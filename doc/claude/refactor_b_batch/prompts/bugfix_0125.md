# Bugfix implement prompt — issue 0125 RESIDUAL: scope-ammeter bail burns an undo slot + leaves bbox(START) unbalanced

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
Issue file: doc/claude/issues/0125-instance-branch-refusal-set-modify-spurious-undo.md
Plan: doc/claude/refactor_b_batch/BUGFIX_PLAN.md item 6 (issue-0125-residual).
Predecessor: item 5 (commit 84890f12) fixed the scheduler `instance` branch (rc capture,
gated set_modify, "1"/"0" result) and DOCUMENTED these two residuals; its receipt is
doc/claude/refactor_b_batch/receipts/bugfix_0125.md. This item fixes the residuals in
src/actions.c `place_symbol`. (This prompt file replaces the consumed item-5 prompt;
the old version is preserved in git history.)

## The two legs (scout re-verified from source 2026-07-18, binary feb3071e)

`place_symbol` (src/actions.c:2453) refuses a `type=scope` symbol with zero PINLAYER
pin rects when no single ELEMENT is selected ("scope-ammeter bail"). Today that bail
sits DEEP inside the placement body — after `push_undo`, after real mutations — and
manually rolls back. Two things leak:

- **Leg 1 (bbox unbalance)**: the bail returns 0 AFTER `bbox(START,...)` fired at
  actions.c:2567 (`if(first_call && (draw_sym & 3))`) without the matching
  `bbox(END)`, leaving `xctx->bbox_set==1`. The NEXT placement's `bbox(START)` then
  prints "ERROR: rentrant bbox() call" AND unconditionally tclevals the real `alert_`
  (src/select.c:810-812 — a modal popup under X; live-verified). Live-reproduced by
  the scout in the current test run: the reentrant error line appears during the
  placement following the bail (it survives intervening `xschem undo` +
  `xschem clear force` — nothing else resets bbox_set).
- **Leg 2 (burnt undo slot)**: `push_undo` fires at actions.c:2502 before the
  mutations the bail rolls back (`xctx->instances--`), so the slot survives as a
  no-op undo. Pinned today by test check IR8, which DELIBERATELY asserts the
  burnt-slot behavior and says to flip it consciously — this fix flips it.

**Leg-2 fix shape (scout decision, option (a) from the plan): pre-flight the bail
condition BEFORE push_undo.** All needed info is available pre-mutation:
- `match_symbol` (src/token.c:182-202) NEVER returns -1 and is idempotent (second
  call finds the symbol in the loop); calling it before the push only moves the
  symbol-load earlier. Undo-snapshot impact verified harmless: in-memory undo
  (src/in_memory_undo.c:316-352, mem_serialize_slot) snapshots the whole sym array
  — the snapshot now contains one extra (unreferenced) symbol def, self-consistent;
  disk undo (src/save.c:4050 push_undo) writes the schematic file, which embeds only
  referenced/embedded symbols — unaffected.
- `xctx->sym[i].type`, `xctx->sym[i].rects[PINLAYER]` are set by load_sym_def;
  `xctx->lastsel` / `xctx->sel_array[0]` are read RAW, exactly as the in-body check
  at 2588 reads them (deliberate parity — do NOT add a rebuild_selected_array call).

The in-body bail STAYS as a backstop: after `translate()` (actions.c:2558-2563) the
symbol can in principle be swapped for a different one (parameterized/generator
names), so the post-translate check at 2578-2606 remains reachable in that exotic
path. Leg 1's `bbox(END)` goes there so the backstop no longer poisons bbox_set.
The backstop path still burns a slot (push already fired) — that becomes a
NARROWED, theoretical-only residual; document it (see Docs step).

## Verified anchors (fresh 2026-07-18 — re-verify before editing, lines drift)

- src/actions.c:2453 `int place_symbol(int pos, const char *symbol_name, ...`
- src/actions.c:2469 symbol-view guard `if(editing_symbol_view()) return 0;`
- src/actions.c:2477 `if(!name1[0]) return 0;`
- src/actions.c:2501-2504:
  ```c
   if(name[0]) {
     if(first_call && to_push_undo) xctx->push_undo();
   } else  return 0;
   i=match_symbol(name);
  ```
