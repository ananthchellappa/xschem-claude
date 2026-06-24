# Action Registry: Phase 2 Refactor — PR Description

## Summary

This PR completes Phase 2 of the Action Registry refactor for xschem.
The goal is a single declarative table (`src/actions.csv`) that is the
**source of truth** for all user-visible actions: menus, command palette,
keyboard shortcuts, tooltips, and cheat-sheet. The C engine (`callback.c`
and friends) is completely untouched — only Tcl/CSV files change.

Phase 1 seeded the File menu. Phase 2 migrates the remaining menus,
adds data-driven keyboard shortcuts with full modifier safety, and adds
four high-value UX features: command palette, status bar help, persisted
remaps, and recently-used commands in the palette.

---

## Bug Fixes

### BUG-A: Plain-key bindings stole ALL modifier variants from C
**Root cause:** `bind_accelerators_from_table` installed `run_action ...; break`
unconditionally on plain keys (e.g. `<Key-u>`), so pressing Ctrl+U, Alt+U,
Alt+key etc. would fire the Tcl binding and never reach C's `handle_key_press`
which handles the modifier variants (Ctrl+U = unselect floaters, Alt+U =
align-to-grid).

**Fix:** For any binding whose Tk sequence has no modifier prefix
(`<Control->` / `<Alt->`), the binding body is now wrapped in:
```tcl
if {[action_key_unmodified %s]} {run_action ...; break}
```
`action_key_unmodified` returns true only when no real modifier is held
(NumLock/CapsLock are ignored as they are lock keys, not intentional
modifiers). Modifier-specific bindings (e.g. `<Control-Key-z>`) are
already exclusive and bind unconditionally — no guard needed.

**Renamed:** `should_handle_unmodified` → `action_key_unmodified` (clearer name).

### BUG-A (related): Escape was incorrectly migrated
`view.redraw` (accel: Esc) was in `migrated_action_ids`. But `XK_Escape` in
C calls `abort_operation()` + `tclstop` + `MENUSTARTWIRE` cleanup — far more
than `xschem redraw`. Migrating it would have stolen Escape from every
in-progress operation (wire draw, move, etc.).

**Fix:** Removed `view.redraw` from `migrated_action_ids`. Added a comment
explaining why. Added a test case verifying `<Key-Escape>` has no Tk binding.

### BUG-B: Regression harness regex patterns (verified correct)
The `run.sh` patterns (`FAIL$`, `^FATAL`, `Tcl_AppInit() err`) were
audited and confirmed correct. Added `test_regression_parser.tcl` with
16 positive/negative test cases that can be run standalone with `tclsh`.

### BUG-C and BUG-D: Missing semicolons in commands (verified fixed)
- `simulation.set_netlist_dir`: `set local_netlist_dir 0; set_netlist_dir 1` ✓
- `view.show.visible_layers`: `select_layers; xschem redraw` ✓

### BUG-F: Dynamic submenu uses -postcommand (verified correct)
`build_menu_from_table` creates dynamic submenus with
`-postcommand [list $hook $topwin]` so the populate hook fires every time
the menu opens, not once at startup.

### BUG-H: remap_action_accel rebinds all windows (verified correct)
`remap_action_accel` iterates `array names accel_bound_seqs` so every
registered drawing widget (tab) gets the new binding.

### BUG-L: CRLF guard in CSV parser
`action_parse_csv_line` had no `\r` guard on the last field. If called
directly with a CRLF line (not via `load_action_table`), the last dict
value would carry a trailing `\r`. Added `lreplace/trimright` at the end
of the function.

### BUG-M: fuzzy_subseq_score fallback for standalone testing
`palette_refilter` uses `fuzzy_subseq_score` from `xschem.tcl`. When
`action_registry.tcl` is sourced standalone (testing), the call would
crash. Added an `if {![info commands ...]}` guard that installs a simple
substring-match fallback.

---

## New Features

### Phase 2: All remaining menus migrated to actions.csv
View, Properties, Options, Edit, Tools, Symbol, Highlight, Simulation,
Help menus are now generated from `actions.csv` by `build_menu_from_table`.
The Layers menu is intentionally excluded — it is dynamically generated
by `reconfigure_layers_menu` based on PDK-defined cadlayers.

### Phase 2 Batch 1–3: Data-driven keyboard accelerators
Keyboard shortcuts are now generated from the `accel` column in `actions.csv`
via `bind_accelerators_from_table`. Each binding pre-empts the generic
`<KeyPress>` → C path only for its specific key; C handles everything else.

