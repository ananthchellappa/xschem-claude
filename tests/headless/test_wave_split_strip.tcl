# tests/headless/test_wave_split_strip.tcl — ASE Waveform Viewer
# RMB on empty strip space -> "Split Strip" (viewer plan item 8,
# doc/claude/suggestions/plan_viewer_enhancements_2026-07.md; contract in
# doc/claude/specs/waveform_viewer.md)
#
# The feature: a right-click that does not travel, on waveform space with NO
# trace under it, posts a menu whose one entry splits that strip into one strip
# per drawn trace. Decision D-F: node 0 keeps the original strip, the rest get
# new strips inserted directly below it, in reading order. Also
# Graph > Split Strip, which acts on the TARGET strip.
#
# What is asserted here:
#   SP*  the PURE half, literal dicts, no window and no DISPLAY:
#        index_after_insert (the insert twin of index_after_removal) and
#        split_graph_in_graphs — the D-F ordering, marker migration, the
#        hilight_wave hand-off, vec-less traces, and the refusals
#   SN*  no-window legs: split_strip and the gate never throw when nothing
#        resolves
#   SG1  the split itself: profile, rect count, order, modified still 0
#   SG2  the >= 2 drawn traces REFUSAL: no mutation, no undo point, no log line
#   SG3  markers and hilight_wave migrate through the REAL path (rect props)
#   SG4  the stored TARGET follows graph identity through the insert
#   SG5  UNDO: exactly one `u` restores the pre-split model
#   SG6  replayable logging: one fully-resolved line, replay reproduces; and the
#        command takes exactly ONE regenerate and never calls add_graph
#   SG7  the GATE (strip_menu_pick): empty space resolves, a trace pixel refuses
#        (that is item 7's), a one-trace strip refuses
#   SG8  the two menus PARTITION the body — ctx_menu_post offers the trace menu
#        first, so a trace pixel can never get the strip menu
#   SG9  the MENU widget: entries, the disabled header, invoking it splits
#   SG10 the GESTURE: a real no-travel RMB on empty space posts the strip menu;
#        a travelled RMB posts nothing and still box-zooms
#   SG11 Graph > Split Strip: the menubar twin, acting on the target strip
#
# NOT asserted (stated, not hidden): pixels, and digital/bus strips. The suite
# has no digital fixture, so "this menu owns the whole body of a digital strip"
# is recorded in the spec and left to the eyeball; what IS asserted is the
# mechanism it rests on (no trace under the pointer -> this menu).
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_split_strip.tcl
# (add --nogui to run only the SP*/SN* legs)

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
set scratch [test_scratch wvsplit]

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
# SP* — the PURE half.
# ============================================================================

# --- index_after_insert: the insert twin of index_after_removal ---
check "SP1 an index below the insertion point is unchanged" \
  [wviewer::index_after_insert 0 1 2] 0
check "SP2 an index AT the insertion point is pushed down" \
  [wviewer::index_after_insert 1 1 2] 3
check "SP3 an index above it shifts by the same count" \
  [wviewer::index_after_insert 2 1 2] 4
check "SP4 a single insert is the plot_signals case" \
  [wviewer::index_after_insert 3 0 1] 4
check "SP5 count 0 is the identity" [wviewer::index_after_insert 3 1 0] 3
check "SP6 a negative count is refused, not applied" \
  [wviewer::index_after_insert 3 1 -2] 3
check "SP7 a non-integer index is returned untouched" \
  [wviewer::index_after_insert {} 1 1] {}
check "SP8 a non-integer insertion point is a no-op" \
  [wviewer::index_after_insert 3 x 1] 3
# teeth: it must NOT be index_after_removal or reordered_index under a new name
check_true "SP9 it differs from index_after_removal on the same inputs" \
  [expr {[wviewer::index_after_insert 3 1 1] ne [wviewer::index_after_removal 3 {1}]}]
check_true "SP10 and from reordered_index" \
  [expr {[wviewer::index_after_insert 3 1 1] ne [wviewer::reordered_index 3 1 2]}]

# --- split_graph_in_graphs: where D-F lives ---
proc sp_trace {v c} { return [dict create expr $v name {} vec $v color $c] }
proc sp_vecs {G} {
  if {![catch {dict size $G}]} {
    set out {}
    foreach t [wviewer::dget $G traces {}] { lappend out [wviewer::dget $t vec {}] }
    return $out
  }
  return $G
}
set S [dict create traces [list [sp_trace va 4] [sp_trace vb 5] [sp_trace vc 6]] \
                   logx 0 logy 0 x1 0 x2 1 y1 0 y2 2 \
                   hilight_wave 2 markers "9 1 0 3 0.5 0.25 0 0 0"]
# sentinels either side, so "the rest of the stack is untouched" is witnessable
set gs [wviewer::split_graph_in_graphs [list ALPHA $S OMEGA] 1]
check "SP11 three traces become three strips" [llength $gs] 5
check "SP12 D-F: node 0 KEEPS the original strip" [sp_vecs [lindex $gs 1]] va
check "SP13 D-F: the rest go directly below, in reading order" \
  [list [sp_vecs [lindex $gs 2]] [sp_vecs [lindex $gs 3]]] {vb vc}
check "SP14 the strips above and below are untouched" \
  [list [lindex $gs 0] [lindex $gs 4]] {ALPHA OMEGA}
check "SP15 the trace DICTIONARY rides along (colour preserved)" \
  [wviewer::dget [lindex [wviewer::dget [lindex $gs 3] traces {}] 0] color {}] 6
# the bold trace was node 2 -> it lands in the LAST new strip, as node 0
check "SP16 hilight_wave followed its trace to the new strip" \
  [wviewer::dget [lindex $gs 3] hilight_wave {}] 0
check "SP17 the source dropped the bold it no longer owns" \
  [dict exists [lindex $gs 1] hilight_wave] 0
# the marker sat on node 1 -> it migrates and its wave field is remapped
check "SP18 the marker migrated with node 1, remapped to 0" \
  [wviewer::dget [lindex $gs 2] markers {}] {9 0 0 3 0.5 0.25 0 0 0}
check "SP19 the source has no marker left" \
  [dict exists [lindex $gs 1] markers] 0
check "SP20 every new strip's ranges are blank (regenerate re-autozooms)" \
  [list [wviewer::dget [lindex $gs 2] x1 {}] [wviewer::dget [lindex $gs 3] y2 {}]] {{} {}}
