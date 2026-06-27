# Phase 3d.2 — sem-gated batch 1 (first idle_only command-key migration)

**Status:** DONE (commit `ac558252`). **Branch:** `feature/action-registry`.
**Predecessors:** d1 (Tcl-backed actions), d1b (the `idle_only` gate, commit
`c806149d`), d2 batches 1-3. See `tutorial_action_registry_phase3d.md` and
`plan_phase3d1b_idle_only.md`.

## Goal

The first batch that uses the d1b `idle_only` gate to **fully migrate** semaphore-gated
command keys out of the switch. Each chord's branch is `if(sem>=2)break; <behavior>`;
migrating it = add an `idle_only` canvas row → the behavior's action, and delete the
case/branch. At `sem>=2` the dispatch skips the chord (→ switch → no case / its own
`if(sem>=2)break`), reproducing the old no-op exactly.

## The four chords (all Tcl-backed, reusing verified-identical `actions.csv` ids)

| Key (keysym) | Chord | Switch behavior | id (reused) | tcl command | Case fate |
|---|---|---|---|---|---|
| `n` (110) | plain `rstate==0` | `tcleval("xschem netlist -erc")` | `toolbar.netlist` | `xschem netlist -erc` | **whole delete** |
| `n` (110) | `Ctrl` | `tcleval("xschem clear schematic")` | `file.clear_schematic` | `xschem clear schematic` | (part of whole delete) |
| `U` (85) | plain `rstate==0` | `pop_undo(1,1); draw()` | `edit.redo` | `xschem redo; xschem redraw` | **whole delete** (single branch) |
| `u` (117) | plain `rstate==0` | `pop_undo(0,1); draw()` | `edit.undo` | `xschem undo; xschem redraw` | branch only (case stays) |

### Why these reuse-as-Tcl is behavior-exact (verified against scheduler.c)

- `n` plain/Ctrl: the switch *already* calls `tcleval("xschem netlist -erc")` /
  `tcleval("xschem clear schematic")` — the Tcl-backed action runs the identical
  string. Byte-for-byte the same path.
- `U` (`edit.redo` = `xschem redo; xschem redraw`): `xschem redo` → `pop_undo(1,1)`
  (scheduler.c:4779), `xschem redraw` → `draw()` (4788). Switch = `pop_undo(1,1);
  draw()`. Identical.
- `u` (`edit.undo` = `xschem undo; xschem redraw`): `xschem undo` (no args) → redo=0,
  set_modify=1 → `pop_undo(0,1)` (6585); `+ redraw` → `draw()`. Switch = `pop_undo(0,1);
  draw()`. Identical.

`u` keeps its `case` because the **Alt** branch (align-to-grid, uses `c_snap` +
`push_undo`/`round_schematic_to_grid` — not idle_only-trivial) and the **Ctrl** branch
(`unselect_attached_floaters`, *not* sem-gated) stay in C. Only the plain branch is
deleted (like batch-2 `g`/`T`/`O`).

All four are **canvas-only** (no `waves_selected` guard in these cases) → `idle_only`
**canvas** rows, no `over_graph` rows.

## Deferred (not this batch), with reasons

- **`e`** (descend / go_back): `xschem descend` = `descend_schematic(0,0,0,1)` but the
  switch calls `descend_schematic(0,1,1,1)` (params differ); `xschem go_back` also adds
  an internal `semaphore==0` check the C `go_back(1)` lacks (differs at `sem==1`). Needs
  a C-act + its own analysis — defer (the Z/`view.zoom_in` family of "Tcl menu ≠ key C").
- **`&`,`>`,`<`,`?`,`/`,`*`** symbol keys: all *unconditional* (no mod guard) → a
  whole-case-delete changes behavior for modified presses (the `%`/`_` caveat). Additive
  migration only; lower value; later.
- **`q` quit / `o` load**: manipulate the semaphore directly (`semaphore=0`, save/restore)
  — not plain idle_only; later.

## Concrete steps

1. Add 4 Tcl-backed registry rows reusing the csv ids (`toolbar.netlist`,
   `file.clear_schematic`, `edit.redo`, `edit.undo`), `fn=NULL`, `tcl=<command>`.
2. Seed 4 `idle_only` canvas rows in `init_input_bindings`:
   `set_input_binding_idle(DEV_KEY, 'n', 0, ACTX_CANVAS, "toolbar.netlist")` etc.
3. Whole-delete `case 'n'` and `case 'U'`; delete the plain `rstate==0` branch from
   `case 'u'` (keep Alt/Ctrl + the `break;`).
4. Build (C89, no warnings).

## Testing (extend `tests/headless/test_key_graph_context.tcl`)

- **Data:** the 4 rows present **with the ` idle` marker** and **canvas-only** (no graph
  row), e.g. `{key 110 0 canvas toolbar.netlist idle}`, `{key 110 ctrl canvas
  file.clear_schematic idle}`, `{key 85 0 canvas edit.redo idle}`, `{key 117 0 canvas
  edit.undo idle}`.
- **The idle gate on a real key (undo/redo — safe & reversible):** make a small,
  reversible change to the fixture via `xschem`, then:
  - at `semaphore=2`, press `u` → the change is **not** undone (chord skipped);
  - at `semaphore=0`, press `u` → it **is** undone; press `U` → redone.
  Observe via an object count / modify flag (`xschem get …`). Reset semaphore to 0 after.
  (This is the d1b gate proven on a *migrated* key, not just the probe.)
- **`n` plain (netlist):** assert the row+idle and that it dispatches at `sem=0` without
  error. (ERC/netlist writes files; keep it light — row + no-error.)
- **`n` Ctrl (clear schematic):** `xschem clear schematic` pops a confirm dialog, so do
  **not** key-press it headless — assert the row + idle marker only.
- Re-run the full suite (engine `run.sh` 6/6, all GUI smokes). Narrow any older
  count/glob assertion the 4 new rows trip.

## Risks / watch-items

- **Reusing csv ids that resolve to multi-statement Tcl** (`edit.redo`/`edit.undo` run
  two `xschem` subcommands) — fine: `tcleval` runs the whole string, exactly as a menu
  invoke would. Verified equivalent above.
- **`clear schematic` dialog** — don't trigger in the test; and the migration preserves
  the dialog (the switch did the same `tcleval`).
- **`u` case kept** — confirm only the plain branch is removed; Alt align + Ctrl
  unselect-floaters stay byte-identical.
- **semaphore left high** wedges later checks — always reset to 0.

## Definition of done

- Builds clean; engine 6/6; all GUI smokes green.
- 4 idle_only canvas rows added; `case 'n'`/`case 'U'` whole-deleted; plain branch
  removed from `case 'u'`; actions reuse the verified-identical csv ids.
- Test proves the gate on `u`/`U` + rows-present-with-idle + canvas-only.
- Plan/tutorial/memory/next-prompt updated; commits split code vs docs.
