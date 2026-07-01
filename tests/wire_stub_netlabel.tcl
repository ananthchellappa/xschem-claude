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

# ---------------------------------------------------------------------------
# B2. Selection scan -> the (instance, pin) targets to stub, exposed as
#     `xschem pin_stub_targets` (a Tcl list of {inst pin} pairs). User model:
#       - individual pins selected -> exactly THOSE pins (honored even if wired);
#       - whole instance selected  -> its pins NOT already wired.
#     "wired" = a wire endpoint AT the pin OR a wire passing THROUGH it (touch()).
#     Schematic-mode only. See doc/claude/specs/wire_stub_netlabel.md §4.1.
# ---------------------------------------------------------------------------
# compare as unordered sets (sel_array order is not part of the contract)
proc same_targets {desc got want} { check $desc [lsort $got] [lsort $want] }

set wd [file normalize ./wire_stub_work]
file delete -force $wd ; file mkdir $wd
set sym $wd/blk.sym
set fp [open $sym w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nK {type=subcircuit}\nV {}\nS {}\nE {}"
# 3 pins at symbol centers (0,0) (0,40) (0,80)
puts $fp "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true}"
puts $fp "B 5 -2.5 37.5 2.5 42.5 {name=B dir=in show_pinname=true}"
puts $fp "B 5 -2.5 77.5 2.5 82.5 {name=C dir=in show_pinname=true}"
close $fp

xschem clear force
xschem instance $sym 0 0 0 0 {name=x1}

# whole instance, no wires -> all 3 pins
xschem unselect_all ; xschem select instance x1
same_targets "B2 whole-instance, no wires -> all pins" [xschem pin_stub_targets] {{0 0} {0 1} {0 2}}

# a wire ENDPOINT at pin 0 (0,0) -> pin 0 excluded
xschem wire 0 0 30 0
xschem unselect_all ; xschem select instance x1
same_targets "B2 wire endpoint at pin0 excludes it" [xschem pin_stub_targets] {{0 1} {0 2}}

# a wire passing THROUGH pin 1 (0,40) with NO endpoint there (vertical 0,20 -> 0,60):
# discriminates touch() (on-segment) from a naive endpoint-only check.
xschem wire 0 20 0 60
xschem unselect_all ; xschem select instance x1
same_targets "B2 wire THROUGH pin1 excludes it too" [xschem pin_stub_targets] {{0 2}}

# individual pin selection WINS over connectivity + whole-instance:
xschem unselect_all ; xschem select pin x1 0
same_targets "B2 selected pin0 returned even though wired" [xschem pin_stub_targets] {{0 0}}
xschem unselect_all ; xschem select pin x1 1 ; xschem select pin x1 2
same_targets "B2 two pins selected -> exactly those" [xschem pin_stub_targets] {{0 1} {0 2}}
# select a WIRED pin (pin0) + the whole instance: pins-win yields {0 0} (the selected pin),
# whereas whole-instance mode would yield the UNCONNECTED set {0 2} -- so this discriminates.
xschem unselect_all ; xschem select instance x1 ; xschem select pin x1 0
same_targets "B2 wired pin + whole-instance -> only that pin (pins win, not the unconnected set)" \
  [xschem pin_stub_targets] {{0 0}}

# a SECOND instance: whole-instance mode enumerates only the selected instance's pins
xschem instance $sym 100 0 0 0 {name=x2}
xschem unselect_all ; xschem select instance x2
same_targets "B2 second instance enumerated by index" [xschem pin_stub_targets] {{1 0} {1 1} {1 2}}

# a COINCIDENT instance pin (abutment) counts as connected, same as a wire. Fresh schematic
# (no wires): place x2's pin0 exactly on x1's pin2 -- symbol pins are at (0,0)/(0,40)/(0,80), so
# x2 at origin (0,80) puts x2 pin0 -> (0,80) == x1 pin2 -> (0,80).
xschem clear force
xschem instance $sym 0 0  0 0 {name=x1}
xschem instance $sym 0 80 0 0 {name=x2}
xschem unselect_all ; xschem select instance x1
same_targets "B2 coincident pin (abutment) excluded from x1" [xschem pin_stub_targets] {{0 0} {0 1}}
xschem unselect_all ; xschem select instance x2
same_targets "B2 coincident pin excluded from x2 too"        [xschem pin_stub_targets] {{1 1} {1 2}}

# nothing selected -> empty; symbol-edit mode (no instances) -> empty
xschem unselect_all
check "B2 nothing selected -> empty" [xschem pin_stub_targets] {}
xschem clear force symbol
check "B2 symbol-edit mode -> empty (schematic-only)" [xschem pin_stub_targets] {}

file delete -force $wd

if {$nfail == 0} { puts "ALL PASS (wire_stub_netlabel)" } else { puts "$nfail FAILURES (wire_stub_netlabel)" }
