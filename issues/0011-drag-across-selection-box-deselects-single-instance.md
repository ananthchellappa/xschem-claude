# Issue 0011 — moving the pointer across the dashed annotation box visually drops the selection highlight

**Opened:** 2026-06-15
**Refined:** 2026-06-16 — reproduction corrected after investigation: this is
**motion-triggered** (no button press) and the object stays **logically
selected**; the visible effect is the hover-highlight redraw disturbing the
selection overlay. Earlier framing ("a drag deselects", press-path root cause)
was wrong and is superseded below.
**Status:** FIX APPLIED 2026-06-16 (pending visual eyeball) — root cause pinned
to `draw_hover`'s stale-`sel_array` repair (see §7); one-line fix in `callback.c`
(`rebuild_selected_array()` before the repair `draw_selection`). Verified at the
data level (the bug condition `lastsel==0` at repair time now rebuilds to the real
count) and guarded by `tests/headless/test_hover_selection_repair.tcl`. The
on-screen repair is a window-only overlay → final confirmation is a manual eyeball
(move the bare pointer across the dashed box with `hover_highlight` on; the
selection box must stay drawn).
**Affects:** interactive use with `src/cadence_style_rc`
(`intuitive_interface=1`, `cadence_compat=1`, `enable_stretch=1`,
`hover_highlight` on). Seen on `xschem_library/examples/mos_power_ampli.sch`.
**Severity:** low–medium (the user believes the object was deselected, so they
re-select; no data loss — the object is in fact still selected).
**Branch:** the implicated code (`draw_hover`, the hover-awareness cue) landed on
this lineage; see [[hover-highlight]]. Suggest a small branch when picked up.
**Related:** `code_analysis/FAQ.md` Q14, `code_analysis/wire_follow_stretch_move.md`.

---

## 1. Reproduction (corrected — confirmed headlessly)

1. Run with `--script src/cadence_style_rc`; open
   `xschem_library/examples/mos_power_ampli.sch`.
2. Select a single instance — e.g. **R18** (around schematic (1240,-930)). Its
   dashed selection box is drawn.
3. **Without pressing any mouse button**, move the pointer horizontally to the
   right, e.g. to ~(1440,-930), so it **crosses the edge of the large dashed box**
   that surrounds the circuit.
4. **Observed:** R18's selection highlight disappears — it *looks* deselected.

**No button press or drag is involved** — bare pointer motion across that boundary
is enough. This corrects the original report, which described it as a click/drag.

### What the "dashed rectangle" actually is
It is **not** the selection highlight and **not** a UI artifact — it is a real
drawn object in the schematic: `mos_power_ampli.sch:100`

```
P 4 5 0 -1290 1390 -1290 1390 -130 0 -130 0 -1290 {dash=3}
```

a dashed **polygon** (a box from (0,-1290) to (1390,-130)) drawn as an annotation
around the whole circuit. Most elements in this example sit inside it, which is
why "most of the elements" are affected. Crossing its outline makes that polygon
the object under the cursor.

---

## 2. Key finding: the object is NOT actually deselected

Driving the exact gesture headlessly via `xschem callback` (bare `MotionNotify`
events sweeping across the box edge) and querying `xschem objects -selected` after
each step shows **the instance remains selected the entire time** (its `.sel`
flag stays `SELECTED`; the `ui_state` `SELECTION` bit stays set). A subsequent
`xschem redraw` brings the highlight back.

So the user-visible "deselection" is a **rendering artifact**: the selection
*highlight overlay* is erased on screen while the selection itself is intact.

---

## 3. Implicated code (confirmed) — the hover-highlight redraw

Every `MotionNotify` runs `draw_hover(0)` (`callback.c:3491`, inside
`handle_motion_notify`; `mouse_inside` is set just above at `:3369`). `draw_hover`
(`callback.c:1817`) outlines the object under the cursor with a dashed-yellow cue
and, when the hovered object changes, **erases the previous outline and repairs
the selection/scope overlays**:

```c
if(prev_type) { /* erase previous hover outline, then repair overlays */
  draw_hover_shape(xctx->gctiled, prev_type, xctx->hover_n, xctx->hover_col); /* erase */
  draw_selection(xctx->gc[SELLAYER], 0);   /* repair selection highlight */
  draw_scope_highlight();
}
if(newsel.type) draw_hover_shape(xctx->gc_hover, newsel.type, ...); /* draw new outline */
```

(`callback.c:1849-1862`; `draw_hover_shape` is `draw.c:5462` — for a POLYGON it
draws the polygon outline via `drawtemppolygon`.)

Instrumented trace of the sweep: as the pointer leaves the selected instance
(hover is **suppressed** on a selected object, so `newsel.type=0`) and approaches
the box edge, `find_closest_obj` starts returning the dashed **polygon**
(`newsel.type=32 == POLYGON`), and the erase/redraw path runs on the
`draw_window=1, draw_pixmap=0` overlay. The selection highlight is collateral in
that window-only erase/repair dance.

