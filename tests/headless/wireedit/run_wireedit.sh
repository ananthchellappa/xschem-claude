#!/bin/sh
# Aggregate every test_wireedit_*.tcl in this dir: print each RESULT line and exit
# nonzero if any test FAILS or produces no RESULT. Spec: Phase 0.2.
#
# These tests drive the real edit dispatch and need an X display; honors $DISPLAY
# (defaults to :0). Run from anywhere -- it locates the repo root relative to itself.
root=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$root" || exit 2
fail=0
ran=0
for t in tests/headless/wireedit/test_wireedit_*.tcl; do
  [ -e "$t" ] || continue
  ran=$((ran + 1))
  out=$(DISPLAY="${DISPLAY:-:0}" timeout 60 ./src/xschem --pipe -q --nolog --script "$t" 2>&1)
  line=$(printf '%s\n' "$out" | grep -E '^RESULT:' | tail -1)
  echo "$(basename "$t"): ${line:-NO RESULT}"
  case "$line" in
    "RESULT: ALL PASS") ;;
    *) fail=1 ;;
  esac
done
if [ "$ran" -eq 0 ]; then echo "WIREEDIT: no tests found"; exit 2; fi
if [ "$fail" -eq 0 ]; then echo "WIREEDIT: ALL PASS"; else echo "WIREEDIT: FAILURES"; fi
exit $fail
