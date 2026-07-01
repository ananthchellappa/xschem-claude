# migrate_pin_names.py — Cadence-style pin-owned name text migration

Adds the pin-owned-name-text tokens to existing xschem `.sym` files so their pins
behave like natively-created ones (the running editor already writes these tokens for
new pins). Part of the pin-owned-name-text feature — design + rationale in
`doc/claude/specs/cadence_pin_name_text.md` (Option B).

> Sibling tool: `xschem_libmigrate.py` in this directory is unrelated — it migrates
> flat libraries to the lib/cell/view layout (the Library Manager work).

## What it does

For each pin rect (`B 5 ... {...}`) it writes, in the pin's own property string:

    show_pinname=true|false  name_dx=<dx> name_dy=<dy> name_size=<s>
    [name_rot=<r>] [name_flip=<f>] [name_font=<font>]

There is **no separate persisted `T` name record**: the displayed name is derived from
these tokens (a synth view in symbol-edit; drawn from tokens on placed instances). Per
pin, one of:

- **ADOPT** — a pin that has a literal `T {<exactname>}` label (no `@`) nearby whose text
  equals the pin's `name=`: the label's geometry is folded into the pin's `name_*` tokens
  (`show_pinname=true`) and the `T` record is **removed**.
- **CREATE** — otherwise the pin gets default `name_*` tokens matching the editor's
  `create_pin` (in-pins name on the right `name_dx=25`; out/inout on the left
  `name_dx=-25 name_flip=1`) and `show_pinname=false` (hidden), leaving any non-matching
  legacy text untouched as an ordinary note.

**Skipped**: pins already carrying a `show_pinname` token (idempotency), empty or
`@`-templated pin names, symbols with 0 pins, and `label`/`logo`/`title`/`probe`/… types.

Migration is **display-only** — `name=`/`dir=`/pin order are never changed, so **netlists
are byte-identical**. Every write is self-checked (the result is re-parsed and the pin
count verified) and aborted on any mismatch.

## Usage

    # one file (writes FILE.sym.bak first)
    python3 migrate_pin_names.py path/to/cell.sym

    # a whole tree, preview only
    python3 migrate_pin_names.py --dry-run -r /path/to/library --report out.json

    # a whole tree, in place, no backups
    python3 migrate_pin_names.py -r --no-backup /path/to/library

Options: `-r/--recursive`, `-n/--dry-run`, `--no-backup`, `--no-adopt` (always create,
never adopt), `--default-size FLOAT` (created name size, default 0.2), `--show-created`
(make created names visible instead of hidden), `--adopt-radius FLOAT` (max pin↔label
bind distance, default 100), `--exclude GLOB` (repeatable), `--report FILE` (JSON
summary), `-v/--verbose`. See `--help`.

stdlib only (Python 3). Idempotent — re-running is a no-op.

## Tests

    python3 -m pytest tools/migrate/test_migrate_pin_names.py     # unit tests
    # end-to-end (loads migrated syms in xschem, asserts netlist invariance):
    cd src && ./xschem --nogui --pipe -q --script ../tests/headless/test_migrate_pin_names.tcl

A dry-run over the stock `xschem_library` (1712 `.sym`) parses every file with **0
errors** (1415 migrate, 297 skip; ~520 pins adopted, the rest created hidden).
