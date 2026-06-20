# Cadence-like instantiation: the "Create Instance" library browser

Status: **implemented** (branch `fluid-editing`).
Related: `specs/library_manager_launch.md` (the launch-command / single-window-focus
pattern this reuses), `code_analysis/library_manager_design.md` (the lib/cell/view
model), `src/library_manager.tcl` (the browser widgetry to draw on),
`code_analysis/gui_focus_and_testability_lessons.md` (focus behavior + test limits).

## 1. Goal

Make placing a symbol feel like Cadence Virtuoso's **Add ▸ Instance**: the user
opens a *library browser*, selects a **Library → Cell → (symbol) View**, and the
symbol attaches to the cursor for placement — repeatedly, from a floating form.
Today's entry point (`Tools ▸ Insert symbol`) is a bare action that drops straight
into a flat file dialog; that is replaced by a proper instance-creation tool.

## 2. Current state (verified)

- `Tools ▸ Insert symbol` → `xschem place_symbol` (no arg), accelerator `Ins` /
  `Shift-I` (`src/xschem.tcl:11296`). Also a toolbar button (`ToolInsertSymbol`) and
  a right-click context-menu entry.
- `xschem place_symbol` **(no arg)** pops the legacy `.load` file dialog
  (`file_dialog_place_symbol`, `src/xschem.tcl:4713`) to pick a `.sym`, then enters
  interactive placement (symbol attached to cursor, `PLACE_SYMBOL` ui_state `8192`,
  drop on click).
- `xschem place_symbol <ref>` skips the dialog and goes straight to interactive
  placement. `<ref>` may be a lib-qualified `lib/cell` (resolved to the symbol view
  via the registry) — this is exactly what the Library Manager's `place_symbol`
  button does (`libmgr::place_symbol`), guarding on
  `xschem cellview_path <ref> symbol ne {}`.
- The Library Manager (`src/library_manager.tcl`) already renders a 3-column
  Library/Cell/View browser over the read-only query commands
  (`xschem libraries` / `lib_cells` / `cell_views` / `cellview_path`).

## 3. The change

### 3.1 Menu / entry points
- **Remove** `Tools ▸ Insert symbol`.
- **Add** `Edit ▸ Create Instance` → opens the new Create Instance browser.
- New dispatcher command **`xschem create_instance`** (the menu, the key binding,
  and replay all go through it). Like `xschem library_manager` it is logged
  (`log_action`) so the launch is replayable and bindable, and it is a singleton
  that raises+focuses an already-open form (reusing the `focus -force` +
  withdraw/deiconify pattern from `specs/library_manager_launch.md`).
- **`cadence_style_rc`** binds the key **`i`** to it:
  `bind .drw <Key-i> {xschem create_instance}`.
- The default **Insert key stays legacy** (`xschem place_symbol`) for non-cadence
  users — only `cadence_style_rc` rebinds. (Decision ratified with the user.)
- The toolbar button and right-click "Insert symbol" entry are **left as-is** in v1
  (they still run legacy `place_symbol`); revisiting them is a noted follow-up, not
  part of this change.

### 3.2 The Create Instance form (`.mkinst`)
A **new, dedicated, modeless** toplevel — separate from the Library Manager.

- **Layout:** the same 3-column Library / Cell / View browser as the Library
  Manager (reuse the query commands and as much listbox logic as is cleanly
  shareable). The **View column is restricted to symbol views** — a selection is
  only valid when it maps to a `.sym`.
