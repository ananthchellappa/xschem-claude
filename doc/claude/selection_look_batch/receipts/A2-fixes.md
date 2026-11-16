# Stage A2 receipt: fixes for the stage-A verify findings, the text-style variant, composites

Crew: stage-A2 fix crew, 2026-11-15. Base: `e3c43487e` (pristine clone `~/gsl0`). Stage-A red bed:
`~/gsv1` (not edited by this crew). Windows-emulation build: `~/gsv2`. All edits are in the main
tree, **uncommitted** (PLAN.md holds stage A until the user's stage-B look).
`git diff --stat`: 7 files, `src/{callback,draw,move,select,xinit}.c`, `src/xschem.h`,
`src/xschem.tcl`.

## How it was measured

- **Display.** Every GUI run was on this crew's own Xvfb `:271` (1920x1080x24) with openbox, with
  `DISPLAY` unset in the calling shell, `GUI_GATE=0`, and a throwaway `HOME` per run. Never `:99`,
  never the user's screen, never T1.
- **Repros.** The verifier's own scripts (`fillrect`, `partial`, `scoperep`, `xhair`,
  `customfont`, `fastsel`, `instzoom_hide`, `winemu`), plus this crew's `expo*` (Expose) and
  `ovl*` (overlay compared with a full redraw).
- **Pixels.** `magick compare -metric AE` against a full `xschem redraw` of the same state, or
  against the unselected canvas, as each repro defines.
- **Red / green.** Red is `~/gsv1`, the stage-A prototype. Green is this tree's final binary
  (no `.c`/`.h` newer than `src/xschem`; `make -q` is clean).
