# Spec: descend never saves/loses edits

Branch context: `fluid-editing` (cadence-style editing work).

> ## ⚠ DESIGN PIVOT (2026-06-21) — backing file `cellName~.sch`, not an in-memory snapshot
>
> Steps 1–6 built an **in-memory** snapshot (`hier_slot[]`, reusing the undo
> serializer). On review we are switching to a **disk backing-file / autosave**
> design (the editor `~`-file convention, e.g. NEdit). It is simpler, reuses the
> tested save/load path, and gives crash recovery for free. The in-memory plan
> below is **superseded** by the "Backing-file design" and "Revised plan"
> sections that follow; it is kept for history and because several of its pieces
> are reused.
>
> ### Backing-file design
> - In memory stays the working copy (zoom/pan/edit), always.
> - A **genuine edit** (`set_modify(1)`, which excludes highlight/select/pan/zoom/
>   net-resolution — verified) **immediately writes** `cellName~.sch`
>   (`cellName~.sym` for symbols), next to the cell.
> - **Save** writes `cellName.sch` and deletes `cellName~.sch`.
> - The `~` file exists only while the buffer is dirty (first edit creates it).
> - **go_back** loads `cellName~.sch` if present (logical name stays `cellName`,
>   `modified=1`), else the clean `cellName.sch`. No snapshot, no `hier_slot[]`.
> - **Highlight is not an edit** → no `set_modify` → no write (verified: no
>   set_modify in hilight.c/findnet.c/node_hash.c; load/select/hilight leave
>   modified=0).
> - Bonus: `~` is a crash-recovery artifact for any dirty cell, not just descend.
>
> ### Considerations / decisions
> - Write **immediately** per edit, but behind one `write_backup()` function so an
>   idle-debounce can be added later if large flat schematics hitch.
> - Gate with `autosave_backup` (default on) and skip buffers with no real on-disk
>   name (untitled / headless tests) so tests don't spray `~` files.
> - Hide `*~.sch` / `*~.sym` from the file-open dialog, library browser, and any
>   directory scans. (Symbol→schematic resolution already only looks for
>   `cellName.sch`, never `cellName~`.)
>
> ### Revised plan (RED-first; acceptance tests S1/S2 unchanged, mechanism-agnostic)
> Keep: Part-1 fix, the mem_serialize/restore refactor (still used by undo), the
> acceptance + fidelity tests, the tutorial.
> | Step | Change | Gate |
> |---|---|---|
> | **B1** | `backup_file_name()` + `write_backup()` / `remove_backup()` (reuse save_schematic); `autosave_backup` flag; skip unnamed buffers | unit tcl test: edit → `cellName~.sch` appears with current content |
> | **B2** | Hook into the edit funnel: `set_modify(1)` → write_backup; `set_modify(0/2)` → remove_backup. Verify highlight/select/load do NOT write | edit writes `~`; highlight/save/load do not; modified semantics intact |
> | **B3** | go_back loads `cellName~.sch` when present (identity = `cellName`, modified=1); remove the in-memory overlay + descend snapshot | **S1 GREEN** via the `~` file; fidelity GREEN |
> | **B4** | Remove dead in-memory machinery: `hier_slot[]`, snapshot/restore_hier, `descend_keep_in_memory`, `get hier_slots`; replace `test_descend_efficiency.tcl` with a `~`-file behavior test | suites green; no dead code |
> | **B5** | Remove the descend save prompt (old Step 7) — now trivially safe (edits always autosaved) | **S2 GREEN** |
> | **B6** | Symbols: `cellName~.sym` for edited symbols; descend-into-symbol path | symbol-edit round trip preserved |
> | **B7** | Hide `~` files in file dialog / library browser / dir scans | `~` files not listed as cells |
> | **B8** | Lifecycle + recovery: clean `~` on save/close; on open, detect a stale `~` and offer recovery (may be deferred) | stale-`~` handling test |
> | **B9** | Tabs, deep hierarchy, leak/edge audit; GUI eyeball | suites green; manual pass |
>
> The original in-memory spec follows unchanged for reference.

---

## (SUPERSEDED) Original in-memory spec

## Problem

Two defects, one reported and one structural, both around descending into a
sub-schematic.

