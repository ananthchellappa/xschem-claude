# Cadence-like instantiation: the "Create Instance" library browser

Status: **implemented** (branch `fluid-editing`).
**Revised** to a two-dialog design — a properties-style **form** that owns the
fields + the live preview, plus the **Library Browser** it launches. See
**§6 (current design)** below; §3.2/§3.4 describe the original single-browser
form and are kept for history (the placement *mechanics* — fluid arming, the
keep-placing loop, the .sym guard, the recursion guard, Esc-ends-everything —
are unchanged; only the entry-point UI moved).

Related: `doc/claude/specs/library_manager_launch.md` (the launch-command / single-window-focus
pattern this reuses), `doc/claude/code_analysis/library_manager_design.md` (the lib/cell/view
model), `src/library_manager.tcl` (the browser widgetry to draw on),
`doc/claude/code_analysis/gui_focus_and_testability_lessons.md` (focus behavior + test limits).

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
  withdraw/deiconify pattern from `doc/claude/specs/library_manager_launch.md`).
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
- **Repeat (keep-placing).** After dropping an instance the same symbol is
  re-armed so the user keeps clicking to place more, until Esc. xschem's
  `place_symbol` is **one-shot** (a drop clears `PLACE_SYMBOL`), so the form
  re-issues it on each canvas `ButtonRelease` (a `+`-appended binding that is a
  no-op unless a symbol is armed and a drop just completed).
- **Esc ends the whole gesture.** While the form is open, Esc both aborts the
  current placement **and dismisses the form** (whether the canvas or the form has
  focus). Closing the form by any means (Close, WM close) likewise aborts an armed
  placement. (Esc is bound at the Tcl level on the canvas and the form while open,
  and removed when the form is destroyed, restoring the default Esc.)
- **Resume on reopen.** The form remembers the most recently armed Library / Cell /
  View. Re-launching (`Edit ▸ Create Instance` / the `i` key) restores that
  selection **and re-arms the preview immediately**, so the user can place without
  touching the form.
- **Recursion guard (a circuit is physical — no cell may contain itself, directly
  or through an ancestor).** A selection is refused when its schematic view is *any
  schematic in the current hierarchy stack* — the open schematic and every parent
  descended through (`cellview_path <lib/cell> schematic` equals `xschem get
  schname <n>` for some `n` in `0..currsch`). The preview is not armed and the
  status line explains. Cells with no schematic (primitives) are always placeable.

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
CI1–CI12 (updated for the §6 two-dialog design):

- CI1 `xschem create_instance` opens the **`.ciform` form** with four entry fields
  (`elib`/`ecell`/`eview`/`einstname`) + a Browse button and **no** Place button;
  `Edit ▸ Create Instance` is wired to it; `Tools ▸ Insert symbol` is gone.
- CI2 single window: a second `xschem create_instance` reuses `.ciform` (stable X id).
- CI3 typed fields that resolve to a real `.sym` arm the preview (`ui_state` has the
  `PLACE_SYMBOL` bit `8192`); a blank View arms nothing; a schematic-only view does
  not arm — each with an explanatory status (the `.sym` guard).
- CI4 the Instance Name field becomes the placed instance's `name=` (`name=M7` →
  an instance `M7` exists after a drop).
- CI5 Browse opens the `.mkinst` Library Browser with a **Cancel** button and **no
  OK / Apply** (selections apply live).
- CI6 every selection applies to the form live: a Library click fills Library (and
  clears Cell/View), a Cell click with a single symbol view also fills View and
  arms, a multi-symbol-view cell leaves View empty (no auto-fill) until a View is
  clicked; the View column lists only symbol views.
- CI7 Esc and the Cancel button both dismiss the browser via `mkinst::cancel`; the
  form survives and keeps the last live selection.
- CI8 keep-placing: each canvas drop re-arms the same symbol (continuous placement).
- CI9 Esc clears the placement and dismisses **both** the form and the browser.
- CI10 reopening restores the form's fields and re-arms.
- CI11 the Legacy button is wired to `ciform::legacy` = no-arg `place_symbol`
  (asserted structurally — the legacy dialog is modal, not invoked).
