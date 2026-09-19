#!/bin/bash
# xvfb_arm.sh — decide which X display a suite run gets, and default it to a
# private virtual one.
#
# WHY THIS EXISTS
#
# full_audit.sh and run_suites.sh used to inherit $DISPLAY. Launched from an
# interactive session that is a real screen, they take over that screen: 21 of
# the headless tests replay full <ButtonPress-1>/<B1-Motion>/<ButtonRelease-1>
# sequences through the PRODUCTION bindings on a real canvas, so the machine
# spends the whole audit placing resistors and dragging wires in front of
# whoever owns the monitor. The GUI-test control gate exists to make that
# survivable (Pause/Stop), but the better answer is not to borrow the screen at
# all.
#
# Xvfb is strictly better as the routine arm, and this is measured, not assumed
# (doc/claude/suggestions/xvfb_for_the_gui_test_arm.md, commit a8cd30ef):
#   - deterministic: 30/30 soak with identical check counts (397/150/488) where
#     the same suites on :0 have documented 4-in-10, 2-in-3 and 1-in-5 flake
#     rates
#   - faithful: a full audit under Xvfb reproduced the recorded :0 baseline
#     fail list exactly (279 PASS / 18 FAIL / 0 SKIP in 712 s)
#   - fast: test_wave_modes 2.3-2.4 s on Xvfb vs 6.2-45.6 s on :0
#
# WHAT STILL NEEDS A REAL DISPLAY, and is why this is a default and not a law:
#   1. a human eyeball -- judging a layout, poking at a widget
#   2. WSLg-specific bugs, which are invisible under Xvfb by construction
# For those: AUDIT_DISPLAY=:0
#
# WINDOW-MANAGER BEHAVIOUR was the third item on that list. A bare Xvfb runs no
# WM, so decoration, iconify, stacking and raise are meaningless there -- the
# standing ruling in doc/claude/signal_browser_detach_batch/PLAN.md. That is a
# property of running Xvfb EMPTY, not of Xvfb, so this file now starts openbox
# inside the virtual session by default. Measured, 2026-08-13:
#
#                        reparented   wm iconify -> state   ismapped
#   Xvfb, no WM              0        normal (silent no-op)    1
#   Xvfb + openbox           1        iconic                   0
#   :0 (WSLg)                1        normal                   1
#
# So openbox restores reparenting and real iconify/withdraw semantics -- and on
# iconify is MORE faithful than WSLg, whose Xwayland does not honour it either.
#
# WHAT OPENBOX DOES NOT CLOSE, measured in the same session: WSLg's extra
# asynchronous Configure traffic. One `wm geometry` request yields 3 Configure
# events on :0 and 1 under Xvfb with or without openbox, and `save_layout` is
# re-entered twice per restore on :0 and zero times under Xvfb. Calculator
# landmine D6 needs exactly that traffic, so it stays a :0-only REPRODUCTION.
#
# The lesson is not "add more window managers until the bug appears". It is that
# a guard which only fires on one developer's display is not covered at all:
# test_calc_skeleton S12 now FORCES that race instead of waiting for an
# environment to supply it, and goes red on every arm when the guard is removed.
# Prefer that shape for anything in this class. Full A/B in
# doc/claude/calculator_batch/receipts/00-phase0-skeleton.md.
#
# INTERFACE
#
#   AUDIT_DISPLAY   unset | auto  attach to the persistent dev display if one
#                                 is up (devdisplay.sh), else spawn a private
#                                 Xvfb                                (DEFAULT)
#                   none          run with DISPLAY unset; GUI legs self-skip
#                   :0  (or any)  use that display verbatim
#   AUDIT_SCREEN    Xvfb screen spec, default 1920x1080x24
#   AUDIT_WM        window manager to run inside the Xvfb session.
#                   default `openbox`; `none` for the old WM-less behaviour;
#                   or the name/path of another. Ignored unless we spawn Xvfb --
#                   an explicit AUDIT_DISPLAY already has whatever WM it has.
#   AUDIT_XVFB_BASE the first display number the private Xvfb may take,
#                   default 200; never below 100 (DECISIONS D17.8). xvfb-run -a
#                   alone numbers from :99, which is the persistent dev
#                   display's number, so a run on a box whose dev display was
#                   down took :99 for itself. 200 up also stays clear of T1's
#                   own private arm (:100 up, run_regression.tcl).
#
# Screen size is PINNED, never left to chance: test_fluid_bodyshove_guards_0132
# passes at 1280x1024 / 1600x900 / 1920x1080 / 2560x1440 / 5120x1440 and fails
# only at 1600x1200. A run whose geometry is not recorded cannot be compared
# against another run.
#
# THE HAZARD THIS FILE EXISTS TO CONTAIN: on the Xvfb arm, GUI_GATE=0 is not a
# preference, it is mandatory, and it is forced below rather than left to the
# caller. gui_gate.sh's _gate_enabled only tests that $DISPLAY is non-empty, so
# a virtual display arms the gate exactly like a real one; gate_start then
# reaches _gate_attention, which KILLS the live panel and relaunches it with
# the calling suite's DISPLAY. That would move the user's visible Pause/Stop
# panel onto a display nobody can see, for every session sharing
# ~/.claude/gui_test_gate/. Xvfb without GUI_GATE=0 does not free the screen;
# it breaks the Pause button.
#
# USAGE, from a script's top, before it parses anything expensive:
#     . "$HERE/xvfb_arm.sh"
#     xvfb_arm "$0" "$@"          # may exec; never returns in that case

