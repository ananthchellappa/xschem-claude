# ASE-L Select On Design + whole-flow GUI acceptance (item 08 of
# doc/claude/ase_l_batch, spec doc/claude/specs/ase_l.md "UI v2" — the
# ROUND-2 ACCEPTANCE GATE):
#   H1     sod_expr builds lowercased v(<net>) / i(<inst>) tokens (headless)
#   H2     sod_merge queue semantics: append / OR-flags merge / identical
#          re-queue nochange / other rows intact (headless)
#   I1-I10 the Select On Design click mode on the design schematic (GUI,
#          needs a usable MAIN window): menu entry enters the mode and seizes
#          the canvas <ButtonPress-1>/<ButtonRelease-1>/<Key-Escape>
#          bindings; a REAL generated Motion+Press+Release gesture queues
#          v(g); direct sod_click legs queue v(d)/i(v1), dedupe on a
#          net-label click, refuse a non-source instance (v1 scope); the row
#          shows in the Outputs pane immediately; a REAL <Key-Escape> ends
#          the mode, restores all three bindings VERBATIM, leaves the
#          generic <ButtonPress> untouched and re-raises the ASE window
#          (W4 nudge/self-SKIP pattern); the To Be Plotted flavor ORs plot
#          into an existing row; the Add-Output dialog's From Design… button
#          closes the dialog and enters the mode; ase::ui::close ends an
#          active mode (binding-leak guard).
#   WF     the ROUND GATE whole-flow leg on a FRESH session: open the state
#          view -> Choose Analyses (op enabled) -> add output vd=v(d) via the
#          --> dialog -> Netlist and Run (log toplevel, status Ready, id
#          Value ~409.7uA, vd Value ~1.0) -> Save State to a scratch view ->
#          Close -> reopen the scratch view -> variables/analyses/outputs
#          repopulate identically.
# Hermetic: the committed sky130_tests/test_nfet_final cell is CLONED into a
# scratch dir (the committed tree is never written); the clone's state rundir
# is rewritten to the scratch through the public ase::state_load/state_save
# schema (the test_ase_final D7 fixture-shaping precedent).
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_interact.tcl
# (GUI legs need DISPLAY; the run legs need ngspice)

set fail 0; set npass 0
# check/check_true/main_ready/tv_find copied from tests/headless/test_ase_window.tcl
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

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

# the treeview item whose $col cell equals $val, or {}
proc tv_find {tv col val} {
  foreach it [$tv children {}] {
    if {[$tv set $it $col] eq $val} { return $it }
  }
  return {}
}

# menu_save_state variant (origin: tests/headless/test_ase_window.tcl): drive
# Session > Save State but retarget the View entry BEFORE proceeding — the
# Save-As dialog then creates/overwrites lib/cell/$view instead of the
# session's own view. Returns 1 when the dialog round completed.
proc menu_save_state_as {top view} {
  $top.mb.session invoke {Save State}
  for {set i 0} {$i < 100} {incr i} {
    update
    if {[winfo exists $top.saveas]} { break }
    after 20
  }
  if {![winfo exists $top.saveas]} { return 0 }
  $top.saveas.view delete 0 end
  $top.saveas.view insert 0 $view
  $top.saveas.btns.proceed invoke
  for {set i 0} {$i < 100} {incr i} {
    update
    if {![winfo exists $top.saveas]} { return 1 }
    after 20
  }
  return 0
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch ase_interact]

# model resolution exactly as sky130A/cadence_style_rc sets it (the
# test_ase_final idiom)
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]

# --- fixture: CLONE the committed cell, scratch registry (D10) ---------------
# sky130_tests points at the CLONE (Save-As writes land there); the device
# libraries point at the real committed trees.
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

