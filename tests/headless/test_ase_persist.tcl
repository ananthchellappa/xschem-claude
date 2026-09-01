# Waveform-viewer persistence + ROUND-3 ACCEPTANCE GATE (item 14 of
# doc/claude/ase_l_batch, spec doc/claude/specs/waveform_viewer.md
# "Persistence" + "Item 14 notes"):
#   R1   ase::state_default carries `viewer {}` + exactly the 15 schema keys
#        (headless, pure)
#   R2   viewer-key round-trip byte-stability: a state with a full viewer
#        dict (auto-marked graph w/ RPN trace + plain graph) save->load->save
#        byte-identical; the reloaded graphs value IDENTICAL incl. `auto 1`
#   R3   old-state compat: a viewer-less 13-key file + unknown key loads with
#        viewer {} default-merged, unknown key preserved; re-save writes
#        `viewer {}` as the LAST schema line before the unknown key
#   R4   wviewer::snapshot closed arms (pure): no window + no prev -> {};
#        no window + prev -> prev with `open 0`, graphs KEPT
#   R5   (--nogui arm only) ase::open_state on an `open 1` state -> 1, no Tk
#        side effects (wviewer::window_for stays {})
#   G1   fresh session on the committed-shape state: window up, NO viewer
#        auto-open (viewer {})
#   G2   Choose Analyses through the REAL dialog: dc V2 0..1.8 step 0.01
#        enabled via widgets + <Return>; op stays enabled; plot_sim_type dc
#   G3   REAL <Button-1> on the id row's Plot cell -> state plot 1
#   G3s  Outputs > To Be Saved > Select On Design: click the D wire + REAL
#        ESC -> output row {expr v(d) save 1 plot 0}. WHY this step is part
#        of the acceptance flow: ngspice restricts the raw to the .save set,
#        so without it v(d) is NOT in the dc raw and the shipped item-13
#        add_trace honestly REFUSES an unknown vector while a raw is loaded
#        — Direct Plot of an unsaved net cannot land a trace. A real ADE-L
#        user marks the net To Be Saved before running, exactly this step.
#   G4   Netlist and Run -> viewer auto-opens, raw attached (dc, 181 pts),
#        auto graph 0 = exactly the id trace, raw index id >= 0
#   G5   cursor A + readout: x=1.8 + id vs `xschem raw value id 180` ground
#        truth (hundreds of uA, eng notation)
#   G6   Direct Plot click on the D wire + REAL ESC -> ONE new non-auto graph
#        with exactly v(d); auto graph + outputs untouched
#   G7   Save State to scratch view ngspice_persist1 (REAL dialog + Return):
#        file exists, viewer dict open 1 + 2 graphs + auto marker + exact
#        trace model dicts
#   G8   close (viewer dies too) -> reopen the scratch view: viewer
#        RELAUNCHES, layout restored, raw re-attached, id re-materialized,
#        cursor A readout sane again (the gate's heart)
#   G9   no-auto-open arms: viewer `open 0` (graphs kept) and viewer key
#        REMOVED (old-state fixture live) -> session up, NO viewer
#   G10  missing-raw arm: `open 1` + raw DELETED -> viewer up, layout
#        restored, raw not loaded, redraw rc 0, NO crash
#   G11  rawfile seam: viewer rawfile = RELATIVE test_nfet_final_ase.raw
#        (resolved against the state rundir) -> raw attached
# Hermetic: the committed sky130_tests/test_nfet_final cell is CLONED into a
# scratch dir (the committed tree is never written); state shaping goes ONLY
# through the public ase::state_load/state_save schema on the CLONE.
#
# Runs via full_audit's DEFAULT arm (GUI legs self-SKIP without a usable
# DISPLAY; run legs additionally self-SKIP without ngspice — the item-14
# PROOF run must show ZERO SKIPs on G1-G11). Standalone repro from the repo
# ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_persist.tcl
# (headless arm: add --nogui)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# wait for a real, mapped main canvas (WSLg can be slow to map the window);
# returns 0 when it never becomes usable -> the caller SKIPs, not FAILs
proc main_ready {} {
  catch {wm geometry . 1000x800}
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo ismapped .drw] && [winfo width .drw] > 300 && [winfo height .drw] > 300} {
      return 1
    }
  }
  return 0
}

# error-guarded raw query: `xschem raw ...` THROWS when nothing is loaded —
# a missing raw must FAIL its check, not abort the test
proc rawq {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

# the vec fields of graph $i's traces in graph-list $gs ({} when absent)
proc gvecs {gs i} {
  if {![string is integer -strict $i] || $i < 0 || $i >= [llength $gs]} {
    return {}
  }
  set out {}
  foreach tr [wviewer::dget [lindex $gs $i] traces {}] {
    lappend out [wviewer::dget $tr vec {}]
  }
  return $out
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch ase_persist]

# model resolution exactly as sky130A/cadence_style_rc sets it
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]

# --- fixture: CLONE the committed cell, scratch registry ---------------------
set clonelib [file join $scratch sky130_tests]
file mkdir $clonelib
file copy [file join $repo sky130A xschem_libs sky130_tests test_nfet_final] \
  $clonelib
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests $clonelib"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]
set schpath [file normalize \
  [file join $clonelib test_nfet_final schematic test_nfet_final.sch]]
set clonestate [file join $clonelib test_nfet_final ngspice_state1 \
  test_nfet_final.state]
set key [ase::session_key sky130_tests test_nfet_final ngspice_state1]

