#!/bin/bash
# test_gui_gate_revive.sh — self-test for the GUI-test gate's MID-SUITE panel
# recovery (tests/headless/gui_gate.sh + gui_gate_widget.tcl).
# Run from anywhere:  tests/headless/test_gui_gate_revive.sh
#
# WHY THIS EXISTS (2026-07-30). WSLg's Xwayland aborted on its own three times
# in one nine-hour session — "(EE) request could not be marshaled: can't send
# file descriptor", SIGABRT, weston logged `xserver exited, code 134`. Every X
# client died with it, and a Tk client dies badly: libX11's default I/O error
# handler just exit(1)s and Tk installs none, so WM_DELETE_WINDOW never fires,
# on_close never runs, and the panel leaves a stale widget.pid behind.
#
# Two of those aborts landed BETWEEN suites and nobody noticed — the next
# gate_start quietly rebuilt the panel. The third landed 3 minutes INTO a
# 150-run soak, and _gate_ensure_widget was reachable only from gate_start, so
# the panel stayed dead: 27 minutes of GUI flood with a Pause button that no
# longer existed. That is the exact failure this whole gate was built to
# prevent, so it gets a test.
#
# Arms:
#   SHELL  G1..G3   fail-open + the pid-identity check (no DISPLAY needed)
#   LIVE   G4..G10  real panel: revive, repeat-revive, Pause-after-rebirth,
#                   the forensic trail, and fail-open when wish will not start
#   WIDGET W1..W2   a revive with nothing pending must NOT grab focus
#
# Uses a throwaway GUI_GATE_DIR: the real ~/.claude/gui_test_gate is untouched.

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# THESE SUITES TEST THE GATE, so they must run where the gate is LIVE. The
# persistent dev display deliberately disables it (gui_gate.sh
# _gate_dev_display -- a panel on an invisible display is useless, and worse,
# _gate_attention would relaunch the user's real panel there). On that display
# every gate assertion here fails for the wrong reason: measured 6 failures on
# :99 against 0 on any other display. So relocate rather than mislead.
if [ -n "${DISPLAY:-}" ] && [ "${XSCHEM_GATE_SELFTEST_ARM:-0}" != 1 ] && \
   [ "$DISPLAY" = "$(cat "${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}/display" 2>/dev/null)" ] && \
   command -v xvfb-run >/dev/null 2>&1; then
  echo "-- on the dev display, where the gate is disabled BY DESIGN; re-execing on a private Xvfb" >&2
  export XSCHEM_GATE_SELFTEST_ARM=1
  exec xvfb-run -a -s "-screen 0 1280x1024x24" bash "$0" "$@"
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0
ck()   { if [ "$2" = "1" ];   then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS+1)); fi; }
eqck() { if [ "$2" = "$3" ];  then echo "ok   $1"; else echo "FAIL $1 (got '$2' want '$3')"; FAILS=$((FAILS+1)); fi; }

# a stand-in suite: gate_start, then N pause points one second apart
cat > "$TMP/fakesuite.sh" <<'EOF'
#!/bin/bash
set -u
. "$SELFDIR/gui_gate.sh"
gate_start "selftest suite" || { echo SUITE_STOPPED_AT_START; exit 3; }
for i in $(seq 1 "$STEPS"); do
  gate_pause_point "selftest | step $i of $STEPS" || { echo SUITE_STOPPED; gate_finish; exit 3; }
  echo "step $i"
  sleep 1
done
gate_finish
echo SUITE_DONE
EOF
chmod +x "$TMP/fakesuite.sh"

echo "=== SHELL arm ==="

# G1/G2 fail open — a gate that can wedge the suite is worse than no gate
out="$(GUI_GATE=0 GUI_GATE_DIR="$TMP/g1" SELFDIR="$SELF" STEPS=2 bash "$TMP/fakesuite.sh" 2>/dev/null)"; rc=$?
eqck "G1 GUI_GATE=0 -> suite runs" "$(echo "$out" | tail -1)" "SUITE_DONE"
eqck "G1 exit 0" "$rc" "0"
out="$(env -u DISPLAY GUI_GATE_DIR="$TMP/g2" SELFDIR="$SELF" STEPS=2 bash "$TMP/fakesuite.sh" 2>/dev/null)"; rc=$?
eqck "G2 no DISPLAY -> suite runs" "$(echo "$out" | tail -1)" "SUITE_DONE"
eqck "G2 exit 0" "$rc" "0"

