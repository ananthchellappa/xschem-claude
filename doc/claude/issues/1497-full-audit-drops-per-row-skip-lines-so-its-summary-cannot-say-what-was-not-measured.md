# 1497 — `full_audit.sh` drops per-row `skip:` lines, so its `SUMMARY:` cannot say what was not measured

**STAMP:** `v1 claim=open tree=c84aee78 stamped=2026-09-20 fix=untried open=1 by=stranger-reds`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, item E, from
`receipts/E-impl.md` §6/§7 finding 1 and `receipts/E-verify.md` §7 item 2 (found outside the
item, written down rather than fixed on the way past — that batch's acceptance criterion 4).
**Class** harness / verification method: lost coverage that reads as a pass.
**Related, read first:** **1487** (the identical defect in `tests/run_regression.tcl`,
**FIXED** in `c84aee78` — its resolution section is the worked example of how to do this
safely), **1494** (`run_suites.sh` reports a crashed suite as `NORESULT` and throws the crash
text away — same family, different driver, different lost line), **0147** and **0891** (the
printed-but-uncounted precedents), **0805** (`full_audit.sh`'s pass arm is not locked against
the shared banner rule).

---

## The defect

A suite that cannot run a row says so, by name and with a reason, on a line beginning
`skip: ` (the D10 contract: `skip: <row> -- <why>`). `tests/headless/run_suites.sh` echoes
every one of them under the suite's verdict line (D13.11), and since `c84aee78`
`tests/run_regression.tcl` carries them into the T1 verdict and counts them in `skips=`
(issue 1487). **`tests/headless/full_audit.sh` does neither.**

READ at `c84aee78`, by symbol rather than by line:

* Its only skip concept is **whole-suite**. `is_skip` is anchored on
  `^(RESULT: SKIP|SKIP: no X connection|RESULT: ALL PASS \(0 checks, skipped: no X\))`, and
  `classify()` is its only consumer: a run either *is* a skip or it is not.
* The per-test loop prints one line, `printf '%-8s | %s\n' "${STATUS[$name]}" "$name"`. The
  captured output is kept (`OUT[$name]`) **only for `CRASH`, `TIMEOUT` and `FAIL`** — a
  passing suite's output is discarded, so its `skip:` lines are not merely unprinted, they
  are unrecoverable from the run.
* The `SUMMARY:` line is `$PASS pass $FAIL fail $CRASH crash/timeout $SKIP skip`, where
  `$SKIP` counts **suites** that self-skipped entirely, never **rows** that did not run.

MEASURED at `c84aee78`, the whole of it in one command —
`/usr/bin/grep -cF 'skip:' <driver>` over the three drivers:

| driver | occurrences of the literal `skip:` |
|---|---|
| `tests/headless/full_audit.sh` | **0** — the word does not appear in the file at all |
| `tests/headless/run_suites.sh` | 1 (the echo) |
| `tests/run_regression.tcl` | 5 (the 1487 carry arm, its sanitiser and their comments) |

## Why it matters, and it is 1487's measurement again

1487 was filed on a gate whose case logs carried **8** `skip:` lines and whose verdict
carried **0**, with one case quietly running **70** checks instead of 76 because the run's
HOME could not reach the fork ngspice. A full audit is in exactly that position today: its
green `SUMMARY:` line is a claim about correctness that says nothing about coverage, and the
one arm that could answer *"did this run measure less than the last one?"* throws the
evidence away for every suite that passed.

## Fix direction — PROPOSED AND UNMEASURED

1. **Echo each `skip:` line under the test's verdict line**, as `run_suites.sh` already does
   (one `grep -E` over the captured output, indented under the verdict), which also means
   keeping `$out` long enough to scan it when the verdict is `PASS`.
2. **Add a row-skip tally to `SUMMARY:`**, distinct from `$SKIP`. It must be a *separate*
   number: `full_audit.sh` and `run_suites.sh` deliberately **disagree** about whole-suite
   skips — the audit's own comment records that a *named* test which self-skips is a failure
   to deliver — and a per-row skip is a different thing. Blurring the two would make the
   disagreement unreadable.
3. ⚠ **Two traps, both measured while 1487 was landed, and both apply here.**
   * **A carried line must not be able to score.** `full_audit.sh` has its own EREs
     (`has_failure`, the two crash literals, `is_pass`), and `test_audit_classifier`
     **section K** locks the Tcl banner rule against them. Any echo must sit where it cannot
     reach `classify()`, and the shared rule must not gain a fourth spelling.
   * **Carried text is suite-controlled.** In `run_regression.tcl` a carried line at column 0
     could forge the run's own trailer, which is why `t1_carry_line` rewrites the sentinel
     word at all four carry sites. `full_audit.sh`'s readers are shell greps over a variable,
     so the exposure is different in shape but not in kind: decide deliberately what a suite
     may put into the driver's own output.

## Evidence

`doc/claude/stranger_reds_batch/receipts/E-impl.md` §6 and §7 item 1; `E-verify.md` §7
item 2; issue **1487**'s Resolution section (the same defect closed in the other driver,
with the measurements that say how).
