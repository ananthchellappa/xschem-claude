# perform_action() BOUNDARY -- Refactor B ATOM 22: route `reset_symbol` through the
# single mutation boundary. The direct INLINE twin of reset_inst_prop (atom 13, §33):
# a VALIDATING verb whose two gates reject a bad call with an early TCL_ERROR *before*
# any mutation, so (via the atom-13 log-on-success boundary) a rejected call mutates
# nothing and logs nothing.
#
# WHY reset_symbol -- an ADDITIVE-LOG+GATE atom. The pre-migration branch had NEITHER a
# self-log NOR a read-only gate: it merely did `my_strdup(&inst[inst].name, argv[3])`
# after two Tcl_SetResult gates, then Tcl_ResetResult. The migration ADDS BOTH:
#   * a REPLAY line (`xschem reset_symbol <inst> <symref>`, both referents Tcl_Merge-
#     quoted), and
#   * the boundary's generic READ-ONLY gate -- closing a LATENT bug: the old branch
#     mutated a read-only cell silently (check (d) pins it closed).
#
# THE ONE REAL DIVERGENCE from the reset_inst_prop template (locked by checks (f)/(g)):
# reset_symbol's run_core arm must NOT push_undo and must NOT set_modify. reset_symbol is
# a documented LOW-LEVEL batch sub-step -- its SOLE non-branch caller, the Tcl proc
# `fix_symbols` (xschem.tcl), does ONE `xschem push_undo` *before* a foreach loop that
# calls `xschem reset_symbol` per instance, then reload_symbols + set_modify(1). If the
# run_core arm pushed a slot per call, fix_symbols' N calls would SHATTER that single
# one-Ctrl-Z batch (one undo would revert only the last remap). The precedent for a
# no-undo/no-set_modify run_core arm is replace_symbol's fast-form (atom 14). Checks
# (f)/(g) drive the REAL fix_symbols and assert ONE undo reverts the WHOLE remap.
#
# TWO REFERENTS, both Tcl_Merge-quoted (check (e)): argv[2] (instance name/index) and
# argv[3] (symbol reference) can each carry Tcl metacharacters (an arrayed name x2[3:0],
# a symref path with a space/bracket), so a raw `%s` line would misparse on replay -- the
# atom-13 issue-0048 replay-safe lesson. log_action_argv/Tcl_Merge brace-quotes minimally.
#
# Checks:
#   (a) SUCCESS: `xschem reset_symbol R1 devices/capa.sym` -> exactly +1 byte-exact log
#       line, the effect applies (inst.name swaps res.sym -> devices/capa.sym), interp
#       result BLANK (PRESERVED -- the old branch also ended in Tcl_ResetResult on success;
#       the boundary must not leak a result). NO set_modify: a standalone reset_symbol on a
#       clean sheet leaves the modified flag UNCHANGED (the load-bearing no-set_modify half
#       of the fix_symbols-owns-the-batch divergence; the old branch had no set_modify).
#   (b) argc!=4 (too few AND too many) -> TCL_ERROR + NON-EMPTY verb-named message + NO
#       mutation + +0 log.
#   (c) instance-not-found -> TCL_ERROR + NON-EMPTY verb-named message + NO mutation + +0.
#   (d) READONLY reject (the NEW gate) -> TCL_ERROR + verb-named read-only message + NO
#       mutation + +0 log. Pins the pre-migration mutate-on-read-only bug closed.
#   (e) METACHAR referents: arrayed instance name x2[3:0] + a spaced symref round-trip via
#       Tcl_Merge (brace-quoted in the log; the exact logged line REPLAYS without error and
#       re-applies the swap).
#   (f) fix_symbols emits N replay lines: the real proc remaps 3 instances -> exactly +3
#       `xschem reset_symbol` lines, all remapped.
#   (g) UNDO BATCH INTEGRITY (the load-bearing check): ONE undo after fix_symbols reverts
#       the WHOLE remap -- proving the run_core arm pushed NO undo (the single bracket held
#       by fix_symbols' one push_undo is intact). A distilled explicit-bracket variant
#       re-asserts it independently of fix_symbols' internals.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_reset_symbol.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §42

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers this
# in logdir_tests so LOG is always set in the real run; the guard keeps a bare invocation
# from erroring. (deferred, NOT "skipped: no X".)
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
# ANY reset_symbol* line -- to prove a FAILED call logs NOTHING (not even a variant), and
# to count fix_symbols' batch.
proc rc_any {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem reset_symbol*} $l]} { incr n } }
  return $n
}
# The symbol reference (inst.name) of instance N, read from instance_list's 2nd column
# ({instname} {symref} {type} per line). reset_symbol swaps inst.name in place (no
# reload), so this reflects the mutation directly.
proc symref {n} {
  set lines [split [xschem instance_list] "\n"]
  return [lindex [lindex $lines $n] 1]
}

