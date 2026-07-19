# Bugfix implement prompt — issue 0125: `xschem instance` refusal still set_modify(1) + stale-result leak

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
Issue file: doc/claude/issues/0125-instance-branch-refusal-set-modify-spurious-undo.md
Scout receipt (batch item 08): doc/claude/refactor_b_batch/receipts/08_instance.md
Plan: doc/claude/refactor_b_batch/BUGFIX_PLAN.md item 5.

## Bug (LIVE-repro'd 2026-07-18 by the scout, current binary feb3071e)

The scheduler `instance` branch discards `place_symbol`'s 1-placed/0-refused rc and
unconditionally runs `set_modify(1)` + leaves whatever stale interp result the internals
leaked. Live headless (`--nogui --pipe -q --nolog --script`, repo-root cwd):

- `xschem instance {} 100 100 0 0` → refused (instances stays 0) but `xschem get modified`
  == 1; result was `` (empty).
- `xschem instance {   } 100 100 0 0` → same (whitespace trims to empty name).
- symbol view (`xschem load -force xschem_library/devices/res.sym`) then
  `xschem instance devices/capa.sym 0 0 0 0` → refused, modified == 1.
- `xschem instance devices/scope_ammeter.sym 300 300 0 0` with nothing selected →
  scope-ammeter bail: refused (instance rolled back, instances 0) but modified == 1 AND
  result leaked `@spice_get_node` AND one spurious undo slot burnt (a wire placed before
  the refusal needs TWO undos to disappear; undo #1 is a no-op restoring the same state).
- Successful placements leak stale results too: a batch `xschem instance ... $i` loop
  returned `0` on every call that placed.

## Scout decision (PROCEED, scope NARROWED to part (a))

**Part (a) — scheduler branch rc capture + deterministic result: FIX.** Capture the rc into
the existing `placed` flag, gate `set_modify(1)` (and the already-`placed`-gated W3
`maintain_wire_segments`) on it, and set an explicit `1`/`0` result (TCL_OK kept).
Consumers verified 2026-07-18 — NOBODY reads the result today (it is stale-leak garbage:
observed ``, `0`, `@spice_get_node`): src/place_pins.tcl:28, src/xschem.tcl:3913 + 3937
(inside a no_undo bracket), all tests/ + tests/headless/ fixture calls are
statement-position; the single capture, tests/headless/test_noncairo_verbs_ungated.tcl:111
`set l1 [xschem instance ...]`, never uses `$l1`. Arc coord form precedent already returns
"1"/"0" (scheduler.c arc branch). So the result-contract defer trigger does NOT fire.

**Part (b) — place_symbol lazy push_undo: DROPPED, refuted as stated.** The issue's defect 2
("no-match refusal burns an undo slot because push at 2502 precedes match_symbol at 2504")
is wrong from source: `match_symbol` NEVER returns -1 (token.c:182 comment + structure —
unknown names append systemlib/missing.sym via load_sym_def, save.c:4660-4668 hard-exits
only if missing.sym itself is gone), so the `if(i!=-1)` guard (actions.c:2506) is dead code
and a bad symbol name is a REAL mutation (missing.sym instance placed — set_modify correct).
The empty-name bails (actions.c:2477 and 2503) return BEFORE the push at 2502 — no slot.
The ONLY real spurious-slot refusal is the scope-ammeter bail (actions.c:2604): push fires
at 2502, real mutations follow (inst array, hash, register), then the bail manually rolls
back (`xctx->instances--`) and returns 0 — the slot survives (live-proven no-op undo).
Moving the push later cannot fix that (mutations must stay covered); it needs an
undo-discard primitive. RESIDUAL — record in the issue file, do not attempt here.

## ANCHORS (all re-verified from source 2026-07-18 — re-verify again before editing, lines drift)

- src/scheduler.c:5289 — `else if(!strcmp(argv[1], "instance"))`. Branch body 5290-5315:
  5291 !xctx check; 5292 `scheduler_readonly_reject(interp, "instance")`; 5293
  `int placed = 0;` (NOTE: currently declared AFTER two statements — hoist to block top for
  C89 while editing); argc==7 arm 5294-5299, argc==8 arm 5300-5303, argc==9 arm 5304-5309
  (`int x = !(atoi(argv[8]));` — the batch first_call dance: first call argv[8]=0 →
  first_call=1 pushes once, calls 2..N argv[8]!=0 → first_call=0 no push. DO NOT PERTURB);
  every arm ends `set_modify(1); placed = 1;`; W3 comment 5310-5313; 5314
  `if(placed && tclgetboolvar("autotrim_wires")) maintain_wire_segments();`.
  No Tcl_SetResult anywhere in the branch.
- src/actions.c:2453 — `place_symbol(...)`, contract comment "returns 1 if symbol
  successfully placed, 0 otherwise" at 2452. Refusal paths: 2469 symbol-view guard
  (editing_symbol_view, actions.c:2436, `.sym` filename test); 2477 empty name1; 2503
  empty name after rel_sym_path (else-arm of the `if(name[0])` push gate at 2501-2503);
  2604 scope-ammeter no-selection bail (inside `type==scope && rects[PINLAYER]==0`,
  `has_x`-gated `alert_` at 2596, manual rollback then `return 0`). Success `return 1` at
  2644. Do NOT touch actions.c.
- src/token.c:182 — `match_symbol` "never returns -1" (comment + code).
- xschem_library/devices/scope_ammeter.sym — `type=scope`, zero `B ` pin rects → the 2604
  bail triggers when nothing is selected. Verified reachable headless as
  `devices/scope_ammeter.sym` (NOT systemlib/...).
- src/xschem.tcl:11290 `alert_` — third arg 1 = nowait (no tkwait window) but still
  `tkwait visibility` under X → stub it in the test's scope block (0128 editor-stub
  precedent) so full_audit's X-attached run cannot flake.
