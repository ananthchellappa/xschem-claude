#!/bin/bash
# wslg_health.sh — is this X display healthy enough for GUI test results to
# MEAN anything?  (issue 0310; spec doc/claude/specs/wslg_health_probe.md)
#
#   tests/headless/wslg_health.sh            # probe $DISPLAY
#   tests/headless/wslg_health.sh :0         # probe a named display
#   tests/headless/wslg_health.sh -q         # one-line verdict only
#
# WHY IT EXISTS.  WSLg's Xwayland aborts on its own (see the gui_test_gate spec)
# and the display that comes BACK can be a 640x480 stub whose window manager
# parks every new top-level at absolute -32768.  It answers xdpyinfo.  Clients
# connect.  wish starts and maps windows.  Every liveness check in this harness
# reads green -- and GUI suites then run blind, producing numbers that look
# completely ordinary.  That already cost Batch F a whole item: an entire
# full_audit ran to completion against a stub and its diff was meaningless.
# LIVENESS IS NOT VISIBILITY, and that distinction is the whole point here.
#
# EXIT CODES (distinct on purpose -- "no display" is NOT a failure, and
# "not measured" is neither healthy nor stub):
#   0  HEALTHY    -- the display is real and places windows where it is asked to
#   1  UNHEALTHY  -- STUB display / windows parked off-screen / a wedged server.
#                    GUI results taken on it are a measurement of a different
#                    machine; re-run them after `wsl --shutdown`.
#   2  NODISPLAY  -- $DISPLAY unset, or no X server there at all.  The
#                    legitimate headless case.  NOT a fault.
#   3  UNKNOWN    -- the probe could not judge (a required tool is missing, or a
#                    display with no local socket did not answer).  Ruled a
#                    separate code rather than folded into 1 or 2: a silent
#                    downgrade to "healthy" is what this script exists to
#                    prevent, and calling a toolless box "STUB" would be a lie.
#   4  STOPPED    -- the GUI-test control panel is set to STOP.  NOTHING was
#                    mapped and this display was NOT measured.
#   5  DEFERRED   -- the panel is PAUSED and stayed paused past the bounded
#                    wait.  Again: NOTHING mapped, NOT measured.  Deliberately
#                    NOT 1: "I did not look" is not "the display is broken", and
#                    a caller that could not tell those two apart from healthy
#                    would be back to guessing.
#  64  usage error (EX_USAGE) -- deliberately NOT 2, so a typo can never be read
#                    as "this box is headless, carry on".  Covers an unknown
#                    option, a MALFORMED DISPLAY NAME (`0`, `:O`) and a second
#                    positional argument -- all three used to fall through to 2.
#
# THE CHECKS (all five were measured, on a healthy AND on a stub server):
#   1 server answers      xdpyinfo -- necessary, nowhere near sufficient
#   2 root geometry       xwininfo -root, against a FLOOR (not == 640x480): this
#                         machine legitimately alternates 5120x1440 / 2560x1440
#                         as monitors come and go, and a resize is not a fault
#   3 no parked window    xwininfo -root -tree, TWICE, with the probe in between.
#                         A window counts only if the SAME window id sits at the
#                         sentinel in BOTH samples.  MEASURED, on the healthy
#                         5120x1440 display: every ordinary window map passes
#                         through a transient `+-32768+-32768` WM frame (1 in 240
#                         one-shot snapshots taken across 6 wish launches; a
#                         reviewer saw 6 in 240 under load), so a single snapshot
#                         reports a perfectly good display as a STUB whenever
#                         anything else happens to be opening a window -- and
#                         this script promises to be safe to run while suites are
#                         in flight.  A real stub parks PERMANENTLY; a WM frame
#                         moves within ~30 ms.  The match is on MAGNITUDE
#                         (|x| or |y| > 30000), not on the text '+-327', which
#                         also matched an ordinary window at x=-327 or -3275 --
#                         normal on a 5120-wide multi-monitor desktop.
#   4 server uptime       stat /tmp/.X11-unix/X<n> -- the socket is recreated on
#                         every respawn.  INFORMATION, never a verdict: a server
#                         that restarted seconds ago is not broken, it just
#                         explains vanished windows and dead panels.
#   5 functional probe    THE DECISIVE ONE, and the only check that exercises
#                         placement: map a real Tk window and compare where it
#                         landed against where it asked to go.  Measured healthy:
#                         `want +200+200 got +206+227 screen 5120x1440` -- a WM
#                         decoration offset is CORRECT and must not be flagged,
#                         hence a tolerance rather than an equality test.  On the
#                         broken server the same probe read +-32730+-32709 with
#                         screen 640x480.  THE READ MUST SETTLE: measured on the
#                         HEALTHY display, winfo rootx immediately after
#                         `tkwait visibility` is -32730/-32709 -- byte-identical
#                         to the recorded stub value -- and only becomes 206/227
#                         after a ConfigureNotify has been processed, ~26 ms
#                         later and only under `update`, not `update idletasks`.
#                         A fixed `after N` therefore misreads a healthy display
#                         as a stub whenever the WM is slower than N, so the
#                         probe polls for two agreeing out-of-sentinel samples,
#                         and the whole probe is BEST OF 3: measured, the WM
#                         occasionally ignores the requested position and maps
#                         at the origin (`want +437+311 got +6+27`), 1 in 15 on
#                         a display that is entirely fine.  A stub fails every
#                         attempt; a WM hiccup does not.
#   +  Fatal server error count in /mnt/wslg/stderr.log -- reported as
#      INFORMATION only.  A rising count predicts more panel deaths; it does not
#      mean the results in hand are wrong.
#
# CONTRACT:
#   * Every X call gets a TIMEOUT.  A wedged server makes clients block forever
#     -- which is exactly one of the conditions being detected -- and a probe
#     that hangs on a hung display is useless.
#   * IT ANSWERS THE GUI-TEST CONTROL PANEL'S Pause AND Stop.  Check 5 MAPS A
#     WINDOW ON THE USER'S SCREEN, and the one invariant that whole harness
#     exists to protect is that anything which paints on that screen obeys that
#     button.  The first draft of this script did not, dozens of little probe
#     windows flashed during a sabotage run, the user pressed Pause and NOTHING
#     STOPPED -- which is why this paragraph is here.  Before it maps anything
#     it READS $GUI_GATE_DIR/control (default ~/.claude/gui_test_gate/control):
#       STOP  -> map nothing, report STOPPED, exit 4
#       PAUSE -> hold, polling, up to a BOUNDED overall wait; if it is still
#                paused at the end, map nothing, report DEFERRED, exit 5
#       RUN / missing / unreadable -> proceed.  FAIL OPEN, exactly like the
#                rest of the gate.
#     A PLAIN READ OF ONE SMALL FILE IS THE WHOLE MECHANISM.  It deliberately
#     does NOT source tests/headless/gui_gate.sh: this probe is meant to be
#     usable as a preflight from inside `gate_start` itself, and sourcing the
#     gate from something the gate calls is a circular dependency waiting to
#     bite.  It only ever READS; it never writes into the gate dir, which
#     belongs to the user and to the panel.
#   * It starts nothing, kills nothing, and is safe to run while suites are in
#     flight.
#   * Depends only on what this harness already uses: xdpyinfo, xwininfo, wish,
#     stat, coreutils.
#
# TESTABLE WITHOUT A STUB.  Xwayland cannot be crashed to order, so the JUDGEMENT
# is factored away from the measuring: wh_check_geometry / wh_check_sentinel /
# wh_check_placement / wh_decide are pure functions over values.  Sourcing this
# file defines them and runs nothing (the main entry point is guarded), so
# tests/headless/test_wslg_health.sh drives them with the values RECORDED from
# the real 2026-08-10 failure.  The test additionally runs THIS FILE end to end
# under a PATH shim of fake xdpyinfo/xwininfo/wish emitting those same recorded
# values, which is what ties the reported numbers to what X actually said.
#
# Tunables: WSLG_HEALTH_MIN_W (1024) MIN_H (768) PLACE_TOL (64) TIMEOUT (10)
#           PROBE_TIMEOUT (20) PROBE_SETTLE_MS (3000) PROBE_HOLD_MS (0)
#           PROBE_ATTEMPTS (3)
#           WANT_X (200) WANT_Y (200)
#           SENTINEL_MAG (30000) TREE_SETTLE (0.2) PROBE_TAG ($$)
#           SOCKET_DIR (/tmp/.X11-unix) STDERR_LOG (/mnt/wslg/stderr.log)
#           GATE_WAIT (300) GATE_POLL (1) + GUI_GATE_DIR for the control file

