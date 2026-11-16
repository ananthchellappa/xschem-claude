# Stage A3 receipt: fixes for the A2 verify findings N1, N2, N3

Crew: stage-A3 fix crew, 2026-11-15. Base: `e3c43487e` (pristine build `~/gsl0`). Red bed: `~/gsv3`
(the A2 code, not edited). All edits are in the main tree and are **uncommitted**, on top of A2's
uncommitted change. `git diff --stat` for A2 plus A3 together: 8 files, 1704 insertions, 194
deletions. The A3 part alone (against `~/gsv3/src`) touches `src/actions.c`, `src/draw.c`,
`src/move.c`, `src/select.c` and `src/xschem.h`. `callback.c`, `xinit.c` and `xschem.tcl` are as
A2 left them.

## How it was measured

- **Displays.** My own Xvfb `:272`, `:273` and `:274` (1920x1080x24), each with openbox. `DISPLAY`
  was unset in every calling shell. Every run had `GUI_GATE=0` and a throwaway `HOME`. I never used
  `:99`, `:0` or the user's screen, and never ran T1.
- **Where the GUI runs ran.** All in `~/gsa3`, a clone of `e3c43487e` holding this tree's `src`.
  `scr/sync.sh` copies the changed sources across, builds, and proves every `src` file identical
  (`diff=0` at the end). This kept backup files out of the main tree. Two more copies:
  - `~/gsa3w` is Windows emulation (`SEL_REAL_XCLIP 0`, plus the two `#if 0` in `xinit.c`, as in
    `~/gsv2`);
  - `~/gsa3n` is a non-cairo build.
- **Pixels.** `magick compare -metric AE` against a full `xschem redraw` of the same state.
- **Band edge.** The count of band-grey (`#4F4F4F`) pixels on the two rows holding the band's
  lower edge, as in the verifier's N3 metric.
- **Time.** Milliseconds per motion or per operation, with `update` and a round trip. Where shown,
  CPU is split into xschem's own CPU and the X server's.
- **Scratch.** Scripts, logs and images are under
  `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A3/`
  (`scr/`, `v2/out/`, `a2/out/`, `img/`, `log/`). That is scratch and is not durable.

## N1: repair lost when a script switches to a real window

**Cause.** `sel_idle_cb` dropped the pending repair of every non-current context whenever
`tabbed_interface` was 1. That is right only for a hidden tab, which shares `.drw` and is fully
redrawn when shown. It is wrong in two cases:
- a real top-level window (a detached tab, or one made by `xschem new_schematic create_window`)
  has its own X window and stays on screen;
- the tab shown on `.drw` stays on screen when a real window becomes current, because a switch to
  a real window does not change the front tab.

**Fix.** A new `sel_ctx_on_screen` in `move.c` decides whether a context is on screen:
- every context in the windowed interface;
- in the tabbed interface, a context with a non-empty `top_path`, or the tab that
  `get_drw_front_win()` names.

`sel_idle_cb` walks the slots with `get_window_ctx`. It repairs an on-screen context into its own
window, with `xctx` switched to it, and drops damage only for a hidden tab. This is the same rule as
`net_hilight_ctx_visible` in `hilight.c`.

**Red and green.** AE of each window against its own full redraw.

| repro | red `~/gsv3` | green |
|---|---|---|
| `ctx_detach` D1 / D2 / D3 / D4, halo | 6633 / 6173 / 6173 / 0 | 0 / 0 / 0 / 0 |
| same, bright | 2854 / 4234 / 4234 / 0 | 0 / 0 / 0 / 0 |
| same, halo `own` | 6932 / 6303 / 6303 / 0 | 0 / 0 / 0 / 0 |
| `ctx_mix` A / B / C / D, halo | 5270 / 0 / 4016 / 0 | 0 / 0 / 0 / 0 |
| same, bright | 2238 / 0 / 1329 / 0 | 0 / 0 / 0 / 0 |

- Green is also 0 in bright `own`, in classic, on `~/gsa3w` (emulation) and on `~/gsa3n`
  (non-cairo).
- `ctx_mix.tcl` is new. It puts a tab, a second tab and a real window together, and switches
  before idle in four ways:
  - A: select in the front tab, then the real window becomes current;
  - B: select in the main tab, then another tab comes to the front. Its damage must **not** be
    painted over the new front tab;
  - C: select in the real window, then the main tab becomes current;
  - D: deselect all in the real window, then a tab becomes current.
