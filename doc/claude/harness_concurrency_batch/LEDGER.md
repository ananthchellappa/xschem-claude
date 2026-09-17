# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

| id | task | crew status | commit | rows red→green | issues | notes |
|---|---|---|---|---|---|---|
| — | batch scaffolding | driver | `78d06f1e` | — | — | PLAN, BRIEF, DECISIONS, LEDGER; owed ledger backed up; R1 filed as a ruling debt against 0990 |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, identical across 4 runs, 7.4–7.5 s | 1476 | `test_regression_concurrency_1476.tcl`, 485 lines. All four faces reproduced. Private miniature fixture; the real `tests/open_close/` tree never touched. **Refuted the plan's fix shape.** |
| **B1** | faces 1–3 | **DONE** | — | **13 RED → 2 RED**, i.e. 11 turned; `2 FAILED (18 passed)` identical in **10 of 10** consecutive runs | 0867, 0990, 0384(part) | The 2 survivors are C1's verdict lock, as reserved. 6 files, 264 insertions. |

## Check count — settled at 20

A1 said 20, the driver's crude grep said 16. **20 is right**: `13+7` before, `2+18`
after, and `^(ok:|FAIL:)` counts 20. The driver counted *call sites*; two of the 14
sites sit inside `foreach c $CASES` loops. Recorded because the driver's number was
the wrong one, and it was the driver who raised the doubt.

## B1's design choice (ruling R1, scratch half)

`results/` is now **per-run**: each case works in `<case>/results.<pid>`, computes its
verdict there, and `publish_results` then restores the canonical `<case>/results`
name. Scratch moved out entirely to `<case>/.work.<pid>`.

**Why the cheaper option was rejected, concretely:** keeping `results/` shared and
guarding only the wipe is insufficient — a guarded wipe still *fails*, and the case
then proceeds into a directory another run is writing, so `print_results` compares
gold against the *other run's* files. The fixture agrees: rows D2a/D2b green only when
the wipe's argument is per-run.

Blast radius handled: `print_results` gained an optional `resdir` (defaulting to the
canonical name, so every other caller is unchanged), plus `netlisting`'s `$results`,
`create_save`'s two `results_dir` sites, `open_close`'s `$output`, and gold promotion.

## ⚠ Two scope additions B1 was forced into — one would have shipped invisibly

1. **`tests/cleanup_debug_file.awk`.** xschem *prints these paths into the results*:
   1898/1898 open_close files, 5/10 create_save, 2 netlisting `.spice`. Left alone,
   the fix would have made **1905 result files vary run-to-run on the same machine** —
   invisible to the suite, and it would have shipped. Two patterns map the per-run
   token back to canonical, so create_save's lines stay byte-identical to before.
   Netlists also had to join `cleanlist` (only debug files were ever normalised); a
   dry run first proved the awk changes **0 of 724** netlists otherwise.
2. **`.gitignore`.** The three existing rules are *exact paths*, so per-run siblings
   were untracked junk. Verified against real directories — `check-ignore` on a
   nonexistent path silently under-reports.

## ⚠ B1's corrections — C1 depends on all three

1. **A1's correction 4 is half wrong.** Face 4 is *not* reliably "the second run is
   erased". In run 8 the coin landed the other way: `V2a` green, **`V2b` RED**. C1's
   acceptance must therefore be *both rows green AND stable across repeats*, not
   "V2a flips, V2b was always green". **Three runs would not have caught this.**
2. The shape of `results/` changed, but **`run_regression.tcl` needs no change for
   it** — the driver never names a case's results directory.
3. **A comment can become the thing a source-text row measures.** `src_line` takes the
   *first* match, so a draft that quoted the old wipe verbatim in prose had rows S2 and
   the D fixture measuring the comment rather than the code. Cost one red/green cycle;
   the suite now carries a warning about it.

## B1 verification

Faces 1/2/3 green **10/10** (0 phantoms of 1500 jobs; the second run reaches its
verdict and exits 0). A real crash still reports verbatim (`exit 139`) — the fix does
not mask genuine failures. All three cases rc 0, 0 FATAL / 0 WARNING, correct file
counts, byte-identical manifests across two runs each, **0 of 3376 result files
contain a per-run token**, and `summarize_all` would count 0 lines per case.
`sweep_dead_run_dirs` exercised in both directions. Binary confirmed current. T1 not
run — that is V1's, and `run_regression.tcl` is C1's file.

## ⚠ Standing red, by design, until C1 lands

The suite is deliberately not in `hcases` (C1's file), but `full_audit.sh:393` globs
`test_*.tcl` and picks it up. **Any full audit before C1 shows 2 RED rows by design**
(13 before B1). Nobody carries this count forward as "known".

## Pre-batch baseline (driver, 2026-09-16)

* Solo T1: `rc=0`, **410 s**, `Start=83 / Finish=83`, **ZERO counted failures**,
  `results.log` mtime moved. Any red from here is ours.
* Defect reproduced 3/3 at 3/6/9 s staggers: 407/432/757 phantom `exit -1`, second run
  dead at `open_close.tcl:32` every time, 1/5/6 result files silently lost.

## Resume point

Next task to dispatch: **C1** (face 4, the verdict lock), carrying B1's three
corrections — in particular that acceptance is *both* V2 rows green *and* stable
across repeats, because the erasure picks its victim at random.
