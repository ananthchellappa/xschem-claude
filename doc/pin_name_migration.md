# Migrating existing symbols to owned pin-name text

*How to use `migrate_pin_names.py` to give the pins of existing `.sym` files the
Cadence-style **owned name text** that the editor now writes for newly-created pins —
walked through on a whole library.*

> Tool: `tools/migrate/migrate_pin_names.py` (stdlib Python 3, no dependencies).
> Reference: `tools/migrate/README_pin_names.md`. Design: `doc/claude/specs/cadence_pin_name_text.md`.
> Not to be confused with `tools/migrate/xschem_libmigrate.py`, which is a *different*
> tool (flat → lib/cell/view library layout).

---

## 1. What the tool does

Each symbol pin is a `B 5 ...` rect. With the owned-name-text feature a pin also carries,
in its own property string, the tokens that describe its name label:

    show_pinname=true|false  name_dx=<dx> name_dy=<dy> name_size=<s>
    [name_rot=<r>] [name_flip=<f>] [name_font=<font>]

There is **no separate `T` name record** — the name is *derived* from these tokens (drawn
directly on placed instances, and materialized as an editable text when you open the symbol
for editing). The migration tool writes those tokens onto existing symbols. Per pin it does
exactly one of:

- **ADOPT** — the pin has a plain literal `T {<exactname>}` label next to it whose text
  equals the pin's `name=`: fold that label's position/size/rotation into the pin's
  `name_*` tokens, set `show_pinname=true`, and **delete the `T` record**. The name looks
  the same, but is now owned by the pin.
- **CREATE** — no matching label: give the pin default `name_*` tokens (same offsets the
  editor uses) with `show_pinname=false` (**hidden**), so the name is ready but off. Any
  unrelated legacy text is left untouched.
- **SKIP** — pins that are already owned, have empty or `@…` names, symbols with no pins,
  and `label`/`logo`/`title`/`probe`/… symbol types.

It only ever adds display tokens and removes adopted `T` labels — `name=`, `dir=`, pin
coordinates and pin order are never touched, so **netlists are byte-identical** afterwards.

## 2. Before you start

- **Python 3** (`python3 --version`). No third-party packages.
- **Non-destructive**: by default the tool writes `FILE.sym.bak` before editing a file.
- **Idempotent**: running it again is a no-op — already-owned pins are skipped.
- Every write is **self-checked** (the result is re-parsed and its pin/token invariants
  verified); if anything looks wrong the file is left untouched and reported as an error.

## 3. Quick start

```sh
cd <repo root>

# preview a single file — writes nothing
python3 tools/migrate/migrate_pin_names.py --dry-run -v xschem_library/ngspice/opamp_65nm.sym

# migrate one file (leaves opamp_65nm.sym.bak next to it)
python3 tools/migrate/migrate_pin_names.py xschem_library/ngspice/opamp_65nm.sym

# preview a whole tree and save a machine-readable report
python3 tools/migrate/migrate_pin_names.py --dry-run -r xschem_library --report /tmp/report.json
```

`--help` lists every option (see §7).

## 4. Worked example — migrating a whole library

Say you have a library `xschem_libraries_oa/` (342 symbols in lib/cell/view layout) and want
a migrated copy `xschem_libs_newsym/` while keeping the original pristine. The idiomatic
recipe is **copy, then migrate the copy** (so the untouched original *is* your backup, and
the new tree carries no `.bak` clutter):

**Step 1 — preview + report (writes nothing).**

```sh
python3 tools/migrate/migrate_pin_names.py --dry-run -r xschem_libraries_oa \
        --report /tmp/oa_report.json
# ... per-file lines ...
# 239 migrated, 103 skipped, 0 errors; 466 names created, 507 adopted
```

Read the summary line and skim the report for `error` entries and warnings before committing
to it. Here: 0 errors, and the only warnings are intentional duplicate pin names (ground
buses, connectors like `conn_10x2`) — the tool binds each label to its nearest pin, so those
are informational.

**Step 2 — copy the whole tree** (symbols *and* everything else, so the result is a complete
usable library):

```sh
cp -r xschem_libraries_oa xschem_libs_newsym
```

**Step 3 — migrate the copy in place** (`--no-backup`, since the original tree is the backup):

```sh
python3 tools/migrate/migrate_pin_names.py -r --no-backup xschem_libs_newsym \
        --report /tmp/oa_migrated.json
# 239 migrated, 103 skipped, 0 errors; 466 names created, 507 adopted
```

That's it — `xschem_libs_newsym/` now has owned pin names; `xschem_libraries_oa/` is
unchanged.

## 5. What actually changed (per pin)

The edit is deliberately minimal. Here is a real before/after for one cell,
`xschem_simulator/or4_1/symbol/or4_1.sym` (a 4-input OR gate that shipped with literal name
labels, so its pins are **adopted**):

