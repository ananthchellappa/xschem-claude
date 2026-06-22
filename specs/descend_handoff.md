# Descend-preserve work — session handoff / resume

## RESUME PROMPT (paste after /clear)

> Continue the descend autosave work on branch `fluid-editing`. The design PIVOTED
> from an in-memory snapshot to an editor-style `cellName~.sch` backing file — read
> the "DESIGN PIVOT" section of `specs/descend_hierarchy_in_memory.md` (plan) and
> this file first. Steps 1–6 (in-memory, now superseded) and B1–B6 (backing file)
> are DONE and committed; resume at **B9** (tabs / deep multi-level hierarchy / leak
> + edge audit; GUI eyeball with `src/xschem --script src/cadence_style_rc`). The
> in-memory machinery was removed in B4; B5 removed the descend save prompt (S2
> GREEN); B6 extended autosave to symbols and removed the descend_symbol prompt for
> NON-embedded symbols (SY1/SY2 GREEN) — embedded-symbol descent deliberately keeps
> the legacy save prompt (go_back's embedded path reloads parent from disk, not the ~
> backup, so dropping it would lose parent edits; pinned by Part C); B7 hides
> `*~.sch`/`*~.sym` from the file dialog, library browser, and dir scans (one
> is_backup_file predicate in xschem.tcl; listers hide, resolvers untouched); B8 adds
> the lifecycle: `load_backup_as()` (save.c, reused by go_back + `xschem load_backup`),
> discard-cleanup `remove_backup()` in clear_schematic, and `xschem_recover_backup`
> (xschem.tcl) wired into the interactive open (scheduler.c, gated `!force && has_x`).
> Build + run the suites after each step, commit per step, and EXTEND the living
> tutorial `code_analysis/descend_in_memory_tutorial.md` with each step's lesson(s).
>
> Backing-file model: a genuine edit (`set_modify(1)`) writes `cellName~.sch`/
> `~.sym` (`write_backup`, save.c; `backup_file_name` handles both exts); a real
> `save_schematic` removes it; `load_schematic` guards itself with
> `xctx->no_autosave`; `go_back` loads the `~` if present (identity restored to
> cellName); `descend_schematic` + non-embedded `descend_symbol` no longer prompt.
> autosave_backup flag (default 1). `*~.sch/.sym` gitignored. Tests: test_backup_file,
> test_autosave_hook, test_descend_preserve (S1+S2 GREEN), test_descend_symbol
> (Part A + SY1/SY2 + Part C GREEN), test_descend_efficiency, test_descend_fidelity.
> ⚠ regression harness: the `tests/` cases invoke a bare `xschem`, so run with
> `PATH=$REPO/src:$PATH XSCHEM_SHAREDIR=$REPO/src` or every case FATALs silently
> (results.log still reads "clean" — green-but-hollow). Also rebuild BEFORE running
> the regression (a `make` racing a running suite gives spurious FATALs from a
> half-written binary).

> ⚠ **Everything below this line describes the SUPERSEDED in-memory design**
> (Steps 1–6) and is kept only for history. The authoritative current state is the
> RESUME PROMPT above + the "DESIGN PIVOT" section of the spec. Backing-file
> commits: B1 `c408fe3`, B2 `a9ca3cf`, B3 `7a30ff8`, B4 `b4bbfa4` (removed the
> in-memory machinery), B5 `f9fda05` (removed descend save prompt → S2 green),
> B6 `6d9d8a3` (symbol autosave + descend_symbol no-prompt, embedded guard kept),
> B7 `1d1bf75` (hide `~` backups from cell listings), B8 `58e053a` (lifecycle +
> crash recovery: load_backup_as / discard-cleanup / xschem_recover_backup),
> B9-partial: `3306d76` (deep-close: `xschem exit` uses `hierarchy_modified()`),
> `e0e2b92` (same guard in the 4 xinit.c tab/window close paths — the tabbed GUI
> closes through those, not `xschem exit`), `6918906` (Cadence per-level walk-up +
> nicer `ask_save` + go_back "No" removes ~). Walk-up = `hierarchy_close {close|quit}`
> (xschem.tcl): ascend bottom→top, prompt each DIRTY level naming the cell
> (intermediate via go_back Save/No/Cancel; top via ask_save), then force teardown;
> Ctrl-W=`close_schematic_window`, Ctrl-Q=`quit_xschem` (force only if sole window).
> Logic tested headless (test_hier_walkup); DIALOG APPEARANCE + live GUI close are
> has_x-gated → NEED USER EYEBALL.
> Next: finish B9 (USER eyeball of the close/quit walk-up + dialog sizing; tabs
> interaction; leak audit `xschemtest -d 3`). Possible polish: multi-window quit
> only walks up the CURRENT window (others get a single hierarchy_modified prompt).

