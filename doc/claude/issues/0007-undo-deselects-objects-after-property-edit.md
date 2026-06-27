# Issue 0007 — undo after a property edit silently deselects the object

**Opened:** 2026-06-14
**Status:** RESOLVED 2026-06-15 — fixed on `fix/0007-undo-keep-selection` (off
master) and propagated here (slick) + `feature/hover-highlight`. The fix keys off
**array position** (not stable id, as originally sketched): the default `disk`
backend re-mints ids on reload, so an id snapshot would not survive it. See
`doc/claude/code_analysis/undo_keep_selection_decision.md` and
`tests/headless/test_undo_selection.tcl` (20/20, both backends). Was: pre-existing,
general undo behaviour, not specific to the slick forms.
**Affects:** the selection after any `xschem undo` (key `u`, menu, or typed
`xschem undo; xschem redraw` in the CIW) that actually restores a slot — the
previously-selected object(s) come back **unselected**.
**Severity:** low (workflow annoyance; no data loss — the edit is correctly
undone, only the selection is dropped).
**Branch:** independent of any feature; suggest a small dedicated branch off
`master` when picked up.
**Related:** the stable-object-handles work ([[stable-object-handles]]) makes the
clean fix feasible — selection can be re-established by **stable id** after the
restore.

---

## 1. The symptom (reported)

1. Select an object (instance **or** text). It is highlighted.
2. Edit a property via the form and press **OK**. The object stays selected, as
   expected.
3. Press **`u`** (logged in the CIW as `xschem undo; xschem redraw`). The property
   change is correctly undone — **but the object is now no longer selected.**

Typing `xschem undo; xschem redraw` in the CIW after a property edit does the
same thing.

**The tell-tale asymmetry:** if an object is *just selected* with **no edit yet**,
then `xschem undo; xschem redraw` does **not** deselect it.

---

## 2. Root cause (verified — same in both undo backends)

Undo restores the entire object model from an undo slot and **unconditionally
clears the selection** as part of that restore:

- in-memory undo: `mem_pop_undo()` → `unselect_all(1)` at `in_memory_undo.c:422`
  (right after `clear_drawing()`, before the object arrays are freed and
  re-read from the slot).
- on-disk undo: `pop_undo()` → `unselect_all(1)` at `save.c:3880` (same shape).

Selection is **not part of the undo snapshot** (the saved slot is the object
model — wires/insts/rects/text/…; the per-object `.sel` flag and `sel_array` are
not persisted/restored). So a restore necessarily comes back with everything
deselected, and the code makes that explicit with `unselect_all`.

**Why "just selected, no edit" does NOT deselect:** when there is nothing to
undo, `pop_undo`/`mem_pop_undo` **return early before** reaching `unselect_all`:

```c
if(xctx->cur_undo_ptr == xctx->tail_undo_ptr) return;   /* nothing to undo */
```

(`in_memory_undo.c:406`, `save.c:3862`). Selecting an object does not push an undo
slot, so in that state undo is a no-op → the early return fires → the selection
is left untouched. After a property edit (which *did* `push_undo()`), undo has a
slot to restore → it runs the full restore path → `unselect_all` → the object
comes back deselected. Hence the asymmetry the reporter noticed.

So this is **general undo behaviour**, not a slick-form bug: any undo that
actually rolls back a change drops the selection.

---

## 3. Expected behaviour

After undoing a change to a still-present object, the object that was selected
before the undo should remain selected (the edit is reverted, the selection is
not). This matches the user's mental model: "undo my edit" ≠ "deselect".

> Edge cases the fix must define: undoing an object's **creation** (the object no
> longer exists after undo → nothing to reselect — fine); undoing a **deletion**
> (the object reappears → arguably should be reselected); a selection that spanned
> several objects (restore all that still exist).

---

## 4. Fix sketch (not yet implemented)

The clean fix is now cheap thanks to stable ids ([[stable-object-handles]] — all
7 drawable types carry a stable `id`):

1. **Before** the restore, snapshot the selected set as a list of **stable ids**
   (via the existing `xschem objects -selected` / per-type id enumerators), not
   array indices (indices are invalidated by the reload).
2. Do the restore as today (`clear_drawing` + reload + the existing
   `unselect_all`).
3. **After** the reload, re-select every snapshotted id that still resolves to a
   live object (`*_index_from_id`), then `rebuild_selected_array()`.

Decisions to settle first (short decision doc, per the project recipe):
- **D1 — where it lives:** inside `pop_undo`/`mem_pop_undo` (covers every undo
  route uniformly), vs. only around the property-edit apply (narrow). Prefer the
  former — the asymmetry is in the undo primitive, so fix it there once.
- **D2 — redo too:** redo (`redo==1`) runs the same restore path; apply the same
  save/restore so redo is symmetric.
- **D3 — snapshot timing for the head push:** `mem_pop_undo` may itself call
  `push_undo()` when at head (`:407`); make sure the id snapshot is taken from the
  live selection before any of that churns the arrays.
- **D4 — created/deleted objects:** ids that no longer resolve are simply skipped
  (covers undo-of-create); decide whether undo-of-delete should reselect the
  reappeared object (its id is restored from the slot, so it *can* be).

Verification is mostly headless-assertable now (unlike the geometry dialogs):
select by id → edit → undo → assert the id is selected again
(`xschem objects -selected` contains it); and the no-op-undo case still leaves a
fresh selection untouched.

---

## 5. Acceptance criteria

- After editing a property of a selected instance/text and undoing, the object
  remains selected (verified by stable id, headless).
- Redo keeps the selection consistent too.
- The existing "nothing to undo → selection untouched" behaviour is preserved.
- No change to what undo restores in the object model itself (this is purely a
  selection-preservation addition).
