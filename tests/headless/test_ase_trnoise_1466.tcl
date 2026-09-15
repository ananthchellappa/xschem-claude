# tests/headless/test_ase_trnoise_1466.tcl -- ISSUE 1466: TRANSIENT NOISE AND
# RANDOM SOURCES, WITH NO SCHEMATIC EDIT. doc/claude/ase_analyses_batch/PLAN.md
# Stage 13, the DECK half (task 1 of 2; the Tran form's section is task 2).
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# ngspice can make any independent source emit transient noise -- white, 1/f and
# random-telegraph (`trnoise`) -- or a random value held for a time (`trrandom`).
# It is the noise `.NOISE` cannot show: jitter on an edge, a comparator flipping.
# ASE-L had no way to ask for it. The only door was typing POSITIONAL arguments
# onto a source on the schematic, which ASE-L's founding doctrine forbids and
# which two shipped ngspice examples get wrong.
#
# ============================================================================
# ⚠ THE MEASUREMENTS THAT DECIDE THE SHAPE -- 2026-09-15, BOTH BINARIES UNLESS
# MARKED (`/usr/bin/ngspice` 45.2 and the fork), HOME pointed at an empty dir
# ============================================================================
#  1. `alter v1 trnoise = [ 1m 1u 0 0 0 0 0 ]` works on a V and on an I source,
#     SI suffixes and all, and still reaches a transient after an earlier `op`.
#  2. ⚠ WITH NO RESTORE, THE NEXT TRANSIENT IS NOISY TOO: rms 0.82 V on a `dc 0`
#     source and 5004 points where its own card asks for 108. A zero vector
#     restores it (rms 0, 108 points), and clears a `trrandom` source as well.
#     Hence the `post` leg, and section EE's second row is the proof.
#  3. `alter` does NOT survive `reset`. No ASE-L deck resets; a campaign shard
#     is its own process.
#  4. ⚠ `trrandom` ON A CURRENT SOURCE FREEZES: `trrandom(2 1u 1m 1m 0)` draws
#     one value after its delay and holds it to the end; on a V source, 501.
#     Hence a V source + VCCS for an injected random current (row NE4).
#  5. fork only -- `PLAN.md`'s `ase_inoise_1` is an XSPICE `a` card (MIF-ERROR,
#     rc 1); a negative noise timestep through `alter` hangs (rc 124 under
#     `timeout 10`); a current source on a digital node drives a singular analog
#     node of the same name and ends rc 0.
#  6. a carrier on a net nothing else touches runs at rc 0 and says nothing.
#  7. forced `optran` + `trrandom` with TD = 0 -> the transient's first point is
#     a random draw; TD = 1n -> 0.
#  8. `notrnoise`: white and 1/f gone; RTS on a source with a noise timestep of 0
#     and every `trrandom` source untouched.
#  9. under `.options seed=5` (or `setseed 5`) RTS and `trrandom` repeat run to
#     run and white noise does not.
#
# ============================================================================
# ⚠ NO ROW PINS A NUMBER THE SIMULATOR DRAWS, AND NONE PINS A POINT COUNT
# ============================================================================
# White noise differs on every run on both binaries, and the two binaries
# disagree about a transient's point count (`binary-differences.md` #7; 5008
# against 4415 here). Section EE asserts PRESENCE, ABSENCE, EQUALITY BETWEEN TWO
# RUNS and an order-of-magnitude window -- never a value.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#   NR  the registry entry and the contract as schema
#   NB  a backend with no contract gets nothing
#   NE  the emitted lines and their places
#   NK  the refusals and the cautions
#   NX  the derived readouts
#   NS  the seed and kill-switch data
#   NC  the corpus and the round trip
#   EE  the END-TO-END run, on BOTH binaries (guarded legs)
#   NP  the checkpoint plan counts the noise (debt M22)
#   EC  a CHECKPOINTED noisy transient END TO END, on BOTH binaries (guarded)
#
# THE HISTORY:
#   see the RESULT line of the first commit that carries this file -- issue
#   1466 ships it; raise the number here when rows are added, never lower it.
#   62 -> 76 AND RAISED, debt M22 (Stage 13 task 3, receipt 43): section NP --
#   six pure-Tcl rows, the checkpoint planner raising the card's estimate by the
#   noise -- and section EC, four rows per binary, a noisy transient whose card
#   is under `ase::ckpt_floor` rendered, run through ASE-L's own checkpoint loop
#   and read back. 62 + 6 + 2 x 4 = 76 with both binaries present; a missing one
#   prints its SKIPPED line and the count falls by eight, never silently. One
#   existing row's COMMENT moved and no term of it did: NX2's fourth term (the
#   salvage hook stays the card's) is still true, for a new reason.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_trnoise_1466.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_trnoise_1466.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name got} { check $name [expr {$got ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch nz1466]
catch {test_sim_registry_isolate}

## A call that never blows the suite up: an absent proc is NOPROC and a raise is
## RAISED:<message>, so a row reports a defect instead of a stack trace. `--nogui
## --pipe` exits 0 on an uncaught mid-script error, so a raise here would
## otherwise end the suite silently at rc 0 with no RESULT line.
proc s_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc s_dget {d k} {
  if {[catch {dict get $d $k} v]} { return MISSING }
  return $v
}
proc s_broken {v} {
  return [expr {[string match {NOPROC*} $v] || [string match {RAISED:*} $v]}]
}
## The `{token field}` pairs of an emit check, so a row can ask whether ONE
## offence is among them without depending on the order they are reported in.
proc s_pairs {v} {
  set o {}
  if {[s_broken $v]} { return BROKEN }
  foreach f $v { lappend o [lrange $f 0 1] }
  return $o
}

proc nz_netlist {} {
  return "* nzbench\nvdd vdd 0 dc 1.8\nvsig in 0 dc 0 sin(0 1 1k)\nvrts rts 0 dc 0\niref 0 bias dc 0\nr1 vdd out 1k\nr2 out 0 1k\nrin in 0 1k\nrrts rts 0 1k\nrb bias 0 1k\n.end\n"
}
proc nz_row {noise args} {
  return [concat [list type tran enabled 1 step 1u stop 2m noise $noise] $args]
}
proc nz_state {ans {rundir {}} args} {
  global scratch
  if {$rundir eq {}} { set rundir $scratch }
  set st [ase::state_default]
  dict set st design [dict create cell nzbench lib $scratch]
  dict set st rundir $rundir
  dict set st simulator ngspice
  dict set st analyses $ans
  foreach {k v} $args { dict set st $k $v }
  return $st
}
proc nz_deck {st {nl {}}} {
  if {$nl eq {}} { set nl [nz_netlist] }
  return [ase::backend::ngspice::render_deck $st $nl]
}
proc nz_lines {st} {
  if {[catch {nz_deck $st} d]} { return [list RAISED:$d] }
  return [split [string trimright $d "\n"] "\n"]
}
proc nz_facts {{nl {}}} {
  if {$nl eq {}} { set nl [nz_netlist] }
  return [ase::netlist_facts $nl]
}
## Every finding whose sentence matches `pat`, as `{entry verdict}` pairs.
## ⚠ BROKEN, NOT `{}`, WHEN THE READER RAISED OR IS MISSING -- otherwise every
## row expecting "no finding" would pass on a reader that no longer exists.
proc nz_find {row pat {facts {}} {state {}}} {
  if {$facts eq {}} { set facts [nz_facts] }
  set v [s_ans ase::stimuli_verdicts ngspice $row $facts $state]
  if {[s_broken $v]} { return BROKEN }
  set out {}
  foreach f $v {
    if {[string match $pat [lindex $f 2]]} { lappend out [list [lindex $f 0] [lindex $f 1]] }
  }
  return $out
}
proc nz_count {row {facts {}} {state {}}} {
  if {$facts eq {}} { set facts [nz_facts] }
  set v [s_ans ase::stimuli_verdicts ngspice $row $facts $state]
  if {[s_broken $v]} { return BROKEN }
  return [llength $v]
}

# ===========================================================================
# NR -- THE REGISTRY ENTRY AND THE CONTRACT AS SCHEMA
# ===========================================================================
set NR1TYPES {}
foreach nrt [dict keys [s_ans ase::analysis_types ngspice]] {
  if {[s_ans ase::analysis_stimuli ngspice $nrt] ne {}} { lappend NR1TYPES $nrt }
}
## ⚠ AND THE WINDOW DRAWS NOTHING FOR IT. `ase::ui::chana_show` grids a table
## button for any type whose `setup` contract declares `columns`; the transient's
## table is NOT a `setup` contract, so both readers answer empty and this commit
## puts no widget on the Tran form. That is what keeps task 1 headless.
check {NR1 exactly one shipped type declares a stimuli contract, it is tran, the\
 registry is self-consistent, and tran has no setup contract the window would draw} \
  [list $NR1TYPES \
        [s_dget [s_ans ase::analysis_stimuli ngspice tran] key] \
        [s_ans ase::analysis_schema_errors ngspice] \
        [s_ans ase::analysis_setup ngspice tran] \
        [s_ans ase::analysis_setup_columns ngspice tran]] \
  {tran noise {} {} {}}

