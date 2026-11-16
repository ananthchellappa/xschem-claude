# C4: a selected text draw() leaves out stays out; halo repaints only what draw() paints

Crew C, follow-up C4, 2026-11-16. Built and measured in the clone `~/gsc1` on top of C3
(`656e3bda8`); C4 is scratch-committed there as `927b60470`. Private displays: `:320` and `:321`
only (Xvfb plus openbox). The main tree carries only this receipt and `C4-incremental.patch`.

**In plain English.** If you untick the text layer in View > Show > Visible layers, the sheet's
texts disappear. Selecting one brought its letters back in every styled look (Bright, Bright with
box, Halo), and Halo also drew its band around letters that should not be visible. The `>` key,
which draws only the current layer, had the same problem. Classic was unaffected (it draws only
boxes). Halo also had a related problem: it repainted a selected rectangle, line, polygon, arc,
wire or symbol body in its own colours even when that layer was switched off.

Now the selection overlay asks the same questions `draw()` asks, through shared functions in
`draw.c`. A selected text that `draw()` does not paint is marked the way a hidden text already was
(C2): no letters and no band, just classic's box in the selection colour, or in Bright with box
only the selection box. Halo keeps its band around an object on a switched-off layer, but no longer
paints the object itself. Every new check fails on C3 and passes on C4. Redraw and drag times did
not change in a way anyone could feel.

## MEDIUM-1: one set of predicates for `draw()` and the overlay (`src/draw.c`, `src/move.c`)

`draw()` decides whether to paint something in four places. Each decision is now a named
function. `draw()` calls it, and the overlay calls the same function. Nothing is copied.

| predicate (draw.c) | what `draw()` uses it for | who else asks it |
|---|---|---|
| `text_draw_layer(i)` | floating text `i`: the layer it is painted in, or -1. Covers `text_hidden`, the annotation layer (0615), `only_probes`, and (cairo) `enable_layer` and `draw_single_layer`. This is the body of C3's `sel_text_own_layer()` in `move.c`, moved and now used by `draw()`'s own text loop. | `draw_sel_entry()` case `xTEXT`: the letters and band, and halo's own-colour letters |
| `sym_text_draw_layer(n, j, …)` (static) | instance text `j`: `text_hidden_inst`, a hidden symbol's text other than its name (1249), the layer derivation (disabled, `only_probes`, `text_layer_<n>=`, annotation layer), `draw_single_layer`, `enable_layer`. This is `draw_symbol()`'s text-loop body, moved verbatim, comments included. | `draw_temp_symbol_parts()`, per text |
| `layer_draws(c)` | the sheet's own lines, rects, arcs and polygons on layer `c` | halo's own-colour pass for those four types |
| `sym_layer_draws(c)` | whether `draw()` calls `draw_symbol()` for layer `c` | halo's own-colour pass for an instance |
| `wires_draw()` | the wires (`draw_single_layer` only; the layer switches never hid wires) | halo's own-colour pass for a wire |

