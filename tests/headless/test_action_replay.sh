#!/bin/sh
# Acceptance smoke for the action log (spec section 5 "the real one"):
# RECORD -> REPLAY -> DIFF across TWO processes.
#
#   1. process A loads a fixture, is driven through bound input actions (via
#      `xschem callback`, the real dispatch path that logs), and snapshots its
#      state. Its Xschem.log is captured.
#   2. process B loads the SAME fixture FRESH, `source`s A's log, and snapshots.
#   3. the two snapshots must be identical -> the log faithfully reproduces the
#      session.
#
# This proves the log is actually REPLAYABLE, not merely well-formed -- the one
# thing a single-process check cannot show.
#
# Needs a display (drives the canvas); run e.g. DISPLAY=:0 sh test_action_replay.sh
#
# What is diffed, and why a zoom RATIO not absolute zoom: the logged view
# commands reproduce the relative zoom TRANSFORM (xctx->zoom /= factor is pure)
# but not the absolute view. Absolute zoom depends on the post-load baseline,
# which depends on the drawing-area size at load time -- and that varies between
# two processes (window mapping is nondeterministic under WSLg, issues 0001/0002).
# The log is not meant to reproduce the absolute view anyway: wheel zoom centers
# on the mouse (view_zoom reads mousex_snap) and `xschem zoom_in` does not capture
# the pointer, so origin cannot round-trip either (a v1 limit, kin to the
# click-select gap, issue 0005). So the snapshot diffs the geometry-INDEPENDENT
# state the log IS designed to reproduce: the zoom transform (final/baseline),
# the colorscheme flag, and the object counts.

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="$REPO/src/xschem"
FIXTURE="xschem_library/examples/nand2.sch"   # repo-relative; small, has insts+wires
fail=0
ok()  { echo "ok:   $1"; }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

if [ -z "${DISPLAY:-}" ]; then echo "SKIP: no DISPLAY (this smoke drives the canvas)"; exit 0; fi
if [ ! -x "$XSCHEM" ]; then echo "FATAL: $XSCHEM not built"; exit 3; fi

LOGDIR=$(mktemp -d); REC=$(mktemp); REP=$(mktemp); RECD=$(mktemp); REPD=$(mktemp)
cleanup() { rm -rf "$LOGDIR" "$REC" "$REP" "$RECD" "$REPD"; }
trap cleanup EXIT

# snapshot helper text shared by both drivers (Tcl): geometry-independent state.
# zoomxform = final/baseline zoom (the relative transform the log reproduces);
# rounded to 6 sig figs so the two processes' differing baselines, divided out,
# compare equal without last-ULP float noise. Requires ::z0 set after load.
SNAP='set out [open $::SNAP w]
puts $out "zoomxform [format %.6g [expr {[xschem get zoom]/$::z0}]]"
puts $out "dark $dark_colorscheme"
puts $out "inst [xschem get instances]"
puts $out "wires [xschem get wires]"
close $out'

# --- RECORD driver -----------------------------------------------------------
cat > "$RECD" <<EOF
set ::SNAP "$REC"
xschem load $FIXTURE
set ::z0 [xschem get zoom]            ;# baseline, before any action
# bound input actions through the real dispatch path (these get logged):
#   wheel-up = ButtonPress(4) button 4 -> view.zoom_in   (x3)
#   wheel-down= ButtonPress(4) button 5 -> view.zoom_out  (x1)
#   key O (keysym 79)                  -> view.toggle_colorscheme
xschem callback .drw 4 350 250 0 4 0 0
xschem callback .drw 4 350 250 0 4 0 0
xschem callback .drw 4 350 250 0 4 0 0
xschem callback .drw 4 350 250 0 5 0 0
xschem callback .drw 2 350 250 79 0 0 0
update idletasks
$SNAP
catch {destroy .ciw}; update            ;# clean RAIL teardown (issue 0002)
exit
EOF
DISPLAY="$DISPLAY" timeout 40 "$XSCHEM" --pipe -q --logdir "$LOGDIR" --script "$RECD" >/dev/null 2>&1

LOG="$LOGDIR/Xschem.log"
[ -f "$LOG" ] && ok "record produced a log" || bad "record produced no log"

# the log must hold exactly the replayable commands the actions emit
if grep -qx "xschem zoom_in"  "$LOG" 2>/dev/null; then ok "log has zoom_in";  else bad "log missing zoom_in"; fi
if grep -qx "xschem zoom_out" "$LOG" 2>/dev/null; then ok "log has zoom_out"; else bad "log missing zoom_out"; fi
if grep -qx "xschem toggle_colorscheme" "$LOG" 2>/dev/null; then ok "log has toggle_colorscheme"; else bad "log missing toggle_colorscheme"; fi

# the recorded actions actually moved the view (guard against a vacuous pass:
# a no-op session would record zoomxform==1 and still "match" on replay)
XF=$(sed -n 's/^zoomxform //p' "$REC")
if [ -n "$XF" ] && [ "$XF" != "1" ]; then ok "actions changed the zoom (xform=$XF)"
else bad "actions did not change the zoom (vacuous: xform=$XF)"; fi

# --- REPLAY driver: fresh process, same fixture, source the log --------------
cat > "$REPD" <<EOF
set ::SNAP "$REP"
xschem load $FIXTURE
set ::z0 [xschem get zoom]             ;# this process's own post-load baseline
uplevel #0 [list source "$LOG"]        ;# replay the recorded session
update idletasks
$SNAP
exit
EOF
DISPLAY="$DISPLAY" timeout 40 "$XSCHEM" --pipe -q --nolog --script "$REPD" >/dev/null 2>&1
[ -f "$REP" ] && ok "replay produced a snapshot" || bad "replay produced no snapshot"

# --- DIFF --------------------------------------------------------------------
if diff -u "$REC" "$REP" >/dev/null 2>&1; then
  ok "replayed state matches recorded state"
else
  bad "replayed state DIFFERS from recorded state"
  echo "--- recorded:"; sed 's/^/    /' "$REC"
  echo "--- replayed:"; sed 's/^/    /' "$REP"
fi

if [ "$fail" -eq 0 ]; then echo "RESULT: ALL PASS"; else echo "RESULT: $fail FAILED"; fi
[ "$fail" -eq 0 ]