- src/actions.c:2506 `if(i!=-1)` (dead-true guard, leave untouched)
- src/actions.c:2567 `if(first_call && (draw_sym & 3) ) bbox(START, 0.0 , 0.0 , 0.0 , 0.0);`
- src/actions.c:2578 `if(xctx->sym[i].type && !strcmp(xctx->sym[i].type, "scope")) {`
- src/actions.c:2587 `if(xctx->sym[i].rects[PINLAYER] == 0) {`
- src/actions.c:2588 `if(xctx->lastsel == 1 && xctx->sel_array[0].type==ELEMENT) {`
- src/actions.c:2593-2605 the else arm: `const char msg[]=...`, dbg, has_x-gated
  alert_, `#if 1` block freeing instname/name/prop_ptr/lab/prop, `xctx->instances--;`,
  `return 0;`
- src/select.c:804 `void bbox(int what,...)`; START reentrant error+alert_ at 810-812
  (alert unconditional, NOT has_x-gated); END at 848-863 is a NO-OP when
  `bbox_set==0` (safe to call defensively) and restores saved area + clears bbox_set
  otherwise.
- src/scheduler.c:5289-5316 `instance` branch (post-84890f12): argc 7/8 call
  place_symbol with draw_sym=3, first_call=1, to_push_undo=1; argc==9 with
  draw_sym=0, first_call=!atoi(argv[8]).
- src/scheduler.c:3824-3828 `xschem get lastsel` calls rebuild_selected_array()
  (the test uses this to make a headless `xschem select instance` selection visible
  to the raw lastsel read — select_element only sets need_reb_sel_arr).
- tests/headless/test_instance_refusal.tcl — 10 checks, ALL PASS on the unfixed
  binary (scout ran it live); IR8 (line ~125) pins the burnt slot; blanket alert_
  stub at lines ~41-42; B7 scope-bail block at ~103-128.
- xschem_library/devices/scope_ammeter.sym: `K {type=scope` at line 23, zero
  PINLAYER pin rects (the bail fires live, proving the condition).

Consumer audit (all 10 place_symbol callsites, scout-enumerated): scope symbols are
reachable only via the scheduler `instance` branch (5296/5300/5304), the
`place_symbol` verb (scheduler.c:7896/7898/7901, draw=4), and the interactive
Insert dialog (callback.c:327 start_place_symbol, draw=4) — all benefit from both
legs. Fixed-symbol callers (actions.c:1427 lab_pin draw=0; 2305-2309 lab_* draw=2;
2359-2368 lab_* draw=4; place_sch_pin 2397 / place_wire_label 2421 ipin/opin/iopin/
lab_pin draw=4 push=0) can never trip the scope pre-flight — unchanged.

## EDITS (src/actions.c only — two edits)

**EDIT A (leg 1, do FIRST — staged red-first, see Test protocol)**: in the bail's
`#if 1` block (2597-2605), immediately before `return 0;`, add:

```c
        /* issue 0125 residual: balance the bbox(START) opened at 2567 for this
         * first_call; bailing with bbox_set==1 poisons the NEXT placement
         * (reentrant-bbox error + real alert_ modal from select.c bbox()).
         * Gate mirrors the START gate exactly so a batch-owned bbox (first_call==0)
         * is never closed from here. */
        if(first_call && (draw_sym & 3)) bbox(END, 0.0, 0.0, 0.0, 0.0);
```

**EDIT B (leg 2)**: replace actions.c:2501-2504 (the push gate + match) with:

```c
 if(!name[0]) return 0;
 /* issue 0125 residual: resolve the symbol BEFORE push_undo (match_symbol is
  * idempotent and never returns -1, token.c) so the scope-ammeter refusal below
  * can bail without burning an undo slot. Snapshot-ordering delta is harmless:
  * the undo slot may now contain one extra unreferenced symbol def. */
 i = match_symbol(name);
 /* Pre-flight twin of the in-body scope-ammeter bail (below, at the
  * rects[PINLAYER]==0 arm): a type=scope symbol with no pins needs exactly one
  * selected ELEMENT to link to; refuse BEFORE push_undo and before any mutation.
  * lastsel/sel_array are read raw, in deliberate parity with the in-body check.
  * The in-body bail stays as a backstop for the exotic translate()-swapped-symbol
  * path (that path still burns a slot - documented residual in issue 0125). */
 if(xctx->sym[i].type && !strcmp(xctx->sym[i].type, "scope")
    && xctx->sym[i].rects[PINLAYER] == 0
    && !(xctx->lastsel == 1 && xctx->sel_array[0].type == ELEMENT)) {
   const char msg[]="scope_ammeter is being inserted but no selected ammeter device/vsource to link to\n";
   dbg(0, "%s", msg);
   if(has_x) tclvareval("alert_ {", msg, "} {} 1", NULL);
   return 0;
 }
 if(first_call && to_push_undo) xctx->push_undo();
```

