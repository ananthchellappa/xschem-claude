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
#
# WHAT IT STARTS, AND WHO KILLS IT (added 2026-08-15, see the R arm at the end).
# This suite forks four kinds of process, and until R landed it reaped one:
#
#   1. gate PANELS. Every fakesuite.sh run reaches gate_start ->
#      _gate_ensure_widget -> _gate_launch_widget, which `setsid`s a
#      `wish gui_gate_widget.tcl <GATE_DIR>` DELIBERATELY detached from the
#      launching process group (the panel is a singleton meant to outlive one
#      suite). Five throwaway control dirs here reach that path: g1, g3, g4, g5,
#      g6. Nothing ever killed them, and `trap 'rm -rf "$TMP"' EXIT` deleted the
#      dirs out from under them -- so every run left a handful of panels polling
#      a directory that no longer existed. Measured: 21 alive, all ~24.3 h old,
#      12% CPU and 269 MB between them.
#   2. WIDGET ARM wishes (widget_arm, `timeout 30 wish $TMP/vN.tcl`), which
#      source the panel and exit on their own -- bounded, but reaped anyway.
#   3. the brake's THROWAWAY TARGETS ($TMP/xschemselftest, the quoted-cmdline
#      sleep), killed explicitly at the end of the widget arm.
#   4. the PRIVATE Xvfb of the re-run just below, whose teardown used to be
#      xvfb-run's own EXIT trap and therefore nobody's under a SIGKILL.
#
# All four are now tracked and reaped BY PID and BY PROVENANCE, never by program
# name -- see tests/headless/spawn_reaper.sh for why `pkill -f
# gui_gate_widget.tcl` would be a bug and not a fix.

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SELF/spawn_reaper.sh"

# BEFORE the private display is chosen, not after: a run that was SIGKILLed
# leaves its private Xvfb serving and its /tmp/.X<n>-lock behind, and the lock
# alone used to make the number look occupied forever -- 60 of them, then the
# launcher returns 127 and this suite exits with no RESULT line at all. The
# sweep reclaims only displays whose OWNING RUN is provably dead (marker file),
# so a concurrent suite's display is never touched, and neither is :99 or :0.
reaper_sweep_orphan_xvfb

# THESE SUITES TEST THE GATE, so they must run where the gate is LIVE. The
# persistent dev display deliberately disables it (gui_gate.sh
# _gate_dev_display -- a panel on an invisible display is useless, and worse,
# _gate_attention would relaunch the user's real panel there). On that display
# every gate assertion here fails for the wrong reason: measured 6 failures on
# :99 against 0 on any other display. So relocate rather than mislead.
#
# WE start that display, so WE tear it down -- see reaper_run_on_private_xvfb,
# which replaced an `exec xvfb-run`. Two things went wrong with delegating it:
# xvfb-run's teardown is its own EXIT trap and therefore nobody's under a
# SIGKILL, and its `clean_up` runs under `set -e` and ends with `kill $XVFBPID`,
# so a session that correctly reaped its own server made xvfb-run exit 1 with
# 57 green checks behind it. Note this is NOT an `exec`: the parent stays alive
# to reap the display if the run under it cannot.
if [ -n "${DISPLAY:-}" ] && [ "${XSCHEM_GATE_SELFTEST_ARM:-0}" != 1 ] && \
   [ "$DISPLAY" = "$(cat "${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}/display" 2>/dev/null)" ] && \
   command -v Xvfb >/dev/null 2>&1; then
  echo "-- on the dev display, where the gate is disabled BY DESIGN; re-running on a private Xvfb" >&2
  export XSCHEM_GATE_SELFTEST_ARM=1
  reaper_run_on_private_xvfb 1280x1024x24 bash "$0" "$@"
  exit $?
fi
TMP="$(mktemp -d)"
# A SECOND scratch root, deliberately outside $TMP: the R arm stands a decoy
# panel in it to stand for "the user's live panel on :0, or another session's".
# It must be invisible to this run's provenance rule, which is exactly what
# being outside $TMP means.
OTHER="$(mktemp -d)"
DECOY=""
# The decoy's OWN pid, held from the fork. $DECOY is read back from
# $OTHER/widget.pid after a poll, and a launch whose pidfile is late or never
# written leaves that empty -- in which case the suite failed R0 and then leaked
# the very panel it started, named by nothing: the decoy lives OUTSIDE $TMP on
# purpose, so provenance cannot see it either. $! costs nothing and covers it.
DPID=""
reaper_init "$TMP" || { echo "RESULT fails=1 (reaper would not arm on $TMP)"; exit 1; }

