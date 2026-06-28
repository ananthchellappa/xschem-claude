# P3: Modify an existing symbol = add ONLY the pins missing vs the schematic, and
# touch NO existing artwork (no box resize, no rewrite of existing records).
# Spec: doc/claude/specs/create_symbol_view.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_modify_symbol_pins.tcl

set work /tmp/p3_modify_work
file delete -force $work; file mkdir $work

# schematic with three pins: A(in), B(in), Y(out)
set sch $work/amp.sch
set fp [open $sch w]
puts $fp "v {xschem version=3.4.4 file_version=1.2}"
puts $fp "G {}"; puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
puts $fp "C {ipin.sym} 0 0 0 0 {name=p1 lab=A}"
puts $fp "C {ipin.sym} 0 20 0 0 {name=p2 lab=B}"
puts $fp "C {opin.sym} 100 0 0 0 {name=p3 lab=Y}"
close $fp

# an EXISTING symbol that has only A(in) and Y(out), plus a UNIQUE artwork marker
set sym $work/amp.sym
set BOX {P 4 5 130 -20 -130 -20 -130 20 130 20 130 -20 {}}
set ARTWORK {L 6 -77 -77 -33 -77 {}}
set fp [open $sym w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "K {type=subcircuit\nformat=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"\n}"
puts $fp "T {@symname} -36 -6 0 0 0.3 0.3 {}"
puts $fp $BOX
puts $fp $ARTWORK
puts $fp "B 5 -152.5 -12.5 -147.5 -7.5 {name=A dir=in}"
puts $fp "L 4 -150 -10 -130 -10 {}"
puts $fp "T {A} -125 -14 0 0 0.2 0.2 {}"
puts $fp "B 5 147.5 -12.5 152.5 -7.5 {name=Y dir=out}"
puts $fp "L 4 130 -10 150 -10 {}"
puts $fp "T {Y} 125 -14 0 1 0.2 0.2 {}"
close $fp

set ::fails 0
proc check {name ok} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout; if {!$ok} {incr ::fails} }
proc result {} { puts [expr {$::fails==0 ? {RESULT: ALL PASS} : "RESULT: $::fails FAILED"}]; flush stdout; exit [expr {$::fails!=0}] }

proc pin_names {file} {
  set out {}
  set fp [open $file r]
  foreach ln [split [read $fp] \n] {
    if {[regexp {^B 5 .* \{.*name=([^ \}]+).*dir=} $ln -> n]} { lappend out $n }
  }
  close $fp
  return [lsort $out]
}
proc pin_rec {file name} {
  set fp [open $file r]; set rec {}
  foreach ln [split [read $fp] \n] {
    if {[regexp "^B 5 .*name=$name +dir=" $ln]} { set rec $ln }
  }
  close $fp
  return $rec
}
proc has_line {file needle} {
  set fp [open $file r]; set d [read $fp]; close $fp
  return [expr {[string first $needle $d] >= 0}]
}

# --- the modify ---
modify_symbol_pins $sch $sym

check "Modify added the missing pin B" [expr {[lsearch [pin_names $sym] B] >= 0}]
check "all three pins now present (A B Y)" [expr {[pin_names $sym] eq {A B Y}}]
check "existing artwork box preserved verbatim" [has_line $sym $BOX]
check "custom artwork marker preserved verbatim" [has_line $sym $ARTWORK]
check "existing pin A record unchanged" \
  [has_line $sym "B 5 -152.5 -12.5 -147.5 -7.5 {name=A dir=in}"]
check "existing pin Y record unchanged" \
  [has_line $sym "B 5 147.5 -12.5 152.5 -7.5 {name=Y dir=out}"]
# new pin B is an input -> left column (negative x), below the existing pins
set brec [pin_rec $sym B]
check "new pin B is on the left (negative x)" [regexp {^B 5 -1} $brec]
check "new pin B sits below existing pins (positive y; existing are at y=-10)" \
  [expr {[regexp {^B 5 [-0-9.]+ ([-0-9.]+)} $brec -> by] && $by > 0}]

# idempotent: a second modify adds nothing
set before [pin_names $sym]
modify_symbol_pins $sch $sym
check "second modify is a no-op (no duplicate pins)" [expr {[pin_names $sym] eq $before}]

result
