#!/bin/bash
# gui_gate.sh — shell side of the GUI-test control gate (see
# tests/headless/gui_gate_widget.tcl and doc/claude/specs/gui_test_gate.md).
#
# Source this, then:
#   gate_start "<suite-label>"      # warn + hold until Proceed, or until the
#                                   #   panel's 2-minute auto-start countdown
#                                   #   expires (GUI_GATE_AUTOSTART seconds)
#   gate_pause_point "<i/N test>"   # call BETWEEN atomic tests; holds while the
#                                   #   panel is Paused; returns 2 on Stop
#   gate_finish                     # clean this suite's status/request files
#
# ROBUST BY DESIGN:
#   * The gate lives in the git-tracked test harness, NOT in a Claude Code
#     settings hook (the previous hook-based gate silently died when
#     settings.local.json was rewritten). It cannot be clobbered that way.
#   * The control dir is under $HOME (not the repo), so the SAME panel governs
#     the main session and every worktree/subagent test run.
#   * FAIL OPEN: no DISPLAY, GUI_GATE=0, or a dead/again-unlaunchable panel
#     never blocks testing — the suite just runs. Nor does an unattended desk:
#     the panel auto-starts a waiting suite after 2 minutes.
#
# Disable entirely:  export GUI_GATE=0

GATE_DIR="${GUI_GATE_DIR:-$HOME/.claude/gui_test_gate}"
_GATE_PID="$$"
_GATE_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_gate_enabled() {
  [ "${GUI_GATE:-1}" = "0" ] && return 1
  [ -z "${DISPLAY:-}" ] && return 1
  command -v wish >/dev/null 2>&1 || return 1
  return 0
}

_gate_widget_alive() {
  local pf="$GATE_DIR/widget.pid"
  [ -f "$pf" ] || return 1
  local wp; wp="$(cat "$pf" 2>/dev/null)"
  [ -n "$wp" ] && kill -0 "$wp" 2>/dev/null
}

_gate_ensure_widget() {
  _gate_widget_alive && return 0
  mkdir -p "$GATE_DIR/req" "$GATE_DIR/status"
  # A plain `( wish ... & )` leaves the panel in the LAUNCHING SUITE'S process
  # group, so anything that kills that group -- which is how a background/CI
  # task is normally torn down when it finishes -- kills the panel too. Measured:
  # `kill -TERM -<pgid>` after a suite ended took the widget with it and left a
  # stale widget.pid behind (dead process, no WM_DELETE_WINDOW, so none of
  # on_close's cleanup ran). The panel is a SINGLETON meant to outlive every
  # individual suite, so it gets its own session. A stale pid file loses the
  # singleton race harmlessly: _gate_widget_alive kill -0's it.
  if command -v setsid >/dev/null 2>&1; then
    ( setsid wish "$_GATE_SELF_DIR/gui_gate_widget.tcl" "$GATE_DIR" >/dev/null 2>&1 & )
  else
    ( wish "$_GATE_SELF_DIR/gui_gate_widget.tcl" "$GATE_DIR" >/dev/null 2>&1 & )
  fi
  # wait briefly for it to write its pid
  local i
  for i in $(seq 1 20); do _gate_widget_alive && return 0; sleep 0.15; done
  _gate_widget_alive
}

_gate_control() { cat "$GATE_DIR/control" 2>/dev/null; }

