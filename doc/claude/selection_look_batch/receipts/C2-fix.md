# C2: a hidden floating text stays hidden when selected; `selection_halo_width` parsed as a number

Crew C, follow-up C2, 2026-11-15. Built and measured in the clone `~/gsc1` on top of stage C
(`dd21e8332`, a scratch commit of C-combined over `e6b38ba83`). Private displays: `:320` only
(Xvfb plus openbox). The main tree carries only this receipt and the patches.

**In plain English.** A text that is hidden on the sheet now stays hidden when you select it,
in every look. Before this, Bright, Bright with box and Halo painted its letters in the selection
colour while it was selected, so selecting a hidden text revealed it. Now the selection shows
only the text's box, the same mark Classic has always used. In Bright with box that box is the
selection box itself, drawn once. When you turn hidden texts on (View > Show hidden texts, or the
annotation switch for an annotation text), the text is drawn and selected like any other text.
Separately, a `selection_halo_width` setting that is not a number (for example `abc` or `5px`)
now gets the default width of 3. Before, a word like `abc` gave no halo at all.

## F-C1: hidden floating texts (coordinator's decision; the user approved the look)

**What changed** (`src/move.c`):

- **`draw_sel_entry()`, `case xTEXT`.** This applies to the glyph pass, the band pass and the
  own-colour pass.
  - When `text_hidden(xctx->text[n].flags, TEXT_CTX_SCHEMATIC)` is true, the text loses
    `SELP_GLYPH`, `SELP_TXTBAND` and `SELP_GLYPHOWN`.
  - In bright and halo the glyph pass draws `SELP_TEXTBOX` in their place. That is classic's
    box, in `gc_sel`, the selection colour.
  - In brightbox it draws nothing, because `sel_box_pass()` has already drawn the selection box
    around the text.
  - "Hidden" is `text_hidden()`'s own answer, the one `draw()` uses: `hide=true` unless
    `show_hidden_texts` is on, and `hide=op` / `hide=voltage` according to `annot_show`'s bits.
    So a text that has been shown again is selected as any text is.
- **`sel_styled_draw()`.** A `sel_flush(xctx->gc_sel)` was added after the glyph pass.
  `drawtemprect(…, ADD, …)` batches, and before C2 nothing in the glyph pass batched. Without the
  flush the box never reached the window (copy K18 below).
- **Unchanged:**
  - Classic.
  - Hidden *instance* texts. These already stayed hidden: the overlay draws instance texts
    through `draw_symbol()`, which asks `text_hidden_inst()`.
  - The erase footprint.
  - The cheap drag fallback (`SELP_CLASSIC`). It already draws every text as classic's box,
    hidden or not, with brightbox's box added, exactly as before C2.

**The erase footprint holds at deep zoom (measured, probe `zp/probe.tcl` in this session's
scratchpad).** The new box is drawn at `gc_sel`'s line width, and that width grows with zoom.
The text footprint is the text's box plus 3 px (plus the band). The overlay's GCs are clipped to
the damaged footprints, so the box cannot leave residue.

Probe: one hidden text, zoomed in 1×, 4×, 16× and 64×, in each styled look. It selected the text,
deselected it, and compared the canvas with a fresh full redraw.

| zoom | line width | px painted while selected (bright / halo / brightbox) | residue after deselect |
|---|---|---|---|
| 1× | 1.3 | 432 / 432 / 432 | 0 in all three looks |
| 4× | 5.2 | 8706 / 8706 / 1742 | 0 in all three looks |
| 16× | 20.8 | 14430 / 15540 / 1110 | 0 in all three looks |
| 64× | 83.2 | 0 / 0 / 0 (the box is off screen) | 0 in all three looks |

Cost: at deep zoom the outer half of the box line is clipped, so it looks thinner than classic's.

**Rows (`tests/headless/test_selection_look_pixels.tcl`, `dcases`, display arm 186 → 190).**

- **Fixture.** It gains `ZZ_TRUE`, a `hide=true` floating text, next to `ZZ_FLOAT_HIDDEN`
  (`hide=voltage`). F1 counts 4 texts.
- **Regions.** They come from classic's own mark:
  - `inner` is the text's box shrunk by 6 px on each side. The letters are there, and no box line.
  - `outer` is the box grown by 6 px.
- **H3a.** Classic marks each selected hidden text with a box wider and taller than 12 px. This
  guards the regions the rows below are built on.
- **H3.** In bright, brightbox and halo, for both hidden texts: 0 px change inside `inner`, the
  whole change lies within `outer`, and every changed pixel is the selection colour. That is
  6 cells.
