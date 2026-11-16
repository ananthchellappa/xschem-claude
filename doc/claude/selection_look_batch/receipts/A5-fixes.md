# Stage A5 receipt: N5 and D1

Crew: stage-A5 fix crew, 2026-11-15. Base: `e3c43487e` (pristine build `~/gsl0`). Red bed:
`~/gsa4` (the A4 tree, not edited). All edits are in the main tree and are **uncommitted**, on top
of A2's, A3's and A4's uncommitted change. The A5 part alone (against `~/gsa4/src`) touches
`src/move.c`, `src/draw.c`, `src/callback.c`, `src/actions.c` and `src/xschem.h`. `select.c`,
`xinit.c` and `xschem.tcl` are as A4 left them. Nothing changes how anything looks: no colour,
width or `selection_text_style` was touched.

## How it was measured

- **Displays.** My own Xvfb `:272`–`:279` (1920x1080x24), each with openbox (checked with
  `_NET_SUPPORTING_WM_CHECK`). `DISPLAY` was unset in every calling shell. Every run had
  `GUI_GATE=0`, a throwaway `HOME` and its cwd in a clone. One lock file per display, so no two
  runs shared a screen. I never used `:99`, `:0` or the user's screen, and never ran T1.
- **Trees.** `~/gsa5` holds this tree's `src`: every tracked `src` file is byte-identical to the
  main tree. `~/gsa5w` is the Windows emulation (`SEL_REAL_XCLIP 0` plus the two `#if 0` in
  `xinit.c`, as A3 and A4 did); it differs from the main tree in `xinit.c` and `xschem.h` only.
  `~/gsa5n` is non-cairo. `~/gsa5s` was a throwaway copy for the sabotages. All are built.
- **Pixels.** `magick compare -metric AE` against a full `xschem redraw` of the same state, unless
  a row says otherwise. "colour" and "own" are `selection_text_style`.
- **Scratch.** `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A5/`
  (below, `A5/`). New poses in `A5/scr/`, snapshots in `A5/out/`, images in `A5/img/`. The re-run
  of every earlier repro is in `A5/r/` (A4's own `A4/r/` and `A4/scr/` scripts, pointed at
  `~/gsa5*`). Scratch, not durable.

## N5: a tab's drawing reaches the canvas by an Expose, and the overlay does not know

**Cause.** The verifier's reading is right, and it is wider than one Expose. `sel_canvas_win`
(the tab whose drawing the shared `.drw` canvas holds) moved only on a full `draw()`. But
`handle_expose()` repaints the exposed rect from the **current** tab's pixmap, in classic and in
every style. After a switch that does not draw (`switch_tab()` with `dr` 0), an Expose paints the
new tab onto the canvas while `sel_canvas_win` still names the old one. `sel_idle_cb()` then drops
the new tab's damage as "not on screen". A select there is never drawn.

**Why not "a full Expose notes the tab".** I measured what reaches `handle_expose()`:
- a real deiconify gave one full rect here, but one Expose event can come as several rects
  (row G1q, four quadrants), and a window can be exposed piece by piece (G1r: a hole uncovered
  later by a real toplevel going away);
- a partial Expose must not move the canvas tab (G1p);
- another tab can paint into the window between two rects of the same tab (G1h);
- a tab's pixmap keeps the size of the last resize it saw: after G6 resized the window while `t1`
  was current and back while main was, `t1`'s pixmap stayed 960x652 inside a 900x632 window, so
  "the pixmap is covered" never came true (TM1 stayed red until the window clip went in);
- a window partly off the screen is exposed only on the screen: a real deiconify at `+1500+0`
  exposed `0 0 419 632` of a 900-wide canvas (G1s).

**Fix.**
- `sel_note_expose()` (`move.c`), called by `handle_expose()` after it pastes, in **both** the
  styled and the classic branch. It paints nothing; the classic call is there so the tab is right
  when the style is switched later. A tab that is not `sel_canvas_win` collects its exposed rects.
  When they cover what the tab can paint, it calls `sel_note_canvas()`. "What the tab can paint" is
  its pixmap (`xrect[0]`) clipped to the window as it is now (`Tk_IdToWindow`, `Tk_Width`,
  `Tk_Height`) and to the screen (`Tk_GetRootCoords`, `WidthOfScreen`, `HeightOfScreen`).
