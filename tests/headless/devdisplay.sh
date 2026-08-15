#!/bin/bash
# devdisplay.sh — a persistent, private, window-managed X display for GUI testing.
#
# WHY THIS EXISTS
#
# xvfb_arm.sh (8423240a) stopped full_audit.sh and run_suites.sh from borrowing
# the developer's screen. It fixed the two entry points that call it and nothing
# else. The leak it CANNOT fix is the most common one of all:
#
#     ./src/xschem --pipe -q --script tests/headless/<t>.tcl
#
# 319 headless tests plus ~25 under tests/ are run exactly like that, by hand,
# dozens of times a session. There is no wrapper around a binary name a human
# types, so no amount of arming scripts reaches it. Any fix that depends on
# remembering to type something different has already failed once -- that is
# precisely how gated_xschem.sh came to exist, and precisely why it does not
# help here.
#
# So the fix is environmental: bring up ONE long-lived invisible display, point
# the development shell at it, and let every invocation -- careless, scripted or
# hand-typed -- land there instead of on the monitor.
#
#     tests/headless/devdisplay.sh start
#
# WHO POINTS A SHELL AT IT: not the human. A person launching xschem is
# launching it to USE it, and the suites arm themselves. L1 is typed by the
# assistant, so the cover is the assistant's environment -- launch the session
# as `DISPLAY=:99 claude` (tool shells inherit it) or use `devdisplay.sh exec`.
# ~/.bashrc cannot do it here: it returns at its lines 6-9 for non-interactive
# shells, and the Bash tool's shell is non-interactive -- it inherits its
# environment rather than sourcing that file. `shellinit` below is for the
# narrow case of a terminal used ONLY for running tests by hand.
#
# :0 then becomes the thing you opt INTO (AUDIT_DISPLAY=:0), which is the right
# way round: the only remaining reason to need it is reproducing WSLg-specific
# defects, and those are rare and deliberate.
#
# THREE SIDE WINS, all measured before this file existed:
#   - immune to WSLg's Xwayland aborts, which kill that server ~3x/session and
#     take every client with it. A private Xvfb does not die when WSLg does.
#   - no ~1 s xvfb-run spawn per invocation; the display is already up.
#   - determinism: 30/30 soak with identical check counts where the same suites
#     on :0 flake 4-in-10 / 2-in-3 / 1-in-5, and test_wave_modes runs in 2.3 s
#     against 6.2-45.6 s.
#
# WHAT IT DELIBERATELY DOES NOT DO: reproduce WSLg-only bugs. WSLg emits 3
# <Configure> events per `wm geometry` where every other display emits 1, and
# that is an Xwayland property, not a window-manager one -- openbox does not
# supply it. Calculator landmine D6 stays a :0-only reproduction, and the
# durable answer stays forcing the hazard in the test (test_calc_skeleton S12)
# rather than shopping for an environment that happens to provide it.
#
# Spec: doc/claude/specs/dev_display.md
#
# USAGE
#   devdisplay.sh start            bring it up (idempotent)
#   devdisplay.sh stop             take it down
#   devdisplay.sh restart
#   devdisplay.sh status           alive? which display, pids, screen, wm, clients
#   devdisplay.sh view [--stop]    x11vnc on localhost, to look at it on demand
#   devdisplay.sh exec CMD...      run one command on it without exporting
#
#   DEVDISPLAY_NUM         display number, default 99
#   DEVDISPLAY_SCREEN      default 1920x1080x24   (NEVER 1600x1200, see below)
#   DEVDISPLAY_WM          default openbox; `none` for a bare server
#   XSCHEM_DEVDISPLAY_DIR  state dir, default $HOME/.claude/xschem_dev_display

set -u

STATE_DIR="${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}"
NUM="${DEVDISPLAY_NUM:-99}"
# PINNED, never left to chance: test_fluid_bodyshove_guards_0132 passes at
# 1280x1024 / 1600x900 / 1920x1080 / 2560x1440 / 5120x1440 and fails only at
# 1600x1200. A run whose geometry is not recorded cannot be compared with
# another run, so the size is stored in the state dir alongside the pids.
SCREEN="${DEVDISPLAY_SCREEN:-1920x1080x24}"
WM="${DEVDISPLAY_WM:-openbox}"
DPY=":$NUM"

