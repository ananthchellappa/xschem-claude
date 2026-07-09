# 0095 — Undo after a (topology-changing) move DROPS the selection

Status: **FIXED** (`pop_undo_keep_selection` rewritten id-keyed). Branch `fluid-editing`.
Test: `tests/headless/test_undo_move_keep_selection.tcl` (RED-first, sabotage-verified, headless).
Reported by user: "I select something, click-drag to move it, then Undo — the movement is
undone but the selection is lost too. Selection is not an edit operation; it should survive."

## Symptom

Select an instance, click-drag it (a fluid stretch that re-routes the attached wires), press
**undo** → the move reverts but the instance is no longer selected. On the memory undo backend
a sibling defect: undo re-*adds* a tool-owned follow-wire to the selection.

## Root cause

The issue-0007 helper `pop_undo_keep_selection()` (select.c) snapshotted the selected set by
**array position** `(type, layer, index)` and re-applied it after `xctx->pop_undo`, but ONLY when
**all seven per-type object counts were unchanged** — a single global fingerprint:

```c
if(nsel > 0 && b_inst==xctx->instances && b_wire==xctx->wires && ... ) { /* re-select by index */ }
```

That guard was written for *property/geometry* edits, whose object population never changes. But a
fluid drag-move **re-routes wires** (rip-up, exit-stub insert, trim/merge, kissing stubs), so the
post-move `xctx->wires` differs from the restored pre-move count. The guard goes FALSE and the
**entire** selection is dropped — including the moved instance, whose array is untouched and whose
identity is perfectly recoverable. Because the fingerprint ANDs all types, a change to the WIRE
count alone discards the INSTANCE selection collaterally.

Two distinct bad outcomes:
1. **guard fails → whole selection dropped** (the reported bug; disk & memory).
2. **guard passes by coincidence** (a count-neutral reroute: delete k + add k wires) → the wire
   array was re-ordered (new wires appended, deletes compact/swap), so index-based re-select picks
   the WRONG wires — a silent mis-selection.

Sibling **memory-backend** defect: the undo slot is serialized mid-gesture (push_undo runs after
`fluid_reroute_restore()` but while the follow-wires are still grabbed `SELECTED1/2`). `mem_restore_slot`
struct-copies those stale `.sel` flags back, so restoring the slot re-selects tool-owned wires. (The
disk backend is immune: a `.sch` slot file does not persist selection flags.)

## Why array-position was chosen originally, and why id is right NOW

Issue 0007 deliberately avoided stable ids because the default **disk** backend re-mints ids on
reload. That premise is **obsolete on this branch**: issue 0043 added the disk-undo id side channel
(`capture_undo_ids`/`restore_undo_ids`, save.c) that re-stamps the pre-move ids positionally after a
reload, and the memory backend preserves ids verbatim. So every object's session-stable `.id`
(xWire/xInstance/gfx/xText, stamped in store.c) now **survives `pop_undo` in both backends**.

## Fix

Rewrite `pop_undo_keep_selection()` (select.c) to re-select by **session-stable id**:

1. Before restore: snapshot each selected object's `(type, layer, index, id)`.
2. `xctx->pop_undo(redo, set_modify)`.
3. Normalize the restored selection to empty: force `rebuild_selected_array()` (mem restore leaves
   `lastsel==0` while stale `.sel` bits are set, so `unselect_all`'s `(SELECTION|lastsel)` guard would
   otherwise skip), then `unselect_all(0)`. Clears the memory stale-flag defect; no-op on disk.
4. Re-select by id via `inst_index_from_id` / `wire_index_from_id` / `text_index_from_id` /
   `gfx_index_from_id` (store.c). A moved instance keeps its id → re-found regardless of wire-count
   change; an id that no longer resolves (deleted, or re-stored fresh) is skipped. This kills both
   the drop and the coincidental-mis-select hazard.
5. **Fallback** (rare): if nothing resolved by id AND the population is unchanged, re-select by array
   position under the strict count guard — covers the disk `restore_undo_ids` bail on a per-type
   shape mismatch (save.c), which leaves fresh ids. Backend-agnostic (wraps the `xctx->pop_undo` fn ptr).

## Scope / non-goals

- **"Click-drag must not change the selected set"** (the user's companion request) already holds in
  the cadence/fluid config (`cadence_style_rc`: `fluid_editing=1`): the move END selection-normalize
  (issue 0091/0093, move.c) deselects tool-owned follow-wires and keeps the user's own set. Verified
  (test U1 "after move only the instance stays selected"; `test_wireedit_32` case A). Classic
  (`fluid_editing=0`) stretch deliberately leaves follow-wires selected — a tested, intentional
  default (`unselect_partial_sel_wires=0`, `test_wireedit_32` case B) — and is left unchanged.
- A user WIRE that the reroute deleted/merged (its id gone) cannot be re-selected after undo. Niche
  (issue 0093 territory); the moved instance — the reported case — always survives. A
  snapshot-at-move-START id capture (extending `fluid_startsel_id`) would close it; deferred.

## Test

`tests/headless/test_undo_move_keep_selection.tcl` (14 checks, headless via `move_objects` +
`undo`, asserts on the id-keyed `xschem selection` set):
- U1 disk, count-changing fluid stretch → after undo == the instance, exactly (RED: dropped).
- U2 memory, same → after undo == the instance (RED: extra stale follow-wire).
- U3 multi-instance selection survives move+undo.
- U4 plain move (no count change) regression guard.
- U5 property-edit undo (0007 core) still keeps selection + reverts the edit.

Sabotage-verified: reverting the fix reddens exactly U1(×2) + U2, leaving the 11 structural/precondition
checks green. Regression: `test_undo_selection` (0007) ALL PASS both backends (under X); full
`wireedit` suite ALL PASS.
