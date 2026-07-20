# gf180mcuD — Cadence-style GlobalFoundries 180MCU design workarea

A self-contained GF180MCU (gf180mcuD) analog/mixed-signal design environment for xschem,
built from the open_pdks gf180mcuD xschem tree migrated into the repo's Cadence-ish
**lib/cell/view** format. On launch the migrated libraries appear in the Library Manager
and you can draw → netlist → simulate (ngspice) with the Cadence-compatible UX.

Sibling of `../sky130A/`; same pattern, but simpler — the gf180 PDK ships only primitive
symbols (no primitive schematics) and a small, self-contained model set.

## Launch

```sh
./gf180mcuD/run.sh [cell.sch]            # from the repo root
# or directly:
src/xschem --script gf180mcuD/cadence_style_rc [cell.sch]
```

The Library Manager opens showing the migrated libraries. Cadence UX is active:
crosshair, `cadence_compat`, connected stretch/move, and the custom forms
**Find Navigator** (Ctrl+Shift+G) and **Instance Update** (Ctrl+Shift+I). A **GF180MCU**
menu is added to each window (drop the models block, show the models path).

## Libraries (Library Manager)

| Library | Cells | Notes |
|---|---|---|
| `gf180mcu_pr`    | 66  | analog device primitives (nfet/pfet/cap/res/diode/npn/pnp) — symbol-only leaves |
| `gf180mcu_tests` | 59  | example testbenches + `0_top` device gallery (symbol + schematic views) |
| `devices`        | —   | standard xschem device lib — referenced from `../xschem_libs_newsym/devices` (not duplicated) |
| `analyses`, `examples`, `ngspice`, `ngspice_verilog_cosim`, `xschem_simulator` | — | the repo's migrated general-purpose libraries — referenced from `../xschem_libs_newsym/<lib>` (not duplicated) |

All cross-references are lib-qualified (`C {gf180mcu_pr/nfet_03v3}`, `C {devices/vsource}`),
resolved through `xschem_libs/library.defs` (registry-only mode).

## Layout

```
gf180mcuD/
├── xschem_libs/     library.defs + <lib>/<cell>/{symbol,schematic}/<cell>.<ext>
├── models/          vendored libs.tech/ngspice (flat, self-contained SPICE models, ~784 KB)
│                    design.spice + sm141064.spice (+ _mim, smbb000149) + .ngspice symlinks
├── cadence_style_rc the launch rc (UX + registry + models)
├── gf180_procs.tcl  GF180MCU menu (add models block; models path)
├── run.sh
└── README.md
```

## Models

The gf180 models are small and self-contained (every `.lib` refers to a sibling file by
bare name), so `models/` is a verbatim copy of the PDK's `libs.tech/ngspice`. Testbenches
embed:

```
.include $::180MCU_MODELS/design.ngspice
.lib     $::180MCU_MODELS/sm141064.ngspice typical
```

`cadence_style_rc` sets `::180MCU_MODELS` to `gf180mcuD/models`. Use **GF180MCU → Add models
block** to drop the same two lines into a new top-level schematic.

## Design flow

1. New schematic; place devices from `gf180mcu_pr` (set W/L/nf on the FET template).
2. Add supplies/pins from `devices` (`vsource`, `gnd`, `lab_pin`, ...).
3. **GF180MCU → Add models block**; put `.tran`/`.dc`/`.op`/`.control` in a
   `devices/code_shown` (or `simulator_commands_shown`) symbol.
4. Netlist (SPICE) → `netlist_dir`; simulate with ngspice. Device symbols carry hidden
   `gm`/`id` operating-point overlays.

## Validation

Built and validated 2026-07-20. All green:

- **Registry** — headless `library_list` lists exactly the 8 intended libs; `devices` + the 5
  general libs resolve to `xschem_libs_newsym/<lib>` (outside `gf180mcuD/`, not duplicated); cells
  resolve to real `<lib>/<cell>/{symbol,schematic}/<cell>.<ext>` files.
- **Netlisting** — all **59** testbenches netlist through the registry with **0** unresolved
  symbols.
- **Models** — with `::180MCU_MODELS` set (as `cadence_style_rc` does), the `code_shown` MODELS
  block's `tcleval` expands to `.include <models>/design.ngspice` +
  `.lib <models>/sm141064.ngspice typical`. (If the var is unset the block silently drops — always
  launch via the rc.)
- **Simulation** — ngspice runs clean; `nfet_03v3` (W=1u, L=0.28u, Vgs=Vds=3.3 V) draws
  **Id ≈ 520 µA**, a sane 3.3 V nfet current — the vendored models work end-to-end.
- **Regression smoke** — `tests/headless/test_gf180mcud_libmgr.tcl` (29 checks) is registered in
  `tests/run_regression.tcl` and sabotage-verified (drop a `DEFINE` → the run FAILs). Run it alone:
  ```sh
  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_gf180mcud_libmgr.tcl
  # prints "OVERALL: ok"
  ```

