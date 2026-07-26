# sky130A migrated workarea (Cadence-style, in-repo)

Status: EXECUTED 2026-07-20. Self-contained sky130 design workarea at repo-root `sky130A/`,
using the repo's flat→lib/cell/view migration tooling. Ships with the repo.

## Goal

Capture the bare minimum of the open_pdks sky130 xschem tree
(`/home/qflow/dev/open_pdks/sky130/sky130A/libs.tech/xschem`, treated as a read-only SYSTEM dir)
into an in-repo workarea, migrated to the Cadence-ish lib/cell/view format, so that on launch the
migrated libraries appear in the Library Manager and schematics can be designed + netlisted +
simulated with a Cadence-compatible UX.

## Layout (`sky130A/`, committed)

```
sky130A/
├── xschem_libs/
│   ├── library.defs                                   # the registry (cds.lib analog)
│   ├── sky130_fd_pr/    <cell>/symbol/<cell>.sym                 (77)
│   ├── sky130_stdcells/ <cell>/symbol/<cell>.sym                 (437)
│   ├── sky130_tests/    <cell>/{symbol,schematic}/<cell>.ext     (78 sym / 76 sch)
│   ├── mips_cpu/        <cell>/{symbol,schematic}/<cell>.ext     (12 / 12)
│   └── stdcells/        <cell>/symbol/<cell>.sym                 (76, draft digital)
├── models/                                            # copy of libs.tech/combined (~3.3 MB)
├── cadence_style_rc                                   # the launch rc (single --script)
└── README.md
```

`devices` is NOT copied: `library.defs` registers it against the repo's already-migrated
`xschem_libs_newsym/devices` (all 39 referenced device cells confirmed present). Repo-relative link
`DEFINE devices ../../xschem_libs_newsym/devices` — valid while `sky130A/` lives inside the repo.

The workarea also exposes five more of the repo's migrated general-purpose libraries the same way
(repo-relative `DEFINE <lib> ../../xschem_libs_newsym/<lib>`): `analyses`, `examples`, `ngspice`,
`ngspice_verilog_cosim`, `xschem_simulator` — so the Library Manager lists 11 libraries total.
(A handful of `examples` cells also reach `rom8k`/`logic`, which are not registered; register those
two similarly if full resolution of every example is wanted.)

## Migration recipe

1. Tool A — flat→lib/cell/view + lib-qualified ref rewrite:
   `tools/migrate/xschem_libmigrate.py --dst sky130A/xschem_libs --lib devices=xschem_library/devices
    --lib sky130_fd_pr=$SKY/sky130_fd_pr --lib sky130_stdcells=$SKY/sky130_stdcells
    --lib sky130_tests=$SKY/sky130_tests --lib mips_cpu=$SKY/mips_cpu --lib stdcells=$SKY/stdcells`
   (`devices` is INDEX-ONLY, so `devices/foo.sym` refs strip to `devices/foo`; its emitted dir is
   discarded in step 3.) Rewrite verified on sky130's already-slashed refs
   (`devices/vsource.sym`→`devices/vsource`, `sky130_fd_pr/nfet_01v8.sym`→`sky130_fd_pr/nfet_01v8`).
2. Tool B — pin-name decorate: `migrate_pin_names.py -r --no-backup sky130A/xschem_libs`
   (netlist-invariant; pins own their name text — Cadence style, matches xschem_libs_newsym).
3. Devices fixup: delete `sky130A/xschem_libs/devices/`; in `library.defs` replace
   `DEFINE devices devices` with `DEFINE devices ../../xschem_libs_newsym/devices`.
4. Models: `combined/` is NOT self-contained — its `corners/*.spice` `.include` device models
   from `libs.ref/sky130_fd_pr/spice/` via relative paths at mixed depths (`../../../` and
   `../../../../libs.ref`). So vendor a minimal mirror of the PDK's `sky130A/` root:
   `models/libs.tech/combined` (copy) + `models/libs.ref/sky130_fd_pr/spice/` (the 128-file
   transitive closure the tt corner needs, ~1.1 MB). `SKYWATER_MODELS = models/libs.tech/combined`.
   Total ~4.7 MB, self-contained (full 48 MB `libs.ref/sky130_fd_pr/spice` NOT vendored).

## The launch rc (`sky130A/cadence_style_rc`)

Loaded with `xschem --script sky130A/cadence_style_rc`. It:
- sources the repo `src/cadence_style_rc` (Cadence UX + keybindings + the find_helper Ctrl+Shift+G /
  instance_update Ctrl+Shift+I forms), then OVERRIDES the library registry to this workarea:
  `XSCHEM_LIBRARY_DEFS=<dir>/xschem_libs/library.defs`, `library_registry_defs_only 1`,
  `XSCHEM_LIBRARY_PATH {}`, `library_default_layout nested`, `launch_library_manager 1`.
- sets `::SKYWATER_MODELS = <dir>/models` and carries the sky130 helper procs
  (`sky130_fet_drc`, `sky130_save_fet_params`, `sky130_write_save_lines`, the SKY130 menu) copied
  from the PDK xschemrc — self-contained, no PDK_ROOT needed. corner.sym emits
  `.lib $::SKYWATER_MODELS/sky130.lib.spice tt`.

See [[sky130-workarea-setup]] (env/rc gotchas), [[find-helper-port]], [[instance-update-port]].
