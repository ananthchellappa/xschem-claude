# perform_action() BOUNDARY -- Refactor B ATOM 29 (audit §49): migrate the `undo` verb.
#
# `undo` is Refactor B batch item 05 (doc/claude/refactor_b_batch/PLAN.md), the undo-family twin
# of redo (atom 28, §48) -- a consistency-only migration with ZERO coverage gain by design; see
# doc/claude/code_analysis/perform_action_atom29_undo_decision.md. The OLD branch was already
# boundary-shaped (inline !xctx guard + scheduler_readonly_reject("undo") + argv-parsed
# pop_undo_keep_selection(redo, set_modify) + unconditional two-form log + reset-on-success), so
# the migration consolidates gate and log onto perform_action with NO observable behaviour change.
# The core (select.c, the issue-0095 selection-keeping wrapper over xctx->pop_undo) is undo-stack
# NAVIGATION: NO push_undo exists on this path and NONE is added (a spurious push before the pop
# would restore the just-pushed state = a no-op undo -- check (a) is that regression's detector).
#
# THE HEADLINE is the NORMALIZING core_log_action arm: unlike redo's fixed bare line, undo's old
# branch logged a NORMALIZED form of its two optional integer args, so the log can ride neither
# the default `%s` arm nor a raw-argv passthrough -- the per-verb arm reads argv IDENTICALLY to
# run_core (the rotate/break_wires/attach_labels invariant). Check (b) pins all three
# normalizations: atoi canonicalization (`00`->`0`), default fill (`xschem undo 1` logs
# `xschem undo 1 1` -- replay preserves DIRECTION), tail drop (extra words never logged).
# Tolerant argc is PRESERVED (no arity gate -- every argc executes + logs, as before; §48 rule).
#
# THE F-SHARED TWIN (locked by check (f) + the S7 grep rows): pop_undo_keep_selection has exactly
# TWO scheduler.c call sites -- run_core's redo arm (fixed 1,1; atom 28) and run_core's undo arm
# (argv-parsed redo/set_modify; THIS atom -- the site MOVED from the branch). `xschem undo 1 1`
# IS a redo wearing the undo verb (flag 0/4 undo, 1 redo, 2 peek -- save.c), with its OWN
# `xschem undo 1 1` log line, +0 `xschem redo` -- distinct verbs, no double-log path.
#
# ENTRY MAP (asserted by check (g), NO callback.c edit): legacy `case 'u'` plain is GONE
# (Phase 3d.2); key `u` is a Tcl-funneled binding (keysym 117, mods 0, idle-gated) -> ActionDef
# edit.undo `xschem undo; xschem redraw` (mutates=1) -> dispatch_input_action -> Tcl eval -> the
# scheduler branch -> the boundary. The branch's log sets actionlog_cmd_logged, so dispatch's
# Layer A wrapper copy DEDUPS -> exactly ONE bare `xschem undo`, never the compound. Read-only:
# the key is gated at DISPATCH (mutates=1 -> readonly_block) BEFORE any Tcl runs.
#
# Checks ((e) runs FIRST while the launch undo stack is still empty):
#   (e) NO-OP-STILL-LOGS: EMPTY undo stack (cur==tail in-core early return, save.c) -> rc TCL_OK,
#       instances unchanged, +1 exact-bare `xschem undo` (§30; byte-identical to the old
#       unconditional log).
#   (a) SUCCESS: place R1 (pushes undo); `xschem undo` -> 1 -> 0, rc TCL_OK, exactly +1 byte-exact
#       bare `xschem undo`, interp result blank.
#   (b) THE ATOM-29 HEADLINE -- the NORMALIZING log arm:
#       (b1) `xschem undo 1 1` REDOES (0 -> 1), rc TCL_OK, +1 exact `xschem undo 1 1`, +0 bare,
#            +0 `xschem redo` (twin independence AND the two-int form).
#       (b2) `xschem undo 00 01` undoes (1 -> 0), +1 exact `xschem undo 0 1`, +0
#            `xschem undo 00 01` (atoi canonicalization).
#       (b3) `xschem undo 1` redoes (0 -> 1), +1 exact `xschem undo 1 1` (default fill).
#       (b4) `xschem undo 0 1 extra` undoes (1 -> 0), rc TCL_OK, +1 exact `xschem undo 0 1`,
#            +0 lines containing `extra` (tolerant argc + tail drop).
#   (c) READONLY CONSOLIDATION: read-only -> TCL_ERROR, NON-EMPTY `*undo*read-only*` message
#       (the §33 landmine: the success-only reset must not wipe it), no mutation, +0 log. NOT a
#       new gate -- the old branch had the same inline reject; the check pins the consolidation.
#   (d) REPLAY: the recorded bare `xschem undo` re-executes through the replay_action_log
#       suppress seam (re-applies against the ambient stack) WITHOUT re-logging; a control
#       unwrapped `source` DOES re-log (+1).
#   (f) STACK ROUND-TRIP + SIBLING LOCK: undo -> 0, redo -> 1, twice -- round-trips clean (the
#       spurious-push detector); the redo verb logs +1 exact-bare `xschem redo` each time with
#       +0 undo lines.
#   (g) KEY FUNNEL + LAYER-A DEDUP: inject key `u` (`xschem callback .drw 2 400 300 117 0 0 0`,
#       the real handle_key_press->dispatch chain) -> undo applied (1 -> 0), +1 exact-bare
#       `xschem undo`, +0 compound `xschem undo; xschem redraw` lines. Then read-only + the same
#       injection -> blocked at dispatch (mutates=1 -> readonly_block), no mutation, +0 log.
#
# Effect oracle: one resistor (devices/res.sym); `xschem get instances` reads the count.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_undo.tcl
# doc/claude/code_analysis/perform_action_atom29_undo_decision.md §5

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers this in
# logdir_tests so LOG is always set in the real run; the guard keeps a bare invocation from erroring.
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counter (the recorded verbs are single-line, so match the whole line).
proc lc {v} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {$l eq "xschem $v"} { incr n } }; return $n
}
# substring counter (for the tail-drop + compound-dedup proofs: no line may CONTAIN the pattern).
proc lcsub {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {[string match "*$pat*" $l]} { incr n } }; return $n
}
proc udc {} { return [lc undo] }                  ;# byte-exact bare `xschem undo` count
proc ninst {} { return [xschem get instances] }

