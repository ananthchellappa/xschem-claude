# gf180mcuD migrated workarea (Cadence-style, in-repo)

Status: EXECUTED 2026-07-20. Self-contained GlobalFoundries 180MCU design workarea at repo-root
`gf180mcuD/`, using the repo's flat→lib/cell/view migration tooling. Sibling of `sky130A/`; ships
with the repo. Launch: `./gf180mcuD/run.sh [cell.sch]` or
`src/xschem --script gf180mcuD/cadence_style_rc`.

## Goal

Capture the open_pdks gf180mcuD xschem tree
(`/home/qflow/dev/open_pdks/gf180mcu/gf180mcuD/libs.tech/xschem`, treated as a read-only SYSTEM dir)
into an in-repo workarea, migrated to the Cadence-ish lib/cell/view format, so that on launch the
migrated libraries appear in the Library Manager and schematics can be designed + netlisted +
simulated (ngspice) with a Cadence-compatible UX. Same pattern as `sky130A/`.

## Why simpler than sky130A

The gf180 open_pdks xschem tree is small and flat:
- **Primitives are symbol-only leaves** (`symbols/*.sym`, 66) — pure SPICE-format devices, NO
  primitive schematics, no deep hierarchy. sky130 had schematic views + stdcells + mips_cpu.
- **Models are tiny and self-contained** (`libs.tech/ngspice`, 784 KB): every `.lib` refers to a
  sibling file by bare name (`sm141064.spice`, `sm141064_mim.spice`, `smbb000149.spice`,
  `design.spice`). No mixed-depth `.include` chain, no transitive-closure trimming — vendor verbatim.
