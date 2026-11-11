# phaseDegUnwrapped -- ADE's verb, a route-C row in calc::catalogue
# (src/calculator.tcl): the recipe `dup() -180 == 360 * + cph()` applied to a
# phase column.  Spec: doc/claude/specs/calculator.md §7.2.
#   PU1      the catalogue row: name, category, route, returns, recipe
#   PU2-PU3  a phase that wraps: 1/(1+s)^3 (crosses the cut once) and
#            1/(1+s)^7 (crosses it twice), each against `ph cph()` sample by
#            sample and against the closed form
#   PU4      a first sample just either side of the cut
#   PU5      a first sample of exactly -180 becomes +180, and only that moves
#   PU6      real signals: phase 0 or +/-180
#   PU7      "phaseDegUnwrapped of the negated wave, plus 180" as one expression
# Every fixture is built in memory with `xschem raw new` + `xschem raw set`, so
# the phase it holds is exactly the wrapped value written here.
# Run: tests/headless/run_suites.sh --nogui test_calc_phase_unwrapped
source [file join [file dirname [info script]] scratch.tcl]

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}

set PI [expr {acos(-1)}]
# principal value in (-180, 180]
proc wrap {d} {
  set w [expr {$d - 360.0*floor($d/360.0 + 0.5)}]
  if {$w <= -180.0} { set w [expr {$w + 360.0}] }
  return $w
}
# a fresh in-memory database holding column `ph` = the given phases
set ndb 0
proc phase_db {phs} {
  global ndb
  set n [llength $phs]
  xschem raw new pu[incr ndb] table x 0 [expr {$n - 1}] 1
  xschem raw add ph {}
  set i 0
  foreach p $phs { xschem raw set x $i $i ; xschem raw set ph $i $p ; incr i }
}
# read back through `raw values` (%.16g), as numbers in canonical form
proc evalcol {name rpn} {
  xschem raw add $name "ph $rpn"
  return [lmap v [xschem raw values $name] {expr {double($v)}}]
}
proc maxdiff {a b} {
  set m 0.0
  foreach x $a y $b { set m [expr {max($m, abs($x - $y))}] }
  return $m
}
# the number of adjacent steps larger than 180 degrees
proc jumps {l} {
  set n 0
  for {set i 1} {$i < [llength $l]} {incr i} {
    if {abs([lindex $l $i] - [lindex $l $i-1]) > 180} { incr n }
  }
  return $n
}

# PU1 -- the row.  The recipe below is read from the catalogue, not restated.
set row [calc::fn_row phaseDegUnwrapped]
check {PU1 the catalogue row: Special Functions, route C, a wave, the anchored cph() recipe} \
  [lrange $row 0 4] {phaseDegUnwrapped {Special Functions} C wave {dup() -180 == 360 * + cph()}}
set R [lindex $row 4]

# PU2-PU3 -- 1/(1+s)^k over four decades either side of its pole, 81 points.
foreach {id k} {PU2 3 PU3 7} {
  set truth {} ; set wr {}
  for {set i 0} {$i < 81} {incr i} {
    set f [expr {pow(10.0, -2.0 + 4.0*$i/80.0)}]
    set d [expr {-$k*atan($f)*180.0/$PI}]
    lappend truth $d ; lappend wr [wrap $d]
  }
  phase_db $wr
  set got [evalcol pdu $R]
  set ref [evalcol cph {cph()}]
  check "$id 1/(1+s)^$k: the wrapped phase crosses the cut [expr {$k > 4 ? 2 : 1}] time(s), the result never jumps" \
    [list [jumps $wr] [jumps $got]] [list [expr {$k > 4 ? 2 : 1}] 0]
  check "$id ...it equals `ph cph()` sample by sample, and runs to the closed form within 1e-9" \
    [list [expr {$got eq $ref}] [expr {[maxdiff $got $truth] < 1e-9}] \
          [expr {round([lindex $got end])}]] [list 1 1 [expr {round([lindex $truth end])}]]
}

# PU4 -- a first sample just either side of the cut.
phase_db {179.9 -179.9 -179.0 179.5}
set a [evalcol pdu $R] ; set b [evalcol cph {cph()}]
phase_db {-179.9 179.9 179.0 -179.5}
set c [evalcol pdu $R] ; set d [evalcol cph {cph()}]
check {PU4 a first sample just above or just below the cut: continuous, equal to cph()} \
  [list [expr {$a eq $b}] [expr {[maxdiff $a {179.9 180.1 181.0 179.5}] < 1e-9}] \
        [expr {$c eq $d}] [expr {[maxdiff $c {-179.9 -180.1 -181.0 -179.5}] < 1e-9}]] {1 1 1 1}

# PU5 -- exactly -180 first: +180, and the rest follows a whole turn up.
phase_db {-180 -179 -178}
set a [evalcol pdu $R] ; set b [evalcol cph {cph()}]
check {PU5 a first sample of exactly -180 is anchored at +180; cph() alone leaves it at -180} \
  [list $a $b] {{180.0 181.0 182.0} {-180.0 -179.0 -178.0}}

# PU6 -- real signals.
set out {}
foreach phs {{0 0 0} {180 180 180} {-180 -180 180} {0 180 0} {180 0 -180}} {
  phase_db $phs ; lappend out [evalcol pdu $R]
}
check {PU6 a real signal: constant sign gives 0 or 180; a sign change steps by 180, settled downward} \
  $out {{0.0 0.0 0.0} {180.0 180.0 180.0} {180.0 180.0 180.0} {0.0 -180.0 -360.0} {180.0 0.0 -180.0}}

# PU7 -- phaseDegUnwrapped(-w) + 180, spelled on w's phase column.  Negating a
# wave adds 180 to its wrapped phase; `180 + dup() 180 > 360 * -` puts the sum
# back in (-180, 180] before the verb, and `180 +` follows it.
set truth {} ; set wr {}
for {set i 0} {$i < 81} {incr i} {
  set f [expr {pow(10.0, -2.0 + 4.0*$i/80.0)}]
  set d [expr {-3*atan($f)*180.0/$PI}]
  lappend wr [wrap $d] ; lappend truth [expr {[wrap [expr {[wrap $d] + 180}]] + 180}]
}
phase_db $wr
set got [evalcol neg "180 + dup() 180 > 360 * - $R 180 +"]
set want [list [lindex $truth 0]]
for {set i 1} {$i < 81} {incr i} {
  set p [lindex $want end] ; set q [lindex $truth $i]
  lappend want [expr {$q - 360.0*floor(($q - $p)/360.0 + 0.5)}]
}
check {PU7 phaseDegUnwrapped of the negated wave plus 180: starts near 358, ends near 92, no jump} \
  [list [expr {[maxdiff $got $want] < 1e-9}] [expr {round([lindex $got 0])}] \
        [expr {round([lindex $got end])}] [jumps $got]] {1 358 92 0}

set floor 9
if {$npass + $fail < $floor} {
  puts "FAIL: PUFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
