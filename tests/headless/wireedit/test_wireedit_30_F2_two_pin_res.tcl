# F2 (nice_drag_rerouting §7 fixture matrix) -- 2-pin res, BOTH pins on wires, dragged
# PERPENDICULAR: independent escapes, no collision. This is the canonical Phase-3 "nice escape"
# fixture and the acceptance gate for enabling the fluid nice escape (spec §8 Phase 3): with
# fluid_editing on (and NO wire_exit_stub -- the fluid gate alone must fire the escape stubs),
# both pins must exit along their outward normal (P3), the route stays orthogonal (P4), no leg
# crosses the body (P5), and -- the fix -- connectivity is preserved (P1): the -y escape stub
# no longer disconnects pin P. All four are asserted GREEN (no pred_verdict baseline dance:
# this fixture must PASS, it is the feature working).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_30_F2_two_pin_res.tcl
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
set fluid_editing  1        ;# the fluid gate alone must fire the escape stubs (no wire_exit_stub)

xschem instance devices/res 0 0 0 0 {name=RA}          ;# pins P(0,-30) M(0,30)
xschem wire 0 30  0 130  ; xschem instance {lab_pin.sym} 0 130  0 0 {name=LM lab=NM}  ;# M -> NM (+y)
xschem wire 0 -30 0 -130 ; xschem instance {lab_pin.sym} 0 -130 0 0 {name=LP lab=NP}  ;# P -> NP (-y)

set snap [net_snapshot]
set ra [inst_by_name RA]
check "F2: RA located" [expr {$ra >= 0}]
xschem unselect_all
xschem select instance $ra
we_move_stretch 40 0                                    ;# perpendicular drag: both escapes fire

puts "PRED: F2.metrics bends=[route_bends] length=[route_length]"; flush stdout

# --- the fluid nice escape, all four predicates GREEN -----------------------
check "F2.P1 connectivity invariant (no disconnect -- the fix)" [p1_netlist_invariant $snap]
check "F2.P2 no-short"                                          [p2_no_short]
check "F2.P3 escape perpendicular (fluid gate fired the stubs)" [p3_escape_perp RA 10]
check "F2.P4 orthogonality"                                     [p4_orthogonal]
check "F2.P5 no body cross"                                     [p5_no_body_cross]
check "F2: runtime P1 guard flags 0 disconnects" \
  [expr {[info exists ::fluid_last_move_disconnects] && $::fluid_last_move_disconnects == 0}]

we_result
