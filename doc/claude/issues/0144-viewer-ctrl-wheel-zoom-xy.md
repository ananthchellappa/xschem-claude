# 0144 — Waveform viewer Ctrl+wheel zoomed X only (should zoom X and Y)

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** ASE waveform viewer wheel handler (`src/wave_viewer.tcl`
`wviewer::wheel` / new `wviewer::wheel_zoom`). Spec
`doc/claude/specs/waveform_viewer.md` (Wheel D1); reference
`doc/claude/code_analysis/waveform_subsystem_reference.md` §8.
**Reported by:** user, 2026-07-25 — "CTRL+Scroll_Up/Down should do same thing as
in schematic, but it's only zooming in the X direction. The strip the cursor is
on should zoom in/out both in X and Y, but other strips should only match the X
zoom."
**Test:** `tests/headless/test_wave_viewer.tcl` — IX-zoom-in/out y-span legs +
new IX-zoom-strips leg (8 new checks, 221 total).

## Symptom

In the waveform viewer, Ctrl+wheel zoomed only the X (time) window. In the
schematic the same gesture zooms the view in both directions, so the viewer felt
half-functional: the vertical scale could not be zoomed with the wheel.

## Root cause

Item 19 (graph-interact) deliberately implemented Ctrl+wheel as an **X-only**
zoom on the pointed graph (`wviewer::wheel`, `mods == ctrl` branch): it read the
graph range, scaled `x1`/`x2` about their centre, and left `y1`/`y2` frozen at
their read-back values. That was the shipped contract — this issue revises it per
the user's ask.

Secondary defect found while fixing: because only the **pointed** graph's X was
written, the zoom was **clobbered under `sharedx 1`** — `regenerate` makes
non-master graphs inherit **graph-0's** x range (`wave_viewer.tcl:659`), so
Ctrl+wheel on a non-zero strip was overwritten on the next render.

## Fix

New `wviewer::wheel_zoom {token dir gi}`; `wviewer::wheel`'s ctrl arm resolves
the pointed strip (`graph_at_pointer`) and delegates to it. Semantics:

- **X window on EVERY strip** — same zoom factor about each strip's own centre,
  so the stack stays time-aligned ("other strips only match the X zoom"), and the
  `sharedx 1` inheritance above stays consistent instead of clobbering.
- **Y window ONLY on the pointed strip** — Y is per-strip (each carries its own
  signal scale), so zooming Y on all of them would fight the user's intent.
- Zoom factor unchanged from the previous X zoom: `0.8` in (up), `1/0.8` out
  (down), about centre.
- Every concrete axis is re-frozen at its read-back value **before** zooming (D7)
  so `regenerate` cannot re-autozoom an untouched axis away; ONE `set_graphs` +
  `regenerate` for the whole sweep.

`wheel_zoom` exists as a separate proc because it is the synchronous-write seam
the tests drive with an explicit target index — a 2-strip pointer position is not
reproducible headlessly (item-17 lesson: witness a state write, not a gesture).

**Out of scope (unchanged, X-only):** the View-menu Zoom In/Out and the `Z` /
`Ctrl-z` keys (`wviewer::graph_zoom`, D6) — they have no pointed strip. Say so if
they should follow.

## Verification

- RED before / GREEN after: IX-zoom-in and IX-zoom-out now also assert the
  y-span shrinks / grows (both FAIL pre-fix — X zoomed, Y did not, exactly the
  report).
- New IX-zoom-strips leg (2 strips, y ranges −1..1 and −2..2, `wheel_zoom … 1`):
  pointed strip 1 zooms X **and** Y; strip 0's X **matches** strip 1's new X
  span; strip 0's Y is **unchanged**; canvas stays pinned.
- No regressions: `test_wave_viewer` 221 (was 213), `test_ase_plot` 124,
  `test_graph_box_zoom_xy` 7, `test_ase_window` 155, `test_ase_dialogs` 133,
  `test_ase_savestate_adopt` 26.

## Files

- `src/wave_viewer.tcl` — new `wviewer::wheel_zoom`; `wheel` ctrl arm delegates.
- `tests/headless/test_wave_viewer.tcl` — y-span legs + IX-zoom-strips.
- `doc/claude/specs/waveform_viewer.md`,
  `doc/claude/code_analysis/waveform_subsystem_reference.md`.