# Anything left by a run that never got to run its teardown -- SIGKILL, tool
# timeout, a worktree pulled out from under it. A trap cannot cover those, so
# the next run does. TWO proofs, and the second is not optional: a control dir
# under a temp root that is GONE (the shape the pre-fix code left, and how the
# 21 strays were identified), or one that still EXISTS whose `.reaper_owner`
# stamp names a dead run -- which is the only shape THIS code can leave, because
# reaping now happens before the `rm -rf`. Measured: with the first criterion
# alone, a SIGKILLed run's 5 panels were invisible to every later run.
reaper_sweep_orphan_panels

# ONE teardown, on every exit path: normal end, `set -u` abort, an uncaught
# error, INT and TERM. Reaping comes BEFORE `rm -rf "$TMP"`, which is the whole
# story of this bug -- the old trap removed the control dirs and left the
# processes that were reading them.
_teardown() {
  [ -n "${DECOY:-}" ] && reaper_track "$DECOY"
  [ -n "${DPID:-}" ] && reaper_track "$DPID"
  reaper_reap
  rm -rf "$TMP" "$OTHER"
  return 0
}
trap '_teardown' EXIT
trap '_teardown; exit 130' INT
trap '_teardown; exit 143' TERM

# The private display of the re-run above, if that is what we are on. It is
# adopted by PID as well as by name: reaper_own_xvfb refuses :0, refuses the
# persistent dev display named by EITHER state file, and refuses any server this
# run did not itself start -- the last of which no environment variable can
# switch off. So this cannot become a way to kill somebody else's display.
if [ -n "${XSCHEM_REAPER_OWNED_DISPLAY:-}" ] && \
   [ "${XSCHEM_REAPER_OWNED_DISPLAY:-}" = "${DISPLAY:-}" ]; then
  reaper_own_xvfb "$DISPLAY" || true
fi
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

# BF1 "Forever" writes the WORD, not an epoch. The shell must honour it as a
# keyword -- and B4 above must keep passing, i.e. one word in, every other
# non-number still rejected.
G6="$TMP/g6"; mkdir -p "$G6/req" "$G6/status"; printf '%s' RUN > "$G6/control"
printf 'forever' > "$G6/allow_until"
t0=$(date +%s)
out="$(GUI_GATE_DIR="$G6" GUI_GATE_AUTOSTART=120 SELFDIR="$SELF" STEPS=1 \
       timeout 30 bash "$TMP/fakesuite.sh" 2>"$TMP/g6.err")"; rc=$?
el=$(( $(date +%s) - t0 ))
eqck "BF1 suite ran under a forever grant" "$(echo "$out" | tail -1)" "SUITE_DONE"
ck   "BF1 it did NOT wait out the countdown (took ${el}s)" \
     "$([ "$el" -lt 15 ] && echo 1 || echo 0)"
ck   "BF1 no go-ahead request was armed" \
     "$([ -z "$(ls -A "$G6/req" 2>/dev/null)" ] && echo 1 || echo 0)"

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
# Tracked at the fork, not at the teardown: its command line does not mention
# $TMP, so provenance cannot find it and an abort between here and the explicit
# kill below would leave a 200-second sleep behind.
reaper_track "$QUOTEPID"

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
  # V10: "Forever" (the button that replaced "Allow 2h"). An open-ended grant
  # cannot expire mid-batch, which is the failure a fixed window has: it runs
  # out while nobody is at the desk and every later suite pays the autostart
  # countdown.
  .go.a120 invoke
  ck "V10 Forever opened a grant" [grant_live]
  ck "V10 ...recorded as the keyword, not an epoch" [expr {[grant_until] eq "forever"}]
  ck "V10 ...and grant_forever agrees" [grant_forever]
  # The trap: PAUSE pushes a timed window forward so a hold does not burn it.
  # That arithmetic must not touch a forever grant -- doing so would resolve
  # "forever" to a small number and silently downgrade it to seconds.
  set fp [open [file join $G control] w]; puts -nonewline $fp PAUSE; close $fp
  set ::last_tick [expr {[clock seconds] - 30}]
  refresh
  ck "V10 PAUSE does not downgrade a forever grant" [expr {[grant_until] eq "forever"}]
  ck "V10 ...and it is still live" [grant_live]
  set fp [open [file join $G control] w]; puts -nonewline $fp RUN; close $fp
  refresh
  ck "V10 the panel says so, without a countdown" \
     [expr {[string match {*until you Revoke*} [.top.msg cget -text]]}]
  .go.revoke invoke
  ck "V10 Revoke ends a forever grant too" [expr {![grant_live]}]
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
reaper_track "$FAKEPID"
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

