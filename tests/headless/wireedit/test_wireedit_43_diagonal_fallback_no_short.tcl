# issue 0085 "blind-elbow diagonal fallback" -- from-user repro tests/from_user/before_3.sch ->
# after_5.sch (2026-07-08, FLUID_TRACE=/tmp/fltrace_7_8_1.log).
#
# A diagonal fluid drag of R18 (+180,-90) makes the 0081 two-leg decomposition fail its P2
# partition check (composite legs merge nets) -> rollback to the single diagonal pass. That pass's
# manhattan L relays were chosen by fluid_ml_blocked, which only tested the stationary-device
# two-pin bridge, so it picked elbows that:
#   (a) ran R18.P's riser straight through R18's OWN co-moving M pin (moving instances were
#       explicitly skipped by the bridge test) -> self-short N -220 -160 -220 -100, and
#   (b) T'd the rail relay's vertical leg onto C12's stub ENDPOINT at (-400,-90) (wire-endpoint
#       contacts were never tested) -> #net2/#net1 merge,
# and the result was committed with NO partition re-check (`if(nlegs==1) break`). Everything
# collapsed onto one net (after_5.sch).
#
# The fix (a) widens the elbow choice to 4 hazard classes (fluid_ml_hazards: device bridge,
# co-moving pin plow, lone foreign pin, stray stationary-wire-endpoint contact) picking the
# strictly-lower-severity orientation, and (b) partition-checks EVERY fallback attempt: attempt 1
# (ortho diagonal pass) rolls back to attempt 2, a RIGID diagonal relay (no manhattan jog, no new
# copper), kept only when strictly better; else the ortho attempt-1 result returns (never-worse).
#
# Asserts are CONNECTIVITY-only (routes may legally be diagonal after the last-resort relay):
#   - R18 not self-shorted (P vs M)
#   - C12 stays tied to R18.P and the rail stays tied to R18.M, and the two nets stay DISTINCT
#   - v8 (ammeter) not shorted
# Both drives are exercised: one-shot END move and the stepwise RUBBER path (Phase II
# restore-and-reapply must agree: release == stepwise).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_43_diagonal_fallback_no_short.tcl
source [file join [file dirname [info script]] fixtures.tcl]
source [file join [file dirname [info script]] predicates.tcl]

proc gates0 {} {
  uplevel #0 {set cadence_compat 1}
  uplevel #0 {set fluid_editing 1}
  uplevel #0 {set orthogonal_wiring 1}
  uplevel #0 {set autotrim_wires 0}
  uplevel #0 {set enable_stretch 1}
  uplevel #0 {set unselect_partial_sel_wires 0}
  uplevel #0 {set cadsnap 10}
}
proc inst_by_name {n} {
  set ni [xschem get instances]
  for {set i 0} {$i < $ni} {incr i} { if {[xschem getprop instance $i name] eq $n} { return $i } }
  return -1
}
proc pinnet {inst pin} {
  xschem resolved_net 0
  set m [xschem instance_nodemap $inst]
  foreach {p nn} [lrange $m 1 end] { if {$p eq $pin} { return $nn } }
  return {}
}
# net of the H/V wire covering point (x,y) (endpoint or mid-span), {} if none
proc net_of_wire_at {x y} {
  xschem resolved_net 0
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    lassign [xschem wire_coord $i] x1 y1 x2 y2
    set on 0
    if {$x1 == $x2 && $x == $x1 && $y >= min($y1,$y2) && $y <= max($y1,$y2)} { set on 1 }
    if {$y1 == $y2 && $y == $y1 && $x >= min($x1,$x2) && $x <= max($x1,$x2)} { set on 1 }
    if {$on} { return [xschem getprop wire $i lab] }
  }
  return {}
}

# before_3.sch scene (text label omitted -- cosmetic only)
proc build_scene {} {
  xschem clear force
  gates0
  xschem instance devices/capa    -420 -200 0 0 {name=C12 m=1 value="40u"}
  xschem instance devices/res     -400  -40 0 1 {name=R18 m=1 value=200}
  xschem instance devices/ammeter -360  140 3 0 {name=v8}
  xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
  foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140}
    {-400 -10 -400 140} {-420 -90 -400 -90} {-550 140 -400 140}
    {-400 140 -390 140} {-420 -170 -420 -90} {-400 -90 -400 -70}
  } { xschem wire {*}$w }
  xschem unselect_all
}

