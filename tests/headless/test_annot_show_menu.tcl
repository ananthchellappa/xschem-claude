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

# ------------------------------------------------------------------- cleanup --
set ::autosave_backup $::saved_autosave_0601   ;# issue 0601

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
