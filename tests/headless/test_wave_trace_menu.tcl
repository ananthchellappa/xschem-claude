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
#   TB*  (issue 0174) the LMB wave-bold pick is PRECISE and PER-TRACE. This file
#        owns graph_trace_at-gated picking and is the only suite with a LIVE
#        multi-trace strip, so the two defects that need one live here:
#        TB-far  a click more than the pick tolerance from every trace selects
#                NOTHING (with teeth: a huge tol at the same pixel still hits,
#                so -1 means "far", not "no data") — defect (a);
#        TB-move a click on trace B while trace A is selected MOVES the
#                selection, in ONE click with nothing in between — defect (b);
#        TB-same re-clicking the selected trace KEEPS it selected (D3);
#        TB-clear a far click CLEARS the selection (D2);
#        TB-cross the selection is ONE TRACE IN THE WINDOW, not one per strip —
#                hilight_wave is a per-RECT token, so a click on strip B used to
#                leave strip A's bold standing; the witness is the whole stack;
#        TB-agree the C click arm and graph_trace_at agree on every scanned row
#                of the plot box — one shared tolerance, not two that overlap;
#        TB-node the witness is a NODE index, proved on a fixture carrying a
#                vec-less trace so MODEL and NODE indices diverge (landmine 34);
#        TB-digital / TB-noraw a body click writes no uninitialised garbage into
#                hilight_wave on the two paths find_closest_wave refused early;
#        TB-clean the gesture is view state: no modify, no undo point (landmine 19).
#        test_wave_viewer.tcl's WB* block keeps the single-trace precision legs.
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

# --- REUSE an existing empty strip instead of inserting one (D1/D2) ----------
# The whole reuse decision is the PURE wviewer::reuse_strip_for_trace_move, so
# every rung of D1/D2 is assertable here with literal lists and no window.
#
# ⚠ These legs are the ones that CANNOT go hollow: "consume the strip at gi + 1"
# and "insert a strip at gi + 1" leave the trace at the same index, so the
# discriminators are the strip COUNT and the strip IDENTITY (the inert `tpid`
# key below — the model dict is free-form and graph_props reads known keys only).
proc tp_e {id} { return [dict replace [wviewer::empty_graph] tpid $id] }
proc tp_s {id args} {
  set trs {}
  set c 4
  foreach v $args { lappend trs [tp_trace $v $c]; incr c }
  return [dict create traces $trs logx 0 logy 0 x1 0 x2 1 y1 0 y2 2 tpid $id]
}
proc tp_ids {gs} {
  set out {}
  foreach G $gs { lappend out [wviewer::dget $G tpid -] }
  return $out
}

# the shared definition of "empty" (stated, not implied): ZERO MODEL TRACES
check "TP28 a fresh strip is empty" [wviewer::graph_is_empty [wviewer::empty_graph]] 1
check "TP28 a strip with a drawn trace is not" \
  [wviewer::graph_is_empty [tp_s X va]] 0
check "TP29 a strip holding only vec-less traces is NOT empty (zero MODEL traces)" \
  [wviewer::graph_is_empty [dict create traces \
     [list [dict create expr {} name {} vec {} color 7]]]] 0
check_true "TP29 ... and node_count would have called it empty (the two differ)" \
  [expr {[wviewer::node_count [dict create traces \
     [list [dict create expr {} name {} vec {} color 7]]]] == 0}]
check "TP30 a malformed entry fails CLOSED (never consumable)" \
  [wviewer::graph_is_empty SENTINEL] 0

# D1: nearest BELOW, else nearest ABOVE, else insert
check "TP31 no empty strip anywhere -> -1, so one must be inserted" \
  [wviewer::reuse_strip_for_trace_move [list [tp_s A va vb] [tp_s B vc]] 0] -1
check "TP32 the empty strip directly below is consumed" \
  [wviewer::reuse_strip_for_trace_move [list [tp_s A va vb] [tp_e B]] 0] 1
check "TP33 with two below, the NEAREST below wins" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [tp_s B vc] [tp_e C] [tp_e D]] 0] 2
check "TP34 nothing below -> the nearest ABOVE" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_e A] [tp_e B] [tp_s C va vb] [tp_s D vc]] 2] 1
check "TP35 D1 tie-break: BELOW wins even when the one above is NEARER" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_e A] [tp_s B va vb] [tp_s C vc] [tp_s D vd] [tp_e E]] 1] 4
check "TP36 with two above and none below, the nearest above wins" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_e A] [tp_e B] [tp_s C va vb]] 2] 1
# D-D: the auto-plot strip is rebuilt after every run, so a trace parked there is
# silently destroyed — it is never consumable, exactly as `e` never deletes it
check "TP37 the only empty strip is the AUTO strip -> -1 (D-D)" \
  [wviewer::reuse_strip_for_trace_move [list [tp_s A va vb] [tp_e B]] 0 1] -1
check "TP38 the auto strip is skipped and another empty strip taken" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [tp_e B] [tp_e C]] 0 1] 2
check "TP38 an auto strip ABOVE does not block the one below" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_e A] [tp_s B va vb] [tp_e C]] 1 0] 2
# D2: distance
check "TP39 a FAR empty strip IS taken (D2, no cap by default)" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [tp_s B vc] [tp_s C vd] [tp_s D ve] \
           [tp_s E vf] [tp_s F vg] [tp_s G vh] [tp_e H]] 0] 7
check "TP40 the optional cap refuses it (cap 2)" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [tp_s B vc] [tp_s C vd] [tp_e D]] 0 -1 2] -1
check "TP40 ... and accepts one inside the cap" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [tp_s B vc] [tp_e C] [tp_e D]] 0 -1 2] 2
check "TP41 the cap applies BEFORE the direction preference" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_e A] [tp_s B va vb] [tp_s C vc] [tp_s D vd] [tp_e E]] 1 -1 2] 0
check "TP42 cap 0 is OFF, not 'distance must be 0'" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [tp_s B vc] [tp_e C]] 0 -1 0] 2
check "TP42 a negative cap is refused, not applied" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [tp_s B vc] [tp_e C]] 0 -1 -3] 2
# the cap's config reader (D2 default OFF — it must stay off until asked for)
check "TP43 the cap config default is 0 (OFF)" [wviewer::reuse_max_distance] 0
set ::wviewer_reuse_max_distance 3
check "TP43 a set value is honoured" [wviewer::reuse_max_distance] 3
set ::wviewer_reuse_max_distance junk
check "TP43 junk falls back to OFF" [wviewer::reuse_max_distance] 0
set ::wviewer_reuse_max_distance -2
check "TP43 a negative value falls back to OFF" [wviewer::reuse_max_distance] 0
unset ::wviewer_reuse_max_distance
check "TP43 unset is OFF again" [wviewer::reuse_max_distance] 0
# candidate hygiene
check "TP44 a strip of vec-less traces is not a candidate" \
  [wviewer::reuse_strip_for_trace_move \
     [list [tp_s A va vb] [dict create traces \
        [list [dict create expr {} name {} vec {} color 7]] tpid B]] 0] -1
check "TP45 a non-integer source index -> -1 (no throw)" \
  [pcall {wviewer::reuse_strip_for_trace_move [list [tp_e A]] x}] -1
check "TP45 an empty stack -> -1" [wviewer::reuse_strip_for_trace_move {} 0] -1
# REPLAY DETERMINISM: the log line carries no destination, so a replay recomputes
# the decision — which is only sound because the decision is a pure function of
# the model. Asserted rather than assumed.
set tpr [list [tp_e A] [tp_s B va vb] [tp_s C vc] [tp_e D]]
check_true "TP46 the same model gives the same answer twice (replay-safe)" \
  [expr {[wviewer::reuse_strip_for_trace_move $tpr 1] eq
         [wviewer::reuse_strip_for_trace_move $tpr 1]}]

# --- the COMPOSITION, reuse arm: count and identity are the discriminators ---
set tpg [list [tp_s A va vb vc] [dict replace [tp_e B] y1 -5 y2 -4] [tp_s C vd]]
set tpat [wviewer::reuse_strip_for_trace_move $tpg 0]
check "TP47 the reuse picks strip 1" $tpat 1
set tpmv [wviewer::move_trace_in_graphs $tpg 0 1 $tpat]
check "TP47 the STRIP COUNT is unchanged — nothing was created" [llength $tpmv] 3
check "TP47 and the strips are the same strips (identity, not arithmetic)" \
  [tp_ids $tpmv] {A B C}
check "TP48 the trace landed in the strip that was already there" \
  [tp_vecs [lindex $tpmv 1]] {vb}
check "TP48 the source kept the rest, in order" [tp_vecs [lindex $tpmv 0]] {va vc}
check "TP49 the REUSED strip's stale ranges were blanked (autozoom for free)" \
  [list [wviewer::dget [lindex $tpmv 1] y1 {}] [wviewer::dget [lindex $tpmv 1] y2 {}]] {{} {}}