- Images. Each one shows red `~/gsv3` on the left, A3 in the middle and a full redraw on the right.
  - `img/N1_detached_red_green_redraw_halo.png`: the selected `x5` is missing in red.
  - `img/N1_fronttab_red_green_redraw_halo.png`.

## N2: the rubber band over a large selection

**Cause.** There were two causes. Both made each motion cost as much as the whole selection.
1. `select_rect` (`actions.c`) erased the old band by stroking it with `gctiled`, then called
   `draw_selection`. In bright and halo that repaints the whole styled selection on every motion.
2. On the Shift band, `select_object(..., 0, ...)` ("remove near obj if dragging") also called
   `draw_selection` on every motion. My first fix did only part 1, and halo was still 56.7 against
   52 ms at width 3500 and 21.5 against 14.1 at 8200. A trace found this second full repaint.

**Fix.**
- In styled modes, the old band's four edges become damage (`sel_band_damage`). The repair restores
  them and repaints only the selection entries they meet.
- The band is now an overlay the repair knows about (`xctx->band_shown`). `sel_band_paint` stamps it
  again after the selection, scope, hover and fly-lines, and before the crosshair. That is the order
  a motion paints them in. `sel_paint_others` and `sel_styled_show` both call it. A full `draw()`
  clears `band_shown`, and the next motion paints the band again, as in classic.
- `select_rect` styled RUBBER does four things in turn: damage the old band, select, repair
  (`sel_overlay_flush`), paint the new band. END damages the band and repairs. Classic keeps its own
  sequence, untouched.
- `select_object`'s deselect branch repairs damage (`sel_overlay_flush`) in styled modes instead of
  calling `draw_selection`.
