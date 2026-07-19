# 0125 — `xschem instance` branch: refusal still set_modify(1) + spurious undo slot on no-match

**Status: OPEN** (found 2026-07-18 by the Refactor B batch item-08 scout while DEFERring the
`instance` migration; pre-existing behavior bugs, independent of any migration — fix standalone).

## Two related defects

1. **Refusal marks the schematic modified.** `place_symbol` returns 1-placed / 0-refused
   (actions.c:2452-2453; refusal paths: symbol-view guard at 2469, empty-name at 2477/2503,
   scope-ammeter bail at 2604, match_symbol i==-1). The scheduler `instance` branch
   (scheduler.c:5290-5306) DISCARDS that rc and unconditionally runs `set_modify(1)` + silent
   TCL_OK — a refused placement dirties the buffer and reports success.

2. **No-match refusal burns a spurious undo slot.** Inside `place_symbol`, `push_undo` fires at
   actions.c:2502 BEFORE `match_symbol` at 2504 — a no-match refusal pushes an undo snapshot for
   a mutation that never happens. Same class as issue 0121 (add_pin_stubs late no-op undo);
   same fix shape: lazy push_undo on first actual store.

## Why it matters beyond tidiness

Any future migration of `instance`/`place_symbol` onto the perform_action boundary needs the rc
surfaced for log-on-success; this cleanup is the prerequisite and must land as its OWN change
(behavior fix), never bundled with a migration atom (batch rule).

## Cross-refs

- Batch scout receipt: doc/claude/refactor_b_batch/receipts/08_instance.md
- Sibling issue: 0121 (spurious undo on all-skip add_pin_stubs)
- Migration itself deferred as D3 coordinate-form-bypass: PLAN.md item 08 (funnel logger
  log_placed_instance callback.c:1572-1589; in-code silent-replay-receiver invariant at 1563-1571)
