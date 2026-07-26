# CIW action-log transcript coverage (issue 0129 + its ordering follow-up).
#
# All in src/ciw.tcl:
#   Fix A (ciw_exec): a `exit`/`quit` typed in the CIW terminates the process before the post-eval
#     log-write, so it was never recorded. ciw_exec now logs an exit/quit command BEFORE the eval;
#     the line-buffered stream flushes it on the newline, so the record survives the process death.
#   Fix B (ciw_capture_puts + ciw_log_outcome): console `puts` output was never written to the file
#     (ciw_echo touches only the pane). Now ciw_capture_puts BUFFERS console output in
#     ::ciw_out_pending, and ciw_log_outcome emits, IN CONSOLE ORDER, the COMMAND line first, then
#     the buffered output, then the result -- so the transcript reads top-to-bottom (command above
#     its output), not output-before-command.
#
# ciw_capture_puts / ciw_log_outcome are callable headless (procs load under --nogui), so Fix B and
# the ORDERING are exercised directly; ciw_exec reads a Tk widget so its exit path is tested via a
# child that really exits, and its wiring is grep-guarded.
#
# Run from the repo ROOT (or via run_regression.tcl):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ciw_actionlog_output.tcl
# Prints "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set bin  [info nameofexecutable]
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set workroot [test_scratch ciw_actionlog_work]
set childn 0

# Run an inner script in a fresh CHILD xschem with a private --logdir; return the RAW action-log body.
proc run_child {inner} {
  global bin workroot childn
  set d [file join $workroot c[incr childn]]
  file mkdir $d
  set sf [file join $d inner.tcl]
  set fd [open $sf w]; puts $fd $inner; close $fd
  catch {exec $bin --nogui --pipe -q --logdir $d --script $sf 2>@1}
  set lf [file join $d Xschem.log]
  if {![file exists $lf]} { return "" }
  set rf [open $lf r]; set body [read $rf]; close $rf
  return $body
}
proc first_idx {body pat} {
  set i 0
  foreach ln [split $body \n] { if {[string first $pat $ln] >= 0} { return $i }; incr i }
  return -1
}
proc has {body pat}      { return [expr {[first_idx $body $pat] >= 0}] }
proc before {body a b}   { set ia [first_idx $body $a]; set ib [first_idx $body $b]
                           return [expr {$ia >= 0 && $ib >= 0 && $ia < $ib}] }

# =====================================================================
# Fix B + ordering: ciw_capture_puts buffers, ciw_log_outcome emits COMMAND then OUTPUT then RESULT
# =====================================================================
# each scenario mirrors one ciw_exec command: `-reset` clears the self-log dedup flag at the
# START (as ciw_exec line ~235 does), then a possible puts buffers, then ciw_log_outcome emits.
set b [run_child {
  # a `set`-style command: result RETURN value, logged AFTER the command line
  xschem log_action -reset; set ::ciw_out_pending {}
  ciw_log_outcome 0 {SETCMD_a} RES_10
  # a `puts`-style command: buffered console output, logged AFTER the command line
  xschem log_action -reset; set ::ciw_out_pending {}
  ciw_capture_puts [list OUT_puts30]
  ciw_log_outcome 0 {PUTSCMD_expr} {}
  # stderr output -> "#! ", still after the command
  xschem log_action -reset; set ::ciw_out_pending {}
  ciw_capture_puts [list stderr ERR_oops]
  ciw_log_outcome 0 {STDERRCMD} {}
  # a CHANNEL puts must NOT be buffered/logged
  xschem log_action -reset; set ::ciw_out_pending {}
  proc ::ciw_saved_puts {args} {}
  ciw_capture_puts [list somechan CHAN_zzz]
  ciw_log_outcome 0 {CHANCMD} {}
  # a FAILED command: "# failed:" comment first, then the error output
  xschem log_action -reset; set ::ciw_out_pending {}
  ciw_log_outcome 1 {FAILCMD} ERRMSG_boom
}]
check_true "child produced an action log" [expr {$b ne {}}]
# presence
check_true {result "#= RES_10" logged}          [has $b "#= RES_10"]
check_true {puts output "#= OUT_puts30" logged}  [has $b "#= OUT_puts30"]
check_true {stderr "#! ERR_oops" logged}         [has $b "#! ERR_oops"]
check_true {failed cmd comment logged}           [has $b "# failed: FAILCMD"]
check_true {failed error "#! ERRMSG_boom" logged} [has $b "#! ERRMSG_boom"]
check_true {channel puts NOT logged}             [expr {![has $b "CHAN_zzz"]}]
# ORDERING: command line strictly BEFORE its output/result (the whole point of the follow-up)
check_true {set: command BEFORE its result}      [before $b "SETCMD_a" "#= RES_10"]
check_true {puts: command BEFORE its output}     [before $b "PUTSCMD_expr" "#= OUT_puts30"]
check_true {stderr: command BEFORE its output}   [before $b "STDERRCMD" "#! ERR_oops"]
check_true {failed: comment BEFORE its error}    [before $b "# failed: FAILCMD" "#! ERRMSG_boom"]