- Headless profile: `autotrim_wires` == 0 (src/xschemrc leaves it off headless), so the W3
  maintain call never runs in the tests.
- Readonly refusal (unchanged, control): rc=1, msg
  `xschem instance: schematic is read-only (use Edit > Make Editable to enable editing)`.
- Undo ring persists across `xschem clear force` (clear_schematic never calls clear_undo).
- Live-verified batch semantics (expected values for IR4): wire + 3-call batch
  (`... "name=p$i lab=n$i" $i`, i=0,1,2) → instances==3; ONE undo removes all three and
  keeps the wire; second undo peels the wire.
- tests/headless/full_audit.sh — auto-discovers tests/headless/test_*.tcl; default runner
  `--pipe -q --nolog --script <file>` from repo root; pass banner `RESULT: ALL PASS`.

## EDITS (exact scope — src/scheduler.c ONLY; C89; rebuild `cd src && make`)

Rewrite the `instance` branch body (scheduler.c:5290-5315) to:

```c
    {
      int placed = 0; /* issue 0125: rc of place_symbol, 1-placed / 0-refused */
      if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
      if(scheduler_readonly_reject(interp, "instance")) return TCL_ERROR;
      if(argc==7) {
       /*           pos sym_name      x                y             rot       */
        placed = place_symbol(-1, argv[2], atof(argv[3]), atof(argv[4]), (short)atoi(argv[5]),
               /* flip              prop draw first to_push_undo */
               (short)atoi(argv[6]),NULL,  3,   1,      1);
      } else if(argc==8) {
        placed = place_symbol(-1, argv[2], atof(argv[3]), atof(argv[4]), (short)atoi(argv[5]),
               (short)atoi(argv[6]), argv[7], 3, 1, 1);
      } else if(argc==9) {
        int x = !(atoi(argv[8]));
        placed = place_symbol(-1, argv[2], atof(argv[3]), atof(argv[4]), (short)atoi(argv[5]),
               (short)atoi(argv[6]), argv[7], 0, x, 1);
      }
      /* issue 0125: a refusal (symbol-view guard, empty name, scope-ammeter bail) must not
       * dirty the buffer; it used to set_modify(1) unconditionally and leak a stale result */
      if(placed) set_modify(1);
      /* W3: ... keep the existing W3 comment verbatim ... */
      if(placed && tclgetboolvar("autotrim_wires")) maintain_wire_segments();
      Tcl_SetResult(interp, placed ? "1" : "0", TCL_STATIC); /* issue 0125: 1-placed / 0-refused */
    }
```

Deltas vs today: `placed` hoisted to block top (C89) and assigned from the rc in all three
arms (batch dance untouched); `set_modify(1)` moved out of the arms and gated; explicit
"1"/"0" result. The `placed` gate on maintain_wire_segments now also (correctly) skips the
W3 pass on refusal. No change to actions.c, the readonly gate, the argc arms' arguments, or
any other branch.

## TEST PLAN

NEW test file tests/headless/test_instance_refusal.tcl (auto-discovered by full_audit; own
process; repo-root cwd; per-check `ok:`/`FAIL:` lines; final `RESULT: ALL PASS` /
`RESULT: N FAILED` + matching exit code; end `xschem exit closewindow force`; copy the shape
of tests/headless/test_scripted_shape_undo.tcl). No fixture file — untitled buffer +
`xschem clear force` per block. Never save.