# G3 IDENTITY, not just liveness. A widget.pid outlives both the process and the
# boot, and pids recycle — so a stale file naming a live but innocent process
# must read as DEAD. Believing it would be unrecoverable: no panel would ever
# launch and gate_start would spin forever, and _gate_attention would SIGKILL a
# bystander.
G3="$TMP/g3"; mkdir -p "$G3/req" "$G3/status"
sleep 120 & IMPOSTOR=$!
printf '%s' "$IMPOSTOR" > "$G3/widget.pid"
( export GUI_GATE_DIR="$G3"; . "$SELF/gui_gate.sh"
  _gate_widget_alive && exit 0 || exit 1 ) 2>/dev/null
alive_rc=$?
kill "$IMPOSTOR" 2>/dev/null; wait "$IMPOSTOR" 2>/dev/null
ck "G3 a live non-panel pid in widget.pid reads as DEAD" \
   "$([ "$alive_rc" != "0" ] && echo 1 || echo 0)"

echo "=== PENDING arm (v6: a launch into an X server that is not there yet) ==="
# WHY (2026-08-04). The revive logged "FAILED -- suite continues UNGATED" SEVEN
# times in one day, always exactly 3 s after "death detected". Those 3 s were
# never wish's: WSLg dies two ways, and in the bad one weston itself SIGABRTs,
# WSLGd restarts the compositor, and the fresh weston binds :0 IMMEDIATELY but
# spawns Xwayland lazily -- 2.83/2.89/2.91/2.91/3.05 s later, once 54.4 s. wish
# launched into that window does NOT fail: connect() succeeds, the handshake
# never completes, and it blocks with no stderr and no pidfile (measured: 25 s
# silent; 269 s against a display with no listener). The gate declared failure
# at the exact moment the X server was being created, then LEAKED that wish --
# one of them wrote its pidfile 134.2 s later and became a real, unsupervised
# panel.
#
# The stub below is that wish: alive, silent, no pidfile, for as long as we
# like. Reproducing it by killing weston would take down the user's desktop and
# every X client on the box -- precisely what this gate exists to prevent.
STUB="$TMP/stub"; mkdir -p "$STUB"
cat > "$STUB/wish" <<'EOF'
#!/bin/sh
# stub `wish`: $1 = widget script, $2 = gate dir. Writes the pidfile after
# `stub_delay` tenths of a second ("never" = never), like a wish stuck in the X
# handshake. argv keeps gui_gate_widget.tcl, so the gate's identity check sees
# it exactly as it sees the real panel.
trap 'exit 0' TERM INT
d="$(cat "$2/stub_delay" 2>/dev/null || echo never)"
i=0
while [ "$i" -lt 3000 ]; do
  if [ "$d" != "never" ] && [ "$i" = "$d" ]; then printf '%s' "$$" > "$2/widget.pid"; fi
  i=$((i + 1)); sleep 0.1
done
EOF
chmod +x "$STUB/wish"

panel_procs() { pgrep -f "gui_gate_widget[.]tcl $1\$" 2>/dev/null | wc -l | tr -d ' '; }

# THE orphan test. "No orphan" does not mean "no wish": a revive that reaps a
# stuck launch is allowed to try again at once, and that retry is a live wish.
# It means no wish that NOBODY IS TRACKING -- the 2026-08-04 leak, where a
# "FAILED" launch left a process that mapped a panel 134 s later with no file on
# disk naming it. Anything not in widget.pid and not in widget.launching is one.
untracked_procs() {
  local d="$1" p wp lp u=0
  wp="$(cat "$d/widget.pid" 2>/dev/null)"
  lp="$(cut -d' ' -f1 "$d/widget.launching" 2>/dev/null)"
  for p in $(pgrep -f "gui_gate_widget[.]tcl $d\$" 2>/dev/null); do
    [ "$p" = "$wp" ] && continue
    [ "$p" = "$lp" ] && continue
    u=$((u + 1))
  done
  echo "$u"
}

