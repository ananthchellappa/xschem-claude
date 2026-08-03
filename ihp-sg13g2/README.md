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
- **Vendored models** in `models/` (436 KB), referenced through `$::MODELS_NGSPICE`,
  plus prebuilt **OSDI** modules in `osdi/` so the Verilog-A devices simulate as shipped.

## Layout

```
xschem_libs/     library.defs + the three migrated PDK libraries
models/          verbatim copy of the PDK's libs.tech/ngspice/models
osdi/            compiled Verilog-A modules (psp103, psp103_nqs, r3_cmc, mosvar)
cadence_style_rc the launch rc (registry + models + procs + menu)
sg13g2_procs.tcl DRC / annotate / menu procs, namespaced sg13g2_*
run.sh
```

## Simulation

All 49 testbenches **netlist** with zero unresolved symbols, and **47 of 49 simulate
clean** in ngspice 46.

The two that do not are upstream bench quirks, not model problems: `IHP_testcases` is the
gallery index page rather than a real bench, and `dc_esd_diodes` has a vector-name bug in
its own `.control` block.

### Verilog-A / OSDI

SG13G2's MOS devices are `psp103va`, its resistors `r3_cmc` and its varicaps `mosvar` —
all Verilog-A, which ngspice loads as compiled **OSDI** modules. They are prebuilt here in
`osdi/` and each bench registers them itself, so simulation works out of the box.

Rebuild them (needed after a change of machine/architecture, or an ngspice upgrade that
bumps the OSDI ABI):

```sh
tools/migrate/build_ihp_osdi.sh          # needs openvaf-r or openvaf on PATH
```

Each bench carries, ahead of its `.lib` lines:

```
.control
pre_osdi $::SG13G2_OSDI/psp103.osdi
pre_osdi $::SG13G2_OSDI/psp103_nqs.osdi
pre_osdi $::SG13G2_OSDI/r3_cmc.osdi
pre_osdi $::SG13G2_OSDI/mosvar.osdi
.endc
```

`pre_osdi`, not `osdi`: the modules must be registered **before** the deck is parsed, or
the device lines are read while the model names are still unknown. A plain `osdi` inside
`.control` runs too late, and ngspice has no `.osdi` dot-card (`unimplemented dot
command`). Carrying it in the netlist rather than in a `.spiceinit` is what makes a bench
portable — `.spiceinit` is only read from the cwd or `$HOME`, and the directory ngspice
runs in is your `netlist_dir`.

The **IHP > Add Ngspice models symbol** menu entry places a block with the same preamble,
so new designs get it too.

Sanity check: `sg13_lv_nmos` W=1 µm, L=0.45 µm at Vgs=1.2 V, Vds=1.5 V draws
**Id ≈ 259 µA**.

## Regenerating from the original source

```sh
tools/migrate/build_ihp_sg13g2.sh [/path/to/IHP-Open-PDK/ihp-sg13g2/libs.tech]
```

Rebuilds `xschem_libs/` and `models/` from the read-only PDK tree. It never touches the
hand-written files in this directory (`cadence_style_rc`, `sg13g2_procs.tcl`, `run.sh`,
this README). The PDK sources are staged into a scratch directory and only the copies
are edited, so the PDK tree is never modified.

`osdi/` is NOT rebuilt by that script — the compiled modules have their own
(`build_ihp_osdi.sh`), so a library re-migration does not require a Verilog-A toolchain.

Three rewrites happen during the build, and all are load-bearing — see the spec for the
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
3. **OSDI registration.** Every block that pulls in a model library also gets the
   `.control pre_osdi … .endc` preamble above. The trigger is "this block references a
   model library", NOT "a path had to be rewritten" — gating it on the rewrite skipped the
   15 benches that already used `$::MODELS_NGSPICE`, which then failed with *Unable to
   find definition of model* for every r3_cmc resistor and mosvar varicap.

## Tests

```sh
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ihp_sg13g2_libmgr.tcl
```

66 checks: the registry lists exactly the 9 intended libraries, the shared libraries
resolve outside this directory, representative cells resolve, the models are present, the
rc wiring is intact, the two migration rewrites above are still in place, and every
model-using bench registers the OSDI modules. Registered
in `tests/run_regression.tcl`.
