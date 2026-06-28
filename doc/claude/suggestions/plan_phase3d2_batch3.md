# Phase 3d.2 — batch 3 plan (clean canvas-only command keys)

**Status:** DONE (commit `9687d033`). **Branch:** `feature/action-registry`.
**Predecessors:** d1 (Tcl-backed actions, `design_phase3d1_tcl_backed_actions.md`),
the d2 dispatch refinement (`525bc94f`), batch 1 (`H`, Alt-`h`, `dd0e5909`) and
batch 2 (`y/G/g/T/O`, `9a8e517a`). See `tutorial_action_registry_phase3d.md` for
the running lessons.

## Goal

Migrate the next cluster of **clean canvas-only command keys** out of the
`handle_key_press` switch into the binding table, behavior-preserving and tested.
"Clean" = a branch with **no** `if(semaphore>=2)break;`, **no** `waves_selected`
routing, **no** mouse-coordinate dependency, **no** modal `ui_state` manipulation.
(Classification scan re-run on the current line numbers; these four qualify.)

## The four keys

| Key (keysym) | Chord | Behavior in the switch | Backing | Action id | Case fate |
|---|---|---|---|---|---|
| `A` (65) | plain `rstate==0` | toggle `netlist_show` tcl var (+ `alert_`) | **C** | `view.toggle_show_netlist` *(new)* | **whole case deleted** |
| `L` (76) | plain `rstate==0` | toggle `orthogonal_wiring` (+ `xctx->manhattan_lines=0`, `redraw_w_a_l_r_p_z_rubbers(1)`) | **C** | `edit.toggle_orthogonal_wiring` *(new)* | branch only (case stays) |
| `=` (61) | plain `state==0` | `tcleval("tclcmd")` | **Tcl** | `tools.execute_tcl_command` *(in csv)* | branch only (case stays) |
| `$` (36) | plain `rstate==0` | toggle `xctx->draw_pixmap` (+ `alert_`) | **C** | `view.toggle_draw_pixmap` *(new)* | branch only (case stays) |

`L`/`=`/`$` keep their `case` because the **other** branch stays in C: `L` Alt →
`place_net_label(0)`; `=` Ctrl → fill-pattern cycle; `$` Ctrl → toggle `draw_window`.

### `A` is the only graph-routed key here

`A` already has `over_graph` rows (`set_input_binding(DEV_KEY,'A',0,ACTX_OVER_GRAPH,
"graph.forward")` at callback.c:2450, plus the Ctrl one). So adding its **canvas**
row (`'A' 0 canvas -> view.toggle_show_netlist`) makes the key fully data and the
whole `case 'A'` deletes. Its `rstate==ControlMask` branch is a **canvas no-op**
(empty body, a comment: graph-only hcursor handled by the over_graph row), so nothing
is lost by deleting the case. Because an over_graph row exists, the dispatch keeps
computing `current_input_ctx()` for `A` — correct: over a graph it still forwards.

`L`/`=`/`$` are **canvas-only** (no `over_graph` row): they never forwarded to a
graph, so they rely on the d2 dispatch refinement (canvas-only chord → `ACTX_CANVAS`,
no `waves_selected`). **No** over_graph rows are added for them.

## The wrinkles (resolved)