```diff
-B 5 -62.5 -62.5 -57.5 -57.5 {name=A dir=in goto=4 }
-B 5  57.5  -2.5  62.5   2.5 {name=X dir=out }
+B 5 -62.5 -62.5 -57.5 -57.5 {show_pinname=true name_dx=5 name_dy=-14 name_size=0.2 name=A dir=in goto=4 }
+B 5  57.5  -2.5  62.5   2.5 {show_pinname=true name_dx=-5 name_dy=-14 name_size=0.2 name_flip=1 name=X dir=out }
 ...
-T {X} 55 -14 0 1 0.2 0.2 {}
-T {A} -55 -74 0 0 0.2 0.2 {}
```

Note:

- The new tokens are **prepended** (right after the `{`) and the original `name=`/`dir=`/`goto=`
  are preserved verbatim. (Prepending matters: some imported symbols end a pin prop with an
  empty-valued token like `dir=`, and appending after it would let the tokenizer swallow the
  first appended token.)
- `name_dx/name_dy` are the adopted label's position **relative to the pin center**; the input
  pin `A`'s label sat at `-55,-74` and its pin center is `-60,-60` → `name_dx=5 name_dy=-14`.
  The output pin `X` was mirrored, so it also picks up `name_flip=1`.
- The five `T {A..D}` / `T {X}` label records are **deleted** — the name now lives on the pin.

A symbol with **no** matching labels instead gets `show_pinname=false` plus the default
offsets, e.g. `... show_pinname=false name_dx=25 name_dy=-5 name_size=0.2 name=P dir=inout ...`
— the name is present but hidden until you reveal it.

## 6. Verifying the result

- **The report.** `--report FILE` writes JSON: a `totals` block plus a per-file
  `{status, created, adopted, skipped_pins, warnings}`. Grep it for `"status": "error"`.
- **Load in xschem.** The migrated symbols must load and re-save cleanly, and their names
  must materialize. Headless:

  ```sh
  cd src
  # NOTE: use an ABSOLUTE path — xschem resolves a relative path against its own cwd
  ./xschem --nogui --pipe -q --script /dev/stdin <<'EOF'
  xschem load /abs/path/xschem_libs_newsym/xschem_simulator/or4_1/symbol/or4_1.sym
  puts "pins=[xschem get rects 5]"
  xschem pin_names on          ;# force-show every owned name
  puts "name views=[xschem get texts]"
  EOF
  ```

  or just open one in the GUI: `src/xschem /abs/path/.../or4_1.sym` and toggle
  **Symbol ▸ Pin names ▸ Show all pin names**.
- **Idempotency.** Re-run the migration over the output; it must report `0 migrated` and
  change nothing.
- **ERC.** Inside the symbol editor, **Symbol ▸ Check pin names** (or `xschem
  check_pin_names`) flags duplicate names, owned-but-nameless pins, and any legacy label a
  migration left un-adopted.

## 7. Options

| Option | Meaning |
|---|---|
| `-r`, `--recursive` | recurse into directories |
| `-n`, `--dry-run` | report only, write nothing |
| `--no-backup` | do not write `FILE.sym.bak` |
| `--no-adopt` | never adopt existing labels; always create hidden names |
| `--default-size FLOAT` | `name_size` for *created* names (default `0.2`). Set this to your `sym_pin_name_size` if you changed it, so migrated names match editor-created ones |
| `--show-created` | make *created* names visible (default: hidden) |
| `--adopt-radius FLOAT` | max pin↔label bind distance (default `100`) |
| `--exclude GLOB` | skip matching paths (repeatable) |
| `--report FILE` | write a JSON summary |
| `-v`, `--verbose` | log per-pin actions |

## 8. Rollback

- Single files: the tool wrote `FILE.sym.bak` — `mv FILE.sym.bak FILE.sym` restores it.
- A migrated *copy* (the §4 recipe): just `rm -rf xschem_libs_newsym`; the original tree was
  never touched.

## 9. Caveats & tips

- **Eyeball a few cells in the GUI.** The tool is textual and structurally verified, but it
  cannot judge whether an adopted name's position *looks* right on a busy symbol. Open a
  handful after migrating.
- **`--default-size` vs `sym_pin_name_size`.** Created (hidden) names are stamped
  `--default-size` (0.2). If your xschemrc sets `sym_pin_name_size` to something else, pass
  the same value so a migrated pin matches one you draw by hand.
- **Conservative adoption.** Only a *plain* label (square scale, no props beyond `font=`) is
  adopted. A label on a custom layer, with `hide=`, a color, or a non-square scale is left
  as-is (appearance preserved) and its pin gets a hidden created name instead — so nothing
  visibly changes for those, and you can reveal/reposition later.
- **Duplicate pin names** (ground buses, connectors) are handled by nearest-label binding and
  reported as a warning, not an error.
- **What it declines.** Symbols it can't parse cleanly (e.g. an embedded `[...]` block) are
  **skipped, not failed** — a bulk `-r` run still exits 0. Non-UTF-8 bytes and CRLF line
  endings round-trip byte-for-byte.
- **Generators.** If a `.sym` is produced by a generator script, migrating the output is fine,
  but the generator may overwrite it later; migrate (or update) the generator too.
