#!/bin/bash
# test_gui_gate_batch.sh — self-test for the GUI-test gate's v5 additions:
# the approval window ("batch the batches"), the snooze read-back, the
# interrupted-suite trap, and the hard brake over ungated xschem processes.
# Run from anywhere:  tests/headless/test_gui_gate_batch.sh
#
# WHY THE APPROVAL WINDOW EXISTS: the gate warned before EVERY suite, which is
# right for one big run and wrong for how testing actually happens — forty tiny
# suites of a couple of seconds each meant forty Proceed presses, or, with
# nobody at the desk, forty two-minute autostart waits to run two minutes of
# tests. The gate cost an order of magnitude more time than the tests it
# guarded. "Allow 30m"/"Allow 2h" opens a window in which suites start without
# asking, while Pause and Stop keep working throughout.
#
# Arms:
#   SHELL  B1..B7   grant honoured / counted / expires / malformed; the trap;
#                   gated_xschem.sh fail-open
#   WIDGET V1..V8   snooze adoption, stale-status sweep, do_allow/do_revoke,
#                   and the brake (aimed at a throwaway process, never at a
#                   real xschem — see GUI_GATE_BRAKE_NAME)
#
# Uses a throwaway GUI_GATE_DIR: the real ~/.claude/gui_test_gate is untouched.

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0
ck()   { if [ "$2" = "1" ];  then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS+1)); fi; }
eqck() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got '$2' want '$3')"; FAILS=$((FAILS+1)); fi; }

cat > "$TMP/fakesuite.sh" <<'EOF'
#!/bin/bash
set -u
. "$SELFDIR/gui_gate.sh"
gate_start "batch selftest" || { echo SUITE_STOPPED_AT_START; exit 3; }
echo GATE_START_RETURNED
for i in $(seq 1 "$STEPS"); do
  gate_pause_point "batch selftest | step $i" || { echo SUITE_STOPPED; gate_finish; exit 3; }
  echo "step $i"
  sleep 1
done
gate_finish
echo SUITE_DONE
EOF

echo "=== SHELL arm ==="

if [ -z "${DISPLAY:-}" ] || ! command -v wish >/dev/null 2>&1; then
  echo "-- no DISPLAY/wish: the gate is disabled entirely, nothing to test"
  echo "RESULT fails=0"; exit 0
fi

# B1 THE HEADLINE: with an approval window open, gate_start must return AT ONCE
# and must not arm a request at all. Before this, each suite cost either a click
# or a 2-minute autostart wait.
G1="$TMP/g1"; mkdir -p "$G1/req" "$G1/status"
printf '%s' RUN > "$G1/control"
printf '%s' "$(( $(date +%s) + 600 ))" > "$G1/allow_until"
t0=$(date +%s)
out="$(GUI_GATE_DIR="$G1" GUI_GATE_AUTOSTART=120 SELFDIR="$SELF" STEPS=1 \
       timeout 30 bash "$TMP/fakesuite.sh" 2>"$TMP/g1.err")"; rc=$?
el=$(( $(date +%s) - t0 ))
eqck "B1 suite ran under the approval window" "$(echo "$out" | tail -1)" "SUITE_DONE"
eqck "B1 exit 0" "$rc" "0"
ck   "B1 it did NOT wait out the 120s countdown (took ${el}s)" \
     "$([ "$el" -lt 15 ] && echo 1 || echo 0)"
ck   "B1 no go-ahead request was ever armed" \
     "$([ -z "$(ls -A "$G1/req" 2>/dev/null)" ] && echo 1 || echo 0)"
ck   "B1 and it said so on stderr" \
     "$(grep -q 'approved batch window' "$TMP/g1.err" && echo 1 || echo 0)"

# B2 the panel's "n suites have run" counter
eqck "B2 grant_count incremented" "$(cat "$G1/grant_count" 2>/dev/null)" "1"
GUI_GATE_DIR="$G1" SELFDIR="$SELF" STEPS=1 timeout 30 bash "$TMP/fakesuite.sh" >/dev/null 2>&1
eqck "B2 ...and again for the next suite" "$(cat "$G1/grant_count" 2>/dev/null)" "2"