- **The .sym guard (the "most important" requirement):** before placing, verify
  `xschem cellview_path <lib/cell> symbol ne {}` (a real symbol view / `.sym`).
  Cells with no symbol view are not placeable: the Create button is disabled and the
  status line says why. (A cell may have only a schematic view; xschem can
  auto-symbol a `.sch`, but v1 requires an actual symbol view, matching "select a
  symbol view".)
- **Buttons:**
  - **Create** (and double-click on a cell/symbol) → `xschem place_symbol <lib/cell>`:
    the symbol attaches to the cursor for an interactive drop on the canvas. The
    form **stays open** (modeless) so several instances can be placed in a row. On
    Create the form does **not** grab focus back (the canvas needs the placement
    clicks).
  - **Legacy Xschem** → `xschem place_symbol` (no arg): the exact dialog used today,
    untouched, for users who want the flat file picker.
  - **Close** → withdraw/destroy the form.
- **Single window + focus:** opening when already open raises and focuses the form
  (the `raise_to_front` pattern), so the key binding is idempotent.

### 3.3 Logging / replay
- The launch logs `xschem create_instance` (CIW + `Xschem.log`).
- The placement itself is already replayable: the interactive drop logs a concrete
  `xschem instance {...}` from `callback.c` (see `test_action_log_libmgr.tcl` AL9),
  so no extra command-level logging is added for Create (that would duplicate the
  drop and be non-replayable).

## 3.4 Fluid placement (refinement)

The form is a *selector that arms a live preview*, not a click-Create dialog:

- **No Create button.** As soon as a cell + symbol view is selected (and on every
  selection change), the symbol is **armed for placement automatically** — the
  preview follows the cursor the moment the mouse returns to the schematic canvas.
  Switching selection re-arms with the new symbol (the previous, undropped preview
  is aborted first).
- **Repeat.** After dropping an instance the same symbol stays armed (xschem's
  native place loop), so the user keeps clicking to place more.
- **Esc ends the whole gesture.** While the form is open, Esc both aborts the
  current placement **and dismisses the form** (whether the canvas or the form has
  focus). Closing the form by any means (Close, WM close) likewise aborts an armed
  placement. (Esc is bound at the Tcl level on the canvas and the form while open,
  and removed when the form is destroyed, restoring the default Esc.)
- **Resume on reopen.** The form remembers the most recently armed Library / Cell /
  View. Re-launching (`Edit ▸ Create Instance` / the `i` key) restores that
  selection **and re-arms the preview immediately**, so the user can place without
  touching the form.
- **Recursion guard (a circuit is physical — no cell may contain itself).** A
  selection is refused when its schematic view *is the schematic currently being
  edited* (`cellview_path <lib/cell> schematic` == `xschem get schname`): the
  preview is not armed and the status line explains. Cells with no schematic
  (primitives) are always placeable. v1 guards the current schematic; guarding the
  whole hierarchy stack (an ancestor is also recursion) is a noted extension.

## 4. Out of scope (v1)

- **Instance parameter fields** in the form (Cadence shows property fields before
  placing). v1 is selection-only; set properties via the existing Edit Properties
  form after placement.
- A **Category** column.
- Changing the toolbar button / context-menu entry (see §3.1).
- Replacing the legacy `.load` dialog itself (kept verbatim behind the Legacy
  button).

## 5. Acceptance / tests

Discriminating, automatable checks (GUI, needs X) — `tests/headless/test_create_instance.tcl`,
CI1–CI6 (the `.sym` guard CI4 sabotage-verified):

- CI1 `xschem create_instance` opens `.mkinst`; `Edit ▸ Create Instance` is wired to
  it; `Tools ▸ Insert symbol` is gone.
- CI2 single window: a second `xschem create_instance` reuses the same window
  (stable X id), not a second one.
- CI3 the browser populates libraries; selecting a library fills cells; the View
  column shows only symbol views.
- CI4 the `.sym` guard: a cell **with** a symbol view enables Create and
  `cellview_path … symbol` is non-empty; a cell **without** one disables Create and
  resolves empty.
- CI5 Create starts interactive placement (`ui_state` has the `PLACE_SYMBOL` bit
  `8192`), the form stays open, abort clears it, and it can place again.
- CI6 the Legacy button is wired to `mkinst::legacy`, which calls no-arg
  `place_symbol` (asserted structurally — the legacy dialog is modal, not invoked).
- CI7 (= AL11 in `test_action_log_libmgr.tcl`, run with `--logdir`): launching logs
  a replayable `xschem create_instance` line.

**Manual eyeball (per the focus lessons):** that the floating form does not steal
the placement clicks, and that cross-window focus on launch behaves — WM-arbitrated,
not reliably assertable headless.

## 6. Phased plan (proposed — for sign-off)

1. **Engine command.** Add `xschem create_instance` in `xschem_cmds_*` (scheduler.c):
   `has_x`-gated, `log_action`s, `tceval`s the Tcl opener. RED test CI1/CI7.
2. **The form.** New `src/create_instance.tcl` (`mkinst::` namespace): 3-column
   browser over the query commands, symbol-view filter, `.sym` guard, Create /
   Legacy / Close, modeless + `raise_to_front`. Source it from `xschem.tcl` next to
   `library_manager.tcl`. RED→GREEN CI2–CI6.
3. **Menu surgery.** Remove `Tools ▸ Insert symbol`; add `Edit ▸ Create Instance`
   → `xschem create_instance`.
4. **rc binding.** `cadence_style_rc`: `bind .drw <Key-i> {xschem create_instance}`.
5. **Tests + docs.** `test_create_instance.tcl` (CI1–CI7, sabotage-verified); update
   this spec to "implemented"; note the toolbar/context follow-up.

Each phase builds and the suite stays green; ported to `library-manager` by
cherry-pick once signed off (mirrors the current branch arrangement).
