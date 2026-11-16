# Stage A4 receipt: N4, and what a repair does to a shape being placed

Crew: stage-A4 fix crew, 2026-11-15. Base: `e3c43487e` (pristine build `~/gsl0`). Red bed: `~/gsa3`
(the A3 tree, not edited). All edits are in the main tree and are **uncommitted**, on top of A2's
and A3's uncommitted change. The A4 part alone (against `~/gsa3/src`) touches `src/move.c`,
`src/draw.c`, `src/callback.c` and `src/xschem.h`. `actions.c`, `select.c`, `xinit.c` and
`xschem.tcl` are as A3 left them.

## How it was measured

- **Displays.** My own Xvfb `:276`, `:277` and `:278` (1920x1080x24), each with openbox (checked
  with `_NET_SUPPORTING_WM_CHECK`). `DISPLAY` was unset in every calling shell. Every run had
  `GUI_GATE=0`, a throwaway `HOME`, and its cwd in a clone. I never used `:99`, `:0` or the user's
  screen, and never ran T1.
- **Trees.** `~/gsa4` is a clone of `e3c43487e` holding this tree's `src`; a sync script copies the
  changed files, builds, and proves every tracked `src` file identical to the main tree. Two more:
  `~/gsa4w` (Windows emulation: `SEL_REAL_XCLIP 0` plus the two `#if 0` in `xinit.c`, as A3 did)
  and `~/gsa4n` (non-cairo). `~/gsa4s` was a throwaway copy for the sabotages.
- **Pixels.** `magick compare -metric AE` against a full `xschem redraw` of the same state, unless
  a section says otherwise. "colour" and "own" are `selection_text_style`.
- **Scratch.** `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A4/`
  (below, `A4/`): poses in `A4/scr/v/`, A4 logs in `A4/log/`, snapshots in `A4/out/`, images in
  `A4/img/`. The re-run of every earlier repro lives in `A4/r/` (a copy of the A3 verifier's `V3/`
  scripts pointed at `~/gsa4*`). Scratch, not durable.

## N4: `load -window` Cancel leaves the styled selection wrong

**Cause.** The verifier's reading is right, and it is one case of a wider one. A3's
`sel_ctx_on_screen` asked which tab is *front* (`get_drw_front_win()`). But what the shared `.drw`
canvas shows is the drawing of the last tab that was fully drawn there, and the two differ after
any switch that does not draw. `switch_tab()` with `dr` 0 makes the target current and front
(`note_drw_front()`) and draws nothing. The `load -window` save prompt then runs the event loop, so
`sel_idle_cb` runs with the canvas still showing the main tab: it dropped the main tab's damage as
hidden and painted the target's into the main tab's drawing. Cancel switches back with `dr` 0, so
nothing repaints.

**Fix** (`src/move.c`, `src/draw.c`, `src/xschem.h`).
- A new `sel_canvas_win` in `move.c` holds the tab whose drawing the canvas holds.
  `sel_note_canvas()` sets it. `draw()` calls it once a full redraw has reached the window (not a
  bbox redraw, not `print_image()`, which draws only into the pixmap). Real windows are skipped:
  they own their X window.
- `sel_ctx_on_screen` uses `sel_canvas_win` instead of `get_drw_front_win()`. A real window and
  every window of the windowed interface are always on screen, as before; so is the one context of
  a session with no other tab or window.
- `sel_idle_cb` now puts the **current** context through the same test. Before, it was always
  flushed. A tab that is not on the canvas drops its damage; it is fully redrawn when shown.
- `get_drw_front_win()` and `note_drw_front()` are unchanged. `hilight.c` still uses them (issue
  0073), so that base behaviour does not move.

**Why not the verifier's suggestion** (repair the outgoing tab synchronously inside
`switch_tab()`). It covers damage that is pending at the moment of the switch. It does not cover
damage the target already had (K2 below: A3 6173), which is still painted into the wrong drawing
once the target is "front". It would also need a call in every switch path. Tracking what the
canvas holds covers every path that does not draw, in one place. (This is reasoned from the code;
I did not build the alternative.)

