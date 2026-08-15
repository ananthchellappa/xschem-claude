# perform_action() BOUNDARY -- TENTH per-verb migration, the SECOND NON-transform
# verb and the FIRST after the wire-surgery pair (Refactor B, audit §4 / §30):
# floaters_from_selected_inst.
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). Atoms 1-9 migrated trim_wires/align + the transform SEXTET
# (rotate/flip/flipv x pivot + in-place) + break_wires. Atom 10 migrates
# floaters_from_selected_inst -- the CLEANEST next atom:
#   * a BARE no-arg verb (no coordinate pivot, no 0/1 flag) -- even SIMPLER than
#     break_wires (atom 9): run_core takes no argc/argv and the log falls to
#     core_log_action's DEFAULT `xschem %s` form (NO per-verb branch, like
#     trim_wires/align/in-place);
#   * NO mid-gesture split (not a transform, no STARTMOVE/STARTCOPY arms);
#   * floaters_from_selected_inst() (select.c) OWNS its own push_undo/set_modify/
#     draw(), so run_core adds NONE -- adding push_undo would double-push (the
#     atom-1 no-double-push rule, as with break_wires_at_pins);
#   * it is called ONLY by this verb's own scheduler branch (NO key, NO other C
#     caller), so it is strictly 1:1 -- log at the boundary/core_log_action. Unlike
#     trim_wires (whose shared C fn is a sub-step of align) there is no sub-step to
#     lock; case (e) instead locks the UNCONDITIONAL-log semantics the boundary
#     preserves (a no-op floaters STILL logs, byte-identically to pre-migration).
#
# Entry points, all funnelled through perform_action:
#   scheduler branch (Symbol menu hand-written -command / command palette raw /
#     scripted `xschem floaters_from_selected_inst`) -> return perform_action(...)
#   There is NO key entry point (no keybindings.csv row, no callback.c legacy switch).
#
# DELIBERATE behaviour delta of this atom: the scheduler branch NEVER HAD a
# scheduler_readonly_reject (floaters mutates but was ungated on a read-only cell,
# a scattered 0041/0051-class gap). The boundary's ONE gate now CLOSES it -- floaters
# correctly REFUSES on a read-only cell. The WRITABLE effect + log are byte-identical.
#
#   (a) exactly ONE log line from EACH entry point (script / menu wrapper), and the
#       WRITABLE effect applies (texts 0 -> 6)
#   (b) readonly reject (the 0041/0051 close): TCL_ERROR, verb-named message, NO
#       mutation, NO log -- one gate covers the scheduler/menu/script route
#   (c) byte-identical: the logged line is textually `xschem floaters_from_selected_inst`
#   (d) replay: the recorded bare verb re-EXECUTES (effect applies) through the
#       replay_action_log suppress seam but does NOT re-log; a control unwrapped
#       source DOES re-log (a real re-executable verb, not a coordinate-form bypass)
#   (e) UNCONDITIONAL-log lock (the floaters analogue of the atom-1 sub-step lock):
#       floaters with NOTHING selected is a no-op (texts unchanged) but STILL logs
#       +1 -- the boundary preserves floaters's pre-migration unconditional log
#       (contrast change_elem_order, whose branch suppresses a no-op log)
#
# Effect oracle (byte-identical before/after atom 10 -- atom 10 only MOVES the log
# site): a resistor (devices/res.sym) selected at the origin. res.sym has 8 symbol
# texts, 2 of them `:net_name` (skipped by floaters). `xschem floaters_from_selected_inst`
# flattens the other 6 into standalone floater texts -> text count 0 -> 6, a clean,
# deterministic oracle. Determined empirically on the pre-migration binary. NB
# `xschem select instance` sets the instance's sel flag but does NOT rebuild
# xctx->sel_array; floaters reads lastsel/sel_array directly, so the fixture forces
# a rebuild via `xschem get lastsel` before the verb (else it silently no-ops).
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_floaters_from_selected_inst.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §30

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit
# registers this in logdir_tests so LOG is always set in the real run; the guard
# keeps a bare invocation from erroring. (deferred, NOT "skipped: no X" -- the
# effect is X-independent, but the log site needs an open action log.)
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
proc fc {} { return [logcount {xschem floaters_from_selected_inst}] }

# Fixture: a resistor selected at the origin, with sel_array materialized (floaters
# reads lastsel/sel_array directly -- `xschem get lastsel` forces rebuild_selected_array).
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem select instance 0
  xschem get lastsel
}

# ---------------------------------------------------------------------------
# (a) EXACTLY ONE log line from EACH entry point, and the WRITABLE effect applies.
#     script -> scheduler branch -> perform_action
#     menu   -> menu_action_logged wrapper -> `xschem floaters_from_selected_inst`
#               -> branch; the wrapper resets/checks the dedup flag so the core's
#               log wins and the wrapper skips its copy -> exactly one line.
# ---------------------------------------------------------------------------
fixture
set c0 [fc]
xschem floaters_from_selected_inst
check "(a) scripted 'xschem floaters_from_selected_inst' -> exactly +1" \
  [expr {[fc] == $c0 + 1}] "c0=$c0 now=[fc]"
check "(a) scripted: WRITABLE effect applied (texts 0 -> 6)" \
  [expr {[xschem get texts] == 6}] "texts=[xschem get texts]"