## ⚠ STAGE 9's LESSON 2, APPLIED: a key licensed on ONE type is invisible to every
## blanket list, and the Options editor's two sites ask `ase::analysis_setup_key`.
## The window's own skip expression is recomposed from core here, because
## `ase::ui::chana_fields` is not loaded headless.
check {NR2 the noise table is a legal key on a tran row and refused on a dc row,\
 and the one question every surface asks names it} \
  [list [s_ans ase::analysis_emit_check ngspice [nz_row {{src vdd func trnoise na 1m ts 10u}}]] \
        [expr {[lsearch -exact [s_pairs [s_ans ase::analysis_emit_check ngspice \
           {type dc enabled 1 noise {{src vdd}}}]] {unknownkey noise}] >= 0}] \
        [s_ans ase::analysis_setup_key ngspice tran] \
        [s_ans ase::analysis_setup_key ngspice sp] \
        [expr {[lsearch -exact [concat [s_ans ase::analysis_nonsetting_keys] \
                  [s_ans ase::analysis_setup_key ngspice tran]] noise] >= 0}]] \
  {{} 1 noise ports 1}

## ⚠ ONE POSITIONAL LIST PER FUNCTION, AND EVERY ARGUMENT HAS A LABEL, so task 2
## can show every value the deck carries in the position the deck carries it.
set NR3NOLABEL 0
foreach nrf {trnoise trrandom} {
  foreach nrd [s_ans ase::stimuli_args ngspice tran $nrf] {
    if {[catch {dict get $nrd label}]} { incr NR3NOLABEL }
  }
}
check {NR3 all seven trnoise and all five trrandom arguments are declared in their\
 positions, each with a label, and the roles name the right ones} \
  [list [s_ans ase::stimuli_arg_names ngspice tran trnoise] \
        [s_ans ase::stimuli_arg_names ngspice tran trrandom] \
        $NR3NOLABEL \
        [s_ans ase::stimuli_arg_role ngspice tran trnoise interval] \
        [s_ans ase::stimuli_arg_role ngspice tran trnoise amplitude] \
        [s_ans ase::stimuli_arg_role ngspice tran trnoise flicker] \
        [s_ans ase::stimuli_arg_role ngspice tran trrandom interval] \
        [s_ans ase::stimuli_arg_role ngspice tran trrandom amplitude]] \
  {{na ts nalpha namp rtsam rtscapt rtsemt} {dist ts td param1 param2} 0 ts na namp ts {}}

## A KEY READ BY NOTHING IS A KEY CHECKED BY NOTHING (issue 1428's S35). A
## fixture backend whose one entry carries the contract under test.
proc nk_types {stimuli {setup {}}} {
  set e [dict create label zz baseline 1 registered 1 emitorder 10 \
    fields {{name ff kind real label Ff}} \
    emit {{role analysis tmpl {zz @ff?}}} \
    results {viewer {kind sweep}} \
    plots {{select {ZZ Analysis} role sweep results viewer label zz}}]
  if {$stimuli ne {}} { dict set e stimuli $stimuli }
  if {$setup ne {}} { dict set e setup $setup }
  return [dict create zz $e]
}
set ::NKST {} ; set ::NKSETUP {}
proc nk_hook {} { return [nk_types $::NKST $::NKSETUP] }
proc nk_errs {st {setup {}}} {
  set save $::ase::backends
  set ::NKST $st ; set ::NKSETUP $setup
  ase::register_backend zzst [dict create render_deck x run_cmd x log_file x \
    result_probe x raw_file x analysis_types nk_hook]
  ase::analysis_cache_clear zzst
  set e [s_ans ase::analysis_schema_errors zzst]
  set probe [s_ans ase::analysis_setup_key zzst zz]
  set ::ase::backends $save
  ase::analysis_cache_clear zzst
  return [list $e $probe]
}
set NKGOOD {key nn selector func \
            lines ::ase::backend::ngspice::noise_alter_lines \
            targets {{name src route alter label S}} \
            functions {fx {label Fx args {{name a label A}}}}}
## NON-VACUITY: the good contract reaches core through the fixture (its key is
## answered), so an empty registry cannot be mistaken for a clean one.
check {NR4a the fixture backend is really read, and a well-formed contract is clean} \
  [nk_errs $NKGOOD] {{} nn}
check {NR4 each way of getting the contract wrong is named} \
  [list [lindex [nk_errs [dict remove $NKGOOD key]] 0] \
        [lindex [nk_errs [dict replace $NKGOOD key ff]] 0] \
        [lindex [nk_errs [dict replace $NKGOOD key id]] 0] \
        [lindex [nk_errs [dict remove $NKGOOD selector]] 0] \
        [lindex [nk_errs [dict remove $NKGOOD lines]] 0] \
        [lindex [nk_errs [dict replace $NKGOOD lines ::no::such::proc]] 0] \
        [lindex [nk_errs [dict replace $NKGOOD check ::no::such::proc]] 0] \
        [lindex [nk_errs [dict remove $NKGOOD targets]] 0] \
        [lindex [nk_errs [dict remove $NKGOOD functions]] 0] \
        [lindex [nk_errs [dict replace $NKGOOD functions {fx {label Fx}}]] 0] \
        [lindex [nk_errs [dict replace $NKGOOD functions {fx {label Fx args {{name a}}}}]] 0] \
        [lindex [nk_errs {not a dict at all}] 0] \
        [lindex [nk_errs $NKGOOD {key pp noun port min 2 \
           columns {{name aa label A}} lines ::ase::backend::ngspice::sp_alter_lines}] 0]] \
  [list {{zz nostimulikey {}}} {{zz stimulikeyclash ff}} {{zz stimulikeyclash id}} \
        {{zz nostimuliselector {}}} {{zz nostimulilines {}}} \
        {{zz badstimulilines ::no::such::proc}} {{zz badstimulihook ::no::such::proc}} \
        {{zz nostimulitargets {}}} {{zz nostimulifunctions {}}} \
        {{zz badstimulifunction fx}} {{zz badstimuliarg fx}} {{zz badstimuli {}}} \
        {{zz twotables {}}}]

