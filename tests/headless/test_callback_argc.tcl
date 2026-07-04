# Issue 0076 regression: `xschem callback` with too few args must return a Tcl ERROR,
# never crash. Before the fix the branch read argv[2..9] with no argc guard, so
# `xschem callback` (argc==2) passed argv[2]==NULL as win_path into callback() ->
# NULL deref -> SIGSEGV -> emergency-save -> the whole editor died (same class as the
# select_inside typo, issue 0075). callback needs argc>=10
# (win_path event mx my key button aux state).
#
# The script reaching "OVERALL: ok" is itself the core assertion: a crash on any short
# form kills the process before the sentinel and run_regression scores it FAIL.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_callback_argc.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# Every short-argc form (argc 2..9) must ERROR, not crash. Getting through the whole
# loop proves none SIGSEGV'd.
foreach {label cmd} {
  "no args (argc 2)"        {xschem callback}
  "win only (argc 3)"       {xschem callback .drw}
  "partial (argc 6)"        {xschem callback .drw 5 0 0}
  "one short (argc 9)"      {xschem callback .drw 5 0 0 0 0 0}
} {
  check "short errors: $label" [catch $cmd] 1
}

catch {xschem callback} emsg
check "usage message" [string match {*callback: usage*} $emsg] 1

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
