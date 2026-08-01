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
# TWO call sites in callback.c since issue 0191: the LMB drag's release arm and
# the CTRL+wheel arm. Both are gestures and both go through THE apply -- that is
# the invariant, not the count. A third would mean a new gesture arrived without
# a leg here; zero would mean a gesture grew its own subst_token copy.
check "AS1 graph_axis_zoom (THE apply) is called from callback.c exactly twice\
 (the 0190 drag release and the 0191 CTRL+wheel arm)" \
  [az_count_code $ascb {graph_axis_zoom\(}] 2
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
# CW* — the CTRL+WHEEL map and its verb (BOTH arms) — issue 0191, §18
# ============================================================================
# One CTRL+wheel click in an axis-number margin zooms THAT AXIS ONLY, anchored
# at the pointer:
#     q = G_axis(p), u = (q - A)/R, R2 = R * f, lo = q - u*R2, hi = lo + R2
# with f = K (in) or 1/K (out), K = GRAPH_AXIS_WHEEL_FACTOR read out of
# src/xschem.h. The INVARIANT, and the only thing the user asked for, is that q
# keeps its screen pixel: (q - lo)/(hi - lo) == u.
#
# ⚠ EVERY probe pixel here is OFF-CENTRE, deliberately at 25 % of the plot
# extent. At the CENTRE the anchored form and a zoom-about-centre form agree to
# 4 decimal places, so a centred leg cannot tell them apart and SAB-1 would pass
# straight through it. That is the whole distinction this group exists to make.
set ::cwK [az_define [file join $repo src xschem.h] GRAPH_AXIS_WHEEL_FACTOR]
check_true "CC1 GRAPH_AXIS_WHEEL_FACTOR was read out of src/xschem.h: {$::cwK}\
 (staging with teeth: every CW/CD leg below compares against it)" \
  [pexpr {[string is double -strict "$::cwK"] && $::cwK > 0.0 && $::cwK < 1.0}]
if {![string is double -strict "$::cwK"]} {
  set ::cwK 0.8; stall "GRAPH_AXIS_WHEEL_FACTOR unreadable"
}
if {[catch {

az_reset
pcall {xschem raw clear}
pcall {xschem raw new azzoom.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {az_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a"}
pcall {az_graph 0 500 800 900}
pcall {xschem setprop rect 2 1 node "v_a"}
pcall {az_graph 0 1000 800 1400 {}}   ;# a layer-2 rect that is NOT a graph
pcall {xschem unselect_all}
# re-stage the two analog strips to the window every leg computes against, and
# drop the dirty flag the setprops raise (AV6 owns the "a setprop DOES dirty"
# control; these legs are about the zoom)
proc cw_stage {} {
  for {set i 0} {$i < 2} {incr i} {
    foreach {t v} {x1 0 x2 1.0 y1 0 y2 2.5 ypos1 0 ypos2 2} {
      pcall {xschem setprop rect 2 $i $t $v}
    }
  }
  pcall {xschem set_modify 0}
}
# the box/margin pixels, re-derived together -- a zoom cannot move them (the
# plot box is geometry, not data) but they are re-scanned after every zooming
# leg anyway, exactly like az_scan does for the AZ/AM groups
proc cw_scan {} {
  global cwband cwbox cwxm cwym
  set cwband [az_band 0 0 800 400]
  if {[llength $cwband] != 4} { set cwband {-1 -1 -1 -1} }
  set cwbox  [az_box 0 $cwband]
  if {[llength $cwbox] != 4} { set cwbox {-1 -1 -1 -1} }
  set cwxm [az_xmargin $cwbox $cwband]
  set cwym [az_ymargin $cwbox $cwband]
  if {[llength $cwxm] != 2} { set cwxm {-1 -1} }
  if {[llength $cwym] != 2} { set cwym {-1 -1} }
}
cw_stage
az_reestablish
cw_scan
lassign $cwbox  cbx1 cby1 cbx2 cby2
lassign $cwband cux1 cuy1 cux2 cuy2
set ccx [expr {($cbx1 + $cbx2) / 2}]
set ccy [expr {($cby1 + $cby2) / 2}]
set cbw [expr {$cbx2 - $cbx1}]
set cbh [expr {$cby2 - $cby1}]
set CA  [pcall {xschem getprop rect 2 0 x1}]
set CB  [pcall {xschem getprop rect 2 0 x2}]
set CR  [pexpr {$CB - $CA}]
set CYA [pcall {xschem getprop rect 2 0 y1}]
set CYB [pcall {xschem getprop rect 2 0 y2}]
set CYR [pexpr {$CYB - $CYA}]
# the OFF-CENTRE probe pixels (see the group header)
set cwpx [expr {$cbx1 + int($cbw * 0.25)}]
set cwpy [expr {$cby2 - int($cbh * 0.25)}]
check_true "CW0 the CW fixture scanned and its window is the one every leg\
 computes against (box=$cwbox band=$cwband x $CA..$CB y $CYA..$CYB)" \
  [pexpr {$cbx1 >= 0 && $cbw > 60 && $cbh > 40 && $CR > 0 && $CYR > 0}]
check_true "CW0 the probe pixels are really OFF-CENTRE (teeth: at the centre a\
 zoom-about-centre form is indistinguishable from the anchored one)\
 px=$cwpx cx=$ccx py=$cwpy cy=$ccy" \
  [pexpr {abs($cwpx - $ccx) > $cbw * 0.15 && abs($cwpy - $ccy) > $cbh * 0.15}]
if {$cbx1 < 0} { stall "CW* pixel scan came up empty" }

# --- CW0: the verb exists and fails SOFT ------------------------------------
check_true "CW0 the verb answers a 2-element window for a good query" \
  [pexpr {[llength [xschem get graph_axis_wheel_map 0 x $cwpx in]] == 2}]
check "CW0 a bad graph index answers {}" \
  [pcall {xschem get graph_axis_wheel_map 99 x $cwpx in}] {}
check "CW0 a negative graph index answers {}" \
  [pcall {xschem get graph_axis_wheel_map -1 x $cwpx in}] {}
check "CW0 a NON-GRAPH layer-2 rect answers {}" \
  [pcall {xschem get graph_axis_wheel_map 2 x $cwpx in}] {}
check "CW0 an unknown axis word answers {}" \
  [pcall {xschem get graph_axis_wheel_map 0 q $cwpx in}] {}
check "CW0 an unknown direction word answers {}" \
  [pcall {xschem get graph_axis_wheel_map 0 x $cwpx sideways}] {}
check "CW0 a short query answers {}" \
  [pcall {xschem get graph_axis_wheel_map 0 x $cwpx}] {}
check "CW0 ...and none of those was a Tcl ERROR (fail soft, like every other\
 graph_* getter the viewer wraps in catch)" \
  [pcall {list [catch {xschem get graph_axis_wheel_map 99 x 1 in}] \
               [catch {xschem get graph_axis_wheel_map 0 q 1 in}] \
               [catch {xschem get graph_axis_wheel_map 0 x}]}] {0 0 0}

# --- CW1: BOTH endpoints against the closed form ----------------------------
# `q` comes from `xschem graph_coord`, an INDEPENDENT pixel->data transform (a
# different C function), so what is under test here is the anchored map itself.
set cwq  [az_coord 0 $cwpx $ccy 0]
set cwu  [pexpr {($cwq - $CA) / $CR}]
set cwR2 [pexpr {$CR * $::cwK}]
set cwlo [pexpr {$cwq - $cwu * $cwR2}]
set cwm  [pcall {xschem get graph_axis_wheel_map 0 x $cwpx in}]
check_true "CW1 wheel-IN lo == q - u*R2 (map=$cwm q=$cwq u=$cwu)" \
  [pexpr {[az_close [lindex $cwm 0] $cwlo 1e-9 $CR]}]
check_true "CW1 wheel-IN hi == lo + R2 (map=$cwm)" \
  [pexpr {[az_close [lindex $cwm 1] [expr {$cwlo + $cwR2}] 1e-9 $CR]}]

# --- CW2: the WIDTH only. This leg must SURVIVE SAB-1 -----------------------
# Kept separate from CW3 on purpose: a zoom-about-centre implementation has the
# right WIDTH and the wrong POSITION, so a suite whose only zoom assertion is
# this one passes while the window slides sideways.
set cwmi [pcall {xschem get graph_axis_wheel_map 0 x $cwpx in}]
set cwmo [pcall {xschem get graph_axis_wheel_map 0 x $cwpx out}]
check_true "CW2 one click IN multiplies the range by K=$::cwK (map=$cwmi)" \
  [pexpr {[az_close [expr {[lindex $cwmi 1] - [lindex $cwmi 0]}] \
                    [expr {$CR * $::cwK}] 1e-12 $CR]}]
check_true "CW2 one click OUT divides it by K (map=$cwmo)" \
  [pexpr {[az_close [expr {[lindex $cwmo 1] - [lindex $cwmo 0]}] \
                    [expr {$CR / $::cwK}] 1e-12 $CR]}]

# --- CW3: THE FIXED POINT ---------------------------------------------------
# The decisive leg, and the whole user ask: after the zoom, the data coordinate
# under the pointer is at the SAME canvas pixel. Asked of graph_coord before and
# after, so nothing about the map is reused as its own oracle.
# ⚠ The tolerance is 1e-6 OF THE RANGE, not 1e-9: graph_axis_zoom writes the
# tokens through dtoa (8 significant digits), so the round trip through the rect
# quantises the window at ~5e-9 relative. The map's own exactness is CW1's job
# (1e-9, no token in the loop). A zoom-about-centre form misses by 0.05 here --
# 6 % of the new range and ~60000x this tolerance.
cw_stage
cw_scan
set cwqb [az_coord 0 $cwpx $ccy 0]
set cwm3 [pcall {xschem get graph_axis_wheel_map 0 x $cwpx in}]
pcall {xschem graph_axis_zoom 0 x [lindex $cwm3 0] [lindex $cwm3 1]}
set cwqa [az_coord 0 $cwpx $ccy 0]
check_true "CW3 the apply really narrowed the window (teeth: x=[pcall {list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]}])" \
  [pexpr {[az_close [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}] \
                    [expr {$CR * $::cwK}] 1e-6 $CR]}]
check_true "CW3 THE FIXED POINT: the data x under the pointer pixel is\
 unchanged (before=$cwqb after=$cwqa)" \
  [pexpr {[az_close $cwqa $cwqb 1e-6 $CR]}]

# --- CW4: the same pair for Y in the left margin ----------------------------
cw_stage
cw_scan
set cwqy  [az_coord 0 $ccx $cwpy 1]
set cwuy  [pexpr {($cwqy - $CYA) / $CYR}]
set cwR2y [pexpr {$CYR * $::cwK}]
set cwloy [pexpr {$cwqy - $cwuy * $cwR2y}]
set cwm4  [pcall {xschem get graph_axis_wheel_map 0 y $cwpy in}]
check_true "CW4 Y wheel-IN lo == q - u*R2 (map=$cwm4 q=$cwqy u=$cwuy)" \
  [pexpr {[az_close [lindex $cwm4 0] $cwloy 1e-9 $CYR]}]
check_true "CW4 Y wheel-IN hi == lo + R2 (map=$cwm4)" \
  [pexpr {[az_close [lindex $cwm4 1] [expr {$cwloy + $cwR2y}] 1e-9 $CYR]}]
set cwqyb [az_coord 0 $ccx $cwpy 1]
pcall {xschem graph_axis_zoom 0 y [lindex $cwm4 0] [lindex $cwm4 1]}
set cwqya [az_coord 0 $ccx $cwpy 1]
check_true "CW4 THE FIXED POINT on Y (before=$cwqyb after=$cwqya)" \
  [pexpr {[az_close $cwqya $cwqyb 1e-6 $CYR]}]

# --- CW5: the ROUND TRIP ----------------------------------------------------
# in then out at the SAME pixel restores the window. This is the payoff of a
# REVERSIBLE factor (D-27): the shipped Shift+wheel arms are x0.8 in / x1.2 out
# and lose 4 % of the range per round trip -- 5e-2, which is 6e4 x this
# tolerance. The tolerance is again dtoa's 8 significant digits, not the maths.
cw_stage
cw_scan
set cw5m1 [pcall {xschem get graph_axis_wheel_map 0 x $cwpx in}]
pcall {xschem graph_axis_zoom 0 x [lindex $cw5m1 0] [lindex $cw5m1 1]}
set cw5m2 [pcall {xschem get graph_axis_wheel_map 0 x $cwpx out}]
pcall {xschem graph_axis_zoom 0 x [lindex $cw5m2 0] [lindex $cw5m2 1]}
check_true "CW5 in-then-out restored x1 (A=$CA got=[pcall {xschem getprop rect 2 0 x1}])" \
  [pexpr {[az_close [xschem getprop rect 2 0 x1] $CA 1e-6 $CR]}]
check_true "CW5 ...and x2 (B=$CB got=[pcall {xschem getprop rect 2 0 x2}])" \
  [pexpr {[az_close [xschem getprop rect 2 0 x2] $CB 1e-6 $CR]}]
check_true "CW5 ...and it really left the window in between (teeth: otherwise\
 this leg passes when neither click did anything)" \
  [pexpr {[az_close [expr {[lindex $cw5m1 1] - [lindex $cw5m1 0]}] \
                    [expr {$CR * $::cwK}] 1e-9 $CR] &&
          abs([lindex $cw5m1 0] - $CA) > $CR * 0.01}]

# --- CW6: the OTHER axis is byte-identical, on EVERY rect -------------------
cw_stage
cw_scan
set cw6b [az_windows]
set cw6m [pcall {xschem get graph_axis_wheel_map 0 x $cwpx in}]
pcall {xschem graph_axis_zoom 0 x [lindex $cw6m 0] [lindex $cw6m 1]}
set cw6a [az_windows]
check_true "CW6 the X zoom really wrote (teeth)" \
  [pexpr {[lindex $cw6b 0 0] ne [lindex $cw6a 0 0]}]
check "CW6 an X zoom leaves EVERY rect's y1 y2 ypos1 ypos2 byte-identical" \
  [pcall {set o {}; foreach row $cw6a { lappend o [lrange $row 2 5] }; set o}] \
  [pcall {set o {}; foreach row $cw6b { lappend o [lrange $row 2 5] }; set o}]
cw_stage
cw_scan
set cw6b2 [az_windows]
set cw6m2 [pcall {xschem get graph_axis_wheel_map 0 y $cwpy in}]
pcall {xschem graph_axis_zoom 0 y [lindex $cw6m2 0] [lindex $cw6m2 1]}
set cw6a2 [az_windows]
check_true "CW6 the Y zoom really wrote (teeth)" \
  [pexpr {[lindex $cw6b2 0 2] ne [lindex $cw6a2 0 2]}]
check "CW6 a Y zoom leaves EVERY rect's x1 x2 byte-identical" \
  [pcall {set o {}; foreach row $cw6a2 { lappend o [lrange $row 0 1] }; set o}] \
  [pcall {set o {}; foreach row $cw6b2 { lappend o [lrange $row 0 1] }; set o}]

# --- CW7: X propagates, Y does not ------------------------------------------
cw_stage
cw_scan
set cw7m [pcall {xschem get graph_axis_wheel_map 0 x $cwpx in}]
pcall {xschem graph_axis_zoom 0 x [lindex $cw7m 0] [lindex $cw7m 1]}
check_true "CW7 the X zoom PROPAGATED to the participating rect 1\
 (r0=[pcall {list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]}]\
 r1=[pcall {list [xschem getprop rect 2 1 x1] [xschem getprop rect 2 1 x2]}])" \
  [pexpr {[xschem getprop rect 2 1 x1] eq [xschem getprop rect 2 0 x1] &&
          [xschem getprop rect 2 1 x2] eq [xschem getprop rect 2 0 x2] &&
          [xschem getprop rect 2 0 x1] ne "0"}]
cw_stage
cw_scan
set cw7y1 [pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}]
set cw7m2 [pcall {xschem get graph_axis_wheel_map 0 y $cwpy in}]
pcall {xschem graph_axis_zoom 0 y [lindex $cw7m2 0] [lindex $cw7m2 1]}
check_true "CW7 the Y zoom wrote rect 0 (teeth)" \
  [pexpr {[xschem getprop rect 2 0 y1] ne "0"}]
check "CW7 ...and did NOT propagate to rect 1" \
  [pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}] $cw7y1

# --- CW8: the pointer AT the plot-box edge pins that edge -------------------
# p = e1 => u = 0 => lo == A; p = e2 => u = 1 => hi == B. The tolerance is 2 % of
# R because the SCANNED edges are the outermost INTEGER pixels inside the
# extent, up to a pixel short of it (AM3's reason, verbatim).
cw_stage
cw_scan
set cw8l [pcall {xschem get graph_axis_wheel_map 0 x $cbx1 in}]
set cw8r [pcall {xschem get graph_axis_wheel_map 0 x $cbx2 in}]
check_true "CW8 pointer at the LEFT plot edge pins lo at A (map=$cw8l A=$CA)" \
  [pexpr {[az_close [lindex $cw8l 0] $CA 0.02 $CR]}]
check_true "CW8 pointer at the RIGHT plot edge pins hi at B (map=$cw8r B=$CB)" \
  [pexpr {[az_close [lindex $cw8r 1] $CB 0.02 $CR]}]

# --- CW9: a pixel outside the plot extent is CLAMPED, not refused -----------
set cw9 [pcall {xschem get graph_axis_wheel_map 0 x [expr {$cbx2 + 50}] in}]
check_true "CW9 a pixel 50 px past the right edge still answers (D-11: it\
 commits, it does not silently refuse)" [pexpr {[llength $cw9] == 2}]
# the tolerance is 2 % of R for AM3/AM10's reason: the SCANNED right edge is the
# outermost INTEGER pixel inside the extent, up to a pixel short of the true e2
# the clamp uses, so the two answers differ by one pixel's worth of data
check_true "CW9 ...and gives (to one scanned pixel) the same window as one AT\
 the edge (edge=$cw8r past=$cw9)" \
  [pexpr {[az_close [lindex $cw9 0] [lindex $cw8r 0] 0.02 $CR] &&
          [az_close [lindex $cw9 1] [lindex $cw8r 1] 0.02 $CR]}]
check_true "CW9 ...and it is NOT simply refusing and echoing the edge query:\
 both endpoints are finite and the range is R*K" \
  [pexpr {[az_close [expr {[lindex $cw9 1] - [lindex $cw9 0]}] \
                    [expr {$CR * $::cwK}] 1e-9 $CR]}]

# --- CW10/CW11: LOG axes, BOTH of them (PLAN Q6) ----------------------------
# The wheel map is log-correct BY INHERITANCE: gr->gx1..gy2 and G_X/G_Y are
# already in log space when logx/logy is set, so nothing in
# graph_axis_wheel_map() mentions a logarithm. "Correct by inheritance" is
# exactly the claim that rots without a leg, and until these two NOTHING in this
# file ever set logx or logy on the WHEEL map -- AM9 covers the DRAG map only,
# and it covers X only.
# Two distinct defects these catch, and neither is visible to any other leg:
#   * a pow(10,.) creeping onto either end (landmine 35 from the other side):
#     the answer leaves the -3..0 token range entirely;
#   * an anchor computed in LINEAR space while the window is logarithmic: the
#     width would still be R*K (CW2 stays green) and the fixed point would move,
#     which is the same asymmetry SAB-1 exploits.
# ⚠ The window is set to -3..0, i.e. 1e-3..1 in real units, because that is what
# a log axis's x1/x2 tokens ARE -- the shipped box zoom writes dtoa(G_X(...))
# into them with no conversion. A leg that staged 1e-3..1 would be testing a
# fixture bug, not the map.
cw_stage
cw_scan
foreach {azt azv} {logx 1 x1 -3 x2 0} { pcall {xschem setprop rect 2 0 $azt $azv} }
set cwLA [pcall {xschem getprop rect 2 0 x1}]
set cwLB [pcall {xschem getprop rect 2 0 x2}]
set cwLR [pexpr {$cwLB - $cwLA}]
check_true "CW10 the log-X fixture really took (teeth: logx=[pcall {xschem getprop rect 2 0 logx}]\
 window=$cwLA..$cwLB)" \
  [pexpr {[xschem getprop rect 2 0 logx] eq "1" && $cwLR > 0}]
set cwlq [az_coord 0 $cwpx $ccy 0]
set cwlu [pexpr {($cwlq - $cwLA) / $cwLR}]
set cwlm [pcall {xschem get graph_axis_wheel_map 0 x $cwpx in}]
check_true "CW10 logx=1: lo == q - u*R2 evaluated in LOG space (map=$cwlm\
 q=$cwlq u=$cwlu)" \
  [pexpr {[az_close [lindex $cwlm 0] \
                    [expr {$cwlq - $cwlu * $cwLR * $::cwK}] 1e-9 $cwLR]}]
check_true "CW10 ...and hi == lo + R*K, still in log space (map=$cwlm)" \
  [pexpr {[az_close [expr {[lindex $cwlm 1] - [lindex $cwlm 0]}] \
                    [expr {$cwLR * $::cwK}] 1e-12 $cwLR]}]
check_true "CW10 ...and NEITHER bound was pow(10,.)-converted: both stay inside\
 the token range -3..0 (map=$cwlm)" \
  [pexpr {[lindex $cwlm 0] >= -3.0001 && [lindex $cwlm 0] < 0.0 &&
          [lindex $cwlm 1] <= 0.0001  && [lindex $cwlm 1] > -3.0001}]
pcall {xschem graph_axis_zoom 0 x [lindex $cwlm 0] [lindex $cwlm 1]}
set cwlqa [az_coord 0 $cwpx $ccy 0]
check_true "CW10 THE FIXED POINT on a LOG X axis: the data x under the pointer\
 pixel is unchanged (before=$cwlq after=$cwlqa)" \
  [pexpr {[az_close $cwlqa $cwlq 1e-6 $cwLR]}]
foreach {azt azv} {logx 0 x1 0 x2 1.0} { pcall {xschem setprop rect 2 0 $azt $azv} }

cw_stage
cw_scan
foreach {azt azv} {logy 1 y1 -3 y2 0} { pcall {xschem setprop rect 2 0 $azt $azv} }
set cwMA [pcall {xschem getprop rect 2 0 y1}]
set cwMB [pcall {xschem getprop rect 2 0 y2}]
set cwMR [pexpr {$cwMB - $cwMA}]
check_true "CW11 the log-Y fixture really took (teeth: logy=[pcall {xschem getprop rect 2 0 logy}]\
 window=$cwMA..$cwMB)" \
  [pexpr {[xschem getprop rect 2 0 logy] eq "1" && $cwMR > 0}]
set cwmq [az_coord 0 $ccx $cwpy 1]
set cwmu [pexpr {($cwmq - $cwMA) / $cwMR}]
set cwmm [pcall {xschem get graph_axis_wheel_map 0 y $cwpy in}]
check_true "CW11 logy=1: lo == q - u*R2 evaluated in LOG space (map=$cwmm\
 q=$cwmq u=$cwmu)" \
  [pexpr {[az_close [lindex $cwmm 0] \
                    [expr {$cwmq - $cwmu * $cwMR * $::cwK}] 1e-9 $cwMR]}]
check_true "CW11 ...and NEITHER bound was pow(10,.)-converted (map=$cwmm)" \
  [pexpr {[lindex $cwmm 0] >= -3.0001 && [lindex $cwmm 0] < 0.0 &&
          [lindex $cwmm 1] <= 0.0001  && [lindex $cwmm 1] > -3.0001}]
pcall {xschem graph_axis_zoom 0 y [lindex $cwmm 0] [lindex $cwmm 1]}
set cwmqa [az_coord 0 $ccx $cwpy 1]
check_true "CW11 THE FIXED POINT on a LOG Y axis (before=$cwmq after=$cwmqa)" \
  [pexpr {[az_close $cwmqa $cwmq 1e-6 $cwMR]}]
foreach {azt azv} {logy 0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 0 $azt $azv} }
check "CW11 ...and the log fixture was put back (both flags off again)" \
  [pcall {list [xschem getprop rect 2 0 logx] [xschem getprop rect 2 0 logy]}] {0 0}

} cwerr]} { check "CW* group ran to its end" "ERR:$cwerr" ok }

