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
#   * per-test timeout via $AUDIT_TIMEOUT (default 300s)
#
# DISPLAY: the audit runs on a PRIVATE Xvfb by default and no longer borrows
# whatever screen it was launched from — see tests/headless/xvfb_arm.sh for the
# measurements behind that and for the three cases that still want a real one.
#   AUDIT_DISPLAY=:0    the real screen (and then the GUI gate matters again)
#   AUDIT_DISPLAY=none  no DISPLAY at all; GUI tests self-SKIP (`winfo exists .`)
#   AUDIT_SCREEN=WxHxD  pin the virtual screen; default 1920x1080x24
#
# Usage:
#   tests/headless/full_audit.sh                 # all tests, private Xvfb
#   tests/headless/full_audit.sh test_sweep_diff test_multi_window   # a subset
#   AUDIT_DISPLAY=:0 tests/headless/full_audit.sh                    # real screen
#   XSCHEM=/path/to/xschem tests/headless/full_audit.sh              # in CI -- NO outer
#                                     # xvfb-run: the script arms its own private Xvfb
#   AUDIT_LIB_ONLY=1 . tests/headless/full_audit.sh   # define is_skip/has_failure/
#                                                     # classify only, run nothing
#
set -u

HERE=$(cd "$(dirname "$0")" && pwd)

# Pick the display arm before anything else: this may re-exec the whole script
# under xvfb-run, so nothing above it should have side effects.
#
# Skipped in library mode. xvfb_arm() ends in `exec xvfb-run ...`, and the
# AUDIT_LIB_ONLY source-guard that would have stopped us is 300-odd lines below --
# so `AUDIT_LIB_ONLY=1 . full_audit.sh` used to exec away and NEVER RETURN to its
# caller, which is precisely how test_audit_classifier.tcl loads the predicates
# (merge 5, doc/claude/suggestions/plan_merge5_fluid_into_open_pdk.md section 5.3).
# Library mode runs no test, so it needs no display and must never re-exec.
if [ "${AUDIT_LIB_ONLY:-0}" != "1" ]; then
  # shellcheck source=/dev/null
  . "$HERE/xvfb_arm.sh"
  xvfb_arm "$0" "$@"
fi

REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="${XSCHEM:-$REPO/src/xschem}"
# 300, not 120: test_wave_markers legitimately needs 61-149 s, so the old
# default turned a slow-but-passing test into an intermittent TIMEOUT.
TIMEOUT="${AUDIT_TIMEOUT:-300}"

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
# (test_ase_log_seam_0207 and test_select_at were MISSING from this list until
# issue 0415. Both assert on the action log, which exists only under --logdir, so
# without the flag they failed on their FIRST line -- `FAIL: action log open` --
# and every downstream assertion failed for want of a log rather than for want of
# the behaviour: 16 of the first's 26 checks lost, 5 in the second (SA5, SA6b,
# SA7b, SA8b and the opener). The other 10 of the 26 are not evidence either --
# they assert ABSENCES (PS9 over an empty line set, PS10a/PS10b/PS11/PS13 "nothing
# was logged", RP2/RP3 "replay executed nothing") and pass vacuously with no log
# at all. Both test files say so in their own headers
# (test_select_at.tcl:7-15, test_ase_log_seam_0207.tcl:39-47) and neither had ever
# been on the list. Measured here at 938388a5: 16 FAILED (10 passed) / 5 FAILED
# without the flag, ALL PASS (26 checks) / ALL PASS with it.
# The flag is safe to grant because the dispatch below is an if/elif CHAIN with
# in_list "$logdir_tests" FIRST: a name can take exactly one arm, so a case on
# this list can never also reach a --nolog invocation -- and --nolog + --logdir is
# a fatal abort (util.c:344-349). nolog_tests holds only test_nolog, so there is
# no overlap to guard in the first place.)
logdir_tests=" test_ciw test_ciw_autocomplete test_ciw_puts_capture test_hi_descend \
  test_ase_log_seam_0207 test_select_at \
  test_action_log_dispatch test_action_log_libmgr test_context_menu_log \
  test_gesture_end_log test_phase3_mints test_lib_roundtrip test_selflog_output \
  test_altf5_ciw test_undo_link_symbols test_dblclick_connected_grow test_delete_cut_selflog \
  test_select_same_net_by_label test_snap_bindkeys \
  test_descend_goback_selflog test_save_reload_copy_selflog test_selflog_grep_guard \
  test_key_make_sch_from_sel_log \
  test_context_menu_descend_refusal_0249 \
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
# (test_placement_preview_doors drives no `xschem callback`; --nogui also makes its
# place_text / add_image rows exercise the CANCELLED-dialog path, which is the terminal
# case issue 0242 measured)
# (test_paste_modify_flag_0244 drives no `xschem callback` either -- it arms with
# `xschem merge`/`xschem paste`, commits with `move_objects end`, cancels with
# `abort_operation` -- so it is true-headless by construction)
# (test_placement_wire_gate is --nogui by PRESCRIPTION, not preference: its own header says
# so, and with ANY display it blocks forever at the G4 `xschem place_text` row -- headlessly
# place_text() fails fast because the text dialog needs a Tk toplevel, but under a real X the
# modal is raised for real and nothing dismisses it. Measured: killed at 120s under WSLg,
# still stalled after 300s under xvfb-run. Issue 0355; the suite now self-guards too, so the
# two halves are independent.)
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
# (test_descend_symbol is the same modal trap as test_placement_wire_gate above, one
# row further along: SNW6 calls `xschem symbol_in_new_window` with nothing selected, that
# arm composes <work>/descend_parent.sym -- a fixture that has never existed in any commit
# -- and load_schematic()'s fd==NULL branch raises `alert_`, a modal toplevel nothing
# dismisses. It does not fail, it HANGS, and paid AUDIT_TIMEOUT (300 s) plus a crash row
# on every full run. Headless it is 38 checks / exit 0, which its own header already
# prescribed. Issue 0414, root-caused on the open_pdk side and left OPEN with this exact
# fix identified; applied here at merge 5 because that is the run it reddens.)
# The list is the UNION of both merge-5 sides (merge 5, doc/claude/suggestions/
# plan_merge5_fluid_into_open_pdk.md): keeping either half alone silently un-pins the
# other's tests, and dropping open_pdk's half hangs test_placement_wire_gate forever.
nogui_tests=" test_descend_refusal_channel_0251 test_descend_symbol test_nogui test_sweep_diff test_make_symbol_dialog test_ase_core test_ase_final test_ase_final_gf180 test_placement_preview_doors test_paste_modify_flag_0244 test_shape_draw_gate test_placement_wire_gate test_verilog_view_model test_vcd_read test_ase_cosim test_raw_ascii_point_bounds test_vcd_time_base test_raw_read_dispatch test_raw_read_failure_0306 test_node_token_split test_wave_cursor_crossdb test_backannotate_digital test_cosim_golden_e2e "
# test_nolog exercises --nolog mode explicitly
nolog_tests=" test_nolog "

