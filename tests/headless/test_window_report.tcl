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

# ⚠ THE LOG IS THE SINK NOW, so the content rows read the FILE. They used to read the
# pane copy, which was only ever a proxy for it -- and when the census moved to
# `log_action -noecho` (fourteen lines of forensics per viewer-open was unusable in a
# CIW) that proxy went to zero and took five content rows with it. Reading the real
# sink means these rows survive the next change of mind about the pane.
proc logrows {tag} {
  global logf
  set fd [open $logf r] ; set body [read $fd] ; close $fd
  set out {}
  foreach l [split [string trimright $body \n] \n] {
    if {[string match "#= *" $l]} { lappend out [string range $l 3 end] }
  }
  # the census for ONE call: the header line carrying $tag, and every indented row
  # after it up to the next header.
  set res {} ; set on 0
  foreach l $out {
    if {[string match "window_report *" $l]} { set on [string match "window_report $tag *" $l] }
    if {$on} { lappend res $l }
  }
  return $res
}

set n [window_report probe1]
check "W2 it reports something" [expr {$n > 0}] "(lines=$n)"
set rows1 [logrows probe1]
check "W3 every reported line reached the LOG" [expr {[llength $rows1] == $n}] "([llength $rows1] vs $n)"
check "W4 the header names the current window and cellview" \
  [string match {window_report probe1 current_win_path=*current_name=*readonly=*} [lindex $rows1 0]] \
  "(=> [lindex $rows1 0])"
check "W5 the main toplevel is listed" \
  [regexp {\n\s+\.\s+stack=} "\n[join $rows1 \n]"] {}

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
set row [lsearch -inline -glob [logrows probe2] {*.wrprobe*}]
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

# ⚠ NO COPY IN THE PANE AT ALL, while the log is available. The census is SEVEN lines
# and wviewer::open takes two of them 700ms apart, so mirroring it put fourteen lines of
# forensics into the user's CIW on every waveform open -- the user's own verdict on
# reading it was that it was clutter. `log_action -noecho` writes the file and skips the
# mirror. Two earlier versions of this proc got the pane count wrong in the OTHER
# direction (echo AND log printed everything twice), so the count is asserted, never
# the source.
#
# This is a NEGATIVE row and it has two positive twins, without which it would pass on a
# window_report that had simply stopped working: W10b (the same call really did reach the
# log) and W11 (the fallback echo still fires when the log cannot take it).
set ::echoed {}
set n4 [window_report probe4]
check "W10 NO pane copy while the log is available (it would be clutter, not signal)" \
  [expr {[llength $::echoed] == 0}] "([llength $::echoed] echoed vs $n4 reported)"
check "W10b ... and that same call still reached the log in full" \
  [expr {[llength [logrows probe4]] == $n4 && $n4 > 0}] "([llength [logrows probe4]] vs $n4)"

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

puts [expr {$::fail == 0 ? "RESULT: ALL PASS (14 checks)" : "RESULT: $::fail FAILED"}]
flush stdout
exit [expr {$::fail != 0}]
