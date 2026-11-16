# A7 verify: Bright with box (adversarial)

- **Date:** 2026-11-15
- **Verifies:** stage A7 (`selection_style brightbox`, "Bright with box", made the default),
  receipt `receipts/A7-brightbox.md`, patch `receipts/A7-combined.patch`.
- **Trees, all built with `./configure && make -C src`:**
  - `~/gsv7`: `e6b38ba83` + `A7-combined.patch`. `git diff e6b38ba83 | md5sum` gives
    `8db50b9272a724e7c903cee676d6ee3b`, the patch file's own md5.
  - `~/gsv7b`: `e6b38ba83` + `sel_on_e6b38ba83.patch` (pre-A7). `git diff` md5
    `ba0d5a4e852ec1316e4cf8004cc2547f`, the patch file's own md5.
  - `~/gsv7c`: `e6b38ba83` unpatched (base, for Classic identity and pre-existing checks).
  - `~/gsv7s`: a second A7 copy, used only for the broken-on-purpose builds. It was
    restored, byte-compared (see below) and then deleted.
  - Compiler warnings: the same six `-Wdiscarded-qualifiers` lines in all three builds
    (normalised warning list md5 identical); A7 adds none.
- **Displays:** private Xvfb `:300`–`:303`, each with its own openbox. Every xschem run had
  an explicit `DISPLAY=:30x` under `env -u DISPLAY`, or no display at all. Every run had a
  throwaway HOME.

## Verdict

**A7: SAFE WITH LIMITS.** I found no A7 defect. The limits are two LOW inaccuracies in the
FAQ entry and the coverage gaps listed at the end.

**The batch: one HIGH finding, which is not A7's.** On the batch's tree, both before and
after A7, `test_op_annot` fails rows `L27` and `U19`. It passes at base. It is registered
in both `hcases` and `dcases`, so T1 on this tree is red on both arms. No receipt in the
batch mentions it.

## Findings

### HIGH (batch-level, from a stage before A7): `test_op_annot` rows L27 and U19 are red

| tree | arm | result |
|---|---|---|
| `~/gsv7c` (base) | `--nogui` | `ALL PASS (486 checks)` |
| `~/gsv7b` (pre-A7) | display `:301` | `2 FAILED (491 passed)`: L27, U19 |
| `~/gsv7` (A7) | display `:300` | `2 FAILED (491 passed)`: L27, U19 |
| `~/gsv7` (A7) | `--nogui` | `2 FAILED (484 passed)`: L27, U19 |

```
FAIL: L27 THE REFACTOR HAPPENED: HIDE_TEXT survives in ONE .c, and five .c files call text_hidden
  -> {actions.c {actions.c draw.c move.c psprint.c select.c svgdraw.c}}
  (exp {actions.c {actions.c draw.c psprint.c select.c svgdraw.c}}) : FAIL
FAIL: U19 the colour override reaches all three back ends from ONE helper
  -> {actions.c draw.c move.c psprint.c svgdraw.c} (exp {actions.c draw.c psprint.c svgdraw.c}) : FAIL
```

- **Cause:** both rows list the `src/*.c` files that call `text_hidden` and
  `annot_text_layer`. The batch added one call to each in `src/move.c`, in the
  styled overlay's per-text helper (the two lines read
  `if(text_hidden(xctx->text[i].flags, TEXT_CTX_SCHEMATIC)) return -1;` and
  `if((alay = annot_text_layer(xctx->text[i].flags, TEXT_CTX_SCHEMATIC)) != -1) tl = alay;`).
  `sel_on_e6b38ba83.patch` adds them. A5b, A6 and A7's incremental patches do not, so a
  stage before A5b brought them in. At base, `move.c` has neither call.
- **My reading (the driver's call):** the product line looks right. An overlay that repaints
  a text's glyphs has to agree with `draw.c` on whether the text is hidden, and on its
  annotation colour. So the overlay is a fourth caller and the rows' expected sets are
  narrow. Per CLAUDE.md, widen the rows deliberately, with a comment saying why. Do not
  widen the regexp to keep the count still. Ideally also add a behavioural row: a hidden
  `hide=op` text must not appear when selected.
- **Effect:** T1 on this tree would score this case red on both arms: two `FAIL` lines plus
  a `HARNESS:` line per arm.

### LOW (A7's FAQ, Q94): the installed-rc sentence leaves out `./xschemrc`

The FAQ says *"For an installed xschem the rc file is `~/.xschem/xschemrc`."* I measured an
install-like layout (share dir outside the source tree, so `running_in_src_dir=0`).
`~/.xschem/xschemrc` holding `set selection_style bright` is read and wins. But if the
launch directory holds an `./xschemrc`, xschem reads that file **instead** of
`~/.xschem/xschemrc`, and the home file's line is ignored (`xinit.c`'s rc chain:
`--rcfile`, else `./xschemrc`, else `~/.xschem/xschemrc`). A user with a project
`xschemrc` would add the line to the wrong file. A half-sentence fixes it.

