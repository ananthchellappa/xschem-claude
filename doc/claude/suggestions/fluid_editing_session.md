# Fluid editing — RED-first session plan + next-session prompt

Spec: `doc/claude/specs/fluid_editing.md`. Background: `doc/claude/FAQ.md` Q26.
Branch `fluid-editing` @ `8f7e621b`.

## Ground truth established this session (don't re-derive)

- The stretch pipeline is COMPLETE: per-shape editors `edit_{line,wire,rect,polygon}_point`
  (callback.c ~2281-2510) set `SELECTED1..4` + call `move_objects(START)`; release commits
  via `end_shape_point_edit` (callback.c:3763). `move.c` stretches every sub-part incl. arc
  (SELECTED1/2/3 @484) and rect edges (corner pairs @318-336). **No move.c work needed.**
- The ONLY gaps: (a) rect/line grab is gated `cond = already_selected` (callback.c:5896) →
  two-step; (b) no `edit_arc_point`, and `end_shape_point_edit` has no ARC branch; (c) rect
  edge (side) grab not detected — corners only.
- Polygon (@5892) and free-wire-vertex (`grab_free_wire_vertex` @5866) already do first-click
  grab — the model to match.
- All gate on `!readonly` (RO can't stretch), `intuitive` (default 1), plain drag.

## Phases (each: RED test → implement → GREEN → sabotage-verify → regression → commit)

### Phase 0 — test harness (do FIRST, no product change)
Fluid grab is an interactive gesture; drive it headless via `xschem callback` press/motion/
release (NOT `event generate` — see [[keybind-raise-test-gotchas]]). Resolve up front:
1. Exact `xschem callback` argc/order for Button1 press, Motion, release (crib from
   `tests/headless/test_callback_argc.tcl` + `callback()` in callback.c).
2. Coordinate space: callback wants screen px → convert schematic→screen via
   `xschem get xorigin/yorigin/zoom`, or find a seam to set `mousex_snap`/`mousey_snap`.
3. Geometry read-back for assertions: how to read a rect's 4 corner coords / a line's
   endpoints / an arc's center+angles after the gesture (the object query API from
   [[stable-object-handles]] — `xschem object <id>` / `objects` — or a debug dump). Pick a
   fixture: a small **editable** symbol with one rect, one line, one arc (make one under a
   test workdir; do NOT rely on the RO SANDBOX symbols).
Deliver a `tests/headless/test_fluid_editing.tcl` skeleton with a `grab_drag {x y dx dy}`
helper + `OVERALL: ok` sentinel, and register in run_regression hcases.

### Phase 1 — C1: rect + line first-click grab (cadence_compat)
- **RED** FE1: cadence_compat=1; press on a rect corner, drag +Δ, release → assert **only
  that corner moved**, opposite corner fixed. Fails today (whole rect translates).
- **RED** FE2: same for a line endpoint (one end moves, other fixed).
- Implement: `int cond = already_selected || cadence_compat;` (callback.c:5896).
- GREEN. **Sabotage**: force `cond = already_selected` → FE1/FE2 flip back to whole-move.
- Guard: FE1b — `cadence_compat=0` still two-step (first click moves whole) — stock intact.

### Phase 2 — C2: arc
- **RED** FE3: press on an arc angular endpoint, drag → assert radius/angle changed, center
  fixed. Fails today (no editor).
- Implement `edit_arc_point` (mirror `edit_rect_point`, tolerance zones on center + xa,ya +
  xb,yb → SELECTED1/2/3) + dispatch in the 5895 block + ARC branch in `end_shape_point_edit`.
- GREEN + sabotage (neuter the endpoint hit-test → no grab). **Verify undo**: after a stretch,
  `xschem undo` restores the arc (confirms `move_objects` owns the undo push).

### Phase 3 — C3: rect edge (side) grab
- **RED** FE4: press on a rect SIDE midpoint, drag perpendicular → assert that side's two
  corners moved, the other two fixed. Fails today (only corners detected).
- Implement side-midpoint zones in `edit_rect_point` → set the two corners
  (`SELECTED1|SELECTED2` for the shared edge, etc.).
- GREEN + sabotage.

### Phase 4 — C4 polish (optional, only if time)
- Line/wire endpoint tolerance (POINTINSIDE, not exact snap-match).
- Refactor 5892-5909 → `try_grab_shape_point(state)`.
- `fluid_editing` tcl var (default = cadence_compat) + Options menu; regated dispatch on it.

## Discipline (this repo)
RED-first + sabotage-verify every phase (a green suite ≠ the code ran — [[green-but-hollow]]).
After each phase: run headless hcases + baseline-compare the log/descend/select surface vs
`git stash`ed master (zero new FAIL), then commit. Small commits per phase. Push at the end
or per user.

---

## NEXT-SESSION PROMPT (paste after /clear)

```
Continue the "fluid editing" feature on branch fluid-editing (Cadence direct manipulation:
first-click grab of any object tip/edge → drag stretches, no pre-select, no enable_stretch).

Read first, in order:
  - doc/claude/specs/fluid_editing.md          (the design + the C1..C4 changes)
  - doc/claude/suggestions/fluid_editing_session.md   (this RED-first phase plan)
  - doc/claude/FAQ.md Q26                       (enable_stretch vs select_touch vs full-enclosure)
  - memory: MEMORY.md + action-log-descend-absorb.md, symbol-editor-apply-scope.md

Key facts (already established, don't re-derive): the stretch pipeline is COMPLETE
(edit_{line,wire,rect,polygon}_point + move_objects + end_shape_point_edit; move.c stretches
all sub-parts incl. arc + rect edges). The ONLY gaps are the gating at callback.c:5896
(cond = already_selected) and a missing edit_arc_point / arc branch in end_shape_point_edit.

Do Phase 0 first: build the headless gesture harness (drive xschem callback press/motion/
release; resolve callback argc, coord conversion, and geometry read-back; editable fixture
symbol). Then Phase 1 (C1) RED-first: write FE1/FE2 that FAIL today, then the one-line cond
change, GREEN, sabotage-verify, regression, commit. Then Phases 2→3. Ask before Phase 4.

Work in the editable copy, not the RO SANDBOX symbols. Follow this repo's RED-first +
sabotage-verify discipline and baseline-compare for regressions.
```
