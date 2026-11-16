# Stage M1-verify receipt: the merged A6 + A5b tree

**Verdict: SAFE WITH LIMITS.** No defect found in the merged tree. Every limit below was already
declared by A5b or A6, or is a base limit classic shows too, except two small new notes (F2, F3)
that change nothing the user sees.

**In plain English.** The main tree now holds both of the last two stages: A5b's fix for knowing
which tab the canvas shows, and A6's per-label choice between the outlined look and the plain
selection-colour look, with the user's 16 px cut-off. I built it three ways (normal, Windows
emulation, no cairo) and attacked it. The two halves do not interfere: every picture the merged
tree draws in A5b's own configuration is pixel-identical to A5b's tree (1400 of 1400 snapshots on
Linux, 1400 of 1400 on the Windows emulation), and every place A6's code meets A5b's
bookkeeping gave the right picture. The 16 px cut-off behaves as ruled: labels drawn at 16.5 px
get the outline, labels at 15.5 px are plain, a mixed selection gets each right, and moving,
dragging, zooming, hovering and deselecting never leave a label half-redrawn. Classic is
unchanged byte for byte. valgrind found nothing in 54 headless runs, 27 display
runs on the merged builds (5 more on base) and 161 row runs. The selection suites give exactly base's verdicts, check for check.
Timing: on a 1600-FET sheet every hover, crosshair and rubber-band step stays at 0.5-2.3 ms (base
classic 2-15 ms), the 16 px cut-off makes selecting labels between 12 and 16 px cheaper than
A6 was (4.0 against 5.8 ms for 1600 FETs), and nothing is slower than A5 beyond the spread
between repeats.

Crew: stage-M1-verify, 2026-11-15, independent verifier. Base `bd14668b9` (pristine `~/gsl0`).
Nothing was committed, pushed or stashed; the only file written in the main tree is this one.

## What was verified, and how

- **The tree.** `git -C ~/dev/xschem-claude diff -- src | md5sum` = `f616df1ef1ff88e31b382f7b11c7e87f`
  at the start and at the end (re-checked at 15:08, after the housekeeping). Built from `bd14668b9` plus that diff in `~/gsm`
  (cairo, real X clip), `~/gsmn` (non-cairo; same diff), `~/gsmw` (Windows emulation: the diff
  plus `SEL_REAL_XCLIP 0` and the two `#if 0` in `set_clip_mask()`, as A5b did; its diff md5
  `420eeb0aa5adfda5c6ca46f0b14b0b10`). All three configure and build rc 0.
- **Comparators** (read and run only): `~/gsl0` (base, classic), `~/gsa5`/`~/gsa5w` (A5),
  `~/gsa6`/`~/gsa6w`/`~/gsa6n` (A6, 12 px), `~/gsa7`/`~/gsa7w`/`~/gsa7n` (A5b).
- **Displays.** My own Xvfb + openbox on `:286`-`:295` only, each checked free first. `DISPLAY`
  unset in every calling shell; headless runs under `env -u DISPLAY`. Every run had
  `GUI_GATE=0`, a throwaway `HOME`, and a cwd in a throwaway scratch directory (never a tree
  root). The data the poses load (`sky130A`, `xschem_library`, the cadence rc chain) is one copy
  in scratch shared by every build, so a title block or path never differs between builds.
- **Pixels.** `magick compare -metric AE`. "pre" = the screen before the step, "R" = a full
  `xschem redraw` of the same state; "noted" = AE(pre, after), "right" = AE(after, R).
