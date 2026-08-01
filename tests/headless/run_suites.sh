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
# Same fail-open contract as full_audit.sh: no DISPLAY, GUI_GATE=0 or no panel
# and it just runs. Disable entirely with `export GUI_GATE=0`. A Stop press
# abandons the remaining runs and exits 3.
#
# Exits 0 only if every run passed. Spec: doc/claude/specs/gui_test_gate.md
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
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
    -h|--help)   sed -n '2,26p' "$0"; exit 0 ;;
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

PASS=0; FAIL=0; STOPPED=0; i=0

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
    if [ "$ec" -eq 124 ]; then
      printf 'TIMEOUT  | %-28s run %d/%d (after %ss)\n' "$name" "$i" "$_nruns" "$TIMEOUT"
      FAIL=$((FAIL + 1))
    elif [ -z "$result" ]; then
      printf 'NORESULT | %-28s run %d/%d (exit %d — binary never reported)\n' \
             "$name" "$i" "$_nruns" "$ec"
      FAIL=$((FAIL + 1))
    elif printf '%s' "$result" | grep -q 'ALL PASS'; then
      printf 'PASS     | %-28s run %d/%d  %s\n' "$name" "$i" "$_nruns" "$result"
      PASS=$((PASS + 1))
    else
      printf 'FAIL     | %-28s run %d/%d  %s\n' "$name" "$i" "$_nruns" "$result"
      printf '%s\n' "$out" | grep -E '^FAIL' | sed 's/^/         | /'
      FAIL=$((FAIL + 1))
    fi
  done
done

type gate_finish >/dev/null 2>&1 && gate_finish

if [ "$STOPPED" = "1" ]; then
  echo "RESULT: STOPPED by the GUI-test control panel (partial: $PASS pass $FAIL fail)"
  exit 3
fi
echo "RESULT: $PASS/$((PASS + FAIL)) runs passed"
[ "$FAIL" -eq 0 ]
