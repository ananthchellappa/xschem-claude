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
#   AUDIT_DISPLAY   unset | auto  spawn a private Xvfb                (DEFAULT)
#                   none          run with DISPLAY unset; GUI legs self-skip
#                   :0  (or any)  use that display verbatim
#   AUDIT_SCREEN    Xvfb screen spec, default 1920x1080x24
#   AUDIT_WM        window manager to run inside the Xvfb session.
#                   default `openbox`; `none` for the old WM-less behaviour;
#                   or the name/path of another. Ignored unless we spawn Xvfb --
#                   an explicit AUDIT_DISPLAY already has whatever WM it has.
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

# Re-exec self under a private Xvfb unless told otherwise. Idempotent: the
# re-exec sets XSCHEM_XVFB_ARM so the second pass falls straight through.
xvfb_arm() {
  local self="$1"; shift

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
      ;;   # fall through and spawn
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
  echo "display arm: private Xvfb, screen $screen, wm $wm, GUI_GATE=0" >&2
  echo "             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)" >&2
  export XSCHEM_XVFB_ARM=1
  export AUDIT_SCREEN="$screen"
  export AUDIT_WM="$wm"
  # forced, not defaulted -- see "THE HAZARD" above
  export GUI_GATE=0
  # This file re-enters itself as an executable, inside the new X session, to
  # start the WM before handing off. It is one file rather than two because the
  # launcher and the policy that decides to launch must not drift apart.
  exec xvfb-run -a -s "-screen 0 $screen" "$_XVFB_ARM_SELF" --wm-launch "$self" "$@"
}

# Start $AUDIT_WM on the current $DISPLAY and block until it has actually
# claimed the screen, then exec the real script.
#
# "Actually claimed" matters: openbox takes a few tens of ms to own the WM_S0
# manager selection, and a toplevel mapped before that is never reparented --
# it would behave exactly like the WM-less case the WM was added to fix, but
# only sometimes, which is worse than not having it. The check is the
# _NET_SUPPORTING_WM_CHECK property on the root window, which a compliant WM
# sets once it is live. Bounded, and failure is non-fatal: a run WITHOUT a WM is
# still a useful run, a run that hangs waiting for one is not.
_xvfb_wm_launch() {
  local wm="${AUDIT_WM:-openbox}"
  if [ "$wm" != none ]; then
    "$wm" >/dev/null 2>&1 &
    local wmpid=$!
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
  fi
  exec "$@"
}

# Remember where this file lives even when it is SOURCED (in which case $0 is
# the caller, not this file). BASH_SOURCE[0] is this file in both cases.
_XVFB_ARM_SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")

# Executed (not sourced) as the in-session launcher: xvfb_arm.sh --wm-launch <cmd> [args]
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${1:-}" = "--wm-launch" ]; then
  shift
  _xvfb_wm_launch "$@"
fi
