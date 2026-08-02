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

## The read-only twins (issue 0204)

`select_at` is mutating **by construction** — that is the whole point of it, and the
reason it can log a replayable gesture. But a caller that only wants to know *what
is under this point* must not pay for that: a leftover selection is read by other
subsystems as a statement of user intent. Issue 0204 is the exact failure — the
Ctrl-4 signal pick classified its clicks with `select_at`, so every plot click left
its target selected, and `hi_descend` then read that residue as a noun-verb descend
target instead of arming the verb-noun pick.

So each mutating coordinate verb has a read-only twin. Same hit test, same
classification, no `.sel`, no `sel_array`, no `draw_selection`, no log line:

| ask | mutating | read-only twin |
|---|---|---|
| what object is at (x,y)? | `select_at x y` | **`object_at x y`** |
| which instance is at (x,y)? | `select_at` + filter | `instance_at x y` (issue 0200) |
| what net is on the wire at (x,y)? | `select_at` + `nets -selected` | **`net_name_at x y`** |

- **`xschem object_at <x> <y>`** returns the same bare `type index col id` row
  `select_at` returns, or `""` on a miss. `col` is *reconstructed*, not read from
  `sel_array` (which a probe has no business rebuilding): `rebuild_selected_array`
  (move.c) stores `WIRELAYER` for wires and instances and `TEXTLAYER` for texts, and
  the four per-layer types already carry their layer out of `find_closest_obj`. So
  the row is field-for-field identical to an `xschem selection` row without a
  selection ever existing.
- **`xschem net_name_at <x> <y>`** / **`xschem net_name_at -wire <index>`** returns
  the RAW net token (`#` intact, original case) of a **wire**, or `""`. Not
  `net_at` — that name was already taken by an unrelated on-copper predicate.
  The WIRE-only gate is load-bearing, not a convenience: on a device *body*
  `nets -selected` reports every net the device touches, and a two-pin device shorted
  onto one net reports exactly one, so a count test alone misclassified a non-source
  device click as a voltage pick (`test_ase_unnamed_net` AN7b). A wire lies on
  exactly one net by construction. It runs `prepare_netlist_structs(0)` **before**
  the pick, like `flylines at`, so it is cold-correct and no `.node` pointer is
  captured across the prep that frees them.

  **A caller that already hit-tested should use `-wire <index>`**, feeding it the
  index out of an `object_at` row. The coordinate form runs a *second, independent*
  `find_closest_obj`, and `find_closest_text` expands floater text through Tcl on
  every pass — so a floater whose expansion changed between the two passes can win
  the cascade the second time and turn a resolved wire into a silent `""`. Indices
  survive the prep (`prepare_netlist_structs` names nodes; it never stores, splits or
  trims wires), so an index taken before it still names the same wire after it. This
  is what `ase::ui::sod_net_at` does.

`object_at` and `net_name_at`'s **coordinate** form use `override_lock=0`, matching
`select_at` exactly, so classification is unchanged for locked objects. That is
deliberately *not* the obvious choice for a probe — a lock gates edits, and a probe
cannot make anything editable (issue 0160's own argument) — but relaxing it changes
what a locked vsource and a locked unnamed wire classify as. That is a user-visible
decision, so it stays a separate one rather than a side effect (issue 0205).

`net_name_at -wire <index>` has no lock semantics at all: the lock lives only inside
`find_closest_obj`, which the index form does not run, so it returns a locked wire's
token. Consistent rather than inconsistent — the verb cannot edit — and invisible to
the ASE pick, whose index always comes from an `override_lock=0` `object_at` row.

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