kill_panels() {   # kill every stub for a dir and WAIT for them to go
  local d="$1" i
  pkill -f "gui_gate_widget[.]tcl $d\$" 2>/dev/null || true
  for i in $(seq 1 50); do [ "$(panel_procs "$d")" = "0" ] && return 0; sleep 0.1; done
  return 0
}

# run gui_gate.sh code against a throwaway dir with the stub as `wish` and a
# DISPLAY that does not exist (nothing here ever touches the real X server)
in_gate() {   # $1 = gate dir, rest = shell code
  local d="$1"; shift
  ( export GUI_GATE_DIR="$d" DISPLAY=:99 PATH="$STUB:$PATH" \
           GUI_GATE_REVIVE_EVERY="${REVIVE_EVERY:-1}" \
           GUI_GATE_PENDING_DEADLINE="${PEND_DEADLINE:-180}"
    . "$SELF/gui_gate.sh"
    eval "$@" ) 2>/dev/null
}

# X1 a launch that connects LATE is ADOPTED, not abandoned -- exactly one panel
X1="$TMP/x1"; mkdir -p "$X1/req" "$X1/status"
printf '%s' 40 > "$X1/stub_delay"          # pidfile at 4.0 s: past the 3 s poll
printf '%s' 999999999 > "$X1/widget.pid"   # crashed panel: stale pid, dead
in_gate "$X1" '_gate_revive_widget; echo rc=$?' > "$TMP/x1.out"
eqck "X1 the 3 s fast path does not claim success" "$(cat "$TMP/x1.out")" "rc=1"
ck   "X1 ...and does not claim FAILURE either (PENDING)" \
     "$(grep -q 'launch PENDING' "$X1/events.log" && echo 1 || echo 0)"
ck   "X1 the in-flight wish is TRACKED (widget.launching)" \
     "$([ -f "$X1/widget.launching" ] && echo 1 || echo 0)"
ck   "X1 the corpse is kept as widget.pid.crashed, not deleted" \
     "$([ -f "$X1/widget.pid.crashed" ] && echo 1 || echo 0)"
eqck "X1 exactly one wish was forked" "$(panel_procs "$X1")" "1"
eqck "X1 ...and it is TRACKED, not leaked" "$(untracked_procs "$X1")" "0"
# a later pause point must adopt it
sleep 3
in_gate "$X1" 'gate_pause_point "later"; echo rc=$?' >/dev/null
ck   "X1 the late panel is ADOPTED at a later pause point" \
     "$(grep -q 'revived late' "$X1/events.log" && echo 1 || echo 0)"
ck   "X1 ...widget.pid now names it" \
     "$(in_gate "$X1" '_gate_widget_alive && echo 1 || echo 0' | tail -1)"
eqck "X1 ...still exactly one wish (no second launch)" "$(panel_procs "$X1")" "1"
ck   "X1 ...and the markers are cleared" \
     "$([ ! -f "$X1/widget.launching" ] && [ ! -f "$X1/widget.pid.crashed" ] && echo 1 || echo 0)"
eqck "X1 ...nothing untracked left behind" "$(untracked_procs "$X1")" "0"
kill_panels "$X1"

# X2 a launch that NEVER connects is reaped at the deadline -- NO ORPHAN
X2="$TMP/x2"; mkdir -p "$X2/req" "$X2/status"
printf '%s' never > "$X2/stub_delay"
printf '%s' 999999999 > "$X2/widget.pid"
PEND_DEADLINE=4 in_gate "$X2" '_gate_revive_widget' >/dev/null
eqck "X2 a stuck launch is pending, one wish alive" "$(panel_procs "$X2")" "1"
STUCK="$(cut -d' ' -f1 "$X2/widget.launching" 2>/dev/null)"
sleep 5
PEND_DEADLINE=4 in_gate "$X2" 'gate_pause_point "later"' >/dev/null
ck   "X2 the stuck wish is REAPED at the deadline" \
     "$(grep -q 'launch abandoned' "$X2/events.log" && echo 1 || echo 0)"
