# tests/headless/test_wave_snap.tcl — ASE Waveform Viewer diamond SNAP CURSOR
# (viewer plan item 9; contract in doc/claude/specs/waveform_viewer.md)
#
# The feature: while the pointer hovers a waveform graph, a diamond sticks to
# the nearest SAMPLE of the nearest trace, and that sample's RAW x/y are
# published through `xschem get graph_snap` for item 10's status bar.
#
# ⚠ The GLYPH is eyeball-only — it is painted straight to the window with
# draw_pixmap = 0, so it is not in save_pixmap and there is no way to read it
# back. What IS assertable, and what this suite covers, is the whole contract
# around it: the per-window arming, the published pick, the raw-not-log values,
# and the yields.
#
#   SP*  arming: per CONTEXT, not global (the no_grid precedent) — the blast
#        radius that keeps ~127 embedded schematic graphs out of a per-sample
#        walk they never asked for
#   SQ*  the published pick: format, emptiness when nothing is snapped, and
#        that it is a REPORT (never runs the query itself, so item 10 can poll
#        it for free)
#   SS*  source tripwires for the things behaviour cannot reach: the gesture
#        yield, the query brake, and window-only painting
#   SG*  DISPLAY: the viewer arms its own window, a real hover over a trace
#        publishes a sample, leaving the graphs clears it, disarming clears it
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_snap.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

# Count regexp matches in CODE lines only. A C block comment that explains what
# the code deliberately does NOT do contains the very string being counted --
# counting the prose is a mistake made twice in this tree already (see the
# legendbold emitter leg in test_wave_legend.tcl).
proc count_code {src pat} {
  set n 0
  foreach line [split $src "\n"] {
    set t [string trimleft $line]
    # ⚠ NOT [string match "*" $t] -- `*` is a glob that matches EVERY string, so
    # that form silently skips every line and the count is always 0. Literal
    # first-character tests only.
    if {[string index $t 0] eq "*"} { continue }
    if {[string range $t 0 1] eq "/*" || [string range $t 0 1] eq "//"} { continue }
    incr n [regexp -all $pat $line]
  }
  return $n
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvsnap]

set statefile [file join $repo sky130A xschem_libs sky130_tests test_nfet_final \
                    ngspice_state1 test_nfet_final.state]
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

