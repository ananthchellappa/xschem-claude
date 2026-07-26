# Item 10 fluid_pass - DEFERRED at scout stage.

fr: 4

## Reasons

- Defer trigger 1 CONFIRMED from source: harness-only, no production entry. Repo-wide grep for `xschem fluid_pass`/`xschem fluid_snapshot` finds only the scheduler.c branch itself (scheduler.c:3418-3435; plan's :3283 drifted), move.c comments, and one Track-D test (tests/headless/wireedit/test_wireedit_56_fluid_pass_harness_d6.tcl). No xschem.tcl -command, no keybindings.csv row, no callback.c key. Migration yields zero production log coverage.
- Defer trigger 2 CONFIRMED from source: arm-state dependency is unresolvable within the rubric. move.c:4944-4959 documents the gesture-state contract -- passes are novelty-scoped against fluid_g.start_wire and fail-safe-decline (return 0) when fluid_g.snap_pinnet is NULL, i.e. without a prior `xschem fluid_snapshot arm` (scheduler.c:3399-3409, unlogged). A logged fluid_pass line alone replays as a decline, not the recorded effect; making it self-contained would require logging fluid_snapshot, a D2 transient gesture-state store the rubric excludes.
- D4 name-routing stands (atom-24 rubric table line 95 re-verified): fluid_harness_run_pass (move.c:4964-4985) dispatches fluid_end_passes[] (table at move.c:4681) by name via p->fn(); the identical pass fns run raw inside the real move_objects END cluster (move.c:7568-7572) and the idempotence probe (move.c:4916-4942), where they are logged as the move and must stay raw.
- Load-bearing Tcl result: the branch returns the changed-count (scheduler.c:3433-3434) and the D6 test consumes it (`set changed [xschem fluid_pass straighten_reversals]`, test lines 47/60/73-75). The boundary's Tcl_ResetResult-on-success would clobber it -- the same result-consumption objection that deferred item 09 apply_properties.
- Core pushes NO undo and the branch has NO readonly gate today; the harness is a diagnostic tool, so a boundary readonly gate would newly refuse read-only diagnostic runs for no production benefit.
- Only plausible unlock is a harness/test-verb log-exemption class, which by definition yields zero production coverage -- per the plan's own rationale this cannot justify an atom. DEFER as zero-gain; no files written per task rules.
