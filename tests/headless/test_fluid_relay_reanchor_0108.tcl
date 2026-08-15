# issue 0108 -- an ACCEPTED rigid diagonal relay was Manhattanized (0107) into Ls that still
# target the pin's STALE pre-move foot: a detour route through the vacated location plus the
# stale feed copper behind it survived the save (before_8.sch NW drag -> after_25.sch: the
# [0,-40 0,0] stub and the #net3 route around the old [-80,0] riser foot). Under rot180 the
# two stale-anchor Ls must CROSS each other's route, so BOTH orientations verified dirty and
# the raw DIAGONALS survived. Fix: re-anchor each relay diagonal to the closest same-net
# copper (partition-verified), then prune the abandoned stale feed. See
#   doc/claude/issues/0108-fluid-relay-reanchors-to-stale-feet.md
#
# Fixture (fixture_0105_pre.sch == tests/from_user/before_8.sch): R18 (res, rot3 flip1) at
# (-40,0), pins (-70,0) #net3 / (-10,0) #net1; both follow anchors sit on the y=0 row.
#
# Case A: plain LMB attached drag NW by (-130,-90) (the 0107 repro). PASS = no diagonals,
# pins on distinct nets, NO wire endpoint left at the stale feet (0,0)/(-80,0), no new
# dangling endpoints, and total copper length near the hand-optimized preferred_25.sch
# (~1140; the stale-anchor route was ~1900). RED before 0108: stale feet + length ~1900.
#
# Case B: noun-verb 'm' connected stretch, 2x ALT-R (rot180) mid-drag, drop NW (-130,-90).
# Pre-0108 this delta happened to resolve via the 0107 anchor-L; kept as a no-harm guard.
#
# Case C: same rot180 gesture, drop (0,-80) -- RED before 0108: the stale-anchor Ls cross the
# sibling route, both orientations verify dirty, ONE RAW DIAGONAL is saved. PASS = no
# diagonals + partition preserved. (Sweep also showed (60,-60) in this class.)
#
# NEEDS A REAL X DISPLAY. Self-skips cleanly with no display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_relay_reanchor_0108.tcl

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
proc count_diag_wires {} {
  set n 0
  foreach w [allwires] { lassign $w x1 y1 x2 y2
    if {$x1 != $x2 && $y1 != $y2} { incr n } }
  return $n
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
proc allpins {} {
  set P {}
  set n [xschem get instances]
  for {set i 0} {$i<$n} {incr i} {
    set nm [xschem getprop instance $i name]
    if {$nm eq ""} continue
    foreach {pin net} [lrange [xschem instance_nodemap $nm] 1 end] {
      set pc [xschem instance_pin_coord $nm name $pin]
      if {[llength $pc] >= 3} { lappend P [lindex $pc 1] [lindex $pc 2] }
    }
  }
  return $P
}
proc on_seg {x y a b c d {tol 0.01}} {
  set cross [expr {($c-$a)*($y-$b) - ($d-$b)*($x-$a)}]
  set len   [expr {hypot($c-$a, $d-$b)}]
  if {$len == 0} { return [expr {abs($x-$a)<$tol && abs($y-$b)<$tol}] }
  if {abs($cross)/$len > $tol} { return 0 }
  set dot [expr {($x-$a)*($c-$a) + ($y-$b)*($d-$b)}]
  if {$dot < -$tol || $dot > $len*$len+$tol} { return 0 }
  return 1
}
proc dangling_eps {} {
  set ws [allwires]; set ps [allpins]; set D {}
  set nw [llength $ws]
  for {set i 0} {$i<$nw} {incr i} {
    lassign [lindex $ws $i] x1 y1 x2 y2
    foreach {ex ey} [list $x1 $y1 $x2 $y2] {
      set hit 0
      foreach {px py} $ps { if {abs($px-$ex)<0.6 && abs($py-$ey)<0.6} { set hit 1; break } }
      if {!$hit} {
        for {set j 0} {$j<$nw} {incr j} {
          if {$j==$i} continue
          lassign [lindex $ws $j] a b c d
          if {[on_seg $ex $ey $a $b $c $d]} { set hit 1; break }
        }
      }
      if {!$hit} { lappend D [list $ex $ey] }
    }
  }
  return $D
}
proc ep_in {eps x y {tol 0.6}} {
  foreach e $eps { lassign $e a b
    if {abs($a-$x)<$tol && abs($b-$y)<$tol} { return 1 } }
  return 0
}

# ================= Case A: plain LMB attached drag NW (-130,-90) =================
load_fixture
set pre_dangle [dangling_eps]
set p_before [pnet P]; set m_before [pnet M]
check "A setup: pins on distinct nets (P=$p_before M=$m_before)" [expr {$p_before ne $m_before}]
check "A setup: no diagonal wires before the drag" [expr {[count_diag_wires] == 0}]

xschem unselect_all
lassign [xschem instance_coord R18] j1 j2 rx ry
lassign [screen $rx $ry] psx psy
lassign [screen [expr {$rx-130}] [expr {$ry-90}]] tsx tsy
xschem callback $WIN $BP     $psx $psy 0 1 0 0
xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
xschem callback $WIN $MOTION $tsx $tsy 0 0 0 $Button1Mask
xschem callback $WIN $BR     $tsx $tsy 0 1 0 $Button1Mask
update idletasks

lassign [xschem instance_coord R18] a1 a2 nrx nry
check "A: R18 landed at (-170,-90) [list got $nrx $nry]" [expr {$nrx==-170 && $nry==-90}]
set p_after [pnet P]; set m_after [pnet M]
check "A: pins stay on DISTINCT nets (P=$p_after M=$m_after)" [expr {$p_after ne $m_after}]
set ndiag [count_diag_wires]
check "A: no non-Manhattan wires (got $ndiag diagonal)" [expr {$ndiag == 0}]
check "A: stale right-pin foot (0,0) is bare" [expr {![endpoint_at 0 0]}]
check "A: stale left-pin anchor (-80,0) is bare" [expr {![endpoint_at -80 0]}]
set post_dangle [dangling_eps]
set subset 1
foreach e $post_dangle { lassign $e ex ey
  if {![ep_in $pre_dangle $ex $ey]} { set subset 0 } }
check "A: no NEW dangling endpoints (pre=$pre_dangle post=$post_dangle)" $subset
set tlen [total_wire_len]
check "A: total copper near hand-optimized preferred (got $tlen, want <= 1250)" \
  [expr {$tlen <= 1250}]

# ---- shared rot180 gesture: 'm' connected stretch, 2x ALT-R mid-drag, drop at (dx,dy) ----
proc rot180_case {label dx dy} {
  global WIN KP BP BR MOTION Button1Mask Mod1Mask KSYM_m KSYM_r
  load_fixture
  set pre_dangle [dangling_eps]
  set r18 -1
  set n [xschem get instances]
  for {set i 0} {$i<$n} {incr i} { if {[xschem getprop instance $i name] eq "R18"} { set r18 $i } }
  check "$label setup: fixture has R18" [expr {$r18 >= 0}]

  lassign [xschem instance_coord R18] j1 j2 rx ry
  lassign [screen $rx $ry] sx sy
  lassign [screen [expr {$rx+$dx/3}] [expr {$ry+$dy/3}]] m1x m1y
  lassign [screen [expr {$rx+2*$dx/3}] [expr {$ry+2*$dy/3}]] m2x m2y
  lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
  xschem unselect_all; xschem select instance $r18
  xschem callback $WIN $KP $sx $sy $KSYM_m 0 0 0
  xschem callback $WIN $MOTION $m1x $m1y 0 0 0 0
  xschem callback $WIN $KP $m1x $m1y $KSYM_r 0 0 $Mod1Mask
  xschem callback $WIN $KP $m1x $m1y $KSYM_r 0 0 $Mod1Mask
  xschem callback $WIN $MOTION $m2x $m2y 0 0 0 0
  xschem callback $WIN $MOTION $tx $ty 0 0 0 0
  xschem callback $WIN $BP $tx $ty 0 1 0 0
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks

  lassign [xschem instance_coord R18] b1 b2 brx bry brot bflip
  check "$label: R18 landed at ([expr {$rx+$dx}],[expr {$ry+$dy}]) [list got $brx $bry]" \
    [expr {$brx==$rx+$dx && $bry==$ry+$dy}]
  check "$label: R18 rotated by 180 (rot=$brot expected [expr {(3+2)%4}])" [expr {$brot == (3+2)%4}]
  set p_after [pnet P]; set m_after [pnet M]
  check "$label: pins stay on DISTINCT nets (P=$p_after M=$m_after)" [expr {$p_after ne $m_after}]
  set ndiag [count_diag_wires]
  check "$label: no non-Manhattan wires after rot180 stretch (got $ndiag diagonal)" [expr {$ndiag == 0}]
  set post_dangle [dangling_eps]
  set subset 1
  foreach e $post_dangle { lassign $e ex ey
    if {![ep_in $pre_dangle $ex $ey]} { set subset 0 } }
  check "$label: no NEW dangling endpoints (pre=$pre_dangle post=$post_dangle)" $subset
}

rot180_case "B (rot180 NW -130,-90)" -130 -90
rot180_case "C (rot180 S 0,-80)" 0 -80
rot180_case "D (rot180 NE 60,-60)" 60 -60

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
