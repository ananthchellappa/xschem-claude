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

echo "RESULT fails=$FAILS"
exit $((FAILS ? 1 : 0))
