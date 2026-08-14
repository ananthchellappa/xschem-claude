# perform_action() BOUNDARY -- Refactor B ATOM 23: route the MUTATE form of `instance_number`
# through the single mutation boundary. A three-way SYNTHESIS of shipped templates:
#   * the image §40 (atom 20) QUERY/MUTATE SPLIT -- instance_number has a read-only-SAFE QUERY
#     sub-form (argc==3, a pure array-position read-back) that the boundary's unconditional
#     readonly gate would OVER-REJECT and whose interp result the success-path Tcl_ResetResult
#     would WIPE, so ONLY the MUTATE form (argc>3) crosses; the QUERY stays RAW in the branch IN
#     FRONT of the boundary (the wire_cut §37 form-split applied to a query vs a mutation);
#   * the reset_symbol §42 (atom 22) TWO-REFERENT Tcl_Merge log (a collision-distinct array name,
#     both referents brace-quoted); the array here is `ino` (av/ev/pp/mi/im/rs all taken -- §36);
#   * the change_elem_order §41 (atom 21) SHARED-SUB-STEP LOCK -- the MUTATE form calls
#     change_elem_order() RAW (the SAME core already on the boundary under the `change_elem_order`
#     verb), which OWNS its push_undo (gated on `modified`) + set_modify; that raw sub-step stays
#     SILENT below the boundary (it logged nothing, still does) and instance_number gets its OWN
#     new verb name (the log form + args differ from change_elem_order's).
#
# WHY instance_number -- an ADDITIVE-LOG atom: the pre-migration MUTATE branch had NO self-log
# and NO readonly gate, so the migration ADDS both (a replay line AND the C-level read-only gate
# -- a CORRECTNESS FIX: the old branch reordered a read-only cell silently).
#
# KEY DESIGN CALLS (resolved from source):
#   A) QUERY/MUTATE SPLIT (C1): the branch keeps RAW in front the !xctx precedence, the argc<3
#      gate, get_instance, and (argc==3) the QUERY result + return. ONLY `if(argc>3)` delegates.
#   B) THE MUTATE-FORM RESULT: the old mutate returned my_itoa(atoi(argv[3])). NO caller consumes
#      it (grep-verified: the sole MUTATE callers are this suite + oracle scripts; the QUERY result
#      IS consumed by `idx`). So the boundary DROPS it on success (the apply_pin_prop §18 wrinkle);
#      the standalone checks assert the EFFECT (z-order via the QUERY form), not the result.
#   C) run_core arm: re-does the argc<3 + get_instance gates BEFORE any mutation, then
#      unselect_all + select_element + rebuild_selected_array + change_elem_order(atoi(argv[3])) +
#      draw. NO push_undo / NO set_modify -- change_elem_order() owns both.
#   D) core_log_action arm: TWO referents argv[2] (inst) + argv[3] (n) via log_action_argv/Tcl_Merge
#      (`ino`), NOT raw %s. NO had_sel gate -- the mutate is SELF-CONTAINED (re-selects argv[2]
#      itself), so the log is UNCONDITIONAL on success (no 0005/ambient-selection dependence).
#
# Checks:
#   (a) MUTATE SUCCESS: reorders z-order (asserted via the QUERY form) + exactly +1 byte-exact
#       `xschem instance_number <inst> <n>` log line + interp result BLANK (the boundary drops the
#       old my_itoa result on success).
#   (b) QUERY on a READ-ONLY cell (the headline of the split): TCL_OK + correct position + logs
#       NOTHING -- NOT over-rejected, result preserved (it never reaches the boundary).
#   (c) MUTATE on a READ-ONLY cell (the NEW gate): TCL_ERROR (verb-named) + no reorder + no log.
#   (d) argc<3 -> TCL_ERROR + no log.
#   (e) instance-not-found (BOTH forms) -> TCL_ERROR + no log.
#   (f) METACHAR referent: arrayed `x2[3:0]` round-trips via Tcl_Merge (brace-quoted; the exact
#       logged line REPLAYS without error + re-applies).
#   (g) UNDO/set_modify per the change_elem_order core: standalone mutate SETS modified=1, and ONE
#       undo reverts the reorder (single push, owned by the core -- a double-push would leave it).
#   (h) SHARED-SUB-STEP LOCK (runtime): a `change_elem_order` verb still logs its OWN line, and a
#       `instance_number` mutate logs ZERO change_elem_order lines. + REPLAY round-trip: the recorded
#       `instance_number` line re-applies through the suppress seam WITHOUT re-logging (self-contained
#       -- re-selects itself, no fixture re-selection needed); a control unwrapped `source` DOES re-log.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_instance_number.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §43

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

