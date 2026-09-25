# Receipt C — item 3: what the export path is missing, and why a golden is the wrong instrument

Crew `survey:suite-gap`, dispatched from `cff55068`. Nothing rebuilt. No test code written —
this is the survey the implementation stage works from.

## What already exists, and the one clause that is load-bearing

`tests/headless/test_ps_valid_1350.tcl`:

* **`V19` is the only row in the tree that can see this defect at all.** Its predicate is
  `$rc19 == 0 && [llength $rgb] > 0 && $rgbbad == 0 && [llength [lsort -unique $rgb]] == 2`,
  and the **`distinct == 2`** clause is the one that matters — the suite's own comment says a
  garbage triple landing inside 0..1 would still be a third distinct value. So V19 reddens on
  a reverted fix **even in the lucky-heap case**, which the range clause alone would miss.
* **`V20`** is the corpus-scale volume statement (0 out-of-range channels over ~325 sheets)
  and its own comment concedes it is heap-dependent, not categorical — 77 of 321 sheets showed
  zero on another sweep. V19 is the fence; V20 is the scale.
* **`V14`** fences syntactic validity and page/link survival over the corpus, not byte
  stability: `distil`/`clean` compare a PDF against the PostScript **from the same export**,
  so two different exports both satisfy it.
* All three go through `child_export`, which hardcodes `xschem hier_psprint` and `--nogui`.
  **One verb, one arm.**

## The gap is worse than "no row exists" — three suites are BLIND by construction

Grepping all of `tests/` for `md5`, `determinis*`, `run to run`, `exported twice`: the only
PostScript byte comparisons in the tree **filter out exactly the lines 1607 is about**.

| helper | file | what it drops |
|---|---|---|
| `ps_filter` | `test_hier_pdf_links_1333.tcl:1240` | every `setlinewidth\|setlinejoin\|setlinecap\|RGB` line — its comment says *"the values move with heap layout, so a byte-for-byte PostScript comparison of this back end is impossible without dropping them"* |
| `opa_l_normps` | `test_op_annot.tcl:2932` | every `<r> <g> <b> RGB` line, for issue 0454, whose header states *"two PS exports of identical content are NOT byte-equal"* |
| `opa_l_print2` | `test_op_annot.tcl:2929` | adds a **warm-up export** to *"settle issue 0454's volatile PS colour into the same slot for both sides of a comparison"* |

**If the over-read came back tomorrow, every row using these would stay green by
construction.** That is the mechanism by which 144 changed lines in every exported file went
unnoticed for as long as they did. Two of those three helpers exist *because of* this defect
and are now dead weight; a third copy is the failure mode to avoid.

One more: `test_callback_argc.tcl:~487` is the tree's only same-process double `print ps`,
and it asserts the two files **differ** (`$hc_b1 ne $hc_b2`) to prove `xschem fill_type` did
display-free work. Against a non-deterministic exporter that row could have passed with
`fill_type` doing nothing at all. **`dc23e730` silently de-vacuified it** — it now passes for
the right reason, and nothing in the tree records that.

Also missing: **`print ps` and `print svg` are unasserted as export paths** (the only rows
asserting their content are `test_nh_export_custom_color.tcl` E1–E6, which check for one
specific hex value and self-skip without Tk/X — and with an uppercase `SKIP:` that
`summarize_all` does not collect); **no `.svg` golden anywhere** (`tests/headless/gold/` holds
six files, all netlists or text); and **no static row for the repair** — `V11` greps
`psprint.c` for 1342's `set_lw()` clamp and `V13` greps `save.c`, but nothing greps for
`if(pixel >= (unsigned int)cadlayers) return;`.

## A determinism row is feasible with NO filtering at all

In-tree binary, `HOME` on scratch, one export per child, **five separate children each
writing to a different directory**, on `LCC_instances.sch`:

| verb | distinct md5s / runs |
|---|---|
| `print ps` | **1 / 5** |
| `print svg` | **1 / 5** |
| `hier_psprint` | **1 / 5** |

Searched for and **absent**: absolute paths, `$HOME`, `/tmp`, the scratch path (0 matches —
independently confirmed by the md5s agreeing across five *different* output directories), pid,
temp-file name, font-cache id, `%%CreationDate`, `%%For`. The PS header is fixed text
(`%%Creator: xschem`, no version string).

**One date field exists and it is not a wall clock.** `T {@time_last_modified}` at
`xschem_library/devices/title.sym:38`, instantiated by `LCC_instances.sch:280`, renders the
schematic file's **mtime** (`stat` matches to the second). Harmless for md5-across-runs;
**fatal for a committed golden**, which would redden in every fresh clone — the exact
environment CLAUDE.md says gate figures are taken in.

### Two landmines a naive row would hit, both measured

1. **`hier_psprint` is not idempotent within one process.** Three `hier_psprint` calls in one
   process: run 1 differs from runs 2 and 3 (146088 vs 145896 bytes; 8226 lines of shifted
   coordinates and line widths). That is issue **1341**'s first-walk page scale. Six
   interleaved `print ps`/`print svg` calls in one process: 1 md5 each. **So the row must be
   one export per child** — which `child_export` already gives for free. An in-process loop
   would redden for a reason that has nothing to do with 1607.
2. **`ps_strip_nav` is not the place for this.** It removes the navigation strip so *counts*
   keep their meaning; it is about a feature's annotations, not volatility. A determinism row
   wants the raw bytes, strip included.

## Item 4 is assertable in one row, without moving the suite to `dcases`

Same fixture, headless vs `:99`, 3 children: `:99` is deterministic too (**1 md5 / 3**, all
three verbs, 0 out of gamut). The arms differ — but for `print ps` **the entire difference is
one line** (`0.463376 setlinewidth` vs `0.520833`), for `print svg` one (`stroke-width:
0.667261` vs `0.75`), and for `hier_psprint` 11932 lines of arm-dependent page scale (1341 /
1345).