# B3 an EXPIRED window must not silently keep approving
G3="$TMP/g3"; mkdir -p "$G3/req" "$G3/status"; printf '%s' RUN > "$G3/control"
printf '%s' "$(( $(date +%s) - 60 ))" > "$G3/allow_until"
t0=$(date +%s)
out="$(GUI_GATE_DIR="$G3" GUI_GATE_AUTOSTART=4 SELFDIR="$SELF" STEPS=1 \
       timeout 60 bash "$TMP/fakesuite.sh" 2>/dev/null)"
el=$(( $(date +%s) - t0 ))
eqck "B3 expired window -> suite still runs (via autostart)" "$(echo "$out" | tail -1)" "SUITE_DONE"
ck   "B3 ...but it had to WAIT for it (${el}s >= 4s)" \
     "$([ "$el" -ge 4 ] && echo 1 || echo 0)"

# B4 a corrupt allow_until is not a blank cheque
G4="$TMP/g4"; mkdir -p "$G4/req" "$G4/status"; printf '%s' RUN > "$G4/control"
printf 'yes please' > "$G4/allow_until"
t0=$(date +%s)
out="$(GUI_GATE_DIR="$G4" GUI_GATE_AUTOSTART=4 SELFDIR="$SELF" STEPS=1 \
       timeout 60 bash "$TMP/fakesuite.sh" 2>/dev/null)"
el=$(( $(date +%s) - t0 ))
ck "B4 garbage in allow_until is ignored, not honoured" \
   "$([ "$el" -ge 4 ] && echo 1 || echo 0)"

# B5 the trap: an INTERRUPTED suite must not orphan status/<pid>. An orphan
# makes the panel list a phantom suite AND blocks STOP from self-clearing,
# which silently restores the "one Stop breaks every future suite" bug.
G5="$TMP/g5"; mkdir -p "$G5/req" "$G5/status"; printf '%s' RUN > "$G5/control"
printf '%s' "$(( $(date +%s) + 600 ))" > "$G5/allow_until"
GUI_GATE_DIR="$G5" SELFDIR="$SELF" STEPS=30 bash "$TMP/fakesuite.sh" >/dev/null 2>&1 &
SP=$!
for i in $(seq 1 60); do [ -n "$(ls -A "$G5/status" 2>/dev/null)" ] && break; sleep 0.3; done
ck "B5 pre-condition: a status file exists while running" \
   "$([ -n "$(ls -A "$G5/status" 2>/dev/null)" ] && echo 1 || echo 0)"
kill -INT "$SP" 2>/dev/null
wait "$SP" 2>/dev/null
sleep 1
ck "B5 an interrupted suite cleans up its status file" \
   "$([ -z "$(ls -A "$G5/status" 2>/dev/null)" ] && echo 1 || echo 0)"

# B6/B7 gated_xschem.sh — the enrolment wrapper for bare loops
out="$(GUI_GATE=0 XSCHEM=/bin/echo "$SELF/gated_xschem.sh" hello-from-wrapper 2>/dev/null)"; rc=$?
eqck "B6 gated_xschem passes args through to the binary" "$out" "hello-from-wrapper"
eqck "B6 ...and returns its exit status" "$rc" "0"
GUI_GATE=0 XSCHEM=/bin/false "$SELF/gated_xschem.sh" >/dev/null 2>&1; rc=$?
eqck "B7 a failing binary's status is propagated, not swallowed" "$rc" "1"

echo "=== WIDGET arm ==="
# The brake is aimed at a THROWAWAY process name. Never point the self-test at
# the real "xschem": it would SIGSTOP the user's actual windows.
FAKE="$TMP/xschemselftest"
cp "$(command -v sleep)" "$FAKE"

# stderr is MERGED, never discarded: the first version of this harness swallowed
# it, and a fatal Tcl error in the panel showed up only as three silent empty
# arms with no clue why.
widget_arm() {   # $1 dir  $2 tcl-body-file
  ( cd "$SELF" && GUI_GATE_BRAKE_NAME=xschemselftest timeout 30 wish "$2" "$1" ) 2>&1
}

