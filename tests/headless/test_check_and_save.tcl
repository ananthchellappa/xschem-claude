# Check and Save (check_and_save, chksave::* in src/xschem.tcl; `xschem check_schematic` in
# src/scheduler.c): the Virtuoso Schematic Composer gesture. It checks the current level,
# saves, and lists what it found.
#   CS0        a clean cell reports nothing
#   CS1-CS3    the schematic's pins against its OWN symbol (missing either way, direction)
#   CS4-CS6    connectivity: unconnected pins, a one-connection net, a label on nothing
#   CS7        shorted labels come from the netlister's ERC
#   CS8        a placed subcircuit whose symbol disagrees with its schematic
#   CS9        a placed symbol that is missing
#   CS10-CS12  it saves: modified flag, file on disk, a symbol view, a read-only cell
#   CS13       the symbol path in the cellview layout (lib/cell/{schematic,symbol})
#   CS14-CS17  the report window (display arm only)
# Run: tests/headless/run_suites.sh [--nogui] test_check_and_save
source [file join [file dirname [info script]] scratch.tcl]

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}

set D [test_scratch chksave]

# A subcircuit symbol with the given pins, each {name dir}.
proc mksym {f pins} {
  set fd [open $f w]
  puts $fd "v {xschem version=3.4.6 file_version=1.2}"
  puts $fd "K {type=subcircuit\nformat=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"}"
  set y 0
  foreach p $pins {
    lassign $p n d
    puts $fd "B 5 -2.5 [expr {$y - 2.5}] 2.5 [expr {$y + 2.5}] {name=$n dir=$d}"
    incr y 20
  }
  close $fd
}

# The clean cell: IN -> R1 -> OUT, VDD a port of its own.
proc amp_sheet {} {
  xschem clear force
  xschem instance {res.sym} 0 0 0 0 {name=R1 value=1k}
  set p [lrange [xschem instance_pin_coord R1 name P] 1 2]
  set m [lrange [xschem instance_pin_coord R1 name M] 1 2]
  xschem instance {ipin.sym} {*}$p 0 0 {name=p1 lab=IN}
  xschem instance {opin.sym} {*}$m 0 0 {name=p2 lab=OUT}
  xschem instance {iopin.sym} 300 300 0 0 {name=p3 lab=VDD}
}

proc texts {fs} { return [lmap d $fs {list [dict get $d sev] [dict get $d text]}] }

# CS0 -- clean.
mksym $D/amp.sym {{IN in} {OUT out} {VDD inout}}
amp_sheet
xschem saveas $D/amp.sch schematic
check {CS0 a clean cell with a matching symbol reports nothing} [texts [chksave::run]] {}

# CS1-CS3 -- the own symbol disagrees: OUT's direction, EN extra, VDD missing.
mksym $D/amp.sym {{IN in} {OUT in} {EN in}}
set f [texts [chksave::run]]
check {CS1 a direction mismatch is an error} \
  [expr {[lsearch -exact $f {error {Pin OUT is out in the schematic but in on symbol amp}}] >= 0}] 1
check {CS2 a symbol pin missing from the schematic is an error} \
  [expr {[lsearch -exact $f {error {Pin EN is on symbol amp but not in the schematic}}] >= 0}] 1
check {CS3 a schematic pin missing from the symbol is an error, and nothing else is reported} \
  [list [expr {[lsearch -exact $f {error {Pin VDD is in the schematic but not on symbol amp}}] >= 0}] \
        [llength $f]] {1 3}
mksym $D/amp.sym {{IN in} {OUT out} {VDD inout}}

# CS4-CS6 -- connectivity.
amp_sheet
xschem instance {res.sym} 400 0 0 0 {name=R3 value=1k}
xschem instance {res.sym} 600 0 0 0 {name=R4 value=1k}
set p4 [lrange [xschem instance_pin_coord R4 name P] 1 2]
xschem instance {lab_pin.sym} {*}$p4 0 0 {name=l1 lab=NETX}
xschem instance {lab_pin.sym} 900 900 0 0 {name=l2 lab=LONELY}
set f [texts [chksave::run]]
check {CS4 both pins of a loose resistor are unconnected} \
  [list [expr {[lsearch -exact $f {warning {Pin P of R3 is unconnected}}] >= 0}] \
        [expr {[lsearch -exact $f {warning {Pin M of R3 is unconnected}}] >= 0}]] {1 1}
check {CS5 a labelled net reaching one pin has one connection} \
  [expr {[lsearch -exact $f {warning {Net NETX has one connection (R4 P)}}] >= 0}] 1
check {CS6 a label on nothing, and the five warnings are all there is} \
  [list [expr {[lsearch -exact $f {warning {Label LONELY connects to nothing}}] >= 0}] [llength $f]] {1 5}

