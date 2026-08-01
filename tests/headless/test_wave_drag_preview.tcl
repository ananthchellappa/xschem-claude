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

# --- DV8-DV12: the arm is a SET (issue 0192) --------------------------------
# `xschem set graph_preview <gi> <ni> <scale> [<gi> <ni> ...]`, read back through
# the unchanged HEAD getter plus the NEW `xschem get graph_preview_set`.
#
# The cap is READ OUT OF src/xschem.h rather than frozen here, the az_define
# idiom from test_wave_axis_zoom.tcl: GRAPH_MAX_PREVIEW_WAVES is a tunable, and a
# leg holding a copy of it stops testing the product the moment somebody changes
# it. {} when it cannot be read -> the leg FAILS rather than skipping.
proc dv_define {path name} {
  if {[catch {set fp [open $path r]}]} { return {} }
  set src [read $fp]
  close $fp
  foreach line [split $src "\n"] {
    if {[regexp "^\\s*#define\\s+$name\\s+(\[-+0-9\]+)\\s*\$" $line -> v]} {
      if {[string is integer -strict $v]} { return $v }
    }
  }
  return {}
}
set dv_cap [dv_define [file join $repo src xschem.h] GRAPH_MAX_PREVIEW_WAVES]
check_true "DV8 GRAPH_MAX_PREVIEW_WAVES was read out of src/xschem.h: {$dv_cap}" \
  [expr {[string is integer -strict "$dv_cap"] && $dv_cap > 1}]
if {![string is integer -strict "$dv_cap"]} { set dv_cap 64 }

# ⚠ THE COMPATIBILITY LEG. The HEAD getter's output must not move: seven shipped
# DV legs and the whole single-trace era rest on `<gi> <ni> <scale>`. SAB-5
# (arming only the first pair in Tcl) must leave this GREEN — it tests the C
# storage, not the Tcl arm.
check "DV8 trailing pairs leave the HEAD getter byte-identical" \
  [pcall {xschem set graph_preview 1 2 0.7 0 3 2 5; xschem get graph_preview}] {1 2 0.7}
check "DV8 ... and the whole set comes back head-first from the new getter" \
  [pcall {xschem get graph_preview_set}] {1 2 0 3 2 5}
check "DV9 the set is empty at rest" \
  [pcall {xschem set graph_preview 0; xschem get graph_preview_set}] {}
check "DV9 ... after the short disarm form" \
  [pcall {xschem set graph_preview 1 2 0.7 0 3; xschem set graph_preview 0
          xschem get graph_preview_set}] {}
check "DV9 ... and after the zero-scale disarm form" \
  [pcall {xschem set graph_preview 1 2 0.7 0 3; xschem set graph_preview 1 1 0
          xschem get graph_preview_set}] {}
check "DV10 the three-argument form is the plural case with n = 1" \
  [pcall {xschem set graph_preview 0 1 0.7; xschem get graph_preview_set}] {0 1}
check "DV10 ... and its head is unchanged" [pcall {xschem get graph_preview}] {0 1 0.7}
# a set LONGER than the cap: truncated, no error, head intact. The move itself is
# uncapped (xschem.h) -- only the chrome is bounded.
set dv11cmd [list xschem set graph_preview 3 7 0.55]
for {set k 0} {$k < $dv_cap + 5} {incr k} { lappend dv11cmd 1 $k }
check "DV11 an over-long set does not error" [pcall {eval $dv11cmd; expr 1}] 1
check "DV11 ... it is truncated to GRAPH_MAX_PREVIEW_WAVES ($dv_cap) pairs" \
  [expr {[llength [pcall {xschem get graph_preview_set}]] / 2}] $dv_cap
check "DV11 ... and the HEAD is not corrupted" [pcall {xschem get graph_preview}] {3 7 0.55}
check "DV11 ... the head is still element 0 of the set" \
  [lrange [pcall {xschem get graph_preview_set}] 0 1] {3 7}
check "DV12 a trailing odd argument (a gi with no ni) is ignored" \
  [pcall {xschem set graph_preview 2 4 0.8 9; xschem get graph_preview_set}] {2 4}
check "DV12 ... and the head is unaffected" [pcall {xschem get graph_preview}] {2 4 0.8}
pcall {xschem set graph_preview 0}
check "DV12 disarmed again, in both getters" \
  [list [pcall {xschem get graph_preview}] [pcall {xschem get graph_preview_set}]] {0 {}}

