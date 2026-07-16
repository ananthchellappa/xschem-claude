# incremental_wire_reroute.md Phase I -- OWNERSHIP DECOUPLING (bookkeeping).
#
# Root cause (spec §3): wire-follow is implemented by select_attached_nets() marking each attached
# wire's endpoint SELECTED1/SELECTED2 (partial select) so the generic stretch machinery drags it.
# rebuild_selected_array() (move.c:93) puts ANY wire with sel!=0 into sel_array, so the auto-grabbed
# follow-wires land in the user's SELECTION and -- with the cadence default unselect_partial_sel_wires=0
# -- STAY selected after the drag. The user's complaint: "wires get selected when I only move an
# instance" (does not happen in Cadence).
#
# Phase I decouples ownership WITHOUT changing the route: under fluid_editing, a stretch that grabbed
# follow-wires (and where the user selected NO wires of her own) leaves NO wire selected at END -- the
# follow-wires are transient tool-owned, not persistent user selection. Only sel-flags change; wire
# GEOMETRY is byte-identical (asserted). Gated on fluid_editing => default OFF is byte-identical.
#
# RED against HEAD c0ce9d06: case A asserts lastsel==1 after the move; today it is 2 (follow-wire left
# selected). Teeth: case B (fluid off) must still be 2 (proves the change is gated + is what flips A);
# case C (route byte-identical on vs off); case D (a wire the USER selected is NOT clobbered).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_32_decouple_ownership.tcl
source [file join [file dirname [info script]] fixtures.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}
# index of the wire whose (normalized) endpoints match, or -1
proc wire_idx {x1 y1 x2 y2} {
  set want [we_norm [list $x1 $y1 $x2 $y2]]
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    if {[we_norm [xschem wire_coord $i]] eq $want} { return $i }
  }
  return -1
}

# Build the canonical setup: res RA at (0,0) (pins M=(0,30), P=(0,-30)); a riser wire on pin M up to
# (0,130), continued by a horizontal to (60,130). Returns RA's index. `fluid` toggles the gate.
proc setup {fluid} {
  we_reset 1 1                                   ;# enable_stretch=1, orthogonal_wiring=1, cadsnap=10
  uplevel #0 [list set cadence_compat 1]
  uplevel #0 [list set autotrim_wires 1]
  uplevel #0 [list set fluid_editing $fluid]
  uplevel #0 [list set unselect_partial_sel_wires 0]   ;# cadence default: the follow-wire would persist
  xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}
  xschem wire 0 30 0 130
  xschem wire 0 130 60 130
  return [inst_by_name RA]
}

# ---- Case A: fluid ON, selection = {instance}, no user wires -> NO wire left selected ------------
set ra [setup 1]
xschem unselect_all
xschem select instance $ra
check "A: pre-move only the instance is selected (lastsel==1)" [expr {[xschem get lastsel] == 1}]
we_move_stretch 20 0
set selA [xschem get lastsel]
check "A: after fluid stretch, follow-wire is NOT left selected (lastsel==1)" [expr {$selA == 1}]
set segA [segset]

# ---- Case B: fluid OFF, same -> follow-wire persists (teeth: the flip is gated on fluid) ---------
set ra [setup 0]
xschem unselect_all
xschem select instance $ra
we_move_stretch 20 0
set selB [xschem get lastsel]
check "B: fluid OFF is unchanged -- follow-wire still selected (lastsel==2, RED-preserving)" \
  [expr {$selB == 2}]
set segB [segset]

# ---- Case C: route byte-identical on vs off (only selection differs, not geometry) --------------
check "C: wire geometry identical fluid on vs off (route unchanged)" [expr {$segA eq $segB}]

# ---- Case D: a wire the USER explicitly selected must NOT be clobbered ---------------------------
# fluid ON, but the user also selected a far, unrelated wire C. nuserwire>0 => the decouple must
# STAND DOWN (Phase I defers the mixed case), so C stays selected. Proven airtight: C (user-selected)
# rides the +20x stretch to (220,200)-(280,200); then a plain move (0,-40) of the still-selected set
# drops it to y=160 IFF it is still selected. If Phase I wrongly cleared it, it stays at y=200.
set ra [setup 1]
xschem wire 200 200 260 200                        ;# wire C, far from RA, unattached
set c [wire_idx 200 200 260 200]
check "D: wire C located" [expr {$c >= 0}]
xschem unselect_all
xschem select instance $ra
xschem select wire $c
check "D: pre-move instance + user wire selected (lastsel==2)" [expr {[xschem get lastsel] == 2}]
we_move_stretch 20 0                               ;# fluid stretch; C rides to (220,200)-(280,200)
xschem move_objects 0 -40                          ;# plain move of whatever is still selected
check "D: user-selected wire C survived the fluid stretch (moved to y=160)" \
  [expr {[has_seg 220 160 280 160] && ![has_seg 220 200 280 200]}]

