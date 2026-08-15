# Action-log coverage -- the stdin REPL and TCP command-server channels record
# to the action log (issue 0003, issue 0071 atom 6).
#
#   stdin -- the built-in Tcl/Tk stdin loop has no eval hook, so xschem.tcl
#     takes the channel over for NON-TTY stdin when the log is open
#     (stdin_repl_setup: dup fd 0, close stdin, park a never-EOF pipe in the
#     freed std-channel slot) and serves a logged read-eval loop.
#     Tested via a CHILD process (this test's own stdin belongs to the
#     harness): commands piped to `--nogui --pipe --logdir` must land in the
#     child's log -- raw on success, '# failed:' comment on error, exactly
#     once for a self-logging `xschem <verb>` (core-log dedup).
#   TCP -- xschem_getdata records after evaluation, same ciw_exec pattern.
#     Tested IN-PROCESS: setup_tcp_xschem + a loopback client socket (the
#     event loop serves the connection while the client vwaits).
#   --script bodies stay unlogged by design (issue 0003 "NOT in scope"):
#     a child run with --script must NOT log the script's commands.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_stdin_tcp_log.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "SKIP: no action log open -- run with --logdir"
  puts "RESULT: SKIP (no log)"
  exit 0
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set XSCHEM [file join $REPO src xschem]
set work /tmp/atom6_stdin_tcp_log_work
file delete -force $work; file mkdir $work

# count EXACT-match lines (glob, no wildcard = exact) in any log file
proc logcountf {f pat} {
  if {[catch {open $f r} fd]} { return -1 }
  set body [read $fd]; close $fd
  set n 0
  foreach line [split $body \n] { if {[string match $pat $line]} { incr n } }
  return $n
}
proc logcount {pat} { return [logcountf [xschem get actionlog_filename] $pat] }

# ---------------------------------------------------------------------------
# 1) STDIN child: piped commands are logged (raw / # failed / dedup-once)
# ---------------------------------------------------------------------------
set cmdf $work/stdin_cmds
set fp [open $cmdf w]
puts $fp "xschem set cadsnap 20"      ;# self-logs at its core -> REPL copy deduped
puts $fp "nonexistent_stdin_zz"       ;# fails -> '# failed:' comment
puts $fp "set stdin_probe_ok 1"       ;# plain Tcl success -> logged raw
puts $fp "exit 0"
close $fp
set clogdir $work/stdin_logdir; file mkdir $clogdir
set rc [catch {exec $XSCHEM --nogui --pipe -q --logdir $clogdir < $cmdf > $work/stdin.out 2> $work/stdin.err} err]
set clog [file join $clogdir Xschem.log]
check "stdin child ran and wrote a log" [file exists $clog] "rc=$rc err=[string range $err 0 80]"
check "stdin: self-logging verb logged EXACTLY once (core-log dedup)" \
  [expr {[logcountf $clog {xschem set cadsnap 20}] == 1}] \
  "n=[logcountf $clog {xschem set cadsnap 20}]"
check "stdin: failing command -> '# failed:' comment" \
  [expr {[logcountf $clog {# failed: nonexistent_stdin_zz}] == 1}]
check "stdin: failing command NOT logged as a live line" \
  [expr {[logcountf $clog {nonexistent_stdin_zz}] == 0}]
check "stdin: plain Tcl success logged raw" \
  [expr {[logcountf $clog {set stdin_probe_ok 1}] == 1}]

# ---------------------------------------------------------------------------
# 2) --script child: script bodies are NOT auto-logged (issue 0003 non-goal)
# ---------------------------------------------------------------------------
set scriptf $work/child_script.tcl
set fp [open $scriptf w]
puts $fp "set script_probe_marker 1"
puts $fp "exit 0"
close $fp
set slogdir $work/script_logdir; file mkdir $slogdir
catch {exec $XSCHEM --nogui --pipe -q --logdir $slogdir --script $scriptf \
         < /dev/null > $work/script.out 2> $work/script.err}
set slog [file join $slogdir Xschem.log]
check "--script child wrote a log" [file exists $slog]
check "--script body is NOT auto-logged" \
  [expr {[logcountf $slog {*script_probe_marker*}] == 0}]

# ---------------------------------------------------------------------------
# 3) TCP in-process: loopback client against our own server
# ---------------------------------------------------------------------------
proc tcp_send {port cmd} {
  set s [socket localhost $port]
  fconfigure $s -blocking 0
  puts $s $cmd
  flush $s
  close $s w                            ;# half-close: server reads to EOF
  set ::tcp_reply {}
  set ::tcp_done 0
  fileevent $s readable [list apply {{s} {
    append ::tcp_reply [read $s]
    if {[eof $s]} { catch {close $s}; set ::tcp_done 1 }
  }} $s]
  set aid [after 5000 {set ::tcp_done timeout}]
  vwait ::tcp_done
  after cancel $aid
  return $::tcp_reply
}
set snap_save [xschem get cadsnap]
# setup_tcp_xschem returns the assigned port on success, 0 on failure; port 0
# asks the OS for any free port
set port 0; set got 0
if {![catch {setup_tcp_xschem 0} r] && $r != 0} { set port $r; set got 1 }
check "TCP server armed (setup_tcp_xschem)" $got "port=$port"
if {$got} {
  # 3a) plain Tcl success -> reply + raw log line
  set c0 [logcount {expr {6*7}}]
  set rep [tcp_send $port {expr {6*7}}]
  check "TCP: command evaluated (reply 42)" [expr {[string trim $rep] eq {42}}] "rep=$rep"
  check "TCP: success logged raw, +1" [expr {[logcount {expr {6*7}}] == $c0 + 1}]

  # 3b) self-logging xschem verb -> EXACTLY one line (dedup)
  set c0 [logcount {xschem set cadsnap 15}]
  tcp_send $port {xschem set cadsnap 15}
  check "TCP: self-logging verb logged EXACTLY once (dedup)" \
    [expr {[logcount {xschem set cadsnap 15}] == $c0 + 1}] \
    "c0=$c0 now=[logcount {xschem set cadsnap 15}]"

  # 3c) failing command -> '# failed:' comment, no live line
  set c0 [logcount {# failed: nonexistent_tcp_zz}]
  tcp_send $port {nonexistent_tcp_zz}
  check "TCP: failing command -> '# failed:' comment" \
    [expr {[logcount {# failed: nonexistent_tcp_zz}] == $c0 + 1}]
  check "TCP: failing command NOT logged live" \
    [expr {[logcount {nonexistent_tcp_zz}] == 0}]

  # 3d) failed MULTI-LINE script: every line must come out commented, or the
  #     tail lines would replay live (the all-lines-commented rule)
  set c1 [logcount {# failed: nonexistent_tcp_multiline_zz}]
  set c2 [logcount {# set tail_line_must_be_commented 1}]
  tcp_send $port "nonexistent_tcp_multiline_zz\nset tail_line_must_be_commented 1"
  check "TCP: failed multi-line -> first line commented" \
    [expr {[logcount {# failed: nonexistent_tcp_multiline_zz}] == $c1 + 1}]
  check "TCP: failed multi-line -> tail line ALSO commented" \
    [expr {[logcount {# set tail_line_must_be_commented 1}] == $c2 + 1}]
  check "TCP: failed multi-line -> tail line not live" \
    [expr {[logcount {set tail_line_must_be_commented 1}] == 0}]

  catch {close $xschem_server_getdata(server)}
  catch {unset xschem_server_getdata(server)}
}
xschem set cadsnap $snap_save

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