in_list() { case "$2" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# THE ONE MATCHER. Every predicate below asks whether the blob contains a LINE
# of the given shape -- never whether it contains the token somewhere. That is
# the whole repair: issue 0350 anchored is_skip, issue 0354 measured that the
# other four predicates were the identical defect wearing a different sign.
line_has() { printf '%s\n' "$2" | grep -qE "$1"; }

# A test PASSES on "RESULT: ALL PASS" or on the older run_regression sentinel
# "OVERALL: ok"; a handful use their own banner.
#
# Both banners are accepted because ~5 shipped tests (test_wire_split,
# test_crossview_paste, test_pin_type_edit, test_add_pin_lib_symbol_view,
# test_select_at) only ever print "OVERALL: ok" -- they were scored FAIL here
# forever while passing every one of their own checks (red-but-hollow, the
# inverse of issue 0147). "OVERALL: notok"/"OVERALL: FAIL" are the failure
# banners and are not substrings of "OVERALL: ok", so the test still fails.
#
# EVERY ARM IS LINE-ANCHORED (issue 0354 H1). These used to be unanchored bash
# `==` globs over the whole merged stdout+stderr blob, so a suite that printed
# three FAIL lines, a "RESULT: 1 FAILED" banner and exited 1 was scored PASS
# because one of its check NAMES quoted "OVERALL: ok" -- and since AUDIT_MIN_PASS
# counts PASSes, that hollow PASS satisfied the CI floor too (.github/workflows/
# ci.yaml). Same contract as the skip banner: a pass banner counts only at the
# START OF A LINE. Measured across the tree: every shipped emitter prints its
# banner at column 0, so no in-tree suite changes classification.
#
# The "<name> headless: ..." arm is the one banner that is PREFIXED by
# construction (test_hi_descend.tcl:163), so it is anchored at BOTH ends -- that
# is the only way to assert its shape rather than accept it inside a check name.
is_pass() {
  local name="$1" out="$2" ec="$3"
  case "$name" in
    test_palette)              [ "$ec" -eq 0 ] && line_has '^EVENT opens palette: yes' "$out" ;;
    test_ciw_autocomplete)     line_has '^PASS: ciw autocomplete \(0 failure\(s\)\)' "$out" ;;
    test_ciw_puts_capture)     line_has '^PASS: ciw puts-capture \(0 failure\(s\)\)' "$out" ;;
    test_lib_new_discovered_defs) line_has '^RESULT: all passed' "$out" ;;
    test_nogui)                line_has '^NOGUI_TEST_PASS' "$out" ;;
    test_readonly_guard)       line_has '^READONLY_GUARD_TEST_PASS' "$out" ;;
    test_readonly_action_dispatch) line_has '^ACTION_READONLY_TEST_PASS' "$out" ;;
    # third banner shape: "<name> headless: all checks passed" / "... N FAILURE(S)"
    # (test_cadence_descend_newwin_ro passes every check but was scored FAIL;
    # test_hi_descend shares the banner and really does fail one check)
    test_cadence_descend_newwin_ro|test_hi_descend) \
                               line_has '^[A-Za-z0-9_]+ headless: all checks passed$' "$out" \
                                 && ! is_skip "$out" ;;
    *)                         line_has '^(RESULT: ALL PASS|OVERALL: ok)' "$out" \
                                 && ! is_skip "$out" ;;
  esac
}
# THE SKIP CONTRACT (issue 0350). A skip banner counts only at the START OF A
# LINE. Anywhere else -- inside a check name, a diagnostic, an echoed comment --
# it is ordinary text and the test is classified on its real verdict. And a FAIL
# line beats a skip banner (has_failure below): a run that failed must not be
# able to hide behind one. That guard used to cover only the `FAIL:` banner
# shape; issue 0354 H2 measured the four other failure banners the tree really
# emits and has_failure now covers all of them.
#
# This used to be three UNANCHORED substring tests over the whole stdout+stderr
# blob, evaluated ahead of is_pass, so a line a test printed MID-RUN --
#   ok:   keyboard/ctx-menu copy (skipped: no X)  (no display)
# -- reclassified the ENTIRE test as SKIP. SKIP increments only SKIP, the exit
# gate is FAIL+CRASH>0 and AUDIT_MIN_PASS defaults to 0, so four fully-passing
# suites (59 checks) were discarded wholesale -- and would have gone on being
# discarded had they turned red (measured: a probe printing FAIL and exiting 1
# was scored SKIP, audit exit 0). ~20 shipped tests still carry comments
# explaining how they dodge the token; the anchor is what repays that dodge tax.
#
# The three accepted shapes are the only banners any test emits at column 0:
#   RESULT: SKIP (...)                          canonical self-skip (84 sites)
#   SKIP: no X connection (has_x=0); ...        test_grid_toggle_sel_gc.tcl:35,
#                                               which prints NO RESULT line at all
#   RESULT: ALL PASS (0 checks, skipped: no X)  the legacy banner -- extinct as an
#                                               emitted string, kept so a
#                                               resurrected test cannot be scored
#                                               a hollow PASS. PINNED to that exact
#                                               literal (issue 0354 H3): it used to
#                                               anchor only `RESULT:`, so a fully
#                                               green "RESULT: ALL PASS (20 checks;
#                                               3 legs skipped: no X)" was scored
#                                               SKIP. The alternative is kept rather
#                                               than deleted -- deleting it would let
#                                               a resurrected legacy banner score a
#                                               hollow PASS, which is the one thing
#                                               it exists to prevent.
#
# NOTE full_audit and run_suites.sh deliberately DISAGREE about skips, and that
# split is ratified (issue 0350 D5): a whole-tree sweep tolerates SKIP behind an
# AUDIT_MIN_PASS floor, whereas run_suites.sh:105 was asked for THIS test by
# name, so a skip there is a failure to deliver and scores FAIL.
is_skip() {
  line_has '^(RESULT: SKIP|SKIP: no X connection|RESULT: ALL PASS \(0 checks, skipped: no X\))' "$1"
}

