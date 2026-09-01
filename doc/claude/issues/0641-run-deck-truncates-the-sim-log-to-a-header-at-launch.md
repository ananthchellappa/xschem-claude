# 0641 — `run_deck` truncates the sim log to a header at launch, destroying the previous run's log

Status: **OPEN — measured, not fixed. INTRODUCED by 0618's fix**, knowingly.
Filed by the 0617+0618 crew, 2026-08-23. Related: **0618**, 0207.

## What changed

0618 needed a log to exist even when the simulator never launches (`execute` returns
-1, `ase::run_done` never fires, and **before the fix no log file was written at
all**). So `ase::run_deck` now opens the log `w` and writes the header immediately
before `eval execute`; `run_done` later rewrites the whole file with header +
delimiter + output + footer.

## The cost, measured

* The **previous run's complete log is destroyed the moment the next run starts**, and
  the file stays header-only for the whole duration of the run. Before, the old log
  survived until the new run finished.
* `ase::ui::show_log` (`src/ase_window.tcl:3590`) falls back to the **file** whenever
  it has no run_id, so a mid-run *Simulation → Log* on that path can show a header and
  nothing else. (During a run with a run_id it streams `execute(data,$id)`, which is
  unchanged.)
* The test suite had to move E2 into its own rundir for exactly this reason — see the
  `e2dir` comment in `tests/headless/test_ase_core.tcl`. That is an honest disclosure
  of the same clobber a user sharing a rundir will hit.

## Why it was accepted

The alternatives are worse in different directions. Writing everything only in
`run_done` loses the failed-launch record, which is the case a user most needs.
Appending in `run_done` (mode `a`) breaks `test_ase_cosim`, which calls `run_done` six
times on one path and expects truncation.

## Recommended

Write the launch header to a **temporary** path (or keep it in memory) and move it into
place only when the run either fails to launch or completes — so the previous log is
replaced atomically and never merely erased. Alternatively roll the log (`.log.1`)
before truncating.
