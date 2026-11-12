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
#   RS6      a bench whose own text sets the seed or re-draws under it gets no
#            default: a `reset` or `mc_source` or `option seed=` in its
#            pre-commands, an enabled row's verbatim lines or the netlist's own
#            .control, or a netlist option card naming the seed; look-alikes
#            (a bare `setseed`, a `reset` mid-line, `resetx`, a device called
#            `reset`, `.param seed=`, `rseed=`, a disabled row's verbatim
#            `reset`, a seed after an inline comment marker, a `+ seed=` that
#            continues a device) keep it; case and `+` continuations of an
#            option card are read as ngspice reads them
#   RS6b     the options preview, given the netlist, agrees with the deck
#   RS7      on a real ngspice, `setseed 42` then `reset` in the pre-commands
#            draws what seed 42 draws, not what the default's seed draws
#   RS8      on a real ngspice, a hand-written `reset` loop in the
#            pre-commands draws a new value on each pass
#   RS9      the ASE-L window's preview reads the netlist the next run renders
#            from (<rundir>/<cell>.spice), writes nothing, and follows a change
#            to it: a netlist that resets or carries a seed card drops the
#            default, a plain one keeps it
#   RS10     that reader creates no directory and moves no global (R602e)
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

# RS6 -- the bench's own text. Each case is a state and a netlist; the answer
# is how many default seed lines the rendered deck carries.
proc rs_ndefault {st nl} {
  global scratch
  set d [file join $scratch rdeck6] ; file mkdir $d
  dict set st rundir $d
  if {[catch {ase::backend::ngspice::render_deck $st $nl} deck]} { return "RAISED:$deck" }
  set n 0
  foreach l [split $deck "\n"] {
    if {$l eq ".options seed=[ase::run_seed_default]"} { incr n }
  }
  return $n
}
set got {} ; set want {}
foreach {label st nl n} [list \
  pre-reset      [rs_state pre_commands [list "setseed 42" reset]]     $NL 0 \
  pre-mc_source  [rs_state pre_commands [list "setseed 42" mc_source]] $NL 0 \
  pre-option     [rs_state pre_commands [list "option seed=5"]]        $NL 0 \
  verbatim-reset [rs_state analyses {{type op enabled 1 x {reset}}}]  $NL 0 \
  netlist-ctl    [rs_state] "* t\nr1 a 0 1k\n.control\nsetseed 9\nreset\n.endc\nv1 a 0 1\n.end\n" 0 \
  netlist-card   [rs_state] "* t\nr1 a 0 1k\n.option method=gear seed=5\nv1 a 0 1\n.end\n" 0 \
  bare-setseed   [rs_state pre_commands [list "setseed 42"]]           $NL 1 \
  echo-reset     [rs_state pre_commands [list "echo no reset here"]]   $NL 1 \
  device-reset   [rs_state] "* t\nreset a 0 1k\nv1 a 0 1\n.end\n"  1 \
  param-seed     [rs_state] "* t\n.param seed=5\nr1 a 0 1k\nv1 a 0 1\n.end\n" 1 \
  disabled-row   [rs_state analyses {{type op enabled 1} {type tran enabled 0 x {reset}}}] $NL 1 \
  card-in-ctl    [rs_state] "* t\nr1 a 0 1k\n.control\n.options seed=5\n.endc\nv1 a 0 1\n.end\n" 0 \
  reset-word     [rs_state pre_commands [list "resetx 1"]]             $NL 1 \
  card-upper     [rs_state] "* t\nr1 a 0 1k\n.OPTIONS SEED=5\nv1 a 0 1\n.end\n" 0 \
  card-rseed     [rs_state] "* t\nr1 a 0 1k\n.options rseed=5\nv1 a 0 1\n.end\n" 1 \
  card-dollar    [rs_state] "* t\nr1 a 0 1k\n.options method=gear \$ seed=5\nv1 a 0 1\n.end\n" 1 \
  card-semi      [rs_state] "* t\nr1 a 0 1k\n.options method=gear ; seed=5\nv1 a 0 1\n.end\n" 1 \
  card-slash     [rs_state] "* t\nr1 a 0 1k\n.options method=gear // seed=5\nv1 a 0 1\n.end\n" 1 \
  card-note      [rs_state] "* t\nr1 a 0 1k\n.options seed=5 \$ chosen\nv1 a 0 1\n.end\n" 0 \
  card-plus      [rs_state] "* t\nr1 a 0 1k\n.options method=gear\n+ seed=5\nv1 a 0 1\n.end\n" 0 \
  device-plus    [rs_state] "* t\nr1 a 0 1k\n+ seed=5\nv1 a 0 1\n.end\n" 1 \
  pre-semi       [rs_state pre_commands [list "option reltol=1e-3 ; seed=5"]] $NL 1 \
  plain          [rs_state] $NL 1 \
] {
  lappend got "$label=[rs_ndefault $st $nl]" ; lappend want "$label=$n"
}
check {RS6 a bench whose own text sets or re-draws the seed gets no default; look-alikes keep it} \
  $got $want
# Two previews of one bench: given a netlist that seeds nothing, and given one
# whose own .control resets. The first must show the default (so the second's
# absence is the rule, not a preview that failed or shows nothing).
proc rs_pv_seeds {nl} {
  if {[catch {ase::opt_preview ngspice [rs_state] {} $nl} p]} { return RAISED }
  set n 0
  foreach e [dict get $p deck] {
    if {[string equal -nocase [lindex $e 0] seed]} { incr n }
  }
  return $n
}
check {RS6b the options preview, given the netlist, drops the default exactly as the deck does} \
  [list [rs_pv_seeds $NL] \
        [rs_pv_seeds "* t\nr1 a 0 1k\n.control\nreset\n.endc\nv1 a 0 1\n.end\n"]] {1 0}

