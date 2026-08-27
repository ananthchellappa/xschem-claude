# 0858 - the waveform viewer's box-zoom rubber rectangle is not drawn while a simulation is running

**Status:** OPEN, **user-reported, NOT yet reproduced by me**. Filed 2026-08-26.
Cosmetic — the zoom itself works.

## What the user sees

In the waveform viewer, **while a simulation is still running**: RMB
press-and-drag inside the plot body draws **no rubber rectangle**. Releasing
still zooms to the dragged box, correctly. Once the run finishes the rectangle
is presumably drawn again (not stated; worth confirming).

Reported alongside the confirmation that [0852](0852-get-raw-value-has-no-lower-bound-so-a-zero-point-database-sigsegvs-raw-pos-at.md)
is fixed — moving the cursor over a trace mid-run no longer kills xschem. This is
what the user found once the crash stopped hiding it.

## The code, and what it is NOT

`src/callback.c`, the RMB interior-drag arm (`waves_callback`, after `finish:`):

```c
  if(event == MotionNotify && (state & Button3Mask) && (xctx->ui_state & GRAPHPAN) &&
     !xctx->graph_marker_drag &&
     !xctx->graph_axis_drag &&
     xctx->graph_master >= 0 && !xctx->graph_left && !xctx->graph_top && !xctx->graph_bottom) {
```

Each motion erases the previous outline through `xctx->gctiled` (which restores
from `save_pixmap`) and strokes the new one in `xctx->gc[SELLAYER]`. The
ButtonRelease arm erases the last one before the zoom redraw.

**Eliminated by reading the source — these are NOT the cause:**

* **The guard has no data term.** Not one of its six conjuncts mentions
  `allpoints`, `npoints`, `sim_type` or `raw`. A zero-point database cannot
  fail it.
* **`graph_master` is geometry, not data.** `waves_selected()`
  (`src/callback.c`) sets it purely from `POINTINSIDE` against the graph rect's
  own coordinates; nothing about the loaded database reaches it.
* **`gr->x1/x2/y1/y2`, which the clamp uses, are geometry too.** `setup_graph_data`
  (`src/draw.c`) derives them from `gr->rx1..ry2` plus margins. They cannot go
  degenerate or NaN because a dataset is empty, so the clamp cannot collapse the
  rectangle to nothing.
* **`setup_graph_data` still runs during the drag.** It is the first statement
  inside the master-graph block, ahead of the `goto finish` that GRAPHPAN takes,
  so `gr` is populated on every motion event of the gesture.
* **Not 0852.** That was a SIGSEGV on `raw pos_at`, fixed and pinned; this
  gesture does not call it and the process survives.

## The standing hypothesis, and why it is only that

The rubber band is painted **outside** the normal draw path and lives only in
the window, not in `save_pixmap`. **Anything that repaints the canvas erases it.**
That is the issue-0011 class this tree has hit before (see the window-only
overlay repair note: selection / scope / hover / diff overlays all had to be
re-struck inside the erase block or they vanished).

So the question is *what repaints the viewer during a run*, and I did not find
it. What I did find, and it is suggestive rather than conclusive:
`execute_fileevent` (`src/xschem.tcl`) reads the simulator pipe **1024 bytes at
a time** and forks `exec ps -o state= -p <pid>` on **every** readable event. That
is a blocking `exec` in the event loop, firing constantly while ngspice writes
output. It would explain queued/coalesced motion events and general sluggishness;
it does not by itself explain an erased outline.

## Reproduction, which is the actual next step

Not headless-reproducible as filed: there is **no Tcl seam for
`xctx->graph_rubber_active`** (`grep graph_rubber src/scheduler.c` → nothing), so
a script cannot ask whether the band was struck. Two ways in:

1. **Pixels.** Drive a Button3 press + motion through `xschem callback` on `:99`
   with a real background job writing to the raw, and diff the canvas mid-drag
   against the same drag with a finished raw. `tests/headless/test_expose_repaint`
   already does canvas differencing and is the model.
2. **A seam.** Expose `graph_rubber_active` read-only under `xschem get`, which
   makes this and the axis-drag twin testable for good. Cheap, and probably worth
   doing regardless.

⚠ Do **not** assume the finished-run case works until it is measured. The user
reported the failing case only; "it comes back afterwards" is my inference from
their wording, not their statement.

## Acceptance if fixed

1. Mid-run RMB drag paints a visible rubber rectangle that tracks the pointer.
2. **Positive twin.** The same drag on a finished simulation is unchanged, and
   the zoom applied on release is identical in both cases — the fix must not
   move the zoom math, which already works.
3. The axis-region drag zoom's band (issue 0190), the twin of this one and using
   the same gctiled-erase / SELLAYER-draw pair, behaves the same way in both
   states — a fix that lands on one and not the other is the shape this tree
   keeps repeating.
4. The release-side erase still runs, so no ghost outline survives the zoom.
5. Sabotage: whatever repaint is found to be the cause, reinstate it and confirm
   row 1 reds.
