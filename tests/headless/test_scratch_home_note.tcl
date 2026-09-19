## File: tests/headless/test_scratch_home_note.tcl
## Pins the two HOME rules tests/headless/scratch.tcl carries for the outsider
## fixes batch (doc/claude/outsider_fixes_batch/DECISIONS.md):
##
##   D9   a suite run UN-armed -- the bare `./src/xschem --script <t>.tcl`, which
##        no driver wraps -- prints ONE stderr line saying it is using the real
##        HOME and which command would give it a throwaway one. Armed runs (a
##        driver's throwaway, or the XSCHEM_TEST_HOME opt-out) print nothing.
##   D10  `test_real_home` names the tester's REAL home for read-only fixture
##        lookups, and honours XSCHEM_TEST_REAL_HOME only as an absolute,
##        existing directory.
##
## And the property the note's whole design rests on: it is never COUNTED. The
## line lands in every case log T1 scores and in the merged output the shell
## drivers classify, so the C rows feed the line a real child actually printed
## -- not a copy of it written here -- through each reader's OWN code:
## run_regression.tcl's summarize_all (extracted and evaluated),
## tests/banner_rule.tcl, full_audit.sh's classify (AUDIT_LIB_ONLY), and
## run_suites.sh's EREs (extracted from its source). The `skip:` lines D10 added
## to five suites get the same treatment, built from their own source with every
## variable replaced by a hostile value.
##
##   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_scratch_home_note.tcl
##
## Every child runs with a HOME made here, under this suite's scratch dir.

source [file join [file dirname [info script]] scratch.tcl]
source [file join [file dirname [info script]] .. banner_rule.tcl]

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set xbin    [info nameofexecutable]
set scratch [test_scratch homenote]

set npass 0 ; set fail 0
proc check {name got want} {
  global npass fail
  if {$got eq $want} {
    puts "ok:   $name"
    incr npass
  } else {
    puts "FAIL: $name -> {$got} (exp {$want})"
    incr fail
  }
}
proc slurp {p} {
  if {[catch {open $p r} f]} { return {} }
  set t [read $f] ; close $f ; return $t
}
proc wr {p body} { set f [open $p w] ; puts -nonewline $f $body ; close $f ; return $p }

## The exact D9 sentence, with the suite's bare name in it.
proc note_for {name} {
  return "note: this suite is using your real HOME; tests/headless/run_suites.sh $name gives it a throwaway one"
}
proc count_notes {txt} {
  return [regexp -all -line {^note: this suite is using your real HOME;} $txt]
}