# RS7, RS8 -- what the rule is for, on a real ngspice. The netlist draws a
# Gaussian resistor at every parse; the bench's pre-commands print it.
proc rs_run_pre {pre} {
  global scratch ng
  set d [file join $scratch rdeck7] ; file mkdir $d
  set nl "* draw\n.param rv=agauss(1000,100,1)\nr1 a 0 {rv}\nv1 a 0 1\n.end\n"
  set st [rs_state pre_commands $pre rundir $d]
  if {[catch {ase::backend::ngspice::render_deck $st $nl} deck]} { return "RAISED:$deck" }
  set f [file join $d deck7.sp]
  set fd [open $f w] ; puts $fd $deck ; close $fd
  if {[catch {exec env -u DISPLAY {*}$ng -b $f 2>@1} out]} { set out $out }
  return [regexp -all -inline {@r1\[resistance\]\s*=\s*\S+} $out]
}
if {$ng eq {}} {
  puts "skip: RS7 RS8 need ngspice on PATH"
} else {
  set v42 [rs_draw ".options seed=42"]
  set v1  [rs_draw ".options seed=[ase::run_seed_default]"]
  set r7 {}
  regexp {=\s*(\S+)} [lindex [rs_run_pre [list "setseed 42" reset op \
                                  "print @r1\[resistance\]"]] 0] -> r7
  check {RS7 setseed 42 then reset in the pre-commands draws seed 42's value, which is not the default's} \
    [list [expr {$r7 eq $v42}] [expr {$v42 ne $v1 && $v42 ne {NOVALUE}}]] {1 1}
  set pr [list op "print @r1\[resistance\]" reset op "print @r1\[resistance\]"]
  set r8 [rs_run_pre $pr]
  check {RS8 a hand-written reset loop in the pre-commands draws a new value on each pass} \
    [list [llength $r8] [expr {[lindex $r8 0] ne [lindex $r8 1]}]] {2 1}
}

# RS9 -- the window's reader, ase::ui::optsheet_netlist_text, through a real
# session. Three reads of one key: before any netlist, after a netlist whose
# .control resets, after that file is replaced by a plain one (a different
# size, so the remembered copy must be dropped).
proc rs_pv_key {key} {
  if {[catch {ase::opt_preview ngspice [ase::session_state $key] {} \
                [ase::ui::optsheet_netlist_text $key]} p]} { return RAISED }
  set n 0
  foreach e [dict get $p deck] {
    if {[string equal -nocase [lindex $e 0] seed]} { incr n }
  }
  return $n
}
set r9 {}
if {[catch {
  set rd9 [file join $scratch run9] ; file mkdir $rd9
  set st9 [rs_state rundir $rd9]
  dict set st9 design cell rs9
  set p9 [file join $scratch rs9.state]
  ase::state_save $p9 $st9
  ase::session_open rs9 $p9
  ase::session_update rs9 $st9
  lappend r9 none=[rs_pv_key rs9]
  set f9 [file join $rd9 rs9.spice]
  set fd [open $f9 w]
  puts -nonewline $fd "* t\nr1 a 0 1k\n.CONTROL\nsetseed 9\nRESET\n.ENDC\nv1 a 0 1\n.end\n"
  close $fd
  set before [lsort [glob -nocomplain -directory $rd9 *]]
  lappend r9 resets=[rs_pv_key rs9]
  lappend r9 wrote=[expr {[lsort [glob -nocomplain -directory $rd9 *]] ne $before}]
  set fd [open $f9 w] ; puts -nonewline $fd "* card\nr1 a 0 1k\n.option method=gear\n+ seed=5\n.end\n" ; close $fd
  lappend r9 card=[rs_pv_key rs9]
  set fd [open $f9 w] ; puts -nonewline $fd "* plain\nr1 a 0 1k\nv1 a 0 1\n.end\n" ; close $fd
  lappend r9 plain=[rs_pv_key rs9]
} e9]} { lappend r9 RAISED:$e9 }
check {RS9 the window's preview reads the run's netlist, writes nothing, and follows its changes} \
  $r9 {none=1 resets=0 wrote=0 card=0 plain=1}

# RS10 -- and the reader is a query (R602e, the rule above
# ase::ui::rsel_resolve_input): a bench whose run directory does not exist, and
# one that names none, are previewed without a directory being created and
# without ::netlist_dir moving.
set r10 {}
if {[catch {
  set gone [file join $scratch run10_missing]
  set st10 [rs_state rundir $gone]
  dict set st10 design cell rs10
  set p10 [file join $scratch rs10.state]
  ase::state_save $p10 $st10
  ase::session_open rs10 $p10
  ase::session_update rs10 $st10
  ## Start from no netlist directory chosen yet (xschemrc presets one), so the
  ## leg can see set_netlist_dir choosing one.
  set nd_saved $::netlist_dir
  set ::netlist_dir {}
  set nd0 $::netlist_dir
  set sims [file join $::USER_CONF_DIR simulations]
  set sims0 [file exists $sims]
  rs_pv_key rs10
  lappend r10 missing_made=[file exists $gone]
  dict set st10 rundir {}
  ase::session_update rs10 $st10
  rs_pv_key rs10
  lappend r10 nd_moved=[expr {([info exists ::netlist_dir] ? $::netlist_dir : {<unset>}) ne $nd0}]
  lappend r10 sims_made=[expr {[file exists $sims] != $sims0}]
  set ::netlist_dir $nd_saved
} e10]} { lappend r10 RAISED:$e10 }
check {RS10 previewing a bench with a missing or no run directory creates nothing and moves no global} \
  $r10 {missing_made=0 nd_moved=0 sims_made=0}

set floor 8
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
