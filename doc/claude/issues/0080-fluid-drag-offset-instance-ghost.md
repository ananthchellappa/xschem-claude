# Issue 0080 — fluid drag draws a duplicate instance "ghost" at 2× the drag displacement

**Opened:** 2026-07-06
**Status:** FIX APPLIED (working tree, uncommitted) — root cause confirmed by
windowed runtime trace. Regressions green.
**Affects:** interactive click-drag move of an instance with `fluid_editing` on and
attached wires (the fluid live-reroute path). Not observed in a plain non-fluid move.
**Severity:** low-med — cosmetic (no data/netlist effect) but visually confusing:
two instance images on every drag.
**Branch:** `fluid-editing`.
**Related:** issue 0079 (grey follow-wires seen in same gesture);
[[nice-drag-rerouting]]; `draw_temp_symbol` (`draw.c:958`); the fluid live-commit
tail in `move.c` (`:3078-3097`).

---

## 1. Observed (real-window feel test)

Launched `src/xschem --script src/cadence_style_rc --logdir /tmp`, opened
`tests/from_user/before_1.sch`, LMB-click-drag on **R18**.

Two instance images appear during the drag:

- The **real** R18 (full: value/name labels, cyan pin numbers, red pin squares)
  tracks the mouse correctly at the drag displacement **δ**.
- An **extra greyed-out** R18 (symbol outline + pin boxes only, drawn in the
  selection colour) appears at **2·δ** — i.e. one full displacement *beyond* the
  real instance.

User's exact characterization: grab-and-move from (0,0) to (5,0) with LMB held →
ghost is drawn at (10,0). The ghost offset always equals **twice** the pointer
displacement from the press point.

Screenshot on file (yellow arrow marks the 2× ghost).

**Correction to first draft of this issue:** this is NOT the ordinary pre-existing
move rubber-band (that draws a single ghost at 1·δ while the real instance stays
put). Here the real instance is *committed live* at δ (fluid Phase II), AND a second
image is drawn at 2·δ. It is a fluid-mode double-draw bug.

## 2. Root cause (CONFIRMED by windowed runtime trace)

The 2δ ghost is drawn by `draw_selection(gc[SELLAYER], …)` reached from **`draw()`
(`draw.c:6137`)** — i.e. from an **external full redraw** (window Expose, hover,
crosshair, `xschem redraw`) that fires **between** fluid RUBBER frames. It is NOT a
`move_objects` seam bug (that seam never triggers an external redraw, which is why
the static read looked coincident).

In that between-frames window:
1. The instance geometry is already **live-committed** to origin+δ
   (`move.c:2968` `inst.x0 = rx1 + deltax`).
2. `xctx->deltax` has been **restored to δ** by the live-commit tail (`move.c:3096`)
   so the eventual interactive `END` (`move_objects(END,0,0,0)`, which consumes the
   accumulated delta) still works.

So when an external `draw()` repaints the selection overlay, the ELEMENT case
(`move.c:512`) computes `xoffset = rx1 - inst.x0 + deltax`; with the instance
committed (`rx1 == inst.x0 == origin+δ`) and `deltax == δ`, `xoffset = δ`, and
`draw_temp_symbol` (`draw.c:993`) draws the symbol at `inst.x0 + δ = origin + 2δ`.

The live-commit tail (`move.c:3092`) *does* zero δ around **its own**
`draw()`/`draw_selection` (ghost correct on that frame), but restores δ afterward —
so any redraw in the gap re-adds it.

**Trace evidence** (windowed, res + attached riser, drag +40 in x; forcing a redraw
mid-drag):
```
COMMIT_NOW tail: deltax=40 ... (instance committed to inst.x0=40)
  GHOSTDRAW inst.x0=40 deltax=0  drawpos=40   <- tail's own draw: coincident, correct
=== force a redraw mid-drag (mimics GUI Expose) ===
  GHOSTDRAW inst.x0=40 deltax=40 drawpos=80   <- THE 2δ ghost (origin 0 + 2*40)
```

## 3. Fix (APPLIED — `src/move.c`, uncommitted)

Make `draw_selection()` a thin wrapper that zeroes the move-delta while the geometry
is live-committed (`fluid_reroute_dirty`), delegating to a renamed static
`draw_selection_impl()` (body byte-for-byte unchanged):

```c
void draw_selection(GC g, int interruptable)
{
  if(xctx->fluid_reroute_dirty) {
    double sv_dx = xctx->deltax, sv_dy = xctx->deltay;
    xctx->deltax = 0.0; xctx->deltay = 0.0;
    draw_selection_impl(g, interruptable);
    xctx->deltax = sv_dx; xctx->deltay = sv_dy;
  } else {
    draw_selection_impl(g, interruptable);
  }
}
```

- `fluid_reroute_dirty` is set only at the fluid live-commit (`move.c:3086`, requires
  `fluid_editing` on at START) and cleared by `fluid_reroute_discard()` /
  at START ⇒ when `fluid_editing` is off it is never set ⇒ **default-off byte-identical.**
- Wrapper (vs inline zero) guarantees the restore across every early-return in the
  body (interruptable resume, tiled-fill fast path).
- Post-fix trace: the mid-drag redraw logs `drawpos=40` (coincident), ghost gone.

**Verification:** incremental `make` clean; `run_wireedit.sh` → ALL PASS (37 incl.
test 33 release==stepwise byte-identical → committed geometry unchanged);
`test_fluid_editing.tcl` (windowed) → ALL PASS (26 checks).

## 4. Repro

1. `src/xschem --script src/cadence_style_rc --logdir /tmp`
2. Open `tests/from_user/before_1.sch`, `fluid_editing` on.
3. LMB-click-drag R18 by a few grid steps (hold LMB).
4. Observe: real R18 at δ, greyed duplicate R18 at 2·δ.
