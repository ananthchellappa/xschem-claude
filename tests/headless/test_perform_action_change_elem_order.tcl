# perform_action() BOUNDARY -- Refactor B ATOM 21: the TWENTY-FIRST per-verb migration
# (audit §41 / §40 / §39 / §29 / §4): change_elem_order.
#
# `xschem change_elem_order <n>` reorders the z-order (array position) of the SELECTED
# object: n>=0 sets it to position n (clamped to array bounds in-core); n==-1 opens the
# interactive "Object Sequence number" input_line dialog (the Shift+S / Prop-menu form).
# It is a value-carrying integer verb like attach_labels (atom 11) -- so core_log_action
# PRESERVES the value with %d, NOT collapsed like break_wires (atom 9).
#
# TWO ENTRY POINTS, BOTH funnelled through perform_action (the atom-16 "grep the GUI for
# every entry point" lesson; the break_wires atom-9 / transform-verb pattern):
#   scheduler branch (Prop menu / scripted `xschem change_elem_order <n>`)
#       -> return perform_action("change_elem_order", argc, argv)
#   Shift-S key (callback.c legacy switch, case 'S', rstate==0, HARDCODED -1)
#       -> perform_action("change_elem_order", 3, av) with av[2]="-1"
# The Shift-S key KEEPS its semaphore>=2 + readonly_block() self-guards (the break_wires
# Ctrl-! pattern -- readonly_block() preserves the read-only messageBox this legacy-switch
# key posted, which the boundary's silent TCL_ERROR would drop since an event handler
# discards perform_action's rc). The boundary's ONE scheduler_readonly_reject gates the
# scheduler/menu/script path (CONSOLIDATION: the old branch HAD its own, now REMOVED).
#
# THREE DESIGN CALLS (resolved from source, pinned on the pre-migration binary):
#   1) READONLY = CONSOLIDATION, not a new fix: the branch already had a per-verb
#      scheduler_readonly_reject AND the Shift-S key an inline readonly_block; the boundary's
#      ONE gate now covers the scheduler path (the key keeps readonly_block belt-and-suspenders).
#      Both refuse on read-only pre AND post (check (b)).
#   2) THE had_sel LOG GATE -- PRESERVED, §30 REJECTED (the load-bearing decision, adversarial-review
#      MAJOR): both entry points gated the log on `if(had_sel)` -- a nothing-selected reorder is a
#      no-op that must NOT log. The §30 no-op-still-logs alignment (as floaters/toggle_ignore) was
#      first taken then REJECTED: change_elem_order is SELECTION-DEPENDENT (0005 class) AND its core
#      keeps the reordered object SELECTED (the editprop.c swap moves the .sel bit), so a phantom
#      empty-selection line would, on a whole-log replay where an intervening interactive deselect was
#      NOT logged, find that object STILL selected and REORDER it -- a silent z-order divergence. So
#      the had_sel gate is PRESERVED, moved into core_log_action (`if(xctx->lastsel)`, the log
#      authority's natural home, like replace_symbol's fast gate) -- EXACT pre-migration behaviour,
#      locking test_selflog_output.tcl:190 `change_elem_order (no sel) is nolog` (check (c)).
#   3) LOG FORM = value-preserving `xschem change_elem_order %d` via core_log_action (the
#      attach_labels %d template -- PRESERVES the integer, NOT collapsed): a bare numeric arg,
#      no Tcl metacharacter, so log_action("...%d", atoi(argv[2])), NOT log_action_argv.
#
# Checks:
#   (a) SUCCESS + reorder oracle: R1(idx0)/R2(idx1) overlapping; select R2, `change_elem_order 0`
#       -> R2 to idx0, R1 to idx1 (read back via `xschem instance_number`); exactly +1 log; and
#       VALUE-PRESERVING byte-exact: `change_elem_order 7` logs `xschem change_elem_order 7`
#       (the RAW n, before the in-core clamp -- not collapsed), and set_modify(1) on a saved sheet.
#   (b) READONLY reject from BOTH entry points: scripted -> TCL_ERROR + verb-named message + NO
#       mutation + NO log; Shift-S key -> NO mutation + NO log (readonly_block breaks first).
#   (c) had_sel GATE PRESERVED (§30 REJECTED): `change_elem_order 3` with nothing selected -> TCL_OK,
#       NO mutation, +0 log (matches test_selflog_output:190); a SELECTED reorder logs +1; a
#       multi-selection (select_all) no-op STILL logs +1 (had_sel!=0, matches test_selflog_output:184).
#   (d) VALIDATION gates: `change_elem_order -5` (invalid: not >=0, not -1) -> TCL_ERROR + +0 log
#       + no mutation; bare `change_elem_order` (argc<3, the OOB-crash class) -> TCL_ERROR + +0 log.
#   (e) UNDO DEPTH = single push: `change_elem_order 0` then ONE undo restores R1(idx0)/R2(idx1).
#   (f) SHIFT-S KEY EQUIVALENCE (callback injection, keysym 83 state 0): mutates (via the stubbed
#       input_line target) + logs byte-exact `xschem change_elem_order -1` exactly +1.
#   (g) REPLAY round-trip: the recorded `change_elem_order 0` re-EXECUTES through the
#       replay_action_log suppress seam (selection-dependent, 0005 class -- the fixture re-selects)
#       but does NOT re-log; a control unwrapped `source` DOES re-log.
#   (h) SHARED SUB-STEP silent: `instance_number inst <n>` calls change_elem_order() RAW -> logs NO
#       change_elem_order line (off the boundary; runtime lock the grep-guard can't provide).
#
# Effect oracle (byte-identical reorder before/after atom 21 -- the migration MOVES the log site
# + flips the had_sel gate, it does not change the reorder): two res.sym instances placed at the
# SAME origin (0 0 0 0), distinct names R1/R2 -> z-order == array index, read back via
# `xschem instance_number <name>`. Determined empirically on the pre-migration binary (oracle.tcl):
# the reorder, the single push_undo, the set_modify, the empty/invalid/bare no-op-no-log, the
# Shift-S mutate+log, and the value-preserving `change_elem_order 7` all pinned there.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_change_elem_order.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §41

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers this in
# logdir_tests so LOG is always set in the real run; the guard keeps a bare invocation from
# erroring. (deferred, NOT "skipped: no X".)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stubs (real DISPLAY): the Shift-S key KEEPS readonly_block() (posts
# tk_messageBox when has_x), and the n<0 path opens input_line (.dialog, tkwait) which would
# WEDGE headless -- stub both. input_line sets tctx::retval to a controllable target index,
# simulating the user typing a sequence number.
catch {rename tk_messageBox _paw_real_mb}
proc tk_messageBox {args} { return ok }
catch {rename input_line _paw_real_input_line}
set ::paw_il_target 0
set ::paw_il_calls 0
proc input_line {txt {cmd {}} {preset {}} {w 12}} {
  incr ::paw_il_calls
  set tctx::retval $::paw_il_target
  return $tctx::retval
}