## Run one child with exactly this HOME / XSCHEM_TEST_REAL_HOME / XSCHEM_TEST_HOME
## ({} = unset, {""} = set but empty) and return {rc stdout stderr}. The three
## are restored on every path.
proc run_child {fixture home real testhome} {
  global xbin scratch
  set saved {}
  foreach v {HOME XSCHEM_TEST_REAL_HOME XSCHEM_TEST_HOME} {
    if {[info exists ::env($v)]} { lappend saved $v 1 $::env($v) } else { lappend saved $v 0 {} }
  }
  set ::env(HOME) $home
  foreach {v val} [list XSCHEM_TEST_REAL_HOME $real XSCHEM_TEST_HOME $testhome] {
    if {$val eq {}} {
      catch {unset ::env($v)}
    } elseif {$val eq {""}} {
      set ::env($v) {}
    } else {
      set ::env($v) $val
    }
  }
  set of [file join $scratch child.out] ; set ef [file join $scratch child.err]
  file delete -force $of $ef
  set rc 0
  if {[catch {exec timeout --kill-after=5 60 $xbin --nogui --pipe -q --nolog \
                   --script $fixture > $of 2> $ef} msg opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  foreach {v had val} $saved {
    if {$had} { set ::env($v) $val } else { catch {unset ::env($v)} }
  }
  return [list $rc [slurp $of] [slurp $ef]]
}

set srcline "source [list [file join $here scratch.tcl]]"
set fx_once [wr [file join $scratch hn_once.tcl] \
  "$srcline\nputs \"ARMED=\[__scratch_home_armed\]\"\nputs \"REAL=\[test_real_home\]\"\nputs {OVERALL: ok}\nexit 0\n"]
set fx_twice [wr [file join $scratch hn_twice.tcl] \
  "$srcline\n$srcline\nputs {OVERALL: ok}\nexit 0\n"]

## The homes. Every one of them lives in this suite's scratch dir.
set plain  [file join $scratch plainhome]
set thrown [file join $scratch xschem-test-home.4242.QmZxKe]
set nopid  [file join $scratch xschem-test-home.notapid.QmZxKe]
set realh  [file join $scratch realhome]
set custom [file join $scratch customhome]
foreach d [list $plain $thrown $nopid $realh $custom] { file mkdir $d }

# =============================================================================
# N -- the armed matrix: who prints the note, and how many times
# =============================================================================
## Each row is {id home real testhome expected-note-count why}.
set N_rows [list \
  [list N1 $plain  {}     {}      1 "bare command: plain HOME, nothing set"] \
  [list N2 $thrown $realh {}      0 "a driver's throwaway: pattern HOME and XSCHEM_TEST_REAL_HOME"] \
  [list N3 $thrown {}     {}      1 "pattern HOME but no XSCHEM_TEST_REAL_HOME is not armed"] \
  [list N4 $plain  $realh {}      1 "XSCHEM_TEST_REAL_HOME alone does not arm a plain HOME"] \
  [list N5 $plain  {}     real    0 "XSCHEM_TEST_HOME=real, the opt-out, has its own banner"] \
  [list N6 $plain  {}     $custom 0 "XSCHEM_TEST_HOME=<dir>, the custom home, has its own banner"] \
  [list N7 $plain  {}     {""}    1 "an EMPTY XSCHEM_TEST_HOME counts as unset"] \
  [list N8 $nopid  $realh {}      1 "xschem-test-home.<non-pid>.* is not the pattern"] \
]
set N1_err {}
foreach r $N_rows {
  lassign $r id home real th want why
  lassign [run_child $fx_once $home $real $th] rc out err
  if {$id eq {N1}} { set N1_err $err }
  set armed -1
  regexp -line {^ARMED=([01])$} $out -> armed
  check "$id $why: rc, note lines on stderr, note lines on stdout, armed" \
    [list $rc [count_notes $err] [count_notes $out] $armed] \
    [list 0 $want 0 [expr {$want ? 0 : 1}]]
}

## N9: the note is the EXACT D9 sentence, naming the suite that printed it, on a
## line of its own. (xschem's own startup lines share stderr -- `Using run time
## directory ...`, `Sourcing ...` -- so the row picks the note out by its prefix
## and then demands the whole line.)
set N1_note [lsearch -all -inline -glob [split $N1_err "\n"] {note: this suite *}]
check "N9 the un-armed line is exactly D9's sentence, naming the suite" \
  $N1_note [list [note_for hn_once]]

## N10: sourcing scratch.tcl twice still says it once.
lassign [run_child $fx_twice $plain {} {}] rc out err
check "N10 a second source of scratch.tcl does not repeat the note" \
  [list $rc [count_notes $err]] {0 1}

# =============================================================================
# R -- test_real_home (in this process; it reads ::env at call time)
# =============================================================================
proc with_env {pairs body} {
  set saved {}
  foreach {v val} $pairs {
    if {[info exists ::env($v)]} { lappend saved $v 1 $::env($v) } else { lappend saved $v 0 {} }
    if {$val eq {}} { catch {unset ::env($v)} } else { set ::env($v) $val }
  }
  set rc [catch {uplevel 1 $body} r]
  foreach {v had val} $saved {
    if {$had} { set ::env($v) $val } else { catch {unset ::env($v)} }
  }
  if {$rc} { return "RAISED:$r" }
  return $r
}
check "R1 an absolute, existing XSCHEM_TEST_REAL_HOME is the real home" \
  [with_env [list HOME $thrown XSCHEM_TEST_REAL_HOME $realh] {test_real_home}] $realh
check "R2 unset, the real home is HOME" \
  [with_env [list HOME $plain XSCHEM_TEST_REAL_HOME {}] {test_real_home}] $plain
check "R3 a flag-shaped value (=1) is NOT read as a path" \
  [with_env [list HOME $plain XSCHEM_TEST_REAL_HOME 1] {test_real_home}] $plain
check "R4 a path that does not exist is not the real home" \
  [with_env [list HOME $plain XSCHEM_TEST_REAL_HOME [file join $scratch nosuch]] {test_real_home}] $plain
## and the child agrees with the in-process answer, through the environment
lassign [run_child $fx_once $thrown $realh {}] rc out err
set creal {}
regexp -line {^REAL=(.*)$} $out -> creal
check "R5 a driven child's test_real_home is the carried real home" $creal $realh

# =============================================================================
# C -- nothing that reads a suite's output counts either line
# =============================================================================
## The lines under test: the note a real child printed (N1), and every `skip:`
## template the D10 suites carry, taken from their source with each variable
## replaced by a value built to end in a counted shape or begin with one.
set LINES [list]
foreach l $N1_note { lappend LINES $l }
set skip_srcs [list test_ase_converge_1459.tcl test_ase_sp_1452.tcl test_vcd_read.tcl \
                    test_vcd_time_base.tcl test_ase_cosim.tcl test_launch_context.tcl]
set per_src {}
foreach s $skip_srcs {
  set n 0
  foreach {-> tpl} [regexp -all -inline {puts "(skip: [^"]*)"} [slurp [file join $here $s]]] {
    incr n
    foreach hostile {FAIL {GOLD?} {RESULT?} FATAL} {
      ## backslash escapes are resolved as `puts` would, so a `\n` inside a
      ## template reaches the readers as the extra line it really prints
      set l [regsub -all {\$(::)?\{?[A-Za-z_][A-Za-z0-9_:]*\}?} $tpl $hostile]
      lappend LINES [subst -nocommands -novariables $l]
    }
  }
  lappend per_src [expr {$n > 0}]
}
## Non-vacuity: a template the regexp cannot find is a line nothing below checks.
check "C0 the note a child printed, and a skip: line from each of the [llength $skip_srcs] D10 suites, are all here to be read" \
  [list [llength $N1_note] [lsort -unique $per_src]] {1 1}

## C1 -- T1: run_regression.tcl's OWN summarize_all, lifted out of the file and
## evaluated, over a case log holding every line above.
set RR [slurp [file join $repo tests run_regression.tcl]]
set sa_code {}
set i [string first "proc summarize_all " $RR]
if {$i >= 0} {
  set acc {}
  foreach l [split [string range $RR $i end] "\n"] {
    append acc $l "\n"
    if {[info complete $acc]} { break }
  }
  set sa_code $acc
}
set t1_counted -1
if {$sa_code ne {}} {
  namespace eval ::t1probe {}
  set ::t1_blocks 0 ; set ::t1_failures 0
  if {![catch {namespace eval ::t1probe $sa_code}]} {
    set caselog [wr [file join $scratch case.log] "[join $LINES \n]\nOVERALL: ok\n"]
    set vf [open [file join $scratch verdict.log] w]
    catch {set t1_counted [::t1probe::summarize_all $caselog $vf case.log]}
    close $vf
  }
}
check "C1 T1's own summarize_all counts none of the [llength $LINES] lines (FAIL\$ GOLD?\$ RESULT?\$ ^FATAL)" \
  [list [expr {$sa_code ne {}}] $t1_counted] {1 0}

## C2 -- tests/banner_rule.tcl: neither line is a death, and neither turns a
## passing case into a failed one.
set c2 {}
foreach l $LINES {
  lappend c2 [banner_died $l] [regression_case_failed 0 "$l\nOVERALL: ok\n"]
}
check "C2 banner_rule: no line is a death, none fails a passing case" \
  [lsort -unique $c2] 0

## C3 -- full_audit.sh's classify, through AUDIT_LIB_ONLY, exactly as
## test_audit_classifier.tcl drives it: a line beside a passing banner still
## scores PASS, and a line with no banner is not mistaken for a skip.
set FA [file join $here full_audit.sh]
set SNIPPET {
AUDIT_LIB_ONLY=1
. "$1" >/dev/null 2>&1 || exit 91
echo "VERDICT=$(classify "$3" "$2" 0)"
if is_skip "$2"; then echo SKIP=YES; else echo SKIP=NO; fi
if has_failure "$2"; then echo FAILURE=YES; else echo FAILURE=NO; fi
}
set c3 {}
foreach l $LINES {
  set out {}
  catch {exec env -u DISPLAY XSCHEM=/bin/true timeout 20 \
              bash -c $SNIPPET _ $FA "$l\nRESULT: ALL PASS (1 checks)" probe 2>@1} out
  set v ? ; set sk ? ; set fl ?
  regexp {VERDICT=([A-Z]+)} $out -> v
  regexp {SKIP=([A-Z]+)} $out -> sk
  regexp {FAILURE=([A-Z]+)} $out -> fl
  lappend c3 "$v/$sk/$fl"
}
check "C3 full_audit.sh classify: every line beside a pass banner is PASS, no skip, no failure" \
  [lsort -unique $c3] PASS/NO/NO

## C4 -- run_suites.sh's VERDICT EREs, extracted from its source: none matches
## a line. ONE ERE is set aside by name, `^skip:`: since DECISIONS D13.11
## run_suites.sh echoes every `skip:` line indented UNDER the verdict it has
## already printed, so matching these lines is that ERE's whole job and it
## scores nothing. (C4 counted it among the classifiers until the S2c-R2-I
## integration, and went red on every full_audit.sh once D13.11 landed.) C5
## holds the other half: the echo is there, and it takes skip: lines only.
set RSsrc [slurp [file join $here run_suites.sh]]
set eres {} ; set echo_re {}
foreach {-> re} [regexp -all -inline {grep -q?E '([^']+)'} $RSsrc] {
  if {$re eq {^skip:}} { set echo_re $re } else { lappend eres $re }
}
set c4 {}
foreach l $LINES {
  foreach re $eres {
    if {![catch {exec grep -qE -- $re << $l}]} { lappend c4 "$re matched: $l" }
  }
}
check "C4 run_suites.sh: its [llength $eres] verdict EREs match none of the lines" \
  [list [expr {[llength $eres] >= 5}] $c4] {1 {}}

## C5 -- D13.11: the echo ERE exists and matches exactly the `skip:` lines, so
## the documented single-suite command shows every row a suite could not run.
set c5 {} ; set nskip 0
foreach l $LINES {
  set m [expr {$echo_re ne {} && ![catch {exec grep -qE -- $echo_re << $l}]}]
  set want [string match {skip:*} $l]
  incr nskip $want
  if {$m != $want} { lappend c5 "matched=$m: $l" }
}
check "C5 run_suites.sh echoes every skip: line under its verdict (D13.11), and only those" \
  [list [expr {$echo_re ne {}}] [expr {$nskip >= 6}] $c5] {1 1 {}}

puts "----"
puts "test_scratch_home_note: $npass passed, $fail failed"
## The whole-line completion banner T1 and run_suites.sh score on
## (tests/banner_rule.tcl): without it this suite is a counted HARNESS FAIL
## the moment it is registered, however green its rows (measured, S2c-T).
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
