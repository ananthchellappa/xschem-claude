# Ledger — issue 1603 batch

Receipts land in `receipts/`. One row per handed-off task, collected by the driver.

| # | task | crew | receipt | verdict |
|---|---|---|---|---|
| A | rebuild the typeless-symbol fixture; drive every back end; count real crashes | `measure:fixture+drive` | `receipts/A-measure-and-triage.md` | **collected — 2 of 26 driven**, both with gdb backtraces; the issue's premise about NULL corrected |
| B | static triage of the netlister cluster | `triage:netlisters` | folded into receipt A | **collected — 16 of 19 are false positives**; 2 need guards, 1 must stay unguarded |
| C | static triage of draw / editprop / scheduler / token | `triage:rest` | folded into receipt A | **collected** — `draw.c` is a wrong-field guard, `scheduler.c` ×3 is one decision, `token.c` ×3 unreachable by caller contract |
| D | adversarially refute every claim | `verify:refute-claims` | folded into receipt A | **collected — refuted no verdict, refuted the EVIDENCE for several**, and turned the fragility argument into a one-token measurement |
| E | land the four guards, document the invariant, fence it all | dispatched | — | in flight |

## What the measurement round settled, and it reorders the issue completely

**The netlister cluster was the wrong priority, and the driver said so to the user before
measuring.** The recommendation rested on "19 of 27 sites are in the netlisters, and netlisting
runs headless in every batch flow". The count was right; the implication was not. That cluster
contains **zero** driven defects — 14 sites already guard, 2 are commented-out code, 3 are
unreachable by caller contract. The two real crashes are in `scheduler.c` (`sch_pinlist`, true
headless, two lines of Tcl) and `draw.c` (display, after one ordinary `setprop`).

**The issue's premise about when `type` is NULL was wrong.** A missing `type=` is not enough:
`set_sym_flags()` rewrites it to `""` for any symbol with any global property. The NULL state
requires an **empty or absent `G`/`K` record**. Any future fixture that gets this wrong measures
nothing — which is why the new suite carries a control row proving its own fixture.

**16 of 26 candidates were mis-classified by the original sweep**, not one as the issue conceded,
and six of those were guarded on the *immediately preceding line* at the sweep's own commit. The
sweep's method was the real defect: a `strcmp` regex is blind to `IS_LABEL_OR_PIN`, and that blind
spot hid `netlist.c:1024` — the site that actually faults first, and the only unguarded use of
that macro in the whole of `src/`.

**The defence-in-depth guards are backed by a measurement, not by taste.** One token in
`set_sym_flags` is what keeps three netlister sites safe; flipping it yields two sequential
segfaults. That flip is now the deterministic sabotage for the static rows.

Baseline to gate against, from `73ebbfa0`: `cases=97 blocks=96 counted_failures=0 skips=8`
(`results.1594312.log`, a fresh clone built from scratch at an 84-character path, ran solo,
throwaway home, `elapsed=589s`, `wc -l` 290).

⚠ **Gate in a clone at a SHORT path.** A clone under the session scratchpad reaches 173
characters and makes T1 report 11 failures that are not real — `test_op_annot` and
`test_annot_hier_0911` compare a status message the product deliberately elides past the status
bar's width. Full write-up in `CLAUDE.md` and
`doc/claude/issue_1607_batch/LEDGER.md`.

## Resume point

If this batch is picked up cold: stages A, B and C were dispatched together as one measurement
round from `73ebbfa0`, with D pipelined behind B and C to refute their claims, and the driver's
prediction registered in `DECISIONS.md` F1 beforehand. Nothing has been committed. The next
action after the receipts land is to decide the semantic groups on the evidence, then implement
the guards group by group with a row per group — never a blanket substitution (F2), and never a
guard without a row that reddens on its removal (F3).
