# perform_action() BOUNDARY -- Refactor B ATOM 28 (audit §48): migrate the `redo` verb.
#
# `redo` is Refactor B batch item 03 (doc/claude/refactor_b_batch/PLAN.md), the first strictly
# ZERO-DELTA consistency migration; see
# doc/claude/code_analysis/perform_action_atom28_redo_decision.md. The OLD branch was already
# boundary-shaped (inline !xctx guard + scheduler_readonly_reject("redo") + fixed bare
# log_action("xschem redo") + reset-on-success), so the migration consolidates gate and log onto
# perform_action with NO observable behaviour change. The core pop_undo_keep_selection(1, 1)
# (select.c, the issue-0095 selection-keeping wrapper over xctx->pop_undo) is undo-stack
# NAVIGATION: NO push_undo exists on this path and NONE is added (a push at cur<head snaps
# head=++cur, save.c, TRUNCATING the redo tail -- check (f) is that regression's detector).
#
# THE HEADLINE is the NO-ARITY-GATE decision (deliberately unlike delete §44 / clear_drawing §47,
# whose OLD branches were if(argc==2) silent no-ops that log-on-success would phantom-log): redo's
# old branch EXECUTES and logs bare at ANY argc, so tolerant argc is the PRESERVED behaviour (the
# toggle_ignore §32 precedent) and the DEFAULT `xschem %s` core_log_action arm keeps the logged
# line byte-identical bare at every argc. Check (b) is its proof.
#
# THE F-SHARED TWIN (locked by check (g)): pop_undo_keep_selection has exactly TWO scheduler.c
# call sites -- the redo arm (fixed 1,1 -- moves into run_core) and the RAW `undo` branch
# (argv-parsed redo/set_modify: `xschem undo 1 1` performs a redo with its OWN `xschem undo 1 1`
# log). The undo branch STAYS RAW (batch item 05's scope); distinct verbs, distinct lines, no
# double-log path. The S7 exact-count grep rows pin both call sites.
#
# ENTRY MAP (asserted by check (h), NO callback.c edit): legacy `case 'U'` is GONE (Phase 3d.2);
# Shift+U is a Tcl-funneled binding (keysym 85, mods 0 -- printable keysyms strip ShiftMask) ->
# ActionDef edit.redo `xschem redo; xschem redraw` (mutates=1) -> dispatch_input_action ->
# Tcl eval -> the scheduler branch -> the boundary. The branch's log sets actionlog_cmd_logged,
# so dispatch's Layer A wrapper copy DEDUPS -> exactly ONE bare `xschem redo`, never the compound.
# Read-only: the key is gated at DISPATCH (mutates=1 -> readonly_block) BEFORE any Tcl runs.
#
# Checks:
#   (a) SUCCESS: place (pushes undo), undo (1->0), `xschem redo` -> 1 again, rc TCL_OK, exactly
#       +1 byte-exact bare `xschem redo`, interp result blank.
#   (b) THE ATOM-28 HEADLINE -- TOLERANT EXTRA-ARG + BARE LOG FORM: re-arm; `xschem redo extra`
#       STILL executes (0->1), rc TCL_OK, +1 exact-bare `xschem redo`, +0 `xschem redo extra`
#       lines. Pins the no-arity-gate decision AND the default-%s byte-identical log shape.
#   (c) READONLY CONSOLIDATION: read-only -> TCL_ERROR, NON-EMPTY `*redo*read-only*` message
#       (the §33 landmine: the success-only reset must not wipe it), no mutation, +0 log. NOT a
#       new gate -- the old branch had the same inline reject; the check pins the consolidation.
#   (d) REPLAY: the recorded `xschem redo` re-executes through the replay_action_log suppress
#       seam (re-applies against the ambient stack) WITHOUT re-logging; a control unwrapped
#       `source` DOES re-log.
#   (e) NO-OP-STILL-LOGS: EMPTY redo stack (fresh place, nothing undone) -> rc TCL_OK, instances
#       unchanged, +1 exact-bare line (byte-identical to the old unconditional log; §30).
#   (f) STACK NEUTRALITY: undo -> 0, redo -> 1, undo -> 0, redo -> 1 round-trip. A spurious
#       run_core push_undo would truncate the redo tail (push at cur<head snaps head=++cur) and
#       leave instances at 0 -- the sabotage-(B) detector.
#   (g) SIBLING RAW -- the F-shared lock: `xschem undo 1 1` redoes via the RAW undo branch ->
#       instances restored, +1 `xschem undo 1 1`, +0 `xschem redo`.
#   (h) KEY FUNNEL + LAYER-A DEDUP: inject Shift+U (`xschem callback .drw 2 400 300 85 0 0 0`,
#       the real handle_key_press->dispatch chain) -> redo applied, +1 exact-bare `xschem redo`,
#       +0 compound `xschem redo; xschem redraw` lines. Then read-only + the same injection ->
#       blocked at dispatch (mutates=1 -> readonly_block), no mutation, +0 log.
#
# Effect oracle: one resistor (devices/res.sym); `xschem get instances` reads the count.
# `xschem undo` arms a redo slot (1->0); `xschem redo` restores it (0->1).
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_redo.tcl
# doc/claude/code_analysis/perform_action_atom28_redo_decision.md §6

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
# substring counter (for the compound-dedup proof: no line may CONTAIN the pattern).
proc lcsub {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {[string match "*$pat*" $l]} { incr n } }; return $n
}
proc rdc {} { return [lc redo] }                  ;# byte-exact `xschem redo` count
proc ninst {} { return [xschem get instances] }

