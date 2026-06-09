# Phase 3c (c4/c5): proves the 'f' key's graph-vs-canvas routing is now DATA
# (a DEV_KEY dispatch at the top of handle_key_press consults the binding table:
# canvas row -> view.zoom_full, over_graph row -> graph.forward) instead of the
# inline waves_selected guard that used to sit in the switch's case 'f'.
#
# Fires KeyPress events for 'f' (keysym 102) whose pointer lands (a) over a
# waveform graph -> routed to the graph, canvas zoom unchanged; (b) on bare
# canvas -> full zoom (canvas zoom changes).
# Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_key_graph_context.tcl
update idletasks
focus -force .drw

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# no-modifier key consults the graph only when graph_use_ctrl_key is off
set graph_use_ctrl_key 0

# load a schematic with a graph rect at schematic coords 540,-740 .. 1200,-340
set repo [file normalize [file join [file dirname [info script]] .. ..]]
xschem load [file join $repo xschem_library examples tb_test_evaluated_param.sch]
xschem zoom_full
update idletasks

# schematic -> screen pixel, recomputed live each call because zooming/panning
# shifts xorigin/yorigin/zoom and so moves the graph's screen position:
#   X_TO_XSCHEM(s) = s*zoom - origin  =>  s = (sch+origin)/zoom
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}
proc keyat  {x y ks} { xschem callback .drw 2 $x $y $ks 0 0 0; update idletasks }
proc wheelat {x y}   { xschem callback .drw 4 $x $y 0 4 0 0; update idletasks }
set F 102   ;# keysym for 'f'

# --- the data: 'f' rows exist (canvas->zoom_full, over_graph->forward), and
#     no migrated row for the Ctrl-f / Alt-f chords (they stay in the C switch) -
set dump [xschem bindings dump]
check "canvas f -> view.zoom_full row present" \
  [expr {[lsearch -exact $dump {key 102 0 canvas view.zoom_full}] >= 0}] {}
check "over_graph f -> graph.forward row present" \
  [expr {[lsearch -exact $dump {key 102 0 graph graph.forward}] >= 0}] {}
check "no Ctrl-f / Alt-f rows (still in C switch)" \
  [expr {[lsearch -glob $dump {key 102 ctrl *}] < 0 &&
         [lsearch -glob $dump {key 102 alt *}]  < 0}] {}

# perturb the canvas zoom away from "full" so a subsequent zoom_full is observable
lassign [screen 870 100] cx cy   ;# below the graph: bare canvas
wheelat $cx $cy                  ;# canvas wheel-up: zoom in
set zp [xschem get zoom]

# (a) 'f' over the graph forwards to the graph -> the *canvas* zoom does NOT change
lassign [screen 870 -540] gx gy  ;# center of the graph rect (live coords)
keyat $gx $gy $F
check "over-graph f leaves canvas zoom" [expr {[xschem get zoom] == $zp}] \
  "(z=$zp @ $gx,$gy)"

# (b) 'f' over bare canvas does a full zoom -> canvas zoom changes back from $zp
lassign [screen 870 100] cx cy   ;# live coords after step (a)
keyat $cx $cy $F
check "over-canvas f zooms full" [expr {[xschem get zoom] != $zp}] \
  "(zp=$zp z1=[xschem get zoom] @ $cx,$cy)"

# ---- arrow keys (Phase 3c c4/c5 batch 2): no-modifier scroll is data-driven ----
set Up 65362; set Down 65364; set Left 65361; set Right 65363
proc origin {} { list [xschem get zoom] [xschem get xorigin] [xschem get yorigin] }

# the data: all 4 arrows have canvas-scroll + over_graph-forward rows, and NO
# modified-arrow rows (Ctrl+Left/Right tab-switch etc. stay in the C switch)
check "arrow scroll rows present" [expr {
  [lsearch -exact $dump {key 65362 0 canvas view.scroll_up}]    >= 0 &&
  [lsearch -exact $dump {key 65363 0 canvas view.scroll_right}] >= 0 &&
  [lsearch -exact $dump {key 65362 0 graph graph.forward}]      >= 0 }] {}
check "no modified-arrow rows (still in C switch)" [expr {
  [lsearch -glob $dump {key 65361 ctrl *}] < 0 &&
  [lsearch -glob $dump {key 65363 ctrl *}] < 0 }] {}

# (c) Up arrow on bare canvas -> vertical scroll (yorigin moves; zoom & xorigin not)
lassign [screen 870 100] cx cy
lassign [origin] z0 x0 y0
keyat $cx $cy $Up
lassign [origin] z1 x1 y1
check "over-canvas Up = vertical scroll" [expr {$z1==$z0 && $x1==$x0 && $y1!=$y0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1)"

# (d) Right arrow on bare canvas -> horizontal scroll (xorigin moves; zoom & yorigin not)
lassign [screen 870 100] cx cy
lassign [origin] z0 x0 y0
keyat $cx $cy $Right
lassign [origin] z1 x1 y1
check "over-canvas Right = horizontal scroll" [expr {$z1==$z0 && $y1==$y0 && $x1!=$x0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1)"

# (e) Up arrow over the graph forwards to the graph -> the canvas origin does NOT move
lassign [screen 870 -540] gx gy
lassign [origin] z0 x0 y0
keyat $gx $gy $Up
lassign [origin] z1 x1 y1
check "over-graph Up leaves canvas origin" [expr {$z1==$z0 && $x1==$x0 && $y1==$y0}] \
  "(z:$z0->$z1 x:$x0->$x1 y:$y0->$y1 @ $gx,$gy)"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
