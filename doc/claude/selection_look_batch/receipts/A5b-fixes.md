# Stage A5b receipt: N7, N6, W1 and D1b

**In plain English.** The selection overlay has to know which tab's picture the shared drawing
canvas is showing, because it only paints a tab's selection when that tab is the one on screen.
After an internal tab switch that does not redraw (the tab menu's Edit netlist, Save or Close, the
`load -window` save prompt), A5 could get that wrong in two ways the verifier found: a repaint of
half the window or more put the whole tab on screen without the overlay noticing (N7), and a
repaint in more than 16 pieces was never noticed at all (N6). Either way a later select did not
show. A5b drops the "count the Exposes" approach and instead follows every copy of a tab's
picture onto the canvas, so the overlay's idea of what is on screen is what is really there. In
every case measured where the canvas really shows the tab, a select now looks exactly as a full
redraw would; where it still shows parts of two tabs, nothing is painted over the other tab's
part. Two smaller things are
fixed with it: on the Windows build a small repaint no longer paints a selection over the other
tab's picture (W1), and a 3-pixel dot left after a line click with no mouse motion is gone (D1b).
Classic mode is unchanged byte for byte, and nothing about how a selection looks was touched.

Crew: stage-A5b fix crew, 2026-11-15. Base: `bd14668b9` (pristine build `~/gsl0`). Red bed:
`~/gsa5`, `~/gsa5w`, `~/gsa5n` (the A5 tree, which is the main tree's current `src`; not edited).
Built in `~/gsa7` (real X clip, cairo), `~/gsa7w` (Windows emulation: `SEL_REAL_XCLIP 0` plus
the two `#if 0` in `xinit.c`) and `~/gsa7n` (non-cairo). The A5b part alone, against the main
tree's `src`, touches `src/move.c`, `src/callback.c`, `src/draw.c`, `src/actions.c` and
`src/xschem.h`. No text-look code was touched: no colour, width, font, band or
`selection_text_style` logic. Nothing was committed, pushed or stashed anywhere.

Deliverables: this file and `receipts/A5b-incremental.patch` (applies with `git apply` on top of
the A5 diff, i.e. on the main tree as it stands). md5s at the end.

## How it was measured

- **Displays.** My own Xvfb `:286`-`:295` (1920x1080x24), each checked free first (no lock file,
  no abstract socket) and each with openbox. `DISPLAY` was unset in every calling shell, and
  every headless run had `env -u DISPLAY`. Every run had `GUI_GATE=0`, a throwaway `HOME`, and
  its cwd in a throwaway scratch directory holding two symlinks into the clone (`sky130A`,
  `xschem_library`), never a tree root. One lock file per display. I never used `:99`, `:0` or
  the user's screen, and never ran T1.
- **Pixels.** `magick compare -metric AE` against a full `xschem redraw` of the same state
  unless a row says otherwise. "colour" and "own" are `selection_text_style`; "dark" and
  "light" the colour scheme. "noted" = the select changed the screen (pre vs after); "right" =
  the screen after the select against a full redraw (must be 0 where the screen truly shows the
  tab).
- **Scratch.** `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A5b/`
  (below, `A5b/`). New poses `A5b/scr/v7_thr.tcl`, `v7_cov.tcl`, `v7_wsel.tcl`, `v7_rub.tcl`,
  `v7_dw.tcl`; the verifier's V5 poses and every earlier repro are re-run from `A5b/scr/` and
  `A5b/r/`. Images in `A5b/img/`. Scratch, not durable.

## The design: follow the pastes, not the Exposes

A5 moved `sel_canvas_win` (the tab the canvas holds) on a full `draw()`, or when one tab's
**Expose rects** covered the window (`sel_note_expose()`, a list of at most 16 rects). Both
findings come from counting the wrong thing: an Expose is a request, and what reaches the window
is whatever the repair then pastes. N7 is a repair that pasted more than the Expose (the
`sel_pend_full()` widening); N6 is a list too short to hold the request.

A5b removes `sel_note_expose()` and `sel_exp_covers()` and makes `sel_note_paste()` the only
source of truth besides `draw()`. `sel_note_paste()` is already called by every pixmap-to-window
copy (`MyXCopyArea()`, `MyXCopyAreaDouble()`), in every style. Now:

- A paste by the **canvas tab** gives its rect back to the canvas tab.
- A paste by **another tab** makes it the *collecting* tab (if it was not) and cuts the rect out
  of what does not yet show its drawing. When nothing is left, the canvas holds that tab:
  `sel_note_canvas()`.
- The collecting tab's state is kept as its **complement**: the part of what it can paint
  (`sel_paintable()`: its pixmap rect, clipped to the window as it is now and to the screen, as A5
  did) that does not show its drawing. That set is a list of at most `SEL_EXP_MAX` (64) rects that
  may overlap. Its own pastes cut rects (`sel_exp_cut()`, at most 4 pieces per rect,
  `sel_exp_minus()`); the canvas tab's pastes add rects (`sel_exp_put()`); a change in what it can
  paint (a move, a resize, the screen edge) keeps what is left inside and adds the new part
  (`sel_exp_rebase()`).
- **Bounded, and only ever late.** A rect that does not fit is merged with the list rect whose
  bounding box wastes least, and rects the merged one holds are dropped. A merge can only
  **overstate** what does not show the tab, so the tab can be noted later than its drawing gets
  there, never earlier. The list never needs more than 64 entries, whatever the number of Exposes.
- Identity is the context pointer **and** its `window_number` (monotonic, never reused), so a
  freed tab's address being reused cannot inherit a list. Real windows (`top_path` set) and
  scratch contexts (`window_number` 0) never share the canvas and are skipped. In a non-tabbed
  session the canvas is not shared and the record is never consulted (`sel_ctx_on_screen()`).
- When a collecting tab's cover completes **piecewise** (the completing paste does not hold the
  whole paintable area), the earlier pieces were painted with the overlay it had then, and the
  idle repair dropped its damage meanwhile (`sel_idle_cb()`). So completion also queues a
  whole-window repair (`sel_pend_add()` of everything). Row `late` below needs it.