# ============================================================================
# CD* — the DIGITAL axis window (BOTH arms) — D-29
# ============================================================================
# A digital strip's Y is the ypos1/ypos2 BAND, not y1/y2: graph_axis_zoom has
# always written ypos there, but graph_axis_map computed the window from y1/y2
# and S_Y unconditionally, so item 0190's own D-19 was documented and never
# implemented. MEASURED before this change, on y1=0 y2=2.5 ypos1=0 ypos2=4:
# `xschem get graph_axis_map 0 y 636 310` -> `0 1.6437`, i.e. the ANALOG window.
# The two ranges are staged DISJOINT here (0..2.5 and 10..14) so no answer can be
# in both and no leg can pass by accident.
if {[catch {

az_reset
pcall {xschem raw clear}
pcall {xschem raw new azzoom.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {az_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a"}
pcall {xschem unselect_all}
foreach {cdt cdv} {x1 0 x2 1.0 y1 0 y2 2.5 ypos1 10 ypos2 14} {
  pcall {xschem setprop rect 2 0 $cdt $cdv}
}
az_reestablish
# ⚠ the plot box is scanned with digital=0 and the strip is made digital
# AFTERWARDS. graph_plotbox_at refuses digital strips, and the digital box is
# TALLER at the top (setup_graph_data: y1 = ry1 + marginy*0.4 for digital,
# ry1 + marginy otherwise; the bottom edge y2 is identical), so the analog scan
# is a strict SUBSET of the digital extent -- every pixel taken from it is
# inside the digital plot box too and the map's clamp cannot bite.
set cdband [az_band 0 0 800 400]
if {[llength $cdband] != 4} { set cdband {-1 -1 -1 -1} }
set cdbox [az_box 0 $cdband]
if {[llength $cdbox] != 4} { set cdbox {-1 -1 -1 -1} }
lassign $cdbox dbx1 dby1 dbx2 dby2
set dccx [expr {($dbx1 + $dbx2) / 2}]
set dbh  [expr {$dby2 - $dby1}]
set cdpy [expr {$dby2 - int($dbh * 0.25)}]     ;# OFF-CENTRE, as in CW
pcall {xschem setprop rect 2 0 digital 1}
pcall {xschem set_modify 0}
check_true "CD0 the digital fixture: box scanned before digital=1\
 (box=$cdbox py=$cdpy) and the two windows are DISJOINT (y 0..2.5, ypos 10..14)" \
  [pexpr {$dbx1 >= 0 && $dbh > 40 && $cdpy > $dby1 && $cdpy < $dby2 &&
          [xschem getprop rect 2 0 digital] == 1 &&
          [xschem getprop rect 2 0 ypos1] == 10}]
check "CD0 graph_plotbox_at now refuses the strip (teeth: this is exactly why\
 the box had to be scanned first)" \
  [pcall {xschem get graph_plotbox_at 0 $dccx $cdpy}] 0
if {$dbx1 < 0} { stall "CD* pixel scan came up empty" }

# The INDEPENDENT Tcl transform, pixel -> DIGITAL (ypos) value.
# ⚠ `graph_coord` is the WRONG oracle on a digital strip: it inverts the ANALOG
# transform (G_Y) and answers in 0..2.5. But both transforms share the plot box
# EXACTLY -- W_Y(y1) == DW_Y(ypos1) == the box's bottom edge and
# W_Y(y2) == DW_Y(ypos2) == its top (setup_graph_data: dcy = -h/posh,
# ddy = y2 - ypos1*dcy) -- so the FRACTION graph_coord gives is the same fraction
# in ypos space. Nothing here reuses DG_Y, which is the C code under test.
proc cd_qdig {px py} {
  set a [az_coord 0 $px $py 1]
  if {![string is double -strict $a]} { return {} }
  set y1 [xschem getprop rect 2 0 y1]
  set y2 [xschem getprop rect 2 0 y2]
  set p1 [xschem getprop rect 2 0 ypos1]
  set p2 [xschem getprop rect 2 0 ypos2]
  if {$y2 == $y1} { return {} }
  return [expr {$p1 + ($a - $y1) / ($y2 - $y1) * ($p2 - $p1)}]
}

# --- CD1: the WHEEL map answers in the ypos band ----------------------------
set cdm1 [pcall {xschem get graph_axis_wheel_map 0 y $cdpy in}]
check_true "CD1 graph_axis_wheel_map y answers INSIDE ypos1..ypos2 = 10..14\
 (map=$cdm1)" \
  [pexpr {[llength $cdm1] == 2 &&
          [lindex $cdm1 0] > 9.0 && [lindex $cdm1 0] < 15.0 &&
          [lindex $cdm1 1] > 9.0 && [lindex $cdm1 1] < 15.0}]
check_true "CD1 ...and OUTSIDE y1..y2 = 0..2.5, so it cannot be the analog\
 window by accident (map=$cdm1)" \
  [pexpr {[lindex $cdm1 0] > 2.5 && [lindex $cdm1 1] > 2.5}]

# --- CD2: the DRAG map, now on the same shared helper (makes D-19 true) -----
# ⚠ IT MUST BE A **REVERSE** DRAG, and this is not a detail: graph_axis_map's
# FORWARD branch is `lo = A + ua*R` with `ua = (q - A)/R`, which collapses to
# `lo = q` for ANY window. A forward drag therefore cannot see which window the
# map used at all -- measured under SAB-4, where a forward leg stayed green while
# the digital branch was deleted. The reverse branch scales by `R/|s|` and does
# depend on it. The expectation is az_expect (the closed form the AM group is
# built on) evaluated on the YPOS window, and the teeth are that the same closed
# form on the ANALOG window gives a completely different answer.
set cdp0 [expr {$dby1 + 5}]
set cdp1 [expr {$dby2 - int($dbh * 0.25)}]
set cdq0 [pcall {cd_qdig $dccx $cdp0}]
set cdq1 [pcall {cd_qdig $dccx $cdp1}]
set cdm2 [pcall {xschem get graph_axis_map 0 y $cdp0 $cdp1}]
set cde2 [pcall {az_expect 10.0 14.0 $cdq0 $cdq1}]
set cdw2 [pcall {az_expect 0.0 2.5 $cdq0 $cdq1}]
check_true "CD2 the digital drag probe is a REVERSE drag between two distinct\
 ypos values (teeth: q0=$cdq0 q1=$cdq1)" \
  [pexpr {[string is double -strict "$cdq0"] && [string is double -strict "$cdq1"] &&
          $cdq0 > $cdq1 + 1.0 && $cdq0 < 14.001 && $cdq1 > 9.999}]
check_true "CD2 graph_axis_map y == the closed form on the YPOS window\
 (map=$cdm2 expect=$cde2) -- the leg that makes §17.3's D-19 true for the first\
 time" \
  [pexpr {[llength $cdm2] == 2 &&
          [az_close [lindex $cdm2 0] [lindex $cde2 0] 1e-6 4.0] &&
          [az_close [lindex $cdm2 1] [lindex $cde2 1] 1e-6 4.0]}]
check_true "CD2 ...and NOT the closed form on the analog y1/y2 window, which is\
 what it answered before this item (that=$cdw2)" \
  [pexpr {abs([lindex $cdm2 0] - [lindex $cdw2 0]) > 1.0}]

# --- CD3: the fixed point ON THE DIGITAL STRIP ------------------------------
# through cd_qdig above, never graph_coord directly
set cdqb [pcall {cd_qdig $dccx $cdpy}]
check_true "CD3 the independent Tcl transform lands in the ypos band (teeth:\
 q=$cdqb)" [pexpr {[string is double -strict "$cdqb"] && $cdqb > 10.0 && $cdqb < 14.0}]
check_true "CD3 ...and the map agrees with it: (q-lo)/(hi-lo) == (q-A)/(B-A)\
 (map=$cdm1 q=$cdqb)" \
  [pexpr {[az_close [expr {($cdqb - [lindex $cdm1 0]) /
                           ([lindex $cdm1 1] - [lindex $cdm1 0])}] \
                    [expr {($cdqb - 10.0) / 4.0}] 1e-6 1.0]}]
pcall {xschem graph_axis_zoom 0 y [lindex $cdm1 0] [lindex $cdm1 1]}
set cdqa [pcall {cd_qdig $dccx $cdpy}]
check_true "CD3 THE FIXED POINT on the digital strip (before=$cdqb\
 after=$cdqa)" [pexpr {[az_close $cdqa $cdqb 1e-6 4.0]}]

# --- CD4: the apply writes ypos and leaves y1/y2 alone ----------------------
check_true "CD4 ypos1/ypos2 were written and narrowed by K\
 (ypos=[pcall {list [xschem getprop rect 2 0 ypos1] [xschem getprop rect 2 0 ypos2]}])" \
  [pexpr {[az_close [expr {[xschem getprop rect 2 0 ypos2] -
                           [xschem getprop rect 2 0 ypos1]}] \
                    [expr {4.0 * $::cwK}] 1e-6 4.0]}]
check "CD4 ...and y1/y2 are byte-identical" \
  [pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]}] {0 2.5}

} cderr]} { check "CD* group ran to its end" "ERR:$cderr" ok }

