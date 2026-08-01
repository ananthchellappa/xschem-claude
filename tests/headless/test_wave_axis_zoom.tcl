# tests/headless/test_wave_axis_zoom.tcl — AXIS-REGION DRAG ZOOM (issue 0190)
#
# Spec: doc/claude/specs/waveform_viewer_modes.md §17 (and §15.1's ownership
# table, which grew two rows for it).
# Decision doc: doc/claude/code_analysis/ovb01_03_axis_region_drag_zoom_decision.md
#
# THE FEATURE. An LMB press-and-drag in a waveform strip's AXIS-NUMBER MARGIN
# zooms that axis only: the bottom margin (where the X tick numbers are drawn)
# zooms X, the left margin (the Y tick numbers) zooms Y. A FORWARD drag (X left
# to right, Y upward) zooms IN to exactly the two data coordinates the press and
# the release land on. A REVERSE drag zooms OUT by the one anchored linear map
# that puts the CURRENT window back between those two screen positions:
#     R2 = R / |s|,   lo = A - ub * R2,   hi = lo + R2
# where A/B is the current window, R = B - A, and ua/ub are the press/release
# normalised into it. BOTH ENDPOINTS MATTER: a width-only implementation slides
# the window sideways and still passes every "the range grew" assertion, which
# is why every reverse leg here asserts lo and hi separately.
#
# THREE C FUNCTIONS, and the split is the point (draw.c):
#   graph_axis_at()   which margin a canvas pixel is in     -> `xschem get graph_axis_at`
#   graph_axis_map()  THE formula, in exactly one place     -> `xschem get graph_axis_map`
#   graph_axis_zoom() THE apply, shared by the gesture and  -> `xschem graph_axis_zoom`
#                     by the replayable verb
# `xschem get graph_axis_drag` is the "what did that press arm" signal the ASE
# viewer's press seam consults (wviewer::axis_grabbed) instead of hit-testing
# the margins in Tcl.
#
# SEVEN GROUPS:
#   AZ*  the region query. BOTH arms. Every pixel is DERIVED from the engine's
#        own answers — the plot box comes from graph_plotbox_at, the container
#        band from the engine's zoom/origin — and never predicted from
#        `0.14 * rh`. Re-scanned after anything that zooms.
#   AM*  the map. BOTH arms. Every expectation is computed IN TCL from the
#        closed form, using `xschem graph_coord` as an INDEPENDENT pixel->data
#        transform (a different C function; the arithmetic under test is the
#        anchored map, not the transform).
#   AV*  the apply / the verb. BOTH arms. Witnesses EVERY rect, not the one
#        addressed — X propagates and Y does not, and a one-rect witness cannot
#        see the difference.
#   AL*  the replay log line. BOTH arms, in a `--logdir` CHILD PROCESS: this
#        suite runs `--nolog`, so a child is the only honest way to assert a
#        C self-logged line. AL4 REPLAYS the line in a second child.
#   AS*  source-level tripwire. BOTH arms. The anchored zoom-out expression
#        appears in draw.c exactly ONCE and graph_axis_map() is CALLED exactly
#        once from callback.c and once from scheduler.c — landmine 45(a): a
#        gesture and a verb that each carry their own copy of a formula will
#        drift, and no behavioural leg can see it while they still agree.
#   AG*  the real C gesture on an on-canvas schematic graph. DISPLAY only.
#        Drives `xschem callback .drw <T> <px> <py> 0 <b> 0 <s>` directly
#        (X11 event codes: 2 KeyPress, 4 ButtonPress, 5 ButtonRelease,
#        6 MotionNotify; 256 = Button1Mask), replaying the WHOLE sequence.
#   AX*  the ASE viewer seam. DISPLAY only. Real viewer, shipped bindings, and
#        an INERT per-strip `sdid` witness so "which strip is at index k" is
#        independent of "what is in it".
#
# NOT ASSERTED (the eyeball list, decision doc §10): the rubber band's pixels,
# the drag feel, whether the tick labels are legible after a zoom, the (absent)
# pointer-cursor change during the drag, and whether losing the axis margins
# from the viewer's strip reorder is noticeable in use.
#
# Standalone repro:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_axis_zoom.tcl
#   ./src/xschem         --pipe -q --nolog --script tests/headless/test_wave_axis_zoom.tcl
# Auto-discovered by tests/headless/full_audit.sh (it globs test_*.tcl); it
# needs no logdir_tests registration because the log leg spawns its own child.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# NEVER THROWS: almost every call site hands this the result of pcall/pexpr,
# which is the string ERR:<msg> when the inner script blew up -- and
# `expr {"ERR:..." ? 1 : 0}` raises at top level and would abort the whole file
# through the outer catch, silently dropping every leg after it.
proc check_true {name cond} {
  if {[catch {expr {$cond ? 1 : 0}} v]} { check $name "NOT-A-BOOLEAN {$cond}" 1; return }
  check $name $v 1
}
proc note {msg} { puts "  note: $msg" }
# the loud, greppable "this leg could not be staged" marker
proc stall {msg} { puts "  AXIS-TEST-STALL: $msg" }
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}
proc pexpr {e} {
  if {[catch {uplevel 1 [list expr $e]} r]} { return "ERR:$r" }
  return $r
}
# relative closeness, guarded against a non-numeric operand (a getter that
# answered {} because the leg before it failed)
proc az_close {a b rtol {scale {}}} {
  if {![string is double -strict $a] || ![string is double -strict $b]} { return 0 }
  if {$scale eq {} || ![string is double -strict $scale] || $scale == 0.0} {
    set scale [expr {abs($b) > 1e-300 ? abs($b) : 1.0}]
  }
  return [expr {abs($a - $b) <= $rtol * abs($scale) ? 1 : 0}]
}

# recent-files gate (issue 0119)
set no_recent_files 1

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvaxis]

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

# --- which ARM is this, and did we get the one that was asked for? ----------
# A --pipe run under a DISPLAY whose X server was momentarily unreachable comes
# up text-only and runs the same reduced set as --nogui, printing a perfectly
# happy ALL PASS. Tell the two apart from the process's OWN command line.
set ::az_nogui 0
if {![catch {open /proc/self/cmdline rb} azfh]} {
  set ::az_nogui [expr {[lsearch -exact [split [read $azfh] "\0"] --nogui] >= 0}]
  close $azfh
}
set ::az_want_x [expr {!$::az_nogui && [info exists ::env(DISPLAY)] && $::env(DISPLAY) ne {}}]
set ::az_have_x [expr {[info exists ::has_x] && [info commands winfo] ne {}}]
check "AA0 the arm that ran is the arm that was asked for\
 (--nogui=$::az_nogui DISPLAY-wanted=$::az_want_x has_x=$::az_have_x)" \
  [expr {$::az_want_x && !$::az_have_x ? {X ARM REQUESTED BUT XSCHEM CAME UP HEADLESS} : {ok}}] ok

