# tests/headless/test_ase_converge_1459.tcl -- ISSUE 1459: THE SIMULATOR SAID
# WHICH NODES WOULD NOT CONVERGE AND NOBODY EVER READ IT. PLAN.md Stage 10,
# the DECK half (10a's parser, 10b's parser and emitter, 10c's emitters).
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# `grep -c 'CKTncDump\|Last Node Voltages\|optran\|wrnodev' src/ase.tcl`
# returned ZERO until this block. Three things the simulator already prints,
# and no GUI has ever shown:
#
#  * the `Last Node Voltages` table, whose trailing ` *` marks EVERY NODE THAT
#    STILL FAILS the convergence test. evidence/convergence.md calls it "the
#    single most useful diagnostic in ngspice";
#  * the four-rung operating-point ladder, which is on STDERR;
#  * `optran` -- the fourth rung, ON BY DEFAULT -- which hands back the
#    TRANSIENT STATE AT ITS STOP TIME as your operating point.
#
# ============================================================================
# ⚠ THE ONE THAT MAKES AN OPERATING POINT NOT AN OPERATING POINT
# ============================================================================
# MEASURED 2026-09-13 on BOTH binaries, on a 1 k / 1 n RC driven to 1 V:
#
#     plain `op`                                       v(out) = 1.000000e+00
#     .options noopiter gminsteps=0 srcsteps=0         v(out) = 9.999550e-01
#
# The second number is the transient value at optran's 10 us stop, and
# 1 - e^-10 = 0.99995460. The only signal that it happened is one stderr line
# nobody sees. Section LD is the parser that finds it.
#
# ============================================================================
# ⚠ AND FOUR ACCEPTED-AND-INERT CASES, ALL MEASURED HERE, ALL AT rc 0
# ============================================================================
#  1. `.options optran 1 1 1 0 10u 0` -- `optran` is a COMMAND and is absent
#     from `OPTtbl[]`, so the card does NOTHING. Three deck spellings were
#     tried; all three left `Note: Transient op started` in the log.
#  2. `optran`'s first three arguments OVERRIDE `.options noopiter /
#     gminsteps / srcsteps` on the same task, silently. Section OT refuses that
#     deck at the form rather than shipping three option rows that do nothing.
#  3. `optran 1 1 1 1u 10u 0` -- a step larger than stop/50 is SILENTLY
#     replaced by stop/50. The number the user typed is not the number used.
#  4. `rusage devtimes` prints NOTHING in any stock build: `resource.c:322`
#     reads counters that are only written inside `#ifdef PER_DEVICE_STATS`,
#     and `cktload.c:30` is the literal line `// #define PER_DEVICE_STATS`.
#     PLAN.md §10c names it for the health strip; section RH is why it is not
#     offered.
#
# ============================================================================
# ⚠ AND THE "FASTEST FIX" THAT SILENTLY CHANGES THE ANSWER
# ============================================================================
# `wrnodev` writes `.ic` cards, and `.ic` is an INITIAL CONDITION for a
# transient, which is a different thing from the starting guess it is for an
# operating point. MEASURED on both binaries, one bench, one edit:
#
# ⚠ AN EARLIER VERSION OF THIS COMMENT SAID "a CLAMP that is never released".
# That is WRONG and the driver measured it: with the file included, a node with
# state runs 2.499900e+00 -> 1.893447e+00 at one time constant -> 1.500000e+00
# by twenty. The clamp IS released; what persists is the initial condition, and
# the trajectory converges once the circuit forgets it. The table below is
# measured AT t = 0, and a single point cannot tell the two mechanisms apart.
# The hazard, the two modes and the default are all unaffected -- only the
# reason is, and a wrong reason is what the next person designs against.
#
#     saved at 5 V                     .ic v(a) = 2.5
#     re-run at 3 V, no file            starts at 1.500000e+00   <- correct
#     re-run at 3 V, the file included  starts at 2.500000e+00   <- WRONG
#     re-run at 3 V, re-spelt .nodeset  starts at 1.500000e+00   <- correct
#
# rc 0 and nothing on either stream, all three. Section WR is the re-spelling
# and its refusal.
#
# ============================================================================
# CANNED LOG TEXT, AND EVERY LINE OF IT WAS CAPTURED FROM A REAL RUN
# ============================================================================
# PLAN.md §10 specifies canned text for determinism. Every fixture below was
# captured 2026-09-13 from a deck written for the purpose, on the fork, and
# confirmed byte-identical on apt 45.2 -- with ONE declared exception, marked
# `SPLICED` at its own row, where a combination could not be produced on this
# machine and is assembled from two literals that were each measured.
#
# Section EE then runs the real thing on BOTH binaries and closes the loop the
# other way: nothing the ladder prints may be a line this parser has never
# heard of. That is the SURPLUS direction, and it is the direction issue 1457
# was blind in.
#
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
#    sections NC LD OT WR RH DK -- pure Tcl, identical on both arms
#    section  EE -- starts real simulators on BOTH binaries, six rows each,
#                   self-skips with the path printed when one is absent
#
# NEW AT 76, both arms, `diff` of the two ok-lists empty. The sabotage campaign
# is in doc/claude/ase_analyses_batch/receipts/36-stage-10-deck.md: 35 mutations,
# 33 killed by name, one declared equivalent with the measurement behind it, and
# one that DELETED a row rather than shipping it green-and-unfalsifiable.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_converge_1459.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_converge_1459.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch converge1459]
catch {test_sim_registry_isolate}

## ⚠ EVERY READER IS TOTAL AND ANSWERS A COMPARABLE VALUE. A row whose
## extractor raises cannot disagree with anything, and `--nogui --pipe` exits 0
## on an uncaught mid-script error -- so a killed suite looks like a pass.
proc c_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}

proc c_state {args} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell rc lib $scratch]
  dict set st rundir $scratch
  dict set st simulator ngspice
  dict set st save_all_v 1
  dict set st analyses {{type op enabled 1} {type tran enabled 1 step 1u stop 1m}}
  foreach {k v} $args { dict set st $k $v }
  return $st
}
proc c_netlist {} {
  return "* rc\nv1 in 0 1\nr1 in out 1k\nc1 out 0 1n\n.end\n"
}
proc c_deck {st} { return [c_ans ase::backend::ngspice::render_deck $st [c_netlist]] }
proc c_at {deck pat} {
  set i 0
  foreach l [split $deck "\n"] {
    if {[regexp $pat $l]} { return $i }
    incr i
  }
  return -1
}
proc c_lines {deck pat} {
  set out {}
  foreach l [split $deck "\n"] { if {[regexp $pat $l]} { lappend out [string trim $l] } }
  return $out
}

# ============================================================================
# THE FIXTURES -- captured verbatim, 2026-09-13, both binaries agreeing
# ============================================================================

## A REAL FAILED OPERATING POINT. Deck: two exponential B-sources in series off
## a 5 V rail, `optran 1 0 0 0 10u 0` so Newton runs and fails while every
## other rung is off, `.options reltol=1e-6 vntol=1e-9 abstol=1e-15` so the
## node voltages fail the tolerance too.
##
## ⚠ THE NAME IN ROW 1 IS 37 CHARACTERS AND THE FORMAT IS `%-30s %20g %20g`.
## `%-30s` does not truncate, so BOTH VALUE COLUMNS SHIFT RIGHT on that row.
## A column-position parser reads it wrong and says nothing.
##
## ⚠ AND `v1#branch` IS A BRANCH CURRENT IN A TABLE HEADED "Last Node
## Voltages". `x1.nn` is a subcircuit node, which is what `ase::netlist_map`
## has to resolve.
set NCSTAR {
DC solution failed -

Last Node Voltages
------------------

Node                                   Last Voltage        Previous Iter
----                                   ------------        -------------
a_very_long_node_name_for_column_test                    5                    5
top                                          4.9901                 4.99 *
x1.nn                                       4.98019              4.97999 *
bot                                         4.98019              4.97999 *
v1#branch                                 -0.009905            -0.010005 *

}

## ⚠ THE SAME TABLE WITH NOT ONE STAR IN IT, AND IT IS NOT A HYPOTHETICAL.
## Captured from `optran 0 0 0 0 10u 0` on a 1 k / 1 n RC: with every rung
## switched off nothing ever iterates, so `CKTrhs` and `CKTrhsOld` are both the
## zero vector they were allocated as, and no row can differ from itself. A
## parser that assumes at least one star highlights nothing and looks broken;
## one that reads "table present" as "these nodes are the problem" lights the
## whole circuit.
set NCNOSTAR {
DC solution failed -

Last Node Voltages
------------------

Node                                   Last Voltage        Previous Iter
----                                   ------------        -------------
in                                                0                    0
out                                               0                    0
v1#branch                                         0                    0

}

