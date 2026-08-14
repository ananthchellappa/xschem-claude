# perform_action() BOUNDARY -- Refactor B ATOM 18: the EIGHTEENTH per-verb migration
# (audit §38 / §34 / §33 / §4). A HIGHER-FRICTION coverage gain now the friction-free pool
# is EMPTY -- a symbol-editor mutation that logged NOTHING and had NO C-level read-only gate
# before this atom, carrying an INLINE mutation body (strictly 1:1 with the verb -- C3, there
# is NO shared mutating core to lock, unlike trim_wires/attach_labels) and TWO string referents.
#
# It follows the replace_symbol §34 template (a VALIDATING verb whose validation MOVES IN before
# its single push_undo, whose core_log_action logs TWO referents via log_action_argv/Tcl_Merge,
# and whose success-path interp result is DROPPED) crossed with the reset_inst_prop §33 argc-gate.
#
# apply_pin_prop applies <prop> to the symbol PINLAYER rects named by <scope> (current | selected
# | all; default "selected"), mirroring the pin branch of edit_rect_property without a dialog
# round-trip (cadence_pin_name_text.md; symbol_editor_apply_scope.md). Migration:
#   - Branch (scheduler.c, xschem_cmds_a) -> `return perform_action("apply_pin_prop", argc, argv)`.
#   - run_core arm: the WHOLE inline body MOVES in verbatim -- the argc<3 "needs: [scope] new_prop"
#     validation (early TCL_ERROR BEFORE any mutation), pin_scope_resolve (the SHARED READ-ONLY
#     resolver, stays raw below the boundary), the guard-pass no-op (Tcl_SetResult "0" + TCL_OK,
#     NO push_undo), else the SINGLE push_undo + the apply loop (set_different_token / pin_reorient
#     / pin_view_apply) + set_modify(1) + draw() + Tcl_SetResult "1".
#   - core_log_action arm: TWO forms mirroring the branch's arg resolution --
#       argc>=4 -> `xschem apply_pin_prop <scope> <prop>`  (via log_action_argv(4, pp))
#       argc==3 -> `xschem apply_pin_prop <prop>` (back-compat, "selected" scope; log_action_argv(3, pp))
#     BOTH referents Tcl_Merge-quoted (the <prop> string carries spaces + brackets + braces; the
#     <scope> bareword logs unbraced). The array is named `pp` (NOT av/ev/av[3]) -- the §36
#     collision lesson.
#
# THE RESULT-DROPPED WRINKLE (verified empirically, checks (a)/(b2)/(g)): the OLD branch returned a
# MEANINGFUL "0"/"1" interp result; the boundary's atom-13 success-path Tcl_ResetResult BLANKS it.
# A repo-wide grep found: the PRODUCTION consumer gfxform::do_apply (xschem.tcl) DISCARDS the result
# (a bare statement), so no feature regresses; the ONLY consumers of the return value were two
# STANDALONE tests (symbol_pin_scope.tcl, pin_name_text.tcl) that asserted `== 1` / `== 0` -- those
# were switched to assert the EFFECT (a stronger oracle) as part of this atom. So the drop is safe.
#
# THE READONLY CORRECTNESS FIX (check (c)): the SCRIPTED `xschem apply_pin_prop` had NO C gate.
# Verified empirically on the pre-migration binary -- a scripted apply MUTATED PINLAYER rects on a
# read-only symbol view (name_size actually changed). The migration ADDS the boundary's generic gate:
# a read-only cell now returns TCL_ERROR + a verb-named message + NO apply + NO log. Safe -- the
# guard-pass no-op is a NO-OP, not a read-only-safe QUERY, so the all-or-nothing gate cannot over-reject.
#
# Checks:
#   (a) SUCCESS: the scope form -> exactly +1 `xschem apply_pin_prop selected {<prop>}` log line +
#       the change applies (both selected pins get name_size=0.9, B keeps name=B) + the metachar prop
#       (foo=a[1]) logs BRACE-QUOTED via Tcl_Merge + replays without a Tcl error + re-applies + the
#       interp RESULT is BLANK (dropped by the boundary).
#   (b) argc-gate: bare `xschem apply_pin_prop` -> TCL_ERROR + NON-EMPTY verb-named message + +0 log
#       + NO mutation (the reset_inst_prop §33 validating headline: failure is not logged, message survives).
#   (b2) NO-OP-STILL-LOGS (§30): re-applying the SAME prop returns "" (no-op, no undo) but STILL logs +1.
#   (c) READONLY reject (the correctness fix): TCL_ERROR + verb-named read-only message + NO apply + NO log.
#   (d) back-compat: `xschem apply_pin_prop <prop>` (argc==3) logs the 3-arg form `xschem apply_pin_prop
#       {<prop>}` + applies to the CURRENT selection ("selected" scope).
#   (e) REPLAY: the recorded line re-EXECUTES through the replay_action_log suppress seam but does NOT
#       re-log; a control unwrapped `source` DOES re-log.
#   (f) UNDO DEPTH (the atom-1 no-double-push rule): run_core owns the SINGLE push_undo -- ONE undo
#       restores the prior name_size; a spurious arm double-push would leave the change after one undo.
#   (g) RESULT-DROP + no caller regressed: the boundary blanks the "0"/"1" result AND the production
#       idiom (gfxform::do_apply, which discards the result) still applies the change.
#
# Effect oracle (byte-identical effect before/after atom 18 -- the migration MOVES the body + gates
# the log, it does not change the apply): two PINLAYER pins A,B placed via add_symbol_pin (each
# `name=X dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.2`), both selected (A primary).
# `xschem apply_pin_prop selected {... name_size=0.9}` changed-fields-diffs vs A's prop, so the ONLY
# changed token name_size fans to A AND B (B keeps its own name=B). Determined empirically on the
# pre-migration binary; the readonly-mutates, no-op-"0", argc-gate, and metachar round-trip pinned there.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_apply_pin_prop.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §38

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

