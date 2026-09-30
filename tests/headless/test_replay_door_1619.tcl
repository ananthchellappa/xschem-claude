# Issue 1619 -- THE ACTION LOG'S REPLAY DOOR.
#
# The recording engine shipped long ago and is fenced by 29 round-trip suites:
# `replay_action_log` (src/xschem.tcl) wraps `source` in the
# `xschem log_action -suppress push/pop` depth counter, and a recorded log
# replayed in a fresh process gives a BYTE-IDENTICAL log back. What did not
# exist was any way for a USER to reach it -- no actions.csv row, no menu entry,
# no keybinding, no file chooser. The only route was typing the proc name into
# the CIW. So "macros and script creation from log files" (wish-list old item 3)
# was at zero for want of a door, not for want of an engine.
#
# This suite fences the DOOR, in five bands, and deliberately does NOT re-fence
# the engine (that is the `test_perform_action_*` family's job):
#
#   D*  the declarative registration: the actions.csv row, its column values,
#       and its visibility to the command palette's own predicate.
#   P*  the two procs and the way they are wired: the chooser half delegates to
#       the testable half, and NEITHER contains a second `source` -- the door
#       reuses the shipped seam instead of re-implementing replay.
#   R*  behaviour against the real binary: a good log applies its EFFECT; a
#       cancelled, missing, malformed or foreign-schematic log is REPORTED and
#       never throws out of the door; and the shipped seam still throws, so the
#       catch in the door is load-bearing rather than decorative.
#   L*  the log-side properties, measured in a CHILD with its own --logdir
#       (T1's hcases loop passes no --logdir): a replay is not re-logged, and a
#       FAILED replay leaves the suppress depth balanced so the session keeps
#       logging afterwards.
#   M*  the Tools-menu entry: grep-guarded on the headless arm, and asserted
#       against the live Tk menu when a display is present.
#
# THREE FINDINGS THIS SUITE PINS, because they are answers a reader will want
# and a future change could silently reverse:
#
#  1. A REPLAY IS N UNDO UNITS, NOT ONE (row R2). Every logged verb pushes its
#     own undo slot, so undoing a 50-line macro takes 50 undos. There is no
#     Tcl-level undo-grouping primitive -- `xschem push_undo` adds a slot, it
#     does not merge the ones the verbs push -- so making a replay atomic needs
#     a C-side undo barrier, which is out of this issue's scope. R2 pins the
#     current behaviour, so the day someone adds that barrier this row says so.
#
#  2. A MALFORMED LOG LEAVES A HALF-CHANGED SCHEMATIC (rows R5, R6). A log file
#     is executable Tcl and `replay_action_log` wraps `source`, which evaluates
#     commands one at a time: the lines BEFORE the error have already run when
#     the error is raised, and the lines after never run. So the door cannot
#     promise all-or-nothing, and it must not pretend to. What it CAN promise --
#     and R5/R6 assert -- is that the failure is reported rather than thrown,
#     and that the partial state is exactly what the log's own prefix produced.
#
#  3. A LOG RECORDED AGAINST A DIFFERENT SCHEMATIC ABORTS AT THE FIRST LINE
#     THAT CANNOT APPLY (row R7), with the same partial-state consequence. A log
#     recorded through the file dialog usually opens with `xschem load {...}`,
#     which re-establishes its own schematic, so this bites hardest on a log
#     recorded mid-session.
#
# Spec: doc/claude/specs/action_logging.md section 3b.
#
# Run:
#   headless: tests/headless/run_suites.sh --nogui test_replay_door_1619
#   display:  tests/headless/run_suites.sh test_replay_door_1619
# Registered in hcases AND dcases in tests/run_regression.tcl (band M's live-menu
# rows need a mapped menubar; the headless arm grep-guards the same wiring and
# prints an uppercase SKIPPED:, which is neither a counted nor a skip-counted
# shape). Prints "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
  flush stdout
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# Evaluate $script in the CALLER's frame and return its result, or a LEGIBLE
# SENTINEL if it raised. Everything this suite probes can raise on a tree with no
# door (an unknown proc name, an `info body` of a proc that is not there), and a
# raise would hit the file-scope catch and abort the run -- issue 1616 lost 340
# of its 402 checks to exactly that.
proc q {script} {
  if {[catch {uplevel 1 $script} r]} { return "RAISED($r)" }
  return $r
}

set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here .. ..]]
set bin  [info nameofexecutable]
source [file join $here scratch.tcl]
set work [test_scratch replay_door_1619]

