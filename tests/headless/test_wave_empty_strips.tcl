# tests/headless/test_wave_empty_strips.tcl — ASE Waveform Viewer
# "Delete Empty Strips" (viewer plan item 5,
# doc/claude/suggestions/plan_viewer_enhancements_2026-07.md; contract in
# doc/claude/specs/waveform_viewer.md)
#
# The feature: bare `e` in the viewer deletes every strip that holds no traces,
# EXCEPT the tool-owned auto-plot strip (decision D-D) and except the last strip
# standing (decision D-C). Remappable from an rc file; logged replayably; one
# undo point.
#
# What is asserted here:
#   EP*  the PURE half, literal lists, no window and no DISPLAY:
#        remove_graphs, index_after_removal (the deletion twin of
#        reordered_index) and empty_strips_to_delete — which is where both user
#        decisions live, so D-C and D-D are pinned by assertions rather than by
#        a comment
#   EN*  no-window legs: delete_empty_strips never throws when no viewer
#        resolves — unknown token, omitted token, foreign canvas
#   EG1  the DELETION itself: strips with traces survive, empty ones go, the
#        model list and the layer-2 rect count agree, modified stays 0
#   EG2  D-D: the auto-plot strip is SPARED even though it is traceless
#   EG3  D-C: `e` on a window holding one empty strip is a NO-OP — no mutation,
#        no undo point, and NO log line (the move_strip `from == to` rule)
#   EG4  the stored TARGET follows graph identity across the deletion, and a
#        target that was itself deleted lands on a live strip (never dangles)
#   EG5  MARKERS: a marker on a doomed strip takes its `prev` links with it —
#        the delta partner in a SURVIVING strip is swept, not left dangling
#   EG6  UNDO: exactly one `u` restores the deleted strips (one undo point per
#        gesture, snapshot taken BEFORE the mutation)
#   EG7  replayable logging: exactly one `wviewer::delete_empty_strips <token>`
#        line per real deletion, explicit token, and replaying it reproduces
#        the state
#   EG8  the binding SEAM: bare `e` is on the `WaveViewer` bindtag, survives the
#        strip_bindings sweep, and is NOT on the canvas widget
#   EG9  a REAL `e` key event on the viewer canvas deletes the empty strips
#   EG10 REMAPPABILITY from an rc file (the "rc wins" rule)
#   EG11 Graph > Delete Empty Strips: the menu entry exists with the `e`
#        accelerator and invoking it deletes
#
# NOT asserted (stated, not hidden): pixels. That the survivors re-tile the
# window is eyeball-only, like every other wave rendering (test_wave_viewer.tcl
# header). What IS asserted is the model, the rect count, and that the redraw
# inside regenerate returned without error.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_empty_strips.tcl
# (add --nogui to run only the EP*/EN* legs)

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
set scratch [test_scratch wvempty]

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
# EP* — the PURE half. No window, no DISPLAY, literal lists.
# ============================================================================
set E [wviewer::empty_graph]
set F [dict replace $E traces [list [dict create vec v1 expr v1]]]
# teeth: the two fixtures must actually DIFFER in the property under test, or
# every "the empty ones went" leg below passes against identical inputs
check "EP0 the pure fixtures differ (one holds a trace, one does not)" \
  [list [llength [dict get $E traces]] [llength [dict get $F traces]]] {0 1}

# --- remove_graphs ---
check "EP1 remove two indices" \
  [wviewer::remove_graphs {A B C D} {1 3}] {A C}
check "EP1 removal is order-independent (top-down internally)" \
  [wviewer::remove_graphs {A B C D} {3 1}] {A C}
check "EP2 an empty index list leaves the list alone" \
  [wviewer::remove_graphs {A B C D} {}] {A B C D}
check "EP3 out-of-range and non-integer indices are ignored" \
  [wviewer::remove_graphs {A B C D} {9 -1 x {}}] {A B C D}
check "EP4 a duplicated index removes one element, not two" \
  [wviewer::remove_graphs {A B C D} {1 1}] {A C D}
check "EP5 removing everything is legal at this layer" \
  [wviewer::remove_graphs {A B C D} {0 1 2 3}] {}

# --- index_after_removal (the deletion twin of reordered_index) ---
check "EP6 an index below every removal is unchanged" \
  [wviewer::index_after_removal 0 {1 2}] 0