This path **only exists because the hover-awareness cue is enabled**
(`hover_highlight`); `draw_hover` early-returns when it is off (`callback.c:1835`).
So this is most likely an **interaction introduced by the hover feature**
([[hover-highlight]]), not pre-existing selection logic.

---

## 4. Leading hypothesis for the exact defect (NOT yet pixel-verified)

The window-only erase/repair in `draw_hover` does not faithfully restore the
selection highlight when the hovered object is a large shape overlapping the
selected object (here the big dashed polygon encloses R18). Candidates:

- the erase (`draw_hover_shape(gctiled, …)`) over/around the big polygon paints
  background where the selection box is, and `draw_selection(gc[SELLAYER],0)` does
  not fully repaint it in the window-only (`draw_pixmap=0`) pass; or
- an overlay/XOR ordering issue between the hover outline, the selection
  highlight, and the scope highlight when shapes overlap.

A clean horizontal sweep in the headless harness fires the erase/repair branch
only a little (few intervening hovered objects on that row), which is likely why
the *logical* state is trivially confirmed but the *visual* artifact is best seen
in the live GUI, where the cursor crosses many objects.

### Quick confirmation step (for the live GUI)
Set `hover_highlight 0` and repeat the gesture. If the highlight no longer
vanishes, the hover redraw is confirmed as the cause (code-evident: `draw_hover`
no-ops when `hover_highlight` is false, `callback.c:1835`).

---

## 5. How to verify a fix (headless + eyeball)

- **Headless (state):** the existing probe pattern — select an instance, inject a
  `MotionNotify` sweep across the polygon edge, assert `xschem objects -selected`
  is unchanged. (This already passes today, since the bug is visual — keep it as a
  guard that no fix turns the visual bug into a logical one.)
- **Eyeball (the real bug):** in the GUI, confirm the selection highlight stays
  drawn while the pointer crosses the dashed box, with `hover_highlight` on.
- A faithful automated check needs a window pixel grab (the highlight is a
  window-only overlay, absent from `xschem print` output).

---

## 6. Acceptance criteria

- With `hover_highlight` on, moving the bare pointer across the dashed annotation
  box (or any large overlapping shape) leaves a selected object's highlight
  intact on screen.
- The object remains selected (it already does) — no regression to logical
  selection state.
- The hover cue itself still works (objects under the cursor still outline).

---

## 7. Root cause (pinned) and fix

Confirmed by instrumenting `draw_hover` and driving the exact bare-motion sweep
across the dashed polygon headlessly:

1. `draw_hover` (`callback.c`), on a hover change, **erases the previous outline
   then repairs overlays** with `draw_selection(xctx->gc[SELLAYER], 0)`.
2. `draw_selection` (`move.c:210`) is the **move-time** drawer: it paints from
   `xctx->sel_array` / `xctx->lastsel` (via `movelastsel`). On the motion/hover
   path nothing rebuilds that snapshot, so **`lastsel` is stale `0`** while the
   object is still selected by its `.sel` flag. With `lastsel==0` the repair
   draws **nothing**.
3. The erase is destructive here: with `fix_broken_tiled_fill` set (it is `1` on
   this WSL host), `drawtemppolygon(gctiled, …)` (`draw.c:2194`) restores the
   shape's **whole bounding box** from the backing pixmap. For the big enclosing
   polygon that bbox is essentially the whole schematic, so it wipes the
   window-only selection overlay across the entire area.
4. Erase wipes the highlight; no-op repair never repaints it → the object *looks*
   deselected while its `.sel` flag is untouched (hence `xschem objects
   -selected` still lists it, and the earlier headless probes saw selcount==1).

Instrumented proof: at the repair, `lastsel=0`/`movelastsel=0` (buggy); after the
fix, `lastsel=1`/`movelastsel=1`, so `draw_selection` repaints the box.

**Fix** (`callback.c`, in `draw_hover`, repair branch): call
`rebuild_selected_array()` before `draw_selection`, so the repair paints from the
true selection (the `.sel` flags) rather than a stale snapshot. The branch only
runs on a hover *change*, so the extra rebuild is infrequent (and the path
already calls `find_closest_obj` every motion).

**Why it was single-vs-multiple in the original report:** unrelated to the true
mechanism — that framing came from the earlier (wrong) press-path hypothesis. The
confirmed motion mechanism does not depend on the selection count.

**Note (not fixed, separate):** even with a correct repair, erasing a *huge*
hovered shape via a full-bbox pixmap restore is wasteful on
`fix_broken_tiled_fill` hosts (it repaints a large region on every hover change
near the polygon). Could be tightened later to the actual outline region; out of
scope for this fix.

**Verification:**
- Data level: instrumented `lastsel` 0→1 at the repair (above).
- Headless guard: `tests/headless/test_hover_selection_repair.tcl` (logical
  selection survives the real motion sweep across the polygon; hover engages the
  polygon so the repair branch is reachable; gated by `hover_highlight`).
- Manual eyeball (pending): with `hover_highlight` on, the selection box stays
  drawn while the pointer crosses the dashed box.