if {[catch {

# ============================================================================
# shared helpers
# ============================================================================

proc az_reset {} {
  catch {xschem unselect_all}
  catch {xschem select_all}
  catch {xschem delete}
  catch {xschem unselect_all}
  catch {xschem set_modify 0}
}
proc az_graph {x1 y1 x2 y2 {props {flags=graph}}} {
  xschem set rectcolor 2
  xschem rect $x1 $y1 $x2 $y2 -1 $props 0
}
# WORLD box -> canvas pixel band, through the engine's OWN transform (the same
# arithmetic X_TO_SCREEN does). NEVER an assumed absolute pixel range:
# zoom_full fits the drawing to whatever the canvas happens to be.
proc az_band {wx1 wy1 wx2 wy2} {
  set z  [xschem get zoom]
  set xo [xschem get xorigin]
  set yo [xschem get yorigin]
  if {![string is double -strict $z] || $z == 0.0} { return {} }
  return [list [expr {int(($wx1 + $xo) / $z)}] [expr {int(($wy1 + $yo) / $z)}] \
               [expr {int(($wx2 + $xo) / $z)}] [expr {int(($wy2 + $yo) / $z)}]]
}
# the PLOT BOX of strip `gi` in canvas pixels, {x1 y1 x2 y2}, found by ASKING
# the engine (graph_plotbox_at) and never by predicting from the rect: a seed
# sweep inside the strip's own band, then a walk out to each of the four edges.
proc az_box {gi band} {
  if {[llength $band] != 4} { return {} }
  lassign $band ux1 uy1 ux2 uy2
  if {$ux2 < $ux1} { set t $ux1; set ux1 $ux2; set ux2 $t }
  if {$uy2 < $uy1} { set t $uy1; set uy1 $uy2; set uy2 $t }
  set step [expr {($ux2 - $ux1) > 2000 || ($uy2 - $uy1) > 2000 ? 8 : 2}]
  set sx {}; set sy {}
  for {set y $uy1} {$y <= $uy2} {incr y $step} {
    for {set x $ux1} {$x <= $ux2} {incr x $step} {
      if {[xschem get graph_plotbox_at $gi $x $y]} { set sx $x; set sy $y; break }
    }
    if {$sx ne {}} break
  }
  if {$sx eq {}} { return {} }
  set x1 $sx
  while {$x1 > -20000 && [xschem get graph_plotbox_at $gi [expr {$x1 - 1}] $sy]} { incr x1 -1 }
  set x2 $sx
  while {$x2 < 20000 && [xschem get graph_plotbox_at $gi [expr {$x2 + 1}] $sy]} { incr x2 }
  set cx [expr {($x1 + $x2) / 2}]
  set y1 $sy
  while {$y1 > -20000 && [xschem get graph_plotbox_at $gi $cx [expr {$y1 - 1}]]} { incr y1 -1 }
  set y2 $sy
  while {$y2 < 20000 && [xschem get graph_plotbox_at $gi $cx [expr {$y2 + 1}]]} { incr y2 }
  return [list $x1 $y1 $x2 $y2]
}
# The BOTTOM-margin probe pixel: the plot box's centre-x, half way down the gap
# between the box's bottom edge and the container band's bottom. Derived, not
# predicted. {} when there is no such gap (the caller FAILS, never skips).
proc az_xmargin {box band} {
  if {[llength $box] != 4 || [llength $band] != 4} { return {} }
  lassign $box bx1 by1 bx2 by2
  lassign $band ux1 uy1 ux2 uy2
  if {$uy2 - $by2 < 6} { return {} }
  return [list [expr {($bx1 + $bx2) / 2}] [expr {($by2 + $uy2) / 2}]]
}
# The LEFT-margin probe pixel: half way across the gap between the container
# band's left edge and the plot box's left edge, at the box's centre-y.
proc az_ymargin {box band} {
  if {[llength $box] != 4 || [llength $band] != 4} { return {} }
  lassign $box bx1 by1 bx2 by2
  lassign $band ux1 uy1 ux2 uy2
  if {$bx1 - $ux1 < 6} { return {} }
  return [list [expr {($ux1 + $bx1) / 2}] [expr {($by1 + $by2) / 2}]]
}
# Count regexp matches in CODE lines only (the test_wave_snap.tcl count_code
# idiom): a C block comment explaining what the code deliberately does NOT do
# contains the very string being counted.
proc az_count_code {src pat} {
  set n 0
  foreach line [split $src "\n"] {
    set t [string trimleft $line]
    # ⚠ NOT [string match "*" $t] -- `*` is a glob that matches EVERY string.
    if {[string index $t 0] eq "*"} { continue }
    if {[string range $t 0 1] eq "/*" || [string range $t 0 1] eq "//"} { continue }
    incr n [regexp -all $pat $line]
  }
  return $n
}
proc az_slurp {p} {
  if {[catch {open $p r} h]} { return {} }
  set s [read $h]
  close $h
  return $s
}
# The NUMERIC value of a #define, read straight out of the C source.
#
# WHY, and it is not tidiness: both constants this suite depends on are TUNABLES
# the issue file invites an eyeball to re-tune (the click-vs-drag travel and the
# zoom-out backstop). A leg that freezes a COPY of the value stops testing the
# product the moment somebody turns the knob: it either keeps passing against a
# number the code no longer uses, or it goes red for a change that was correct.
# Reading the define means the legs assert the constant's EFFECT -- raise
# GRAPH_CLICK_TOL and AM7 follows it; lower GRAPH_AXIS_ZOOM_MAX_FACTOR and AM8
# and AM12 follow it -- while a REBUILD-less edit, or a code path that ignores
# the constant, still goes red.
# {} when the define is missing or is not a number: the caller FAILS, never skips.
proc az_define {path name} {
  set src [az_slurp $path]
  if {$src eq {}} { return {} }
  foreach line [split $src "\n"] {
    if {[regexp "^\\s*#define\\s+$name\\s+(\[-+0-9.eE\]+)\\s*\$" $line -> v]} {
      if {[string is double -strict $v]} { return $v }
    }
  }
  return {}
}
# every graph rect's x1 x2 y1 y2 ypos1 ypos2, as one comparable list -- the
# "witness EVERY rect" primitive
proc az_windows {} {
  set out {}
  set n [xschem get rects 2]
  for {set i 0} {$i < $n} {incr i} {
    set row {}
    foreach t {x1 x2 y1 y2 ypos1 ypos2} { lappend row [xschem getprop rect 2 $i $t] }
    lappend out $row
  }
  return $out
}
# data-space x (d==0) or y (d==1) of a canvas pixel, through the INDEPENDENT
# graph_coord verb
proc az_coord {gi px py d} {
  set r [pcall {xschem graph_coord $gi $px $py}]
  if {[llength $r] != 2} { return {} }
  return [lindex $r $d]
}
# the closed form, in Tcl: what graph_axis_map MUST answer for a drag from
# data-space ca to data-space cb inside the window [A,B]
proc az_expect {A B ca cb} {
  set R [expr {$B - $A}]
  if {$R == 0.0} { return {} }
  set ua [expr {($ca - $A) / $R}]
  set ub [expr {($cb - $A) / $R}]
  set s  [expr {$ub - $ua}]
  if {$s > 0.0} { return [list [expr {$A + $ua * $R}] [expr {$A + $ub * $R}]] }
  set f [expr {-$s}]
  # the backstop, read from xschem.h -- never a frozen copy of its value
  if {$f < 1.0 / $::az_maxf} { set f [expr {1.0 / $::az_maxf}] }
  set R2 [expr {$R / $f}]
  set lo [expr {$A - $ub * $R2}]
  return [list $lo [expr {$lo + $R2}]]
}

# ---- the two TUNABLE constants, read from the source they live in ----------
# AC1 is a staging leg with teeth: if either parse came up empty every leg that
# uses it would silently compare against {} and the file would unwind on the
# first expr. Both are asserted to be present, numeric and sane BEFORE any group
# runs. See az_define above for why they are read rather than hardcoded.
set az_ctol [az_define [file join $repo src callback.c] GRAPH_CLICK_TOL]
set az_maxf [az_define [file join $repo src xschem.h]   GRAPH_AXIS_ZOOM_MAX_FACTOR]
check_true "AC1 GRAPH_CLICK_TOL was read out of src/callback.c: {$az_ctol}" \
  [pexpr {[string is double -strict "$az_ctol"] && $az_ctol > 0 && $az_ctol < 100}]
check_true "AC1 GRAPH_AXIS_ZOOM_MAX_FACTOR was read out of src/xschem.h:\
 {$az_maxf}" \
  [pexpr {[string is double -strict "$az_maxf"] && $az_maxf > 1.0}]
if {![string is double -strict "$az_ctol"]} { set az_ctol 3.0; stall "GRAPH_CLICK_TOL unreadable" }
if {![string is double -strict "$az_maxf"]} { set az_maxf 1000.0; stall "GRAPH_AXIS_ZOOM_MAX_FACTOR unreadable" }

# ============================================================================
# AZ* — the region query (BOTH arms)
# ============================================================================
if {[catch {

az_reset
pcall {xschem raw clear}
pcall {xschem raw new azzoom.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {xschem raw add v_b {vsweep 2 *}}
# strip 0/1: analog, identical windows.  strip 2: DIGITAL.  strip 3: a plain
# layer-2 rect that is NOT a graph (the fail-closed witness).
pcall {az_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a\nv_b"}
foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 0 $azt $azv} }
pcall {az_graph 0 500 800 900}
pcall {xschem setprop rect 2 1 node "v_a"}
foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 1 $azt $azv} }
pcall {az_graph 0 1000 800 1400}
pcall {xschem setprop rect 2 2 node "v_a"}
pcall {xschem setprop rect 2 2 digital 1}
foreach {azt azv} {x1 0 x2 1.0} { pcall {xschem setprop rect 2 2 $azt $azv} }
pcall {az_graph 0 1500 800 1900 {}}
pcall {xschem unselect_all}

proc az_reestablish {} {
  if {[info commands winfo] ne {}} {
    catch {wm deiconify .}
    catch {raise .}
    for {set i 0} {$i < 100} {incr i} {
      catch {update}
      if {[winfo exists .drw] && [winfo ismapped .drw]} break
      after 20
    }
  }
  catch {xschem zoom_full}
  catch {update}
}
# EVERY scanned pixel is re-derived together: a re-fit moves all of them at once
proc az_scan {} {
  global azband azbox azxm azym azdband
  set azband  [az_band 0 0 800 400]
  set azbox   [az_box 0 $azband]
  set azxm    [az_xmargin $azbox $azband]
  set azym    [az_ymargin $azbox $azband]
  set azdband [az_band 0 1000 800 1400]
  # SENTINELS, never {}: an empty coordinate reaching an `expr` further down is
  # a hard Tcl error that would unwind the whole file through the outer catch.
  if {[llength $azbox]  != 4} { set azbox  {-1 -1 -1 -1} }
  if {[llength $azband] != 4} { set azband {-1 -1 -1 -1} }
  if {[llength $azxm]   != 2} { set azxm   {-1 -1} }
  if {[llength $azym]   != 2} { set azym   {-1 -1} }
  if {[llength $azdband] != 4} { set azdband {-1 -1 -1 -1} }
}
az_reestablish
az_scan
lassign $azbox   bx1 by1 bx2 by2
lassign $azband  ux1 uy1 ux2 uy2
lassign $azxm    xmx xmy
lassign $azym    ymx ymy
set bcx [expr {($bx1 + $bx2) / 2}]
set bcy [expr {($by1 + $by2) / 2}]

# --- AZ0: staging, WITH TEETH ------------------------------------------------
check "AZ0 two analog graph rects, one digital, one non-graph layer-2 rect" \
  [pcall {list [xschem get rects 2] [xschem get graph_rects]}] {4 3}
check_true "AZ0 the plot box was SCANNED and is a real box (>100 px each way):\
 box=$azbox band=$azband" \
  [pexpr {$bx1 >= 0 && $bx2 - $bx1 > 60 && $by2 - $by1 > 40}]
check_true "AZ0 a BOTTOM-margin pixel was found (FAIL, never skip): $azxm" \
  [pexpr {$xmx >= 0 && $xmy > $by2}]
check_true "AZ0 a LEFT-margin pixel was found (FAIL, never skip): $azym" \
  [pexpr {$ymx >= 0 && $ymx < $bx1}]
if {$bx1 < 0 || $xmx < 0 || $ymx < 0} { stall "AZ* pixel scan came up empty" }

# --- AZ1..AZ8: the region map -----------------------------------------------
check "AZ1 a plot-box pixel is NOT an axis region" \
  [pcall {xschem get graph_axis_at 0 $bcx $bcy}] {}
check "AZ2 a bottom-margin pixel is the X axis" \
  [pcall {xschem get graph_axis_at 0 $xmx $xmy}] x
check "AZ3 a left-margin pixel is the Y axis" \
  [pcall {xschem get graph_axis_at 0 $ymx $ymy}] y
# the top band is the horizontal legend's; assert the pixel really IS one
set az4y [expr {$uy1 + ($by1 - $uy1) / 2}]
check_true "AZ4 the top-band probe pixel really is a legend entry (teeth)" \
  [pexpr {[xschem get graph_legend_at 0 $bcx $az4y] >= 0}]
check "AZ4 a top-margin (legend band) pixel is not an axis region" \
  [pcall {xschem get graph_axis_at 0 $bcx $az4y}] {}
# --- AZ5: the reorder grip keeps unconditional first refusal ----------------
set az5x [expr {$ux2 - 7}]
check "AZ5 without a reorder handle the grip column answers x (teeth: the\
 refusal below is the GRIP's, not the geometry's)" \
  [pcall {xschem get graph_axis_at 0 $az5x $xmy}] x
pcall {xschem setprop rect 2 0 reorder_handle 1}
check "AZ5 with reorder_handle=1 the same pixel is refused" \
  [pcall {xschem get graph_axis_at 0 $az5x $xmy}] {}
check "AZ5 ...and the rest of the bottom margin still answers x" \
  [pcall {xschem get graph_axis_at 0 $xmx $xmy}] x
pcall {xschem setprop rect 2 0 reorder_handle 0}
check "AZ6 a pixel outside the container rect (left) is not an axis region" \
  [pcall {xschem get graph_axis_at 0 [expr {$ux1 - 20}] $bcy}] {}
check "AZ6 a pixel outside the container rect (right) is not an axis region" \
  [pcall {xschem get graph_axis_at 0 [expr {$ux2 + 20}] $bcy}] {}
check "AZ6 a pixel outside the container rect (below) is not an axis region" \
  [pcall {xschem get graph_axis_at 0 $bcx [expr {$uy2 + 20}]}] {}
check "AZ7 a bad graph index fails closed" \
  [pcall {xschem get graph_axis_at 99 $xmx $xmy}] {}
check "AZ7 a negative graph index fails closed" \
  [pcall {xschem get graph_axis_at -1 $xmx $xmy}] {}
check "AZ7 a layer-2 rect that is NOT a graph fails closed" \
  [pcall {xschem get graph_axis_at 3 $xmx $xmy}] {}
check "AZ7 a short query fails closed" [pcall {xschem get graph_axis_at 0}] {}
check "AZ8 the bottom-LEFT corner answers y, not x (D-7: one precedence rule)" \
  [pcall {xschem get graph_axis_at 0 $ymx $xmy}] y

# --- AZ9: the VERTICAL legend IS the left margin ----------------------------
pcall {xschem setprop rect 2 0 vlegend 1}
check_true "AZ9 with vlegend=1 the left-margin pixel really is a legend entry\
 (teeth)" [pexpr {[xschem get graph_legend_at 0 $ymx $ymy] >= 0}]
check "AZ9 ...so graph_axis_at refuses it" \
  [pcall {xschem get graph_axis_at 0 $ymx $ymy}] {}
check "AZ9 ...while the bottom margin still answers x (the legend takes only\
 the left one)" [pcall {xschem get graph_axis_at 0 $xmx $xmy}] x
pcall {xschem setprop rect 2 0 vlegend 0}
check "AZ9 the left margin comes back once vlegend is off" \
  [pcall {xschem get graph_axis_at 0 $ymx $ymy}] y

# --- AZ11: a DIGITAL strip has axes too (D-19) ------------------------------
# graph_plotbox_at REFUSES digital strips, so the probe pixel is taken 3 px
# above the container band's bottom -- the bottom margin is 14% of the height,
# so that is inside it by construction and needs no scan.
lassign $azdband dx1 dy1 dx2 dy2
set dcx [expr {($dx1 + $dx2) / 2}]
check_true "AZ11 the digital strip's band was located: $azdband" \
  [pexpr {$dx1 >= 0 && $dy2 - $dy1 > 50}]
check "AZ11 graph_plotbox_at still refuses the digital strip (teeth: this is\
 the gate graph_axis_at deliberately does NOT copy)" \
  [pcall {xschem get graph_plotbox_at 2 $dcx [expr {($dy1 + $dy2) / 2}]}] 0
check "AZ11 ...yet its bottom margin answers x" \
  [pcall {xschem get graph_axis_at 2 $dcx [expr {$dy2 - 3}]}] x

# --- AZ10: NO RAW LOADED, the margins still answer --------------------------
# the leg that dies if graph_plotbox_at's raw gate is ever copied into
# graph_axis_at. The geometry is unchanged by a raw clear (setup_graph_data
# reads tokens only), so the SAME pixels are reused deliberately.
pcall {xschem raw clear}
check "AZ10 with no raw loaded graph_plotbox_at goes dead (teeth)" \
  [pcall {xschem get graph_plotbox_at 0 $bcx $bcy}] 0
check "AZ10 ...but the bottom margin still answers x" \
  [pcall {xschem get graph_axis_at 0 $xmx $xmy}] x
check "AZ10 ...and the left margin still answers y" \
  [pcall {xschem get graph_axis_at 0 $ymx $ymy}] y
check "AZ10 ...and the plot box is still not an axis region" \
  [pcall {xschem get graph_axis_at 0 $bcx $bcy}] {}
pcall {xschem raw new azzoom.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {xschem raw add v_b {vsweep 2 *}}

} azzerr]} { check "AZ* group ran to its end" "ERR:$azzerr" ok }

# ============================================================================
# AM* — the map (BOTH arms)
# ============================================================================
if {[catch {

az_reestablish
az_scan
lassign $azbox  bx1 by1 bx2 by2
lassign $azband ux1 uy1 ux2 uy2
set bcx [expr {($bx1 + $bx2) / 2}]
set bcy [expr {($by1 + $by2) / 2}]
set bw  [expr {$bx2 - $bx1}]
set bh  [expr {$by2 - $by1}]
set A  [pcall {xschem getprop rect 2 0 x1}]
set B  [pcall {xschem getprop rect 2 0 x2}]
set R  [pexpr {$B - $A}]
set YA [pcall {xschem getprop rect 2 0 y1}]
set YB [pcall {xschem getprop rect 2 0 y2}]
set YR [pexpr {$YB - $YA}]
check_true "AM0 the AM fixture window is the one the legs compute against\
 (x $A..$B, y $YA..$YB, box ${bw}x${bh} px)" \
  [pexpr {$R > 0 && $YR > 0 && $bw > 60 && $bh > 40}]

# --- AM1: forward X drag == exactly the two data coordinates ----------------
set p0 [expr {$bx1 + 10}]
set p1 [expr {$bx2 - 10}]
set m1 [pcall {xschem get graph_axis_map 0 x $p0 $p1}]
set c0 [az_coord 0 $p0 $bcy 0]
set c1 [az_coord 0 $p1 $bcy 0]
check_true "AM1 forward X drag: lo == graph_coord at the PRESS pixel\
 (map=$m1 coord=$c0)" [pexpr {[az_close [lindex $m1 0] $c0 1e-9 $R]}]
check_true "AM1 forward X drag: hi == graph_coord at the RELEASE pixel\
 (map=$m1 coord=$c1)" [pexpr {[az_close [lindex $m1 1] $c1 1e-9 $R]}]

# --- AM2: reverse X drag, BOTH endpoints against the closed form ------------
set q0 [expr {$bx2 - 2}]
set q1 [expr {$bx1 + int($bw * 0.25)}]
set m2 [pcall {xschem get graph_axis_map 0 x $q0 $q1}]
set e2 [az_expect $A $B [az_coord 0 $q0 $bcy 0] [az_coord 0 $q1 $bcy 0]]
check_true "AM2 reverse X drag: lo == A - ub*R2 (map=$m2 expect=$e2)" \
  [pexpr {[az_close [lindex $m2 0] [lindex $e2 0] 1e-9 $R]}]
check_true "AM2 reverse X drag: hi == lo + R2 (map=$m2 expect=$e2)" \
  [pexpr {[az_close [lindex $m2 1] [lindex $e2 1] 1e-9 $R]}]
check_true "AM2 the reverse drag really ZOOMED OUT (teeth: the new range is\
 wider than the old)" \
  [pexpr {([lindex $m2 1] - [lindex $m2 0]) > $R * 1.2}]

# --- AM3: a FULL-EXTENT reverse drag leaves the window unchanged ------------
# ⚠ This is the leg SAB-2 (drop the anchoring term) does NOT kill: ub == 0
# there, so the anchor term vanishes and lo == A either way. That asymmetry is
# the entire reason AM2/AM4/AM6 assert both endpoints separately.
# The tolerance is 2% of R because the scanned box edges are the outermost
# INTEGER pixels inside the extent, up to a pixel short of it on each side.
set m3 [pcall {xschem get graph_axis_map 0 x $bx2 $bx1}]
check_true "AM3 full-extent reverse drag leaves lo at A (map=$m3 A=$A)" \
  [pexpr {[az_close [lindex $m3 0] $A 0.02 $R]}]
check_true "AM3 full-extent reverse drag leaves hi at B (map=$m3 B=$B)" \
  [pexpr {[az_close [lindex $m3 1] $B 0.02 $R]}]

# --- AM4: half-extent reverse drag from the right edge -> [A-R, A+R] --------
set m4 [pcall {xschem get graph_axis_map 0 x $bx2 $bcx}]
check_true "AM4 half-extent reverse drag: lo == A - R (map=$m4)" \
  [pexpr {[az_close [lindex $m4 0] [expr {$A - $R}] 0.03 $R]}]
check_true "AM4 half-extent reverse drag: hi == A + R (map=$m4)" \
  [pexpr {[az_close [lindex $m4 1] [expr {$A + $R}] 0.03 $R]}]

# --- AM5/AM6: the Y axis. UPWARD (decreasing pixel y) is the forward drag ----
set y0 [expr {$by2 - 10}]
set y1p [expr {$by1 + 10}]
set m5 [pcall {xschem get graph_axis_map 0 y $y0 $y1p}]
set d0 [az_coord 0 $bcx $y0 1]
set d1 [az_coord 0 $bcx $y1p 1]
check_true "AM5 forward (upward) Y drag: lo == graph_coord at the press pixel\
 (map=$m5 coord=$d0)" [pexpr {[az_close [lindex $m5 0] $d0 1e-9 $YR]}]
check_true "AM5 forward (upward) Y drag: hi == graph_coord at the release pixel\
 (map=$m5 coord=$d1)" [pexpr {[az_close [lindex $m5 1] $d1 1e-9 $YR]}]
check_true "AM5 ...and lo < hi (map=$m5)" [pexpr {[lindex $m5 0] < [lindex $m5 1]}]
set z0 [expr {$by1 + 2}]
set z1 [expr {$by2 - int($bh * 0.25)}]
set m6 [pcall {xschem get graph_axis_map 0 y $z0 $z1}]
set e6 [az_expect $YA $YB [az_coord 0 $bcx $z0 1] [az_coord 0 $bcx $z1 1]]
check_true "AM6 reverse (downward) Y drag: lo (map=$m6 expect=$e6)" \
  [pexpr {[az_close [lindex $m6 0] [lindex $e6 0] 1e-9 $YR]}]
check_true "AM6 reverse (downward) Y drag: hi (map=$m6 expect=$e6)" \
  [pexpr {[az_close [lindex $m6 1] [lindex $e6 1] 1e-9 $YR]}]
check_true "AM6 the reverse Y drag really ZOOMED OUT" \
  [pexpr {([lindex $m6 1] - [lindex $m6 0]) > $YR * 1.2}]

# --- AM7: the click/drag boundary, BOTH sides -------------------------------
# The boundary pixels come from GRAPH_CLICK_TOL itself ($az_ctol, parsed out of
# callback.c), not from a frozen 3/4. That is what ties this leg to the SEAM the
# getter drives: `xschem get graph_axis_map` passes graph_click_tol() -- the
# gesture's own threshold -- so raising the #define and rebuilding moves both
# the product and this leg, while raising it in ONE of the two places (the defect
# this replaces: scheduler.c used to carry its own literal 3.0) goes red here.
set amc  [expr {int($az_ctol)}]
set amc1 [expr {$amc + 1}]
check "AM7 travel of exactly GRAPH_CLICK_TOL ($amc px) is a CLICK: no answer" \
  [pcall {xschem get graph_axis_map 0 x $bcx [expr {$bcx + $amc}]}] {}
check "AM7 ...and $amc px the other way too" \
  [pcall {xschem get graph_axis_map 0 x $bcx [expr {$bcx - $amc}]}] {}
check_true "AM7 travel of $amc1 px is a DRAG: an answer" \
  [pexpr {[llength [xschem get graph_axis_map 0 x $bcx [expr {$bcx + $amc1}]]] == 2}]
check_true "AM7 ...and $amc1 px the other way too" \
  [pexpr {[llength [xschem get graph_axis_map 0 x $bcx [expr {$bcx - $amc1}]]] == 2}]

# --- AM8: the zoom-out clamp keeps the answer finite ------------------------
set m8 [pcall {xschem get graph_axis_map 0 x $bcx [expr {$bcx - $amc1}]}]
# purely the CLAMP question -- finiteness and the bound. Direction and anchoring
# are AM2/AM4/AM6's job, deliberately: a leg that mixes the two dies for the
# wrong sabotage and stops telling you which defect you have.
check_true "AM8 a $amc1-px reverse drag on a wide box is FINITE (map=$m8)" \
  [pexpr {[string is double -strict [lindex $m8 0]] &&
          [string is double -strict [lindex $m8 1]] &&
          abs([lindex $m8 0]) < 1e300 && abs([lindex $m8 1]) < 1e300}]
# the bound is R * the define's CURRENT value: lower GRAPH_AXIS_ZOOM_MAX_FACTOR
# below plot_width/$amc1 without rebuilding and this goes red, which is the point
# -- the old form hardcoded 1000.0 and could not see the constant move at all.
check_true "AM8 ...and spans no more than R * GRAPH_AXIS_ZOOM_MAX_FACTOR\
 ($az_maxf)" \
  [pexpr {abs([lindex $m8 1] - [lindex $m8 0]) <= $R * $az_maxf * 1.000001}]

# --- AM9: a LOG axis maps in LOG space, with no pow(10,.) -------------------
foreach {azt azv} {logx 1 x1 -3 x2 0} { pcall {xschem setprop rect 2 0 $azt $azv} }
set m9 [pcall {xschem get graph_axis_map 0 x [expr {$bx1 + 10}] [expr {$bx1 + int($bw * 0.4)}]}]
set c9 [az_coord 0 [expr {$bx1 + 10}] $bcy 0]
check_true "AM9 logx=1: the map agrees with graph_coord, i.e. it is in LOG\
 space (map=$m9 coord=$c9)" [pexpr {[az_close [lindex $m9 0] $c9 1e-9 3.0]}]
check_true "AM9 ...and the answer is NOT pow(10,.)-converted: both bounds are\
 inside the token range -3..0 (map=$m9)" \
  [pexpr {[lindex $m9 0] >= -3.0001 && [lindex $m9 0] < 0.0 &&
          [lindex $m9 1] <= 0.0001  && [lindex $m9 1] > -3.0001}]
foreach {azt azv} {logx 0 x1 0 x2 1.0} { pcall {xschem setprop rect 2 0 $azt $azv} }

# --- AM10: a release outside the plot box is CLAMPED, not refused -----------
set ma [pcall {xschem get graph_axis_map 0 x [expr {$bx1 + 20}] $bx2}]
set mb [pcall {xschem get graph_axis_map 0 x [expr {$bx1 + 20}] [expr {$bx2 + 50}]}]
check_true "AM10 a drag ending 50 px past the right edge answers (not refused)" \
  [pexpr {[llength $mb] == 2}]
check_true "AM10 ...and gives the same window as one ending ON the edge\
 (on=$ma past=$mb)" \
  [pexpr {[az_close [lindex $ma 0] [lindex $mb 0] 0.02 $R] &&
          [az_close [lindex $ma 1] [lindex $mb 1] 0.02 $R]}]

# --- AM11: fail-soft -------------------------------------------------------
check "AM11 a bad graph index answers {}" \
  [pcall {xschem get graph_axis_map 77 x $bx1 $bx2}] {}
check "AM11 a negative graph index answers {}" \
  [pcall {xschem get graph_axis_map -1 x $bx1 $bx2}] {}
check "AM11 an unknown axis word answers {}" \
  [pcall {xschem get graph_axis_map 0 q $bx1 $bx2}] {}
check "AM11 a short query answers {}" [pcall {xschem get graph_axis_map 0 x}] {}
check "AM11 a NON-GRAPH layer-2 rect answers {}" \
  [pcall {xschem get graph_axis_map 3 x $bx1 $bx2}] {}
# an OFF-SCREEN graph: added AFTER the fit, so nothing re-zooms onto it
pcall {az_graph 200000 200000 200800 200400}
pcall {xschem unselect_all}
set azoff [pexpr {[xschem get rects 2] - 1}]
check "AM11 an off-screen graph has no transform, so the map answers {}" \
  [pcall {xschem get graph_axis_map $azoff x 10 200}] {}
check "AM11 ...and so does the region query" \
  [pcall {xschem get graph_axis_at $azoff 10 200}] {}

# --- AM12: the zoom-out clamp actually BINDS, and binds AT the constant ------
# AM8 only bounds the answer from above, and on a normal strip the click
# threshold binds long before the backstop does (max factor ~ plot_width /
# GRAPH_CLICK_TOL), so until this leg NOTHING in the suite ever entered the clamp
# arm -- the `f < 1/GRAPH_AXIS_ZOOM_MAX_FACTOR` line was dead code as far as the
# tests were concerned. This leg runs it: a graph rect sized off the CURRENT zoom
# so its plot box is ~5 * maxf * (tol+1) screen pixels wide, where a
# just-over-threshold reverse drag is a zoom-out of thousands of x.
# The assertion is EQUALITY with R * GRAPH_AXIS_ZOOM_MAX_FACTOR, BOTH SIDES,
# against the value parsed out of xschem.h: deleting the clamp, mis-signing it,
# or lowering the #define without rebuilding all go red, while re-tuning the
# #define and rebuilding stays green and keeps asserting the new value.
set amwhalf [pexpr {int(5.0 * $az_maxf * $amc1 * [xschem get zoom])}]
pcall {az_graph -$amwhalf 0 $amwhalf 400}
pcall {xschem unselect_all}
set azwide [pexpr {[xschem get rects 2] - 1}]
foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} {
  pcall {xschem setprop rect 2 $azwide $azt $azv}
}
set amwR [pexpr {[xschem getprop rect 2 $azwide x2] - [xschem getprop rect 2 $azwide x1]}]
# the plot extent in SCREEN PIXELS, from the INDEPENDENT graph_coord transform
# (data-per-pixel over a 100-px baseline) -- never predicted from the rect
set amwslope [pexpr {abs([az_coord $azwide 400 $bcy 0] - [az_coord $azwide 300 $bcy 0]) / 100.0}]
set amwext [pexpr {$amwslope > 0 ? $amwR / $amwslope : 0}]
set amwfac [pexpr {$amwext / $amc1}]
check_true "AM12 the wide strip's plot extent is $amwext px, so an unclamped\
 $amc1-px reverse drag would zoom out ${amwfac}x -- the clamp ($az_maxf) IS the\
 binding constraint here, not the click threshold (teeth)" \
  [pexpr {$amwfac > $az_maxf * 2.0}]
set m12 [pcall {xschem get graph_axis_map $azwide x 400 [expr {400 - $amc1}]}]
check_true "AM12 the clamped reverse drag spans EXACTLY R *\
 GRAPH_AXIS_ZOOM_MAX_FACTOR (map=$m12 R=$amwR maxf=$az_maxf)" \
  [pexpr {[az_close [expr {[lindex $m12 1] - [lindex $m12 0]}] \
                    [expr {$amwR * $az_maxf}] 1e-9]}]

} azmerr]} { check "AM* group ran to its end" "ERR:$azmerr" ok }

# ============================================================================
# AV* — the apply / the verb (BOTH arms)
# ============================================================================
if {[catch {

# Its own fixture: rect 0/1 plain graphs (both participate), rect 2 UNLOCKED,
# rect 3 a different sim_type, rect 4 DIGITAL.
az_reset
pcall {xschem raw clear}
pcall {xschem raw new azzoom.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {az_graph 0 0 800 400}
pcall {az_graph 0 500 800 900}
pcall {az_graph 0 1000 800 1400 {flags=graph,unlocked}}
pcall {az_graph 0 1500 800 1900}
pcall {xschem setprop rect 2 3 sim_type ac}
pcall {az_graph 0 2000 800 2400}
pcall {xschem setprop rect 2 4 digital 1}
for {set i 0} {$i < 5} {incr i} {
  foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5 ypos1 0 ypos2 2} {
    pcall {xschem setprop rect 2 $i $azt $azv}
  }
}
pcall {xschem unselect_all}
az_reestablish
check "AV0 five graph rects, and the flags/sim_type fixture really differs\
 (teeth)" \
  [pcall {list [xschem get graph_rects] [xschem getprop rect 2 2 flags] \
               [xschem getprop rect 2 3 sim_type] [xschem getprop rect 2 4 digital]}] \
  {5 graph,unlocked ac 1}

# --- AV1: X propagates -- witness EVERY rect --------------------------------
set before [az_windows]
check "AV1 graph_axis_zoom 0 x returns 1" [pcall {xschem graph_axis_zoom 0 x 0.25 0.75}] 1
check "AV1 rect 0 x1/x2 written" \
  [pcall {list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]}] {0.25 0.75}
check "AV1 rect 1 FOLLOWED (the participation test, not the addressed rect)" \
  [pcall {list [xschem getprop rect 2 1 x1] [xschem getprop rect 2 1 x2]}] {0.25 0.75}
check "AV3 the UNLOCKED rect 2 did NOT follow" \
  [pcall {list [xschem getprop rect 2 2 x1] [xschem getprop rect 2 2 x2]}] {0 1.0}
check "AV4 the different-sim_type rect 3 did NOT follow" \
  [pcall {list [xschem getprop rect 2 3 x1] [xschem getprop rect 2 3 x2]}] {0 1.0}
check "AV1 the digital rect 4 shares the sim_type, so it DID follow" \
  [pcall {list [xschem getprop rect 2 4 x1] [xschem getprop rect 2 4 x2]}] {0.25 0.75}
check "AV1 no Y token moved anywhere (X is X)" \
  [pcall {set azy {}
          for {set i 0} {$i < 5} {incr i} {
            lappend azy [xschem getprop rect 2 $i y1] [xschem getprop rect 2 $i y2]
          }
          set azy}] {0 2.5 0 2.5 0 2.5 0 2.5 0 2.5}

# --- AV2: Y touches its own rect only ---------------------------------------
set b1 [pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}]
check "AV2 graph_axis_zoom 0 y returns 1" [pcall {xschem graph_axis_zoom 0 y 0.5 1.5}] 1
check "AV2 rect 0 y1/y2 written" \
  [pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]}] {0.5 1.5}