Two small static helpers, `inst_draw_disabled()` (shorted or LVS-ignored, and the colour that
implies) and `sym_text_color()` (the colour an instance's texts default to), replace two inline
blocks in `draw_symbol()`. The overlay uses them so it computes the same inputs to
`sym_text_draw_layer()`.

`draw_temp_symbol_parts()` gains one argument, `text_c`: the colour `draw()` draws the instance's
texts in (a highlight colour, or `cadlayers` for their own colours). `draw_sel_entry()` passes
`sel_own_hilight_color()` for the instance; `draw_temp_symbol()` (classic, box only) passes
`cadlayers` and asks nothing. The predicate is evaluated only when letters or a band are wanted,
and `lvs_ignore` is read at most once per call.

`sel_undrawn_text_parts()` is C2's hidden-text treatment, moved out of `move.c` so both text paths
share it. It removes the letters, the band and the own-colour letters. Unless the look is
brightbox, whose box pass already draws a box, it adds classic's text box.

**Halo's own colours.** `draw_sel_entry()` now drops `SELP_OWN` for a wire when `wires_draw()` is
false, and for a rect, line, polygon or arc when `layer_draws(c)` is false. The instance's
own-colour loop skips a layer `sym_layer_draws()` rejects. `draw_symbol()` already tests
`enable_layer` per layer itself. The selection band is untouched, so the selected object is still
marked.

## The rows (`tests/headless/test_selection_look_pixels.tcl`, band D)

The display arm goes from 197 to 201 checks. The headless arm still self-skips with 0 checks.

| row | drives | asserts |
|---|---|---|
| **D1** | the text layer unticked, as the Visible-layers checkbutton does (`enable_layer`, `xschem enable_layers`, `xschem redraw`) | in bright, brightbox and halo, the selected floating note changes nothing 6 px inside classic's box, changes something inside the box widened by 6 px, and uses only the selection colour. Selecting M1 changes fewer than a tenth of the pixels its letters cover. |
| **D2** | `draw_single_layer` on layer 4 through the real key (`xschem set rectcolor 4`, `key greater 1`; `key less` resets) | a leg showing the note's letters left the unselected sheet (so the key took effect), then D1's three assertions |
| **D4** | halo, layer 4 unticked; rect, line, polygon, arc selected one at a time | per object, a leg showing it is gone from the unselected sheet; the selection changes only to `#ff8000` |
| **D5** | halo, `draw_single_layer` on empty layer 7; wire, M1, rect | the same, per object |

"M1's letters" are measured, not assumed: the pixels that change when the text layer is unticked,
inside a fixed region around M1. Drawn letters change all of them. A box or stroke crossing them
changes a few in a hundred, so the threshold is a tenth.

**Red first.** The C4 suite was run against a C3 build (C3's `draw.c`, `move.c` and `xschem.h`,
built in scratch) and against C4 on `:320`:

| | C3 build | C4 build |
|---|---|---|
| whole suite | `4 FAILED (197 passed)`: D1, D2, D4, D5 | `ALL PASS (201 checks)` |
| D1/D2, note: px changed inside the box (bright / brightbox / halo) | 2214 / 2214 / 2470 | 0 / 0 / 0 |
| D1/D2, M1: letter px changed, of 1341 (classic changes 5) | 1341 / 1341 / 1339 | 5 / 10 / 5 |
| D2, halo, M1: pin-colour px | 360 | 0 |
| D4, halo, layer-4-colour px: rect / line / poly / arc | 815 / 290 / 679 / 316 | 0 |
| D5, halo, layer-4 / pin-colour px on M1 | 793 / 360 | 0 |
| D5, halo, wire-colour px on the wire | 319 | 0 |

Both halves of D1 and D2 (the note and M1) are red on C3. A row for `hide_symbols` was written
and dropped: it is green on C3, because `draw_temp_symbol_parts()` draws none of a hidden
symbol's texts.

## LOW: V7c and V8b (rows L2 and L3)

- **L2** gains a leg: the "ring", the pixels classic's box outline paints around each floating
  text. In bright, fewer than a tenth of them may turn exactly `#ff8000`; measured, 0 of 1058 (the
  note) and 0 of 363 (the small note) do. In brightbox, whose box is on that ring, more than a
  third must; measured, 527 and 182 do. Brightbox is the control showing the ring can see a box.
- **L3** gains a cap: the halo band around the horizontal wire is no taller than classic's stroke
  (read back from classic, 2 px here) plus 2 × `halo_px` (read from `xschem get selection_look`,
  3) plus 2. Measured: the band is 8 px, exactly stroke + 2 × `halo_px`. Earlier in this stage it
  was also exactly that at halo widths 1, 3 and 6 and at line widths 2 and 11. **The measured
  margin is 0.** The 2 px are slack for rounding at other zooms and widths, which nothing measured
  needed. A band twice as wide is 6 px over at the default.

The verifier's V7c and V8b edits were applied verbatim from its own `breaks.py`. Each now reddens
its row (table below).

## Builds broken on purpose

Each edit was built, the pixel suite was run on `:320`, then the sources were restored and
byte-compared.

| build | the edit | red |
|---|---|---|
| K1 | the floating-text arm asks `text_hidden()` again instead of `text_draw_layer()` | D1, D2 (2 FAILED) |
| K2 | the instance-text test in `draw_temp_symbol_parts()` disabled (`if(0 && …)`) | D1, D2, D5 (3 FAILED) |
| K3 | the rect/line/polygon/arc own-colour gate disabled | D4, D5 (2 FAILED) |
| K4 | the wire own-colour gate disabled | D5 (1 FAILED) |
| K5 | the instance own-colour `sym_layer_draws()` skip removed | D5 (1 FAILED) |
| K6 | `sel_undrawn_text_parts()` adds no box | H3, H4, D1, D2 (4 FAILED) |
| V7c | the verifier's: bright draws classic's box around the letters | L2 (1 FAILED) |
| V8b | the verifier's: halo's band twice as wide | L3 (1 FAILED) |

After restoring, all 76 source files matched their pre-drive checksums. Every object file also
matched except `scheduler.o`. `scheduler.c` embeds `__DATE__ " : " __TIME__` (`char date[]`), so
its object changes on every recompile, and the drive recompiled it. A full rebuild from the
restored sources followed (every `.c` touched).

## `draw()` paints what it painted before

The refactor moves `draw()`'s own conditions into functions, and is meant to change nothing on
screen. A probe (`eqv.tcl`, scratch) hashed the whole window (crc32 of `window_snapshot` pixels)
on four sheets under 18 states each, on a C3 build and on C4. The four sheets were `cmos_inv`,
`greycnt` and `poweramp` from `xschem_library/examples`, plus a fixture built to reach every
branch.

- **The fixture** has geometry on layer 4, a `layer=7` note, `hide=voltage` and `hide=true`
  notes, M2 with `text_layer_0=7 text_layer_1=12`, `lvs_ignore=short` and `spice_ignore=short`
  resistors, a label, and a `type=annotator` symbol with a `hide=op` text.
- **The 18 states:** plain; the text, layer-4, pin and wire layers each unticked; single layer 1,
  3, 4, 5 and 7; `hide_symbols` 1 and 2; `show_hidden_texts`; `only_probes`; a highlighted net;
  that net with the text layer off; `lvs_ignore`; plain again.

**Result: all 72 hashes are identical.** Runs C3, C4, C3 gave a byte-identical summary. 64 of the
72 hashes are distinct, so the states really change the picture.

The examples' `title.sym` was removed from their copies. With it in, the hashes of those three
sheets differed between the two builds' runs while the fixture's agreed. The title block prints
`@path`, `@schname_ext` and `@time_last_modified`. I did not establish which of those differs.

## Timing (C3 build against C4, same machine, same sheet)

The sheet has 1600 `nmos4` instances and 1600 floating notes, in a 900×700 window on `:321`. The
probe times a redraw with nothing selected and a redraw with everything selected (20 each). It
also times a drag of everything: start, 6 steps, end and undo, averaged over 3. Each figure below
is the mean of two whole runs per build, in ms. "near" is a quarter of the sheet, where the texts
are drawn; at "full" most are culled for size.

| zoom | text layer | look | redraw, none selected | redraw, all selected | drag of all |
|---|---|---|---|---|---|
| full | on | classic | 2.3 → 2.5 | 6.4 → 6.2 | 443 → 457 |
| full | on | bright | 2.3 → 2.9 | 8.0 → 8.5 | 482 → 489 |
| full | on | brightbox | 2.4 → 2.3 | 9.1 → 9.0 | 519 → 515 |
| full | on | halo | 2.4 → 2.4 | 18.0 → 19.3 | 591 → 573 |
| full | off | classic | 2.5 → 2.4 | 6.7 → 6.4 | 595 → 485 |
| full | off | bright | 2.3 → 2.3 | 7.9 → 7.6 | 526 → 497 |
| full | off | brightbox | 2.4 → 2.3 | 9.3 → 7.7 | 525 → 511 |
| full | off | halo | 2.5 → 2.2 | 18.5 → 16.7 | 557 → 546 |
| near | on | classic | 6.8 → 6.2 | 11.4 → 10.8 | 583 → 453 |
| near | on | bright | 6.7 → 6.5 | 18.9 → 19.7 | 605 → 532 |
| near | on | brightbox | 7.4 → 6.3 | 22.1 → 18.4 | 556 → 521 |
| near | on | halo | 6.3 → 6.3 | 19.1 → 18.9 | 522 → 528 |
| near | off | classic | 0.8 → 1.0 | 5.4 → 5.4 | 440 → 474 |
| near | off | bright | 1.0 → 1.0 | 12.7 → 11.0 | 522 → 506 |
| near | off | brightbox | 0.9 → 1.0 | 14.3 → 7.7 | 553 → 488 |
| near | off | halo | 0.9 → 1.0 | 13.6 → 11.6 | 566 → 528 |

Every difference is inside the run-to-run spread of one build: C3's own two runs of the same drag
differ by up to 240 ms, and the drag is dominated by the move and the undo, not the overlay. The
one consistent change is that with the text layer off, select-all redraws at "near" got cheaper
(brightbox 14.3 → 7.7 ms). The overlay no longer paints 1600 notes' letters that the user switched
off. **Nothing here would feel different.**

The pixel suite itself takes 47.8 s on C4 against 47.7 s for the C3 build running the same suite
file. Band D costs about 4 s over C3's 43.7 s.

## Other checks

- **Suites, armed (`run_suites.sh`).**
  - Display arm, `:320`:

    | suite | checks |
    |---|---|
    | pixels | 201 |
    | plumbing | 29 |
    | `test_grid_toggle_sel_gc` | 10 |
    | `test_typeless_symbol_1603` | 9 |
    | `test_annot_declutter_1244` | 134 |
    | `test_op_annot` | 493 |

    `test_op_annot` reads 494 with `--logdir`, as T1 runs it. Its W23 skip is the missing
    action log. `test_typeless_symbol_1603`'s N2 skip is its own dev-display check; `:320` is not
    `:99`.
  - Headless (`env -u DISPLAY AUDIT_DISPLAY=none`):

    | suite | checks |
    |---|---|
    | plumbing | 29 |
    | `test_op_annot` | 486, its usual five display-only skips |
    | `test_typeless_symbol_1603` | 9 |
    | `test_drag_tclvar_reads` | 41 |
    | `test_undo_link_symbols` | pass |

    Pixels and the grid suite self-skip. `test_annot_declutter_1244` gives NORESULT there. It is
    in `dcases` only, and its header says it must not run under `--nogui`.
- **`test_op_annot` L27 reddened on the first display run, and the fix was the row.**
  - L27 lists the `.c` files that call `text_hidden`. C3 had added `move.c` to that list. Its
    comment kept `move.c` there through "a prose mention", meaning a comment as the row's evidence,
    which is the trap CLAUDE.md records for issue 1646. C4's `move.c` names neither the flag nor
    the predicate.
  - L27 is now back to its pre-batch form: name "five .c files", list without `move.c`, as at
    `e6b38ba83`. Its comment says why the overlay is not in it.
  - U19 (`annot_text_layer` callers) likewise drops `move.c`.
  - The source-text rows U30 (`annot_text_layer(` count), A19 and A22
    (`test_annot_declutter_1244`) pass unchanged. The moved code kept their call counts.
- **Valgrind.** `valgrind -q` (with `env` before `valgrind`) gives 0 lines on the pixel and
  plumbing suites, both arms.
- **Build.** A full rebuild gives the base six warnings (`actions.c` 1, `save.c` 1, `token.c` 3,
  `util.c` 1). None is in a file C4 touches.
- **T1.** `tests/run_regression.tcl` is not in the diff, so `cases` and `blocks` cannot move. The
  touched suites were captured exactly as T1's two loops run them and scored with `summarize_all`,
  lifted whole (16 procs) from `run_regression.tcl`. `banner_complete` was sourced from
  `banner_rule.tcl`.

  | suite | arm | block lines | counted | `skips` | checks |
  |---|---|---|---|---|---|
  | pixels | `dcases` | 3 | 0 | 0 | 201 (was 197) |
  | `test_op_annot` | `dcases` | 3 | 0 | 0 | 494 |
  | `test_op_annot` | `hcases` | 8 | 0 | 5 | 486 |
  | plumbing | `hcases` | 3 | 0 | 0 | 29 |

  These block shapes are line-for-line identical to stage C's captures apart from the count.
  **Delta: cases +0, blocks +0, counted +0, skips +0, `wc -l` +0.**
- **The patches apply to the main tree.**
  - In a copy of `f039113c5`, `C3-incremental.patch` then `C4-incremental.patch` apply cleanly.
    `draw.c` and both test files then equal the clone's. `move.c`, `xschem.h` and `scheduler.c`
    differ from the clone by exactly `c2b467535`, main's drag fix, which the clone does not carry.
  - `C4-incremental.patch` also applies cleanly to main's current HEAD `720c20e2e`, where C3 is
    committed as `d14e4daee`. The result is identical to the first case in every file both touch.
  - That tree was built in scratch (the same six warnings) and run on `:321`. All passed:

    | suite | checks |
    |---|---|
    | pixels | 201 |
    | plumbing | 29, both arms |
    | grid | 10 |
    | `test_drag_abort_backup_1716` | 111 display, 73 headless |
    | `test_drag_tclvar_reads` | 41 |

    That build carried the patch before one last comment-only edit to L3's comment.

## Declared limits

- The highlight-colour input to the instance predicate (`text_c`, from `sel_own_hilight_color()`)
  has no row. Every band-D row drives an instance that is not highlighted.
- A hidden symbol (`hide_symbols` 1 or 2) has no row, because it was already right on C3: the
  overlay draws none of its texts. At `hide_symbols` 2, `draw()` still draws the name while the
  overlay draws no text at all. That is a pre-existing difference, and it reveals nothing.
- Halo's own-colour pass on an instance with a geometry layer unticked relies on `draw_symbol()`'s
  own `enable_layer` test. I read that, but no row measures it: D4 selects the sheet's own
  objects, and D5 drives M1 under `draw_single_layer`.
- `text_draw_layer()` keeps the layer gates inside `#if HAS_CAIRO==1`, exactly as `draw()`'s text
  loop had them. A non-cairo build was not built or run.
- The `draw()` equivalence is measured (4 sheets × 18 states at zoom-full in one window size), not
  proven, and the title block was excluded.

## Files

- Clone `~/gsc1`, commit `927b60470`:
  - `src/draw.c`;
  - `src/move.c`;
  - `src/xschem.h`;
  - `tests/headless/test_selection_look_pixels.tcl`;
  - `tests/headless/test_op_annot.tcl`.
- `receipts/C4-incremental.patch` is `git diff 656e3bda8 927b60470`: 5 files, +355 −123, md5
  `2308af70fb87d8237c6a152fb1202acf`.
