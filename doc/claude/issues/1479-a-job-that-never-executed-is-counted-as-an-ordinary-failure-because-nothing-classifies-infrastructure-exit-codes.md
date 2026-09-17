# 1479 — a job that never executed is counted as an ordinary failure, because nothing classifies infrastructure exit codes

**Status:** OPEN — filed 2026-09-17 by the harness concurrency batch (task D3), measured in
the tree at `aa0e2213`. This is issue **0384**'s fix candidate **2**, which the batch landed
only in part; 0384's own closing section says so and this file carries the remainder.

**Class:** harness / test infrastructure. **Severity:** medium — it does not hide a failure,
it misattributes one, and the bill is a crew bisecting a product defect that never existed.

## What landed, and what did not

`5f7164d4` gave `read_job_status` two sentinels so that *"the status file is missing"* and
*"the status file is garbage"* stopped masquerading as a real exit code — the `exit -1`
phantom that produced 656 false FATALs in one measured collision. That is the
**status-file** half of 0384's candidate 2.

**The exit-code half was not implemented.** 0384 asked for a job that *never executed* —
`exit 126`, `exit 127`, a signalled job — to be reported on its own line, as infrastructure,
so a reader is never invited to read it as a golden mismatch. Nothing in the tree does this.
A repo-wide grep over `tests/*.tcl`, `tests/*.awk` and `tests/headless/*.sh` for a branch on
126, 127 or a signal returns **only prose and comments** — including CLAUDE.md's own rule,
which draws exactly this distinction for `couldn't execute "xschem"` / `exit 127` (issue 0016
part 4) and is enforced by nothing.

## Mechanism

Three case files collate job results, and all three do the same thing:

```tcl
tests/netlisting.tcl:127-131    set rc [read_job_status $status]
                                if {$rc != 0 && $rc != 10} {
                                  puts "FATAL: $cmd : [job_status_reason $rc $status]"
tests/open_close.tcl:128-132    (identical, guard is `$rc != 0`)
tests/create_save.tcl:98-102    (identical, guard is `$rc != 0`)
```

`job_status_reason` (`tests/test_utility.tcl:185-196`) special-cases only the two sentinels
and returns a bare `"exit $rc"` for everything else. Measured by extracting the **shipped**
proc body verbatim and calling it — not by re-implementing it:

```
  rc   1 -> FATAL: <cmd> : exit 1
  rc 126 -> FATAL: <cmd> : exit 126
  rc 127 -> FATAL: <cmd> : exit 127
  rc 139 -> FATAL: <cmd> : exit 139
  rc 143 -> FATAL: <cmd> : exit 143   (SIGTERM, via `echo $?`)
```

Five different meanings, one shape. `summarize_all` (`run_regression.tcl:327`) then counts
any line beginning `FATAL`, so all five score identically. Measured against that exact rule:

```
  counted=1  FATAL: ... : exit 126     <- the binary was never executed
  counted=1  FATAL: ... : exit 127     <- the binary was not found
  counted=1  FATAL: ... : exit 143     <- the job was killed by SIGTERM
  counted=1  FATAL: ... : exit 139     <- a REAL SIGSEGV in the product
  counted=1  FATAL: 53.  Please search for FATAL in its output file for more detail
```

The first three mean *nothing was tested*. The fourth means *the product crashed*. They are
indistinguishable in `results.log`.

## ⚠ An accuracy correction to 0384's own wording — "signal 15" is the wrong string

0384's candidate 2 asks for `exit 126` / `exit 127` / **`signal 15`** to be classified.
Whoever implements it by looking for that string will find nothing in the job path, because
**two unrelated channels share the phrase**:

* **The job path.** Every job's command ends `; echo $? > '$status'`
  (`tests/netlisting.tcl:107`). A shell records a SIGTERMed child as **143** (128+15). The
  string `signal 15` is never written; the number `143` is, and it arrives at
  `job_status_reason` as an ordinary integer.
* **The case-log path.** `FATAL: signal N` is printed by **xschem itself** —
  `src/main.c:58`, `fprintf(errfp, "\nFATAL: signal %d\n", s)` — into the case log *body*,
  where `banner_rule.tcl:107` (`banner_died`) reads it to decide whether a suite died. That
  is a per-case predicate about the child's own crash, not about a job's status file.

0384's transcript shows `FATAL: signal 15` because it was reading the second channel. The
classification it asks for belongs to the first. Both are worth having; they are not the
same change, and conflating them is how this candidate ends up half-implemented again.

⚠ **And do not "fix" this in `banner_rule.tcl`.** Its comment at `:115-118` records that the
`couldn't execute "xschem"` / exit-127 markers are **deliberately excluded** from the death
set, with a stated reason: they belong to the golden cases' `/bin/sh` jobs and to
run_regression's xschemtest guard, neither of which that predicate is reached from, and
*"folding them in for symmetry would blur that distinction."* The gap is at the **job** level,
in `job_status_reason` and its three callers.

## What it costs a reader

0384's measured instance is the bill, and it is not hypothetical: three concurrent runs
produced

