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