# A long-lived process with a QUOTE in its command line. /proc/<pid>/cmdline is
# arbitrary text, and the brake's scanner used to `lindex` it as a Tcl list —
# which throws on the first unbalanced quote it meets, inside refresh, killing
# the panel outright. Most command lines on a developer box contain quotes.
bash -c 'sleep 200' "don't" >/dev/null 2>&1 & QUOTEPID=$!

# --- V1/V2 snooze read-back, V5/V6 allow/revoke, V3 stale-status sweep
W="$TMP/w1"; mkdir -p "$W/req" "$W/status"; printf '%s' RUN > "$W/control"
printf '%s' "$(( $(date +%s) + 1800 )) snooze" > "$W/snooze_until"
printf 'a waiting suite' > "$W/req/4242"
# a pid that provably does not exist right now
PHANTOM=999999
while [ -e "/proc/$PHANTOM" ]; do PHANTOM=$((PHANTOM + 1)); done
export PHANTOM
printf 'phantom suite' > "$W/status/$PHANTOM"
cat > "$TMP/v1.tcl" <<'EOF'
set argv [list [lindex $::argv 0]]; set argc 1
source gui_gate_widget.tcl
set G [lindex $::argv 0]; set fails 0
proc bgerror {m} { puts "BGERROR: $m"; flush stdout; exit 2 }
proc ck {n ok} { global fails
  if {$ok} { puts "ok   $n" } else { puts "FAIL $n"; incr fails }; flush stdout }
after 500 {
  # V1: a 30-minute snooze written before this process started must SURVIVE the
  # relaunch. It used to be write-only, so every relaunch silently downgraded it
  # to a fresh 2-minute autostart.
  ck "V1 a future snooze_until is adopted at startup" [expr {$::deadline > [clock seconds] + 1500}]
  ck "V1 ...and is labelled a snooze, not an autostart" [expr {$::deadline_kind eq "snooze"}]
  refresh
  # V3: the phantom status file must be swept
  ck "V3 a status file whose pid is gone is swept" \
     [expr {![file exists [file join $G status $::env(PHANTOM)]]}]
  # V5: Allow opens the window, zeroes the counter, and releases what waits
  .go.a30 invoke
  ck "V5 do_allow opened an approval window" [grant_live]
  ck "V5 ...for about 30 minutes" \
     [expr {[grant_until] - [clock seconds] > 1700 && [grant_until] - [clock seconds] <= 1800}]
  ck "V5 ...reset the counter" [expr {[grant_count] == 0}]
  ck "V5 ...and released the waiting suite" [expr {[llength [pending_reqs]] == 0}]
  refresh
  ck "V5 Revoke becomes available" [expr {[.go.revoke cget -state] eq "normal"}]
  # V6: Revoke closes it again
  .go.revoke invoke
  ck "V6 do_revoke closes the window" [expr {![grant_live]}]
  refresh
  ck "V6 ...and Revoke goes back to disabled" [expr {[.go.revoke cget -state] eq "disabled"}]
  puts "WFAILS $fails"; flush stdout
  exit [expr {$fails ? 1 : 0}]
}
EOF
widget_arm "$W" "$TMP/v1.tcl" | tee "$TMP/v1.out"
ck "widget arm 1 (V1/V3/V5/V6) green" \
   "$(grep -q '^WFAILS 0$' "$TMP/v1.out" && echo 1 || echo 0)"

# --- V2 a STALE snooze must not be adopted
W2="$TMP/w2"; mkdir -p "$W2/req" "$W2/status"; printf '%s' RUN > "$W2/control"
printf '%s' "$(( $(date +%s) - 300 )) snooze" > "$W2/snooze_until"
cat > "$TMP/v2.tcl" <<'EOF'
set argv [list [lindex $::argv 0]]; set argc 1
source gui_gate_widget.tcl
set fails 0
proc bgerror {m} { puts "BGERROR: $m"; flush stdout; exit 2 }
proc ck {n ok} { global fails
  if {$ok} { puts "ok   $n" } else { puts "FAIL $n"; incr fails }; flush stdout }
