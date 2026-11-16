# Stage A7 receipt: Bright with box (`brightbox`), now the default

Crew: stage-A7 crew, 2026-11-15. Clone `~/gsa8` = `e6b38ba83` plus `sel_on_e6b38ba83.patch`
(md5 `ba0d5a4e852ec1316e4cf8004cc2547f`), committed there as the local scratch commit `cf8626009`;
the A7 change is the working-tree diff on top of it. Base for "unchanged" comparisons: `~/gsa8b`
(`e6b38ba83`, no patch) and the pre-A7 build of `~/gsa8` (`cf8626009` built as is). **Nothing in
the main tree's `src/` was touched**; the only main-tree writes are this file, the two patches and
`A7-shots/`. All display runs were on private Xvfb displays `:286`–`:295` with openbox; nothing ran
on `$DISPLAY`, `:0` or `:99`.

## In plain English

- **The new look exists and is the default.** View → Selection look now has four entries:
  Classic, Bright, **Bright with box**, Halo. Bright with box is Bright plus a solid box in the
  selection colour around each selected object: the same box the dashed yellow hover outline
  draws, at the same width (`hover_highlight_width`), but solid and in the selection colour. A
  fresh session with no setting gets it; so does an empty or misspelled `selection_style`.
- **It draws correctly.** After every action the brief lists, the window was compared with a fresh
  full redraw of the same state, pixel by pixel. Every comparison was 0 pixels different, in dark
  and light, at six box widths, with fluid editing on and off, with and without cairo, and under
  valgrind.
- **Nothing else changed on screen.** Classic is pixel-identical to the untouched base clone;
  Bright and Halo are pixel-identical to the build before this stage, in dark and light.
- **It costs almost nothing.** On three real bundled pages, select-all and rubber-band release
  are 0.1–0.3 ms slower than Bright (the box is drawn once per selected object); hover and drags
  are within run-to-run noise of Bright. The box adds about 0.1 ms to the selection drawing of an
  8-device drag frame. The drag safety switch (which drops to a cheaper drawing when a drag is
  slow) never fired on any page in any styled look.
- **Two defects were found by this stage's own rows and fixed before delivery**, both only with
  fluid editing **off**, which is not the default: a wire stretched by a move got a straight box
  line cutting diagonally across its L-shaped stroke, and when the move was also rotated, the next
  frame left that diagonal on screen. See "Found and fixed during this stage".

## What changed, by symbol

- `src/xschem.h`: `SEL_STYLE_BRIGHTBOX`, the part bit `SELP_BOX`, `Xschem_ctx` fields `gc_selbox`
  and `sel_box_px`, the prototype of `hover_inst_rect()`; the comments over the style and text
  style say what brightbox is.
- `src/xinit.c`:
  - `create_gc()` / `free_gc()` create and free `gc_selbox`; `set_clip_mask()`,
    `sel_set_clip_rects()` and `sel_reset_clip_rects()` clip it with the other overlay GCs.
  - `build_colors()` gives it the selection colour and, beside the hover GC's own setting, the
    hover outline's width as a solid line (`sel_box_px` records that width).
  - `sel_style_sync()` knows the word `brightbox`; an unset, empty or unknown word now means
    brightbox (it meant halo). The text style `auto` means colour in brightbox, as in bright.
- `src/draw.c`:
  - `hover_inst_rect()`, factored out of `draw_hover_shape()`'s instance arm, is the one place
    that decides an instance's hover box; hover and brightbox both call it, so they cannot
    disagree. It also checks the symbol pointer before reading its type, which the old arm did
    not.
  - `inst_text_bbox()` takes a rotation and flip to add, so a label's box follows a rotated or
    flipped move; the hover passes none, so the hover is unchanged.
- `src/move.c`:
  - `draw_sel_entry()` draws `SELP_BOX` for every object type (table below); `sel_rect_out()` and
    `sel_line_out()` take it too.
  - New `sel_box_pass()`: the box gets its own pass and GC after the strokes and before the
    glyphs, in `sel_styled_draw()`'s full look and in its cheap drag look (which keeps the box).
  - `sel_entry_fp()`, the footprint every erase and repair uses, grows by half the box width plus
    one in brightbox, and measures the box with the strokes.
