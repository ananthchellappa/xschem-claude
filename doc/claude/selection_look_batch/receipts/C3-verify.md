# C3 verify: the look fences, C2's hidden-text fix, `window_snapshot pixels` (adversarial)

- **Date:** 2026-11-15
- **Verifies:** C3 (`receipts/C3-fix.md`, patch `receipts/C3-incremental.patch`, md5
  `fada9a0ddaedfb52f02e08f0c162793c`, checked before applying) and C2 as committed in
  `f039113c5` (`receipts/C2-fix.md`), which had had no independent check.
- **Trees:**
  - `~/gsv9`: a fresh clone at `f039113c5` with `C3-incremental.patch` applied (`git apply
    --check`, then apply; only `src/scheduler.c` and the pixel suite change; `git diff` equals
    the patch apart from the blob hashes on the `index` line). `./configure && make -C src`:
    6 warnings, the base's six sites, no new one. Kept, built.
  - `~/gsv9s1`..`~/gsv9s3`: copies of `~/gsv9` for the broken-on-purpose builds. After every
    run the six edited sources were `cmp`-identical to `~/gsv9` again; then deleted.
  - `~/gsv8` (stage C, pre-C2) and `~/gsv7c` (base `e6b38ba83`): binaries used read-only.
- **Displays:** Xvfb + openbox on `:333`–`:336` only, started by me, killed by recorded pid
  after checking each cmdline and each openbox's `DISPLAY`. Every xschem had an explicit
  `DISPLAY=:33x` under `env -u DISPLAY`, or none. Every run had a throwaway HOME.

## Verdict

**SAFE WITH LIMITS.**

- **HIGH-1 is answered.** All seven builds that slipped through last round are now red, as
  C3's table says, and so is everything else from my original thirteen that changes the
  screen. V10 is now red in 18 rows. V11 stays green, as before, because it changes nothing.
- **Two new builds that change the screen pass all three suites** (LOW-1). The new look rows
  test in one direction only.
- **C2 is correct for what it covers.** Every look leaves no residue and Classic is
  byte-identical to base. The new flush costs nothing, and the halo-width parse is clean under
  valgrind.
- **C2's rule stops short of one case** (MEDIUM-1). A text whose *layer* is switched off (View
  > Show > Visible layers) is revealed when selected, in every styled look including the
  default. Classic shows only its box. This is the same kind of defect as the hidden texts C2
  fixed.
- **`window_snapshot pixels` is clean.** Valgrind reports 0 errors over 51 calls, 47 of them
  `pixels` with hostile arguments, and `--nogui` refuses cleanly.

## (1) The broken-on-purpose builds against `f039113c5` + C3

Method, as last round: one edit per build on a pristine copy, then `make -C src`. Then the
plumbing suite (headless), the pixel suite and `test_grid_toggle_sel_gc` on a private display,
and the red rows read off. In every red run the failed and passed rows add up to the full count
(197 / 29 / 10), so no band aborted. Three builds ran at a time, one per display.

### The original thirteen

| build | what it breaks | red rows (pixel suite unless named) | screen changed last round |
|---|---|---|---|
| V1a | brightbox box = the instance's raw bbox | B2, B4 | yes |
| V1b | box ignores the label case (xx1..yy2) | **B4** | 328 px |
| V2 | no repair mark on deselect | 16 R rows (r02, r11, r30, r40 × 4 looks) | yes |
| V3 | menu values bright/brightbox swapped | M1, M4 | yes |
| V4 | `draw()` does not call `sel_style_sync()` | **L4** | 1279 px |
| V6 | dark default = the grid's grey `#4f4f4f` | **L1, L2, L3** | 7220–9377 px |
| V7 | bright/brightbox draw a text as a box | **B4, H5, L2** | 8112 px |
| V8 | halo band stroked with `gc_sel` (hidden under the object) | **L3** | 5202 px |
| V10 | `take` reads the backing pixmap, not the window | 18 rows: B1–B4, C1, C4, H1×3, H3a, H3, H4, H5, O1, L1–L4 | (hook) |
| V11 | erase pad without the halo width | none | none (measured last round) |
| V12 | setprop marks only the new footprint | R brightbox-w9 r24 | yes |
| V14 | classic draws no text box | **C4, H3a, H3, H5, L2, L3** | 2844 px |
| V16 | `selection_color` ignored | **L1** | 8471 px |