# Fixture: ONE resistor placed (the placement pushes undo -> `xschem undo` removes it).
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (e) NO-OP-STILL-LOGS (§30) -- runs FIRST, before ANY placement: the launch undo stack is
#     empty (cur==tail), pop_undo early-returns in-core = a no-op SUCCESS -> TCL_OK ->
#     log-on-success STILL emits +1 exact-bare -- byte-identical to the OLD unconditional log.
# ---------------------------------------------------------------------------
set t0 [ninst]
set c0 [udc]
set e [catch {xschem undo} m]
check "(e) empty-undo-stack no-op: rc TCL_OK (a no-op is a SUCCESS, not a failure)" [expr {$e == 0}] "rc=$e msg=>$m<"
check "(e) empty-undo-stack no-op: NO mutation" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
check "(e) empty-undo-stack no-op STILL logs +1 exact-bare (byte-identical to the old unconditional log)" \
  [expr {[udc] == $c0 + 1}] "c0=$c0 now=[udc]"

# ---------------------------------------------------------------------------
# (a) SUCCESS: placed R1 undone -> exactly +1 byte-exact bare line. A spurious run_core
#     push_undo before the pop would restore the just-pushed state (instances stays 1) --
#     the sabotage-(B) detector.
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: one instance placed" [expr {[ninst] == 1}] "instances=[ninst]"
set c0 [udc]
set e [catch {xschem undo} r]
check "(a) scripted 'xschem undo': rc TCL_OK" [expr {$e == 0}] "rc=$e msg=>$r<"
check "(a) scripted 'xschem undo' removes the placement (1 -> 0)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(a) scripted 'xschem undo' -> exactly +1 log line" [expr {[udc] == $c0 + 1}] "c0=$c0 now=[udc]"
check "(a) interp result blank on success (old branch reset-on-success preserved)" \
  [expr {$r eq ""}] "got=>$r<"
# byte-exact bare form (core_log_action's NORMALIZING undo arm, argc==2 branch).
set fd [open [xschem get actionlog_filename] r]; set allU [read $fd]; close $fd
set exactU ""
foreach l [split $allU \n] { if {$l eq {xschem undo}} { set exactU $l } }
check "(a) logged line is byte-exact 'xschem undo' (bare argc==2 form)" \
  [expr {$exactU eq "xschem undo"}] "got=>$exactU<"

