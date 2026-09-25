# Receipt A — item 2: `svgdraw.c` has the call shape and NOT the defect

Crew `measure:svgdraw`, dispatched from `cff55068`. `make -C src` rebuilt nothing, so every
in-tree figure is against committed code. `cadlayers = 22` in this configuration (measured:
22 `.lN` CSS classes in the export, and an instrumented probe printing `cadlayers=22` on all
5253 hits).

## Verdict: NO DEFECT

**Eight valgrind runs of `xschem print svg`, every one `ERROR SUMMARY: 0 errors from 0
contexts`.** Zero `Invalid read`, zero `Invalid write`, zero `N bytes after a block` lines.

* headless (`env -u DISPLAY`): `LCC_instances.sch`; `poweramp.sch` (86 instances, 36 pin
  labels); `cmos_example.sch` (50 instances, 21 pin labels); and a five-pass adversarial
  sweep on `LCC_instances` — `hide_symbols=2`, every net hilighted, a custom-RGB
  `net_hilight_style` with `color_layer < 0`, `lvs_ignore=1`, `color_ps=0`.
* a sixth pass with the Tcl `$svg_colors` list **truncated from 22 elements to 3** while
  `cadlayers` stayed 22 — the only other way garbage could enter the block.
* `DISPLAY=:99`: the same three sheets, all clean. The display exports are 1.9–2.8× larger
  (145357 / 391170 / 461892 bytes vs 77235 / 202467 / 165632) because `has_x` gives a real
  viewport, so the two arms are genuinely different code paths and **both** are clean.

## The instrument was proved sharp, not assumed

In a scratch clone the crew **deleted the one-line 1353 fix** from `set_ps_colors()` and ran
the identical valgrind spelling on the identical sheet:

```
==1287377== Invalid read of size 4
==1287377==    at set_ps_colors ← ps_draw_symbol.constprop.0 ← create_ps ← ps_draw
==1287377==  Address 0x76e3c40 is 8 bytes after a block of size 264 alloc'd
==1287377==    at calloc ← my_calloc ← create_ps
==1287377== ERROR SUMMARY: 432 errors from 3 contexts
```

264 = 22 × `sizeof(Ps_color)`; the three contexts are the `.red`/`.green`/`.blue` reads at
`+0`/`+4`/`+8`. **So this invocation, sheet, arm and build configuration do catch exactly
this defect class when it is present.** The SVG zero is a measurement, not a blind spot.

## Why — and this is a better reason than the driver's E1 prediction

E1 predicted safety from the absence of a restore site plus four clamps. Both hold, and the
crew found the structural fact underneath them:

**`psprint.c` is a STATEFUL back end; `svgdraw.c` is a STATELESS, class-based one.**
PostScript colour is sticky, so `set_ps_colors(pixel)` emits `R G B RGB` on every change and
the text passes must put the previous colour back — `psprint.c:1980` `if(textlayer != c)
set_ps_colors(c)` and `:2030` `if(plw != c) set_ps_colors(c)`, where `c == cadlayers` in the
pseudo-layer pass. **That restore is the over-read.** SVG emits its colours **once**, into a
CSS stylesheet looped over `i` in `[0, cadlayers)`, and each element then carries only
`class="lN"`. `svgdraw.c` has **no analogue of `set_ps_colors()` at all**. The
`svg_draw_symbol(c + 1, i, c + 1, …)` call at `:1301` is byte-for-byte psprint's shape — but
**the sink it fed in psprint does not exist here.**

Reads of `svg_colors[…]`, all three of them (the symbol is file-local; no other `.c` names it):

| site | function | dominated by |
|---|---|---|
| `:426` | `svg_draw_string_line` | **nothing local** — only `if(color_ps)`, a colour-mode test. Every clamp is in its callers. |
| `:1099` | `fill_svg_colors` (a `dbg` print) | the loop bound `i<cadlayers` at `:1069` |
| `:1229`–`:1237` | `svg_draw`, the CSS block | the loop bound `i<cadlayers` at `:1224` |

`:426` is reached only via `svg_draw_string`/`old_svg_draw_string`, and all four of their
`layer` arguments are clamped immediately above: `:947`, `:1007`, `:1048`, `:1356`, each
`if(x < 0 || x >= cadlayers) x = <a real layer>`. `svg_draw_symbol` also does
`if(layer == cadlayers) goto draw_texts;` at `:823`, skipping the geometry entirely, and with
`c == layer == cadlayers` the `c != layer` test is false so `c_for_text` takes `TEXTLAYER` or
`TEXTWIRELAYER` — both real layers.

**So the SVG consequence did not reproduce because four explicit clamps prevent it, not by
luck.** That is a stronger statement than the issue's "unmeasured, not clean", and it is the
one that lets item 2 close.

## Determinism, for completeness

9 runs of `xschem print svg`: **1 distinct md5**. Malformed colour tokens
(`#[0-9a-fA-F]+` of length ≠ 7): **0** headless, **0** on `:99`.

Note on what "out of gamut" can even mean here: `svgdraw.c` emits `#%02x%02x%02x`, so garbage
that fits in a byte is a syntactically valid colour and invisible to a range check. What
*is* detectable is a value **> 255** — `Svg_color`'s members are `int` (`svgdraw.c:26-30`),
unlike `Ps_color`'s `unsigned int` — which prints as more than two hex digits and breaks the
`#rrggbb` shape. That is the only SVG-side invariant worth asserting, and it is what row V25
asserts.

## Incidental, NOT part of the verdict

`svg_draw()` leaks `svg_colors` (264 bytes) on the two `fopen`-failure `return`s at `:1154`
and `:1161`, which skip the `my_free(_ALLOC_ID_, &svg_colors)` at `:1387`. A leak on an
unwritable plotfile — not an out-of-bounds read, and no use-after-free. Filed nowhere yet;
too small for its own issue, worth folding into the next `svgdraw.c` visit.