# The door's identity, in one place: the id, the label and the two proc names.
# Every band below reads these, so a rename is one edit here plus the product.
set ID    tools.replay_action_log
set LABEL {Replay action log...}
set DLG   replay_action_log_dialog
set RUN   replay_action_log_run

# Invoke the door's testable half WITHOUT re-parsing its argument (a scratch path
# can contain a space, which `uplevel` would resplit) and without ever raising.
proc doorrun {path} {
  global RUN
  if {[catch {$RUN $path} r]} { return "RAISED($r)" }
  return $r
}

# =====================================================================
# D* -- the declarative registration (src/actions.csv -> $::action_table)
# =====================================================================
proc row_by_id {id} {
  global action_table
  if {![info exists action_table]} { return {} }
  foreach r $action_table { if {[dict get $r id] eq $id} { return $r } }
  return {}
}
# Field access that cannot raise on a missing row or a missing key.
proc rf {row key} {
  if {$row eq {}} { return "NO-ROW" }
  if {![dict exists $row $key]} { return "NO-KEY" }
  return [dict get $row $key]
}

set row [row_by_id $ID]
check_true "D1 actions.csv has a row with id $ID"  [expr {$row ne {}}]
check "D2 the row's type is command"               [rf $row type] {command}
check "D3 the row sits on the tools menu"          [rf $row menu] {tools}
check "D4 the row's command is the chooser proc"   [rf $row command] $DLG
check "D5 the row's label is the shipped wording"  [rf $row label] $LABEL
# A chooser entry ends in "..." -- the convention `Net highlight styles...`
# follows on this same menu.
check_true "D6 the label ends in ... (it opens a chooser)" \
  [string match {*...} [rf $row label]]
# help is the command palette's and the keybindings cheat-sheet's only prose for
# this action, so it must be a sentence and not an echo of the label.
check_true "D7 the row has help prose, not a label echo" \
  [expr {[string length [rf $row help]] > [string length $LABEL] \
         && [rf $row help] ne [rf $row label]}]
# nolog: the csv command opens a MODAL chooser. If Layer A ever pushed it as a
# replay command (which happens the moment this id gains a C registry entry), a
# replayed log would stop dead waiting for a human -- the documented reason
# file.open, place_symbol and place_text are nolog.
check "D8 the row is nolog=1 (a modal chooser must never become a replay command)" \
  [rf $row nolog] {1}
# No accelerator is claimed: a real chord needs a C input-binding entry and this
# issue ships no C change. An accel string here would advertise a chord that
# binds nothing -- the column is DISPLAY ONLY, per actions.csv's own header.
check "D9 the row claims no accelerator (no C binding ships with it)" \
  [rf $row accel] {}
# The palette's own predicate, lifted from palette_refilter: a row is runnable
# from the palette iff type eq command AND command ne {}.
check_true "D10 the row satisfies the palette's own runnable predicate" \
  [expr {[rf $row type] eq {command} && [rf $row command] ne {}}]
check_true "D11 a plausible palette query scores the row (fuzzy_subseq_score)" \
  [expr {[q {fuzzy_subseq_score replay [rf $row label]}] > 0}]
# Exactly one row, or the palette and the cheat-sheet show the action twice.
set nid 0
if {[info exists ::action_table]} {
  foreach r $::action_table { if {[dict get $r id] eq $ID} { incr nid } }
}
check "D12 exactly one row carries that id" $nid 1

# =====================================================================
# P* -- the two procs, and the wiring between them
# =====================================================================
check_true "P1 the chooser proc $DLG is defined" \
  [expr {[llength [info procs $DLG]] == 1}]
check_true "P2 the testable half $RUN is defined" \
  [expr {[llength [info procs $RUN]] == 1}]
check_true "P3 the shipped seam replay_action_log is still defined" \
  [expr {[llength [info procs replay_action_log]] == 1}]

set dlgbody [q {info body $DLG}]
set runbody [q {info body $RUN}]
# tk_getOpenFile GRABS THE DISPLAY AND WAITS FOR A HUMAN: no headless run and no
# Xvfb run can press OK in it, so this wiring is grep-guarded rather than driven
# (ase::ui::simdlg_browse and wviewer::rawbar_browse declare the same limit).
check_true "P4 the chooser proc really opens a file chooser (tk_getOpenFile)" \
  [string match {*tk_getOpenFile*} $dlgbody]