check "AV2 rect 1's y1/y2 are byte-identical" \
  [pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}] $b1
check "AV2 rect 0's ypos1/ypos2 (the digital band) were NOT touched" \
  [pcall {list [xschem getprop rect 2 0 ypos1] [xschem getprop rect 2 0 ypos2]}] {0 2}

# --- AV5: a DIGITAL rect's Y is the ypos band -------------------------------
check "AV5 graph_axis_zoom 4 y returns 1" [pcall {xschem graph_axis_zoom 4 y 0.25 1.25}] 1
check "AV5 the digital rect's ypos1/ypos2 were written" \
  [pcall {list [xschem getprop rect 2 4 ypos1] [xschem getprop rect 2 4 ypos2]}] {0.25 1.25}
check "AV5 ...and its y1/y2 were left alone" \
  [pcall {list [xschem getprop rect 2 4 y1] [xschem getprop rect 2 4 y2]}] {0 2.5}

# --- AV6: no dirty flag, WITH a control proving the probe can go to 1 -------
pcall {xschem set_modify 0}
check "AV6 the probe starts clean" [pcall {xschem get modified}] 0
check "AV6 the zoom applied" [pcall {xschem graph_axis_zoom 0 x 0.3 0.6}] 1
check "AV6 ...and left the buffer CLEAN (landmine 19: a graph gesture is view\
 state)" [pcall {xschem get modified}] 0