## ⚠ THE FOLD, IN THE ORDER IT REALLY ARRIVES. `run_cmd` appends `2>@1`; stdout
## to a file is block-buffered and stderr is not, so ALL THIRTEEN stderr lines
## precede ALL THIRTEEN stdout lines -- and `Circuit:`, `Doing analysis` and the
## solver banner all happened BEFORE gmin stepping began. Captured from
## `ngspice -b ladder.cir > fold.txt 2>&1`.
set LADFOLD {Note: Starting spice3 gmin stepping
Trying gmin =   1.0000E-02 Note: One successful gmin step
Trying gmin =   1.0000E-03 Note: One successful gmin step
Trying gmin =   1.0000E-04 Note: One successful gmin step
Trying gmin =   1.0000E-05 Note: One successful gmin step
Trying gmin =   1.0000E-06 Note: One successful gmin step
Trying gmin =   1.0000E-07 Note: One successful gmin step
Trying gmin =   1.0000E-08 Note: One successful gmin step
Trying gmin =   1.0000E-09 Note: One successful gmin step
Trying gmin =   1.0000E-10 Note: One successful gmin step
Trying gmin =   1.0000E-11 Note: One successful gmin step
Trying gmin =   1.0000E-12 Note: One successful gmin step
Note: spice3 gmin stepping completed


Note: No compatibility mode selected!


Circuit: * rung 2: spice3 gmin stepping (gminsteps>1)

Doing analysis at TEMP = 27.000000 and TNOM = 27.000000

Using SPARSE 1.3 as Direct Linear Solver

No. of Data Rows : 1
v(a) = 2.570247e+00
Note: Simulation executed from .control section 
}

## The whole ladder on a singular deck: dynamic gmin failed, true gmin failed,
## source stepping failed, and the TRANSIENT rung rescued it.
set LADFAIL {Warning: singular matrix:  check node 1

Note: Starting dynamic gmin stepping
Warning: singular matrix:  check node 1

Warning: Dynamic gmin stepping failed
Note: Starting true gmin stepping
Warning: singular matrix:  check node 1

Warning: True gmin stepping failed
Note: Starting source stepping
Warning: source stepping failed
Note: Transient op started
Note: Transient op finished successfully
}

## Gillespie source stepping, `set ngdebug`. ⚠ `Supplies reduced to ...% ` ends
## WITHOUT A NEWLINE, so the announcement of the step being attempted and the
## verdict of the one before it share one physical line.
set LADSRC {Note: Starting source stepping
Supplies reduced to   0.0000% Note: One successful source step
Supplies reduced to  87.4788% Note: One successful source step
Supplies reduced to 100.0000% Note: One successful source step
Note: Source stepping completed
}

## ⚠ A LIVE PARTIAL TAIL, and this is the shape reading the pipe really gives:
## measured with `os.read`, THREE OF FOUR CHUNKS end mid-line and the dangling
## text is always `Trying gmin = <value> ` -- the rung being attempted RIGHT
## NOW, whose newline arrives only when it finishes. The one event a live pane
## exists to show is the one that is never newline-terminated while it matters.
set LADTAIL "Note: Starting spice3 gmin stepping\nTrying gmin =   1.0000E-02 Note: One successful gmin step\nTrying gmin =   1.0000E-03 "

## SPLICED -- DECLARED, NOT CAPTURED. No circuit tried on this machine made
## `dynamic_gmin` fail and `new_gmin` succeed (nine were tried; every one either
## completed at the first variant or failed at both). The two literals are
## ngspice's own (`cktop.c:264` and `:458`) and the code path is real
## (`cktop.c:58-70` runs the second variant only when the first failed), but the
## COMBINATION below is assembled here. Row LD6 is the only row that uses it and
## it says so in its own name.
set LADMIXED {Note: Starting dynamic gmin stepping
Warning: Dynamic gmin stepping failed
Note: Starting true gmin stepping
Note: True gmin stepping completed
}

## The whole-ladder give-up line, which no rung prints.
set LADGIVEUP {Note: Starting dynamic gmin stepping
Warning: Dynamic gmin stepping failed
Note: Starting source stepping
Warning: source stepping failed

Error: The operating point could not be simulated successfully.
    Any of the following steps may fail.!
}

## ⚠ RUNG 4 SWITCHED OFF, AND ONLY ONE OF THE TWO BINARIES SAYS SO. Measured:
## `optran 1 1 1 0 10u 0` deselects the transient rung on apt 45.2 and on the
## fork alike -- same answer, `1.000000e+00` where the rung would have given
## `9.999550e-01` -- but apt 45.2 prints nothing at all. Absence of this line is
## NOT evidence the rung is armed.
set LADOFF {Note: Optran is deselected.
Doing analysis at TEMP = 27.000000 and TNOM = 27.000000
}

set HEALTHLOG {No. of Data Rows : 2012
Transient timepoints = 2013

Accepted timepoints = 2012

Rejected timepoints = 1

Total iterations = 4045
}

## A real `wrnodev` file, captured after a plain `op` on both binaries.
set WRFILE {* Intermediate Transient Solution
* Circuit: * wrnodev after a plain op
* Recorded at simulation time: 0
.ic v(in) = 5
.ic v(a) = 3.33333
.ic v(b) = 1.66667
}