# `replay_action_log_run ` and `replay_action_log ` differ in the character after
# the prefix, so these two string matches genuinely partition delegate-vs-inline.
check_true "P5 the chooser proc delegates to $RUN rather than replaying inline" \
  [expr {[string match "*$RUN *" $dlgbody] \
         && ![string match {*replay_action_log *} $dlgbody]}]
# THE POINT OF THE ISSUE: the door reuses the shipped seam. A `source` in either
# new proc would be a SECOND replay path, outside the suppress counter, and its
# lines would re-log on every replay.
check_true "P6 neither new proc contains its own source (no second replay path)" \
  [expr {![string match {*source *} $dlgbody] && ![string match {*source *} $runbody]}]
check_true "P7 the testable half calls the shipped seam replay_action_log" \
  [string match {*replay_action_log *} $runbody]
# The seam itself is unchanged: suppress push, source, suppress pop.
set seam [q {info body replay_action_log}]
check_true "P8 the seam still brackets its source with suppress push/pop" \
  [expr {[string match {*-suppress push*} $seam] \
         && [string match {*source *} $seam] \
         && [string match {*-suppress pop*} $seam]}]
# The chooser's sticky initial directory follows the INITIAL*DIR house pattern
# (INITIALINSTDIR / INITIALTEXTDIR / INITIALPROPDIR: lazily created, remembered
# across opens). Its three siblings are all PER-WINDOW-CONTEXT, listed in
# tctx::global_list; a new one left out of that list would be the single
# INITIAL*DIR that leaks between tabs, which no other row would notice.
check_true "P9 the chooser uses an INITIAL*DIR sticky dir (INITIALLOGDIR)" \
  [string match {*INITIALLOGDIR*} $dlgbody]
check_true "P9b INITIALLOGDIR is per-context like its INITIAL*DIR siblings (tctx::global_list)" \
  [expr {[lsearch -exact [q {set ::tctx::global_list}] INITIALLOGDIR] >= 0}]

# =====================================================================
# R* -- behaviour against the real binary, in this process
# =====================================================================
proc mklog {name lines} {
  global work
  set p [file join $work $name]
  set fd [open $p w]; foreach l $lines { puts $fd $l }; close $fd
  return $p
}
proc nwires {} { return [q {xschem get wires}] }

# R1 -- a good log applies its EFFECT and the door reports success.
set good [mklog good.log [list \
  {xschem wire 0 0 100 0} \
  {xschem wire 0 100 100 100}]]
set w0 [nwires]
check "R1a the door reports success on a good log"  [doorrun $good] 1
check "R1b EFFECT: the two logged wires exist (+2)" [nwires] [expr {$w0 + 2}]

# R2 -- ANSWER TO "IS A REPLAY ONE UNDO UNIT OR N?": it is N. Each logged verb
# pushes its own undo slot, so ONE undo removes ONE wire, not both. Pinned here
# so a future undo barrier (which needs a C change) shows up as this row moving.
q {xschem undo}
check "R2 a replay is N undo units, not one (one undo removes one line's effect)" \
  [nwires] [expr {$w0 + 1}]
q {xschem undo}

# R3 -- Cancel. tk_getOpenFile returns {} on Cancel; the door must do nothing at
# all, not hand the empty string to `source`.
set w0 [nwires]
check "R3a a cancelled chooser ({} path) reports no replay" [doorrun {}] 0
check "R3b a cancelled chooser changes nothing"             [nwires] $w0

# R4 -- an unreadable path. The RAW SEAM THROWS (control: that is why the door
# has to catch), the DOOR reports instead, and nothing changes.
set gone [file join $work does_not_exist.log]
set w0 [nwires]
check "R4a the door reports failure on an unreadable path" [doorrun $gone] 0
check "R4b an unreadable path changes nothing"             [nwires] $w0
check_true "R4c control: the RAW seam THROWS on the same path (the catch is load-bearing)" \
  [expr {[catch {replay_action_log $gone}] == 1}]

# R5 -- ANSWER TO "WHAT HAPPENS ON A MALFORMED LOG?": a log file is executable
# Tcl, `source` evaluates commands one at a time, so a syntax error mid-file runs
# everything above it and nothing below. The door reports; the schematic is HALF
# CHANGED, and this row states by how much rather than hiding it. (The bad line
# is written as a QUOTED string with a backslash-escaped brace, so this suite's
# own parser stays balanced.)
set bad [mklog bad.log [list \
  {xschem wire 0 0 100 0} \
  {xschem wire 0 100 100 100} \
  "this line has an unbalanced \{ brace" \
  {xschem wire 0 200 100 200}]]