# CS7 -- two labels with different names on one pin: the netlister's short.
amp_sheet
xschem instance {res.sym} 400 0 0 0 {name=R3 value=1k}
set p3 [lrange [xschem instance_pin_coord R3 name P] 1 2]
set m3 [lrange [xschem instance_pin_coord R3 name M] 1 2]
xschem instance {lab_pin.sym} {*}$p3 0 0 {name=l1 lab=AAA}
xschem instance {lab_pin.sym} {*}$p3 0 0 {name=l2 lab=BBB}
xschem instance {lab_pin.sym} {*}$m3 0 0 {name=l3 lab=IN}
set fs [chksave::run]
set sh [lsearch -inline -all -glob [texts $fs] {error *shorted*}]
set shd [lindex [lmap d $fs {expr {[string match *shorted* [dict get $d text]] ? $d : [continue]}}] 0]
check {CS7 shorted labels are an error that points at the net} \
  [list [llength $sh] [expr {[dict exists $shd net] && [dict get $shd net] in {AAA BBB}}]] {1 1}

# CS8 -- a placed subcircuit whose symbol disagrees with its schematic.
mksym $D/amp.sym {{IN in} {OUT out}}
xschem clear force
xschem instance $D/amp.sym 0 0 0 0 {name=x1}
xschem saveas $D/top.sch schematic
set fs [chksave::run]
set sd [lmap d $fs {expr {[dict exists $d sym] ? [dict get $d text] : [continue]}}]
check {CS8 the placed cell's missing symbol pin is reported against that symbol} \
  [expr {[llength [lsearch -all -glob $sd {*VDD*}]] >= 1}] 1
mksym $D/amp.sym {{IN in} {OUT out} {VDD inout}}

# CS9 -- a placed symbol that is missing.
set fd [open $D/top.sch a] ; puts $fd "C {$D/nosuch.sym} 500 500 0 0 {name=x9}" ; close $fd
xschem load -undo_reset $D/top.sch
check {CS9 a missing symbol is an error} \
  [llength [lsearch -all -glob [texts [chksave::run]] "error {Symbol $D/nosuch.sym not found}"]] 1

# CS10 -- it saves, and returns what it found.
xschem load -undo_reset $D/amp.sch
xschem instance {res.sym} 400 0 0 0 {name=R3 value=1k}
set before [file mtime $D/amp.sch]
after 1100
set got [check_and_save]
xschem load -undo_reset $D/amp.sch
check {CS10 the edit is saved, unmodified, and the findings are returned} \
  [list [expr {[file mtime $D/amp.sch] > $before}] [xschem get modified] \
        [expr {[lsearch -glob [xschem instance_list] {*R3*}] >= 0}] [llength $got]] {1 0 1 2}
check {CS10b the status line says what happened} \
  [xschem get statusmsg] {Check and Save: 0 errors, 2 warnings, saved}

# CS11 -- a symbol view is saved and not checked.
xschem load -undo_reset $D/amp.sym
check {CS11 a symbol view is saved with no findings} \
  [list [check_and_save] [xschem get modified]] {{} 0}

# CS12 -- a read-only cell is neither checked nor saved.
xschem load -undo_reset $D/amp.sch
xschem set readonly 1
check {CS12 a read-only cell is not saved} [list [check_and_save] [xschem get statusmsg]] \
  {{} {Check and Save: read-only, NOT saved}}
xschem set readonly 0

# CS13 -- the cellview layout finds lib/cell/symbol/cell.sym from lib/cell/schematic/cell.sch.
file mkdir $D/lib/amp/schematic $D/lib/amp/symbol
close [open $D/lib/amp/symbol/amp.sym w]
check {CS13 the cellview symbol path, and none for a cell with no symbol} \
  [list [chksave::own_symbol $D/lib/amp/schematic/amp.sch] [chksave::own_symbol $D/lib/amp/schematic/b.sch]] \
  [list [file join $D lib amp symbol amp.sym] {}]

# CS14-CS17 -- the report window.
if {[info commands winfo] ne {} && [info exists has_x]} {
  xschem load -undo_reset $D/amp.sch   ;# CS10 saved the loose R3 into it
  focus -force .drw ; update
  check_and_save ; update
  check {CS14 findings open the report, one line each, keyboard left on the canvas} \
    [list [winfo ismapped .chksave] [expr {int([.chksave.t index end-1c]) - 1}] [focus]] {1 2 .drw}
  check {CS15 the summary line repeats the status line} [.chksave.sum cget -text] \
    {Check and Save: 0 errors, 2 warnings, saved}
  eval [.chksave.t tag bind f0 <Button-1>]
  check {CS16 clicking a line selects its instance} [join [xschem selected_set]] {R3}
  xschem delete
  check_and_save ; update
  check {CS17 a clean re-check closes the report} [winfo exists .chksave] 0
} else {
  puts "SKIP: CS14-CS17 need a display (the report window)"
}

set floor [expr {([info commands winfo] ne {} && [info exists has_x]) ? 19 : 15}]
if {$npass + $fail < $floor} {
  puts "FAIL: CSFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
