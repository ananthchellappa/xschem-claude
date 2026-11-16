# Stage A adversarial verify: `selection_style` prototype

Verifier for stage A. Base `e3c43487e`. The stage-A diff was taken from the main tree's
`git diff -- src/` (md5 `c1d12e98df7a7c56dd1a05dafdd22585`). It was applied to a clean clone
`~/gsv1` and built there; the build had only the six pre-existing const warnings.
`~/gsl0` (pristine base) was the comparison binary.

Nothing in the main tree was edited except this file.

## How everything below was measured

- **Displays.** Every run was on my own Xvfb `:287` or `:288` (1920x1080x24, openbox), with
  `GUI_GATE=0` and a throwaway `HOME`. `DISPLAY` was unset in every shell. Nothing ran on `:99`,
  on `$DISPLAY`, or under T1. All four of my server/WM pids were killed at the end.
- **Harness.** It lives in
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/V/scr/`
  (`run.sh`, `wrap.tcl`, `common.tcl` plus one pose per scenario).
  - A pose captures `.drw` in-process with `import -window [winfo id .drw]`. That avoids
    `lookshot.sh`'s name match, which the gate panel photobombed for the crew.
  - Every residue row compares two snapshots taken in the same process: the state after the
    gesture (`<row>`) and the same state after `xschem redraw` (`<row>_R`).
    `magick compare -metric AE`; **0 = canonical**.
- **Reproducing any row:** start your own Xvfb with openbox on display N, then
  `VDPY=:N scr/run.sh ~/gsv1 scr/wrap.tcl <tag> V_SCR=<scr dir> V_STYLE=<classic|bright|halo> V_POSE=<scr dir>/<pose>.tcl`.
  The PNGs land in `selshot/V/out/<tag>.<row>.png`.
- **Evidence.** All evidence images are under
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/V/`.

## Findings, ranked

### D1. DEFECT (high): halo re-paints the FILL of a selected filled shape on top of everything inside it

**What happens.**
- `sel_rect_out` (`SELP_OWN`) calls `filledrect(c, ...)` when `r->fill` is set.
- The `POLYGON` and `ARC` own passes pass the fill too (`drawpolygon(..., p->fill, ...)`,
  `drawarc(..., fill, ...)`). So does `draw_symbol` for an instance's filled rects, polygons and arcs.
- All of this is painted window-only, after the pixmap. Every object that `draw()` painted inside the
  shape (texts, wires, other instances) is covered for as long as the shape is selected.
- Classic and bright show only an outline, so the contents stay visible.

**Repros.**
- `fillrect.tcl`: `xschem rect 480 -220 600 -120 -1 {fill=full}`, select it.
  - M1's `nfet_01v8` text and the gate wire inside the rect disappear in halo only.
  - Evidence: `F8_filled_rect_hides_contents.png`. Left is unselected, middle is bright, right is halo.
- `partial.tcl`: select a filled rect, then place a text or a wire inside it.
  - The new object is visible until the next full redraw, which hides it.
  - Halo, compared with a redraw: text 889 px, wire 489 px. Classic and bright: 0 and 184
    (184 is the same in classic).
  - Evidence: `F8b_new_wire_hidden_under_selected_fill.png`.

**Fix.** The own pass should stroke outlines only (fill 0 for rects, polygons and arcs, and in the
instance re-draw). An alternative is to clip the own pass to a 1-bit mask of the band strokes, so it
restores only what the band covered. Either way also removes D2.

### D2. DEFECT (high): a halo drag of filled shapes leaves fill residue that survives abort and `unselect_all`

**What happens.**
- The styled erase routes `gctiled` rects through `TILED_BY_COPY` to `fix_restore_rect`. That
  copies back only the **four padded edges**.
- The own pass (D1) painted the **interior fill** at every rubber-band position. Each frame's fill
  therefore stays on screen until a full redraw.
- **Repro `fillrect.tcl`** (select, `move_objects start` + 3 steps, step back to the anchor, abort,
  `unselect_all`). Halo, back-to-anchor compared with the selection: 42287 px. After abort: 40486.
  After `unselect_all`, against the unselected canvas: **41357**.
  Classic and bright: 0 / 0 / 0. Evidence: `F1_fillrect_halo_residue.png`.
