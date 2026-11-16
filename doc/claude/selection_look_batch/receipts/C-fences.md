# Stage C — fences, registration and the small open findings

Crew C, 2026-11-15. Clone `~/gsc1` (16-character path): `e6b38ba83` plus `A7-combined.patch`
(md5 `8db50b9272a724e7c903cee676d6ee3b`, checked before applying), scratch-committed as
`d8846e39b`; this stage is the working tree on top of it. Nothing committed past the scratch
commit, nothing pushed, nothing stashed. The batch commit still waits on the user's look.

Displays: private Xvfb + openbox on `:320` and `:321` only, started and killed by recorded pid.
Every xschem ran with an explicit `DISPLAY=:32x` or under `env -u DISPLAY`, with `GUI_GATE=0`
and a throwaway `HOME`.

## What changed, by item

### 1. Fences, registered in `tests/run_regression.tcl` in the same change

| suite | list | what it fences | headless | display |
|---|---|---|---|---|
| `tests/headless/test_selection_look_plumbing.tcl` (new) | `hcases` | the four settings reaching C | ALL PASS (28) | not registered (every row is headless) |
| `tests/headless/test_selection_look_pixels.tcl` (new) | `dcases` | the looks on screen | `RESULT: SKIP (no X …)`, 0 checks | ALL PASS (186) |
| `tests/headless/test_grid_toggle_sel_gc.tcl` (fixed, extended) | `dcases` | issue 0082 + the selection GCs | uppercase `SKIP:`, 0 checks | ALL PASS (10) |
| `tests/headless/test_op_annot.tcl` (L27/U19 widened) | both, already | — | ALL PASS (486) | ALL PASS (493; 494 with T1's `--logdir`) |

Run times on this machine: plumbing ~0.3 s; pixels ~38 s; grid ~1 s. All three end with
`OVERALL: ok (N checks)` / `OVERALL: ok`, which `banner_complete` accepts (measured, see item 7).
The pixel suite sources `scratch.tcl`, so it arms the watchdog (it pumps with `update`; row W20h's
population). The grid suite issues no `update`/`vwait`/`tkwait`/`toplevel`/`grab`; it sources
`scratch.tcl` for a scratch sheet (item 4), which arms the watchdog too.

**How the pixels are read.** A new test hook, `xschem window_snapshot` (`src/scheduler.c`, before
`windows` in `xschem_cmds_w`): `take <slot>` copies the whole window with `XGetImage` after flushing
cairo and `XSync` (refuses an unmapped window), `diff a b` answers `n x1 y1 x2 y2`, `colors a b`
the colours slot b holds where it differs, most frequent first, `pixels slot x y w h` a list of
`#rrggbb`, `free`. Eight slots. In process, no `xwd`/`import` dependency. And
`xschem get selection_look` reports the context's cache (`style text_style text_own_px halo_px
box_px`) and resolves nothing.

**Plumbing rows** (headless): D1–D3 the Tcl defaults and the C default for own_px agreeing;
S1 the four words; S2 `{}`, `unknownword`, `Halo`, `BRIGHT`, `halo `, ` classic`, `brightbox2`
→ brightbox; S3 unset → brightbox; S4 compare_sch forces classic and lets go; T1 the text-style
table in bright/brightbox/halo; O1–O15 own_px values (item 2); W1 halo width default and clamps;
K1 a bare `set` does not resolve, `build_colors` and `xschem line_width` do; C1–C3 a child
xschem with `--rcfile`: no rc → brightbox, an rc's `bright` (with own_px `abc`) wins and reads 16,
an rc's `halo` wins with own text.

**Pixel rows** (display): F1/F2 fixture and second tab; M1 the menu's four radio entries read off
`.menubar.view.sellook` (type, label, value, variable); M2 default brightbox on both sides; M3
box width = `hover_highlight_width`; M4 each entry invoked with a selection up applies its look
and leaves the canvas equal to a redraw. **R** (41 rows × 4 passes: brightbox at box width 1,
bright, halo, brightbox at box width 9, each with r00 asserting the look in force): select one of
each object, deselect, click on nothing, select-all, unselect-all, rubber band released, hover
on/off a selected FET and text, hover outline then a neighbour selected/deselected, drag mid-move
and ended, Escape, undo, zoom in/out, wheel, pan by command and by middle-drag, property edits that
grow/shrink a label and a floating text, Expose of 30 %/80 %, a selection change while covered,
twelve zoom-ins and fourteen zoom-outs with selects there, the box width changed under a
selection, tab switch both ways with select/deselect in the second tab. Each row: the canvas
equals a fresh full redraw, plus state legs where a row could otherwise pass on a no-op (lastsel,
the moved bbox, Escape restoring it, undo restoring it). **B1** brightbox differs from bright and
only in the selection colour; **B2** that difference has the hover outline's bounding box and every
pixel the dashed hover paints is the selection colour in brightbox; **B3** a wire's and a line's
box does not show at width 1 and does at 3, a FET's shows at both and grows. **C1** classic paints
select-all in layer 2's colour and nothing else, **C2** equals a redraw, **C3** unselect gives back
the unselected picture. **H0** the two hide texts' regions are real and separate; **H1** (each
styled look) the annotator selected, its `hide=op` text's region is unchanged, and once
`annot_show` shows it the overlay does paint it; **H2** halo gives a hidden floating text no
own-colour glyphs, and does the shown one. **O1** halo, a text below 16 px: own_px `abc` draws as
16 does, 0 does not.

Removed during development: a rubber-band **mid-sweep** row. A redraw erases the rubber rectangle,
so the window and a redraw differ there by construction (3326 px in brightbox and bright).

### 2. M1-verify F2 — non-numeric `selection_text_own_px`

`sel_style_sync()` (`src/xinit.c`) now parses with `strtod` and an end-pointer check: a finite
number with surrounding blanks is taken (negative clamps to 0), anything else — empty, `abc`,
`16px`, `nan`, `inf`, `1e400`, `12 13`, `-`, blanks — is the default `SEL_TEXT_OWN_PX`. Rows O1–O15
of the plumbing suite, C2 (the rc door), O1 of the pixel suite.

### 3. M1-verify F3 — the comment above `SEL_TEXT_OWN_PX`

`src/xschem.h` now says only what is recorded: the ladder put the first open counters at 12 px; the
driver judged 12–14 px band text heavy in the composites (worst on the light scheme) and recommended
16; the user approved that (2026-11-15, PLAN.md "Rulings during the batch").

### 4. `test_grid_toggle_sel_gc` — decision: restate AND extend AND register

- Its reason was stale: "draw_selection() strokes the selection with gc[SELLAYER]" is true of the
  classic look only, and the default is now brightbox. Restated: layer 2's GC is shared by the
  grid, the crosshair and the classic look; the styled looks use `gc_sel`/`gc_selhalo`/`gc_selbox`.
  The original rows now run with `selection_style classic` set explicitly (row C0), so they keep
  measuring what they were written for.
- Extended: `xschem get gc_line_style` accepts `sel`, `selhalo`, `selbox` besides a layer; band S
  asserts all three LineSolid across grid on / off / off without axes / on in bright, brightbox and
  halo — the user's "solid" ruling for the box.
- Fixed before registering: it ran `xschem rect 4 0 0 100 100`, whose fifth number is a **position**
  (`xschem rect x1 y1 x2 y2 [pos]`), so it stored the rect at index 100 of an empty array. valgrind:
  invalid writes in `storeobject`; the process printed its banner and then aborted at exit with
  `double free or corruption (!prev)`, rc 134 (three runs). T1 would have scored that red. Now
  `xschem rect 0 0 100 100` on the current rectcolor; clean under valgrind.
- It also left `untitled~.sch` in the directory xschem started in (`tests/` under T1): the
  first edit of the untitled startup sheet writes that backup. It now loads a sheet in its own
  scratch directory first (sourcing `scratch.tcl`, which also arms the watchdog), and row **U1**
  asserts no `untitled*` was added to the start directory (red with the load left out, measured).
- Registered in `dcases` alone.

### 5. `test_op_annot` L27/U19

Widened with a comment each: `move.c` joins the `text_hidden` caller set (sel_text_own_layer()
asks it before repainting a floating text in its own colour) and the `annot_text_layer` set (the
same function picks the colour the plain draw uses). Run from `~/gsc1`: headless ALL PASS (486),
display ALL PASS (493), via `run_suites.sh`. The behavioural row the brief asked for lives in the
pixel suite, since it needs window pixels: **H1** (instance `hide=op` text, each styled look) and
**H2** (floating hidden text, halo own colour). H1 needed the hidden text placed **inside** its
symbol's body: with it outside, symbol_bbox() leaves the hidden text out of the instance's bbox,
the overlay is clipped to that footprint, and a copy whose overlay ignores `text_hidden_inst()`
still passed H1 (measured; 36 residue rows and B1–B3 caught it instead). With the text inside the body
H1 goes red in all three looks on that copy.

### 6. FAQ Q94

(a) Installed xschem: `./xschemrc` in the launch directory when there is one, else
`~/.xschem/xschemrc` (read from `Tcl_AppInit`'s rc block in `src/xinit.c`; `--rcfile` overrides
both). Source-tree `--script` advice kept. (b) The wire/line box: at the default width 1 it does
not show, at 3 or more it shows as a band — row B3 measures exactly those two widths (width 2 also
measured 0 px on this fixture's zoom, so the FAQ names only 1 and 3+).

### 7. T1 delta (derived, no full T1)

Relative to `e6b38ba83`. Method as CLAUDE.md asks: every top-level proc of the clone's
`tests/run_regression.tcl` lifted (16), `tests/banner_rule.tcl` sourced, the arm's HARNESS rule
applied, `summarize_all` run over each suite's output captured in that arm's own shape (cwd
`tests/`; `env -u DISPLAY … --nogui --pipe -q --script` for `hcases`; `--pipe -q --logdir <dir>
--script` on a display for `dcases`; throwaway HOME).

| case | arm | rc | banner_complete | counted | `^skip:` | block lines |
|---|---|---|---|---|---|---|
| `test_selection_look_plumbing` | hcases | 0 | 1 | 0 | 0 | 3 |
| `test_selection_look_pixels` | dcases | 0 | 1 | 0 | 0 | 3 |
| `test_grid_toggle_sel_gc` | dcases | 0 | 1 | 0 | 0 | 3 |
| `test_op_annot` (changed, registered already) | hcases | 0 | 1 | 0 | 5 | 8 (486 checks) |
| `test_op_annot` | dcases | 0 | 1 | 0 | 0 | 3 (494 checks) |

Unregistered arms, captured for completeness: pixels `--nogui` → `RESULT: SKIP (no X …)` +
`OVERALL: ok (0 checks)`, banner_complete 1; grid `--nogui` → `SKIP:` + `OVERALL: ok`,
banner_complete 1. Neither prints a lowercase `skip:`.

**Delta: `cases` +3, `blocks` +3, `counted_failures` +0, `skips` +0, `wc -l` +9,
`planned_cases` 201 → 204** (lists evaluated out of the file's own text: tcases 3, hcases
137 → 138, dcases 60 → 62, + xschemtest). `test_op_annot` moves no term: its rows changed
expectation, not shape. Elapsed grows by about the pixel suite's ~38 s plus ~1 s.
Meta-fences over registration run headless and green: `test_registered_banner_1626` ALL PASS
(10; "157 registered entries" resolve and carry a banner), `test_suite_watchdog_1403` ALL PASS
(40; W20h "all 60 of 157 registered cases that reach the event loop arm one").

### 8. Health

- `rm src/*.o && make -C src`: **6 warnings**, the base's six (actions.c 586, util.c 222,
  save.c 7357, token.c 1057–1059), none in a file this stage touched.
- valgrind -q, `env` before `valgrind`: plumbing `--nogui` 0 lines (ALL PASS 28; its child
  xschems are not traced); pixels `--nogui` 0 lines; grid `--nogui` 0 lines; pixels on `:320`
  **0 lines, ALL PASS (186)**; grid on `:321` **0 lines, ALL PASS (10)**.
- Final armed runs: `run_suites.sh --nogui` (AUDIT_DISPLAY=none) plumbing PASS 28, the other two
  skipped; `run_suites.sh` on `:320` all three PASS (28 / 186 / 10).

## A product fix this stage made: `xschem setprop text` under brightbox/halo

Row r25 at box width 9 (a selected floating text grown back by `xschem setprop text … txt_ptr`)
left **572 px** of residue. The arm marked the text's OLD footprint as overlay damage but not the
new one, and the redraw is clipped to the union of the two `text_bbox()`es, which the box (and
halo's band) reach past. `xschem setprop text` now marks the new footprint too, after the change
(`src/scheduler.c`, the `text` arm of `setprop`). The GUI's Edit Properties path
(`edit_text_property()`) ends in a full `draw()` and is not affected.

## Broken on purpose

Each copy: one edit to the pristine file, `make -C src`, the suites named, then the pristine file
copied back. P = plumbing (headless), X = pixels (`:320`), G = grid (`:321`). Driver and edit
table: the session scratchpad's `selC/bop/` (`breaks.py`, `drive.sh`).

| id | copy | red rows |
|---|---|---|
| K1 | brightbox's box left out of the erase footprint (`sel_entry_fp()`, `bp = 0`) | X 12: brightbox r35/r36 (width changed to 9), brightbox-w9 r01 r03 r04 r05 r06 r12 r14 r24 r25 r34 |
| K2 | Tcl default `set_ne selection_style halo` | P 3: D1 D2 C1; X 1: M2 |
| K3 | C fallback (unset/unknown/`brightbox` itself) → halo | P 7: D2 S1 S2 S3 S4 T1 C1 |
| K4 | `gc_selbox` not given the repair clip (`XSetClipRectangles` dropped) | X 2: brightbox-w9 r24 r25 |
| K5 | unknown word no longer falls back (→ classic) | P 6: D2 S1 S2 S3 S4 C1 |
| K6 | `selection_text_own_px` read with `atof()` again (F2) | P 8: O8 O10 O11 O12 O13 O14 O15 C2; X 1: O1 |
| K7 | `sel_text_own_layer()` ignores `text_hidden()` | X 1: H2 |
| K8 | the overlay's symbol-text loop (`draw_temp_symbol()`) ignores `text_hidden_inst()` | X 38: H1 in all three looks, B1 B2 B3, and 32 residue rows over all four passes |
| K9 | `gc_selbox` dashed | G 3: S bright, S brightbox, S halo; X 0 |
| K10 | classic painted as bright (`sel_style_eff()`) | X 1: C1 |
| K11 | the menu's Halo entry carries value `hallo` | X 2: M1 M4 |
| K12 | `xschem setprop text` without this stage's new-footprint mark | X 1: brightbox-w9 r25 |
| K13 | `sel_box_px` stuck at 1 | X 1: brightbox-w9 r00 |
| K14 | compare_sch no longer forces classic | P 1: S4 |
| K15 | the instrument: `window_snapshot diff`/`colors` find no differing pixel | X 10: B1 B2 B3 C1 H0 H1×3 H2 O1 |

Restore, measured twice: `md5sum src/*.c *.h *.tcl` identical to the pre-sweep record; every
`.o` byte-identical except `scheduler.o`, and that one only because `scheduler.c` embeds
`__DATE__ " : " __TIME__`: two rebuilds of identical source differ in `objdump -d` by exactly one
`movabs` immediate holding the time string. A third, single-copy sweep (K9 against the final
grid suite) restored with every `.o` identical.

The H band's fixture was moved once during the sweep. In the first round the annotator's hidden
text sat outside its symbol's lines, and K8 left H1 green (39 other rows red: 36 residue, B1–B3): symbol_bbox() leaves a
hidden text out of the instance's bbox, and the overlay is clipped to that footprint. With the text
inside the body, K8 reddens H1 in every look. Every X copy was re-run against the moved fixture
(the table is that round); K3, K5, K14 touch only P.

## Findings not fixed (for the driver)

- **F-C1 — a selected hidden floating text shows in every styled look.** The GLYPH and TXTBAND
  passes (`draw_temp_string_parts()` from `sel_styled_draw()`) do not ask `text_hidden()`; only
  `sel_text_own_layer()` does. Selected while hidden (select-all or a rubber band reach it), on
  this fixture: `hide=voltage` text — classic 1506 px, all layer-2 grey (its bbox box, upstream
  behaviour); bright 3416 (the letters, selection colour); brightbox 4132 (letters + box); halo
  3509 (the band around the letters). `hide=true`: 1734 / 3931 / 4746 / 3965. Instance texts
  stay hidden (H1). Whether a selected hidden text should show its letters, its box, or nothing is
  a look decision, so it is reported, not fixed; H2 and H1's names claim only what they measure.
- **F-C2 — `selection_halo_width` still uses `atoi()`**: `abc` → 0 (no band), `5px` → 5. Same
  fix shape as F2 if wanted.
- **F-C3 — `xschem rect x1 y1 x2 y2 pos` with `pos` past the array end writes out of bounds**
  (`storeobject()`), pre-existing and not this batch's code; found through the grid suite's old
  `xschem rect 4 0 0 100 100`. Not filed.
- **F-C4 — `xschem set annot_show` alone leaves instance bboxes stale** until `xschem
  update_all_sym_bboxes`, so a newly shown instance text is clipped out of its selection overlay.
  The Simulation menu pairs the two; the suite mirrors the menu. Pre-existing, noted only.
- The Escape-aborted drag (r14) writes `fix~.sch` beside the fixture (issue 1716); it lands in the
  suite's scratch directory and goes with it.

## Not covered

- A rubber band **mid-sweep** (a redraw erases the rubber rectangle by construction).
- Classic is fenced by colour (C1), redraw equality (C2) and unselect restoring (C3), not compared
  with `e6b38ba83`'s own rendering (that needs a base build).
- Thin spots the sweep measured: K4 reddens only r24/r25 at box width 9; K9 only the grid suite
  (the hover outline it is compared with in B2 dashes the same way); K13 only r00 at width 9,
  since the GC's width is set separately from the `sel_box_px` cache.
- The light colour scheme (dark is pinned); `:0` and the user's screen (the batch's look debt
  stays the user's); `test_home_isolation` (its fixtures start Xvfb outside `:320–:329`; the three
  suites are "inside" by G2's rule — each sources `scratch.tcl` and calls `xschem` — and the
  plumbing suite's one launcher spells `[info nameofexecutable]`); `test_op_annot` under
  valgrind; a full T1.
- Measured on Xvfb + openbox 3.6.1, 1920x1080x24. Pixel rows compare captures with each other,
  never with stored images.

## Patches

- `C-incremental.patch` — this stage on top of `A7-combined.patch` (`git diff d8846e39b`, new files
  intent-to-add): md5 `e86bbc4eccd267684eb7e9be660b4806`, 9 files.
- `C-combined.patch` — the whole batch against `e6b38ba83`: md5
  `b36d19c97d5c15c2ae57a02463810edf`, 15 files.
- `git -C /home/analog/dev/xschem-claude apply --check C-incremental.patch` → **rc 0** (check only,
  against the main tree as it stands). Also checked into temporary indexes: combined on
  `e6b38ba83` rc 0, incremental on `d8846e39b` rc 0.
- Both patches and this receipt scanned for the words the brief keeps out of the public tree: none.

## State left

- `~/gsc1`: scratch commit `d8846e39b` plus this stage in the working tree (the two new suites
  intent-to-add), built. No `*~.sch` or `untitled*` left by these runs.
- `:320` and `:321` (Xvfb + openbox) killed by recorded pid after checking each cmdline. The two
  Xvfb servers had inherited `DISPLAY` in their environment; a server connects to nothing.
- Main tree: only this receipt and the two patches written.
- Scratch trimmed (throwaway homes removed); sweep logs, captures and probes kept under
  `selC/` in the session scratchpad.