Two differences from `sky130A` worth knowing: the gf180 models are flat/self-contained (no
transitive-closure trimming), and there were no PDK Tcl procs to port — device operating-point
annotation is baked into each primitive symbol as hidden `tcleval(gm=..)`/`tcleval(id=..)` T lines.

## Building from original source

How to reproduce this workarea from a fresh open_pdks gf180mcuD install, **without** Claude Code —
just the repo's migration scripts + shell. Design + full rationale:
`doc/claude/specs/gf180mcud_workarea.md`. The two Python tools are stdlib-only (Python 3),
non-destructive (they never touch the source PDK), and idempotent.

The source PDK xschem tree ships primitives under `symbols/` and testbenches under `tests/`; the
testbenches reference the primitives with a `symbols/` **directory** prefix (`C {symbols/nfet_03v3.sym}`).
The migrate tool rewrites a slashed `prefix/cell` reference only when `prefix` is a *library name* —
so to land the primitives in a library named `gf180mcu_pr` (not `symbols`), the `symbols/` prefix is
stripped in a scratch staging copy first, turning the references bare so the tool's bare-cell
resolver maps them to `gf180mcu_pr/<cell>`.

Run from the repo root. `$PDK_ROOT` is the dir that **directly contains** `gf180mcuD/` — depending on
how open_pdks was installed this may be nested (e.g. `.../open_pdks/gf180mcu/`, not
`.../open_pdks/`). Locate it with `find <install> -type d -name gf180mcuD`:

```sh
SRC=$PDK_ROOT/gf180mcuD/libs.tech/xschem          # symbols/ + tests/
MODELS=$PDK_ROOT/gf180mcuD/libs.tech/ngspice      # design.spice, sm141064.spice, ...
DST=gf180mcuD/xschem_libs
STAGE=$(mktemp -d)

# 1. Stage sources (non-destructive) and normalize the 'symbols/' dir prefix to bare refs,
#    so the migrate tool resolves them into the gf180mcu_pr library.
mkdir -p "$STAGE/symbols" "$STAGE/tests"
cp -a "$SRC/symbols/." "$STAGE/symbols/"
cp -a "$SRC/tests/."   "$STAGE/tests/"
sed -i 's#symbols/\([A-Za-z0-9_]\+\.sym\)#\1#g' "$STAGE/tests"/*.sch

# 2. Flat -> lib/cell/view + lib-qualified reference rewrite.
#    'devices' is INDEX-ONLY: its FLAT repo copy (xschem_library/devices) is passed purely so the
#    tool can enumerate device cells and rewrite `devices/foo.sym` -> `devices/foo`; the emitted
#    devices/ dir is discarded in step 4 (the registry points at the repo's newsym copy instead).
python3 tools/migrate/xschem_libmigrate.py --dst "$DST" \
  --lib devices=xschem_library/devices \
  --lib gf180mcu_pr="$STAGE/symbols" \
  --lib gf180mcu_tests="$STAGE/tests"

# 3. Cadence-style pin-owned name text (netlist-invariant, idempotent).
python3 tools/migrate/migrate_pin_names.py -r --no-backup "$DST/gf180mcu_pr"
python3 tools/migrate/migrate_pin_names.py -r --no-backup "$DST/gf180mcu_tests"

# 4. Drop the index-only devices dir; write the curated registry (general libs -> newsym).
rm -rf "$DST/devices"
cat > "$DST/library.defs" <<'DEFS'
DEFINE devices ../../xschem_libs_newsym/devices
DEFINE analyses ../../xschem_libs_newsym/analyses
DEFINE examples ../../xschem_libs_newsym/examples
DEFINE ngspice ../../xschem_libs_newsym/ngspice
DEFINE ngspice_verilog_cosim ../../xschem_libs_newsym/ngspice_verilog_cosim
DEFINE xschem_simulator ../../xschem_libs_newsym/xschem_simulator
DEFINE gf180mcu_pr gf180mcu_pr
DEFINE gf180mcu_tests gf180mcu_tests
DEFS

# 5. Vendor the models verbatim (flat, self-contained; preserves the .ngspice -> .spice symlinks).
mkdir -p gf180mcuD/models
cp -a "$MODELS/." gf180mcuD/models/

rm -rf "$STAGE"
```

`cadence_style_rc`, `gf180_procs.tcl`, `run.sh` and this `README.md` are hand-written (not
generated) — copy them from an existing `gf180mcuD/` or adapt `../sky130A/`'s equivalents (set
`::180MCU_MODELS` instead of `::SKYWATER_MODELS`; the model var starting with a digit is legal Tcl).

> The general libs point at `../../xschem_libs_newsym/<lib>` (repo-relative), so this workarea must
> stay **inside** the repo. To make it fully standalone, migrate those libs into `xschem_libs/` too
> and change the `DEFINE`s to local paths.

Regeneration note: the migrate tools are idempotent, so re-running steps 2–3 over an existing tree is
safe. See `doc/claude/specs/gf180mcud_workarea.md` for the tool internals and the sky130A sibling.
