# 0867 — two concurrent `run_regression.tcl` runs in one tree report 25 phantom FATALs

STATUS: **FIXED 2026-09-17** by the harness concurrency batch — `5f7164d4` and
`43b40f04`. See "Closed" at the bottom, issue **1476**, and
`doc/claude/harness_concurrency_batch/`.

~~OPEN — measured 2026-08-27, NOT fixed.~~ Harness defect, unrelated to
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

## Closed — 2026-09-17

Fixed by **`5f7164d4`** (per-run results roots, and a job status you can tell apart)
with **`43b40f04`** (the verdict lock). Red suite at **`5114dd8b`**, registered and
verified at **`d4946b61`** — solo T1, **84 cases, ZERO counted failures, rc 0**. The
two faces that were in no issue file are recorded as **1476**.

**Against this file's acceptance, honestly:**

* *"Two runs started ~30 s apart both report ZERO, and neither `results.log` contains
  `FATAL: … : exit -1`"* — met, by making the second run **not run at all**. By
  default it is refused loudly (exit 2, nothing written) so the first run's verdict is
  intact; with `T1_LOG_LOCK_WAIT` set it queues and both produce complete verdicts,
  the earlier one preserved as `results.<pid>.log`. The phantom `exit -1` is gone
  regardless of which arm is taken: **656 phantoms of 1500 jobs → 0, in 10 of 10
  runs.** A missing status file is now `-1001` and reported as *"NO STATUS FILE …
  this job's exit code was never written or was deleted by another run in this tree"*,
  never as `exit -1`.
* *"The status/tmp paths of a run contain that run's pid"* — met: `<case>/.work.<pid>`.

⚠ **But this file's proposed one-line fix was measured to be a NO-OP, and that is the
part worth carrying forward.** It proposed
`set workroot "$testname/results/.work.[pid]"` — pid-scoping the scratch *inside*
`results/`. Measured on one staggered pair: today's shared path gave **660** phantoms,
this file's shape gave **658**, and only moving the workroot **out** of `results/`
(`"$testname/.work.[pid]"`) gave **0**. The shared object was never `.work`; it was
`$testname/results` itself, which every run wiped on the way in. A fix taken from this
file as written, verified by inspection, would have shipped and changed nothing. It is
the same lesson as **0990**'s refuted "a row would be expensive": an unmeasured
sentence in an issue file is not a finding.
