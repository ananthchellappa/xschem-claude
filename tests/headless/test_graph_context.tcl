# Phase 3c (c1+c3): proves the wheel's graph-vs-canvas routing is now DATA
# (over_graph rows -> graph.forward) instead of inline waves_selected guards.
# Loads a schematic containing a waveform graph and fires wheel events whose
# pointer lands (a) over the graph -> routed to the graph, canvas zoom unchanged;
# (b) on bare canvas -> normal canvas zoom.
# Run under X with --pipe:
#   ./src/xschem --pipe --script tests/headless/test_graph_context.tcl
update idletasks
focus -force .drw

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# no-modifier wheel consults the graph only when graph_use_ctrl_key is off
set graph_use_ctrl_key 0

# load a schematic with a graph rect at schematic coords 540,-740 .. 1200,-340
set repo [file normalize [file join [file dirname [info script]] .. ..]]
xschem load [file join $repo xschem_library examples tb_test_evaluated_param.sch]
xschem zoom_full
update idletasks

# schematic -> screen pixel:  X_TO_XSCHEM(s) = s*zoom - origin  =>  s = (sch+origin)/zoom
set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
proc screen {sx sy} { global xo yo zm; list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}] }
proc wheelat {x y} { xschem callback .drw 4 $x $y 0 4 0 0; update idletasks }

lassign [screen 870 -540] gx gy   ;# center of the graph rect
lassign [screen 870 100]  cx cy   ;# below the graph: bare canvas

# the data: over_graph rows exist
set dump [xschem bindings dump]
check "over_graph wheel rows present" [expr {
  [lsearch -exact $dump {wheel up 0 graph graph.forward}] >= 0 &&
  [lsearch -exact $dump {wheel up shift graph graph.forward}] >= 0 }] {}

# (a) wheel over the graph routes to the graph -> the *canvas* zoom does not change
set z0 [xschem get zoom]
wheelat $gx $gy
check "over-graph wheel leaves canvas zoom" [expr {[xschem get zoom] == $z0}] "(z=$z0 @ $gx,$gy)"

# (b) wheel over bare canvas zooms the canvas as usual
set z0 [xschem get zoom]
wheelat $cx $cy
check "over-canvas wheel zooms canvas" [expr {[xschem get zoom] != $z0}] "(z0=$z0 z1=[xschem get zoom] @ $cx,$cy)"

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
