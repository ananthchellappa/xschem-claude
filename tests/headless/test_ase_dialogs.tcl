# ASE-L v2 dialogs (item 07 of doc/claude/ase_l_batch, spec
# doc/claude/specs/ase_l.md "Menu tree v2" / "Choose Analyses dialog" /
# "Dialog style"):
#   H1     ase::open_state trailing ro arg -> session attr `readonly`
#          (every open sets it; a plain reopen clears it)
#   H2     ase::ui::save_as_needs_confirm (D8): readonly+same-target /
#          plain same-target / unwritable-file same-target / different target
#   H3     ase::ui::do_save_state_as creates a MISSING view through
#          library_new_view and writes this session's serialization (D9)
#   H4     ase::ui::do_load_state_from imports content into THIS session,
#          session goes dirty (D10)
#   G1-G11 GUI legs (DISPLAY only, else a partial skip): Choose Analyses via
#          menu / OP,TR strip / analyses double-click preselect; dc
#          quick-field round trip + D6 rejection; Setup Design (View list
#          filtered to schematic views) round trip; Model Files list dialog
#          add/delete; Save All -> save_all_i + Save Options column + deck
#          line + disabled Levels; Simulation Options add/delete; Save-As
#          prefill / new-view create / same-target clean save; read-only
#          same-target confirm gate; Load State browser (opens defaulted to
#          the session's own Library/Cell with the View column filled and no
#          View preselected -- G9a; a Library change clears the stale status
#          -- G9b; an unknown cell degrades one column only -- G9c; a bare OK
#          names the missing View -- G9d; state-view filter, import + dirty,
#          dirty-prompt-first); --> strip = Add Output;
#          no todo_stub left on any rewired item-07 entry.
#   GE1-16 item-10 esc-dismiss legs: EVERY ASE-L dialog dismisses on a real
#          generated <Key-Escape> through its CANCEL path — dialog destroyed,
#          per-window records (edrow/edchk/dlg) cleaned, ZERO state mutation
#          (serialize snapshot unchanged); ESC from inside an entry bubbles
#          to the dialog toplevel (GE2); the .chana.x subdialog dismisses
#          without killing its parent and cleans dlg(anextra) (GE5); the
#          confirm's ESC never runs oncmd (GE13); the ASE main window (GE14,
#          witness-proven delivery) and the log window (GE15) stay
#          ESC-unbound; the item-08 Select-On-Design canvas ESC still ends
#          the mode with the seized binding restored verbatim (GE16).
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl
# (env -u DISPLAY for the headless-only run; add DISPLAY for the GUI legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- helpers copied verbatim from tests/headless/test_ase_window.tcl ---------
# (each test is its own process — helpers are copied, not shared-sourced)

# the treeview item whose $col cell equals $val, or {}
proc tv_find {tv col val} {
  foreach it [$tv children {}] {
    if {[$tv set $it $col] eq $val} { return $it }
  }
  return {}
}

# bbox of $item (optionally a cell) with a retry loop — WSLg can be slow to
# map the toplevel, and bbox is empty until the row is displayed
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

# real double-click replay at the center of $item's row: Tk REFUSES `event
# generate <Double-1>`, so replay two press/release pairs — Tk's click-count
# machinery turns the second press into the <Double-1> match (the
# test_ase_view G1 idiom)
proc tv_dblclick {tv item} {
  set bb [tv_bbox $tv $item]
  if {[llength $bb] != 4} { return 0 }
  lassign $bb x y wdt hgt
  set cx [expr {$x + $wdt/2}]; set cy [expr {$y + $hgt/2}]
  foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
    event generate $tv $ev -x $cx -y $cy
  }
  update
  return 1
}

# real single click at the center of $item's $col cell (checkbox cells).
# `dx` shifts the click point horizontally: two consecutive generated clicks
# at the SAME spot classify as <Double-1> (generated events share the display
# timestamp, so Tk's 500ms window never expires — only a >5px offset breaks
# the multi-click chain).
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

# deliver a REAL generated key event $ev to $w, WSLg-robustly. The W6c
# diagnosis, extended to EVERY generated-key site (item-06 fixer round 2,
# generalized from <Return>-only to any key for the item-10 ESC legs): Tk
# redirects GENERATED KeyPress events to the display's focus window, and
# under WSLg the X focus round-trip is asynchronous — an ungated
# `focus -force; update; event generate ...` intermittently lands the key on
# the previously-focused widget, so the product binding under test silently
# never fires (run 4: the W3 editor's Return was lost, cascading into 5
# FAILs; a lost W3t restore-to-27 left .temp 33 in the W6 deck). Gate every
# generate on Tk actually REPORTING $w as the focus owner, and retry the
# whole sequence until $done — an expr string evaluated in the CALLER's scope
# that proves the product binding really ran (dialog destroyed / state key
# changed / entry restored) — turns true. Returns 1 on proven delivery, 0 on
# timeout (~10s); the caller's own checks then report the real failure.
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