- CI12 recursion guard: a cell may not be placed in its own schematic, nor an
  ancestor in a descendant; a cell not in the stack still arms.
- (= AL11 in `test_action_log_libmgr.tcl`, run with `--logdir`): launching logs a
  replayable `xschem create_instance` line.

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

## 7. Revision: the Create Instance FORM + the Library Browser (current design)

The entry point is no longer the bare 3-column browser; it is a **properties-style
form**, with the browser demoted to a Browse target. `src/create_instance.tcl` now
holds two cooperating namespaces.

### 7.1 `ciform::` — the Create Instance form (`.ciform`)
- A compact toplevel with four entry fields — **Library Name**, **Cell Name**,
  **View Name**, **Instance Name** — styled with the slick property-form fonts
  (`slickprop::init_fonts` → `slickPropLabel`/`slickPropValue`), plus a **Browse…**
  button and a **Legacy Xschem** / **Close** button row. `xschem create_instance`
  opens it (logged, singleton, `raise_to_front`).
- **It owns the placement lifecycle.** There is **no Place button** — placement is a
  canvas click. Whenever the fields resolve to a real symbol view, the symbol is
  armed for a live preview (`ciform::arm` → `xschem place_symbol <sym> [name=…]`):
  - resolution = `xschem cellview_path <lib/cell> <view>` and the result must be a
    `*.sym` (`ciform::resolve`). **A blank/missing View ⇒ no preview ⇒ nothing to
    place** (the explicit requirement); the status line says what's missing.
  - the **recursion guard** (own-schematic or any ancestor in the hierarchy stack)
    and the **keep-placing** drop-hook loop are unchanged, just moved here.
  - the **Instance Name**, when set, is passed as the `name=` attribute of the
    placed instance; empty ⇒ xschem auto-names.
- Editing any field (`<KeyRelease>` → `ciform::on_change`) re-arms. Esc (canvas or
  form) ends placement and dismisses the form **and** the browser.
- **`xschem create_instance [lcv]`** takes the same list contract as
  `xschem library_manager`: an optional `{lib cell view [instname]}` list that
  pre-fills the form (overwriting the current fields, even when the singleton is
  already open) and re-arms. So `xschem create_instance [libmgr::selection]` /
  `[xschem get_inst_lcv]` drops a chosen cell straight onto the cursor. A 4th
  element sets the Instance Name; a bare `xschem create_instance` keeps whatever
  the form last held (`ciform::set_fields`).

### 7.2 `mkinst::` — the Library Browser (`.mkinst`), a LIVE picker
- The same 3-column Library / Cell / (symbol-only) View browser. It does not arm
  placement itself; instead **every selection is applied to the form immediately**
  (`mkinst::push` → `ciform::set_lcv <lib> <cell> <view>`, which re-arms the form's
  preview). Because each selection *is* an Apply, there is **no OK and no Apply
  button** — only **Cancel**, and **Esc** (`bind .mkinst <Key-Escape>` →
  `mkinst::cancel`) also dismisses the browser. Dismissing the browser leaves the
  form holding the last applied selection; the form is unaffected.
  - **Library click** (`on_lib`) → fills the form's Library field and clears Cell /
    View (the form tracks the now-incomplete selection: `{lib "" ""}`).
  - **Cell click** (`on_cell`) → lists the cell's symbol views. **If the cell has
    exactly one symbol view, it is selected so the cell click also fills the form's
    View field**; with several symbol views the View is left unselected (the form's
    View stays empty until the user clicks one); with none the status says so.
  - **View click** (`on_view`) → fills the form's View field.
- On open it highlights whatever the form currently holds (`restore_from_form` →
  `restore_path`), with the live push muted (`suppress_push`) so positioning the
  panes does not echo transient partial state back to the form.
- The form still owns the `.sym` guard, the recursion guard and the arming — the
  browser only pushes the chosen lib/cell/view.

### 7.3 What did not change
The launch command/logging (§3.1, §3.3), the `.sym` guard, the recursion guard
(§3.4), the fluid keep-placing loop, the Legacy fall-back, and Esc semantics are all
preserved — they moved from `mkinst::` to `ciform::`. The toolbar button and
right-click "Insert symbol" entry remain legacy (still a noted follow-up).
