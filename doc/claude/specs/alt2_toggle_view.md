# ALT-2 — toggle the view type (schematic ⇄ symbol) in the same window

## Goal

`Alt-2` **toggles the view *type* shown in the current editor window** between the
schematic-type view and the symbol-type view of the *same cell*:

- current window shows a **schematic-type** view → open the cell's **symbol** view;
- current window shows a **symbol-type** view → open the cell's **schematic** view.

It opens **in the same window** (replacing the current content, with the normal
"save changes?" prompt if the current view is modified). Nuances:

1. **Multiple views of the target type** → a modal drop-down asks which one. The
   drop-down defaults to the canonically-named view (`symbol` when picking a symbol
   view, `schematic` when picking a schematic view). With exactly one schematic and
   one symbol view (the common case) there is **no dialog** — the target is obvious.
2. **Already open elsewhere** → if another window already shows the exact view that
   would be opened, just **activate that window** instead of loading in place.
3. **Read-only first, edit if seen edited** → the first time a given view is opened
   via this toggle in the session, it opens **read-only**. If that view has already
   been in **edit** mode this session, it opens **editable**.

Default binding: `key,50,alt,canvas,view.toggle_view_type` (keysym 50 = the `2` key).
Action id `view.toggle_view_type`, Tcl-backed by `alt2_toggle_view`. **No new C
logic** — the C change is only keybinding scaffolding (an `ActionDef` row + a default
`InputBinding`); everything else composes existing `xschem` subcommands.

## Building blocks (all already exist)

| need | primitive |
|------|-----------|
| current file / view type | `xschem get schname`; symbol iff `[string match {*.sym} …]` |
| cell identity of a path | `schematic_cellview <abs>` → `{lib cell view layout}` / `{}` |
| views of a cell | `xschem cell_views <lib> <cell>` |
| a view's datafile (→ its type) | `xschem cellview_path <lib/cell> <view>` (`.sym`/`.sch`) |
| flat/unregistered sibling | `[file rootname <cur>].<other-ext>` (the `symbol_view_path` fallback) |
| enumerate open windows + their file | `xschem windows` → `{win_path top_path group xwindow current_name number}` |
| current window path | `xschem get current_win_path` |
| switch context to a window/tab | `xschem new_schematic switch <win_path>` |
| raise a detached toplevel | `raise_activate_toplevel <top_path>` (WSLg-aware) |
| same-window load + save-prompt | `xschem load -gui -inplace [-readonly] {<F>}` |
| modified? / read-only? | `xschem get modified` / `xschem get readonly` |
| modal combobox chooser | mirror `libmgr::newview_dialog` (grab + vwait) |

`-gui` makes the load interactive (enables the save-prompt via `save(1,0)`, whose `-1`
return = user cancelled), `-inplace` opts out of new-window routing so it lands in the
current window. Headless (`--nogui`, `has_x==0`) the prompt is skipped and the load is
in place — so tests never block on the modal.

## Module (`src/alt2_toggle_view.tcl`, namespace `alt2`)

Sourced unconditionally from `xschem.tcl` (next to `library_defs.tcl`) so the action is
available with the default keymap, independent of `cadence_style_rc`.

**Session state** (persists for the process, like `cadence::last_loc`):
```
namespace eval alt2 { variable edited ; array set edited {} }   ;# key = normalized datafile path
```

**Pure, unit-testable seams:**
- `alt2::other_ext {curpath}` → `.sym` if cur is `*.sch` else `.sch`.
- `alt2::default_view {ext}` → `symbol` (`.sym`) / `schematic` (`.sch`).
- `alt2::find_window_for {targetpath curwin windowslist}` → the `win_path` of a row
  (≠ `curwin`) whose normalized `current_name` equals `targetpath`, else `""`.
  (Pure over the `xschem windows` list — testable with a synthetic list.)
- `alt2::views_of_ext {lib cell ext}` → view names of that cell whose datafile matches
  `ext` (via `cell_views` + `cellview_path`; the `mkinst::symbol_views` pattern).

**Impure resolver:** `alt2::target_candidates {curpath}` → list of `{view abspath}` for the
target type. Registered cell → filter `cell_views`; flat/unregistered → the single
`[file rootname]$ext` sibling (empty view name), or `{}` if it does not exist.

