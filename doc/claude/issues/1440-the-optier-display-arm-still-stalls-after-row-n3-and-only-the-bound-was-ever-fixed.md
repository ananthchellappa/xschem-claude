# 1440 — `test_ase_optier_0963`'s display arm still stalls after row N3, and only the bound was ever fixed

**Filed by the driver, not fixed.** Reproduced again on 2026-09-13 by the Stage 7 task-2
crew (issue 1439) while running the ASE family on `:99`. **The stall itself has never had
an issue number** — it has a write-up
(`doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`), a paragraph in
`CLAUDE.md`, and an issue that bounds it (**1403**) but does not explain it.

**Branch:** fluid-editing.

## Why this is separate from 1403

Issue **1403** is about the **absence of a bound**: `tests/run_regression.tcl` had no
`timeout` on any of its four `exec` sites and no waiter had a deadline, so a hung suite was
indistinguishable from a slow one. That is **fixed** — `t1_timeout` (900 s default) prefixes
all four sites, rc 124 is counted as a `FAIL` that says `TIMED OUT`, and the in-suite
watchdog names the last row printed.

**1403 makes the stall a named outcome. It does not stop the stall.** That is exactly the
distinction `CLAUDE.md` draws in its own words — *"treat a bug that only `:0` can reproduce
as a test defect too: the fix is to force the race deterministically, not to hope an
environment supplies it"* — and nothing has forced this one.

## What it does, measured three times now

| when | arm | rows printed | stops after | outcome |
|---|---|---|---|---|
| 2026-09-11 | display | **86 of 103** | **N3** | sat **8 h 07 m**, no bound, no `ngspice` alive |
| 2026-09-11 | display | 86 of 103 | N3 | reproduced while writing the 1403 fix |
| **2026-09-13** | display (`:99`) | **91 of 108** | **N3** | **rc 124** at 260 s, bounded and named |

⚠ **The suite has grown by five rows since the first sighting and it still stops after
N3.** That is the load-bearing observation in this file: the stopping point is not drifting
with the row count, so it is a property of what N3 leaves behind rather than of where the
suite happens to be when it runs out of something.

**The headless arm is unaffected** — `test_ase_optier_0963` is **ALL PASS (108)** headless
and is in T1, which runs the headless arm only. So this costs nothing in T1 and everything
in `full_audit.sh` and in any `run_suites.sh` display run, which is where a person looks
before believing a GUI change.

## Why it has stayed invisible

Three separate things each hide it:

* **T1 does not run this arm.** `run_regression.tcl`'s `dcases` is deliberately short
  because the display arm costs wall-clock (`:110`), so the routine number nobody doubts
  never touches it. (That is the third shape recorded against issue **1421**.)
* **It is not the 1402 flap.** Issue **1402** is `test_ase_optier_0963` going red on
  X1/X2/X7 under load — a *convergence* flap on the bandgap bench, which reds and passes.
  This is a **stall**, on a different arm, always at the same row, and the two have been
  conflated in at least one report.
* **Since 1403 it looks handled.** A `TIMEOUT | test_ase_optier_0963` line reads like the
  harness working, and it is — the harness is working. The suite is not.

## What is owed

⚠ **This needs a ruling before it needs a fix**, which is why it is filed rather than
chased: the honest options are not equivalent in cost.

1. **Force the race deterministically** in the suite, as `CLAUDE.md` prescribes and as
   `test_calc_skeleton` S12 did for the Calculator's `:0`-only failure. Most work, best
   outcome, and the only one that leaves the display arm trustworthy.
2. **Bound and skip**: mark row N3's successor as display-arm-skipped with the reason, so
   the arm completes and says what it did not run. Cheap, honest, and leaves a hole.
3. **Leave it**, and accept that this suite's display arm is a 260-second `TIMEOUT` every
   time anyone runs the family on `:99`.

Recorded with `owed.sh add rule 1440`. Until it is answered, **any report that says the ASE
family is green on the display arm must name this suite as the exception**, the way the
1439 receipt did.