- `src/xschem.tcl`: the View → Selection look entry `Bright with box` between Bright and Halo
  (same `xschem build_colors; xschem redraw` command as its neighbours); `set_ne selection_style
  brightbox`; the comment block over the four looks.
- Comment-only: `src/actions.c`, `src/callback.c`, `src/scheduler.c`, `src/select.c` ("bright/halo"
  becomes "not classic").
- `doc/claude/FAQ.md`: Q94 (verbatim at the end).

## The box, per object type

| selected object | box |
|---|---|
| instance (device, subcircuit) | the symbol's box without its texts (`xx1..yy2`), as the hover |
| net label, pin, sheet label | the union of its visible texts, as the hover |
| floating text | its text box (`text_bbox()`, custom font honoured), as the hover |
| rectangle | its outline |
| polygon | its outline, without the point dots |
| arc | the arc itself |
| line | a line along it, never thick, as the hover |
| wire | a line along the wire's own stroke path (see below) |
| selected instance pin | none: the hover draws none either |

Where exact mirroring of the hover reads oddly, or does not show:

- **Wires and lines.** The box lies on the bright stroke itself, so at the default width it does
  not show; at a hover width above the stroke's it shows as a wider line along the wire.
- **A wire stretched by a move** (fluid editing off) is stroked as an L. Mirroring the hover
  exactly (a straight line between the ends) drew a diagonal across the L, so the wire's box
  now takes the stroke's own path. This is the one deliberate departure from the hover's
  geometry; the hover never draws a stretched wire, so there was nothing to mirror.
- **An instance's parameter texts** (W/L, nf, model name) sit outside its box, exactly as with the
  hover; the texts themselves are in the selection colour. Visible in `A7-shots/`.

## Found and fixed during this stage

Both came out of a rotated/flipped-move pose (`bbrot.tcl`) added to the rows during this stage;
both need fluid editing off, where a move draws stretched wires as Ls (`drawtemp_manhattanline()`,
with `orthogonal_wiring` on as the bundled rcs set it).

1. **Diagonal box across a stretched wire.** Any move with fluid off: the box was a straight line
   between the wire's moving and fixed ends, across the stroke's L. At width 1 a thin diagonal; at
   width 5 a thick one. A redraw drew the same, so the AE rows could not see it; it was seen in
   the snapshots. Fixed in `draw_sel_entry()`: the wire's box uses the stroke's own call.
