# HANDOFF v5 — xschem-claude PR Project
# Updated after Session 8 — READY TO OPEN PR

## STATUS: READY FOR PR

All bugs BUG-A through BUG-X3 are verified fixed.
All features implemented and headless-verified.
Harness: PASS (9/9) with real SPICE comparisons.
C diff: 0 lines vs origin/main.

## VERIFIED IN SESSION 8

1. build_menu_from_table defensive check: correct Tcl syntax
2. Harness counts real SPICE tests (not state.txt)
3. Symbol keys & # ! → correct xschem commands verified
4. BUG-X3: <Key-n> has modifier guard, <Control-Key-n> empty (Mode B verified)
5. All 11 menus exist and non-empty (Mode B verified)
6. Clean launch: no Tcl errors on startup

## TO OPEN THE PR

  https://github.com/ananthchellappa/xschem-claude/compare/main...chennakeshavadasa:xschem-claude:main

  PR title: "Data-driven action registry: CSV-driven menus, keybindings, and command palette"
  PR description: see pr_description.md

## MANUAL GUI CHECKLIST (run before merging)

  [ ] Ctrl+Shift+P → palette opens, no error dialog
  [ ] Type "save" in palette → save action appears, Enter runs it
  [ ] Options menu → first entry is NOT a layer (should be Color Postscript or similar)
  [ ] Layers menu → colored layer list (dynamic, built by create_layers_menu)
  [ ] All other menus show correct entries
  [ ] Press n → netlist runs (check status bar)
  [ ] Press Ctrl+N → schematic clears to empty
  [ ] Press u → undo
  [ ] Press Ctrl+U → does NOT undo (unselects floaters)
  [ ] Press & → trim_wires runs
  [ ] Press # → check_unique_names 0 runs
  [ ] Press ! → break_wires_at_pins 0 runs
  [ ] Hover over menu item → help text in status bar
  [ ] Help → Keybindings (from table) → cheat-sheet window opens
  [ ] Remap a shortcut in dialog → survives xschem restart

## REPO

  https://github.com/chennakeshavadasa/xschem-claude
  Branch: main
