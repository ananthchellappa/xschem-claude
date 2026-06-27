# File diff snapshot — action registry (Phase 1 + Phase 2)

Build/source file changes introduced by the action-registry feature on branch
`feature/action-registry` (vs `master`). Documentation-only artifacts
(`doc/claude/suggestions/`, `doc/claude/code_analysis/`) are excluded by request. Line counts are
whole-file (`wc -l`): `old --> new` for modified files.

> Scope note: this branch also contains a *separate* refactor (utility-layer
> extraction: `util.c`, `util.h`, and the matching edits to `editprop.c`,
> `xschem.h`) and the pre-existing headless harness infra (`run.sh`,
> `harness.tcl`, `gold/`, `cases.txt`, `minrc`). Those are **not** part of this
> feature and are listed under "Out of scope" at the end.

## Built / installed product files

| File | What changed / why it's needed |
|---|---|
| `src/actions.csv` **(new, 161 lines)** | The declarative action table — the single source of truth for user actions (`id, type, menu, label, accel, command, submenu, hook, help`; 133 command rows). Needed so menus, the command palette, the keyboard bindings, and the cheat-sheet can all be *generated* from one place instead of hand-synced across three. The `accel` column is also the source of truth for the (Phase 2) generated key bindings. |
| `src/action_registry.tcl` **(new, 476 lines)** | All the generators and the data layer, in Tcl, with zero C changes: RFC4180 CSV loader (`load_action_table`); menu generator (`build_menu_from_table`); the fuzzy command palette (`command_palette`, reuses `fuzzy_subseq_score`); the accel→Tk-sequence translator (`accel_to_tk_sequence`) and binding installer (`bind_accelerators_from_table`, gated by `migrated_action_ids`); runtime remap (`remap_action_accel`); the generated cheat-sheet (`generate_keybindings_text` / `show_keybindings_help`); and procs promoted from inline menu scripts (`action_reload`, `action_component_browser`). Needed as the home for everything that reads the table. |
| `src/xschem.tcl` **(11763 --> 11716, −47; 21 ins / 68 del)** | Sources the registry and loads the table at startup; replaces ~68 lines of hand-written File-menu code with a single `build_menu_from_table` call; installs the palette binding **and** the generated accelerators in `set_bindings`; adds Help entries (Command palette, "Keybindings (from table)"). Helps by *shrinking* the monolith while *adding* features — menu/keys/help logic moves out of the 11.7k-line file into the data-driven registry, and the File menu is proven byte-identical to before. |
| `src/Makefile.in` **(116 --> 117, +1)** | Adds `action_registry.tcl` and `actions.csv` to `install_shares` so the two new runtime files are installed alongside the binary. Needed for `make install` to ship the feature. |

## Test files (ship with the feature; run headless, not compiled/installed)

| File | What it is / why it's needed |
|---|---|
| `tests/headless/dump_file_menu.tcl` **(new, 101 lines)** | Introspects the *generated* File menu (every entry's type/label/accelerator, incl. submenus) and compares it to the known-good pre-refactor structure. Proves the table-generated menu is byte-identical (28/28 entries) — the evidence behind "behavior-preserving". |
| `tests/headless/test_palette.tcl` **(new, 28 lines)** | Smoke for the command palette: the Ctrl+Shift+P binding is installed, `save` fuzzy-matches the Save actions, and the key event opens the dialog. |
| `tests/headless/test_accelerators.tcl` **(new, 80 lines)** | Proves each migrated key (undo/redo/zoom) carries the table command and, *by observation in the running GUI*, produces the same effect as the direct command (identical zoom ratio; wire removed/restored); and that un-migrated keys (`f`/`s`/`w`) have no specific binding so they still reach C. 12 assertions. |
| `tests/headless/test_remap.tcl` **(new, 40 lines)** | Proves shortcuts are genuinely data-driven: remap `view.zoom_in` from `Shift+Z` to `Ctrl+Shift+Z`, confirm the old key is released, the new key runs and zooms, then restore. 7 assertions. |
| `tests/headless/test_keybindings_help.tcl` **(new, 37 lines)** | Proves the generated cheat-sheet matches the table (exactly the migrated keys flagged `*`, a non-migrated key present-but-unstarred) and follows a runtime remap. 6 assertions. |

## Out of scope (on the branch, but a different feature/infra)

| File | Why excluded |
|---|---|
| `src/util.c`, `src/util.h` **(new)** | Part of the separate utility-layer extraction from `editprop.c`, not the action registry. |
| `src/editprop.c`, `src/xschem.h` **(modified)** | Modified by that same utility-layer refactor (and `Makefile.in`'s `util.c`/`util.h` lines), not by this feature. |
| `tests/headless/run.sh`, `harness.tcl`, `gold/*`, `cases.txt`, `minrc`, `README.md`, `.gitignore` **(new)** | The pre-existing hermetic engine harness, added earlier as test infrastructure; this feature *uses* it (6/6 green) but did not introduce it. |

---

**Feature footprint (built/installed + tests, excluding out-of-scope):**
2 new product files (637 lines), 2 modified product files (net −46 lines), 5 new
test files (286 lines). C engine: **0 lines changed.**
