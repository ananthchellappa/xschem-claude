#
#  File: bus_transpose.tcl
#
#  Regression for the ALT+SHIFT+ScrollWheel "transpose selected bus index" feature:
#  single index [N] on a pin/netlabel `lab` or an instance `name`. Wires and text are
#  tolerated (no effect). See doc/claude/specs/bus_transpose_scroll.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script bus_transpose.tcl
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils bus_resize.tcl]      ;# shared applier + is_label_type
source [file join $utils bus_transpose.tcl]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# --- pure index transform (brace descriptions: [N] would be cmd-substituted) ---
check {grow scalar -> [0]}  [bustranspose::grow_name dat]      {dat[0]}
check {grow [0] -> [1]}     [bustranspose::grow_name {dat[0]}] {dat[1]}
check {grow [7] -> [8]}     [bustranspose::grow_name {dat[7]}] {dat[8]}
check {grow leaves range}   [bustranspose::grow_name {clk[1:0]}] {clk[1:0]}

check {shrink [1] -> [0]}   [bustranspose::shrink_name {dat[1]}] {dat[0]}
check {shrink [0] collapse} [bustranspose::shrink_name {dat[0]}] {dat}
check {shrink scalar floor} [bustranspose::shrink_name dat]      {dat}
check {shrink leaves range} [bustranspose::shrink_name {clk[1:0]}] {clk[1:0]}

check {roundtrip scalar}    [bustranspose::shrink_name [bustranspose::grow_name dat]]      {dat}
check {roundtrip [3]}       [bustranspose::shrink_name [bustranspose::grow_name {dat[3]}]] {dat[3]}

# --- integration: real selection through bustranspose_apply ---------------
xschem load [file normalize buried_hilight/a.sch]

# net label: lab index grows/shrinks
xschem instance devices/lab_pin.sym 100 100 0 0 {name=l1 lab=bus}
set li [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select instance l1
bustranspose_apply grow
check "label grow lab"   [xschem getprop instance $li lab] {bus[0]}
bustranspose_apply grow
check "label grow lab 2"  [xschem getprop instance $li lab] {bus[1]}
bustranspose_apply shrink
check "label shrink lab"  [xschem getprop instance $li lab] {bus[0]}
bustranspose_apply shrink
check "label shrink collapse" [xschem getprop instance $li lab] {bus}
bustranspose_apply shrink
check "label shrink floor" [xschem getprop instance $li lab] {bus}

# generic instance: name index grows
xschem instance devices/res.sym 300 300 0 0 {name=R1}
set ri [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select instance R1
bustranspose_apply grow
check "instance grow name" [xschem getprop instance $ri name] {R1[0]}

# wires and text are tolerated (no effect) when co-selected with a label
xschem load [file normalize buried_hilight/a.sch]
xschem instance devices/lab_pin.sym 100 100 0 0 {name=lm lab=net}
set lm [expr {[xschem get instances]-1}]
xschem wire 0 0 200 0
xschem text 400 400 0 0 {a note} {} 0.4 1
xschem unselect_all
xschem select instance lm
xschem select wire 0
xschem select text 0
bustranspose_apply grow
check "label transposed in mixed sel" [xschem getprop instance $lm lab] {net[0]}
check "wire untouched (no bus added)" [xschem getprop wire 0 bus] {}

# --- single-undo: a multi-object notch is ONE undo step -------------------
xschem load [file normalize buried_hilight/a.sch]
xschem instance devices/lab_pin.sym 100 100 0 0 {name=la lab=aaa}
xschem instance devices/lab_pin.sym 100 200 0 0 {name=lb lab=bbb}
xschem unselect_all ; xschem select instance la ; xschem select instance lb
bustranspose_apply grow
check "multi grow la" [xschem getprop instance la lab] {aaa[0]}
check "multi grow lb" [xschem getprop instance lb lab] {bbb[0]}
xschem undo
check "ONE undo reverts la" [xschem getprop instance la lab] {aaa}
check "ONE undo reverts lb" [xschem getprop instance lb lab] {bbb}

if {$nfail} { puts "bus_transpose: $nfail check(s): FAIL" } \
else        { puts "bus_transpose: all checks PASS" }