ck   "X2 ...the abandoned wish is really dead" \
     "$([ -n "$STUCK" ] && ! kill -0 "$STUCK" 2>/dev/null && echo 1 || echo 0)"
eqck "X2 ...and nothing untracked survives it" "$(untracked_procs "$X2")" "0"
# and the run is NOT silenced afterwards: v4/v5 deleted widget.pid before every
# launch, so one failure tripped the deliberate-close guard and killed every
# later attempt for the rest of the run -- with no log line at all.
printf '%s' 5 > "$X2/stub_delay"
sleep 1
PEND_DEADLINE=180 in_gate "$X2" '_gate_revive_widget' >/dev/null
ck   "X2 a LATER revive still runs (a failed attempt does not silence the run)" \
     "$([ "$(grep -c 'death detected' "$X2/events.log")" -ge 2 ] && echo 1 || echo 0)"
kill_panels "$X2"

# X3 the subtlest rule: a DELIBERATE CLOSE leaves no marker, and no marker must
# mean no relaunch -- ever. Get this wrong and the panel resurrects itself every
# time the user closes it.
X3="$TMP/x3"; mkdir -p "$X3/req" "$X3/status"
printf '%s' 5 > "$X3/stub_delay"
in_gate "$X3" 'for i in 1 2 3 4 5; do gate_pause_point "p$i"; done' >/dev/null
eqck "X3 no markers -> NO panel is launched (deliberate close honoured)" \
     "$(panel_procs "$X3")" "0"
ck   "X3 ...and nothing was even attempted" \
     "$([ ! -f "$X3/events.log" ] || ! grep -q 'death detected' "$X3/events.log" && echo 1 || echo 0)"
# ...including a close that lands DURING a failed revive: on_close deletes all
# three markers, so what it leaves behind is the same "no marker" state.
printf '%s' never > "$X3/stub_delay"
printf '%s' 999999999 > "$X3/widget.pid"
PEND_DEADLINE=3 in_gate "$X3" '_gate_revive_widget' >/dev/null
kill_panels "$X3"
rm -f "$X3/widget.pid" "$X3/widget.pid.crashed" "$X3/widget.launching"   # <- on_close
printf '%s' 5 > "$X3/stub_delay"
in_gate "$X3" 'for i in 1 2 3 4 5; do gate_pause_point "p$i"; done' >/dev/null
eqck "X3 a close DURING a failed revive is still a close" "$(panel_procs "$X3")" "0"

# X4 two suites reviving in the same instant: one launch, never two panels
X4="$TMP/x4"; mkdir -p "$X4/req" "$X4/status"
printf '%s' 40 > "$X4/stub_delay"
printf '%s' 999999999 > "$X4/widget.pid"
in_gate "$X4" '_gate_revive_widget' >/dev/null &
R1=$!
in_gate "$X4" '_gate_revive_widget' >/dev/null &
R2=$!
wait "$R1" "$R2" 2>/dev/null
eqck "X4 two racing revivers fork exactly ONE wish" "$(panel_procs "$X4")" "1"
eqck "X4 ...and only one of them announced a revive" \
     "$(grep -c 'death detected' "$X4/events.log" 2>/dev/null)" "1"
eqck "X4 ...and the loser left nothing untracked" "$(untracked_procs "$X4")" "0"
kill_panels "$X4"

# X5 the lock cannot wedge the gate: an owner that was SIGKILLed must not stop
# every other suite from ever reviving again.
X5="$TMP/x5"; mkdir -p "$X5/req" "$X5/status/"
printf '%s' 5 > "$X5/stub_delay"; printf '%s' 999999999 > "$X5/widget.pid"
mkdir -p "$X5/revive.lock"; printf '%s %s' 999999999 "$(date +%s)" > "$X5/revive.lock/owner"
in_gate "$X5" '_gate_revive_widget' >/dev/null
sleep 1
eqck "X5 a lock held by a dead owner is broken, the revive proceeds" \
     "$(panel_procs "$X5")" "1"