1. **Spurious "save?" prompt on a freshly-opened file.** (FIXED, see below.)
   In `cadence_compat` mode a Tcl trace auto-enables `autotrim_wires`
   (`xschem.tcl:12454`). `load_schematic()` then runs `trim_wires()` on load
   (`save.c:3711`), which rewrites redundant wires and calls `set_modify(1)`
   (`check.c:380`). So a just-opened, user-untouched schematic is flagged
   modified; the first context-menu descend (`descend_schematic()` →
   `if(xctx->modified) save(1,0)` → `ask_save`, `actions.c:2562`) then asks to
   save. Reproduced: `test_lm324.sch`, `modified=1` immediately after
   `load_new_window` in cadence mode, `0` in plain mode.

2. **Descend is treated as a save point; without saving it silently loses
   parent edits.** This is the structural issue this spec addresses.

### Why descend currently must save

`descend_schematic()` (`actions.c:2682`) calls `load_schematic(child)`, which
**overwrites the parent's drawing arrays in the single `xctx`**. `go_back()`
(`actions.c:2766`) then **reloads the parent from disk**. Only per-level
*metadata* is stacked (`sch[]`, `sch_path[]`, `zoom_array[]`, `hier_attr[]`,
`portmap[]`, `previous_instance[]`, `sch_inst_number[]`, `sch_path_hash[]` —
all `[CADMAXHIER]` fields in `Xschem_ctx`), **not** the geometry. So any unsaved
parent edit is gone after a round trip.

Proven empirically: load `test_lm324.sch`, add a wire to the parent
(`wires 11→12`, `modified=1`), descend into `x1`, decline the save, `go_back`
→ parent back to **11 wires**. The added wire is silently lost. The save-prompt
is the *only* current guard against this.

### Desired behavior (user's model)

> Descending is not discarding — one will return. The alert belongs only where
> changes are actually at risk: closing the window (discarding top-level edits),
> or returning *up* after editing a lower level.

So: **descend should never prompt and never lose data**; prompts happen at
window-close and at `go_back` (already present, `actions.c:2726`).

## Part 1 — spurious-flag fix (DONE)

`load_schematic()` snapshots `xctx->modified` before load-time normalization
(`check_collapsing_objects()` + `trim_wires()`) and restores the clean state if
that normalization was the only dirtier (`save.c`, ~3710):

```c
int mod_before_norm = xctx->modified;
check_collapsing_objects();
if(reset_undo && tclgetboolvar("autotrim_wires")) trim_wires();
if(reset_undo && !mod_before_norm && xctx->modified) set_modify(0);
```

Verified: clean load → `modified=0`, descend silent; genuine edit →
`modified=1`, existing prompt still fires (loss-guard intact until Part 2).
Regression: 3 core suites clean; wireedit 18/18.

This alone resolves the *reported* bug. Part 2 is needed to actually remove the
descend prompt safely.

## Part 2 — preserve the parent in memory

### Approach (chosen): per-level full-ctx pointer, reusing the tab swap model

The tabbed interface already preserves a complete schematic by swapping the
whole `Xschem_ctx *` pointer (`save_xctx[MAX_NEW_WINDOWS]`, `xinit.c:41`;
`switch_tab` does `xctx = save_xctx[n]`, `xinit.c:1655`). The object arrays,
counts, spatial hashes, netlist/hilight tables, undo slots and the whole
hierarchy metadata all live inside `Xschem_ctx`, so one pointer carries them.

Reuse it for the hierarchy:

- Add `Xschem_ctx *hier_ctx[CADMAXHIER]` (a new per-level stack of saved ctxs),
  paralleling the existing `[CADMAXHIER]` metadata arrays.
- **descend:** `hier_ctx[currsch] = xctx;` then `alloc_xschem_data(<same
  win/top path>)` for a fresh ctx and load the child into it. The parent ctx —
  geometry, modified flag, hilights, undo — stays alive, untouched, in
  `hier_ctx[currsch]`.
- **go_back:** instead of `load_schematic(parent-from-disk)`, free the child
  ctx (`delete_schematic_data`) and swap back: `xctx = hier_ctx[currsch]`.
  Unsaved parent edits are exactly as they were. No save needed → **remove the
  `if(xctx->modified) save(1,0)` block in `descend_schematic()`**.

This is strictly closer to the tab machinery than a bespoke "snapshot the
arrays" routine (none exists; the design is deliberately pointer-swap).

### Risk areas (must be handled in the phases)

