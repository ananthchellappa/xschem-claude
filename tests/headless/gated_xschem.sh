#!/bin/bash
# gated_xschem.sh — a drop-in replacement for `./src/xschem` that ENROLS the run
# in the GUI-test control gate.
#
# WHY: `run_suites.sh` gates a run only if you remember to use it. The habit it
# competes with is a bare loop:
#
#     for i in 1 2 3; do ./src/xschem --pipe -q --nolog --script t.tcl; done
#
# which never calls the gate at all, so the panel's Pause button has no
# authority over it — it can only watch. Swap the binary for this and the loop
# becomes gated with no other change:
#
#     for i in 1 2 3; do tests/headless/gated_xschem.sh --pipe -q --nolog --script t.tcl; done
#
# Prefer `run_suites.sh` when you are running whole suites: it also reports
# PASS/FAIL per run and offers a pause point BETWEEN runs. Use this when you
# need the raw binary with your own arguments.
#
# One invocation = one gate_start, so a long loop would once have meant one
# prompt per iteration. It does not any more: press **Allow 30m / Allow 2h** in
# the panel first and the whole loop runs unprompted, while Pause and Stop keep
# working throughout.
#
# Same fail-open contract as the rest of the gate: no DISPLAY, GUI_GATE=0, or no
# panel and this is just a slightly slower `xschem`. Exit status is the
# binary's, except 3 when the panel Stopped the run before it started.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)

# Route onto the private/persistent test display FIRST (spec
# doc/claude/specs/dev_display.md). This file used to source gui_gate.sh and
# nothing else, so the recommended drop-in binary *gated* the developer's screen
# instead of freeing it -- the panel could pause the flood, but the flood still
# landed on the monitor.
#
# On the default arm the display is invisible, the arm forces GUI_GATE=0, and
# the gate calls below become no-ops: there is nothing to pause when nothing is
# visible. The combination that still matters is the deliberate one --
#     AUDIT_DISPLAY=:0 tests/headless/gated_xschem.sh --script t.tcl
# -- where the arm leaves GUI_GATE exactly as the caller set it and this file
# behaves as it always did.
. "$HERE/xvfb_arm.sh"
xvfb_arm "$0" "$@"
XSCHEM="${XSCHEM:-$REPO/src/xschem}"

if [ ! -x "$XSCHEM" ]; then
  echo "FATAL: xschem binary not found/executable at: $XSCHEM" \
       "(build with: cd src && make, or set \$XSCHEM)" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$HERE/gui_gate.sh" 2>/dev/null || true

_label="gated_xschem: $(basename "${*:-xschem}" 2>/dev/null || echo xschem)"
if type gate_start >/dev/null 2>&1; then
  gate_start "$_label" || { echo "gui_gate: stopped before start" >&2; exit 3; }
fi
# Hold here if the panel is Paused, BEFORE spending a window on the display.
if type gate_pause_point >/dev/null 2>&1; then
  gate_pause_point "$_label" || { echo "gui_gate: STOP" >&2; gate_finish; exit 3; }
fi

"$XSCHEM" "$@"
_rc=$?

type gate_finish >/dev/null 2>&1 && gate_finish
exit "$_rc"
