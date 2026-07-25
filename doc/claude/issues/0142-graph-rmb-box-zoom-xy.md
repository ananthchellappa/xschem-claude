# 0142 — Graph RMB press-drag: no zoom rectangle, and Y ignored (X-only zoom)

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** shared graph interaction engine `waves_callback` (`src/callback.c`) +
`xctx` rubber state (`src/xschem.h`). Reference
`doc/claude/code_analysis/waveform_subsystem_reference.md` §5; spec
`doc/claude/specs/waveform_viewer.md` (RMB D2).
**Reported by:** user, 2026-07-25 (in the ASE waveform viewer).
**Test:** `tests/headless/test_graph_box_zoom_xy.tcl` (5 checks; DISPLAY-guarded
gesture, self-SKIP under --nogui).

## Symptom

In a graph (ASE waveform viewer, and equally an on-canvas schematic graph), an
RMB (Button3) press-drag inside the plot area:

1. draws **no zoom rectangle** (no drag feedback), and
2. zooms **only horizontally** — the Y extent of the drag is ignored.

Contrast the schematic editor, where RMB press-drag-release draws a rubber
rectangle and zooms to that box in both axes (`zoom_rectangle`).

## Root cause

The graph RMB box-zoom lives in the shared C engine `waves_callback`
(`src/callback.c`), not in the viewer Tcl. It was **X-only by design** and drew
no rubber:

- **Interior drag** (`!graph_left && !graph_top`): release branch
  (`callback.c:1454`) computed `xx1/xx2 = G_X(mouseX)` only and wrote just the
  `x1`/`x2` tokens. There was no `y1`/`y2` write.
- **Left-margin drag** (`graph_left`): a *separate* release branch
  (`callback.c:1471`) did a Y-only zoom (`y1`/`y2`, or `ypos1/ypos2` for
  digital).
- **No rubber rectangle** was ever drawn during any RMB graph drag — motion
  events during a Button3 GRAPHPAN drew nothing.

So the interior gesture the user performs was X-only with no feedback.

## Fix (shared C — applies to the viewer AND on-canvas graphs)

Decision (user-confirmed): apply to **all graphs**; keep the left-margin drag as
a **Y-only** zoom.

1. **Rubber rectangle.** New `xctx` fields `graph_rubber_active` +
   `graph_rubber_x/y`. On each Button3 interior MotionNotify (GRAPHPAN,
   `!graph_left && !graph_top && !graph_bottom`), erase the previous outline via
   the tiled GC (`drawtemprect(xctx->gctiled, NOW, …)` — restores the graph
   pixmap under the old outline) and draw the new one in `gc[SELLAYER]`, clamped
   to the plot box — exactly the `zoom_rectangle` RUBBER pattern. The outline is
   erased again on the Button3 release before the zoom redraw. Display-only:
   `drawtemprect` no-ops when `!has_x`, so headless box-zoom math is unaffected.
2. **XY box-zoom.** The press now saves **both** `mx_double_save` and
   `my_double_save` (previously only the axis-relevant one). The interior release
   branch now writes the X window (`x1`/`x2`) across the participating graphs
   **and** the Y window on the master graph — `y1`/`y2` for analog, `ypos1`/
   `ypos2` for digital — mirroring the existing left-margin Y-zoom (same `G_Y`/
   `DG_Y` math and Shift=zoom-out semantics). X stays synced across stacked
   graphs; Y is per-graph (master only), matching the engine's existing model.

Gating is unchanged: `!graph_left` keeps the left-margin Y-only zoom intact; a
pure-horizontal interior drag still zooms X only (`ymoved` false); a
pure-vertical interior drag now zooms Y (previously a no-op).

## Verification

- `test_graph_box_zoom_xy.tcl`: drives the full Button3 press→motion→motion→
  release sequence over the shipped `test_ne555.sch` embedded graph (Ctrl held to
  satisfy the non-locked-graph interaction gate). Asserts the X window zoomed in
  (gesture registered) **and** the Y window zoomed in (the fix). RED before
  (both Y checks fail — X-only), GREEN after (5/5).
- No regressions in the shared engine: `test_wave_viewer` 213, `test_ase_plot`
  124, `test_ase_window` 155, `test_ase_dialogs` 133, `test_ase_savestate_adopt`
  26 — all pass.

## Files

- `src/xschem.h` — `graph_rubber_active` + `graph_rubber_x/y` in `xctx`.
- `src/callback.c` — `waves_callback`: press saves both corners; live rubber
  draw/erase; interior release becomes an XY box-zoom.
- `tests/headless/test_graph_box_zoom_xy.tcl` — new (auto-discovered).
- `doc/claude/specs/waveform_viewer.md`, `.../waveform_subsystem_reference.md` —
  updated RMB / §5 notes.