# ============================================================================
# CS* — source-level one-home tripwires (BOTH arms; CS3 is DISPLAY-only)
# ============================================================================
if {[catch {

set csdraw  [az_slurp [file join $repo src draw.c]]
set cscb    [az_slurp [file join $repo src callback.c]]
set cssched [az_slurp [file join $repo src scheduler.c]]
set csview  [az_slurp [file join $repo src wave_viewer.tcl]]
check_true "CS0 the four sources were read" \
  [pexpr {[string length $csdraw] > 1000 && [string length $cscb] > 1000 &&
          [string length $cssched] > 1000 && [string length $csview] > 1000}]

# --- CS1: the anchor and the two call sites ---------------------------------
check "CS1 the anchored WHEEL expression appears in draw.c exactly ONCE" \
  [az_count_code $csdraw {q - u \* R2}] 1
check "CS1 graph_axis_wheel_map is CALLED from callback.c exactly once" \
  [az_count_code $cscb {graph_axis_wheel_map\(}] 1
check "CS1 ...and from scheduler.c exactly once" \
  [az_count_code $cssched {graph_axis_wheel_map\(}] 1
check "CS1 neither carries a copy of the anchored expression" \
  [expr {[az_count_code $cscb {q - u \* R2}] +
         [az_count_code $cssched {q - u \* R2}]}] 0
check "CS1 the wheel FACTOR has exactly one home in C: draw.c uses it, the\
 gesture and the verb pass a DIRECTION word instead" \
  [list [az_count_code $csdraw {GRAPH_AXIS_WHEEL_FACTOR}] \
        [az_count_code $cscb  {GRAPH_AXIS_WHEEL_FACTOR}] \
        [az_count_code $cssched {GRAPH_AXIS_WHEEL_FACTOR}]] {2 0 0}

# --- CS2: the MIRRORED constant ---------------------------------------------
# src/xschem.h's GRAPH_AXIS_WHEEL_FACTOR and wviewer::wheel_zoom's `f` literal
# are the same number in two languages -- the viewer's BODY zoom still computes
# its own window with zoom_about while its MARGIN arms take theirs from C, so a
# drift would make one gesture step differently depending on where the pointer
# is. This is the GRAPH_REORDER_HANDLE_W precedent, and both sides carry a
# "change both" comment.
proc cs_tcl_factor {src} {
  set inproc 0
  foreach line [split $src "\n"] {
    if {[string match "proc wviewer::wheel_zoom *" [string trimleft $line]]} {
      set inproc 1
      continue
    }
    if {!$inproc} continue
    if {[regexp {set f +\[expr +\{[^?]*\? *([-+0-9.eE]+) *:} $line -> v]} {
      if {[string is double -strict $v]} { return $v }
    }
  }
  return {}
}
set cstcl [pcall {cs_tcl_factor $csview}]
check_true "CS2 the Tcl-side factor was parsed out of wviewer::wheel_zoom\
 (teeth: {$cstcl})" \
  [pexpr {[string is double -strict "$cstcl"] && $cstcl > 0.0 && $cstcl < 1.0}]
check "CS2 GRAPH_AXIS_WHEEL_FACTOR (src/xschem.h) == wviewer::wheel_zoom's f\
 literal (src/wave_viewer.tcl)" \
  [pexpr {"$::cwK" eq "$cstcl" ? 1 : 0}] 1
check_true "CS2 ...and BOTH sides carry a change-both warning next to the\
 literal (the GRAPH_REORDER_HANDLE_W precedent)" \
  [pexpr {[regexp -all {MIRRORED IN TCL} [az_slurp [file join $repo src xschem.h]]] > 0 &&
          [regexp -all {MIRRORED IN C} $csview] > 0}]

# --- CS4: the axis WINDOW has one home, and it knows about digital ----------
check "CS4 graph_axis_window appears in draw.c exactly 3 times (one definition\
 + one call from each formula)" [az_count_code $csdraw {graph_axis_window\(}] 3
check "CS4 the digital/ypos decision is made exactly ONCE" \
  [az_count_code $csdraw {DS_Y\(gr->ypos1\)}] 1
# the body of a function, from its signature to the first bare closing brace in
# column 1 -- the AS2 idiom
proc cs_body {src sig} {
  set st [string first $sig $src]
  if {$st < 0} { return {} }
  set tail [string range $src $st end]
  if {[regexp {(?s)^(.*?\n\})\n} $tail -> b]} { return $b }
  return {}
}
set cswb [pcall {cs_body $csdraw "int graph_axis_wheel_map(int i, int axis"}]
set csmb [pcall {cs_body $csdraw "int graph_axis_map(int i, int axis"}]
check_true "CS4 both formula bodies were located (teeth for the next leg)" \
  [pexpr {[string length $cswb] > 300 && [string length $csmb] > 300 &&
          [string first "graph_axis_window(" $cswb] > 0 &&
          [string first "graph_axis_window(" $csmb] > 0}]
check "CS4 ...and NEITHER formula resolves the window itself any more: no\
 S_X(/S_Y(/DS_Y( survives in either body" \
  [pexpr {[regexp -all {S_X\(|S_Y\(|DS_Y\(} $cswb] +
          [regexp -all {S_X\(|S_Y\(|DS_Y\(} $csmb]}] 0
# ⚠ az_count_code skips C comment leaders, not Tcl's `#`. This is the Tcl form.
proc cs_count_tcl {src pat} {
  set n 0
  foreach line [split $src "\n"] {
    if {[string index [string trimleft $line] 0] eq "#"} { continue }
    incr n [regexp -all $pat $line]
  }
  return $n
}
check "CS4 the viewer asks C for the window in exactly ONE place and derives\
 nothing itself (D-22: no second copy of the plot-box geometry in Tcl)" \
  [pcall {cs_count_tcl $csview {graph_axis_wheel_map}}] 1
check "CS4 ...and carries no copy of the anchored expression" \
  [pcall {cs_count_tcl $csview {q - u \* R2}}] 0

} cserr]} { check "CS* group ran to its end" "ERR:$cserr" ok }

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
# 257 = Button1Mask | ShiftMask: a drag with Shift added mid-gesture. This is
# one of waves_selected()'s `skip` clauses, i.e. the route that reaches its
# !is_inside branch WITHOUT the pointer having left the strip. AG15's lever.
proc ag_shdrag {x y} { xschem callback .drw 6 $x $y 0 0 0 257 }
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

# --- AG14: the GRAPHPAN ROUTING LATCH, and the release that LEAVES the strip -
#
# THE PROBE-PLACEMENT LESSON OF THIS ITEM, in one leg. Every AG/AX gesture above
# releases INSIDE the strip it pressed in -- and there the correct engine and one
# missing the `|| xctx->graph_axis_drag` term in the GRAPHPAN latch
# (callback.c, the routing latch of landmine 36) give the SAME answer, because
# waves_selected's POINTINSIDE arm re-finds the strip on its own and the release
# reaches waves_callback either way. Deleting that term therefore left all 338
# checks green while silently breaking a real, reachable gesture. A leg driven
# from a path where the right and the wrong implementation agree is not a leg.
#
# The path where they disagree needs BOTH halves:
#   (a) graph_top must already be 1 at the press, or the latch fires on its
#       `!graph_top` term regardless. graph_axis_at's Y region is "left of the
#       plot box, ANYWHERE in the container", so the TOP-LEFT corner is a Y
#       region whose press sits ABOVE the plot box -- graph_top = 1. It only
#       answers Y on a strip that owns no legend entry there: with a `node`
#       token the horizontal legend's slot 0 spans rx1+2 .. rx1+rw/n across the
#       whole top band (legend_slot_hit, draw.c), and graph_axis_at declines it.
#       Hence a third strip carrying NO `node` token.
#   (b) the release must LEAVE the strip, so that nothing but the latch can
#       route it back. Released to the LEFT of the container band, at 1/4 of the
#       plot box's height.
# Without the term: no GRAPHPAN, waves_selected answers 0 for the release,
# waves_callback never runs, and the zoom is silently dropped.
pcall {az_graph 0 1000 800 1400}
foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 2 $azt $azv} }
pcall {xschem unselect_all}
pcall {xschem set_modify 0}
az_reestablish
set ag14band [az_band 0 1000 800 1400]
set ag14box  [az_box 2 $ag14band]
if {[llength $ag14band] != 4} { set ag14band {-1 -1 -1 -1} }
if {[llength $ag14box]  != 4} { set ag14box  {-1 -1 -1 -1} }
lassign $ag14band a4ux1 a4uy1 a4ux2 a4uy2
lassign $ag14box  a4bx1 a4by1 a4bx2 a4by2
# the TOP-LEFT corner: half way into the left margin, half way up the top margin
set a4px [expr {($a4ux1 + $a4bx1) / 2}]
set a4py [expr {($a4uy1 + $a4by1) / 2}]
# the release: LEFT of the container band, at 1/4 of the box height
set a4rx [expr {$a4ux1 - 6 > 0 ? $a4ux1 - 6 : 2}]
set a4ry [expr {$a4by1 + ($a4by2 - $a4by1) / 4}]
check_true "AG14 the legend-less third strip scanned: band=$ag14band box=$ag14box\
 press=($a4px,$a4py) release=($a4rx,$a4ry)" \
  [pexpr {$a4bx1 >= 0 && $a4bx2 - $a4bx1 > 60 && $a4by2 - $a4by1 > 40 &&
          $a4bx1 - $a4ux1 >= 6 && $a4by1 - $a4uy1 >= 6}]
if {$a4bx1 < 0} { stall "AG14 strip-2 pixel scan came up empty" }
check "AG14 that strip really owns no legend entry at the corner (teeth: with a\
 `node` token the horizontal legend claims the whole top band and this is {})" \
  [pcall {xschem get graph_legend_at 2 $a4px $a4py}] -1
check "AG14 the TOP-LEFT corner is the strip's Y region" \
  [pcall {xschem get graph_axis_at 2 $a4px $a4py}] y
check_true "AG14 ...and it is ABOVE the plot box, so the press latches\
 graph_top = 1 (press y=$a4py, plot-box top=$a4by1)" [pexpr {$a4py < $a4by1}]
check_true "AG14 the release pixel is LEFT of the container band, i.e. OUTSIDE\
 the strip ($a4rx < $a4ux1)" [pexpr {$a4rx < $a4ux1}]
check "AG14 ...and no strip of the fixture claims it" \
  [pcall {list [xschem get graph_axis_at 0 $a4rx $a4ry] \
               [xschem get graph_axis_at 1 $a4rx $a4ry] \
               [xschem get graph_axis_at 2 $a4rx $a4ry]}] {{} {} {}}
set ag14m  [pcall {xschem get graph_axis_map 2 y $a4py $a4ry}]
set ag14w0 [pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2] \
                        [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}]
ag_unlatch
pcall {ag_press $a4px $a4py}
check "AG14 the corner press arms the Y axis drag" \
  [pcall {xschem get graph_axis_drag}] y
check_true "AG14 ...and it LATCHED GRAPHPAN even though graph_top is already 1 --\
 THE ROUTING-LATCH TERM ITSELF (ui_state=[pcall {xschem get ui_state}], bit 15)" \
  [pexpr {[string is integer -strict [pcall {xschem get ui_state}]] &&
          ([pcall {xschem get ui_state}] & 32768)}]
pcall {ag_drag $a4rx $a4ry}
pcall {ag_rel  $a4rx $a4ry}
check_true "AG14 a release OUTSIDE the strip still COMMITTED the map's lo\
 (map=$ag14m got=[pcall {list [xschem getprop rect 2 2 y1] [xschem getprop rect 2 2 y2]}])" \
  [pexpr {[az_close [xschem getprop rect 2 2 y1] [lindex $ag14m 0] 1e-6]}]
check_true "AG14 ...and its hi" \
  [pexpr {[az_close [xschem getprop rect 2 2 y2] [lindex $ag14m 1] 1e-6]}]
check_true "AG14 ...and it really zoomed OUT (y1 went negative)" \
  [pexpr {[xschem getprop rect 2 2 y1] < 0.0}]
check "AG14 ...and the arm is back to nothing" [pcall {xschem get graph_axis_drag}] {}
check "AG14 ...and the other two strips are byte-identical (Y never propagates)" \
  [pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2] \
               [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}] $ag14w0

# --- AG15: an ABANDONED arm must not poison the NEXT gesture ----------------
#
# waves_selected's `if(!is_inside)` branch drops an armed MARKER drag; it did not
# drop an armed AXIS drag. That looks unreachable -- GRAPHPAN keeps the
# pointer-outside case out of the branch (AG14 above is exactly that case) -- but
# every `skip = 1` clause jumps the rect loop entirely, leaving is_inside 0 with
# GRAPHPAN still set. Adding Shift mid-drag is one such clause
# (`event == MotionNotify && Button1Mask && ShiftMask`).
#
# MEASURED before the fix: the abandoned arm survived the shift AND the release
# (the same skip keeps waves_callback out), and graph_axis_press_arm() does not
# clear it either -- it returns early when the new press is not in a margin. The
# next plain LMB press-drag in the PLOT BODY, which owns no axis gesture at all,
# then committed a zoom from the abandoned press position: y1/y2 0..2.5 ->
# 1.2537228..2.3920389.  NO ESC anywhere in this leg: abort_operation() clears
# the arm and would mask the whole thing.
foreach i {0 1 2} {
  foreach {azt azv} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 $i $azt $azv} }
}
pcall {xschem set_modify 0}
set a5px [expr {($a4ux1 + $a4bx1) / 2}]
set a5py [expr {($a4by1 + $a4by2) / 2}]
set a5uy [expr {$a4by1 + 15}]
set a5cx [expr {($a4bx1 + $a4bx2) / 2}]
check "AG15 the staging pixel is strip 2's left margin (teeth)" \
  [pcall {xschem get graph_axis_at 2 $a5px $a5py}] y
check "AG15 ...and the body pixel is NOT an axis region (teeth)" \
  [pcall {xschem get graph_axis_at 2 $a5cx $a5py}] {}
ag_unlatch
set ag15w [az_windows]
pcall {ag_press $a5px $a5py}
check "AG15 the margin press armed the Y axis drag (teeth)" \
  [pcall {xschem get graph_axis_drag}] y
check_true "AG15 ...and latched GRAPHPAN (teeth)" \
  [pexpr {[pcall {xschem get ui_state}] & 32768}]
pcall {ag_shdrag $a5px $a5uy}
check_true "AG15 the Shift+B1 motion really took waves_selected's SKIP route --\
 GRAPHPAN is gone, so the !is_inside branch ran (teeth)" \
  [pexpr {!([pcall {xschem get ui_state}] & 32768)}]
check "AG15 ...and the ABANDONED axis arm went with it" \
  [pcall {xschem get graph_axis_drag}] {}
pcall {ag_rel $a5px $a5uy}
check "AG15 the release after the abandon commits nothing" [az_windows] $ag15w
pcall {xschem unselect_all}
set ag15b [az_windows]
pcall {ag_press $a5cx $a5py}
check "AG15 a following PLOT-BODY press arms nothing (a stale arm would still\
 read `y` here)" [pcall {xschem get graph_axis_drag}] {}
pcall {ag_drag $a5cx $a5uy}
pcall {ag_rel  $a5cx $a5uy}
check "AG15 ...and the plot-BODY drag commits NO zoom on any strip (before the\
 abort it committed the abandoned press's)" [az_windows] $ag15b
ag_unlatch
check "AG15 ...and none of it dirtied the buffer" [pcall {xschem get modified}] 0

} azgerr]} { check "AG* group ran to its end" "ERR:$azgerr" ok }
} else {
  puts "SKIPPED: AG* (no DISPLAY / no .drw canvas)"
}

