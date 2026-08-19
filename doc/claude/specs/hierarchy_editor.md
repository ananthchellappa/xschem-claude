# Hierarchy Editor (HED) — spec

A Cadence Virtuoso **Hierarchy Editor** work-alike for xschem: a saved, named,
reusable object (the **config view**) that decides, per design and per place in
the hierarchy, *which view of each cell* is used — for descend, for netlisting,
for printing, for simulation — without editing a single `.sch` or `.sym`.

Companion plan: `doc/claude/hierarchy_editor_batch/PLAN.md`.
Related: `doc/claude/specs/text_view_type.md` (the view-type table this extends),
`doc/claude/specs/library_manager_launch.md`, `doc/claude/specs/hi_descend.md`
(the existing one-shot view override), `doc/claude/specs/ase_l.md`.

---

## 0. The one-paragraph version

Today xschem answers "which schematic does this instance expand into?" with a
hardwired if-ladder inside `get_sch_from_sym()` (`src/actions.c:3524`), fed by
two attributes (`schematic=` on the instance, `schematic=` on the symbol) that
live **inside the design files**. Choosing "simulate this block as Verilog-A
instead of schematic" therefore means *editing the design*, and undoing it means
editing it back. Cadence answers the same question with an ordered **view list**
consulted at every node of an expanded hierarchy, overridable per cell, per
instance and per occurrence, all stored in a **separate config cellview** that
the design knows nothing about. This spec brings that model to xschem, keeps
every existing attribute working unchanged, and adds four things Cadence does
not have (§7).

---

## 1. Where xschem stands today

### 1.1 Feature-by-feature

| Cadence HED capability | xschem today | Evidence |
|---|---|---|
| Config is a saved, named, reusable **object** | **absent** | — |
| Config selects the design opened/netlisted | **absent** | — |
| Global **View List** (ordered, searched per cell) | **absent** — order is a hardwired if-ladder | `get_sch_from_sym()` `src/actions.c:3556-3630` |
| Global **Library List** (per-config lib search order) | **partial** — one global ordered path (`XSCHEM_LIBRARY_PATH` → `library_registry`, `abs_sym_path`); not per-config, not overridable per subtree | `src/library_defs.tcl:158`, `src/actions.c:472` |
| Global **Stop List** | **partial, and per-SYMBOL not per-config** — `spice_stop`, `spectre_stop`, `verilog_stop`, `vhdl_stop`, `tedax_stop` symbol attributes; plus `default_schematic=ignore` | `src/spice_netlist.c:671`, `src/verilog_netlist.c:441`, `src/actions.c:3416` |
| Stop/skip by **library** | **partial** — `$xschem_libs` (allow) / `$nolist_libs` / `$noprint_libs` (deny), regex-matched | `check_lib()` `src/netlist.c:585-610` |
| **Cell binding** (all instances of a cell → view X) | **partial** — symbol attribute `schematic=` inside the `.sym`; edits the *library cell*, so it is global to every design that uses it | `src/actions.c:3578` |
| **Instance binding** | **partial** — instance attribute `schematic=` in the parent `.sch`; scoped to that instance **in that cell**, therefore inherited by every occurrence of the parent — not occurrence-specific | `get_sym_name()` `src/actions.c:3141`, `get_additional_symbols()` `src/actions.c:3355` |
| **Occurrence binding** (`/I0/I3/I7`) | **absent** | — |
| **Inherited view list** per subtree | **absent** | — |
| **Inherited stop list** per subtree | **absent** | — |
| Hierarchy **tree browser** | **partial** — `traversal` / `hier_traversal`, a Tk window with one row per instance per level (INSTANCE / SYMBOL / SCHEMATIC + Sym/Sch/Upd buttons) | `src/xschem.tcl:5652-5810` |
| **Table** (flat, unique-cell) view | **absent** | — |
| "View Found" vs "View To Use" as distinct columns | **partial** — the traversal row's entry shows the resolved path and lets you type a replacement | `traversal_setlabels` `src/xschem.tcl:5594` |
| Editing a binding writes the **config**, not the design | **absent** — traversal's `Upd` button rewrites the instance `schematic=` attribute | `src/xschem.tcl:5787` |
| Named/multiple configs per cell (`config_presim`, `config_extracted`) | **absent** | — |
| **Nested** configs (a subcell bound to a `config` view) | **absent** | — |
| Netlist honours the binding | **partial** — instance `schematic=` honoured by symbol cloning | `get_additional_symbols()` `src/actions.c:3355-3500` |
| Descend honours the binding | **yes** for `schematic=`; plus a documented one-shot override | `hi_descend_view_path` `src/actions.c:3559-3566` |
| View types beyond schematic/symbol | **yes, and better factored than Cadence's** — one table, five consumers | `src/library_defs.tcl:232-290` |
| Views enumerable per cell | **yes** | `cell_views` `src/library_defs.tcl:368` |
| ADE-style `switchViewList` / `stopViewList` env vars | **absent** (ASE-L has simulator profiles, no view list) | — |
| Hierarchical PDF export honours a binding | **partial** (same `schematic=` path) | `hier_psprint()` `src/psprint.c:1014-1090` |

Note on the two "partial" binding rows: under `cadence_compat` both of those
mechanisms are **retired** in favour of the config (§3.8) — they are legacy
artifacts, not a foundation to build on. They stay live only for users who have
not opted in.

**Score: xschem has the two leaf mechanisms (a per-symbol override and a
per-instance override) and none of the machinery above them** — no list, no
inheritance, no occurrence scope, no separable object, no editor that edits the
object instead of the design.

### 1.2 The four architectural facts the design must respect

**F1 — Netlisting is per-SYMBOL, not per-occurrence.**
`global_spice_netlist()` loops `for(i=0;i<xctx->symbols;++i)` and emits one
`.subckt` per unique **cell basename** `get_cell(sym[i].name, 0)`, deduped
through `subckt_table` (`src/spice_netlist.c:497-541`). Two occurrences of the
same cell bound to *different* views cannot both be emitted under one subckt
name. Occurrence binding therefore **requires name mangling** — a distinct
symbol entry per distinct binding. This is a hard constraint, not a preference.

