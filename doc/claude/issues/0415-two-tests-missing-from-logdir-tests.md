# 0415 — `test_ase_log_seam_0207` and `test_select_at` are missing from `logdir_tests`

Status: **OPEN** — measured green with the flag they are owed, one-word fix identified,
not applied. Pre-existing; predates merge 5 (`7af2da9e`).
Area: `tests/headless/full_audit.sh` (`logdir_tests`).
Tests: `tests/headless/test_ase_log_seam_0207.tcl`, `tests/headless/test_select_at.tcl`.

## The defect

Two of the audit's reds fail on the same first line:

```
FAIL: action log open
```

Both exercise the action log, which only exists when the binary is started with `--logdir`.
`full_audit.sh` keeps the list of such cases in `logdir_tests`; neither of these is on it, so
both run without the log and every downstream assertion about it fails for want of a log rather
than for want of the behaviour. `test_select_at` loses 5 checks that way (SA5, SA6b, SA7b, SA8b
and the opener), `test_ase_log_seam_0207` loses its whole 26.

## The one-word fix, measured

Same binary, same tests, with the flag they are owed:

```sh
./src/xschem --pipe -q --logdir <tmp> --script tests/headless/test_ase_log_seam_0207.tcl
RESULT: ALL PASS (26 checks)

./src/xschem --pipe -q --logdir <tmp> --script tests/headless/test_select_at.tcl
RESULT: ALL PASS
OVERALL: ok
```

Fix: add `test_ase_log_seam_0207` and `test_select_at` to `logdir_tests` in
`tests/headless/full_audit.sh`.

⚠ `--nolog` and `--logdir` are **mutually exclusive** (the binary aborts outright), so a case
moved into `logdir_tests` must not also be invoked with `--nolog` — worth checking against
`run_suites.sh --nolog`, which is exactly the combination that aborts.

## Why it is not merge 5

Both failures are in the pre-merge audit baseline recorded on the fluid side
(`doc/claude/calculator_batch/receipts/00b-audit-baseline-2026-08-14.txt`, taken at `8423240a`,
an ancestor of the merge), and neither test file nor `logdir_tests` was touched by `7af2da9e`.
The failure mode is a harness-invocation gap that has been there since each test was written.
