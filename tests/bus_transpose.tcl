#
#  File: bus_transpose.tcl
#
#  Regression for the ALT+SHIFT+ScrollWheel "transpose selected bus index" feature (v2):
#  shift the index/range up/down on a pin/netlabel `lab` or an instance `name`:
#    up:   dat -> dat[0] -> dat[1] ...;   dat[N:M] -> dat[N+1:M+1]
#    down: dat[1] -> dat[0] -> dat (collapse); dat (bare) stays; dat[N:M] -> dat[N-1:M-1]
#          but never negative (dat[1:0] / any dat[N:0] stay unchanged).
#  Wires and text are tolerated (no effect). See doc/claude/specs/bus_transpose_scroll.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script bus_transpose.tcl
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils bus_resize.tcl]      ;# shared applier + is_label_type + _split
source [file join $utils bus_transpose.tcl]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}
# evaluate $script; if it errors (e.g. a not-yet-defined proc during RED), report the
# error string so the check FAILs cleanly instead of aborting the whole file.
proc tv {script} { if {[catch {uplevel 1 $script} r]} { return "<ERR:$r>" } ; return $r }

# --- pure index transform (brace descriptions: [N] would be cmd-substituted) ---
# up: bare/single/range
check {up scalar -> [0]}    [tv {bustranspose::up_name dat}]       {dat[0]}
check {up [0] -> [1]}       [tv {bustranspose::up_name {dat[0]}}]  {dat[1]}
check {up [7] -> [8]}       [tv {bustranspose::up_name {dat[7]}}]  {dat[8]}
check {up [1:0] -> [2:1]}   [tv {bustranspose::up_name {clk[1:0]}}] {clk[2:1]}
check {up [3:0] -> [4:1]}   [tv {bustranspose::up_name {bus[3:0]}}] {bus[4:1]}

# down: bare/single/range + no-negative floor
check {down [1] -> [0]}     [tv {bustranspose::down_name {dat[1]}}] {dat[0]}
check {down [0] collapse}   [tv {bustranspose::down_name {dat[0]}}] {dat}
check {down scalar floor}   [tv {bustranspose::down_name dat}]      {dat}
check {down [2:1] -> [1:0]} [tv {bustranspose::down_name {clk[2:1]}}] {clk[1:0]}
check {down [1:0] blocked}  [tv {bustranspose::down_name {clk[1:0]}}] {clk[1:0]}
check {down [3:0] blocked}  [tv {bustranspose::down_name {bus[3:0]}}] {bus[3:0]}

# roundtrips
check {roundtrip scalar}    [tv {bustranspose::down_name [bustranspose::up_name dat]}]       {dat}
check {roundtrip [3]}       [tv {bustranspose::down_name [bustranspose::up_name {dat[3]}]}]  {dat[3]}
check {roundtrip [4:1]}     [tv {bustranspose::down_name [bustranspose::up_name {x[4:1]}]}]  {x[4:1]}

# --- integration: real selection through bustranspose_apply ---------------
xschem load [file normalize buried_hilight/a.sch]

# net label: lab index up/down
xschem instance devices/lab_pin.sym 100 100 0 0 {name=l1 lab=bus}
set li [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select instance l1
bustranspose_apply up
check "label up lab"        [xschem getprop instance $li lab] {bus[0]}
bustranspose_apply up
check "label up lab 2"      [xschem getprop instance $li lab] {bus[1]}
bustranspose_apply down
check "label down lab"      [xschem getprop instance $li lab] {bus[0]}
bustranspose_apply down
check "label down collapse" [xschem getprop instance $li lab] {bus}
bustranspose_apply down
check "label down floor"    [xschem getprop instance $li lab] {bus}

# net label: lab RANGE shifts (not widens)
xschem instance devices/lab_pin.sym 100 300 0 0 {name=lr lab=d[3:0]}
set lri [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select instance lr
bustranspose_apply up
check "label range up"      [xschem getprop instance $lri lab] {d[4:1]}
bustranspose_apply down
check "label range down"    [xschem getprop instance $lri lab] {d[3:0]}
bustranspose_apply down
check "label range down blocked (no negative)" [xschem getprop instance $lri lab] {d[3:0]}

# generic instance: name index up
xschem instance devices/res.sym 500 500 0 0 {name=R1}
set ri [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select instance R1
bustranspose_apply up
check "instance up name"    [xschem getprop instance $ri name] {R1[0]}

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
bustranspose_apply up
check "label transposed in mixed sel" [xschem getprop instance $lm lab] {net[0]}
check "wire untouched (no bus added)" [xschem getprop wire 0 bus] {}

# --- single-undo: a multi-object notch is ONE undo step -------------------
xschem load [file normalize buried_hilight/a.sch]
xschem instance devices/lab_pin.sym 100 100 0 0 {name=la lab=aaa}
xschem instance devices/lab_pin.sym 100 200 0 0 {name=lb lab=bbb}
xschem unselect_all ; xschem select instance la ; xschem select instance lb
bustranspose_apply up
check "multi up la" [xschem getprop instance la lab] {aaa[0]}
check "multi up lb" [xschem getprop instance lb lab] {bbb[0]}
xschem undo
check "ONE undo reverts la" [xschem getprop instance la lab] {aaa}
check "ONE undo reverts lb" [xschem getprop instance lb lab] {bbb}

if {$nfail} { puts "bus_transpose: $nfail check(s): FAIL" } \
else        { puts "bus_transpose: all checks PASS" }