# Independent second guard: an aborted run must not lie about its verdict, the
# same way an aborted gesture must not lie about the modify flag (0244/0267/0270).
# The skip arm of classify() is its ONLY consumer, so it can only ever move a
# test SKIP -> FAIL; no currently-PASSing test can change classification
# because of it. Anchored for exactly the reason is_skip is: "undo after a failed
# paste" is a legitimate check name.
#
# The alternation covers every failure-banner shape MEASURED in tests/headless
# (issue 0354 H2 -- the old one covered `FAIL:` and `RESULT: <n> FAILED` only):
#   FAIL: <check> -> {..} (exp {..})       the per-check line, ~all suites
#   RESULT: <n> FAILED (<n> passed)        the dominant verdict banner
#   RESULT: <n> FAIL                       19 sites, incl. test_cadence_stretch_move.tcl:170
#   RESULT: FAIL (<n> ok, <n> fail)        6 sites
#   RESULT: FAILED                         test_coordlog_precision.tcl:62
#   RESULT: <n> FAILURE(S)
#   OVERALL: notok / OVERALL: FAIL         the run_regression sentinels
#   OVERALL: fail                          4 sites, lowercase
#   OVERALL: <n> FAILED, <n> passed        test_descend_inert_class.tcl:151 (CI hard gate)
# Column 0 ONLY, deliberately (0350 D2, re-ratified here): a suite that echoes a
# CHILD run's indented output must not be reddened by someone else's failure.
has_failure() {
  line_has '^(FAIL[: !]|RESULT: ([0-9]+ )?FAIL|OVERALL: ([0-9]+ )?(notok|NOTOK|FAIL|fail))' "$1"
}