WH_MIN_W="${WSLG_HEALTH_MIN_W:-1024}"
WH_MIN_H="${WSLG_HEALTH_MIN_H:-768}"
WH_PLACE_TOL="${WSLG_HEALTH_PLACE_TOL:-64}"
WH_TIMEOUT="${WSLG_HEALTH_TIMEOUT:-10}"
WH_PROBE_TIMEOUT="${WSLG_HEALTH_PROBE_TIMEOUT:-20}"
WH_PROBE_SETTLE_MS="${WSLG_HEALTH_PROBE_SETTLE_MS:-3000}"
# TEST HOOK, 0 in normal use: keep the probe window mapped this many extra ms
# after it has reported, so an observer can catch it and prove a real top-level
# really was mapped on the real display (test check DH22b). It changes nothing
# the probe measures or says.
WH_PROBE_HOLD_MS="${WSLG_HEALTH_PROBE_HOLD_MS:-0}"
WH_PROBE_ATTEMPTS="${WSLG_HEALTH_PROBE_ATTEMPTS:-3}"
WH_WANT_X="${WSLG_HEALTH_WANT_X:-200}"
WH_WANT_Y="${WSLG_HEALTH_WANT_Y:-200}"
WH_SENTINEL_MAG="${WSLG_HEALTH_SENTINEL_MAG:-30000}"
WH_TREE_SETTLE="${WSLG_HEALTH_TREE_SETTLE:-0.2}"
WH_PROBE_TAG="${WSLG_HEALTH_PROBE_TAG:-$$}"
WH_STDERR_LOG="${WSLG_HEALTH_STDERR_LOG:-/mnt/wslg/stderr.log}"

# --- the GUI-test gate's control file (READ ONLY -- see CONTRACT above) ------
# Same default and same override as tests/headless/gui_gate.sh's GATE_DIR, but
# reached by reading the one file rather than by sourcing the gate: this probe
# is meant to be usable as a preflight from inside gate_start.
WH_GATE_DIR="${GUI_GATE_DIR:-$HOME/.claude/gui_test_gate}"
# The BOUND on a PAUSE hold, in seconds, and the poll interval. Bounded because
# a Pause the user pressed and then forgot must not hang a suite for the rest of
# the day: at the bound the probe reports DEFERRED (= "not measured"), which the
# caller can tell apart from both healthy and stub.
WH_GATE_WAIT="${WSLG_HEALTH_GATE_WAIT:-300}"
WH_GATE_POLL="${WSLG_HEALTH_GATE_POLL:-1}"
WH_GATE_DEADLINE=""   # set at the first PAUSE; SHARED by every consult, so the
                      # wait is bounded OVERALL and not once per consult
WH_GATE_WAITED=0      # seconds actually held, for the report
WH_GATE_WHERE=""      # which consult tripped, for the report

WH_QUIET=0
WH_DETAIL=""          # the detail block, printed under the verdict

