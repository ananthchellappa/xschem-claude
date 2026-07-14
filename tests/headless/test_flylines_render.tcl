# Hover fly-lines -- on-screen overlay (Track B), GUI/render path.
# doc/claude/specs/hover_flylines.md, suggestions/flyline_implementation_plan.md (B2/B3).
#
# The overlay exists only with a real canvas, so this drives the FULL Tk event sequence:
# `event generate $WIN <Motion>` fires the shipping .drw <Motion> binding
# ("xschem callback %W %T %x %y ...") -> callback() -> draw_flylines(), exactly like a real
# mouse move (gesture-test-full-sequence discipline: a bare synthetic call is not enough).
# Asserts on `xschem flylines shown` -- the net whose star is currently drawn.
#
# Needs a real X window. Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_flylines_render.tcl
# RED-first: without draw_flylines the shown-net never becomes CLK -> checks red.

set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
if {[catch {winfo viewable $WIN} vv] || !$vv} {
  puts "SKIP: no viewable X window ($WIN) -- fly-line render test needs a real display"
  puts "RESULT: SKIP (no X)"
  exit 0
}
update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} {incr ::fails}
}
# world -> screen (widget-relative px), inverse of X_TO_SCREEN (see test_dblclick_connected_grow)
proc screen {wx wy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  list [expr {int(($wx + $xo)/$z)}] [expr {int(($wy + $yo)/$z)}]
}
proc hover {wx wy} {
  global WIN
  lassign [screen $wx $wy] SX SY
  event generate $WIN <Motion> -x $SX -y $SY
  update idletasks
}
proc shown {} { xschem flylines shown }

# inline fixtures (xschem load would route to a new window under the GUI); mirror the
# tests/headless/flylines/*.sch fixtures with primitive commands.
proc labels {args} {
  xschem clear force
  set i 0
  foreach x $args { incr i; xschem instance lab_pin.sym $x 0 0 0 [list name=l$i lab=CLK] }
  xschem unselect_all; xschem zoom_full; update idletasks
}
proc wired_pair {} {
  xschem clear force
  xschem wire 0 0 200 0
  xschem instance lab_pin.sym 0   0 0 0 {name=l1 lab=CLK}
  xschem instance lab_pin.sym 200 0 0 0 {name=l2 lab=CLK}
  xschem unselect_all; xschem zoom_full; update idletasks
}
proc two_nets {} {           ;# CLK on the y=0 row, RST on the y=200 row (two implicit nets)
  xschem clear force
  xschem instance lab_pin.sym 0   0   0 0 {name=a1 lab=CLK}
  xschem instance lab_pin.sym 200 0   0 0 {name=a2 lab=CLK}
  xschem instance lab_pin.sym 0   200 0 0 {name=b1 lab=RST}
  xschem instance lab_pin.sym 200 200 0 0 {name=b2 lab=RST}
  xschem unselect_all; xschem zoom_full; update idletasks
}

# ---- B2: draw on hover; `shown` tracks the hovered net --------------------
set ::flylines 1

labels 0 200                       ;# two CLK labels, no wire -> 2 clusters -> 1 fly-line
hover 0 0
check "B2 hover a CLK label -> shown CLK" [expr {[shown] eq "CLK"}] "shown=[shown]"

hover 100000 100000                ;# empty space -> net changes to nothing
check "B2 hover empty -> shown {}" [expr {[shown] eq ""}] "shown=[shown]"

labels 0 200 400                   ;# three CLK labels -> 3 clusters -> 2 fly-lines
hover 0 0
check "B2 hover 3-cluster net -> shown CLK" [expr {[shown] eq "CLK"}] "shown=[shown]"

wired_pair                         ;# CLK on both labels but joined by a wire -> 1 cluster
hover 0 0
check "B2 implicit-only: wired pair -> nothing shown" [expr {[shown] eq ""}] "shown=[shown]"

labels 0 200                       ;# feature OFF -> no overlay even over a real net
set ::flylines 0
hover 0 0
check "B2 flylines off -> shown {}" [expr {[shown] eq ""}] "shown=[shown]"
set ::flylines 1

# ---- B3: erase-on-move, survive zoom, clear on <Leave> --------------------
two_nets
hover 0 0
check "B3 hover net A -> shown CLK"                 [expr {[shown] eq "CLK"}] "shown=[shown]"
hover 0 200
check "B3 move to net B -> shown RST (A star erased)" [expr {[shown] eq "RST"}] "shown=[shown]"
hover 100000 100000
check "B3 move to empty -> shown {}"                [expr {[shown] eq ""}]    "shown=[shown]"

hover 0 0
check "B3 re-hover A -> shown CLK"                  [expr {[shown] eq "CLK"}] "shown=[shown]"
xschem zoom_full; update idletasks
check "B3 shown survives zoom_full (re-stamped)"    [expr {[shown] eq "CLK"}] "shown=[shown]"

event generate $WIN <Leave>; update idletasks
check "B3 <Leave> -> shown {}"                      [expr {[shown] eq ""}]    "shown=[shown]"

# ---- C1 (render): hovering DRAWS but never mutates the schematic -----------
# The load-bearing invariant carried into the draw path (B0). Build a real net, clear the
# modified flag, hover so a star is actually drawn (shown==CLK), and confirm nothing changed:
# modified stays 0 and no net got highlighted (draw_flylines must not touch hilight_table).
proc hilight_nets {} {
  set n 0
  foreach l [split [xschem globals] "\n"] { if {[regexp {^hilight_nets=(\d+)} $l -> v]} {set n $v} }
  return $n
}
labels 0 200
xschem set_modify 0
hover 0 0
check "C1 render: hover drew the star (shown CLK)"       [expr {[shown] eq "CLK"}]          "shown=[shown]"
check "C1 render: hover left modified == 0"              [expr {[xschem get modified] == 0}] "modified=[xschem get modified]"
check "C1 render: hover highlighted nothing (read-only)" [expr {[hilight_nets] == 0}]        "hilight_nets=[hilight_nets]"

# ---------------------------------------------------------------------------
puts ""
if {$::fails == 0} {
  puts "RESULT: ALL PASS"
} else {
  puts "RESULT: $::fails FAILED"
}
