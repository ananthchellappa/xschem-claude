# F1 (nice_drag_rerouting §7 fixture matrix) -- 1-pin net-label mid-span tap.
#
# GROUND-TRUTH GREEN ANCHOR. F1 is the regression of the SHIPPED single-pin fix
# (commits d5163559 "W7 keep the through-wire, drop one stub" + 6925e724 "W7 slide guard
# perpendicular-only"; see doc/claude/FAQ.md Q27 and doc/claude/specs/wire_segment_splitting.md
# W7). It MUST be green on every predicate today. If a predicate goes RED on F1 the PREDICATE
# is wrong, not the code -- F1 validates the predicate stack before we aim it at the RED
# fixtures F3/F4/F5/F8.
#
# Fixture = the exact user case behind the shipped fix: a horizontal through-run, a resistor
# tapping it at x=0, and a net-label (devices/lab_wire) tapping the interior at x=-80. The
# split feature breaks the run into 3 abutting collinear segments at the two taps. Dragging
# the label up must LEAVE the run in place -- not jog the whole run into a U-detour.
#
# RE-AUTHORED for doc/claude/specs/wire_label_ride.md S1 (change #4 + LEASH). The tap here is a
# NET LABEL, whose pin is now a naming anchor rather than copper geometry, so the shipped result
# changed in three linked ways -- and only for a label, never for the resistor tap:
#   - connect_by_kissing() no longer mints the vertical rescue stub -80,-110 -> -80,-60: the drag
#     creates NO new copper at all (R1);
#   - the label is projected back onto its owner span at move END (R7), returning to (-80,-60)
#     rather than committing off the run;
#   - with the label transiently away from the -80 split point, maintain_wire_segments welds the
#     two collinear halves, so the run is left split only at the RESISTOR pin.
# P1 connectivity is unchanged, which is the point: the stub was never what connected the label
# (name_attached_inst_to_net binds a pin to any wire it touch()es, interior included).
#
# AMENDED AGAIN for S2 (R2, changes #6/#7, `label_splits_wires` default 0): the label never
# splits the run in the first place, so the fixture starts at 2 segments (split at the RESISTOR
# only) instead of 3, and S1's transient weld is now the resting state. Every post-drag assertion
# below is BYTE-IDENTICAL to the S1 result -- which is the S2 claim worth having here: removing the
# split changes what the fixture looks like at rest, not what the drag does to it. The two halves
# either side of x=-80 are now genuinely one object all along, so BOTH run pieces belong in the P7
# stable set. Set `label_splits_wires 1` to get the 3-segment pre-S2 fixture back.
#
# Uses devices/res + devices/lab_wire (not the fixtures.tcl res.sym/lab_pin helpers): the
# mid-span split needs an INLINE net label (lab_wire), and this reproduces the proven-green
# W7 geometry byte-for-byte.
#
# Predicates exercised now: P1 (connectivity), P4 (orthogonality), P7 (stability). P2
# (no-short) and P3 (escape-perp) assertions land here when those predicates are written
# (spec §8 Phase-0 order); the concrete geometry checks below already pin the shipped result.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_20_F1_netlabel_tap.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

# locate an instance by its `name` property
proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}

# --- build the shipped W7 fixture ------------------------------------------
# we_reset sets enable_stretch=0, orthogonal_wiring=1, cadsnap=10 and clears. The mid-span
# split + tap-drag behaviour additionally needs these gates, set BEFORE placing objects so
# the label's placement performs the split:
we_reset 0 1
set cadence_compat 1
set autotrim_wires 1
set fluid_editing  1

xschem wire -100 -60 110 -60                                   ;# horizontal through-run
xschem instance devices/res     0 -30 0 1 {name=R7 m=1 value=320} ;# resistor taps the run at x=0
xschem instance devices/lab_wire -80 -60 0 0 {name=l8 lab=GB}  ;# net-label taps mid-span at x=-80

# S2: the RESISTOR pin still splits the run at x=0; the net LABEL at x=-80 does not (R2).
check "F1: the device tap alone splits the run into 2 clickable segments" [expr {[xschem get wires] == 2}]

# capture connectivity + the run segments that must stay untouched (P7 stable set)
set snap [net_snapshot]
# P7 stable set: BOTH run pieces. Under S2 the label never cut the run, so neither half is a
# gesture artifact -- dragging the label must leave every existing wire object alone (it did
# already under S1, where the -100..0 piece was instead a weld of two halves).
set run_segs {{-100 -60 0 -60} {0 -60 110 -60}}

# --- drag the net-label up (0,-50) via the faithful cadence stretch+kissing drag ---
set li [inst_by_name l8]
check "F1: label instance located" [expr {$li >= 0}]
xschem unselect_all
xschem select instance $li
we_move_stretch 0 -50                                          ;# label pin 0,-60 -> 0,-110

# --- predicate assertions (the ground truth) -------------------------------
check "F1: P1 connectivity invariant -- no pin lost/gained a net" [p1_netlist_invariant $snap]
check "F1: P4 orthogonality -- every leg axis-aligned"           [p4_orthogonal]
check "F1: P7 stability -- the untapped run piece is untouched" [p7_stability $run_segs]

# --- concrete shipped-behaviour geometry (pins the exact result) -----------
check "F1: exactly 2 wires (the run, NOT a 5-wire U-detour)" [expr {[xschem get wires] == 2}]
check "F1: the run still spans -100..0 on y=-60"             [has_seg -100 -60 0 -60]
check "F1: the resistor tap still splits it at x=0"          [has_seg 0 -60 110 -60]
check "F1: the leash put the label back on the run (R7)" \
  [expr {[lrange [xschem instance_pin_coord l8 name p] 1 2] eq {-80 -60}}]
# NO segment leaves the y=-60 run: the label drag extruded no copper (R1)
set off_run 0
foreach w [segset] { lassign $w a b x y; if {$b != -60 || $y != -60} { incr off_run } }
check "F1: no stub leaves the run (R1)" [expr {$off_run == 0}]

we_result