- `sel_exp_covers()` tests the cover exactly: the rects' edges cut the target into cells, and it
  tests one point per cell.
- `sel_note_paste()` (`move.c`), called from `MyXCopyArea()` and `MyXCopyAreaDouble()` (`draw.c`)
  whenever a context pastes into its own window. A paste by another tab into the shared canvas
  drops the collected rects it meets. So a canvas left showing parts of two tabs keeps its old tab.
- `sel_note_canvas()` empties the list.
- Real windows (non-empty `top_path`) are skipped, as before.
- New ctx state: none. New statics in `move.c`: the rect list, its count and its owner.

**Red and green.** `A5/scr/a5_canvas.tcl` (copy of `flop.sch` as `t1`, main is the not gate).
Halo `colour`, dark, AE against a full redraw (`g1p` right of x=124, `g1s` left of x=400):

| row | what | `~/gsa4` | `~/gsa5` |
|---|---|---|---|
| G1 | `dr` 0 switch, one synthetic full Expose, select `x5` | **5270** | 0 |
| G1b | the same with a real iconify/deiconify | **5270** | 0 |
| G1q | four synthetic quadrant Exposes | **5270** | 0 |
| G1r | Exposes around a hole, then a real toplevel unmapped over the hole | **5270** | 0 |
| G1s | real deiconify, window partly off the screen | **3270** | 0 |
| G1p | partial Expose by `t1`, back to main with `dr` 0, select `M1` | 0 | 0 |
| G1h | two halves with main's repair painting in between | snapshot equal to A5 | equal |
| G6 | `dr` 0 switch, then a resize (Configure) | 0 | 0 |

The verifier's own pose (`v4_canvas`, G1/G1b) is 5270/5270 on `~/gsa4` and 0/0 on `~/gsa5`.

Every configuration (G1 = G1b = G1q = G1r; all 0 on `~/gsa5`):

| build | `~/gsa4` G1 | `~/gsa4` G1s | `~/gsa4` TM1 / TM4 |
|---|---|---|---|
| halo `colour` dark | 5270 | 3270 | 5270 / 5181 |
| halo `own` dark | 5539 | 3431 | 5539 / 5819 |
| bright `colour` dark | 2238 | 1508 | 2238 / 2103 |
| bright `own` dark | 2507 | 1668 | 2507 / 2741 |
| halo `colour` light | 5270 | 3270 | 5270 / 5182 |
| bright `own` light | 2508 | 1668 | 2508 / 2741 |
| `~/gsa4w` halo | 5270 | 3270 | 5270 / 5181 |
| `~/gsa4n` halo | 4162 | 2473 | 4162 / 4194 |

On `~/gsa5` the same rows are 0 in all of them, and in `~/gsa5w` bright `own` and `~/gsa5n` bright
`colour` too. Of the 29 snapshots of the pose, A5 and A4 differ in exactly the N5 rows (g1, g1b,
g1q, g1r, g1s, tm1, tm4); the other 22, references included, are pixel-identical.

**The tab right-click menu, with real Tk events.** I right-click `t1`'s tab (`<ButtonPress-3>` on
`.tabs.x1`, which runs `tab_context_menu`) and press the menu's buttons with Enter, ButtonPress-1 and
ButtonRelease-1 at real coordinates. The Close prompt is a `tk_messageBox` stub that runs my steps
and answers.
- **TM1**: `Edit netlist` with no netlist opens `alert_`, with `t1` current and the canvas on main.
  Inside it: a real iconify/deiconify, then `xschem select instance x5`. Compared with the G1
  reference. The alert is first moved off the canvas. `~/gsa4` **5270**, `~/gsa5` 0.
- **TM2**: the same, but the select is a real click on `x5`. 0 on both: a click goes through the
  motion repair, which draws at once, so A4 was already right here.