## (HISTORY — superseded) Where things stood with the in-memory design

Branch `fluid-editing`. Goal: descending into a sub-schematic must never prompt
to save and never lose unsaved parent edits; prompts only at window-close and
go_back. Mechanism: snapshot the parent into `hier_slot[]` (reusing the undo
serializer) on descend; restore from it on go_back.

### Committed
- `4dbed77` Part 1: load-time auto-trim no longer flags a fresh file modified.
- `4b03b7d` Step 1: RED acceptance test `tests/headless/test_descend_preserve.tcl`
  + fixture `tests/headless/fixtures/descend/` (parent→child).
- `2909f2e` Steps 2–3: extracted `mem_serialize_slot` / `mem_restore_slot`;
  `free_undo_*` generalized to `(Undo_slot *)`.
- `094eb49` Step 4: `hier_slot[CADMAXHIER]` + `hier_slot_valid/modified[]` store
  + `mem_init/free_hier_slot(s)`; freed in `free_xschem_data`.
- `d38074c` Step 5: descend snapshots parent (`mem_snapshot_hier`), go_back
  overlays it (`mem_restore_hier`) after the disk load_schematic. Flag
  `descend_keep_in_memory` (default 1). **S1 GREEN.**
- `12bae6d` Step 6: fidelity test `test_descend_fidelity.tcl` (+ richer fixture
  `descend_fid_parent.sch`). Found that net resolution (even `select`) bakes
  derived `lab=` into wire props; the snapshot captured it so a clean parent
  came back non-identical to disk. **Fix:** go_back overlays the snapshot ONLY
  when the parent had unsaved edits (`hier_slot_modified`); a clean parent uses
  the authoritative disk reload → byte-identical. Snapshot also moved before
  descend's `prepare_netlist_structs`.

### Acceptance test status
`env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_preserve.tcl`
- S1 (no data loss): **PASS**
- S2 (no prompt): **RED** — flips at Step 7 (remove descend save block).
Fidelity: `tests/headless/test_descend_fidelity.tcl` → ALL PASS.

### Suites (all green)
- `bash tests/headless/wireedit/run_wireedit.sh` → 18/18
- `cd tests && tclsh run_regression.tcl` → no FAIL/GOLD/FATAL
  (needs `XSCHEM_SHAREDIR=<repo>/src`)
- Rebuild: `cd src && make xschem`

## Key implementation facts
- Shared serializer: `mem_serialize_slot`/`mem_restore_slot` in
  `in_memory_undo.c`; hierarchy wrappers `mem_snapshot_hier(lvl)` /
  `mem_restore_hier(lvl)` (returns 1 if restored). Slots lazily allocated
  (`mem_init_hier_slot`), freed per-level on go_back + all on teardown.
- descend snapshots at the PARENT level index (before `currsch++`),
  `actions.c` ~2672. go_back overlays after `currsch--` + load_schematic,
  `actions.c` ~2773.
- go_back **overlay** approach: keep disk `load_schematic` (file identity/title/
  netlist-dir bookkeeping), then `mem_restore_hier` swaps in preserved geometry
  ONLY when `hier_slot_modified[currsch]` is set (parent had unsaved edits);
  otherwise free the slot and keep the clean disk reload. Confines net-name
  baking to already-dirty parents and keeps clean parents byte-identical.
- Embedded-symbol returns (`.xschem_embedded_`) deliberately still use the disk
  path; go_back just frees the slot. That's Step 8.

## Remaining steps (RED-first)
- **Step 6**: validate restore fidelity — extend S1 to assert zoom, netlist
  output, and hilight survive go_back vs a disk-reload baseline. Decide whether
  to drop the now-redundant disk read in the overlay.
- **Step 7**: add S2 RED assertion already present; remove the
  `if(xctx->modified) save(1,0)` block in `descend_schematic` (`actions.c` ~2562).
  → S2 GREEN. (Keep go_back + close prompts.)
- **Step 8**: embedded symbols — snapshot already deep-copies `sym[]`; make
  go_back restore embedded edits from memory and drop redundant temp-reload.
- **Step 9**: tab interaction — `hier_slot[]` rides per-tab ctx; audit
  `switch_tab`; new `test_descend_tab`.
- **Step 10**: deep multi-level descend + free hier_slots on jump-to-top /
  clear_schematic / new-file (currently only go_back + teardown free them →
  potential leak on direct currsch reset); leak check `xschemtest -d 3`.
- **Step 11**: GUI eyeball with `src/xschem --script src/cadence_style_rc`.

## Known gaps / watch-items
- Direct `currsch` resets (jump to top, clear_schematic, load new top file) do
  NOT yet free intermediate hier_slots → leak until teardown. Fix in Step 10.
- Overlay does a disk read then discards its geometry — wasteful but correct.
