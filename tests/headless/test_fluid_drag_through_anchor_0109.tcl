# issue 0109 -- a PURE-AXIS fluid drag that carries a device pin THROUGH its follow anchor used
# to stretch the follow stub straight across the sibling pin and across the other net's riser
# foot on the same row: a two-contact-point merge no END pass could de-short (short-tail only
# reached partial improvement and reverted), and the pure-axis path had NO P2 safety net
# (`if(!leg_snapped) break;`), so the short committed sight-unseen
# (before_8.sch, R18 dragged (-110,0) -> after_26.sch: R18 shorted out, #net3 swallowed).
# Fix: push-through corner slide (the anchor's perpendicular riser TRANSLATES with the pin,
# vacating the row) + the P2 safety net armed for pure-axis fluid stretches. See
#   doc/claude/issues/0109-fluid-drag-through-anchor-collinear-short.md
#
# Fixture (fixture_0105_pre.sch == tests/from_user/before_8.sch): R18 (res, rot3 flip1) at
# (-40,0), pins (-70,0) #net3 / (-10,0) #net1; both follow anchors sit on the y=0 row:
# the #net3 riser foots at (-80,0), the #net1 feed descends to (0,0).
#
# Case A: plain LMB drag pure-left (-110,0) -- the repro. RED before 0109: pins merged.
# Case B: same drag with a wobble past the target and back (the user's actual hand path).
# Case C: diagonal dip then settle back onto the row at (-110,0).
# Case D: pull-away drag pure-right (+60,0) -- push-through must NOT fire (pin moves away
#         from the left anchor, toward/past the right one); guards the (0,0) corner slide.
# All cases: pins on DISTINCT nets, no diagonal wires, no NEW dangling endpoints.
#
# NEEDS A REAL X DISPLAY. Self-skips cleanly with no display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_drag_through_anchor_0109.tcl

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

set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256

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

# waypoints: {dx dy} pairs relative to R18's start; plain LMB press on R18, motions, release at last
proc drag_case {label waypoints endx endy} {
  global WIN BP BR MOTION Button1Mask
  load_fixture
  set pre_dangle [dangling_eps]
  set p_before [pnet P]; set m_before [pnet M]
  check "$label setup: pins on distinct nets (P=$p_before M=$m_before)" \
    [expr {$p_before ne $m_before}]

  xschem unselect_all
  lassign [xschem instance_coord R18] j1 j2 rx ry
  lassign [screen $rx $ry] psx psy
  xschem callback $WIN $BP $psx $psy 0 1 0 0
  xschem callback $WIN $MOTION $psx [expr {$psy-4}] 0 0 0 $Button1Mask
  set tx $psx; set ty $psy
  foreach wp $waypoints {
    lassign $wp dx dy
    lassign [screen [expr {$rx+$dx}] [expr {$ry+$dy}]] tx ty
    xschem callback $WIN $MOTION $tx $ty 0 0 0 $Button1Mask
  }
  xschem callback $WIN $BR $tx $ty 0 1 0 $Button1Mask
  update idletasks

  lassign [xschem instance_coord R18] a1 a2 nrx nry
  check "$label: R18 landed at ([expr {$rx+$endx}],[expr {$ry+$endy}]) [list got $nrx $nry]" \
    [expr {$nrx == $rx+$endx && $nry == $ry+$endy}]
  set p_after [pnet P]; set m_after [pnet M]
  check "$label: pins stay on DISTINCT nets (P=$p_after M=$m_after)" [expr {$p_after ne $m_after}]
  set ndiag [count_diag_wires]
  check "$label: no non-Manhattan wires (got $ndiag diagonal)" [expr {$ndiag == 0}]
  set post_dangle [dangling_eps]
  set subset 1
  foreach e $post_dangle { lassign $e ex ey
    if {![ep_in $pre_dangle $ex $ey]} { set subset 0 } }
  check "$label: no NEW dangling endpoints (pre=$pre_dangle post=$post_dangle)" $subset
}

# Case A: pure-left in steps -- the after_26 repro. RED before 0109.
drag_case "A (pure-left -110,0)" {{-30 0} {-60 0} {-90 0} {-110 0}} -110 0
# Case B: wobble left past the target then back right (the user's recorded hand path).
drag_case "B (wobble)" \
  {{-20 0} {-90 0} {-110 0} {-140 0} {-170 0} {-160 0} {-150 0} {-140 0} {-130 -10} {-110 0}} -110 0
# Case C: diagonal dip then settle back onto the row.
drag_case "C (diag dip)" \
  {{-10 -10} {-50 -30} {-140 -80} {-170 -100} {-150 -100} {-120 -40} {-110 0}} -110 0
# Case D: pull-away right (+60,0): left stub stretches, right pin passes THROUGH its (0,0) anchor.
drag_case "D (pure-right +60,0)" {{20 0} {40 0} {60 0}} 60 0

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