_say()  { echo "devdisplay: $*" >&2; }
# $1 only, never $* -- _die takes an exit code as $2, and printing $* appends it
# to the message ("...within 10s 5").
# LOUD, and deliberately NOT prefixed like the routine banners. The first
# version of xvfb_arm.sh's give-up warning was prefixed exactly like its normal
# lines and was therefore swallowed by every `grep -v` used to read those runs,
# which is how a wait loop that never waited went unnoticed for two commits.
# A warning you routinely filter is not a warning.
_warn() { echo "!! devdisplay WARNING: $*" >&2; }
_die()  { echo "!! devdisplay ERROR: $1" >&2; exit "${2:-1}"; }

_f() { echo "$STATE_DIR/$1"; }

# --- identity, not mere liveness -------------------------------------------
# `kill -0` trusts a pid file that outlives both the process and the boot. pids
# recycle -- the counter restarts at every WSL boot while the state dir
# persists -- so a stale xvfb.pid can name some unrelated live process and make
# a dead display report healthy. Every liveness test below therefore also
# confirms WHAT the pid is.
_pid_of() {
  local f; f=$(_f "$1")
  [ -r "$f" ] || return 1
  local p; p=$(cat "$f" 2>/dev/null)
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  echo "$p"
}

_cmdline() { tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null; }

# Is <pid> alive AND running <program>? For the X server we also require the
# display number to appear as its own argv word, so :99 never matches :990.
_pid_is() {
  local p="$1" prog="$2" want_dpy="${3:-}"
  kill -0 "$p" 2>/dev/null || return 1
  local c; c=$(_cmdline "$p") || return 1
  case " $c " in *" $prog "*|*"/$prog "*) ;; *) return 1 ;; esac
  if [ -n "$want_dpy" ]; then
    case " $c " in *" $want_dpy "*) ;; *) return 1 ;; esac
  fi
  return 0
}

# Is anything LISTENING for this display? Two forms, and on this platform only
# the second one ever exists:
#
#   /tmp/.X11-unix/XN     the filesystem socket -- what every tutorial polls
#   @/tmp/.X11-unix/XN    the Linux abstract-namespace socket
#
# WSLg mounts /tmp/.X11-unix mode 777 WITHOUT the sticky bit, and an X server
# refuses to create a socket file in such a directory:
#     _XSERVTransmkdir: Mode of /tmp/.X11-unix should be set to 1777
#     _XSERVTransSocketCreateListener: failed to bind listener
# It carries on and binds the abstract socket, so the display is perfectly
# usable and `xdpyinfo -display :97` returns 0 -- while the socket FILE never
# appears. A `[ -S ... ]` readiness gate therefore reports "server never came
# up" for a server that is up and serving. Measured here on the first run.
_x_socket_listening() {
  [ -S "/tmp/.X11-unix/X$NUM" ] && return 0
  command -v ss >/dev/null 2>&1 || return 1
  ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$NUM\b"
}

# Does an X server answer on this display at all? (Says nothing about whose.)
#
# The listen test comes FIRST and is not decoration. `xdpyinfo -display :97`
# against a display with no server does not fail fast: the client library falls
# back to TCP localhost:6097, which under WSL is neither refused nor answered,
# so the call HANGS -- it ate a 2-minute command timeout on the first cold
# `status` this file ever ran. Nothing listening, no probe. The surviving probe
# is bounded too, in case a server exists but is wedged.
_server_answers() {
  _x_socket_listening || return 1
  command -v xdpyinfo >/dev/null 2>&1 || return 0
  timeout 5 xdpyinfo -display "$DPY" >/dev/null 2>&1
}

# Is the live server on $DPY the one WE started? Distinguishing this from
# "something answers" is what stops us adopting, killing or overwriting another
# user's or another tool's :99.
_ours() {
  local p; p=$(_pid_of xvfb.pid) || return 1
  _pid_is "$p" Xvfb "$DPY" || return 1
  _server_answers
}