check "AV6 CONTROL: a plain setprop on the same token DOES dirty the buffer\
 (so the probe is not simply broken)" \
  [pcall {xschem setprop rect 2 0 x1 0.31; xschem get modified}] 1
pcall {xschem set_modify 0}

# --- AV7: read-only applies (D-13) ------------------------------------------
pcall {xschem set readonly 1}
check "AV7 the buffer really is read-only (teeth)" [pcall {xschem get readonly}] 1
check "AV7 the verb still applies in a read-only buffer" \
  [pcall {xschem graph_axis_zoom 0 x 0.4 0.8}] 1
check "AV7 ...and really wrote" \
  [pcall {list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]}] {0.4 0.8}
pcall {xschem set readonly 0}
pcall {xschem set_modify 0}

# --- AV8: fail-soft on the index, fail-LOUD on the usage --------------------
pcall {xschem set rectcolor 2; xschem rect 0 3000 800 3400 -1 {} 0; xschem unselect_all}
set aznon [pexpr {[xschem get rects 2] - 1}]
set azb [az_windows]
check "AV8 a bad graph index answers 0" [pcall {xschem graph_axis_zoom 77 x 1 2}] 0
check "AV8 a negative graph index answers 0" [pcall {xschem graph_axis_zoom -1 x 1 2}] 0
check "AV8 a NON-GRAPH layer-2 rect answers 0" \
  [pcall {xschem graph_axis_zoom $aznon x 1 2}] 0
