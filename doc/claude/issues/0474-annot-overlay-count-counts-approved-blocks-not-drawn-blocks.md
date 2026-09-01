# 0474 — the `annot_overlay_count` seam counts blocks the reader APPROVED, not blocks DRAWN

Status: **OPEN, measured, NOT fixed.**
Filed by the S9b write-up agent from the S9b adversary pass (Verify-C).

## What the seam actually measures

`xschem get annot_overlay_count` is the monotonic seam that rows **O13**,
**O14** and **O17** of `tests/headless/test_op_annot.tcl` lean on, and it is the
**only** coverage the screen back end can have (`draw()`'s whole body is inside
`if(has_x)`, `draw.c:10377`).

It bumps inside `get_annot_overlay()`. In `draw.c`, every one of

* the `draw_single_layer` early return,
* the `enable_layer` early return,
* the `size * FONTWIDTH * mooz < 1` zoom-cull return,

happens **after** that bump. `psprint.c`'s `!enable_layer` return likewise.

So the seam cannot distinguish *"drew it"* from *"decided to draw it and then
culled it"*. A sabotage that corrupts or removes the `draw_string` call
**after** `get_annot_overlay()` returns would pass every count row.

## Blast radius

* The **export** back ends are also covered by the suite's SVG and PS **label
  assertions**, which read the rendered bytes — so a broken draw there does red.
* The **screen** back end rests on this seam alone. That is the path a user
  looks at, and the path issue 0465 keeps out of every tier runner.

## Fix shape (not applied)

Move the bump to immediately **after** the successful `draw_string` (or add a
second `annot_overlay_drawn` counter beside it and assert both), so the screen
rows can tell approval from paint. Keep the existing counter if any row depends
on the approval semantics.

## Still open

Yes. Note it is only reachable as a *test* weakness, not a user-visible defect:
the culls it hides are correct behaviour. What it hides is a future regression.
