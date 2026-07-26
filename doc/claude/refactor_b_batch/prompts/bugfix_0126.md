# Bugfix implement prompt — issue 0126: scripted `xschem apply_properties` mutates a read-only cell

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
Issue file: doc/claude/issues/0126-apply-properties-scripted-readonly-gap.md
Scout receipt (batch item 09): doc/claude/refactor_b_batch/receipts/09_apply_properties.md
Plan: doc/claude/refactor_b_batch/BUGFIX_PLAN.md item 1.

## Bug (re-confirmed live 2026-07-18 by the scout)

`xschem apply_properties <scope> <id> <new> <old> [keep_name]` has NO readonly gate anywhere
on the scripted path. Live repro on Q1.sch: `xschem set readonly 1` then a full-arg
apply_properties returned rc=0, result "1", and the instance property WAS changed. Worse, the
mutation is fully silent: `set_modify()` (src/actions.c:189, `ro_suppress`) suppresses the
modified flag on readonly buffers precisely because "Genuine edits can't reach here while
read-only (blocked upstream)" (actions.c:187) — an assumption this verb violates. So a
script/CIW/replay path corrupts the in-memory view with no '*' marker, no autosave backup, no
save-on-close prompt. Only the interactive form self-gates (property_form.tcl:542), which is
why normal GUI use never sees it.

## ANCHORS (all re-verified from source 2026-07-18 — re-verify again before editing, lines drift)

- src/scheduler.c:173 — `static int scheduler_readonly_reject(Tcl_Interp *interp, const char
  *subcmd)`. Contract (header comment 166-172): returns 1 with the interp error result set +
  CIW note when the edit must be refused; call at an edit subcommand's top, AFTER its !xctx
  check.
- src/scheduler.c:1594-1608 — the `apply_properties` branch:
  - 1596 `int modified, keep_name = 0;`
  - 1597 `if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}`
  - 1598-1602 the `argc < 6` "needs: scope displayed_id new_prop old_prop [keep_name]" check
  - 1604-1605 call to `apply_instance_properties(...)`
  - 1607 `Tcl_SetResult(interp, modified < 0 ? "-1" : (modified ? "1" : "0"), TCL_STATIC);`
- Gate-ordering convention (verified in siblings): !xctx check, THEN readonly reject, THEN
  argument parsing/validation — see `setprop` (scheduler.c:10258-10259) and `wire`
  (scheduler.c:11682-11683).
- src/editprop.c:1094-1106 — `apply_instance_properties()`: no gate; `idx < 0` returns -1
  (issue 0042 contract); `if(modified) set_modify(1);`. Undo is a lazy single push inside
  `apply_symbol_prop()` (editprop.c:927 ff.), so a refusal BEFORE the call also prevents the
  undo-slot push. DO NOT gate here — update_symbol (editprop.c:1134, legacy vim path) shares
  apply_symbol_prop and is guarded interactively; the scheduler branch is the whole scripted
  surface.
- No over-reject possible — the form is triple-guarded and never issues the command readonly:
  - src/property_form.tcl:542 `slickprop::do_apply` — `if {[xschem get readonly]} { return 0 }`
  - src/property_form.tcl:736 `slickprop::maybe_apply_then` readonly guard
  - src/property_form.tcl:1390-1397 viewer mode: OK/Apply disabled, Enter = Cancel
- The did-result contract (0/1/-1 at scheduler.c:1607, dispatched by do_apply at
  property_form.tcl:577-596) is UNTOUCHED by this fix: the gate returns TCL_ERROR before the
  result is set, and the form never reaches the command when readonly.
- Log sites: the ONLY log is Tcl-side, `slickprop::log_apply` gated `$did == 1`
  (property_form.tcl:594, ratified decision D1 in
  doc/claude/code_analysis/apply_properties_logging_decision.md). The fix must NOT add any
  C-side log; a refused call therefore logs nothing structurally.
- tests/headless/test_readonly_guard.tcl — the issue-0041 guard suite: `cmds` list at ~line
  45-50 (currently ends `trim_wires wire undo redo align setprop replace_symbol`), loop calls
  each verb BARE (no args) on a readonly buffer and requires rc!=0 + message matching
  `*read-only*`. Runner: tests/headless/test_readonly_guard.sh; full_audit pass banner
  `READONLY_GUARD_TEST_PASS` (full_audit.sh:83).
