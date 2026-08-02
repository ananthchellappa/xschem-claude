# ihp-sg13g2 — IHP SG13G2 Cadence-style design workarea

A self-contained, in-repo design workarea for the **IHP SG13G2** 130 nm SiGe BiCMOS
open PDK: the PDK's xschem libraries migrated to the Cadence-ish `lib/cell/view` layout,
its ngspice models vendored alongside, and a launch rc that layers the repo's
Cadence-style UX on top.

Third sibling of [`sky130A/`](../sky130A/README.md) and
[`gf180mcuD/`](../gf180mcuD/README.md). Spec:
[`doc/claude/specs/ihp_sg13g2_workarea.md`](../doc/claude/specs/ihp_sg13g2_workarea.md).

## Launch

```sh
./ihp-sg13g2/run.sh                 # from the repo root
./ihp-sg13g2/run.sh some_cell.sch   # opening a cell
```

equivalently

```sh
src/xschem --script ihp-sg13g2/cadence_style_rc --logdir /tmp
```

or pick it from the GUI launcher, which fills in the flags for you:

```sh
./pdk_launcher.sh
```

## What you get

- **9 libraries in the Library Manager**: the three migrated PDK libraries —
  `sg13g2_pr` (41 primitives), `sg13g2_stdcells` (80), `sg13g2_tests` (49 testbenches) —
  plus `devices` and the five general libraries, which are **shared** with the rest of
  the repo (`../xschem_libs_newsym/<lib>`) rather than duplicated here.
- **The IHP menu**, inserted before `Netlist`: create a FET/BIP `.save` file, add the
  ngspice models symbol, add a FET or BIP parameter annotator.
- **DRC checks** on primitive dimensions (MOS, resistor, MiM cap, HBT, diode, S-varicap)
  and operating-point annotation, ported from the PDK's `xschem-drc` / `xschem-menu`.
- **Vendored models** in `models/` (436 KB), referenced through `$::MODELS_NGSPICE`.

## Layout

```
xschem_libs/     library.defs + the three migrated PDK libraries
models/          verbatim copy of the PDK's libs.tech/ngspice/models
cadence_style_rc the launch rc (registry + models + procs + menu)
sg13g2_procs.tcl DRC / annotate / menu procs, namespaced sg13g2_*
run.sh
```

## Simulation: what works today

All 49 testbenches **netlist** with zero unresolved symbols. Of those, **22 simulate
clean** in ngspice — HBT, diodes, MiM and parasitic caps, taps, schottky, isolbox.

The other 25 need something this PDK checkout does not ship. SG13G2's MOS models are
`psp103va` — Verilog-A, which ngspice loads as compiled **OSDI** modules. There is no
`osdi/` directory in `IHP-Open-PDK/ihp-sg13g2/libs.tech/ngspice/`, only the Verilog-A
sources under `libs.tech/verilog-a/`. Until those are compiled, any bench with a MOS,
varicap or `r3_cmc` resistor stops at `could not find a valid modelname`.

To enable them:

```sh
cd /home/qflow/dev/IHP-Open-PDK/ihp-sg13g2/libs.tech/verilog-a
./openvaf-compile-va.sh            # needs openvaf on PATH
# then load the modules for your ngspice runs, e.g. in the .spiceinit used for the run:
#   osdi /path/to/psp103.osdi
```

Nothing in this workarea needs to change when you do — the models and netlists are
already correct.

## Regenerating from the original source

```sh
tools/migrate/build_ihp_sg13g2.sh [/path/to/IHP-Open-PDK/ihp-sg13g2/libs.tech]
```

Rebuilds `xschem_libs/` and `models/` from the read-only PDK tree. It never touches the
hand-written files in this directory (`cadence_style_rc`, `sg13g2_procs.tcl`, `run.sh`,
this README). The PDK sources are staged into a scratch directory and only the copies
are edited, so the PDK tree is never modified.

Two rewrites happen during the build, and both are load-bearing — see the spec for the
full reasoning:

1. **Proc namespacing.** The PDK injects very generic proc names (`fet_drc`,
   `save_params`, `display_fet_params`, …) into the global interpreter. The build renames
   both the definitions and the call sites inside the symbols to `sg13g2_*`, so several
   PDK workareas can be loaded without colliding.
2. **Model-path normalization.** 27 benches referenced the corner libraries by bare
   filename, which only resolves via the PDK's own `.spiceinit` and an exported
   `PDK_ROOT`. They are rewritten to `$::MODELS_NGSPICE/<file>` so they resolve from
   anywhere. `.include <cell>.save` lines are deliberately left bare — those are relative
   to the netlist directory.

## Tests

```sh
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ihp_sg13g2_libmgr.tcl
```

57 checks: the registry lists exactly the 9 intended libraries, the shared libraries
resolve outside this directory, representative cells resolve, the models are present, the
rc wiring is intact, and the two migration rewrites above are still in place. Registered
in `tests/run_regression.tcl`.
