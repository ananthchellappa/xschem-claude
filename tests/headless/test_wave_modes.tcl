# tests/headless/test_wave_modes.tcl — ASE Waveform Viewer PLOT MODES (issue 0151)
#
# Spec: doc/claude/specs/waveform_viewer_modes.md
#
# What is asserted here (and why it is honest):
#   PURE legs (M*) need no DISPLAY — they drive the policy/validation procs
#   directly with hand-built arguments:
#     M1 wviewer::resolve_mode      single|multi|invert + garbage rejection
#     M2 wviewer::default_plot_mode config var -> initial mode, invalid -> single
#     M3 wviewer::plan_plot         THE landing policy: single = all signals into
#                                   the (clamped) target, no new strip unless the
#                                   stack is empty; multi = one NEW strip per
#                                   signal, appended after the existing ones
#     M4 wviewer::target_clamp      stale/negative target never escapes range
#     M5 wviewer::graph_props       emits `active=1` ONLY when asked (the C
#                                   indicator's only Tcl-side witness)
#   GUI legs (MG*) open a real viewer window (self-SKIP without a usable
#   DISPLAY) and assert per-window state, the menu, the click re-target, the
#   prop-token plumbing of the marker, persistence and the schematic-side
#   entry points.
#
# NOT asserted (stated, not hidden): the PIXELS of the dull-yellow active-strip
# marker. The C draw is gated behind draw_graph's new flags bit 16 and is
# eyeball-only, exactly like the wave rendering itself (test_wave_viewer.tcl
# header). What IS asserted is which rect carries `active=1`, when the token is
# absent, and that a redraw with the token present returns rc 0.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_modes.tcl
# (add --nogui to run only the pure legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# error-guarded call: a MISSING proc must make its own leg FAIL, not abort the
# whole file through the outer catch (this file is written RED-first, so every
# leg has to be able to report independently)
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
set scratch [test_scratch wvmodes]

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]

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
# PURE legs — policy + validation, no window
# ============================================================================

# --- M1: mode word resolution ------------------------------------------------
check "M1 invert flips single -> multi"  [pcall {wviewer::resolve_mode single invert}] multi
check "M1 invert flips multi -> single"  [pcall {wviewer::resolve_mode multi invert}]  single
check "M1 explicit multi"                [pcall {wviewer::resolve_mode single multi}]  multi
check "M1 explicit single"               [pcall {wviewer::resolve_mode multi single}]  single
check "M1 idempotent set"                [pcall {wviewer::resolve_mode multi multi}]   multi
check "M1 garbage rejected as {}"        [pcall {wviewer::resolve_mode single bogus}]  {}
check "M1 empty request rejected as {}"  [pcall {wviewer::resolve_mode single {}}]     {}
check "M1 case-insensitive request"      [pcall {wviewer::resolve_mode single MULTI}]  multi

# --- M2: config var -> initial mode ------------------------------------------
set save_cfg {}
if {[info exists ::wviewer_plot_mode]} { set save_cfg $::wviewer_plot_mode }
check "M2 shipped default is single" [pcall {set ::wviewer_plot_mode}] single
set ::wviewer_plot_mode multi
check "M2 config multi -> multi"     [pcall {wviewer::default_plot_mode}] multi
set ::wviewer_plot_mode MULTI
check "M2 config MULTI -> multi"     [pcall {wviewer::default_plot_mode}] multi
set ::wviewer_plot_mode nonsense
check "M2 invalid config -> single"  [pcall {wviewer::default_plot_mode}] single
set ::wviewer_plot_mode {}
check "M2 empty config -> single"    [pcall {wviewer::default_plot_mode}] single
set ::wviewer_plot_mode $save_cfg

# --- M3: THE landing policy --------------------------------------------------
# single: no new strip while one exists, everything into the target
check "M3 single/2 strips/target 1/3 signals" \
  [pcall {wviewer::plan_plot single 2 1 3}] {new 0 targets {1 1 1}}
check "M3 single/1 strip/target 0/1 signal" \
  [pcall {wviewer::plan_plot single 1 0 1}] {new 0 targets 0}
