# 0867 — two concurrent `run_regression.tcl` runs in one tree report 25 phantom FATALs

STATUS: **OPEN — measured 2026-08-27, NOT fixed.** Harness defect, unrelated to
the feature work that found it (item 0864's verification). Filed rather than
fixed because it touches the shared test runner and belongs in its own change.

## What it looks like when it bites

`tests/results.log` carries a block of

```
FATAL: <a shell command> : exit -1
```

lines and `run_regression.tcl` **counts every one of them** (`^FATAL` is one of
its four counted shapes). A run that should be at the branch's ZERO baseline
reports 25 failures. Nothing crashed. On this branch, where the standing rule is
that *"a standing red is a defect, not furniture"*, that is the most expensive
possible way to be wrong: it reads exactly like 25 real crashes.

Observed during 0864's verification, with two agents each running
`cd tests && tclsh run_regression.tcl` in the same checkout: one run reported
`FATAL: 25`, the other — the one that finished last — reported ZERO. The
arithmetic closes: `open_close.log` says 1899 files were produced, the run that
collated got 1874, and 1874 + 25 = 1899.

## Mechanism

`tests/open_close.tcl` scopes its scratch by TEST NAME, not by process:

```tcl
tests/open_close.tcl:32   file delete -force $testname/results
tests/open_close.tcl:38   set workroot "$testname/results/.work"
tests/open_close.tcl:58     set status  "$cwd/$workroot/$idx.status"
tests/open_close.tcl:63     set tmpdir  "$cwd/$workroot/$idx.tmp"
tests/open_close.tcl:108  file delete -force $workroot
```

Two runs therefore share one `open_close/results/.work`. Whoever starts second
deletes the first one's tree; whoever finishes first deletes it again at :108.
`read_job_status` (`tests/test_utility.tcl:118`) returns **-1** for a status file
that has gone missing, and `open_close.tcl:98-101` turns every -1 into a counted
`FATAL: ... : exit -1`.

The runner already knows how to do this properly one file away:
`run_parallel_cmds` writes `.parallel_jobs.[pid]` (`tests/test_utility.tcl:82`),
pid-scoped precisely so concurrent runs cannot collide. `$workroot` never got
the same treatment.

## Why it is worse than lost bookkeeping

`$workroot/$idx.tmp` is each job's private `XSCHEM_TMP_DIR` — the temp/undo
directory xschem creates on load. Two runs sharing those directory names are not
merely losing exit codes, they are handing two live xschem processes the same
undo scratch. The visible symptom is the phantom FATALs; the invisible one is
cross-run corruption of temp state.

## Fix shape

Give `$workroot` the established pid scope, e.g.
`set workroot "$testname/results/.work.[pid]"`, and leave the `results/`
directory deletion at :32 alone or make it likewise unshared. One line, the same
pattern `run_parallel_cmds` already uses.

## Acceptance

* Two `tclsh run_regression.tcl` runs started ~30 s apart in one tree both
  report ZERO counted failures, and neither `results.log` contains
  `FATAL: ... : exit -1`.
* The status/tmp paths of a run contain that run's pid.
