# Issue 0682 — annotation visibility lives ONLY in ASE-L `Results > Annotate`.
#
# ⚠ THIS FILE WAS THE 0457(b) VIEW-MENU SUITE UNTIL 2026-08-24, AND ITS SUBJECT
# WAS REVERSED, NOT REPAIRED. On 2026-08-22 the same user ruled that
# `annot_show` needed a stock affordance and put a checkbutton pair in
# `View > Show / Hide` (issue 0457(b)); rows A1-A19 of this file pinned those
# two entries, their labels, their -postcommand and the two procs behind them.
# On 2026-08-24, driving the shipped feature on a real sky130 bench, the same
# user reversed that placement, verbatim:
#
#   "What is View > Show? We want to be like Cadence. It needs to ONLY be in
#    ASE-L > Results > Annotate > Operating Point Info."
#   "results (including OP info) only make sense when there is a result loaded
#    - meaning an ASE-L is active, to which this schematic is 'bound'."
#
# 0457(b) answered the question it was asked; this is a change of destination.
# See doc/claude/issues/0682-*.md.
#
# ⚠ WHAT HAPPENED TO ROWS A1-A19, STATED OUT LOUD BECAUSE DELETING THEM QUIETLY
# IS THE DEFECT CLASS THIS PROJECT HAS SHIPPED BEFORE (a suite green over a
# control nobody can reach). They are REPLACED, and they are replaced in two
# different places:
#   * The DELETION half — the View pair is gone, its two procs are gone, its
#     -postcommand is gone, its derived vars are gone — is rows B1-B8 below.
#     Every one of them is a NEGATIVE claim, which is exactly why B9/B10 exist.
#   * The BEHAVIOURAL half — A10-A14/A18's PULL, PUSH, mask arithmetic and
#     off-ramp — moved WHOLE to tests/headless/test_ase_window.tcl rows
#     W1a1-W1a16, because the surface it belongs to is an ASE-L session window
#     and this file has no session. B9 asserts that owner exists; a run in which
#     B1-B8 pass and B9/B10 fail has deleted a control and built nothing.
#   * A19 (the two labels PARTITION the content classes, issue 0678) has NO
#     successor and that is a ratified consequence, not an oversight: decision
#     D9 keeps the user's own two label strings, `Operating Point info` and
#     `DC Node Voltages`, and Cadence's names do not partition by our classes.
#     Rule debt [0678] is MOOT under this ruling but only the USER may clear it.
#
# ⚠ THE THREE CHORDS ARE NOT TOUCHED. `6` / `Alt-6` / `Ctrl-6`
# (src/cadence_style_rc:317-319) were confirmed correct on a real bench (0678);
# they write the mask themselves via cadence::annot_mode (utils/annot_mode.tcl),
# never through the deleted procs, so nothing here can reach them.
#
# NEEDS A DISPLAY — the subject is Tk menu entries. Do NOT run under --nogui.
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --script \
#       tests/headless/test_annot_show_menu.tcl

if {[catch {winfo exists .}] || ![winfo exists .]} {
  puts "RESULT: SKIP (needs Tk/X; the subject is a menu)"
  flush stdout
  exit 0
}

# --- issue 0601: keep the editor's autosave "~" file out of the launch directory.
# This suite instances a resistor, and the first edit of the startup untitled
# buffer runs set_modify(1) -> write_backup() (src/actions.c:208 -> save.c:4149),
# which lands in the LAUNCH dir (a Tcl `cd` does not move it, issue 0323).
# Guarded by tests/headless/test_no_untitled_litter.tcl.
set ::saved_autosave_0601 $::autosave_backup
set ::autosave_backup 0

set fail 0
set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name ($got)" ; incr npass } \
  else { puts "FAIL: $name (got '$got' want '$want')" ; incr fail }
}

set M .menubar.view.show