set w0 [nwires]
check "R5a the door reports failure on a syntax error mid-file" [doorrun $bad] 0
check "R5b a syntax error leaves a PARTIAL replay: the 2 lines above it applied" \
  [nwires] [expr {$w0 + 2}]
q {xschem undo}; q {xschem undo}

# R6 -- the same for a RUNTIME error (an unknown command mid-file): line 1
# applied, line 3 did not.
set rerr [mklog runerr.log [list \
  {xschem wire 0 0 100 0} \
  {no_such_command_1619 foo} \
  {xschem wire 0 200 100 200}]]
set w0 [nwires]
check "R6a the door reports failure on a runtime error mid-file" [doorrun $rerr] 0
check "R6b a runtime error leaves a PARTIAL replay: only the line above it applied" \
  [nwires] [expr {$w0 + 1}]
q {xschem undo}

# R7 -- ANSWER TO "WHAT ABOUT A LOG RECORDED AGAINST A DIFFERENT SCHEMATIC?": the
# first line whose referent does not exist here raises, and the replay stops
# there. `xschem setprop instance 3 ...` is the deterministic case -- it answers
# "xschem setprop: instance not found" against a schematic with no instance 3.
set foreign [mklog foreign.log [list \
  {xschem wire 0 0 100 0} \
  {xschem setprop instance 3 name X1619} \
  {xschem wire 0 200 100 200}]]
set w0 [nwires]
check "R7a the door reports failure on a log recorded against another schematic" \
  [doorrun $foreign] 0
check "R7b it aborts AT the foreign line: the line above applied, the one below did not" \
  [nwires] [expr {$w0 + 1}]
q {xschem undo}

# R8 -- a DIRECTORY is not a log. tk_getOpenFile will not return one, but the
# palette, the CIW and a future keybinding can all reach the door with any string.
set w0 [nwires]
check "R8a the door reports failure when handed a directory" [doorrun $work] 0
check "R8b being handed a directory changes nothing"         [nwires] $w0

# =====================================================================
# C* -- WHAT THE DOOR SAYS. The door's only feedback channel is ciw_echo (the
# action log's own channel -- [[ciw-feedback-channels]] says ciw_echo, not
# puts/the statusbar -- and deliberately NOT a tk_messageBox, which would make
# these very paths undrivable on any arm with a display). ciw_echo is defined
# under --nogui too (it no-ops when the pane is absent), so SHADOWING it is how
# the words become testable. Without this band, a door that reported NOTHING at
# all, or that said "replayed" after a failure, would pass every other row.
# =====================================================================
set ciwlines {}
set spy_ok [expr {[llength [info commands ciw_echo]] == 1}]
check_true "C0 ciw_echo exists to be shadowed (the door's only feedback channel)" $spy_ok
if {$spy_ok} {
  rename ciw_echo replay_door_1619_real_ciw_echo
  proc ciw_echo {line {tag {}}} { lappend ::ciwlines $line }
}
proc said {pat} {
  foreach l $::ciwlines { if {[string match $pat $l]} { return 1 } }
  return 0
}
proc saidwhat {} { return [join $::ciwlines { | }] }

set ciwlines {}; doorrun $good
check_true "C1 a good replay is announced and names the path" \
  [expr {[said {*replayed*good.log*}] && ![said {*STOPPED*}]}]
q {xschem undo}; q {xschem undo}

set ciwlines {}; doorrun $bad
check_true "C2 a failed replay says it STOPPED and names the path" \
  [said {*STOPPED*bad.log*}]
# THE SENTENCE THE USER MOST NEEDS: the schematic is half changed. Without it the
# only honest thing about a failed replay goes unsaid.
check_true "C3 a failed replay warns that the lines above it were already applied" \
  [said {*already been applied*}]
check_true "C4 a failed replay does NOT also claim success" \
  [expr {![said {*replayed action log*}]}]
q {xschem undo}; q {xschem undo}

set ciwlines {}; doorrun $gone
check_true "C5 an unreadable path says it cannot be read, not that it was replayed" \
  [expr {[said {*cannot read*}] && ![said {*replayed action log*}]}]

set ciwlines {}; doorrun $work
check_true "C6 a directory says it cannot be read" [said {*cannot read*}]