# ============================================================================
# SECTION NC -- 10a: THE NODES THAT DID NOT CONVERGE
# ============================================================================
if {[catch {

check {NC1 every row of the table is read, and the 37-character name does not\
 cost the two value columns} \
  [c_ans ase::ncdump_parse ngspice $NCSTAR] \
  {{name a_very_long_node_name_for_column_test last 5 prev 5 failing 0 kind node table 0}\
 {name top last 4.9901 prev 4.99 failing 1 kind node table 0}\
 {name x1.nn last 4.98019 prev 4.97999 failing 1 kind node table 0}\
 {name bot last 4.98019 prev 4.97999 failing 1 kind node table 0}\
 {name v1#branch last -0.009905 prev -0.010005 failing 1 kind branch table 0}}

## ⚠ THE SURPLUS DIRECTION. NC1 says every row it read is right; it would pass
## with a row silently dropped. NC1b counts the table's own data lines and
## demands the parser account for all of them.
check {NC1b the parser drops nothing -- as many rows out as the table has data\
 lines in} \
  [apply {{t} {
     set n 0
     set seen 0
     foreach l [split $t "\n"] {
       if {[regexp {^-{4}\s+-{6,}} $l]} { set seen 1 ; continue }
       if {!$seen} { continue }
       if {[string trim $l] eq {}} { break }
       incr n
     }
     return [list $n [llength [ase::ncdump_parse ngspice $t]]] }} $NCSTAR] {5 5}

check {NC2 the starred names are what the canvas lights, and a branch current\
 is not one of them} \
  [list [c_ans ase::ncdump_failing ngspice $NCSTAR] \
        [c_ans ase::ncdump_failing ngspice $NCSTAR {node branch}]] \
  {{top x1.nn bot} {top x1.nn bot v1#branch}}

## ⚠ THE TABLE IS THERE AND NOT ONE ROW IS STARRED -- a real state, measured.
check {NC3 a table with no star gives three rows and NOTHING to highlight} \
  [list [llength [c_ans ase::ncdump_parse ngspice $NCNOSTAR]] \
        [c_ans ase::ncdump_failing ngspice $NCNOSTAR] \
        [c_ans ase::ncdump_failing ngspice $NCNOSTAR {node branch}]] {3 {} {}}

## CONTROL: a log with no table at all must answer empty, or NC3 proves only
## that the reader is silent.
check {NC3b a log with no table at all answers empty, which is what makes NC3 a\
 measurement rather than a silence} \
  [list [c_ans ase::ncdump_parse ngspice $LADFOLD] \
        [c_ans ase::ncdump_failing ngspice $LADFOLD]] {{} {}}

## ⚠ TWO FAILED ANALYSES IN ONE RUN PRINT TWO TABLES, and a caller that wants
## to separate them needs to be able to.
check {NC4 two tables in one log are both read and each row says which it came\
 from} \
  [apply {{a b} {
     set r [ase::ncdump_parse ngspice "$a$b"]
     set t {}
     foreach row $r { lappend t [dict get $row table] }
     return [list [llength $r] $t [ase::ncdump_failing ngspice "$a$b"]] }} \
   $NCSTAR $NCNOSTAR] \
  {8 {0 0 0 0 0 1 1 1} {top x1.nn bot}}

## ⚠ THE FOLD CAN PUT AN UNBUFFERED STDERR LINE INSIDE THE TABLE. A row whose
## value fields are not numbers is skipped, and the table does NOT end there --
## the blank line the simulator prints is what ends it.
## ⚠ AND THE ROW COUNT IS PART OF THE ANSWER, NOT DECORATION. Asking only for
## the starred names, this row PASSED with the numeric test removed: the
## injected `v(out) = 9.999550e-01` became a sixth row called `v(out)` with no
## star, so the failing list was unchanged and nothing noticed. The surplus is
## the direction that matters here too.
check {NC5 a stderr line landing inside the table costs no row AND adds none} \
  [apply {{t} {
     set lines [split $t "\n"]
     set out {}
     foreach l $lines {
       lappend out $l
       if {[string match {top*} $l]} {
         lappend out {Warning: singular matrix:  check node 1}
         lappend out {Note: One successful gmin step}
         ## ⚠ AND A LINE THAT REALLY IS THREE TOKENS. The two above are
         ## caught by the field COUNT; this one is not -- `print v(out)` writes
         ## to the same stream the table does, so `v(out) = 9.999550e-01` is
         ## three whitespace-separated tokens landing in a three-column table.
         ## Only the numeric test on the VALUE fields turns it away, and
         ## without that test it is read as a node called `v(out)`.
         lappend out {v(out) = 9.999550e-01}
       }
     }
     set j [join $out "\n"]
     return [list [llength [ase::ncdump_parse ngspice $j]] \
                  [ase::ncdump_failing ngspice $j]] }} $NCSTAR] \
  {5 {top x1.nn bot}}

## ⚠ AND A NODE REALLY NAMED LIKE A NOTE MUST STILL BE READ. The skip above is
## on the VALUE fields being numeric, not on the row looking like prose.
check {NC5b the numeric test is on the values, so a three-token row with real\
 numbers is kept whatever its name looks like} \
  [apply {{} {
     set t "Last Node Voltages\n------------------\n\nNode  Last Voltage  Previous Iter\n----  ------------  -------------\nWarning:                 1.5                  1.4 *\n\n"
     return [ase::ncdump_failing ngspice $t] }}] {Warning:}

check {NC6 a backend with no ncdump hook gets NO fallback content} \
  [apply {{t} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zzc1 [dict create render_deck x \
       run_cmd x log_file x result_probe x raw_file x]}]
     set r [list $rc [ase::ncdump_parse zzc1 $t] [ase::ncdump_failing zzc1 $t]]
     set ::ase::backends $save
     ase::ladder_cache_clear zzc1
     return $r }} $NCSTAR] {0 {} {}}

} ncerr]} { check {NC0 section NC ran to the end} "RAISED:$ncerr" {} }

# ============================================================================
# SECTION LD -- 10b: THE LADDER, CONTENT-MATCHED
# ============================================================================
if {[catch {

proc ld_states {text} {
  set p [ase::ladder_parse ngspice $text]
  set out {}
  foreach r [dict get $p rungs] { lappend out [dict get $r id] [dict get $r state] }
  lappend out verdict [dict get $p verdict]
  return $out
}

check {LD1 the four rungs are the adapter's, in ladder order, with ⚖ R9's labels} \
  [apply {{} {
     set out {}
     foreach r [ase::ladder_rungs ngspice] {
       lappend out [list [dict get $r id] [dict get $r label]]
     }
     return $out }}] \
  {{newton {Newton from the initial guess}} {gmin {gmin stepping}}\
 {src {Source stepping}} {tranop {Transient operating point}}}

## ⚠ THE ORDER-INDEPENDENCE ROW, AND IT IS THE POINT OF THE WHOLE PARSER. The
## fixture is the log AS IT REALLY ARRIVES -- the entire ladder printed BEFORE
## the `Circuit:` banner that happened first. A state machine that trusted
## arrival order would work on a terminal and be wrong on every logged run.
## ⚠ THE RUNG CATALOGUE IS MEMOISED PER BACKEND NAME, and registering a
## backend is the one event that changes what the hook would answer. Without the
## drop in `ase::register_backend` a re-registration is invisible for the rest of
## the session, which on this tree means the moment a user registers a simulator.
check {LD1b registering a backend drops the rung memo, so a re-registration is\
 not invisible for the rest of the session} \
  [apply {{} {
     set save $::ase::backends
     proc ::zzc6a {} { return {{id one label One steps {} times {}}} }
     proc ::zzc6b {} { return {{id two label Two steps {} times {}}
                               {id three label Three steps {} times {}}} }
     set base [dict create render_deck x run_cmd x log_file x result_probe x raw_file x]
     ase::register_backend zzc6 [dict merge $base [dict create ladder_rungs ::zzc6a]]
     set a [llength [ase::ladder_rungs zzc6]]
     ase::register_backend zzc6 [dict merge $base [dict create ladder_rungs ::zzc6b]]
     set b [llength [ase::ladder_rungs zzc6]]
     set ::ase::backends $save
     ase::ladder_cache_clear zzc6
     rename ::zzc6a {} ; rename ::zzc6b {}
     return [list $a $b] }}] {1 2}

check {LD2 the folded log, whose ladder arrives BEFORE the banner that really\
 came first, still reads as a gmin-stepping success} \
  [ld_states $LADFOLD] \
  {newton passedover gmin ok src notrun tranop notrun verdict ok}

## ⚠ AND THE SHUFFLE CONTROL: the same lines in a deliberately scrambled order
## must give the SAME answer, or LD2 is only a claim about one arrangement.
check {LD2b the same lines shuffled give the same answer} \
  [apply {{t} {
     set l [split [string trim $t] "\n"]
     ## a fixed, reproducible scramble -- reverse, which is the worst case for
     ## any sequence assumption
     return [ld_states [join [lreverse $l] "\n"]] }} $LADFOLD] \
  {newton passedover gmin ok src notrun tranop notrun verdict ok}

check {LD3 the per-step trace is kept, and both ends of one physical line are\
 read -- the trial AND the verdict that shares it} \
  [apply {{t} {
     set p [ase::ladder_parse ngspice $t]
     foreach r [dict get $p rungs] {
       if {[dict get $r id] eq {gmin}} {
         return [list [llength [dict get $r trials]] \
                      [lindex [dict get $r trials] 0] \
                      [lindex [dict get $r trials] end] \
                      [dict get $r methods] [dict get $r pending]]
       }
     }
     return NORUNG }} $LADFOLD] \
  {11 1.0000E-02 1.0000E-12 spice3 {}}

## ⚠ THE ONE EVENT A LIVE PANE EXISTS TO SHOW. In the finished file every line
## is terminated because the next write supplies the newline; reading the pipe,
## the rung being attempted right now never is.
check {LD4 an unterminated tail is the rung being attempted RIGHT NOW, and the\
 rung reads as running rather than finished} \
  [apply {{t} {
     set p [ase::ladder_parse ngspice $t]
     foreach r [dict get $p rungs] {
       if {[dict get $r id] eq {gmin}} {
         return [list [dict get $r state] [dict get $r pending] \
                      [llength [dict get $r trials]]]
       }
     }
     return NORUNG }} $LADTAIL] {running 1.0000E-03 2}

## CONTROL for LD4: the SAME text with the newline supplied must NOT be pending,
## or `pending` is a constant and the row proves nothing.
check {LD4b the same text with its newline back is not pending} \
  [apply {{t} {
     set p [ase::ladder_parse ngspice "${t}Note: One successful gmin step\n"]
     foreach r [dict get $p rungs] {
       if {[dict get $r id] eq {gmin}} { return [dict get $r pending] }
     }
     return NORUNG }} $LADTAIL] {}

check {LD5 the full singular ladder: gmin failed at both variants, source\
 stepping failed, and the TRANSIENT rung is what answered} \
  [ld_states $LADFAIL] \
  {newton passedover gmin failed src failed tranop ok verdict ok}

## SPLICED FIXTURE -- see LADMIXED's own note. The rung has three variants and
## a later one runs only when an earlier one failed, so a rung carrying both a
## `failed` and a `completed` line SUCCEEDED. A last-marker-wins reader would
## call it failed whenever the failing variant printed last, which on a folded
## log is a matter of buffering.
check {LD6 SPLICED FIXTURE -- a rung whose first variant failed and whose second\
 completed reads as ok, not failed} \
  [ld_states $LADMIXED] \
  {newton passedover gmin ok src notrun tranop notrun verdict ok}

## ⚠ AND REVERSED, WHICH IS THE ONLY ARRANGEMENT THAT CAN CATCH IT. In the
## forward order the `completed` line is simply the last one seen, so a reader
## that let a failure win would STILL answer ok. It is when the fold puts the
## failing variant last -- and on a folded log the order is whatever two buffers
## decided -- that the two readings come apart.
check {LD6b SPLICED FIXTURE reversed -- a failure marker arriving AFTER the\
 success marker does not take the rung back} \
  [ld_states [join [lreverse [split [string trim $LADMIXED] "\n"]] "\n"]] \
  {newton passedover gmin ok src notrun tranop notrun verdict ok}

check {LD7 source stepping's own trace, whose trial text also shares a line with\
 the verdict before it} \
  [apply {{t} {
     set p [ase::ladder_parse ngspice $t]
     foreach r [dict get $p rungs] {
       if {[dict get $r id] eq {src}} {
         return [list [dict get $r state] [dict get $r trials]]
       }
     }
     return NORUNG }} $LADSRC] \
  {ok {0.0000 87.4788 100.0000}}

## ⚠ RUNG 1 IS NOT OBSERVABLE, IN EITHER DIRECTION, AND THE PARSER SAYS SO
## RATHER THAN GUESSING. `cktop.c` has no "starting Newton" line and no "Newton
## failed" line: measured on both binaries, `.options noopiter` (rung SKIPPED)
## and a genuinely failing Newton give the same first line.
check {LD8 rung 1 is reported as passed over, never as failed, because the log\
 cannot tell the two apart} \
  [apply {{t} {
     set p [ase::ladder_parse ngspice $t]
     set r [lindex [dict get $p rungs] 0]
     return [list [dict get $r id] [dict get $r state] [dict get $r detail]] }} \
   $LADFOLD] \
  {newton passedover {skipped or failed -- this simulator prints nothing for this step}}

check {LD8b a log with no ladder in it at all leaves rung 1 unknown rather than\
 claiming it succeeded} \
  [ld_states "Circuit: * rc\nDoing analysis at TEMP = 27.000000\nv(out) = 1.000000e+00\n"] \
  {newton unknown gmin notrun src notrun tranop notrun verdict unknown}

check {LD9 the give-up line is the whole ladder's verdict and belongs to no rung} \
  [ld_states $LADGIVEUP] \
  {newton passedover gmin failed src failed tranop notrun verdict failed}

## ⚠ THE OFF LINE EXISTS ON ONE BINARY ONLY, so `off` must be readable when it
## is there and the ABSENCE of it must not be read as armed.
check {LD10 the rung-4 off line is read as off where it is printed, and its\
 absence is read as not-run rather than as armed} \
  [list [apply {{t} {
           set p [ase::ladder_parse ngspice $t]
           foreach r [dict get $p rungs] {
             if {[dict get $r id] eq {tranop}} { return [dict get $r state] }
           }
           return NORUNG }} $LADOFF] \
        [apply {{} {
           set p [ase::ladder_parse ngspice "Doing analysis at TEMP = 27.000000\n"]
           foreach r [dict get $p rungs] {
             if {[dict get $r id] eq {tranop}} { return [dict get $r state] }
           }
           return NORUNG }}]] \
  {off notrun}

## ⚠ THE SENTENCE ON THE OP FORM IS CONDITIONAL, AND THAT IS A CORRECTION. An
## unconditional "this operating point may come from a transient" would tell a
## user their exact answer is suspect when it is exact: measured, the shipped
## defaults leave the transient rung ARMED AND NEVER CALLED, because Newton
## converges above it. The run says which rung answered, and only a run that
## really descended to rung 4 earns the sentence.
check {LD11 only a run that really reached a lower rung earns that rung's\
 sentence} \
  [list [c_ans ase::ladder_ran_notes ngspice $LADFAIL] \
        [c_ans ase::ladder_ran_notes ngspice $LADFOLD] \
        [c_ans ase::ladder_ran_notes ngspice \
           "Circuit: * rc\nv(out) = 1.000000e+00\n"]] \
  {{{This operating point came from a transient, not from a DC solve.}}\
 {{This operating point came from gmin stepping, not from a plain solve.}} {}}

## ⚠ THE TREE TARGETS WINDOWS TOO (`CLAUDE.md`, `XSchemWin/`), so a log can
## arrive with CRLF endings. The trial's "is anything after it on this line"
## test must not count a carriage return as something, or EVERY rung reads as
## still in progress on that platform.
check {LD12 a backend with no ladder hook gets no rungs and no reading of one} \
  [apply {{t} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zzc2 [dict create render_deck x \
       run_cmd x log_file x result_probe x raw_file x]}]
     set r [list $rc [ase::ladder_rungs zzc2] [ase::ladder_parse zzc2 $t] \
                 [ase::ladder_ran_notes zzc2 $t]]
     set ::ase::backends $save
     ase::ladder_cache_clear zzc2
     return $r }} $LADFOLD] {0 {} {} {}}

} lderr]} { check {LD0 section LD ran to the end} "RAISED:$lderr" {} }

