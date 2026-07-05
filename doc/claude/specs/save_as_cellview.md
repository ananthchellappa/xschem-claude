# Spec — Library/Cell/View Save & Save-As form

**Branch:** `fluid-editing`. **Status:** IMPLEMENTED 2026-07-02. `src/save_as_form.tcl`
(`saveform::` form + `savebrowse::` browser + `save_as_cellview_dialog`), sourced from
`xschem.tcl` after `create_instance.tcl`; the one-line C hook in `saveas()` (`actions.c`)
redirects the chooser to the form. Tests: `tests/headless/test_save_as_cellview.tcl`
(headless core, sabotage-verified) + `tests/headless/test_save_as_form.tcl` (X-gated form).
End-to-end verified: bare `xschem saveas` routes through the form proc → `save_schematic`
→ identity rebound. GUI eyeball (the blocking Save click) still recommended.
**Goal:** replace the old file-path "stone-age" save dialog with a Cadence-style
**Library / Cell / View** form (like Create Instance), while keeping the old dialog
reachable via a **Legacy** button.

Related: [[cadence_create_instance]] (the form/browser template), `src/library_defs.tcl`
(the LCV model), issue 0060 (untitled backup), `doc/claude/specs/create_symbol_view.md`.

---

## 1. Motivation / user request

When the user chooses **Save** or **Save As**, they currently get the old file-path
chooser (`save_file_dialog`). We want a form whose fields are just **Library**, **Cell**,
**View**, with a **Browse** button (the same 3-column Library→Cell→View picker the Create
Instance form uses). The user can pick via the browser or type into the fields:

- **Library must already exist.** If the typed library is unknown → an error popup, and
  the Library entry text is **selected** so the user can immediately retype it.
- **Cell / View are created if missing** (a new cell dir and/or view dir).
- A **Legacy Xschem** button drops to the old `save_file_dialog` for a plain path save.
- Saving as a cellview means the on-disk file is always **`<cell>.<ext>`** inside the
  view dir; `<ext>` is `.sch` for a schematic buffer, `.sym` for a symbol buffer.

## 2. The LCV model this builds on (already in `src/library_defs.tcl`)

Read-side (thin `xschem` shims over these procs):
- `xschem libraries` → `library_list` → `{name path}` pairs.
- `xschem library <name>` → `library_resolve` → abs path, or `""` if unknown. **← the
  library-exists check.**
- `xschem lib_cells <lib>` → `library_cells`.
- `xschem cell_views <lib> <cell>` → `cell_views`.
- `xschem cellview_path <lib/cell> <view>` → `cellview_resolve` → abs datafile path, or
  `""` if it does not exist yet.
- `schematic_cellview <abspath>` → `{lib cell view layout}` (reverse map, for pre-fill).

Layout: a view is `<libpath>/<cell>/<view>/<cell>.<ext>` (nested; the canonical
Cadence-ish layout). A nested cell/view is just directories — no registration needed
beyond the library's `library.defs` DEFINE, so **`file mkdir` + save is sufficient** and
the new cell/view appears in `library_cells`/`cell_views` automatically.

**Extension rule (important):** for the SAVE target the extension comes from the BUFFER's
editor type (schematic→`.sch`, symbol→`.sym`), NOT from the view name. `cellview_resolve`
derives ext from the view name only for READ resolution (with a `<cell>.*` glob fallback);
the writer must construct `<cell>.<type-ext>` explicitly.

## 3. Current save plumbing (do not re-architect — hook into it)

- Menu (table-driven, `src/actions.csv`): `file.save`→`xschem save`,
  `file.save_as`→`xschem saveas`, `file.save_as_symbol`→`xschem saveas {} symbol`.
- Keys (C, `callback.c`): Ctrl-S → `save(0,0)` (or `saveas(NULL,SCHEMATIC)` when the name
  is empty/`untitled`); Ctrl-Shift-S → `saveas(NULL,SCHEMATIC)`; Ctrl-Alt-S →
  `saveas(NULL,SYMBOL)`.
