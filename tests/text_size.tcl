#
#  File: text_size.tcl
#
#  Regression for the CTRL+Plus / CTRL+Minus "grow/shrink displayed text size" feature:
#  text notes (xText size) and pin/netlabel @lab display size (text_size_N). Other
#  object types are ignored. See doc/claude/specs/text_size_scroll.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script text_size.tcl
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils bus_resize.tcl]      ;# shared applier
source [file join $utils text_resize.tcl]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}
proc approx {desc got want} {   ;# floating compare to 1e-6
  global nfail
  if {abs($got - $want) < 1e-6} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# --- pure size transform --------------------------------------------------
# min_step dominates for small sizes (10% of 0.33 = 0.033 < 0.05)
approx "grow 0.33 -> +min_step" [textsize::grow 0.33] 0.38
# 10% dominates for larger sizes
approx "grow 1.0 -> 1.1"        [textsize::grow 1.0]  1.1
# shrink reverses a grow
approx "shrink 0.38 -> 0.33"    [textsize::shrink 0.38 0.1] 0.33
# clamp at floor
approx "shrink 0.12 clamps floor" [textsize::shrink 0.12 0.1] 0.1
# no-op at floor
approx "shrink at floor no-op"  [textsize::shrink 0.1 0.1] 0.1

# --- integration: text note size -----------------------------------------
xschem load [file normalize buried_hilight/a.sch]
xschem text 400 400 0 0 {a note} {} 0.4 1
set tn 0
xschem unselect_all ; xschem select text $tn
set s0 [xschem getprop text $tn size]
approx "text note initial size" $s0 0.4
textsize_apply grow
set s1 [xschem getprop text $tn size]
check "text note grew" [expr {$s1 > $s0}] 1
textsize_apply shrink
approx "text note shrank back" [xschem getprop text $tn size] 0.4

# --- integration: net label @lab display size ----------------------------
xschem load [file normalize buried_hilight/a.sch]
xschem instance devices/lab_pin.sym 100 100 0 0 {name=l1 lab=clk}
set li [expr {[xschem get instances]-1}]
lassign [xschem inst_name_text $li] nidx nsz
check "inst_name_text finds @lab at index 0" $nidx 0
approx "inst_name_text default size 0.33" $nsz 0.33
xschem unselect_all ; xschem select instance l1
textsize_apply grow
set ov [xschem getprop instance $li text_size_0]
check "label text_size_0 override set" [expr {$ov ne {} && $ov > 0.33}] 1

# --- generic instance is ignored (no @lab) -------------------------------
xschem instance devices/res.sym 300 300 0 0 {name=R1}
set ri [expr {[xschem get instances]-1}]
check "inst_name_text empty for resistor" [xschem inst_name_text $ri] {}

# --- single-undo: a note + a label, one grow = one undo ------------------
xschem load [file normalize buried_hilight/a.sch]
xschem text 400 400 0 0 {note} {} 0.4 1
xschem instance devices/lab_pin.sym 100 100 0 0 {name=la lab=aaa}
set la [expr {[xschem get instances]-1}]
xschem unselect_all ; xschem select text 0 ; xschem select instance la
textsize_apply grow
check "multi: note grew"  [expr {[xschem getprop text 0 size] > 0.4}] 1
check "multi: label grew" [expr {[xschem getprop instance $la text_size_0] ne {}}] 1
xschem undo
approx "ONE undo reverts note" [xschem getprop text 0 size] 0.4
check "ONE undo reverts label" [xschem getprop instance $la text_size_0] {}

if {$nfail} { puts "text_size: $nfail check(s): FAIL" } \
else        { puts "text_size: all checks PASS" }
