#
#  File: bus_resize.tcl
#
#  Regression for the ALT+ScrollWheel "grow/shrink selected" feature:
#  bus-width on pin/netlabel/instance names + wire thickness.
#  See doc/claude/specs/bus_thickness_scroll.md
#
#  Run UNDER xschem (needs the `xschem` command + a real selection):
#      cd tests
#      ../src/xschem --nogui --pipe -q --script bus_resize.tcl
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils bus_resize.tcl]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# --- pure name transform --------------------------------------------------
check "grow scalar"        [busresize::grow_name clk]        {clk[1:0]}
check "grow 1:0 -> 2:0"    [busresize::grow_name {clk[1:0]}] {clk[2:0]}
check "grow 5:2 -> 6:2"    [busresize::grow_name {d[5:2]}]   {d[6:2]}

check "shrink 2:0 -> 1:0"  [busresize::shrink_name {clk[2:0]}] {clk[1:0]}
check "shrink 1:0 collapse" [busresize::shrink_name {clk[1:0]}] {clk}
check "shrink scalar floor" [busresize::shrink_name clk]        {clk}
check "shrink 6:2 -> 5:2"  [busresize::shrink_name {d[6:2]}]   {d[5:2]}
check "shrink 3:2 collapse" [busresize::shrink_name {d[3:2]}]   {d}

# round-trip
check "roundtrip scalar"   [busresize::shrink_name [busresize::grow_name clk]]        {clk}
check "roundtrip 2:0"      [busresize::shrink_name [busresize::grow_name {clk[2:0]}]] {clk[2:0]}

# --- wire thickness model -------------------------------------------------
check "wire grow from plain" [busresize::wire_grow {}]   $busresize::wire_start
check "wire shrink plain noop" [busresize::wire_shrink {}] 0
# grow from a numeric value: >= +0.5 step, and > original
set t0 4.0
set t1 [busresize::wire_grow $t0]
check "wire grow increases" [expr {$t1 > $t0}] 1
check "wire grow visible step" [expr {$t1 >= $t0 + 0.5}] 1
# shrink a value just above start collapses to plain (0)
check "wire shrink below start -> plain" [busresize::wire_shrink [expr {$busresize::wire_start + 0.1}]] 0

# --- integration: real selection through busresize_apply ------------------
xschem load [file normalize buried_hilight/a.sch]

# net label: lab grows/shrinks, instance auto-name untouched
xschem instance devices/lab_pin.sym 100 100 0 0 {name=l1 lab=clk}
set li [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select instance l1
busresize_apply grow
check "label grow lab"   [xschem getprop instance $li lab] {clk[1:0]}
busresize_apply grow
check "label grow lab 2"  [xschem getprop instance $li lab] {clk[2:0]}
busresize_apply shrink
check "label shrink lab"  [xschem getprop instance $li lab] {clk[1:0]}
busresize_apply shrink
check "label shrink collapse" [xschem getprop instance $li lab] {clk}
busresize_apply shrink
check "label shrink floor" [xschem getprop instance $li lab] {clk}

# generic instance: name grows
xschem instance devices/res.sym 300 300 0 0 {name=R1}
set ri [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select instance R1
busresize_apply grow
check "instance grow name" [xschem getprop instance $ri name] {R1[1:0]}

# wire: thickness via bus property
xschem unselect_all
xschem wire 0 0 200 0
set wi 0
xschem select wire $wi
busresize_apply grow
check "wire grow bus>0" [expr {[xschem getprop wire $wi bus] > 0}] 1

if {$nfail} { puts "bus_resize: $nfail check(s): FAIL" } \
else        { puts "bus_resize: all checks PASS" }
