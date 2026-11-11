# phaseDegUnwrapped -- ADE's verb (src/calculator.tcl): a route-C row in
# calc::catalogue, whose recipe lifts a first point of -180 to +180 and then
# unwraps with cph(), and an infix call, `phaseDegUnwrapped(vf(out))`, which
# calc::ix_phase_call translates onto the signal's phase column.
# Spec: doc/claude/specs/calculator.md §7.2.
#   PU1      the catalogue row: name, category, route, returns, recipe
#   PU2-PU3  a phase that wraps: 1/(1+s)^3 (crosses the cut once) and
#            1/(1+s)^7 (crosses it twice), each against `cph()` sample by
#            sample and against the closed form
#   PU4      a first sample just either side of the cut
#   PU5      a first sample of exactly -180 becomes +180, and only that moves
#   PU6      real signals: phase 0 or +/-180
#   PU7      infix negation: the first point is the principal value of ph+180
#   PU8-PU9  infix: the translations, and the refusals
#   PU10     infix `phaseDegUnwrapped(-vf(x)) + 180` evaluated, against the
#            closed form of the negated wave's unwrapped phase plus 180
#   PU11     infix through the Outputs evaluator on the committed ac fixture
# The fixtures for PU2-PU10 are built in memory with `xschem raw new` +
# `xschem raw set`, in a column named `ph(x)` -- the name the raw reader gives
# the phase of v(x) -- so the phase it holds is exactly the value written here
# and the infix translation's own postfix can be evaluated on it unchanged.
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
# the unwrap written from ADE's definition: the first point's principal value,
# then each point on the branch nearest the one before
proc unwrap {l} {
  set out {}
  foreach y $l {
    if {$out eq {}} { lappend out [wrap $y] ; continue }
    set q [lindex $out end]
    lappend out [expr {$y - 360.0*floor(($y - $q)/360.0 + 0.5)}]
  }
  return $out
}
# a fresh in-memory database holding column `ph(x)` = the given phases
set ndb 0
proc phase_db {phs} {
  global ndb
  set n [llength $phs]
  xschem raw new pu[incr ndb] table x 0 [expr {$n - 1}] 1
  xschem raw add ph(x) {}
  set i 0
  foreach p $phs { xschem raw set x $i $i ; xschem raw set ph(x) $i $p ; incr i }
}
# evaluate a whole postfix text into a new column; read back through
# `raw values` (%.16g) as numbers in canonical form
proc evalrpn {name rpn} {
  xschem raw add $name $rpn
  return [lmap v [xschem raw values $name] {expr {double($v)}}]
}
proc evalcol {name rpn} { return [evalrpn $name "ph(x) $rpn"] }
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
# 1/(1+s)^k's phase in degrees, four decades around its pole, 81 points
proc pole_phase {k} {
  global PI
  set out {}
  for {set i 0} {$i < 81} {incr i} {
    set f [expr {pow(10.0, -2.0 + 4.0*$i/80.0)}]
    lappend out [expr {-$k*atan($f)*180.0/$PI}]
  }
  return $out
}
proc infix {t} {
  set r [calc::ix_route $t]
  if {[dict get $r mode] ne {infix}} { return [list [dict get $r mode] [dict get $r msg]] }
  return [dict get $r rpn]
}

# PU1 -- the row.  The recipe below is read from the catalogue, not restated.
set row [calc::fn_row phaseDegUnwrapped]
check {PU1 the catalogue row: Special Functions, route C, a wave, the anchored cph() recipe} \
  [lrange $row 0 4] {phaseDegUnwrapped {Special Functions} C wave {dup() -180 == 360 * + cph()}}
set R [lindex $row 4]