- `xschem saveas [path] [type]` (`scheduler.c:7113`) → C `saveas(fptr, SCHEMATIC|SYMBOL)`
  (`actions.c:636`):
  - `path` given (non-NULL) → writes it **verbatim** via `save_schematic(path,0)`.
  - `path` NULL and `has_x` → pops `save_file_dialog {Save file} * INITIALLOADDIR {<name>}`,
    reads the chosen path from `tclresult()`, then `save_schematic(res,0)`.
- `save_schematic(name,0)` (`save.c:3556`) is the identity chokepoint: when `name` differs
  from `xctx->sch[currsch]` it **rebinds the current cell's identity**
  (`sch[currsch]`, `current_name`, `current_dirname`, title, clears modified, drops the `~`
  backup). It does NOT `mkdir`; the caller must ensure the directory exists.
- After `xschem saveas` returns, `scheduler.c:7137` re-derives read-only from the new
  file's writability and refreshes the title.

**Every Save/Save-As entry point that needs a chooser funnels through `saveas(NULL,type)`
→ the `save_file_dialog` tcleval.** Redirecting that one call routes them all.

## 4. Design

### 4.1 Integration = ONE C line (Model A: form returns a path)

In `saveas()` (`actions.c`), replace the dialog invocation

```c
my_snprintf(name, S(name), "save_file_dialog {Save file} * INITIALLOADDIR {%s}", filename);
```

with a call to the new blocking Tcl chooser, passing the buffer type and the seed name:

```c
my_snprintf(name, S(name), "save_as_cellview_dialog {%s} %s",
            filename, type == SYMBOL ? "symbol" : "schematic");
```

