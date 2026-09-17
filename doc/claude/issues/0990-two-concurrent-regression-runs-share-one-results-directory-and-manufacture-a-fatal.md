# 0990 — two concurrent regression runs share one results directory and manufacture a FATAL

**Filed** 2026-08-30, by the item S4c write-up, from two verify passes that hit
it independently in the same session. **Status FIXED 2026-09-17** by the harness
concurrency batch — `5f7164d4` and `43b40f04`; see "Closed" at the bottom, issue
**1476**, and `doc/claude/harness_concurrency_batch/`. ~~Status open.~~ **Subject**
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

~~None. This is harness infrastructure and nothing in `tests/` watches it. A row
would have to run two regressions at once, which is expensive; fix 1 is
structural and can be verified by inspection plus a single grep that no fixed
`.work` path remains.~~

⚠ **EVERY CLAUSE OF THAT PARAGRAPH IS WRONG, AND IT IS A LARGE PART OF WHY NOTHING
WAS ATTEMPTED FOR SEVENTEEN DAYS ACROSS THREE FILINGS.** Measured 2026-09-16:

* **"A row would have to run two regressions at once."** No. The reproduction needs
  **one case**, not a regression — ~70 s. And the suite that shipped does not even do
  that: its miniature two-run fixture reproduces face 1 and face 2 in **2.4 s with no
  xschem process at all**. Face 3 needs **no concurrency whatsoever** and reds in two
  awk spawns.
* **"which is expensive."** The whole suite is **8.5–8.6 s**, 20 checks, **2.1 %** of
  T1's runtime. It is registered in `hcases` and T1 stayed at **ZERO counted failures**
  with it in.
* **"fix 1 is structural and can be verified by inspection."** ⚠ This is the dangerous
  one. Fix 1 as written — `results/.work.[pid]` — is a **NO-OP**, and inspection is
  precisely what cannot see that. Measured on one staggered pair: the shared path gave
  **660** phantoms, fix 1 gave **658**, and only moving the workroot **out** of
  `results/` gave **0**. Inspection plus "a single grep that no fixed `.work` path
  remains" would have passed a fix that changed nothing.

**The lesson, recorded because this file is the batch's own cautionary tale:** an
unmeasured cost estimate in an issue file is not a finding, but it is read as one. It
stood unchallenged through three re-filings of the same defect. Nobody spent the 70
seconds. **Re-measure a premise before inheriting it** — and when you decline to write
a row, say what it would cost *as a measurement*, not as a guess.

The rows that now exist are in
`tests/headless/test_regression_concurrency_1476.tcl` — 20 checks, 13 red on the
pre-fix tree, `ALL PASS (20 checks)` after, registered in T1's `hcases`.

## Closed — 2026-09-17

Fixed by **`5f7164d4`** (per-run results roots and a job status you can tell apart)
with **`43b40f04`** (the verdict lock). Red suite at **`5114dd8b`**, registered and
verified at **`d4946b61`** — solo T1, **84 cases, ZERO counted failures, rc 0**. The
two faces that were in no issue file are **1476**. Batch record:
`doc/claude/harness_concurrency_batch/`, including ruling **R1** and its two
amendments, the second of which is this file's fix 1 being measured a no-op.

**Against this file's three fixes:**

1. **"Make the work directory unique per run — `results/.work.[pid]`" — landed only
   after being corrected.** See the Rows note above: the shared object was never
   `.work`, it was `$testname/results` itself, which every run wiped on the way in.
   What shipped makes the **results root** per-run (`<case>/results.<pid>`), moves
   scratch out of it entirely (`<case>/.work.<pid>`), and restores the canonical
   `<case>/results` name with `publish_results` once the verdict is computed — so gold
   promotion reads the path it always did. Result: **656 phantoms of 1500 jobs → 0, in
   10 of 10 runs.**
2. **"Distinguish a missing status file from a real nonzero exit" — landed as
   written.** `read_job_status` answers `-1001` (missing) and `-1002` (garbled), and
   `job_status_reason` says *"NO STATUS FILE (…) — this job's exit code was never
   written or was deleted by another run in this tree (issue 1476); the job itself may
   well have succeeded"*, while a real code is still reported exactly as before
   (`exit 139`), so every existing grep and habit keeps working. This file called it a
   complement to fix 1 rather than a replacement, and that was right.
3. **"Take a lock for the duration of a run" — landed, for the verdict file.**
   `tests/results.log.lock`; the second run refuses loudly and exits **2** by default,
   queues only on `T1_LOG_LOCK_WAIT`, and on that arm preserves the prior verdict as
   `results.<pid>.log` first. A lock over the *whole* run was weighed and not taken —
   it would serialise runs completely, and with the roots per-run it is no longer
   needed to make them safe.

**"Until it is fixed: run `tclsh run_regression.tcl` solo"** — still the right advice,
and now the harness enforces it rather than asking. CLAUDE.md's SOLO bullet is
rewritten accordingly. ⚠ But this file's closing sentence stays true of the past: **a
T1 verdict taken before 2026-09-17 while another agent's suite was live should still
not be believed**, because nothing recorded whether that run was contended.