## ⚠ THE `setup` READERS STILL ANSWER EMPTY FOR tran, SO NOTHING OF STAGE 9's
## FIRES ON A TRANSIENT -- while the ROW reader, which asks the generalised key,
## counts the noise table (core may count entries and no more).
set NR5ROW [nz_row {{src vdd func trnoise na 1m ts 10u} {net out func trnoise na 1m ts 10u}}]
check {NR5 Stage 9's setup legs say nothing for tran, and the row reader counts\
 the noise table} \
  [list [s_ans ase::analysis_setup_emit ngspice $NR5ROW lines] \
        [s_ans ase::analysis_setup_emit ngspice $NR5ROW post] \
        [s_ans ase::analysis_setup_banner ngspice tran $NR5ROW] \
        [llength [s_ans ase::analysis_setup_rows ngspice tran $NR5ROW]] \
        [llength [s_ans ase::stimuli_rows ngspice $NR5ROW]]] \
  {{} {} {state clear} 2 2}

# ===========================================================================
# NB -- A BACKEND WITH NO CONTRACT GETS NOTHING (D34-D37: no fallback content)
# ===========================================================================
proc nb_types {} {
  set e [dict get [ase::analysis_types ngspice] tran]
  dict unset e stimuli
  dict set e needs [lsearch -all -inline -not -exact [dict get $e needs] stimuli_check]
  return [dict create tran $e]
}
proc nb_probe {script} {
  set save $::ase::backends
  ase::register_backend zznz [dict create render_deck x run_cmd x log_file x \
    result_probe x raw_file x analysis_types nb_types si_suffixes \
    ::ase::backend::ngspice::si_suffixes]
  ase::analysis_cache_clear zznz
  set r [uplevel 1 $script]
  set ::ase::backends $save
  ase::analysis_cache_clear zznz
  return $r
}
set NBROW [nz_row {{src vdd func trnoise na 1m ts 10u} {net out func trrandom dist 2 ts 1u param1 1m}}]
set NBST [nz_state [list $NBROW]]
check {NB1 the stub backend is really read -- it answers a tran line and no contract} \
  [nb_probe {list [dict keys [s_ans ase::analysis_types zznz]] \
                  [s_ans ase::analysis_line zznz {type tran enabled 1 step 1u stop 2m}] \
                  [s_ans ase::analysis_stimuli zznz tran]}] \
  {tran {tran 1u 2m} {}}
check {NB2 and every reader answers empty for it -- no key, no lines, no carrier, no\
 finding, no seed sentence, no kill report, no readout -- and the table is refused} \
  [nb_probe {list [s_ans ase::analysis_setup_key zznz tran] \
                  [lrange [lindex [s_ans ase::analysis_emit_check zznz $NBROW] 0] 0 1] \
                  [s_ans ase::stimuli_emit zznz $NBROW lines $NBST 0] \
                  [s_ans ase::stimuli_emit zznz $NBROW post $NBST 0] \
                  [s_ans ase::stimuli_netlist_lines zznz [dict replace $NBST simulator zznz]] \
                  [s_ans ase::stimuli_verdicts zznz $NBROW [nz_facts] $NBST] \
                  [s_ans ase::stimuli_seed_report zznz $NBST $NBROW] \
                  [s_ans ase::stimuli_kill_report zznz $NBST $NBROW] \
                  [s_ans ase::stimuli_readout zznz $NBST $NBROW 1]}] \
  {{} {unknownkey noise} {} {} {} {} {} {} {}}

# ===========================================================================
# NE -- THE EMITTED LINES AND THEIR PLACES
# ===========================================================================
proc nz_has {lines text} { return [expr {[lsearch -exact $lines $text] >= 0}] }
proc nz_pos {lines text {from 0}} { return [lsearch -exact -start $from $lines $text] }

set NE1L [nz_lines [nz_state [list [nz_row {{src vdd func trnoise na 1m ts 10u}}]]]]
## ⚠ ALL SEVEN, ALWAYS, POSITIONALLY, PADDED WITH 0 -- the short form is a heap
## read and a silent zero, and the padded form was measured benign.
check {NE1 an alter-route trnoise entry emits all seven arguments, padded with 0,\
 above its transient} \
  [list [nz_has $NE1L {alter vdd trnoise = [ 1m 10u 0 0 0 0 0 ]}] \
        [expr {[nz_pos $NE1L {alter vdd trnoise = [ 1m 10u 0 0 0 0 0 ]}] < [nz_pos $NE1L {tran 1u 2m}]}] \
        [s_ans ase::stimuli_values ngspice tran {src vdd func trnoise na 1m ts 10u}]] \
  {1 1 {1m 10u 0 0 0 0 0}}

set NE2L [nz_lines [nz_state [list [nz_row {{src vdd func trrandom dist 2 ts 100u param1 1m}}]]]]
check {NE2 an alter-route trrandom entry emits all five arguments, padded with 0} \
  [list [nz_has $NE2L {alter vdd trrandom = [ 2 100u 0 1m 0 ]}] \
        [s_ans ase::stimuli_values ngspice tran {src vdd func trrandom dist 2 ts 100u param1 1m}]] \
  {1 {2 100u 0 1m 0}}

## ⚠ THE CARRIER IS IN THE NETLIST SLOT, IMMEDIATELY AFTER THE LAST NETLIST CARD,
## AND ITS NAME BEGINS WITH THE LETTER OF THE DEVICE IT IS. `PLAN.md`'s
## `ase_inoise_1` begins with `a` and is an XSPICE card (measured, rc 1).
set NE3L [nz_lines [nz_state [list [nz_row {{net out func trnoise na 1m ts 10u}}]]]]
check {NE3 an injected trnoise entry adds a quiet current carrier right after the\
 netlist, outside .control, and alters the carrier} \
  [list [nz_has $NE3L {iase_noise_1_1 0 out dc 0}] \
        [expr {[nz_pos $NE3L {iase_noise_1_1 0 out dc 0}] == [nz_pos $NE3L {rb bias 0 1k}] + 1}] \
        [expr {[nz_pos $NE3L {iase_noise_1_1 0 out dc 0}] < [nz_pos $NE3L .control]}] \
        [nz_has $NE3L {alter iase_noise_1_1 trnoise = [ 1m 10u 0 0 0 0 0 ]}]] \
  {1 1 1 1}

## ⚠ A RANDOM CURRENT GOES IN THROUGH A V SOURCE AND A 1 S VCCS, because a
## `trrandom` current source can stop redrawing after its first value (measured).
set NE4L [nz_lines [nz_state [list [nz_row {{net out func trrandom dist 2 ts 100u param1 1m}}]]]]
check {NE4 an injected trrandom entry becomes a voltage source and a VCCS into the\
 net, and never a current source} \
  [list [nz_has $NE4L {vase_noise_1_1 ase_noise_1_1 0 dc 0}] \
        [nz_has $NE4L {gase_noise_1_1 0 out ase_noise_1_1 0 1}] \
        [nz_has $NE4L {alter vase_noise_1_1 trrandom = [ 2 100u 0 1m 0 ]}] \
        [expr {[lsearch -glob $NE4L {iase_noise_*}] < 0}]] \
  {1 1 1 1}

## ⚠ THE RESTORE's PLACE: below the guard (a failed transient has nothing to put
## back), above `remzerovec` and the write.
set NE5ST [nz_state [list [nz_row {{src vdd func trnoise na 1m ts 10u}}]]]
set NE5L [nz_lines $NE5ST]
set NE5G [lindex [ase::backend::ngspice::sim_status_guard] 0]
set NE5CARD [nz_pos $NE5L {tran 1u 2m}]
set NE5GI [nz_pos $NE5L $NE5G $NE5CARD]
set NE5RI [nz_pos $NE5L {alter vdd trnoise = [ 0 0 0 0 0 0 0 ]}]
set NE5ZI [nz_pos $NE5L remzerovec $NE5CARD]
set NE5WI [nz_pos $NE5L "write [ase::backend::ngspice::raw_file $NE5ST]" $NE5CARD]
check {NE5 every altered source is put back by a zero trnoise, below the guard and\
 above remzerovec and the write} \
  [list [expr {$NE5CARD >= 0 && $NE5GI > $NE5CARD}] \
        [expr {$NE5RI > $NE5GI}] [expr {$NE5ZI > $NE5RI}] [expr {$NE5WI > $NE5ZI}]] \
  {1 1 1 1}

set NE6L [nz_lines [nz_state [list [nz_row {{src vdd func trnoise na 1m ts 10u}} x {{echo HATCH}}]]]]
check {NE6 the verbatim hatch stays immediately above the card, with the noise above\
 the hatch} \
  [list [expr {[nz_pos $NE6L {echo HATCH}] == [nz_pos $NE6L {tran 1u 2m}] - 1}] \
        [expr {[nz_pos $NE6L {alter vdd trnoise = [ 1m 10u 0 0 0 0 0 ]}] < [nz_pos $NE6L {echo HATCH}]}]] \
  {1 1}

set NE7A [nz_lines [nz_state [list [nz_row {{net out func trnoise na 1m ts 10u enabled 0}}]]]]
set NE7B [nz_lines [nz_state [list [dict replace [nz_row {{net out func trnoise na 1m ts 10u}}] enabled 0] \
                                   {type op enabled 1}]]]
check {NE7 a switched-off entry emits nothing at all, and a switched-off transient\
 carries no carrier} \
  [list [lsearch -all -glob $NE7A {*ase_noise*}] [lsearch -all -glob $NE7A {alter *}] \
        [lsearch -all -glob $NE7B {*ase_noise*}]] \
  {{} {} {}}

set NE8L [nz_lines [nz_state [list [nz_row {{src vdd func trnoise na 1m ts 10u}}] \
                                   [nz_row {{net out func trnoise na 1m ts 10u}} stop 3m]]]]
set NE8C1 [nz_pos $NE8L {tran 1u 2m}]
set NE8C2 [nz_pos $NE8L {tran 1u 3m}]
check {NE8 two transients: each row's noise is given above its own card only, put\
 back before the next, and the carriers are named by row} \
  [list [expr {[nz_pos $NE8L {alter vdd trnoise = [ 1m 10u 0 0 0 0 0 ]}] < $NE8C1}] \
        [expr {[nz_pos $NE8L {alter vdd trnoise = [ 0 0 0 0 0 0 0 ]}] > $NE8C1 \
               && [nz_pos $NE8L {alter vdd trnoise = [ 0 0 0 0 0 0 0 ]}] < $NE8C2}] \
        [expr {[nz_pos $NE8L {alter iase_noise_2_1 trnoise = [ 1m 10u 0 0 0 0 0 ]}] > \
               [nz_pos $NE8L {alter vdd trnoise = [ 0 0 0 0 0 0 0 ]}] \
               && [nz_pos $NE8L {alter iase_noise_2_1 trnoise = [ 1m 10u 0 0 0 0 0 ]}] < $NE8C2}] \
        [nz_has $NE8L {iase_noise_2_1 0 out dc 0}] \
        [expr {[nz_pos $NE8L {alter iase_noise_2_1 trnoise = [ 0 0 0 0 0 0 0 ]}] > $NE8C2}]] \
  {1 1 1 1 1}

## ⚠ AN EMPTY TABLE AND NO TABLE ARE ONE DECK, AND IT CARRIES NOTHING THIS STAGE
## EMITS -- which is what keeps every committed deck golden where it was.
set NE9A [s_ans nz_deck [nz_state [list {type tran enabled 1 step 1u stop 2m}]]]
set NE9B [s_ans nz_deck [nz_state [list [nz_row {}]]]]
check {NE9 a transient with an empty noise table renders byte-identically to one\
 with none, and neither deck carries a noise line} \
  [list [expr {$NE9A eq $NE9B && ![s_broken $NE9A]}] \
        [expr {[string first ase_noise $NE9A] < 0}] \
        [expr {[string first { trnoise = } $NE9A] < 0}]] \
  {1 1 1}

# ===========================================================================
# NK -- THE REFUSALS AND THE CAUTIONS
# ===========================================================================
set NK1ROW [nz_row {{src vdd func trnoise na 1m ts -1u}}]
set NK1RD [s_ans nz_deck [nz_state [list $NK1ROW]]]
check {NK1 a negative noise timestep is refused as fatal, by the precondition AND by\
 render_deck, which writes nothing} \
  [list [nz_find $NK1ROW {*negative noise timestep*}] \
        [lindex [s_ans ase::needs_eval ngspice tran stimuli_check $NK1ROW [nz_facts] {} {}] 0] \
        [string match {RAISED:*nothing was rendered*} $NK1RD]] \
  {{{1 fatal}} fatal 1}

check {NK2 a noise timestep of 0 is refused only where it silences an amplitude --\
 an RTS-only entry is the legal idiom} \
  [list [nz_find [nz_row {{src vdd func trnoise na 1m ts 0}}] {*timestep of 0*}] \
        [nz_count [nz_row {{src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}]]] \
  {{{1 fatal}} 0}

set NK3 {}
foreach a {0 2 2.5 -1 1} {
  lappend NK3 [llength [nz_find [nz_row [list [list src vdd func trnoise ts 1u namp 1m nalpha $a]]] {*1/f exponent*}]]
}
check {NK3 a 1/f exponent outside 0 < alpha < 2 is refused while the 1/f amplitude\
 is live, and not when it is 0} \
  [list $NK3 [nz_find [nz_row {{src vdd func trnoise na 1m ts 1u nalpha 2}}] {*1/f exponent*}]] \
  {{1 1 1 1 0} {}}

check {NK4 an alter onto a source already carrying a waveform is refused, onto a DC\
 source it is clean} \
  [list [nz_find [nz_row {{src vsig func trnoise na 1m ts 10u}}] {*already carries a sin waveform*}] \
        [nz_count [nz_row {{src vdd func trnoise na 1m ts 10u}}]]] \
  {{{1 fatal}} 0}

check {NK5 a random source is refused on a current source, and is clean on a voltage\
 source and injected into a net} \
  [list [nz_find [nz_row {{src iref func trrandom dist 2 ts 100u td 1n param1 1m}}] {*current source*}] \
        [nz_count [nz_row {{src vdd func trrandom dist 2 ts 100u td 1n param1 1m}}]] \
        [nz_count [nz_row {{net out func trrandom dist 2 ts 100u td 1n param1 1m}}]]] \
  {{{1 fatal}} 0 0}

set NK6NL "* sub\nvx a 0 dc 1\nra a 0 1k\n.subckt sub p q\nv9 p q dc 1\n.ends\nx1 a 0 sub\n.end\n"
check {NK6 a source the netlist text does not show, or shows only inside a\
 subcircuit, is a caution and never a refusal} \
  [list [nz_find [nz_row {{src vnope func trnoise na 1m ts 10u}}] {*not in the netlist text*}] \
        [nz_find [nz_row {{src v9 func trnoise na 1m ts 10u}}] {*inside a subcircuit*} [nz_facts $NK6NL]]] \
  {{{1 caution}} {{1 caution}}}

check {NK7 a device that is not an independent source cannot carry noise} \
  [nz_find [nz_row {{src r1 func trnoise na 1m ts 10u}}] {*not a voltage or current source*}] \
  {{1 fatal}}

check {NK8 a net is refused when it is ground or provably absent, cautioned when an\
 included file could supply it, and clean when present} \
  [list [nz_find [nz_row {{net 0 func trnoise na 1m ts 10u}}] {*goes into ground*}] \
        [nz_find [nz_row {{net GND func trnoise na 1m ts 10u}}] {*goes into ground*}] \
        [nz_find [nz_row {{net nosuch func trnoise na 1m ts 10u}}] {*no net 'nosuch'*}] \
        [nz_find [nz_row {{net nosuch func trnoise na 1m ts 10u}}] {*no net 'nosuch'*} {} \
           [dict create includes {{file /x/stim.inc}}]] \
        [nz_count [nz_row {{net out func trnoise na 1m ts 10u}}]]] \
  {{{1 fatal}} {{1 fatal}} {{1 fatal}} {{1 caution}} 0}

set NK9F [dict replace [nz_facts] evtinv {known 1 nodes {out 1}}]
set NK9U [dict replace [nz_facts] evtinv {known 0}]
check {NK9 a net a MEASURED event inventory names is refused; an unmeasured one is not} \
  [list [nz_find [nz_row {{net out func trnoise na 1m ts 10u}}] {*digital node*} $NK9F] \
        [nz_find [nz_row {{net out func trnoise na 1m ts 10u}}] {*digital node*} $NK9U]] \
  {{{1 fatal}} {}}

set NK10 {}
foreach d {0 5 {} 2.5} {
  lappend NK10 [llength [nz_find [nz_row [list [list src vdd func trrandom dist $d ts 1u td 1n param1 1m]]] {*distribution from 1 to 4*}]]
}
check {NK10 a random source needs a distribution of 1 to 4, a hold time above 0 and\
 a value for its first parameter} \
  [list $NK10 \
        [nz_find [nz_row {{src vdd func trrandom dist 2 ts 0 td 1n param1 1m}}] {*hold time above 0*}] \
        [nz_find [nz_row {{src vdd func trrandom dist 2 ts 1u td 1n}}] {*needs a value for Amplitude*}]] \
  {{1 1 1 1} {{1 fatal}} {{1 fatal}}}

check {NK11 a value the simulator's own SI alphabet cannot read is refused} \
  [nz_find [nz_row {{src vdd func trnoise na 1m ts 1xyz}}] {*cannot read '1xyz'*}] \
  {{1 fatal}}

check {NK12 an RTS amplitude with a mean low or high time of 0 is refused} \
  [list [nz_find [nz_row {{src vrts func trnoise rtsam 5m rtscapt 0 rtsemt 30u}}] {*mean low time of 0*}] \
        [nz_find [nz_row {{src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 0}}] {*mean high time of 0*}]] \
  {{{1 fatal}} {{1 fatal}}}

check {NK13 a random source with no delay warns that the OP fallback starts the\
 transient from a draw, unless it has a delay or the fallback is switched off} \
  [list [nz_find [nz_row {{src vdd func trrandom dist 2 ts 100u param1 1m}}] {*transient fallback*}] \
        [nz_find [nz_row {{src vdd func trrandom dist 2 ts 100u td 1n param1 1m}}] {*transient fallback*}] \
        [nz_find [nz_row {{src vdd func trrandom dist 2 ts 100u param1 1m}}] {*transient fallback*} {} \
           [dict create opstrategy {tranop 0}]]] \
  {{{1 caution}} {} {}}

check {NK14 an entry with every amplitude 0, a timestep above 1/100 of the stop time\
 and a large 1/f record are cautioned, and a huge 1/f record is refused} \
  [list [nz_find [nz_row {{src vdd func trnoise ts 10u}}] {*adds no noise*}] \
        [nz_find [nz_row {{src vdd func trnoise na 1m ts 100u}}] {*1/100 of the stop time*}] \
        [nz_find [nz_row {{src vdd func trnoise ts 100p namp 1m nalpha 1}}] {*allocates about*}] \
        [nz_find [nz_row {{src vdd func trnoise ts 1f namp 1m nalpha 1}}] {*allocates about*}]] \
  {{{1 caution}} {{1 caution}} {{1 caution}} {{1 fatal}}}

## ⚠ ALL OF THEM, NOT THE FIRST, AND THE PRECONDITION PICKS THE WORST. The CAUTION
## (entry 2, a random source with no delay) is reported BEFORE the FATAL (entry
## 3), so a precondition that took the first finding would say caution here.
set NK15ROW [nz_row {{src vdd func trnoise na 1m ts 10u} {src vdd func trrandom dist 2 ts 100u param1 1m} \
                     {src vsig func trnoise na 1m ts -1u}}]
set NK15V [s_ans ase::stimuli_verdicts ngspice $NK15ROW [nz_facts] {}]
set NK15E {}
foreach f $NK15V { lappend NK15E [lindex $f 0] }
check {NK15 every entry's findings are reported, and the analysis precheck carries\
 the worst of them} \
  [list [lsort -unique $NK15E] \
        [ase::precheck_worst [s_ans ase::analysis_precheck ngspice [nz_state [list $NK15ROW]] [nz_facts]]]] \
  {{2 3} fatal}

check {NK16 an entry with no target, two targets or an unknown kind is refused} \
  [list [nz_find [nz_row {{func trnoise na 1m ts 10u}}] {*names no source and no net*}] \
        [nz_find [nz_row {{src vdd net out func trnoise na 1m ts 10u}}] {*names both*}] \
        [nz_find [nz_row {{src vdd func pinknoise na 1m}}] {*no noise kind*}]] \
  {{{1 fatal}} {{1 fatal}} {{1 fatal}}}

set NK17NL "* taken\nv1 out 0 dc 1\nr1 out 0 1k\niase_noise_1_1 0 out dc 0\n.end\n"
check {NK17 a netlist already using ASE-L's carrier names refuses an injected entry} \
  [nz_find [nz_row {{net out func trnoise na 1m ts 10u}}] {*a name ASE-L keeps*} [nz_facts $NK17NL]] \
  {{1 fatal}}

check {NK18 a name that would split the generated command is refused} \
  [nz_find [nz_row [list [list src {v dd} func trnoise na 1m ts 10u]]] {*splits it*}] \
  {{1 fatal}}

check {NK19 a table or an entry nothing can read is refused rather than dropped} \
  [list [nz_find [nz_row "\{unbalanced"] {*cannot be read*}] \
        [nz_find [nz_row {{src vdd func {}}}] {*no noise kind*}] \
        [nz_find [nz_row {a}] {*cannot be read*}]] \
  {{{0 fatal}} {{1 fatal}} {{1 fatal}}}

check {NK20 a noise timestep that makes the run enormous is cautioned once for the\
 row} \
  [nz_find [nz_row {{net out func trrandom dist 2 ts 1f td 1n param1 1m}}] {*gigabytes*}] \
  {{0 caution}}

## ⚠ AND render_deck's OWN TIER SEES THE MEASURED INVENTORY. The gate donates it;
## `render_deck` did not, and it is the tier a circuit measured for the FIRST time
## by `ase::run_deck` reaches. The inventory is seeded by hand under the probe's
## own key, so no simulator runs; the unmeasured render is the control.
set NK21NL "* dig\nvin in 0 pulse(0 1 1n 1n 1n 10n 20n)\naconv \[in\] \[dig\] adcmod\nainv dig dout inv1\n.model adcmod adc_bridge(in_low=0.3 in_high=0.7)\n.model inv1 d_inverter\n.end\n"
set NK21ST [nz_state [list [nz_row {{net dig func trnoise na 1m ts 10p}} step 1n stop 30n]]]
ase::event_inv_clear
set NK21A [s_ans nz_deck $NK21ST $NK21NL]
set NK21P [s_ans ase::event_probe ngspice $NK21ST $NK21NL]
set NK21SEEDED 0
if {![s_broken $NK21P] && $NK21P ne {}} {
  dict set ::ase::event_inv [ase::event_inv_key $NK21P] {known 1 nodes {dig 1 dout 1}}
  set NK21SEEDED 1
}
set NK21B [s_ans nz_deck $NK21ST $NK21NL]
ase::event_inv_clear
check {NK21 render_deck refuses noise on a node the event inventory measured, and\
 renders the same bench while nothing is measured} \
  [list [expr {![s_broken $NK21A] && [string first {alter iase_noise_1_1} $NK21A] >= 0}] \
        $NK21SEEDED [string match {RAISED:*nothing was rendered*} $NK21B]] \
  {1 1 1}

# ===========================================================================
# NX -- THE DERIVED READOUTS
# ===========================================================================
proc nx_g {v} { if {[string is double -strict $v]} { return [format %.6g $v] } ; return $v }
set NX1ST [nz_state [list [nz_row {{src vdd func trnoise na 1m ts 1u}} stop 1m]]]
set NX1R [s_ans ase::stimuli_readout ngspice $NX1ST [lindex [dict get $NX1ST analyses] 0] 1]
check {NX1 white-noise density is NA*sqrt(2*TS), flat to 1/(2*TS), measured in the\
 source's own quantity} \
  [list [nx_g [s_dget $NX1R density]] [nx_g [s_dget $NX1R flat_to]] \
        [s_dget $NX1R quantity] [s_dget $NX1R estimate] \
        [nx_g [s_ans ase::noise_density 1e-3 1e-6]] [s_ans ase::noise_density 1e-3 0]] \
  {1.41421e-06 500000 V 1 1.41421e-06 {}}

set NX2ROWA [nz_row {{src vdd func trnoise na 1m ts 100n}} stop 1m]
set NX2ROWB [nz_row {{src vdd func trnoise na 1m ts 10u}} stop 1m]
set NX2ROWC {type tran enabled 1 step 1u stop 1m}
## ⚠ AND THE ADAPTER'S SALVAGE HOOK UNDERNEATH IT STAYS THE CARD'S (the fourth
## term). Until debt M22 the reason was that the hook alone decided whether a run
## was checkpointed, and a checkpointed noisy transient was unmeasured. Since M22
## the PLANNER raises the hook's answer by the noise itself (section NP), and the
## hook must stay the card's for three other readers: it is this estimate's
## BASE, §7g's `points_max` input, and what lets NK20's noise-only caution fire.
## Task 1's sabotage S44 (the hook made noise-aware) still reds this term.
check {NX2 the point estimate is max(stop/step, 5*stop/TS), and the salvage\
 estimator underneath it is left alone} \
  [list [s_ans ase::stimuli_points ngspice {} $NX2ROWA] \
        [s_ans ase::stimuli_points ngspice {} $NX2ROWB] \
        [s_ans ase::stimuli_points ngspice {} $NX2ROWC] \
        [s_ans ase::analysis_point_estimate ngspice tran $NX2ROWA {}] \
        [s_ans ase::noise_points 1000 1e-3 1e-7 5] \
        [s_ans ase::noise_points {} 1e-3 0 5]] \
  {50000 1000 1000 1000 50000 {}}

set NX3ST [nz_state [list $NX2ROWA]]
check {NX3 the file size is points x vectors x 8 bytes, and nothing is guessed when\
 the caller gives no vector count} \
  [list [s_dget [s_ans ase::stimuli_readout ngspice $NX3ST $NX2ROWA 1 4] bytes] \
        [s_dget [s_ans ase::stimuli_readout ngspice $NX3ST $NX2ROWA 1] bytes] \
        [s_ans ase::noise_bytes 50000 4 8]] \
  {1600000 {} 1600000}

set NX4ROW [nz_row {{src vdd func trnoise ts 100n namp 1m nalpha 1} {src vdd func trnoise na 1m ts 100n}} stop 1m]
check {NX4 a 1/f entry reports the bytes its record takes before the first time\
 point, and a white-only entry reports none} \
  [list [s_dget [s_ans ase::stimuli_readout ngspice {} $NX4ROW 1] flicker_bytes] \
        [s_dget [s_ans ase::stimuli_readout ngspice {} $NX4ROW 2] flicker_bytes]] \
  {400400 {}}

set NX5ROW [nz_row {{src vdd func trnoise na 1m ts 1u} {src iref func trnoise na 1m ts 1u} \
                    {net out func trrandom dist 2 ts 1u td 1n param1 1m}}]
check {NX5 volts on a voltage source, amperes on a current source and on anything\
 injected; an entry number out of range answers nothing} \
  [list [s_dget [s_ans ase::stimuli_readout ngspice {} $NX5ROW 1] quantity] \
        [s_dget [s_ans ase::stimuli_readout ngspice {} $NX5ROW 2] quantity] \
        [s_dget [s_ans ase::stimuli_readout ngspice {} $NX5ROW 3] quantity] \
        [s_ans ase::stimuli_readout ngspice {} $NX5ROW 4] \
        [s_ans ase::stimuli_readout ngspice {} $NX5ROW 0]] \
  {V A A {} {}}

# ===========================================================================
# NP -- THE CHECKPOINT PLAN COUNTS THE NOISE (debt M22)
# ===========================================================================
## ⚠ A NOISY TRANSIENT IS FAR LONGER THAN ITS CARD, AND THE CARD USED TO DECIDE.
## `tran 1u 2m` is 2000 points by its card -- a fiftieth of `ase::ckpt_floor` --
## and `TS = 20n` makes it 443,808 points on 45.2 and 500,008 on the fork
## (measured on section EC's bench). Planned from the card alone it was never
## checkpointed, so a Stop threw the whole run away where ⚖ R1 ruled ALWAYS
## SALVAGE. `evidence/m22-checkpointed-noise.md` measured the loop safe to arm on
## a noisy transient on both binaries; section EC runs it through this renderer.
set NPROW [nz_row {{src vdd func trnoise na 1m ts 20n}} stop 2m]
set NPST [nz_state [list $NPROW]]
set NPPLAN {n 4 step 100000 points 500000 vector time}
set NPCARD [s_ans ase::analysis_point_estimate ngspice tran $NPROW $NPST]
check {NP1 a noisy transient whose card is under the checkpoint floor and whose\
 noise is far over it is checkpointed, on the noise's estimate and interval --\
 the same count the Tran form shows} \
  [list $NPCARD [expr {[string is double -strict $NPCARD] && $NPCARD < [ase::ckpt_floor]}] \
        [s_ans ase::ckpt_plan ngspice $NPROW $NPST] \
        [expr {[s_dget [s_ans ase::ckpt_plan ngspice $NPROW $NPST] points] eq \
               [s_ans ase::stimuli_points ngspice $NPST $NPROW]}] \
        [s_ans ase::ckpt_rows ngspice $NPST]] \
  [list 2000 1 $NPPLAN 1 [list [list 30 0 tran $NPPLAN]]]

## ⚠ AND NOTHING ELSE MOVES. The raise hands the card's answer back untouched for
## a row with no table, an empty one, only switched-off entries, or noise whose
## interval asks for FEWER points than the card -- under the floor and over it.
## The switched-off entry is `TS = 1n`, which would ask 10 million points under
## the floor and 40 million over it if it were counted.
proc np_plan {row} { return [s_ans ase::ckpt_plan ngspice $row [nz_state [list $row]]] }
set NP2UNDER {type tran enabled 1 step 1u stop 2m}
set NP2OVER  {type tran enabled 1 step 10n stop 8m}
set NP2OFF   {{src vdd func trnoise na 1m ts 1n enabled 0}}
set NP2PLAN  {n 4 step 160000 points 800000 vector time}
check {NP2 no table, an empty table and only switched-off entries plan exactly what\
 the card alone plans, under the floor and over it -- and so does noise that asks\
 for fewer points than the card} \
  [list [np_plan $NP2UNDER] [np_plan [dict replace $NP2UNDER noise {}]] \
        [np_plan [dict replace $NP2UNDER noise $NP2OFF]] \
        [np_plan $NP2OVER] [np_plan [dict replace $NP2OVER noise {}]] \
        [np_plan [dict replace $NP2OVER noise $NP2OFF]] \
        [np_plan [dict replace $NP2OVER noise {{src vdd func trnoise na 1m ts 10u}}]]] \
  [list {} {} {} $NP2PLAN $NP2PLAN $NP2PLAN $NP2PLAN]

set NP3D0 [s_ans nz_deck [nz_state [list $NP2OVER]]]
set NP3D1 [s_ans nz_deck [nz_state [list [dict replace $NP2OVER noise $NP2OFF]]]]
check {NP3 a checkpointed transient carrying only a switched-off noise entry renders\
 byte-identically to the same row with no table, loop and interval included} \
  [list [expr {$NP3D0 eq $NP3D1 && ![s_broken $NP3D0]}] \
        [expr {[string first {let ckstep = 160000} $NP3D0] >= 0}]] \
  {1 1}

## ⚠ THE NOISY DECK's SHAPE AROUND THE LOOP. The `alter` is above the arming (the
## setup lines' place, issue 1466), the loop is issue 1433's between the card and
## `delete all`, and the restore is the `post` leg's -- below the guard, ONCE,
## outside the loop. A restore inside the loop would silence the noise at the
## first checkpoint; section EC's third row is that measurement's twin.
proc np_rising {ps} {
  set prev -1
  foreach p $ps { if {$p <= $prev} { return 0 } ; set prev $p }
  return 1
}
set NP4L [nz_lines $NPST]
set NP4CARD [nz_pos $NP4L {tran 1u 2m}]
set NP4DEL [nz_pos $NP4L {delete all} $NP4CARD]
set NP4REST {alter vdd trnoise = [ 0 0 0 0 0 0 0 ]}
set NP4P [list [nz_pos $NP4L {alter vdd trnoise = [ 1m 20n 0 0 0 0 0 ]}] \
               [nz_pos $NP4L {let ckstep = 100000}] \
               [nz_pos $NP4L {echo ASE-CKPT-ARMED tran 0 100000 500000}] \
               [nz_pos $NP4L {stop after $cktgt}] \
               $NP4CARD \
               [nz_pos $NP4L {while ckdone = 0} $NP4CARD] \
               $NP4DEL \
               [nz_pos $NP4L $NE5G $NP4CARD] \
               [nz_pos $NP4L $NP4REST] \
               [nz_pos $NP4L remzerovec $NP4DEL] \
               [nz_pos $NP4L "write [ase::backend::ngspice::raw_file $NPST]" $NP4CARD]]
set NP4LOOP {}
if {$NP4CARD >= 0 && $NP4DEL > $NP4CARD} { set NP4LOOP [lrange $NP4L $NP4CARD $NP4DEL] }
check {NP4 the noisy deck gives the noise above the arming, arms the loop on the\
 noise's interval above the card, and puts the source back once -- below the loop\
 and the guard, above remzerovec and the write} \
  [list [np_rising $NP4P] [llength [lsearch -all -exact $NP4L $NP4REST]] \
        [llength $NP4LOOP] [lsearch -all -glob $NP4LOOP {*alter *}]] \
  [list 1 1 [expr {$NP4DEL - $NP4CARD + 1}] {}]

## ⚠ NO FALLBACK CONTENT (D34-D37). The raise reads the TYPE's `stimuli`
## contract, so an `ac` row carrying the key plans nothing, and a backend whose
## `tran` keeps ngspice's `salvage` hook but declares no contract gets the card's
## plan and never ngspice's factor of 5. The first probe is non-vacuity: the stub
## really does carry the salvage hook, so its `{}` is the floor speaking.
set NP5NOISY [dict replace $NP2OVER noise {{src vdd func trnoise na 1m ts 1n}}]
check {NP5 a noise table on a type with no stimuli contract changes nothing -- an ac\
 row, or a transient under a backend that declares no contract} \
  [list [np_plan {type ac enabled 1 sweep dec points 10 start 1 stop 1meg \
                  noise {{src vdd func trnoise na 1m ts 1n}}}] \
        [nb_probe {list [expr {[s_ans ase::analysis_salvage zznz tran] ne {}}] \
                        [s_ans ase::ckpt_plan zznz $NPROW $NPST] \
                        [s_ans ase::ckpt_plan zznz $NP5NOISY [nz_state [list $NP5NOISY]]]}] \
        [s_dget [np_plan $NP5NOISY] points]] \
  [list {} [list 1 {} $NP2PLAN] 40000000]

## ⚠ AND THE VERDICT AND THE SENTENCE FOLLOW THE SAME PLAN, because both re-derive
## it from the state (`ase::ckpt_rows`). Before M22 a stopped noisy run was
## `unknown` -- no marker was ever asked for -- so nothing was said about what a
## Stop had kept. The checkpoint header is hand-written, as test_ase_core's CK23
## writes one: `ase::cap_raw_plots` reads the ASCII half only.
set NP6D [file join $scratch np6run]
file mkdir $NP6D
set NP6ST [nz_state [list $NPROW] $NP6D]
set NP6V [list [s_ans ase::run_completed ngspice $NP6ST "ASE-CKPT-DONE 100000\n"] \
               [s_ans ase::run_completed ngspice $NP6ST "ASE-CKPT-DONE 100000\nASE-RUN-COMPLETE\n"]]
set np6f [open [ase::ckpt_path $NP6ST] w]
puts -nonewline $np6f "Title: np\nDate: now\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 200000\nVariables:\n\t0\ttime\ttime\n\t1\tv(vdd)\tvoltage\nBinary:\n"
close $np6f
set NP6R [s_ans ase::ckpt_report ngspice $NP6ST "ASE-CKPT-DONE 100000\n"]
file delete -force $NP6D
check {NP6 a stopped noisy run reads as aborted rather than unknown, and the salvage\
 sentence quotes the noise's estimate} \
  [list $NP6V [llength $NP6R] \
        [string match {*kept at 200000 points of an estimated 500000,*} [lindex $NP6R 0]]] \
  {{aborted complete} 1 1}

# ===========================================================================
# NS -- WHICH KINDS A SEED REPEATS, AND WHAT THE KILL SWITCH KILLS
# ===========================================================================
check {NS1 each entry names its live kinds, which a seed repeats and which\
 notrnoise kills -- RTS killed only with a noise timestep above 0} \
  [list [s_ans ase::stimuli_kinds ngspice tran {func trnoise na 1m ts 1u}] \
        [s_ans ase::stimuli_kinds ngspice tran {func trnoise namp 1m nalpha 1 ts 1u}] \
        [s_ans ase::stimuli_kinds ngspice tran {func trnoise rtsam 5m rtscapt 18u rtsemt 30u}] \
        [s_ans ase::stimuli_kinds ngspice tran {func trnoise rtsam 5m rtscapt 18u rtsemt 30u ts 1u}] \
        [s_ans ase::stimuli_kinds ngspice tran {func trrandom dist 2 ts 1u param1 1}]] \
  [list {live white repeat rts killed white} {live flicker repeat rts killed flicker} \
        {live rts repeat rts killed {}} {live rts repeat rts killed rts} \
        {live random repeat random killed {}}]

set NS2ROW [nz_row {{src vdd func trnoise na 1m ts 10u} {net bias func trrandom dist 2 ts 100u td 1n param1 1m} \
                    {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}]
set NS2R [s_ans ase::stimuli_seed_report ngspice [nz_state [list $NS2ROW]] $NS2ROW]
check {NS2 the seed report splits by kind: white does not repeat, a random source\
 and RTS do, and there is no seed on this bench} \
  [list [s_dget $NS2R present] [s_dget $NS2R norepeat] [s_dget $NS2R repeat] \
        [s_dget $NS2R seeded] [s_dget $NS2R sentences]] \
  [list {white random rts} white {random rts} 0 \
        [list {White noise does not repeat from run to run: the simulator seeds it from its process ID, and no seed reaches it.} \
              {Random sources and RTS noise repeat only when a seed is set.}]]

## ⚠ A SENTENCE ABOUT "NOISE" IN GENERAL WOULD BE FALSE FOR HALF THE ROWS, so a
## white-only row says nothing about repeating and an RTS-only row nothing about
## the process ID.
set NS3W [nz_row {{src vdd func trnoise na 1m namp 1m nalpha 1 ts 10u}}]
set NS3R [nz_row {{src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}]
check {NS3 a white-and-1/f row gets only the does-not-repeat sentence and an RTS-only\
 row only the repeats sentence} \
  [list [s_dget [s_ans ase::stimuli_seed_report ngspice [nz_state [list $NS3W]] $NS3W] sentences] \
        [s_dget [s_ans ase::stimuli_seed_report ngspice [nz_state [list $NS3R]] $NS3R] sentences]] \
  [list [list {White noise and 1/f noise do not repeat from run to run: the simulator seeds them from its process ID, and no seed reaches them.}] \
        [list {RTS noise repeats only when a seed is set.}]]

set NS4A [nz_state [list $NS3R] {} options {{name seed value 5}}]
set NS4B [nz_state [list $NS3R] {} sweep {enabled 1 seed 7 axes {{kind temp values {27 85}}}}]
check {NS4 an options seed or a seeded campaign counts as seeded, and the sentence\
 then says the kind repeats exactly} \
  [list [s_dget [s_ans ase::stimuli_seed_report ngspice $NS4A $NS3R] seeded] \
        [s_dget [s_ans ase::stimuli_seed_report ngspice $NS4B $NS3R] seeded] \
        [s_dget [s_ans ase::stimuli_seed_report ngspice $NS4A $NS3R] sentences]] \
  [list 1 1 [list {RTS noise repeats exactly under the seed.}]]

set NS5ROW [nz_row {{src vdd func trnoise na 1m ts 10u} {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u} \
                    {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u ts 10u} \
                    {net bias func trrandom dist 2 ts 100u td 1n param1 1m}}]
set NS5K [s_ans ase::stimuli_kill_report ngspice [nz_state [list $NS5ROW] {} options {{name notrnoise}}] $NS5ROW]
check {NS5 the kill report names the catalogue row, sees it armed, and splits the\
 entries into killed and surviving} \
  [list [s_dget $NS5K option] [s_dget $NS5K armed] [s_dget $NS5K killed] [s_dget $NS5K survive] \
        [s_dget [s_ans ase::stimuli_kill_report ngspice [nz_state [list $NS5ROW]] $NS5ROW] armed] \
        [expr {[s_ans ase::opt_phase ngspice notrnoise] ne {}}]] \
  {notrnoise 1 {{1 white} {3 rts}} {{2 rts} {4 random}} 0 1}

# ===========================================================================
# NC -- THE CORPUS AND THE ROUND TRIP
# ===========================================================================
source [file join $repo tests headless state_roundtrip.tcl]
set NC1 [ase_state_roundtrip $repo]
puts "  NC1 tracked [s_dget $NC1 tracked] bad {[s_dget $NC1 bad]} control_disagrees\
 [s_dget $NC1 control_disagrees] control_agrees [s_dget $NC1 control_agrees]"
check {NC1 the committed .state files round-trip byte-identically, both controls\
 disagreeing and agreeing} \
  [list [expr {[s_dget $NC1 tracked] >= 104}] [s_dget $NC1 bad] \
        [s_dget $NC1 control_disagrees] [s_dget $NC1 control_agrees]] \
  {1 {} 1 1}

set NC2P [file join $scratch nz_roundtrip.state]
set NC2ST [nz_state [list $NS2ROW {type op enabled 1}]]
ase::state_save $NC2P $NC2ST
set nch [open $NC2P rb] ; set NC2T1 [read $nch] ; close $nch
set NC2L [ase::state_load $NC2P]
ase::state_save $NC2P $NC2L
set nch [open $NC2P rb] ; set NC2T2 [read $nch] ; close $nch
check {NC2 a bench carrying a noise table saves, loads and saves again to the same\
 bytes, with the table intact} \
  [list [expr {$NC2T1 eq $NC2T2}] \
        [llength [ase::stimuli_rows ngspice [lindex [dict get $NC2L analyses] 0]]]] \
  {1 3}

# ===========================================================================
# EE -- THE END-TO-END RUN, ON BOTH BINARIES
# ===========================================================================
## ⚠ TWO HALVES OF A FEATURE TESTED IN DIFFERENT PLACES NEVER MEET (issue 1449),
## so this section takes the deck ASE-L renders, runs it, and reads the results
## back with a SECOND ngspice process (`load` + `stddev`/`maximum`/`mean`), which
## knows nothing about ASE-L. Binaries from `$env(ASE_NZ_NGSPICE)`
## (colon-separated) or the two the crew brief names; a missing one SKIPS with
## its path printed.
proc ee_binaries {} {
  if {[info exists ::env(ASE_NZ_NGSPICE)] && $::env(ASE_NZ_NGSPICE) ne {}} {
    set out {} ; set i 0
    foreach b [split $::env(ASE_NZ_NGSPICE) :] { incr i ; lappend out [list env$i $b] }
    return $out
  }
  return [list [list apt /usr/bin/ngspice] \
               [list fork /home/analog/dev/ngspice/build-ver_50/src/ngspice]]
}
## ⚠ ZERO WITHIN 1e-9, NOT `eq 0`, AND A MEASUREMENT SAYS WHY: `stddev()` of a
## constant 1.8 V trace prints `6.67741E-15` on both binaries -- floating-point
## residue, not noise. The noise this section looks for is 1e-3 and up, six
## orders above the tolerance, so the tolerance cannot hide it.
proc ee_zero {v} { return [expr {[string is double -strict $v] && abs($v) < 1e-9}] }
proc ee_run {bin deck} {
  global scratch
  set rc [catch {exec env HOME=$scratch $bin -b $deck 2>@1} out]
  return [list $rc $out]
}
## Reads the two transient plots back. Returns a dict, or {} when nothing was read.
proc ee_read {bin raw} {
  global scratch
  set rd [file join $scratch ee_reader.cir]
  set f [open $rd w]
  puts $f "* reader\nrdummy a 0 1\n.control\nload $raw"
  foreach {tag plot} {A tran1 B tran2} {
    puts $f "setplot $plot"
    puts $f "let s1 = stddev(v(vdd))\nlet s2 = stddev(v(bias))\nlet m3 = maximum(v(rts))"
    puts $f "let n0 = length(time)\nlet b100 = v(bias)\[100\]\nlet r3 = mean(v(rts))\nlet w100 = v(vdd)\[100\]"
    puts $f "echo NZ $tag \$&s1 \$&s2 \$&m3 \$&n0 \$&b100 \$&r3 \$&w100"
  }
  puts $f ".endc\n.end"
  close $f
  catch {exec env HOME=$scratch $bin -b $rd 2>@1} out
  set r {}
  foreach l [split $out "\n"] {
    if {[regexp {^NZ ([AB]) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)} $l -> t s1 s2 m3 n0 b100 r3 w100]} {
      dict set r $t [dict create s1 $s1 s2 $s2 m3 $m3 n0 $n0 b100 $b100 r3 $r3 w100 $w100]
    }
  }
  return $r
}
set EERUN [file join $scratch eerun]
file mkdir $EERUN
set EEROWA [dict replace [nz_row {{src vdd func trnoise na 1m ts 10u} \
                                  {net bias func trrandom dist 2 ts 100u td 1n param1 1m} \
                                  {src vrts func trnoise rtsam 5m rtscapt 18u rtsemt 30u}}] step 10u]
set EEROWB {type tran enabled 1 step 10u stop 2m}
set EEST [nz_state [list $EEROWA $EEROWB] $EERUN options {{name seed value 5}}]
set EESTK [dict replace $EEST options {{name seed value 5} {name notrnoise}}]
set EEDECK [file join $EERUN nzbench_ase.spice]
set EEDECKK [file join $EERUN nzbench_kill.spice]
set EERAW [ase::backend::ngspice::raw_file $EEST]
set EEMAP [ase::plotmap_path $EEST]
set eef [open $EEDECK w] ; puts -nonewline $eef [nz_deck $EEST] ; close $eef
set eef [open $EEDECKK w] ; puts -nonewline $eef [nz_deck $EESTK] ; close $eef
set EEEST [s_ans ase::stimuli_points ngspice $EEST $EEROWA]
set EESEEN {}
foreach eepair [ee_binaries] {
  lassign $eepair eetag eebin
  if {$eebin eq {} || ![file executable $eebin]} {
    puts "SKIPPED: EE $eetag end-to-end leg (no executable at '$eebin')"
    continue
  }
  if {[lsearch -exact $EESEEN [file normalize $eebin]] >= 0} { continue }
  lappend EESEEN [file normalize $eebin]
  set EEV {}
  foreach eei {1 2} {
    file delete -force $EERAW $EEMAP
    lassign [ee_run $eebin $EEDECK] eerc eeout
    set eemap {}
    if {[file isfile $EEMAP]} { set mf [open $EEMAP r] ; set eemap [string trim [read $mf]] ; close $mf }
    lappend EEV [list $eerc $eemap [ee_read $eebin $EERAW] $eeout]
  }
  file delete -force $EERAW $EEMAP
  lassign [ee_run $eebin $EEDECKK] eerck eeoutk
  set EEK [ee_read $eebin $EERAW]
  lassign [lindex $EEV 0] rc1 map1 r1 out1
  lassign [lindex $EEV 1] rc2 map2 r2 out2
  check "EE1/$eetag the deck ASE-L renders runs, records both transients and reads\
 back" \
    [list $rc1 $map1 [lsort [dict keys $r1]]] \
    [list 0 "PLOT tran 0 |Transient Analysis|\nPLOT tran 1 |Transient Analysis|" {A B}]
  if {$rc1} { puts "  EE1/$eetag output: $out1" }
  set A [s_dget $r1 A] ; set B [s_dget $r1 B]
  check "EE2/$eetag the noisy transient carries white noise on the altered supply, a\
 random current on the injected net and a telegraph on the RTS source" \
    [list [expr {[string is double -strict [s_dget $A s1]] && [s_dget $A s1] > 0}] \
          [expr {[string is double -strict [s_dget $A s2]] && [s_dget $A s2] > 0}] \
          [expr {[string is double -strict [s_dget $A m3]] && [s_dget $A m3] > 0.004}]] \
    {1 1 1}
  ## ⚠ THE RESTORE, END TO END: the second transient follows the noisy one in the
  ## same process, and without the `post` leg it is noisy too (measured).
  check "EE3/$eetag the transient after it is clean -- every noisy source was put\
 back -- and has its own card's points, not the noise timestep's" \
    [list [ee_zero [s_dget $B s1]] [ee_zero [s_dget $B s2]] [ee_zero [s_dget $B m3]] \
          [expr {[string is double -strict [s_dget $B n0]] && [string is double -strict [s_dget $A n0]] \
                 && [s_dget $B n0] * 3 < [s_dget $A n0]}]] \
    {1 1 1 1}
  check "EE4/$eetag the noisy transient's point count is within a factor of two of\
 the estimate ($EEEST) -- an estimate, never a golden" \
    [expr {[string is double -strict [s_dget $A n0]] && [string is double -strict $EEEST] \
           && [s_dget $A n0] >= $EEEST / 2.0 && [s_dget $A n0] <= $EEEST * 2.0}] 1
  ## ⚠ THE SEED SENTENCE's LOGIC, CHECKED AGAINST THE SIMULATOR. The report says
  ## white does not repeat and random/RTS do; two runs under `.options seed=5`
  ## must agree with it kind by kind.
  set A2 [s_dget $r2 A]
  set NSR [s_ans ase::stimuli_seed_report ngspice $EEST $EEROWA]
  check "EE5/$eetag under the bench's seed the random source and the RTS source repeat\
 run to run and the white noise does not -- as the seed report says" \
    [list $rc2 [s_dget $NSR norepeat] [s_dget $NSR repeat] [s_dget $NSR seeded] \
          [expr {[s_dget $A b100] eq [s_dget $A2 b100] && [s_dget $A b100] ne {MISSING}}] \
          [expr {[s_dget $A r3] eq [s_dget $A2 r3] && [s_dget $A r3] ne {MISSING}}] \
          [expr {[s_dget $A w100] ne [s_dget $A2 w100]}]] \
    {0 white {random rts} 1 1 1 1}
  set AK [s_dget $EEK A]
  set KR [s_ans ase::stimuli_kill_report ngspice $EESTK $EEROWA]
  check "EE6/$eetag with notrnoise the white noise is gone while the random source and\
 the zero-timestep RTS source run on -- as the kill report says" \
    [list $eerck [s_dget $KR killed] [s_dget $KR survive] \
          [ee_zero [s_dget $AK s1]] \
          [expr {[string is double -strict [s_dget $AK s2]] && [s_dget $AK s2] > 0}] \
          [expr {[string is double -strict [s_dget $AK m3]] && [s_dget $AK m3] > 0.004}]] \
    {0 {{1 white}} {{2 random} {3 rts}} 1 1 1}
  if {$eerck} { puts "  EE6/$eetag output: $eeoutk" }
}
if {![llength $EESEEN]} {
  puts "SKIPPED: EE -- no ngspice binary found on this machine"
}

# ===========================================================================
# EC -- A CHECKPOINTED NOISY TRANSIENT, END TO END, ON BOTH BINARIES (debt M22)
# ===========================================================================
## ⚠ THE LOOP IS ISSUE 1433's AND IT IS UNCHANGED; WHAT IS NEW IS THAT IT IS ARMED
## HERE AT ALL. `tran 1u 2m` is 2000 points by its card and `TS = 20n` noise on
## its only source makes it ~500,000, so the deck ASE-L renders now carries the
## loop. The run is rendered, run on each binary, and read back by a SECOND
## ngspice process that knows nothing about ASE-L. MEASURED while writing this
## section, same bench: rc 0 on both, 4 checkpoints and 434,610 points on 45.2,
## 5 and 501,008 on the fork (443,808 and 500,008 unchecked), under a second each.
##
## ⚠ NOISE IS JUDGED TIME-WEIGHTED, NEVER BY `stddev` OVER RAWFILE POINTS.
## `evidence/m22-checkpointed-noise.md` reading 3: each `resume` clusters small
## steps, and a per-point statistic moved 5 % under the loop while the generated
## samples did not move at all. The statistic here is `integ(v*v)` over time; for
## linearly interpolated independent samples of sigma NA its RMS is NA*sqrt(2/3),
## 0.816 NA -- measured 0.825 / 0.823 checked and 0.840 / 0.833 unchecked
## (45.2 / fork). The window 0.7-0.95 holds both and not a silenced source.
## An absence is `maximum(abs(v))` under `ee_zero`'s tolerance -- not a statistic.
proc ec_netlist {} { return "* ecbench\nvn nn 0 dc 0\nrn nn 0 1k\n.end\n" }
## Per plot: points, last time, the smallest step between neighbours (time
## rising at every point iff > 0), the time-weighted RMS and the peak of v(nn).
proc ec_read {bin raw plots} {
  global scratch
  set rd [file join $scratch ec_reader.cir]
  set f [open $rd w]
  puts $f "* reader\nrdummy a 0 1\n.control\nload $raw"
  foreach p $plots {
    puts $f "setplot $p"
    puts $f "let n0 = length(time)\nlet n1 = n0 - 1\nlet n2 = n0 - 2\nlet tl = maximum(time)"
    puts $f "let ta = time\[1,\$&n1\]\nlet tb = time\[0,\$&n2\]\nlet dmin = minimum(ta - tb)"
    puts $f "let e = integ(v(nn)*v(nn))\nlet rms = sqrt(e\[\$&n1\]/tl)\nlet mx = maximum(abs(v(nn)))"
    puts $f "echo EC $p \$&n0 \$&tl \$&dmin \$&rms \$&mx"
  }
  puts $f ".endc\n.end"
  close $f
  catch {exec env HOME=$scratch $bin -b $rd 2>@1} out
  set r {}
  foreach l [split $out "\n"] {
    if {[regexp {^EC (\S+) (\S+) (\S+) (\S+) (\S+) (\S+)} $l -> p n0 tl dmin rms mx]} {
      dict set r $p [dict create n0 $n0 tl $tl dmin $dmin rms $rms mx $mx]
    }
  }
  return $r
}
proc ec_num {d k} {
  set v [s_dget $d $k]
  if {[string is double -strict $v]} { return $v }
  return {}
}
set ECRUN [file join $scratch ecrun]
file mkdir $ECRUN
set ECROWA {type tran enabled 1 step 1u stop 2m noise {{src vn func trnoise na 1 ts 20n}}}
set ECROWB {type tran enabled 1 step 10u stop 2m}
set ECST [nz_state [list $ECROWA $ECROWB] $ECRUN]
set ECDECK [file join $ECRUN nzbench_ec.spice]
set ECRAW [ase::backend::ngspice::raw_file $ECST]
set ECMAP [ase::plotmap_path $ECST]
set ECCK [ase::ckpt_path $ECST]
set ECCKT [ase::ckpt_tmp_path $ECST]
set ECPLAN [s_ans ase::ckpt_plan ngspice $ECROWA $ECST]
set ecf [open $ECDECK w] ; puts -nonewline $ecf [s_ans nz_deck $ECST [ec_netlist]] ; close $ecf
set ECSEEN {}
foreach ecpair [ee_binaries] {
  lassign $ecpair ectag ecbin
  if {$ecbin eq {} || ![file executable $ecbin]} {
    puts "SKIPPED: EC $ectag end-to-end leg (no executable at '$ecbin')"
    continue
  }
  if {[lsearch -exact $ECSEEN [file normalize $ecbin]] >= 0} { continue }
  lappend ECSEEN [file normalize $ecbin]
  file delete -force $ECRAW $ECMAP $ECCK $ECCKT
  lassign [ee_run $ecbin $ECDECK] ecrc ecout
  set ecn 0 ; set eccomplete 0
  foreach l [split $ecout "\n"] {
    if {[string match {ASE-CKPT-DONE *} [string trim $l]]} { incr ecn }
    if {[string trim $l] eq [ase::ckpt_marker complete]} { set eccomplete 1 }
  }
  set ecres [ec_read $ecbin $ECRAW {tran1 tran2}]
  set ecA [s_dget $ecres tran1] ; set ecB [s_dget $ecres tran2]
  set ecC [s_dget [ec_read $ecbin $ECCK tran1] tran1]
  set eccap [ase::cap_raw_plots $ECCK]
  puts "  EC/$ectag rc $ecrc checkpoints $ecn plan {$ECPLAN} results {$ecA}\
 next {$ecB} checkpoint {$ecC}"
  check "EC1/$ectag the noisy transient's deck arms ASE-L's checkpoint loop on the\
 noise's estimate, and the run checkpoints and finishes -- rc 0, three or more\
 checkpoints, the completion marker, and ASE-L's own verdict says complete" \
    [list [s_dget $ECPLAN points] $ecrc [expr {$ecn >= 3}] $eccomplete \
          [s_ans ase::run_completed ngspice $ECST $ecout]] \
    {500000 0 1 1 complete}
  if {$ecrc} { puts "  EC1/$ectag output: [string range $ecout 0 3000]" }
  set ecAn [ec_num $ecA n0] ; set ecCn [ec_num $ecC n0]
  check "EC2/$ectag the checkpoint on disk is a readable transient that stops short of\
 the end, and the results file's noisy transient reaches its stop time with time\
 rising at every point and the noise's points, not the card's" \
    [list [lindex [lindex $eccap end] 0] \
          [expr {$ecCn ne {} && $ecAn ne {} && $ecCn > 0 && $ecCn < $ecAn}] \
          [expr {[ec_num $ecC tl] ne {} && [ec_num $ecC tl] < 2e-3}] \
          [expr {[ec_num $ecA tl] ne {} && abs([ec_num $ecA tl] - 2e-3) < 1e-9}] \
          [expr {[ec_num $ecA dmin] ne {} && [ec_num $ecA dmin] > 0}] \
          [expr {$ecAn ne {} && $ecAn > 50 * 2000 && $ecAn >= 250000 && $ecAn <= 1000000}]] \
    {{Transient Analysis} 1 1 1 1 1}
  check "EC3/$ectag the noise survived the loop, judged TIME-WEIGHTED: the RMS over\
 time of the noisy source is 0.7-0.95 of its amplitude" \
    [expr {[ec_num $ecA rms] ne {} && [ec_num $ecA rms] > 0.7 && [ec_num $ecA rms] < 0.95}] 1
  check "EC4/$ectag the transient after it is clean and whole -- the source was put\
 back below the loop -- reaching its own stop time with its own card's points" \
    [list [ee_zero [s_dget $ecB mx]] \
          [expr {[ec_num $ecB tl] ne {} && abs([ec_num $ecB tl] - 2e-3) < 1e-9}] \
          [expr {[ec_num $ecB n0] ne {} && [ec_num $ecB n0] >= 200 && [ec_num $ecB n0] < 600}]] \
    {1 1 1}
}
file delete -force $ECRAW $ECMAP $ECCK $ECCKT
if {![llength $ECSEEN]} {
  puts "SKIPPED: EC -- no ngspice binary found on this machine"
}

puts "RESULT: [expr {$fail ? "$fail FAILED ($npass passed)" : "ALL PASS ($npass checks)"}]"
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
exit [expr {$fail ? 1 : 0}]
