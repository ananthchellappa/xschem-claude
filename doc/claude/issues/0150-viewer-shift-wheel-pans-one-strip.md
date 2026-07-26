# 0150 — Viewer Shift+wheel panned X on ONE strip; X is the shared axis

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** ASE waveform viewer pan (`src/wave_viewer.tcl` — new `wviewer::pan_x`,
called from `wviewer::wheel`'s shift arm and hence from the Left/Right arrows,
issue 0149). Pure Tcl.
**Reported by:** user, 2026-07-25 — "Shift-Scroll is doing a horizontal pan. But
it's only affecting one graph element. Reminder, any x-axis change needs to
affect all graph elements. Y axes of different strips are independent."
**Test:** `tests/headless/test_wave_viewer.tcl` — CG-panx legs (277 checks total).

## Symptom

`wviewer::wheel`'s `shift` arm resolved the pointed strip (`graph_at_pointer`)
and called `apply_range` on **that index only**, so a horizontal pan slid one
strip out of time-alignment with the rest of the stack. The zoom path had
already been fixed to the shared-X rule (0144: `wheel_zoom` zooms X on every
strip, Y only on the pointed one); the pan path never was. The 0149 arrows
inherited the bug by delegating to the same arm.

## Fix

New **`wviewer::pan_x {token dir}`**, mirroring `wheel_zoom`'s loop: for every
graph, freeze all four axes at their read-back values (D7), shift `x1`/`x2` by
5 % of **that strip's own span** (identical motion in the normal shared-range
case, proportional if the ranges differ), then ONE `set_graphs` + `regenerate`.
`wheel`'s shift arm is now just `return [wviewer::pan_x $token $dir]`.

Y is untouched by this and stays per-strip: the plain-wheel arm still pans
`y1`/`y2` on the pointed strip alone, which is the intended contract (each strip
carries its own signal scale).

## Rule of thumb (now uniform)

| gesture | X | Y |
|---|---|---|
| Shift+wheel / Left / Right | every strip (`pan_x`) | — |
| plain wheel / Up / Down | — | pointed strip |
| Ctrl+wheel, View>Zoom, `Z`, `Ctrl-z` | every strip (`wheel_zoom`) | pointed strip |
| RMB box zoom (C) | participating graphs | master graph |
| `f` / View>Fit | per strip, from its own data | per strip |

## Tests (CG-panx, two strips with the same x and different y)

- shift+wheel moves strip 0's x by one delta **and strip 1 by the same delta**,
  both still sharing one x window, with **no** y change on either strip;
- the Left arrow (through the production `key_filter`) does the same;
- a vertical pan moves **exactly one** strip's y and no strip's x;
- canvas baseline re-asserted on each.

Sabotage-verified: restoring the pointed-strip-only pan turns the "strip 1 moved
by the SAME delta" / "share one x window" checks red.

## Known remaining per-strip X writers

- **Graph > Axes…** writes x1/x2 for the one graph being edited (an explicit
  per-graph form; `Shared X Axis` in the Graph menu is the toggle that makes
  regenerate force graph-0's x onto the others).
- **Fit** fits each strip to its own data; identical in practice when the strips
  plot the same raw.
