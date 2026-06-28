# Refactor plan: an action registry to enable UI/UX enhancements

## Starting question

> "What we currently care about most is ease of use. The tool has very poor UX.
> Where is the biggest bang for buck in terms of refactoring to *enable*
> enhancements to UI/UX?"

The goal is not a single feature — it's removing the structural friction that
makes *every* UX improvement expensive. So we look for the common substrate under
discoverability, shortcuts, menus, toolbars, and context menus.

## Findings (grounded in the code)

Everything that makes xschem's UX poor traces to one root: **user actions are not
first-class data.** They are scattered across three hand-synced places:

- **221 menu items** in `build_widgets` (`xschem.tcl`, ~700 lines) whose
  `-accelerator` labels are *decorative only*;
- the **1596-line `handle_key_press`** C keysym chain in `callback.c`, where the
  key → action mapping is hardcoded as `if/else` control flow;
- **`keys.help`**, a prose copy of the bindings that drifts out of sync.

Three measurements make the fix unusually cheap for what it unblocks:

| Finding | Source | Why it matters |
|---|---|---|
| Menu items already carry `{label, accel, command}` | `doc/claude/code_analysis/menu_inventory/` (242 items extracted; 221 real actions) | seed data for the table already exists |
| 65 keysym branches are just `tcleval("<command>")` | `grep tcleval` in `handle_key_press` | the actions are *already command strings* — they move into the table nearly verbatim |
| A general-purpose fuzzy matcher already exists | `fuzzy_subseq_score` in `xschem.tcl` (used by the file chooser) | a command palette is cheap — reuse, don't build |

Risk context (from `doc/claude/code_analysis/callgraph/` risk map): this work lives on the
**safe seam** — Tcl plus the `xschem`-command dispatcher boundary — *not* the
`xctx` / `token.c` / editing-core. UX work almost never needs the C engine, and
the headless harness (`tests/headless/`) covers the engine paths regardless.

## The move: one declarative action registry

Extract a single source of truth — an **action table** — and route menus,
keybindings, and help through it instead of hand-maintaining each.

Proposed schema (one row per user action):

    { id  label  menu  accelerator  command  help  enable_when }

- `id`        stable key (e.g. `edit.copy`)
- `label`     menu/palette text ("Copy")
- `menu`      where it appears (`edit`, or empty for palette-only)
- `accelerator` display + the binding source of truth (e.g. `Ctrl+C`)
- `command`   the Tcl/`xschem` command string to run (already how things work)
- `help`      one-line description (feeds palette + generated cheat-sheet)
- `enable_when` optional predicate for greying-out (later)

Generators read the table to produce: the menus (replacing the 221 hand-written
`add command` calls), the accelerator bindings, the "Show Keybindings" list, and
the command palette.

### What it unblocks (the UX payoff)
- **Command palette** (e.g. `Ctrl+Shift+P`): fuzzy-type an action name → run it.
  THE fix for xschem's #1 UX problem — discoverability — built on the existing
  `fuzzy_subseq_score`. Highest visible win.
- **Customizable + discoverable shortcuts**: shortcuts become data → remappable,
  with an always-accurate, generated cheat-sheet (kills the `keys.help` drift).
- **Consistent menus, tooltips, context menus, a toolbar**: all read one table.

## Plan (risk-sequenced)

**Phase 1 — pure Tcl, zero C changes, biggest payoff first**
1. Define the action table; seed it from `doc/claude/code_analysis/menu_inventory/menu_items.csv`
   (add `id` + `help` columns). For the 43 inline-script commands, extract each
   into a named proc first so every `command` field is a clean call.
2. Write generators: `build_menu_from_table`, `bind_accelerators_from_table`,
   `generate_keybindings_help`.
3. Convert ONE menu (File) to generate from the table — prove the pattern.
4. Add the **command palette** (fuzzy search over the table) reusing
   `fuzzy_subseq_score`.
5. `handle_key_press` (C) stays untouched and keeps working.
6. Verify: headless harness green (engine unchanged) + manual smoke of File menu
   and palette.

**Phase 2 — incremental, opt-in**
- Migrate the 65 `tcleval("...")` key branches onto the table (each is already a
  command string) → enables user-remappable shortcuts. Do it in batches;
  harness + smoke per batch.
- The gnarly non-`tcleval` branches (live drag/move state, modal operations) stay
  in C for now.

