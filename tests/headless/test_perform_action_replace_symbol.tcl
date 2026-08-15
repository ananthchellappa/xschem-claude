# perform_action() BOUNDARY -- Refactor B ATOM 14: the SECOND VALIDATING verb, and
# the FIRST per-verb migration to carry a FAST-FLAG log gate (audit §34 / §33 / §4).
#
# This atom is a PLAIN per-verb migration onto the UNCHANGED atom-13 boundary
# (log-on-success). It touches NO shared machinery -- the log-on-success change atom 13
# made handles replace_symbol's validation failures FOR FREE. What is NEW here is the
# FAST FLAG: `xschem replace_symbol <inst> <sym> fast` is a multi-substitution machinery
# sub-mode that skips BOTH the undo AND the log (the atom-4 `save fast` axis applied to a
# per-verb log form for the first time).
#
# replace_symbol swaps an instance's symbol for another (delete_inst_node + inst.name =
# rel_sym_path(sym) + match_symbol + new_prop_string; a prefix change may rename the
# instance, e.g. R1 -> C1 when swapping devices/res.sym -> devices/capa.sym). Migration:
#   - Branch (scheduler.c, xschem_cmds_r) -> `return perform_action("replace_symbol", argc, argv)`.
#   - run_core arm: the fast-flag parse + the two validation gates (argc!=4 "needs 2
#     additional arguments"; get_instance(argv[2])<0 "instance not found") MOVE in, BEFORE
#     the single (non-fast) push_undo, so a bad arg mutates nothing and (via log-on-success)
#     logs nothing. draw() stays COMMENTED-OUT (caller redraws -- old branch behaviour).
#   - core_log_action arm: `xschem replace_symbol <inst> <sym>` via log_action_argv
#     (Tcl_Merge) -- BOTH argv[2] (the instance referent) AND argv[3] (the symbol path) can
#     carry Tcl metacharacters, so both are brace-quoted for replay (the atom-13 arrayed-name
#     lesson). GATED on !fast (the fast form logs nothing).
#
# Entry map: replace_symbol has NO key, NO menu, NO other C/Tcl caller -- it is a PURE
# SCRIPTED verb (verified by grepping keybindings/mousebindings/actions.csv, xschem.tcl
# -command, callback.c act_*, and C Tcl_Eval). So there is NO callback.c edit and NO
# key-equivalence decision (like reset_inst_prop §33, unlike toggle_ignore's Shift+T §32).
# The migration is purely ADDITIVE coverage: the old branch NEVER logged.
#
# Checks:
#   (a) SUCCESS: the script entry -> exactly +1 log line + the swap applies (cell::name
#       res.sym -> devices/capa.sym) + byte-exact `xschem replace_symbol R1 devices/capa.sym`.
#   (a2) REPLAY-SAFE REFERENT (the atom-13 arrayed-name lesson): an arrayed instance name
#       `x2[3:0]` is logged BRACE-QUOTED via Tcl_Merge (`xschem replace_symbol {x2[3:0]}
#       devices/capa.sym`), and that EXACT line REPLAYS without a Tcl error and re-applies
#       the swap. A raw %s form would replay `[3:0]` as a command substitution.
#   (b) THE VALIDATING-CLASS HEADLINE (atom-13 log-on-success, inherited): no-arg + one-arg
#       (argc!=4) and bogus-name (not found) each return TCL_ERROR, set a NON-EMPTY
#       verb-named message, mutate NOTHING, and log +0. A failed call records no replayable line.
#   (c) READONLY reject: TCL_ERROR, verb-named read-only message (non-empty), no mutation, no log.
#   (d) REPLAY: the recorded self-contained line re-EXECUTES through the replay_action_log
#       suppress seam but does NOT re-log; a control unwrapped `source` DOES re-log.
#   (e) FAST-FORM NOT LOGGED + NO UNDO (the NEW fast-gate lock, the atom-4 save-fast analogue):
#       `xschem replace_symbol R1 devices/capa.sym fast` SWAPS the symbol but emits +0 log AND
#       pushes NO undo -- so ONE undo does NOT restore the pre-fast symbol (it removes the
#       instance entirely: the fixture's place snapshot is the only one on the stack).
#   (f) UNDO DEPTH (non-fast, the atom-1 no-double-push rule): run_core owns replace_symbol's
#       SINGLE push_undo (non-fast). ONE undo restores the prior symbol (capa -> res) and a
#       SECOND undo removes the instance. A spurious run_core double-push would leave an
#       identical extra snapshot so the symbol would survive the first undo.
#
# Effect oracle (byte-identical effect before/after atom 14 -- the migration MOVES validation
# + gates the log, it does not change the swap): a devices/res.sym resistor placed at the
# origin as R1; `xschem replace_symbol R1 devices/capa.sym` swaps its symbol, so `xschem
# getprop instance 0 cell::name` goes `res.sym` -> `devices/capa.sym` (and the instance is
# renamed R1 -> C1 by the capa prefix). Determined empirically on the pre-migration binary.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_replace_symbol.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §34

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X".)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counters (the recorded verbs are single-line, so match the whole line).
proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc rc {} { return [logcount {xschem replace_symbol R1 devices/capa.sym}] } ;# success line
# ANY replace_symbol* line -- to prove a FAILED / FAST call logs NOTHING (not even a variant).
proc rc_any {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem replace_symbol*} $l]} { incr n } }
  return $n
}
proc cell {} { return [xschem getprop instance 0 cell::name] }