echo "=== REAP arm ==="
# THE CHECK THIS SUITE DID NOT HAVE. It passed every one of its own checks while
# leaving 21 gate panels alive for a day, because "did I clean up after myself"
# was never asserted. It is asserted here, and it carries its own positive
# evidence: R1 first proves there was something to reap, so R2 cannot go green
# by the suite having quietly stopped spawning panels.

# A decoy panel standing for THE USER'S LIVE PANEL ON :0 (or a concurrent
# worktree's). Its control dir is outside $TMP, so this run's provenance rule
# must not see it. This is the check that makes `pkill -f gui_gate_widget.tcl`
# impossible to reintroduce: that fix passes R2 and fails R4.
mkdir -p "$OTHER/req" "$OTHER/status"; printf '%s' RUN > "$OTHER/control"
wish "$SELF/gui_gate_widget.tcl" "$OTHER" >"$OTHER/log" 2>&1 &
DPID=$!          # held from the fork; $DECOY below may never arrive
for i in $(seq 1 60); do [ -s "$OTHER/widget.pid" ] && break; sleep 0.1; done
DECOY="$(cat "$OTHER/widget.pid" 2>/dev/null)"
ck "R0 a decoy panel from ANOTHER session is up (pid ${DECOY:-none})" \
   "$([ -n "$DECOY" ] && kill -0 "$DECOY" 2>/dev/null && echo 1 || echo 0)"

n_before="$(reaper_survivors | grep -c . || true)"
ck "R1 this run really did leave processes of its own alive ($n_before)" \
   "$([ "${n_before:-0}" -ge 1 ] && echo 1 || echo 0)"

reaper_reap_procs
n_after="$(reaper_survivors | grep -c . || true)"
eqck "R2 after reaping, nothing this run started is still alive" "${n_after:-?}" "0"

ck "R3 ...and the OTHER session's panel is untouched" \
   "$([ -n "$DECOY" ] && kill -0 "$DECOY" 2>/dev/null && echo 1 || echo 0)"

# A panel that dies lazily is still a leak if the next suite starts before it
# goes, so the zero has to hold once the dust settles, not only in the instant
# after the signal.
sleep 3
n_late="$(reaper_survivors | grep -c . || true)"
eqck "R4 ...still zero 3 s later (no lazy deaths counted as clean)" "${n_late:-?}" "0"

# R6-R9 THE REFUSALS -- the other half of the contract, and until now the half
# no check covered at all. R0-R5 prove the reaper kills what it started; these
# prove it will not touch what it did not. Measured: with both refusals deleted
# from reaper_own_xvfb this file was still 57/57 green, while a three-line probe
# made the reaper adopt the LIVE persistent dev display (pid 901342) -- one
# reaper_reap_xvfb away from taking every other suite on this machine down.
#
# Each refusal runs in a SUBSHELL. If one wrongly SUCCEEDED it would leave
# _REAPER_XVFB_PID naming somebody else's server, and the teardown would then
# shoot it -- a check that causes the damage it is testing for is not a check.
#
# THE REASON IS ASSERTED, NOT ONLY THE RETURN CODE, and that is not pedantry:
# there is no Xvfb on :0 on this box, so `reaper_own_xvfb :0` would fail for the
# uninteresting reason ("no Xvfb serving") with the :0 guard deleted, and a check
# reading rc alone would stay green through the sabotage aimed at it. A refusal
# has to refuse for the right reason to be worth anything.
rmsg="$( ( reaper_own_xvfb ':0' ) 2>&1 )"; rc=$?
ck "R6 reaper_own_xvfb REFUSES :0 AS the user's screen" \
   "$([ "$rc" -ne 0 ] && case "$rmsg" in *"user's screen"*) echo 1 ;; *) echo 0 ;; esac || echo 0)"