**Phase 3 — compounding wins (cheap once the table exists)**
- Toolbar, context menus, tooltips, recently-used, enable/disable state — all
  read the same table.

## What is NOT the best bang for buck (avoid)
- Splitting the `xschem.tcl` monolith / `build_widgets` — cosmetic; unblocks
  nothing.
- Rewriting individual dialogs one-by-one — one-offs that don't compound.
- Touching the C engine (`xctx`, `draw`, `token`) — high risk, and UX rarely
  needs it.

## Verification loop (same as the util extraction)
plan → small change → build → `tests/headless/run.sh` (engine unchanged) →
manual UI smoke → commit. Phase 1 is additive and reversible: the table can
coexist with hand-written items, migrate menu-by-menu.

## Status / next step

**Phase 1 — DONE** (branch `feature/action-registry`, UI/Tcl only, C engine untouched):
- `src/actions.csv` — the action table (134 rows: id, type, menu, label, accel,
  command, submenu, hook, help), seeded from the menu inventory.
- `src/action_registry.tcl` — CSV loader, `build_menu_from_table`, the command
  palette (Ctrl+Shift+P, reuses `fuzzy_subseq_score`), and two procs
  (`action_component_browser`, `action_reload`) promoted from inline menu scripts.
- `src/xschem.tcl` — File menu generated from the table; one palette binding in
  `set_bindings`; a "Command palette" entry in the Help menu.
- `doc/claude/code_analysis/menu_inventory/gen_actions.tcl` — idempotent generator for the
  106 imported palette rows.
- Verified: headless harness 6/6 PASS (engine unchanged); File menu byte-identical
  (28/28 entries); palette = 131 commands.

Deferred to Phase 2: the 22 inline-script commands (need named-proc extraction)
and the 46 checkbutton / 15 radiobutton toggles (need a `toggle` row type), then
migrate the `tcleval(...)` key branches onto the table for remappable shortcuts.

**Phase 2 — IN PROGRESS** (branch `feature/action-registry`, still UI/Tcl only,
callback.c untouched — keys are intercepted *above* C via Tk binding specificity):
- `accel_to_tk_sequence` (action_registry.tcl): translates an accel display
  string to a real Tk event pattern ("Ctrl+S"→`<Control-Key-s>`, "Shift+Z"→
  `<Shift-Key-Z>`, "Alt-F"→`<Alt-Key-f>`, "U"→`<Key-u>`). The keysym, not the
  display casing, decides: a bare letter → lowercase keysym (C `case 'u'`), a
  Shift'd letter → uppercase keysym (C `case 'U'`). Returns {} for non-shortcuts
  (mouse buttons, "Print Scrn", comma alternatives, symbol keys, unknown mods).
- `bind_accelerators_from_table` + `run_action`: install bindings on the drawing
  widget in `set_bindings`, gated by an explicit `migrated_action_ids` allowlist;
  re-runnable (releases prior bindings first). `remap_action_accel` changes one
  row's accel at runtime and re-installs — the core a "customize shortcuts"
  dialog would call.
- `generate_keybindings_text` / `show_keybindings_help`: cheat-sheet generated
  from the table (Help → "Keybindings (from table)"), always accurate; supersedes
  the hand-maintained keys.help. Migrated keys flagged `*`.
- Classification of `handle_key_press`: keys that are waves-guarded (route to
  graph on mouse-over), infix/modal placement or move-start, or depend on
  in-progress edit state STAY in C; only clean global command keys migrate.
- **Batch 1 (done & verified):** `edit.undo` (u), `edit.redo` (Shift+U),
  `view.zoom_in` (Shift+Z), `view.zoom_out` (Ctrl+Z). Each binding empirically
  runs the same action as the C branch (identical zoom ratio; wire removed/
  restored), un-migrated keys still reach C. Tests:
  `tests/headless/test_accelerators.tcl` (12/12), `test_remap.tcl` (7/7),
  `test_keybindings_help.tcl` (6/6); engine harness still 6/6.
- Next batches: grow `migrated_action_ids` with more clean command keys (e.g.
  `S` change-elem-order, `n`/Ctrl+n/Ctrl+N netlist & clear, `T` toggle-ignore,
  hilight `j/J/k/K` family, `x` new-process); add symbol-key keysym mapping
  (`# = * & !`) when those rows are migrated.