# Fixture: a devices/res.sym resistor placed at the origin as R1. A successful swap to
# devices/capa.sym is observable as cell::name res.sym -> devices/capa.sym. replace_symbol
# targets by NAME, so no selection is needed.
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: the ONE script entry (no key, no menu wrapper) -> exactly +1 log line,
#     the swap applies, and the logged line is the self-contained name form.
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: res.sym in place (cell=res.sym)" [expr {[cell] eq "res.sym"}] "cell=[cell]"
set c0 [rc]
set r [xschem replace_symbol R1 devices/capa.sym]
check "(a) scripted 'xschem replace_symbol R1 devices/capa.sym' -> exactly +1" [expr {[rc] == $c0 + 1}] "c0=$c0 now=[rc]"
check "(a) scripted: swap applied (cell res.sym -> devices/capa.sym)" [expr {[cell] eq "devices/capa.sym"}] "cell=[cell]"
check "(a) scripted: success interp result CLEARED by the boundary (old instname result dropped)" [expr {$r eq ""}] "r=>$r<"
# byte-exact: Tcl_Merge quotes MINIMALLY, so a plain refdes + path logs unbraced.
set fd [open [xschem get actionlog_filename] r]; set allR1 [read $fd]; close $fd
set exactR1 ""
foreach l [split $allR1 \n] { if {$l eq {xschem replace_symbol R1 devices/capa.sym}} { set exactR1 $l } }
check "(a) logged line is byte-exact 'xschem replace_symbol R1 devices/capa.sym' (Tcl_Merge unbraced for a plain refdes+path)" \
  [expr {$exactR1 eq "xschem replace_symbol R1 devices/capa.sym"}] "got=>$exactR1<"

# (a2) REPLAY-SAFE REFERENT (the atom-13 arrayed-name lesson). An arrayed/bussed instance
# name carries Tcl metacharacters -- `x2[3:0]` (its instname is literally `x2[3:0]`). A RAW
# `xschem replace_symbol x2[3:0] devices/capa.sym` line would replay `[3:0]` as a Tcl command
# substitution ("invalid command name 3:0"); the log MUST Tcl-quote the referent
# (log_action_argv/Tcl_Merge -> `xschem replace_symbol {x2[3:0]} devices/capa.sym`). Assert
# the logged line is brace-quoted AND that replaying that EXACT line re-resolves + swaps.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0]}
xschem redraw
set nm [xschem getprop instance 0 name]
check "(a2) arrayed instance instname is literally x2\[3:0\]" [string equal $nm {x2[3:0]}] "name=$nm"
xschem replace_symbol {x2[3:0]} devices/capa.sym
check "(a2) arrayed name: swap applied (cell -> devices/capa.sym)" [expr {[cell] eq "devices/capa.sym"}] "cell=[cell]"
set fd [open [xschem get actionlog_filename] r]; set allA [read $fd]; close $fd
set exactA ""
foreach l [split $allA \n] { if {[string match {xschem replace_symbol *x2*} $l]} { set exactA $l } }
check "(a2) arrayed name logged BRACE-QUOTED (Tcl_Merge), not raw" \
  [expr {$exactA eq {xschem replace_symbol {x2[3:0]} devices/capa.sym}}] "got=>$exactA<"