# ...and refuses the dev display even with the state file it consults REDIRECTED
# AWAY, which is not hypothetical: test_devdisplay.sh exports exactly that
# redirection for its whole run and sources the reaper. The refusal that holds
# here is "this run did not start it", which no environment variable can move.
DEVDPY="$(cat "$HOME/.claude/xschem_dev_display/display" 2>/dev/null)"
[ -n "$DEVDPY" ] || DEVDPY=":99"
rmsg="$( ( XSCHEM_DEVDISPLAY_DIR="$TMP/no_such_state_dir"; reaper_own_xvfb "$DEVDPY" ) 2>&1 )"; rc=$?
ck "R7 ...and REFUSES the dev display ($DEVDPY) AS SUCH with its state dir redirected away" \
   "$([ "$rc" -ne 0 ] && case "$rmsg" in *"persistent dev display"*) echo 1 ;; *) echo 0 ;; esac || echo 0)"

# The provenance arm has its own refusal: pointed at a non-temp root it would
# match half the processes on a developer box by their command lines.
( reaper_init "$HOME" ) >/dev/null 2>&1; rc=$?
ck "R8 reaper_init REFUSES a non-temp prefix (\$HOME)" \
   "$([ "$rc" -ne 0 ] && echo 1 || echo 0)"

# An innocent process that merely MENTIONS Xvfb and a display number. The first
# version of the identification asked whether those two strings appeared
# anywhere in a command line, and a reviewer got it to adopt -- and kill -- a
# plain sleep, and before that a tool shell. An X server is argv[0]=Xvfb,
# argv[1]=:<n>; nothing else is.
IMPNUM=""
for n in $(seq 141 160); do
  [ -e "/tmp/.X$n-lock" ] && continue
  ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$n\b" && continue
  IMPNUM="$n"; break
done
if [ -n "$IMPNUM" ]; then
  bash -c 'sleep 60; :' Xvfb ":$IMPNUM" >/dev/null 2>&1 & IMP=$!
  reaper_track "$IMP"
  ( reaper_own_xvfb ":$IMPNUM" ) >/dev/null 2>&1; rc=$?
  ck "R9 an impostor whose command line merely says 'Xvfb :$IMPNUM' is not adopted" \
     "$([ "$rc" -ne 0 ] && kill -0 "$IMP" 2>/dev/null && echo 1 || echo 0)"
else
  ck "R9 an impostor whose command line merely says Xvfb is not adopted (no free number)" 0
fi

# R11 THE SWEEP, which is the only cover the SIGKILL path has -- no trap runs
# then, so the next run has to do it. Both halves matter and neither is
# hypothetical: the first criterion (control dir GONE) selects exactly the
# strays the OLD code produced, and NONE of the ones the fixed code can produce,
# because reaping now happens BEFORE `rm -rf "$TMP"` and a hard-killed run
# leaves its dirs standing. Without the owner stamp the sweep would be a
# one-time historical cleanup dressed up as a forward net.
DEADPID=999999; while [ -e "/proc/$DEADPID" ]; do DEADPID=$((DEADPID + 1)); done
ORPHDIR="$(mktemp -d)"; mkdir -p "$ORPHDIR/req" "$ORPHDIR/status"
printf '%s' RUN > "$ORPHDIR/control"
printf '%s %s\n' "$DEADPID" 1 > "$ORPHDIR/.reaper_owner"   # a run that is gone
wish "$SELF/gui_gate_widget.tcl" "$ORPHDIR" >"$ORPHDIR/log" 2>&1 & ORPHPID=$!
reaper_track "$ORPHPID"          # if the sweep does not take it, the teardown must
for i in $(seq 1 60); do [ -s "$ORPHDIR/widget.pid" ] && break; sleep 0.1; done
reaper_sweep_orphan_panels
for i in $(seq 1 40); do kill -0 "$ORPHPID" 2>/dev/null || break; sleep 0.1; done
ck "R11 a panel whose dir SURVIVES but whose run is provably dead is swept" \
   "$(kill -0 "$ORPHPID" 2>/dev/null && echo 0 || echo 1)"
# The negative control is the decoy, standing right there through the same
# sweep: its dir exists and carries no stamp at all, so there is no proof it is
# an orphan, so it is not touched. "No evidence" must never mean "kill it".
ck "R11 ...and a panel with no owner stamp at all is left strictly alone" \
   "$([ -n "$DECOY" ] && kill -0 "$DECOY" 2>/dev/null && echo 1 || echo 0)"
rm -rf "$ORPHDIR"