- **Scratch.** `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/V6/`
  (below `V6/`). Poses are A5b's and A6's, copied with paths changed; new ones are
  `V6/r16/rows16.tcl` (A6's rows re-posed at the 16 px cut-off), `V6/scr/v8_early.tcl`,
  `V6/scr/v8_offtext.tcl`, `V6/scr/v8_hide.tcl`, and `V6/scr/reg8.sh` (A5b's full regression
  plus five scripted-Expose poses and ten extra poses). Scratch, not durable.

## 1. The merge

- **Equivalence.** `receipts/A5b-incremental.patch` and `receipts/A6-incremental.patch` were
  each applied on top of the A5 diff, in both orders (`V6/merge/a6b5`, `V6/merge/b5a6`): both
  orders give identical files, and both equal the main tree's `src` except for the one ruled
  edit, `SEL_TEXT_OWN_PX` 12.0 → 16.0 (`xschem.h`) with `selection_text_own_px` 12 → 16
  (`xschem.tcl`) and their comments.
- **The seam.** A6's `sel_cairo_bbox_clip()` lift sits in `sel_overlay_flush()` after A5b's
  `sel_pend_full()` / `sel_off_canvas()` decision and around the pastes, so A5b's pasted-rect
  bookkeeping (`sel_note_paste()` on each `MyXCopyArea()`) is untouched by it.
- **A5b's configuration is unchanged by the merge.** Every snapshot of the full regression
  (`reg8`: 1400 snapshots over `V6/out`, `V6/r/out`, `V6/r/a2/out`) in halo `colour` (the look
  A5b was built in) is pixel-identical between `~/gsm` and `~/gsa7` (1400/1400), and between
  `~/gsmw` and `~/gsa7w` (1400/1400). Every score line in the two regression logs is the same.
- **A6's configuration, as far as A6 could draw it.** With the cut-off at 0 (`own` on every
  text, A6's forced own) `~/gsm` against `~/gsa7` own differs in 6 snapshots, all from A6's
  removal of A5's double-painted pin names (`a5_canvas` g1h 56 px, `v5_xh2` x2 2, `v7_cov` mid
  36, `v7_thr` S315_m/T315_m 42, i.e. antialiased pin-name edges). With the cut-off at 12,
  `~/gsm` against `~/gsa6` differs in exactly the 50 snapshots A5b fixed (`v5_realwin` R1/R4,
  `v5_full` F1/F3, `v5_cov` c1/c11/c1c/c1e/c5b/c5c, `v7_cov` k17 to rnd, `v7_thr` T316-T625 and
  S316/S317 with their `_m` legs, `v7_wsel` s3/s5/s6, `v7_dw` ip1, the 3-px `pline` dot, g1h,
  tm1b), and `~/gsm` at 0 against `~/gsa6` at 0 differs in the same 50. So the merged tree is A6
  plus A5b's fixes and nothing else.
- **Cross-effects attacked:**
  - *A6's text mark in a tab not on the canvas* (`v8_offtext`: `xschem setprop text` on a
    selected text in `t1` after a dr 0 switch, then exposes): the change is confined to the
    text's own footprint (about 127x21 px) in halo auto and own, bright, `~/gsa7` colour and own,
    `~/gsmw` and `~/gsmn`. After a whole-window Expose and a reselect the screen differs from its
    redraw by 19 px in every build, classic `~/gsl0` included (a base residue); after a deselect,
    0.
  - *A6's clip lift during A5b's Expose repair*: A2's five scripted-Expose poses (`expo` to
    `expo5`: an Expose over M1, the whole window, a corner; staircases of small Exposes across a
    selected text and a new text; the same Expose repeated), every snapshot against the screen
    before the Exposes: 0 in all 105 score lines (21 regression runs, 13 of them on merged builds). The real-window Exposes are
    in section 4.
  - *A5b's coverage with A6's band footprints* (`v7_thr`, `v7_cov`, `v5_cov`, `v5_full`,
    `v5_realwin` under halo auto): the same pattern as A5b's tables with A6's halo size (5500 px
    instead of 5270), in section 4.
  - *`hide_symbols 2`* (`v8_hide`): no ghost texts; the select against its redraw is 0 in every
    build.
- **Compiler warnings.** `~/gsm` against `~/gsl0`: cairo 6 / 6, `-std=c89 -pedantic` 67 / 67,
  non-cairo 6 / 6 and 67 / 67, `~/gsmw` 6; the same warnings line for line.

## 2. The 16 px cut-off

Rows: `V6/r16/rows16.tcl`, A6's rows re-posed with every probe size moved to the new cut-off
(`HI` = 16.5 px, `LO` = 15.5 px rendered; `V_THR` moves both). M1 (`nfet_01v8`) selected with
its labels and floating texts, halo, dark, `~/gsm`. "d" = the screen after the change against a
full redraw of it, "du" = the same after a deselect.

| row | what | figure |
|---|---|---|
| A | M1 with every label (pins too) at 16.5 px or more and a 20 px text, vs forced own | **0** (forced colour differs by 1172) |
| B | M1's labels and a text at 15.5 px, vs forced colour | **0** (forced own differs by 1002) |
| C c1 | mixed: M1's labels at 16.5 px, its pin labels below, a 16.5 px and a 15.5 px text; the 16.5 px part vs forced own / the 15.5 px part vs forced colour | **0 / 0** |
| C c2-c5 | crosshair swept over it; deselect the 15.5 px text, the 16.5 px one, all; each vs redraw | 0, 0, 0, 0 |
| H | hover sweep across the mixed selection | 0 |
| M m1-m4 | scripted move, a real drag of the 16.5 px text, a drag ended by Escape, deselect; each vs redraw | 0, 0, 0, 0 |
| Z z1-z3 | zoom in, zoom out twice (labels cross 16 px), deselect | 0, 0, 0 |
| K k1-k3 | `utils/text_resize.tcl` grow then shrink twice on the two texts (the 15.5 px one crosses 16) | 0, 0, 0 |
| O o2-o4 | `selection_text_own_px` changed in Tcl, then a box-limited `setprop text`: deselect, reselect + redraw + `setprop`, deselect | 10, 29, 0 (classic: 10, 29) |
| D13 | `setprop instance M1 W` (re-texts the labels; full redraw) | 0 / 0 |
| D14 | `text_size_5` taken to 19 px | 0 / 0 |