_wm_alive() {
  local p; p=$(_pid_of wm.pid) || return 1
  [ "$WM" = none ] && return 1
  _pid_is "$p" "$WM"
}

_vnc_alive() {
  local p; p=$(_pid_of vnc.pid) || return 1
  _pid_is "$p" x11vnc
}

# A compliant WM sets _NET_SUPPORTING_WM_CHECK on the root window once it is
# live. Match the SUCCESS form `... window id # 0x...`, never the bare word
# "window": xprop's failure output is "no such atom on any window." -- which
# contains "window", so a `grep -q window` readiness check succeeds on the first
# iteration forever and the wait never waits. That exact bug shipped in
# xvfb_arm.sh and survived review because openbox happened to win the race
# anyway. Match success text, never a word that also appears in the error.
_wm_claimed() {
  command -v xprop >/dev/null 2>&1 || return 0   # cannot check -> do not block
  xprop -display "$DPY" -root _NET_SUPPORTING_WM_CHECK 2>/dev/null |
    grep -q 'window id #'
}

_kill_pidfile() {
  local f; f=$(_f "$1"); local p
  p=$(_pid_of "$1") || { rm -f "$f"; return 0; }
  kill -TERM "$p" 2>/dev/null
  local i=0
  while [ "$i" -lt 30 ] && kill -0 "$p" 2>/dev/null; do sleep 0.1; i=$((i+1)); done
  kill -0 "$p" 2>/dev/null && kill -KILL "$p" 2>/dev/null
  rm -f "$f"
}

_clean_state() { rm -f "$(_f xvfb.pid)" "$(_f wm.pid)" "$(_f vnc.pid)" \
                       "$(_f display)" "$(_f screen)" "$(_f wm)" "$(_f vnc.log)"; }

# ---------------------------------------------------------------------------
cmd_start() {
  if _ours; then
    _say "already running on $DPY (screen $(cat "$(_f screen)" 2>/dev/null || echo '?'), wm $(cat "$(_f wm)" 2>/dev/null || echo '?'))"
    _say "  export DISPLAY=$DPY"
    return 0
  fi

  # Something answers on $DPY that is not ours. Do not race it, do not kill it.
  if _server_answers; then
    _die "$DPY is already served by an X server that is not ours.
       Pick another with DEVDISPLAY_NUM=<n>, or stop that server yourself." 4
  fi

  # A lock with no server behind it. Xvfb refuses to start over one, and this is
  # the documented cause of the black-frame captures earlier in this batch.
  if [ -e "/tmp/.X$NUM-lock" ]; then
    if rm -f "/tmp/.X$NUM-lock" 2>/dev/null; then
      _say "cleaned stale /tmp/.X$NUM-lock"
    else
      _die "/tmp/.X$NUM-lock exists and is not removable (owned by another user?).
       Pick another display with DEVDISPLAY_NUM=<n>." 4
    fi
  fi
  rm -f "/tmp/.X11-unix/X$NUM" 2>/dev/null

  command -v Xvfb >/dev/null 2>&1 || _die "Xvfb not found. Install the 'xvfb' package." 3

  mkdir -p "$STATE_DIR" || _die "cannot create state dir $STATE_DIR" 3
  _clean_state

  Xvfb "$DPY" -screen 0 "$SCREEN" -nolisten tcp >/dev/null 2>&1 &
  local xpid=$!
  echo "$xpid" > "$(_f xvfb.pid)"

  local i=0
  while [ "$i" -lt 100 ]; do
    _server_answers && break
    kill -0 "$xpid" 2>/dev/null || { _clean_state; _die "Xvfb died at startup on $DPY" 5; }
    i=$((i+1)); sleep 0.1
  done
  if ! _server_answers; then
    _kill_pidfile xvfb.pid; _clean_state
    _die "Xvfb did not accept connections on $DPY within 10s" 5
  fi

  local wmname="none"
  if [ "$WM" != none ]; then
    if ! command -v "$WM" >/dev/null 2>&1; then
      _warn "window manager '$WM' not found -- running WM-LESS.
       Install it, or set DEVDISPLAY_WM=none to silence this."
    else
      DISPLAY="$DPY" "$WM" >/dev/null 2>&1 &
      local wpid=$!
      echo "$wpid" > "$(_f wm.pid)"
      wmname="$WM"
      # A toplevel mapped before the WM owns the screen is NEVER reparented --
      # it behaves exactly like the WM-less case the WM was added to fix, but
      # only sometimes, which is worse than not having one at all.
      i=0
      while [ "$i" -lt 100 ]; do
        _wm_claimed && break
        kill -0 "$wpid" 2>/dev/null || { _warn "$WM died at startup -- continuing WM-LESS"; wmname="none"; rm -f "$(_f wm.pid)"; break; }
        i=$((i+1)); sleep 0.05
      done
      if [ "$wmname" != none ] && ! _wm_claimed; then
        _warn "$WM did not claim $DPY in 5s -- continuing WM-LESS"
      fi
    fi
  fi

  echo "$DPY"    > "$(_f display)"
  echo "$SCREEN" > "$(_f screen)"
  echo "$wmname" > "$(_f wm)"

  _say "up on $DPY  (screen $SCREEN, wm $wmname, pid $xpid)"
  _say "  export DISPLAY=$DPY          # then every xschem run lands here"
  _say "  $0 view                      # to watch it"
  return 0
}

