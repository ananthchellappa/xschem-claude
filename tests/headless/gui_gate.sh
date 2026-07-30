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

# _gate_log — a timestamped, shell-side event trail (panel launched / died /
# revived / fail-open taken).
#
# The panel's own stderr (widget.log, below) is NOT enough on its own:
# _gate_ensure_widget truncates that file on every launch, so a revive destroys
# the record of the death that caused it. Measured on the sibling review gate --
# it had stderr capture, its panel really did die and relaunch, and the log was
# 0 bytes minutes later. This file is the thing that turns "the panel vanished
# and nobody knows why" into a one-line answer.
#
# Capped, so a long soak cannot grow it without bound.
_gate_log() {
  local f="$GATE_DIR/events.log" n
  mkdir -p "$GATE_DIR" 2>/dev/null
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null)" \
         "$_GATE_PID" "$*" >> "$f" 2>/dev/null
  n="$(wc -l < "$f" 2>/dev/null || echo 0)"
  if [ "${n:-0}" -gt 400 ] 2>/dev/null; then
    tail -n 200 "$f" > "$f.tmp" 2>/dev/null && mv -f "$f.tmp" "$f" 2>/dev/null
  fi
  return 0
}

# _gate_widget_alive — is OUR panel running? Identity, not merely liveness.
#
# `kill -0` alone trusts a pid file that outlives both the process and the boot.
# pids recycle: the counter restarts at every WSL boot while widget.pid persists
# across boots, so a stale file can name a live, innocent process within hours.
# Believing that would be the one failure this gate cannot survive --
# _gate_ensure_widget would no-op, no panel would ever launch, and gate_start's
# wait loop would spin FOREVER (nothing deletes the req, liveness never fails):
# the exact inverse of the fail-open contract. _gate_attention would also TERM
# and then SIGKILL that innocent process.
#
# An unreadable /proc is accepted, not treated as a mismatch: unverifiable is
# not the same as wrong, and guessing "dead" there would launch a second panel
# on every single call.
_gate_widget_alive() {
  local pf="$GATE_DIR/widget.pid"
  [ -f "$pf" ] || return 1
  local wp; wp="$(cat "$pf" 2>/dev/null)"
  [ -n "$wp" ] || return 1
  kill -0 "$wp" 2>/dev/null || return 1
  if [ -r "/proc/$wp/cmdline" ]; then
    tr '\0' ' ' < "/proc/$wp/cmdline" 2>/dev/null | grep -q gui_gate_widget || return 1
  fi
  return 0
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
  # NEVER /dev/null. The panel died mid-suite on 2026-07-30 and there was no way
  # to find out why, because wish's stderr had been discarded -- the one line
  # that would have named the killer ("X connection to :0 broken") went nowhere.
  # Truncated per launch, so it cannot grow without bound; the durable trail is
  # events.log (_gate_log), which a relaunch does not erase.
  local log="$GATE_DIR/widget.log"
  if command -v setsid >/dev/null 2>&1; then
    ( setsid wish "$_GATE_SELF_DIR/gui_gate_widget.tcl" "$GATE_DIR" >"$log" 2>&1 & )
  else
    ( wish "$_GATE_SELF_DIR/gui_gate_widget.tcl" "$GATE_DIR" >"$log" 2>&1 & )
  fi
  # wait briefly for it to write its pid
  local i
  for i in $(seq 1 20); do
    _gate_widget_alive && { _gate_log "panel launched pid=$(cat "$GATE_DIR/widget.pid" 2>/dev/null)"; return 0; }
    sleep 0.15
  done
  _gate_log "panel launch FAILED (see $log)"
  _gate_widget_alive
}

