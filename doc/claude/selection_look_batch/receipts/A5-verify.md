# A5 verification (adversarial)

Verifier receipt for stage A5 of the selection-look batch. Nothing was committed. The main tree
was not edited except for this file.

- Tree under test: the uncommitted `src/` diff, 8 files. `git diff -- src | md5sum` was
  `1c35de6bd5f722eb374c922052ff9f17` at launch and is the same at the end.
- Clones: `~/gsl0` (base), `~/gsa4` (A4), `~/gsa5` (A5, equal to the main tree in all 8 files),
  `~/gsa5w` (Windows emulation: `SEL_REAL_XCLIP 0` and two `#if 0` in `xinit.c`), `~/gsa5n`
  (no cairo), and `~/gsa4w`, `~/gsa4n`. Every binary was newer than its sources.
- Displays: my own Xvfb with openbox on `:286`–`:293`. Never `:0`, `:99` or `$DISPLAY`.
  `GUI_GATE=0` and an explicit `AUDIT_DISPLAY` on every run. Throwaway HOME on every run.
- Scratch: `V5` = `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/V5`.
  Scripts are in `V5/scr`, snapshots in `V5/out`, `V5/r/out` and `V5/r/a2/out`, images in `V5/img`.
- AE is `magick compare -metric AE` (pixel count). The canvas is 900x632.

## Verdict: SAFE WITH LIMITS

- No regression against A4 or against base anywhere I measured.
- Classic is pixel-identical to base.
- Health is clean: no crash, valgrind clean, no new warnings, the same suite verdicts as base.
- Claims 2 and 3 hold, and claim 4 is confirmed as a limit.
- Claim 1 holds for every shape the crew measured. But **N7** shows that N5's symptom is still
  there after one real Expose of half the window or more that does not cover all of it. It is
  the defect this stage set out to fix, it can be reached with a real X Expose, and the fix is
  small. I would fix N7 before the commit. It does not need to block the user's look (stage B).

## Findings

| id | severity | new in A5? | one line |
|---|---|---|---|
| N7 | medium | no (A4 the same) | after a dr 0 switch, an Expose of 50% to 99% of the window repaints the whole canvas but does not note the tab |
| N6 | low | no | a cover made of more than 16 rects never notes the tab |
| W1 | low | no (A4 the same) | Windows only: a partial Expose of a tab that is not on the canvas paints its whole selection over the old tab's picture |
| D1b | cosmetic | no (A4 the same) | a 3-pixel dot at a click point after a line PLACE that came with no motion |

### N7 (medium): a half-window Expose paints the whole tab but does not note it

**Mechanism.** In `handle_expose()` the styled branch calls `sel_pend_add()` and then
`sel_overlay_flush()`. When the pending area is half the window or more, `sel_pend_full()`
widens the repair to the whole window, so the whole pixmap is copied. But `sel_note_expose()` is
told only the exposed rect, so the cover is incomplete. The canvas now shows the current tab
everywhere, while `sel_canvas_win` still names the old tab. `sel_idle_cb()` then drops the
current tab's damage, so its selection changes never show. This is N5's symptom.

**Repro with a real X Expose** (`V5/scr/v5_realwin.tcl`, row R1):
1. Main tab on `not.sch`, a second tab `t1` on `flop.sch`. Main is shown.
2. An override-redirect toplevel covers the top 60% of `.drw`.
3. `xschem new_schematic switch $t1 $f2 0`.
4. Destroy the toplevel. The server exposes the area it covered.
5. `xschem select instance x5`.

Results. "pre" is the canvas before the select, compared with `t1`'s own full redraw. "shown"
is the canvas after the select, compared with a full redraw.

| row | exposed | config | pre vs t1 | shown vs redraw |
|---|---|---|---|---|
| R1 | 60% | A5 halo `colour` dark | 0 | **5270** |
| R1 | 60% | A5 bright `own` light | 0 | **2508** |
| R1 | 60% | `~/gsa5w` halo `own` | 0 | **5539** |
| R1 | 60% | `~/gsa5n` bright `colour` | 0 | **1160** |
| R4 | 75% | all four of the above | 0 | 5270 / 2508 / 5539 / 1160 |
| R3 | 100% | all four | 0 | 0 (noted, correct) |
| R2 | 40% | all four | canvas really mixed (45666, 22132 n) | not noted, correct |
| R1 | 60% | A4 halo `colour` | 0 | 5270 (the same as A5) |
| R1 | 60% | classic, A5 and `~/gsl0` | 28524 (canvas mixed, base) | 28524 |

