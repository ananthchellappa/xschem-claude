# Copy — Library Manager (a cell, or a set of cells that point at each other)

Status: built. Form and engine `src/copy_form.tcl`, entry points
`libmgr::ctx_copy_cell`, `libmgr::do_copy_plan`, `libmgr::do_copy_cell`
(`src/library_manager.tcl`). Tests: `tests/headless/test_copy_retarget.tcl`
(engine and decisions, no display, `hcases`) and
`tests/headless/test_copy_form.tcl` (the widgets, `dcases`).

## What it is for

The case that drove it: there is a cell `my_buf3` and its bench `my_buf3_tb`,
which has saved ASE-L states (`ngspice_state1`, ...). The user makes a variant,
`fast_buf3`, and wants the bench for it, `fast_buf3_tb`: the same bench, now
instantiating `fast_buf3`, with states that simulate the new bench.

A copy of the files alone does not give that. Measured on the real cells before
this was built, the copied bench still instantiated `my_buf3`, and each copied
state still had `design {lib ... cell my_buf3_tb ...}`: opening it under
`fast_buf3_tb` and pressing Run simulated the OLD bench, with nothing to say so.
Its include file and the result file of its saved plots were the old bench's too.

So a copy does three things:

1. copies the cells that were picked, under their new names;
2. points the copies at each other: instances in the copied schematics, and the
   copied states (section "What is re-pointed");
3. says what in the copies still names an original, because a name inside a
   title text or a hand-written SPICE block is not something to guess at.

## What it replaces

RMB > Copy on a CELL used to pop `libmgr::cell_dialog` (destination library +
new cell name). `libmgr::cell_dialog` still exists and is what RMB > Rename uses.

## Scope model

lib / cell / view only. No config views, no DM/SCM integration.

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
(`ase::state_default`), which could be read instead if a state view is ever
named without the `<sim>_state<N>` convention.

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

- **Exclude libraries** multi-select listbox + Defaults / None / All. A cell
  whose master lives in an excluded library is never listed, and nothing below
  it is visited, so a PDK never enters the table. The copies keep referencing
  such cells in place.
- **Update instance references**, Cadence's three-way "Update Instances",
  `copyform::st(updaterefs)`:
  - `none`: instances in the copies still bind to the ORIGINAL cells. An exact
    snapshot that keeps tracking the golden cells.
  - `copies` (default): instances inside the newly copied cells are pointed at
    the copies.
  - `library`: cells ALREADY in the destination library that instantiate an
    original are re-pointed as well. It edits cells the user did not pick, so
    the table lists each of them (Action `Re-point`) before OK is pressed. A
    schematic that is open in a window is left alone and named in the report:
    the editor would write its own copy back over the change.
- **Name prefix / suffix**: added to the names proposed for the cells below.
- **The table of cells** (next section) + Rename, Copy / Keep, Rescan.

Default exclude list is derived, not hand-maintained
(`copyform::default_excludes {?srclib?}`): `devices`, `*_pr`, `*stdcells`, plus
any registered library whose directory is not writable, minus `srclib`, which
is never excluded.

The match is on the **primitive** naming the PDKs share, not on a PDK prefix.
Every registry in the tree names primitives `<pdk>_pr` (`sky130_fd_pr`,
`gf180mcu_pr`, `sg13g2_pr`) and cell libraries `*stdcells`, while the design
libraries shipped beside them are `sky130_tests`, `sky130_tests_ase`,
`gf180mcu_tests`, `sg13g2_tests`, `mips_cpu`. A `sky130*`-style prefix glob
swallows those design libraries and, when copying out of `sky130_tests_ase`,
the source library itself, leaving the traversal nothing to copy.

## The table of cells

The table is the plan, shown before OK. One row per cell: Library, Cell (indented
by depth), New name, Action. Row 0 is the cell being copied; the rest are the
cells below it (`copyform::hier`, read from the schematics as text).

| Action | meaning |
|---|---|
| `Copy` | the cell is copied under New name |
| `Use existing` | a cell of that name is already in the destination library: nothing is copied over it, references are pointed at it |
| `Keep` | not copied; references to the original stay |
| `Re-point` | ("Entire destination library" only) a cell already there, whose instances will be re-pointed |

- Double-click a New name (or Rename, or F2) to type it in place; Return keeps
  it, Escape drops it. Naming row 0 is naming the copy (the To field).
- Click an Action (or Copy / Keep, or Space) to switch a row between copied and
  kept. A kept cell of the destination library needs a new name before it can be
  a copy there, so the name field opens.
- `Use existing` is how a bench is copied AFTER its new device exists: name the
  device's row after the existing cell.

**Names proposed** (`copyform::suggest`). Two naming habits are followed and
nothing else is guessed:

