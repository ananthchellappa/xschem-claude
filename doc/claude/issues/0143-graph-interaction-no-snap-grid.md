# 0143 — Snap grid must not apply to graphs (box-zoom snapped to grid steps)

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** shared graph interaction engine `waves_callback` (`src/callback.c`).
Follow-on to issue 0142 (graph RMB XY box-zoom).
**Reported by:** user, 2026-07-25 ("Concept of snap grid does not apply to graph
windows. Remove that restriction on the zoom rectangle in the graph window").
**Test:** `tests/headless/test_graph_box_zoom_xy.tcl` (Part 2 unsnap legs).

## Symptom

The RMB box-zoom rectangle (and, generally, all graph pan/zoom) used the
schematic-grid-**snapped** pointer, so the zoom box could only be dragged to
grid points — a fine sub-region could not be selected. The snap grid is a
schematic drawing concept; it has no meaning inside a graph.

## Root cause

`callback()` computes `xctx->mousex_snap = round(mousex / cadsnap) * cadsnap`
(`src/callback.c:7631`) for every event, and `waves_callback` read
`mousex_snap`/`mousey_snap` in ~29 places (box-zoom corners, pan deltas, region
detection). So graph interaction inherited the schematic grid quantization.

## Fix

One override at the top of `waves_callback` (`src/callback.c`):

```c
xctx->mousex_snap = xctx->mousex;
xctx->mousey_snap = xctx->mousey;
```

`waves_callback` only ever mutates graph tokens / cursors — never schematic
geometry — and `callback()` returns immediately after this handler (the next
event recomputes the snap), so unsnapping here is safe and does not leak into
schematic editing. This unsnaps ALL graph interaction (box-zoom rectangle, pan,
region detection, cursor grab) in one place, matching the user's principle,
rather than swapping 29 call sites.

## Verification

- `test_graph_box_zoom_xy.tcl` Part 2: with `cadsnap` set LARGER than the whole
  drag, a snapped pointer would collapse press==release (no zoom); the test
  asserts the box-zoom still zooms X and Y. RED before this fix (2 FAIL — snapped
  to one point), GREEN after (7/7 total).
- No regressions: `test_wave_viewer` 213, `test_ase_plot` 124, `test_ase_window`
  155, `test_ase_dialogs` 133.

## EXTENDED, NOT SUPERSEDED — by issue 0177 (2026-07-30)

The decision above is right and the code below still ships. What was wrong was
the **scope claim**: "this unsnaps ALL graph interaction in one place" is true
only of interaction routed THROUGH `waves_callback`. Anything that runs when
`waves_selected()` declines the event still saw a grid-quantised pointer — and
that includes a band just inside every strip rect which contains the **top of the
legend**, where the schematic arm paints the crosshair *at* the snapped mirror.
The 0175 eyeball reported it as "the snap grid is at play when it comes to
clicking on the legend text".

Issue 0177 makes "this canvas has no snap grid" a **property of the window**
(`xctx->no_snap`, tested where `mousex_snap` is born) instead of a per-handler
override. **The `waves_callback` un-snap below is deliberately kept**: an
ordinary schematic window can embed graphs, `waves_callback` runs on those too,
and that context is not `no_snap` — its grid is real and wanted everywhere except
inside a graph. `test_graph_box_zoom_xy.tcl` Part 2 (this issue's own witness) is
exactly that case and goes red the moment the line is deleted.

See `doc/claude/issues/0177-viewer-has-no-snap-grid.md` and landmine 44.

## Files

- `src/callback.c` — `waves_callback` entry unsnap.
- `tests/headless/test_graph_box_zoom_xy.tcl` — Part 2 unsnap legs.
- `doc/claude/specs/waveform_viewer.md`, `.../waveform_subsystem_reference.md`.