- **TM3**: `Save` from `t1`'s menu with a select pending in main; then a select in main. 0 / 0 on both.
- **TM4**: `Close` on a modified `t1`; inside the prompt a real deiconify and a select of `x1`,
  then Cancel. `~/gsa4` **5181**, `~/gsa5` 0. After Cancel, a select in main: 0 on both.
- **TM5**: `Close` answered OK. 0 on both.

**Other paths, fixed or shown safe.**
- **Configure/resize**: the resize handler runs `draw()`, which already notes the tab (G6, 0 on
  both).
- **Toggling tabbed mode**: `xinit.c` disables the `Tabbed interface` menu entry when a tab or
  window is created and enables it only at window count 0. So it can only toggle with the main
  context alone. Read in the code.
- **Anything that pastes a pixmap**: every `XCopyArea` in `src/` is inside `MyXCopyArea()` or
  `MyXCopyAreaDouble()`, and the Windows cairo copy is inside `MyXCopyArea()` after the new call.
  So every paste reaches `sel_note_paste()`.
- **Tab destroyed, path reused** (`v4_reuse`): all rows 0 in halo, bright `own` and classic.

**Declared limit: a window over part of the canvas.** A part of the canvas covered by another
window is not exposed until it is uncovered. Until then the cover is incomplete and the canvas
keeps its old tab. Row TM1b leaves `alert_` where it opens (over the canvas) and masks it: **5271
on `~/gsa4` and 5271 on `~/gsa5`**. So it is not a regression, and A5 does what A4 did there. The
safe side is chosen on purpose: noting the new tab before its drawing covers the canvas would let
its overlay paint over the part that still shows the old tab. The real deiconify there sent rects that leave out exactly the alert's area.

**A legitimate change in an earlier row: `ctx_a4` K6b.** K6 is a base bug A4 recorded and did not
fix: an Expose of `.drw` while a real window is current pastes the **main** tab's pixmap over the
canvas, in every build. K6b then has a select pending in `t1`. On A4 the repair painted `t1`'s
patch and halo onto main's drawing. On A5 the full Expose by main notes main as the canvas tab, so
`t1`'s damage is dropped and the canvas shows exactly main's drawing. A5's K6b snapshot now equals
its K6 snapshot (AE 0) in all ten styled configurations, as classic and `~/gsl0` always did. A4's
differed from it by 8485 (halo `colour`), 9184 (halo `own`), 4961 (bright `colour`), 5660 (bright
`own`), 6447 (`~/gsa4n` halo) and 2916 (`~/gsa4n` bright `colour`). So K6b's AE against the
`t1` reference rises (halo `colour` 56749 to 65234); that reference is not what the screen can
show while the base bug stands. Image: `A5/img/k6b_a4_a5_classic.png`.

**Images.** `A5/img/n5_g1_red_green_ref.png` (G1: A4, A5, full redraw),
`A5/img/n5_tm1_red_green_ref.png`, `A5/img/n5_tm4_red_green_ref.png`.

## D1: the restamp painted a dot the tool never drew

**Cause.** `sel_rubbers_restamp()` stamped every shape the tool held, from `nl_*`. From the start of
a shape to its first motion the tool shows nothing, but `nl_*` already holds the shape, both ends on
the start point. With `CapRound`, X draws that as a 3-pixel dot. The same happens after a click that
stores a segment and starts the next one at the same point (wire, line): `draw()` has wiped the
old stroke and the new segment has not been stroked.

**Fix.** A new per-context `rubber_shown` (`xschem.h`) holds the shape-placing `START*` bits whose
owner has stroked the shape it now holds. The owners in `actions.c` keep it:
- `new_wire()`, `new_line()`, `new_rect()`, `new_polygon()`, `new_arc()`, `zoom_rectangle()`:
  the RUBBER branch clears the bit when it erases and sets it when it strokes;
- the PLACE/START branch clears it for a new shape, and for a continued wire, line or rect when the
  click stored a segment (`modified`). A click that stored nothing keeps it: the stroke on screen
  is already that point;