# ============================================================================
# SECTION OT -- 10b: THE STRATEGY LINE
# ============================================================================
if {[catch {

check {OT1 a bench that asks for no strategy emits no strategy line, so no\
 committed deck moves} \
  [list [c_ans ase::optran_line ngspice [c_state]] \
        [c_lines [c_deck [c_state]] {optran}]] {{} {}}

## ⚠ THE SHIPPED DEFAULTS, AND THE SIXTH ARGUMENT IS ZERO IN EVERY ONE OF THEM.
## `optran.c:670-671` has no clamp on the ramp, so the supply factor oscillates
## and returns to ZERO at twice the ramp time; `README.optran` says ramping is
## "not yet established".
check {OT2 all four rungs on is the simulator's own shipped line, ramp argument\
 included} \
  [c_ans ase::optran_line ngspice [c_state opstrategy {newton 1 gmin 1 src 1 tranop 1}]] \
  {{optran 1 1 1 100n 10u 0}}

## ⚠ THE RAMP ARGUMENT IS 0 WHATEVER THE STATE SAYS, and this row exists
## because nothing else in this suite forbids a key from reaching argument 6.
## A `.state` can be hand-edited -- that is `render_deck`'s third refusal tier's
## whole premise -- and `optran.c:670-671` has NO clamp: once `optime` passes
## `opramptime` the supply factor keeps oscillating and returns to ZERO at twice
## the ramp time, while `README.optran` says supply ramping is "not yet
## established". A state carrying a ramp must not get one.
check {OT2b argument 6 is 0 even for a state that explicitly asks for a ramp} \
  [apply {{} {
     set out {}
     foreach r {5u 0 100n 1} {
       lappend out [lindex [ase::optran_line ngspice [c_state opstrategy \
         [list newton 1 gmin 1 src 1 tranop 1 tranop_ramp $r \
               opramptime $r ramp $r]]] 0]
     }
     return [lsort -unique $out] }}] \
  {{optran 1 1 1 100n 10u 0}}

check {OT3 each rung switches off in its own argument, and the ramp stays 0\
 through every one of them} \
  [apply {{} {
     set out {}
     foreach s {{newton 0 gmin 1 src 1 tranop 1} {newton 1 gmin 0 src 1 tranop 1}
                {newton 1 gmin 1 src 0 tranop 1} {newton 1 gmin 1 src 1 tranop 0}} {
       lappend out [lindex [ase::optran_line ngspice \
                              [c_state opstrategy $s]] 0]
     }
     return $out }}] \
  {{optran 0 1 1 100n 10u 0} {optran 1 0 1 100n 10u 0}\
 {optran 1 1 0 100n 10u 0} {optran 1 1 1 0 10u 0}}

check {OT4 the step counts reach arguments 2 and 3, and only when their rung is on} \
  [apply {{} {
     set a [lindex [ase::optran_line ngspice [c_state opstrategy \
              {newton 1 gmin 1 gminsteps 10 src 1 srcsteps 7 tranop 1}]] 0]
     set b [lindex [ase::optran_line ngspice [c_state opstrategy \
              {newton 1 gmin 0 gminsteps 10 src 0 srcsteps 7 tranop 1}]] 0]
     return [list $a $b] }}] \
  {{optran 1 10 7 100n 10u 0} {optran 1 0 0 100n 10u 0}}

check {OT5 the transient rung's two times reach arguments 4 and 5} \
  [c_ans ase::optran_line ngspice [c_state opstrategy \
     {newton 1 gmin 1 src 1 tranop 1 tranop_step 1n tranop_stop 500n}]] \
  {{optran 1 1 1 1n 500n 0}}

## ⚠ A RUNG NOT NAMED IS ON. A strategy that names only what it switched off
## must not silently disable the other three.
check {OT6 a strategy naming only the rung it switched off leaves the rest on} \
  [c_ans ase::optran_line ngspice [c_state opstrategy {tranop 0}]] \
  {{optran 1 1 1 0 10u 0}}

## ⚠ THE XOR RULE, AS A REFUSAL. MEASURED on both binaries: a deck carrying
## `.options noopiter gminsteps=0 srcsteps=0` AND `optran 1 1 1 0 10u 0`
## answers the PLAIN-NEWTON value with rc 0 and nothing on either stream.
## Three option rows the user set did nothing and nobody was told.
check {OT7 an Options row the strategy would override is refused by name, not\
 passed down with a caution} \
  [apply {{} {
     set out {}
     foreach o {noopiter gminsteps srcsteps savecurrents} {
       set st [c_state opstrategy {newton 1} options [list [list name $o value 1]]]
       set r [ase::opstrategy_refusals ngspice $st]
       lappend out [list $o [llength $r] [lindex [lindex $r 0] 0]]
     }
     return $out }}] \
  {{noopiter 1 optionclash} {gminsteps 1 optionclash} {srcsteps 1 optionclash} {savecurrents 0 {}}}

check {OT7b the refusal names every clashing row, and render_deck refuses with\
 the evaluator's own sentence rather than a second spelling of it} \
  [apply {{} {
     set st [c_state opstrategy {newton 1} options \
               {{name noopiter value 1} {name srcsteps value 0}}]
     set r [lindex [ase::opstrategy_refusals ngspice $st] 0]
     set rc [catch {ase::backend::ngspice::render_deck $st [c_netlist]} e]
     return [list [lindex $r 2] $rc \
                  [expr {[string first [lindex $r 2] $e] >= 0}]] }}] \
  {{the Options sheet sets noopiter, srcsteps, and the operating-point strategy\
 overrides those rows without saying so} 1 1}

## ⚠ CONTROL: the same Options rows with NO strategy must render, or OT7 is
## measuring the option rows rather than the clash.
check {OT7c the same Options rows with no strategy render exactly as they did} \
  [apply {{} {
     set st [c_state options {{name noopiter value 1} {name srcsteps value 0}}]
     return [list [llength [ase::opstrategy_refusals ngspice $st]] \
                  [catch {ase::backend::ngspice::render_deck $st [c_netlist]}]] }}] {0 0}

## ⚠ EVERY RUNG OFF IS NOT A STRATEGY. MEASURED on both binaries:
## `optran 0 0 0 0 10u 0` on a 1 k / 1 n RC -- an operating point that is ONE
## matrix solve -- ends `DC solution failed`, `op simulation(s) aborted`, rc 1.
check {OT8 every rung off is refused, because the simulator cannot solve\
 anything at all with it} \
  [apply {{} {
     set r [ase::opstrategy_refusals ngspice \
              [c_state opstrategy {newton 0 gmin 0 src 0 tranop 0}]]
     return [list [llength $r] [lindex [lindex $r 0] 0] [lindex [lindex $r 0] 1]] }}] \
  {1 allrungsoff blocked}

## ⚠ MEASURED, BOTH BINARIES: `optran 1 1 1 20u 10u 0` answers `Error: Optran
## step size larger than final time.` AND `Error in command 'optran'` -- at
## **rc 0**, with the run carrying on under whatever settings it had before.
## `optran 1 1 1 1u 10u 0` is worse: the step is SILENTLY replaced by
## finaltime/50 and the note is on stdout in the middle of a run log.
## ⚠ AND THE BOUNDARY IS THE SIMULATOR'S OWN, TO THE BIT. `optran.c:173` is
## `if (opstepsize > opfinaltime/50.)`, strictly greater -- and MEASURED on both
## binaries, `optran 1 1 1 200n 10u 0` DOES print `Note: Optran step size set to
## 2.000000e-07`, because `INPevaluate("200n")` lands a hair above `1e-5/50.`.
## ASE-L's own parse lands in the same place, so the refusal fires exactly where
## the note does. `199n` is silent on both binaries and is accepted here.
check {OT9 a transient step the simulator would reject or silently replace is\
 refused at the form, at the same boundary the simulator itself uses} \
  [apply {{} {
     set out {}
     foreach {sp st} {20u 10u 1u 10u 200n 10u 199n 10u 100n 10u 1n 10u} {
       set r [ase::opstrategy_refusals ngspice [c_state opstrategy \
                [list newton 1 tranop 1 tranop_step $sp tranop_stop $st]]]
       lappend out [list $sp [lindex [lindex $r 0] 0]]
     }
     return $out }}] \
  {{20u tranopstepbig} {1u tranopstepcut} {200n tranopstepcut} {199n {}}\
 {100n {}} {1n {}}}

check {OT9b the fix names the largest step the simulator would actually use} \
  [apply {{} {
     set r [ase::opstrategy_refusals ngspice [c_state opstrategy \
              {newton 1 tranop 1 tranop_step 1u tranop_stop 10u}]]
     return [lindex [lindex $r 0] 3] }}] {use a step of at most 2e-07}

check {OT9c an unreadable time is refused as a time, and the step rules do not\
 apply to a rung that is switched off} \
  [apply {{} {
     set a [ase::opstrategy_refusals ngspice [c_state opstrategy \
              {newton 1 tranop 1 tranop_step zz tranop_stop 10u}]]
     set b [ase::opstrategy_refusals ngspice [c_state opstrategy \
              {newton 1 tranop 0 tranop_step 20u tranop_stop 10u}]]
     return [list [lindex [lindex $a 0] 0] [llength $b]] }}] {tranopstep 0}

## ⚠ POSITION, AND THE MECHANISM IS NOT LAST-WRITER-WINS. `optran` with a live
## circuit writes `ci_defTask` directly, so it governs every analysis that
## FOLLOWS it in the block and none that precede it. A line emitted after the
## first analysis would leave that analysis on the shipped defaults.
check {OT10 the strategy line is inside .control and above EVERY analysis} \
  [apply {{} {
     set d [c_deck [c_state opstrategy {newton 1 gmin 1 src 1 tranop 0}]]
     set ctl [c_at $d {^\.control$}]
     set ot  [c_at $d {^optran }]
     set op  [c_at $d {^op$}]
     set tr  [c_at $d {^tran }]
     return [list [expr {$ot > $ctl}] [expr {$ot < $op}] [expr {$ot < $tr}] \
                  [llength [c_lines $d {^optran }]]] }}] {1 1 1 1}

check {OT11 a backend with no strategy hooks emits nothing and refuses nothing} \
  [apply {{} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zzc3 [dict create render_deck x \
       run_cmd x log_file x result_probe x raw_file x]}]
     set st [c_state opstrategy {newton 0 gmin 0 src 0 tranop 0} \
               options {{name noopiter value 1}}]
     set r [list $rc [ase::optran_line zzc3 $st] \
                 [ase::opstrategy_refusals zzc3 $st]]
     set ::ase::backends $save
     ase::ladder_cache_clear zzc3
     return $r }}] {0 {} {}}

} oterr]} { check {OT0 section OT ran to the end} "RAISED:$oterr" {} }

