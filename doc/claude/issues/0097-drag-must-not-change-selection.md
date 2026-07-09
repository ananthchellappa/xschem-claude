# 0097 — press-hold-drag-release must not change the selection (Cadence deferred-selection)

**Branch:** fluid-editing   **Status:** FIXED + regression test + valgrind-clean, UNCOMMITTED
**Spec:** doc/claude/specs/cadence_modifier_drag.md (§ deferred-selection)
**Test:** tests/headless/test_drag_keeps_selection.tcl (X-required, self-skips under --nogui)

## Requirement
A "click and drag" is really *press, hold, move, release*. A **click** (press+release, no
motion) selects, as always. A **drag** must NOT change the selection membership:
- nothing selected + drag an object → the object moves and ends **unselected**;
- selection S + drag an object **not in S** → the object moves, **S is preserved untouched**
  (the dragged object is not added to it) — Cadence lets you keep a selection while dragging a
  different wire;
- an object in S + drag it → S moves and stays selected.

## Symptom (before)
With nothing selected, press-drag-release R18 (before_5.sch) left **R18 selected** afterward
(`lastsel` 0→1). The transient selection the move needs leaked into the persistent selection.

## Root cause
The intuitive/cadence press path SELECTS at press: `handle_button_press` (callback.c) does
`unselect_all` + `select_object` on the grabbed object (needed because the move engine is
selection-based), then starts the move; on release the object stays selected. There was no
notion of "this selection was only transient, for the drag".

## Fix
A **deferred-selection** restore, scoped to a plain (no-modifier) intuitive drag of a
not-already-selected object:
- **Snapshot** the pre-press selection by session-stable id *before* the press-time
  `unselect_all` (`drag_sel_snapshot`, select.c) — only when an object was hit.
- **Arm** the restore at the actual move START branch (cadence plain + non-cadence plain),
  gated on `did_snapshot` so a read-only press or a Ctrl/Shift gesture never arms it.
- **Consume** at the single move-completion funnel `end_move_copy_logged` (callback.c): if the
  gesture actually **moved** (`!nothing`), `drag_sel_restore_now()` clears everything and
  re-selects the snapshot by id (so a click keeps its normal select, and copy — which keeps the
  new object selected — is excluded). Restore-by-id survives the array renumbering a fluid
  reroute causes; a snapshot object that no longer exists is silently dropped.
- Leaked snapshots are wiped at every press-start and at the shape-point-edit tail.

New state on `Xschem_ctx`: `drag_sel_restore` + `drag_sel_id/type/col/n` (calloc-zeroed; freed
each gesture). Whole-object moves (instance / wire body / text) are covered; the fluid
shape-point (vertex/edge) grab keeps its precise-edit selection.

## Verification
- tests/headless/test_drag_keeps_selection.tcl — 6/6 (drag-unselected→deselected+moved,
  click→selected, keep-prior-selection, drag-selected→stays+moved).
- No regression: wireedit ALL PASS; test_fluid_editing 26/26; test_cadence_drag's selection
  checks (plain-click-selects, no-motion-click-stays, click-to-isolate) all pass (its 2 fails are
  the pre-existing wire-detach ones, identical before/after). Golden suite drives no callback
  gestures → unaffected.
- valgrind: the deferred-selection path adds **zero** leaks — a load-only baseline shows the
  identical 5 pre-existing cairo/resetwin teardown blocks (4,728 bytes).

## Scope / notes
- Naturally scoped to the intuitive/cadence interface (where drag-to-move exists); non-intuitive
  gestures and stock non-cadence defaults are untouched (spec §6). No new user toggle.
- Not covered (deliberate): a shape-point vertex/edge grab keeps the grabbed shape selected (a
  distinct precise-edit gesture); Ctrl-detach / Shift-copy keep their own semantics.
