# instance_update — Instance Update (Xschem port of the S-Edit utility)

Status: spec only (fluid-editing). Author: session 2026-07-19. Pure-Tcl port, no C changes.

This is the Xschem port of the Tanner S-Edit **Instance Update** utility
(`references/instance_update.tcl` (863 lines) + `references/instance_update_usr_guide.md`, both
READ-ONLY — the reference `.tcl` is a design source to study, never a target to modify). It
bulk-**retargets the master** of instances in the current schematic. Every S-Edit primitive is
replaced with a real Xschem verb:

- S-Edit's `find instance -scope … -filter/-modify {script}` engine becomes a Tcl
  **iterate-and-match loop** over the current-sheet instance store (`xschem get instances`).
- S-Edit's split **MasterLibrary / MasterCell** pair becomes Xschem's **single symbol reference**
  (`cell::name`), reverse-mapped to `{lib cell view}` via the LCV registry and re-composed with
  `xschem cellview_path`; the retarget itself is **`xschem replace_symbol`** (there is no
  `setprop cell::name` — see grounding).
- `property get -name Name -system` becomes `xschem getprop instance <N> name`.
- `database cells` → `xschem lib_cells <lib>`; `sed_get_library_names` → `xschem libraries`;
  `sed_get_current_library` → derived from `schematic_cellview [xschem get schname]`.
- `mode renderoff/renderon` becomes the **single-`push_undo` + `replace_symbol … fast` + one
  `redraw`** batch idiom.
- The shadowed-`clipboard`/`clip.exe` hack is dropped for native Tk `clipboard`
  (via `utils/cadence_clip.tcl`).

Related prior art (reuse, do not reinvent):
- `doc/claude/specs/find_helper.md` — the sibling S-Edit port (shipped same session). This spec
  shares its **History**, **Copy**, **read-only Command/Results panes**, **Build/Run**, hierarchy
  guard, and static-brace-safety translation verbatim. Factor the identical History/Copy/read-only
  helpers, do not duplicate them (see *Shared helpers*).
- `utils/select_same_cell.tcl` — `selsame::inst_ident` is the exact per-instance
  `getprop cell::name` → `abs_sym_path` → `schematic_cellview {lib cell view}` reverse-map this port
  needs, plus the `for {i} {i<[xschem get instances]}` enumerate loop.
- `utils/toggle_pins_netlabels.tcl` — the `push_undo` single-undo transaction and the
  `bind .drw <chord> {…; break}` wiring model.
- `utils/lib_mgr_helpers.tcl` — Library/Cell/View helpers (the S-Edit `sed_helpers.tcl` replacement).
- `utils/cadence_clip.tcl` — `cadence::clip_put` (native `clipboard clear/append` + `ciw_echo`).

---

## Goal

A modeless Tk form (`inst_update::show`) that **bulk-retargets the master reference** of a set of
instances on the current schematic sheet. The target set is chosen by an optional **Name regex** +
**Scope** + **From-library** + **From-cell**; the replacement is a **To-library** + **To-cell**. A
**Get** button seeds From-lib/From-cell from the current selection; a **List** button previews the
matching instances read-only; **Build Command** shows the assembled query summary without running;
**Run** performs the retarget and reports each instance as updated or FAILED. History + Copy +
read-only Command/Results panes reuse the find_helper patterns.

The retarget maps to exactly one Xschem verb per instance:
`xschem replace_symbol <index> [xschem cellview_path "<toLib>/<toCell>" <view>] fast`, wrapped in a
single `push_undo` for one-Ctrl-Z atomicity.

## Non-goals

- **No new C verb, no new matching engine.** All matching/iteration/retarget is pure Tcl over
  existing verbs (`xschem get instances`, `getprop`, `cellview_path`, `replace_symbol`,
  `selected_set`, `libraries`, `lib_cells`). A genuinely missing primitive is **deferred**, not
  written in C.
- **No hierarchy-scope mutation, and no hierarchy-scope List.** Xschem verbs act on the **current
  sheet only**; there is no cross-sheet find/`-modify`/enumeration primitive. S-Edit's "List runs on
  hierarchy; Build/Run reset to view; copy the command and hand-edit `-scope hierarchy`" trick has
  **no Xschem engine behind it** — the "built command" here is a Tcl loop over the current sheet, so
  there is nothing to hand-edit into a hierarchy run. `hierarchy` scope is refused (reset to view
  with a warning) for **all three** of Build/Run/List. This is the one faithful divergence from the
  reference and is documented as such (see *Scope & the hierarchy guard*).
- **No verbatim re-runnable command string.** S-Edit echoed the exact `find …` line; Xschem runs a
  Tcl loop, so the Command box shows a faithful **human-readable summary**, not a re-runnable verb.
- **No symbol-view support.** In a `.sym` view there are no schematic instances to retarget; the
  form refuses to run there (mirrors `toggle_pins_netlabels.tcl`).
- **No cross-session persistence** of form state or history.

---

## Object identity & the LCV model (grounding — how S-Edit MasterLibrary/MasterCell maps)

