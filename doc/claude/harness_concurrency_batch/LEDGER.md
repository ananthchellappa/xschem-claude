# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

| id | task | crew status | commit | rows red→green | issues | notes |
|---|---|---|---|---|---|---|
| — | batch scaffolding | driver | `78d06f1e` | — | — | PLAN, BRIEF, DECISIONS, LEDGER; owed ledger backed up; R1 filed as a ruling debt against 0990 |
| **A1** | the RED suite | **DONE** | — | 20 checks, **13 RED / 7 green**, identical across 4 consecutive runs, 7.4–7.5 s | 1476 | `tests/headless/test_regression_concurrency_1476.tcl`, 485 lines. All four faces reproduced. B1 turns 11 rows, C1 turns 2. The 7 greens are deliberate guard/non-vacuity rows — incl. `V1b`, which reds if C1 ever renames `results.log`, as R1 forbids. Private miniature fixture; the real `tests/open_close/` tree is never touched. |

## ⚠ A1's corrections to PLAN — B1 depends on all four

1. **Neither fix shape in PLAN closes the defect.** Measured over three configurations
   of the same staggered pair: today's `"$testname/results/.work"` → **660** phantoms,
   B dead; `"$testname/results/.work.[pid]"` — *PLAN's stated minimum* → **658**
   phantoms, B dead; `"$testname/.work.[pid]"` → **0** phantoms, B still dead 2 of 3.
   **Pid-scoping inside `results/` is a no-op**, because the shared object is
   `$testname/results` itself, which every run wipes at startup. A fix measured once
   on that shape looks green and is not.
2. **Face 4 is an ERASURE, not a corruption.** The verdict file ends up 13268 bytes,
   zero NUL bytes, run A's verdict complete and well-formed — it is run B's entire
   verdict that vanishes while B exits 0. A1's first draft had two rows keyed on
   corruption/mixture that shipped GREEN and proved nothing; they were rekeyed.
3. **Face 1 is mis-attributed in PLAN.** PLAN blames the end-of-run delete at `:108`.
   In every pair run B **died at startup and never reached `:108`** — yet A still lost
   639–670 status files, all to B's partially-completed *startup* wipe.
4. **Face 3 is bigger and needs no concurrency at all.** gawk's "cannot open file" is
   **fatal**, so one missing file aborts the whole `xargs -n 64` batch and leaves
   present files un-normalised too. Reproducible in two awk spawns. **B1's file list
   must include `test_utility.tcl:102-114`**, which PLAN omitted.

Every line number PLAN cited checked out with no drift. 0990's "two regressions at
once, expensive" is refuted harder than PLAN put it: one miniature pair, **2.4 s**, no
xschem process at all.

## ⚠ Standing red, by design, until C1 lands

The suite is deliberately not in `hcases` (that is C1's file), but `full_audit.sh:393`
picks it up via its `ls test_*.tcl` glob. **Any full audit between now and C1 shows 13
RED rows by design.** That is the suite working — but it reads exactly like a
regression, which is the standing-red-as-furniture trap. Nobody should carry this
count forward as "known".

## Pre-batch baseline (driver, 2026-09-16)

* Solo T1: `rc=0`, **410 s**, `Start=83 / Finish=83`, 82 `Total num fail:` lines,
  **ZERO counted failures**, `results.log` mtime moved. Any red from here is ours.
* Defect reproduced 3/3 at 3/6/9 s staggers: 407/432/757 phantom `exit -1`, second run
  dead at `open_close.tcl:32` every time, 1/5/6 result files silently lost.

## Resume point

Next task to dispatch: **B1** (faces 1–3), carrying A1's four corrections — in
particular that the workroot must move **out of** `results/`, and that closing face 2
needs the startup wipe addressed, not the workroot.
