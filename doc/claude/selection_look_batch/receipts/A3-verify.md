# Stage A3 verify: the N1, N2 and N3 fixes

Adversarial check of the uncommitted change on `fluid-editing` (base `e3c43487e`). The working-tree
diff md5 was `05fb051c1fb05cd10ee34c6f1fb2b3ae` when I started and when I finished.

## Verdict: SAFE WITH LIMITS

- **N1, N2 and N3 are fixed.** Every red repro is red on `~/gsv3` (A2) and 0 on `~/gsa3` (A3). My
  figures match the crew's exactly.
- **Classic is unchanged.** Classic on `~/gsa3` is byte-identical to `~/gsl0` on every snapshot I
  took but one, and that one is the title block's file time (each clone's checkout time).
- **One new finding, N4 (low).** `xschem load -window` into a modified tab, answered Cancel, leaves
  the styled selection wrong until the next repaint. Classic is right. A2 has the same bug. It is a
  scripting path only.
- **Limits, all declared by the crew or by A2:** a big drag can switch to the cheap look partway;
  select all is 2.6–5.7x classic in halo; a whole-view band's grow phase at width 8200 is 1.5–1.8x
  classic in halo.
- Valgrind is clean. `--nogui` and `--pipe` exit 0 in every style. No new compiler warnings.

## How I measured

- Builds: `~/gsl0` (base), `~/gsv3` (A2, the red bed), `~/gsa3` (A3), `~/gsa3w` (A3 plus the
  Windows emulation toggles in `xinit.c` and `SEL_REAL_XCLIP 0`), `~/gsa3n` (A3, non-cairo; `ldd`
  shows no cairo). The eight changed files in `~/gsa3` and `~/gsa3n` are identical to the main
  tree. No source file is newer than any binary.
- Private Xvfb + openbox on `:287`–`:292`, 1920x1080x24. `DISPLAY` unset first, `GUI_GATE=0`, a
  throwaway HOME per run, cwd inside the clone. A per-display `flock` so two runs never share a
  display.
- A checkpoint is: snapshot, `xschem redraw`, snapshot again, `magick compare -metric AE`. Mid-band,
  the difference must lie only on the band outline (`off=0`). After release it must be AE 0.
- Scratch: `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/V3/`
  (below, `V3/`). Scripts in `V3/scr`, logs in `V3/log`, images in `V3/img`, snapshots in `V3/out`.

## Findings

### N4 (low): `load -window` Cancel leaves the selection wrong

**Repro** (`V3/scr/ctx_cancel.tcl`, and `ctx_cancel2.tcl` with the real `ask_save` dialog and its
Cancel button pressed). Tabbed interface, two tabs. Tab `.x1.drw` is modified.

- C1: in the main tab, `xschem select instance M1; xschem select text <n>`, then at once
  `xschem load -window .x1.drw <file>`. Answer Cancel.
- C2: select in `.x1.drw`, switch to main, deselect M1 in main, `load -window .x1.drw`, Cancel.

**Result** (AE after Cancel against a full redraw):

| build | C1 | C2 |
|---|---|---|
| A3 halo `colour` | 8683 | 14658 |
| A3 bright `own` | 6528 | 10026 |
| A2 (`~/gsv3`) halo | 8683 | 14658 |
| A3 classic | 0 | 0 |
| `~/gsl0` classic | 0 | 0 |

The real dialog gives the same figures. It opened at `+900+505`, off the canvas, so there was no
Expose.

- C1: the new selection is not drawn at all. Image: `V3/img/cc_halo_c1_cancel_vs_redraw.png` (left:
  after Cancel; right: after a redraw).
- C2: M1 still looks selected after it was deselected. A patch of the other tab (flop.sch's
  selected "MISSING SYMBOL" box) is pasted onto the main tab. Image:
  `V3/img/cc_halo_c2_cancel_vs_redraw.png`.

**Cause.** The `-window` branch calls `new_schematic("switch", target, "", 0)`. `switch_tab` with
`dr=0` does not draw, but it still calls `note_drw_front()`. While the modal dialog runs the event
loop, `sel_idle_cb` sees the target as the front tab. The main tab's damage is dropped as hidden
(`sel_ctx_on_screen`), and the target's damage is painted into the shared canvas, which still shows
the main tab. Cancel switches back with `dr=0` again, so nothing repaints.

