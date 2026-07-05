#!/bin/bash
#
# full_audit.sh — portable headless test audit.
#
# Runs every tests/headless/test_*.tcl with the flags it needs, classifies each
# as PASS / FAIL / CRASH / TIMEOUT / SKIP, prints a summary, and exits non-zero
# if anything FAILED, CRASHED, or TIMED OUT (SKIP and PASS are fine).
#
# Portable (vs the original machine-specific version):
#   * repo root + binary resolved relatively; override the binary with $XSCHEM
#   * no hard-coded DISPLAY — GUI tests self-SKIP when $DISPLAY is unset (they
#     guard on `winfo exists .`); under a real/virtual X (xvfb-run) they run
#   * per-test timeout via $AUDIT_TIMEOUT (default 120s)
#
# Usage:
#   tests/headless/full_audit.sh                 # all tests
#   tests/headless/full_audit.sh test_sweep_diff test_multi_window   # a subset
#   XSCHEM=/path/to/xschem xvfb-run -a tests/headless/full_audit.sh  # in CI
#
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="${XSCHEM:-$REPO/src/xschem}"
TIMEOUT="${AUDIT_TIMEOUT:-120}"

if [ ! -x "$XSCHEM" ]; then
  echo "FATAL: xschem binary not found/executable at: $XSCHEM (build with: cd src && make, or set \$XSCHEM)" >&2
  exit 2
fi

# Tests that need the action log / CIW open -> run with --logdir <tmp>
logdir_tests=" test_ciw test_ciw_autocomplete test_ciw_puts_capture test_hi_descend \
  test_action_log_dispatch test_action_log_libmgr test_context_menu_log \
  test_gesture_end_log test_phase3_mints test_lib_roundtrip test_selflog_output \
  test_altf5_ciw test_undo_link_symbols "
# Tests that must run true-headless (no X needed) -> --nogui
nogui_tests=" test_nogui test_sweep_diff "
# test_nolog exercises --nolog mode explicitly
nolog_tests=" test_nolog "

in_list() { case "$2" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# A test PASSES on "RESULT: ALL PASS"; a handful use their own banner.
is_pass() {
  local name="$1" out="$2" ec="$3"
  case "$name" in
    test_palette)              [ "$ec" -eq 0 ] && [[ "$out" == *"EVENT opens palette: yes"* ]] ;;
    test_ciw_autocomplete)     [[ "$out" == *"PASS: ciw autocomplete (0 failure(s))"* ]] ;;
    test_ciw_puts_capture)     [[ "$out" == *"PASS: ciw puts-capture (0 failure(s))"* ]] ;;
    test_lib_new_discovered_defs) [[ "$out" == *"RESULT: all passed"* ]] ;;
    test_nogui)                [[ "$out" == *"NOGUI_TEST_PASS"* ]] ;;
    *)                         [[ "$out" == *"RESULT: ALL PASS"* ]] ;;
  esac
}
is_skip() { [[ "$1" == *"RESULT: SKIP"* ]]; }

# Test selection: explicit args, else all test_*.tcl
sel=("$@")
if [ "${#sel[@]}" -eq 0 ]; then
  mapfile -t files < <(ls "$HERE"/test_*.tcl | sort)
else
  files=()
  for s in "${sel[@]}"; do
    s="${s%.tcl}"; files+=("$HERE/$(basename "$s").tcl")
  done
fi

PASS=0 FAIL=0 CRASH=0 SKIP=0
declare -A STATUS OUT

for testfile in "${files[@]}"; do
  name=$(basename "$testfile" .tcl)
  [ -f "$testfile" ] || { echo "MISSING | $name"; STATUS[$name]=FAIL; OUT[$name]="no such test file"; ((FAIL++)); continue; }

  if in_list "$name" "$logdir_tests"; then
    tmpd=$(mktemp -d)
    if [ "$name" = "test_action_log_libmgr" ]; then
      out=$(timeout "$TIMEOUT" env XSCHEM_AL_LOGDIR="$tmpd" "$XSCHEM" --pipe -q --logdir "$tmpd" --script "$testfile" 2>&1); ec=$?
    else
      out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --logdir "$tmpd" --script "$testfile" 2>&1); ec=$?
    fi
    rm -rf "$tmpd"
  elif in_list "$name" "$nogui_tests"; then
    out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --nogui --script "$testfile" 2>&1); ec=$?
  elif in_list "$name" "$nolog_tests"; then
    out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --script "$testfile" 2>&1); ec=$?
  else
    out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --script "$testfile" 2>&1); ec=$?
  fi

  if [ "$ec" -eq 124 ]; then
    STATUS[$name]=TIMEOUT; OUT[$name]="$out"; ((CRASH++))
  elif is_skip "$out"; then
    STATUS[$name]=SKIP; ((SKIP++))
  elif [[ "$out" == *"FATAL: signal"* ]] || { [[ "$out" == *"Tcl_AppInit() error"* ]] && ! is_pass "$name" "$out" "$ec"; }; then
    STATUS[$name]=CRASH; OUT[$name]="$out"; ((CRASH++))
  elif is_pass "$name" "$out" "$ec"; then
    STATUS[$name]=PASS; ((PASS++))
  else
    STATUS[$name]=FAIL; OUT[$name]="$out"; ((FAIL++))
  fi
  printf '%-8s | %s\n' "${STATUS[$name]}" "$name"
done

echo "========================================"
echo "SUMMARY: $PASS pass  $FAIL fail  $CRASH crash/timeout  $SKIP skip  (total $((PASS+FAIL+CRASH+SKIP)))"
echo "========================================"

if [ "$((FAIL+CRASH))" -gt 0 ]; then
  echo; echo "=== FAIL / CRASH / TIMEOUT output ==="
  for name in $(printf '%s\n' "${!OUT[@]}" | sort); do
    echo; echo "###### ${STATUS[$name]}: $name ######"; echo "${OUT[$name]}"
  done
  exit 1
fi
exit 0
