#!/bin/bash
# test_review_gate.sh — self-test for the review gate (review_gate.sh +
# review_gate_widget.tcl). Run from anywhere:  tools/review_gate/test_review_gate.sh
#
# Two arms:
#   SHELL  (T1..T7)  the blocking script: fail-open, timeout, verdicts, hold
#   WIDGET (B1..B13, S1..S3) the Tk panel's procs, driven by `invoke` rather
#                    than by a human click, plus three sabotage legs
#
# The widget arm needs $DISPLAY and pops a short-lived panel. Without DISPLAY it
# is skipped, and the shell arm degrades to its fail-open legs — the same rule
# the gate itself follows.

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0
ck() { if [ "$2" = "1" ]; then echo "ok   $1"; else echo "FAIL $1"; FAILS=$((FAILS+1)); fi; }
eqck() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got '$2' want '$3')"; FAILS=$((FAILS+1)); fi; }

echo "=== SHELL arm ==="

# T1/T2 fail open: a gate that can wedge the build loop is worse than no gate
out="$(REVIEW_GATE=0 "$SELF/review_gate.sh" --dir "$TMP/g1" --label T1 2>/dev/null)"; rc=$?
eqck "T1 REVIEW_GATE=0 -> NOGATE" "$(echo "$out" | head -1)" "DECISION: NOGATE"
eqck "T1 exit 0" "$rc" "0"
out="$(env -u DISPLAY "$SELF/review_gate.sh" --dir "$TMP/g2" --label T2 2>/dev/null)"; rc=$?
eqck "T2 no DISPLAY -> NOGATE" "$(echo "$out" | head -1)" "DECISION: NOGATE"
eqck "T2 exit 0" "$rc" "0"

if [ -z "${DISPLAY:-}" ] || ! command -v wish >/dev/null 2>&1; then
  echo "-- no DISPLAY/wish: skipping the live arms"
  echo "RESULT fails=$FAILS"; exit $((FAILS ? 1 : 0))
fi

G="$TMP/live"
printf 'body detail\n' > "$TMP/body.md"

# T3 the timeout must self-release: an item finished at 02:00 cannot stall
# until morning
t0=$(date +%s)
out="$("$SELF/review_gate.sh" --dir "$G" --label "T3 timeout" --body-file "$TMP/body.md" \
        --timeout 5 --out "$TMP/o3" 2>/dev/null)"; rc=$?
el=$(( $(date +%s) - t0 ))
eqck "T3 timeout -> TIMEOUT" "$(echo "$out" | head -1)" "DECISION: TIMEOUT"
eqck "T3 exit 0" "$rc" "0"
ck   "T3 released in ~5s (got ${el}s)" "$([ "$el" -ge 4 ] && [ "$el" -le 12 ] && echo 1 || echo 0)"
ck   "T3 --out file written" "$([ -f "$TMP/o3" ] && echo 1 || echo 0)"

reply_when_ready() {   # $1 verdict  $2 notes
  local i id
  for i in $(seq 1 80); do
    id=$(ls "$G/req" 2>/dev/null | head -1)
    if [ -n "$id" ]; then
      printf '%s\n%s' "$1" "$2" > "$G/reply/$id.t"; mv "$G/reply/$id.t" "$G/reply/$id"; return 0
    fi
    sleep 0.3
  done
  return 1
}

# T4 PROCEED carries the user's notes back to the builder
( sleep 1; reply_when_ready PROCEED "bump legend 1.2x" ) &
out="$("$SELF/review_gate.sh" --dir "$G" --label "T4 proceed" --timeout 60 2>/dev/null)"; rc=$?
wait
eqck "T4 -> PROCEED" "$(echo "$out" | head -1)" "DECISION: PROCEED"
eqck "T4 exit 0" "$rc" "0"
eqck "T4 notes returned" "$(echo "$out" | tail -1)" "bump legend 1.2x"

# T5 STOP is the one verdict that must NOT be exit 0 — it halts the loop
( sleep 1; reply_when_ready STOP "wait for me" ) &
out="$("$SELF/review_gate.sh" --dir "$G" --label "T5 stop" --timeout 60 2>/dev/null)"; rc=$?
wait
eqck "T5 -> STOP" "$(echo "$out" | head -1)" "DECISION: STOP"
eqck "T5 exit 3" "$rc" "3"