`save_as_cellview_dialog` returns the chosen absolute datafile path (having already
`file mkdir`'d its directory), or `""` to abort. C then proceeds exactly as today
(`save_schematic(res,0)` rebinds identity, logs, updates recents). This single change
covers Save-As, Save-as-symbol, Ctrl-S on an untitled buffer, and `xschem save` on an
unnamed buffer — all funnel here. The explicit-path form `xschem saveas <path> <type>`
is untouched (no dialog), so scripts/tests keep working.

Rationale for Model A over routing the menu/keys to a modeless form: one change, all
entry points, and it reuses the identity-rebind/readonly/log plumbing unchanged. The old
dialog was already blocking (`tkwait window .load`), so a blocking chooser is idiomatic.

### 4.2 The form (`saveform::`, new file `src/save_as_form.tcl`)

Modeled on `ciform::` (Create Instance). Blocking: opened by
`save_as_cellview_dialog {seedname} {schematic|symbol}`, which builds `.saveform`, waits
(`tkwait window .saveform`), and returns `::saveform::result` (a path or `""`).

Widgets:
- Three label+entry rows **Library / Cell / View** (`saveform::lib/cell/view`), reusing the
  slick fonts, like `ciform`.
- A **Browse…** button → the LCV browser (§4.3).
- A status line (shows the resolved target / errors).
- Bottom buttons: **Save** (commit), **Legacy Xschem** (old dialog), **Cancel**.
- The window title reflects the type: "Save As (schematic)" / "Save As (symbol)".

Pre-fill: seed the fields from the current buffer's identity. If the seed name resolves
under a registered library (`schematic_cellview`), pre-fill lib/cell/view. Else leave
Library blank (or default to the first writable library), Cell = the seed's basename, View
= the type's canonical name (`schematic`/`symbol`).

`saveform::save` (Save button / Return):
1. Read lib/cell/view. Require all three non-empty (status prompt if not).
2. **Library validation:** `xschem library $lib` == `""` → `tk_messageBox` error
   ("Library '<lib>' does not exist"), then `focus` the Library entry and **select its
   text** (`$e selection range 0 end`), and return (form stays open).
3. Compute `ext = (type eq symbol ? sym : sch)`, `lp = [xschem library $lib]`,
   `path = [file join $lp $cell $view "$cell.$ext"]`.
4. `file mkdir [file dirname $path]` (creates the cell/view dirs if missing).
5. Set `::saveform::result $path`, `destroy .saveform` → the blocking dialog returns the
   path to C, which saves + rebinds identity.

`saveform::legacy` (Legacy button): call the old `save_file_dialog {Save file} *
INITIALLOADDIR {<seed>}`, set `::saveform::result` to its return, destroy `.saveform`. So
the Legacy path returns a plain chosen path to the same C plumbing.

`saveform::cancel` / Esc / window close: `::saveform::result ""`, destroy → C aborts
(no save).

### 4.3 The Browse browser (`savebrowse::`, in the same file)

A 3-column Library→Cell→View listbox picker modeled on `mkinst::`, but:
- It lists **all** views of a cell (not only symbol views) — Save may target any view.
- Selecting pushes `{lib cell view}` live into the form's fields (same `set_lcv` pattern).
- Selecting a Library that has cells, or a Cell that has views, helps the user pick an
  existing target to overwrite; typing a NEW cell/view name in the form creates it on Save.
- Cancel/Esc dismiss the browser; the form keeps whatever was applied.

Kept separate from `mkinst::` so Create Instance is untouched (and its symbol-only view
filter stays). Shared model calls (`xschem libraries/lib_cells/cell_views`) are identical.

### 4.4 Behaviors / edge cases

- **Untitled → real cellview:** the common case. Save rebinds `sch[currsch]` from
  `untitled.sch` to `<lib>/<cell>/<view>/<cell>.<ext>` (issue 0060's `~` backup is dropped
  by `save_schematic` on the successful save).
- **Overwrite existing cellview:** if the target file exists, `save_schematic` overwrites
  it (same as the old dialog with overwrite confirmed). Optional: a `tk_messageBox`
  overwrite confirm when the target `<cell>.<ext>` already exists — mirror the old dialog's
  `overwrt` behavior. (Decision: confirm on overwrite of an EXISTING different-identity
  file; silent when re-saving the current buffer's own file.)
- **Symbol vs schematic:** `type` from C selects the extension and the default view name.
  A schematic buffer saved into a view that already holds a `<cell>.sym` just adds
  `<cell>.sch` alongside (both are valid views of the cell); documented, not blocked.
- **No writable library / none defined:** the Browse list may be empty and any typed
  library fails validation → Legacy button is the escape hatch.
- **Read-only buffer:** `xschem save`/`saveas` already block on `xctx->readonly` upstream;
  the form is never reached. No extra guard needed.
- **Headless / `--nogui`:** `saveas(NULL,...)` is `has_x`-gated, so the form never opens
  headless; scripted saves use the explicit `xschem saveas <path> <type>`.

## 5. Test surface

**Headless CORE (no X)** — a backend proc `saveform::resolve_target {lib cell view type}`
(pure: validate lib, compute + `mkdir` path, return it or throw), tested directly:
- resolves `{lib cell view schematic}` → `<lp>/<cell>/<view>/<cell>.sch`; `symbol` → `.sym`.
- unknown library → throws (the popup is the GUI wrapper; core throws).
- creates the cell dir and the view dir when missing (assert `file isdirectory`).
- after `xschem saveas <path> <type>`: the file exists, `xschem get schname` == path,
  the buffer is no longer modified, and the cell/view now enumerate via
  `xschem lib_cells`/`cell_views`.
- an untitled buffer saved this way rebinds identity (schname changes off `untitled.sch`).

**X-gated FORM** (like `test_create_instance.tcl`, `gui`-gated):
- `save_as_cellview_dialog` builds `.saveform` with Library/Cell/View entries + Browse +
  Save + Legacy + Cancel.
- unknown-library Save → error path: form stays open, Library entry has a selection
  (`$e selection present`), no save happened.
- Browse opens `.savebrowse`; selecting lib/cell/view fills the form live.
- Legacy button routes to `save_file_dialog`.
- Cancel/Esc return `""` (abort).
- integration smoke: pre-fill from a buffer already in a library.

RED-first: write the core tests first (they fail — proc absent), implement, then the form.
Sabotage-verify each (neuter validation / path build → the asserting checks redden).

## 6. Non-goals (this pass)

- No changes to the Library Manager (`libmgr`), Create Instance (`ciform`/`mkinst`), or
  `library_defs.tcl` model. Build on top only.
- No new library CREATION from the save form (library must exist; use the Library Manager
  to make one). Cell/view creation only.
- Layout/other view types beyond schematic/symbol are out of scope (the writer only emits
  `.sch`/`.sym`).
