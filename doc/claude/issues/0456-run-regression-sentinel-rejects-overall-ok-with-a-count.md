# 0456 — run_regression's PASS sentinel rejects `OVERALL: ok (N checks)`

Status: OPEN (measured, not fixed)
Found: S8 of doc/claude/specs/op_annotation.md, baseline measurement on branch `annotate`.

`tests/headless/test_pdk_launcher` passes 30/30 of its own checks and prints

    OVERALL: ok (30 checks)

`tests/run_regression.tcl:117` requires the line-anchored exact regex
`^OVERALL: ok$`, which that string does not match, so the harness synthesises a
FAIL for a case that is entirely green. Compare `test_find_helper.log` and
`test_ciw_actionlog_output.log`, which print a bare `OVERALL: ok` and pass.

Two ways out, both cheap: relax the sentinel to `^OVERALL: ok( |$)`, or make the
case print the bare form and put its count on a separate line. Filed rather than
fixed because changing a shared harness sentinel mid-run is out of S8's blast
radius.