S-Edit stores an instance's master as **two independent, first-class properties**: `MasterLibrary`
and `MasterCell`, each individually gettable/settable with `property get/set -name … -system`.

**Xschem stores no such pair.** An instance's master is a **single symbol reference string**
(`xctx->inst[i].name`, read with `xschem getprop instance <N> cell::name`) — an abs `.sym` path, a
lib-qualified ref like `devices/nand2.sym`, or a legacy flat name. The `{lib cell view}` triple is
**derived** by reverse-mapping that path against the on-disk library layout
(`<libpath>/<cell>/<view>/<cell>.sym`) registered in `library.defs`.

| S-Edit primitive | Xschem analogue |
|---|---|
| `property get -name MasterLibrary -system` | `lindex [schematic_cellview [abs_sym_path [xschem getprop instance <N> cell::name]]] 0` |
| `property get -name MasterCell -system` | element **1** of the same `schematic_cellview` result |
| (S-Edit has no view dimension) | element **2** = the master's **view** (usually `symbol`) — Xschem gains this axis |
| `property get -name Name -system` | `xschem getprop instance <N> name` (the instance refdes / instname) |
| `property set -name MasterLibrary/MasterCell -system -value …` | `xschem replace_symbol <N> [xschem cellview_path "<lib>/<cell>" <view>] fast` (**one** call sets both at once) |
| `sed_get_library_names` | `xschem libraries` → list of `{name path}`; names via `foreach {n p}` |
| `database cells -design <lib>` | `xschem lib_cells <lib>` → sorted cell-name list |
| `sed_get_current_library` | `lindex [schematic_cellview [xschem get schname]] 0`; fall back to first library |
| `workspace getactive` (containing cell, in List) | `lindex [schematic_cellview [xschem get schname]] 1` — **constant** on a single sheet |

**Key consequences to preserve:**

1. **Retarget is ONE verb, not two property-sets.** `setprop instance <N> cell::name …` does **not
   exist** (setprop has no `cell::` branch). The only way to repoint a master is
   `xschem replace_symbol`. So MasterLibrary + MasterCell are **composed together** into one
   symbol-ref argument via `xschem cellview_path "<lib>/<cell>" <view>` and applied atomically.
   S-Edit's split "set library then set cell, share one catch, report half-updates" collapses to a
   single all-or-nothing verb — there is **no half-updated state** (see *Retarget core*).