**The colour content is arm-independent for all three verbs**: the sorted multiset of ` RGB`
lines is md5-identical across arms for `print ps` (`1a8e9805…`) and `hier_psprint`
(`b9f1f0e9…`), and the sorted multiset of `#rrggbb` tokens is md5-identical for `print svg`
(`9f6a42f4…`). So the multiset is the largest invariant surviving the arm difference, and it
is precisely what the over-read corrupts.

Cost: ~0.1 s per child on a suite-written fixture, ~0.2 s on `LCC_instances`.

## Placement: extend the suite, do not add one

`run_regression.tcl` builds `tcases` (3) + `hcases` (**78**) + `dcases` (**15**) +
`xschemtest` = **97 cases**, the recorded baseline. Registering one new suite in `hcases`
would cost `cases=` 97 → 98, `blocks=` 96 → 97, `wc -l` 290 → 293. **Extending
`test_ps_valid_1350` costs nothing in those numbers** — only the suite's own
`RESULT: ALL PASS (21 checks)` moves to `(26 checks)`, which is exactly the coverage signal
issue 1487 built that line for.

Row numbering in that file means *when written*, not *where placed* — physical order is
V1…V11 **V21** V12 V18 V19 V13 V14 V20 V15 V16 V17. So new rows are **V22 onward**, appended
beside V19/V20 where the 1353/1607 argument already lives.

Two mechanical requirements:

1. **The `ps2pdf` gate at line 104 exits before every row**, and its skip text claims
   *"NONE of this suite's 21 rows ran"*. The new rows need no ps2pdf, so leaving them below
   the gate would skip rows that could have run and make the skip text a lie. Move the guard
   to immediately before the `V1` block (helpers stay above it), and re-word it to name only
   the distilling range.
2. **`child_export` hardcodes the verb** at line 139. Give it two optional arguments —
   `{verb hier_psprint}` and `{arm nogui}` — defaulting to today's behaviour so all 21
   existing rows are untouched.

## The rows

* **V22** — two separate `--nogui` children export the **same** sheet; assert byte-identical,
  **no filtering**, for `print ps`, `print svg` and `hier_psprint`. Fixture: V19's existing
  `txtop.sch`/`txt.sym` pair, purpose-built to make the pseudo-layer restore fire four times.
  Measured 1 md5 / 6 children. Reddens on any heap-dependent value reaching the file — the
  pre-fix state was 6 md5s in 9 runs — and on anyone adding a timestamp, pid or path.
* **V23** — the same property on the shipped `LCC_instances.sch`, the sheet the issue
  measured. Separate from V22 on purpose: it carries `title.sym`, so it proves determinism is
  assertable on real content **where a committed golden would redden in every clone**.
* **V24** — the static fence for the repair, in V11/V13's shape: assert `set_ps_colors()`
  contains `if(pixel >= (unsigned int)cadlayers) return;`. Reddens on a one-line deletion.
  It exists because the repair is the *third* answer to item 1 — a future reader who prefers
  a zeroed entry should have to redden a named row, not just edit a line.
* **V25** — the SVG half, as a **shape** row, because a range row is impossible there
  (`#%02x%02x%02x` makes any byte-sized garbage syntactically valid). Assert every
  `#[0-9a-fA-F]+` token is exactly six digits, and every `class="lN"` a drawn element
  references resolves to a class the file's own `<style>` block defines. `Svg_color`'s members
  are `int`, so a value > 255 emits more than two digits per channel. Reddens if any of the
  four clamps at `svgdraw.c:947`, `:1007`, `:1048`, `:1356` is removed — which is the only
  thing standing between the SVG back end and this defect.
* **V26** — item 4 in one row: export headless and on the dev display, assert the two
  **colour multisets** are identical (sorted ` RGB` lines for PS, sorted `#rrggbb` tokens for
  SVG). Not byte equality — the arms genuinely differ, and only by line width / page scale.
  ⚠ Spawn the display child through `tests/headless/devdisplay.sh exec` from inside this
  `hcases` suite rather than moving the suite to `dcases`; self-skip with a lowercase `skip:`
  line naming V26 when `devdisplay.sh status` is not alive. That keeps 97/96 and makes
  `skips=` environment-dependent by one, which CLAUDE.md already says it is.

Expected: `cases=97 blocks=96 counted_failures=0 skips=8` unchanged on this box, suite
`RESULT:` `(21 checks)` → `(26 checks)`; `skips=9` with V26 named on a box with no dev display.

## Helpers to reuse, and two to read and NOT copy

Reuse `child_export` (parameterised), `slurp` (binary-safe; `eq` on two slurped strings *is*
the assertion, no md5 shell-out needed), `wsch`/`wsym` (fixture writers — V19's fixture at
lines 483–489 is already the shape V22 needs, and reusing it is what makes V19 and V22
comparable), `check`, and `test_scratch` from `scratch.tcl`. `distil`/`clean` are **not**
needed by any new row, which is what keeps them off the ps2pdf gate.

Do **not** copy `ps_filter`, `opa_l_normps` or `opa_l_print2`. Whether to delete them now
that `dc23e730` has landed is a small follow-on — `ps_filter` also masks 1342's
`setlinewidth` garbage, which V11/V21 fence independently.

## NOT MEASURED

This crew did not build a sabotaged binary to watch the proposed rows redden; in-tree edits
were forbidden and a clone build costs minutes. The reddening evidence for V22/V23 is the
issue's own 6-md5s-in-9-runs figure and receipt B's 9-in-9. **The implementation stage owes
the sabotage.**
