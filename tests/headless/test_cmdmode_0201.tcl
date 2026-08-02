# cmdmode — the generic command-mode suspend/resume contract, on its own.
# doc/claude/issues/0201-no-command-suspend-resume-contract.md
#
# Pure Tcl: no C, no schematic, no canvas, no Tk. It exercises src/cmdmode.tcl against
# STUB modes, so nothing here depends on ASE, the waveform viewer or a display — which is
# the point of D1 (the contract must be usable by anything, not be ASE glue).
#
# Legs (CR*):
#   CR1a-CR1c  register / registered / unregister
#   CR1d-CR1f  suspend_all releases only the LIVE modes, and reports how many
#   CR1g-CR1i  resume_all puts back exactly those, LIFO, with the canvas argument
#   CR1j-CR1l  the D6 latch: double suspend is a no-op, stray resume is a no-op
#   CR1m-CR1n  resume_all's default canvas, and an explicit one
#   CR2a-CR2c  a THROWING suspend arm does not strand the others and is not resumed
#   CR2d-CR2e  a THROWING resume arm does not stop the ones after it
#   CR2f       unregister while suspended: the mode is not resumed by a dead callback
#   CR3a-CR3c  rehome: re-homes live modes, no-op while a suspend is in flight
#
# Standalone repro from the repo ROOT (either form):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_cmdmode_0201.tcl
#   tclsh tests/headless/test_cmdmode_0201.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

# Source the file under test ONLY if the binary has not already loaded it. Re-sourcing
# would re-initialise the namespace variables and silently drop ASE's real registration,
# which the DISPLAY-gated sibling (test_cmdmode_descend_0201.tcl) then depends on.
# RED-first: before the wiring lands, the procs are simply undefined and every leg errors.
if {[info commands cmdmode::register] eq {}} {
  set here [file dirname [file normalize [info script]]]
  set f [file join $here .. .. src cmdmode.tcl]
  if {[file exists $f]} { source $f }
}
proc val {body} { if {[catch {uplevel 1 $body} r]} { return "ERR: $r" } ; return $r }

# --- stub modes -----------------------------------------------------------------------
# Each records what it was told, so the legs can assert on ORDER and on ARGUMENTS, not
# just on counts. `live` is the suspend arm's return value: the contract's "was there
# anything to release?".
set ::trace {}
proc mk {name live} {
  proc sus_$name {} "lappend ::trace sus:$name; return $live"
  proc res_$name {cv} "lappend ::trace res:$name:\$cv; return 1"
}
mk a 1
mk b 0        ;# registered but not live -> must be suspended-asked, never resumed
mk c 1
proc sus_boom {}   { lappend ::trace sus:boom; error "suspend exploded" }
proc res_boom {cv} { lappend ::trace res:boom:$cv; return 1 }
proc sus_ok    {}  { lappend ::trace sus:ok; return 1 }
proc res_boom2 {cv} { lappend ::trace res:boom2:$cv; error "resume exploded" }

proc clear_all {} {
  foreach k [cmdmode::registered] { cmdmode::unregister $k }
  catch {cmdmode::resume_all}      ;# drop any latch a previous leg left standing
  set ::trace {}
}

