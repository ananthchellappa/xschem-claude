# Harness concurrency batch — PLAN

**Subject.** Two concurrent `tclsh run_regression.tcl` runs in one tree corrupt each
other in four distinct ways. Filed five times across seven weeks (0384, 0867, 0990,
0955, 0905) and **never once attempted** — `git log --all --grep` over both clones
returns nothing. Two further faces were reproduced on 2026-09-16 and are unfiled.

## The measured evidence (do not re-derive it)

Measured 2026-09-16 at HEAD, 20-core box, in-tree `src/xschem`:

| run | result |
|---|---|
| `open_close.tcl` **solo** | 34 s, rc 0, 1898 result files, **0 FATAL** |
| two runs, **3 s** apart | A: **407** phantom `FATAL … exit -1` · B: **died**, rc 1 |
| two runs, **6 s** apart | A: **432** phantom · B: **died**, rc 1 |
| two runs, **9 s** apart | A: **757** phantom · B: **died**, rc 1 |

Solo T1 baseline, same night: `rc=0`, **410 s (6m50s)**, `Start=83 / Finish=83`,
82 `Total num fail:` lines, **ZERO counted failures**, `results.log` mtime moved
(1789603761 → 1789624370, so not a fossil). **T1 is at its zero baseline; any red
after this batch is ours.**

A reproduction cycle is ~70 s and needs ONE case, not a whole regression. Issue
0990's claim that a row "would have to run two regressions at once, which is
expensive" is **wrong** and must not be inherited.

## The four faces

1. **Phantom FATALs** in whichever run collates. `$workroot` is a fixed path
   (`open_close.tcl:38`, `create_save.tcl:32`, `netlisting.tcl:38`); run A deletes
   it at its `:108`/`:100`/`:131` while run B is still reading; `read_job_status`
   (`test_utility.tcl:118-125`) scores a missing status file `-1`; the caller turns
   every `-1` into a counted `FATAL … exit -1`. Described by 0384/0867/0990.
2. **The second run dies at startup, with no verdict at all.** `file delete -force
   $testname/results` (`open_close.tcl:32`) fails — `error deleting
   "open_close/results": file already exists` — because the other run is creating
   files inside it mid-walk. rc 1, no banner, no `Total num fail:` line. **Recorded
   in no issue file.** Worse than face 1: face 1 screams, face 2 vanishes, and the
   driver counts lines that are *there*.
3. **Silent result-file loss in the cleanup phase.** `cleanup_debug_files`
   (`test_utility.tcl:102-114`) `catch`es its `xargs … awk`, so files the other run
   deleted produce `awk: … cannot open file` on stderr and are **never counted**.
   Observed 1, 5 and 6 files lost in the three pairs. **Recorded in no issue file.**
