# nice_drag_rerouting Phase 3 -- exit-stub CONNECTIVITY (the disconnect fix).
#
# BUG (root cause): insert_exit_stubs() stored the exit stub as (pin -> tip). When the pin's
# escape normal points -x or -y, the tip is LEFT/BELOW the pin, so the wire is stored with
# x1>x2 (or y1>y2) -- UNORDERED. touch() (clip.c), which the netlister uses in
# name_attached_inst_to_net() to bind a pin to a wire, REQUIRES ordered coords (x1<=x2, or
# vertical y1<=y2); on an unordered stub it returns 0, so the pin silently fails to bind and
# lands on a fresh #net (a disconnect -- P1 violation). A +y/+x escape stub was ordered by
# luck and bound fine, which is why only the -y/-x pin disconnected.
#
# This is the RED-first guard for that fix: a 2-pin res with BOTH pins wired to labels, dragged
# perpendicular with wire_exit_stub forced on (so both a +y escape (pin M) and a -y escape
# (pin P) stub fire). It asserts:
#   - P1 connectivity invariant holds (NO pin lands on #net -- the disconnect is gone),
#   - both pins still resolve to their original labelled nets,
#   - P3 escape-perpendicular holds (the nice escape actually fired),
#   - the -y stub really is present (teeth: proves we exercised the failing direction).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_29_exit_stub_connectivity.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}
# resolved net of a named instance's pin (bare token), via the connectivity map
proc pin_net {inst pin} {
  set map [xschem instance_nodemap $inst]
  foreach {p node} [lrange $map 1 end] { if {$p eq $pin} { return $node } }
  return {}
}

we_reset 1 1
set cadence_compat 1; set autotrim_wires 1; set fluid_editing 1; set wire_exit_stub 1
xschem instance devices/res 0 0 0 0 {name=RA}       ;# pins P(0,-30) M(0,30)
xschem wire 0 30 0 130   ; xschem instance {lab_pin.sym} 0 130  0 0 {name=LM lab=NM}   ;# M -> NM (+y escape)
xschem wire 0 -30 0 -130 ; xschem instance {lab_pin.sym} 0 -130 0 0 {name=LP lab=NP}   ;# P -> NP (-y escape)

set snap [net_snapshot]
xschem unselect_all; xschem select instance [inst_by_name RA]
we_move_stretch 40 0                                 ;# perpendicular drag: both escape stubs fire

# --- the fix: no disconnect -------------------------------------------------
check "P1 connectivity invariant holds (no pin torn onto #net)" [p1_netlist_invariant $snap]
check "pin M still on net NM" [expr {[pin_net RA M] eq "NM"}]
check "pin P still on net NP (the -y escape stub -- the bug)" [expr {[pin_net RA P] eq "NP"}]
check "runtime P1 guard flags 0 disconnects" \
  [expr {[info exists ::fluid_last_move_disconnects] && $::fluid_last_move_disconnects == 0}]

# --- the nice escape actually fired (teeth) ---------------------------------
check "P3 escape perpendicular holds (both pins exit along their normal)" [p3_escape_perp RA 10]
check "P4 orthogonality holds" [p4_orthogonal]
check "-y exit stub present at pin P (40,-30)-(40,-40)" [has_seg 40 -30 40 -40]
check "+y exit stub present at pin M (40,30)-(40,40)"   [has_seg 40 30 40 40]

we_result