- **The setting.** `selection_text_own_px` 16, unset, and empty all give the same pictures as
  the default (`C`: identical); 12 moves the 15.5 px text to the band (lo vs colour 1087), 20
  moves the 16.5 px one to colour (hi vs own 1075). Tcl (`set_ne selection_text_own_px 16`) and
  C (`SEL_TEXT_OWN_PX 16.0`, used when the variable is empty) agree. A leading space (`" 16"`)
  reads 16. The old 12 px rows re-run on `~/gsm` with `selection_text_own_px 12` give exactly
  `~/gsa6`'s figures (A, B, C, D1, D2, D6).
- **Every path that changes a selected text's drawn size without a full redraw**, at the new
  sizes (A6's table, re-measured; classic = `~/gsm` classic, and `~/gsl0` gives the same):

  | row | what | halo auto d / du | classic d / du | bright d / du |
  |---|---|---|---|---|
  | D1 | 16.5 → 15.5 px (crosses down) | 40 / 40 | 40 / 40 | 40 / 40 |
  | D2 | 15.5 → 16.5 px (crosses up) | 0 / 39 | 39 / 39 | 39 / 39 |
  | D3 | font Serif | 1 / 30 | 53 / 30 | 30 / 30 |
  | D4 | weight bold | 6 / 109 | 153 / 109 | 77 / 109 |
  | D5 | a longer text | 0 / 10 | 10 / 10 | 10 / 10 |
  | D6 | a shorter text | 10 / 10 | 10 / 10 | 10 / 10 |
  | D7 | `text_size_5` (full redraw) | 0 / 0 | | |
  | D8 | `setprop -fast` size | 1353 / 1185 | 1456 / 1209 | |
  | D9 | `cairo_font_scale 0.9`, then `setprop` | 11681 / 11173 | 12125 / 11527 | |
  | D10 | 15.5 → 18 px | 0 / 12 | 12 / 12 | 12 / 12 |
  | D11 | font Monospace | 92 / 95 | 128 / 95 | |
  | D12 | `allprops {font=Monospace weight=bold}` | 98 / 114 | 146 / 114 | |

  Every residue is at or below classic's, and on D1-D3, D5, D6 and D10 the screen after the
  deselect is AE 0 against classic's. The probe texts are named `label_hi`/`label_lo`: at
  15.5-16.5 px the underscore of `_` reaches below `text_bbox()`, which is the base limit A6
  declared for D10 (a glyph outside the text box) and which classic leaves too. At A6's 12 px
  probe sizes the same rows read 0 because the underscore stayed inside the box; the new
  figures are that base limit, not a regression.
- **Edit Properties** (`edit_text_property()`) and `utils/text_resize.tcl`
  (`busresize::apply_changes`: `setprop -fast` then `xschem redraw`) end in a full redraw, read
  from the code. Every `build_colors()` caller in the GUI is followed by a full draw; only the
  scripted `fill_reset nodraw` / `fill_type … nodraw` re-sync the cached setting without one.
- **valgrind on the rows**: all 14 rows above under valgrind on `~/gsm` (161 logs): every log
  empty, every figure equal to the plain run.

## 3. A6's unfinished re-run: every repro family under the merged default

`reg8` is A5b's regression (every repro family from receipts A2-A5b: `drag2`, `ovl`, `hil`,
`hil2`, `sw`, the `ctx_*` and `det_*` tab and window poses, `print`, `band*`, `vband`, `vconn`,
the `v4_*`, `v5_*`, `v7_*`, `a5_*` and `rub2_a4` poses, D1-D5 and L1) plus five scripted-Expose
poses and ten extra poses (`partial2`, `partial3`, `italic`, `clickhov`, `hoverx`, `pinsel`,
`symedit`, `newwin`, `instzoom`, `resid`) and the Windows-emulation leg. Run in full on:

| build | style / text / scheme | every pose rc 0 | score lines |
|---|---|---|---|
| `~/gsm` | halo auto dark (the default) | yes | all 0 except the known set below |
| `~/gsm` | halo auto light | yes | same |
| `~/gsm` | bright auto dark, light | yes | same, bright's own values |
| `~/gsm` | halo colour dark | yes | = `~/gsa7` colour, line for line |
| `~/gsm` | halo auto at 0 px and at 12 px | yes | = `~/gsa7` own / `~/gsa6` auto |
| `~/gsmw` | halo auto dark, halo colour dark | yes | colour = `~/gsa7w` colour, line for line |
| `~/gsmn` | halo auto dark, bright colour dark | yes | same set, non-cairo values |
| `~/gsm` | classic colour dark, light | yes but one (`a5_canvas` dark, the crash below) | = `~/gsl0` classic, line for line |
| `~/gsa7n` vs `~/gsmn` | bright colour dark | yes | identical, line for line |

