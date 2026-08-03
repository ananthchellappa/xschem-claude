# Copy (Hierarchical) — Library Manager

Implementation: `src/copy_form.tcl`, entry point `libmgr::ctx_copy_cell`
(`src/library_manager.tcl`). Test: `tests/headless/test_copy_form.tcl`.

## What it replaces

RMB > Copy on a CELL used to pop `libmgr::cell_dialog` — destination library
combobox + new cell name entry, nothing else. It always copied every view and
had no way to express a hierarchy. `libmgr::cell_dialog` still exists and is
still used by RMB > Rename; only Copy was re-pointed.

## Scope model

lib / cell / view only. No config views, no DM/SCM integration, no
cross-library reference rewriting outside the copied set.

## View NAME vs view TYPE

A view is a directory `<lib>/<cell>/<view>/` holding `<cell>.<ext>`. The view's
**type is the datafile extension**, never the directory name — the same
direction `library_defs.tcl` already goes (`library_new_view` maps type → ext,
`cellview_resolve` maps ext → view).

| datafile        | type        |
|-----------------|-------------|
| `<cell>.sch`    | `schematic` |
| `<cell>.sym`    | `symbol`    |
| `<cell>.state`  | `state`     |
| anything else   | `data`      |

**ASE-L state views.** `ngspice_state1` is a view of type `state`
(`doc/claude/specs/ase_l.md`). Its NAME additionally encodes simulator and
ordinal, so stripping the ordinal gives a narrower, simulator-qualified type
spelling — the *subtype*:

```
ngspice_state1   -> type state, subtype ngspice_state
spectre_state2   -> type state, subtype spectre_state
symbol           -> type symbol, no subtype
```

So in the form's Filter field:

```
type:state           every simulation state, any simulator
type:ngspice_state   only the ngspice ones
ngspice_state1       that one view, by name
*_state1             name glob
type:symbol foo*     types and names mix freely; comma or space separated
```

This is the Cadence viewType/viewName split expressed with information already
on disk. No `cdsinfo.tag`-style side table is introduced — it is the rule
`library_defs.tcl:217-219` already states for `cellview_resolve`: *"the view
name is just a label; a view's editor type comes from the `<cell>.<ext>`
datafile it holds, not from the name."*

The subtype is derived from the view name, which is cheap and needs no I/O. A
`.state` file also carries an explicit `simulator ngspice` key
(`ase::state_default`, `src/ase.tcl:30`), so pass 2 may read that instead if a
state view is ever named without the `<sim>_state<N>` convention.

Procs: `copyform::view_type`, `copyform::view_subtype`,
`copyform::cell_view_types`, `copyform::parse_view_spec`,
`copyform::match_views`.

## The form

Toplevel `.libmgr.cp`, transient for `.libmgr`, house style of
`save_as_form.tcl` (ttk widgets, `slickprop::init_fonts`, sunken status label,
OK/Cancel footer, Return/Escape bound).

Always visible:

- **From** — source library / cell, read-only labels.
- **To** — destination library combobox (`libmgr::lib_names`) + cell entry.
- **Views** — three exclusive modes; only the active mode's widget is enabled.
  - `All views` (default, the Cadence default)
  - `Selected views:` multi-select listbox of the source cell's actual views,
    each shown as `name    (type)`
  - `Filter:` the expression above, with a hint line.
- **Copy Hierarchical** checkbutton — the reveal.

Revealed by the checkbox (`copyform::sync_hier`, `grid` / `grid remove` plus
`wm geometry $w {}` so the toplevel shrinks back):

- **Exclude libraries** multi-select listbox + Defaults / None / All. Cells
  whose master lives in an excluded library are not copied and the copies keep
  referencing them in place — Cadence semantics. The exclude list also prunes
  the traversal, so an excluded PDK never enters the cell table.
