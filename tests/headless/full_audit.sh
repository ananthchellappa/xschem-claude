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

# Tests inherit this process's cwd, and several build paths relative to it
# (fixture copies, scratch dirs). Pin it to the repo root so the audit gives
# every test the same cwd no matter where it was invoked from (a src/ or
# parent-dir invocation used to make relative fixture paths resolve outside
# the repo -> startup Tcl error popup -> hang until timeout).
cd "$REPO" || exit 2

# Tests that need the action log / CIW open -> run with --logdir <tmp>
logdir_tests=" test_ciw test_ciw_autocomplete test_ciw_puts_capture test_hi_descend \
  test_action_log_dispatch test_action_log_libmgr test_context_menu_log \
  test_gesture_end_log test_phase3_mints test_lib_roundtrip test_selflog_output \
  test_altf5_ciw test_undo_link_symbols test_dblclick_connected_grow test_delete_cut_selflog \
  test_descend_goback_selflog test_save_reload_copy_selflog test_selflog_grep_guard \
  test_stdin_tcp_log test_libmgr_mutation_log test_nhse_mutation_log test_paste_at_log \
  test_shape_setprop_log test_sympin_drop_log test_cadence_window_hop_log \
  test_rotmove_drop_log test_netlist_log test_apply_hilight_log \
  test_toggle_editmode_log test_actionlog_suppress_gate test_perform_action_trim_wires \
  test_perform_action_align test_perform_action_rotate_in_place \
  test_perform_action_flip_in_place test_perform_action_flipv_in_place \
  test_perform_action_rotate test_perform_action_flip test_perform_action_flipv \
  test_perform_action_break_wires test_perform_action_floaters_from_selected_inst \
  test_perform_action_attach_labels "
# Tests that must run true-headless (no X needed) -> --nogui
# (test_make_symbol_dialog is designed for --nogui: under X its has_x-gated
# open-in-new-window step runs, and the second make_symbol_dialog on the same
# cell raises a blocking "already open" warning popup -> flaky FAIL/CRASH)
nogui_tests=" test_nogui test_sweep_diff test_make_symbol_dialog "
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
    test_readonly_guard)       [[ "$out" == *"READONLY_GUARD_TEST_PASS"* ]] ;;
    test_readonly_action_dispatch) [[ "$out" == *"ACTION_READONLY_TEST_PASS"* ]] ;;
    *)                         [[ "$out" == *"RESULT: ALL PASS"* && "$out" != *"skipped: no X"* ]] ;;
  esac
}
# "skipped: no X" is the legacy self-skip banner ("RESULT: ALL PASS (0 checks,
# skipped: no X)") -- classified as SKIP so an un-converted test can never count
# as a hollow PASS on a display-less box.
is_skip() { [[ "$1" == *"RESULT: SKIP"* || "$1" == *"skipped: no X"* ]]; }

# Test selection: explicit args, else all test_*.tcl. The 52-test wireedit
# suite (wireedit/run_wireedit.sh, true headless) is part of the full run and
# can be selected explicitly with the pseudo-name "wireedit".
sel=("$@")
run_wireedit=0
if [ "${#sel[@]}" -eq 0 ]; then
  mapfile -t files < <(ls "$HERE"/test_*.tcl | sort)
  run_wireedit=1
else
  files=()
  for s in "${sel[@]}"; do
    case "$s" in wireedit) run_wireedit=1; continue ;; esac
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
  elif [[ "$out" == *"FATAL: signal"* ]] || { [[ "$out" == *"Tcl_AppInit() error"* ]] && ! is_pass "$name" "$out" "$ec"; }; then
    # crash detection BEFORE skip (review wf_bfc3c5e4): a test that prints its skip banner and
    # then dies must count as CRASH, not SKIP (a clean self-skip exit 0's right after the banner,
    # so it can never reach a FATAL/Tcl_AppInit line).
    STATUS[$name]=CRASH; OUT[$name]="$out"; ((CRASH++))
  elif is_skip "$out"; then
    STATUS[$name]=SKIP; ((SKIP++))
  elif is_pass "$name" "$out" "$ec"; then
    STATUS[$name]=PASS; ((PASS++))
  else
    STATUS[$name]=FAIL; OUT[$name]="$out"; ((FAIL++))
  fi
  printf '%-8s | %s\n' "${STATUS[$name]}" "$name"
done

# Wireedit suite: run_wireedit.sh exits nonzero on any FAIL or missing RESULT
# line; its verdict is merged into the audit exit code so a wireedit regression
# fails the audit (hardening plan step A3).
WIREEDIT_RC=0
WIREEDIT_VERDICT="not run (subset selection)"
if [ "$run_wireedit" -eq 1 ]; then
  echo "--------- wireedit suite ---------"
  "$HERE/wireedit/run_wireedit.sh"; WIREEDIT_RC=$?
  if [ "$WIREEDIT_RC" -eq 0 ]; then WIREEDIT_VERDICT="PASS"; else WIREEDIT_VERDICT="FAIL (rc=$WIREEDIT_RC)"; fi
fi

echo "========================================"
echo "SUMMARY: $PASS pass  $FAIL fail  $CRASH crash/timeout  $SKIP skip  (total $((PASS+FAIL+CRASH+SKIP)))"
echo "WIREEDIT: $WIREEDIT_VERDICT"
echo "========================================"

if [ "$((FAIL+CRASH))" -gt 0 ]; then
  echo; echo "=== FAIL / CRASH / TIMEOUT output ==="
  for name in $(printf '%s\n' "${!OUT[@]}" | sort); do
    echo; echo "###### ${STATUS[$name]}: $name ######"; echo "${OUT[$name]}"
  done
  exit 1
fi
[ "$WIREEDIT_RC" -ne 0 ] && exit 1
# Hollow-green guard (review wf_bfc3c5e4): a selection whose tests ALL self-skip (e.g. xvfb
# broke and every gesture test skipped) exits 0 with zero coverage. CI sets AUDIT_MIN_PASS to
# the expected pass floor; default 0 keeps local subset runs unchanged.
if [ "$PASS" -lt "${AUDIT_MIN_PASS:-0}" ]; then
  echo "AUDIT_MIN_PASS: only $PASS pass < required ${AUDIT_MIN_PASS} -- treating as failure (hollow green)"
  exit 1
fi
exit 0