**Reach.** Only `xschem load -window`. No menu or binding calls it (the Library Manager's
`load_new_window -window` is a different path: it opens a new top-level). A user can reach it by typing
the select and the load on one CIW line. Any later redraw, zoom or Expose clears it.

**One possible fix.** Repair the outgoing context's damage synchronously in `switch_tab`, before
`xctx` changes, while it is still the front tab. That covers C1 and C2. I did not build it.

### Not defects

- **A big drag switches to the cheap look partway** (`V3/scr/bigdrag.tcl`, 1600 FETs). Mid-drag,
  back at the anchor, against the static look: halo 2300 = 182725, halo 3500 = 225338, bright 2300 =
  0, bright 3500 = 91313. Classic (`~/gsl0` and A3) = 0. Abort, copy-Escape and place are 0 in every
  style. Halo step times were 21.5, then 7.2, 7.5, 6.1, 5.9 ms, so the probe took the cheap look. The
  probe code is the same in A2 and A3. A2-verify saw styled at 2300 on a quieter machine. This is
  A2's decision 6. Image: `V3/img/bd_halo2300_sel_vs_back.png`.
- **The band's start corner pixel is never painted**, in any style, classic included. It shows what
  is under it, which differs by style. That is 1 px per checkpoint (`K2_cp0`, `J`).
- **With hover on, a band's final state differs from a redraw in every style.** The hover outline
  is drawn at the pointer and a redraw drops it. Halo 130–561 px, `~/gsl0` classic 137–1643 px.
  Image: `V3/img/bfin_ab.png`.
- **A Shift press on a selected object starts a copy-drag, not a band** (`K1`). Same in classic.
- **Scripted `xschem undo` leaves the window unrepainted** (`ctx_misc` m2/m5/m6). Halo
  4846/14449/16030, bright `own` 4846/11310/12746, A3 classic and `~/gsl0` 4846/13207/13207. This is
  upstream, as A2-verify recorded. The GUI keys `u` and `U` give 0 in every style (`vconn` Q5, Q6).

## The crew's claims, re-measured

### N1 (`ctx_detach`, `ctx_mix`)

| repro | crew red / green | mine `~/gsv3` / `~/gsa3` / `~/gsl0` |
|---|---|---|
| `ctx_detach` D1/D2/D3, halo | 6633/6173/6173 → 0 | 6633/6173/6173 / 0 / 0 |
| same, bright | 2854/4234/4234 → 0 | 2854/4234/4234 / 0 / 0 |
| same, halo `own` | 6932/6303/6303 → 0 | 6932/6303/6303 / 0 / 0 |
| same, bright `own` | — | 3153/4366/4366 / 0 / 0 |
| `ctx_mix` A/C, halo | 5270/4016 → 0 | 5270/4016 / 0 / 0 |
| same, bright | 2238/1329 → 0 | 2238/1329 / 0 / 0 |
| same, halo `own` | — | 5539/4463 / 0 / 0 |
| same, bright `own` | — | 2507/1811 / 0 / 0 |

D4 and `ctx_mix` B/D are 0 everywhere. The select is live: before against after in D1 is 6633.

**My attacks on `sel_ctx_on_screen`** (`V3/scr/ctx_v3.tcl`, H1–H7):
- H1: damage in a hidden tab, the tab shown again.
- H2: deselect pending, switch away and back before idle.
- H3: damage pending in two contexts at once.
- H4: `load -window` into an unmodified tab (the `dr=0` path).
- H5: a real window destroyed with damage pending, a new window reusing the slot before idle.
- H6, H7: destroys with the main tab's damage pending.

All 0 on A3 (halo and bright, `colour` and `own`), `~/gsa3w`, `~/gsa3n`, classic and `~/gsl0`.
They are also 0 on A2, so they show the new rule broke nothing; they do not detect N1 itself.
`ctx_tab` (tab closed with damage pending) and `ctx_win`: 0. N4 is the one hole I found.

