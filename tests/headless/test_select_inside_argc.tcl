# Issue 0075 regression: `xschem select_inside` with too few args must return a Tcl
# ERROR, never crash the interpreter. Before the fix, a short command reached
# atof(argv[3]) == atof(NULL) -> SIGSEGV -> emergency-save -> the whole editor died
# (the user typo `xschem select_inside x1`, meant as `xschem select instance x1`).
#
# This whole script running to the "OVERALL: ok" sentinel is itself the core assertion:
# a crash on ANY of the short forms below kills the process before the sentinel prints,
# and run_regression.tcl then synthesizes a FAIL (crash => missing sentinel + nonzero
# exit). The per-check asserts additionally pin the usage-error contract.
#
# Pure headless. Run from the repo ROOT (xctx exists at script time under --nogui):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_select_inside_argc.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# 1. Every short-argc form must ERROR (catch==1), not crash. Reaching this point at all
#    proves no SIGSEGV occurred for the earlier forms (a crash would have ended the run).
foreach {label cmd} {
  "no coords (argc 2)"      {xschem select_inside}
  "1 arg  (the 0075 typo)"  {xschem select_inside x1}
  "1 numeric arg (argc 3)"  {xschem select_inside 0}
  "2 args (argc 4)"         {xschem select_inside 0 0}
  "3 args (argc 5)"         {xschem select_inside 0 0 0}
} {
  check "short errors: $label" [catch $cmd] 1
}

# 2. The error message is the usage string (not some incidental error).
catch {xschem select_inside x1} emsg
check "usage message" [string match {*select_inside: usage*} $emsg] 1

# 3. The correct 4-coord form still works (catch==0), and the deselect flag form too.
check "valid 4-arg form"        [catch {xschem select_inside 0 0 100 100}] 0
check "valid 5-arg (deselect)"  [catch {xschem select_inside 0 0 100 100 0}] 0

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
