# Item 01 check_unique_names - atom 26

- commit: 3702df0bfccf4268bf124190cb704a92dac34760
- test: tests/headless/test_perform_action_check_unique_names.tcl (38 checks)
- verifier: OK

## Sabotage runs

| name | target | failedExactly |
|---|---|---|
| A: readonly-gate the mode-0 raw front (the whole-verb-delegate over-reject consequence) | (b2) read-only query NOT over-rejected | true |
| B: drop the branch mode-0 log_action | (b) logged query +1 'xschem check_unique_names 0' | false |
| C: spurious xctx->push_undo() in the run_core arm | (e) undo depth (second undo peels the fixture setprop) | false |
| D: bypass the boundary in the branch (raw check_unique_names(1) + inline log) | (c) read-only mutate refused AND the S1 delegation + S7 exact-count grep rows | true |
| E: revert Ctrl+# to the raw unrouted call | (f) Ctrl+# +1 log / read-only key refused | true |

## Non-baseline audit fails

- test_perform_action_reset_symbol
- test_perform_action_rotate

## Docs

- doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
- doc/claude/code_analysis/perform_action_atom26_check_unique_names_asymmetric_split_decision.md
- doc/claude/issues/0068-unmigrated-legacy-switch-keys-not-logged.md
- /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/MEMORY.md

## Summary

Atom 26 shipped as specified: asymmetric logged-query/mutate split for check_unique_names (mode-1 rename via perform_action gaining the missing readonly gate — the pre-migration binary oracle-verified a silent read-only RENAME; mode-0 highlight stays raw-front AND keeps its own 'xschem check_unique_names 0' log) + '#'/Ctrl+# key routing (0068 partial close; Ctrl+# via boundary with av[2]="1", '#' raw + own log). run_core/core_log_action arms (fixed '1' literal), branch split, header-comment lists updated. Fixture deviation (oracle-pinned): the prompt's 'setprop instance 1 name R1 fast' does NOT skip uniquify (only -fast is parsed and it only skips undo/draw; new_prop_string reads the disable_unique_names tclvar) — the duplicate pair is forced under set ::disable_unique_names 1. New 38-check test green standalone AND inside full_audit; registered in full_audit.sh logdir_tests. Grep guard: old S1 prefix row replaced by 3 scheduler.c rows + 2 callback.c rows added + a 7-check S7 exact-count fail-closed block; S2 CVERBS kept, out of S3; guard green. Sabotage ×5, each reverted to a byte-exact intended diff (md5-verified; git-checkout revert was unusable because the real work was uncommitted) with clean re-runs green: A failed exactly (b2); B failed target (b) plus (b2)/(d-control)/(g) — all four assert the SAME single removed branch log line, no unrelated checks failed, and the '#'-key logs kept passing (proving the split's second site); C failed target (e) plus (e2)'s no-push undo probe — both are the same double-push detector; D failed exactly (c) plus exactly the named S1 delegation + S7 '...1' grep rows; E failed exactly (f)'s two Ctrl+# sub-checks. full_audit SUMMARY: 179 pass / 15 fail / 1 timeout, WIREEDIT ALL PASS — the 14 PLAN.md baseline fails plus TWO non-baseline casualties of a single X-server drop window: test_perform_action_reset_symbol ('X connection to :0 broken' in its audit output) and the alphabetically-consecutive test_perform_action_rotate ('timeout: dumped core'); both re-run standalone GREEN (reset_symbol twice), neither is touched by this diff, and both verbs' grep exclusivity rows pass — environment flakes, not atom-26 regressions. test_selflog_output fails only its baseline WSLg transform-key set; its deterministic check_unique_names checks (:352-357) pass. Committed 3702df0b (8 files: src/scheduler.c, src/callback.c, new test, grep guard, full_audit.sh, audit doc §46 + §45 tail, decision doc w/ implementation-outcome Status line, issue 0068 note); PLAN.md ledger deliberately untouched (pipeline-owned); MEMORY.md action-logging line updated (next = PLAN.md item 02 clear_drawing).