# Fixture: ONE resistor placed (the placement pushes undo -> head==cur, empty redo tail).
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}
  xschem redraw
}
# arm a redo slot: undo the placement (1 -> 0 instances, cur < head).
proc arm_redo {} {
  fixture
  xschem undo
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: armed redo re-applies the placement -> exactly +1 byte-exact bare line.
# ---------------------------------------------------------------------------
arm_redo
check "(a) fixture armed: undo removed the placed instance" [expr {[ninst] == 0}] "instances=[ninst]"
set c0 [rdc]
set e [catch {xschem redo} r]
check "(a) scripted 'xschem redo': rc TCL_OK" [expr {$e == 0}] "rc=$e msg=>$r<"
check "(a) scripted 'xschem redo' re-applies the placement (0 -> 1)" [expr {[ninst] == 1}] "instances=[ninst]"
check "(a) scripted 'xschem redo' -> exactly +1 log line" [expr {[rdc] == $c0 + 1}] "c0=$c0 now=[rdc]"
check "(a) interp result blank on success (old branch reset-on-success preserved)" \
  [expr {$r eq ""}] "got=>$r<"
# byte-exact bare form (core_log_action default `xschem %s` arm).
set fd [open [xschem get actionlog_filename] r]; set allR [read $fd]; close $fd
set exactR ""
foreach l [split $allR \n] { if {$l eq {xschem redo}} { set exactR $l } }
check "(a) logged line is byte-exact 'xschem redo' (bare-verb default form)" \
  [expr {$exactR eq "xschem redo"}] "got=>$exactR<"

# ---------------------------------------------------------------------------
# (b) THE ATOM-28 HEADLINE -- TOLERANT EXTRA-ARG + BARE LOG FORM. `xschem redo extra` STILL
#     executes (the old branch had NO argc handling -- preserved, NO arity gate added) and the
#     log stays byte-identical BARE (`xschem redo`, +0 `xschem redo extra` lines): the DEFAULT
#     `xschem %s` core_log_action arm ignores argv entirely.
# ---------------------------------------------------------------------------
xschem undo   ;# re-arm (1 -> 0)
check "(b) re-armed: instance removed" [expr {[ninst] == 0}] "instances=[ninst]"
set c0 [rdc]
set x0 [lc {redo extra}]
set e [catch {xschem redo extra} m]
check "(b) extra-arg: rc TCL_OK (tolerant argc PRESERVED -- no arity gate)" [expr {$e == 0}] "rc=$e msg=>$m<"
check "(b) extra-arg: STILL executes (0 -> 1)" [expr {[ninst] == 1}] "instances=[ninst]"
check "(b) extra-arg: exactly +1 byte-exact BARE 'xschem redo' line" [expr {[rdc] == $c0 + 1}] "c0=$c0 now=[rdc]"
check "(b) extra-arg: +0 'xschem redo extra' lines (default %s arm ignores argv)" \
  [expr {[lc {redo extra}] == $x0}] "x0=$x0 now=[lc {redo extra}]"

# ---------------------------------------------------------------------------
# (c) READONLY CONSOLIDATION: the boundary's ONE generic gate refuses with the SAME verb-named
#     message the old inline scheduler_readonly_reject(interp, "redo") emitted -> TCL_ERROR,
#     non-empty message (the §33 landmine: success-only reset must not wipe it), NO mutation,
#     +0 log. NOT a new gate -- byte-identical consolidation.
# ---------------------------------------------------------------------------
arm_redo
set t0 [ninst]
xschem set readonly 1
set c0 [rdc]
set e [catch {xschem redo} m]
check "(c) readonly: TCL_ERROR" [expr {$e == 1}] "rc=$e"
check "(c) readonly: message names the verb + read-only (non-empty -- reset did not wipe it)" \
  [expr {[string match {*redo*read-only*} $m]}] "msg=>$m<"
check "(c) readonly: NO log line (+0)" [expr {[rdc] == $c0}] "c0=$c0 now=[rdc]"
check "(c) readonly: NO mutation (redo slot NOT applied)" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY. The recorded `xschem redo` re-executes against the AMBIENT undo stack. Through the
#     replay_action_log suppress seam the effect applies but does NOT re-log; a control
#     unwrapped `source` DOES re-log. Re-arm the redo slot before each.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_redo_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem redo"; close $fd

arm_redo
set nc [rdc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (redo re-applied the placement)" [expr {[ninst] == 1}] "instances=[ninst]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[rdc] == $nc}] "nc=$nc now=[rdc]"