check "AV8 ...and nothing was written by any of them" [az_windows] $azb
check "AV8 a bad axis word is a catchable ERROR (a script wants to know)" \
  [pcall {catch {xschem graph_axis_zoom 0 q 1 2}}] 1
check "AV8 a short call is a catchable ERROR" \
  [pcall {catch {xschem graph_axis_zoom 0 x}}] 1

} azverr]} { check "AV* group ran to its end" "ERR:$azverr" ok }

# ============================================================================
# AL* — the replay log line (BOTH arms, in a --logdir CHILD PROCESS)
# ============================================================================
# This suite runs --nolog, so the only honest way to assert a C self-logged line
# is a child with its own --logdir (the test_wave_markers.tcl MD3 pattern).
if {[catch {

proc al_child {path body} {
  set h [open $path w]
  puts $h "# written by tests/headless/test_wave_axis_zoom.tcl, group AL"
  puts $h $body
  close $h
}
set alfix {xschem raw clear
xschem raw new alzoom.raw dc vsweep 0 1.0 0.1
xschem raw add v_a {vsweep 1 +}
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem rect 0 1000 800 1400 -1 {flags=graph} 0
xschem unselect_all
foreach i {0 1} { foreach {t v} {x1 0 x2 1.0 y1 0 y2 2.5} { xschem setprop rect 2 $i $t $v } }}

set alc1 [file join $scratch al_child1.tcl]
set ald1 [file join $scratch allog1]
file delete -force $ald1
file mkdir $ald1
al_child $alc1 "$alfix
xschem graph_axis_zoom 0 x 0.25 0.75
puts \"child r0=\[xschem getprop rect 2 0 x1] \[xschem getprop rect 2 0 x2]\"
puts \"child r1=\[xschem getprop rect 2 1 x1] \[xschem getprop rect 2 1 x2]\"
puts AL-CHILD-DONE
exit 0"
set alrc [catch {exec [info nameofexecutable] --nogui --pipe -q \
                      --logdir $ald1 --script $alc1 2>@1} alout]
set allines {}
foreach alf [lsort [glob -nocomplain [file join $ald1 *]]] {
  foreach all [split [az_slurp $alf] "\n"] { lappend allines $all }
}
proc al_count {lines pat} {
  set n 0
  foreach l $lines { if {[string match $pat $l]} { incr n } }
  return $n
}
if {$alrc || ![string match {*AL-CHILD-DONE*} $alout]} {
  note "AL child output: [string range $alout end-400 end]"
  stall "AL child did not reach its sentinel"
}
check "AL1 the --logdir child ran to its end" \
  [expr {[string match {*AL-CHILD-DONE*} $alout] ? 1 : 0}] 1
check_true "AL1 ...and really had a log open (the logdir holds xschem lines)" \
  [pexpr {[llength $allines] > 0 && [al_count $allines {xschem *}] > 0}]
check "AL2 EXACTLY ONE graph_axis_zoom line for one call" \
  [al_count $allines {xschem graph_axis_zoom 0 x *}] 1
check "AL2 ...and no y line at all" [al_count $allines {xschem graph_axis_zoom * y *}] 0
set alline {}
foreach l $allines { if {[string match {xschem graph_axis_zoom *} $l]} { set alline $l } }
check "AL3 the logged line is the VERB form: 6 words, axis word in the middle" \
  [list [llength $alline] [lindex $alline 0] [lindex $alline 1] \
        [lindex $alline 2] [lindex $alline 3]] {6 xschem graph_axis_zoom 0 x}
check_true "AL3 its bounds are NUMERIC, and are the DATA values, never pixels\
 (line: $alline)" \
  [pexpr {[string is double -strict [lindex $alline 4]] &&
          [string is double -strict [lindex $alline 5]] &&
          [az_close [lindex $alline 4] 0.25 1e-12] &&
          [az_close [lindex $alline 5] 0.75 1e-12]}]
check "AL3 no logged line carries a graph_axis pixel query" \
  [expr {[al_count $allines {*graph_axis_at*}] + [al_count $allines {*graph_axis_map*}]}] 0
# --- AL4: REPLAY -----------------------------------------------------------
set alr0 {}; set alr1 {}
foreach l [split $alout "\n"] {
  if {[string match {child r0=*} $l]} { set alr0 [string range $l 9 end] }
  if {[string match {child r1=*} $l]} { set alr1 [string range $l 9 end] }
}
set alc2 [file join $scratch al_child2.tcl]
al_child $alc2 "$alfix
$alline
puts \"replay r0=\[xschem getprop rect 2 0 x1] \[xschem getprop rect 2 0 x2]\"
puts \"replay r1=\[xschem getprop rect 2 1 x1] \[xschem getprop rect 2 1 x2]\"
puts AL-REPLAY-DONE
exit 0"
set alrc2 [catch {exec [info nameofexecutable] --nogui --pipe -q --nolog \
                       --script $alc2 2>@1} alout2]
set alp0 {}; set alp1 {}
foreach l [split $alout2 "\n"] {
  if {[string match {replay r0=*} $l]} { set alp0 [string range $l 10 end] }
  if {[string match {replay r1=*} $l]} { set alp1 [string range $l 10 end] }
}
if {$alrc2 || ![string match {*AL-REPLAY-DONE*} $alout2]} {
  note "AL replay output: [string range $alout2 end-400 end]"
  stall "AL replay child did not reach its sentinel"
}
check "AL4 the replay child ran to its end" \
  [expr {[string match {*AL-REPLAY-DONE*} $alout2] ? 1 : 0}] 1
# TEETH, and they are load-bearing: without them AL4 is a pure CONSISTENCY leg
# (both children would agree that nothing propagated) and could not see a
# dropped participation loop at all -- measured under SAB-4.
check_true "AL4 the original child really wrote rect 0 (teeth)" \
  [pexpr {$alr0 ne {} && $alr0 ne {0 1.0}}]
check_true "AL4 ...and the zoom really PROPAGATED to rect 1 in that child\
 (teeth: otherwise the replay leg below compares two nothings)" \
  [pexpr {$alr1 ne {} && $alr1 ne {0 1.0}}]
check "AL4 replaying the logged line reproduces rect 0's window" $alp0 $alr0
check "AL4 ...and rect 1's, so the ONE line carries the whole propagation" $alp1 $alr1

} azlerr]} { check "AL* group ran to its end" "ERR:$azlerr" ok }