The synthetic Expose version (`V5/scr/v5_full.tcl`) gives the same at 60% (F1) and exactly 50%
(F3, the `>=` in `sel_pend_full()`). At 40% (F2) the repair stays small and the canvas really
is mixed.

The same gap is easier to reach on the Windows build (`V5/scr/v5_win.tcl`). There, main's idle
repair runs between two half-window Exposes of `t1` and paints main's selection unclipped. That
correctly drops `t1`'s first rect (`sel_note_paste()`). Then the second half's full repair
repaints all of `t1`, so the canvas holds `t1`, but `t1` is never noted. `~/gsa5w`: 5270 (halo
`colour`), 5539 (halo `own`), 2508 (bright `own` light). With main's select removed, it is noted
and correct. `~/gsa5` with the real clip is correct in the same script.

**How a user meets it.** A dr 0 switch is outstanding: the tab menu's Edit netlist, Save or
Close, or the `xschem load -window` save prompt. Then a window that covered half the canvas or
more goes away. A real click on the canvas still shows its selection, because the motion repair
draws at once (the crew's TM2). A select that does not come through canvas motion (a script, a
menu entry, a key) does not show.

**Suggested fix.** For a tab that is not `sel_canvas_win`, keep the Expose repair to the exposed
rect: no `sel_pend_full()` widening. Then the canvas holds exactly what the collection records,
as in classic. The other option is to pass the whole window to `sel_note_expose()` after a full
repair. That is wrong when another window covers part of the canvas, because X discards the
paint there (the TM1b case). So the first option fits A5's own safe-side rule.

Image: `V5/img/n7_r1_classic_halo_pre_sel_redraw.png`. Left to right: classic after R1 (mixed),
halo after R1 (all `t1`), halo after the select (no halo on `x5`), halo after a redraw.

### N6 (low): a cover of more than 16 rects never notes the tab

**Mechanism.** In `sel_note_expose()`, `if(sel_exp_n == SEL_EXP_MAX) return;` comes before the
new rect is stored and before `sel_exp_covers()`. Rects that tile the window contain none of each
other, so none merge. The 17th rect and every later one are dropped, and the cover never
completes.

**Repro** (`V5/scr/v5_cov.tcl`): after a dr 0 switch to `t1`, Expose 20 horizontal strips that
tile the window (C1). Each strip is under half the window, so there is no full repair. Then
`xschem select instance x5`.

| row | rects | noted | shown vs redraw (halo `colour`) |
|---|---|---|---|
| C1 | 20 strips | no | **5270** |
| C1c | 17 strips | no | **5270** |
| C1e | 8x8 grid, 64 rects | no | **5270** |
| C1b | 16 strips | yes | 0 |
| C1d | 20 strips, then a real deiconify | yes | 0 |

The same pattern holds in bright `own` light, on `~/gsa5w` and on `~/gsa5n`. A4 notes none of
them. A real Expose region of more than 16 rects needs many small windows over the canvas, so
it is rare.

**Suggested fix.** Run the cover test with the new rect before dropping it. Or merge rects that
share a whole edge.

Image: `V5/img/n6_c1_20strips_16strips_ref.png`.

### W1 (low, Windows only, the same on A4): a partial Expose paints the whole selection

**Mechanism.** Without a real X clip, `sel_overlay_flush()` repaints every selected object
unclipped after the copies. For a tab that is not on the canvas, the paint lands on the parts
that still show the old tab.

**Repro** (`V5/scr/v5_wsel.tcl`):
1. `t1` has `x5` selected. Switch to main with a draw.
2. Switch to `t1` with dr 0.
3. Expose the top 30% of the window. `x5` lies below that strip.

The canvas then shows main's drawing with `t1`'s `x5` halo on it.

| | AE against the real-clip build |
|---|---|
| `~/gsa5w` halo `own` | **7355** |
| `~/gsa4w` halo `own` | **7355** (the same) |
| `~/gsa5w` bright `own` | **3915** |
| classic | 0 |

