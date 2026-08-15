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

# --- v6 tunables (see "The launch is ASYNCHRONOUS and TRACKED" below) -------
# How long a launch is watched synchronously before it is left to be adopted
# later. 3 s is generous for a HEALTHY X server: measured fork -> pidfile is
# 106 ms idle and 76-92 ms with 20 CPU hogs running on a 14-core box (loadavg
# 10-16) -- ~33x of headroom. Load was never what broke this.
_GATE_LAUNCH_POLL="${GUI_GATE_LAUNCH_POLL:-20}"        # x 0.15 s
# How long a pidfile-less wish is given before it is reaped as an orphan.
# Worst case actually observed end to end was 134 s (a weston restart whose
# Xwayland respawn was itself 54 s late); 180 s keeps ~35% headroom.
_GATE_PENDING_DEADLINE="${GUI_GATE_PENDING_DEADLINE:-180}"
# How long a widget.pid.crashed corpse marker keeps authorising revives.
_GATE_CRASH_TTL="${GUI_GATE_CRASH_TTL:-1800}"
# Age at which revive.lock is broken even though its owner still looks alive.
_GATE_LOCK_TTL="${GUI_GATE_LOCK_TTL:-300}"
_GATE_LOCK_DEPTH=0

_gate_now() { date +%s; }

# Is $DISPLAY the persistent dev display? (doc/claude/specs/dev_display.md)
#
# Deliberately a file read and not a liveness probe: this sits in a hot path,
# and if DISPLAY *names* the dev display the run is invisible either way, so a
# panel there is useless whether or not our pid check would pass.
_gate_dev_display() {
  local f="${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}/display"
  [ -r "$f" ] || return 1
  local d; d=$(cat "$f" 2>/dev/null)
  [ -n "$d" ] && [ "$d" = "${DISPLAY:-}" ]
}

_gate_enabled() {
  [ "${GUI_GATE:-1}" = "0" ] && return 1
  [ -z "${DISPLAY:-}" ] && return 1
  # THE HAZARD, arriving by a second route. _gate_enabled only tests that
  # DISPLAY is non-empty, so an INVISIBLE display arms the gate exactly like a
  # real one; gate_start then reaches _gate_attention, which kills the live
  # panel and relaunches it with the calling suite's DISPLAY -- moving the
  # user's Pause/Stop panel onto a display nobody can see, for every session
  # sharing this control dir. xvfb_arm.sh contains that by forcing GUI_GATE=0,
  # but a script that sources THIS and not the arm, inheriting DISPLAY=:99 from
  # the developer's shell, would walk straight into it. A dev display without
  # this exclusion does not free the screen; it breaks the Pause button.
  _gate_dev_display && return 1
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
_gate_is_panel_pid() {
  local p="${1:-}"
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$p" 2>/dev/null || return 1
  # A backgrounded wish that exited leaves a ZOMBIE until this shell reaps it,
  # and `kill -0` succeeds on a zombie. Its /proc/<pid>/cmdline is empty, so the
  # identity test below reads it as dead -- which is what we want.
  if [ -r "/proc/$p/cmdline" ]; then
    tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q gui_gate_widget || return 1
  fi
  return 0
}

_gate_widget_alive() {
  local pf="$GATE_DIR/widget.pid"
  [ -f "$pf" ] || return 1
  local wp; wp="$(cat "$pf" 2>/dev/null)"
  _gate_is_panel_pid "$wp"
}

# --- v6: markers -----------------------------------------------------------
# widget.launching     "<pid> <epoch>" -- a wish we forked that has not written
#                      widget.pid yet. Its existence is what stops a second one.
# widget.pid.crashed   "<pid> <epoch>" -- the corpse of a panel we are trying to
#                      revive. v4/v5 DELETED widget.pid before relaunching and
#                      never put it back, so one failed attempt tripped the
#                      revive's own "[ -f widget.pid ] || return 1" precondition
#                      (the deliberate-close rule) and silenced every later
#                      attempt for the rest of the run, with no log line at all.
#                      Measured: weston aborted again 80 s into the same 283-test
#                      audit and events.log has no gate event for it.
_gate_marker_pid()   { local v; v="$(cat "$1" 2>/dev/null)"; printf '%s' "${v%% *}"; }
_gate_marker_epoch() {
  local v e; v="$(cat "$1" 2>/dev/null)"; e="${v##* }"
  case "$e" in ''|*[!0-9]*) e=0 ;; esac; printf '%s' "$e"
}
_gate_marker_age()   { echo $(( $(_gate_now) - $(_gate_marker_epoch "$1") )); }