**Red and green** (AE after Cancel against a full redraw; C1 and C2 are the verifier's cases):

| build | `ctx_cancel` (scripted Cancel) C1 / C2 | `ctx_cancel2` (real dialog, Cancel pressed) C1 / C2 |
|---|---|---|
| A3 `~/gsa3` halo `colour` (red) | 8683 / 14658 | 8683 / 14658 |
| A3 bright `colour` (red) | 6744 / 9195 | — |
| A3 bright `own` (red) | — | 6528 / 10026 |
| A4: halo and bright, `colour` and `own`, dark; halo `colour` and bright `own`, light | 0 / 0 | 0 / 0 |
| A4 `~/gsa4w` halo `colour`, bright `own` | 0 / 0 | 0 / 0 |
| A4 `~/gsa4n` halo, bright | 0 / 0 | 0 / 0 |
| A4 classic, `~/gsl0` classic, dark and light | 0 / 0 | 0 / 0 |

The selection really changed: the "before" state against C1's is 8683 (halo `colour`), 6528
(bright `own`), 4824 (classic). Images (left A3, middle A4, right a full redraw):
`A4/img/N4_c1_red_green_redraw_halo.png`, `A4/img/N4_c2_red_green_redraw_halo.png`.

### Every other path that changes the on-screen context

I read `switch_tab`, `switch_window`, `create_new_tab`, `create_new_window`, `destroy_tab`,
`detach_tab`, `swap_tabs`, `swap_windows` and the `new_schematic` arms in `xinit.c`, and every C
caller of `new_schematic`. The paths that do not draw are: the `load -window` branch in
`scheduler.c`, `xschem new_schematic switch <tab> <file> 0`, `create_new_tab` with `dr` 0,
`swap_windows` with `dr` 0 (from `xschem exit` in the windowed interface), and the redraw-only
switch an Expose makes (`switch_no_tcl_ctx`). New poses: `A4/scr/v/ctx_a4.tcl`, `ctx_a4b.tcl`,
`win_a4.tcl`, `win_exit.tcl`.

| case | what it does | A3 halo | A4, every style and tree |
|---|---|---|---|
| K1 | damage in main, `new_schematic switch t1 … 0`, idle, back with `dr` 0 | **8683** | 0 |
| K2 | damage in t1 and in main, same round trip | **6173** | 0 |
| K3, K3_main | `dr` 0 switch to t1, then t1 drawn, then a select in t1 | 0 | 0 |
| K4_drawn, K4_main | `create_new_tab` with `dr` 0, damage pending | 0 | 0 |
| K5 | real window `w` current, select pending in the front tab | 0 | 0 |
| O1, O1b, O1c, O2, O2_main | `load -window`, answered No (the load goes ahead) | 0 | 0 |
| R1, R2, R2b | `swap_tabs` (tab reorder) with damage pending | 0 | 0 |
| R3, R3_main | tab click (a `dr` 1 switch) with damage pending | 0 | 0 |
| X1 | close the main tab with damage pending | 0 | 0 |
| WC1, WC1_w1, WC2, WC2_w1b | windowed (`tabbed_interface 0`) `load -window`, Cancel | 0 | 0 |
| WO1_w1, WO1b_w1, WO1, WO2_w1, WO2 | windowed `load -window`, answered No | 0 | 0 |
| E1, E2 | windowed `xschem exit` of the main window with a second window open, damage pending in either (`swap_windows`) | 0 | 0 (halo `colour`, bright `own`, classic only) |

"Every style and tree" is halo and bright, `colour` and `own`, dark, halo `colour` and bright `own`
light, on `~/gsa4`, plus halo `colour` and bright `own` on `~/gsa4w` and halo and bright on
`~/gsa4n`. Classic on `~/gsa4` and `~/gsl0` is 0 too. The table answers task 2(b)
(reordering, R1–R3) and 2(c) (windowed, WC/WO) as well: neither was broken, on A3 or A4. A reorder is
a pure `pack` change on the Tcl side, and a tab click draws.

**K6, a base bug, not fixed.** A synthetic Expose of `.drw` while a real window is current and tab
t1 is front pastes the **main** tab's pixmap over t1's drawing, in every build, classic included:
`~/gsl0` classic 62028 px between before and after, A4 classic the same, halo 63651. The cause is
the redraw-only switch: `handle_window_switching()` calls `new_schematic("switch_no_tcl_ctx",
".drw", …)`, and `switch_window()` maps `.drw` to slot 0, the main tab, not to the tab the canvas
holds. K6b (a select in t1 then the same Expose) inherits it in every build. Fixing it changes
classic, which this stage may not do. **Proposed fix:** in that Expose arm, under the tabbed
interface, resolve `.drw` to the tab whose drawing is on the canvas (`get_drw_front_win()`, or
`sel_canvas_win`) before switching. Not built. Image (`~/gsl0` classic, before and after):
`A4/img/K6_expose_base_classic_pre_post.png`.

## Task 2(a): a repair wipes a shape being placed

**Measured on A3.** A wire, line, rectangle, polygon, arc or zoom box being placed is a window-only
drawing. It is not in the pixmap, and `sel_paint_others` does not repaint it. So a styled repair
wipes it wherever the damage meets it, and wipes all of it when the repair is of the whole window.
Pose `A4/scr/v/rub2_a4.tcl`: each shape crosses M1 and a wire, then one trigger, then no motion:
- e1 a small Expose, e2 an Expose of most of the window;
- s1 `select_all` (a full-window repair through `sel_pend_full()`);
- m1 select M1, d1 deselect M1 (both under the shape).

Metric: **OUT/IN**. OUT is pixels off the shape's path where the snapshot differs from a full
redraw. IN is pixels on the path where it differs from the same shape with no trigger. A motion
away and back is not a fair reference: it differs from a full redraw off the path too (see
"Other findings").

| A3 halo, IN (OUT is 0 throughout) | e1 | e2 | s1 | m1 | d1 | path px |
|---|---|---|---|---|---|---|
| wire | 0 | **1313** | **1313** | 0 | 0 | 1329 |
| line | 0 | **1317** | **1317** | 0 | 0 | 1317 |
| rect | 0 | **2627** | **2627** | **404** | **404** | 2627 |
| polygon | 0 | **944** | **944** | **385** | **385** | 944 |
| zoom box | 0 | **2611** | **2611** | **404** | **404** | 2611 |
| arc (first stage) | 0 | **947** | **947** | **389** | **389** | 947 |
| arc (placed, second stage) | 0 | **2362** | **2362** | **416** | **416** | 2362 |

Bright gives the same. Classic (`~/gsl0`, and A4 the same): e2 wipes it too (wire 1329, rect 2627,
zoom 2611), which is upstream. A select cuts a little (rect s1 70, d1 82). So styled was worse than
classic on s1, m1 and d1, and as bad on e2.

**Fix** (`src/move.c`, `src/callback.c`, `src/xschem.h`). A new `sel_rubbers_restamp()` stamps the
shape again from the owner's own state (`nl_x1` … `nl_y2`, `nl_polyx/y`, the arc's `nl_x`, `nl_r`,
`nl_a`, `nl_b`) with the owner's own GC, then the crosshair and snap cursor, in a motion's order.
It is called after the two repairs that no motion follows: `sel_idle_cb` (for every context it
repairs) and the styled branch of `handle_expose`. It does nothing in classic.
- It is **not** called from `sel_overlay_flush` itself. Every owner calls `restore_selection()`
  between erasing its old shape and stroking the new one, so a stamp there paints the old shape
  back.
