# tests/headless/test_ase_run_seed.tcl -- an ordinary ASE-L run is repeatable.
#
# A sky130 `tt_mm` section sets MC_MM_SWITCH=1, so every device draws a random
# mismatch offset when the netlist loads, and ngspice picks a new seed each run
# unless the deck gives one. Unseeded, every Run of such a bench was a fresh
# Monte Carlo trial, and about one tb_bandgap trial in 24 failed to converge
# (doc/claude/FAQ.md Q93). The user's ruling, 2026-11-11: "tt_mm should give
# same result each time". ase::run_seed_state (src/ase.tcl) adds the
# simulator's seed option to a run that has none.
#   RS1      a plain run's deck carries the default seed, once
#   RS2      a seed the bench already sets is kept, a number or `random`
#   RS3      a campaign shard is left alone, seeded or deliberately unseeded
#   RS4      the options preview shows the same seed line the deck writes
#   RS5      the line works: the same deck twice gives the same mismatch draw,
#            and without the line two runs differ (needs ngspice on PATH)
# Run: tests/headless/run_suites.sh --nogui test_ase_run_seed

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}

set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch runseed]
catch {ase::sim_clear}

proc rs_state {args} {
  set st [dict create design [dict create lib L cell c1 view schematic] \
                      simulator ngspice rundir {} options {} \
                      analyses {{type op enabled 1}} outputs {} temperature 27]
  foreach {k v} $args { dict set st $k $v }
  return $st
}
set NL "* t\nr1 a 0 1k\nv1 a 0 1\n.end\n"
proc rs_deck {st} {
  global NL scratch
  set d [file join $scratch rdeck] ; file mkdir $d
  dict set st rundir $d
  if {[catch {ase::backend::ngspice::render_deck $st $NL} deck]} { return "RAISED:$deck" }
  return $deck
}
# the deck's seed lines, in order
proc rs_seeds {st} {
  set out {}
  foreach l [split [rs_deck $st] "\n"] {
    if {[regexp -nocase {^\.options?\s+seed\y} $l]} { lappend out $l }
  }
  return $out
}

# RS1 -- a plain run.
check {RS1 a run with no seed of its own is given the default seed, once} \
  [list [ase::run_seed_default] [rs_seeds [rs_state]]] \
  [list 1 [list ".options seed=[ase::run_seed_default]"]]

# RS2 -- the bench's own seed wins.
check {RS2 a seed the bench sets is kept as it is: a number, and the word random} \
  [list [rs_seeds [rs_state options {{name seed value 7}}]] \
        [rs_seeds [rs_state options {{name SEED value random}}]]] \
  {{{.options seed=7}} {{.options SEED=random}}}

# RS3 -- a campaign shard: `sweep` names a point. Unseeded, it must stay
# unseeded (each shard its own sample); seeded, it keeps its campaign's seed.
set sw [dict create axes {{kind temperature}} point {27} index 3]
check {RS3 a campaign shard is not given the default: unseeded stays unseeded, seeded keeps its seed} \
  [list [rs_seeds [rs_state sweep $sw]] \
        [rs_seeds [rs_state sweep $sw options {{name seed value 42}}]]] \
  {{} {{.options seed=42}}}

# RS4 -- the options sheet's preview shows every line the deck contains, so it
# shows this one, says ASE-L added it, and the bench's own rows (the plan) do
# not carry it: the bench did not ask for it.
set pv {} ; set note {} ; set inplan 0
catch {
  set p [ase::opt_preview ngspice [rs_state]]
  foreach e [dict get $p deck] {
    if {[string equal -nocase [lindex $e 0] seed]} { lappend pv [lindex $e 1] }
  }
  foreach n [dict get $p notes] {
    if {[string equal -nocase [lindex $n 0] seed]} { set note [lindex $n 1] }
  }
}
catch {
  foreach rec [ase::opt_deck_plan ngspice [rs_state]] {
    if {[string equal -nocase [lindex $rec 0] seed]} { set inplan 1 }
  }
}
check {RS4 the options preview shows the seed line the deck writes, noted as ASE-L's, outside the bench's own rows} \
  [list $pv $note $inplan] [list [rs_seeds [rs_state]] default 0]

# RS5 -- the line does what it is for. A resistor with a Gaussian value is the
# smallest mismatch draw; the seed line is the one the deck above wrote.
set ng [auto_execok ngspice]
if {$ng eq {}} {
  puts "skip: RS5 needs ngspice on PATH"
} else {
  proc rs_draw {seedline} {
    global scratch ng
    set f [file join $scratch draw.sp]
    set fd [open $f w]
    puts $fd "* draw\n.param rv=agauss(1000,100,1)\nr1 a 0 {rv}\nv1 a 0 1\n$seedline"
    puts $fd ".control\nop\nprint @r1\[resistance\]\n.endc\n.end"
    close $fd
    if {[catch {exec env -u DISPLAY {*}$ng -b $f 2>@1} out]} { set out $out }
    if {[regexp {@r1\[resistance\]\s*=\s*(\S+)} $out -> v]} { return $v }
    return "NOVALUE"
  }
  set line [lindex [rs_seeds [rs_state]] 0]
  set a [rs_draw $line] ; set b [rs_draw $line]
  set c [rs_draw {}] ; set d [rs_draw {}]
  check {RS5 with the seed line two runs draw the same value; without it they differ} \
    [list [expr {$a eq $b && $a ne {NOVALUE}}] [expr {$c ne $d && $c ne {NOVALUE}}]] {1 1}
}

set floor 4
if {$npass + $fail < $floor} {
  puts "FAIL: RSFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