# The classification chain, lifted out of the run loop into a verb so the
# ORDERING is testable (tests/headless/test_audit_classifier.tcl). Echoes exactly
# one of PASS / SKIP / FAIL / CRASH / TIMEOUT; the loop below keeps only the
# counter bookkeeping. The order is load-bearing:
#   * TIMEOUT and CRASH out-rank skip -- a test that printed its banner and then
#     died is a CRASH, not a SKIP (review wf_bfc3c5e4). A clean self-skip exit 0's
#     right after its banner, so it can never reach a FATAL/Tcl_AppInit line.
#   * is_skip stays AHEAD of is_pass. The `*)` and banner arms of is_pass call
#     `! is_skip` themselves, so for those the order is unobservable -- but the
#     seven name-specific arms (test_palette, test_ciw_autocomplete,
#     test_ciw_puts_capture, test_lib_new_discovered_defs, test_nogui,
#     test_readonly_guard, test_readonly_action_dispatch) do not self-guard, and
#     test_grid_toggle_sel_gc prints its skip line next to "OVERALL: ok". Putting
#     is_pass first turns both into hollow PASSes.
#     The gate stays HERE, on the chain, and is NOT duplicated onto the seven
#     name-specific arms (0243 F2: gates live at the verb, not at every caller) --
#     duplicating it would also make that ordering unobservable.
#
# BOTH crash predicates are line-anchored too (issue 0354). They were unanchored
# substring tests with OPPOSITE failure directions:
#   * "FATAL: signal" in a check NAME scored a fully GREEN suite CRASH. main.c:58
#     prints it after a leading \n, so column 0 is guaranteed for the real thing.
#   * "Tcl_AppInit() error" in a check name scored a genuinely FAILING suite
#     CRASH instead of FAIL (0354 H4 -- measured by this item, absent from the
#     original filing; red->red, so the exit gate never moved either way).
# NOTE the anchor keeps the arm's own literal. xinit.c also emits
# "Tcl_AppInit() err 1:" .. "err 4:" (xinit.c:1507/3253/3325/3373), which this arm
# has never matched; widening it is a separate, unmeasured change (0354 H4 note).
classify() {
  local name="$1" out="$2" ec="$3"
  if [ "$ec" -eq 124 ]; then
    echo TIMEOUT
  elif line_has '^FATAL: signal' "$out" \
       || { line_has '^Tcl_AppInit\(\) error' "$out" && ! is_pass "$name" "$out" "$ec"; }; then
    echo CRASH
  elif is_skip "$out" && ! has_failure "$out"; then
    echo SKIP
  elif is_pass "$name" "$out" "$ec"; then
    echo PASS
  else
    echo FAIL
  fi
}

# ---------------------------------------------------------------------------
# THE TWO LEAK DETECTORS. Both take the tree to inspect as $1 (defaulting to the
# repo) so they can be exercised against a synthetic throw-away tree by
# tests/headless/test_audit_classifier.tcl, and both are defined above the
# source-guard for the same reason.
# ---------------------------------------------------------------------------

# Arm 1, the directory glob (issue 0148). Tests mkdir a per-pid `_<tag>_<pid>`
# dir and delete it on their last line, so any test that exits early, errors, or
# crashes orphans one in the working tree -- invisible in `git status` because
# .gitignore hides the pattern. Snapshot before/after, report what the run left
# behind, and remove it. Every test now goes through tests/headless/scratch.tcl,
# so the expected count is 0 and a leak is FATAL by default -- that enforcement
# is the whole point of issue 0148 (the class recurred twice because nothing
# checked). Set AUDIT_STRICT_SCRATCH=0 to downgrade it to a warning.
scratch_snapshot() {
  local root="${1:-$REPO}"
  ls -1d "$root"/_*_[0-9]* "$root"/tests/_*_[0-9]* "$root"/tests/headless/_*_[0-9]* \
         "$root"/src/_*_[0-9]* 2>/dev/null | sort
}

