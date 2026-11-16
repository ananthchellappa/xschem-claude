# Stage A4 verify: N4, and the restamp of a shape being placed

Adversarial check of the uncommitted change on `fluid-editing` (base `e3c43487e`). The working-tree
diff md5 was `c080b0e08c24dec37e21e75fa82dc127` when I started and when I finished. `~/gsa4` holds
the same diff (same md5, every changed file `cmp`-equal).

## Verdict: SAFE WITH LIMITS

- **N4 is fixed.** Every red figure the crew gives for A3 I got exactly, and A4 is 0 in every
  style I ran.
- **The rubber wipe is fixed.** A3 wipes a shape being placed on a repair. A4 puts it back: 0/0 in
  every cell I ran, in six configurations on three trees.
- **Classic is unchanged.** Classic on `~/gsa4` is byte-identical to `~/gsl0` on all 480 snapshots
  I compared.
- **Two new findings, both small.**
  - **N5 (low), a regression against A3.** After a switch to a tab that does not draw (`dr` 0), a
    full Expose paints that tab over the canvas, but A4 still thinks the canvas holds the old tab.
    A selection change in the new tab is then not drawn until the next full redraw.
  - **D1 (cosmetic), new in A4.** A restamp of a shape that has no length yet paints a 3-pixel dot
    the tool itself never drew.
- **K6 is base and the motion residual pre-dates A4.** Both confirmed.
- **Health is clean.** Valgrind clean. `--nogui` and `--pipe` exit 0 in every style. Warnings
  equal base. Suite verdicts equal base, line for line.

## How I measured

- **Builds.** `~/gsl0` is base. `~/gsa3` is A3, the red bed. `~/gsa4` is A4. `~/gsa4w` is A4 plus
  the Windows emulation toggles. `~/gsa4n` is A4, non-cairo. All are the crew's clones. I did not
  edit them.
- **Displays.** My own Xvfb with openbox on `:292`–`:295`, 1920x1080x24. `DISPLAY` was unset in
  every calling shell. Every run had `GUI_GATE=0`, `AUDIT_DISPLAY` set to its own display, a
  throwaway `HOME`, and its cwd in a clone. A per-display `flock` kept two runs off one display.
  I never used `:99`, `:0` or the user's screen. I did not run T1.
- **Pixels.** `magick compare -metric AE`. A checkpoint is a snapshot, then `xschem redraw`, then a
  second snapshot. For shapes being placed I used the crew's OUT/IN metric, rebuilt by me in
  `V4/scr/oi.sh`, not their script.
- **Scratch.** `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/V4/`
  (below, `V4/`). Poses in `V4/scr`, logs in `V4/log`, snapshots in `V4/out`, images in `V4/img`.
  It is scratch, not durable.

## Findings

### N5 (low): a full Expose after a `dr` 0 switch hides the new tab's selection

**Repro** (`V4/scr/v4_canvas.tcl`, rows G1 and G1b):
1. Tabbed interface. Tab `t1` holds `flop.sch`. The main tab is on the canvas.
2. `xschem new_schematic switch $t1 $f2 0`. `t1` is current. The canvas still shows the main tab.
3. A full Expose of `.drw`. G1 sends `xschem callback .drw 12 0 0 0 W H 0`. G1b does a real
   `wm iconify .` and `wm deiconify .`. Either way the canvas now shows `t1`'s drawing.
4. `xschem select instance x5` in `t1`. Wait for idle.

**Result.** The selection of `x5` never reaches the screen. The snapshot after the select equals
the snapshot before it (AE 0 on A4).

| build | G1 | G1b |
|---|---|---|
| A4 `~/gsa4` halo `colour` | **5270** | **5270** |
| A4 `~/gsa4` bright `own` | **2507** | **2507** |
| A4 `~/gsa4w` halo | **5270** | **5270** |
| A4 `~/gsa4n` halo | **4162** | **4162** |
| A3 `~/gsa3` halo | 0 | 0 |
| A4 classic, `~/gsl0` classic | 0 | 0 |

