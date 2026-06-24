# HANDOFF v4 — xschem-claude PR Project
# Updated after Session 5

## WHAT IS DONE (all committed and pushed)

All bugs BUG-A through BUG-X3 are fixed.
All features 1-8 and D1-D3 are implemented.
Symbol keys &, #, ! migrated (Priority 2 done).
Menu dump test added (Priority 1 done).
PR description updated (Priority 4 done).

## WHAT STILL NEEDS MANUAL GUI VERIFICATION

Run this checklist on Nithin's machine before opening the PR:
  [ ] Ctrl+Shift+P → palette opens, no error dialog
  [ ] Type "trim" in palette → trim_wires appears
  [ ] Type "save" in palette → save action appears
  [ ] Press Enter in palette → action runs, no error
  [ ] File menu → all entries present
  [ ] Options menu → Color Postscript/SVG at top (NOT a layer name)
  [ ] Layers menu → colored layer list (dynamic)
  [ ] View / Properties / Tools / Symbol / Highlight / Simulation / Waves / Help
      → all show correct entries
  [ ] Press & → trim_wires runs
  [ ] Press # → check_unique_names 0 runs
  [ ] Press Ctrl+# → check_unique_names 1 runs
  [ ] Press ! → break_wires_at_pins 0 runs
  [ ] Press n → netlist generated
  [ ] Press Ctrl+N → schematic clears to empty
  [ ] Press u → undo
  [ ] Press Ctrl+U → does NOT undo
  [ ] Press Shift+Z → zoom in
  [ ] Press Ctrl+Z → zoom out
  [ ] Help → Keybindings (from table) → cheat-sheet window
  [ ] Hover over menu item → help text in status bar
  [ ] Remap shortcut via dialog → survives xschem restart
  [ ] Recent palette: open palette with empty query → recent actions shown first

## NEXT STEP: OPEN THE PR

Once manual checklist is all green:
  git push myfork main   (already done)
  Open PR: https://github.com/ananthchellappa/xschem-claude/compare/main...chennakeshavadasa:main

## REPO

  https://github.com/chennakeshavadasa/xschem-claude