2. **That diagonal left on screen.** In a move rotated mid-drag, the footprint (`sel_entry_fp()`)
   measured only the stroke, so erasing the frame left the box's diagonal behind: AE 165 at width
   1, 743 at width 5 (dark and light), row `r4_rot_again`. Fixed by measuring the box with the
   strokes, so the footprint holds whatever path the box takes. (With fix 1 in place the box's
   path is the stroke's, so fix 2 is now a guarantee rather than a repair.)

`B4` below is the build with both reverted, and shows the red.

## Broken on purpose: the rows can see a broken box

Each copy below is the final A7 build with one thing broken on purpose (`scr/sab.py`), built, run
through both row sets at box width 1 and 9 with fluid editing on and off, then restored from a
pristine copy (byte-compared with `~/gsa8`) and rebuilt. Non-zero rows only; every row not listed
was 0.

| copy | what is broken | rows that went red (AE px) |
|---|---|---|
| B1 | the box left out of the footprint (no pad) | width 9: `a1_select`, `a3_click_empty`, `a6_band`, `a18_final_unselect` 295 each, `r0_sel` 295; fluid off also `a9_drag_mid` 1019, `a11_esc` 475, and every `r*` row but `r5_end`, 259–1128. Width 1: none (a 1 px box lies inside Bright's own erase pad) |
| B2 | `gc_selbox` not clipped to the repair rects | width 9: `a8e_hover_then_select_near`, `a8f_hover_then_deselect_near` 81 each, fluid on and off. Width 1: none |
| B3 | an instance's box not displaced during a drag | fluid off, the rotated and flipped rows only (`r2`, `r3`, `r4`, `r6`, `r7`): 106–357 at width 1, 625–2476 at width 9. A plain drag is not red, because a redraw draws the same misplaced box; fluid on, none (a live-committed drag has no displacement). Hence the geometry probe below |
| B4 | this stage's two late fixes reverted | fluid off: `r4_rot_again` 165 at width 1, 1183 at width 9 |

**Geometry probe** (`bbgeo.tcl`, fluid editing off; it reads where the box is rather than comparing
with a redraw, since a misplaced box is redrawn misplaced): M1 selected and dragged by (30, 30);
count the selection-colour pixels on the left edge of the rest rect and of the displaced rect
mid-drag. Final build: rest 2/152, displaced 152/152. B3: rest 152/152, displaced 16/152. With
fluid on the final build gives rest 0/152, displaced 152/152.

## Correctness: window equals a fresh full redraw

Method: each row performs an action, snapshots the canvas, runs `xschem redraw`, snapshots again,
and scores the pixel difference (`magick compare -metric AE`). 0 means what was on screen is what a
full redraw draws. Page: the bundled sky130 `not.sch`, with one rectangle, line, polygon, arc and
floating text added; selected: an instance (M1), a label (p3), a wire, the text and the four
shapes. Snapshots are `import -window` of the canvas on a private Xvfb with openbox.

`bbrows.tcl`, 39 rows: select, deselect one, click empty, select-all, unselect-all, rubber band;
hover onto, inside and off a selected instance, onto a selected text and rectangle; a hover outline
and a crosshair each stamped over a selected object's box, then a select or deselect next to it;
drag mid and end; Escape-cancelled drag; Edit-menu undo and redo (each followed by `xschem redraw`,
as the menu does) and the U key; zoom in and out, wheel up and down; pan by command and by
middle-drag; property edits that resize a label and a FET; Expose by an override-redirect window
covering 30% and 80% of the canvas, and a selection change while covered; tab switch (new tab
with `flop.sch`, select there, back, forth, deselect), and a final unselect.

`bbrot.tcl`, 8 rows (added this stage): an instance, a label, a wire and a text selected, then a
move rotated (Shift-R), flipped (Shift-F) and rotated again mid-drag, the end, and a rotated and
flipped move cancelled with Escape.

Final build, brightbox, every run: **all rows 0**.

| variant | `bbrows` (39) | `bbrot` (8) |
|---|---|---|
| dark, box width 1 (the default) | 0 | 0 |
| light, width 1 | 0 | 0 |
| dark, width 0 (X's thin line) | 0 | 0 |
| light, width 3 | 0 | 0 |
| dark, width 9 | 0 | 0 |
| light, width 9 | 0 | 0 |
| dark, fluid editing off | 0 | 0 |
| light, fluid off, width 5 | 0 | 0 |
| dark, text style `own` | 0 | 0 |
| light, text style `own`, width 4 | 0 | 0 |
| no-cairo build, dark | 0 | – |
| no-cairo build, light | 0 | – |
| no-cairo build, light, fluid off, width 5 | – | 0 |
| under valgrind, light, width 3 | 0 | – |
| under valgrind, dark, fluid off, width 5 | – | 0 |

Bright, Halo and Classic ran the same 39 rows earlier in this stage: Bright and Halo all 0; Classic
gives `a2_deselect_one=22` and `a7b_hover_move_inside=2`, identical on the untouched base clone
`~/gsa8b`, so those are the base's own behaviour, not A7's.

## Identity: the other three looks are unchanged

The batch's full regression (`reg8.sh`: every pose of stages A2–A6, about 1400 snapshots per
style and scheme) was run on the A7 build and compared snapshot by snapshot, byte-identical PNG or
AE 0:

| look | scheme | compared with | identical snapshots |
|---|---|---|---|
| Classic | dark | `~/gsa8b` (untouched base) | 1400 / 1400 |
| Classic | light | `~/gsa8b` | 1400 / 1400 |
| Bright | dark | pre-A7 build | 1400 / 1400 |
| Bright | light | pre-A7 build | 1400 / 1400 |
| Halo | dark | pre-A7 build | 1400 / 1400 |
| Halo | light | pre-A7 build | 1400 / 1400 |

Brightbox has nothing to be identical to, so its regression run is read against Bright's on the same
build instead (`scr/bbvsb.py` compares every scored value of the two logs, 211 each): the same
values are zero and non-zero, pose for pose, in dark and in light. The non-zero ones (eight per
scheme) are non-zero in Bright too, so they belong to the poses, not to the box. Apart from
them, one pose (`clickhov`) exited 7 in two of the fourteen runs (A7 brightbox light, A7 halo
dark) with a `magick` read error: the pose writes one scratch file whose name is shared by all
nine parallel workers, so it is a harness race. Rerun alone, it exits 0 in both, and the halo
rerun's snapshots are identical to pre-A7's.

## Timing

Milliseconds per step, on the final build, as the median over six rounds of each round's median
over its repetitions. The four looks are interleaved within each
round, in an order reversed every other round, so drift lands on all four alike. Each
page ran alone on a private Xvfb (1400x1000, openbox) from a scratch copy of the bundled workarea,
with that workarea's own `cadence_style_rc` (crosshair and hover on, hover width 1, fluid editing
on). Each step includes an X round trip. Hover moves the pointer between two selected devices,
with 3 and then everything selected; select-all starts from nothing selected after a full redraw;
the rubber band sweeps a block of 10–50 objects from nothing selected; a drag of 1, 3 or 8 devices
is a move started with the `m` key, 20 motion frames and then Escape, split into the first four
frames (the ones the drag switch below times) and the rest.

**bgopamp** (sky130A `bandgap_opamp.sch`: 73 instances, 70 wires)

| action | classic | bright | brightbox | halo | brightbox range | bright range |
|---|---|---|---|---|---|---|
| hover, 3 selected | 0.8 | 1.0 | **1.0** | 1.1 | 0.9–1.0 | 1.0–1.2 |
| hover, all selected | 3.9 | 1.2 | **1.3** | 1.3 | 1.2–1.5 | 1.1–1.5 |
| select-all | 1.2 | 2.5 | **2.7** | 3.4 | 2.6–2.8 | 2.4–3.1 |
| rubber band, motion | 0.5 | 0.5 | **0.5** | 0.5 | 0.5–0.6 | 0.4–0.6 |
| rubber band, release | 0.7 | 1.1 | **1.2** | 1.2 | 1.1–1.3 | 1.0–1.3 |
| drag 1, first 4 frames | 5.4 | 5.6 | **5.7** | 5.6 | 5.5–5.7 | 5.4–5.9 |
| drag 1, later frames | 6.1 | 6.2 | **6.3** | 6.2 | 6.0–6.3 | 6.0–6.4 |
| drag 3, first 4 frames | 7.7 | 8.2 | **8.3** | 8.2 | 8.1–8.5 | 7.9–8.5 |
| drag 3, later frames | 7.7 | 8.0 | **8.0** | 8.0 | 7.9–8.2 | 7.8–8.1 |
| drag 8, first 4 frames | 10.9 | 11.7 | **11.7** | 11.9 | 11.4–12.2 | 11.4–11.8 |
| drag 8, later frames | 11.0 | 11.4 | **11.6** | 11.4 | 11.4–11.9 | 11.0–11.7 |

**sdfrbp** (ihp-sg13g2 `sg13g2_sdfrbp_2.sch`: 81 instances, 330 wires)

| action | classic | bright | brightbox | halo | brightbox range | bright range |
|---|---|---|---|---|---|---|
| hover, 3 selected | 0.9 | 1.4 | **1.5** | 1.4 | 1.3–1.7 | 1.4–1.5 |
| hover, all selected | 8.3 | 2.1 | **2.1** | 2.1 | 2.0–2.3 | 2.0–2.2 |
| select-all | 2.3 | 5.3 | **5.4** | 5.3 | 5.2–5.9 | 5.1–5.5 |
| rubber band, motion | 0.6 | 0.6 | **0.6** | 0.6 | 0.6–0.7 | 0.6–0.7 |
| rubber band, release | 0.7 | 1.3 | **1.4** | 1.5 | 1.3–1.5 | 1.3–1.5 |
| drag 1, first 4 frames | 12.0 | 12.2 | **12.3** | 12.3 | 12.3–13.5 | 11.8–12.5 |
| drag 1, later frames | 14.5 | 15.0 | **14.6** | 14.9 | 14.5–15.9 | 14.1–15.1 |
| drag 3, first 4 frames | 14.4 | 15.3 | **15.6** | 14.8 | 14.7–16.5 | 14.8–16.6 |
| drag 3, later frames | 18.6 | 19.0 | **19.0** | 18.7 | 18.8–21.0 | 18.9–21.0 |
| drag 8, first 4 frames | 24.8 | 25.3 | **25.1** | 25.0 | 24.3–28.6 | 24.8–27.7 |
| drag 8, later frames | 25.2 | 25.0 | **25.1** | 25.1 | 25.0–26.8 | 24.8–27.5 |

**predec4** (xschem_library `rom8k/rom2_predec4.sch`: 102 instances, 100 wires)

| action | classic | bright | brightbox | halo | brightbox range | bright range |
|---|---|---|---|---|---|---|
| hover, 3 selected | 0.9 | 0.9 | **0.9** | 0.9 | 0.8–1.1 | 0.8–1.0 |
| hover, all selected | 6.0 | 1.5 | **1.5** | 1.5 | 1.4–1.7 | 1.3–1.5 |
| select-all | 1.8 | 3.7 | **4.0** | 3.8 | 3.8–4.3 | 3.6–4.0 |
| rubber band, motion | 0.6 | 0.6 | **0.6** | 0.6 | 0.5–0.7 | 0.5–0.6 |
| rubber band, release | 0.6 | 0.8 | **0.9** | 0.9 | 0.8–1.0 | 0.8–0.9 |
| drag 1, first 4 frames | 5.9 | 6.1 | **6.2** | 6.2 | 6.0–6.4 | 5.9–6.4 |
| drag 1, later frames | 6.1 | 6.2 | **6.3** | 6.2 | 6.1–6.4 | 6.0–7.1 |
| drag 3, first 4 frames | 6.8 | 7.0 | **7.1** | 7.0 | 6.9–7.3 | 6.9–7.6 |
| drag 3, later frames | 7.0 | 7.1 | **7.3** | 7.2 | 7.0–7.4 | 7.0–8.0 |
| drag 8, first 4 frames | 8.2 | 8.5 | **8.5** | 8.7 | 8.4–8.6 | 8.3–9.0 |
| drag 8, later frames | 10.7 | 10.8 | **10.7** | 10.8 | 10.5–11.2 | 10.6–11.8 |

**In words.** Bright with box costs what Bright costs. Select-all and rubber-band release, which
draw the box once for every selected object, are 0.1–0.3 ms slower than Bright; hover and drags
are within run-to-run noise of it (±0.4 ms, with overlapping ranges). Every action on
`bandgap_opamp` and `rom2_predec4` is well under one 60 Hz frame (16.7 ms) in every look. On
`sg13g2_sdfrbp_2` the drags of 3 and 8 devices take 19–25 ms in **every** look, Classic
included (18.6 and 25.2 ms), so that time is the drag's own work, not the selection drawing,
which the probe below puts at about 1 ms.

**The selection drawing's own share** (an instrumented copy of the final build that logs the drag
switch's own measurement: the overlay's frame time, X server work included, for the first four
frames of each drag; two rounds of five drags per size, every page):