# wh_say <line> — queue a detail line (printed after the verdict, so the verdict
# can be a single glanceable line at the top).
wh_say() { WH_DETAIL="${WH_DETAIL}$1"$'\n'; }
# wh_lab — fixed-width check name, so the detail block reads as a column
wh_lab() { printf '%-18s' "${1:-}"; }

wh_is_num() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
# signed integer (the sentinel coordinates are negative)
wh_is_int() {
  case "${1:-}" in
    ''|-) return 1 ;;
    -*) wh_is_num "${1#-}" ;;
    *) wh_is_num "$1" ;;
  esac
}
wh_abs() { local v="${1:-0}"; printf '%s' "${v#-}"; }

# wh_valid_display <name> — the X display grammar: [host]:N[.S] or unix/:N.
# A malformed VALUE is a usage error (64), never the "no display, carry on" 2:
# `wslg_health.sh 0` (colon forgotten) and `wslg_health.sh :O` (letter O) both
# used to be reported as "the legitimate headless case, not a fault".
wh_valid_display() {
  local d="${1:-}" rest num scr
  case "$d" in
    unix/:*) rest="${d#unix/:}" ;;
    :*)      rest="${d#:}" ;;
    *:*)     rest="${d#*:}" ;;
    *)       return 1 ;;
  esac
  num="${rest%%.*}"
  wh_is_num "$num" || return 1
  if [ "$rest" != "$num" ]; then
    scr="${rest#*.}"
    wh_is_num "$scr" || return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# THE GATE.  Check 5 paints on the user's screen, so it answers the panel.
# ---------------------------------------------------------------------------

# wh_gate_state — RUN | PAUSE | STOP, read from the panel's control file.
# FAILS OPEN in every ambiguous case (no gate dir, no file, a file that cannot
# be read, a file holding something else), exactly like the rest of the gate:
# a probe that refused to run because $HOME had no .claude in it would be a new
# way to block testing, and blocking testing is not this button's job.
# The panel writes the word with no trailing newline; other writers (the
# documented `echo STOP > control` escape hatch) add one, so whitespace goes.
wh_gate_state() {
  local f="$WH_GATE_DIR/control" v
  [ -f "$f" ] || { printf 'RUN'; return 0; }
  v="$(tr -d '[:space:]' < "$f" 2>/dev/null)" || v=""
  case "$v" in
    STOP)  printf 'STOP' ;;
    PAUSE) printf 'PAUSE' ;;
    *)     printf 'RUN' ;;
  esac
}

# wh_gate_wait <where> — obey the panel BEFORE anything is mapped.
#   rc 0  proceed
#   rc 4  STOP standing -> the caller must map nothing and exit 4
#   rc 5  still PAUSED at the bound -> map nothing, exit 5 (DEFERRED)
# Called once at the top (so a STOP costs nothing and touches no X) and then
# AGAIN BEFORE EVERY SINGLE PROBE ATTEMPT -- the only code here that maps a
# window, and it runs up to WSLG_HEALTH_PROBE_ATTEMPTS times. Those later
# consults are the ones that matter: a Pause pressed while xdpyinfo and xwininfo
# are running, or pressed the moment the first probe window appears, would
# otherwise still be followed by a window on the user's screen, which is
# precisely the complaint. WH_GATE_DEADLINE is shared across all of them, so the
# hold stays bounded OVERALL however many times it is consulted.
# GUI_GATE=0 DOES NOT EXEMPT THIS. That variable means "do not stop to ask
# permission"; PAUSE/STOP is a standing order from a user who is at the keyboard
# and has already pressed a button. See doc/claude/specs/wslg_health_probe.md.
wh_gate_wait() {
  local where="${1:-preflight}" st now t0
  st="$(wh_gate_state)"
  [ "$st" = "RUN" ] && return 0
  WH_GATE_WHERE="$where"
  [ "$st" = "STOP" ] && return 4
  # A TUNABLE TYPO MUST NOT LOOK LIKE A BROKEN DISPLAY. `$(( t0 + WH_GATE_WAIT ))`
  # with a non-integer bound aborts bash with an arithmetic syntax error, and the
  # script then dies while HOLDING: no VERDICT line at all and exit 1, which every
  # caller reads as "stub display, GUI results are meaningless" -- a hold reported
  # as a broken display, the exact confusion codes 4 and 5 exist to prevent.
  # WSLG_HEALTH_GATE_WAIT=2.5 is an easy thing for a caller to write, since the
  # POLL interval next to it documents fractions (this file's own test uses 0.2).
  # Truncate a fractional bound; fall back to the default for anything else; say
  # so on stderr either way, so a typo is visible rather than silently obeyed.
  local raw
  if ! wh_is_num "$WH_GATE_WAIT"; then
    raw="$WH_GATE_WAIT"
    WH_GATE_WAIT="${WH_GATE_WAIT%%.*}"
    wh_is_num "$WH_GATE_WAIT" || WH_GATE_WAIT=300
    echo "wslg_health: WSLG_HEALTH_GATE_WAIT='$raw' is not a whole number of seconds -- using ${WH_GATE_WAIT}s" >&2
  fi
  t0="$(date +%s)"
  [ -n "$WH_GATE_DEADLINE" ] || WH_GATE_DEADLINE=$(( t0 + WH_GATE_WAIT ))
  while [ "$st" = "PAUSE" ]; do
    now="$(date +%s)"
    if [ "$now" -ge "$WH_GATE_DEADLINE" ]; then
      WH_GATE_WAITED=$(( WH_GATE_WAITED + now - t0 ))
      return 5
    fi
    sleep "$WH_GATE_POLL" 2>/dev/null || sleep 1
    st="$(wh_gate_state)"
  done
  now="$(date +%s)"
  WH_GATE_WAITED=$(( WH_GATE_WAITED + now - t0 ))
  # Resume can also mean Stop: the user who was holding us may have given up.
  [ "$st" = "STOP" ] && return 4
  return 0
}

