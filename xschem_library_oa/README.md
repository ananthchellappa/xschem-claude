# xschem_library_oa — lib/cell/view layout (pilot)

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

## Scope (pilot)

Currently migrated: **`devices`** and **`examples`**. The remaining libraries
(`logic`, `ngspice`, `rom8k`, …) are a follow-up sweep; until then they keep
working from the flat tree via the legacy search path (resolution falls back to
flat for any reference that is not lib-qualified).

## Try it

```sh
# point xschem at this registry (in xschemrc, or the environment):
#   set XSCHEM_LIBRARY_DEFS /path/to/xschem_library_oa/library.defs
cd src
XSCHEM_LIBRARY_DEFS=$PWD/../xschem_library_oa/library.defs \
  ./xschem ../xschem_library_oa/examples/cmos_inv/schematic/cmos_inv.sch
```

## Regenerate

This tree is produced by the migrator; do not hand-edit it. To regenerate:

```sh
tools/migrate/regen_pilot.sh        # wraps xschem_libmigrate.py
```