# Echo the display of a LIVE persistent dev display, or fail. Liveness is
# delegated to devdisplay.sh's own `status` rather than reimplemented here:
# deciding "is :99 really ours" needs a pid-identity check (pids recycle across
# a WSL boot while the state dir persists), and two copies of that rule would
# drift. One implementation, one answer.
_xvfb_dev_display() {
  local dd; dd="$(dirname "$_XVFB_ARM_SELF")/devdisplay.sh"
  [ -x "$dd" ] || return 1
  "$dd" status >/dev/null 2>&1 || return 1
  # The state dir belongs to the tester's REAL home: test_home.sh carries it as
  # XSCHEM_DEVDISPLAY_DIR, and the fallback reads through XSCHEM_TEST_REAL_HOME so a
  # caller that switched HOME without carrying it still finds the dev display
  # rather than silently spawning a private one (the 1397 trap).
  local sf="${XSCHEM_DEVDISPLAY_DIR:-${XSCHEM_TEST_REAL_HOME:-$HOME}/.claude/xschem_dev_display}/display"
  [ -r "$sf" ] || return 1
  local d; d=$(cat "$sf" 2>/dev/null)
  [ -n "$d" ] || return 1
  echo "$d"
}

# Re-exec self under a private Xvfb unless told otherwise. Idempotent: the
# re-exec sets XSCHEM_XVFB_ARM so the second pass falls straight through.
xvfb_arm() {
  local self="$1"; shift
  local _dpy

  if [ "${XSCHEM_XVFB_ARM:-0}" = 1 ]; then
    return 0
  fi

  case "${AUDIT_DISPLAY:-auto}" in
    none)
      export XSCHEM_XVFB_ARM=1
      unset DISPLAY
      echo "display arm: none (DISPLAY unset; GUI legs will self-skip)" >&2
      return 0
      ;;
    auto|"")
      # Prefer a PERSISTENT dev display if one is up (devdisplay.sh). Attaching
      # is better than spawning: no ~1 s xvfb-run per invocation, one stable
      # display shared by every entry point and every worktree, and -- the
      # reason it exists -- the same display a bare `./src/xschem --script ...`
      # gets from the shell, which no arming script can reach.
      # doc/claude/specs/dev_display.md
      if _dpy=$(_xvfb_dev_display); then
        export XSCHEM_XVFB_ARM=1
        export DISPLAY="$_dpy"
        # forced for the same reason as the spawn path -- see "THE HAZARD" above
        export GUI_GATE=0
        echo "display arm: ATTACHED to persistent dev display $DISPLAY (devdisplay.sh), GUI_GATE=0" >&2
        return 0
      fi
      ;;   # no persistent display -- fall through and spawn a private one
    *)
      export XSCHEM_XVFB_ARM=1
      export DISPLAY="$AUDIT_DISPLAY"
      echo "display arm: $DISPLAY (explicit; the gate is left as you set it)" >&2
      return 0
      ;;
  esac

  if ! command -v xvfb-run >/dev/null 2>&1; then
    export XSCHEM_XVFB_ARM=1
    echo "display arm: xvfb-run NOT FOUND -> falling back to inherited DISPLAY=${DISPLAY:-<unset>}" >&2
    echo "             (install xvfb, or set AUDIT_DISPLAY explicitly to silence this)" >&2
    return 0
  fi

  local screen="${AUDIT_SCREEN:-1920x1080x24}"
  local wm="${AUDIT_WM:-openbox}"
  if [ "$wm" != none ] && ! command -v "$wm" >/dev/null 2>&1; then
    echo "display arm: WM '$wm' not found -> running WM-less (install it, or set AUDIT_WM=none to silence)" >&2
    wm=none
  fi
  # D17.8: never :99. `-n` BEFORE `-a`: xvfb-run applies its options in order,
  # and `-a` searches upward from whatever number is current when it is read.
  local base="${AUDIT_XVFB_BASE:-200}"
  case "$base" in ''|*[!0-9]*)
    echo "display arm: AUDIT_XVFB_BASE='$base' is not a display number -- using 200" >&2
    base=200 ;;
  esac
  base=$((10#$base))
  if [ "$base" -lt 100 ]; then
    echo "display arm: AUDIT_XVFB_BASE=$base is below 100 -- using 100 (a private display never takes :99, the dev display's number)" >&2
    base=100
  fi
  echo "display arm: private Xvfb from :$base up, screen $screen, wm $wm, GUI_GATE=0" >&2
  echo "             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)" >&2
  export XSCHEM_XVFB_ARM=1
  export AUDIT_SCREEN="$screen"
  export AUDIT_WM="$wm"
  # forced, not defaulted -- see "THE HAZARD" above
  export GUI_GATE=0
  # This file re-enters itself as an executable, inside the new X session, to
  # start the WM before handing off. It is one file rather than two because the
  # launcher and the policy that decides to launch must not drift apart.
  #
  # THE THROWAWAY HOME CROSSES THIS EXEC BY HANDOFF (test_home.sh, DECISIONS D5).
  # exec never runs the EXIT trap that deletes it, and the re-exec'd driver would
  # otherwise see a live owner (xvfb-run keeps this pid) and treat itself as
  # nested -- so nothing would ever delete it. The handoff names THIS pid, and the
  # re-exec'd driver takes ownership only if that pid is its parent or grandparent
  # and matches .owner. Exported here and nowhere else: exported any earlier, any
  # direct child of the owner could claim a live home.
  #
  # _XVFB_LAUNCH is --wm-launch for a bash driver (it re-arms, and takes the
  # home over, itself) and --wm-launch-own for the `--arm` entry below, whose
  # command is a POSIX script that cannot: the launcher takes it over instead.
  #
  # THE REAPER STARTS HERE, BEFORE THE EXEC (D17.7) -- see THE REAPER below.
  _xvfb_start_reaper "$wm"
  if type test_home_handoff >/dev/null 2>&1; then test_home_handoff; fi
  exec xvfb-run -n "$base" -a -s "-screen 0 $screen" "$_XVFB_ARM_SELF" "${_XVFB_LAUNCH:---wm-launch}" "$self" "$@"
}

# Start $AUDIT_WM on the current $DISPLAY and block until it has actually
# claimed the screen, recording the server and the WM in the owner's throwaway
# for the sweep (D17.7). The reaper is already running: it started before the
# exec into xvfb-run.
#
# "Actually claimed" matters: openbox takes a few tens of ms to own the WM_S0
# manager selection, and a toplevel mapped before that is never reparented --
# it would behave exactly like the WM-less case the WM was added to fix, but
# only sometimes, which is worse than not having it. The check is the
# _NET_SUPPORTING_WM_CHECK property on the root window, which a compliant WM
# sets once it is live. Bounded, and failure is non-fatal: a run WITHOUT a WM is
# still a useful run, a run that hangs waiting for one is not.
_xvfb_wm_start() {
  local wm="${AUDIT_WM:-openbox}" wmpid=""
  _xvfb_record_server
  if [ "$wm" != none ]; then
    # The handoff variable is the re-exec'd driver's to consume, never the WM's.
    env -u XSCHEM_TEST_HOME_HANDOFF "$wm" >/dev/null 2>&1 &
    wmpid=$!
    if command -v xprop >/dev/null 2>&1; then
      local i=0
      while [ "$i" -lt 100 ]; do
        # Match the SUCCESS form, `... window id # 0x...`, not the word
        # "window". xprop's failure output is "no such atom on any window."
        # -- which contains "window", so a `grep -q window` readiness check
        # succeeds on the first iteration forever and the wait never waits.
        if xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q 'window id #'; then
          break
        fi
        kill -0 "$wmpid" 2>/dev/null || { echo "!! display-arm WARNING: $wm died at startup" >&2; break; }
        i=$((i + 1))
        sleep 0.05
      done
      if [ "$i" -ge 100 ]; then
        # LOUD, and deliberately not prefixed "display arm:" -- the first
        # version of this warning was prefixed exactly like the normal banner
        # lines and was therefore filtered out by every `grep -v "display arm"`
        # used to read these runs, which is how a wait loop that never waited
        # went unnoticed. A warning you routinely filter is not a warning.
        echo "!! display-arm WARNING: $wm did not claim the screen in 5s -- continuing WM-LESS" >&2
      fi
    fi
    # The WM runs under the driver's (throwaway) HOME, and after the exec below
    # it is a child of the driver itself. Name it, so the driver's test_home.sh
    # EXIT trap can stop it BEFORE deleting that HOME -- otherwise it outlives
    # the run and writes into a deleted home (the orphan shape now holding :99).
    export XSCHEM_XVFB_WM_PID="$wmpid"
    _xvfb_record_wm "$wmpid" "$wm"
  fi
}

# D17.7: RECORD THE SERVER IN THE THROWAWAY, so that a run killed before its
# reaper could act -- or whose reaper was itself killed -- still leaves the
# record the next arm's sweep kills it from, BY IDENTITY (argv[0] Xvfb and a
# HOME that is exactly the dead throwaway: test_home.sh _th_kill_recorded_display,
# test_utility.tcl t1_home_kill_xvfb). Round 2 recorded nothing on this path,
# and the regression refuter measured the sweep deleting a killed run's home
# and leaving its Xvfb serving, with HOME a deleted directory, for good.
# Written only into a throwaway this xvfb-run's OWN run owns -- `.owner` names
# the pre-exec driver (xvfb-run is that very pid, $PPID here) or, after the
# --wm-launch-own takeover, this launcher -- never into a real or custom home,
# and never over a nested run's parent's record.
_xvfb_owns_home() {
  [ -f "$HOME/.owner" ] || return 1
  [[ "${HOME##*/}" =~ $_TH_NAME_RE ]] 2>/dev/null || return 1
  local o
  o=$(head -n 1 "$HOME/.owner" 2>/dev/null); o="${o%% *}"
  [ "$o" = "$PPID" ] || [ "$o" = "$BASHPID" ]
}
_xvfb_record_server() {
  local n x
  _xvfb_owns_home || return 0
  n="${DISPLAY#:}"; n="${n%%.*}"
  case "$n" in ''|*[!0-9]*) return 0 ;; esac
  x=$(head -c 32 "/tmp/.X$n-lock" 2>/dev/null | tr -cd 0-9)
  # the server xvfb-run started: named by its lock, and a child of xvfb-run
  [ -n "$x" ] && [ "$(_xvfb_stat_field "$x" 4)" = "$PPID" ] || return 0
  mkdir -p "$HOME/.xvfb" 2>/dev/null || return 0
  echo ":$n" > "$HOME/.xvfb/display"
  echo "$x" > "$HOME/.xvfb.pid"
}
_xvfb_record_wm() {   # <pid> <wm>
  [ -n "$1" ] && _xvfb_owns_home || return 0
  mkdir -p "$HOME/.xvfb" 2>/dev/null || return 0
  echo "${2##*/}" > "$HOME/.xvfb/wm"
  echo "$1" > "$HOME/.xvfb/wm.pid"
}

