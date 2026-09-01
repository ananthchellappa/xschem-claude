# 1232 — test_descend_views is registered in no runner

**Status:** OPEN — number claimed by item S7's red phase.

`tests/headless/test_descend_views.tcl` appears in neither
`tests/headless/full_audit.sh`'s `nogui_tests` nor `tests/run_regression.tcl`'s
`hcases` — verified by grep, 0 hits in each. It exits 0 with `RESULT: ALL PASS`
when run by hand.

Its row D2 is the only committed row anywhere that drives a per-instance
`schematic` setting through the bare verb, so the one suite that could have caught
issue 1228's neighbourhood is the one nothing runs.

A ruling is owed: register it now (it adds an unmeasured suite to T1) or file only.
