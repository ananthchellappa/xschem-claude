# F8 (nice_drag_rerouting §7 fixture matrix) -- 4-pin device, mixed edges: full bundle, lane
# assignment, P6. Assert-only: pred_verdict records the OBSERVED verdict per predicate (baseline
# pinned to reality). This is the integration fixture -- a rigid group of pins moving together
# whose escapes interact. With the Phase-3 fluid nice escape enabled, P5 flipped RED->GREEN (no
# leg crosses the body). P3 stays RED: pin b is a near-centre bulk pin with an ambiguous escape
# normal (the crude-normal case, §6) so its leg does not escape perpendicular -- a Phase-5/6
# concern, not a regression. Critically P1 stays GREEN across the whole bundle (the +y/-y AND -x
# escape stubs all bind now -- the order_wire_coords disconnect fix in move.c).
#
# devices/nmos4 at origin: d(20,-30) escapes down, g(-20,0) escapes left, s(20,30) escapes up,
# b(20,0) is a near-centre bulk pin (ambiguous normal -- the crude-normal case, §6). Each pin
# is wired to a labelled anchor; then the whole device is dragged +X so the bundle must reroute.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_25_F8_mos_bundle.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} {
    if {[xschem getprop instance $i name] eq $n} { return $i }
  }
  return -1
}

we_reset 1 1
set cadence_compat 1
set autotrim_wires 1
set fluid_editing  1

xschem instance devices/nmos4 0 0 0 0 {name=M1}
# one wire per pin, out to a labelled anchor
xschem wire 20 -30 20 -130 ; xschem instance {lab_pin.sym} 20 -130 0 0 {name=LD lab=NETD}  ;# d down
xschem wire -20 0 -120 0   ; xschem instance {lab_pin.sym} -120 0  0 0 {name=LG lab=NETG}  ;# g left
xschem wire 20 30 20 130   ; xschem instance {lab_pin.sym} 20 130  0 0 {name=LS lab=NETS}  ;# s up
xschem wire 20 0 120 0     ; xschem instance {lab_pin.sym} 120 0   0 0 {name=LB lab=NETB}  ;# b right

check "F8: bundle built (device + 4 stubs + 4 labels)" [expr {[xschem get instances] == 5}]
set snap [net_snapshot]

set m1 [inst_by_name M1]
check "F8: M1 located" [expr {$m1 >= 0}]
xschem unselect_all
xschem select instance $m1
we_move_stretch 40 0                                          ;# drag the whole device +X

# informational route metrics (P6 needs a hand-authored oracle -> not gated here)
puts "PRED: F8.metrics bends=[route_bends] length=[route_length]"; flush stdout

# --- record verdicts (baseline pinned to OBSERVED reality) ------------------
pred_verdict "F8.P1 connectivity invariant" [p1_netlist_invariant $snap] GREEN
pred_verdict "F8.P2 no-short"               [p2_no_short]                GREEN
pred_verdict "F8.P3 escape perpendicular"   [p3_escape_perp M1 10]       RED
pred_verdict "F8.P4 orthogonality"          [p4_orthogonal]              GREEN
pred_verdict "F8.P5 no body cross"          [p5_no_body_cross]           GREEN

we_result
