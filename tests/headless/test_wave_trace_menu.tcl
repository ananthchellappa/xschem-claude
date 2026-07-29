# tests/headless/test_wave_trace_menu.tcl — ASE Waveform Viewer
# RMB context menu on a trace -> "Move to Separate Strip" (viewer plan item 7,
# doc/claude/suggestions/plan_viewer_enhancements_2026-07.md; contract in
# doc/claude/specs/waveform_viewer.md)
#
# The feature: a right-click that does NOT travel, on a trace inside the plot
# body of a strip that carries at least two drawn traces, posts a small menu.
# Its one command entry gives that trace a strip of its own, inserted directly
# below the source. One undo point, one log line, no add_graph.
#
# What is asserted here:
#   TP*  the PURE half, literal dicts, no window and no DISPLAY:
#        trace_label (the legend's own naming rule) and the
#        linsert + move_trace_in_graphs COMPOSITION that the command is built
#        out of — marker migration, the hilight_wave hand-off and the carried
#        trace dictionary, proved on lists rather than through a window
#   TN*  no-window legs: move_trace_to_new_strip and the menu gate never throw
#        when nothing resolves — unknown token, omitted token, foreign canvas
#   TG1  the move itself: profile, rect count, the new strip's position
#        (BELOW the source), modified still 0
#   TG2  the >= 2 drawn traces REFUSAL: no mutation, no undo point, no log line
#   TG3  markers and hilight_wave migrate through the REAL path (rect props),
#        not just through the pure list op
#   TG4  the stored TARGET becomes the new strip (the move_trace step-6 rule)
#   TG5  UNDO: exactly one `u` restores the pre-move model
#   TG6  replayable logging: exactly one fully-resolved line, and replaying it
#        reproduces the state; and the command takes exactly ONE regenerate and
#        never calls add_graph
#   TG7  the GATE (trace_menu_pick): a real trace pixel resolves to {gi ti};
#        empty waveform space and a one-trace strip refuse
#   TG8  the MENU widget: entries, the disabled header naming the picked trace,
#        and invoking the command entry performs the move
#   TG9  the GESTURE: a real no-travel <ButtonPress-3>/<ButtonRelease-3> pair
#        through the PRODUCTION bindings posts the menu
#   TG10 the gesture's three refusals: a travelled B3 (box zoom — which must
#        STILL zoom), a modified B3, and a release with no recorded press
#   TG11 no collateral damage: the B3 box zoom and the LMB wave-bold click are
#        unchanged by the new release arm
#
# NOT asserted (stated, not hidden): pixels. That the menu is legible and lands
# under the pointer is eyeball-only, like every other wave rendering. tk_popup
# is SPIED on rather than called for real in the gesture legs — a live popup
# takes a global grab that would swallow the events of every later leg.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_trace_menu.tcl
# (add --nogui to run only the TP*/TN* legs)

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
set scratch [test_scratch wvtracemenu]

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
# TP* — the PURE half. No window, no DISPLAY, literal dicts.
# ============================================================================

# --- trace_label: the legend's own naming rule ---
check "TP1 a distinct alias is what the legend shows" \
  [wviewer::trace_label [dict create vec {v(out)} name outp]] outp
check "TP2 an alias equal to the vector is not repeated" \
  [wviewer::trace_label [dict create vec vec_a name vec_a]] vec_a
check "TP3 no alias -> the vector" \
  [wviewer::trace_label [dict create vec vec_a name {}]] vec_a
check "TP4 a missing name key -> the vector" \
  [wviewer::trace_label [dict create vec vec_a]] vec_a
check "TP5 a trace that reaches no node slot has no label" \
  [wviewer::trace_label [dict create vec {} name {}]] {}
# teeth: the rule must really be graph_props', not "always the name"
check_true "TP6 the label rule matches graph_props' node token" \
  [expr {[string match {*outp;v(out)*} \
     [wviewer::graph_props [dict create traces \
        [list [dict create vec {v(out)} name outp color 4]]]]] &&
   [wviewer::trace_label [dict create vec {v(out)} name outp]] eq {outp}}]

# --- the COMPOSITION the command is built out of ---
# A source strip with three drawn traces, a bold trace and a marker; the new
# strip is a fresh empty_graph inserted directly below it.
proc tp_trace {v c} { return [dict create expr $v name {} vec $v color $c] }
set S [dict create traces [list [tp_trace va 4] [tp_trace vb 5] [tp_trace vc 6]] \
                   logx 0 logy 0 x1 0 x2 1 y1 0 y2 2 \
                   hilight_wave 1 markers "7 1 0 3 0.5 0.25 0 0 0"]
set gs0 [list $S]
check "TP7 the source strip carries three drawn traces" \
  [wviewer::node_count [lindex $gs0 0]] 3
