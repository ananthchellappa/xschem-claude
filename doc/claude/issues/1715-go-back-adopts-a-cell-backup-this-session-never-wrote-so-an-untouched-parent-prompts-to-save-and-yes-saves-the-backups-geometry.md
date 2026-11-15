# 1715 — `go_back` adopts a `cell~.sch` this session never wrote, so an untouched parent prompts "has unsaved changes" and Yes saves the backup's geometry into the cell

**STAMP:** `v1 claim=open tree=31dd76b6c stamped=2026-11-15 fix=untried open=2 by=selection_look-docs`

Found by the selection-look batch's realistic-timing crew
(`doc/claude/selection_look_batch/receipts/realistic-timing.md`, the paragraph "A base defect
seen on the way (both trees)"). It was re-measured while filing, on the base build `~/gsl0` (a
clone of `e3c43487e` whose `src/` is identical to HEAD for every function cited here), on a
private Xvfb, with a throwaway HOME and a scratch copy of `sky130A`. **The batch did not cause
it.** Filed, not fixed.

The bundled `sky130A/xschem_libs/sky130_tests_ase` hierarchy is the fixture: `tb_bandgap` →
`bandgap` (instance `x1`) → `bandgap_opamp` (instance `x1`). All three are tracked in the repo.

## What the crew saw (observation, not re-derived)

- With `sky130A/cadence_style_rc` sourced, the crew descended `tb_bandgap` → `bandgap` →
  `bandgap_opamp` with net `VCC` highlighted and went back up twice. In round 1 of its
  `h1_tbbg_vcc_none` poses, on both the base and the batch build, the first `go_back` raised
  *"Schematic "bandgap" has unsaved changes"* (`asks=1`). Nothing had been edited. Later
  rounds did not prompt.
- A diagnostic run prompted on base and not on the batch tree.
- The crew linked it to the `VCC` highlight. **That link does not hold** (see below).

## Measured while filing

Each run used the crew's own walk (descend `x1` twice, `go_back` twice), with `ask_save`
overridden to answer "no" and count:

