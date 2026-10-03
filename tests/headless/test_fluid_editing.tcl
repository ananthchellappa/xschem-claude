# Fluid editing: first-click tip/edge grab (Cadence direct manipulation).
# Spec doc/claude/specs/fluid_editing.md, plan doc/claude/suggestions/fluid_editing_session.md.
#
# Drives the REAL interactive gesture (press -> motion -> release) through
# `xschem callback`, then reads back object geometry via `saveas` + parse of the
# B/L/A file records. A first click-and-hold on an object's TIP (endpoint/vertex)
# or EDGE (corner/side), followed by a drag, must STRETCH only that sub-part --
# with no pre-select step and independent of enable_stretch -- when fluid_editing
# is on (C4: fluid_editing gates the grab; default = cadence_compat via the rc).
# A body click still moves the whole object; stock (fluid off) behaviour is untouched.
#
# NEEDS A REAL X DISPLAY (the gesture runs move_objects + Xlib drawtemp; under
# --nogui the callback path dereferences the absent .drw canvas and SIGSEGVs).
# So the automated --nogui run_regression harness would crash here -- this test
# SELF-SKIPS (prints OVERALL: ok and exits 0) when .drw is not viewable. That
# self-skip is a CRASH GUARD, not a registration decision: on the --nogui arm this
# file runs ZERO rows, so an hcases entry alone measures nothing (issue 1641).
# Run it for real with a display through the armed, gated, Xvfb-arm driver:
#
#   tests/headless/run_suites.sh test_fluid_editing
#
# NOT a bare ./src/xschem: that inherits $DISPLAY, which can be the user's own
# screen, and these rows drive real pointer gestures across it.
#
# RED-first: on a build without the grab, a first-click corner/endpoint grab does a
# WHOLE-OBJECT move (both ends translate), so FE1/FE2 (which assert the OPPOSITE end
# stays fixed) FAIL. FE1b is the stock-behaviour guard.

# ---------------------------------------------------------------------------
# X-availability gate: skip cleanly when there is no usable display (e.g. the
# --nogui regression harness), so this file does not SIGSEGV there. It makes the
# file safe to RUN in hcases; it does not make an hcases entry a FENCE, because
# zero rows run on that arm (issue 1641 -- the old wording here said "safe to
# register in hcases" and that was read as the registration decision).
# ---------------------------------------------------------------------------
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
set HASX 1
if {[catch {winfo viewable $WIN} vv] || !$vv} { set HASX 0 }
if {!$HASX} {
  puts "SKIP: no viewable X window ($WIN) -- fluid-editing gesture test needs a real display"
  puts "RESULT: SKIP (no X)"
  puts "OVERALL: ok"
  exit 0
}

# A STALL BOUND, below the gate on purpose. This suite drives the real gesture
# through `xschem callback`, which is the path issue 1375 hung on:
# descend_schematic() -> tcl_call("ask_save") -> a `tkwait` under --script that
# nothing can click. Sourced here it arms XSCHEM_SUITE_WATCHDOG_MS, so a hang
# that reaches the event loop becomes a NAMED outcome (rc 124, one line naming
# this file and the last row it printed) instead of silence. Row W20h of
# test_suite_watchdog_1403.tcl is what fails if this line is removed; W13 there
# records what the bound does NOT cover. BELOW the gate, not above it, so the
# self-skip path stays byte-identical under an unarmed HOME.
source [file join [file dirname [info script]] scratch.tcl]

update idletasks
catch { focus -force $WIN }
update idletasks

set ::fails 0
set ::npass 0
proc check {name ok {detail {}}} {
  if {$ok} { puts "ok:   $name"; incr ::npass } \
  else     { puts "FAIL: $name $detail : FAIL"; incr ::fails }
}

# schematic -> screen pixel: screen = (sch + origin) / zoom  (inverse of X_TO_XSCHEM)
proc sch2scr {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  return [list [expr {int(round(($sx + $xo)/$z))}] [expr {int(round(($sy + $yo)/$z))}]]
}
# screen pixel -> schematic: the INVERSE of sch2scr, i.e. where a press pixel really
# landed after sch2scr's rounding to a whole pixel. A gesture row aims in schematic
# units but the product only ever sees the pixel, so this is what the hit tests see
# (issue 1641: FE8 aimed at a point ON its arc and pressed a pixel 4 degrees off its end).
proc scr2sch {px py} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  return [list [expr {$px*$z - $xo}] [expr {$py*$z - $yo}]]
}