| page | look | drag 1 | drag 3 | drag 8 | worst frame | switch fired |
|---|---|---|---|---|---|---|
| bandgap_opamp | brightbox | 0.22–0.25 | 0.46–0.53 | 1.06–1.13 | 2.85 | 0 of 30 drags |
| bandgap_opamp | bright | 0.21–0.23 | 0.48–0.50 | 0.95–1.10 | 3.62 | 0 of 30 |
| sg13g2_sdfrbp_2 | brightbox | 0.20–0.28 | 0.47–0.53 | 1.06–1.20 | 2.65 | 0 of 30 |
| sg13g2_sdfrbp_2 | bright | 0.19–0.24 | 0.37–0.49 | 0.92–1.10 | 2.44 | 0 of 30 |
| rom2_predec4 | brightbox | 0.22–0.23 | 0.41–0.44 | 0.82–0.87 | 2.06 | 0 of 30 |
| rom2_predec4 | bright | 0.19–0.23 | 0.41–0.41 | 0.78–0.81 | 1.75 | 0 of 30 |

(medians of the two rounds, ms; Halo is in the same range, 0.23–1.27 ms medians, and did not fire
either.) The box adds about a tenth of a millisecond to an 8-device drag frame.

**The drag switch's threshold is unchanged**: the first 4 frames of every drag are timed
(`SEL_DRAG_PROBE`), and the second of them over 16.7 ms (`SEL_DRAG_FRAME_MS`, one 60 Hz frame)
switches the rest of that drag to the cheap look (`sel_drag_fallback()`). The timed interval now
includes the box pass, so the box counts toward the switch; the cheap look keeps the box (one
outline per object), so a switched drag still shows it. On these pages the overlay's own frame
never came near the threshold, so the switch never fired.

