# Fluid editing: first-click tip/edge grab (Cadence direct manipulation).
# Spec doc/claude/specs/fluid_editing.md, plan doc/claude/suggestions/fluid_editing_session.md.
#
# Drives the REAL interactive gesture (press -> motion -> release) through
# `xschem callback`, then reads back object geometry via `saveas` + parse of the
# B/L/A file records. A first click-and-hold on an object's TIP (endpoint/vertex)
# or EDGE (corner/side), followed by a drag, must STRETCH only that sub-part --
# with no pre-select step and independent of enable_stretch -- when cadence_compat
# is set. A body click still moves the whole object; stock (cadence_compat=0)
# behaviour is untouched.
#
# NEEDS A REAL X DISPLAY (the gesture runs move_objects + Xlib drawtemp; under
# --nogui the callback path dereferences the absent .drw canvas and SIGSEGVs).
# So the automated --nogui run_regression harness would crash here -- this test
# SELF-SKIPS (prints OVERALL: ok and exits 0) when .drw is not viewable, and is
# meant to be run for real with a display:
#
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_fluid_editing.tcl
#
# RED-first: on a build without the C1 cond change, a first-click corner/endpoint
# grab does a WHOLE-OBJECT move (both ends translate), so FE1/FE2 (which assert the
# OPPOSITE end stays fixed) FAIL. FE1b is the stock-behaviour guard.

# ---------------------------------------------------------------------------
# X-availability gate: skip cleanly when there is no usable display (e.g. the
# --nogui regression harness), so this file is safe to register in hcases.
# ---------------------------------------------------------------------------
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
set HASX 1
if {[catch {winfo viewable $WIN} vv] || !$vv} { set HASX 0 }
if {!$HASX} {
  puts "SKIP: no viewable X window ($WIN) -- fluid-editing gesture test needs a real display"
  puts "RESULT: ALL PASS (0 checks, skipped: no X)"
  puts "OVERALL: ok"
  exit 0
}

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
proc feq {a b} { expr {abs($a - $b) < 1e-6} }
proc pt_in {px py pts} {
  foreach {x y} $pts { if {[feq $x $px] && [feq $y $py]} { return 1 } }
  return 0
}

# --- fixture: one rect, one line, one arc, placed far apart so a press hits exactly
#     one object. Rebuilt fresh per test so geometry never carries over.
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
# PHASE 1 -- C1: rect + line first-click grab under cadence_compat
# ===========================================================================

# ---- FE1: rect corner grab (cadence_compat=1) -----------------------------
setup_fixture
set ::cadence_compat 1
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

# ---- FE2: line endpoint grab (cadence_compat=1) ---------------------------
setup_fixture
set ::cadence_compat 1
set orig [line_ends]
check "FE2 pre: line has endpoints (600,0) and (800,0)" \
  [expr {[pt_in 600 0 $orig] && [pt_in 800 0 $orig]}] "(ends=$orig)"
lassign [sch2scr 600 0]  ex ey
lassign [sch2scr 640 40] tx ty
grab_drag $ex $ey $tx $ty
set now [line_ends]
check "FE2 other endpoint FIXED at (800,0)" [pt_in 800 0 $now] "(ends=$now)"
check "FE2 grabbed endpoint MOVED off (600,0)" [expr {![pt_in 600 0 $now]}] "(ends=$now)"

# ---- FE1b: stock guard -- cadence_compat=0 still does the two-step whole move ----
# (intuitive path on, cadence off): a first-click drag translates the WHOLE rect,
# so the opposite corner MOVES. Proves C1 leaves stock behaviour intact.
setup_fixture
set ::cadence_compat 0
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

# ---- FE3: arc endpoint grab (cadence_compat=1) ----------------------------
# Grab the start-angle endpoint (xa,ya) = (1300,0); drag it. The center must stay
# put and the start angle `a` must change. Today (no edit_arc_point) the press
# falls through to a WHOLE-object move: the center translates and `a` is unchanged.
setup_fixture
set ::cadence_compat 1
lassign [arc_geom] ax ay ar aa ab
check "FE3 pre: arc center (1200,0) r=100 a=0 b=90" \
  [expr {[feq $ax 1200] && [feq $ay 0] && [feq $ar 100] && [feq $aa 0] && [feq $ab 90]}] \
  "(arc=[arc_geom])"
# press on the start endpoint (1300,0), drag toward (1300,-50)
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
set ::cadence_compat 1
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
# Pressing on a side (not a corner) grabs that side's TWO corners, so the drag
# stretches the whole edge: the top corners move in y, the bottom edge stays put
# and the left/right x extents are unchanged. Today (corners only) the press falls
# through to a WHOLE move and the bottom edge translates too.
setup_fixture
set ::cadence_compat 1
lassign [sch2scr 100 0]   ex ey
lassign [sch2scr 100 -40] tx ty
grab_drag $ex $ey $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE4 bottom edge FIXED at y2=200" [feq $y2 200] "(bbox=[rect_bbox])"
check "FE4 top edge MOVED off y1=0"     [expr {![feq $y1 0]}] "(bbox=[rect_bbox])"
check "FE4 left/right x extents UNCHANGED (0,200)" \
  [expr {[feq $x1 0] && [feq $x2 200]}] "(bbox=[rect_bbox])"

# ---- FE4b: the grab works ANYWHERE along the side, not only the midpoint ----
# (press at 1/4 of the top edge). This distinguishes a full-edge grab from a
# midpoint-only zone.
setup_fixture
set ::cadence_compat 1
lassign [sch2scr 50 0]   ex ey
lassign [sch2scr 50 -40] tx ty
grab_drag $ex $ey $tx $ty
lassign [rect_bbox] x1 y1 x2 y2
check "FE4b quarter-point on top edge still grabs the edge (bottom fixed)" \
  [expr {[feq $y2 200] && ![feq $y1 0] && [feq $x1 0] && [feq $x2 200]}] "(bbox=[rect_bbox])"

# ---------------------------------------------------------------------------
file delete -force -- $::RBTMP
if {$::fails} { puts "RESULT: $::fails FAILED ($::npass passed)" } \
else          { puts "RESULT: ALL PASS ($::npass checks)" }
puts "OVERALL: [expr {$::fails ? {notok} : {ok}}]"
exit [expr {$::fails ? 1 : 0}]
