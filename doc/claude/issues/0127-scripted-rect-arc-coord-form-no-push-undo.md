# 0127 — scripted `xschem rect` (and arc/line siblings) coordinate form: set_modify with NO push_undo

**Status: FIXED** (2026-07-18, fluid-editing, commit `fix(undo): scripted rect/arc/line
coord forms push an undo checkpoint (issue 0127)` — bug-fix batch item 4; three one-line
`xctx->push_undo()` calls in the scheduler rect/line/arc coord arms; found 2026-07-18 by
the Refactor B batch item-25 scout while DEFERring the `rect` migration; pre-existing
behavior bug, independent of any migration — fixed standalone).

## What changed (fix, 2026-07-18)

- src/scheduler.c rect coord arm: `xctx->push_undo();` immediately before its
  `storeobject(..., xRECT, ...)`.
- src/scheduler.c line coord arm: same, immediately before `storeobject(..., LINE, ...)`.
- src/scheduler.c arc coord arm: `xctx->push_undo();` INSIDE the
  `if(layer >= 0 && layer < cadlayers)` success arm, immediately before `store_arc(...)` —
  a refused invalid-layer arc (result "0") still pushes nothing, avoiding a 0121/0125-class
  spurious undo slot; mirrors interactive new_arc's r>0-guarded push. The "1"/"0" result
  contract is untouched.
- Placement rationale: mirrors the `wire` coord branch (which already pushes per scripted
  call, receipts/06_wire.md) and the interactive twins (new_rect actions.c push-before-store,
  new_line, new_arc). Interactive and scripted placements now share undo semantics.
- Live-repro'd bug (scout, current binary): `xschem wire 0 0 100 0` then
  `xschem rect 300 -100 400 -50` then ONE `xschem undo` → the WIRE vanished with the rect
  (undo rode the wire's checkpoint). Same for line and arc coord forms.
- Machinery callers analyzed, per-call push accepted on the wire precedent:
  create_graph.tcl (one rect per composite; its trailing `xschem set_modify 0` does not touch
  undo slots) and place_sym_pins.tcl (N rect + N line per pinlist loop — same class as the
  already-pushing `xschem wire` loops; the MAX_UNDO=80 ring caps depth, undo depth is
  convenience not correctness).
- Regression test: tests/headless/test_scripted_shape_undo.tcl (18 checks: per-shape
  stored/undo-survives-prior-edit/undo-removes-shape/exactly-one-push + redo control +
  invalid-layer-arc no-spurious-slot + set_modify control + readonly refusal controls).
  create_save goldens verified byte-identical pre/post fix (defer trigger does not fire).

## RESIDUAL (still OPEN)

Scripted `xschem text` (scheduler.c `text` branch, create_text) pushes NOTHING and ALSO
never calls set_modify — a worse, two-part bug class (interactive place_text pushes in
actions.c). Fixing it needs its own set_modify decision; deliberately left OUT of this fix
(see receipts/24_text.md).

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
