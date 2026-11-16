# C3: rows that fence the look itself; `window_snapshot pixels` refuses an overflowing region

Crew C, follow-up C3, 2026-11-15. Built and measured in the clone `~/gsc1` on top of C2
(`4bcd74664`); C3 is scratch-committed there as `656e3bda8`. Private display: `:320` only
(Xvfb plus openbox). The main tree carries only this receipt and `C3-incremental.patch`.

**In plain English.** The independent check (`receipts/C-verify.md`) found that the tests
caught a selection that was erased or repainted badly, but not a selection that looked wrong.
Every one of those tests compared the screen with a fresh redraw, and a fresh redraw paints the
same wrong look. So a build that painted the selection in the grid's grey, or drew boxes instead
of letters, passed everything.

This stage adds seven checks that compare the screen with what the look is meant to be:

- the documented colours;
- a text's own letters, as the unselected sheet shows them;
- the band Halo adds outside a line;
- classic's box around a text;
- the box around a net label;
- a typed `set selection_style` taking effect on the next redraw.

Each of the verifier's seven builds that slipped through now fails at least one of them. A
second, smaller change makes the test-only snapshot command refuse a region whose size
overflows, instead of silently wrapping.

## HIGH-1 and MEDIUM-1: the rows (`tests/headless/test_selection_look_pixels.tcl`)

The display arm goes from 190 to 197 checks. The headless arm still self-skips with 0 checks.
Every expected value is fixed in the suite rather than read off a redraw.

| row | band | what it compares with | fences |
|---|---|---|---|
| **B4** | B | B2's method on the net label `p1`: brightbox's box must have the bounding box of the hover outline. The label is the one instance whose hover rectangle is its text, not its symbol bbox (`hover_inst_rect()`). | the box follows the label case |
| **C4** | C | The floating note and the small note, each selected alone in classic. The change must be a rectangle outline: every edge of its bounding box at least 90% layer 2's grey, and nothing changed 4 px inside. | classic has its text boxes. Band C's header ("a box per text") is now a measured claim. |
| **L1** | L | Bright, FET selected, the most frequent colour painted: `#ff8000` (dark default), `#00ff00` (`selection_color`), `#ff8000` (`selection_color notacolour`, which falls back to the default), `#e05a00` (light default), `#ff8000` (dark again). | the selection colour used, and `selection_color` honoured |
| **L2** | L | Bright and brightbox, both floating texts. The text's box is classic's mark. 2 px inside it, no changed pixel was background on the unselected sheet. 4 px inside it, some letter pixels turn exactly `#ff8000`. | texts are letters in the selection colour, not boxes |
| **L3** | L | Halo, the horizontal wire selected: only `#ff8000` changes; the change is at least 7 px tall (a 3 px band on each side plus the stroke); the wire's own middle is unchanged. Halo, floating note: changed pixels on the background, all `#ff8000`. | Halo has a band |
| **L4** | L | From brightbox with the FET selected, a typed `set ::selection_style X` plus `xschem redraw`, for X = bright, halo, classic. The look in force must read X back; the window must equal X chosen through `build_colors`; and it must differ from brightbox's, so the comparison could see a look that did not change. | MEDIUM-1, FAQ Q94's "takes effect on the next redraw" |
| **S1** | S | See the LOW item below. | the overflow |

Thresholds come from C2's own figures, measured with a probe before the rows were written:

- L2: 2342 changed pixels on the floating note, 0 of them on the background.
- L3: the wire's change is 992 pixels, every one `#ff8000`.
- B4: brightbox's box and the hover outline share their bounding box at all four hover points
  tried.
- L4: pixel-identical to the menu path in every look.

