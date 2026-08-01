# ase_migrate.py — de-clutter a testbench into the ASE-L form

Converts a **cluttered** xschem testbench — one that carries its model/corner
setup, its `.control` simulator commands, and its waveform graph(s) directly on
the schematic — into the **ASE-L "clean"** form: a circuit-only schematic plus a
separate `ngspice_state1` state view that holds the simulation setup.

    <cell>/schematic/<cell>.sch           circuit ONLY (devices, wires, labels,
                                           gnd, sources) — no models, no corner,
                                           no .control, no graphs, no launcher
    <cell>/ngspice_state1/<cell>.state    the extracted setup as an ase:: state
                                           view (models / includes / variables /
                                           analyses / options / outputs)

After migration, **Tools > Launch ASE-L** on the clean schematic opens an Analog
Sim Environment session with the workarea's default model preloaded, and opening
the `ngspice_state1` view in the Library Manager restores exactly the migrated
setup.

> Design + state-file schema: `doc/claude/specs/ase_l.md` ("Migration tool").
> Reference cells this tool mirrors: `sky130A` / `gf180mcuD`
> `…/nfet_test_claude` (cluttered "before") → `…/test_nfet_final` (clean "after").
> Sibling tools in this dir are unrelated: `migrate_pin_names.py` (pin name text),
> `xschem_libmigrate.py` (flat → lib/cell/view layout).

stdlib-only Python 3, no dependencies. Emitting a cell needs **no xschem process**
(the state serializer reproduces `ase::state_serialize` byte-for-byte);
`--verify` is the only step that shells out to `xschem` + `ngspice`.

---

## Quick start

Migrate one cell (writes into a library-root `--out` directory, under `<cell>/`):

    # from the repo root
    python3 tools/migrate/ase_migrate.py \
        --sch gf180mcuD/xschem_libs/gf180mcu_tests/nfet_test_claude/schematic/nfet_test_claude.sch \
        --pdk gf180 --out /tmp/out

Preview only, nothing written:

    python3 tools/migrate/ase_migrate.py --sch CELL.sch --pdk gf180 --dry-run

Migrate **and prove** the migrated cell reproduces the cluttered cell's operating
point (runs both through `xschem` + `ngspice`, compares Id within 1 µA):

    python3 tools/migrate/ase_migrate.py --sch CELL.sch --pdk sky130 --out /tmp/out --verify

Migrate a **whole `*_tests` library** (every cell that carries clutter):

    python3 tools/migrate/ase_migrate.py \
        --library gf180mcuD/xschem_libs/gf180mcu_tests --pdk gf180 --out /tmp/out_lib

---

## Options

| Option | Meaning |
|---|---|
| `--pdk {sky130,gf180}` | **required** — the technology profile (corner→model map, `$::<var>` model path). |
| `--sch FILE` | a single cluttered `<cell>.sch` to migrate. |
| `--library DIR` | a lib/cell/view library root; migrate every testbench cell under it. |
| `--out DIR` | destination **library-root** directory; the cell is written under `DIR/<cell>/…`. Default: `<source-lib>_ase`. |
| `--lib NAME` | library name recorded in the state's `design=` (default: inferred from the path). |
| `--hoist-sources` | lift numeric `vsource` values into named design variables (`value=1.65` → `.param V1=1.65`, schematic uses `value=V1`). Opt-in heuristic; **off** by default (values kept literal). |
| `--dry-run` | report only; write nothing. |
| `--verify` | run before/after through `xschem`+`ngspice` and compare Id. |
| `--xschem PATH` | xschem binary for `--verify` (default `./src/xschem`). |
| `--models-dir DIR` | absolute dir the `$::<model_var>` resolves to for `--verify` (default: the in-repo workarea models dir). |

`--sch` and `--library` are mutually exclusive; one is required.

---

## What it keeps, extracts, and drops

The `.sch` is scanned into records (reusing `migrate_pin_names`' save.c-faithful
scanner) and each is classified:

