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
#
# HOME: a THROWAWAY home first, before the display arm, so openbox on the private
# Xvfb and the xvfb-run re-exec both inherit it (tests/headless/test_home.sh;
# DECISIONS D4). XSCHEM_TEST_HOME=real runs against your own HOME, loudly.
# CWD: xschem runs from the repository root (below; DECISIONS D13.3), with its
# untitled autosave redirected into a private directory that is deleted at the
# end, so it does not land in the checkout either (issue 1486).
. "$HERE/test_home.sh"
test_home_arm || exit $?
. "$HERE/xvfb_arm.sh"
xvfb_arm "$0" "$@"
XSCHEM="${XSCHEM:-$REPO/src/xschem}"

# RUN FROM THE REPOSITORY ROOT (DECISIONS D13.3), as full_audit.sh does. xschem
# autosaves unsaved work to ./untitled~.sch, so a run from your home directory
# overwrote or deleted a ~/untitled~.sch of your own. Every argument that names
# a path EXISTING relative to your cwd -- `--script t.tcl`, a schematic, a
# `--logdir=dir` value -- is made absolute FIRST, so it still means the file you
# meant. An argument naming a path that does not exist yet (an output you want
# created) is left as written, and now resolves against the repository root.
_abs_if_exists() {   # print $1 absolute if it names an existing relative path
  case "$1" in
    ''|/*) printf '%s' "$1" ;;
    *) if [ -e "$1" ]; then
         if [ -d "$1" ]; then (cd "$1" && pwd)
         else printf '%s/%s' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"
         fi
       else printf '%s' "$1"; fi ;;
  esac
}
_args=()
for _a in "$@"; do
  case "$_a" in
    --*=*) _args+=("${_a%%=*}=$(_abs_if_exists "${_a#*=}")") ;;
    -*)    _args+=("$_a") ;;
    *)     _args+=("$(_abs_if_exists "$_a")") ;;
  esac
done
set -- ${_args[@]+"${_args[@]}"}
unset _args _a
case "$XSCHEM" in */*) XSCHEM=$(_abs_if_exists "$XSCHEM") ;; esac
cd "$REPO" || { echo "FATAL: cannot cd to the repository root $REPO" >&2; exit 1; }

# ... and the autosave itself goes to a PRIVATE directory, not into the checkout
# (issue 1486). xschem composes the untitled buffer's path from $PWD, so only
# $PWD moves; the cwd stays the repository root, because suites resolve fixtures
# against [pwd]. tests/headless/suite_cwd.sh has the mechanism and the numbers.
# shellcheck source=/dev/null
. "$HERE/suite_cwd.sh"
suite_cwd_arm "$REPO" || true
_scwd=$(suite_cwd_for run) || true

if [ ! -x "$XSCHEM" ]; then
  echo "FATAL: xschem binary not found/executable at: $XSCHEM" \
       "(build with: cd src && make, or set \$XSCHEM)" >&2
  suite_cwd_disarm; exit 1
fi

# shellcheck source=/dev/null
. "$HERE/gui_gate.sh" 2>/dev/null || true

_label="gated_xschem: $(basename "${*:-xschem}" 2>/dev/null || echo xschem)"
if type gate_start >/dev/null 2>&1; then
  gate_start "$_label" || { echo "gui_gate: stopped before start" >&2; suite_cwd_disarm; exit 3; }
fi
# Hold here if the panel is Paused, BEFORE spending a window on the display.
if type gate_pause_point >/dev/null 2>&1; then
  gate_pause_point "$_label" || { echo "gui_gate: STOP" >&2; suite_cwd_disarm; gate_finish; exit 3; }
fi

env "PWD=$_scwd" "$XSCHEM" "$@"
_rc=$?

suite_cwd_disarm
type gate_finish >/dev/null 2>&1 && gate_finish
exit "$_rc"
