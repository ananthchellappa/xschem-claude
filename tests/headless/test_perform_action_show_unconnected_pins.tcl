# perform_action() BOUNDARY -- FIFTEENTH per-verb migration (Refactor B, audit §4 /
# §35): show_unconnected_pins.
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-check
# it?" and "did we log it?" are structural invariants, not per-path checklist items
# (audit §3.1). Atom 15 is a PLAIN per-verb migration onto the UNCHANGED atom-13
# log-on-success boundary (NO shared-machinery change) -- it migrates the friction-free
# verb the fresh atom-15 fan-out scout picked after the atom-14 VALIDATING shortlist was
# EXHAUSTED. show_unconnected_pins is:
#   * a BARE no-arg verb like floaters (atom 10) / toggle_ignore (atom 12): run_core
#     takes no argc/argv and the log falls to core_log_action's DEFAULT `xschem %s`
#     form (NO per-verb branch);
#   * the SECOND verb to SHARE the attach_labels_to_inst() core (after attach_labels
#     atom 11). Its core show_unconnected_pins() (netlist.c) selects every instance and
#     calls attach_labels_to_inst(2) RAW to place a lab_show.sym label on each
#     UNCONNECTED pin. attach_labels_to_inst() OWNS its push_undo (place_symbol pushes
#     once via to_push_undo on the first placed label), set_modify(1) and draw(), so
#     run_core adds NONE -- adding push_undo would double-push (the atom-1 rule);
#   * the atom-11 SHARED-SUB-STEP LOCK, re-verified from the OTHER side: that raw
#     attach_labels_to_inst(2) call stays SILENT below the boundary (its log lives under
#     the `attach_labels` verb in core_log_action, NOT in the C fn), so routing
#     show_unconnected_pins double-logs NOTHING with the attach_labels verb (check (g)).
#
# Entry points, all funnelled through perform_action:
#   scheduler branch (hilight menu hand-written -command / actions.csv command palette /
#     scripted `xschem show_unconnected_pins`) -> return perform_action(...)
#   There is NO key entry point (no keybindings.csv row, no callback.c legacy switch,
#   no act_* handler). The Shift+H key is act_attach_labels -> attach_labels_to_inst(1),
#   a DIFFERENT path that does NOT pass through show_unconnected_pins -- untouched here.
#
# DELIBERATE behaviour delta of this atom (a CORRECTNESS FIX): the scheduler branch
# NEVER HAD a scheduler_readonly_reject -- show_unconnected_pins placed lab_show labels
# on a read-only cell (place_symbol ran; only set_modify was ro-suppressed), a scattered
# 0041/0051-class mutation-on-a-read-only-cell gap. The boundary's ONE gate now CLOSES
# it -- the verb correctly REFUSES on a read-only cell (check (c)). The WRITABLE effect +
# log are byte-identical to pre-migration.
#
#   (a) exactly ONE log line from EACH entry point (script / menu wrapper), and the
#       WRITABLE effect applies (instances 1 -> 3: two lab_show.sym labels placed)
#   (b) NO-OP STILL LOGS (§30/§32): a sheet with NO unconnected pins (both pins wired)
#       places nothing but STILL logs +1 -- the boundary's unconditional log; a no-op is
#       a SUCCESS (TCL_OK), so log-on-success keeps it
#   (c) readonly reject (the CORRECTNESS FIX): TCL_ERROR, verb-named message, NO
#       placement, NO log -- one gate covers the scheduler/menu/script route
#   (d) byte-identical: the logged line is textually `xschem show_unconnected_pins`
#   (e) replay: the recorded bare verb re-EXECUTES (labels placed) through the
#       replay_action_log suppress seam but does NOT re-log; a control unwrapped source
#       DOES re-log (a real re-executable verb, not a coordinate-form bypass)
#   (f) undo DEPTH (the atom-1 no-double-push rule): ONE undo removes the labels (3 -> 1),
#       a SECOND removes the instance (1 -> 0) -- attach_labels_to_inst's SINGLE push_undo
#       is the only show_unconnected_pins snapshot; a spurious run_core push_undo would
#       insert an identical third so R1 would survive two undos
#   (g) SHARED-SUB-STEP LOCK (the atom-11 lock, from the show_unconnected_pins side):
#       `xschem show_unconnected_pins` MUTATES (labels placed) yet emits ZERO `xschem
#       attach_labels` lines -- the raw attach_labels_to_inst(2) sub-step stays silent
#       below the boundary
#   (h) menu route: the hilight-menu -command in xschem.tcl is `xschem
#       show_unconnected_pins` verbatim -> the scheduler branch -> the boundary
#
# Effect oracle (byte-identical before/after atom 15 -- atom 15 MOVES the log site + ADDS
# the readonly gate): a resistor (devices/res.sym) at the origin has TWO pins (0,-30 &
# 0,30), both unconnected. `xschem show_unconnected_pins` selects all instances and
# places a lab_show.sym label on each unconnected pin -> instance count 1 -> 3 (labels
# p1,p2), a clean deterministic oracle. Determined empirically on the pre-migration
# binary. show_unconnected_pins() selects all instances + rebuilds selected_array +
# prepare_netlist_structs itself, so no pre-selection is needed; the fixture forces a
# redraw so the pin-vs-wire skip test's spatial hash is populated headless.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_show_unconnected_pins.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §35

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X" -- the effect is
# X-independent, but the log site needs an open action log.)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counter: the recorded verb is bare, so match the whole line.
proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc sc {} { return [logcount {xschem show_unconnected_pins}] }
# Prefix counter for the shared-sub-step lock (g): any `xschem attach_labels...` line.
proc alcount {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem attach_labels*} $l]} { incr n } }
  return $n
}

