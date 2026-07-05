# Fluid editing: first-click tip/edge grab (Cadence direct manipulation)

Status: **C1-C3 BUILT + reviewed + committed** (2026-07-04). Branch `fluid-editing`.
Drafted @ `8f7e621b`; implemented @ `3c2959e3` (C1) `f03c05fd` (C2) `615b2442` (C3)
`2afe5d29` (adversarial-review fixes). C4 = deferred (Phase-4 gate).
Plan + next-session prompt: `doc/claude/suggestions/fluid_editing_session.md`.

## Built (2026-07-04)

- **C1** (`3c2959e3`): callback.c `cond = already_selected || cadence_compat` — first-click
  rect-corner / line-end grab.
- **C2** (`f03c05fd`): `edit_arc_point` (arc angular endpoints) + ARC dispatch + ARC branch
  in `end_shape_point_edit`.
- **C3** (`615b2442`): rect edge (full-side) grab in `edit_rect_point`, cadence-gated.
- **Review fixes** (`2afe5d29`) from a 6-lens adversarial workflow (5 confirmed findings):
  1. modifier-held press was swallowed by the shape editors (broke Cadence Shift-copy /
     Ctrl-detach) → editors now bail at the top when Ctrl/Shift held.
  2. arc grab was dispatched on `cond`, not cadence-gated → now cadence-only (like C3 edges).
  3. C3 edge bands blanketed the interior of a thin/zoomed-out rect (no whole-move) → each
     band enabled only when the rect exceeds `2*ds` in that direction.
  4. arc no-op restore falsely cleaned the `modified` flag (mouse-vs-center reference
     mismatch) → restore now keys on the net `deltax/deltay`.
  5. arc CENTER/radius (`SELECTED1`) handle removed as dead code — the center is not on the
     curve, so a click there never selects the arc; radius editing stays area-stretch-only.
- **Test**: `tests/headless/test_fluid_editing.tcl` (22 checks, drives real press/motion/
  release via `xschem callback`, reads geometry via `saveas`+B/L/A parse; self-skips under
  `--nogui`; registered in `run_regression` hcases). RED-first + sabotage-verified per phase.

### Open design decision (Phase-4 gate)
The spec's third arc handle — **grab center → change radius** — is NOT deliverable via
first-click: the geometric center is not on the arc, so a click there never hits/selects the
arc. Delivered the two angular-endpoint handles (start angle, sweep). Making radius
first-click-grabbable would need a *new* gesture (e.g. grab the arc body at the mid-angle),
which changes the mid-curve click from whole-move to radius-stretch — a UX choice deferred
to C4 / user sign-off.

## Goal

Cadence-style **direct manipulation** when `cadence_compat` is set: a single
click-and-hold on any **tip** (endpoint / vertex) or **edge** (side / corner) of an object,
followed by a drag, **stretches** that sub-part — with **no separate select step first**
and **without** requiring `enable_stretch`. "As long as what is clicked-and-held makes
sense, an extension of the object follows." This is the essence of *fluid editing*: eliminate
the select-then-drag two-step.

Non-goal: changing stock (non-cadence) behavior. All changes gate on `cadence_compat`
(default 0) so the default UX is untouched.

## What already works (and why the rest doesn't)

The press handler (`callback.c` `start_button1_pressed`, ~5860→) already, after
`select_object()` picks what is under the cursor, dispatches per-shape "grab a control
point" editors. Each sets `SELECTED1..4` on the grabbed sub-part and calls
`move_objects(START)`; the drag then stretches and **commits on release** via
`end_shape_point_edit()` (`callback.c:3763`). **The whole stretch pipeline is complete** —
`move.c` already stretches every sub-part:

- rect corners `SELECTED1..4` **and edges** (corner pairs `SELECTED1|SELECTED2` …) — move.c:290-336
- wire / line endpoints `SELECTED1/2` — move.c:400-456
- polygon vertex `SELECTED1` — move.c:349
- **arc** center/endpoints `SELECTED1/2/3` — move.c:484-492

So no `move.c` work is needed. The gap is purely **which editors are allowed to fire, and
when**:

