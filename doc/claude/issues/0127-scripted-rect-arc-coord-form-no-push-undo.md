# 0127 — scripted `xschem rect` (and arc/line siblings) coordinate form: set_modify with NO push_undo

**Status: OPEN** (found 2026-07-18 by the Refactor B batch item-25 scout while DEFERring the
`rect` migration; pre-existing behavior bug, independent of any migration — fix standalone).

## Symptom

A scripted `xschem rect <lay> x1 y1 x2 y2 ...` stores the rectangle and marks the schematic
modified, but pushes NO undo checkpoint — undo after a scripted rect silently rides the
PREVIOUS checkpoint, discarding unrelated edits along with the rect.

## Mechanism

- Scheduler rect branch coord arm (scheduler.c:8894-8915): `storeobject(...)` (~8904) +
  `set_modify(1)` (~8915), no `xctx->push_undo()` anywhere in the arm.
- `storeobject` itself (store.c:226) contains zero push_undo/log_action — by design (it is the
  raw store primitive).
- The interactive twin DOES push: `new_rect` PLACE arm pushes undo at actions.c:4576 before its
  storeobject at 4581 — so interactive and scripted rects have divergent undo semantics.

## Scope / siblings

Same interactive-pushes/scripted-does-not asymmetry CONFIRMED for both siblings:
- `arc`: scripted coord arm scheduler.c:2084-2098 does store_arc (2093) + set_modify(1) (2094)
  with no push_undo behind the readonly gate (2080); interactive twin pushes at actions.c:4450
  (receipts/26_arc.md).
- `line`: coord arm storeobject at scheduler.c:5774 + set_modify(1) at scheduler.c:5780 with NO
  push_undo; interactive new_line PLACE pushes at actions.c:4499 before its five emit sites
  (receipts/30_line.md).
`text` is worse (NEITHER path's scripted form pushes; see receipts/24_text.md) but shares the class.

Fix shape: a lazy push_undo at the top of each scripted coord arm (or in a shared helper),
mirroring the interactive arm. Same class as issues 0121 / 0125 (spurious/missing undo at
store boundaries).

## Cross-refs

- Batch scout receipt: doc/claude/refactor_b_batch/receipts/25_rect.md
- Interactive funnel log site (why rect is NOT silent): actions.c:4584-4585 (`RECTORDER`'d
  read-back coords)
- Sibling issues: 0121 (add_pin_stubs spurious undo), 0125 (instance refusal undo/set_modify)