**F2 — `get_additional_symbols()` already does exactly that cloning, and is the
insertion point.** For every instance carrying `schematic=`, it synthesises a
new `xctx->sym[]` entry named after the resolved target, copies the base symbol,
records `base_name` and `parent_prop_ptr`, and rewrites the clone's `schematic=`
/ `*_sym_def` attributes (`src/actions.c:3355-3500`). It is called at the head
of every netlister and of `hier_psprint` (11 call sites). **A config binder is a
pre-pass that decides what each instance resolves to; this function is the
machine that materialises it.** No new hierarchy walker is needed for netlisting.

**F3 — At netlist time there is no instance context.** Every netlister calls
`get_sch_from_sym(filename, sym, -1, 0)` — `inst == -1`
(`spice_netlist.c:93,678`, `spectre_netlist.c:538`, `vhdl_netlist.c:531`,
`verilog_netlist.c:445`, `tedax_netlist.c:84`, `netlist.c:1961`). The instance's
identity survives only as fields on the cloned symbol. Corollary of F2: bindings
must be **materialised before** the symbol loop, never looked up inside it.

**F4 — Occurrence keys already exist in one subsystem.**
`hier_hilight_hash_lookup(token, value, path, what)` (`src/xschem.h:2661`) keys
highlight state by hierarchical path, and `xctx->sch_path[CADMAXHIER]`
(`src/xschem.h:1585`) is the live path string. The *concept* is proven in this
codebase; it has simply never reached the binding path.

---

## 2. The object: the `config` view

### 2.1 It is a view, and views are directories

**Naming rule (D14, ruled by the user 2026-08-18): follow the xschem
convention, not Cadence's filename.** The view type is `config`, the default
view name is `config`, and the datafile is `<cell>.cfg` — because every other
view in xschem holds a file named after the cell, and Cadence's `expand.cfg`
would be the single exception that `cell_views`, `cellview_resolve` and every
path helper would need a special case for.

