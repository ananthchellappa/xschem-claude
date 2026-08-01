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

All 107 emitted `.state` files are **canonical for the real loader**: `ase::state_load` +
`ase::state_serialize` inside `src/xschem` is byte-identical for every one, every sub-element
`llength`-parses at depth 2-3, and all 1483 output rows carry unique identifier-shaped names.
The clean `.sch` is byte-for-byte unchanged from the pre-fix tool in **all 107** cells — the diff
touches state extraction only. Of the 296 expressions the old code emitted and the new one drops,
all 296 are attributable (quoted header rows no longer shredded 162, aliases 33, RPN
numbers/operators/functions 67, `%N` 8, redirects 2, `vs` selectors 4) and none is a real
plottable vector.

## Round 2 — defects found by verifying the fix

The first pass introduced one regression and left several adjacent defects; all fixed in the
follow-up commit:

* **Regression:** `_probe_tokens` treated `vs` as an x-axis keyword on *every* probe card, so
  `.save vs vd vg` silently lost two signals — `vs`/`vd`/`vg` are ordinary net names in a MOSFET
  bench. The display grammar (`vs`, `xlimit`, `title`, `xlog`, …) now applies only to
  `plot`/`print`, and every dropped clause warns.
* A constant reference-line row (`-; 0.9`) became an output; ngspice aborts the analysis on
  `.save 0.9` when nothing else got saved. Now dropped with a warning (3 cells).
* `i(@dev[param])` is not an ngspice vector (`no such function as i`); it is rewritten to the bare
  `@dev[param]` form, which also collapses the duplicate row in `sky130_oscillator` (5 cells).
* `_NAME_MAX` truncated `…_base[gm|id|vth]` to three identical heads that the `_2`/`_3` dedupe
  then made indistinguishable — the cap now keeps the discriminating tail.
* A graph alias that would need a uniquifying suffix now yields to the expr-derived name
  (`f2` beats `vth2_2`).
* `_OPT_NAME_RE` rejected legitimate hyphenated options (`.options NONLIN-TRAN`); an unquoted
  `.include` path containing spaces was truncated where the old code kept it.
* Bus row `;a,b` lost bit `a` when the label field was empty; `a;;b` returned nothing with a
  warning that misdescribed it (`find_nth` collapses separator runs — it plots `b`).
* An `includes`/`models` path using an unqualified `$VAR` (`$PDK_ROOT/…`, `$::SKYWATER_STDCELLS`)
  now warns: `ase::expand_path` substitutes at global level, so `render_deck` hard-errors at Run
  time. 7 sky130A cells are affected — a property of those source schematics, not of the migrator.

## Round 3 — the `print` half of the deck (`src/ase.tcl`)

Verification also turned up a defect on the ASE side, made reachable in bulk by the bus expansion
above: `render_deck` interpolated an output expr verbatim into `print <expr>`, and ngspice's
expression parser reads the `[0]` of `print a[0]` as a **subscript** of a vector named `a`:

```
print a[0]      -> Warning from checkvalid: vector a is not available or has zero length
print "a[0]"    -> "a[0]" = 1.500000e+00
```

`print v(a[0])`, `print {a[0]}` and `print a\[0\]` all fail the same way (measured, ngspice-42);
the `.save` side was always fine. So **1109 of 1488 `print` lines produced nothing** and
`ase::result_probe` — which scrapes `<expr> = <float>` out of the log — left the Outputs pane
blank for every bus bit.

`ase::backend::ngspice::print_arg` now quotes a bracketed expression (quoting `@dev[param]` is
harmless, so the rule is just "has a `[`"), and `result_probe` accepts the quoted label ngspice
echoes back. Tests: `tests/headless/test_ase_print_bracket_0167.tcl` (12 checks, PB10-PB12 drive
real ngspice); sabotage-verified — reverting `print_arg` to the identity turns 5 of them red.

## Round 4 — the state pointed back at the cluttered cell

Reported from the GUI: open `sky130_tests_ase/tb_bandgap/ngspice_state1`, then **Session > Design
Window**, and it loads
`sky130A/xschem_libs/sky130_tests/tb_bandgap/schematic/tb_bandgap.sch` — the *cluttered*
original, not the migrated one.

`LibraryMigrator` defaulted its library name to `basename(libroot)`, i.e. the **source**
library, and that name went straight into the state's `design {lib … cell … view schematic}`.
ASE resolves the design through `xschem cellview_path <lib>/<cell> <view>`
(`ase::ui::design_path`, `src/ase_window.tcl:3100`), so every migrated state resolved back into
the tree it came from — the state view and its schematic were never associated.

The library name now comes from the **destination** root (`migrate_all(out_root)` for `--library`,
the computed `out_root` for `--sch`); an explicit `--lib` still wins. Verified through the real
`xschem cellview_path` under `sky130A/cadence_style_rc`:

```
tb_bandgap -> .../sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch
   exists=1  is_ase_tree=1
```

`sky130A/xschem_libs/sky130_tests_ase` was regenerated (48 states, `design` lib now
`sky130_tests_ase`, all still `state_load`/`state_serialize` byte-identical). Tests L6/L7.

## Known, not fixed here

* `ase::state_load` runs `ase::expand_bus_outputs`, which clones a row's `name` when it expands a
  `v(d[1:0])` range — such a state is not byte-stable under load→save and gains duplicate names.
  No migrated cell emits a range expr today, so it is dormant.
