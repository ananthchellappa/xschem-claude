# ASE-L v2 dialogs (item 07 of doc/claude/ase_l_batch, spec
# doc/claude/specs/ase_l.md "Menu tree v2" / "Choose Analyses dialog" /
# "Dialog style"):
#   H1     ase::open_state trailing ro arg -> session attr `readonly`
#          (every open sets it; a plain reopen clears it)
#   H2     ase::ui::save_as_needs_confirm (D8, UNCHANGED by the D13 overrule):
#          readonly+same-target / plain same-target / unwritable-file
#          same-target / a target this session does not own -- both the
#          unresolvable one and an EXISTING sibling, which is the row the old
#          fourth-row name only pretended to be
#   H2b    ase::ui::save_as_overwrites_other (S-2..S-6), the SECOND door the
#          user's 2026-09-09 overrule of D13 added: a DIFFERENT EXISTING state
#          -> 1, this session's own -> 0, a missing target -> 0, an UNTITLED
#          session against an existing target -> 1 (S-3); the two predicates
#          are mutually exclusive on every target; and the predicate is PURE --
#          it creates nothing and writes nothing
#   H2c/d  the two overwrite SENTENCES, both minted in the lbl_* family (S-7):
#          the new one interpolates the l/c/v it was given, the read-only one
#          is the shipped string byte for byte, embedded newline included
#   H3     ase::ui::do_save_state_as creates a MISSING view through
#          library_new_view and writes this session's serialization (D9)
#   H4     ase::ui::do_load_state_from imports content into THIS session,
#          session goes dirty (D10)
#   G1-G11 GUI legs (DISPLAY only, else a partial skip): Choose Analyses via
#          menu / OP,TR strip / analyses double-click preselect; dc
#          quick-field round trip + D6 rejection; Setup Design (View list
#          filtered to schematic views) round trip; Model Files list dialog
#          add/delete; Save All -> save_all_i + Save Options column + deck
#          line + disabled Levels; the S4 `save_op_params` third blanket
#          (G5b widget paths + grid rows survive the shift, G5c commits `0` for
#          the explicit OFF and writes `{}` -- the ON default -- back on, issue
#          0927); Simulation Options add/delete; Save-As
#          prefill / new-view create / same-target clean save; read-only
#          same-target confirm gate; G8b the DIFFERENT-EXISTING-state confirm
#          gate driven through the real menu -- the row the silent-clobber
#          defect would have failed; Load State browser (opens defaulted to
#          the session's own Library/Cell with the View column filled and no
#          View preselected -- G9a; a Library change clears the stale status
#          -- G9b; an unknown cell degrades one column only -- G9c; a bare OK
#          names the missing View -- G9d; state-view filter, import + dirty,
#          dirty-prompt-first); --> strip = Add Output;
#          no todo_stub left on any rewired item-07 entry.
#   GE1-16 item-10 esc-dismiss legs: EVERY ASE-L dialog OF THE ITEM-10 SET
#          dismisses on a real generated <Key-Escape> through its CANCEL path
#          (the results-batch item-7 `Results > Select…` dialog is newer and
#          carries its own ESC leg, tests/headless/test_results_dialog.tcl
#          SEL407 -- destroyed AND its per-window dlg records cleaned, which is
#          what tells the close path apart from a bare destroy) — dialog destroyed,
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
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP -- AND IT IS TWO NUMBERS
# ============================================================================
# ⚠ THIS FILE HAD NO FLOOR PARAGRAPH UNTIL ISSUE 1408. Two things make that
# worse here than in most suites:
#
#   * THE TWO ARMS MEASURE DIFFERENT THINGS, NOT THE SAME THING TO DIFFERENT
#     PRECISION. Most of this file is inside `if {[info exists ::has_x] ...}`,
#     so HEADLESS runs 37 checks and the DISPLAY arm runs 224. Reporting one
#     number reads as a floor that fell by 187. ALWAYS REPORT PER ARM.
#   * `run_regression.tcl` RUNS THIS FILE ON **NEITHER** ARM -- measured, it is
#     in neither `cases` nor `dcases`. So T1 at zero says NOTHING about any row
#     here, and a receipt that quotes a T1 zero has not exercised one of them.
#     The suite runs under full_audit.sh's display arm and under run_suites.sh.
#
# THE HISTORY:
#   37 / 215   as this paragraph was written (2026-09-11, HEAD 8bfbbd6f)
#   37 / 236   section GG, issue 1411: the wrapping type grid. Headless is
#              unmoved because every GG row is a widget row.
#   37 / 224   section G14, issue 1408: the dialog describes THIS session's
#              simulator. Headless is UNMOVED because every G14 row is a widget
#              row and sits inside the display guard, by design -- the schema
#              half of the same change is test_ase_core.tcl section AD.
#
# ⚠ RAISED, NEVER LOWERED. If a number falls, say which rows went and why, per
# row; do not edit the number downward to make the file agree with itself.

proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- helpers copied verbatim from tests/headless/test_ase_window.tcl ---------
# (each test is its own process — helpers are copied, not shared-sourced)

# the grid row a widget sits in, or -1 when it is not gridded at all (S4's
# Save All row shift: the third checkbox pushes Levels and the button bar down
# by one, and the existing rows drive those two by PATH)
proc ase_grid_row {w} {
  if {![winfo exists $w]} { return -1 }
  set gi [grid info $w]
  if {[dict exists $gi -row]} { return [dict get $gi -row] }
  return -1
}

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

# --- issue 0648 helpers ------------------------------------------------------
# Every new-API call is catch-wrapped, so on a tree where the seam does not
# exist yet each row goes red on its own with `ERR: invalid command name ...`
# instead of aborting the whole GUI leg at the first missing proc.
# (Copied verbatim from tests/headless/test_ase_core.tcl, house style: each
# test is its own process, so helpers are copied and not shared-sourced.)
proc cx {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR: $r" }
  return $r
}
# the ase::echo pane sink, parked and collected (test_ase_core's c_echo_arm).
# ase::echo (ase.tcl:134) calls ::ciw_echo unconditionally when it exists, so
# renaming it is how every ASE suite captures a notice.
proc d_echo_arm {} {
  set ::d_echo {}
  if {[info commands ::d_saved_ciw_echo] eq {}} {
    if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::d_saved_ciw_echo }
    proc ::ciw_echo {msg {tag {}}} { lappend ::d_echo [list $tag $msg] }
  }
}
proc d_echo_disarm {} {
  if {[info commands ::d_saved_ciw_echo] ne {}} {
    catch {rename ::ciw_echo {}}
    rename ::d_saved_ciw_echo ::ciw_echo
  }
}
# how many collected messages match $pat -- a COUNT, not a boolean: "the
# discard is stated" and "the discard is stated ONCE" are different claims and
# a duplicated sentence is its own defect (issue 0635's subject).
proc d_echoed_n {pat} {
  set n 0
  foreach e $::d_echo { if {[string match -nocase $pat [lindex $e 1]]} { incr n } }
  return $n
}

