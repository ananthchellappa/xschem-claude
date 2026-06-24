# Action Registry Phase 2 Implementation

This PR completes Phase 2 of the Action Registry refactor, migrating hardcoded Tcl UI elements to a data-driven system backed by `actions.csv`.

## Summary of Changes
- **Bug Fixes**: Resolved all priority bugs A through J from the initial code review, including modifier-guarding issues and action typos.
- **Menu Migration**: Successfully migrated the remaining menus (`View`, `Properties`, `Layers`, `Tools`, `Symbol`, `Highlight`, `Simulation`, `Help`) to be generated dynamically from `actions.csv`.
- **Accelerator Migration (Batch 1-3)**: Migrated Tcl keybindings to the action registry.
  - Added support for symbol keys (`#`, `=`, `&`, `!`) by updating the keysym lookup table in `accel_to_tk_sequence`.
  - Keys requiring context (such as `f` for zoom full which is WAVES-guarded, `F` for flip while moving, and `Esc` for aborting an operation) have deliberately been left in C to avoid breaking contextual behaviors, per the refactor plan.
- **Status Bar Help**: Implemented a `<<MenuSelect>>` event hook (`handle_menu_hover`) to display descriptive help text from the registry in the status bar when hovering over any migrated menu item.
- **Test Coverage**: Added extensive headless test coverage (`test_accelerators.tcl` and `test_keybindings_help.tcl`) to ensure the generated bindings exactly mirror the behavior of the old C dispatch logic.

## Verification
- `tests/headless/run.sh` passes 100%.
- GUI headless tests `test_accelerators.tcl` and `test_keybindings_help.tcl` pass 100%.
- Verified `make -C src` builds with zero warnings.