- `new_arc()`'s SET clears it when the line goes and no arc is stroked yet; its second-stage stroke
  sets it only when it really strokes (`nl_r > 0`);
- a polygon's ADD keeps it: the window still shows the same polygon.
`sel_rubbers_restamp()` stamps `ui_state & rubber_shown` only. So the restamp draws exactly what the
tool shows at that moment. `draw()` does **not** clear the bits, on purpose: A4's "a select after a
tab return puts the shape back" (verifier's `v4_tabmid`) depends on it, and it is unchanged.

**Red and green.**

| pose | rows | `~/gsa4` | `~/gsa5` |
|---|---|---|---|
| `v4_degen` (start, no motion) | wire, line, rect, poly, zoom, arc; e2 / s1 / m1 | **3** each | 0 |
| `v4_degen2` (second click on the first point) | rect, line, wire, zoom; e2 / s1 | **3** each | 0 |
| `a5_degen3` pwire, pline (click stores a segment) | s1, bright | **3** | 0 |

`v4_degen` is 3 on A4 and 0 on A5 in halo `colour` dark and light, bright `own` dark, and the
emulation and non-cairo trees (halo); A5 is also 0 in halo `own` and bright `own` light. With no
trigger (n0) it is 0 everywhere. `v4_degen2` is 3 on A4 and 0 on A5 in halo, bright `own` and
non-cairo halo; A5 is also 0 in halo light and on `~/gsa5w`. The pwire/pline dot shows in bright
only; halo is 0 on both trees.

**What the restamp still draws, on purpose.** `A5/scr/a5_degen3.tcl` drives cases where the tool
itself shows a degenerate shape: start at P, move to Q, move back to P (rect, line, wire, poly,
zoom, arc), and a polygon point added with no motion after it. The tool's own picture (n0, no
trigger) differs from a full redraw by 3 px (19 for the wire, 247 for the polygon). After e2, s1 and
m1 the screen still equals that picture: the restamp reproduces the tool's own dot and nothing more.
A5 equals A4 on 72 of 72 snapshots in halo `colour` dark and light, `~/gsa5w` and `~/gsa5n`, and on
70 of 72 in bright `colour` and bright `own`; the two that differ are pwire s1 and pline s1, the D1
dot, 3 to 0.

**The restamp's job is kept.** The rubber pose (`rub2_a4`, OUT/IN against the path): 0/0 in every
cell on A5, halo `colour` and bright `own`; 126 of 126 snapshots identical to A4 in both. The
tab-switch-while-placing pose (`v4_tabmid`): 44 of 44 identical to A4 in halo and in bright `own`,
so A4's "a select puts the shape back" behaviour is unchanged.

**Images (8x).** `A5/img/d1_rect_e2_8x.png`, `d1_wire_e2_8x.png`, `d1_line_e2_8x.png`,
`d1_pwire_s1_8x.png` (each: A4, A5, full redraw).

## Sabotages (each on `~/gsa5s`, built, restored with `cp` and proved with `cmp`)

| id | sabotage | rows | result |
|---|---|---|---|
| S1 | drop the styled `sel_note_expose()` call in `handle_expose()` | a5_canvas | G1, G1b, G1q, G1r, TM1 **5270**; TM4 **5181**; G1s **3270** |
| S2 | `sel_note_paste()` does nothing | G1h | **6173** against A5's G1h (the `M1` select is lost) |
| S3 | note on any Expose, no cover test | G1p | **6173** |
| S4 | no clip to the screen | G1s | **3270** |
| S5 | no clip to the window or the screen | TM1, G1s | **5270**, **3270** |
| S6 | restamp uses `ui_state` alone | v4_degen | **3** on all six kinds, e2/s1/m1 |
| S7 | wire PLACE ignores `modified` | a5_degen3 bright | pwire s1 **3** |
| S8 | rect stroke does not set its bit | rub2_a4 halo | rect IN **2627** (e2, s1), **404** (m1, d1) |

