# 0125 — `xschem instance` branch: refusal still set_modify(1) + spurious undo slot on no-match

**Status: FIXED** (defect 1, 2026-07-18, commit: see `git log --oneline -- src/scheduler.c`,
"fix(instance): refused placement no longer dirties buffer + 1/0 result (issue 0125)").
Defect 2 as originally written was REFUTED from source; the one real spurious-slot path
(scope-ammeter bail) is a documented RESIDUAL, left OPEN — see below.
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
- **The ONLY real spurious-slot refusal is the scope-ammeter bail** (actions.c:~2604,
  `type=scope` with zero pin rects and nothing selected): `push_undo` fires at 2502, real
  mutations follow (inst array slot, hash, register), then the bail manually rolls back
  (`xctx->instances--`) and returns 0 — the slot survives (live-proven no-op undo #1).
  Moving the push later cannot fix this (the mutations must stay covered); it needs an
  undo-discard primitive. **RESIDUAL — left OPEN.** Documented by test check IR8, which
  deliberately asserts today's burnt-slot behavior so a future fix flips it consciously.

### Additional residual found while building the regression (same bail, 2026-07-18)

The scope-ammeter bail also returns 0 AFTER `bbox(START, ...)` (actions.c:2567 region)
without the matching `bbox(END)`, leaving `xctx->bbox_set==1`. The NEXT placement's
`bbox(START)` then reports "ERROR: rentrant bbox() call" and — worse — `bbox()` itself
calls the real `alert_` (select.c:811-812), i.e. a modal popup under X (live-verified
hang in an X-attached headless run). The regression test stubs `alert_` for its whole
duration to stay immune. Same missing-cleanup class as the burnt slot; fix together with
the undo-discard residual.

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