# ============================================================================
# AS* — source-level tripwire (BOTH arms)
# ============================================================================
if {[catch {

set asdraw  [az_slurp [file join $repo src draw.c]]
set ascb    [az_slurp [file join $repo src callback.c]]
set assched [az_slurp [file join $repo src scheduler.c]]
check_true "AS0 the three sources were read" \
  [pexpr {[string length $asdraw] > 1000 && [string length $ascb] > 1000 &&
          [string length $assched] > 1000}]
check "AS1 the anchored zoom-out expression appears in draw.c exactly ONCE" \
  [az_count_code $asdraw {A - ub \* R2}] 1
check "AS1 callback.c carries NO copy of it (the gesture calls the map)" \
  [az_count_code $ascb {A - ub \* R2}] 0
check "AS1 scheduler.c carries NO copy of it (the verb calls the map)" \
  [az_count_code $assched {A - ub \* R2}] 0
check "AS1 graph_axis_map is CALLED from callback.c exactly once" \
  [az_count_code $ascb {graph_axis_map\(}] 1
check "AS1 graph_axis_map is CALLED from scheduler.c exactly once" \
  [az_count_code $assched {graph_axis_map\(}] 1
check "AS1 graph_axis_map appears in draw.c exactly once (its definition; it\
 does not call itself)" [az_count_code $asdraw {graph_axis_map\(}] 1
check "AS1 graph_axis_zoom (THE apply) is called from callback.c exactly once" \
  [az_count_code $ascb {graph_axis_zoom\(}] 1
check "AS1 ...and from scheduler.c exactly once" \
  [az_count_code $assched {graph_axis_zoom\(}] 1
# the neighbouring invariants this item promised not to break
check "AS2 GRAPH_CLICK_TOL was NOT moved into the header (it answers a\
 different question from GRAPH_TRACE_PICK_TOL -- landmine 20)" \
  [az_count_code [az_slurp [file join $repo src xschem.h]] {#define\s+GRAPH_CLICK_TOL}] 0
check "AS2 ...and it is still defined in callback.c" \
  [az_count_code $ascb {#define\s+GRAPH_CLICK_TOL}] 1
# the BODY of graph_axis_zoom(), from its definition to the first line that is
# a bare closing brace in column 1 -- enough to prove landmine 19 holds for it
set asstart [string first "int graph_axis_zoom(int i, int axis" $asdraw]
set asbody {}
if {$asstart >= 0} {
  set astail [string range $asdraw $asstart end]
  if {[regexp {(?s)^(.*?\n\})\n} $astail -> asm]} { set asbody $asm }
}
check_true "AS2 graph_axis_zoom's body was located (teeth for the next leg)" \
  [pexpr {[string length $asbody] > 200 && [string first "log_action" $asbody] > 0}]
check "AS2 graph_axis_zoom does NOT set_modify and does NOT push_undo\
 (landmine 19: a graph gesture is view state)" \
  [regexp -all {set_modify|push_undo} $asbody] 0

# --- AS3: ONE home for the click-vs-drag THRESHOLD too ----------------------
# AS1 proves the two call sites of graph_axis_map() share the FORMULA. They must
# also share its THRESHOLD, and for a while they did not: scheduler.c passed a
# literal 3.0 while callback.c passed GRAPH_CLICK_TOL, so the seam the whole AM
# group is driven through carried its own copy of the number. Nothing could see
# it -- raise the #define and the gesture needs 7 px while the getter still
# answers at 4, and every AM leg stays green. That is landmine 45(a) with the
# constant instead of the maths. The accessor graph_click_tol() is now the one
# home; these legs stop a copy from growing back.
check "AS3 the getter takes the threshold from callback.c's accessor" \
  [az_count_code $assched {graph_click_tol\(\)}] 1
check "AS3 ...and hands graph_axis_map NO numeric literal in its place" \
  [az_count_code $assched {&lo, *&hi, *[-+0-9.]}] 0
check "AS3 the accessor is defined exactly once, and in callback.c (where the\
 #define it exports lives)" \
  [az_count_code $ascb {^double graph_click_tol\(void\)$}] 1
check "AS3 ...and callback.c still passes the #define itself to graph_axis_map" \
  [az_count_code $ascb {graph_axis_map\(.*GRAPH_CLICK_TOL|GRAPH_CLICK_TOL\)\)}] 1
check "AS3 draw.c -- which owns the formula -- knows nothing about either name" \
  [az_count_code $asdraw {GRAPH_CLICK_TOL|graph_click_tol}] 0

} azserr]} { check "AS* group ran to its end" "ERR:$azserr" ok }

# ============================================================================
# AG* — the real C gesture on an on-canvas schematic graph (DISPLAY only)
# ============================================================================
set ::az_ran_x 0
if {$::az_have_x && [winfo exists .drw]} {
if {[catch {

# X11 event codes: 2 KeyPress, 4 ButtonPress, 5 ButtonRelease, 6 MotionNotify.
# 256 is Button1Mask.
proc ag_press {x y} { xschem callback .drw 4 $x $y 0 1 0 0 }
proc ag_drag  {x y} { xschem callback .drw 6 $x $y 0 0 0 256 }
proc ag_rel   {x y} { xschem callback .drw 5 $x $y 0 1 0 256 }
proc ag_move  {x y} { xschem callback .drw 6 $x $y 0 0 0 0 }
proc ag_key   {x y n} { xschem callback .drw 2 $x $y $n 0 0 0 }
# drop a stale ui_state latch: GRAPHPAN (32768) freezes graph_master and makes
# waves_callback `goto finish` before the arm; a schematic latch makes
# waves_selected skip the graph entirely. Either turns the NEXT press into a
# no-op. (2,2) is a pixel no strip of this fixture occupies.
proc ag_unlatch {} {
  catch {ag_key  2 2 65307}
  catch {ag_rel  2 2}
  catch {ag_move 2 2}
  catch {xschem unselect_all}
}
proc ag_gesture {p0x p0y p1x p1y} {
  ag_unlatch
  ag_press $p0x $p0y
  ag_drag [expr {($p0x + $p1x) / 2}] [expr {($p0y + $p1y) / 2}]
  ag_drag $p1x $p1y
  ag_rel  $p1x $p1y
}

az_reset
pcall {xschem raw clear}
pcall {xschem raw new azzoom.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {az_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a"}
pcall {az_graph 0 500 800 900}
pcall {xschem setprop rect 2 1 node "v_a"}
foreach i {0 1} {
  foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 $i $azt $azv} }
}
pcall {xschem unselect_all}
az_reestablish
az_scan
lassign $azbox  bx1 by1 bx2 by2
lassign $azband ux1 uy1 ux2 uy2
lassign $azxm   xmx xmy
lassign $azym   ymx ymy
set bcx [expr {($bx1 + $bx2) / 2}]
set bcy [expr {($by1 + $by2) / 2}]
set bw  [expr {$bx2 - $bx1}]
pcall {xschem set_modify 0}
check_true "AG0 the AG fixture scanned: box=$azbox band=$azband xm=$azxm ym=$azym" \
  [pexpr {$bx1 >= 0 && $bw > 60 && $xmx >= 0 && $ymx >= 0}]
if {$bx1 < 0 || $xmx < 0 || $ymx < 0} { stall "AG* pixel scan came up empty" }

# --- AG1..AG5: what a press arms -------------------------------------------
ag_unlatch
pcall {ag_press $xmx $xmy}
check "AG1 a bottom-margin press arms the X axis drag" \
  [pcall {xschem get graph_axis_drag}] x
pcall {ag_rel $xmx $xmy}
check "AG1 ...and the release clears the arm" [pcall {xschem get graph_axis_drag}] {}
ag_unlatch
pcall {ag_press $ymx $ymy}
check "AG2 a left-margin press arms the Y axis drag" \
  [pcall {xschem get graph_axis_drag}] y
pcall {ag_rel $ymx $ymy}
ag_unlatch
pcall {ag_press $bcx $bcy}
check "AG3 a plot-BODY press arms nothing" [pcall {xschem get graph_axis_drag}] {}
pcall {ag_rel $bcx $bcy}
ag_unlatch
set ag4y [expr {$uy1 + ($by1 - $uy1) / 2}]
pcall {ag_press $bcx $ag4y}
check "AG4 a legend-band press arms nothing" [pcall {xschem get graph_axis_drag}] {}
pcall {ag_rel $bcx $ag4y}
ag_unlatch
pcall {xschem setprop rect 2 0 reorder_handle 1}
pcall {ag_press [expr {$ux2 - 7}] $xmy}
check "AG5 a grip-column press arms nothing" [pcall {xschem get graph_axis_drag}] {}
pcall {ag_rel [expr {$ux2 - 7}] $xmy}
pcall {xschem setprop rect 2 0 reorder_handle 0}

# --- AG6: the CURSOR non-collision -----------------------------------------
# A y-cursor's line crosses the left margin and its numeric readout is DRAWN
# there, so a press at its height must keep belonging to the cursor.
ag_unlatch
pcall {xschem setprop rect 2 0 hcursor1_y 1.25}
# find the pixel row the cursor sits on, by asking graph_coord (independent of
# the arm under test)
set agcy -1
for {set y [expr {$by1 + 2}]} {$y <= $by2 - 2} {incr y} {
  set v [az_coord 0 $bcx $y 1]
  if {[string is double -strict $v] && abs($v - 1.25) < 0.01} { set agcy $y; break }
}
check_true "AG6 the y-cursor's pixel row was located (y=$agcy)" [pexpr {$agcy > 0}]
pcall {ag_move $ymx $agcy}
pcall {ag_press $ymx $agcy}
set agf [pcall {xschem get graph_flags}]
check "AG6 a press on the y-cursor arms NO axis drag" \
  [pcall {xschem get graph_axis_drag}] {}
check_true "AG6 ...because it really GRABBED the cursor (graph_flags=$agf,\
 bit 512) -- without this half the leg passes when nothing happened at all" \
  [pexpr {[string is integer -strict $agf] && ($agf & 512)}]
pcall {ag_rel $ymx $agcy}
ag_unlatch
pcall {xschem setprop rect 2 0 hcursor1_y {}}
pcall {xschem setprop rect 2 0 y1 0; xschem setprop rect 2 0 y2 2.5}

# --- AG7/AG8: the full gestures commit exactly the map's answer -------------
foreach i {0 1} {
  foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 $i $azt $azv} }
}
pcall {xschem set_modify 0}
set ag7p0 [expr {$bx1 + 15}]
set ag7p1 [expr {$bx2 - 15}]
set ag7m  [pcall {xschem get graph_axis_map 0 x $ag7p0 $ag7p1}]
ag_gesture $ag7p0 $xmy $ag7p1 $xmy
check_true "AG7 a full forward X gesture commits the map's lo (map=$ag7m got=[pcall {xschem getprop rect 2 0 x1}])" \
  [pexpr {[az_close [xschem getprop rect 2 0 x1] [lindex $ag7m 0] 1e-6]}]
check_true "AG7 ...and its hi" \
  [pexpr {[az_close [xschem getprop rect 2 0 x2] [lindex $ag7m 1] 1e-6]}]
check "AG7 ...and the arm is back to nothing" [pcall {xschem get graph_axis_drag}] {}

foreach i {0 1} {
  foreach {azt azv} {x1 0 x2 1.0} { pcall {xschem setprop rect 2 $i $azt $azv} }
}
set ag8p0 [expr {$bx2 - 5}]
set ag8p1 [expr {$bx1 + int($bw * 0.25)}]
set ag8m  [pcall {xschem get graph_axis_map 0 x $ag8p0 $ag8p1}]
ag_gesture $ag8p0 $xmy $ag8p1 $xmy
check_true "AG8 a full reverse X gesture commits the map's lo (map=$ag8m got=[pcall {xschem getprop rect 2 0 x1}])" \
  [pexpr {[az_close [xschem getprop rect 2 0 x1] [lindex $ag8m 0] 1e-6]}]
check_true "AG8 ...and its hi" \
  [pexpr {[az_close [xschem getprop rect 2 0 x2] [lindex $ag8m 1] 1e-6]}]
check_true "AG8 ...and it really zoomed OUT" \
  [pexpr {[xschem getprop rect 2 0 x1] < 0.0}]

# --- AG9: a sub-threshold press+release commits nothing ---------------------
foreach i {0 1} {
  foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 $i $azt $azv} }
}
pcall {xschem set_modify 0}   ;# the setprop resets above dirty it; AG12 is
                              ;# about the GESTURES, and AV6 already proves a
                              ;# plain setprop DOES set the flag
set ag9b [az_windows]
ag_unlatch
pcall {ag_press $xmx $xmy}
pcall {ag_rel [expr {$xmx + 2}] $xmy}
check "AG9 a sub-threshold press+release leaves every window byte-identical" \
  [az_windows] $ag9b
check "AG9 ...and clears the arm" [pcall {xschem get graph_axis_drag}] {}

# --- AG10: ESC mid-drag ------------------------------------------------------
set ag10b [az_windows]
ag_unlatch
pcall {ag_press $xmx $xmy}
check "AG10 the drag really armed before ESC (teeth)" \
  [pcall {xschem get graph_axis_drag}] x
pcall {ag_drag [expr {$bx2 - 15}] $xmy}
pcall {ag_key [expr {$bx2 - 15}] $xmy 65307}
check "AG10 ESC clears the arm" [pcall {xschem get graph_axis_drag}] {}
pcall {ag_rel [expr {$bx2 - 15}] $xmy}
check "AG10 ...and the trailing release commits nothing" [az_windows] $ag10b

# --- AG11: X propagates, Y does not -- one leg, BOTH rects ------------------
ag_unlatch
set ag11y0 [pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}]
ag_gesture $ymx [expr {$by2 - 15}] $ymx [expr {$by1 + 15}]
check_true "AG11 the Y gesture moved rect 0's window (teeth)" \
  [pexpr {[xschem getprop rect 2 0 y1] != 0}]
check "AG11 ...and left rect 1's y1/y2 untouched" \
  [pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}] $ag11y0
ag_gesture [expr {$bx1 + 15}] $xmy [expr {$bx2 - 15}] $xmy
check_true "AG11 the X gesture moved rect 0's window (teeth)" \
  [pexpr {[xschem getprop rect 2 0 x1] != 0}]
check_true "AG11 ...and rect 1's x1/x2 FOLLOWED it" \
  [pexpr {[az_close [xschem getprop rect 2 1 x1] [xschem getprop rect 2 0 x1] 1e-9] &&
          [az_close [xschem getprop rect 2 1 x2] [xschem getprop rect 2 0 x2] 1e-9]}]

# --- AG12: still clean ------------------------------------------------------
check "AG12 after the whole AG block the buffer is still modified 0" \
  [pcall {xschem get modified}] 0

# --- AG13: the same gesture on a strip whose index is NOT 0 -----------------
# Every AG leg above presses inside RECT 0's margins. AZ11 only QUERIES a
# non-zero index and AV5 only calls the VERB on one, so the press -> arm ->
# release path had never been driven off index 0 at all: a
# graph_axis_press_arm(0, ...)-style hardcode, or a graph_master /
# graph_axis_draggraph mix-up, would have been invisible to the whole suite.
# The DECISIVE half is the Y gesture -- Y touches its own rect only, so "rect 1
# moved and rect 0 did not" can only mean the arm followed the pressed strip.
set ag13band [az_band 0 500 800 900]
set ag13box  [az_box 1 $ag13band]
set ag13xmp  [az_xmargin $ag13box $ag13band]
set ag13ymp  [az_ymargin $ag13box $ag13band]
if {[llength $ag13box] != 4} { set ag13box {-1 -1 -1 -1} }
if {[llength $ag13xmp] != 2} { set ag13xmp {-1 -1} }
if {[llength $ag13ymp] != 2} { set ag13ymp {-1 -1} }
lassign $ag13box g1x1 g1y1 g1x2 g1y2
lassign $ag13xmp g1mx g1my
lassign $ag13ymp g1yx g1yy
check_true "AG13 strip 1 was scanned: box=$ag13box xm=$ag13xmp ym=$ag13ymp" \
  [pexpr {$g1x1 >= 0 && $g1mx >= 0 && $g1yx >= 0 && $g1x2 - $g1x1 > 60}]
if {$g1x1 < 0 || $g1mx < 0 || $g1yx < 0} { stall "AG13 strip-1 pixel scan came up empty" }
check "AG13 the scanned bottom-margin pixel is STRIP 1's X region (teeth)" \
  [pcall {xschem get graph_axis_at 1 $g1mx $g1my}] x
check "AG13 ...and strip 0 does not claim that pixel at all" \
  [pcall {xschem get graph_axis_at 0 $g1mx $g1my}] {}
check "AG13 the scanned left-margin pixel is STRIP 1's Y region (teeth)" \
  [pcall {xschem get graph_axis_at 1 $g1yx $g1yy}] y
# re-stage both windows, then clear the dirty flag those setprops raise (AV6's
# control leg: a plain setprop DOES dirty, the gesture does not)
foreach i {0 1} {
  foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 $i $azt $azv} }
}
pcall {xschem set_modify 0}
# (a) Y on strip 1 -- its own rect ONLY
set ag13y0 [pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]}]
ag_unlatch
pcall {ag_press $g1yx $g1yy}
check "AG13 a left-margin press on STRIP 1 arms the Y axis drag" \
  [pcall {xschem get graph_axis_drag}] y
set ag13ym [pcall {xschem get graph_axis_map 1 y $g1yy [expr {$g1y1 + 15}]}]
pcall {ag_drag $g1yx [expr {$g1y1 + 15}]}
pcall {ag_rel  $g1yx [expr {$g1y1 + 15}]}
check_true "AG13 ...and the release committed the map onto RECT 1\
 (map=$ag13ym got=[pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}])" \
  [pexpr {[az_close [xschem getprop rect 2 1 y1] [lindex $ag13ym 0] 1e-6] &&
          [az_close [xschem getprop rect 2 1 y2] [lindex $ag13ym 1] 1e-6]}]
check "AG13 ...leaving rect 0's y1/y2 byte-identical (Y never propagates, so\
 the arm really followed the PRESSED strip and not index 0)" \
  [pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]}] $ag13y0
