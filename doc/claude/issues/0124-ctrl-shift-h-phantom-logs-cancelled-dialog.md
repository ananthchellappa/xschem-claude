# 0124 — Ctrl+Shift+H phantom-logs a cancelled make_sch_from_sel dialog

**Status: OPEN** (found 2026-07-18 by the Refactor B batch item-07 scout while DEFERring the
`make_sch_from_sel` migration; independent of that migration — fix standalone, do NOT bundle).

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