4. **Phantom PASS via the verdict file.** `run_regression.tcl:295` is
   `set log_fn "results.log"` and `:381` opens it mode `w` — fixed name, truncate,
   no lock. A run can report ZERO having verified nothing. Filed as 0955 (which
   calls itself "Sibling of issue 0867 … the same collision in a different file and
   in the opposite direction") and 0905. **This is the dangerous direction** — faces
   1–3 are loud, face 4 is silent, and it lands in the one file CLAUDE.md calls
   "THE ONLY PLACE THE ANSWER IS".

## The shape being built (ruling R1, see DECISIONS.md)

* **Scratch is made parallel-safe.** `$workroot` gets the pid scope the runner
  already uses one file away (`test_utility.tcl:82`, `.parallel_jobs.[pid]`).
  Nobody reads scratch after a run, so this is pure win.
* **The verdict is serialised.** `results.log` keeps its canonical name — `crew.js`,
  CLAUDE.md and the user all read that exact filename — and `run_regression.tcl`
  takes a lock so the second run is told plainly to wait rather than silently
  truncating it.

## Stages — ONE TASK PER CREW, dispatched serially

⚠ **Crews are dispatched one at a time on purpose.** Until this batch lands, two
crews running suites at once reproduce the very defect under repair, and the loser's
numbers are void. Nobody runs a suite while another crew is running one.

| id | task | files | acceptance |
|---|---|---|---|
| **A1** | the RED suite | new `tests/headless/test_regression_concurrency_1476.tcl` | rows RED on today's tree, for all four faces; source-text rows in the idiom of `test_suite_watchdog_1403.tcl` W14–W19 (`has_text`), behavioural rows bounded by `timeout` |
| **B1** | faces 1–3: scratch | `open_close.tcl:32,38`, `create_save.tcl:28,32`, `netlisting.tcl:32,38`, `test_utility.tcl:118-125` + its 3 callers, **and `test_utility.tcl:102-114`** | A1's face-1/2/3 rows go GREEN; a missing status file is reported as missing, not as `exit -1`; see ⚠ A1 below — the workroot must move **out of** `results/`, and face 2 needs the startup wipe, not the workroot |
| **C1** | face 4: verdict lock | `run_regression.tcl` (~`:295`, `:381`) | A1's face-4 rows go GREEN; second run waits or refuses **loudly**; `results.log` keeps its name |
| **D1** | docs | new `doc/claude/issues/1476-*.md`; close 0384, 0867, 0990, 0955, 0905; `NUMBERING.md` | 1476 records faces 2+3; the five are closed with pointers; NUMBERING records 1476 and corrects the stale 1332 bullet |
| **V1** | verification | — | solo T1, reported per CLAUDE.md's reading rules (mtime moved, Start/Finish pairs, per-case zero) |
| **E1** | companion: 0805 + 0802 | `tests/headless/full_audit.sh:211-212`, `:311-325`; `test_audit_classifier.tcl` | one bundle — 0805's own text says land them together |
| **E2** | companion: 0408(a) | `tests/headless/test_label_ride.tcl:548,550-552,839` | part (a) ONLY; part (b) is unexplained and out of scope |
| **E3** | companion: 1332-residual | `tests/headless/test_ase_bus_bits_0159.tcl:277,285` | poll, don't widen the delay; recipe at `test_rdw_keys_1245.tcl:2243,2279` |

**Explicitly out of scope:** 1232 (edits `run_regression.tcl:27` — the file C1 owns;
schedule after, never beside), 1455/1290, 1346, 0396/0368.

**Verified already fixed, do not touch:** 1332 (`Status: FIXED` 2026-09-05), 0994
(`FIXED 2026-08-30`). The scan also reported 0642 and 0645 as stale; **unverified by
the driver** — check before believing.

## ⚠ A1's corrections — measured, and they invalidate part of this plan

**The shape this PLAN called the minimum is a no-op.** A1 measured three
configurations of one staggered pair:

| workroot | run A | run B |
|---|---|---|
| `"$testname/results/.work"` (today) | **660** phantoms | died at startup |
| `"$testname/results/.work.[pid]"` — *this PLAN's stated minimum* | **658** phantoms | died at startup |
| `"$testname/.work.[pid]"` (outside `results/`) | **0** phantoms | died at startup, 2 of 3 |

The shared object is **`$testname/results` itself**, which every run wipes at startup
(`open_close.tcl:32`, `create_save.tcl:28`, `netlisting.tcl:32`). Pid-scoping a
directory *inside* the thing that gets wiped changes nothing. Moving the workroot out
closes face 1 and leaves face 2 flaky — **face 2 is a property of the startup wipe and
must be fixed there.**

**Face 1 is mis-attributed above.** The end-of-run delete at `:108` is not the culprit
in practice: run B died at startup and never reached it, yet run A still lost 639–670
status files to B's partially-completed *startup* wipe.

**Face 4 is an erasure, not a corruption.** 13268 bytes, zero NUL bytes, run A's
verdict complete — run B's verdict simply never appears while B exits 0. Rows keyed on
corruption or interleaving ship GREEN and prove nothing; A1 had two such rows in its
first draft and rekeyed them.

**Face 3 needs no concurrency and is wider than stated.** gawk's "cannot open file" is
**fatal**, so one missing file aborts the entire `xargs -n 64` batch — the *present*
files in that batch are left un-normalised too. Reproducible in two awk spawns, no
collision required. `test_utility.tcl:102-114` joins B1's file list.

## Issue number

**1476** — mint-checked 2026-09-16: outside every reserved band, no file in either
clone (`~/dev/xschem-claude`, `~/dev/xschem-op-wcard`), no reservation anywhere but
this clone's own `next free number` line.