# Fixture: a single resistor R1. `xschem instance devices/res.sym` normalizes the stored
# name to `res.sym`, so a reset to `devices/capa.sym` is observable.
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: exactly +1 byte-exact log line, the effect applies, interp result BLANK.
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: R1 symbol reference is res.sym" [expr {[symref 0] eq "res.sym"}] "symref=[symref 0]"
set c0 [logcount {xschem reset_symbol R1 devices/capa.sym}]
set r [xschem reset_symbol R1 devices/capa.sym]
check "(a) scripted 'xschem reset_symbol R1 devices/capa.sym' -> exactly +1" \
  [expr {[logcount {xschem reset_symbol R1 devices/capa.sym}] == $c0 + 1}] \
  "c0=$c0 now=[logcount {xschem reset_symbol R1 devices/capa.sym}]"
check "(a) scripted: effect applied (inst.name swaps res.sym -> devices/capa.sym)" \
  [expr {[symref 0] eq "devices/capa.sym"}] "symref=[symref 0]"
check "(a) interp result BLANK on success (PRESERVED -- the old branch also Tcl_ResetResult'd; the boundary must not leak a result)" \
  [expr {$r eq ""}] "got=>$r<"
# byte-exact: Tcl_Merge quotes MINIMALLY, so a plain refdes+path logs unbraced.
set fd [open [xschem get actionlog_filename] r]; set allA [read $fd]; close $fd
set exactA ""
foreach l [split $allA \n] { if {$l eq {xschem reset_symbol R1 devices/capa.sym}} { set exactA $l } }
check "(a) logged line is byte-exact 'xschem reset_symbol R1 devices/capa.sym' (Tcl_Merge unbraced for plain referents)" \
  [expr {$exactA eq "xschem reset_symbol R1 devices/capa.sym"}] "got=>$exactA<"

# (a3) NO set_modify -- the load-bearing no-set_modify half of the divergence. A standalone
# reset_symbol on a CLEARED sheet must leave the modified flag UNCHANGED (the arm calls no
# set_modify, matching the old branch). fix_symbols owns the set_modify(1) after its loop; a
# regression that added set_modify(1) to the arm would flip the flag here (and, worse, fire N
# autosave write_backup() of a half-remapped/stale-ptr sheet mid-fix_symbols).
fixture
xschem set_modify 0
check "(a3) precondition: modified flag cleared to 0" [expr {[xschem get modified] == 0}] "modified=[xschem get modified]"
xschem reset_symbol R1 devices/capa.sym
check "(a3) standalone reset_symbol leaves modified UNCHANGED (0) -- the run_core arm calls NO set_modify" \
  [expr {[xschem get modified] == 0}] "modified=[xschem get modified]"

# ---------------------------------------------------------------------------
# (b) argc!=4 -- FAILURE IS NOT LOGGED, and the error message SURVIVES.
#   too-few (argc=3) -> "needs 2 additional arguments"; too-many (argc=5) -> same gate.
# ---------------------------------------------------------------------------
fixture
set t0 [symref 0]
set a0 [rc_any]
set e1 [catch {xschem reset_symbol R1} m1]
check "(b) too-few (argc=3): TCL_ERROR" [expr {$e1 == 1}] "rc=$e1"
check "(b) too-few: NON-EMPTY verb-named message (Tcl_ResetResult did not wipe it)" \
  [expr {[string match {*reset_symbol*additional arguments*} $m1]}] "msg=>$m1<"
