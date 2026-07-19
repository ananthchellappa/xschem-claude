# 0125 — `xschem instance` branch: refusal still set_modify(1) + spurious undo slot on no-match

**Status: FIXED — both residuals closed** (defect 1, 2026-07-18, commit 84890f12
"fix(instance): refused placement no longer dirties buffer + 1/0 result (issue 0125)";
residuals — burnt undo slot + bbox unbalance in the scope-ammeter bail — fixed
2026-07-18, batch item 6, "fix(instance): scope-ammeter bail balances bbox + no burnt
undo slot (issue 0125 residual)").
Defect 2 as originally written was REFUTED from source; the one real spurious-slot path
(scope-ammeter bail) was a documented RESIDUAL, now fixed via pre-flight — see below.
Only a NARROWED theoretical residual remains (translate-swapped-symbol backstop path).
(Found 2026-07-18 by the Refactor B batch item-08 scout while DEFERring the `instance`
migration; pre-existing behavior bugs, independent of any migration — fixed standalone.)

## Defect 1 (FIXED): refusal marked the schematic modified + leaked a stale result

`place_symbol` returns 1-placed / 0-refused (actions.c:2452-2453; refusal paths:
symbol-view guard at 2469, empty-name at 2477/2503, scope-ammeter bail at ~2604). The
scheduler `instance` branch (scheduler.c, `else if(!strcmp(argv[1], "instance"))`)
DISCARDED that rc and unconditionally ran `set_modify(1)` + left whatever stale interp
result the internals leaked (observed live: ``, `0`, `@spice_get_node`) — a refused
placement dirtied the buffer and reported garbage.

### What changed (src/scheduler.c, instance branch only)

- The rc of `place_symbol` is captured into the existing `placed` flag in all three argc
  arms (7/8/9; the argc==9 batch first_call dance untouched). `placed` hoisted to block
  top for C89.
- `set_modify(1)` moved out of the arms and gated on `placed`; the already-`placed`-gated
  W3 `maintain_wire_segments` call now also (correctly) skips on refusal.
- Deterministic result: `Tcl_SetResult(interp, placed ? "1" : "0", TCL_STATIC)`, TCL_OK
  kept (matches the arc coord-form "1"/"0" precedent).
- Consumer audit 2026-07-18: NOBODY read the old stale-leak result — src/place_pins.tcl:28,
  src/xschem.tcl:3913 + 3937 (no_undo bracket), all tests/ fixture calls are
  statement-position; the single capture (tests/headless/test_noncairo_verbs_ungated.tcl
  `set l1 [xschem instance ...]`) never uses `$l1`. Result-contract defer trigger did not
  fire.
- Regression: tests/headless/test_instance_refusal.tcl (10 checks; 5 refusal variants ×
  {result, modified, instance-delta} consolidated in IR-REF; batch undo-depth, refusal
  no-slot, missing.sym-mutation, readonly and success controls). Red-first verified
  (IR1 + IR-REF red pre-fix, controls green), 6 sabotages each failed exactly their
  target check.

## Defect 2 (REWRITTEN from source — original claim refuted)

The original claim — "no-match refusal burns an undo slot because push at actions.c:2502
precedes match_symbol at 2504" — is WRONG:

- **A no-match refusal DOES NOT EXIST.** `match_symbol` NEVER returns -1 (token.c:182
  comment + structure): an unknown symbol name appends `systemlib/missing.sym` via
  `load_sym_def` (save.c:4660-4668 hard-exits only if missing.sym itself is gone). The
  `if(i!=-1)` guard in actions.c:2506 is dead code. A bad symbol name is therefore a REAL
  mutation (a missing.sym instance is placed) — `set_modify(1)`, rc 1 and the undo slot
  are all CORRECT there (pinned by test check IR9).
- The empty-name bails (actions.c:2477 and the else-arm of the `if(name[0])` push gate at
  2501-2503) return BEFORE the push — no slot (pinned by test check IR6).
- **The ONLY real spurious-slot refusal was the scope-ammeter bail** (`type=scope` with
  zero pin rects and nothing selected): `push_undo` fired, real mutations followed
  (inst array slot, hash, register), then the bail manually rolled back
  (`xctx->instances--`) and returned 0 — the slot survived (live-proven no-op undo #1).
  **FIXED (batch item 6) via option (a): a pre-flight twin of the bail condition now
  runs BEFORE push_undo** in `place_symbol` — `match_symbol` is hoisted above the push
  (idempotent, never returns -1, token.c; the undo snapshot may now carry one extra
  unreferenced symbol def — harmless for both in-memory and disk undo), and the
  scope/no-pins/no-single-ELEMENT-selected condition refuses with the same dbg +
  has_x-gated alert_, rc 0, before any mutation. No undo-discard primitive was needed.
  Test check IR8 consciously FLIPPED from pinning the burnt slot to asserting undo #1
  peels the prior edit in one step; IR12 added as the scope-success control
  (selected ELEMENT → placement still succeeds).

### Second residual found while building the regression (same bail) — also FIXED

The scope-ammeter bail also returned 0 AFTER `bbox(START, ...)` without the matching
`bbox(END)`, leaving `xctx->bbox_set==1`. The NEXT placement's `bbox(START)` then
reported "ERROR: rentrant bbox() call" and — worse — `bbox()` itself calls the real
`alert_` (select.c, unconditional, NOT has_x-gated), i.e. a modal popup under X
(live-verified hang in an X-attached headless run). **FIXED (batch item 6): the in-body
backstop bail now closes with `bbox(END)` under the exact same gate as the START
(`first_call && (draw_sym & 3)`)**, so a batch-owned bbox is never closed from there.
Test check IR11 added (placement after a bail is clean, zero alerts via a counting
alert_ stub).

### NARROWED theoretical residual (left OPEN, documented)

The in-body bail stays as a BACKSTOP: after `translate()` a parameterized/generator
name can in principle swap the symbol for a different one, re-triggering the scope
condition post-mutation. Only on that exotic path: (1) the push already fired, so the
slot still burns; (2) the old bail's pre-existing stale name-hash entry (hash_names
ran before the rollback) still survives. On the normal pre-flighted path both artifacts
are gone — including the transient mutate-then-rollback side effects (stale name-hash
entry) the old bail always left behind.

## Why it mattered beyond tidiness

Any future migration of `instance`/`place_symbol` onto the perform_action boundary needs
the rc surfaced for log-on-success; this cleanup is the prerequisite and landed as its OWN
change (behavior fix), never bundled with a migration atom (batch rule).

## Cross-refs

- Batch scout receipt: doc/claude/refactor_b_batch/receipts/08_instance.md
- Fix prompt: doc/claude/refactor_b_batch/prompts/bugfix_0125.md
- Regression: tests/headless/test_instance_refusal.tcl
- Sibling issue: 0121 (spurious undo on all-skip add_pin_stubs)
- Migration itself deferred as D3 coordinate-form-bypass: PLAN.md item 08 (funnel logger
  log_placed_instance callback.c:1572-1589; in-code silent-replay-receiver invariant at 1563-1571)
