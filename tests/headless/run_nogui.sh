#!/bin/sh
# Headless smoke test driver for the --nogui flag.
#
# Proves that "xschem --nogui ..." opens no window (Tk is never loaded) even when
# DISPLAY is set, yet still loads and netlists a schematic. Exits 0 on PASS,
# non-zero on FAIL, so it can be wired into CI / run_regression.tcl.

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
xschem="$repo/src/xschem"

if [ ! -x "$xschem" ]; then
  echo "RESULT: FAIL (xschem binary not built at $xschem)"
  exit 2
fi

# A small, dependency-light example to load + netlist.
sch="$repo/xschem_library/examples/rc_filter.sch"
if [ ! -f "$sch" ]; then
  sch=$(ls "$repo"/xschem_library/examples/*.sch 2>/dev/null | head -1)
fi
XSCHEM_NOGUI_TESTSCH="$sch"
export XSCHEM_NOGUI_TESTSCH

# Deliberately keep DISPLAY as-is (typically set in dev/CI): the whole point is
# that --nogui must win over an available X server.
out=$("$xschem" --nogui --pipe -q --script "$here/test_nogui.tcl" 2>&1)
rc=$?
echo "$out"

if [ "$rc" -eq 0 ] && echo "$out" | grep -q "NOGUI_TEST_PASS"; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL (rc=$rc)"
  exit 1
fi