The five refusal variants each record THREE facts (result string, modified flag read right
after the call, instances delta == 0) into accumulator vars; ONE consolidated check IR-REF
asserts all of them at the end (this makes each sabotage below fail exactly one check).

Blocks in order:

- B1 IR1 (success contract; argc==8): clear force; `xschem set_modify 0`;
  `set r [xschem instance devices/lab_pin.sym 0 0 0 0 {name=l1 lab=clk}]` →
  check IR1: instances==1 && modified==1 && `$r eq "1"`.
- B2 V1 (empty name, argc==7): clear force; set_modify 0; `xschem instance {} 100 100 0 0`.
- B3 V2 (whitespace name, argc==8): clear force; set_modify 0;
  `xschem instance {   } 100 100 0 0 {name=x1}`.
- B4 V3 (batch-form refusal, argc==9): clear force; set_modify 0;
  `xschem instance {} 100 100 0 0 {name=x1} 0`.
- B5 IR4a/b/c (batch success + first_call dance + undo depth): clear force;
  `xschem wire 0 0 100 0`; set_modify 0; loop i 0..2
  `xschem instance devices/lab_pin.sym [expr {100*$i}] -100 0 0 "name=p$i lab=n$i" $i` →
  IR4a: instances==3 && modified==1; `xschem undo` → IR4b: instances==0 && wires==1
  (ONE slot for the whole batch); `xschem undo` → IR4c: wires==0. (Do NOT check results
  here — covered by IR1/IR-REF.)
- B6 IR6 (refusal adds no undo slot — control): clear force; `xschem wire 0 0 100 0`;
  `xschem instance {} 0 0 0 0`; `xschem undo` → IR6: wires==0 (single undo peels the wire;
  the refusal pushed nothing).