# PU2-PU3 -- 1/(1+s)^3 and 1/(1+s)^7.
foreach {id k cuts} {PU2 3 1 PU3 7 2} {
  set truth [pole_phase $k]
  set wr [lmap d $truth {wrap $d}]
  phase_db $wr
  set got [evalcol pdu $R]
  set ref [evalcol cph {cph()}]
  check "$id 1/(1+s)^$k: the wrapped phase crosses the cut $cuts time(s), the result never jumps" \
    [list [jumps $wr] [jumps $got]] [list $cuts 0]
  check "$id ...it equals `cph()` sample by sample, and runs to the closed form within 1e-9" \
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

# PU7 -- the infix negation folds the shifted phase itself: the first point of
# `phaseDegUnwrapped(-vf(x))` is the principal value of ph + 180 from every
# side of the cut, the cut itself included.
set out {}
foreach first {-180 -179 -1 0 1 179 180} {
  phase_db [list $first [expr {$first + 5}]]
  lappend out [lindex [evalrpn pdu [infix {phaseDegUnwrapped(-vf(x))}]] 0]
}
check {PU7 the negated wave's first point is the principal value of ph+180, cut included} \
  $out {0.0 1.0 179.0 180.0 -179.0 -1.0 0.0}

# PU8 -- infix translations.
check {PU8 infix reads the signal's phase column: vf(out), a quoted net, if(name), -vf(out), any case} \
  [lmap t {{phaseDegUnwrapped(vf(out))} {phaseDegUnwrapped(vf("out"))} {phaseDegUnwrapped(if(@m1[id]))}
           {phaseDegUnwrapped(-vf(out))+180} {PHASEDEGUNWRAPPED( vf(out) )}} {infix $t}] \
  [list "ph(out) $R" "ph(out) $R" "ph(i(@m1\[id\])) $R" "ph(out) 180 + dup() 180 > 360 * - $R 180 +" "ph(out) $R"]

# PU9 -- infix refusals: no shape answers the phase of anything but one AC signal.
set e1 {Cannot evaluate: phaseDegUnwrapped takes one AC signal, such as vf(out) or -vf(out).}
check {PU9 refused: an expression, a scaled signal, a constant, a non-AC or plain signal, two arguments} \
  [lmap t {{phaseDegUnwrapped(vf(a)/vf(b))} {phaseDegUnwrapped(2*vf(out))} {phaseDegUnwrapped(-1)}
           {phaseDegUnwrapped(vt(out))} {phaseDegUnwrapped(v(out))} {phaseDegUnwrapped(vf(a),1)}} {infix $t}] \
  [list [list refuse $e1] [list refuse $e1] [list refuse $e1] \
        {refuse {Cannot evaluate: phaseDegUnwrapped needs an AC signal; write vf(out).}} \
        {refuse {Cannot evaluate: phaseDegUnwrapped needs an AC signal; write vf(out).}} \
        {refuse {Cannot evaluate: phaseDegUnwrapped takes 1 argument.}}]

# PU10 -- `phaseDegUnwrapped(-vf(x)) + 180`, the translator's own postfix,
# evaluated on 1/(1+s)^3.  Negating the wave adds 180 to its phase.
set truth [pole_phase 3]
phase_db [lmap d $truth {wrap $d}]
set got [evalrpn neg [infix {phaseDegUnwrapped(-vf(x)) + 180}]]
set want [lmap v [unwrap [lmap d $truth {expr {$d + 180}}]] {expr {$v + 180}}]
check {PU10 infix phaseDegUnwrapped(-vf(x))+180 is the negated wave's unwrapped phase plus 180: about 358 down to 92} \
  [list [expr {[maxdiff $got $want] < 1e-9}] [expr {round([lindex $got 0])}] \
        [expr {round([lindex $got end])}] [jumps $got]] {1 358 92 0}

# PU11 -- through the Outputs evaluator on the committed ac fixture, whose
# ph(lp) column is the plain phase there; the analysis comes from vf().
set fx [file join [file dirname [info script]] data calc_fixture.raw]
set a [calc::eval_text {phaseDegUnwrapped(vf(lp))} $fx {}]
set b [calc::eval_text {ph(lp) cph()} $fx ac]
set c [calc::eval_text {phaseDegUnwrapped(-vf(lp))+180} $fx {}]
check {PU11 eval_text: phaseDegUnwrapped(vf(lp)) answers as ph(lp) cph() does, and -vf(lp)+180 is 360 above it} \
  [list [dict get $a ok] [dict get $a kind] [expr {[dict get $a value] == [dict get $b value]}] \
        [dict get $c ok] [expr {abs([dict get $c value] - [dict get $a value] - 360.0) < 1e-9}]] \
  {1 wave 1 1 1}

set floor 13
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