Every other row of each run stayed at its A5 value, except S3's TM1b, which fell from 5271 to 1:
noting on a partial Expose happens to suit that one row, and G1p shows why it is wrong. After the
last restore `~/gsa5s` was rebuilt and
`callback.c`, `move.c`, `actions.c`, `draw.c`, `xschem.h` compared equal to the main tree.
`~/gsa5s` is deleted.

## Earlier repros, re-run on A5

All on `~/gsa5`, `~/gsa5w` and `~/gsa5n`, in the configurations A4's crew ran (halo and bright,
`colour` and `own`, dark and light), with A4's scripts. "Identical" means pixel-identical to A4's
own snapshots.
- **A2 repros** (D1 `partial`, D2 `fillrect` and `instzoom_hide`, D3 `scoperep`, D4 `xhair`, D5
  `customfont`, L1 `fastsel`): the score logs equal A4's line for line in all eight
  configurations; 578 of 578 snapshots identical. D7 `winemu`: w1, w2, w3 all 0 in halo and
  bright, `colour` and `own`, `fix_broken_tiled_fill` 0 and 1; 48 of 48 identical.
- **A2's `expo*`**: all 99 scores 0 in 11 configurations; 165 of 165 identical.
- **Ten more A2-era poses** A4 did not run (`partial2`, `partial3`, `italic`, `clickhov`, `hoverx`,
  `pinsel`, `symedit`, `newwin`, `instzoom`, `resid`), on `~/gsa4` and `~/gsa5`, halo `colour` and
  bright `own`: 148 of 148 identical.
- **Scenario scripts** (`drag2`, `ovl`, `hil`, `hil2`, `sw`, `ctx_tab`, `ctx_win`, `ctx_misc`,
  `print`, `bigdrag`, `pin1`, `det_ev`, `det_net`, `band`, `band3`, `bandae`; 13 configurations):
  scores equal A4's line for line; 1842 of 1842 snapshots identical.
- **`ctx_v3`** (11 configurations), **`ctx_detach`**, **`ctx_mix`**: scores equal A4's; 220 and 270
  snapshots identical, plus `~/gsl0`'s 90.
- **A4's repros** (`ctx_cancel`, `ctx_cancel2`, `ctx_a4`, `ctx_a4b`, `win_a4`; 14 configurations)
  and five `rub2_a4` configurations: scores equal A4's except K6b (above); 1642 of 1652 snapshots
  identical, the ten others being K6b in the ten styled configurations; `rub2` 630 of 630.
- **`vband` and `vband_k`**: all 19 analysis files byte-identical to A4's (10 `vband`, 9
  `vband_k`); 880 and 396 snapshots identical.
- **The verifier's V4 poses**: `v4_reuse` all 0; `v4_tabmid` and the rubber pose as above.

## Classic byte-identity, `~/gsa5` against `~/gsl0`