- tests/property_form/body.tcl — PF52a-d (~lines 1111-1135) lock the editable 1/0/-1 contract;
  PF47 (~line 949)/PF48 lock the log seam. All run on EDITABLE buffers — must stay green.
  Runner: `cd src && timeout -s KILL 120 ./xschem -q --script ../tests/property_form/wrap.tcl`,
  results in /tmp/sh_pf_test.log (needs DISPLAY).
- tests/headless/full_audit.sh — auto-discovers every tests/headless/test_*.tcl; default
  runner `--pipe -q --nolog --script <file>` from repo root; default pass banner
  `RESULT: ALL PASS`.

## EDITS (exact scope — nothing else)

1. src/scheduler.c, apply_properties branch: insert ONE line between the !xctx check (1597)
   and the argc<6 check (1598):

   ```c
   if(scheduler_readonly_reject(interp, "apply_properties")) return TCL_ERROR;
   ```

   BEFORE the argc check, matching the setprop/wire convention, so the guard suite's bare-verb
   call gets the read-only refusal (not the "needs:" argc error). No new declarations (C89
   untouched), no allocations, no new log site. Rebuild: `cd src && make`.

2. tests/headless/test_readonly_guard.tcl: add `apply_properties` to the `cmds` list (the
   refused-count check auto-adjusts via `[llength $cmds]`).

3. NEW test file tests/headless/test_apply_properties_readonly.tcl (auto-discovered by
   full_audit; own process per headless discipline; run from repo root; emit per-check
   `ok:`/`FAIL:` lines and final `RESULT: ALL PASS` / `RESULT: N FAILED`, exit code
   accordingly — copy the shape of tests/headless/test_readonly.tcl).

## TEST PLAN

Fixture: `$REPO/xschem_library/examples/Q1.sch` (proven today: inst 0 "MODELS", name-token
subst via `xschem subst_tok`, id via `xschem instance_id`; ids are session-stable across
apply/undo — PF52/issue 0043 — but re-fetch after undo if flaky). Never save the file; all
checks are in-memory. Derive $REPO from the script location like test_readonly_guard.tcl does.

Suggested sequence (adapt freely, keep the check SEMANTICS):

```tcl
xschem load $sch                                     ;# editable
set orig [xschem getprop instance 0]
set id   [xschem instance_id [xschem getprop instance 0 name]]
set new  [xschem subst_tok $orig name ZZ99]
# APRO1 (control, editable path unchanged): apply returns "1", prop changed, modified flag set
set r [xschem apply_properties current $id $new $orig 1]
#   check: $r == 1 && [xschem getprop instance 0] ne $orig && [xschem get modified] == 1
# APRO2 (control, undo unchanged): one undo restores the original prop
xschem undo
#   check: [xschem getprop instance 0] eq $orig
# APRO5 setup: one REAL edit so the undo stack head is known
set r2 [xschem apply_properties current $id $new $orig 1]   ;# expect 1, prop == $new
xschem set modified 0
xschem set readonly 1
# APRO3 (regression the bug caused): full-arg apply on readonly is REFUSED with the message
set rc [catch {xschem apply_properties current $id $orig $new 1} err]
#   check: $rc == 1 && [string match "*read-only*" $err] && $err ne {}
# APRO4 (no mutation): prop untouched, modified stays 0
#   check: [xschem getprop instance 0] eq $new && [xschem get modified] == 0
# APRO5 (no spurious undo slot): one undo peels the REAL edit, i.e. the refusal pushed nothing
xschem set readonly 0
xschem undo
#   check: [xschem getprop instance 0] eq $orig
```

RED FIRST: write the new test and run it against the UNFIXED binary — APRO3, APRO4 and APRO5
must FAIL (this is the recorded bug regression). Then apply edit 1, rebuild, re-run: all green.

### Sabotage verification (each named sabotage: apply to src/scheduler.c only, rebuild, run,
confirm the TARGET check fails, `git diff src/scheduler.c` to confirm only the sabotage is in
it, then `git checkout -- src/scheduler.c`... NO — the fix is also in scheduler.c. Instead:
commit is NOT yet made, so revert each sabotage by re-editing the file back to the fixed text
(Edit tool, exact-string), then confirm with `git diff src/scheduler.c` that only the intended
fix line remains. After ALL sabotages, one clean rebuild + full green re-run.)

- SB-A -> targets APRO1 (over-reject guard). Change the inserted line to
  `if(scheduler_readonly_reject(interp, "apply_properties") || 1) return TCL_ERROR;`
  Editable path now refused -> APRO1 fails; readonly checks still pass (APRO2 is written to
  pass vacuously). Expect EXACTLY APRO1 red (APRO5-setup r2 will also refuse -> if that
  cascades, record it; primary witness is APRO1).
