# 1716 — an Escape-aborted fluid drag leaves the sheet modified and writes its mid-drag geometry to `cell~.sch`, because `insert_exit_stubs()` calls `set_modify(1)` on every live reroute step

**STAMP:** `v1 claim=open tree=31dd76b6c stamped=2026-11-15 fix=untried open=3 by=selection_look-docs`

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
