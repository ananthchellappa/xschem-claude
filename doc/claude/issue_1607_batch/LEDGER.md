# Ledger — issue 1607 batch

Receipts land in `receipts/`. One row per handed-off task, collected by the driver.

| # | task | crew | receipt | verdict |
|---|---|---|---|---|
| A | item 2 — measure the `svgdraw.c` path | `measure:svgdraw` | `receipts/A-svgdraw.md` | **collected — NO DEFECT**, 8 valgrind runs at 0 errors, with a control proving the instrument catches the defect (432 errors when the guard is reverted) |
| B | item 4 — is the display path clean or only repeatable | `measure:ps-display-arm` | `receipts/B-display-arm.md` | **collected — the display arm was NOT clean**: reverted, `:99` gives 432/699 valgrind errors and 9 distinct md5s in 9 runs. The fix changes nothing rendered: 36/36 pages identical |
| C | item 3 — the coverage gap, surveyed | `survey:suite-gap` | `receipts/C-suite-gap.md` | **collected** — the gap is worse than "no row": three existing helpers filter out exactly the lines this issue is about. Five rows specified, V22–V26 |
| D | implement V22–V26 | `impl:V22-V26` | receipt folded into `../LEDGER.md` below | **collected — `ALL PASS (26 checks)` on both arms**, 21 → 26, and the crew ran its own S1 sabotage: 6 FAILED / 20 passed |
| E | sabotage-verify the new rows | `sabotage:V22-V26` | `receipts/D-sabotage.md` | **collected — and it condemned row V25 as a sampler.** S1 reddens 6 of 26; S2 reddens nothing in the canonical spelling |
| F | record the svgdraw safety argument in source | `notes:svgdraw+callback` | folded below | **collected** — comment-only, `src/svgdraw.c` + `test_callback_argc.tcl`, 28 insertions, 0 deletions |
| G | **row V27** — the static fence E's measurement showed was needed | `v27` | folded below | **collected — `ALL PASS (27 checks)` on both arms**, and it found a decoy the driver's spec missed |

## What the sabotage changed about the plan

**The driver's row V25 does not do what the driver designed it to do, and the crew proved it
with a one-byte experiment.** V25 was meant to fence the four `svgdraw.c` clamps. Measured: the
`svgdraw` clamp deletion is **invisible to the suite as committed** (3 runs, 3 × ALL PASS,
because nothing the suite exports carries an out-of-range `layer=` token), and even with a
forced fixture the canonical spelling stayed green **11 runs out of 11**. Adding one
environment variable of **one byte** flipped V25 green → red → green.

The over-read is **deterministic in the source and random only in its consequence**, so the
matching instrument is static. Row **V27** — assert all four clamps are present — is stage G.
V25 is kept as the well-formedness row it actually is, with its text corrected.

Two consequences the driver has already applied:

* `src/svgdraw.c`'s new comment cited V25 as the fence. **Corrected** to cite V27, and to say
  that valgrind is only reliable at index `== cadlayers` (redzone) and silent 3 runs in 4 at a
  far index — so the verdict rests on the clamps, not on the valgrind zero.
* The issue file carried the same overstatement. **Corrected** with the three measurements.

## Pre-existing findings the crews tripped over — NOT this batch's, recorded so they are not lost

1. **`tests/headless/test_scratch_home_note.tcl` fails row `C1` at HEAD**, reproduced with the
   batch's edits stashed. `t1_counted` stays at its `-1` sentinel, meaning the lifted
   `summarize_all` *raised* when called rather than miscounting. ⚠ The suite is **not registered
   in `run_regression.tcl`**, so this is not a T1 counted failure — which is also why nobody has
   noticed. Someone should look.
2. **`tests/headless/test_nh_export_custom_color.tcl` is not registered either** (see E2b). It is
   the only place in the tree asserting the content of a `print ps` / `print svg` file.

### ⚠ The driver checked this before writing it down, and the first framing was wrong

The tempting headline was "unregistered suites the gate never executes", and the sweep looked
alarming: **412 suites match `tests/headless/test_*.tcl` and only 76 are named in
`run_regression.tcl` — 336 unregistered.** But `tests/headless/full_audit.sh` selects
`all test_*.tcl` by directory glob (`mapfile -t files < <(ls "$HERE"/test_*.tcl | sort)`), so
**those 336 are run — by a different driver.**

So the accurate statement is much narrower, and it is about *which* driver: T1, the per-commit
gate whose zero this project treats as the baseline, exercises 76 of the 412; the other 336 are
exercised only by `full_audit.sh`, which is a longer audit nobody runs per commit. That is why
`test_scratch_home_note`'s `C1` red can sit at HEAD without T1 noticing, and why the one suite
asserting `print ps` / `print svg` content is not in the gate. A worthwhile question for its own
day — *which of the 336 deserve promotion into `hcases`?* — and **not** the 336-defect finding
the raw number suggests. Recorded this way because the overstated version would have been the
kind of number that gets quoted back for months.