# _gate_attention — make sure the panel is visible ON THE DESKTOP THE USER IS
# LOOKING AT. A panel nobody sees is worse than no panel: the suite still waits
# out its countdown and then floods a display the user never got to defend.
#
# Under a virtual-desktop manager (the user runs VirtuaWin) a window created on
# desktop A is simply not reachable from desktop B — `raise` and -topmost act
# WITHIN a desktop, and there is no portable way to ask which desktop a window
# is on, let alone move it. So the only reliable way to pop the panel where the
# user actually is, is to RELAUNCH it: a fresh window maps on the current
# desktop. The user authorised the kill explicitly.
#
# NEVER while PAUSED. Pause is the one state that means "I am here, hold off",
# and a dead panel FAILS OPEN by design (gate_pause_point returns 0 when the
# widget is gone) — so killing it mid-pause would march every held suite
# straight through the hold. Not raising a paused panel costs nothing: the user
# who pressed Pause is by definition at the desk.
#
# A plain TERM is deliberate: the widget's WM_DELETE_WINDOW handler releases
# every pending request (closing the panel must not wedge a suite), and running
# that here would let this suite through ungated. TERM kills it outright.
_gate_attention() {
  [ "$(_gate_control)" = "PAUSE" ] && return 0

  # don't thrash when several suites start within moments of each other
  local stamp="$GATE_DIR/last_raise" now prev
  now="$(date +%s)"
  if [ -f "$stamp" ]; then
    prev="$(cat "$stamp" 2>/dev/null || echo 0)"
    [ "$((now - prev))" -lt 10 ] && return 0
  fi
  printf '%s' "$now" > "$stamp"

  if _gate_widget_alive; then
    local wp i; wp="$(cat "$GATE_DIR/widget.pid" 2>/dev/null)"
    kill "$wp" 2>/dev/null
    for i in $(seq 1 10); do _gate_widget_alive || break; sleep 0.1; done
    _gate_widget_alive && kill -9 "$wp" 2>/dev/null
    rm -f "$GATE_DIR/widget.pid"
  fi
  _gate_ensure_widget
}

# gate_start "<label>" — block until acked (Proceed) / snooze-expired.
gate_start() {
  _gate_enabled || return 0
  local label="${1:-test suite ($_GATE_PID)}"
  mkdir -p "$GATE_DIR/req" "$GATE_DIR/status"

  # A STOP already standing when we arrive was aimed at some EARLIER suite --
  # this one has never been told to stop, and the control file outlives the
  # process that was stopped. Left alone it would make every future suite exit
  # 3 forever: a hold no user asked for, which breaks the rule that only PAUSE
  # holds tests up. Clear it; a Stop pressed while we wait is caught below.
  if [ "$(_gate_control)" = "STOP" ]; then
    printf '%s' RUN > "$GATE_DIR/control" 2>/dev/null
  fi

  # Arm the go-ahead request for THIS suite BEFORE touching the panel, so that
  # the (possibly just-relaunched) widget sees it on its very first poll and
  # flashes for it immediately.
  local req="$GATE_DIR/req/$_GATE_PID"
  printf '%s' "$label" > "$req"

  # pop the panel onto the desktop the user is actually looking at
  _gate_attention

  if ! _gate_ensure_widget; then
    echo "gui_gate: panel unavailable, proceeding without gate" >&2
    rm -f "$req"
    return 0
  fi
  echo "gui_gate: '$label' waiting for go-ahead in the control panel..." >&2
  while [ -f "$req" ]; do
    _gate_widget_alive || { echo "gui_gate: panel gone, proceeding" >&2; rm -f "$req"; break; }
    sleep 0.3
  done
  # Stop pressed while we were waiting?
  [ "$(_gate_control)" = "STOP" ] && return 2
  return 0
}

# gate_pause_point "<status>" — hold while Paused; 2 on Stop.
gate_pause_point() {
  _gate_enabled || return 0
  local status="${1:-}"
  mkdir -p "$GATE_DIR/status"
  printf '%s' "$status" > "$GATE_DIR/status/$_GATE_PID"
  while true; do
    local c; c="$(cat "$GATE_DIR/control" 2>/dev/null)"
    case "$c" in
      PAUSE)
        _gate_widget_alive || return 0   # dead panel -> fail open
        sleep 0.3 ;;
      STOP) return 2 ;;
      *) return 0 ;;
    esac
  done
}

gate_finish() {
  rm -f "$GATE_DIR/status/$_GATE_PID" "$GATE_DIR/req/$_GATE_PID" 2>/dev/null
  return 0
}
