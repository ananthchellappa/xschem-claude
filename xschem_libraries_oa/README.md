# xschem_libraries_oa — lib/cell/view layout

This is a **generated**, sibling copy of part of `../xschem_library/` converted to
the Cadence/OpenAccess-style **library / cell / view** layout. The original flat
`../xschem_library/` is left **completely untouched** — early adopters can place
the two side by side and diff them:

```
diff -r ../xschem_library/devices  devices     # (after accounting for the view dirs)
```

## What changed

| Flat (legacy)                         | lib/cell/view (here)                          |
|---------------------------------------|-----------------------------------------------|
| `devices/res.sym`                     | `devices/res/symbol/res.sym`                  |
| `examples/cmos_inv.sch`               | `examples/cmos_inv/schematic/cmos_inv.sch`    |
| `examples/cmos_inv.sym`               | `examples/cmos_inv/symbol/cmos_inv.sym`       |
| `C {nmos4.sym}` (resolved by path)    | `C {devices/nmos4}` (lib-qualified)           |

A `library.defs` registry (the `cds.lib` analog) maps each library name to its
directory (relative to this file). The **file record format is unchanged** — only
the directory layout and the reference strings differ.

## Scope

Migrated (12 standard cell/design libraries): **devices, examples, ngspice,
ngspice_verilog_cosim, logic, xschem_simulator, binto7seg, pcb, rom8k, analyses,
xTAG, rulz-r8c33**.

Intentionally **left flat** (they rely on mechanisms that do not map cleanly to
cell/view; they keep working from the flat tree via the legacy search path):

| Library            | Why it stays flat                                      |
|--------------------|--------------------------------------------------------|
| `generators`       | on-the-fly `.tcl` symbol generation                    |
| `inst_sch_select`  | instance schematic-selection + absolute `.cir` includes|
| `gschem_import`    | nested `sym/` subdirectory (a library within a library)|
| `viewdraw_import`  | a format-converter tool, not a symbol library          |
| `symgen`           | `.symdef` generator sources, not `.sym`/`.sch`         |

Resolution falls back to the flat search path for any reference that is not
lib-qualified, so the excluded libraries and any not-yet-migrated user designs
keep working unchanged.

## Try it

```sh
# point xschem at this registry (in xschemrc, or the environment):
#   set XSCHEM_LIBRARY_DEFS /path/to/xschem_libraries_oa/library.defs
cd src
XSCHEM_LIBRARY_DEFS=$PWD/../xschem_libraries_oa/library.defs \
  ./xschem ../xschem_libraries_oa/examples/cmos_inv/schematic/cmos_inv.sch
```

## Regenerate

This tree is produced by the migrator; do not hand-edit it. To regenerate:

```sh
tools/migrate/regen_oa.sh           # wraps xschem_libmigrate.py
```
