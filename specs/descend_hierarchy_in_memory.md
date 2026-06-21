# Spec: in-memory hierarchy so descend never saves/loses

Status: **DRAFT — awaiting sign-off before Phase 1.**
Branch context: `fluid-editing` (cadence-style editing work).

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

## Alternative considered (rejected)

*Silent disk auto-save on descend* — eliminates the prompt and loss with a
one-line change, but writes the user's file as a side effect of navigation,
which directly contradicts "descend is not a save point." Rejected.