# Arm 2, the working-tree delta (issues 0352, 0353). Arm 1 only ever globs
# DIRECTORIES with ONE name shape in four fixed parents, so it is structurally
# blind to everything else a run can leave behind:
#   a leaked FILE            untitled-NN.sch in the repo root       (0353)
#   a differently-named DIR  undo_link_child/                       (0352)
#   a NON-IGNORED deletion   something the run removed mid-suite
# Guessing another name would repeat the defect, so this arm asks git what
# actually moved instead.
#
# KNOWN LIMIT, measured -- do NOT read this arm as total coverage. `git status`
# honours .gitignore, so everything .gitignore hides is invisible here in BOTH
# directions: `*~.sch` / `*~.sym` (:55,:56) and `_*_[0-9]*/` (:64). That means
# the autosave-BACKUP half of 0353 is unreported, and so is 100% of issue 0356's
# only measured instance (an untracked `tests/untitled-16~.sch` that a suite
# deleted) -- this arm cannot find 0356's emitter. Widening it (`--ignored=
# matching` filtered to the two backup patterns) re-introduces exactly the
# name-guessing this item exists to remove, so it is an OPEN decision recorded in
# 0356, not something that item settled. Locked by C39b/C39c in
# tests/headless/test_audit_classifier.tcl so the gap cannot be forgotten.
#
# REPORT ONLY, and deliberately so: it feeds no removal and no exit path, and is
# NOT wired into AUDIT_STRICT_SCRATCH. Arm 1's cleanup deletes whatever its
# snapshot reports, and `untitled-NN.sch` is shaped exactly like unsaved user
# work -- 0352 and 0353 both refuse to let the audit delete that. Making it
# fatal before the emitting tests are fixed would also redden a hard gate on the
# first honest report. Fix the tests; the report is the standing reminder.
tree_delta_snapshot() {
  local root="${1:-$REPO}"
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$root" status --porcelain --untracked-files=all 2>/dev/null | sort
}

# Source-guard: `AUDIT_LIB_ONLY=1 . tests/headless/full_audit.sh` defines the
# predicates, classify() and the two snapshot verbs and returns WITHOUT running
# an audit, so the classifier can be regression-locked without a 300-test sweep.
# Inert on the normal executed path -- the test short-circuits and `return`
# never runs.
[ "${AUDIT_LIB_ONLY:-0}" = "1" ] && return 0 2>/dev/null

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

# Both leak detectors are defined above the source-guard; take their "before"
# readings here, just ahead of the first test.
SCRATCH_BEFORE=$(scratch_snapshot)
TREE_BEFORE=$(tree_delta_snapshot)

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

  # one verdict, decided by classify() above; the loop only tallies.
  STATUS[$name]=$(classify "$name" "$out" "$ec")
  case "${STATUS[$name]}" in
    PASS)          ((PASS++)) ;;
    SKIP)          ((SKIP++)) ;;
    CRASH|TIMEOUT) OUT[$name]="$out"; ((CRASH++)) ;;
    *)             OUT[$name]="$out"; ((FAIL++)) ;;
  esac
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

# Arm 2: what the run did to the working tree, in BOTH directions. Report only --
# nothing below deletes any of it and nothing below changes the exit code.
TREE_AFTER=$(tree_delta_snapshot)
TREE_APPEARED=$(comm -13 <(printf '%s\n' "$TREE_BEFORE") <(printf '%s\n' "$TREE_AFTER"))
TREE_VANISHED=$(comm -23 <(printf '%s\n' "$TREE_BEFORE") <(printf '%s\n' "$TREE_AFTER"))
TREE_NADD=0
TREE_NDEL=0
if [ -n "$TREE_APPEARED" ] || [ -n "$TREE_VANISHED" ]; then
  echo "--------- working-tree delta (report only) ---------"
fi
if [ -n "$TREE_APPEARED" ]; then
  TREE_NADD=$(printf '%s\n' "$TREE_APPEARED" | grep -c .)
  printf '%s\n' "$TREE_APPEARED" | sed 's/^/TREEADD | /'
fi
if [ -n "$TREE_VANISHED" ]; then
  TREE_NDEL=$(printf '%s\n' "$TREE_VANISHED" | grep -c .)
  printf '%s\n' "$TREE_VANISHED" | sed 's/^/TREEDEL | /'
fi

echo "========================================"
echo "SUMMARY: $PASS pass  $FAIL fail  $CRASH crash/timeout  $SKIP skip  (total $((PASS+FAIL+CRASH+SKIP)))"
echo "WIREEDIT: $WIREEDIT_VERDICT"
echo "SCRATCH:  $SCRATCH_N leaked dir(s)"
echo "TREE:     $TREE_NADD appeared  $TREE_NDEL vanished (report only, gitignored paths excluded; issues 0352/0353)"
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
