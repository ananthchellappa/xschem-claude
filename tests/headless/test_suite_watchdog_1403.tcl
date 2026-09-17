# tests/headless/test_suite_watchdog_1403.tcl
#
# Issue 1403 -- A SUITE THAT HANGS MUST SAY SO, AND EVERY CHILD OF T1 MUST HAVE
# A DEADLINE.
#
# On 2026-09-11 `test_ase_optier_0963` printed 86 of its 103 rows on the display
# arm, stopped after row N3, and sat there for EIGHT HOURS AND SEVEN MINUTES.
# A suite that is slow and a suite that is wedged emit byte-identical output --
# none -- so nothing could tell them apart and nothing woke anyone. Write-up:
# doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md
#
# Two layers landed, and this suite pins BOTH, because each covers what the
# other cannot:
#
#   LAYER 2, rows W1-W13 -- the in-suite watchdog in `scratch.tcl`. It is armed
#     by the suite being a suite, so it bounds the one command no driver wraps:
#     a bare `./src/xschem --nogui --pipe -q --nolog --script <t>.tcl`. It is
#     NOT a general timeout, and W13 pins the limitation by measurement rather
#     than by comment: a Tcl `after` timer reaches only a hang that gets to the
#     event loop.
#
#   LAYER 1, rows W14-W19 (W15c is four rows, one per exec site) -- `timeout` on each of `tests/run_regression.tcl`'s
#     four `exec` sites. That driver had none, on any site, while the other two
#     have had one all along (`run_suites.sh` 200 s, `full_audit.sh` 300 s) --
#     so T1, the one suite whose baseline is ZERO, was the one with no bound.
#     These rows read the driver the way row V57 of `test_op_annot.tcl` reads
#     the display-arm loop: an arm that nothing notices the removal of is a trap
#     issue 0891 already sprang once.
#
# ⚠ WHY A ROW ASSERTS A LIMITATION. W13 says the watchdog does NOT cover a
# blocking `exec`. That is deliberate: the comment block in `scratch.tcl` makes
# the same claim, and a comment cannot be prevented from drifting away from the
# code. If somebody later makes the watchdog general, W13 goes red and tells
# them to rewrite the paragraph -- which is the correct outcome, not a nuisance.
#
# ⚠ FLOOR: 32 checks, and it only ever goes up. Both arms report the same
# number: every child is spawned `--nogui` on purpose, so the rows measure the
# watchdog and not the display.
#
#   headless     -> 32 checks
#       ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_suite_watchdog_1403.tcl
#   dev display  -> 32 checks
#       tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_suite_watchdog_1403.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail" ; incr npass } else { puts "FAIL: $name $detail" ; incr fail }
}
## Substring test that never treats the needle as a glob pattern -- the watchdog
## sentence carries characters `string match` would eat.
proc has_text {haystack needle} { expr {[string first $needle $haystack] >= 0} }

## ⚠ A BUDGET IS PINNED BY VALUE, NEVER BY SUBSTRING. `has_text` is `string
## first`, so the needle `BUDGET 900000` sits happily inside `BUDGET 90000000`
## and `return 900` inside `return 90000`. The DEFLATING direction of a bad edit
## is caught by a prefix match; the INFLATING one is not -- and inflating is the
## direction that silently reinstates the defect this whole issue exists to
## close. Both layers carry the same nominal 900 in DIFFERENT UNITS
## (`t1_timeout` seconds, `__wd_budget_ms` milliseconds), landed together and
## documented side by side, so a unit mix-up is the likeliest future edit and
## every harmful unit mix-up is a decimal-prefix extension. Found by an
## adversarial review of this diff, after a sabotage pass that only tried the
## deflating direction.
proc budget_of {out} {
  if {[regexp -line {^BUDGET ([0-9]+)$} $out -> v]} { return $v }
  return -1
}
## The default a shell driver falls back to, read out of the driver itself, so
## W1b measures the relation instead of restating it in a detail string.
proc sh_default {path} {
  if {[regexp -line {^TIMEOUT="\$\{[A-Z_]+:-([0-9]+)\}"} [slurp $path] -> n]} { return $n }
  return -1
}

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set xbin    [info nameofexecutable]
set scratch [test_scratch wd1403]
set srcline "source [list [file join $here scratch.tcl]]"

proc write_fixture {path body} {
  set f [open $path w] ; puts $f $body ; close $f
  return $path
}