# ANY apply_pin_prop* line -- to prove a FAILED call logs NOTHING and to count no-op logs.
proc apc {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem apply_pin_prop*} $l]} { incr n } }
  return $n
}
# lines matching a specific glob
proc apcpat {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
proc szv  {n} { xschem getprop rect 5 $n name_size }
proc showv {n} { xschem getprop rect 5 $n show_pinname }
proc nmv  {n} { xschem getprop rect 5 $n name }

# Fixture: a SYMBOL VIEW with two PINLAYER pins A,B, both selected (A is sel_array[0] = primary).
# apply_pin_prop acts on the current selection, so the selection IS the fixture.
set base    "name=A dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.2"
set changed "name=A dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.9"
set changedM "name=A dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.9 foo=a\[1\]"
proc fixture {} {
  xschem clear force symbol
  xschem add_symbol_pin 0  0 A in 0
  xschem add_symbol_pin 40 0 B in 0
  xschem unselect_all; xschem select rect 5 0; xschem select rect 5 1
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: the scope form -> exactly +1 log line, the change applies to both selected
#     pins, the metachar prop logs BRACE-QUOTED + replays, and the interp result is BLANK.
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: A,B pins at default name_size=0.2" [expr {[szv 0] eq "0.2" && [szv 1] eq "0.2"}] "A=[szv 0] B=[szv 1]"
set c0 [apc]
set r [xschem apply_pin_prop selected $changed]
check "(a) scope form -> exactly +1 log line" [expr {[apc] == $c0 + 1}] "c0=$c0 now=[apc]"
check "(a) change applied: A,B name_size -> 0.9" [expr {[szv 0] eq "0.9" && [szv 1] eq "0.9"}] "A=[szv 0] B=[szv 1]"
check "(a) changed-fields-only: B keeps its own name=B (not fanned to A)" [expr {[nmv 1] eq "B"}] "B name=[nmv 1]"
check "(a) RESULT DROPPED: the boundary blanks the old '1' success result" [expr {$r eq ""}] "r=>$r<"
# byte-exact scope form: scope bareword unbraced, prop brace-quoted (has spaces).
check "(a) logged line is the brace-quoted scope form 'xschem apply_pin_prop selected {<prop>}'" \
  [expr {[apcpat "xschem apply_pin_prop selected \{$changed\}"] == 1}] "count=[apcpat "xschem apply_pin_prop selected \{$changed\}"]"

# (a2) METACHAR referent (the atom-13/atom-16 replay-safe lesson): a prop with `foo=a[1]` carries Tcl
# metacharacters. A RAW line would replay `[1]` as a command substitution; log_action_argv/Tcl_Merge
# brace-quotes it. Assert the logged line is brace-quoted AND replaying that EXACT line re-applies.
fixture
xschem apply_pin_prop selected $changedM
check "(a2) metachar prop applied (foo=a\[1\] on A,B)" [expr {[xschem getprop rect 5 0 foo] eq "a\[1\]" && [xschem getprop rect 5 1 foo] eq "a\[1\]"}] \
  "A foo=[xschem getprop rect 5 0 foo] B foo=[xschem getprop rect 5 1 foo]"
set fd [open [xschem get actionlog_filename] r]; set allM [read $fd]; close $fd
set exactM ""
foreach l [split $allM \n] { if {[string match {xschem apply_pin_prop selected *foo=a*} $l]} { set exactM $l } }
check "(a2) metachar prop logged BRACE-QUOTED (Tcl_Merge), not raw" \
  [expr {$exactM eq "xschem apply_pin_prop selected \{$changedM\}"}] "got=>$exactM<"
# replay-safety: re-fixture, eval the EXACT logged line, assert it resolved (no Tcl error) + applied.
fixture
set rrc [catch {uplevel #0 $exactM} rres]
check "(a2) the logged line REPLAYS without a Tcl error (metachar-safe)" [expr {$rrc == 0}] "rc=$rrc res=>$rres<"
check "(a2) replay applied the metachar prop (foo=a\[1\] on A)" [expr {[xschem getprop rect 5 0 foo] eq "a\[1\]"}] "A foo=[xschem getprop rect 5 0 foo]"

# ---------------------------------------------------------------------------
# (b) argc-gate: bare `xschem apply_pin_prop` -> TCL_ERROR, NON-EMPTY verb-named message,
#     +0 log, NO mutation. The message-non-empty check is the landmine proof (success-only reset).
# ---------------------------------------------------------------------------
fixture
set t0 [szv 0]
set a0 [apc]
set e1 [catch {xschem apply_pin_prop} m1]
check "(b) no-arg: TCL_ERROR" [expr {$e1 == 1}] "rc=$e1"
check "(b) no-arg: NON-EMPTY verb-named message (landmine: Tcl_ResetResult did not wipe it)" \
  [expr {[string match {*apply_pin_prop*needs*} $m1]}] "msg=>$m1<"
check "(b) no-arg: NO log line (+0 -- failure not logged)" [expr {[apc] == $a0}] "a0=$a0 now=[apc]"
check "(b) no-arg: NO mutation" [expr {[szv 0] eq $t0}] "before=$t0 after=[szv 0]"

# (b2) NO-OP-STILL-LOGS (§30): re-applying the SAME prop is a no-op (no undo) but STILL logs +1.
fixture
xschem apply_pin_prop selected $changed   ;# first apply (real change)
set c1 [apc]
set rnoop [catch {xschem apply_pin_prop selected $changed} mnoop]  ;# same prop -> no-op
check "(b2) no-op re-apply: no error" [expr {$rnoop == 0}] "rc=$rnoop res=>$mnoop<"
check "(b2) no-op re-apply returns BLANK (was '0'; boundary drops it)" [expr {$mnoop eq ""}] "res=>$mnoop<"
check "(b2) NO-OP STILL LOGS +1 under log-on-success (§30: a no-op is a SUCCESS)" [expr {[apc] == $c1 + 1}] "c1=$c1 now=[apc]"

# ---------------------------------------------------------------------------
# (c) READONLY reject (the CORRECTNESS FIX): the boundary's ONE generic gate refuses -> TCL_ERROR,
#     verb-named read-only message (non-empty), NO mutation, NO log. Pre-migration the scripted form
#     MUTATED a read-only symbol view (the gap this closes).
# ---------------------------------------------------------------------------
fixture
set t0 [szv 0]
xschem set readonly 1
set a0 [apc]
set e3 [catch {xschem apply_pin_prop selected $changed} m3]
check "(c) readonly: TCL_ERROR" [expr {$e3 == 1}] "rc=$e3"
check "(c) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*apply_pin_prop*read-only*} $m3]}] "msg=>$m3<"
check "(c) readonly: NO log line (+0)" [expr {[apc] == $a0}] "a0=$a0 now=[apc]"
check "(c) readonly: NO mutation (the scripted form used to mutate a read-only cell)" [expr {[szv 0] eq $t0}] "before=$t0 after=[szv 0]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) BACK-COMPAT (argc==3): `xschem apply_pin_prop <prop>` defaults to "selected" scope, logs the
#     3-arg form, applies to the CURRENT selection (the accepted selection-dependent replay class, 0005).
# ---------------------------------------------------------------------------
fixture
set c0 [apc]
xschem apply_pin_prop $changed
check "(d) back-compat: applied to the current selection (A,B name_size -> 0.9)" [expr {[szv 0] eq "0.9" && [szv 1] eq "0.9"}] "A=[szv 0] B=[szv 1]"
check "(d) back-compat: exactly +1 log line" [expr {[apc] == $c0 + 1}] "c0=$c0 now=[apc]"
check "(d) back-compat: logs the 3-arg form 'xschem apply_pin_prop {<prop>}' (no scope word)" \
  [expr {[apcpat "xschem apply_pin_prop \{$changed\}"] == 1}] "count=[apcpat "xschem apply_pin_prop \{$changed\}"]"

# ---------------------------------------------------------------------------
# (e) REPLAY. The recorded scope-form line re-EXECUTES through the replay_action_log suppress seam
#     but does NOT re-log; a control unwrapped `source` DOES re-log. The fixture pre-selects A,B so
#     the recorded apply is observable.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_apply_pin_prop_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem apply_pin_prop selected \{$changed\}"; close $fd

fixture
set nc [apc]
replay_action_log $rec
check "(e) replay seam: EFFECT applied (A,B name_size -> 0.9)" [expr {[szv 0] eq "0.9" && [szv 1] eq "0.9"}] "A=[szv 0] B=[szv 1]"
check "(e) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[apc] == $nc}] "nc=$nc now=[apc]"

fixture
set nc [apc]
uplevel #0 [list source $rec]
check "(e) control (unwrapped source): EFFECT applied (A,B name_size -> 0.9)" [expr {[szv 0] eq "0.9" && [szv 1] eq "0.9"}] "A=[szv 0] B=[szv 1]"
check "(e) control (unwrapped source): re-logged (+1, re-executable action)" [expr {[apc] == $nc + 1}] "nc=$nc now=[apc]"
file delete $rec

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (the atom-1 no-double-push rule): run_core owns the SINGLE push_undo PER apply.
#     TWO successive applies (0.5 then 0.9) build a TWO-LEVEL history; a spurious run_core double-push
#     would stack an IDENTICAL extra snapshot, so the SECOND undo would land on the double (0.5) instead
#     of the original 0.2. One undo alone cannot see a double-push (both restore the same prior state) --
#     the SECOND undo is the discriminator (the reset_inst_prop §33 depth pattern).
# ---------------------------------------------------------------------------
fixture
set half "name=A dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.5"
xschem apply_pin_prop selected $half
xschem apply_pin_prop selected $changed
check "(f) undo depth: second apply took (name_size -> 0.9)" [expr {[szv 0] eq "0.9"}] "name_size=[szv 0]"
xschem undo
check "(f) undo depth: ONE undo -> the first apply's 0.5" [expr {[szv 0] eq "0.5"}] "name_size=[szv 0]"
xschem undo
check "(f) undo depth: a SECOND undo -> the original 0.2 (SINGLE push_undo per apply; a run_core double-push would leave 0.5 here)" \
  [expr {[szv 0] eq "0.2"}] "name_size=[szv 0]"

# ---------------------------------------------------------------------------
# (g) RESULT-DROP + no caller regressed. The boundary blanks the "0"/"1" result (locked in (a)/(b2)).
#     The ONLY production consumer, gfxform::do_apply (xschem.tcl), DISCARDS the result -- so it still
#     applies the change despite the drop. Drive it the way production does (scope in ::gfxform_pin_scope).
# ---------------------------------------------------------------------------
fixture
if {[llength [info procs gfxform::do_apply]] == 1} {
  set gfxform::type pin
  set ::gfxform_pin_scope selected
  set gerr [catch {gfxform::do_apply $changed} gmsg]
  check "(g) production gfxform::do_apply drives apply_pin_prop (discards result) without error" [expr {$gerr == 0}] "rc=$gerr msg=>$gmsg<"
  check "(g) gfxform::do_apply applied the change (A,B name_size -> 0.9) -- the discarded result did not break the path" \
    [expr {[szv 0] eq "0.9" && [szv 1] eq "0.9"}] "A=[szv 0] B=[szv 1]"
} else {
  # Fallback: the production idiom is a bare statement discarding the result. Assert that idiom works.
  xschem apply_pin_prop selected $changed
  check "(g) production idiom (bare statement, result discarded) applies the change" \
    [expr {[szv 0] eq "0.9" && [szv 1] eq "0.9"}] "A=[szv 0] B=[szv 1] (gfxform::do_apply not loaded headless)"
}

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