### LOW (A7's FAQ, Q94): "on those it does not show" holds only at narrow widths

*"A wire's or line's box lies on the bright stroke itself, so on those it does not show."*
I selected two wires and one line and compared Bright with Bright with box, same pose
(`rows7.tcl`):

| `hover_highlight_width` | full zoom | zoomed in |
|---|---|---|
| 0 | 0 px | 0 px |
| 1 (default) | 0 px | 0 px |
| 3 | **1310 px** | 0 px |

The sentence is true at the default width. It is false once the box is wider than the
bright stroke at the current zoom. Suggested wording: "...so at the default width it does
not show".

### INFO (pre-existing, not A7: same counts in pre-A7 Bright, present in base Classic)

Each of these was checked against a comparator before being called "not A7's".
- **Copy, then Escape (`c4_copy_esc`):** the hover outline on GND is not redrawn. 50 px at
  width 1, 685 px at width 9, identical in pre-A7 Bright and Halo. Base Classic gives 1589.
- **Paste and place, mid-frame (`p1`, `q1`):** 3022 and 517 px, identical in every look,
  base Classic included.
- **Ctrl-drag end, light theme, fluid off (`d2`):** a 1 px cyan dot in M1's source pin.
  Also present in base Classic and pre-A7 Bright.
- **The user's own config** (`sky130A/cadence_style_rc`, `zero_opamp.sch`, `rows6.tcl`,
  31 rows): 9 rows are non-zero, with byte-for-byte the same counts on pre-A7 Bright at
  widths 1 and 5. Base Classic has 15 non-zero rows. The large ones (Delete, Ctrl-wheel
  out, wheel pan; 543/851/784 px at width 5) are the hover outline left where it was. **One
  pointer motion clears each of them** (`rows8.tcl`: 117 → 0, 543 → 0). A real pointer
  always sends that motion, so a user should not see them for long.
- **Changing the colour, width or style without a redraw** (`k1`, `w1`, `v1`): this is the
  documented behaviour. The GUI always pairs `build_colors` with a redraw.

## Coverage: gestures (residue rows)

A row compares the window with the same window after `xschem redraw`
(`magick compare -metric AE`), so a residue or a missing repair shows as non-zero.

**`rows1.tcl`, 71 rows on a fixture**: a line, a rect, an acute polygon, an arc, a
custom-font text, a plain text and a bold text; diagonal wires and a wire on a pin;
`nmos4`, `res`, a label with `lab=A`, a label with no `lab`, a label with `lab=" "`, a
symbol with no texts, a text-only label symbol, a subcircuit and `gnd`. The rows are:
copy (mid, a second mid, end, deselect after, Escape, rotate mid, flip mid, rotate end),
Ctrl-drag (mid, end), paste (mid, end), place (mid, end, Escape), stretch with fluid off
(mid, mid, end), a fluid move (mid, end), Delete and undo, align, rotate and flip at rest
(key and menu), highlight with a selected wire (highlight, deselect, reselect,
unhighlight), descend and go back (select, inside, select all inside, back, deselect),
the theme toggle while selected (toggle, select more, deselect), the selection colour
changed while selected, the hover width changed at runtime (deselect, hover, select all,
deselect all), the style typed while selected, zoom in ×12 and out ×14 with hover,
deselect and reselect, then the special objects, hover on arc, polygon and custom text,
partial deselect, a text shrunk and a label grown and shrunk.

| run | look | scheme | width | other | non-zero rows |
|---|---|---|---|---|---|
| r1_bb_d_w1 (+ rep) | brightbox | dark | 1 | | c4 50, p1 3022, q1 517, k1, w1, v1 |
| r1_bb_d_w9 | brightbox | dark | 9 | | c4 685, p1 3022, q1 515, k1, w1, v1 |
| r1_bb_d_w15, w25 | brightbox | dark | 15, 25 | | the same six rows |
| r1_bb_l_w1_nofl (+ rep) | brightbox | light | 1 | fluid off | the same six + d2 1 px |
| r1_bb_l_w9_cad | brightbox | light | 9 | Cadence keys | the same six |
| vg_rows1_w9 | brightbox | dark | 9 | **under valgrind** | the same six; **0 valgrind errors** |
| comparators | pre-A7 bright, halo; base classic | | 1, 9 | | c4, p1, q1 (and d2) as above |

