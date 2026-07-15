# `xschem select_at` — replayable click-select (issue 0005, FAQ Q24/Q25)

## Problem

Clicking to select an object produces **no** action-log line, so a session cannot
be replayed faithfully (`action_logging_checklist.md` rows 17/51/53, deferred).
`xschem selection` can *report* what is selected, but reporting uses the transient
array index / session id — neither is a referent you can log and replay against a
later, possibly-different state.

## Insight — log the gesture, not the identity

A click-select's faithful replayable form is **the click coordinate**: re-running
the same hit-test (`find_closest_obj`) reselects the same object with no identity
machinery, works across sessions, and covers all 7 drawable types uniformly. This
mirrors the existing Layer C doctrine (a gesture is logged at its END with its
final params: `zoom_box`, wire end, move delta). A click-select's final param is
the coordinate. `select_at` is the missing member of that family.

## Command

```
xschem select_at <x> <y> [add] [nodraw]
```

- `<x> <y>` — **schematic** coordinates (the same space as `xctx->mousex/mousey`
  and `find_closest_obj`), doubles.
- default — plain click: `unselect_all` then select the closest object (replaces
  the current selection).
- `add` — shift-click semantics: keep the existing selection and add the hit
  object.
- `nodraw` — skip the selection redraw (headless / batch).
- **Returns** the hit object as one **bare** `type index col id` row (`type` ∈
  wire|instance|rect|line|poly|arc|text; `id` = stable id where the type carries
  one, else −1). Bare-single mirrors `xschem object` vs the brace-wrapped list rows
  of `xschem objects`/`xschem selection`; so it equals `[lindex [xschem selection]
  0]` for that object. `col` is taken from `sel_array` (not `find_closest_obj`,
  which returns 0 for the flat types) so the row is byte-identical to the
  enumerator's. A **miss** (empty space) returns `""` and selects nothing (the
  default-mode `unselect_all` still runs).

## Logging (self-log-at-core + funnel)

Selection funnels through `select_object()` (`select.c`) — every click-select
call site reaches it. The log line is emitted there, once, gated on a genuine
coordinate hit-select:

```c
if(!select_at_suppress_log && !selptr && select_mode == SELECTED && sel.type)
  log_action("xschem select_at %.10g %.10g", snap_to_grid(mx), snap_to_grid(my));
```

**Effective coordinates**: the logged coordinate is the EFFECTIVE one — the raw
mouse position snapped to the current snap grid (`snap_to_grid()`, actions.c:
`my_round(v/cadsnap)*cadsnap`, -0 normalized to 0) and printed `%.10g` — never
the raw mouse double with float noise (`242.99999999999997`). Same rule for
`select_grow_connected x y`. Applied inside `log_action_stash_select_at()`
(util.c), so both the interactive funnel (raw mouse) and the `xschem select_at`
command (idempotent on already-snapped input) get it. Replay hit-tests at the
snapped point, which is Cadence's click-resolution model.

- `!selptr` — the caller passed a coordinate (not a precomputed object); a
  caller that already holds the object logs its own gesture.
- `select_mode == SELECTED` — excludes the deselect calls (`select_mode == 0`).
- `sel.type` — only when something was actually hit.

So **interactive plain clicks, verb-noun move/copy pickups, and launcher clicks**
all record `xschem select_at x y` at the funnel — the exact gap the user hit. The
verb-noun pickup logging `select_at` then `move_objects` is *faithful* (click
selected the object, then it moved), so it is deliberately NOT suppressed.

The `xschem select_at` **command** sets `select_at_suppress_log` around its own
`select_object()` call and logs the line itself (so it can add the ` add` marker
and it is recorded exactly once). `log_action` is a no-op when logging is off, so
the funnel adds ~zero cost.

**Interactive shift-click** (`add`): the plain-click select site
(`callback.c:5865-5868`) skips `unselect_all` when Shift is held — i.e. it
augments. It sets the one-shot `select_at_add` global (= `state & ShiftMask`)
around its `select_object()` call so the funnel logs `xschem select_at x y add`,
and resets it right after. Replay of that line augments instead of replacing. The
other click-select sites (plain click, cadence isolate, move/copy pickup) leave
`select_at_add` at its default 0 → the replace form.

## Replay

The logged file is source-able Tcl. Replaying `xschem select_at 120.5 340` re-runs
`find_closest_obj(120.5, 340)` and reselects whatever is closest — reproducing the
click. Coordinate-faithful: robust as long as the object is still there; if the
schematic changed, it selects whatever is now under the point, which is exactly
what replaying that click means.

## Scope / v1 gaps (documented, deferred)

- Empty-click **deselect-all** is not logged (no object hit). Follow-on.
- `selptr != NULL` select paths (wire-point edit, some cadence-compat isolates)
  log their own gesture, not `select_at`.
- Move-survival (reselect the same object after it moved) needs the handle-primary
  tier (`select @id`, causal-chain replay, row 53) — out of scope here.

## Tests

`tests/headless/test_select_at.tcl` (needs X + `--logdir`; established
gesture-log harness). RED-first: every check fails on a build without
`select_at` (`invalid command`), captured by a sentinel wrapper so the RED run
completes.

- SA1 command hits the object at its coordinate; return row matches `xschem
  selection`.
- SA2 default mode replaces a prior selection; `add` augments it.
- SA3 miss (empty coord) returns `""`, selects nothing.
- SA4 `nodraw` headless no-crash; selection still updated.
- SA5 command self-logs `xschem select_at x y` (and ` add`).
- SA6 **replay round-trip**: capture the logged line, `unselect_all`, source it →
  same object reselected (assert via `xschem selection`).
- SA7 **interactive**: a real click driven through `xschem callback` logs
  `xschem select_at x y` at the funnel.
- SA8 **interactive shift-click**: a Shift-click augments the selection and logs
  `xschem select_at x y add`.
