# Issue 0018 — with a wire SELECTED and orthogonal_wiring on, a new wire could not be
# completed: the completing click placed nothing (in persistent_command mode the rubber
# band just kept following). Trigger config = src/cadence_style_rc
# (cadence_compat + orthogonal_wiring + persistent_command + snap_cursor + ...).
#
# Root cause: drawing the selection overlay under the in-progress rubber band
# (restore_selection -> draw_selection -> drawtemp_manhattanline with force_manhattan)
# called recompute_orthogonal_manhattanline() on the SELECTED wire and overwrote the
# GLOBAL xctx->manhattan_lines with that wire's orientation. The active (perpendicular)
# wire then inherited the wrong manhattan direction; in persistent mode start_wire set
# constr_mv from it and collapsed the new segment to zero length -> discarded.
# Fix: drawtemp_manhattanline() saves/restores manhattan_lines around its force_manhattan
# recompute so drawing the overlay never leaks into the active gesture (src/draw.c).
#
# Drives the REAL press/motion/release dispatch via `xschem callback`, so it needs a
# window. WSLg note: it waits for the canvas and RETRIES fixture build (never FAILs on a
# not-ready window, only on the actual lost-wire behavior).
#   ./src/xschem --pipe -q --script tests/headless/test_wire_complete_with_selection.tcl

set KP 2 ; set BP 4 ; set BR 5 ; set MOTION 6
set Button1Mask 256

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}
proc result {} {
  puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]; flush stdout
  exit [expr {$::fails != 0}]
}
proc ready {} {
  catch {wm geometry . 1000x800}
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo ismapped .drw] && [winfo width .drw] > 300 && [winfo height .drw] > 300} break
  }
  xschem zoom_full; update idletasks
}
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}
proc click {sx sy} { lassign [screen $sx $sy] cx cy
  xschem callback .drw $::BP $cx $cy 0 1 0 0
  xschem callback .drw $::BR $cx $cy 0 1 0 $::Button1Mask; update }
proc wkey {sx sy} { lassign [screen $sx $sy] cx cy; xschem callback .drw $::KP $cx $cy 119 0 0 0 }
proc esc {}       { xschem callback .drw $::KP 1 1 65307 0 0 0; update }
proc moveto {sx sy} { lassign [screen $sx $sy] cx cy; xschem callback .drw $::MOTION $cx $cy 0 0 0 0 }
proc mr {x0 y x1 {step 10}} { for {set x $x0} {$x<=$x1} {incr x $step} { moveto $x $y; update } }
proc mrv {x y0 y1 {step 10}} { for {set y $y0} {$y<=$y1} {incr y $step} { moveto $x $y; update } }

proc cadcfg {} {
  foreach {v val} {draw_crosshair 1 crosshair_size 2 infix_interface 0 cadence_compat 1
    orthogonal_wiring 1 snap_cursor 1 snap_cursor_size 4 persistent_command 1
    use_cursor_for_selection 1 enable_stretch 1 intuitive_interface 1 cadsnap 10} {
    set ::$v $val; catch {xschem set $v $val}
  }
}

# Draw a wire (persistent mode: finish with Esc), then optionally select it, then draw a
# PERPENDICULAR new wire and report the wire-count delta for the new wire.
#   dir = "v" : first wire vertical  (0,40)->(0,-40); new wire horizontal (100,100)->(160,100)
#   dir = "h" : first wire horizontal(40,0)->(-40,0); new wire vertical   (100,40)->(100,160)
# returns "notready" if the window/geometry isn't ready (first wire absent).
proc scenario {dir presel} {
  cadcfg; xschem clear force; ready
  if {$dir eq "v"} { wkey 0 40; click 0 40; moveto 0 -40; click 0 -40; esc } \
  else             { wkey 40 0; click 40 0; moveto -40 0; click -40 0; esc }
  update idletasks
  if {[xschem get wires] != 1} { return notready }
  if {$presel} { click 0 0 }   ;# select the first wire (passes through its body)
  set before [xschem get wires]
  if {$dir eq "v"} { wkey 100 100; click 100 100; mr 110 100 160;  click 160 100; esc } \
  else             { wkey 100 100; click 100 100; mrv 100 110 160; click 100 160; esc }
  update idletasks
  return [expr {[xschem get wires] - $before}]
}
proc run {dir presel} {
  for {set t 0} {$t < 40} {incr t} {
    set r [scenario $dir $presel]
    if {$r ne "notready"} { return $r }
    update
  }
  return notready
}

# Case 1 (the bug): vertical wire selected, draw a horizontal new wire -> must complete.
check "horizontal wire completes with a vertical wire selected" [expr {[run v 1] >= 1}]
# Case 2 (symmetric): horizontal wire selected, draw a vertical new wire -> must complete.
check "vertical wire completes with a horizontal wire selected"  [expr {[run h 1] >= 1}]
# Case 3 (guard): nothing selected still works (pre- and post-fix).
check "new wire completes with nothing selected (guard)"         [expr {[run v 0] >= 1}]

result
