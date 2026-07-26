#!/bin/sh
# Launch xschem in the sky130A Cadence-style workarea.
#   ./sky130A/run.sh [cell.sch]
# Resolves paths relative to this script, so it works from anywhere in the repo.
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
exec "$repo/src/xschem" --script "$here/cadence_style_rc" "$@"