This needs a dr 0 switch plus a partial Expose while the tab has a selection. Image:
`V5/img/w1_partial_expose_realclip_vs_winemu.png` (real clip on the left, Windows emulation on
the right).

### D1b (cosmetic, the same on A4): a dot at a click point with no motion

**Repro** (`V5/scr/v5_rub.tcl`, `pline_jump`):
1. `persistent_command 1`. Start a line at P from the GUI.
2. Motion to Q, then motion back to P.
3. Press and release at R = (600, -120) with no motion before it.
4. An Expose (e2).

A 3-pixel dot appears at R (pixels 801–802, 290–291, `srgb(136,221,0)`).

- Halo and bright, A4 and A5 alike: e2 = 6 against the tool's own picture.
- Classic: 3, which is only the P residue being erased.

**Cause.** `new_line()` PLACE stores nothing (the rubber is P to P), keeps the `rubber_shown`
bit, and starts the new segment at the click point. The restamp in `sel_rubbers_restamp()` then
strokes a zero-length segment at R. `pwire_jump` stores a wire, so its path differs and it is
clean.

A real pointer sends a motion to R before the press, so this is only reached by script or
synthetic input. Suggested fix: clear the bit when the click point differs from the stroked
point.

Image: `V5/img/d1b_pline_jump_n0_e2_classic_8x.png`.

### Observations, not defects

- **A stroke by another context is not a paste.** `V5/scr/v5_xh2.tcl`: `t1` exposes 70% of the
  window (a full repair). Main, now current, draws its crosshair. `t1` exposes the last 30%. The
  cover completes, `t1` is noted, and the selection shows. Main's crosshair stroke stays inside
  `t1`'s picture: 448 px (halo), 446 (bright). Classic and `~/gsl0` leave 1185 px, so this is
  base behaviour and A5 leaves less. A4 does not note `t1` at all (5737).
- **`a5_canvas` sometimes stops after TM5's message box.** It stopped once on `~/gsa5` halo
  `colour` dark (batch 1). It also stopped once on base `~/gsl0` classic light (rc 1) and once on
  `~/gsa4` bright `colour` dark (rc 1, last line the "UNSAVED data: want to exit?" box). It
  passed 20 of 20 repeats on `~/gsa5`, and it passed under valgrind. It is not A5's.

## The claims beside my figures

| claim | the crew | my figure | verdict |
|---|---|---|---|
| 1. N5 fixed (`sel_note_expose()`, `sel_exp_covers()`, `sel_note_paste()`) | G1/G1b/G1q/G1r and TM1 5270 to 0; TM4 5181 to 0; G1s 3270 to 0 | the same, exactly. halo `colour`: 5270 / 3270 / 5270 / 5181 to 0. bright `own` dark and light: 2507–2508 / 1668 / 2741 to 0. `~/gsa4w` halo `own`: 5539 / 3431 / 5539 / 5819 to 0. `~/gsa4n` bright `colour`: 1160 / 741 / 1162 to 0 | holds for those shapes. Not for N7 or N6 |
| 1. Clip to the window and the screen | S4, S5 | `v5_geo`: a 2300x1400 window (G7, G7b) 5271 on A4, 0 on A5; also off the left and top edge (G9) 2053 to 0; classic and bright `own` correct | holds |
| 1. Pastes drop rects | S2 | C2 (overlap), C3 (beyond the window) noted; C4 (outside or zero size) not noted; C5 (a 1-pixel gap column, a missing last row, one missing pixel) not noted, and noted once that pixel is added; C10 noted; C11 (main repainted half) not noted; C12 (a new tab made with dr 0) and C13 (a destroyed and re-created tab) not noted | holds |
| 1. Cost | — | 500 tiny Exposes: 65.0 ms on A5 halo, 64.6 on A4 halo, 60.1 on `~/gsl0` classic. The array is static (16), so it cannot grow | fine |
| 2. D1 fixed: per-tab `rubber_shown`, `draw()` keeps it | `v4_degen` 3 to 0 | `v4_degen` (wire, line, rect, poly, zoom, arc): A4 0/3/3/3, A5 0 everywhere. `v4_degen2`: A4 0/3/3, A5 0/0/0, `~/gsa4n` and `~/gsa5n` too. `a5_degen3` pwire/pline s1 bright 3 to 0. 11 more rubber kinds (`v5_rub`): A4 equals A5 on every one | holds. D1b is left over, cosmetic and old |
| 3. K6b moves 56749 to 65234 legitimately | yes | against main's full redraw: A5 **0**, A4 8485, classic 0. Against the `t1` reference: A5 65234, A4 56749, classic 62222, bright `own` 61082 (A4 55422), `~/gsa5w` halo `own` 66796 (A4 57612), `~/gsa5n` bright `colour` 33867 (A4 30951). After it (K6c), Enter makes `.drw` current in every build and a select-all is correct (0) | legitimate. While the base K6 bug stands, the canvas really holds main's drawing, and A5 now shows exactly that, as classic does. Image: `V5/img/k6b_a4_a5_main_t1.png` |
| 4. Limit: TM1b, a window over part of the canvas | 5271 on A4 and A5 | 5271 halo `colour`, 2857 bright `own` light, 5540 `~/gsa5w`, 1161 `~/gsa5n`, on A4 and on A5 alike | confirmed as declared. N7 is the case its safe-side reasoning does not cover |