# C7 -- CANCEL IS SILENT. A door that forgot to special-case the empty path still
# returns 0 (file readable {} is false), so R3a cannot tell the difference; this
# row is the only thing between that and a spurious "cannot read {}" in the CIW
# every time a user changes their mind in the chooser.
set ciwlines {}; doorrun {}
check "C7 a cancelled chooser says NOTHING at all" [saidwhat] {}

if {$spy_ok} { rename ciw_echo {} ; rename replay_door_1619_real_ciw_echo ciw_echo }
check_true "C8 the real ciw_echo was restored" \
  [expr {[llength [info commands ciw_echo]] == 1 \
         && [llength [info commands replay_door_1619_real_ciw_echo]] == 0}]

# =====================================================================
# X* -- THE CHOOSER HALF, with tk_getOpenFile SHADOWED.
# tk_getOpenFile itself cannot be driven -- it grabs the display and waits for a
# human, which is why this tree's other Browse buttons declare themselves
# untestable -- but everything the chooser proc does AROUND it can be, by
# shadowing the one command that blocks. That is the difference between
# grep-guarding the wiring (P4/P5) and proving it. The shadow is installed only
# for this band and removed at its end; on an arm where Tk supplies the real
# command it is renamed aside first, never destroyed.
# =====================================================================
set had_gof [expr {[llength [info commands tk_getOpenFile]] == 1}]
if {$had_gof} { rename tk_getOpenFile replay_door_1619_real_gof }
set gof_args {}
set gof_answer {}
set gof_calls 0
proc tk_getOpenFile {args} {
  set ::gof_args $args
  incr ::gof_calls
  return $::gof_answer
}
proc gof_opt {name} {
  set i [lsearch -exact $::gof_args $name]
  if {$i < 0 || $i + 1 >= [llength $::gof_args]} { return "NO-OPT" }
  return [lindex $::gof_args [expr {$i + 1}]]
}
proc dlgrun {} {
  global DLG
  if {[catch {$DLG} r]} { return "RAISED($r)" }
  return $r
}

# X1 -- Cancel: the chooser returns {} and the door must do nothing at all.
set w0 [nwires]; set gof_answer {}; set gof_calls 0
check "X1a a cancelled chooser makes the door report no replay" [dlgrun] 0
check "X1b the chooser really was consulted once"               $gof_calls 1
check "X1c a cancelled chooser changes nothing"                 [nwires] $w0

# X2 -- the chooser's answer is what gets replayed, EFFECT and all. This is the
# row that proves the menu entry actually does the thing.
set w0 [nwires]; set gof_answer $good
check "X2a the chooser's pick is replayed and reported as success" [dlgrun] 1
check "X2b EFFECT: the picked log's two wires exist (+2)"          [nwires] [expr {$w0 + 2}]
q {xschem undo}; q {xschem undo}
# X2c -- the chooser must PROPAGATE a failure, not report success for it. Dropping
# the run half's answer is a no-op in Tcl (a proc returns its last command's
# value), but `replay_action_log_run $path ; return 1` is the shape that looks
# tidy and lies, and X1a/X2a cannot tell it apart -- Cancel returns before it and
# a good log returns 1 anyway. This is the row that can.
set gof_answer $bad
check "X2c a FAILED replay is reported as failure by the chooser too" [dlgrun] 0
q {xschem undo}; q {xschem undo}

# X3 -- the chooser is asked with a usable initial directory and a .log filter.
check_true "X3a the chooser is given an existing -initialdir" \
  [q {file isdirectory [gof_opt -initialdir]}]
check "X3b the chooser's -title is the terse dialog wording" \
  [gof_opt -title] {Replay action log}
check_true "X3c the chooser offers a .log filter and an all-files escape" \
  [expr {[string match {*.log*} [gof_opt -filetypes]] \
         && [string match {*All files*} [gof_opt -filetypes]]}]

# X4 -- STICKY DIRECTORY: after a pick, the next open starts where the user left
# off. $good lives in the scratch dir, so that is what the second open must offer.
set gof_answer {}
dlgrun
check "X4 the next open starts in the directory last picked from (INITIALLOGDIR)" \
  [file normalize [gof_opt -initialdir]] [file normalize $work]

# X5 -- a stale remembered directory must not be handed to the chooser. (A user
# picks a log on a removable volume, unmounts it, reopens the door.)
set ::INITIALLOGDIR [file join $work no_such_dir_1619]
set gof_answer {}
dlgrun
check_true "X5 a vanished remembered directory is replaced, not passed on" \
  [q {file isdirectory [gof_opt -initialdir]}]