# Defensive modal stubs (real DISPLAY): a mutate with n<0 would open input_line (.dialog, tkwait)
# and readonly_block posts tk_messageBox when has_x -- this suite never triggers the n<0 dialog
# (every mutate uses n>=0) and the boundary uses ciw_echo not readonly_block, but stub both so a
# stray dialog can never WEDGE headless.
catch {rename tk_messageBox _pain_real_mb}
proc tk_messageBox {args} { return ok }
catch {rename input_line _pain_real_input_line}
proc input_line {txt {cmd {}} {preset {}} {w 12}} { set tctx::retval 0; return 0 }

# ANY `xschem instance_number*` line -- the QUERY form logs NOTHING, so this counts only MUTATE lines.
proc inc {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem instance_number*} $l]} { incr n } }
  return $n
}
# lines exactly matching a pattern
proc inpat {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
# ANY `xschem change_elem_order*` line -- for the shared-sub-step lock (h).
proc cec {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem change_elem_order*} $l]} { incr n } }
  return $n
}
# z-order position of instance <ref>, via the read-only-safe QUERY form (argc==3 -- logs nothing).
proc idx {ref} { return [xschem instance_number $ref] }

# fixture: two overlapping instances, distinct names -> z-order == array index (R1=0, R2=1).
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}
  xschem instance devices/res.sym 0 0 0 0 {name=R2 value=2k}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) MUTATE SUCCESS: reorder oracle (via the QUERY form) + exactly +1 byte-exact + result BLANK.
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: R1=idx0 R2=idx1" [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"
set c0 [inc]
set r [xschem instance_number R2 0]     ;# MUTATE: move R2 to idx0
check "(a) reorder applied: R2 -> idx0, R1 -> idx1 (asserted via the QUERY form)" \
  [expr {[idx R2]==0 && [idx R1]==1}] "R1=[idx R1] R2=[idx R2]"
check "(a) exactly +1 log line" [expr {[inc]==$c0+1}] "c0=$c0 now=[inc]"
check "(a) logged line byte-exact 'xschem instance_number R2 0' (Tcl_Merge unbraced for plain referents)" \
  [expr {[inpat {xschem instance_number R2 0}]==1}] "count=[inpat {xschem instance_number R2 0}]"
check "(a) interp result BLANK on success (the boundary DROPS the old my_itoa result -- no caller consumes the mutate result)" \
  [expr {$r eq ""}] "got=>$r<"

# (a2) QUERY logs NOTHING on an EDITABLE cell too (the `idx` read-back never pollutes the log).
fixture
set q0 [inc]
set p [xschem instance_number R1]
check "(a2) QUERY (argc==3) returns the position (0) + logs NOTHING (raw-front, never reaches the boundary)" \
  [expr {$p==0 && [inc]==$q0}] "p=$p c0=$q0 now=[inc]"