### N2 (band over a large selection)

Pixels: every band checkpoint, mid-band, differs from a redraw only on the band outline. Every
final state is AE 0 (except with hover on; see above). Coverage (`V3/scr/vband.tcl`,
`vband_k.tcl`):
- A: Shift band leftwards, grow, shrink, grow, over a selected text, M1, a wire, a filled rect and
  M1's scope outline;
- B: Alt band (deselect); C: plain band from a selection; D: Ctrl band;
- E1: Alt band started on the selected M1; E2: press on a selected filled rect, drag, Escape;
- F: Escape mid-band; G: wheel zoom mid-band; H: pan by key mid-band;
- I, J: whole-view bands over everything selected (the `sel_area_fast` path);
- K1–K5: bands whose edges run through selected texts.

Configurations: halo and bright, `colour` and `own`, dark and light, on `~/gsa3`, `~/gsa3w` and
`~/gsa3n`. Also with crosshair, full-span crosshair, halo width 12 and snap cursor, and with no
redraw between checkpoints (results identical). In all of them the styled checkpoints have
`off=0`: 26 per `vband` run, up to 17 per `vband_k` run.

The band itself: its outline pixels are identical to classic's at the same rectangle in every
checkpoint, except the start corner pixel above.

**Timing.** ms per motion, two runs each, widths 2300 / 3500 / 8200. The machine was shared with
another session's load.

`perfb2.tcl` (1600 FETs + 1600 wires, all selected, 20 motions):

| | crew | mine |
|---|---|---|
| `~/gsl0` classic | 9.75 / 54.76 / 14.59 | 10.06,10.04 / 56.04,60.99 / 13.19,16.11 |
| A2 halo | 16.06 / 105.15 / 42.54 | 14.86,11.44 / 101.54,198.01 / 40.43,74.65 |
| A3 halo | 13.33 / 2.52 / 0.91 | 14.42,8.60 / 2.46,3.14 / 0.82,1.21 |
| A3 bright | 13.85 / 2.45 / 0.98 | 12.47,12.58 / 2.20,4.84 / 0.96,1.84 |
| A3 classic | 11.02 / 60.25 / 15.52 | 14.92,10.12 / 84.20,57.64 / 21.01,15.03 |

At 2300 the press lands on a selected object, so it is a copy-drag, not a band (the crew says so).

`bandbig.tcl`, plain band from the corner over the whole view (`V_FRAC=1.0`; I select 120 / 288
/ 1440, the crew 110 / 255 / 1400):

| | crew grow | mine grow | crew jitter | mine jitter |
|---|---|---|---|---|
| `~/gsl0` classic | 3.45 / 6.62 / 2.07 | 4.04,4.15 / 7.32,7.83 / 2.56,2.29 | 9.93 / 21.25 / 6.58 | 11.23,11.94 / 24.64,24.39 / 7.26,7.27 |
| A3 halo | 1.29 / 2.75 / 3.57 | 1.33,1.33 / 2.99,3.04 / 3.93,4.23 | 0.72 / 2.01 / 2.66 | 2.25,2.38 / 5.79,5.91 / 1.89,2.08 |
| A3 bright | 1.39 / 2.68 / 1.53 | 1.35,1.24 / 2.94,3.14 / 1.52,1.40 | 0.73 / 1.72 / 1.42 | 2.23,2.32 / 5.33,5.16 / 1.04,0.98 |

The crew's declared limit holds: halo grow at 8200 is 1.5–1.8x classic. My halo jitter is higher
than the crew's at 2300 and 3500 but still 4–5x faster than classic. A half-view run (`V_FRAC`
0.5) is in `V3/out/bandbig_*`.

My own band (`V3/scr/vperf.tcl`, from an empty spot over an all-selected 1600 FET sheet, grow
mean):

