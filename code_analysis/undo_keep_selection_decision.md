# Issue 0007 — keep selection across undo/redo: plan + decisions

**Status:** RESOLVED 2026-06-15 — RED `75d2472e` / GREEN `01a22b39`. Approach =
**index + count-guard, at the call site** (`pop_undo_keep_selection` in select.c,
wrapping the two scheduler undo/redo sites). Test `tests/headless/test_undo_selection.tcl`
20/20 on **both** backends; sabotage-verified; core regression clean. Fully headless
(no eyeball needed). NOTE: branch is off master, which needed `./configure` to
regenerate the (feature-branch-stale) `src/Makefile` before building.
**Branch:** `fix/0007-undo-keep-selection` (off `master`).
**Issue:** `issues/0007-undo-deselects-objects-after-property-edit.md`.

---

## 1. Problem (verified on master)

Any `xschem undo`/`redo` that actually restores a slot comes back with the
previous selection **dropped**: both backends call `unselect_all(1)` during the
restore — `mem_pop_undo` (`in_memory_undo.c:422`) and `pop_undo`
(`save.c:3889`) — and selection is **not** part of the undo snapshot. The "just
selected, no edit" case is untouched only because undo early-returns before the
restore when there is nothing to undo. So: editing a selected object then undoing
reverts the edit **and** silently deselects the object.

## 2. The correction to the issue's fix sketch (important)

The issue proposes "re-select by **stable id**, cheap thanks to
[[stable-object-handles]]." **That does not work for the default backend.**

- `undo_type` defaults to **`disk`** (`xschem.tcl:12071`).
- On-disk `pop_undo` restores by **reloading the slot file**, and the load funnel
  **re-mints** stable ids (the stable-handles work deliberately chose
  *invalidate-on-restore* for disk undo). So a snapshot id will not resolve after
  a disk undo → selection stays dropped.
- Stable ids survive only the **in-memory** backend.

So an id-based fix would silently do nothing for most users. **A uniform fix must
key off something that survives a disk reload.**

## 3. What survives both backends: array position