- B7 V4 + IR7 + IR8 (scope-ammeter bail): clear force; `xschem wire 0 0 100 0`;
  set_modify 0; `xschem unselect_all`; stub the alert
  (`rename alert_ alert_orig_0125; proc alert_ {args} {return 1}`);
  `xschem instance devices/scope_ammeter.sym 300 300 0 0` (record V4 facts; NOTE: wires
  delta 0 too) → IR7: instances==0 (bail rolled the instance back); `xschem undo` →
  IR8 (RESIDUAL DOC, part (b) — expected to FLIP when the residual is ever fixed):
  wires==1 (the burnt slot makes undo #1 a no-op). Restore the alert
  (`rename alert_ {}; rename alert_orig_0125 alert_`); clear force.
- B8 IR9 (bad name is a MUTATION, not a refusal — semantic pin): clear force; set_modify 0;
  `xschem instance no_such_symbol_0125.sym 200 200 0 0` → IR9: instances==1 &&
  modified==1 (missing.sym placed; do NOT check the result here).
- B9 IR10 (readonly control): clear force; `xschem set readonly 1`;
  `catch {xschem instance devices/res.sym 0 0 0 0}` → IR10: rc==1 && msg matches
  `*read-only*` && instances==0; `xschem set readonly 0`.
- B10 V5 (symbol-view guard, LAST — leaves the schematic buffer):
  `xschem load -force xschem_library/devices/res.sym`; set_modify 0;
  `xschem instance devices/capa.sym 0 0 0 0` (record V5 facts).
- Final consolidated check IR-REF: for EVERY variant V1..V5: result eq "0" && modified==0
  && instances-delta==0. Print per-variant detail with `puts` before the check for
  diagnosability.

RED FIRST: run the new test against the UNFIXED binary. Expected red: IR-REF (all five
variants dirty modified; results are stale garbage) and IR1 (result sub-assertion — the
leaked result was observed as ``/`0`/`@spice_get_node`; if it coincidentally reads "1"
pre-fix, note it in the receipt, the check stays). IR4a-c, IR6, IR7, IR8, IR9, IR10 must be
GREEN pre-fix (controls). Then apply the edit, rebuild, re-run: all green.

### Sabotage verification

Each: edit src/scheduler.c only, rebuild, run the new test, confirm EXACTLY the target
check fails (and nothing else), revert by exact-string re-edit back to the fixed text,
`git diff src/scheduler.c` must then show ONLY the intended fix. After ALL sabotages: one
clean rebuild + full green re-run.

- SB-MOD → IR-REF. Change `if(placed) set_modify(1);` back to unconditional
  `set_modify(1);`. All five variants report modified==1 → only IR-REF red (IR1/IR4
  expect modified==1 anyway; IR6/IR7/IR8 don't read modified).
- SB-CAP7 → IR-REF. In the argc==7 arm only, discard the rc again
  (`place_symbol(...); placed = 1;`). V1/V4/V5 report result "1" + modified 1 → only
  IR-REF red (IR7 instances==0 unaffected; IR8 slot shape unchanged; autotrim off so the
  maintain call stays inert).
- SB-CAP9 → IR-REF. Same discard in the argc==9 arm only → V3 dirty → only IR-REF red
  (IR4's batch success legitimately has placed=1).
- SB-RES → IR-REF. `Tcl_SetResult(..., placed ? "1" : "0", ...)` → always `"1"` →
  refusal results wrong → only IR-REF red (IR1 still sees "1").
- SB-SUC → IR1. Same line → always `"0"` → only IR1 red (IR-REF still sees "0";
  IR4/IR9 check no results).
- SB-UND → IR6. Add `if(!placed) xctx->push_undo();` after the arms → the B6 refusal
  burns a slot, its single undo restores {wire} → IR6 red. IR8 stays green (it asserts
  only undo #1 wires==1, which an extra slot also satisfies); IR4 unaffected (no refusal
  in that block).

### Suite gates

- tests/headless/full_audit.sh — NO new failures beyond the recorded batch baseline
  (PLAN.md header, 2026-07-18, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag,
  test_ciw, test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui,
  test_lib_sweep, test_phase3_mints, test_reopen_readonly, test_save_as_cellview,
  test_select_at, test_selflog_output, test_untitled_reuse, test_wire_split.
  (Congestion flakes have precedent — retry suspects in isolation and record.
  test_fluid_editing FE8 pre-existing per the 0127 receipt.) The new test_instance_refusal
  must be PASS. Watch test_create_instance, test_paste_at_log, test_rotmove_drop_log,
  test_noncairo_verbs_ungated, test_perform_action_instance_number — they drive the edited
  branch as fixture machinery (statement-position, result unread) and must stay green.
- create_save goldens (success-path insurance — fixture scripts place instances through
  this branch): `cd tests && tclsh create_save.tcl` → no FAIL/GOLD?/FATAL.

## DOCS

- doc/claude/issues/0125-instance-branch-refusal-set-modify-spurious-undo.md:
  Status OPEN → FIXED (date + commit hash) for defect 1, with a "What changed" section
  (rc captured, set_modify + W3 maintain gated, deterministic "1"/"0" result, consumer
  audit: nobody read the old stale-leak result). REWRITE defect 2 with the source-verified
  truth: no-match refusal DOES NOT EXIST (match_symbol never returns -1 — token.c:182,
  missing.sym fallback; the actions.c `if(i!=-1)` guard is dead code; bad names are real
  mutations), the empty-name bails return before the push, and the ONLY spurious-slot path
  is the scope-ammeter bail (push 2502 → real mutations → manual rollback → return 0) which
  needs an undo-discard primitive — RESIDUAL, left OPEN, documented by test check IR8
  (deliberately asserts today's burnt-slot behavior so a future fix flips it consciously).
- doc/claude/refactor_b_batch/BUGFIX_PLAN.md: the driver pipeline owns the ledger stage —
  leave item 5 for the driver unless instructed otherwise.
- Memory (per discipline): per-item detail into the batch block of
  /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/action-logging.md;
  the MEMORY.md action-logging index line stays ONE short line.

## COMMIT

Explicit file list ONLY (never -a / -A):
  src/scheduler.c
  tests/headless/test_instance_refusal.tcl
  doc/claude/issues/0125-instance-branch-refusal-set-modify-spurious-undo.md

Message:

```
fix(instance): refused placement no longer dirties buffer + 1/0 result (issue 0125)

The scheduler instance branch discarded place_symbol's 1-placed/0-refused rc:
every refusal (symbol-view guard, empty name, scope-ammeter bail) still ran
set_modify(1) and returned whatever stale interp result the internals leaked.
Capture the rc, gate set_modify + the W3 maintain pass on it, and return a
deterministic "1"/"0" (TCL_OK kept; no consumer read the old garbage result).
The issue's claimed no-match spurious undo is refuted from source (match_symbol
never returns -1); the real scope-ammeter burnt-slot residual is recorded in the
issue file and pinned by a residual-doc test check.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

Do NOT push. Do not touch junk dirs (_nhangle_* etc.) or any file outside the list above.
