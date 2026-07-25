# 0146 — Viewer zoom was centre-anchored; must zoom AT the mouse pointer

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** ASE waveform viewer zoom (`src/wave_viewer.tcl` `wheel_zoom` /
new `zoom_about`) + new C verb `xschem graph_coord` (`src/scheduler.c`
`xschem_cmds_g`). Follow-on to 0144/0145.
**Reported by:** user, 2026-07-25 — "Zoom when using CTRL+Scroll_wheel must be AT
the mouse-pointer. Is that the case or is some other point being used?"
**Test:** `tests/headless/test_wave_viewer.tcl` — IX-anchor-pure (pure math) +
IX-anchor (the invariance teeth); 239 checks total.

## Answer to the question / symptom

It was **not** at the pointer: every viewer zoom (Ctrl+wheel, View-menu Zoom
In/Out, `Z`/`Ctrl-z`) scaled each strip's data window about its **centre** —
inherited from item-19's original X zoom and carried into 0144's `wheel_zoom`:

```tcl
set c [expr {($ax1 + $ax2) / 2.0}]        ;# centre, not the pointer
```

The schematic disagrees: `view_zoom` (`src/actions.c:4069`) is pointer-anchored —
`xorigin = -mousex_snap + (mousex_snap + xorigin)/factor` keeps the point under
the cursor fixed. So "same thing as in schematic" was not satisfied.

## Fix

**`wviewer::zoom_about {lo hi a f}`** (pure): scale `[lo,hi]` by `f` keeping data
coordinate `a` at the same relative position — `lo' = a-(a-lo)f`,
`hi' = a+(hi-a)f`. Empty `a` → centre (so the old behavior is just a special
case); `a` outside the range clamps to the nearest edge, so an anchor in a plot
margin pins that edge instead of flinging the window.

**`xschem graph_coord <graph_idx> <screen_x> <screen_y>`** (new C verb, `g`
dispatch group): the data-space `{dx dy}` under a canvas pixel — pixel →
`X_TO_XSCHEM` → `G_X`/`G_Y`. This is required because the graph→data transform
uses the **plot box** = the rect minus the 14% margins that only
`setup_graph_data` knows; re-deriving that in Tcl is the documented mirror/desync
trap (reference §8). Uses a **local** `Graph_ctx`, never `xctx->graph_struct`,
which an in-flight `draw_graph` may be using (landmine 11). Returns `{}` on a bad
index / non-graph rect so callers can fall back. Partially delivers reference
backlog item #7 (graph coordinate verb).

**Off-screen guard (found by adversarial review, then verified in the source):**
`setup_graph_data` **returns early** for an off-screen graph (the `RECT_OUTSIDE`
test, `draw.c` ~3583) *before* computing the `cx/dx/cy/dy` transform — and
`G_X`/`G_Y` divide by `cx`/`cy`. So the verb `memset`s the local `Graph_ctx` and
treats a still-zero scale as "no transform", returning `{}`. Sabotage-verified:
without the guard the verb returns `{inf inf}`. The viewer's own graph fills the
window so it never hit this, but an on-canvas schematic graph scrolled out of view
does. Tcl also rejects non-finite anchors (`string is double` *accepts* Inf/NaN),
so a bad value falls back to centre rather than clamping to an edge.

Context safety: the Tcl caller only queries the verb behind
`wviewer::switch_ctx`, which **verifies** the switch took (reference §8), so a
silently-refused context switch cannot make the verb read another window's graphs.

**Anchor plumbing:** the wheel binds now pass the event `%x %y` →
`wheel_bind` → `wheel` → `wheel_zoom`; `Z`/`Ctrl-z` pass the KeyPress `%x %y`
through `graph_zoom` (`key_filter` already received them). The **View menu**
passes none — its click is off-canvas — so it keeps zooming about centre, which is
the sane default for a menu.

**Per-strip anchoring:** the x anchor (a *time*) is computed once from the pointed
strip and reused by every strip — they share the axis, so anchoring them all at
the cursor's time keeps the stack aligned *and* pinned under the cursor. The y
anchor applies only to the pointed strip (0144/0145 contract).

## Verification

- **IX-anchor (the teeth):** probe a canvas pixel at 30%/30% (well off-centre,
  inside the plot body), record the data point under it via `graph_coord`,
  Ctrl+wheel zoom in at that pixel, re-read — the data point under that pixel must
  be unchanged (and both spans must have shrunk, so it really zoomed). Then zoom
  back out at the same pixel and re-assert. **Sabotage-verified:** disabling the
  anchor (back to centre) fails exactly the two "did not move" checks.
- **IX-anchor-pure:** `zoom_about` anchor/centre/clamp cases + span-scaling +
  anchor-fraction preservation (float tolerance, not string equality).
- **`graph_coord` legs** in `test_graph_box_zoom_xy.tcl`: on-screen returns two
  finite numbers; a bad index returns `{}`; an off-screen graph (panned away with
  `zoom_box`) returns `{}` — sabotage-verified (`{inf inf}` without the guard).
- No regressions: `test_wave_viewer` 239 (was 227), `test_ase_plot` 124,
  `test_graph_box_zoom_xy` 7, `test_ase_window` 155, `test_ase_dialogs` 133,
  `test_ase_savestate_adopt` 26.
- Main `run_regression.tcl`: its 3 netlisting `*_debug` FAILs and the hilight
  harness FAILs were reproduced with **all** changes stashed and rebuilt →
  pre-existing, not from this work. (The suite also ends with
  `couldn't execute "xschem"` because it execs the bare name, which is not
  installed on PATH in this workarea — also pre-existing.)

## Files

- `src/scheduler.c` — new `graph_coord` verb in `xschem_cmds_g`.
- `src/wave_viewer.tcl` — `zoom_about`; `wheel_zoom` anchor; `%x %y` threaded
  through the wheel binds, `wheel_bind`, `wheel`, `graph_zoom`, `key_filter`.
- `tests/headless/test_wave_viewer.tcl` — IX-anchor-pure + IX-anchor.
- `doc/claude/specs/waveform_viewer.md`,
  `doc/claude/code_analysis/waveform_subsystem_reference.md`.
