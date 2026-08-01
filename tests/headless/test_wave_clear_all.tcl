# tests/headless/test_wave_clear_all.tcl — ASE Waveform Viewer "Clear All"
# (issue 0171; contract in doc/claude/specs/waveform_viewer.md)
#
# The feature: Ctrl-D in the viewer deletes every graph and every trace and
# leaves ONE empty strip. The plot mode is retained; the key is remappable from
# an rc file; the action is logged replayably.
#
# What is asserted here:
#   CA*  no-window legs (run under --nogui too): clear_all never throws when no
#        viewer resolves — unknown token and omitted token both return {}
#   CG1  the CLEAR itself: 3 strips with traces + an auto-plot strip -> exactly
#        one EMPTY graph in the model AND one layer-2 rect on the canvas; the
#        auto marker is gone (so the next run appends its own strip); target
#        back to 0; modified still 0 (readonly discipline held by with_edit)
#   CG2  what SURVIVES a clear: the plot mode (the explicit requirement — both
#        multi and single arms), Shared X, and the LOADED RAW (points/sim_type
#        unchanged: a clear must not force a re-run)
#   CG3  replayable logging: exactly one `wviewer::clear_all <token>` line per
#        clear, explicit token, and one on a redundant clear too (documented
#        always-log rule, unlike set_plot_mode's change-only rule)
#   CG4  the binding SEAM: the `WaveViewer` bindtag is on the viewer canvas
#        right after the widget, carries the Ctrl-D default, and survives the
#        strip_bindings sweep that clears every widget-level sequence
#   CG5  a REAL Ctrl-D key event on the viewer canvas clears it (the whole
#        chain: Tk -> key_filter does not swallow it -> tag binding ->
#        clear_all_at -> model)
#   CG6  REMAPPABILITY from an rc file: `bind WaveViewer <Control-Key-d>
#        {break}` disables the default, a user sequence bound on the tag works,
#        and install_default_binds does NOT overwrite a binding an rc already
#        made (the "rc wins" rule — rc files run before the first viewer open)
#   CG7  Graph > Clear All: the menu entry exists with the Ctrl+D accelerator
#        and invoking it clears
#   CG8  the follow-up defect: the strip a clear leaves behind must be USED by
#        the next plot gesture, not appended past — clear -> multi-plot -> 3
#        signals must give 3 strips with no blank band, laid out NEWEST-FIRST
#        (last pick on top, 2026-07-27), with the picker's predicted colors
#        intact per signal (the landing policy itself is pinned by
#        test_wave_modes M3/M3b/MG6/MG12)
#   CG9  issue 0172: a REAL viewer window is not offered to `load_new_window` as a
#        pristine-untitled reuse target — wviewer::open brands the context
#        (`xschem get wave_viewer` == 1) and the open goes to a NEW window with the
#        viewer's graph rects intact. The mechanism-level guard is headless, in
#        tests/headless/test_pristine_untitled_viewer_0172.tcl; this leg is what
#        proves the branding actually happens in production
#
# NOT asserted (stated, not hidden): pixels. That a cleared viewer *renders* as
# one empty grid is eyeball-only, exactly like every other wave rendering
# (test_wave_viewer.tcl header). What IS asserted is the model, the rect count
# and that the redraw inside regenerate returned without error.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_clear_all.tcl
# (add --nogui to run only the CA* legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# error-guarded call: a MISSING proc must make its own leg FAIL, not abort the
# whole file through the outer catch
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch wvclear]

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