kill_panels "$X5"

if [ -z "${DISPLAY:-}" ] || ! command -v wish >/dev/null 2>&1; then
  echo "-- no DISPLAY/wish: skipping the live arms"
  echo "RESULT fails=$FAILS"; exit $((FAILS ? 1 : 0))
fi

echo "=== LIVE arm ==="

# G3b the CRASH SIGNATURE, asserted where nothing can race it: a panel killed by
# a signal never runs WM_DELETE_WINDOW, so on_close never deletes widget.pid nor
# rewrites control. That asymmetry is what identified the 2026-07-30 death as an
# X-server abort rather than a window close, so it is worth pinning down.
G3B="$TMP/g3b"; mkdir -p "$G3B/req" "$G3B/status"; printf '%s' PAUSE > "$G3B/control"
( export GUI_GATE_DIR="$G3B"; . "$SELF/gui_gate.sh"; _gate_ensure_widget >/dev/null 2>&1 )
PB="$(cat "$G3B/widget.pid" 2>/dev/null)"
if [ -n "$PB" ] && kill -0 "$PB" 2>/dev/null; then
  kill -9 "$PB" 2>/dev/null
  for i in $(seq 1 40); do kill -0 "$PB" 2>/dev/null || break; sleep 0.1; done
  ck "G3b a signalled panel leaves widget.pid behind (on_close did NOT run)" \
     "$([ -f "$G3B/widget.pid" ] && echo 1 || echo 0)"
  eqck "G3b ...and leaves control untouched" "$(cat "$G3B/control" 2>/dev/null)" "PAUSE"
else
  ck "G3b panel launched for the signature check" "0"
fi
G="$TMP/live"
export GUI_GATE_DIR="$G" GUI_GATE_AUTOSTART=3 GUI_GATE_REVIVE_EVERY=1

# wait for a live panel pid that differs from $1 (empty = any). echoes it, or ""
wait_new_pid() {
  local old="$1" i p
  for i in $(seq 1 "${2:-60}"); do
    p="$(cat "$G/widget.pid" 2>/dev/null)"
    if [ -n "$p" ] && [ "$p" != "$old" ] && kill -0 "$p" 2>/dev/null; then printf '%s' "$p"; return 0; fi
    sleep 0.3
  done
  return 1
}

SELFDIR="$SELF" STEPS=45 bash "$TMP/fakesuite.sh" > "$TMP/suite.out" 2>"$TMP/suite.err" &
SUITE=$!

P1="$(wait_new_pid "" 60)"
ck "G4 gate_start launched a panel" "$([ -n "$P1" ] && echo 1 || echo 0)"