| run | `bandgap~.sch` beside `bandgap.sch` before | highlight | first `go_back` | prompt | backup afterwards |
|---|---|---|---|---|---|
| A | yes (planted) | `VCC` | `modified=1`, `p2` at (110,-117) | **yes** | gone |
| B | no (A's run removed it) | `VCC` | `modified=0`, `p2` at (40,-167) | no | absent |
| C | yes (planted) | **none** | `modified=1`, `p2` at (110,-117) | **yes** | gone |
| D | no | `VCC` | `modified=0`, `p2` at (40,-167) | no | absent |

- **A clean cell directory never prompts.** The crew's own diagnostic walk, re-run three
  times against a clean copy, gave `modified=0` at every step.
- **The highlight is irrelevant.** Run C prompts with no highlight at all. The trigger is a
  `bandgap~.sch` beside `bandgap.sch`. The crew's `VCC` correlation came from run order: the
  backup was there for round 1 and gone after it.
- **The planted backup was the one 1716 leaves.** It came from an Escape-aborted drag of
  three objects on `bandgap.sch` (see **1716**): the title block `l1` and the pins `p2` and
  `p4`, all displaced by (+70,+50), plus two extra wire segments (50 `N` records against 48).
- **On the way down the sheet shows the disk version; on the way up it shows the backup's.**
  After `descend`, `p2` is at (40,-167). After `go_back`, it is at (110,-117).
- **Answering Yes writes the backup's geometry into the cell.** With `ask_save` answering
  "yes" (scratch copy, restored afterwards), `bandgap.sch` was saved with `p2`, `p4` and `l1`
  at their displaced positions. Those are geometry from a drag the user cancelled.
- **Answering No deletes the backup.** It was gone after the prompt in runs A and C.

That the crew's backup had this origin is an **inference, not a measurement**. By file
times, the crew's Escape-aborted page-drag poses on `bandgap.sch` ran earlier than its
`tb_bandgap` walks, in the same per-tree work directories, and 1716's mechanism leaves exactly
such a file. Those directories have since been deleted, so their contents cannot be checked.
The base-versus-batch difference in the diagnostic would be explained by which work directory
still held a leftover when it ran. That is plausible and was not established.

## Cause (confirmed by reading code, and consistent with every measurement above)

- **`go_back` (`src/actions.c`)** reloads the parent with
  `if(from_embedded_sym || !load_backup_as(filename, set_title)) load_schematic(...)`.
  The descend-in-memory spec's **B3** is the reason
  (`doc/claude/specs/descend_hierarchy_in_memory.md`): the parent's unsaved edits live in its
  `cellName~.sch`, so ascending loads them back.
- **`load_backup_as` (`src/save.c`)** checks only that `autosave_backup` is on and that the
  `~` exists (`stat`). It does not ask whether this session wrote it (`xctx->backup_owned`,
  issue 1486). It does not compare its age with the cell's. It does not ask the user. It loads
  the `~` as content, restores the buffer's identity to the cell, and ends in `set_modify(1)`.
- **That `set_modify(1)` makes the file look like this session's.** It calls `write_backup()`,
  which rewrites the `~` and records its path in `xctx->backup_owned`. The parent is now
  `modified=1`.
- **The prompt follows.** The next `go_back` from `bandgap` finds `xctx->modified` set and
  raises `ask_save`. "yes" runs `save_schematic` on the backup's content. "no" runs
  `remove_backup_if_owned()`, which deletes the file, because the previous step made it
  "owned".

**The open path already treats the same file differently.** On an interactive open,
`xschem_recover_backup` (`src/xschem.tcl`, B8) silently drops a `~` that is older than or the
same age as the cell, and asks *"Recover unsaved changes?"* before restoring a newer one
(rows `R3a`/`R3c` of `tests/headless/test_backup_recovery.tcl`). `go_back` does neither. By
reading, it would also load an **older** `~` as content; only the newer case was measured.

**It also defeats issue 1486's guarantee.** `write_backup()`'s own comment says *"A '~' we
never wrote is a previous session's crash recovery and is not ours to delete"*. Here
`load_backup_as` adopts such a file and the "No" arm deletes it. Measured: the file was gone
after "No". If that file was a real crash's recovery of real edits, a user who answers "No" to
a prompt they did not expect loses it. That consequence is reasoned from the code, not
measured.

**The user-visible result:**

- An untouched sheet shows `*` and prompts on the way up.
- The sheet the user sees changes between descending and ascending.
- Answering Yes saves stale or cancelled geometry into the design file with no indication
  where it came from.

## Whose defect it is

It is the fork's, not upstream's. At `f276d0cf2` (upstream xschem, the fork base)
`load_backup_as`, `write_backup` and `autosave_backup` occur zero times in `src/`. Upstream
writes no `cell~.sch`.

- `c408fe3ec` (2026-06-21, "feat(autosave): B1 backup-file helpers (cellName~.sch)")
  introduced the backup file.
- `58e053a94` (2026-06-21, "feat(descend): B8 lifecycle + crash recovery for the ~ backing
  file") introduced `load_backup_as` and its call in `go_back`.

Neither commit is an ancestor of `f276d0cf2`. Both are ancestors of HEAD.

## Related

- **0495** found the same mechanism from another caller: *"`go_back` dirties the parent only
  when a `<cell>~.sch` exists beside it"*. It was fixed **at the caller**, for the
  OP-annotation walk only, by parking `::autosave_backup` (`op_annot::_park_backup`). The
  interactive `go_back` was left as it was, and nothing asked whose `~` it was. This issue is
  that remaining path. It is filed separately rather than as an addendum because 0495 is
  scoped to and closed for the walk.
- **0632**: the same walk's dirty-path variant.
- **1486**: backup ownership (`backup_owned`), which this path bypasses.
- **1716**: one way a foreign `~` comes to exist. Any crash, kill or scripted exit with a
  modified sheet leaves one too.

## Proposed fix (NOT built)

In `go_back`, load a `~` as the parent's unsaved edits only if it is one this session wrote.
Compare its path with `xctx->backup_owned`, or better, record ownership per hierarchy level
at descend time. `backup_owned` is one slot and is overwritten by the child's own backup.

A `~` this session did not write belongs to B8's open-path logic, not to B3:

- drop it if it is older than the cell, as `xschem_recover_backup` does;
- otherwise ask before restoring it, or load the disk version and leave the `~` alone.

What the user is offered for a newer foreign `~` on the way up is a user-visible choice.
Leaving it on disk untouched is the conservative default, because it changes nothing a user
sees today except that the spurious prompt disappears.

## Open items

1. The fix above.
2. A fence row. Plant a `bandgap~.sch` this session did not write, walk
   `tb_bandgap` → `bandgap` → `bandgap_opamp` → back up, and assert three things:
   `xschem get modified` stays 0, no `ask_save` fires, and the planted file is
   **byte-identical** afterwards (not deleted, not rewritten). A control leg should show that
   a backup this session did write, from an edit on `bandgap` before descending, is still
   restored and still prompts.