C89: `const char msg[]` is the first declaration of its block (same pattern as the
in-body arm at 2594). `i` is already declared at function top. No new allocations.
Do NOT touch the `if(i!=-1)` guard, the in-body bail's rollback, or anything else.

Behavior deltas (all confined to the scope-ammeter refusal path): no burnt undo
slot; no bbox poisoning; the transient mutate-then-rollback side effects vanish
(incl. a pre-existing stale name-hash entry the old bail left behind — note it in
the issue file); alert/dbg message, rc 0, scheduler "0" result, modified==0 all
IDENTICAL. Success paths byte-identical except symbol-load-before-push (verified
harmless above).

Build: `make -C src` (or `make` from repo root). Rebuild after every edit/sabotage.

## Test plan — extend tests/headless/test_instance_refusal.tcl (no new file)

Run form (own process, repo-root cwd — relative paths break otherwise):
`src/xschem --pipe -q --nolog --script tests/headless/test_instance_refusal.tcl`

Four changes:

1. **Counting alert stub** (replaces the blanket stub at ~41-42; keep the
   rename/restore bracket):
   ```tcl
   set ::alert_count 0
   rename alert_ alert_orig_0125
   proc alert_ {args} {incr ::alert_count; return 1}
   ```
   Update the stub's comment: it still guards the X-attached-run hang (item-5
   receipt), and now also witnesses that no alert fires where none should.

2. **Flip IR8 consciously** (its comment says to): after the scope refusal,
   `xschem undo` must now peel the wire in ONE step — no burnt slot:
   ```tcl
   check "IR8 scope refusal burns no undo slot: undo #1 peels the wire" \
     [expr {[xschem get wires] == 0}] "(wires=[xschem get wires])"
   ```
   Rewrite the RESIDUAL-DOC comment above it: fixed by the pre-flight bail
   (issue 0125 residual); only the theoretical translate-swapped-symbol backstop
   path still burns a slot.

3. **New check IR11 (bbox balance — the regression the bug caused)**, new block
   after B7, before B8:
   ```tcl
   # B7b IR11: the bail must not poison bbox state for the NEXT placement
   xschem clear force
   xschem unselect_all
   xschem instance devices/scope_ammeter.sym 300 300 0 0   ;# refusal
   set ::alert_count 0                                     ;# window starts AFTER the refusal
   set r [xschem instance devices/lab_pin.sym 0 0 0 0 {name=lbb lab=bb}]
   check "IR11 placement after scope bail: clean (no reentrant-bbox alert)" \
     [expr {$r eq "1" && [xschem get instances] == 1 && $::alert_count == 0}] \
     "(r='$r' instances=[xschem get instances] alerts=$::alert_count)"
   xschem clear force
   ```
   (Windowed reset makes it immune to the has_x-gated refusal alert in X-attached
   audit runs.)

4. **New check IR12 (unchanged-behavior control: scope SUCCESS with a selected
   device)**, after IR11, before B8:
   ```tcl
   # B7c IR12: with exactly one selected ELEMENT the scope placement must SUCCEED
   xschem clear force
   xschem instance devices/res.sym 100 100 0 0 {name=R1 value=1k}
   xschem select instance R1
   set ls [xschem get lastsel]   ;# forces rebuild_selected_array (select_element only flags)
   set r [xschem instance devices/scope_ammeter.sym 400 400 0 0]
   check "IR12 scope+selected-device still places (control)" \
     [expr {$ls == 1 && $r eq "1" && [xschem get instances] == 2}] \
     "(lastsel=$ls r='$r' instances=[xschem get instances])"
   xschem clear force
   ```

Also update the file-header comment (top of the test) to mention the residual fix.
Everything else (IR1, IR4a-c, IR6, IR7, IR9, IR10, V1-V5/IR-REF) stays byte-identical
— they are the unchanged-behavior + readonly + undo controls. Final count: 12 checks.

