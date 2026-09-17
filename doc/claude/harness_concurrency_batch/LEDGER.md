# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

| id | task | crew status | commit | rows red→green | issues | notes |
|---|---|---|---|---|---|---|
| — | batch scaffolding | driver | — | — | — | PLAN, BRIEF, DECISIONS, LEDGER written; owed ledger backed up; R1 filed as a ruling debt against 0990 |

## Pre-batch baseline (driver, 2026-09-16)

* Solo T1: `rc=0`, **410 s**, `Start=83 / Finish=83`, 82 `Total num fail:` lines,
  **ZERO counted failures**, `results.log` mtime moved. T1 is at its zero baseline —
  any red from here is this batch's.
* Defect reproduced 3/3 at 3 s, 6 s and 9 s staggers: 407 / 432 / 757 phantom
  `exit -1` FATALs in the collating run, second run dead at `open_close.tcl:32` every
  time, 1 / 5 / 6 result files silently lost to the cleanup awk.
* Tree clean but for four pre-existing untracked dirs (`.xschem/`,
  `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`, a sky130 debug dir).

## Resume point

Next task to dispatch: **A1** (the red suite).
