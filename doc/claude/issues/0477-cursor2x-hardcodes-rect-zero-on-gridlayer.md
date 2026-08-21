# 0477 — `xschem set cursor2_x` hard-codes rect ZERO on GRIDLAYER

Status: **OPEN. MEASURED on this tree before and after S11, DELIBERATELY NOT
FIXED.** Filed by the S11 crew (2026-08-20).
Related: 0478 (the third gate), 0480 (which window the graph path uses), spec
`doc/claude/specs/op_annotation.md` §4.7 / step S11.

## What it is

`scheduler.c`'s `xschem set cursor2_x <t>` arm resolves the cursor against
`&xctx->rect[GRIDLAYER][0]` **specifically** — rect index zero — not against
"the graph rect", and not against the set of graph rects that
`graph_cursor_dbs()` (`draw.c`) is perfectly willing to fan out over:

```c
if(has_graph) {                              /* S11; was rects[GRIDLAYER] > 0 */
  Graph_ctx *gr = &xctx->graph_struct;
  xRect *r = &xctx->rect[GRIDLAYER][0];      /* <-- rect ZERO, hard-coded */
  if(r->flags & 1) {                         /* <-- and it must BE a graph */
```

GRIDLAYER is an ordinary drawing layer as well as the graph layer, so a plain
rectangle drawn there — a box round a note, a highlight, anything — takes index
0 if it was created first and **silently disables cursor-B annotation for every
real graph on the sheet**.

## Measured — BEFORE S11 (Measure agent, fresh process, verbatim)

    S11BEFORE E1 nongraph rect at idx0    : raw annot={0 0 -1}  v(d)=0  gm=0

with the fixture line the same agent recorded beside it:

    E0 verbatim: rects=2  rect0 flags=""  rect1 flags="graph"

i.e. a plain rect at index 0 and a **real, node-set, `fullyzoom`'d** graph at
index 1, cursor B enabled, a 5-point transient raw annotated, `set cursor2_x
3e-9` issued. `annot_p` is still `update_op()`'s point 0, `annot_x` was never
written, the sweep index was never resolved, and every `xschem raw value <v> -1`
still answers point 0 — while point 3 of that raw genuinely holds `v(d)=3`.

## Measured — AFTER S11 (write-up agent, same script, shipped binary
`2f41eadd6452dd682863f51659425a64`)

    S11AFTER  E0 rects=2  rect0 flags=""  rect1 flags="graph"
    S11AFTER  E1 nongraph rect at idx0    : raw annot={0 0 -1}  v(d)=0  gm=0

**Unchanged, on purpose.**

## Why S11 did not fix it

S11's acceptance clause is that a schematic *with* a graph must behave exactly
as it does today — the brief weights that regression above the new feature. The
new direct arm therefore fires only when **no** rect on GRIDLAYER carries
`flags & 1`; here one does, so the shipped block runs, including this defect.

Decision **D1**, ladder rung **L2** (least surprising, smallest blast radius):

* **Chosen** — trigger the direct arm on "no graph OBJECT anywhere", i.e. a scan
  for `flags & 1` over `rects[GRIDLAYER]`.
* **Rejected (a)** — trigger on `rects[GRIDLAYER] == 0`. A plain rectangle on
  GRIDLAYER would then block the graphless path too, and a schematic with
  nothing plotted is exactly the situation the step exists for. Row **T21** of
  `tests/headless/test_op_annot.tcl` discriminates the two.
* **Rejected (b)** — trigger whenever any of the three shipped gates is false.
  That silently *repairs* this issue and 0478 as a side effect, which is a
  user-visible change to graph-present behaviour that no one ratified.

## Pinned, so a repair reds a named line

Row **T14** of `tests/headless/test_op_annot.tcl` asserts the **current, wrong**
behaviour: plain rect at index 0 + real graph at index 1 + cursor B on ⇒
`annot` stays `{0 0 -1}`. Whoever fixes this will red T14; that is the point.

## Suggested repair, when someone takes it

Scan for the first rect with `flags & 1` and hand *that* one down (the scan S11
already added for `has_graph` computes the index for free), or better, hand
`graph_cursor_dbs()` the whole set the way `draw_graph()` does. Either way the
window question of issue **0480** has to be answered at the same time, because
the shared `xctx->graph_struct` that goes with rect 0 will no longer match the
rect that resolved the cursor.