```
FATAL: 53.  Please search for FATAL in its output file for more detail
```

where all 53 were `exit 126` — the exec never happened, so no netlist was ever compared.
A crew diffing *"3 FAIL lines"* against *"4 FAIL lines including a FATAL in netlisting"* has
every reason to call that a regression and bisect a fix that was never wrong. You only
discover it is bogus by opening `<case>_output.txt` and noticing that **every** failure is
`exit 126`, i.e. that the binary never ran.

The same signature has a second, entirely innocent source that this classification would also
disambiguate: a **concurrent relink** of `src/xschem` while suites are forking it by path.
0384 measured the binary's mtime and size moving three times inside one window. So
*"every failure is `exit 126`"* means *either* a concurrent run *or* a concurrent build —
**never** a product defect. That is a strong, cheap inference the harness currently forces
every reader to make by hand, from a file it does not point them at.

## How to reproduce

**Measured, cheaply, with no suite run and no concurrency** — the two probes above: extract
`tests/test_utility.tcl:167-196` verbatim, call `job_status_reason` across the codes, and
apply `run_regression.tcl:327` to the resulting lines. Both are reproduced in full in the
mechanism section.

**End-to-end, from 0384's own diagnosis recipe** (still current, still the way to recognise
this):

```sh
grep -oE "exit [0-9]+$" tests/<case>_output.txt | sort | uniq -c   # all 126/127 -> never ran
ps aux | grep "tclsh run_regression"                               # >1 means the run is void
stat -c '%y %s' src/xschem                                         # moved -> the run is void
```

## Fix shape

⚠ **PROPOSED AND UNMEASURED.** Not implemented, not run. Two of this batch's five issue
files prescribed fixes later measured to change nothing, so the label is literal.

**The narrow change is one function.** All three call sites already route through
`job_status_reason`, so classifying there reaches every one of them:

```tcl
# 126 = found but not executable; 127 = not found; 128+N = killed by signal N
```

**But that alone only changes the sentence, not the verdict shape.** The line still begins
`FATAL` and is still counted by `:327`. To give a reader the separation 0384 asked for, the
**prefix** emitted at the three call sites has to change too, and `summarize_all` has to
learn the new shape. That is a change to what `results.log` contains, so it touches the two
shell readers and whatever `test_audit_classifier.tcl` locks — cost it before starting.

**⚠ There is a decision buried in this, and getting it wrong recreates issue 0147.** 0384
says an infrastructure failure should be *"reported on its own line"* so it is not misread; it
does **not** say uncounted. Making `INFRA:` a non-counting shape would mean a run in which
**every job failed to start** reports zero failures — which is precisely the fail-open
`print_results` was hardened against (`test_utility.tcl:270-277`: it used to bail when
`gold/` was absent, *"so a case in which every single job failed to even start contributed
NOTHING to the run's failure count"*). The `NOGOLD` / `NODISPLAY` lines are the tree's
existing answer to this tension — printed loudly, deliberately **not** counted — and they are
safe only because they mean *"no baseline exists"*, a setup state, rather than *"the thing
under test did not run"*. **An `INFRA:` line must stay COUNTED and merely be labelled.**
Anything else is a quieter harness, not a better one.

**The sentinels show the pattern already works.** `JOB_STATUS_MISSING` / `JOB_STATUS_GARBLED`
(`test_utility.tcl:167-168`) are −1001/−1002, deliberately outside the 0..255 a real `echo $?`
can produce, each with its own sentence, **while a real exit code keeps the exact shape every
existing grep and habit knows** (`exit 139`). Whatever this becomes should preserve that
property for genuine product failures — that constraint is why the first half of candidate 2
landed cleanly.

## Not this issue

* **0384** — the parent. **Fixed** for candidates 1 and 3 and for the status-file half of 2;
  its closing section names this remainder explicitly, and its diagnosis recipe stands.
* **1476 face 1** — the `exit -1` phantom, the *other* half of candidate 2. **Fixed**.
* **0016 part 4** — where CLAUDE.md draws this distinction in prose for
  `couldn't execute "xschem"` / `exit 127`. Nothing enforces it; that is this issue.
* **0147** — the fail-open this fix must not recreate by making `INFRA:` uncounted.
* **1477**, **1478** — the other two residuals of the same batch. Independent mechanisms.

## Evidence

`tests/test_utility.tcl:167-196` (`read_job_status`, `job_status_reason`, the two sentinels),
`:270-277` (the 0147 comment on always counting FATALs).
`tests/netlisting.tcl:107` (the `echo $?` job tail), `:127-131`; `tests/open_close.tcl:128-132`;
`tests/create_save.tcl:98-102` (the three identical collate branches).
`tests/run_regression.tcl:327` (the counted rule). `tests/banner_rule.tcl:107` (`banner_died`),
`:115-118` (the deliberate exclusion). `src/main.c:58` (the real `FATAL: signal` emitter).
Probes taken 2026-09-17 against verbatim-extracted shipped source; no suite was run.