if {[catch {

# hermetic rundir: rewrite the CLONE's state file through the public schema
# BEFORE any session opens (fixture shaping, not a flow workaround)
set cst [ase::state_load $clonestate]
dict set cst rundir $rundir
ase::state_save $clonestate $cst

# --- R1: state_default gained the viewer key ---------------------------------
set d [ase::state_default]
check "R1 state_default has viewer {}" [dict get $d viewer] {}
# `cosim` joined in §E of doc/claude/specs/mixed_signal_signal_browser.md. It is
# in ase::omit_if_empty, so an empty one is not serialized and R2's
# byte-identical round trip below is unaffected. `save_op_params` (plan step S4
# / issue 0617 -- the gate that carries op_annot's device OP `.save` cards into
# the deck) joined for exactly the same reason and with the same `{}` default:
# a `0` default would be serialized into all 104 committed .state files and
# would break R2 here and F3/G3/R4/V4 in the sibling suites.
check "R1 exactly the 17 schema keys" [lsort [dict keys $d]] \
  [lsort {version simulator design rundir temperature models variables \
          analyses outputs save_all_v save_all_i save_op_params options \
          includes pre_commands cosim viewer}]

# --- R2: viewer round-trip byte-stability ------------------------------------
set vgraphs [list \
  [dict create traces {{expr {i(v1) -1 *} name id vec id color 4}} \
               logx 0 logy 0 x1 {} x2 {} y1 {} y2 {} auto 1] \
  [dict create traces {{expr v(d) name {} vec v(d) color 4}} \
               logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]]
set st2 [ase::state_default]
dict set st2 viewer [dict create open 1 sharedx 0 rawfile {} graphs $vgraphs]
ase::state_save [file join $scratch r2a.state] $st2
set st2b [ase::state_load [file join $scratch r2a.state]]
ase::state_save [file join $scratch r2b.state] $st2b
set f [open [file join $scratch r2a.state] rb]; set a [read $f]; close $f
set f [open [file join $scratch r2b.state] rb]; set b [read $f]; close $f
check_true "R2 save->load->save byte-identical with a viewer dict" \
  [expr {$a eq $b}]
set vg2 [dict get [dict get $st2b viewer] graphs]
check "R2 reloaded graphs IDENTICAL to the input" $vg2 $vgraphs
check "R2 auto 1 marker round-tripped on graph 0" \
  [wviewer::dget [lindex $vg2 0] auto 0] 1
check "R2 open/sharedx/rawfile round-tripped" \
  [list [dict get [dict get $st2b viewer] open] \
        [dict get [dict get $st2b viewer] sharedx] \
        [dict get [dict get $st2b viewer] rawfile]] {1 0 {}}

# --- R3: old-state compat (no viewer key) ------------------------------------
set old [dict remove [ase::state_default] viewer]
dict set old zz_custom {kept 1}
ase::state_save [file join $scratch r3.state] $old
set f [open [file join $scratch r3.state] r]; set out3 [read $f]; close $f
check_true "R3 fixture file carries NO viewer line" \
  [expr {[lsearch -glob [split [string trimright $out3 "\n"] "\n"] {viewer *}] < 0}]
set st3 [ase::state_load [file join $scratch r3.state]]
check "R3 viewer default-merged to {}" [dict get $st3 viewer] {}
check "R3 unknown key preserved" [dict get $st3 zz_custom] {kept 1}
ase::state_save [file join $scratch r3b.state] $st3
set f [open [file join $scratch r3b.state] r]; set out3b [read $f]; close $f
set lines3 [split [string trimright $out3b "\n"] "\n"]
check "R3 re-save: viewer {} is the last schema line" \
  [lindex $lines3 end-1] {viewer {}}
check "R3 re-save: unknown key after it" [lindex $lines3 end] {zz_custom {kept 1}}

# --- R4: snapshot closed arms (pure, no window) ------------------------------
check "R4 snapshot: no window + no prev -> {}" [wviewer::snapshot tokR4 {}] {}
set prevd [dict create open 1 sharedx 1 rawfile {} \
  graphs {{traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {} auto 1}}]
check "R4 snapshot: no window + prev -> open flipped to 0" \
  [wviewer::snapshot tokR4 $prevd] [dict replace $prevd open 0]
check "R4 snapshot closed arm KEEPS the graphs" \
  [dict get [wviewer::snapshot tokR4 $prevd] graphs] [dict get $prevd graphs]

# --- R6: viewer_restore RE-EXPRESSED ON results::resolve, and R604's ONE ------
#     SENTENCE. Results batch item 6, doc/claude/specs/results_selection.md
#     section 8 (R601/R604/R604a) and section 4 (R201).
#
# ⚠ THIS GROUP RUNS WITH OR WITHOUT A DISPLAY AND WITH OR WITHOUT NGSPICE, on
# purpose. T-E's other half lives in G10/G11 below, which self-skip -- and
# spec section 12 names T-E as the batch's one invariant that can be green by
# not having run. Everything here is pure Tcl over shims, so the sentence half
# of T-E is asserted on every single run of this file.
#
# `ase::ui::viewer_restore` used to implement section 4's `ok` and `invalid`
# arms BY HAND (absolute-ise against the rundir -> `file isfile` -> else
# `ase::last_rawfile`). It now asks `results::resolve`, which is the proc that
# was copied FROM it. The sentences below are the RESOLVER's own text, which the
# hand-written version never produced anywhere -- that is what makes these
# checks non-vacuous rather than a re-reading of the source.
set r6_top [ase::state_default]
set r6_rundir [file join $scratch r6run]
file mkdir $r6_rundir
set r6_real [file join $r6_rundir r6_present.raw]
set fp [open $r6_real w] ; puts $fp "Title: r6" ; close $fp

proc r6_state {rawfile} {
  global r6_top r6_rundir
  set st $r6_top
  dict set st rundir $r6_rundir
  dict set st viewer [dict create open 1 sharedx 0 rawfile $rawfile graphs {} \
                        mode single target 0]
  return $st
}
# the shims. `wviewer::restore` returns 1 so the generic no-results line is
# reachable (it is gated on the rc), and records what it was handed.
rename ase::session_state   r6_o_session_state
rename ase::last_rawfile    r6_o_last_rawfile
rename ase::last_vcdfiles   r6_o_last_vcdfiles
rename ase::plot_sim_type   r6_o_plot_sim_type
rename wviewer::restore     r6_o_wrestore
rename ::ase::echo          r6_o_echo
proc ase::session_state {key} { return $::r6_st }
proc ase::last_rawfile {key} { return $::r6_derived }
proc ase::last_vcdfiles {key} { return {} }
proc ase::plot_sim_type {st} { return tran }
proc wviewer::restore {token vdict rawfile sim_type {dbs {}}} {
  set ::r6_gotraw $rawfile
  return 1
}
proc ::ase::echo {msg {tag {}}} { lappend ::r6_said $msg ; return 1 }

proc r6_run {rawfile derived} {
  set ::r6_st [r6_state $rawfile]
  set ::r6_derived $derived
  set ::r6_said {}
  set ::r6_gotraw {NOT-CALLED}
  set rc [ase::ui::viewer_restore r6key]
  return [list $rc $::r6_gotraw $::r6_said]
}
proc r6_hits {said pat} { return [llength [lsearch -all -glob $said $pat]] }

# (1) nothing named, a derived result exists -> `default`: the derived path is
#     used and NOTHING is said. Every state file written before item 6 carries
#     `rawfile {}`, so a sentence here would land in the CIW on every session
#     open forever -- R604a.
lassign [r6_run {} $r6_real] r6rc r6raw r6msg
check "R6a default: the derived result is used" $r6raw $r6_real
check "R6a default: ...and nothing is said (R604a)" [llength $r6msg] 0
# (2) nothing named and nothing derived -> the pre-existing no-results sentence,
#     unchanged, still exactly once.
lassign [r6_run {} {}] r6rc r6raw r6msg
check "R6b nothing at all: no raw handed to the viewer" $r6raw {}
check "R6b nothing at all: the no-results sentence, once" \
  [r6_hits $r6msg {*no simulation results for this state*}] 1
# (3) a RELATIVE name that exists under the rundir -> `ok`: absolute-ised and
#     used, silently. This is G11's shape, asserted without a display.
lassign [r6_run r6_present.raw {}] r6rc r6raw r6msg
check "R6c ok: a relative name is resolved against the rundir" \
  [file normalize $r6raw] [file normalize $r6_real]
check "R6c ok: ...and nothing is said (R604a)" [llength $r6msg] 0
# (4) a named result that is GONE, with a derived one to fall back to ->
#     `invalid`: the resolver's own sentence, naming BOTH files.
lassign [r6_run r6_missing.raw $r6_real] r6rc r6raw r6msg
check "R6d invalid: falls back to the derived result" $r6raw $r6_real
check "R6d invalid: SAYS which result went missing, once (T-E, R604)" \
  [r6_hits $r6msg {*r6_missing.raw is no longer on disk*}] 1
check "R6d invalid: ...and names what it fell back to" \
  [r6_hits $r6msg {*falling back to r6_present.raw*}] 1
# (5) gone, and nothing to fall back to -> ONE sentence, not two: R604a
#     suppresses the generic no-results line when the resolver already spoke
#     about the same event.
lassign [r6_run r6_missing.raw {}] r6rc r6raw r6msg
check "R6e invalid+empty: no raw handed to the viewer" $r6raw {}
check "R6e invalid+empty: the resolver's sentence is emitted" \
  [r6_hits $r6msg {*r6_missing.raw is no longer on disk*}] 1
check "R6e invalid+empty: REPORTED ONCE -- no second, generic sentence (R604)" \
  [r6_hits $r6msg {*no simulation results for this state*}] 0
check "R6e invalid+empty: exactly one sentence in total" [llength $r6msg] 1
# (6) the `open 1` gate is untouched by the re-expression: a closed viewer
#     resolves nothing and says nothing.
set ::r6_st [r6_state r6_missing.raw]
dict set ::r6_st viewer [dict replace [dict get $::r6_st viewer] open 0]
set ::r6_derived {} ; set ::r6_said {} ; set ::r6_gotraw {NOT-CALLED}
check "R6f open 0 still returns 0 without touching the resolver" \
  [list [ase::ui::viewer_restore r6key] $::r6_gotraw [llength $::r6_said]] \
  {0 NOT-CALLED 0}

# restore every shim and PROVE it by body, not by name (a rename that left the
# shim in place would otherwise poison every leg below it).
foreach {r6_orig r6_name} {r6_o_session_state ase::session_state \
                           r6_o_last_rawfile ase::last_rawfile \
                           r6_o_last_vcdfiles ase::last_vcdfiles \
                           r6_o_plot_sim_type ase::plot_sim_type \
                           r6_o_wrestore wviewer::restore \
                           r6_o_echo ::ase::echo} {
  rename $r6_name {}
  rename $r6_orig $r6_name
}
# ⚠ FIX ROUND: the last element used to be
# `string first {results::resolve} [info body ase::ui::viewer_restore] >= 0`,
# and the proc's own COMMENT block contains that literal -- so replacing the
# CALL with the verbatim pre-item hand-written arms left this element GREEN.
# It now matches the CALL SHAPE on a line of its own, which no comment can
# satisfy. (Same repair as test_results_select's SEL350 element 1.)
check "R6 every shim restored" \
  [list [info procs r6_o_session_state] [info procs r6_o_wrestore] \
        [info procs r6_o_echo] \
        [regexp {\n\s*set res \[results::resolve} [info body ase::ui::viewer_restore]]] \
  {{} {} {} 1}

# --- T-E BOOKKEEPING: WHY THE LEGS DID OR DID NOT RUN ------------------------
# doc/claude/specs/results_selection.md section 12: T-E is the batch's ONE test
# that can be green BY NOT HAVING RUN -- G10/G11 self-skip without a usable
# DISPLAY and without ngspice, and a count that matches while the leg skipped is
# exactly the failure mode. So the REASON is recorded as it happens and then
# checked against the preconditions measured independently at the bottom of the
# file. A leg that stopped for some OTHER reason reds that check.
set te_why {no usable DISPLAY}

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # wait for the viewer canvas to be mapped (WSLg can be slow); 0 -> SKIP
  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  # focus-gated, done-expr-proven key delivery (test_ase_dialogs helpers —
  # generated keys go to the display's FOCUS window, asynchronous under WSLg)
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
  proc send_return {w done} {
    return [uplevel 1 [list send_key $w <Return> $done]]
  }

  # bbox with a retry loop (WSLg slow map) + real checkbox-cell click
  # (test_ase_window helpers)
  proc tv_bbox {tv item {col {}}} {
    for {set i 0} {$i < 100} {incr i} {
      update
      if {$col ne {}} { set bb [$tv bbox $item $col] } \
      else            { set bb [$tv bbox $item] }
      if {[llength $bb] == 4} { return $bb }
      after 50
    }
    return {}
  }
  proc tv_cell_click {tv item col {dx 0}} {
    set bb [tv_bbox $tv $item $col]
    if {[llength $bb] != 4} { return 0 }
    lassign $bb x y wdt hgt
    set cx [expr {$x + $wdt/2 + $dx}]; set cy [expr {$y + $hgt/2}]
    event generate $tv <ButtonPress-1> -x $cx -y $cy
    event generate $tv <ButtonRelease-1> -x $cx -y $cy
    update
    return 1
  }

  # REAL <Key-Escape> ends a Select-On-Design mode (gesture-test-full-
  # sequence lesson): gate each generate on Tk reporting the canvas as focus
  # owner and retry until the seized Key-Escape binding is provably reverted
  # (restored by the product's sod_end). Returns 1 when the mode ended.
  proc real_esc {cv pre_esc} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[bind $cv <Key-Escape>] eq $pre_esc} { return 1 }
      focus -force $cv
      update
      if {[focus -displayof $cv] eq $cv} {
        event generate $cv <Key-Escape>
        update
        if {[bind $cv <Key-Escape>] eq $pre_esc} { return 1 }
      }
      after 50
    }
    return 0
  }

  set mainok [main_ready]
  set have_ng [expr {[auto_execok ngspice] ne {}}]

  if {!$mainok} {
    set te_why {main window never became usable}
    puts "SKIPPED: G1-G11 acceptance legs (WSLg geometry: main window never became usable)"
  } else {

    # --- G1: fresh session, committed-shape state, NO viewer auto-open -------
    check "G1 open_state -> 1" \
      [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
    update
    set top [ase::ui::window_for $key]
    check_true "G1 session window exists" \
      [expr {$top ne {} && [winfo exists $top]}]
    check "G1 viewer {} state opened NO viewer" [wviewer::window_for $key] {}

    # --- G2: Choose Analyses through the REAL dialog -------------------------
    $top.mb.analyses invoke "Choose\u2026"
    update
    set w $top.chana
    check_true "G2 Choose Analyses dialog up" [winfo exists $w]
    $w.types.dc invoke
    update
    if {![info exists ::ase::ui::dlg($key,anen)] || !$::ase::ui::dlg($key,anen)} {
      $w.enable invoke
    }
    check "G2 Enable checkbutton set" $::ase::ui::dlg($key,anen) 1
    foreach {fld val} {source V2 start 0 stop 1.8 step 0.01} {
      $w.$fld delete 0 end
      $w.$fld insert 0 $val
    }
    send_return $w.step {![winfo exists $top.chana]}
    check_true "G2 dialog closed on Return (commit ran)" \
      [expr {![winfo exists $top.chana]}]
    set an2 [ase::state_get [ase::session_state $key] analyses]
    set dcrow {}; set oprow {}
    foreach a2 $an2 {
      if {[ase::state_get $a2 type] eq {dc}} { set dcrow $a2 }
      if {[ase::state_get $a2 type] eq {op}} { set oprow $a2 }
    }
    check "G2 dc enabled 1" [ase::state_get $dcrow enabled] 1
    check "G2 dc source V2" [ase::state_get $dcrow source] V2
    check "G2 dc start 0" [ase::state_get $dcrow start] 0
    check "G2 dc stop 1.8" [ase::state_get $dcrow stop] 1.8
    check "G2 dc step 0.01" [ase::state_get $dcrow step] 0.01
    check "G2 op row still enabled" [ase::state_get $oprow enabled] 1
    check "G2 plot_sim_type dc" \
      [ase::plot_sim_type [ase::session_state $key]] dc

    # --- G3: REAL <Button-1> on the id row's Plot cell -----------------------
    set otv $top.body.outs.tv
    check "G3 outs pane has the single id row" [llength [$otv children {}]] 1
    check "G3 REAL click on the Plot cell delivered" [tv_cell_click $otv 0 plot] 1
    set orow [lindex [ase::state_get [ase::session_state $key] outputs] 0]
    check "G3 id row plot 1" [ase::state_get $orow plot] 1
    check "G3 id row save still 1" [ase::state_get $orow save] 1

    # --- G3s: mark v(d) To Be Saved through the REAL click mode --------------
    # (see the header: without a `.save v(d)` the dc raw carries no v(d) and
    # Direct Plot of the unsaved net cannot land a trace — a real ADE-L user
    # marks the net To Be Saved before running)
    set cv .drw
    set pre_esc [bind $cv <Key-Escape>]
    $top.mb.outputs.saved invoke {Select On Design}
    update
    # make the design ctx current DETERMINISTICALLY before the click: WSLg
    # focus events still in flight can flip the current window after the
    # mode's own design_window raise; a real mouse click switches ctx as it
    # lands and sod_click with explicit coords bypasses that — replicate the
    # click's switch (the test_ase_plot P6 idiom)
    xschem new_schematic switch .drw
    check "G3s design is the current schematic" \
      [file normalize [xschem get schname]] $schpath
    ase::ui::sod_click $key 550 -330                   ;# the D-net wire
    update
    check "G3s REAL ESC ended the save mode" [real_esc $cv $pre_esc] 1
    set outs3 [ase::state_get [ase::session_state $key] outputs]
    check "G3s outputs gained the v(d) save row" [llength $outs3] 2
    set vrow [lindex $outs3 1]
    check "G3s v(d) row expr" [ase::state_get $vrow expr] {v(d)}
    check "G3s v(d) row save 1 / plot 0" \
      [list [ase::state_get $vrow save 0] [ase::state_get $vrow plot 0]] {1 0}

    if {!$have_ng} {
      set te_why {ngspice not found}
      puts "SKIPPED: G4-G11 run/relaunch acceptance legs (ngspice not found)"
      ase::ui::close $key
      update
    } else {

      # --- G4: Netlist and Run -> viewer auto-opens with the id trace --------
      $top.mb.sim invoke {Netlist and Run}
      set id4 [ase::session_getattr $key run_id]
      check_true "G4 run started (integer execute id)" \
        [string is integer -strict $id4]
      set ec4 [ase::wait $id4]
      update
      check "G4 exit 0" $ec4 0
      check "G4 status Ready" [$top.status.stat cget -text] {Status: Ready}
      check "G4 status light Green" [$top.status.stat cget -background] Green
      set vtop [wviewer::window_for $key]
      check_true "G4 viewer auto-opened" \
        [expr {$vtop ne {} && [winfo exists $vtop]}]
      set vready 0
      if {$vtop ne {}} { set vready [viewer_ready $vtop] }
      check "G4 viewer window mapped" $vready 1
      set vdrw $vtop.drw
      xschem new_schematic switch $vdrw
      check_true "G4 raw loaded index >= 0" \
        [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
               [rawq {xschem raw loaded}] >= 0}]
      check "G4 raw sim_type dc" [rawq {xschem raw sim_type}] dc
      check "G4 raw points 181 (dc 0..1.8 step 0.01)" \
        [rawq {xschem raw points}] 181
      check "G4 auto graph is graph 0" [wviewer::auto_graph_index $key] 0
      set gs4 [dict get [wviewer::layout_for $key] graphs]
      check "G4 auto graph carries EXACTLY the id trace" [gvecs $gs4 0] id
      check_true "G4 raw vector id materialized (raw add)" \
        [expr {[string is integer -strict [rawq {xschem raw index id}]] &&
               [rawq {xschem raw index id}] >= 0}]
      check "G4 redraw rc 0" [catch {xschem redraw}] 0

      # --- G5: cursor A + readout vs engine ground truth ---------------------
      set cmenu $vtop.wvmenubar.cursors
      $cmenu invoke [$cmenu index {Cursor A}]
      update
      xschem new_schematic switch $vdrw
      set truth [rawq {xschem raw value id 180}]
      check_true "G5 ground truth id(Vgs=1.8) ~ 409.68 uA" \
        [expr {[string is double -strict $truth] &&
               abs($truth * 1e6 - 409.68) < 1.0}]
      xschem redraw
      xschem set cursor1_x 1.8
      wviewer::readout_refresh $key
      set ta [$vtop.wvreadout.a cget -text]
      check_true "G5 readout A line carries x=[ase::format_value 1.8]" \
        [expr {[string first "x=[ase::format_value 1.8]" $ta] >= 0}]
      check_true "G5 readout A line carries id=[ase::format_value $truth] (eng notation)" \
        [expr {[string first "id=[ase::format_value $truth]" $ta] >= 0}]

      # --- G6: Direct Plot on the D wire -> ONE new graph with v(d) ----------
      set outs_snap [ase::state_get [ase::session_state $key] outputs]
      set pre_esc [bind $cv <Key-Escape>]
      $top.mb.results invoke {Direct Plot}
      update
      # the click's ctx switch, replicated (P6 idiom — see G3s)
      xschem new_schematic switch .drw
      check "G6 design is the current schematic" \
        [file normalize [xschem get schname]] $schpath
      ase::ui::sod_click $key 550 -330                 ;# the D-net wire
      update
      check "G6 REAL ESC ended the mode" [real_esc $cv $pre_esc] 1
      set gs6 [dict get [wviewer::layout_for $key] graphs]
      check "G6 exactly ONE new graph appended" [llength $gs6] 2
      check "G6 new graph is NOT auto-marked" \
        [wviewer::dget [lindex $gs6 1] auto 0] 0
      check "G6 new graph traces exactly v(d)" [gvecs $gs6 1] {v(d)}
      check "G6 auto graph untouched (still just id)" [gvecs $gs6 0] id
      check "G6 outputs unchanged (Direct Plot writes no outputs)" \
        [ase::state_get [ase::session_state $key] outputs] $outs_snap

      # --- G7: Save State to the scratch view ngspice_persist1 ---------------
      $top.mb.session invoke {Save State}
      update
      set w $top.saveas
      check_true "G7 Save State dialog up" [winfo exists $w]
      $w.view delete 0 end
      $w.view insert 0 ngspice_persist1
      send_return $w.view {![winfo exists $top.saveas]}
      check_true "G7 dialog closed (save ran)" [expr {![winfo exists $top.saveas]}]
      set persistfile [file join $clonelib test_nfet_final ngspice_persist1 \
        test_nfet_final.state]
      check_true "G7 scratch view state file created" [file isfile $persistfile]
      set pst [ase::state_load $persistfile]
      set vd7 [dict get $pst viewer]
      check "G7 snapshot: viewer open 1" [ase::state_get $vd7 open] 1
      # ⚠ RESTATED BY THE RESULTS BATCH'S ITEM 6 (T-F), not deleted and not
      # renumbered: its EXPECTATION genuinely changed. `wviewer::snapshot`
      # hardcoded `rawfile {}` from item 14 until item 6, and this check is what
      # pinned that hardcode -- the read side was complete, covered and correct
      # the whole time while NOTHING had ever written the slot. It now carries
      # THE SELECTED RESULT, written by the snapshot (absolute) and stored
      # RELATIVE to the state's rundir by ase::ui::viewer_snapshot (R602/R602a).
      # THIS IS THE ASSERTION THAT WOULD HAVE FAILED FOR THE WHOLE LIFE OF THE
      # SEAM -- doc/claude/specs/results_selection.md section 12, T-F.
      check "G7 snapshot: rawfile = the selected result, relative (T-F)" \
        [ase::state_get $vd7 rawfile x] test_nfet_final_ase.raw
      # ...and the relative form is not merely a shorter string: it resolves,
      # against the state's own rundir, to the raw the run actually produced.
      check_true "G7 snapshot: ...and it resolves to the run's raw (T-F)" \
        [expr {[file pathtype [ase::state_get $vd7 rawfile x]] ne {absolute} &&
               [file normalize [file join $rundir \
                  [ase::state_get $vd7 rawfile x]]] eq
               [file normalize [file join $rundir test_nfet_final_ase.raw]]}]
      set g7 [ase::state_get $vd7 graphs]
      check "G7 snapshot: 2 graphs" [llength $g7] 2
      check "G7 snapshot: auto marker on graph 0" \
        [wviewer::dget [lindex $g7 0] auto 0] 1
      check "G7 snapshot: graph 0 = the exact id trace model dict" \
        [dict get [lindex $g7 0] traces] \
        {{expr {i(v1) -1 *} name id vec id color 4}}
      check "G7 snapshot: graph 1 = the exact v(d) trace model dict" \
        [dict get [lindex $g7 1] traces] \
        {{expr v(d) name {} vec v(d) color 4}}

      # --- G8: close + relaunch (the gate's heart) ---------------------------
      # item 16: this session is DIRTY (viewer snapshot at save-time); the menu
      # Close now routes through close_request's save prompt, so tear down
      # directly (behavior-identical to the pre-rewire menu Close).
      ase::ui::close $key
      update
      check_true "G8 session toplevel gone" [expr {![winfo exists $top]}]
      check_true "G8 viewer closed with the session (item-13 lifecycle)" \
        [expr {![winfo exists $vtop]}]
      set key2 [ase::session_key sky130_tests test_nfet_final ngspice_persist1]
      check "G8 reopen the scratch view -> 1" \
        [ase::open_state sky130_tests test_nfet_final ngspice_persist1] 1
      update
      set top2 [ase::ui::window_for $key2]
      check_true "G8 NEW session window up" \
        [expr {$top2 ne {} && [winfo exists $top2]}]
      set vtop2 [wviewer::window_for $key2]
      check_true "G8 viewer RELAUNCHED" [expr {$vtop2 ne {}}]
      set vready2 0
      if {$vtop2 ne {}} { set vready2 [viewer_ready $vtop2] }
      check "G8 relaunched viewer mapped" $vready2 1
      set gs8 [dict get [wviewer::layout_for $key2] graphs]
      check "G8 layout restored: 2 graphs" [llength $gs8] 2
      check "G8 auto graph index 0" [wviewer::auto_graph_index $key2] 0
      check "G8 auto graph trace id" [gvecs $gs8 0] id
      check "G8 Direct-Plot graph trace v(d)" [gvecs $gs8 1] {v(d)}
      set vdrw2 $vtop2.drw
      xschem new_schematic switch $vdrw2
      check_true "G8 raw re-attached (loaded >= 0)" \
        [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
               [rawq {xschem raw loaded}] >= 0}]
      check "G8 raw sim_type dc" [rawq {xschem raw sim_type}] dc
      check "G8 raw points 181" [rawq {xschem raw points}] 181
      # T-F's second half: a save->restore round trip RE-SELECTS THE SAME
      # RESULT. Before item 6 the state named nothing, so what came back was
      # whatever ase::last_rawfile derived -- the right answer by luck, and
      # nothing distinguished the two. Here the stored name is what was
      # followed (G11b below is the leg that proves the two can differ).
      check "G8 T-F: the round trip re-attached the SAME result" \
        [file normalize [rawq {xschem raw rawfile}]] \
        [file normalize [file join $rundir test_nfet_final_ase.raw]]
      check_true "G8 raw index id >= 0 (RPN re-materialized)" \
        [expr {[string is integer -strict [rawq {xschem raw index id}]] &&
               [rawq {xschem raw index id}] >= 0}]
      check "G8 redraw rc 0" [catch {xschem redraw}] 0
      set cmenu2 $vtop2.wvmenubar.cursors
      $cmenu2 invoke [$cmenu2 index {Cursor A}]
      update
      xschem new_schematic switch $vdrw2
      xschem redraw
      xschem set cursor1_x 1.8
      wviewer::readout_refresh $key2
      set ta2 [$vtop2.wvreadout.a cget -text]
      check_true "G8 relaunched readout carries x=[ase::format_value 1.8]" \
        [expr {[string first "x=[ase::format_value 1.8]" $ta2] >= 0}]
      check_true "G8 relaunched readout carries id=[ase::format_value $truth] again" \
        [expr {[string first "id=[ase::format_value $truth]" $ta2] >= 0}]
      # raw backup for G11 (taken while the artifact still exists — G10
      # deletes it)
      set rawfile [file join $rundir test_nfet_final_ase.raw]
      set rawbak [file join $scratch raw_backup.raw]
      file copy -force $rawfile $rawbak

      # --- G9: no-auto-open arms ---------------------------------------------
      $top2.mb.session invoke Close
      update
      check_true "G9 session 2 closed" [expr {![winfo exists $top2]}]
      check_true "G9 viewer 2 closed" \
        [expr {$vtop2 eq {} || ![winfo exists $vtop2]}]
      # (a) open 0, graphs kept
      set pst [ase::state_load $persistfile]
      set vd_live [dict get $pst viewer]
      check "G9 sanity: stored viewer open 1" [ase::state_get $vd_live open] 1
      dict set pst viewer [dict replace $vd_live open 0]
      ase::state_save $persistfile $pst
      check "G9a reopen (viewer open 0) -> 1" \
        [ase::open_state sky130_tests test_nfet_final ngspice_persist1] 1
      update
      set top9 [ase::ui::window_for $key2]
      check_true "G9a session window up" \
        [expr {$top9 ne {} && [winfo exists $top9]}]
      check "G9a NO viewer auto-open (open 0)" [wviewer::window_for $key2] {}
      ase::ui::close $key2
      update
      # (b) viewer key removed entirely (old-state fixture live)
      set pst [ase::state_load $persistfile]
      set pst [dict remove $pst viewer]
      ase::state_save $persistfile $pst
      set f [open $persistfile r]; set raw9 [read $f]; close $f
      check_true "G9b rewritten state carries NO viewer line" \
        [expr {[lsearch -glob [split [string trimright $raw9 "\n"] "\n"] \
                 {viewer *}] < 0}]
      check "G9b reopen (no viewer key) -> 1" \
        [ase::open_state sky130_tests test_nfet_final ngspice_persist1] 1
      update
      set top9b [ase::ui::window_for $key2]
      check_true "G9b session window up" \
        [expr {$top9b ne {} && [winfo exists $top9b]}]
      check "G9b NO viewer auto-open (old state)" [wviewer::window_for $key2] {}
      ase::ui::close $key2
      update

      # --- G10: missing-raw arm ----------------------------------------------
      set pst [ase::state_load $persistfile]
      dict set pst viewer $vd_live
      ase::state_save $persistfile $pst
      file delete -force -- $rawfile
      # T-E, the DELETED half. Item 6's writer means $vd_live now NAMES the raw
      # (it carried the hardcoded empty `rawfile` before), so this arm stopped
      # being "nothing was named" and became `invalid`: the named result is
      # gone, the derived one (ase::last_rawfile) is the same deleted file, and
      # there is nothing to fall back to. R604 says the status is reported ONCE,
      # on restore, through ase::echo -- so the channel is captured here rather
      # than asserted from a green rc.
      set ::g10_said {}
      rename ::ase::echo g10_echo_orig
      proc ::ase::echo {msg {tag {}}} { lappend ::g10_said $msg ; return 1 }
      check "G10 sanity: the stored state NAMES the deleted result (T-E)" \
        [ase::state_get $vd_live rawfile x] test_nfet_final_ase.raw
      check "G10 reopen (open 1, raw deleted) -> 1" \
        [ase::open_state sky130_tests test_nfet_final ngspice_persist1] 1
      update
      rename ::ase::echo {}
      rename g10_echo_orig ::ase::echo
      check "G10 T-E: the echo shim was restored" \
        [expr {[info procs ::ase::echo] ne {} && [info procs g10_echo_orig] eq {}}] 1
      # the sentence NAMES the result that went missing, and it is the
      # resolver's own -- not the generic "no simulation results" line, which
      # R604a suppresses when the resolver has already spoken about the event.
      set g10_hit {}
      foreach m $::g10_said {
        if {[string first {test_nfet_final_ase.raw is no longer on disk} $m] >= 0} {
          set g10_hit $m
        }
      }
      check_true "G10 T-E: restore SAID which result went missing" \
        [expr {$g10_hit ne {}}]
      check "G10 T-E: ...and said it exactly once" \
        [llength [lsearch -all -glob $::g10_said {*is no longer on disk*}]] 1
      check "G10 T-E: ...and did NOT also emit the generic no-results line" \
        [llength [lsearch -all -glob $::g10_said \
                    {*no simulation results for this state*}]] 0
      set top10 [ase::ui::window_for $key2]
      check_true "G10 session window up" \
        [expr {$top10 ne {} && [winfo exists $top10]}]
      set vtop10 [wviewer::window_for $key2]
      check_true "G10 viewer up despite the missing raw" [expr {$vtop10 ne {}}]
      set vready10 0
      if {$vtop10 ne {}} { set vready10 [viewer_ready $vtop10] }
      check "G10 viewer mapped" $vready10 1
      set gs10 [dict get [wviewer::layout_for $key2] graphs]
      check "G10 layout restored: 2 graphs" [llength $gs10] 2
      check "G10 model traces present (id / v(d))" \
        [list [gvecs $gs10 0] [gvecs $gs10 1]] {id v(d)}
      xschem new_schematic switch $vtop10.drw
      set rl10 [rawq {xschem raw loaded}]
      check_true "G10 raw NOT loaded (errors-or-negative)" \
        [expr {[string match ERR:* $rl10] || $rl10 < 0}]
      check "G10 redraw rc 0 (traces draw empty, no crash)" \
        [catch {xschem redraw}] 0
      ase::ui::close $key2
      update

      # --- G11: rawfile seam (relative name, resolved against rundir) --------
      set pst [ase::state_load $persistfile]
      dict set pst viewer [dict replace $vd_live rawfile test_nfet_final_ase.raw]
      ase::state_save $persistfile $pst
      file copy -force $rawbak $rawfile
      check "G11 reopen (relative rawfile seam) -> 1" \
        [ase::open_state sky130_tests test_nfet_final ngspice_persist1] 1
      update
      set vtop11 [wviewer::window_for $key2]
      check_true "G11 viewer up" [expr {$vtop11 ne {}}]
      set vready11 0
      if {$vtop11 ne {}} { set vready11 [viewer_ready $vtop11] }
      check "G11 viewer mapped" $vready11 1
      xschem new_schematic switch $vtop11.drw
      check_true "G11 raw attached through the rawfile seam (loaded >= 0)" \
        [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
               [rawq {xschem raw loaded}] >= 0}]
      ase::ui::close $key2
      update
      check "G11 session closed clean" [ase::ui::window_for $key2] {}

      # --- G11b: T-E, the RELATIVE half, made DISCRIMINATING -----------------
      # G11 above cannot tell "the stored name was followed" from "the derived
      # default happened to be the same file", because it is. So: a SECOND raw
      # in the same rundir under a name the derived default can never produce.
      # If the seam is honoured, THAT is what the registry ends up holding.
      set altraw [file join $rundir alt_pick.raw]
      file copy -force $rawbak $altraw
      set pst [ase::state_load $persistfile]
      dict set pst viewer [dict replace $vd_live rawfile alt_pick.raw]
      ase::state_save $persistfile $pst
      check "G11b reopen (relative name of a DIFFERENT raw) -> 1" \
        [ase::open_state sky130_tests test_nfet_final ngspice_persist1] 1
      update
      set vtop11b [wviewer::window_for $key2]
      check_true "G11b viewer up" [expr {$vtop11b ne {}}]
      if {$vtop11b ne {}} { viewer_ready $vtop11b }
      xschem new_schematic switch $vtop11b.drw
      check "G11b T-E: the STORED name was followed, not the derived default" \
        [file tail [rawq {xschem raw rawfile}]] alt_pick.raw
      check_true "G11b ...and it really attached (loaded >= 0)" \
        [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
               [rawq {xschem raw loaded}] >= 0}]
      ase::ui::close $key2
      update
      set te_why RAN
    }
  }

} else {
  # --- R5: headless open_state on an open-1 state (no Tk side effects) ------
  set cst5 [ase::state_load $clonestate]
  dict set cst5 viewer {open 1 sharedx 0 rawfile {} graphs {}}
  ase::state_save $clonestate $cst5
  check "R5 headless open_state on an open-1 state -> 1" \
    [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
  check "R5 no viewer window headless" [wviewer::window_for $key] {}
  ase::session_close $key
  puts "gui legs skipped (no DISPLAY)"
}

# --- T-E: ASSERT THE SKIP REASON, NOT JUST THE COUNT -------------------------
# The preconditions are re-measured HERE, independently of the branches that
# recorded `te_why`, and the two are compared. A leg that stopped for any other
# cause -- or one that silently never reached its end -- reds this check instead
# of leaving a matching check count behind. Nothing here prints a SKIP
# substring: full_audit.sh would score the WHOLE FILE as SKIP on one.
set te_expect {no usable DISPLAY}
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  if {[info exists mainok] && !$mainok} {
    set te_expect {main window never became usable}
  } elseif {[info exists have_ng] && !$have_ng} {
    set te_expect {ngspice not found}
  } elseif {[info exists mainok] && [info exists have_ng]} {
    set te_expect RAN
  }
}
puts "T-E legs: $te_why"
check "T-E legs: the recorded reason matches the measured preconditions" \
  $te_why $te_expect

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
test_scratch_drop $scratch      ;# early drop; the check below asserts removal
check "cleanup: scratch removed" [file exists $scratch] 0
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
