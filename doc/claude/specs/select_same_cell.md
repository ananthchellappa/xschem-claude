# Select all instances of the same cell / view (Ctrl-Alt-H)

## Goal

A Cadence-style shortcut that, from a single trigger, **selects every instance in the
current schematic that shares a cell (optionally a specific symbol view)** with some
reference. The reference comes from what the user has already indicated — a selected
text note, a selected instance, or a selection in the Library Manager.

This is the inverse of Ctrl-Alt-S (`locate_selected_in_libmgr`), which goes
schematic → Library Manager. Ctrl-Alt-H goes reference → schematic selection. It reuses
the same dispatch skeleton (`cadence::selkind`, `libmgr::selection`, `schematic_cellview`,
`cellview_path`) and is **pure Tcl — no C engine change**.

Binding: `bind .drw <Control-Alt-Key-h> {select_same_cell; break}` in `cadence_style_rc`,
helper in `utils/select_same_cell.tcl` (sourced after `cadence_nav.tcl` and
`lib_mgr_helpers.tcl`).

## Identity model

A **symbol view is a specific `.sym` datafile** (`<lib>/<cell>/<view>/<cell>.sym`, or a
legacy flat `<lib>/<cell>.sym`). Two facts follow and are the whole basis of matching:

- **Same lib/cell/view ⟺ same resolved absolute symbol path.** So "same view" matching
  compares normalized abs paths — this is exact and works for nested, alt-named, flat and
  even unregistered symbols without needing to name the view.
- **Same lib/cell (any view) ⟺ same `{lib cell}`** as reported by
  `schematic_cellview <abspath>` (registry-aware; `{}` for symbols not under any
  registered library).

Per-instance identity (`selsame::inst_ident i`):
```
ref = xschem getprop instance i cell::name      ;# the symbol reference, e.g. devices/res
abs = file normalize [abs_sym_path ref]         ;# view-precise key ("" if unresolvable)
{lib cell view _} = schematic_cellview abs      ;# view-agnostic keys ("" if unregistered)
```

## Three match modes

| mode | matches an instance when | warns about |
|------|--------------------------|-------------|
| `lib`  | `inst.lib == target.lib` (lib non-empty) | — |
| `cell` | `inst.lib/inst.cell == target.lib/target.cell` | — |
| `view` | `inst.abs == target.abs` | same lib/cell, different abs (a different symbol view not added) |

`selsame::match {mode target idents}` is a **pure function** over a list of
`{idx lib cell view abs}` tuples → `{matchedIdx otherViews}`, where `otherViews` is a list
of `{idx view}` for the view-mode warning. Abs paths are pre-normalized by the caller so
`match` uses plain string equality and is filesystem-independent (unit-testable).

## Reference resolution (`selsame::target` → `{mode target label}`)

Branches on `cadence::selkind` (which reports the schematic selection):

1. **One instance selected** (`inst n`): target = that instance's identity →
   **view mode**, `target = {lib cell abs}`, label `lib/cell/view`. Warns about siblings
   (same lib/cell) placed with a different symbol view. If the instance is unregistered
   (`lib==""`) it still matches by abs path; no warning is possible (no lib/cell group).

2. **One text note selected** (`text n str`): scan the note for the first
   `lib/cell[/view]` slash token (`selsame::parse_libcellview`):
   - `lib/cell/view` → **view mode**, `target.abs = cellview_path lib/cell view`
     (error if that view does not resolve).
   - `lib/cell` (two components) → **cell mode** (any view).

3. **Nothing selected in the schematic** (`none`): read the Library Manager
   (`libmgr::selection`, `{}`/`{lib}`/`{lib cell}`/`{lib cell view}`):
   - `{}` or Library Manager closed → informative error, no-op.
   - `{lib}` → **lib mode** (all instances of that library).
   - `{lib cell}` → **cell mode** (that cell, any view).
   - `{lib cell view}` → resolve the view's datafile: a **`.sym` (symbol-type) view →
     view mode + warning**; a `.sch` (schematic-type) or unresolved view is, per the
     requirement, *equivalent to no symbol view selected* → **cell mode**.

4. **Anything else** (multi-select, a single wire, etc.) → informative error, no-op.

## Apply + report

```
xschem unselect_all                      ;# replace the current selection
foreach i $matched { xschem select instance $i }
xschem redraw                            ;# draw() -> draw_selection paints the SELLAYER
ciw_echo "selected N instance(s) of <label>"
# view mode only, when siblings differ:
ciw_echo "warning: M instance(s) of lib/cell use a different symbol view (not selected): v1, v2" error
```

Selection is **replace**, not add: the shortcut answers "select all of these", so the
prior selection (including the reference note) is cleared first; in the one-instance case
the reference instance is naturally re-selected as one of the matches.

Matching is over the **current schematic level only** (`xschem get instances` /
`xctx->inst[]`), not the whole hierarchy — consistent with every other selection op.

## Non-goals / resolved defaults

- Multi-object or non-instance/non-text selections are **not** guessed at — they produce a
  one-line CIW hint and do nothing (mirrors Ctrl-Alt-S).
- Legacy/flat/unregistered symbols: view-mode (abs-path) matching still works; lib- and
  cell-mode only match symbols under a registered library (`schematic_cellview` non-empty).
- Token charset for the text note is `\w` (`[A-Za-z0-9_]`), matching
  `cadence::first_libcell`. Bracketed vector names are a documented non-match.

## Test plan (RED-first)

Pure (fast, no binary needed but run under the same harness):
- `parse_libcellview`: `a/b/c`→`{a b c}`; `a/b`→`{a b {}}`; embedded `pre x/y/z post`;
  no-slash (`I3`, `x1[5]`)→`{}`; four components→first three.
- `match`: lib/cell/view modes over synthetic tuples, incl. the view-mode `otherViews`
  grouping and unregistered (lib=="") abs-only matching.

Integration (binary, `--nogui --pipe -q --script`, temp registered library with a cell
carrying two symbol views `symbol` + `sym_alt` and a second cell):
- one-instance → selects same view, warns about the alt-view sibling;
- text `lib/cell` → selects both views' instances (cell mode);
- text `lib/cell/sym_alt` → selects only the alt-view instances;
- Library-Manager lib / cell / symbol-view / schematic-view selections drive lib / cell /
  view / cell modes respectively;
- `xschem get lastsel` and `xschem objects -selected -type instance` confirm the exact set.

Sabotage-verify each branch (green-but-hollow guard): neutering the matcher must redden the
count assertions, not just pass silently.