# wh_gate_report <rc> <display> — the verdict line for a gate hold, and the
# partial detail under it. NOT a health verdict: nothing was measured. The
# wording deliberately avoids "SKIP" in every form -- full_audit.sh scores a
# whole FILE on those substrings.
wh_gate_report() {
  local rc="$1" dpy="${2:-}" where="${WH_GATE_WHERE:-preflight}"
  if [ "$rc" = 4 ]; then
    echo "VERDICT: STOPPED  display=$dpy  the GUI-test control panel is set to STOP ($WH_GATE_DIR/control) -- nothing was mapped and this display was NOT measured (that is neither healthy nor stub)"
  else
    echo "VERDICT: DEFERRED  display=$dpy  the GUI-test control panel is PAUSED ($WH_GATE_DIR/control) and still paused after ${WH_GATE_WAITED}s (bound ${WH_GATE_WAIT}s) -- nothing was mapped and this display was NOT measured (that is neither healthy nor stub); press Resume and run it again"
  fi
  wh_say "  [--  ] $(wh_lab "window placement") NOT MEASURED -- the probe maps a real window and the panel says $( [ "$rc" = 4 ] && echo STOP || echo PAUSE ) (consulted at: $where)"
  [ "$WH_QUIET" = 1 ] || printf '%s' "$WH_DETAIL"
  return "$rc"
}

# ---------------------------------------------------------------------------
# THE JUDGEMENT.  Pure functions over values: no X, no I/O beyond wh_say.
# Return 0 = ok, 1 = STUB/unhealthy, 3 = cannot judge.
# ---------------------------------------------------------------------------

# wh_check_geometry <w> <h> <what>
# A FLOOR, deliberately, not an equality test against the 640x480 stub: the stub
# size is not a magic constant and this machine's real root alternates between
# 5120x1440 and 2560x1440 as monitors come and go.  Only "implausibly small for
# a desktop" is a fault.
wh_check_geometry() {
  local w="${1:--}" h="${2:--}" what; what="$(wh_lab "${3:-root geometry}")"
  if ! wh_is_num "$w" || ! wh_is_num "$h"; then
    wh_say "  [??  ] $what unreadable (got '${w}x${h}')"
    return 3
  fi
  if [ "$w" -lt "$WH_MIN_W" ] || [ "$h" -lt "$WH_MIN_H" ]; then
    wh_say "  [STUB] $what ${w}x${h} is below the ${WH_MIN_W}x${WH_MIN_H} floor -- this is a stub display"
    return 1
  fi
  wh_say "  [ok  ] $what ${w}x${h}  (floor ${WH_MIN_W}x${WH_MIN_H})"
  return 0
}

# wh_sentinel_ids <tree-text> — the ids of windows parked at the sentinel.
# MAGNITUDE, not the text '+-327': that prefix also matched an ordinary window
# at x=-327 or x=-3275, which is entirely normal on this 5120x1440 multi-monitor
# desktop (measured: `900x700+-327+140` was reported as a STUB).
wh_sentinel_ids() {
  printf '%s\n' "${1:-}" | awk -v mag="${WH_SENTINEL_MAG:-30000}" '
    {
      pos = $NF
      if (pos !~ /^\+/) next
      s = substr(pos, 2)
      i = index(s, "+")
      if (i == 0) next
      x = substr(s, 1, i - 1) + 0
      y = substr(s, i + 1) + 0
      if (x < 0) x = -x
      if (y < 0) y = -y
      if (x > mag || y > mag) print $1
    }'
}

# wh_check_sentinel <tree-sample-1> [<tree-sample-2>]
# Nothing may sit at the sentinel IN BOTH SAMPLES.  0310's signature:
#   0x201d48 (has no name): ()  544x547+-32768+-32768  +-32768+-32768
# TWO samples because one is not evidence: MEASURED on the healthy display, an
# ordinary window map passes through a transient WM frame at exactly
# +-32768+-32768, so a single snapshot condemns a good display whenever any
# other client happens to be opening a window.  A stub parks permanently; the
# transient frame is gone from the next sample.  With one argument the same
# sample is used twice (that is what the recorded-stub fixtures do -- on the real
# stub the window IS in every sample).
wh_check_sentinel() {
  local t1="${1:--}" t2="${2:-}" ids1 ids2 both hits first firstid seen
  [ -n "$t2" ] || t2="$t1"
  if [ "$t1" = "-" ] || [ "$t2" = "-" ]; then
    wh_say "  [??  ] $(wh_lab "parked windows") window tree unreadable"
    return 3
  fi
  ids1="$(wh_sentinel_ids "$t1" | sort -u)"
  ids2="$(wh_sentinel_ids "$t2" | sort -u)"
  both=""
  if [ -n "$ids1" ] && [ -n "$ids2" ]; then
    both="$(printf '%s\n' "$ids1" | grep -Fxf <(printf '%s\n' "$ids2") || true)"
  fi
  hits="$(printf '%s' "$both" | grep -c . || true)"
  if [ "${hits:-0}" -gt 0 ]; then
    firstid="$(printf '%s\n' "$both" | head -1)"
    first="$(printf '%s\n' "$t2" | grep -m1 -F "$firstid" | sed 's/^ *//')"
    wh_say "  [STUB] $(wh_lab "parked windows") $hits window(s) parked at the sentinel (|x| or |y| > ${WH_SENTINEL_MAG}) in BOTH samples, e.g.: $first"
    return 1
  fi
  seen="$(printf '%s\n%s\n' "$ids1" "$ids2" | grep -c . || true)"
  if [ "${seen:-0}" -gt 0 ]; then
    wh_say "  [ok  ] $(wh_lab "parked windows") none persistent (${seen} transient WM pre-placement frame(s) in one sample only -- normal while a window is mapping)"
  else
    wh_say "  [ok  ] $(wh_lab "parked windows") none (no window with |x| or |y| > ${WH_SENTINEL_MAG} in either sample of the window tree)"
  fi
  return 0
}