# _gate_revive_widget — bring the panel back MID-SUITE.
#
# Why this has to exist: WSLg's Xwayland aborts on its own
# ("(EE) request could not be marshaled: can't send file descriptor", SIGABRT --
# three times in one nine-hour session on 2026-07-30). Every X client dies with
# it, and a Tk client dies BADLY: libX11's default I/O error handler simply
# exit(1)s and Tk installs none, so WM_DELETE_WINDOW never runs, on_close never
# runs, and the panel leaves a stale widget.pid behind.
#
# Until this existed, _gate_ensure_widget was reachable ONLY from gate_start --
# which runs once per suite invocation. A panel that died BETWEEN suites was
# quietly rebuilt by the next gate_start and nobody noticed; a panel that died
# DURING one stayed dead. Measured: 27 minutes of a 150-run soak with no Pause
# button, which is the exact scenario this whole gate was built to prevent.
#
# THROTTLED, never once-only: three aborts in one session, and a soak outlives
# several. GUI_GATE_REVIVE_EVERY overrides the interval (seconds).
_gate_revive_widget() {
  # ONLY revive a panel that CRASHED, never one the user closed.
  #
  # Those two are distinguishable, and the distinction is the whole forensic
  # signature of the 07-30 death: on_close (WM_DELETE_WINDOW) deletes
  # widget.pid, whereas a signalled/X-severed panel cannot run on_close at all
  # and leaves the file behind. So a MISSING widget.pid means "the user shut me
  # down" -- which the spec defines as "get out of the way" -- and resurrecting
  # it one pause point later would be the gate arguing with the user.
  [ -f "$GATE_DIR/widget.pid" ] || return 1

  local stamp="$GATE_DIR/last_revive" now prev
  now="$(date +%s)"
  if [ -f "$stamp" ]; then
    prev="$(cat "$stamp" 2>/dev/null || echo 0)"
    [ "$((now - prev))" -lt "${GUI_GATE_REVIVE_EVERY:-30}" ] && return 1
  fi
  printf '%s' "$now" > "$stamp"
  _gate_log "panel death detected -- reviving"
  # drop the corpse's pid file first, or _gate_ensure_widget's own liveness
  # check could race a pid that is being reaped
  rm -f "$GATE_DIR/widget.pid"
  if _gate_ensure_widget; then _gate_log "panel revived"; return 0; fi
  _gate_log "revive FAILED -- suite continues UNGATED"
  return 1
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

# _gate_grant_live — is a user APPROVAL WINDOW currently open?
#
# The gate warns before EVERY suite, which is right for one big run and wrong
# for the way testing is actually done: forty tiny suites, each a couple of
# seconds long, meant one Proceed press each -- or, with nobody at the desk,
# forty two-minute autostart waits to run about two minutes of tests. The gate
# was costing an order of magnitude more time than the tests it guarded.
#
# So Proceed gained siblings: "Allow 30m"/"Allow 2h" write an epoch into
# allow_until, and while that is in the future a suite starts WITHOUT asking --
# no request, no countdown, no panel relaunch. The user approves once and walks
# away. Pause and Stop are untouched by this: they are read at every pause
# point, so an approved batch is still fully controllable (that is the whole
# point of approving it and leaving).
#
# The panel owns this file; the shell only ever reads it.
_gate_grant_live() {
  local f="$GATE_DIR/allow_until" until now
  [ -f "$f" ] || return 1
  until="$(cat "$f" 2>/dev/null)"
  case "${until:-}" in ''|*[!0-9]*) return 1 ;; esac
  now="$(date +%s)"
  [ "$now" -lt "$until" ]
}

# gate_start "<label>" — block until acked (Proceed) / snooze-expired / covered
# by an approval window.
gate_start() {
  _gate_enabled || return 0
  local label="${1:-test suite ($_GATE_PID)}"
  mkdir -p "$GATE_DIR/req" "$GATE_DIR/status"

  # An interrupted suite (Ctrl-C, `timeout`, a worktree being torn down) used to
  # orphan status/<pid> forever. The panel then lists a suite that is not
  # running, and -- because STOP only self-clears once no status file remains --
  # never puts `control` back to RUN, which silently resurrects the v2 bug where
  # one Stop press made every future suite exit 3. Only install the trap if the
  # caller has not set its own; stealing a script's EXIT handler would be worse
  # than the leak.
  if [ -z "$(trap -p EXIT)" ]; then trap 'gate_finish' EXIT; fi
  if [ -z "$(trap -p INT)"  ]; then trap 'gate_finish' INT;  fi
  if [ -z "$(trap -p TERM)" ]; then trap 'gate_finish' TERM; fi

  # A STOP already standing when we arrive was aimed at some EARLIER suite --
  # this one has never been told to stop, and the control file outlives the
  # process that was stopped. Left alone it would make every future suite exit
  # 3 forever: a hold no user asked for, which breaks the rule that only PAUSE
  # holds tests up. Clear it; a Stop pressed while we wait is caught below.
  if [ "$(_gate_control)" = "STOP" ]; then
    printf '%s' RUN > "$GATE_DIR/control" 2>/dev/null
  fi

  # An open approval window covers this suite: start at once, ask nothing.
  # Still ensure a panel exists -- QUIETLY, no _gate_attention -- because the
  # whole bargain is "approve once, walk away, and keep Pause/Stop". A batch
  # running with no panel would be exactly the flood this gate exists to
  # prevent. (Ensuring one here is not the mid-suite revive and does not
  # contradict it: a NEW suite has always built a panel if none was up.)
  if _gate_grant_live; then
    local gc; gc="$(cat "$GATE_DIR/grant_count" 2>/dev/null || echo 0)"
    case "$gc" in ''|*[!0-9]*) gc=0 ;; esac
    printf '%s' "$((gc + 1))" > "$GATE_DIR/grant_count" 2>/dev/null
    _gate_ensure_widget >/dev/null 2>&1
    _gate_log "approval window open -- '$label' starts without asking"
    echo "gui_gate: approved batch window open, starting '$label' (no prompt)" >&2
    return 0
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
    if ! _gate_widget_alive; then
      # A panel that dies while a suite waits is not "the gate is over": the
      # user has still never seen this request. Try to bring it back, and only
      # fall through to the fail-open contract if it will not stay up.
      if ! _gate_revive_widget; then
        _gate_log "panel gone during gate_start -- proceeding ungated"
        echo "gui_gate: panel gone, proceeding" >&2; rm -f "$req"; break
      fi
    fi
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

  # THE hole this closes. Liveness used to be tested ONLY inside the PAUSE
  # branch below, so in the normal RUN state a suite never noticed that its
  # panel had died -- and nothing anywhere brought one back before the next
  # gate_start, which does not come until the next suite. This function is the
  # only gate code that runs for the whole life of a suite, so the check belongs
  # here, ahead of reading `control`.
  #
  # Best-effort BY CONSTRUCTION: the result is deliberately discarded. A gate
  # that turned a missing panel into a blocked suite would have broken its own
  # one rule to fix a lesser bug.
  _gate_widget_alive || _gate_revive_widget || true

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