- **H4.** Brightbox changes fewer px than bright for each hidden text (one box, not the glyph
  pass's box as well). Its third leg reads back that the line width at that zoom is at least
  2 px. At width 1 the two marks are the same pixels, and the row would be red on correct code.
- **H5.** The same texts shown are selected as any text is: something changes inside `inner`, in
  every styled look, for both. `ZZ_FLOAT_HIDDEN` is shown with `annot_show`'s voltage bit.
  `ZZ_TRUE` is shown with `show_hidden_texts`, set the way the menu sets it (the Tcl variable,
  which `draw()` copies into the context, plus `xschem set`).
- **Comments.** The H band comment and the suite header no longer say that the selection-colour
  glyphs are still painted for a hidden floating text. H2 still measures the own colour.

**Red first.** The final suite run against C's sources (`dd21e8332`'s `move.c` and `xinit.c`)
gives `2 FAILED (188 passed)`:

- **H3 is red in all six cells.** On C a selected hidden text changed 1539–3224 px inside its box:
  - in bright and brightbox, antialiased letters in up to 232 colours;
  - in halo, letters in the selection colour.
- **H4 is red** with `{0 0}`.
- **H3a and H5 are green on C**, as expected. H5 guards against hiding too much (copy K17).

On C2 the suite gives `ALL PASS (190 checks)`.

## F-C2: `selection_halo_width`

`src/xinit.c`: a new `static int sel_num(const char *s, double *v)` holds C's own-px parse:
`strtod`, an end check that allows trailing blanks, and finite (`v - v == 0.0`).
`selection_text_own_px` and `selection_halo_width` now both use it.

For the halo width:

- A non-number gives the default 3 (the Tcl default in `set_ne`).
- The existing 0..20 clamp is applied to the double *before* the `(int)` conversion, so `1e9`
  gives 20 and cannot overflow.
- A fraction is truncated toward zero, as `atoi()` did, so `2.6` gives 2.
- `selection_text_own_px` behaves exactly as in C. Rows O8 and O10–O15 are unchanged and green.

**Row W2** (`tests/headless/test_selection_look_plumbing.tcl`, `hcases`, 28 → 29):

| input | `abc` | `5px` | `nan` | `inf` | `1e400` | ` 7 ` | blanks | `2.6` | `-0.5` | `1e9` | `-` | `4 5` |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| W2 expects | 3 | 3 | 3 | 3 | 3 | 7 | 3 | 2 | 0 | 20 | 3 | 3 |
| on C (`atoi`) | 0 | 5 | 0 | 0 | 1 | 7 | 0 | 2 | 0 | 1 | 0 | 4 |

W2 is red on C and green on C2. W1 (empty/0/5/-2/20/21/99 → 3/0/5/0/20/20/20) is unchanged and green.

## Copies broken on purpose

Each copy was built, run, restored, and byte-compared afterwards. Sources and objects were
identical every time (`SRC-RESTORED-IDENTICAL`, `OBJ-IDENTICAL`).

| id | copy | rows that went red |
|---|---|---|
| K16 | brightbox also draws the glyph pass's box (`box = (parts & SELP_GLYPH) != 0`) | pixels H4 (`{0 0 1}`), re-run after H4 gained its line-width leg |
| K17 | hidden read off the flags (`HIDE_TEXT \| HIDE_TEXT_VOLTAGE`), not `text_hidden()` | pixels H5 |
| K18 | the new `sel_flush()` after the glyph pass removed | pixels R bright r04 and r35, R halo r04 and r35, H3, H4 (6 rows) |
| K19 | `selection_halo_width` read with `atoi()` again | plumbing W2 |

## Checks

**Suites:**

| suite | headless arm | display arm (`:320`) |
|---|---|---|
| `test_selection_look_plumbing` (`hcases`) | ALL PASS (29) | ALL PASS (29) |
| `test_selection_look_pixels` (`dcases`) | `RESULT: SKIP (no X: …)`, 0 checks, unchanged | ALL PASS (190) |
| `test_grid_toggle_sel_gc` (`dcases`, not touched, run as a control) | not run (`dcases` only) | ALL PASS (10) |

These are the armed `run_suites.sh` runs:

- headless: `env -u DISPLAY AUDIT_DISPLAY=none GUI_GATE=0`;
- display: `AUDIT_DISPLAY=:320`.

**T1.**

- **No registration changed in C2.** The touched cases were captured in T1's loop shape and
  scored with `summarize_all` lifted from `run_regression.tcl` (all 16 procs) and
  `banner_complete` sourced from `tests/banner_rule.tcl`. Each scored one block of 3 lines,
  `banner_complete=1`, counted 0, skips 0.
