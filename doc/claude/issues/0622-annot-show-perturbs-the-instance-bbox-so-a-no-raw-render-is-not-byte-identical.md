# 0622 — `annot_show` perturbs the INSTANCE BBOX, so a no-raw render is not byte-identical at fullzoom (and two sheets flip symbol level-of-detail)

STATUS: **OPEN — measured, NOT fixed.** Found by the adversary leg of the crew
that implemented [0614](0614-annot-chords-must-own-node-voltages.md) /
[0615](0615-node-voltage-colour-collides-with-op-block.md), 2026-08-22. It does
not refute either issue — no text is gained or lost — but it **narrows 0614's
own acceptance sentence**, which is why it is filed rather than footnoted.

---

## 0614's acceptance said this, and as written it is FALSE

> "With **no** raw loaded and `annot_show` 0, every existing schematic renders
> byte-identically to before the change (I7 regression guard)."

Measured after the change, no raw loaded, all 822 `.sch` in the tree rendered at
mask 0 and at mask 3 (mask 3 == pre-change geometry, because every annotation
text is visible there):

| render mode | byte-identical | differ |
|---|---|---|
| **fullzoom** (`xschem print svg f.svg W H`) | 763 / 822 | **59** |
| **fixed viewport** (explicit `x1 y1 x2 y2`) | 820 / 822 | **2** |

**Zero of the 59 gains or loses a single `<text>` element.** Nothing is blanked;
the page is framed differently.

Repro, verbatim, on the shipped tree:

```
xschem load xschem_library/examples/pump.sch
xschem set annot_show 0 ; xschem update_all_sym_bboxes ; xschem print svg a.svg 1200 900
xschem set annot_show 3 ; xschem update_all_sym_bboxes ; xschem print svg b.svg 1200 900
```

```
4831 pump_0.svg
4837 pump_3.svg
DIFFER            <- same 8 <text> elements in both, shifted ~15 units in y
```

(Re-measured by the write-up agent on the committed tree: `4831` vs `4837`,
`grep -c '<text'` = 8 in both.)

## Why

`symbol_bbox()` (`src/select.c:709`) skips a text whose **translated** value
starts with `@spice` — but with no raw loaded the translation is **empty**, so
the text used to contribute its degenerate anchor point to the instance bbox.
Since 0614 the same text is hidden by class before it is measured, so it
contributes nothing. `calc_drawing_bbox()` reads the cached `inst[].x1..y2`, and
`zoom_full` frames off that. Hence: fullzoom moves, a fixed viewport does not.

## The sharper half — two sheets change SYMBOL GRAPHICS, not framing

`draw.c:735/1044`, `svgdraw.c:796` and `psprint.c:1050` all carry the same
level-of-detail rule:

```
(inst.x2-inst.x1)*mooz < 3 && (inst.y2-inst.y1)*mooz < 3  ->  draw a placeholder rect
```

Because the instance bbox now depends on `annot_show`, **the placeholder decision
does too**. Measured at a FIXED viewport, no raw, deterministic over 3/3 runs
(`0 == 1` and `2 == 3`, 164-byte delta):

- `sky130A/xschem_libs/sky130_tests/test_nmos/schematic/test_nmos.sch`
- its `sky130_tests_ase` mirror

render **four instances as `l4` placeholder rectangles at mask 0** and as real
symbols (`l5` + `l15` strokes) at mask 3. Invisible at three screen pixels, but
it is `annot_show` reaching **symbol graphics** rather than annotation text, and
no row in `test_op_annot.tcl` section U guards it.

## Two ways to close it

1. **Make `symbol_bbox()` skip an untranslatable annotation text regardless of
   the mask** — i.e. move the existing `@spice`-prefix skip so it also fires
   when the class is hidden. Smallest change, makes the bbox mask-independent,
   and makes 0614's acceptance sentence true as written. Suspect this is right.
2. **Narrow the claim** to "at a fixed viewport", in 0614 and in the spec, and
   leave the bbox alone. Cheaper; leaves `annot_show` able to move a placeholder
   decision, which is the part that will surprise someone.

Not chosen here because the fix touches `select.c:709`, which is the
selectability seam as well as the drawing-bbox seam (row U23 depends on it), and
that is a measurement the 0614+0615 pass had no oracle for.

## Guardian to add with the fix

A row that renders one shipped sheet with **no raw** at masks 0 and 3 at
**fullzoom** and asserts byte-identity, plus one that asserts the `test_nmos`
placeholder count does not move with the mask. Section U has neither today.