1. **Window-bound fields must not diverge across levels of the same window.**
   A swapped-in ctx carries its own `window`, `save_pixmap`, GCs
   (`gc*`, `gctiled`), cairo surfaces, `top_path`, `current_win_path`,
   `areax1..areah`, color arrays. After the swap these must point at the *live*
   window's resources. The authoritative copy-list already exists:
   `compare_schematics()` / the window-context block at `xinit.c:827-858`
   (used when two ctxs share one window). Phase 1 factors that into a helper
   `adopt_window_ctx(dst, src)` and calls it after every hierarchy swap.

2. **Embedded symbols** (`.xschem_embedded_`, `go_back` `actions.c:2747`).
   Today the edited embedded symbol body is folded back into the parent's
   `sym[]` via `load_sym_def()` before the from-disk reload. With a memory
   restore the parent ctx already holds its own `sym[]`; the edited definition
   must be merged into *that* ctx's `sym[]` (keeping `inst[].ptr` consistent)
   before the swap. The `from_embedded_sym` modified-propagation
   (`actions.c:2770`) is preserved.

3. **Cross-level hilight** (`hilight_child_pins`, `hilight_parent_pins`,
   `propagate_hilights`). These step `currsch` up/down to read the adjacent
   level's `hilight_table`/`previous_instance[]`/`sch_inst_number[]`. With a
   single ctx per level the adjacent level now lives in a *different* ctx, so
   these must read the neighbour from `hier_ctx[currsch±1]` rather than from
   the same ctx's stacked arrays. **This is the deepest change** and needs its
   own phase + tests. (Fallback if it proves too invasive: keep the per-level
   metadata arrays mirrored in the active ctx so these functions keep working
   unchanged — evaluate in Phase 2.)

4. **Memory.** Up to `CADMAXHIER` (40) full ctxs alive on a deep descent. Tabs
   already hold a full ctx each, so per-level cost is comparable; deep chains
   are short in practice. Free promptly on `go_back`.

5. **Tab × hierarchy interaction.** `save_xctx[]` (tabs) and `hier_ctx[]`
   (levels) are orthogonal stacks; switching tabs must save/restore the
   *current level's* ctx and its `hier_ctx[]` spine together. Audit
   `switch_tab`/`switch_window`.

### Phasing

- **Phase 0** — this spec; sign-off. ← we are here
- **Phase 1** — `hier_ctx[]` + `adopt_window_ctx()` helper; descend stashes,
  go_back swaps back (from-disk reload retained as fallback behind a flag for
  bisecting). No prompt removal yet. Validate geometry/zoom/undo survive a
  round trip with an unsaved parent edit.
- **Phase 2** — cross-level hilight via neighbour ctx (risk area 3), embedded
  symbol merge (risk area 2). Headless hilight/descend tests.
- **Phase 3** — remove the `descend_schematic()` save block; confirm
  `go_back` + window-close remain the only prompts. Add the data-loss
  regression (edit parent → descend → go_back → edit survives) as a permanent
  headless test.
- **Phase 4** — tab×hierarchy audit (risk area 5); soak.

### Testing

- New headless test `test_descend_preserve.tcl`: the proven loss scenario must
  now *keep* the wire across descend/go_back with no save and no prompt.
- Re-run regression (create_save/open_close/netlisting) + wireedit each phase.
- Eyeball in real GUI (`src/xschem --script src/cadence_style_rc`): descend via
  context menu on a clean file (no prompt), and with an unsaved parent edit
  (no prompt, edit intact on return).

## Mechanism refinement (supersedes the pointer-swap sketch above)

During planning, the whole-`Xschem_ctx`-pointer swap was found to collide badly
with the `currsch`-indexed per-level metadata arrays (`sch[]`, `sch_path[]`,
`zoom_array[]`, `hier_attr[]`, …) and the cross-level hilight functions
(`hilight_child_pins`/`hilight_parent_pins`), which all assume a *single* ctx
holding every level's metadata. A per-level ctx would split that metadata across
ctxs and force a deep rewrite of the hilight traversal.

**Better basis: reuse the in-memory undo serializer.** `mem_push_undo()` /
`mem_pop_undo()` (`in_memory_undo.c:263,394`) already deep-copy the *entire*
schematic drawing state — wires, instances, symbols (via `copy_symbol`), texts,
rects/lines/polys/arcs and all `prop_ptr`s — into an `Undo_slot`
(`xschem.h:723`, array `uslot[MAX_UNDO]` at 1168), and restore it. This is
exactly the parent-snapshot we need, already tested and maintained.

Refined mechanism (keeps ONE ctx; metadata/hilight machinery untouched):

