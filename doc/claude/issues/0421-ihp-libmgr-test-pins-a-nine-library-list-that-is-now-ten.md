# 0421 - test_ihp_sg13g2_libmgr pins a nine-library list that the tree has since grown to ten

> **RESOLVED 2026-08-25 — DUPLICATE of issue 0690, fixed there.**
> This defect was filed **four** times (0421, 0455, 0491, 0690). The ruling: **the
> TREE was right and the GOLDEN was stale.** `sg13g2_tests_ase` is the migrated ASE-L
> testbench library — a tracked `DEFINE` from ancestor commit c69b88de, 140 tracked
> files across 49 cells — and `test_sky130a_libmgr.tcl:47-52` had already made the
> identical change for `sky130_tests_ase` (11 → 12, citing 15bb25ef). The golden now
> lists 10 and the suite reports `OVERALL: ok (67 checks)`.
> Read `doc/claude/issues/0690-*.md`; nothing below needs re-deriving.

Status: **RESOLVED as a duplicate of 0690** (2026-08-25). Was: OPEN (measured, not fixed)
Found: 2026-08-16, S1 baseline measurement of the `annotate` branch (Measure agent).
Not caused by the operating-point-annotation work; pre-existing on this branch.

## What was measured

`tclsh tests/run_regression.tcl` writes into `tests/results.log`:

```
FAIL: library_list = exactly the 9 intended libs -> {analyses devices examples ngspice ngspice_verilog_cosim sg13g2_pr sg13g2_stdcells sg13g2_tests sg13g2_tests_ase xschem_simulator} (exp {analyses devices examples ngspice ngspice_verilog_cosim sg13g2_pr sg13g2_stdcells sg13g2_tests xschem_simulator})
HARNESS: headless/test_ihp_sg13g2_libmgr did not complete cleanly (exit=0, OVERALL_ok=0) -- crashed, aborted mid-script, or a check failed: FAIL
```

The observed list is the expected list plus one entry: `sg13g2_tests_ase`. The
library exists in the tree; the test's hard-coded expectation was written before it
was added and was never updated.

## Why it matters

Two of the three `FAIL` lines in the current `tests/results.log` come from this one
stale expectation (the check itself, plus the HARNESS roll-up it triggers). Any
future baseline diff on this branch must discount both or mistake them for a
regression.

The check is a whitelist, which is the right shape — it is what would catch a
library accidentally leaking into the IHP workarea. The defect is only that the
whitelist was not updated when `sg13g2_tests_ase` was deliberately added.

## Candidate fix (not applied)

Add `sg13g2_tests_ase` to the expected list in
`tests/headless/test_ihp_sg13g2_libmgr.tcl`, after confirming from git history that
the library was an intended addition rather than stray untracked content.

Left unfixed here deliberately: S1 is a Tcl-only feature step and must not carry an
unrelated test-expectation change into its diff.
