#!/bin/sh
# Regenerate the pilot lib/cell/view tree (xschem_library_oa/) from the flat
# xschem_library/ libraries. Non-destructive: removes and rebuilds only the
# generated tree; the flat source is never touched.
#
# Run from the repo root (or anywhere; paths are resolved relative to this script).
set -e
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$here/../.." && pwd)

dst="$repo/xschem_library_oa"
# remove only the generated parts; keep the hand-written README.md
rm -rf "$dst/devices" "$dst/examples" "$dst/library.defs"
python3 "$here/xschem_libmigrate.py" --dst "$dst" \
  --lib devices="$repo/xschem_library/devices" \
  --lib examples="$repo/xschem_library/examples"
echo "regenerated $dst"
