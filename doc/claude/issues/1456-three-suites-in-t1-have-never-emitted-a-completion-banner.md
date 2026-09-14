# 1456 — three suites in T1's case list have never emitted a completion banner, so T1 has not been at zero since stage 7

**Status:** fixed in this commit; filed because the *reporting* failure around it is the real finding
**Filed:** 2026-09-13, by the driver of the ASE-L analyses batch
**Area:** tests / harness
**Related:** 0689 (the same class, inverted), 0420 / 0492 / 0629 (0689's four filings), 0990, 1455

## The defect

`tests/headless/test_ase_optsheet_1441.tcl`, `test_ase_effective_1442.tcl` and
`test_ase_meas_1443.tcl` each end with

```tcl
if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
```

and **no `OVERALL:` line at all**. `tests/banner_rule.tcl`'s `banner_complete` requires a
whole-line `OVERALL: ok`, and `regression_case_failed` counts a case with no completion banner as
a failure **however green its own checks are**. So all three have been scored a `HARNESS … did not
complete cleanly (exit=0, OVERALL_ok=0, died=0)` failure on **every** run of
`tests/run_regression.tcl` since each joined its case list:

| suite | joined T1 in | stage |
|---|---|---|
| `test_ase_optsheet_1441` (both arms) | `f91c36ae` | 7 |
| `test_ase_effective_1442` | `1a5fefec` | 7 |
| `test_ase_meas_1443` | `3f31a33b` | 8 |

`git log -S'OVERALL'` on all three prints nothing: they never had one. A sweep of **every** case in
`run_regression.tcl`'s two lists finds exactly these three and no others, so the defect is bounded.

**The fix is one line per file**, the shape 131 other sites in this tree already use:

```tcl
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
```

Verified: all three now print `OVERALL: ok`, and `banner_complete` accepts it, rejects
`OVERALL: notok`, and rejects the no-banner body — so the fix is a change of verdict and not of
wording.

## ⚠ The finding that matters more than the fix

`tests/run_regression.tcl` prints only `Start …` / `Finish …` to stdout, **exits 0 whatever
happens**, and writes every verdict — and the `Total num fail:` counters — to **`tests/results.log`
and nowhere else**.

The driver of this batch read T1's *stdout capture*, grepped it for `FAIL` / `FATAL` / `TIMED OUT`,
found nothing, and reported **"rc 0, zero counted failures"** — four times in one day, in four
ledger entries and four commit messages. The grep was of a file that cannot contain a verdict. One
of those entries went further and recorded that those three strings *"appear zero times in the
log"* as though it were a measurement; it is a check that cannot fail, which is this batch's own
first-named failure mode, committed by the person auditing for it.

> **The rule: T1's answer lives in `tests/results.log`.** Not in its stdout, not in its exit code.
> `grep -cE 'FAIL$|GOLD\?|RESULT\?|^FATAL' tests/results.log`, then read the `Total num fail:`
> lines, then name any case that is not 0.

`doc/claude/ase_analyses_batch/LEDGER.md` carries the corrections in place, each pointing at the
block *T1 HAS NOT BEEN AT ZERO SINCE STAGE 7*. What was actually true on each of those runs is
**rc 0, the expected case count, and no NEW red attributable to the commit** — a real thing to have
measured, and not what was written.

## Why this is 0689's family, inverted

Issue **0689** was the same red from the other side: `run_regression.tcl` carried a private
completion pattern anchored at both ends, so suites that appended a check count to a banner they
*did* emit could never match it. That standing red was filed **four times** (0420, 0492, 0629,
0689) and waved through as furniture each time, and `CLAUDE.md` now carries a paragraph about it:
*"a standing red is a defect, not furniture — it is the one place a real regression hides in plain
sight."*

This is the mirror image: the reader is correct and three suites never reported. The consequence is
identical, and so is the way it survived — **everybody read the summary nobody wrote**.

## What is still open

Nothing of this issue. The other half of the same T1 read — row **X7** of
`test_ase_optier_0963`, which failed on a solo run and passed standalone — is issue **1455**.
