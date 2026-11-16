# Issue 0082 regression: toggling the grid OFF (CTRL-G -> view.toggle_draw_grid ->
# `set draw_grid 0; xschem redraw`) must NOT leave the GC layer 2 owns in a dashed line style.
# gc[GRIDLAYER] is gc[SELLAYER] (both == layer 2), and crosshair_layer defaults to 2 as well,
# so the grid, the crosshair and the CLASSIC selection look (selection_style classic) all stroke
# with one GC. Before the drawgrid() fix, the axes line-attribute mutation ran before the
# draw_grid early-out, so a grid-OFF redraw left that GC LineOnOffDash and a classic selection
# highlight (rects/instances, drawn verbatim by drawtemprect) rendered dashed/broken.
#
# The other selection looks (bright, brightbox, halo; brightbox is the default) stroke with
# their own GCs, gc_sel, gc_selhalo and gc_selbox (build_colors() in src/xinit.c), which no grid
# code touches. Band S asserts they stay solid across the same toggles in each look: the box
# brightbox draws is solid by the user's ruling (doc/claude/selection_look_batch/PLAN.md), and a
# dashed box would read as the hover outline.
#
# Observable: `xschem get gc_line_style [<layer>|sel|selhalo|selbox]` -> cached X line_style
#   0 = LineSolid, 1 = LineOnOffDash, 2 = LineDoubleDash, -1 = no X / bad layer.
#
# Notes on determinism:
#  - crosshair OFF: draw_crosshair uses crosshair_layer (default 2 == the same GC) and would
#    otherwise re-set attributes after the grid pass.
#  - selection is a RECT, not a WIRE: the wire overlay (drawtemp_manhattanline -> drawtempline)
#    re-sets the GC to LineSolid itself and would mask the corruption; drawtemprect uses the
#    GC verbatim, so the leaked dashed style survives to the post-draw probe.
#
# REQUIRES X (real GCs); registered in dcases. Under --nogui it says so and stops.
# scratch.tcl gives it a scratch directory (and arms the in-suite watchdog).
# Run it armed:  tests/headless/run_suites.sh test_grid_toggle_sel_gc
# Prints "OVERALL: ok" on success (run_regression sentinel).

source [file join [file dirname [info script]] scratch.tcl]

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

# A real sheet in scratch first: the first edit of a sheet writes its `~` backup, and for the
# untitled startup sheet that is untitled~.sch in the directory xschem started in (tests/ under
# T1). Row U1 at the foot asserts none was left there.
set here_untitled [lsort [glob -nocomplain -directory [pwd] untitled*]]
set dir [test_scratch gridselgc]
set f [open [file join $dir grid.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}\nG {}\nK {}\nV {}\nS {}\nE {}"
close $f
xschem load [file join $dir grid.sch]

# A selected RECT so draw_selection() exercises the real overlay path (drawtemprect, verbatim GC).
# `xschem rect x1 y1 x2 y2 [pos]` draws on the current rectcolor; this file once wrote
# `xschem rect 4 0 0 100 100`, which stores at position 100 of an empty array (a write past its
# end that aborted the process at exit with a heap-corruption message).
set rc [xschem get rectcolor]
xschem rect 0 0 100 100
xschem select_all
check "rect selected" [list [xschem get rects $rc] [xschem get lastsel]] {1 1}

# ---- C: the classic look, the one that strokes with layer 2's GC
set selection_style classic; xschem build_colors
check "C0 the classic look is in force" [dict get [xschem get selection_look] style] classic

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

# ---- S: the styled looks. Each: the look in force, then the three selection GCs' styles at
# grid on, grid off with axes, grid off without, and grid back on.
foreach look {bright brightbox halo} {
  set selection_style $look; xschem build_colors
  set seen {}
  foreach {g a} {1 1 0 1 0 0 1 1} {
    set draw_grid $g; set draw_grid_axes $a
    xschem redraw
    lappend seen [list [xschem get gc_line_style sel] [xschem get gc_line_style selhalo] \
                       [xschem get gc_line_style selbox]]
  }
  check "S $look: gc_sel, gc_selhalo and gc_selbox stay LineSolid across grid on / off / off\
 without axes / on" [list [dict get [xschem get selection_look] style] $seen] \
    [list $look {{0 0 0} {0 0 0} {0 0 0} {0 0 0}}]
}
set selection_style brightbox; xschem build_colors
xschem set modified 0
check "U1 no untitled backup was left in the directory xschem started in" \
  [lsort [glob -nocomplain -directory [pwd] untitled*]] $here_untitled

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
