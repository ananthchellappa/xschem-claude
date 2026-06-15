#!/bin/sh
# Regenerate the lib/cell/view tree (xschem_library_oa/) from the flat
# xschem_library/ libraries. Non-destructive: rebuilds only the generated tree;
# the flat source is never touched. The library order below is the reference
# search order (a bare ref resolves to the first library that defines the cell).
#
# Migrated set = the standard cell/design libraries. Intentionally excluded
# (they rely on mechanisms that do not map cleanly to cell/view and keep working
# from the flat tree): generators (on-the-fly .tcl symbol generation),
# inst_sch_select (instance schematic-selection + absolute .cir includes),
# gschem_import (nested sym/ subdir), viewdraw_import (converter tool), symgen
# (.symdef sources).
#
# Run from anywhere; paths are resolved relative to this script.
set -e
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$here/../.." && pwd)

LIBS="devices examples ngspice ngspice_verilog_cosim logic xschem_simulator \
      binto7seg pcb rom8k analyses xTAG rulz-r8c33"

dst="$repo/xschem_library_oa"
# remove only the generated parts; keep the hand-written README.md
rm -f "$dst/library.defs"
for l in $LIBS; do rm -rf "$dst/$l"; done

args=""
for l in $LIBS; do args="$args --lib $l=$repo/xschem_library/$l"; done
# shellcheck disable=SC2086
python3 "$here/xschem_libmigrate.py" --dst "$dst" $args
echo "regenerated $dst"