# single into an EMPTY stack: exactly one strip is created and used
check "M3 single/0 strips creates exactly one" \
  [pcall {wviewer::plan_plot single 0 0 2}] {new 1 targets {0 0}}
# a stale target (strip deleted since) can never escape the range
check "M3 single clamps a stale high target" \
  [pcall {wviewer::plan_plot single 2 7 1}] {new 0 targets 1}
check "M3 single clamps a negative target" \
  [pcall {wviewer::plan_plot single 3 -2 1}] {new 0 targets 0}
# multi: one NEW strip per signal, appended AFTER the existing stack
check "M3 multi/2 strips/3 signals appends 3" \
  [pcall {wviewer::plan_plot multi 2 0 3}] {new 3 targets {2 3 4}}
check "M3 multi/0 strips/1 signal" \
  [pcall {wviewer::plan_plot multi 0 0 1}] {new 1 targets 0}
check "M3 multi ignores the target" \
  [pcall {wviewer::plan_plot multi 2 1 2}] {new 2 targets {2 3}}
# empty gesture creates nothing in either mode
check "M3 single/0 signals is a no-op"  [pcall {wviewer::plan_plot single 2 1 0}] {new 0 targets {}}
check "M3 multi/0 signals is a no-op"   [pcall {wviewer::plan_plot multi 2 1 0}]  {new 0 targets {}}
# the ASE auto-plot strip is NEVER a Direct-Plot landing site: it is cleared
# and rebuilt after every run, so traces put there would vanish (and item 13's
# "Direct-Plot graphs and the auto graph never touch each other" would break)
check "M3 single refuses to land in the auto strip -> appends one" \
  [pcall {wviewer::plan_plot single 1 0 2 0}] {new 1 targets {1 1}}
check "M3 single lands normally when the target is NOT the auto strip" \
  [pcall {wviewer::plan_plot single 2 1 1 0}] {new 0 targets 1}
check "M3 auto strip elsewhere in the stack does not disturb the plan" \
  [pcall {wviewer::plan_plot single 3 2 1 0}] {new 0 targets 2}
check "M3 multi ignores the auto strip too (always appends)" \
  [pcall {wviewer::plan_plot multi 1 0 2 0}] {new 2 targets {1 2}}

# --- M4: target clamp --------------------------------------------------------
check "M4 in-range target kept"        [pcall {wviewer::target_clamp 1 3}]  1
check "M4 too-high target clamped"     [pcall {wviewer::target_clamp 5 3}]  2
check "M4 negative target clamped"     [pcall {wviewer::target_clamp -1 3}] 0
check "M4 empty layout -> 0"           [pcall {wviewer::target_clamp 2 0}]  0
check "M4 non-integer target -> 0"     [pcall {wviewer::target_clamp x 3}]  0