The rows in bold are what C3 added (C2's H rows already caught some of these).
C3's receipt lists the same red rows for V1b, V4, V6, V7, V8, V14 and V16. C3 did not rebuild
V10. Here the R band is still blind under V10, because every R row compares two captures that
both come from the pixmap. But the suite is red in 18 other rows.

### Eleven more builds, aimed at the new rows

| build | what it breaks | pixel | plumbing | grid | screen change |
|---|---|---|---|---|---|
| V6L | light default = grey `#aaaaaa` | L1 | ok | ok | — |
| V7b | bright/brightbox draw a box AND letters, all texts | B4 | ok | ok | — |
| **V7c** | bright adds classic's box around a selected floating text's letters | **ALL PASS** | ok | ok | **1426 px** |
| V8b | halo band twice as wide (`lw + 4w`) | **ALL PASS** | ok | ok | **2715 px (FET), 2120 px (wires)** |
| V8c | halo band half as wide (`lw + w`) | L3 | ok | ok | — |
| V9 | brightbox box stroked with `gc_sel` | B2, B3, B4, H4 | ok | ok | — |
| V13d | brightbox box dashed 4/4, like the hover outline | **ALL PASS** | ok | S bright, S brightbox, S halo | — |
| V14b | classic's text box 2 px bigger | L2 | ok | ok | — |
| V14c | classic's text box shifted 5 px, same size | R bright r04/r05/r35/r36, L2 | ok | ok | — |
| V17 | bright strokes a selected wire in grey | R bright r03/r05/r12/r36, B3 | ok | ok | — |
| V1c | brightbox box filled | B2, B3, H1 brightbox | ok | ok | — |

I measured the screen change for V7c and V8b against `~/gsv9`'s own captures of the same poses
(`import`, `magick compare -metric AE`). Every other pose was AE 0. Cropped side by side, V7c is
bright with a box around "floating note", which is brightbox's look for a text. V8b is halo with
a visibly doubled band.

## (2) The new rows, looked at for vacuity

### LOW-1: L2 and L3 test in one direction only (V7c, V8b pass)

- **L2** checks two things. Inside the text's box shrunk by 2 px, nothing that was background
  changes. Inside the box shrunk by 4 px, some letter pixels turn exactly `#ff8000`. The shrink
  leaves out the box edge on purpose. So "letters, not a box" is measured as "letters, and no
  paint on the background inside the box". A build that draws the letters **and** classic's box
  (V7c) passes.
  - Suggested leg: in bright, the ring of pixels on classic's box outline does not change. In
    brightbox it changes, in the selection colour.
- **L3** asks that a halo wire's change be at least 7 px tall. There is no upper bound, and W1
  and W2 check only the resolved number, not the GC. So a band twice as wide as configured
  (V8b) passes.
  - Suggested leg: change height ≤ stroke + 2 × `halo_px` + 2.

### LOW-2: a dashed box in phase with the hover outline passes B2 and B4 (V13d)

- B2 asks two things. The box shares its bounding box with the hover outline. And every pixel
  the dashed hover paints is the selection colour in brightbox.
- B4 asks only the first, with no coverage leg.
- A box drawn with the hover's own dash pattern, in phase, satisfies both. Only
  `test_grid_toggle_sel_gc`'s line-style readback catches V13d. That suite is in `dcases`, so T1
  still goes red.
- Suggested leg for B2: the gap pixels of the hover dash on the box ring are also the selection
  colour.

### LOW-3: C4 measures classic's box against itself

C4 takes the changed area as the box and checks it is an outline. So C4 cannot see a box of the
wrong size (V14b) or in the wrong place (V14c). Those reddened through L2, whose regions come
from that box, and V14c also through R bright rows. C4's claim ("a selected text is a box
outline") is accurate. The box's geometry is fenced only indirectly.

### Checked and not vacuous

- **L4 does not match the menu path by construction.** `look_now` reads `xschem get
  selection_look`, which reports the cache and never resolves it (its own comment says so, and
  the code agrees). The typed path is `set` plus `xschem redraw`, with no `build_colors`. The
  third leg (`diff 4 6 > 0`) shows that the comparison can see a look that did not change. V4 is
  red only in L4. The menu itself is driven by M4, which invokes the real entries.
- **Fixed colours.** L1–L3 hard-code the C defaults (`#ff8000` dark, `#e05a00` light). A user
  rc cannot move them in these runs: run in-tree, xschem sources neither `./xschemrc` nor
  `~/.xschem/xschemrc` (`xinit.c`), and the suite pins the dark scheme before its first row. A
  shipped `src/xschemrc` that set `selection_color` would turn L1 red. It would not make L1
  vacuous. L2 and L3 repeat `#ff8000` instead of reusing L1's measured colour, so a deliberate
  change of the default means editing three rows.
- **S1** is red on the pre-C3 parse (build `S1x`, `atoi` sums: `1 FAILED`, S1 only).
- **Empty-region guard.** Under V14 the suite now reports `6 FAILED (191 passed)`, all 197
  rows. Under V10 it reports `18 FAILED (179 passed)`. No run aborted.
- **Registration.** C3 does not touch `run_regression.tcl`. The touched cases were scored in
  T1's loop shape with `summarize_all` (16 procs lifted) and `banner_complete` from
  `tests/banner_rule.tcl`. The results:
  - plumbing (`hcases`): `ALL PASS (29)`, `banner_complete=1`;
  - pixel (`dcases`): `ALL PASS (197)`, `banner_complete=1`;
  - pixel, headless: `SKIP (no X …)`, `banner_complete=1`;
  - 0 counted, 0 skips, `planned=206` (3 + 139 + 63 + 1) on this tree.
- **Determinism.** 9 runs of the pixel suite at 197 checks, all `ALL PASS`:
  - three at a time on three displays, twice (43.4–43.9 s);
  - three at a time under 24 CPU burners on 20 cores (48.6–48.9 s, load average 16).

## (3) C2, attacked

### MEDIUM-1: a text on a layer switched off is revealed when selected (all styled looks)

- **Setup.** View > Show > Visible layers: unticking layer 3 (TEXTLAYER) runs `xschem
  enable_layers; xschem redraw`. `draw()` then skips every text on that layer: the
  `enable_layer[textlayer]` check in its floating-text loop, and the same check for instance
  texts.
- **What C2 tests.** C2's arm in `draw_sel_entry()` tests only `text_hidden()`. The overlay's
  instance-text path tests only `text_hidden_inst()`. C2's own comment calls these texts "a
  text draw() does not paint", but `draw()` has two more gates: `enable_layer` and
  `draw_single_layer`.
- **Measured** on the fixture with layer 3 off: pixels inside the text's own area (classic's
  box shrunk by 6 px) that change when it is selected.