# T6 hold is the ONLY state that blocks past the deadline
( for i in $(seq 1 80); do id=$(ls "$G/req" 2>/dev/null|head -1)
    [ -n "$id" ] && { touch "$G/hold/$id"; break; }; sleep 0.2; done
  sleep 7
  id=$(ls "$G/req" 2>/dev/null|head -1)
  [ -n "$id" ] && echo HELD_OK > "$TMP/held" || echo HELD_BROKEN > "$TMP/held"
  rm -f "$G/hold/$id" ) &
t0=$(date +%s)
out="$("$SELF/review_gate.sh" --dir "$G" --label "T6 hold" --timeout 3 2>/dev/null)"; rc=$?
wait
el=$(( $(date +%s) - t0 ))
eqck "T6 hold froze the countdown" "$(cat "$TMP/held" 2>/dev/null)" "HELD_OK"
ck   "T6 released only after un-hold (${el}s > 3s timeout)" "$([ "$el" -gt 6 ] && echo 1 || echo 0)"
eqck "T6 -> TIMEOUT" "$(echo "$out" | head -1)" "DECISION: TIMEOUT"

# T7 the control dir is left clean — a stray req file would block the next run
n=$(ls "$G"/req "$G"/body "$G"/hold "$G"/deadline "$G"/reply 2>/dev/null | grep -cv '^$\|:$')
eqck "T7 no leftovers in the control dir" "$n" "0"

# T8 a panel that dies mid-wait is RELAUNCHED, not treated as "review over".
# This is not hypothetical: the panel died on its own during the first real
# use of the gate, the wait ended NOGATE, and the item went unreviewed with no
# trace of why (wish's output was going to /dev/null). Both halves are fixed —
# the relaunch here, and widget.log below.
G2="$TMP/revive"
( for i in $(seq 1 80); do
    id=$(ls "$G2/req" 2>/dev/null | head -1)
    if [ -n "$id" ]; then
      p1=$(cat "$G2/widget.pid" 2>/dev/null)
      kill -9 "$p1" 2>/dev/null; rm -f "$G2/widget.pid"     # panel dies hard
      for j in $(seq 1 60); do
        p2=$(cat "$G2/widget.pid" 2>/dev/null)
        if [ -n "$p2" ] && [ "$p2" != "$p1" ] && kill -0 "$p2" 2>/dev/null; then
          echo REVIVED > "$TMP/revive.flag"; break
        fi
        sleep 0.3
      done
      # answer through the NEW panel, proving the request survived the death
      printf 'PROCEED\nafter revival' > "$G2/reply/$id.t"; mv "$G2/reply/$id.t" "$G2/reply/$id"
      return 0 2>/dev/null || exit 0
    fi
    sleep 0.3
  done ) &
out="$("$SELF/review_gate.sh" --dir "$G2" --label "T8 revive" --timeout 90 2>/dev/null)"; rc=$?
wait
eqck "T8 a killed panel is relaunched, not abandoned" "$(cat "$TMP/revive.flag" 2>/dev/null)" "REVIVED"
eqck "T8 the request survived the death -> PROCEED, not NOGATE" \
  "$(echo "$out" | head -1)" "DECISION: PROCEED"
eqck "T8 exit 0" "$rc" "0"
eqck "T8 the notes typed after revival came back" "$(echo "$out" | tail -1)" "after revival"
ck "T8 the panel's output is captured for diagnosis, not /dev/null" \
  "$([ -f "$G2/widget.log" ] && echo 1 || echo 0)"

echo "=== WIDGET arm ==="
W="$TMP/w"; mkdir -p "$W"/{req,body,reply,hold,deadline}
printf 'BTN item' > "$W/req/777"; printf 'body' > "$W/body/777"
cat > "$TMP/p1.tcl" <<'EOF'
set argv [list [lindex $::argv 0]]; set argc 1
source review_gate_widget.tcl
set G [lindex $::argv 0]; set fails 0
proc bgerror {m} { puts "BGERROR: $m"; flush stdout; exit 2 }
proc ck {n ok} { global fails
  if {$ok} { puts "ok   $n" } else { puts "FAIL $n"; incr fails }; flush stdout }
proc arm {id l} { global G
  set f [open [file join $G req $id] w]; puts -nonewline $f $l; close $f; refresh }
