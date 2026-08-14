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
#   2. window-manager behaviour. Xvfb runs no WM, so decoration, iconify,
#      stacking, raise and focus-follow are meaningless there (the standing
#      ruling in doc/claude/signal_browser_detach_batch/PLAN.md). Starting a WM
#      inside the Xvfb session would close most of this gap; none is installed.
#   3. WSLg-specific bugs, which are invisible under Xvfb by construction.
# For those: AUDIT_DISPLAY=:0
#
# INTERFACE
#
#   AUDIT_DISPLAY   unset | auto  spawn a private Xvfb                (DEFAULT)
#                   none          run with DISPLAY unset; GUI legs self-skip
#                   :0  (or any)  use that display verbatim
#   AUDIT_SCREEN    Xvfb screen spec, default 1920x1080x24
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
  echo "display arm: private Xvfb, screen $screen, GUI_GATE=0" >&2
  echo "             (AUDIT_DISPLAY=:0 to use the real screen, =none to skip GUI legs)" >&2
  export XSCHEM_XVFB_ARM=1
  export AUDIT_SCREEN="$screen"
  # forced, not defaulted -- see "THE HAZARD" above
  export GUI_GATE=0
  exec xvfb-run -a -s "-screen 0 $screen" "$self" "$@"
}