- My first version asked the owner to stroke again (`redraw_w_a_l_r_p_z_rubbers(1)`). Against the
  motion reference it was worse than no fix (wire e1/e2 1932/1788, rect 2620/3416), because
  `callback()` moves the pointer to an Expose's corner and the owner strokes to the pointer. Hence
  a pure stamp from stored state.

**Green: OUT/IN 0/0 in every cell** (all seven kinds × five triggers):
- halo `colour`, bright `own`, halo light, halo `own` light, bright light;
- crosshair on, snap cursor on, hover on (halo);
- `~/gsa4w` halo and bright `own`, `~/gsa4n` halo and bright `own` light.

With the crosshair on, the full redraw after an Expose is itself off by 23 px (e1) and 12 px (e2):
the Expose moved the pointer, and the redraw paints the crosshair's centre mark there. `~/gsl0`
classic shows the same. So for those I compared the snapshot with the untriggered state instead:
0 for every kind.

Images (left A3, middle A4, right the untriggered shape): `A4/img/R_rect_e2_a3_a4_expected_halo.png`,
`A4/img/R_rect_m1_a3_a4_expected_halo.png`, `A4/img/R_arc_e2_a3_a4_expected_halo.png`.

The arc's second stage needed a pose fix: the first version placed the arc's second point under
the final pointer, so the arc was degenerate and drew nothing (0 path pixels). It now places it
elsewhere, and the row has 2362 path pixels. The runs made before that fix (crosshair, snap
cursor, hover, light, bright light, `~/gsa4w` halo, `~/gsa4n` halo) therefore cover six kinds, not
seven. The fixed arc is 0/0 on A4 halo, bright `own`, halo `own` light, `~/gsa4w` bright `own` and
`~/gsa4n` bright `own` light, and red on A3 as in the table.

## Sabotages (each on `~/gsa4s`, restored with `cp` and proved with `cmp`)

