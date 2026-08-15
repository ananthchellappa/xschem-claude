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
#   ./src/xschem --pipe -q --script tests/headless/test_flylines_render.tcl
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

# a RESTING selection is not a gesture: the star must still draw (the gesture-mask that keeps a
# mid-drag erase from tearing the rubber-band must not also suppress fly-lines under a selection).
labels 0 200
xschem unselect_all; xschem select_at 0 0; update idletasks
hover 0 0
check "B3 selection active -> star still drawn"     [expr {[shown] eq "CLK"}] "shown=[shown]"
xschem unselect_all; update idletasks

# ---- H1: the DRAWN star origin is the cursor point on the hovered object ----
# hub-at-cursor (plan H0/H1): observe the actual drawn origin (fly_seg[0..1]) via
# `xschem flylines origin`, which the `shown` net name cannot expose. Here each hover is a
# NET CHANGE (through empty), so the full-recompute path draws the origin at the cursor.
proc wire_net {} {   ;# wire named CLK by a label at its left end + a far CLK label -> 2 clusters
  xschem clear force
  xschem wire 0 0 200 0
  xschem instance lab_pin.sym 0   0 0 0 {name=l1 lab=CLK}
  xschem instance lab_pin.sym 500 0 0 0 {name=l2 lab=CLK}
  xschem unselect_all; xschem zoom_full; update idletasks
}
proc origin {} { xschem flylines origin }
proc ox {} { set o [xschem flylines origin]; expr {$o eq "" ? "" : [lindex $o 0]} }

wire_net
hover 60 5
check "H1 hover wire @60 -> shown CLK"        [expr {[shown] eq "CLK"}]           "shown=[shown]"
set o [ox]
check "H1 drawn origin tracks cursor @60"     [expr {$o ne "" && abs($o-60) < 6}] "origin=[origin]"
hover 100000 100000                            ;# leave the net -> star erased
check "H1 hover empty -> origin cleared"      [expr {[origin] eq ""}]             "origin=[origin]"
hover 150 5                                    ;# NET CHANGE back onto the wire, cursor at 150
set o [ox]
check "H1 drawn origin tracks cursor @150"    [expr {$o ne "" && abs($o-150) < 6}] "origin=[origin]"

# ---- H2: within ONE net the origin TRACKS the pointer (cheap slide, no re-cluster) ----
# Moving along the SAME wire (same net, no empty between hovers) slides the drawn origin under the
# cursor via the cheap path (recompute hub point + rebuild fly_seg, NO re-clustering). Without H2
# the same-net short-circuit would freeze the origin at the first-hover point.
wire_net
hover 100000 100000                            ;# drop any stale star -> the seed is a clean recompute
hover 60 5                                     ;# NET CHANGE empty->CLK: full recompute seeds hub=wire
set o [ox]
check "H2 seed hover @60 -> origin ~60"        [expr {$o ne "" && abs($o-60) < 6}]  "origin=[origin]"
hover 150 5                                     ;# SAME net, same wire hub -> cheap origin slide
check "H2 same-net slide -> shown still CLK"   [expr {[shown] eq "CLK"}]             "shown=[shown]"
set o [ox]
check "H2 same-net slide -> origin follows ~150" [expr {$o ne "" && abs($o-150) < 6}] "origin=[origin]"
hover 30 5                                      ;# slide back the other way, still one net
set o [ox]
check "H2 same-net slide back -> origin ~30"   [expr {$o ne "" && abs($o-30) < 6}]  "origin=[origin]"

# same net, DIFFERENT cluster: moving off the hub cluster onto the far label (both CLK) must
# RECOMPUTE and flip the hub -- NOT cheap-slide within the stale cluster. seg0 exposes the
# destination too, so an over-broad hub-cluster match (which would keep a stale destination)
# is caught. wire_net: wire cluster anchored at the near label (0,0), far CLK label at (500,0).
wire_net
hover 100000 100000
hover 60 5                                      ;# hub = wire cluster; seg0 = ~{60 0  500 0}
set s [xschem flylines seg0]
check "H2 hub=wire cluster -> seg0 dest is the far label (500,0)" \
  [expr {[llength $s]==4 && abs([lindex $s 2]-500)<6 && abs([lindex $s 3]-0)<6}] "seg0=$s"
hover 500 0                                      ;# SAME net CLK, the far label = a DIFFERENT cluster
set s [xschem flylines seg0]
check "H2 cross-cluster recompute -> hub flips: origin=label(500), dest=other cluster(0)" \
  [expr {[llength $s]==4 && abs([lindex $s 0]-500)<6 && abs([lindex $s 2]-0)<6}] "seg0=$s"

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