The known non-zero set, identical on every build in the same configuration and present before
the merge: `D1 partial` wire 184 (a base residue); `D3` "before 30" in dark (present before the
select); `ovl` o7-o9 15/16/16; `ctx_misc` m2 4846, m5 16382, m6 17115 (halo auto; colour 14449 /
16030, bright 9326 / 11610); `ctx_a4` k6b 66933 (colour 65416, bright 59700). Each equals the
predecessor build's figure in the same configuration (`~/gsa6` auto, `~/gsa7` own and colour,
`~/gsa7n` bright colour), and the same rows are non-zero on base classic too (`ctx_misc` m2 4846,
m5 and m6 13207, `ctx_a4` k6b 62404, `ovl` o6-o9 3/19/16/16): they compare against a reference that
differs by design. (Classic also has `vband` residues of 44-1539 px that every styled build
reads as 0.)

Against `~/gsm` at 12 px, the default (16 px) changes 9 snapshots in 4 window poses
(`ctx_detach` d1, `ctx_win` w1, `det_ev` e1, `win_a4` wc2): a 12-16 px label in a detached or
second window that is now plain. Each snapshot moves together with its own redraw reference, so
it is the cut-off, not a stale paint.

## 4. A5b's claims, re-measured on the merged tree

halo auto dark unless named; `~/gsm` (and `~/gsa7` colour beside it where it helps). The halo of
the selection is 5500 px with A6's labels, 5270 in A5b's colour look; every "5270" in A5b's
tables reads 5500 here.

- **N7, threshold** (`v7_thr`, noted / right): T315, S315 0 / 36565 (not noted, the canvas is
  mixed: correct); T316, S316, T317, S317, T474, T625, T632 **5500 / 0**. Main's later select
  draws nothing below the strip (`m-vs-mR-below` 0) where the canvas holds `t1`. R5 right 0;
  R6 above the bottom 20% 0. Colour: the same rows read A5b's 5270 / 0, and match `~/gsa7`
  line for line.
- **N7, real windows** (`v5_realwin`): R1, R3, R4 **5500 / 0**; R2 not noted (45848 against
  `t1`: correct). **`v5_full`**: F1, F3, F4, F5 **5500 / 0**; F2 not noted.
- **N6** (`v7_cov`): k16, k17, k20, k16r, k17r, g4s, g64, g100s, g500, ov16, ov20, brick, rnd,
  mid2 **5500 / 0**; gap 0 / 5563, gapg 0 / 5528, mid 0 / 10665 (not noted: correct); late 0 / 0.
  `v5_cov`: c1, c1b-c1e, c2, c3, c5b, c5c, c5d, c10, c11 noted, right 0; c4, c5, c9, c12, c13
  not noted. Every row equals A5b's verdict.
- **W1** (`v7_wsel` on `~/gsmw`, the canvas below the exposed strip against main's own
  picture): s1-s6 below **0** in halo auto and colour. s3's strip itself differs from the
  real-clip build by 2435 px (colour 2339): A5b's declared emulation limit (an entry crossing
  the rect's edge is not painted).
