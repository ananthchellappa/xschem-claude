#!/bin/sh
# Headless driver for the issue 0041 read-only enforcement regression.
# Proves every mutating `xschem` subcommand is refused on a read-only buffer via the
# Tcl command path, while non-mutating queries still work. Exits 0 on PASS, non-zero
# on FAIL, so it can be wired into CI.

here=$(cd "$(dirname "$0")" && pwd)

# Route this run onto the private/persistent GUI-test display instead of the
# screen it was launched from (tests/headless/xvfb_arm.sh, spec
# doc/claude/specs/dev_display.md). POSIX sh cannot source the arm -- it is
# bash -- so re-exec through its --arm entry. AUDIT_DISPLAY=:0 opts back in.
[ "${XSCHEM_XVFB_ARM:-0}" = 1 ] || exec bash "$here/xvfb_arm.sh" --arm sh "$0" "$@"
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