# ---------------------------------------------------------------------------
# (b) THE ATOM-29 HEADLINE -- the NORMALIZING log arm. The chain rides the stack armed by (a):
#     redo/undo alternate via the undo verb's flag forms, and every logged line is the
#     NORMALIZED two-int form the old branch emitted -- never raw argv, never bare-collapsed.
# ---------------------------------------------------------------------------
# (b1) `xschem undo 1 1` IS a redo wearing the undo verb -- its OWN two-int line, +0 bare,
#      +0 `xschem redo` (twin independence).
set c0 [udc]
set u11 [lc {undo 1 1}]
set r0 [lc redo]
set e [catch {xschem undo 1 1} m]
check "(b1) 'xschem undo 1 1': rc TCL_OK" [expr {$e == 0}] "rc=$e msg=>$m<"
check "(b1) 'xschem undo 1 1' REDOES (0 -> 1)" [expr {[ninst] == 1}] "instances=[ninst]"
check "(b1) 'xschem undo 1 1' -> +1 exact 'xschem undo 1 1'" [expr {[lc {undo 1 1}] == $u11 + 1}] "u11=$u11 now=[lc {undo 1 1}]"
check "(b1) 'xschem undo 1 1' -> +0 bare 'xschem undo'" [expr {[udc] == $c0}] "c0=$c0 now=[udc]"
check "(b1) 'xschem undo 1 1' -> +0 'xschem redo' (distinct verb, no double-log path)" \
  [expr {[lc redo] == $r0}] "r0=$r0 now=[lc redo]"
# (b2) atoi canonicalization: `xschem undo 00 01` executes redo=0/set=1 and logs `xschem undo 0 1`.
set u01 [lc {undo 0 1}]
set uraw [lc {undo 00 01}]
set e [catch {xschem undo 00 01} m]
check "(b2) 'xschem undo 00 01': rc TCL_OK" [expr {$e == 0}] "rc=$e msg=>$m<"
check "(b2) 'xschem undo 00 01' undoes (1 -> 0)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(b2) 'xschem undo 00 01' -> +1 exact 'xschem undo 0 1' (atoi canonicalization)" \
  [expr {[lc {undo 0 1}] == $u01 + 1}] "u01=$u01 now=[lc {undo 0 1}]"
check "(b2) 'xschem undo 00 01' -> +0 raw 'xschem undo 00 01' lines" \
  [expr {[lc {undo 00 01}] == $uraw}] "uraw=$uraw now=[lc {undo 00 01}]"
# (b3) default fill: `xschem undo 1` (argc==3) logs BOTH ints -- replay preserves DIRECTION.
set u11 [lc {undo 1 1}]
set e [catch {xschem undo 1} m]
check "(b3) 'xschem undo 1': rc TCL_OK" [expr {$e == 0}] "rc=$e msg=>$m<"
check "(b3) 'xschem undo 1' redoes (0 -> 1)" [expr {[ninst] == 1}] "instances=[ninst]"
check "(b3) 'xschem undo 1' -> +1 exact 'xschem undo 1 1' (default fill -- replay keeps the redo direction)" \
  [expr {[lc {undo 1 1}] == $u11 + 1}] "u11=$u11 now=[lc {undo 1 1}]"
# (b4) tolerant argc + tail drop: extra words execute fine and never reach the log.
set u01 [lc {undo 0 1}]
set x0 [lcsub extra]
set e [catch {xschem undo 0 1 extra} m]
check "(b4) 'xschem undo 0 1 extra': rc TCL_OK (tolerant argc PRESERVED -- no arity gate)" [expr {$e == 0}] "rc=$e msg=>$m<"
check "(b4) 'xschem undo 0 1 extra' undoes (1 -> 0)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(b4) 'xschem undo 0 1 extra' -> +1 exact 'xschem undo 0 1' (tail drop)" \
  [expr {[lc {undo 0 1}] == $u01 + 1}] "u01=$u01 now=[lc {undo 0 1}]"
check "(b4) 'xschem undo 0 1 extra' -> +0 lines containing 'extra'" \
  [expr {[lcsub extra] == $x0}] "x0=$x0 now=[lcsub extra]"

# ---------------------------------------------------------------------------
# (c) READONLY CONSOLIDATION: the boundary's ONE generic gate refuses with the SAME verb-named
#     message the old inline scheduler_readonly_reject(interp, "undo") emitted -> TCL_ERROR,
#     non-empty message (the §33 landmine: success-only reset must not wipe it), NO mutation,
#     +0 log. NOT a new gate -- byte-identical consolidation.
# ---------------------------------------------------------------------------
fixture
set t0 [ninst]
xschem set readonly 1
set c0 [udc]
set e [catch {xschem undo} m]
check "(c) readonly: TCL_ERROR" [expr {$e == 1}] "rc=$e"
check "(c) readonly: message names the verb + read-only (non-empty -- reset did not wipe it)" \
  [expr {[string match {*undo*read-only*} $m]}] "msg=>$m<"