| selected | classic | bright | brightbox | halo |
|---|---|---|---|---|
| floating note (inner region) | 0 | 2214 | 2214 | 2470 |
| M1, pixels of layer 3's text area | 5 | 1341 | 1341 | 1339 |
| R1, same | 5 | 757 | 757 | 753 |

- **What it looks like.** In brightbox, a capture shows "floating note", "D", "5u/0.18u/1" and
  "M1" in orange. Classic shows only boxes. Halo puts its band around the invisible letters,
  because `sel_text_own_layer()` returns -1 for the glyphs but the band is not gated.
- **History.** Stage A had this too, so it is not a C2 regression. It is a gap in C2's scope,
  and it is in the default look. Classic with the layer off is byte-identical to base (below).
- **Possible fix.**
  - Floating texts: gate C2's arm on the same answer `draw()` uses. `sel_text_own_layer(n) < 0`
    is exactly "`draw()` does not paint this text", including `text_hidden()`.
  - Instance texts: skip a text whose layer is disabled in the styled passes of the overlay's
    symbol path.
  - Not built or tested here.

### C2's hidden-text arm in all four looks (probe `hid_probe.tcl`)

Four hidden texts: `hide=true` (ZZ_TRUE), `hide=voltage` (ZZ_FLOAT_HIDDEN), and two I added.
ZZ_ROT is `hide=true`, rotated and flipped. ZZ_FONT is `hide=true` with a custom font and
weight.