## Regressions: A4 against A5, pixel by pixel

Every earlier repro and scenario script, per configuration (`V5/scr/reg.sh`, scored with
`V5/scr/ident.sh`). These are the D1–D7, L1 and N1–N5 repros, the `expo*` set, the A3/A4
scenarios (`drag2`, `ovl`, `hil`, `hil2`, `sw`, `ctx_*`, `print`, `bigdrag`, `pin1`, `det_*`,
`band*`, `win_a4`), and my `v5_*` poses.

| configuration | identical snapshots |
|---|---|
| halo `colour` dark | 868 / 912 |
| bright `own` light | 867 / 912 |
| halo `own` light | 900 / 948 |
| bright `colour` dark | 895 / 946 |
| `~/gsa4w` / `~/gsa5w` halo `own` dark | 870 / 912 |
| `~/gsa4n` / `~/gsa5n` bright `colour` dark | 863 / 908 |

Every difference is an expected row: the N5 rows (G1*, TM1, TM4), the D1 rows (`v4_degen*`,
`a5_degen3`, `pwire_jump` s1), the `v5_cov` and `v5_geo` rows that A5 now notes, and K6b. The
scenario score lines are identical, line for line, except K6b, in all six pairs. The expected
non-zero scores stay where they were: `ovl` o7–o9 15/16, `ctx_misc` m2/m5/m6 4846 / 14449 /
16030, and D1 `partial` wire 184 (upstream).

- D7 `winemu` on `~/gsa5w`: w1, w2, w3 all 0 in 8 configurations.
- `expo*` in 5 configurations: 45 checks, all 0.

## Classic against base

`~/gsl0` against `~/gsa5` classic, every snapshot: 947 / 948 identical dark, 945 / 946 light. The
only differences are the date in the print PNG's title block (205 px and 204 px).

## Health

- **Headless.** 48 runs without valgrind (`~/gsa5`, `~/gsa5n`, `~/gsa5w`, `~/gsl0`; `--nogui`
  and `--pipe`; 3 styles; 2 text styles) and 36 under valgrind. All rc 0, every mark written,
  every log empty, no `FATAL`.
- **Valgrind on the display.** 10 runs: `~/gsa5` `a5_canvas`, `v5_cov`, `v5_geo`, `v5_k6`,
  `v5_rub`, `v4_degen2`; `~/gsa5w` `a5_canvas`, `v5_cov`; `~/gsa5n` `a5_canvas`, `v5_rub`. All
  clean, all reached `V-DONE`, all with the same scores.
- **Warnings, base against A5.** Identical: cairo default 6 / 6, cairo `-std=c89 -pedantic` 67 / 67,
  non-cairo 6 / 6 and 67 / 67. With `-Wall -Wextra -std=c89 -pedantic` on the 6 changed `.c`
  files: 44 unique lines on both, identical.
- **Suites** (`run_suites.sh`, `GUI_GATE=0`, explicit `AUDIT_DISPLAY`). Identical verdicts on
  base and A5:

| list | arm | base and A5 |
|---|---|---|
| disp | display | 28 / 30 (1 skipped) |
| scan | display | 10 / 10 |
| extra (12 suites) | display | 8 / 10 (2 skipped) |
| nogui | counted | 19 / 24 (10 skipped) |
| scan | counted | 7 / 9 (1 skipped) |
| extra | counted | 5 / 10 (2 skipped) |