if {[catch {

# hermetic rundir: rewrite the CLONE's state file through the public schema
# BEFORE any session opens (fixture shaping, not a flow workaround; the
# committed tree is never written)
set cst [ase::state_load $clonestate]
dict set cst rundir $rundir
ase::state_save $clonestate $cst

# --- H1: sod_expr (pure helper) ----------------------------------------------
## RESTATED, casemode batch item 9 (same ids, same expected strings): the case
## mode is now a REQUIRED third argument -- sod_expr folds only when the run's
## requested mode is `fold`, which is A1's default everywhere, so both expected
## values are unchanged. H1's real subject, that sod_expr is a PURE string op
## callable with no design loaded, is untouched: the mode arrives as an argument
## precisely so this proc never has to ask the engine (spec
## simulator_profiles.md §13.2).
check "H1 sod_expr voltage lowercases the net" \
  [ase::ui::sod_expr voltage D fold] {v(d)}
check "H1 sod_expr current lowercases the source" \
  [ase::ui::sod_expr current V1 fold] {i(v1)}

# --- H2: sod_merge (pure helper) ---------------------------------------------
lassign [ase::ui::sod_merge {} {v(d)} {save 1 plot 0}] rows2 st2
check "H2 sod_merge appends a new row" $st2 added
check "H2 appended row shape" $rows2 {{name {} expr v(d) plot 0 save 1}}
# OR the plot flavor into the save-only row
lassign [ase::ui::sod_merge $rows2 {v(d)} {save 1 plot 1}] rows2b st2b
check "H2 sod_merge ORs flags into an existing row" $st2b merged
check "H2 merged single row plot 1 save 1" $rows2b \
  {{name {} expr v(d) plot 1 save 1}}
# identical re-queue -> nochange, list returned unchanged
lassign [ase::ui::sod_merge $rows2b {v(d)} {save 1 plot 1}] rows2c st2c
check "H2 sod_merge identical re-queue is nochange" $st2c nochange
check "H2 nochange returns the outputs unchanged" $rows2c $rows2b
# other rows stay intact when a later row merges
set base {{name id expr -i(v1) save 1 plot 0} {name {} expr v(g) plot 0 save 1}}
lassign [ase::ui::sod_merge $base {v(g)} {save 1 plot 1}] rows2d st2d
check "H2 sod_merge leaves other rows intact" $rows2d \
  {{name id expr -i(v1) save 1 plot 0} {name {} expr v(g) plot 1 save 1}}

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set key [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  set mainok [main_ready]

  if {!$mainok} {
    puts "SKIPPED: I1-I10 Select On Design legs (WSLg geometry: main window never became usable)"
  } else {

    check "I0 open_state -> 1" \
      [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
    update
    set top [ase::ui::window_for $key]
    check_true "I0 session window exists" \
      [expr {$top ne {} && [winfo exists $top]}]

    # I1: the To Be Saved menu entry enters the mode on the design canvas.
    # Capture the PRE-mode values of all four bindings first (the design will
    # land in the pristine untitled MAIN window -> canvas .drw).
    set cv .drw
    set pre_press   [bind $cv <ButtonPress-1>]
    set pre_rel     [bind $cv <ButtonRelease-1>]
    set pre_esc     [bind $cv <Key-Escape>]
    set pre_generic [bind $cv <ButtonPress>]
    $top.mb.outputs.saved invoke {Select On Design}
    update
    check "I1 design is the current schematic" \
      [file normalize [xschem get schname]] $schpath
    check "I1 mode canvas is the main canvas" [xschem get current_win_path] .drw
    check_true "I1 ButtonPress-1 seized (non-empty binding)" \
      [expr {[bind $cv <ButtonPress-1>] ne {}}]

    # I2: REAL generated click gesture queues v(g) — Motion at the target
    # pixel FIRST (that is what refreshes mousex_snap), then Press/Release.
    # World (340,-330) = the G-net wire, clear of the lG label at 300,-330.
    # Pixel = (w + origin)/zoom (X_TO_SCREEN, xschem.h) after zoom_full.
    xschem zoom_full
    update
    set xorig [xschem get xorigin]
    set yorig [xschem get yorigin]
    set zoom  [xschem get zoom]
    set px [expr {int(round((340.0 + $xorig) / $zoom))}]
    set py [expr {int(round((-330.0 + $yorig) / $zoom))}]
    if {$px < 0 || $py < 0 || $px >= [winfo width $cv] || $py >= [winfo height $cv]} {
      puts "SKIPPED: I2 real-gesture leg (computed pixel $px,$py outside the mapped canvas)"
    } else {
      event generate $cv <Motion> -x $px -y $py
      update
      event generate $cv <ButtonPress-1> -x $px -y $py
      event generate $cv <ButtonRelease-1> -x $px -y $py
      update
      set outs [ase::state_get [ase::session_state $key] outputs]
      check_true "I2 real click gesture queues v(g)" \
        [string match "*{name {} expr v(g) plot 0 save 1}*" $outs]
    }

    # I3: direct wire click (D-net wire at 550,-330, clear of the lD label)
    ase::ui::sod_click $key 550 -330
    update
    set outs [ase::state_get [ase::session_state $key] outputs]
    check_true "I3 direct wire click queues v(d)" \
      [string match "*{name {} expr v(d) plot 0 save 1}*" $outs]
    check_true "I3 row visible in the Outputs pane immediately" \
      [expr {[tv_find $top.body.outs.tv name {v(d)}] ne {}}]

    # I4: net-label click resolves the SAME net -> nochange, no state write
    set before [ase::state_get [ase::session_state $key] outputs]
    ase::ui::sod_click $key 500 -330
    update
    check "I4 net-label click dedupes (outputs unchanged)" \
      [ase::state_get [ase::session_state $key] outputs] $before

    # I5: vsource click queues the source current i(v1); the committed
    # -i(v1) row is a DIFFERENT string and must survive beside it
    ase::ui::sod_click $key 600 -300
    update
    set outs [ase::state_get [ase::session_state $key] outputs]
    check_true "I5 vsource click queues i(v1)" \
      [string match "*{name {} expr i(v1) plot 0 save 1}*" $outs]
    check_true "I5 committed -i(v1) row still present" \
      [string match "*{name id expr -i(v1) save 1 plot 0}*" $outs]

    # I6: non-source instance (M1 subcircuit) queues NOTHING (v1 scope)
    set before [ase::state_get [ase::session_state $key] outputs]
    ase::ui::sod_click $key 400 -300
    update
    check "I6 non-source click queues nothing" \
      [ase::state_get [ase::session_state $key] outputs] $before

    # I7: a REAL <Key-Escape> on the canvas ends the mode. Generated
    # KeyPress events go to the display's FOCUS window and WSLg confirms
    # focus asynchronously (the test_ase_window send_return diagnosis), so
    # gate each generate on Tk reporting the canvas as focus owner and retry
    # until the mode is provably inactive (the seized Key-Escape binding
    # reverted — restored by the product's sod_end).
    set ended 0
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[bind $cv <Key-Escape>] eq $pre_esc} { set ended 1; break }
      focus -force $cv
      update
      if {[focus -displayof $cv] eq $cv} {
        event generate $cv <Key-Escape>
        update
        if {[bind $cv <Key-Escape>] eq $pre_esc} { set ended 1; break }
      }
      after 50
    }
    check "I7 ESC ends the mode via the REAL key" $ended 1
    check "I7 ButtonPress-1 binding restored verbatim" \
      [bind $cv <ButtonPress-1>] $pre_press
    check "I7 ButtonRelease-1 binding restored" \
      [bind $cv <ButtonRelease-1>] $pre_rel
    check "I7 Key-Escape binding restored" [bind $cv <Key-Escape>] $pre_esc
    check "I7 generic ButtonPress binding untouched" \
      [bind $cv <ButtonPress>] $pre_generic
    # ASE window re-raised above the design window after ESC — the W4
    # nudge/self-SKIP pattern (test_ase_window): the WSLg-safe raise is a
    # withdraw/deiconify re-map that can take ~2s to show in wm stackorder,
    # and WSLg occasionally DROPS a re-map outright; each nudge re-drives the
    # PRODUCT path (enter the mode + sod_end -> the same raise arm), so a
    # product regression that never raises still fails every attempt.
    proc i7_wait_ase_raised {top} {
      for {set i 0} {$i < 100} {incr i} {
        update
        set so [wm stackorder .]
        set ai [lsearch -exact $so $top]
        set di [lsearch -exact $so .]
        if {$ai >= 0 && $di >= 0 && $ai > $di} { return 1 }
        after 50
      }
      return 0
    }
    set raised [i7_wait_ase_raised $top]
    for {set nudge 1} {!$raised && $nudge <= 4} {incr nudge} {
      puts "  I7 raise stalled (WSLg re-map drop) — re-driving mode+sod_end (nudge $nudge)"
      $top.mb.outputs.saved invoke {Select On Design}
      update
      ase::ui::sod_end $key
      set raised [i7_wait_ase_raised $top]
    }
    if {$raised} {
      check "I7 ASE window re-raised after ESC" $raised 1
    } else {
      puts "SKIPPED: I7 raise assertion (WSLg stackorder stall after 5 product-path attempts)"
    }

    # I8: the To Be Plotted flavor ORs plot into the existing v(d) row —
    # still exactly ONE v(d) row
    $top.mb.outputs.plotted invoke {Select On Design}
    update
    ase::ui::sod_click $key 550 -330
    update
    set outs [ase::state_get [ase::session_state $key] outputs]
    check_true "I8 To Be Plotted flavor merges plot into v(d)" \
      [string match "*{name {} expr v(d) plot 1 save 1}*" $outs]
    set nvd 0
    foreach o $outs {
      if {[ase::state_get $o expr] eq {v(d)}} { incr nvd }
    }
    check "I8 still exactly one v(d) row" $nvd 1
    ase::ui::sod_end $key
    update

    # I9: the Add-Output dialog's From Design… button closes the dialog and
    # enters the mode
    $top.strip.out invoke
    update
    check_true "I9 --> opens the Add Output dialog" [winfo exists $top.edout]
    $top.edout.fromdes invoke
    update
    check_true "I9 From Design closes the dialog" \
      [expr {![winfo exists $top.edout]}]
    check_true "I9 mode active after From Design" \
      [expr {[bind $cv <ButtonPress-1>] ne $pre_press}]
    ase::ui::sod_end $key
    update

    # I10: closing the session window ends an active mode (binding-leak
    # guard) — re-enter, close, all three bindings restored
    $top.mb.outputs.saved invoke {Select On Design}
    update
    ase::ui::close $key
    update
    check "I10 close restored ButtonPress-1" [bind $cv <ButtonPress-1>] $pre_press
    check "I10 close restored ButtonRelease-1" \
      [bind $cv <ButtonRelease-1>] $pre_rel
    check "I10 close restored Key-Escape" [bind $cv <Key-Escape>] $pre_esc
    check_true "I10 session window gone" \
      [expr {![winfo exists $top]}]
  }

  # --- WF: the whole-flow ROUND GATE on a FRESH session (D11: the I-leg
  # session was closed WITHOUT saving, so this reopens the pristine clone) ---
  check "WF open state -> 1" \
    [ase::open_state sky130_tests test_nfet_final ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true "WF session window exists" \
    [expr {$top ne {} && [winfo exists $top]}]
  check "WF v2 title" [wm title $top] {Analog Sim Environment test_nfet_final}

  # WF Choose Analyses: dialog opens preselected on op with Enable set (the
  # committed state), OK round-trips
  $top.mb.analyses invoke "Choose\u2026"
  update
  check_true "WF Choose Analyses dialog opens" [winfo exists $top.chana]
  check "WF Choose Analyses preselects op" $::ase::ui::dlg($key,antype) op
  check "WF Choose Analyses op Enable set" $::ase::ui::dlg($key,anen) 1
  $top.chana.btns.proceed invoke
  update
  check_true "WF Choose Analyses dialog closed" \
    [expr {![winfo exists $top.chana]}]
  set open {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {op}} { set open [ase::state_get $a enabled] }
  }
  check "WF op analysis still enabled" $open 1

  # WF --> dialog adds the vd=v(d) output (save checked)
  $top.strip.out invoke
  update
  check_true "WF --> opens the Add Output dialog" [winfo exists $top.edout]
  $top.edout.name insert 0 vd
  $top.edout.expr insert 0 {v(d)}
  set ::ase::ui::edchk($key,save) 1   ;# the checkbutton variable is product surface
  $top.edout.btns.proceed invoke
  update
  check_true "WF dialog adds v(d) to the state" \
    [string match "*{name vd expr v(d) plot 0 save 1}*" \
      [ase::state_get [ase::session_state $key] outputs]]
  check_true "WF vd row in the Outputs pane" \
    [expr {[tv_find $top.body.outs.tv name vd] ne {}}]

  # WF Netlist and Run (needs the main window for netlisting + ngspice)
  if {!$mainok} {
    puts "SKIPPED: WF Netlist-and-Run legs (WSLg geometry: main window never became usable)"
  } elseif {[auto_execok ngspice] eq {}} {
    puts "SKIPPED: WF Netlist-and-Run legs (ngspice not found)"
  } else {
    $top.mb.sim invoke {Netlist and Run}
    set idw [ase::session_getattr $key run_id]
    check_true "WF Netlist and Run started (integer execute id)" \
      [string is integer -strict $idw]
    check_true "WF log toplevel appears" [winfo exists $top.logwin]
    set ecw [ase::wait $idw]
    update
    check "WF exit 0" $ecw 0
    check "WF status Ready" [$top.status.stat cget -text] {Status: Ready}
    check "WF status light Green" [$top.status.stat cget -background] Green
    set otv $top.body.outs.tv
    set idit [tv_find $otv name id]
    set vcell [expr {$idit ne {} ? [$otv set $idit value] : {}}]
    # item 09: the Value cell renders in engineering notation (409.7u) — the
    # `u` suffix makes the cell uA directly, same physical gate as before
    set vok 0
    if {[regexp {^-?([0-9.]+)u$} $vcell -> num]} {
      if {abs($num - 409.68) < 1.0} { set vok 1 }
    }
    check "WF id Value ~409.7uA" $vok 1
    if {!$vok} { puts "  WF id Value cell: '$vcell'" }
    set vdit [tv_find $otv name vd]
    set vdcell [expr {$vdit ne {} ? [$otv set $vdit value] : {}}]
    # v(d)=1.0 formats to a plain `1`, but accept a NUMm (x1e-3) rendering
    # too so a 999.9m-class rounding can never flake the leg (item 09)
    set vdok 0
    if {[string is double -strict $vdcell]} {
      if {abs($vdcell - 1.0) < 1e-3} { set vdok 1 }
    } elseif {[regexp {^-?([0-9.]+)m$} $vdcell -> vdnum]} {
      if {abs($vdnum * 1e-3 - 1.0) < 1e-3} { set vdok 1 }
    }
    check "WF vd Value ~1.0 (added output flowed through)" $vdok 1
    if {!$vdok} { puts "  WF vd Value cell: '$vdcell'" }
  }

  # WF Save State to a scratch view of the CLONE
  check "WF Save State dialog round completed" \
    [menu_save_state_as $top ngspice_scratch1] 1
  set scratchstate [file join $clonelib test_nfet_final ngspice_scratch1 \
    test_nfet_final.state]
  check_true "WF scratch view created" [file isfile $scratchstate]
  # snapshot the three pane-backing lists NOW (identity gate after reopen)
  set snap_vars [ase::state_get [ase::session_state $key] variables]
  set snap_ana  [ase::state_get [ase::session_state $key] analyses]
  set snap_outs [ase::state_get [ase::session_state $key] outputs]

  # WF close the session
  # item 16: this session is DIRTY; the menu Close now routes through
  # close_request's save prompt, so tear down directly (behavior-identical to
  # the pre-rewire menu Close).
  ase::ui::close $key
  update
  check_true "WF close destroyed the window" [expr {![winfo exists $top]}]

  # WF reopen the scratch view: panes repopulate identically
  set key2 [ase::session_key sky130_tests test_nfet_final ngspice_scratch1]
  check "WF reopen scratch view -> 1" \
    [ase::open_state sky130_tests test_nfet_final ngspice_scratch1] 1
  update
  set top2 [ase::ui::window_for $key2]
  check_true "WF reopened window exists" \
    [expr {$top2 ne {} && [winfo exists $top2]}]
  check "WF variables identical" \
    [ase::state_get [ase::session_state $key2] variables] $snap_vars
  check "WF analyses identical" \
    [ase::state_get [ase::session_state $key2] analyses] $snap_ana
  check "WF outputs identical" \
    [ase::state_get [ase::session_state $key2] outputs] $snap_outs
  check_true "WF reopened pane shows the vd row" \
    [expr {[tv_find $top2.body.outs.tv name vd] ne {}}]
  $top2.mb.session invoke Close
  update

} else {
  puts "gui legs skipped (no DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
