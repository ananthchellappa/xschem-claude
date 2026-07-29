# tests/headless/test_wave_drag_preview.tcl — ASE Waveform Viewer
# Mid-drag shrink preview of the dragged trace (viewer plan item 6,
# doc/claude/suggestions/plan_viewer_enhancements_2026-07.md; contract in
# doc/claude/specs/waveform_viewer.md)
#
# The feature: while a trace is being dragged to another strip (decision D-E:
# the TRACE drag, not the strip reorder) it is drawn vertically shrunk about the
# plot box centre, in BOTH axes. Render state only — three transient xctx numbers, no prop
# token, no model write, no undo point, and never in an export.
#
# What is asserted here:
#   DP*  the PURE half, no window and no DISPLAY: the rc knob and its fallbacks
#   DN*  no-window legs: arming and clearing never throw when nothing resolves
#   DV*  the C VERB: `xschem set graph_preview` / `get graph_preview` round-trip,
#        the disarm forms, and that it is per-CONTEXT rather than global
#   DG1  arming from the real gesture: a >3 px trace drag arms the preview for
#        the picked trace, a sub-threshold one does not
#   DG2  the NODE-index mapping: the C side is armed with the node index, not
#        the model trace index (they differ once any trace has an empty `vec`)
#   DG3  teardown: the drop, a cancel, and Escape all disarm
#   DG4  ⚠ THE REGRESSION GUARD the plan asked for: `graph_trace_at` answers are
#        UNCHANGED while a preview is armed. The preview is visual only, so the
#        drop-target maths must not move under it
#   DG5  the preview never reaches the MODEL: no rect prop, no undo point, no
#        log line, buffer unmodified
#   DG6  the STRIP reorder drag arms NOTHING (decision D-E)
#   DG7  a redraw with a preview armed does not throw, and the model survives it
#
# NOT asserted (stated, not hidden): that the trace LOOKS 10 % shorter. Nothing
# here can read pixels back. What IS asserted is that the arming reaches C with
# the right numbers, that the gate is transient, and that nothing else moves.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_drag_preview.tcl
# (add --nogui to run only the DP*/DN* legs)

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

set no_recent_files 1

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvdragprev]

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
# DP* — the rc knob
# ============================================================================
check "DP1 the default shrink is 0.7 (a 30 % shrink, review 2026-07-29)" \
  [wviewer::drag_shrink] 0.7
set ::wviewer_drag_shrink 0.75
check "DP2 an rc value in range is used" [wviewer::drag_shrink] 0.75
set ::wviewer_drag_shrink 1.0
check "DP3 1.0 is legal — it disables the effect, not the drag" \
  [wviewer::drag_shrink] 1.0
foreach {v why} {0 {0 would disarm rather than shrink}
                 -0.5 {a negative would MIRROR the trace}
                 1.5 {above 1 would magnify}
                 abc {unparseable}
                 {} {empty}} {
  set ::wviewer_drag_shrink $v
  check "DP4 '$v' falls back to the default ($why)" [wviewer::drag_shrink] 0.7
}
unset ::wviewer_drag_shrink
check "DP5 with the var unset the default stands" [wviewer::drag_shrink] 0.7

# ============================================================================
# DN* — no window needed
# ============================================================================
check "DN1 arming an unknown token -> 0 (no throw)" \
  [pcall {wviewer::drag_preview_arm no/such/token 0 0}] 0
check "DN2 clearing an unknown token -> 0 (no throw)" \
  [pcall {wviewer::drag_preview_clear no/such/token}] 0

# ============================================================================
# DV* — the C verb, reachable without a viewer window
# ============================================================================
check "DV1 nothing is armed at rest" [pcall {xschem get graph_preview}] 0
check "DV2 arming round-trips gi, node and scale" \
  [pcall {xschem set graph_preview 2 1 0.9; xschem get graph_preview}] {2 1 0.9}
check "DV3 a fractional scale survives verbatim" \
  [pcall {xschem set graph_preview 0 3 0.755; xschem get graph_preview}] {0 3 0.755}
check "DV4 the short form disarms" \
  [pcall {xschem set graph_preview 0; xschem get graph_preview}] 0
check "DV5 a ZERO scale disarms (0.0 is the off value, not a scale)" \
  [pcall {xschem set graph_preview 1 1 0; xschem get graph_preview}] 0
# teeth: the getter must not be answering a constant
check_true "DV6 two different armings give two different answers" \
  [expr {[pcall {xschem set graph_preview 1 0 0.5; xschem get graph_preview}] ne
         [pcall {xschem set graph_preview 2 0 0.5; xschem get graph_preview}]}]
pcall {xschem set graph_preview 0}
check "DV7 disarmed again" [pcall {xschem get graph_preview}] 0