rename tk_getOpenFile {}
if {$had_gof} { rename replay_door_1619_real_gof tk_getOpenFile }
check "X6 tk_getOpenFile was left exactly as it was found" \
  [expr {[llength [info commands tk_getOpenFile]] == 1}] $had_gof

# =====================================================================
# L* -- the log-side properties, in a CHILD with its own --logdir
#       (T1's hcases loop passes no --logdir, so these cannot run in-process)
# =====================================================================
set childn 0
proc run_child {inner} {
  global bin work childn RUN
  set d [file join $work c[incr childn]]
  file mkdir $d
  set sf [file join $d inner.tcl]
  set fd [open $sf w]; puts $fd [string map [list @RUN@ $RUN] $inner]; close $fd
  catch {exec $bin --nogui --pipe -q --logdir $d --script $sf 2>@1}
  set lf [file join $d Xschem.log]
  if {![file exists $lf]} { return "NO-LOG" }
  set rf [open $lf r]; set body [read $rf]; close $rf
  return $body
}
proc countlines {body pat} {
  set n 0
  foreach l [split $body \n] { if {[string match $pat $l]} { incr n } }
  return $n
}

# L1 -- a replay through the door is NOT re-logged: it rides the seam's suppress
# counter. The fixture holds a wire (an observable EFFECT) and an `xschem copy`
# (the canary that self-logs unconditionally and needs no selection). L1a proves
# the replay actually RAN -- without it, L1b would pass vacuously on a tree where
# the door does not exist at all, which is precisely the "absence of a log line
# is not absence of coverage" trap.
set l1 [run_child {
  set d [file dirname [xschem get actionlog_filename]]
  set p [file join $d l1_fixture.log]
  set fd [open $p w]
  puts $fd {xschem wire 0 0 100 0}
  puts $fd {xschem copy}
  close $fd
  @RUN@ $p
  xschem log_action -noecho "MARK1619 wires=[xschem get wires]"
  exit
}]
check "L1a EFFECT: the replay ran in the child (one wire from the fixture)" \
  [countlines $l1 {MARK1619 wires=1}] 1
check "L1b the replayed lines are NOT re-logged (they ride the suppress seam)" \
  [countlines $l1 {xschem copy*}] 0

# L2 -- AFTER A FAILED REPLAY THE SESSION STILL LOGS. The seam pops its suppress
# depth before re-raising, and the door catches rather than unwinding past the
# pop -- so a bad log must not wedge logging off for the rest of the session. A
# door written by hand as `push; source; pop` would fail exactly here.
set l2 [run_child {
  set d [file dirname [xschem get actionlog_filename]]
  set p [file join $d l2_fixture.log]
  set fd [open $p w]; puts $fd {no_such_command_1619 foo}; close $fd
  @RUN@ $p
  xschem copy
  exit
}]
check "L2 after a FAILED replay the session still logs (suppress depth balanced)" \
  [expr {[countlines $l2 {xschem copy*}] >= 1}] 1

# =====================================================================
# M* -- the Tools-menu entry
# =====================================================================
# Headless grep guard: the menubar needs Tk, so on the --nogui arm assert the
# WIRING in the source instead. The wanted text is BUILT from $LABEL and $DLG, so
# a rename is caught rather than silently un-guarded.
set sf [file join $root src xschem.tcl]
set sb [read [set f [open $sf r]]]; close $f
set want "menubar.tools add command -label \"$LABEL\" -command \{$DLG\}"
check_true "M1 src/xschem.tcl adds the Tools-menu entry with that label and command" \
  [expr {[string first $want $sb] >= 0}]

if {[llength [info commands winfo]] && ![catch {winfo exists .}]} {
  set tm .menubar.tools
  set seen 0; set cmd {}
  set last -1
  catch {set last [$tm index end]}
  if {[winfo exists $tm] && $last ne {} && $last ne {none}} {
    for {set i 0} {$i <= $last} {incr i} {
      if {![catch {$tm entrycget $i -label} lbl] && $lbl eq $LABEL} {
        set seen 1
        catch {set cmd [$tm entrycget $i -command]}
      }
    }
  }
  check "M2 the live Tools menu carries the entry" $seen 1
  check "M3 the live entry's -command is the chooser proc" [string trim $cmd "{} "] $DLG
} else {
  puts "SKIPPED: M2/M3 live Tools-menu rows (no Tk on this arm; M1 grep-guards the same wiring)"
  flush stdout
}

# --- verdict ---
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail != 0}]
