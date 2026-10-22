# 1705 — ASE-L could not save a result under a name

**STAMP:** `v1 claim=fixed tree=6500f6d0c stamped=2026-10-21 fix=taken open=0 by=driver`

*Renumbered 1666 → 1705 on 2026-10-21: 1666 was first minted here, but the clone
`~/private/xschem-private` had already minted 1666 (2026-10-17) for an unrelated
issue. Commits made before the rename cite it as 1666.*

The user asked (2026-10-21): "We have the ability to load a past result? Do we
have the ability to save the current result as a certain meaningful name (like
ADE-L in Cadence does) so it can be loaded later? If not, please add this super
useful feature". That rules spec `doc/claude/specs/results_selection.md` §17 Q2
("is a run history wanted?"): yes.

## What was wrong

Loading existed (`Results > Select…`, `results::select`). Saving did not: every
run overwrites `<rundir>/<cell>_ase.raw` and its siblings in place, so the only
way to keep a result was to copy files by hand.

## The fix

Spec §20 of `doc/claude/specs/results_selection.md`. Runs still write where they
always wrote. `Results > Save…` copies the result in view into
`<results_dir>/<lib>/<cell>/<folder>/` with a `result.meta`; `Results > Select…`
lists saved results and selecting one presents the session's state with `rundir`
pointed at the saved folder (`ase::result_state`), so the readers follow without
learning a new argument; `Results > Delete…` removes saved results.

Fence: `tests/headless/test_ase_saved_results_1705.tcl`, registered in both T1
lists.

## Verify round (2026-10-21)

An end-to-end run on a real sky130 bench, a code read and a sabotage sweep
found these, all fixed and each fenced by a row that reddens with its defect
put back:

- Select with the waveform viewer open repainted nothing (Outputs, title,
  status and annotation stayed on the previous result): `results::persist`
  recorded the selection before `rsel_commit` read the old view. The dialog now
  reads the view first (SVR45b), and the viewer's own select doors repaint at
  idle through `ase::ui::result_view_sync` (SVR27e).
- The schematic's annotation kept the previous view's numbers, because the
  attached raw's freshness stamp answered "current" for a different file.
  `annot_ensure_loaded` now re-attaches when the attached database is this
  session's own other result, and a change of view forces it (SVR51, SVR51b).
- Delete's row map was wiped by Select refilling or closing (SVR47b);
  deleting the result in view did not repaint (SVR29b).
- A copy of a saved result whose run state was synthesised was stamped as the
  run's own (SVR31b); a netlist older than the deck (Run on an existing
  netlist) was skipped as stale (SVR12b); two co-simulation VCDs with one file
  name collapsed onto one copy (SVR13b); an interrupted overwrite could leave an
  `.old` the sweep would rename back over a later Delete (SVR18e).
- A saved result selected while a run was running hid that run when it
  finished: `run_finished` now returns the view to the live run (SVR27f).

Limits that stand are declared in the suite's header.