- **D1b** (`v7_rub`, against the tool's own picture): `pline_jump`, `pline_back`, `prect_jump`
  e2 **3** (classic's own value) in halo auto and colour.
- **TM1b, G1h**: identical to `~/gsa7` in colour (part of the 1400/1400); in auto they differ
  from `~/gsa7` own only by A6's pin-name change (g1h 56 px).
- **A5b's declared limits.** Re-observed where a pose reaches them, unchanged: the emulation's
  unpainted edge-crossing entry (s3 above); the off-canvas immediate erase (G1h, equal to
  `~/gsa7`); a select in a tab whose picture is only partly on the canvas is not drawn until the
  canvas holds the tab (every "not noted" row above and in `v8_early`). The shuffled-tile limit
  was not re-posed beyond `g100s`/`g500` (both noted); the `sel_paint_others()` emulation limit
  has no row, as A5b said; the timing and no-real-input limits apply to this stage too.
- **Trying to note a tab early** (`v8_early`, 28 rows: `t1` exposes the left 49%, a dr 0 switch
  to main, one operation in main, a dr 0 switch back, then the 49-75% and 75-100% strips, then a
  select in `t1`). In no row was `t1` noted while the canvas held anything of main's (every
  interactive row with "pre vs t1" > 0 is not noted, as on `~/gsa7`). Five scripted rows
  (`xschem wire`, `line`, `rect`, `text`, and a `wire` with `draw_window 1`) paint main's object
  straight into the window, which is not a paste, so the bookkeeping cannot see it (F1); the
  completing strip then triggers A5b's whole-window repair, which repaints `t1` everywhere, so
  the screen is right (pre vs t1 0, right 0) where classic leaves main's object on `t1`'s
  picture (618, 618, 100547, 4375 and 618 px).
- **Real and scripted Exposes**: the `R` rows above are real windows uncovering the canvas; the
  `expo*` poses are scripted; both 0 / correct.

## 5. A6's claims

- **One decision everywhere.** `sel_text_band_for()` is the only size comparison (read: its
  callers are `sel_cairo_text_clip()`, `sel_text_parts()`, `draw_temp_string_parts()` and the
  own-glyph filter in `draw_symbol()`). Its size is `draw_string_cairo()`'s
  (`xscale*52*cairo_font_scale*mooz`), and the cached `sel_text_own_px` is re-read only by
  `sel_style_sync()`. Attacked by rows C, H, M, Z, K, O and D above (a selection that is half
  band, half colour, swept, hovered, moved, dragged, zoomed across the cut-off, deselected in
  parts): no row leaves a text painted one way and erased the other.
- **The text mark before `setprop text`** and **the clip lift**: rows D1-D6 and D10-D12 above,
  every "d" at or below classic; the offtext pose in section 1.
- **Without cairo** both `auto` and `own` are the colour look: rows A, B, C, D1, D2 on `~/gsmn`
  read 0 against forced own and forced colour alike (forced own = forced colour there, 0 px),
  and D1, D2 are 0 / 0.
- **Windows emulation** (`~/gsmw`): rows A, B, C, D2, M, K read as on `~/gsm`; D1 30 / 30
  against classic's 40 / 40 on the same build.
- **A6's limits** (bold/monospace need more than the cut-off; band width 1 px; S7 unfenced;
  `setprop -fast` and `cairo_font_scale` stale in every style; pin names not part of the look; a
  zoom that skips its redraw): unchanged. The bold and monospace part no longer arises at the
  default: A6's ladder opens bold at 16 px and monospace at 13, and no text below 16 px gets the
  band now.

## 6. Classic

Every snapshot of the full regression in classic, `~/gsm` against base `~/gsl0`, same data
directory: **dark 1398 / 1398 identical, light 1400 / 1400 identical**, and every score line the
same. The two dark snapshots not compared are `a5_canvas` tm5 and its reference, which `~/gsm`
did not reach because that run hit the `delete_undo()` crash (section 7). The full-page PNG with
the title-block date did not differ either (the runs fell on the same date). Also identical:
`~/gsmn` against `~/gsa7n` in bright colour (1396 / 1396), `~/gsm` against `~/gsa7` and `~/gsmw`
against `~/gsa7w` in halo colour (1400 / 1400 each).

## 7. Health

- **valgrind, headless** (`--nogui` and `--pipe`, classic/bright/halo × auto/colour/own, on
  `~/gsm`, `~/gsmw`, `~/gsmn`): 54 runs, every log empty, every run reached its marker.
- **valgrind, display**: `a5_canvas`, `v7_thr`, `v7_cov`, `v7_wsel`, `v7_rub`, `v7_dw`,
  `v8_early`, `v8_offtext` (halo auto) and `v7_thr`, `v7_wsel` (bright auto) on `~/gsm`;
  `a5_canvas`, `v7_wsel`, `v7_cov`, `v7_thr` on `~/gsmw`; `a5_canvas`, `v7_rub`, `v7_cov` on
  `~/gsmn`: 17 runs, every log empty, every pose reached its done marker. Plus `a5_canvas` 5
  times each on `~/gsm` halo and `~/gsm` classic (and 5 on base `~/gsl0` classic) in the crash
  leg below, every log empty, and the 161 row logs in section 2.
- **The `delete_undo()` crash on tab close** (A5b's observation) is issue **1706** (processes
  started in the same second share `random_string()`'s seed, so their temp and undo directory
  names collide; a failed undo dir then leaves `undo_dirname` NULL for `delete_undo()` to read at tab close), and the rate
  follows launch timing, not the build:
  - launched **one at a time**: `a5_canvas` under valgrind 5 times each on `~/gsm` halo,
    `~/gsm` classic and `~/gsl0` classic, and 3 display-valgrind runs: 18 runs, **0** stops;
  - launched **four or more in the same second** (my parallel waves): the wave-3 run of `~/gsm`
    classic stopped at TM5 (14:25:11, 5 runs launched together), and a deliberate batch of four
    plain runs per display started together gave **base `~/gsl0` classic 3 of 16, merged
    `~/gsm` classic 4 of 16, merged halo 0 of 8 at TM5** plus one halo run that reached its done
    marker and then exited 1. In that batch two emergency-save directories carry the **same**
    random suffix (`/tmp/xschem_emergencysave_flop_dbeeaefcca` and `..._not_dbeeaefcca`), which
    is 1706's shared seed seen directly.

  So the merge does not change it; base and merged stop equally often under same-second
  launches, and neither stopped once when launched alone.