# shared connectivity asserts; tag distinguishes the drives
proc assert_no_shorts {tag} {
  set nP [pinnet R18 P]
  set nM [pinnet R18 M]
  set nC [net_of_wire_at -420 -170]   ;# C12 pin (always covered by C12's net wire, whatever the route shape)
  set nR [net_of_wire_at -550 150]    ;# rail stub  (stationary vertical wire)
  check "$tag: R18.P and R18.M both connected" [expr {$nP ne {} && $nM ne {}}]
  check "$tag: R18 not self-shorted (P net != M net)" [expr {$nP ne $nM}]
  check "$tag: C12 riser still on R18.P's net" [expr {$nC eq $nP}]
  check "$tag: rail still on R18.M's net" [expr {$nR eq $nM}]
  check "$tag: C12 net and rail net stay distinct" [expr {$nC ne $nR}]
  check "$tag: v8 not shorted (plus != minus)" \
    [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
}

# baseline sanity: the pin-name assumption (P = C12 side, M = rail side) must hold pre-move,
# otherwise every post-move assert would test the wrong pins
build_scene
check "baseline: R18.P on C12 riser's net" [expr {[pinnet R18 P] eq [net_of_wire_at -420 -170]}]
check "baseline: R18.M on rail's net" [expr {[pinnet R18 M] eq [net_of_wire_at -550 150]}]
check "baseline: nets distinct" [expr {[pinnet R18 P] ne [pinnet R18 M]}]

# ---- Drive 1: one-shot END diagonal move (+180,-90) ----------------------------------------------
xschem select instance [inst_by_name R18]
we_move_stretch 180 -90
assert_no_shorts "D1(release)"

# ---- Drive 2: stepwise RUBBER path (waypoints from the user's FLUID_TRACE log) --------------------
build_scene
xschem select instance [inst_by_name R18]
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {10 10   70 10   100 0   140 -30   140 -80   180 -90} {
  xschem move_objects step $sx $sy
}
xschem move_objects end 180 -90
assert_no_shorts "D2(stepwise)"

# ---- Drive 3: pure-axis sanity (elbow-classifier widening must not damage an axis move) -----------
build_scene
xschem select instance [inst_by_name R18]
we_move_stretch 180 0
assert_no_shorts "D3(pure-X)"

# ---- Drive 4 (review wf_e348633c F2): STRAY must NOT flag a tap on the stretched wire's own
# pre-move span. R1.P's follow wire (0,0)-(200,0) carries a mid-span tap T (100,0)-(100,80) feeding
# R2. A pure-Y drag re-covers the old span in one orientation; a false STRAY flip away from it
# would DISCONNECT the tap (P1). Pure-axis => no partition safety net: the classifier alone owns it.
xschem clear force
gates0
xschem instance devices/res -0 30 0 0 {name=R1 m=1 value=100}
xschem instance devices/lab_pin 200 0 0 0 {name=lA lab=NETA}
xschem instance devices/res 100 110 0 0 {name=R2 m=1 value=100}
xschem wire 0 0 200 0
xschem wire 100 0 100 80
xschem unselect_all
xschem select instance [inst_by_name R1]
we_move_stretch 0 -100
check "D4(tap): R2 tap still on R1.P's net (no false-STRAY flip disconnect)" \
  [expr {[pinnet R2 P] ne {} && [pinnet R2 P] eq [pinnet R1 P]}]
check "D4(tap): NETA anchor still on R1.P's net" \
  [expr {[pinnet lA p] eq [pinnet R1 P]}]

# ---- Drive 5 (review wf_e348633c F1): a SIBLING follow wire's fixed anchor is a real contact.
# R1.P's wire runs to (200,0); R1.M's wire (net B) runs to anchor (100,60). Dragging R1 +Y by 60
# puts one orientation's horizontal leg exactly through the sibling anchor (100,60) -> the
# classifier must see it (partial-sel wires were skipped entirely before the hardening) and route
# the other way. Assert nets A and B stay distinct.
xschem clear force
gates0
xschem instance devices/res -0 30 0 0 {name=R1 m=1 value=100}
xschem instance devices/lab_pin 200 0 0 0 {name=lA lab=NETA}
xschem instance devices/lab_pin 100 60 0 0 {name=lB lab=NETB}
xschem wire 0 0 200 0
xschem wire 0 60 100 60
xschem unselect_all
xschem select instance [inst_by_name R1]
we_move_stretch 0 60
check "D5(sibling-anchor): NETA and NETB stay distinct" \
  [expr {[pinnet lA p] ne [pinnet lB p]}]
check "D5(sibling-anchor): R1.P still on NETA" [expr {[pinnet R1 P] eq [pinnet lA p]}]
check "D5(sibling-anchor): R1.M still on NETB" [expr {[pinnet R1 M] eq [pinnet lB p]}]

# ---- Drive 6 (round-2 review wf_876b8a88): a co-selected SIBLING follow wire whose FIXED anchor
# T's the other follow wire's pre-move span joins two nets THROUGH that T; abandoning the span
# would split them (SPANLOSS must count partial siblings, not just stationary taps). R1.P's wire
# (0,0)-(200,0) carries R2.P's wire T at (50,0); both instances co-selected, pure-Y drag.
xschem clear force
gates0
xschem instance devices/res 0 30 0 0 {name=R1 m=1 value=100}
xschem instance devices/res 50 80 0 0 {name=R2 m=1 value=100}
xschem instance devices/lab_pin 200 0 0 0 {name=lA lab=NETA}
xschem wire 0 0 200 0
xschem wire 50 0 50 50
xschem unselect_all
xschem select instance [inst_by_name R1]
xschem select instance [inst_by_name R2]
we_move_stretch 0 -100
check "D6(sibling-T): R2.P still on NETA (span with sibling T re-covered)" \
  [expr {[pinnet R2 P] eq [pinnet lA p]}]
check "D6(sibling-T): R1.P still on NETA" [expr {[pinnet R1 P] eq [pinnet lA p]}]

we_result