- **Not shown.** In every look, 0 changed pixels inside the text's box shrunk by 6 px. Exactly
  one colour is painted: classic `#4f4f4f`, styled `#ff8000`. The selected window equals a fresh
  redraw, and an unselect restores the unselected picture with 0 residue.
  - Changed pixels for ZZ_TRUE: classic 799, bright 803, halo 803, brightbox 402.
  - Brightbox draws only its own box, at `hover_highlight_width` 1, so it changes fewer pixels.
- **Shown** (`show_hidden_texts` 1, `annot_show` voltage bit). Classic changes 0 pixels inside
  the box; it draws the box only. Bright and brightbox: 1566 / 3208 / 398 / 1846. Halo: 1068 /
  2549 / 332 / 1005. So letters appear, and the selected window equals a redraw every time.
- **Toggled while selected.** Two hidden texts plus the FET were selected. Then hidden texts
  were shown and hidden again with a redraw, then `xschem set show_hidden_texts 1` was applied
  to the C side only (no redraw, so the pixmap still hides them), then everything was
  unselected. Every step equals a fresh redraw, and the unselect leaves 0 residue (bright,
  brightbox, halo).
- **Mid-drag** (`m`, four motions, then a capture). The hidden text shows only its box: 803 /
  402 / 803 px, one colour, 0 inside. A shown text moves as letters. Escape leaves 0 residue.
  The drag stayed in the styled look, not the cheap fallback.
- **Rotate and flip while selected.** Both equal a redraw. (`xschem undo` from a script does not
  redraw, so the window keeps the rotated text. That happens on base too: the capture md5s are
  identical between `~/gsv7c` and `~/gsv9`. It is not a selection-look matter.)
- **Classic identity.** 16 Classic captures of hidden texts are byte-identical (pixel md5)
  between base `~/gsv7c` and `~/gsv9`. They cover each hidden text and `zz1`, select-all, and
  select-all with layer 3 off, both with hidden texts not shown and shown.

### The `sel_flush()` after the glyph pass: cost and correctness

- **Cost by construction: nothing when there is nothing to flush.** `sel_flush()` is three
  `END` calls. `drawtemparc`, `drawtemprect` and `drawtempline` each guard `END` with
  `&& i`, so they make no X request when nothing was batched. Before C2 the glyph pass never
  batched anything.
- **Measured** on a 600-text page with 300 `hide=true`, everything selected. Stage C
  (`~/gsv8`) against C2 (`~/gsv9`), three alternating rounds, `:336`:

| look | hidden texts | redraw, C (ms) | redraw, C2 (ms) | select-all, C (ms) | select-all, C2 (ms) |
|---|---|---|---|---|---|
| bright | not shown | 2.69 / 2.70 / 2.88 | 2.16 / 2.22 / 2.34 | 0.89 / 0.95 / 0.95 | 0.94 / 0.90 / 0.91 |
| bright | shown | 3.05 / 3.07 / 3.44 | 3.21 / 3.26 / 3.30 | 0.86 / 0.88 / 0.96 | 1.00 / 0.86 / 0.92 |
| brightbox | not shown | 2.87 / 2.95 / 3.27 | 2.27 / 2.30 / 2.49 | 1.67 / 1.70 / 1.92 | 1.66 / 1.62 / 1.73 |
| brightbox | shown | 3.42 / 3.49 / 3.56 | 3.45 / 3.49 / 3.67 | 1.73 / 1.62 / 1.61 | 1.63 / 1.71 / 1.74 |
| halo | not shown | 2.57 / 2.58 / 2.73 | 1.99 / 2.13 / 2.14 | 0.85 / 0.90 / 0.86 | 0.83 / 0.85 / 0.84 |
| halo | shown | 3.06 / 3.14 / 3.15 | 3.07 / 3.08 / 3.21 | 0.89 / 0.89 / 0.89 | 0.86 / 0.84 / 0.87 |

  - With hidden texts on the page, C2 redraws about 0.5 ms faster, because a box is cheaper
    than glyphs.
  - With hidden texts shown, the two builds are within noise of each other.
  - Everything is far under one 60 Hz frame.