## Run one child, always externally bounded -- this suite does not get to be the
## thing that hangs. Returns {rc elapsed_ms merged_output}.
proc run_child {path budget cap} {
  global xbin
  set had [info exists ::env(XSCHEM_SUITE_WATCHDOG_MS)]
  set old {}
  if {$had} { set old $::env(XSCHEM_SUITE_WATCHDOG_MS) }
  if {$budget eq {}} {
    catch {unset ::env(XSCHEM_SUITE_WATCHDOG_MS)}
  } else {
    set ::env(XSCHEM_SUITE_WATCHDOG_MS) $budget
  }
  set t0 [clock milliseconds]
  set rc 0 ; set out {}
  if {[catch {exec timeout --kill-after=5 $cap $xbin --nogui --pipe -q --nolog \
                   --script $path 2>@1} out opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  set el [expr {[clock milliseconds] - $t0}]
  if {$had} { set ::env(XSCHEM_SUITE_WATCHDOG_MS) $old } else {
    catch {unset ::env(XSCHEM_SUITE_WATCHDOG_MS)}
  }
  return [list $rc $el $out]
}

## Same, with the two streams kept apart -- W9 needs to see stderr on its own.
proc run_child_split {path budget cap outf errf} {
  global xbin
  set had [info exists ::env(XSCHEM_SUITE_WATCHDOG_MS)]
  set old {}
  if {$had} { set old $::env(XSCHEM_SUITE_WATCHDOG_MS) }
  set ::env(XSCHEM_SUITE_WATCHDOG_MS) $budget
  set rc 0
  if {[catch {exec timeout --kill-after=5 $cap $xbin --nogui --pipe -q --nolog \
                   --script $path > $outf 2> $errf} msg opt]} {
    set ec [dict get $opt -errorcode]
    set rc [expr {[lindex $ec 0] eq {CHILDSTATUS} ? [lindex $ec 2] : 1}]
  }
  if {$had} { set ::env(XSCHEM_SUITE_WATCHDOG_MS) $old } else {
    catch {unset ::env(XSCHEM_SUITE_WATCHDOG_MS)}
  }
  return $rc
}

proc slurp {p} {
  if {[catch {open $p r} f]} { return {} }
  set t [read $f] ; close $f ; return $t
}

# =============================================================================
# LAYER 2 -- the in-suite watchdog
# =============================================================================

## --- W1/W2/W4: the budget the suite actually ends up with --------------------
## The child prints its own resolved budget, so these rows read the value in
## force rather than re-deriving the rule.
set f_budget [write_fixture [file join $scratch budget.tcl] \
  "$srcline\nputs \"BUDGET \$::__wd_budget\"\nexit 0"]

lassign [run_child $f_budget {} 30] rc el out
check W1a-default-budget-is-900000 [expr {[budget_of $out] == 900000}] \
  "-- env unset; the default must sit ABOVE run_suites.sh 200s and full_audit.sh 300s so it never preempts their verdict"

## ⚠ W1b MEASURES WHAT W1a's DETAIL STRING ONLY CLAIMED. The watchdog must sit
## ABOVE both shipped drivers' caps -- so a wrapped run always reports THAT
## driver's verdict with THAT driver's number -- and must still BE a bound. The
## upper half is what reddens on a 900000 -> 900000000 slip; the lower half
## reddens if anyone raises SUITE_TIMEOUT or AUDIT_TIMEOUT past the watchdog.
set st [sh_default [file join $here run_suites.sh]]
set at [sh_default [file join $here full_audit.sh]]
## ⚠ READ THE BUDGET THE CODE ACTUALLY RESOLVED, never a literal repeated here.
## Written as `set wd_def 900000` this row compared the test's own constant with
## the drivers and therefore stayed GREEN when the code's default was inflated
## to 25 hours -- caught by re-running the sabotage pass after adding the row.
## A row that restates the value it is guarding is guarding nothing.
set wd_def [budget_of $out]
check W1b-default-is-above-both-drivers-and-still-a-bound \
  [expr {$st > 0 && $at > 0 && $wd_def > $at*1000 && $wd_def > $st*1000 && $wd_def <= 3600000}] \
  "-- run_suites.sh ${st}s, full_audit.sh ${at}s, watchdog ${wd_def}ms: above both so it never preempts their verdict, and under an hour so it is still a BOUND"

lassign [run_child $f_budget 4000 30] rc el out
check W2a-env-overrides-the-budget [expr {[budget_of $out] == 4000}] \
  "-- XSCHEM_SUITE_WATCHDOG_MS=4000"

lassign [run_child $f_budget {not-a-number} 30] rc el out
check W4a-malformed-env-falls-back [expr {[budget_of $out] == 900000}] \
  "-- a typo must not silently DISARM the only bound an unwrapped run has"

lassign [run_child $f_budget 0 30] rc el out
check W3a-zero-is-a-real-disable [expr {[budget_of $out] == 0}] \
  "-- 0 is how a deliberate unbounded debug run is asked for"

## --- W5-W9: a hang in the event loop ----------------------------------------
## `vwait` on a variable nothing sets is the shape of issue 1375's modal: a
## `tkwait` under `--script` that nothing can click.
set f_hang [write_fixture [file join $scratch hang.tcl] \
  "$srcline\nputs {WD-FIXTURE row N3 reached}\nflush stdout\nvwait ::__never_set__\nexit 0"]

lassign [run_child $f_hang 3000 40] rc el out
## ⚠ W5a DOES NOT DISCRIMINATE ON ITS OWN. `timeout` also exits 124, so this row
## holds whether the watchdog fired or the external cap did -- it pins the CODE,
## which is the part every reader keys on. W5b (it ended at the budget, not the
## cap) and W6a (it said so) are the rows that tell the two apart, and a sabotage
## pass that disarms the timer leaves W5a green on purpose.
check W5a-event-loop-hang-exits-124 [expr {$rc == 124}] \
  "-- rc=$rc; 124 is timeout(1)'s code and run_suites.sh already classifies it as TIMEOUT, so no reader has to change"
check W5b-and-it-exits-at-the-budget [expr {$el < 20000}] \
  "-- ${el}ms against a 40s external cap; the point is that the BUDGET ended it, not the cap"
check W6a-watchdog-line-on-stdout [has_text $out {###### WATCHDOG TIMEOUT ######}] \
  "-- a stall must be a NAMED OUTCOME, never the absence of one"
check W7a-line-names-the-suite-not-the-library [has_text $out {hang.tcl exceeded}] \
  "-- `info script` inside a sourced library names the LIBRARY; the row pins that frame 1 is used instead"
check W7b-line-does-not-name-scratch-tcl [expr {![has_text $out {scratch.tcl exceeded}]}] \
  "-- the non-vacuity half of W7a"
check W8a-line-quotes-the-last-stdout-line [has_text $out {last output: WD-FIXTURE row N3 reached}] \
  "-- \"86 of 103 rows, stops after N3\" is the FINDING; \"it hung\" is what an external timeout could already say"

set of [file join $scratch w9.out] ; set ef [file join $scratch w9.err]
set rc9 [run_child_split $f_hang 3000 40 $of $ef]
check W9a-watchdog-line-on-stderr-too \
  [has_text [slurp $ef] {###### WATCHDOG TIMEOUT ######}] \
  "-- a caller that captured only stderr would otherwise still see a silent death"

## --- W10: non-vacuity -- a healthy suite is untouched ------------------------
set f_ok [write_fixture [file join $scratch ok.tcl] \
  "$srcline\nputs {WD-FIXTURE healthy}\nputs {OVERALL: ok}\nexit 0"]
lassign [run_child $f_ok 3000 30] rc el out
check W10a-healthy-run-exits-0 [expr {$rc == 0}] "-- rc=$rc"
check W10b-healthy-run-prints-no-watchdog-line \
  [expr {![has_text $out {WATCHDOG TIMEOUT}]}] \
  "-- the watchdog must be invisible on every run that does not hang, or 169 suites grow a new output line"

## --- W11: the wrapped `puts` still behaves ----------------------------------
## The last-line capture renames ::puts. All four call forms must survive, and
## ONLY stdout may be recorded -- a suite writing its own log through a file
## channel is not producing progress output.
set w11f [file join $scratch w11.txt]
set b11 "$srcline\n"
append b11 "set fh \[open [list $w11f] w\]\n"
## ⚠ THE ORDER OF THESE WRITES IS LOAD-BEARING and W11c is vacuous without it.
## The file-channel writes must come AFTER the stdout writes, so that a wrap
## which wrongly recorded file channels would leave LAST=no-newline. Written the
## other way round the correct and the broken code both answer `chan-stdout`,
## and the row passes either way -- which is what the first draft did, caught by
## a sabotage pass that reddened nothing.
append b11 "puts {plain-stdout}\n"
append b11 "puts -nonewline {nonl-stdout}\n"
append b11 "puts stdout {chan-stdout}\n"
append b11 "puts \$fh {to-file}\n"
append b11 "puts -nonewline \$fh {no-newline}\n"
append b11 "puts \$fh \"\\nLAST=\$::__wd_last\"\n"
append b11 "close \$fh\n"
append b11 "exit 0"
set f_w11 [write_fixture [file join $scratch w11.tcl] $b11]
lassign [run_child $f_w11 3000 30] rc el out
set w11 [slurp $w11f]
check W11a-file-channel-writes-are-intact \
  [expr {[has_text $w11 {to-file}] && [has_text $w11 {no-newline}]}] \
  "-- `puts \$fh s` and `puts -nonewline \$fh s`"
check W11b-stdout-writes-are-intact \
  [expr {[has_text $out {plain-stdout}] && [has_text $out {nonl-stdout}] && [has_text $out {chan-stdout}]}] \
  "-- `puts s`, `puts -nonewline s`, `puts stdout s`"
check W11c-only-stdout-is-recorded [has_text $w11 {LAST=chan-stdout}] \
  "-- the file channel wrote LAST; if it were recorded the value would be `no-newline`"

## --- W12: it leaves through the WRAPPED exit --------------------------------
## An external SIGTERM cannot do this: measured 2026-09-11, a killed child takes
## the binary's emergency-save path and leaves /tmp/xschem_emergencysave_* plus
## its own scratch dir behind. The watchdog's `exit` runs the cleanup.
set b12 "$srcline\n"
append b12 "set d \[test_scratch wd1403child\]\n"
append b12 "puts \"CHILDSCRATCH \$d\"\nflush stdout\n"
append b12 "vwait ::__never_set__\nexit 0"
set f_w12 [write_fixture [file join $scratch w12.tcl] $b12]
## ⚠ SETS AND IDENTITY, NEVER A COUNT. `/tmp/xschem_emergencysave_*` is a GLOBAL
## namespace and `src/main.c:42` puts NO PID IN THE NAME -- the prefix is the cell
## name plus a random suffix -- so a count taken across this window answers for
## every xschem on the box, not for this child. Measured 2026-09-17 (receipt V4):
## under a concurrent T1 pair the OTHER run's deliberately-killed watchdog children
## reddened this row at ~1 run in 4 (`37 -> 38 in /tmp`), in the one suite whose
## baseline is ZERO. Same defect class as C11 (`test_ase_core.tcl:1591`) and as
## 0609's own supplied fix code: a count is not an identity, third appearance.
##
## ⚠ AND A SET DIFFERENCE ALONE CANNOT BE THE ASSERTION EITHER. Names that appear
## during the window are still names from a SHARED namespace, so a foreign corpse
## is `new` too and asserting on the delta would red exactly as often as the count
## did. The ground truth is what the CHILD ITSELF announced: `sig_handler` creates
## the dir and then prints `EMERGENCY SAVE DIR: <path>` (`src/main.c:45-52`), so a
## child names its own corpse on the way out, and `run_child` merges stderr (`2>@1`)
## so the row can see it. That is the identity idiom the three sibling reapers
## already use (`test_zero_point_pos_at_0852.tcl:156`,
## `test_raw_read_failure_0306.tcl:254`, `test_zero_point_raw_0836.tcl:147`).
## The delta is kept and REPORTED, never asserted on, so the foreign traffic that
## used to red this row is visible as evidence instead of as a failure.
proc em_snap {} {
  return [lsort [glob -nocomplain -directory /tmp -type d xschem_emergencysave_*]]
}
## The corpses a child NAMED on its way out. `run_child` merges stderr (`2>@1`),
## which is what puts `sig_handler`'s marker into $out; identity, never a glob.
proc em_announced {txt} {
  set ds {}
  foreach {em_all em_d} [regexp -all -inline {EMERGENCY SAVE DIR: (\S+)} $txt] {
    if {[string match {*xschem_emergencysave*} $em_d] && [lsearch -exact $ds $em_d] < 0} {
      lappend ds $em_d
    }
  }
  return $ds
}
## Delete ONLY what this run's own child announced. NEVER a foreign corpse.
proc em_reap {txt} {
  set n 0
  foreach d [em_announced $txt] { catch {file delete -force $d} ; incr n }
  return $n
}
set em_before [em_snap]
lassign [run_child $f_w12 3000 40] rc el out
set childdir {}
foreach l [split $out \n] {
  if {[regexp {^CHILDSCRATCH (.+)$} [string trim $l] -> d]} { set childdir [string trim $d] }
}
set em_after [em_snap]
## Appeared during the window, whoever made it -- CONTEXT, not the assertion.
set em_new {}
foreach d $em_after { if {[lsearch -exact $em_before $d] < 0} { lappend em_new $d } }
## Announced by THIS child -- the only corpses this row is entitled to judge.
set em_mine [em_announced $out]
set em_foreign {}
foreach d $em_new { if {[lsearch -exact $em_mine $d] < 0} { lappend em_foreign $d } }
check W12a-child-scratch-dir-was-removed \
  [expr {$childdir ne {} && ![file isdirectory $childdir]}] \
  "-- [expr {$childdir eq {} ? {the fixture never reported a dir} : $childdir}]"
## A failure prints the OFFENDING PATHS, not a bare pair of numbers: `37 -> 38`
## told a reader that something happened somewhere in /tmp, which is precisely
## what made the false red so expensive to diagnose.
if {[llength $em_mine]} {
  set em_detail "THIS child left [llength $em_mine] emergency-save corpse(s): [join $em_mine {, }]"
} else {
  set em_detail "the child announced no EMERGENCY SAVE DIR, so it left through the wrapped exit"
}
append em_detail " -- [llength $em_foreign] foreign corpse(s) appeared in the same window and are\
 deliberately IGNORED (shared /tmp, no pid in the name); an external SIGTERM on this same hang\
 would add one that IS ours"
check W12b-no-emergency-save-corpse [expr {[llength $em_mine] == 0}] "-- $em_detail"
## Reap ONLY what this child announced. NEVER a foreign corpse: another run may
## still be holding it, and deleting one would make this suite commit the very
## cross-run interference it exists to detect.
foreach d $em_mine { catch {file delete -force $d} }

## --- W13: THE LIMITATION, pinned by measurement ------------------------------
## A Tcl `after` timer fires only when the interpreter reaches the event loop.
## A blocking `exec` never does. This row exists so the paragraph in scratch.tcl
## cannot drift away from the code: if the watchdog is ever made general, this
## goes red and names the paragraph that then needs rewriting.
set f_exec [write_fixture [file join $scratch execblock.tcl] \
  "$srcline\nputs {WD-FIXTURE before exec}\nflush stdout\ncatch {exec sleep 12}\nputs {WD-FIXTURE after exec}\nexit 0"]
lassign [run_child $f_exec 2000 8] rc el out
check W13a-blocking-exec-is-NOT-covered \
  [expr {![has_text $out {WATCHDOG TIMEOUT}] && $el > 6000}] \
  "-- ${el}ms with a 2000ms budget; the watchdog cannot reach a hang that never gets to the event loop, and scratch.tcl says so in prose"
## ⚠ AND THIS ROW IS A CORPSE PRODUCER -- MEASURED, NOT SUSPECTED. W13 is the one
## row whose child CANNOT leave through the wrapped exit: that is the whole point
## of it, so `timeout` SIGTERMs the child at the 8 s cap, `sig_handler` runs, and
## the run leaks exactly one `/tmp/xschem_emergencysave_*` EVERY TIME. Measured
## 2026-09-17: /tmp grew by +1 per suite run (44 -> 49 over five runs) with no
## other producer running. That litter is not cosmetic -- `/tmp` is a tmpfs here
## and, until W12b above stopped counting, corpses in this SHARED namespace were
## exactly what reddened a concurrent run's W12b at ~1 run in 4. So this suite was
## itself one of the producers of the foreign traffic that the row above had to be
## taught to ignore, and leaving the leak in place while fixing only the detector
## would have kept feeding every other count-based check on the box.
## Reaps by NAME, from this child's own announcement -- never a foreign corpse.
em_reap $out

# =============================================================================
# LAYER 1 -- run_regression.tcl's four exec sites
# =============================================================================
# Read textually, the way row V57 of test_op_annot.tcl reads the display-arm
# loop. Cite PROC NAMES, never bare line numbers.

set rr [slurp [file join $repo tests run_regression.tcl]]

check W14a-driver-defines-t1_timeout \
  [expr {[has_text $rr {proc t1_timeout }] && [has_text $rr {T1_CASE_TIMEOUT}]}] \
  "-- the per-case budget, with an env override"
## ⚠ SCOPED TO THE PROC AND ANCHORED AT BOTH ENDS. Unscoped, some future
## `return 900` elsewhere in this 330-line driver answers for t1_timeout;
## unanchored, `return 90000` (a 25-hour per-case bound) matches the needle
## `return 900` and the row stays green. Same hole as the budget rows above,
## on the other layer.
set t1body {}
regexp {proc t1_timeout \{\} \{(.*?)\n\}} $rr -> t1body
check W14b-default-is-900-seconds \
  [expr {$t1body ne {} && [regexp -line {^[ \t]*return 900$} $t1body] ? 1 : 0}] \
  "-- ~3x full_audit.sh's cap: it bounds a hang without redefining \"slow\" for the six display-arm cases"
check W15a-all-four-exec-sites-are-prefixed \
  [expr {[regexp -all {\$t1_pre} $rr] >= 4}] \
  "-- tcases (tclsh), hcases, dcases and xschemtest; [regexp -all {\$t1_pre} $rr] uses of \$t1_pre"
check W15b-kill-after-upgrades-to-SIGKILL [has_text $rr {--kill-after=20}] \
  "-- so \"timed out\" cannot itself become the thing that hangs"

## ⚠ W15a COUNTS, IT DOES NOT POSITION -- and `concat [list tclsh ...] $t1_pre`
## keeps the count at four while handing the words `timeout --kill-after=20 900`
## to the case as ARGV and applying no deadline at all. Three of the four sites
## had no positional guard whatever; only the display arm did, through W16a.
## These four rows close that, per site, by requiring $t1_pre to come BEFORE the
## word list that names the binary. Found by an adversarial review of this diff.
proc rr_cmdline {txt var} {
  foreach l [split $txt \n] {
    if {[regexp -- "set\\s+$var\\s+\\\[concat" $l]} { return $l }
  }
  return {}
}
foreach {_site _var _needle} [list \
    tcases     tccmd {[list tclsh} \
    hcases     hccmd {[list $xschem_cmd --nogui} \
    dcases     dccmd {[list $xschem_cmd --pipe} \
    xschemtest xtcmd {[list $xschem_cmd --nogui --pipe -q --script xschemtest.tcl}] {
  set _ln [rr_cmdline $rr $_var]
  set _ip [string first {$t1_pre} $_ln]
  set _ic [string first $_needle $_ln]
  check W15c-$_site-prefixes-rather-than-merely-mentions-t1_pre \
    [expr {$_ln ne {} && $_ip >= 0 && $_ic > $_ip}] \
    "-- \$t1_pre must PRECEDE the words that name the binary; appended instead, the timeout words become the case's argv and nothing is bounded"
}
## ⚠ THIS ROW ASSERTS AN ORDERING, NOT A SPELLING, and V57 of test_op_annot.tcl
## is where the idiom comes from. A byte-exact needle reddens on a pure rename
## of the local `dd` or a reflow that changes no behaviour -- the same
## brittleness the house rule "cite PROC NAMES, never bare line numbers" exists
## to avoid. What must hold is that the devdisplay token comes BEFORE $t1_pre on
## the line that builds the child command: that is the difference between the
## timeout being xschem's parent and the timeout being devdisplay.sh's parent.
set W16_LINE {}
foreach _l16 [split $rr \n] {
  if {[regexp -- {set\s+dccmd} $_l16]} { set W16_LINE $_l16 }
}
check W16a-display-arm-prefix-is-INSIDE-devdisplay-exec \
  [expr {$W16_LINE ne {} &&
         [regexp {(devdisplay\.sh|\$dd)\s+exec[^\n]*\$t1_pre} $W16_LINE] ? 1 : 0}] \
  "-- devdisplay.sh stays the parent of what it runs, so a timeout wrapped AROUND it would signal the shell and orphan xschem on :99"
check W17a-harness-lines-route-through-t1_why \
  [expr {[regexp -all {\[t1_why } $rr] >= 3}] \
  "-- the hcases line, the dcases line and the tcases arm"
check W18a-t1_why-names-124-as-a-timeout \
  [expr {[has_text $rr {$childcode == 124}] && [has_text $rr {TIMED OUT after}]}] \
  "-- rc 124 is the answer \"it hung\", and it must reach results.log saying so"
## The CLAIM is "the tcases arm appends a HARNESS line whose reason comes from
## t1_why and which summarize_all will count". Pinning the exact source line
## also pinned `${tc}` over `$tc` and the argument spelling, both of which are
## identity-preserving edits.
check W19a-tcases-synthesizes-a-counted-FAIL \
  [expr {[regexp {HARNESS:[^\n]*t1_why[^\n]*:\s*FAIL} $rr] ? 1 : 0}] \
  "-- a killed case otherwise leaves only what it managed to print, which reads like ordinary failing checks"

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
