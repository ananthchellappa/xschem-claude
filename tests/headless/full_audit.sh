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
  test_key_make_sch_from_sel_log \
  test_coordlog_precision test_wave_tabs \
  test_stdin_tcp_log test_libmgr_mutation_log test_nhse_mutation_log test_paste_at_log \
  test_shape_setprop_log test_sympin_drop_log test_cadence_window_hop_log \
  test_rotmove_drop_log test_netlist_log test_apply_hilight_log \
  test_toggle_editmode_log test_actionlog_suppress_gate test_perform_action_trim_wires \
  test_perform_action_align test_perform_action_rotate_in_place \
  test_perform_action_flip_in_place test_perform_action_flipv_in_place \
  test_perform_action_rotate test_perform_action_flip test_perform_action_flipv \
  test_perform_action_break_wires test_perform_action_floaters_from_selected_inst \
  test_perform_action_attach_labels test_perform_action_toggle_ignore \
  test_perform_action_reset_inst_prop test_perform_action_replace_symbol \
  test_perform_action_show_unconnected_pins test_perform_action_embed_rawfile \
  test_perform_action_wire_cut test_perform_action_apply_pin_prop \
  test_perform_action_move_instance test_perform_action_image \
  test_perform_action_change_elem_order test_perform_action_reset_symbol \
  test_perform_action_instance_number test_perform_action_delete \
  test_perform_action_add_pin_stubs test_perform_action_check_unique_names \
  test_perform_action_clear_drawing test_perform_action_redo \
  test_perform_action_undo "
# Tests that must run true-headless (no X needed) -> --nogui
# (test_make_symbol_dialog is designed for --nogui: under X its has_x-gated
# open-in-new-window step runs, and the second make_symbol_dialog on the same
# cell raises a blocking "already open" warning popup -> flaky FAIL/CRASH)
# (test_verilog_view_model is pure view-model logic and needs no display; it is
# pinned here so its ASE-dispatch check cannot open a real ASE toplevel under X)
# (test_vcd_read is a pure file-parser/data-model test -- it only reads VCD and
# .raw files into the Raw registry and never draws, so it needs no display)
# (test_ase_cosim drives ase:: procs, the raw registry and the wviewer attach
# seam with its three Tk helpers stubbed -- no display, and pinned here so its
# `xschem load` of fixture schematics cannot land in a real editor window)
# (test_raw_ascii_point_bounds only feeds malformed ascii rawfiles to the Raw
# reader and never draws; issue 0213)
# (test_vcd_time_base reads a synthesized .raw and .vcd into the Raw registry and
# compares time columns -- pure data model, no drawing, verified with DISPLAY
# unset; spec D3/H3)
# (test_raw_read_dispatch reads table/vcd/raw files into the Raw registry; its
# end-to-end group calls open_sub_schematic / hi_descend, which open a new
# window but need no display -- whole file verified with DISPLAY unset; 0290)
# (test_node_token_split drives the graph hit-testers, the bold envelope and the
# marker readout over a synthesized raw+VCD pair through `xschem get`/`xschem
# graph_marker` verbs only -- no canvas is ever drawn, so it is true-headless;
# issue 0305)
# (test_raw_read_failure_0306 feeds non-regular paths and missing files to the
# Raw readers and drives `set raw_level`; every crash-provoking sequence runs in
# a spawned --nogui child, so the parent never draws and never dies -- issue 0306)
nogui_tests=" test_nogui test_sweep_diff test_make_symbol_dialog test_ase_core test_ase_final test_ase_final_gf180 test_verilog_view_model test_vcd_read test_ase_cosim test_raw_ascii_point_bounds test_vcd_time_base test_raw_read_dispatch test_raw_read_failure_0306 test_node_token_split test_wave_cursor_crossdb test_backannotate_digital test_cosim_golden_e2e "
# test_nolog exercises --nolog mode explicitly
nolog_tests=" test_nolog "

in_list() { case "$2" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# A test PASSES on "RESULT: ALL PASS" or on the older run_regression sentinel
# "OVERALL: ok"; a handful use their own banner.
#
# Both banners are accepted because ~5 shipped tests (test_wire_split,
# test_crossview_paste, test_pin_type_edit, test_add_pin_lib_symbol_view,
# test_select_at) only ever print "OVERALL: ok" -- they were scored FAIL here
# forever while passing every one of their own checks (red-but-hollow, the
# inverse of issue 0147). "OVERALL: notok"/"OVERALL: FAIL" are the failure
# banners and are not substrings of "OVERALL: ok", so the test still fails.
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
    # third banner shape: "<name> headless: all checks passed" / "... N FAILURE(S)"
    # (test_cadence_descend_newwin_ro passes every check but was scored FAIL;
    # test_hi_descend shares the banner and really does fail one check)
    test_cadence_descend_newwin_ro|test_hi_descend) \
                               [[ "$out" == *"headless: all checks passed"* ]] && ! is_skip "$out" ;;
    *)                         [[ "$out" == *"RESULT: ALL PASS"* || "$out" == *"OVERALL: ok"* ]] \
                                 && ! is_skip "$out" ;;
  esac
}
# "skipped: no X" is the legacy self-skip banner ("RESULT: ALL PASS (0 checks,
# skipped: no X)") -- classified as SKIP so an un-converted test can never count
# as a hollow PASS on a display-less box. is_skip runs BEFORE is_pass, which is
# what keeps the "OVERALL: ok" arm above honest: every X-gated self-skip prints
# "RESULT: SKIP (no X)" (or, for test_grid_toggle_sel_gc, "SKIP: no X
# connection") next to its "OVERALL: ok" and is classified SKIP, not PASS.
is_skip() { [[ "$1" == *"RESULT: SKIP"* || "$1" == *"skipped: no X"* \
               || "$1" == *"SKIP: no X connection"* ]]; }

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