# the original 2-arg helper the pre-item-10 legs call (same contract)
proc send_return {w done} {
  return [uplevel 1 [list send_key $w <Return> $done]]
}

# --- local helper (extends the copied pair) ----------------------------------
# double-click aimed at a specific CELL: the analyses rows carry an Enable
# checkbox cell whose single-click handler toggles the flag, so a row-center
# double click could land there — aim at the harmless $col cell instead.
proc tv_dblclick_cell {tv item col} {
  set bb [tv_bbox $tv $item $col]
  if {[llength $bb] != 4} { return 0 }
  lassign $bb x y wdt hgt
  set cx [expr {$x + $wdt/2}]; set cy [expr {$y + $hgt/2}]
  foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
    event generate $tv $ev -x $cx -y $cy
  }
  update
  return 1
}

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
set models  [file join $repo sky130A models libs.tech combined sky130.lib.spice]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_dialogs]

# --- scratch lib/cell/view fixture + registry --------------------------------
# clean nfet schematic (the test_ase_core fixture: nfet_test_claude minus its
# corner + simulator_commands_shown instances)
set sch_text {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/vsource} 250 -300 0 0 {name=V2 value=1.8}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
}
file mkdir [file join $scratch aselib nfet_clean schematic]
set f [open [file join $scratch aselib nfet_clean schematic nfet_clean.sch] w]
puts -nonewline $f $sch_text
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]

if {[catch {

# seed the state view through the REAL creation backend, then shape the nfet
# fixture state (models/variables/outputs/options, rundir -> scratch) through
# the session procs + session_save — itself code under test
library_new_view aselib nfet_clean ngspice_state1 ngspice_state1
set spath [xschem cellview_path aselib/nfet_clean ngspice_state1]
if {$spath eq {}} { error "fixture: state view did not resolve" }
set spath [file normalize $spath]
set key [ase::session_key aselib nfet_clean ngspice_state1]

ase::session_open $key $spath
set st [ase::session_state $key]
dict set st rundir $rundir
dict set st models [list [list file $models section tt]]
dict set st variables {{name Vgs value 1.8} {name Vds value 1.0}}
dict set st outputs {{name id expr -i(v1) save 1 plot 0}}
dict set st options {{name savecurrents value 1}}
ase::session_update $key $st
ase::session_save $key
ase::session_close $key

# a second, DIFFERING state view (Vgs 0.9) seeded through the real creation
# backend — the H4/G9 import fixture. Deliberately NOT created through the
# Save-As worker: the S2 sabotage class (worker view-creation broken) must
# fail exactly its H3/G7 targets, never cascade into the import legs.
library_new_view aselib nfet_clean ngspice_stateB ngspice_state1
set bpath [file normalize [xschem cellview_path aselib/nfet_clean ngspice_stateB]]
set stB [ase::state_load $spath]
dict set stB variables {{name Vgs value 0.9} {name Vds value 1.0}}
ase::state_save $bpath $stB

# --- H1: the trailing ro arg threads the session readonly attr (D7) ----------
check "H1 ro-open returns 1" [ase::open_state aselib nfet_clean ngspice_state1 1] 1
check "H1 ro-open sets the session readonly attr" \
  [ase::session_getattr $key readonly] 1
check "H1 plain reopen returns 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
check "H1 plain reopen clears it" [ase::session_getattr $key readonly] 0

# --- H2: save_as_needs_confirm predicate (D8/D13) ----------------------------
ase::session_setattr $key readonly 1
check "H2 needs_confirm: readonly + same target" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state1] 1
ase::session_setattr $key readonly 0
check "H2 plain same target" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state1] 0
file attributes $spath -permissions 0444
check "H2 unwritable file same target" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state1] 1
file attributes $spath -permissions 0644
ase::session_setattr $key readonly 1
check "H2 different target needs no confirm even readonly" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state9] 0
ase::session_setattr $key readonly 0

# --- H3: do_save_state_as creates a missing view (D9) ------------------------
set r3 [ase::ui::do_save_state_as $key aselib nfet_clean ngspice_state2]
set p2 [xschem cellview_path aselib/nfet_clean ngspice_state2]
check_true "H3 do_save_state_as creates a new view dir" \
  [expr {$r3 == 1 && $p2 ne {}}]
check_true "H3 cell_views lists the created view" \
  [expr {[lsearch -exact [xschem cell_views aselib nfet_clean] ngspice_state2] >= 0}]
set c2 {}
catch {set f [::open $p2 r]; set c2 [read $f]; close $f}
check "H3 created file carries this session's serialization" \
  $c2 "[ase::state_serialize [ase::session_state $key]]\n"

# --- H4: do_load_state_from imports content + dirty (D10) --------------------
# import the differing stateB content (seeded in the fixture)
check "H4 session clean before the import" [ase::session_dirty $key] 0
set r4 [ase::ui::do_load_state_from $key $bpath]
check "H4 worker returns success" $r4 1
check "H4 do_load_state_from imports content" \
  [ase::state_get [ase::session_state $key] variables] \
  {{name Vgs value 0.9} {name Vds value 1.0}}