Figures are AE against a full redraw. On A3 the select changes 5270 pixels and is drawn. Valgrind
on the same pose gives the same figures and an empty log.

**Cause.** `handle_expose()` copies the current tab's pixmap to the window. It does not call
`sel_note_canvas()`. So `sel_canvas_win` still names the main tab. `sel_idle_cb()` then finds `t1`
"not on screen" and drops its damage. It stays wrong until something calls `draw()`.

**Reach.** It needs a `dr` 0 switch, then a full Expose, then a selection change in the new tab
before anything draws.
- From a script: `xschem new_schematic switch <tab> <file> 0`, or `create` with `dr` 0.
- From the GUI: the tab right-click menu (`Netlist`, `Save`, `Close` on another tab) does `dr` 0
  switches in `src/xschem.tcl`. `Netlist` with no netlist opens `alert_`, which runs the event loop
  and does not grab. I read this in the code. I did not build a GUI repro. In that state the
  canvas is already wrong on base (it shows one tab while another is current), so N5 adds to a
  base defect rather than breaking a correct screen.

**Proposed fix (not built).** In the styled branch of `handle_expose`, when the Expose covers the
whole window under the tabbed interface, call `sel_note_canvas()` after the copy. Or make
`handle_expose` and `sel_idle_cb` use the same rule.

**Image:** `V4/img/N5_g1_a3_a4_redraw_halo.png` (left A3, middle A4, right a full redraw).

### D1 (cosmetic): a restamp of a zero-length shape paints a dot

**Repro** (`V4/scr/v4_degen.tcl`). With the infix interface, start a tool at the pointer
(`xschem rect gui`, `line gui`, `wire gui`, `polygon gui`, `zoom_box` and a press, or the arc's
first point). Do not move. Then trigger a repair: a big Expose (e2), `select_all` (s1), or a select
(m1).

**Result.** A 3-pixel dot (a 2x2 box at the start point, in the layer colour) appears. The tool
never drew it. Escape removes it.

| build | rect, line, wire, poly, zoom, arc (first stage): e2 / s1 / m1 |
|---|---|
| A4 halo `colour` | 3 / 3 / 3 each |
| A4 bright `own` | 3 / 3 / 3 each |
| A3 halo, A4 classic, `~/gsl0` classic | 0 |

The arc's second stage with no radius yet (`nl_r` -1) is 0. A persistent wire is 0 in halo and 3 on
s1 in bright. With no trigger (n0) it is 0 everywhere.

**It can outlive the tool** (`V4/scr/v4_degen2.tcl`). If the second click lands on the first point
with no motion, the tool ends with nothing stored and the dot stays until the next redraw: rect,
line, wire and zoom 3 px each, on e2 and s1, in halo, bright and `~/gsa4n` halo. `~/gsl0`
classic is 0. `ui_state`
reads 0 (or `SELECTION` after s1), so no tool is active.

**Cause.** `sel_rubbers_restamp()` stamps from `nl_*` even when both ends are the same point. With
`CapRound`, X draws a zero-length line as a dot.

**Fix idea (not built).** Skip the stamp when the shape is degenerate: `nl_x1 == nl_x2 &&
nl_y1 == nl_y2`; for the arc in state 0, `nl_xx1 == nl_xx2 && nl_yy1 == nl_yy2`; for the polygon,
the rubber point equal to the last stored point.

**Images (8x):** `V4/img/D1_degenerate_dot_rect_s1_halo_8x.png`,
`V4/img/D1_dot_left_after_tool_ends_rect_wire_halo_8x.png` (green rect dot, cyan wire dot).

## The crew's claims, re-measured

