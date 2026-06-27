# Phase 3d.2 — sem-gated batch 2 (the hilight cluster: `k`, `K`)

**Status:** DONE (commit `107c1524`). **Branch:** `feature/action-registry`.
**Predecessors:** d1b (`idle_only` gate, `c806149d`), sem-gated batch 1 (`n`/`U`/`u`,
`ac558252`). Same pattern as batch 1; see `plan_phase3d2_semgated_batch1.md` and
`tutorial_action_registry_phase3d.md`.

## Goal

Migrate the net-highlight command keys `k` and `K` out of the switch — both
**whole-case deletes** — using the d1b `idle_only` gate. All five chords map to
existing `actions.csv` Tcl commands **verified byte-identical** to the switch's C
calls, so the batch is all-Tcl-backed reusing those ids.

## The two keys, five chords

| Key (keysym) | Chord | Switch behavior | id (reused) | tcl command | idle_only |
|---|---|---|---|---|---|
| `k` (107) | plain `rstate==0` | `enable_drill=0; hilight_net(0); redraw_hilights(0)` | `hilight.highlight_selected_net_pins` | `xschem hilight` | **yes** |
| `k` (107) | `Ctrl` | `unhilight_net()` | `hilight.un_highlight_selected_net_pins` | `xschem unhilight` | **yes** |
| `k` (107) | `Alt` (`EQUAL_MODMASK`) | `select_hilight_net()` | `hilight.select_hilight_nets_pins` | `xschem select_hilight_net` | **no** (2 rows: Mod1, Mod4) |
| `K` (75) | plain `rstate==0` | `enable_drill=0; clear_all_hilights(); draw()` | `hilight.un_highlight_all_net_pins` | `xschem unhilight_all` | **yes** |
| `K` (75) | `Ctrl` | `enable_drill=1; hilight_net(0); redraw_hilights(0)` | `hilight.propagate_highlight_selected_net_pins` | `xschem hilight drill` | **yes** |

### Verified identical to the csv Tcl commands (vs `scheduler.c`)

- `xschem hilight` (2427) = `enable_drill=0; hilight_net(0); redraw_hilights(0)` → `k` plain. ✓
- `xschem hilight drill` (2428) = `enable_drill=1; hilight_net(0); redraw_hilights(0)` → `K` Ctrl. ✓
- `xschem unhilight` (6641) = `unhilight_net()` (no redraw, like the switch) → `k` Ctrl. ✓
- `xschem unhilight_all` (6629) = `enable_drill=0; clear_all_hilights(); draw()` → `K` plain. ✓
- `xschem select_hilight_net` (5367) = `select_hilight_net()` → `k` Alt. ✓

`hilight_net` operates on the **current selection** (`rebuild_selected_array()` +
`sel_array` scan, hilight.c:1924) — **not** the mouse — so these are clean to migrate
(an action can't read mouse coords).

### Whole-delete is exact

- `case 'k'` handled exactly `rstate ∈ {0, Mod1, Mod4, ControlMask}` (plain, EQUAL_MODMASK
  = `==Mod1 || ==Mod4`, Ctrl). The 4 rows (`k 0`, `k Mod1`, `k Mod4`, `k ctrl`) cover
  every chord → delete the whole case.
- `case 'K'` handled `rstate ∈ {0, ControlMask}`. The 2 rows cover both → delete whole.

Both are **canvas-only** (no `waves_selected` guard) → canvas rows, no over_graph.

### idle vs non-idle on the same key

`k` plain/Ctrl and `K` plain/Ctrl have `if(sem>=2)break;` → **idle_only** rows. `k` Alt
(`select_hilight_net`) has **no** sem guard → **non-idle** rows. So at `sem>=2`: `k`/`K`
idle chords are skipped (→ deleted case → nothing, as before), but Alt-`k` still fires
(its row isn't idle_only) — exactly the old behavior. Good demonstration that the gate
is per-chord.

## Concrete steps

1. Add 5 Tcl-backed registry rows reusing the csv ids (fn=NULL, tcl=`xschem …`).
2. Seed 6 binding rows in `init_input_bindings`:
   - `set_input_binding_idle(DEV_KEY, 'k', 0, ACTX_CANVAS, "hilight.highlight_selected_net_pins")`
   - `set_input_binding_idle(DEV_KEY, 'k', ControlMask, ACTX_CANVAS, "hilight.un_highlight_selected_net_pins")`
   - `set_input_binding(DEV_KEY, 'k', Mod1Mask, ACTX_CANVAS, "hilight.select_hilight_nets_pins")`  (non-idle)
   - `set_input_binding(DEV_KEY, 'k', Mod4Mask, ACTX_CANVAS, "hilight.select_hilight_nets_pins")`  (non-idle)
   - `set_input_binding_idle(DEV_KEY, 'K', 0, ACTX_CANVAS, "hilight.un_highlight_all_net_pins")`
   - `set_input_binding_idle(DEV_KEY, 'K', ControlMask, ACTX_CANVAS, "hilight.propagate_highlight_selected_net_pins")`
3. Whole-delete `case 'k'` and `case 'K'` (replace with a migration comment, no label).
4. Build (C89, no warnings).

## Testing (extend `tests/headless/test_key_graph_context.tcl`)

- **Data:** the 6 rows present; the 4 sem-gated ones carry ` idle`, the 2 Alt rows do
  **not**; all canvas-only (no graph row). e.g.
  `{key 107 0 canvas hilight.highlight_selected_net_pins idle}`,
  `{key 107 alt canvas hilight.select_hilight_nets_pins}` (no idle).
- **Idle gate on real keys (via `bbox_hilighted`):** `bbox_hilighted` = `-100 -100 100
  100` when nothing is hilighted, a real bbox otherwise.
  - `xschem unhilight_all; xschem select instance 0` (set up a selection).
  - at `semaphore=2`, `keyat … 107` (`k` hilight) → bbox still `-100 -100 100 100`
    (skipped); at `semaphore=0`, `keyat … 107` → bbox changes (fires).
  - `keyat … 75` (`K` clear, idle) → bbox back to `-100 -100 100 100`.
  - reset `semaphore 0`.
- Engine `run.sh` 6/6 + all GUI smokes. Narrow any older assertion the new rows trip.

## Deferred (not this batch)

- **`j`/`J`**: `j`'s 4th branch (`SET_MODMASK && state&ControlMask` → `print_hilight_net(3)`,
  not sem-gated) is a **family** (`SET_MODMASK` = any mods with Mod1 or Mod4) — exact
  rows can't cover it, so `j` can't whole-delete exactly. `J`'s sole guard is `SET_MODMASK`
  (family) too. Additive/branch later.
- **`Q`** (edit_property dialogs), **`q`/`o`** (manipulate semaphore directly).

## Definition of done

- Builds clean; engine 6/6; all GUI smokes green.
- 6 rows added (4 idle, 2 non-idle); `case 'k'`/`case 'K'` whole-deleted; actions reuse
  the verified-identical csv ids.
- Test proves the gate on `k`/`K` via `bbox_hilighted` + rows-present-with-correct-idle +
  canvas-only.
- Plan/tutorial/memory/next-prompt updated; commits split code vs docs.