# ---- Case E (review Bug B): multi-instance move, an internal follow-wire grabbed at BOTH ends -----
# A wire whose two endpoints land on two moving pins is folded to full SELECTED by select_attached_nets
# (SELECTED1 then SELECTED2 -> select.c:965 folds to SELECTED). A START `sel==SELECTED` count therefore
# misreads it as a USER wire, so the deselect stands down and the tool-owned wire persists selected --
# defeating the feature in exactly the common multi-instance case. It MUST be deselected.
proc setup2 {} {
  we_reset 1 1
  uplevel #0 [list set cadence_compat 1]
  uplevel #0 [list set autotrim_wires 1]
  uplevel #0 [list set fluid_editing 1]
  uplevel #0 [list set unselect_partial_sel_wires 0]
}
setup2
xschem instance devices/res 0 0   0 0 {name=RA m=1 value=1k}      ;# pins M=(0,30)  P=(0,-30)
xschem instance devices/res 0 200 0 0 {name=RB m=1 value=1k}      ;# pins M=(0,230) P=(0,170)
xschem wire 0 30 0 170                                            ;# RA.M(0,30) <-> RB.P(0,170): both ends on moving pins
set ra [inst_by_name RA]; set rb [inst_by_name RB]
xschem unselect_all
xschem select instance $ra
xschem select instance $rb
check "E: pre-move two instances selected, no user wire (lastsel==2)" [expr {[xschem get lastsel] == 2}]
we_move_stretch 20 0
check "E: both-ends-grabbed internal follow-wire is NOT left selected (lastsel==2)" \
  [expr {[xschem get lastsel] == 2}]

# ---- Case F (review Bug A): a wire the USER stretch-box-selected by ONE endpoint (partial) --------
# A stretch box-select marks the wire SELECTED1/SELECTED2 (partial) -- a genuine user selection. A
# START `sel==SELECTED` count misses it, so the guard wrongly fires and deselects the user's own wire.
# It MUST survive the move.
setup2                                                           ;# enable_stretch=1 (we_reset 1)
xschem wire 0 0 100 0
xschem unselect_all
xschem select_inside -5 -5 5 5                                   ;# box encloses endpoint (0,0) only -> partial stretch-select
check "F: user stretch-selected a wire by one endpoint (partial) -> lastsel==1" \
  [expr {[xschem get lastsel] == 1}]
we_move_stretch 0 20
check "F: user's partially stretch-selected wire SURVIVES the move (still selected)" \
  [expr {[xschem get lastsel] >= 1}]

# ---- Case G (pre-existing crash guard, found while building this test) ---------------------------
# update_symbol_bboxes() at move START iterated xctx->movelastsel, but movelastsel was refreshed for
# the current move only AFTER that call -- so it used the STALE count from the previous move. Moving a
# 2-object selection then a SMALLER one made the loop read a stale sel_array slot pointing at a
# cleared/unlinked instance (ptr<0), and symbol_bbox() dereferenced sym[ptr<0] -> heap-buffer-overflow
# (confirmed via AddressSanitizer). Fix: refresh movelastsel BEFORE update_symbol_bboxes. This case
# exercises the path (move 2, then move 1) and asserts the second move completes with correct geometry.
# (The overflow faults reliably only under ASan/dash; the E->F sequence above empirically crashed
# pre-fix under `sh`.)
setup2
xschem instance devices/res 0   0 0 0 {name=RA m=1 value=1k}
xschem instance devices/res 200 0 0 0 {name=RB m=1 value=1k}
set ra [inst_by_name RA]; set rb [inst_by_name RB]
xschem unselect_all
xschem select instance $ra
xschem select instance $rb
xschem move_objects 30 0                                         ;# plain move of 2 -> movelastsel=2
setup2                                                          ;# clear; now a SMALLER selection
xschem instance devices/res 0 0 0 0 {name=RC m=1 value=1k}
set rc [inst_by_name RC]
xschem unselect_all
xschem select instance $rc
xschem move_objects 40 0                                         ;# stale movelastsel(=2) path; must not OOB
check "G: move after a larger prior selection completes, RC pin M at x=40" \
  [expr {[lindex [xschem instance_pin_coord $rc name M] 1] == 40}]

we_result