The same reds appear on both trees: `test_select_at` 5 FAILED, `test_cadence_drag` 2 FAILED,
`test_load_window_routing` 4 FAILED, the same NORESULT set, and a TIMEOUT for
`test_shape_draw_gate` and `test_placement_preview_doors` on the display arm.

Those two hang; they are not slow. A5's `test_shape_draw_gate` still timed out at 900 s, idle in
the event loop at 0% CPU. Run directly for 150 s on both trees, each prints byte-identical output
up to the same stop point. On the counted arm both pass on both trees (421 and 206 checks).

## Timing

Run with `V5/scr/tim.sh` on `:286`, the builds alternating, two runs each, while nothing else of
mine was running. The load average was 0.40 at the start, and other sessions were still on the
machine. Tabulated with `V5/scr/timtab.sh`. Each cell is ms, "run 1, run 2". The A4
halo column had a load blip in run 2 (about 2x on several rows).

**Hover and crosshair** (`perfv.tcl`, 1600 selected):

| | `~/gsl0` classic | A4 halo | A5 halo | A4 bright | A5 bright | A5 classic |
|---|---|---|---|---|---|---|
| hover change | 6.99, 7.09 | 1.08, 1.01 | 1.07, 1.08 | 1.04, 1.37 | 0.99, 1.38 | 6.92, 7.47 |
| crosshair | 11.10, 11.21 | 0.82, 0.90 | 0.89, 0.85 | 0.78, 1.22 | 0.77, 0.97 | 11.03, 12.31 |
| full-span crosshair | 11.02, 12.36 | 4.55, 5.30 | 5.00, 4.33 | 4.54, 6.22 | 4.46, 4.85 | 10.85, 12.48 |
| band motion | 13.22, 13.41 | 1.07, 0.65 | 0.46, 0.50 | 0.51, 0.30 | 0.52, 0.52 | 13.09, 13.95 |
| unselect all | 6.50, 7.01 | 0.86, 0.89 | 0.58, 0.54 | 0.58, 1.42 | 0.60, 0.84 | 7.31, 7.56 |

**Select all + update** (`vperf.tcl`, median), widths 2300 / 3500 / 8200:

| | 2300 | 3500 | 8200 |
|---|---|---|---|
| `~/gsl0` classic | 4.86, 5.10 | 9.12, 10.04 | 1.91, 1.98 |
| A4 halo | 12.72, 23.47 | 24.99, 44.45 | 9.20, 17.80 |
| A5 halo | 12.63, 12.89 | 22.94, 22.72 | 9.56, 9.94 |
| A4 bright | 12.47, 14.90 | 21.83, 26.52 | 3.18, 4.11 |
| A5 bright | 11.96, 13.35 | 21.93, 27.54 | 2.87, 3.38 |
| A5 classic | 4.80, 6.28 | 8.94, 9.88 | 1.94, 2.20 |

**Rubber band** (`vperf.tcl` grow mean; `perfb2.tcl` band motion, 1600 FETs + 1600 wires;
`bandbig.tcl` with `V_FRAC=1.0`), widths 2300 / 3500 / 8200:

| | Shift band | Alt band | `perfb2` | `bandbig` grow | `bandbig` jitter |
|---|---|---|---|---|---|
| `~/gsl0` classic | 13.91,14.72 / 26.74,28.27 / 6.22,6.58 | 9.99,10.64 / 19.53,22.59 / 22.12,22.00 | 9.62,9.28 / 51.24,52.31 / 11.77,14.41 | 3.83,3.96 / 7.38,8.27 / 2.31,2.46 | 10.84,12.13 / 27.10,27.85 / 6.50,6.56 |
| A4 halo | 2.26,4.15 / 4.04,7.92 / 0.99,2.10 | 2.03,3.85 / 2.68,5.48 / 2.52,5.00 | 12.90,15.16 / 2.05,2.27 / 0.88,0.79 | 1.34,1.39 / 2.94,2.96 / 3.60,3.77 | 2.26,2.15 / 5.32,5.19 / 2.02,1.88 |
| A5 halo | 1.94,2.08 / 4.05,3.76 / 1.27,1.16 | 1.89,1.74 / 2.58,2.60 / 2.68,2.40 | 12.39,11.88 / 2.09,1.97 / 0.78,0.75 | 1.27,1.31 / 2.89,2.88 / 3.57,4.17 | 2.86,2.14 / 5.31,5.89 / 1.80,2.55 |
| A4 bright | 2.13,2.83 / 3.82,4.54 / 0.80,1.24 | 1.81,2.40 / 2.61,3.36 / 2.43,3.30 | 11.65,11.77 / 2.07,1.88 / 0.73,0.74 | 1.15,1.23 / 2.74,3.02 / 1.43,1.50 | 2.63,2.26 / 5.24,5.83 / 1.12,1.16 |
| A5 bright | 2.03,3.88 / 4.01,4.75 / 0.75,0.94 | 1.75,2.12 / 2.55,3.21 / 2.31,2.77 | 11.69,12.98 / 1.89,2.30 / 0.72,0.91 | 1.20,1.33 / 2.89,3.19 / 1.50,1.48 | 2.00,2.45 / 5.14,5.83 / 1.15,1.08 |
| A5 classic | 14.01,17.15 / 27.65,29.77 / 6.68,7.17 | 10.03,10.38 / 20.88,23.45 / 23.84,23.89 | 9.08,9.77 / 51.81,55.54 / 11.57,12.91 | 3.95,4.15 / 7.02,7.99 / 2.01,2.27 | 10.44,11.72 / 23.66,26.08 / 6.22,6.53 |

**Drag** (`dragbench.tcl`, gates sheet, ms per step):

| | K=390 | K=826 |
|---|---|---|
| `~/gsl0` classic | 6.22, 6.53 | 4.23, 5.07 |
| A4 halo | 4.92, 4.96 | 9.35, 9.43 |
| A5 halo | 4.82, 5.49 | 9.49, 10.12 |
| A4 bright | 4.95, 4.69 | 9.05, 8.97 |
| A5 bright | 4.78, 5.42 | 9.21, 10.44 |
| A5 classic | 6.11, 6.98 | 4.21, 4.86 |

**Reading.**
- A5 is within noise of A4 on every row.
- A5 classic is within noise of base.
- The rows match A3's figures: hover 6.84 / 1.19 / 0.97, crosshair 10.72 / 0.86 / 0.79,
  full-span 10.74 / 4.62 / 4.44, band motion 12.31 / 0.66 / 0.52, unselect all 6.67 / 0.73 /
  0.49, select all at 2300 5.07 / 14.41 / 12.75, `perfb2` at 3500 54.76 / 2.52 / 2.45.
- Two styled costs are old and were declared earlier:
  - select all is about 2.5x classic at 2300 and 4.5–5x in halo at 8200;
  - a drag at K=826 is about 2x classic. A2 measured 5.11 against 10.69.

## What I did not cover

- **Real hand input.** Every gesture was synthetic. Only the Exposes in `v5_realwin.tcl` and the
  crew's TM rows come from real window changes.
- **The real Windows build.** `~/gsa5w` is an emulation on Linux.
- **The rest of the style matrix.** The full regression set ran in 4 of the 8 style, text and
  scheme configurations on `~/gsa5`, plus one each on `~/gsa5w`, `~/gsa5n`, `~/gsa4w` and
  `~/gsa4n`. Halo `colour` light, halo `own` dark, bright `colour` light and bright `own` dark
  had only the claim-1 rows.
- **The two hanging suites.** I did not diagnose them. They hang the same way on base.
- **Excluded by the brief.** `:0` and Xwayland, the user's screen, and T1.
- **A human look at any pixel.**

## Housekeeping

- I stopped my Xvfb and openbox on `:286`–`:293` by pid, after checking each cmdline and
  `DISPLAY`.
- I deleted every `*~.sch` in the seven clones. All were newer than my start mark, and none were
  older.
- I deleted the suite scratch dirs my timed-out runs left in `~/gsa5` and `~/gsl0`, and four
  `/tmp/xschem_emergencysave_untitled_*` dirs that my own killed runs named in their output.
- I left other emergency-save dirs from this morning in `/tmp`, because I cannot prove they are
  mine.
- I left a `plot.xpm` in `~/gsa4n` and `~/gsa5n`. It came from my print pose and is untracked.
- I did not touch the main tree's backups.