- A2's end-of-function flushes in `select_inside` and `select_touch` are gone. `select_rect` now
  flushes. The scripted `xschem select_inside` (and `font.c`'s caller) repair at idle instead of
  synchronously.

**Why this approach.** A band motion now costs what it changed, not what is selected. It keeps
A2's model: damage, then one repair that leaves the window equal to a full redraw. There is no
band-only drawing path. The same change also fixes N3.

**A case I found, and fixed.** A plain drag that grows a band over the whole view and then jitters
there was still slow. `select_inside` re-selects every object inside the old band on every motion.
Each call marked the object as damage although its look had not changed, so each motion repainted
everything inside. A new `sel_area_fast` in `select.c` fixes this. In styled modes, `select_inside`
and `select_touch` pass bit 2 (draw nothing) for a wire, text or instance that is already in the
state the band puts it in. Every other effect of those calls is unchanged. Classic is not affected:
the helper returns 1 when the style is classic.

### Timing: the verifier's band (`perfb2.tcl`, 1600 FET + 1600 wires, everything selected; ms per motion, 20 motions)

| view width | classic `~/gsl0` | A2 halo | A2 bright | **A3 halo** | **A3 bright** | A3 classic |
|---|---|---|---|---|---|---|
| 2300 (see note) | 9.75 | 16.06 | 12.50 | 13.33 | 13.85 | 11.02 |
| 3500 | 54.76 | 105.15 | 89.63 | **2.52** | **2.45** | 60.25 |
| 8200 | 14.59 | 42.54 | 11.20 | **0.91** | **0.98** | 15.52 |

- **Note on 2300.** The 2300 "band" in `perfb` is not a band. The Shift press lands on a selected
  object, so it becomes a copy-drag (`ui_state` 0x48 = SELECTION|STARTCOPY). The release then places
  copies, so the 3500 and 8200 phases run on a sheet with 3200 FETs. At 2300 halo is 1.2–1.4x
  classic. It goes through A2's drag path, not the band.
- An earlier run on a quieter machine gave the same picture: at 3500, 55.71 / 99.66 / 82.91 /
  **2.38** / **1.97** / 52.10; at 8200, 13.92 / 40.08 / 11.32 / **0.93** / **0.86** / 14.03.

### Timing: a band over the whole view (`bandbig.tcl`, plain drag from the sheet's corner over the whole view; ms per motion)

| phase, view width | classic `~/gsl0` | A2 halo | A2 bright | **A3 halo** | **A3 bright** | A3 classic |
|---|---|---|---|---|---|---|
| grow (20 motions), 2300 | 3.45 | 5.84 | 5.80 | 1.29 | 1.39 | 3.49 |
| grow, 3500 | 6.62 | 11.32 | 12.53 | 2.75 | 2.68 | 7.31 |
| grow, 8200 | 2.07 | 6.02 | 2.03 | **3.57** | 1.53 | 2.31 |
| jitter at full size (10), 2300 | 9.93 | 17.03 | 17.36 | **0.72** | 0.73 | 10.22 |
| jitter, 3500 | 21.25 | 36.20 | 39.48 | **2.01** | 1.72 | 22.46 |
| jitter, 8200 | 6.58 | 18.99 | 6.78 | **2.66** | 1.42 | 7.48 |

- Without `sel_area_fast`, A3 halo's jitter was 8.88 / 20.43 / **11.02**. At 8200 that is 1.67x
  classic.
- The selection at the end is 110, 255 and 1400 instances at the three widths.

### Timing: select all

`selall.tcl`: a clean 1600-FET sheet, `xschem select_all` plus the idle repair, median of 5, ms.
This batch ran while other jobs were using the machine. All six builds ran in it, one after another.

| view width | classic `~/gsl0` | A2 halo | A2 bright | **A3 halo** | **A3 bright** | A3 classic |
|---|---|---|---|---|---|---|
| 2300 | 5.07 | 13.59 | 13.98 | 14.41 | 12.75 | 5.21 |
| 3500 | 9.73 | 31.01 | 24.32 | 25.92 | 24.02 | 9.85 |
| 8200 | 2.59 | 12.97 | 4.28 | 11.04 | 5.27 | 2.57 |

- **Select all is not fixed.** Halo is still 2.7x, 2.7x and 4.3x classic. Where the time goes,
  measured:
  - **At 8200 it is the X server.** With the repair timed alone (`selall2.tcl`, 20 reps), A3 halo
    takes 9.98 ms. Of that, the X server uses 10.0 ms of CPU and xschem 2.0 ms. Bright takes
    2.99 ms. The cost is the X server drawing the halo's wide strokes for every visible FET.
  - **At 2300 and 3500 it is xschem's CPU, on texts.** At 3500, callgrind puts 67% of the repair
    in `translate()`. That is mostly `tcleval` on the sky130 FET's symbol texts: one call per
    visible text per repair, not duplicated. Classic's `draw_selection` pays the same upstream cost.
- **Three small changes went in for it.** None moves the wall time beyond noise.
  - `sel_pend_full`: a damage list covering half the window or more is repaired as the whole
    window, with no culling and no text closure. Halo went 25 → 23 ms at 3500 and 10.4 → 9.8 at
    8200.
  - `sel_pend_add` compaction: after a merge, rects now inside the grown rect are dropped, so no
    area is copied twice.
  - The own-colour pass of an instance (`draw_sel_entry`, ELEMENT) skips a layer that has no lines,
    polygons, arcs or rects in the symbol, past layer 0. Each skipped call drew nothing, but
    `draw_symbol` reads `lvs_ignore` through `tclgetboolvar` on every call. Callgrind: the repair
    went from 319M to 151M instructions for 3 select-alls at 8200, and xschem's CPU from 3.5 to
    2.0 ms. The wall time did not move, because the X server dominates there.
- The verifier's `perfb` select all, which runs on the sheet with copies, at 3500 / 8200: classic
  18.46 / 4.72, A2 halo 53.13 / 25.11, A3 halo 53.45 / 23.90, A3 bright 54.68 / 6.98.

### Hover and crosshair (D6, `perfv.tcl`, 1600 selected; ms)

| | classic `~/gsl0` | A3 halo | A3 bright |
|---|---|---|---|
| hover change | 6.84 | 1.19 | 0.97 |
| crosshair | 10.72 | 0.86 | 0.79 |
| full-span crosshair | 10.74 | 4.62 | 4.44 |
| band motion (perfv's own) | 12.31 | 0.66 | 0.52 |
| unselect all | 6.67 | 0.73 | 0.49 |

## N3: the band broken over selected text

**Cause.**
- Classic order: erase the old band with `gctiled`, draw the new band, then repaint the selection.
  The styled repaint restores each selected text's background from the pixmap, and the halo strokes
  cover what they cross. So the new band was cut wherever it crossed selected text or a halo.
- The comment above `sel_styled_show` claimed the band was stamped again. Nothing did that.

**Fix.**
- This is the N2 change: the band is painted after the repair, and every repair stamps it again
  (`sel_band_paint`).
- The comment above `sel_styled_show` is rewritten to be true:
  - the band is stamped again;
  - other window-only drawings (a zoom box, a wire or shape being placed) are covered where a stroke
    crosses them, and are erased inside every selected text's box;
  - their owner repaints them on the next motion.

**Red and green.** Band-grey pixels on the band's lower-edge rows 109 / 110 (`band.tcl`):

| build | rows 109 / 110 |
|---|---|
| classic `~/gsl0` | 829 / 829 |
| red `~/gsv3` halo | 518 / 562 |
| red `~/gsv3` bright | 577 / 577 |
| A3 halo, bright, classic (`colour` and `own`; also `~/gsa3w`) | 829 / 829 |

- Image: `img/N3_band_red_vs_green_halo.png` (top red, bottom green).
- A new `band3.tcl` sends an Expose over the band's edge while the band is up:

  | build | rows 109 / 110 |
  |---|---|
  | A3 halo and bright | **829 / 829** |
  | red `~/gsv3` halo | 491 / 535 |
  | red `~/gsv3` bright | 550 / 550 |
  | classic, on `~/gsl0` and A3 alike | 751 / 751 |

  In classic, the Expose cuts the band. That is upstream behaviour and it is unchanged.

## Sabotages

Each was built in a throwaway copy (`~/gsa3s`), restored with `cp`, and checked with `cmp` against
the main tree.

| sabotage | effect |
|---|---|
| **S1**: `sel_area_fast` skips the mark for every object, changed or not | `bandae` (new, below) halo: plain 13005, Shift 11289, Alt 11943, right-to-left 23410, Shift right-to-left 9955. **Red.** |
| **S3**: `sel_paint_others` does not call `sel_band_paint` | `band.tcl` and `band2.tcl` (full-span crosshair): 829 / 828. **Not red**: a motion paints the band last anyway. `band3.tcl` (Expose during the band): **556 / 556**, halo and bright. **Red.** |
| N1, N3 | the red bed `~/gsv3` is the A2 code itself (tables above) |

- **`bandae.tcl` (new).** Five area selects over already-selected objects on a 400-FET sheet with
  texts visible:
  - a plain band that grows, jitters, then shrinks back;
  - a Shift (add) band;
  - an Alt (deselect) band;
  - a right-to-left (touch) band;
  - a Shift right-to-left band.

  Each final state is compared with its full redraw:

  | build and style | result |
  |---|---|
  | A3 halo and bright, `colour` and `own`, on `~/gsa3`, `~/gsa3w` and `~/gsa3n` | all 0 |
  | `~/gsv3`, `~/gsl0` | 0 (it was not a red there) |
  | classic, A3 against `~/gsl0` | identical |

  The cases select 30, 49, 35, 49 and 62 objects. Halo against classic differs by 41137 px, and
  `own` against `colour` by 16049, so the styles were live.

## Classic is unchanged

Classic on `~/gsa3` against `~/gsl0`, final code, AE per snapshot:
- **A2's 15 states** (`classic_seq.tcl`): 15 of 15 dark, 15 of 15 light.
- **Verifier and A3 scripts:**

  | script | snapshots AE 0 |
  |---|---|
  | `drag2` | 19 / 19 |
  | `ovl` | 20 / 20 |
  | `band` | 1 / 1 |
  | `hil` | 5 / 5 |
  | `hil2` | 5 / 5 |
  | `sw` | 11 / 11 |
  | `ctx_detach` | 10 / 10 |
  | `ctx_tab` | 8 / 8 |
  | `ctx_misc` | 30 / 30 |
  | `ctx_mix` | 8 / 8 |
  | `bandae` | 10 / 10 |
  | `print` | 14 / 15 |

- **`print`.** The one difference is `p_png_full`, 205 px. It is the title block's file date: each
  clone has its own checkout time (`~/gsl0` 00:05:54, `~/gsa3` 04:12:41). Image:
  `img/print_png_full_corner_base_vs_a3.png`.
- **The A3 classic paths are guarded by construction.** `sel_band_damage`, `sel_band_paint` and
  `sel_pend_add` return early in classic. `select_rect` keeps the classic branch verbatim.
  `sel_area_fast` returns 1. The `select_object` change is inside a style test.

## Repros on the final code

All on `~/gsa3`, AE. Wire 184 in D1 is upstream: classic and `~/gsl0` also give 184.

| repro | halo, bright (`colour`) | `own` | light scheme (`colour`, halo `own`) | emulation `~/gsa3w` (`colour`, `own`) | non-cairo `~/gsa3n` |
|---|---|---|---|---|---|
| D1 `partial` text / wire | 0 / 184 | 0 / 184 | 0 / 184 | 0 / 184 | 0 / 184 |
| D2 `fillrect` back / abort / unselect | 0 / 0 / 0 | 0 | 0 | 0 | 0 |
| D2 `instzoom_hide` | 0 / 0 / 0 | 0 | 0 | 0 | 0 |
| D3 `scoperep` white px; text vs redraw | 30/30; 0 | 30/30; 0 | — (white is the background); 0 | 30/30; 0 | 30/30; 0 |
| D4 `xhair` | 0 | 0 | 0 | 0 | 0 |
| D5 `customfont` sel / desel | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| L1 `fastsel` f1 / f2 / f3 | 0 / 0 / 0 | 0 | 0 | 0 | 0 |
| D7 `winemu` w1 / w2 / w3 on `~/gsa3w` | halo and bright, `colour` and `own`, `fix_broken_tiled_fill` 0 and 1: all 0 | | | | |

- **A2's `expo*`.** e1, e2, e3, expo2, expo3, expo4 a / b, expo5 e1 / e1b: all 0. That holds in
  halo and bright, `colour` and `own`, on `~/gsa3` and `~/gsa3w`.
- **A2's `ovl*`.** Hover over text, hover over a wire, crosshair, full-span crosshair and a plain
  click (`ovl3`, every hover and crosshair setting) are all 0. The Shift-click (`ovl` o5, `ovl2`)
  gives 401 and 15–16. That is the snap-cursor diamond a redraw drops, as A2 recorded. Classic does
  the same.
- **The verifier's other scripts, halo and bright, against their redraws.**
  - All 0: `drag2` 6/6, `hil` 2/2, `hil2` 2/2, `sw` 4/4, `ctx_tab` 4/4, `ctx_win` 2/2.
  - `ovl` 7/10: o7–o9 are 15–16 px of snap diamond. `~/gsl0` classic gives 16–19.
  - `ctx_misc` 12/15: `m2_undo_delete`, `m5_move_then_undo` and `m6_redo` are nonzero. `~/gsl0`
    classic also gives 4846 / 13207 / 13207. A scripted `xschem undo` leaves the window
    unrepainted; this is upstream, as the verifier recorded.

## Valgrind

`valgrind -q --error-exitcode=99` on `~/gsa3`. Every log is empty and every exit is 0:

| scripts | styles |
|---|---|
| `ctx_detach` | halo `colour`, bright `own` |
| `ctx_mix` | halo `colour`, bright `own` |
| `ctx_tab` | halo `own` |
| `ctx_win` | halo `colour` |
| `band` | halo `own`, bright `colour` |
| `bandae` | halo `colour`, bright `own` |
| `bandbig` | halo, width 3500 |
| `selall_cg` | halo at 8200 (the whole-window repair), bright at 3500 |

## Headless

I made `nogui2.tcl` from `nogui.tcl`. It adds repeated `xschem select_inside` (select, reselect,
deselect) and `xschem select_all`. I ran it with `--nogui` and with `--pipe`, `DISPLAY` unset, in
classic, bright and halo, each with `colour` and `own`, all under valgrind. All 12 runs exited 0
with empty valgrind logs, and each reached its final mark.

## Warnings

Every `.c` in `OBJ` was compiled for base (`~/gsl0`) and for A3 in four configurations:
- cairo, default flags;
- cairo, `-std=c89 -pedantic`;
- non-cairo, default flags;
- non-cairo, `-std=c89 -pedantic`.

I also added `-Wall -Wextra`, for information. In every configuration the warning lines, with line
numbers stripped, are **identical** between base and A3. Zero new warnings. The non-cairo A3 links
without cairo. `~/gsa3n` is a full non-cairo build, and `ldd` shows no cairo.

## Suites (`~/gsa3`, `run_suites.sh`, `GUI_GATE=0`)

I ran A2's lists. Every result is identical, line for line, to the base runs A2 recorded on
`~/gsl0`.

| run | result |
|---|---|
| display arm `:274`, 31 selection suites | 28/30 passed, 1 skipped. `test_select_at` (5 FAILED) and `test_cadence_drag` (2 FAILED) fail the same way on base. `test_expose_repaint` self-skips. |
| counted arm (`--nogui`, `AUDIT_DISPLAY=none`), 34 suites | 19/24 passed, 10 skipped, the same as base |
| source-scanning suites, display arm (10) | 10/10 |
| the same 10, counted arm | 7/9, 1 skipped, the same as base |

## Housekeeping

- **An incident in the main tree.** My first `ctx_detach` and `ctx_mix` runs ran in the main tree,
  before I moved GUI runs to `~/gsa3`. They rewrote
  `sky130A/xschem_libs/sky130_tests/not/schematic/not~.sch` there (mtime 04:12, 2302 bytes). The
  brief says to leave that file alone, and I cannot restore its earlier content. It is a gitignored
  backup. I made no other change to the main tree outside `src/` and this receipt.
  - `tests/from_user/before_5~.sch` (02:59) is not mine.
  - `src/untitled~.sch` (2026-09-30) is not mine.
- I removed the backups my runs left in `~/gsl0`, `~/gsv3` and my own clones. The files were
  `not~.sch`, `untitled~.sch` and `tests/from_user/before_5~.sch`; the last was left in `~/gsa3`
  by the suites.
- I killed my Xvfb and openbox processes by pid.
- I deleted `~/gsa3s` (the sabotage copy).
- **Kept for the verifier:**
  - `~/gsa3` (cairo, green);
  - `~/gsa3w` (Windows emulation);
  - `~/gsa3n` (non-cairo).

  Each holds this tree's `src` at the time of writing. Delete them when they are no longer needed.
- The main tree builds clean: `make -q -C src` gives 0, and no `.c` or `.h` is newer than
  `src/xschem`.

## What I could not do, or did not do

- **Select all is still 2.7–4.3x classic in halo.** See the timing section. The rest of its cost
  is not cheap to remove:
  - at far zoom it is the X server drawing wide strokes;
  - at text-visible zoom it is upstream `translate()` on every visible symbol text.
- **The grow phase of a whole-view band in halo is 1.5–1.7x classic at width 8200.** That is
  3.57 ms against 2.07–2.31. Each motion selects a new strip of FETs, and the X server draws their
  halo. The absolute cost is small. The jitter phase and the verifier's band are far below
  classic.
- **An object already selected but never painted is no longer repainted by a band passing over
  it.** In styled modes the band skips the record for an object whose state does not change
  (`sel_area_fast`). Callers that select with bit 2 promise to repaint themselves. This is
  `select_connected_nets`, the undo reselect and the stretch code. Classic would repaint such an
  object as a side effect; styled will not.
- **The scripted `xschem select_inside` repairs at idle now, not inside the call.** A script that
  takes a screenshot without letting Tcl go idle would see the old picture.
- **Nothing ran on `:0` or on the user's real X server.**
  - D7 is emulated.
  - The halo's X-server cost may differ on the user's Windows X server.
- **No new suites.** Fences for the band, the context rule and `sel_area_fast` are stage C's job.
  Today the scratch repros above guard them: `bandae`, `band3`, `ctx_mix`.
- **Labels.** I did not touch how labels or texts look. `selection_text_style` behaves as A2 left
  it. Every change is in damage, repair order or cost.

## Decisions that are the USER's (described, not taken)

- **Halo cost when zoomed far out.** Select all at width 8200 is 4.3x classic in halo, and almost
  all of it is the X server drawing the halo's wide strokes. One option would cut this: draw a
  thinner halo, or none, below some zoom level. That changes how a selection looks, so it is the
  user's call. I did not build it.