# The same spy one channel further in, on `ase::echo` itself. `d_echo_arm`
# above parks ::ciw_echo; the 0691 failure lines are emitted by ase::echo
# (ase.tcl:180) -- do_load_state_from's own unloadable-FILE arm already calls
# it directly -- so they are read HERE. Copied verbatim in shape from
# tests/headless/test_ase_window.tcl's w_aecho_spy (each test is its own
# process: helpers are copied, not shared-sourced).
proc d_aecho_spy {script} {
  set ::d_aecho {}
  if {[info commands ::d_saved_ase_echo] eq {}} {
    if {[info commands ::ase::echo] ne {}} { rename ::ase::echo ::d_saved_ase_echo }
    proc ::ase::echo {msg {tag {}}} { lappend ::d_aecho [list $tag $msg] ; return 1 }
  }
  catch {uplevel 1 $script}
  if {[info commands ::d_saved_ase_echo] ne {}} {
    catch {rename ::ase::echo {}}
    rename ::d_saved_ase_echo ::ase::echo
  }
  return $::d_aecho
}
# just the `error`-tagged pairs of a d_aecho_spy result -- "it said something"
# and "it said ONE error-tagged sentence" are different claims (issue 0635)
proc d_aecho_errors {echoes} {
  set out {}
  foreach e $echoes { if {[lindex $e 0] eq {error}} { lappend out $e } }
  return $out
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

# --- H2: save_as_needs_confirm predicate (D8) --------------------------------
# ⚠ D13 IS RETIRED, AND THE USER RETIRED IT (2026-09-09). D13 read "overwriting
# a DIFFERENT existing view needs NO confirm in v1 -- the spec's only confirm
# trigger is read-only + same-target", and it described the shipped window
# accurately: measured that day on the live binary with session `ngspice_state1`
# open and its sibling view `debug_st1` present and writable,
# `save_as_needs_confirm` answered **0** for `debug_st1` -- so typing an
# existing sibling view into the Save-As form destroyed it with no warning at
# all. The user's ruling, verbatim: "Just confirm if overwriting an existing
# state." Undo was explicitly NOT asked for; a confirm was.
#
# THIS PREDICATE IS UNCHANGED BY THAT (batch decision S-1,
# doc/claude/ase_l_ux_batch/DECISIONS.md). It still answers exactly "the target
# IS my own file AND that file is effectively read-only", and the four rows
# below still pin it, byte for byte. The NEW door is
# `ase::ui::save_as_overwrites_other` -- section H2b.
#
# What the overrule DID change here is a NAME (S-9). The fourth row used to be
# called "H2 different target needs no confirm even readonly" -- a promise about
# the WINDOW, and the window no longer makes it. Renamed to name the PREDICATE
# and its value. Its assertion is untouched.
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
check "H2 needs_confirm: 0 for an unresolvable target, readonly or not" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_state9] 0
# ...and S-1's REAL pin, which the row above only looked like. `ngspice_state9`
# does not exist, so that call returns at the unresolvable guard and never
# reaches the own-vs-other comparison at all. `ngspice_stateB` DOES exist, is
# NOT this session's file, and the session is read-only-flagged besides: still
# 0. Widening save_as_needs_confirm to swallow the new case -- the thing S-1
# forbids -- turns THIS row red and no other.
check "H2 needs_confirm: 0 for an EXISTING target this session does not own, readonly or not" \
  [ase::ui::save_as_needs_confirm $key aselib nfet_clean ngspice_stateB] 0
ase::session_setattr $key readonly 0

# --- H2b: save_as_overwrites_other predicate (S-2 .. S-6) --------------------
# The second door, added 2026-09-09 when the user overruled D13: 1 iff the
# resolved target EXISTS and is NOT this session's own state file, else 0.
# `ngspice_stateB` is the fixture's second, DIFFERING state view (seeded above
# through library_new_view for the H4/G9 import legs) -- an existing file this
# session does not own, which is precisely the case that used to be destroyed
# in silence. `ngspice_state9` is never created by this fixture.
set fh [::open $bpath r]; set h2b_before [read $fh]; close $fh
check "H2b overwrites_other: a DIFFERENT, EXISTING state -> 1 (S-2)" \
  [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_stateB] 1
check "H2b overwrites_other: this session's OWN state -> 0 (S-4, that is what Save means)" \
  [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state1] 0
check "H2b overwrites_other: a target that does not exist -> 0 (S-5, creating is not overwriting)" \
  [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state9] 0
# read-only is the OTHER door's business and must not leak into this one
ase::session_setattr $key readonly 1
check "H2b overwrites_other: read-only does not change any of the three answers" \
  [list [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_stateB] \
        [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state1] \
        [ase::ui::save_as_overwrites_other $key aselib nfet_clean ngspice_state9]] \
  {1 0 0}
# S-2's load-bearing claim: the two doors are mutually exclusive BY
# CONSTRUCTION (one arm needs target == own, the other target != own), so
# save_state_ok can chain them and never has to compose a sentence out of two
# reasons. Measured as a pair per target, in the ONE session state where both
# could plausibly fire -- read-only:
#   own -> {1 0}   different+existing -> {0 1}   missing -> {0 0}   never {1 1}
set h2b_pairs {}
foreach h2b_v {ngspice_state1 ngspice_stateB ngspice_state9} {
  lappend h2b_pairs [list \
    [ase::ui::save_as_needs_confirm    $key aselib nfet_clean $h2b_v] \
    [ase::ui::save_as_overwrites_other $key aselib nfet_clean $h2b_v]]
}
check "H2b the two doors are mutually exclusive on every target (never both 1)" \
  $h2b_pairs {{1 0} {0 1} {0 0}}
ase::session_setattr $key readonly 0

# S-3: an UNTITLED session owns NO file -- `ase::session_path` returns {}, issue
# 0141's marker -- so EVERY existing target is somebody else's, including the
# one this fixture's titled session is sitting on. That is the case where a
# clobber is most likely and least expected, so it is the case that must ask.
# The suite had no untitled session, so make one the way Tools > Launch ASE-L
# does: ase::new_session (src/ase.tcl:9840) registers under the untitled
# metaview, a key of its own, and is closed again below so no later leg inherits
# a second session on this design.
set uk [ase::new_session aselib nfet_clean schematic]
# ...and flagged read-only, deliberately: without the flag the last row of this
# group could not go red at all. `save_as_needs_confirm` only ever returns 1 on
# a readonly attr or an unwritable file, so an unflagged untitled session would
# answer 0 whether or not the proc still bails on `own eq {}` -- a green row
# measuring nothing. Flagged, dropping that bail turns it red and nothing else.
ase::session_setattr $uk readonly 1
check "H2b the untitled session really has no own file" [ase::session_path $uk] {}
check "H2b overwrites_other: UNTITLED + an EXISTING target -> 1 (S-3)" \
  [ase::ui::save_as_overwrites_other $uk aselib nfet_clean ngspice_state1] 1
check "H2b overwrites_other: UNTITLED + a target that does not exist -> 0 (S-5 holds untitled too)" \
  [ase::ui::save_as_overwrites_other $uk aselib nfet_clean ngspice_state9] 0
check "H2b needs_confirm stays 0 for a read-only-flagged UNTITLED session (no own file to be read-only)" \
  [ase::ui::save_as_needs_confirm $uk aselib nfet_clean ngspice_state1] 0
ase::session_close $uk

# PURITY, asserted rather than assumed: save_as_overwrites_other is called from
# an OK handler that has NOT yet decided to do anything. Probing a view that
# does not exist must not create it (contrast ase::rundir, which mkdirs and
# moves a process-global), and the sibling it just answered about must be
# byte-identical afterwards.
set fh [::open $bpath r]; set h2b_after [read $fh]; close $fh
check_true "H2b the predicate created nothing and wrote nothing" [expr {
  [xschem cellview_path aselib/nfet_clean ngspice_state9] eq {} &&
  [lsearch -exact [xschem cell_views aselib nfet_clean] ngspice_state9] < 0 &&
  $h2b_after eq $h2b_before}]

# --- H2c/H2d: the two overwrite sentences (S-7) ------------------------------
# Both live in the lbl_* family (src/ase_window.tcl:5578) so that neither is a
# magic string inside save_state_ok -- the save_all_report_discard drift of
# issue 0661 is what that family exists to prevent. Asserted THROUGH the procs;
# every other row in this suite that needs one of these sentences reads it from
# the proc too, so the literal is typed in exactly one place: here.
check "H2c lbl_overwrite_state is the ratified sentence" \
  [ase::ui::lbl_overwrite_state aselib nfet_clean ngspice_stateB] \
  {State aselib/nfet_clean/ngspice_stateB exists. Overwrite?}
# ...and it really INTERPOLATES all three arguments rather than naming a fixed
# target: substituting the fixture's l/c/v out of one rendering must reproduce
# the rendering taken with placeholder arguments. A proc that dropped, swapped
# or hardcoded any of the three fails here; a proc that interpolated nothing at
# all fails the row above.
check "H2c lbl_overwrite_state interpolates the lib/cell/view it was given" \
  [ase::ui::lbl_overwrite_state L C V] \
  [string map {aselib L nfet_clean C ngspice_stateB V} \
     [ase::ui::lbl_overwrite_state aselib nfet_clean ngspice_stateB]]
# The read-only sentence was MOVED into the family, not rewritten: it is the
# string that shipped, byte for byte, embedded newline included. The mint was
# meant to change zero pixels on the arm it did not come to change, and this
# row is what says so.
check "H2d lbl_overwrite_readonly is the SHIPPED read-only sentence, unchanged" \
  [ase::ui::lbl_overwrite_readonly aselib nfet_clean ngspice_state1] \
  "The state aselib/nfet_clean/ngspice_state1 was opened read-only.\nOverwrite it?"
check "H2d ...and its embedded newline survived the move (two lines, not one)" \
  [llength [split [ase::ui::lbl_overwrite_readonly aselib nfet_clean ngspice_state1] \n]] 2