arm_redo
set nc [rdc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied" [expr {[ninst] == 1}] "instances=[ninst]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[rdc] == $nc + 1}] "nc=$nc now=[rdc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) NO-OP-STILL-LOGS (§30). EMPTY redo stack (fresh placement, nothing undone: push_undo
#     snapped head==cur): pop_undo(1,..) early-returns in-core = a no-op SUCCESS -> TCL_OK ->
#     log-on-success STILL emits +1 -- byte-identical to the OLD branch's unconditional log.
# ---------------------------------------------------------------------------
fixture
set t0 [ninst]
set c0 [rdc]
set e [catch {xschem redo} m]
check "(e) empty-redo-stack no-op: rc TCL_OK (a no-op is a SUCCESS, not a failure)" [expr {$e == 0}] "rc=$e msg=>$m<"
check "(e) empty-redo-stack no-op: NO mutation" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
check "(e) empty-redo-stack no-op STILL logs +1 (byte-identical to the old unconditional log)" \
  [expr {[rdc] == $c0 + 1}] "c0=$c0 now=[rdc]"

# ---------------------------------------------------------------------------
# (f) STACK NEUTRALITY (the sabotage-(B) detector). redo is stack NAVIGATION: no push_undo
#     anywhere on the path. undo -> 0, redo -> 1, undo -> 0, redo -> 1 round-trips. A spurious
#     run_core push_undo before the pop would fire at cur<head and snap head=++cur -- TRUNCATING
#     the redo tail -- so the following pop_undo(1,..) finds cur>=head and restores NOTHING
#     (instances would stay 0 here).
# ---------------------------------------------------------------------------
arm_redo
xschem redo
check "(f) round-trip 1: redo restores the placement" [expr {[ninst] == 1}] "instances=[ninst]"
xschem undo
check "(f) round-trip 2: undo removes it again" [expr {[ninst] == 0}] "instances=[ninst]"
xschem redo
check "(f) round-trip 3: redo restores it AGAIN (redo tail intact -- no spurious push_undo truncation)" \
  [expr {[ninst] == 1}] "instances=[ninst]"

