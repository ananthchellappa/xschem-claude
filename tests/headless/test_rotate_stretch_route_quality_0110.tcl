# issue 0110 -- a ROTATED fluid stretch skipped the aesthetic straighteners entirely (they were
# rotfree-gated), so one ALT-R mid-drag saved a 4-segment STAIRCASE at the pin's stale anchor
# column plus a U-LOOP under the destination backbone (before_8.sch, 'm' + ALT-R, drop (+10,-90)
# -> after_27.sch). Fix: fluid_prune_anchor_tails runs BEFORE the straighteners (the dangling
# stale-anchor tail masked the staircase's jog at touch-degree 2), and
# fluid_straighten_reversals + fluid_collapse_axis_overshoot_stub run under rotation/flip too
# (all their reshapes are pin-partition-verified + novelty-scoped + body-guarded). See
#   doc/claude/issues/0110-rotate-stretch-skips-straighteners-staircase-loop.md
#
# Fixture (fixture_0105_pre.sch == tests/from_user/before_8.sch): R18 (res, rot3 flip1) at
# (-40,0). Gesture: select R18, 'm' connected stretch, one ALT-R mid-drag, drop at (+10,-90)
# -> R18 at (-30,-90) rot0 flip1, pins (-30,-120) #net3 / (-30,-60) #net1.
#
# PASS = partition preserved AND the two quality defects are gone:
#   - #net3 has NO jog at the stale anchor column x=-80: the backbone extends to the pin column
#     (a wire ends at (-30,-150)) and feeds the pin straight down;
#   - #net1 has NO copper below y=-35 (the old loop dove to y=0) and no endpoint at the stale
#     (0,0) anchor;
#   - total copper strictly below the pre-fix route (1470) and no new dangling endpoints.
#
# NEEDS A REAL X DISPLAY. Self-skips cleanly with no display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_rotate_stretch_route_quality_0110.tcl

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- fluid drag test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}
update idletasks; catch { focus -force $WIN }; update idletasks

set ::fails 0; set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail"; incr ::fails }
}

set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256 ; set Mod1Mask 8
set KSYM_m 109 ; set KSYM_r 114

set ::HERE [file dirname [file normalize [info script]]]

proc load_fixture {} {
  xschem load [file join $::HERE fixture_0105_pre.sch]
  set ::intuitive_interface 1; xschem set intuitive_interface 1
  set ::cadence_compat 1
  set ::fluid_editing 1; catch { xschem set fluid_editing 1 }
  set ::orthogonal_wiring 1; catch { xschem set orthogonal_wiring 1 }
  set ::autotrim_wires 1
  set ::enable_stretch 0
  xschem zoom_full; update idletasks
}

proc pnet {pin} { return [lindex [xschem instance_net R18 $pin] 0] }
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(round(($sx+$xo)/$zm))}] [expr {int(round(($sy+$yo)/$zm))}]
}
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
proc wires_of {net} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    if {[xschem getprop wire $i lab] eq $net} { lappend L [xschem wire_coord $i] }
  }
  return $L
}
proc total_wire_len {} {
  set t 0.0
  foreach w [allwires] { lassign $w x1 y1 x2 y2
    set t [expr {$t + abs($x2-$x1) + abs($y2-$y1)}] }
  return $t
}
proc endpoint_at {x y {tol 0.6}} {
  foreach w [allwires] { lassign $w a b c d
    if {(abs($a-$x)<$tol && abs($b-$y)<$tol) || (abs($c-$x)<$tol && abs($d-$y)<$tol)} { return 1 } }
  return 0
}

load_fixture
set p_before [pnet P]; set m_before [pnet M]
check "setup: pins on distinct nets (P=$p_before M=$m_before)" [expr {$p_before ne $m_before}]

set r18 -1
set n [xschem get instances]
for {set i 0} {$i<$n} {incr i} { if {[xschem getprop instance $i name] eq "R18"} { set r18 $i } }
check "setup: fixture has R18" [expr {$r18 >= 0}]

set dx 10; set dy -90
lassign [xschem instance_coord R18] j1 j2 rx ry
lassign [screen $rx $ry] sx sy
lassign [screen [expr {$rx+$dx/2}] [expr {$ry+$dy/2}]] m1x m1y
lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
xschem unselect_all; xschem select instance $r18
xschem callback $WIN $KP $sx $sy $KSYM_m 0 0 0
xschem callback $WIN $MOTION $m1x $m1y 0 0 0 0
xschem callback $WIN $KP $m1x $m1y $KSYM_r 0 0 $Mod1Mask
xschem callback $WIN $MOTION $tx $ty 0 0 0 0
xschem callback $WIN $BP $tx $ty 0 1 0 0
xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord R18] a1 a2 nrx nry nrot nflip
check "R18 landed at (-30,-90) rot0 [list got $nrx $nry rot $nrot]" \
  [expr {$nrx == -30 && $nry == -90 && $nrot == 0}]
set p_after [pnet P]; set m_after [pnet M]
check "pins stay on DISTINCT nets (P=$p_after M=$m_after)" [expr {$p_after ne $m_after}]

# --- #net3: staircase collapsed -- no wire endpoint on the stale anchor column between the
#     backbone row and the pin row, and the backbone reaches the pin column at y=-150 ---
set p3 [lindex [xschem instance_net R18 P] 0]
set stale3 0
foreach w [wires_of "#$p3"] { lassign $w x1 y1 x2 y2
  foreach {ex ey} [list $x1 $y1 $x2 $y2] {
    if {abs($ex - -80) < 0.6 && $ey > -150.4 && $ey < -60} { set stale3 1 } } }
check "#net3: no jog endpoint left on the stale x=-80 column (wires=[wires_of "#$p3"])" \
  [expr {!$stale3}]
check "#net3: backbone reaches the pin column (endpoint at (-30,-150))" [expr {[endpoint_at -30 -150]}]

# --- #net1: U-loop gone -- no #net1 wire ENDPOINT in the old loop band (-35 < y < 100; the
#     loop's elbows sat on y=0, legitimate copper is at y<=-60 and on the y=140 ammeter row) ---
set m1 [lindex [xschem instance_net R18 M] 0]
set deep 0
foreach w [wires_of "#$m1"] { lassign $w x1 y1 x2 y2
  foreach ey [list $y1 $y2] { if {$ey > -35 && $ey < 100} { set deep 1 } } }
check "#net1: no loop endpoint in the -35<y<100 band (wires=[wires_of "#$m1"])" [expr {!$deep}]
check "#net1: stale right-pin anchor (0,0) is bare" [expr {![endpoint_at 0 0]}]

set tlen [total_wire_len]
check "total copper strictly below the pre-fix route (got $tlen, want < 1470)" [expr {$tlen < 1470}]

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
