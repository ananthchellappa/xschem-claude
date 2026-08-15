#!/bin/sh
# Phase-0 smoke for the action-logging feature: the log file + --logdir option.
# This is a STARTUP/CLI behavior (file creation, rotation, fatal-on-bad-dir,
# no-litter policy), so it is driven at the process level rather than as a single
# in-process .tcl like the binding smokes.
#
#   sh tests/headless/test_action_log.sh
#
# Prints "RESULT: ALL PASS" / "RESULT: N FAILED" and exits nonzero on failure.

HERE=$(cd "$(dirname "$0")" && pwd)

# Route this run onto the private/persistent GUI-test display instead of the
# screen it was launched from (tests/headless/xvfb_arm.sh, spec
# doc/claude/specs/dev_display.md). POSIX sh cannot source the arm -- it is
# bash -- so re-exec through its --arm entry. AUDIT_DISPLAY=:0 opts back in.
[ "${XSCHEM_XVFB_ARM:-0}" = 1 ] || exec bash "$HERE/xvfb_arm.sh" --arm sh "$0" "$@"
REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="$REPO/src/xschem"
TMP=$(mktemp -d /tmp/xschem_actionlog_test.XXXXXX)
fail=0

ok()   { echo "ok:   $1"; }
bad()  { echo "FAIL: $1"; fail=$((fail+1)); }

# run xschem headlessly, quitting immediately after startup; never block
run() { timeout 30 "$XSCHEM" --pipe -q -x "$@" >/dev/null 2>&1; }

# 1) --logdir creates the directory and writes Xschem.log with the Tcl-comment header
LD="$TMP/logs"
run --logdir "$LD"
if [ -f "$LD/Xschem.log" ]; then ok "Xschem.log created under --logdir"; else bad "Xschem.log not created under --logdir"; fi
if head -1 "$LD/Xschem.log" 2>/dev/null | grep -q '^# xschem action log'; then ok "log has the Tcl-comment header"; else bad "log header missing/wrong"; fi

# 2) rotation: subsequent runs take the next free name
run --logdir "$LD"
run --logdir "$LD"
if [ -f "$LD/Xschem.log.1" ] && [ -f "$LD/Xschem.log.2" ]; then ok "rotation Xschem.log.1 / .2"; else bad "rotation did not produce .1/.2"; fi

# 3) uncreatable logdir is fatal (nonzero exit) with a message on stderr
ERR=$(timeout 30 "$XSCHEM" --pipe -q -x --logdir /proc/cannot/make/this >/dev/null 2>&1; echo "rc=$?")
rc=$(echo "$ERR" | sed -n 's/.*rc=//p')
if [ "$rc" != "0" ]; then ok "uncreatable logdir exits nonzero (rc=$rc)"; else bad "uncreatable logdir did not abort"; fi
if timeout 30 "$XSCHEM" --pipe -q -x --logdir /proc/cannot/make/this 2>&1 | grep -qi "cannot create log directory"; then
  ok "uncreatable logdir prints an error message"
else bad "no error message for uncreatable logdir"; fi

# 4) no-litter policy: headless (no X) WITHOUT --logdir creates no log in the cwd
WD="$TMP/work"; mkdir -p "$WD"
( cd "$WD" && run )
if ls "$WD"/Xschem.log* >/dev/null 2>&1; then bad "headless run littered the cwd with a log"; else ok "headless w/o --logdir creates no log (no litter)"; fi

# 5) --nolog beats even an explicit-opt-in environment: no file is ever created
ND="$TMP/nolog"; mkdir -p "$ND"
( cd "$ND" && run --nolog )
if ls "$ND"/Xschem.log* >/dev/null 2>&1; then bad "--nolog run still created a log"; else ok "--nolog creates no log"; fi

# 6) --nolog + --logdir is contradictory: fatal, nonzero exit, clear message
rc=$(timeout 30 "$XSCHEM" --pipe -q -x --nolog --logdir "$TMP/conflict" >/dev/null 2>&1; echo $?)
if [ "$rc" != "0" ]; then ok "--nolog + --logdir exits nonzero (rc=$rc)"; else bad "--nolog + --logdir did not abort"; fi
if timeout 30 "$XSCHEM" --pipe -q -x --nolog --logdir "$TMP/conflict" 2>&1 | grep -qi "mutually exclusive"; then
  ok "--nolog + --logdir prints an error message"
else bad "no error message for --nolog + --logdir"; fi
if [ -d "$TMP/conflict" ]; then bad "conflicting run still created the logdir"; else ok "conflicting run created nothing"; fi

rm -rf "$TMP"
if [ "$fail" -eq 0 ]; then echo "RESULT: ALL PASS"; else echo "RESULT: $fail FAILED"; fi
[ "$fail" -eq 0 ]
