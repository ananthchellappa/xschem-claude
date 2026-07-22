#!/bin/bash
# gui_gate.sh — shell side of the GUI-test control gate (see
# tests/headless/gui_gate_widget.tcl and doc/claude/specs/gui_test_gate.md).
#
# Source this, then:
#   gate_start "<suite-label>"      # warn + block until the user clicks Proceed
#                                   #   (or a Snooze timer auto-proceeds)
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
#     never blocks testing — the suite just runs.
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
  # a stale pid file loses the singleton race harmlessly; launch detached
  ( wish "$_GATE_SELF_DIR/gui_gate_widget.tcl" "$GATE_DIR" >/dev/null 2>&1 & )
  # wait briefly for it to write its pid
  local i
  for i in $(seq 1 20); do _gate_widget_alive && return 0; sleep 0.15; done
  _gate_widget_alive
}

# gate_start "<label>" — block until acked (Proceed) / snooze-expired.
gate_start() {
  _gate_enabled || return 0
  local label="${1:-test suite ($_GATE_PID)}"
  mkdir -p "$GATE_DIR/req" "$GATE_DIR/status"
  if ! _gate_ensure_widget; then
    echo "gui_gate: panel unavailable, proceeding without gate" >&2
    return 0
  fi
  # (re)arm the go-ahead request for THIS suite -> the panel warns for every
  # suite (user choice). Blocks until the panel removes our request file.
  local req="$GATE_DIR/req/$_GATE_PID"
  printf '%s' "$label" > "$req"
  echo "gui_gate: '$label' waiting for go-ahead in the control panel..." >&2
  while [ -f "$req" ]; do
    _gate_widget_alive || { echo "gui_gate: panel gone, proceeding" >&2; rm -f "$req"; break; }
    sleep 0.3
  done
  # Stop pressed while we were waiting?
  [ "$(cat "$GATE_DIR/control" 2>/dev/null)" = "STOP" ] && return 2
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