# The in-session launcher for a bash DRIVER: start the WM, then exec the driver,
# which re-arms and takes the throwaway over itself (test_home.sh handoff).
_xvfb_wm_launch() {
  _xvfb_wm_start
  exec "$@"
}

# ---------------------------------------------------------------------------
# THE REAPER (DECISIONS D13.15, D17.7). A private Xvfb must not outlive a killed
# owner by more than a few seconds. xvfb-run stops its Xvfb when the command it
# runs exits -- but only if xvfb-run itself is still alive to do it, and a
# SIGKILL of the driver the tester launched IS a SIGKILL of xvfb-run (the driver
# exec'd into it). Measured in round 1: the server and its openbox survived
# until the next armed run's sweep, >300 s later, and forever if nobody ran
# again.
#
# ⚠ IT STARTS BEFORE THE EXEC, NOT INSIDE THE SESSION (D17.7). Round 2 started
# it from the launcher, after xvfb-run had started the server and the WM had
# claimed it -- and the round-2 regression refuter measured the window that
# left: a kill -9 of the tester's pid 98-103 ms after the server started left
# that Xvfb serving for good (3 of 3), because the launcher's reaper, finding
# xvfb-run already dead, never started. So the watcher is started here, by the
# very process that is about to exec into xvfb-run: xvfb-run keeps its pid AND
# its start time, so "the owner" is known before the server exists, and there is
# no instant at which a server is up with nobody watching it.
#
# ⚠ AND IT KNOWS WHAT TO KILL BY A TAG, NOT BY A PID IT HAS TO BE TOLD. The
# server does not exist yet, so its pid cannot be passed in. Instead this process
# exports XSCHEM_TEST_XVFB_TAG=<its pid>.<its start time>.<boot> -- unique on
# this machine -- and xvfb-run, its Xvfb and the WM all inherit it. When the
# owner is gone, the reaper kills exactly the processes whose argv[0] is Xvfb or
# the WM AND whose /proc/<pid>/environ carries that exact tag: identity, never a
# name or a number (D13.7). An XSCHEM_TEST_* name, so no snapshot of the
# tester's environment (D13.16) carries it into a long-lived process.
#
# It polls the owner every 0.5 s, by pid AND start time (a recycled pid is not
# the owner); on a normal exit xvfb-run has already stopped its server, the scan
# finds nothing, and the reaper is gone within a second. It is started under
# `setsid env -i PATH=...`: a terminal's hangup to the run's process group does
# not take it with it, and for as long as it runs it carries none of the
# harness variables.
_xvfb_stat_field() {   # <pid> <n>: field n (1-based, n>=3) of /proc/<pid>/stat
  local s n="$2"
  s=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  s="${s##*) }"
  set -- $s
  shift $(( n - 3 )) 2>/dev/null || return 1
  printf '%s' "${1:-}"
}
_xvfb_same() {   # <pid> <starttime>: that very process, alive and not a zombie
  local st
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ -d "/proc/$1" ] || return 1
  st=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  st="${st##*) }"
  set -- $1 $2 $st
  [ "$3" != Z ] && [ "${22:-}" = "$2" ]
}
# Live, non-zombie pids whose argv[0] basename is one of <prog>... AND whose
# environment carries exactly XSCHEM_TEST_XVFB_TAG=<tag>, one per line.
_xvfb_tagged() {   # <tag> <prog>...
  local T="$1" d p a0 st; shift
  for d in /proc/[0-9]*; do
    p="${d#/proc/}"
    [ "$p" != "$BASHPID" ] || continue
    a0=""; IFS= read -r -d '' a0 < "$d/cmdline" 2>/dev/null
    a0="${a0##*/}"
    [ -n "$a0" ] || continue
    case " $* " in *" $a0 "*) ;; *) continue ;; esac
    st=$(cat "$d/stat" 2>/dev/null) || continue
    st="${st##*) }"; [ "${st%% *}" != Z ] || continue
    grep -qxzF "XSCHEM_TEST_XVFB_TAG=$T" "$d/environ" 2>/dev/null || continue
    echo "$p"
  done
}
_xvfb_start_reaper() {   # <wm name, or none>
  [ -d /proc/self ] || return 0
  # $BASHPID captured HERE: inside a $(...) below it would name that subshell,
  # and the reaper would take a dead process for the owner and kill a live run's
  # display within a poll (measured once: test_file_menu_log lost its X server).
  local me="$BASHPID" ps boot
  ps=$(_xvfb_stat_field "$me" 22) || return 0
  boot=$(tr -cd '0-9a-f' < /proc/sys/kernel/random/boot_id 2>/dev/null | head -c 12)
  export XSCHEM_TEST_XVFB_TAG="$me.$ps.${boot:-0}"
  local wn="${1:-none}"; wn="${wn##*/}"
  if command -v setsid >/dev/null 2>&1; then
    setsid env -i PATH="$PATH" bash "$_XVFB_ARM_SELF" --reap \
      "$me" "$ps" "$XSCHEM_TEST_XVFB_TAG" "$wn" "$HOME" </dev/null >/dev/null 2>&1 &
  else
    env -i PATH="$PATH" bash "$_XVFB_ARM_SELF" --reap \
      "$me" "$ps" "$XSCHEM_TEST_XVFB_TAG" "$wn" "$HOME" </dev/null >/dev/null 2>&1 &
  fi
  return 0
}
# The fifth argument, the run's HOME, is not read: it is on the command line so
# that a person -- or a suite checking for leftovers -- can see whose it is.
_xvfb_reap() {   # <owner pid> <its start time> <tag> <wm name or none> [<home>]
  local P="$1" Ps="$2" T="$3" Wn="${4:-none}" progs pids p k n x empty=0 i=0 xl=""
  trap '' HUP INT
  case "$T" in ''|*[!0-9a-f.]*) exit 0 ;; esac
  progs="Xvfb"; [ "$Wn" = none ] || progs="Xvfb $Wn"
  while _xvfb_same "$P" "$Ps"; do sleep 0.5; done
  # The owner is gone: whatever of its session is still running goes too. The
  # scan repeats until it has come back empty twice, so a server that was still
  # between fork and exec when the owner died is not missed.
  while [ "$i" -lt 12 ]; do
    pids=$(_xvfb_tagged "$T" $progs)
    if [ -z "$pids" ]; then
      empty=$((empty + 1)); [ "$empty" -ge 2 ] && break
    else
      empty=0
      k=TERM; [ "$i" -ge 6 ] && k=KILL
      for p in $pids; do
        # remember each server's display, to clear its lock by CONTENT below
        n=$( (tr '\0' '\n' < "/proc/$p/cmdline") 2>/dev/null | sed -n 's/^:\([0-9][0-9]*\)$/\1/p' | head -n 1)
        [ -n "$n" ] && xl="$xl $p:$n"
        kill -"$k" "$p" 2>/dev/null
      done
    fi
    sleep 0.5
    i=$((i + 1))
  done
  # A SIGKILLed server leaves its lock; remove it only if it still names the
  # server just stopped -- by CONTENT, never by number (D13.14).
  for x in $xl; do
    p="${x%%:*}"; n="${x#*:}"
    [ -d "/proc/$p" ] && continue
    if [ "$(head -c 32 "/tmp/.X$n-lock" 2>/dev/null | tr -cd 0-9)" = "$p" ]; then
      rm -f "/tmp/.X$n-lock" "/tmp/.X11-unix/X$n" 2>/dev/null
    fi
  done
  exit 0
}

