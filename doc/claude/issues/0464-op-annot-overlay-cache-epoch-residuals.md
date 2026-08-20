# 0464 — what the S9 overlay cache epoch still cannot observe

- **status**: OPEN (narrowed by S9b, 2026-08-20). ⚠ **The list below was WRONG BY OMISSION**:
  a schematic RELOAD is a fourteenth thing the epoch cannot observe, it IS reachable from a
  toolbar button, and it reverted the step — issue **0466**.
> ✅ **THE CODE IS NOW IN THE TREE** (S9b, 2026-08-20). The retry re-landed attempt 1's
> src/ half unchanged and replaced its invalidation with four hooks (`clear_drawing`,
> `set_modify`'s floater block, `remove_symbols`, the four raw mutators), a 14th epoch
> term (`live_cursor2_backannotate`), a hold around `prepare_netlist_structs`, and a second
> seam `xschem get annot_overlay_flushes`. **Residuals 1, 2 and 4 below survive verbatim;
> residual 3 is CLOSED and residual 5 (new) is added.** Full record in issue 0466 § S9b.
>
> Historical note, kept because it dates the residual list:
> ⚠ **THE CODE THIS ISSUE DESCRIBES WAS NOT IN THE TREE** when this issue was written. Step S9 (attempt 1) was
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


---

## S9b update (2026-08-20) — what moved

**Residual 3 is CLOSED.** "An extra raw database selected without republishing"
is now covered three ways: the four in-place raw mutators (`raw_add_vector`,
`raw_renamevar`, `raw_deletevar`, the `xschem raw set` arm) each bump
explicitly, and rows **O30** and **O37** guard them. Sabotage variant
`raw_mutator_flush_off` reds exactly O30, so the hooks are load-bearing.

**Residuals 1, 2 and 4 survive verbatim.** Residual 1 was re-measured by the S9b
adversary and reproduces: poking `::op_annot::desc(<type>)` directly left
`op_annot::text` answering `VQ = 10u` while the export still drew `VZ = 10u`.

**Residual 2 (the re-entrancy segfault) is NARROWED, NOT CLOSED.** S9b adds
`if(annot_overlay_busy) return;` at the top of `annot_overlay_sync()` — decision
D8, ladder rung L2 — because the busy flag guarded `get_annot_overlay()` but not
the function that **frees** the cache. A full deferred-flush redesign was rejected
as larger than the step. ⚠ **The crash is still reachable and its blast radius
GREW**: S9b takes the trigger from "a symbol the user placed a carrier on" to
"every registered device on every sheet with the mask on". The S9b adversary built
the apples-to-apples control and confirmed the hazard is **pre-existing** — an
ordinary symbol whose own `T` record is `tcleval([reproc @ref])`, with
`annot_show=0` and nothing registered, crashes identically — so this is not an
S9b regression. **Do not close this issue on the strength of S9b.**

**A fifth residual, new with S9b: over-invalidation is unmeasured.** Flushes run
well ahead of user actions (13 flushes across 5 exports plus 4 navigations was
observed) because a `reload` bumps through both `remove_symbols` and
`clear_drawing`, and the netlisters bump per sub-sheet. Correctness-safe, and the
`annot_overlay_flushes` goldens only pin **single wrapped actions** — so a future
hook that doubles the flush rate on a common path would cost frames without
reddening anything.

**A sixth, on the OTHER dangling-pointer residual (`annot_epoch.ctx`, listed as
residual #3 in issue 0466 rather than here):** HOOK A sits in `clear_drawing()`,
which window/tab teardown calls (`xinit.c:962`), so the monotonic sequence has
moved by the time a recycled malloc address could alias. That ABA is retired.

**Related new issues from S9b**: **0469** (the overlay resolves a device by NAME,
so an all-digit or duplicated instance name renders another device's numbers —
the one adversary attack that succeeded), **0473** (the hold DROPS rather than
defers; `prepare_netlist_structs` still resets every floater cache mid-export),
**0474** (`annot_overlay_count` counts approved, not drawn).