# Fixture: a resistor at the origin with BOTH pins unconnected (2 lab_show labels get
# placed). show_unconnected_pins selects all instances itself, so no pre-selection; the
# redraw populates the spatial hash for the pin-vs-wire connectivity test.
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from the script entry point + a SYNTHETIC dedup-wrapper
#     exercise, and the WRITABLE effect applies.
#     script -> scheduler branch -> perform_action.
#     The second drive, `menu_action_logged {xschem show_unconnected_pins}`, is a
#     SYNTHETIC exercise of the menu_action_logged dedup wrapper -- NOT this verb's real
#     menu path (the hilight menu is a hand-written raw `-command "xschem
#     show_unconnected_pins"`, NOT menu_action_logged-wrapped; that real route is asserted
#     by check (h)). It proves that EVEN IF the verb were reached through the dedup
#     wrapper, the wrapper resets/checks the dedup flag so the core's boundary log wins
#     and the wrapper skips its copy -> exactly one line.
# ---------------------------------------------------------------------------
fixture
set c0 [sc]
xschem show_unconnected_pins
check "(a) scripted 'xschem show_unconnected_pins' -> exactly +1" \
  [expr {[sc] == $c0 + 1}] "c0=$c0 now=[sc]"
check "(a) scripted: WRITABLE effect applied (instances 1 -> 3, two lab_show labels)" \
  [expr {[xschem get instances] == 3}] "instances=[xschem get instances]"
check "(a) scripted: the placed cells are lab_show.sym" \
  [expr {[xschem getprop instance 1 cell::name] eq {lab_show.sym} &&
         [xschem getprop instance 2 cell::name] eq {lab_show.sym}}] \
  "1=[xschem getprop instance 1 cell::name] 2=[xschem getprop instance 2 cell::name]"

fixture
set c0 [sc]
menu_action_logged {xschem show_unconnected_pins}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[sc] == $c0 + 1}] "c0=$c0 now=[sc]"

# ---------------------------------------------------------------------------
# (b) NO-OP STILL LOGS (§30/§32): a sheet with NO unconnected pins (a resistor whose
#     both pins are covered by a wire) places NOTHING but STILL emits exactly one
#     `xschem show_unconnected_pins` line -- the boundary's unconditional log. A no-op is
#     a SUCCESS (run_core returns TCL_OK), so log-on-success keeps it (contrast a
#     validating verb's TCL_ERROR, which is NOT logged).
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=R1}
xschem wire 0 -30 0 30
xschem redraw
set i0 [xschem get instances]
set c0 [sc]
# catch-wrapped so a run_core arm regressed to return TCL_ERROR on the no-op path
# (sabotage 4) reports a clean log-count FAIL here, not an uncaught-error script abort
# (the atom-13 (e) lesson). The real no-op returns TCL_OK, so the catch is a no-op.
catch {xschem show_unconnected_pins}
check "(b) no-unconnected-pins: NO placement (no-op, instances unchanged)" \
  [expr {[xschem get instances] == $i0}] "before=$i0 after=[xschem get instances]"
check "(b) no-unconnected-pins: STILL logs +1 (boundary preserves the unconditional log)" \
  [expr {[sc] == $c0 + 1}] "c0=$c0 now=[sc]"

# ---------------------------------------------------------------------------
# (c) READONLY REJECT (the CORRECTNESS FIX -- this branch never had a readonly gate):
#     TCL_ERROR, verb-named message, NO placement (instances stay 1), NO log. The ONE
#     boundary gate now covers the scheduler/menu/script route. Pre-migration the verb
#     PLACED labels on a read-only cell (place_symbol ran; only set_modify was suppressed).
# ---------------------------------------------------------------------------
fixture
set i0 [xschem get instances]
xschem set readonly 1
set c0 [sc]
set rc [catch {xschem show_unconnected_pins} res]
check "(c) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(c) readonly scripted: message names the verb + read-only" \
  [expr {[string match {*show_unconnected_pins*read-only*} $res]}] "res=$res"
check "(c) readonly scripted: NO log line (+0)" \
  [expr {[sc] == $c0}] "c0=$c0 now=[sc]"
check "(c) readonly scripted: NO placement (instance count unchanged)" \
  [expr {[xschem get instances] == $i0}] "before=$i0 after=[xschem get instances]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) BYTE-IDENTICAL: the logged line is textually `xschem show_unconnected_pins` -- no