A property/geometry edit (the issue's case) does **not** change object count or
order. Therefore the restored object sits at the **same array index** in both
backends:
- disk: file order == reload order == array order;
- memory: the slot is a struct-copy in order.

So **`(type, layer, index)` is a stable referent across the restore for any
non-structural edit** — and needs zero stable-handles machinery (works on master
as-is).

The only risk is a restore that changes the population (undo of a create/delete)
or reorders (the rare explicit "change element order"): then an index may be out
of range or point at a different object. Guard with a **population check**: only
re-apply the selection if every object count is unchanged across the restore.
Structural undos then skip re-selection (selection drops — the prior behaviour,
which the issue marks acceptable for those edges).

## 4. Decisions (ratified)

| # | Decision | Choice |
|---|---|---|
| Identity | id vs index vs hybrid | **Index `(type,layer,index)` + count-guard.** Uniform across disk+memory; works on the default backend; no id dependency. (id-only rejected per §2; hybrid rejected as over-built for a low-severity issue.) |
| D1 | Where it lives | **Call-site helper**, not inside the two backend functions. One implementation, backend-agnostic, leaves the delicate restore internals untouched, and affects only the user-facing `xschem undo`/`redo` (internal `redo==2/4` calls from netlisting are left alone). |
| D2 | Redo too | **Yes** — same helper wraps `pop_undo(1,…)`; redo runs the same restore path. |
| D4 | Created/deleted/reordered | **Count-guard skips them** (population changed ⇒ don't re-select). Undo-of-create → object gone (correct); undo-of-delete → reappears unselected (acceptable per issue); reorder-undo (same count) → may re-select the object now at that index (documented minor limitation). |
| Partial sel | stretch endpoints (`SELECTED1`) | Re-select as full `SELECTED` (v1). Faithful enough; note it. |

## 5. Design

A new helper (in `select.c`, near the other selection code):

```c
/* Run an undo/redo restore while preserving the current selection by array
 * position. Backend-agnostic: a non-structural edit keeps object order, so the
 * restored objects sit at the same indices. If the object population changes
 * (structural undo) the selection is dropped, as before. */
void pop_undo_keep_selection(int redo, int set_modify)
{
  /* 1. snapshot the live selection as (type,col,idx) + a population fingerprint */
  rebuild_selected_array();
  int nsel = xctx->lastsel, i, c;
  /* small malloc of {type,col,idx} triples from xctx->sel_array[0..nsel) */
  /* counts before: instances, wires, texts, and per-layer rects/lines/polygons/arcs */

  /* 2. the actual restore (clears selection + reloads the model) */
  xctx->pop_undo(redo, set_modify);

  /* 3. re-apply iff population unchanged */
  if(nsel > 0 && counts_unchanged) {
    for(i = 0; i < nsel; i++) {
      switch(snap[i].type) {
        case ELEMENT: if(idx in range) select_element(snap[i].idx, SELECTED, 1, 1); break;
        case WIRE:    select_wire(...);   break;
        case xTEXT:   select_text(...);   break;
        case xRECT:   select_box(col,...);    break;
        case LINE:    select_line(col,...);   break;
        case POLYGON: select_polygon(col,...);break;
        case ARC:     select_arc(col,...);    break;
      }
    }
    rebuild_selected_array();
  }
  /* free snap */
}
```

Then route the two **user-facing** call sites through it:
- `scheduler.c:6552` `xschem undo` — `pop_undo_keep_selection(redo, set_modify)`
- `scheduler.c:4761` `xschem redo` — `pop_undo_keep_selection(1, 1)`

`select_*(idx, SELECTED, fast=1, override_lock=1)` — `fast=1` defers drawing (the
caller's redraw paints it); `override_lock=1` faithfully restores objects that
were selected (they were selectable a moment ago). `rebuild_selected_array()`
rebuilds `sel_array` from the `.sel` flags. No change to what undo restores in the
object model — this is purely additive selection preservation.

Notes:
- Snapshot is taken **before** `pop_undo`, while the selection is still live; the
  early-return-on-nothing-to-undo path inside `pop_undo` leaves the model (and
  thus counts) unchanged, so the guard passes and re-apply is a harmless no-op →
  the "nothing to undo → selection untouched" behaviour is preserved.
- `prep_*` hash flags etc. are handled by `pop_undo` itself; `select_*` + `rebuild`
  only touch `.sel`/`sel_array`.

## 6. Test plan (RED-first, headless on master)

New `tests/headless/test_undo_selection.tcl` (gesture-test idiom: `puts ok:/FAIL:`,
`RESULT: ALL PASS`, run with `--pipe`). Master introspection confirmed available:
`xschem get lastsel`, `xschem selected_set`, `xschem select`, and undoable edits
`xschem setprop` / `move_objects` / `translate`.

- **US1 (core):** place an instance, `xschem select instance 0`, make an undoable
  property edit (`xschem setprop …`, verify it pushed undo), `xschem undo` →
  assert `lastsel == 1` and `selected_set` still names that object. (RED today:
  lastsel becomes 0.)
- **US2 (redo):** after US1, `xschem redo` → still selected.
- **US3 (no-op undo preserved):** select with no edit, `xschem undo` → selection
  untouched (lastsel unchanged). (Already passes; guards against regression.)
- **US4 (multi-select):** select two objects, edit one, undo → both still
  selected.
- **US5 (structural undo skips cleanly):** create an object (undoable), undo its
  creation → no crash, no spurious selection (object gone). Optional: undo a
  delete → no crash (selection may be empty; documents the edge).
- **US6 (both backends):** run US1 under `undo_type=memory` *and* `disk` — the fix
  must hold for both (this is the whole point of choosing index over id).

Sabotage check: force the count-guard always-false → US1/US2/US4 redden; force it
always-true and corrupt an index → bounds guard prevents a crash.

## 7. Recipe / next steps

Characterize (done) → this decision doc (done, ratified) → **RED-first**
(`test_undo_selection.tcl`, watch US1/US2/US4 fail) → implement
`pop_undo_keep_selection` + route the 2 call sites → GREEN under **both** backends
→ run core regression → update issue 0007 to RESOLVED. Self-contained; no
dependency on the stable-handles branches.
