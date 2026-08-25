#!/bin/bash
# run_suites.sh — GATED driver for ad-hoc suite runs and soaks.
#
# WHY THIS EXISTS: the GUI-test control gate (gui_gate.sh, and the wish panel
# in gui_gate_widget.tcl) is a SHELL library — it only governs a run that
# sources it. full_audit.sh was its only caller, so the very common
#     for i in 1 2 3; do ./src/xschem --pipe -q --nolog --script <t>.tcl; done
# soak loop floods the display with ungated windows and the panel's Pause
# button does nothing. Run suites through THIS instead and Pause works.
#
#   tests/headless/run_suites.sh test_wave_markers
#   tests/headless/run_suites.sh -n 12 test_wave_markers          # a soak
#   tests/headless/run_suites.sh -n 3 test_wave_viewer test_wave_modes
#   tests/headless/run_suites.sh --nogui test_wave_markers        # engine arm
#   tests/headless/run_suites.sh --logdir test_actionlog_suppress_gate
#
# Names may be given bare (`test_wave_markers`), with `.tcl`, or as a path.
# Repeats are the OUTER loop, so `-n 3 a b` runs a b a b a b — a soak
# interleaves rather than running each suite three times back to back.
#
# DISPLAY: like full_audit.sh, a run gets a PRIVATE Xvfb by default instead of
# borrowing the screen it was launched from (tests/headless/xvfb_arm.sh).
#   AUDIT_DISPLAY=:0    the real screen -- for an eyeball, a WM-dependent test,
#                       or a WSLg-only repro. The gate matters again there.
#   AUDIT_DISPLAY=none  no DISPLAY; GUI legs self-skip
#   AUDIT_SCREEN=WxHxD  pin the virtual screen; default 1920x1080x24
#
# Same fail-open contract as full_audit.sh: no DISPLAY, GUI_GATE=0 or no panel
# and it just runs. Disable entirely with `export GUI_GATE=0`. A Stop press
# abandons the remaining runs and exits 3.
#
# A run is PASS on "RESULT: ALL PASS" or on the older run_regression sentinel
# "OVERALL: ok" (issue 0228 — the same banner rule full_audit.sh uses), SKIP if
# it self-skipped for want of an X connection, FAIL otherwise.
#
# Exits 0 only if every run passed or skipped. Spec: doc/claude/specs/gui_test_gate.md
set -u

HERE=$(cd "$(dirname "$0")" && pwd)

# Display arm (may re-exec this script under xvfb-run — keep it above anything
# with side effects). Skipped for --help: spawning an X server to print a
# header block would be absurd, and would also swallow the exit.
_want_help=0
for _a in "$@"; do case "$_a" in -h|--help) _want_help=1 ;; esac; done
if [ "$_want_help" = 0 ]; then
  # shellcheck source=/dev/null
  . "$HERE/xvfb_arm.sh"
  xvfb_arm "$0" "$@"
fi
unset _want_help _a

REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="${XSCHEM:-$REPO/src/xschem}"
TIMEOUT="${SUITE_TIMEOUT:-200}"

REPEAT=1
MODE=nolog            # nolog (DISPLAY arm) | nogui | logdir
suites=()

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--repeat) REPEAT="${2:-1}"; shift 2 ;;
    --nogui)     MODE=nogui;  shift ;;
    --logdir)    MODE=logdir; shift ;;
    -h|--help)   sed -n '2,36p' "$0"; exit 0 ;;   # the header block, up to `set -u`
    -*)          echo "run_suites: unknown option $1" >&2; exit 2 ;;
    *)           suites+=("$1"); shift ;;
  esac
done

if [ "${#suites[@]}" -eq 0 ]; then
  echo "usage: $0 [-n REPEAT] [--nogui|--logdir] <suite> [suite...]" >&2; exit 2
fi
if [ ! -x "$XSCHEM" ]; then
  echo "FATAL: xschem binary not found/executable at: $XSCHEM" \
       "(build with: cd src && make, or set \$XSCHEM)" >&2
  exit 1
fi