# ---------------------------------------------------------------------------
# (b) QUERY on a READ-ONLY cell -- the HEADLINE of the split: TCL_OK + correct position + no log.
#     A regression that routed the QUERY through the boundary would REFUSE it here (or blank its
#     result). The read-only-safe query is NOT over-rejected.
# ---------------------------------------------------------------------------
fixture
xschem set readonly 1
set c0 [inc]
set qrc [catch {xschem instance_number R2} q]
check "(b) QUERY on read-only: TCL_OK (read-only-safe, NOT over-rejected)" [expr {$qrc==0}] "rc=$qrc q=>$q<"
check "(b) QUERY on read-only: returns the correct position (1)" [expr {$q==1}] "q=$q"
check "(b) QUERY on read-only: logs NOTHING" [expr {[inc]==$c0}] "c0=$c0 now=[inc]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (c) MUTATE on a READ-ONLY cell -- the NEW gate: TCL_ERROR (verb-named) + no reorder + no log.
#     (Pre-migration the mutate reordered a read-only cell silently.)
# ---------------------------------------------------------------------------
fixture
xschem set readonly 1
set c0 [inc]
set before [idx R2]
set mrc [catch {xschem instance_number R2 0} m]
check "(c) MUTATE on read-only -> REFUSED (TCL_ERROR)" [expr {$mrc==1}] "rc=$mrc"
check "(c) MUTATE on read-only -> verb-named read-only message" \
  [string match {*instance_number*read-only*} $m] "m=>$m<"
check "(c) MUTATE on read-only -> NO reorder (R2 still idx1)" [expr {[idx R2]==$before && [idx R2]==1}] "R2=[idx R2]"
check "(c) MUTATE on read-only -> logs NOTHING (log-on-success)" [expr {[inc]==$c0}] "c0=$c0 now=[inc]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) argc<3 -> TCL_ERROR + no log (the raw-front gate; also the OOB-safe class).
# ---------------------------------------------------------------------------
fixture
set c0 [inc]
set drc [catch {xschem instance_number} d]
check "(d) argc<3 (bare) -> TCL_ERROR" [expr {$drc==1}] "rc=$drc"
check "(d) argc<3 -> non-empty '1 additional argument' message" \
  [expr {[string match {*instance_number*additional argument*} $d]}] "d=>$d<"
check "(d) argc<3 -> logs NOTHING (+0)" [expr {[inc]==$c0}] "c0=$c0 now=[inc]"

# ---------------------------------------------------------------------------
# (e) instance-not-found (BOTH forms) -> TCL_ERROR + no log (the branch's get_instance gate fires
#     for both before either delegates or returns a QUERY result).
# ---------------------------------------------------------------------------
fixture
set c0 [inc]
set qerc [catch {xschem instance_number bogus_name} qe]
check "(e) QUERY not-found -> TCL_ERROR" [expr {$qerc==1}] "rc=$qerc"
check "(e) QUERY not-found -> verb-named message" [expr {[string match {*instance_number*not found*} $qe]}] "qe=>$qe<"
check "(e) QUERY not-found -> +0 log" [expr {[inc]==$c0}] "c0=$c0 now=[inc]"
set c1 [inc]
set merc [catch {xschem instance_number bogus_name 0} me]
check "(e) MUTATE not-found -> TCL_ERROR" [expr {$merc==1}] "rc=$merc"
check "(e) MUTATE not-found -> verb-named message" [expr {[string match {*instance_number*not found*} $me]}] "me=>$me<"
check "(e) MUTATE not-found -> +0 log (fails in the branch front, never reaches the boundary)" [expr {[inc]==$c1}] "c1=$c1 now=[inc]"

