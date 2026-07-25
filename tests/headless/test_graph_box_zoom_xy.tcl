# Graph RMB box-zoom is an X+Y box (issue: waveform-viewer RMB press-drag).
# An RMB (Button3) press-drag INSIDE a graph's plot area must zoom BOTH the X
# window (x1/x2 tokens) AND the Y window (y1/y2 tokens) to the dragged box — and
# draw a live rubber rectangle. Before the fix the interior drag zoomed X only
# (Y ignored); this test's TEETH is the Y-window assertion (RED before the fix,
# GREEN after). The rubber rectangle itself is transient X drawing and is not
# asserted here (drawtemprect no-ops without a display anyway).
#
# The same shared C engine (waves_callback) drives both the ASE waveform viewer
# and on-canvas schematic graphs, so this drives the shipped test_ne555.sch
# embedded graph directly. ControlMask is held throughout to satisfy the
# non-locked-graph interaction gate (waves_selected).
#
# GUI gesture: DISPLAY-guarded, self-SKIPs (RESULT: SKIP) under --nogui / no
# usable main window. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_graph_box_zoom_xy.tcl
# (needs DISPLAY)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# X11 event / mask constants
set BP 4 ; set BR 5 ; set MOTION 6
set ShiftMask 1 ; set ControlMask 4 ; set Button3Mask 1024

# schematic -> screen pixel:  s_screen = (s_sch + origin) / zoom
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}

# wait for a real, mapped main canvas (WSLg can be slow); 0 => caller SKIPs
proc main_ready {} {
  catch {wm geometry . 1000x800}
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo ismapped .drw] && [winfo width .drw] > 300 && [winfo height .drw] > 300} {
      return 1
    }
  }
  return 0
}

# tokens of the graph rect (index 0) as numbers
proc gtok {t} { expr {double([xschem getprop rect 2 0 $t])} }

set skipped 0
if {[catch {

 if {![info exists ::has_x] || [info commands winfo] eq {}} {
   puts "gui gesture skipped (no DISPLAY)"; set skipped 1
 } elseif {![main_ready]} {
   puts "SKIPPED: (WSLg geometry: main window never became usable)"; set skipped 1
 } else {
   set here [file normalize [file dirname [info script]]]
   set repo [file normalize [file join $here .. ..]]
   xschem load [file join $repo xschem_library examples test_ne555.sch]
   xschem zoom_full
   update

   # the shipped ne555 graph is layer-2 rect 0
   check "fixture: rect 0 is a graph" [xschem getprop rect 2 0 flags] graph

   # rect container B 2 730 -720 1530 -320 ; pick two points well inside the
   # 14%-margin plot box, forming a sub-box in BOTH axes
   set p1x 950 ; set p1y -640
   set p2x 1310; set p2y -430

   set ox1 [gtok x1]; set ox2 [gtok x2]
   set oy1 [gtok y1]; set oy2 [gtok y2]
   set oxlo [expr {min($ox1,$ox2)}]; set oxhi [expr {max($ox1,$ox2)}]
   set oylo [expr {min($oy1,$oy2)}]; set oyhi [expr {max($oy1,$oy2)}]

   # RMB box-zoom gesture (Ctrl held so the non-locked graph accepts it)
   lassign [screen $p1x $p1y] s1x s1y
   lassign [screen [expr {($p1x+$p2x)/2}] [expr {($p1y+$p2y)/2}]] smx smy
   lassign [screen $p2x $p2y] s2x s2y
   set C $ControlMask
   set CM [expr {$ControlMask | $Button3Mask}]
   xschem callback .drw $BP     $s1x $s1y 0 3 0 $C
   xschem callback .drw $MOTION $smx $smy 0 0 0 $CM
   xschem callback .drw $MOTION $s2x $s2y 0 0 0 $CM
   xschem callback .drw $BR     $s2x $s2y 0 3 0 $CM
   update

   set nx1 [gtok x1]; set nx2 [gtok x2]
   set ny1 [gtok y1]; set ny2 [gtok y2]
   set nxlo [expr {min($nx1,$nx2)}]; set nxhi [expr {max($nx1,$nx2)}]
   set nylo [expr {min($ny1,$ny2)}]; set nyhi [expr {max($ny1,$ny2)}]

   # gesture registered: X window changed and zoomed IN (new range inside old)
   check_true "X window changed (gesture registered)" \
     [expr {$nx1 != $ox1 || $nx2 != $ox2}]
   check_true "X zoomed in (new X range inside old)" \
     [expr {$nxlo >= $oxlo - 1e-9 && $nxhi <= $oxhi + 1e-9 && ($nxhi-$nxlo) < ($oxhi-$oxlo)}]

   # THE FIX: Y window also changed and zoomed IN (RED before the fix)
   check_true "Y window changed (Y no longer ignored)" \
     [expr {$ny1 != $oy1 || $ny2 != $oy2}]
   check_true "Y zoomed in (new Y range inside old)" \
     [expr {$nylo >= $oylo - 1e-9 && $nyhi <= $oyhi + 1e-9 && ($nyhi-$nylo) < ($oyhi-$oylo)}]

   # --- unsnap (issue 0143): the schematic snap grid must NOT apply in a graph.
   # With a snap step LARGER than the whole drag, a *snapped* pointer collapses
   # press==release -> no zoom; an *unsnapped* pointer still zooms. RED before
   # the unsnap fix, GREEN after. ---
   set save_snap $::cadsnap
   set ::cadsnap 100000
   xschem load [file join $repo xschem_library examples test_ne555.sch]
   xschem zoom_full
   update
   set ux1 [gtok x1]; set ux2 [gtok x2]; set uy1 [gtok y1]; set uy2 [gtok y2]
   lassign [screen $p1x $p1y] s1x s1y
   lassign [screen [expr {($p1x+$p2x)/2}] [expr {($p1y+$p2y)/2}]] smx smy
   lassign [screen $p2x $p2y] s2x s2y
   xschem callback .drw $BP     $s1x $s1y 0 3 0 $C
   xschem callback .drw $MOTION $smx $smy 0 0 0 $CM
   xschem callback .drw $MOTION $s2x $s2y 0 0 0 $CM
   xschem callback .drw $BR     $s2x $s2y 0 3 0 $CM
   update
   set vx1 [gtok x1]; set vx2 [gtok x2]; set vy1 [gtok y1]; set vy2 [gtok y2]
   set ::cadsnap $save_snap
   check_true "unsnap: X still zooms with a snap grid bigger than the drag" \
     [expr {$vx1 != $ux1 || $vx2 != $ux2}]
   check_true "unsnap: Y still zooms with a snap grid bigger than the drag" \
     [expr {$vy1 != $uy1 || $vy2 != $uy2}]
 }

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "  $::errorInfo"
  incr fail
}

if {$fail == 0 && $skipped} {
  puts "RESULT: SKIP (graph box-zoom gesture needs a usable display)"
  flush stdout
  exit 0
}
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