## ⚠ A MISSING ENTRY MUST RED ONE ROW, NOT ABORT THE FILE. `$M type -1` raises
## `bad menu entry index "-1"`, and under --pipe that stops Tcl_AppInit dead:
## measured (0457(b) era), a single renamed label took one row out and every row
## after it never ran at all, so a one-word change read as a total collapse.
## These return markers instead, and the rows below name them in their goldens.
proc entry_index {m label} {
  if {![winfo exists $m]} { return -1 }
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[catch {$m entrycget $i -label} l]} { continue }
    if {$l eq $label} { return $i }
  }
  return -1
}
## The same lookup keyed on the -variable rather than the label. B2 needs it: a
## deletion claim must not depend on the deleted thing's LABEL to look for it,
## or a mere relabelling reads as a removal.
proc entry_index_var {m var} {
  if {![winfo exists $m]} { return -1 }
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[catch {$m entrycget $i -variable} v]} { continue }
    if {$v eq $var} { return $i }
  }
  return -1
}
## Every label in a menu and, recursively, in its cascades. B3 searches the
## WHOLE View tree, not just `Show / Hide`: "we moved it one submenu over" must
## not read as "we removed it".
proc menu_tree_labels {m} {
  set out {}
  if {![winfo exists $m]} { return $out }
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {![catch {$m entrycget $i -label} l]} { lappend out $l }
    if {![catch {$m entrycget $i -menu} sub] && $sub ne {} && [winfo exists $sub]} {
      foreach s [menu_tree_labels $sub] { lappend out $s }
    }
  }
  return $out
}
## Count the lines of <path> matching <re>; -1 when the file is absent, so a
## missing file reds one row instead of raising out of the file.
proc src_grep {path re} {
  if {![file isfile $path]} { return -1 }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set n 0
  foreach l [split $d \n] { if {[regexp -- $re $l]} { incr n } }
  return $n
}
proc src_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  return $d
}
## The source text of ONE proc: from its `proc <name> {` header (column 0) up to
## the next such header, or end of file. {} when the proc is absent.
##
## ⚠ THIS EXISTS BECAUSE `.` MATCHES A NEWLINE IN TCL REGEXP. Row B10 used to
## read `[regexp {proc ase::ui::annot_apply \{.*?xschem set annot_show} $S_ASE]`
## and its own comment claimed that anchoring made a no-op shim unsatisfiable.
## MEASURED 2026-08-25 (issue 0682 sabotage variant S1) that claim was FALSE: with
## a live `proc ase::ui::annot_apply {key which} {}` shim above a renamed
## `..._real` body, the `.*?` spans the newline from the shim's header into the
## real body and the row stayed GREEN over a completely dead control -- the exact
## hollow-guard failure this file exists to prevent. SLICE FIRST, THEN MATCH.
proc proc_src {src name} {
  set s "\n$src"
  set i [string first "\nproc $name \{" $s]
  if {$i < 0} { return {} }
  set rest [string range $s [expr {$i + 1}] end]
  set j [string first "\nproc " $rest]
  if {$j < 0} { return $rest }
  return [string range $rest 0 $j]
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set F_XS  [file join $REPO src xschem.tcl]
set F_ASE [file join $REPO src ase_window.tcl]
set S_XS  [src_slurp $F_XS]
set S_ASE [src_slurp $F_ASE]

# ======================================================================== B ==
# THE DELETION. Every row here is a NEGATIVE claim; B9/B10 are the positive
# counterweight and must be read together with them.
# ============================================================================

# ⚠ THE OVER-DELETION GUARD, AND IT IS GREEN BEFORE THE CHANGE ON PURPOSE.
# `View > Show / Hide` is a real submenu with real unrelated entries
# (`Show hidden texts` among them, src/xschem.tcl). Only the two annotation
# checkbuttons and the -postcommand they needed come out; a diff that took the
# whole submenu with them would satisfy B2-B5 perfectly.
check "B1 the View>Show/Hide submenu survives, with its unrelated entries" \
      [list [winfo exists $M] [expr {[entry_index $M "Show hidden texts"] >= 0}]] \
      {1 1}

check "B2 no View>Show entry is wired to the mask's derived vars (searched BY -variable)" \
      [list [entry_index_var $M annot_show_op] [entry_index_var $M annot_show_voltage]] \
      {-1 -1}

# The third element is the anti-hollow half: a walk that returned nothing would
# make the two 0s meaningless.
set vlabels [menu_tree_labels .menubar.view]
check "B3 neither annotation label survives anywhere in the WHOLE View menu tree" \
      [list [expr {[lsearch -exact $vlabels {Show device OP / branch current annotation}] >= 0}] \
            [expr {[lsearch -exact $vlabels {Show node voltage annotation}] >= 0}] \
            [expr {[llength $vlabels] > 5}]] \
      {0 0 1}

# The two procs existed ONLY to serve the View pair — measured, exactly three
# call sites in src/, all of them that pair (the -postcommand and the two
# -commands). The chords call `xschem set annot_show` themselves.
check "B4 the View pair's two procs are gone" \
      [list [llength [info procs annot_show_menu_sync]] \
            [llength [info procs annot_show_menu_apply]]] \
      {0 0}

check "B5 the View>Show submenu no longer carries the pair's -postcommand" \
      [string match {*annot_show_menu_sync*} [$M cget -postcommand]] 0

# ---------------------------------------------------------- source contract --
# ⚠ A RUNTIME ROW CANNOT SEE A DELETION THAT LEFT DEAD CODE BEHIND. B4/B5 pass
# over a proc that is defined but never reached; these greps do not.
check "B6 src/xschem.tcl keeps exactly the two Op-Annotate writers of the mask" \
      [list [src_grep $F_XS {xschem set annot_show}] \
            [regexp {Op Annotate.*?xschem set annot_show 3} $S_XS] \
            [regexp {Annotate Operating Point into schematic.*?xschem set annot_show 3} $S_XS]] \
      {2 1 1}

check "B7 the derived vars annot_show_op / annot_show_voltage are gone from src/xschem.tcl" \
      [list [src_grep $F_XS {annot_show_op}] [src_grep $F_XS {annot_show_voltage}]] \
      {0 0}

# S7 decision D4: writing the mask must go THROUGH `xschem set`; a bare
# `set ::annot_show N` leaves the C field stale until the next bulk sync
# (measured: `xschem get` still read 3 after `set ::annot_show 0`, until one
# `xschem update_all_sym_bboxes`). Kept on BOTH files now that the writer moved.
check "B8 no bare 'set ::annot_show <int>' in either file" \
      [list [src_grep $F_XS {^\s*set\s+::annot_show\s+[0-9]}] \
            [src_grep $F_ASE {^\s*set\s+::annot_show\s+[0-9]}]] \
      {0 0}

# ======================================================================== B ==
# THE REPLACEMENT EXISTS. Without these two rows, deleting the View pair and
# building NOTHING passes B1-B8 with full marks — which is precisely the
# failure this project has shipped before.
# ============================================================================

# The behavioural owner is tests/headless/test_ase_window.tcl rows W1a1-W1a17:
# they open a real ASE-L session window and drive the DESIGN context's mask
# through the two `Results > Annotate` entries. This row only asserts that the
# three named seams exist, so a green run here can never be mistaken for
# evidence that the control works.
check "B9 the ASE-L replacement's three seams are defined (behaviour: test_ase_window W1a)" \
      [list [llength [info procs ase::has_results]] \
            [llength [info procs ase::ui::annot_apply]] \
            [llength [info procs ase::ui::annot_menu_sync]]] \
      {1 1 1}

# ⚠ SLICED, NOT ANCHORED -- and the difference was measured, not reasoned about.
# The sabotage protocol for this crew neutralises a callee by renaming it to
# `..._real` and leaving a live no-op shim. The earlier form of this row used one
# regexp anchored on `proc ase::ui::annot_apply \{` with a `.*?` reaching for the
# writer, and because `.` matches a NEWLINE in Tcl that `.*?` walked straight out
# of the shim and into the `_real` body: the row passed with the control fully
# dead (0682 variant S1). proc_src now cuts the proc's OWN body out first, so the
# second element can only be satisfied by a writer inside the shipped proc.
check "B10 src/ase_window.tcl carries exactly one mask writer, inside ase::ui::annot_apply" \
      [list [src_grep $F_ASE {xschem set annot_show}] \
            [regexp {xschem set annot_show} [proc_src $S_ASE ase::ui::annot_apply]]] \
      {1 1}


# ======================================================================== C ==
# ISSUE 0683, THE RULING — BOTH STOCK ITEMS REFUSE WITHOUT A BOUND SESSION,
# AND THE REFUSAL IS PROVED TO HAVE REACHED A SINK.
# ============================================================================
# The user ruled on 2026-08-25, verbatim:
#
#   "Refuse without a bound session. Both stock items check for a live bound
#    session and refuse with a clear message naming the ASE-L path if there is
#    none."
#
# The trade was stated in the question and accepted: stock xschem with no ASE-L
# can no longer annotate at all. TWO ALTERNATIVES WERE EXPLICITLY REJECTED —
# making the two items TOGGLE, and DELETING them — and C1 pins both rejections,
# because "greyed out" and "gone" are the two shapes a hurried fix reaches for.
#
# ⚠ THE REFUSAL MESSAGE IS THE RISKIEST PART OF THIS ITEM, NOT ITS POLISH. The
# channel it goes through has open defects (0674, 0675, 0677, 0699, 0800), and
# 0675 is exactly the hazard: a channel can pass its OWN liveness test and reach
# nobody. A refusal nobody sees is WORSE than the bug being fixed — the menu item
# then does nothing at all, with no explanation.
#
# MEASURED ON THIS TREE, 2026-08-25, and it is why C5 is written the way it is:
# under `--pipe -q --nolog` on :99, with `winfo exists .ciw` = 0 and
# `xschem get actionlog_filename` = {}, a notify still records
# `sinks {ciw statusbar}` and STILL RETURNS 1. Both witnesses lie. The only
# honest question is "did the text land in something a person can read", so
# every row below reads WIDGET TEXT and FILE BYTES:
#
#   sink 1  .ciw.l.t                            (exists under `--pipe -q`)
#   sink 3  [xschem get top_path].statusbar.12   (the --nolog arm's only sink)
#   sink 2  [xschem get actionlog_filename]      (exists under --logdir)
#
# ⚠ `[xschem get top_path]`, NEVER `xschem get topwindow` — the latter answers
# "." and builds `..statusbar.12`, which does not exist (src/ciw.tcl:132).
#
# ⚠ THE MARKER IS `ASE-L`, AND THAT IS A CONTRACT ON THE MESSAGE, NOT A TEST
# CONVENIENCE. In the shipped `--nolog` arm the ONLY sink is `.statusbar.12`,
# which receives the 28-character SHORT form (xschem::notify_short) and never the
# rendered sentence. So a refusal whose short form does not name ASE-L reaches
# the user as an unexplained blank, which is the state the ruling exists to
# prevent. Both the long line and the short form must carry it.
#
#   C0  a live sink exists in THIS process          <- green before (precondition)
#   C1  both entries still exist, both still normal <- green before (the two
#                                                      rejected options)
#   C2  the labels are ONE source, read off the widgets  <- red before
#   C3  the guard is FIRST in each -command body    <- red before
#   C4  the refusal: mask untouched, no file dialog <- red before
#   C4b the refusal touches no loaded raw           <- red before
#   C5  THE REFUSAL REACHED A SINK                  <- red before
#   C6  the remedy is DERIVED from the live labels  <- red before
#   C7  the printed remedy EXECUTES                 <- red before
#   C8  POSITIVE: with a session the item still works <- green before
#   C9  the OTHER entry names its OWN path          <- red before
# ============================================================================

set C_HERE [file normalize [file dirname [info script]]]
source [file join $C_HERE scratch.tcl]
set C_SCRATCH [test_scratch annot_show_menu]

## --- fixture: one registered lib, one cell, one annotator, one op raw --------
file mkdir [file join $C_SCRATCH annotlib]
set f [open [file join $C_SCRATCH annotlib c_probe.sym] w]
puts $f "v {xschem version=3.4.7RC file_version=1.2}"
puts $f "G {}"
puts $f "K \{type=zzs7probe\ntemplate=\"name=zp1\"\}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "L 4 0 0 0 10 {}"
puts $f "T \{ZZC0683TEXT\} 5 5 0 0 0.2 0.2 \{layer=15\nhide=op\}"
close $f
file mkdir [file join $C_SCRATCH aselib c_dut schematic]
set f [open [file join $C_SCRATCH aselib c_dut schematic c_dut.sch] w]
puts $f "v {xschem version=3.4.7RC file_version=1.2}"
puts $f "G {}"
puts $f "K {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "N 250 -330 420 -330 {}"
puts $f "C \{annotlib/c_probe\} 0 0 0 0 \{name=CD1\}"
puts $f "C \{devices/lab_wire\} 330 -330 0 0 \{name=la lab=a\}"
close $f
set f [open [file join $C_SCRATCH library.defs] w]
puts $f "DEFINE aselib [file join $C_SCRATCH aselib]"
puts $f "DEFINE annotlib [file join $C_SCRATCH annotlib]"
puts $f "DEFINE devices [file join $REPO xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $C_SCRATCH library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
set C_DUT [file normalize [file join $C_SCRATCH aselib c_dut schematic c_dut.sch]]
set C_RAW [file join $C_SCRATCH c_op.raw]
set f [open $C_RAW w]
puts -nonewline $f "Title: 0683 refusal fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(a)\tvoltage
\t1\tv(gnd)\tvoltage
Values:
0\t3.14
\t0.0
"
close $f

## --- the three readable sinks, read as TEXT and BYTES, never as `sinks` ------
proc c_ciw_text {} {
  if {[winfo exists .ciw.l.t]} { return [.ciw.l.t get 1.0 end] }
  return {}
}
proc c_sb_path {} {
  if {[catch {xschem get top_path} tp]} { return {} }
  return "$tp.statusbar.12"
}
proc c_sb_text {} {
  set w [c_sb_path]
  if {$w eq {} || ![winfo exists $w]} { return {} }
  if {[catch {$w cget -text} t]} { return {} }
  return $t
}
proc c_log_path {} {
  if {[catch {xschem get actionlog_filename} p]} { return {} }
  return $p
}
proc c_log_text {{from 0}} {
  set p [c_log_path]
  if {$p eq {} || ![file isfile $p]} { return {} }
  set fd [open $p r] ; seek $fd $from ; set d [read $fd] ; close $fd
  return $d
}
proc c_log_size {} {
  set p [c_log_path]
  if {$p eq {} || ![file isfile $p]} { return 0 }
  return [file size $p]
}
## Which of the three sinks EXIST in this process.
proc c_live_sinks {} {
  set out {}
  if {[winfo exists .ciw.l.t]} { lappend out ciw }
  set w [c_sb_path] ; if {$w ne {} && [winfo exists $w]} { lappend out statusbar }
  if {[c_log_path] ne {}} { lappend out log }
  return $out
}
## How many of the three currently HOLD <needle> anywhere.
proc c_sinks_holding {needle} {
  set n 0
  if {[string first $needle [c_ciw_text]] >= 0} { incr n }
  if {[string first $needle [c_sb_text]]  >= 0} { incr n }
  if {[string first $needle [c_log_text]] >= 0} { incr n }
  return $n
}

## A live menu entry's -label / -command, or a self-naming marker.
proc c_lbl {m idx} {
  if {![winfo exists $m] || $idx < 0} { return NO-ENTRY }
  if {[catch {$m entrycget $idx -label} l]} { return NO-LABEL }
  return $l
}
proc c_cmd {m idx} {
  if {![winfo exists $m] || $idx < 0} { return {} }
  if {[catch {$m entrycget $idx -command} c]} { return {} }
  return $c
}
## Call a zero-argument label proc, or answer a marker if it is not defined.
## ⚠ NEVER `catch {...} r` around an undefined proc name and then compare — an
## `invalid command name` message would be the value compared, and any golden
## that happened to be empty would pass. The marker is distinctive.
proc c_proc {name} {
  if {[llength [info procs $name]] == 0 && [llength [info procs ::$name]] == 0} {
    return NO-PROC:$name
  }
  if {[catch {uplevel #0 [list $name]} r]} { return RAISED:$name }
  return $r
}
proc c_notify_field {f} {
  if {![info exists ::xschem::notify_last]} { return NO-RECORD }
  if {[catch {dict get $::xschem::notify_last $f} v]} { return NO-FIELD }
  return $v
}

set C_MW  .menubar.waves
set C_MG  .menubar.simulation.graph
set C_MT  .menubar.tools
set C_IW  [entry_index $C_MW {Op Annotate}]
set C_IG  [entry_index $C_MG {Annotate Operating Point into schematic}]
set C_IT  [entry_index $C_MT {Launch ASE-L}]
set C_ITOP_TOOLS [entry_index .menubar {Tools}]
set C_ITOP_WAVES [entry_index .menubar {Waves}]
set C_ITOP_SIM   [entry_index .menubar {Simulation}]
set C_IGRAPHS    [entry_index .menubar.simulation {Graphs}]

# --- C0: this process HAS a sink. One self-naming red beats three mysterious --
# Without it, a run launched with `--nolog` and no CIW would fail C5 for a reason
# that has nothing to do with the refusal.
puts "C0 live sinks in this process: {[c_live_sinks]} (log: {[c_log_path]})"
check "C0 PRECONDITION at least one notify sink is live in this process" \
  [expr {[llength [c_live_sinks]] > 0 ? 1 : 0}] 1

# --- C1: the two REJECTED options, pinned -----------------------------------
# TOGGLE was rejected (it would put a second working annotation control outside
# ASE-L, a partial retreat from 0682) and DELETION was rejected (the refusal
# message is more useful than a missing menu, because it says where the function
# went). So both entries must still EXIST, must still be plain `command` entries
# rather than checkbuttons, and must still be -state normal: greying them out is
# the deletion the user turned down, wearing a different hat.
check "C1 both stock entries still exist, still plain commands, still enabled" \
  [list [expr {$C_IW >= 0 ? 1 : 0}] [$C_MW type $C_IW] [$C_MW entrycget $C_IW -state] \
        [expr {$C_IG >= 0 ? 1 : 0}] [$C_MG type $C_IG] [$C_MG entrycget $C_IG -state]] \
  {1 command normal 1 command normal}

# --- C2: R-0653-d req 2 — the labels are ONE source --------------------------
# ⚠ BOTH HALVES ARE NEEDED, AND test_ase_window W1t IS THE PRECEDENT. The
# LITERAL half catches a constant that was renamed out from under the menu; the
# CONSTANT half catches prose hardcoded in the refusal that has drifted from the
# widget. A constant compared against a constant is a tautology and would pass
# over both. Issue 0661 is the standing example of exactly that drift, one word
# apart and still plausible.
check "C2 the three labels the refusal names are read off the REAL widgets and match the constants" \
  [list [c_lbl $C_MW $C_IW] [expr {[c_proc annot_lbl_op_annotate] eq [c_lbl $C_MW $C_IW] ? 1 : 0}] \
        [c_lbl $C_MG $C_IG] [expr {[c_proc annot_lbl_annotate_op] eq [c_lbl $C_MG $C_IG] ? 1 : 0}] \
        [c_lbl $C_MT $C_IT] [expr {[c_proc annot_lbl_launch_ase] eq [c_lbl $C_MT $C_IT] ? 1 : 0}]] \
  {{Op Annotate} 1 {Annotate Operating Point into schematic} 1 {Launch ASE-L} 1}

# --- C3: the guard is the FIRST statement of each body -----------------------
# ⚠ READ OFF THE LIVE `-command` SCRIPT, so it is slice-proof by construction:
# there is no whole-file `.*?` to walk out of one proc and into another (the
# failure that kept N22b and B10 green over dead code — `.` matches a newline in
# Tcl). Position matters as much as presence: `select_raw` is a MODAL
# tk_getOpenFile (src/xschem.tcl:14518) and it also rewrites the global
# `netlist_dir` merely by being read, so a refused user must never reach it
# (issue 0683 §7).
proc c_guard_first {cmd} {
  set g [string first {ase::annot_binding_ok} $cmd]
  set s [string first {select_raw} $cmd]
  set m [string first {xschem set annot_show} $cmd]
  if {$g < 0} { return 0 }
  if {$s >= 0 && $g > $s} { return 0 }
  if {$m >= 0 && $g > $m} { return 0 }
  return 1
}
set C_CW [c_cmd $C_MW $C_IW]
set C_CG [c_cmd $C_MG $C_IG]
check "C3 both bodies call the binding guard, and call it BEFORE select_raw and the mask write" \
  [list [expr {[string first {ase::annot_binding_ok} $C_CW] >= 0 ? 1 : 0}] [c_guard_first $C_CW] \
        [expr {[string first {ase::annot_binding_ok} $C_CG] >= 0 ? 1 : 0}] [c_guard_first $C_CG]] \
  {1 1 1 1}

# --- the select_raw counting stub -------------------------------------------
# ⚠ NOT OPTIONAL PLUMBING. `select_raw` is modal under X; invoking either entry
# with no guard and no stub HANGS the suite (issue 0803's class). It is also the
# measurement: a call count of 0 is the positive proof the guard sits above it.
set ::c_sel_calls 0
set ::c_sel_ret $C_RAW
if {[llength [info procs select_raw]]} { rename select_raw c_real_select_raw }
proc select_raw {args} { incr ::c_sel_calls ; return $::c_sel_ret }

foreach _ck [dict keys [set ::ase::sessions]] {
  catch {ase::ui::close $_ck} ; catch {ase::session_close $_ck}
}
xschem load $C_DUT
update

# --- C4: THE REFUSAL --------------------------------------------------------
catch {xschem set annot_show 0}
catch {xschem raw clear}
set ::c_sel_calls 0
catch {$C_MW invoke $C_IW}
update
check "C4 with no session, Waves > Op Annotate changes nothing and never opens the file dialog" \
  [list [dict size [set ::ase::sessions]] [xschem get annot_show] \
        $::c_sel_calls [op_annot::_annotated]] \
  {0 0 0 0}

# --- C4b: the refusal must not disturb a database the user already has -------
# ⚠ `op_annot::_annotated` IS NOT AN ELEMENT HERE, and that is a correction to
# the plan rather than an omission: measured, it reads `xschem raw loaded` and
# `xschem raw annot` and NEVER the mask, so with a raw deliberately attached it
# answers 1 whatever the refusal did. The honest claim is that the attached
# values are untouched. (Before issue 0864 it read the Live-annotate switch as a
# third term; that is gone, and Section D below is what pins its absence.)
catch {xschem annotate_op $C_RAW}
set c4b_v0 [expr {[catch {xschem raw value v(a) -1} _r] ? "RAISED" : $_r}]
set c4b_l0 [expr {[catch {xschem raw loaded} _r] ? "RAISED" : $_r}]
catch {xschem set annot_show 0}
set ::c_sel_calls 0
catch {$C_MW invoke $C_IW}
update
check "C4b the refusal touches no loaded waveform database" \
  [list [xschem get annot_show] $::c_sel_calls $c4b_v0 $c4b_l0 \
        [expr {[catch {xschem raw value v(a) -1} _r] ? "RAISED" : $_r}] \
        [expr {[catch {xschem raw loaded} _r] ? "RAISED" : $_r}]] \
  {0 0 3.14 0 3.14 0}

# --- C5: THE REFUSAL REACHED A SINK -----------------------------------------
# ⚠ NEVER `dict get $::xschem::notify_last sinks` AND NEVER notify's RETURN.
# Both were measured lying on this exact tree, in a process with no CIW and no
# log file: `sinks` read {ciw statusbar} and the return was 1. This row reads the
# widget text and the file bytes, asserts the marker was NOT already present
# anywhere (so a leftover cannot make the after-check vacuous), and then asserts
# at least one sink GREW to contain it.
## ⚠ THE BEFORE-CHECK IS SCOPED TO THE REGION PAST THE SNAPSHOT, AND THAT IS A
## CORRECTION MADE WHEN THE ROW FIRST WENT GREEN, NOT A WEAKENING. The row as
## first written asked `c_sinks_holding` over the WHOLE accumulated sink text.
## Two of the three sinks are APPEND-ONLY (the CIW pane and the durable log
## file), and C4 and C4b above have already refused -- visibly, which is the
## point of the whole section -- so that form reads 2 in a CORRECT build and 0
## only while the refusal is broken. It reddened for the exact opposite of the
## reason it was written. The teeth are in the SECOND element either way: the
## marker must appear in text that did not exist before the invoke.
catch {[c_sb_path] configure -text {}}
set c5_ciw0 [string length [c_ciw_text]]
set c5_log0 [c_log_size]
set c5_before 0
if {[string first {ASE-L} [string range [c_ciw_text] $c5_ciw0 end]] >= 0} { incr c5_before }
if {[string first {ASE-L} [c_sb_text]] >= 0}                             { incr c5_before }
if {[string first {ASE-L} [c_log_text $c5_log0]] >= 0}                   { incr c5_before }
catch {xschem set annot_show 0}
set ::c_sel_calls 0
catch {$C_MW invoke $C_IW}
update
set c5_new 0
if {[string first {ASE-L} [string range [c_ciw_text] $c5_ciw0 end]] >= 0} { incr c5_new }
if {[string first {ASE-L} [c_sb_text]] >= 0}                             { incr c5_new }
if {[string first {ASE-L} [c_log_text $c5_log0]] >= 0}                   { incr c5_new }
puts "C5 sinks that newly carry the marker: $c5_new of [llength [c_live_sinks]] live\
 (statusbar now {[c_sb_text]})"
check "C5 the refusal REACHED a readable sink — widget text and file bytes, never `sinks`" \
  [list $c5_before [expr {$c5_new >= 1 ? 1 : 0}]] {0 1}

# --- C6: the remedy is DERIVED, not prose -----------------------------------
# ⚠ COMPARED AGAINST THE LIVE WIDGET LABELS, NOT AGAINST annot_remedy_menu. A
# row that asked "does the printed path equal the proc that printed it" is a
# tautology and stays green while the menu is renamed underneath it — that is
# issue 0661's measured drift class. `>`-separated because that is the shipped
# convention (src/ase_window.tcl:3180, ase::ui::remedy_op_params_menu).
set C_REMEDY "[c_lbl .menubar $C_ITOP_TOOLS] > [c_lbl $C_MT $C_IT]"
set C_PATH_W "[c_lbl .menubar $C_ITOP_WAVES] > [c_lbl $C_MW $C_IW]"
set C_PATH_G "[c_lbl .menubar $C_ITOP_SIM] > [c_lbl .menubar.simulation $C_IGRAPHS] > [c_lbl $C_MG $C_IG]"
## Printed, not assumed: if the composition itself is wrong every row below reds
## for a reason that has nothing to do with the refusal.
puts "C6 composed from live widgets: remedy {$C_REMEDY} waves {$C_PATH_W} graphs {$C_PATH_G}"
check "C6 R-0653-d the remedy names the LIVE Tools > Launch ASE-L path and a pasteable command" \
  [list [expr {[c_notify_field menu] eq $C_REMEDY ? 1 : 0}] \
        [c_notify_field command] \
        [expr {[string first $C_PATH_W [c_notify_field line]] >= 0 ? 1 : 0}]] \
  [list 1 {ase::launch_for_current} 1]

# --- C7: R-0653-d req 1 — the printed command is EXECUTED, never compared ----
# `ciw_exec` runs `uplevel #0 $cmd` (src/ciw.tcl:598), so a printed remedy IS an
# executable contract. Issue 0679 is the precedent for what goes wrong when it is
# not run: a remedy naming a key the session was never registered under.
set c7_cmd [c_notify_field command]
set c7_rc  [catch {uplevel #0 $c7_cmd} c7_res]
update
check "C7 the remedy the user is told to paste actually creates the bound session" \
  [list $c7_rc [dict size [set ::ase::sessions]] \
        [expr {[ase::session_for_current] ne {} ? 1 : 0}]] \
  {0 1 1}

# --- C8: THE POSITIVE TWIN ---------------------------------------------------
# A suite that only asserts refusal has not tested this. C4/C4b/C5/C6/C9 are all
# negative claims and a patch that simply broke the menu item satisfies every one
# of them.
catch {xschem set annot_show 0}
catch {xschem raw clear}
set ::c_sel_calls 0
catch {$C_MW invoke $C_IW}
update
check "C8 POSITIVE with the session live the entry works exactly as it always did" \
  [list $::c_sel_calls [xschem get annot_show] \
        [expr {[catch {xschem raw value v(a) -1} _r] ? "RAISED" : $_r}] \
        [op_annot::_annotated]] \
  {1 3 3.14 1}

# --- C9: the OTHER entry names its OWN path ---------------------------------
# A copy-paste that passed the Waves path to the Graphs body would satisfy every
# row above. Both halves are asserted: the Graphs path present AND the Waves path
# absent.
## ⚠ `ase::session_for_current` RETURNS {key level lib cell view}, NOT A BARE
## KEY (src/ase.tcl:3022), and `ase::session_close` takes a key -- handed the
## list it fails `dict exists` and returns 0 with the session STILL ALIVE. The
## row as first written did exactly that and then measured the entry ANNOTATING
## (annot_show 3, select_raw called once), i.e. it reported a missing refusal
## that was actually a live session it had failed to close. Both closers get
## the key, and the teardown is asserted rather than assumed.
set c9_key [lindex [ase::session_for_current] 0]
catch {ase::ui::close $c9_key} ; catch {ase::session_close $c9_key}
update
check "C9a PRECONDITION the session really is gone before the Graphs entry is tried" \
  [list [dict size [set ::ase::sessions]] [ase::session_for_current]] {0 {}}
catch {xschem set annot_show 0}
catch {xschem raw clear}
set ::c_sel_calls 0
catch {$C_MG invoke $C_IG}
update
check "C9 Simulation > Graphs refuses too, and names its OWN menu path" \
  [list [xschem get annot_show] $::c_sel_calls \
        [expr {[string first $C_PATH_G [c_notify_field line]] >= 0 ? 1 : 0}] \
        [expr {[string first $C_PATH_W [c_notify_field line]] >= 0 ? 1 : 0}]] \
  {0 0 1 0}

# =============================================================================
# SECTION D — ISSUE 0864: `MUST ONLY HAPPEN WHEN USER REQUESTS IT!!`
# =============================================================================
# `Simulation > Graphs > Live annotate probes with 'b' cursor` is the switch the
# user unticks and finds ticked again after pressing `6`. 0864 splits what it
# means from what it was doing: it goes back to meaning ONLY "follow cursor B
# and re-annotate as it moves", it stops being a term of what `6` and `Alt-6`
# RENDER, and it ships off.
#
# ⚠ THIS FILE OWNS THE WIDGET. The headless suite (test_op_annot rows S16, O29,
# A64-1..A64-5) drives the Tcl variable directly, which is right for what it
# measures and is blind to the entry itself. Only here can a row click the thing
# the user clicks.
set D_MG  .menubar.simulation.graph
set D_IL  [entry_index_var $D_MG live_cursor2_backannotate]

# ⚠ THE FEATURE IS KEPT AND MADE OPT-IN, NOT REMOVED, and this row is what says
# so. Every other 0864 row is a negative claim — the switch is not a render
# gate, the force-set is gone, the default is off — and a build that simply
# deleted the checkbutton would satisfy all of them. It must still be there,
# still be a checkbutton, still carry the user's own label, and still write 1/0.
check "D1 Simulation > Graphs still carries the Live annotate checkbutton: the feature is kept, not removed" \
  [list [expr {$D_IL >= 0 ? 1 : 0}] \
        [expr {$D_IL >= 0 ? [$D_MG type $D_IL] : {NO-ENTRY}}] \
        [expr {$D_IL >= 0 ? [$D_MG entrycget $D_IL -label] : {NO-ENTRY}}] \
        [expr {$D_IL >= 0 ? [$D_MG entrycget $D_IL -onvalue] : {-}}] \
        [expr {$D_IL >= 0 ? [$D_MG entrycget $D_IL -offvalue] : {-}}]] \
  [list 1 checkbutton {Live annotate probes with 'b' cursor} 1 0]

# ⚠ SOURCE-ONLY, DELIBERATELY. Reading the live variable here would red on a
# developer whose own ~/.xschem/xschemrc sets it — true about their machine, not
# about the shipped tree — and after 0864 the default changes nothing that
# renders, so there is no behavioural observable to read at all. The value is
# matched as a whole word, not to end of line, so the shipped line may carry a
# trailing comment naming the issue.
check "D2 the box ships UNTICKED: live cursor annotation is opt-in" \
  [list [src_grep $F_XS {^set_ne live_cursor2_backannotate 0(\M|$)}] \
        [src_grep $F_XS {^set_ne live_cursor2_backannotate 1(\M|$)}]] \
  {1 0}

# ⚠ THE CLICK, NOT THE VARIABLE. With an operating point attached, ticking and
# unticking this entry must not change one character of what the schematic
# shows. Two things are read at each of the three points: the gate `6`'s device
# block is drawn through, and the `@spice_get_voltage` floater that `Alt-6`'s
# node voltages are drawn through — because A1 has to be done in BOTH languages
# and each of these two reads exactly one of them. `3.14` is the positive
# control: a build that rendered nothing ever would fail all three points.
#
# ⚠ `invoke` FLIPS THE VARIABLE AND RUNS THE ENTRY'S -command, of which there is
# none (filed separately). That is deliberate: the row must hold for the widget
# as SHIPPED, not for a repaired one.
proc d_floater {} {
  if {[catch {xschem translate la {@spice_get_voltage}} r]} { return RAISED }
  return $r
}
xschem load $C_DUT
update
catch {xschem annotate_op $C_RAW}
set d_lv $::live_cursor2_backannotate
set d3_0 [list [op_annot::_annotated] [d_floater]]
if {$D_IL >= 0} { catch {$D_MG invoke $D_IL} } ; update
set d3_1 [list [op_annot::_annotated] [d_floater]]
if {$D_IL >= 0} { catch {$D_MG invoke $D_IL} } ; update
set d3_2 [list [op_annot::_annotated] [d_floater]]
set ::live_cursor2_backannotate $d_lv
check "D3 CLICKING the checkbutton changes nothing the annotation shows" \
  [list $d3_0 $d3_1 $d3_2] [list {1 3.14} {1 3.14} {1 3.14}]
catch {xschem raw clear}

# =============================================================================
# SECTION E — ISSUE 0868: THE THIRD ANNOTATE ENTRY, AND THE ONE GUARD NO
#             HEADLESS ROW CAN SEE (the waveform viewer's active tab)
# =============================================================================
# The user's request, verbatim 2026-08-26:
#
#   "We can add a menu item in Results > Annotate for annotating TRAN node
#    voltages for time-point given by cursor B, or A - whatever the convention
#    is - if there is only one cursor in the waveform viewer's active tab, use
#    that. If A and B are there, then use cursor-A."
#
# ⚠ READ THE SUBJECT OF THE SENTENCE: "the waveform viewer's ACTIVE TAB". Not
# the schematic's own graph cursors. The mode must ask the VIEWER which cursors
# are on and where they sit, and only fall back to the current context's own
# graph cursors when there is no viewer -- which is the only case a headless row
# can construct at all. Rows V11-V13 of tests/headless/test_op_annot.tcl measure
# the fallback and the cursor RULE; they are blind to the borrow, by
# construction, because headless there is no viewer to borrow from. That is why
# B12 lives here and why this suite has to be run on the dev display before the
# item is called done.
#
#   B11   the submenu carries THREE entries      <- red before (measured: two)
#   B12f  FIXTURE: a viewer is open holding the run's raw -- and the DESIGN
#         window holds NOTHING -- with the two cursors at different times
#   B12   the mode annotates at the VIEWER's cursor, not the design context's
#   B12b  STRUCTURAL: the borrow enters and LEAVES the viewer's context
#   B12d  PRECONDITION for B12c: the design window is empty again
#   B12c  the ASE-L MENU ENTRY does it too -- acceptance row 2 of issue 0881
#
# ⚠ THE FIXTURE USED TO HAND-ATTACH, AND THAT IS WHY THE FEATURE SHIPPED BROKEN
# (item A10, issue 0881). B12f used to do `xschem annotate_op $E_TRAN` in the
# DESIGN window, which is a state the product never produces: the waveform
# viewer attaches the run's results to its OWN window's context
# (wviewer::attach_raw switches context first, by design), so on a real bench
# the design window holds nothing and the annotation refused with what was then
# spelled "Transient annotation -- NO RAW FILE loaded" (issue 0886 rewrote it to
# "No simulation results are loaded, so there are no voltages to show. Run a
# simulation first, then try again."). 29 checks here and 413 in
# tests/headless/test_op_annot.tcl were all green over a feature that had never
# once worked end to end. The fixture now supplies the raw the way the product
# does -- through `wviewer::attach_raw`, the same call the post-run auto-plot
# makes -- and asserts the design window is EMPTY as its own claim.
#
# ⚠ B12 IS BUILT SO THE TWO ANSWERS CANNOT ALIAS. The viewer's cursor A sits at
# 2 ns and the design context's cursor B sits at 4 ns, and the fixture raw's
# v(a) is exactly 2.0 and 4.0 there. A build that reads the current context
# answers 4; a build that borrows answers 2. Neither number can arrive by
# accident, and B12f is asserted separately so a fixture that failed to build
# reds as a fixture rather than as a verdict about the feature.
# ⚠ THE VIEWER MIRRORS ARE THE `cva` / `cvb` ARRAYS, KEYED BY TOKEN
# (src/wave_viewer.tcl:349-350). The tab stash keys every per-view array on the
# token, so reading them describes the ACTIVE TAB by construction -- there is no
# separate "which tab" question to get wrong.

set E_TRAN [file join $C_SCRATCH e_tran.raw]
set f [open $E_TRAN w]
puts -nonewline $f "Title: 0868 transient fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 5
Variables:
\t0\ttime\ttime
\t1\tv(a)\tvoltage
Values:
0\t0
\t0.0
1\t1e-09
\t1.0
2\t2e-09
\t2.0
3\t3e-09
\t3.0
4\t4e-09
\t4.0
"
close $f

## The design context's window path, taken from `xschem windows` (field 0 is the
## context path, field 4 the schematic) rather than assumed -- opening a viewer
## MOVES the current context, and every row below has to come back deliberately.
proc e_winpath {schpath} {
  foreach e [xschem windows] {
    if {[file normalize [lindex $e 4]] eq [file normalize $schpath]} { return [lindex $e 0] }
  }
  return {}
}
## Evaluate <script> with <win> current, then restore. A MARKER, never a raise:
## `xschem new_schematic switch` silently no-ops while a semaphore is up
## (wave_viewer.tcl landmine 17), and a blind read would then answer about the
## wrong context.
proc e_ctx {win script} {
  set cur [xschem get current_win_path]
  if {$cur ne $win} { catch {xschem new_schematic switch $win} ; update }
  if {[xschem get current_win_path] ne $win} { return "SWITCH-FAILED($win)" }
  if {[catch {uplevel 1 $script} r]} { set r "ERR: $r" }
  if {[xschem get current_win_path] ne $cur} { catch {xschem new_schematic switch $cur} ; update }
  return $r
}
## The source text of ONE proc, sliced out of <src> so a grep cannot run past
## the end of the body into the next one -- issue 0682's measured hole, where
## `.` matched a newline and a row stayed green over a renamed no-op shim.
proc e_proc_src {src name} {
  set s "\n$src"
  set i [string first "\nproc $name \{" $s]
  if {$i < 0} { return {} }
  set rest [string range $s [expr {$i + 1}] end]
  set j [string first "\nproc " $rest]
  if {$j < 0} { return $rest }
  return [string range $rest 0 $j]
}
proc e_slurp {p} {
  if {![file isfile $p]} { return {} }
  set fd [open $p r] ; set d [read $fd] ; close $fd ; return $d
}

xschem load $C_DUT
update
set E_DWIN [e_winpath $C_DUT]
catch {uplevel #0 {ase::launch_for_current}}
update
set E_KEY [lindex [ase::session_for_current] 0]
set E_AW {}
catch {set E_AW [ase::ui::window_for $E_KEY]}
set E_AM {}
if {$E_AW ne {}} { set E_AM $E_AW.mb.results.annotate }

# ---------------------------------------------------------------------------
# B11 — THE THREE ENTRIES, READ OFF THE REAL WIDGETS
# ---------------------------------------------------------------------------
# ⚠ OFF THE WIDGETS, NOT OUT OF THE SOURCE. Row C2's lesson: a label the source
# and the suite agree on is not a label the user sees. Measured on the real
# ASE-L menu 2026-08-27, this submenu carries exactly two entries.
# ⚠ ALL THREE MUST BE CHECKBUTTONS. `add command` cannot display state, and
# state is the entire content of a visibility control (decision D1, row W1a1 of
# tests/headless/test_ase_window.tcl).
set e_b11 {}
if {$E_AM ne {} && [winfo exists $E_AM]} {
  for {set i 0} {$i <= [$E_AM index end]} {incr i} {
    set t NO-TYPE ; set l NO-LABEL
    catch {set t [$E_AM type $i]} ; catch {set l [$E_AM entrycget $i -label]}
    lappend e_b11 [list $t $l]
  }
} else {
  set e_b11 NO-MENU
}
check "B11 the ASE-L Results > Annotate submenu carries THREE checkbuttons, and the third is the transient one" \
  $e_b11 \
  [list [list checkbutton {Operating Point info}] \
        [list checkbutton {DC Node Voltages}] \
        [list checkbutton {Transient Node Voltages (at cursor)}]]

# ---------------------------------------------------------------------------
# B12f — THE FIXTURE, ASSERTED SEPARATELY
# ---------------------------------------------------------------------------
# ⚠ WITHOUT THIS ROW B12 CANNOT BE READ. A viewer that never opened, a session
# key that never resolved or a raw that never attached all make B12 red for a
# reason that has nothing to do with the feature. Five claims: the viewer
# toplevel exists and its canvas is mapped; the viewer's own context is
# reachable; its cursor-A mirror says ON and its cursor-B mirror says OFF; the
# viewer's cursor A sits at 2 ns; and the DESIGN context has the transient
# attached with ITS OWN cursor B on at 4 ns.
set E_VOK 0
catch {wviewer::open $E_KEY}
update
set E_VT {}
catch {set E_VT [wviewer::window_for $E_KEY]}
for {set _i 0} {$_i < 200} {incr _i} {
  update
  if {$E_VT ne {} && [winfo exists $E_VT.drw] && [winfo ismapped $E_VT.drw]} { set E_VOK 1 ; break }
  after 20
}
set E_VW {}
if {$E_VT ne {}} { set E_VW $E_VT.drw }

## THE SESSION METADATA SEAM. Only two READERS are replaced -- which file this
## session's last run wrote, and whether that file still describes the deck --
## because nothing in a headless-launched session has actually run a simulator.
## They are METADATA: no database is attached by either of them, and the raw
## still reaches a context only through the product's own supply call below.
## Restored in the section E teardown.
set E_HAD_LRF [expr {[info commands ::ase::last_rawfile] ne {}}]
set E_HAD_RST [expr {[info commands ::ase::results_stale] ne {}}]
if {$E_HAD_LRF} { rename ::ase::last_rawfile  ::ase::_e_saved_lrf }
if {$E_HAD_RST} { rename ::ase::results_stale ::ase::_e_saved_rst }
proc ::ase::last_rawfile  {key} { return [expr {$key eq $::E_KEY ? $::E_TRAN : {}}] }
proc ::ase::results_stale {key} { return 0 }

## ⚠ THE SUPPLY GOES THROUGH THE PRODUCT, NOT THROUGH THE FIXTURE.
## `wviewer::attach_raw` is byte-for-byte the call `ase::ui::auto_plot` makes
## after a run (src/ase_window.tcl:4701); it switches to the VIEWER's context
## first -- "never clear a foreign ctx" -- and hands the file to
## `ase::attach_dbs`, which is what actually calls `xschem raw read`. So after
## this line the viewer's window holds the run's transient and the DESIGN
## window holds nothing, which is exactly the state the user reported.
set E_ATT 0
catch {set E_ATT [wviewer::attach_raw $E_KEY [ase::last_rawfile $E_KEY] tran]}
update
catch {xschem new_schematic switch $E_DWIN}
update

set ::wviewer::cva($E_KEY) 1
set ::wviewer::cvb($E_KEY) 0
e_ctx $E_VW {xschem cursor 1 1 ; xschem set cursor1_x 2e-9}
set e_vpos [e_ctx $E_VW {xschem get cursor1_x}]
set e_vraw [e_ctx $E_VW {list [xschem raw loaded] [xschem raw sim_type]}]
e_ctx $E_DWIN {
  catch {xschem raw clear}
  catch {xschem cursor 1 0}
  xschem cursor 2 1
  xschem set cursor2_x 4e-9
}
## ⚠ THE DESIGN WINDOW'S EMPTINESS IS AN ASSERTION, NOT AN ASSUMPTION. Element
## 2 of the list is `catch {xschem raw sim_type}`, which is 1 exactly when the
## accessor RAISES "No raw file loaded" -- the two reads
## `cadence::annot_tran` refuses on. A fixture that quietly left a database
## here would make B12 a verdict about nothing.
set e_dstate [e_ctx $E_DWIN {list [xschem raw loaded] [catch {xschem raw sim_type}] \
                                  [xschem get graph_flags] [xschem get cursor2_x]}]
check "B12f FIXTURE the run's raw reaches the VIEWER's window through wviewer::attach_raw, the DESIGN window holds NOTHING, and the two cursors sit at different times" \
  [list $E_VOK $E_ATT $e_vpos $::wviewer::cva($E_KEY) $::wviewer::cvb($E_KEY) $e_vraw $e_dstate] \
  [list 1 1 2e-09 1 0 {0 tran} {-1 1 4 4e-09}]

# ---------------------------------------------------------------------------
# B12 — GUARD G8: THE MODE READS THE VIEWER'S CURSOR, NOT THE SHEET'S
# ---------------------------------------------------------------------------
# ⚠ THE ONLY ROW IN THE TREE THAT CAN SEE THIS GUARD. A build that resolves the
# cursor from the CURRENT context answers 4e-09 / v(a) 4 here and passes every
# row of tests/headless/test_op_annot.tcl section V, because headless there is
# no viewer and the fallback IS the answer.
# ⚠ AND IT MUST COME BACK. The borrow enters the viewer's context to read; a
# borrow that forgets to leave strands the user in the waveform window's context
# with the schematic still on screen (issue 0173's shape). The fourth element is
# that claim.
# ⚠ SAME GOLDEN, ENTIRELY DIFFERENT CLAIM SINCE ITEM A10. B12f no longer hands
# the design window a database, so reaching `ok` at all now requires the mode to
# go and GET the run's results -- this row is acceptance row 1 of issue 0881 as
# well as guard G8. Measured before the fix it answers `noraw` and annotates
# nothing, which is the user's own bench report.
set e_before [xschem get current_win_path]
set e_state [e_ctx $E_DWIN {cadence::annot_tran}]
set e_annot [e_ctx $E_DWIN {xschem raw annot}]
set e_val   [e_ctx $E_DWIN {xschem raw value v(a) -1}]
check "B12 guard G8 the mode annotates at the VIEWER's cursor A (2 ns), not the design context's cursor B (4 ns), and comes back" \
  [list $e_state [lindex $e_annot 1] $e_val \
        [expr {[xschem get current_win_path] eq $e_before ? 1 : 0}]] \
  {ok 2e-09 2 1}

# ---------------------------------------------------------------------------
# B12b — STRUCTURAL: THE BORROW IS THE SHIPPED ONE, AND THE LEAVE IS
#        UNCONDITIONAL
# ---------------------------------------------------------------------------
# ⚠ B12 CAN PASS OVER A BORROW THAT NEVER LETS GO IN THE ERROR PATH. `enter_ctx`
# takes a ticket that `leave_ctx` gives back (wave_viewer.tcl:1622/1693), and
# `wviewer::readout_refresh` (:14498) is the shipped caller to copy. A body that
# entered, threw, and never left would leave the ticket outstanding and the
# current context wrong for everything after it -- and B12's own fourth element
# only measures the SUCCESS path.
# ⚠ WHOLE-LINE COMMENTS STRIPPED, so the explanatory paragraph that names these
# two procs is not counted as an implementation of them.
set E_SRC [e_slurp [file join $REPO utils annot_mode.tcl]]
set E_CUR [e_proc_src $E_SRC cadence::_annot_tran_cursor]
set e_enter 0 ; set e_leave 0 ; set e_fin 0
foreach _l [split $E_CUR \n] {
  if {[regexp {^\s*#} $_l]} continue
  if {[regexp {wviewer::enter_ctx} $_l]} { incr e_enter }
  if {[regexp {wviewer::leave_ctx} $_l]} { incr e_leave }
  if {[regexp {\mfinally\M|\mcatch\M} $_l]} { incr e_fin }
}
check "B12b the cursor resolver borrows the viewer's context through enter_ctx and ALWAYS gives it back" \
  [list [expr {[string length $E_CUR] > 0 ? 1 : 0}] \
        [expr {$e_enter >= 1 ? 1 : 0}] \
        [expr {$e_leave >= 1 ? 1 : 0}] \
        [expr {$e_fin >= 1 ? 1 : 0}]] \
  {1 1 1 1}

# ---------------------------------------------------------------------------
# B12d — B12c's PRECONDITION, ASSERTED ON ITS OWN
# ---------------------------------------------------------------------------
# ⚠ WITHOUT THIS ROW B12c PASSES ON B12's LEFTOVERS. B12 has just attached a
# database to the design window and armed bit2; if the menu entry were then
# pressed over that state it would be measuring nothing. So the design window is
# emptied and the mask cleared, while the VIEWER keeps holding the run's raw and
# its cursor A stays at 2 ns -- the same bench state B12f built, restored.
e_ctx $E_DWIN {catch {xschem raw clear} ; catch {xschem set annot_show 0}}
e_ctx $E_VW {xschem cursor 1 1 ; xschem set cursor1_x 2e-9}
set ::wviewer::cva($E_KEY) 1
set ::wviewer::cvb($E_KEY) 0
set e_d_pre [e_ctx $E_DWIN {list [xschem raw loaded] [xschem get annot_show]}]
set e_v_pre [e_ctx $E_VW   {list [xschem raw loaded] [xschem raw sim_type]}]
check "B12d PRECONDITION the design window is empty again with no bit armed, and the viewer still holds the run's transient" \
  [list $e_d_pre $e_v_pre] [list {-1 0} {0 tran}]

# ---------------------------------------------------------------------------
# B12c — ACCEPTANCE ROW 2 OF ISSUE 0881: THE MENU DOOR
# ---------------------------------------------------------------------------
# ⚠ THE USER NAMED BOTH DOORS: "I do a TRAN run and then Alt-Shift-6 and
# Results > Annotate > Transient Node.. don't annotate anything onto the
# schematic". B12 is the chord's door; this is the menu's. They share one body,
# so a fix could only break them apart by accident -- but "could only" is how
# the original defect got here, and the menu carries one thing the chord does
# not: the tick.
# ⚠ THE TICK IS THE PASS/FAIL, NOT DECORATION. Tk has already flipped the
# variable by the time the -command body runs, and `annot_menu_sync` reads the
# mask back and SNAPS THE TICK OFF again on a refusal. So a still-ticked box
# after the press is a second, independent reading of "the mask really gained
# bit2", taken through the widget the user is looking at.
set ::ase::ui::annot($E_KEY,tran) 1
catch {ase::ui::annot_apply $E_KEY tran}
update
set e_c_mask  [e_ctx $E_DWIN {xschem get annot_show}]
set e_c_annot [e_ctx $E_DWIN {xschem raw annot}]
set e_c_tick  $::ase::ui::annot($E_KEY,tran)
check "B12c ACCEPTANCE Results > Annotate > Transient Node Voltages annotates at the viewer's cursor, arms bit2 and leaves the entry TICKED" \
  [list [expr {[string is integer -strict $e_c_mask] && ($e_c_mask & 4) ? 1 : 0}] \
        $e_c_tick [lindex $e_c_annot 1]] \
  [list 1 1 2e-09]

# ---------------------------------------------------------------------------
# B12g — ACCEPTANCE ROW 3 OF ISSUE 0881: *WHICH* RESULTS FILE
# ---------------------------------------------------------------------------
# ⚠ B12 AND B12c CANNOT TELL THE FIX FROM ITS NEAR-MISS, AND THIS ROW CAN.
# In their fixture the file the viewer is showing and the file the session
# metadata names are the SAME file, so a build that never looks at the viewer
# at all -- one that just rebuilds a path and reads it off disk -- passes both.
# The first A10 build was exactly that build, and a verifier proved it by
# deleting the viewer attach from this fixture and watching B12 and B12c stay
# green.
# ⚠ SO THIS ROW MAKES THE TWO DISAGREE. The waveform viewer keeps holding the
# run's results, where v(a) is 2 V at the 2 ns cursor. The session metadata is
# repointed at a DIFFERENT results file, where v(a) at 2 ns is 20 V. The user's
# ruling decides which one wins, verbatim: "The info should already be
# available - it's been loaded to display waveforms in the waveform viewer."
# Four claims: the press succeeded; the number is the VIEWER's 2 V and not the
# other file's 20 V; the database now attached to the design window is the
# viewer's file BY NAME; and the mask gained the transient bit.
set E_DECOY [file join $C_SCRATCH e_decoy.raw]
set f [open $E_DECOY w]
puts -nonewline $f "Title: 0881 decoy, a DIFFERENT run
Date: Mon Jan 1 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 5
Variables:
\t0\ttime\ttime
\t1\tv(a)\tvoltage
Values:
0\t0
\t0.0
1\t1e-09
\t10.0
2\t2e-09
\t20.0
3\t3e-09
\t30.0
4\t4e-09
\t40.0
"
close $f
e_ctx $E_DWIN {catch {xschem raw clear} ; catch {xschem set annot_show 0}}
e_ctx $E_VW {xschem cursor 1 1 ; xschem set cursor1_x 2e-9}
set ::wviewer::cva($E_KEY) 1
set ::wviewer::cvb($E_KEY) 0
catch {rename ::ase::last_rawfile {}}
proc ::ase::last_rawfile {key} { return [expr {$key eq $::E_KEY ? $::E_DECOY : {}}] }
set e_g_pre   [e_ctx $E_DWIN {list [xschem raw loaded] [xschem get annot_show]}]
set e_g_state [e_ctx $E_DWIN {cadence::annot_tran}]
set e_g_val   [e_ctx $E_DWIN {xschem raw value v(a) -1}]
set e_g_rf    [e_ctx $E_DWIN {xschem raw rawfile}]
set e_g_mask  [e_ctx $E_DWIN {xschem get annot_show}]
catch {rename ::ase::last_rawfile {}}
proc ::ase::last_rawfile  {key} { return [expr {$key eq $::E_KEY ? $::E_TRAN : {}}] }
check "B12g ACCEPTANCE the results file the WAVEFORM VIEWER is showing is the one annotated, even when the session metadata names a different file" \
  [list $e_g_pre $e_g_state $e_g_val [expr {$e_g_rf eq $E_TRAN ? 1 : 0}] \
        [expr {[string is integer -strict $e_g_mask] && ($e_g_mask & 4) ? 1 : 0}]] \
  [list {-1 0} ok 2 1 1]

# --- section E teardown ------------------------------------------------------
catch {rename ::ase::last_rawfile {}}
catch {rename ::ase::results_stale {}}
if {$E_HAD_LRF} { catch {rename ::ase::_e_saved_lrf ::ase::last_rawfile} }
if {$E_HAD_RST} { catch {rename ::ase::_e_saved_rst ::ase::results_stale} }
catch {e_ctx $E_DWIN {catch {xschem raw clear} ; catch {xschem cursor 1 0} ; catch {xschem cursor 2 0}}}
catch {array unset ::wviewer::cva $E_KEY}
catch {array unset ::wviewer::cvb $E_KEY}
if {$E_VT ne {}} { catch {wviewer::close $E_KEY} ; catch {destroy $E_VT} }
update
catch {ase::ui::close $E_KEY} ; catch {ase::session_close $E_KEY}
update
catch {xschem set annot_show 0}

# --- restore -----------------------------------------------------------------
rename select_raw {}
if {[llength [info procs c_real_select_raw]]} { rename c_real_select_raw select_raw }
foreach _ck [dict keys [set ::ase::sessions]] {
  catch {ase::ui::close $_ck} ; catch {ase::session_close $_ck}
}
catch {xschem raw clear}
catch {xschem set annot_show 0}
# ------------------------------------------------------------------- cleanup --
set ::autosave_backup $::saved_autosave_0601   ;# issue 0601

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