# same structural interpolation test as H2c, for the same reason: a sentence
# that hardcoded one of its three components would render IDENTICALLY under the
# row above (which feeds it the very values it hardcoded) and only shows up when
# the arguments change.
check "H2d ...and it interpolates its lib/cell/view too" \
  [ase::ui::lbl_overwrite_readonly L C V] \
  [string map {aselib L nfet_clean C ngspice_state1 V} \
     [ase::ui::lbl_overwrite_readonly aselib nfet_clean ngspice_state1]]

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

# --- H3b (0691 SWEEP): do_save_state_as REFUSES a key nobody is under --------
# 0691's "weaker second arm". Measured at HEAD, headless: an unknown key makes
# `ase::session_path` return {} -- the SAME value that marks an untitled session
# -- so control reaches the `own eq {}` adopt arm at ase_window.tcl:3800-3805.
# library_new_view CREATES the view, a defaults-state file is written into it,
# `ase::session_adopt` returns 0 into a discarded value (:3804) and the proc
# ends in its hardcoded `return 1` (:3815):
#   H3B catch=0 res=1
#   H3B viewpath = .../aselib/nfet_clean/ngspice_stateH3B/nfet_clean.state
#   H3B echoes   = {{} {ase: state saved to aselib/nfet_clean/ngspice_stateH3B}}
# The lie and the bogus view arrive together, so the row pins both: refusing
# BEFORE any write removes the manufactured 1 and the litter in one guard.
set h3b_key {H3B-NO-SESSION}
set h3b_e [d_aecho_spy \
  {set ::h3b_rc [ase::ui::do_save_state_as $h3b_key aselib nfet_clean ngspice_stateH3B]}]
set h3b_err [d_aecho_errors $h3b_e]
check "H3b 0691 do_save_state_as REFUSES a key no session is under: returns 0,\
 creates NO view (and therefore no state file), and says so exactly once tagged\
 error" \
  [list [expr {[info exists ::h3b_rc] ? $::h3b_rc : {NO-RETURN}}] \
        [expr {[xschem cellview_path aselib/nfet_clean ngspice_stateH3B] ne {} ? 1 : 0}] \
        [llength $h3b_err] \
        [expr {[llength $h3b_err] == 1 ? [lindex $h3b_err 0 0] : {NO-ONE-LINE}}]] \
  {0 0 1 error}

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

# --- H4b/H4c/H4d (0691): the witness, the sentence, and the ONE sentence -----
# `ase::ui::do_load_state_from` (ase_window.tcl:3575-3587) is honest about the
# FILE (:3576-3579) and never about the KEY: `ase::session_update`'s answer is
# discarded at :3580 and the proc ends in a hardcoded `return 1` at :3586 --
# the identical shape 0679 just fixed one proc over in `save_all_apply`.
# Measured at HEAD, headless, at the same commit as the repaired twin:
#   session_update(BOGUS)      = 0    <- honest
#   do_load_state_from(BOGUS)  = 1    <- fabricated
#   save_all_apply(BOGUS)      = 0    <- 0679's repair holding
# So "Load State into a session that is gone" reports success, changes nothing
# and says nothing.
set h4_key {H4B-NO-SESSION}
set h4b_bad  [d_aecho_spy {set ::h4b_badrc  [ase::ui::do_load_state_from $h4_key $bpath]}]
set h4b_good [d_aecho_spy {set ::h4b_goodrc [ase::ui::do_load_state_from $key $bpath]}]
check "H4b 0691 do_load_state_from reports FAILURE for a key no session is under\
 and SUCCESS for the registered one -- both arms from the SAME loadable file in\
 one tuple, so a proc hardwired to either value fails one half" \
  [list [expr {[info exists ::h4b_badrc] ? $::h4b_badrc : {NO-RETURN}}] \
        [expr {[info exists ::h4b_goodrc] ? $::h4b_goodrc : {NO-RETURN}}]] \
  {0 1}

set h4c_err [d_aecho_errors $h4b_bad]
check "H4c 0691 the refused import is NOT SILENT: exactly one ase::echo, tagged\
 error, naming the key it could not find -- and the successful import says\
 nothing at all" \
  [list [llength $h4c_err] \
        [expr {[llength $h4c_err] == 1 ? [lindex $h4c_err 0 0] : {NO-ONE-LINE}}] \
        [expr {[llength $h4c_err] == 1 &&
               [string first $h4_key [lindex $h4c_err 0 1]] >= 0 ? 1 : 0}] \
        [llength $h4b_good]] \
  {1 error 1 0}

# H4d: GREEN AT HEAD, and the row that stops the fix growing a SECOND sentence.
# The unloadable-FILE arm already emits one error-tagged line; the new
# unknown-KEY arm must be mutually exclusive with it, not additive.
set h4d [d_aecho_spy \
  {set ::h4d_rc [ase::ui::do_load_state_from $key [file join $scratch h4d-no-such.state]]}]
set h4d_err [d_aecho_errors $h4d]
check "H4d 0691 THE ECHO DOES NOT DOUBLE-FIRE: an unloadable FILE into a\
 REGISTERED key still returns 0 with exactly one error-tagged line" \
  [list [expr {[info exists ::h4d_rc] ? $::h4d_rc : {NO-RETURN}}] \
        [llength $h4d_err] \
        [expr {[llength $h4d_err] == 1 ? [lindex $h4d_err 0 0] : {NO-ONE-LINE}}]] \
  {0 1 error}