check "(c) readonly: NO log line (+0)" [expr {[udc] == $c0}] "c0=$c0 now=[udc]"
check "(c) readonly: NO mutation (placement NOT undone)" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY. The recorded bare `xschem undo` re-executes against the AMBIENT undo stack.
#     Through the replay_action_log suppress seam the effect applies but does NOT re-log; a
#     control unwrapped `source` DOES re-log. Re-arm (fixture -> 1 instance) before each.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_undo_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem undo"; close $fd

fixture
set nc [udc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (undo removed the placement)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[udc] == $nc}] "nc=$nc now=[udc]"

fixture
set nc [udc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied" [expr {[ninst] == 0}] "instances=[ninst]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[udc] == $nc + 1}] "nc=$nc now=[udc]"
file delete $rec

# ---------------------------------------------------------------------------
# (f) STACK ROUND-TRIP + SIBLING LOCK (the spurious-push detector). undo is stack NAVIGATION:
#     no push_undo anywhere on the path (the at-head push that arms the redo slot lives INSIDE
#     save.c pop_undo). undo -> 0, redo -> 1, twice; each redo-verb call logs +1 exact-bare
#     `xschem redo` and +0 undo lines (the sibling stays on its own line).
# ---------------------------------------------------------------------------
fixture
foreach pass {1 2} {
  xschem undo
  check "(f) round-trip $pass: undo removes the placement (1 -> 0)" [expr {[ninst] == 0}] "instances=[ninst]"
  set r0 [lc redo]
  set c0 [udc]
  xschem redo
  check "(f) round-trip $pass: redo restores it (0 -> 1; redo tail intact -- no spurious push)" \
    [expr {[ninst] == 1}] "instances=[ninst]"
  check "(f) round-trip $pass: redo verb logs +1 exact-bare 'xschem redo'" \
    [expr {[lc redo] == $r0 + 1}] "r0=$r0 now=[lc redo]"
  check "(f) round-trip $pass: redo verb logs +0 undo lines" [expr {[udc] == $c0}] "c0=$c0 now=[udc]"
}

# ---------------------------------------------------------------------------
# (g) KEY FUNNEL + LAYER-A DEDUP. Key `u` through the REAL handle_key_press->dispatch chain
#     (keysym 117, state 0 -- keybindings.csv row `key,117,0,canvas,edit.undo,1`; idle-gated,
#     injected at normal idle). The ActionDef compound `xschem undo; xschem redraw` evals ->
#     the branch's boundary log sets actionlog_cmd_logged -> dispatch's Layer A copy is
#     SKIPPED: exactly ONE bare `xschem undo`, NEVER the compound. Then read-only + the same
#     injection: blocked at DISPATCH (mutates=1 -> readonly_block, stubbed modal), no mutation,
#     +0 log.
# ---------------------------------------------------------------------------
fixture
set c0 [udc]
set k0 [lcsub {xschem undo; xschem redraw}]
xschem callback .drw 2 400 300 117 0 0 0   ;# key 'u': keysym 117, state 0
update idletasks
check "(g) key 'u': undo applied (1 -> 0)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(g) key 'u': EXACTLY +1 bare 'xschem undo' (Layer A dedup -- not +2)" \
  [expr {[udc] == $c0 + 1}] "c0=$c0 now=[udc]"
check "(g) key 'u': +0 compound 'xschem undo; xschem redraw' lines (dedup skipped the wrapper copy)" \
  [expr {[lcsub {xschem undo; xschem redraw}] == $k0}] "k0=$k0 now=[lcsub {xschem undo; xschem redraw}]"

# read-only + the same injection: gated at dispatch (mutates=1 -> readonly_block). Stub the modal.
fixture
set t0 [ninst]
rename tk_messageBox __real_tk_messageBox
proc tk_messageBox {args} {}
xschem set readonly 1
set c0 [udc]
xschem callback .drw 2 400 300 117 0 0 0
update idletasks
check "(g) readonly key 'u': NO mutation (gated at dispatch by mutates=1)" \
  [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
check "(g) readonly key 'u': NO log line (+0)" [expr {[udc] == $c0}] "c0=$c0 now=[udc]"
xschem set readonly 0
rename tk_messageBox {}
rename __real_tk_messageBox tk_messageBox

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