- `draw()` with a bbox drawn **straight into the window** (`draw_window` 1, the "No XCopyArea"
  drawing model) is not a pixmap paste, so it now reports its rect to `sel_note_paste()` too.
  Row `ip1` below needs it.

## N7: a half-window Expose paints the whole tab but did not note it

**Decision: note what was really painted.** The brief offered two options. I measured both.

- *(a) Repair only the exposed rect for a tab not on the canvas* (the verifier's suggestion; my
  sabotage X2). The bookkeeping is then true, but the screen is left **mixed**: part old tab, part
  new, which no full redraw of either tab ever matches, and the new tab's select is never drawn.
  At 50% (row T316): `right` **36231**, the canvas against `t1`'s own picture **30961**. It can
  never reach AE 0, by construction.
- *(b) Count what the repair pasted* (adopted). A repair of half the window or more pastes the
  whole window, so the whole window shows the tab, and the paste itself reports that. The
  bookkeeping is true and the screen is one coherent tab, so the select shows correctly.

The verifier's objection to (b) was the part of the canvas another window covers, where X
discards the paint (TM1b). That part is not lost: with backing store NotUseful the server sends
an Expose for it when it is uncovered, and that Expose is repaired from whichever tab is current
then, which the paste rule follows like any other. It is also exactly what `draw()` already does:
a full `draw()` notes the tab although a covering window clips part of it. TM1b's numbers below
show the result.

**How the repair now reads** (`sel_expose_repair()`, `move.c`, which `handle_expose()`'s styled
branch now calls instead of the four calls it made): a tab not on the canvas repairs the exposed
rect only (its other pending damage belongs to a picture that is not on screen, so it is dropped,
as the idle repair already drops it), and the repair's pastes do the bookkeeping. A rect of half
the window or more still widens to the whole window (`sel_pend_full()`), and that paste notes the
tab. Classic's branch is unchanged except that its trailing `sel_note_expose()` call is gone: its
`MyXCopyArea()` reports the paste itself.

**Real Expose** (`v5_realwin`, the verifier's pose: an override-redirect window over the top part
of `.drw`, a dr 0 switch to `t1`, the window destroyed, `select x5`). `right`, A5 to A5b:

| row | exposed | halo colour | halo own | bright colour | bright own light | `~/gsa7w` halo own | `~/gsa7n` bright colour |
|---|---|---|---|---|---|---|---|
| R1 | 60% | 5270 → **0** | 5539 → **0** | 2238 → **0** | 2508 → **0** | 5539 → **0** | 1160 → **0** |
| R4 | 75% | 5270 → **0** | 5539 → **0** | 2238 → **0** | 2508 → **0** | 5539 → **0** | 1160 → **0** |
| R3 | 100% | 0, 0 | 0, 0 | 0, 0 | 0, 0 | 0, 0 | 0, 0 |
| R2 | 40% | not noted on both (the canvas really is mixed, 45807 against `t1`) |||||

**Threshold** (`v7_thr`, new). `T<h>`: a real Expose of the top `h` rows of a 632-row canvas
(50% is 316 rows); `S<h>`: the same rect as a synthetic Expose. Halo colour shown; halo own, bright
colour, bright own light, `~/gsa7w` and `~/gsa7n` give the same pattern with their own halo size.

| row | rows exposed | A5 noted / right | A5b noted / right | A5b: main's later select |
|---|---|---|---|---|
| T315, S315 | just under 50% | 0 / 36294 | 0 / 36294 (not noted: correct, the canvas is mixed) | drawn, below-strip 0 |
| T316, S316 | exactly 50% | 0 / **5270** | 5270 / **0** | not drawn (canvas holds `t1`) |
| T317, S317 | just over | 0 / **5270** | 5270 / **0** | not drawn |
| T474 | 75% | 0 / **5270** | 5270 / **0** | not drawn |
| T625 | 99% | 0 / **5270** | 5270 / **0** | not drawn |
| T632 | 100% | 5270 / 0 | 5270 / 0 | not drawn |

