# issue 0111 -- the P3 exit-stub pass re-staircases the straightened pin arrival.
#
# A fluid NW drag of R18 from before_8.sch (fixture_0105_pre.sch) leaves #net3 as a 4-segment
# monotone STAIRCASE: horizontal @y=-150 -> riser at x=-190 -> a 10-unit stub east into the
# pin (-180,-90). The END straighten pass (0090) correctly collapses the jog and lands the
# riser straight into the pin (3 segments) -- but insert_exit_stubs() runs AFTER it and
# re-inserts the escape-normal stub, sliding the riser one grid back off the pin: the two
# passes are direct antagonists on this shape and the pass ORDER made the stub win
# (tests/from_user/after_28.sch, /tmp/fltrace_7_8_25.log: "slid jog wire=13 x->-180
# (staircase collapse)" yet the save shows the riser at -190 + stub).
#
# Fix (in straighten, not in insert_exit_stubs): a near collapse target that lands on a
# MOVING pin whose escape normal runs along the slide axis now tries the FAR target first --
# where legal it removes the jog entirely and the route arrives straight along the pin's
# lead (P3-perfect, minimum segments) -- else it normalizes the jog to one grid OUTWARD of
# the pin (pin + grid x normal), which is byte-identical to the old collapse + re-stub round
# trip, so the 0089/0090/0091 goldens and the wireedit 37/40 connected-wire shove keep their
# shapes. Here the P side's far collapse succeeds: #net3 becomes the 2-segment L
#   (-320,-160)->(-320,-90)->(-180,-90)   (C12 foot column merged + lead-axis run into P)
# exceeding the reported ask (3 segments). The M side's far collapse is foreign-blocked
# (it would touch the new #net3 column), so it normalizes to the familiar one-grid outward
# jog -- the pre-0111 #net1 shape, unchanged.
# See doc/claude/issues/0111-exit-stub-restaircases-straightened-pin-arrival.md
#
# Fixture (fixture_0105_pre.sch == tests/from_user/before_8.sch): R18 (res, rot3 flip1) at
# (-40,0), pins P=(-70,0) #net3 / M=(-10,0) #net1. Drag NW by (-110,-90) -> R18 at (-150,-90),
# pins P=(-180,-90) / M=(-120,-90).
#
# NEEDS A REAL X DISPLAY. Self-skips cleanly with no display. Run for real:
#   ./src/xschem --pipe -q --script tests/headless/test_fluid_exit_stub_staircase_0111.tcl

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
  set ::wire_exit_stub 0
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
proc have_wire {X1 Y1 X2 Y2} {
  foreach w [allwires] { lassign $w x1 y1 x2 y2
    if {($x1==$X1 && $y1==$Y1 && $x2==$X2 && $y2==$Y2) ||
        ($x1==$X2 && $y1==$Y2 && $x2==$X1 && $y2==$Y1)} { return 1 } }
  return 0
}
proc have_endpoint {X Y} {
  foreach w [allwires] { lassign $w x1 y1 x2 y2
    if {($x1==$X && $y1==$Y) || ($x2==$X && $y2==$Y)} { return 1 } }
  return 0
}

proc drag_case {label waypoints} {
  global WIN BP BR MOTION Button1Mask
  load_fixture
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
  check "$label: R18 landed at (-150,-90) [list got $nrx $nry]" \
    [expr {$nrx == -150 && $nry == -90}]
  set p_after [pnet P]; set m_after [pnet M]
  check "$label: pins stay on DISTINCT nets (P=$p_after M=$m_after)" [expr {$p_after ne $m_after}]
  check "$label: no non-Manhattan wires" [expr {[count_diag_wires] == 0}]

  # THE issue: #net3 must NOT save as the 4-segment staircase of after_28.sch (riser at
  # x=-190 + 10-unit stub into the pin). The far collapse gives the 2-segment L instead:
  # C12's foot column straight down to y=-90, then the lead-axis run into the P pin.
  check "$label: #net3 lead-axis run into the P pin \[-320,-90 -180,-90\]" \
    [have_wire -320 -90 -180 -90] "wires=[allwires]"
  check "$label: #net3 column merged straight down \[-320,-160 -320,-90\]" \
    [have_wire -320 -160 -320 -90]
  check "$label: no staircase jog corner at (-190,-90)" [expr {![have_endpoint -190 -90]}]
  check "$label: old horizontal @y=-150 fully absorbed" [expr {![have_endpoint -190 -150]}]

  # The M pin's far collapse is foreign-blocked (would touch the new #net3 column), so the
  # #net1 feed keeps the pre-0111 one-grid outward jog -- the baseline shape, unchanged.
  check "$label: #net1 M-pin outward stub kept \[-120,-90 -110,-90\]" \
    [have_wire -120 -90 -110 -90]
  check "$label: #net1 riser at the normalized jog \[-110,-90 -110,-40\]" \
    [have_wire -110 -90 -110 -40]
}

# The user's gesture (fltrace_7_8_25.log): NW drag with intermediate commits, landing (-110,-90).
drag_case "A (NW drag -110,-90)" {{-20 -10} {-30 -30} {-40 -40} {-110 -90}}
# Same landing via a different hand path (single long step).
drag_case "B (direct NW)" {{-110 -90}}

puts ""
if {$::fails == 0} { puts "RESULT: ALL PASS ($::npass checks)"; puts "OVERALL: ok" } \
else               { puts "RESULT: $::fails FAIL"; puts "OVERALL: FAIL" }
exit [expr {$::fails ? 1 : 0}]