check "SP21 the SOURCE keeps its own ranges" \
  [list [wviewer::dget [lindex $gs 1] x1 {}] [wviewer::dget [lindex $gs 1] x2 {}]] {0 1}

# refusals
check "SP22 a one-trace strip is returned unchanged" \
  [llength [wviewer::split_graph_in_graphs [list [dict create traces \
     [list [sp_trace va 4]]]] 0]] 1
check "SP23 a traceless strip is returned unchanged" \
  [llength [wviewer::split_graph_in_graphs [list [wviewer::empty_graph]] 0]] 1
check "SP24 an out-of-range index is returned unchanged" \
  [llength [wviewer::split_graph_in_graphs [list $S] 9]] 1
check "SP25 a non-integer index is returned unchanged" \
  [llength [wviewer::split_graph_in_graphs [list $S] x]] 1

# vec-less traces reach no node slot, so they are not "traces" for the split and
# stay behind in the source strip
set SX [dict create traces [list [sp_trace va 4] \
                                 [dict create expr {} name {} vec {} color 7] \
                                 [sp_trace vb 5]] logx 0 logy 0]
check "SP26 three model traces, two node slots" \
  [list [llength [dict get $SX traces]] [wviewer::node_count $SX]] {3 2}
set gsx [wviewer::split_graph_in_graphs [list $SX] 0]
check "SP27 two node slots -> two strips" [llength $gsx] 2
check "SP28 the vec-less trace stays with node 0" [sp_vecs [lindex $gsx 0]] {va {}}
check "SP29 and node 1 got the new strip" [sp_vecs [lindex $gsx 1]] vb

# a five-trace strip, to prove the descending loop scales past the 3 above
set S5 [dict create traces [list [sp_trace v1 4] [sp_trace v2 5] [sp_trace v3 6] \
                                 [sp_trace v4 7] [sp_trace v5 8]] logx 0 logy 0]
set gs5 [wviewer::split_graph_in_graphs [list $S5] 0]
set order {}
foreach G $gs5 { lappend order [sp_vecs $G] }
check "SP30 five traces split into five strips in reading order" \
  $order {v1 v2 v3 v4 v5}

# --- REUSE the ADJACENT empty strip instead of inserting one (D3/D4) ----------
# The decision is the PURE wviewer::plan_split: {ok reuse at new}. It is
# ASYMMETRIC with the single-trace move on purpose — that gesture may take any
# empty strip anywhere, this one only the strip immediately BELOW (D3), because a
# split produces a contiguous run reading node 0, 1, 2 downward and a strip taken
# from above or from far below would tear that run apart.
#
# ⚠ Reuse and insert can look identical: with an empty strip at gi + 1, both put
# node 1 there. The discriminators are the strip COUNT and the strip IDENTITY
# (the inert `spid` key — free-form model dict, graph_props reads known keys).
proc sp_e {id} { return [dict replace [wviewer::empty_graph] spid $id] }
proc sp_st {id args} {
  set trs {}
  set c 4
  foreach v $args { lappend trs [sp_trace $v $c]; incr c }
  return [dict create traces $trs logx 0 logy 0 x1 0 x2 1 y1 0 y2 2 spid $id]
}
proc sp_ids {gs} {
  set out {}
  foreach G $gs { lappend out [wviewer::dget $G spid -] }
  return $out
}
proc sp_plan {gs gi {auto -1}} {
  set p [wviewer::plan_split $gs $gi $auto]
  return [list [dict get $p ok] [dict get $p reuse] [dict get $p at] [dict get $p new]]
}

check "SP31 no strip below at all -> insert nc-1 at gi+1" \
  [sp_plan [list [sp_st A va vb vc]] 0] {1 -1 1 2}
check "SP32 the strip below holds traces -> insert nc-1" \
  [sp_plan [list [sp_st A va vb vc] [sp_st B vd]] 0] {1 -1 1 2}
check "SP33 an EMPTY strip below is consumed, and only the shortfall inserted" \
  [sp_plan [list [sp_st A va vb vc] [sp_e B]] 0] {1 1 2 1}
check "SP34 D4: two traces + an empty strip below inserts NOTHING" \
  [sp_plan [list [sp_st A va vb] [sp_e B]] 0] {1 1 2 0}
check "SP35 D3: an empty strip ABOVE is NOT eligible (reading order)" \
  [sp_plan [list [sp_e A] [sp_st B va vb vc] [sp_st C vd]] 1] {1 -1 2 2}
check "SP36 D3: an empty strip TWO below is not eligible either (adjacent only)" \
  [sp_plan [list [sp_st A va vb vc] [sp_st B vd] [sp_e C]] 0] {1 -1 1 2}
check "SP37 D-D: an AUTO strip immediately below is never consumed" \
  [sp_plan [list [sp_st A va vb vc] [sp_e B]] 0 1] {1 -1 1 2}
check "SP38 a strip of vec-less traces below is not empty (zero MODEL traces)" \
  [sp_plan [list [sp_st A va vb vc] [dict create traces \
     [list [dict create expr {} name {} vec {} color 7]]]] 0] {1 -1 1 2}
check "SP39 a malformed entry below fails CLOSED (never consumed)" \
  [sp_plan [list [sp_st A va vb vc] SENTINEL] 0] {1 -1 1 2}
# refusals: the plan says ok 0 and split_graph_in_graphs returns the list intact
check "SP40 one drawn trace -> no plan" [sp_plan [list [sp_st A va] [sp_e B]] 0] {0 -1 0 0}
check "SP40 a traceless strip -> no plan" [sp_plan [list [sp_e A] [sp_e B]] 0] {0 -1 0 0}
check "SP40 an out-of-range index -> no plan" [sp_plan [list [sp_st A va vb]] 9] {0 -1 0 0}
check "SP40 a non-integer index -> no plan" [pcall {sp_plan [list [sp_st A va vb]] x}] {0 -1 0 0}
check "SP40 an empty stack -> no plan" [sp_plan {} 0] {0 -1 0 0}
# REPLAY DETERMINISM: the log line carries only `gi`, so a replay recomputes the
# plan — sound only because the plan is a pure function of the model
set spr [list [sp_st A va vb vc] [sp_e B]]
check_true "SP41 the same model plans the same way twice (replay-safe)" \
  [expr {[sp_plan $spr 0] eq [sp_plan $spr 0]}]

