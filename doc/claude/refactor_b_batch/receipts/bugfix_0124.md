# Receipt: bug-fix batch item 3 — issue 0124

Item 3 issue 0124.

- commit: e6419588
- test: tests/headless/test_key_make_sch_from_sel_log.tcl (7 checks)
- sabotage:
  - S1 csv nolog removed (buggy row restored) -> target: B KEY cancelled/refused dialog logs nothing (issue 0124 phantom) — failed exactly
  - S2 core self-log wrapped in if(0) (literal kept for grep-guard) -> target: A2 subcommand success logs exactly one line + C KEY success logs exactly one line (declared two-check set) — failed exactly
  - S3 registry mutates field 1->0 (callback.c ActionDef row) -> target: D2 KEY readonly never opens the dialog — failed exactly
- non-baseline fails: none
- verifier: OK

## Scout scope

Full fix, no narrowing needed: product change is ONE csv field (src/actions.csv:124 append `,1`) plus a comment-only save.c correction (the stale "Ctrl+H logs via Layer A" sentence at save.c:5392-5396, worded to avoid the grep-guarded literal); no C behavior, scheduler, or core-log change. Support scope: new headless test tests/headless/test_key_make_sch_from_sel_log.tcl (checks: key cancel+overwrite-refuse +0 lines, key success exactly +1, subcommand cancel/success controls, readonly no-log + dialog-never-opened, cancel-mutates-nothing) with three named sabotages (csv-revert -> exactly check B; if(0) core log -> declared A2+C pair; mutates=0 -> exactly D2), full_audit.sh logdir_tests registration, issue-file FIXED update, memory per discipline. Residuals recorded at implement time in the issue file: act handler still returns 1 unconditionally (harmless once the row is nolog, deliberate) and the deferred item-07 boundary migration remains separate (do NOT bundle).

## Summary

Issue 0124 FIXED, commit e6419588 on fluid-editing (5 files, explicit list, not pushed). Fix: src/actions.csv:124 gained 11th field nolog=1 (startup loop calls set_action_nolog, d->log_cmd stays NULL, dispatch's Layer-A fallback permanently silent for the Ctrl+Shift+H action; core self-log in save.c covers the success line from every entry point) + comment-only rewrite of the stale save.c sentence above the self-log (log_action literal count stays exactly 1 for grep-guard :492). All prompt anchors re-verified from source before editing; no C behavior change (rebuilt, clean). New test (7 checks: A1/A2 subcommand cancel/success, B key cancel+overwrite-refuse phantom regression, C key success exactly-one, D1/D2 readonly no-log/dialog-never-opens, E no-mutation) ran ALL PASS under X (key path exercised, full Tk event keysym 72 state 5), registered in full_audit.sh logdir_tests. Sabotage x3 each failed EXACTLY its target then clean re-run green. full_audit (once, before commit): new test PASS; fails = the 14-test PLAN.md baseline plus 4 audit-congestion flakes (test_altf5_ciw FAIL, test_key_graph_context TIMEOUT, test_perform_action_trim_wires FAIL, test_perform_action_undo TIMEOUT) which all PASS in an isolated subset full_audit run (which also satisfied the once-via-full_audit requirement for the new test) — none touch make_sch_from_sel, so nonBaselineFails is empty. Required-green singles all PASS: test_selflog_grep_guard, test_key_graph_context (isolation), test_action_log_dispatch, test_delete_cut_selflog, test_keybindings_help; test_selflog_output's three make_sch_from_sel checks (cancel/real-edit/read-only) plus the TCL_ERROR check still print ok inside its audit output. Issue file Status->FIXED with the two required notes (overwrite-refuse second phantom covered by check B; unconditional return 1 left as-is); memory: 0124 block appended to action-logging.md batch section, MEMORY.md action-logging line extended by one clause.
