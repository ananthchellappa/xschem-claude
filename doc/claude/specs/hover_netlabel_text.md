# Spec — Hover-highlight outlines a net label's name TEXT, not just its pin

Status: IN PROGRESS 2026-06-28. Builds on the hover-highlight feature
(`xctx->hover_*`, `draw_hover()` in `callback.c`, `draw_hover_shape()` in `draw.c`).

## Motivation

When the mouse hovers over a net label (a `lab_pin`/`lab_wire`-style instance), the
dashed hover outline is drawn only around the tiny **attachment point** — the pin box
that connects the label to a wire — even though the user is pointing at the label's
visible **name text**. For ordinary symbols the body box is the right thing to outline,
but for a net label the body is a 2.5×2.5 stub and the meaningful, hit-able object is
the net-name text. Clicking the text already highlights the net; the hover cue should
match what the user is aiming at.

## Root cause

`draw_hover_shape()` (draw.c, `case ELEMENT`) always outlines the instance's *no-text*
bounding box `inst[n].xx1/yy1/xx2/yy2` — the symbol geometry without any texts. For a
net label that box is just the pin stub; the `@lab` text lives well outside it (see
`xschem_library/devices/lab_pin.sym`: a `B` pin box at the origin plus a `T {@lab}`
text drawn at an offset). `find_closest_element()` already lets the cursor *select* the
label when it is anywhere inside the full bbox (texts included), so hover detection
fires over the text — only the drawn rectangle is wrong.

## Behavior (normative)

- When the hovered instance's symbol **type** is a label/pin/bus-tap-class type
  (`IS_LABEL_SH_OR_PIN`: `label`, `ipin`, `opin`, `iopin`, `scope`, `show_label`,
  `bus_tap`) **and** the instance has at least one visible name text, the hover
  rectangle is drawn around the union bounding box of that instance's **visible texts**
  (the rendered net name) instead of the pin stub.
- "Visible texts" excludes `@spice…` annotator texts and hidden texts — the same set
  `symbol_bbox()` (select.c) folds into the with-texts bbox.
- All other instances (ordinary symbols) are unchanged: they keep outlining the
  no-text body box `xx1/yy1/xx2/yy2`.
- If a label/pin instance happens to have no visible text (e.g. an empty `lab`),
  fall back to the no-text body box so hover still shows *something*.

## Implementation

`src/draw.c`:

- New file-local helper `inst_text_bbox(int n, double *x1,*y1,*x2,*y2)` that walks the
  instance's symbol texts exactly as `symbol_bbox()` does (translate, skip `@spice`,
  honor hidden-text flags, `get_sym_text_size`, `text_bbox`, Cairo custom-font
  save/restore) and returns the union bbox plus a found-flag.
- `draw_hover_shape()` `case ELEMENT`: if the symbol type is `IS_LABEL_SH_OR_PIN`
  (type non-NULL) and `inst_text_bbox()` finds text, outline that bbox; otherwise the
  existing `xx1/yy1/xx2/yy2`.

No Tcl changes. No new `xschem` subcommand. Purely a drawing-side refinement of an
existing cue, so no test golden files change; verified by GUI hover over a label.
