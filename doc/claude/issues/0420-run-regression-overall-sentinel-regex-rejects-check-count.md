# 0420 - run_regression.tcl's OVERALL sentinel regex rejects a passing suite that prints its check count

Status: OPEN (measured, not fixed)
Found: 2026-08-16, S1 baseline measurement of the `annotate` branch (Measure agent).
Not caused by the operating-point-annotation work; pre-existing on this branch.

## What was measured

`tests/run_regression.tcl:117` decides a headless case passed with

```tcl
set sentinel [regexp -line {^OVERALL: ok$} $body]
```

That is an anchored exact match. `tests/headless/test_pdk_launcher.tcl` ends its log with

```
OVERALL: ok (30 checks)
```

so the sentinel never matches, and line 120 writes

```
HARNESS: headless/test_pdk_launcher did not complete cleanly (exit=0, OVERALL_ok=0) -- crashed, aborted mid-script, or a check failed: FAIL
```

into `tests/results.log` even though the suite passed.

Run standalone, the same suite is green:

```
$ ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_pdk_launcher.tcl
...
OVERALL: ok (30 checks)
```

exit 0, 30 checks, zero `FAIL` lines. The failure exists only inside the regression
harness's own verdict.

## Why it matters

This is a false red in the trustworthy tier. It costs one permanent `FAIL` line in
`results.log`, which every later baseline diff has to remember to discount. It also
means the harness cannot distinguish "suite printed a check count" from "suite
crashed", so a genuinely crashed suite that happened to print a count would be
reported identically.

## Candidate fix (not applied)

Relax the anchor to `{^OVERALL: ok\M}` or `{^OVERALL: ok( |$)}` so a trailing
`(N checks)` is accepted while `OVERALL: not ok` still fails. Do not simply drop the
`$` without a word boundary — `^OVERALL: ok` alone would also match a hypothetical
`OVERALL: okay-ish`.

Left unfixed here deliberately: S1 is a Tcl-only feature step and must not carry an
unrelated harness change into its diff.