**Entry `alt2_toggle_view`:**
```
1. cur = xschem get schname ; guard empty / pristine-untitled.
2. if not read-only  ->  alt2::mark_edited $cur       ;# remember an editable view before leaving it
3. cands = alt2::target_candidates $cur
   - {}                 -> ciw "no <symbol|schematic> view for <cell>"; return
   - 1 candidate        -> chosen = it
   - >1                 -> chosen = alt2::choose_dialog (default alt2::default_view); cancel -> return
4. tpath = normalize(chosen path)
5. win = alt2::find_window_for $tpath [xschem get current_win_path] [xschem windows]
   - win ne ""          -> alt2::activate $win ; ciw "activated ..."; return
6. ro = [info exists edited($tpath)] ? 0 : 1
   xschem load -gui -inplace {-readonly?} {$chosenpath}
   ciw "opened <label> (<read-only|editable>)"
```

**Read-only / edit memory.** The rule "edit iff this view has been edited this session"
is maintained entirely by step 2: whenever the toggle leaves a view that is currently
*editable*, that view's path is added to `edited`. So the starting (editable) schematic,
or a view the user made editable with `Ctrl-2` before toggling away, is remembered and
re-opens editable; a view only ever seen read-only stays read-only. No hooks into
`toggle_readonly` / `make_editable` are needed (the toggle's own step 2 is the funnel).

**Activation.** `alt2::activate {win_path top_path}` = `xschem new_schematic switch
<win_path>` (selects the tab / switches context) and, for a detached toplevel
(`top_path ne "."`), also `raise_activate_toplevel <top_path>`. Guarded so headless
(no Tk) degrades to the context switch.

## Keybinding scaffolding (single-source-of-truth discipline)

1. `src/callback.c` `action_registry[]`: append
   `{ "view.toggle_view_type", NULL, "alt2_toggle_view", "Open the alternate view (schematic⇄symbol) of the current cell" }`
   (mutates=0 — the toggle itself changes no schematic content).
2. `src/callback.c` `init_input_bindings()`: add
   `set_input_binding(DEV_KEY, '2', Mod1Mask, ACTX_CANVAS, "view.toggle_view_type");`
   at the end of the canvas key block (insertion order = csv order).
3. `src/keybindings.csv`: add `key,50,alt,canvas,view.toggle_view_type,` in the **same
   positional slot** — the drift-guard `test_bindings_file.tcl` byte-compares shipped vs
   regenerated.
4. `src/actions.csv`: add a metadata row so `test_keybindings_help.tcl` (every bound id
   has a label) stays green, and the toggle appears on the View menu:
   `view.toggle_view_type,command,view,Toggle schematic/symbol view,Alt+2,alt2_toggle_view,,,Open the alternate view of the current cell,`

Plain `2` (logic level) and `Ctrl-2` (choose layer) still fall through to the C switch —
the DEV_KEY dispatch matches the exact code+mods, so only `Alt-2` is intercepted.

## Edge cases / resolved defaults

- **Current is untitled/empty or not a real cell** → CIW hint, no-op.
- **No view of the target type** (e.g. a schematic-only cell toggled toward a symbol) →
  CIW hint, no-op.
- **Chooser cancelled** → no-op.
- **Target already open in the current window** → not treated as "another window"
  (`find_window_for` excludes `curwin`); it reloads in place.
- **Scope:** the toggle targets the alternate view of the *current cell*; it does not
  descend or cross hierarchy.

## Test plan (RED-first)

Pure (fast): `other_ext`, `default_view`, `find_window_for` (synthetic `xschem windows`
list incl. the exclude-current and no-match cases), `views_of_ext` (real temp lib).

Integration (binary, `--nogui`, temp registered lib — cell `aa` with `symbol`+`sym_alt`
symbol views and a `schematic` view; cell `bb` schematic-only):
- schematic→symbol with two symbol views → `target_candidates` returns both (chooser
  path); with one → resolves directly.
- in-place toggle: `xschem get schname` flips ext; RO-first (`get readonly`==1); after
  marking edited, a re-toggle opens editable (`get readonly`==0).
- `find_window_for` matches a synthetic second window and excludes the current one.
- flat/unregistered sibling resolution.
- Sabotage each branch (green-but-hollow guard): neutering `other_ext`, the RO decision,
  or `find_window_for` must redden the relevant checks.

The actual keypress, the modal chooser, the save-prompt, and cross-window raise are
**GUI-manual** (headless has no Tk); every decision branch is covered headless.