# R12 the same, for the process class the ORIGINAL STRAY BELONGED TO. An X
# server outlives the run that made it just as a panel does -- the pair recorded
# on this box was `Xvfb :95` and an openbox, 24 h old -- and until now nothing
# reclaimed one: the panel sweep matches panels only, and the leftover
# /tmp/.X<n>-lock then burned the number for every future run.
XN=""
for n in $(seq 160 -1 150); do
  [ -e "/tmp/.X$n-lock" ] && continue
  ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$n\b" && continue
  XN="$n"; break
done
if [ -n "$XN" ] && command -v Xvfb >/dev/null 2>&1; then
  Xvfb ":$XN" -screen 0 640x480x24 -nolisten tcp >/dev/null 2>&1 & XPID=$!
  reaper_track "$XPID"
  for i in $(seq 1 100); do
    ss -xl 2>/dev/null | grep -q "@/tmp/\.X11-unix/X$XN\b" && break; sleep 0.1
  done
  printf '%s %s %s\n' "$XPID" "$DEADPID" 1 > "${TMPDIR:-/tmp}/.reaper_xvfb.$XN"
  reaper_sweep_orphan_xvfb
  for i in $(seq 1 40); do kill -0 "$XPID" 2>/dev/null || break; sleep 0.1; done
  ck "R12 a private display whose run is dead is reclaimed (:$XN pid $XPID)" \
     "$(kill -0 "$XPID" 2>/dev/null && echo 0 || echo 1)"
  # Tidy up only what is provably finished -- the same rule the reaper itself
  # follows. Dropping the lock of a server that is still serving advertises a
  # busy display number as free, and under a sabotaged reaper (where this check
  # is red anyway) that is exactly the state this block would create.
  if kill -0 "$XPID" 2>/dev/null; then
    _reaper_say "R12: :$XN pid $XPID survived the sweep — marker and lock left in place"
  else
    rm -f "${TMPDIR:-/tmp}/.reaper_xvfb.$XN" "/tmp/.X$XN-lock"
  fi
  # ...and the display THIS run is sitting on went through the very same sweep
  # untouched: either its marker names an owner that is alive (the private one),
  # or it has no marker at all (a borrowed one, or :99).
  ck "R12 ...while the display this run is on (${DISPLAY:-none}) still answers" \
     "$(xdpyinfo -display "${DISPLAY:-:0}" >/dev/null 2>&1 && echo 1 || echo 0)"
else
  ck "R12 a private display whose run is dead is reclaimed (no free number)" 0
  ck "R12 ...while the display this run is on still answers (not reached)" 0
fi

# The decoy has served its purpose; it is ours, so we take it with us -- by the
# pid we held from the fork as well as the one it wrote down.
reaper_track "$DECOY"; reaper_track "$DPID"; reaper_reap_procs
ck "R10 the decoy is gone, by the pid held at the fork and not only its pidfile" \
   "$([ -n "$DPID" ] && ! kill -0 "$DPID" 2>/dev/null && echo 1 || echo 0)"
DECOY=""; DPID=""

# THE PRIVATE X SERVER, LAST OF ALL -- and the ordering is load-bearing. Every
# check above runs clients on this display (the decoy, the sweep's throwaway
# panels), and an X server's death takes every client with it: with this block
# where it used to be, R11's negative control failed because the decoy had
# already died with :101, not because anything killed it wrongly. A teardown
# check must be the last thing that runs, or it silently answers the questions
# after it. Two arms, one assertion each, so the check count does not depend on
# how the suite was launched.
if reaper_owns_xvfb; then
  xp="$(reaper_xvfb_pid)"
  reaper_reap_xvfb
  ck "R5 the private Xvfb this run started ($DISPLAY pid $xp) is gone" \
     "$(reaper_xvfb_alive && echo 0 || echo 1)"
else
  # We did not start this display, so the contract is the opposite one: leave it
  # exactly as we found it. Asserted by it still answering.
  borrowed_ok=0
  if [ -z "${DISPLAY:-}" ]; then
    borrowed_ok=1                       # nothing to borrow, nothing to break
  elif ! command -v xdpyinfo >/dev/null 2>&1; then
    command -v wish >/dev/null 2>&1 && borrowed_ok=1
  elif xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    borrowed_ok=1
  fi
  ck "R5 a BORROWED display (${DISPLAY:-none}) is left running, never reaped" "$borrowed_ok"
fi

echo "RESULT fails=$FAILS"
exit $((FAILS ? 1 : 0))