- **Update instance references** — Cadence's three-way "Update Instances",
  `copyform::st(updaterefs)`:
  - `none` — copy the tree verbatim; instances in the copies still bind to the
    ORIGINAL libraries. An exact/archival snapshot that keeps tracking the
    golden cells, and the right choice when the retarget happens later by other
    means.
  - `copies` (default) — retarget instances inside the newly copied cells to
    the copies. What "hierarchical copy" normally means.
  - `library` — also fix up cells ALREADY in the destination library that
    reference the originals. Widest blast radius: touches cells the user did
    not select.

  The choice is echoed on the status bar (`copyform::sync_refs`) because
  `none` silently yields copies that still simulate against the source library.
- **On name conflict**: skip | rename | overwrite.
- **Name prefix / suffix**.
- **Cells to copy** table (Library, Cell, Views, Action) + Update table.

Default exclude list is derived, not hand-maintained
(`copyform::default_excludes {?srclib?}`): `devices`, `*_pr`, `*stdcells`, plus
any registered library whose directory is not writable — minus `srclib`, which
is never excluded.

The match is on the **primitive** naming the PDKs share, not on a PDK prefix.
Every registry in the tree names primitives `<pdk>_pr` (`sky130_fd_pr`,
`gf180mcu_pr`, `sg13g2_pr`) and cell libraries `*stdcells`, while the design
libraries shipped beside them are `sky130_tests`, `sky130_tests_ase`,
`gf180mcu_tests`, `sg13g2_tests`, `mips_cpu`. A `sky130*`-style prefix glob
swallows those design libraries — and, when copying out of `sky130_tests_ase`,
the source library itself, leaving the traversal nothing to copy.

## Pass 1 vs pass 2

Pass 1 is look-and-feel. `copyform::open` returns a **plan dict** and that dict
is the seam:

```
src {lib cell}  dst {lib cell}  views {…resolved…}  viewmode  viewfilter
hier  exclude {…}  updaterefs  conflict  prefix  suffix
```

`libmgr::ctx_copy_cell` executes only what the old dialog could already do —
flat copy, all views, via `libmgr::do_copy_cell` → `library_copy_cell`. A plan
with `hier 1`, or with `viewmode` other than `all`, reports "not implemented
yet (pass 1: form only)" on the Library Manager status bar.

Stubbed, in the order pass 2 should take them:

1. **Per-view copy** — copy only `views` instead of the whole cell directory.
   `library_copy_view` already exists per view; the loop and the
   cell-directory creation are what is missing.
2. **Hierarchy scan** — `copyform::refresh_table` currently inserts the top
   cell plus a placeholder row. Real version walks each copied schematic's
   instance `symbol=` references, resolves them (`lib_qualified_abs` /
   `abs_sym_path`), stops at excluded libraries, and fills the same four
   columns.
3. **Reference rewriting** — honour `updaterefs`. `none` is a no-op (and is
   therefore the cheapest thing to ship first). `copies`: for each copied cell,
   rewrite `symbol=` to the destination library where the master was also
   copied, and leave it alone where the master was excluded. `library`: same
   rewrite applied to every cell already in the destination library that
   referenced an original — needs a confirmation step, since it edits cells the
   user did not select. This is the part that makes hierarchical copy worth
   having, and the part Cadence users check first.
4. **Conflict policy and name mapping** — currently collected, not applied.

Not rewritten by any pass, and worth saying out loud in the UI later: paths
inside `.state` files (ASE state `design {lib cell view}` points at the source
cell), simulator model paths, and anything holding a literal library name in a
property string.

## Testability

Everything above the widgets is pure Tcl over the filesystem, so
`tests/headless/test_copy_form.tcl` builds a fixture library in `/tmp`,
registers it through `XSCHEM_LIBRARY_DEFS`, and checks type derivation, filter
parsing, view matching, the plan dict, and then the widget behaviour that is
the actual pass-1 deliverable (section hidden → revealed → hidden, exclude
defaults pre-selected, accept/cancel results).