- Factor the serialize/restore bodies of `mem_push_undo`/`mem_pop_undo` into
  `mem_serialize_slot(Undo_slot *s)` / `mem_restore_slot(Undo_slot *s, …)`.
- Add a per-level snapshot store `Undo_slot hier_slot[CADMAXHIER]` (+ a
  `hier_slot_valid[CADMAXHIER]` flag) to `Xschem_ctx`.
- **descend:** before `clear_drawing()`/loading the child, snapshot the parent
  into `hier_slot[currsch]`.
- **go_back:** when a valid snapshot exists for the level, restore the parent
  from `hier_slot[currsch]` (then set `current_name`/`current_dirname` from the
  preserved `sch[currsch]`, invalidate `prep_*`, keep the existing
  `hilight_parent_pins`/`propagate_hilights`/zoom restore) **instead of**
  `load_schematic()`-from-disk. Free the slot.
- Then the `if(xctx->modified) save(1,0)` block in `descend_schematic()` is
  removed: the parent is preserved in memory, so descend never needs to save.

This is independent of which undo backend (memory/disk) is active — the
hierarchy snapshot always uses the in-memory serializer and its own
`hier_slot[]` store, so it never clobbers the user's undo history.

## RED-first implementation plan (atomic steps)

Acceptance test `tests/headless/test_descend_preserve.tcl`, two scenarios:
- **S1 (no data loss):** load → add a parent wire (`modified=1`) →
  `ask_save` stubbed to return "no" → descend → `go_back` → assert parent wire
  count restored and `modified` still 1 (unsaved-but-present). RED today
  (wire lost). → GREEN at Step 5.
- **S2 (no prompt):** descend on a modified parent → assert `ask_save` was
  **not** called. RED until Step 7.

| Step | Change | Test gate |
|---|---|---|
| **1** | Write `test_descend_preserve.tcl` (S1) and run it — confirm it **FAILS** on the current build (wire lost). | S1 RED (expected) |
| **2** | Refactor: extract `mem_serialize_slot(Undo_slot*)` from `mem_push_undo`; call it there. No behavior change. | build + undo test (`wireedit_14`) GREEN |
| **3** | Refactor: extract `mem_restore_slot(Undo_slot*, …)` from `mem_pop_undo`; call it there. No behavior change. | build + undo test GREEN |
| **4** | Add `hier_slot[CADMAXHIER]` + `hier_slot_valid[]` to `Xschem_ctx`; init in `alloc_xschem_data`, free in `clear_drawing`/`delete_schematic_data`. Unused. | build + full suite GREEN |
| **5** | descend snapshots parent into `hier_slot[currsch]` before loading child; `go_back` restores from it (incl. `current_name`/zoom/prep-invalidate) instead of disk reload, behind flag `descend_keep_in_memory` (default on). **Keep** the descend save block for now. | **S1 GREEN**; full suite + wireedit + netlisting GREEN |
| **6** | Validate restore fidelity: add asserts to S1 for zoom, netlist output, and hilight after `go_back` (compare to a disk-reload baseline). | extended S1 GREEN |
| **7** | Remove the `if(xctx->modified) save(1,0)` block in `descend_schematic`. Add S2 assertion. | **S2 GREEN**; suite GREEN |
| **8** | Embedded-symbol path (`.xschem_embedded_`): confirm snapshot preserves the edited `sym[]`; drop/adjust now-redundant temp-reload logic in `go_back`. | new `test_descend_embedded` GREEN |
| **9** | Tab interaction: descend in a tab, switch away/back, `go_back` — state intact (`hier_slot[]` rides with the per-tab ctx). Audit `switch_tab`. | new `test_descend_tab` GREEN |
| **10** | Deep multi-level descend + memory freed on each `go_back`; leak check (`xschemtest -d 3`). Audit `clear_schematic`/load-new-file frees `hier_slot[]`. | leak log clean; suite GREEN |
| **11** | GUI eyeball (`src/xschem --script src/cadence_style_rc`): context-descend on clean file (no prompt) and on edited parent (no prompt, edit intact on return); close-with-unsaved still prompts. | manual pass |

Each step keeps the build compiling and every previously-green test green; RED
steps (1, and the S2 add in 7) are written before the implementing change.

## Alternative considered (rejected)

*Silent disk auto-save on descend* — eliminates the prompt and loss with a
one-line change, but writes the user's file as a side effect of navigation,
which directly contradicts "descend is not a save point." Rejected.
