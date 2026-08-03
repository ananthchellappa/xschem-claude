#!/bin/bash
# build_diff_amp_osdi.sh — compile xschem's `diff_amp` Verilog-A example into the
# OSDI module its testbenches load.
#
#   tools/migrate/build_diff_amp_osdi.sh [DESTDIR]
#
# DESTDIR defaults to $USER_CONF_DIR/xschem_library, i.e. ~/.xschem/xschem_library.
#
# WHY: sky130_tests/diff_amp's SYMBOL carries the model in its `device_model`
# attribute, and that block ends with
#
#     .control
#     pre_osdi $USER_CONF_DIR/xschem_library/diff_amp.osdi
#     .endc
#
# so the netlister emits that line into every deck that instantiates the cell.
# Nothing ships the compiled artifact, so `sky130_tests_ase/tb_diff_amp` and
# `…/top` (which instantiates tb_diff_amp) both die at
#
#     Error opening osdi lib ".../.xschem/xschem_library/diff_amp.osdi":
#     No such file or directory!
#
# This is NOT a migration defect — the path never passes through the ASE state,
# and the CLUTTERED originals fail identically (issue 0210 bucket E). It is a
# workarea-setup gap, and this script closes it.
#
# The .osdi is a COMPILED BINARY for this host's architecture. Re-run after
# changing machine/architecture or upgrading ngspice across an OSDI ABI bump.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
SRC=$REPO/xschem_library/ngspice/diff_amp.va
DEST=${1:-${USER_CONF_DIR:-$HOME/.xschem}/xschem_library}

[ -f "$SRC" ] || { echo "no Verilog-A source: $SRC" >&2; exit 1; }

# OpenVAF-Reloaded first, matching build_ihp_osdi.sh's preference order.
if command -v openvaf-r >/dev/null 2>&1; then
  COMPILER=openvaf-r
elif command -v openvaf >/dev/null 2>&1; then
  COMPILER=openvaf
else
  echo "no Verilog-A compiler: install 'openvaf-r' or 'openvaf'" >&2
  exit 1
fi

mkdir -p "$DEST"
echo "compiling $SRC with $COMPILER"
"$COMPILER" -o "$DEST/diff_amp.osdi" "$SRC"
ls -la "$DEST/diff_amp.osdi"
echo "done -> $DEST/diff_amp.osdi"
