# F4 (nice_drag_rerouting §7 fixture matrix) -- pin/route behind a body: body-detour (P5).
# Spec §8 predicts RED. Assert-only: pred_verdict records the OBSERVED verdict (baseline
# pinned to reality, not the spec's guess). When Phase 5/6 (body-aware routing) lands, a
# RED->GREEN flip fails here on purpose -> update the baseline.
#
# Construction: a horizontal through-wire (net NETX) sits at y=0. A resistor is dragged DOWN
# onto it so the device body straddles the wire -- the wire now crosses the body interior with
# neither endpoint on an RB pin (RB's pins are at y=+/-30, clear of the y=0 wire). That is the
# canonical P5 violation: routing/geometry that ploughs a wire straight through a device body.
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_23_F4_body_detour.tcl
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

xschem wire -100 0 100 0                                      ;# through-wire, net NETX
xschem instance {lab_pin.sym} -100 0 0 0 {name=LX lab=NETX}
xschem instance devices/res 0 200 0 0 {name=RB m=1 value=1k}  ;# above; pins P(0,170) M(0,230)

check "F4: through-wire clear of the body before the drag" [p5_no_body_cross]
set snap [net_snapshot]

set rb [inst_by_name RB]
check "F4: RB located" [expr {$rb >= 0}]
xschem unselect_all
xschem select instance $rb
we_move_stretch 0 -200                                        ;# RB body down onto y=0 (pins to 0,+/-30)

# --- record verdicts (baseline pinned to OBSERVED reality) ------------------
pred_verdict "F4.P1 connectivity invariant" [p1_netlist_invariant $snap] GREEN
pred_verdict "F4.P4 orthogonality"          [p4_orthogonal]              GREEN
pred_verdict "F4.P5 no body cross"          [p5_no_body_cross]           RED

we_result