# ============================================================================
# SECTION WR -- 10c: SAVE AND RESTORE THE OPERATING POINT
# ============================================================================
if {[catch {

set WRDIR [file join $scratch wr]
file mkdir $WRDIR
set WRPATH [file join $WRDIR op.ic]
set wf [open $WRPATH w] ; puts -nonewline $wf $WRFILE ; close $wf

check {WR1 a bench that asks for neither emits neither} \
  [list [c_ans ase::wrnodev_lines ngspice [c_state] save] \
        [c_ans ase::wrnodev_lines ngspice [c_state] restore] \
        [c_lines [c_deck [c_state]] {wrnodev|nodeset|\.include}]] {{} {} {}}

check {WR2 the save is the simulator's own command, named at the file the\
 bench chose} \
  [c_ans ase::wrnodev_lines ngspice \
     [c_state opstate [list save 1 file $WRPATH]] save] \
  [list "wrnodev $WRPATH"]

## ⚠ A RELATIVE NAME IS TAKEN AGAINST THE RUN DIRECTORY, which is where the
## simulator's own working directory is.
check {WR3 a relative file name lands in the run directory} \
  [c_ans ase::wrnodev_lines ngspice [c_state opstate {save 1 file op.ic}] save] \
  [list "wrnodev [file join $scratch op.ic]"]

## ⚠ THE HEADLINE MEASUREMENT. `wrnodev` writes `.ic`, and `.ic` is an INITIAL
## CONDITION for a transient -- not the starting guess it is for an `op`, and
## NOT a clamp that is never released (an earlier comment here said that; the
## driver measured the node relaxing to the true answer by twenty time
## constants, so what persists is the initial condition and not a clamp).
## Measured on both binaries: the same bench re-run one edit later starts at
## 2.500000e+00 with the file included and at 1.500000e+00 without it -- and at
## 1.500000e+00 again with the very same values re-spelt as `.nodeset`, which is
## released before the final Newton phase. So the default restore mode re-spells
## the file; `force` is the verbatim include, for a user who means `.ic`.
check {WR4 the default restore re-spells the simulator's own .ic file as\
 .nodeset, which cannot change the answer} \
  [c_ans ase::wrnodev_lines ngspice \
     [c_state opstate [list restore 1 file $WRPATH]] restore] \
  {{.nodeset v(in) = 5} {.nodeset v(a) = 3.33333} {.nodeset v(b) = 1.66667}}

check {WR4b force is the verbatim include, i.e. the simulator's own .ic\
 semantics, and it is NOT the default} \
  [list [c_ans ase::wrnodev_lines ngspice \
           [c_state opstate [list restore 1 mode force file $WRPATH]] restore] \
        [ase::opstate_get [c_state opstate [list restore 1 file $WRPATH]] mode seed]] \
  [list [list ".include $WRPATH"] seed]

## ⚠ THE COMMENT LINES OF THE SIMULATOR'S FILE ARE NOT CARDS, and one of them
## carries the circuit TITLE, which begins with `*` and could hold anything.
check {WR4c the file's own comment header does not become a card} \
  [apply {{d} {
     set p [file join $d weird.ic]
     set f [open $p w]
     puts $f "* Circuit: * .ic v(sneaky) = 99"
     puts $f "* Recorded at simulation time: 0"
     puts $f ".ic v(a) = 1"
     close $f
     return [ase::wrnodev_lines ngspice \
               [c_state opstate [list restore 1 file $p]] restore] }} $WRDIR] \
  {{.nodeset v(a) = 1}}

check {WR5 a save with no enabled OP row is refused, because there is no\
 operating point to save} \
  [apply {{p} {
     set a [ase::opstate_refusals ngspice [c_state opstate [list save 1 file $p] \
              analyses {{type tran enabled 1 step 1u stop 1m}}]]
     set b [ase::opstate_refusals ngspice [c_state opstate [list save 1 file $p] \
              analyses {{type op enabled 0} {type tran enabled 1 step 1u stop 1m}}]]
     set c [ase::opstate_refusals ngspice [c_state opstate [list save 1 file $p]]]
     return [list [lindex [lindex $a 0] 0] [lindex [lindex $b 0] 0] [llength $c]] }} \
   $WRPATH] {saveneedsop saveneedsop 0}

check {WR6 a seed restore from a file that is not there is refused by path,\
 and the same state in force mode is not} \
  [apply {{d} {
     set gone [file join $d nothere.ic]
     set a [ase::opstate_refusals ngspice [c_state opstate [list restore 1 file $gone]]]
     set b [ase::opstate_refusals ngspice \
              [c_state opstate [list restore 1 mode force file $gone]]]
     return [list [lindex [lindex $a 0] 0] \
                  [expr {[string first $gone [lindex [lindex $a 0] 2]] >= 0}] \
                  [llength $b]] }} $WRDIR] {opstatefile 1 0}

check {WR6b a restore mode nobody has heard of is refused rather than treated\
 as the default} \
  [apply {{p} {
     set r [ase::opstate_refusals ngspice \
              [c_state opstate [list restore 1 mode ic file $p]]]
     return [list [lindex [lindex $r 0] 0] [lindex [lindex $r 0] 1]] }} $WRPATH] \
  {opstatemode blocked}

check {WR6c a save or restore with no file named at all is refused} \
  [apply {{} {
     set r [ase::opstate_refusals ngspice [c_state opstate {save 1}]]
     set n {}
     foreach e $r { lappend n [lindex $e 0] }
     return [lsort $n] }}] {nofile}

## ⚠ POSITION, AND BOTH SIDES ARE DECISIONS. The restore is a DOT CARD and must
## stay at deck level; the save is a COMMAND and must be inside `.control` --
## and BELOW the `$sim_status` guard, so a failed operating point can never
## overwrite a good saved one with the zeros `CKTncDump` prints.
check {WR7 the restore is a deck card above .control and the save is a command\
 below the guard} \
  [apply {{p} {
     set d [c_deck [c_state opstate [list save 1 restore 1 file $p]]]
     set ctl  [c_at $d {^\.control$}]
     set ns   [c_at $d {^\.nodeset }]
     set wr   [c_at $d {^wrnodev }]
     set grd  [c_at $d {^  quit 1$}]
     set opl  [c_at $d {^op$}]
     return [list [expr {$ns >= 0 && $ns < $ctl}] [expr {$wr > $ctl}] \
                  [expr {$wr > $grd}] [expr {$wr > $opl}] \
                  [llength [c_lines $d {^wrnodev }]]] }} $WRPATH] {1 1 1 1 1}

## CONTROL for WR7: the save rides the OP row and no other, so a bench whose
## only analysis is a transient emits the card nowhere.
check {WR7b the save rides the OP analysis and no other} \
  [apply {{p} {
     set st [c_state opstate [list save 1 file $p] \
               analyses {{type op enabled 1} {type tran enabled 1 step 1u stop 1m}}]
     set d [c_deck $st]
     set wr [c_at $d {^wrnodev }]
     set tr [c_at $d {^tran }]
     return [list [llength [c_lines $d {^wrnodev }]] [expr {$wr < $tr}]] }} $WRPATH] {1 1}

check {WR8 a backend with no opstate hook emits nothing} \
  [apply {{p} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zzc4 [dict create render_deck x \
       run_cmd x log_file x result_probe x raw_file x]}]
     set st [c_state opstate [list save 1 restore 1 file $p]]
     set r [list $rc [ase::wrnodev_lines zzc4 $st save] \
                 [ase::wrnodev_lines zzc4 $st restore]]
     set ::ase::backends $save
     ase::ladder_cache_clear zzc4
     return $r }} $WRPATH] {0 {} {}}

} wrerr]} { check {WR0 section WR ran to the end} "RAISED:$wrerr" {} }