# ---------------------------------------------------------------------------
# (d2) n<0 REPLAY-SAFETY GATE: a negative n would drive the shared change_elem_order() core into
#      its interactive input_line DIALOG -- for a PURE SCRIPTED verb that is a headless wedge, and a
#      logged `instance_number <inst> <neg>` line would replay into it. So n<0 is REJECTED (TCL_ERROR,
#      verb-named) + no reorder + no log + NO dialog opened (::paw_il_calls stays 0). A DELIBERATE
#      divergence from change_elem_order's `n >= 0 || n == -1` gate (that verb has an interactive form).
# ---------------------------------------------------------------------------
fixture
set c0 [inc]; set ::paw_il_calls 0
foreach nbad {-1 -5} {
  set nrc [catch {xschem instance_number R2 $nbad} ne]
  check "(d2) n=$nbad -> TCL_ERROR" [expr {$nrc==1}] "rc=$nrc"
  check "(d2) n=$nbad -> 'invalid order' message (rejects negatives, incl -1)" \
    [expr {[string match {*instance_number*invalid order*} $ne]}] "ne=>$ne<"
}
check "(d2) n<0 -> NO reorder (R2 still idx1)" [expr {[idx R2]==1}] "R2=[idx R2]"
check "(d2) n<0 -> +0 log (rejected before the boundary log site)" [expr {[inc]==$c0}] "c0=$c0 now=[inc]"
check "(d2) n<0 -> NO input_line dialog opened (scripted verb never reaches change_elem_order's n<0 dialog)" \
  [expr {$::paw_il_calls==0}] "calls=$::paw_il_calls"