after 400 {
  ck "V2 an EXPIRED snooze_until is not adopted" [expr {$::deadline == 0}]
  # V9 the scanner must survive a command line containing a quote (there is one
  # running right now, planted by the harness), and refresh must not throw.
  ck "V9 the /proc scan survives a quoted command line" \
     [expr {![catch {xschem_procs}]}]
  ck "V9 ...and so does a full refresh tick" [expr {![catch {refresh_body}]}]
  # V10 the poll loop must re-arm even when the body throws, or the panel keeps
  # its pid and window while silently no longer reading req/ or control.
  rename refresh_body real_refresh_body
  set ::throwcount 0
  proc refresh_body {} { incr ::throwcount; error "deliberate" }
  refresh
  after 1000 {
    rename refresh_body {} ; rename real_refresh_body refresh_body
    # ~1 s at 300 ms a tick. If the re-arm sat AFTER the throw point (as it
    # did), the loop dies at the first throw and this stops at 1.
    ck "V10 a throwing refresh_body still re-arms the loop ($::throwcount ticks)" \
       [expr {$::throwcount >= 3}]
    ck "V10 ...and the panel is still alive to say so" [winfo exists .]
    puts "WFAILS $fails"; flush stdout
    exit [expr {$fails ? 1 : 0}]
  }
}
EOF
widget_arm "$W2" "$TMP/v2.tcl" | tee "$TMP/v2.out"
ck "widget arm 2 (V2) green" "$(grep -q '^WFAILS 0$' "$TMP/v2.out" && echo 1 || echo 0)"

# --- V4/V7/V8 the brake
W3="$TMP/w3"; mkdir -p "$W3/req" "$W3/status"; printf '%s' RUN > "$W3/control"
"$FAKE" 120 & FAKEPID=$!
export SELFTEST_PID="$FAKEPID"
cat > "$TMP/v3.tcl" <<'EOF'
set argv [list [lindex $::argv 0]]; set argc 1
source gui_gate_widget.tcl
set fails 0
proc bgerror {m} { puts "BGERROR: $m"; flush stdout; exit 2 }
proc ck {n ok} { global fails
  if {$ok} { puts "ok   $n" } else { puts "FAIL $n"; incr fails }; flush stdout }
proc state_of {p} {
  foreach e [xschem_procs] { if {[lindex $e 0] eq $p} { return [lindex $e 2] } }
  return "gone"
}
set target $::env(SELFTEST_PID)
after 500 {
  ck "V4 an ungated process is found by the brake" \
     [expr {[state_of $target] ne "gone"}]
  refresh
  ck "V4 ...and is listed as UNGATED" \
     [expr {[string first "UNGATED" [.status get 1.0 end]] >= 0}]
  ck "V4 ...with the Halt button live" [expr {[.run.halt cget -state] eq "normal"}]
  # V7 halt, then resume
  do_toggle_halt
  after 300 {
    ck "V7 Halt SIGSTOPs it" [expr {[state_of $target] eq "T"}]
    refresh
    ck "V7 ...the button flips to Resume" \
       [expr {[string first "Resume" [.run.halt cget -text]] >= 0}]
    ck "V7 ...and Kill becomes available" [expr {[.run.kill cget -state] eq "normal"}]
    do_toggle_halt
    after 300 {
      ck "V7 Resume SIGCONTs it" [expr {[state_of $target] ne "T" && [state_of $target] ne "gone"}]
      # V8 Kill must be confirmed. Answer "no" -> nothing dies.
      proc tk_messageBox {args} { return no }
      do_kill_xschem
      after 300 {
        ck "V8 declining the Kill confirmation leaves it alive" \
           [expr {[state_of $target] ne "gone"}]
        puts "WFAILS $fails"; flush stdout
        exit [expr {$fails ? 1 : 0}]
      }
    }
  }
}
EOF
widget_arm "$W3" "$TMP/v3.tcl" | tee "$TMP/v3.out"
ck "widget arm 3 (V4/V7/V8 brake) green" \
   "$(grep -q '^WFAILS 0$' "$TMP/v3.out" && echo 1 || echo 0)"
kill -CONT "$FAKEPID" 2>/dev/null; kill -9 "$FAKEPID" 2>/dev/null; wait "$FAKEPID" 2>/dev/null
kill -9 "$QUOTEPID" 2>/dev/null; wait "$QUOTEPID" 2>/dev/null

echo "RESULT fails=$FAILS"
exit $((FAILS ? 1 : 0))
