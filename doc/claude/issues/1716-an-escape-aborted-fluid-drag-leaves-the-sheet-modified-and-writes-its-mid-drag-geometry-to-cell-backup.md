# 1716 — an Escape-aborted fluid drag leaves the sheet modified and writes its mid-drag geometry to `cell~.sch`, because `insert_exit_stubs()` calls `set_modify(1)` on every live reroute step

**STAMP:** `v1 claim=fixed tree=3b36f24a1 stamped=2026-11-15 fix=superseded open=0 super=self by=drag_perf-D`

Found by the selection-look batch's realistic-timing crew
(`doc/claude/selection_look_batch/receipts/realistic-timing.md`, the paragraph "A base defect
seen on the way (both trees)"). The crew did not diagnose it. It was reproduced and diagnosed
while filing, on the base build `~/gsl0` (a clone of `e3c43487e` whose `src/` is identical to
HEAD for every function cited here). The run used a private Xvfb, a throwaway HOME and a
scratch copy of `sky130A`. **The batch did not cause it.** Filed, not fixed.

## What the crew saw (observation, not re-derived)

`*~.sch` backup files appeared in the scratch copies of every page whose drags the crew had
aborted with Escape. Its poses press on a selected device, send twelve motions, then press
Escape and release, with `sky130A/cadence_style_rc` sourced. The crew did not establish where
the files came from.

## Measured while filing

The fixture was the bundled `sky130A/xschem_libs/sky130_tests_ase/bandgap/schematic/bandgap.sch`,
a tracked file, with `cadence_style_rc` sourced (`fluid_editing 1`, `autotrim_wires 1`). Three
objects were selected: the title block `l1` and the pins `p2` and `p4`. The crew's own gesture
followed: press on `l1`, twelve motions, Escape, release.

| step | `xschem get modified` | `bandgap~.sch` exists | `ui_state` |
|---|---|---|---|
| selected, before the press | 0 | no | `SELECTION` |
| first motion | **1** | **yes** | `SELECTION\|STARTMOVE` |
| twelfth motion | 1 | yes | `SELECTION\|STARTMOVE` |
| after Escape | **1** | **yes** | `SELECTION` |
| after release | 1 | yes | `SELECTION` |
| after the process exits | — | **yes, left on disk** | — |

- **The backup holds the cancelled drag.** In `bandgap~.sch`, `l1`, `p2` and `p4` are all
  displaced by (+70,+50) from `bandgap.sch`. It also has 50 `N` (wire) records against the
  cell's 48, the live reroute's extra segments. No other instance differs. By reading, Escape
  restores the buffer itself to the pristine snapshot; only the flag and the file are left
  behind.
- **The stack, from gdb on the same binary.** The breakpoint was `set_modify` with argument
  1 or 3. Over the twelve motions it hit 11 times, and each hit was followed by a
  `write_backup` hit. Every backtrace reads `set_modify` ← `move_objects` ← `callback`.
  - `insert_exit_stubs()` does not appear in the trace because it ends in a tail call (its
    last statement compiles to `jmp set_modify`).
  - The return address in `move_objects` is the instruction right after its
    `call insert_exit_stubs`, so that call site is the caller.
- **One caveat about the gesture.** In this run the first press-drag of the session, on `l1`
  alone, became a rubber-band selection (`SELECTION|STARTSELECT`), not a move, and left the
  sheet clean. It was used as a warm-up. It is **not** evidence that a one-object drag is
  clean, and nothing here measured one.

## Cause (confirmed by reading code, and consistent with the measurement above)

- **A live step goes through the commit block.** On a fluid stretch, each live RUBBER step
  of `move_objects` (`src/move.c`, incremental-reroute Phase II) restores the pristine
  snapshot and sets `commit_now`. It then falls through into the shared commit block, which
  is guarded by `(what & END) || commit_now`.
  - END-only work in that block is fenced off by `if(!commit_now)`, and fluid passes are
    fenced by `FLUID_PASS_END_ONLY`.
  - The `insert_exit_stubs()` call is fenced by neither. Its condition is `stretch_select`,
    then `wire_exit_stub || fluid_editing`, then `leg_ortho`, no rotation or flip, and the
    last leg.
- **`insert_exit_stubs()` ends in an unconditional `set_modify(1)`**, whether or not it
  inserted a stub.
- **`set_modify(1)`** sets `xctx->modified`. Through `write_backup()` it also writes the whole
  live buffer, mid-drag geometry included, to `cell~.sch`, and records that path in
  `xctx->backup_owned`.
- **ABORT rolls the geometry back and touches neither the flag nor the file.** Its comment
  says *"No set_modify(): the RUBBER steps never set it (see the live-step branch), so an
  aborted fluid drag leaves the buffer's modified flag exactly as it was pre-drag."* The
  live-step branch says *"Deliberately NO set_modify() here … so a fluid drag that is aborted
  or returns to the origin stays clean (no spurious modified/save-prompt)."*

**So this is a defect, not the documented autosave behaviour.** `set_modify` documents
autosave as firing on *"a genuine edit"*, and `move_objects` documents an aborted or
returned-to-origin fluid drag as not one. Both comments describe the intended contract;
`insert_exit_stubs()` breaks it on every live step. A search of `tests/headless/` when
filing found no row asserting the modified flag or the backup after an aborted fluid drag.
The paste-abort sibling has one (0244's suite).

## Consequences

Measured:

- After Escape the sheet stays modified.
- A `cell~.sch` holding the cancelled geometry is written during the drag.
- An exit that does not go through a save or discard leaves that file on disk. In the crew's
  runs and in this one, that exit was a script's `exit`.

By reading, not measured:

- **The current session.** The title shows `*`. Closing, quitting or going up a level asks
  "has unsaved changes" about a sheet the user did not change. "No" removes the owned backup.
  "Yes" saves the rolled-back buffer, which is the original geometry, so the session itself
  is not corrupted.
- **A later session.** After a crash, a kill or a scripted exit, the leftover `~` is newer
  than the cell.
  - On open, `xschem_recover_backup` offers *"Recover unsaved changes?"*, and Yes restores
    the cancelled drag.
  - On the way up a hierarchy, `go_back` loads it with no question at all (**1715**). That is
    how the realistic-timing crew met it.
- **A sheet that was already modified before the drag.** Its `~` holds real unsaved edits.
  Each live step overwrites that `~` with mid-drag geometry, and Escape does not rewrite it,
  so a crash after an aborted drag recovers the cancelled drag rather than the user's edits.
- **The enforcement refusal arm restores the wrong flag.** On an END refused by
  `fluid_enforce_invariants`, `move_objects` restores `enf_mod_before`. That value is
  captured at END, **after** the live steps have already set the flag. So a refused fluid
  drag of a clean sheet also stays modified, and its `~` holds the refused geometry.

Scope: measured only with `cadence_style_rc` on `bandgap.sch`. By reading, the call's
condition needs `fluid_editing` (default 1 in `src/xschem.tcl`) or `wire_exit_stub`, a
stretch drag, an orthogonal leg and no rotation or flip. A default session therefore likely
reaches it too; that was not measured. The crew saw backups on every page it aborted drags on.

## Whose defect it is

It is the fork's, not upstream's. At `f276d0cf2` (upstream xschem, the fork base)
`insert_exit_stubs`, `commit_now`, `write_backup` and `autosave_backup` occur zero times in
`src/`. None of the commits below is an ancestor of `f276d0cf2`; all are ancestors of HEAD.

- `8ba5ddf73` (2026-06-19, "feat(wire-editing): Phase 6 exit-stub preservation behind
  wire_exit_stub switch (TC10)") introduced `insert_exit_stubs()` with its unconditional
  `set_modify(1)`. It was harmless then, because the function ran only at a real END, which
  sets the flag anyway.
- `c408fe3ec` (2026-06-21, "feat(autosave): B1 backup-file helpers (cellName~.sch)") made
  `set_modify(1)` write the backup.
- `51ab52982` (2026-07-06, "feat(fluid-editing): incremental per-snap-step wire reroute
  (Phase II)") routed live steps through the commit block. That is the change that made the
  call fire on every step.

## Related

- **1715**: how a leftover `~` from this defect turns into a spurious prompt, and a Yes that
  saves the cancelled drag.
- **0244** (fixed): Escape on a paste or merge corrupted the modified flag in the other
  direction. Its fix saves and restores the pre-gesture flag, which is the precedent for this
  one.
- **1486**: backup ownership (`backup_owned`).

## Proposed fix (NOT built)

1. **Do not dirty on a live step.** Have `insert_exit_stubs()` leave the flag to its caller,
   or call `set_modify(1)` only when it stored a stub **and** the step is a real END. A real
   END already calls `set_modify(1)` itself after a committed move, so nothing is lost there.
2. **Defence in depth on ABORT.** Capture `xctx->modified` at gesture START and restore it on
   ABORT, as 0244's fix does for paste.
   - If this gesture created the `~`, remove it (it is owned).
   - If the sheet was dirty before the drag, rewrite the `~` from the rolled-back buffer.
   - Capture `enf_mod_before` from the same START value rather than at END.
3. Once the flag is right, the two comments quoted above become true again. They need no
   edit, only a fence.

## Open items

1. The fix above.
2. A fence row, with an Escape-aborted fluid stretch drag of several devices with wires on a
   scratch copy of `bandgap.sch`.
   - Assert `xschem get modified` is 0 after every motion and after Escape, and that no
     `bandgap~.sch` exists at any step.
   - A second leg plants a `~` first (the dirty-before case) and asserts it is
     byte-identical after Escape.
   - Non-vacuity legs: `ui_state` carries `STARTMOVE` during the motions, and the live
     geometry really moved mid-drag. In this run the first gesture of a session did not
     start a move at all.
3. Check, by building it, the enforcement refusal arm above: a refused fluid drag of a clean
   sheet should leave it clean with no `~`.

## Fix (taken, by stage D of `doc/claude/drag_perf_batch/`; not the shape proposed above)

Built on `3b36f24a1` plus stage A's patch (`doc/claude/drag_perf_batch/receipts/D-fix.md`).
**Do not paste the proposal above**: neither of its items was taken.

- **A hold, not a per-pass edit.** `set_modify()` (`src/actions.c`) declares nothing for
  `mod` 1 or 3 while `xctx->modify_hold > 0`: no flag, no `modify_seq` bump, no
  `write_backup()`, no title or button change. The floater and annotation caches are still
  flushed. `move_objects()` (`src/move.c`) takes the hold for a live step (`commit_now`) and
  for a refusable END (`enf_snapped`), inside its commit block, and drops it at the
  accept/refuse verdict or at the block's end. So every pass is covered, not only
  `insert_exit_stubs()`: `trim_wires()`, `remove_move_orphan_wires()` and the fluid
  shove/reroute/offset passes also call `set_modify(1)` when they change something.
  `insert_exit_stubs()` keeps its unconditional call; under the hold it is harmless.
- **The refusal arm.** It now calls `set_modify(-1)` when the sheet was dirty before the
  gesture (it writes nothing, so the `~` keeps the user's edits byte for byte) and
  `set_modify(0)` when it was clean. `enf_mod_before` is read at END as before; it is the true
  pre-gesture flag now, because the live steps were held.
- **A completed drag is unchanged.** Its END runs the accept arm's own unheld
  `set_modify(1)`, so the final flag and the backup's content are those of stage A.
  Measured: the stage A identity sweeps (390 seam files, 80 GUI files) are byte-identical, and so
  are the 418 backups the two trees both wrote. The only listing difference is three `~` files
  stage A leaves and this fix does not, each beside a page whose drag changed nothing (a
  refused drag).
- **Fence:** `tests/headless/test_drag_abort_backup_1716.tcl`, registered in both T1 lists.
  Bands A (scripted seam: abort, `abort_operation`, dirty-before, plus controls), R (the
  refusal, one-shot and stepwise, clean and dirty) and E (the real Tk gesture with Escape,
  under `sky130A/cadence_style_rc`). Every fence row is red on stage A's tree, and each part of
  the fix has a broken-on-purpose build that turns rows red (the receipt has the table).
- **Open items 1 to 3 are closed.** Item 2's legs are rows A1 to A3 and E1 to E2 (with the
  `STARTMOVE` and movement non-vacuity legs). Item 3 is band R.

### Follow-up, stage D2: the orphaned gesture (`doc/claude/drag_perf_batch/receipts/D2-fix.md`)

Finding F1 of `receipts/D-verify.md`: the hold above made a live drag that ends with **neither an
END nor an ABORT** leave its moved shapes undeclared. `unselect_all()` (`src/select.c`) zeroes
`ui_state`, and the `u`, Shift-U and `n` keys, `xschem unselect_all|undo|redo|netlist` and the
area-select branch of the motion handler all reach it mid-drag. The shapes then stayed moved on
screen while the sheet read clean, with no `~` and no quit prompt. Before the hold, each live
step's own `set_modify(1)` had declared them, by accident.

- **Shape taken.** `fluid_reroute_orphan_check()` (`src/move.c`) runs as the OUTERMOST `xschem`
  command returns (`xschem()`, `src/scheduler.c`, by a nesting depth). If the gesture is still
  armed and dirty but `STARTMOVE` is gone, and the document is still the one the gesture started
  on (`xctx->fluid_reroute_level` and `fluid_reroute_sch`, recorded at START), it calls
  `set_modify(1)` once. A per-gesture latch, `fluid_reroute_settled`, is set before that call, by
  `load_schematic()` when it resets undo (a new document: a reload is the same level and file, so
  only this tells it apart), and by `save_schematic()` (the geometry is on disk).
- **Why not the shape D-verify proposed** (declare inside `unselect_all()`, hold the live step's
  restore). It was built and measured. Most callers unselect BEFORE they tear the buffer down, so
  it wrote a stray `bandgap~.sch` of the cancelled drag on `xschem clear` and `clear force`, `xschem
  load` and `load -gui` of another cell, `xschem reload` and `go_back`. It wrote the CHILD's geometry into `tb_bandgap~.sch` when the
  drag was below the top, because `clear_schematic()` and `ask_new_file()` reset `currsch` first.
  It wrote an EMPTY `~` inside `xschem undo 0 0` with history, where the `unselect_all()` runs
  after `clear_drawing()`. And with a display it crashed: SIGSEGV in `set_modify()` called from
  `unselect_all()` inside `descend_schematic()`, on any `xschem descend` mid-drag. On the four
  cases F1 named, the two shapes give the same flag, the same `~` and the same quit prompt, and a
  sweep of 58 keys pressed mid-drag on the display gives identical results for both.
- **Fence:** band O and row E4 of `tests/headless/test_drag_abort_backup_1716.tcl`. O0 is the
  per-step leg (nothing is declared while the gesture is live), O1 to O4 and E4 (the real `u` key)
  are the four orphaning verbs, O5 is the once-per-gesture latch, O6 the undo-with-history restore,
  O7 a save mid-drag, and O8 to O13 the verbs that replace the document (load, reload, clear,
  go_back, and the no-title forms `descend 1 0` and `go_back 2`, which load without an undo reset).
  Each guard of the shape has a copy broken on purpose that turns at least one of those rows red;
  the receipt has the table.
- **Changed from the base build, and not restored:** a scripted `xschem descend` in the middle of a
  live drag now discards the drag's geometry, as `go_back` then loads the parent from disk, clean.
  On the base build the live steps had declared it, so it came back modified. Stage D's tree
  already behaved this way; row O12b holds the parent to "declared or pristine".

## Follow-up: the save prompt during a live drag (G1, stage D3 of `doc/claude/drag_perf_batch/`)

- **The regression.** The fix above stops a live step from declaring the sheet, so the sheet reads
  clean while the drag is live. On the base build every live step had declared it, so a verb that
  leaves or discards the document asked about the moved shapes. With the fix they went ahead
  without asking and the shapes were lost: Ctrl-Q, Ctrl-W and Ctrl-E pressed with Button-1 still
  held, and anything during a keyboard `m` move (File > Close and Clear Schematic, Edit > Pop,
  Ctrl-N, Ctrl-O in place, the window manager's close button, Quit with another tab's drag left
  live, and descend followed by go_back). Finding G1 of `receipts/D2-verify.md`, measured on a
  key sweep of the three builds.
- **Shape taken.** `end_live_fluid_drag()` (`src/callback.c`) ends a live fluid drag the way its
  release would, through the release's own funnel (`end_move_copy_logged()`), so a refused END
  still declares nothing. It is called at the START of each such verb, before anything is torn
  down: `go_back()` when confirming, `clear_schematic()` when asking, `ask_new_file()` opening in
  place, `descend_schematic()` with a title, `descend_symbol()`, `xschem exit` without force,
  `destroy_window()`/`destroy_tab()` of the current window, `destroy_all_windows()`/
  `destroy_all_tabs()` for each other window, and `hierarchy_close` (quit and close, in Tcl)
  through the new `xschem end_live_drag`. Not in `unselect_all()`, for the reasons in the section
  above.
- **The answers.** Yes saves the shapes where the screen has them; No drops them with the level's
  other edits; Cancel leaves the gesture over, the shapes where they are, the sheet modified with
  its `~`, and the cell file untouched. ⚠ That differs from the base build, which kept the gesture
  live after Cancel; the release then ended it further along.
- **Fence:** bands L, V and K and row R7 of `tests/headless/test_drag_abort_backup_1716.tcl`. Band K
  drives the real keys and menu entries on the display arm; row K18 holds the action log (the
  move line and the verb's own line), and needs the log, so it prints `SKIP:` under `--nolog`.
  Each call site has a copy broken on purpose that turns at least one row red
  (`receipts/D3-fix.md`).
- **Left as stage D had them:** the scripted no-title forms (`descend 1 0`, `go_back 0|2`), which
  load without an undo reset, and the verbs that open into another window or tab and leave the
  current buffer alone (a routed `load -gui`, `load_new_window`, Alt-E). Issue **1718** records
  what the no-title forms still do with a live snapshot.

## Follow-up: Ctrl-S during a drag on a sheet that already has unsaved changes (2026-11-16)

Finding G2 of `doc/claude/drag_perf_batch/receipts/D3-verify.md`, present at the base and unchanged
by D and D3. Stage D stops a mid-drag save from writing half-dragged geometry only when the sheet
was clean before the drag: then the save is a no-op and the drag continues. If the sheet already
had an unsaved edit, Ctrl-S with Button-1 held (or a scripted `xschem save`) runs
`save_schematic()`, whose `unselect_all(1)` ends the gesture, and then writes what is on screen:
the half-dragged positions reach the cell file and Escape can no longer undo them. A fix would end
or refuse the live gesture at the start of the save the way `end_live_fluid_drag()` does for the
verbs above, and needs its own ruling on which (save the shapes where the screen has them, or
save the sheet as it was before the drag). Open.