if {[catch {

# --- CR1a-CR1c: registration ----------------------------------------------------------
clear_all
check "CR1a registered is empty to start" [cmdmode::registered] {}
cmdmode::register a sus_a res_a
cmdmode::register b sus_b res_b
check "CR1b register keeps insertion order" [cmdmode::registered] {a b}
cmdmode::unregister b
check "CR1c unregister drops just that one" [cmdmode::registered] {a}
check_true "CR1c2 an empty key is refused" [string match "ERR:*" [val {cmdmode::register {} x y}]]
check_true "CR1c3 a missing resume cb is refused" [string match "ERR:*" [val {cmdmode::register z sus_a {}}]]

# --- CR1d-CR1i: the round trip --------------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
cmdmode::register b sus_b res_b        ;# not live
cmdmode::register c sus_c res_c
check "CR1d suspend_all counts only the LIVE modes" [cmdmode::suspend_all] 2
check "CR1e every registered mode was ASKED, in registration order" $::trace {sus:a sus:b sus:c}
check "CR1f the pending list is the live ones, newest first" [cmdmode::pending] {c a}
set ::trace {}
check "CR1g resume_all resumes exactly those" [cmdmode::resume_all .x1.drw] 2
check "CR1h resume is LIFO and carries the canvas" $::trace {res:c:.x1.drw res:a:.x1.drw}
check "CR1i the not-live mode was never resumed" [string match "*res:b*" $::trace] 0

# --- CR1j-CR1l: the D6 latch ----------------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
check "CR1j not suspended to start" [cmdmode::is_suspended] 0
check "CR1k1 first suspend releases 1" [cmdmode::suspend_all] 1
check "CR1k2 the latch is up" [cmdmode::is_suspended] 1
set ::trace {}
check "CR1k3 a second suspend is a no-op" [cmdmode::suspend_all] 0
check "CR1k4 and it did not call the arm again" $::trace {}
check "CR1k5 one resume clears it" [cmdmode::resume_all] 1
check "CR1k6 the latch is down" [cmdmode::is_suspended] 0
set ::trace {}
check "CR1l a second resume is a no-op" [cmdmode::resume_all] 0
check "CR1l2 and it did not call the arm again" $::trace {}

# --- CR1m-CR1n: the canvas argument ---------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
cmdmode::suspend_all
set ::trace {}
cmdmode::resume_all
# With no argument resume_all reads `xschem get current_win_path` itself -- under the
# binary that is a real canvas path, under bare tclsh the command does not exist and the
# catch leaves it empty. Either way the arm is CALLED with exactly one argument.
check_true "CR1m default canvas: the arm still ran with one argument" \
  [regexp {^res:a:} [lindex $::trace 0]]
check "CR1n2 exactly one resume happened" [llength $::trace] 1

# --- CR2a-CR2c: a throwing suspend arm ------------------------------------------------
clear_all
cmdmode::register boom sus_boom res_boom
cmdmode::register a    sus_a    res_a
check "CR2a a throwing suspend does not abort the sweep" [cmdmode::suspend_all] 1
check "CR2b the modes after it were still asked" $::trace {sus:boom sus:a}
check "CR2c the thrower is NOT queued for resume" [cmdmode::pending] {a}
set ::trace {}
cmdmode::resume_all .drw
check "CR2c2 and it is not resumed -- a half-released seize stays down" $::trace {res:a:.drw}

# --- CR2d-CR2e: a throwing resume arm -------------------------------------------------
clear_all
cmdmode::register boom2 sus_ok  res_boom2
cmdmode::register a     sus_a   res_a
cmdmode::suspend_all
set ::trace {}
check "CR2d a throwing resume is not counted, the rest still are" [cmdmode::resume_all .drw] 1
check "CR2e the arms after the thrower still ran (LIFO: a, then boom2)" \
  $::trace {res:a:.drw res:boom2:.drw}
check "CR2e2 the latch still came down" [cmdmode::is_suspended] 0

# --- CR2f: unregistered while suspended -----------------------------------------------
clear_all
cmdmode::register a sus_a res_a
cmdmode::register c sus_c res_c
cmdmode::suspend_all
cmdmode::unregister a
set ::trace {}
check "CR2f resume skips the mode that was unregistered mid-flight" [cmdmode::resume_all .drw] 1
check "CR2f2 and it called only the survivor" $::trace {res:c:.drw}

# --- CR3a-CR3c: rehome ----------------------------------------------------------------
clear_all
cmdmode::register a sus_a res_a
set ::trace {}
check "CR3a rehome re-homes the live mode onto the new canvas" [cmdmode::rehome .x2.drw] 1
check "CR3b it is a suspend+resume pair, not a bare rebind" $::trace {sus:a res:a:.x2.drw}
check "CR3b2 rehome leaves no latch standing" [cmdmode::is_suspended] 0
cmdmode::suspend_all
set ::trace {}
check "CR3c rehome is a no-op while a suspend is in flight" [cmdmode::rehome .x3.drw] 0
check "CR3c2 it did not touch the arms" $::trace {}
check "CR3c3 and the pending suspend is still pending" [cmdmode::is_suspended] 1
cmdmode::resume_all

clear_all

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