# bare name | name.tcl | path -> path
resolve() {
  case "$1" in
    */*) printf '%s' "$1" ;;
    *.tcl) printf '%s' "$HERE/$1" ;;
    *) printf '%s' "$HERE/$1.tcl" ;;
  esac
}

for s in "${suites[@]}"; do
  f=$(resolve "$s")
  [ -f "$f" ] || { echo "FATAL: no such test file: $f" >&2; exit 1; }
done

# shellcheck source=/dev/null
. "$HERE/gui_gate.sh" 2>/dev/null || true

_nruns=$(( REPEAT * ${#suites[@]} ))
if type gate_start >/dev/null 2>&1; then
  gate_start "run_suites: $_nruns run(s) [$MODE] ($(basename "${suites[0]}") ...)" || {
    echo "gui_gate: stopped before start"; exit 3; }
fi

PASS=0; FAIL=0; SKIP=0; STOPPED=0; i=0

for _r in $(seq 1 "$REPEAT"); do
  for s in "${suites[@]}"; do
    i=$((i + 1))
    name=$(basename "$(resolve "$s")" .tcl)
    f=$(resolve "$s")

    # pause point BETWEEN atomic runs: the current run always finishes, the
    # loop holds here while Paused and breaks cleanly on Stop.
    if type gate_pause_point >/dev/null 2>&1; then
      if ! gate_pause_point "run_suites | ${name} (${i} of ${_nruns})"; then
        STOPPED=1; echo "gui_gate: STOP -> skipping the remaining runs"; break 2
      fi
    fi

    case "$MODE" in
      nogui)  out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --nogui --script "$f" 2>&1); ec=$? ;;
      logdir) tmpd=$(mktemp -d)
              out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --logdir "$tmpd" --script "$f" 2>&1); ec=$?
              rm -rf "$tmpd" ;;
      *)      out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --script "$f" 2>&1); ec=$? ;;
    esac

    result=$(printf '%s\n' "$out" | grep -E '^RESULT' | tail -1)

    # ONE banner rule, shared with the other two readers -- issue 0228. This was
    # the only one of the three that could not read the older run_regression
    # sentinel, so a suite printing "OVERALL: ok" and no RESULT: line scored
    # NORESULT here forever while passing every one of its own checks (the
    # inverse of issue 0147). The Tcl reader now shares ONE rule file:
    # tests/banner_rule.tcl defines banner_complete (this same shape), banner_died
    # and regression_case_failed, and tests/run_regression.tcl calls them instead of
    # keeping the private both-ends-anchored copy that false-redded every counted
    # suite for four filings (0420, 0492, 0629, 0689). tests/headless/full_audit.sh
    # accepts both banners in is_pass and classifies a self-skip FIRST.
    # NAMED BY PROC, NEVER BY LINE NUMBER -- the refs here used to say
    # "run_regression.tcl:115/:116" and were already pointing two lines off, which
    # is the same drift that let the defect survive.
    #
    #   * WHOLE LINE, never a substring, so the string inside a check's own
    #     message cannot forge a pass. A trailing "(N checks)" is tolerated
    #     because test_ihp_sg13g2_libmgr.tcl:195 and test_pdk_launcher.tcl:119
    #     print "OVERALL: ok (N checks)" -- a bare -x refuses those two.
    #   * EVERY failure spelling maps to FAIL, or a real failure stays exactly as
    #     unreadable as the NORESULT it replaces: "notok" (test_wire_split,
    #     test_crossview_paste, test_pin_type_edit), "OVERALL: FAIL"
    #     (test_add_pin_lib_symbol_view) and "OVERALL: N FAILED" (the two above).
    #   * EXIT 0 is required on the pass arm, as regression_case_failed does: a
    #     suite that prints the banner and then dies is not a pass -- it is a FAIL
    #     naming the exit code, not a "binary never reported" NORESULT.
    #
    # Custom-banner suites (test_nogui, test_readonly_guard, test_hi_descend,
    # test_cadence_descend_newwin_ro) print no OVERALL line at all, are NOT
    # reached by this, and still need full_audit.sh's bespoke cases.
    if [ -z "$result" ]; then
      if printf '%s\n' "$out" \
           | grep -qE '^OVERALL: ok([[:space:]]+\([^)]*\))?[[:space:]]*$'; then
        if [ "$ec" -eq 0 ]; then
          result="RESULT: ALL PASS (via OVERALL: ok sentinel)"
        else
          result="RESULT: FAILED (OVERALL: ok but exit $ec)"
        fi
      elif printf '%s\n' "$out" | grep -qE '^OVERALL: (notok|FAIL|[0-9]+ FAILED)'; then
        result="RESULT: FAILED (via OVERALL failure sentinel)"
      fi
    fi

    # A SELF-SKIP IS NOT A PASS. full_audit.sh's is_skip runs before its is_pass
    # for exactly this reason, and without it the sentinel arm above forges a
    # green: test_grid_toggle_sel_gc.tcl:34-36 prints "SKIP: no X connection" and
    # a bare "OVERALL: ok" with zero checks run, and the legacy banner
    # "RESULT: ALL PASS (0 checks, skipped: no X)" already scored a hollow PASS
    # here through the ^RESULT path. SKIP is neither pass nor fail; a nonzero exit
    # is never a skip.
    #
    # THE REGEXP IS LINE-ANCHORED, and must stay byte-identical to full_audit.sh's
    # is_skip (issue 0354 H1; asserted by test_audit_classifier.tcl so the two
    # copies cannot drift). Unanchored, "skipped: no X" matches inside a CHECK
    # NAME: test_save_reload_copy_selflog.tcl:139,205,280 name three checks
    # "keyboard ... (skipped: no X)", so the suite ran every check, passed and
    # exited 0 while this driver reported SKIP and full_audit reported PASS --
    # and since run_suites.sh exits 0 on skips, that read as a green run in which
    # four suites appeared never to have executed (merge 5,
    # doc/claude/suggestions/plan_merge5_fluid_into_open_pdk.md section 5.5).
    skipped=0
    if [ "$ec" -eq 0 ] && printf '%s\n' "$out" \
         | grep -qE '^(RESULT: SKIP|SKIP: no X connection|RESULT: ALL PASS \(0 checks, skipped: no X\))'; then
      skipped=1
    fi

    if [ "$ec" -eq 124 ]; then
      printf 'TIMEOUT  | %-28s run %d/%d (after %ss)\n' "$name" "$i" "$_nruns" "$TIMEOUT"
      FAIL=$((FAIL + 1))
    elif [ "$skipped" = "1" ]; then
      printf 'SKIP     | %-28s run %d/%d (self-skipped: no X — nothing ran)\n' \
             "$name" "$i" "$_nruns"
      SKIP=$((SKIP + 1))
    elif [ -z "$result" ]; then
      printf 'NORESULT | %-28s run %d/%d (exit %d — binary never reported)\n' \
             "$name" "$i" "$_nruns" "$ec"
      FAIL=$((FAIL + 1))
    elif printf '%s' "$result" | grep -q 'ALL PASS'; then
      printf 'PASS     | %-28s run %d/%d  %s\n' "$name" "$i" "$_nruns" "$result"
      PASS=$((PASS + 1))
    else
      printf 'FAIL     | %-28s run %d/%d  %s\n' "$name" "$i" "$_nruns" "$result"
      # ^FATAL too: a suite that dies through `bail` prints its verdict there and
      # never prints a FAIL: line, so the FAIL: grep alone would show nothing.
      printf '%s\n' "$out" | grep -E '^(FAIL|FATAL)' | sed 's/^/         | /'
      FAIL=$((FAIL + 1))
    fi
  done
done

type gate_finish >/dev/null 2>&1 && gate_finish

if [ "$STOPPED" = "1" ]; then
  echo "RESULT: STOPPED by the GUI-test control panel" \
       "(partial: $PASS pass $FAIL fail $SKIP skip)"
  exit 3
fi
# Skips are reported but do not fail the run, as in full_audit.sh:7. The
# "RESULT: n/m runs passed" prefix is unchanged so anything grepping it still
# reads; the skip count is appended only when there is one, and 0/0 with a skip
# count is a run in which nothing actually ran.
if [ "$SKIP" -eq 0 ]; then
  echo "RESULT: $PASS/$((PASS + FAIL)) runs passed"
else
  echo "RESULT: $PASS/$((PASS + FAIL)) runs passed ($SKIP skipped)"
fi
[ "$FAIL" -eq 0 ]
