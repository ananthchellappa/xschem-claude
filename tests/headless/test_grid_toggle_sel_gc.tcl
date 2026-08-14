# Issue 0082 regression: toggling the grid OFF (CTRL-G -> view.toggle_draw_grid ->
# `set draw_grid 0; xschem redraw`) must NOT leave the shared GRIDLAYER/SELLAYER GC in a
# dashed line style. draw_selection() strokes the grey selection overlay with
# gc[SELLAYER], which aliases gc[GRIDLAYER] (both == layer 2). Before the drawgrid() fix,
# the axes line-attribute mutation ran before the draw_grid early-out, so a grid-OFF redraw
# left the GC LineOnOffDash and the selection highlight (rects/instances, drawn verbatim by
# drawtemprect) rendered dashed/broken.
#
# Observable: `xschem get gc_line_style [<layer>]` -> cached X line_style
#   0 = LineSolid, 1 = LineOnOffDash, 2 = LineDoubleDash, -1 = no X / bad layer.
#
# Notes on determinism:
#  - crosshair OFF: draw_crosshair uses crosshair_layer (default 2 == the same GC) and would
#    otherwise re-set attributes after the grid pass.
#  - selection is a RECT, not a WIRE: the wire overlay (drawtemp_manhattanline -> drawtempline)
#    re-sets the GC to LineSolid itself and would mask the corruption; drawtemprect uses the
#    GC verbatim, so the leaked dashed style survives to the post-draw probe.
#
# REQUIRES X (real GCs). Run from the repo ROOT under a display, NOT --nogui:
#   ./src/xschem --pipe -q --script tests/headless/test_grid_toggle_sel_gc.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set sel [xschem get gridlayer]   ;# SELLAYER == GRIDLAYER == 2

# Needs a real X connection (GCs only exist with has_x). Under --nogui the seam returns -1:
# skip cleanly rather than false-fail.
if {[xschem get gc_line_style $sel] eq "-1"} {
  puts "SKIP: no X connection (has_x=0); run under DISPLAY with --pipe"
  puts "OVERALL: ok"; exit 0
}

set draw_crosshair 0      ;# crosshair_layer default == 2, keep it off the shared GC

# A selected RECT so draw_selection() exercises the real overlay path (drawtemprect, verbatim GC).
xschem rect 4 0 0 100 100
xschem select_all
check "rect selected" [expr {[xschem get rects 4] >= 1}] 1

# Defaults: grid on + axes on. Grid-ON path ends with the LineSolid reset.
set draw_grid 1
set draw_grid_axes 1
xschem redraw
check "baseline grid-ON: sel GC solid" [xschem get gc_line_style $sel] 0

# THE BUG: turn the grid OFF (exactly what CTRL-G does) and redraw. The shared GC must stay
# solid; before the fix the axes attribute block left it dashed (1) on this early-out path.
set draw_grid 0
xschem redraw
check "grid-OFF (axes on): sel GC solid, not dashed" [xschem get gc_line_style $sel] 0

# Control: grid off + axes off must also be solid (axes block skipped entirely).
set draw_grid_axes 0
xschem redraw
check "grid-OFF (axes off): sel GC solid" [xschem get gc_line_style $sel] 0

# Toggling back on stays solid.
set draw_grid 1
set draw_grid_axes 1
xschem redraw
check "grid re-ON: sel GC solid" [xschem get gc_line_style $sel] 0

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
