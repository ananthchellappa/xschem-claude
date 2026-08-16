# 0415 — `test_ase_log_seam_0207` and `test_select_at` are missing from `logdir_tests`

Status: **FIXED** — 2026-08-15, on `fluid-editing` (merge-5 loose ends, item 01).
Filed on the open_pdk side: measured green with the flag, one-word fix identified,
left unapplied there. Pre-existing; predates merge 5 (`7af2da9e`).
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
and the opener); `test_ase_log_seam_0207` reds **16 of its 26** (measured: `RESULT: 16 FAILED
(10 passed)`). The 10 survivors are not evidence either — PS9, PS10a, PS10b, PS11, PS13, RP2
and RP3 assert *absences* ("no stray line was logged", "replay executed nothing") and pass
vacuously over a log that was never opened. All 26 are worthless without the flag; only 16
of them say so out loud. (An earlier revision of this line said "loses its whole 26", which
the measurement below contradicts.)

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

---

## FIXED — what was applied, and the evidence (2026-08-15, at `938388a5`)

`tests/headless/full_audit.sh`: the two names added to `logdir_tests`, with the rationale
and the abort trap recorded above the list. Both test files' headers now name their own
registration, matching the convention ~60 sibling suites already carry
("Needs the action log open -> registered in `full_audit.sh` `logdir_tests`"). Those two
edits are comment-only — `git diff -U0` on them contains no non-comment line.

**The abort trap: proven, not asserted.** Three independent measurements:

1. **The lists do not overlap.** Sourced in `AUDIT_LIB_ONLY=1` mode and enumerated:
   `logdir_tests ∩ nolog_tests = ∅` and `logdir_tests ∩ nogui_tests = ∅` (the `nogui`
   arm passes `--nolog --nogui`, so it counts). `nolog_tests` holds exactly `test_nolog`.
2. **Overlap could not matter anyway.** `full_audit.sh:435-449` is an `if/elif` chain with
   `in_list "$name" "$logdir_tests"` as its FIRST arm, so a name takes exactly one arm and
   can never be handed both flags.
3. **`run_suites.sh --nolog` cannot arise.** `run_suites.sh` has no `--nolog` option at all;
   `nolog` is its default *mode*, selected by the absence of a flag. Passing it explicitly
   hits the `-*)` arm: `run_suites: unknown option --nolog`, exit 2, before any binary runs.
   The binary's own guard was exercised directly for completeness —
   `./src/xschem --nolog --logdir <tmp>` → `xschem: --nolog and --logdir are mutually
   exclusive, aborting.`, exit 1 (`src/util.c:344-349`).

**Red/green drive** (this is a harness list edit and adds no new `.tcl` checks; the drive is
the evidence that stands in for a sabotage). Same binary, same dev display `:99`, only the
list edit differs:

| direction | `test_ase_log_seam_0207` | `test_select_at` |
|---|---|---|
| **without** the names (list reverted from a byte-exact backup) | `FAIL` — first failing line `FAIL: PS0 action log open (needs --logdir) -> {0} (exp {1}) : FAIL`; `RESULT: 16 FAILED (10 passed)` | `FAIL` — first failing line `FAIL: action log open`; `RESULT: 5 FAILED` (SA5, SA6b, SA7b, SA8b and the opener, exactly as filed) |
| **with** the names (restored from the byte-exact backup) | `PASS` — `RESULT: ALL PASS (26 checks)` | `PASS` — `RESULT: ALL PASS` |

The reverted-direction counts reproduce the merge-5 A/B table
(`doc/claude/code_analysis/open_pdk_merge5_result.md` §6) exactly: 16 FAILED (10 passed) and
5 FAILED.

**Not widened, deliberately.** `test_ciw` and `test_selflog_output` are named next to 0415 in
that write-up, but they were **already** on `logdir_tests` before this fix and their audit
reds have nothing to do with the flag — the baseline shows both printing `ok: action log
open` / `ok: actionlog_filename set` and then failing elsewhere (`FAIL: no result/error text
in file`; six `key <mod>-<k> logs …` rows, the known WSLg `event generate` delivery flake).
What that write-up actually records for them is a *`run_suites.sh` invocation-mode* mismatch
(its default mode is `--nolog`), not a `logdir_tests` membership gap. They are out of scope
here and stay red in the baseline.

Receipt: `doc/claude/merge5_loose_ends/receipts/01-logdir-tests-0415.md`.
