# issue 0086 "future-blind leg-0 aesthetics defeat the two-leg decomposition" -- from-user repro
# tests/from_user/before_3.sch -> after_6.sch (2026-07-08, FLUID_TRACE=/tmp/fltrace_7_8_2.log).
#
# A diagonal fluid drag of R18 by (+150,-80) has a clean Manhattan solution (the offset pass's
# V-H-V riser for R18.M + a V-first elbow for R18.P's stub), but THREE future-blind leg-0
# decisions each parked #net2 copper exactly on R18.M's FINAL landing point (-250,-90), so the
# 0081 X-then-Y decomposition failed its partition check, the single diagonal pass failed too
# (0085), and the gesture collapsed to the rigid diagonal relay: two DIAGONAL wires saved
# (after_6.sch) although nothing forced them:
#   (a) compute_wire_slide slid the C12-stub corner from (-400,-90) to (-250,-90) -- the slid
#       neighbour's stretched endpoint became a fixed anchor ON the landing point, and leg 1's
#       follow stretch from it was a degenerate straight run (no elbow freedom) into the short;
#   (b) with the slide declined, the free elbow tie for the stub relay (both orientations
#       P2-clean at leg-0 sight) could still pick the corner AT the landing point;
#   (c) with (a)+(b) fixed, insert_exit_stubs planted a P3 stub at the pin's INTERMEDIATE
#       (leg-0) position (-250,-80)..(-250,-70) -- an anchor inside leg 1's stretch corridor.
# The fix: (a) fluid_slide_future_hazard declines the slide when slid/dragged copper would park
# on a co-moving foreign-net pin's final landing; (b) fluid_ml_future_covers breaks free elbow
# ties away from orientations covering a future landing; (c) exit stubs are inserted on the
# FINAL leg only (they are a final-state aesthetic). All three are inert outside decomposed
# fluid legs.
#
# Unlike test 43 (connectivity-only, diagonals legal after the last resort), THIS test pins the
# QUALITY outcome: the (+150,-80) drag must stay all-Manhattan AND keep the partition intact.
# Both drives are exercised (release == stepwise must agree).
#
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/wireedit/test_wireedit_44_diagonal_manhattan_quality.tcl
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

# quality + connectivity asserts; tag distinguishes the drives
proc assert_manhattan_clean {tag} {
  set nP [pinnet R18 P]
  set nM [pinnet R18 M]
  set nC [net_of_wire_at -420 -170]   ;# C12 pin (always covered by C12's net wire, whatever the route shape)
  set nR [net_of_wire_at -550 150]    ;# rail stub  (stationary vertical wire)
  check "$tag: all wires Manhattan (no diagonal fallback fired)" [all_manhattan]
  check "$tag: R18.P and R18.M both connected" [expr {$nP ne {} && $nM ne {}}]
  check "$tag: R18 not self-shorted (P net != M net)" [expr {$nP ne $nM}]
  check "$tag: C12 riser still on R18.P's net" [expr {$nC eq $nP}]
  check "$tag: rail still on R18.M's net" [expr {$nR eq $nM}]
  check "$tag: C12 net and rail net stay distinct" [expr {$nC ne $nR}]
  check "$tag: v8 not shorted (plus != minus)" \
    [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]
  check "$tag: OUT untouched by the reroute" \
    [expr {[net_of_wire_at -300 140] eq [pinnet p5 p]}]
  check "$tag: OUT distinct from R18.M's net (row not overrun past v8)" \
    [expr {[net_of_wire_at -300 140] ne $nM}]
}

# baseline sanity: the pin-name assumption (P = C12 side, M = rail side) must hold pre-move,
# otherwise every post-move assert would test the wrong pins
build_scene
check "baseline: R18.P on C12 riser's net" [expr {[pinnet R18 P] eq [net_of_wire_at -420 -170]}]
check "baseline: R18.M on rail's net" [expr {[pinnet R18 M] eq [net_of_wire_at -550 150]}]
check "baseline: nets distinct" [expr {[pinnet R18 P] ne [pinnet R18 M]}]