set gs1 [linsert $gs0 1 [wviewer::empty_graph]]
check "TP8 the insert goes BELOW the source and leaves its index alone" \
  [list [llength $gs1] [wviewer::node_count [lindex $gs1 0]] \
        [wviewer::node_count [lindex $gs1 1]]] {2 3 0}
set gs2 [wviewer::move_trace_in_graphs $gs1 0 1 1]
proc tp_vecs {G} {
  set out {}
  foreach tr [wviewer::dget $G traces {}] { lappend out [wviewer::dget $tr vec {}] }
  return $out
}
check "TP9 the moved trace left the source, in order" \
  [tp_vecs [lindex $gs2 0]] {va vc}
check "TP10 and landed alone in the new strip" [tp_vecs [lindex $gs2 1]] {vb}
check "TP11 the trace DICTIONARY is carried whole (colour rides along)" \
  [wviewer::dget [lindex [wviewer::dget [lindex $gs2 1] traces {}] 0] color {}] 5
# the bold trace WAS the one that moved -> the source loses its highlight and
# the destination picks it up at its new node index (0)
check "TP12 the source dropped its hilight_wave key entirely" \
  [dict exists [lindex $gs2 0] hilight_wave] 0
check "TP13 the destination picked the bold up at node 0" \
  [wviewer::dget [lindex $gs2 1] hilight_wave {}] 0
# the marker sat on the moved trace -> it MIGRATES, with its wave field
# rewritten into the destination's node index space
check "TP14 the source has no markers left" \
  [dict exists [lindex $gs2 0] markers] 0
check "TP15 the marker migrated with its trace, wave field remapped to 0" \
  [wviewer::dget [lindex $gs2 1] markers {}] {7 0 0 3 0.5 0.25 0 0 0}
# a bold that did NOT move must be renumbered, not handed over
set S2 [dict replace $S hilight_wave 2]
set gs3 [wviewer::move_trace_in_graphs [linsert [list $S2] 1 [wviewer::empty_graph]] 0 1 1]
check "TP16 a bold trace ABOVE the moved one shifts down by one" \
  [wviewer::dget [lindex $gs3 0] hilight_wave {}] 1
check "TP17 and the destination does NOT inherit it" \
  [dict exists [lindex $gs3 1] hilight_wave] 0
# the fresh strip's ranges stay blank, which is what makes regenerate autozoom
# it around whatever landed there
check "TP18 the new strip's ranges are blank (regenerate re-autozooms them)" \
  [list [wviewer::dget [lindex $gs2 1] x1 {}] [wviewer::dget [lindex $gs2 1] x2 {}] \
        [wviewer::dget [lindex $gs2 1] y1 {}] [wviewer::dget [lindex $gs2 1] y2 {}]] {{} {} {} {}}
check "TP19 the SOURCE keeps its own ranges" \
  [list [wviewer::dget [lindex $gs2 0] x1 {}] [wviewer::dget [lindex $gs2 0] x2 {}]] {0 1}
# teeth: without the insert the pure move is a no-op (from_gi == to_gi), so the
# insert is load-bearing rather than decorative
check "TP20 without the inserted strip the pure move refuses (from == to)" \
  [tp_vecs [lindex [wviewer::move_trace_in_graphs $gs0 0 1 0] 0]] {va vb vc}

# --- NODE index space vs MODEL index space -----------------------------------
# The C engine counts only traces that reach the `node` prop token; a trace with
# an empty `vec` occupies a MODEL slot and no node slot. Every leg above used
# traces where the two spaces coincide, which is exactly how a mapping bug hides.
set SX [dict create traces [list [tp_trace va 4] [dict create expr {} name {} vec {} color 7] \
                                 [tp_trace vb 5]] \
                    logx 0 logy 0 x1 0 x2 1 y1 0 y2 2]
check "TP21 three model traces, two node slots" \
  [list [llength [dict get $SX traces]] [wviewer::node_count $SX]] {3 2}
check "TP22 node 1 is MODEL index 2 (the spaces have diverged)" \
  [wviewer::trace_index_of_node $SX 1] 2
check "TP23 the gate still sees two drawn traces, so it must offer the menu" \
  [expr {[wviewer::node_count $SX] >= 2}] 1
set gsx [wviewer::move_trace_in_graphs [linsert [list $SX] 1 [wviewer::empty_graph]] 0 2 1]
check "TP24 moving MODEL index 2 leaves the vec-less trace behind" \
  [tp_vecs [lindex $gsx 0]] {va {}}
check "TP25 and moves the right trace" [tp_vecs [lindex $gsx 1]] {vb}

# --- the b3 click tolerance is the C engine's number ---
# ⚠ ZERO, deliberately — NOT GRAPH_CLICK_TOL. The engine's Button-3 box-zoom
# gate is exact equality on the raw pointer (graph interaction disables the snap
# grid), so a release one pixel from its press has already zoomed. TG10 drives
# that end to end; this leg pins the constant so a "tidy up to 3" cannot land
# silently.
check "TP26 the B3 click tolerance is ZERO (menu and box zoom are exclusive)" \
  [wviewer::b3_click_tol] 0
