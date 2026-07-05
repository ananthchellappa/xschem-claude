#
#  File: hilight_style_decr.tcl
#
#  Headless regression for the net-highlight style cursor stepping commands
#  (xschem incr_hilight_color / decr_hilight_color), driving the ALT-minus feature.
#  See doc/claude/specs/hilight_style_decrement.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script hilight_style_decr.tcl
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# Normalize the cursor to 0 by stepping back enough times, then probe stepping.
# n styles is built on first use; the commands return the new index.
set n 0
# advance once to ensure the style table exists and learn it is >= 1
set after_incr [xschem incr_hilight_color]
check "incr returns a non-negative index" [expr {$after_incr >= 0}] 1

# Walk the cursor to a known 0: decrement until we read 0 (bounded loop).
for {set i 0} {$i < 1000} {incr i} {
  if {[xschem decr_hilight_color] == 0} break
}
check "cursor parked at 0" [expr {[xschem incr_hilight_color] == 1}] 1   ;# now at 1

# from 1: decr -> 0, decr -> wraps to top (n-1)
check "decr 1 -> 0" [xschem decr_hilight_color] 0
set top [xschem decr_hilight_color]                ;# wrap to n-1
check "decr 0 wraps to a positive top" [expr {$top > 0}] 1
# stepping forward from the top wraps back to 0
check "incr top wraps to 0" [xschem incr_hilight_color] 0

if {$nfail} { puts "hilight_style_decr: $nfail check(s): FAIL" } \
else        { puts "hilight_style_decr: all checks PASS" }
