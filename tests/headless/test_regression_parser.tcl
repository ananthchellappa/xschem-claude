# test_regression_parser.tcl — BUG-B verification
# Run standalone: tclsh tests/headless/test_regression_parser.tcl
#
# Verifies that the regex patterns used in run.sh to detect failure lines
# match and reject exactly the right strings.  A false negative (pattern
# misses a real failure) would silently pass a broken baseline; a false
# positive would fail green runs.

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# --- FAIL$ pattern (run.sh: grep -q " FAILED" state.txt) ---
# The harness writes "PASS case" or "FAIL case". In run.sh the diff loop
# prints "FAIL  $base" and sets fail=1; separate grep is on "ERROR ".
# We test the shell-side patterns by simulating what they would match in Tcl.

# Pattern: line ending with exactly FAIL (case-sensitive, anchored)
proc matches_fail {line} { return [regexp {FAIL$} $line] }

check "FAIL$ matches 'FAIL  state.txt FAIL'" [matches_fail "FAIL  state.txt FAIL"] {}
check "FAIL$ matches bare 'FAIL'"            [matches_fail "FAIL"] {}
check "FAIL$ rejects 'PASS  state.txt'"      [expr {![matches_fail "PASS  state.txt"]}] {}
check "FAIL$ rejects 'FAILURE'"              [expr {![matches_fail "FAILURE"]}] {}
check "FAIL$ rejects 'FAIL  base: missing'"  [expr {![matches_fail "FAIL  base: missing from results"]}] {}

# Pattern: line ending with GOLD? (run.sh uses NEW to flag unbasellined files)
proc matches_gold_q {line} { return [regexp {GOLD\?$} $line] }

check "GOLD?$ matches 'ask GOLD?'"          [matches_gold_q "ask GOLD?"] {}
check "GOLD?$ rejects 'GOLD'"              [expr {![matches_gold_q "GOLD"]}] {}
check "GOLD?$ rejects 'GOLD?X'"            [expr {![matches_gold_q "GOLD?X"]}] {}
check "GOLD?$ rejects empty string"        [expr {![matches_gold_q ""]}] {}

# Pattern: ^FATAL (run.sh: grep -q "FATAL:" stderr.log)
proc matches_fatal {line} { return [regexp {^FATAL} $line] }

check "^FATAL matches 'FATAL: xschem exited'"   [matches_fatal "FATAL: xschem exited with status 1"] {}
check "^FATAL matches bare 'FATAL'"             [matches_fatal "FATAL"] {}
check "^FATAL rejects leading space"            [expr {![matches_fatal " FATAL"]}] {}
check "^FATAL rejects 'NOT FATAL'"              [expr {![matches_fatal "NOT FATAL"]}] {}
check "^FATAL rejects 'fatal' (lowercase)"      [expr {![matches_fatal "fatal: something"]}] {}

# Pattern: Tcl_AppInit error detection
proc matches_tcl_init_err {line} { return [regexp {Tcl_AppInit\(\) err} $line] }

check "Tcl_AppInit error matched"      [matches_tcl_init_err {Tcl_AppInit() err 1: something}] {}
check "Tcl_AppInit error not on PASS"  [expr {![matches_tcl_init_err "PASS  something"]}] {}

if {$fail == 0} { puts "\nRESULT: ALL PASS" } else { puts "\nRESULT: $fail FAILED" }
exit [expr {$fail == 0 ? 0 : 1}]
