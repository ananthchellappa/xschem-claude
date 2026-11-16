# Stage A6 receipt: how a selected label reads in halo

Crew: stage-A6 crew, 2026-11-15. Base: `bd14668b9` plus the main tree's uncommitted A2–A5 `src`
change (`git diff -- src | md5sum` = `1c35de6bd5f722eb374c922052ff9f17`, checked before my edits and
again at the end). Red bed: `~/gsa5` (A5, not edited). All A6 work is in fresh clones `~/gsa6`,
`~/gsa6w`, `~/gsa6n`. **Nothing in the main tree's `src` was touched.** The A6 change is
`receipts/A6-incremental.patch` (against the main tree's current `src`); it touches `src/draw.c`,
`src/move.c`, `src/scheduler.c`, `src/xinit.c`, `src/xschem.h` and `src/xschem.tcl`.

## In plain English

**What changed.**
- In **halo**, a selected text now keeps its own colour and gets a thin (1 px) band of the
  selection colour around its letters. That is the look the user approved on 2026-11-15. Until
  now it was available only by setting `selection_text_style own`; the default drew the letters in
  the selection colour.
- `selection_text_style` has a new default, **`auto`**: the band look in halo, the plain
  selection-colour look in bright. `own` and `colour` (or `color`) still force one look in both
  styles. Any other word means `auto`. Classic ignores the setting, as before.
- **Small text falls back to the selection colour.** A text drawn smaller than **12 screen px**
  is drawn in the plain selection colour, because at that size the band fills the holes of the
  letters and the label turns into a smudge. This is decided **per text**, from the size the text
  is actually drawn at (its size times the zoom times `cairo_font_scale`). So in one selection a
  big label can have the band while a small one next to it is plain selection colour, and zooming
  in moves a label from one look to the other. The cut-off is a new setting,
  `selection_text_own_px` (default 12).
- In practice: when one schematic unit is one screen pixel, a usual FET label (size 0.2) is drawn
  at about 10 px, so it is drawn in the selection colour. Zoom in about 1.2x and it gets the band.
  The small pin letters on a sky130 FET (size 0.15) need about 1.55x.
- Without cairo there is no band, so every text is drawn in the selection colour, as before.
- **Two A5 defects fixed on the way.** Both were in the `own` look, which nobody saw by default
  until now. Changing a selected text with `xschem setprop text` (size, font, weight, or the text
  itself) left a 7 to 22 px piece of the old band on screen, or cut off part of the new one. That
  redraw is limited to the text's box, and the band reaches outside it.

**Why 12 px.** I drew the same label at every size from 4 to 20 px and counted the holes in its
letters (o, e, a, d, b, g, p, q, 0) that still show any background once the band is drawn. In
the default sans face, none shows at 11 px or below, and about a third show at 12 px. Serif is
the same. Zooming in on a smaller text gives exactly the same counts as a bigger text at the
same zoom, so the screen size is the right thing to measure. By eye, the own colour inside the
band reads from about 12 px on a dark background and from 10–11 px on a light one. 12 is the
smallest size that works for the default face in both schemes. The band stays 1 px; nothing I
measured gave a reason to change it.

**What is still not right.**
- **Bold and monospace need more than 12 px.** A bold label's holes stay closed until 16 px,
  monospace until 13 px. Between 12 px and those sizes such a label gets the band and reads
  heavy. A per-face cut-off would fix it; I did not build one.
- Even above 12 px the band look reads bolder than the plain one at 12–14 px (composites). That
  is the look itself, not a defect.
- Italic was not measured: this machine has no oblique sans face, so `slant=italic` renders
  upright and measures the same as regular.
- Some size changes leave the screen stale **in every style, classic included**:
  `xschem setprop -fast` (no redraw, by contract), setting `cairo_font_scale` from Tcl (no menu
  sets it), and a text box that is too small for bold, custom-font or underscore glyphs (an old
  `text_bbox()` limit). I measured each and the styled overlay is never worse than classic there.
- No real screen and no real hand input: everything is synthesized events on Xvfb.

## How it was measured

- **Trees.** `~/gsa6`, `~/gsa6w`, `~/gsa6n`: each a local `git clone` of `~/dev/xschem-claude`
  at `bd14668b9`, plus `git -C ~/dev/xschem-claude diff -- src | git apply` (md5 checked), plus
  this change. `~/gsa6w` is the Windows emulation as A5 built `~/gsa5w` (`SEL_REAL_XCLIP 0` and
  the two `#if 0` in `set_clip_mask()`). `~/gsa6n` is non-cairo (`HAS_CAIRO` undefined). All
  three built with `make -C src`; `git -C ~/gsa6 diff bd14668b9 -- src | md5sum` =
  `0be801036feeea5a132f38b46bdceaa2` (the same for `~/gsa6n`; `~/gsa6w` differs only by the
  emulation toggles).
- **Displays.** My own Xvfb `:270`–`:279` (1920x1080x24), each with openbox, each checked free
  first. `DISPLAY` was unset in every calling shell. Every run had `GUI_GATE=0`, a throwaway
  `HOME`, one lock per display, and its cwd in a scratch work dir holding **copies** of `sky130A`,
  `tests` and `xschem_library` (an early run of mine had its fixtures symlinked and left
  `not~.sch` autosave backups in `~/gsl0`, `~/gsa5` and `~/gsa5w`; see Housekeeping). I never
  used `:99`, `:0` or the user's screen, and never ran T1.
- **Pixels.** `magick compare -metric AE`. "Full redraw" means the same state rebuilt from its
  selection set and drawn by `xschem redraw`. "Forced own" means `selection_text_style own` with
  `selection_text_own_px 0` (the band on every text); "forced colour" means
  `selection_text_style colour`.
- **Scratch.**
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A6/`
  (below, `A6/`). Scripts in `A6/scr/`, composites in `A6/composites/`. Scratch, not durable.

## The threshold measurement

`A6/scr/ladder.tcl` draws `nf=1 W=0.42 L=0.15 M1 abdegopq` at a ladder of rendered sizes
(em px = `xscale * 52 * cairo_font_scale * mooz`, the size `draw_string_cairo()` gives cairo),
snaps it unselected, with forced own, forced colour and the build default.
`A6/scr/counters.py` finds the letter holes of the unselected text and counts how many still hold
a background pixel in the forced-own image. Dark scheme unless named:

| em px | Sans | Serif | Serif, light | Mono | Bold | Sans, zoomed 2x |
|---|---|---|---|---|---|---|
| 8 | 0 of 15 | 0 of 12 | 0 of 14 | 0 of 14 | 0 of 15 | 0 of 15 |
| 9 | 0 of 12 | 0 of 14 | 0 of 16 | 0 of 16 | 0 of 11 | 0 of 12 |
| 10 | 0 of 14 | 0 of 15 | 0 of 15 | 0 of 15 | 0 of 12 | 0 of 14 |
| 11 | 0 of 10 | 0 of 16 | 0 of 17 | 0 of 10 | 0 of 11 | 0 of 10 |
| **12** | **4 of 11** | **4 of 15** | **4 of 15** | 0 of 11 | 0 of 15 | **4 of 11** |
| 13 | 8 of 11 | 5 of 14 | 5 of 14 | 4 of 13 | 0 of 12 | 8 of 11 |
| 14 | 9 of 12 | 9 of 14 | 9 of 15 | 5 of 12 | 0 of 14 | 9 of 12 |
| 16 | 10 of 12 | 11 of 13 | 12 of 14 | 10 of 12 | 3 of 15 | 10 of 12 |

- "Sans, zoomed 2x" is the view zoomed in 2x with every text half the size: the same rendered
  px, and the counts equal the unzoomed column row for row. So the cut-off is a screen size, not
  a text size.
- `slant=italic` gives the Sans column exactly (no oblique face is installed; declared above).
- The whole-string ladder of the composites (`lad_dark`, `lad_light`, the `(N px)` suffix
  included) agrees: 0 open at 11 px, 6 of 12 at 12 px. Its one outlier is 10 px, 4 of 14 open in
  both schemes: hinting at that size opens a few holes that 11 px closes again.
- By eye (`A6/composites/ladder_dark_2x.png`, `ladder_light_2x.png`): below 12 px the band look
  is a smudge in dark; in light it is legible from about 10 px but no better than the plain look.
- **12 px** is therefore the first size at which the default face keeps its letters open. It is
  `SEL_TEXT_OWN_PX` in `xschem.h`, mirrored as `set_ne selection_text_own_px 12` in `xschem.tcl`.

## One decision for each text, everywhere

`sel_text_band_for(xscale)` (`draw.c`) is the only place the size is compared: it answers the
band a text of that size gets (1 px or 0). `sel_text_parts(parts, xscale)` turns that into the
parts a pass paints: a text with the band never gets selection-colour glyphs (`SELP_GLYPH`), one
without never gets the band or own-colour glyphs (`SELP_TXTBAND`, `SELP_GLYPHOWN`). Every site
that paints, erases, clips or sizes a selected text asks one of the two, with that text's own
`xscale` (`get_sym_text_size()` for a symbol text):

- `draw_temp_string_parts()`: the parts, the background restore box (`2 + band` px around the
  text box, so a plain text is erased with 2 px and leaves no band-sized damage) and the band
  stroke. Floating texts and every symbol text go through it.
- `draw_sel_entry()` (`move.c`), floating text: filters its parts first, so a pass that has
  nothing to paint for a text skips it.
- `draw_temp_symbol_parts()`: skips a symbol text with nothing to paint before translating it.
- The own-colour glyph repaint of an instance (`draw_symbol()` under
  `sel_glyph_own_filter(1)`): only the texts with the band, and no pin name (the overlay never
  restores or bands a pin name; A5's forced own painted them a second time, which thickened
  their antialiased edge without changing their colour).
- `sel_cairo_text_clip()`: the per-text glyph clip uses the same `2 + band` pad.
- `sel_entry_fp()`: a floating text's footprint is measured through its own erase, so it follows
  the text's decision. An instance's pad (`2*INT_LINE_W + INT_BUS_WIDTH + sel_halo_px + 4`)
  already exceeds the largest text pad (3 px), so the band term was taken out of it: an instance
  whose texts are plain has the same footprint as one whose texts have the band.
- `sel_close_texts()` grows the repair rects through the same background restore, so a
  text's whole box (band included, or not) lies in one rect.
- `sel_styled_draw()` runs the band pass and the window-only own-colour pass when the style has
  a band at all; each text then takes or skips them through `sel_text_parts()`. The order of the
  passes is A5's: backgrounds, bands, strokes, then glyphs last.
- Idle repair (`sel_idle_cb()`), hover, scope and crosshair repaints, the drag look and the
  restamps all paint through `sel_styled_draw()` / `draw_sel_entry()`, so they inherit it.
  The drag's cheap look (classic look for a slow drag, timed over the first four frames) and the
  hover and scope outlines are unchanged.
- Without cairo `sel_text_band_for()` returns 0, so `auto` and `own` are both the colour look.
- `selection_text_style` and `selection_text_own_px` are read by `sel_style_sync()` only on a
  full redraw, like `selection_style`, so an erase always uses the decision its draw used.

## Every way a selected text's drawn size changes without a full redraw

I looked for every write to a text's `xscale` and every redraw limited to a box
(`bbox(START)` … `bbox(END)`) that can hold a text:

| path | redraw | A6 |
|---|---|---|
| `xschem setprop text <n> size\|font\|weight\|txt_ptr\|allprops\|<token> …` | limited to the text's box | **fixed**, rows D1–D6, D10–D12 |
| `xschem setprop -fast text …` | none, the caller must redraw | stale in every style, row D8 |
| `xschem setprop instance … text_size_N …` | full | row D7, 0 |
| Edit Properties on a text (`edit_text_property()`) | full | read from the code |
| a pin's name view (`pin_view_refresh()`, from a pin property edit) | full | read from the code |
| zoom, pan, `change_linewidth()` | full | |
| `set cairo_font_scale …` then any limited redraw | limited | stale in every style, row D9 |
| `xschem replace_symbol`, `xschem setprop instance -fast` | none, the caller must redraw | read from the code |

Rect, line, arc and polygon property edits also redraw a limited box, but change no text.

**The fix for the limited redraw.** `xschem setprop text` (`scheduler.c`) now records the
selected text's footprint as overlay damage **before** the change (`sel_mark_object()`), so the
repair at the end of that `draw()` wipes the old look outside the text box. The new look,
whichever its new size gives it, is painted by that `draw()`'s own pass over the selection. The
repair (`sel_overlay_flush()`) also lifts the redraw's cairo clip while it runs
(`sel_cairo_bbox_clip()`, new, `draw.c`): its X restores already reached past the box, so a text
the box cut was restored whole and repainted only in part. A second mark after the change was
tried and removed, because taking it out changed no row (S5b below).

## Red and green

Rows are `A6/scr/rows.tcl` on `not.sch`, M1 (`nfet_01v8`) selected with one or two floating
texts. All halo, dark. Every `~/gsa6*` figure below is from a re-run of all 98 row runs on the
final builds (`A6/log/rows2_final.txt`, all exit 0, all reached `V-DONE`); they equal the
figures the sabotages were scored against. "d" is the screen after the change against a full redraw of it, "du" the
screen after a deselect against a full redraw of it.

| row | what | `~/gsa5` (A5) | `~/gsa6` default | `~/gsa6` own | `~/gsa6w` | `~/gsa6n` |
|---|---|---|---|---|---|---|
| A | (a) default look of M1 (labels 12.5 px and up) and a 16 px text, vs forced own | **3281** (default) | 0 | 0 | 0 | 0 ¹ |
| B | (b) M1 at 11 px, pins 8 px, a 9 px text, vs forced colour | **1852** (own) | 0 | 0 | 0 | 0 |
| C c1 | (c) M1 + a 12.5 px text + an 11.5 px text: 12.5 vs forced own / 11.5 vs forced colour | **810** (default) / **733** (own) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| C c2 | crosshair swept across that selection, vs full redraw | 0 | 0 | 0 | 0 | 0 |
| C c3–c5 | deselect the 11.5 px text, then the 12.5 px one, then all, each vs full redraw | 0 | 0 | 0 | 0 | 0 |
| D1 | (d) 12.5 → 11.5 px (crosses down): d / du; then 11.5 vs forced colour | **7** / 0; **738** (own) | 0 / 0; 0 | 0 / 0; 0 | 0 / 0; 0 | 0 / 0 |
| D2 | 11.5 → 12.5 px (crosses up) | **8** / 0 (own) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| D3 | font Serif | **7** / 0 (own) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| D5 | a longer text | **22** / 0 (own) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| D6 | a shorter text | **7** / **7** (own) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| D7 | M1's `text_size_5` (a symbol text, full redraw) | 0 / 0 (own) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |

¹ Non-cairo has no band: forced own and forced colour are the same picture there, so A and B
cannot be red on `~/gsa6n`; they show its default is that picture.

`~/gsa5`'s rows are red in the configuration named: A and C's 12.5 px half under its default
(`colour`), the rest under `own`, which is what `auto` now gives. Under its own default A5 is
green on D1–D7, because the colour look has no band to leave behind. `~/gsa5w` (`own`): D2 **8**,
D6 **7**/**7**, D1 0/0 but **731** against forced colour. Bright (`auto` = colour) on `~/gsa6`:
D1–D7 all 0/0.

**Rows that show a base limit**, the same or worse in classic (`~/gsa6` classic and `~/gsl0`
classic give the same figures):

| row | what | classic d / du | `~/gsa6` default d / du | `~/gsa6` bright |
|---|---|---|---|---|
| D4 | weight bold | 107 / 71 | 0 / 71 | 61 / 71 |
| D8 | `setprop -fast` size | 970 / 870 | 955 / 763 | 755 / 755 |
| D9 | `cairo_font_scale 0.9`, then `setprop` on one text | 13794 / 13415 | 13637 / 13161 | 13162 / 13152 |
| D10 | 11.5 → 18 px (underscore below the text box) | 10 / 10 | 0 / 10 | 10 / 10 |
| D11 | font Monospace | 111 / 76 | 68 / 76 | 68 / 76 |
| D12 | `allprops {font=Monospace weight=bold}` | 125 / 90 | 72 / 90 | 72 / 90 |

D4, D10, D11, D12: the leftover is a glyph that `text_bbox()` does not cover (bold, a custom font,
a descender), so classic leaves it too. On `~/gsa6` every px wrong after the change is also wrong
after the deselect, and no px is wrong in the styled screen that is right in classic's. The
screen after the deselect is AE 0 against classic's on D1–D7 and D10–D12. D8 and D9 change a size
with no redraw of the changed area at all.

## Sabotages

Each was applied to `~/gsa6`, built, run, restored with `cp` and proved with `cmp`, and rebuilt.
S1–S4, S6 and S7 ran while a second `sel_mark_object()` (after the change) was still in
`scheduler.c`; S5b then showed that mark changes no row, and it was removed.

| id | sabotage | reddens |
|---|---|---|
| S1 | `auto` resolves to colour in halo (`sel_style_sync()`) | A **3281**; C 12.5 px **810**. With explicit `own`: 0 (as it should) |
| S2 | `sel_text_band_for()` ignores the size | B **1852**; C 11.5 px **733**; D1 vs forced colour **731** |
| S3 | the background restore pad loses its band term (`draw_temp_string_parts()`) | C c2, c3, c4 **11** each |
| S4 | `sel_mark_object()` records nothing for a text | C c1 **1237** (12.5 px **795**, 11.5 px **442**), c3 **442**, c4 and c5 **1237**; D1 **442** / **483** |
| S5a | `xschem setprop text` records no damage before the change | D6 **7** / **7** |
| S5b | drop the second mark (after the change) | nothing: D2, D3, D5, D10, D11, D12 unchanged. Mark removed. |
| S6 | `sel_overlay_flush()` does not lift the cairo clip | D2 **8**, D3 **14**, D5 **15** |
| S7 | `sel_cairo_text_clip()` pad loses its band term | **nothing** (declared below) |

S7: the pad picks which repair rect clips a text's glyphs. With 2 px instead of 3, a rect that
holds the 2 px box but not the 3 px one would be picked and clip the band's outer pixel.
`sel_close_texts()` grows every rect that meets a text's 3 px box to hold all of it, so I found no
pose where a rect holds the smaller box and not the larger one. The pad is kept equal to the
restore's anyway; nothing fences it.

## Earlier repros under the new default

A forked copy of me re-ran A5's and A4's scripts (copied to `A6/r/`, pointed at `~/gsa6`,
`~/gsa6w`, `~/gsa6n` and `~/gsl0` through the scratch work dirs) in A5's configurations plus
`auto` (halo and bright, dark and light, `~/gsa6w`, `~/gsa6n`). Its score logs were compared
with A5's line for line (`A6/r/log/cmp_text.interim`). **It did not finish**: the hand-back was
called while five of its batches were still running, and I stopped them (see Housekeeping). What
completed:

| family | against A5's score lines | `auto` configurations |
|---|---|---|
| A2 repros (D1 `partial`, D2 `fillrect`/`hide2`, D3 `scoperep`, D4 `xhair`, D5 `customfont`, L1 `fastsel`) | 119 equal, 0 differ | all 0, except D1's wire 184, which every build and classic give |
| D7 `winemu` (w1–w3, `fix_broken_tiled_fill` 0 and 1) | 8 equal | all 0 |
| A2's `expo*` | 11 equal | all 0 |
| `ctx_v3` | 11 equal | all 0 |
| `ctx_detach`, `ctx_mix` | 27 equal, 13 not run (killed) | all 0 |
| scenario scripts (`drag2`, `ovl`, `hil`, `sw`, `ctx_*`, `print`, `bigdrag`, `band*`, …) | 208 equal | all 0 |
| A4's repros (`ctx_a4`, `ctx_cancel*`, `win_a4`) and `rub2_a4` | 70 equal, 4 differ, 1 not run | all 0 except K6b |
| `vband`, `vband_k` | 594 equal, 1 not run | no nonzero AE line |

The 4 that differ are all K6b in `own` configurations (halo own dark, bright own dark and light,
`~/gsa6w` bright own): 66796 → 66751 and 61082 → 61037. K6b is the base bug A4 recorded and A5
re-measured (a select pending in a tab that is not on the canvas); its AE against a full redraw is
tens of thousands in every build, classic included, and it moves with the look of the pending
select. With the small symbol texts now drawn plain, it moved by 45 px. Not a new defect.

A5's own poses and the verifier's V4 poses, scored by me from the fork's snapshots before
deleting them: `a5_canvas` halo `auto` dark and light, bright `auto`, `~/gsa6w` halo `auto`:
G1, G1b, G1q, G1r, G6, G1p, TM1–TM5 all 0; TM1b 5501 (halo dark), 5850 (light), 2239 (bright),
which is A5's declared limit (a window over part of the canvas; halo `colour` gives A5's 5271).
`v4_degen` on `~/gsa6w` halo `auto` and `~/gsa6` halo `own`: all 0 for every kind and trigger.
`a5_degen3` on `~/gsa6w` halo `auto`: the screen after every trigger equals the tool's own
picture, which differs from a full redraw by A5's 3 / 19 / 247 px. 65 other A5-pose runs (`ac`,
`cv`, `dg`, `dg2`, `dg3`, `ru`, `rub`, `tm`) reached `V-DONE` with exit 0 but were **not
scored**. The ten A2-era poses A4 did not run (`partial2`, `partial3`, `italic`, `clickhov`,
`hoverx`, `pinsel`, `symedit`, `newwin`, `instzoom`, `resid`): `~/gsa6` halo `colour` and bright
`own` equal `~/gsa5`'s lines exactly, and halo `auto` and bright `auto` give the same figures. The
only nonzero one is `partial2` q2 (a text straddling the redraw box), 30 in halo and 8 in bright,
which `~/gsa5` gives too.

## Classic byte-identity against `~/gsl0`

Every classic snapshot the fork took on `~/gsl0` that has a `~/gsa6` classic counterpart with
the same tag (A2 scenario scripts, A2 repros, A4 repros, rubber pose, `vband`, `vband_k`,
`ctx_v3`, `ctx_detach`/`ctx_mix`, `a5_canvas`, `v4_degen`, `v4_degen2`, `a5_degen3`, `v4_canvas`,
`v4_reuse`, `v4_tabmid`; dark and light): **1396 of 1399 AE 0**. Two are the full-page PNG
export's title-block date (206 px each, the known exception). The third is a `~/gsa6` snapshot
left empty when I stopped the fork. 569 `~/gsl0` snapshots had no `~/gsa6` counterpart because
those `~/gsa6` classic runs were in the batches I stopped. Separately, my own rows D1–D12 in
classic give the same figures on `~/gsa6` and `~/gsl0` wherever both were run (D3, D4, D8, D9,
D10).

## Health

- **Valgrind, display arm**, on the final builds: rows A, C, D2, D6, D9 on `~/gsa6`; C and D2 on
  `~/gsa6w`; C on `~/gsa6n`. 8 runs: every log empty, every run exit 0 and reached `V-DONE`, with
  the same scores as outside valgrind.
- **Valgrind, `--nogui` and `--pipe`**: A5's `nogui2`, `nogui3`, `nogui4` on `~/gsa6`, `~/gsa6n`
  and `~/gsa6w`; classic, bright and halo; `auto`, `colour` and `own`. 162 runs: all exit 0, end
  mark written, valgrind log empty, no `FATAL`.
- **Warnings.** Every `OBJ` file, base (`~/gsl0`'s sources) against A6 (`~/gsa6`'s), warning
  lines with line numbers stripped: cairo default, cairo `-std=c89 -pedantic`, non-cairo default,
  non-cairo `-std=c89 -pedantic`. Identical files each (6 / 67 / 6 / 67 lines on both).
- **Suites** (`tests/headless/run_suites.sh` from the work dir's copy, `GUI_GATE=0`, explicit
  `AUDIT_DISPLAY`), A6 (`:278`) and base `~/gsl0` (`:279`), A5's lists. Display arm: 28/30
  passed, 1 skipped, on both. Counted arm (`--nogui`, `AUDIT_DISPLAY=none`): 19/24 passed, 10
  skipped, on both. The scan list: display 10/10 on both, counted 7/9 (1 skipped) on both. Every
  verdict line is identical between A6 and base. The reds are base's own: `test_select_at` 5
  FAILED and `test_cadence_drag` 2 FAILED on the display arm; `NORESULT` for `test_cadence_drag`,
  `test_hover_highlight`, `test_hover_selection_repair`, `test_select_at` and
  `test_wire_complete_with_selection` on the counted arm, and `test_annot_declutter_1244`,
  `test_nh_angle_render` in the scan list's counted arm.

## Timing

`A6/scr/perf6.tcl`: a sheet of 1600 `nfet_01v8` and 1600 wires, a 1400x1000 window, dark, at
three view widths. Per width: hover (20 motions over instances, `hover_highlight 1`, the sheet
selected), crosshair (20 motions), select all (median of 5), a shift rubber band growing over the
selected sheet (mean of 20 motions), and a drag of the selected sheet (20 frames: the first four
alone, then the rest). Every figure is ms per step including an X round trip. Two rounds, the
variants interleaved, one at a time on `:270`; the cell is the mean, the two rounds in brackets.
"halo auto" is the A6 default, "halo colour" the A5 default look in A6's code, "A5" is `~/gsa5`'s
default, "halo own, every size" is `own` with `selection_text_own_px 0` (A5's forced own).

**Labels at 14.7 px (the band is drawn):**

| variant | hover | crosshair | select all | rubber band | drag, first 4 | drag, rest |
|---|---|---|---|---|---|---|
| halo auto (A6) | 1.8 (1.6/1.9) | 0.8 (0.8/0.8) | **6.8** (6.5/7.2) | 1.3 (1.3/1.3) | 1553 (1574/1532) | 691 (677/705) |
| halo colour | 1.5 (1.6/1.3) | 0.9 (0.9/0.8) | 4.1 (4.3/3.8) | 1.2 (1.3/1.1) | 1831 (1984/1678) | 730 (771/689) |
| A5 (`~/gsa5`) | 1.4 (1.5/1.3) | 0.8 (0.8/0.8) | 3.8 (4.0/3.6) | 1.1 (1.3/1.0) | 1421 (1489/1353) | 741 (676/807) |
| halo own, every size | 1.9 (1.9/1.9) | 0.9 (1.0/0.9) | 8.2 (8.0/8.5) | 1.4 (1.3/1.5) | 1516 (1517/1515) | 645 (645/644) |
| classic (`~/gsa6`) | 3.3 (3.4/3.2) | 4.7 (4.8/4.5) | 1.6 (1.6/1.5) | 4.9 (5.0/4.8) | 1655 (1647/1663) | 705 (698/712) |
| classic (`~/gsl0`) | 3.3 (2.8/3.8) | 4.7 (4.1/5.3) | 1.5 (1.3/1.7) | 4.5 (4.0/5.1) | 1583 (1514/1652) | 734 (640/827) |

**Labels at 5.7 px (every text falls back to the selection colour):**

| variant | hover | crosshair | select all | rubber band | drag, first 4 | drag, rest |
|---|---|---|---|---|---|---|
| halo auto (A6) | 1.4 (1.3/1.5) | 0.9 (0.9/0.9) | 16.9 (15.9/17.8) | 2.6 (2.5/2.7) | 1918 (1938/1899) | 1749 (1847/1651) |
| halo colour | 1.3 (1.4/1.1) | 1.0 (1.0/0.9) | 15.6 (16.9/14.2) | 2.4 (2.7/2.2) | 1720 (1867/1573) | 1733 (1832/1634) |
| A5 (`~/gsa5`) | 1.6 (1.4/1.7) | 1.3 (1.0/1.6) | 19.8 (17.3/22.2) | 3.3 (2.9/3.7) | 1991 (1759/2223) | 1883 (1822/1943) |
| halo own, every size | 1.5 (1.5/1.6) | 0.9 (0.9/0.9) | **36.5** (37.4/35.6) | 3.5 (3.6/3.5) | 1675 (1696/1654) | 1622 (1628/1617) |
| classic (`~/gsa6`) | 12.5 (11.9/13.1) | 18.4 (17.5/19.2) | 6.6 (6.1/7.1) | 19.5 (18.5/20.4) | 1815 (1819/1811) | 1597 (1599/1594) |
| classic (`~/gsl0`) | 14.9 (11.9/17.8) | 23.8 (17.6/30.0) | 8.0 (5.9/10.1) | 24.6 (17.2/32.0) | 2262 (1564/2961) | 2269 (1432/3107) |

**Labels at 1.7 px (whole sheet in view):**

| variant | hover | crosshair | select all | rubber band | drag, first 4 | drag, rest |
|---|---|---|---|---|---|---|
| halo auto (A6) | 0.9 (1.0/0.7) | 0.7 (0.6/0.8) | 16.7 (20.7/12.6) | 1.6 (1.9/1.3) | 2261 (2450/2071) | 2291 (2498/2084) |
| halo colour | 0.9 (0.9/0.8) | 0.9 (0.9/0.9) | 13.1 (13.2/13.0) | 1.4 (1.4/1.3) | 2241 (2264/2218) | 2269 (2228/2309) |
| A5 (`~/gsa5`) | 1.0 (0.9/1.0) | 0.9 (0.8/1.0) | 14.3 (13.2/15.4) | 1.6 (1.4/1.7) | 2345 (2237/2452) | 2264 (2368/2159) |
| halo own, every size | 0.9 (0.9/1.0) | 0.8 (0.8/0.8) | 13.8 (14.2/13.3) | 1.4 (1.6/1.3) | 2247 (2383/2110) | 2259 (2362/2156) |
| classic (`~/gsa6`) | 5.8 (5.9/5.7) | 9.0 (9.1/8.9) | 3.0 (3.0/2.9) | 9.6 (10.0/9.3) | 2168 (2231/2106) | 2096 (2154/2039) |
| classic (`~/gsl0`) | 13.5 (6.3/20.6) | 17.6 (9.2/26.0) | 5.1 (3.2/7.0) | 15.9 (10.6/21.3) | 3387 (2183/4591) | 3019 (2135/3902) |

**What the band costs.** Where it is drawn (14.7 px), selecting all 1600 FETs takes about 3 ms
more than the plain look (6.8 against 4.1 and 3.8 ms); hover is about 0.3 ms slower, and the
crosshair, the rubber band and the drag show no difference above the noise. Where the labels are
small (5.7 px) the A6 default costs what the plain look costs (16.9 against 15.6 ms, inside the
two rounds' spread), while the band on every text (A5's `own`) costs 36.5 ms: the fallback also
saves the band's cost exactly where it would be a smudge. At 1.7 px the variants agree within
their spread. The drag is dominated by something else (0.6 to 2.5 s per frame for 1600 FETs in
every style, classic included) and the band is not visible in it.
Caveat: the machine was shared (my forked repro runs and another session's test run were live),
which is why some pairs, `~/gsl0`'s second round especially, are far apart. Only the select-all
difference at 14.7 px and the `own`-at-every-size figure at 5.7 px are larger than the spread.

## Composites

In `A6/composites/` (full path above):
- `fet_dark.png`, `fet_light.png`: M1 selected with its labels and a floating note, at three
  zooms (labels 8, 13 and 20 px). Columns: classic, halo with `colour` (the A5 default), halo
  with `auto` (the A6 default). At 8 px every label is plain selection colour in both halo
  columns; at 13 and 20 px the A6 column has own-colour labels with the band.
- `ladder_dark.png`, `ladder_light.png`: the threshold ladder, 7 to 20 px. Columns: unselected,
  the band at every size, the A6 default (band from 12 px).
- `ladder_dark_2x.png`, `ladder_light_2x.png`: 9 to 13 px at 2x, where the cut-off is.

## The patch

- `receipts/A6-incremental.patch`: `src` changes relative to the main tree's current `src`.
  `git apply --check` and `git apply` were run on a copy of the main tree's `src` and on a fresh
  clone at `bd14668b9` with the A5 diff applied; both give files byte-identical to `~/gsa6/src`.
  md5 `372714428dc3878a9922ed2de1b534e9`.
- `git -C ~/gsa6 diff bd14668b9 -- src | md5sum` = `0be801036feeea5a132f38b46bdceaa2` (the same
  for `~/gsa6n`; `~/gsa6w`, with the emulation toggles, `f6db767a6c7ef20c5f1f812d3a574f11`).
- The main tree's `git diff -- src | md5sum` is still `1c35de6bd5f722eb374c922052ff9f17`.

## Limits and what I could not do

- Bold labels need 16 px and monospace 13 px before their letters open; at 12 px and up they
  get the band anyway. Italic was not measured (no oblique face installed).
- The band stays 1 px; I measured no other width.
- S7 is unfenced (above).
- `setprop -fast`, `cairo_font_scale` set from Tcl, and glyphs outside `text_bbox()` leave the
  screen stale in classic too (rows D4, D8–D12). Not fixed here.
- Pin names (`show_pin_names`) are not part of the selection look in any style; under halo they
  stay as drawn beneath it, as in the A5 default.
- A zoom command that skips its redraw leaves the whole canvas stale in every style until the
  next draw; I did not pose it.
- No real hand input and no real screen. The Windows build was not compiled; only the emulation.
- `edit_text_property()`, `pin_view_refresh()` and `replace_symbol` were read, not driven.

## Housekeeping

- My Xvfb and openbox on `:270`–`:279` (the fork used `:274`–`:277`) are stopped, killed by the
  pids recorded at start after checking each command line and openbox's `DISPLAY`. No X lock file
  or socket is left for those displays. The fork's five unfinished batches were stopped by killing
  their process trees; no xschem of mine or the fork's is left running.
- My early runs (fixtures symlinked) left `not~.sch` autosave backups in `~/gsl0`, `~/gsa5` and
  `~/gsa5w`. I identified them by content (my test texts) and time and removed them; after that
  every run used work dirs with **copied** fixtures, and those copies are deleted.
- **Backups I did not write, left untouched** (the brief forbids touching those clones):
  `~/gsa5`, `~/gsa5w`, `~/gsa5n`: `.../not/schematic/not~.sch` (11:17:40, 11:18:12, 11:33:37; the
  first two within a minute of another crew's Xvfb `:286`–`:291` starting, scratch `A5b/`);
  `~/gsa5` and `~/gsa5w`: `xschem_library/examples/flop~.sch` and `mos_power_ampli~.sch`
  (11:53:32–38, when nothing of mine ran on those trees); `~/gsl0`: `.../not/schematic/not~.sch`
  (11:48:52, a wire split at nets DN and y, none of my texts). Every runner of mine and the
  fork's changes into a work dir under `A6/wd/` and loads `not.sch` relative to it; I found no
  path from them into those clones.
- `~/gsa4`, `~/gsa4w`, `~/gsa4n`: nothing newer than my start mark. Main tree: only `LEDGER.md`
  and `receipts/A5-verify.md` (not mine) and my two receipt files are newer; its `src` md5 is
  unchanged.
- `~/gsa6`, `~/gsa6w`, `~/gsa6n` carry only their `src` changes and build products; no backup
  files.
- Scratch `A6/` is 12 MB after deleting the snapshots, work dirs and test clones; the composites,
  scripts, score logs (`A6/log/`, `A6/r/log/`) and sabotage diffs (`A6/sab/`) are kept.
- No commit, push or stash anywhere. `~/private` was not read.