- **Same family with `hide_symbols 2`** (`instzoom_hide.tcl`, M1 drag + abort + unselect,
  compared with unselected): halo **1173 px** of red pin fragments; classic 0.
  - `draw_symbol`'s hide path paints the PINLAYER rects (filled) at the displaced offset.
  - `draw_temp_symbol_parts`' hide path erases only the bbox outline.
  - Evidence: `F4_hide_symbols_drag_residue.png` (selected, drag, after unselect, base).

**Fix.** D1's fix removes the fills. Independently, `sel_styled_erase` could restore each entry's
whole padded bbox in one copy: an instance's displaced `xx1..yy2`, a rect's full rect. That is a
superset by construction, and it is cheaper than one copy per primitive.

### D3. DEFECT (medium): an interactive click cuts the property-form scope outline, contradicting PLAN's "must still read distinctly on top"

**What happens.** `sel_repair` restores the clicked object's padded footprint from the pixmap. It then
re-strokes only the selection, never `draw_scope_highlight()`. The window-only white outline therefore
stays cut until a full redraw.

**Repro `scoperep.tcl`.**
- Setup: M1 selected, `highlight_scope current M1`, redraw. Then `select wire` on the gate wire, then
  `select wire ... clear`.
- Count white pixels at column x=333, rows 228–257. The scope outline crosses the G pin there.

