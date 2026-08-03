#!/bin/bash
# build_ihp_osdi.sh — compile the IHP SG13G2 Verilog-A models into OSDI modules
# for the in-repo ihp-sg13g2/ workarea.
#
#   tools/migrate/build_ihp_osdi.sh [VA_SRC_DIR]
#
# VA_SRC_DIR defaults to
#   /home/qflow/dev/IHP-Open-PDK/ihp-sg13g2/libs.tech/verilog-a
#
# Output: ihp-sg13g2/osdi/{psp103,psp103_nqs,r3_cmc,mosvar}.osdi
#
# WHY these are needed: SG13G2's MOS models are psp103va / pspnqs103va and its
# resistors r3_cmc — Verilog-A, which ngspice loads as compiled OSDI shared
# objects. Without them any bench containing a MOS, varicap or r3_cmc resistor
# netlists cleanly and then fails at `could not find a valid modelname`.
#
# This deliberately does NOT use the PDK's own openvaf-compile-va.sh: that script
# writes into `../ngspice/osdi`, i.e. into the read-only PDK tree. The workarea
# keeps its own copy so it stays self-contained.
#
# The .osdi files are COMPILED BINARIES for this host's architecture. Re-run this
# script after changing machine/architecture or upgrading ngspice across an OSDI
# ABI bump. See doc/claude/specs/ihp_sg13g2_workarea.md.
set -euo pipefail

SRC=${1:-/home/qflow/dev/IHP-Open-PDK/ihp-sg13g2/libs.tech/verilog-a}
REPO=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$REPO/ihp-sg13g2/osdi

[ -d "$SRC" ] || { echo "no Verilog-A source dir: $SRC" >&2; exit 1; }

# OpenVAF-Reloaded first, matching the PDK's own preference order.
if command -v openvaf-r >/dev/null 2>&1; then
  COMPILER=openvaf-r
elif command -v openvaf >/dev/null 2>&1; then
  COMPILER=openvaf
else
  echo "no Verilog-A compiler: install 'openvaf-r' or 'openvaf'" >&2
  exit 1
fi
echo "compiling with $COMPILER"

mkdir -p "$OUT"
for pair in \
  "psp103/psp103.va:psp103.osdi" \
  "psp103/psp103_nqs.va:psp103_nqs.osdi" \
  "r3_cmc/r3_cmc.va:r3_cmc.osdi" \
  "mosvar/mosvar.va:mosvar.osdi"
do
  va=${pair%%:*}; osdi=${pair##*:}
  echo "  $va -> $osdi"
  # -D__NGSPICE__ selects the ngspice-flavoured code paths in the CMC sources.
  "$COMPILER" -D__NGSPICE__ -o "$OUT/$osdi" "$SRC/$va"
done

echo
ls -la "$OUT"
echo "done -> $OUT"