All AE 0:
- A2's 15 states: dark 15 of 15, light 15 of 15;
- A2 repros 34 of 34; `expo*` 15 of 15; scenario scripts 282 of 284, dark and light (the two left
  are the full-page PNG export's title-block date, 205 and 204 px, as A2 and A4 recorded);
- `ctx_v3` 20 of 20, `ctx_detach` 10 of 10, `ctx_mix` 8 of 8; A4's repros 146 of 146;
- new and verifier poses: `a5_canvas` 29 of 29 dark and 29 of 29 light; `a5_degen3` 72 + 72;
  `v4_degen` 128 + 128; `v4_degen2` 24; `v4_canvas` 15; `v4_reuse` 16; `v4_tabmid` 44;
- the rubber pose: 126 of 126 dark, 126 of 126 light, 126 of 126 with crosshair, hover and snap
  cursor on;
- `vband` 88 of 88 dark and 88 of 88 light; `vband_k` 44 of 44.

## Health

- **Valgrind, display arm** (`~/gsa5` unless named): `a5_canvas` halo (and on `~/gsa5w`),
  `a5_degen3` bright (and halo on `~/gsa5n`), `v4_degen` halo, the rubber pose (wire, rect, poly,
  arc2) halo, `v4_tabmid` halo, `v4_reuse` bright `own`, `ctx_a4`, `ctx_tab`, `ctx_cancel`,
  `ctx_v3` halo. 12 runs. Every log empty, every run reached `V-DONE`, and the TM rows ran inside
  valgrind with the same scores.
- **Valgrind, `--nogui` and `--pipe`**: `nogui2`, `nogui3`, `nogui4` (headless tabs, `dr` 0
  switches, a synthetic Expose, every placement tool, `load -window`) on `~/gsa5`, `~/gsa5n` and
  `~/gsa5w`; classic, bright and halo, `colour` and `own`. 108 runs: all exit 0, end mark written,
  valgrind log empty, no `FATAL`.
- **Warnings.** All `OBJ` files, base against A5, warning lines with line numbers stripped:
  cairo default, cairo `-std=c89 -pedantic`, non-cairo default, non-cairo `-std=c89 -pedantic`:
  identical files each (6 / 67 / 6 / 67 lines on both). Non-cairo base is `~/gsl0`'s sources with
  a non-cairo `config.h` (`V4/bn`, as A4's verifier did).
- **Suites** (`tests/headless/run_suites.sh`, `GUI_GATE=0`, explicit `AUDIT_DISPLAY`), A5 and
  base (`~/gsl0`), A4's lists. Display arm (`AUDIT_DISPLAY=:279`): 28/30 passed, 1 skipped, on
  both. Counted arm (`--nogui`, `AUDIT_DISPLAY=none`): 19/24 passed, 10 skipped, on both. The
  scan list: display 10/10 on both, counted 7/9 (1 skipped) on both. Every verdict line is identical
  between A5 and base. The reds are base's own: `test_select_at` 5 FAILED and `test_cadence_drag`
  2 FAILED on the display arm; `NORESULT` for `test_cadence_drag`, `test_hover_highlight`,
  `test_hover_selection_repair`, `test_select_at` and `test_wire_complete_with_selection` on the
  counted arm, and `test_annot_declutter_1244`, `test_nh_angle_render` in the scan list's counted
  arm.

## What I could not do

- No real hand input and no real screen. Every gesture is a synthesized event on Xvfb. The tab
  menu was driven by real Tk events on the real widgets, but the Close prompt is a stub.
- The Windows build was not compiled; only the emulation (`~/gsa5w`).
- TM1b, a window over part of the canvas, stays as A4 had it (declared above).
- `sel_note_paste()` sees pastes from a pixmap only. A tiled-GC erase (`gctiled`) or a direct
  stroke into the window by another context is not seen. Only the current context strokes into
  the window, so I found no path where that matters; it is read from the code, not measured.
- `draw()` does not clear `rubber_shown`, on purpose (above). After a `draw()` while placing, the
  next repair puts the shape back, as A4 did.
- Hidden-tab draws that borrow a context (`net_hilight_redraw_other_windows`) were not exercised.
- No timing.

## Housekeeping

- My Xvfb and openbox on `:272`-`:279` are stopped. I killed them by pid after checking each
  command line and `DISPLAY`. No X lock file or socket is left for those displays.
- My runs left `*~.sch` backups in the clones: 5 in `~/gsl0`, 1 each in `~/gsa4`, `~/gsa4w` and
  `~/gsa4n`, 5 in `~/gsa5`, 4 each in `~/gsa5w` and `~/gsa5n`. Each was newer than my start mark,
  and no older ones existed. I removed them.
- The main tree's backups (59 files) have the same md5s as at my start. No run had its cwd in the
  main tree.
- `~/gsl0` is clean. `~/gsa4`, `~/gsa4w` and `~/gsa4n` have no file newer than my start mark (red
  bed untouched). `~/gsa5`, `~/gsa5w` and `~/gsa5n` show only their eight changed files, plus an
  untracked `plot.xpm` in `~/gsa5n`, copied from `~/gsa4n` and rewritten by my headless runs.
  `~/gsa5s` is deleted.
- Scratch under `A5/` is about 457 MB. It sits on the root ext4 disk here, not in RAM. Delete it
  once this is on the ledger.
- In the main tree I changed only the five source files above and wrote this file. No commit.