# ---- Drive 1: one-shot END diagonal move (+150,-80) ----------------------------------------------
xschem select instance [inst_by_name R18]
we_move_stretch 150 -80
assert_manhattan_clean "D1(release)"

# ---- Drive 2: stepwise RUBBER path (wandering waypoints from the user's FLUID_TRACE log) ---------
build_scene
xschem select instance [inst_by_name R18]
xschem move_objects start 0 0 kissing stretch
foreach {sx sy} {10 10  -10 40  100 30  170 -60  40 -80  60 40  180 0  100 -80  -30 -20
                 120 -10  150 -70  150 -80} {
  xschem move_objects step $sx $sy
}
xschem move_objects end 150 -80
assert_manhattan_clean "D2(stepwise)"

# ---- Drive 3: release == stepwise (byte-level route agreement between D1 and D2) -----------------
# (rebuilt D1 here so both geometries are captured in one session)
proc wire_geoms {} {
  set nw [xschem get wires]
  set g {}
  for {set i 0} {$i < $nw} {incr i} { lappend g [xschem wire_coord $i] }
  return [lsort $g]
}
set g2 [wire_geoms]
build_scene
xschem select instance [inst_by_name R18]
we_move_stretch 150 -80
check "D3: release and stepwise routes byte-identical" [expr {[wire_geoms] eq $g2}]

# ---- Drive 4: pure-axis sanity (the 0086 helpers must be inert on a single-axis move) ------------
build_scene
xschem select instance [inst_by_name R18]
we_move_stretch 150 0
check "D4(pure-X): all wires Manhattan" [all_manhattan]
check "D4(pure-X): nets distinct" [expr {[pinnet R18 P] ne [pinnet R18 M]}]
check "D4(pure-X): v8 not shorted" [expr {[pinnet v8 plus] ne [pinnet v8 minus]}]

# ---- Drive 5: the 0085 scene (+180,-90) must still be connectivity-clean (test 43's contract;
# routes MAY legally stay diagonal there if no clean Manhattan exists -- do not pin quality) ------
build_scene
xschem select instance [inst_by_name R18]
we_move_stretch 180 -90
check "D5(+180,-90): R18 not self-shorted" [expr {[pinnet R18 P] ne [pinnet R18 M]}]
check "D5(+180,-90): C12 net and rail net stay distinct" \
  [expr {[net_of_wire_at -420 -170] ne [net_of_wire_at -550 150]}]

# ---- Drive 6: issue 0087 -- the (+250,-90) razor-edge (before_3.sch -> after_7.sch). Both R18 pins
# land STACKED on the shared column x=-150 (M at -100, P at -160), so the leg-0 corner slide / free
# elbow tie parked #net2 copper a SINGLE grid off R18.M's final POINT but squarely inside the riser
# M drags down that column -- the 0086 point-only future tests missed it and the gesture collapsed to
# the diagonal relay (after_7.sch: N -400 140 -150 -100 + N -400 -90 -150 -160). The fix generalises
# both future tests from the pin's final POINT to its full riser CORRIDOR. A clean Manhattan route
# exists (net2 up column x=-400 over the top, net1 down its own column) so QUALITY is pinned here. ---
build_scene
xschem select instance [inst_by_name R18]
we_move_stretch 250 -90
assert_manhattan_clean "D6(+250,-90 razor-edge)"

# ---- Drive 7: the singular point must not be a lucky isolated pass -- the whole (+230..+270, -60..
# -110) band around it stays all-Manhattan AND partition-clean. Pre-fix ONLY (+250,-90) was diagonal
# in this band (its neighbours found the route); the band locks the edge so a regression re-reports. -
build_scene
set band_bad 0
foreach dx {230 240 250 260 270} {
  foreach dy {-60 -70 -80 -90 -100 -110} {
    build_scene
    xschem select instance [inst_by_name R18]
    we_move_stretch $dx $dy
    if {![all_manhattan] || [pinnet R18 P] eq [pinnet R18 M]} { incr band_bad }
  }
}
check "D7: (+230..+270,-60..-110) band all-Manhattan + partition-clean (30 deltas)" [expr {$band_bad == 0}]

we_result