# wh_check_placement <want_x> <want_y> <got_x> <got_y>
# THE DECISIVE CHECK.  A window-manager decoration offset is CORRECT: the
# measured healthy result is want +200+200 -> got +206+227 (dx 6, dy 27), so this
# is a tolerance, never an equality test.  The stub parks at -32730/-32709, i.e.
# ~32900 px out, which no tolerance worth the name could swallow.

# wh_place_ok <want_x> <want_y> <got_x> <got_y> — the same judgement, SILENT.
# 0 within tolerance, 1 out, 3 unreadable.  wh_main uses it to decide whether to
# retry the probe; wh_check_placement is this plus the reporting.
wh_place_ok() {
  local wx="${1:--}" wy="${2:--}" gx="${3:--}" gy="${4:--}" dx dy
  if ! wh_is_int "$wx" || ! wh_is_int "$wy" || ! wh_is_int "$gx" || ! wh_is_int "$gy"; then
    return 3
  fi
  dx="$(wh_abs "$((gx - wx))")"; dy="$(wh_abs "$((gy - wy))")"
  if [ "$dx" -gt "$WH_PLACE_TOL" ] || [ "$dy" -gt "$WH_PLACE_TOL" ]; then
    return 1
  fi
  return 0
}

wh_check_placement() {
  local wx="${1:--}" wy="${2:--}" gx="${3:--}" gy="${4:--}" dx dy
  if ! wh_is_int "$wx" || ! wh_is_int "$wy" || ! wh_is_int "$gx" || ! wh_is_int "$gy"; then
    # 3, NOT 0. The decisive check having produced nothing is exactly the case
    # where "healthy" would be the silent downgrade this script exists to
    # prevent, so it downgrades the whole verdict to UNKNOWN (DH16, DH19e).
    wh_say "  [??  ] $(wh_lab "window placement") probe produced no coordinates -- cannot judge this display"
    return 3
  fi
  dx="$(wh_abs "$((gx - wx))")"; dy="$(wh_abs "$((gy - wy))")"
  if [ "$dx" -gt "$WH_PLACE_TOL" ] || [ "$dy" -gt "$WH_PLACE_TOL" ]; then
    wh_say "  [STUB] $(wh_lab "window placement") want +${wx}+${wy} got +${gx}+${gy} -- off by ${dx},${dy} px (tolerance ${WH_PLACE_TOL}); the WM is parking windows where nobody can see them"
    return 1
  fi
  wh_say "  [ok  ] $(wh_lab "window placement") want +${wx}+${wy} got +${gx}+${gy}  (offset ${dx},${dy} px, WM decoration, tolerance ${WH_PLACE_TOL})"
  return 0
}

# wh_decide <root_w> <root_h> <tree1> <want_x> <want_y> <got_x> <got_y> <scr_w> <scr_h> [<tree2>]
# Compose the three judgements (plus the probe's own view of the screen size,
# which is what read 640x480 on the broken server).  Any STUB anywhere wins;
# otherwise an unjudgeable check downgrades to UNKNOWN.  Sets WH_VERDICT.
wh_decide() {
  local rw="${1:--}" rh="${2:--}" tree="${3:--}" wx="${4:--}" wy="${5:--}" \
        gx="${6:--}" gy="${7:--}" sw="${8:--}" sh="${9:--}" tree2="${10:-}"
  local stub=0 unknown=0 rc

  wh_check_geometry "$rw" "$rh" "root geometry"; rc=$?
  [ "$rc" = 1 ] && stub=1; [ "$rc" = 3 ] && unknown=1

  wh_check_sentinel "$tree" "$tree2"; rc=$?
  [ "$rc" = 1 ] && stub=1; [ "$rc" = 3 ] && unknown=1

  wh_check_placement "$wx" "$wy" "$gx" "$gy"; rc=$?
  [ "$rc" = 1 ] && stub=1; [ "$rc" = 3 ] && unknown=1

  # The probe's own screen size: a second, independent witness of the stub, taken
  # from inside a real Tk client rather than from xwininfo.
  if [ "$sw" != "-" ] || [ "$sh" != "-" ]; then
    wh_check_geometry "$sw" "$sh" "probe screen size"; rc=$?
    [ "$rc" = 1 ] && stub=1; [ "$rc" = 3 ] && unknown=1
  fi

  if [ "$stub" = 1 ]; then WH_VERDICT=UNHEALTHY; return 1; fi
  if [ "$unknown" = 1 ]; then WH_VERDICT=UNKNOWN; return 3; fi
  WH_VERDICT=HEALTHY; return 0
}

# ---------------------------------------------------------------------------
# THE MEASURING.  Everything below talks to X, and everything is under timeout.
# ---------------------------------------------------------------------------

# wh_dpy_socket <display> — the /tmp/.X11-unix path for a local display, or "".
# ONLY `:N` and `unix/:N` are socket-backed.  `localhost:N` and `127.0.0.1:N` are
# TCP displays on port 6000+N and have no socket here: mapping them onto
# /tmp/.X11-unix/XN attributed an unrelated local server's socket to a TCP
# display and produced a confident false verdict in BOTH directions -- MEASURED
# on this healthy machine: `wslg_health.sh localhost:0` said "the X server is
# wedged" (exit 1) after 10 s, and `localhost:9` against a live TCP listener on
# 6009 said "no X server there" (exit 2) in 6 ms without ever contacting it.
# A hosted display simply has no local socket to inspect, which is a real
# difference and the caller treats it as one (UNKNOWN, not a fault, not a stub).
# WSLG_HEALTH_SOCKET_DIR retargets the directory so the test can present a
# server-that-does-not-answer without going anywhere near the real /tmp/.X11-unix
# (this script must be safe to run while suites are in flight; its TEST must be
# equally safe to run while a real display is in use).
wh_dpy_socket() {
  local d="${1:-}" n
  case "$d" in
    :*)       n="${d#:}" ;;
    unix/:*)  n="${d#unix/:}" ;;
    *) return 1 ;;
  esac
  n="${n%%.*}"
  wh_is_num "$n" || return 1
  printf '%s/X%s' "${WSLG_HEALTH_SOCKET_DIR:-/tmp/.X11-unix}" "$n"
}