- **Against `e6b38ba83`**, the batch delta is still cases +3, blocks +3, counted +0, skips +0,
  `wc -l` +9, with `planned_cases` 201 → 204. That is the same as C.
- **On the main worktree (`c2b467535`)**, `planned_cases` is 203 → 206.

**Health:**

- **Warnings.** A full rebuild (`rm -f *.o && make`) gives 6 warnings, the same six sites as
  base: `actions.c:586`, `util.c:222`, `save.c:7357`, `token.c:1057`–`1059`.
- **Valgrind.** `valgrind -q` (with `env` before `valgrind`) gave 0 lines on both suites, both
  arms: plumbing at 29 checks on each arm, and pixels at 190 checks on the display arm and as a
  self-skip on the headless arm. The display-arm run used the final suite file.

**Timing, C against C2** (`:320`, three alternating rounds per binary, mean ms):

- "redraw" is a full redraw with everything selected, over 20 repetitions.
- "select-all" is an unselect plus select-all, over 10 repetitions.
- Neither page carries a hidden text, so this measures the new check's cost on ordinary texts.

| page (objects selected) | look | redraw C | redraw C2 | select-all C | select-all C2 |
|---|---|---|---|---|---|
| rom8k (219) | bright | 6.1/6.4/6.5 | 6.8/6.5/6.2 | 3.9/4.2/3.9 | 4.0/4.3/3.9 |
| rom8k (219) | brightbox | 6.6/6.9/6.9 | 7.1/6.9/6.8 | 4.3/4.5/4.8 | 4.6/4.5/4.3 |
| rom8k (219) | halo | 6.4/6.7/6.5 | 6.8/6.7/6.7 | 4.0/4.2/4.3 | 4.2/4.4/4.3 |
| intuitive_interface_cheatsheet (6306, 288 texts) | bright | 5.2/5.4/5.2 | 5.3/5.6/5.4 | 6.6/7.0/6.9 | 6.8/6.8/7.2 |
| intuitive_interface_cheatsheet (6306, 288 texts) | brightbox | 6.5/6.8/6.3 | 6.5/6.7/6.7 | 9.7/9.5/9.9 | 9.2/9.4/9.7 |
| intuitive_interface_cheatsheet (6306, 288 texts) | halo | 7.2/7.2/7.2 | 7.3/7.3/7.1 | 8.8/9.2/9.3 | 9.4/8.8/9.2 |

The two builds are within noise of each other, and everything stays under one 60 Hz frame
(16.7 ms).

## Patches

| file | md5 | applies to |
|---|---|---|
| `C2-incremental.patch` | `93798d7ea69f1da528f636b333c4e7bd` | C-combined (`dd21e8332` = `e6b38ba83` + C-combined): checked |
| `C-combined2.patch` | `16b3ff7374c4db32228e0bfe3bf2d24d` | the whole batch including C2, against `e6b38ba83`: checked with a temporary index |
| `C-incremental-on-main.patch` | `cdee35f6e6e9c6f0457fbbef082ff73c` | the main worktree as it stands: checked on a copy |

`C2-incremental.patch` touches `src/move.c`, `src/xinit.c` and the two selection-look suites.
`C-combined2.patch` spans 15 files.

**Main tree: `C-incremental.patch` as filed does NOT apply to it.**
`git apply --check` reports `patch failed: tests/run_regression.tcl:163`. The cause:

- The main tree's HEAD moved to `c2b467535` after the batch base, `e6b38ba83`.
- That commit appended `headless/test_drag_abort_backup_1716` to the tails of both `hcases` and
  `dcases`, the same two lines C appends to.
- The conflict is textual only. The resolution keeps both entries, the 1716 entry first in each
  list.

`C-incremental-on-main.patch` is C-incremental with exactly that resolution. Every other file's
section is byte-identical to `C-incremental.patch`. In `run_regression.tcl` the only changed
lines are which entry loses its closing `]`.

Checked on a copy of the main worktree, with the main tree itself untouched:

- `C-incremental-on-main.patch` applies, and `C2-incremental.patch` then applies on top (rc 0).
- The resulting `src/move.c`, `src/xinit.c`, `src/scheduler.c` and `src/xschem.h` are
  byte-identical to gsc1's files with `git diff e6b38ba83 c2b467535` applied to them.
- The two suites and `xinit.c` are byte-identical to gsc1's.

So C2 lands on the main tree exactly as tested here. That merged tree (C + C2 together with the
1716 drag fix) was not built or run.

## Left alone, as instructed

F-C3 (the `xschem rect` out-of-bounds write) is filed elsewhere. F-C4 is noted only.