- **No custom PDK procs**: the gf180 xschemrc has no DRC / op-annotate / menu Tcl (sky130's did).
  Device operating-point display is baked into each primitive symbol as hidden `tcleval(gm=..)` /
  `tcleval(id=..)` T lines + the stock `ngspice_backannotate.tcl`.

Result: 2 PDK libs (vs sky130's 5), ~2.8 MB total (vs ~15 MB).

## Layout (`gf180mcuD/`)

```
gf180mcuD/
├── xschem_libs/
│   ├── library.defs                                     # the registry (cds.lib analog)
│   ├── gf180mcu_pr/    <cell>/symbol/<cell>.sym                   (66 primitives)
│   └── gf180mcu_tests/ <cell>/{symbol,schematic}/<cell>.ext      (59 benches + 0_top gallery)
├── models/             copy of libs.tech/ngspice (flat, self-contained, ~784 KB)
├── cadence_style_rc    the launch rc (single --script)
├── gf180_procs.tcl     GF180MCU menu (add models block; models path)
├── run.sh
└── README.md
```

`devices` and the 5 general libs are NOT copied: `library.defs` registers them repo-relative against
the repo's already-migrated newsym tree (`DEFINE devices ../../xschem_libs_newsym/devices`, etc.), so
the Library Manager lists **8 libraries** total (devices, analyses, examples, ngspice,
ngspice_verilog_cosim, xschem_simulator, gf180mcu_pr, gf180mcu_tests). All 9 device cells referenced
by the testbenches (code_shown, title, launcher, lab_pin, vsource, gnd, vdd, res, ammeter) confirmed
present in newsym/devices. Repo-relative links are valid while `gf180mcuD/` lives inside the repo.

## Migration recipe

The gf180 testbenches reference the primitives as `symbols/<cell>.sym` (a dir prefix, not a lib
name), so a **staging pre-normalization** is needed — the migrate tool only rewrites a slashed
`prefix/cell` when `prefix` is a lib NAME, and we want the lib named `gf180mcu_pr`, not `symbols`.

1. Stage sources in scratch (non-destructive) and strip the `symbols/` dir prefix to bare refs so
   the tool's bare-cell resolution maps them to `gf180mcu_pr/<cell>`:
   ```
   cp -a $SRC/symbols/. $STAGE/symbols/ ; cp -a $SRC/tests/. $STAGE/tests/
   sed -i 's#symbols/\([A-Za-z0-9_]\+\.sym\)#\1#g' $STAGE/tests/*.sch
   ```
2. Tool A — flat→lib/cell/view + lib-qualified ref rewrite:
   ```
   tools/migrate/xschem_libmigrate.py --dst gf180mcuD/xschem_libs \
     --lib devices=xschem_library/devices \
     --lib gf180mcu_pr=$STAGE/symbols \
     --lib gf180mcu_tests=$STAGE/tests
   ```
   `devices` is INDEX-ONLY (its FLAT source `xschem_library/devices` is used only to enumerate cells
   so `devices/foo.sym` refs strip to `devices/foo`; its emitted dir is discarded in step 4). Rewrites
   verified: `symbols/nfet_03v3.sym`→`gf180mcu_pr/nfet_03v3`, `test_nfet_03v3.sym`→
   `gf180mcu_tests/test_nfet_03v3` (0_top gallery), `devices/code_shown.sym`→`devices/code_shown`.
3. Tool B — pin-name decorate: `migrate_pin_names.py -r --no-backup gf180mcuD/xschem_libs/gf180mcu_pr`
   (and `.../gf180mcu_tests`). Netlist-invariant; primitive pins gain the Cadence-style pin-owned
   name tokens (66 migrated; the test-wrapper syms are skipped — 0-pin / probe types).
4. Devices fixup: delete `gf180mcuD/xschem_libs/devices/`; replace the generated `library.defs` with
   the curated one (devices + the 5 general libs → `../../xschem_libs_newsym/<lib>`, plus the 2 PDK
   libs local).
5. Models: `cp -a libs.tech/ngspice/. gf180mcuD/models/` — wholesale, self-contained, symlinks
   (`*.ngspice`→`*.spice`) preserved.

## The launch rc (`gf180mcuD/cadence_style_rc`)

Loaded with `xschem --script gf180mcuD/cadence_style_rc`. It:
- sources the repo `src/cadence_style_rc` (Cadence UX + keybindings + find_helper Ctrl+Shift+G /
  instance_update Ctrl+Shift+I), then OVERRIDES the registry to this workarea:
  `XSCHEM_LIBRARY_DEFS=<dir>/xschem_libs/library.defs`, `library_registry_defs_only 1`,
  `XSCHEM_LIBRARY_PATH {}`, `library_default_layout nested`, `launch_library_manager 1`.
- sets `::180MCU_MODELS = <dir>/models` (the testbenches embed
  `.include $::180MCU_MODELS/design.ngspice` + `.lib $::180MCU_MODELS/sm141064.ngspice typical`), and
  sources `gf180_procs.tcl` which adds a GF180MCU menu (append `gf180_menupdk` to
  `user_startup_commands`). NB: the model var starts with a digit — Tcl `set ::180MCU_MODELS` /
  `$::180MCU_MODELS` is legal and matches the PDK's own convention.

## Validation (2026-07-20)

- Registry: headless `library_list` = exactly the 8 intended libs; devices + 5 general libs resolve
  to `xschem_libs_newsym/<lib>` (outside `gf180mcuD/`); cells resolve to real files.
- Netlist: all **59** testbenches netlist through the registry with **0** unresolved symbols.
- Models: with `::180MCU_MODELS` set, the MODELS `tcleval` block expands to
  `.include <models>/design.ngspice` + `.lib <models>/sm141064.ngspice typical`. (When the var is
  unset the block silently drops — set it, as the rc does.)
- ngspice: clean run; `nfet_03v3` (W=1u, L=0.28u, Vgs=Vds=3.3 V) draws **Id ≈ 520 µA** — sane 3.3 V
  nfet current, models work end-to-end.
- Regression smoke: `tests/headless/test_gf180mcud_libmgr.tcl` (29 checks, registered in
  `run_regression.tcl` hcases). Sabotage-verified: drop a DEFINE → FAIL.

## Regeneration

Re-run the migration recipe above (steps 1–5). See [[sky130_workarea]] for the sibling and
`doc/claude/code_analysis/library_manager_design.md` for the tool design.
