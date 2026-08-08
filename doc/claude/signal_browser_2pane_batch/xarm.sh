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

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
CTLDIR="${GUI_GATE_DIR:-$HOME/.claude/gui_test_gate}"
DEADLINE_FILE="$HERE/DEADLINE"
SCREEN="${XARM_SCREEN:--screen 0 1920x1080x24}"

deadline=0
[ -r "$DEADLINE_FILE" ] && deadline=$(tr -dc '0-9' < "$DEADLINE_FILE")
[ -z "$deadline" ] && deadline=0
now=$(date +%s)

unattended=0
if [ "$now" -lt "$deadline" ] && command -v xvfb-run >/dev/null 2>&1; then
  unattended=1
fi

# After the deadline the user is back in charge, so the panel must be up. Raising
# it is idempotent: if one is already running we leave it alone. It goes on the
# REAL display, never on the Xvfb one — a panel nobody can see is worse than none.
raise_panel() {
  if pgrep -f 'gui_gate_widget.tcl' >/dev/null 2>&1; then return 0; fi
  if [ -z "${DISPLAY:-}" ]; then
    echo "xarm: no DISPLAY — cannot raise the gate panel" >&2
    return 1
  fi
  mkdir -p "$CTLDIR"
  ( wish "$REPO/tests/headless/gui_gate_widget.tcl" "$CTLDIR" >>"$CTLDIR/widget.log" 2>&1 & )
  sleep 2
  pgrep -f 'gui_gate_widget.tcl' >/dev/null 2>&1
}

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
    echo "xarm: the GUI gate panel governs these runs. Pause/Stop are live."
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
      exec env GUI_GATE=0 xvfb-run -a -s "$SCREEN" \
        "$REPO/tests/headless/run_suites.sh" "$@"
    fi
    raise_panel || echo "xarm: WARNING — proceeding without a panel" >&2
    exec "$REPO/tests/headless/run_suites.sh" "$@"
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
      exec env GUI_GATE=0 xvfb-run -a -s "$SCREEN" \
        "$REPO/src/xschem" --pipe -q --nolog --script "$f" "$@"
    fi
    raise_panel || echo "xarm: WARNING — proceeding without a panel" >&2
    exec "$REPO/tests/headless/gated_xschem.sh" --pipe -q --nolog --script "$f" "$@"
    ;;
  *)
    echo "usage: xarm.sh {suites <names...>|one <testfile.tcl>|mode}" >&2
    exit 2
    ;;
esac
