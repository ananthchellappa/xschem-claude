# 0464 — what the S9 overlay cache epoch still cannot observe

- **status**: OPEN, known limits of the S9 cache. ⚠ **The list below was WRONG BY OMISSION**:
  a schematic RELOAD is a fourteenth thing the epoch cannot observe, it IS reachable from a
  toolbar button, and it reverted the step — issue **0466**.
> ⚠ **THE CODE THIS ISSUE DESCRIBES IS NOT IN THE TREE.** Step S9 (attempt 1) was
> implemented in full, went green on 192 headless / 195 display checks and nine
> sabotage variants, and was then **REVERTED** because its cache renders the
> previous file's numbers after a schematic reload — issue **0466**, invariant I3.
> The implementation is preserved as `doc/claude/issues/0466-attempt-1-reverted.patch`.
> Everything below was measured against that patch and is binding on the retry.
- **found**: S9 (the draw-time overlay)
- **subject**: src/actions.c `annot_overlay_sync()` / `annot_overlay_flush()` /
  `annot_data_changed()`, src/op_annot.tcl `::op_annot::gen`

## What

S9 caches one rendered block per instance, because an uncached sweep costs +20..35 % of a
frame with the annotation gate closed and +66..100 % with a raw loaded (measured; see the S9
report). The cache is flushed wholesale when an **observed-state epoch** moves:

    xctx pointer · instances · currsch · str_hash(sch[currsch]) · annot_show · modify_seq ·
    xctx->raw pointer · raw->level · raw->nvars · raw->annot_p · annot_data_seq · ::op_annot::gen

`annot_data_seq` is bumped explicitly by `update_op()` (save.c) and
`backannotate_at_cursor_b_pos()` (callback.c) because re-running the *same* deck republishes
into the *same* `Raw` allocation with identical `nvars`/`level` and `annot_p` 0 → 0, so
nothing observable moves. `::op_annot::gen` is bumped by `op_annot::register` and is what
makes invariant I5 ("a user's register takes effect on redraw, no restart") true.

## The residuals

1. **A descriptor mutated in place, without `register`.** `op_annot::register` is the only
   writer that bumps `gen`. Poking `::op_annot::desc(<type>)` directly — undocumented, but a
   plain Tcl array — leaves the cache stale until something else moves the epoch. The
   documented round trip (`descriptor` → `dict set` → `register`) is unaffected.
2. **A user `devproc` that depends on state outside the epoch.** The device path is whatever
   the descriptor's `devproc` returns; if it reads a Tcl variable, an environment variable or
   a file, changing that changes the block with nothing for the epoch to see.
3. **An extra raw database selected without republishing.** Every path that calls
   `update_op()` is covered. A future switch that changes which database the display reads
   *without* going through `update_op()` would not be.
4. **The last epoch's array is not freed at process teardown.** `annot_overlay_flush()` runs
   on every epoch change and when `xctx` is NULL, so the steady-state footprint is one
   `char *` per instance plus the live blocks; nothing frees the final one at exit. Same
   shape as the `xText.floater_ptr` cache it is modelled on.

None of these is reachable from the menus, the keys or the documented API. They are recorded
so the next person to widen the feature knows exactly where the cache stops looking.