- SB-B -> targets APRO3. Change the inserted line to swallow the refusal:
  `if(scheduler_readonly_reject(interp, "apply_properties")) { Tcl_ResetResult(interp); Tcl_SetResult(interp, "0", TCL_STATIC); return TCL_OK; }`
  rc becomes 0 -> APRO3 fails; no mutation -> APRO4/APRO5 stay green; controls green. Exactly
  APRO3.
- SB-C -> targets APRO4. Move the gate call to AFTER the `apply_instance_properties` call
  (before the Tcl_SetResult at 1607). Mutation now happens, then the error returns -> APRO3
  passes (rc+msg), APRO4 fails (prop changed). EXPECTED COLLATERAL: APRO5 also fails (the
  core's lazy push_undo ran) — same causal event, record both; primary witness is APRO4.
- SB-D -> targets APRO5. Insert a stray `xctx->push_undo();` immediately BEFORE the gate line.
  Refusal still clean (APRO3/APRO4 green; APRO1/APRO2 tolerate the extra editable-path push),
  but the spurious slot makes the single undo in APRO5 restore the wrong state -> exactly
  APRO5 fails.
- SB-E -> targets the guard-suite membership (test_readonly_guard.tcl). Move the gate to
  AFTER the argc<6 check. The bare-verb loop call now gets the "needs:" error instead of
  "read-only" -> test_readonly_guard fails on exactly the apply_properties row (+ its refused
  count); the new APRO file stays fully green (full-arg calls still hit the gate). Run via
  tests/headless/test_readonly_guard.sh.

After each sabotage: revert to the exact fixed text, `git diff src/scheduler.c` must show ONLY
the one-line gate insertion. Final clean rebuild, then a full green re-run of both test files.

### Suite gates

- tests/headless/full_audit.sh — must show NO new failures beyond the recorded batch baseline
  (PLAN.md header, 2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag,
  test_ciw, test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui,
  test_lib_sweep, test_phase3_mints, test_reopen_readonly, test_save_as_cellview,
  test_select_at, test_selflog_output, test_untitled_reuse, test_wire_split.
  (test_fluid_editing passed at batch-start despite the expectation note.) The new
  test_apply_properties_readonly and test_readonly_guard must be PASS.
- tests/property_form suite (PF47/PF48 log seam + PF52 contract untouched):
  `cd src && timeout -s KILL 120 ./xschem -q --script ../tests/property_form/wrap.tcl`,
  then `grep -c FAIL /tmp/sh_pf_test.log` must be 0 (needs DISPLAY; if no X available,
  record that it was skipped and why).

## DOCS

- doc/claude/issues/0126-apply-properties-scripted-readonly-gap.md: Status OPEN -> FIXED
  (date + commit hash), add a "What changed" section: the one-line gate + its placement
  (before argc, setprop/wire convention), the live-repro facts (rc=0/result "1"/prop mutated),
  and the aggravating finding that actions.c:189 ro_suppress made the pre-fix mutation fully
  silent (no modified flag, no autosave). Note the residual: none — the boundary migration for
  this verb stays DEFERRED per the batch receipt, independent of this gate.
- doc/claude/refactor_b_batch/BUGFIX_PLAN.md: ledger item 1 `[ ]` -> `[x]` with a one-line
  outcome, unless the driver pipeline owns the ledger stage — in that case leave it and say so.
- Memory (per discipline): per-item detail goes into the batch block of
  /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/action-logging.md;
  the MEMORY.md index line for action-logging stays one short line (append "bugfix 0126 done"
  style, keep it terse).

## COMMIT

Explicit file list ONLY (never -a / -A):
  src/scheduler.c
  tests/headless/test_apply_properties_readonly.tcl
  tests/headless/test_readonly_guard.tcl
  doc/claude/issues/0126-apply-properties-scripted-readonly-gap.md
  doc/claude/refactor_b_batch/BUGFIX_PLAN.md   (only if edited)

Message:

```
fix(readonly): reject scripted apply_properties on read-only buffer (issue 0126)

The apply_properties scheduler branch had no readonly gate: a scripted/CIW/replay
`xschem apply_properties` mutated a read-only cell silently (set_modify's
ro_suppress hid even the modified flag). One scheduler_readonly_reject at the
branch top, before argc validation, per the setprop/wire convention. The form's
0/1/-1 did-contract and the Tcl-side log seam (D1) are untouched; the form
self-gates and never issues the command when readonly.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

Do NOT push. Do not touch junk dirs (_nhangle_* etc.) or any file outside the list above.
