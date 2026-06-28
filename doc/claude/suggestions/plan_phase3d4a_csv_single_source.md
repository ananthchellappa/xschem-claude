# Phase 3d.4a — actions.csv as the single source of truth for every bound id

**Status:** DONE (commit `7cb366f1`). **Branch:** `feature/action-registry`.
**Predecessors:** d3 (cheat-sheet generated from `xschem bindings dump`, `2c8d9e16`),
which surfaced the work-list for free: every action id the C registry binds that has
no `actions.csv` row renders in the sheet as a bare id instead of a human label.

## Goal

Every id in the live binding table resolves to a human label (and help text) in
`actions.csv`; the idle-ness of an action becomes csv data; id collisions between the
C registry and the csv are reconciled so **one id = one behavior**. Pure data + Tcl +
two-line C rename; no dispatch changes.

## The work-list (from the live cheat-sheet, not from memory)

Bare ids in the rendered sheet (16):

| id | bound to | csv row |
|---|---|---|
| `view.scroll_up/down/left/right` | arrows | **add** (4) |
| `view.pan_up/down/left/right` | Ctrl/Shift+wheel | **add** (4) |
| `view.snap_half` / `view.snap_double` | `g` / `G` | **add** (2) |
| `view.toggle_show_netlist` | `A` | **add** |
| `view.toggle_draw_pixmap` | `$` | **add** |
| `view.zoom_rect` | Button 3 | **add** |
| `edit.toggle_stretch` | `y` | **add** |
| `edit.toggle_orthogonal_wiring` | `L` | **add** |
| `sch.edit_header` | `B` | **rename C id** (see below) |

`graph.forward` is deliberately NOT given a csv row: it is routing plumbing, the
cheat-sheet footnotes it instead of listing it, and a csv row would surface a junk
no-op entry in the command palette.

## Reconciles (each verified by reading both sides)

1. **`sch.edit_header` → `prop.edit_header_license_text`.** The csv already has
   `prop.edit_header_license_text` running `update_schematic_header` — byte-identical
   to the C registry's Tcl backing for `sch.edit_header`. Two ids, one behavior →
   rename the C registry id + its `B` canvas row (+ 2 comments) to the csv id.
   Tests referencing the old id are updated.
2. **`Z` / `view.zoom_in`: NO collision (deferral was over-cautious).**
   `view_zoom(0.0)` defaults its factor to `CADZOOMSTEP` (actions.c:3028
   `factor = z!=0.0 ? z : CADZOOMSTEP`), so the csv's `xschem zoom_in`
   (= `view_zoom(0.0)`) and the wheel's `act_zoom_in` (= `view_zoom(CADZOOMSTEP)`)
   are **identical**; same for `zoom_out`/`view_unzoom`. One id, one behavior already
   — no `view.zoom_in_center` split needed. (The lesson-5 "same id, two behaviors"
   note is corrected in the docs commit.) This also un-defers a future `Z` key
   migration: `key 90 0 canvas → view.zoom_in` would be behavior-preserving.
3. **`view.zoom_rect` ≠ `view.zoom_box`: genuinely distinct, keep both ids.**
   `xschem zoom_box` (no args) sets `MENUSTART|MENUSTARTZOOM` (arm-then-click);
   `act_zoom_rect_start` calls `zoom_rectangle(START)` immediately at the pointer
   (the gesture). Different behaviors, correctly different ids.

## csv schema: the `idle` column

Append a 10th column `idle`: `1` = the action's default binding is idle-gated
(skipped by the dispatch while the engine is busy, `semaphore>=2`). Set on the 11
ids the C table seeds via `set_input_binding_idle` with a canvas row:
`toolbar.netlist`, `file.clear_schematic`, `edit.undo`, `edit.redo`,
`hilight.highlight_selected_net_pins`, `hilight.un_highlight_selected_net_pins`,
`hilight.un_highlight_all_net_pins`, `hilight.propagate_highlight_selected_net_pins`,
`sym.list.print_list_of_highlight_nets`, `sym.list.create_pins_from_highlight_nets`,
`sym.list.create_labels_from_highlight_nets`.
(`hilight.select_hilight_nets_pins` — Alt+k — is NOT idle-gated; per-chord truth
stays in the binding table / `bindings dump`, the csv column records the action's
default.) Every other row gets an empty trailing field, keeping field counts uniform.

## Label-only rows and the palette

The 15 new rows have an **empty `command`** cell: their behavior is C-backed and
dispatched by the binding table; there is no verified-identical Tcl equivalent
(`xschem set cadsnap` lacks the `change_linewidth`+`draw` tail; the toggles flip
tcl vars + xctx fields inline). Rather than invent near-equivalents (the `e` trap),
they are label/help metadata for generated views. `palette_refilter` learns to skip
command rows with an empty `command` so the palette doesn't list dead entries.
(Future option, deliberately not done here: an `xschem action <id>` dispatcher would
make them runnable from the palette.)

## Steps

1. `callback.c`: rename the `sch.edit_header` registry id + `B` binding row +
   comments to `prop.edit_header_license_text`. Build.
2. `actions.csv`: add the `idle` header column; append the empty/`1` idle field to
   every data row; add the 15 label-only rows (menu `view`/`edit` per id prefix,
   empty accel/command); update the header comment block (idle column, label-only
   row convention).
3. `action_registry.tcl`: palette skips empty-command rows; refresh the d4-era
   comments (the "folded in at d4" fallback note — the id fallback stays as a
   safety net but is no longer the expected path).
4. Tests:
   - `test_key_graph_context.tcl`: the two `sch.edit_header` row assertions +
     comment → new id.
   - `test_keybindings_help.tcl`: REPLACE the "C-only id falls back to its id"
     check with its inverse — **every** dump row's id (except `graph.forward`) has
     an `actions.csv` label, and spot-check `Up → Scroll up`, `B → Edit
     Header/License text`; assert rows expose an `idle` field (csv parses with the
     new column).
5. Run: engine `run.sh` 6/6 + all GUI smokes (`test_keybindings_help`,
   `test_key_graph_context`, `test_palette`, `dump_file_menu`, `test_accelerators`,
   `test_remap`, `test_mouse_bindings`, `test_gesture_bindings`,
   `test_binding_precedence`, `test_graph_context`).

## Risks / non-goals

- No binding/dispatch changes; the only C diff is an id string rename.
- The csv `accel` column on new rows stays EMPTY (the cheat-sheet reads the live
  table; a hand-written accel would re-introduce the drift d3 killed).
- d4b (load `keybindings.csv`/`mousebindings.csv` at startup) is a separate step.
