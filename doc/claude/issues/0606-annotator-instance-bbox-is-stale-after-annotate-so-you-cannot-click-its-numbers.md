# 0606 — the annotator's instance bbox is stale after `annotate_op`, so you cannot click the numbers it prints

STATUS: **OPEN — measured 2026-08-22**, on the shipped `devices/annotate_params`
carrier with a real ngspice raw. Found while paying the `annotate_params_on_tb_bandgap`
look debt. Related: **0605** (the user's direction is "select such annotation and
move it"), 0468, spec §4.4 (Carrier 1).

**This is the defect that blocks the user's stated plan for 0605.** An annotation
you cannot click is an annotation you cannot drag.

## Measured

Two `devices/annotate_params` instances placed on a copy of
`sky130_tests/test_nmos`, `ref=M1` and `ref=M2`, then a real ngspice-42 raw
annotated onto the sheet:

```
PRE  annot1 bbox = 620 -172 636 -150            (16 x 22 — the EMPTY carrier)
POST annot1 bbox = 620 -172 636 -150            (unchanged, after annotate_op)
```

The block it now draws is six rows, `id = 515.8u` … `vds = 1.641`, roughly
86 x 113 in schematic units. The bbox is one seventh of its width and one fifth
of its height, and it sits at the top-left corner of what is drawn.

Hit-testing follows the bbox, not the ink:

```
xschem select_at 628 -160  -> {annot1}     the carrier's own empty origin
xschem select_at 660 -140  -> {}           ON the printed `gm  = 521.1u`
xschem select_at 680 -100  -> {}           ON the printed `vds = 1.641`
```

Two of three clicks land on visible, legible numbers and select **nothing**.

## It is staleness, not a design limit — one round-trip fixes it

```
before setprop : 620 -172     636 -150
xschem setprop instance annot1 ref M1        (a no-op: same value)
after  setprop : 620 -173.485 705.907 -60.6082
xschem select_at 660 -140  -> {annot1}       now it selects
```

`setprop` recomputes `symbol_bbox()` (`scheduler.c:675`/`:692`/`:1011`);
`annotate_op` does not. So the geometry the selector needs is computable and is
simply never recomputed when the thing that changed is the *value* the text
interpolates rather than the text itself.

⚠ The round-trip is not a workaround worth shipping: `setprop` **dirties the
schematic**, and invariant **I4** says annotation never modifies it. The fix has
to recompute the bbox without an edit — the same shape as S9b's
`annot_data_changed()` invalidation, and plausibly the same call site.

## What is NOT wrong, and it is worth recording

The carrier itself renders **correctly and legibly**:

```
M1
 id  = 515.8u
 gm  = 521.1u
 gds = 53.83u
 vgs = 1.72
 vth = 0.5872
 vds = 1.641
```

No clipping, no artifacts, no leftover ink from the blank state — the concern the
look debt was originally written about. And because the user chose where to put
it, it does **not** collide with the symbol's own texts the way the draw-time
overlay does (0605). On this evidence the symbol carrier is the better of the two
carriers for anyone who wants to place blocks deliberately — provided you can
select it, which is this issue.

`xschem get modified` is **0** across load + annotate + redraw, so I4 holds until
somebody reaches for the `setprop` workaround.

## Not yet checked

gf180 and IHP. gf180 needs its own bench run; IHP cannot be simulated on this box
at all (`psp103.osdi` targets OSDI v0.4, ngspice-42 here supports v0.3).