- **Correctness.** The temp-primitive buffers are static and shared by every GC, and a batch
  is drawn with whichever GC flushes it. The hidden boxes are batched under `gc_sel` and
  flushed with `gc_sel`. The flush comes after brightbox's box pass (which flushes its own GC
  first) and before the own-colour pass (which uses the per-layer buffers, not the temp ones).
  Removing the flush reddens 6 rows (C2's K18).
- **My own builds:**
  - C2x1 (the band kept for a hidden text): red at H3.
  - C2x3 (no mark at all in bright and halo): red at H3 and H4.

### `sel_num()` edge cases (probe `num.tcl`, under valgrind, `--nogui`, 0 errors)

| input | halo_px | text_own_px | note |
|---|---|---|---|
| `0x10`, `0X14`, `0x1p3` | 16, 20, 8 | 16, 20, 8 | `strtod` reads hex and hex floats (INFO) |
| `0x`, `5e`, `1e`, `e5`, `--5`, `5 5`, `1,5`, `1_000`, `0b101` | 3 | 16 | default |
| `\t5\n`, `\v5`, `\f5\r`, `+5`, `5.` | 5 | 5 | blanks either side are allowed |
| `.5`, `0.0000001` | 0 | 0.5, 1e-07 | truncated toward zero, as `atoi()` did |
| `1e-400`, `-1e-400`, `-0` | 0 | 0, -0, -0 | `-0.0` is not `< 0.0`, so it stays `-0` (harmless, INFO) |
| `infinity`, `-inf`, `NaN(1)`, `nan(0x1)` | 3 | 16 | rejected as not finite |
| `1e308`, `9e18`, `2147483648` | 20 | as typed | clamped before the cast; no overflow |
| `1e309`, `-1e309`, 400 nines | 3 | 16 | overflows to inf, so the default (INFO: `1e308` gives 20, `1e309` gives 3) |
| `-1e9`, `-2147483649` | 0 | 0 | |
| `20.9999`, `20.5` | 20 | as typed | |
| 400 zeros then `7` | 7 | 7 | |
| `٥`, `5\0`, NBSP before or after, ` ` before | 3 | 16 | not ASCII digits or blanks: the default |

`strtod` depends on the locale, and xschem never calls `setlocale`. Only C and POSIX locales
are installed here, so a comma-decimal locale could not be measured. Not worth a change.

## (4) `window_snapshot pixels` under valgrind (probe `ws_hostile.tcl`)

`valgrind -q --error-exitcode=99` on `:336` returned rc 0, with no `==` lines, over 51 calls
(47 of them `pixels`):

- **Accepted.** x, y, w and h at `INT_MAX` and `INT_MIN` in every combination whose sums stay
  in range, such as `INT_MIN + INT_MAX`, `0 + INT_MAX` (a full row of 1110) and `INT_MIN + 1`.
  These are accepted and clipped. A negative or zero w or h answers an empty list.
- **Refused with the two-term error.** x + w past `INT_MAX` or below `INT_MIN`, and the same
  for y + h.
- **Refused with the integer error.** These inputs:
  - ints and longs out of range;
  - 400 digits;
  - `a`, empty, a blank, a trailing blank;
  - `0x10`, `1.5`, `1e3`, `nan`, `inf`;
  - a value with an embedded NUL;
  - a non-ASCII digit;
  - a lone `-`.
- **Accepted as decimal.** A leading blank, `+5` and `010` (read as 10). Harmless.
- **Ignored.** Extra arguments after h. Harmless (INFO).
- **The whole window.** `pixels 0 0 0 100000 100000` answers 769230 values, which is
  1110 × 693. Then `take 1`, `diff`, `free`; after `free` the slot holds no capture.
- **Under `--nogui`.** A clean "no X server connection" error, also valgrind-clean.

## Housekeeping

- **Displays.** `:333`–`:336` were killed by pid. `~/gsv9s1`–`~/gsv9s3` were deleted after
  their sources were `cmp`-identical to `~/gsv9`. `~/gsv9` is kept, built.
- **Litter.** No `*~.sch` or `untitled*` was left in `~/gsv9`. None of my runs left a
  `/tmp/xschem_emergencysave_*`: the ones from this hour are another session's `bandgap` and
  `untitled` sheets, so I left them alone.
- **Main tree.** This receipt is the only file written there.
- **Public safety.** `C3-incremental.patch`, `C3-fix.md`, `C2-fix.md` and the batch files
  committed in `f039113c5` carry no private repository name, premium feature name or private
  design path. `CREW_BRIEF.md` is not committed.
- **Probes and logs** are in the session scratchpad, under `selC3v/`.
