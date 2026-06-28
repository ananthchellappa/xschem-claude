# Issue 0028 — custom net-highlight color not applied to net-label / pin-name text

**Opened:** 2026-06-24
**Status:** ✅ RESOLVED 2026-06-24 (branch `fluid-editing`). `draw_hilight_net()` now, for a
custom-RGB style (`color_layer < 0`), briefly repoints the fallback layer's GC foreground
(symbol graphics + non-cairo text) AND `xctx->xcolor_array[col]` (cairo text) to the style's
exact pixel around the `draw_symbol()` call, then restores both (per instance, so multiple
distinct custom colors each render correctly). New shared helper
`resolve_hilight_style_rgb()` caches the pixel→RGB once (`hilight.c`, extern in `xschem.h`);
`draw.c`'s `hilight_cairo_set_source()` was refactored to call it. Width/dash/angle remain
wire-only; only the color is applied to symbols.
**Affects:** `draw_hilight_net()` instance loop (`src/hilight.c`); `get_color()` fallback;
the cairo text path (`set_cairo_color()` → `xcolor_array`, `src/draw.c`).
**Severity:** low (cosmetic) — highlight color was correct on the wire but wrong on the
net-label / pin-name text for **custom-RGB** styles only; layer-index/default styles were
always consistent.
**Branch:** `fluid-editing`. See [[net-hilight-styles]]. Spec §9 updated.

---

## 1. Symptom

With a `net_hilight_style` row using a **custom** color (an X name or `#rrggbb`, e.g.
`{1 yellow 4 {10 8} 0 0 none 0}`), highlighting a net drew the **wire** in yellow but the
net-label and pin-name **text** in a red/orange fallback color. The user first noticed it on
*dashed* styles — incidental, because their dashed rows happened to use color names; the real
discriminator is custom-color vs layer-index, not dash-vs-solid.

A layer-index style (e.g. `{0 4 ...}`) rendered both the wire and the label text in layer 4's
color — consistent. Only custom colors diverged.

## 2. Root cause

Pass 1 of the feature decoupled "highlight style" from "layer color" and gave **wires** a new
pixel-based render path (`get_hilight_pixel()` → exact style pixel, via `gc_hilight`/cairo).
But the **symbol/instance** render path was left on the legacy *layer-index* path:

```c
/* src/hilight.c, draw_hilight_net() instance loop (before fix) */
int col = get_color(xctx->inst[i].color);   /* a LAYER index */
draw_symbol(ADD, col, i, c, 0, 0, 0.0, 0.0);
```

`get_color()` must return a valid **layer index** because it also feeds layer-indexed
consumers (SVG/PS export, ngspice plot colors). For a custom-RGB style there is no layer, so
it returns a *sane fallback layer*:

```c
int get_color(int value) {
  NetHilightStyle *s;
  if(value < 0) return (-value) % cadlayers;
  s = get_hilight_style(value);
  if(s->color_layer >= 0) return s->color_layer;
  return cadlayers > 5 ? 5 : cadlayers - 1;   /* <-- lossy: drops the custom color */
}
```

`draw_symbol()` then colors the symbol — graphics through `gc[col]`, and (under cairo) the
**text** through `set_cairo_color(col)` → `xctx->xcolor_array[col]` — i.e. fallback layer 5,
not the style's pixel.

So the same logical "highlight color" had **two representations consumed by two paths**: the
wire used the lossless *pixel*; the symbol used a *lossy layer-index projection*. They agree
by construction for default/layer-index styles and diverge only for custom RGB.

## 3. Fix

In the instance loop, for custom styles, borrow the fallback layer's color slots for the
duration of the `draw_symbol()` call (covers both cairo text and Xlib graphics), then restore:

```c
NetHilightStyle *st = (val >= 0) ? get_hilight_style(val) : NULL;
if(st && st->color_layer < 0 && has_x) {
  resolve_hilight_style_rgb(st);              /* st->cr/cg/cb cached once */
  save_xc = xctx->xcolor_array[col];
  XSetForeground(display, xctx->gc[col], st->color);
  xctx->xcolor_array[col].pixel = st->color;
  xctx->xcolor_array[col].red = st->cr; .green = st->cg; .blue = st->cb;  /* (expanded in src) */
  custom = 1;
}
... draw_symbol(...) + END flushes ...
if(custom) { XSetForeground(display, xctx->gc[col], xctx->color_index[col]);
             xctx->xcolor_array[col] = save_xc; }
```

