# 0491 — `test_ihp_sg13g2_libmgr`'s expected library list is stale by one library

> **RESOLVED 2026-08-25 — DUPLICATE of issue 0690, fixed there.**
> This defect was filed **four** times (0421, 0455, 0491, 0690). The ruling: **the
> TREE was right and the GOLDEN was stale.** `sg13g2_tests_ase` is the migrated ASE-L
> testbench library — a tracked `DEFINE` from ancestor commit c69b88de, 140 tracked
> files across 49 cells — and `test_sky130a_libmgr.tcl:47-52` had already made the
> identical change for `sky130_tests_ase` (11 → 12, citing 15bb25ef). The golden now
> lists 10 and the suite reports `OVERALL: ok (67 checks)`.
> Read `doc/claude/issues/0690-*.md`; nothing below needs re-deriving.

**Status:** **RESOLVED as a duplicate of 0690** (2026-08-25). Was: open, pre-existing on branch `annotate`; NOT caused by S3.
**Filed by:** step S3d of `doc/claude/specs/op_annotation.md` (measured while
taking the tier baseline).

## What

`cd tests && tclsh run_regression.tcl` reports, verbatim:

```
FAIL: library_list = exactly the 9 intended libs ->
  {... sg13g2_tests sg13g2_tests_ase xschem_simulator}
  (exp {... sg13g2_tests xschem_simulator}) : FAIL
```

`OVERALL: 1 FAILED (65 passed)` for that case; 2 of the 3 FAIL-ending lines in
the whole T1 run.

## Cause

`ihp-sg13g2/xschem_libs/sg13g2_tests_ase/` exists on disk and is **committed** —
140 tracked files, added by `bf83fa95 regen(pdk): sky130A + ihp-sg13g2 benches
through the fixed migrator`. The suite's expected list still names 9 libraries
and was last touched by the earlier commit `e9f6f676`.

A library was added to the repository without updating the test's expected list.
The test is right to notice; its expectation is simply one commit behind.

## Fix

Add `sg13g2_tests_ase` to the expected list in
`tests/headless/test_ihp_sg13g2_libmgr.tcl` and update the "exactly the 9
intended libs" wording to 10.