# --- the reuse arm of split_graph_in_graphs ----------------------------------
# nc = 3 with an empty strip below: strip B takes node 1, ONE strip is inserted
set gsr [wviewer::split_graph_in_graphs \
  [list [dict replace [sp_st A va vb vc] hilight_wave 1 markers "9 1 0 3 0.5 0.25 0 0 0"] \
        [dict replace [sp_e B] y1 -5 y2 -4] [sp_st C vd]] 0]
check "SP42 one strip was inserted, not two — the count is the signal" [llength $gsr] 4
check "SP42 and the pre-existing empty strip is the one that got node 1" \
  [sp_ids $gsr] {A B - C}
check "SP43 the run still reads node 0, 1, 2 downward (D-F)" \
  [list [sp_vecs [lindex $gsr 0]] [sp_vecs [lindex $gsr 1]] \
        [sp_vecs [lindex $gsr 2]] [sp_vecs [lindex $gsr 3]]] {va vb vc vd}
check "SP44 the marker migrated INTO the reused strip, remapped to 0" \
  [wviewer::dget [lindex $gsr 1] markers {}] {9 0 0 3 0.5 0.25 0 0 0}
check "SP44 the bold followed its trace into the reused strip" \
  [wviewer::dget [lindex $gsr 1] hilight_wave {}] 0
check "SP45 the reused strip's stale ranges were blanked (autozoom for free)" \
  [list [wviewer::dget [lindex $gsr 1] y1 {}] [wviewer::dget [lindex $gsr 1] y2 {}]] {{} {}}
# D4's zero-insert case: two traces, an empty strip below -> the count never changes
set gsz [wviewer::split_graph_in_graphs \
  [list [sp_st A va vb] [sp_e B] [sp_st C vc]] 0]
check "SP46 D4: a two-trace split with an empty strip below inserts NOTHING" \
  [llength $gsz] 3
check "SP46 the same three strips, in the same order" [sp_ids $gsz] {A B C}
check "SP46 and node 1 really moved into the one that was already there" \
  [list [sp_vecs [lindex $gsz 0]] [sp_vecs [lindex $gsz 1]] [sp_vecs [lindex $gsz 2]]] \
  {va vb vc}
# teeth: the always-insert arm produces a stack these legs can tell apart, so
# "reuse always" and "insert always" cannot both pass
set gsi [wviewer::move_trace_in_graphs \
  [linsert [list [sp_st A va vb] [sp_e B] [sp_st C vc]] 1 [wviewer::empty_graph]] 0 1 1]
check "SP47 the always-insert construction grows the stack to four" [llength $gsi] 4
check "SP47 ... and pushes the pre-existing empty strip down a slot" \
  [sp_ids $gsi] {A - B C}
check "SP47 the same fixture with the strip below EXCLUDED inserts again" \
  [llength [wviewer::split_graph_in_graphs \
     [list [sp_st A va vb] [sp_e B] [sp_st C vc]] 0 1]] 4
# five traces with an empty strip below: reuse 1, insert 3
set gs5r [wviewer::split_graph_in_graphs [list $S5 [sp_e Z]] 0]
set order5 {}
foreach G $gs5r { lappend order5 [sp_vecs $G] }
check "SP48 five traces, one reused strip, three inserted" [llength $gs5r] 5
check "SP48 in reading order, with the reused strip second" \
  $order5 {v1 v2 v3 v4 v5}
check "SP48 the reused strip kept its identity at index 1" [sp_ids $gs5r] {- Z - - -}
# the TARGET arithmetic must use the plan's own numbers (D5)
set spp [wviewer::plan_split [list [sp_st A va] [sp_st B va vb vc] [sp_e C] \
                                  [sp_st D vd] [sp_st E ve]] 1]
check "SP49 the plan for a reused-below split inserts 1 at index 3" \
  [list [dict get $spp at] [dict get $spp new]] {3 1}
check "SP49 a target BELOW the inserts shifts by the ACTUAL count, not nc-1" \
  [wviewer::index_after_insert 4 [dict get $spp at] [dict get $spp new]] 5
check_true "SP49 ... which differs from the old gi+1 / nc-1 arithmetic" \
  [expr {[wviewer::index_after_insert 4 2 2] != 5}]
check "SP49 a zero-insert plan leaves every index alone" \
  [wviewer::index_after_insert 4 \
     [dict get [wviewer::plan_split [list [sp_st A va vb] [sp_e B] [sp_st C vc]] 0] at] \
     [dict get [wviewer::plan_split [list [sp_st A va vb] [sp_e B] [sp_st C vc]] 0] new]] 4

# ============================================================================
# SN* — no window needed
# ============================================================================
check "SN1 unknown token -> {} (no throw)" \
  [pcall {wviewer::split_strip 0 no/such/token}] {}
check "SN2 omitted token with no viewer -> {} (no throw)" \
  [pcall {wviewer::split_strip 0}] {}
check "SN3 a non-integer index -> {} (no throw)" \
  [pcall {wviewer::split_strip x no/such/token}] {}
check "SN4 split_target_strip with no viewer -> {} (no throw)" \
  [pcall {wviewer::split_target_strip}] {}
check "SN5 the gate on a non-viewer canvas -> -1 (no throw)" \
  [pcall {wviewer::strip_menu_pick .drw 10 10}] -1
check "SN6 posting on a non-viewer canvas -> 0 (no throw)" \
  [pcall {wviewer::strip_menu_post .drw 10 10}] 0
check "SN7 unposting an unknown token -> 0 (no throw)" \
  [pcall {wviewer::strip_menu_unpost no/such/token}] 0
check "SN8 building for an unknown token -> {} (no throw)" \
  [pcall {wviewer::strip_menu_build no/such/token 0}] {}

