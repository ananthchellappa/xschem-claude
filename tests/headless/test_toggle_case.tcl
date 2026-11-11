# Toggle Case (toggle_case, togglecase::* in src/xschem.tcl; action edit.toggle_case,
# bound to Ctrl-5 by src/cadence_style_rc): swap the letter case of the selected pins,
# net labels, symbol pins and text, in one undo step.
#   TC1-TC2   the swap itself: per letter, and @tokens / tcleval(...) left alone
#   TC3-TC7   a schematic: only selected pins, labels and text change; one undo
#   TC8-TC10  refusals: nothing selected, nothing with letters, read-only
#   TC11      a symbol's pin box changes its name
#   TC12      the action is registered and the Cadence profile binds Ctrl-5 to it
#   TC13      a real Ctrl-5 on the canvas toggles (display arm only)
# Run: tests/headless/run_suites.sh [--nogui] test_toggle_case
source [file join [file dirname [info script]] scratch.tcl]

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}

set D [test_scratch togglecase]
set repo [file normalize [file join [file dirname [info script]] .. ..]]

# TC1-TC2 -- the swap.
check {TC1 each letter flips, other characters stay} \
  [lmap s {case CASE cAsE {dAta[3:0]} vdd_1v8 {}} {togglecase::swap $s}] \
  [list CASE case CaSe {DaTA[3:0]} VDD_1V8 {}]
check {TC2 a text keeps its @tokens, and a tcleval text is left alone} \
  [list [togglecase::swap_text {Gain @name x@value}] [togglecase::swap_text {tcleval([expr 1])}]] \
  [list {gAIN @name X@value} {tcleval([expr 1])}]

# The sheet: an input pin, two net labels, a text, a resistor.
proc sheet {} {
  global D
  set fd [open $D/tc.sch w]
  puts $fd "v {xschem version=3.4.6 file_version=1.2}"
  puts $fd "T {Hello @name} 0 -200 0 0 0.4 0.4 {}"
  puts $fd "C {ipin.sym} 0 0 0 0 {name=p1 lab=inA}"
  puts $fd "C {lab_pin.sym} 200 0 0 0 {name=l1 lab=Vout}"
  puts $fd "C {lab_pin.sym} 400 0 0 0 {name=l2 lab=keep}"
  puts $fd "C {res.sym} 600 0 0 0 {name=R1 value=1k}"
  close $fd
  xschem load -undo_reset $D/tc.sch
  xschem unselect_all
}
proc labs {} {
  list [xschem getprop instance p1 lab] [xschem getprop instance l1 lab] \
       [xschem getprop instance l2 lab] [xschem getprop instance R1 name] [xschem text_string 0]
}

sheet
xschem select instance p1 ; xschem select instance l1 ; xschem select instance R1
xschem select text 0
set n [toggle_case]
check {TC3 the selected pin, label and text flip; the resistor and the unselected label do not} \
  [list $n {*}[labs]] {3 INa vOUT keep R1 {hELLO @name}}
check {TC4 the sheet is marked modified} [xschem get modified] 1
check {TC5 the status line says how many changed} [xschem get statusmsg] {Toggle Case: 3 changed}
xschem undo
check {TC6 one undo puts all three back} [labs] {inA Vout keep R1 {Hello @name}}
xschem redo
check {TC7 redo flips them again, and a second toggle is the original} \
  [list [lindex [labs] 0] [toggle_case] [labs]] {INa 3 {inA Vout keep R1 {Hello @name}}}

# TC8-TC10 -- refusals change nothing.
sheet
check {TC8 nothing selected} [list [toggle_case] [xschem get statusmsg] [xschem get modified]] \
  {0 {Toggle Case: select pins, labels or text first} 0}
xschem select instance R1
check {TC9 a selection with no pin, label or text} [list [toggle_case] [xschem get statusmsg] [labs]] \
  {0 {Toggle Case: nothing in the selection has letters to change} {inA Vout keep R1 {Hello @name}}}
xschem select instance l1
xschem set readonly 1
check {TC10 a read-only cell is not changed} [list [toggle_case] [xschem get statusmsg] [labs]] \
  {0 {Toggle Case: read-only} {inA Vout keep R1 {Hello @name}}}
xschem set readonly 0

# TC11 -- a symbol's pin box.
set fd [open $D/tc.sym w]
puts $fd "v {xschem version=3.4.6 file_version=1.2}"
puts $fd "K {type=subcircuit}"
puts $fd "B 5 -2.5 -2.5 2.5 2.5 {name=clk dir=in}"
puts $fd "T {@symname} 0 20 0 0 0.3 0.3 {}"
close $fd
xschem load -undo_reset $D/tc.sym
xschem select rect 5 0 ; xschem select text 0
set n [toggle_case]
check {TC11 a symbol pin changes its name, @symname stays} \
  [list $n [xschem getprop rect 5 0 name] [xschem text_string 0]] {1 CLK @symname}

# TC12 -- the action exists, ships unbound, and the Cadence profile binds Ctrl-5.
set dump [xschem bindings dump]
set bound [expr {[lsearch -exact $dump {key 53 ctrl canvas edit.toggle_case}] >= 0}]
set rc [read [set fd [open $repo/src/cadence_style_rc]]] ; close $fd
check {TC12 ships unbound, the profile binds Ctrl-5, and the binding is accepted} \
  [list $bound \
        [regexp -line {^xschem bind key 53 ctrl canvas edit.toggle_case$} $rc] \
        [catch {xschem bind key 53 ctrl canvas edit.toggle_case}] \
        [expr {[lsearch -exact [xschem bindings dump] {key 53 ctrl canvas edit.toggle_case}] >= 0}]] \
  {0 1 0 1}

# TC13 -- a real Ctrl-5 on the canvas.
if {[info commands winfo] ne {} && [info exists has_x] && [winfo exists .drw]} {
  sheet
  xschem select instance l1
  focus -force .drw ; update
  event generate .drw <KeyPress> -keysym 5 -state 4 -x 200 -y 200 -when now
  update
  check {TC13 Ctrl-5 on the canvas toggles the selected label} [xschem getprop instance l1 lab] vOUT
} else {
  puts "SKIP: TC13 needs a display (a real key press)"
}

xschem set modified 0
set floor [expr {([info commands winfo] ne {} && [info exists has_x]) ? 13 : 12}]
if {$npass + $fail < $floor} {
  puts "FAIL: TCFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