cmd_stop() {
  if [ ! -d "$STATE_DIR" ]; then _say "not running (no state)"; return 0; fi
  if ! _ours && ! _pid_of xvfb.pid >/dev/null 2>&1; then
    _clean_state; _say "not running (state cleaned)"; return 0
  fi
  _kill_pidfile vnc.pid
  _kill_pidfile wm.pid
  _kill_pidfile xvfb.pid
  rm -f "/tmp/.X$NUM-lock" "/tmp/.X11-unix/X$NUM" 2>/dev/null
  _clean_state
  _say "stopped $DPY"
  return 0
}

cmd_status() {
  local state
  if _ours; then state=alive
  elif _server_answers; then state=foreign
  elif _pid_of xvfb.pid >/dev/null 2>&1; then state=stale
  else state=dead
  fi

  local wmid="-"
  if [ "$state" = alive ] && command -v xprop >/dev/null 2>&1; then
    local id
    id=$(xprop -display "$DPY" -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -o '0x[0-9a-f]*' | head -1)
    if [ -n "$id" ]; then
      wmid=$(xprop -display "$DPY" -id "$id" _NET_WM_NAME 2>/dev/null | sed 's/.*= *//; s/"//g')
      [ -n "$wmid" ] || wmid="?"
    fi
  fi

  local clients="n/a"
  if [ "$state" = alive ] && command -v xlsclients >/dev/null 2>&1; then
    clients=$(xlsclients -display "$DPY" 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo "display: $DPY"
  echo "state:   $state"
  echo "screen:  $(cat "$(_f screen)" 2>/dev/null || echo "$SCREEN (not started)")"
  echo "wm:      $(cat "$(_f wm)" 2>/dev/null || echo "$WM (not started)") ($wmid)"
  echo "xvfb:    $(_pid_of xvfb.pid 2>/dev/null || echo '-')"
  echo "vnc:     $(_vnc_alive && _pid_of vnc.pid || echo '-')"
  echo "clients: $clients"
  echo "state dir: $STATE_DIR"
  [ "$state" = alive ]
}

cmd_view() {
  if [ "${1:-}" = "--stop" ]; then
    _kill_pidfile vnc.pid; _say "viewer stopped ($DPY still running)"; return 0
  fi
  _ours || _die "$DPY is not running. Start it first: $0 start" 6
  if _vnc_alive; then
    _say "viewer already running: $(grep -m1 '^PORT=' "$(_f vnc.log)" 2>/dev/null || echo 'port unknown')"
    return 0
  fi
  command -v x11vnc >/dev/null 2>&1 || \
    _die "x11vnc not found. Install it:  sudo apt install x11vnc" 3

  # localhost ONLY. This puts a live view of a development display on a socket;
  # it must never be reachable off this machine.
  x11vnc -display "$DPY" -localhost -nopw -forever -shared -quiet \
         > "$(_f vnc.log)" 2>&1 &
  echo $! > "$(_f vnc.pid)"
  local i=0 port=""
  while [ "$i" -lt 60 ]; do
    port=$(grep -m1 '^PORT=' "$(_f vnc.log)" 2>/dev/null | cut -d= -f2)
    [ -n "$port" ] && break
    _vnc_alive || break
    i=$((i+1)); sleep 0.1
  done
  if ! _vnc_alive; then
    _warn "x11vnc exited immediately; log tail:"; tail -5 "$(_f vnc.log)" >&2
    rm -f "$(_f vnc.pid)"; return 1
  fi
  _say "viewing $DPY on localhost:${port:-5900} -- point a VNC viewer there"
  _say "  $0 view --stop     # to close it (display keeps running)"
  return 0
}

# Emit a shell-rc snippet that points this shell at the dev display.
#
# WHY THIS IS A SUBCOMMAND and not a line of prose in a README: `export
# DISPLAY=:99` typed at a prompt lasts exactly as long as that terminal, and the
# whole value of this thing is that it catches invocations nobody is thinking
# about -- including the ones typed in a window opened tomorrow. Advice that has
# to be re-applied per terminal is advice that will be half-applied.
#
# The snippet is CONDITIONAL on the display actually listening, which matters
# more than it looks. An unconditional `export DISPLAY=:99` in a shell rc
# survives the display it names: after a reboot, or `wsl --shutdown`, or a
# `devdisplay.sh stop`, every GUI program in every new terminal points at
# nothing and fails with "cannot open display" -- including the ones that have
# nothing to do with testing. Conditional means the fallback is your normal
# desktop, silently and correctly.
cmd_shellinit() {
  cat <<EOF
# --- xschem dev display (generated by devdisplay.sh shellinit) ---------------
# Land GUI runs on the private test display when it is up, so a scripted
# xschem never takes the desktop. Falls back to your normal DISPLAY when it is
# not running -- start it with:  $0 start
# Spec: doc/claude/specs/dev_display.md
if [ -r "$STATE_DIR/display" ]; then
  _xschem_dpy=\$(cat "$STATE_DIR/display" 2>/dev/null)
  _xschem_n=\${_xschem_dpy#:}
  if [ -n "\$_xschem_dpy" ] && { [ -S "/tmp/.X11-unix/X\$_xschem_n" ] || \\
       ss -xl 2>/dev/null | grep -q "@/tmp/\\.X11-unix/X\$_xschem_n\\b"; }; then
    export DISPLAY="\$_xschem_dpy"
  fi
  unset _xschem_dpy _xschem_n
fi
# --- end xschem dev display --------------------------------------------------
EOF
}

cmd_exec() {
  [ $# -gt 0 ] || _die "exec needs a command" 2
  _ours || _die "$DPY is not running. Start it first: $0 start" 6
  DISPLAY="$DPY" GUI_GATE=0 "$@"
}

cmd_help() { sed -n '2,70p' "$0" | sed 's/^# \{0,1\}//'; }

# Dispatch only when EXECUTED. Sourcing this file gets the predicates above as a
# library and runs nothing -- test_devdisplay.sh needs that to check _wm_claimed
# directly. Without the guard, `. devdisplay.sh` with no args would run `status`.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-status}" in
    start)   shift; cmd_start "$@" ;;
    stop)    shift; cmd_stop "$@" ;;
    restart) shift; cmd_stop; cmd_start "$@" ;;
    status)  shift; cmd_status "$@" ;;
    view)      shift; cmd_view "$@" ;;
    exec)      shift; cmd_exec "$@" ;;
    shellinit) shift; cmd_shellinit "$@" ;;
    -h|--help|help) cmd_help ;;
    *) _die "unknown command '${1:-}'. Try: $0 help" 2 ;;
  esac
fi