| sabotage | what reddened (halo) | stayed 0 |
|---|---|---|
| S1: drop the `sel_rubbers_restamp()` call in `handle_expose` | e2: wire 1313, rect 2627, zoom 2611 | e1, s1, m1, d1 |
| S2: drop both calls in `sel_idle_cb` | s1: wire 1313, rect 2627, zoom 2611; m1/d1: rect 404, zoom 404 | e1, e2 |
| S3: `draw()` no longer calls `sel_note_canvas()` | K3 4998, K5 5270, O1b 1996, R2 13351, R3 13106, `ctx_v3` h1 18133, h3 19502, h4 5133, `ctx_tab` t1 15483 | C1, C2, K1, K2 |
| S5: `sel_idle_cb` flushes the current context without the test | C2 8485 | C1 and the rest |
| (A3's front-tab rule is `~/gsa3`) | C1 8683, C2 14658, K1 8683, K2 6173 | |

After the restore: `cmp` equal to the main tree for all four files, C1/C2 0/0, rubber 0.

## Earlier repros, re-run on A4

All in halo and bright, `colour` and `own`, dark and light, on `~/gsa4`, `~/gsa4w` and `~/gsa4n`
unless stated.

- **A2 repros** (D1 `partial`, D2 `fillrect` and `instzoom_hide`, D3 `scoperep`, D4 `xhair`, D5
  `customfont`, L1 `fastsel`): line for line the same as the A3 verifier's logs, in all eight
  configurations it ran (`colour`, `own`, light, light `own`, emulation, emulation `own`,
  non-cairo, `~/gsl0`). All 0, except D1's wire 184, which classic gives too.
- **D7 `winemu`** on `~/gsa4w`: w1, w2, w3 all 0, in halo and bright, `colour` and `own`,
  `fix_broken_tiled_fill` 0 and 1.
- **A2's `expo*`**: e1, e2, e3, expo2, expo3, expo4 a/b, expo5 e1/e1b all 0, in 11 configurations
  including light, emulation, non-cairo and classic. expo3 needs a `V_TXT`; A3's value was not
  recorded, so I used `Expose gjpqy text`.
- **The verifier's scenario scripts** (`drag2`, `ovl`, `hil`, `hil2`, `sw`, `ctx_tab`, `ctx_win`,
  `ctx_misc`, `print`, `bigdrag`, `pin1`, `det_ev`, `det_net`, `band`, `band3`, `bandae`): in the
  four configurations the verifier ran (A3 halo `colour`, bright `own`, classic; `~/gsl0` classic)
  the scores equal its own, and all 426 snapshots of the three A4 ones are pixel-**identical** to
  its A3 snapshots (`bigdrag` writes timings only). I also ran halo `own`, bright `colour`, light,
  `~/gsa4w` and `~/gsa4n`. In every configuration the only nonzero scores are the known
  ones: `ovl` o7–o9 15–20, and o6 3 in classic (the snap-cursor diamond a redraw drops; `~/gsl0`
  gives the same), and `ctx_misc` m2/m5/m6 (scripted undo, upstream).
- **N1 / N3 scripts**: `ctx_detach` d4 and `ctx_mix` a–d are 0 on `~/gsa4`, `~/gsa4w`, `~/gsa4n`
  and `~/gsl0` in every style. `ctx_v3` h1–h7 are 0 in 11 configurations.
- **`vband`** (the band over a big selection): the analysis files are byte-identical to the
  verifier's A3 ones for all six configurations it ran, and for its emulation and non-cairo runs.
  `vband_k`: byte-identical to the verifier's for all nine of its configurations (seven A3, two
  `~/gsl0`).
- **Classic byte-identity against `~/gsl0`**:
  - A2's 15 states, dark: 15 of 15 AE 0; light: 15 of 15;
  - the A2 repros: 34 of 34 snapshots; `expo*`: 15 of 15;
  - `ctx_v3` 20 of 20, `ctx_detach` 10 of 10, `ctx_mix` 8 of 8, `win_exit` 4 of 4;
  - the scenario scripts: 141 of 142 snapshots, dark and light. The one left is the full-page PNG
    export (205 px): the title block's file date, which differs between clones. A2-verify
    recorded it, and A4's export equals A3's exactly;
  - `vband`: 88 of 88 snapshots, dark and light;
  - the rubber pose: 126 of 126 (dark), 126 of 126 (light), 126 of 126 (crosshair), 18 of 18 (arc);
  - `ctx_cancel` 5 + 5, `ctx_cancel2` 5 + 5, `ctx_a4` 20 + 20, `ctx_a4b` 22 + 22, `win_a4` 21 + 21
    snapshots (dark + light), all identical.
  - Non-cairo has no base build, so `~/gsa4n` classic was compared with A3's `~/gsa3n`: 34 of 34
    identical.