# ============================================================================
# DG* — GUI legs
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
  proc profile {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [llength [wviewer::dget $G traces {}]]
    }
    return $out
  }
  proc preview_of {vdrw} {
    xschem new_schematic switch $vdrw
    return [xschem get graph_preview]
  }
  set ::dpt 100000
  proc dp_ev {w seq args} {
    set ::dpt [expr {$::dpt + 1000}]
    eval [list event generate $w $seq -time $::dpt] $args
  }

  # ⚠ Strip 0 carries a VEC-LESS trace at model index 0. That is deliberate and
  # load-bearing: a trace with no `vec` occupies a model slot and no NODE slot,
  # so model and node indices DIVERGE by one from there on. Without it the two
  # spaces coincide and DG2 — "the C side is armed with the node index" — passes
  # just as well against code that armed with the model index (verified: it did).
  # add_trace cannot make one (it refuses an empty expression), so it is planted
  # into the model directly; graph_props skips it, so nothing is drawn for it.
  proc fill_viewer {tok} {
    wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
    foreach {gi vec} {0 vec_a 0 vec_b 1 vec_c} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  fill_viewer: add_trace $vec -> $e" }
    }
    set gs [dict get [wviewer::layout_for $tok] graphs]
    set G [lindex $gs 0]
    set trs [linsert [wviewer::dget $G traces {}] 0 \
               [dict create expr {} name {} vec {} color 7]]
    wviewer::set_graphs $tok [lreplace $gs 0 0 [dict replace $G traces $trs]]
    wviewer::regenerate $tok
    wviewer::fit $tok
  }
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

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check "DG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: DG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set ::dp_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::dp_log $line }

  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvdp.raw dc vsweep 0 1.0 0.02}
  foreach {v ex} {vec_a {vsweep 1 +} vec_b {vsweep 3 +} vec_c {vsweep 5 +}} {
    pcall {xschem raw add $v $ex}
  }
  set rawvars [split [pcall {xschem raw list}] "\n"]
  check_true "DG0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $rawvars vec_a] >= 0}]

  fill_viewer $tok
  set hit [find_trace_px $vdrw 0]
  if {![llength $hit]} {
    puts "SKIPPED: DG1-DG7 (no pixel on a trace — window too small to plot in)"
  } else {
    lassign $hit tpx tpy tni

    # --- DG1: arming from the real gesture -----------------------------------
    check "DG1 nothing armed before the gesture" [preview_of $vdrw] 0
    # a press followed by a SUB-threshold motion is still a click, not a drag
    dp_ev $vdrw <ButtonPress-1> -x $tpx -y $tpy
    dp_ev $vdrw <B1-Motion> -x [expr {$tpx + 2}] -y $tpy -state 0x100
    update
    check "DG1 a sub-threshold motion arms NOTHING (it is still a click)" \
      [preview_of $vdrw] 0
    # past the threshold it is a drag, and the trace is picked up
    dp_ev $vdrw <B1-Motion> -x [expr {$tpx + 40}] -y [expr {$tpy + 40}] -state 0x100
    update
    set arm [preview_of $vdrw]
    check_true "DG1 a >3 px drag arms the preview" [expr {$arm ne {0}}]
    check "DG1 it is armed on the strip the trace came from, at the shrink factor" \
      [list [lindex $arm 0] [lindex $arm 2]] [list 0 [wviewer::drag_shrink]]

    # --- DG2: NODE index, not model trace index ------------------------------
    check "DG2 the armed wave is the NODE index the engine answered" \
      [lindex $arm 1] $tni
    # THE TEETH: the fixture's vec-less trace makes the two spaces differ, so
    # arming with the model index would have given a different number here.
    set gs [dict get [wviewer::layout_for $tok] graphs]
    set mti [wviewer::trace_index_of_node [lindex $gs 0] $tni]
    check "DG2 fixture: three model traces, two node slots" \
      [list [llength [wviewer::dget [lindex $gs 0] traces {}]] \
            [wviewer::node_count [lindex $gs 0]]] {3 2}
    check_true "DG2 fixture: the model index and the node index really DIFFER" \
      [expr {$mti != $tni}]
    check_true "DG2 so the armed value is not the model index" \
      [expr {[lindex $arm 1] != $mti}]
    check_true "DG2 node_index_of_trace is the mapping used" \
      [expr {[wviewer::node_index_of_trace [lindex $gs 0] $mti] == $tni}]

    # --- DG4: the drop-target maths must not move under the preview ----------
    # ⚠ THE regression guard the plan asked for: the preview is VISUAL ONLY.
    # Measured with the preview armed, against the answers taken before it was.
    set before {}
    set after {}
    xschem new_schematic switch $vdrw
    pcall {xschem set graph_preview 0}
    for {set k -20} {$k <= 20} {incr k 5} {
      lappend before [wviewer::trace_at $vdrw 0 $tpx [expr {$tpy + $k}]]
    }
    xschem new_schematic switch $vdrw
    pcall {xschem set graph_preview 0 $tni [wviewer::drag_shrink]}
    for {set k -20} {$k <= 20} {incr k 5} {
      lappend after [wviewer::trace_at $vdrw 0 $tpx [expr {$tpy + $k}]]
    }
    check "DG4 graph_trace_at is UNCHANGED while a preview is armed" $after $before
    # teeth: the sampled column must actually contain a hit, or "unchanged"
    # would be comparing two lists of -1
    check_true "DG4 the sampled column really does cross a trace" \
      [expr {[lsearch -glob $before {[0-9]*}] >= 0}]
    xschem new_schematic switch $vdrw
    pcall {xschem set graph_preview 0}

    # --- DG5: nothing reaches the model --------------------------------------
    set nlog [llength $::dp_log]
    lassign [wviewer::history_depth $tok] u0 r0
    xschem new_schematic switch $vdrw
    pcall {xschem set graph_preview 0 $tni 0.9}
    catch {xschem redraw}
    check "DG5 the buffer is not modified by an armed preview" \
      [pcall {xschem get modified}] 0
    check "DG5 no rect prop was written (no `preview` token exists)" \
      [pcall {xschem getprop rect 2 0 preview}] {}
    check "DG5 no log line" [expr {[llength $::dp_log] - $nlog}] 0
    lassign [wviewer::history_depth $tok] u1 r1
    check "DG5 no undo point" [expr {$u1 - $u0}] 0
    # {3 1}: strip 0 holds the two drawn traces PLUS the fixture's vec-less one
    check "DG5 the model is untouched" [profile $tok] {3 1}

    # --- DG7: a redraw with a preview armed is harmless ----------------------
    check "DG7 a redraw with the preview armed does not throw" \
      [pcall {xschem redraw; expr 1}] 1
    check "DG7 and the model survived it" [profile $tok] {3 1}
    xschem new_schematic switch $vdrw
    pcall {xschem set graph_preview 0}

    # --- DG3: teardown --------------------------------------------------------
    # finish the drag that DG1 started: the release drops the trace and must
    # leave nothing armed
    dp_ev $vdrw <ButtonRelease-1> -x [expr {$tpx + 40}] -y [expr {$tpy + 40}] -state 0x100
    update
    check "DG3 the drop disarms the preview" [preview_of $vdrw] 0
    # an explicit cancel (Escape's path) disarms too
    fill_viewer $tok
    dp_ev $vdrw <ButtonPress-1> -x $tpx -y $tpy
    dp_ev $vdrw <B1-Motion> -x [expr {$tpx + 40}] -y $tpy -state 0x100
    update
    check_true "DG3 armed again for the cancel leg" [expr {[preview_of $vdrw] ne {0}}]
    check_true "DG3 the cancel reports a drag WAS armed" \
      [pcall {wviewer::strip_drag_cancel $vdrw}]
    check "DG3 and it disarmed the preview" [preview_of $vdrw] 0
    # a bare reset with nothing armed is safe and leaves it disarmed
    check "DG3 resetting an unarmed drag is a no-op" \
      [pcall {wviewer::trace_drag_reset $tok}] 0
    check "DG3 still disarmed" [preview_of $vdrw] 0

    # --- DG6: the STRIP reorder gets NO preview (decision D-E) ---------------
    # a press on empty waveform space arms the strip reorder, not a trace drag
    fill_viewer $tok
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set epx -1; set epy -1
    for {set py 2} {$py < $H} {incr py 2} {
      set px [expr {int(0.50 * $W)}]
      if {[wviewer::strip_at_pixel $vdrw $px $py] != 0} { continue }
      if {[wviewer::trace_at $vdrw 0 $px $py] < 0} { set epx $px; set epy $py; break }
    }
    if {$epx >= 0} {
      dp_ev $vdrw <ButtonPress-1> -x $epx -y $epy
      dp_ev $vdrw <B1-Motion> -x $epx -y [expr {$epy + 40}] -state 0x100
      update
      check "DG6 D-E: a STRIP reorder drag arms no preview" [preview_of $vdrw] 0
      dp_ev $vdrw <ButtonRelease-1> -x $epx -y [expr {$epy + 40}] -state 0x100
      update
      check "DG6 and none after its release either" [preview_of $vdrw] 0
    } else {
      puts "SKIPPED: DG6 (no empty pixel in strip 0)"
    }
  }

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: DG* GUI legs (no DISPLAY)"
}

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_drag_preview: $npass passed, $fail failed"
# run_suites.sh classifies on the literal string `ALL PASS` in the last RESULT
# line, and on exit status.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