- a bench is named after what it tests: copying `my_buf3_tb` as `fast_buf3_tb`
  proposes `fast_buf3` for `my_buf3`;
- a block is named after its owner: copying `my_buf3` as `fast_buf3` proposes
  `fast_buf3_bias` for `my_buf3_bias`.

**Which rows are copied by default** (`copyform::default_on`). A copy into
another library takes the cells below along. A copy inside one library takes
only the cells a new name was proposed for, so copying a bench inside its
library never duplicates a block by surprise. A row the user named or switched
by hand keeps what the user chose when the table is rebuilt.

OK refuses a plan that cannot run (`copyform::plan_why`: a name that is taken,
a name no cell can have, two copies with one name, ...) on the form's own
status bar, with everything typed still there.

## What is re-pointed

The files are edited as text: loading each schematic into the editor would
clobber the one the user has open, and would re-save every record. A line that
is not changed comes back byte for byte (binary I/O; names compared as the
UTF-8 bytes they have on disk).

**Schematics** (`copyform::retarget_sch`). An instance record is a line that
starts `C {` outside every attribute block. Its reference is resolved to a cell
(`copyform::ref_cell`) and, if that cell is replaced, rewritten in the spelling
it had:

| reference | becomes |
|---|---|
| `lib/cell`, `lib/cell.sym`, `lib/cell.sch` | the same form, new library and cell |
| a path found on the search list (`cell.sym`, `lib/cell/symbol/cell.sym`) | `lib/cell` (how this program writes it) |
| an absolute path, or a path into a view with a name of its own | the path of the same file in the copy |

**ASE-L states** (`copyform::retarget_state`):

| key | rule |
|---|---|
| `design` | a design that is a replaced cell becomes its replacement. A state the user pointed at some other cell (Setup > Design) is left |
| `models`, `includes` | a file inside a replaced cell's own directory is read from the copy, when the copy has it. Whatever is written in front of the cell is kept, so `$::HDO_DIR/lib/...` stays a variable |
| `viewer` | only when the design moved: the selected result is cleared (a state's way of saying "my own last run"), and traces pinned to the old bench's result file (`<cell>_ase.raw`) are pinned to the copy's |

A state ALWAYS follows its own cell, whatever "Update instance references"
says: a state stored under one cell and simulating another is never what a copy
is for.

**The same rule elsewhere in the Library Manager**, because it is the same
defect:

- Rename (`libmgr::do_rename_cell`): the renamed cell's own states follow the
  new name. Other cells that instantiate it, or hold a state that simulates it,
  are NOT edited; the status bar counts them and the CIW names each.
- Copy view (`libmgr::do_copy_view`): a state view copied into another cell
  simulates the cell it now belongs to. Copied inside its own cell it is left.

## The report

`copyform::execute` returns a dict (`copied`, `used`, `kept`, `sch`, `states`,
`edited`, `skipped`, `left`). The Library Manager's status bar gets one line
(`copied 2 cells, 1 instance re-pointed, 2 states re-pointed, 3 places still
name an original (see the CIW)`); the CIW gets the whole account, one sentence a
line, ending with what is left:

```
copy: still names my_buf3_tb: fast_buf3_tb/schematic/fast_buf3_tb.sch line 8: T {my_buf3_tb (sky130): ...
```

`left` is every line of the copied cells' files that still names an original as
a whole word (`copyform::mentions`): comments, title texts, an include that was
not copied, a `schematic=` attribute. They are reported, never edited.

## All or nothing

`copyform::plan_why` refuses before anything is created. A failure after that
(a state file that cannot be read, a file that cannot be written) puts every
edited file back and moves every cell made so far to the library's trash;
the error says `nothing was copied: <why>`.

## Replay

`libmgr::do_copy_plan <plan>` is the one executor and what the action log
records, with the plan trimmed to the rows that do something
(`copyform::plan_min`). `libmgr::do_copy_cell` (one cell, all views) logs as it
always did.

## Testability

The engine and the form's decisions are plain Tcl over the filesystem, so
`tests/headless/test_copy_retarget.tcl` runs with no display: a fixture library
with a bench, a device, a sub-block, states, a flat library, a second library.
`tests/headless/test_copy_form.tcl` presses the form: a name typed in place, a
row switched by a real click, OK refusing on the form, and right-click > Copy end
to end through the modal form.

## Not built

- Re-pointing the cells that instantiate a RENAMED cell. Rename reports them.
- A check, when a state is opened, that its design is the cell it is stored
  under (a state copied by other means, before this, still has the old one).
- Editing what `left` reports. A `schematic=` attribute or a name in a SPICE
  block is shown, not rewritten.
- Selecting several cells in the Library Manager's cell pane and copying them
  as a set. The set is built in the form, from the cell that was right-clicked.
- Overwriting an existing cell.
