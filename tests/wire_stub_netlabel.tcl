#
#  File: wire_stub_netlabel.tcl
#
#  Headless regression for Thread B -- wire-stubs + auto net-labels on instance pins.
#  See doc/claude/specs/wire_stub_netlabel.md
#
#  Phases land here as they are implemented:
#    B1 -- median_double() sizing primitive (this file's first section).
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script wire_stub_netlabel.tcl
#

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# ---------------------------------------------------------------------------
# B1. median_double() -- exposed as the diagnostic `xschem get median v...`.
#     The wire-stub op (§4.2) reduces the processed pins' name sizes to ONE
#     size (median, not mean, so a lone outlier pin cannot skew stub length).
# ---------------------------------------------------------------------------
check "B1 single value = itself"        [xschem get median 0.42]              0.42
check "B1 all-equal = that value"       [xschem get median 0.2 0.2 0.2]       0.2
check "B1 two equal = that value"       [xschem get median 0.2 0.2]           0.2
# SKEWED inputs where median != mean -- these discriminate median from a plain average:
check "B1 odd skewed = middle (not mean)"   [xschem get median 1 2 30]        2
check "B1 even skewed = mean of 2 middle"   [xschem get median 1 2 3 100]     2.5
check "B1 negatives skewed"                 [xschem get median -30 -2 -1]     -2
# UNSORTED inputs whose positional-middle != median -- these discriminate "did it sort?":
check "B1 unsorted odd (mid!=median)"       [xschem get median 3 1 2]         2
check "B1 unsorted 5 (mid!=median)"         [xschem get median 5 2 8 1 9]     5
# the real pin-size case the feature will hit: three owned pins 0.15/0.30/0.60 -> 0.30
check "B1 pin-size median (0.15/0.3/0.6)"   [xschem get median 0.15 0.3 0.6]  0.3

# error handling: no numbers is an error, not a silent 0
check "B1 no args errors" [catch {xschem get median}] 1

if {$nfail == 0} { puts "ALL PASS (wire_stub_netlabel)" } else { puts "$nfail FAILURES (wire_stub_netlabel)" }