_gate_kill_pid() {
  local p="${1:-}" i
  _gate_is_panel_pid "$p" || return 0
  kill "$p" 2>/dev/null
  for i in $(seq 1 20); do _gate_is_panel_pid "$p" || return 0; sleep 0.1; done
  kill -9 "$p" 2>/dev/null
  return 0
}

# --- v6: the revive lock ---------------------------------------------------
# The control dir is shared by the main session AND every worktree/subagent run,
# and events.log routinely shows several suite pids alive at once. The throttle
# was a non-atomic read-then-write and nothing serialised the corpse handling or
# the launch, so two suites in the same second could both pass the throttle,
# both drop the pid file and both fork a panel. Re-entrant (depth counter) so
# _gate_revive_widget can call _gate_ensure_widget while holding it.
# SELF-EXPIRING: a lock whose owner is dead, or simply older than _GATE_LOCK_TTL,
# is broken -- a SIGKILLed suite must not disable revives for everyone else.
_gate_lock() {
  local d="$GATE_DIR/revive.lock" tries="${1:-0}" own opid oep now
  if [ "${_GATE_LOCK_DEPTH:-0}" -gt 0 ]; then
    _GATE_LOCK_DEPTH=$((_GATE_LOCK_DEPTH + 1)); return 0
  fi
  mkdir -p "$GATE_DIR" 2>/dev/null
  while : ; do
    if mkdir "$d" 2>/dev/null; then
      printf '%s %s' "$_GATE_PID" "$(_gate_now)" > "$d/owner" 2>/dev/null
      _GATE_LOCK_DEPTH=1
      return 0
    fi
    own="$(cat "$d/owner" 2>/dev/null)"
    opid="${own%% *}"; oep="${own##* }"
    case "$oep" in ''|*[!0-9]*) oep=0 ;; esac
    now="$(_gate_now)"
    if [ -z "$opid" ] || ! kill -0 "$opid" 2>/dev/null \
       || [ "$((now - oep))" -ge "$_GATE_LOCK_TTL" ]; then
      _gate_log "breaking stale revive lock (owner=${opid:-?})"
      rm -rf "$d" 2>/dev/null
      continue
    fi
    [ "$tries" -gt 0 ] || return 1
    tries=$((tries - 1))
    sleep 0.2
  done
}

_gate_unlock() {
  [ "${_GATE_LOCK_DEPTH:-0}" -gt 0 ] || return 0
  _GATE_LOCK_DEPTH=$((_GATE_LOCK_DEPTH - 1))
  [ "$_GATE_LOCK_DEPTH" -eq 0 ] && rm -rf "$GATE_DIR/revive.lock" 2>/dev/null
  return 0
}

# _gate_reconcile — called when a panel IS alive: settle the markers.
# This is where a LATE launch is adopted (the thing that used to happen by
# accident: on 2026-08-04 a wish declared "FAILED" wrote its pidfile 134 s later
# and became the real panel, unsupervised, while the suite ran ungated).
_gate_reconcile() {
  local f="$GATE_DIR/widget.launching" wp pend age
  wp="$(cat "$GATE_DIR/widget.pid" 2>/dev/null)"
  if [ -f "$f" ]; then
    pend="$(_gate_marker_pid "$f")"; age="$(_gate_marker_age "$f")"
    if [ -n "$pend" ] && [ "$pend" = "$wp" ]; then
      _gate_log "panel revived late (+${age}s) pid=$pend -- adopted"
    elif _gate_is_panel_pid "$pend"; then
      # someone else's panel won the race: never leave two
      _gate_kill_pid "$pend"
      _gate_log "duplicate panel pid=$pend reaped (live panel is ${wp:-?})"
    fi
    rm -f "$f" 2>/dev/null
  fi
  rm -f "$GATE_DIR/widget.pid.crashed" 2>/dev/null
  return 0
}

