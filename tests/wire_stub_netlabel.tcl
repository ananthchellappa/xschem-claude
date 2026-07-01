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

# individual pin selection restricts to those pins (pins WIN over a whole-instance selection);
# an already-connected pin is SKIPPED even when explicitly selected (user decision 2026-07-01).
xschem unselect_all ; xschem select pin x1 2
same_targets "B2 selected UNCONNECTED pin -> stubbed" [xschem pin_stub_targets] {{0 2}}
xschem unselect_all ; xschem select pin x1 0
same_targets "B2 selected but already-wired pin -> skipped" [xschem pin_stub_targets] {}
xschem unselect_all ; xschem select pin x1 1 ; xschem select pin x1 2
same_targets "B2 two pins selected, the wired one filtered out" [xschem pin_stub_targets] {{0 2}}
# pins WIN over a co-selected whole instance (scope): selecting the WIRED pin0 + the instance
# yields {} (only pin0 is considered, and it is wired), NOT the whole-instance set {0 2}.
xschem unselect_all ; xschem select instance x1 ; xschem select pin x1 0
same_targets "B2 wired pin0 + whole-instance -> {} (pins win; pin0 wired)" \
  [xschem pin_stub_targets] {}

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

# ---------------------------------------------------------------------------
# B3. Sizing: reduce the targets to ONE size S (the MEDIAN of their pin-name
#     sizes), the label line height H at S, and the grid-snapped stub length
#     L > 2H. Exposed as `xschem pin_stub_sizing` -> "S H L". §4.2. Assertions
#     are RELATIONAL (robust to font metrics): the contract is S=median, H>0,
#     L>2H, L on grid, and L the SMALLEST such grid multiple.
# ---------------------------------------------------------------------------
set wd3 [file normalize ./wire_stub_work3]
file delete -force $wd3 ; file mkdir $wd3
set sym3 $wd3/blk3.sym
set fp [open $sym3 w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nK {type=subcircuit}\nV {}\nS {}\nE {}"
puts $fp "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_size=0.15}"
puts $fp "B 5 -2.5 37.5 2.5 42.5 {name=B dir=in show_pinname=true name_size=0.30}"
puts $fp "B 5 -2.5 77.5 2.5 82.5 {name=C dir=in show_pinname=true name_size=0.60}"
close $fp

xschem clear force
xschem instance $sym3 0 0 0 0 {name=x1}
set grid [set ::cadgrid]

xschem unselect_all ; xschem select instance x1
lassign [xschem pin_stub_sizing] S H L
# S is the MEDIAN (0.15/0.30/0.60 -> 0.30) -- discriminates median from min/max/mean(0.35)
check "B3 size = median of the pins' sizes" $S [xschem get median 0.15 0.30 0.60]
check "B3 label height positive"            [expr {$H > 0}] 1
check "B3 stub length > 2*height (Req 1)"   [expr {$L > 2*$H}] 1
check "B3 stub length lands on grid"        [expr {abs($L - $grid*round($L/$grid)) < 1e-9}] 1
check "B3 stub length is the SMALLEST such grid multiple" [expr {($L - $grid) <= 2*$H}] 1

# a single pin -> S is exactly that pin's size (median of one); bigger size -> longer stub
xschem unselect_all ; xschem select pin x1 2
lassign [xschem pin_stub_sizing] S1 H1 L1
check "B3 single pin size = that pin's size" $S1 0.6
check "B3 bigger size -> longer stub"        [expr {$L1 > $L}] 1

# nothing selected -> empty sizing string
xschem unselect_all
check "B3 nothing selected -> empty" [xschem pin_stub_sizing] {}

file delete -force $wd3

# ---------------------------------------------------------------------------
# B4. Stub geometry: `xschem pin_stub_geom <inst> <pin> <L>` -> "x1 y1 x2 y2 dx dy".
#     Outward = (pin center - BODY center) snapped to the dominant axis, then
#     transformed through the instance rot/flip; start = pin abs coord, end =
#     start + outward*L. Deterministic -> assert exact values. §4.3.
# ---------------------------------------------------------------------------
set wd4 [file normalize ./wire_stub_work4]
file delete -force $wd4 ; file mkdir $wd4
# cross.sym: body center (0,0); 4 pins on 4 sides at (-20,0)/(20,0)/(0,-20)/(0,20)
set symx $wd4/cross.sym
set fp [open $symx w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nK {type=subcircuit}\nV {}\nS {}\nE {}"
puts $fp "B 5 -22.5 -2.5 -17.5 2.5 {name=L dir=in show_pinname=true}"
puts $fp "B 5 17.5 -2.5 22.5 2.5 {name=R dir=in show_pinname=true}"
puts $fp "B 5 -2.5 -22.5 2.5 -17.5 {name=T dir=in show_pinname=true}"
puts $fp "B 5 -2.5 17.5 2.5 22.5 {name=B dir=in show_pinname=true}"
close $fp

xschem clear force
xschem instance $symx 100 100 0 0 {name=x1}
# each pin points AWAY from the body along its own axis; stub end = start + outward*40
check "B4 left  pin -> -x" [xschem pin_stub_geom 0 0 40] {80 100 40 100 -1 0}
check "B4 right pin -> +x" [xschem pin_stub_geom 0 1 40] {120 100 160 100 1 0}
check "B4 top   pin -> -y" [xschem pin_stub_geom 0 2 40] {100 80 100 40 0 -1}
check "B4 bot   pin -> +y" [xschem pin_stub_geom 0 3 40] {100 120 100 160 0 1}

# rot=1 rotates the outward direction (+x -> +y here) and the pin position with it
xschem clear force ; xschem instance $symx 100 100 1 0 {name=x1}
check "B4 rot=1: right pin outward rotates to +y" [xschem pin_stub_geom 0 1 40] {100 120 100 160 0 1}
# flip mirrors x: the right pin now points -x
xschem clear force ; xschem instance $symx 100 100 0 1 {name=x1}
check "B4 flip: right pin outward mirrors to -x" [xschem pin_stub_geom 0 1 40] {80 100 40 100 -1 0}

# OFFSET body: both pins at +x, but the body center is BETWEEN them, so pin0 must point -x
# (toward lower x, away from the body) -- discriminates "pin - body center" from "sign of pin".
set symo $wd4/offset.sym
set fp [open $symo w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nK {type=subcircuit}\nV {}\nS {}\nE {}"
puts $fp "B 5 7.5 -2.5 12.5 2.5 {name=A dir=in show_pinname=true}"
puts $fp "B 5 47.5 -2.5 52.5 2.5 {name=B dir=in show_pinname=true}"
close $fp
xschem clear force ; xschem instance $symo 0 0 0 0 {name=x1}
check "B4 offset body: inner +x pin still points -x (uses body center)" \
  [xschem pin_stub_geom 0 0 40] {10 0 -30 0 -1 0}
check "B4 offset body: outer pin points +x" [xschem pin_stub_geom 0 1 40] {50 0 90 0 1 0}

# bad instance / pin -> empty; missing args -> error
check "B4 bad instance -> empty" [xschem pin_stub_geom 99 0 40] {}
check "B4 bad pin -> empty"      [xschem pin_stub_geom 0 99 40] {}
check "B4 missing args errors"   [catch {xschem pin_stub_geom 0 0}] 1

file delete -force $wd4

# ---------------------------------------------------------------------------
# B5. Mutation: `xschem add_pin_stubs [-prefix s] [-suffix s] [-inst-prefix]`
#     draws a wire stub + a lab_pin net-label out of each stub target, oriented
#     so the text reads outward. One undo. Label = [instname_][prefix]pin[suffix].
# ---------------------------------------------------------------------------
set wd5 [file normalize ./wire_stub_work5]
file delete -force $wd5 ; file mkdir $wd5
set symc $wd5/cross.sym
set fp [open $symc w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nK {type=subcircuit}\nV {}\nS {}\nE {}"
puts $fp "B 5 -22.5 -2.5 -17.5 2.5 {name=L dir=in show_pinname=true}"
puts $fp "B 5 17.5 -2.5 22.5 2.5 {name=R dir=in show_pinname=true}"
puts $fp "B 5 -2.5 -22.5 2.5 -17.5 {name=T dir=in show_pinname=true}"
puts $fp "B 5 -2.5 17.5 2.5 22.5 {name=B dir=in show_pinname=true}"
close $fp

# sorted list of lab= over the lab_pins (all instances except the source at index 0)
proc labels {} {
  set out {}
  for {set i 1} {$i < [xschem get instances]} {incr i} { lappend out [xschem getprop instance $i lab] }
  return [lsort $out]
}
proc fresh {sym} {
  xschem clear force
  xschem instance $sym 100 100 0 0 {name=x1}
  xschem unselect_all ; xschem select instance x1
}

fresh $symc
set L [lindex [xschem pin_stub_sizing] 2]
check "B5 whole instance -> 4 stubs" [xschem add_pin_stubs] 4
check "B5 4 wires created"           [xschem get wires] 4
check "B5 4 lab_pins placed"         [expr {[xschem get instances]-1}] 4
check "B5 default net names = pin names" [labels] {B L R T}

# every label's text extends OUTWARD from its stub end (flag in the wind): targets are processed
# in pin order 0..3, so lab instances 1..4 correspond to pins 0..3. Use the B4 seam for the stub
# end + outward dir, then check the placed lab_pin's bbox centre points outward from that end.
set okdir 1
for {set k 0} {$k < 4} {incr k} {
  lassign [xschem pin_stub_geom 0 $k $L] px py ex ey dx dy
  xschem unselect_all ; xschem select instance [expr {$k+1}]
  lassign [xschem get bbox_selected] bx1 by1 bx2 by2
  set cx [expr {($bx1+$bx2)/2.0}] ; set cy [expr {($by1+$by2)/2.0}]
  if {($cx-$ex)*$dx + ($cy-$ey)*$dy <= 0} { set okdir 0 }
}
check "B5 every label reads outward (flag in the wind)" $okdir 1

# ONE undo removes every wire + label
xschem undo
check "B5 one undo removes all stubs+labels" \
  [list [xschem get wires] [xschem get instances]] {0 1}

# naming options (default = pin name; prefix/suffix/inst-prefix combine)
fresh $symc ; xschem add_pin_stubs -prefix pre_
check "B5 -prefix"        [labels] {pre_B pre_L pre_R pre_T}
fresh $symc ; xschem add_pin_stubs -suffix _s
check "B5 -suffix"        [labels] {B_s L_s R_s T_s}
fresh $symc ; xschem add_pin_stubs -inst-prefix
check "B5 -inst-prefix"   [labels] {x1_B x1_L x1_R x1_T}
fresh $symc ; xschem add_pin_stubs -inst-prefix -prefix p_ -suffix _s
check "B5 combined"       [labels] {x1_p_B_s x1_p_L_s x1_p_R_s x1_p_T_s}

# already-connected pins are skipped (wire the L pin at its abs coord (80,100))
fresh $symc ; xschem unselect_all ; xschem wire 80 100 80 140
xschem unselect_all ; xschem select instance x1
check "B5 already-wired pin skipped -> 3 stubs" [xschem add_pin_stubs] 3
check "B5 skipped label set (no L)"             [labels] {B R T}

# selected-pins mode: only those pins
fresh $symc ; xschem unselect_all ; xschem select pin x1 1 ; xschem select pin x1 3
check "B5 selected pins -> 2 stubs" [xschem add_pin_stubs] 2
check "B5 selected labels"          [labels] {B R}

# nothing to do -> 0, no change
fresh $symc ; xschem unselect_all
check "B5 nothing selected -> 0"        [xschem add_pin_stubs] 0
check "B5 no change when nothing to do" [list [xschem get wires] [expr {[xschem get instances]-1}]] {0 0}
xschem clear force symbol
check "B5 symbol-edit mode -> 0"        [xschem add_pin_stubs] 0

file delete -force $wd5

if {$nfail == 0} { puts "ALL PASS (wire_stub_netlabel)" } else { puts "$nfail FAILURES (wire_stub_netlabel)" }
