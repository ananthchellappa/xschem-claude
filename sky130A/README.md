# sky130A — Cadence-style sky130 design workarea

A self-contained sky130 analog/mixed-signal design environment for xschem, built from the
open_pdks sky130 xschem tree migrated into the repo's Cadence-ish **lib/cell/view** format.
On launch the migrated libraries appear in the Library Manager and you can draw → netlist →
simulate (ngspice) with the Cadence-compatible UX.

## Launch

```sh
./sky130A/run.sh [cell.sch]            # from the repo root
# or directly:
src/xschem --script sky130A/cadence_style_rc [cell.sch]
```

The Library Manager opens showing the migrated libraries. Cadence UX is active:
crosshair, `cadence_compat`, connected stretch/move, and the custom forms
**Find Navigator** (Ctrl+Shift+G) and **Instance Update** (Ctrl+Shift+I).

## Libraries (Library Manager)

| Library | Cells | Notes |
|---|---|---|
| `sky130_fd_pr`    | 77  | analog device PCells (nfet/pfet/cap/res/diode/bjt) |
| `sky130_stdcells` | 437 | sky130_fd_sc_hd digital standard-cell symbols |
| `sky130_tests`    | 81  | example testbenches (symbol + schematic views) |
| `mips_cpu`        | 12  | MIPS CPU verilog-port example |
| `stdcells`        | 76  | process-agnostic digital draft (used by a couple of tests) |
| `devices`         | —   | the standard xschem device lib — referenced from `../xschem_libs_newsym/devices` (not duplicated) |

All cross-references are lib-qualified (`C {sky130_fd_pr/nfet_01v8}`, `C {devices/vsource}`),
resolved through `xschem_libs/library.defs` (registry-only mode).

## Layout

```
sky130A/
├── xschem_libs/     library.defs + <lib>/<cell>/{symbol,schematic}/<cell>.<ext>
├── models/          vendored mini-PDK: libs.tech/combined + libs.ref/sky130_fd_pr/spice
│                    (SPICE models; the tt corner + its 128-file model closure, ~4.7 MB)
├── cadence_style_rc the launch rc (UX + registry + models)
├── sky130_procs.tcl sky130 helper procs (DRC, FET op-point save/annotate, SKY130 menu)
└── README.md
```

## Models

Models are vendored under `models/` as a minimal mirror of the PDK
(`models/libs.tech/combined` + the referenced `models/libs.ref/sky130_fd_pr/spice`) so the
relative `.include` paths resolve without the full open_pdks install. `corner.sym` emits
`.lib $::SKYWATER_MODELS/sky130.lib.spice <corner>`; drop a `sky130_fd_pr/corner` symbol into a
top-level schematic and pick the corner (`tt`/`ss`/`ff`/…).

## Design flow

1. New schematic; place devices from `sky130_fd_pr` (set W/L/nf; min-size DRC warns).
2. Add supplies/pins from `devices`; add `sky130_fd_pr/corner` for models.
3. Put `.tran`/`.dc`/`.op`/`.control` in a `devices/simulator_commands_shown` symbol.
4. Netlist (SPICE) → `netlist_dir`; simulate with ngspice.

Regenerate the libraries from the PDK with `tools/migrate/xschem_libmigrate.py` — see
`doc/claude/specs/sky130_workarea.md`.
