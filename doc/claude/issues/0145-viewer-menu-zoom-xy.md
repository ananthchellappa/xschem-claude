# 0145 — Viewer View-menu Zoom In/Out (and Z / Ctrl-z) zoomed X only

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** ASE waveform viewer `wviewer::graph_zoom` (`src/wave_viewer.tcl`).
Follow-on to issue 0144 (Ctrl+wheel XY zoom) — closes the gap it left open.
**Reported by:** user, 2026-07-25 (answering the 0144 report's open question:
"Yes … View menu").
**Test:** `tests/headless/test_wave_viewer.tcl` — IX-menu-zoomin/out y-span legs
+ `graph_zoom` legs in IX-zoom-strips (6 new checks, 227 total).

## Symptom

After 0144, Ctrl+wheel zoomed both axes (X on every strip, Y on the pointed
strip), but the **View menu Zoom In/Out** — and the `Z` / `Ctrl-z` keys, which
route to the same proc — still zoomed **X only**. Two zoom affordances in one
window with different semantics.

## Root cause

`wviewer::graph_zoom` (D6) was written as an X-only zoom: for each target graph
it scaled `x1`/`x2` about the centre and re-froze `y1`/`y2` at their read-back
values. Its `gi` default `all` meant "every graph" because the menu was assumed
to have no pointer.

## Fix

`graph_zoom` now delegates to `wviewer::wheel_zoom` (the 0144 worker), so the
menu, `Z`, `Ctrl-z` and Ctrl+wheel share one contract: **X on every strip, Y on
the strip under the pointer.** `gi all` (what all four callers pass) resolves the
pointed strip via `graph_at_pointer`; an explicit `gi` names the Y target
directly (scripting/tests). ~30 lines of duplicated zoom math deleted.

Pointer resolution for the menu: the click leaves the canvas, but `mousex_snap`
retains the last canvas position, so `graph_at_pointer` yields the last strip the
pointer was over — and falls back to strip 0 when it was never over one. For
`Z`/`Ctrl-z` the pointer is genuinely over a strip, so it is exact.

**Semantics change to note:** an explicit `gi` used to mean "zoom only this
graph's X"; it now means "Y target, X on all". No caller in the tree passed `gi`
explicitly (all four use the default), and no test called `graph_zoom` directly,
so nothing depended on the old meaning.

`Z`/`Ctrl-z` were included deliberately even though the user named the View menu:
they are the same proc and the same affordance class, and a keyboard zoom has a
*better*-defined pointed strip than the menu. Splitting them would have meant two
zoom behaviors in one window — the very thing this issue removes.

## Verification

- RED before / GREEN after: IX-menu-zoomin/out now also assert the y-span
  shrinks/grows (both FAIL pre-fix), and the IX-zoom-strips `graph_zoom` legs
  fail pre-fix (no Y zoom; and the old explicit-`gi` path left the other strip's
  X untouched so the "matches the X zoom" assertion failed) — 4 RED → 0.
- New IX-zoom-strips `graph_zoom` legs (2 strips, explicit target 0, direction
  out): target strip 0 zooms X **and** Y; strip 1's X **matches**; strip 1's Y
  **unchanged**.
- No regressions: `test_wave_viewer` 227 (was 221), `test_ase_plot` 124,
  `test_graph_box_zoom_xy` 7, `test_ase_window` 155, `test_ase_dialogs` 133,
  `test_ase_savestate_adopt` 26, `test_ase_dirty` 41.

## Files

- `src/wave_viewer.tcl` — `graph_zoom` delegates to `wheel_zoom`.
- `tests/headless/test_wave_viewer.tcl` — menu y-span legs + `graph_zoom` strips
  legs.
- `doc/claude/specs/waveform_viewer.md`,
  `doc/claude/code_analysis/waveform_subsystem_reference.md`,
  `doc/claude/issues/0144-viewer-ctrl-wheel-zoom-xy.md` (out-of-scope note
  closed).