| Object | First-click grab, no pre-select? | Mechanism / gate |
|---|---|---|
| polygon vertex | ✅ yes | `edit_polygon_point` @5892 — not gated on prior selection |
| wire endpoint (free) | ✅ yes | `grab_free_wire_vertex` @5866 (cadence fast-path, issue 0017) |
| wire endpoint (connected) | draws a new branch wire | `add_wire_from_wire` @5871 |
| **rect corner** | ❌ needs pre-select | `edit_rect_point`, gated `cond = already_selected` (5896) |
| **line endpoint** | ❌ needs pre-select | `edit_line_point`, same `cond` |
| **arc** any point | ❌ never | **no `edit_arc_point` exists** |
| rect **edge** (side) | ❌ never | `edit_rect_point` grabs corners only |

The `cond = already_selected` gate (callback.c:5896) *is* the two-step: first click
selects + moves-whole; only a second click on the handle stretches. Wire dodged it with a
dedicated cadence path; polygon was never gated; rect / line / arc were left behind.

## Design / changes

All gated on `cadence_compat` (+ existing `intuitive`, `!readonly`, plain drag = no
Ctrl/Shift). The corner/tip-vs-body discriminator already lives *inside* each editor (a
`cadhalfdotsize`-scaled tolerance zone around the handle; a body click returns 0 and falls
through to the normal whole-object move) — so ungating is safe.

**C1 — first-click rect/line grab (core, ~1 line).** callback.c:5896:
`int cond = already_selected || cadence_compat;`
Now a first click on a rect corner / line end grabs it; a body click still moves the whole
object. Stock behavior (`cadence_compat=0`) unchanged.

**C2 — `edit_arc_point` (new).** Mirror `edit_rect_point`: tolerance zones on the arc
center and its two angular endpoints → `SELECTED1/2/3`. Dispatch it in the same block. Add
the matching `ARC` branch to `end_shape_point_edit()` (which today has poly/rect/line/wire
but **no arc**). Geometry side already in move.c. Closes the only type with no editor.

**C3 — rect edge grab (the "edge" half).** `edit_rect_point` today detects only the 4
corners. Detect a click near a **side midpoint** and set that side's *two* corners
(`SELECTED1|SELECTED2` = one edge, etc.); move.c:318-336 already stretches corner pairs. A
click-detection add, not a geometry add.

**C4 — polish (optional).**
- Line/wire endpoints require an **exact** grid-snap match (`mousex_snap == x1`) to grab,
  while rect uses a tolerance zone. Give line/wire the same `POINTINSIDE` tolerance for a
  forgiving feel.
- Collapse the scattered per-type `if` chain (5892-5909) into one
  `try_grab_shape_point(state)` switch on `sel_array[0].type`.
- A dedicated `fluid_editing` toggle var (default = `cadence_compat`) instead of
  overloading `cadence_compat`, so it can be tuned independently.

## Constraints / risks

- **Read-only stays blocked** — every editor is gated `!xctx->readonly`; a stretch is a
  mutation. Fluid editing is editable-mode only. (The RO-symbol confusion in [[FAQ Q26]] is
  about *selection*, a separate axis.)
- **Undo:** the editors' inline `push_undo()` is commented out because `move_objects(START)`
  owns the undo push; the new arc path must go through the same `move_objects` START/END so
  a stretch is undoable — verify, don't assume.
- **Small objects** (< 2× handle tolerance): the whole body falls inside corner zones →
  can't move-whole, only stretch. Tie-break: grab a corner only if the click is nearer a
  corner than the object center.
- **Wire double-handling:** wire endpoint presses are consumed earlier
  (`grab_free_wire_vertex` for free ends, `add_wire_from_wire` for connected ends), so the
  ungated `cond` wire branch only sees non-endpoint clicks → `edit_wire_point` returns 0.
  Harmless, but keep the ordering.
- **select_at logging** (this branch's action-log): a fluid grab runs `select_object` →
  stashes a `select_at`, then a move; the two coexist (the move flushes the select_at). No
  conflict; see `doc/claude/specs/action_log_absorb.md`.

## Files (expected)

- `src/callback.c` — C1 (cond), C2 (`edit_arc_point` + dispatch + `end_shape_point_edit`
  arc branch), C3 (edge detection in `edit_rect_point`), C4 (refactor/var).
- `src/xschem.tcl` — C4 `fluid_editing` var + Options menu entry (if adopted).
- No `move.c` changes.

## Test

Headless, RED-first, driving the real gesture through `xschem callback` button
press/motion/release (interactive mouse can't be `event generate`-d reliably — see
[[keybind-raise-test-gotchas]]). Assert post-gesture geometry: first-click-on-corner
stretches ONLY that corner (not a whole-object translate). See the session plan for the
per-phase RED checks.
