# Issue 0077 regression: `xschem getprop wire` / `getprop rect` must bounds-check the
# caller-supplied index before subscripting xctx->wire[n] / xctx->rect[c][n]. Before the
# fix an out-of-range index did an OOB heap read -> SIGSEGV -> emergency-save -> editor died
# (crash / memory disclosure). getprop text was already safe (get_text upper-bounds).
#
# Reaching "OVERALL: ok" is itself the core assertion: an OOB read on any form below crashes
# the process before the sentinel and run_regression scores it FAIL.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_getprop_index_bounds.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# Give the happy path real objects to read: one wire (index 0) and one rect on layer 4.
xschem wire 0 0 100 0
xschem rect 4 0 0 50 50
check "wire created"  [expr {[xschem get wires] >= 1}] 1

# Valid in-range reads must still succeed (no regression of the happy path).
check "valid getprop wire 0"      [catch {xschem getprop wire 0 lab}]   0
check "valid getprop rect 4 0"    [catch {xschem getprop rect 4 0 dash}] 0

# Out-of-range indices must ERROR (not OOB-read / crash).
foreach {label cmd} {
  "wire index too big"   {xschem getprop wire 999999 lab}
  "wire index negative"  {xschem getprop wire -1 lab}
  "rect layer negative"  {xschem getprop rect -1 0 dash}
  "rect layer too big"   {xschem getprop rect 9999 0 dash}
  "rect index too big"   {xschem getprop rect 4 999999 dash}
} {
  check "oob errors: $label" [catch $cmd] 1
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