| claim | crew | mine |
|---|---|---|
| N4 C1 / C2, A3 halo `colour` | 8683 / 14658 | 8683 / 14658 |
| N4 C1 / C2, A3 bright `own` (`ctx_cancel2`) | 6528 / 10026 | 6528 / 10026 |
| N4 C1 / C2, A4 | 0 / 0 | 0 / 0 (halo `colour`, bright `own`, classic; `~/gsl0` classic) |
| "before" vs C1 (the select really changed) | 8683 / 6528 / 4824 | 8683 / 6528 / 4824 |
| K1 / K2, A3 halo | 8683 / 6173 | 8683 / 6173 |
| K1–K5, A4 | 0 | 0 (halo `colour`, bright `own`) |
| K6 pre/post, `~/gsl0` and A4 classic / A4 halo | 62028 / 63651 | 62028 / 63651; bright `own` 60906 |
| K6b | "inherits it in every build" | halo 56749, classic 62222 |
| Rubber IN, A3 halo, e2 and s1 | wire 1313, line 1317, rect 2627, poly 944, zoom 2611, arc 947, arc2 2362 | the same, every cell |
| Rubber IN, A3 halo, m1 and d1 | rect 404, poly 385, zoom 404, arc 389, arc2 416 | the same; wire 0 |
| Rubber OUT/IN, A4 | 0/0 every cell | 0/0 every cell: halo `colour`, bright `own`, bright light, halo `own` light, `~/gsa4w` halo, `~/gsa4n` bright `own` |
| Crosshair on: full redraw off after Expose | e1 23, e2 12 | e1 23, e2 12 (arc2 17 and 6); IN 0 |
| Classic rubber | e2 wipes it, small cuts on s1/d1 | the same; A4 classic equals `~/gsl0` 126/126 |
| Motion residual, halo | 11–27 px, zoom 146 | s1: 17–27, arc2 36, zoom 149; m1: 11–30, zoom 23 |
| Motion residual pre-dates A4 | identical on A3 | all 42 reference snapshots identical A3 vs A4 |
| Windowed `load -window`, WC/WO | 0 | 0 on `~/gsa4` halo, bright `own` light, `~/gsa4w` halo |
| Scenario scripts identical to A3 | 426 snapshots | 238/238 halo `colour` dark, 238/238 bright `own` light (14 scripts each) |
| Nonzero scenario scores on A4 | `ovl` o7–o9, `ctx_misc` m2/m5/m6 | the same: o7–o9 15–16; m2/m5/m6 4846/14449/16030 |

My motion residual range is a little wider than the crew's (arc2 36, zoom 149). It is the same on
A3, so it does not change their conclusion.

## Other attacks, all clean

- **`sel_canvas_win` stale.** Iconified window with a `dr` 1 switch (G2, G2b), an iconified `dr` 0
  round trip (G3), detach of the active tab (G5b): 0 on A3, A4 and classic.
- **Tab destroyed, path reused** (`V4/scr/v4_reuse.tcl`). `.x1.drw` and `.x2.drw` were both
  reused. Destroy while current, destroy from main, `create` with `dr` 0, destroy then create
  before idle, real Expose after: rows R1–R5b all 0 on A3 halo, A4 halo, A4 bright `own`, A4
  classic and `~/gsl0`. Classic identity 16/16. This pose was not run under valgrind.
- **Tab switch while placing a shape** (`V4/scr/v4_tabmid.tcl`; rect, wire, polygon, zoom box).
  A tab click to `t1`, a select there, a big Expose there, pending damage in main at the switch,
  and Escape after the return: all 0. A4 never painted main's shape into `t1`, and left nothing
  after Escape. On the return, `draw()` wipes the shape in every build. A select then puts it back
  on A4 (0 of 2627 path pixels differ for rect; wire 16 of 1329). A3 and classic leave it wiped
  until the next motion. That is better, not worse. Classic identity 44/44.
- **XOR.** Every rubber GC is `GXcopy`, so a second stamp is a no-op. No double draw showed in any
  row.
- **Wrong window.** The rubber state (`nl_*`, `ui_state`) lives in each context. The tab rows above
  found no cross-paint.
