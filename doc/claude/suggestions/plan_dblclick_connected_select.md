# Plan: double-click incremental connected-selection

*Spec:* `../specs/dblclick_connected_select.md`. Branch `fluid-editing`.
Status: **Commit 1 + 2 DONE** 2026-07-13 (engine + subcommand + tests, then the
cadence_compat double-click trigger; 22/22 pass, sabotage-verified). FEATURE
COMPLETE.

Commit 1 shipped: `select_grow_connected_step()` + `grow_one_ring_wires()`
(`select.c`), xctx state `dblgrow_level/seed_type/seed_id/sel_sig` (`xschem.h`),
`xschem select_grow_connected [x y]` (`scheduler.c:8102`), test
`tests/headless/test_dblclick_connected_grow.tcl` (T1–T6). Whole-net (level 2) is
implemented as repeated one-ring flood so it stays WIRES-ONLY (does not use
`select_connected_nets(0)`, which would pull in instances).

---

## 0. Ratified decisions (do not re-litigate)

| # | Fork | Decision |
|---|---|---|
| O1 | bindability path | **A — Tcl rebind + `xschem select_grow_connected` subcommand.** No registry-grammar change. Step 2 (registry surgery) is DROPPED. |
| O2 | ring contents | **wires-only rings** (thin variant); seed of any type stays selected |
| O3 | 3rd click | **geometric flood** `select_connected_nets(0)` |
| O4 | escalation | **cap at 3**: click1→ring1, click2→ring2, click3→all, click4+→no-op |
| — | Edit Properties | double-click **gives it up** under cadence_compat; `q` covers it |

**Active steps: 1, 3, 4, 5(A), 6, 7, 8.** Step 2 (registry `dblclick` device) is
not built.

---

## 1. Core: the escalation engine (C)

New function in `select.c` (mirrors `select_connected_nets` shape):

```c
/* level: 0 -> ring1, 1 -> ring2, 2 -> whole net. Returns new level. */
int select_grow_connected_step(void);
```

State on `xctx` (new fields, group under a `/* select.c */` comment near the
selection fields):
- `int dblgrow_level;`        /* current escalation level, -1 = inactive */
- `int dblgrow_seed_id;`      /* session-stable id of the seed object */
- `int dblgrow_seed_type;`    /* WIRE / ELEMENT / xTEXT ... */
- `unsigned int dblgrow_sel_stamp;` /* selection-generation snapshot */

Add a monotonic `xctx->sel_generation` bumped in `rebuild_selected_array()`
(`move.c:53`) whenever the set changes, so the grower can detect external
selection edits (spec reset condition 3). If a generation counter is deemed too
invasive, fall back to comparing `lastsel` + seed-still-selected only (weaker but
adequate for the common case).

Engine logic (driven by a seed already picked — see Step 3):

```
if (seed != dblgrow_seed) OR (seed not selected) OR (sel_stamp changed):
    dblgrow_level = 0; dblgrow_seed = seed; snapshot stamp
switch(dblgrow_level):
  case 0: /* ring1 */  grow_one_ring();          dblgrow_level = 1; break;
  case 1: /* ring2 */  grow_one_ring();          dblgrow_level = 2; break;
  default:/* all   */  select_connected_nets(0); dblgrow_level = 2; break;
snapshot stamp; rebuild_selected_array(); draw_selection();
```

`grow_one_ring()` (O2 = wires-only):
- If a wires-only ring is wanted, implement a thin non-recursive walk: for each
  currently-selected wire/pin endpoint, `get_square()` → walk
  `wire_spatial_table[sqx][sqy]`, `select_wire()` any wire whose endpoint
  `endpoint_near`/`touch`es a selected endpoint, marking with `select_wire(...,
  fast=nodraw)`; do **not** pull in instances. Model on the ELEMENT branch of
  `select_connected_nets` (`select.c:114-153`) + the wire loop in
  `check_connected_nets` (`select.c:46-87`), minus recursion and minus the
  instance selection.
- Cheap first cut (if O2 flips to "include devices"): just call
  `select_connected_nets(2)` and skip the thin variant entirely.

Draw once per step (nodraw during the walk, single `draw_selection()` at the end)
to avoid flicker on ring 2 of a big net.

## 2. Registry surgery — DROPPED (O1 = A)

Not built. Trigger is the Tcl rebind in Step 5. (Kept here only as the record of
the rejected option: a `dblclick` device + `DEV_DBLCLICK` + rerouting `case -3`
through `dispatch_input_action`.)

## 3. Seed pick + gesture entry (C)

Reached from the `select_grow_connected` subcommand (Step 4), which the Tk
`<Double-Button-1>` binding calls (Step 5):
- Pick the object under the cursor with `find_closest_obj`/`select_object`
  (`select.c:1440`) using the same override-lock the current
  `handle_double_click` uses (`callback.c:6670-6678`) so locked instances still
  seed.
- Identify seed id+type (session-stable `id` on every object; wire `id` at
  `xschem.h`, stamped at birth) for the escalation-state comparison.
