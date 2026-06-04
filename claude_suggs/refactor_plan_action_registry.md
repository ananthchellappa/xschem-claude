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
| Menu items already carry `{label, accel, command}` | `code_analysis/menu_inventory/` (242 items extracted; 221 real actions) | seed data for the table already exists |
| 65 keysym branches are just `tcleval("<command>")` | `grep tcleval` in `handle_key_press` | the actions are *already command strings* — they move into the table nearly verbatim |
| A general-purpose fuzzy matcher already exists | `fuzzy_subseq_score` in `xschem.tcl` (used by the file chooser) | a command palette is cheap — reuse, don't build |

Risk context (from `code_analysis/callgraph/` risk map): this work lives on the
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
1. Define the action table; seed it from `code_analysis/menu_inventory/menu_items.csv`
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
Phase 1 step 3+4 (generate the File menu from the table + a command-palette
prototype) is the proposed proof-of-concept. Not started yet.
