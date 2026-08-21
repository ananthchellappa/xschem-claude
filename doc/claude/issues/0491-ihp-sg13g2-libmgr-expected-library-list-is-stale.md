# 0491 — `test_ihp_sg13g2_libmgr`'s expected library list is stale by one library

**Status:** open. Pre-existing on branch `annotate`; NOT caused by S3.
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
