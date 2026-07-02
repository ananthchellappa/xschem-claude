#!/bin/sh
# GUI driver for the issue 0041 residual regression (action-dispatch read-only enforcement
# via the action_registry `mutates` flag). REQUIRES a real X display; SKIPs (exit 0) when
# none is available, since the keybinding path needs Tk + a mapped canvas.

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
xschem="$repo/src/xschem"
export REPO="$repo"

if [ ! -x "$xschem" ]; then
  echo "RESULT: FAIL (xschem binary not built at $xschem)"
  exit 2
fi
if [ -z "$DISPLAY" ]; then
  echo "RESULT: SKIP (no DISPLAY; this test needs X)"
  exit 0
fi

out=$(timeout 120 "$xschem" --rcfile "$here/minrc" --pipe -q --nolog \
      --script "$here/test_readonly_action_dispatch.tcl" 2>&1)
rc=$?
echo "$out" | grep -E "ok:|FAIL:|ACTION_READONLY"

if [ "$rc" -eq 0 ] && echo "$out" | grep -q "ACTION_READONLY_TEST_PASS"; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL (rc=$rc)"
  exit 1
fi