# Scratch-leak detector (issue 0148). Tests mkdir a per-pid `_<tag>_<pid>` dir
# and delete it on their last line, so any test that exits early, errors, or
# crashes orphans one in the working tree -- invisible in `git status` because
# .gitignore hides the pattern. Snapshot before/after, report what the run left
# behind, and remove it. Every test now goes through tests/headless/scratch.tcl,
# so the expected count is 0 and a leak is FATAL by default -- that enforcement
# is the whole point of issue 0148 (the class recurred twice because nothing
# checked). Set AUDIT_STRICT_SCRATCH=0 to downgrade it to a warning.
scratch_snapshot() {
  ls -1d "$REPO"/_*_[0-9]* "$REPO"/tests/_*_[0-9]* "$HERE"/_*_[0-9]* \
         "$REPO"/src/_*_[0-9]* 2>/dev/null | sort
}
SCRATCH_BEFORE=$(scratch_snapshot)

# GUI-test control gate: warn the user before the suite runs and give
# Pause/Resume during it (tests/headless/gui_gate.sh). Fails open (no DISPLAY /
# GUI_GATE=0 / no panel -> just runs). A Stop press aborts the remaining tests.
# shellcheck source=/dev/null
. "$HERE/gui_gate.sh" 2>/dev/null || true
_ntests=${#files[@]}
if type gate_start >/dev/null 2>&1; then
  gate_start "full_audit: $_ntests tests ($(basename "${files[0]:-?}") ...)" || {
    echo "gui_gate: stopped before start"; exit 3; }
fi
_gate_stopped=0

for testfile in "${files[@]}"; do
  name=$(basename "$testfile" .tcl)
  [ -f "$testfile" ] || { echo "MISSING | $name"; STATUS[$name]=FAIL; OUT[$name]="no such test file"; ((FAIL++)); continue; }

  # pause point BETWEEN atomic tests: the current test always finishes; the
  # suite holds here while Paused, and breaks out cleanly on Stop.
  if type gate_pause_point >/dev/null 2>&1; then
    if ! gate_pause_point "full_audit | ${name} (next of ${_ntests})"; then
      _gate_stopped=1; echo "gui_gate: STOP -> skipping remaining tests"; break
    fi
  fi

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

type gate_finish >/dev/null 2>&1 && gate_finish
if [ "${_gate_stopped:-0}" = "1" ]; then
  echo "RESULT: STOPPED by GUI-test control panel (partial: ${PASS} pass ${FAIL} fail ${SKIP} skip so far)"
  exit 3
fi

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

SCRATCH_LEAKED=$(comm -13 <(printf '%s\n' "$SCRATCH_BEFORE") <(scratch_snapshot))
SCRATCH_N=0
if [ -n "$SCRATCH_LEAKED" ]; then
  SCRATCH_N=$(printf '%s\n' "$SCRATCH_LEAKED" | grep -c .)
  echo "--------- scratch leaks ---------"
  printf '%s\n' "$SCRATCH_LEAKED" | sed 's/^/LEAKED  | /'
  # only ever remove paths this run created, never a glob
  printf '%s\n' "$SCRATCH_LEAKED" | while IFS= read -r d; do [ -n "$d" ] && rm -rf -- "$d"; done
  echo "(removed; convert the owning test to tests/headless/scratch.tcl -- issue 0148)"
fi

echo "========================================"
echo "SUMMARY: $PASS pass  $FAIL fail  $CRASH crash/timeout  $SKIP skip  (total $((PASS+FAIL+CRASH+SKIP)))"
echo "WIREEDIT: $WIREEDIT_VERDICT"
echo "SCRATCH:  $SCRATCH_N leaked dir(s)"
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
if [ "${AUDIT_STRICT_SCRATCH:-1}" = "1" ] && [ "$SCRATCH_N" -gt 0 ]; then
  echo "AUDIT_STRICT_SCRATCH: $SCRATCH_N scratch dir(s) leaked into the working tree"
  exit 1
fi
exit 0
