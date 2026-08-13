# 0324 — `test_ihp_sg13g2_libmgr` still expects exactly nine libraries; the workarea registry now yields twelve, so the suite fails one check

Status: **OPEN**.
Found by: issue 0228's fix. The suite prints `OVERALL: ok (N checks)` and no `RESULT:`
line, so through `run_suites.sh` it was scored `NORESULT` — *indistinguishable from a
regression*, which is exactly the readability 0228 was about. With the sentinel fallback
in place the same run reports **`FAIL`** and names the check.
Severity: low — one stale expectation in a test, no product defect. But it is a **real
red** on the X arm now, so it must be either fixed or knowingly carried.
Pre-existing: **yes**, and not caused by 0228. `git log -- ihp-sg13g2/xschem_libs/library.defs`
shows `c69b88de` ("the migrated schematic still instantiated the SOURCE library") added
`DEFINE sg13g2_tests_ase sg13g2_tests_ase` without touching the test, whose last commit
is the older `e9f6f676`.

## Symptom

```
$ SUITE_TIMEOUT=400 doc/claude/signal_browser_2pane_batch/xarm.sh suites test_ihp_sg13g2_libmgr.tcl
FAIL     | test_ihp_sg13g2_libmgr       run 1/1  RESULT: FAILED (via OVERALL failure sentinel)
         | FAIL: library_list = exactly the 9 intended libs ->
           {SANDBOX TEST analyses devices examples ngspice ngspice_verilog_cosim
            sg13g2_pr sg13g2_stdcells sg13g2_tests sg13g2_tests_ase xschem_simulator}
           (exp {analyses devices examples ngspice ngspice_verilog_cosim sg13g2_pr
                 sg13g2_stdcells sg13g2_tests xschem_simulator}) : FAIL
```

65 checks pass, 1 fails: `OVERALL: 1 FAILED (65 passed)`.

## Diagnosis

`tests/headless/test_ihp_sg13g2_libmgr.tcl:66-68` pins the list:

```tcl
set expect [lsort {devices sg13g2_pr sg13g2_stdcells sg13g2_tests \
                   analyses examples ngspice ngspice_verilog_cosim xschem_simulator}]
check "library_list = exactly the 9 intended libs" $names $expect
```

The observed 12 exceed the expected 9 by three names, from **two different causes**:

* **`sg13g2_tests_ase`** — a tenth `DEFINE` line was added to
  `ihp-sg13g2/xschem_libs/library.defs` by `c69b88de`. The workarea genuinely has it.
* **`SANDBOX` and `TEST`** — these are **not** in the workarea's `library.defs` at all.
  They come in behind the six `DEFINE <lib> ../../xschem_libs_newsym/<lib>` lines, i.e.
  from the shared `xschem_libs_newsym` registry, so the "9 intended libs" assertion is
  also asserting something about a *shared* directory that other work is free to grow.

## What to decide, not just patch

Bumping the literal to 12 makes the check green and keeps it brittle: the next `DEFINE`
anywhere in `xschem_libs_newsym` reddens it again. The check has two halves worth
separating:

1. the workarea's **own** libraries are all registered and resolve — worth pinning exactly;
2. libraries inherited from the shared registry are **present**, but not an exhaustive set
   — worth asserting as a subset (`every expected name is in $names`), not as equality.

Also worth resolving: whether `SANDBOX`/`TEST` leaking into an `ihp-sg13g2` workarea listing
is intended at all, since `test_ihp_sg13g2_libmgr.tcl:14` describes the run as reading "the
same registry vars the rc sets".

## Repro

```sh
SUITE_TIMEOUT=400 doc/claude/signal_browser_2pane_batch/xarm.sh one test_ihp_sg13g2_libmgr.tcl
#  -> 65 ok, 1 FAIL, "OVERALL: 1 FAILED (65 passed)"
```

Related: `doc/claude/issues/0228-run-suites-will-not-read-the-overall-ok-sentinel.md`
(the harness fix that made this visible).
