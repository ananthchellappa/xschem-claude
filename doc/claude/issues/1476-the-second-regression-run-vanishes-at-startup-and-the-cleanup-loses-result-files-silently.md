# 1476 — the second regression run vanishes at startup, and the cleanup loses result files silently

**Status: FIXED** 2026-09-17, by the harness concurrency batch — `5f7164d4`
(faces 2 and 3, with face 1) and `43b40f04` (face 4). Red suite first at
`5114dd8b`, registered in T1 and verified at `d4946b61`.

**Reproduced** 2026-09-16 on this tree at HEAD, 20-core box, in-tree `src/xschem`.
**Subject** `tests/open_close.tcl`, `tests/create_save.tcl`, `tests/netlisting.tcl`
and `tests/test_utility.tcl`. **Class** harness / test infrastructure.

**Why a sixth number for a defect filed five times.** Two concurrent
`tclsh run_regression.tcl` runs in one tree corrupt each other in **four** distinct
ways. Three of the four were already on file — faces 1 and 4 across **0384**,
**0867**, **0990**, **0955** and **0905**, all five of which are closed by the same
batch. **The two recorded here were in no issue file at all.** They are not
refinements of the others: one of them is the *quietest* face of the set, and the
other needs no concurrency whatsoever.

Full record: `doc/claude/harness_concurrency_batch/` (PLAN, DECISIONS — ruling R1
and its two amendments — LEDGER, and the crew receipts A1/B1/C1/V1).

---

## Face 2 — the second run dies at startup and leaves no verdict line at all

Every case begins by wiping a **shared** results tree. Pre-fix
`tests/open_close.tcl:32`, and the same shape at `create_save.tcl:28` and
`netlisting.tcl:32`:

```tcl
file delete -force $testname/results
file mkdir $testname/results
```

Unguarded, and its target is shared by every run in the tree. When another run is
creating files inside that tree mid-walk, the delete **raises**:

```
error deleting "open_close/results": file already exists
```

Tcl's `file delete -force` walks the tree and reports that message when a directory
it has just emptied is repopulated underneath it. The raise is uncaught, so the case
dies on the spot: **rc 1, no completion banner, and no `Total num fail:` line
whatsoever.**

**Measured:** in **9 of 9** staggered pairs the second run died at startup this way
(A1). B1 then measured the fixed shape at **10 of 10** clean.

### Why this is worse than the phantom FATAL it travels with

Face 1 — the phantom `FATAL … : exit -1` block described by 0384/0867/0990 — is
loud. It manufactures counted failure lines, a reader investigates, and the tell
(`exit -1` is not a code any xschem process writes) is right there in the text. It
costs an hour and it is *survivable*, because the run announces that something went
wrong.

Face 2 announces nothing, and the reason is structural. `run_regression.tcl`'s
counted shapes are

```tcl
if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]}
```

— **four patterns, every one of which needs a line to exist.** A case that dies
before it writes its block contributes no line, so there is nothing to match. The
verdict file is simply one block shorter than it should be, and short is exactly
what a clean run looks like.

**A run that screams gets counted. A run that vanishes does not. The driver counts
the lines that are *there*.** This is the same fail-open class as issue **0147** (a
plausible `results.log` while nothing was verified) and as **0905**'s 0-byte log,
arriving through a third door: not an empty file and not a truncated one, but a
complete-looking file that is missing a case nobody will notice is absent. CLAUDE.md
already teaches "count `Start`/`Finish` pairs for cases, never log lines" — face 2 is
precisely the defect that rule protects against, and before this batch nothing in the
harness enforced it.

### Fix

The results root is now **per-run**. Each case works in `<case>/results.<pid>` with
its scratch in `<case>/.work.<pid>` — out of `results/` entirely — and
`publish_results` (`tests/test_utility.tcl`) restores the canonical `<case>/results`
name by delete-then-rename once the verdict is computed, so gold promotion and every
documented path are unchanged. The startup wipe still happens, because a pid can be
reused by a later run, but it now targets **only this run's own root**: nobody else is
inside it, so it cannot raise and it cannot delete anybody's evidence.
`sweep_dead_run_dirs` reaps the roots of runs that are no longer alive (a killed run
would otherwise leave 1898 files behind per case), and is deliberately biased so that
the failure direction is "a leftover survives", never "a live run's tree is deleted".

