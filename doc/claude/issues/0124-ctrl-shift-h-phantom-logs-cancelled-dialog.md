# 0124 — Ctrl+Shift+H phantom-logs a cancelled make_sch_from_sel dialog

**Status: FIXED** (2026-07-18, bug-fix batch item 3; commit e6419588 on `fluid-editing`). What changed:
`src/actions.csv:124` gained the 11th field `nolog=1` (startup loop then calls
`xschem set_action_nolog` for the id, so `d->log_cmd` stays NULL and dispatch's Layer-A
fallback is permanently silent for this action); stale comment above the core self-log in
`src/save.c` (~:5392) updated to say the core is now the ONLY log site for every entry point;
NEW key-path regression test `tests/headless/test_key_make_sch_from_sel_log.tcl` (checks
A1/A2 subcommand cancel/success, B key cancel+overwrite-refuse phantom, C key success exactly
one line, D1/D2 readonly, E no mutation) registered in `full_audit.sh` `logdir_tests`.
Sabotage-verified: S1 (csv nolog removed) fails exactly B; S2 (core self-log `if(0)`) fails
exactly A2+C; S3 (registry mutates=0) fails exactly D2.

Notes:
- (a) The overwrite-refuse branch (filename == current schematic -> messageBox) was a SECOND
  phantom on the same mechanism (the edit block is skipped, the handler still returns 1);
  fixed by the same nolog flag and covered by check B's second drive.
- (b) The act handler's unconditional `return 1` (callback.c:3434) is now harmless — Layer A
  is permanently silent for this id — and is left as-is deliberately.

*(original report below)* — found 2026-07-18 by the Refactor B batch item-07 scout while
DEFERring the `make_sch_from_sel` migration; independent of that migration — fixed standalone,
not bundled.

## Symptom

Press Ctrl+Shift+H (the `act_make_sch_sym_from_sel` chord), then Cancel the save-file dialog.
Nothing was edited — but the action log still records the command line. Replaying such a log
re-pops a dialog for an edit that never happened.

## Mechanism

- The key path calls the core `make_schematic_symbol_from_sel()` DIRECTLY (callback.c:3434;
  chord at callback.c:3976; registry row callback.c:3690 with mutates=1; Layer-A log_cmd from
  actions.csv:124 via xschem.tcl:13931-13941).
- The core self-logs ONLY on the real edit (save.c:5397) and skips `log_action` on Cancel —
  correct so far.
- But the act handler returns 1 unconditionally, so on Cancel `actionlog_cmd_logged` stays 0 and
  `dispatch_input_action`'s Layer-A fallback copy fires anyway (callback.c:4143-4145) — the
  phantom line.
- `test_selflog_output.tcl` only exercises cancel on the SUBCOMMAND path (scheduler branch),
  which does not phantom-log — so the key-path hole is untested and invisible to the suite.

## Fix (scout's recommendation, verified cheapest)

An `actions.csv` `nolog` flag on row 124 alone. The core's self-log already covers the key's
success line, so silencing the Layer-A copy removes ONLY the phantom Cancel line. Add a key-path
cancel test (full Tk event sequence per gesture-test-full-sequence discipline).

## Cross-refs

- Batch scout receipt: doc/claude/refactor_b_batch/receipts/07_make_sch_from_sel.md
- Self-log-at-core family locks: test_selflog_grep_guard.tcl:492, :606-623, :671-677
- Related deferred migration: PLAN.md item 07 (rank-14 self-logging-core exemption unlock)