# wh_probe <display> — map a REAL Tk window and report where it landed.
# Prints: "PROBE want +X+Y got +X+Y screen WxH", or nothing on failure.
# rc 0 ok, 124 timed out (a wedged server), other = wish failed.
# The window is titled "wslg_health probe <tag>" with a per-process tag, so the
# leak check can name OUR window and not any other copy's (two agents share this
# display and the test must be safe to run while suites are in flight).
wh_probe() {
  local dpy="$1" tcl out rc
  command -v wish >/dev/null 2>&1 || return 127
  tcl="$(mktemp "${TMPDIR:-/tmp}/wslg_probe.XXXXXX.tcl")" || return 126
  cat > "$tcl" <<'PROBE_TCL'
# Map one small top-level where the caller asks, wait for the WM to actually
# PLACE it, then report the ACTUAL root coordinates. Deliberately short-lived.
set wx     [lindex $argv 0]
set wy     [lindex $argv 1]
set tag    [lindex $argv 2]
set mag    [lindex $argv 3]
set settle [lindex $argv 4]
set hold   [lindex $argv 5]
wm title . "wslg_health probe $tag"
wm geometry . 160x60+$wx+$wy
update idletasks
catch {tkwait visibility .}
# THE READ MUST SETTLE. Measured on the HEALTHY 5120x1440 display: winfo rootx
# right after `tkwait visibility` is -32730/-32709 -- byte-identical to the
# RECORDED STUB VALUE -- and becomes 206/227 only once a ConfigureNotify has
# been processed, ~26 ms later, and only under `update` (`update idletasks`
# never processes it: sampled at +0/10/25/50/100/150/200/250/400 ms with
# idletasks only, it read -32730 at every one of them). A fixed `after N`
# therefore reports a HEALTHY display as a stub whenever the WM is slower than
# N. Poll for two consecutive agreeing samples outside the sentinel region, or
# the deadline -- on a real stub the deadline is what reports, and it reports
# the parked coordinates, which is the wanted answer.
set prev ""
set stable 0
set deadline [expr {[clock milliseconds] + $settle}]
while {1} {
    catch {update}
    set cur [list [winfo rootx .] [winfo rooty .]]
    if {$cur eq $prev} {incr stable} else {set stable 1}
    set prev $cur
    if {$stable >= 2 && abs([lindex $cur 0]) < $mag && abs([lindex $cur 1]) < $mag} break
    if {[clock milliseconds] >= $deadline} break
    after 20 {set ::__wh_tick 1}
    vwait ::__wh_tick
}
puts "PROBE want +$wx+$wy got +[lindex $prev 0]+[lindex $prev 1] screen [winfo screenwidth .]x[winfo screenheight .]"
flush stdout
if {$hold > 0} {
    after $hold {exit 0}
    vwait __wh_never
}
exit 0
PROBE_TCL
  out="$(DISPLAY="$dpy" timeout "$WH_PROBE_TIMEOUT" wish "$tcl" \
           "$WH_WANT_X" "$WH_WANT_Y" "$WH_PROBE_TAG" "$WH_SENTINEL_MAG" \
           "$WH_PROBE_SETTLE_MS" "$WH_PROBE_HOLD_MS" 2>/dev/null)"
  rc=$?
  rm -f "$tcl"
  printf '%s' "$out"
  return "$rc"
}

wh_usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  echo "exit: 0 healthy | 1 stub/unhealthy | 2 no display (NOT a fault) | 3 unknown"
  echo "      4 stopped by the GUI-test panel | 5 deferred (panel paused) -- both mean NOT MEASURED"
  echo "      64 usage"
}