⚠ **Pid-scoping the scratch *inside* `results/` — the shape three earlier issues
proposed — is a no-op.** A1 measured all three configurations of one staggered pair:
`"$testname/results/.work"` (then-current) 660 phantoms, `"$testname/results/.work.[pid]"`
**658** phantoms, `"$testname/.work.[pid]"` 0 phantoms. The shared object is
`$testname/results` itself. Anyone re-deriving this fix should start there.

⚠ **The per-run token leaks into result *content*.** xschem prints these paths into
the files the harness compares — `set XSCHEM_TMP_DIR {<workroot>/44.tmp}` in 1898 of
1898 open_close files, `process_option(): file name given: <resdir>/…` and
`is_from_web(<resdir>/…)` in create_save, `.include <workroot>/…` in 2 netlists — so
without normalisation every one of those files would differ from its own gold on the
next run of the same tree with nothing changed. `tests/cleanup_debug_file.awk` gained
two patterns that **map the token back to its canonical spelling**
(`results\.[0-9]+` → `results`, `\.work\.[0-9]+` → `.work`) rather than blanking the
line, so an existing baseline still matches. Verified: `grep -rlE` for either token
over all 3376 result files → **0 files**, and two consecutive runs of each case give
byte-identical manifests.

### Rows

`tests/headless/test_regression_concurrency_1476.tcl` —
`S2-{open_close,create_save,netlisting}-startup-wipe-cannot-die-silently` (source
text, milliseconds), and the behavioural pair `D2a-the-second-run-reaches-a-verdict`
/ `D2b-the-second-run-exits-zero`, which run a miniature two-run collision in ~2.4 s.
Red before, green after, 10 of 10.

---

## Face 3 — silent result-file loss in the cleanup phase, and it needs no concurrency

Pre-fix `tests/test_utility.tcl:102-114`:

```tcl
proc cleanup_debug_files {files njobs} {
  ...
  catch {exec xargs -0 -P $njobs -n 64 awk -f cleanup_debug_file.awk < $tmp 2>@ stderr}
  file delete -force $tmp
}
```

A bare `catch` with **no branch and no return value**. Every failure of that pipeline
is discarded at the point it happens, and the proc tells its caller nothing.

**The loss is wider than "the missing files are skipped", and this is the part that
makes it an issue rather than a tidiness note.** gawk treats `cannot open file` as a
**fatal** error, so a single missing path **aborts the whole `xargs -n 64` batch** —
and `cleanup_debug_file.awk` only writes a file back from `endfile()`, with
`END{endfile()}` flushing the last file of a batch. Up to 63 files that were *present
and healthy* are therefore left un-normalised alongside the one that was gone, with
their machine-specific paths and window IDs intact, ready to differ from gold for
reasons that have nothing to do with the code under test.

⚠ **This face requires no collision at all.** A1 reproduced it deterministically in
**two awk spawns**: a file on its own is normalised (`normalised=1`); the same file
batched with one missing path is **not** (`normalised=0`), while `catch` returns
`0` and the proc returns `{}` — it reported nothing, to nobody. Concurrency is merely
the most common way to make a file disappear mid-run; `1`, `5` and `6` files were
lost this way in the three staggered pairs that opened the batch.

### Fix

`cleanup_debug_files` now partitions its input into present and missing **before**
spawning anything, so a missing file can never reach gawk. Missing files are reported
as a counted `FATAL` in the case's own words — *"N result file(s) gone before
normalization (first: …) — another run in this tree is the usual cause (issue
1476)"* — and an awk failure is likewise reported rather than swallowed, with
*"result files may be un-normalized"*. The proc returns its problem list, so the
caller decides. The present list is also `lsort -unique`d: the batches must stay
disjoint, because two parallel awks rewriting one file is a corrupted file, and
netlisting's last-writer-wins rename can list one published path twice.

### Rows

`C1b-a-missing-file-does-not-silently-cost-its-batch-mates`, with
`C1a-a-file-on-its-own-is-normalised` beside it as the non-vacuity guard proving C1b
measures a **loss** and not a no-op. Red before (`batched=0 told-the-caller=0`), green
after (`batched=1 told-the-caller=1`). Deterministic; no concurrency, no xschem
process.

---

## The other two faces, for completeness — filed elsewhere, closed by the same batch