1. **`A` is a multi-statement tcl-var toggle**, not a single `tcleval`. Replicate the
   branch verbatim in a C act (like `O`'s colorscheme act), not a one-liner Tcl
   command:
   ```c
   static int act_toggle_show_netlist(const ActionEvent *e) {
     int v; (void)e;
     v = !tclgetboolvar("netlist_show");
     if(v) { tcleval("alert_ { enabling show netlist window} {}");  tclsetvar("netlist_show","1"); }
     else  { tcleval("alert_ { disabling show netlist window } {}"); tclsetvar("netlist_show","0"); }
     return 1;
   }
   ```
   (Mirror the exact alert strings, including the stray spaces, so behavior is byte-identical.)
2. **`L` mutates a C flag + redraws**, plus only zeroes `manhattan_lines` on the
   off-transition (the on-transition leaves it). Replicate exactly:
   ```c
   static int act_toggle_orthogonal_wiring(const ActionEvent *e) {
     (void)e;
     if(tclgetboolvar("orthogonal_wiring")) { tclsetboolvar("orthogonal_wiring", 0); xctx->manhattan_lines = 0; }
     else                                   { tclsetboolvar("orthogonal_wiring", 1); }
     redraw_w_a_l_r_p_z_rubbers(1);
     return 1;
   }
   ```
3. **`$` toggles a C-only flag** (`xctx->draw_pixmap`) and emits an alert; it sets **no**
   tcl var (unlike its Ctrl `draw_window` sibling). Replicate the plain branch only:
   ```c
   static int act_toggle_draw_pixmap(const ActionEvent *e) {
     (void)e;
     xctx->draw_pixmap = !xctx->draw_pixmap;
     if(xctx->draw_pixmap) tcleval("alert_ { enabling draw pixmap} {}");
     else                  tcleval("alert_ { disabling draw pixmap} {}");
     return 1;
   }
   ```
4. **`=` is the easy one** — pure `tcleval("tclcmd")`, and the csv already has the id
   `tools.execute_tcl_command` with tcl `tclcmd`. Register it Tcl-backed (no C act).

## Concrete steps (mirror batch 2)

1. Add `act_toggle_show_netlist`, `act_toggle_orthogonal_wiring`,
   `act_toggle_draw_pixmap` next to the other batch-2 acts (after
   `act_toggle_colorscheme`). No act for `=` (Tcl-backed).
2. Add four registry rows: three C-backed (new ids), one Tcl-backed reusing
   `tools.execute_tcl_command` → `"tclcmd"`.
3. Seed four `canvas` binding rows in `init_input_bindings`:
   `'A' 0 canvas view.toggle_show_netlist` (next to the existing `A` over_graph rows
   conceptually, but place with the batch-3 group), `'L'/'='/'$' 0 canvas ...`.
   No over_graph rows.
4. Delete `case 'A'` entirely; delete the plain (`rstate==0` / `state==0`) branch from
   `case 'L'`, `case '='`, `case '$'` (leave their other branches + the `break;`).
5. Build (C89, no warnings).

## Testing (extend `tests/headless/test_key_graph_context.tcl`)

- `A`: press on canvas, assert `netlist_show` flips; press again, flips back
  (round-trip). Stub nothing — pure tcl var. **Watch:** the `alert_` proc must exist
  headless (it does — used by existing keys); if it pops UI, it's `alert_ {msg} {}`
  which is non-blocking.
- `L`: press on canvas, assert `orthogonal_wiring` flips; round-trip. (`manhattan_lines`
  is C-internal — the tcl var is the observable.)
- `=`: stub `proc tclcmd {} { incr ::tclcmd_calls }`; assert the counter increments on a
  canvas `=`.
- `$`: **no clean tcl observable** (C flag `draw_pixmap`, no var). Assert the **row
  present** (`key 36 0 canvas view.toggle_draw_pixmap`) and that pressing it doesn't
  error — behavior covered by the shared dispatch path (same approach batch 2 took for
  `toggle_ignore`).
- Data assertions: each `key <code> 0 canvas <id>` row present; `L`/`=`/`$` have **no**
  `over_graph` row; `A` keeps its existing `over_graph` row AND gains the canvas row.
- Narrow any older broad count assertion that the four new rows would trip.

Then the full regression: engine harness `tests/headless/run.sh` 6/6, all GUI smokes
green (`test_graph_context`, `test_binding_precedence`, `test_mouse_bindings`,
`test_accelerators`, `test_remap`, `test_gesture_bindings`, `test_key_graph_context`).

## Risks / watch-items

- **`test_accelerators.tcl`** asserts `{f s w}` have no Tcl-level bind — none of
  `A/L/=/$` are in that list; re-run to be sure.
- **`=` reuses a csv id** — first batch-3 key to do so. Confirm `find_action_def`
  accepts it and the bind validator (callback.c:2634) doesn't reject the Tcl-backed id
  (the d1 validator fix already handles this).
- **`A` whole-delete** — double-check the `rstate==ControlMask` branch really is an
  empty no-op before deleting the case (it is: comment-only, graph cursor handled by
  the over_graph row).
- **New ids not in `actions.csv`** (`view.toggle_show_netlist`,
  `edit.toggle_orthogonal_wiring`, `view.toggle_draw_pixmap`) — fine (registered in C);
  note for d4 csv unification so the d3 cheat-sheet stays complete.

## Deferred (not this batch)

- **`Z`** (Shift+Z zoom-in, `view_zoom(0.0)`): the csv maps `view.zoom_in` →
  Shift+Z → `xschem zoom_in` (= `view_zoom(0.0)`), but the C registry **already**
  binds `view.zoom_in` = `view_zoom(CADZOOMSTEP)` to the mouse **wheel**. Same id, two
  semantics → a **d4 csv/C reconciliation** decision, not a clean migration. Defer.
- **`%`, `_`**: *unconditional* (no mod guard); a whole-case-delete would change
  behavior for modified presses (Ctrl+%, …). Not behavior-preserving without
  enumerating mod variants.
- **`+`/`-`**: only Ctrl/Alt branches; no clean plain chord.
- Semaphore-gated keys (→ d1b), mouse-coord/placement commands, embedded-logic dialogs.

## Definition of done

- Builds clean; engine 6/6; all GUI smokes green.
- New checks pass (`A`/`L` var round-trips; `=` counter; `$` + `A`/`L`/`=` rows present
  and correctly canvas-only / `A` graph+canvas).
- `case 'A'` removed; the plain branch removed from `L`/`=`/`$`.
- No behavior change for any other key (kept Ctrl/Alt branches intact).
- Plan/tutorial/memory updated; commit code and docs separately, small steps.