- **Suites** (`tests/headless/run_suites.sh`, `GUI_GATE=0`, explicit `AUDIT_DISPLAY`; display
  arm `AUDIT_DISPLAY=:291` / `:292`, counted arm `--nogui` with `AUDIT_DISPLAY=none`; A5b's
  lists, 31 + 10 + 12 suites on the display arm and 34 + 10 + 12 on the counted arm), run on
  `~/gsm` and on base `~/gsl0` at the same time: **every suite gives the same verdict on both,
  and every failing check is the same check** (the detail lines are identical once the clone's
  path is replaced). The non-passes, all base: display arm `test_select_at` 5 FAILED and
  `test_cadence_drag` 2 FAILED; `test_placement_preview_doors` and `test_shape_draw_gate`
  TIMEOUT (200 s); counted arm `test_load_window_routing` 4 FAILED (LR1b, LR5b, LR5e, LR6) and
  11 NORESULT (`test_cadence_drag`, `test_hover_highlight`, `test_hover_selection_repair`,
  `test_select_at`, `test_wire_complete_with_selection`, `test_clone_canvas_bindings`,
  `test_close_window_restores_prev_tab`, `test_multi_window`, `test_window_numbering`,
  `test_annot_declutter_1244`, `test_nh_angle_render`); the SKIPs are self-skips. The tallies
  equal A5b's for base and `~/gsa7`.

## 8. Timing

Run one at a time on `:295`, after every other run of mine had finished (load average 1.4-2.7
on 20 cores; another agent's Xvfb `:270`-`:273` was up). ms per step including an X round trip;
the cell is the mean of two rounds with the rounds in brackets.

**A6's table** (`V6/scr/perf8.sh`, A6's `perf6.tcl`: 1600 `nfet_01v8` and 1600 wires, a
1400x1000 window, dark). Variants interleaved. "auto" is each build's default; `~/gsa6` is A6 at
12 px; "own at every size" is `own` with `selection_text_own_px 0`. The drag of the whole
selected sheet is left out of the tables: every variant, classic and base included, is within
the rounds' spread (the first four frames 0.8-0.9 s at 17.5 px, 1.8-2.1 s at 14.7 px and
1.4-1.7 s at 5.7 px; later frames 0.5-0.6, 0.5-0.6 and 1.3-1.4 s), which is base cost, not the
overlay.

Labels at **17.5 px** (the band is drawn in both A6 trees):

| variant | hover | crosshair | select all | rubber band |
|---|---|---|---|---|
| merged, halo auto (default) | 1.2 (1.1/1.2) | 0.7 (0.6/0.7) | **5.0** (5.0/4.9) | 1.0 (1.0/0.9) |
| merged, halo colour | 1.0 (1.0/1.0) | 0.7 (0.7/0.6) | 3.5 (3.6/3.5) | 0.8 (0.8/0.8) |
| `~/gsa6`, halo auto (12 px) | 1.4 (1.5/1.2) | 0.8 (0.8/0.8) | 6.2 (6.6/5.8) | 1.0 (1.2/0.8) |
| `~/gsa5`, halo colour (A5) | 1.1 (1.2/1.0) | 0.8 (0.9/0.7) | 4.1 (4.6/3.6) | 1.0 (1.2/0.8) |
| merged, own at every size | 1.3 (1.4/1.3) | 0.7 (0.7/0.7) | 5.7 (6.0/5.3) | 1.0 (1.1/1.0) |
| merged, classic | 2.0 (1.9/2.2) | 2.9 (2.8/3.1) | 1.0 (1.0/1.1) | 3.0 (2.7/3.2) |
| base `~/gsl0`, classic | 2.1 (2.1/2.1) | 3.0 (3.0/3.0) | 1.1 (1.1/1.1) | 3.2 (3.3/3.1) |