# Remember where this file lives even when it is SOURCED (in which case $0 is
# the caller, not this file). BASH_SOURCE[0] is this file in both cases.
_XVFB_ARM_SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")

# Executed (not sourced) as the in-session launcher: xvfb_arm.sh --wm-launch <cmd> [args]
# test_home.sh is SOURCED for its throwaway pattern only (sourcing arms nothing):
# _xvfb_record_server writes into a throwaway and nothing else.
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${1:-}" = "--wm-launch" ]; then
  shift
  # shellcheck source=/dev/null
  . "$(dirname "$_XVFB_ARM_SELF")/test_home.sh"
  _xvfb_wm_launch "$@"
fi

# The detached watcher (see THE REAPER above): xvfb_arm.sh --reap <args>
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${1:-}" = "--reap" ]; then
  shift
  _xvfb_reap "$@"
fi

# The in-session launcher for the `--arm` entry below: its command is a POSIX
# script that can neither source test_home.sh nor run an EXIT trap, so THIS
# process takes the throwaway over (test_home.sh handoff: its parent is the
# pre-exec owner, now running xvfb-run), runs the command as a CHILD, and exits
# with its status -- after its EXIT trap has stopped the WM and deleted the home.
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${1:-}" = "--wm-launch-own" ]; then
  shift
  # shellcheck source=/dev/null
  . "$(dirname "$_XVFB_ARM_SELF")/test_home.sh"
  test_home_arm || exit $?
  _xvfb_wm_start
  "$@"
  _xa_rc=$?
  exit "$_xa_rc"