**The rule must stay one-point-changeable.** The strings `config` and `.cfg`
appear **only** in the four view-type procs of `src/library_defs.tcl`
(`view_type_of_ext`, `view_exts_of_type`, `view_type_opener`,
`view_default_name`). Nothing else in the feature — not the HED, not the
resolver, not the scheduler commands, not a test — may hardcode either string;
they ask the table. Renaming the view (to `hierarchy`, or to Cadence's spelling)
is then a two-row edit, which is what "easily updated later" has to mean in
practice. Test **T-P** enforces it by grep.

A config is a cellview like any other:
`<lib>/<cell>/<configview>/<cell>.cfg`. It is created, listed, copied, renamed
and deleted by the Library Manager with **no Library-Manager changes**, because
`cell_views` (`src/library_defs.tcl:368`) enumerates any subdir holding
`<cell>.<ext>` and `library_new_view` (`:1025`) already switches on view type.

Adding the type is the same one-row change the `text` type was
(`doc/claude/specs/text_view_type.md`): four procs in `src/library_defs.tcl`.

| proc | row to add |
|---|---|
| `view_type_of_ext` | `.cfg { return config }` |
| `view_exts_of_type` | `config { return {.cfg} }` |
| `view_type_opener` | `config` → new opener `hed` |
| `view_default_name` | unchanged (name == type) |

`libmgr::view_handler` (`src/library_manager.tcl:448`) gains a `hed` branch:
open the Hierarchy Editor on that config. `library_new_view` gains a `config`
seed arm writing a valid empty config (never a zero-byte file — the loader must
not need an empty-file case).

**New View launches its tool (ruled by the user 2026-08-18).** Library Manager
right-click → *New view…* already prompts for a name and a type
(`libmgr::ctx_new_view`, `:1233`) and creates the view, but stops there —
`libmgr::do_new_view` (`:1241`) refreshes, selects and logs, and the user is
left looking at a list row. It must instead **open the new view in its tool**,
for every type, routed through the one table:

| type created | tool that opens |
|---|---|
| `schematic` | the schematic editor |
| `symbol` | the symbol editor |
| `verilog`, `veriloga`, `text` | the text editor |
| `state` | the ASE-L state window |
| **`config`** | **the Hierarchy Editor** |

This is `view_type_opener` doing exactly what it was built for, so the change is
one call at the end of `do_new_view` — **not** a `switch` on type, which would
be a sixth copy of the table the `text_view_type` spec was written to prevent.

Note this changes behaviour for view types that already exist, not only for
`config`. That is intended and was asked for; it gets its own item and its own
test (T-Q) rather than riding along on the config work. The action-log line must
stay a single replayable `do_new_view` — a replay must create the view without
also spawning an editor, the same rule `open_text_view` follows at `:459`.

`lib_qualified_abs` must **not** divert `.cfg` to a symbol; add it beside the
`verilog`/`veriloga`/`text` arms.

### 2.2 File format

Text, line-oriented, greppable, diffable, and readable by `git diff` — the same
argument that made `expand.cfg` readable in OA. **Not Tcl `source`d** (a config
is data that may arrive from elsewhere; sourcing it is arbitrary code execution).

```
xschem_config 1
# <cell>.cfg — Hierarchy Editor config view

topcell    <lib> <cell> <view>
description {free text, one Tcl-quoted word}

global viewlist  {schematic veriloga verilog spice symbol}
global stoplist  {veriloga verilog spice}
global liblist   {mylib devices}

# cell <lib> <cell> <key> <value>
cell   mylib opamp  view      veriloga
cell   mylib opamp  viewlist  {veriloga schematic}
cell   mylib bandgap stoplist {spice}

# inst <occurrence-path> <key> <value>
inst   /I0/I3      view      schematic
inst   /I0/I3/I7   viewlist  {extracted schematic}
inst   /I5         stoplist  {veriloga}
```

Rules:
- First line is the magic + integer format version. A loader that does not know
  the version **refuses and says so**; it never guesses.
- Unknown `global`/`cell`/`inst` keys are **preserved verbatim on save** and
  ignored on load (forward compatibility: an older xschem must not silently
  delete a newer key).
- Every list value is a Tcl list; every free-text value is Tcl-quoted.
- Order of `cell`/`inst` records is not significant; the writer emits them
  sorted (stable diffs).
- No occurrence path may be empty; the top cell is `/`.

### 2.3 Occurrence path syntax

`/` = top cell. Below that, `/`-joined **instance names** as they appear in the
parent (`xctx->inst[].instname`), e.g. `/x1/xamp/m1`. Vector instances use the
expanded single element, `/x1[3]/xamp` — matching `descend_hierarchy`'s existing
convention (`src/xschem.tcl:5942`), which already splits on `.` and resolves
`xlev1[3:0]` to the indexed element. **Decision D6 in §8** covers `.` vs `/`.

---

## 3. The resolver

### 3.1 Inputs at one node

Resolving instance *I* of cell *C*, at occurrence path *P*, under config *K*:

```
occurrence bindings   K.inst[P]           .view / .viewlist / .stoplist / .lib
cell bindings         K.cell[lib,C]       .view / .viewlist / .stoplist / .lib
inherited lists       nearest ancestor of P that set viewlist/stoplist
global lists          K.global            viewlist / stoplist / liblist
design attributes     instance schematic= , symbol schematic=      (legacy)
```

### 3.2 Precedence — highest first

1. `hi_descend_view_path` — the existing one-shot, single-use descend override
   (`src/actions.c:3559`). Untouched, still wins over everything.
2. **Occurrence binding** `inst <P> view <V>`.
3. **Cell binding** `cell <lib> <C> view <V>`.
4. **Design attribute** — instance `schematic=`, then symbol `schematic=`.
   **Present only when `cadence_compat` is unset.** Under `cadence_compat` this
   rank does not exist: the attribute is ignored and §3.8 warns about it.
   *(Decision **D1**, ruled by the user 2026-08-18. This rank is the one thing
   Cadence has no equivalent for — see FAQ Q49 and §8.)*
5. **View list walk** — the effective view list at *P*: the nearest ancestor
   occurrence or cell override, else `global viewlist`. The first name in the
   list for which the cell has an existing view wins.
6. **Legacy fallback** — today's `get_sch_from_sym()` tail exactly as written
   (`cellview_sch_path` → `search_schematic` → `abs_sym_path(name,".sch")`).

**Rule NO-CONFIG-NO-CHANGE:** with no config loaded, ranks 2/3/5 are empty and
the ladder collapses to 1 → 4 → 6, which is byte-for-byte today's behaviour.
This is a testable invariant, not an aspiration (§9, T-A).

### 3.3 Inheritance

`viewlist` and `stoplist` set on a node apply to **that node and everything
below it**, until another node overrides. Resolution of the effective list at
*P* walks *P*'s ancestors from nearest to root, then falls back to global. A
cell binding's list applies at every occurrence of that cell **and below**, but
loses to an occurrence binding on a longer prefix.

### 3.4 Stop list

If the view a node resolved to is named in the effective **stop list** at that
node, the expander does **not** descend below it and the netlister treats it as
a leaf.

**One list, all five formats** (**D2**, ruled by the user 2026-08-18). SPICE,
Spectre, Verilog, VHDL and tEDAx all read the same list. This is what Cadence
does, and at config level one answer is the answer you want.

**The per-symbol `*_stop` attributes keep working and apply on top.** A node
stops if *either* the config's stop list names its view *or* the symbol carries
the format's own `spice_stop` / `spectre_stop` / `verilog_stop` / `vhdl_stop` /
`tedax_stop` (`src/spice_netlist.c:671`, `src/verilog_netlist.c:441`, and
siblings). The relationship is **OR, never override**: a config can add a reason
to stop, it can never talk a symbol out of stopping. That asymmetry is
deliberate — a symbol that declares itself a leaf for SPICE usually has no
schematic worth descending into, and a config that forced a descent would
produce a broken netlist, not a different one. This rule is unaffected by
`cadence_compat` (§3.8): `*_stop` is not a view selection.

*Implementation note, not a feature:* the accessor of §5 takes a **dotted key**
(`stoplist`, and syntactically `stoplist.<format>`), and the parser preserves
unknown keys (§2.2). v1 ships and documents exactly one list and the GUI shows
exactly one field. This costs nothing now and means a later per-format list, if
one is ever wanted, is a phase rather than a format change.

### 3.5 Library binding

`lib` on a cell or occurrence binding redirects which library the cell is taken
from; `global liblist` reorders the search. Both are resolved before the view
walk. Implemented over `library_registry` / `abs_sym_path`, not by mutating
`XSCHEM_LIBRARY_PATH` (which is process-global and would leak across windows —
see the memory note on that variable's trace gotcha).

### 3.6 Output of a resolution

```
{ path  view  viewname  found  stopped  source  mangled_name }
```
- `path` — absolute file the node expands into (or "" if unresolvable)
- `viewname` — the view *name* chosen (for the "View Found" column)
- `found` — 1 if that file exists
- `stopped` — 1 if the stop list applies here
- `source` — which precedence rank produced it (for the GUI's provenance column
  and for `-d 1` diagnosis)
- `mangled_name` — the synthetic symbol name when the binding differs from the
  cell's default (F1/F2); empty otherwise

### 3.8 `cadence_compat`: the config is the only mechanism

`cadence_compat` (`tclgetboolvar("cadence_compat")`, set by
`src/cadence_style_rc:40`) is the direction this editor is going, and under it
the property editor is a structured per-field form — `edit_prop` delegates
unconditionally to `slickprop::edit_form` (`src/xschem.tcl:12332`), the raw text
box surviving only as `edit_prop_legacy` for rollback. There is no way to
*author* a `schematic=` attribute through it: the form preserves property tokens
it does not own verbatim (`src/property_form.tcl:278,293`) but offers no way to
add a new one.

So under `cadence_compat`:

- instance `schematic=` and symbol `schematic=` are **ignored** — rank 4 of
  §3.2 is absent;
- `default_schematic=ignore` is **still honoured** (it suppresses netlisting of
  a symbol's own definition; it selects nothing, so it is not a binding);
- `spice_sym_def` / `spectre_sym_def` / `verilog_sym_def` / `vhdl_sym_def` are
  **still honoured** — they supply a *body*, not a view selection, and a config
  has no way to express one. A cell whose resolved view is its own symbol with a
  `*_sym_def` netlists from that definition exactly as today.

**The ignored-attribute warning.** Every netlist run under `cadence_compat`
collects the instances and symbols whose `schematic=` it ignored and reports
them — once per run, at the end, to both the log and the CIW (`ciw_echo`, never
`puts` — the CIW feedback-channel rule):

```
WARNING: cadence_compat: 5 `schematic=` attributes ignored (config view governs)
  /x2         comp3.sym   schematic=comp3_parax.sch
  /x3         comp3.sym   schematic=comp3_pex
  /x4         comp3.sym   schematic=comp3_pex2
  /x5         comp3.sym   schematic=comp3_empty.sch
  comp3b.sym  (symbol)    schematic=comp3_alt.sch
  Bindings > Import converts these into config bindings.
```

Silence here would turn a parasitic-annotated block back into an ideal one with
no signal to anyone. The same list is what `Tools → Validate Config` reports and
what `Bindings → Import` (§7.1) consumes.

**With `cadence_compat` unset nothing changes** — the ladder is byte-for-byte
today's, no warning is emitted, and T-A covers it.

### 3.7 Subckt name mangling (F1)

When two occurrences of cell *C* resolve to different views, the netlist needs
two bodies. The clone's name is `<cell>__<viewname>` by default, with the
un-suffixed name reserved for whichever binding is the **cell-level** one (so a
design with a single global override produces the *same* names it does today).
Collision with a real cell named `<cell>__<viewname>` is detected and a numeric
suffix appended. **D3** in §8 covers the mangling scheme.

---

## 4. GUI

### 4.1 Broad strokes — the partitions

One toplevel, `.hed`, six horizontal bands top to bottom:

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1  MENUBAR      File   Edit   View   Bindings   Tools   Help          │
├──────────────────────────────────────────────────────────────────────┤
│ 2  TOP CELL     Config: [lib▾][cell▾][config▾]                        │
│                 Top:    [lib▾][cell▾][view▾]      [Open] [Update]     │
├──────────────────────────────────────────────────────────────────────┤
│ 3  GLOBAL BINDINGS                                    ▾ (collapsible) │
│     Library List [                                          ]         │
│     View List    [                                          ]         │
│     Stop List    [                                          ]         │
│     Description  [                                          ]         │
├──────────────────────────────────────────────────────────────────────┤
│ 4  HIERARCHY          ⟨Tree⟩ ⟨Table⟩            (ttk::notebook)       │
│    ┌──────────────────────────────────────────────────────────────┐   │
│    │ Instance │ Library │ Cell │ View Found │ View To Use │ Inh.   │   │
│    │          │         │      │            │             │ View   │   │
│    │          │         │      │            │             │ List   │   │
│    │ ▼ /      │ mylib   │ top  │ schematic  │             │ (glob) │   │
│    │   ├ x1   │ mylib   │ amp  │ veriloga   │ veriloga    │ (inh)  │   │
│    │   └ x2   │ devices │ res  │ ─ stopped ─│             │        │   │
│    └──────────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────────────┤
│ 5  BINDINGS       ⟨Cell Bindings⟩ ⟨Instance Bindings⟩  (ttk::notebook)│
│    ┌──────────────────────────────────────────────────────────────┐   │
│    │ Library │ Cell │ View To Use │ Inh. View List │ Inh. Stop List│   │
│    └──────────────────────────────────────────────────────────────┘   │
│                                              [+] [−] [Clear all]      │
├──────────────────────────────────────────────────────────────────────┤
│ 6  STATUS       "24 cells, 3 bound, 1 unresolved"                     │
└──────────────────────────────────────────────────────────────────────┘
```

Bands 3, 4 and 5 are the three panes of a vertical `ttk::panedwindow` so the
user can give the tree the whole window. Band 3 collapses to a one-line summary.

**Widget doctrine, from what this repo already does:** `ttk::treeview` with
`-columns` for every table (Library Manager `src/library_manager.tcl:101`, ASE
`src/ase_window.tcl:659`, copy form `src/copy_form.tcl:349`); `ttk::panedwindow`
for resizable splits; a `ttk::label -relief sunken` status bar; fixed bottom
bars packed **before** the expanding centre widget (the bug documented at
`src/library_manager.tcl:78`). No new palette — reuse the Library Manager's.

### 4.2 Band 1 — menus

| menu | items |
|---|---|
| **File** | New Config… · Open Config… · Save · Save As… · Recent Configs ▸ · Open Top Cellview · Close |
| **Edit** | Undo / Redo (binding edits) · Cut/Copy/Paste binding · Delete Binding · Clear All Bindings |
| **View** | Tree / Table (radio) · Expand All · Collapse All · Show Only Bound · Show Only Unresolved · Show Provenance column · Update (`Ctrl+U`) |
| **Bindings** | Set Cell View · Set Instance View · Set Inherited View List… · Set Inherited Stop List… · Set Library… · Delete Binding · Promote Instance→Cell · **Import from design attributes** · **Export to design attributes** |
| **Tools** | Validate Config · Diff Against Config… · Netlist With This Config · Open in Library Manager · Where-Used |
| **Help** | Hierarchy Editor Help |

The two **Import/Export from design attributes** items are the migration path
and a genuine improvement over Cadence (§7.1).

### 4.3 Band 4 — the tree

Columns (all toggleable, order fixed):

| column | content |
|---|---|
| Instance | tree column; occurrence name; root shows `/` |
| Library | resolved library |
| Cell | cell name |
| View Found | the view the resolver chose |
| View To Use | editable — combobox of `cell_views` for that cell, plus `<none>` |
| Inh. View List | effective list here; parenthesised when inherited, plain when set here |
| Inh. Stop List | same |
| Provenance | which precedence rank fired (§3.6 `source`) — off by default |
| Count | number of occurrences of this cell (Table tab only) |

Row states, by tag: **bound** (bold), **inherited** (normal), **stopped**
(dimmed, no expander), **unresolved** (red foreground, `<view not found>` in
View Found), **generator** (italic — `is_generator()` targets are opaque).

Right-click menu = the **Bindings** menu, retargeted at the clicked row —
same pattern as `libmgr::ctx_post` (`src/library_manager.tcl:141`).

Double-click a row = open that cellview (the Library Manager's `open_view`
behaviour, honouring `view_type_opener`).

**Tree vs Table:** Tree = occurrence hierarchy, the only place instance bindings
can be made. Table = one row per unique (lib, cell), the only place a bulk cell
binding is convenient. Same columns, same right-click menu.

### 4.4 Band 5 — the binding tables

Two tabs, each a flat editable list of what is actually **stored in the config**
— as opposed to band 4, which shows what was *resolved*. This split is the
single most useful thing in Cadence's HED and must not be collapsed: a user
needs to see "the six things I chose" separately from "the four hundred things
that follow from them".

Editing a cell here and pressing Update re-resolves band 4.

### 4.5 Update semantics

The tree does **not** auto-re-expand on every keystroke. `Update` (`Ctrl+U`,
toolbar, and the View menu) re-runs the expander. Stale state is shown
explicitly: the status bar reads `bindings changed — press Update` and the tree
is dimmed. *(Cadence behaves the same way, for the same reason: expansion is
expensive.)* Auto-update on binding change is a preference, default off — **D7**.

### 4.6 Launch points

**No keyboard accelerator** (**D8**, ruled by the user 2026-08-18). Virtuoso
ships none for its Hierarchy Editor, xschem's Library Manager — the closest
sibling tool — has none either, and `Ctrl+Shift+H` turns out to be *make
schematic from selection* (`src/xschem.tcl:17307`). Four ways in:

1. **Tools → Hierarchy Editor** on the main menubar. **Pre-filled**: if the
   window is showing a schematic, the Config *Library* and *Cell* fields open
   already set to the current cell, and the Top Cell fields to the current
   lib/cell/view. The user picks a config name (or *New…*) and nothing else.
   With no current cell — an untitled window — the fields open empty.
2. **Command palette**, via an `actions.csv` row, so it is searchable by name
   and remappable by anyone who does want a key.
3. **Library Manager**: double-click a `config` view; and *New view…* of type
   `config` opens it on the view it just created (§2.1).
4. **`xschem hierarchy_editor [<lib>/<cell>/<config>]`** — the same
   `libmgr::open`-style optional-LCV argument, for scripts and the action log.

The existing **Simulation → Changelog from current hierarchy** and the
`traversal` window stay where they are; the HED does not replace them (**D9**).


### 4.7 Binding a schematic window to an HED

Everything in §4.8–§4.10 stands on one idea: a schematic window can be **bound**
to a Hierarchy Editor window.

A binding is created when the HED opens the design — the `Open` button in band 2,
`File → Open Top Cellview`, or a double-click on a tree row that opens a
cellview. It survives closing and reopening the schematic *through that HED*:
close the schematic editor window, go back to the HED, press `Open`, and the new
window is bound again. It is destroyed when either window closes.

Stored as a Tcl array in the HED's namespace, keyed by the schematic window's
`win_path`: `hed::bound(<win_path>) = <hed toplevel>`. One schematic window has
at most one HED; **one HED may own several schematic windows** (you descend into
two blocks in two windows, both still mirror into the same tree).

A window that is *not* bound behaves exactly as it does today: no mirror, no
locate, no extra context-menu entries, no cost. Everything below is inert
until a binding exists — which is also how it stays free for users who never
open the HED.

Whether more than one HED window may exist at a time is **D15** in §8; the
default is yes, one per config being edited, because "that HED instance" only
means something if there can be more than one.

### 4.8 Live mirror — schematic → Tree view, one way only

**The Tree view follows the schematic. The schematic never follows the tree.**

When the bound schematic window changes what it is showing or what is selected,
the HED's Tree view immediately:

- expands the path down to the current location and scrolls it into view;
- selects the row for the currently selected instance, if one is selected;
- otherwise selects the row for the cell currently being displayed.

Descending into an instance therefore walks the tree open one level at a time,
in step with the editor. Ascending collapses nothing (an expanded subtree stays
expanded — the user opened it) but moves the selection back up.

**The reverse does not happen.** Clicking, expanding or collapsing rows in the
HED changes only the HED. It does not descend the schematic, does not change the
displayed cell, and does not change the schematic's selection. This asymmetry is
deliberate and is the whole point: the tree is an *instrument*, not a second set
of navigation controls competing with the editor's own. A two-way mirror would
make every idle click in the tree a navigation event.

**How the notification works.** No selection-change hook exists in the C core
today, and adding a `tcleval` at every site that touches `xctx->sel_array` would
fire hundreds of times inside one rubber-band drag. Instead:

1. C sets a **dirty flag** (`xctx->hier_mirror_dirty`) at the few authoritative
   points where the answer can actually change: selection set/clear, the tail of
   `descend_schematic()` / `go_back()`, `load_schematic()`, and window/tab switch.
2. **One flush** at the tail of `callback()` — after the event is fully handled —
   emits a single notification per event:

   ```
   hed::notify <win_path> <sch_path> <selected-instname-or-empty>
   ```

3. The flush is skipped entirely when no window is bound, so an unbound session
   pays one integer test per event and nothing else.

`xctx->sch_path[]` is dot-separated with a trailing dot (`.x1.xamp.`, built at
`src/actions.c:4039-4042`); the config's occurrence paths are `/`-separated
(§2.3, **D6**). The translation between them is one helper, the same one item 1.7
already owes, and it is the **single point** where D6 could be reversed.

### 4.9 Locate — from the schematic to the Table row

The other direction, on demand: a keypress in the bound schematic window brings
the corresponding **cell's** row into focus in the HED.

- If the HED is in **Tree** view it **switches to Table** view. Locate is always
  a Table-view operation — Table is the one-row-per-cell view, and "which cell am
  I looking at" is a cell question, not an occurrence question.
- The row is selected and scrolled into view, exactly as if it had been clicked.
- **With an instance selected**, the target is the cell **that instance is an
  instance of**.
- **With nothing selected**, the target is the cell whose schematic is currently
  displayed.
- Unbound window, or the cell is not in the expanded hierarchy: say so on the
  schematic's status bar and do nothing.

Together with §4.8 the two directions are complementary and never fight: the
**mirror** drives the **Tree** continuously and automatically; **locate** drives
the **Table** on demand and explicitly.

**The key.** Cadence users reach this with `Ctrl-I` (a SKILL-built utility, not a
stock binding). **`Ctrl+I` is not available here** — it is *insert symbol*
(`src/callback.c:7590`), core and frequently used, and taking it would be a
regression for every user who never opens the HED. The default is therefore
**`Ctrl+Shift+L`** ("Locate"), which is free, with the action registered in
`actions.csv` so anyone who wants `Ctrl-I` can rebind it in one row. That choice
is **D16** in §8.

Note this is the one accelerator the feature claims; D8's "no accelerator" ruling
was about *launching* the HED, which is a once-a-session act. Locate is a
mid-edit gesture used many times an hour, which is exactly the distinction that
makes a key worth spending.

### 4.10 Set the view from the schematic — beyond Cadence

Right-click an instance in a **bound** schematic window and the context menu
carries a **`View ▸`** entry listing every view that cell actually has
(`cell_views`), with the currently-resolved one marked. Picking one writes the
binding and the HED updates.

- **It writes an occurrence binding** for that instance at its current place in
  the hierarchy — the narrowest, least surprising scope, and the one the user
  was pointing at. Widening it to every instance of the cell is what the HED's
  existing **Promote Instance→Cell** (§4.2 Bindings menu) is for; there is no
  second cascade for it.
- The entry appears **only** when the window is bound and exactly one instance is
  selected. Unbound windows see today's menu, unchanged.
- The instance's drawing does not change — the symbol is the same. What changes
  is descend and netlisting. The schematic's status bar says what was written,
  and the HED goes stale (§4.5) rather than silently re-expanding.
- Not gated by `cadence_compat`: this writes the *config*, never a design
  attribute, so it is the sanctioned replacement for the `schematic=` typing that
  §3.8 retires.

**Mechanical note.** `context_menu` (`src/xschem.tcl:14956`) is a hand-rolled
`overrideredirect` toplevel of plain `button` widgets returning integer codes
through `tctx::retval` to `context_menu_action()` (`src/callback.c:5144`) — it is
not a Tk `menu` and has **no cascade support**. A `View ▸` submenu therefore means
building a second popup beside the first, including its own leave/dismiss
handling alongside the existing `close_ctxmenu_on_leave` logic. The alternative
is a flat run of `Set view: <name>` buttons inline. That is **D17** in §8;
the default is the cascade, because it is what was asked for and because a cell
with six views would otherwise add six rows to a menu that is already long.

---

## 5. Engine integration

Five consumers must honour the active config. Each is a separate partition in
the plan because each can be shipped and verified alone.

| # | consumer | entry point | what changes |
|---|---|---|---|
| C1 | **Descend** (`e`, Ctrl+E, hi_descend, Alt-2) | `get_sch_from_sym()` `src/actions.c:3524` | the if-ladder becomes a call to the resolver; occurrence path is `xctx->sch_path[]` + the target instname |
| C2 | **Netlist** (all 5 backends) | `get_additional_symbols(1)` `src/actions.c:3355` | a pre-pass materialises config-derived `schematic=`/mangled names into the clone set; the symbol loops are untouched (F2) |
| C3 | **Hierarchical print** | `hier_psprint()` `src/psprint.c:1014` | same pre-pass; already calls `get_additional_symbols` |
| C4 | **ASE-L / simulation** | `doc/claude/specs/ase_l.md` | the ASE state's `design` gains an optional `config` field; running a sim activates it for the netlist and deactivates after |
| C5 | **Library Manager / view opener** | `libmgr::view_handler` | `config` type opens the HED |

**The active config is per-`xctx`** (per window/tab), not global — multiple
windows each netlisting under a different config is the whole point. It is
stored as a path + a parsed in-memory dict, and it is **not** part of the undo
stack (a config is not design data).

`xschem` subcommands to add (dispatcher `scheduler.c`, letter-bucketed —
`doc/claude/specs/`, memory `scheduler-letter-dispatch`):

```
xschem config load <path>            -> "" | error
xschem config save [<path>]
xschem config unload
xschem config get <path|topcell|description|dirty>
xschem config global <viewlist|stoplist|liblist> [<value>]
xschem config cell <lib> <cell> <key> [<value>]
xschem config inst <occpath> <key> [<value>]
xschem config resolve <occpath>      -> the §3.6 dict
xschem config expand [<maxdepth>]    -> the whole tree, flat, one row per line
xschem config import                 -> lift design schematic= attrs into bindings
xschem config export                 -> write bindings back as design attrs
```

`config expand` is the **only** thing the GUI calls to build band 4. Keeping the
expander in C, not Tcl, is what makes it fast enough to press Update freely —
and it means the batch's GUI work cannot be blocked on expander performance.
**D4** in §8 covers C-vs-Tcl for the expander.

---

## 6. The expander

Walk from the top cell. At each node: resolve (§3), emit a row, and unless
`stopped`, recurse into the resolved schematic's instances.

It must **not** drive the editor. The existing `hier_traversal`
(`src/xschem.tcl:5712`) does a real `xschem descend` + `go_back` per subcircuit
with `no_draw 1` — correct but far too slow to sit behind an Update button on a
real design. The HED expander reads instance records out of the `.sch` files
directly (the same scan `sym_vs_sch_pins()` already does, `src/netlist.c:1930`),
caches by file+mtime, and never touches `xctx`'s loaded schematic.

Guards:
- depth capped at `CADMAXHIER`;
- a visited-set on (resolved path, occurrence) breaks recursive designs and
  reports them as `unresolved: recursion` rather than hanging;
- vector instances expand to their elements only when the tree node is opened
  (an `x[63:0]` bus of blocks must not cost 64 subtrees on Update);
- rows are produced lazily per expanded node in Tree mode, eagerly in Table mode.

---

## 7. Where we go beyond Cadence

These are not decoration — each answers a complaint the Cadence flow actually
generates.

**7.1 Import / Export against design attributes.**
Cadence's config and the design are hermetically separate, so an existing
design full of ad-hoc bindings cannot be turned into a config, and a config
cannot be flattened back for a tool that does not read configs. `config import`
lifts every `schematic=` attribute in the expanded hierarchy into equivalent
cell/occurrence bindings; `config export` writes the resolved bindings back as
attributes. Import is the migration path for every existing xschem design;
export is the escape hatch. Both are reversible and both are diffable.

**7.2 Provenance column.**
Cadence shows you *what* a cell bound to and makes you infer *why*. The
Provenance column names the precedence rank that fired (§3.6 `source`), so
"why is this still schematic?" is one glance, not a bisect. Mirrors the
`-d 1` reason lines this codebase already writes for the viewer hijack
(`doc/claude/issues/0172`).

**7.3 Config diff.**
`Tools → Diff Against Config…` shows two configs' resolutions side by side and
lists only the cells that resolve differently. The routine real-world question
("what actually changes between presim and postlayout?") has no answer in
Cadence short of opening both and reading.

**7.4 Validate.**
`Tools → Validate Config` reports, in one pass: bindings that match no cell in
the expanded hierarchy (typo detection — Cadence silently ignores these), views
named in a view list that no cell in the design has, stop-list entries that
never fire, occurrence paths that no longer exist after a design edit, and
cells that resolved to `<view not found>`.

**7.5 Set the view from the schematic (§4.10).**
In Virtuoso, changing a binding means leaving the schematic, finding the row in
the HED, and coming back. Here the instance you are looking at is the instance
you right-click, and the view list you are offered is the one that cell actually
has. The binding still lands in the config, so nothing about the design changes
— it is a shortcut into the config, not a way around it.

**7.6 Text-first, git-first.**
The config is a text file in a view directory that `library_git.tcl` already
version-controls. A config is reviewable in a pull request. `expand.cfg` is
nominally text too, but nothing in the Virtuoso flow encourages treating it that
way.

---

## 8. Design decisions that can change

**These are the seams the work-breakdown is partitioned along.** Each names the
items that must be redone if the decision is reversed. Record any change in the
batch ledger's rulings table, then amend this section.

| # | decision | default | if reversed, redo |
|---|---|---|---|
| **D1** | Where design attributes (`schematic=`) rank against config bindings | **RULED 2026-08-18 (user):** under `cadence_compat`, **ignored entirely** + warned (§3.8); with it unset, unchanged from today | resolver items (P2), warning item (P5) |
| **D2** | Stop list: one list, or one per netlist format | **RULED 2026-08-18 (user):** **one list for all five formats**; per-symbol `*_stop` still fires, OR-ed on top, never overridden | format model item (P2), file format (P1), GUI band 3 (P4) |
| **D3** | Subckt name mangling scheme when bindings diverge | `<cell>__<viewname>`, cell-level binding keeps the plain name | netlist integration (P5) only |
| **D4** | Expander in C (`xschem config expand`) or Tcl | **C** | expander item (P3) + every GUI item's data source (P4) — this is why P3 lands before P4 |
| **D5** | Config file format: line-oriented text vs Tcl dict vs JSON | **line-oriented text** (§2.2) | loader/saver items (P1) only; everything above uses the parsed dict |
| **D6** | Occurrence path separator | `/`, leading `/` = top | path items (P1, P2), GUI display (P4), tests |
| **D7** | Auto-update the tree on binding change | **off**, explicit `Update` | one GUI item (P4) |
| **D8** | Launcher | **RULED 2026-08-18 (user):** **no accelerator**; Tools menu (pre-filled from the current cell) + command palette + Library Manager + `xschem hierarchy_editor`. Plus: *New view…* launches the tool for **every** view type | P1 (new-view launch item), P4 (4.2, 4.15) |
| **D9** | Fate of the existing `traversal` window | **keep, untouched**; HED is additive | P8 (an item that would retire it) |
| **D10** | Active config scope | per-`xctx` (window/tab) | C-side state item (P2) |
| **D11** | Whether a config may be nested (subcell bound to a `config` view) | **yes, one level in v1**, deeper deferred | resolver (P2) + expander (P3) |
| **D12** | GUI is one toplevel vs a tab in the Library Manager | **own toplevel**; **amended by D15** — one toplevel *per config*, not one globally | all of P4 |
| **D13** | Whether ASE-L states carry a config | **yes, optional field** | P7 only |
| **D15** | May more than one HED window exist at once | **yes**, one per config being edited; a schematic window binds to exactly one of them (§4.7). Amends **D12**, which said one toplevel | P4 (4.1, 4.17) |
| **D16** | The Locate key | **`Ctrl+Shift+L`**. `Ctrl+I` — what Cadence users have in muscle memory — is *insert symbol* (`src/callback.c:7590`) and is not available. Registered in `actions.csv`, so rebinding is one row | P4 (4.19) |
| **D17** | `View ▸` in the schematic context menu: cascade or flat | **cascade** (a second popup), because `context_menu` is hand-rolled buttons with no cascade support; flat `Set view: <name>` rows are the fallback | P4 (4.20) |
| **D14** | View-type name and datafile extension | **RULED 2026-08-18 (user):** xschem convention — view `config`, file `<cell>.cfg`, **never** Cadence's `expand.cfg`; both strings confined to the four view-type procs (§2.1) | P1 (1.1) only, *provided* T-P stays green |

---

## 9. Verification

Headless suites under `tests/headless/`, named `test_hed_*.tcl`, run through
`run_suites.sh` on the dev display. Fixtures: a purpose-built 4-level library
under `tests/headless/fixtures/hedlib/` with cells that have `schematic`,
`veriloga`, `verilog` and `spice` views, one recursive cell, one vector-instance
cell, and one cell present in two libraries.

| id | invariant |
|---|---|
| **T-A** | **NO-CONFIG-NO-CHANGE** — every existing netlist golden file is byte-identical with the feature built in and no config loaded. Non-negotiable; runs every item. |
| T-B | format round-trip: load → save → load produces an identical file, including unknown keys |
| T-C | precedence ladder: one test per rank in §3.2, each proving the rank *below* it was suppressed |
| T-D | inheritance: a list set at `/I0` applies at `/I0/I1/I2` and not at `/I3` |
| T-E | stop list: a stopped node emits no children and netlists as a leaf; the same list stops in all five formats |
| T-S | mirror is one-way: descending / selecting / changing cell in a bound schematic moves the Tree selection and expands the path; clicking, expanding and collapsing rows in the Tree changes **nothing** in the schematic (asserted on `sch_path`, `currsch` and the selection set, before and after) |
| T-T | mirror cost: with no window bound, the flush fires zero notifications; with one bound, a rubber-band drag over 50 objects produces **one** notification, not 50 |
| T-U | locate: from Tree view it switches to Table; with an instance selected it targets that instance's cell, with nothing selected the displayed cell; the row is selected and scrolled into view; unbound window and not-in-hierarchy both report and do nothing |
| T-V | context-menu `View ▸`: present only when bound **and** exactly one instance selected; lists exactly `cell_views`; marks the resolved view; picking one writes an **occurrence** binding at the right path and leaves the design file untouched (`xschem get modified` unchanged) |
| T-Q | Library Manager *New view…* opens the created view in the right tool for every type in the table (`schematic`, `symbol`, `verilog`, `veriloga`, `text`, `state`, `config`), and an action-log **replay** of the same line creates the view without spawning anything |
| T-R | Tools → Hierarchy Editor pre-fills Library/Cell from the current schematic; opens empty on an untitled window; no accelerator is registered |
| T-P | naming is one-point-changeable: no source or test file outside the four `src/library_defs.tcl` view-type procs contains the literal `config` as a view name or `.cfg` as an extension. A grep-based test, run every item |
| T-O | `*_stop` × config stop list, all four combinations, per format: the node stops if either says so, and a config never un-stops a symbol that declared itself a leaf |
| T-F | occurrence divergence: two occurrences of one cell on different views produce two subckts with the mangled names of D3, and the instances call the right one |
| T-G | expander: recursion terminates and reports; depth cap honoured; vector instance expands to elements |
| T-H | import/export: `import` then `unload` netlists identically to the original; `export` then delete-config netlists identically to config-loaded |
| T-I | GUI: tree populates, columns correct, View-To-Use combobox lists exactly `cell_views`, edit lands in the binding table, Update re-resolves, dirty state shown |
| T-J | validate: each of the five §7.4 categories is detected on a fixture built to contain it |
| T-K | per-`xctx`: two windows with different configs netlist differently in the same session |
| T-M | `cadence_compat` on: `schematic=` ignored, resolution follows the config alone, and the §3.8 warning names every ignored attribute exactly once. `cadence_compat` off: identical to T-A |
| T-N | `default_schematic=ignore` and the four `*_sym_def` attributes still fire under `cadence_compat` (they are bodies/suppressions, not view selections) |
| T-L | sabotage: for each item, break the new code deliberately and prove the suite goes red (green-but-hollow discipline) |

Pixel deliverables (the HED window itself, row tags, dimming, the diff view) are
**look debts** — `tests/headless/owed.sh add look hed-<what>`. A green suite
never discharges one.

---

## 10. Non-goals for v1

- Constraint lists (Cadence's fourth global list) — layout-only, no analogue here.
- Deeper-than-one-level config nesting (D11).
- A config referencing configs in other libraries by path rather than lib/cell.
- Binding by *symbol* as distinct from binding by cell.
- Rewriting `traversal` (D9).
- Any change to `XSCHEM_LIBRARY_PATH` semantics.

---

## 11. Open questions for the user

1. ~~**D1**~~ — **answered 2026-08-18.** Under `cadence_compat` the config is
   the only mechanism; instance and symbol `schematic=` are ignored and
   netlisting warns about each one (§3.8, FAQ Q49). With `cadence_compat` unset,
   nothing changes.
2. ~~**D2**~~ — **answered 2026-08-18.** One stop list, all five formats.
   Per-symbol `*_stop` attributes keep working and are OR-ed on top (§3.4).
3. ~~launcher~~ — **answered 2026-08-18.** No accelerator. Tools menu
   (pre-filled), command palette, Library Manager, `xschem hierarchy_editor`.
   *New view…* launches the tool for every view type (§2.1, §4.6).
4. **D16** — `Ctrl+I` is *insert symbol* and cannot be taken. Default for
   Locate is `Ctrl+Shift+L`; say if you want a different free chord
   (`Ctrl+Shift+` A B D E J M U W Y Z are open) or want `Ctrl+I` stolen anyway.
5. **D15** — more than one HED window at a time, one per config? Default yes.
6. **D17** — `View ▸` as a real cascade, or a flat `Set view: <name>` run in the
   existing menu? Default cascade.
7. ~~naming~~ — **answered 2026-08-18.** xschem convention: view `config`,
   file `<cell>.cfg`; both strings confined to the view-type table so a later
   rename is a two-row edit (§2.1, D14, test T-P).