Labels at **14.7 px** (A6's "band drawn" size; under 16 px now, so plain in the merged default):

| variant | hover | crosshair | select all | rubber band |
|---|---|---|---|---|
| merged, halo auto (default) | 1.3 (1.3/1.3) | 0.7 (0.8/0.7) | **4.0** (4.2/3.9) | 1.0 (1.0/1.0) |
| merged, halo colour | 1.1 (1.1/1.0) | 0.7 (0.7/0.7) | 3.3 (3.4/3.2) | 1.0 (0.9/1.0) |
| `~/gsa6`, halo auto (12 px) | 1.4 (1.5/1.4) | 0.7 (0.7/0.7) | **5.8** (6.0/5.6) | 1.0 (1.1/0.9) |
| `~/gsa5`, halo colour (A5) | 1.1 (1.2/1.1) | 0.7 (0.7/0.7) | 3.5 (3.5/3.5) | 1.0 (0.9/1.0) |
| merged, own at every size | 1.8 (1.9/1.7) | 0.9 (0.9/0.8) | 8.1 (8.6/7.5) | 1.3 (1.4/1.2) |
| merged, classic | 2.5 (2.1/2.8) | 3.7 (3.2/4.2) | 1.3 (1.1/1.5) | 3.7 (3.2/4.2) |
| base `~/gsl0`, classic | 2.4 (2.4/2.5) | 3.5 (3.3/3.8) | 1.3 (1.2/1.4) | 3.7 (3.6/3.7) |

Labels at **5.7 px** (plain in every A6 tree):

| variant | hover | crosshair | select all | rubber band |
|---|---|---|---|---|
| merged, halo auto (default) | 1.1 (1.1/1.1) | 0.8 (0.8/0.9) | 13.4 (13.5/13.4) | 2.3 (2.1/2.5) |
| merged, halo colour | 1.0 (1.0/1.0) | 0.7 (0.8/0.6) | 12.8 (13.6/11.9) | 2.0 (2.0/1.9) |
| `~/gsa6`, halo auto (12 px) | 1.0 (1.0/0.9) | 0.7 (0.7/0.6) | 12.5 (12.9/12.1) | 2.1 (2.2/2.0) |
| `~/gsa5`, halo colour (A5) | 1.0 (1.0/1.0) | 0.8 (0.8/0.8) | 13.3 (13.3/13.3) | 2.1 (2.2/2.0) |
| merged, own at every size | 1.7 (2.1/1.4) | 1.1 (1.4/0.8) | **37.8** (46.0/29.7) | 3.6 (4.3/2.9) |
| merged, classic | 12.5 (9.2/15.8) | 17.6 (13.4/21.8) | 6.0 (5.0/7.1) | 17.1 (13.9/20.3) |
| base `~/gsl0`, classic | 9.7 (9.6/9.7) | 14.0 (14.1/13.9) | 4.9 (5.1/4.8) | 14.9 (15.2/14.6) |

**What the merge and the 16 px cut-off cost.** Nothing a user would feel: every hover,
crosshair and rubber-band step on the 1600-FET sheet is 0.7-2.3 ms in the default, under base
classic's 2.1-14.9 ms on the same sheet. Select-all of 1600 FETs costs 1.5 ms more than the plain look where
the band is drawn (5.0 against 3.5 ms) and 0.7 ms more at 14.7 px (4.0 against 3.3), and at 14.7 px
the 16 px cut-off saves 1.8 ms against A6's 12 px tree (4.0 against 5.8), because those labels are
no longer banded. The remaining 0.7 ms at 14.7 px, where no text has the band, is probably the
band and own-colour passes each text is asked about and skips. The merged classic is base classic
within the two rounds' spread on every row. A5b's bookkeeping is not visible in any row.

**A5b's standard table** (`V6/scr/tim8.sh`: A2's `perfv`, `vperf`, `perfb2`, `bandbig` and the
drag bench, builds alternating, two reps, on `:295`, the machine otherwise idle). Each build in
its default text look (A5: colour; merged: auto at 16 px). ms per event, rep 1, rep 2:

| row | base classic | A5 halo | merged halo | A5 bright | merged bright | merged classic |
|---|---|---|---|---|---|---|
| hover | 7.05, 8.21 | 1.06, 1.07 | 1.02, 0.99 | 0.98, 0.92 | 1.13, 0.93 | 7.28, 7.00 |
| crosshair (`xh2`) | 10.92, 12.83 | 0.86, 0.96 | 0.79, 0.72 | 0.73, 0.72 | 0.95, 0.85 | 11.11, 11.21 |
| rubber band motion | 13.01, 14.48 | 0.62, 0.61 | 0.51, 0.49 | 0.48, 0.49 | 0.64, 0.61 | 13.18, 13.03 |
| select all | 4.74, 4.86 | 0.48, 0.41 | 0.42, 0.46 | 0.42, 0.50 | 0.49, 0.44 | 4.79, 4.75 |
| select all, zoomed (`sa3500`) | 9.27, 8.94 | 23.50, 22.76 | 22.98, 28.03 | 21.48, 21.54 | 22.47, 21.34 | 8.99, 8.94 |
| band grow, big (`gr3500`) | 7.30, 8.64 | 3.47, 2.68 | 3.28, 3.43 | 2.87, 2.89 | 2.85, 2.63 | 8.35, 7.17 |
| drag K=390 | 5.66, 6.00 | 4.79, 4.87 | 5.17, 5.78 | 4.76, 5.03 | 4.97, 4.52 | 6.75, 5.83 |
| drag K=826 | 4.37, 4.34 | 9.29, 9.03 | 9.77, 11.56 | 9.10, 9.48 | 9.00, 8.71 | 4.94, 4.32 |