**Second toplevel** (`rows2.tcl`: main window and a second window side by side, at widths 1
and 9, plus pre-A7 Bright at 9). Rows: both windows selected, hover in window 2, select by
clicking in window 2, move mid and end in window 2, deselect in main, select while covered
then uncovered, and after closing window 2. **Every row 0 in both windows.**

**Tabs** (`rows9.tcl`, tabbed interface with two tabs; A7 brightbox and pre-A7 Bright).
Rows: select in tab 1, select all and hover in tab 2, switch back, deselect and reselect,
switch again, set the hover width to 9 in tab 2 (with `build_colors` and a redraw),
deselect there, then back to tab 1 to deselect and reselect. **All 12 rows 0 in both
builds.** The rows are not vacuous: reselecting in tab 1 changes 874 px. The width set in
tab 2 does not reach tab 1, whose box stays at width 1. That is because `build_colors()`
runs for the current context only, and the hover outline's GC behaves the same way. The
box is set beside the hover GC, so the two cannot disagree. There is no GUI control for
`hover_highlight_width`. It is an rc setting, and every tab reads it at creation
(`create_new_tab()` calls `create_gc()` and `build_colors()`).

**User's launch config** (`rows6.tcl`): see INFO above. It covers click select, Shift and
Ctrl click, the `m` stretch with rotate (mid, end, undo), an LMB drag (mid, end), the `c`
copy (mid, end, Escape), the `m` Escape, Delete and undo, property edits on a FET and a
label (grow, shrink), a rubber band (mid, end, hover after), select all with Ctrl-wheel in
and out and a wheel pan, and highlighting a label's net with a FET added.

**The forced cheap drag look** (an instrumented copy with `SEL_DRAG_FRAME_MS` set to 0, so
every drag falls back). The mid-drag rows (`c1`, `c5`, `d1`, `s1`, `s4`) differ from a
redraw because the redraw paints the cheap look and the frame does not. Under the same
instrumentation Bright shows the same rows. Every end-of-drag, Escape and after-drag row
is 0 in both looks, and the A7 box is kept in the cheap look.

**Partial redraws cannot mix looks:** `draw()` calls `sel_style_sync()` only when
`!xctx->bbox_set`, so a bbox-limited redraw keeps the look the rest of the overlay was
painted in.

## Identity (other looks unchanged)

`rows4.tcl` takes 26 poses on two pages: the fixture and `mos_power_ampli.sch` at a fixed
path, because the title block prints the path. Each pose has a selection, hover, select
all, a two-device `m` drag (mid, rotate, Escape) and a rubber band. Each image is compared
by `magick f.png rgb:- | md5sum`.

| A7 look | compared with | dark | light |
|---|---|---|---|
| Classic | base `e6b38ba83` | 26/26 identical | 26/26 identical |
| Bright | pre-A7 Bright | 26/26 | 26/26 |
| Halo | pre-A7 Halo | 26/26 | 26/26 |

The comparison can tell the looks apart: Classic against Bright differs by 946–58579 px,
and Bright against Halo by 1053–125042 px, on the selection poses.

## Exports with a selection

PNG, SVG and PDF, selected and not, in all four looks (`rows3.tcl`):
- **PNG:** pixel md5 `71d7982c…` for all eight.
- **PDF** (rastered with `gs -r60`): `ead34c1b…` for all eight.
- **SVG:** the selected (`c8c67519…`) and unselected (`913f45e9…`) exports differ, because
  base sizes an SVG to the selection's area. Each is identical across the four looks.
- No box reaches any export, and the screen after each export is clean (rows 0).

## FAQ Q94 claims, measured