check "EP7 an index above the removals shifts down by their count" \
  [wviewer::index_after_removal 3 {1 2}] 1
check "EP8 a REMOVED index answers with the slot its follower took" \
  [wviewer::index_after_removal 1 {1 2}] 1
check "EP8 the second removed index answers the same slot" \
  [wviewer::index_after_removal 2 {1 2}] 1
check "EP9 a duplicated removal is counted ONCE (else the target jumps)" \
  [wviewer::index_after_removal 3 {1 1}] 2
check "EP10 no removals is the identity" [wviewer::index_after_removal 2 {}] 2
check "EP11 a non-integer index is returned untouched" \
  [wviewer::index_after_removal {} {1}] {}
check "EP12 non-integer entries in the removal list are skipped" \
  [wviewer::index_after_removal 3 {x 1}] 2
# the deletion twin must NOT be reordered_index: same inputs, different answer
check_true "EP13 index_after_removal differs from reordered_index (it is not a rename)" \
  [expr {[wviewer::index_after_removal 3 {1 2}] ne [wviewer::reordered_index 3 1 2]}]

# --- empty_strips_to_delete: where D-C and D-D live ---
check "EP14 the traceless strips, in index order" \
  [wviewer::empty_strips_to_delete [list $F $E $F $E] -1] {1 3}
check "EP15 a stack with no empty strips deletes nothing" \
  [wviewer::empty_strips_to_delete [list $F $F] -1] {}
check "EP16 D-D the auto-plot strip is never a candidate" \
  [wviewer::empty_strips_to_delete [list $F $E $E] 2] {1}
check "EP17 D-D a lone traceless auto strip is spared" \
  [wviewer::empty_strips_to_delete [list $E] 0] {}
check "EP18 D-C never delete the last strip: all-empty spares index 0" \
  [wviewer::empty_strips_to_delete [list $E $E $E] -1] {1 2}
check "EP19 D-C one empty strip -> NOTHING to delete (the no-op case)" \
  [wviewer::empty_strips_to_delete [list $E] -1] {}
check "EP20 D-C+D-D together: the auto strip already keeps one alive" \
  [wviewer::empty_strips_to_delete [list $E $E] 1] {0}
check "EP21 an empty layout is a no-op" \
  [wviewer::empty_strips_to_delete {} -1] {}
# composition teeth: the kill list must actually be applicable to the list it
# was computed from, and must leave at least one strip
set gs21 [list $E $E $E]
set surv [wviewer::remove_graphs $gs21 [wviewer::empty_strips_to_delete $gs21 -1]]
check "EP22 the two pure procs compose to exactly one survivor" [llength $surv] 1

# ============================================================================
# EN* — no window needed
# ============================================================================
check "EN1 unknown token -> {} (no throw)" \
  [pcall {wviewer::delete_empty_strips no/such/token}] {}
check "EN2 omitted token with no viewer -> {} (no throw)" \
  [pcall {wviewer::delete_empty_strips}] {}
check "EN3 delete_empty_strips_at on a non-viewer canvas -> {} (no throw)" \
  [pcall {wviewer::delete_empty_strips_at .drw}] {}