fixture
set c0 [fc]
menu_action_logged {xschem floaters_from_selected_inst}
check "(a) menu wrapper -> exactly +1 (core log wins, wrapper dedups)" \
  [expr {[fc] == $c0 + 1}] "c0=$c0 now=[fc]"

# ---------------------------------------------------------------------------
# (b) READONLY REJECT (the 0041/0051 close -- this branch never had a readonly gate):
#     TCL_ERROR, verb-named message, NO mutation (texts stay 0), NO log. The ONE
#     boundary gate now covers the scheduler/menu/script route.
# ---------------------------------------------------------------------------
fixture
set t0 [xschem get texts]
xschem set readonly 1
set c0 [fc]
set rc [catch {xschem floaters_from_selected_inst} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(b) readonly scripted: message names the verb + read-only" \
  [expr {[string match {*floaters_from_selected_inst*read-only*} $res]}] "res=$res"
check "(b) readonly scripted: NO log line (+0)" \
  [expr {[fc] == $c0}] "c0=$c0 now=[fc]"
check "(b) readonly scripted: NO mutation (text count unchanged)" \
  [expr {[xschem get texts] == $t0}] "before=$t0 after=[xschem get texts]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) BYTE-IDENTICAL: the logged line is textually `xschem floaters_from_selected_inst`
#     -- no args, no format drift (the migration MOVED the log site; it must not
#     change the text). Grab the last matching physical line and compare exactly.
# ---------------------------------------------------------------------------
fixture
xschem floaters_from_selected_inst
set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
set exact ""
foreach l [split $all \n] { if {$l eq {xschem floaters_from_selected_inst}} { set exact $l } }
check "(c) logged line is byte-exact 'xschem floaters_from_selected_inst'" \
  [expr {$exact eq "xschem floaters_from_selected_inst"}] "got=>$exact<"

# ---------------------------------------------------------------------------
# (d) REPLAY. floaters_from_selected_inst is a bare, re-executable verb (not a
#     coordinate-form bypass): replaying it re-runs the effect. Through the
#     replay_action_log suppress seam the effect applies but does NOT re-log (the
#     boundary's log site rides !actionlog_suppress -- re-entrant-safe). A control
#     unwrapped `source` DOES re-log. The recorded file holds ONLY the verb line, so
#     the fixture pre-establishes the selection the effect consumes.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_floaters_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem floaters_from_selected_inst"; close $fd

fixture
set nc [fc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (texts 0 -> 6)" \
  [expr {[xschem get texts] == 6}] "texts=[xschem get texts]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[fc] == $nc}] "nc=$nc now=[fc]"

fixture
set nc [fc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (texts 0 -> 6)" \
  [expr {[xschem get texts] == 6}] "texts=[xschem get texts]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[fc] == $nc + 1}] "nc=$nc now=[fc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) UNCONDITIONAL-log lock (the floaters analogue of the atom-1 sub-step lock):
#     floaters with NOTHING selected is a no-op (no texts created) but STILL emits
#     exactly one `xschem floaters_from_selected_inst` line -- the boundary preserves
#     floaters's pre-migration unconditional log (core_log_action logs regardless of
#     whether the effect mutated). This is the byte-identical-output guarantee for
#     the no-op path; contrast change_elem_order, whose branch suppresses a no-op log.
# ---------------------------------------------------------------------------
xschem clear force
xschem unselect_all
set t0 [xschem get texts]
set c0 [fc]
xschem floaters_from_selected_inst
check "(e) nothing-selected: NO mutation (no floater texts created, no-op)" \
  [expr {[xschem get texts] == $t0}] "before=$t0 after=[xschem get texts]"
check "(e) nothing-selected: STILL logs +1 (boundary preserves the unconditional log)" \
  [expr {[fc] == $c0 + 1}] "c0=$c0 now=[fc]"

# ---------------------------------------------------------------------------
# (f) UNDO OWNERSHIP (the atom-1 no-double-push rule): floaters_from_selected_inst()
#     OWNS its single push_undo (on first mutation), and the run_core arm adds NONE.
#     The discriminator is undo DEPTH, not the first undo's texts: floaters's push and
#     a spurious run_core push_undo() both capture the SAME pre-mutation state (R1, 0
#     texts), so ONE undo restores texts either way. But the fixture's undo stack holds
#     exactly TWO snapshots -- the instance-place snapshot + floaters's ONE push -- so
#     TWO undos wind all the way back to empty (R1 gone). A double-push would insert a
#     THIRD (identical) snapshot, so R1 would SURVIVE two undos (instances still 1).
# ---------------------------------------------------------------------------
fixture
xschem floaters_from_selected_inst
check "(f) undo ownership: floaters created 6 texts" \
  [expr {[xschem get texts] == 6}] "texts=[xschem get texts]"
xschem undo
check "(f) undo ownership: ONE undo restores the texts (6 -> 0)" \
  [expr {[xschem get texts] == 0}] "texts=[xschem get texts]"
xschem undo
check "(f) undo ownership: a SECOND undo removes the instance (R1 gone) -- floaters's single push_undo is the ONLY floaters snapshot; a double-push in run_core would leave an identical extra one so R1 would survive two undos" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