# H4b's registered arm re-imported stateB: leave the session exactly as the H4
# block left it, so the GUI legs below open on a clean session.
ase::session_revert $key
check "H4d the H block leaves the session clean again" [ase::session_dirty $key] 0

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
    $top.chana.form.$fld delete 0 end
    $top.chana.form.$fld insert 0 $val
  }
  set ::ase::ui::dlg($key,anen) 1
  send_return $top.chana.form.step {![winfo exists $top.chana]}
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
  ## ⚠ STAGE 1 MOVED THIS STRING, DELIBERATELY, AND IT IS THE ONE VISIBLE
  ## CHANGE OF THE WHOLE STAGE. The Arguments column stops being a key dump and
  ## becomes THE LINE THE DECK WILL CARRY -- ase::ui::arg_summary now calls
  ## ase::analysis_line, the same proc render_deck emits, so the pane cannot
  ## show a setting the deck does not have. It is a DISPLAY string, not deck
  ## output: deck golden D1 and the 17-case render corpus are byte-identical.
  check "G2 Arguments summary is the line the deck will carry" \
    [expr {$dcit ne {} ? [$atv set $dcit args] : {}}] \
    {dc V2 0 1.8 0.01}

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
  $top.chana.form.stop delete 0 end
  $top.chana.form.stop insert 0 10u
  $top.chana.form.step delete 0 end
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

  # G5b/G5c: Outputs > Save All gains the THIRD blanket — `save_op_params`,
  # the gate that lets ase::netlist capture op_annot::save_cards and
  # render_deck carry it into the deck (plan step S4 / issue 0617).
  # ⚠ THE ROW NUMBERS IN save_all_dialog ARE HARDCODED: opparams takes grid row
  # 2, so `dialog_row $w 2 Levels: levels` must move to 3 and
  # `dialog_buttons $w 3` to 4. The widget PATHS `.allv` `.alli` `.levels`
  # `.btns.proceed` are what G5 and GE10 drive, so they must survive verbatim.
  $top.mb.outputs invoke "Save All\u2026"
  update
  check_true "G5b Save All dialog reopens" [winfo exists $top.saveall]
  check "G5b the opparams checkbutton exists" \
    [winfo exists $top.saveall.opparams] 1
  check "G5b allv/alli/levels/proceed paths survive the row shift" \
    [list [winfo exists $top.saveall.allv] [winfo exists $top.saveall.alli] \
          [winfo exists $top.saveall.levels] \
          [winfo exists $top.saveall.btns.proceed]] {1 1 1 1}
  check "G5b Levels is still the inert disabled v1 field" \
    [$top.saveall.levels cget -state] disabled
  check "G5b opparams sits between alli and Levels in the grid" \
    [list [ase_grid_row $top.saveall.alli] [ase_grid_row $top.saveall.opparams] \
          [ase_grid_row $top.saveall.levels] [ase_grid_row $top.saveall.btns]] \
    {1 2 3 4}

  # G5c: the checkbox actually reaches the state, both ways round.
  # ⚠ 0927 FLIPPED THE POLARITY (2026-08-29, the user's call). The box now
  # starts TICKED on a state that never mentions the key -- which is every
  # existing test bench -- and the empty value is what keeps the key out of
  # ase::state_serialize and the 104 committed .state files byte-identical
  # (F3/G3/R4/V4/R2). So: ON writes `{}` and VANISHES from the file, OFF writes
  # a literal `0` and is the only thing a state file ever says about this key.
  # The sequence below is untick -> OK -> reopen -> retick -> OK, i.e. the
  # mirror image of what this row used to drive.
  check "G5c 0927 opparams starts TICKED (the gate defaults ON)" \
    [expr {[info exists ::ase::ui::dlg($key,opparams)]
             ? $::ase::ui::dlg($key,opparams) : {<no record>}}] 1
  catch {$top.saveall.opparams invoke}
  $top.saveall.btns.proceed invoke
  update
  check "G5c 0927 UN-ticking opparams writes save_op_params 0" \
    [ase::state_get [ase::session_state $key] save_op_params] 0
  check_true "G5c 0927 an off gate IS serialized (off is what costs a key)" \
    [expr {[string first "save_op_params 0" \
       [ase::state_serialize [ase::session_state $key]]] >= 0}]
  $top.mb.outputs invoke "Save All\u2026"
  update
  check "G5c reopening preloads the UN-ticked state" \
    [expr {[info exists ::ase::ui::dlg($key,opparams)]
             ? $::ase::ui::dlg($key,opparams) : {<no record>}}] 0
  catch {$top.saveall.opparams invoke}
  $top.saveall.btns.proceed invoke
  update
  check "G5c 0927 re-ticking writes {} back, never 1" \
    [ase::state_get [ase::session_state $key] save_op_params <absent>] {}
  check "G5c 0927 an ON gate is OMITTED from the serialized state again" \
    [expr {[string first "save_op_params" \
       [ase::state_serialize [ase::session_state $key]]] >= 0}] 0

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

  # G8b: THE ROW THE SILENT-CLOBBER DEFECT WOULD HAVE FAILED (S-2).
  # Save State is always a Save-As, so OK can land on a file that is already
  # somebody's state. Until 2026-09-09 it just wrote: measured on the live
  # binary, `save_as_needs_confirm` answered 0 for an existing sibling view and
  # there was no second door, so an existing state was destroyed with no
  # warning. Now `save_as_overwrites_other` answers 1 and OK raises the confirm
  # FIRST. Driven through the REAL menu entry and the REAL form, not the worker:
  # the defect lived in the OK handler, and a worker-level row would have been
  # green through all of it.
  #
  # A DEDICATED victim view, seeded here rather than reusing `ngspice_stateB`:
  # stateB is the G9 import fixture and this row's entire subject is a file that
  # must NOT change, so a regression here must not also redden G9 for a reason
  # that is not G9's. `library_new_view` is the same real creation backend the
  # fixture uses; its content is then made distinct from this session's, so a
  # write of ANY kind moves the bytes.
  library_new_view aselib nfet_clean ngspice_stateV ngspice_state1
  set vpath [file normalize [xschem cellview_path aselib/nfet_clean ngspice_stateV]]
  # THE ANTI-VACUITY GUARD, and it is not decoration. The H2 row renamed above
  # spent months called "a different target needs no confirm" while pointing at
  # `ngspice_state9`, a view this fixture never creates -- so it was measuring
  # the unresolvable-target guard, and it would have stayed green through the
  # entire defect. A row about overwriting an existing state is worth nothing
  # unless the state exists, is not this session's own, and holds something this
  # session would not write.
  check_true "G8b the victim state exists and is not this session's own file" [expr {
    $vpath ne {} && [file exists $vpath] &&
    $vpath ne [file normalize [ase::session_path $key]]}]
  if {[file exists $vpath]} {
    set stV [ase::state_load $vpath]
    dict set stV variables {{name Vgs value 0.11} {name Vds value 0.22}}
    ase::state_save $vpath $stV
  }
  # every read of the victim goes through this, so a red row above degrades the
  # rows below to reds of their own instead of aborting the GUI block
  proc g8b_read {} {
    global vpath
    set c {}
    catch {set fh [::open $vpath r]; set c [read $fh]; close $fh}
    return $c
  }
  set vbefore [g8b_read]
  check_true "G8b ...and it holds something this session would NOT write" [expr {
    $vbefore ne {} && ![string match {*Vgs value 1.44*} $vbefore]}]
  $top.mb.session invoke {Save State}
  update
  # the form re-opens on the SESSION's own identity, never on whatever was
  # typed into it last -- so the overwrite below is a thing the user has to type
  # on purpose, and this row is what says the retype is real rather than a
  # leftover
  check "G8b the re-opened Save-As is prefilled with the session's own l/c/v" \
    [list [$top.saveas.lib get] [$top.saveas.cell get] [$top.saveas.view get]] \
    {aselib nfet_clean ngspice_state1}
  $top.saveas.view delete 0 end
  $top.saveas.view insert 0 ngspice_stateV
  $top.saveas.btns.proceed invoke
  update
  check_true "G8b OK onto a DIFFERENT EXISTING state raises the confirm" \
    [winfo exists $top.confirm]
  # One title for both arms, and the sentence READ FROM THE MINT rather than
  # retyped here -- a drift between the two would be issue 0661 all over again.
  # Both reads are caught into {}: when the confirm is missing (which is exactly
  # what the pre-2026-09-09 window did) these rows must go red one by one, not
  # abort the whole GUI block into a single UNEXPECTED ERROR that says nothing
  # about which promise broke.
  set g8b_title {}; catch {set g8b_title [wm title $top.confirm]}
  set g8b_msg   {}; catch {set g8b_msg [$top.confirm.msg cget -text]}
  check "G8b the confirm is titled Overwrite State" $g8b_title {Overwrite State}
  check "G8b the confirm names the state it is about to destroy" $g8b_msg \
    [ase::ui::lbl_overwrite_state aselib nfet_clean ngspice_stateV]
  check "G8b the target is byte-identical while the confirm is up" [g8b_read] $vbefore
  # Cancel: nothing written, and the Save-As form STAYS UP so the user can
  # retype the view they meant (that is also what keeps save_state_modal's
  # tkwait from returning a false completion on the quit path)
  catch {$top.confirm.btns.cancel invoke}
  update
  check_true "G8b Cancel dismisses the confirm" \
    [expr {![winfo exists $top.confirm]}]
  check "G8b Cancel wrote NOTHING: the target is still byte-identical" [g8b_read] $vbefore
  check_true "G8b Cancel leaves the Save-As form up to retype in" \
    [winfo exists $top.saveas]
  # CLEANUP, caught: a red row above can leave the form already gone, and an
  # error on the teardown would abort the whole GUI block into one UNEXPECTED
  # ERROR -- which is how a precise red turns into an unreadable run.
  catch {$top.saveas.btns.cancel invoke}
  update
  check_true "G8b the abandoned Save-As is gone and the session is untouched" [expr {
    ![winfo exists $top.saveas] && [ase::session_dirty $key] == 0}]

  # --- G8c: THE GATE MUST BE REAL FOR THE KEYBOARD TOO -----------------------
  # Both rows below are regressions found by this item's own adversary AFTER
  # the confirm shipped, i.e. the gate existed and was still bypassable.
  #
  # G8c-1 <Return>. `save_state_dialog` binds <Return> on all three fields, so
  # "type the view name, press Return" is the sanctioned submit; `ase::ui::confirm`
  # then focuses OK and binds <Return> to confirm_ok. Composed, the SAME key
  # raises the popup and fires it. `ase::ui::confirm_safe_default` puts focus on
  # Cancel and points <Return> at the dismissal instead. Escape already did.
  proc g8c_raise {} {
    uplevel 1 {
      catch {destroy $top.confirm}
      $top.mb.session invoke {Save State}
      for {set i 0} {$i < 100} {incr i} {
        update ; if {[winfo exists $top.saveas]} break ; settle 20 }
      $top.saveas.view delete 0 end
      $top.saveas.view insert 0 ngspice_stateV
      $top.saveas.btns.proceed invoke
      for {set i 0} {$i < 100} {incr i} {
        update ; if {[winfo exists $top.confirm]} break ; settle 20 }
    }
  }
  g8c_raise
  check_true "G8c the confirm is up again" [winfo exists $top.confirm]
  check "G8c focus rests on Cancel, not on the destructive button"     [focus -displayof $top.confirm] $top.confirm.btns.cancel
  check "G8c <Return> on the confirm is the DISMISSAL, not the write"     [bind $top.confirm <Return>] [list destroy $top.confirm]
  event generate $top.confirm <Return>
  update
  check_true "G8c ...and pressing it dismissed rather than wrote"     [expr {![winfo exists $top.confirm]}]
  check "G8c Return wrote NOTHING: the target is still byte-identical" [g8b_read] $vbefore

  # G8c-2 the ORPHAN. Escape on the Save-As form is the documented item-10
  # dismissal. It used to destroy the form and leave the confirm alive, so a
  # user who backed out of the dialog was left with a live destructive button
  # aimed at their file. `ase::ui::confirm_owned_by` binds the form's <Destroy>.
  g8c_raise
  check_true "G8c the confirm is up for the orphan check" [winfo exists $top.confirm]
  # focus -force first: the confirm holds the keyboard, and a generated Key
  # event is routed by focus. Without it the ESC lands nowhere and the row
  # would pass for the wrong reason (no orphan because no dismissal).
  focus -force $top.saveas
  update
  event generate $top.saveas <Key-Escape>
  update
  check_true "G8c ESC dismissed the form" [expr {![winfo exists $top.saveas]}]
  check_true "G8c ESC on the FORM takes the confirm with it (no orphan)" \
    [expr {![winfo exists $top.confirm]}]
  check "G8c the orphan path wrote NOTHING either" [g8b_read] $vbefore

  # G8c-3 re-opening the form must not leave a confirm naming the OLD target.
  # `dialog_frame` destroys the previous form, which fires the same <Destroy>.
  g8c_raise
  check_true "G8c the confirm is up for the re-open check" [winfo exists $top.confirm]
  $top.mb.session invoke {Save State}
  for {set i 0} {$i < 100} {incr i} {
    update ; if {[winfo exists $top.saveas]} break ; settle 20 }
  check_true "G8c re-opening the form drops the stale confirm"     [expr {![winfo exists $top.confirm]}]
  catch {$top.saveas.btns.cancel invoke}
  update
  check "G8c the whole G8c block wrote NOTHING to the victim" [g8b_read] $vbefore

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
  catch {$top.saveall.opparams invoke}   ;# S4's third blanket, same contract
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  check_true "GE10 ESC dismisses Save All" \
    [expr {![winfo exists $top.saveall]}]
  check "GE10 allv/alli/opparams records cleaned" \
    [list [info exists ::ase::ui::dlg($key,allv)] \
          [info exists ::ase::ui::dlg($key,alli)] \
          [info exists ::ase::ui::dlg($key,opparams)]] {0 0 0}
  check "GE10 state unchanged" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # =========================================================================
  # GE10b-GE10h -- ISSUE 0648: THE TICK THAT VANISHES WITHOUT A WORD
  # =========================================================================
  # The user, verbatim, 2026-08-23: "I went to Outputs > Save and checked the
  # 'Save device OP parameters'. I re-ran the sim and still don't get OP info."
  # Measured at HEAD under a real WM on :99: ticking the box sets
  # dlg($key,opparams)=1 and the checkbutton is visibly ON, while
  # `save_op_params` stays `{}`; ESC destroys the dialog and says NOTHING; and
  # `wm protocol $top.saveall WM_DELETE_WINDOW` is EMPTY -- ase::ui::dialog_frame
  # (:1350) registers no handler, the only WM_DELETE_WINDOW in ase_window.tcl
  # is :277 for the session toplevel -- so a window-manager close destroys the
  # toplevel WITHOUT running save_all_cancel at all (proof: after the close the
  # dlg record still EXISTS, which save_all_cancel would have unset). Issue
  # 0648's sentence "Cancel, ESC via bind_dialog_esc, and the window-manager
  # close all reach save_all_cancel" is WRONG on its third clause, and a
  # "changes were discarded" notice placed only in save_all_cancel would be
  # silent on exactly the path the user's window manager offers.
  #
  # The dialog's whole content is three checkboxes, so a user who ticks one has
  # expressed the entire intent and a visibly-toggled checkbutton reads as
  # applied. These rows pin the answer chosen in decision D1: KEEP OK-commit
  # (GE10h -- the GE1-GE16 zero-state-mutation contract survives) and STATE the
  # discard, name the dropped box, and RE-ARM the OP-card nudge so the user's
  # next run is not silent too (GE10f, the GUI half of the acceptance row).
  #
  # GREEN BEFORE THE CHANGE, and deliberately so (controls, not evidence):
  # GE10e (nothing is ever said today, so "says nothing" is trivially true) and
  # both GE10h rows (nothing commits today either -- they exist to stay green,
  # and they are what a live-commit design would have reddened).
  set snap [ase::state_serialize [ase::session_state $key]]

  # GE10b: the WM close is wired AT ALL, and to the cancel path -- reads '' at
  # HEAD.  GE10e rides its teardown: an untouched dialog must stay silent.
  d_echo_arm
  $top.mb.outputs invoke "Save All\u2026"
  update
  check "GE10b 0648 Save All registers a WM_DELETE_WINDOW handler on its cancel\
 path" \
    [cx {wm protocol $top.saveall WM_DELETE_WINDOW}] \
    [list ase::ui::save_all_cancel $key]
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  d_echo_disarm
  check "GE10e 0648 NON-VACUITY CONTROL: dismissing an UNTOUCHED Save All says\
 nothing" [d_echoed_n {*NOT applied*}] 0

  # GE10c/GE10d: a DISCARDED tick is stated, once, and names the dropped box.
  d_echo_arm
  $top.mb.outputs invoke "Save All\u2026"
  update
  catch {$top.saveall.opparams invoke}
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  d_echo_disarm
  check "GE10c 0648 a ticked box dropped by ESC is REPORTED, exactly once" \
    [d_echoed_n {*Save All*NOT applied*}] 1
  check "GE10d 0648 the report NAMES the box that was dropped" \
    [d_echoed_n {*Save device OP parameters*}] 1
  check "GE10h 0648 ZERO STATE MUTATION survives the fix: tick + ESC still\
 leaves the state byte-identical (the GE1-GE16 contract, decision D1)" \
    [ase::state_serialize [ase::session_state $key]] $snap

  # GE10f: THE ACCEPTANCE ROW, GUI SIDE. The user's exact sequence: the nudge
  # has already fired for this cellview (take, then hold), the user ticks the
  # box, the tick is discarded -- and the tool must be able to speak again on
  # the next card-less run instead of going silent, which is the whole defect.
  cx {ase::op_cards_nudge_reset}
  set ge10f_st [ase::session_state $key]
  set ge10f_take [list [cx {ase::op_cards_nudge_ok $ge10f_st}] \
                       [cx {ase::op_cards_nudge_ok $ge10f_st}]]
  $top.mb.outputs invoke "Save All\u2026"
  update
  catch {$top.saveall.opparams invoke}
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  check "GE10f 0648 THE ACCEPTANCE ROW: a DISCARDED opparams tick RE-ARMS the\
 OP-card nudge (take, hold, then speak again)" \
    [list $ge10f_take [cx {ase::op_cards_nudge_ok [ase::session_state $key]}]] \
    {{1 0} 1}

  # GE10g: the window-manager close now behaves exactly as ESC does. Driven by
  # RUNNING the registered protocol command, which is what a real WM close
  # invokes -- and which is literally nothing at HEAD, so the dialog survives.
  d_echo_arm
  $top.mb.outputs invoke "Save All\u2026"
  update
  catch {$top.saveall.opparams invoke}
  set ge10g_cmd [cx {wm protocol $top.saveall WM_DELETE_WINDOW}]
  catch {uplevel #0 $ge10g_cmd}
  update
  d_echo_disarm
  check "GE10g 0648 a WM close destroys the dialog, cleans all three dlg\
 records AND reports the discard" \
    [list [winfo exists $top.saveall] \
          [info exists ::ase::ui::dlg($key,allv)] \
          [info exists ::ase::ui::dlg($key,alli)] \
          [info exists ::ase::ui::dlg($key,opparams)] \
          [d_echoed_n {*Save All*NOT applied*}]] {0 0 0 0 1}
  check "GE10h 0648 ZERO STATE MUTATION survives the fix: tick + WM close still\
 leaves the state byte-identical" \
    [ase::state_serialize [ase::session_state $key]] $snap
  # GE10i -- ISSUES 0692/0695: THE PER-KEY TOUCH RECORD SURVIVES NO TEARDOWN
  # PATH. GREEN AT HEAD and deliberately so (a guard, not evidence): at HEAD
  # there is no such record to leak -- the three checkbuttons carry no -command
  # and "the user touched this box" is a value diff. It is RETARGETED from the
  # as-opened `seed` record 0692 introduced, which 0695 deletes: once the touch
  # is an event on the widget the seed has no reader left, and a row asserting a
  # record nothing can create asserts nothing (test_ase_window W1zb term 5 pins
  # the deletion itself). This record is the ONLY guard it will ever have:
  # `ase::ui::save_all_close` (ase_window.tcl:3453-3466) unsets exactly
  # allv/alli/opparams and every existing cleanup row -- GE10 and GE10g above --
  # checks exactly those three, so a leaked touch record would outlive OK, ESC
  # AND the window-manager close with ZERO rows red, and would then make the
  # next dialog for this key believe a box was hand-ticked. It lives in this
  # suite because this is where 0648's WM-close protocol is owned.
  # The OK arm deliberately touches nothing, so its commit is idempotent and
  # GE10h's byte-identical-state contract above is not disturbed; the ESC and WM
  # arms DO tick a box first, so the record they must clean is a non-empty one --
  # `alli`, not `opparams`, so the OP-card nudge is left to GE10f which owns it.
  set ge10i {}
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.btns.proceed invoke}
  update
  lappend ge10i [info exists ::ase::ui::dlg($key,touched)]
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.alli invoke}
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  lappend ge10i [info exists ::ase::ui::dlg($key,touched)]
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.alli invoke}
  catch {uplevel #0 [cx {wm protocol $top.saveall WM_DELETE_WINDOW}]}
  update
  lappend ge10i [info exists ::ase::ui::dlg($key,touched)]
  check "GE10i 0695 the per-key touch record is unset by ALL THREE teardown\
 paths -- OK, ESC, and the window-manager close protocol" $ge10i {0 0 0}

  # GE10j -- ISSUE 0695: THE TOUCH RECORD IS CLEARED AT OPEN, NOT ONLY AT CLOSE.
  # `ase::ui::dialog_frame` (ase_window.tcl:1391) DESTROYS an existing toplevel
  # of the same name with NO cancel, so re-opening Save All from the menu while
  # one is already up runs no teardown at all. A `touched` record that survived
  # that would make the fresh dialog believe a box was hand-ticked -- and a box
  # the dialog believes was hand-ticked is exactly the box that must NOT follow
  # an external write. The leak is therefore invisible on OK (a touched field
  # resolves to its own displayed value, which at open IS the live value) and
  # shows up only here: the fresh dialog's box must still follow.
  # RED AT HEAD for 0695's plain reason -- nothing follows yet.
  set ge10j_st [ase::session_state $key]
  set ge10j_off $ge10j_st
  dict set ge10j_off save_op_params 0   ;# 0927: OFF is `0`; `{}` is now the ON default
  cx {ase::session_update $key $ge10j_off}
  $top.mb.outputs invoke "Save All…"
  update
  catch {$top.saveall.opparams invoke}      ;# a hand tick, then ABANDONED
  $top.mb.outputs invoke "Save All…"        ;# re-open: destroy, no cancel, no teardown
  update
  set ge10j_touched [cx {ase::ui::save_all_touched $key}]
  set ge10j_box0 [cx {set [$top.saveall.opparams cget -variable]}]
  cx {ase::ui::save_op_params_on $key}      ;# external write, behind the FRESH dialog
  update
  set ge10j_box1 [cx {set [$top.saveall.opparams cget -variable]}]
  catch {destroy $top.saveall}
  foreach ge10j_r {allv alli opparams seed touched} {
    catch {array unset ::ase::ui::dlg $key,$ge10j_r}
  }
  cx {ase::session_update $key $ge10j_st}
  update
  check "GE10j 0695 a hand tick ABANDONED by re-opening the dialog does not\
 follow the user into the fresh one: its touched set is empty and its box still\
 follows an external write" \
    [list $ge10j_touched $ge10j_box0 $ge10j_box1] {{} 0 1}

  # GE10k -- ISSUE 0695: THE TOUCH IS AN EVENT ON THE WIDGET, AND IT IS WIRED ON
  # ALL THREE BOXES. Measured at HEAD: every one of the three checkbuttons reads
  # `command={}` -- there is no touch event at all, which is precisely why "the
  # user changed this box" had to be a value diff, and a value diff cannot
  # survive a box that follows the live value (test_ase_window W1ze owns that
  # half). Structural on purpose: this is the only row that fails loudly if a
  # later edit re-adds a checkbutton without its -command, and it pins `invoke`'s
  # empty return, which every G5/GE10 hand-tick gesture in this suite relies on.
  $top.mb.outputs invoke "Save All…"
  update
  set ge10k {}
  foreach ge10k_f {allv alli opparams} {
    lappend ge10k [cx {$top.saveall.$ge10k_f cget -command}]
  }
  lappend ge10k [cx {$top.saveall.opparams invoke}]
  catch {$top.saveall.opparams invoke}      ;# un-tick: leave the state alone
  send_key $top.saveall <Key-Escape> {![winfo exists $top.saveall]}
  check "GE10k 0695 every Save All checkbutton reports its own hand tick through\
 ase::ui::save_all_mark_touched, and invoke still returns the empty string the\
 existing gestures rely on" $ge10k \
    [list [list ase::ui::save_all_mark_touched $key allv] \
          [list ase::ui::save_all_mark_touched $key alli] \
          [list ase::ui::save_all_mark_touched $key opparams] {}]

  # leave no half-open dialog behind on a tree where GE10g could not close it
  catch {destroy $top.saveall}
  foreach ge10_r {allv alli opparams seed touched} {
    catch {array unset ::ase::ui::dlg $key,$ge10_r}
  }
  update

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

  # --- G13 (casemode item 9, fix round) ---------------------------------------
  # A Direct-Plot / Select-On-Design pick asks the session's profile for the case
  # mode its expressions must be written in (ase::ui::sod_case_mode). That
  # question used to travel ase::sim_profile_casemode -> ase::sim_profile_resolve
  # -> ::set_sim_defaults, and set_sim_defaults is NOT a read: while the
  # Simulation Configuration dialog is open its first loop SLURPS every
  # `.sim…r.$i.cmd` text widget back into `sim($tool,$i,cmd)`. So one pick
  # COMMITTED the user's unsaved edits into global config and defeated that
  # dialog's Cancel — a read-only pick (issue 0204) writing something it has no
  # business writing. Fixed by asking with the resolver's `init 0` form and doing
  # a guarded one-time init instead; test_ase_sod_case SC208 pins the cause
  # headless, THIS pins the symptom with a real dialog and a real widget.
  ::set_sim_defaults
  set g13_before $::sim(spice,0,cmd)
  simconf
  update
  set g13_w .sim.topf.f.scrl.center.spice.r.0.cmd
  check_true "G13 fixture: the simconf row-0 cmd widget exists" \
    [expr {[winfo exists $g13_w] ? 1 : 0}]
  if {[winfo exists $g13_w]} {
    $g13_w delete 1.0 end
    $g13_w insert 1.0 {G13-USER-IS-STILL-TYPING}
    update
    set g13_mode {}
    catch {set g13_mode [ase::ui::sod_case_mode $key]}
    check "G13 a case-mode resolve leaves an OPEN simconf's unsaved edit uncommitted" \
      [list $::sim(spice,0,cmd) [expr {$g13_mode ne {} ? 1 : 0}]] [list $g13_before 1]
  }
  if {[winfo exists .sim]} {
    destroy .sim
    xschem set semaphore [expr {[xschem get semaphore] -1}]
  }
  update
  set ::sim(spice,0,cmd) $g13_before

  # done: close the session window (unsaved edits are discarded by contract).
  # item 16: this session is DIRTY; the menu Close now routes through
  # close_request's save prompt, so tear down directly (behavior-identical to
  # the pre-rewire menu Close).
  ase::ui::close $key
  update
  check_true "G12 session window closed" [expr {![winfo exists $top]}]

  # --- GG: THE TYPE GRID -- ISSUE 1411 ---------------------------------------
  # Eleven cells, four per row, each carrying its state as a GLYPH on the label.
  #
  # ⚠ EVERY ROW HERE IS A DISPLAY-ARM ROW, and `run_regression.tcl` runs this file
  # on NEITHER of its arms -- so a receipt quoting a T1 zero has not exercised one
  # of them. The resolver's own contract is in test_ase_core.tcl section AG,
  # deliberately, so it survives that.
  check "GG fixture: a session for the grid rows" \
    [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  catch {destroy $top.chana}
  $top.mb.analyses invoke "Choose…"
  update
  set gw $top.chana

  ## GG1 -- ELEVEN CELLS, FOUR PER ROW.
  ## ⚠ ELEVEN, NOT TWELVE. The plan's "twelve grid rows" counts the options sheet,
  ## which is `$w.opts` and is not an analysis type -- registering it would put it
  ## in ase::analysis_offered, in the seed and in the radio variable.
  ## ⚠ READ `grid info` BY NAME. Its key order is not guaranteed and taking
  ## `lindex 3`/`lindex 5` gave {row column} transposed on the first attempt --
  ## a row that would have passed or failed on Tk's option order, not on layout.
  set GG1COLS {}
  foreach gc [winfo children $gw.types] {
    set gi [grid info $gc]
    lappend GG1COLS [list [dict get $gi -row] [dict get $gi -column]]
  }
  check "GG1 every analysis this simulator describes gets a cell, and they wrap\
 four to a row instead of running off the dialog" \
    [list [llength [winfo children $gw.types]] \
          [lrange $GG1COLS 0 3] [lindex $GG1COLS 4]] \
    [list 11 {{0 0} {0 1} {0 2} {0 3}} {1 0}]

  ## GG2 -- ⚠ THE PATHS DID NOT MOVE. Four committed rows in three suites drive
  ## `$top.chana.types.<type>`; adding cells is safe, moving them is not, and
  ## issue 1405 is what that lesson cost. `pack` became `grid` inside the SAME
  ## frame, so the children keep their names.
  check "GG2 the cells the rest of the tree drives by name are still there under\
 those names, with the new ones added beside them" \
    [list [winfo exists $gw.types.op] [winfo exists $gw.types.dc] \
          [winfo exists $gw.types.ac] [winfo exists $gw.types.tran] \
          [winfo exists $gw.types.pss]] \
    {1 1 1 1 1}

  ## GG3 -- THE GLYPH CARRIES THE STATE, AND `ok` CARRIES NONE.
  ## Marking the normal case is how a grid becomes noise.
  check "GG3 a cell this adapter cannot yet drive is marked, and a cell that is\
 simply available is not" \
    [list [$gw.types.op cget -text] [$gw.types.pss cget -text] \
          [ase::ui::chana_glyph ok]] \
    [list op "⊘ pss" {}]

  ## GG4 -- ⚠ THE MEASUREMENT THAT FORCED THE GLYPH. A per-cell `-background` is
  ## WIPED: `ase::ui::_theme_widget`'s Radiobutton arm rewrites it and
  ## `ase::ui::populate` ends in `apply_theme $top`, which recurses into this child
  ## toplevel on every state mutation. This row sets a colour, repaints, and shows
  ## it gone -- so nobody re-proposes colour-coded cells.
  $gw.types.pss configure -background #123456
  set GG4SET [$gw.types.pss cget -background]
  ase::ui::apply_theme $top
  update
  check "GG4 a colour put on a cell does not survive the theme pass, which is why\
 the state is a glyph and not a colour" \
    [list [expr {$GG4SET eq {#123456}}] \
          [expr {[$gw.types.pss cget -background] eq {#123456}}]] \
    {1 0}

  ## GG5 -- ⚠ EVERY CELL IS SELECTABLE, INCLUDING A BLOCKED ONE, AND THIS IS THE
  ## ROW THAT MATTERS. `invoke` on a `-state disabled` radiobutton is a SILENT
  ## no-op (rc 0, variable unchanged, `-command` never fired), so disabling the
  ## cell would make a `.state` file carrying `{type pss enabled 1}` impossible to
  ## turn OFF in the dialog -- and would make a future row written as
  ## `$top.chana.types.pss invoke` pass while doing nothing at all.
  $gw.types.pss invoke
  update
  check "GG5 a cell for an analysis that cannot be run is still clickable, so its\
 reason can be read and a bench that already carries it can be edited" \
    [list [$gw.types.pss cget -state] $::ase::ui::dlg($key,antype)] \
    {normal pss}

  ## GG6 -- AND SELECTING IT SAYS WHY.
  check "GG6 selecting a blocked cell explains it in words rather than leaving the\
 user to guess from a greyed control" \
    [list [expr {[$gw.status cget -text] ne {}}] \
          [expr {[$gw.status cget -text] eq \
                 [ase::analysis_state_msg ngspice pss \
                   [ase::analysis_state ngspice pss [ase::sim_caps_cached ngspice]]]}]] \
    {1 1}

  ## GG7 -- WHAT IS DISABLED IS THE **Enable** CHECKBUTTON, not the cell.
  set GG7BLOCKED [$gw.enable cget -state]
  $gw.types.op invoke
  update
  check "GG7 an analysis that cannot be run cannot be switched on, while one that\
 can still can" \
    [list $GG7BLOCKED [$gw.enable cget -state]] \
    {disabled normal}

  ## GG8 -- ⚠ BUT A ROW ALREADY ON MUST STILL BE TURNABLE OFF. A bench can carry
  ## `{type pss enabled 1}` from a hand-edited file, and `ase::preflight_gate`
  ## refuses the run; if the dialog also refused to let it be cleared the user
  ## would have no way out except editing the file by hand.
  set GG8ST [ase::session_state $key]
  set GG8ROWS [ase::state_get $GG8ST analyses]
  lappend GG8ROWS {type pss enabled 1}
  dict set GG8ST analyses $GG8ROWS
  ase::session_update $key $GG8ST
  catch {destroy $gw}
  $top.mb.analyses invoke "Choose…"
  update
  set gw $top.chana
  $gw.types.pss invoke
  update
  check "GG8 a blocked analysis that is already switched on in the bench can still\
 be switched off, so a hand-edited state file is never a trap" \
    [list $::ase::ui::dlg($key,anen) [$gw.enable cget -state]] \
    {1 normal}

  ## GG9 -- DETECT IS OFFERED ONLY WHERE IT COULD CHANGE AN ANSWER.
  ## ⚠ A `noprobe` CELL IS ONE DETECT CAN NEVER HELP; offering the button there is
  ## the button that lies, and it is why `noprobe` is a separate reason token.
  check "GG9 the Detect button is live while cells rest on an assumption, and the\
 grid says which cells those are" \
    [list [winfo exists $gw.detect] \
          [$gw.detect cget -state] \
          [ase::analysis_detectable ngspice [ase::sim_caps_cached ngspice]]] \
    {1 normal 1}

  ## GG10 -- ⚠ DETECT PAINTS BEFORE IT BLOCKS, AND THE ORDER IS THE WHOLE POINT.
  ## The measurement can take up to 31.2 s against a binary that never answers,
  ## with Tk frozen throughout; setting the sentence and calling `update idletasks`
  ## BEFORE the blocking call is what puts it on screen. Structural, because the
  ## only behavioural way to see it is to own a binary that hangs.
  set GG10B {}
  foreach gl [split [info body ase::ui::chana_detect] "\n"] {
    if {[regexp {^\s*#} $gl]} { continue }
    append GG10B "$gl\n"
  }
  check "GG10 STRUCTURAL Detect puts its sentence on screen before it blocks, not\
 after the wait is over -- which would be the same as not saying it" \
    [list [expr {[string first {update idletasks} $GG10B] > \
                 [string first {analyses_measuring} $GG10B]}] \
          [expr {[string first {analysis_detect} $GG10B] > \
                 [string first {update idletasks} $GG10B]}]] \
    {1 1}

  ## GG11 -- NO TENTH COLOUR.
  check "GG11 the grid adds no colour to the locked palette, so it reads the same\
 in every theme" \
    [llength [dict keys [ase::palette]]] 9

  catch {destroy $gw}
  ase::ui::close $key
  update


  # --- G14: THE DIALOG DESCRIBES **THIS** SESSION'S SIMULATOR -----------------
  # Issue 1408, Stage 2 item 2d of doc/claude/ase_analyses_batch/.
  #
  # ⚠ MEASURED BEFORE THE FIX, ON THIS ARM: a bench whose state said
  # `simulator zznoad` -- a backend registered with the five hooks and NO
  # `analysis_types` hook -- was shown NGSPICE's four radio buttons, a
  # committable `dc` form, and `dc V2 0 1.8 0.01` in the Arguments column. The
  # registry was right the whole time (`ase::analysis_offered zznoad` answered
  # `{}`); the dialog asked `ase::analysis_offered` with no argument.
  #
  # ⚠ THESE ROWS ARE ON THE DISPLAY ARM AND `run_regression.tcl` RUNS THIS FILE
  # ON NEITHER OF ITS ARMS -- measured. So a receipt quoting a T1 zero has NOT
  # exercised one of them. The schema half is in test_ase_core section AD,
  # deliberately, so the contract survives even where these cannot run.
  proc g14_five {} {
    return [dict create \
      render_deck  [ase::backend_hook ngspice render_deck] \
      run_cmd      [ase::backend_hook ngspice run_cmd] \
      log_file     [ase::backend_hook ngspice log_file] \
      result_probe [ase::backend_hook ngspice result_probe] \
      raw_file     [ase::backend_hook ngspice raw_file]]
  }
  catch {ase::register_backend zznoad [g14_five]}
  ## ⚠ `ase::session_update` DOES NOT REDRAW THE PANE, measured -- the Arguments
  ## column still held ngspice's deck lines after the state said `zznoad`. These
  ## rows set the simulator behind the UI's back (there is no gesture that edits
  ## the state key directly), so they must repaint the way the product's own
  ## simulator-choice path does, or they would be measuring a stale treeview.
  proc g14_setsim {k s} {
    set st [ase::session_state $k]
    dict set st simulator $s
    ase::session_update $k $st
    ase::ui::populate $k
    update
  }
  proc g14_kids {w} {
    if {![winfo exists $w]} { return NOWIDGET }
    set o {} ; foreach c [winfo children $w] { lappend o [winfo name $c] }
    return [lsort $o]
  }
  proc g14_state {w} {
    if {![winfo exists $w]} { return NOWIDGET }
    if {[catch {$w cget -state} v]} { return NOSTATE }
    return $v
  }

  ## ⚠ A FRESH SESSION AND A FRESH `$top`. By this point in the file the window
  ## G1 opened is gone -- measured, `$top.mb.analyses` raised
  ## `invalid command name ".ase5.mb.analyses"` -- so this block re-opens rather
  ## than inheriting a toplevel whose lifetime it does not control.
  check "G14 fixture: a session for these rows" \
    [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  check_true "G14 fixture: its window is up" \
    [expr {$top ne {} && [winfo exists $top]}]
  catch {destroy $top.chana}
  g14_setsim $key zznoad
  set G14ANA0 [ase::state_get [ase::session_state $key] analyses]
  $top.mb.analyses invoke "Choose…"
  update

  ## G14a -- the grid is empty, because this simulator offers nothing.
  check "G14a a bench naming a simulator ASE-L has no adapter for gets NO analysis\
 radio buttons, instead of the default simulator's four" \
    [g14_kids $top.chana.types] {}

  ## G14b -- and it SAYS SO. ⚠ Not a fifth cell state and not a Detect button:
  ## the states are per ANALYSIS and there are no rows to colour, and no probe
  ## can help because the gap is in ASE-L rather than in the binary.
  check "G14b an empty grid says why it is empty, naming the simulator" \
    [list [expr {[$top.chana.status cget -text] ne {}}] \
          [expr {[string first {zznoad} [$top.chana.status cget -text]] >= 0}] \
          [expr {[$top.chana.status cget -text] eq [ase::analysis_gap_msg zznoad]}]] \
    {1 1 1}

  ## G14c -- every control that could write the bench is disabled.
  check "G14c with nothing to choose, Enable, Options and OK are all disabled" \
    [list [g14_state $top.chana.enable] [g14_state $top.chana.opts] \
          [g14_state $top.chana.btns.proceed]] \
    {disabled disabled disabled}

  ## G14d -- ⚠ AND THE PRESELECT IS EMPTY, NOT `op`. An unconditional `op` is
  ## what let OK append `{type op enabled 1}` to a bench whose backend cannot
  ## render op.
  check "G14d nothing is preselected when nothing is offered" \
    $::ase::ui::dlg($key,antype) {}

  ## G14e -- ⚠ THE COMMIT DOORS REFUSE ON **MEMBERSHIP**, NOT ON EXISTENCE.
  ## `[info exists dlg($key,antype)]` is TRUE for an `antype` of `{}`, which is
  ## exactly the value an empty grid leaves behind -- so the three doors were
  ## reachable and `chana_x_ok` would have written `{type {} enabled 0}` into the
  ## bench: a state key for a type that does not exist, round-tripping through
  ## the .state file forever. Driving the PROCS and not the buttons is the point,
  ## because a disabled Tk button's `invoke` returns `{}` and would hide it.
  set G14SAID {}
  set ::g14_echo {}
  set g14_had [expr {[info commands ::ciw_echo] ne {}}]
  if {$g14_had} { rename ::ciw_echo ::g14_saved_ciw }
  proc ::ciw_echo {line {tag {}}} { lappend ::g14_echo [list $tag $line] ; return {} }
  catch {ase::ui::chana_ok $key}
  catch {ase::ui::chana_options $key}
  ## ⚠ `anextra` IS PLANTED ON PURPOSE, AND WITHOUT IT THIS ROW IS BLIND.
  ## `chana_x_ok` returns early unless `dlg($key,anextra)` exists, and only
  ## `chana_options` sets it -- which the guard above has just refused. MEASURED:
  ## with `chana_x_ok`'s membership guard DELETED the suite still read ALL PASS,
  ## because the door was never reached. The state it protects is reachable in
  ## the product (open Options under one simulator, change the bench's simulator,
  ## press OK), and it is the door that writes `{type {} enabled 0}` -- a state
  ## key for a type that does not exist, round-tripping through the .state file
  ## forever. So the fixture puts the dialog in that state and knocks.
  set ::ase::ui::dlg($key,anextra) {}
  catch {ase::ui::chana_x_ok $key}
  array unset ::ase::ui::dlg $key,anextra
  set G14SAID $::g14_echo
  catch {rename ::ciw_echo {}}
  if {$g14_had} { rename ::g14_saved_ciw ::ciw_echo }
  update
  check "G14e all three commit doors refuse: the bench is untouched, no Options\
 subdialog is built, and each refusal says why" \
    [list [expr {[ase::state_get [ase::session_state $key] analyses] eq $G14ANA0}] \
          [winfo exists $top.chana.x] \
          [expr {[llength $G14SAID] >= 1}] \
          [expr {[string first {has no adapter} [lindex $G14SAID 0 1]] >= 0}]] \
    {1 0 1 1}

  ## G14f -- the Arguments column. ⚠ THE `op` ROW GOES BLANK and that is a
  ## ratified consequence, not an accident: there is no deck line to show, and
  ## the Type column beside it already says `op`.
  set G14PANE {}
  foreach g14r [$top.body.ana.tv children {}] {
    lappend G14PANE [lindex [$top.body.ana.tv item $g14r -values] 3]
  }
  check "G14f the Arguments column shows the stored keys under a simulator with\
 no adapter, and the op row -- which has no keys -- goes blank rather than\
 echoing a deck line no backend emits" \
    $G14PANE {{} {source=V2 start=0 stop=1.8 step=0.01} {} {}}

  catch {destroy $top.chana}

  ## G14g -- THE CONTROL, and it is what makes every row above non-vacuous:
  ## put ngspice back and the whole dialog works exactly as it did.
  g14_setsim $key ngspice
  $top.mb.analyses invoke "Choose…"
  update
  set G14PANE2 {}
  foreach g14r [$top.body.ana.tv children {}] {
    lappend G14PANE2 [lindex [$top.body.ana.tv item $g14r -values] 3]
  }
  ## ⚠ ELEVEN, NOT FOUR. This row asserted four until issue 1410 registered the
  ## seven analyses ngspice has that ASE-L cannot yet drive; they are LISTED so the
  ## user can see they exist, and each carries a `blocked` cell. The row is a
  ## CONTROL -- its job is that putting ngspice back restores the working dialog --
  ## so it tracks the registry rather than naming a number, and `lsort` is why the
  ## order here is alphabetical while the grid's is emit order (AG1 pins that).
  ## ⚠ THE SECOND TERM ASSERTS THE GAP SENTENCE IS **GONE**, NOT THAT THE LINE IS
  ## EMPTY. It was written as "nothing is said" when the status line existed only
  ## to explain an empty grid; issue 1411 gave every cell a sentence, so with
  ## ngspice back the line carries the SELECTED cell's own reason -- `op` resting
  ## on a source-verified invariant nobody has measured. What must not come back
  ## is the no-adapter line, and that is what is checked.
  check "G14g CONTROL with ngspice back the full grid returns, the no-adapter\
 line is gone and the selected cell explains itself instead, every control is\
 live, op is preselected and the pane shows deck lines again" \
    [list [g14_kids $top.chana.types] \
          [expr {[string first {no adapter} [$top.chana.status cget -text]] < 0}] \
          [expr {[$top.chana.status cget -text] eq \
                 [ase::analysis_state_msg ngspice op \
                   [ase::analysis_state ngspice op [ase::sim_caps_cached ngspice]]]}] \
          [list [g14_state $top.chana.enable] [g14_state $top.chana.opts] \
                [g14_state $top.chana.btns.proceed]] \
          $::ase::ui::dlg($key,antype) \
          [lindex $G14PANE2 0]] \
    [list {ac dc disto noise op pss pz sens sp tf tran} 1 1 {normal normal normal} op op]
  $top.chana.btns.cancel invoke
  update

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