fi

# POSIX-callable entry:  bash xvfb_arm.sh --arm <script> [args]
#
# Most of the standalone .sh suites are `#!/bin/sh`, and this file is bash --
# `local`, `BASH_SOURCE`, and the array subscript above all break under dash. So
# a POSIX script cannot source it. Rather than flip seven shebangs from sh to
# bash (which silently swaps the `echo` builtin's backslash handling underneath
# scripts nobody is re-reading today), they re-exec THROUGH here:
#
#     HERE=$(cd "$(dirname "$0")" && pwd)
#     [ "${XSCHEM_XVFB_ARM:-0}" = 1 ] || exec bash "$HERE/xvfb_arm.sh" --arm sh "$0" "$@"
#
# One line, no interpreter change, and the arming policy stays in one file.
#
# Note the explicit `sh` before "$0". Several of these suites are NOT chmod +x
# (test_flylines.sh, test_file_menu_log.sh, test_recent_launchlog.sh) and are
# run as `sh tests/headless/<t>.sh`. Re-exec'ing "$0" alone turns that into an
# exec of a non-executable file -- "Permission denied", and the suite never
# runs at all. Naming the interpreter works either way.
#
# THE HOME IS ARMED HERE TOO (DECISIONS D13.1). These seven suites are documented
# entry points, and round 1 measured them rewriting ~/.xschem/geometry and
# creating ~/.cache/openbox, because only the three drivers armed. So this entry
# arms a throwaway FIRST (test_home.sh), exactly as the drivers do, and then:
#   * on the private Xvfb path xvfb_arm execs xvfb-run, handing the home off to
#     the --wm-launch-own launcher above, which owns and deletes it;
#   * on every other path (attach, none, explicit, no xvfb-run) it runs the
#     command as a CHILD -- never exec, which would skip the EXIT trap that
#     deletes the home -- and exits with the command's status.
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${1:-}" = "--arm" ]; then
  shift
  [ $# -gt 0 ] || { echo "!! xvfb_arm --arm needs a command" >&2; exit 2; }
  # shellcheck source=/dev/null
  . "$(dirname "$_XVFB_ARM_SELF")/test_home.sh"
  test_home_arm || exit $?
  _XVFB_LAUNCH=--wm-launch-own
  xvfb_arm "$@"     # may exec (xvfb-run path); returns on attach/none/explicit
  unset _XVFB_LAUNCH
  "$@"
  _xa_rc=$?
  exit "$_xa_rc"
fi
