# Issue 0018 — with a wire selected (orthogonal_wiring on), a new wire cannot be completed

**Opened:** 2026-06-20
**Status:** ✅ **RESOLVED 2026-06-20** (branch `fluid-editing`).
Fix in `drawtemp_manhattanline()` (`src/draw.c`): save/restore `xctx->manhattan_lines`
around its `force_manhattan` recompute so painting the selection overlay never leaks the
selected wire's orientation into the active wire-drawing gesture. Regression test
`tests/headless/test_wire_complete_with_selection.tcl` (vertical-selected→horizontal,
horizontal-selected→vertical, plus nothing-selected guard); sabotage-verified. Guards
green: wireedit TC0–17, `test_cadence_drag`, `test_wire_vertex_grab`,
`test_gesture_bindings`, core regression.
**Affects:** interactive wire (and line) drawing whenever a wire is selected and
`orthogonal_wiring` is on — i.e. the `src/cadence_style_rc` setup.
**Severity:** high — wire drawing appears broken (the rubber band keeps following and the
click never places a wire) until you deselect.
**Branch:** `fluid-editing`.
**Reported config:** `src/xschem --script src/cadence_style_rc` →
`cadence_compat 1`, `orthogonal_wiring 1`, `persistent_command 1`, `snap_cursor 1`,
`infix_interface 0`, `use_cursor_for_selection 1`, `enable_stretch 1`, `draw_crosshair 1`.

---

## 1. Symptom

Draw a wire, **select it**, then start a new wire anywhere (it does *not* have to start on
the selected wire) and try to complete it: the rubber band keeps following the cursor and
the completing click never places the wire. Deselect the first wire and drawing works
normally again.

## 2. Root cause

With `orthogonal_wiring` on, `xctx->manhattan_lines` (1 = horizontal-first, 2 =
vertical-first) is the global "which way does the L bend" state for the wire/line currently
being drawn. It is (re)computed from the active wire's own dx/dy in
`recompute_orthogonal_manhattanline()`, called explicitly from
`redraw_w_a_l_r_p_z_rubbers()` (draw) and `place_moved_wire()` (move).

On every motion of the new wire, the rubber-band redraw also repaints the **selection
overlay** under it: `new_wire(RUBBER)` → `restore_selection()` → `draw_selection()`. For a
selected wire, `draw_selection()` strokes it with `drawtemp_manhattanline(..., force_manhattan=1)`
(`src/move.c`), and `drawtemp_manhattanline()` calls `recompute_orthogonal_manhattanline()`
on **the selected wire's** endpoints — overwriting the global `manhattan_lines` with the
*selected* wire's orientation.

So a vertical selected wire forces `manhattan_lines = 2` (vertical-first) while the user
draws a horizontal wire. Verified trace (drawing horizontal `(100,100)→(160,100)` with a
vertical wire `(0,-40)–(0,40)` selected), two recomputes interleave every motion:

```
recompute p1=(100,100) p2=(160,100) dx=60 dy=0  -> manh=1   (active wire — correct)
recompute p1=(0,-40)   p2=(0,40)    dx=0  dy=80 -> manh=2   (selected wire — clobber, wins)
```

In `persistent_command` mode the completing click runs `start_wire()`, which sets
`constr_mv = manhattan_lines` (= 2) and then constrains the rubber endpoint back to the
start x (`mx = mx_double_save`). The horizontal segment collapses to zero length, so
`new_wire(PLACE)` stores nothing — the wire can't be completed. With nothing selected,
`draw_selection()` paints nothing, `manhattan_lines` stays correct, and drawing works.

## 3. Fix

`drawtemp_manhattanline()` is a *drawing* routine; its `force_manhattan` recompute exists
only to stroke that one line as an L. It must not leak that recomputed value into global
gesture state. The fix saves `manhattan_lines` on entry and restores it after drawing when
`force_manhattan` was set (`src/draw.c`). The legitimate consumers are unaffected because
they recompute `manhattan_lines` themselves before using it: the wire/line draw
(`redraw_w_a_l_r_p_z_rubbers`) and the wire move placement (`place_moved_wire`,
`src/move.c:1032`).

## 4. Tests

`tests/headless/test_wire_complete_with_selection.tcl` drives the real
press/motion/release dispatch under the reported config:
- vertical wire selected → a horizontal new wire must complete (RED before fix);
- horizontal wire selected → a vertical new wire must complete (symmetric);
- nothing selected → still completes (guard, green before & after).
Window-readiness wait + precondition-retry keep it deterministic under WSLg.
Sabotage-verified: removing the restore reddens the two selected-wire cases while the
guard stays green.

## 5. Notes

- An earlier draft of this issue blamed a stale `prev_rubberx/prev_rubbery` baseline. That
  is a real but *separate* narrow edge case (a new gesture's first rubber update being
  skipped when it coincides with the previous gesture's last rubber point) and was **not**
  the reported bug; the reported failure is the `manhattan_lines` clobber above. The
  prev_rubber observation is left here only as a pointer in case it is pursued later.
