# C4 verify: draw()'s shared predicates, MEDIUM-1, the tightened L2/L3 (adversarial)

- **Date:** 2026-11-16
- **Verifies:** C4 (`receipts/C4-fix.md`, patch `receipts/C4-incremental.patch`, md5
  `2308af70fb87d8237c6a152fb1202acf`, checked before applying) on `720c20e2e`.
- **Trees:**
  - `~/gsv10`: a fresh clone at `720c20e2e` with the patch applied (`git apply --check`, then
    apply). Five files change: `src/draw.c`, `src/move.c`, `src/xschem.h`, the pixel suite and
    `test_op_annot.tcl`. `./configure && make -C src`: 6 warnings, the same six sites as the
    base.
  - `~/gsv10b`: a fresh clone at `720c20e2e`, the base for every `draw()` comparison.
  - `~/gsv10n`, `~/gsv10bn`: the same two trees built without cairo (`HAS_CAIRO 0`, `HAS_XCB 0`
    in the generated `config.h`, then a full rebuild; `ldd` shows no cairo). 6 warnings each.
  - `~/gsv10s1`..`~/gsv10s4`: copies of `~/gsv10` for the broken-on-purpose builds.
- **Displays:** Xvfb + openbox on `:330`–`:338` only, started by me, killed by recorded pid
  after checking each cmdline and each openbox's `DISPLAY`. Every X client (xschem, `import`)
  ran under `env -u DISPLAY` with an explicit `DISPLAY=:33x`, or with none. Every run had a
  throwaway HOME and `TMPDIR` in my scratch.

## Verdict

**SAFE WITH LIMITS.**

- **`draw()` paints what it painted before.** 5624 window hashes over 38 pages and 74 states
  each, both themes, cairo build: all equal to the base. 4144 more on the no-cairo pair: all
  equal. PNG, SVG and PDF export: identical (PDF after rasterising, since its bytes carry a
  random `/ID` that differs between two runs of the same build too).
- **The title block is not a finding.** It prints the sheet file's modification time and a path
  that depends on which tree the sheet sits in. The crew's two clones were checked out one
  second apart. Measured both ways: proven below.
- **The split costs nothing measurable.** Five pages from 86 to 3200 instances; redraw, zoom,
  pan, layer off, single layer and all-selected, at two zooms; six interleaved rounds. Every C4
  median is within the base's run-to-run spread. One apparent 14% on the first page loaded did
  not reproduce at N = 40.
- **MEDIUM-1 is closed except in one corner** (LOW-1). Over 180 states of one instance's texts,
  the base reveals what `draw()` hides in all 91 hidden states; C4 in 3. Those 3 are a
  highlighted instance with `draw_single_layer` on the highlight colour's own layer. Geometry
  inside a symbol on a disabled layer: measured, halo repaints none of it in its own colours.
- **The new `text_c` argument has no fence** (LOW-2). A build that drops it passes all three
  suites while getting 12 of those 180 states wrong.
- **Band D is not vacuous, with one soft spot** (LOW-3). Every build that breaks what band D is
  about turns it red, except one: revealing only M1's small `D` pin text passes D1's
  one-tenth threshold.
- **V7c and V8b are now red**, by the new L2 ring leg and the L3 cap, as C4 says. So is every
  other C3-round build that changes the screen, all 13 originals included. V13d is now caught by
  the pixel suite too, which closes C3-verify's LOW-2.
- **The L27/U19 revert keeps the rows meaningful.** Their code is byte-identical to the
  pre-batch rows; a `text_hidden()` or `annot_text_layer()` call added to `move.c` turns them red.

## (1a) Why the title block's hashes differed: the sheet's mtime and its path

Two of `title.sym`'s texts depend on the sheet file, not the build: `@path @schname_ext` and
`@time_last_modified`. The second is `stat()`'s mtime of the sheet (`token.c`), printed to the
second. A probe loaded one sheet in a 1000×720 window, zoomed full
and hashed the canvas (`import -window [winfo id .drw] rgb:- | md5sum`).

- **The two clones' copies are one second apart.** `git clone` wrote the examples I checked at
  00:49:56 in `~/gsv10` and at 00:49:57 in `~/gsv10b`. A fresh clone stamps checkout time, so
  two clones agree only by luck.