# --- gesture primitives (event codes: ButtonPress=4, MotionNotify=6, ButtonRelease=5;
#     state bit Button1Mask=256, ShiftMask=1). button arg = 1 for press/release, 0 for motion.
proc gpress   {sx sy {st 0}}   { xschem callback $::WIN 4 $sx $sy 0 1 0 $st }
proc gmotion  {sx sy {st 256}} { xschem callback $::WIN 6 $sx $sy 0 0 0 $st }
proc grelease {sx sy {st 256}} { xschem callback $::WIN 5 $sx $sy 0 1 0 $st }

# Full grab-drag from press-screen (psx,psy) to target-screen (tsx,tsy). Two motion
# events (midpoint + target) guarantee mouse_moved is set and move_objects(RUBBER)
# accumulates a non-zero deltax before the release commits via end_shape_point_edit.
proc grab_drag {psx psy tsx tsy {shift 0}} {
  set pst [expr {$shift ? 1 : 0}]
  set mst [expr {$shift ? 257 : 256}]
  gpress   $psx $psy $pst
  gmotion  [expr {($psx+$tsx)/2}] [expr {($psy+$tsy)/2}] $mst
  gmotion  $tsx $tsy $mst
  grelease $tsx $tsy $mst
  catch { update idletasks }
}

