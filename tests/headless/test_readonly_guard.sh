#!/bin/sh
# Headless driver for the issue 0041 read-only enforcement regression.
# Proves every mutating `xschem` subcommand is refused on a read-only buffer via the
# Tcl command path, while non-mutating queries still work. Exits 0 on PASS, non-zero
# on FAIL, so it can be wired into CI.

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
xschem="$repo/src/xschem"
export REPO="$repo"

if [ ! -x "$xschem" ]; then
  echo "RESULT: FAIL (xschem binary not built at $xschem)"
  exit 2
fi

out=$("$xschem" --nogui --rcfile "$here/minrc" --pipe -q --nolog \
      --script "$here/test_readonly_guard.tcl" 2>&1)
rc=$?
echo "$out"

if [ "$rc" -eq 0 ] && echo "$out" | grep -q "READONLY_GUARD_TEST_PASS"; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL (rc=$rc)"
  exit 1
fi
