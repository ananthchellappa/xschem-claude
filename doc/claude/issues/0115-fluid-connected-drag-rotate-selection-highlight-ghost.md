# 0115 — fluid connected-drag rotate draws the selection-highlight ghost at the double-transformed overlay position

**Status: FIXED** (working tree). Reported by user (windowed feel test, animated-GIF capture):
"Select C12 + R18 + connecting wire, press `m` for connected drag, click to start drag, then
during the drag press ALT-R to rotate. When rotated, the selection highlight is a ghost in the
wrong location (similar to an issue flagged earlier)."

**Affects:** interactive connected-drag (`fluid_editing` on) of ≥1 object with attached wires,
when a mid-drag ALT-R / ALT-F rotates/flips the in-flight selection. Cosmetic only — no
data/netlist/geometry effect (the SAVED result is correct, e.g. `after_30.sch`). Same family as
**issue 0080** (the translation twin); this is its rotation counterpart.
**Branch:** `fluid-editing`. **Related:** 0080, 0114 (the group-transform that made mid-drag
ALT-R reach this path for a multi-selection), `rotate_keep_connected_stretch.md` Case 4b,
`incremental_wire_reroute.md` Phase II, WIRING.md §8 class I.

---

## 1. Symptom

During a fluid connected drag, after a mid-drag rotate the **selection overlay** (the
symbol-outline + pin boxes + labels drawn in the selection colour) appears as a duplicate
"ghost" a long way from the real, correctly-committed objects. The committed geometry that the
drag is live-editing is right; only the highlight overlay is drawn in the wrong place, so the
canvas shows the objects twice.

## 2. Root cause

Under a fluid stretch, each RUBBER step **live-commits** the rerouted geometry (Phase II) and,
since `rotate_keep_connected_stretch.md` Case 4b, a rotated/flipped stretch reroutes live too —
the shared commit block bakes `ROTATION(move_rot, move_flip, pivot, coord)` **into** the
committed `inst/wire/text` coords. `xctx->deltax/deltay` are deliberately kept at the accumulated
total, and `move_rot/move_flip` kept set, so the eventual interactive END
(`move_objects(END,0,0,0)`) can consume the whole transform (move.c live-commit tail).

`draw_selection_impl()` paints every selected object at
`ROTATION(move_rot, move_flip, pivot=x1,y1, coord) + delta`. On coords that are **already**
committed with that transform, this re-applies it: the overlay is transformed a SECOND time.

Issue 0080 fixed the translation half by making `draw_selection()` a wrapper that zeros
`deltax/deltay` while `fluid_reroute_dirty`. But it left `move_rot/move_flip/rotatelocal`
untouched — so once a mid-drag ALT-R set `move_rot`, the overlay got a second rotation about the
pivot, landing the highlight in a wholly wrong place. The wrapper (and the live step's own
repaint tail, move.c ~7762) is reached both by the step's own `draw()` and by any external full
redraw (Expose / hover / `xschem redraw` / crosshair) firing between RUBBER frames.

## 3. Fix (`src/move.c`, `draw_selection()` wrapper)

Neutralize the WHOLE move transform for the duration of the overlay draw, not just the delta:
save+zero `deltax, deltay, move_rot, move_flip, rotatelocal`, call `draw_selection_impl`, restore.
So while the committed geometry already carries the transform, the overlay paints those objects
**as-is** (identity) and coincides with them. END still sees the accumulated total.

- Gated on `fluid_reroute_dirty` — set only when `fluid_editing` was on at START ⇒ default-off is
  byte-identical. The translation-only fluid path already has `move_rot==move_flip==0`, so it stays
  byte-identical to the 0080 fix.
- Wrapper (vs inline zero) guarantees restore on every `draw_selection_impl` early-return
  (interruptable resume, tiled-fill fast path).

## 4. Verification — quantitative overlay-position proof

A temporary gated probe (`FLUID_GHOST_PROBE=<file>`) was added to the ELEMENT case of
`draw_selection_impl` logging each selected instance's committed origin vs its overlay draw origin
(`rx1+deltax, ry1+deltay`), then a windowed replay drove the exact user gesture
(`before_5.sch`: select C12+R18+#net2 wire, `m`, translate, ALT-R, hold, `xschem redraw`) — the
held frame is provably the mid-rotate fluid-dirty step (FLUID_TRACE: `what=RUBBER commit_now=1 …
rot=1`). Probe removed after measuring.

| frame | inst | committed origin | overlay-highlight origin | offset (ghost) |
|---|---|---|---|---|
| **pre-fix** | C12 | (-80,-260) | **(-150, 90)** | **(-70, +350)** |
| **pre-fix** | R18 | (-220,-200) | **(-210, -50)** | **(+10, +150)** |
| **post-fix** | C12 | (-80,-260) | (-80,-260) | (0, 0) |
| **post-fix** | R18 | (-220,-200) | (-220,-200) | (0, 0) |

Pre-fix the highlight is drawn hundreds of grid units away (`move_rot=1`, second rotation about the
pivot); post-fix it coincides exactly (`move_rot` zeroed for the overlay). To re-verify: re-add
the `FLUID_GHOST_PROBE` fopen/fprintf in the ELEMENT case of `draw_selection_impl` (log
`inst[n].x0/y0` vs `rx1+deltax, ry1+deltay`), then drive the §5 gesture headlessly with the X
event injection used by `tests/headless/test_connected_drag_group_transform_0114.tcl`
(`m` + MotionNotify translate + ALT-R + `xschem redraw`) and grep the `dirty=1` lines.

**Regression:** wireedit suite 56/56 ALL PASS (committed geometry byte-identical — the overlay
change touches no saved state); windowed gesture tests green — 0114 group-transform 7/7, 0113 7/7,
rotate_stretch_reconnect 17/17 + 0099 21/21 + 0100 51/51 + 0103 77/77 + 0104 76/76 + 0110 9/9.
(`test_fluid_editing` FE8 fails, but it fails identically on baseline HEAD — a pre-existing arc
drag-and-return failure unrelated to this fix.)

## 5. Repro (interactive)

1. `FLUID_TRACE=/tmp/t.log src/xschem --script src/cadence_style_rc --logdir /tmp`
2. Open `tests/from_user/before_5.sch`.
3. Leftward LMB rubber-band select C12 + R18 + the connecting wire.
4. `m` (connected drag), click to start, drag, then ALT-R mid-drag.
5. Pre-fix: the highlight ghost jumps far from the real objects. Post-fix: it tracks them.