check "(b) too-few: NO log line (+0 -- failure not logged)" [expr {[rc_any] == $a0}] "a0=$a0 now=[rc_any]"
check "(b) too-few: NO mutation" [expr {[symref 0] eq $t0}] "before=$t0 after=[symref 0]"

set a1 [rc_any]
set e1b [catch {xschem reset_symbol R1 devices/capa.sym extra} m1b]
check "(b) too-many (argc=5): TCL_ERROR (argc!=4 gate)" [expr {$e1b == 1}] "rc=$e1b"
check "(b) too-many: NON-EMPTY verb-named message" \
  [expr {[string match {*reset_symbol*additional arguments*} $m1b]}] "msg=>$m1b<"
check "(b) too-many: NO log line (+0)" [expr {[rc_any] == $a1}] "a1=$a1 now=[rc_any]"
check "(b) too-many: NO mutation" [expr {[symref 0] eq $t0}] "before=$t0 after=[symref 0]"

# ---------------------------------------------------------------------------
# (c) instance-not-found -> TCL_ERROR, verb-named message, +0 log, no mutation.
# ---------------------------------------------------------------------------
fixture
set t0 [symref 0]
set a0 [rc_any]
set e2 [catch {xschem reset_symbol bogus_name devices/capa.sym} m2]
check "(c) bogus-name: TCL_ERROR" [expr {$e2 == 1}] "rc=$e2"
check "(c) bogus-name: NON-EMPTY verb-named message" \
  [expr {[string match {*reset_symbol*not found*} $m2]}] "msg=>$m2<"
check "(c) bogus-name: NO log line (+0 -- failure not logged)" [expr {[rc_any] == $a0}] "a0=$a0 now=[rc_any]"
check "(c) bogus-name: NO mutation" [expr {[symref 0] eq $t0}] "before=$t0 after=[symref 0]"

# ---------------------------------------------------------------------------
# (d) READONLY reject -- the NEW gate the old branch NEVER HAD. TCL_ERROR, verb-named
#     read-only message, NO mutation (the pre-migration bug: it mutated a read-only cell),
#     NO log.
# ---------------------------------------------------------------------------
fixture
set t0 [symref 0]
xschem set readonly 1
set a0 [rc_any]
set e3 [catch {xschem reset_symbol R1 devices/capa.sym} m3]
check "(d) readonly: TCL_ERROR" [expr {$e3 == 1}] "rc=$e3"
check "(d) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*reset_symbol*read-only*} $m3]}] "msg=>$m3<"
check "(d) readonly: NO log line (+0)" [expr {[rc_any] == $a0}] "a0=$a0 now=[rc_any]"
check "(d) readonly: NO mutation (the pre-migration mutate-on-read-only bug is CLOSED)" \
  [expr {[symref 0] eq $t0}] "before=$t0 after=[symref 0]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (e) METACHAR referents: arrayed instance name x2[3:0] + a spaced symref. BOTH must
#     Tcl_Merge-brace-quote in the log, and the exact logged line must REPLAY.
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0]}
xschem redraw
set nm [lindex [lindex [split [xschem instance_list] "\n"] 0] 0]
check "(e) arrayed instance instname is literally x2\[3:0\]" [string equal $nm {x2[3:0]}] "name=$nm"
xschem reset_symbol {x2[3:0]} {my sym.sym}
check "(e) metachar: effect applied (inst.name -> 'my sym.sym')" [expr {[symref 0] eq {my sym.sym}}] "symref=[symref 0]"
set fd [open [xschem get actionlog_filename] r]; set allE [read $fd]; close $fd
set exactE ""
foreach l [split $allE \n] { if {[string match {xschem reset_symbol *x2*} $l]} { set exactE $l } }
check "(e) both referents logged BRACE-QUOTED (Tcl_Merge), not raw" \
  [expr {$exactE eq {xschem reset_symbol {x2[3:0]} {my sym.sym}}}] "got=>$exactE<"