# teeth: the insert arm produces a stack the same leg can tell apart, so a
# "reuse always" and an "insert always" implementation cannot both pass
set tpins [wviewer::move_trace_in_graphs [linsert $tpg 1 [wviewer::empty_graph]] 0 1 1]
check "TP49 the insert arm grows the stack instead" [llength $tpins] 4
check "TP49 ... and pushes the pre-existing empty strip down" [tp_ids $tpins] {A - B C}

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
  # EMPTY WAVEFORM SPACE means empty PLOT BODY, not merely "a pixel with no trace
  # on it". ⚠ The plotbox_at rung is load-bearing (issue 0178): without it this
  # walks the strip from the top and returns a LEGEND pixel, because the legend
  # band is inside the strip and carries no drawn trace. That used to be
  # indistinguishable from body space -- both refused every gate -- but the
  # legend is now the trace menu's second picking surface, so a legend pixel
  # answers {0 n} and TG7's "empty waveform space refuses" leg went red pointing
  # at the helper rather than at the code. It is also exactly the region item 8's
  # own gate excludes (`strip_menu_pick` requires plotbox_at), so this now agrees
  # with the thing it is testing against.
  proc find_empty_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 2} {
        if {[wviewer::strip_at_pixel $vdrw $px $py] != $gi} { continue }
        if {![wviewer::plotbox_at $vdrw $gi $px $py]} { continue }
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

    # === TB (issue 0174): the LMB wave-bold pick is PRECISE and PER-TRACE ====
    #
    # Two defects, both previously documented as out of scope by issue 0152:
    #   (a) find_closest_wave() had NO distance threshold — it minimised |dy| at
    #       the nearest sample and returned the winner however far away, so a
    #       click anywhere in the plot body bolted something. Measured on this
    #       fixture before the fix: 714 of 776 pixel rows of the centre column
    #       are more than 10 px from every trace, and every one of them bolted a
    #       trace.
    #   (b) the toggle tested the CURRENT bold, not the trace just picked, so the
    #       selection could never move from trace A to trace B: the click that
    #       should have picked B cleared A instead. Measured: -1 -> click node 0
    #       -> 0 -> click node 2 -> -1 (not 2).
    # Plus one found by measuring: find_closest_wave() returned from BOTH its
    # early exits without writing *node_number, so a body click on a digital
    # strip or with no raw loaded persisted stack garbage into hilight_wave
    # (measured: -1859984240).
    #
    # These legs live here rather than only in test_wave_viewer.tcl's WB* block
    # because this is the file that owns graph_trace_at-gated picking AND the
    # only one with a live multi-trace strip: WB*'s fixture has a single trace
    # on strip 0, where "picks the nearest" and "picks node 0" are the same
    # answer and neither defect is witnessable. WB* keeps the single-trace
    # precision legs; the multi-trace semantics are here.
    #
    # ⚠ HOLLOWNESS. "it picks the nearest trace" is not the test — a leg that
    # only ever clicks ON a trace passes against the thresholdless pick too. The
    # load-bearing legs are TB-far (a click far from everything picks NOTHING)
    # and TB-move (A -> B in ONE click, nothing in between).

    # A pixel the engine agrees is on node `want` of strip `gi`, or {}.
    # find_trace_px's scan, with the node index as an input rather than an
    # output — the three fixture traces (vsweep+1/+3/+5) are parallel and well
    # separated after a fit, so one column finds all three.
    proc tb_px_for_node {vdrw gi want} {
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      foreach fx {0.50 0.40 0.60 0.30 0.70} {
        set px [expr {int($fx * $W)}]
        for {set py 2} {$py < $H} {incr py 1} {
          if {[wviewer::trace_at $vdrw $gi $px $py] == $want} { return [list $px $py] }
        }
      }
      return {}
    }
    # ... and one INSIDE the plot box that is more than the pick tolerance from
    # every trace. plotbox_at is required so the scan cannot hand back the
    # legend/label margin, where LMB means something else entirely.
    proc tb_far_px {vdrw gi} {
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      set px [expr {int(0.50 * $W)}]
      for {set py 2} {$py < $H} {incr py 1} {
        if {![wviewer::plotbox_at $vdrw $gi $px $py]} { continue }
        if {[wviewer::trace_at $vdrw $gi $px $py] >= 0} { continue }
        return [list $px $py]
      }
      return {}
    }
    proc tb_bold {vdrw} {
      xschem new_schematic switch $vdrw
      set v [pcall {xschem getprop rect 2 0 hilight_wave}]
      if {$v eq {} || [string match ERR:* $v]} { return {} }
      return $v
    }
    proc tb_reset {tok} {
      wviewer::with_edit $tok {xschem setprop rect 2 0 hilight_wave -1}
    }
    # every strip's hilight_wave at once — the witness for the CROSS-STRIP legs.
    # `-` means the token is absent (nothing bold), which must never be read as
    # node 0 (landmine 34's neighbour: a bare atoi("") would say 0).
    proc tb_bolds {vdrw} {
      xschem new_schematic switch $vdrw
      set o {}
      for {set k 0} {$k < [xschem get rects 2]} {incr k} {
        set v {}
        catch {set v [xschem getprop rect 2 $k hilight_wave]}
        lappend o [expr {$v eq {} ? "-" : $v}]
      }
      return $o
    }
    proc tb_reset_all {tok vdrw} {
      xschem new_schematic switch $vdrw
      set n [xschem get rects 2]
      wviewer::with_edit $tok {
        for {set k 0} {$k < $n} {incr k} { xschem setprop rect 2 $k hilight_wave -1 }
      }
    }
    proc tb_click {vdrw px py} {
      tm_ev $vdrw <ButtonPress-1>   -x $px -y $py
      tm_ev $vdrw <ButtonRelease-1> -x $px -y $py -state 0x100
      update
    }

    set W [winfo width $vdrw]; set H [winfo height $vdrw]

    # The fixture grows a VEC-LESS trace at model index 1, so MODEL and NODE
    # index spaces diverge (landmine 34): without it "picks the trace under the
    # pointer" and "picks model index N" are the same answer and the witness
    # proves nothing. graph_props skips a vec-less trace when building the
    # `node` token, so nothing is drawn for it. The plant is the
    # test_wave_drag_preview.tcl fill_viewer precedent.
    fill_viewer $tok
    set tbgs [dict get [wviewer::layout_for $tok] graphs]
    set tbG  [lindex $tbgs 0]
    set tbtr [linsert [wviewer::dget $tbG traces {}] 1 \
                [dict create expr {} name {} vec {} color 7]]
    wviewer::set_graphs $tok [lreplace $tbgs 0 0 [dict replace $tbG traces $tbtr]]
    wviewer::regenerate $tok
    wviewer::fit $tok
    update
    set tbG [lindex [dict get [wviewer::layout_for $tok] graphs] 0]
    check "TB0 four MODEL traces, three NODE slots (landmine 34)" \
      [list [llength [wviewer::dget $tbG traces {}]] [wviewer::node_count $tbG]] {4 3}
    check "TB0 node 1 is MODEL index 2 — the spaces have diverged" \
      [wviewer::trace_index_of_node $tbG 1] 2

    set tb0 [tb_px_for_node $vdrw 0 0]
    set tb2 [tb_px_for_node $vdrw 0 2]
    set tbf [tb_far_px $vdrw 0]
    if {![llength $tb0] || ![llength $tb2] || ![llength $tbf]} {
      puts "SKIPPED: TB legs (no separated trace pixels — window too small to plot in)"
    } else {
      check_true "TB0 a pixel on node 0, a pixel on node 2 and a far body pixel were found" \
        [expr {[llength $tb0] && [llength $tb2] && [llength $tbf]}]

      # --- TB-far: defect (a). THE leg that fails on the old code. ------------
      # Teeth: the same pixel with an enormous tolerance DOES find a trace, so
      # -1 at the shipping tolerance means "far from every trace", not "this
      # strip has no data" — which is how this leg would otherwise pass against
      # a pick that was simply broken.
      lassign $tbf tbfx tbfy
      check_true "TB-far the far pixel is FAR, not data-less (a huge tol still hits)" \
        [expr {[wviewer::trace_at $vdrw 0 $tbfx $tbfy 1e30] >= 0}]
      check "TB-far ... and the shipping tolerance calls it empty" \
        [wviewer::trace_at $vdrw 0 $tbfx $tbfy] -1
      tb_reset $tok
      tb_click $vdrw $tbfx $tbfy
      check "TB-far a click far from every trace selects NOTHING" [tb_bold $vdrw] -1

      # --- TB-move: defect (b). A -> B in ONE click, nothing in between. ------
      lassign $tb0 tb0x tb0y
      lassign $tb2 tb2x tb2y
      tb_reset $tok
      tb_click $vdrw $tb0x $tb0y
      check "TB-move a click on node 0 selects node 0" [tb_bold $vdrw] 0
      tb_click $vdrw $tb2x $tb2y
      check "TB-move a click on node 2 MOVES the selection there (one click)" \
        [tb_bold $vdrw] 2

      # --- TB-same: D3 — a plain click never deselects what it lands on -------
      # Settled by the user at review. Cadence behaviour, and it is what leaves
      # room for 0175: de-selecting ONE trace becomes Ctrl+click, which is also
      # the only way to add to a selection.
      tb_click $vdrw $tb2x $tb2y
      check "TB-same re-clicking the selected trace KEEPS it selected" [tb_bold $vdrw] 2

      # --- TB-clear: D2 — empty body space clears -----------------------------
      # Also settled at review. This does NOT collide with the strip
      # drag-reorder that owns the same pixels: the two are separated by the
      # TRAVEL test in C, not by the pick — a real reorder drag travels well past
      # GRAPH_CLICK_TOL (3 px) and its release never reaches the wave-bold arm.
      # Only a press-release that moved less than that clears, which is a click
      # by any definition. test_wave_viewer.tcl's WB-lmb-drag owns the drag half.
      tb_reset $tok
      tb_click $vdrw $tb0x $tb0y
      check "TB-clear node 0 is selected before the far click" [tb_bold $vdrw] 0
      tb_click $vdrw $tbfx $tbfy
      check "TB-clear a far click CLEARS the selection" [tb_bold $vdrw] -1

      # --- TB-cross: the selection is ONE TRACE IN THE WINDOW -----------------
      # hilight_wave is a PER-RECT token, so everything above only proves the
      # rule WITHIN one strip. Reported at review: selecting a trace on strip A
      # and then clicking one on strip B left BOTH bold — the same "the
      # selection cannot move" defect, across strips. The witness has to be the
      # whole stack (tb_bolds), never one rect: `tb_bold` alone reads strip 0 and
      # would pass while strip 1 kept a stale bold.
      # fill_viewer puts vec_d alone on strip 1, plus the vec-less plant on 0.
      set tbs1 {}
      for {set py 2} {$py < $H} {incr py 1} {
        if {[wviewer::trace_at $vdrw 1 $tbfx $py] == 0} { set tbs1 [list $tbfx $py]; break }
      }
      set tbe1 {}
      for {set py 2} {$py < $H} {incr py 1} {
        if {![wviewer::plotbox_at $vdrw 1 $tbfx $py]} { continue }
        if {[wviewer::trace_at $vdrw 1 $tbfx $py] >= 0} { continue }
        set tbe1 [list $tbfx $py]; break
      }
      if {![llength $tbs1] || ![llength $tbe1]} {
        puts "SKIPPED: TB-cross (no trace/empty pixel found in strip 1)"
      } else {
        tb_reset_all $tok $vdrw
        check "TB-cross nothing bold anywhere to start" [tb_bolds $vdrw] {-1 -1}
        tb_click $vdrw $tb0x $tb0y
        check "TB-cross a click on strip 0 bolds there and nowhere else" \
          [tb_bolds $vdrw] {0 -1}
        tb_click $vdrw [lindex $tbs1 0] [lindex $tbs1 1]
        check "TB-cross a click on strip 1 MOVES the selection off strip 0" \
          [tb_bolds $vdrw] {-1 0}
        tb_click $vdrw [lindex $tbs1 0] [lindex $tbs1 1]
        check "TB-cross re-clicking it keeps it, and strip 0 stays clear" \
          [tb_bolds $vdrw] {-1 0}
        tb_click $vdrw $tb0x $tb0y
        check "TB-cross and back the other way" [tb_bolds $vdrw] {0 -1}
        tb_click $vdrw [lindex $tbe1 0] [lindex $tbe1 1]
        check "TB-cross empty space on ANOTHER strip clears the selection too" \
          [tb_bolds $vdrw] {-1 -1}
      }

      # --- TB-agree: the shared tolerance -------------------------------------
      # The C click arm and graph_trace_at must answer the same question at the
      # same pixel — three picking surfaces on one strip disagreeing about
      # "close enough" is the next bug report. Scanned across the whole column,
      # not spot-checked, so a tolerance that merely OVERLAPS cannot pass.
      set tbdiff 0
      set tbrows 0
      for {set py 2} {$py < $H} {incr py 7} {
        if {![wviewer::plotbox_at $vdrw 0 $tbfx $py]} { continue }
        incr tbrows
        set want [wviewer::trace_at $vdrw 0 $tbfx $py]
        tb_reset $tok
        tb_click $vdrw $tbfx $py
        if {[tb_bold $vdrw] != $want} { incr tbdiff }
      }
      check_true "TB-agree the scan covered the plot box" [expr {$tbrows > 10}]
      check "TB-agree the click arm and graph_trace_at agree on every row" $tbdiff 0

      # --- TB-node: the witness is a NODE index -------------------------------
      # node 2 is MODEL index 3 in this fixture, so a picker that answered in
      # model space would have written 3 here.
      tb_reset $tok
      tb_click $vdrw $tb2x $tb2y
      set tbG [lindex [dict get [wviewer::layout_for $tok] graphs] 0]
      check "TB-node the selected trace is node 2 = MODEL index 3" \
        [list [tb_bold $vdrw] [wviewer::trace_index_of_node $tbG [tb_bold $vdrw]]] {2 3}

      # --- TB-clean: landmine 19 — selection is VIEW state --------------------
      lassign [wviewer::history_depth $tok] tbu0 tbr0
      tb_reset $tok
      tb_click $vdrw $tb0x $tb0y
      xschem new_schematic switch $vdrw
      check "TB-clean the gesture left the buffer unmodified" [xschem get modified] 0
      lassign [wviewer::history_depth $tok] tbu1 tbr1
      check "TB-clean the gesture took no undo point" [expr {$tbu1 - $tbu0}] 0

      # --- TB-digital: D5 --------------------------------------------------
      # graph_wave_at answers -1 across a digital strip's whole body by design
      # (a band/ribbon is not a polyline). Nothing is lost: find_closest_wave
      # refused digital strips too, but it refused by returning BEFORE writing
      # *node_number, so the caller's uninitialised local was persisted into the
      # token. `digital` is set on the RECT and not through the model — the
      # viewer's graph_props has no digital key — so no regenerate may run
      # between here and the restore.
      tb_reset $tok
      wviewer::with_edit $tok {xschem setprop rect 2 0 digital 1; xschem redraw}
      update
      xschem new_schematic switch $vdrw
      check "TB-digital the strip really is digital" \
        [xschem getprop rect 2 0 digital] 1
      set tbbad 0
      foreach fy {0.20 0.35 0.50 0.65 0.80} {
        tb_reset $tok
        tb_click $vdrw $tbfx [expr {int($fy * $H)}]
        if {[tb_bold $vdrw] != -1} { incr tbbad }
      }
      check "TB-digital a body click on a digital strip selects nothing, and writes no garbage" \
        $tbbad 0
      wviewer::with_edit $tok {xschem setprop rect 2 0 digital 0; xschem redraw}
      update

      # --- TB-noraw: the other uninitialised-read path ------------------------
      tb_reset $tok
      xschem new_schematic switch $vdrw
      pcall {xschem raw clear}
      update
      set tbbad 0
      foreach fy {0.25 0.50 0.75} {
        tb_reset $tok
        tb_click $vdrw $tbfx [expr {int($fy * $H)}]
        if {[tb_bold $vdrw] != -1} { incr tbbad }
      }
      check "TB-noraw a body click with no raw loaded selects nothing, and writes no garbage" \
        $tbbad 0
      # put the fixture's raw back for anything downstream
      xschem new_schematic switch $vdrw
      pcall {xschem raw new wvtm.raw dc vsweep 0 1.0 0.02}
      foreach {v ex} {vec_a {vsweep 1 +} vec_b {vsweep 3 +} vec_c {vsweep 5 +}
                      vec_d {vsweep 7 +}} {
        pcall {xschem raw add $v $ex}
      }
      check_true "TB-noraw the fixture raw is back" \
        [expr {[lsearch -exact [split [pcall {xschem raw list}] "\n"] vec_a] >= 0}]
    }
    rename tb_px_for_node {}
    rename tb_far_px {}
    rename tb_bold {}
    rename tb_bolds {}
    rename tb_reset {}
    rename tb_reset_all {}
    rename tb_click {}
    fill_viewer $tok
  }

  # ==========================================================================
  # TL* / TS* — issue 0175: the LEGEND is a picking surface, and the selection
  # holds MORE THAN ONE trace
  # ==========================================================================
  #
  # Two features, one fixture, because both need what only this suite has: a
  # LIVE strip carrying three drawn traces PLUS a vec-less one, so MODEL and
  # NODE index spaces genuinely diverge (landmine 34).
  #
  #   TL*  `xschem get graph_legend_at <gi> <px> <py>` — the legend hit test.
  #        It always existed, fused into the ACTION of draw.c's
  #        edit_wave_attributes() and reachable only from a Button3 press;
  #        0175 extracted it as a pure query so both mouse buttons and Tcl share
  #        one answer. Slot arithmetic, the SLOT BOUNDARY, the refusals, and the
  #        RAW-PIXELS contract.
  #   TS*  the SELECTION as a SET: Ctrl+click adds, Ctrl+click on a selected
  #        trace removes, a plain click COLLAPSES to the one clicked, and the set
  #        is window-wide (Ctrl spans strips, a plain click does not).
  #
  # ⚠ HOLLOWNESS — every one of these is a leg that would otherwise be skipped:
  #   (1) a multi-select leg must assert the SET, not the COUNT: {0 2} and {0 1}
  #       are both "two selected", and `llength == 2` passes on the wrong one;
  #   (2) the Ctrl REMOVE must be driven from a >= 2-element selection, or
  #       "removed the right one" and "cleared everything" are the same state;
  #   (3) the query needs a SLOT-BOUNDARY leg on a >= 3-entry strip: a one-entry
  #       strip has a single slot spanning the whole width and proves nothing
  #       about `rw / n_nodes * wcnt`;
  #   (4) the query must be fed RAW pixels, not the C mouse mirror — asserted by
  #       parking the pointer on a DIFFERENT entry and querying a third one;
  #   (5) the witness is a NODE index, on a fixture where node != model index.

  # the fixture, planted here rather than inherited: the TB block's teardown runs
  # a plain fill_viewer, which drops the vec-less trace that trap (5) needs.
  fill_viewer $tok
  set tsgs [dict get [wviewer::layout_for $tok] graphs]
  set tsG0 [lindex $tsgs 0]
  set tstr [linsert [wviewer::dget $tsG0 traces {}] 1 \
              [dict create expr {} name {} vec {} color 7]]
  wviewer::set_graphs $tok [lreplace $tsgs 0 0 [dict replace $tsG0 traces $tstr]]
  wviewer::regenerate $tok
  wviewer::fit $tok
  update

  # every strip's SELECTION SET at once — the witness for everything below.
  # `-` is a strip with nothing selected, which must never read as node 0.
  proc ts_sels {vdrw} {
    xschem new_schematic switch $vdrw
    set o {}
    for {set k 0} {$k < [xschem get rects 2]} {incr k} {
      set s [wviewer::selected_waves $vdrw $k]
      lappend o [expr {[llength $s] ? $s : "-"}]
    }
    return $o
  }
  # the RAW token pair, so the two-token contract is asserted directly and not
  # only through the composed reader
  proc ts_tokens {vdrw gi} {
    xschem new_schematic switch $vdrw
    set h {}; catch {set h [xschem getprop rect 2 $gi hilight_wave]}
    set s {}; catch {set s [xschem getprop rect 2 $gi sel_waves]}
    return [list $h $s]
  }
  proc ts_reset {tok vdrw} {
    xschem new_schematic switch $vdrw
    set n [xschem get rects 2]
    wviewer::with_edit $tok {
      for {set k 0} {$k < $n} {incr k} {
        xschem setprop rect 2 $k hilight_wave -1
        catch {xschem setprop rect 2 $k sel_waves {}}
      }
    }
  }
  # `st` is the modifier mask on the PRESS; 0x4 is ControlMask. The release
  # carries it too, plus Button1Mask (0x100), exactly as X reports it.
  proc ts_click {vdrw px py {st 0}} {
    tm_ev $vdrw <ButtonPress-1>   -x $px -y $py -state $st
    tm_ev $vdrw <ButtonRelease-1> -x $px -y $py -state [expr {$st | 0x100}]
    update
  }
  proc ts_px_for_node {vdrw gi want} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60 0.30 0.70} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 1} {
        if {[wviewer::trace_at $vdrw $gi $px $py] == $want} { return [list $px $py] }
      }
    }
    return {}
  }
  proc ts_far_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set px [expr {int(0.50 * $W)}]
    for {set py 2} {$py < $H} {incr py 1} {
      if {![wviewer::plotbox_at $vdrw $gi $px $py]} { continue }
      if {[wviewer::trace_at $vdrw $gi $px $py] >= 0} { continue }
      return [list $px $py]
    }
    return {}
  }
  # the legend BAND of strip `gi`: the last canvas row above its plot box.
  # Derived from the engine's own plot-box query, never a fraction of the widget
  # — the strip geometry follows the WM's window size.
  proc ts_legend_row {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set px [expr {int(0.5 * $W)}]
    for {set py 0} {$py < $H} {incr py} {
      if {[wviewer::plotbox_at $vdrw $gi $px $py]} { return [expr {$py - 1}] }
    }
    return -1
  }
  # the first x at which the legend answer rises above `from`, scanning right —
  # a real slot boundary, FOUND rather than computed from the formula under test
  proc ts_boundary {vdrw gi row from} {
    set W [winfo width $vdrw]
    for {set x 0} {$x < $W} {incr x} {
      if {[wviewer::legend_at $vdrw $gi $x $row] > $from} { return $x }
    }
    return -1
  }
  # the CENTRE x of legend slot `n` — the midpoint of the run of columns the
  # engine assigns to that entry. Clicks use this, never a fixed fraction: the
  # outermost columns of the band sit within waves_selected's 5-px routing
  # border, where a press never reaches the graph at all (a leg driven from
  # there passes for the wrong reason).
  proc ts_slot_center {vdrw gi row n} {
    set W [winfo width $vdrw]
    set lo -1; set hi -1
    for {set x 0} {$x < $W} {incr x} {
      if {[wviewer::legend_at $vdrw $gi $x $row] != $n} { continue }
      if {$lo < 0} { set lo $x }
      set hi $x
    }
    if {$lo < 0} { return {} }
    return [expr {($lo + $hi) / 2}]
  }
  # a pixel in the strip's LEFT AXIS MARGIN: inside the rect (so the press really
  # is routed to this graph), outside the plot box, and on no legend slot
  proc ts_axis_margin_px {vdrw gi py} {
    set W [winfo width $vdrw]
    for {set x 0} {$x < $W} {incr x} {
      if {![wviewer::plotbox_at $vdrw $gi $x $py]} { continue }
      if {$x < 12} { return {} }
      set mx [expr {$x - 4}]
      if {[wviewer::legend_at $vdrw $gi $mx $py] >= 0} { return {} }
      return $mx
    }
    return {}
  }

  set tsrow [ts_legend_row $vdrw 0]
  set tsW   [winfo width $vdrw]
  set ts0   [ts_px_for_node $vdrw 0 0]
  set ts1   [ts_px_for_node $vdrw 0 1]
  set ts2   [ts_px_for_node $vdrw 0 2]
  set tsf   [ts_far_px $vdrw 0]
  set tsq0  [ts_px_for_node $vdrw 1 0]

  check_true "TL0 the legend band of strip 0 was located" [expr {$tsrow > 0}]
  if {$tsrow <= 0} {
    puts "SKIPPED: TL*/TS* (no legend band found — window too small)"
  } else {

  # --- TL1: the slot arithmetic --------------------------------------------
  set tsL0 [wviewer::legend_at $vdrw 0 [expr {int(0.02 * $tsW)}] $tsrow]
  set tsL1 [wviewer::legend_at $vdrw 0 [expr {int(0.50 * $tsW)}] $tsrow]
  set tsL2 [wviewer::legend_at $vdrw 0 [expr {int(0.98 * $tsW)}] $tsrow]
  check "TL1 the far left of the legend band is entry 0" $tsL0 0
  check "TL1 the middle is entry 1" $tsL1 1
  check "TL1 the far right is entry 2" $tsL2 2
  # TEETH: three DIFFERENT answers across one band is what a single-slot (or a
  # constant-0) implementation cannot produce
  check "TL1 the three columns really give three different entries" \
    [lsort -unique [list $tsL0 $tsL1 $tsL2]] {0 1 2}

  # --- TL2: the SLOT BOUNDARY (hollowness trap 3) --------------------------
  # An off-by-one slot is invisible to any leg that clicks slot CENTRES. This
  # walks to the first x where the answer changes and asserts the pixel on either
  # side of it, so a `wcnt` shifted by one moves the boundary and turns this red
  # while every centre leg above stays green.
  set tsb [ts_boundary $vdrw 0 $tsrow 0]
  check_true "TL2 a 0->1 slot boundary was found inside the band" \
    [expr {$tsb > 0 && $tsb < $tsW}]
  if {$tsb > 0} {
    check "TL2 the pixel just LEFT of the boundary is still entry 0" \
      [wviewer::legend_at $vdrw 0 [expr {$tsb - 1}] $tsrow] 0
    check "TL2 the boundary pixel itself is entry 1" \
      [wviewer::legend_at $vdrw 0 $tsb $tsrow] 1
    # ... and it sits about a THIRD of the way across: the slot width is
    # rw/n_nodes, so with three entries the first boundary cannot be at halfway
    check_true "TL2 the boundary is near 1/3 of the width, not 1/2" \
      [expr {$tsb > 0.25 * $tsW && $tsb < 0.42 * $tsW}]
  }

  # --- TL3: the refusals — all fail CLOSED, never a plausible 0 ------------
  if {[llength $ts0]} {
    check "TL3 inside the plot box there is no legend entry" \
      [wviewer::legend_at $vdrw 0 [lindex $ts0 0] [lindex $ts0 1]] -1
  }
  check "TL3 a bad graph index refuses" [wviewer::legend_at $vdrw 99 100 $tsrow] -1
  check "TL3 a negative graph index refuses" [wviewer::legend_at $vdrw -1 100 $tsrow] -1
  check "TL3 a pixel far below every strip refuses" \
    [wviewer::legend_at $vdrw 0 [expr {int(0.5 * $tsW)}] 100000] -1
  check "TL3 the raw verb with too few arguments answers -1, it does not error" \
    [pcall {xschem get graph_legend_at 0}] -1
  # the two picking surfaces of one strip are DISJOINT: neither answers where the
  # other does
  check "TL3 trace_at answers nothing in the legend band" \
    [wviewer::trace_at $vdrw 0 [expr {int(0.5 * $tsW)}] $tsrow] -1

  # --- TL4: RAW pixels, not the C mouse mirror (hollowness trap 4) ---------
  # The in-place hit test this query replaces read xctx->mousex_snap — the
  # GRID-SNAPPED schematic-space mouse mirror. A query that inherited that would
  # answer for wherever the POINTER is, not for the pixel it was handed. Park the
  # pointer on entry 0 and ask about entry 2: a mirror-reading query says 0.
  tm_ev $vdrw <Motion> -x [expr {int(0.02 * $tsW)}] -y $tsrow
  update
  check "TL4 with the pointer parked on entry 0, a query about entry 2 says 2" \
    [wviewer::legend_at $vdrw 0 [expr {int(0.98 * $tsW)}] $tsrow] 2
  # ... and a COARSE snap grid does not move any answer either: with snap 400 a
  # pointer in slot 2 snaps into a neighbouring slot, so a snapped-coordinate
  # query would report the neighbour
  #
  # ⚠ THIS HALF HAS TO DISARM no_snap TO KEEP ITS TEETH (issue 0177). Since 0177
  # the viewer canvas is a `no_snap` context: callback() computes
  # mousex_snap/mousey_snap unsnapped there, so `cadsnap` no longer perturbs
  # anything on this window and the sabotage this leg is built to catch -- a
  # query that reads the mouse mirror instead of its own arguments -- would sail
  # straight through. Dropping the property for the duration of the probe puts a
  # genuinely grid-snapped mirror back under the query, which is the only state
  # in which the assertion means what its name says. The viewer's own behaviour
  # under a coarse grid is covered by test_wave_snap SNG2/SNG4, with the property
  # left armed.
  set tssnap [pcall {set ::cadsnap}]
  set tsnosnap [pcall {xschem get no_snap}]
  set tsraw {}
  if {[string is double -strict $tssnap]} {
    catch {
      xschem set cadsnap 400
      catch {xschem set no_snap 0}
      # Prove the disarm took, i.e. that the "coarse grid" this leg claims to be
      # testing under actually exists on this canvas.
      # ⚠ THE WITNESS MOTION HAS TO LAND WHERE waves_selected DECLINES IT. A
      # motion anywhere the graph owns is routed to waves_callback, which
      # un-snaps both mirrors at its head (issue 0143) whatever no_snap says --
      # so a probe inside the strip can never see a snapped mirror and the
      # witness would fail for the wrong reason (measured: it did). Canvas (1,1)
      # is inside the rect-edge inset, which is the one part of the window the
      # schematic arm still handles.
      tm_ev $vdrw <Motion> -x 1 -y 1
      update
      set tsmirror [pcall {xschem get mousex_snap}]
      set tsraw [list [wviewer::legend_at $vdrw 0 [expr {int(0.02 * $tsW)}] $tsrow] \
                      [wviewer::legend_at $vdrw 0 [expr {int(0.50 * $tsW)}] $tsrow] \
                      [wviewer::legend_at $vdrw 0 [expr {int(0.98 * $tsW)}] $tsrow]]
    }
    catch {xschem set cadsnap $tssnap}
    catch {xschem set no_snap $tsnosnap}
    if {[info exists tsmirror] && [string is double -strict $tsmirror]} {
      check_true "TL4 the probe really ran under a coarse grid (mirror is on it)" \
        [expr {abs($tsmirror - round($tsmirror/400.0)*400.0) < 1e-9}]
    }
    check "TL4 a coarse snap grid does not move the legend answers" $tsraw {0 1 2}
    check "TL4 ...and the viewer got its no_snap property back" \
      [pcall {xschem get no_snap}] $tsnosnap
  } else {
    puts "SKIPPED: TL4 snap half (cadsnap unreadable)"
  }

  if {![llength $ts0] || ![llength $ts2] || ![llength $tsf]} {
    puts "SKIPPED: TS* (no separated trace pixels — window too small to plot in)"
  } else {

  # --- TS1: Ctrl+click ADDS, and the witness is the SET --------------------
  ts_reset $tok $vdrw
  check "TS1 nothing selected to start" [ts_sels $vdrw] {- -}
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  check "TS1 a plain body click selects one trace" [ts_sels $vdrw] {0 -}
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  check "TS1 CTRL+click ADDS the second trace (the SET, not the count)" \
    [ts_sels $vdrw] {{0 2} -}
  # the TWO-TOKEN contract, asserted directly: hilight_wave is the HEAD (so an
  # older build still bolds a real trace) and sel_waves carries the whole set
  check "TS1 hilight_wave is the head and sel_waves is the set" \
    [ts_tokens $vdrw 0] {0 {0 2}}
  # teeth for trap (1): adding the MIDDLE trace must give {0 1 2}, in order — an
  # append-without-ordering would read {0 2 1} and a count check would not care
  if {[llength $ts1]} {
    ts_click $vdrw [lindex $ts1 0] [lindex $ts1 1] 0x4
    check "TS1 a third CTRL+click gives the SET {0 1 2}, in order" \
      [ts_sels $vdrw] {{0 1 2} -}
  }

  # --- TS2: Ctrl+click on a SELECTED trace REMOVES it (trap 2) -------------
  # driven from a >= 2-element selection, so "removed the right one" and
  # "cleared everything" are distinguishable states
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  check "TS2 two traces selected before the remove" [ts_sels $vdrw] {{0 2} -}
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  check "TS2 CTRL+click on a selected trace removes THAT ONE, not all" \
    [ts_sels $vdrw] {0 -}
  check "TS2 ... and sel_waves is GONE, not left as a one-element list" \
    [ts_tokens $vdrw 0] {0 {}}
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1] 0x4
  check "TS2 CTRL+click on the last selected trace empties the selection" \
    [ts_sels $vdrw] {- -}
  # teeth: removing the OTHER member leaves the OTHER survivor, so the two
  # removals are not interchangeable
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1] 0x4
  check "TS2 removing the OTHER one leaves node 2, not node 0" [ts_sels $vdrw] {2 -}

  # --- TS3: a PLAIN click COLLAPSES the selection --------------------------
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  check "TS3 two selected before the plain click" [ts_sels $vdrw] {{0 2} -}
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  check "TS3 a plain click on a SELECTED trace collapses to just that one" \
    [ts_sels $vdrw] {0 -}
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1]
  check "TS3 ... and on the OTHER selected trace, to that one" [ts_sels $vdrw] {2 -}
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1] 0x4
  ts_click $vdrw [lindex $tsf 0] [lindex $tsf 1]
  check "TS3 a plain click on EMPTY body clears the whole set" [ts_sels $vdrw] {- -}

  # --- TS4: CTRL never clears, and it is still VIEW state ------------------
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  ts_click $vdrw [lindex $tsf 0] [lindex $tsf 1] 0x4
  check "TS4 CTRL+click on empty body leaves the selection alone" \
    [ts_sels $vdrw] {{0 2} -}
  lassign [wviewer::history_depth $tok] tsu0 tsr0
  set tslog0 [llength $::tm_log]
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1] 0x4
  lassign [wviewer::history_depth $tok] tsu1 tsr1
  check "TS4 a CTRL selection change took no undo point (landmine 19)" \
    [expr {$tsu1 - $tsu0}] 0
  xschem new_schematic switch $vdrw
  check "TS4 ... and left the buffer unmodified" [xschem get modified] 0
  check "TS4 ... and logged nothing (0176 must replay explicit indices, not state)" \
    [expr {[llength $::tm_log] - $tslog0}] 0

  # --- TS5: the set is WINDOW-WIDE ----------------------------------------
  if {![llength $tsq0]} {
    puts "SKIPPED: TS5 (no trace pixel found in strip 1)"
  } else {
    ts_reset $tok $vdrw
    ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
    ts_click $vdrw [lindex $tsq0 0] [lindex $tsq0 1] 0x4
    check "TS5 CTRL across strips ADDS instead of moving the selection" \
      [ts_sels $vdrw] {0 0}
    ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1]
    check "TS5 a plain click collapses the WHOLE WINDOW to the one clicked" \
      [ts_sels $vdrw] {2 -}
    # a multi-select on strip 0 is cleared by a plain click on strip 1 too — the
    # witness has to be the whole stack, never one rect (0174 defect (d))
    ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
    ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
    ts_click $vdrw [lindex $tsq0 0] [lindex $tsq0 1]
    check "TS5 a plain click on ANOTHER strip clears a multi-select here" \
      [ts_sels $vdrw] {- 0}
  }

  # --- TS6: the LEGEND drives all of it too --------------------------------
  set tsx0 [ts_slot_center $vdrw 0 $tsrow 0]
  set tsx2 [ts_slot_center $vdrw 0 $tsrow 2]
  check_true "TS6 the centre column of legend entries 0 and 2 was located" \
    [expr {$tsx0 ne {} && $tsx2 ne {} && $tsx0 != $tsx2}]
  if {$tsx0 eq {} || $tsx2 eq {}} {
    puts "SKIPPED: TS6 (legend slot centres not found)"
  } else {
  ts_reset $tok $vdrw
  ts_click $vdrw $tsx0 $tsrow
  check "TS6 a plain legend click selects that entry's trace" [ts_sels $vdrw] {0 -}
  ts_click $vdrw $tsx2 $tsrow 0x4
  check "TS6 CTRL on another legend entry ADDS it" [ts_sels $vdrw] {{0 2} -}
  ts_click $vdrw $tsx2 $tsrow 0x4
  check "TS6 CTRL on a selected legend entry REMOVES it" [ts_sels $vdrw] {0 -}
  ts_click $vdrw $tsx2 $tsrow
  check "TS6 a plain legend click COLLAPSES to that entry" [ts_sels $vdrw] {2 -}
  # the two surfaces agree about which trace they mean: selecting entry 2 from
  # the legend and picking node 2 in the body land on the same node
  ts_reset $tok $vdrw
  ts_click $vdrw $tsx2 $tsrow
  set tsvia_legend [ts_sels $vdrw]
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1]
  check "TS6 the legend and the body select the SAME trace" \
    $tsvia_legend [ts_sels $vdrw]
  # a click on the legend ROW that owns no entry changes NOTHING: only the plot
  # BODY clears
  set tsmx [ts_axis_margin_px $vdrw 0 [lindex $tsf 1]]
  if {$tsmx eq {}} {
    puts "SKIPPED: TS6 axis-margin leg (no margin pixel found)"
  } else {
    ts_reset $tok $vdrw
    ts_click $vdrw $tsx0 $tsrow
    ts_click $vdrw $tsmx [lindex $tsf 1]
    check "TS6 a click in the AXIS MARGIN owns no trace and changes nothing" \
      [ts_sels $vdrw] {0 -}
  }
  }

  # --- TR*: RMB on a LEGEND entry is the TRACE MENU, not a selection toggle --
  # (issue 0178, found at the 0177 eyeball)
  #
  # The legend used to be the ONE region of the viewer where RMB was not a
  # context menu: the press fell through btn3_filter to the C engine, whose
  # Button3-outside-the-plot-box arm calls edit_wave_attributes(2, ...) and
  # TOGGLES that trace's membership -- a second button for Ctrl+LMB. RMB now
  # never means "selection" on this canvas any more -- it is a context menu where
  # one can post, and inert where one cannot (a 1-trace strip's legend, the axis
  # margins, and any MODIFIED RMB). Selection on the legend
  # belongs to LMB / Ctrl+LMB alone (TS6 above).
  #
  # The change is TCL-ONLY and deliberately so: the C arm is untouched, so
  # on-canvas SCHEMATIC graphs -- which have no context menus of their own --
  # keep the toggle they have always had.
  set trx1 [ts_slot_center $vdrw 0 $tsrow 1]
  if {$trx1 eq {}} {
    puts "SKIPPED: TR* (legend slot centre not found)"
  } else {
    # the GATE: a legend pixel resolves to {strip node}, a body pixel does not
    check "TR1 legend_slot_at resolves a legend entry to {strip node}" \
      [pcall {wviewer::legend_slot_at $vdrw $trx1 $tsrow}] {0 1}
    check "TR1 ...and a plot-BODY pixel is not a legend slot" \
      [pcall {wviewer::legend_slot_at $vdrw [lindex $ts2 0] [lindex $ts2 1]}] {-1 -1}
    check "TR1 ...and neither is a pixel off every strip" \
      [pcall {wviewer::legend_slot_at $vdrw -50 -50}] {-1 -1}

    # the trace menu's gate now accepts the legend, and names the SAME trace the
    # legend entry does
    check "TR2 trace_menu_pick accepts a legend entry" \
      [pcall {wviewer::trace_menu_pick $vdrw $trx1 $tsrow}] \
      [list 0 [wviewer::trace_index_of_node \
                 [lindex [dict get [wviewer::layout_for $tok] graphs] 0] 1]]
    # ⚠ THE PARTITION, which now holds by TWO different mechanisms and so has to
    # be checked on BOTH regions: in the body the strip gate refuses whatever
    # trace_at accepts; over the legend it cannot compete at all, because it
    # requires plotbox_at. Losing either limb means both menus post on one click.
    check "TR2 the strip menu still refuses the legend (the partition holds)" \
      [pcall {wviewer::strip_menu_pick $vdrw $trx1 $tsrow}] -1

    # THE REPORTED BEHAVIOUR, through the REAL gesture. A full unmodified
    # <ButtonPress-3>/<ButtonRelease-3> on a legend entry must leave the
    # selection exactly as it found it -- empty when it was empty, and (the half
    # that names the report) UNCHANGED when that very trace was already selected.
    # ⚠ THE GESTURE MUST WITNESS BOTH HALVES AT ONCE. Asserting only "the
    # selection did not change" is satisfied just as well by RMB-on-the-legend
    # doing NOTHING AT ALL, which is a distinct and equally wrong outcome (break
    # the release-side post and that is exactly what happens). So every real
    # gesture below reports the menu too, and `tr_rmb` takes the post witness
    # from `trace_menu_unpost`'s own return -- it answers 1 precisely when a menu
    # widget was there to take down.
    proc tr_rmb {vdrw tok px py {st 0}} {
      tm_ev $vdrw <ButtonPress-3>   -x $px -y $py -state $st
      tm_ev $vdrw <ButtonRelease-3> -x $px -y $py -state [expr {$st | 0x400}]
      update
      set posted 0
      catch {set posted [wviewer::trace_menu_unpost $tok]}
      update
      return $posted
    }
    ts_reset $tok $vdrw
    set trposted [tr_rmb $vdrw $tok $trx1 $tsrow]
    check "TR3 RMB on a legend entry does NOT select" [ts_sels $vdrw] {- -}
    check "TR3 ...and it DID post the trace menu (not merely do nothing)" \
      $trposted 1
    ts_click $vdrw $trx1 $tsrow
    check "TR3 (control) an LMB click on the same entry DOES select" \
      [ts_sels $vdrw] {1 -}
    set trposted2 [tr_rmb $vdrw $tok $trx1 $tsrow]
    check "TR3 RMB on the legend of a SELECTED trace does NOT deselect it" \
      [ts_sels $vdrw] {1 -}
    check "TR3 ...and that one posted a menu too" $trposted2 1

    # ⚠ A MODIFIED RMB MUST NOT TOGGLE EITHER, and the first cut of this fix let
    # it: the swallow copied the menu gate's `$s & 13` refusal, so Ctrl+RMB and
    # Shift+RMB still reached C -- whose Button3 routing and toggle arm both
    # ignore `state` -- and went on select/deselecting the trace SILENTLY,
    # because the release gate then refuses to post a menu for those very
    # modifiers. The whole reported defect, alive under a modifier. It is inert
    # now: no toggle, no menu.
    foreach {trname trmask} {Ctrl 0x4 Shift 0x1 Alt 0x8} {
      ts_reset $tok $vdrw
      ts_click $vdrw $trx1 $tsrow
      set trm [tr_rmb $vdrw $tok $trx1 $tsrow $trmask]
      check "TR4 $trmask ($trname)+RMB on a selected legend entry does NOT deselect" \
        [ts_sels $vdrw] {1 -}
      check "TR4 ...and posts no menu either (it is inert)" $trm 0
    }

    # the menu the gesture posts is BUILT for the legend entry's own trace: the
    # header entry carries that trace's label, so a gate that resolved to the
    # wrong trace -- or to strip 0 trace 0 by accident -- shows up here
    ts_reset $tok $vdrw
    tm_ev $vdrw <ButtonPress-3>   -x $trx1 -y $tsrow -state 0
    tm_ev $vdrw <ButtonRelease-3> -x $trx1 -y $tsrow -state 0x400
    update
    set trti [wviewer::trace_index_of_node \
                [lindex [dict get [wviewer::layout_for $tok] graphs] 0] 1]
    set trwant [wviewer::trace_label [lindex [wviewer::dget \
                  [lindex [dict get [wviewer::layout_for $tok] graphs] 0] traces {}] $trti]]
    # trace_menu_build only emits the disabled header when the trace HAS a label,
    # so a label-less fixture trace would make entry 0 the command instead -- skip
    # rather than assert a mismatch that says nothing about the gate
    if {$trwant eq {}} {
      puts "SKIPPED: TR4 header-label leg (the picked trace carries no label)"
    } else {
      set trgot {}
      catch {set trgot [$vtop.wvtracemenu entrycget 0 -label]}
      check "TR4 the posted menu's header names the legend entry's own trace" \
        $trgot $trwant
    }
    catch {wviewer::trace_menu_unpost $tok} ; update

    # the swallow is scoped to the PRESS, and to legend pixels only
    set fp [open [file join $repo src wave_viewer.tcl] r]; set trsrc [read $fp]; close $fp
    check_true "TR5 only the PRESS is claimed, and only on a legend slot" \
      [regexp {if \{\$T == 4 && \[lindex \[wviewer::legend_slot_at \$W \$x \$y\] 0\] >= 0\} \{ set b3own 1 \}} $trsrc]
    check_true "TR5 ...and the forward is skipped only for a claimed press" \
      [regexp {if \{!\$b3own\} \{ xschem callback \$W \$T \$x \$y 0 \$b 0 \$s \}} $trsrc]
    check "TR5 ...with NO modifier exemption (that hole shipped once)" \
      [regexp -all {\$T == 4 && !\(\$s & 13\)} $trsrc] 0
    # the C engine is untouched, so embedded schematic graphs keep the toggle
    set fp [open [file join $repo src callback.c] r]; set trc [read $fp]; close $fp
    check_true "TR5 the C legend toggle still exists (embedded schematic graphs)" \
      [regexp {edit_wave_attributes\(2, i, gr\)} $trc]
  }

  # --- TS7: the witness is a NODE index (trap 5) ---------------------------
  # the fixture carries a vec-less trace at MODEL index 1, so node 2 is model
  # index 3 — a selection reported in model space would say 3
  set tsGm [lindex [dict get [wviewer::layout_for $tok] graphs] 0]
  check "TS7 the fixture has 4 model traces and 3 node slots (landmine 34)" \
    [list [llength [wviewer::dget $tsGm traces {}]] [wviewer::node_count $tsGm]] {4 3}
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  check "TS7 the selected NODE indices map to MODEL indices 0 and 3" \
    [list [wviewer::trace_index_of_node $tsGm 0] \
          [wviewer::trace_index_of_node $tsGm 2]] {0 3}

  # --- TS8: the selection survives a REGENERATE ----------------------------
  # regenerate rebuilds every rect from the model, and it runs on a plain window
  # RESIZE. Without capture_live_graph_state carrying `sel_waves` a multi-select
  # would silently collapse to one trace the next time the user resized.
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  ts_click $vdrw [lindex $ts2 0] [lindex $ts2 1] 0x4
  wviewer::capture_live_graph_state $tok
  check "TS8 the model captured the whole set" \
    [wviewer::model_sel [lindex [dict get [wviewer::layout_for $tok] graphs] 0]] {0 2}
  wviewer::regenerate $tok
  update
  check "TS8 and it survived the regenerate, in the rect" [ts_sels $vdrw] {{0 2} -}
  check "TS8 ... in both tokens" [ts_tokens $vdrw 0] {0 {0 2}}
  # TEETH: a SINGLE selection must NOT grow a sel_waves token on the way
  # through — that is what keeps a never-Ctrl-clicked strip byte-identical to
  # pre-0175 and readable by an older build
  ts_reset $tok $vdrw
  ts_click $vdrw [lindex $ts0 0] [lindex $ts0 1]
  wviewer::capture_live_graph_state $tok
  wviewer::regenerate $tok
  update
  check "TS8 a single-trace selection carries NO sel_waves token" \
    [ts_tokens $vdrw 0] {0 {}}
  }
  }

  rename ts_sels {}
  rename ts_tokens {}
  rename ts_reset {}
  rename ts_click {}
  rename ts_px_for_node {}
  rename ts_far_px {}
  rename ts_legend_row {}
  rename ts_boundary {}
  rename ts_slot_center {}
  rename ts_axis_margin_px {}
  fill_viewer $tok

  # --- TG12..TG18: REUSE an existing empty strip (D1/D2) ---------------------
  #
  # ⚠ THE HOLLOWNESS TRAP. When the free empty strip happens to sit at
  # from_gi + 1, "consume it" and "insert one there" leave the same trace at the
  # same index — a leg that only checks `vecs_at` passes either way. Two
  # discriminators, used on every leg below:
  #   1. the STRIP COUNT: reuse leaves `ngraphs` alone, an insert grows it;
  #   2. STRIP IDENTITY: every fixture strip carries an inert `tmid` key, so a
  #      strip the gesture CREATED reads back as `-` and the pre-existing ones
  #      keep their letters (the SD legs of test_wave_viewer.tcl, same reason —
  #      regenerate/graph_props read known keys only, so tmid changes nothing).
  # These legs need no pixel, so they live OUTSIDE the find_trace_px guard.
  proc fill_spec {tok spec {auto -1}} {
    set gs {}
    foreach _ $spec { lappend gs [wviewer::empty_graph] }
    wviewer::set_graphs $tok $gs
    set gi 0
    foreach vecs $spec {
      foreach v $vecs {
        set e [wviewer::add_trace $tok $gi $v]
        if {$e ne {}} { puts "  fill_spec: add_trace $v -> $e" }
      }
      incr gi
    }
    # the identity keys go on AFTER the traces (add_trace rewrites the strip dict)
    set out {}
    set gi 0
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      set G [dict replace $G tmid [string index ABCDEFGH $gi]]
      if {$gi == $auto} { set G [dict replace $G auto 1] }
      lappend out $G
      incr gi
    }
    wviewer::set_graphs $tok $out
    wviewer::regenerate $tok
    wviewer::fit $tok
    wviewer::set_target_strip 0 $tok
  }
  proc tmids {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [wviewer::dget $G tmid -]
    }
    return $out
  }
  proc kill_list {tok} {
    return [wviewer::empty_strips_to_delete \
              [dict get [wviewer::layout_for $tok] graphs] \
              [wviewer::auto_graph_index $tok]]
  }

  # TG12: the empty strip directly below is CONSUMED, not doubled
  fill_spec $tok {{vec_a vec_b vec_c} {} {vec_d}}
  check "TG12 fixture: three traces, an EMPTY strip below it, then one" \
    [profile $tok] {3 0 1}
  check "TG12 fixture identities" [tmids $tok] {A B C}
  # plant absurd ranges on the empty strip and get them into the RECT, so the
  # blanking leg below has teeth (capture_live_graph_state folds the live rect
  # back into the model before the move, so a model-only plant proves nothing)
  set gs [dict get [wviewer::layout_for $tok] graphs]
  wviewer::set_graphs $tok \
    [lreplace $gs 1 1 [dict replace [lindex $gs 1] y1 -5.0 y2 -4.0]]
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "TG12 fixture: the absurd range really reached the rect" \
    [xschem getprop rect 2 1 y1] -5.0
  check "TG12 the destination is the strip that was already there" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  check "TG12 the STRIP COUNT did not grow — nothing was inserted" [ngraphs $tok] 3
  check "TG12 and they are the SAME strips (identity, not arithmetic)" \
    [tmids $tok] {A B C}
  check "TG12 the moved trace is in the consumed strip" [vecs_at $tok 1] vec_b
  check "TG12 the source kept the other two, in order" [vecs_at $tok 0] {vec_a vec_c}
  check "TG12 the strip below is untouched" [vecs_at $tok 2] vec_d
  check "TG12 the DESTINATION is the target (step 6, reused or new)" \
    [pcall {wviewer::target_strip $tok}] 1
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "TG12 the consumed strip's stale ranges were blanked (autozoom for free)" \
    [list [wviewer::dget [lindex $gs 1] y1 {}] [wviewer::dget [lindex $gs 1] y2 {}]] {{} {}}
  xschem new_schematic switch $vdrw
  check "TG12 the rect count agrees with the model" [xschem get rects 2] 3
  check "TG12 the consumed strip's RECT carries the trace" \
    [string match {*vec_b*} [xschem getprop rect 2 1 node]] 1
  check "TG12 and the source rect no longer does" \
    [string match {*vec_b*} [xschem getprop rect 2 0 node]] 0
  check_true "TG12 regenerate re-autozoomed it (the rect range is not the plant)" \
    [expr {[xschem getprop rect 2 1 y1] != -5.0}]
  check "TG12 buffer NOT left modified (read-only viewer discipline)" \
    [xschem get modified] 0

  # TG13: nothing empty below -> the nearest empty strip ABOVE (D1)
  fill_spec $tok {{} {vec_a vec_b vec_c} {vec_d}}
  check "TG13 fixture: the empty strip is ABOVE the source" [profile $tok] {0 3 1}
  check "TG13 the strip above is consumed" \
    [pcall {wviewer::move_trace_to_new_strip 1 1 $tok}] 0
  check "TG13 the strip count is unchanged" [ngraphs $tok] 3
  check "TG13 the same strips, in the same order" [tmids $tok] {A B C}
  check "TG13 the trace went UP into it" [vecs_at $tok 0] vec_b
  check "TG13 the source kept the rest" [vecs_at $tok 1] {vec_a vec_c}
  check "TG13 the target followed the destination upward" \
    [pcall {wviewer::target_strip $tok}] 0

  # TG14: with nothing to reuse the old behaviour stands — INSERT below (D-F)
  fill_spec $tok {{vec_a vec_b vec_c} {vec_d}}
  check "TG14 fixture has no empty strip" [kill_list $tok] {}
  check "TG14 the new strip goes directly below the source" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  check "TG14 the strip count GREW by one" [ngraphs $tok] 3
  check "TG14 the created strip has no identity, the others keep theirs" \
    [tmids $tok] {A - B}
  check "TG14 the trace is in the created strip" [vecs_at $tok 1] vec_b
  check "TG14 the strip that was below slid down" [vecs_at $tok 2] vec_d

  # TG15: the AUTO-plot strip is never consumed (D-D) — item 13 rebuilds it after
  # every run, so a trace parked there is silently destroyed at the next one
  fill_spec $tok {{vec_a vec_b vec_c} {} {vec_d}} 1
  check "TG15 fixture: strip 1 is the auto-plot strip, and it is traceless" \
    [list [pcall {wviewer::auto_graph_index $tok}] [profile $tok]] {1 {3 0 1}}
  check "TG15 the move INSERTS rather than consuming the auto strip" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  check "TG15 the strip count grew" [ngraphs $tok] 4
  check "TG15 the auto strip was pushed down, not filled" \
    [pcall {wviewer::auto_graph_index $tok}] 2
  check "TG15 it is still traceless" [vecs_at $tok 2] {}
  check "TG15 the trace is in the new strip" [vecs_at $tok 1] vec_b
  check "TG15 identities: a created strip between A and the auto strip" \
    [tmids $tok] {A - B C}

  # TG16: D2 — a FAR empty strip is taken by default, and the optional cap is OFF
  fill_spec $tok {{vec_a vec_b vec_c} {vec_d} {vec_d} {vec_d} {}}
  check "TG16 fixture: the only empty strip is four strips away" \
    [kill_list $tok] 4
  check "TG16 the far empty strip IS consumed (D2 default: no cap)" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 4
  check "TG16 the strip count is unchanged" [ngraphs $tok] 5
  check "TG16 the same strips" [tmids $tok] {A B C D E}
  check "TG16 the trace travelled to it" [vecs_at $tok 4] vec_b
  # the cap exists for the "the trace teleported" reading; it is OFF unless asked
  fill_spec $tok {{vec_a vec_b vec_c} {vec_d} {vec_d} {vec_d} {}}
  set ::wviewer_reuse_max_distance 2
  check "TG16 with the cap on, the far strip is refused and one is inserted" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  check "TG16 so the stack grew" [ngraphs $tok] 6
  check "TG16 and the far empty strip is still empty" [vecs_at $tok 5] {}
  unset ::wviewer_reuse_max_distance
  check "TG16 the cap is OFF again" [pcall {wviewer::reuse_max_distance}] 0

  # TG17: the log line is unchanged, so a REPLAY must recompute the same reuse
  # decision from the model. Asserted, not assumed.
  fill_spec $tok {{vec_a vec_b vec_c} {} {vec_d}}
  set nlog [llength $::tm_log]
  check "TG17 the move reused strip 1" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  check "TG17 exactly one line logged" [expr {[llength $::tm_log] - $nlog}] 1
  check "TG17 the line is the unchanged shape (no reuse decision in it)" \
    [lindex $::tm_log end] "wviewer::move_trace_to_new_strip 0 1 $tok"
  set replay [lindex $::tm_log end]
  set post_ids [tmids $tok]
  set post_prof [profile $tok]
  check_true "TG17 one undo restores the model" \
    [expr {[pcall {wviewer::undo $tok}] ne {ERR}}]
  check "TG17 the undo put the empty strip back" \
    [list [profile $tok] [tmids $tok]] {{3 0 1} {A B C}}
  pcall {uplevel #0 $replay}
  check "TG17 the replay reproduced the state EXACTLY (same reuse decision)" \
    [list [profile $tok] [tmids $tok] [ngraphs $tok]] \
    [list $post_prof $post_ids 3]

  # TG18: the interaction with `e` (item 5) — reuse consumes the very strip `e`
  # would have deleted, so there is less for `e` to find afterwards
  fill_spec $tok {{vec_a vec_b vec_c} {} {}}
  check "TG18 before the move, `e` would delete both empty strips" \
    [kill_list $tok] {1 2}
  check "TG18 the move consumes the NEAREST of them" \
    [pcall {wviewer::move_trace_to_new_strip 0 1 $tok}] 1
  check "TG18 one empty strip is left for `e`" [kill_list $tok] 2
  check "TG18 `e` deletes exactly that one" [pcall {wviewer::delete_empty_strips $tok}] 1
  check "TG18 leaving the two strips that hold traces" \
    [list [profile $tok] [tmids $tok]] {{2 1} {A B}}
  check "TG18 and `e` is then a no-op" [pcall {wviewer::delete_empty_strips $tok}] 0
  # D-C still holds: `e` never empties the window, whatever reuse did before it
  check "TG18 D-C: a window of one empty strip still keeps it" \
    [wviewer::empty_strips_to_delete [list [wviewer::empty_graph]]] {}

  # ==========================================================================
  # MM* — a trace drag carries the WHOLE SELECTION (issue 0192)
  # ==========================================================================
  # doc/claude/specs/waveform_viewer_modes.md §19. The end-to-end gesture: press
  # on a SELECTED trace, drag, drop on another strip -> every selected trace in
  # the window moves there, in source order, as ONE undo point and ONE log line.
  #
  # ⚠ WHY A THREE-STRIP FIXTURE. A two-strip stack cannot tell "moved to the
  # strip I dropped on" from "moved to the other one" — with two strips those are
  # the same answer. Three strips, dropped on the LAST one, discriminate.
  # ⚠ WHY THE `sdid` KEY. An inert per-strip identity (the test_wave_viewer.tcl
  # idiom; graph_props reads known keys only, so it changes nothing) witnesses
  # WHICH STRIP is at index k independently of WHICH TRACE is in it. Without it a
  # trace move and a strip reorder produce the same trace-per-strip witness.
  # ⚠ WHY THE SELECTION IS BUILT WITH mm_click. Through the SHIPPED bindings, at
  # found pixels — never by writing hilight_wave/sel_waves by hand, or the leg
  # asserts against a selection the real gesture could not have produced.
  xschem new_schematic switch $vdrw
  pcall {xschem raw add vec_e {vsweep 9 +}}

  proc mm_fill {tok spec} {
    set gs {}
    foreach _ $spec { lappend gs [wviewer::empty_graph] }
    wviewer::set_graphs $tok $gs
    set gi 0
    foreach vecs $spec {
      foreach v $vecs {
        set e [wviewer::add_trace $tok $gi $v]
        if {$e ne {}} { puts "  mm_fill: add_trace $v -> $e" }
      }
      incr gi
    }
    # the identity keys go on AFTER the traces (add_trace rewrites the dict)
    set out {}
    set gi 0
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [dict replace $G sdid [string index ABCDEFGH $gi]]
      incr gi
    }
    wviewer::set_graphs $tok $out
    wviewer::regenerate $tok
    wviewer::fit $tok
    wviewer::set_target_strip 0 $tok
    update
  }
  proc mm_sdids {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [wviewer::dget $G sdid ?]
    }
    return $out
  }
  # the MIDDLE canvas row of strip `gi`'s band — a drop point that belongs to
  # that strip and to no other. {} when the band is not on screen.
  proc mm_dropy {vdrw gi} {
    set H [winfo height $vdrw]
    set lo -1; set hi -1
    for {set py 0} {$py < $H} {incr py} {
      if {[wviewer::strip_at_pixel $vdrw [expr {int(0.5 * [winfo width $vdrw])}] $py] != $gi} {
        continue
      }
      if {$lo < 0} { set lo $py }
      set hi $py
    }
    if {$lo < 0} { return {} }
    return [expr {($lo + $hi) / 2}]
  }
  # the whole gesture: press, one sub-threshold step, one real step, release.
  # Never a bare press+release — the drag only owns the pointer past 3 px.
  proc mm_drag {vdrw px py tx ty} {
    tm_ev $vdrw <ButtonPress-1> -x $px -y $py
    tm_ev $vdrw <B1-Motion> -x [expr {$px + 1}] -y [expr {$py + 1}] -state 0x100
    update
    tm_ev $vdrw <B1-Motion> -x $tx -y $ty -state 0x100
    update
    tm_ev $vdrw <ButtonRelease-1> -x $tx -y $ty -state 0x100
    update
  }
  proc mm_ranges {vdrw gi} {
    xschem new_schematic switch $vdrw
    set o {}
    foreach t {x1 x2 y1 y2} {
      set v {}
      catch {set v [xschem getprop rect 2 $gi $t]}
      lappend o $v
    }
    return $o
  }
  proc mm_mranges {tok gi} {
    set G [lindex [dict get [wviewer::layout_for $tok] graphs] $gi]
    set o {}
    foreach t {x1 x2 y1 y2} { lappend o [wviewer::dget $G $t {}] }
    return $o
  }
  # log lines whose command word is `w`, WITHIN the window that starts at index
  # `from` — the whole-log form would collect every earlier group's lines.
  proc mm_lines {w from} {
    set o {}
    foreach l [lrange $::tm_log $from end] { if {[lindex $l 0] eq $w} { lappend o $l } }
    return $o
  }
  # every viewer MUTATION line in the window — the "ONE log line per gesture"
  # witness. ⚠ `set_target_strip` is deliberately NOT in this list: the PRESS
  # re-targets (the shipped <ButtonPress-1> body, click_target), and §12.3 says
  # that line appears exactly when the press really moved the target. What this
  # item owes is one MUTATION line, and no target line for the DESTINATION —
  # that one is set in place as an internal consequence (MM12).
  proc mm_muts {from} {
    set o {}
    foreach l [lrange $::tm_log $from end] {
      if {[lsearch -exact {wviewer::move_traces wviewer::move_trace wviewer::move_strip
                           wviewer::move_trace_to_new_strip wviewer::delete_items
                           wviewer::undo wviewer::redo} [lindex $l 0]] >= 0} {
        lappend o $l
      }
    }
    return $o
  }
  # local copies of the TS* selection helpers: those are renamed away at the end
  # of the TS block above, and a shared helper would have to outlive its group.
  # Same bodies, same contracts — every strip witnessed, `-` for "nothing
  # selected" (which must never read as node 0), `st 0x4` = ControlMask.
  proc mm_sels {vdrw} {
    xschem new_schematic switch $vdrw
    set o {}
    for {set k 0} {$k < [xschem get rects 2]} {incr k} {
      set s [wviewer::selected_waves $vdrw $k]
      lappend o [expr {[llength $s] ? $s : "-"}]
    }
    return $o
  }
  proc mm_tokens {vdrw gi} {
    xschem new_schematic switch $vdrw
    set h {}; catch {set h [xschem getprop rect 2 $gi hilight_wave]}
    set s {}; catch {set s [xschem getprop rect 2 $gi sel_waves]}
    return [list $h $s]
  }
  proc mm_reset {tok vdrw} {
    xschem new_schematic switch $vdrw
    set n [xschem get rects 2]
    wviewer::with_edit $tok {
      for {set k 0} {$k < $n} {incr k} {
        xschem setprop rect 2 $k hilight_wave -1
        catch {xschem setprop rect 2 $k sel_waves {}}
      }
    }
  }
  proc mm_click {vdrw px py {st 0}} {
    tm_ev $vdrw <ButtonPress-1>   -x $px -y $py -state $st
    tm_ev $vdrw <ButtonRelease-1> -x $px -y $py -state [expr {$st | 0x100}]
    update
  }
  proc mm_px_for_node {vdrw gi want} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60 0.30 0.70} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 1} {
        if {[wviewer::trace_at $vdrw $gi $px $py] == $want} { return [list $px $py] }
      }
    }
    return {}
  }

  set mmspec {{vec_a vec_b vec_c} {vec_d} {vec_e}}
  mm_fill $tok $mmspec
  set mmP0 [mm_px_for_node $vdrw 0 0]
  set mmP1 [mm_px_for_node $vdrw 0 1]
  set mmP2 [mm_px_for_node $vdrw 0 2]
  set mmP1_0 [mm_px_for_node $vdrw 1 0]
  set mmDY2 [mm_dropy $vdrw 2]
  set mmDY1 [mm_dropy $vdrw 1]
  # STAGING TEETH: an empty pixel scan must FAIL, never quietly compare {} to {}
  check "MM0 staging: a pixel was found for every trace and for the drop rows" \
    [list [llength $mmP0] [llength $mmP1] [llength $mmP2] [llength $mmP1_0] \
          [expr {$mmDY2 ne {} ? 2 : 0}] [expr {$mmDY1 ne {} ? 2 : 0}]] {2 2 2 2 2 2}
  if {[llength $mmP0] && [llength $mmP1] && [llength $mmP2] && [llength $mmP1_0]
      && $mmDY2 ne {} && $mmDY1 ne {}} {
    set mmDX [expr {int(0.5 * [winfo width $vdrw])}]
    lassign $mmP0 mmx0 mmy0
    lassign $mmP1 mmx1 mmy1
    lassign $mmP2 mmx2 mmy2
    lassign $mmP1_0 mmxd mmyd
    check "MM0 fixture: three strips, identities A B C" \
      [list [profile $tok] [mm_sdids $tok]] {{3 1 1} {A B C}}

    # --- MM1: the whole selection travels ---------------------------------
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmx2 $mmy2 0x4
    set mmsel [wviewer::selected_waves $vdrw 0]
    check "MM0 the selection is a NON-CONTIGUOUS 2-of-3 on strip 0" $mmsel {0 2}
    check_true "MM0 ... really non-adjacent" \
      [expr {[llength $mmsel] == 2 && [lindex $mmsel 1] - [lindex $mmsel 0] > 1}]
    set mmlog0 [llength $::tm_log]
    lassign [wviewer::history_depth $tok] mmu0 mmr0
    set mmpre [dict get [wviewer::layout_for $tok] graphs]
    mm_drag $vdrw $mmx0 $mmy0 $mmDX $mmDY2
    check "MM1 both selected traces arrived on strip 2, in SOURCE order" \
      [vecs_at $tok 2] {vec_e vec_a vec_c}
    check "MM1 strip 0 kept its third trace, and only that" [vecs_at $tok 0] vec_b
    check "MM1 strip 1 is untouched" [vecs_at $tok 1] vec_d
    check "MM1 the strip IDENTITIES are unchanged (a move, not a reorder)" \
      [list [profile $tok] [mm_sdids $tok]] {{1 1 3} {A B C}}

    # --- MM2: the SELECTION followed, witnessed on EVERY strip -------------
    check "MM2 the selection followed to the destination's appended nodes" \
      [mm_sels $vdrw] {- - {1 2}}
    check "MM2 ... in BOTH tokens, with hilight_wave as the head" \
      [mm_tokens $vdrw 2] {1 {1 2}}
    # absent-means-absent: an emptied selection DROPS both tokens rather than
    # storing -1, so graph_props emits nothing for that strip
    check "MM2 ... and the source names neither of them any more" \
      [mm_tokens $vdrw 0] {{} {}}

    # --- MM12: the destination became the TARGET, with no extra log line ---
    check "MM12 the destination is the target strip" [wviewer::target_index $tok] 2
    set mmtl {}
    foreach l [mm_lines wviewer::set_target_strip $mmlog0] {
      if {[lindex $l 1] == 2} { lappend mmtl $l }
    }
    check "MM12 no separate set_target_strip line was logged for the DESTINATION" \
      $mmtl {}

    # --- MM4: exactly ONE log line, with the NORMALISED pairs --------------
    set mmnew [mm_muts $mmlog0]
    check "MM4 the whole gesture logged exactly ONE mutation line" [llength $mmnew] 1
    check "MM4 ... and it is move_traces with the normalised pairs and the token" \
      [lindex $mmnew 0] [list wviewer::move_traces {{0 0} {0 2}} 2 $tok]

    # --- MM3: exactly ONE undo point --------------------------------------
    lassign [wviewer::history_depth $tok] mmu1 mmr1
    check "MM3 the gesture took exactly ONE undo point" [expr {$mmu1 - $mmu0}] 1
    set mmpost [dict get [wviewer::layout_for $tok] graphs]
    check "MM3 one `u` returns 1" [pcall {wviewer::undo $tok}] 1
    check "MM3 ... and it put every trace back" \
      [list [vecs_at $tok 0] [vecs_at $tok 1] [vecs_at $tok 2]] \
      {{vec_a vec_b vec_c} vec_d vec_e}
    check "MM3 ... and the selection with them" [mm_sels $vdrw] {{0 2} - -}
    lassign [wviewer::history_depth $tok] mmu2 mmr2
    check "MM3 the depth moved by exactly 1 (not by the trace count)" \
      [expr {$mmu1 - $mmu2}] 1

    # --- MM4 (replay): the logged line reproduces this run -----------------
    check "MM4 replaying the logged line from the pre-move state" \
      [pcall {eval [lindex $mmnew 0]; list [vecs_at $tok 0] [vecs_at $tok 2]}] \
      {vec_b {vec_e vec_a vec_c}}
    check "MM4 ... reproduces the layout exactly" \
      [dict get [wviewer::layout_for $tok] graphs] $mmpost

    # --- MM13: still a read-only, unmodified buffer ------------------------
    xschem new_schematic switch $vdrw
    check "MM13 the viewer buffer is still readonly and unmodified" \
      [list [pcall {xschem get readonly}] [pcall {xschem get modified}]] {1 0}

    # --- MM5: a selection spanning TWO source strips -----------------------
    mm_fill $tok $mmspec
    set mmP0 [mm_px_for_node $vdrw 0 0]
    set mmP1_0 [mm_px_for_node $vdrw 1 0]
    check "MM5 staging: pixels re-found after the refill" \
      [list [llength $mmP0] [llength $mmP1_0]] {2 2}
    lassign $mmP0 mmx0 mmy0
    lassign $mmP1_0 mmxd mmyd
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmxd $mmyd 0x4
    check "MM5 staging: one selected on strip 0, one on strip 1" \
      [mm_sels $vdrw] {0 0 -}
    set mmlog0 [llength $::tm_log]
    mm_drag $vdrw $mmx0 $mmy0 $mmDX $mmDY2
    check "MM5 both sources are correctly reduced" \
      [list [vecs_at $tok 0] [vecs_at $tok 1]] {{vec_b vec_c} {}}
    check "MM5 ... and both traces arrived, ascending by (gi, ti)" \
      [vecs_at $tok 2] {vec_e vec_a vec_d}
    check "MM5 the emptied source strip SURVIVES (D-51)" \
      [list [profile $tok] [mm_sdids $tok]] {{2 0 3} {A B C}}
    check "MM5 one mutation line, carrying the cross-strip pairs" \
      [mm_muts $mmlog0] [list [list wviewer::move_traces {{0 0} {1 0}} 2 $tok]]

    # --- MM6: the destination IS one of the sources (D-44) ----------------
    mm_fill $tok $mmspec
    set mmP0 [mm_px_for_node $vdrw 0 0]
    set mmP2 [mm_px_for_node $vdrw 0 2]
    set mmP1_0 [mm_px_for_node $vdrw 1 0]
    check "MM6 staging: pixels re-found" \
      [list [llength $mmP0] [llength $mmP2] [llength $mmP1_0]] {2 2 2}
    lassign $mmP0 mmx0 mmy0
    lassign $mmP2 mmx2 mmy2
    lassign $mmP1_0 mmxd mmyd
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmx2 $mmy2 0x4
    mm_click $vdrw $mmxd $mmyd 0x4
    check "MM6 staging: two on strip 0 and one on strip 1 selected" \
      [mm_sels $vdrw] {{0 2} 0 -}
    set mmlog0 [llength $::tm_log]
    mm_drag $vdrw $mmx0 $mmy0 $mmDX $mmDY1
    check "MM6 the destination's own selected trace stayed at its index" \
      [vecs_at $tok 1] {vec_d vec_a vec_c}
    check "MM6 ... the other source is reduced" [vecs_at $tok 0] vec_b
    check "MM6 ONE mutation line, and its pairs EXCLUDE the already-there one" \
      [mm_muts $mmlog0] [list [list wviewer::move_traces {{0 0} {0 2}} 1 $tok]]

    # --- MM7: a press on an UNSELECTED trace moves only it (D-41) ---------
    # and it logs the SINGULAR wviewer::move_trace line, which is a REPLAY
    # CONTRACT — TD1/TD2/TD7 and every action log on disk already name it.
    mm_fill $tok $mmspec
    set mmP0 [mm_px_for_node $vdrw 0 0]
    set mmP1 [mm_px_for_node $vdrw 0 1]
    set mmP2 [mm_px_for_node $vdrw 0 2]
    check "MM7 staging: pixels re-found" \
      [list [llength $mmP0] [llength $mmP1] [llength $mmP2]] {2 2 2}
    lassign $mmP0 mmx0 mmy0
    lassign $mmP1 mmx1 mmy1
    lassign $mmP2 mmx2 mmy2
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmx2 $mmy2 0x4
    check "MM7 staging: nodes 0 and 2 selected, node 1 is NOT" \
      [wviewer::selected_waves $vdrw 0] {0 2}
    set mmlog0 [llength $::tm_log]
    mm_drag $vdrw $mmx1 $mmy1 $mmDX $mmDY2
    check "MM7 only the pressed (unselected) trace moved" \
      [list [vecs_at $tok 0] [vecs_at $tok 2]] {{vec_a vec_c} {vec_e vec_b}}
    check "MM7 ... and it logged the SINGULAR shipped line" \
      [mm_muts $mmlog0] [list [list wviewer::move_trace 0 1 2 $tok]]

    # --- MM8: a SAME-STRIP drop with a multi-selection is a no-op ---------
    mm_fill $tok $mmspec
    set mmP0 [mm_px_for_node $vdrw 0 0]
    set mmP2 [mm_px_for_node $vdrw 0 2]
    set mmDY0 [mm_dropy $vdrw 0]
    check "MM8 staging: pixels re-found" \
      [list [llength $mmP0] [llength $mmP2] [expr {$mmDY0 ne {} ? 2 : 0}]] {2 2 2}
    lassign $mmP0 mmx0 mmy0
    lassign $mmP2 mmx2 mmy2
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmx2 $mmy2 0x4
    set mmlog0 [llength $::tm_log]
    lassign [wviewer::history_depth $tok] mmu0 mmr0
    mm_drag $vdrw $mmx0 $mmy0 $mmDX $mmDY0
    check "MM8 nothing moved" [profile $tok] {3 1 1}
    check "MM8 nothing was logged" [mm_muts $mmlog0] {}
    check "MM8 no undo point was taken" \
      [expr {[lindex [wviewer::history_depth $tok] 0] - $mmu0}] 0

    # --- MM9: a sub-threshold press-release is still the wave-bold click --
    mm_fill $tok $mmspec
    set mmP0 [mm_px_for_node $vdrw 0 0]
    set mmP2 [mm_px_for_node $vdrw 0 2]
    check "MM9 staging: pixels re-found" [list [llength $mmP0] [llength $mmP2]] {2 2}
    lassign $mmP0 mmx0 mmy0
    lassign $mmP2 mmx2 mmy2
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmx2 $mmy2 0x4
    set mmlog0 [llength $::tm_log]
    lassign [wviewer::history_depth $tok] mmu0 mmr0
    mm_click $vdrw $mmx2 $mmy2
    check "MM9 the shipped no-travel click still COLLAPSES the selection" \
      [mm_sels $vdrw] {2 - -}
    check "MM9 nothing moved" [profile $tok] {3 1 1}
    check "MM9 nothing was logged and no undo point was taken" \
      [list [mm_muts $mmlog0] \
            [expr {[lindex [wviewer::history_depth $tok] 0] - $mmu0}]] {{} 0}

    # --- MM10: Escape mid-multi-drag abandons everything ------------------
    mm_fill $tok $mmspec
    set mmP0 [mm_px_for_node $vdrw 0 0]
    set mmP2 [mm_px_for_node $vdrw 0 2]
    check "MM10 staging: pixels re-found" [list [llength $mmP0] [llength $mmP2]] {2 2}
    lassign $mmP0 mmx0 mmy0
    lassign $mmP2 mmx2 mmy2
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmx2 $mmy2 0x4
    set mmlog0 [llength $::tm_log]
    lassign [wviewer::history_depth $tok] mmu0 mmr0
    tm_ev $vdrw <ButtonPress-1> -x $mmx0 -y $mmy0
    tm_ev $vdrw <B1-Motion> -x $mmDX -y $mmDY2 -state 0x100
    update
    xschem new_schematic switch $vdrw
    check_true "MM10 mid-drag: the multi preview really is armed" \
      [expr {[pcall {xschem get graph_preview_set}] ne {}}]
    check "MM10 mid-drag: the destination wears the drop frame" \
      [pcall {xschem getprop rect 2 2 reorder_handle}] 4
    check_true "MM10 Escape reports a drag WAS armed" \
      [pcall {wviewer::strip_drag_cancel $vdrw}]
    xschem new_schematic switch $vdrw
    check "MM10 the preview is cleared" [pcall {xschem get graph_preview_set}] {}
    check "MM10 the drop frame is gone" \
      [pcall {xschem getprop rect 2 2 reorder_handle}] 1
    check "MM10 the pointer is restored" [pcall {$vdrw cget -cursor}] {}
    check "MM10 nothing moved, nothing logged, no undo point" \
      [list [profile $tok] [mm_muts $mmlog0] \
            [expr {[lindex [wviewer::history_depth $tok] 0] - $mmu0}]] {{3 1 1} {} 0}
    tm_ev $vdrw <ButtonRelease-1> -x $mmDX -y $mmDY2 -state 0x100
    update

    # --- MM11: an EMPTY destination is put back to AUTO ranges (D-55) -----
    mm_fill $tok {{vec_a vec_b vec_c} {vec_d} {}}
    # give the empty strip a deliberately WRONG stored window, the state
    # capture_live_graph_state would have frozen onto it
    set mmgs [dict get [wviewer::layout_for $tok] graphs]
    wviewer::set_graphs $tok [lreplace $mmgs 2 2 \
      [dict replace [lindex $mmgs 2] x1 -5 x2 -4 y1 100 y2 200]]
    wviewer::regenerate $tok
    update
    set mmfroz [mm_ranges $vdrw 2]
    set mmP0 [mm_px_for_node $vdrw 0 0]
    set mmP2 [mm_px_for_node $vdrw 0 2]
    set mmDY2 [mm_dropy $vdrw 2]
    check "MM11 staging: pixels re-found and the stale window is really on the rect" \
      [list [llength $mmP0] [llength $mmP2] [expr {$mmDY2 ne {} ? 2 : 0}] $mmfroz] \
      {2 2 2 {-5 -4 100 200}}
    lassign $mmP0 mmx0 mmy0
    lassign $mmP2 mmx2 mmy2
    mm_reset $tok $vdrw
    mm_click $vdrw $mmx0 $mmy0
    mm_click $vdrw $mmx2 $mmy2 0x4
    mm_drag $vdrw $mmx0 $mmy0 $mmDX $mmDY2
    check "MM11 both traces landed on the empty strip" [vecs_at $tok 2] {vec_a vec_c}
    check "MM11 the destination's model ranges went back to auto" \
      [mm_mranges $tok 2] {{} {} {} {}}
    check_true "MM11 ... and regenerate re-fitted the rect away from the stale window" \
      [expr {[mm_ranges $vdrw 2] ne $mmfroz}]

    mm_fill $tok $mmspec
  } else {
    puts "  MM0 staging FAILED above — the MM legs could not run"
  }
  foreach mmp {mm_fill mm_sdids mm_dropy mm_drag mm_ranges mm_mranges mm_lines
               mm_muts mm_sels mm_tokens mm_reset mm_click mm_px_for_node} {
    rename $mmp {}
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