| claim | result |
|---|---|
| The menu has four entries, Bright with box is the default, and the menu applies the choice at once | **true**: 5 menu rows 0. Bright differs from the start by 1344 px, and Bright with box equals the start. |
| `set selection_style bright` in the rc keeps Bright | **true** for `--script`, `--rcfile` and `~/.xschem/xschemrc` (installed layout) |
| Run from the source tree, xschem reads neither `./xschemrc` nor `~/.xschem/xschemrc` | **true** in every shape I tried: absolute path, relative path, `./xschem`, and the user's own launch `src/xschem --script <repo>/sky130A/cadence_style_rc --logdir …` on `:300`. In each, the default stayed brightbox while both files said `bright`. |
| Installed: the rc file is `~/.xschem/xschemrc` | **incomplete**: `./xschemrc` takes its place when present (LOW above) |
| Typed in the command window, the choice takes effect on the next redraw | **true**: no change before a redraw (AE 0 against the start); after it, the same as the menu's Bright (AE 0) |
| In Halo, text keeps its own colour with a thin band; `selection_text_style colour` gives plain letters | **true**: auto gives own-colour letters with a thin orange outline; `colour` gives plain orange letters (94644 px apart) |
| The box is the hover outline's box, solid, in the selection colour, as wide as `hover_highlight_width` | **true** in code (`sel_box_px` is set from the hover width beside `gc_hover`; `hover_inst_rect()` is shared with `draw_hover_shape()`) and on screen |
| On wires and lines the box does not show | **true at widths 0 and 1 only** (LOW above) |

One extra measurement, not a claim: `--preinit 'set selection_style bright'` also keeps
Bright in the user's launch shape (clean HOME, clean cwd; without it the result is
brightbox). It is an alternative to editing the tracked `<pdk>/cadence_style_rc`, but
`pdk_launcher` builds its own command line, so for launcher users the FAQ's advice is the
practical one.

## Proof that the rows can go red (built broken on purpose, then restored)

A7's code is in `~/gsv7s`. Before any break, `move.o` and `xinit.o` had identical md5s in
`~/gsv7` and `~/gsv7s` (`b97fa586…`, `9a581456…`). The object files reproduce, so they
witness the restore. The binary does not, because of `__DATE__`.

| build | break | runs | rows that went red (baseline is the six rows above) |
|---|---|---|---|
| S1 | `sel_entry_fp()`: `bp = 0` (the box left out of the footprint) | dark w9 | **12 new rows**: c0_sel 315, c1 630, c2 630, c3b 315, c5 630, c5b 186, z7 30, o5 315, o6 242, o12 315, o13 242, te1 60. Two baseline rows also grew: c4 685→1315, p1 3022→3652 |
| S1 | same | dark w1 | **2 new rows**: w3_hw_change_selall 530, w4_hw_change_unselall 318 |
| S2 | `sel_set_clip_rects()`: no `XSetClipRectangles` on `gc_selbox` | dark w9 | **2 new rows**: z6_zoom_out_select 147, te1_text_shrunk 275 |
| S2 | same | light w9, Cadence keys | **3 new rows**: z2_zoom_in_hover 18996, z6 147, te1 275 |
| S2 | same | dark w1 | **1 new row**: z6 11 |

**Restore:** both files were copied back from the pristine copies. Then
`cmp` against `~/gsv7` gave no differences for `move.c`, `xinit.c`, `draw.c`, `callback.c`,
`xschem.h` and `xschem.tcl`. `git diff e6b38ba83 | md5sum` gave `8db50b92…`, which is
A7-combined.patch. After the rebuild, `move.o` was `b97fa586…` and `xinit.o` `9a581456…`,
identical to `~/gsv7`. The forced-cheap instrumentation was restored the same way and gave
the same `move.o` md5.

## Responsiveness (one realistic page, the user's own config)

`zero_opamp.sch` (sky130A) under `sky130A/cadence_style_rc`: 70 instances, 69 wires, fluid
on, crosshair on, hover width 1, display `:300`, 1300×950. Bright and Bright with box were
interleaved over 9 rounds. Each figure is ms per action, including the styled overlay's
idle repair (`update idletasks`) and an X round trip (`winfo pointerxy`).

| action | Bright, median (min–max) | Bright with box, median (min–max) | difference |
|---|---|---|---|
| select all (from nothing, after a full redraw) | 3.30 (2.69–3.97) | 3.41 (2.76–4.94) | +0.11 |
| hover between devices, 3 selected | 0.95 (0.92–1.16) | 1.00 (0.85–1.25) | +0.05 |
| hover between devices, all selected | 1.19 (1.06–1.27) | 1.29 (1.18–1.31) | +0.10 |
| rubber band release | 0.68 (0.43–0.99) | 0.69 (0.43–0.95) | +0.01 |
| drag 1 device, per motion frame | 5.95 (5.86–6.70) | 6.03 (5.99–7.08) | +0.08 |
| drag 3 devices, per motion frame | 7.52 (6.92–8.03) | 7.56 (7.10–8.86) | +0.04 |

Every action is far inside a 60 Hz frame (16.7 ms), and the box adds about 0.1 ms or less.
These figures are on Xvfb, not on the user's X server.

## Public-repo check