# _gate_pending_state — 0: a launch is still in flight, do NOT fork another.
#                       1: nothing pending (any corpse has been reaped).
# Call under the lock.
_gate_pending_state() {
  local f="$GATE_DIR/widget.launching" pid age
  [ -f "$f" ] || return 1
  pid="$(_gate_marker_pid "$f")"; age="$(_gate_marker_age "$f")"
  if ! _gate_is_panel_pid "$pid"; then
    rm -f "$f" 2>/dev/null
    _gate_log "pending panel launch gone after ${age}s -- will retry"
    return 1
  fi
  if [ "$age" -ge "$_GATE_PENDING_DEADLINE" ]; then
    # THE anti-orphan clause, and the only place a wish is killed for being
    # slow. A pidfile-less wish this old is one that will map a window nobody
    # asked for, minutes after the suite gave up on it.
    _gate_kill_pid "$pid"
    rm -f "$f" 2>/dev/null
    _gate_log "panel launch abandoned after ${age}s (no usable X server); orphan wish pid=$pid reaped"
    return 1
  fi
  return 0
}

# _gate_revive_authorised — may we (re)build a panel at all?
# widget.pid present         -> a panel died without running on_close (crash)
# widget.pid.crashed present -> we are already mid-revive after such a death
# widget.launching present   -> we already forked one; adopt or reap it
# NONE of them -> the user CLOSED the panel (on_close deletes all three) and
# "get out of the way" is exactly what that means.
_gate_revive_authorised() {
  [ -f "$GATE_DIR/widget.pid" ] && return 0
  [ -f "$GATE_DIR/widget.launching" ] && return 0
  if [ -f "$GATE_DIR/widget.pid.crashed" ]; then
    if [ "$(_gate_marker_age "$GATE_DIR/widget.pid.crashed")" -ge "$_GATE_CRASH_TTL" ]; then
      rm -f "$GATE_DIR/widget.pid.crashed" 2>/dev/null
      _gate_log "crash marker expired -- no further revives until the next gate_start"
      return 1
    fi
    return 0
  fi
  return 1
}