- **Each build on its own copy, as the crew ran them:** `cmos_inv` and `greycnt` hash
  differently. The only differing pixels are a 9×13 box (`cmos_inv`) and an 8×12 box
  (`greycnt`) at the time's last digit. The crops read `00:49:57` against `00:49:56`.
- **Both builds on the same file:** they still differ, in a 534×19 strip, the path line. The
  base build, loading its own tree's sheet, prints `cmos_inv.sch`. The C4 build, loading the
  same file from the other tree, prints `/home/analog/gsv10b/xschem_library/examples/cmos_inv.sch`,
  because the file is outside its library path. So `@path` depends on which tree the sheet sits
  in relative to the running build.
- **Same mtime, each build on its own copy:** after `touch -d '2026-01-01 12:00:00'` on every
  `.sch` and `.sym` in all four of my trees, base, C4 and base again give one hash per sheet
  (`cmos_inv` `8930c388…`, `greycnt` `58442aa9…`), **with the title block in.**

So the title block reports facts about the file, not about the renderer. My wider comparison
below keeps the title block in, equalises the mtimes, and loads each build's pages from its own
tree.

## (1b) `draw()` against the base, widened

Probe `eqv.tcl`: one xschem per page set, 1000×720 window, dark theme then light. Every state
hashes the whole canvas through `import` (the X server's pixels, not the hook). Each build ran
on its own display, at the same time as the other.

**74 states per page per theme:**

- plain;
- each of the 22 layers unticked in turn (`enable_layer`, `xschem enable_layers`, as the
  Visible layers checkbutton does);
- `draw_single_layer` on each of the 22 layers (`xschem set rectcolor k` then the `>` key; `<`
  after);
- `hide_symbols` 1 and 2;
- `show_hidden_texts`;
- `annot_show` 1, 2, 4, 8, 9 and 15;
- `only_probes`, and `only_probes` with the text layer off;
- a highlighted net, alone, with the text layer off, and in single layer 3;
- three highlighted instances, alone, with layer 3 off, with layer 4 off, and in single layer 3;
- `lvs_ignore`, alone and with the text layer off;
- `select_all` in classic, bright, brightbox and halo;
- zoomed in: plain, text layer off, single layer 3, single layer 4;
- plain again.

**Pages (38 specs):**

| set | pages |
|---|---|
| examples, 20 | my fixture (C4's fixture contents plus a `layer=12` note, bold/italic and monospace notes, `hide=true`, a bus, M2 with `text_layer_0/1`, `lvs_ignore=short`, `spice_ignore=short`, `hide_texts=true` and `hide=true` resistors, an annotator symbol with a `hide=op` text and a layer-7 text); `cmos_inv`, `greycnt`, `poweramp`, `mos_power_ampli`, `osc`, `0_examples_top`, `LCC_instances`, `classD_amp`, `TwoStageAmp`, `plot_manipulation`, `MSA-2643`, `lightning`, `rom8k`; descended into the first child of `greycnt`, `poweramp` and `0_examples_top`; symbol views `nmos4.sym`, `greycnt.sym`, `lab_pin.sym` |
| sky130A, 8 | `n_diffamp`, `test_inv`, `charge_pump`, `adder_4bit`, `test_lvs_ignore`, `tb_bandgap_opamp`, `top`, `top` descended (work area's `cadence_style_rc` sourced first) |
| ihp-sg13g2, 5 | `ac_hbt_13g2`, `dc_lv_pmos`, `dc_logic_not`, `tran_svaricap_test`, `isolbox_sweep_tb` |
| gf180mcuD, 5 | `0_top`, `test_nfet_TRAN`, `test_cap_mim_1f0fF`, `test_pnp_05p00x00p42`, `0_top` descended |

Each descended page hashes differently from its parent, so the descent happened.

**Result:**

| build pair | states | equal | distinct hashes (so the states change the picture) |
|---|---|---|---|
| cairo, examples | 2960 | **2960** | 1497 |
| cairo, sky130A | 1184 | **1184** | 613 |
| cairo, ihp-sg13g2 | 740 | **740** | 393 |
| cairo, gf180mcuD | 740 | **740** | 367 |
| no cairo, examples | 2960 | **2960** | 1381 |
| no cairo, sky130A | 1184 | **1184** | 605 |

The no-cairo base differs from the cairo base in all 2960 example states, so that build really
is the other text path.

**Same-build repeatability:** the C4 examples set run twice gives 2960 of 2960 equal. My first
base run of the examples was spoiled by my own mistake. I ran another probe on the same display
`:330` while it was running, and 529 states in that window differ. I discarded that run and re-ran
both builds on clean displays; that rerun is the table above.

## (1c) Export

`exp.tcl` exported six pages (fixture, `cmos_inv`, `greycnt`, `poweramp`, `plot_manipulation`,
`rom8k`) in seven states (plain, layer 3 off, layer 4 off, single layer 3, `hide_symbols` 2,
`show_hidden_texts`, highlighted instances) as `xschem print png` (800×600), `svg` and `pdf`.
That makes 126 files per run, from the base twice and from C4 once.

| format | base = base again | base = C4 | distinct states |
|---|---|---|---|
| PNG | 42/42 bytes | **42/42 bytes** | 41 |
| SVG | 42/42 bytes | **42/42 bytes** | 36 |
| PDF | 0/42 bytes | 0/42 bytes | — |
| PDF, rasterised (ghostscript, 100 dpi) | 42/42 pixels | **42/42 pixels** | 36 |

The PDF bytes differ between two runs of the same build; the visible difference is the random
`/ID` cairo writes. Rasterised, every page is identical.

## (2) Cost: no measurable change

Probe `tim4.tcl`. Each measure is `time {… ; winfo pointerx .} N`; the round trip makes the X
server finish too. Window 1200×900 on `:338`, dark theme, brightbox for the selected case.
Measured on each page at zoom full:

- a redraw;
- `zoom_in` + `zoom_out` (two draws);
- `pan up` + `pan down` (two draws);
- a redraw with the text layer unticked;
- a redraw in single layer 4;
- a redraw with everything selected.

Then three `zoom_in`s ("near") and a redraw, a pan, and a redraw with everything selected.

Five pages:

- `poweramp` (86 instances, 67 wires): a real page;
- `mos_power_ampli` (117 instances);
- `rom8k`;
- C3's 600-note page;
- `big.sch`, generated: 3200 instances, 4800 wires, 400 notes.

Six rounds, base and C4 in one process each per round, alternating which went first. Medians
of the six, in ms, base → C4, N = 20:

| page | redraw | zoom in+out | pan up+down | text layer off | single layer 4 | all selected | near: redraw | near: pan | near: all selected |
|---|---|---|---|---|---|---|---|---|---|
| `poweramp` | 3.59 → 4.10 | 4.12 → 4.86 | 2.02 → 2.21 | 0.95 → 0.99 | 0.55 → 0.63 | 3.13 → 3.20 | 0.63 → 0.65 | 1.08 → 1.09 | 0.96 → 1.06 |
| `mos_power_ampli` | 6.60 → 6.73 | 4.80 → 5.04 | 1.20 → 1.27 | 0.69 → 0.71 | 0.64 → 0.64 | 1.38 → 1.39 | 0.58 → 0.60 | 1.04 → 0.99 | 0.98 → 0.94 |
| `rom8k` | 4.38 → 4.54 | 3.59 → 3.61 | 1.05 → 1.04 | 0.64 → 0.62 | 0.60 → 0.60 | 1.36 → 1.36 | 0.53 → 0.58 | 0.95 → 0.93 | 1.14 → 1.16 |
| 600 notes | 1.48 → 1.44 | 1.27 → 1.21 | 1.29 → 1.25 | 0.57 → 0.56 | 0.57 → 0.55 | 2.69 → 2.74 | 0.86 → 0.85 | 1.28 → 1.29 | 2.71 → 2.65 |
| `big.sch` | 6.80 → 6.71 | 2.48 → 2.46 | 1.14 → 1.14 | 0.65 → 0.64 | 0.64 → 0.62 | 4.09 → 4.18 | 0.97 → 0.97 | 1.42 → 1.38 | 4.72 → 4.82 |

- **One cell looked like a cost, and it did not reproduce.** `poweramp`, the first page each
  process loaded, came out 0.5 ms (14%) slower on C4 in all six pairs. I re-ran it twice at
  N = 40:
  - after `mos_power_ampli`: C4/base 0.92–1.02 on every measure;
  - loaded first, then again: redraw 3.77 → 3.92 and 3.81 → 3.93, the ranges overlapping (base
    3.61–4.38, C4 3.77–4.05), every other measure 0.98–1.02.

  So it was the first page's cold start plus the noise of a shared machine. Other sessions' jobs
  (a pytest run, klayout, another clone's T1) were running throughout. It is not the split.
- **Every other cell is within the other build's min–max range.**
- **The code agrees.** `draw()`'s four new predicates are inlined (see the suites section). The
  one new call is `sym_text_draw_layer()`, once per text `draw_symbol()` does not cull. It holds
  the same tests the inline code made.

Nothing here would feel different.

## (3) MEDIUM-1, measured in every look

### The floating note and M1's texts, as last round

`m1.tcl` on my C3 fixture. It counts the pixels a state removes from the unselected sheet (all
layers on), then how many of those the selection paints, and how many it paints back in their
own colour. The regions are M1's padded bbox and the note's box, shrunk.

| state | look | M1: removed / painted by the selection (base → C4) | note: removed / painted (base → C4) |
|---|---|---|---|
| text layer off | classic | 1341 / 5 → 5 | 2214 / 0 → 0 |
| | bright | 1341 / **1341 → 5** | 2214 / **2214 → 0** |
| | brightbox | 1341 / **1341 → 10** | 2214 / **2214 → 0** |
| | halo | 1341 / **1339 → 5** | 2214 / **2023 → 0** |
| single layer 4 | bright | 2156 / 1845 → 419 (= classic's 419) | 2214 / **2214 → 0** |
| | halo | 2156 / 2114 → 674, own colour **360 → 0** | 2214 / **2023 → 0** |
| single layer 3 | halo | 1568 / 1568 → 1478, own colour **1113 → 0** | not removed |
| layer 4 off (M1's geometry) | classic | 753 / 749 | — |
| | bright, brightbox | 753 / 753 → 753 | — |
| | halo | 753 / 753 → 753, own colour **0 → 0** | — |

- **Text layer off and single layer: closed.** C4 paints what classic paints (its box, 5–10
  pixels where the box crosses a letter) and nothing in the text's own colour.
- **Geometry inside a symbol on a disabled layer: halo's own-colour pass paints none of it**,
  in the base and in C4, so `draw_symbol()`'s own `enable_layer` test does hold. The crew read
  it; this measures it. In single-layer mode the base repainted 1113 and 360 pixels in their
  own colours; C4 repaints 0.
- **The selection still strokes disabled geometry in the selection colour**, as classic always
  has (749 of 753 in classic's grey, 753 in `#ff8000`). That is the stroke, not a reveal of the
  object's look, and classic does the same. INFO, not a defect.

### Instance texts with a highlight colour: one corner left (LOW-1)

`inv.tcl` sweeps M1's texts through 180 states: no highlight and highlight colours 9, 4 and 20,
each plain, with every one of the 22 layers off, and with `draw_single_layer` on every layer.
In each it counts the lit pixels inside the `5u/0.18u/1` text box on the unselected sheet. Then
it counts, with M1 selected, the lit and `#ff8000` pixels in classic, bright, brightbox and halo.
A text `draw()` paints must get its letters (no *missing*). A text `draw()` leaves out must get
none (no *reveal*). The threshold is above the 22 pixels a box edge puts in the region.

| build | states | text not drawn by `draw()` | reveal | missing |
|---|---|---|---|---|
| base (`720c20e2e`, C3) | 180 | 91 | **91** | 0 |
| C4 | 180 | 91 | **3** | 0 |
| C4 with `text_c` dropped (VT4, below) | 180 | 91 | 9 | 3 |

`draw()`'s own text pixel counts are identical in every state on both builds.

**C4's three reveals are a highlighted instance with `draw_single_layer` set to the highlight
colour's own layer.** Highlight colour 9 is layer 16, 4 is 11 and 20 is 12; the states are
`hl=9 single16`, `hl=4 single11` and `hl=20 single12`. There `draw()` paints none of M1's
texts. Bright, brightbox and halo light every letter pixel (941 in bright, the count with M1
shown), as the base does in every hidden state.

The cause is a gate the shared predicate does not model. `draw_hilight_net()` (`hilight.c`)
draws a highlighted instance in its own layer loop. That loop's gate is `draw_single_layer ==
-1 || c == draw_single_layer`, and it draws the texts only on the `c == cadlayers - 1` pass.
`draw()`'s own loop always lets `cadlayers - 1` through (`sym_layer_draws()`); the highlight
loop does not. So in single-layer mode `draw()` paints none of a highlighted instance's texts.
Measured on all 22 layers: the unselected count is 0 in every `hl=… single…` state. The overlay asks `sym_text_draw_layer()` with `text_c` =
the highlight layer, which answers "drawn" whenever the single layer equals it. Halo's own-glyph
pass calls `draw_symbol(ADD, hc, n, cadlayers, …)` directly and has the same gap.

To fix it, share the highlight loop's gate. For an instance `draw_hilight_net()` draws, the
overlay should treat its texts as drawn only if that gate passes `cadlayers - 1` *and*
`sym_text_draw_layer()` agrees, which is the pair of tests the highlight loop makes. Halo's
own-glyph call needs the same gate.

The same difference applies to halo's own-colour *geometry* of a highlighted instance on layers
0 and `cadlayers - 1`. `sym_layer_draws()` exempts those two layers; the highlight loop does not.
`nmos4` has no geometry there, so I did not measure that half.

Severity LOW: it takes a highlight, the `>` key on exactly the layer that highlight style paints
in, and a selected highlighted instance. MEDIUM-1 was any unticked layer. It is the same kind of
defect, so it is worth the one-line gate.

### `text_c` does real work, and nothing fences it (LOW-2)

VT4 passes `cadlayers` as `text_c`, as `draw_temp_symbol()` does. On the sweep above it reveals in
9 states: the highlight layer unticked, single layer 3, and single layer on the highlight layer.
It also *misses* the letters in 3: the text layer unticked while M1 is highlighted, where `draw()`
still paints them in the highlight colour. All three suites pass it (table in (4)). C4-fix.md
declares "no row for the highlight colour". This puts a number on that declared gap. A row would
need a highlighted M1 with the highlight layer unticked (reveal) and with the text layer unticked
(missing). Both are already in `inv.tcl`.

## (4) The broken-on-purpose builds against C4

Method, as in C3-verify: one edit per build on a pristine copy of `~/gsv10`, `make -C src`, then
the plumbing suite (`--nogui`), the pixel suite and `test_grid_toggle_sel_gc` (display `:334`–
`:336`). After each lane the six edited sources were `cmp`-identical to `~/gsv10` again. My
C3-round edits all still applied except C2x1 and C2x3, whose rule moved from `move.c` into
`sel_undrawn_text_parts()` (`draw.c`); I re-pointed those two at it. The VT builds are new and
aim at what C4 changed. The unbroken copy (NONE) passes 29, 201 and 10.

Plumbing reddened only C2x4 (O10, O11, O13, W2: `sel_num()` taking NaN). `test_grid_toggle_sel_gc`
reddened only V13d, as in the C3 round.

**The thirteen originals, and the two C3 left green:**

| build | what it breaks | pixel suite, C3 round | pixel suite, now |
|---|---|---|---|
| V1a | brightbox box = the instance's raw bbox | B2, B4 | B2, B4 |
| V1b | box ignores the label case | B4 | B4 |
| V2 | no repair mark on deselect | 16 R rows | 16 R rows |
| V3 | menu values bright/brightbox swapped | M1, M4 | M1, M4 |
| V4 | `draw()` does not call `sel_style_sync()` | L4 | L4 |
| V6 | dark default = the grid's grey | L1, L2, L3 | L1, L2, L3 |
| V7 | bright/brightbox draw a text as a box | B4, H5, L2 | B4, H5, L2 |
| V8 | halo band stroked with `gc_sel` | L3 | L3, **D4, D5** |
| V10 | `take` reads the backing pixmap | 18 rows | 22 rows (adds D1, D2, D4, D5) |
| V11 | erase pad without the halo width | none (changes nothing) | none |
| V12 | setprop marks only the new footprint | R brightbox-w9 r24 | R brightbox-w9 r24 |
| V14 | classic draws no text box | C4, H3a, H3, H5, L2, L3 | those, **D1, D2** |
| V16 | `selection_color` ignored | L1 | L1 |
| **V7c** | bright adds classic's box to the letters | **ALL PASS** | **L2** (the ring leg) |
| **V8b** | halo band twice as wide | **ALL PASS** | **L3** (the cap) |

**The other C3-round builds:** V6L L1; V7b B4, **L2**; V14b L2; V1c B2, B3, H1, **D1, D2**; V9
B2, B3, B4, H4; V8c L3; V13d **L2** in the pixel suite (the brightbox ring control: a dashed box
covers under a third of the ring). In C3 the pixel suite passed V13d, and only
`test_grid_toggle_sel_gc` caught it. So C3-verify's LOW-2 is now closed as well. C2x1 H3, D1, D2;
C2x3 H3, H4, D1, D2; V17 R bright r03/r05/r12/r36, B3; V14c R bright r04/r05/r35/r36, L2; S1x
S1; C2x4 passes the pixel suite and reddens plumbing. **Every C3-round build that changes the
screen is red.** V11 changes nothing (C3-verify measured it), so its green is expected.

**The C4 builds:**

| build | what it breaks | result |
|---|---|---|
| VT1 | `text_draw_layer()` ignores `enable_layer` (`draw()` and the overlay both show the note) | D1 |
| VT2 | the floating-text overlay asks `text_hidden()` only (C3's rule: MEDIUM-1 back) | D1, D2 |
| VT3 | the instance-text overlay skips `sym_text_draw_layer()` (C3's instance reveal back) | D1, D2, D5 |
| VT4 | `text_c` always `cadlayers` (highlight colour ignored) | **ALL PASS** (LOW-2) |
| VT5 | halo's own colours ignore the sheet-object gate entirely | D4, D5 |
| VT6 | halo's own colours ignore `sym_layer_draws()` for a symbol | D5 |
| VT7 | halo's own colours ignore `wires_draw()` | D5 |
| VT8 | the sheet-object gate ignores `enable_layer` (single layer only) | D4 |
| VT11w | of M1's undrawn texts, `5u/0.18u/1` revealed | D1, D2 |
| VT11 | of M1's undrawn texts, the name `M1` revealed | D1, D2 |
| VT11d | of M1's undrawn texts, the pin text `D` revealed | **ALL PASS** (LOW-3) |
| VT12 | an undrawn text keeps `SELP_GLYPHOWN` | ALL PASS: equivalent (below) |

**Is band D vacuous?** No.

- Every gate C4 added has a build that turns band D red: the floating-text predicate, the
  instance-text predicate, the sheet-object own gate in both halves, the symbol gate and the
  wire gate.
- D4 and D5 cannot pass with nothing drawn. Their colour leg wants exactly `{#ff8000}`, and an
  empty selection gives `{}`.
- D1 has no explicit "the note left the sheet" leg, but it does not need one. VT1 puts the
  letters back on the sheet *and* in the selection, and D1 goes red because the note's box
  then has changed pixels inside it.

Two soft spots:

- **LOW-3, D1/D2's one-tenth threshold for M1.** It is measured over all of M1's letter pixels,
  so it passes a reveal of one small text. VT11d reveals only the 0.15-scale `D` (wrong on screen,
  orange letters `draw()` does not paint) and passes. The name `M1` is already enough to fail
  it. A per-text region, or a threshold on the count rather than the fraction, would close it.
- **VT12 is not a hole.** `draw_sel_entry()`'s xTEXT own-glyph branch tests `text_draw_layer(n)
  >= 0` again before drawing. An instance's own glyphs go through `draw_symbol()`, which has its
  own gate. So stripping `SELP_GLYPHOWN` in `sel_undrawn_text_parts()` is a second line of
  defence, and removing it changes no pixel.

## (5) L27 and U19 after the revert

- **The rows' code is the pre-batch code, byte for byte.** `diff` against
  `f039113c5~1:tests/headless/test_op_annot.tcl` shows only the two added comment blocks.
  `move.c` names `text_hidden`, `annot_text_layer` and `HIDE_TEXT` zero times, so the file sets
  `{actions.c draw.c psprint.c select.c svgdraw.c}` and `{actions.c draw.c psprint.c svgdraw.c}`
  are again what they were before the batch.
- **They still catch what they are for.** I lifted `opa_l_cfiles` and `opa_u_ccalls` unchanged
  and ran the L27, U19 and U30 predicates over edited copies of `src/`:

  | edit | L27 | U19 | U30 |
  |---|---|---|---|
  | C4 as is | pass | pass | pass (2 2 2) |
  | `move.c` calls `text_hidden()` again (VT2's edit) | **FAIL** | pass | pass |
  | `move.c` calls `annot_text_layer()` | pass | **FAIL** | pass |
  | `move.c` mentions both in a comment | FAIL | FAIL | pass |
  | `draw.c`'s `text_draw_layer()` stops calling `text_hidden()` | pass | pass | pass |

  - The comment case fails, a false red. That is the direction the suite's own comments accept
    (cheap to be wrong in).
  - The last case is the rows' standing limit, not C4's. They are file sets, and `draw.c` names
    `text_hidden_inst` in other places. The pre-batch `draw.c` was no different. Only a
    behavioural row could see that one; I did not build it.
- **U30's count survives the move into helpers:** `draw.c` still calls `annot_text_layer(`
  exactly twice, now in `text_draw_layer()` and `sym_text_draw_layer()`.

## Suites, T1 scoring, valgrind

- **T1's own launch shapes and scoring** (`derive.tcl`: lifted `summarize_all` and its 16 procs,
  `banner_rule.tcl` sourced, `planned 206` from the three lists), on `~/gsv10`:

  | case | arm | checks | banner | counted | skips |
  |---|---|---|---|---|---|
  | `test_selection_look_plumbing` | hcases | 29 | 1 | 0 | 0 |
  | `test_selection_look_pixels` | dcases | 201 | 1 | 0 | 0 |
  | `test_grid_toggle_sel_gc` | dcases | 10 | 1 | 0 | 0 |
  | `test_op_annot` | hcases | 486 | 1 | 0 | 5 (its known display-only rows) |
  | `test_op_annot` | dcases | 494 | 1 | 0 | 0 |

- **Valgrind** (`valgrind -q --error-exitcode=99`, `env` first) over the whole pixel suite on
  C4: `ALL PASS (201 checks)`, rc 0, every log empty.
- **Build:** six warnings on every build, the same six sites as the base.
- **Code shape:** in `draw.o` (`-O2`), `draw()` has no call to `text_draw_layer`,
  `layer_draws`, `sym_layer_draws` or `wires_draw`. They are inlined. `draw_symbol()` makes one
  out-of-line call to `sym_text_draw_layer()` per text it does not cull.
- **Read, not measured (INFO):** in `draw_temp_symbol_parts()`, a text that asks for letters or
  a band now goes through `text_hidden_inst()` twice: the old early test, then inside
  `sym_text_draw_layer()`. At the declutter rung that bumps `annot_declutter_count` twice per
  overlay draw. Its one reader (`annot_declutter_say`) tests only that the count grew, so
  nothing changes.

## Findings

| id | severity | what | where |
|---|---|---|---|
| LOW-1 | low | A highlighted instance's texts are revealed when selected in single-layer mode on the highlight colour's own layer: 3 of 91 hidden states, all styled looks. Fix: for an instance `draw_hilight_net()` draws, give the overlay (and halo's own-glyph call) that loop's layer gate. | (3) |
| LOW-2 | low | `text_c` has no row. Dropping it (VT4) passes every suite but is wrong in 12 of 180 states (9 reveals, 3 missing letters). | (3), (4) |
| LOW-3 | low | D1/D2's M1 leg is a tenth of all of M1's letter pixels, so revealing one small text (VT11d, the pin text `D`) passes. | (4) |
| INFO | — | Selection strokes disabled-layer geometry in the selection colour, as classic always has. | (3) |
| INFO | — | `text_hidden_inst()` runs twice per overlay text that asks for letters; harmless to its one reader. | suites |

Closed this round: MEDIUM-1 (except LOW-1), C3-verify's LOW-1 (V7c, V8b) and LOW-2 (V13d).
C3-verify's LOW-3 (the C3 row measures the box against itself) was not in scope and I did not
re-check it.

## Housekeeping

- Displays `:330`–`:338` killed by recorded pid (18 processes, each cmdline and openbox
  `DISPLAY` checked first); none left.
- `~/gsv10s1`–`~/gsv10s3` restored (`diff -r` on `src/`: 0 files differ from `~/gsv10`), then
  deleted with `~/gsv10s4` and the no-cairo pair. `~/gsv10` and `~/gsv10b` are kept, built. In
  both, every `.sch` and `.sym` mtime is set to 2026-01-01 (`touch -d`, for (1a)); their git
  content is unchanged.
- No `*~.sch` or `untitled*` in any clone. Nothing written in the main tree but this file.
- Scratch (probes, captures, logs): `selC4v/` under the session scratchpad. `eqv.tcl`,
  `exp.tcl`, `m1.tcl`, `inv.tcl`, `tim4.tcl`, `bop/breaks4.py`, `bop/drive4.sh`.