Save/restore is per-instance, so two nets with different custom colors each render correctly.

## 4. Teaching value — how the bug arises, and the smells

This is a textbook **incomplete abstraction migration** with a **lossy adapter at a boundary**,
hidden by **coincidental correctness**.

- **Primitive Obsession / overloaded scalar.** One `int` ("color value") means *three* things
  depending on sign and context: a sim **logic level** (`< 0`), a **style index** (`>= 0`),
  and — historically — a **layer index**. There is no single authoritative type for "the
  color to draw this highlight in." Consumers each reach for a different adapter
  (`get_color()` → layer, `get_hilight_pixel()` → pixel), and nothing forces them to agree.

- **Lossy projection presented as a total function.** `get_color()` *must* return a layer
  index for its other callers, so for the new richer concept (custom RGB) it returns a
  *plausible* fallback. A fallback that is a real, valid color is more dangerous than an
  obviously-wrong sentinel: it looks intentional, so it survives review and eyeballing.

- **Partial refactor / Shotgun Surgery not finished.** Adding the richer representation
  (custom pixel) required updating *every* consumer of the old one. The wire path was
  migrated; the symbol path was not. The gap was even **documented as a non-goal** (spec §9:
  "symbols keep the fallback layer color… a possible follow-up"). A documented non-goal that
  contradicts the user's mental model ("the highlight is one color") is a latent bug report.

- **Coincidental correctness defeats happy-path testing.** For the default table and any
  layer-index style the two paths produce the *same* color by construction, so every test and
  every screenshot that used default/layer colors passed. The divergence is only observable
  with a value where the two projections differ — a **custom** color. The test surface didn't
  include the one input that distinguishes the code paths.

The general lesson: **when a refactor splits one render path into two (wire vs symbol) that
must agree, the seam needs a test that pins them together — exercised with an input that makes
them disagree if the seam is wrong.**

## 5. Preventing it with TDD

The decoupling has an invariant worth stating up front, *before* writing the rendering code:

> "All elements of a single highlighted net (wire body, junction dots, net-label text,
> pin-name text) render in the **same** color — the style's resolved color."

TDD turns that sentence into a failing test first:

1. **Choose the discriminating input.** Use a **custom** `#rrggbb` (not a layer name), so the
   lossless pixel and the lossy layer projection cannot coincide. This is the input that makes
   coincidental correctness impossible — the heart of the technique.
2. **Assert at the observable boundary (pixels).** Render a highlighted custom-color net to a
   PNG and sample the pixel under the label text; assert it equals the style RGB, not the
   fallback. Tk can sample pixels without an external image lib:

   ```tcl
   # tests/headless (GUI) — RED before the fix, GREEN after
   set STYLE {{0 "#ffcc00" 4 {10 8} 0 0 none 0}}
   set net_hilight_style $STYLE
   xschem update_net_hilight_style
   xschem hilight_netname -style 0 MYNET
   xschem zoom_full; xschem redraw
   xschem print png $out 900 400
   set im [image create photo -file $out]
   # sample several pixels across the label-text bbox; at least one must be the style color
   assert_pixel_color $im $label_bbox {255 204 0}     ;# #ffcc00, NOT the fallback layer
   ```
3. **Cover the seam, not just one side.** Separate assertions for the wire pixel and the
   label-text pixel; both must equal the style color. (Pre-fix: wire GREEN, text RED.)
4. **Property generalization.** Parameterize over {layer-index style, custom-RGB style} ×
   {solid, dashed}; the invariant "wire color == label color == style color" must hold for all
   four. The custom-RGB cells fail RED before the fix.

A cheaper, non-visual variant if pixel sampling is undesirable: expose an introspection that
returns the *resolved pixel actually used* for each element of a highlighted net, and assert
`wire_pixel == label_pixel == style_pixel`. Either way the principle is the same — **assert the
cross-path color invariant with an input that breaks coincidental agreement.**

## 6. Verification done

Before/after PNG (GUI, `DISPLAY=:0`): a custom `yellow` net's label went **red → yellow**; a
layer-index style was unchanged (green label + green wire); three distinct custom colors
(red/yellow/cyan) each colored their own label correctly. Build clean. An automated headless
pixel-sampling regression per §5 is the recommended follow-up (not yet committed).