#     args, no format drift (the migration MOVED the log site; it must not change the text).
# ---------------------------------------------------------------------------
fixture
xschem show_unconnected_pins
set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
set exact ""
foreach l [split $all \n] { if {$l eq {xschem show_unconnected_pins}} { set exact $l } }
check "(d) logged line is byte-exact 'xschem show_unconnected_pins'" \
  [expr {$exact eq "xschem show_unconnected_pins"}] "got=>$exact<"

# ---------------------------------------------------------------------------
# (e) REPLAY. show_unconnected_pins is a bare, re-executable verb (not a coordinate-form
#     bypass): replaying it re-runs the effect. Through the replay_action_log suppress
#     seam the effect applies but does NOT re-log (the boundary's log site rides
#     !actionlog_suppress -- re-entrant-safe). A control unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_sup_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem show_unconnected_pins"; close $fd

fixture
set nc [sc]
replay_action_log $rec
check "(e) replay seam: EFFECT applied (instances 1 -> 3)" \
  [expr {[xschem get instances] == 3}] "instances=[xschem get instances]"
check "(e) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[sc] == $nc}] "nc=$nc now=[sc]"

fixture
set nc [sc]
uplevel #0 [list source $rec]
check "(e) control (unwrapped source): EFFECT applied (instances 1 -> 3)" \
  [expr {[xschem get instances] == 3}] "instances=[xschem get instances]"
check "(e) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[sc] == $nc + 1}] "nc=$nc now=[sc]"
file delete $rec

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (the atom-1 no-double-push rule): attach_labels_to_inst() (reached via
#     show_unconnected_pins()) OWNS its single push_undo (on the first placed label), and
#     the run_core arm adds NONE. The fixture's undo stack holds exactly TWO snapshots --
#     the instance-place snapshot + the ONE push -- so ONE undo removes the labels (3 ->
#     1) and a SECOND winds back to empty (R1 gone). A double-push would insert a THIRD
#     (identical) snapshot, so R1 would SURVIVE two undos (instances still 1).
# ---------------------------------------------------------------------------
fixture
xschem show_unconnected_pins
check "(f) undo ownership: two labels placed (instances 3)" \
  [expr {[xschem get instances] == 3}] "instances=[xschem get instances]"
xschem undo
check "(f) undo ownership: ONE undo removes the labels (3 -> 1)" \
  [expr {[xschem get instances] == 1}] "instances=[xschem get instances]"
xschem undo
check "(f) undo ownership: a SECOND undo removes the instance (R1 gone) -- attach_labels_to_inst's single push_undo is the ONLY show_unconnected_pins snapshot; a double-push in run_core would leave an identical extra one so R1 would survive two undos" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

# ---------------------------------------------------------------------------
# (g) SHARED-SUB-STEP LOCK (the atom-11 lock, re-verified from the show_unconnected_pins
#     side): show_unconnected_pins()'s core calls attach_labels_to_inst(2) RAW -- that
#     call must stay SILENT below the boundary (its log lives under the `attach_labels`
#     verb in core_log_action, NOT in the C fn). So `xschem show_unconnected_pins`
#     MUTATES (labels placed) yet emits ZERO `xschem attach_labels` lines. A self-log
#     added inside attach_labels_to_inst / show_unconnected_pins would double-log with the
#     attach_labels verb path (sabotage 6).
# ---------------------------------------------------------------------------
fixture
set a0 [alcount]
xschem show_unconnected_pins
check "(g) shared-sub-step lock: MUTATED (instances 3) proving the raw attach_labels_to_inst(2) ran" \
  [expr {[xschem get instances] == 3}] "instances=[xschem get instances]"
check "(g) shared-sub-step lock: ZERO 'xschem attach_labels' lines (raw sub-step stays silent below the boundary)" \
  [expr {[alcount] == $a0}] "a0=$a0 now=[alcount]"

# ---------------------------------------------------------------------------
# (h) MENU ROUTE: the hilight menu invokes `xschem show_unconnected_pins` verbatim (a
#     hand-written -command, NOT menu_action_logged-wrapped), so it rides the scheduler
#     branch -> the boundary with no separate routing. Assert the source -command is the
#     bare verb (structural) AND that invoking it exactly as the menu does logs +1.
# ---------------------------------------------------------------------------
set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set fd [open [file join $REPO src xschem.tcl] r]; set tcl [read $fd]; close $fd
check "(h) menu -command is 'xschem show_unconnected_pins' verbatim (rides the branch -> boundary)" \
  [expr {[regexp -- {-command "xschem show_unconnected_pins"} $tcl]}] \
  "menu -command not found as the bare verb in xschem.tcl"
fixture
set c0 [sc]
eval {xschem show_unconnected_pins}   ;# the exact string the menu -command evaluates
check "(h) menu -command string, evaluated as the menu does -> exactly +1" \
  [expr {[sc] == $c0 + 1}] "c0=$c0 now=[sc]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