check "H4 session dirty after the import" [ase::session_dirty $key] 1
ase::session_revert $key
check "H4 revert leaves the session clean" [ase::session_dirty $key] 0

# drop the H session so the GUI legs exercise a fresh window build
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  ase::ui::close $key; update
} else {
  ase::session_close $key
}

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  check "G1 open_state -> 1" [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true "G1 session window up" [expr {$top ne {} && [winfo exists $top]}]

  # G1: Choose Analyses opens from the menu (default preselect op), from the
  # OP,TR strip button, and from an analyses-row double-click (that row's
  # type preselected)
  $top.mb.analyses invoke "Choose\u2026"
  update
  check_true "G1 menu Choose Analyses opens the dialog" [winfo exists $top.chana]
  check "G1 menu open preselects op" $::ase::ui::dlg($key,antype) op
  $top.chana.btns.cancel invoke
  update
  $top.strip.ana invoke
  update
  check_true "G1 OP,TR strip opens Choose Analyses" [winfo exists $top.chana]
  $top.chana.btns.cancel invoke
  update
  set atv $top.body.ana.tv
  set dcit [tv_find $atv type dc]
  check_true "G1 analyses pane has the dc row" [expr {$dcit ne {}}]
  tv_dblclick_cell $atv $dcit type
  check_true "G1 dbl-click opens Choose Analyses" [winfo exists $top.chana]
  check "G1 dbl-click dc row preselects dc" $::ase::ui::dlg($key,antype) dc

  # G2: dc quick fields round trip through the dialog OK (dialog is still up
  # and preselected dc from G1)
  foreach {fld val} {source V2 start 0 stop 1.8 step 0.01} {
    $top.chana.$fld delete 0 end
    $top.chana.$fld insert 0 $val
  }
  set ::ase::ui::dlg($key,anen) 1
  send_return $top.chana.step {![winfo exists $top.chana]}
  check_true "G2 dialog closed on Return" [expr {![winfo exists $top.chana]}]
  set dcrow {}
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq {dc}} { set dcrow $a; break }
  }
  check "G2 Choose Analyses round-trips dc quick fields" \
    [list [ase::state_get $dcrow enabled] [ase::state_get $dcrow source] \
          [ase::state_get $dcrow start] [ase::state_get $dcrow stop] \
          [ase::state_get $dcrow step]] \
    {1 V2 0 1.8 0.01}
  set dcit [tv_find $atv type dc]
  check "G2 Arguments summary shows the fields" \
    [expr {$dcit ne {} ? [$atv set $dcit args] : {}}] \
    {source=V2 start=0 stop=1.8 step=0.01}

  # G2b: D6 rejection — an ENABLED tran with a blank step is refused, the
  # dialog survives, the state is untouched. Driven through the OK BUTTON:
  # a rejection has no observable delivery witness, so a WSLg-dropped
  # <Return> would make this leg hollow-green (Return delivery is proven by
  # G2 above).
  $top.strip.ana invoke
  update
  $top.chana.types.tran invoke
  update
  set ::ase::ui::dlg($key,anen) 1
  $top.chana.stop delete 0 end
  $top.chana.stop insert 0 10u
  $top.chana.step delete 0 end
  set ana_before [ase::state_get [ase::session_state $key] analyses]
  $top.chana.btns.proceed invoke
  update
  check_true "G2b enabled tran with blank step rejected (dialog survives)" \
    [winfo exists $top.chana]
  check "G2b state unchanged on rejection" \
    [ase::state_get [ase::session_state $key] analyses] $ana_before
  $top.chana.btns.cancel invoke
  update

  # G3: Setup > Design — View list filtered to SCHEMATIC views (nfet_clean
  # also has ngspice_state* views: the filter proof), round trip via OK
  $top.mb.setup invoke "Design\u2026"
  update
  check_true "G3 Setup Design opens" [winfo exists $top.design]
  check "G3 prefilled Library" [$top.design.lib get] aselib
  check "G3 prefilled Cell" [$top.design.cell get] nfet_clean
  check "G3 view list filtered to schematic views" \
    [$top.design.view cget -values] schematic
  $top.design.btns.proceed invoke
  update
  check_true "G3 Setup Design closed on OK" [expr {![winfo exists $top.design]}]
  set d3 [ase::state_get [ase::session_state $key] design]
  check "G3 design round-trips" \
    [list [dict get $d3 lib] [dict get $d3 cell] [dict get $d3 view]] \
    {aselib nfet_clean schematic}
  check_true "G3 title still shows the design cell" \
    [string match {Analog Sim Environment nfet_clean*} [wm title $top]]

  # G4: Setup > Model Files — list dialog rows from the state, row-editor
  # add, dialog-local ctx delete (D1)
  $top.mb.setup invoke "Model Files\u2026"
  update
  check_true "G4 Model Files dialog opens" [winfo exists $top.models]
  set mtv $top.models.tv
  check "G4 Model Files lists the state models" \
    [list [llength [$mtv children {}]] [$mtv set 0 file] [$mtv set 0 section]] \
    [list 1 $models tt]
  $top.models.ctx invoke "Add\u2026"
  update
  check_true "G4 Add opens the row editor" [winfo exists $top.modrow]
  $top.modrow.file insert 0 /tmp/extra.lib.spice
  $top.modrow.section insert 0 tt2
  send_return $top.modrow.section {![winfo exists $top.modrow]}
  check_true "G4 add round-trips" [string match \
    {*file /tmp/extra.lib.spice section tt2*} \
    [ase::state_get [ase::session_state $key] models]]
  check "G4 dialog list grew" [llength [$mtv children {}]] 2
  $mtv selection set 1
  update
  $top.models.ctx invoke Delete
  update
  check "G4 delete removes the row" \
    [llength [ase::state_get [ase::session_state $key] models]] 1
  $top.models.btns.close invoke
  update

  # G5: Outputs > Save All — alli toggle writes save_all_i, the outputs
  # pane's Save Options column reacts, the deck gains the blanket line, the
  # Levels field is the inert disabled v1 placeholder (D11)
  $top.mb.outputs invoke "Save All\u2026"
  update
  check_true "G5 Save All dialog opens" [winfo exists $top.saveall]
  check "G5 levels entry disabled" [$top.saveall.levels cget -state] disabled
  $top.saveall.alli invoke
  $top.saveall.btns.proceed invoke
  update
  check "G5 Save All writes save_all_i" \
    [ase::state_get [ase::session_state $key] save_all_i] 1
  set otv $top.body.outs.tv
  set idit [tv_find $otv name id]
  check "G5 Save Options column reacts" \
    [expr {$idit ne {} ? [$otv set $idit saveopts] : {}}] alli
  set render [ase::backend_hook ngspice render_deck]
  set st5 [ase::session_state $key]
  dict set st5 options {}   ;# drop the explicit row — the blanket alone
  set deck5 [$render $st5 "* stub circuit\n.end\n"]
  check_true "G5 deck gains .options savecurrents" \
    [regexp -line {^\.options savecurrents$} $deck5]

  # G6: Simulation > Options — name/value row add + delete (immediate
  # commit, D15)
  $top.mb.sim invoke "Options\u2026"
  update
  check_true "G6 Simulation Options dialog opens" [winfo exists $top.simopt]
  $top.simopt.ctx invoke "Add\u2026"
  update
  check_true "G6 Add opens the option row editor" [winfo exists $top.optrow]
  $top.optrow.name insert 0 reltol
  $top.optrow.value insert 0 1e-4
  send_return $top.optrow.value {![winfo exists $top.optrow]}
  check_true "G6 Sim Options round-trips a name/value row" [string match \
    {*name reltol value 1e-4*} \
    [ase::state_get [ase::session_state $key] options]]
  set optv $top.simopt.tv
  set ridx [expr {[llength [ase::state_get [ase::session_state $key] options]] - 1}]
  $optv selection set $ridx
  update
  $top.simopt.ctx invoke Delete
  update
  check_true "G6 delete removes the option row" \
    [expr {![string match {*reltol*} \
      [ase::state_get [ase::session_state $key] options]]}]
  $top.simopt.btns.close invoke
  update

  # G7: Session > Save State — always Save-As, prefilled with the session's
  # own L/C/V; same-target OK is the plain save (clears dirty); an edited
  # View creates the new view (item-02 creation path)
  $top.mb.session invoke {Save State}
  update
  check_true "G7 Save-As dialog opens" [winfo exists $top.saveas]
  check "G7 Save-As dialog prefilled with current lcv" \
    [list [$top.saveas.lib get] [$top.saveas.cell get] [$top.saveas.view get]] \
    {aselib nfet_clean ngspice_state1}
  check "G7 session dirty before the save" [ase::session_dirty $key] 1
  $top.saveas.btns.proceed invoke
  update
  check_true "G7 Save-As closed after the save" \
    [expr {![winfo exists $top.saveas]}]
  check "G7 same-target OK saves clean" [ase::session_dirty $key] 0
  $top.mb.session invoke {Save State}
  update
  $top.saveas.view delete 0 end
  $top.saveas.view insert 0 ngspice_state3
  $top.saveas.btns.proceed invoke
  update
  set p3 [xschem cellview_path aselib/nfet_clean ngspice_state3]
  check_true "G7 Save-As creates a new view dir" [expr {$p3 ne {}}]
  check_true "G7 new view listed in cell_views" \
    [expr {[lsearch -exact [xschem cell_views aselib nfet_clean] ngspice_state3] >= 0}]

  # G8: read-only same-target -> the confirm gate (D7/D8): proceed on the
  # Save-As first raises $top.confirm WITHOUT writing; the confirm's OK
  # writes + cleans
  set st8 [ase::session_state $key]
  dict set st8 variables {{name Vgs value 1.44} {name Vds value 1.0}}
  ase::session_update $key $st8
  check "G8 session dirty before the confirm path" [ase::session_dirty $key] 1
  ase::session_setattr $key readonly 1
  $top.mb.session invoke {Save State}
  update
  $top.saveas.btns.proceed invoke
  update
  check_true "G8 read-only same-target raises the confirm" \
    [winfo exists $top.confirm]
  set f [::open $spath r]; set sdata [read $f]; close $f
  check_true "G8 file not yet written while the confirm is up" \
    [expr {![string match {*Vgs value 1.44*} $sdata]}]
  $top.confirm.btns.proceed invoke
  update
  set f [::open $spath r]; set sdata [read $f]; close $f
  check_true "G8 confirm proceed writes the file" \
    [string match {*Vgs value 1.44*} $sdata]
  check "G8 session clean after the confirmed save" [ase::session_dirty $key] 0
  ase::session_setattr $key readonly 0

  # G9: Session > Load State — browser filtered to simulation-state views,
  # import + dirty, and the dirty-prompt-first gate
  $top.mb.session invoke {Load State}
  update
  check_true "G9 Load State browser opens" [winfo exists $top.loadst]
  # G9a: the browser opens ALREADY on this session's own cell, so the only
  # pick left is the state View. Library + Cell selected, View column filled
  # and filtered, View deliberately UNselected (a default pick would be one
  # OK press from discarding the session for a state nobody chose).
  check "G9a defaults to the session Library" \
    [ase::ui::lb_sel $top.loadst.pw.lib.lb] aselib
  check "G9a defaults to the session Cell" \
    [ase::ui::lb_sel $top.loadst.pw.cell.lb] nfet_clean
  check_true "G9a View column already filled and filtered" [expr {
    [lsearch -exact [$top.loadst.pw.view.lb get 0 end] ngspice_state1] >= 0 &&
    [lsearch -exact [$top.loadst.pw.view.lb get 0 end] schematic] < 0}]
  check "G9a no View preselected" [ase::ui::lb_sel $top.loadst.pw.view.lb] {}
  check "G9a status names the defaulted cell" [$top.loadst.status cget -text] \
    {aselib/nfet_clean — choose a state View}
  # a library the browser does not list must fall back rather than
  # half-select or error, and it must not disturb what is already chosen
  check "G9a unknown library falls back" \
    [ase::ui::lb_select_value $top.loadst.pw.lib.lb no_such_lib] 0
  check "G9a a missed library leaves the selection alone" \
    [ase::ui::lb_sel $top.loadst.pw.lib.lb] aselib
  # G9b: picking a different Library must clear the status that described the
  # OLD cell -- only reachable on the first click now the browser opens
  # defaulted, so the defaulting is what makes this stale text visible
  $top.loadst.pw.lib.lb selection clear 0 end
  ase::ui::loadst_on_lib $key
  check "G9b library change resets the stale status" \
    [$top.loadst.status cget -text] \
    {pick a Library / Cell / simulation-state View}
  check "G9b library change empties the Cell column" \
    [$top.loadst.pw.cell.lb size] 0
  # G9c: an unknown CELL degrades one column only -- library stays chosen and
  # its Cell list stays filled (more useful than clearing it)
  ase::ui::lb_select_value $top.loadst.pw.lib.lb aselib
  ase::ui::loadst_on_lib $key
  check "G9c unknown cell falls back" \
    [ase::ui::lb_select_value $top.loadst.pw.cell.lb no_such_cell] 0
  check "G9c library stays chosen after a cell miss" \
    [ase::ui::lb_sel $top.loadst.pw.lib.lb] aselib
  check_true "G9c cell column stays filled after a cell miss" \
    [expr {[$top.loadst.pw.cell.lb size] > 0}]
  # G9d: bare OK with Library+Cell chosen and no View must name the MISSING
  # View, not tell the user to pick a Library they already picked
  ase::ui::lb_select_value $top.loadst.pw.cell.lb nfet_clean
  ase::ui::loadst_on_cell $key
  $top.loadst.b.ok invoke
  update
  check_true "G9d bare OK keeps the browser open" [winfo exists $top.loadst]
  check "G9d bare OK names the missing View" \
    [$top.loadst.status cget -text] {aselib/nfet_clean — choose a state View}
  set llb $top.loadst.pw.lib.lb
  set i9 [lsearch -exact [$llb get 0 end] aselib]
  $llb selection clear 0 end; $llb selection set $i9
  event generate $llb <<ListboxSelect>>
  update
  set clb $top.loadst.pw.cell.lb
  set i9 [lsearch -exact [$clb get 0 end] nfet_clean]
  $clb selection clear 0 end; $clb selection set $i9
  event generate $clb <<ListboxSelect>>
  update
  set vlb $top.loadst.pw.view.lb
  set views9 [$vlb get 0 end]
  check_true "G9 Load State browser filtered to state views" [expr {
    [lsearch -exact $views9 ngspice_state1] >= 0 &&
    [lsearch -exact $views9 ngspice_stateB] >= 0 &&
    [lsearch -exact $views9 schematic] < 0}]
  set i9 [lsearch -exact $views9 ngspice_stateB]
  $vlb selection clear 0 end; $vlb selection set $i9
  update
  $top.loadst.b.ok invoke
  update
  check "G9 load imports the picked state" \
    [ase::state_get [ase::session_state $key] variables] \
    {{name Vgs value 0.9} {name Vds value 1.0}}
  check "G9 session dirty after the import" [ase::session_dirty $key] 1
  set vt $top.body.vars.tv
  set vgsit [tv_find $vt name Vgs]
  # item 09: the pane renders the imported 0.9 in engineering notation
  # (900m); the raw-state import check above keeps asserting 0.9
  check "G9 panes repopulated with the imported value" \
    [expr {$vgsit ne {} ? [$vt set $vgsit value] : {}}] 900m
  # dirty session -> the discard prompt comes FIRST
  $top.mb.session invoke {Load State}
  update
  set llb $top.loadst.pw.lib.lb
  set i9 [lsearch -exact [$llb get 0 end] aselib]
  $llb selection clear 0 end; $llb selection set $i9
  event generate $llb <<ListboxSelect>>
  update
  set clb $top.loadst.pw.cell.lb
  set i9 [lsearch -exact [$clb get 0 end] nfet_clean]
  $clb selection clear 0 end; $clb selection set $i9
  event generate $clb <<ListboxSelect>>
  update
  set vlb $top.loadst.pw.view.lb
  set i9 [lsearch -exact [$vlb get 0 end] ngspice_stateB]
  $vlb selection clear 0 end; $vlb selection set $i9
  update
  $top.loadst.b.ok invoke
  update
  check_true "G9 dirty prompt appears first" [winfo exists $top.confirm]
  $top.confirm.btns.proceed invoke
  update
  check "G9 confirmed load leaves the imported content" \
    [ase::state_get [ase::session_state $key] variables] \
    {{name Vgs value 0.9} {name Vds value 1.0}}

  # G10: the --> strip button = the Add Output dialog (D3)
  $top.strip.out invoke
  update
  check_true "G10 --> strip opens the Add Output dialog" [expr {
    [winfo exists $top.edout] && [wm title $top.edout] eq {Add Output}}]
  $top.edout.btns.cancel invoke
  update

  # G11: no item-07 todo stubs remain on any rewired entry (the item-08
  # Outputs Select-On-Design entries are excluded by construction)
  set stub_hits {}
  foreach {m e} [list $top.mb.session {Load State} \
                      $top.mb.session {Save State} \
                      $top.mb.setup "Design\u2026" \
                      $top.mb.setup "Model Files\u2026" \
                      $top.mb.analyses "Choose\u2026" \
                      $top.mb.outputs "Save All\u2026" \
                      $top.mb.sim "Options\u2026"] {
    if {[string match *todo_stub* [$m entrycget $e -command]]} {
      lappend stub_hits [list $m $e]
    }
  }
  foreach b [list $top.strip.ana $top.strip.out] {
    if {[string match *todo_stub* [$b cget -command]]} { lappend stub_hits $b }
  }
  foreach e [list "Add\u2026" "Edit\u2026"] {
    if {[string match *todo_stub* [$top.body.ana.ctx entrycget $e -command]]} {
      lappend stub_hits [list ana.ctx $e]
    }
  }
  check "G11 no item-07 todo stubs remain" $stub_hits {}

  # ===========================================================================
  # GE: item 10 esc-dismiss — every dialog dismisses on ESC through its
  # CANCEL path. Per leg: serialize-snapshot the session state, open the
  # dialog through a REAL entry point, optionally perturb a field, deliver a
  # focus-gated <Key-Escape> (send_key), then assert: dialog destroyed,
  # per-window records cleaned (info exists = 0), state byte-identical to the
  # snapshot. Each leg keeps its snapshot local so the legs stay
  # mutation-free by construction.
  # ===========================================================================

  # GE1: Add Variable (= strip button; no per-window records)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.var invoke
  update
  check_true "GE1 Add Variable dialog up" [winfo exists $top.addvar]
  $top.addvar.name insert 0 geVar
  send_key $top.addvar <Key-Escape> {![winfo exists $top.addvar]}
  check_true "GE1 ESC dismisses Add Variable" \
    [expr {![winfo exists $top.addvar]}]
  check "GE1 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE2: Edit Variable — ESC is sent TO THE ENTRY (the bubbling proof: the
  # entry's bindtags include the dialog toplevel, whose ESC binding fires)
  set snap [ase::state_serialize [ase::session_state $key]]
  ase::ui::variable_editor $key 0
  update
  check_true "GE2 Edit Variable dialog up" [winfo exists $top.edvar]
  $top.edvar.value delete 0 end
  $top.edvar.value insert 0 9.99
  send_key $top.edvar.value <Key-Escape> {![winfo exists $top.edvar]}
  check_true "GE2 ESC from inside an entry dismisses the editor" \
    [expr {![winfo exists $top.edvar]}]
  check "GE2 edrow record cleaned" [info exists ::ase::ui::edrow($key,var)] 0
  check "GE2 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE3: Add Output (--> strip button)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.out invoke
  update
  check_true "GE3 Add Output dialog up" [winfo exists $top.edout]
  $top.edout.expr insert 0 v(d)
  send_key $top.edout <Key-Escape> {![winfo exists $top.edout]}
  check_true "GE3 ESC dismisses Add Output" \
    [expr {![winfo exists $top.edout]}]
  check "GE3 edrow/edchk records cleaned" \
    [list [info exists ::ase::ui::edrow($key,out)] \
          [info exists ::ase::ui::edchk($key,plot)] \
          [info exists ::ase::ui::edchk($key,save)]] {0 0 0}
  check "GE3 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE4: Choose Analyses (OP,TR strip; perturb by picking the tran radio)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.ana invoke
  update
  check_true "GE4 Choose Analyses dialog up" [winfo exists $top.chana]
  $top.chana.types.tran invoke
  update
  send_key $top.chana <Key-Escape> {![winfo exists $top.chana]}
  check_true "GE4 ESC dismisses Choose Analyses" \
    [expr {![winfo exists $top.chana]}]
  check "GE4 antype/anen records cleaned" \
    [list [info exists ::ase::ui::dlg($key,antype)] \
          [info exists ::ase::ui::dlg($key,anen)]] {0 0}
  check "GE4 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE5: the Analysis Options SUBDIALOG (.chana.x, a nested toplevel):
  # ESC the subdialog FIRST (it dies with its Tk parent), the parent
  # survives (nested-toplevel binding isolation), dlg(anextra) is cleaned
  # (the chana_x_cancel fix — the old bare-destroy Cancel leaked it); then
  # ESC dismisses the parent too.
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.strip.ana invoke
  update
  $top.chana.opts invoke
  update
  check_true "GE5 Analysis Options subdialog up" [winfo exists $top.chana.x]
  send_key $top.chana.x <Key-Escape> {![winfo exists $top.chana.x]}
  check_true "GE5 ESC dismisses Analysis Options" \
    [expr {![winfo exists $top.chana.x]}]
  check_true "GE5 parent Choose Analyses survives" [winfo exists $top.chana]
  check "GE5 anextra record cleaned" \
    [info exists ::ase::ui::dlg($key,anextra)] 0
  send_key $top.chana <Key-Escape> {![winfo exists $top.chana]}
  check_true "GE5 ESC then dismisses Choose Analyses" \
    [expr {![winfo exists $top.chana]}]
  check "GE5 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE6: Setup > Design
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.setup invoke "Design\u2026"
  update
  check_true "GE6 Setup Design dialog up" [winfo exists $top.design]
  send_key $top.design <Key-Escape> {![winfo exists $top.design]}
  check_true "GE6 ESC dismisses Setup Design" \
    [expr {![winfo exists $top.design]}]
  check "GE6 dlib/dcell/dview records cleaned" \
    [list [info exists ::ase::ui::dlg($key,dlib)] \
          [info exists ::ase::ui::dlg($key,dcell)] \
          [info exists ::ase::ui::dlg($key,dview)]] {0 0 0}
  check "GE6 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE7: Model Files list dialog (no records — immediate-commit engine)
  $top.mb.setup invoke "Model Files\u2026"
  update
  check_true "GE7 Model Files dialog up" [winfo exists $top.models]
  send_key $top.models <Key-Escape> {![winfo exists $top.models]}
  check_true "GE7 ESC dismisses Model Files" \
    [expr {![winfo exists $top.models]}]

  # GE8: Model File row editor over a reopened list dialog — ESC the row
  # editor first (list dialog survives, dlg(models) cleaned), then ESC the
  # list dialog
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.setup invoke "Model Files\u2026"
  update
  $top.models.ctx invoke "Add\u2026"
  update
  check_true "GE8 model row editor up" [winfo exists $top.modrow]
  send_key $top.modrow <Key-Escape> {![winfo exists $top.modrow]}
  check_true "GE8 ESC dismisses the row editor" \
    [expr {![winfo exists $top.modrow]}]
  check_true "GE8 models list dialog survives" [winfo exists $top.models]
  check "GE8 dlg(models) record cleaned" \
    [info exists ::ase::ui::dlg($key,models)] 0
  send_key $top.models <Key-Escape> {![winfo exists $top.models]}
  check_true "GE8 ESC then closes Model Files" \
    [expr {![winfo exists $top.models]}]
  check "GE8 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE9: Simulation Options — same engine, terser (dismiss + record checks)
  $top.mb.sim invoke "Options\u2026"
  update
  $top.simopt.ctx invoke "Add\u2026"
  update
  check_true "GE9 option row editor up" [winfo exists $top.optrow]
  send_key $top.optrow <Key-Escape> {![winfo exists $top.optrow]}
  check_true "GE9 ESC dismisses the option row editor" \
    [expr {![winfo exists $top.optrow]}]
  check "GE9 dlg(simopt) record cleaned" \
    [info exists ::ase::ui::dlg($key,simopt)] 0
  send_key $top.simopt <Key-Escape> {![winfo exists $top.simopt]}
  check_true "GE9 ESC dismisses Simulation Options" \
    [expr {![winfo exists $top.simopt]}]

  # GE10: Save All — toggle a checkbox first: the toggle must NOT reach the
  # state through ESC (save_all_i stays as G5 wrote it)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.outputs invoke "Save All\u2026"
  update
  check_true "GE10 Save All dialog up" [winfo exists $top.saveall]
  $top.saveall.alli invoke
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  check_true "GE10 ESC dismisses Save All" \
    [expr {![winfo exists $top.saveall]}]
  check "GE10 allv/alli records cleaned" \
    [list [info exists ::ase::ui::dlg($key,allv)] \
          [info exists ::ase::ui::dlg($key,alli)]] {0 0}
  check "GE10 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE11: Load State browser (no records)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.session invoke {Load State}
  update
  check_true "GE11 Load State browser up" [winfo exists $top.loadst]
  send_key $top.loadst <Key-Escape> {![winfo exists $top.loadst]}
  check_true "GE11 ESC dismisses Load State" \
    [expr {![winfo exists $top.loadst]}]
  check "GE11 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE12: Save State (Save-As)
  set snap [ase::state_serialize [ase::session_state $key]]
  $top.mb.session invoke {Save State}
  update
  check_true "GE12 Save-As dialog up" [winfo exists $top.saveas]
  send_key $top.saveas <Key-Escape> {![winfo exists $top.saveas]}
  check_true "GE12 ESC dismisses Save-As" \
    [expr {![winfo exists $top.saveas]}]
  check "GE12 salib record cleaned" \
    [info exists ::ase::ui::dlg($key,salib)] 0
  check "GE12 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE13: the shared confirm — ESC = Cancel, oncmd must NOT run
  unset -nocomplain ::ge13
  ase::ui::confirm $key {Confirm Test} {ESC must cancel, not proceed} \
    {set ::ge13 1}
  update
  check_true "GE13 confirm popup up" [winfo exists $top.confirm]
  send_key $top.confirm <Key-Escape> {![winfo exists $top.confirm]}
  check_true "GE13 ESC dismisses the confirm" \
    [expr {![winfo exists $top.confirm]}]
  check "GE13 oncmd did not run" [info exists ::ge13] 0

  # GE14: the ASE MAIN window stays ESC-unbound (structural), and a
  # temporary test-side witness binding proves ESC DELIVERY to the toplevel
  # (receipts/06: a no-op leg without a delivery witness is hollow-green);
  # the witness is restored to the empty binding afterwards
  check "GE14 session toplevel has no Escape binding" \
    [bind $top <Key-Escape>] {}
  set snap [ase::state_serialize [ase::session_state $key]]
  unset -nocomplain ::ge14
  bind $top <Key-Escape> {set ::ge14 1}
  send_key $top <Key-Escape> {[info exists ::ge14]}
  check "GE14 ESC delivery witnessed" [info exists ::ge14] 1
  bind $top <Key-Escape> {}
  check "GE14 witness removed (binding empty again)" \
    [bind $top <Key-Escape>] {}
  check_true "GE14 window survives" [winfo exists $top]
  check "GE14 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE15: the log window stays ESC-exempt (structural — its documented
  # close is Ctrl-W, covered by test_ase_window W6c)
  set lw [ase::ui::log_open $key]
  update
  check_true "GE15 log window up" \
    [expr {$lw ne {} && [winfo exists $lw]}]
  check "GE15 log window has no Escape binding" [bind $lw <Key-Escape>] {}
  destroy $lw
  update

  # GE16: item-08 Select-On-Design ESC regression (D8) — the canvas-side
  # ESC seize/restore is untouched by the dialog wiring. Self-SKIP ONLY
  # when the mode never arms (design window unopenable — the WSLg W4-class
  # raise stall); once armed the assertions MUST run.
  set armed [ase::ui::select_on_design $key {save 1 plot 0}]
  if {$armed != 1} {
    puts "SKIPPED: GE16 sod ESC regression (select_on_design returned\
 $armed — design window unopenable, WSLg stall)"
  } else {
    set cv   $::ase::ui::sod($key,canvas)
    set prev $::ase::ui::sod($key,prevesc)
    # the test_ase_interact I7 pattern via send_key: done = the seized
    # Key-Escape binding reverted (restored by the product's sod_end)
    send_key $cv <Key-Escape> {[bind $cv <Key-Escape>] eq $prev}
    check "GE16 SOD ESC still ends the mode" \
      [expr {[bind $cv <Key-Escape>] eq $prev ? 1 : 0}] 1
    check "GE16 canvas Escape binding restored verbatim" \
      [bind $cv <Key-Escape>] $prev
  }

  # done: close the session window (unsaved edits are discarded by contract).
  # item 16: this session is DIRTY; the menu Close now routes through
  # close_request's save prompt, so tear down directly (behavior-identical to
  # the pre-rewire menu Close).
  ase::ui::close $key
  update
  check_true "G12 session window closed" [expr {![winfo exists $top]}]

} else {
  puts "gui legs skipped (no DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
catch {file attributes $spath -permissions 0644}
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