# ---------------------------------------------------------------------------
# (g) SIBLING RAW -- the F-shared lock. `xschem undo 1 1` performs a redo through the RAW undo
#     branch (batch item 05's scope): same core pop_undo_keep_selection, DISTINCT verb, its OWN
#     `xschem undo 1 1` log line, +0 `xschem redo` -- no double-log path.
# ---------------------------------------------------------------------------
arm_redo
set rc0 [rdc]
set uc0 [lc {undo 1 1}]
xschem undo 1 1
check "(g) sibling 'xschem undo 1 1' redoes via the RAW undo branch (0 -> 1)" [expr {[ninst] == 1}] "instances=[ninst]"
check "(g) sibling logs its OWN 'xschem undo 1 1' line (+1)" [expr {[lc {undo 1 1}] == $uc0 + 1}] "uc0=$uc0 now=[lc {undo 1 1}]"
check "(g) sibling does NOT log a 'xschem redo' line (+0)" [expr {[rdc] == $rc0}] "rc0=$rc0 now=[rdc]"

# ---------------------------------------------------------------------------
# (h) KEY FUNNEL + LAYER-A DEDUP. Shift+U through the REAL handle_key_press->dispatch chain
#     (keysym 85, state 0 -- printable keysyms strip ShiftMask, so the binding row is mods 0;
#     idle-gated, injected at normal idle). The ActionDef compound `xschem redo; xschem redraw`
#     evals -> the branch's boundary log sets actionlog_cmd_logged -> dispatch's Layer A copy is
#     SKIPPED: exactly ONE bare `xschem redo`, NEVER the compound. Then read-only + the same
#     injection: blocked at DISPATCH (mutates=1 -> readonly_block, stubbed modal), no mutation,
#     +0 log.
# ---------------------------------------------------------------------------
arm_redo
set c0 [rdc]
set k0 [lcsub {xschem redo; xschem redraw}]
xschem callback .drw 2 400 300 85 0 0 0   ;# Shift+U: keysym 85 ('U'), state 0 (binding mods=0)
update idletasks
check "(h) Shift+U key: redo applied (0 -> 1)" [expr {[ninst] == 1}] "instances=[ninst]"
check "(h) Shift+U key: EXACTLY +1 bare 'xschem redo' (Layer A dedup -- not +2)" \
  [expr {[rdc] == $c0 + 1}] "c0=$c0 now=[rdc]"
check "(h) Shift+U key: +0 compound 'xschem redo; xschem redraw' lines (dedup skipped the wrapper copy)" \
  [expr {[lcsub {xschem redo; xschem redraw}] == $k0}] "k0=$k0 now=[lcsub {xschem redo; xschem redraw}]"

# read-only + the same injection: gated at dispatch (mutates=1 -> readonly_block). Stub the modal.
arm_redo
set t0 [ninst]
rename tk_messageBox __real_tk_messageBox
proc tk_messageBox {args} {}
xschem set readonly 1
set c0 [rdc]
xschem callback .drw 2 400 300 85 0 0 0
update idletasks
check "(h) readonly Shift+U key: NO mutation (gated at dispatch by mutates=1)" \
  [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
check "(h) readonly Shift+U key: NO log line (+0)" [expr {[rdc] == $c0}] "c0=$c0 now=[rdc]"
xschem set readonly 0
rename tk_messageBox {}
rename __real_tk_messageBox tk_messageBox

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