| state | white pixels |
|---|---|
| before | 30/30 |
| halo, after select | 11/30 |
| halo, after deselect | 11/30 |
| bright | 19/30 |
| classic select / deselect | 28/30 / 22/30 (upstream's own small cut) |
| after a full redraw | 30/30 |

Evidence: `F2_scope_outline_cut_by_click.png` (scope, select wire, deselect, redraw).

**Fix.** In `sel_repair`, call `draw_scope_highlight()`, plus the hover outline if `hover_type`, while
the footprint clip is still set. The rubber-band end strokes in `select_inside` and `select_touch` have
the same gap through the text-background restore.

### D4. DEFECT (medium): with the crosshair on, the crosshair is cut across every selected text's bbox on EVERY motion

**What happens.**
- `draw_crosshair` strokes the new crosshair first and then calls `draw_selection`.
- The styled `SELP_TEXTBG` pass then restores each selected text's bbox (+2 px) from the pixmap,
  which wipes the crosshair just drawn. Symbol texts of selected instances count too.
- The receipt's "wiped until the crosshair next moves" is wrong: every move re-cuts it.
- `draw_snap_cursor` has the same order.

**Repro `xhair.tcl`.** Select M1 and the floating text, `draw_crosshair 1`, `<Enter>`, motion, redraw,
motion. Column x=145, rows 96–129:
- classic: the yellow dotted line is present;
- halo: black.

Evidence: `F3_crosshair_gap_text.png` (top classic, bottom halo).

**Also, by code reading (not pixel-measured).** The same path wipes a hover outline or fly-lines on a
selected text whenever the crosshair moves.

**Fix.** When styled, call `draw_selection` before stroking the new crosshair or snap cursor. Keep the
classic order so classic stays byte-identical.

### D5. DEFECT (medium): a custom-font text leaks its cairo font into the repair of every other selected text

**What happens.** `select_text` calls `set_text_custom_font()` before `draw_sel_object()`. The
`sel_repair` repaint then lays out and draws the other selected texts in the footprint with that font.
So their background restore and their glyphs both use the wrong metrics.

**Repro `customfont.tcl`.**
- Setup: text `MONO` with `font=Monospace weight=bold`, overlapping M1's attribute texts. Select M1,
  then select the custom text, then deselect it.
- Against a redraw:

| style | select | deselect |
|---|---|---|
| halo | 1096 px | 1678 px |
| bright | 1096 px | 1678 px |
| classic | 0 | 173 (upstream) |

- M1's `1 x W_N / L_N` shows own-colour glyph remnants under misplaced orange ones.
- Evidence: `F6_customfont_repair.png`, `F6b_customfont_desel.png` (top incremental, bottom redraw).

**Fix.** Do the styled call before `set_text_custom_font` in `select_text`, or `cairo_restore` around
it.

### D6. DEFECT (medium, performance): the static overlay has no cost bound, and the default hover path pays it in full

**What happens.**
- Hover is on by default (`set_ne hover_highlight 1`).
- Every hover change, and every crosshair motion, calls `draw_selection`. That repaints the whole
  styled overlay: one `XCopyArea` plus one cairo glyph render per text, and a `draw_symbol` per
  instance.
- The 400-entry fallback applies only to `STARTMOVE|STARTCOPY`.

**Measured** in ms on Xvfb, with `winfo pointerxy` round trips inside the timing (`perf.tcl`,
`perf2.tcl`, `perf3.tcl`).

| case | classic | halo |
|---|---|---|
| gates_sky130.sch (826 inst), select-all: hover change | 8.2 | 20.3 |
| gates_sky130.sch (826 inst), select-all: crosshair motion | 11.9 | 32.5 |
| 1600-FET grid at mid zoom, select-all: hover change | 6.7 | 21.7 |
| 1600-FET grid at mid zoom, select-all: crosshair motion | 11.4 | **41.9** |
| 1600-FET grid at mid zoom, select-all: `select_all` | 5.9 | 15.9 |
| scripted per-instance `xschem select instance $i` (no `fast`), K=400 | 42 | 308 |
| scripted per-instance `xschem select instance $i` (no `fast`), K=826 | 70 | **1011** |

- Bright is close to halo: 18.6 for a hover change and 28.4 for a crosshair motion.
- The scripted-select cost is quadratic: `sel_repair` runs `sel_collect` and pushes every selected
  entry through all passes on each click.
- `chksave::show` in `src/xschem.tcl` selects every instance of a symbol that way.
- Not measured on the user's TCP X server, which is likely slower.

**Fix.**
- Clip the hover and crosshair repairs to the damaged rectangle, with the culling area set as
  `sel_repair` already does. That makes them proportional to the local area.
- In `sel_repair`, skip entries whose bbox misses the footprint before calling `draw_sel_entry`.
- Consider whether a bound on the static overlay is needed too.

### D7. DEFECT (medium, portability; emulated, not run on Windows): `sel_repair`'s correctness rests on `XSetClipRectangles`, which is a no-op stub on Windows

**Background.** `draw.c` has an `#ifndef __unix__` placeholder that returns 0. `set_clip_mask` has its
own `#if 1 /* set to 0 to emulate Windows ... */` switch. I built `~/gsv2` = `~/gsv1` with both
switches set to 0.

**Measured (`winemu.tcl`), halo compared with a redraw:**

| gesture | AE |
|---|---|
| deselect the wire | **139** |
| select in another order | 6 |
| deselect M1 | 6 |

- Classic is unchanged (25 / 0 / 22, upstream's). On `gsv1` the halo rows are 0.
- Visible effect: M1's selected `G` glyph is left in its unselected red. The text-background copy is
  unclipped, but the glyph is cairo-clipped to the footprint, so the restore wipes the glyph and the
  repaint never redraws it.
- Evidence: `F9_windows_noclip_repair.png`.
- `fix_broken_tiled_fill 1` made no difference.

**Fix.** On non-unix, after the footprint restore, repaint the whole selection unclipped. That is
idempotent, as the crew itself relies on in `select_inside`.

### L1. LIMIT: a `fast` single select (repair = 0) is not canonical

**What happens.** `xschem select ... fast` (without `nodraw`) paints in call order. A text's background
restore also wipes a neighbour's band.

**Repro `fastsel.tcl`.** Wire, then a text overlapping it, both with `fast`:

| | halo | bright | classic |
|---|---|---|---|
| wire, then text | 736 px | 230 px | 0 |
| reverse order | 881 px | 638 px | 0 |

Evidence: `F5_fast_select_noncanonical.png` (the wire band is cut across the text).

**Reach.** `open_sub_schematic`, `hi_descend_current`, `hi_descend_newwin` (one instance each), the
`unselect_attached_floaters` / attached-floater loops, and user scripts.

**Fix.** Repair `fast` calls too, or end every batch caller with one full stroke, as the rubber band
does.

### Nits and limits (no fix needed now)

- **Low zoom.** The screen-px band turns a dense sheet at zoom_full into orange blobs
  (`L_lowzoom_halo_390_vs_fallback_410.png`: left is a 390-instance halo drag, right is the 410
  fallback). That is a look question for stage B.
- **Fallback threshold.** It counts entries, not cost. A symbol with many texts costs far more than
  an nfet.
- **Large styled erases.** At more than 800 entries a styled erase is now a full-window copy on Linux
  too. Each drag frame wipes the window-only scope, hover and fly-line overlays (as upstream Windows
  already does).
- **Style resync on a partial redraw.** `sel_style_sync()` in a bbox-limited `draw()` re-reads the
  style but repaints only the bbox. If `selection_style` was changed without a full redraw, a later
  erase uses the new style on an old overlay. This is an edge case: the menu always redraws.
- **compare_schematics GCs.** Its scratch context never runs `free_gc`. That is pre-existing for all
  its GCs, and now two more leak per compare.

## What I tried that held up

- **Classic is byte-identical to `~/gsl0`** on 15 more states (`classic_seq.tcl`): mid-drag, rotate
  mid-move, a step after the rotate, abort, `unselect_all`, copy rubber band, rubber band
  select/deselect, a hover sweep and crosshair motion. All AE 0.
  - Non-vacuous: drag vs select 9891 px, rotate 9186, copy 3689, band 4213.
  - Its two stretch rows were vacuous (`enable_stretch` was unset there). Stretch is covered in the
    next item instead.
- **Residue sweep (`resid.tcl`), classic, bright and halo, every row 0 against a redraw:**
  - bus wire select, deselect, and drag+abort;
  - filled arc + filled polygon + dashed line + 0.8-size text, drag+abort and unselect;
  - **stretch** (`enable_stretch 1`, one wire end) drag+abort;
  - copy rubber band + abort;
  - zoom_in during a held move, then back to the anchor;
  - **expose** (a toplevel mapped over the canvas, then destroyed);
  - deselecting a wide text next to selected objects.
  - Non-vacuous: halo drag 39780 px, stretch 1162, copy 8345.
- **Rotate during a move (halo and bright):** abort equals the pre-drag state.
- **Italic, bold or oblique wide texts:** drag, abort and unselect all 0.
- **Pin (INST_PIN) marks:** select, deselect and `unselect_all` all 0.
- **Large drags** of 390, 410 and 826 instances (the halo path, the fallback, and the >800
  window-copy erase): abort 0 each time.
- **High-zoom instance drag:** 0.
- **Hover outline across a real click on the hovered object:** it survives (magenta 213 classic,
  194 halo).
- **New window (`tabbed_interface 0`) and new tab (`1`) opened after startup:** `gc_sel` paints
  `#ff8000`. After `toggle_colorscheme`, `#e05a00` with 0 old-colour pixels.
- **`--nogui` under `valgrind -q --error-exitcode=99`:** select, move, undo and `unselect_all` in all
  three styles, exit 0.
- **GUI valgrind memcheck on a 30-step mixed scenario:** 0 errors.
  - "Definitely lost" is identical to the base (3,585 bytes in 24 blocks on both).
  - No leak stack names a new symbol.
- **Non-cairo build (`HAS_CAIRO 0`)** of draw.c, move.c, select.c and xinit.c: the `-Wall -Wextra`
  warning set is identical to the base's.
- **compare_schematics under halo:** no crash.
- **Refuted: a false-edge band at bbox-limited redraws** (area margin only one line width beyond the
  clip). It was not reproduced: `setprop` under a selected enclosing rect gave 0.

## Left in place

- `~/gsv1`: the stage-A diff applied and built, for re-running the repros.
- `~/gsv2`: the Windows clip emulation build, for D7.
- The raw snapshots are in `selshot/V/out/`.

Delete these when no longer needed.