# =====================================================================
# Faithful path: drive a real `puts` command through the actual ciw_exec inner sequence (redefine
# ::puts -> ciw_capture_puts -> eval -> ciw_log_outcome). Guards the "puts returns ''" invariant:
# ciw_capture_puts must return "" so a command ending in puts does not mint a spurious "#= result".
# =====================================================================
set p [run_child {
  xschem log_action -reset
  set ::ciw_out_pending {}
  rename ::puts ::ciw_saved_puts
  proc ::puts {args} {ciw_capture_puts $args}
  set code [catch {uplevel #0 {puts HIFAITHFUL}} res]
  rename ::puts {}; rename ::ciw_saved_puts ::puts
  ciw_log_outcome $code {puts HIFAITHFUL} $res
}]
check_true {faithful puts: command line present}       [has $p "puts HIFAITHFUL"]
check_true {faithful puts: output "#= HIFAITHFUL"}      [has $p "#= HIFAITHFUL"]
check_true {faithful puts: command BEFORE its output}   [before $p "puts HIFAITHFUL" "#= HIFAITHFUL"]
check_true {faithful puts: NO spurious result line}     [expr {![has $p "result HIFAITHFUL"]}]

# =====================================================================
# Fix A — an actual `exit` still leaves its line in the log
# =====================================================================
set a [run_child { xschem log_action -noecho {exit} ; exit }]
check_true {`exit` line survives the process exit} [has $a "exit"]
set aq [run_child { xschem log_action -noecho {quit} ; exit }]
check_true {`quit` line survives the process exit} [has $aq "quit"]

# the exact classifier ciw_exec uses to decide what to pre-log
proc is_exit_cmd {c} { return [regexp {^(exit|quit)(\s|$)} $c] }
check_true {classifier: "exit" is exit-like}   [is_exit_cmd exit]
check_true {classifier: "quit" is exit-like}   [is_exit_cmd quit]
check_true {classifier: "exit 0" is exit-like} [is_exit_cmd "exit 0"]
check_true {classifier: "exithhh" is NOT}      [expr {![is_exit_cmd exithhh]}]
check_true {classifier: "set exit 1" is NOT}   [expr {![is_exit_cmd "set exit 1"]}]

# =====================================================================
# Integration grep-guards (ciw_exec reads a Tk widget -> not headless-callable)
# =====================================================================
set src [file join $root src ciw.tcl]
set rc [read [set f [open $src r]]]; close $f
check_true "ciw_exec pre-eval exit guard present" \
  [expr {[regexp {regexp \{\^\(exit\|quit\)} $rc] && [regexp {log_action -noecho \$cmd} $rc]}]
check_true "ciw_capture_puts buffers into ::ciw_out_pending" \
  [expr {[regexp {lappend ::ciw_out_pending result} $rc] && [regexp {lappend ::ciw_out_pending error} $rc]}]
check_true "ciw_log_outcome emits command then buffered output" \
  [expr {[regexp {proc ciw_log_outcome} $rc] && [regexp {foreach \{kind txt\} \$::ciw_out_pending} $rc]}]

# --- verdict ---
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