# the suite is released by the 3 s autostart; give it a step or two, then take
# the panel out the way Xwayland did — SIGKILL, no WM_DELETE_WINDOW, stale pid
if [ -n "$P1" ]; then
  while [ ! -s "$G/status/$SUITE" ] && kill -0 "$SUITE" 2>/dev/null; do sleep 0.3; done
  kill -9 "$P1" 2>/dev/null
  # SIGKILL is not synchronous: assert only after the corpse is actually gone,
  # or this reads "still alive" on a loaded box. (The stale-widget.pid half of
  # the crash signature is asserted deterministically in G3b — here the revive
  # legitimately races us for that file.)
  for i in $(seq 1 40); do kill -0 "$P1" 2>/dev/null || break; sleep 0.1; done
  ck "G5 pre-condition: the panel is dead" \
     "$(! kill -0 "$P1" 2>/dev/null && echo 1 || echo 0)"

  # THE regression: nothing but gate_pause_point runs now, and it must notice
  P2="$(wait_new_pid "$P1" 60)"
  ck "G5 a mid-suite panel death is REVIVED by gate_pause_point" \
     "$([ -n "$P2" ] && echo 1 || echo 0)"

  # G6 revive is throttled, never once-only: three aborts in one session
  if [ -n "$P2" ]; then
    kill -9 "$P2" 2>/dev/null
    P3="$(wait_new_pid "$P2" 60)"
    ck "G6 a SECOND death is revived too (not once-only)" \
       "$([ -n "$P3" ] && echo 1 || echo 0)"

    # G7 the reborn panel governs the suite that started before it existed
    if [ -n "$P3" ]; then
      printf '%s' PAUSE > "$G/control"
      before="$(grep -c '^step ' "$TMP/suite.out" 2>/dev/null || echo 0)"
      sleep 4
      after="$(grep -c '^step ' "$TMP/suite.out" 2>/dev/null || echo 0)"
      ck "G7 Pause on the REBORN panel holds the already-running suite" \
         "$([ "$before" = "$after" ] && echo 1 || echo 0)"
      printf '%s' RUN > "$G/control"
      sleep 2
      resumed="$(grep -c '^step ' "$TMP/suite.out" 2>/dev/null || echo 0)"
      ck "G7 Resume releases it again" \
         "$([ "$resumed" -gt "$after" ] && echo 1 || echo 0)"

      # G11 the other half of the rule: a panel the USER CLOSED must stay
      # closed. on_close deletes widget.pid; a crash cannot. Reviving a
      # deliberate close would be the gate arguing with the user, and would
      # turn "get out of the way" into a panel that reappears every second.
      kill -9 "$P3" 2>/dev/null
      for i in $(seq 1 40); do kill -0 "$P3" 2>/dev/null || break; sleep 0.1; done
      rm -f "$G/widget.pid"                     # <- what on_close leaves behind
      sleep 5                                   # several pause points go by
      ck "G11 a panel the user CLOSED is not resurrected" \
         "$([ ! -f "$G/widget.pid" ] && echo 1 || echo 0)"
      ck "G11 ...and the suite kept running anyway (fail open)" \
         "$(kill -0 "$SUITE" 2>/dev/null && echo 1 || echo 0)"
    fi
  fi
fi

printf '%s' STOP > "$G/control"
wait "$SUITE" 2>/dev/null
printf '%s' RUN > "$G/control"

# G8/G9 the forensic trail. events.log is the durable one — widget.log is
# truncated by the very relaunch that a death triggers, which is how the sibling
# review gate ended up with a 0-byte log of a real death.
ck "G8 events.log records the death" \
   "$(grep -q 'death detected' "$G/events.log" 2>/dev/null && echo 1 || echo 0)"
ck "G8 events.log records the revive" \
   "$(grep -q 'panel revived' "$G/events.log" 2>/dev/null && echo 1 || echo 0)"
ck "G9 the panel's stderr is captured, not /dev/null" \
   "$([ -f "$G/widget.log" ] && echo 1 || echo 0)"

# bracketed pattern: a bare `-f gui_gate_widget.tcl` also matches pkill's OWN
# command line and SIGTERMs this script (exit 144). Burned once already.
pkill -f "gui_gate_widget[.]tcl $G" 2>/dev/null || true

# G10 fail open when wish is present but will not stay up: the suite must still
# finish, and must say why.
BADBIN="$TMP/badbin"; mkdir -p "$BADBIN"
printf '#!/bin/sh\nexit 1\n' > "$BADBIN/wish"; chmod +x "$BADBIN/wish"
out="$(PATH="$BADBIN:$PATH" GUI_GATE_DIR="$TMP/g10" GUI_GATE_AUTOSTART=3 \
       SELFDIR="$SELF" STEPS=2 bash "$TMP/fakesuite.sh" 2>"$TMP/g10.err")"; rc=$?
eqck "G10 unlaunchable panel -> suite still completes" "$(echo "$out" | tail -1)" "SUITE_DONE"
eqck "G10 exit 0" "$rc" "0"
ck   "G10 and it says so" \
     "$(grep -q 'panel unavailable' "$TMP/g10.err" && echo 1 || echo 0)"