### Red-first protocol (STAGED — this doubles as leg isolation evidence)

1. Extend the test FIRST, run on the UNFIXED binary: expect EXACTLY IR8 RED
   (wires==1) and IR11 RED (alert_count==1); IR12 GREEN (control holds pre-fix);
   all 9 others GREEN. If IR12 is red pre-fix, STOP and investigate — the control
   contract is wrong.
2. Apply EDIT A only, rebuild, rerun: IR11 flips GREEN, IR8 still RED — proves
   leg 1 alone owns IR11.
3. Apply EDIT B, rebuild, rerun: 12/12 GREEN.

### Sabotages (each fails EXACTLY its target; revert via `git diff` confirming only
the sabotage, then targeted `git checkout -- src/actions.c`, rebuild, green rerun)

- **SB-PRE → target IR8**: in EDIT B's condition append `&& 0` (pre-flight dead,
  in-body bail handles the refusal). Expect IR8 RED only — IR11 stays green
  (EDIT A backstop closes the bbox), IR7/IR12/V4/IR-REF green.
- **SB-END → target IR11 (declared DIFFERENTIAL, two-step)**: EDIT A's line is
  unreachable with the pre-flight active, so: with SB-PRE still applied, ALSO
  delete EDIT A's bbox(END) line. Expect IR8 AND IR11 RED; the delta vs SB-PRE
  alone (IR8 only) attributes IR11 exactly to the bbox(END) line. Record it as a
  differential sabotage in the receipt.
- **SB-SEL → target IR12**: in EDIT B replace the
  `!(xctx->lastsel == 1 && xctx->sel_array[0].type == ELEMENT)` term with `1`
  (refuse even with a selection). Expect IR12 RED only (refusal paths behave
  identically, so IR7/IR8/IR11/V4 stay green).

After the last revert: rebuild + one clean 12/12 run.

## Suite gates

- `tests/headless/full_audit.sh` from repo root, ONCE after the fix. Baseline
  fails (pre-existing, PLAN.md header, 14 tests): test_cadence_descend_newwin_ro,
  test_cadence_drag, test_ciw, test_descend_untitled_preserve, test_hi_descend,
  test_lib_manager_gui, test_lib_sweep, test_phase3_mints, test_reopen_readonly,
  test_save_as_cellview, test_select_at, test_selflog_output, test_untitled_reuse,
  test_wire_split. Anything else failing: retry in isolation before counting it
  (item-5 receipt: congestion flakes are common; all its 5 extra fails passed
  isolated). Watch specifically: test_instance_refusal PASS + the item-5 fixture
  watchlist (test_create_instance, test_paste_at_log, test_rotmove_drop_log,
  test_noncairo_verbs_ungated, test_perform_action_instance_number). No
  logdir_tests registration needed (default --nolog runner, auto-discovered).
- create_save gate (place_symbol itself changed): run tests/create_save.tcl per
  the item-4/5 precedent — no tracked gold in this worktree; run via a PATH
  wrapper that execs src/xschem by ABSOLUTE path (bare `xschem` loses argv[0]
  sharedir detection); expect zero FATAL, outputs populated.

## Docs step

- Issue file doc/claude/issues/0125-instance-branch-refusal-set-modify-spurious-undo.md:
  header → both residuals FIXED (this commit); rewrite the "Defect 2" residual
  paragraph + "Additional residual" section: fixed via pre-flight bail before
  push_undo (option (a) — no undo-discard primitive needed) + bbox(END) balance in
  the backstop bail; note IR8 flipped + IR11/IR12 added; record the NARROWED
  theoretical residual (translate-swapped-symbol reaching the backstop still burns
  a slot; the old bail's stale name-hash entry also only survives on that path).
- Memory (discipline): per-item detail appended to the auto-memory
  action-logging.md batch block; MEMORY.md index stays one short line (no new line
  — update the existing batch line only if needed).
- BUGFIX_PLAN.md ledger line for item 6 is the driver's job, not yours.

## Commit

Explicit file list ONLY (never -a / -A, never push):

```
git add src/actions.c tests/headless/test_instance_refusal.tcl doc/claude/issues/0125-instance-branch-refusal-set-modify-spurious-undo.md
```

Message:

```
fix(instance): scope-ammeter bail balances bbox + no burnt undo slot (issue 0125 residual)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```