# ANY change_elem_order line (to prove a FAILED/empty call logs the right count) + exact-match.
proc cec {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {[string match {xschem change_elem_order*} $l]} { incr n } }
  return $n
}
proc cecpat {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc idx {ref} { return [xschem instance_number $ref] }

# fixture: two overlapping instances, distinct names -> z-order == array index (R1=0, R2=1).
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}
  xschem instance devices/res.sym 0 0 0 0 {name=R2 value=2k}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: the reorder oracle + exactly +1 log + VALUE-PRESERVING byte-exact + set_modify.
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: R1=idx0 R2=idx1" [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"
xschem select instance 1     ;# R2 (idx1)
set c0 [cec]
set r [xschem change_elem_order 0]
check "(a) reorder applied: R2 -> idx0, R1 -> idx1" [expr {[idx R2]==0 && [idx R1]==1}] "R1=[idx R1] R2=[idx R2]"
check "(a) exactly +1 log line" [expr {[cec]==$c0+1}] "c0=$c0 now=[cec]"
check "(a) logged line byte-exact 'xschem change_elem_order 0'" \
  [expr {[cecpat {xschem change_elem_order 0}]>=1}] "count=[cecpat {xschem change_elem_order 0}]"

# VALUE-PRESERVING: change_elem_order 7 logs the RAW `7` (in-core clamp to instances-1 does NOT
# collapse the logged value -- the atom-11 %d fidelity, distinct from break_wires's collapse-to-1).
fixture
xschem select instance 1
set c0 [cec]
xschem change_elem_order 7
check "(a) VALUE-PRESERVING byte-exact 'xschem change_elem_order 7' (raw n, not clamped/collapsed)" \
  [expr {[cecpat {xschem change_elem_order 7}]==1}] "count=[cecpat {xschem change_elem_order 7}]"
check "(a) +1 log for the value form" [expr {[cec]==$c0+1}] "c0=$c0 now=[cec]"

# set_modify(1): a reorder on a SAVED sheet sets modified (the core owns set_modify).
set recf [file join [file dirname $LOG] paw_ceo_mod_[pid].sch]
fixture
xschem saveas $recf
check "(a) set_modify oracle: modified==0 after saveas" [expr {[xschem get modified]==0}] "modified=[xschem get modified]"
xschem select instance 1
xschem change_elem_order 0
check "(a) reorder SETS modified=1 (the core owns set_modify -- no double, no missing)" \
  [expr {[xschem get modified]==1}] "modified=[xschem get modified]"