# ============================================================================
# SECTION RH -- 10c: THE RUN-HEALTH STRIP
# ============================================================================
if {[catch {

check {RH1 a bench that does not ask for it emits nothing} \
  [list [c_ans ase::runhealth_lines ngspice [c_state]] \
        [c_lines [c_deck [c_state]] {^rusage}]] {{} {}}

## ⚠ `devtimes` IS NOT IN THIS LINE AND THAT IS NOT AN OVERSIGHT. PLAN.md §10c
## names it. MEASURED on both binaries: it prints NOTHING, no warning, rc 0 --
## `resource.c:322-335` reads `CKTstat->devCounts[]`, written only inside
## `#ifdef PER_DEVICE_STATS`, and `cktload.c:30` is the literal line
## `// #define PER_DEVICE_STATS`. Offering it would be a control that does
## nothing, which is this batch's most-met defect.
check {RH2 one line, four counters, and NOT devtimes} \
  [list [c_ans ase::runhealth_lines ngspice [c_state runhealth 1]] \
        [expr {[string first devtimes \
                 [lindex [c_ans ase::runhealth_lines ngspice [c_state runhealth 1]] 0]] >= 0}]] \
  {{{rusage tranpoints accept rejected totiter}} 0}

check {RH3 the counters are read back out of a real run's log} \
  [c_ans ase::runhealth_parse ngspice $HEALTHLOG] \
  {tranpoints 2013 accept 2012 rejected 1 totiter 4045}

## CONTROL: a log with none of them must answer empty, or RH3 proves only that
## the reader can find something.
check {RH3b a log with no counters in it answers empty} \
  [c_ans ase::runhealth_parse ngspice $LADFOLD] {}

check {RH4 the line is the LAST thing in .control before the block closes} \
  [apply {{} {
     set d [c_deck [c_state runhealth 1]]
     set ru [c_at $d {^rusage }]
     set ec [c_at $d {^\.endc$}]
     set tr [c_at $d {^tran }]
     return [list [expr {$ru > $tr}] [expr {$ru < $ec}] [expr {$ec - $ru}]] }}] {1 1 1}

check {RH5 a backend with no health hook emits nothing and reads nothing} \
  [apply {{t} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zzc5 [dict create render_deck x \
       run_cmd x log_file x result_probe x raw_file x]}]
     set r [list $rc [ase::runhealth_lines zzc5 [c_state runhealth 1]] \
                 [ase::runhealth_parse zzc5 $t]]
     set ::ase::backends $save
     ase::ladder_cache_clear zzc5
     return $r }} $HEALTHLOG] {0 {} {}}

} rherr]} { check {RH0 section RH ran to the end} "RAISED:$rherr" {} }