# (b) X on strip 1 -- rect 1 is the master and rect 0 must FOLLOW it
ag_unlatch
pcall {ag_press $g1mx $g1my}
check "AG13 a bottom-margin press on STRIP 1 arms the X axis drag" \
  [pcall {xschem get graph_axis_drag}] x
set ag13xm2 [pcall {xschem get graph_axis_map 1 x $g1mx [expr {$g1x2 - 15}]}]
pcall {ag_drag [expr {$g1x2 - 15}] $g1my}
pcall {ag_rel  [expr {$g1x2 - 15}] $g1my}
check_true "AG13 ...and the release committed the map onto RECT 1\
 (map=$ag13xm2 got=[pcall {list [xschem getprop rect 2 1 x1] [xschem getprop rect 2 1 x2]}])" \
  [pexpr {[az_close [xschem getprop rect 2 1 x1] [lindex $ag13xm2 0] 1e-6] &&
          [az_close [xschem getprop rect 2 1 x2] [lindex $ag13xm2 1] 1e-6]}]
check_true "AG13 ...and rect 0 FOLLOWED it, so propagation runs off a non-zero\
 master too (rect0=[pcall {list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]}])" \
  [pexpr {[az_close [xschem getprop rect 2 0 x1] [xschem getprop rect 2 1 x1] 1e-9] &&
          [az_close [xschem getprop rect 2 0 x2] [xschem getprop rect 2 1 x2] 1e-9]}]
check "AG13 ...and the arm is back to nothing" [pcall {xschem get graph_axis_drag}] {}
check "AG13 ...and neither gesture dirtied the buffer" [pcall {xschem get modified}] 0

} azgerr]} { check "AG* group ran to its end" "ERR:$azgerr" ok }
} else {
  puts "SKIPPED: AG* (no DISPLAY / no .drw canvas)"
}

