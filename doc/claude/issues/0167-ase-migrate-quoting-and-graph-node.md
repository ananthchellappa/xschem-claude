# 0167 — `ase_migrate.py` aborts a library migration on a graph line-continuation backslash

Status: **FIXED**
Area: `tools/migrate/ase_migrate.py` (`_tcl_conv`, `graph_outputs`, `_mk_name`,
`CellMigrator.write`, `LibraryMigrator.migrate_all`, `SpiceDeck` card parsers)
Tests: `tools/migrate/test_ase_migrate.py` — S6/S7/S8 (quoting + tclsh differential),
G1-G9 (`node=` grammar, incl. the real `test_carry_lookahead`), P1-P9 (card parsers),
L1-L4 (library walk isolation). 70 checks, `python3 tools/migrate/test_ase_migrate.py`.
Found: user ran `ase_migrate.py --library sky130A/xschem_libs/sky130_tests --pdk sky130`
Related: `doc/claude/specs/ase_l.md`, `doc/claude/code_analysis/waveform_subsystem_reference.md` §2.5

## In plain English

Migrating the whole `sky130_tests` library died on cell 26 of 48:

```
MigrationError: value needs backslash quoting (out of domain): 's0[255],s0[254],\'
```

Two independent defects met in that message.

**1. The value should never have existed.** It came from a graph record's `node=` attribute in
`test_carry_lookahead`. `graph_outputs()` split `node=` on `[\s;]+` and called every fragment a
plottable signal. But `node=` is xschem's trace mini-language, not a whitespace list
(`draw_graph()` `src/draw.c` ~4645-4801, row split `my_strtok_r(nptr, "\n", "\"", 4)`
`src/util.c:159`):

* rows are separated by **newline only**; `"` quotes a row (quotes stripped, may span lines);
  `\` escapes the next char — a **trailing `\` is a line continuation**, never a token
* `alias;expr` — the text before the first `;` is the **legend label**, not a signal
* `label;a[3],a[2],…` (a `,` after the `;`) is a **bus**: one trace, N bits
  (`get_bus_idx_array()` `src/draw.c:2842`, bit separators `; , SPACE \ NEWLINE`)
* unescaped whitespace in the expression → an xschem **RPN expression**
* a `%N` / `%rawfile%simtype` suffix selects a dataset

The 9-row `node=` of `test_carry_lookahead` was shredded into 21 fragments: bus aliases (`A`,
`S0`) emitted as signals, 256-bit bus lists kept as single 1681-char "expressions", quoted header
rows (`"32 bit; xxx"`) split into three tokens each, and one row cut in half at an escaped space —
leaving the bare `s0[255],s0[254],\`.

**2. The serializer refused a value Tcl handles fine.** `_tcl_conv` brace-quoted unconditionally
and raised on any backslash or unbalanced brace count, with a docstring promising a fallback to
"xschem canonicalize" — a subcommand that does not exist, and no caller catches `MigrationError`.
Tcl's real `Tcl_ScanElement`/`Tcl_ConvertElement` picks one of four forms (bare / brace /
backslash-escape / mask) and has **no** out-of-domain input.

Because `CellMigrator.write()` wrote the clean `.sch` *before* serializing the state, and
`migrate_all()` had no per-cell guard, the crash left `test_carry_lookahead` on disk as a schematic
with **no state view**, and stranded the remaining 22 cells unmigrated.

## Fixed

* `_tcl_conv(s, quote_hash=True)` is now a faithful `Tcl_ScanElement`/`Tcl_ConvertElement`
  reimplementation (nesting walk, trailing-backslash and backslash-newline rules, `]`/`"` forbid
  the bare form without preferring braces, MASK keeps already-balanced braces, leading `#` quoted
  for element 0 only). It never raises. `_struct_to_str` passes `quote_hash` only for index 0, as
  Tcl does. Verified byte-for-byte against `[list $v]` for 630 values (hand-picked pathologies +
  a deterministic sweep) and for the nested `[list [list …]]` form — test S7/S8.
* `graph_outputs(props, warn)` implements the real grammar: `_graph_rows()` mirrors
  `my_strtok_r(…,"\n","\"",4)`; per row it strips `%…`, takes the alias as the output **name**,
  expands a bus to its bits, and reduces an RPN expression to its **operands** (a derived trace is
  not a `.save`-able vector — `src/ase.tcl render_deck` emits `.save <expr>` / `print <expr>`).
  `tcleval(...)` node values are refused, not guessed at. Every lossy step warns.
  `test_carry_lookahead` now yields 1090 outputs (1089 real bus bits + the `xxx` placeholder its
  two header rows name) instead of 21 fragments.
* `_mk_name` guarantees the identifier shape the viewer requires
  (`^[A-Za-z_][A-Za-z0-9_]*$`, `src/ase_window.tcl`) and **uniqueness** — `ase::result_probe`
  keys its results dict by output name (`src/ase.tcl` ~1055-1061), so the 10 pre-existing
  collisions (`i(curr)"` vs `i(curr)`, `avg` vs `avg()`, …) silently shadowed results.
* `CellMigrator.write()` serializes **both** views before writing either (no more half-written
  cells) — which also makes `--dry-run` exercise the serializer instead of reporting a false
  all-clear. `LibraryMigrator.migrate_all()` records a failing cell in `failed` and continues;
  the CLI prints the failures and exits 1.
* `SpiceDeck` card parsing hardened: `_split_ws` keeps `{…}`/`(…)`/`"…"` groups whole
  (`.param p={1.8 * 2}` used to serialize as the value `{1.8`), `_probe_tokens` drops shell
  redirection and an ngspice `vs <xvector>` clause, `plot sig+2` loses the display offset,
  `.options save all` maps to `save_all_v`, a non-numeric `.temp` is refused here rather than
  detonating in `render_deck`, `\b` keeps a typo'd `.opton` out of the `.op` analysis path, and
  non-identifier option tokens and residual `.param` tokens warn instead of vanishing.

## Verified

`--library` over both shipped workareas now completes: `sky130_tests` 48 cells,
`gf180mcu_tests` 59 cells, exit 0, no failures. The gated integration leg still reproduces the
cluttered cell's operating point exactly (`Id_before == Id_after == 4.843529e-04`).