## What the measurement round settled

**E1 held, with a better reason than the driver's.** The prediction was "no restore site plus
four clamps". The crew found the fact underneath: `psprint.c` is a **stateful** back end whose
text passes must restore a sticky colour with the raw incoming layer, and `svgdraw.c` is a
**stateless, class-based** one that emits its colours once into a CSS stylesheet. The
`svg_draw_symbol(c + 1, …)` call is byte-for-byte psprint's shape; **the sink it fed does not
exist in svgdraw.** That converts item 2 from "unmeasured, not clean" to "structurally
absent, and the four clamps that keep it absent are now fenced by a row".

**E2 held and is now measured on the arm nobody had measured.** Suppressing the pseudo-layer
colour is render-identical on the display arm too — 36 of 36 pages byte-identical in both
`pgmraw` and `ppmraw`, because the whole textual diff is 144 dead ` RGB` lines and no drawing
operator moves.

**Item 4's suspicion was right and the driver's earlier reading of it was too comfortable.**
The display arm was not fine; it was reading garbage the whole time and the two runs that
agreed simply landed on the same value twice. With a display it is **worse** than headless —
144 out-of-gamut components in 9 of 9 runs versus 4 of 9, and 9 distinct md5s versus 3.

**E3 is answered against the issue's own wording.** Item 3 asks for "a golden for the headless
export path". A committed golden is the wrong instrument, for two measured reasons: every
sheet carrying `title.sym` renders the schematic's **mtime** via `@time_last_modified`, so a
golden reddens in every fresh clone — the very environment gate figures are taken in — and the
colour tables derive from user preferences (`light_colors` / `tctx::colors`, switched by
`dark_colorscheme`), so a golden would pin the environment rather than the exporter. The
property the issue's headline actually names — *the same schematic exported twice produces two
different files* — is assertable with no filtering and no golden at all. That is V22/V23.
This is test-harness engineering, so it is decided here rather than queued as a ruling.

Baseline to gate against, from `cff55068`: `cases=97 blocks=96 counted_failures=0 skips=8`
(`tests/results.1185647.log`). The step is not a constant — a suite in both `hcases` and
`dcases` costs two cases and one headless self-skip; one in `hcases` alone costs one case
and no skip.

## Stage G — the fence needed scoping, and the driver's spec would have shipped a fence that fenced nothing

The driver specified V27 as "assert each of the four (variable, fallback) pairs is individually
present". The crew measured that it is **necessary but not sufficient**: `svgdraw.c` has a `#if 0`
region — the disabled "determine used layers" walk — containing a **byte-for-byte copy of the
fourth clamp, double space included**. A whole-file regexp for it is **green on a copy whose live
clamp has been deleted**. V27 therefore strips comments and `#if 0` regions with a depth-counting
`#if`/`#endif` scan before matching.

Two further controls, each decided by measurement rather than taste:

* a **single-space** regexp for that clamp is **red on the file as shipped** — the double space is
  real — so the matcher collapses whitespace and joins tokens with an *optional* space, which also
  survives `if (x` and `textlayer=c_for_text` reformats;
* a row asserting "**four** clamps are present" is **green** on a copy with one clamp deleted and
  an unrelated one added elsewhere. So V27 asserts the four **by name** and the only count it
  checks is the length of its own table, which stops a silently shortened table from making the
  row vacuously true.

Sabotage: **4 of 4** clamp deletions redden V27, each naming the missing clamp in its detail field,
and the row is green against the real file. Verified end to end as well as at predicate level, via
a symlink mirror (`cp -rs`) of `tests/` and `src/` so the real binary ran against a modified
`svgdraw.c` with no `src/` edit and no rebuild: control `3 FAILED`, all four sabotages `4 FAILED`,
the extra failure being V27. **V25 stayed green through all four** — independently reproducing
receipt D's S2 result and extending it from one clamp to all four.

The crew also caught the driver quoting a garbage token (`#666e5100`) whose provenance was not in
any receipt, and **declined to cite it without a source** rather than passing it along. The
verbatim line it came from is now in `receipts/D-sabotage.md`. That is the second time this batch
that a crew refused to inherit an unsourced figure from the driver.

## Resume point

If this batch is picked up cold: Stages A, B and C were dispatched together as one
measurement round from `cff55068`, with the driver's Stage A prediction registered in
`DECISIONS.md` E1 beforehand. Nothing has been committed yet. The next action after the
receipts land is to decide Stage A on the evidence, then implement whatever Stage C's
survey says is missing.