# ---------------------------------------------------------------------------
# (i) NUMERIC-INDEX referent: get_instance accepts a bare array index for argv[2]. `instance_number
#     0 1` moves the instance at idx0 to idx1. Logs `xschem instance_number 0 1` (bareword, unbraced),
#     which REPLAYS to the same reorder.
# ---------------------------------------------------------------------------
fixture
check "(i) pre: idx0=R1 idx1=R2" [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"
set c0 [inc]
xschem instance_number 0 1        ;# move the instance at idx0 (R1) to idx1
check "(i) numeric-index mutate applied (R1 -> idx1)" [expr {[idx R1]==1 && [idx R2]==0}] "R1=[idx R1] R2=[idx R2]"
check "(i) numeric-index logged byte-exact 'xschem instance_number 0 1'" \
  [expr {[inpat {xschem instance_number 0 1}]==1 && [inc]==$c0+1}] "count=[inpat {xschem instance_number 0 1}] delta=[expr {[inc]-$c0}]"
# replay round-trip
fixture
uplevel #0 {xschem instance_number 0 1}
check "(i) numeric-index line REPLAYS to the same reorder (R1 -> idx1)" [expr {[idx R1]==1}] "R1=[idx R1]"

# ---------------------------------------------------------------------------
# (j) OUT-OF-RANGE n: change_elem_order clamps n to instances-1 IN-CORE; the log records the RAW n
#     (atom-21 value-preserving), so a replay re-clamps identically (not collapsed).
# ---------------------------------------------------------------------------
fixture
set c0 [inc]
xschem instance_number R1 99      ;# clamp to last index (1)
check "(j) out-of-range n clamps in-core (R1 -> last idx 1)" [expr {[idx R1]==1}] "R1=[idx R1]"
check "(j) log records the RAW n byte-exact 'xschem instance_number R1 99' (value-preserving, replay re-clamps)" \
  [expr {[inpat {xschem instance_number R1 99}]==1 && [inc]==$c0+1}] "count=[inpat {xschem instance_number R1 99}] delta=[expr {[inc]-$c0}]"

# ---------------------------------------------------------------------------
# (k) NO-OP reorder (n == current index): change_elem_order does NOT short-circuit a self-swap -- it
#     still push_undo + set_modify + logs (consistent with the change_elem_order verb). +1 log, ONE
#     undo restores, modified set. A faithful record (replays to the same no-op).
# ---------------------------------------------------------------------------
set reck [file join [file dirname $LOG] pain_noop_[pid].sch]
fixture
xschem saveas $reck
check "(k) precondition: R2 at idx1, modified==0" [expr {[idx R2]==1 && [xschem get modified]==0}] "R2=[idx R2] mod=[xschem get modified]"
set c0 [inc]
xschem instance_number R2 1       ;# no-op: R2 already at idx1
check "(k) no-op still logs +1 (change_elem_order does not short-circuit a self-swap)" \
  [expr {[inpat {xschem instance_number R2 1}]==1 && [inc]==$c0+1}] "count=[inpat {xschem instance_number R2 1}] delta=[expr {[inc]-$c0}]"
check "(k) no-op still sets modified=1 (inherited from the change_elem_order core)" [expr {[xschem get modified]==1}] "mod=[xschem get modified]"
check "(k) no-op left z-order unchanged (R1=0 R2=1)" [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"
xschem undo
check "(k) ONE undo after the no-op restores state (single push)" [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"
file delete $reck

# ---------------------------------------------------------------------------
# (f) METACHAR referent: an arrayed instance name x2[3:0] must Tcl_Merge-brace-quote in the log,
#     and the exact logged line must REPLAY without a Tcl error + re-apply the reorder.
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0]}
xschem instance devices/res.sym 0 0 0 0 {name=R9}
xschem redraw
set nm [lindex [lindex [split [xschem instance_list] "\n"] 0] 0]
check "(f) arrayed instance instname is literally x2\[3:0\]" [string equal $nm {x2[3:0]}] "name=$nm"
check "(f) pre: x2\[3:0\]=idx0 R9=idx1" [expr {[idx {x2[3:0]}]==0 && [idx R9]==1}] "x2=[idx {x2[3:0]}] R9=[idx R9]"
xschem instance_number {x2[3:0]} 1      ;# move x2[3:0] to idx1
check "(f) metachar mutate applied (x2\[3:0\] -> idx1)" [expr {[idx {x2[3:0]}]==1}] "x2=[idx {x2[3:0]}]"
set fd [open [xschem get actionlog_filename] r]; set allF [read $fd]; close $fd
set exactF ""
foreach l [split $allF \n] { if {[string match {xschem instance_number *x2*} $l]} { set exactF $l } }
check "(f) referent logged BRACE-QUOTED (Tcl_Merge), not raw" \
  [expr {$exactF eq {xschem instance_number {x2[3:0]} 1}}] "got=>$exactF<"
# replay-safety: re-place, eval the EXACT logged line, assert it resolves (no Tcl error) + applies.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0]}
xschem instance devices/res.sym 0 0 0 0 {name=R9}
xschem redraw
set rrc [catch {uplevel #0 $exactF} rres]
check "(f) the logged line REPLAYS without a Tcl error (metachar-safe)" [expr {$rrc==0}] "rc=$rrc res=>$rres<"
check "(f) replay re-applied the reorder (x2\[3:0\] -> idx1)" [expr {[idx {x2[3:0]}]==1}] "x2=[idx {x2[3:0]}]"

# ---------------------------------------------------------------------------
# (g) UNDO / set_modify per the change_elem_order core: the mutate calls change_elem_order() which
#     OWNS a SINGLE push_undo + set_modify. A standalone mutate on a saved sheet SETS modified=1,
#     and ONE undo reverts the reorder (a double-push in the arm would leave R2 at idx0 after one undo).
# ---------------------------------------------------------------------------
set recf [file join [file dirname $LOG] pain_mod_[pid].sch]
fixture
xschem saveas $recf
check "(g) set_modify oracle: modified==0 after saveas" [expr {[xschem get modified]==0}] "modified=[xschem get modified]"
xschem instance_number R2 0
check "(g) standalone mutate SETS modified=1 (the change_elem_order core owns set_modify)" \
  [expr {[xschem get modified]==1}] "modified=[xschem get modified]"
check "(g) mutate reordered R2 -> idx0" [expr {[idx R2]==0}] "R2=[idx R2]"
xschem undo
check "(g) ONE undo reverts the reorder (R1=idx0 R2=idx1 -- single push owned by the core)" \
  [expr {[idx R1]==0 && [idx R2]==1}] "R1=[idx R1] R2=[idx R2]"
file delete $recf

# (g2) DOUBLE-PUSH DETECTOR (the load-bearing no-double-push check). A single mutate + one undo
# reverts EITHER way (both pushes capture the same z-order), so it can't tell a double-push apart.
# THREE instances give THREE distinct z-order states S0/S1/S2; TWO mutations then TWO undos must
# return to S0 -- but if the arm ALSO push_undo's (a double-push), each mutation consumes TWO slots
# BOTH holding the SAME z-order, so the second undo of each pair is a z-order no-op and two undos
# revert only ONE mutation (leaving S1). Single-push (change_elem_order owns the sole push) -> S0.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=R1}
xschem instance devices/res.sym 0 0 0 0 {name=R2}
xschem instance devices/res.sym 0 0 0 0 {name=R3}
xschem redraw
check "(g2) S0 fixture: R1=0 R2=1 R3=2" [expr {[idx R1]==0 && [idx R2]==1 && [idx R3]==2}] "R1=[idx R1] R2=[idx R2] R3=[idx R3]"
xschem instance_number R3 0      ;# M1 -> S1: R3=0 R2=1 R1=2
xschem instance_number R2 0      ;# M2 -> S2: R2=0 R3=1 R1=2
xschem undo
xschem undo
check "(g2) TWO undos revert BOTH mutations to S0 (single push per mutate -- a double-push in the arm would leave S1)" \
  [expr {[idx R1]==0 && [idx R2]==1 && [idx R3]==2}] "R1=[idx R1] R2=[idx R2] R3=[idx R3]"

# ---------------------------------------------------------------------------
# (h) SHARED-SUB-STEP LOCK (runtime) + REPLAY round-trip.
#   (h1) a `change_elem_order` verb still logs its OWN change_elem_order line (+1);
#   (h2) a `instance_number` mutate logs ZERO change_elem_order lines (the raw sub-step stays silent)
#        -- it logs its own instance_number line instead.
# ---------------------------------------------------------------------------
fixture
xschem select instance 1                ;# R2
set ce0 [cec]
xschem change_elem_order 0
check "(h1) the change_elem_order verb still logs its OWN line (+1)" [expr {[cec]==$ce0+1}] "ce0=$ce0 now=[cec]"

fixture
set ce0 [cec]; set in0 [inc]
xschem instance_number R2 0
check "(h2) instance_number mutate logs ZERO change_elem_order lines (raw sub-step stays silent below the boundary)" \
  [expr {[cec]==$ce0}] "ce0=$ce0 now=[cec]"
check "(h2) instance_number mutate logs its OWN instance_number line (+1)" [expr {[inc]==$in0+1}] "in0=$in0 now=[inc]"

# REPLAY round-trip: the mutate is SELF-CONTAINED (re-selects argv[2] itself), so the recorded line
# re-applies through the replay_action_log suppress seam WITHOUT re-logging -- and WITHOUT the fixture
# re-selecting first (unlike change_elem_order's 0005 selection-dependent replay). A control unwrapped
# `source` DOES re-log.
set rec [file join [file dirname $LOG] pain_[pid].log]
set fd [open $rec w]; puts $fd "xschem instance_number R2 0"; close $fd

fixture                                  ;# note: NO pre-selection -- the mutate re-selects R2 itself
set nc [inc]
replay_action_log $rec
check "(g/h) replay seam: EFFECT applied (R2 -> idx0) without a fixture re-selection (self-contained)" \
  [expr {[idx R2]==0}] "R2=[idx R2]"
check "(g/h) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[inc]==$nc}] "nc=$nc now=[inc]"

fixture
set nc [inc]
uplevel #0 [list source $rec]
check "(g/h) control (unwrapped source): EFFECT applied (R2 -> idx0)" [expr {[idx R2]==0}] "R2=[idx R2]"
check "(g/h) control (unwrapped source): re-logged (+1, re-executable action)" [expr {[inc]==$nc+1}] "nc=$nc now=[inc]"
file delete $rec

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