The last column is the other half of the bug: on A5, after a dr 0 switch back to main, main's
`select M1` was painted **onto `t1`'s picture** (15483 px changed) because A5 still believed the
canvas showed main. On A5b it is not painted, because the canvas truly shows `t1`.

- **R5** (60% uncovered, then a second window over the bottom 20% goes, `t1` still current):
  `right` 5270 → **0**.
- **R6** (the same, but a dr 0 switch to main before the second window goes, so main repaints the
  bottom 20%; then back to `t1` and `select x1`): above the bottom 20%, 10451 → **0**. The bottom
  20% shows main on both (`t1` stays the canvas tab; nothing repaints it with `t1`), which is what
  classic shows there too.
- **The verifier's synthetic `v5_full`**: F1 (60%) and F3 (exactly 50%) 5270 → **0**, noted, in
  every configuration; F2 (40%) unchanged and correctly not noted.

## N6: a cover of more than 16 rects never noted the tab

Fixed by the design above: there is no list of Exposes any more, and the complement list cannot
fill up from tiling covers (each paste of a tile only removes area). `v7_cov` (new): after a dr 0
switch, `t1` is exposed in many synthetic pieces, each under half the window, then `select x5`.
noted / right, A5 → A5b, halo colour:

| row | the pieces | A5 | A5b |
|---|---|---|---|
| k16, k16r | 16 strips, in order and reversed | 5270/0 | 5270/0 |
| k17, k17r | 17 strips | 0/**5270** | 5270/**0** |
| k20 | 20 strips | 0/**5270** | 5270/**0** |
| g4s | 4x4 tiles, shuffled | 5270/0 | 5270/0 |
| g64 | 8x8 tiles | 0/**5270** | 5270/**0** |
| g100s | 10x10 tiles, shuffled | 0/**5270** | 5270/**0** |
| g500 | 25x20 tiles, in order | 0/**5270** | 5270/**0** |
| ov16, ov20 | overlapping strips (ov20 shuffled) | 5270/0, 0/**5270** | 5270/0, 5270/**0** |
| brick | 8x10 offset bricks, shuffled (non-tiling edges) | 0/**5270** | 5270/**0** |
| rnd | 60 random rects, then 16 strips | 0/**5270** | 5270/**0** |
| gap | 16 strips, one 1 px short | 0/5333 | 0/5333 (not noted: correct) |
| gapg | 8x8 shuffled, one tile 1 px short | 0/5283 | 0/5283 (not noted: correct) |
| mid | left half, then main's pending repair paints into it, then right half | 0/10169 | 0/10169 (not noted: correct) |
| mid2 | `mid`, then the left half again | 5270/0 | 5270/0 |
| late | left half, `select x5` in `t1`, right half | 2472/0 (the first half lacked its halo until the next select) | 0/0 (whole-window repair at completion) |

The same pattern holds in halo own (5539), bright colour (2238), `~/gsa7w` halo colour and
`~/gsa7n` bright colour (1160). The verifier's `v5_cov`: C1 (20 strips), C1c (17), C1e (8x8)
5270 → **0**; C1b, C1d, C2, C3, C5d, C10 unchanged and noted; C4, C5, C9, C12, C13 unchanged and
not noted. **C5b, C5c and C11 change from not noted to noted, and that is correct**: each contains
an Expose of half the window or more (C5b and C5c are the whole window minus one row or one
pixel; C11 three half-window Exposes), and both A5 and A5b repaint the whole window for those.
After them the screen truly is `t1` everywhere (A5's pre-select screen differs from `t1`'s full
redraw by exactly its 5270 halo pixels), so A5's "must not note" was the N7 bug in another form.

**Cost.** The Expose loop is not measurably slower: `g500` (500 Exposes) 95 ms on A5 against
100 ms on A5b in one run, within run-to-run spread; the per-Expose repair dominates.

## W1: on Windows, a partial Expose painted the whole selection over the other tab

**Cause.** Without a real X clip (`SEL_REAL_XCLIP` 0), `sel_overlay_flush()` paints every
selected entry that meets the repair rects unclipped, after the copies. For a tab not on the
canvas, everything outside its rects is the other tab's picture.

**Fix** (`sel_overlay_flush()`, plus `sel_expose_repair()` for the restamp). For a tab not on
the canvas (`sel_off_canvas()`), and a repair that is not the whole window:
- texts do not grow the repair rects (`sel_close_texts()` is skipped), so nothing outside the
  exposed rect is copied;
- without a real clip only the entries **wholly inside** one rect are painted
  (`sel_paint_entries()`'s new `inside` argument, `sel_rect_holds()`), and none of the other
  overlays (`sel_paint_others()`); with the real clip everything is painted, clipped, as before;
- only the exposed rect is repaired: the tab's other pending damage is dropped
  (`sel_expose_repair()`), which is what the idle repair does with it anyway;
- a shape being placed is restamped inside the exposed rect only, under a clip, and not at all
  without one.

`v7_wsel` (new): `t1` with a selection, main drawn, a dr 0 switch to `t1`, then ONE synthetic
Expose under half the window. AE of the canvas **below the exposed strip** against main's own
picture (must be 0: nothing of `t1` outside the rect), halo own:

| row | the Expose | `~/gsa5` | `~/gsa5w` | `~/gsa7` | `~/gsa7w` |
|---|---|---|---|---|---|
| s1 | top 30% strip, `x5` below it | 0 | **7355** | 0 | **0** |
| s2 | 312 rows, holds `x5` | 0 | 0 | 0 | 0 |
| s3 | 250 rows, cuts through `x5` | **1863** | **3974** | 0 | **0** |
| s5 | as s1, with a `select x1` pending at the Expose | **10739** | **18094** | 0 | **0** |
| s6 | as s1, `t1` was placing a line | **600** | **600** | 0 | **0** |
| s4 | as s1, `t1` had its crosshair shown | 0 | **7355** | 0 | 0 |

s3, s5 and s6 were red on the **real-clip** build too: the texts grew the rect (s3), the
pending damage was repaired with it (s5), and the restamp was unclipped (s6). The verifier's
`v5_wsel` s1 on the emulation: halo own 7355 → **0**, bright own 3318 → **0**, halo colour 6833
→ **0**. Image: `A5b/img/w1_s5_a5w_a5bw_mainref.png` (left `~/gsa5w`, middle `~/gsa7w`, right
main's own picture).

## D1b: a dot after a line PLACE with no motion

**Fix** (`new_line()` PLACE, `actions.c`): a click that stored nothing keeps the line's
`rubber_shown` bit only when the stroked rubber is the point clicked, i.e. when
`nl_x1`,`nl_y1`,`nl_x2`,`nl_y2` all equal the snapped click point. A click with no motion before
it may land elsewhere, and the new segment there is not stroked, so the bit is cleared.

`v7_rub` (new, from `v5_rub`), AE against the tool's own picture (n0), halo: `pline_jump` and
`pline_back` e2 **6 → 3**, s1 and m1 down by 3 as well; bright the same. 3 is classic's own value
(the P residue the tool erases, as the verifier recorded). The same attack on rect and wire PLACE
(`prect_jump`, `prect_back`, `pwire_jump`, `pwire_back`, `rect_back`, `wire_back`) shows **no**
dot on A5: rect and wire take another path (wire PLACE stores a segment and redraws; rect is
stroked from the click). An edit there had no row that could see it, so I reverted it and changed
only the line.

## Sabotages

Each applied to `~/gsa7` (or `~/gsa7w`), built, run, restored with `cp` from `A5b/pristine/`,
proved with `cmp`, rebuilt. Script: `A5b/scr/sab7.py`, `A5b/scr/sab7.sh`.

| id | sabotage | pose | red |
|---|---|---|---|
| X1 | a whole-window paste is not counted | v7_thr, v5_realwin | T316/T317/T474, S316/S317 noted 0, right **5270**; R1, R3, R4 **5270**; R6 above **10451** |
| X2 | option (a): a tab off the canvas never widens to the whole window | v7_thr | T316 right **36231** (never noted) |
| X3 | on a full list, drop the rect instead of merging | v7_cov | gapg noted **5270** (noted on a non-cover: wrong) |
| X5 | the canvas tab's paste is not given back | v7_cov | mid noted **5270** (wrong) |
| X6 | emulation: paint every entry meeting the rects | v7_wsel (w) | s3 below **3974** |
| X6b | emulation: A5's unrestricted repaint | v7_wsel (w) | s1 **7355**, s3 **3974**, s5 **15070**, s4 **7355** |
| X8 | an off-canvas repair grows its rects for texts | v7_wsel | s3 below **1863** |
| X9 | an off-canvas Expose repairs its other pending damage too | v7_wsel | s5 below **10739** |
| X10 | an off-canvas Expose restamps unclipped | v7_wsel | s6 below **600** |
| X11 | the line keeps its bit wherever the click lands | v7_rub | pline e2 **6**, s1 +3, m1 +3 |
| X12 | piecewise completion does not queue the whole-window repair | v7_cov | late noted **4247** (first half had no halo) |
| X14 | a bbox `draw()` straight into the window is not counted | v7_dw | ip1 noted **5270** (wrong) |
| X7 | emulation: paint the other overlays for an off-canvas tab | v7_wsel (w) | **no red** (declared below) |

Every other row of each run stayed at its A5b value. After the last restore all five files
compared equal to `A5b/pristine/` in both trees, and both were rebuilt.

`v7_dw` (new) is the row behind X14: `t1` off the canvas exposes the left half; main, still the
canvas tab, deletes M1 (dw*) or places an instance (ip*), whose bbox `draw()` reaches the window;
`t1` exposes the right half. The canvas then shows main where M1 was, so `t1` must not be noted.
`ip1` (draw_window 1): A5 noted 5270 (wrong) → A5b **0**; dw0, dw1, ip0 correct on both.

## Earlier repros, re-run on the final A5b

The whole list (`A5b/scr/reg7.sh`): A2's repros (D1 `partial`, D2 `fillrect` and
`instzoom_hide`, D3 `scoperep`, D4 `xhair`, D5 `customfont`, L1 `fastsel`); the scenario scripts
(`drag2`, `ovl`, `hil`, `hil2`, `sw`, `ctx_tab`, `ctx_win`, `ctx_misc`, `print`, `bigdrag`,
`pin1`, `det_ev`, `det_net`, `band`, `band3`, `bandae`, `ctx_v3`, `ctx_detach`, `ctx_mix`); A4's
repros (`ctx_cancel`, `ctx_cancel2`, `ctx_a4`, `ctx_a4b`, `win_a4`, `rub2_a4`); `vband`, `vconn`;
A5's `a5_canvas`, `a5_degen3`; the verifier's V4 and V5 poses (`v4_degen`, `v4_degen2`,
`v4_canvas`, `v4_reuse`, `v4_tabmid`, `v5_cov`, `v5_rub`, `v5_geo`, `v5_k6`, `v5_full`,
`v5_realwin`, `v5_win`, `v5_wsel`, `v5_xh`, `v5_xh2`, `v5_load`); and the five new `v7` poses.
On the final binaries, in six configurations, against the same list on `~/gsa5*` (A5):

| configuration | snapshots | identical to A5 | different | no A5 counterpart (new rows) |
|---|---|---|---|---|
| `~/gsa7` halo colour dark | 1299 | 1158 | 54 | 87 |
| `~/gsa7` halo own dark | 1299 | 1158 | 54 | 87 |
| `~/gsa7` bright colour dark | 1299 | 1158 | 54 | 87 |
| `~/gsa7` bright own light | 1299 | 1158 | 54 | 87 |
| `~/gsa7w` halo own dark | 1299 | 1155 | 57 | 87 |
| `~/gsa7n` bright colour dark | 1295 | 1156 | 55 | 84 |

Every repro's own score line is identical to A5's, in all six. Every differing snapshot is one of:
- **the rows this stage fixes**: `v5_realwin` R1, R4; `v5_full` F1, F3; `v5_cov` C1, C1c, C1e;
  `v7_thr` T316-T625, S316, S317, R5, R6 (and their `_m` legs, where A5 painted main's select
  onto `t1`'s picture); `v7_cov` k17, k17r, k20, g64, g100s, g500, ov20, brick, rnd; `v7_wsel` s3,
  s5 (real clip), plus s1, s4 and the verifier's `v5_wsel` s1 and `v5_win` w1 on the emulation
  (`v5_win` w1: 5539 → **0** against its redraw); `v5_rub` `pline_jump` e2, s1, m1 (3 px, D1b).
  By exactly the halo size where the select is now drawn: 5270 halo colour, 5539 halo own, 2238
  bright colour, 2508 bright own light, 1160 non-cairo;
- **C5b, C5c, C11**: explained under N6;
- **TM1b and G1h** (below);
- `print` `p_png_full`: the full-page PNG export's title-block date (228 px, 262 on the
  emulation), as every stage has recorded;
- `vband` rows G and H: 311 px (310 light, 143 non-cairo). That is the clone's path in the sheet's
  title block, `/home/analog/gsa7` against `/home/analog/gsa5` (image `A5b/img/vb75.png`); those
  rows are identical against an earlier A5b run in the same clone.

Against that earlier A5b run (before the wire and rect D1b edits were reverted), the final
binaries are identical on every snapshot both runs have: 1212 of 1212 (1211 non-cairo).

**TM1b moves** (the verifier's declared limit: an alert window over part of the canvas during a
real deiconify after a dr 0 switch). `t1`'s select now shows outside the alert: halo colour 5271
→ **1**, halo own 5540 → **1**, `~/gsa7w` 5540 → **1**, bright colour 2239 → **1**, `~/gsa7n` 1161
→ **1**, bright own light 2857 → **349** (the 349 is on A5 too: the alert's frame outside the
masked rect in the light scheme). The deiconify's Expose is half the window or more, so it is
repaired as the whole window, which notes `t1`. The part under the alert is clipped by the
server; it is the masked rect, and the server exposes it again when the alert goes.

**G1h changes** by 6173 px (halo colour; 6303 own, 4234 bright, 4366 bright own light, 3431
non-cairo). G1h's first Expose is exactly half the window, so on A5 too it repainted the whole
window with `t1`; A5b records that. Main's later `select M1` (after a dr 0 switch back) is
therefore not painted over `t1`'s picture, where A5 painted it. What shows at M1 is a plain patch
of main's drawing, pasted by main's immediate unselect erase (`sel_styled_erase()`, not part of
this stage; declared below). Neither build matches main's full redraw there, because the canvas
shows `t1` on both: that is the dr 0 state itself (right of the middle, against main's redraw:
14011 px A5, 16496 A5b). Image `A5b/img/g1h_a5_a7.png`: A5, A5b, main's full redraw.

## Classic byte-identity, `~/gsa7` against `~/gsl0`

The whole list above, classic, dark and light: **1299 of 1299 snapshots identical, both
schemes**, and every repro's score line identical, `print` included.

A first run gave 336 of 1299, and the reason is worth knowing for the next crew: the sheet's
title block prints the schematic's absolute path, so a snapshot of `~/gsa7` differs from one of
`~/gsl0` by the clone's name (`gsa7` against `gsl0`). Every one of those differences sat in the
bottom strip where that path is drawn (most in a 26x27 box at the right edge), plus the
full-page PNG export. So the comparison was re-run with `~/gsa7`'s binary and `~/gsl0`'s data
paths (`DATAREPO`, `A5b/scr/mkcwd.sh`), which puts the same path in both title blocks; that run
is the one quoted. The same cause is behind the `vband` G and H differences against A5 above.

## Health

- **Valgrind, display arm** (each pose's default rows, `V-DONE` reached, log empty unless named):
  `a5_canvas`, `v7_thr`, `v7_cov`, `v7_wsel`, `v7_rub`, `v7_dw` on `~/gsa7` halo own, on
  `~/gsa7w` halo own and on `~/gsa7n` bright colour; `a5_canvas`, `v7_cov`, `v7_rub` on `~/gsa7`
  halo colour; `v7_thr`, `v7_wsel` on `~/gsa7` bright colour. 23 runs, every log empty except
  one `a5_canvas` run: see the TM5 observation below, which is base's.
- **Valgrind, `--nogui` and `--pipe`** (`v5_ng.tcl`: headless tabs, dr 0 switches, a synthetic
  Expose, every placement tool, `load -window`), on the final `~/gsa7`, `~/gsa7w` and `~/gsa7n`,
  classic, bright and halo, colour and own: 36 runs, every one exit 0, end mark `V5NG-OK`,
  valgrind log empty, no `FATAL`.
- **Warnings.** Every `OBJ` file compiled, warning lines with line numbers stripped, final
  sources: cairo default 6 lines, cairo `-std=c89 -pedantic` 67, non-cairo 6, `~/gsa7w` 6. Each
  file is identical to base's (`~/gsl0`; non-cairo base = `~/gsl0`'s sources with `~/gsa7n`'s
  `config.h`, built in scratch). `-Wall -Wextra` on the four changed `.c` files: 143 lines on
  base, A5 and A5b, identical files per source.
- **Suites** (`tests/headless/run_suites.sh`, `GUI_GATE=0`, explicit `AUDIT_DISPLAY`), A5b
  (`~/gsa7`), A5 (`~/gsa5`) and base (`~/gsl0`), the V5 lists. Note that `run_suites.sh` itself
  `cd`s to the repository root it lives in, so those xschem runs had their cwd at the clone's
  root; that is the harness's own behaviour, and I cleaned what they left (Housekeeping).

  | list | arm | base | A5 | A5b |
  |---|---|---|---|---|
  | selection (31) | display `:288`-`:290` | 28/30, 1 skipped | same | same |
  | selection (34) | counted (`--nogui`, `AUDIT_DISPLAY=none`) | 19/24, 10 skipped | same | same |
  | scan (10) | display | 10/10 | same | same |
  | scan (10) | counted | 7/9, 1 skipped | same | same |
  | windows/placement (12) | display | 8/10, 2 skipped | same | same |
  | windows/placement (12) | counted | 5/10, 2 skipped | same | same |

  Every verdict line is identical between A5b and A5, and every verdict identical to base. The
  reds are base's own: display `test_select_at` (5 FAILED), `test_cadence_drag` (2 FAILED),
  `TIMEOUT` `test_placement_preview_doors` and `test_shape_draw_gate`; counted `NORESULT` for
  `test_cadence_drag`, `test_hover_highlight`, `test_hover_selection_repair`, `test_select_at`,
  `test_wire_complete_with_selection`, `test_annot_declutter_1244`, `test_nh_angle_render`,
  `test_clone_canvas_bindings`, `test_close_window_restores_prev_tab`, `test_multi_window`,
  `test_window_numbering`, and `FAIL` `test_load_window_routing`.

## Timing

The A2/A3 timing rows (`A5b/scr/tim7.sh`, A2's `perfv`, `vperf`, `perfb2`, `bandbig` and the drag
bench), on `:286`, builds alternating, two reps: base classic (`~/gsl0`), A5 halo and bright
(`~/gsa5`), A5b halo, bright and classic (`~/gsa7`). ms per event, rep 1, rep 2:

| row | base classic | A5 halo | A5b halo | A5 bright | A5b bright | A5b classic |
|---|---|---|---|---|---|---|
| hover | 12.96, 10.82 | 2.54, 1.78 | 1.73, 1.73 | 1.82, 1.72 | 1.04, 1.39 | 8.01, 10.24 |
| crosshair (`xh2`) | 20.00, 17.37 | 2.01, 1.43 | 1.38, 1.37 | 1.46, 1.43 | 0.91, 1.19 | 12.76, 18.18 |
| rubber band motion | 24.26, 18.97 | 1.09, 0.34 | 0.76, 0.68 | 0.76, 0.71 | 0.64, 0.61 | 13.53, 18.91 |
| select all | 8.82, 6.79 | 0.81, 0.64 | 0.65, 0.64 | 0.72, 0.71 | 0.53, 0.53 | 5.11, 6.62 |
| select all, zoomed (`sa3500`) | 14.67, 14.12 | 51.51, 38.34 | 27.62, 40.80 | 34.20, 36.56 | 28.25, 32.85 | 9.05, 12.46 |
| band grow, big (`gr3500`) | 11.20, 9.41 | 5.91, 5.40 | 2.99, 3.89 | 4.78, 4.55 | 2.98, 3.66 | 10.14, 10.05 |
| drag K=390 | 9.03, 7.86 | 9.43, 9.65 | 5.07, 6.55 | 7.61, 7.79 | 5.02, 6.04 | 7.93, 8.32 |
| drag K=826 | 6.61, 5.63 | 8.71, 8.67 | 9.83, 12.89 | 16.01, 16.09 | 9.62, 12.01 | 5.94, 6.12 |

The rest of the table (`A5b/scr/timtab7.sh`) reads the same way. No row is slower on A5b than on
A5 beyond the spread between two reps of one build, and A5b classic is within the same spread of
base. **The machine was not quiet**: another crew's work kept the load average at 8.5 falling to
5.3 over the run (20 cores), which is why reps differ by up to 50%. The one row that looked worse,
halo drag K=826, was re-run four more times alternating the two builds right afterwards: A5
14.07, 13.88, 13.55, 13.79 against A5b 13.46, 13.92, 13.82, 13.68 ms per step, and K=390 7.30,
7.05, 6.85, 7.05 against 7.01, 6.90, 6.85, 7.07: equal. The bookkeeping costs a string compare per
paste by the canvas tab; the list work runs only while a tab off the canvas is collecting.

## Observation, not mine: the `a5_canvas` TM5 stop is a crash in `delete_undo()`, on base too

The verifier recorded that `a5_canvas` sometimes stops after TM5's "UNSAVED data: want to exit?"
box, on `~/gsa5`, `~/gsa4` and base. Under valgrind it shows what it is: a SIGSEGV reading a NULL
`xctx->undo_dirname` in `my_snprintf()` from `delete_undo()` (`save.c`), from
`delete_schematic_data()`, from `new_schematic` destroy (`destroy_tab()`, the tab menu's Close
answered OK). Reproduced under valgrind on base `~/gsl0` (classic) 1 time in 10, `~/gsa5` 1 in 4,
`~/gsa7` 2 in 5 (halo own), with identical stacks. Nothing in it touches the overlay, and it is intermittent at
every level, so the counts are not a rate comparison. `delete_undo()` trusts
`undo_initialized` to mean `undo_dirname` is set, and `init_undo()` sets `undo_initialized` even
when the directory could not be made; I did not establish which path leaves it NULL here. Worth
an issue of its own; I filed none (not in this stage's scope).

## Declared limits

- **A shuffled cover of many tiles may never note the tab.** The 64-rect list merges when it
  fills, and a merge overstates. Simulated, not measured on screen: 16x16 shuffled tiles (256)
  noted only on some shuffles, 25x20 shuffled (500) on none. In order (row g500) and up to 10x10
  shuffled (g100s) they note. This is the safe side: the select is then not drawn, exactly as on
  A4 and A5, until the next full `draw()`. A real Expose region of that many pieces needs that
  many windows over the canvas.
- **Emulation: an entry crossing an exposed rect's edge is not painted** for a tab not on the
  canvas (painting it would paint outside the rect). `v7_wsel` s3 on `~/gsa7w` against `~/gsa7`:
  2474 px inside the strip. It is repaired by the next full repair of that tab.
- **Emulation: skipping `sel_paint_others()` for a tab not on the canvas has no row that sees it**
  (sabotage X7 stays green). The hover, crosshair and placement overlays of a tab that is not on
  screen should not be up at an Expose; I found no pose that puts one there.
- **Immediate paints by a tab not on the canvas still reach the other tab's picture**:
  `sel_styled_erase()` (an unselect's immediate copy), a tiled-GC erase (`gctiled`) and a direct
  stroke. They are not prevented; that code is outside this stage. The erase is a
  `MyXCopyArea()`, so the bookkeeping follows it; a tiled fill and a stroke are not pastes and are
  not followed, as A5 already recorded. Row G1h above shows the erase.
- **A hover or crosshair immediate repair** by a tab not on the canvas still flushes its pending
  damage, as A5 did.
- **The part of a whole-window repair that another window covers counts as painted**, as
  `draw()` does; the server's later Expose for it is repaired and counted like any other.
- **Timing was taken on a loaded machine** (load average 8.5 falling to 5.3, from another crew).
  A5b is no slower than A5 within the spread between reps, but that spread was up to 50%, so
  this cannot see a small regression.
- No real hand input and no real screen: every gesture is synthesized on Xvfb (the tab menu by real
  Tk events on the real widgets, the Close prompt stubbed). The Windows build was not compiled;
  only the emulation.

## Housekeeping

- **Displays stopped.** All ten of mine, `:286`-`:295`: each Xvfb and openbox pid came from my
  `log/x<n>.pids`, and each was checked before the kill (`/proc/<pid>/cmdline` was
  `Xvfb :<n> ...`, and the openbox's own `DISPLAY` was `:<n>`). No `/tmp/.X<n>-lock` or socket is
  left for any of them. The openbox processes still running are on `:270`-`:276`, which are A6's,
  and I did not touch them.
- **Clones cleaned.** `scr/hk7.sh doit` removed 36 untracked or ignored files my runs had written
  after my start mark into `~/gsl0`, `~/gsa5`, `~/gsa5w`, `~/gsa5n`, `~/gsa7`, `~/gsa7w` and
  `~/gsa7n`. They were `*~.sch` backups (`untitled~.sch`, `xschem_library/examples/{flop,dlatch,
  mos_power_ampli}~.sch`, `sky130A/.../not~.sch`, `tests/from_user/before_5~.sch`), the
  `tests/headless/results/test_statusmsg_hold_0248.log` a suite writes, and
  `tests/headless/.scratch/_p0269_*`. `~/gsl0` got some of these through the `DATAREPO` symlinks
  of the classic-identity runs. A second pass lists nothing. `~/gsl0` has no modified tracked
  file. The gsa5 and gsa7 clones show only their 8 modified `src/` files. The one exception is
  `~/gsa5n/plot.xpm`, which is dated 09:49, before my start mark at 11:17, so it is not mine and
  I left it.
- **Emergency-save dirs.** I removed the 22 `/tmp/xschem_emergencysave_*` dirs my runs created:
  - 4 `flop_*` from the valgrind `a5_canvas` crashes (12:25-12:32);
  - 6 `untitled_*` from suite TIMEOUTs (12:14-12:27);
  - 12 `not_*` (11:50:58-11:54:44). These begin two seconds after my `r1`/`r2` repro runs
    started (`log/r1.out`, 11:50:56) and are empty but one. The timing is the only evidence they
    are mine.

  The list is in `log/emerg_removed.txt`. `xschem_emergencysave_bandgap_afefaccada` (12:49, empty)
  is not mine and is left. None of my scripts names bandgap, and my runs at that minute were the
  `rub2` poses.
- **Scratch.** I deleted the PNG outputs (`out/`, `r/out/`, `r/a2/out/`) and the openbox homes.
  `selshot/A5b/` is now about 10 MB and keeps `scr/`, `r/scr/`, `sim/`, `img/`, `log/`, `warn/`,
  `suites/`, `sabchk/`, `pristine/` and `patch/`.
- **Main tree.** The only things I added are this receipt and `receipts/A5b-incremental.patch`.
  `git -C ~/dev/xschem-claude diff -- src | md5sum` reads `1c35de6bd5f722eb374c922052ff9f17` before
  and after.

## Patch and md5s

- `receipts/A5b-incremental.patch`: **`5d9dbc83062a45d09caf6e2b91bbb67b`**.
  - It covers 5 files: `src/actions.c`, `src/callback.c`, `src/draw.c`, `src/move.c` and
    `src/xschem.h`.
  - It is a `diff -u` of the main tree's `src` (the A5 tree) against `~/gsa7/src`.
  - `git -C ~/dev/xschem-claude apply --check` passes.
  - Applied to a copy of the main tree's `src`, the result is `cmp`-identical to `~/gsa7/src`.
- `git -C ~/gsa7 diff bd14668b9 -- src | md5sum`: **`41d3cfa12b7bb11ddcd5074bc3b98ef8`**.
  This is A5 plus A5b, 8 files, on HEAD `bd14668b9`.
- The main tree's `git diff -- src | md5sum` is unchanged: `1c35de6bd5f722eb374c922052ff9f17`.
- **Merging with A6.** I checked this against `receipts/A6-incremental.patch` as it stood when I
  read it.
  - Strict `git apply` of either patch on top of the other fails on one hunk, `src/move.c`
    hunk 9. A6 adds `if(xctx->bbox_set) sel_cairo_bbox_clip(1);` just before the closing brace of
    `sel_overlay_flush()`. A5b adds the new `sel_expose_repair()` right after that brace, so the
    two hunks touch adjacent lines.
  - `patch -p1` of A5b on top of A6 merges at fuzz 1 and keeps A6's line inside
    `sel_overlay_flush()`, where it belongs.
  - The merged tree compiles. Its only warning is the one base already has in `actions.c`.
  - The two patches share no other lines. A6's `scheduler.c`, `xinit.c` and `xschem.tcl` changes
    do not overlap with mine, and in `draw.c`, `move.c` and `xschem.h` the hunks are in different
    places.