file delete $recf

# ---------------------------------------------------------------------------
# (b) READONLY reject from BOTH entry points (the CONSOLIDATION). Scripted -> TCL_ERROR +
#     verb-named message + NO mutation + NO log. Shift-S key -> NO mutation + NO log
#     (readonly_block breaks BEFORE perform_action; input_line never reached).
# ---------------------------------------------------------------------------
fixture
xschem select instance 1
xschem set readonly 1
set c0 [cec]
set rc [catch {xschem change_elem_order 0} res]
check "(b) readonly scripted: TCL_ERROR" [expr {$rc==1}] "rc=$rc"
check "(b) readonly scripted: message names verb + read-only (non-empty)" \
  [expr {[string match {*change_elem_order*read-only*} $res]}] "res=>$res<"
check "(b) readonly scripted: NO mutation (R2 still idx1)" [expr {[idx R2]==1}] "R2=[idx R2]"
check "(b) readonly scripted: NO log (+0)" [expr {[cec]==$c0}] "c0=$c0 now=[cec]"

set ::paw_il_calls 0
set c1 [cec]
xschem callback .drw 2 300 300 83 0 0 0    ;# Shift-S (keysym 83 'S', state 0)
check "(b) readonly Shift-S key: NO mutation (R2 still idx1)" [expr {[idx R2]==1}] "R2=[idx R2]"
check "(b) readonly Shift-S key: NO log (+0)" [expr {[cec]==$c1}] "c1=$c1 now=[cec]"
check "(b) readonly Shift-S key: input_line NOT reached (readonly_block breaks first)" \
  [expr {$::paw_il_calls==0}] "calls=$::paw_il_calls"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) had_sel LOG GATE PRESERVED (§30 REJECTED for this selection-dependent verb -- adversarial
#     review MAJOR): nothing selected -> the reorder is a no-op AND logs NOTHING (the pre-migration
#     had_sel behaviour in core_log_action's `if(xctx->lastsel)`, locked by test_selflog_output:190).
#     This avoids the phantom-line replay divergence -- a still-selected object reordered on whole-log
#     replay where an unlogged interactive deselect left it selected.
# ---------------------------------------------------------------------------
fixture
xschem unselect_all
set c0 [cec]
set rc [catch {xschem change_elem_order 3} res]
check "(c) empty-selection: returns TCL_OK (rc=0 -- a no-op is a SUCCESS)" [expr {$rc==0}] "rc=$rc res=>$res<"
check "(c) had_sel GATE: empty-selection logs NOTHING (+0 -- NOT the §30 flip; matches test_selflog_output:190)" \
  [expr {[cec]==$c0}] "c0=$c0 now=[cec]"
check "(c) empty-selection: NO mutation (2 instances intact)" [expr {[xschem get instances]==2}] "instances=[xschem get instances]"
# gate not stuck-closed: a SELECTED reorder DOES log +1.
xschem select instance 1
set c1 [cec]
xschem change_elem_order 0
check "(c) had_sel GATE: a SELECTED reorder logs +1 (gate OPEN when something is selected)" \
  [expr {[cec]==$c1+1}] "c1=$c1 now=[cec]"
# multi-selection: change_elem_order no-ops (lastsel!=1) but had_sel!=0 -> STILL logs (matches the
# old branch, and test_selflog_output:184 where select_all + change_elem_order logs).
fixture
xschem select_all
set c2 [cec]
xschem change_elem_order 0
check "(c) had_sel GATE: multi-select (select_all) no-op STILL logs +1 (had_sel!=0, matches test_selflog_output:184)" \
  [expr {[cec]==$c2+1}] "c2=$c2 now=[cec]"
check "(c) multi-select: reorder was a NO-OP (R1=idx0 R2=idx1 unchanged -- lastsel!=1)" \
  [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"

# ---------------------------------------------------------------------------
# (d) VALIDATION gates: invalid n and the argc<3 OOB class each -> TCL_ERROR, +0 log, no mutation.
# ---------------------------------------------------------------------------
fixture
xschem select instance 1
set c0 [cec]
set rc [catch {xschem change_elem_order -5} res]
check "(d) invalid n=-5 (not >=0, not -1): TCL_ERROR" [expr {$rc==1}] "rc=$rc"
check "(d) invalid n=-5: NON-EMPTY message (landmine: success-only reset did not wipe it)" \
  [expr {[string match {*change_elem_order*} $res] && $res ne {}}] "res=>$res<"
check "(d) invalid n=-5: NO mutation (R2 still idx1)" [expr {[idx R2]==1}] "R2=[idx R2]"
check "(d) invalid n=-5: NO log (+0 -- failure not logged)" [expr {[cec]==$c0}] "c0=$c0 now=[cec]"

set c1 [cec]
set rc [catch {xschem change_elem_order} res]
check "(d) bare (argc<3, the OOB class): TCL_ERROR (no crash -- gate before core_log_action reads argv 2)" \
  [expr {$rc==1}] "rc=$rc"
check "(d) bare: NON-EMPTY verb-named message" [expr {[string match {*change_elem_order*needs*} $res]}] "res=>$res<"
check "(d) bare: NO log (+0)" [expr {[cec]==$c1}] "c1=$c1 now=[cec]"

# ---------------------------------------------------------------------------
# (e) UNDO DEPTH = single push: the core owns ONE push_undo on the first mutation. ONE undo
#     restores the pre-reorder order. A double-push would leave R2 at idx0 after one undo.
# ---------------------------------------------------------------------------
fixture
xschem select instance 1
xschem change_elem_order 0
check "(e) after reorder: R2=idx0" [expr {[idx R2]==0}] "R2=[idx R2]"
xschem undo
check "(e) ONE undo restores R1=idx0 R2=idx1 (single push -- a double-push would leave R2 at idx0)" \
  [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"

# ---------------------------------------------------------------------------
# (f) SHIFT-S KEY EQUIVALENCE (callback injection): keysym 83 ('S') state 0 -> case 'S' rstate==0
#     -> change_elem_order(-1) (input_line stubbed to target idx0) -> mutates + logs byte-exact
#     `xschem change_elem_order -1` exactly +1 (identical to the scripted form).
# ---------------------------------------------------------------------------
fixture
check "(f) pre: R1=idx0 R2=idx1" [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"
xschem select instance 1        ;# R2 (idx1)
set ::paw_il_target 0           ;# user types 0 -> move R2 to idx0
set ::paw_il_calls 0
set c0 [cec]
xschem callback .drw 2 300 300 83 0 0 0
check "(f) Shift-S invoked input_line (the n<0 dialog path)" [expr {$::paw_il_calls>=1}] "calls=$::paw_il_calls"
check "(f) Shift-S mutated: R2 -> idx0" [expr {[idx R2]==0}] "R2=[idx R2]"
check "(f) Shift-S logs byte-exact 'xschem change_elem_order -1' exactly +1 (== scripted form)" \
  [expr {[cecpat {xschem change_elem_order -1}]==1 && [cec]==$c0+1}] \
  "exact=[cecpat {xschem change_elem_order -1}] c0=$c0 now=[cec]"

# ---------------------------------------------------------------------------
# (g) REPLAY. change_elem_order is SELECTION-dependent (the 0005 class, like floaters/attach_labels)
#     -- the recorded line names no referent, so the fixture re-selects before replay. Through the
#     replay_action_log suppress seam the effect applies but does NOT re-log (rides
#     !actionlog_suppress); a control unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_ceo_[pid].log]
set fd [open $rec w]; puts $fd "xschem change_elem_order 0"; close $fd

fixture
xschem select instance 1
set nc [cec]
replay_action_log $rec
check "(g) replay seam: EFFECT applied (R2 -> idx0)" [expr {[idx R2]==0}] "R2=[idx R2]"
check "(g) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[cec]==$nc}] "nc=$nc now=[cec]"

fixture
xschem select instance 1
set nc [cec]
uplevel #0 [list source $rec]
check "(g) control (unwrapped source): EFFECT applied (R2 -> idx0)" [expr {[idx R2]==0}] "R2=[idx R2]"
check "(g) control (unwrapped source): re-logged (+1, re-executable action)" [expr {[cec]==$nc+1}] "nc=$nc now=[cec]"
file delete $rec

# ---------------------------------------------------------------------------
# (h) SHARED SUB-STEP stays SILENT (adversarial-review MINOR / the attach_labels atom-11 lock):
#     `instance_number inst <n>` (scheduler.c) calls change_elem_order() RAW as a sub-step -- it is
#     OFF the boundary, logged NOTHING pre-migration, and must still log NOTHING. Runtime lock: the
#     grep-guard scans only scheduler.c/callback.c, so a future self-log added in editprop.c would
#     escape it -- this check catches that (a spurious `change_elem_order` line from the raw path).
# ---------------------------------------------------------------------------
fixture
set c0 [cec]
xschem instance_number R1 1     ;# mutating form (argc>3): selects R1, reorders it to idx1
check "(h) instance_number mutating form reordered (R1 -> idx1)" [expr {[idx R1]==1}] "R1=[idx R1]"
check "(h) instance_number sub-step logs NO change_elem_order line (+0 -- raw core, off the boundary)" \
  [expr {[cec]==$c0}] "c0=$c0 now=[cec]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