proc rd {f} { set p [open $f r]; set t [read $p]; close $p; return $t }
after 600 {
  refresh
  .btns.hold invoke
  ck "B1 hold file created" [file exists [file join $G hold 777]]
  refresh
  ck "B2 hold relabels to Un-hold" [expr {[.btns.hold cget -text] eq "Un-hold"}]
  .btns.hold invoke
  ck "B3 un-hold removes the file" [expr {![file exists [file join $G hold 777]]}]
  refresh
  ck "B4 relabels back to Hold" [string match "Hold*" [.btns.hold cget -text]]
  .notes insert end "legend 1.2x please"
  .btns.go invoke
  set r [file join $G reply 777]
  ck "B5 proceed wrote a reply" [file exists $r]
  set txt [rd $r]
  ck "B6 verdict is PROCEED" [expr {[lindex [split $txt \n] 0] eq "PROCEED"}]
  ck "B7 notes round-tripped" [expr {[lindex [split $txt \n] 1] eq "legend 1.2x please"}]
  ck "B8 notes box cleared" [expr {[string trim [.notes get 1.0 end]] eq ""}]
  ck "B9 deadline cleaned" [expr {![file exists [file join $G deadline 777]]}]
  file delete $r [file join $G req 777]
  arm 778 second
  .btns.stop invoke
  ck "B10 stop verdict is STOP" [expr {[lindex [split [rd [file join $G reply 778]] \n] 0] eq "STOP"}]
  puts "WFAILS $fails"; flush stdout
  exit [expr {$fails ? 1 : 0}]
}
EOF
( cd "$SELF" && timeout 40 wish "$TMP/p1.tcl" "$W" ) | tee "$TMP/w1.out"
ck "widget arm 1 (B1..B10) green" "$(grep -q '^WFAILS 0$' "$TMP/w1.out" && echo 1 || echo 0)"
grep -c '^FAIL' "$TMP/w1.out" >/dev/null

# on_close calls exit, which `catch` cannot stop — so the close/idle/sabotage
# legs need exit and destroy stubbed and run in their own process.
W2="$TMP/w2"; mkdir -p "$W2"/{req,body,reply,hold,deadline}
cat > "$TMP/p2.tcl" <<'EOF'
set argv [list [lindex $::argv 0]]; set argc 1
source review_gate_widget.tcl
set G [lindex $::argv 0]; set fails 0
rename exit real_exit
proc exit {{c 0}} { set ::exited 1 }
rename destroy real_destroy
proc destroy {args} { set ::destroyed 1 }
proc bgerror {m} { puts "BGERROR: $m"; flush stdout; real_exit 2 }
proc ck {n ok} { global fails
  if {$ok} { puts "ok   $n" } else { puts "FAIL $n"; incr fails }; flush stdout }
proc arm {id l} { global G
  set f [open [file join $G req $id] w]; puts -nonewline $f $l; close $f; refresh }
proc rd {f} { set p [open $f r]; set t [read $p]; close $p; return $t }
after 600 {
  arm 779 third
  on_close
  set r3 [file join $G reply 779]
  ck "B11 close replies to pending" [file exists $r3]
  ck "B12 close verdict is PROCEED" [expr {[file exists $r3] && [lindex [split [rd $r3] \n] 0] eq "PROCEED"}]
  ck "B12b close removed the pid file" [expr {![file exists [file join $G widget.pid]]}]
  file delete $r3 [file join $G req 779]
  refresh
  ck "B13 idle disables Proceed" [expr {[.btns.go cget -state] eq "disabled"}]
  # SABOTAGE: nothing pending -> a forced Proceed must write NO reply. Red if
  # do_reply ever writes a fixed path instead of iterating pending().
  .btns.go configure -state normal
  .notes insert end "never delivered"
  .btns.go invoke
  ck "S1 no pending -> no reply written" \
     [expr {[llength [glob -nocomplain -directory [file join $G reply] *]] == 0}]
  # SABOTAGE: the shell polls for reply/<id>, so a half-written file would be
  # read as a truncated verdict. No .tmp may survive.
  arm 780 fourth
  .btns.go invoke
  ck "S2 reply written" [file exists [file join $G reply 780]]
  ck "S3 no .tmp left behind" \
     [expr {[llength [glob -nocomplain -directory [file join $G reply] *.tmp*]] == 0}]
  puts "WFAILS $fails"; flush stdout
  real_exit [expr {$fails ? 1 : 0}]
}
EOF
( cd "$SELF" && timeout 40 wish "$TMP/p2.tcl" "$W2" ) | tee "$TMP/w2.out"
ck "widget arm 2 (B11..S3) green" "$(grep -q '^WFAILS 0$' "$TMP/w2.out" && echo 1 || echo 0)"

echo "RESULT fails=$FAILS"
exit $((FAILS ? 1 : 0))
