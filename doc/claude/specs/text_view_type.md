# `text` — a cell's documentation as a view

Status: DONE (2026-08-12)
Owner branch: fluid-editing
Related: `doc/claude/specs/mixed_signal_signal_browser.md` §B (the `verilog` /
`veriloga` view types, and the extension-derived-type doctrine this extends),
`doc/claude/specs/ase_l.md` (the `state` view type), `src/copy_form.tcl` header.

## Why

A cell's documentation written as `<cell>/README.md` is invisible. The Library
Manager lists **views**, and a plain file next to the view directories is not
one, so the reader has to already know it exists and go looking through the
directory tree — which is the job the Library Manager exists to remove. The
prose belongs where the schematic is: in the view list.

There is a correctness half too, and it is the same argument §B made for `.v`.
Before this change a `<cell>.md` inside a view directory typed as `data`, whose
opener is `editor`, i.e. **`xschem load`** — which on a non-schematic text file
does not fail. It skips every line and leaves an empty schematic whose `schname`
is the Markdown file, marked unmodified, so the next save writes an empty `.sch`
over the documentation.

## The change: one row in the one table

The view-type model is four procs in `src/library_defs.tcl` with five consumers
(`copyform::view_type`, `library_new_view`, `libmgr::view_handler`,
`lib_qualified_abs`, `alt2::*`). A new type is a row, not a feature:

| proc | row |
|---|---|
| `view_type_of_ext` | `.md .markdown .txt .text` → `text` |
| `view_exts_of_type` | `text` → `{.md .txt}` (canonical first) |
| `view_type_opener` | `text` → `text` (the `edit_file` handler, shared with verilog/veriloga) |
| `library_new_view` | `text` → seeded by `library_text_seed` |

Nothing in `libmgr::view_handler` changed: it already dispatches on
`view_type_opener`, so `libmgr::open_text_view` picked the type up for free.
That is the payoff of §B's consolidation, and it is worth stating plainly — the
GUI-side edit for this feature was **one word in a combobox**.

`lib_qualified_abs` gains `text` too, so a reference spelled `lib/cell.md`
resolves to the text view rather than silently handing back the **symbol** (the
`default` arm, and exactly the bug §B fixed for `lib/cell.v`).

The New-View dialog offers `text`; the seed is a Markdown skeleton carrying the
heading and the cell's *other* views, because a blank file gets closed again.

## Deliberately not done

- **Not in the Alt-2 ring.** `alt2::toggle_types` stays
  `{schematic symbol verilog veriloga}`. Alt-2 is the schematic⇄symbol⇄source
  toggle; cycling into a README is not what the key is for. A text view is
  reached from the Library Manager, deliberately.
- **No internal Markdown renderer.** `edit_file` opens the configured editor and
  already falls back to xschem's internal text window when that editor is not
  executable. A viewer of our own would be a second thing to maintain for a file
  format the user's editor handles better.
- **`data` still opens in the editor.** Narrowing the catch-all is a separate
  decision (§B said the same); this change names two more extensions, it does
  not change what happens to unnamed ones.
- **The view directory's NAME is still free.** `cellview_resolve` types a view by
  the datafile inside it, so the SANDBOX cell's view is called `README` and holds
  `tb_counter_wrapper.md`. The consequence, shared with `verilog`, is that
  `cellview_resolve_typed` (and therefore `lib_qualified_abs`) can only find a
  text view whose directory is literally named `text`, or a loose
  `<lib>/<cell>.md` in a flat library. Enumeration (`cell_views`) and opening
  from the Library Manager are unaffected — they never need the name.

## First user

`SANDBOX/tb_counter_wrapper`, whose `README` view documents what a fresh clone
must install to run the mixed-signal co-simulation testbench. Its view list now
reads `README ngspice_state1 schematic symbol`.

## Tests

`tests/headless/test_text_view_model.tcl` — the table rows, the handler
dispatch, `cell_views` enumeration, `cellview_path` resolution,
`lib_qualified_abs`, `library_new_view` + its seed, and the two negatives that
say the change stayed inside its lane: a `.md` view does **not** dispatch to
`editor`, and `text` is **not** in the Alt-2 toggle ring.