# _gate_launch_widget — fork ONE wish and TRACK it. Call under the lock.
#
# THE LAUNCH IS ASYNCHRONOUS (v6, 2026-08-04). v4/v5 polled for 3.0 s
# (20 x 0.15) and, if widget.pid had not appeared, declared "panel launch
# FAILED", continued UNGATED and walked away from a live wish. That happened
# SEVEN times in one day. The 3 s were never wish's:
#
#   * WSLg dies two ways. (A) Xwayland alone exits ("xserver exited, code 134")
#     with weston alive -- weston respawns it in 2-60 MILLISECONDS, and every
#     revive in that mode succeeded. (B) weston itself SIGABRTs and WSLGd
#     restarts the compositor; the fresh weston binds :0 at once but spawns
#     Xwayland LAZILY: 2.83, 2.89, 2.91, 2.91, 3.05 s later -- and once 54.4 s.
#     Every "revive FAILED" was a mode-B abort; the one mode-B whose respawn was
#     instant (20 ms) is the one revive that succeeded.
#   * wish does not fail fast against a socket that accepts but never completes
#     the X handshake -- it BLOCKS, writes nothing to stderr, and never reaches
#     the line that writes widget.pid. Measured: 25 s with zero output; against
#     a display with no listener at all, 269 s (Xlib's TCP fallback retrying
#     SYNs). So "empty widget.log + no widget.pid + a live wish" is the NORMAL
#     outcome of launching into a restarting compositor, not an anomaly.
#   * wish itself is never the problem: fork -> pidfile is 106-107 ms idle and
#     113-121 ms under 20 busy loops plus exec churn on a 14-core box. 3 s is 25x
#     that. Lengthening the poll to cover the observed 134 s would block a pause
#     point for 134 s and break the one rule.
#
# So the fast path keeps its 3 s, and a launch that is still in flight is
# RECORDED (widget.launching) instead of abandoned: the suite carries on
# ungated -- honestly, and saying so -- and a later pause point adopts the panel
# when it finally connects, or reaps it at _GATE_PENDING_DEADLINE.
_gate_launch_widget() {
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
  #
  # Backgrounded DIRECTLY (not inside `( ... & )`) so that $! names the wish:
  # `setsid cmd &` from a non-job-control shell is not a process-group leader,
  # so setsid execs in place rather than forking (verified: pid == pgid == sid,
  # /proc/<pid>/cmdline is the wish command line). Without that pid there is
  # nothing to adopt and nothing to reap.
  local log="$GATE_DIR/widget.log" pid i
  if command -v setsid >/dev/null 2>&1; then
    setsid wish "$_GATE_SELF_DIR/gui_gate_widget.tcl" "$GATE_DIR" >"$log" 2>&1 &
  else
    wish "$_GATE_SELF_DIR/gui_gate_widget.tcl" "$GATE_DIR" >"$log" 2>&1 &
  fi
  pid=$!
  printf '%s %s' "$pid" "$(_gate_now)" > "$GATE_DIR/widget.launching"

  # wait briefly for it to write its pid (the healthy case: ~0.11 s)
  for i in $(seq 1 "$_GATE_LAUNCH_POLL"); do
    if _gate_widget_alive; then
      rm -f "$GATE_DIR/widget.launching" "$GATE_DIR/widget.pid.crashed" 2>/dev/null
      _gate_log "panel launched pid=$(cat "$GATE_DIR/widget.pid" 2>/dev/null)"
      return 0
    fi
    _gate_is_panel_pid "$pid" || break     # wish exited outright: nothing to wait for
    sleep 0.15
  done

  # 2 = PENDING (a live wish we will adopt or reap later)
  # 1 = FAILED   (wish is gone; nothing to adopt, nothing leaked)
  if _gate_is_panel_pid "$pid"; then
    _gate_log "panel launch PENDING pid=$pid (X server may be restarting) -- suite continues UNGATED for now; will adopt at a later pause point"
    return 2
  fi
  rm -f "$GATE_DIR/widget.launching" 2>/dev/null
  _gate_log "panel launch FAILED (wish exited, see $log)"
  return 1
}

# _gate_ensure_widget — a panel exists, or one is on its way. Never two.
_gate_ensure_widget() {
  _gate_widget_alive && { _gate_reconcile; return 0; }
  if ! _gate_lock 0; then
    # another suite is launching RIGHT NOW: wait for its panel rather than fork
    # a second one. Same 3 s budget, spent on somebody else's wish.
    local i
    for i in $(seq 1 "$_GATE_LAUNCH_POLL"); do
      _gate_widget_alive && { _gate_reconcile; return 0; }
      sleep 0.15
    done
    return 1
  fi
  local rc
  if _gate_widget_alive; then _gate_reconcile; rc=0
  elif _gate_pending_state;  then rc=1       # in flight: adopt/reap it later
  else _gate_launch_widget; rc=$?; if [ "$rc" -ne 0 ]; then rc=1; fi
  fi
  _gate_unlock
  return "$rc"
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
# Throttle. Read-then-write, so it is only sound under the revive lock.
_gate_throttle_ok() {
  local stamp="$GATE_DIR/last_revive" now prev
  now="$(_gate_now)"
  if [ -f "$stamp" ]; then
    prev="$(cat "$stamp" 2>/dev/null || echo 0)"
    case "$prev" in ''|*[!0-9]*) prev=0 ;; esac
    [ "$((now - prev))" -lt "${GUI_GATE_REVIVE_EVERY:-30}" ] && return 1
  fi
  printf '%s' "$now" > "$stamp"
  return 0
}

