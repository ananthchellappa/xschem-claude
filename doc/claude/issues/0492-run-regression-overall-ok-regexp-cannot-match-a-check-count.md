# 0492 — `run_regression.tcl`'s `OVERALL: ok` regexp cannot match a case that prints its check count

**Status:** open. Pre-existing on branch `annotate`; NOT caused by S3.
**Filed by:** step S3d of `doc/claude/specs/op_annotation.md` (measured while
taking the tier baseline).

## What

`cd tests && tclsh run_regression.tcl` reports:

```
HARNESS: headless/test_pdk_launcher did not complete cleanly (exit=0, OVERALL_ok=0) ... : FAIL
```

while that same case's own log ends:

```
OVERALL: ok (30 checks)
```

with all 30 checks marked `ok:`. The case passes; the harness cannot see that it
passed.

## Cause

`tests/run_regression.tcl:117` matches the anchored regular expression
`{^OVERALL: ok$}`. `OVERALL: ok (30 checks)` has trailing text, so `$` cannot
match. Suites that print a bare `OVERALL: ok` are seen; suites that print their
check count are not.

Pure reporting artifact — nothing about the case under test is wrong. But it
costs a FAIL line in every T1 run, which is exactly the signal a crew reads to
decide whether a change regressed anything.

## Fix

Relax the sentinel to `{^OVERALL: ok\M}` (or `{^OVERALL: ok( |$)}`) so a
check count is allowed after it, and keep it anchored at the start so
`OVERALL: 1 FAILED` still cannot match.
