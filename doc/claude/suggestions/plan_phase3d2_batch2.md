# Phase 3d.2 — batch 2 plan (clean canvas-only command keys)

**Status:** proposed. **Branch:** `feature/action-registry`. **Predecessors:** d1
(Tcl-backed actions, `design_phase3d1_tcl_backed_actions.md`), the d2 dispatch
refinement (commit `525bc94f`), and d2 batch 1 (`H`, Alt-`h`, commit `dd0e5909`).
See `tutorial_action_registry_phase3d.md` for the running lessons.

## Goal

Migrate the next cluster of **clean canvas-only command keys** out of the
`handle_key_press` switch into the binding table, one small, tested, behavior-
preserving batch. "Clean" = a branch with **no** `if(semaphore>=2)break;`, **no**
`waves_selected` routing, **no** mouse-coordinate dependency, and **no** modal
`ui_state` manipulation. (Classification scan already done; these five qualify.)

## The five keys

| Key (keysym) | Chord | Behavior in the switch | Backing | Action id | Case fate |
|---|---|---|---|---|---|
| `y` (121) | plain `rstate==0` | toggle `enable_stretch` | **C** | `edit.toggle_stretch` *(new)* | **whole case deleted** |
| `G` (71) | plain `rstate==0` | double snap factor | **C** | `view.snap_double` *(new)* | **whole case deleted** |
| `g` (103) | plain `rstate==0` | half snap factor | **C** | `view.snap_half` *(new)* | branch only (case stays) |
| `T` (84) | plain `rstate==0` | `toggle_ignore()` | **C** | `prop.toggle_ignore_attribute_on_selected_instances` *(in csv)* | branch only (case stays) |
| `O` (79) | plain `rstate==0` | toggle light/dark colorscheme | **C** | `view.toggle_colorscheme` *(in csv)* | branch only (case stays) |

`T`/`O`/`g` keep their `case` because the **other** branch is semaphore-manipulating
or a dialog (Ctrl-T "load last closed", Ctrl-O "load most recent", Ctrl-g "set snap"
input dialog, Alt-g hilight-with-sem) — those stay in C, untouched.

All five are **canvas-only** (no `over_graph` rows): they never forwarded to a graph,
so they rely on the d2 dispatch refinement (canvas-only chord → `ACTX_CANVAS`, no
`waves_selected`). No graph rows are added.

## The two wrinkles (already resolved)

1. **`G`/`g` read `c_snap`, a `handle_key_press` parameter.** It is derived in
   `callback()` as `c_snap = tclgetdoublevar("cadsnap")` (callback.c:5207). An action
   doesn't get the parameter, so it reads the same source:
   ```c
   static int act_snap_double(const ActionEvent *e) {
     (void)e; set_snap(tclgetdoublevar("cadsnap") * 2.0); change_linewidth(-1.); draw(); return 1; }
   static int act_snap_half(const ActionEvent *e) {
     (void)e; set_snap(tclgetdoublevar("cadsnap") / 2.0); change_linewidth(-1.); draw(); return 1; }
   ```
2. **`y` toggles the local `enable_stretch` param** (callback.c:4131), which is dead
   (the function returns right after); the only durable effect is `tclsetboolvar`. So:
   ```c
   static int act_toggle_stretch(const ActionEvent *e) {
     (void)e; tclsetboolvar("enable_stretch", !tclgetboolvar("enable_stretch")); return 1; }
   ```
   `enable_stretch` is itself derived `= tclgetboolvar("enable_stretch")` (callback.c:5151),
   confirming the tcl var is the source of truth.

`T` → `act_toggle_ignore` = `(void)e; toggle_ignore(); return 1;` (single C call).
`O` → `act_toggle_colorscheme` replicating the branch **verbatim** (dark_colorscheme
flip, `dim_value`/`dim_bg` resets, `build_colors(0.0,0.0)`, `draw()`). **Do NOT** route
`O` through the Tcl `xschem toggle_colorscheme` (the csv command) unless you first
verify it does the *identical* thing including the dim resets — default to the C act.

## Concrete steps (mirror d1/batch-1)

1. Add the five `act_*` functions next to the others (after `act_make_sch_sym_from_sel`).
2. Add five registry rows (all C-backed, `tcl=NULL`). For the two csv ids reuse them;
   for `edit.toggle_stretch`/`view.snap_double`/`view.snap_half` (not in csv yet) just
   register them in C — the csv unification is d4.
3. Seed five `canvas` binding rows in `init_input_bindings` (keysym, `0`, `ACTX_CANVAS`,
   id). No over_graph rows.
4. Delete `case 'y'` and `case 'G'` entirely; delete the plain branch from `case 'g'`,
   `case 'T'`, `case 'O'` (leave their other branches + the `break;`).
5. Build (C89, no warnings).

## Testing (extend `tests/headless/test_key_graph_context.tcl`)

Four of the five are observable via Tcl vars — assert the flip/scale:
- `y`: `enable_stretch` toggles. `O`: `dark_colorscheme` toggles. `G`: `cadsnap` ×2.
  `g`: `cadsnap` ÷2. Press on canvas (`keyat $cx $cy <keysym>`), read the var.
- `T` (`toggle_ignore`, operates on selection — no clean observable): assert the
  **row present** + that pressing it doesn't error; behavior is covered by the
  shared dispatch path. (Optionally stub nothing — it's C.)
- Data: each `key <code> 0 canvas <id>` row present; the migrated keys have **no**
  `over_graph`/`canvas`-elsewhere rows beyond the one.
- Negative/regression: `G` then `g` returns `cadsnap` to its start (×2 then ÷2);
  confirm an *un*migrated chord on a shared case still works — e.g. press Ctrl-`g`
  path is untouched (hard to assert headless; at least confirm the case still compiles
  and `bindings dump` shows no `g`/`T`/`O` Ctrl rows).

Then the full regression: engine harness `tests/headless/run.sh` 6/6, all GUI smokes
green (`test_graph_context`, `test_binding_precedence`, `test_mouse_bindings`,
`test_accelerators`, `test_remap`, `test_gesture_bindings`, `test_key_graph_context`).

## Risks / watch-items

- **`test_accelerators.tcl`** asserts `{f s w}` have no Tcl-level bind — none of
  `y/G/g/T/O` are in that list, so it should be unaffected; re-run to be sure.
- **`O` colorscheme** is the one with non-trivial C (build_colors/dim) — replicate
  exactly; don't "simplify".
- **New ids not in `actions.csv`** (`edit.toggle_stretch`, `view.snap_*`) — fine for
  now (registered in C); note them for the d4 csv unification so the cheat-sheet (d3)
  stays complete.
- Keep cases `g`/`T`/`O` intact except the plain branch; their Ctrl/Alt branches are
  semaphore-manipulating and stay in C.

## Definition of done

- Builds clean; engine 6/6; all GUI smokes green.
- New checks pass (the var-flip/scale observables + rows present).
- `case 'y'` and `case 'G'` removed; the plain branch removed from `g`/`T`/`O`.
- No behavior change for any other key (including the kept Ctrl/Alt branches).
- Plan/tutorial/memory updated; commit code and docs separately, per the rhythm.

## Deferred (not this batch)

Semaphore-gated keys (→ d1b: the 6 chords + `n`/`q`/etc.), mouse-coord/placement
commands, and embedded-logic dialogs (insert-symbol `file_chooser`/`load_file_dialog`).