# ============================================================================
# EG* — GUI legs (self-SKIP without a usable DISPLAY)
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
  # test_wave_clear_all.tcl: generated KeyPress events go to the display's focus
  # window and the WSLg focus round-trip is asynchronous, so every generate is
  # gated on Tk reporting $w as the focus owner and retried until $done — an
  # expr evaluated in the CALLER's scope — turns true).
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

  proc ngraphs {tok} { llength [dict get [wviewer::layout_for $tok] graphs] }
  proc ntraces {tok gi} {
    set gs [dict get [wviewer::layout_for $tok] graphs]
    if {$gi >= [llength $gs]} { return -1 }
    return [llength [dict get [lindex $gs $gi] traces]]
  }
  # the trace-count PROFILE of the whole stack — the one assertion that says
  # "these strips survived and those did not" in a single comparison
  proc profile {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [llength [dict get $G traces]]
    }
    return $out
  }

  # 5 strips: traces, EMPTY, traces, EMPTY, EMPTY. No auto strip unless asked.
  proc fill_viewer {tok {want_auto 0}} {
    set gs {}
    for {set i 0} {$i < 5} {incr i} { lappend gs [wviewer::empty_graph] }
    wviewer::set_graphs $tok $gs
    if {$want_auto} { wviewer::ensure_auto_graph $tok }
    foreach {gi vec} {0 vec_a 0 vec_b 2 vec_c} {
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

  check "EG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: EG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  # spy on the replayable-log seam (the slickprop::log_apply pattern)
  set ::wve_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::wve_log $line }

  # a raw dataset attached to the viewer ctx — synthetic, hermetic (no ngspice,
  # no .raw file). add_trace VALIDATES against the loaded raw's variable list,
  # so a fixture built from names the raw does not know would silently record
  # nothing and every "the strips with traces survived" assertion would pass
  # against a model where NO strip had traces (green-but-hollow).
  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvempty.raw dc vsweep 0 1.0 0.1}
  foreach v {vec_a vec_b vec_c vec_d vec_e} {
    pcall {xschem raw add $v "vsweep 1 +"}
  }
  set rawvars [split [pcall {xschem raw list}] "\n"]
  check_true "EG0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $rawvars vec_a] >= 0 && [lsearch -exact $rawvars vec_c] >= 0}]

  # --- EG1: the deletion itself ---------------------------------------------
  fill_viewer $tok
  check "EG1 fixture has 5 strips" [ngraphs $tok] 5
  # teeth: the fixture must really be MIXED, else "the empty ones went" would
  # pass against a stack that was uniform all along
  check "EG1 fixture profile is mixed (2 strips hold traces, 3 do not)" \
    [profile $tok] {2 0 1 0 0}
  xschem new_schematic switch $vdrw
  check "EG1 fixture placed 5 graph rects" [xschem get rects 2] 5

  check "EG1 delete_empty_strips returns the COUNT deleted" \
    [pcall {wviewer::delete_empty_strips $tok}] 3
  check "EG1 only the strips holding traces survive, in order" [profile $tok] {2 1}
  check "EG1 the model list shrank to 2" [ngraphs $tok] 2
  xschem new_schematic switch $vdrw
  check "EG1 the canvas rect count agrees with the model" [xschem get rects 2] 2
  check "EG1 the survivors are still graphs" \
    [list [xschem getprop rect 2 0 flags] [xschem getprop rect 2 1 flags]] {graph graph}
  check "EG1 buffer NOT left modified (read-only viewer discipline)" \
    [xschem get modified] 0
  # a second call has nothing left to do
  check "EG1 a second call deletes nothing" \
    [pcall {wviewer::delete_empty_strips $tok}] 0
  check "EG1 and left the survivors alone" [profile $tok] {2 1}

  # --- EG2: D-D the auto-plot strip is spared -------------------------------
  fill_viewer $tok 1
  check "EG2 fixture has an auto-plot strip at index 5" \
    [pcall {wviewer::auto_graph_index $tok}] 5
  check "EG2 the auto strip is traceless (so it LOOKS deletable)" \
    [ntraces $tok 5] 0
  check "EG2 delete_empty_strips deleted 3, not 4" \
    [pcall {wviewer::delete_empty_strips $tok}] 3
  check "EG2 the auto strip survived" \
    [pcall {wviewer::auto_graph_index $tok}] 2
  check "EG2 profile: two real strips + the spared auto strip" [profile $tok] {2 1 0}

  # --- EG3: D-C keep one, and the no-op discipline --------------------------
  pcall {wviewer::clear_all $tok}
  check "EG3 clear_all leaves exactly one empty strip" \
    [list [ngraphs $tok] [ntraces $tok 0]] {1 0}
  set nlog [llength $::wve_log]
  check "EG3 `e` on a single empty strip deletes NOTHING" \
    [pcall {wviewer::delete_empty_strips $tok}] 0
  check "EG3 the strip is still there (never empty the window)" [ngraphs $tok] 1
  check "EG3 a no-op emits NO log line for a replay to re-run" \
    [expr {[llength $::wve_log] - $nlog}] 0
  # all-empty stack: one survives, the rest go
  wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph] \
                                 [wviewer::empty_graph]]
  wviewer::regenerate $tok
  check "EG3 an all-empty stack keeps exactly one strip" \
    [list [pcall {wviewer::delete_empty_strips $tok}] [ngraphs $tok]] {2 1}

  # --- EG4: the stored target follows graph identity -------------------------
  #
  # ⚠ THIS GROUP IS EASY TO WRITE HOLLOW, and the first version of it was.
  # `target_index` CLAMPS every read to the live strip count, so on a fixture
  # whose empty strips sit at the BOTTOM the clamp alone lands on the same index
  # the remap would have produced — deleting the remap outright still passed
  # (sabotage-verified). The fixture below is built so the two answers DIFFER:
  # 8 strips with the empties at 1 and 3, so 6 survive and a target of 5 must
  # come back as 3, while an unremapped 5 would clamp to 5.
  # Strip 5 is the only one carrying 3 traces, so the target's IDENTITY (not
  # just its number) is assertable after the move.
  proc fill_wide {tok} {
    set gs {}
    for {set i 0} {$i < 8} {incr i} { lappend gs [wviewer::empty_graph] }
    wviewer::set_graphs $tok $gs
    foreach {gi vec} {0 vec_a 0 vec_b 2 vec_c 4 vec_d
                      5 vec_a 5 vec_b 5 vec_c 6 vec_e 7 vec_a 7 vec_d} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  fill_wide: add_trace $vec -> $e" }
    }
    wviewer::regenerate $tok
  }

  fill_wide $tok
  check "EG4 fixture profile (empties at 1 and 3, strip 5 uniquely holds 3)" \
    [profile $tok] {2 0 1 0 1 3 1 2}
  pcall {wviewer::set_target_strip 5 $tok}
  check "EG4 fixture target is strip 5" [pcall {wviewer::target_strip $tok}] 5
  pcall {wviewer::delete_empty_strips $tok}
  check "EG4 six strips survive" [ngraphs $tok] 6
  check "EG4 the target followed its strip DOWN to index 3" \
    [pcall {wviewer::target_strip $tok}] 3
  # identity, not arithmetic: index 3 must be the same strip the target was on
  check "EG4 and index 3 is the strip that uniquely held 3 traces" \
    [ntraces $tok 3] 3
  # teeth: a bare clamp would have answered 5 here, so this pair really does
  # exercise index_after_removal
  check_true "EG4 the clamp alone would have given a DIFFERENT answer" \
    [expr {[wviewer::target_clamp 5 6] != 3}]

  # --- EG4b: the target BEYOND the surviving count — the clamped case -------
  # ⚠ EG4 above is still one step short, and the shortfall was found by the
  # issue-0176 review. Its target (5) is BELOW the surviving count (6), so
  # `target_index`'s clamp is inert and reading the target after the mutation
  # gives the same answer as reading it before. Push the target to the LAST
  # strip and the clamp bites: read after `set_graphs` and it truncates 7 -> 5
  # BEFORE index_after_removal subtracts the two deletions below, landing on 3 —
  # a strip the target was never on. The read now happens before the mutation
  # (delete_empty_strips, and delete_items which copied it).
  fill_wide $tok
  pcall {wviewer::set_target_strip 7 $tok}
  check "EG4b the target is the LAST strip, past the count that will survive" \
    [pcall {wviewer::target_strip $tok}] 7
  pcall {wviewer::delete_empty_strips $tok}
  check "EG4b the target followed its strip to index 5" \
    [pcall {wviewer::target_strip $tok}] 5
  check "EG4b and index 5 is the strip that held 2 traces, as strip 7 did" \
    [ntraces $tok 5] 2
  # teeth: name the WRONG answer explicitly, so a regression cannot look benign
  check_true "EG4b a post-mutation read would have answered 3 — a different strip,\
 with a different trace count" \
    [expr {[wviewer::index_after_removal [wviewer::target_clamp 7 6] {1 3}] == 3
           && [ntraces $tok 3] != 2}]

  # a target that is ITSELF deleted must land on a live strip, never dangle
  fill_wide $tok
  pcall {wviewer::set_target_strip 3 $tok}
  check "EG4 target set to an EMPTY strip (index 3, doomed)" \
    [pcall {wviewer::target_strip $tok}] 3
  pcall {wviewer::delete_empty_strips $tok}
  check "EG4 a deleted target takes the slot its follower moved into" \
    [pcall {wviewer::target_strip $tok}] 2
  check_true "EG4 and that slot is inside the survivors" \
    [expr {[pcall {wviewer::target_strip $tok}] < [ngraphs $tok]}]
  check_true "EG4 the clamp alone would again have differed" \
    [expr {[wviewer::target_clamp 3 6] != 2}]

  # --- EG5: markers on a doomed strip take their links with them -------------
  # A delta block whose partner number is gone degrades to a plain callout with
  # NO indication, so the survivor's `prev` link must be swept, not orphaned.
  fill_viewer $tok
  set gs [dict get [wviewer::layout_for $tok] graphs]
  # A record is `num wave dset point x y prev ldx ldy [extra]` and
  # markers_line_fields REFUSES anything shorter than 9 fields, so a short
  # fixture reads as "no markers at all" and every leg below would pass
  # vacuously (it did, first time round).
  # marker 1 on the DOOMED empty strip 1; marker 2 on the SURVIVING strip 2 with
  # prev=1 — the delta partner that is about to disappear.
  set gs [lreplace $gs 1 1 [dict replace [lindex $gs 1] markers {1 0 0 0 0.25 0.5 0 0 0}]]
  set gs [lreplace $gs 2 2 [dict replace [lindex $gs 2] markers {2 0 0 0 0.75 0.5 1 0 0}]]
  wviewer::set_graphs $tok $gs
  # REGENERATE, or the fixture is a lie: delete_empty_strips runs
  # capture_live_graph_state, which re-reads `markers` FROM THE RECT PROPS and
  # overwrites the model with what it finds. A model-only plant would be wiped
  # before the deletion ever saw it.
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "EG5 fixture: the marker really reached the doomed strip's RECT" \
    [xschem getprop rect 2 1 markers] {1 0 0 0 0.25 0.5 0 0 0}
  check "EG5 fixture: the doomed strip carries marker 1" \
    [pcall {wviewer::markers_numbers \
      [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 1] markers]}] 1
  check "EG5 fixture: the survivor's marker 2 points at 1 (prev, field 6)" \
    [lindex [pcall {wviewer::markers_line_fields \
      [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 2] markers]}] 6] 1
  pcall {wviewer::delete_empty_strips $tok}
  set surv [dict get [wviewer::layout_for $tok] graphs]
  check "EG5 the doomed strip and its marker are gone" [llength $surv] 2
  set mk [pcall {wviewer::dget [lindex $surv 1] markers {}}]
  check_true "EG5 the survivor kept its own marker" \
    [expr {[lsearch -exact [pcall {wviewer::markers_numbers $mk}] 2] >= 0}]
  check "EG5 the dangling prev link was swept to 0" \
    [lindex [pcall {wviewer::markers_line_fields $mk}] 6] 0

  # --- EG6: one undo point per gesture ---------------------------------------
  fill_viewer $tok
  set before [profile $tok]
  pcall {wviewer::delete_empty_strips $tok}
  check "EG6 the deletion happened" [profile $tok] {2 1}
  check_true "EG6 one undo restores the deleted strips" \
    [expr {[pcall {wviewer::undo $tok}] ne {ERR}}]
  check "EG6 the model is back to the pre-delete profile" [profile $tok] $before
  check "EG6 the undo was ONE step, not two (state did not over-rewind)" \
    [ngraphs $tok] 5

  # --- EG7: replayable logging ----------------------------------------------
  fill_viewer $tok
  set nlog [llength $::wve_log]
  pcall {wviewer::delete_empty_strips $tok}
  check "EG7 exactly one line logged per deletion" \
    [expr {[llength $::wve_log] - $nlog}] 1
  check "EG7 the line is replayable, with the EXPLICIT token" \
    [lindex $::wve_log end] "wviewer::delete_empty_strips $tok"
  fill_viewer $tok
  pcall {uplevel #0 [lindex $::wve_log end]}
  check "EG7 replaying the logged line reproduces the state" [profile $tok] {2 1}
  # the omitted-token form works on the active window
  fill_viewer $tok
  xschem new_schematic switch $vdrw
  check "EG7 omitted token targets the active viewer" \
    [pcall {wviewer::delete_empty_strips}] 3
  check "EG7 omitted-token call did the work" [profile $tok] {2 1}

  # --- EG8: the binding seam -------------------------------------------------
  set btags [bindtags $vdrw]
  check "EG8 the tag sits right AFTER the widget (filters keep first refusal)" \
    [lindex $btags 1] WaveViewer
  check_true "EG8 bare `e` is bound on the tag by default" \
    [expr {[bind WaveViewer <Key-e>] ne {}}]
  check_true "EG8 the default calls delete_empty_strips_at with the event's canvas" \
    [string match {*wviewer::delete_empty_strips_at %W*} [bind WaveViewer <Key-e>]]
  # sweep-proof: strip_bindings clears every WIDGET-level sequence, so a viewer
  # key bound there would die on the next sweep — the tag one does not
  wviewer::strip_bindings $vdrw
  check_true "EG8 the tag binding survives a re-sweep" \
    [expr {[bind WaveViewer <Key-e>] ne {}}]
  check "EG8 `e` is NOT bound on the canvas widget itself" [bind $vdrw <Key-e>] {}
  # the collision check, asserted rather than asserted-in-a-comment: keysym 101
  # must NOT be forwarded to the C engine (where bare `e` is descend_schematic)
  check "EG8 `e` (101) is not in graphkeys, so key_filter forwards nothing" \
    [lsearch -exact $wviewer::graphkeys 101] -1

  # --- EG9: a REAL `e` event -------------------------------------------------
  fill_viewer $tok
  check "EG9 fixture is not already trimmed" [ngraphs $tok] 5
  set delivered [send_key $vdrw <Key-e> {[ngraphs $tok] == 2}]
  if {!$delivered} {
    puts "SKIPPED: EG9/EG10 real-key legs (focus never confirmed)"
  } else {
    check "EG9 `e` left only the strips with traces" [profile $tok] {2 1}
    check "EG9 the key gesture is logged like the command" \
      [lindex $::wve_log end] "wviewer::delete_empty_strips $tok"

    # --- EG10: rc REMAPPABILITY ---------------------------------------------
    # (a) an rc can DISABLE the default with `{break}`
    bind WaveViewer <Key-e> {break}
    fill_viewer $tok
    focus -force $vdrw; update
    event generate $vdrw <Key-e>; update
    check "EG10 a disabled `e` deletes nothing" [ngraphs $tok] 5
    # (b) an rc can bind its own sequence
    bind WaveViewer <Key-y> {wviewer::delete_empty_strips_at %W; break}
    check_true "EG10 the remapped key deletes" \
      [send_key $vdrw <Key-y> {[ngraphs $tok] == 2}]
    check "EG10 the remapped key left the strips with traces" [profile $tok] {2 1}
    # (c) rc WINS: install_default_binds must not overwrite an existing binding
    bind WaveViewer <Key-e> {set ::wve_rc_ran 1; break}
    set wviewer::tagbinds 0
    check "EG10 install_default_binds runs once per session" \
      [pcall {wviewer::install_default_binds}] 1
    check "EG10 an rc binding is NOT overwritten by the defaults" \
      [bind WaveViewer <Key-e>] {set ::wve_rc_ran 1; break}
    bind WaveViewer <Key-y> {}
    bind WaveViewer <Key-e> {}
    set wviewer::tagbinds 0
    pcall {wviewer::install_default_binds}
    check_true "EG10 shipped default restored" \
      [string match {*delete_empty_strips_at*} [bind WaveViewer <Key-e>]]
  }

  # --- EG11: the menu twin ---------------------------------------------------
  set gm $vtop.wvmenubar.graph
  if {[winfo exists $gm]} {
    set idx -1
    for {set i 0} {$i <= [$gm index end]} {incr i} {
      if {[catch {$gm entrycget $i -label} lb]} continue
      if {$lb eq {Delete Empty Strips}} { set idx $i; break }
    }
    check_true "EG11 the Graph menu has a Delete Empty Strips entry" \
      [expr {$idx >= 0}]
    if {$idx >= 0} {
      check "EG11 the entry advertises the `e` accelerator" \
        [$gm entrycget $idx -accelerator] e
      fill_viewer $tok
      $gm invoke $idx
      check "EG11 invoking the menu entry deletes the empty strips" \
        [profile $tok] {2 1}
    }
  } else {
    puts "SKIPPED: EG11 (viewer menubar not found)"
  }

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
  catch {wviewer::close $tok}
  }
} else {
  puts "SKIPPED: EG* GUI legs (no DISPLAY)"
}

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

puts "----"
puts "test_wave_empty_strips: $npass passed, $fail failed"
# The exact wording matters: run_suites.sh (and full_audit.sh) classify a run by
# grepping the last RESULT line for `ALL PASS`, and exit 0/1 is what a bare
# invocation is judged by. A suite that says "RESULT: PASS" is reported as FAIL
# by the harness while printing PASS itself — which is exactly what this file
# did on its first soak.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