## Health

- **Valgrind** (`-q --error-exitcode=99`, display arm): `ctx_v3` halo, `ctx_mix` bright `own`,
  `ctx_detach` halo, `ctx_cancel` halo and classic, `ctx_cancel2` bright, `ctx_a4` halo,
  `ctx_a4b` halo, `win_a4` halo, the rubber pose halo (wire, rect, zoom box, placed arc), and
  `ctx_cancel` on `~/gsa4w`. 11 runs: each exit 0, empty valgrind log, each reached its end
  (`V-DONE`), and `ctx_cancel` under valgrind still gives C1/C2 0/0.
- **`--nogui` and `--pipe`**: `nogui2.tcl` and `nogui3.tcl`, both modes, classic, bright and halo,
  `colour` and `own`, on `~/gsa4`, `~/gsa4n` and `~/gsa4w`, all under valgrind: 72 runs, every one
  exit 0, valgrind log empty, no `FATAL`. The end marks share one name per configuration, so only
  the last tree's (`~/gsa4w`) are proved written: all 24 are. The 24 `~/gsa4` logs equal A3's
  line for line once paths are normalised (they include the `.drw configure -cursor` messages a
  `--pipe` run prints, as A3's do).
- **Suites** (`run_suites.sh` on `~/gsa4`, A2's lists): every verdict line is identical to A3's,
  which were identical to base. Display arm `:278`, 31 suites: 28/30 passed, 1 skipped
  (`test_select_at` 5 FAILED and `test_cadence_drag` 2 FAILED, as on base). Counted arm, 34 suites:
  19/24, 10 skipped. Source-scanning suites: 10/10 on the display arm, 7/9 counted.
- **Warnings.** Every `.c` in `OBJ` compiled for base and for A4: cairo and non-cairo, each with
  default flags, `-std=c89 -pedantic`, and (for information) `-Wall -Wextra`. With line numbers
  stripped the warning lines are **identical** to base in all six. The Windows-emulation sources
  (`~/gsa4w`) give the same lines as A3's emulation (`~/gsa3w`) in all three flag sets. All three
  trees build and link. Zero new warnings.

## Other findings (not fixed)

- **K6** above: an Expose of `.drw` while a real window is current repaints the wrong tab. Base,
  classic included.
- **A band motion over selected text, halo only.** With M1 or everything selected, a motion of the
  shape being placed leaves single rows of text anti-aliasing a shade darker than a full redraw:
  11–27 px, 146 for the zoom box. Classic gives 0 (zoom box 81). The figures are identical on A3,
  so this pre-dates A4. It is in the motion path, which this stage did not touch. Image (top after
  the motion, bottom a full redraw, 8x): `A4/img/A4_motion_residual_ref_over_full.png`.
- **The pointer follows an Expose** (issue 1659's shape). With the crosshair on, a redraw after an
  Expose draws the crosshair's centre mark at the Expose's corner. Classic too.

## What I could not do

- No real hand input and no look on a real screen. Every gesture is a synthesized event on Xvfb.
  The idle-repair and Expose paths are reached the same way in a real session, but a real pointer
  sends real motions, which a pose does not.
- K6's fix is not built: it would change classic.
- No non-cairo base build exists, so non-cairo classic was checked against A3, not base.
- The Windows build itself was not compiled; only the emulation.

## Housekeeping

- My Xvfb and openbox processes (`:276`, `:277`, `:278`) are stopped. I killed them by pid after
  checking each command line and `DISPLAY`. No lock or socket is left.
- My runs left `*~.sch` backups in `~/gsa3`, `~/gsa3n`, `~/gsl0` and my own clones, all written
  after this stage began (the A3 verifier had removed every earlier one). I removed them. `~/gsa3`,
  `~/gsa3n` and `~/gsl0` have no untracked files, and `~/gsa3`'s change is as A3 left it.
- The main tree's backups (59 files) have the same md5s as before this stage.
- `~/gsa4s` (the sabotage copy) is deleted. `~/gsa4`, `~/gsa4w` and `~/gsa4n` are kept for the
  verifier; each holds this tree's `src` (emulation toggles in `~/gsa4w`).
- Scratch under `A4/` is about 420 MB in `/tmp`, which is RAM here. Most of it is snapshots
  (`A4/out/`, `A4/r/out/`). Delete it once the verifier is done.
- I edited only `src/move.c`, `src/draw.c`, `src/callback.c`, `src/xschem.h` and this file.
