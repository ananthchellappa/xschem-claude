# Item 02 clear_drawing - atom 27

- commit: 20f71c45b0b91f445381740e9f26fd98404bd7c1
- test: /home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_perform_action_clear_drawing.tcl (29 checks)

## Sabotage runs

| name | target | failed exactly |
|---|---|---|
| A: drop run_core argc gate (restore old skip-body semantics) | check (b) arity tighten | true |
| B: bypass boundary in branch (restore raw inline body) | check (c) readonly gate + S1 delegation row + S7 delegation row | true |
| C: spurious xctx->push_undo() in run_core arm | check (f) no-spurious-push | true |
| D: log_action("xschem clear_drawing") inside the core (actions.c) | check (g) shared-core spam lock + S7 actions.c ==0 row | true |

## Non-baseline audit fails

- test_altf5_ciw
- test_fluid_editing
- test_graph_context
- test_remap
- test_verb_noun_copy_move
- test_wire_vertex_grab

## Docs

- /home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md (new §47 + §46 RECOMMENDED NEXT superseded)
- /home/qflow/dev/xschem/claude_1/xschem/doc/claude/code_analysis/perform_action_atom27_clear_drawing_decision.md (Status: PROCEED -> IMPLEMENTED, outcome paragraph)
- /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/MEMORY.md (action-logging line: atom 27 done, next item 03 redo)

verifier: OK

## Summary

Refactor B atom 27 implemented per the prompt, start to finish. All anchors re-verified from source (no drift beyond the documented branch line). Pre-migration oracle pinned on the HEAD binary first: readonly view silently EMPTIED (rc=0), extra-arg silent TCL_OK no-op, symbols survive a clear. Code: scheduler.c branch 2388 -> `return perform_action("clear_drawing", argc, argv)` with the extended doc comment; new run_core arm (argc==2 gate + unselect_all(1)+clear_drawing(), no push_undo/set_modify/draw) before the unreachable default; both header rosters (run_core ~:191, core_log_action ~:1039) gained the verb; NO core_log_action arm (default `xschem %s`); actions.c untouched in the commit. Test: 29 checks (a-g incl. symbols-survive contract, arity tighten, NEW readonly gate, replay seam+control, no-op-still-logs, no-spurious-push irreversibility detector, sibling `xschem clear` spam lock), ALL PASS, registered in full_audit logdir_tests. Sabotage-verified x4: (A) failed ONLY the 3 (b) checks; (B) failed (c) incl. the readonly-emptied proof (3->0) AND the S1+S7 delegation rows (collateral a/b/d/e = the removed boundary itself, predicted); (C) failed ONLY (f) (undo resurrected the instance); (D) failed (g) AND the S7 actions.c ==0 row (collateral a/d-control/e read +2 = the same spam, predicted). Each reverted byte-exact (diffed against a good snapshot; actions.c via git diff + targeted checkout), clean re-runs green. Grep guard: S1 floor row, clear_drawing in S2 CVERBS (out of S3), 4-row atom-27 S7 exact-count block; green. Siblings delete/add_pin_stubs/check_unique_names green. full_audit: exit=1 with the 14 PLAN.md baseline fails plus 6 others - test_graph_context/test_verb_noun_copy_move/test_wire_vertex_grab PASS standalone (parallel-run flakes) and test_altf5_ciw/test_fluid_editing/test_remap reproduce IDENTICALLY on the rebuilt pristine HEAD binary (plus intermittent 'SKIP (no X)') - WSLg X-server focus/raise flakiness, verified NOT caused by this atom (zero repo callers of the verb exist for a coupling mechanism). Docs: audit §47 in §44/§46 house style, §46 tail superseded, decision-doc Status updated, MEMORY.md action-logging line updated (next = PLAN.md item 03 redo). PLAN.md ledger deliberately NOT ticked (owned by the pipeline's ledger stage). ONE commit 20f71c45 on fluid-editing, explicit 6-file list, message per the prompt with the Co-Authored-By trailer; not pushed.