# --- M5: the marker's prop token --------------------------------------------
set Gm [dict create traces [list [dict create expr {v(d)} name {} vec {v(d)} \
          color 4]] logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
set p_off [pcall {wviewer::graph_props $Gm}]
set p_on  [pcall {wviewer::graph_props $Gm 1}]
check_true "M5 default props carry NO active token" \
  [expr {![string match {*active=*} $p_off]}]
check_true "M5 active arg emits active=1" \
  [expr {[string match {*active=1*} $p_on]}]
check_true "M5 active props still carry flags=graph" \
  [expr {[string match {flags=graph*} $p_on]}]
check_true "M5 explicit 0 emits no active token" \
  [expr {![string match {*active=*} [pcall {wviewer::graph_props $Gm 0}]]}]

# ============================================================================
# GUI legs
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

  # session registration (headless-style: no ASE window needed for the viewer).
  # dc is enabled so ase::plot_sim_type is `dc`, not `op` — dp_finish aborts on
  # op-only results, and MG12 drives the REAL dp_finish path.
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set an {}
  foreach a [dict get $st analyses] {
    if {[dict get $a type] eq {dc}} {
      set a [dict create type dc enabled 1 source V2 start 0 stop 1.8 step 0.01]
    }
    lappend an $a
  }
  dict set st analyses $an
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  # --- MG1: fresh window -> config default, target 0 -------------------------
  check "MG1 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: MG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {
  check "MG1 fresh viewer is in the shipped default mode" \
    [pcall {wviewer::plot_mode $tok}] single
  check "MG1 fresh viewer targets strip 0" [pcall {wviewer::target_strip $tok}] 0
  xschem new_schematic switch $vdrw
  check "MG1 current_token resolves the active viewer window" \
    [pcall {wviewer::current_token}] $tok
  check "MG1 omitted-token get uses the active window" \
    [pcall {wviewer::plot_mode}] single
  check "MG1 unknown token -> {} (no throw)" \
    [pcall {wviewer::plot_mode no/such/token}] {}

  # --- MG2: the config var seeds a NEW window only ---------------------------
  catch {wviewer::close $tok}; update
  set save_cfg2 $::wviewer_plot_mode
  set ::wviewer_plot_mode multi
  check "MG2 reopen returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG2 new window inherits the config var" [pcall {wviewer::plot_mode $tok}] multi
  set ::wviewer_plot_mode $save_cfg2
  check "MG2 changing the config var does NOT touch the open window" \
    [pcall {wviewer::plot_mode $tok}] multi

  # --- MG3: set/invert + replayable logging ----------------------------------
  # spy on the log seam (the slickprop::log_apply pattern)
  set ::wvm_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wvm_log $line }

  check "MG3 explicit set returns the resolved mode" \
    [pcall {wviewer::set_plot_mode single $tok}] single
  check "MG3 mode actually changed" [pcall {wviewer::plot_mode $tok}] single
  check "MG3 the change is logged replayably (resolved, explicit token)" \
    [lindex $::wvm_log end] "wviewer::set_plot_mode single $tok"
  set nlog [llength $::wvm_log]
  check "MG3 setting the SAME mode is a no-op" \
    [pcall {wviewer::set_plot_mode single $tok}] single
  check "MG3 no log line for a no-op" [llength $::wvm_log] $nlog
  check "MG3 invert flips it" [pcall {wviewer::set_plot_mode invert $tok}] multi
  check "MG3 invert logs the RESOLVED word, never 'invert'" \
    [lindex $::wvm_log end] "wviewer::set_plot_mode multi $tok"
  check "MG3 garbage is refused" [pcall {wviewer::set_plot_mode bogus $tok}] {}
  check "MG3 garbage left the mode alone" [pcall {wviewer::plot_mode $tok}] multi
  xschem new_schematic switch $vdrw
  check "MG3 omitted token targets the active window" \
    [pcall {wviewer::set_plot_mode single}] single

  # --- MG4: Options > Plot Mode menu -----------------------------------------
  set mb $vtop.wvmenubar
  set labels {}
  for {set i 0} {$i <= [$mb index end]} {incr i} {
    catch {lappend labels [$mb entrycget $i -label]}
  }
  check_true "MG4 menubar carries an Options cascade" \
    [expr {[lsearch -exact $labels Options] >= 0}]
  check_true "MG4 Plot Mode submenu exists" [winfo exists $mb.options.plotmode]
  # dynamic label: single -> offers Multi
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::plot_mode_menu_post $tok $mb.options.plotmode}
  check "MG4 label offers the OTHER mode (single -> Multi)" \
    [$mb.options.plotmode entrycget 0 -label] {Set Multi-plot Mode}
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::plot_mode_menu_post $tok $mb.options.plotmode}
  check "MG4 label flips with the mode (multi -> Single)" \
    [$mb.options.plotmode entrycget 0 -label] {Set Single-plot Mode}
  # invoking the entry performs the change AND logs it
  set nlog [llength $::wvm_log]
  $mb.options.plotmode invoke 0
  check "MG4 invoking the entry flips the mode" [pcall {wviewer::plot_mode $tok}] single
  check "MG4 the menu change is logged replayably" \
    [lindex $::wvm_log end] "wviewer::set_plot_mode single $tok"
  check_true "MG4 exactly one line logged per menu use" \
    [expr {[llength $::wvm_log] == $nlog + 1}]

  # --- MG5: single-plot landing ----------------------------------------------
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_target_strip 1 $tok}
  set errs [pcall {wviewer::plot_signals $tok {v(a) v(b) v(c)}}]
  check "MG5 no per-signal errors" $errs {}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5 single-plot created NO new strip" [llength $gs] 2
  check "MG5 all three traces landed in the target strip" \
    [llength [dict get [lindex $gs 1] traces]] 3
  check "MG5 the non-target strip is untouched" \
    [llength [dict get [lindex $gs 0] traces]] 0
  check "MG5 target strip unchanged by the plot" [pcall {wviewer::target_strip $tok}] 1
  # append, never replace (D1)
  pcall {wviewer::plot_signals $tok {v(d)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5 a second gesture APPENDS (never replaces)" \
    [llength [dict get [lindex $gs 1] traces]] 4

  # --- MG5b: single-plot never lands in the ASE auto-plot strip --------------
  # (the auto graph is rebuilt after every run — landing there loses the picks)
  wviewer::set_graphs $tok [list [dict merge [wviewer::empty_graph] {auto 1}]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  check "MG5b the only strip IS the auto strip" [pcall {wviewer::auto_graph_index $tok}] 0
  pcall {wviewer::plot_signals $tok {v(p) v(q)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5b a NEW strip was appended instead" [llength $gs] 2
  check "MG5b the auto strip is untouched" \
    [llength [dict get [lindex $gs 0] traces]] 0
  check "MG5b both signals landed in the new strip" \
    [llength [dict get [lindex $gs 1] traces]] 2
  check "MG5b the created strip became the target" [pcall {wviewer::target_strip $tok}] 1
  check "MG5b a follow-up gesture reuses it (no second strip)" \
    [llength [lindex [pcall {wviewer::plot_signals $tok {v(r)}}] 0]] 0
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG5b still exactly two strips" [llength $gs] 2
  check "MG5b follow-up appended into the same strip" \
    [llength [dict get [lindex $gs 1] traces]] 3

  # --- MG6: multi-plot landing -----------------------------------------------
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::add_trace $tok 0 {v(keep)}}
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  set errs [pcall {wviewer::plot_signals $tok {v(x) v(y)}}]
  check "MG6 no per-signal errors" $errs {}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG6 one NEW strip per signal, appended" [llength $gs] 4
  check "MG6 pre-existing strip 0 untouched" \
    [llength [dict get [lindex $gs 0] traces]] 1
  check "MG6 pre-existing strip 1 untouched" \
    [llength [dict get [lindex $gs 1] traces]] 0
  check "MG6 new strip 2 holds exactly one trace" \
    [llength [dict get [lindex $gs 2] traces]] 1
  check "MG6 new strip 3 holds exactly one trace" \
    [llength [dict get [lindex $gs 3] traces]] 1
  check "MG6 signal order preserved (strip 2 = first pick)" \
    [dict get [lindex [dict get [lindex $gs 2] traces] 0] expr] {v(x)}
  check "MG6 multi-plot does NOT move the target" [pcall {wviewer::target_strip $tok}] 0

  # --- MG7: click re-targets the strip ---------------------------------------
  check_true "MG7 <ButtonPress-1> is bound on the viewer canvas" \
    [expr {[string trim [bind $vdrw <ButtonPress-1>]] ne {}}]
  check_true "MG7 the click bind still forwards the press to the C engine" \
    [string match {*xschem callback*} [bind $vdrw <ButtonPress-1>]]
  check_true "MG7 the click bind calls the re-target seam" \
    [string match {*wviewer::click_target*} [bind $vdrw <ButtonPress-1>]]
  # 4 strips are up from MG6; band 2 spans the 3rd quarter of the canvas
  set H [winfo height $vdrw]
  set W [winfo width $vdrw]
  set y2 [expr {int($H * 5 / 8.0)}]     ;# inside band 2 of 4
  set y0 [expr {int($H * 1 / 8.0)}]     ;# inside band 0 of 4
  pcall {wviewer::click_target $vdrw [expr {$W/2}] $y2}
  check "MG7 clicking band 2 makes it the target" [pcall {wviewer::target_strip $tok}] 2
  pcall {wviewer::click_target $vdrw [expr {$W/2}] $y0}
  check "MG7 clicking band 0 moves the target back" [pcall {wviewer::target_strip $tok}] 0
  # the real Tk event, through the shipped binding
  event generate $vdrw <ButtonPress-1> -x [expr {$W/2}] -y $y2
  update
  check "MG7 a real ButtonPress-1 re-targets through the binding" \
    [pcall {wviewer::target_strip $tok}] 2
  event generate $vdrw <ButtonRelease-1> -x [expr {$W/2}] -y $y2
  update
  # target moves are replayable too
  set nlog [llength $::wvm_log]
  pcall {wviewer::set_target_strip 3 $tok}
  check "MG7 an explicit target move is logged" \
    [lindex $::wvm_log end] "wviewer::set_target_strip 3 $tok"
  pcall {wviewer::set_target_strip 3 $tok}
  check "MG7 no log line when the target does not move" \
    [llength $::wvm_log] [expr {$nlog + 1}]
  check "MG7 a stale target is clamped on read" \
    [pcall {wviewer::set_target_strip 99 $tok}] 3

  # --- MG7b: a re-target must NOT discard C-engine-written graph state --------
  # The C engine writes RMB box-zoom / graph-pan ranges STRAIGHT into the rect
  # prop; the Tcl model never sees them. Moving the marker by regenerate (which
  # re-places every rect from the model) would silently undo the zoom the user
  # just made with the mouse. Simulated here by writing the rect directly,
  # exactly as waves_callback does, then re-targeting.
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_target_strip 0 $tok}
  wviewer::with_edit $tok {
    xschem setprop -fast rect 2 0 x1 3
    xschem setprop -fast rect 2 0 x2 4
  }
  xschem new_schematic switch $vdrw
  check "MG7b engine-written range is on the rect" \
    [list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]] {3 4}
  pcall {wviewer::set_target_strip 1 $tok}
  xschem new_schematic switch $vdrw
  check "MG7b the re-target PRESERVED it (no model-only regenerate)" \
    [list [xschem getprop rect 2 0 x1] [xschem getprop rect 2 0 x2]] {3 4}
  check "MG7b the marker still moved to the new target" \
    [xschem getprop rect 2 1 active] 1
  check "MG7b the old target's marker token was cleared" \
    [xschem getprop rect 2 0 active] {}

  # --- MG8: the active-strip marker's prop token -----------------------------
  # owns its setup (no reliance on the layout an earlier phase happened to leave)
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph] \
                                 [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_target_strip 2 $tok}
  xschem new_schematic switch $vdrw
  check "MG8 four graph rects on the viewer canvas" [xschem get rects 2] 4
  check "MG8 only the TARGET rect carries active=1" \
    [xschem getprop rect 2 2 active] 1
  check "MG8 non-target rect 0 has no active token" [xschem getprop rect 2 0 active] {}
  check "MG8 non-target rect 1 has no active token" [xschem getprop rect 2 1 active] {}
  check "MG8 non-target rect 3 has no active token" [xschem getprop rect 2 3 active] {}
  check "MG8 redraw rc 0 with the marker present" [catch {xschem redraw}] 0
  check "MG8 viewer buffer still readonly after the marker write" \
    [xschem get readonly] 1
  check "MG8 viewer buffer still unmodified" [xschem get modified] 0
  # a single strip has nothing to disambiguate -> no marker at all
  wviewer::set_graphs $tok [list [wviewer::empty_graph]]
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "MG8 one strip -> exactly one rect" [xschem get rects 2] 1
  check "MG8 one strip -> NO marker token" [xschem getprop rect 2 0 active] {}

  # --- MG9: persistence round trip -------------------------------------------
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::set_target_strip 1 $tok}
  set snap [pcall {wviewer::snapshot $tok {}}]
  check "MG9 snapshot carries the mode" [pcall {dict get $snap mode}] multi
  check "MG9 snapshot carries the target" [pcall {dict get $snap target}] 1
  check "MG9 fixed build order keeps mode/target LAST" \
    [dict keys $snap] {open sharedx rawfile graphs mode target}
  # restore into a fresh window
  catch {wviewer::close $tok}; update
  check "MG9 restore returns 1" [pcall {wviewer::restore $tok $snap {} {}}] 1
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG9 mode restored (config default overridden)" [pcall {wviewer::plot_mode $tok}] multi
  check "MG9 target restored" [pcall {wviewer::target_strip $tok}] 1
  # a pre-0151 dict (no mode/target keys) must still load
  set old [dict create open 1 sharedx 0 rawfile {} graphs [list [wviewer::empty_graph]]]
  catch {wviewer::close $tok}; update
  check "MG9 pre-0151 dict still restores" [pcall {wviewer::restore $tok $old {} {}}] 1
  set vtop [wviewer::window_for $tok]; set vdrw $vtop.drw
  viewer_ready $vtop
  check "MG9 missing mode key falls back to the config default" \
    [pcall {wviewer::plot_mode $tok}] single
  check "MG9 missing target key falls back to 0" [pcall {wviewer::target_strip $tok}] 0

  # --- MG12: the REAL Direct Plot finish path honours the mode ----------------
  # (teeth for the ONE production wiring: ase::ui::dp_finish. Driving only
  # wviewer::plot_signals would leave the pre-0151 dp_finish body passing.)
  check "MG12 fixture plots as dc, so dp_finish does not abort on op" \
    [pcall {ase::plot_sim_type [ase::session_state $tok]}] dc
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode multi $tok}
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {ase::ui::dp_finish $tok {v(m1) v(m2)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG12 multi mode: dp_finish made ONE STRIP PER SIGNAL" [llength $gs] 4
  check "MG12 new strip 2 holds one trace" [llength [dict get [lindex $gs 2] traces]] 1
  check "MG12 new strip 3 holds one trace" [llength [dict get [lindex $gs 3] traces]] 1
  # same call, single mode -> everything into the target, no new strip
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
  wviewer::regenerate $tok
  pcall {wviewer::set_plot_mode single $tok}
  pcall {wviewer::set_target_strip 1 $tok}
  pcall {ase::ui::dp_finish $tok {v(s1) v(s2)}}
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "MG12 single mode: dp_finish created NO strip" [llength $gs] 2
  check "MG12 both signals landed in the target strip" \
    [llength [dict get [lindex $gs 1] traces]] 2
  check "MG12 the other strip stayed empty" \
    [llength [dict get [lindex $gs 0] traces]] 0
  check "MG12 an empty queue still creates nothing" \
    [llength [dict get [wviewer::layout_for $tok] graphs]] 2

  # --- MG13: the shipped chord SPELLING actually fires ------------------------
  # A physical Ctrl+Shift+4 arrives as keysym `dollar` on a US layout, so
  # <Control-Shift-Key-4> alone never matches (this is why cadence_style_rc
  # binds <Control-Key-at> for Ctrl-Shift-2). Bind the rc's own script shape on
  # a scratch widget and fire the real event — no rc sourcing, no C keybinding.
  set ::wvm_chord {}
  toplevel .wvmchord
  wm geometry .wvmchord 120x60+0+0
  bind .wvmchord <Control-Key-dollar>  {lappend ::wvm_chord dollar; break}
  bind .wvmchord <Control-Shift-Key-4> {lappend ::wvm_chord shift4; break}
  update
  focus -force .wvmchord
  event generate .wvmchord <KeyPress> -keysym 4 -state 5 -when now
  update
  check "MG13 Ctrl+Shift+4 resolves to the <Control-Key-dollar> form" \
    $::wvm_chord dollar
  destroy .wvmchord
  check_true "MG13 cadence_style_rc binds the form that actually fires" \
    [regexp {bind \.drw <Control-Key-dollar>\s+\{ase::plot_mode_for_current} \
       [read [set fh [open [file join $repo src cadence_style_rc] r]]][close $fh]]

  # --- MG10: schematic-side entry points --------------------------------------
  xschem load $schfile
  check "MG10 design is current" \
    [file tail [xschem get schname]] test_nfet_final.sch
  # session_for_design matches the STATE's `design` dict (view = schematic),
  # not the state view the session key is named after
  check "MG10 the design resolves to the bound session" \
    [pcall {ase::session_for_design sky130_tests test_nfet_final schematic}] $tok
  # flip the viewer's mode from the DESIGN window
  pcall {wviewer::set_plot_mode single $tok}
  check "MG10 chord proc returns the resolved mode" \
    [pcall {ase::plot_mode_for_current invert}] multi
  check "MG10 the VIEWER's mode changed" [pcall {wviewer::plot_mode $tok}] multi
  check "MG10 explicit mode word accepted" \
    [pcall {ase::plot_mode_for_current single}] single
  # no ASE-L window has been built for this session -> honest {}
  check "MG10 ASE window number is {} while no ASE window exists" \
    [pcall {ase::ui::number_for $tok}] {}
  check "MG10 window_number_for_current is honest about it" \
    [pcall {ase::window_number_for_current}] {}
  # ... and with a real ASE-L window it is the Cadence number of .aseN
  set asetop {}
  catch {ase::open_state sky130_tests test_nfet_final ngspice_state1}
  set asetop [ase::ui::window_for $tok]
  if {$asetop eq {} || ![winfo exists $asetop]} {
    puts "SKIPPED: MG10 ASE-window legs (session window never opened)"
  } else {
    update
    set n [pcall {ase::ui::number_for $tok}]
    check_true "MG10 ASE window number is an editor-range number (>=3)" \
      [expr {[string is integer -strict $n] && $n >= 3}]
    check "MG10 the number matches the .aseN toplevel path" $asetop ".ase$n"
    xschem load $schfile
    check "MG10 window_number_for_current returns the ASE-L number" \
      [pcall {ase::window_number_for_current}] $n
    catch {ase::ui::close $tok}
    update
  }
  # session bound, but the viewer WINDOW closed -> honest {} (the mode is
  # per-window state; there is nothing to flip until the window exists)
  xschem load $schfile
  catch {wviewer::close $tok}
  update
  check "MG10 viewer closed -> the chord proc reports {} and changes nothing" \
    [pcall {ase::plot_mode_for_current invert}] {}
  check "MG10 viewer closed -> plot_mode is {} too" [pcall {wviewer::plot_mode $tok}] {}
  # a RESOLVABLE design with NO session at all -> the no-session branch proper
  # (a design outside the registry would stop earlier, at the design gate, and
  # never reach it)
  ase::session_close $tok
  xschem load $schfile
  check "MG10 design still resolves after closing the session" \
    [pcall {ase::design_of_current}] {sky130_tests test_nfet_final schematic}
  check "MG10 no session bound -> {} from the chord proc" \
    [pcall {ase::plot_mode_for_current invert}] {}
  check "MG10 no session bound -> {} from the number query" \
    [pcall {ase::window_number_for_current}] {}
  # and a design the registry does not know at all: the design gate, still no throw
  xschem load [file join $repo xschem_library examples test_ne555.sch]
  check "MG10 unregistered design -> {} from the chord proc" \
    [pcall {ase::plot_mode_for_current invert}] {}
  check "MG10 unregistered design -> {} from the number query" \
    [pcall {ase::window_number_for_current}] {}

  # --- MG11: the shipped chord is bound --------------------------------------
  # (cadence_style_rc is not sourced by this test; assert the LINE exists so a
  # silent removal is caught, the same way the Ctrl-4 entry is documented)
  set rcf [file join $repo src cadence_style_rc]
  set fh [open $rcf r]; set rctext [read $fh]; close $fh
  check_true "MG11 Ctrl-Shift-4 is bound to the mode flip in cadence_style_rc" \
    [regexp {bind \.drw <Control-Shift-Key-4>.*ase::plot_mode_for_current} $rctext]

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  catch {wviewer::close $tok}
  update
  }
} else {
  puts "SKIPPED: MG* GUI legs (no usable DISPLAY)"
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