# replay-safety: re-place, eval the EXACT logged line, assert it resolves (no Tcl error) + applies.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0]}
xschem redraw
set rrc [catch {uplevel #0 $exactE} rres]
check "(e) the logged line REPLAYS without a Tcl error (metachar-safe)" [expr {$rrc == 0}] "rc=$rrc res=>$rres<"
check "(e) replay applied the swap (inst.name -> 'my sym.sym')" [expr {[symref 0] eq {my sym.sym}}] "symref=[symref 0]"

# ---------------------------------------------------------------------------
# (f)/(g) fix_symbols round-trip -- the SOLE non-branch caller, the single-undo-bracket
#     contract. fix_symbols does ONE `xschem push_undo`, a foreach loop of `xschem
#     reset_symbol` per instance, then reload_symbols + set_modify + redraw. `fix_symbols 1`
#     remaps `res.sym` -> `devices/res.sym` for every instance.
#   (f) exactly +3 reset_symbol lines land (byte-replayable per-instance) + all remapped.
#   (g) ONE undo reverts the WHOLE remap -> proves the run_core arm pushed NO undo (a
#       per-call push would leave the single bracket shattered so only the last remap
#       would revert).
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/res.sym 0 0   0 0 {name=R1}
xschem instance devices/res.sym 0 100 0 0 {name=R2}
xschem instance devices/res.sym 0 200 0 0 {name=R3}
xschem redraw
check "(f) fixture: 3 instances, all res.sym" \
  [expr {[symref 0] eq "res.sym" && [symref 1] eq "res.sym" && [symref 2] eq "res.sym"}] \
  "0=[symref 0] 1=[symref 1] 2=[symref 2]"
set n0 [rc_any]
fix_symbols 1
set n1 [rc_any]
check "(f) fix_symbols emitted exactly +3 reset_symbol replay lines (one per instance)" \
  [expr {$n1 - $n0 == 3}] "n0=$n0 n1=$n1 delta=[expr {$n1 - $n0}]"
check "(f) all 3 instances remapped to devices/res.sym" \
  [expr {[symref 0] eq "devices/res.sym" && [symref 1] eq "devices/res.sym" && [symref 2] eq "devices/res.sym"}] \
  "0=[symref 0] 1=[symref 1] 2=[symref 2]"
xschem undo
check "(g) ONE undo reverts the WHOLE remap (all 3 back to res.sym) -- the single fix_symbols undo bracket is intact; the run_core arm pushed NO undo" \
  [expr {[symref 0] eq "res.sym" && [symref 1] eq "res.sym" && [symref 2] eq "res.sym"}] \
  "0=[symref 0] 1=[symref 1] 2=[symref 2]"

# (g2) distilled bracket -- independent of fix_symbols' get_cell internals: ONE outer
# push_undo, N reset_symbol calls, ONE undo reverts ALL. A run_core push would break this.
xschem clear force
xschem instance devices/res.sym 0 0   0 0 {name=R1}
xschem instance devices/res.sym 0 100 0 0 {name=R2}
xschem redraw
xschem push_undo
xschem reset_symbol 0 devices/capa.sym
xschem reset_symbol 1 devices/capa.sym
check "(g2) two reset_symbol calls under one bracket both applied" \
  [expr {[symref 0] eq "devices/capa.sym" && [symref 1] eq "devices/capa.sym"}] \
  "0=[symref 0] 1=[symref 1]"
xschem undo
check "(g2) ONE undo reverts BOTH (single outer bracket -- reset_symbol pushed nothing)" \
  [expr {[symref 0] eq "res.sym" && [symref 1] eq "res.sym"}] "0=[symref 0] 1=[symref 1]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
