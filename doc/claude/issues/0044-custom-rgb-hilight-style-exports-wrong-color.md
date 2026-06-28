# Issue 0044 — Custom-RGB net-highlight style exports to SVG/PDF in the wrong (fallback) color

**Opened:** 2026-06-26
**Status:** ✅ RESOLVED (2026-06-27) — added a shared `hilight_custom_rgb8(value, &r,&g,&b)` helper
(`src/hilight.c`) that yields a custom-RGB hilight style's actual 8-bit color (0 for layer styles / sim
levels / unresolved-without-X). The exporters paint highlighted elements with it, each in the way its
format allows: **SVG** colors by CSS layer class, so it emits an inline `style="stroke:#rrggbb;
fill:#rrggbb"` override (inline style beats an author-stylesheet class) on the highlighted wire / junction
dot / symbol (`svg_set_hilight`/`svg_clr_hilight` + threading `svg_xdrawline`/`svg_drawcircle`/
`svg_drawpolygon`); **PS/PDF** emits an inline RGB per `set_ps_colors`, so it temporarily repoints the
fallback layer's `ps_colors[]` entry around the highlighted wire/symbol (`ps_push_hilight`/
`ps_pop_hilight`), mirroring the on-screen GC repoint. A layer-index style is untouched (the override is a
no-op), so normal export is unchanged. Test `tests/headless/test_nh_export_custom_color.tcl` (GUI):
exports a wire highlighted with a non-palette `#1a9b8c` style and asserts the custom color reaches both
the SVG (inline stroke on a drawn element) and the PS (`0.101562 … RGB` triple); sabotage-verified
(neutering `svg_set_hilight` drops it). Note: PS junction dots are drawn in `WIRELAYER` regardless of
highlight (pre-existing, separate from this issue), so only the PS wire body + symbol take the custom
color. Was finding #6 of the `/code-review high`.
**Severity:** MEDIUM — exported/printed output does not match the on-screen highlight color.
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #6 (CONFIRMED).
**Affects:** `src/hilight.c` `get_color()` (~:635) — returns a *layer index*; for a custom-RGB style
(`color_layer < 0`) it returns a fixed fallback layer (`cadlayers>5 ? 5 : cadlayers-1`). Export
consumers that color highlighted nets/symbols by that layer index: `src/svgdraw.c:731` (symbol),
`:1168` (wire body), `:1189` (junction dots); `src/psprint.c:991` (symbol), `:1561` (wire).
Related: [[net-hilight-styles]]. (The on-screen draw path and the ngspice/`hilight.c:3084` symbol path
already special-case custom colors via a GC / `xcolor_array` repoint; the SVG/PS export paths do not.)

---

## 1. Symptom

Highlight a net with a **custom color** style (a `#RRGGBB` or X color-name entry in the
`net_hilight_style` table, i.e. `color_layer < 0`), then **export to SVG or PDF/PS** (or plot in
ngspice/gaw). The highlighted wire/symbol renders in a fixed fallback layer color (layer 5) instead of
the custom color shown on screen — the exported file no longer matches the display.

## 2. Root cause

`get_color(value)` must return a *layer index* (its consumers are layer-indexed: the SVG `svg_colors[]`
table, the PS color table). A custom-RGB style carries its color as an X pixel in `st->color` (16-bit
`cr/cg/cb` once `resolve_hilight_style_rgb()` runs), not as a layer, so `get_color()` falls back to a
fixed layer. The SVG/PS exporters then emit `svg_colors[fallback]` / the fallback PS color — the wrong
color. On screen this is avoided by temporarily repointing the fallback layer's GC/`xcolor_array` to the
style's exact pixel (`hilight.c` symbol path); the export paths were never given the equivalent.

## 3. Fix sketch

Mirror the on-screen override in the export paths: when the highlight value resolves to a custom-RGB
style (`color_layer < 0`), temporarily repoint that file's per-layer color-table entry for the fallback
layer (`svg_colors[layer]` / the PS color) to the style's RGB (`resolve_hilight_style_rgb()` →
`cr/cg/cb >> 8`), emit the wire/symbol, then restore. Factor a small `*_override_hilight_color(value,
layer, &saved)` / `*_restore_hilight_color(layer, &saved)` helper per export file and wrap the five draw
sites. (Headless export without X can't resolve a pixel→RGB; leave the fallback there, as the parser
already can't resolve color names without X.)

## 4. Acceptance

Exporting (SVG/PDF) a schematic with a custom-color highlighted net emits the net in that exact color;
a regression greps the exported SVG for the expected `#RRGGBB` stroke.
