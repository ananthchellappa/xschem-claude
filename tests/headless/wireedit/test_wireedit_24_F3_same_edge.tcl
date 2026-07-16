# F3 (nice_drag_rerouting §7 fixture matrix) -- two pins on the same side, dragged ALONG the
# edge: escape collision / lane order (P3). Assert-only: pred_verdict records the OBSERVED
# verdict (baseline pinned to reality). With the Phase-3 fluid nice escape enabled, both pins
# now exit along their outward normal so P3 and P5 flipped RED->GREEN (the feature working); P1
# stays GREEN (the exit-stub disconnect fix -- order_wire_coords in move.c).
#
# No stock symbol has two pins on one edge escaping the same way, so this uses devices/nmos4's
# two vertically-stacked right-side pins d(20,-30) and s(20,30) (escape down / up) as the
# same-side pair, and drags the device DOWN -- along the axis the two pins share. A true
# same-edge/same-direction lane collision needs a bespoke symbol; that is a Phase-5 concern.
# Here we record how the fast path handles a stacked-pin along-axis drag.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_24_F3_same_edge.tcl
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
xschem wire 20 -30 20 -130 ; xschem instance {lab_pin.sym} 20 -130 0 0 {name=LD lab=NETD}  ;# d down
xschem wire 20 30  20 130  ; xschem instance {lab_pin.sym} 20 130  0 0 {name=LS lab=NETS}  ;# s up

set snap [net_snapshot]
set m1 [inst_by_name M1]
check "F3: M1 located" [expr {$m1 >= 0}]
xschem unselect_all
xschem select instance $m1
we_move_stretch 40 0                                          ;# drag PERPENDICULAR: forces both
                                                             ;# stacked escapes to jog into a lane

puts "PRED: F3.metrics bends=[route_bends] length=[route_length]"; flush stdout

# --- record verdicts (baseline pinned to OBSERVED reality) ------------------
pred_verdict "F3.P1 connectivity invariant" [p1_netlist_invariant $snap] GREEN
pred_verdict "F3.P2 no-short"               [p2_no_short]                GREEN
pred_verdict "F3.P3 escape perpendicular"   [p3_escape_perp M1 10]       GREEN
pred_verdict "F3.P4 orthogonality"          [p4_orthogonal]              GREEN
pred_verdict "F3.P5 no body cross"          [p5_no_body_cross]           GREEN

we_result
