# Accomplishments: the action registry — new features & refactoring wins

A scannable record of what was delivered on branch `feature/action-registry`,
split into **user-facing features** and **engineering/maintainability gains**.
Everything here is UI/Tcl-layer only — the C engine (`callback.c`,
`handle_key_press`) is untouched and stays the source of truth for un-migrated
keys. All work is behind a green engine regression harness.

---

## 1. New features (what users get)

### Command palette — fuzzy "run any action"  *(Phase 1)*
- Press **Ctrl+Shift+P** (or Help → Command palette): a fuzzy-searchable launcher
  over every action in the table. Type a few letters of a label/help/id and run it.
- Directly addresses xschem's #1 UX gap — **discoverability**. ~131 commands are
  searchable today.
- Built by *reuse*, not new code: rides the existing `fuzzy_subseq_score` matcher.

### Remappable keyboard shortcuts  *(Phase 2)*
- Keyboard shortcuts are now generated from the action table and can be **remapped
  as data** — change a row's `accel`, the live binding follows (old key released,
  new key active). Proven end-to-end (`remap_action_accel`).
- Migrated in safe, verified batches. Batch 1: **undo, redo, zoom-in, zoom-out**.
- Mechanism is C-free: a more-specific Tk binding pre-empts the generic
  `<KeyPress>`, so migrated keys are intercepted *above* the C dispatcher while
  every other key behaves exactly as before.

### Always-accurate keybindings cheat-sheet  *(Phase 2)*
- **Help → "Keybindings (from table)"**: a cheat-sheet *generated* from the same
  table that drives the bindings, so it cannot drift. Replaces the hand-maintained,
  drift-prone `keys.help` prose. Migrated (remappable) keys are flagged `*`.

### Table-generated File menu  *(Phase 1)*
- The File menu is now produced from the table (commands, separators, static
  submenus like *Image export*, dynamic submenus like *Open recent*) instead of
  ~68 lines of hand-written menu code — proven byte-identical to the original
  (28/28 entries).

---

## 2. Refactoring wins (what developers get)

### Single source of truth — the duplicated fact became data
- Before: each action was hand-synced across **three** places — a decorative menu
  `-accelerator`, a `case` in the 1600-line C keysym switch, and a line in
  `keys.help`. They drifted by default.
- After: one declarative table, `src/actions.csv` (133 command rows), with
  generators projecting it into menus, the palette, the key bindings, and the
  cheat-sheet. Change the fact once; every view updates.

### Extensibility — adding an action went from a 3-file edit to a 1-line row
- Add a palette-searchable action = **append one CSV row**. Make it a menu item =
  set its `menu` field. No Tcl to write for the common case. (Documented as a
  30-second quickstart.)
- New generators are small and composable: menus, palette, bindings, cheat-sheet
  are each a short proc reading the same table — new projections (toolbar,
  tooltips, context menus) are now cheap follow-ons rather than from-scratch work.

### Readability — intent extracted from incantation
- Inline multi-line menu `-command {…}` scripts were promoted to **named procs**
  (`action_reload`, `action_component_browser`, …) so every table `command` cell
  is a clean single call — data stays simple, complexity has a name.
- The accelerator translation rules (display string → Tk event pattern) and the
  migrate/leave-in-C classification are written down explicitly, including the
  non-obvious keysym-vs-casing rule that was previously tacit in C.

### Safe, auditable migration — an explicit boundary
- An explicit `migrated_action_ids` allowlist names exactly which keys the new
  layer owns; everything else is provably untouched. The set of keys C no longer
  handles is auditable in one place and grows one reviewed batch at a time.
- Bindings are re-runnable (release-then-rebind), so regeneration/remapping never
  leaks stale bindings — the property that makes "data-driven" actually mean
  "changeable," not just "generated once."

### Risk containment — the C engine was never touched
- The entire feature set lives at the Tk/Tcl seam. `callback.c` is byte-for-byte
  unchanged across both phases (verifiable with `git diff`), so the highest-risk
  code (the `xctx` editing core) carried zero regression risk.

---

## 3. Test & verification infrastructure (new)

A hermetic, headless harness now backs the work — previously there were no tests
for any of this:

| test | proves |
|---|---|
| `tests/headless/run.sh` | engine unchanged — netlists + diffs golden output (6/6 PASS after every commit) |
| `tests/headless/dump_file_menu.tcl` | generated File menu == original (28/28 entries) |
| `tests/headless/test_palette.tcl` | palette binding installed; fuzzy match works |
| `tests/headless/test_accelerators.tcl` | each migrated key == its old C action **by observation**; un-migrated keys still reach C (12/12) |
| `tests/headless/test_remap.tcl` | remapping moves the live binding end-to-end (7/7) |
| `tests/headless/test_keybindings_help.tcl` | cheat-sheet matches the table and follows remaps (6/6) |

The verification standard is *observation, not assertion*: migrated keys are
confirmed by pressing them in the running GUI and measuring the effect (identical
zoom ratio; wire removed/restored), then comparing against the direct command.

---

## 4. Evidence at a glance

- **C engine:** 0 lines changed (`callback.c` untouched).
- **Single source of truth:** 1 table, 133 command rows, ≥4 generated views
  (menu, palette, bindings, cheat-sheet).
- **Discoverability:** ~131 commands searchable via the palette.
- **Tests:** 6 headless suites; engine harness 6/6 green throughout.
- **Cost-of-change:** "add a discoverable, (soon) remappable action" went from a
  3-file hand-synced edit to a single CSV row.

---

## 5. What is now cheap that wasn't

Because actions and (increasingly) bindings are data, these previously-expensive
features are now incremental additions reading the same table:

- **Customize-shortcuts dialog** — the engine exists (`remap_action_accel`); only
  the UI remains.
- **Toolbar / context menus / tooltips** — projections of the table.
- **Per-action enable/disable (greying out)** — an `enable_when` predicate column.
- **More remappable keys** — widen the allowlist, one verified batch at a time.

---

## 6. Scope & honesty (what was deliberately *not* done)

- The C `handle_key_press` chain still owns every un-migrated key — by design. Keys
  that depend on mouse-over-graph routing, modal placement/drag, or in-progress
  edit state stay in C until the supporting layers exist.
- Only the File menu is table-generated so far; other menus remain hand-written
  and coexist with the table (the rows are already present and palette-searchable).
- Symbol keys (`# = * & !`) and multi-key/mouse accelerators are recognized and
  intentionally left to C for now rather than mis-bound.

---

## Appendix: where it lives

| file | role |
|---|---|
| `src/actions.csv` | the action table — single source of truth |
| `src/action_registry.tcl` | loader + generators (menus, palette, bindings, remap, cheat-sheet) |
| `src/xschem.tcl` | sources the registry; File menu, palette + generated bindings in `set_bindings`; Help entries |
| `tests/headless/*` | engine harness + GUI smokes |
| `claude_suggs/tutorial_action_registry.md` | Phase 1 walkthrough (menus + palette) |
| `claude_suggs/tutorial_action_registry_phase2.md` | Phase 2 walkthrough (data-driven shortcuts) |
| `claude_suggs/handle_key_press_engineering_critique.md` | why the old design blocked this, and the migration strategy |
| `claude_suggs/refactor_plan_action_registry.md` | the risk-sequenced plan + status |
