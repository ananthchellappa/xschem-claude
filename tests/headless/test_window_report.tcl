# window_report -- the one-word window census the user types in the CIW when the
# viewer/design arrangement looks wrong (issues 0647, 0840, 0844 are all RACES, and
# prose written afterwards cannot say which toplevel was where).
#
# Needs Tk and a log file:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_window_report.tcl

set ::fail 0
proc check {n ok {d {}}} {
  if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d" ; incr ::fail }
}
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; toplevels are the subject)" ; flush stdout ; exit 0 }
# The action log is HALF the subject -- the census exists to land in it -- so a run
# without one is not a pass with two rows quietly missing, it is a run that cannot
# answer the question. Say so and stop.
set logf {}
catch {set logf [xschem get actionlog_filename]}
if {$logf eq {} || ![file isfile $logf]} {
  puts "RESULT: SKIP (needs --logdir; the action log is what the census is for)"
  flush stdout ; exit 0
}

check "W1 window_report exists" [expr {[llength [info commands window_report]] == 1}]

# capture what it echoes, without disturbing the real pane
set ::echoed {}
if {[llength [info commands ciw_echo]]} { rename ciw_echo _real_ciw_echo }
proc ciw_echo {line {tag {}}} { lappend ::echoed $line ; catch {_real_ciw_echo $line $tag} }

set n [window_report probe1]
check "W2 it reports something" [expr {$n > 0}] "(lines=$n)"
check "W3 the echoed count matches the return" [expr {[llength $::echoed] == $n}] "([llength $::echoed] vs $n)"
# the pane copy arrives through the action-log MIRROR, so it carries the `#= ` comment
# prefix; the fallback copy (no log, or logging suppressed) does not. Accept either --
# the row is about the header's CONTENT, and W9 is what guards the prefix.
check "W4 the header names the current window and cellview" \
  [string match {*window_report probe1 current_win_path=*current_name=*readonly=*} [lindex $::echoed 0]] \
  "(=> [lindex $::echoed 0])"
check "W5 the main toplevel is listed" [expr {[llength [lsearch -all -inline -glob $::echoed {*  .   *}]] >= 0 && \
  [regexp {\n?\s+\.\s+stack=} "\n[join $::echoed \n]"]}] {}

# ⚠ AN UNMAPPED TOPLEVEL MUST STILL APPEAR. `wm stackorder` lists only MAPPED windows,
# so a withdrawn one is absent from it -- and a window that has gone missing is exactly
# the thing being investigated. Dropping it would make the census silent about the one
# state the user is chasing, so it prints `stack=-` instead.
toplevel .wrprobe
wm withdraw .wrprobe
wm title .wrprobe {wr probe}
update idletasks
set ::echoed {}
window_report probe2
set row [lsearch -inline -glob $::echoed {*.wrprobe*}]
check "W6 a WITHDRAWN toplevel is still listed" [expr {$row ne {}}] "(=> $row)"
check "W7 ... and it is marked as out of the stack, not given a position" \
  [expr {[string match {*stack=-*} $row] && [string match {*withdrawn*} $row]}] "(=> $row)"
destroy .wrprobe

# every line must reach the action log as a NON-REPLAYABLE `#= ` comment: the log is
# source-able, and a census line is not a command.
set fd [open $logf r] ; set body [read $fd] ; close $fd
set loglines [split [string trimright $body \n] \n]
set hits [lsearch -all -inline -glob $loglines {#= window_report probe2*}]
check "W8 the census reaches the action log" [expr {[llength $hits] == 1}] "(=> $hits)"
set bare [lsearch -all -inline -glob $loglines {window_report *}]
check "W9 ... only as a comment, never as a replayable line" [expr {[llength $bare] == 0}] "(=> $bare)"

# ⚠ EXACTLY ONE COPY IN THE PANE. log_action MIRRORS what it writes into the CIW
# (src/util.c log_action_echo), so a proc that echoes AND logs prints the whole census
# twice -- which is what the first version of window_report did, caught by W3.
set ::echoed {}
set n4 [window_report probe4]
check "W10 one pane copy per line, not two (the log mirrors what it writes)" \
  [expr {[llength $::echoed] == $n4}] "([llength $::echoed] echoed vs $n4 reported)"

# the FALLBACK, measured rather than asserted at source level: with logging suppressed
# the mirror says nothing, so the direct echo must carry it -- still exactly once.
set before [llength $loglines]
xschem log_action -suppress push
set ::echoed {}
set nrep [window_report probe5]
xschem log_action -suppress pop
check "W11 with logging suppressed the pane copy still arrives" \
  [expr {[llength $::echoed] == $nrep && $nrep > 0}] "([llength $::echoed] vs $nrep)"
set fd [open $logf r] ; set body2 [read $fd] ; close $fd
check "W12 ... and nothing was written to the log while suppressed" \
  [expr {[string first {probe5} $body2] < 0}] {}

# it must survive a session with no CIW at all -- the census is most wanted when the
# window arrangement is broken, which is not the moment to raise.
rename ciw_echo {}
if {[llength [info commands _real_ciw_echo]]} { rename _real_ciw_echo ciw_echo }
rename ciw_echo _hidden_ciw_echo
set rc {}
check "W13 it survives with no ciw_echo in the interpreter" \
  [expr {![catch {window_report probe3} rc] && $rc > 0}] "(rc=$rc)"
rename _hidden_ciw_echo ciw_echo

puts [expr {$::fail == 0 ? "RESULT: ALL PASS (13 checks)" : "RESULT: $::fail FAILED"}]
flush stdout
exit [expr {$::fail != 0}]
