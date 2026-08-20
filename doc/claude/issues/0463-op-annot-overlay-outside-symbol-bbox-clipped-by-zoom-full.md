# 0463 — the S9 OP-annotation overlay is outside symbol_bbox(), so zoom-full and the auto-viewport export clip it

- **status**: OPEN, measured, deliberately not fixed in S9
> ⚠ **THE CODE THIS ISSUE DESCRIBES IS NOT IN THE TREE.** Step S9 (attempt 1) was
> implemented in full, went green on 192 headless / 195 display checks and nine
> sabotage variants, and was then **REVERTED** because its cache renders the
> previous file's numbers after a schematic reload — issue **0466**, invariant I3.
> The implementation is preserved as `doc/claude/issues/0466-attempt-1-reverted.patch`.
> Everything below was measured against that patch and is binding on the retry.
- **found**: S9 (the draw-time overlay), doc/claude/specs/op_annotation.md
- **subject**: src/actions.c `get_annot_overlay()`, src/select.c `symbol_bbox()` (:671),
  src/actions.c `calc_drawing_bbox()` (:4516)

## What

The overlay block is anchored at `xctx->inst[n].xx2 + annot_dx`, `yy1 + annot_dy` and is
rendered directly by the three back ends. It is **not** folded into `symbol_bbox()`, so
`xctx->inst[].x1..y2` — the only rectangle `calc_drawing_bbox()` reads — does not contain it.

Consequences, in the order a user meets them:

1. Turn annotation on (`6`), press zoom-full: the drawing fits the schematic, and the
   rightmost devices' blocks hang off the right edge of the view.
2. `xschem print svg <f>` / `print ps <f>` in the **auto-viewport** form (no explicit
   `w h x1 y1 x2 y2`) sizes the page from the same rectangle, so the same blocks are
   clipped in the exported file.

The 10-argument viewport form of `xschem print` is unaffected — the caller states the
rectangle — which is why every S9 test row uses it and none of them sees this.

## Why it was not fixed in S9 (decision D8, L2)

Folding the overlay into `symbol_bbox()` fixes both symptoms and would additionally give a
headless oracle (`xschem instance_bbox`). It was rejected because `symbol_bbox()` is reached
from the **netlist and save** paths (save.c:4301 warns it can reach
`prepare_netlist_structs()`) and is run over every instance by `update_all_sym_bboxes`. A
per-instance Tcl call there is (a) a re-entrancy hazard against `translate()`'s single static
result buffer (token.c:4604) and (b) a per-instance `op_annot::text` cost on paths that never
draw anything. The accepted consequence is the clipping above.

## What a fix would have to do

Either compute the block's extent **without** calling Tcl (impossible: the row count and the
longest row are what `op_annot::text` returns), or give `symbol_bbox()` a mode flag so only
the draw/zoom callers pay, or extend `calc_drawing_bbox()` alone — it is the one caller that
actually wants the padded rectangle, and it already calls `annot_show_sync_cache()`.
The last is the smallest and is the suggested route.