The rest of `V6/scr/timtab8.sh`'s output reads the same way. The merged halo's second rep of
`sa3500` and K=826 read high, so both rows were re-run four more times alternating A5 and merged
right afterwards (`V6/scr/tim8b.sh`): `sa3500` A5 26.26, 25.57, 25.51, 23.45 against merged
25.81, 25.68, 23.34, 23.14; K=826 10.52, 9.91, 10.15, 9.78 against 10.30, 10.54, 9.76, 9.28;
K=390 5.35, 5.51, 5.44, 4.94 against 5.39, 5.66, 5.07, 4.95 ms: equal. The merged classic is
base classic within the reps' spread on every row. `sa3500` and K=826, the two rows where every styled build
is slower than classic, were so in A5b's table too (A5b halo 27.62, 40.80 and 9.83, 12.89 ms,
on a loaded machine); nothing the merge or the cut-off added.

## Findings

| id | severity | what |
|---|---|---|
| F1 | info | A5b's coverage cannot see a non-paste paint by another tab (scripted `xschem wire/line/rect/text`, `draw_window 1`); harmless because completion repaints the whole window |
| F2 | low | a non-numeric `selection_text_own_px` gives the band on every text |
| F3 | nit | `SEL_TEXT_OWN_PX`'s comment gives the user a reason the user did not give |

**F1.** Repro: `V6/scr/v8_early.tcl` rows `e_cwire`, `e_cline`, `e_crect`, `e_ctext`, `e_dw`.
While `t1` collects (after a dr 0 switch and a partial Expose), main draws an object straight
into the window; `sel_note_paste()` follows pastes only, so `t1`'s complement list does not grow
back over that object, and `t1` is noted when its last strip arrives although main's object was
on the canvas. The screen is nonetheless right, because the completion queues A5b's whole-window
repair (the behaviour sabotage X12 fences), which repaints `t1` over it. No visible defect; the
statement "a tab is noted only when the canvas truly shows it" holds for the screen, not for the
bookkeeping in between. Suggested: nothing to change; if wanted, a sentence in A5b's limits.

**F2.** Repro: `V_OWNPX=abc` with row B (`V6/log/r16_abc.txt`): the 15.5 px texts get the band
(against forced colour 3176 px instead of 0), as with `-5` (clamped to 0). `sel_style_sync()`
reads `atof(op)` when the variable is non-empty, so any non-numeric word is 0, i.e. A5's forced
own on every text, the heaviest look and the one the cut-off exists to prevent. The setting has
no menu entry, so only a hand-edited rc reaches it. Suggested fix: parse with `strtod()` and an
end check, and fall back to `SEL_TEXT_OWN_PX` when nothing numeric was read (the empty case
already does).

**F3.** `xschem.h`, above `SEL_TEXT_OWN_PX`: "the user ruled 16 (2026-11-15) because 12-14 px
band text still read heavy in the composites". PLAN.md records that the *driver* judged 12-14 px
heavy and recommended 16, and the user approved the recommendation. Suggested: "the driver
judged 12-14 px band text heavy in the composites (worst on light) and recommended 16; the user
approved it (2026-11-15)". `xschem.tcl`'s comment is accurate as written.

## Not covered

- No real hand input and no real screen: every gesture is synthesized on Xvfb + openbox. The
  Windows build was not compiled; only A5b's emulation. The user's stage-B look (including the
  responsiveness check on their own screen PLAN.md asks for) remains theirs.
- Realistic designs were timed by another agent (`receipts/realistic-timing.md`); not repeated.
- Italic and other font faces at the new cut-off were not measured (no oblique face installed,
  as for A6).
- `edit_text_property()`, `replace_symbol` and `pin_view_refresh()` were read, not driven.

## Housekeeping

- **Displays.** My ten Xvfb + openbox pairs on `:286`-`:295` stopped, each pid checked first
  (Xvfb's cmdline `Xvfb :NNN`, openbox's environment `DISPLAY=:NNN`); no socket or lock file
  left for those numbers. No other display was touched.
- **`/tmp`.** 22 `xschem_web_*` / `xschem_undo_*` directories left by my killed, timed-out or
  crashed runs (13:47-14:59) removed; the list is `V6/log/tmp_removed.txt`. Left alone: the empty
  `/tmp/xschem_web_ffbaecafef` (13:45:32) and `/tmp/xschem_emergencysave_untitled_acegdfdbga`
  (13:47:12), which I cannot attribute, and every `xschem_*` directory from 15:04 on, which
  belongs to someone else (no process of mine was alive by then). The emergency-save directories
  of section 7 were transient and had already gone before the cleanup.
- **Clones.** `~/gsm`, `~/gsmw` and `~/gsmn` are left built in place. No clone holds a `*~.sch`,
  `*~.sym` or untracked file of mine (`git status --ignored` shows build products only).
  `git status` refreshed the index stat data in the comparator clones; no tracked file changed.
- **Main tree.** Nothing written but this receipt; `src` diff md5 unchanged (above).
- **Scratch** trimmed from 1.3 GB to 120 MB: the PNG snapshots (about 33,000 files, 1.09 GB),
  the throwaway homes and the run cwds deleted. The logs, scripts, ident lists and `V6/img`
  remain.
