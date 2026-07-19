# Item 03 redo - atom 28

- commit: fa2344e63b850f7df26aa0753dcf1c273668d3b0
- test: tests/headless/test_perform_action_redo.tcl (33 checks)
- verifier: OK

## Sabotage matrix

| # | Sabotage | Target / detection | Failed exactly as predicted |
|---|----------|--------------------|-----------------------------|
| A | boundary bypassed (raw inline gate+pop+log+reset body restored at the branch) | grep-guard rows (S1 delegation + 4 S7: delegation==1 got 0, literal-log==0 got 1, readonly-reject==0 got 1, (1,1)==1 got 2); runtime .tcl predicted to stay green | yes |
| B | spurious xctx->push_undo() in the run_core arm before the pop | (a)/(f) truncated-redo-tail signature (instances stays 0), plus the audit-documented same-signature collateral on the other redo-driving effect checks (b)/(d)/(h) | yes |
| C | per-verb raw-argv log arm in core_log_action (log_action_argv passthrough) | (b) only: 'xschem redo extra' logged non-bare, exact-bare +0 | yes |
| D | log gated on did-something (run_core TCL_ERROR at cur_undo_ptr >= head_undo_ptr) | (e) only: empty-redo-stack no-op returned rc error with +0 log | yes |

## Non-baseline audit fails

- test_altf5_ciw
- test_deselect_mode
- test_palette
- test_key_graph_context
- test_fluid_editing

## Docs

- doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
- doc/claude/code_analysis/perform_action_atom28_redo_decision.md
- /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/MEMORY.md

## Summary

Atom 28 (redo -> perform_action boundary, the first strictly ZERO-DELTA consistency migration) shipped as commit fa2344e6 on fluid-editing. CRASH RECOVERY: the working tree already held a prior implementer's complete uncommitted edits (branch delegation at scheduler.c:8897, run_core arm with pop_undo_keep_selection(1,1), the two header rosters, the 33-check test, the S1 delegation row + 6-row S7 exact-count block, full_audit registration, audit doc s48, decision doc status, MEMORY.md line) but NO commit; I verified every edit against the prompt (all correct, nothing missing), then independently re-ran everything rather than trusting the dead session's claims. Atom test 33/33 green, grep guard ALL PASS, siblings (delete/clear_drawing/check_unique_names/toggle_ignore/undo_selection/undo_link_symbols/action_log_dispatch) green, selflog_output's deterministic redo checks pass (only its baseline WSLg transform-key set fails). All four sabotages re-verified THIS session with inverse-Edit reverts (git checkout was unusable since scheduler.c held the real uncommitted work): A left the runtime fully green while S1+4 S7 rows failed closed (the load-bearing lock, as predicted); B/C/D each hit exactly their target. Clean rebuild + re-run green. full_audit (run once): 169 pass/18 fail/1 timeout; the 5 non-baseline names are NOT the atom's - test_deselect_mode, test_palette, test_key_graph_context all pass in isolation on the same binary, test_altf5_ciw is a nondeterministic WSLg raise flake (2/3 pass in isolation, the documented keybind-raise gotcha), test_fluid_editing is explicitly allowed to flake per PLAN.md header; none touch the redo path. Commit staged the explicit 6-file list only (scheduler.c, new test, grep guard, full_audit.sh, audit doc, decision doc); MEMORY.md updated with the hash (outside the repo, not committable). PLAN.md ledger left untouched per the prompt (pipeline-owned). Next per PLAN.md: item 04 get_additional_symbols.
