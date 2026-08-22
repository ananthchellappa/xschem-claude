# 0605 — the OP-annotation overlay lands on top of the symbol's own texts, and the block is partly unreadable

STATUS: **OPEN, DEFERRED BY THE USER 2026-08-22 — direction chosen, timing later.**

> *"Not an issue for now. Later, as we continue building, we will provide a means
> for the user to select such annotation and move it. Good that it was caught."*

So the fix is **not** a cleverer automatic anchor. It is to make an annotation
block a thing the user can **select and drag**, and the auto-placement only has
to be a reasonable starting point. That rules out the "measure the symbol's own
text extents" direction below as the primary answer, and it makes issue **0468**
(the overlay's anchor/size/layer/offset are compiled-in constants) part of the
same piece of work.

⚠ Note the asymmetry this exposes between the two carriers of §4.4. The
`annotate_params` **symbol** is an ordinary instance and is already selectable
and movable today; the draw-time **overlay** is painted by C and is not
selectable at all. Whatever ships has to give the overlay that property, or make
the symbol carrier the route for anyone who wants to move blocks.

Originally: **OPEN — seen, 2026-08-22.** Found by eye, in the first genuine
end-to-end run of the whole feature: a shipped sky130 bench, netlisted by xschem,
simulated by real ngspice-42, annotated from the real `.raw`.
Related: 0468 (the overlay's constants are compiled in), 0475/0476, ruling D9/D9b.

**No test could have found this.** Every guardian in `test_op_annot.tcl` asks
whether a label was *drawn* — `opa_q_n` counts occurrences of `id  =` in an SVG,
`opa_l_seen` regexes for a marker. Two strings drawn at the same coordinates both
count as drawn. This is the entire justification for the `look` ledger.

## What was run

```
xschem netlist  on  sky130A/xschem_libs/sky130_tests/test_nmos          (17 FETs)
+ 102 save cards generated from op_annot::devpath + the D9 descriptor
/usr/bin/ngspice -b   ->  rc=0, ZERO checkvalid warnings, 8.2 MB raw
xschem annotate_op    ->  sim_type=op, and the six rows carry real numbers
```

```
M1  nfet_01v8_lvt   id = 515.8u  gm = 521.1u  gds = 53.83u  vgs = 1.72  vth = 0.5872  vds = 1.641
M2  nfet_01v8       id = 451.1u  gm = 529.9u  gds = 51.47u  vgs = 1.73  vth = 0.7818  vds = 1.661
M3  nfet_03v3_nvt   id = 639.4u  gm = 197.1u  gds = 19.07u  vgs = 3.201  vth = -0.1713 vds = 3.102
M7  nfet_20v0       id = 1.611m  gm = 2.959m  gds = 129u    vgs = 1.799  vth = 0.8521  vds = 0.8391
```

Cross-check: the bench's own `Vd1` ammeter reads **515.8u**, the same number the
overlay prints for M1's `id`. The values are right.

## What is wrong

The block is anchored at the instance bbox's **right edge** (+5, 0) — and that is
exactly where a sky130 FET symbol already prints its own texts: the model name,
`W=…`, `L=…`, `nf=…`, the `svt`/`LVT` marker, and the `B`/`S` pin labels. They
overprint. Rendered at density 200 the middle four rows read as

```
gmfet_0528.1lvt          <- `gm = 528.1u` over `nfet_01v8_lvt`
gds = B53.83u            <- over the B pin label
vgs = 1.72  /  nf=1      <- superimposed
svthx=10.5872            <- `vth = 0.5872` over `svt` and `L=0.15`
```

Only `id` (above the symbol's text block) and `vds` (below it) are cleanly
legible. **Four of the six rows are compromised on the most ordinary device in
the PDK.**

## Why it is not the same as 0475

0475 is about the sky130 symbols' own **annotation** texts (`id=@spice_get_node
…`), which S10b tokened `hide=true` so the overlay's copy is the only one. Those
are correctly hidden here. The texts being collided with are the symbol's
**parameter** texts — the model, the geometry — which a schematic must keep
showing at all times. Hiding them is not an option.

## Directions, none chosen

* **Move the anchor.** Left of the bbox, or below it. Cheapest; trades one
  collision class for another (wires, neighbouring instances).
* **Offset past the symbol's own text extents.** Measure the instance's drawn
  text bbox and start the block after it. Correct-looking, and needs the drawn
  extents of texts the overlay does not own.
* **Paint an opaque background rectangle** behind the block. Makes the block
  readable wherever it lands, and hides whatever is under it — acceptable for
  something that only appears while annotation is on.
* **Make it settable per PDK.** Issue **0468** already asks whether the anchor,
  size, layer, offsets and font should be user-settable rather than compiled-in
  constants with `annot_dx`/`annot_dy` as the only escape. This defect is the
  strongest argument yet for yes.

## Reproduction

The deck, the raw, the SVGs and the PNGs are in the session scratch dir; the
three scripts that build them (`step1_netlist.tcl`, `step2_annot.tcl`,
`step4_zoom.tcl`) are the whole recipe and are ~25 lines each. The only manual
step was adding one `.lib …/sky130.lib.spice tt` line to the netlist, because the
bench expects `$::SKYWATER_MODELS` from the workarea rc.