**Migrated (with modifier guard):** U (undo), N (netlist), Shift+T (toggle
ignore), Shift+S (change order), X (new process), J (print hilight nets),
K (hilight net), Shift+K (clear hilights), # (check unique), = (tcl cmd),
& (trim wires), ! (break wires), Ctrl+# (check unique w/rename), Ctrl+!
(break at pins with param).

**Not migrated (must stay in C):** f (waves_selected guard), F (ui_state
guard for modal flip), Esc (abort_operation, not just redraw), Shift+U
(redo — already has Shift modifier, safe), Ctrl+Z (zoom out — already has
modifier, safe).

### Status Bar Help Text (D3)
`handle_menu_hover` is bound to `<<MenuSelect>>` on every generated menu.
On hover, it looks up the `help` column for the active entry and shows it
in `.statusbar.1`. Clears on mouse-out or separator hover.

### Persist Keyboard Shortcut Remaps (D1)
- `save_accel_overrides()` writes `$USER_CONF_DIR/accel_overrides.tcl`
  with only entries that differ from the CSV original (`orig_accel` field).
- `load_accel_overrides()` re-sources that file on startup.
- Called from `quit_xschem` (save) and `set_bindings .drw` (load).

### Recently Used Commands in Palette (D2)
- `record_recent_action` maintains a capped list of 8 most-recently-used
  action IDs (de-duplicated, most recent first).
- When the palette opens with an empty query, recent actions appear at the
  top with an `--- All commands ---` separator.
- Persisted to `$USER_CONF_DIR/recent_actions.tcl`.

---

## Testing

| Test File | What it proves | How to run |
|---|---|---|
| `tests/headless/run.sh` | All netlisting golden baselines pass | `./run.sh` (no X) |
| `tests/headless/test_accelerators.tcl` | Bindings installed, modifier guard present, Esc/f/F unmigrated | X required |
| `tests/headless/test_regression_parser.tcl` | run.sh regex patterns match/reject correctly | `tclsh ...` |
| `tests/headless/test_accel_persist.tcl` | save/load accel overrides cycle | `--no_x` |
| `tests/headless/test_keybindings_help.tcl` | Cheat-sheet generator output | X required |
| `tools/audit_csv_commands.py` | Zero $topwin/$selectcolor/missing-semicolon issues | `python3 ...` |

---

## What Was NOT Changed

The following C source files are completely untouched (verified with
`git diff origin/main -- src/*.c src/*.h`):
- `src/callback.c` — the C keysym dispatcher is the unchanged source of truth
- `src/xinit.c`, `src/xschem.h`, `src/xschem.c`
- All other C, header, Bison, and Flex files

The Tcl C key dispatch (`handle_key_press` → `callback()`) is still the
authority for every un-migrated key. Migrated keys are pre-empted only by
a more-specific Tk binding with a modifier guard.

---

## How To Verify

```sh
# 1. C files untouched (must show zero output):
git diff origin/main -- src/*.c src/*.h

# 2. Build zero warnings:
make -C src 2>&1 | grep -E "warning|error"

# 3. Headless regression:
tests/headless/run.sh   # must show == HARNESS: PASS ==

# 4. Standalone Tcl tests (no X needed):
tclsh tests/headless/test_regression_parser.tcl
./src/xschem --no_x --rcfile tests/headless/minrc --pipe -q \
             --script tests/headless/test_accel_persist.tcl

# 5. CSV integrity:
python3 tools/audit_csv_commands.py  # must show Total issues: 0

# 6. Under X: verify modifier guard (must show RESULT: ALL PASS):
DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_accelerators.tcl
```

---

## Recommended Next Steps (after merge)

1. **Batch 4 migration:** Safely migrate `e` (edit props), `m` (move),
   `c` (copy) once their modifier guards are audited in callback.c.
2. **Customize shortcuts dialog:** UI is scaffolded; wire to `remap_action_accel`.
3. **enable_when column:** Add context-sensitive greying (e.g., Save only
   active when schematic is modified).
4. **Cheat-sheet window:** `show_keybindings_help` is already implemented;
   add a Help menu entry.

Produces zero output. This PR is 100% Tcl and CSV.

## Files Changed

- `src/action_registry.tcl` — new (all registry/palette/keybind logic)
- `src/actions.csv` — new (135+ action definitions)
- `src/xschem.tcl` — modified (sources registry, calls generators)
- `tests/headless/run.sh` — modified (now runs netlist tests)
- `tests/headless/cases.txt` — 3 PDK test schematics
- `tests/headless/gold/*.spice` — 9 golden netlist baselines
- `tests/headless/test_menu_widgets.tcl` — new menu validation test
- `.github/workflows/ci.yaml` — modified (CI runs headless tests)
- `tools/audit_csv_commands.py` — new (CSV vs xschem.tcl cross-reference)