- If the object was not selected, `select_object` selects it (this is the
  spec's "first double-click selects it too"), then run the engine → ring1.
- Call `select_grow_connected_step()`.

## 4. Tcl subcommand (always — it is the testable/loggable entry)

Add `xschem select_grow_connected [x y]` in the selection-letter dispatch of
`scheduler.c` (near `connected_nets`, `scheduler.c:1232`; respect the
first-letter dispatch rule — see memory `scheduler-letter-dispatch`):
- With `x y`: seed = object at (x,y) (calls the Step 3 pick), then one engine step.
- Without args: one engine step on the current selection/seed.
- Returns the new level (for tests + action-log replay).

This subcommand is also the Option-A trigger (Tcl rebinds `<Double-Button-1>` to
it) and the headless test hook.

## 5. Wire the trigger — DONE (C branch, not a Tk rebind)

**Implemented differently from the original Tk-rebind sketch below, on purpose.**
The Tk `<Double-Button-1>` binding funnels to event `-3`, whose C handler ALSO
terminates in-progress draw gestures (`callback.c:6682-6694`). A blind Tk rebind
of `<Double-Button-1>` would drop that gesture-termination. So the trigger is a
branch inside `handle_double_click` (`callback.c:6668+`):

```c
if(cadence_compat && (xctx->ui_state == 0 || xctx->ui_state == SELECTION)) {
  select_grow_connected_step(xctx->mousex, xctx->mousey, 1);
  return;
}
```

This keeps the `-3` funnel's screen→schematic conversion, `semaphore`/`ui_state`
guards, and draw-gesture termination (an active gesture has ui_state != 0/
SELECTION, so it falls through). Still O1=A: no registry change, `cadence_compat`-
gated, subcommand available for scripting. `cadence_style_rc` gets only a doc
comment (behavior is automatic under `cadence_compat`); no bind line.

Rejected original sketch (Tk rebind in `set_bindings`) — kept for the record:
`bind $topwin <Double-Button-1> "xschem select_grow_connected %x %y"` gated on
`[xschem get cadence_compat]`; would have needed manual screen→schematic math and
lost gesture termination.

## 6. Tests

`tests/headless/test_dblclick_connected_grow.tcl` (X or headless — selection is
observable without a display via `xschem selection`):
- Build a small net: a chain of split wire segments A–B–C–D–E with a couple of
  branch stubs and one instance pin + one net-label.
- **T1 (wire seed, ring escalation):** `select_grow_connected` at a mid-segment →
  assert selection = that segment + its 2 neighbors (ring1). Repeat → ring2
  (neighbors' neighbors). Repeat → whole net. Compare `xschem selection` counts
  and ids at each step against golden sets.
- **T2 (seed already selected):** pre-select the wire, one step → same ring1 as
  T1 (spec "same effect as if it were selected").
- **T3 (non-wire seeds):** seed a net-label; seed an instance pin; assert each
  grows the touching wire ring and keeps the seed selected.
- **T4 (reset):** grow to ring2 on seed X, then step on a different seed Y →
  assert level reset (Y-based ring1), not Y+ring3.
- **T5 (external-change reset):** grow to ring1, `unselect_all`, re-seed same
  object → level restarts at 0.
- **T6 (O2 wires-only):** assert rings contain only WIRE entries (no instance/
  label pulled in beyond the seed) — sabotage: if `grow_one_ring` accidentally
  calls `select_connected_nets(2)`, an instance appears and the assert flips.
- **T7 (no-op under `!cadence_compat`):** the Tk double-click still opens Edit
  Properties (manual/GUI note; headless asserts the subcommand still works when
  called directly).

Sabotage-verify per memory `green-but-hollow`: neuter `grow_one_ring` → T1/T2/T3
must fail; force `dblgrow_level` never to reset → T4/T5 must fail.

## 7. Risks / landmines
- **Selection-model rule:** every `.sel` flip needs `need_reb_sel_arr=1` +
  `rebuild_selected_array()` — use the `select_*` primitives, don't poke `.sel`
  raw (`move.c:53`, WIRING.md).
- **Split-segment churn:** if `autotrim_wires` re-splits/merges mid-gesture, seed
  ids can change. The escalation compares ids; a merge between clicks resets the
  escalation (acceptable — user just double-clicks again). Do **not** trigger
  `maintain_wire_segments` from the grower.
- **RO windows:** connected-grow is selection-only; keep `mutates=0` so it works
  in read-only descend windows, but confirm no path writes the sheet.
- **Multi-window:** the rebind lives inside `set_bindings` (Step 5), so main /
  new / detached windows all inherit it — do NOT bind `<Double-Button-1>`
  one-off outside `set_bindings` or detached windows regress to Edit Properties.
- **`semaphore>=2` / `ui_state` guards** (`callback.c:6666,6679`) must be
  preserved so the grow never fires mid-draw-gesture.

## 8. Suggested commit slicing
1. `feat(select): select_grow_connected_step engine + xschem subcommand` (Steps
   1,3,4) — testable headless immediately; tests T1–T6 fold in here.
2. `feat(cadence): double-click grows connected selection under cadence_compat`
   (Step 5 binding in set_bindings + rc, docs; T7).
