set num_fail 0
set fake_log "fake_test.log"
set fd [open $fake_log w]
puts $fd "loading symbol"
puts $fd "Total files: 12"
puts $fd "File opened"
puts $fd "test: FAIL here"
puts $fd "result: GOLD? (check)"
puts $fd "this is a real FAIL"
puts $fd "this is a real GOLD?"
puts $fd "FATAL: crash"
close $fd

# The logic from run_regression.tcl
set fdread [open $fake_log r]
while {[gets $fdread line] >= 0} {
  if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {^FATAL} $line]} {
    incr num_fail
  }
}
close $fdread

if {$num_fail != 3} {
  puts "FAIL: Expected 3 failures, got $num_fail"
  exit 1
} else {
  puts "PASS: test_regression_parser.tcl"
  exit 0
}