if {[catch {

# ============================================================================
# CA* — no window needed
# ============================================================================
check "CA1 unknown token -> {} (no throw)" \
  [pcall {wviewer::clear_all no/such/token}] {}
check "CA2 omitted token with no viewer -> {} (no throw)" \
  [pcall {wviewer::clear_all}] {}
check "CA3 clear_all_at on a non-viewer canvas -> {} (no throw)" \
  [pcall {wviewer::clear_all_at .drw}] {}

# ============================================================================
# CG* — GUI legs (self-SKIP without a usable DISPLAY)
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

  # deliver a REAL generated key event, WSLg-robustly (the send_key pattern of
  # test_wave_viewer.tcl / test_ase_dialogs.tcl: generated KeyPress events go to
  # the display's focus window and the WSLg focus round-trip is asynchronous, so
  # every generate is gated on Tk reporting $w as the focus owner and retried
  # until $done — an expr evaluated in the CALLER's scope — turns true).
  proc send_key {w ev done} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w]} {
        focus -force $w
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
        if {[winfo exists $w] && [focus -displayof $w] eq $w} {
          event generate $w $ev
          update
          if {[uplevel 1 [list expr $done]]} { return 1 }
        }
      }
      after 50
    }
    puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
    return 0
  }

  # model helpers: number of strips / traces of strip gi
  proc ngraphs {tok} { llength [dict get [wviewer::layout_for $tok] graphs] }
  proc ntraces {tok gi} {
    set gs [dict get [wviewer::layout_for $tok] graphs]
    if {$gi >= [llength $gs]} { return -1 }
    return [llength [dict get [lindex $gs $gi] traces]]
  }
  # a viewer with content: 3 strips, traces in each, plus the ASE auto strip
  proc fill_viewer {tok} {
    wviewer::set_graphs $tok [list [wviewer::empty_graph] \
                                   [wviewer::empty_graph] \
                                   [wviewer::empty_graph]]
    wviewer::ensure_auto_graph $tok
    foreach {gi vec} {0 vec_a 0 vec_b 1 vec_c 2 vec_d 3 vec_e} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  fill_viewer: add_trace $vec -> $e" }
    }
    wviewer::regenerate $tok
  }

  # session registration (headless-style: no ASE window needed for the viewer)
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "CG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: CG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  # spy on the replayable-log seam (the slickprop::log_apply pattern)
  set ::wvc_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wvc_log $line }

  # a raw dataset attached to the viewer ctx — synthetic, hermetic (no ngspice,
  # no .raw file): `xschem raw new <name> <type> <sweepvar> <start> <end> <step>`
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvclear.raw dc vsweep 0 1.0 0.1}
  # real vectors to plot: add_trace VALIDATES a trace against the loaded raw's
  # variable list, so a fixture built from names the raw does not know would
  # silently record nothing and every "cleared it" assertion below would pass
  # against an already-empty model (green-but-hollow). Each is a derived vector
  # (`raw add <name> <rpn>`), which is also what makes them real columns.
  foreach v {vec_a vec_b vec_c vec_d vec_e p1 p2 p3 s1 s2 t1} {
    pcall {xschem raw add $v "vsweep 1 +"}
  }
  set rawvars [split [pcall {xschem raw list}] "\n"]
  check_true "CG0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $rawvars vec_a] >= 0 && [lsearch -exact $rawvars p1] >= 0}]
  set raw_before [list [pcall {xschem raw sim_type}] [pcall {xschem raw points}]]

  # --- CG1: the clear itself -------------------------------------------------
  fill_viewer $tok
  check "CG1 fixture has 4 strips" [ngraphs $tok] 4
  # teeth: the fixture must really HOLD traces, else "it is empty afterwards"
  # would pass against a model that was empty all along
  check "CG1 fixture strips actually hold traces" \
    [list [ntraces $tok 0] [ntraces $tok 1] [ntraces $tok 2] [ntraces $tok 3]] \
    {2 1 1 1}
  check "CG1 fixture has an auto-plot strip" [pcall {wviewer::auto_graph_index $tok}] 3
  pcall {wviewer::set_target_strip 2 $tok}
  check "CG1 fixture target is strip 2" [pcall {wviewer::target_strip $tok}] 2
  xschem new_schematic switch $vdrw
  check_true "CG1 fixture placed 4 graph rects" [expr {[xschem get rects 2] == 4}]

  check "CG1 clear_all returns 1" [pcall {wviewer::clear_all $tok}] 1
  check "CG1 exactly ONE strip remains" [ngraphs $tok] 1
  check "CG1 the survivor is EMPTY" [ntraces $tok 0] 0
  check "CG1 the auto-plot marker is gone" [pcall {wviewer::auto_graph_index $tok}] -1
  check "CG1 target reset to 0" [pcall {wviewer::target_strip $tok}] 0
  xschem new_schematic switch $vdrw
  check "CG1 exactly one layer-2 rect on the canvas" [xschem get rects 2] 1
  check "CG1 the rect is still a graph" [xschem getprop rect 2 0 flags] graph
  check "CG1 the rect carries no traces" [xschem getprop rect 2 0 node] {}
  check "CG1 one strip -> no active marker token" [xschem getprop rect 2 0 active] {}
  check "CG1 buffer NOT left modified (with_edit discipline)" [xschem get modified] 0
  check "CG1 next auto-plot run appends its OWN strip" \
    [pcall {wviewer::ensure_auto_graph $tok}] 1
  check "CG1 the empty survivor is untouched by that append" [ntraces $tok 0] 0

  # --- CG2: what survives a clear -------------------------------------------
  # the explicit requirement: the plot mode is RETAINED, both ways
  pcall {wviewer::set_plot_mode multi $tok}
  set ::wviewer::sharedx($tok) 1
  wviewer::sharedx_toggle $tok
  fill_viewer $tok
  pcall {wviewer::clear_all $tok}
  check "CG2 multi-plot mode retained across a clear" \
    [pcall {wviewer::plot_mode $tok}] multi
  check "CG2 Shared X retained across a clear" \
    [pcall {dict get [wviewer::layout_for $tok] sharedx}] 1
  pcall {wviewer::set_plot_mode single $tok}
  fill_viewer $tok
  pcall {wviewer::clear_all $tok}
  check "CG2 single-plot mode retained across a clear" \
    [pcall {wviewer::plot_mode $tok}] single
  # the loaded raw is NOT cleared — re-picking must not need a re-run
  xschem new_schematic switch $vdrw
  check_true "CG2 raw still loaded after a clear" \
    [expr {[pcall {xschem raw loaded}] >= 0}]
  check "CG2 raw sim_type/points unchanged" \
    [list [pcall {xschem raw sim_type}] [pcall {xschem raw points}]] $raw_before

  # --- CG3: replayable logging ----------------------------------------------
  fill_viewer $tok
  set nlog [llength $::wvc_log]
  pcall {wviewer::clear_all $tok}
  check "CG3 exactly one line logged per clear" \
    [expr {[llength $::wvc_log] - $nlog}] 1
  check "CG3 the line is replayable, with the EXPLICIT token" \
    [lindex $::wvc_log end] "wviewer::clear_all $tok"
  # documented always-log rule: a redundant clear is still a gesture
  set nlog [llength $::wvc_log]
  pcall {wviewer::clear_all $tok}
  check "CG3 a redundant clear is logged too" \
    [expr {[llength $::wvc_log] - $nlog}] 1
  check "CG3 the redundant clear left one empty strip" \
    [list [ngraphs $tok] [ntraces $tok 0]] {1 0}
  # replaying the logged line must reproduce the state
  fill_viewer $tok
  pcall {uplevel #0 [lindex $::wvc_log end]}
  check "CG3 replaying the logged line clears the window" \
    [list [ngraphs $tok] [ntraces $tok 0]] {1 0}
  # and the omitted-token form works on the active window
  fill_viewer $tok
  xschem new_schematic switch $vdrw
  check "CG3 omitted token targets the active viewer" [pcall {wviewer::clear_all}] 1
  check "CG3 omitted-token clear did the work" \
    [list [ngraphs $tok] [ntraces $tok 0]] {1 0}

  # --- CG4: the binding seam -------------------------------------------------
  set btags [bindtags $vdrw]
  check_true "CG4 the WaveViewer bindtag is on the viewer canvas" \
    [expr {[lsearch -exact $btags WaveViewer] >= 0}]
  check "CG4 the tag sits right AFTER the widget (filters keep first refusal)" \
    [lindex $btags 1] WaveViewer
  check_true "CG4 Ctrl-D is bound on the tag by default" \
    [expr {[bind WaveViewer <Control-Key-d>] ne {}}]
  check_true "CG4 the default calls clear_all_at with the event's canvas" \
    [string match {*wviewer::clear_all_at %W*} [bind WaveViewer <Control-Key-d>]]
  # sweep-proof: strip_bindings clears every WIDGET-level sequence, so a viewer
  # key bound there would die on the next sweep — the tag one does not
  wviewer::strip_bindings $vdrw
  check_true "CG4 the tag binding survives a re-sweep" \
    [expr {[bind WaveViewer <Control-Key-d>] ne {}}]
  check "CG4 the sweep does not duplicate the tag" \
    [llength [lsearch -all -exact [bindtags $vdrw] WaveViewer]] 1
  check "CG4 Ctrl-D is NOT bound on the canvas widget itself" \
    [bind $vdrw <Control-Key-d>] {}

  # --- CG5: a REAL Ctrl-D event ---------------------------------------------
  fill_viewer $tok
  check "CG5 fixture is not already clear" [ngraphs $tok] 4
  set delivered [send_key $vdrw <Control-Key-d> {[ngraphs $tok] == 1}]
  if {!$delivered} {
    puts "SKIPPED: CG5/CG6 real-key legs (focus never confirmed)"
  } else {
    check "CG5 Ctrl-D left exactly one strip" [ngraphs $tok] 1
    check "CG5 Ctrl-D left it empty" [ntraces $tok 0] 0
    check "CG5 the key gesture is logged like the command" \
      [lindex $::wvc_log end] "wviewer::clear_all $tok"

    # --- CG6: rc REMAPPABILITY ----------------------------------------------
    # (a) an rc can DISABLE the default with `{break}`
    bind WaveViewer <Control-Key-d> {break}
    fill_viewer $tok
    focus -force $vdrw; update
    event generate $vdrw <Control-Key-d>; update
    check "CG6 a disabled Ctrl-D clears nothing" [ngraphs $tok] 4
    # (b) an rc can bind its own sequence
    bind WaveViewer <Control-Key-r> {wviewer::clear_all_at %W; break}
    check_true "CG6 the remapped key clears" \
      [send_key $vdrw <Control-Key-r> {[ngraphs $tok] == 1}]
    check "CG6 the remapped key left one empty strip" \
      [list [ngraphs $tok] [ntraces $tok 0]] {1 0}
    # (c) rc WINS: install_default_binds never overwrites an existing binding
    #     (rc files are sourced before the first viewer open). Reset the
    #     one-shot guard to replay a "first open" against the rc's binding.
    set ::wviewer::tagbinds 0
    check "CG6 install_default_binds runs once per session" \
      [pcall {wviewer::install_default_binds}] 1
    check "CG6 an rc binding is NOT overwritten by the defaults" \
      [bind WaveViewer <Control-Key-d>] {break}
    check "CG6 a second call is a no-op" [pcall {wviewer::install_default_binds}] 0
    # restore the shipped default for anything that runs after
    bind WaveViewer <Control-Key-r> {}
    bind WaveViewer <Control-Key-d> {}
    set ::wviewer::tagbinds 0
    pcall {wviewer::install_default_binds}
    check_true "CG6 shipped default restored" \
      [string match {*clear_all_at*} [bind WaveViewer <Control-Key-d>]]
  }

  # --- CG7: Graph > Clear All ------------------------------------------------
  set mb $vtop.wvmenubar
  set gi -1
  for {set i 0} {$i <= [$mb.graph index end]} {incr i} {
    if {![catch {$mb.graph entrycget $i -label} lab] && $lab eq {Clear All}} {
      set gi $i
    }
  }
  check_true "CG7 Graph menu carries a Clear All entry" [expr {$gi >= 0}]
  if {$gi >= 0} {
    check "CG7 the entry advertises Ctrl+D" \
      [$mb.graph entrycget $gi -accelerator] Ctrl+D
    fill_viewer $tok
    set nlog [llength $::wvc_log]
    $mb.graph invoke $gi
    check "CG7 invoking the menu entry clears the window" \
      [list [ngraphs $tok] [ntraces $tok 0]] {1 0}
    check "CG7 exactly one log line per menu use" \
      [expr {[llength $::wvc_log] - $nlog}] 1
  }

  # --- CG8: the cleared strip GETS USED (reported follow-up) -----------------
  # The exact reported flow: a viewer with plots -> Ctrl-D -> Ctrl-Shift-4
  # (multi-plot) -> Ctrl-4, pick 3 signals, ESC. Pre-fix multi-plot appended
  # past the cleared strip and left a blank band pinned at the top of the
  # window. Driven at the plot_signals seam (the one ase::ui::dp_finish calls;
  # test_wave_modes MG12 drives the real dp_finish for both arms).
  proc cg_colors {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      foreach tr [dict get $G traces] { lappend out [dict get $tr color] }
    }
    return $out
  }
  proc cg_expr {tok gi ti} {
    set G [lindex [dict get [wviewer::layout_for $tok] graphs] $gi]
    return [dict get [lindex [dict get $G traces] $ti] expr]
  }
  # by SIGNAL, not by model order: multi-plot lays a batch out newest-first
  proc cg_color_of {tok ex} {
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      foreach tr [dict get $G traces] {
        if {[dict get $tr expr] eq $ex} { return [dict get $tr color] }
      }
    }
    return {}
  }
  fill_viewer $tok
  pcall {wviewer::clear_all $tok}
  pcall {wviewer::set_plot_mode multi $tok}
  check "CG8 cleared viewer has one empty strip" \
    [list [ngraphs $tok] [ntraces $tok 0]] {1 0}
  set pre [pcall {wviewer::predict_colors $tok 3}]
  check "CG8 no per-signal errors" \
    [pcall {wviewer::plot_signals $tok {p1 p2 p3}}] {}
  check "CG8 3 signals -> exactly 3 strips (the cleared one was REUSED)" \
    [ngraphs $tok] 3
  check "CG8 no strip is left empty" \
    [pcall {wviewer::empty_graph_indices \
              [dict get [wviewer::layout_for $tok] graphs]}] {}
  # newest-first (2026-07-27): picking p1 p2 p3 must read p3 p2 p1 top-down
  check "CG8 the LAST pick is the TOP strip" [pcall {cg_expr $tok 0 0}] {p3}
  check "CG8 the middle pick is in the middle" [pcall {cg_expr $tok 1 0}] {p2}
  check "CG8 the FIRST pick is the bottom strip" [pcall {cg_expr $tok 2 0}] {p1}
  xschem new_schematic switch $vdrw
  check "CG8 three rects on the canvas, no blank band" [xschem get rects 2] 3
  check "CG8 the picker's predicted colors still match what landed (per signal)" \
    $pre [list [pcall {cg_color_of $tok p1}] [pcall {cg_color_of $tok p2}] \
               [pcall {cg_color_of $tok p3}]]
  check "CG8 multi-plot still gave every trace its own color" \
    [llength [lsort -unique [pcall {cg_colors $tok}]]] 3
  # single-plot after a clear: everything into the cleared strip, still 1 strip
  pcall {wviewer::clear_all $tok}
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::plot_signals $tok {s1 s2}}
  check "CG8 single-plot fills the cleared strip, creates nothing" \
    [list [ngraphs $tok] [ntraces $tok 0]] {1 2}
  # a SECOND multi gesture, now that nothing is empty, creates its strip ON TOP
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::plot_signals $tok {t1}}
  check "CG8 with no empty strip left, the new strip goes on TOP" \
    [list [ngraphs $tok] [pcall {cg_expr $tok 0 0}] [ntraces $tok 1]] {2 t1 2}
  rename cg_colors {}
  rename cg_expr {}
  rename cg_color_of {}

  # --- CG9: issue 0172 — a REAL viewer is not a pristine-untitled reuse target ------
  # `is_pristine_untitled()` (src/scheduler.c) used to accept a live viewer as a scratch
  # buffer to load over — it is top level, named untitled, has no instances and no
  # wires, and `with_edit` (D1) keeps `modified` at 0 forever — so File>Open landed a
  # user schematic INSIDE this window, destroying its graph rects while the WaveViewer
  # bindtag stayed on: the very next Ctrl-D (CG1 above) then wiped the document.
  # The mechanism-level guard is headless (tests/headless/test_pristine_untitled_viewer_0172.tcl,
  # which imitates a viewer by stamping the flags). THIS leg is the one that proves
  # `wviewer::open` itself stamps `wave_viewer`, i.e. that the C-side refusal is armed in
  # production rather than only in the test's imitation.
  xschem new_schematic switch $vdrw
  check_true "CG9 wviewer::open branded the viewer context (wave_viewer)" \
    [expr {[xschem get wave_viewer] eq "1"}]
  set cg9_sch [file join $scratch cg9_real.sch]
  set cg9_fh [open $cg9_sch w]
  puts $cg9_fh "v {xschem version=3.4.5 file_version=1.2}"
  foreach cg9_l {G K V S E} { puts $cg9_fh "$cg9_l {}" }
  puts $cg9_fh "N 0 0 100 0 {lab=A}"
  close $cg9_fh
  set cg9_rects [xschem get rects 2]
  set cg9_tabs [xschem get ntabs]
  check_true "CG9 the viewer holds rects and no wires before the open" \
    [expr {$cg9_rects > 0 && [xschem get wires] == 0}]
  xschem load_new_window $cg9_sch
  check_true "CG9 the open created a NEW window, it did not reuse the viewer" \
    [expr {[xschem get ntabs] == $cg9_tabs + 1 && [xschem get current_win_path] ne $vdrw}]
  xschem new_schematic switch $vdrw
  check_true "CG9 the viewer still holds its own buffer and its graph rects" \
    [expr {[xschem get rects 2] == $cg9_rects && [xschem get wires] == 0 &&
           [string match {untitled*} [file tail [xschem get schname]]]}]
  update

  # --- CG10: issue 0172, the FOURTH door — `xschem load` with no filename ----------
  # `ask_new_file()` (actions.c) is the File>Open C path and the only door that never
  # consults `is_pristine_untitled()`: with `open_in_new_window` 0 (the shipping
  # default) its in-place arm calls load_schematic() unconditionally, so the predicate's
  # viewer refusal cannot reach it. It is entered by `xschem load` with NO argument —
  # the CIW rewrite only adds `-gui` to a load that HAS one — so a typed bare `xschem
  # load` while the viewer holds the context used to clobber it. Fixed in ask_new_file
  # itself: a `wave_viewer` context forces the new-window arm.
  # The dialog is stubbed, exactly as test_load_window_routing stubs ask_save.
  set ::new_file_browser 0
  set ::open_in_new_window 0
  rename load_file_dialog __real_load_file_dialog
  proc load_file_dialog {args} { return $::cg10_file }
  # a DIFFERENT file from CG9's: `new_schematic create` resolves a file that is already
  # open by switching to the window holding it instead of making a new one, which would
  # leave `ntabs` unmoved and read exactly like the hijack this leg is looking for
  set ::cg10_file [file join $scratch cg10_real.sch]
  set cg10_fh [open $::cg10_file w]
  puts $cg10_fh "v {xschem version=3.4.5 file_version=1.2}"
  foreach cg10_l {G K V S E} { puts $cg10_fh "$cg10_l {}" }
  puts $cg10_fh "N 0 40 100 40 {lab=C}"
  close $cg10_fh
  xschem new_schematic switch $vdrw
  set cg10_rects [xschem get rects 2]
  set cg10_tabs [xschem get ntabs]
  check_true "CG10 the viewer holds rects before the bare load" [expr {$cg10_rects > 0}]
  pcall {xschem load}
  check_true "CG10 bare `xschem load` did not load into the viewer" \
    [expr {[xschem get ntabs] == $cg10_tabs + 1 && [xschem get current_win_path] ne $vdrw}]
  xschem new_schematic switch $vdrw
  check_true "CG10 the viewer still holds its graph rects afterwards" \
    [expr {[xschem get rects 2] == $cg10_rects && [xschem get wires] == 0 &&
           [string match {untitled*} [file tail [xschem get schname]]]}]
  rename load_file_dialog {}
  rename __real_load_file_dialog load_file_dialog
  update

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  catch {wviewer::close $tok}
  update
  }
} else {
  puts "SKIPPED: CG* GUI legs (no usable DISPLAY)"
  # Say what is NOT covered on this arm rather than letting a 3-check ALL PASS imply the
  # whole file ran: CG9/CG10 are the ONLY guards for two parts of the issue-0172 fix
  # (that wviewer::open really brands the context, and that ask_new_file refuses to load
  # in place over a viewer), and full_audit's is_pass() scores this file PASS with every
  # CG leg skipped. The mechanism-level guard that does run headless is
  # tests/headless/test_pristine_untitled_viewer_0172.tcl.
  puts "NOTE: CG9/CG10 (issue 0172 viewer-hijack guards) need X and did not run"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts $::errorInfo
  incr fail
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