- **Harness.** Scripts and raw logs are in
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A2/{scr,out}`.
  That is scratch, so it is not durable.

## Findings → fixes

The fix underneath D3, D4, D6 and L1 is the same, so here it is once. **The styled overlay is
now kept right by repair, not by incremental painting.**

- **A select or deselect only records damage.** It adds the object's screen footprint to a
  damage list of up to 16 rects (`sel_mark_object` → `sel_pend_add`, `xctx->sel_pend`). This is
  O(1), and nothing is painted at that point.
- **One repair runs per idle.** `sel_overlay_flush` runs from `Tcl_DoWhenIdle` (`sel_idle_cb`),
  or immediately for hover, crosshair, snap cursor and Expose. It does three things:
  1. copies each damaged rect back from `save_pixmap`;
  2. repaints only the selection entries whose footprint meets a rect (`sel_paint_entries`,
     culled by `sel_entry_fp` + `sel_rect_hits`), clipped to the rects;
  3. repaints every other window-only overlay in `draw()`'s order (`sel_paint_others`): the
     scope outline, hover outline, fly-lines, crosshair, snap cursor and wave highlight.
- **The result is canonical.** A click, a hover change or a crosshair motion leaves the window
  equal to a full redraw, whatever the click order.
- **A full `draw()` drops the list**, since it repaints everything anyway.
- **Classic is untouched.** Every new path is guarded by `sel_style_eff() != SEL_STYLE_CLASSIC`.

| finding | fix (symbols) | red (`~/gsv1`, halo) | green (final, halo and bright) |
|---|---|---|---|
| **D1**: the halo own-pass repaints a selected fill over its contents | `sel_own_fill_skip` (draw.c): the own pass skips any fill larger than the band in both dimensions. A smaller fill, such as a pin square, lies wholly under its own band, so it hides nothing the band did not | `partial`: text **889**, wire **489** | text **0**, wire **184**. The 184 is upstream: it is the same in classic and on `~/gsl0`, because the junction dot is not drawn by a partial redraw |
| **D2**: fill residue after drag, abort and unselect | D1's fix, plus `sel_styled_erase` restoring each entry's whole footprint (`sel_entry_fp`, a superset of anything painted for it) in one copy | `fillrect` back-to-anchor / abort / unselect: **42287 / 40486 / 41357** | **0 / 0 / 0** |
| D2 with `hide_symbols 2` | as above. An instance's footprint is its full displaced bbox | `instzoom_hide` (3 states): **1777 / 1613 / 1616** | **0 / 0 / 0** |
| **D3**: a click cuts the scope outline | `sel_paint_others` repaints `draw_scope_highlight()` (and hover, fly-lines, crosshair, snap cursor) inside the repaired rects | `scoperep`: white pixels **11/30** (bright 19/30) | **30/30** after select and after deselect. The select-by-text sub-repro is AE **0** |
| **D4**: the crosshair is cut by every selected text on each motion | the crosshair and snap cursor are now damage too (`xhair_damage`, `snapc_damage` in callback.c). Their old and new lines are repaired at once and re-stamped last (`overlay_paint_xhair`, `overlay_paint_snapc`). Classic keeps its own order | `xhair`: AE **153** | **0** |
| **D5**: a custom font leaks into the repair of other texts | `select_text` records the damage **before** `set_text_custom_font()`. The repair's `draw_sel_entry` sets and restores each text's own font. The cairo clip is now per text (`sel_cairo_text_clip`, below) and no longer a save/restore spanning several texts | `customfont` select / deselect: **1096 / 1678** | **0 / 0** |
| **D6**: performance | see the timings section | see the table | see the table |
| **D7**: correctness rests on `XSetClipRectangles` (a stub on Windows) | `SEL_REAL_XCLIP` (xschem.h, keyed on `__unix__`). Without a real clip, `sel_overlay_flush` repaints **every** selected entry unclipped after the copies. That is idempotent over its own overlay, and the rects themselves were just restored | `~/gsv2` emulating stage A, `winemu`: halo **6 / 139 / 6**, bright **0 / 76 / 0** | **0 / 0 / 0** on both, and every repro above also **0** under emulation (`emufin_*` logs) |
| **L1**: `fast` single select is not canonical | `fast` now records damage like any select. Only `fast & 2` (nodraw) skips it, so the idle repair makes a `fast` batch canonical | `fastsel` (3 states): halo **736 / 881 / 963**, bright **230 / 638 / 637** | **0 / 0 / 0** |

### A new defect found and fixed: cairo antialiases a glyph run differently under a multi-box clip

The first repair implementation left a few pixels per selected text after an Expose: AE 24 and
51 in two Expose repros, and 24 on the D5 deselect.

- **Cause.** Cairo renders a glyph run differently in two cases: when the run's extents straddle
  more than one box of the clip region, or when one box cuts through the run. A **single** clip
  box that contains the whole run is dropped by cairo, so the run then renders exactly as it
  would unclipped. X strokes clip exactly, so only text is affected.
- **Fix, part 1.** `sel_cairo_text_clip` (draw.c, called from `draw_string_cairo` when it draws
  to the window during a repair) clips each text to the one pending rect holding its background
  box. It skips a text that meets no rect. It falls back to a union clip only when no single
  rect holds the text. `sel_cairo_clip` records the rects; it no longer does a global
  `cairo_save`/`cairo_clip`.
- **Fix, part 2.** `sel_close_texts` (move.c) grows the damage list until every selected text it
  meets lies wholly inside one rect. It stops after at most 8 rounds; if the list has not
  settled by then, the repair covers the whole window. It runs only with a real X clip.

Sabotages, built in `~/gsv2` with real clipping, then restored with `cp` and checked with `cmp`:

| sabotage | effect |
|---|---|
| **S1**: per-text clip disabled | Expose e1 **24**, e3 **51**, D5 deselect **24** |
| **S2**: closure disabled | e1 **24**, e3 **20**, expo3 **16** |
| final tree | e1 / e2 / e3 / expo3 all **0** |

### Overlay compared with a full redraw (`ovl*`, new this stage)

| gesture | halo and bright, final | classic (upstream) | `~/gsv1` halo |
|---|---|---|---|
| hover over a text | 0 | 388 | 669 |
| hover over a wire | 0 | 475 | 318 |
| crosshair motion | 0 | — | — |
| crosshair full-span motion | 0 | — | — |
| plain click | 0 | — | — |

- **Shift-click differs by 401 px. This is not repair residue.** The 401 px are the 9x9
  snap-cursor diamond at the clicked wire's endpoint. The live window shows that diamond while
  Shift is held (`draw_snap_cursor(2)` in the motion and button handlers). The full redraw used
  as the comparison drops it: `draw()` sets `snapc_shown = 0`, and the diamond comes back on the
  next motion.
- **Classic behaves the same way.** A redraw there also paints over the snap cursor.

## D6: timings

**Setup.**
- Xvfb `:271`, a 900x700 window. Medians of 3 runs (4 for classic), in ms.
- "classic" is `~/gsl0`. "A" is the stage-A prototype (`~/gsv1`). "A2" is this tree.
- Classic on this tree was also measured, and is within noise of `~/gsl0`.
- 1600-FET = `perf2`, everything selected. 826-inst = `perf` / `perf3` on an 826-instance sheet.

| metric | classic | A halo | **A2 halo** | **A2 bright** | A2 halo / classic |
|---|---|---|---|---|---|
| 1600-FET hover change | 10.04 | 28.59 | **1.34** | 1.17 | 0.13x |
| 1600-FET crosshair motion | 16.45 | 46.85 | **1.14** | 1.03 | 0.07x |
| 1600-FET crosshair full-span motion | 16.97 | 45.05 | **4.98** | 4.95 | 0.29x |
| 1600-FET unselect all | 9.51 | 6.66 | 1.04 | 1.04 | 0.11x |
| 1600-FET redraw, all selected | 14.78 | 20.93 | 19.23 | 17.41 | 1.30x |
| 1600-FET select all | 7.31 | 16.20 | 12.87 | 11.99 | 1.76x |
| 826-inst hover change | 9.86 | 22.10 | 1.28 | 1.27 | 0.13x |
| 826-inst crosshair motion | 14.82 | 33.60 | 0.76 | 0.84 | 0.05x |
| 826-inst crosshair full-span | 16.85 | 31.74 | 17.56 | 16.54 | 1.04x |
| scripted one-at-a-time select, K=100 | 11.30 | 31.75 | 9.47 | 9.79 | 0.84x |
| K=200 | 19.66 | 88.08 | 17.89 | 17.27 | 0.91x |
| K=400 | 38.86 | 264.52 | 44.21 | 34.32 | 1.14x |
| K=826 | 74.46 | **796.38** | **68.03** | 70.40 | 0.91x |
| select inside (all) | 5.50 | 23.38 | 14.06 | 10.56 | 2.6x |
| select all (826) | 4.83 | 12.32 | 12.86 | 10.96 | 2.7x |
| single-click deselect | 0.70 | 3.23 | 1.03 | 0.90 | 1.5x |
| drag, ms/step, K=390 | 6.88 | 9.03 | 5.76 | 5.43 | 0.84x |
| drag, ms/step, K=826 | 5.11 | 4.66 (cheap look) | 10.69 (styled) | 9.16 | 2.1x |

**What the table shows.**
- **The HARD requirement is met with a wide margin.** Hover change and crosshair motion on the
  1600-FET select-all are now 7–13 % of classic's cost (the requirement was ~1.5x).
- **Scripted selection is linear.** Stage A grew quadratically (796 ms at K=826); A2 costs about
  0.08–0.11 ms per object, like classic.
- **What is still slower than classic is one-shot**, not per-motion: select all, select inside,
  a redraw with everything selected, and a styled drag frame. The worst case is about 2.7x, on
  operations that take 5–14 ms.

### The >400-entry drag threshold is replaced by a measured frame time

**Why the entry count was wrong.** It counts entries, not cost, as the verifier's nit said.
Measured on two sheets:
- **826-instance sheet:** a styled drag frame costs **10.9 ms**. That is inside one 60 Hz frame,
  yet the old threshold dropped this case to the cheap look.
- **1600-FET grid with a 3500-unit-wide view:** a styled frame costs **28.8 ms**. This case
  needs the fallback.
- **A count cannot tell the two apart**, and a fitted linear cost model (entries and texts
  against ms) did not fit the calibration data either.

**What replaced it.** In `sel_styled_show` (move.c):
- the first `SEL_DRAG_PROBE` (4) styled frames of a drag are timed with `sel_frame_clock`
  (xinit.c: `XSync`, then `Tcl_GetTime`; `XFlush` off unix);
- the **second** frame over `SEL_DRAG_FRAME_MS` (16.7 ms) switches the rest of that drag to the
  cheap look (`xctx->sel_drag_cheap`);
- `sel_drag_start()` resets the probe at both `STARTMOVE` and `STARTCOPY`.

Calibration on the 1600-FET grid, ms per drag step at K=1600, with the view width in schematic
units. "No fallback" is a calibration build that never falls back:

| view width | classic | halo, no fallback | **halo, measured fallback** | look kept |
|---|---|---|---|---|
| 2300 | 4.04 | 11.64 | **11.69** | styled (under budget) |
| 3500 | 7.79 | 28.76 | **9.35** | cheap |
| 5000 | 9.67 | 22.65 | **10.53** | cheap |
| 826-inst sheet, K=826 | 3.97 | 10.86 | **10.85** | styled |

- **Abort leaves nothing.** Light and heavy drag-and-abort (`bigdrag`, `bigdrag2`): AE **0**
  against the unselected canvas, in both looks.
- **The existing >800-entry full-window erase is kept.** That is upstream's behaviour and is why
  classic is cheap at K=1600.

## TASK 2: `selection_text_style`

- **What it is.** An internal Tcl variable, `set_ne selection_text_style colour` in
  `xschem.tcl`, with a comment. It is read by `sel_style_sync` into `xctx->sel_text_style`.
  - `colour` (default, and any unknown word): glyphs in `selection_color`.
  - `own`: glyphs keep their own colour (`SELP_GLYPHOWN`) over a band of selection colour that
    follows the letter outlines (`SELP_TXTBAND`, stroked through `cairo_text_band_w`).
- **Where it applies.** In **both bright and halo**; classic ignores it.
  - Without cairo, `sel_text_band_px()` returns 0, so `own` falls back to `colour`: there is no
    outline to stroke.
- **The band is fixed at 1 px**, independent of the halo width.
  - This was chosen by comparing images. A band of `halo − 1` (2 px at the default) closed the
    gaps between letters at the default text size, and the text read as a smudge.
  - `sel_entry_fp` and the text closure include the band in each text's footprint.
- **No menu entry**, because the user has not ruled. The "Selection look" View submenu offers
  only `selection_style`.
- **Measured.** Every repro above is also AE 0 with `selection_text_style own`.

## Composites

All composites are in
`/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A2/composites/`.
I looked at each one with Read before reporting.

- **`composite_{colour,own}_{dark,light}.png`**
  - Rows: M1 selected / M1 + gate wire + floating text / M1 + scope outline.
  - Columns: classic | bright | halo.
- **`zoom3_{colour,own}_{dark,light}.png`**: halo with M1 selected, at zoomed-out, default and
  zoomed-in levels.

What the composites show:
- **Text style.** In `own`, `nf=1` and `1 x W_N / L_N` keep their yellow-green glyphs with a thin
  orange edge. In `colour` they turn orange. The scope outline reads on top in every style.
- **Low zoom.** At the zoomed-out level the halo band dominates small symbols. That is a stage-B
  look question, not a defect.

## Classic is unchanged

On the **final** binary, against `~/gsl0`:
- the verifier's 15-state `classic_seq` (select, drag, rotate mid-move, abort, unselect, stretch,
  copy, rubber band, hover, crosshair), on the **dark and light** schemes: **30 of 30 states AE
  0**;
- the stage-A crew's 6 lookshot shots (3 cases × 2 schemes): **6 of 6 AE 0**.

## Warnings

There are **no new compiler warnings** in any of four builds:
- cairo, default flags;
- cairo, `-std=c89 -pedantic`;
- non-cairo, default flags;
- non-cairo, `-std=c89 -pedantic`.

Base and this tree produce identical warning output in each configuration. The non-cairo build
was confirmed to link without cairo.

## Suites (on `:271`, `GUI_GATE=0`)

Every suite result is **identical to `~/gsl0`** line for line, except the throwaway-home path.

| run | result | notes |
|---|---|---|
| display arm, 31 selection suites | **28/30 passed, 1 skipped** | `test_select_at` (5 FAILED) and `test_cadence_drag` (2 FAILED) fail identically on base. `test_expose_repaint` self-skips (`no X`) on both |
| counted arm (`--nogui`), 34 suites | **19/24 passed, 10 skipped** | the 5 `NORESULT`s are the same on base: `test_hover_highlight`, `test_hover_selection_repair`, `test_select_at`, `test_cadence_drag`, `test_wire_complete_with_selection` |
| source-scanning suites, display arm (10) | **10/10** | `test_callback_argc`, `test_headless_guards_xarm_1492`, `test_del_negative_arg`, `test_ev_precision_bound_1606`, `test_annot_declutter_1244`, `test_backing_store_0413`, `test_snprintf_fmt_1608`, `test_nh_angle_render`, `test_hilight_case_senders`, `test_no_untitled_litter` |
| the same 10, counted arm | **7/9, 1 skipped** | the same as base (`test_annot_declutter_1244` and `test_nh_angle_render` give `NORESULT` on both) |

## What I could not do, or did not do

- **No run on `:0` or on the user's real X server.**
  - The drag probe adapts to the machine, but its behaviour there is unmeasured.
  - D7 is emulated, not run on Windows.
- **The drag look is time-dependent.** Under load, the same drag can switch to the cheap look,
  so a pixel test taken mid-drag on a heavy selection is not deterministic in bright or halo.
  Classic is unaffected.
- **No new suites.** Fences for the damage list, the closure, the fill rule and the text style
  are stage C's job. Today they are guarded only by the scratch repros listed above.
- **`test_expose_repaint` self-skips** on both trees, so the Expose path is measured only by this
  crew's `expo*` repros.
- **Not fixed (pre-existing):** the `compare_schematics` scratch context never calls `free_gc`,
  so two more GCs leak per compare. Compare keeps the classic overlay
  (`sel_style_sync` forces it).
- **Fixed, from the verifier's nits:** style resync on a partial redraw. `draw()` now calls
  `sel_style_sync()` only on a full draw, so a bbox-limited draw can no longer switch styles
  under a live overlay.
- **Stray files removed.** My perf runs had written an `untitled~.sch` backup at the repo root
  and in `~/gsl0`, `~/gsv1` and `~/gsv2`. These are gitignored; all four are removed.
- **State of the clones.**
  - `~/gsv2` = this tree's final `src/` plus the two Windows-emulation switches
    (`SEL_REAL_XCLIP 0` and the two `#if 0` in `set_clip_mask`).
  - `~/gsv1` and `~/gsl0` have no source edits from me.

## Decisions that are the USER's (described, not taken)

1. **Text style: `colour` or `own`.** The default stays `colour`, which is what the user has seen
   so far. Compare `composite_colour_*` with `composite_own_*`.
2. **If `own` is chosen, the band width.** It is fixed at 1 px here. Wider bands were tried and
   read as a smudge.
3. **Whether the text style gets a menu entry**, or stays a setting only.
4. **The default `selection_style`.** PLAN records halo as ruled. The composites are the basis for
   confirming it at stage B.
5. **The low-zoom halo look.** At zoom-out, the band dominates small symbols (`zoom3_*` left
   panel). Whether to thin the band with zoom is a look call.
6. **Whether a drag may switch to the cheap look partway** when frames are slow (budget 16.7 ms,
   2 of the first 4 frames). The budget value is internal engineering. That the look can change
   mid-drag on a slow machine is something the user would see.