2. **A VIEW dimension S-Edit lacked.** The master ref encodes lib/cell/**view**. Keep-cell
   migration recomputes the **same cell under a new library** at the **same view** the source
   instance used: `xschem cellview_path "<newLib>/<oldCell>" <view>`. Default view = the source
   instance's own view from the reverse-map, falling back to `symbol` (masters are symbol-type
   views).

3. **Existence is filesystem-checked.** `xschem cellview_path "<lib>/<cell>" <view>` returns `""`
   when that cell/view datafile does not exist on disk. This **is** the S-Edit "changing library
   requires a matching cell to exist" gotcha, made concrete. Validate the returned path is non-empty
   and ends in `.sym` before passing to `replace_symbol` (mirrors `property_form.tcl:1072`); a miss
   becomes a **FAILED** row, not a crash.

4. **replace_symbol may rename the refdes.** The new symbol template's `name` prefix can overwrite
   the instance's refdes first char (`res R1` → `capa C1`). Address every instance in the loop by
   **numeric index**, and re-read `name` only for reporting; never key the loop on a name that the
   swap can change mid-batch.

5. **Reverse-map coverage differs by API.** `xschem get_inst_lcv` (single selected instance) is
   strict (library.defs-registered nested layout only). `abs_sym_path` + `schematic_cellview` is
   permissive (full `library_list`, handles flat layout, returns a 4th `layout` element). For the
   bulk **Get from selection** loop and per-instance identity, prefer the permissive form and
   **skip** unresolvable instances rather than erroring the whole run.

---

## Form layout

```
┌─ Instance Update ─────────────────────────────────────────────────────┐
│ ┌─ Target (which instances) ──────────────────────────────────────┐   │
│ │ Name regex (optional): [__________________]  Scope:[view ▾] [List]│  │
│ │ From library: [mylib          ▾]  From cell: [(none)        ▾][Get]│  │
│ │ From-cell regex: [________________________]  (enabled iff (Regex))│  │
│ └──────────────────────────────────────────────────────────────────┘   │
│ ☑ -goto none  (do not pan/zoom to matches)                            │
│ ┌─ Replacement (new master) ─────────────┐  ┌─ History ──┐            │
│ │ To library: [otherlib          ▾]       │  │ [ ▲ Prev ] │            │
│ │ To cell:    [(n/a - keep cell) ▾]       │  │ [ ▼ Next ] │            │
│ └─────────────────────────────────────────┘  │   3 / 5    │            │
│                                                └────────────┘            │
│ ──────────────────────────────────────────────────────────────────    │
│ [ Build Command ] [ Run ] [ Copy Results ] [ Reset ]         [ Close ] │
│ ──────────────────────────────────────────────────────────────────    │
│ Command:  (read-only — summary of the query that will run)             │
│ ┌──────────────────────────────────────────────────────────────────┐  │
│ │ retarget instance  scope=view  from=mylib/nand2  to=otherlib/keep │  │
│ └──────────────────────────────────────────────────────────────────┘  │
│ Results:  (read-only, scrollable)                                      │
│ ┌──────────────────────────────────────────────────────────────────┐  │
│ │ 3 instance(s) updated:                                          ▲ │  │
│ │   X1   mylib/nand2  ->  otherlib/nand2                            │  │
│ │   X2   mylib/nand2  ->  otherlib/nand2                          ▼ │  │
│ └──────────────────────────────────────────────────────────────────┘  │
│ Status: 3 updated, 0 failed                                            │
└────────────────────────────────────────────────────────────────────────┘
```

The `-goto none` label keeps S-Edit's wording (there is no CLI flag emitted; it is the analogue of
"do not recenter to the matches"). Fonts/comboboxes follow the house idiom (dedicated `Iu*` fonts
via `uiutil::ensure_font`, `ttk::combobox -state readonly`, `option add *TCombobox*Listbox.font
IuEntry`); if `uiutil::ensure_font` is absent, fall back to plain `font create`.

---

## Widgets → Xschem-command mapping

Every widget drives Xschem verbs, **not** S-Edit `find`/`property`/`database`. `<N>` is an instance
index from the enumerate loop.

| Widget | Var | Default | Drives (Xschem) |
|---|---|---|---|
| **Name regex** entry | `::inst_update::nameRegex` | empty | optional `regexp -- $pat [xschem getprop instance <N> name]` narrowing (instname) |
| **Scope** combobox `view`/`selection`/`hierarchy` | `::inst_update::fscope` | `view` | `view` → loop `0..[xschem get instances]-1`; `selection` → loop over `xschem selected_set`; `hierarchy` → **refused** (guard, reset to view) |
| **List** button | — | — | `inst_update::list_matches` — read-only preview of matched instances → Results |
| **From library** combobox | `::inst_update::fromLib` | current lib | `-postcommand` → names from `xschem libraries`; drives the From-cell equality filter |
| **From cell** combobox | `::inst_update::fromCell` | `(none)` | `-postcommand` → `xschem lib_cells $fromLib` fronted by sentinels; the MasterCell equality target |
| **From-cell regex** entry | `::inst_update::cellRegex` | empty | live only when From-cell = `(Regex)`; `regexp -- $re <masterCell>` |
| **Get** button | — | — | `inst_update::get_from_selection` — reverse-map each `xschem selected_set` master → seed From-lib/From-cell |
| **-goto none** check | `::inst_update::gotonone` | **1** | when unchecked, recenter to the first match after the run; checked = no recenter |
| **To library** combobox | `::inst_update::toLib` | current lib | `-postcommand` → `xschem libraries`; first half of the new master ref |
| **To cell** combobox | `::inst_update::toCell` | `(n/a - keep cell)` | `-postcommand` → `xschem lib_cells $toLib` fronted by `(n/a - keep cell)`; second half (or keep) of the new master ref |
| **Build Command** button | — | — | `inst_update::build_only` — assemble + show summary, no execution, no history |
| **Run** button | — | — | `inst_update::run` — snapshot history, retarget via `replace_symbol`, fill Results/Status |
| **Copy Results** button | — | — | `inst_update::copy_results` → `cadence::clip_put` |
| **Reset** button | — | — | `inst_update::reset` (defaults, **keep history**) |
| **Close** button | — | — | `destroy` the toplevel |
| **▲ Prev / ▼ Next** | `::inst_update::histidx` | — | `history_up` / `history_down` |

---

## Sentinels & change-handler rules (preserved verbatim)

Four parenthesized sentinels (parentheses guarantee they cannot collide with real cell/library
names):

| Sentinel | Where | Meaning (Xschem terms) |
|---|---|---|
| `(none)` | From-cell, **default**, first in list | No cell chosen. **Run disabled** (safety catch — you must choose deliberately). Build still works. In **List** it is treated like `(any cell)`. |
| `(Regex)` | From-cell, **second** (easy to reach) | Enables the **From-cell regex** entry. Matches instances whose master cell matches the regex (unanchored partial, anchor with `^…$`). Run stays disabled while the regex text is empty. |
| `(any cell)` | From-cell, **last** (deliberately effortful) | Every instance of the From-library, any cell. Forces To-cell to `(n/a - keep cell)` (library-only migration) until the user deliberately picks a concrete To-cell (many-to-one). |
| `(n/a - keep cell)` | To-cell, **default**, first in list | Library-only migration: each matched instance **keeps its own cell**, only the library changes. Composed as `cellview_path "<toLib>/<perInstanceCell>" <view>`. |

**Change handlers (auto-linkage — ported 1:1):**

- **`on_from_lib_changed`** — the old cell belonged to the old library → reset `fromCell` to
  `(none)` (the safe default); repopulate the From-cell list from `xschem lib_cells $fromLib`;
  refresh Run state; echo `"From library '<lib>': <n> cell(s)"`.
- **`on_to_lib_changed`** — repopulate the To-cell list; **keep** the chosen To-cell iff the new
  library also has it, else fall back to `(n/a - keep cell)`; refresh Run state.
- **`on_from_cell_changed`** — if From-cell = `(any cell)`, force To-cell to `(n/a - keep cell)`
  (library-only retarget unless the user re-picks a concrete To-cell afterwards); refresh Run state;
  if From-cell = `(Regex)`, park the cursor in the now-enabled From-cell regex entry.
- **`refresh_run_state`** — the From-cell regex entry is `normal` iff From-cell = `(Regex)` else
  `disabled`; the Run button is `normal` iff `runnable`.

**`runnable`** (Run-enable predicate, ported): false if From-cell = `(Regex)` and the regex text is
empty; otherwise true iff `fromLib ≠ ""`, `toLib ≠ ""`, `toCell ≠ ""`, `fromCell ≠ ""`, and
`fromCell ≠ (none)`.

**Combobox freshness** — every dropdown re-reads the live database in its `-postcommand`
(`populate_libs` / `populate_from_cells` / `populate_to_cells`), so lists stay current as libraries
or cells are opened/created. `-postcommand` only sets `-values`; it never touches the bound
`-textvariable`, so it is safe after a history recall.

---

## Scope & the hierarchy guard

- **view** — enumerate `for {set i 0} {$i < [xschem get instances]} {incr i}`.
- **selection** — enumerate the names in `xschem selected_set` (brace-quoted instname list), map
  each to its index. Matching happens within the current selection.
- **hierarchy** — **DEFERRED / REFUSED for all actions.** There is no Xschem cross-sheet find,
  `-modify`, or enumeration primitive; the S-Edit "List-only-on-hierarchy + hand-edit the command"
  route cannot exist because the built "command" is a Tcl loop over the current sheet only. The
  combobox still offers `hierarchy` (so the option is visible/documented), but **`hier_guard`**
  resets scope to `view`, writes the explanation into the Results pane, and returns 1; Build/Run/List
  all call it first. The reset+warning mechanism (and message wording) is preserved from the
  reference; the only divergence is that **List no longer gets special hierarchy treatment** — with
  no engine there is nothing for it to traverse. Documented, not silently dropped.

---

## Core logic

### Scratch mapping (`set_scratch` — sentinel → scratch, ported)

Copy widget state into plain scratch vars the loop reads, resolving the sentinels. This is the
faithful port of the reference's `set_scratch`, minus the S-Edit `-system` property names:

```
fltName  = string trim $nameRegex                      ;# "" = no name filter
fltLib   = $fromLib
fltCell  = ($fromCell in {(none) (any cell) (Regex)}) ? "" : $fromCell   ;# "" = any cell
fltCellRe= ($fromCell eq (Regex)) ? string trim $cellRegex : ""          ;# master-cell regex
newLib   = $toLib
newCell  = ($toCell eq (n/a - keep cell)) ? "" : $toCell                 ;# "" = keep each cell
```

At most one of `fltCell` / `fltCellRe` is non-empty; both empty = any cell of `fltLib`.

### Match predicate (`match_inst {i}` — the `-filter` port)

For instance index `<i>`, reverse-map its master once and test:

```
lassign [inst_update::inst_master $i] mlib mcell mview    ;# schematic_cellview reverse-map
if {$mlib eq ""} return 0                                 ;# unresolvable → skip (never match)
if {$fltName ne "" && ![regexp -- $fltName [xschem getprop instance $i name]]} return 0
if {$mlib ne $fltLib} return 0
if {$fltCell   ne "" && $mcell ne $fltCell}                  return 0
if {$fltCellRe ne "" && ![regexp -- $fltCellRe $mcell]}      return 0
return 1
```

`inst_master {i}` = `lassign [schematic_cellview [abs_sym_path [xschem getprop instance $i
cell::name]]] lib cell view` (the `selsame::inst_ident` idiom). **Static, no-interpolation
safety, translated:** the reference guaranteed safety by keeping `-filter`/`-modify` as *static
braced scripts* referencing namespace scratch vars, so a Name/cell regex containing `{ } [ ] $` was
never string-interpolated into an `eval`. Xschem has **no engine to inject a script into** — the
match/retarget is **native Tcl in this file**, and the user's regexes are passed only as **data** to
`regexp` (never `eval`/`subst`). Same guarantee, structurally stronger.

### Retarget core (the `-modify` port — via `replace_symbol`, one undo)

For each matched index, compose the new master ref and swap it. Library-only migration keeps the
per-instance cell; many-to-one uses the concrete To-cell. **Both compose into ONE symbol ref** and
apply with a single verb (no half-updated state possible):

```
proc inst_update::retarget_one {i} {
  lassign [inst_update::inst_master $i] mlib mcell mview
  set cell [expr {$::inst_update::newCell eq "" ? $mcell : $::inst_update::newCell}]  ;# keep vs many-to-one
  set view [expr {$mview eq "" ? "symbol" : $mview}]
  set path [xschem cellview_path "$::inst_update::newLib/$cell" $view]
  set name [xschem getprop instance $i name]     ;# read BEFORE the swap (refdes may change)
  if {$path eq "" || ![string match *.sym $path]} {
    lappend ::inst_update::fails [list $name $mlib $mcell "no such cell/view: $::inst_update::newLib/$cell:$view"]
    return
  }
  if {[catch {xschem replace_symbol $i $path fast} err]} {
    lappend ::inst_update::fails [list $name $mlib $mcell $err]
  } else {
    lappend ::inst_update::hits  [list $name $mlib $mcell $cell]
  }
}
```

**Single-undo transaction (the `mode renderoff/renderon` + atomicity port):** wrap the whole sweep
in **one** `xschem push_undo`, call `replace_symbol … fast` (the `fast` flag skips per-call
push_undo AND action-logging), then `xschem set_modify 1` and one `xschem redraw` at the end
(`replace_symbol` deliberately never redraws). One Ctrl-Z undoes the entire batch — the true
analogue of S-Edit wrapping the atomic op in `mode renderoff`. Balance any `no_undo`-style toggles
in a `catch`-guarded finally.

- **Read-only sheet** — guarded up front (`xschem get readonly` → red Status, abort before any
  mutation). A per-instance `replace_symbol` that still hits the readonly gate lands in `fails` with
  its verb-named message; report it, do not abort silently (S-Edit's half-updated FAILED reporting,
  preserved as per-instance FAILED).
- **Symbol-view guard** — `string match *.sym [xschem get current_name]` → red Status "not
  available in symbol view", abort.

### Get from selection (`get_from_selection` — ported)

Seed From-lib/From-cell from the current selection without disturbing it (`-add` in S-Edit; here we
never call `unselect_all`):

```
foreach nm [xschem selected_set] {
  set i [index of $nm]
  lassign [inst_update::inst_master $i] lib cell view
  if {$lib eq ""} continue           ;# skip unresolvable, do not abort
  collect unique {lib cell} pairs
}
```

- no instances selected → Results "no instance is selected"; form untouched.
- one library, one cell → set both From-lib and From-cell.
- one library, several cells → set From-lib, leave From-cell at `(none)` (pick manually), explain in
  Results.
- multiple libraries → Results "multiple libraries (…) — nothing set"; form untouched.

### List (read-only preview — `list_matches`)

List never mutates, never touches history/undo. It runs the match predicate over the in-scope
indices and reports each match. The reference grouped rows by *containing cell*
(`workspace getactive` inside the hierarchy traversal); on a single Xschem sheet the containing cell
is **constant** (`lindex [schematic_cellview [xschem get schname]] 1`), so grouping collapses — rows
are instead sorted by **instance name** (`lsort -dictionary`), preserving stable, readable order.
Columns:

- when `fltCell` is empty (`(none)`/`(any cell)`/`(Regex)`): `In cell | Instance | Master cell`
  (the master-cell column shows which cells matched — essential in regex mode).
- when a concrete From-cell is chosen: `In cell | Instance` (master cell is redundant — it equals
  the chosen From-cell).

Output → Results box + `ciw_echo`; Status `N matching instance(s)` / `nothing matched`.

### Build / Run

- **Build Command** — `hier_guard`, then `set_scratch`, then `show_cmd [build_summary]`; never
  executes, never pushes history. Status reflects whether Run is enabled.
- **Run** — `hier_guard` (abort if it reset scope), `runnable` gate (abort with the reason — `(none)`
  vs empty regex), then `history_save`, `set_scratch`, `show_cmd`, the single-undo retarget sweep
  over `collect`'s matched indices, then `report_results`.

### Results report (`report_results` — ported)

```
<nhit> instance(s) updated:
  <name>   <oldLib>/<oldCell>  ->  <newLib>/<newCell>
  …
FAILED (unchanged):                       ;# only if nfail > 0
  <name>   <oldLib>/<oldCell> : <error>
```

Status = `"<nhit> updated"` (+ `", <nfail> failed"`); also `ciw_echo`'d. Note the Xschem FAILED line
says "unchanged" (single-verb atomicity — no "partially updated" state, unlike S-Edit's two
property-sets).

---

## History, Copy, read-only panes (shared with find_helper)

These are **behaviourally identical** to `find_helper.md`; factor the common code rather than
duplicating (see *Shared helpers*).

- **History** — `statevars = {nameRegex fromLib fromCell cellRegex toLib toCell fscope gotonone}`.
  `snapshot` → `{var value …}`; `apply_state` restores each var **and** repopulates the dependent
  From/To cell lists (`populate_from_cells`/`populate_to_cells` only set `-values`, so the recalled
  cell selections survive) then `refresh_run_state`. **Run** calls `history_save` before executing;
  **Build and List do NOT push.** Dup-collapse: a snapshot equal to the stack top is not re-pushed.
  `history_up`/`history_down` walk older/newer and clamp; `histidx` parks one past newest after a
  save so the first ▲ Prev recalls the most-recent run. `histlabel` = `k / n` / `n saved` /
  `(empty)`. **Reset preserves history** (clears fields, re-parks the cursor).
- **Copy** — the `clip.exe` workaround is dropped; `copy_results {?t?}` reads the pane's `sel` tag
  (or whole pane) and pushes via `cadence::clip_put`. Both read-only panes preempt the stock copy
  binding (`<<Copy>>`, `<Control-c>`, `<Control-Insert>` → `copy_results %W; break`).
- **Read-only panes** — `set_txt` toggles `-state normal`/`disabled` around a
  delete+insert; `show_cmd` writes the Command box, `set_results` writes the Results box.

---

## Public API (`inst_update` namespace)

| Proc | Purpose |
|---|---|
| `inst_update::show` | Build (or raise) the modeless form. Bound to the keybind. |
| `inst_update::init_fonts` | Create dedicated `Iu*` fonts + combobox-list font. |
| `inst_update::get_libs` | Library names (`xschem libraries` → names, `lsort -dictionary`). |
| `inst_update::get_cells {lib}` | Cell names of a library (`xschem lib_cells $lib`, `lsort`). |
| `inst_update::populate_libs` / `populate_from_cells` / `populate_to_cells` | Refresh combobox `-values` (with sentinels); `-postcommand` targets. |
| `inst_update::on_from_lib_changed` / `on_to_lib_changed` / `on_from_cell_changed` | Combobox change handlers (sentinel/linkage rules above). |
| `inst_update::runnable` / `refresh_run_state` | Run-enable predicate + widget state sync (regex entry, Run button). |
| `inst_update::get_from_selection` | Seed From-lib/From-cell from `xschem selected_set`. |
| `inst_update::inst_master {i}` | `{lib cell view}` of instance `<i>`'s master (reverse-map; `{}` when unresolvable). |
| `inst_update::set_scratch` | Widget state → scratch vars, resolving all four sentinels. |
| `inst_update::match_inst {i}` | The `-filter` port: name-regex + master-lib + master-cell(-regex) predicate. |
| `inst_update::collect` | Enumerate in-scope indices, filter by `match_inst` → matched index list. |
| `inst_update::scope_indices` | Index list for `view` (0..N-1) or `selection` (`selected_set`→indices). |
| `inst_update::retarget_one {i}` | Compose new master ref + `replace_symbol … fast`; fill `hits`/`fails`. |
| `inst_update::hier_guard` | Reset `hierarchy`→`view` + warn; return 1 if it fired. |
| `inst_update::build_summary` | Human-readable query summary line for the Command box. |
| `inst_update::build_only` | Show the summary without running. |
| `inst_update::run` | Guards → history_save → single-undo retarget sweep → `report_results`. |
| `inst_update::report_results` | Format `hits`/`fails` into the Results pane + Status. |
| `inst_update::list_matches` | Read-only preview: collect + sort + tabulate → Results. |
| `inst_update::copy_results {?t?}` | Copy a pane's text (or selection) via `cadence::clip_put`. |
| `inst_update::snapshot` / `apply_state {s}` | `{var value …}` of `statevars` / restore + repopulate cells. |
| `inst_update::history_save` / `history_up` / `history_down` / `hist_update_label` | History stack (dup-collapse, recall, counter). |
| `inst_update::reset` | Restore field defaults (current lib, `(none)`/`(n/a - keep cell)`); keep history. |
| `inst_update::set_txt` / `show_cmd` / `set_results` / `set_status` | Read-only pane + status helpers. |

### Shared helpers (factor, do not duplicate)

`snapshot`/`apply_state`/`history_*`/`hist_update_label`, `copy_results`, and
`set_txt`/`show_cmd`/`set_results` are structurally identical to `find_helper`'s. Prefer a small
shared module (e.g. `utils/formkit.tcl` with generic `formkit::history_*`, `formkit::copy_pane`,
`formkit::set_txt` taking the namespace/widget as an argument) sourced by both forms; if factoring
proves noisy, keep per-file copies but keep them byte-identical in behaviour. Decision locked at impl
time — the spec requires *no duplicated divergent logic*, not a specific file split.

---

## Keybind + `cadence_style_rc` wiring

- New file: `utils/instance_update.tcl` (namespace + procs; `bind .drw <chord> {…; break}` at
  bottom).
- Source it in `src/cadence_style_rc` beside the other utils (after the `find_helper.tcl` source at
  line 156, before the effective `unset _ut` at line 272), using the pre-computed `$_ut`:
  ```tcl
  # Instance Update form (Ctrl+Shift+I). The Tk bind lives inside the util file;
  # see its header for why it is a .drw bind and not a keybindings.csv row.
  source [file join $_ut instance_update.tcl]
  ```
- Keybind — **Ctrl+Shift+I** (mnemonic "Instance"; VERIFIED FREE: keysym I=73 has no `key,73,…` row
  in `src/keybindings.csv`, and no existing `Control-Shift-Key-I` bind in
  `cadence_style_rc`/`xschem.tcl`/`mouse_bindings.tcl`; lowercase `Key-i` = create_instance is a
  different keysym). Shift emits the capital keysym, so bind `Key-I` (uppercase):
  ```tcl
  bind .drw <Control-Shift-Key-I> {inst_update::show; break}
  ```
  `break` stops the chord reaching the generic `<KeyPress>` → `xschem callback` → C dispatcher.
  `clone_canvas_bindings` (`xschem.tcl:13769`) propagates the `.drw` bind to new/detached canvases.
- **Why not keybindings.csv**: rows there dispatch only compiled C `action_registry[]` ids; there is
  no runtime "register a Tcl proc as an action" path (documented at
  `toggle_pins_netlabels.tcl:33-48`). A brand-new Tcl proc must be a `.drw` bind.

---

## RED-first test plan (`tests/headless/test_instance_update.tcl`)

Mirrors `tests/headless/test_add_wire_label.tcl`: `check name got exp` helper, a pure-Tcl **Section
A** (namespace units, no Tk, no document — fail RED before impl exists), then loaded-fixture sections
that build an in-memory schematic and assert via `getprop`/`get instances`/`selected_set`. Footer
prints the sentinel `OVERALL: ok` on all-pass, else a `… : FAIL` line + `OVERALL: notok`. Register in
`tests/run_regression.tcl` `hcases` as `headless/test_instance_update` (`full_audit.sh`
auto-discovers; do NOT touch `cases.txt`). Run one:
`./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_instance_update.tcl`.

### Section A — pure-Tcl units (no engine, RED-first)

1. **`set_scratch` sentinel mapping** — drive the widget vars through every sentinel combination and
   assert the scratch outputs:
   - From-cell `(none)` → `fltCell=""`, `fltCellRe=""` (and `runnable`=0).
   - From-cell `(any cell)` → `fltCell=""`, `fltCellRe=""`; and `on_from_cell_changed` forced
     To-cell to `(n/a - keep cell)`.
   - From-cell `(Regex)` + text `nand.*` → `fltCell=""`, `fltCellRe="nand.*"`.
   - From-cell `nand2` (concrete) → `fltCell="nand2"`, `fltCellRe=""`.
   - To-cell `(n/a - keep cell)` → `newCell=""`; concrete To-cell → `newCell=<cell>`.
   (Sabotage: mapping `(any cell)`→non-empty `fltCell` ⇒ this fails.)
2. **`runnable`** — false for From-cell `(none)`; false for `(Regex)` with empty regex text; false
   when To-lib/To-cell empty; true for a concrete From-cell + To-lib + To-cell; true for `(Regex)` +
   non-empty regex + valid To.
3. **`on_from_lib_changed` reset** — set From-cell to a concrete cell, then change From-lib →
   From-cell snaps back to `(none)` (the old cell belonged to the old library).
4. **`on_to_lib_changed` keep-or-fallback** — To-cell = `foo`; change To-lib to one that *has* `foo`
   → To-cell stays `foo`; change to one that *lacks* it → To-cell falls to `(n/a - keep cell)`.
   (Uses a stubbed `get_cells` so it is document-free.)
5. **`on_from_cell_changed` (any cell) → keep** — set From-cell `(any cell)` → To-cell forced to
   `(n/a - keep cell)`; set `(Regex)` → From-cell regex entry becomes the focus target
   (state check).
6. **`build_summary`** — given a var set, returns the canonical summary string (scope, from
   lib/cell-or-regex-or-any, to lib/cell-or-keep, optional name regex); `(none)`/`(any cell)`/keep
   render as their documented tokens. (Sabotage: reorder tokens ⇒ fails.)
7. **`snapshot`/`apply_state`** — snapshot captures all 8 `statevars`; `apply_state` restores each
   exactly; round-trip identity. (`apply_state`'s cell-repopulate side effect stubbed/guarded so the
   unit is document-free.)
8. **History snapshot/recall + dup-collapse** — push A, push A (collapsed: length 1), push B (length
   2); `history_up` from parked recalls B then A and clamps; `history_down` walks newer and clamps;
   `histlabel` text at each position (`2 / 2`, `1 / 2`, `2 saved`, `(empty)` before any).
9. **`hier_guard`** — `fscope=hierarchy` → guard sets `fscope=view`, returns 1, and writes the
   warning into Results; `fscope=view`/`selection` → returns 0, scope untouched.
10. **Regex-as-data safety** — feed `match_inst`'s predicate (via a small pure helper that takes the
    scratch regex + a candidate string) a `fltName`/`fltCellRe` containing `[ ] { } $` literally and
    assert it matches/doesn't via `regexp` and **never errors/`eval`s** — the transform is `regexp`,
    not `subst`.

### Section B — loaded-fixture units (in-memory schematic)

Fixture: `xschem clear force`, then place a mix of instances whose masters resolve under registered
libraries — several of the **same** master cell (e.g. two `devices/nand2`-style refs, or the repo's
real `devices/*.sym`), one of a **different** cell, at known coords/names (`X1`, `X2`, `X3`). Choose
a To-library/cell pair that **exists on disk** (so `cellview_path` returns non-empty) and one that
does **not** (for the FAILED-existence unit). Reverse-map assertions use `inst_update::inst_master`.

11. **`inst_master` reverse-map** — `inst_master <i>` returns the fixture instance's `{lib cell
    view}`; an instance with an unresolvable ref (planted flat/off-registry) returns `{}`.
12. **`collect` by From-lib/From-cell** — From-lib=<lib> From-cell=<cellA> scope=view → exactly the
    indices whose master is `<lib>/<cellA>`; the different-cell instance is excluded.
13. **`collect` with (any cell)** — From-cell `(any cell)` → every instance of the library
    (all masters under `<lib>`), regardless of cell.
14. **`collect` with (Regex)** — From-cell `(Regex)` + `^nand` → only masters whose cell starts
    `nand`; anchored regex excludes near-miss cells.
15. **`collect` + Name regex** — add a Name regex `X[12]` → narrows the master-matched set to
    instances named `X1`/`X2` (excludes `X3`). (Sabotage: dropping the name test ⇒ X3 leaks.)
16. **Retarget many-to-one** — From `<lib>/<cellA>`, To `<lib2>/<cellB>` (exists) → run; assert each
    matched instance's `inst_master` is now `<lib2>/<cellB>`; `hits` lists `old -> new`; Status
    `N updated, 0 failed`; **ONE** `xschem undo` restores **all** masters (batch atomicity).
17. **Retarget keep-cell (library migration)** — From `<lib>/<cellA>`, To-lib `<lib2>`, To-cell
    `(n/a - keep cell)` → each matched instance's master lib becomes `<lib2>` but its cell is
    unchanged (`cellA`), at the same view. (Sabotage: keep-cell composing a fixed cell ⇒ fails.)
18. **View preserved** — a source instance whose master view is `symbol` migrates to `<lib2>` at
    view `symbol` (element 2 of `inst_master` unchanged).
19. **FAILED (target cell missing)** — To a `<lib2>/<cellX>` that does NOT exist on disk
    (`cellview_path` → "") → the instance lands in `fails` with "no such cell/view…", its master
    unchanged, Status shows `… failed`, and other valid matches still succeed (per-instance failure
    isolation).
20. **refdes-rename robustness** — retarget to a master whose template renames the refdes; the loop
    addresses by index, so all matched instances are retargeted and the `hits` report reads the
    pre-swap name (no instance skipped/double-processed because a name changed mid-batch).
21. **`get_from_selection`** — select two instances of the same `<lib>/<cellA>` → Get sets From-lib
    `<lib>` + From-cell `<cellA>`; select two of *different* cells (same lib) → From-lib set,
    From-cell `(none)`; select instances of *different libraries* → nothing set (Results warns);
    nothing selected → Results "no instance is selected".
22. **scope=selection** — pre-select one matching instance; `collect` scope=selection returns only
    that index (not its unselected same-master sibling).
23. **`list_matches` end-to-end** — From-lib/From-cell over the fixture → Results tabulates the
    matched instances sorted by name; From-cell `(none)`/`(any cell)`/`(Regex)` shows the Master-cell
    column; concrete From-cell omits it; no selection change, no history push, no undo slot consumed.
24. **hierarchy guard (Run & List)** — scope=hierarchy → `run` resets to view + warns + does the
    view-scope run (or aborts per guard-return); assert no cross-sheet mutation and the warning text;
    `list_matches` likewise resets+warns.
25. **readonly guard** — `xschem set readonly 1` → run refuses, no master changed.
26. **symbol-view guard** — load a tiny `.sym` fixture → run/list refuse with the symbol-view
    message.

### Sabotage checks (green-but-hollow guard)

- Map `(any cell)` to a non-empty `fltCell` ⇒ test 1/13 fail.
- Compose keep-cell with a fixed cell instead of the per-instance cell ⇒ test 17 fails.
- Drop the `cellview_path` existence/`*.sym` check ⇒ test 19 mutates/errors instead of a FAILED row.
- Skip the single `push_undo` (per-call undo) ⇒ test 16's one-undo-restores-all fails.
- Make `hier_guard`/readonly/symbol guards no-ops ⇒ tests 24/25/26 mutate and fail.
- Key the loop on instance name instead of index ⇒ test 20 (refdes rename) fails.

---

## Out-of-scope / DEFER (with receipts)

- **Hierarchy-scope retarget AND hierarchy-scope List.** DEFER — no Xschem cross-sheet find,
  `-modify`, or enumeration primitive exists (scout: "HIERARCHY scope must be DEFERRED … the 'built
  command' is a Tcl loop over the current sheet only, so there is nothing to hand-edit into a
  hierarchy run"). Refused (reset to view + warn) at runtime, not silently degraded. The reference's
  hierarchy-List advantage is lost with the engine; revisit only if a hierarchy-iteration verb is
  added in C (separate batch).
- **Verbatim re-runnable command string.** DEFER — Xschem has no single `find`/`retarget` verb to
  echo; the Command box is a human summary (Non-goals).
- **Splitting MasterLibrary and MasterCell into two independent edits.** N/A — Xschem's master is one
  symbol ref set atomically by `replace_symbol`; there is no separate library-only C set, so the
  "half-updated" FAILED state cannot occur (a plus, not a gap).
- **Cross-session persistence** of form state and history.
- **Symbol-view operation** (no schematic instances to retarget there — a different data model).
- **No C changes in this batch** — if any of the above requires a new scheduler verb, it is deferred
  with a receipt rather than adding a `scheduler.c` branch here (pure-Tcl discipline).