# ============================================================================
# SG* — GUI legs
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
  set ::sgt 100000
  proc sg_ev {w seq args} {
    set ::sgt [expr {$::sgt + 1000}]
    eval [list event generate $w $seq -time $::sgt] $args
  }

  # strip 0: three traces (the split case). strip 1: one (the refusal case).
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
  # A canvas pixel of strip `gi` that the ENGINE says is INSIDE THE PLOT BOX and
  # holds no trace. The plot-box test is not optional: scanning for "no trace"
  # alone finds the label margin at the top of the band first, which is where a
  # Button3 press is already the wave-attributes dialog — the defect this gate
  # was given `plotbox_at` to close.
  proc find_empty_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60 0.30 0.70} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 2} {
        if {[wviewer::strip_at_pixel $vdrw $px $py] != $gi} { continue }
        if {![wviewer::plotbox_at $vdrw $gi $px $py]} { continue }
        if {[wviewer::trace_at $vdrw $gi $px $py] < 0} { return [list $px $py] }
      }
    }
    return {}
  }
  # ... and a pixel of strip `gi` that is in the band but OUTSIDE the plot box
  # (the legend/label margin), for the refusal legs
  proc find_margin_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set px [expr {int(0.50 * $W)}]
    for {set py 2} {$py < $H} {incr py 2} {
      if {[wviewer::strip_at_pixel $vdrw $px $py] != $gi} { continue }
      if {![wviewer::plotbox_at $vdrw $gi $px $py]} { return [list $px $py] }
    }
    return {}
  }
  proc find_trace_px {vdrw gi} {
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    foreach fx {0.50 0.40 0.60 0.30 0.70} {
      set px [expr {int($fx * $W)}]
      for {set py 2} {$py < $H} {incr py 2} {
        if {[wviewer::trace_at $vdrw $gi $px $py] >= 0} { return [list $px $py] }
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

  check "SG0 wviewer::open returns 1" [pcall {wviewer::open $tok}] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: SG* GUI legs (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set ::sp_log {}
  rename wviewer::log_action wviewer::__real_log_action
  proc wviewer::log_action {line} { lappend ::sp_log $line }

  xschem new_schematic switch $vdrw
  pcall {xschem raw new wvsplit.raw dc vsweep 0 1.0 0.02}
  foreach {v ex} {vec_a {vsweep 1 +} vec_b {vsweep 3 +} vec_c {vsweep 5 +}
                  vec_d {vsweep 7 +} vec_e {vsweep 9 +}} {
    pcall {xschem raw add $v $ex}
  }
  set rawvars [split [pcall {xschem raw list}] "\n"]
  check_true "SG0 the fixture raw knows the vectors the traces use" \
    [expr {[lsearch -exact $rawvars vec_a] >= 0 && [lsearch -exact $rawvars vec_d] >= 0}]

  # --- SG1: the split itself -------------------------------------------------
  fill_viewer $tok
  check "SG1 fixture: three traces on strip 0, one on strip 1" [profile $tok] {3 1}
  xschem new_schematic switch $vdrw
  check "SG1 fixture placed 2 graph rects" [xschem get rects 2] 2
  check "SG1 split_strip returns the NUMBER of new strips" \
    [pcall {wviewer::split_strip 0 $tok}] 2
  check "SG1 one strip per trace, the rest of the stack pushed down" \
    [profile $tok] {1 1 1 1}
  check "SG1 D-F: node 0 kept the original strip" [vecs_at $tok 0] vec_a
  check "SG1 D-F: the rest went below it in reading order" \
    [list [vecs_at $tok 1] [vecs_at $tok 2]] {vec_b vec_c}
  check "SG1 the strip that was below is still below" [vecs_at $tok 3] vec_d
  xschem new_schematic switch $vdrw
  check "SG1 the canvas rect count agrees with the model" [xschem get rects 2] 4
  check "SG1 all four are still graphs" \
    [list [xschem getprop rect 2 0 flags] [xschem getprop rect 2 1 flags] \
          [xschem getprop rect 2 2 flags] [xschem getprop rect 2 3 flags]] \
    {graph graph graph graph}
  check "SG1 buffer NOT left modified (read-only viewer discipline)" \
    [xschem get modified] 0
  check "SG1 the new strips really carry their traces in their rects" \
    [list [string match {*vec_b*} [xschem getprop rect 2 1 node]] \
          [string match {*vec_c*} [xschem getprop rect 2 2 node]]] {1 1}
  check "SG1 and the source rect carries only its own" \
    [list [string match {*vec_a*} [xschem getprop rect 2 0 node]] \
          [string match {*vec_b*} [xschem getprop rect 2 0 node]]] {1 0}
  check "SG1 a second split of the same strip does nothing" \
    [pcall {wviewer::split_strip 0 $tok}] {}

  # --- SG2: the >= 2 drawn traces refusal ------------------------------------
  fill_viewer $tok
  set nlog [llength $::sp_log]
  lassign [wviewer::history_depth $tok] u0 r0
  check "SG2 a strip with ONE drawn trace refuses" \
    [pcall {wviewer::split_strip 1 $tok}] {}
  check "SG2 the refusal mutated nothing" [profile $tok] {3 1}
  check "SG2 the refusal logged nothing" \
    [expr {[llength $::sp_log] - $nlog}] 0
  lassign [wviewer::history_depth $tok] u1 r1
  check "SG2 the refusal took NO undo point" [expr {$u1 - $u0}] 0
  check "SG2 a bad strip index refuses too" [pcall {wviewer::split_strip 9 $tok}] {}
  check "SG2 still nothing mutated" [profile $tok] {3 1}
  # teeth: the SAME strip is accepted once it holds two
  pcall {wviewer::add_trace $tok 1 vec_e}
  check "SG2 the same strip is accepted once it holds two" \
    [pcall {wviewer::split_strip 1 $tok}] 1

  # --- SG3: markers and the bold trace, through the REAL path ----------------
  fill_viewer $tok
  set gs [dict get [wviewer::layout_for $tok] graphs]
  # marker 4 on NODE 2 of strip 0 (the last trace), bold on NODE 1
  set gs [lreplace $gs 0 0 [dict replace [lindex $gs 0] \
            markers {4 2 0 5 0.5 0.5 0 0 0} hilight_wave 1]]
  wviewer::set_graphs $tok $gs
  # REGENERATE, or capture_live_graph_state re-reads the RECT and wipes the plant
  wviewer::regenerate $tok
  xschem new_schematic switch $vdrw
  check "SG3 fixture: the marker really reached the rect" \
    [xschem getprop rect 2 0 markers] {4 2 0 5 0.5 0.5 0 0 0}
  check "SG3 fixture: the bold really reached the rect" \
    [xschem getprop rect 2 0 hilight_wave] 1
  check "SG3 the split happened" [pcall {wviewer::split_strip 0 $tok}] 2
  set gs [dict get [wviewer::layout_for $tok] graphs]
  check "SG3 the marker went to node 2's new strip, remapped to 0" \
    [wviewer::dget [lindex $gs 2] markers {}] {4 0 0 5 0.5 0.5 0 0 0}
  check "SG3 no marker was left behind or duplicated" \
    [list [dict exists [lindex $gs 0] markers] [dict exists [lindex $gs 1] markers]] {0 0}
  check "SG3 the bold went to node 1's new strip" \
    [wviewer::dget [lindex $gs 1] hilight_wave {}] 0
  check "SG3 the source dropped its bold" \
    [dict exists [lindex $gs 0] hilight_wave] 0
  xschem new_schematic switch $vdrw
  check "SG3 and the migration reached the RECT" \
    [xschem getprop rect 2 2 markers] {4 0 0 5 0.5 0.5 0 0 0}

  # --- SG4: the stored target follows graph IDENTITY -------------------------
  #
  # ⚠ EASY TO WRITE HOLLOW: target_index CLAMPS, so on a shallow stack an
  # untouched target answers the same as a shifted one. The fixture puts the
  # target BELOW the split (strip 3 of 4) and splits strip 1 into three, so an
  # untouched target would read back as 3 and the correct answer is 5.
  proc fill_deep {tok} {
    set gs {}
    for {set i 0} {$i < 4} {incr i} { lappend gs [wviewer::empty_graph] }
    wviewer::set_graphs $tok $gs
    foreach {gi vec} {0 vec_a 1 vec_a 1 vec_b 1 vec_c 2 vec_d 3 vec_e} {
      set e [wviewer::add_trace $tok $gi $vec]
      if {$e ne {}} { puts "  fill_deep: add_trace $vec -> $e" }
    }
    wviewer::regenerate $tok
    wviewer::fit $tok
  }
  fill_deep $tok
  check "SG4 fixture profile (strip 1 uniquely holds 3)" [profile $tok] {1 3 1 1}
  pcall {wviewer::set_target_strip 3 $tok}
  check "SG4 fixture target is strip 3" [pcall {wviewer::target_strip $tok}] 3
  check "SG4 the split created two new strips" [pcall {wviewer::split_strip 1 $tok}] 2
  check "SG4 the target followed its strip DOWN to index 5" \
    [pcall {wviewer::target_strip $tok}] 5
  check "SG4 and index 5 is the strip the target was on" [vecs_at $tok 5] vec_e
  check_true "SG4 the clamp alone would have given a DIFFERENT answer" \
    [expr {[wviewer::target_clamp 3 [ngraphs $tok]] != 5}]
  # a target ON the split strip stays on it — the source does not move
  fill_deep $tok
  pcall {wviewer::set_target_strip 1 $tok}
  pcall {wviewer::split_strip 1 $tok}
  check "SG4 a target ON the split strip stays with node 0" \
    [pcall {wviewer::target_strip $tok}] 1
  check "SG4 and that strip is the one that kept node 0" [vecs_at $tok 1] vec_a
  # a target ABOVE the split is untouched
  fill_deep $tok
  pcall {wviewer::set_target_strip 0 $tok}
  pcall {wviewer::split_strip 1 $tok}
  check "SG4 a target ABOVE the split is untouched" \
    [pcall {wviewer::target_strip $tok}] 0

  # --- SG5: one undo point per gesture ---------------------------------------
  fill_viewer $tok
  set before [profile $tok]
  pcall {wviewer::split_strip 0 $tok}
  check "SG5 the split happened" [profile $tok] {1 1 1 1}
  check_true "SG5 one undo restores the model" \
    [expr {[pcall {wviewer::undo $tok}] ne {ERR}}]
  check "SG5 the model is back to the pre-split profile" [profile $tok] $before
  check "SG5 the undo was ONE step, not three" [ngraphs $tok] 2
  check "SG5 the traces came back to the strip they left, in order" \
    [vecs_at $tok 0] {vec_a vec_b vec_c}

  # --- SG6: logging, one regenerate, and NO add_graph ------------------------
  fill_viewer $tok
  set nlog [llength $::sp_log]
  set ::sp_addgraph 0
  set ::sp_regen 0
  rename wviewer::add_graph wviewer::__real_add_graph
  proc wviewer::add_graph {token} { incr ::sp_addgraph; return 0 }
  rename wviewer::regenerate wviewer::__real_regenerate
  proc wviewer::regenerate {token} {
    incr ::sp_regen
    return [wviewer::__real_regenerate $token]
  }
  check "SG6 the split happened" [pcall {wviewer::split_strip 0 $tok}] 2
  rename wviewer::add_graph {}
  rename wviewer::__real_add_graph wviewer::add_graph
  rename wviewer::regenerate {}
  rename wviewer::__real_regenerate wviewer::regenerate
  check "SG6 add_graph was NOT used to create the strips" $::sp_addgraph 0
  check "SG6 exactly ONE regenerate for the whole gesture" $::sp_regen 1
  check "SG6 exactly one line logged" [expr {[llength $::sp_log] - $nlog}] 1
  check "SG6 the line is replayable, with the EXPLICIT token" \
    [lindex $::sp_log end] "wviewer::split_strip 0 $tok"
  # hold the line before rebuilding: fill_viewer's own set_target_strip logs
  set replay [lindex $::sp_log end]
  fill_viewer $tok
  pcall {uplevel #0 $replay}
  check "SG6 replaying the logged line reproduces the state" [profile $tok] {1 1 1 1}
  check "SG6 and the same order came back" \
    [list [vecs_at $tok 0] [vecs_at $tok 1] [vecs_at $tok 2]] {vec_a vec_b vec_c}
  fill_viewer $tok
  xschem new_schematic switch $vdrw
  check "SG6 omitted token targets the active viewer" \
    [pcall {wviewer::split_strip 0}] 2

  # --- SG7 / SG8: the GATE and the partition ---------------------------------
  fill_viewer $tok
  set miss [find_empty_px $vdrw 0]
  set hit  [find_trace_px $vdrw 0]
  if {![llength $miss] || ![llength $hit]} {
    puts "SKIPPED: SG7-SG11 (no usable empty/trace pixel — window too small)"
  } else {
    lassign $miss epx epy
    lassign $hit  tpx tpy
    check "SG7 empty waveform space resolves to its strip" \
      [pcall {wviewer::strip_menu_pick $vdrw $epx $epy}] 0
    check "SG7 a pixel ON a trace refuses (that is item 7's)" \
      [pcall {wviewer::strip_menu_pick $vdrw $tpx $tpy}] -1
    check "SG7 a pixel outside every band refuses" \
      [pcall {wviewer::strip_menu_pick $vdrw -50 -50}] -1
    # ⚠ THE LABEL MARGIN. A Button3 PRESS above the plot box is already the wave
    # attributes dialog (callback.c ~896), so a menu posted on that release
    # would land on top of it. The first cut of this gate tested only
    # "no trace here", which the margin also satisfies — it fired there, and
    # this is the regression leg for the plotbox_at rung that closed it.
    set marg [find_margin_px $vdrw 0]
    if {[llength $marg]} {
      check_true "SG7 fixture: the margin pixel IS in the band" \
        [expr {[wviewer::strip_at_pixel $vdrw [lindex $marg 0] [lindex $marg 1]] == 0}]
      check "SG7 fixture: ... and the engine says it is OUTSIDE the plot box" \
        [pcall {wviewer::plotbox_at $vdrw 0 [lindex $marg 0] [lindex $marg 1]}] 0
      check "SG7 the label margin refuses (the wave-attributes dialog owns it)" \
        [pcall {wviewer::strip_menu_pick $vdrw [lindex $marg 0] [lindex $marg 1]}] -1
      # teeth: the in-box pixel and the margin pixel differ only in the box test
      check "SG7 the in-box pixel passes the very test the margin fails" \
        [list [pcall {wviewer::plotbox_at $vdrw 0 $epx $epy}] \
              [pcall {wviewer::plotbox_at $vdrw 0 [lindex $marg 0] [lindex $marg 1]}]] {1 0}
    } else {
      puts "SKIPPED: SG7 margin legs (no in-band pixel outside the plot box)"
    }
    set miss1 [find_empty_px $vdrw 1]
    if {[llength $miss1]} {
      check "SG7 a one-trace strip refuses (already split)" \
        [pcall {wviewer::strip_menu_pick $vdrw [lindex $miss1 0] [lindex $miss1 1]}] -1
    } else {
      puts "SKIPPED: SG7 one-trace-strip leg (no empty pixel on strip 1)"
    }
    # SG8: the two gates PARTITION the body — never both, never neither
    check "SG8 the trace gate and the strip gate never both accept a pixel" \
      [list [lindex [wviewer::trace_menu_pick $vdrw $tpx $tpy] 0] \
            [wviewer::strip_menu_pick $vdrw $tpx $tpy]] {0 -1}
    check "SG8 ... and the other way round on empty space" \
      [list [lindex [wviewer::trace_menu_pick $vdrw $epx $epy] 0] \
            [wviewer::strip_menu_pick $vdrw $epx $epy]] {-1 0}

    # --- SG9: the MENU widget ------------------------------------------------
    set m [pcall {wviewer::strip_menu_build $tok 0}]
    check "SG9 the menu is a child of the viewer TOPLEVEL" $m $vtop.wvstripmenu
    check "SG9 it is a different widget from the trace menu" \
      [expr {$m ne "$vtop.wvtracemenu"}] 1
    check "SG9 it is not tearable off" [$m cget -tearoff] 0
    check "SG9 entry 0 is a disabled header counting the traces" \
      [list [$m entrycget 0 -label] [$m entrycget 0 -state]] {{Strip 1 — 3 traces} disabled}
    check "SG9 entry 1 is the separator" [$m type 1] separator
    check "SG9 entry 2 is the command" \
      [list [$m type 2] [$m entrycget 2 -label]] {command {Split Strip}}
    check "SG9 the command is fully resolved (index + explicit token)" \
      [$m entrycget 2 -command] "wviewer::split_strip 0 $tok"
    $m invoke 2
    check "SG9 invoking the entry splits" [profile $tok] {1 1 1 1}
    check "SG9 unposting removes the widget" [pcall {wviewer::strip_menu_unpost $tok}] 1
    check "SG9 unposting again is a no-op" [pcall {wviewer::strip_menu_unpost $tok}] 0

    # --- SG10: the GESTURE ---------------------------------------------------
    # tk_popup is SPIED: a live popup takes a global grab that would swallow
    # every later leg's events.
    rename ::tk_popup ::__sp_real_tk_popup
    proc ::tk_popup {m x y args} { set ::sp_popped [list $m $x $y] }

    fill_viewer $tok
    set ::sp_popped {}
    sg_ev $vdrw <ButtonPress-3>   -x $epx -y $epy
    sg_ev $vdrw <ButtonRelease-3> -x $epx -y $epy -state 0x400
    update
    check_true "SG10 a no-travel RMB on empty space posts a menu" \
      [expr {[llength $::sp_popped] == 3}]
    check "SG10 and it is the STRIP menu, not the trace menu" \
      [lindex $::sp_popped 0] $vtop.wvstripmenu
    check "SG10 the click itself mutated nothing" [profile $tok] {3 1}
    catch {wviewer::strip_menu_unpost $tok}

    # the same gesture on a TRACE pixel gets the trace menu — the dispatcher
    # offers the more specific one first (the partition, end to end)
    set ::sp_popped {}
    sg_ev $vdrw <ButtonPress-3>   -x $tpx -y $tpy
    sg_ev $vdrw <ButtonRelease-3> -x $tpx -y $tpy -state 0x400
    update
    check "SG10 a click on a trace gets the TRACE menu instead" \
      [lindex $::sp_popped 0] $vtop.wvtracemenu
    catch {wviewer::trace_menu_unpost $tok}

    # a travelled RMB is a box zoom, and must post nothing
    wviewer::fit $tok
    xschem new_schematic switch $vdrw
    set zx1 [xschem getprop rect 2 0 x1]
    set zx2 [xschem getprop rect 2 0 x2]
    set ::sp_popped {}
    set W [winfo width $vdrw]
    sg_ev $vdrw <ButtonPress-3>   -x [expr {int(0.30 * $W)}] -y $epy
    sg_ev $vdrw <ButtonRelease-3> -x [expr {int(0.70 * $W)}] -y $epy -state 0x400
    update
    check "SG10 a travelled RMB posts NO menu" [llength $::sp_popped] 0
    xschem new_schematic switch $vdrw
    check_true "SG10 and the box zoom still happened (x-span narrowed)" \
      [expr {([xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]) <
             ($zx2 - $zx1) - 1e-9}]
    # a modified RMB belongs to whatever else claims it
    wviewer::fit $tok
    set ::sp_popped {}
    sg_ev $vdrw <ButtonPress-3>   -x $epx -y $epy -state 4
    sg_ev $vdrw <ButtonRelease-3> -x $epx -y $epy -state 0x404
    update
    check "SG10 a Control-modified RMB posts no menu" [llength $::sp_popped] 0

    rename ::tk_popup {}
    rename ::__sp_real_tk_popup ::tk_popup
    catch {unset ::wviewer::b3x0($vdrw)}
    catch {unset ::wviewer::b3y0($vdrw)}
    catch {unset ::wviewer::b3mk($vdrw)}
  }

  # --- SG11: the menubar twin ------------------------------------------------
  set gm $vtop.wvmenubar.graph
  if {[winfo exists $gm]} {
    set idx -1
    for {set i 0} {$i <= [$gm index end]} {incr i} {
      if {[catch {$gm entrycget $i -label} lb]} continue
      if {$lb eq {Split Strip}} { set idx $i; break }
    }
    check_true "SG11 the Graph menu has a Split Strip entry" [expr {$idx >= 0}]
    if {$idx >= 0} {
      fill_viewer $tok
      pcall {wviewer::set_target_strip 0 $tok}
      $gm invoke $idx
      check "SG11 invoking it splits the TARGET strip" [profile $tok] {1 1 1 1}
      # teeth: it really follows the target, it is not hardwired to strip 0
      fill_deep $tok
      pcall {wviewer::set_target_strip 1 $tok}
      check "SG11 split_target_strip resolves the target" \
        [pcall {wviewer::split_target_strip $tok}] 2
      check "SG11 and it split strip 1, not strip 0" [profile $tok] {1 1 1 1 1 1}
      check "SG11 the logged line carries the RESOLVED index" \
        [lindex $::sp_log end] "wviewer::split_strip 1 $tok"
    }
  } else {
    puts "SKIPPED: SG11 (viewer menubar not found)"
  }

  # --- SG12..SG18: REUSE the ADJACENT empty strip (D3/D4) --------------------
  #
  # ⚠ THE HOLLOWNESS TRAP: with an empty strip at gi + 1, "consume it" and
  # "insert one there" leave node 1 at the same index. Every leg below therefore
  # asserts the strip COUNT (reuse inserts fewer strips, or none at all) and the
  # strip IDENTITY (the inert `smid` key — a strip the gesture CREATED reads back
  # as `-`; the SD legs of test_wave_viewer.tcl set the precedent).
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
    # identities go on AFTER the traces (add_trace rewrites the strip dict)
    set out {}
    set gi 0
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      set G [dict replace $G smid [string index ABCDEFGH $gi]]
      if {$gi == $auto} { set G [dict replace $G auto 1] }
      lappend out $G
      incr gi
    }
    wviewer::set_graphs $tok $out
    wviewer::regenerate $tok
    wviewer::fit $tok
    wviewer::set_target_strip 0 $tok
  }
  proc smids {tok} {
    set out {}
    foreach G [dict get [wviewer::layout_for $tok] graphs] {
      lappend out [wviewer::dget $G smid -]
    }
    return $out
  }
  proc kill_list {tok} {
    return [wviewer::empty_strips_to_delete \
              [dict get [wviewer::layout_for $tok] graphs] \
              [wviewer::auto_graph_index $tok]]
  }

  # SG12: three traces with an empty strip below — ONE strip inserted, not two
  fill_spec $tok {{vec_a vec_b vec_c} {} {vec_d}}
  check "SG12 fixture: three traces, an EMPTY strip below, then one" \
    [profile $tok] {3 0 1}
  check "SG12 fixture identities" [smids $tok] {A B C}
  check "SG12 the split reports ONE new strip, not two" \
    [pcall {wviewer::split_strip 0 $tok}] 1
  check "SG12 so the stack grew by one, not by two" [ngraphs $tok] 4
  check "SG12 and the pre-existing empty strip is the one that took node 1" \
    [smids $tok] {A B - C}
  check "SG12 the run still reads node 0, 1, 2 downward (D-F)" \
    [list [vecs_at $tok 0] [vecs_at $tok 1] [vecs_at $tok 2]] {vec_a vec_b vec_c}
  check "SG12 the strip that was below is still below" [vecs_at $tok 3] vec_d
  xschem new_schematic switch $vdrw
  check "SG12 the rect count agrees with the model" [xschem get rects 2] 4
  check "SG12 the consumed strip's RECT carries node 1's trace" \
    [string match {*vec_b*} [xschem getprop rect 2 1 node]] 1
  check "SG12 buffer NOT left modified (read-only viewer discipline)" \
    [xschem get modified] 0

  # SG13: D4's zero-insert case — a REAL split that creates no strip at all.
  # 0 is a success: it mutates, it logs and it takes one undo point.
  fill_spec $tok {{vec_a vec_b} {} {vec_c}}
  set nlog [llength $::sp_log]
  lassign [wviewer::history_depth $tok] u0 r0
  set ::sp_regen 0
  rename wviewer::regenerate wviewer::__real_regenerate
  proc wviewer::regenerate {token} {
    incr ::sp_regen
    return [wviewer::__real_regenerate $token]
  }
  check "SG13 a two-trace split with an empty strip below returns 0 new strips" \
    [pcall {wviewer::split_strip 0 $tok}] 0
  rename wviewer::regenerate {}
  rename wviewer::__real_regenerate wviewer::regenerate
  check "SG13 the strip count did NOT change" [ngraphs $tok] 3
  check "SG13 the same three strips (identity, not arithmetic)" [smids $tok] {A B C}
  check "SG13 node 1 moved into the strip that was already there" \
    [list [vecs_at $tok 0] [vecs_at $tok 1] [vecs_at $tok 2]] {vec_a vec_b vec_c}
  check "SG13 0 is a SUCCESS: it logged" [expr {[llength $::sp_log] - $nlog}] 1
  check "SG13 the logged line is the unchanged shape" \
    [lindex $::sp_log end] "wviewer::split_strip 0 $tok"
  lassign [wviewer::history_depth $tok] u1 r1
  check "SG13 ... and took exactly ONE undo point" [expr {$u1 - $u0}] 1
  check "SG13 exactly one regenerate for the whole gesture" $::sp_regen 1
  check_true "SG13 one undo restores the model" \
    [expr {[pcall {wviewer::undo $tok}] ne {ERR}}]
  check "SG13 the undo put the traces and the empty strip back" \
    [list [profile $tok] [smids $tok]] {{2 0 1} {A B C}}

  # SG14: D3 — adjacency means BELOW only
  fill_spec $tok {{} {vec_a vec_b vec_c} {vec_d}}
  check "SG14 an empty strip ABOVE is NOT consumed" \
    [pcall {wviewer::split_strip 1 $tok}] 2
  check "SG14 so two strips were inserted" [ngraphs $tok] 5
  check "SG14 the empty strip above is still empty" [vecs_at $tok 0] {}
  check "SG14 identities: the two created strips sit below the source" \
    [smids $tok] {A B - - C}
  fill_spec $tok {{vec_a vec_b vec_c} {vec_d} {}}
  check "SG14 an empty strip TWO below is not consumed either" \
    [pcall {wviewer::split_strip 0 $tok}] 2
  check "SG14 so the stack grew by two" [ngraphs $tok] 5
  check "SG14 and that empty strip is still empty, at the bottom" \
    [list [vecs_at $tok 4] [smids $tok]] {{} {A - - B C}}

  # SG15: D-D — the auto-plot strip is never consumed, wherever it sits
  fill_spec $tok {{vec_a vec_b vec_c} {} {vec_d}} 1
  check "SG15 fixture: the strip below IS the auto-plot strip" \
    [pcall {wviewer::auto_graph_index $tok}] 1
  check "SG15 the split inserts both strips instead of consuming it" \
    [pcall {wviewer::split_strip 0 $tok}] 2
  check "SG15 the stack grew by two" [ngraphs $tok] 5
  check "SG15 the auto strip was pushed down, not filled" \
    [pcall {wviewer::auto_graph_index $tok}] 3
  check "SG15 it is still traceless" [vecs_at $tok 3] {}
  check "SG15 identities" [smids $tok] {A - - B C}

  # SG16: the stored TARGET must shift by the plan's ACTUAL insert count (D5)
  #
  # ⚠ TRIPLY hollow-able: target_index CLAMPS, the old `nc - 1` count would push
  # one strip too far, and the old `gi + 1` insertion point would push a target
  # sitting ON the reused strip. The fixture separates all three: 5 strips, the
  # source at 1 holding three traces, an EMPTY strip at 2, the target on strip 4.
  # Correct answer 5; old arithmetic 6; clamp alone 4.
  fill_spec $tok {{vec_a} {vec_a vec_b vec_c} {} {vec_d} {vec_e}}
  check "SG16 fixture profile" [profile $tok] {1 3 0 1 1}
  pcall {wviewer::set_target_strip 4 $tok}
  check "SG16 fixture target is strip 4" [pcall {wviewer::target_strip $tok}] 4
  check "SG16 the split consumed the empty strip and inserted ONE" \
    [pcall {wviewer::split_strip 1 $tok}] 1
  check "SG16 the target followed its strip down by exactly one" \
    [pcall {wviewer::target_strip $tok}] 5
  check "SG16 and index 5 is the strip the target was on (identity)" \
    [list [vecs_at $tok 5] [lindex [smids $tok] 5]] {vec_e E}
  check_true "SG16 the old nc-1 arithmetic would have said 6" \
    [expr {[wviewer::index_after_insert 4 2 2] == 6}]
  check_true "SG16 and the clamp alone would have said 4" \
    [expr {[wviewer::target_clamp 4 [ngraphs $tok]] == 4}]
  # a target sitting ON the reused strip stays on it — it did not move
  fill_spec $tok {{vec_a} {vec_a vec_b vec_c} {} {vec_d} {vec_e}}
  pcall {wviewer::set_target_strip 2 $tok}
  pcall {wviewer::split_strip 1 $tok}
  check "SG16 a target ON the consumed strip stays with it" \
    [pcall {wviewer::target_strip $tok}] 2
  check "SG16 and that strip now holds node 1" \
    [list [vecs_at $tok 2] [lindex [smids $tok] 2]] {vec_b C}

  # SG17: the log line carries no reuse decision, so a REPLAY must recompute it
  fill_spec $tok {{vec_a vec_b vec_c} {} {vec_d}}
  set nlog [llength $::sp_log]
  check "SG17 the split reused the strip below" [pcall {wviewer::split_strip 0 $tok}] 1
  check "SG17 exactly one line logged" [expr {[llength $::sp_log] - $nlog}] 1
  set replay [lindex $::sp_log end]
  check "SG17 the line is the unchanged shape" $replay "wviewer::split_strip 0 $tok"
  set post_ids [smids $tok]
  set post_prof [profile $tok]
  check_true "SG17 one undo restores the model" \
    [expr {[pcall {wviewer::undo $tok}] ne {ERR}}]
  check "SG17 the undo put the empty strip back" \
    [list [profile $tok] [smids $tok]] {{3 0 1} {A B C}}
  pcall {uplevel #0 $replay}
  check "SG17 the replay reproduced the state EXACTLY (same plan)" \
    [list [profile $tok] [smids $tok] [ngraphs $tok]] [list $post_prof $post_ids 4]

  # SG18: the interaction with `e` (item 5) — a consumed strip is one `e` no
  # longer finds, and D-C still holds
  fill_spec $tok {{vec_a vec_b} {} {}}
  check "SG18 before the split, `e` would delete both empty strips" \
    [kill_list $tok] {1 2}
  check "SG18 the split consumes the ADJACENT one and inserts nothing" \
    [pcall {wviewer::split_strip 0 $tok}] 0
  check "SG18 one empty strip is left for `e`" [kill_list $tok] 2
  check "SG18 `e` deletes exactly that one" [pcall {wviewer::delete_empty_strips $tok}] 1
  check "SG18 leaving the two strips that hold traces" \
    [list [profile $tok] [smids $tok]] {{1 1} {A B}}
  check "SG18 and `e` is then a no-op" [pcall {wviewer::delete_empty_strips $tok}] 0
  check "SG18 D-C: a window of one empty strip still keeps it" \
    [wviewer::empty_strips_to_delete [list [wviewer::empty_graph]]] {}

  rename wviewer::log_action {}
  rename wviewer::__real_log_action wviewer::log_action
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
puts "test_wave_split_strip: $npass passed, $fail failed"
# run_suites.sh classifies on the literal string `ALL PASS` in the last RESULT
# line, and on exit status.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