# --- DM6: the SOURCE-LEVEL leg, both arms -----------------------------------
# The one-writer / one-predicate rule, asserted where a behavioural leg cannot
# see it: with a single carried trace a bare `preview_gi == wcnt` comparison and
# graph_preview_has() agree EXACTLY, so no gesture leg in this file can tell them
# apart. This is the LS5 / MS13 idiom (count on CODE lines only -- the comments
# around the code deliberately quote the very strings being counted).
proc dm_count_code {src pat} {
  set n 0
  foreach line [split $src "\n"] {
    set t [string trimleft $line]
    if {[string index $t 0] eq "*"} { continue }
    if {[string range $t 0 1] eq "/*" || [string range $t 0 1] eq "//"} { continue }
    incr n [regexp -all $pat $line]
  }
  return $n
}
set dm6src {}
if {![catch {set fp [open [file join $repo src draw.c] r]}]} {
  set dm6src [read $fp]
  close $fp
}
check_true "DM6 src/draw.c was read" [expr {[string length $dm6src] > 10000}]
check "DM6 graph_preview_has() is defined exactly once" \
  [dm_count_code $dm6src {^int graph_preview_has\(}] 1
check "DM6 ... and there is exactly one call site (the ONE draw-side test)" \
  [expr {[dm_count_code $dm6src {graph_preview_has\(}] - 1}] 1
check "DM6 no bare preview_gi / preview_wave comparison survives in draw.c" \
  [dm_count_code $dm6src {(preview_gi|preview_wave)\s*==|==\s*xctx->graph_preview_(gi|wave)}] 0
check "DM6 the ONE writer is the only thing that assigns the set/count" \
  [dm_count_code $dm6src {xctx->graph_preview_n\s*=[^=]}] 2
check "DM6 ... and graph_preview_arm() is defined exactly once" \
  [dm_count_code $dm6src {^void graph_preview_arm\(}] 1
# ⚠ THE PREDICATE'S OWN TEETH, and they can only be source-level. Whether
# graph_preview_has() discriminates on the GI as well as the node index is a
# question about PIXELS: a version that matched by node alone would shrink node 2
# of EVERY strip while a cross-strip drag was in flight, and no headless leg can
# see that (the arm, which is what `get graph_preview_set` reads back, is
# identical either way). So the two comparison terms are pinned here, the MS13
# ms_fnbody idiom.
proc dm_fnbody {src sig} {
  set out {}
  set in 0
  foreach line [split $src "\n"] {
    if {!$in} {
      if {[string first $sig $line] == 0} { set in 1 }
      continue
    }
    lappend out $line
    if {$line eq "\}"} { break }
  }
  return [join $out "\n"]
}
set dm6has [dm_fnbody $dm6src {int graph_preview_has(}]
check_true "DM6 the graph_preview_has() body was located" \
  [expr {[string length $dm6has] > 80}]
check "DM6 the predicate matches on the set element's GI" \
  [dm_count_code $dm6has {graph_preview_set_gi\[[a-z]+\] == gi}] 1
check "DM6 ... AND on its node index, in the same test" \
  [dm_count_code $dm6has {graph_preview_set_wave\[[a-z]+\] == wcnt}] 1
check "DM6 ... and it short-circuits on the scale, so at rest it costs one compare" \
  [dm_count_code $dm6has {graph_preview_scale == 0\.0\) return 0}] 1

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

    # ========================================================================
    # DM* — the MULTI-trace arm (issue 0192)
    # ========================================================================
    # Dragging one SELECTED trace carries the whole selection, and every carried
    # trace wears the shrink. Here that means: the arm reaches C with the whole
    # SET of (gi, node) pairs, head first, and the head keeps its old meaning.
    #
    # ⚠ The fixture is widened on purpose: strip 0 gets THREE drawn traces plus
    # its vec-less one, so a 2-of-3 selection can be NON-ADJACENT (nodes 0 and 2)
    # — with nodes 0 and 1 an implementation that armed "the pressed trace and
    # its neighbour" would pass. Strip 1 keeps one trace, so a cross-strip
    # selection is available for DM2.
    pcall {xschem new_schematic switch $vdrw}
    pcall {xschem raw add vec_d {vsweep 7 +}}
    proc dm_fill {tok} {
      wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
      foreach {gi vec} {0 vec_a 0 vec_b 0 vec_c 1 vec_d} {
        set e [wviewer::add_trace $tok $gi $vec]
        if {$e ne {}} { puts "  dm_fill: add_trace $vec -> $e" }
      }
      set gs [dict get [wviewer::layout_for $tok] graphs]
      set G [lindex $gs 0]
      set trs [linsert [wviewer::dget $G traces {}] 0 \
                 [dict create expr {} name {} vec {} color 7]]
      wviewer::set_graphs $tok [lreplace $gs 0 0 [dict replace $G traces $trs]]
      wviewer::regenerate $tok
      wviewer::fit $tok
      update
    }
    proc dm_px {vdrw gi want} {
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      foreach fx {0.50 0.40 0.60 0.30 0.70} {
        set px [expr {int($fx * $W)}]
        for {set py 2} {$py < $H} {incr py 1} {
          if {[wviewer::trace_at $vdrw $gi $px $py] == $want} { return [list $px $py] }
        }
      }
      return {}
    }
    # a plain click selects; 0x4 (Control) adds — the SHIPPED bindings, never a
    # hand-written token (issue 0175's own legs do it this way)
    proc dm_click {vdrw px py {st 0}} {
      dp_ev $vdrw <ButtonPress-1>   -x $px -y $py -state $st
      dp_ev $vdrw <ButtonRelease-1> -x $px -y $py -state [expr {$st | 0x100}]
      update
    }
    proc dm_set {vdrw} {
      xschem new_schematic switch $vdrw
      return [xschem get graph_preview_set]
    }

    dm_fill $tok
    set dmA [dm_px $vdrw 0 0]
    set dmB [dm_px $vdrw 0 1]
    set dmC [dm_px $vdrw 0 2]
    set dmD [dm_px $vdrw 1 0]
    # STAGING TEETH: no pixel means the legs below would compare {} against {}
    # and pass for the wrong reason. This FAILS rather than skipping.
    check "DM0 staging: a pixel was found for every trace of the fixture" \
      [list [llength $dmA] [llength $dmB] [llength $dmC] [llength $dmD]] {2 2 2 2}
    if {[llength $dmA] && [llength $dmB] && [llength $dmC] && [llength $dmD]} {
      lassign $dmA ax ay
      lassign $dmB bx by
      lassign $dmC cx cy
      lassign $dmD dx dy
      dm_click $vdrw $ax $ay
      dm_click $vdrw $cx $cy 0x4
      set dmsel [wviewer::selected_waves $vdrw 0]
      check "DM0 the shipped bindings really selected TWO traces of strip 0" $dmsel {0 2}
      check_true "DM0 ... and they are NOT ADJACENT (nodes 0 and 2)" \
        [expr {[llength $dmsel] == 2 && [lindex $dmsel 1] - [lindex $dmsel 0] > 1}]
      check "DM0 the model index space really differs from the node space" \
        [list [llength [wviewer::dget \
                 [lindex [dict get [wviewer::layout_for $tok] graphs] 0] traces {}]] \
              [wviewer::node_count \
                 [lindex [dict get [wviewer::layout_for $tok] graphs] 0]]] {4 3}

      # --- DM1: the whole selection is armed ------------------------------
      dp_ev $vdrw <ButtonPress-1> -x $ax -y $ay
      dp_ev $vdrw <B1-Motion> -x [expr {$ax + 40}] -y [expr {$ay + 40}] -state 0x100
      update
      check "DM1 a >3 px drag from a SELECTED trace arms BOTH node indices" \
        [dm_set $vdrw] {0 0 0 2}
      check "DM1 ... and the HEAD getter still answers the pressed trace" \
        [preview_of $vdrw] [list 0 0 [wviewer::drag_shrink]]
      check "DM1 ... the head is element 0 of the set" \
        [lrange [dm_set $vdrw] 0 1] [lrange [preview_of $vdrw] 0 1]
      pcall {wviewer::strip_drag_cancel $vdrw}
      # the head is set ELEMENT 0 (ascending), not "whatever was pressed" —
      # pressing the OTHER member of the same selection arms the same set
      dp_ev $vdrw <ButtonPress-1> -x $cx -y $cy
      dp_ev $vdrw <B1-Motion> -x [expr {$cx + 40}] -y [expr {$cy + 40}] -state 0x100
      update
      check "DM1 pressing the other member arms the same set, same order" \
        [dm_set $vdrw] {0 0 0 2}
      pcall {wviewer::strip_drag_cancel $vdrw}

      # --- DM2: the selection SPANS strips --------------------------------
      dm_click $vdrw $ax $ay
      dm_click $vdrw $dx $dy 0x4
      check "DM2 staging: one trace selected on strip 0 and one on strip 1" \
        [list [wviewer::selected_waves $vdrw 0] [wviewer::selected_waves $vdrw 1]] {0 0}
      dp_ev $vdrw <ButtonPress-1> -x $ax -y $ay
      dp_ev $vdrw <B1-Motion> -x [expr {$ax + 40}] -y [expr {$ay + 40}] -state 0x100
      update
      check "DM2 the armed set carries pairs with DIFFERENT gi" [dm_set $vdrw] {0 0 1 0}
      check_true "DM2 ... i.e. TWO pairs, whose gi values really differ" \
        [expr {[llength [dm_set $vdrw]] == 4 &&
               [lindex [dm_set $vdrw] 0] != [lindex [dm_set $vdrw] 2]}]
      pcall {wviewer::strip_drag_cancel $vdrw}

      # --- DM3: a press on an UNSELECTED trace carries ONLY it (D-41) ------
      dm_click $vdrw $ax $ay
      dm_click $vdrw $cx $cy 0x4
      check "DM3 staging: nodes 0 and 2 selected, node 1 is NOT" \
        [wviewer::selected_waves $vdrw 0] {0 2}
      dp_ev $vdrw <ButtonPress-1> -x $bx -y $by
      dp_ev $vdrw <B1-Motion> -x [expr {$bx + 40}] -y [expr {$by + 40}] -state 0x100
      update
      check "DM3 exactly ONE pair is armed, and it is the pressed trace" \
        [dm_set $vdrw] {0 1}
      check "DM3 ... and the press did not disturb the selection" \
        [wviewer::selected_waves $vdrw 0] {0 2}

      # --- DM4: every teardown path clears the WHOLE set -------------------
      dp_ev $vdrw <ButtonRelease-1> -x [expr {$bx + 40}] -y [expr {$by + 40}] -state 0x100
      update
      check "DM4 the drop clears the set" [dm_set $vdrw] {}
      dm_fill $tok
      set dmA [dm_px $vdrw 0 0]
      set dmC [dm_px $vdrw 0 2]
      check "DM4 staging: the refilled fixture still yields two pixels" \
        [list [llength $dmA] [llength $dmC]] {2 2}
      lassign $dmA ax ay
      lassign $dmC cx cy
      dm_click $vdrw $ax $ay
      dm_click $vdrw $cx $cy 0x4
      dp_ev $vdrw <ButtonPress-1> -x $ax -y $ay
      dp_ev $vdrw <B1-Motion> -x [expr {$ax + 40}] -y [expr {$ay + 40}] -state 0x100
      update
      check_true "DM4 armed again for the cancel leg" [expr {[dm_set $vdrw] ne {}}]
      check_true "DM4 the cancel reports a drag WAS armed" \
        [pcall {wviewer::strip_drag_cancel $vdrw}]
      check "DM4 ... and it cleared the whole set" [dm_set $vdrw] {}
      check "DM4 a bare trace_drag_reset on nothing leaves it empty" \
        [list [pcall {wviewer::trace_drag_reset $tok}] [dm_set $vdrw]] {0 {}}

      # --- DM5: DG4 for N — the pick must not move under a MULTI preview ---
      set dmbefore {}
      set dmafter {}
      xschem new_schematic switch $vdrw
      pcall {xschem set graph_preview 0}
      for {set k -20} {$k <= 20} {incr k 5} {
        lappend dmbefore [wviewer::trace_at $vdrw 0 $ax [expr {$ay + $k}]]
      }
      xschem new_schematic switch $vdrw
      pcall {xschem set graph_preview 0 0 [wviewer::drag_shrink] 0 2}
      check "DM5 staging: a MULTI preview really is armed" \
        [dm_set $vdrw] {0 0 0 2}
      for {set k -20} {$k <= 20} {incr k 5} {
        lappend dmafter [wviewer::trace_at $vdrw 0 $ax [expr {$ay + $k}]]
      }
      check "DM5 graph_trace_at is UNCHANGED under a MULTI preview" $dmafter $dmbefore
      check_true "DM5 the swept column really does cross a trace" \
        [expr {[lsearch -glob $dmbefore {[0-9]*}] >= 0}]
      xschem new_schematic switch $vdrw
      pcall {xschem set graph_preview 0}
    } else {
      puts "  DM0 staging FAILED above — the DM legs could not run"
    }
    rename dm_fill {}
    rename dm_px {}
    rename dm_click {}
    rename dm_set {}
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