# ============================================================================
# SECTION DK -- THE DECK A BENCH THAT ASKS FOR NONE OF THIS STILL RENDERS
# ============================================================================
if {[catch {

## ⚠ THE WHOLE FEATURE IS OPT-IN AND THIS IS THE ROW THAT SAYS SO. Three new
## state keys and four new emitters, and a bench carrying none of them must
## render the deck it rendered yesterday, byte for byte.
check {DK1 a bench carrying none of the three keys renders byte-identically to\
 one built before they existed} \
  [apply {{} {
     set base [ase::state_default]
     set st [c_state]
     set d1 [ase::backend::ngspice::render_deck $st [c_netlist]]
     ## the same state with the three keys explicitly present and empty
     dict set st opstrategy {}
     dict set st opstate {}
     dict set st runhealth {}
     set d2 [ase::backend::ngspice::render_deck $st [c_netlist]]
     ## and with the keys REMOVED, which is what a pre-1459 state file gives
     dict unset st opstrategy
     dict unset st opstate
     dict unset st runhealth
     set d3 [ase::backend::ngspice::render_deck $st [c_netlist]]
     return [list [expr {$d1 eq $d2}] [expr {$d1 eq $d3}] \
                  [regexp {optran|wrnodev|rusage|nodeset} $d1]] }}] {1 1 0}

## CONTROL for DK1: a bench that DOES ask changes the deck, or DK1 is a claim
## that the emitters never run.
check {DK1b a bench that asks for all three changes the deck in exactly four\
 places} \
  [apply {{} {
     global scratch
     set p [file join $scratch wr op.ic]
     set st [c_state opstrategy {newton 1 gmin 1 src 1 tranop 0} runhealth 1 \
               opstate [list save 1 restore 1 file $p]]
     set d [ase::backend::ngspice::render_deck $st [c_netlist]]
     return [list [llength [c_lines $d {^optran }]] \
                  [llength [c_lines $d {^wrnodev }]] \
                  [llength [c_lines $d {^rusage }]] \
                  [llength [c_lines $d {^\.nodeset }]]] }}] {1 1 1 3}

## ⚠ THE THIRD REFUSAL TIER. A `.state` can be hand-edited, so the dialog
## having been happy once is not evidence about this deck.
check {DK2 render_deck refuses a hand-edited state the form would have refused,\
 and refuses BEFORE it builds a single line} \
  [apply {{} {
     set st [c_state opstrategy {newton 0 gmin 0 src 0 tranop 0}]
     set rc [catch {ase::backend::ngspice::render_deck $st [c_netlist]} e]
     return [list $rc [string match {ase: every step*nothing was rendered} $e]] }}] {1 1}

} dkerr]} { check {DK0 section DK ran to the end} "RAISED:$dkerr" {} }

