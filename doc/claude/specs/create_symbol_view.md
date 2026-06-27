# Spec: library-aware "Create symbol from schematic" (with view choice + Modify)

Branch context: `fluid-editing`. Builds on the OpenAccess/Cadence-style library
infrastructure in `src/library_defs.tcl` (Library / Cell / View model).

## Problem

The Symbol menu's **Make symbol from schematic** (accelerator `A`) writes the
`.sym` into the **same directory as the `.sch`**, ignoring the library's layout. For
a cell in a Cadence-like *nested* library —
`<libpath>/<cell>/schematic/<cell>.sch` — the symbol must instead become the
**`symbol` view**: `<libpath>/<cell>/symbol/<cell>.sym`. Today it lands wrongly at
`<libpath>/<cell>/schematic/<cell>.sym`.

It also offers only a blunt "symbol exists — overwrite? ok/cancel", with no way to
name the view or to *augment* an existing symbol with newly-added schematic pins.

## Current behavior (the code path)

`make_symbol()` (`src/save.c:3291`) → Tcl `make_symbol {schpath}` (`src/xschem.tcl`)
→ `make_sym.awk`. The awk derives the output as `sub(/\.sch.*$/,".sym")` on the
input path (line 51) and writes there — hardcoded "same dir, swap extension". The
only guard is a `tk_messageBox` overwrite confirm in `make_symbol`.

## Desired behavior

On `A` / the menu item:

1. **Resolve the cell** from the current schematic's absolute path
   (`xschem get schname`) → `{lib cell view layout}`.
   - **nested/OA** library → continue with the view-aware flow below.
   - **flat** library, or schematic **not** under any registered library → keep the
     legacy behavior: write `<schdir>/<cell>.sym` (a "view name" is meaningless in a
     flat layout). The Replace/Modify choice (step 3) still applies when that `.sym`
     already exists.

2. **Adaptive form** (nested case): a single dialog with a **View name** entry,
   default `symbol`. The dialog watches the typed name:
   - if that view does **not** exist for the cell → a **Create** action;
   - if it **already exists** → reveal **Replace** / **Modify** actions.
   The dialog also offers **Cancel**.

3. **On confirm:**
   - **Create** (view absent) → make the view dir if needed
     (`<libpath>/<cell>/<view>/`) and generate `<cell>.sym` there.
   - **Replace** (view present) → regenerate the whole symbol at the view path
     (legacy generation, correct location).
   - **Modify** (view present) → **add only the pins** that exist in the schematic
     but are missing from the existing symbol. **No existing artwork is touched** —
     no graphics rewritten, **no symbol box resized/extended**, existing pins/labels
     left exactly as they are. Only new `B` pin records are appended.

4. **After a successful create/replace/modify, open the symbol view in a new
   window for editing**: `xschem load_new_window {<viewpath>/<cell>.sym}`.

### Pin placement in Modify
New input pins are appended on the **left**, new output pins on the **right**
(matching `create_symbol`'s convention); inout treated as output side. Placement
uses free space below existing pins; the symbol box is **not** resized even if a new
pin falls outside it (per explicit decision — artwork is sacrosanct in Modify).

## Building blocks (already present in `library_defs.tcl`)

- `library_layout_style {lib}` → `nested` | `flat` (reads `library.tag` LAYOUT, else
  heuristic over cells). OA detection.
- `library_resolve {name}` → library root path.
- `library_view_dir {lib cell view}` → the view dir if it holds `<cell>.*`, else "".
- `cell_views {libname cell}` → existing view names (nested subdirs + legacy flat).
- `library_new_view {lib cell view {type}}` → mkdir view + empty cellfile.
- `library_list` → `{name path}` pairs for all registered libraries.
- `lib_qualified_rel {symbol}` → reverse path→`lib/cell`, but **symbol-view pattern
  only** — must be generalized for schematic paths (see Gaps).

## Gaps to fill

1. **Reverse resolver** `schematic_cellview {abspath}` → `{lib cell view layout}` (or
   empty if the path is not under a registered library). Iterate `library_list`,
   longest-prefix-match the lib path, then parse the remainder:
   `<cell>/<view>/<cell>.sch` (nested) or `<cell>.sch` (flat). Pure path/string +
   `library_layout_style`; no engine state.
2. **Output redirection** for the generator: add an **optional output-path argument**
   to `make_sym.awk` — when given, write the `.sym` there instead of the
   same-dir derived name. (Cleaner than generate-then-move, which would litter
   `schematic/` and risk clobbering a stray `.sym`.)
3. **Pin merge** for Modify: extract schematic pins without re-implementing the
   awk's logic — generate a **temp** symbol with `make_sym.awk` (fresh, all pins),
   parse `B 5 … {name=… dir=…}` records from the temp and from the existing symbol,
   and append the **missing** ones (by pin `name`) to the existing symbol file.

## Phased plan (RED-first; build + suites + commit + tutorial per phase)

| Phase | Change | Test (headless where possible) |
|---|---|---|
| **0** | Spec (this file). Add `schematic_cellview {abspath}` reverse resolver. | unit: nested path → `{lib cell schematic nested}`; flat path → `{… flat}`; unregistered → `{}`. |
| **1** | Route generation to the view dir for **Create**/**Replace**; add `make_sym.awk` output-path arg; view-name handling. | nested fixture → `.sym` in `symbol/`, not `schematic/`; flat → unchanged. |
| **2** | Adaptive **View name / Replace / Modify / Cancel** dialog; wire menu+`A`. Logic testable by stubbing the dialog (the dialog itself is `has_x`-gated → eyeball). | stubbed-dialog logic: absent→create, present+replace→regenerate, present+modify→merge, cancel→no-op. |
| **3** | **Modify** pin-merge (temp-symbol diff; pins only, artwork untouched). | symbol missing K of N pins → modify adds exactly those K; every pre-existing record byte-identical. |
| **4** | Open the view in a new window after OK (`load_new_window`). Edge cases: read-only library, symbol already open in another tab, invalid view name. GUI eyeball in cadence mode. | suites green; manual pass. |

## Test strategy

- The **path resolution, output routing, and pin-merge** are pure/file-level and
  fully headless-testable (`--nogui --pipe -q --nolog --script`).
- The **dialog** is `has_x`-gated; test the orchestration by stubbing the dialog proc
  (return scripted view-name + action), and reserve appearance/flow for a human
  eyeball — the testable-mechanism / GUI-gated-trigger split established earlier.
- Fixtures: build a tiny nested library under `/tmp`
  (`lib/cell/schematic/cell.sch` + a `library.tag` with `LAYOUT nested`) and a flat
  one; never write into committed `xschem_library*`.

## Decisions (confirmed)

- Flat / unregistered: keep legacy same-dir behavior.
- One **adaptive** dialog (name entry reveals Replace/Modify when the name exists).
- Modify places new inputs left / outputs right; **touches no artwork** (no box
  resize, no rewrite of existing records) — pins are added, nothing else.
- After OK, the symbol view opens in a **new window** for edit.

## Deferred / out of scope

- Multi-cell / batch symbol generation.
- Reconciling pin **direction or position** changes for pins that already exist in
  the symbol (Modify only *adds* missing pins; it does not update existing ones).
- `make_sym_lcc.awk` (LCC) path — same treatment could follow later if needed.