* **Face 1 — phantom `FATAL … : exit -1`** in whichever run collates.
  `read_job_status` scored a missing status file `-1`, indistinguishable from a
  garbled one and printed as `exit -1`. Now `-1001` (missing) and `-1002` (garbled),
  each with its own sentence via `job_status_reason`, while **a real exit code is
  still reported exactly as it always was** (`exit 139`), so every existing grep and
  habit keeps working. Measured: 656 phantoms of 1500 jobs → **0**, 10 of 10 runs.
  Filed as **0384**, **0867**, **0990**.
* **Face 4 — the phantom PASS.** `results.log` was a fixed relative name opened mode
  `w` with no lock, so a second run truncated the first's verdict and could report
  ZERO having verified nothing. Filed as **0955** and **0905**. Now serialised by an
  `open … {WRONLY CREAT EXCL}` lock on `tests/results.log.lock`.
  ⚠ **The shape is not "it takes a lock and the second run waits".** Waiting was
  measured to be the *data-losing* option: a run that queues politely and then opens
  mode `w` leaves `results.log` holding **0** of the first run's four case blocks.
  What shipped is **refusal by default** (the second run exits **2**, writes nothing,
  and prints who holds the lock and how to proceed), **waiting opt-in** via
  `T1_LOG_LOCK_WAIT`, and the waiting path **preserving** the prior verdict as
  `results.<pid>.log` before taking the canonical name. Nothing is lost on either
  branch. A stale lock is broken on **evidence** — the owner pid is gone, or
  `/proc/<pid>/cmdline` is no longer the script that took it, because a bare `kill -0`
  answers yes for a **recycled** pid — with `T1_LOG_LOCK_TTL` (default 14400 s) as a
  backstop, and the whole mechanism fails open: a lock that can be neither taken nor
  broken lets the run proceed UNLOCKED with a warning, because a tree that cannot be
  tested is worse than a tree tested without a lock.

⚠ **`file mkdir` IS NOT A LOCK IN TCL.** `tests/headless/gui_gate.sh:169` uses the
mkdir idiom, which is atomic in `/bin/sh` because `mkdir(2)` fails on an existing
directory. Tcl's `file mkdir` **succeeds silently** on one (measured, tcl 8.6.17:
rc 0, no error), so that shape ported here would hand the lock to both runs **and
read as correct in review**. This is the single most likely way to reintroduce
face 4 with every row still green.

---

## Verification

Solo T1 on the finished tree (`d4946b61`, receipt `receipts/V1.md`): **84 cases**
(`Start=84 / Finish=84`), **374.6 s**, **ZERO counted failures**, **rc 0**,
`results.log` mtime moved off its pre-run value. The diff against the pre-batch
baseline log is **exactly two lines** — the new suite's log name and its
`Total num fail: 0`. The suite passed *inside* T1, not merely standalone:
`RESULT: ALL PASS (20 checks)`, `OVERALL: ok`.

⚠ **No performance claim is made.** That run took 374.6 s against a 410 s pre-batch
baseline measured by someone else on an uncontrolled box, once. The difference is
recorded as **UNATTRIBUTED**.

Result-file counts are unchanged: create_save 10, open_close 1898, netlisting
**1488 before and 1488 after**, all three byte-identical to the baseline log.
(`print_results` prints `[llength $pathlist]`, the count of *planned* files; the
tree holds 1468 *landed* files, the 20-file gap being jobs that exit 10 — the
expected-netlist-error path — which append to `pathlist` without producing a file.
The two numbers measure different things and must not be compared.)

## Why it took seven weeks and five issue numbers

Nothing was ever attempted: `git log --all --grep` over both clones returns nothing
for any of the five. The premise that stopped it is recorded in **0990**, which said
a row "would have to run two regressions at once, which is expensive" — and that is
**false**. The reproduction is one *case*, not a regression, at ~70 s; the suite's
miniature fixture does it in **2.4 s with no xschem process at all**. One
unmeasured sentence in a closed issue file deterred four subsequent readers for
seventeen days. Re-measure a premise before inheriting it.

## Related

* **0384**, **0867**, **0990** — face 1. **0955**, **0905** — face 4. All five
  closed 2026-09-17 by this batch.
* **0147** — the historical fail-open where the suite ran no binary and still
  produced a plausible `results.log`. Face 2 is the same class.
* **1403** — T1's per-case timeout, which is what makes killed runs (and therefore
  leftover per-run roots and leftover locks) routine rather than hypothetical.
* **1456** — three suites that emit no completion banner, i.e. the *other* way T1's
  verdict file has been misread. Its note that `run_regression.tcl` "exits 0 whatever
  happens" was true when written; a **refused** run now exits 2.