# --- geometry readback: dump the current buffer to a temp .sch and parse records.
set ::RBTMP "/tmp/xschem_fluid_rb_[pid].sch"
proc records {} {
  file delete -force -- $::RBTMP
  catch { xschem saveas $::RBTMP schematic }
  if {![file exists $::RBTMP]} { return {} }
  set fd [open $::RBTMP r]; set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
# record layouts: "B c x1 y1 x2 y2 {props}"  "L c x1 y1 x2 y2 {props}"  "A c x y r a b {props}"
proc rect_bbox  {} { foreach l [records] { if {[string match "B *" $l]} { return [lrange $l 2 5] } }; return {} }
proc line_ends  {} { foreach l [records] { if {[string match "L *" $l]} { return [lrange $l 2 5] } }; return {} }
proc arc_geom   {} { foreach l [records] { if {[string match "A *" $l]} { return [lrange $l 2 6] } }; return {} }
proc rects_all  {} { set o {}; foreach l [records] { if {[string match "B *" $l]} {lappend o $l} }; return $o }
proc feq {a b} { expr {abs($a - $b) < 1e-6} }
proc pt_in {px py pts} {
  foreach {x y} $pts { if {[feq $x $px] && [feq $y $py]} { return 1 } }
  return 0
}

# --- fixture: one rect, one line, one arc, placed far apart so a press hits exactly one
#     object. Rebuilt fresh per test. NOTE: gestures run at the pristine default zoom
#     (precise clicks + ample drag distance); the only test that zooms out (FE7) runs LAST
#     so its zoom -- which `clear force` does NOT reset -- never leaks into another test.
#       rect:  (0,0)-(200,200)      grab TL corner (0,0)        opposite = (200,200)
#       line:  (600,0)-(800,0)      grab end (600,0)            other end = (800,0)
#       arc:   center (1200,0) r=100 a=0 b=90                   ends (1300,0),(1200,-100)
proc setup_fixture {} {
  xschem set intuitive_interface 1
  set ::enable_stretch 0
  xschem clear force
  xschem rect 0 0 200 200
  xschem line 600 0 800 0
  xschem arc 1200 0 100 0 90 4
  xschem unselect_all
  catch { xschem redraw }
  catch { update idletasks }
}

# ===========================================================================
# PHASE 1 -- C1: rect + line first-click grab
# ===========================================================================

# ---- FE1: rect corner grab ------------------------------------------------
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 1
check "FE1 pre: rect starts at (0,0)-(200,200)" \
  [expr {[rect_bbox] eq {0 0 200 200}}] "(bbox=[rect_bbox])"
# press a few px inside the TL corner (into its ~7px grab zone, toward +x/+y),
# drag the corner to schematic (40,40).
lassign [sch2scr 0 0]  cx cy
lassign [sch2scr 40 40] tx ty
grab_drag [expr {$cx+3}] [expr {$cy+3}] $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE1 opposite corner FIXED at (200,200)" \
  [expr {[feq $x2 200] && [feq $y2 200]}] "(bbox=[rect_bbox])"
check "FE1 grabbed corner MOVED off (0,0)" \
  [expr {!([feq $x1 0] && [feq $y1 0])}] "(bbox=[rect_bbox])"

# ---- FE2: line endpoint grab ----------------------------------------------
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 1
set orig [line_ends]
check "FE2 pre: line has endpoints (600,0) and (800,0)" \
  [expr {[pt_in 600 0 $orig] && [pt_in 800 0 $orig]}] "(ends=$orig)"
lassign [sch2scr 600 0]  ex ey
lassign [sch2scr 640 40] tx ty
grab_drag $ex $ey $tx $ty
set now [line_ends]
check "FE2 other endpoint FIXED at (800,0)" [pt_in 800 0 $now] "(ends=$now)"
check "FE2 grabbed endpoint MOVED off (600,0)" [expr {![pt_in 600 0 $now]}] "(ends=$now)"

# ---- FE1b: stock guard -- fluid OFF still does the two-step whole move ----
setup_fixture
set ::cadence_compat 0; set ::fluid_editing 0
xschem set intuitive_interface 1
lassign [sch2scr 0 0]  cx cy
lassign [sch2scr 40 40] tx ty
grab_drag [expr {$cx+3}] [expr {$cy+3}] $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE1b stock: opposite corner MOVED (whole-object move preserved)" \
  [expr {!([feq $x2 200] && [feq $y2 200])}] "(bbox=[rect_bbox])"

# ===========================================================================
# PHASE 2 -- C2: arc angular-endpoint grab (edit_arc_point)
# ===========================================================================

# ---- FE3: arc endpoint grab -----------------------------------------------
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 1
lassign [arc_geom] ax ay ar aa ab
check "FE3 pre: arc center (1200,0) r=100 a=0 b=90" \
  [expr {[feq $ax 1200] && [feq $ay 0] && [feq $ar 100] && [feq $aa 0] && [feq $ab 90]}] \
  "(arc=[arc_geom])"
lassign [sch2scr 1300 0]   ex ey
lassign [sch2scr 1300 -50] tx ty
grab_drag $ex $ey $tx $ty
lassign [arc_geom] ax ay ar aa ab
check "FE3 arc center FIXED at (1200,0)" \
  [expr {[feq $ax 1200] && [feq $ay 0]}] "(arc=[arc_geom])"
check "FE3 arc start angle a CHANGED off 0" \
  [expr {![feq $aa 0]}] "(arc=[arc_geom])"

# ---- FE3c: arc stretch is UNDOABLE (move_objects owns the undo push) -------
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 1
lassign [sch2scr 1300 0]   ex ey
lassign [sch2scr 1300 -50] tx ty
grab_drag $ex $ey $tx $ty
set after_stretch [arc_geom]
catch { xschem undo }
catch { update idletasks }
check "FE3c undo restores the arc to (1200,0) r=100 a=0 b=90" \
  [expr {[arc_geom] eq {1200 0 100 0 90}}] "(after_stretch=$after_stretch undone=[arc_geom])"

# ===========================================================================
# PHASE 3 -- C3: rect edge (side) grab
# ===========================================================================

# ---- FE4: grab the TOP side at its midpoint, drag perpendicular ------------
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 1
lassign [sch2scr 100 0]   ex ey
lassign [sch2scr 100 -40] tx ty
grab_drag $ex $ey $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE4 bottom edge FIXED at y2=200" [feq $y2 200] "(bbox=[rect_bbox])"
check "FE4 top edge MOVED off y1=0"     [expr {![feq $y1 0]}] "(bbox=[rect_bbox])"
check "FE4 left/right x extents UNCHANGED (0,200)" \
  [expr {[feq $x1 0] && [feq $x2 200]}] "(bbox=[rect_bbox])"

# ---- FE4b: the grab works ANYWHERE along the side, not only the midpoint ----
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 1
lassign [sch2scr 50 0]   ex ey
lassign [sch2scr 50 -40] tx ty
grab_drag $ex $ey $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE4b quarter-point on top edge still grabs the edge (bottom fixed)" \
  [expr {[feq $y2 200] && ![feq $y1 0] && [feq $x1 0] && [feq $x2 200]}] "(bbox=[rect_bbox])"

# ===========================================================================
# REVIEW FIXES -- regressions guarding the adversarial-review findings
# ===========================================================================

# ---- FE5 (findings #4/#5): a modifier-held press near a handle is a Cadence copy(Shift)/
# detach(Ctrl) gesture, NOT a stretch. The shape-point editors must bail before setting
# shape_point_selected, else the copy/detach path (gated on !shape_point_selected) is
# skipped and the gesture silently no-ops. Shift+drag from near a rect corner must COPY.
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 1
check "FE5 pre: one rect present" [expr {[llength [rects_all]] == 1}] "(n=[llength [rects_all]])"
lassign [sch2scr 0 0]     cx cy
lassign [sch2scr 400 400] tx ty
grab_drag [expr {$cx+3}] [expr {$cy+3}] $tx $ty 1     ;# shift=1 -> Cadence copy
check "FE5 Shift+drag near a corner COPIES the rect (2 rects, not a stuck no-op)" \
  [expr {[llength [rects_all]] == 2}] "(n=[llength [rects_all]])"

# ---- FE6 (finding #1): arc grab is fluid-gated. With fluid OFF the stock two-step (arc
# already selected, then click-drag its endpoint) must MOVE THE WHOLE ARC, not stretch it.
setup_fixture
set ::cadence_compat 0; set ::fluid_editing 0
xschem set intuitive_interface 1
lassign [sch2scr 1300 0]  ex ey
gpress $ex $ey; grelease $ex $ey; catch {update idletasks}   ;# click 1: select the arc
check "FE6 pre: arc selected by first click" [expr {[llength [xschem selection]] == 1}] \
  "(sel=[xschem selection])"
lassign [sch2scr 1300 -60] tx ty
grab_drag $ex $ey $tx $ty                                    ;# click 2: press+drag endpoint
lassign [arc_geom] ax ay ar aa ab
check "FE6 stock two-step MOVES the whole arc (center shifts), not a stretch" \
  [expr {!([feq $ax 1200] && [feq $ay 0])}] "(arc=[arc_geom])"

# ===========================================================================
# C4 -- polish: line/wire endpoint tolerance + independent fluid_editing toggle
# ===========================================================================

# ---- FE9 (C4.1): line endpoint grab uses a tolerance ZONE, not an exact snap-match.
# An OFF-GRID endpoint can never be hit by exact snapping (the cursor always snaps to a
# grid cell that never equals it), so the pre-C4 exact match fell through to a whole-
# object move. The tolerance zone grabs it: grab the off-grid end, drag, and the OTHER
# end must stay fixed (a stretch, not a whole move).
xschem clear force
xschem set intuitive_interface 1
set ::cadence_compat 1; set ::fluid_editing 1
set ::enable_stretch 0
xschem line 605 3 800 3
xschem unselect_all; catch {xschem redraw}; catch {update idletasks}
set orig [line_ends]
check "FE9 pre: off-grid line ends (605,3) and (800,3)" \
  [expr {[pt_in 605 3 $orig] && [pt_in 800 3 $orig]}] "(ends=$orig)"
lassign [sch2scr 605 3]  ex ey
lassign [sch2scr 660 60] tx ty
grab_drag $ex $ey $tx $ty
set now [line_ends]
check "FE9 tolerance grab of an OFF-GRID endpoint (other end (800,3) FIXED)" \
  [pt_in 800 3 $now] "(ends=$now)"

# ---- FE10 (C4.3): the grab is gated on fluid_editing, INDEPENDENT of cadence_compat.
# (a) cadence ON, fluid OFF -> first-click corner does NOT grab: the rect's SIZE is
# preserved (a corner stretch would shrink it; a whole-move or no-op keeps 200x200).
setup_fixture
set ::cadence_compat 1; set ::fluid_editing 0
lassign [sch2scr 0 0]  cx cy
lassign [sch2scr 40 40] tx ty
grab_drag [expr {$cx+3}] [expr {$cy+3}] $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE10a cadence ON + fluid OFF: first-click corner does NOT stretch (size 200x200 kept)" \
  [expr {[feq [expr {$x2-$x1}] 200] && [feq [expr {$y2-$y1}] 200]}] "(bbox=[rect_bbox])"
# (b) cadence OFF, fluid ON -> first-click corner DOES grab. Grab signature = grabbed
# corner moved AND opposite fixed (a no-op or whole-move fails one clause).
setup_fixture
set ::cadence_compat 0; set ::fluid_editing 1
xschem set intuitive_interface 1
lassign [sch2scr 0 0]  cx cy
lassign [sch2scr 40 40] tx ty
grab_drag [expr {$cx+3}] [expr {$cy+3}] $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE10b cadence OFF + fluid ON: first-click corner GRABS (corner moved, opposite fixed)" \
  [expr {!([feq $x1 0] && [feq $y1 0]) && [feq $x2 200] && [feq $y2 200]}] "(bbox=[rect_bbox])"

# ---- FE7 (finding #2) runs LAST: it zooms out (zoom_box), and `clear force` does NOT
# reset zoom, so keeping it last leaves every other gesture test at the pristine default
# zoom (precise clicks + ample drag distance). Edge bands are enabled only when the rect
# is thicker than 2*ds in that direction, so a rect THIN in one dimension keeps a movable
# interior. Use a wide-but-short bar: W (=20*Z) >> 2*ds so its center is clear of the
# left/right corner+edge zones, but H (=8*Z) < 2*ds. Pressing the bar's CENTER must MOVE
# THE WHOLE bar (all 4 coords change). On the pre-fix code the full-span top band covers
# the whole interior-y, so the center press grabs the top edge and only deforms y1 (a bar
# that cannot be moved, only reshaped). ds = cadhalfdotsize*2*zoom = 7.4*Z (cadsnap=10).
xschem clear force
xschem set intuitive_interface 1
set ::cadence_compat 1; set ::fluid_editing 1
xschem zoom_box -6000 -6000 6000 6000
set Z [xschem get zoom]
set W [expr {20.0 * $Z}]        ;# >> 2*ds (=14.8*Z): center is clear of corner/left/right zones
set H [expr {8.0 * $Z}]         ;# <  2*ds: top+bottom bands would blanket the interior-y
xschem rect 0 0 $W $H
xschem unselect_all; catch {xschem redraw}; catch {update idletasks}
set orig [rect_bbox]
lassign [sch2scr [expr {$W/2.0}] [expr {$H/2.0}]] cx cy
grab_drag $cx $cy [expr {$cx+25}] [expr {$cy+25}]            ;# 25px screen drag, both axes
lassign [rect_bbox] x1 y1 x2 y2
lassign $orig ox1 oy1 ox2 oy2
check "FE7 thin bar: body drag MOVES WHOLE bar (all 4 coords change, not an edge deform)" \
  [expr {![feq $x1 $ox1] && ![feq $y1 $oy1] && ![feq $x2 $ox2] && ![feq $y2 $oy2]}] \
  "(orig=$orig now=[rect_bbox] Z=$Z W=$W H=$H)"


# ---- arc press diagnostics (issue 1641) ------------------------------------
# edit_arc_point's control-point handle is a box of half-size ds = cadhalfdotsize*2*zoom
# around each angular endpoint. cadhalfdotsize is READ FROM THE PRODUCT rather than
# restated here: a constant copied into a test is a number nothing re-checks, and this
# one moves with cadsnap (set_dotsize_from_snap). Returns {} if it cannot be read.
proc cad_ds {} {
  set v {}
  catch {
    foreach ln [split [xschem globals] \n] {
      if {[regexp {^cadhalfdotsize=([-0-9.eE+]+)$} $ln -> m]} { set v $m }
    }
  }
  if {$v eq {}} { return {} }
  return [expr {$v * 2.0 * [xschem get zoom]}]
}
# Where a press PIXEL really lands relative to the current arc, stated in the terms the
# two hit tests use. This exists so a future break prints its CAUSE: FE8's old detail
# printed `a=30`, which is the arc's own STARTING angle, so "the fix regressed" and "the
# click missed the arc" were the same string (issue 1641 cost a full day to that).
#   find_closest_arc (does the press SELECT the arc): radial |r_press - r| against
#     CADWIREMINDIST*zoom*tk_scaling, which GROWS as you zoom out, and the span test
#     `a <= angle <= a+b`, which has NO angular tolerance at all (1641 open item 3).
#   edit_arc_point (WHICH control point): the `a+b` end is tested FIRST, so a press that
#     also falls in that handle box grabs SELECTED3 and changes `b`, leaving `a` alone.
proc arc_press_diag {px py} {
  lassign [arc_geom] cx cy r a b
  if {$cx eq {}} { return "no arc in the buffer" }
  set pi [expr {acos(-1)}]
  set z [xschem get zoom]
  set ds [cad_ds]
  lassign [scr2sch $px $py] sx sy
  set ang [expr {fmod(atan2($cy - $sy, $sx - $cx)*180.0/$pi, 360.0)}]
  if {$ang < 0} { set ang [expr {$ang + 360.0}] }
  set d [format "press px (%d,%d) -> sch (%.1f,%.1f): angle %.1f vs span %g..%g, r %.1f vs %g" \
           $px $py $sx $sy $ang $a [expr {$a+$b}] [expr {hypot($sx-$cx, $sy-$cy)}] $r]
  if {$ds ne {}} {
    set xb [expr {$cx + $r*cos(($a+$b)*$pi/180.0)}]
    append d [format ", clear of the a+b handle box by %.2f px" [expr {($sx - ($xb+$ds))/$z}]]
  }
  return $d
}
# Press point for the `a` control point of the current arc, DERIVED from that arc's own
# geometry at the live zoom instead of written down as a schematic coordinate. Why it is
# not simply the endpoint (issue 1641, measured):
#   * sch2scr rounds to a whole pixel, and one pixel is `zoom` schematic units, so a press
#     aimed exactly at the endpoint lands up to ~0.71 px away. At this row's zoom-out that
#     is ~7 degrees of a radius-100 arc, and the span test has no tolerance, so an error
#     pointing OUTWARD of `a` misses the arc and the press selects NOTHING. (FE3's arc
#     survives the same rounding only because it has a=0, where the error points inward.)
#   * so bias INWARD by twice that worst-case angle: dth = asin(0.71*zoom/R).
#   * and aim at R = r + 4 px rather than on the ring. Outward both shrinks dth and pushes
#     the press clear of the `a+b` handle box in x -- which must be escaped, or
#     edit_arc_point grabs the OTHER control point. The press stays inside the `a` handle
#     box and inside find_closest_arc's radial slack, i.e. it is a real control-point grab.
# Returns the screen pixel.
proc arc_a_press_px {} {
  lassign [arc_geom] cx cy r a b
  set pi [expr {acos(-1)}]
  set z [xschem get zoom]
  set R [expr {$r + 4.0*$z}]
  set dth [expr {asin(0.71*$z/$R)*180.0/$pi}]
  set ang [expr {$a + 2.0*$dth}]
  return [sch2scr [expr {$cx + $R*cos($ang*$pi/180.0)}] [expr {$cy - $R*sin($ang*$pi/180.0)}]]
}

# Tcl mirror of my_round() in actions.c -- C89 has no round(), so the product rounds
# half AWAY FROM ZERO, which Tcl's round() also does but int() and floor() do not.
# Both the snap grid and the committed arc angle go through it, so the derivation below
# must use the same rule or it disagrees with the product on every .5 case.
proc my_round_c {v} {
  expr {$v > 0.0 ? floor($v + 0.5) : ($v < 0.0 ? ceil($v - 0.5) : $v)}
}
# The start angle `a` that move_objects COMMITS for an `a` control-point drag released at
# screen pixel (relpx,relpy), DERIVED from the product's own arithmetic instead of written
# down. Why a row must assert the committed VALUE and not merely that `a` left its start:
# a sabotage that committed a constant garbage angle on EVERY arc control-point drag passed
# every row this suite then had, because all three of its arc assertions were of the form
# "a is no longer its starting value" -- which any wrong-but-different number satisfies
# (issue 1641; CLAUDE.md "prefer asserting the correct shape over asserting a wrong one's
# absence"). The chain, by symbol, in the order the product applies it:
#   callback()            mousex = X_TO_XSCHEM(px), i.e. scr2sch above;
#                         mousex_snap = my_round(mousex/cadsnap)*cadsnap
#   move_objects(START)   for a LONE arc whose sel != SELECTED the move reference x1,y1 is
#                         the arc's CENTRE, not the mouse -- which is FE8's whole subject
#   move_objects(END)     arc sel == SELECTED2:
#                         a = my_round(fmod(atan2(-deltay,deltax)*180/PI + a, 360)), >= 0
# cadsnap is read from the live interpreter (this suite runs INSIDE xschem), never restated
# as a constant. Returns {} if cadsnap is unreadable or non-positive, so the caller fails
# loudly rather than comparing against a silently wrong number. Assumes the schematic snap
# grid applies, i.e. not a no_snap canvas (true of a schematic window; the ASE waveform
# viewer sets no_snap and has no arcs).
proc arc_expected_a {cx cy a relpx relpy} {
  if {![info exists ::cadsnap]} { return {} }
  if {![string is double -strict $::cadsnap] || $::cadsnap <= 0} { return {} }
  set pi [expr {acos(-1)}]
  set snap [expr {double($::cadsnap)}]
  lassign [scr2sch $relpx $relpy] rx ry
  set sx [expr {[my_round_c [expr {$rx/$snap}]]*$snap}]
  set sy [expr {[my_round_c [expr {$ry/$snap}]]*$snap}]
  set ang [my_round_c [expr {fmod(atan2(-($sy-$cy), $sx-$cx)*180.0/$pi + $a, 360.0)}]]
  if {$ang < 0} { set ang [expr {$ang + 360.0}] }
  return $ang
}

# ---- FE8 (finding #3) runs LAST (after FE7) because it zooms out and `clear force` does
# NOT reset zoom, so keeping it here stops that zoom leaking into another row. It does NOT
# run here because it needs the zoom: the sentence that used to say so had it backwards --
# the zoom-out is what made the old press point unhittable (issue 1641, measured).
# ---- FE8 (finding #3): an arc control-point drag that changes geometry must leave the
# buffer MODIFIED even when the release snaps to the press cell. The arc move reference is
# its CENTER (not the mouse), so the old "release-cell==press-cell" no-op test wrongly reset
# the modified flag to clean after a real change (a lost edit on close-without-save).
xschem clear force
xschem set intuitive_interface 1
set ::cadence_compat 1; set ::fluid_editing 1
xschem arc 1200 0 100 30 90 4                                ;# start angle a=30 (nonzero)
# Zoom out for a big grab zone: ds and find_closest_arc's radial slack both scale with
# zoom. It does NOT make the endpoint easier to hit -- the span test has no zoom term, so
# zooming out makes one pixel ~6 degrees of this arc (issue 1641). The press below is
# derived to survive that.
xschem zoom_box -6000 -6000 6000 6000
xschem unselect_all
xschem saveas $::RBTMP schematic                             ;# named + clean: modified -> 0
catch {update idletasks}
check "FE8 pre: buffer clean (modified=0), arc a=30" \
  [expr {[xschem get modified] == 0 && [feq [lindex [arc_geom] 3] 30]}] \
  "(mod=[xschem get modified] arc=[arc_geom])"
# Grab the `a` control point. The press pixel is DERIVED from the arc (arc_a_press_px)
# rather than written down: this row used to aim at the exact endpoint, (1286.6,-50), and
# at this zoom sch2scr rounded that onto a pixel 4.3 degrees BELOW the arc's own start
# angle, so the press selected nothing and FE8 was red while the behaviour it fences was
# intact (issue 1641). A hardcoded pixel would be the same rot one level up -- and the
# zoom-out on the line above, added to make this endpoint EASIER to hit, is what made the
# old spelling unhittable.
lassign [arc_a_press_px] ex ey
# drag away: the same radius at the far end of the span, so the angle really sweeps.
lassign [arc_geom] fe8_cx fe8_cy fe8_r fe8_sa fe8_sb
set fe8_pi [expr {acos(-1)}]
set fe8_R  [expr {$fe8_r + 4.0*[xschem get zoom]}]
lassign [sch2scr [expr {$fe8_cx + $fe8_R*cos(($fe8_sa+$fe8_sb)*$fe8_pi/180.0)}] \
                 [expr {$fe8_cy - $fe8_R*sin(($fe8_sa+$fe8_sb)*$fe8_pi/180.0)}]] fx fy
# The aim is diagnosed BEFORE the press, because arc_geom does a `saveas` and that clears
# `modified` -- the very flag FE8 is about.
set fe8_aim [arc_press_diag $ex $ey]
gpress   $ex $ey
# FE8a: the press must actually SELECT the arc. Without this, FE8 below cannot tell a
# regression from a missed click: both leave the arc at its starting angle (issue 1641).
set fe8_sel [xschem get lastsel]
check "FE8a the press SELECTED the arc (lastsel=1), so the gesture below ran at all" \
  [expr {$fe8_sel == 1}] \
  "(lastsel=$fe8_sel -- 0 means THE PRESS SELECTED NOTHING, so no gesture happened and\
FE8's verdict says nothing about the false-clean; $fe8_aim)"
gmotion  $fx $fy                                             ;# drag away (angle changes)
gmotion  $ex $ey                                             ;# drag BACK to the press cell
grelease $ex $ey                                             ;# release in the press cell
catch {update idletasks}
set fe8_mod [xschem get modified]                            ;# capture BEFORE arc_geom (saveas clears it)
set fe8_rec [arc_geom]
set fe8_a   [lindex $fe8_rec 3]
# The cause clause is COMPUTED, not asserted unconditionally. The unconditional wording this
# replaces said "a is the starting angle, so the gesture never happened" -- and printed that
# in the one state FE8 exists to catch, where `a` HAS moved and the flag is the thing that is
# wrong. A detail written to stop a sentinel being misread must not itself misread it.
if {![feq $fe8_a $fe8_sa]} {
  set fe8_why "a MOVED $fe8_sa -> $fe8_a, so the geometry really changed: with mod=$fe8_mod\
this IS the false-clean this row exists for"
} elseif {$fe8_sel != 1} {
  set fe8_why "a is STILL the starting angle ($fe8_sa) and lastsel=$fe8_sel, so the press\
selected nothing and no gesture happened -- a MISSED PRESS, not a false-clean"
} else {
  set fe8_why "a is STILL the starting angle ($fe8_sa) but lastsel=1, so the press DID\
select and the gesture ran yet left `a` alone -- FE8b below says which control point it got"
}
check "FE8 drag-and-return changed the arc AND left buffer MODIFIED (no false-clean)" \
  [expr {$fe8_mod == 1 && ![feq $fe8_a $fe8_sa]}] \
  "(mod=$fe8_mod a=$fe8_a; $fe8_why; $fe8_aim)"
# FE8b: and the committed angle must be the RIGHT one. FE8 above, FE3 and FE3c all only ask
# that `a` is no longer its starting value, so a constant garbage angle committed on every arc
# control-point drag passes every one of them (measured, issue 1641). This row asserts the
# whole arc record against the one derived from move_objects' own END arithmetic: the centre,
# radius and `b` must be untouched (a press that drifted into the `a+b` handle box moves `b`
# instead -- edit_arc_point tests that box FIRST) and `a` must equal arc_expected_a.
set fe8_exp [arc_expected_a $fe8_cx $fe8_cy $fe8_sa $ex $ey]
lassign $fe8_rec fe8_gx fe8_gy fe8_gr fe8_ga fe8_gb
check "FE8b committed arc == the record derived from move_objects' own arc-END arithmetic" \
  [expr {$fe8_exp ne {} && [feq $fe8_gx $fe8_cx] && [feq $fe8_gy $fe8_cy] &&
         [feq $fe8_gr $fe8_r] && [feq $fe8_ga $fe8_exp] && [feq $fe8_gb $fe8_sb]}] \
  "(arc=$fe8_rec; derived=[list $fe8_cx $fe8_cy $fe8_r $fe8_exp $fe8_sb]; a expected\
$fe8_exp got $fe8_ga, b expected $fe8_sb got $fe8_gb -- a wrong `a` with everything else\
intact is a WRONG ANGLE COMMITTED, a moved `b` with `a` unmoved means the press grabbed the\
OTHER control point; an empty derived value means cadsnap could not be read; $fe8_aim)"

# ---------------------------------------------------------------------------
file delete -force -- $::RBTMP
if {$::fails} { puts "RESULT: $::fails FAILED ($::npass passed)" } \
else          { puts "RESULT: ALL PASS ($::npass checks)" }
puts "OVERALL: [expr {$::fails ? {notok} : {ok}}]"
exit [expr {$::fails ? 1 : 0}]