# ============================================================================
# CE* — the real CTRL+WHEEL gesture on an on-canvas graph (DISPLAY only)
# ============================================================================
# `xschem callback .drw 4 <px> <py> 0 <4|5> 0 <state>`: ButtonPress of Button4
# (wheel up) / Button5 (wheel down), state 4 = ControlMask, 1 = ShiftMask.
# MEASURED at HEAD, before this item, and every "unchanged" leg below asserts
# the measurement rather than a comment (three comments in the tree said the
# canvas panned or zoomed; it does neither):
#   chord        plot BODY              X margin          Y margin
#   plain        graph X pan +-0.05*gw  graph X pan       graph Y pan +-gh/divy
#   Shift        graph X zoom x0.8/x1.2 same              graph Y zoom
#   Ctrl         graph X pan (== plain) graph X pan       graph Y pan
# and xorigin/yorigin/zoom never moved in any of the twelve trials.
if {$::az_have_x && [winfo exists .drw]} {
if {[catch {

proc ce_move   {x y {st 0}} { xschem callback .drw 6 $x $y 0 0 0 $st }
proc ce_wheel  {x y btn st} { xschem callback .drw 4 $x $y 0 $btn 0 $st }
proc ce_unlatch {} {
  catch {xschem callback .drw 2 2 2 65307 0 0 0}
  catch {xschem callback .drw 5 2 2 0 1 0 256}
  catch {xschem callback .drw 6 2 2 0 0 0 0}
  catch {xschem unselect_all}
}
# one wheel click, with the Motion that precedes it in a real gesture (the C
# mouse mirror is stale for an event with no preceding Motion)
proc ce_click {x y btn st} {
  ce_unlatch
  ce_move  $x $y $st
  ce_wheel $x $y $btn $st
}
proc ce_win {gi} {
  set o {}
  foreach t {x1 x2 y1 y2} { lappend o [xschem getprop rect 2 $gi $t] }
  return $o
}
proc ce_canvas {} {
  return [list [xschem get xorigin] [xschem get yorigin] [xschem get zoom]]
}

az_reset
pcall {xschem raw clear}
pcall {xschem raw new azzoom.raw dc vsweep 0 1.0 0.1}
pcall {xschem raw add v_a {vsweep 1 +}}
pcall {az_graph 0 0 800 400}
pcall {xschem setprop rect 2 0 node "v_a"}
pcall {az_graph 0 500 800 900}
pcall {xschem setprop rect 2 1 node "v_a"}
pcall {xschem unselect_all}
proc ce_stage {} {
  foreach i {0 1} {
    foreach {t v} {x1 0 x2 1.0 y1 0 y2 2.5} { pcall {xschem setprop rect 2 $i $t $v} }
  }
  pcall {xschem set_modify 0}
}
ce_stage
az_reestablish
az_scan
lassign $azbox  ebx1 eby1 ebx2 eby2
lassign $azband eux1 euy1 eux2 euy2
lassign $azxm   exmx exmy
lassign $azym   eymx eymy
set ecx [expr {($ebx1 + $ebx2) / 2}]
set ecy [expr {($eby1 + $eby2) / 2}]
set ebw [expr {$ebx2 - $ebx1}]
# ⚠ OFF-CENTRE, for CW's reason: at the box centre the anchored map and a
# zoom-about-centre map agree and CE2 could not tell them apart.
set epx [expr {$ebx1 + int($ebw * 0.25)}]
set EA  [pcall {xschem getprop rect 2 0 x1}]
set EB  [pcall {xschem getprop rect 2 0 x2}]
set ER  [pexpr {$EB - $EA}]
check_true "CE0 the CE fixture scanned: box=$azbox xm=$azxm ym=$azym probe\
 px=$epx (off-centre by [expr {abs($epx - $ecx)}] px)" \
  [pexpr {$ebx1 >= 0 && $ebw > 60 && $exmx >= 0 && $eymx >= 0 &&
          abs($epx - $ecx) > $ebw * 0.15 && $ER > 0}]
if {$ebx1 < 0 || $exmx < 0 || $eymx < 0} { stall "CE* pixel scan came up empty" }

# --- CE1/CE1b: CTRL+wheel-up in the X margin --------------------------------
ce_stage
set ce1m [pcall {xschem get graph_axis_wheel_map 0 x $epx in}]
set ce1q [az_coord 0 $epx $ecy 0]
pcall {ce_click $epx $exmy 4 4}
set ce1w [pcall {ce_win 0}]
check_true "CE1 CTRL+wheel-up in the X margin narrowed the X window by exactly\
 K=$::cwK (window=$ce1w)" \
  [pexpr {[az_close [expr {[lindex $ce1w 1] - [lindex $ce1w 0]}] \
                    [expr {$ER * $::cwK}] 1e-6 $ER]}]
check_true "CE1b ...and it is EXACTLY graph_axis_wheel_map's answer, so the\
 gesture did not ALSO pan (map=$ce1m window=$ce1w)" \
  [pexpr {[az_close [lindex $ce1w 0] [lindex $ce1m 0] 1e-6 $ER] &&
          [az_close [lindex $ce1w 1] [lindex $ce1m 1] 1e-6 $ER]}]
set ce2q [az_coord 0 $epx $ecy 0]
check_true "CE2 THE FIXED POINT: the data x under the pointer pixel is\
 unchanged (before=$ce1q after=$ce2q)" \
  [pexpr {[az_close $ce2q $ce1q 1e-6 $ER]}]
check "CE1 ...and the Y window is byte-identical" \
  [list [lindex $ce1w 2] [lindex $ce1w 3]] {0 2.5}

# --- CE3: CTRL+wheel in the Y margin ----------------------------------------
ce_stage
set ce3b [az_windows]
pcall {ce_click $eymx $ecy 4 4}
set ce3a [az_windows]
check_true "CE3 CTRL+wheel-up in the Y margin narrowed rect 0's Y window by K\
 (y=[pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]}])" \
  [pexpr {[az_close [expr {[xschem getprop rect 2 0 y2] -
                           [xschem getprop rect 2 0 y1]}] \
                    [expr {2.5 * $::cwK}] 1e-6 2.5]}]
check "CE3 ...on the pointed rect ONLY (rect 1's y1/y2 untouched)" \
  [pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}] {0 2.5}
check "CE3 ...and EVERY rect's x1/x2 is byte-identical" \
  [pcall {set o {}; foreach row $ce3a { lappend o [lrange $row 0 1] }; set o}] \
  [pcall {set o {}; foreach row $ce3b { lappend o [lrange $row 0 1] }; set o}]

# --- CE4: wheel-DOWN is the inverse -----------------------------------------
ce_stage
pcall {ce_click $epx $exmy 5 4}
set ce4w [pcall {ce_win 0}]
check_true "CE4 CTRL+wheel-DOWN widens the X window by 1/K (window=$ce4w)" \
  [pexpr {[az_close [expr {[lindex $ce4w 1] - [lindex $ce4w 0]}] \
                    [expr {$ER / $::cwK}] 1e-6 $ER]}]
pcall {ce_click $epx $exmy 4 4}
set ce4r [pcall {ce_win 0}]
check_true "CE4 ...and out-then-in restores the window (got=$ce4r want=$EA $EB)" \
  [pexpr {[az_close [lindex $ce4r 0] $EA 1e-6 $ER] &&
          [az_close [lindex $ce4r 1] $EB 1e-6 $ER]}]

# --- CE5: CTRL+wheel in the plot BODY is UNCHANGED --------------------------
# MEASURED at HEAD: a graph X PAN of 0.05*gw, byte-identical to a plain wheel,
# with the canvas untouched. NOT a canvas pan (callback.c's binding-table comment
# said so) and NOT a canvas zoom (wave_viewer.tcl's said so). Both were wrong
# over a graph -- landmine 48.
ce_stage
set ce5c [pcall {ce_canvas}]
pcall {ce_click $ecx $ecy 4 4}
set ce5w [pcall {ce_win 0}]
check "CE5 CTRL+wheel-up in the plot BODY still PANS X by 0.05*gw, it does not\
 zoom" [list [lindex $ce5w 0] [lindex $ce5w 1]] {0.05 1.05}
check "CE5 ...and left Y alone" \
  [list [lindex $ce5w 2] [lindex $ce5w 3]] {0 2.5}
check "CE5 ...and never touched the CANVAS (xorigin/yorigin/zoom)" \
  [pcall {ce_canvas}] $ce5c

# --- CE6/CE7: the other chords in the margins are UNCHANGED (D-31) ----------
ce_stage
pcall {ce_click $epx $exmy 4 0}
check "CE6 a PLAIN wheel in the X margin still pans X by 0.05*gw" \
  [pcall {list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]}] {0.05 1.05}
ce_stage
pcall {ce_click $eymx $ecy 4 0}
check_true "CE6 a PLAIN wheel in the Y margin still pans Y (window kept its\
 WIDTH, so it panned and did not zoom: y=[pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]}])" \
  [pexpr {[xschem getprop rect 2 0 y1] != 0 &&
          [az_close [expr {[xschem getprop rect 2 0 y2] -
                           [xschem getprop rect 2 0 y1]}] 2.5 1e-6 2.5]}]
ce_stage
pcall {ce_click $epx $exmy 4 1}
set ce7i [pcall {ce_win 0}]
ce_stage
pcall {ce_click $epx $exmy 5 1}
set ce7o [pcall {ce_win 0}]
check_true "CE7 SHIFT+wheel in the X margin still zooms X by the SHIPPED\
 0.2-of-the-range step: x0.8 in (=$ce7i)" \
  [pexpr {[az_close [expr {[lindex $ce7i 1] - [lindex $ce7i 0]}] \
                    [expr {$ER * 0.8}] 1e-4 $ER]}]
check_true "CE7 ...and x1.2 out, deliberately NOT 1/K -- the shipped arm is not\
 reversible and this item did not change it (=$ce7o)" \
  [pexpr {[az_close [expr {[lindex $ce7o 1] - [lindex $ce7o 0]}] \
                    [expr {$ER * 1.2}] 1e-4 $ER]}]

# --- CE8: no dirty flag (D-35) ----------------------------------------------
ce_stage
pcall {ce_click $epx $exmy 4 4}
pcall {ce_click $eymx $ecy 4 4}
check "CE8 after two CTRL+wheel zooms the buffer is still modified 0 (a zoom is\
 view state: no set_modify, no undo point)" [pcall {xschem get modified}] 0

# --- CE10: the same gesture on a strip whose index is NOT 0 -----------------
# The Y half is the decisive one: Y never propagates, so "rect 1 moved and rect
# 0 did not" can only mean the arm followed the POINTED strip (the AG13 lesson).
set ce10band [az_band 0 500 800 900]
set ce10box  [az_box 1 $ce10band]
set ce10xm   [az_xmargin $ce10box $ce10band]
set ce10ym   [az_ymargin $ce10box $ce10band]
if {[llength $ce10box] != 4} { set ce10box {-1 -1 -1 -1} }
if {[llength $ce10xm] != 2} { set ce10xm {-1 -1} }
if {[llength $ce10ym] != 2} { set ce10ym {-1 -1} }
lassign $ce10box e1x1 e1y1 e1x2 e1y2
lassign $ce10xm  e1mx e1my
lassign $ce10ym  e1yx e1yy
set e1cy [expr {($e1y1 + $e1y2) / 2}]
check_true "CE10 strip 1 was scanned: box=$ce10box xm=$ce10xm ym=$ce10ym" \
  [pexpr {$e1x1 >= 0 && $e1mx >= 0 && $e1yx >= 0 && $e1x2 - $e1x1 > 60}]
if {$e1x1 < 0 || $e1mx < 0 || $e1yx < 0} { stall "CE10 strip-1 pixel scan came up empty" }
ce_stage
pcall {ce_click $e1yx $e1cy 4 4}
check_true "CE10 a CTRL+wheel in STRIP 1's Y margin zoomed RECT 1\
 (y=[pcall {list [xschem getprop rect 2 1 y1] [xschem getprop rect 2 1 y2]}])" \
  [pexpr {[az_close [expr {[xschem getprop rect 2 1 y2] -
                           [xschem getprop rect 2 1 y1]}] \
                    [expr {2.5 * $::cwK}] 1e-6 2.5]}]
check "CE10 ...and left RECT 0's y1/y2 byte-identical, so the arm followed the\
 POINTED strip and not index 0" \
  [pcall {list [xschem getprop rect 2 0 y1] [xschem getprop rect 2 0 y2]}] {0 2.5}
ce_stage
pcall {ce_click $e1mx $e1my 4 4}
check_true "CE10 a CTRL+wheel in STRIP 1's X margin zoomed rect 1 AND\
 propagated to rect 0 (r1=[pcall {ce_win 1}] r0=[pcall {ce_win 0}])" \
  [pexpr {[xschem getprop rect 2 0 x1] eq [xschem getprop rect 2 1 x1] &&
          [xschem getprop rect 2 0 x2] eq [xschem getprop rect 2 1 x2] &&
          [az_close [expr {[xschem getprop rect 2 1 x2] -
                           [xschem getprop rect 2 1 x1]}] \
                    [expr {$ER * $::cwK}] 1e-6 $ER]}]

# --- CE11: graph_use_ctrl_key reserves Ctrl for ACCESS (D-32) ---------------
set ce11save 0
catch {set ce11save $::graph_use_ctrl_key}
check "CE11 the mode starts OFF, so the feature is on out of the box (teeth)" \
  $ce11save 0
ce_stage
pcall {set ::graph_use_ctrl_key 1}
check "CE11 the mode is really on now (teeth: the C side reads this Tcl var\
 through tclgetboolvar on every event)" [pcall {set ::graph_use_ctrl_key}] 1
pcall {ce_click $epx $exmy 4 4}
check "CE11 with graph_use_ctrl_key=1 a CTRL+wheel in the X margin PANS, it\
 does not zoom -- Ctrl is the ACCESS modifier there, not a gesture selector" \
  [pcall {list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]}] {0.05 1.05}
pcall {set ::graph_use_ctrl_key $ce11save}
check "CE11 ...and the mode was restored" [pcall {set ::graph_use_ctrl_key}] $ce11save
ce_stage

# --- CE12: CTRL+SHIFT+wheel is the SHIPPED Shift zoom, and nothing else -----
# `!(state & ShiftMask)` in the new arm (callback.c) has exactly one job: leave
# Ctrl+Shift to the shipped 0.2-of-the-range Shift arms in the per-graph loop.
# Until this leg NOTHING in tests/headless sent a state-5 wheel over a graph --
# every ce_click above uses state 0, 1 or 4 and cv_wheel is hard-coded to
# -state 4 -- so deleting the term left both arms of the suite green.
#
# ⚠ THE WINDOW IS ONLY HALF THE TEETH, and which half depends on the axis.
# MEASURED with the term deleted: the new arm fires and applies on both margins,
# but the per-graph loop below opens with `gr->gx1 = gr->master_gx1` (:1932 --
# captured in the master block BEFORE the zoom), so on the X margin the Shift arm
# recomputes from the PRE-zoom window and overwrites with byte-identical numbers:
# the X legs here stay GREEN under that sabotage and cannot see the double apply.
# The Y margin is the opposite -- setup_graph_data(i, 1, gr) skips only x, so
# gy1/gy2 are re-read from the tokens the suppressed arm just wrote and the Y leg
# below goes red. What sees BOTH is the replay LOG: graph_axis_zoom() self-logs,
# so the suppressed arm leaves a line behind on its way past. CE13 is that leg.
# This one is still worth its lines: it is the user-visible statement, it has real
# teeth on Y, and it is what would catch a future arm that is NOT overwritten.
foreach {ce12ax ce12x ce12y ce12dir ce12btn} [list \
    {X margin}  $epx  $exmy  up   4 \
    {X margin}  $epx  $exmy  down 5 \
    {Y margin}  $eymx $ecy   up   4] {
  ce_stage
  pcall {ce_click $ce12x $ce12y $ce12btn 1}      ;# SHIFT alone: the reference
  set ce12ref [pcall {ce_win 0}]
  ce_stage
  set ce12base [pcall {ce_win 0}]
  pcall {ce_click $ce12x $ce12y $ce12btn 5}      ;# CTRL+SHIFT (4|1)
  set ce12got [pcall {ce_win 0}]
  check_true "CE12 the SHIFT-alone reference really moved the window in the\
 $ce12ax, wheel-$ce12dir (teeth: otherwise the next check compares two no-ops)\
 base=$ce12base ref=$ce12ref" \
    [pexpr {$ce12ref ne $ce12base}]
  check "CE12 CTRL+SHIFT+wheel-$ce12dir in the $ce12ax gives the SHIPPED Shift\
 window, byte for byte -- the new Ctrl arm stood aside" $ce12got $ce12ref
}
ce_stage

# --- CE9: the gesture self-logs one replayable line -------------------------
# A --logdir CHILD, as the AL group does, but this one needs a real DISPLAY
# because the gesture goes through .drw. The pixel scan happens IN THE CHILD:
# its canvas is not this process's, so a pixel computed here would mean nothing
# there. The helper procs are shipped over by source text rather than retyped.
proc ce_proc_src {name} {
  set as {}
  foreach a [info args $name] {
    if {[info default $name $a d]} { lappend as [list $a $d] } else { lappend as $a }
  }
  return [list proc $name $as [info body $name]]
}
set cehelpers {}
foreach p {az_band az_box az_xmargin az_ymargin} {
  append cehelpers [ce_proc_src $p] "\n"
}
set cec1 [file join $scratch ce_child1.tcl]
set ced1 [file join $scratch celog1]
file delete -force $ced1
file mkdir $ced1
set cefix "set no_recent_files 1
$cehelpers
xschem raw clear
xschem raw new cezoom.raw dc vsweep 0 1.0 0.1
xschem raw add v_a {vsweep 1 +}
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem rect 0 1000 800 1400 -1 {flags=graph} 0
xschem unselect_all
foreach i {0 1} {
  xschem setprop rect 2 \$i node v_a
  foreach {t v} {x1 0 x2 1.0 y1 0 y2 2.5} { xschem setprop rect 2 \$i \$t \$v }
}
xschem set_modify 0"
al_child $cec1 "$cefix
catch {wm deiconify .}
catch {raise .}
for {set i 0} {\$i < 200} {incr i} {
  catch {update}
  if {\[winfo exists .drw] && \[winfo ismapped .drw]} break
  after 20
}
catch {xschem zoom_full}
catch {update}
set band \[az_band 0 0 800 400]
set box  \[az_box 0 \$band]
set xm   \[az_xmargin \$box \$band]
set ym   \[az_ymargin \$box \$band]
if {\[llength \$box] != 4 || \[llength \$xm] != 2 || \[llength \$ym] != 2} {
  puts CE-CHILD-NOBOX; exit 0
}
lassign \$box bx1 by1 bx2 by2
lassign \$xm  mx my
lassign \$ym  yx yy
set px \[expr {\$bx1 + int((\$bx2 - \$bx1) * 0.25)}]
xschem callback .drw 6 \$px \$my 0 0 0 4
xschem callback .drw 4 \$px \$my 0 4 0 4
puts \"child r0=\[xschem getprop rect 2 0 x1] \[xschem getprop rect 2 0 x2]\"
puts \"child r1=\[xschem getprop rect 2 1 x1] \[xschem getprop rect 2 1 x2]\"
# CE13's gestures, in THIS child rather than a second one: every extra GUI
# process is another toplevel appearing and vanishing on the display, and under
# WSLg that restacks/resizes the parent's canvas -- measured, it put the AX/CV
# groups' cached probe pixels on the wrong strip about 1 run in 8. Re-stage
# first so the Shift arms start from the same window the Ctrl gesture did.
foreach i {0 1} { foreach {t v} {x1 0 x2 1.0 y1 0 y2 2.5} { xschem setprop rect 2 \$i \$t \$v } }
puts \"child cs-pre=\[xschem getprop rect 2 0 x1] \[xschem getprop rect 2 0 x2]\
 \[xschem getprop rect 2 0 y1] \[xschem getprop rect 2 0 y2]\"
xschem callback .drw 6 \$px \$my 0 0 0 5
xschem callback .drw 4 \$px \$my 0 4 0 5
xschem callback .drw 6 \$yx \$yy 0 0 0 5
xschem callback .drw 4 \$yx \$yy 0 4 0 5
puts \"child cs-post=\[xschem getprop rect 2 0 x1] \[xschem getprop rect 2 0 x2]\
 \[xschem getprop rect 2 0 y1] \[xschem getprop rect 2 0 y2]\"
puts CE-CHILD-DONE
exit 0"
set cerc [catch {exec [info nameofexecutable] --pipe -q \
                      --logdir $ced1 --script $cec1 2>@1} ceout]
set celines {}
foreach cef [lsort [glob -nocomplain [file join $ced1 *]]] {
  foreach cel [split [az_slurp $cef] "\n"] { lappend celines $cel }
}
if {$cerc || ![string match {*CE-CHILD-DONE*} $ceout]} {
  note "CE child output: [string range $ceout end-500 end]"
  stall "CE gesture child did not reach its sentinel"
}
check "CE9 the --logdir GUI child ran the gesture to its end" \
  [expr {[string match {*CE-CHILD-DONE*} $ceout] ? 1 : 0}] 1
check "CE9 the GESTURE self-logged EXACTLY ONE graph_axis_zoom line (the child\
 delivers three wheels -- one CTRL and CE13's two CTRL+SHIFT -- and only the\
 CTRL one may log)" \
  [al_count $celines {xschem graph_axis_zoom 0 x *}] 1
check "CE9 ...and no y line, and no pixel query was logged" \
  [expr {[al_count $celines {xschem graph_axis_zoom * y *}] +
         [al_count $celines {*graph_axis_wheel_map*}] +
         [al_count $celines {*graph_axis_at*}]}] 0
# the FIRST match, not the last: the CTRL gesture is the child's first wheel, so
# this is deterministically its line whatever a broken build appends afterwards.
# Taking the last one made the replay legs below collateral damage of CE13's
# sabotage instead of an independent statement about the CTRL gesture.
set celine {}
foreach cel $celines {
  if {[string match {xschem graph_axis_zoom *} $cel]} { set celine $cel; break }
}
set cer0 {}; set cer1 {}
foreach cel [split $ceout "\n"] {
  if {[string match {child r0=*} $cel]} { set cer0 [string range $cel 9 end] }
  if {[string match {child r1=*} $cel]} { set cer1 [string range $cel 9 end] }
}
check_true "CE9 the child's gesture really zoomed AND propagated (teeth:\
 r0=$cer0 r1=$cer1)" \
  [pexpr {$cer0 ne {} && $cer0 ne {0 1.0} && $cer1 eq $cer0}]
set cec2 [file join $scratch ce_child2.tcl]
al_child $cec2 "$cefix
$celine
puts \"replay r0=\[xschem getprop rect 2 0 x1] \[xschem getprop rect 2 0 x2]\"
puts \"replay r1=\[xschem getprop rect 2 1 x1] \[xschem getprop rect 2 1 x2]\"
puts CE-REPLAY-DONE
exit 0"
set cerc2 [catch {exec [info nameofexecutable] --nogui --pipe -q --nolog \
                       --script $cec2 2>@1} ceout2]
set cep0 {}; set cep1 {}
foreach cel [split $ceout2 "\n"] {
  if {[string match {replay r0=*} $cel]} { set cep0 [string range $cel 10 end] }
  if {[string match {replay r1=*} $cel]} { set cep1 [string range $cel 10 end] }
}
if {$cerc2 || ![string match {*CE-REPLAY-DONE*} $ceout2]} {
  note "CE replay output: [string range $ceout2 end-400 end]"
  stall "CE replay child did not reach its sentinel"
}
check "CE9 the replay child ran to its end" \
  [expr {[string match {*CE-REPLAY-DONE*} $ceout2] ? 1 : 0}] 1
check "CE9 replaying the ONE logged line reproduces rect 0's window" $cep0 $cer0
check "CE9 ...and rect 1's, so the line carries the whole propagation" $cep1 $cer1

# --- CE13: ...and a CTRL+SHIFT wheel logs NOTHING ---------------------------
# The leg CE12 cannot be. Deleting `!(state & ShiftMask)` leaves every window in
# this file byte-identical in the X margin (the Shift arm downstream recomputes
# from the pre-zoom master_gx1/gx2 and overwrites -- an accident of ordering, not
# an assertion), but the suppressed arm still APPLIES on its way past, and
# graph_axis_zoom() self-logs. So the replay LOG is where the term is visible:
# the child above already made exactly ONE graph_axis_zoom line with its plain
# CTRL wheel, and the two CTRL+SHIFT wheels it then delivered must add NONE.
# Measured: 1 line shipped, 3 with the term deleted.
# That also makes this the REPLAY-FIDELITY leg -- a session recorded without the
# term replays a zoom the live gesture never left behind.
#
# ⚠ It rides in CE9's child on purpose. A zero-delta assertion needs proof the
# channel was open, and CE9's own line is that proof (an empty logdir would fail
# CE9 first); a SECOND --logdir GUI child would supply the same proof at the cost
# of another toplevel appearing and vanishing on the display, which under WSLg
# restacked the parent canvas and put the AX/CV groups' cached probe pixels on
# the wrong strip about 1 run in 8 (measured, both flavours).
set ce13pre {}; set ce13post {}
foreach cel [split $ceout "\n"] {
  if {[string match {child cs-pre=*} $cel]}  { set ce13pre  [string range $cel 13 end] }
  if {[string match {child cs-post=*} $cel]} { set ce13post [string range $cel 14 end] }
}
check_true "CE13 both CTRL+SHIFT wheels were DELIVERED: the shipped Shift arms\
 moved the window (pre=$ce13pre post=$ce13post)" \
  [pexpr {$ce13pre ne {} && $ce13post ne {} && $ce13pre ne $ce13post}]
check "CE13 ...and the log STILL holds exactly the one line the plain CTRL wheel\
 made: a CTRL+SHIFT wheel in EITHER margin left NOTHING replayable behind, so\
 the new arm never ran" \
  [al_count $celines {xschem graph_axis_zoom *}] 1
check "CE13 ...and that one line is still the X line, not a Y line the Y-margin\
 CTRL+SHIFT would have added" \
  [al_count $celines {xschem graph_axis_zoom * y *}] 0

} ceerr]} { check "CE* group ran to its end" "ERR:$ceerr" ok }
} else {
  puts "SKIPPED: CE* (no DISPLAY / no .drw canvas)"
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

# ========================================================================
# CV* — the ASE viewer's CTRL+wheel (issue 0191), on the SAME live viewer
# ========================================================================
# The viewer owns every wheel sequence (`bind $wp <Control-Button-4> ... break`)
# and never forwards to C, so this half of the feature is Tcl: wviewer::wheel's
# ctrl arm asks C which REGION the pointer is in and passes the answer to
# wviewer::wheel_zoom, which takes each strip's new window from
# `xschem get graph_axis_wheel_map` -- one formula, in C, for both surfaces.
# Every wheel is preceded by a <Motion> so graph_at_pointer is not stale (D-38),
# and carries -state 4 (ControlMask) so the shipped <Control-Button-N> bind fires.
if {[catch {

proc cv_wheel {w x y up} {
  ax_ev $w <Motion> -x $x -y $y
  ax_ev $w [expr {$up ? {<Button-4>} : {<Button-5>}}] -x $x -y $y -state 4
  update
}
proc cv_wins {n} {
  ax_ctx
  set o {}
  for {set i 0} {$i < $n} {incr i} {
    set row {}
    foreach t {x1 x2 y1 y2} { lappend row [xschem getprop rect 2 $i $t] }
    lappend o $row
  }
  return $o
}
# re-stage BOTH strips to a known window, through the MODEL (the viewer's own
# source of truth) so regenerate cannot autozoom it away
proc cv_stage {tok} {
  set gs [dict get [wviewer::layout_for $tok] graphs]
  set out {}
  foreach G $gs {
    foreach {k v} {x1 0 x2 1.0 y1 0 y2 2.5} { dict set G $k $v }
    lappend out $G
  }
  wviewer::set_graphs $tok $out
  wviewer::regenerate $tok
  update
  ax_ctx
}
# Same, but every strip gets its OWN x window: strip k spans 0 .. (k+1). CV7's
# fixture, and the only one in the file that can tell D-33's two readings apart
# (see CV7). `sharedx` defaults to 0 (wviewer::open seeds it, wviewer::layout_for
# returns it), so regenerate's "non-master graphs inherit graph-0's x range" arm
# does not fire and the per-strip windows survive -- CV7 asserts that rather than
# assuming it.
proc cv_stage_split {tok} {
  set gs [dict get [wviewer::layout_for $tok] graphs]
  set out {}
  set k 0
  foreach G $gs {
    foreach {kk vv} [list x1 0 x2 [expr {1.0 * ($k + 1)}] y1 0 y2 2.5] {
      dict set G $kk $vv
    }
    lappend out $G
    incr k
  }
  wviewer::set_graphs $tok $out
  wviewer::regenerate $tok
  update
  ax_ctx
}
# The plot box + both margin probes for ANY strip index, from the viewer's own
# band registry. ax_scan is strip-0-only; CV8 needs strip 1's, for the same
# reason CE10 exists on the C path. Returns {box xm ym} or {} (the caller FAILS,
# never skips).
proc cv_strip {k} {
  ax_ctx
  set bands [pcall {wviewer::strip_bands_px $::vdrw}]
  if {[llength $bands] <= $k} { return {} }
  set b {}
  foreach v [lindex $bands $k] { lappend b [expr {int($v)}] }
  if {[llength $b] != 4} { return {} }
  set box [az_box $k $b]
  if {[llength $box] != 4} { return {} }
  set xm [az_xmargin $box $b]
  set ym [az_ymargin $box $b]
  if {[llength $xm] != 2 || [llength $ym] != 2} { return {} }
  return [list $box $xm $ym]
}
# A Y-margin pixel of strip `k` that C ITSELF calls the Y region, found by asking
# rather than by predicting: re-scan the strip and walk left from the plot box
# until `graph_axis_at` agrees.
#
# ⚠ WHY THE SCAN IS INSIDE THE LOOP. `az_ymargin`'s midpoint is geometry, and
# `graph_axis_at` has four refusals the geometry cannot see (the container rect,
# the reorder grip column, and `graph_legend_at` -- for a vlegend/digital strip
# the legend IS the left margin). It also re-lays the viewer out on any
# `<Configure>` an `update` delivers, which under WSLg moves the box out from
# under an answer computed a moment earlier. Measured standalone: a single
# predicted midpoint answered NONE on ~1 run in 3, the gesture then degraded to
# the body zoom, and only CV8's "every strip's x1/x2 unchanged" leg saw it --
# the Y legs pass either way, because the body zoom scales Y by the same K.
# Returns {x y} or {} (the caller FAILS, never skips).
proc cv_yprobe {k {tries 12}} {
  for {set n 0} {$n < $tries} {incr n} {
    set s [cv_strip $k]
    if {[llength $s] == 3} {
      lassign [lindex $s 0] bx1 by1 bx2 by2
      lassign [lindex $s 2] mx my
      set lo [expr {2 * $mx - $bx1}]   ;# the band's left edge, back out of the midpoint
      ax_ctx
      for {set x [expr {$bx1 - 2}]} {$x > $lo} {incr x -1} {
        if {[pcall {xschem get graph_axis_at $k $x $my}] eq {y}} { return [list $x $my] }
      }
    }
    update
    after 30
  }
  return {}
}
ax_reset_arms $tok
cv_stage $tok
ax_scan $tok
lassign $axbox  cvbx1 cvby1 cvbx2 cvby2
lassign $axxm   cvxmx cvxmy
lassign $axym   cvymx cvymy
set cvcx [expr {($cvbx1 + $cvbx2) / 2}]
set cvcy [expr {($cvby1 + $cvby2) / 2}]
set cvbw [expr {$cvbx2 - $cvbx1}]
set cvpx [expr {$cvbx1 + int($cvbw * 0.25)}]     ;# OFF-CENTRE, as everywhere
check_true "CV0 the viewer strip was (re)scanned and both strips are staged to\
 0..1 / 0..2.5 (box=$axbox xm=$axxm ym=$axym px=$cvpx)" \
  [pexpr {$cvbx1 >= 0 && $cvxmx >= 0 && $cvymx >= 0 && $cvbw > 60 &&
          abs($cvpx - $cvcx) > $cvbw * 0.15 &&
          [xschem getprop rect 2 0 x1] == 0 && [xschem getprop rect 2 1 x2] == 1.0}]
check "CV0 the scanned bottom-margin pixel really is the X region (teeth: the\
 whole gesture hangs off C's answer here)" \
  [pcall {xschem get graph_axis_at 0 $cvxmx $cvxmy}] x

# --- CV1: X margin -> X on every strip, Y untouched everywhere --------------
set cv1b [pcall {cv_wins 2}]
set cv1m [pcall {ax_ctx; xschem get graph_axis_wheel_map 0 x $cvpx in}]
cv_wheel $vdrw $cvpx $cvxmy 1
set cv1a [pcall {cv_wins 2}]
check_true "CV1 CTRL+wheel in the X margin zoomed X on strip 0 by exactly the C\
 map (map=$cv1m before=$cv1b after=$cv1a)" \
  [pexpr {[az_close [lindex $cv1a 0 0] [lindex $cv1m 0] 1e-6 1.0] &&
          [az_close [lindex $cv1a 0 1] [lindex $cv1m 1] 1e-6 1.0]}]
check_true "CV1 ...and on EVERY strip (X is the shared axis of the stack)" \
  [pexpr {[az_close [lindex $cv1a 1 0] [lindex $cv1m 0] 1e-6 1.0] &&
          [az_close [lindex $cv1a 1 1] [lindex $cv1m 1] 1e-6 1.0]}]
check "CV1 ...and left EVERY strip's y1/y2 unchanged" \
  [pcall {set o {}; foreach row $cv1a { lappend o [lrange $row 2 3] }; set o}] \
  [pcall {set o {}; foreach row $cv1b { lappend o [lrange $row 2 3] }; set o}]

# --- CV2: Y margin -> Y on the pointed strip only, X untouched --------------
cv_stage $tok
ax_scan $tok
set cv2b [pcall {cv_wins 2}]
cv_wheel $vdrw $cvymx $cvcy 1
set cv2a [pcall {cv_wins 2}]
check_true "CV2 CTRL+wheel in the Y margin narrowed strip 0's Y by K=$::cwK\
 (before=$cv2b after=$cv2a)" \
  [pexpr {[az_close [expr {[lindex $cv2a 0 3] - [lindex $cv2a 0 2]}] \
                    [expr {2.5 * $::cwK}] 1e-6 2.5]}]
check "CV2 ...on the POINTED strip only (strip 1's y1/y2 unchanged)" \
  [lrange [lindex $cv2a 1] 2 3] [lrange [lindex $cv2b 1] 2 3]
check "CV2 ...and left EVERY strip's x1/x2 unchanged" \
  [pcall {set o {}; foreach row $cv2a { lappend o [lrange $row 0 1] }; set o}] \
  [pcall {set o {}; foreach row $cv2b { lappend o [lrange $row 0 1] }; set o}]

# --- CV3: the plot BODY is UNCHANGED: both axes, as it has been since 0144 --
cv_stage $tok
ax_scan $tok
set cv3b [pcall {cv_wins 2}]
cv_wheel $vdrw $cvcx $cvcy 1
set cv3a [pcall {cv_wins 2}]
check_true "CV3 CTRL+wheel in the plot BODY still zooms X on EVERY strip AND Y\
 on the pointed one (before=$cv3b after=$cv3a)" \
  [pexpr {[lindex $cv3a 0 0] ne [lindex $cv3b 0 0] &&
          [lindex $cv3a 1 0] ne [lindex $cv3b 1 0] &&
          [lindex $cv3a 0 2] ne [lindex $cv3b 0 2]}]
check "CV3 ...and Y still does NOT follow onto the other strip" \
  [lrange [lindex $cv3a 1] 2 3] [lrange [lindex $cv3b 1] 2 3]

# --- CV4: it went into the MODEL, not just the rect (D-36) ------------------
cv_stage $tok
ax_scan $tok
cv_wheel $vdrw $cvpx $cvxmy 1
set cv4a [pcall {cv_wins 2}]
pcall {wviewer::regenerate $tok}
update
set cv4r [pcall {cv_wins 2}]
check_true "CV4 the zoom really wrote (teeth)" \
  [pexpr {[lindex $cv4a 0 0] ne "0"}]
check "CV4 a regenerate (what a window resize does) does NOT discard it -- the\
 viewer wrote its Tcl MODEL, like its body zoom does" $cv4r $cv4a

# --- CV5/CV6: no undo point, and the fixed point ----------------------------
cv_stage $tok
ax_scan $tok
set cv5d [pcall {wviewer::history_depth $tok}]
set cv6qb [pcall {ax_ctx; az_coord 0 $cvpx $cvcy 0}]
cv_wheel $vdrw $cvpx $cvxmy 1
check "CV5 wviewer::history_depth did not move (D-35: a zoom is view state and\
 is deliberately outside a viewer undo snapshot)" \
  [pcall {wviewer::history_depth $tok}] $cv5d
set cv6qa [pcall {ax_ctx; az_coord 0 $cvpx $cvcy 0}]
check_true "CV6 THE FIXED POINT in the viewer: the data x under the pointer\
 pixel is unchanged (before=$cv6qb after=$cv6qa)" \
  [pexpr {[az_close $cv6qa $cv6qb 1e-6 1.0]}]
check "CV6 ...and the viewer buffer is still modified 0 / readonly 1" \
  [pcall {ax_ctx; list [xschem get modified] [xschem get readonly]}] {0 1}

# --- CV7: two strips with DIFFERENT x windows (D-33, the decisive half) -----
# D-33 says the viewer's X arm calls the C map PER STRIP, so "each strip is
# anchored in its OWN window at the same pointer pixel -- the same answer when
# the windows agree and the RIGHT one when they do not". Every other leg in this
# file stages both strips to the identical 0..1.0, and in that fixture a
# per-strip anchor and "strip 0's answer broadcast to every strip" produce the
# SAME numbers -- so CV1 cannot tell them apart and a `$t`->`$gi` slip in
# wviewer::wheel_zoom's X arm would be invisible. This is the fixture that can:
# strip 0 spans 0..1.0 and strip 1 spans 0..2.0, so the two anchored answers are
# numerically different and the leg names which one each strip got.
cv_stage_split $tok
ax_scan $tok
set cv7b [pcall {cv_wins 2}]
check_true "CV7 the split fixture really took: the two strips carry DIFFERENT x\
 windows (before=$cv7b) -- sharedx is 0, so regenerate left them alone" \
  [pexpr {[lindex $cv7b 0 0] == 0 && [lindex $cv7b 0 1] == 1.0 &&
          [lindex $cv7b 1 0] == 0 && [lindex $cv7b 1 1] == 2.0}]
set cv7m0 [pcall {ax_ctx; xschem get graph_axis_wheel_map 0 x $cvpx in}]
set cv7m1 [pcall {ax_ctx; xschem get graph_axis_wheel_map 1 x $cvpx in}]
check_true "CV7 ...and the per-strip C map therefore gives two DIFFERENT answers\
 for the SAME pointer pixel (m0=$cv7m0 m1=$cv7m1) -- teeth: with equal windows\
 both readings of D-33 coincide and this leg proves nothing" \
  [pexpr {[llength $cv7m0] == 2 && [llength $cv7m1] == 2 &&
          !([az_close [lindex $cv7m0 0] [lindex $cv7m1 0] 1e-6 2.0] &&
            [az_close [lindex $cv7m0 1] [lindex $cv7m1 1] 1e-6 2.0])}]
set cv7s1 [cv_strip 1]
check_true "CV7 strip 1 was scanned for its own fixed-point probe (=$cv7s1)" \
  [pexpr {[llength $cv7s1] == 3}]
set cv7q1 {}
if {[llength $cv7s1] == 3} {
  lassign [lindex $cv7s1 0] cv7b1x1 cv7b1y1 cv7b1x2 cv7b1y2
  set cv7c1y [expr {($cv7b1y1 + $cv7b1y2) / 2}]
  set cv7q1 [pcall {ax_ctx; az_coord 1 $cvpx $cv7c1y 0}]
}
cv_wheel $vdrw $cvpx $cvxmy 1
set cv7a [pcall {cv_wins 2}]
check_true "CV7 strip 0 took ITS OWN anchored window (map=$cv7m0 after=$cv7a)" \
  [pexpr {[az_close [lindex $cv7a 0 0] [lindex $cv7m0 0] 1e-6 1.0] &&
          [az_close [lindex $cv7a 0 1] [lindex $cv7m0 1] 1e-6 1.0]}]
check_true "CV7 strip 1 took ITS OWN anchored window and NOT strip 0's broadcast\
 (map=$cv7m1 after=$cv7a)" \
  [pexpr {[az_close [lindex $cv7a 1 0] [lindex $cv7m1 0] 1e-6 2.0] &&
          [az_close [lindex $cv7a 1 1] [lindex $cv7m1 1] 1e-6 2.0]}]
set cv7q1a {}
if {[llength $cv7s1] == 3} { set cv7q1a [pcall {ax_ctx; az_coord 1 $cvpx $cv7c1y 0}] }
check_true "CV7 THE FIXED POINT holds on strip 1 too, in ITS window\
 (before=$cv7q1 after=$cv7q1a)" \
  [pexpr {[az_close $cv7q1a $cv7q1 1e-6 2.0]}]

# --- CV8: the Y margin of a strip whose index is NOT 0 ----------------------
# wviewer::wheel_zoom's y branch is gated on `$t == $gi`, and `$gi` comes from
# wviewer::graph_at_pointer. CV2 is the only other Y-margin viewer leg and it
# points at strip 0, where a `gi`-hardcode and a graph_at_pointer that always
# answers 0 are both invisible. This is CE10's viewer counterpart: Y never
# propagates, so "strip 1 moved and strip 0 did not" can ONLY mean the arm
# followed the POINTED strip.
cv_stage $tok
ax_scan $tok
# Establish the pointer on strip 1's Y region and CONFIRM it, re-probing if a
# stray relayout moved the box (see cv_yprobe). The two facts are recorded and
# then asserted as named legs, so the confirmation is never re-queried after the
# fact -- a second query is a second chance to flake.
set cv8yx -1; set cv8yy -1
set cv8gap {}; set cv8ax {}
for {set cv8n 0} {$cv8n < 10} {incr cv8n} {
  set cv8p [cv_yprobe 1]
  if {[llength $cv8p] != 2} { update; continue }
  lassign $cv8p cv8yx cv8yy
  ax_ev $vdrw <Motion> -x $cv8yx -y $cv8yy
  set cv8gap [pcall {wviewer::graph_at_pointer $::vdrw}]
  set cv8ax  [pcall {ax_ctx; xschem get graph_axis_at 1 $cv8yx $cv8yy}]
  if {$cv8gap eq {1} && $cv8ax eq {y}} break
}
if {$cv8gap ne {1} || $cv8ax ne {y}} { stall "CV8 never got the pointer onto strip 1's Y margin" }
check "CV8 graph_at_pointer resolves the POINTED strip as 1 (teeth: the whole\
 `\$t == \$gi` gate hangs off this answer, and every other viewer leg in the file\
 points at strip 0) probe=$cv8yx,$cv8yy" $cv8gap 1
check "CV8 ...and C calls that pixel strip 1's Y region" $cv8ax y
set cv8b [pcall {cv_wins 2}]
ax_ev $vdrw <Button-4> -x $cv8yx -y $cv8yy -state 4
update
set cv8a [pcall {cv_wins 2}]
check_true "CV8 CTRL+wheel in STRIP 1's Y margin narrowed STRIP 1's Y by K=$::cwK\
 (before=$cv8b after=$cv8a)" \
  [pexpr {[az_close [expr {[lindex $cv8a 1 3] - [lindex $cv8a 1 2]}] \
                    [expr {2.5 * $::cwK}] 1e-6 2.5]}]
check "CV8 ...and left STRIP 0's y1/y2 unchanged, so the viewer arm followed the\
 POINTED strip and not index 0" \
  [lrange [lindex $cv8a 0] 2 3] [lrange [lindex $cv8b 0] 2 3]
check "CV8 ...and left EVERY strip's x1/x2 unchanged" \
  [pcall {set o {}; foreach row $cv8a { lappend o [lrange $row 0 1] }; set o}] \
  [pcall {set o {}; foreach row $cv8b { lappend o [lrange $row 0 1] }; set o}]

# --- CS3: the two anchored implementations agree NUMERICALLY ----------------
# wviewer::zoom_about (the viewer's BODY zoom) and graph_axis_wheel_map (C, the
# margin zoom) are two anchored scales that must give the same window for the
# same strip, pixel and factor -- otherwise one gesture would step differently
# depending on where in the strip the pointer was. Run HERE because
# wviewer::zoom_about only exists once wave_viewer.tcl is sourced.
cv_stage $tok
ax_scan $tok
check_true "CS3 wviewer::zoom_about is DEFINED (never a silent skip)" \
  [pexpr {[llength [info procs ::wviewer::zoom_about]] == 1}]
set cs3q [pcall {ax_ctx; az_coord 0 $cvpx $cvcy 0}]
set cs3c [pcall {ax_ctx; xschem get graph_axis_wheel_map 0 x $cvpx in}]
set cs3t [pcall {wviewer::zoom_about 0 1.0 $cs3q $::cwK}]
check_true "CS3 zoom_about(0,1,q=$cs3q,K) == graph_axis_wheel_map\
 (tcl=$cs3t c=$cs3c)" \
  [pexpr {[az_close [lindex $cs3t 0] [lindex $cs3c 0] 1e-9 1.0] &&
          [az_close [lindex $cs3t 1] [lindex $cs3c 1] 1e-9 1.0]}]

} cverr]} { check "CV* group ran to its end" "ERR:$cverr" ok }

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