check "TP27 no recorded press -> no marker arm (fails closed)" \
  [wviewer::b3_marker_armed .no/such/canvas] 0

# ============================================================================
# TN* — no window needed
# ============================================================================
check "TN1 unknown token -> {} (no throw)" \
  [pcall {wviewer::move_trace_to_new_strip 0 0 no/such/token}] {}
check "TN2 omitted token with no viewer -> {} (no throw)" \
  [pcall {wviewer::move_trace_to_new_strip 0 0}] {}
check "TN3 a non-integer strip index -> {} (no throw)" \
  [pcall {wviewer::move_trace_to_new_strip x 0 no/such/token}] {}
check "TN4 the gate on a non-viewer canvas -> {-1 -1} (no throw)" \
  [pcall {wviewer::trace_menu_pick .drw 10 10}] {-1 -1}
check "TN5 posting on a non-viewer canvas -> 0 (no throw)" \
  [pcall {wviewer::trace_menu_post .drw 10 10}] 0
check "TN6 unposting an unknown token -> 0 (no throw)" \
  [pcall {wviewer::trace_menu_unpost no/such/token}] 0
check "TN7 building a menu for an unknown token -> {} (no throw)" \
  [pcall {wviewer::trace_menu_build no/such/token 0 0}] {}

# ============================================================================
# TG* — GUI legs (self-SKIP without a usable DISPLAY)
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

  proc ngraphs {tok} { llength [dict get [wviewer::layout_for $tok] graphs] }
  # the trace-count PROFILE of the whole stack — one comparison that says which
  # strip holds what
  proc profile {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [llength [wviewer::dget $G traces {}]]
    }
    return $out
  }
  proc vecs_at {tok gi} {
    set gs [dict get [wviewer::layout_for $tok] graphs]
    if {$gi < 0 || $gi >= [llength $gs]} { return {} }
    set out {}
    foreach tr [wviewer::dget [lindex $gs $gi] traces {}] {
      lappend out [wviewer::dget $tr vec {}]
    }
    return $out
  }

  # Every synthetic event carries an explicitly INCREASING %t (the wb_ev
  # precedent in test_wave_viewer.tcl): without it Tk collapses two presses that
  # fall inside its double-click window into <Double-Button-3>, which the viewer
  # binds to {break} — and the second press then vanishes entirely.
  set ::tmt 100000
  proc tm_ev {w seq args} {
    set ::tmt [expr {$::tmt + 1000}]
    eval [list event generate $w $seq -time $::tmt] $args
  }

  # 2 strips: three traces on strip 0 (the menu case), ONE on strip 1 (the
  # refusal case). Distinct offsets so the three traces do not overlap and the
  # engine's hit test can tell them apart.
  proc fill_viewer {tok} {
    wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
    foreach {gi vec} {0 vec_a 0 vec_b 0 vec_c 1 vec_d} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  fill_viewer: add_trace $vec -> $e" }
    }
    wviewer::regenerate $tok
    wviewer::fit $tok
    wviewer::set_target_strip 0 $tok
  }

  # A canvas pixel that the ENGINE agrees sits on a trace of strip `gi`, as
  # {px py ni}, or {} when the geometry never puts one there (WSLg can hand back
  # a window too small to plot in — that is a SKIP, not a failure).
  proc find_trace_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60 0.30 0.70} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 2} {
        set ni [wviewer::trace_at $vdrw $gi $px $py]
        if {$ni >= 0} { return [list $px $py $ni] }
      }
    }
    return {}
  }
  # ... and one the engine says holds NO trace, for the refusal legs
  proc find_empty_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 2} {
        if {[wviewer::strip_at_pixel $vdrw $px $py] != $gi} { continue }
        if {[wviewer::trace_at $vdrw $gi $px $py] < 0} { return [list $px $py] }
      }
    }
    return {}
  }

  # session registration (headless-style: no ASE window needed for the viewer)
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "TG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: TG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  # spy on the replayable-log seam (the slickprop::log_apply pattern)
  set ::tm_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::tm_log $line }

  # a raw dataset attached to the viewer ctx — synthetic, hermetic (no ngspice,
  # no .raw file). add_trace VALIDATES against the loaded raw's variable list,
  # so a fixture built from names the raw does not know would silently record
  # nothing and every leg below would pass against a model where NO strip had
  # traces (green-but-hollow).
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvtm.raw dc vsweep 0 1.0 0.02}
  foreach {v ex} {vec_a {vsweep 1 +} vec_b {vsweep 3 +} vec_c {vsweep 5 +}
                  vec_d {vsweep 7 +}} {
    pcall {xschem raw add $v $ex}
  }
  set rawvars [split [pcall {xschem raw list}] "\n"]
  check_true "TG0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $rawvars vec_a] >= 0 && [lsearch -exact $rawvars vec_d] >= 0}]

  # --- TG1: the move itself --------------------------------------------------
  fill_viewer $tok
  check "TG1 fixture: three traces on strip 0, one on strip 1" [profile $tok] {3 1}
  xschem new_schematic switch $vdrw
  check "TG1 fixture placed 2 graph rects" [xschem get rects 2] 2
  check "TG1 move_trace_to_new_strip returns the NEW strip's index" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  check "TG1 the new strip went directly BELOW the source" [profile $tok] {2 1 1}
  check "TG1 the moved trace is the one that was asked for" [vecs_at $tok 1] vec_b
  check "TG1 the source kept the other two, in order" [vecs_at $tok 0] {vec_a vec_c}
  check "TG1 the strip that was below is still below" [vecs_at $tok 2] vec_d
  xschem new_schematic switch $vdrw
  check "TG1 the canvas rect count agrees with the model" [xschem get rects 2] 3
  check "TG1 all three are still graphs" \
    [list [xschem getprop rect 2 0 flags] [xschem getprop rect 2 1 flags] \
          [xschem getprop rect 2 2 flags]] {graph graph graph}
  check "TG1 buffer NOT left modified (read-only viewer discipline)" \
    [xschem get modified] 0
  check "TG1 the new strip really carries the trace in its rect" \
    [string match {*vec_b*} [xschem getprop rect 2 1 node]] 1
  check "TG1 and the source rect no longer does" \
    [string match {*vec_b*} [xschem getprop rect 2 0 node]] 0

  # --- TG2: the >= 2 drawn traces refusal ------------------------------------
  fill_viewer $tok
  set nlog [llength $::tm_log]
  lassign [wviewer::history_depth $tok] u0 r0
  check "TG2 a strip with ONE drawn trace refuses" \
    [pcall {wviewer::move_trace_to_new_strip 1 0 $tok}] {}
  check "TG2 the refusal mutated nothing" [profile $tok] {3 1}
  check "TG2 the refusal logged nothing (a replay must not re-run it)" \
    [expr {[llength $::tm_log] - $nlog}] 0
  lassign [wviewer::history_depth $tok] u1 r1
  check "TG2 the refusal took NO undo point" [expr {$u1 - $u0}] 0
  check "TG2 a bad trace index refuses too" \
    [pcall {wviewer::move_trace_to_new_strip 0 9 $tok}] {}
  check "TG2 a bad strip index refuses too" \
    [pcall {wviewer::move_trace_to_new_strip 9 0 $tok}] {}
  check "TG2 still nothing mutated" [profile $tok] {3 1}
  # teeth: the SAME strip becomes eligible once it has a second drawn trace, so
  # the refusal is about the count and not about the strip
  pcall {wviewer::add_trace $tok 1 vec_a}
  check "TG2 the same strip is accepted once it holds two" \
    [pcall {wviewer::move_trace_to_new_strip 1 0 $tok}] 2

  # --- TG3: markers and the bold trace, through the REAL path ----------------
  fill_viewer $tok
  set gs [dict get [wviewer::layout_for $tok] graphs]
  # A record is `num wave dset point x y prev ldx ldy` and markers_line_fields
  # REFUSES anything shorter than 9 fields, so a short fixture reads as "no
  # markers at all" and the migration legs would pass vacuously.
  # marker 3 sits on NODE 1 of strip 0 — the trace about to move.
  set gs [lreplace $gs 0 0 [dict replace [lindex $gs 0] \
            markers {3 1 0 5 0.5 0.5 0 0 0} hilight_wave 1]]
  wviewer::set_graphs $tok $gs
  # REGENERATE, or the fixture is a lie: the command runs
  # capture_live_graph_state, which re-reads `markers`/`hilight_wave` FROM THE
  # RECT PROPS and overwrites the model with what it finds.
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "TG3 fixture: the marker really reached the rect" \
    [xschem getprop rect 2 0 markers] {3 1 0 5 0.5 0.5 0 0 0}
  check "TG3 fixture: the bold really reached the rect" \
    [xschem getprop rect 2 0 hilight_wave] 1
  check "TG3 the move happened" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "TG3 the marker migrated to the new strip, remapped to node 0" \
    [wviewer::dget [lindex $gs 1] markers {}] {3 0 0 5 0.5 0.5 0 0 0}
  check "TG3 the source has no marker left" \
    [dict exists [lindex $gs 0] markers] 0
  check "TG3 the bold went with its trace" \
    [wviewer::dget [lindex $gs 1] hilight_wave {}] 0
  check "TG3 the source dropped its bold" \
    [dict exists [lindex $gs 0] hilight_wave] 0
  xschem new_schematic switch $vdrw
  check "TG3 and the migration reached the new strip's RECT" \
    [xschem getprop rect 2 1 markers] {3 0 0 5 0.5 0.5 0 0 0}

  # --- TG4: the stored target becomes the new strip --------------------------
  #
  # ⚠ EASY TO WRITE HOLLOW. `target_index` CLAMPS every read to the live strip
  # count, so on a shallow stack "the target is the new strip" is also what a
  # command that never touched the target would answer. The fixture below is
  # built so the two answers DIFFER: the target starts on strip 4 of 5, the
  # source is strip 1, and the new strip lands at 2 — an untouched target would
  # read back as 4 (the clamp allows it: the stack grew to 6).
  proc fill_deep {tok} {
    set gs {}
    for {set i 0} {$i < 5} {incr i} { lappend gs [wviewer::empty_graph] }
    wviewer::set_graphs $tok $gs
    foreach {gi vec} {0 vec_a 1 vec_a 1 vec_b 1 vec_c 2 vec_d 3 vec_a 4 vec_b} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  fill_deep: add_trace $vec -> $e" }
    }
    wviewer::regenerate $tok
    wviewer::fit $tok
  }
  fill_deep $tok
  check "TG4 fixture profile (the source, strip 1, uniquely holds 3)" \
    [profile $tok] {1 3 1 1 1}
  pcall {wviewer::set_target_strip 4 $tok}
  check "TG4 fixture target is strip 4" [pcall {wviewer::target_strip $tok}] 4
  check "TG4 the move lands the new strip at index 2" \
    [pcall {wviewer::move_trace_to_new_strip 1 1 $tok}] 2
  check "TG4 the NEW strip is the target (the move_trace step-6 rule)" \
    [pcall {wviewer::target_strip $tok}] 2
  check "TG4 and index 2 really is the new strip (identity, not arithmetic)" \
    [vecs_at $tok 2] vec_b
  # teeth: an untouched target would have clamped to 4 on the six-strip stack,
  # so this pair really does exercise the target write
  check_true "TG4 the clamp alone would have given a DIFFERENT answer" \
    [expr {[wviewer::target_clamp 4 [ngraphs $tok]] != 2}]
  check_true "TG4 the target is inside the live stack" \
    [expr {[pcall {wviewer::target_strip $tok}] < [ngraphs $tok]}]
  # and the strips below the insert really did slide down by one
  check "TG4 the stack below the insert slid down by one" \
    [list [vecs_at $tok 3] [vecs_at $tok 5]] {vec_d vec_b}

  # --- TG5: one undo point per gesture ---------------------------------------
  fill_viewer $tok
  set before [profile $tok]
  pcall {wviewer::move_trace_to_new_strip 0 0 $tok}
  check "TG5 the move happened" [profile $tok] {2 1 1}
  check_true "TG5 one undo restores the model" \
    [expr {[pcall {wviewer::undo $tok}] ne {ERR}}]
  check "TG5 the model is back to the pre-move profile" [profile $tok] $before
  check "TG5 the undo was ONE step, not two" [ngraphs $tok] 2
  check "TG5 the traces came back to the strip they left" \
    [vecs_at $tok 0] {vec_a vec_b vec_c}

  # --- TG6: logging, one regenerate, and NO add_graph -------------------------
  fill_viewer $tok
  set nlog [llength $::tm_log]
  # spies: add_graph would regenerate mid-operation and take neither an undo
  # point nor a log line, which is exactly why this command must not use it
  set ::tm_addgraph 0
  set ::tm_regen 0
  rename wviewer::add_graph wviewer::__real_add_graph
  proc wviewer::add_graph {token} { incr ::tm_addgraph; return 0 }
  rename wviewer::regenerate wviewer::__real_regenerate
  proc wviewer::regenerate {token} {
    incr ::tm_regen
    return [wviewer::__real_regenerate $token]
  }
  check "TG6 the move happened" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  rename wviewer::add_graph {}
  rename wviewer::__real_add_graph wviewer::add_graph
  rename wviewer::regenerate {}
  rename wviewer::__real_regenerate wviewer::regenerate
  check "TG6 add_graph was NOT used to create the strip" $::tm_addgraph 0
  check "TG6 exactly ONE regenerate for the whole gesture" $::tm_regen 1
  check "TG6 exactly one line logged" [expr {[llength $::tm_log] - $nlog}] 1
  check "TG6 the line is replayable, with the EXPLICIT token" \
    [lindex $::tm_log end] "wviewer::move_trace_to_new_strip 0 1 $tok"
  # hold the line BEFORE rebuilding: fill_viewer's own set_target_strip logs, so
  # `[lindex $::tm_log end]` would no longer be the move (it was not, first time
  # round, and the replay leg passed a set_target_strip off as a move)
  set replay [lindex $::tm_log end]
  fill_viewer $tok
  pcall {uplevel #0 $replay}
  check "TG6 replaying the logged line reproduces the state" [profile $tok] {2 1 1}
  check "TG6 and the same trace moved" [vecs_at $tok 1] vec_b
  # the omitted-token form works on the active window
  fill_viewer $tok
  xschem new_schematic switch $vdrw
  check "TG6 omitted token targets the active viewer" \
    [pcall {wviewer::move_trace_to_new_strip 0 0}] 1
  check "TG6 omitted-token call did the work" [profile $tok] {2 1 1}

  # --- TG7: the GATE ---------------------------------------------------------
  fill_viewer $tok
  set hit [find_trace_px $vdrw 0]
  if {![llength $hit]} {
    puts "SKIPPED: TG7-TG11 (no pixel on a trace — window too small to plot in)"
  } else {
    lassign $hit tpx tpy tni
    check_true "TG7 the engine answers a NODE index at the probe pixel" \
      [expr {$tni >= 0 && $tni <= 2}]
    set pick [pcall {wviewer::trace_menu_pick $vdrw $tpx $tpy}]
    check "TG7 the gate resolves the click to {strip trace}" \
      $pick [list 0 [wviewer::trace_index_of_node \
                       [lindex [dict get [wviewer::layout_for $tok] graphs] 0] $tni]]
    # empty waveform space is NOT this menu's (it is item 8's)
    set miss [find_empty_px $vdrw 0]
    if {[llength $miss]} {
      check "TG7 empty waveform space refuses" \
        [pcall {wviewer::trace_menu_pick $vdrw [lindex $miss 0] [lindex $miss 1]}] \
        {-1 -1}
    } else {
      puts "SKIPPED: TG7 empty-space leg (every pixel of strip 0 is near a trace)"
    }
    # a one-trace strip refuses, at the gate as well as at the command
    set hit1 [find_trace_px $vdrw 1]
    if {[llength $hit1]} {
      check "TG7 a strip with one drawn trace refuses at the gate" \
        [pcall {wviewer::trace_menu_pick $vdrw [lindex $hit1 0] [lindex $hit1 1]}] \
        {-1 -1}
    } else {
      puts "SKIPPED: TG7 one-trace-strip leg (no pixel on strip 1's trace)"
    }
    # off every strip
    check "TG7 a pixel outside every band refuses" \
      [pcall {wviewer::trace_menu_pick $vdrw -50 -50}] {-1 -1}

    # --- TG8: the MENU widget ------------------------------------------------
    fill_viewer $tok
    lassign [pcall {wviewer::trace_menu_pick $vdrw $tpx $tpy}] mgi mti
    set m [pcall {wviewer::trace_menu_build $tok $mgi $mti}]
    check "TG8 the menu is a child of the viewer TOPLEVEL, not the canvas" \
      $m $vtop.wvtracemenu
    check_true "TG8 the widget exists" [expr {[winfo exists $m]}]
    check "TG8 it is not tearable off" [$m cget -tearoff] 0
    check "TG8 entry 0 is a disabled header naming the picked trace" \
      [list [$m entrycget 0 -label] [$m entrycget 0 -state]] \
      [list [wviewer::trace_label [lindex [wviewer::dget \
              [lindex [dict get [wviewer::layout_for $tok] graphs] $mgi] traces {}] $mti]] \
            disabled]
    check "TG8 entry 1 is the separator" [$m type 1] separator
    check "TG8 entry 2 is the command" \
      [list [$m type 2] [$m entrycget 2 -label]] {command {Move to Separate Strip}}
    check "TG8 the command is fully resolved (indices + explicit token)" \
      [$m entrycget 2 -command] \
      "wviewer::move_trace_to_new_strip $mgi $mti $tok"
    set nbefore [ngraphs $tok]
    $m invoke 2
    check "TG8 invoking the entry performs the move" [ngraphs $tok] [expr {$nbefore + 1}]
    check "TG8 the picked trace is alone in the new strip" \
      [llength [vecs_at $tok [expr {$mgi + 1}]]] 1
    check "TG8 unposting removes the widget" [pcall {wviewer::trace_menu_unpost $tok}] 1
    check "TG8 unposting again is a no-op" [pcall {wviewer::trace_menu_unpost $tok}] 0

    # --- TG9/TG10/TG11: the GESTURE ------------------------------------------
    # tk_popup is SPIED, never called: a real popup takes a global grab that
    # would swallow every later leg's events. The spy still proves the whole
    # production path ran, because trace_menu_post only reaches it after the
    # gate has resolved a trace and the menu has been built.
    rename ::tk_popup ::__tm_real_tk_popup
    proc ::tk_popup {m x y args} { set ::tm_popped [list $m $x $y] }

    fill_viewer $tok
    set ::tm_popped {}
    tm_ev $vdrw <ButtonPress-3>   -x $tpx -y $tpy
    tm_ev $vdrw <ButtonRelease-3> -x $tpx -y $tpy -state 0x400
    update
    check_true "TG9 a no-travel RMB click posts the menu" \
      [expr {[llength $::tm_popped] == 3}]
    check "TG9 the posted widget is the viewer's trace menu" \
      [lindex $::tm_popped 0] $vtop.wvtracemenu
    check_true "TG9 it was posted in ROOT coordinates (the event's %X/%Y)" \
      [expr {[lindex $::tm_popped 1] >= [winfo rootx $vdrw] &&
             [lindex $::tm_popped 2] >= [winfo rooty $vdrw]}]
    check "TG9 the click itself mutated nothing (the MENU is the mutation)" \
      [profile $tok] {3 1}
    xschem new_schematic switch $vdrw
    check "TG9 and the buffer is still unmodified" [xschem get modified] 0
    catch {wviewer::trace_menu_unpost $tok}

    # ⚠ A ONE-PIXEL WOBBLE IS NOT A CLICK, and this is the leg that says why.
    # The engine's box-zoom gate is exact equality on the RAW pointer (graph
    # interaction disables the snap grid, callback.c ~810/~1871), so a release
    # one pixel from its press has ALREADY zoomed by the time the gate runs.
    # Menu and zoom must be mutually exclusive; the tolerance is 0 for that
    # reason and not because 0 is tidy. The second assertion is the teeth: it
    # proves the zoom really did happen, so this cannot pass by the gesture
    # silently dying.
    wviewer::fit $tok
    xschem new_schematic switch $vdrw
    set wx1 [xschem getprop rect 2 0 x1]
    set wx2 [xschem getprop rect 2 0 x2]
    set ::tm_popped {}
    tm_ev $vdrw <ButtonPress-3>   -x $tpx -y $tpy
    tm_ev $vdrw <ButtonRelease-3> -x [expr {$tpx + 1}] -y $tpy -state 0x400
    update
    check "TG10 a ONE-pixel wobble is not a click (the engine zoomed instead)" \
      [llength $::tm_popped] 0
    xschem new_schematic switch $vdrw
    check_true "TG10 ... and the engine really did commit that zoom" \
      [expr {([xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]) <
             ($wx2 - $wx1) - 1e-9}]
    check "TG10 the tolerance is ZERO, not GRAPH_CLICK_TOL" \
      [wviewer::b3_click_tol] 0
    catch {wviewer::trace_menu_unpost $tok}
    wviewer::fit $tok

    # TG10a: a TRAVELLED B3 is a box zoom, not a menu — and it must still zoom
    wviewer::fit $tok
    xschem new_schematic switch $vdrw
    set zx1 [xschem getprop rect 2 0 x1]
    set zx2 [xschem getprop rect 2 0 x2]
    set ::tm_popped {}
    set W [winfo width $vdrw]
    tm_ev $vdrw <ButtonPress-3>   -x [expr {int(0.30 * $W)}] -y $tpy
    tm_ev $vdrw <ButtonRelease-3> -x [expr {int(0.70 * $W)}] -y $tpy -state 0x400
    update
    check "TG10 a travelled RMB drag posts NO menu" [llength $::tm_popped] 0
    xschem new_schematic switch $vdrw
    check_true "TG10 and the box zoom still happened (x-span narrowed)" \
      [expr {([xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]) <
             ($zx2 - $zx1) - 1e-9}]

    # TG10b: a MODIFIED RMB belongs to whatever else claims it
    wviewer::fit $tok
    set ::tm_popped {}
    tm_ev $vdrw <ButtonPress-3>   -x $tpx -y $tpy -state 4
    tm_ev $vdrw <ButtonRelease-3> -x $tpx -y $tpy -state 0x404
    update
    check "TG10 a Control-modified RMB click posts no menu" [llength $::tm_popped] 0

    # TG10c: a release with no recorded press (a replayed lone event, or a
    # button that went down on another widget) can never be read as a click
    set ::tm_popped {}
    wviewer::btn3_filter $vdrw 5 $tpx $tpy 3 0x400
    update
    check "TG10 a lone ButtonRelease-3 posts no menu" [llength $::tm_popped] 0
    # ... and the press state really is dropped on the release, not left behind
    wviewer::btn3_filter $vdrw 4 $tpx $tpy 3 0
    check_true "TG10 the press records its pixel" \
      [expr {[info exists ::wviewer::b3x0($vdrw)]}]
    wviewer::btn3_filter $vdrw 5 $tpx $tpy 3 0x400
    check "TG10 the release drops it again" \
      [info exists ::wviewer::b3x0($vdrw)] 0
    # ... which is also what makes the SECOND release of a double-RMB inert:
    # <Double-Button-3> is {break}, so the second PRESS never reaches the filter
    # and the second release finds no record
    set ::tm_popped {}
    tm_ev $vdrw <ButtonPress-3>   -x $tpx -y $tpy
    tm_ev $vdrw <ButtonRelease-3> -x $tpx -y $tpy -state 0x400
    update
    check_true "TG10 the first click of a double-RMB posts" \
      [expr {[llength $::tm_popped] == 3}]
    catch {wviewer::trace_menu_unpost $tok}
    set ::tm_popped {}
    tm_ev $vdrw <ButtonRelease-3> -x $tpx -y $tpy -state 0x400
    update
    check "TG10 a second release with no press of its own posts nothing" \
      [llength $::tm_popped] 0

    # TG10d: a press that landed while a MARKER drag was armed keeps the whole
    # gesture — the release ABORTS that drag (callback.c ~866) and a menu there
    # would be a side effect of cancelling something else. The arm can only be
    # seen on the press, so btn3_filter records it; this drives that seam.
    check "TG10 the arm record fails closed when there is no press" \
      [pcall {wviewer::b3_marker_armed $vdrw}] 0
    # The press must READ marker_grabbed, not merely store a zero — a version
    # that stored a constant 0 passed every other leg here (sabotage-verified),
    # so the engine query is spied rather than the array poked.
    rename wviewer::marker_grabbed wviewer::__tm_real_marker_grabbed
    proc wviewer::marker_grabbed {wp} { return 1 }
    set ::tm_popped {}
    wviewer::btn3_filter $vdrw 4 $tpx $tpy 3 0
    check "TG10 the press records what marker_grabbed answered" \
      [pcall {wviewer::b3_marker_armed $vdrw}] 1
    wviewer::btn3_filter $vdrw 5 $tpx $tpy 3 0x400
    check "TG10 a press made while a marker drag was armed posts no menu" \
      [llength $::tm_popped] 0
    check "TG10 and the arm record is dropped with the rest" \
      [info exists ::wviewer::b3mk($vdrw)] 0
    rename wviewer::marker_grabbed {}
    rename wviewer::__tm_real_marker_grabbed wviewer::marker_grabbed
    # with the real query back, an ordinary press records "not armed" and the
    # click posts again — the teeth that stop the spy leg above from passing
    # against a filter that refuses everything
    set ::tm_popped {}
    tm_ev $vdrw <ButtonPress-3>   -x $tpx -y $tpy
    tm_ev $vdrw <ButtonRelease-3> -x $tpx -y $tpy -state 0x400
    update
    check_true "TG10 an unarmed press still posts" \
      [expr {[llength $::tm_popped] == 3}]
    catch {wviewer::trace_menu_unpost $tok}

    # TG11: no collateral damage — the LMB wave-bold click is untouched
    fill_viewer $tok
    wviewer::with_edit $tok {xschem setprop rect 2 0 hilight_wave -1}
    tm_ev $vdrw <ButtonPress-1>   -x $tpx -y $tpy
    tm_ev $vdrw <ButtonRelease-1> -x $tpx -y $tpy -state 0x100
    update
    xschem new_schematic switch $vdrw
    check_true "TG11 the LMB wave-bold click still bolds a trace" \
      [expr {[xschem getprop rect 2 0 hilight_wave] >= 0}]
    # and the RMB click still does NOT bold (issue 0152 stays fixed)
    wviewer::with_edit $tok {xschem setprop rect 2 0 hilight_wave -1}
    set ::tm_popped {}
    tm_ev $vdrw <ButtonPress-3>   -x $tpx -y $tpy
    tm_ev $vdrw <ButtonRelease-3> -x $tpx -y $tpy -state 0x400
    update
    xschem new_schematic switch $vdrw
    check "TG11 the RMB click still leaves the bold alone (issue 0152)" \
      [xschem getprop rect 2 0 hilight_wave] -1
    catch {wviewer::trace_menu_unpost $tok}

    rename ::tk_popup {}
    rename ::__tm_real_tk_popup ::tk_popup

    # TG11b: the BINDING seam — both B3 arms carry the root coordinates the
    # popup needs, and the six-argument call shape still works (test_wave_viewer
    # drives btn3_filter directly with it).
    wviewer::strip_bindings $vdrw
    check_true "TG11 the press binding forwards %X/%Y" \
      [string match {*btn3_filter %W %T %x %y 3 %s %X %Y*} \
        [bind $vdrw <ButtonPress-3>]]
    check_true "TG11 the release binding forwards %X/%Y" \
      [string match {*btn3_filter %W %T %x %y 3 %s %X %Y*} \
        [bind $vdrw <ButtonRelease-3>]]
    check "TG11 the six-argument call shape still works" \
      [pcall {wviewer::btn3_filter $vdrw 4 $tpx $tpy 3 0}] {}
    catch {unset ::wviewer::b3x0($vdrw)}
    catch {unset ::wviewer::b3y0($vdrw)}
    catch {unset ::wviewer::b3mk($vdrw)}
  }

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: TG* GUI legs (no DISPLAY)"
}

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_trace_menu: $npass passed, $fail failed"
# The exact wording matters: run_suites.sh (and full_audit.sh) classify a run by
# grepping the last RESULT line for `ALL PASS`, and exit 0/1 is what a bare
# invocation is judged by. A suite that says "RESULT: PASS" is reported as FAIL
# by the harness while printing PASS itself.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