| Schematic record | Action | Lands in |
|---|---|---|
| device instances, wires (`N`), net labels, gnd, sources, `T`/`L`/`P`/`A` art | **keep** | clean `.sch` |
| `corner` symbol (`corner=tt`) | extract | `state.models` (via the PDK's corner→model map) |
| `code_shown` / `simulator_commands` block | parse its `value` | `models` (`.lib`), `includes` (`.include`), `variables` (`.param`), `options` (`.options`), `analyses` (`.control`) |
| a `.control` block's analyses (`op`/`dc`/`ac`/`tran`) | extract | `state.analyses` |
| `.control` `save`/`print`/`plot`, `flags=graph` block `node=` | extract | `state.outputs` (graph nodes get `plot=1`) |
| `save all` / `print all` | extract | `state.save_all_v` |
| `launcher` (raw-load buttons) | **drop** | — (the ASE-L viewer replaces it) |

**Nothing is silently lost.** A `.control` command that does not map to the state
schema (`let`, `meas`, `foreach`, `while`, …) is **preserved verbatim in the
migration report's warnings**, so you can port it by hand. The per-cell report
(printed by the CLI) lists what was kept, extracted, dropped, hoisted, and every
warning.

### Graph `node=` is a trace mini-language, not a list of signals

A `flags=graph` block's `node=` is parsed with xschem's own grammar (`draw_graph()`
`src/draw.c`, `doc/xschem_man/graphs.html`,
`doc/claude/code_analysis/waveform_subsystem_reference.md` §2.5) — rows separated by
**newline only**, `"` quoting a row, `\` escaping the next character:

| `node=` row | becomes |
|---|---|
| `v(out)` | one output `v(out)` |
| `CIN;cin` | one output `cin`, **named** `CIN` (text before `;` is the legend label) |
| `S0;s0[3],s0[2],\`⏎`s0[1],s0[0]` | a **bus**: one output per bit (the trailing `\` is a line continuation, not a token) |
| `x1.zminus x1.plus -` | an RPN expression — not a `.save`-able vector, so its **operands** are saved and the expression is reported |
| `TEMPERAT%0` | `TEMPERAT`; the `%N` dataset selector has no ASE equivalent and is reported |
| `tcleval(...)` | refused (evaluated at draw time) and reported |

A wide bus expands to one output per bit and says so in the report — e.g.
`sky130_tests/test_carry_lookahead` yields 1089 bit outputs from its four buses.

---

## Output the tool produces

The clean schematic is byte-preserving for the records it keeps (original
geometry and formatting untouched). The state file is **byte-canonical** — the
exact form `ase::state_save` writes, so re-loading and re-saving it in xschem is a
no-op. Example (gf180 `nfet_test_claude`):

    version 1
    simulator ngspice
    design {lib gf180mcu_tests cell nfet_test_claude view schematic}
    rundir {}
    temperature 27
    models {{file {$::180MCU_MODELS/sm141064.ngspice} section typical}}
    variables {}
    analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
    outputs {{name iv1 expr -i(v1) save 1 plot 0}}
    save_all_v 1
    save_all_i 0
    options {{name savecurrents value 1}}
    includes {{file {$::180MCU_MODELS/design.ngspice}}}
    viewer {}

---

## Verification

`--verify` is the acceptance check. It:

1. netlists the **cluttered** source cell and runs `ngspice` on it → `Id_before`;
2. loads the **migrated** `ngspice_state1` state view, renders the deck through
   the public `ase::` API, runs it → `Id_after`;
3. reports `OK` when `|Id_before − Id_after| < 1 µA`, `MISMATCH` otherwise
   (exit code 1), or `skipped` if `ngspice` is absent.

The op-point probe convention is `-i(v1)`. The in-repo reference pairs are the
built-in fixtures: **sky130 ≈ 409.7 µA**, **gf180 ≈ 484.35 µA** (before == after).

---

## Limitations / gotchas

- **Hard values vs design variables.** By default the migrator keeps numeric
  `vsource` values literal (safe, no topology guessing), so a migrated
  `nfet_test_claude` is *electrically* equal to the hand-built `test_nfet_final`
  but not byte-identical (which symbolized `Vds`/`Vgs`). Use `--hoist-sources` to
  lift them into `.param`s named after the instance (`V1`, `V2`, …).
- **Per-PDK profiles.** Only `sky130` and `gf180` are built in. A different PDK
  needs a `Pdk(...)` entry in `PDKS` (name, `$::<model_var>`, and — if it uses a
  `corner` symbol — the corner→`.lib` mapping). gf180-style `code_shown` blocks
  need no corner mapping (the `.include`/`.lib` are parsed straight from the text).
- **A wholly custom `.control` script** (built around `let`/`meas`/loops) migrates
  to "clutter-free schematic + preserved warnings", not a fully-structured state —
  the report tells you exactly what needs hand-porting.
- **`--verify` and xschem argv.** xschem consumes positional args after
  `--script FILE` as *files to open*, not Tcl `$argv`; the verify driver therefore
  bakes its parameters in by placeholder substitution (internal detail — noted here
  because it bites anyone extending the driver).

---

## Using the migrated cell

1. Launch the workarea: `./gf180mcuD/run.sh` (or `./sky130A/run.sh`).
2. In the Library Manager open the clean `schematic` view.
3. **Tools > Launch ASE-L** → a fresh session with the default model preloaded
   (the rc's `::ASE_DEFAULT_MODELS`); or **double-click the `ngspice_state1`
   view** → the full migrated setup. Run from the ASE-L window.

---

## Tests

    python3 tools/migrate/test_ase_migrate.py

41 checks: the Tcl-list serializer (byte-identical to the committed gf180 golden),
the SPICE/`.control` parser, classification, graph recovery, source hoisting, and
an integration leg (auto-skipped without `./src/xschem` + `ngspice`) that migrates
the real gf180 `nfet_test_claude` and asserts `Id_before == Id_after`.
