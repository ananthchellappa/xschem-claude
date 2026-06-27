# Read-only-by-default descend + Make Editable / Make Read Only

Status: **implemented** (branch `fluid-editing`).
Related: `utils/cadence_nav.tcl`, `src/cadence_style_rc`, `actions.c`
(`descend_schematic`), `callback.c` (canvas `context_menu`), `doc/claude/specs/cadence_bindkey_plan.md`.

A Cadence-style browse workflow: descending into a sub-schematic opens it
**read-only** so you navigate the hierarchy without accidentally editing, and you
explicitly opt into editing when you mean to.

## 1. Descend opens read-only by default

A mirrored Tcl flag **`descend_readonly`** (default **0** — unchanged editable
descend). When **1**, `descend_schematic()` forces `xctx->readonly = 1` right after
the child loads (and refreshes the title marker). `cadence_style_rc` sets it to 1.

Only the descended level is affected: ascending (`go_back`) reloads the parent via
`load_schematic`, which resets `readonly` to the **parent's own** file writability —
so the top stays editable if it was. The flag is read in C via
`tclgetboolvar("descend_readonly")`; no C struct/mirror needed.

This covers **every** descend path (double-click, `Ctrl-X` / `cadence::descend_into_inst`,
the context menu, the `xschem descend` command) because they all funnel through
`descend_schematic()`.

## 2. Editing after a read-only descend — three ways

- **`Ctrl-2` → Make Editable** / **`Ctrl-Shift-2` → Make Read Only**
  (`cadence::make_editable` / `cadence::make_readonly`, bound in `cadence_style_rc`).
  Thin wrappers over `xschem set readonly 0|1` that also `log_action` (replayable)
  and `ciw_echo` feedback. A read-only view becomes editable even if its file is
  write-protected (in-memory edits; saving may still be blocked separately).
- **Right-click → "Descend schematic (edit)"** — a canvas `context_menu` item
  (retval 22) that descends and then forces the child editable
  (`descend_schematic(...)` then `xctx->readonly = 0`). Shown only when
  `descend_readonly` is on (in normal mode plain "Descend schematic" is already
  editable, so the extra item would be redundant). `cadence::descend_into_inst_edit`
  is the bindable equivalent.
- **View ▸ Toggle Read Only** — the pre-existing general toggle still works.

## Acceptance / tests

`tests/headless/test_descend_readonly.tcl` (true-headless `--nogui`, descend fixture):

- **DRO1** `descend_readonly=0` → descended child is editable (`readonly==0`).
- **DRO2** `descend_readonly=1` → descended child is read-only (`readonly==1`).
  (Discriminating; sabotage-verified: removing the C set turns it red.)
- **DRO3** `go_back` restores the parent's own editable mode (not the forced RO).
- **DRO4** forcing `set readonly 0` after a read-only descend makes it editable
  (the "Descend (edit)" override path).

`make_editable`/`make_readonly` toggle verified to flip `xschem get readonly` 1↔0.

**Not auto-tested (manual eyeball):** the right-click "Descend schematic (edit)"
menu item itself (a GUI popup); the `Ctrl-2`/`Ctrl-Shift-2` key delivery.

## Out of scope

- Per-hierarchy-level read-only memory (readonly is a single window-context field;
  the descend-forces / ascend-restores behavior above is sufficient for browsing).
- A persisted user preference for `descend_readonly` outside the rc.
