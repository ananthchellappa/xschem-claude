# 0492 — `run_regression.tcl`'s `OVERALL: ok` regexp cannot match a case that prints its check count

> **RESOLVED 2026-08-25 — DUPLICATE of issue 0689, fixed there.**
> This defect was filed **four** times (0420, 0492, 0629, 0689) and waved through as
> "T1 3 FAIL — pre-existing" every time. Nobody fixed it; everybody re-derived it.
> The fix is `tests/banner_rule.tcl` (`banner_complete` / `banner_died` /
> `regression_case_failed`), with `run_regression.tcl` as a consumer and
> `test_audit_classifier.tcl` section K (19 rows) locking it. **T1 went 3 counted
> FAIL lines → 0 in the same commit.** ⚠ The relaxation alone would have been a
> regression — see 0689 §4 — so it shipped paired with a column-0 death predicate.
> Read `doc/claude/issues/0689-*.md`; nothing below needs re-deriving.

**Status:** **RESOLVED as a duplicate of 0689** (2026-08-25). Was: open, pre-existing on branch `annotate`; NOT caused by S3.
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