| | Shift band | Alt band |
|---|---|---|
| `~/gsl0` classic | 13.96,17.18 / 29.12,31.37 / 7.53,8.90 | 10.35,11.73 / 20.24,23.77 / 21.87,27.24 |
| A3 halo | 2.68,2.43 / 5.55,5.02 / 1.42,1.33 | 2.50,2.25 / 3.61,3.38 / 3.03,3.17 |
| A3 bright | 2.52,2.09 / 5.12,4.24 / 0.96,0.89 | 2.31,1.85 / 3.39,2.81 / 3.02,2.60 |
| A2 halo | 31.6,74.7 / 55.2,115.6 / 23.1,44.7 | — |

**Select all + update** (`vperf`, median):

| | crew | mine |
|---|---|---|
| `~/gsl0` classic | 5.07 / 9.73 / 2.59 | 4.85,5.76 / 9.76,10.31 / 2.23,2.60 |
| A3 halo | 14.41 / 25.92 / 11.04 | 14.89,14.72 / 32.33,27.39 / 12.73,11.68 |
| A3 bright | 12.75 / 24.02 / 5.27 | 15.03,12.81 / 27.67,24.62 / 4.21,3.40 |

Halo is 2.6–3.1x, 2.7–3.3x and 4.5–5.7x classic. The crew said 2.7x, 2.7x, 4.3x. Declared.

**Hover and crosshair** (`perfv.tcl`, 1600 selected, ms):

| | crew classic / halo / bright | mine classic / halo / bright |
|---|---|---|
| hover change | 6.84 / 1.19 / 0.97 | 7.70,6.88 / 1.02,1.10 / 1.00,0.93 |
| crosshair | 10.72 / 0.86 / 0.79 | 12.35,10.82 / 0.85,0.83 / 0.81,0.76 |
| full-span crosshair | 10.74 / 4.62 / 4.44 | 11.85,10.72 / 4.62,4.62 / 4.49,4.31 |
| band motion | 12.31 / 0.66 / 0.52 | 12.59,12.67 / 0.42,0.53 / 0.51,0.43 |
| unselect all | 6.67 / 0.73 / 0.49 | 6.76,7.06 / 0.52,0.73 / 0.55,0.56 |

**Classic timing.** Four alternating `~/gsl0` / A3-classic runs (`V3/scr/abcls.sh`): no consistent
difference. Means over four runs, A3 against base: select all at 2300 6.62 vs 7.00; Shift band at
2300 19.84 vs 20.30, at 3500 39.26 vs 38.11; Alt band at 8200 31.65 vs 31.24.

### N3 (band cut by a selected text)

Band-edge grey pixels on the text's row (`band.tcl`, and `band3.tcl` with an Expose while the band
is up):

| build | `band` | `band3` |
|---|---|---|
| A3 halo `colour`, bright `own` | 829 | 829 |
| A3 classic, `~/gsl0` classic | 829 | 751 |

The crew's 829/829 holds. Classic losing 78 px on Expose is upstream; A3 classic matches base.

### `actions.c` and `select.c`

- `select_rect`: the styled branches use `sel_band_damage`, `sel_overlay_flush`, `band_shown` and
  `sel_band_paint`. The classic branches are the original code, verbatim.
- `select_object`'s deselect branch repairs instead of calling `draw_selection`, only when styled.
- `sel_area_fast` returns 1 in classic, so classic is untouched.
- The declared limit ("an object selected with fast bit 2 is not repainted by a band"): I tested
  every caller I could reach (`V3/scr/vconn.tcl`). Scripted `connected_nets`, Ctrl+Button3 and
  Shift+Button3 on M1, a Shift band over those nets, GUI undo `u` and redo `U`. All 0 in halo,
  bright `own` and classic. Classic A3 matches `~/gsl0` on all 12 snapshots.

### Regressions (D1–D7, L1, A2's scenarios)

- D1–D5, L1 on `~/gsa3` halo and bright: `colour`, `own`, light, light `own`, `~/gsa3w`,
  `~/gsa3w own`, `~/gsa3n`. All 0, except D1's wire 184, which is upstream (classic gives 184).
  D3: 30/30 white pixels kept (dark; in light, white is the background). Classic gives D4 497, D5 desel 173, L1 f3 41 on A3 and on `~/gsl0`
  alike.