## Health

- **Warnings** (`scr/hw.sh`: every `OBJ` file of the pre-A7 and the final A7 source compiled in four
  configurations, warning lines kept with line and column stripped): cairo 6 / 6, cairo
  `-std=c89 -pedantic` 67 / 67, no-cairo 6 / 6, no-cairo `-std=c89 -pedantic` 67 / 67 (pre-A7 /
  A7); the warning text is identical in every configuration, and A7 adds no error line.
- **Valgrind** (`-q`, so any error is written): the two display sessions in the table above, and
  the headless transcript below on the cairo and no-cairo builds. Every log is empty.
- **Headless** (`--nogui --pipe`, `DISPLAY` unset, throwaway HOME): `ngA7.tcl` loads a page in
  each of classic, bright, brightbox, halo and an unknown word, and drives select, motion
  callbacks, move, undo, unselect, select-all, an Expose callback, redraw and a netlist, printing
  what the C side answers. Its transcript on the final build equals the pre-A7 build's line for
  line except the first, `DEFAULT selection_style=halo` → `brightbox`, which is the change. Both
  binaries ran from scratch copies of their trees: run from inside a clone, the headless instance
  box widths depend on where the binary sits, which is not A7's doing.
- **An rc line still wins over the new default**: an rc file setting `selection_style bright`
  (sourced at startup with `--rcfile`, the same site that sources `~/.xschem/xschemrc`) leaves
  `bright` in place on both builds; with no rc the A7 build answers `brightbox`. Run from the
  source tree xschem reads no user rc at all (`xschem::rc_name`'s comment), so for a source-tree
  user the line belongs in the `--script` rc; the FAQ says so.

## Not covered

- **The user's own screen and real hand input.** Every pixel here is Xvfb with openbox and every
  gesture is synthesized (`event generate`). The look is a pixel deliverable: the suites are
  green, and it wants the user's eyes on their own X server.
- **`run_suites.sh` / T1 suites** were not run (not in this brief; T1 is the driver's).
- **The blog post** the user asked for is not in this stage's brief.
- **Hover widths** tested: 0, 1 (default), 3, 4, 5, 9. Not tested: widths above 9.
- **Pages:** correctness on one bundled page plus `flop.sch` for the tab rows; timing on three.

## Housekeeping

- **Patches** (in this folder):
  - `A7-incremental.patch` = `git -C ~/gsa8 diff` (the A7 change on top of the scratch commit
    `cf8626009`), md5 `6ad19b81c163b7481da1aafa1e074900`. 10 files, +197 / −67. It reverse-applies
    to `~/gsa8`, and `git apply --check` passes against the main tree's current working state
    (whose `git diff -- src` has md5 `ba0d5a4e852ec1316e4cf8004cc2547f`, the same as
    `sel_on_e6b38ba83.patch`). Checked only; nothing was applied there.
  - `A7-combined.patch` = `git -C ~/gsa8 diff e6b38ba83` (the selection batch plus A7), md5
    `8db50b9272a724e7c903cee676d6ee3b`; it applies to `~/gsa8b` (`e6b38ba83`).
- **Screenshots** (`A7-shots/`, about 1 MB): window 1200x900, so the canvas images are 1200x832;
  page sky130A `n_diffamp.sch` with M1, M3, R1 and one wire selected.
  - `{classic,bright,brightbox,halo}_{dark,light}.sel.png`: one per look and scheme.
  - `composite_{dark,light}.png`: the four looks side by side, the same crop of each.
  - `brightbox_{dark,light}.hover.png`: the pointer on M1, which is selected; the dashed yellow
    hover outline lies exactly on M1's solid box.
  - `brightbox_stretched_wire_fluid_off_before_after.png`: fluid editing off, mid-move, box width
    5 (wider than the default 1, so the wire boxes show): before and after this stage's wire-box
    fix.
  - The final build's screenshots were retaken and are byte-identical to these.
- **`~/gsa8`**: scratch commit `cf8626009` plus the A7 working-tree diff, built (cairo), binary
  current with its source. `src/xschem.preA7` is deleted. **`~/gsa8b`**: `e6b38ba83`, built,
  unmodified. Neither has `*~.sch` or `untitled*` backups (the only match is the tracked
  `doc/claude/specs/untitled_reuse.md`).
- **Displays**: Xvfb and openbox on `:286`–`:295` stopped by the pids recorded at start, each
  checked against its command line; none is left, and no lock file remains.
- **Scratch** (`scratchpad/selA7/`): trimmed to scripts and text logs (about 11 MB). Row sets
  `reg/a7/bbrows.tcl`, `reg/a7/bbrot.tcl`, `reg/a7/bbgeo.tcl`; scorers `reg/a7/score.sh`,
  `reg/a7/geoscore.sh`; broken copies `scr/sab.py`, `scr/sab2.sh`; identity `scr/idq.sh`,
  `reg/scr/ident.sh`, `scr/bbvsb.py`; timing `tim/scr/`; headless `reg/a7/ngA7.tcl`.
- **Left in place**: `/tmp/xschem_emergencysave_*` directories from this afternoon, some
  presumably from runs this stage killed (`not_*`, `flop_*` are this stage's pages), but the
  directory names do not say whose they are and other crews share `/tmp`, so none was deleted.
- **Main tree**: only this file, the two patches and `A7-shots/` were written. Its `src/` was
  not touched, rebuilt or applied to.

## FAQ entry (verbatim, in the patch)

```markdown
## Q94. Selected objects now get a solid box. How do I get Halo back, or Bright without the box?

- **Asked:** 2026-11-15
- **Project state:** branch `fluid-editing` at `e6b38ba83`, plus the selection-look
  batch (`doc/claude/selection_look_batch/`), whose stage A7 added **Bright with
  box** and made it the default.

**Pick the look from the menu: View → Selection look.** It has four entries:
Classic, Bright, Bright with box (the default) and Halo. The menu applies your
choice at once.

- **To keep a look across sessions,** add one line to your rc file:
  - `set selection_style bright` for Bright without the box;
  - `set selection_style halo` for Halo;
  - `set selection_style classic` for the old look.

  For an installed xschem the rc file is `~/.xschem/xschemrc`. Run from the source
  tree, xschem reads neither `./xschemrc` nor `~/.xschem/xschemrc`, so put the line
  in the file you start it with `--script` (for the PDK launchers,
  `<pdk>/cadence_style_rc`).
- **Typed in the command window** instead of picked from the menu, the choice
  takes effect on the next redraw.
- **Halo's text.** In Halo, a selected object's text keeps its own colour, with a
  thin selection-colour band around the letters. For plain selection-colour
  letters instead, also add `set selection_text_style colour`.
- **The box** is the hover outline's box (the dashed yellow one), drawn solid in
  the selection colour and as wide as `hover_highlight_width`. A wire's or line's
  box lies on the bright stroke itself, so on those it does not show.
```