# ============================================================================
# SECTION EE -- THE REAL THING, ON BOTH BINARIES, IN BOTH DIRECTIONS
# ============================================================================
#
# ⚠ THIS SECTION EXISTS BECAUSE OF ISSUE 1449 (two halves of a feature tested in
# different suites never meet) AND ISSUE 1457 (a row that runs the real thing is
# not automatically a row that would notice). Everything above is Tcl reasoning
# about canned text. This takes the deck ASE-L renders, RUNS it, and reads the
# real log back through ASE-L's own parsers -- and then asks the SURPLUS
# question: is there a ladder line in that log that this parser has never heard
# of? A parser that finds the rungs it expects will not notice a rung it does
# not know about, and that is the direction the plan is blind in.
if {[catch {

proc ee_binaries {} {
  if {[info exists ::env(ASE_CONV_NGSPICE)] && $::env(ASE_CONV_NGSPICE) ne {}} {
    set out {} ; set i 0
    foreach b [split $::env(ASE_CONV_NGSPICE) ":"] { incr i ; lappend out [list env$i $b] }
    return $out
  }
  set home {}
  if {[info exists ::env(HOME)]} { set home $::env(HOME) }
  return [list [list apt /usr/bin/ngspice] \
               [list fork [file join $home dev ngspice build-ver_50 src ngspice]]]
}

set EERUN [file join $scratch eerun]
file mkdir $EERUN
set EESEEN {}

foreach eepair [ee_binaries] {
  lassign $eepair eetag eebin
  if {![file executable $eebin]} {
    puts "SKIPPED: EE $eetag leg (no executable at '$eebin')"
    continue
  }
  if {[lsearch -exact $EESEEN [file normalize $eebin]] >= 0} { continue }
  lappend EESEEN [file normalize $eebin]

  ## --- EE1: the strategy line ASE-L emits really switches the rung off ------
  ## ⚠ THIS IS THE ROW THE BRIEF DEMANDED: "a checkbox that silently does
  ## nothing would be worse than no checkbox". The proof is a deck that FAILS TO
  ## CONVERGE when the box is cleared and converges when it is not, on a circuit
  ## whose only reachable rung is the one the box controls.
  ## ⚠ THE FIRST DRAFT OF THIS ROW USED `.options noopiter gminsteps=0
  ## srcsteps=0` TO SILENCE THE RUNGS ABOVE, AND IT MEASURED NOTHING: the
  ## `optran` line's own first three arguments OVERRODE those options and turned
  ## rungs 1-3 straight back on, so the "cleared" deck converged at Newton at
  ## rc 0. That is the XOR rule biting the test that was written to prove a
  ## different part of it. The strategy line alone says everything: `0 0 0`
  ## leaves only the transient rung.
  set eedeck [file join $EERUN rung4.cir]
  foreach {eecase eeline} [list \
      on  "optran 0 0 0 100n 10u 0" \
      off "optran 0 0 0 0 10u 0"] {
    set f [open $eedeck w]
    puts $f "* ASE-L 1459 EE1: only the transient rung can solve this"
    puts $f "v1 in 0 1"
    puts $f "r1 in out 1k"
    puts $f "c1 out 0 1n"
    puts $f ".control"
    puts $f $eeline
    puts $f "op"
    puts $f "print v(out)"
    puts $f ".endc"
    puts $f ".end"
    close $f
    set eerc [catch {exec $eebin -b $eedeck 2>@1} eeout]
    set ::EE1($eecase) [list $eerc $eeout]
  }
  ## with every other rung off in the line itself, the transient rung is the
  ## only one left: armed -> rc 0 and the TRANSIENT value, 9.999550e-01 rather
  ## than the 1.000000e+00 a real solve gives; cleared -> the run dies
  check "EE1/$eetag clearing the transient rung really clears it -- the deck\
 converges with it and fails without it" \
    [list [lindex $::EE1(on) 0] \
          [regexp {v\(out\) = 9\.99955} [lindex $::EE1(on) 1]] \
          [lindex $::EE1(off) 0] \
          [expr {[string first {The operating point could not be simulated successfully} \
                   [lindex $::EE1(off) 1]] >= 0}]] \
    {0 1 1 1}

  ## --- EE2: ASE-L's own deck, run, and its ladder read back -----------------
  set EEST [c_state opstrategy {newton 0 gmin 1 gminsteps 10 src 1 srcsteps 10 tranop 1} \
              runhealth 1 analyses {{type op enabled 1}} rundir $EERUN \
              design [dict create cell eebench lib $EERUN]]
  set EENL "* ee bench\n.model dmod d(is=1e-14 n=1)\nv1 in 0 5\nr1 in a 1\nd1 a b dmod\nd2 b c dmod\nd3 c 0 dmod\n.end\n"
  set eedeck2 [file join $EERUN eebench_ase.spice]
  set f [open $eedeck2 w]
  puts -nonewline $f [ase::backend::ngspice::render_deck $EEST $EENL]
  close $f
  ## `set ngdebug` is what turns the ladder from three lines into the per-step
  ## trace the pane reads; ASE-L's own pre_commands carrier is how a bench asks.
  set EEST2 [c_state opstrategy {newton 0 gmin 1 gminsteps 10 src 1 srcsteps 10 tranop 1} \
               runhealth 1 analyses {{type op enabled 1}} rundir $EERUN \
               design [dict create cell eebench lib $EERUN] \
               pre_commands {{cmd {set ngdebug}}}]
  set f [open $eedeck2 w]
  puts -nonewline $f [ase::backend::ngspice::render_deck $EEST2 $EENL]
  close $f
  set eerc2 [catch {exec $eebin -b $eedeck2 2>@1} eeout2]
  set eelad [ase::ladder_parse ngspice $eeout2]
  set eest {}
  foreach r [dict get $eelad rungs] { lappend eest [dict get $r id] [dict get $r state] }
  set eegm {}
  foreach r [dict get $eelad rungs] {
    if {[dict get $r id] eq {gmin}} { set eegm [dict get $r trials] }
  }
  check "EE2/$eetag the deck ASE-L renders runs, and ASE-L's own parser reads\
 its ladder back: gmin stepping answered, in eleven measured steps" \
    [list $eerc2 $eest [llength $eegm] [lindex $eegm 0] [lindex $eegm end] \
          [dict get $eelad verdict]] \
    {0 {newton passedover gmin ok src notrun tranop notrun} 11 1.0000E-02 1.0000E-12 ok}

  check "EE2b/$eetag the run-health line ASE-L emitted really answers, and the\
 parser reads the counters it wrote" \
    [apply {{t} {
       set h [ase::runhealth_parse ngspice $t]
       return [list [lsort [dict keys $h]] \
                    [expr {[dict exists $h totiter] &&
                           [string is integer -strict [dict get $h totiter]] &&
                           [dict get $h totiter] > 0}]] }} $eeout2] \
    {{accept rejected totiter tranpoints} 1}

  ## --- EE3: THE SURPLUS DIRECTION -------------------------------------------
  ## ⚠ EE2 asks "did the parser find the rungs it expects", and it would pass
  ## with a rung the parser has never heard of sitting unread in the same log.
  ## This asks the other way: every `Note:`/`Warning:` line the ladder really
  ## printed must be claimed by a marker or by a trial pattern. A new upstream
  ## rung, a renamed message, or a variant nobody wired up shows up here as an
  ## unclaimed line, by its own text.
  set eedeck3 [file join $EERUN singular.cir]
  set f [open $eedeck3 w]
  puts $f "* ASE-L 1459 EE3: the whole ladder, every rung exercised"
  puts $f "i1 0 1 1"
  puts $f "c1 1 0 1n"
  puts $f ".control"
  puts $f "op"
  puts $f "print v(1)"
  puts $f ".endc"
  puts $f ".end"
  close $f
  catch {exec $eebin -b $eedeck3 2>@1} eeout3
  set eeunclaimed {}
  set eeknown {}
  foreach {eid em} [ase::backend::ngspice::_ladder_markers] {
    foreach pair [dict get $em start] { lappend eeknown [lindex $pair 1] }
    foreach k {ok bad} { foreach lit [dict get $em $k] { lappend eeknown $lit } }
    if {[dict exists $em off]} {
      foreach lit [dict get $em off] { lappend eeknown $lit }
    }
  }
  ## the per-step trace lines and the messages that are NOT rung events
  set eeignore {{Trying gmin =} {Supplies reduced to} {One successful gmin step}
                {One successful source step} {Further gmin increment}
                {Last gmin step failed} {gmin step failed}
                {singular matrix} {Simulation executed from .control section}
                {No compatibility mode selected} {Ramptime enabled}
                {The operating point could not be simulated successfully}
                {Any of the following steps may fail}
                {no resource usage information}}
  foreach eeline [split $eeout3 "\n"] {
    set eeline [string trim $eeline]
    if {![regexp {^(Note|Warning|Error):} $eeline]} { continue }
    set eehit 0
    foreach lit $eeknown { if {[string first $lit $eeline] >= 0} { set eehit 1 ; break } }
    if {!$eehit} {
      foreach ig $eeignore { if {[string first $ig $eeline] >= 0} { set eehit 1 ; break } }
    }
    if {!$eehit} { lappend eeunclaimed $eeline }
  }
  ## and the positive control: the marker table really did claim something, so
  ## an always-empty `unclaimed` list cannot pass by doing nothing
  set eeclaimed 0
  foreach eeline [split $eeout3 "\n"] {
    foreach lit $eeknown { if {[string first $lit $eeline] >= 0} { incr eeclaimed ; break } }
  }
  check "EE3/$eetag every ladder line the simulator really printed is a line\
 this parser knows about -- the SURPLUS direction, with the count of claimed\
 lines as its control" \
    [list [lsort -unique $eeunclaimed] [expr {$eeclaimed >= 6}]] {{} 1}

  ## --- EE4: a real starred table, parsed --------------------------------
  set eedeck4 [file join $EERUN ncstar.cir]
  set f [open $eedeck4 w]
  puts $f "* ASE-L 1459 EE4: an operating point that really does not converge"
  puts $f "v1 in 0 5"
  puts $f "r1 in 1 1"
  puts $f "b1 1 0 i=1e-30*(exp(v(1)/0.0002)-1)"
  puts $f "r2 1 2 1"
  puts $f "b2 2 0 i=1e-30*(exp(v(2)/0.0002)-1)"
  puts $f ".options reltol=1e-6 vntol=1e-9 abstol=1e-15"
  puts $f ".control"
  puts $f "optran 1 0 0 0 10u 0"
  puts $f "op"
  puts $f "print v(1)"
  puts $f ".endc"
  puts $f ".end"
  close $f
  catch {exec $eebin -b $eedeck4 2>@1} eeout4
  check "EE4/$eetag a real non-converging run's table is read, the starred\
 nodes come back, and the branch current is not among them" \
    [list [llength [ase::ncdump_parse ngspice $eeout4]] \
          [ase::ncdump_failing ngspice $eeout4] \
          [ase::ncdump_failing ngspice $eeout4 {node branch}]] \
    {4 {1 2} {1 2 v1#branch}}

  ## --- EE5: the save/restore round trip, for real ---------------------------
  ## ⚠ AND IT IS THE MEASUREMENT THE RESTORE MODE EXISTS FOR, run rather than
  ## quoted: the same bench one edit later, with the simulator's own file
  ## included verbatim, starts at the STALE value; re-spelt as ASE-L emits it,
  ## it starts at the right one.
  set eesave [file join $EERUN stale.ic]
  file delete -force $eesave
  set eedeck5 [file join $EERUN cap.cir]
  set f [open $eedeck5 w]
  puts $f "* ASE-L 1459 EE5: capture at 5 V"
  puts $f "v1 in 0 5"
  puts $f "r1 in a 1k"
  puts $f "r2 a 0 1k"
  puts $f "c1 a 0 1n"
  puts $f ".control"
  puts $f "op"
  puts $f "wrnodev $eesave"
  puts $f ".endc"
  puts $f ".end"
  close $f
  catch {exec $eebin -b $eedeck5 2>@1} eeout5
  set eerest [ase::wrnodev_lines ngspice \
                [c_state opstate [list restore 1 file $eesave]] restore]
  set eerestf [ase::wrnodev_lines ngspice \
                 [c_state opstate [list restore 1 mode force file $eesave]] restore]
  proc ee_t0 {bin dir cards} {
    set p [file join $dir use.cir]
    set f [open $p w]
    puts $f "* ASE-L 1459 EE5: the same bench at 3 V"
    puts $f "v1 in 0 3"
    puts $f "r1 in a 1k"
    puts $f "r2 a 0 1k"
    puts $f "c1 a 0 1n"
    foreach c $cards { puts $f $c }
    puts $f ".control"
    puts $f "tran 1n 20n"
    puts $f "print v(a)"
    puts $f ".endc"
    puts $f ".end"
    close $f
    catch {exec $bin -b $p 2>@1} out
    foreach l [split $out "\n"] {
      if {[regexp {^0\s+0\.000000e\+00\s+(\S+)} $l -> v]} { return $v }
    }
    return NOT0
  }
  check "EE5/$eetag the simulator's own save file, included verbatim, changes a\
 stale transient's answer -- and the .nodeset ASE-L emits instead does not" \
    [list [file exists $eesave] \
          [ee_t0 $eebin $EERUN {}] \
          [ee_t0 $eebin $EERUN $eerestf] \
          [ee_t0 $eebin $EERUN $eerest]] \
    {1 1.500000e+00 2.500000e+00 1.500000e+00}
}

} eeerr]} { check {EE0 section EE ran to the end} "RAISED:$eeerr" {} }

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456). `tests/banner_rule.tcl`'s `banner_complete`
# requires a WHOLE-LINE `OVERALL: ok`, and `run_regression.tcl` counts a case with
# no banner as a HARNESS failure however green its own checks are. Three suites in
# this batch shipped without one and were scored a HARNESS failure on every T1 run
# since stage 7.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