- D7 (`winemu`) on `~/gsa3w`: 0 in all 8 combinations (halo/bright, `colour`/`own`,
  `fix_broken_tiled_fill` 0/1).
- A2-verify's scripts on A3, halo `colour` and bright `own`: `drag2` 0, `hil` 0, `hil2` 0, `sw` 0,
  `ctx_tab` 0, `ctx_win` 0, `print` 0, `bandae` 0, `det_ev` 0, `det_net` 0. `ovl` o7–o9 are 15–16
  (the snap diamond a redraw drops; classic 16–19).

### Classic byte-identity (A3 classic against `~/gsl0`)

Snapshot pairs, AE 0 unless noted:
- `vband`: 88 dark, 88 light, 88 with hover, 88 with crosshair/snap/halo width 12;
- `vband_k`: 26 + 44; `ctx_v3`: 20; `ctx_cancel`: 5; `vconn`: 12; `bigdrag`: 8 + 8;
- A2's scripts: `drag2` 19, `ovl` 20, `hil` 5, `hil2` 5, `sw` 11, `ctx_tab` 8, `ctx_win` 8,
  `ctx_misc` 30, `bandae` 10, `det_ev` 3, `det_net` 3, `pin1` 3, `band` 1, `band3` 1;
- `print`: 14 of 15. `p_png_full` differs by 205 px, all in a 40x8 box: the title block shows
  04:12:41 on `~/gsa3` and 00:05:54 on `~/gsl0`, each clone's checkout time. The crew found the
  same. Image: `V3/img/print_full_a3_vs_l0.png`.

### Health

- **Valgrind** (`-q --error-exitcode=99`, `~/gsa3`): `ctx_v3` halo and bright `own`, `ctx_mix`
  halo, `ctx_detach` bright `own`, `vband` halo `own` and bright with crosshair and hover,
  `bandae` halo. Every log is empty and every run printed its final mark.
- **Headless**: `nogui2.tcl` and `nogui3.tcl`, `--nogui` and `--pipe`, classic/bright/halo,
  `colour`/`own`, under valgrind, on `~/gsa3` and `~/gsa3n`. 48 runs: all exit 0, empty logs, no
  `FATAL`.
- **Warnings**: base and A3 compiled four ways. Line counts with line numbers stripped, base / A3:
  cairo default 6/6, cairo `-std=c89 -pedantic` 67/67, cairo `-Wall -Wextra` 377/377; non-cairo
  6/6, 67/67, 391/391. Identical.
- **Suites** (`run_suites.sh`, `AUDIT_DISPLAY` explicit, `GUI_GATE=0`): `test_select_at` 5 FAILED
  and `test_cadence_drag` 2 FAILED on both `~/gsa3` and `~/gsl0`, line for line. This confirms the
  crew's "fails the same way on base" for those two.

## What I did not cover

- Nothing on `:0` or the user's Windows X server. The halo's X-server cost may differ there.
- I did not re-run the crew's sabotages S1 and S3, or their full suite lists (31 + 34 + 10). I ran
  only the two suites they reported failing.
- A non-current context flushed at idle uses the current context's per-context Tcl variables (for
  example `lvs_ignore`). Highlight sync does the same, so this is older than A3. Not tested.
- A full-window repair (`sel_pend_full`) wipes other window-only overlays (wire rubber band, zoom
  box) everywhere, not only in the damage, until the next motion. Transient. Not tested.
- Tab reordering (`swap_tabs`, which switches with `dr=0`) with damage pending. Not tested; it may
  share N4's cause.
- Windowed (non-tabbed) `load -window` Cancel. Not tested.
- Timings were taken on a loaded machine; read them as ratios, not absolutes.

## Housekeeping

- My Xvfb and openbox processes (`:287`–`:292`) are stopped, killed by pid after checking each
  one's command line and `DISPLAY`. No lock or socket is left.
- My runs left `*~.sch` backups in `~/gsl0`, `~/gsv3`, `~/gsa3`, `~/gsa3w` and `~/gsa3n` (all
  created after I recorded those clones as having none). I removed them. Each clone's
  `git status` is as before.
- The main tree's three existing backups have the same md5 as before. I edited only this file.
