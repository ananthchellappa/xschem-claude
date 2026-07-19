# Item 05 undo - atom 29

- commit: 96a1c00e
- test: tests/headless/test_perform_action_undo.tcl (46 checks)

## Sabotage runs

| name | target | failedExactly |
|---|---|---|
| A boundary bypass (raw inline branch body restored) | grep-guard rows: S1 undo delegation + S7 exact counts (runtime .tcl must stay fully green) | true |
| B spurious xctx->push_undo() before the pop in run_core's undo arm | (a) instances stays 1 (push-then-pop signature) | true |
| C raw-argv passthrough in the normalizing arm (argv[2]/argv[3] logged as strings, atoi dropped) | (b2) only | true |
| D per-verb arm deleted (fall through to default %s) | (b1), predicted collateral (b2)/(b3)/(b4) | true |
| E did-something gate (run_core TCL_ERROR at cur_undo_ptr==tail_undo_ptr) | (e) — prompt predicted ONLY (e) | false |

## Non-baseline audit fails

- test_altf5_ciw
- test_deselect_mode
- test_palette
- test_perform_action_flipv
- test_perform_action_reset_symbol
- test_readonly_action_dispatch
- test_sympin_drop_log
- test_verb_noun_copy_move
- test_wire_vertex_grab

## Docs

- doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
- doc/claude/code_analysis/perform_action_atom29_undo_decision.md
- /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/MEMORY.md

verifier: OK

## Summary

Atom 29 (undo) shipped exactly per prompt, COMMITTED 96a1c00e (6 files: src/scheduler.c, new tests/headless/test_perform_action_undo.tcl, tests/headless/test_selflog_grep_guard.tcl, tests/headless/full_audit.sh, audit doc +S49, new decision doc). Branch -> return perform_action("undo", argc, argv); run_core argv-parsed arm (atoi defaults 0/1, NO arity gate, NO push_undo); core_log_action NORMALIZING arm (bare at argc==2, atoi-canonical default-filled tail-dropped `xschem undo %d %d` else); both header rosters + redo-arm F-shared prose updated. Oracle pinned on the PRE-migration binary FIRST: all 46 checks pass on BOTH binaries (zero delta). Sabotage x5: A failed EXACTLY the 6 undo grep rows while the runtime test passed IN FULL; B failed (a) with same-signature collateral on the other undo-direction checks (b2/b4/d/f/g — prompt named only (f)); C failed ONLY (b2); D failed (b1)+predicted (b2)/(b3)/(b4); E failed (e) exactly as predicted (+0 log, rc error; (e) trips ONLY under E) but with collateral on (b1)-(b4) beyond the prompt's "ONLY (e)" — at stack bottom cur==tail even with a redo tail armed, so the naive gate also blocks the redo-wearing-undo forms (mechanism implemented verbatim from the prompt; recorded in S49 + decision doc). Each sabotage reverted byte-exact (cmp-verified against pristine copy), clean re-runs green. Grep guard: S1 delegation row replaces the floor row; 5-row S7 exact-count block added; atom-28 twin rows' counts unchanged, prose re-homed; sabotage-A proved all 6 rows load-bearing. Siblings green: test_perform_action_redo (unedited), delete, clear_drawing, check_unique_names, undo_selection, undo_link_symbols, undo_move_keep_selection, action_log_dispatch, undo_stable_ids 26/26; test_selflog_output fails only its baseline WSLg transform-key set (undo checks :43-44/:53-57 pass). full_audit run twice: all 14 PLAN.md baseline fails + test_fluid_editing flake present; the 9 nonBaselineFails listed are the recurring WSLg focus/raise/gesture flake pool — the set is UNSTABLE across the two runs (each test failed in only one of the two runs except altf5_ciw/verb_noun_copy_move/wire_vertex_grab), EVERY one re-verified green in isolation on the migrated binary, and the atom-28 commit recorded the same pool (altf5_ciw/deselect_mode/palette) as WSLg flakes; run 1 was additionally polluted by a concurrent one-off xschem run of mine. test_perform_action_undo, test_perform_action_redo and test_selflog_grep_guard PASS inside both audit runs. Decision-doc Status updated with the implementation outcome; MEMORY.md action-logging line updated (atom 29 done, next = PLAN.md item 06 wire). PLAN.md ledger NOT ticked (pipeline-owned). Nothing pushed.