_gate_revive_widget() {
  # Free win first, and unthrottled: a launch we started earlier may have
  # connected in the meantime. Adopting it is the whole point of v6.
  if _gate_widget_alive; then _gate_reconcile; return 0; fi

  # ONLY revive a panel that CRASHED (or a launch we already own), never one the
  # user closed.
  #
  # Those two are distinguishable, and the distinction is the whole forensic
  # signature of the 07-30 death: on_close (WM_DELETE_WINDOW) deletes
  # widget.pid, whereas a signalled/X-severed panel cannot run on_close at all
  # and leaves the file behind. So NO marker at all means "the user shut me
  # down" -- which the spec defines as "get out of the way" -- and resurrecting
  # it one pause point later would be the gate arguing with the user. on_close
  # deletes all three markers precisely so that a close during a failed revive
  # still means stay away.
  _gate_revive_authorised || return 1

  _gate_lock 0 || return 1          # another suite is already on it
  local rc=1
  if _gate_widget_alive; then _gate_reconcile; rc=0
  elif _gate_pending_state; then rc=1            # in flight; stay ungated, quietly
  elif ! _gate_revive_authorised; then rc=1      # marker expired under us
  elif ! _gate_throttle_ok; then rc=1
  else
    _gate_log "panel death detected -- reviving"
    # Rename the corpse, NEVER delete it: widget.pid is the only evidence that
    # this panel crashed rather than being closed, and v4/v5 destroyed it before
    # every launch. One failed launch then made _gate_revive_authorised's own
    # precondition false for the rest of the run -- silently.
    if [ -f "$GATE_DIR/widget.pid" ]; then
      printf '%s %s' "$(cat "$GATE_DIR/widget.pid" 2>/dev/null)" "$(_gate_now)" \
        > "$GATE_DIR/widget.pid.crashed" 2>/dev/null
      rm -f "$GATE_DIR/widget.pid"
    fi
    _gate_launch_widget; local lrc=$?
    case "$lrc" in
      0) _gate_log "panel revived"; rc=0 ;;
      2) _gate_log "revive PENDING -- suite continues UNGATED until that wish connects"; rc=1 ;;
      *) _gate_log "revive FAILED -- suite continues UNGATED"; rc=1 ;;
    esac
  fi
  _gate_unlock
  return "$rc"
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
    # v6: leave a CORPSE, not a hole. This path kills a healthy panel on
    # purpose, and if the relaunch lands during a compositor restart it goes
    # PENDING like any other -- without the marker, the "no marker = the user
    # closed it" rule would then block every later revive and the user would be
    # left with no panel at all. (Same defect, same code path, as the revive.)
    printf '%s %s' "$wp" "$(_gate_now)" > "$GATE_DIR/widget.pid.crashed" 2>/dev/null
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
#
# The "Forever" button writes the literal word instead of an epoch. It is
# matched as a KEYWORD, before the numeric test, and nothing else non-numeric is
# accepted: this file is shared mutable state that outlives every process here,
# so anything unrecognised in it must keep meaning "no grant" (test_gui_gate_batch
# B4 writes "yes please" and asserts it is ignored). One word in, everything
# else still rejected.
_gate_grant_live() {
  local f="$GATE_DIR/allow_until" until now
  [ -f "$f" ] || return 1
  until="$(cat "$f" 2>/dev/null)"
  [ "${until:-}" = forever ] && return 0
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
  #
  # v6: when the panel IS alive this also settles the markers -- adopting a
  # launch that connected late, or reaping the duplicate that lost a race. That
  # is why the healthy branch is no longer a bare no-op.
  if _gate_widget_alive; then _gate_reconcile; else _gate_revive_widget || true; fi

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