**A missing mark now reddens rows instead of ending the suite.** Under V14, classic draws no
text box, so H3's region helper received an empty rectangle and raised `can't use empty string
as operand of "+"`. Every later row vanished from the verdict, and the exit code was still 0.
T1 would have scored that as an incomplete run, red, but without naming the rows.

`shrink` now returns an empty region for an empty one, and `inside` answers 0 for it. Both moved
up with the helpers so that C4 can use them. With that change, V14 reports
`6 FAILED (191 passed)`, which is all 197 rows.

## LOW: `window_snapshot pixels` (`src/scheduler.c`)

A new `win_snap_region()` parses x, y, w and h:

- each with `strtol`, an end check and `ERANGE`, and each must lie in int range;
- x + w and y + h are checked against `INT_MAX`/`INT_MIN` before they are added.

Anything else is a clean Tcl error with one sentence. Clipping to the capture is unchanged.
`<errno.h>` is now included. Nothing but this suite calls `pixels`.

Row **S1** expects errors for six inputs: x + w past `INT_MAX`, x + w below `INT_MIN`, y + h past
`INT_MAX`, `a`, `1.5`, and a w outside int. It expects 6 values for a 3×2 region and none for
w = −3. On C2's `scheduler.c`, S1 is red: the overflowing call returned a wrapped empty list, and
`a` was read as 0.

## Builds broken on purpose (red first)

The verifier's edits come from its own `breaks.py`, applied verbatim to the C3 sources, plus
C2's `scheduler.c` for S1. Each was built, the pixel suite was run on `:320`, then the sources
were restored and byte-compared.

| build | the edit | new rows red | whole suite |
|---|---|---|---|
| C2 sched | `pixels` with C2's `atoi()` sums | S1 | 1 FAILED |
| V1b | the box ignores the label case | B4 | 1 FAILED |
| V4 | `draw()` does not call `sel_style_sync()` | L4 | 1 FAILED |
| V6 | dark default selection colour = the grid's grey | L1, L2, L3 | 3 FAILED |
| V7 | bright/brightbox draw a text as a box | B4, L2 (and C2's H5) | 3 FAILED |
| V8 | halo's band stroked with `gc_sel`, so it is covered | L3 | 1 FAILED |
| V14 | classic without text boxes | C4, L2, L3 (and H3a, H3, H5) | 6 FAILED, after the guard above |
| V16 | `selection_color` ignored | L1 | 1 FAILED |

After every build, the restored sources were byte-identical (`SRC-RESTORED-IDENTICAL`). The
objects were too, except `scheduler.o`: it is not reproducible, because `scheduler.c` embeds
`__DATE__ " : " __TIME__`. Recompiling the identical `scheduler.c` twice differs in `objdump -d`
by one `movabs` immediate and nothing else (the ASCII `3:16:19` against `3:16:40`).

## Checks

**Suites (armed `run_suites.sh`):**

| suite | headless arm | display arm (`:320`) |
|---|---|---|
| `test_selection_look_pixels` (`dcases`) | `RESULT: SKIP (no X: …)`, 0 checks | ALL PASS (197) |
| `test_selection_look_plumbing` (`hcases`, not touched) | ALL PASS (29) | ALL PASS (29) |
| `test_grid_toggle_sel_gc` (`dcases`, not touched, run as a control) | not run (`dcases` only) | ALL PASS (10) |

- **Runtime.** The pixel suite takes 43.7 s against 40.8 s for C2's suite (one run each, `:320`).
- **T1.** No registration changed. Both arms of the pixel suite were captured in T1's loop
  shape and scored with `summarize_all` lifted from `run_regression.tcl` (16 procs) and
  `banner_complete` sourced from `tests/banner_rule.tcl`. Each scored 1 block of 3 lines,
  `banner_complete=1`, counted 0, skips 0. So the batch delta stays +3/+3/+0/+0, `wc -l` +9, with
  `planned_cases` 201 → 204 against `e6b38ba83`.
- **Warnings.** A full rebuild gives 6, the same sites as base: `actions.c:586`, `util.c:222`,
  `save.c:7357`, `token.c:1057`–`1059`.
- **Valgrind.** `valgrind -q` (with `env` before `valgrind`) gives 0 lines on the pixel and
  plumbing suites, both arms, at 197 and 29 checks.

## Patch

| file | md5 | checked |
|---|---|---|
| `C3-incremental.patch` | `fada9a0ddaedfb52f02e08f0c162793c` | applies on C2 (`4bcd74664`); touches `src/scheduler.c` and the pixel suite |

**Main tree.** While C3 was in progress, the main tree gained `f039113c5` ("feat(select): four
selection looks, default Bright with box") and is clean. Its `xinit.c`, both selection-look
suites, the grid suite and FAQ.md are byte-identical to C2. Its `move.c`, `scheduler.c` and
`xschem.h` differ from C2 by `c2b467535`'s own drag fix. Two checks, both on copies of the main
worktree:

1. **The main tree as it stands.** `git apply --check` passes, and after applying:
   - the pixel suite is byte-identical to the clone's;
   - `scheduler.c` is byte-identical to the clone's C3 `scheduler.c` with `c2b467535`'s own
     delta applied.
2. **The sequence asked for.**
   - On a copy, `C2-incremental.patch` and then `C-incremental-on-main.patch` are backed out in
     reverse.
   - Both are applied again, giving back the main tree's bytes exactly.
   - `C3-incremental.patch` then passes `--check`.

## Not done

- **V10: the R band on its own.** The verifier's other LOW: under a `take` that reads the backing
  pixmap, every R row stays green. That was not requested here. The suite as a whole already
  reddens there (B1–B3, C1, H1, O1 in the verifier's run). V10 was not rebuilt against the
  new rows.
- **`take { 1}` accepting a leading blank.** Harmless, as the verifier says; left alone.
- **The INFO items.** Not touched.
