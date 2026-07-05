# Issue 0068 — un-migrated keyboard shortcuts (legacy C `switch`) are not logged

**Opened:** 2026-07-02
**Status:** OPEN — partially fixed 2026-07-02: the legacy clipboard/edit keys that
resolve to `cut`/`delete`/`undo`/`redo` now record because those cores self-log
(issue 0071 §4b), independent of key migration. Remaining un-migrated keys await
either core self-log of their subcommands or migration to the registry.
**Severity:** MED — common editing keys (clipboard, orient-in-place, property
edit) mutate state with no record because they are still handled by the legacy
`switch(key)` rather than the registry.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Affects:** `src/callback.c` legacy `handle_key_press` switch (~:4080+; cases at
:4193 `c`, :4240 `C`, :4514 `m`, :4708 `q`, :4742 `Q`, :4973/:5086 Ctrl-C/X/V,
:5252 Delete). `src/actions.csv` rows whose `accel` is absent from
`src/keybindings.csv`.
**Related:** [[action-logging]], [[action-registry]]; 0067 (raw Tcl binds —
sibling); spec Phase 3 "resume key migration"; umbrella 0071.

---

## 1. Symptom

Keys that have an `actions.csv` row but were never migrated into
`keybindings.csv` fall through to the legacy `switch(key)` in `handle_key_press`.
That path edits directly and never calls `log_action`, so the shortcut leaves no
action-log / CIW line — even though the same command from a migrated key would be
logged.

## 2. Root cause

Only chords present in the C binding table (mirrored by `keybindings.csv`) reach
`dispatch_input_action` and get logged. Un-migrated chords hit the legacy switch,
whose cases contain no `log_action` (verified at the cited lines), and the
subcommands themselves don't self-log.

## 3. Scope — genuinely unlogged keyboard edits

- **Clipboard:** Copy (Ctrl+C), Cut (Ctrl+X), Paste (Ctrl+V), Delete (Del).
- **Orient in place:** Alt-F / Alt-V / Alt-R (flip/flipv/rotate in place),
  Shift-F / Shift-V / Shift-R (flip/flipv/rotate selected).
- **Property:** Q (`edit_prop`), Shift+Q (`edit_vi_prop`), Shift+S
  (`change_elem_order`).
- **Net-label placement:** Ctrl+P / Ctrl+Shift+P (schematic in/out port), Alt+L /
  Alt+Shift+L (net-pin / wire label) — object is created immediately.
- **Symbol/tools:** A (`make_symbol`), Alt+U (`align`), `!` (`break_wires`), `&`
  (`join_trim_wires`).

NOT in scope (already captured): gesture-completing inserts (W/L/R/… → `xschem
wire/line/rect/arc …` self-log at drop in `actions.c`) and keyboard move/copy
drops (`callback.c:1616`) log via the gesture path regardless of migration.

## 4. Fix sketch

Resume the Phase-3 "key migration": add `keybindings.csv` rows for these chords
so they dispatch through the registry and log automatically (the `actions.csv`
`command`/`nolog` columns already exist). Alternatively, add guarded `log_action`
to the legacy switch cases — but migration is the intended direction and removes
the double-maintenance of the legacy switch.