- **No tool active.** After Escape, after the tool ends, after a tab switch: no stamp, except the
  D1 dot.
- **`no_draw`.** `draw()` returns before `sel_note_canvas()` when `no_draw` is set, so nothing is
  noted that never reached the window. Read in the code, not measured.

## Classic byte-identity, `~/gsa4` vs `~/gsl0`

All AE 0: `ctx_cancel` 5/5, `ctx_a4` 20/20, `v4_canvas` 15/15, rubber pose 126/126, rubber pose
with crosshair, hover and snap cursor 126/126, `v4_degen` 128/128, `v4_reuse` 16/16, `v4_tabmid`
44/44. Total 480 snapshots, none different. I did not compare a full-page PNG export.

## Health

- **Valgrind, display arm** (`~/gsa4` halo): `v4_canvas`, `ctx_a4`, the rubber pose (rect, poly,
  arc2, wire), `v4_degen2`, `ctx_tab`. Every log empty. Every run reached `V-DONE`.
- **Valgrind, `--nogui` and `--pipe`**: `nogui2`, `nogui3` and `nogui4` (headless tabs, Expose,
  tools, `load -window`) on `~/gsa4`, plus `nogui4` on `~/gsa4n`. Classic, bright and halo,
  `colour` and `own`. 48 runs: all exit 0, end mark written, valgrind log empty, no `FATAL`.
- **Warnings.** All 38 `OBJ` files, base against A4. Cairo default 6 / 6 lines, cairo
  `-std=c89 -pedantic` 67 / 67, non-cairo default 6 / 6, non-cairo `-std=c89 -pedantic` 67 / 67.
  The lines are identical once line numbers are stripped. Non-cairo base is `~/gsl0`'s sources with
  `~/gsa4n`'s `config.h` (in `V4/bn`).
- **Suites** (`run_suites.sh`, `GUI_GATE=0`, explicit `AUDIT_DISPLAY`): A4 on `:295`, base on `:292`.
  Display arm: 28/30 passed, 1 skipped, on both. Counted arm: 19/24 passed, 10 skipped, on both.
  The verdict files are byte-identical. The reds are base's own: `test_select_at` 5 FAILED and
  `test_cadence_drag` 2 FAILED on the display arm; five `NORESULT` on the counted arm.

## What I did not cover

- No real hand input and no real screen. Every gesture is a synthesized event on Xvfb.
- No GUI repro of N5 through the tab right-click menu. Its reach there is read from the code.
- The Windows build was not compiled. Only the emulation (`~/gsa4w`).
- There is no non-cairo base binary. Non-cairo base was compiled for warnings only.
- I did not re-run the crew's sabotages.
- Not every scenario list in every style, tree and scheme. The style/tree mixes are the ones named
  in each row.
- Hidden-tab draws that borrow a context (`net_hilight_redraw_other_windows`) were not exercised.
- Destroying a tab whose previous context is a real window was not tested.
- No timing.

## Housekeeping

- My Xvfb and openbox on `:292`–`:295` are stopped. I killed them by pid after checking each
  command line and `DISPLAY`. No lock file or socket is left.
- My runs left `*~.sch` backups in the clones: 3 in `~/gsl0`, 2 in `~/gsa3`, 4 in `~/gsa4`, 3 in
  `~/gsa4w`, 2 in `~/gsa4n`. Each was newer than my start mark, and no older ones existed. I removed
  them.
- The main tree's backups (59 files) have the same md5s as at my start.
- `~/gsl0` is clean. `~/gsa3`, `~/gsa4`, `~/gsa4w` and `~/gsa4n` show only their eight changed
  files. `~/gsa4n` also has an untracked `plot.xpm` dated before my start; it is not mine and I left
  it.
- Scratch under `V4/` is about 168 MB in `/tmp`, which is RAM here. Delete it once this is on the
  ledger.
- I wrote only this file in the main tree.
