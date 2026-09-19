#!/bin/bash
# xarm.sh — the two-pane batch's ONE way to run the X (real-Tk) arm.
#
# WHY THIS EXISTS. The batch runs unattended overnight, and the two ways to get a
# real Tk display have opposite problems:
#
#   * the user's DISPLAY=:0 — every suite asks the GUI gate panel for permission,
#     and nobody is awake to press it; and WSLg's Xwayland dies ~3x a session,
#     taking every client with it. It also floods the screen all night.
#   * a private Xvfb — no gate needed, no flooding, immune to the Xwayland death,
#     but NO WINDOW MANAGER: decoration, iconify, stacking, raise and geometry
#     echo are untestable there. Nothing in two-pane items 13-19 needs a WM (it is
#     all inside one toplevel), which is why Xvfb is the right choice HERE and
#     would not be for the detach batch.
#
# So: Xvfb until the deadline, then hand the machine back to the user under the
# gate panel. The switchover is automatic and needs no bookkeeping from the
# driver — every caller just runs this script and gets whichever is correct.
#
#   xarm.sh suites <suite> [<suite> ...]   # the 11-suite arm, via run_suites.sh
#   xarm.sh one <testfile.tcl>             # one file, full per-check output
#   xarm.sh mode                           # print the mode and the time left
#
# The deadline is an epoch second in DEADLINE beside this script. Edit that file
# to extend or end the unattended window; nothing else reads a clock.
#
# ⚠ SINCE 2026-09-18 (doc/claude/outsider_fixes_batch, DECISIONS D20.6) EVERY RUN
# GOES THROUGH AN ARMED DRIVER, UNDER A THROWAWAY HOME. The round-3 safety
# refuter ran `xarm.sh one test_crossview_paste.tcl` on an empty home and it
# created ~/.claude/gui_test_gate/ and left a `wish` gate panel running there;
# its unattended arm also ran a bare `xschem` under `xvfb-run -a` -- which starts
# at :99, the persistent dev display's number -- against the tester's own HOME.
# So:
#   * it arms first (tests/headless/test_home.sh), like every documented test
#     command, and runs its driver as a CHILD so the throwaway is deleted after;
#   * `one` runs through gated_xschem.sh and `suites` through run_suites.sh, in
#     BOTH modes: those drivers already choose the display (the dev display when
#     it is up, else a private Xvfb from :200 -- never :99, D17.8), and the gate
#     raises its own panel, tracked, when it applies;
#   * unattended only adds GUI_GATE=0, which is what that window has always meant.
# XARM_SCREEN is gone with xvfb-run: set AUDIT_SCREEN (e.g. 1920x1080x24).

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
# shellcheck source=/dev/null
. "$REPO/tests/headless/test_home.sh"
test_home_arm || exit $?
DEADLINE_FILE="$HERE/DEADLINE"

deadline=0
[ -r "$DEADLINE_FILE" ] && deadline=$(tr -dc '0-9' < "$DEADLINE_FILE")
[ -z "$deadline" ] && deadline=0
now=$(date +%s)

unattended=0
if [ "$now" -lt "$deadline" ] && command -v xvfb-run >/dev/null 2>&1; then
  unattended=1
fi

print_mode() {
  if [ "$unattended" = 1 ]; then
    left=$(( (deadline - now) / 60 ))
    echo "xarm mode: XVFB (unattended). ${left} min left; hands back at $(date -d "@$deadline" 2>/dev/null || echo "$deadline")."
  else
    if [ "$deadline" = 0 ]; then
      echo "xarm mode: GATED :0 — no DEADLINE file, so the unattended window is not open."
    elif ! command -v xvfb-run >/dev/null 2>&1; then
      echo "xarm mode: GATED :0 — xvfb-run is not installed."
    else
      echo "xarm mode: GATED :0 — the unattended window closed at $(date -d "@$deadline" 2>/dev/null || echo "$deadline")."
    fi
    echo "xarm: the GUI gate governs these runs where it applies (its panel is raised by the driver). Pause/Stop are live."
  fi
}

cmd="${1:-mode}"
shift 2>/dev/null || true

case "$cmd" in
  mode)
    print_mode
    exit 0
    ;;
  suites)
    [ $# -ge 1 ] || { echo "xarm: 'suites' needs at least one suite name" >&2; exit 2; }
    print_mode
    if [ "$unattended" = 1 ]; then
      GUI_GATE=0 "$REPO/tests/headless/run_suites.sh" "$@"
    else
      "$REPO/tests/headless/run_suites.sh" "$@"
    fi
    exit $?
    ;;
  one)
    [ $# -ge 1 ] || { echo "xarm: 'one' needs a test file" >&2; exit 2; }
    f="$1"; shift
    case "$f" in
      /*) ;;
      *)  [ -f "$REPO/tests/headless/$f" ] && f="$REPO/tests/headless/$f" ;;
    esac
    print_mode
    if [ "$unattended" = 1 ]; then
      GUI_GATE=0 "$REPO/tests/headless/gated_xschem.sh" --pipe -q --nolog --script "$f" "$@"
    else
      "$REPO/tests/headless/gated_xschem.sh" --pipe -q --nolog --script "$f" "$@"
    fi
    exit $?
    ;;
  *)
    echo "usage: xarm.sh {suites <names...>|one <testfile.tcl>|mode}" >&2
    exit 2
    ;;
esac