I grepped `A7-combined.patch` (2320 added lines) and the FAQ Q94 hunk for the
private-branch feature names and the private repository named in the brief, the words
premium, paid, licen(se) and private, the user's design directory, `/home/`, user names,
e-mail, IP addresses and scratchpad paths. Nothing matched. The only hits for `private`
and `paid` are ordinary English in three code comments: "collects a private copy", "a
private collection" and "paid for that on every layer".

## Registered cases (T1's launch lines, without T1)

T1 itself was not run, because three of its cases start displays outside `:300`–`:309`.
Instead, `t1lite.sh` (in the scratch dir) ran every entry of T1's own `hcases` (137) and
`dcases` (60) lists, using T1's two launch lines from `tests/`:
- **headless:** `env -u DISPLAY … xschem --nogui --pipe -q --script <case>.tcl`;
- **display arm:** `DISPLAY=:300` or `:301`, `xschem --pipe -q --logdir … --script <case>.tcl`.

Each case got a fresh throwaway HOME, and `XSCHEM_DEVDISPLAY_DIR` pointed at an empty
directory so nothing could attach to `:99`. Each case was scored with T1's own
`regression_case_failed` from `tests/banner_rule.tcl`. Three entries were excluded because
they start their own Xvfb: `test_home_isolation`, `test_home_isolation_sh` and
`test_t1_display_arm`.

| tree | headless (134 run) | display arm (60 run) |
|---|---|---|
| A7 (`~/gsv7`) | 133 ok; **red: `test_op_annot`** (2 FAILED, 484 passed) | 59 ok; **red: `test_op_annot`** (2 FAILED, 492 passed) |
| base (`~/gsv7c`) | 134 ok (`test_op_annot` 486 checks) | 60 ok (`test_op_annot` 494 checks) |

Every other case gave the same verdict and the same published check count on both trees:
a diff of the per-case score lines differs only at `test_op_annot`. Each tree printed 14
`^skip:` lines. So apart from the HIGH finding, the batch through A7 changes no
registered case. This is not a T1 verdict: there is no trailer and three cases were
excluded. The driver's own gate is still owed.

## Not covered

- **Real hand input on the user's own screen.** Every gesture here was synthesized
  (`xschem callback`). The look is a pixel deliverable, so it stays the user's to look at.
- `:0` (WSLg) and the user's Windows X server: not used, by the brief's rule.
- **A full T1:** not run. Three registered cases start their own displays outside
  `:300`–`:309`. The other 194 runs (both arms) are reported above, but no T1 trailer
  exists for this tree.
- **Valgrind:** one run only (`rows1` at width 9; memcheck errors, no leak check). A7's own
  receipt reports two more.
- **Not tried:** a non-cairo build, Windows, and widths above 25. `sel_box_px` has no upper clamp, and widths 15 and 25 were clean.
- Hover geometry against pre-A7 was not compared pixel for pixel. It is identical by
  construction (`hover_inst_rect()` is the one function both use), and the hover rows were
  0.

## State left behind

- **Main tree:** the only file I wrote is this receipt. No commits, stashes or pushes
  anywhere.
- **Clones kept, built, for reproduction:** `~/gsv7` (A7), `~/gsv7b` (pre-A7) and `~/gsv7c`
  (base). The untracked `*~.sch` and `untitled*` files my runs left were removed: 46 in
  `~/gsv7` and 46 in `~/gsv7c`, including the suites' `tests/untitled~.sch` and the
  `zero_opamp~.sch` left by each timing run's Escape-cancelled drags (base issue 1716).
  `~/gsv7s` was deleted once its restore had been verified identical to `~/gsv7`.
- **Displays:** Xvfb `:300`–`:303` and their four openbox processes were killed by recorded
  pid, after checking each command line (and each openbox's `DISPLAY`). I never touched
  `:99`, `:270`–`:279`, or anything below `:300`.
- **`/tmp`:** I removed the empty `/tmp/xschem_emergencysave_untitled_cdaeabadgc` left by
  one of my timed-out probes. 19 more `/tmp/xschem_emergencysave_*` dirs (76 KB in all)
  appeared during the registered-case run. Suites leave these just as T1 does, and their
  names cannot be told apart from other agents', so I left them.
- **Scratch** (`…/scratchpad/selA7v/`, about 7 MB): the scripts (`lib.tcl`, `runrows.sh`,
  `rows1`–`rows9.tcl`, `tim.tcl`, `t1lite.sh`, `score.tcl`), every run's `rows.txt` and
  the per-case score files. The images, throwaway homes and case logs were deleted.
- I did not touch the user's design directory or any backup in it.