if {[catch {

# ============================================================================
# SP* — arming is PER CONTEXT
# ============================================================================
check "SP1 a fresh context is NOT armed" [pcall {xschem get graph_snap_cursor}] 0
check "SP2 arming round-trips" \
  [pcall {xschem set graph_snap_cursor 1; xschem get graph_snap_cursor}] 1
check "SP3 any non-zero means armed" \
  [pcall {xschem set graph_snap_cursor 7; xschem get graph_snap_cursor}] 1
check "SP4 disarming round-trips" \
  [pcall {xschem set graph_snap_cursor 0; xschem get graph_snap_cursor}] 0
# ⚠ THE LETTER-DISPATCH LANDMINE, and the reason these four legs exist at all:
# `xschem get` groups its sub-keys by first letter and `xschem set` splits on
# `argv[2][0] < 'n'`. A 'g' key placed in the wrong half is SILENTLY
# unreachable -- no error, the setter just does nothing. Both halves of this
# verb were mis-filed on the first try and both failed exactly that way.
check "SP5 the setter really reaches the C side (not silently unreachable)" \
  [pcall {xschem set graph_snap_cursor 1
          set a [xschem get graph_snap_cursor]
          xschem set graph_snap_cursor 0
          list $a [xschem get graph_snap_cursor]}] {1 0}

# ============================================================================
# SQ* — the published pick
# ============================================================================
check "SQ1 nothing snapped -> empty string" [pcall {xschem get graph_snap}] {}
check "SQ2 ...still empty when armed but nothing hovered" \
  [pcall {xschem set graph_snap_cursor 1; xschem get graph_snap}] {}
xschem set graph_snap_cursor 0
check "SQ3 the diamond size is configurable" [set ::graph_snap_cursor_size] 5
# There is NO proximity threshold any more -- the gate is the plot box. A
# leftover tol var would read as "how near you must be", which is exactly the
# behaviour that was reported wrong.
check "SQ3 no proximity-threshold var survives" \
  [info exists ::graph_snap_cursor_tol] 0

# ============================================================================
# SS* — source tripwires for what behaviour cannot reach
# ============================================================================
set fp [open [file join $repo src draw.c] r]; set csrc [read $fp]; close $fp

# THE YIELD. A marker drag, a strip/trace drag, a cursor drag, a graph pan and
# a box zoom all own the pointer while they run. ui_state != 0 is deliberately
# the broadest test: in a read-only viewer canvas it is 0 at rest.
check_true "SS1 the pump yields to any armed gesture" \
  [regexp {if\(xctx->ui_state \|\| xctx->graph_marker_dragmode\) \{ graph_snap_clear\(\); return; \}} $csrc]

# THE BRAKE. graph_point_at walks every sample of every trace; item 9 runs it on
# BARE HOVER, so the query -- not just the repaint -- must be skipped when the
# mouse pixel has not moved.
check_true "SS2 the QUERY is skipped when the mouse pixel did not change" \
  [regexp {mx == xctx->graph_snap_prev_mx && my == xctx->graph_snap_prev_my\) return;} $csrc]

# WINDOW ONLY. Nothing is ever written to save_pixmap, so the glyph cannot reach
# a print or an SVG -- the guarantee the flags-bit-16 "UI chrome" rule provides
# elsewhere, obtained here structurally.
# Exactly ONE draw_pixmap=0 bracket now: the erase copies back from save_pixmap
# and needs no bracket at all, only the DRAW does. If the glyph ever starts
# being written into save_pixmap the copy-back erase silently stops working --
# it would restore the diamond it was meant to remove.
check "SS3 the glyph is painted window-only (never into save_pixmap)" \
  [count_code [string range $csrc [string first "void graph_snap_clear" $csrc] \
        [expr {[string first "void graph_snap_clear" $csrc] + 6000}]] \
     {xctx->draw_pixmap = 0;}] 1

# RAW values, never the log-mapped ones (landmine 35: mylog10 clamps <=0 to -35,
# so a zero sample would read back as 1e-35).
check_true "SS4 the published x/y are the RAW hit values" \
  [regexp {xctx->graph_snap_x = hit\.x;\s*/\* RAW -- landmine 35 \*/} $csrc]

# THE BLAST RADIUS, as a tripwire rather than as behaviour. SG1 below reads the
# getter, and the getter reports xctx->graph_snap whatever the PUMP actually
# consults -- so SG1 stays green even if the pump is re-armed from a global Tcl
# var, which is precisely the mistake that would put a per-sample walk on every
# embedded schematic graph in the tree. Measured: that sabotage left SG1 green
# and merely shrank the suite. This leg is the one that bites.
check_true "SS6 the PUMP arms from the per-context field, not a global var" \
  [regexp {if\(!xctx->graph_snap\) \{ graph_snap_clear\(\); return; \}} $csrc]
check "SS6 ...and no tclgetboolvar arming survives in the pump" \
  [regexp -all {tclgetboolvar\("graph_snap} $csrc] 0

# ⚠ THE ERASE. Reported from a real session: the diamond left a TRAIL across the
# strip and only a full redraw (`f` = fit) cleared it. The cause was erasing with
# the gctiled stroke that draw_snap_cursor()/erase_snap_cursor() use -- which is
# the SHIPPED schematic path, but does not remove the glyph in a viewer window.
# The erase now copies the patch back from save_pixmap, which is the fallback
# erase_snap_cursor() itself uses where the tiled fill is known broken.
# The trail is pixels and cannot be asserted; this is the tripwire that stops it
# regressing to the stroke.
# THE GATE IS THE PLOT BOX. Reported: "the mouse pointer needs to be too close
# to the trace for the diamond cursor to show". The first cut used
# graph_point_at's `tol` as the gate, so the pointer had to pass within ~20 px
# of a trace. The gate is now graph_plotbox_at() and the threshold is handed a
# value nothing can exceed.
check_true "SS8 the pump gates on the PLOT BOX, not on proximity" \
  [regexp {if\(!graph_plotbox_at\(i, \(double\)mx, \(double\)my\)\) continue;} $csrc]
check_true "SS8 ...and hands graph_point_at an unreachable threshold" \
  [regexp {graph_point_at\(i, \(double\)mx, \(double\)my, 1e30,} $csrc]
check "SS8 no proximity tol is read from Tcl any more" \
  [count_code $csrc {graph_snap_cursor_tol}] 0
# landmine 3: gr->cy is negative, so the y screen bounds come back reversed
check_true "SS9 the plot box normalises BOTH axis pairs (gr->cy is negative)" \
  [regexp {if\(ay1 > ay2\) \{ t = ay1; ay1 = ay2; ay2 = t; \}} $csrc]

check_true "SS7 the erase copies back from save_pixmap" \
  [regexp {MyXCopyArea\(display, xctx->save_pixmap, xctx->window, xctx->gc\[0\],} $csrc]
check "SS7 ...and no gctiled stroke erase survives in the snap CODE" \
  [count_code $csrc {graph_snap_shape\(xctx->gctiled}] 0

# the transient state must be reset where every other transient xctx field is
set fp [open [file join $repo src actions.c] r]; set asrc [read $fp]; close $fp
check_true "SS5 clear_drawing() disarms the snap" \
  [regexp {xctx->graph_snap_on = 0;} $asrc]

# ============================================================================
# SN* — issue 0177: THE VIEWER CANVAS HAS NO SCHEMATIC SNAP GRID
# ============================================================================
# The property, not another override. `xctx->no_snap` is a per-context flag that
# callback() consults where mousex_snap/mousey_snap are BORN, so every present
# and future reader on that canvas sees an unsnapped pointer -- instead of each
# handler having to remember to un-snap for itself (which is what issue 0143 did,
# and it only ever covered code reached through waves_callback).
#
# WHAT ESCAPED, and why these legs exist: the reporter saw "the snap grid at play
# when clicking on the legend text". 0175's own suite had a green leg next to an
# unasserted neighbour -- test_wave_trace_menu TL4 proves the legend QUERY is
# snap-immune, but nothing drove a real Tk gesture under a coarse grid and
# nothing at all covered HOVER.

check "SN1 a fresh context has NO no_snap" [pcall {xschem get no_snap}] 0
check "SN2 it round-trips" [pcall {xschem set no_snap 1; xschem get no_snap}] 1
check "SN3 any non-zero means armed" \
  [pcall {xschem set no_snap 7; xschem get no_snap}] 1
check "SN4 disarming round-trips" [pcall {xschem set no_snap 0; xschem get no_snap}] 0
# ⚠ THE LETTER-DISPATCH LANDMINE (see SP5): `xschem set` splits on
# argv[2][0] < 'n' and `xschem get` groups by first letter. An 'n' key in the
# wrong half is SILENTLY unreachable -- the setter just does nothing.
check "SN5 the setter really reaches the C side (not silently unreachable)" \
  [pcall {xschem set no_snap 1
          set a [xschem get no_snap]
          xschem set no_snap 0
          list $a [xschem get no_snap]}] {1 0}

set fp [open [file join $repo src callback.c] r]; set cbsrc [read $fp]; close $fp

# THE SOURCE OF TRUTH. The whole point of 0177 is that the decision is taken
# ONCE, at the place the two fields are computed, rather than being undone
# afterwards by whichever handler happens to remember. If this branch is ever
# replaced by another downstream override the property stops being a property.
check_true "SN6 callback() branches on no_snap where mousex_snap is BORN" \
  [regexp {if\(xctx->no_snap\) \{\s*\n\s*xctx->mousex_snap=xctx->mousex;\s*\n\s*xctx->mousey_snap=xctx->mousey;} $cbsrc]
check_true "SN6 ...and the grid arithmetic is the OTHER arm, not the default" \
  [regexp {\} else \{\s*\n\s*xctx->mousex_snap=my_round\(xctx->mousex / c_snap\) \* c_snap;} $cbsrc]

# ⚠ 0143's LOCAL OVERRIDE MUST SURVIVE. It is NOT superseded: an ordinary
# SCHEMATIC window can embed graphs, waves_callback runs on those too, and that
# context is not no_snap -- its grid is real and wanted everywhere except inside
# a graph. tests/headless/test_graph_box_zoom_xy.tcl drives exactly that case on
# .drw and goes red the moment this line is deleted "because no_snap replaces
# it". It does not.
check_true "SN7 waves_callback's own 0143 un-snap is still there (embedded graphs)" \
  [regexp {xctx->mousex_snap = xctx->mousex;\s*\n\s*xctx->mousey_snap = xctx->mousey;} $cbsrc]

# NEITHER SCHEMATIC POINTER GLYPH IS A VIEWER CONCEPT. draw_crosshair() paints AT
# mousex_snap, so on a grid it IS the snap grid made visible; draw_snap_cursor()
# snaps to the nearest net or symbol pin, of which a waveform canvas has none.
#
# ⚠ THE TEST MUST BE INSIDE THE DRAWERS, NOT IN THEIR CALLERS' LOCALS -- and the
# first cut of this fix put it in the locals, which was wrong twice over:
#   - draw() itself ends with `if(tclgetboolvar("draw_crosshair"))
#     draw_crosshair(7, 0);` (draw.c) and move.c has three more such sites, none
#     of which consults callback()'s draw_xhair. Gating only the local suppressed
#     every ERASE path and left those PAINT paths live: a crosshair stroked on
#     the waveform at each full redraw that then never moved and never cleared;
#   - callback()'s locals are INITIALISERS, so they run before
#     handle_window_switching() may reassign xctx -- on the EnterNotify that
#     switches into or out of a viewer they describe the PREVIOUS context.
# With the test inside the drawer, an ungated CALL SITE is harmless by
# construction -- which is the property being bought, since there are five of
# them outside this file and nothing stops a sixth.
check_true "SN8 draw_crosshair itself refuses on a no_snap canvas" \
  [regexp {if\(xctx->no_snap\) return;\s*\n\s*mx = xctx->mousex_snap;} $cbsrc]
check_true "SN8 draw_snap_cursor itself refuses on a no_snap canvas" \
  [regexp {if \(xctx->no_snap\) return;\s*\n\s*snapcursor_size = tclgetintvar} $cbsrc]
# the call sites this structurally covers, and could not have covered from a
# callback.c local: they are in OTHER FILES
set fp [open [file join $repo src draw.c] r]; set dsrc [read $fp]; close $fp
set fp [open [file join $repo src move.c] r]; set msrc [read $fp]; close $fp
check_true "SN8 draw() has its own ungated crosshair call (hence the drawer gate)" \
  [regexp {tclgetboolvar\("draw_crosshair"\)\) draw_crosshair\(7, 0\)} $dsrc]
check_true "SN8 ...and move.c has more of them" \
  [expr {[regexp -all {draw_crosshair\(3, 0\)} $msrc] >= 3}]
# the CURSOR SHAPE is the one thing the callers still decide, and `-cursor none`
# would hide the pointer with no crosshair standing in for it
check_true "SN8 waves_selected reads the property for the cursor shape" \
  [regexp {int draw_xhair = tclgetboolvar\("draw_crosshair"\) && !xctx->no_snap;} $cbsrc]
check_true "SN8 ...and so does handle_enter_notify, at call time" \
  [regexp {if\(draw_xhair && !xctx->no_snap\) \{} $cbsrc]
# ⚠ AND THE LOCALS MUST STAY UNGATED, or the erase/paint asymmetry comes back
check "SN8 callback()'s locals do NOT carry the test (wrong context, wrong reach)" \
  [count_code $cbsrc {tclgetboolvar\("snap_cursor"\) && !xctx->no_snap}] 0

# ⚠ THE UNITS BUG THAT PUT THE LEGEND OUT OF REACH. waves_selected() insets the
# strip rect by a margin whose comment always said "screen pixels" -- but the
# value was subtracted from r->x1/r->y1, which are XSCHEM units, with no
# conversion. 1 screen pixel is xctx->zoom xschem units (X_TO_XSCHEM), so the
# inset was 1/zoom too wide: MEASURED 21.9 canvas px instead of 6.7 on a
# 1000x776 viewer at zoom 0.2738. legend_slot_hit() starts its horizontal slots
# at gr->ry1 -- the rect top itself -- so that band swallowed the top of every
# legend entry: the query answered correctly and the press went to the schematic
# canvas instead of the graph.
check_true "SN9 the graph-routing inset is converted to xschem units" \
  [regexp {border = 5\.0 \* tk_scaling \* xctx->zoom;} $cbsrc]
check "SN9 ...and the un-converted integer form is gone" \
  [count_code $cbsrc {border = \(int\)\(5\.0 \* tk_scaling\);}] 0

# and the viewer window actually asks for the property
set fp [open [file join $repo src wave_viewer.tcl] r]; set wvsrc [read $fp]; close $fp
check_true "SN10 wviewer::open arms no_snap on its own window" \
  [regexp {xschem set no_snap 1} $wvsrc]

# ============================================================================
# ST* — item 10: the viewer STATUS BAR (pure half)
# ============================================================================
# The formatting is split from the widget precisely so this half needs no
# DISPLAY at all.
check "ST1 mode only, nothing snapped" [pcall {wviewer::status_text single {} {}}] \
  {Plot: single}
check "ST2 multi mode" [pcall {wviewer::status_text multi {} {}}] {Plot: multi}
check "ST3 a snapped sample is appended, engineering-formatted" \
  [pcall {wviewer::status_text single 1.5e-6 0.9}] {Plot: single    x: 1.5u    y: 900m}
check "ST4 negatives and milli" [pcall {wviewer::status_text multi 1e-3 -2.5}] \
  {Plot: multi    x: 1m    y: -2.5}
check "ST5 zero is a value, not 'nothing snapped'" \
  [pcall {wviewer::status_text single 0 0}] {Plot: single    x: 0    y: 0}
check "ST6 an empty mode falls back to single" [pcall {wviewer::status_text {} {} {}}] \
  {Plot: single}
# half a coordinate is not a coordinate
check "ST7 x without y shows no position" [pcall {wviewer::status_text single 1 {}}] \
  {Plot: single}
check "ST7 y without x shows no position" [pcall {wviewer::status_text single {} 1}] \
  {Plot: single}
# ⚠ THE LABEL. The shipped editor bar already has a field literally labelled
# MODE:, and that one is the NETLISTING mode. Two contradictory MODEs in one
# window is worse than no status bar.
check "ST8 the label is 'Plot:', never 'MODE:'" \
  [expr {[string first "MODE:" [wviewer::status_text single 1 2]] < 0}] 1
check_true "ST8 ...and it does say Plot:" \
  [string match "Plot: *" [wviewer::status_text single 1 2]]
# never throws: it rides the motion pump
foreach {tag xx yy} {ST9 abc 1 ST10 1 abc ST11 Inf 1 ST12 NaN NaN} {
  check_true "$tag non-numeric '$xx'/'$yy' does not throw" \
    [expr {![string match ERR:* [pcall {wviewer::status_text single $xx $yy}]]}]
}

# ============================================================================
# SG* — DISPLAY
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "SG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: SG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  # THE BLAST-RADIUS LEG: the viewer arms its OWN window and nothing else. If
  # this were a global Tcl var instead of a per-context flag, the main window
  # would report 1 too and every embedded schematic graph would start paying
  # for a per-sample walk on every mouse move.
  xschem new_schematic switch $vdrw
  check "SG1 the viewer armed its own window" [pcall {xschem get graph_snap_cursor}] 1
  xschem new_schematic switch .drw
  check "SG1 the MAIN window is untouched (per-ctx, not global)" \
    [pcall {xschem get graph_snap_cursor}] 0
  xschem new_schematic switch $vdrw

  # a real trace to hover
  pcall {xschem raw new wvsnap.raw dc vsweep 0 1.0 0.05}
  pcall {xschem raw add vv "vsweep 2 *"}
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  pcall {wviewer::add_trace $tok 0 vv}
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "SG2 the fixture strip holds a trace" \
    [llength [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 0] traces]] 1

  # Sweep motion events across the strip. The gate is the PLOT BOX, so ANY
  # pixel inside it must snap -- the sweep is only here to find the box, whose
  # pixel extent depends on margins and window size.
  set W [winfo width $vdrw]; set H [winfo height $vdrw]
  set snapped {}
  set snapped_at {}
  focus -force $vdrw; update
  for {set yy [expr {int($H*0.15)}]} {$yy < int($H*0.9) && $snapped eq {}} {incr yy 4} {
    for {set xx [expr {int($W*0.2)}]} {$xx < int($W*0.8)} {incr xx 12} {
      event generate $vdrw <Motion> -x $xx -y $yy
      update
      set g [pcall {xschem get graph_snap}]
      if {$g ne {} && ![string match ERR:* $g]} {
        set snapped $g; set snapped_at [list $xx $yy]; break
      }
    }
  }
  if {$snapped eq {}} {
    puts "SKIPPED: SG3+ (no motion pixel resolved to a trace -- WSLg geometry)"
  } else {
    check "SG3 a hover over the trace publishes a pick" \
      [expr {[llength $snapped] == 4}] 1
    lassign $snapped sgi swave sx sy
    check "SG3 the pick names graph 0" $sgi 0
    check "SG3 ...and node 0, the only trace" $swave 0
    check_true "SG3 x is a real number inside the swept range" \
      [expr {[string is double -strict $sx] && $sx >= -0.001 && $sx <= 1.001}]
    # vv = vsweep*2, so y must track x -- and NOT be 1e-35, which is what a
    # log-mapped value would read back as (landmine 35)
    check_true "SG3 y is the RAW sample value (vv = 2*vsweep), not log-mapped" \
      [expr {[string is double -strict $sy] && abs($sy - 2.0*$sx) < 1e-6}]
    check_true "SG3 ...and specifically not the mylog10 clamp artefact" \
      [expr {abs($sy) < 1e30}]

    # the getter is a REPORT: polling it must not change the answer, so item 10
    # can read it as often as it likes for free
    check "SG4 polling the getter is stable (it never runs the query)" \
      [pcall {xschem get graph_snap}] $snapped
    check "SG4 ...twice" [pcall {xschem get graph_snap}] $snapped

    # ⚠ THE REPORTED BUG, as a regression leg. Walk a VERTICAL line through the
    # snapping x, from the top of the box to the bottom. The trace vv = 2*vsweep
    # occupies one y at that x, so most of these pixels are FAR from it -- and
    # every one of them must still snap, because the gate is the box, not a
    # distance. Before the fix only the handful within ~20 px of the trace did.
    lassign $snapped_at okx oky
    set tried 0; set got 0
    for {set yy [expr {int($H*0.05)}]} {$yy < int($H*0.95)} {incr yy 3} {
      event generate $vdrw <Motion> -x $okx -y $yy
      update
      set g [pcall {xschem get graph_snap}]
      if {$g ne {} && ![string match ERR:* $g]} { incr got }
      incr tried
    }
    check_true "SG6 the vertical sweep found the box at all" [expr {$got > 0}]
    # ⚠ A FRACTION, not a magic count. The first version of this leg used
    # `$got > 12`, and a 20-pixel proximity band sampled every 3 pixels yields
    # about 13 -- so the sabotage that restores the old proximity gate SQUEAKED
    # PAST it and the leg proved nothing. The plot box spans most of the strip,
    # so a box gate snaps on a large FRACTION of the sweep while a proximity
    # gate snaps on a few percent. Measured: ~0.78 vs ~0.07.
    check_true "SG6 the snapping band covers most of the sweep, not a thin band" \
      [expr {$tried > 0 && double($got)/$tried > 0.4}]
    # and a point far ABOVE the plot box must NOT snap
    event generate $vdrw <Motion> -x $okx -y 1
    update
    check "SG7 outside the plot box there is no snap" [pcall {xschem get graph_snap}] {}
    # restore a valid snap for the legs below
    event generate $vdrw <Motion> -x $okx -y $oky
    update

    # --- item 10: the status bar WIDGET half ---------------------------------
    set sb $vtop.wvstatus.l
    check_true "ST20 the viewer built its own status bar" \
      [expr {[winfo exists $sb] && [winfo ismapped $sb]}]
    # it must NOT be the editor's own bar: statusmsg()/update_statusbar() rewrite
    # that one from C on every GUI event and would silently clobber us
    check_true "ST20 the editor status bar is hidden in this window" \
      [expr {![winfo ismapped $vtop.statusbar]}]
    # a hover published a sample, so the bar must be showing it
    event generate $vdrw <Motion> -x $okx -y $oky
    update
    set txt [pcall {$sb cget -text}]
    check_true "ST21 the bar shows the plot mode" [string match "Plot: *" $txt]
    check_true "ST21 ...and the snapped x/y" \
      [expr {[string first "x:" $txt] >= 0 && [string first "y:" $txt] >= 0}]
    # the mode is PUSHED from the one mutation site, not polled
    pcall {wviewer::set_plot_mode multi $tok}
    check_true "ST22 changing the mode pushes the bar (no motion needed)" \
      [string match "Plot: multi*" [pcall {$sb cget -text}]]
    pcall {wviewer::set_plot_mode single $tok}
    check_true "ST22 ...and back" \
      [string match "Plot: single*" [pcall {$sb cget -text}]]
    # moving outside the plot box drops the position but keeps the mode
    event generate $vdrw <Motion> -x $okx -y 1
    update
    set txt2 [pcall {$sb cget -text}]
    check "ST23 outside the box the position is dropped" $txt2 {Plot: single}

    # disarming clears the published pick as well as the glyph
    pcall {xschem set graph_snap_cursor 0}
    check "SG5 disarming clears the published pick" [pcall {xschem get graph_snap}] {}
    pcall {xschem set graph_snap_cursor 1}

    # ========================================================================
    # SNG* — issue 0177 on a REAL canvas
    # ========================================================================
    # THE BLAST-RADIUS PAIR, exactly the shape of SG1. no_snap is per CONTEXT:
    # the viewer must answer 1 and every schematic window must answer 0. A
    # global would take the grid away from ordinary schematic editing, which is
    # the one thing this change must not do.
    xschem new_schematic switch $vdrw
    check "SNG1 the viewer window has no snap grid" [pcall {xschem get no_snap}] 1
    xschem new_schematic switch .drw
    check "SNG1 the MAIN schematic window still has one (per-ctx, not global)" \
      [pcall {xschem get no_snap}] 0
    xschem new_schematic switch $vdrw

    # A SNAPPED MIRROR IS AN EXACT MULTIPLE OF cadsnap. That is the assertion to
    # make, and it is the one a coalesced <Motion> cannot fake: comparing the
    # mirror against the pixel the loop THINKS it just sent reads a dropped
    # event as "snapped", but a lagged snapped value is still on the grid and a
    # lagged raw one still is not. (Measured under WSLg: ~2% of generated motion
    # events are coalesced away, which is enough to make the naive form flap.)
    proc snap_on_grid {v m} { expr {abs($v - round($v/double($m))*$m) < 1e-9} }
    # ⚠ cadsnap IS PER-CONTEXT STATE (tctx::global_list, src/xschem.tcl), so
    # `new_schematic switch` SAVES AND RESTORES it. Setting it before a switch
    # and expecting the value to survive is the mistake this comment exists to
    # stop: it silently reverts to the target window's own 10 and the leg then
    # measures a fine grid while claiming to measure a coarse one. Set it AFTER
    # every switch, and restore it per arm.
    set sn_save [pcall {set ::cadsnap}]
    set ::cadsnap 400
    set sn_ongrid 0; set sn_rows 0
    for {set yy 2} {$yy < $H - 2} {incr yy 5} {
      event generate $vdrw <Motion> -x [expr {int($W*0.42)}] -y $yy
      update
      set sx [pcall {xschem get mousex_snap}]; set sy [pcall {xschem get mousey_snap}]
      if {![string is double -strict $sx] || ![string is double -strict $sy]} continue
      incr sn_rows
      if {[snap_on_grid $sx 400] && [snap_on_grid $sy 400]} { incr sn_ongrid }
    }
    check_true "SNG2 the sweep actually read the mirror" [expr {$sn_rows > 50}]
    # ⚠ EVERY row, not most: the legend band, the axis margins, the reorder grip
    # and the rect-edge inset are all on this column, and the whole point of a
    # canvas PROPERTY is that none of them is special.
    check "SNG2 no pixel of the viewer canvas lands the pointer on the grid" \
      $sn_ongrid 0

    # THE OTHER HALF, and the reason it is here: nothing in the tree asserted
    # that a SCHEMATIC canvas still snaps, so a flag that leaked onto .drw would
    # have been caught only implicitly, by whichever gesture suite happened to
    # depend on an exact drag delta. This is the direct witness.
    xschem new_schematic switch .drw
    set sn_msave [pcall {set ::cadsnap}]
    set ::cadsnap 400
    update
    set sn_mongrid 0; set sn_mrows 0
    for {set yy 120} {$yy < 380} {incr yy 7} {
      event generate .drw <Motion> -x 300 -y $yy
      update
      set sx [pcall {xschem get mousex_snap}]; set sy [pcall {xschem get mousey_snap}]
      if {![string is double -strict $sx] || ![string is double -strict $sy]} continue
      incr sn_mrows
      if {[snap_on_grid $sx 400] && [snap_on_grid $sy 400]} { incr sn_mongrid }
    }
    check_true "SNG3 the schematic sweep actually read the mirror" \
      [expr {$sn_mrows > 20}]
    check "SNG3 the schematic canvas still snaps EVERY pointer position" \
      $sn_mongrid $sn_mrows
    set ::cadsnap $sn_msave
    xschem new_schematic switch $vdrw
    set ::cadsnap $sn_save

    # THREE traces, so the legend has three distinguishable slots to click. The
    # SG*/ST* fixture above deliberately holds ONE (it is testing the diamond,
    # which needs a trace, not a legend), and with n_nodes==1 every x in the band
    # answers slot 0 -- which would make the "same entry under a coarse grid" leg
    # unable to tell a right answer from a stuck one.
    pcall {xschem raw add vv2 "vsweep 3 *"}
    pcall {xschem raw add vv3 "vsweep 4 *"}
    pcall {wviewer::add_trace $tok 0 vv2}
    pcall {wviewer::add_trace $tok 0 vv3}
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    update
    set W [winfo width $vdrw]; set H [winfo height $vdrw]

    # ------------------------------------------------------------------------
    # THE ESCAPE ITSELF: a full Tk gesture on the legend, under a coarse grid.
    # ------------------------------------------------------------------------
    # What 0175's probe omitted was the <Motion> -- and the user's hand did not.
    # The gesture below is Motion -> Press -> a 1-px jitter -> Release, because
    # that is what a real click is; a press and release at byte-identical
    # coordinates is not reachable with a hand on a mouse.
    proc sn_legend_click {vdrw px py} {
      catch {xschem setprop -fast rect 2 0 hilight_wave {}}
      catch {xschem setprop -fast rect 2 0 sel_waves {}}
      focus -force $vdrw
      event generate $vdrw <Motion> -x $px -y $py ; update
      event generate $vdrw <ButtonPress-1> -x $px -y $py ; update
      event generate $vdrw <Motion> -x [expr {$px+1}] -y $py ; update
      event generate $vdrw <ButtonRelease-1> -x [expr {$px+1}] -y $py ; update
      return [xschem getprop rect 2 0 hilight_wave]
    }
    # Resolve the legend BAND (every canvas row whose slots answer 0/1/2) rather
    # than hard-coding a row: the horizontal layout spans gr->ry1..gr->y1, whose
    # pixel height is 14% of the strip and therefore window-dependent.
    set sn_band {}
    for {set yy 0} {$yy < int($H*0.5)} {incr yy} {
      set a [pcall {xschem get graph_legend_at 0 [expr {int($W*0.12)}] $yy}]
      set b [pcall {xschem get graph_legend_at 0 [expr {int($W*0.72)}] $yy}]
      if {$a eq "0" && $b eq "2"} { lappend sn_band $yy }
    }
    # ⚠ CLICK IN THE MIDDLE OF THE BAND, NOT AT ITS TOP EDGE. The first row that
    # answers the legend query is the rect's own top edge, and waves_selected
    # deliberately keeps a small inset there so the rect stays grabbable on a
    # schematic canvas -- so the topmost legend rows legitimately do not route to
    # the graph. SNG6 below is the leg that measures how many rows that costs;
    # this one is about the entries themselves.
    set sn_row {}
    if {[llength $sn_band] > 8} {
      set sn_row [lindex $sn_band [expr {[llength $sn_band] / 2}]]
    }
    if {$sn_row eq {}} {
      puts "SKIPPED: SNG4+ (no legend band resolved -- WSLg geometry)"
    } else {
      set sn_fine {}
      set ::cadsnap 10
      foreach frac {0.12 0.42 0.72} {
        lappend sn_fine [sn_legend_click $vdrw [expr {int($W*$frac)}] $sn_row]
      }
      set sn_coarse {}
      set ::cadsnap 400
      foreach frac {0.12 0.42 0.72} {
        lappend sn_coarse [sn_legend_click $vdrw [expr {int($W*$frac)}] $sn_row]
      }
      set ::cadsnap $sn_save
      check "SNG4 a real gesture on each legend entry selects that entry" \
        $sn_fine {0 1 2}
      # THE REGRESSION LEG. With a 40x coarser grid the SAME entry must come
      # back -- not "an entry", the same one.
      check "SNG4 ...and a 40x coarser snap grid changes nothing" \
        $sn_coarse $sn_fine

      # ------------------------------------------------------------------
      # HOVER over the legend band. Nothing covered this at all before 0177.
      # ------------------------------------------------------------------
      # The readable witness for the routing decision is the CURSOR: waves_selected
      # sets `tcross` when it takes the event for the graph and resets it when it
      # declines, and declining is exactly what sends the pointer down the
      # schematic arm (graph_snap_clear, then the crosshair at mousex_snap, then
      # draw_hover). So `tcross` over the whole legend band is the assertion that
      # no schematic pointer ornament can be drawn there.
      event generate $vdrw <Motion> -x [expr {int($W*0.42)}] -y $sn_row ; update
      check "SNG5 a legend hover is routed to the GRAPH (tcross cursor)" \
        [pcall {$vdrw cget -cursor}] tcross
      # ...and the item-9 diamond yields there, because the legend is outside the
      # plot box: the legend band draws NOTHING under the pointer.
      check "SNG5 ...and nothing is snapped over the legend (outside the box)" \
        [pcall {xschem get graph_snap}] {}

      # THE BAND THE UNITS BUG CREATED. Walk the legend column from the rect's
      # top edge down and count how many legend rows route to the schematic
      # canvas. Pre-fix that band was 22 px deep on this geometry; the intended
      # 5-screen-px inset is ~7. Asserting a FRACTION rather than a pixel keeps
      # the leg honest across window sizes and tk scalings.
      set sn_dead 0
      foreach yy $sn_band {
        event generate $vdrw <Motion> -x [expr {int($W*0.42)}] -y $yy ; update
        if {[pcall {$vdrw cget -cursor}] ne "tcross"} { incr sn_dead }
      }
      check_true "SNG6 the legend band was walked" [expr {[llength $sn_band] > 20}]
      # 5*tk_scaling SCREEN px is a handful of rows whatever the zoom. Before the
      # conversion it was 1/zoom times wider -- MEASURED 22 rows on a 1000x776
      # viewer at zoom 0.2738, which is where the reporter's clicks were landing.
      check_true "SNG6 the rect-edge inset costs only a few legend rows, not tens" \
        [expr {$sn_dead <= 12}]
      # ...and it must not eat the band either: the inset is a margin, not a lid.
      check_true "SNG6 most of the legend band routes to the graph" \
        [expr {double([llength $sn_band] - $sn_dead) / [llength $sn_band] > 0.8}]
      event generate $vdrw <Motion> -x $okx -y $oky ; update
    }
  }

  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: SG* GUI legs (no DISPLAY)"
}

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_snap: $npass passed, $fail failed"
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
