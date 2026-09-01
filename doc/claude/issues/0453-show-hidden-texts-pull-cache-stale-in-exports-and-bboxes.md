# 0453 — `show_hidden_texts`' pull cache is one step behind in the export and bbox paths

Status: OPEN, measured, deliberately NOT fixed by S7.
Filed by: S7 (annotation classes), which had to route around it.

## What

`xctx->show_hidden_texts` is a PULL cache. It is refreshed at exactly three
places — `actions.c` (calc_drawing_bbox), `draw.c` (draw) and `xinit.c`
(startup) — while `symbol_bbox()` (select.c), `svg_draw()` (svgdraw.c) and
`create_ps()` (psprint.c) all READ it and none refresh it. `svg_draw()` contains
no `tclgetboolvar` at all.

Measured consequences on this tree:

* **The first export after any Tcl-side change renders with the OLD value**, in
  both directions and for both formats. Three SVG exports in a row after
  `set ::show_hidden_texts 1` give `0 1 1`; three PS exports give `0 1 1`;
  reversed (1 -> 0) gives `1 0`.
* **`xschem update_all_sym_bboxes; xschem redraw` is one toggle behind.** That
  pair is the shipped idiom at `src/xschem.tcl` (the View > "Show hidden texts"
  checkbutton). Measured across the four steps: `0 / 0 / 0 / 161` — only the
  SECOND update is right, because the bboxes are computed from the stale cache
  and only the following `redraw` pulls the new value.
* `xschem set show_hidden_texts N` writes only the C field and the next pull
  silently discards it, which is why the GUI never calls that setter.

## Why S7 did not fix it

Fixing it changes WHEN `hide=true` texts appear in exports for every existing
library symbol — a user-visible behaviour change, and S7's brief forbids mixing
one into the refactor commit. Decision D5.

## What S7 did instead

The new `annot_show` mirror deliberately does NOT copy this pattern:
`annot_show_sync_cache()` (actions.c, shaped after the P6 `pin_names_sync_cache`
precedent) is called at every bulk visibility evaluation, including
`xschem print` and `xschem update_all_sym_bboxes`, and `xschem set annot_show`
writes the Tcl var too so no later pull can undo it. Rows L17 and L18 of
`tests/headless/test_op_annot.tcl` assert the annotation mask is NOT stale;
there is still no row asserting the same for `show_hidden_texts`, because it
would be red.

## Fix sketch

Fold both variables into one sync entry point and call it where
`pin_names_sync_cache()` is already called (draw, calc_drawing_bbox,
`xschem print`, `xschem update_all_sym_bboxes`, startup, CLI batch print), then
make `xschem set show_hidden_texts` push to Tcl as well. Expect the goldens of
any export test that toggles visibility to move by one export.