# ============================================================================
# AX* — the ASE viewer seam (DISPLAY only)
# ============================================================================
if {$::az_have_x && [winfo exists .drw]} {
if {[catch {

proc viewer_ready {top} {
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
    after 20
  }
  return 0
}
proc ax_ev {w seq args} {
  set ::axt [expr {$::axt + 1000}]
  eval [list event generate $w $seq -time $::axt] $args
  update
}
set ::axt 0

# A CONFIRMED context switch to the viewer canvas.
#
# `xschem new_schematic switch $w` on its own is not enough, and this suite
# measured it: any `update` after the switch can deliver a stray EnterNotify on
# the main editor window, whose handle_window_switching (callback.c) puts the C
# context BACK -- and from then on every `xschem getprop rect 2 k ...` in this
# group reads the SCHEMATIC's rects while the leg believes it is reading the
# viewer's. It presents as a product failure ("node -> {v_a v_a}", "readonly ->
# 0") and is nothing of the sort; standalone it cost ~1 run in 12.
# Switch, CONFIRM through current_win_path -- the same test wviewer::over_graph
# gates every graph key on -- and never leave an `update` between the last
# confirmation and the measurement that depends on it.
proc ax_ctx {} {
  for {set i 0} {$i < 100} {incr i} {
    catch {xschem new_schematic switch $::vdrw}
    if {[pcall {xschem get current_win_path}] eq $::vdrw} { return 1 }
    catch {update}
    after 20
  }
  note "ax_ctx: the C context never settled on $::vdrw"
  return 0
}

# A synthetic KeyPress that is actually DELIVERED.
#
# A generated KeyPress goes to the DISPLAY's focus window and the WSLg focus
# round-trip is asynchronous, so a bare `event generate <Key-...>` with no focus
# set is simply dropped a good fraction of the time. AX7's ESC used to be sent
# that way and it was the suite's whole flake budget: measured over 30 standalone
# runs during review, 8 went red on exactly these two AX7 legs, 7 of 10 inside
# one bad window. Every other wave suite in this directory sends keys through a
# focus-retry loop; this is that loop, shaped like test_wave_markers' send_key.
#
# The loop is gated on the RESULT predicate (evaluated in the CALLER's scope),
# not on `focus -displayof` agreeing: under WSLg the X input focus can sit
# outside the application entirely and `focus -force` cannot take it back, so
# gating the SEND on confirmed focus deadlocks. Sending a key that goes nowhere
# is harmless; not noticing that it went nowhere is not, which is why the caller
# checks the return value. Resending ESC is idempotent -- the second one cancels
# an already-cancelled drag.
proc ax_send_key {w ev done {maxtries 100}} {
  set top [winfo toplevel $w]
  for {set i 0} {$i < $maxtries} {incr i} {
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    if {![winfo exists $w]} { after 50; continue }
    catch {wm deiconify $top}
    catch {raise $top}
    catch {event generate $top <FocusIn> -detail NotifyAncestor}
    focus -force $top
    focus -force $w
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    set ::axt [expr {$::axt + 1000}]
    eval [list event generate $w] $ev [list -time $::axt]
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    after 50
  }
  note "ax_send_key: $ev to $w never took effect ($maxtries tries)"
  return 0
}

set st [ase::state_load $statefile]
dict set st rundir [file join $scratch run]
set sstate [file join $scratch session.state]
ase::state_save $sstate $st
set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
ase::session_open $tok $sstate
check "AX0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
set vtop [wviewer::window_for $tok]
set vdrw $vtop.drw
set ::vdrw $vdrw
if {![viewer_ready $vtop]} {
  puts "SKIPPED: AX* (viewer canvas never mapped)"
  catch {wviewer::close $tok}
} else {

check "AX0 the C context settled on the viewer canvas (teeth: every AX leg\
 below reads rect 2 k of whatever context is current)" [pcall {ax_ctx}] 1
pcall {xschem raw clear}
check "AX0 hermetic raw in the viewer ctx" \
  [pcall {xschem raw new axzoom.raw dc vsweep 0 1.0 0.1}] 1
check "AX0 v_a/v_b are real columns" \
  [pcall {list [xschem raw add v_a {vsweep 1 +}] [xschem raw add v_b {vsweep 2 *}]}] {1 1}
# `sdid` is a free-form model key regenerate/graph_props never read, so it is
# the witness that says WHICH STRIP is at index k independently of what is in it
proc ax_ids {tok} {
  set out {}
  foreach G [dict get [wviewer::layout_for $tok] graphs] {
    lappend out [wviewer::dget $G sdid ?]
  }
  return $out
}
proc ax_fixture {tok} {
  wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] sdid A] \
                                 [dict replace [wviewer::empty_graph] sdid B]]
  wviewer::add_trace $tok 0 v_a
  wviewer::add_trace $tok 1 v_b
  wviewer::regenerate $tok
  wviewer::fit $tok
  catch {wviewer::clear_history $tok}
  update
  ax_ctx     ;# LAST, and confirmed: the update above can lose the context
}
ax_fixture $tok
check "AX0 two strips, two graph rects, both carrying their trace" \
  [pcall {list [llength [dict get [wviewer::layout_for $tok] graphs]] \
               [xschem get graph_rects] \
               [xschem getprop rect 2 0 node] [xschem getprop rect 2 1 node]}] \
  {2 2 v_a v_b}
check "AX0 the inert strip witnesses are in place" [pcall {ax_ids $tok}] {A B}
check "AX0 the viewer buffer is readonly" [pcall {xschem get readonly}] 1

# strip 0's CONTAINER band comes from the viewer's own registry
# (wviewer::strip_bands_px, the same seam strip_handle_at_pixel uses, so "the
# grip column" means the same pixels here as it does in the product); the plot
# box and the two margins are then derived exactly as everywhere else in this
# file. NEVER predicted from the rect.
proc ax_scan {tok} {
  global axbox axband axxm axym
  ax_ctx
  set bands [pcall {wviewer::strip_bands_px $::vdrw}]
  set axband {-1 -1 -1 -1}
  if {[llength $bands] >= 1} {
    set b0 {}
    foreach v [lindex $bands 0] { lappend b0 [expr {int($v)}] }
    if {[llength $b0] == 4} { set axband $b0 }
  }
  set axbox [az_box 0 $axband]
  if {[llength $axbox] != 4} { set axbox {-1 -1 -1 -1} }
  set axxm [az_xmargin $axbox $axband]
  set axym [az_ymargin $axbox $axband]
  if {[llength $axxm] != 2} { set axxm {-1 -1} }
  if {[llength $axym] != 2} { set axym {-1 -1} }
}
ax_scan $tok
lassign $axbox  abx1 aby1 abx2 aby2
lassign $axxm   axmx axmy
lassign $axym   aymx aymy
check_true "AX0 the viewer strip was scanned: box=$axbox xm=$axxm ym=$axym" \
  [pexpr {$abx1 >= 0 && $axmx >= 0 && $aymx >= 0}]
if {$abx1 < 0 || $axmx < 0 || $aymx < 0} { stall "AX* pixel scan came up empty" }
check "AX0 the scanned bottom-margin pixel really is the X region (teeth)" \
  [pcall {xschem get graph_axis_at 0 $axmx $axmy}] x
check "AX0 the scanned left-margin pixel really is the Y region (teeth)" \
  [pcall {xschem get graph_axis_at 0 $aymx $aymy}] y

proc ax_reset_arms {tok} {
  catch {wviewer::strip_drag_cancel $::vdrw}
  ax_ctx
  catch {xschem callback $::vdrw 5 2 2 0 1 0 256}
  catch {xschem callback $::vdrw 6 2 2 0 0 0 0}
  update
  ax_ctx     ;# the update above is exactly where the context gets lost
}
proc ax_drag_from {tok} {
  if {[catch {set v $wviewer::drag_from($tok)}]} { return -1 }
  if {$v eq {}} { return -1 }
  return $v
}
proc ax_win {gi} {
  ax_ctx
  set out {}
  foreach t {x1 x2 y1 y2} { lappend out [xschem getprop rect 2 $gi $t] }
  return $out
}

# --- AX1: a bottom-margin press does NOT arm the strip reorder --------------
ax_reset_arms $tok
set ax1r [pcall {wviewer::strip_drag_press $vdrw $axmx $axmy 0}]
check "AX1 strip_drag_press consumed the bottom-margin press" $ax1r 1
check "AX1 ...via the axis rung: axis_grabbed is 1" \
  [pcall {wviewer::axis_grabbed $vdrw}] 1
check "AX1 ...and the strip reorder did NOT arm" [pcall {ax_drag_from $tok}] -1
pcall {ax_ctx; xschem callback $vdrw 5 $axmx $axmy 0 1 0 256}
ax_reset_arms $tok

# --- AX2/AX3: the full viewer gesture through the SHIPPED bindings ----------
set ax2ids [pcall {ax_ids $tok}]
set ax2w0  [pcall {ax_win 0}]
ax_ev $vdrw <ButtonPress-1>   -x $axmx -y $axmy
ax_ev $vdrw <B1-Motion>       -x [expr {$axmx + ($abx2 - $abx1) / 4}] -y $axmy -state 256
ax_ev $vdrw <ButtonRelease-1> -x [expr {$axmx + ($abx2 - $abx1) / 4}] -y $axmy -state 256
update
set ax2w1 [pcall {ax_win 0}]
check_true "AX2 a bottom-margin drag changed the strip's x1/x2\
 (before=$ax2w0 after=$ax2w1)" \
  [pexpr {[lindex $ax2w0 0] ne [lindex $ax2w1 0] || [lindex $ax2w0 1] ne [lindex $ax2w1 1]}]
check "AX2 ...and left y1/y2 alone" \
  [list [lindex $ax2w1 2] [lindex $ax2w1 3]] [list [lindex $ax2w0 2] [lindex $ax2w0 3]]
check "AX2 ...and did NOT reorder the stack (inert sdid witness)" \
  [pcall {ax_ids $tok}] $ax2ids
ax_reset_arms $tok
set ax3w0 [pcall {ax_win 0}]
ax_ev $vdrw <ButtonPress-1>   -x $aymx -y $aymy
ax_ev $vdrw <B1-Motion>       -x $aymx -y [expr {$aymy - ($aby2 - $aby1) / 4}] -state 256
ax_ev $vdrw <ButtonRelease-1> -x $aymx -y [expr {$aymy - ($aby2 - $aby1) / 4}] -state 256
update
set ax3w1 [pcall {ax_win 0}]
check_true "AX3 a left-margin drag changed the strip's y1/y2\
 (before=$ax3w0 after=$ax3w1)" \
  [pexpr {[lindex $ax3w0 2] ne [lindex $ax3w1 2] || [lindex $ax3w0 3] ne [lindex $ax3w1 3]}]
check "AX3 ...and did NOT reorder the stack" [pcall {ax_ids $tok}] $ax2ids
ax_reset_arms $tok

# --- AX4/AX5: the non-collisions --------------------------------------------
set ax4x [expr {($abx1 + $abx2) / 2}]
set ax4y [expr {($aby1 + $aby2) / 2}]
# a body pixel far from every trace, so the trace-drag rung cannot claim it
set ax4ok 0
for {set y [expr {$aby2 - 2}]} {$y > $aby1} {incr y -1} {
  if {![xschem get graph_plotbox_at 0 $ax4x $y]} continue
  if {[xschem get graph_near_wave 0 $ax4x $y 25]} continue
  set ax4y $y; set ax4ok 1; break
}
check_true "AX4 an empty plot-body pixel was found ($ax4x,$ax4y)" $ax4ok
ax_reset_arms $tok
check "AX4 a plot-BODY press still arms the strip reorder" \
  [pcall {wviewer::strip_drag_press $vdrw $ax4x $ax4y 0; ax_drag_from $tok}] 0
check "AX4 ...and armed no axis drag" [pcall {wviewer::axis_grabbed $vdrw}] 0
pcall {ax_ctx; xschem callback $vdrw 5 $ax4x $ax4y 0 1 0 256}
ax_reset_arms $tok
set ax5x [expr {[lindex $axband 2] - 5}]
set ax5g [pcall {wviewer::strip_handle_at_pixel $vdrw $ax5x $ax4y}]
check "AX5 the grip column is strip 0's (teeth)" $ax5g 0
check "AX5 a grip press still arms the strip reorder" \
  [pcall {wviewer::strip_drag_press $vdrw $ax5x $ax4y 0; ax_drag_from $tok}] 0
pcall {ax_ctx
       xschem callback $vdrw 5 $ax5x $ax4y 0 1 0 256}
ax_reset_arms $tok

# --- AX6: the viewer buffer is untouched ------------------------------------
ax_ctx
check "AX6 the viewer buffer is still modified 0" [pcall {xschem get modified}] 0
check "AX6 ...and still readonly 1" [pcall {xschem get readonly}] 1

# --- AX7: ESC during a viewer axis drag -------------------------------------
# ⚠ The ESC goes through ax_send_key, NOT ax_ev. Button events are generated
# straight at the named widget and always land; a KeyPress goes to the display's
# FOCUS window, and this leg is the only key send in the file. Sent bare it was
# dropped on ~1 standalone run in 4 and both AX7 checks then failed together (no
# cancel, so the trailing release committed the zoom). The retry loop is gated on
# the arm actually clearing, and its return value is asserted below so a leg that
# never received its probe cannot pass quietly.
ax_reset_arms $tok
set ax7w [pcall {ax_win 0}]
ax_ev $vdrw <ButtonPress-1> -x $axmx -y $axmy
check "AX7 the axis drag armed (teeth)" [pcall {wviewer::axis_grabbed $vdrw}] 1
ax_ev $vdrw <B1-Motion> -x [expr {$axmx + 40}] -y $axmy -state 256
set ax7k [ax_send_key $vdrw [list <Key-Escape> -x [expr {$axmx + 40}] -y $axmy] \
            {[wviewer::axis_grabbed $::vdrw] == 0}]
check "AX7 the ESC was actually DELIVERED (a swallowed key would leave the arm\
 up and fail the next two legs for the wrong reason)" $ax7k 1
update
check "AX7 ESC cleared the arm" [pcall {wviewer::axis_grabbed $vdrw}] 0
ax_ev $vdrw <ButtonRelease-1> -x [expr {$axmx + 40}] -y $axmy -state 256
update
check "AX7 ...and the window is unchanged" [pcall {ax_win 0}] $ax7w
ax_reset_arms $tok

# --- AX8: a zoom is NOT a viewer undo point ---------------------------------
set ax8d [pcall {wviewer::history_depth $tok}]
ax_ev $vdrw <ButtonPress-1>   -x $axmx -y $axmy
ax_ev $vdrw <B1-Motion>       -x [expr {$axmx + 40}] -y $axmy -state 256
ax_ev $vdrw <ButtonRelease-1> -x [expr {$axmx + 40}] -y $axmy -state 256
update
check "AX8 wviewer::history_depth did not move (D-15: a zoom is view state)" \
  [pcall {wviewer::history_depth $tok}] $ax8d
ax_reset_arms $tok
catch {wviewer::close $tok}
set ::az_ran_x 1
}

} azxerr]} { check "AX* group ran to its end" "ERR:$azxerr" ok }
} else {
  puts "SKIPPED: AX* (no DISPLAY)"
}

set ::az_body_completed 1
} azerr]} { check "the file body ran to its end" "ERR:$azerr" ok }

check "AZZ the file body reached its end (no group unwound into the outer catch)" \
  [expr {[info exists ::az_body_completed] ? 1 : 0}] 1

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
