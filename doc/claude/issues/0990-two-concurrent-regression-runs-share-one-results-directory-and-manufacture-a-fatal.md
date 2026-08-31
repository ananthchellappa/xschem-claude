# 0990 — two concurrent regression runs share one results directory and manufacture a FATAL

**Filed** 2026-08-30, by the item S4c write-up, from two verify passes that hit
it independently in the same session. **Status** open. **Subject**
`tests/open_close.tcl` and the shared `tests/<case>/results/` tree.
**Severity: this fakes a red in the one suite the house rules say must read
ZERO.**

## What happened, twice

Two agents in one crew ran `cd tests && tclsh run_regression.tcl` at overlapping
times. One of them got:

    open_close   Total num fail: 1
    FATAL: 10.  Please search for FATAL in its output file for more detail

A column-0 `FATAL` and a nonzero count is, by `tests/banner_rule.tcl` and by
CLAUDE.md's own rule, a **counted failure** — the thing this branch is told never
to wave through. It is not a failure. Re-run alone, `open_close.tcl` produces
**0 FATALs and 1895 result files**, against 1885 in the contended run: exactly
the 10 that "failed" are the 10 that went missing.

## The mechanism, read out of the source

`tests/open_close.tcl:38`

    set workroot "$testname/results/.work"

A **fixed path with no pid and no run id**. Each parallel job writes its exit
status to `$cwd/$workroot/$idx.status` (`:58`), the run reads them back through
`read_job_status` (`:98`), and at `:108` the run ends with

    file delete -force $workroot

So when run A finishes, it deletes the status directory **run B is still reading
from**. `read_job_status` treats a missing status file as a hard failure by
design — `tests/test_utility.tcl:119`, `if {![file exists $statusfile]} { return -1 }`
— and `-1` is not a crash code any xschem process ever wrote. Every one of the
ten was `exit -1`, which is the signature: a real crash writes a real nonzero
code, a clobbered run writes nothing at all.

`create_save` and `netlisting` share the same `results/` tree and the same
exposure; `open_close` is simply the longest-running, so it is the one that
collides.

## Why it matters more than it looks

The failure is **indistinguishable at a glance from a genuine regression**, it
lands in the suite whose baseline is ZERO, and it appears only under exactly the
condition a crew creates on purpose: several agents verifying at once. Both
verify passes on item S4c ran into it, and both had to notice that `-1` is not a
crash code before they could clear it. An agent who did not look that closely
would have reported a red — or, worse, learned to expect one and carried the
count forward, which is the failure mode CLAUDE.md's "a standing red is a defect,
not furniture" paragraph exists to stop.

## Fixes, cheapest first

1. **Make the work directory unique per run** — `results/.work.[pid]`, matching
   what `run_parallel_cmds` already does for its own scratch file
   (`test_utility.tcl:82`, `.parallel_jobs.[pid]`). One line, and the `:108`
   delete then only removes the run's own directory. The rest of `results/` is
   still shared, but nothing else is *read back* after the run.
2. **Distinguish a missing status file from a real nonzero exit** in
   `read_job_status`, so the report says "this job's status went missing" rather
   than `FATAL: exit -1`. Complements 1; does not replace it.
3. Take a lock for the duration of a `run_regression.tcl` run, so a second one
   waits or refuses with a clear sentence.

1 + 2 together are recommended: 1 removes the collision, 2 makes any future
collision legible instead of alarming.

## Until it is fixed

**Run `tclsh run_regression.tcl` solo.** Both S4c verify passes' final T1
numbers were taken on a quiet box for this reason, and a T1 verdict taken while
another agent's suite was live should not be believed.

## Rows

None. This is harness infrastructure and nothing in `tests/` watches it. A row
would have to run two regressions at once, which is expensive; fix 1 is
structural and can be verified by inspection plus a single grep that no fixed
`.work` path remains.