ck   "G10 launch failure is logged" \
     "$(grep -q 'launch FAILED' "$TMP/g10/events.log" 2>/dev/null && echo 1 || echo 0)"

echo "=== WIDGET arm ==="
# A mid-suite revive has NO pending request. It must come back SILENTLY: the
# panel's `attention` does `focus -force`, which would steal the keyboard from
# the xschem window a running test is driving with `event generate`.
run_widget_arm() {   # $1 label  $2 dir  $3 expected attention calls (0 | 1+)
  local d="$2"
  cat > "$TMP/wa.tcl" <<'EOF'
set argv [list [lindex $::argv 0]]; set argc 1
source gui_gate_widget.tcl
set ::atn 0
proc attention {} { incr ::atn }
proc bgerror {m} { puts "BGERROR: $m"; flush stdout; exit 2 }
after 900 { puts "ATTENTION_CALLS $::atn"; flush stdout; exit 0 }
EOF
  ( cd "$SELF" && timeout 20 wish "$TMP/wa.tcl" "$d" ) 2>/dev/null | grep '^ATTENTION_CALLS' | tail -1
}

WA="$TMP/wa_idle"; mkdir -p "$WA/req" "$WA/status"; printf '%s' RUN > "$WA/control"
got="$(run_widget_arm idle "$WA")"
eqck "W1 revive with nothing pending does NOT grab focus" "$got" "ATTENTION_CALLS 0"

WB="$TMP/wa_req"; mkdir -p "$WB/req" "$WB/status"; printf '%s' RUN > "$WB/control"
printf 'a waiting suite' > "$WB/req/4242"
got="$(run_widget_arm req "$WB")"
n="$(printf '%s' "$got" | awk '{print $2+0}')"
ck "W2 a real go-ahead request still announces itself" \
   "$([ "${n:-0}" -ge 1 ] && echo 1 || echo 0)"

# W3 the panel's half of the deliberate-close rule (v6). The shell revives a
# panel that CRASHED and never one that was CLOSED, and it tells them apart by
# what is left on disk. v6 added two more markers, and EITHER of them left here
# would authorise a revive one pause point after the user closed the panel --
# the endless relaunch loop, the worst regression this file can have.
WC="$TMP/wa_close"; mkdir -p "$WC/req" "$WC/status"; printf '%s' RUN > "$WC/control"
printf '%s %s' 999999999 "$(date +%s)" > "$WC/widget.pid.crashed"
sleep 300 & PENDW=$!            # stands in for a launch still in flight
printf '%s %s' "$PENDW" "$(date +%s)" > "$WC/widget.launching"
cat > "$TMP/wc.tcl" <<'EOF'
set argv [list [lindex $::argv 0]]; set argc 1
source gui_gate_widget.tcl
after 500 { on_close }
EOF
( cd "$SELF" && timeout 20 wish "$TMP/wc.tcl" "$WC" ) >/dev/null 2>&1
ck "W3 a deliberate close clears ALL THREE revive markers" \
   "$([ ! -f "$WC/widget.pid" ] && [ ! -f "$WC/widget.pid.crashed" ] \
      && [ ! -f "$WC/widget.launching" ] && echo 1 || echo 0)"
sleep 0.5
ck "W3 ...and disposes of a launch that was still in flight" \
   "$(! kill -0 "$PENDW" 2>/dev/null && echo 1 || echo 0)"
kill "$PENDW" 2>/dev/null; wait "$PENDW" 2>/dev/null
# and the shell agrees: nothing left to revive from
out="$(GUI_GATE_DIR="$WC" DISPLAY=:99 PATH="$STUB:$PATH" GUI_GATE_REVIVE_EVERY=1 \
       bash -c ". '$SELF/gui_gate.sh'; _gate_revive_widget && echo REVIVED || echo LEFT_ALONE" 2>/dev/null)"
eqck "W3 ...so the shell will not resurrect it" "$out" "LEFT_ALONE"
eqck "W3 ...and forked nothing" "$(panel_procs "$WC")" "0"

echo "RESULT fails=$FAILS"
exit $((FAILS ? 1 : 0))