wh_main() {
  local dpy="" arg npos=0
  for arg in "$@"; do
    case "$arg" in
      -q|--quiet) WH_QUIET=1 ;;
      -h|--help)  wh_usage; return 0 ;;
      # 64 (EX_USAGE), NEVER 2: 2 means "no display, and that is fine", and a
      # caller that acted on a typo as if the box were headless would be a
      # silent, wrong all-clear -- the class of bug this script exists to kill.
      -*)         echo "wslg_health: unknown option $arg" >&2; return 64 ;;
      *)
        npos=$((npos + 1))
        if [ "$npos" -gt 1 ]; then
          echo "wslg_health: at most one display may be given (got '$dpy' and '$arg')" >&2
          return 64
        fi
        # A malformed display VALUE is the same usage error as a malformed
        # option, for the same reason: `wslg_health.sh 0` and `wslg_health.sh :O`
        # used to report "the legitimate headless case, not a fault".
        if ! wh_valid_display "$arg"; then
          echo "wslg_health: '$arg' is not an X display name (want [host]:N[.S] or unix/:N)" >&2
          return 64
        fi
        dpy="$arg"
        ;;
    esac
  done
  [ -n "$dpy" ] || dpy="${DISPLAY:-}"

  # --- the legitimate headless case: no display at all -----------------------
  if [ -z "$dpy" ]; then
    echo "VERDICT: NODISPLAY  \$DISPLAY is unset -- nothing to probe (this is the legitimate headless case, not a fault)"
    return 2
  fi
  if ! command -v xdpyinfo >/dev/null 2>&1 || ! command -v xwininfo >/dev/null 2>&1; then
    echo "VERDICT: UNKNOWN  display=$dpy  xdpyinfo/xwininfo not installed -- cannot judge this display"
    return 3
  fi

  # --- 1a. is there a server there AT ALL? ----------------------------------
  #
  # THE SOCKET IS LOOKED AT FIRST -- ahead of even the panel. A display number
  # with no server behind it is the legitimate headless case: there is nothing
  # there to map and nothing for the user to see, so holding on a PAUSE (or
  # announcing STOPPED) about a display that does not exist would be an INVENTED
  # HOLD -- a hold with no screen behind it. Measured before this order was
  # fixed: `wslg_health.sh :9` on an unused display number sat on a forgotten
  # PAUSE for the full 300 s bound and then reported DEFERRED instead of
  # NODISPLAY, which also turned two of this file's own socket checks red.
  #
  # The socket is also what tells "there is no server here" apart from "the
  # server is wedged". Both look identical from a timeout: against a display
  # with NO listener at all, Xlib silently falls back to TCP and retries SYNs
  # for minutes (measured 269 s while building the gate's v6 revive), so
  # `timeout xdpyinfo :77` on an unused display number expires exactly like a
  # hung server would. Calling an unused display number STUB would be the worst
  # kind of false alarm this script can raise.
  local sock t0 t1 rc grc
  sock="$(wh_dpy_socket "$dpy" || true)"
  if [ -n "$sock" ] && [ ! -e "$sock" ]; then
    echo "VERDICT: NODISPLAY  display=$dpy  no X server there ($sock does not exist) -- the legitimate headless case, not a fault"
    return 2
  fi

  # --- 0. THE PANEL, before any X CALL --------------------------------------
  # A STOP costs nothing this way: no connection, no query, no window. (The
  # NODISPLAY exits above come first on purpose, see 1a.)
  wh_gate_wait "before any X call"; grc=$?
  if [ "$grc" != 0 ]; then wh_gate_report "$grc" "$dpy"; return "$grc"; fi

  # --- 1b. does the server answer at all? -----------------------------------
  t0="$(date +%s)"
  DISPLAY="$dpy" timeout "$WH_TIMEOUT" xdpyinfo >/dev/null 2>&1; rc=$?
  t1="$(date +%s)"
  if [ "$rc" = 124 ]; then
    if [ -n "$sock" ]; then
      # the socket EXISTS and the server behind it never answered: WEDGED. Not
      # the headless case -- anything run against it hangs, so it is a fault.
      echo "VERDICT: UNHEALTHY  display=$dpy  $sock exists but xdpyinfo did not answer within ${WH_TIMEOUT}s -- the X server is wedged"
      return 1
    fi
    # a hosted/TCP display has no socket to inspect, so absent and wedged are
    # genuinely indistinguishable from here. Say so rather than guess.
    echo "VERDICT: UNKNOWN  display=$dpy  xdpyinfo did not answer within ${WH_TIMEOUT}s and there is no local socket to tell 'absent' from 'wedged'"
    return 3
  fi
  if [ "$rc" != 0 ]; then
    echo "VERDICT: NODISPLAY  display=$dpy  no X server there (xdpyinfo rc=$rc) -- the legitimate headless case, not a fault"
    return 2
  fi
  wh_say "  [ok  ] $(wh_lab "server answers") xdpyinfo $dpy replied in $((t1 - t0))s"

  # --- 2/3. root geometry and the sentinel ----------------------------------
  local rootinfo rw rh tree tree2
  rootinfo="$(DISPLAY="$dpy" timeout "$WH_TIMEOUT" xwininfo -root 2>/dev/null)"
  rw="$(printf '%s\n' "$rootinfo" | awk '/^ *Width:/ {print $2; exit}')"
  rh="$(printf '%s\n' "$rootinfo" | awk '/^ *Height:/ {print $2; exit}')"
  [ -n "$rw" ] || rw="-"; [ -n "$rh" ] || rh="-"

  # SAMPLE 1 of the window tree, taken BEFORE the probe. Sample 2 comes after
  # it, so the gap is real work rather than an invented sleep, and our own
  # probe window (which is destroyed before sample 2) is in neither.
  tree="$(DISPLAY="$dpy" timeout "$WH_TIMEOUT" xwininfo -root -tree 2>/dev/null)"
  [ -n "$tree" ] || tree="-"

  # --- 5. the functional probe ----------------------------------------------
  #
  # BEST OF N ATTEMPTS, not one. MEASURED on this healthy display: the WM
  # occasionally ignores the requested position outright and maps the window at
  # the origin instead -- `want +437+311 got +6+27` (the 6,27 is the same
  # decoration offset, applied to 0,0). Seen 1 in 15 and again during a sabotage
  # run, then 0 in 45 and 0 in 30: rare, bursty, and entirely a WM hiccup on a
  # display that is fine. One attempt therefore gives a false UNHEALTHY at a few
  # per cent -- the same class of false alarm as the transient window-tree frame,
  # and just as fatal to a probe whose whole job is to be believed. A STUB fails
  # EVERY attempt (it has no code path that places a window correctly), so
  # retrying costs a stub nothing but the time and costs a healthy machine the
  # false alarm.
  local probe prc wx wy gx gy sw sh attempt=0
  wx="-"; wy="-"; gx="-"; gy="-"; sw="-"; sh="-"

  while : ; do
    # THE LOAD-BEARING CONSULT, and it is INSIDE the loop on purpose: the very
    # next statement maps a top-level on the user's screen, and this loop maps
    # up to WSLG_HEALTH_PROBE_ATTEMPTS of them. Consulting once before the loop
    # gated only the FIRST window: measured, with the button pressed the instant
    # probe window 1 appeared, the probe went on to map two more and then
    # reported a health verdict (exit 1) instead of STOPPED/DEFERRED -- and it
    # does that HARDEST on the display this script exists to detect, because a
    # stub misplaces every attempt and so always takes all three. A Pause
    # pressed while xdpyinfo/xwininfo ran, or between two attempts, must be
    # obeyed HERE, or the user presses the button and a window appears anyway,
    # which is the whole reason this pass exists. The wait budget
    # (WH_GATE_DEADLINE) is shared with the first consult, so repeated consults
    # cannot multiply the bound.
    wh_gate_wait "immediately before the Tk probe"; grc=$?
    if [ "$grc" != 0 ]; then wh_gate_report "$grc" "$dpy"; return "$grc"; fi

    attempt=$((attempt + 1))
    probe="$(wh_probe "$dpy")"; prc=$?
    if [ "$prc" = 124 ]; then
      wh_say "  [STUB] $(wh_lab "window placement") the Tk probe never returned within ${WH_PROBE_TIMEOUT}s"
      echo "VERDICT: UNHEALTHY  display=$dpy  root=${rw}x${rh}  the Tk placement probe HUNG -- GUI results from this display are meaningless"
      [ "$WH_QUIET" = 1 ] || printf '%s' "$WH_DETAIL"
      return 1
    fi
    case "$probe" in
      PROBE*)
        # PROBE want +200+200 got +206+227 screen 5120x1440
        set -- $probe
        wx="${3#+}"; wx="${wx%%+*}"; wy="${3##*+}"
        gx="${5#+}"; gx="${gx%%+*}"; gy="${5##*+}"
        sw="${7%%x*}"; sh="${7##*x}"
        # "+-32730+-32709" splits as x="-32730" y="-32709" only if we cut on the
        # LAST '+' -- which "${3##*+}" does. Guard anyway.
        wh_is_int "$wx" || wx="-"; wh_is_int "$wy" || wy="-"
        wh_is_int "$gx" || gx="-"; wh_is_int "$gy" || gy="-"
        ;;
      *)
        wh_say "  [??  ] $(wh_lab "window placement") probe did not run (wish rc=$prc)"
        break
        ;;
    esac
    wh_place_ok "$wx" "$wy" "$gx" "$gy" && break
    [ "$attempt" -ge "$WH_PROBE_ATTEMPTS" ] && break
  done
  if [ "$attempt" -gt 1 ]; then
    wh_say "  [info] $(wh_lab "placement attempts") $attempt of ${WH_PROBE_ATTEMPTS} (the WM occasionally ignores the requested position on a display that is otherwise fine; a stub fails every attempt)"
  fi

  # SAMPLE 2. A transient WM pre-placement frame is gone by now; a real stub's
  # parked windows are still exactly where they were.
  sleep "$WH_TREE_SETTLE" 2>/dev/null || true
  tree2="$(DISPLAY="$dpy" timeout "$WH_TIMEOUT" xwininfo -root -tree 2>/dev/null)"
  [ -n "$tree2" ] || tree2="-"

  # --- the verdict ----------------------------------------------------------
  wh_decide "$rw" "$rh" "$tree" "$wx" "$wy" "$gx" "$gy" "$sw" "$sh" "$tree2"; rc=$?

  # --- 4 + the stderr log: INFORMATION, never a gate ------------------------
  local age when nfatal
  if [ -n "$sock" ] && [ -e "$sock" ]; then
    when="$(stat -c %y "$sock" 2>/dev/null | cut -d. -f1)"
    age=$(( $(date +%s) - $(stat -c %Y "$sock" 2>/dev/null || echo 0) ))
    wh_say "  [info] $(wh_lab "server started") $when  (${age}s ago, from $sock -- the socket is recreated on every respawn)"
    if [ "$age" -lt 120 ]; then
      wh_say "  [info] ...that is RECENT: not a fault, but it explains vanished windows, dead panels and any suite that ran across it"
    fi
  else
    wh_say "  [info] $(wh_lab "server started") unknown (no local socket for $dpy)"
  fi
  if [ -r "$WH_STDERR_LOG" ]; then
    # `grep -c` prints 0 AND exits 1 when there are no matches, so a `|| echo 0`
    # fallback appends a SECOND 0 and splits this line in two -- and it did so
    # exactly on a clean boot, the case a human most wants to read.
    nfatal="$(grep -c 'Fatal server error' "$WH_STDERR_LOG" 2>/dev/null)"
    [ -n "$nfatal" ] || nfatal=0
    wh_say "  [info] $(wh_lab "Fatal server error") $nfatal so far in $WH_STDERR_LOG (a rising count predicts more panel deaths; it does not make the results in hand wrong)"
  fi

  local head
  case "$rc" in
    0) head="VERDICT: HEALTHY  display=$dpy  root=${rw}x${rh}  no parked windows  probe want +${wx}+${wy} got +${gx}+${gy} screen ${sw}x${sh}" ;;
    1) head="VERDICT: UNHEALTHY  display=$dpy  root=${rw}x${rh}  probe want +${wx}+${wy} got +${gx}+${gy} screen ${sw}x${sh}  -- STUB DISPLAY: GUI results taken here measure a different machine (fix: wsl --shutdown, then re-run)" ;;
    *) head="VERDICT: UNKNOWN  display=$dpy  root=${rw}x${rh}  -- could not judge this display (see below)" ;;
  esac
  echo "$head"
  [ "$WH_QUIET" = 1 ] || printf '%s' "$WH_DETAIL"
  return "$rc"
}

# Guarded so that `source`ing this file defines the judgement functions and runs
# NOTHING -- that is how test_wslg_health.sh drives wh_decide with the values
# recorded from the real 2026-08-10 stub without needing a stub to exist.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  wh_main "$@"
  exit $?
fi