# replay-safety: re-place x2[3:0], eval the EXACT logged line, assert it resolved (no Tcl error) + swapped.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0]}
xschem redraw
set rrc [catch {uplevel #0 $exactA} rres]
check "(a2) arrayed name: the logged line REPLAYS without a Tcl error (metachar-safe)" \
  [expr {$rrc == 0}] "rc=$rrc res=>$rres<"
check "(a2) arrayed name: replay applied the swap (cell -> devices/capa.sym)" [expr {[cell] eq "devices/capa.sym"}] "cell=[cell]"

# ---------------------------------------------------------------------------
# (b) THE VALIDATING-CLASS HEADLINE -- FAILURE IS NOT LOGGED, and the error message SURVIVES.
#   * no-arg / one-arg -> argc!=4 -> TCL_ERROR "needs 2 additional arguments", +0 log, no swap.
#   * bogus            -> not found -> TCL_ERROR "instance not found",            +0 log, no swap.
#   The message-non-empty check is the landmine proof (atom-13 success-only Tcl_ResetResult).
# ---------------------------------------------------------------------------
fixture
set t0 [cell]
set a0 [rc_any]
set e1 [catch {xschem replace_symbol} m1]
check "(b) no-arg: TCL_ERROR" [expr {$e1 == 1}] "rc=$e1"
check "(b) no-arg: NON-EMPTY verb-named message (landmine: Tcl_ResetResult did not wipe it)" \
  [expr {[string match {*replace_symbol*additional arguments*} $m1]}] "msg=>$m1<"
check "(b) no-arg: NO log line (+0 -- failure not logged)" [expr {[rc_any] == $a0}] "a0=$a0 now=[rc_any]"
check "(b) no-arg: NO mutation" [expr {[cell] eq $t0}] "before=$t0 after=[cell]"

set a1 [rc_any]
set e1b [catch {xschem replace_symbol R1} m1b]
check "(b) one-arg: TCL_ERROR" [expr {$e1b == 1}] "rc=$e1b"
check "(b) one-arg: NON-EMPTY verb-named message" \
  [expr {[string match {*replace_symbol*additional arguments*} $m1b]}] "msg=>$m1b<"
check "(b) one-arg: NO log line (+0)" [expr {[rc_any] == $a1}] "a1=$a1 now=[rc_any]"
check "(b) one-arg: NO mutation" [expr {[cell] eq $t0}] "before=$t0 after=[cell]"

set a2 [rc_any]
set e2 [catch {xschem replace_symbol bogus_name devices/capa.sym} m2]
check "(b) bogus-name: TCL_ERROR" [expr {$e2 == 1}] "rc=$e2"
check "(b) bogus-name: NON-EMPTY verb-named message (landmine)" \
  [expr {[string match {*replace_symbol*not found*} $m2]}] "msg=>$m2<"
check "(b) bogus-name: NO log line (+0 -- failure not logged)" [expr {[rc_any] == $a2}] "a2=$a2 now=[rc_any]"
check "(b) bogus-name: NO mutation" [expr {[cell] eq $t0}] "before=$t0 after=[cell]"

# ---------------------------------------------------------------------------
# (c) READONLY reject: the boundary's ONE generic gate refuses -> TCL_ERROR, verb-named
#     read-only message (non-empty), NO mutation, NO log.
# ---------------------------------------------------------------------------
fixture
set t0 [cell]
xschem set readonly 1
set a0 [rc_any]
set e3 [catch {xschem replace_symbol R1 devices/capa.sym} m3]
check "(c) readonly: TCL_ERROR" [expr {$e3 == 1}] "rc=$e3"
check "(c) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*replace_symbol*read-only*} $m3]}] "msg=>$m3<"
check "(c) readonly: NO log line (+0)" [expr {[rc_any] == $a0}] "a0=$a0 now=[rc_any]"
check "(c) readonly: NO mutation" [expr {[cell] eq $t0}] "before=$t0 after=[cell]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY. replace_symbol is a self-contained, re-executable verb (name + symbol in the
#     line): replaying re-runs the swap. Through the replay_action_log suppress seam the
#     effect applies but does NOT re-log; a control unwrapped `source` DOES re-log. The
#     fixture pre-establishes R1 (res.sym) so the recorded swap is observable.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_replace_symbol_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem replace_symbol R1 devices/capa.sym"; close $fd

fixture
set nc [rc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (cell -> devices/capa.sym)" [expr {[cell] eq "devices/capa.sym"}] "cell=[cell]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[rc] == $nc}] "nc=$nc now=[rc]"

fixture
set nc [rc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (cell -> devices/capa.sym)" [expr {[cell] eq "devices/capa.sym"}] "cell=[cell]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[rc] == $nc + 1}] "nc=$nc now=[rc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) FAST-FORM NOT LOGGED + NO UNDO -- the NEW fast-gate lock (the atom-4 save-fast analogue).
#     `xschem replace_symbol R1 devices/capa.sym fast` is a multi-substitution machinery
#     sub-mode: it SWAPS the symbol (mutation observable) but emits +0 log AND pushes NO
#     undo. The fixture's undo stack holds ONLY the instance-place snapshot, so ONE undo
#     removes the instance entirely -- it does NOT restore the pre-fast res.sym (a fast form
#     that mistakenly pushed undo would leave res.sym as an intermediate state, instance
#     count 1 after one undo).
# ---------------------------------------------------------------------------
fixture
set c0 [rc_any]
set rf [xschem replace_symbol R1 devices/capa.sym fast]
check "(e) fast: swap APPLIED (cell -> devices/capa.sym)" [expr {[cell] eq "devices/capa.sym"}] "cell=[cell]"
check "(e) fast: NO log line (+0 -- the fast machinery sub-mode is not logged)" [expr {[rc_any] == $c0}] "c0=$c0 now=[rc_any]"
xschem undo
check "(e) fast: NO undo pushed -- ONE undo REMOVES the instance (does NOT restore res.sym); a fast push_undo would leave 1 instance at res.sym" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (non-fast, the atom-1 no-double-push rule): run_core owns replace_symbol's
#     SINGLE push_undo (captured BEFORE the swap, so the snapshot is res.sym). The fixture's
#     undo stack holds the instance-place snapshot + the swap's ONE push. So ONE undo
#     restores the prior symbol (capa -> res) and a SECOND undo removes the instance. A
#     spurious run_core double-push would capture the SAME pre-swap state, so the symbol
#     would survive the first undo (two undos needed) and the instance both.
# ---------------------------------------------------------------------------
fixture
xschem replace_symbol R1 devices/capa.sym
check "(f) undo depth: swap applied (cell -> devices/capa.sym)" [expr {[cell] eq "devices/capa.sym"}] "cell=[cell]"
xschem undo
check "(f) undo depth: ONE undo restores the prior symbol (capa -> res.sym) with the instance intact" \
  [expr {[xschem get instances] == 1 && [cell] eq "res.sym"}] "instances=[xschem get instances] cell=[cell]"
xschem undo
check "(f) undo depth: a SECOND undo removes the instance (R1 gone) -- replace_symbol's single push_undo is the ONLY swap snapshot; a run_core double-push would leave an identical extra one so the symbol would survive the first undo" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
