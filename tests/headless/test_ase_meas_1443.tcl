# tests/headless/test_ase_meas_1443.tcl -- ISSUE 1443: A GUI THAT COULD NOT READ
# A NUMBER BACK. PLAN.md Stage 8a + 8c.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# `grep -c '\bmeas\b' src/ase.tcl` returned ZERO. Two of the six benchmark ADE
# tasks -- read back the phase margin, and the spread of one measurement over
# 200 Monte Carlo runs -- ended at "you are on your own". And `.four`, `fft`,
# `spec`, `psd` and `linearize` had destinations in every design and NO
# PRODUCERS ANYWHERE: nothing in ASE-L could ask for one.
#
# ============================================================================
# ⚠ THE ONE THAT MAKES A PHASE MARGIN WRONG BY 57.2958x
# ============================================================================
# MEASURED 2026-09-13 on BOTH binaries, an RC whose phase at 1 kHz is exactly
# -45 degrees, through `meas` itself:
#
#     (nothing set)           meas ac p FIND vp(out) AT=1k  ->  -7.853982e-01
#     .options units=degrees  the same line                 ->  -7.853982e-01
#     set units=degrees       the same line                 ->  -4.500000e+01
#
# The CARD does nothing, in silence. Section PH is the auto-emission AND its
# non-vacuity control -- a measurement with no phase in it must NOT emit the
# line -- and PH3 is what says the line comes from the ONE option speller
# rather than from a second literal.
#
# ⚠ AND `units` IS ONE OF THE 247 CATALOGUE ROWS. This task's brief and
# LEDGER.md's Stage 8 block both say it is not; counted live on 2026-09-13 it
# is, with `phase run`, door `control`, `values {radians degrees}` and a `help`
# that already carries the 57.2958 sentence. Receipt C145.
#
# ============================================================================
# ⚠ THE FOUR GRAMMAR TRAPS, RE-MEASURED ON BOTH BINARIES 2026-09-13
# ============================================================================
#  1. `expr=` is broken               -> on the COMMAND form it is not merely
#                                        broken, it does not exist: `Error:
#                                        measure e1 : no such function as
#                                        'expr=7.756162e+00'`
#  2. `param=` is one-shot per session -> on the COMMAND form it does not exist
#                                        either (`no such function as
#                                        'param=...'`), so the plan's `param`
#                                        KIND ships as a `let`, which cannot
#                                        hit the numparam placeholder at all
#  3. `.meas` cards are refused under `-r` -> CONFIRMED, `No .measure possible
#                                        in batch mode (-b) with -r rawfile
#                                        set!`, and a dot card ALSO runs the
#                                        whole simulation a SECOND time
#                                        (`Doing analysis at TEMP` twice)
#  4. the vector carries 7 significant digits, so redirect and parse the
#                                        printed line -> `meas … > file` really
#                                        does write (54 and 66 bytes, with
#                                        `echo > f` = 22 and `print > f` = 31
#                                        as positive controls in the SAME
#                                        deck). ⚠ BUT ITS STATED REASON IS
#                                        FALSE ON apt 45.2: `set measureprec`
#                                        and `NGSPICE_MEAS_PRECISION` are BOTH
#                                        accepted and BOTH inert there, so the
#                                        printed line is `%.6e` -- exactly the
#                                        precision `measure.c:138`'s `"%e"`
#                                        gives the vector. Receipt C146.
#
# ============================================================================
# ⚠ AND THE PRODUCERS' PLOTS MUST NOT REACH THE RESULTS FILE
# ============================================================================
# `src/save.c`'s read_dataset() maps a `Plotname:` to a sim_type by SUBSTRING:
# `"transient analysis"` at :957 and `"spectrum"` at :987. MEASURED 2026-09-13
# through this tree's own reader, on one results file holding a real transient,
# a linearized copy made to DISAGREE with it, and an fft spectrum:
#
#     xschem raw read multi.raw tran  ->  datasets=2   <- the copy joined it
#     xschem raw read multi.raw ac    ->  datasets=1 sim_type=ac
#                                          ... with no ac analysis in the deck
#
# That is issue 1430's `AC Operating Point` refusal exactly, one stage later.
# So no producer plot is written, the walk and the plotmap are untouched, and
# the RESULTS come back as measurements and as the printed harmonic table.
# Rows PP7, PP7b and DK6 hold it.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#    sections KN VD LN PH PP DK SC HK, all pure Tcl, identical on both arms
#
# ⚠ NO SIMULATOR IS STARTED HERE. Every ngspice number quoted above was
# measured beforehand on both binaries; the rows below assert what ASE-L does
# with those facts, which is pure Tcl.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_meas_1443.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_meas_1443.tcl

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
set scratch [test_scratch meas1443]

proc m_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc m_state {meas {ans {}}} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell rc lib $scratch]
  dict set st rundir $scratch
  dict set st simulator ngspice
  dict set st save_all_v 1
  if {[llength $ans]} {
    dict set st analyses $ans
  } else {
    dict set st analyses {{type ac enabled 1 sweep dec points 100 start 10 stop 1meg}
                          {type tran enabled 1 step 5u stop 10m}}
  }
  dict set st measurements $meas
  return $st
}
proc m_netlist {} {
  return "* rc\nv1 in 0 dc 0 ac 1 sin(0 1 1k)\nr1 in out 1k\nc1 out 0 159.1549431n\n.end\n"
}
proc m_deck {st} { return [ase::backend::ngspice::render_deck $st [m_netlist]] }
proc m_lines {st pat} {
  set out {}
  foreach l [split [m_deck $st] "\n"] {
    if {[regexp $pat $l]} { lappend out [string trim $l] }
  }
  return $out
}
## The deck with the rundir path taken out, so a row can quote a whole line.
proc m_scrub {t} {
  global scratch
  return [string map [list $scratch/ {}] $t]
}
proc m_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} { continue } ; lappend out $l }
  return [join $out "\n"]
}
## Index of the LAST deck line matching a pattern, or -1. ⚠ DK2 needs it: a
## per-analysis option appears TWICE, once set above the analysis and once put
## back below it, and the bound that matters is the restore.
proc m_last {deck pat} {
  set i 0 ; set last -1
  foreach l [split $deck "\n"] {
    if {[regexp $pat $l]} { set last $i }
    incr i
  }
  return $last
}

## Index of the first deck line matching a pattern, or -1.
proc m_at {deck pat} {
  set i 0
  foreach l [split $deck "\n"] {
    if {[regexp $pat $l]} { return $i }
    incr i
  }
  return -1
}

catch {ase::sim_clear}

# ============================================================================
# SECTION KN -- THE KIND CATALOGUE IS THE ADAPTER'S (D34)
# ============================================================================
if {[catch {

check {KN1 the kind vocabulary is the one evidence/measure.md measured} \
  [lsort [dict keys [m_ans ase::meas_kinds ngspice]]] \
  {avg deriv fft find fourier integ linearize max max_at min min_at param pp psd rms spec trigtarg when}

check {KN2 one key decides which half of the block a row lands in} \
  [list [m_ans ase::meas_kind_form ngspice when] \
        [m_ans ase::meas_kind_form ngspice max] \
        [m_ans ase::meas_kind_form ngspice fft] \
        [m_ans ase::meas_kind_form ngspice linearize] \
        [m_ans ase::meas_kind_form ngspice nosuchkind]] \
  {meas meas producer producer {}}

## ⚠ FOUR ANALYSIS WORDS AND NO MORE. `chkAnalysisType()` (measure.c:146-154)
## accepts only these; noise, op, pz, tf, sens and disto are hard errors, which
## the dossier verified one `.meas` card at a time.
check {KN3 only four analysis types can carry a measurement at all} \
  [m_ans ase::meas_analyses ngspice] {tran dc ac sp}

## ⚠ THE ADAPTER'S OWN CATALOGUE, CHECKED. This is the row a second adapter's
## conformance harness will spend; here it keeps the first one honest.
check {KN4 the shipped catalogue has no schema errors} \
  [m_ans ase::meas_schema_errors ngspice] {}

## ⚠ AND IT REALLY CHECKS SOMETHING. KN4 alone passes over a checker that
## returns `{}` unconditionally, and the shipped catalogue cannot produce any of
## the four errors -- which is the point of it. The faults are built on a
## synthetic backend instead, one per arm, which is also the shape Stage 15's
## conformance harness will spend on a second adapter.
check {KN4b a catalogue that is wrong in four ways is reported in four ways} \
  [m_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzsk [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x meas_kinds ::ase_t_sk]
     proc ::ase_t_sk {} {
       return [dict create \
         noform  {fields {{name a}}} \
         badform {form sideways fields {{name a}}} \
         badctr  {form meas counter c fields {{name a}}} \
         badyld  {form meas yields plot fields {{name a}}} \
         badreq  {form meas fields {{name a required maybe}}} \
         noname  {form meas fields {{label a}}}]
     }
     ase::meas_cache_clear zzsk
     set r [lsort [ase::meas_schema_errors zzsk]]
     set ::ase::backends $save
     ase::meas_cache_clear zzsk
     rename ::ase_t_sk {}
     return $r }}] \
  [lsort [list {badctr: a counter belongs to a producer} \
               {badform: form 'sideways' is neither meas nor producer} \
               {badreq/a: required must be 0 or 1} \
               {badyld: only a producer may yield something other than a number} \
               {noform: no form} {noname: a field has no name}]]

## ⚠ A BACKEND WITH NO HOOK GETS NO MEASUREMENT CONTENT (D34). Core may not
## invent a vocabulary, and `{}` is what makes every row refuse rather than
## what makes core guess.
check {KN5 a backend that describes no measurements describes none} \
  [m_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzmk [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x]
     ase::meas_cache_clear zzmk
     set r [list [ase::meas_kinds zzmk] [ase::meas_analyses zzmk] \
                 [ase::meas_kind_form zzmk max]]
     set ::ase::backends $save
     ase::meas_cache_clear zzmk
     return $r }}] {{} {} {}}

## ⚠ NON-VACUITY FOR KN5: a backend that DOES declare the hook gets the content,
## through the same reader, so KN5 is measuring the hook and not the reader.
check {KN5b and one that declares the hook does get it} \
  [m_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzmk [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x meas_kinds ::ase_t_mk]
     proc ::ase_t_mk {} { return {pk {form meas fields {{name target required 1}}}} }
     ase::meas_cache_clear zzmk
     set r [list [dict keys [ase::meas_kinds zzmk]] [ase::meas_kind_form zzmk pk]]
     set ::ase::backends $save
     ase::meas_cache_clear zzmk
     rename ::ase_t_mk {}
     return $r }}] {pk meas}

## ⚠ THE MEMO IS DROPPED WHERE THE REPLACEMENT HAPPENS, exactly as issue 1406's
## analysis-type memo is. Registering a backend is the one event that changes
## what the hook would answer.
check {KN6 registering a backend drops the kind memo} \
  [m_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzmk [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x meas_kinds ::ase_t_mk1]
     proc ::ase_t_mk1 {} { return {a {form meas}} }
     ase::meas_cache_clear zzmk
     set before [dict keys [ase::meas_kinds zzmk]]
     proc ::ase_t_mk2 {} { return {b {form meas}} }
     ase::register_backend zzmk [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x meas_kinds ::ase_t_mk2]
     set after [dict keys [ase::meas_kinds zzmk]]
     set ::ase::backends $save
     ase::meas_cache_clear zzmk
     rename ::ase_t_mk1 {} ; rename ::ase_t_mk2 {}
     return [list $before $after] }}] {a b}

## ⚠ `deriv` IS NAMED AND REFUSED, WHICH IS NOT THE SAME AS BEING ABSENT.
## measure_function_type() RECOGNISES the word and com_measure2.c:2156 rejects
## it at RUN TIME -- so a user who types it gets `function 'deriv' currently not
## supported` and no explanation at all. KN7b is the half that says the two
## states really are different.
check_true {KN7 deriv is in the catalogue and carries its reason} \
  [expr {[string first {currently not supported} \
     [m_ans ase::meas_kind_unsupported ngspice deriv]] >= 0 ||
         [string first {refuses it at run time} \
     [m_ans ase::meas_kind_unsupported ngspice deriv]] >= 0}]

check {KN7b an implemented kind carries no unsupported reason} \
  [m_ans ase::meas_kind_unsupported ngspice max] {}

## ⚠ `td` IS NOT OFFERED ON THE EIGHT WINDOW STATISTICS AND THAT IS MEASURED.
## `TD=` is honoured only by com_measure_when() -- WHEN, TRIG and TARG -- and is
## SILENTLY IGNORED by AVG/MIN/MAX/MIN_AT/MAX_AT/PP/RMS/INTEG (the dossier's n6
## against n7). Offering a field the simulator drops is the defect this batch
## exists to delete.
check {KN8 a window statistic offers from/to and NOT the delay the simulator drops} \
  [list [lsort [m_ans apply {{} {
           set o {}
           foreach f [ase::meas_kind_fields ngspice avg] { lappend o [dict get $f name] }
           return $o }}]] \
        [lsort [m_ans apply {{} {
           set o {}
           foreach f [ase::meas_kind_fields ngspice when] { lappend o [dict get $f name] }
           return $o }}]]] \
  {{from target to} {dir from n target td to value}}

} knerr]} { check {KN0 section KN ran to the end} "RAISED:$knerr" {} }

# ============================================================================
# SECTION VD -- THE REFUSAL EVALUATOR
# ============================================================================
if {[catch {

proc vd {row {ans {}}} {
  set st [m_state [list $row] $ans]
  return [ase::meas_verdict ngspice $st $row]
}

check {VD1 a measurement with no name cannot be spelled} \
  [lindex [m_ans vd {analysis ac kind max target vdb(out)}] 0] refuse

## ⚠ THE NAME BECOMES A VECTOR, so it has to be a bare identifier. That is a
## property of the ROW, which is why core checks it without knowing a verb.
check {VD2 a name the simulator cannot make a vector of is refused} \
  [list [lindex [m_ans vd {name {v(out)} analysis ac kind max target vdb(out)}] 0] \
        [lindex [m_ans vd {name 3db analysis ac kind max target vdb(out)}] 0] \
        [lindex [m_ans vd {name f3db analysis ac kind max target vdb(out)}] 0]] \
  {refuse refuse ok}

check {VD3 a kind this simulator does not describe is refused} \
  [lindex [m_ans vd {name x analysis ac kind sorcery target vdb(out)}] 0] refuse

check {VD4 a kind the simulator NAMES and cannot RUN is refused with its reason} \
  [m_ans apply {{} {
     set v [vd {name d analysis tran kind deriv target v(out)}]
     return [list [lindex $v 0] [expr {[string first deriv [lindex $v 1]] >= 0 ||
                                       [string first DERIV [lindex $v 1]] >= 0}]] }}] \
  {refuse 1}

## ⚠ A ROW IS BOUND TO AN ANALYSIS OCCURRENCE, NOT TO A TYPE, because a bench
## may carry two `ac` rows writing two different plots -- the same fact issue
## 1430's sidecar exists for.
check {VD5 binding resolves to the first enabled row of the type, or to the named index} \
  [m_ans apply {{} {
     set st [m_state {} {{type ac enabled 0 sweep dec points 10 start 1 stop 1k}
                         {type ac enabled 1 sweep dec points 10 start 1 stop 1k}
                         {type ac enabled 1 sweep dec points 10 start 1 stop 2k}}]
     return [list [ase::meas_binding ngspice $st {name a analysis ac kind max target vdb(out)}] \
                  [ase::meas_binding ngspice $st {name a analysis ac row 2 kind max target vdb(out)}] \
                  [ase::meas_binding ngspice $st {name a analysis ac row 0 kind max target vdb(out)}] \
                  [ase::meas_binding ngspice $st {name a analysis tran kind max target v(out)}]] }}] \
  {{ac 1} {ac 2} {} {}}

check {VD6 a measurement with no enabled analysis to read is refused} \
  [lindex [m_ans vd {name x analysis tran kind max target v(out)} \
            {{type ac enabled 1 sweep dec points 10 start 1 stop 1k}}] 0] refuse

## ⚠ AND A TYPE THE SIMULATOR'S MEASURE ENGINE REJECTS OUTRIGHT. `noise` is a
## real, enabled, renderable analysis here -- it is the ENGINE that refuses it.
check {VD7 a measurement on an analysis the simulator cannot measure is refused} \
  [lindex [m_ans vd {name x analysis noise kind max target onoise_total} \
            {{type noise enabled 1 out v(out) insrc v1 sweep dec points 10 start 1 stop 1k}}] 0] \
  refuse

check {VD8 a required field with no value is refused, by its label} \
  [m_ans apply {{} {
     set v [vd {name x analysis ac kind when target vdb(out)}]
     return [list [lindex $v 0] [expr {[string first Value [lindex $v 1]] >= 0}]] }}] \
  {refuse 1}

## ⚠ AND "REQUIRED" MEANS THE VALUE THAT WILL REACH THE DECK, NOT THE STORED
## ONE. `psd`'s averaging width is `required 1 default 1` -- the simulator takes
## it as a POSITIONAL argument, so `psd v(out)` is an argument-count error and
## the slot must always carry something; the DECLARED DEFAULT is what carries
## it, through the same `ase::field_emits` the analysis form uses. A refusal can
## only be about the value that will be emitted.
check {VD8b a required slot the kind gives a default is satisfied by that default} \
  [list [lindex [m_ans vd {name x analysis tran kind psd target v(out)}] 0] \
        [m_ans ase::meas_field_value ngspice psd {name x} avgpts] \
        [m_ans ase::meas_field_value ngspice when {name x} value]] \
  {caution 1 {}}

## ⚠ TWO ROWS OF ONE NAME IS A REFUSAL. The name becomes a VECTOR in the
## simulator and a KEY in the sidecar, and the sidecar's lookup is
## case-insensitive because the simulator FOLDS what it prints -- so a second
## row of the same name silently overwrites the first's answer and the surface
## shows one number twice. The FIRST row keeps the name.
check {VD17 a second measurement of the same name is refused, and the first keeps it} \
  [m_ans apply {{} {
     set st [m_state {{name gain analysis ac kind max target vdb(out)}
                      {name Gain analysis ac kind min target vdb(out)}
                      {name loss analysis ac kind min target vdb(out)}}]
     set o {}
     foreach r [ase::meas_rows $st] {
       lappend o [ase::meas_name $r]/[lindex [ase::meas_verdict ngspice $st $r] 0]
     }
     return $o }}] {gain/ok Gain/refuse loss/ok}

check {VD17b and a DISABLED row does not reserve its name} \
  [m_ans apply {{} {
     set st [m_state {{name gain analysis ac kind max target vdb(out) enabled 0}
                      {name gain analysis ac kind min target vdb(out)}}]
     return [lindex [ase::meas_verdict ngspice $st \
       {name gain analysis ac kind min target vdb(out)}] 0] }}] ok

## ⚠ `FIND` HAS TWO GRAMMARS AND EXACTLY ONE MUST BE CHOSEN. Neither is a
## default for the other and a row with neither spells `bad syntax`.
check {VD9 a value measurement reads either at a point or when a signal crosses, never both and never neither} \
  [list [lindex [m_ans vd {name x analysis ac kind find target vp(out)}] 0] \
        [lindex [m_ans vd {name x analysis ac kind find target vp(out) at 1k}] 0] \
        [lindex [m_ans vd {name x analysis ac kind find target vp(out) when vdb(out) value 0}] 0] \
        [lindex [m_ans vd {name x analysis ac kind find target vp(out) at 1k when vdb(out) value 0}] 0]] \
  {refuse ok ok refuse}

## ⚠ THE CRASH RULE. `meas sp` on a REAL S-parameter run segfaults for WHEN,
## TRIG...TARG, RMS and INTEG -- the `frequency` scale of an `.sp` run is
## COMPLEX and com_measure_when() reads `v_realdata` unconditionally
## (com_measure2.c:461), while measure_rms_integral() has no SP branch at all
## (:1073). exit=139 for all four; exit=0 for FIND/MIN/MAX/AVG/PP.
check {VD10 the four functions that segfault a real S-parameter run are FATAL, and the safe ones are not} \
  [m_ans apply {{} {
     set ans {{type sp enabled 1}}
     return [list [lindex [vd {name a analysis sp kind when target S_1_1 value 0.5} $ans] 0] \
                  [lindex [vd {name a analysis sp kind rms target S_2_1} $ans] 0] \
                  [lindex [vd {name a analysis sp kind integ target S_2_1} $ans] 0] \
                  [lindex [vd {name a analysis sp kind trigtarg trig S_1_1 targ S_2_1} $ans] 0] \
                  [lindex [vd {name a analysis sp kind max target S_2_1} $ans] 0] \
                  [lindex [vd {name a analysis sp kind avg target S_2_1} $ans] 0]] }}] \
  {fatal fatal fatal fatal ok ok}

## ⚠ AND IT IS NARROWED TO A REAL `.sp` RUN, NOT TO THE WORD `sp`. On an
## fft/spec/psd SPECTRUM the `frequency` scale is REAL and every function is
## safe -- measure.md §4.6, and it is the whole reason `meas sp` is the right
## verb on a spectrum. A blanket refusal would take away the one thing §8c's
## producers are for.
check {VD10b the same function measured on a spectrum a producer made is NOT fatal} \
  [lindex [m_ans vd {name pk analysis tran kind rms target v(out) on s1}] 0] refuse

check {VD10c ... and with the producer row actually present it is ok} \
  [m_ans apply {{} {
     set st [m_state {{name s1 analysis tran kind fft target v(out)}
                      {name pk analysis tran kind rms target v(out) on s1}}]
     return [lindex [ase::meas_verdict ngspice $st \
       {name pk analysis tran kind rms target v(out) on s1}] 0] }}] ok

check {VD11 an `on` that names no post-processing row is refused} \
  [lindex [m_ans vd {name pk analysis tran kind max target v(out) on nosuch}] 0] refuse

check {VD11b and a producer cannot itself be measured on another one} \
  [m_ans apply {{} {
     set st [m_state {{name s1 analysis tran kind fft target v(out)}
                      {name s2 analysis tran kind psd avgpts 1 target v(out) on s1}}]
     return [lindex [ase::meas_verdict ngspice $st \
       {name s2 analysis tran kind psd avgpts 1 target v(out) on s1}] 0] }}] refuse

## ⚠ A PRODUCER READS A TRANSIENT. `linearize` guards on the plot typename
## (`Error: plot must be a transient analysis`) and `fft`/`psd`/`spec` guard on
## the scale (`Error: fft needs real time scale`).
check {VD12 a post-processing row bound to a non-transient analysis is refused} \
  [list [lindex [m_ans vd {name s analysis ac kind fft target vdb(out)}] 0] \
        [lindex [m_ans vd {name s analysis tran kind fft target v(out)}] 0]] \
  {refuse caution}

## ⚠ AND THE CAUTION IS NOT COSMETIC. `fft` and `psd` never look at the time
## VALUES: on raw adaptive-step data a pure 1 V 1 kHz sine measured
## 9.95420e-01 at 999.57 Hz against 9.99885e-01 at 999.50 Hz linearized.
check {VD13 a spectrum with no resample ahead of it cautions, and one with a resample does not} \
  [m_ans apply {{} {
     set a [m_state {{name s1 analysis tran kind fft target v(out)}}]
     set b [m_state {{name lin analysis tran kind linearize}
                     {name s1 analysis tran kind fft target v(out)}}]
     return [list [lindex [ase::meas_verdict ngspice $a \
                      {name s1 analysis tran kind fft target v(out)}] 0] \
                  [lindex [ase::meas_verdict ngspice $b \
                      {name s1 analysis tran kind fft target v(out)}] 0]] }}] \
  {caution ok}

## ⚠ `spec`'s OWN ARGUMENT RULES, which it answers with `Error: bad stop freq`
## and `Error: bad step freq` and then produces nothing at all.
check {VD14 a spectrum band that is not a band is refused} \
  [list [lindex [m_ans vd {name s analysis tran kind spec start 1k stop 100 step 10 target v(out)}] 0] \
        [lindex [m_ans vd {name s analysis tran kind spec start 0 stop 5k step 10k target v(out)}] 0] \
        [lindex [m_ans vd {name s analysis tran kind spec start 0 stop 5k step 100 target v(out)}] 0]] \
  {refuse refuse ok}

## ⚠ A DISABLED ROW IS NOT A REFUSED ROW. `enabled 0` costs a key, exactly as
## `save_op_params`'s tri-state does, and absent means enabled.
check {VD15 absent means enabled and only an explicit 0 turns a row off} \
  [list [m_ans ase::meas_enabled {name a}] [m_ans ase::meas_enabled {name a enabled 1}] \
        [m_ans ase::meas_enabled {name a enabled 0}]] {1 1 0}

## ⚠ THE SIMULATOR'S RULES COME LAST AND A BACKEND WITH NO `meas_rule` LEAVES
## THE ROW `ok`. A rule nobody stated is not a rule core may invent.
check {VD16 a backend with no rule hook refuses nothing of its own} \
  [m_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzmr [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x meas_kinds ::ase_t_mr]
     proc ::ase_t_mr {} { return {max {form meas fields {{name target required 1}}}} }
     ase::meas_cache_clear zzmr
     set st [m_state {{name a analysis sp kind max target S_2_1}} {{type sp enabled 1}}]
     dict set st simulator zzmr
     set r [lindex [ase::meas_verdict zzmr $st \
              {name a analysis sp kind max target S_2_1}] 0]
     set ::ase::backends $save
     ase::meas_cache_clear zzmr
     rename ::ase_t_mr {}
     return $r }}] ok

} vderr]} { check {VD0 section VD ran to the end} "RAISED:$vderr" {} }

# ============================================================================
# SECTION LN -- SPELLING ONE `meas` LINE
# ============================================================================
if {[catch {

proc ln {row} {
  set st [m_state [list $row]]
  return [ase::backend::ngspice::meas_line $st $row]
}

check {LN1 the canonical bandwidth measurement, spelled as the dossier measured it} \
  [m_ans ln {name f3db analysis ac kind when target vdb(out) value -3.0103 dir fall}] \
  {{meas ac f3db WHEN vdb(out)=-3.0103 FALL=1}}

check {LN2 a window statistic} \
  [m_ans ln {name gain analysis ac kind max target vdb(out)}] {{meas ac gain MAX vdb(out)}}

check {LN3 a delay} \
  [m_ans ln {name tr analysis tran kind trigtarg trig v(out) trigval 0.1 trigdir rise \
             targ v(out) targval 0.9 targdir rise}] \
  {{meas tran tr TRIG v(out) VAL=0.1 RISE=1 TARG v(out) VAL=0.9 RISE=1}}

check {LN4 a windowed RMS} \
  [m_ans ln {name irms analysis tran kind rms target i(vdd) from 1u to 10u}] \
  {{meas tran irms RMS i(vdd) FROM=1u TO=10u}}

check {LN5 a value at a point, and the same value when a signal crosses} \
  [list [m_ans ln {name p analysis ac kind find target vp(out) at 1k}] \
        [m_ans ln {name p analysis ac kind find target vp(out) when vdb(out) value 0}]] \
  {{{meas ac p FIND vp(out) AT=1k}} {{meas ac p FIND vp(out) WHEN vdb(out)=0}}}

## ⚠ ALWAYS `KEY=VALUE` WITH NO SURROUNDING WHITESPACE. `com_meas()` does no
## token joining, so a command written `VAL= 0.5` is `bad syntax. equal sign
## missing ?`. A deck's `.control` lines happen to be whitespace-stripped by
## inp_remove_ws() on the way in, which is exactly why this is a SPELLER rule
## and not a refusal: the same text typed at a prompt or sent through
## libngspice is not stripped.
check {LN6 no qualifier ever carries whitespace around its equals sign} \
  [m_ans apply {{} {
     set bad {}
     foreach row {{name a analysis tran kind when target v(out) value 0.5 dir rise td 1u from 2u to 3u}
                  {name b analysis tran kind trigtarg trig v(in) trigval 0.5 trigtd 1u trigdir rise
                   targ v(out) targval 0.5 targtd 2u targdir fall}
                  {name c analysis tran kind integ target v(out) from 1u to 2u}} {
       foreach l [ln $row] {
         if {[regexp {\s=|=\s} $l]} { lappend bad $l }
       }
     }
     return $bad }}] {}

## ⚠ THE EDGE QUALIFIER IS ONE TOKEN, NEVER TWO. `RISE=n`, `FALL=n` and
## `CROSS=n` each SET the other two to "not given" (com_measure2.c:1331-1339),
## so a line carrying two of them is a line writing over its own answer.
check {LN7 exactly one edge qualifier per trigger and per target} \
  [m_ans apply {{} {
     set l [lindex [ln {name b analysis tran kind trigtarg trig v(in) trigdir rise trign 2
                        targ v(out) targdir fall targn 3}] 0]
     return [list [regexp -all {RISE=|FALL=|CROSS=} $l] $l] }}] \
  {2 {meas tran b TRIG v(in) RISE=2 TARG v(out) FALL=3}}

## ⚠ NOTHING IS INJECTED INTO A SLOT THE USER LEFT EMPTY. That is issue 1432's
## `ptssum` lesson: a `?` slot that resolves to a default puts a setting on
## every line whose bench never asked for one.
check {LN8 an unset qualifier contributes nothing at all} \
  [m_ans ln {name a analysis tran kind when target v(out) value 0.5}] \
  {{meas tran a WHEN v(out)=0.5}}

## ⚠ THE `param` KIND IS A `let`, AND THAT IS THE PLAN'S FIRST TWO TRAPS
## ENCODED. RE-MEASURED 2026-09-13 on both binaries: the COMMAND form supports
## neither `param=` nor `expr=` nor `par()` -- `Error: measure p1 : no such
## function as 'param=7.756162e+00'`. `let pm1 = 180 + ok1` gives
## `pm1 = 1.807562e+02`, and it cannot hit `param=`'s once-per-session
## numparam placeholder because it never goes near numparam.
check {LN9 an expression over other measurements is a let, not a param=} \
  [m_ans ln {name pm analysis ac kind param expr {180 + phs}}] {{let pm = 180 + phs}}

check {LN9b and NOTHING this adapter spells ever writes expr= or param= or par(} \
  [m_ans apply {{} {
     set bad {}
     foreach row {{name a analysis ac kind param expr {180 + phs}}
                  {name b analysis ac kind find target vp(out) at 1k}
                  {name c analysis tran kind max target v(out)}} {
       foreach l [ln $row] {
         if {[regexp {expr=|param=|par\(} $l]} { lappend bad $l }
       }
     }
     return $bad }}] {}

## ⚠ THE ANALYSIS WORD OF A ROW MEASURED ON A SPECTRUM IS `sp`, AND ON A
## RESAMPLED TRANSIENT IT IS NOT. `get_measure2` gates on the CURRENT PLOT's
## typename and ft_plotabbrev() gives every fft/spec/psd plot the typename
## `spN` -- `sp` is a substring of `spectrum`. MEASURED 2026-09-13 on both
## binaries: fft -> sp2 (Spectrum), psd -> sp3 (PSD), spec -> sp4 (Spectrum),
## linearize -> tran2 (Transient Analysis (linearized)).
check {LN10 a measurement on a spectrum says sp, one on a resample keeps the transient's word} \
  [m_ans apply {{} {
     set st [m_state {{name s1 analysis tran kind fft target v(out)}
                      {name lin analysis tran kind linearize}
                      {name pk analysis tran kind max target v(out) on s1}
                      {name lv analysis tran kind max target v(out) on lin}}]
     return [list [ase::backend::ngspice::meas_word $st \
                     {name pk analysis tran kind max target v(out) on s1}] \
                  [ase::backend::ngspice::meas_word $st \
                     {name lv analysis tran kind max target v(out) on lin}] \
                  [ase::backend::ngspice::meas_word $st \
                     {name vm analysis tran kind max target v(out)}]] }}] \
  {sp tran tran}

} lnerr]} { check {LN0 section LN ran to the end} "RAISED:$lnerr" {} }

# ============================================================================
# SECTION PH -- THE RADIANS TRAP
# ============================================================================
if {[catch {

set PHPHASE [m_state {{name pm analysis ac kind find target vp(out) at 1k}}]
set PHPLAIN [m_state {{name gain analysis ac kind max target vdb(out)}}]

## ⚠ THE AUTO-EMISSION. MEASURED on both binaries through `meas` itself, an RC
## whose phase at 1 kHz is exactly -45 degrees: without it `-7.853982e-01`,
## with it `-4.500000e+01`.
check {PH1 a measurement that reads a phase gets the degrees line above it} \
  [m_lines $PHPHASE {^set units}] {{set units=degrees}}

## ⚠ THE NON-VACUITY CONTROL, AND IT IS THE HALF PLAN.md ASKS FOR BY NAME. A
## measurement with no phase in it must NOT emit the line -- an emitter that
## wrote it unconditionally would pass PH1 and fail here.
check {PH2 a measurement with no phase in it emits no units line at all} \
  [m_lines $PHPLAIN {^set units}] {}

check {PH2b and a bench with no measurements at all emits none either} \
  [m_lines [m_state {}] {^set units}] {}

## ⚠ THE LINE IS NOT A SECOND LITERAL. `units` is row 247 of this adapter's own
## option catalogue (issue 1437), so ase::opt_line already spells it and going
## through the speller keeps ONE answer to "how is an option written".
check {PH3 the degrees line is the option speller's, not a literal of its own} \
  [list [m_ans ase::opt_line ngspice units degrees control] \
        [lindex [m_lines $PHPHASE {^set units}] 0]] \
  {{set units=degrees} {set units=degrees}}

## ⚠ AND IT IS THE SPELLER BY CONSTRUCTION, NOT BY COINCIDENCE. PH3 compares two
## strings and a second literal that happened to agree would pass it. This reads
## the emitter: the body CALLS the speller and carries no spelling of its own.
check {PH3c the block that emits it calls the option speller and spells nothing itself} \
  [m_ans apply {{} {
     set b [m_nocomment [info body ase::backend::ngspice::meas_group]]
     return [list [expr {[string first {opt_line} $b] >= 0}] \
                  [expr {[string first {units=} $b] >= 0}] \
                  [expr {[string first {.options} $b] >= 0}]] }}] {1 0 0}

## ⚠ AND `units` REALLY IS IN THE CATALOGUE, which this task's brief and
## LEDGER.md's Stage 8 block both deny. Counted live: 247 rows, and it is one.
check {PH3b units is one of the catalogue rows, with the control door} \
  [list [expr {[dict exists [m_ans ase::sim_options ngspice] units] ? 1 : 0}] \
        [m_ans ase::opt_door ngspice units control]] {1 control}

## ⚠ THE CARD FORM IS NEVER EMITTED. MEASURED on both binaries:
## `.options units=degrees` leaves vp() in RADIANS, silently, and a phase
## margin computed under it is wrong by 57.2958x.
check {PH4 the inert card spelling is never written into the deck} \
  [m_ans apply {{} { return [regexp -all {\.options units} [m_deck $::PHPHASE]] }}] 0

## ⚠ AND THE LINE IS NOT TAKEN BACK. Restoring it would leave the user's own
## printed outputs reporting a phase in the unit the measurement above them did
## not use. The leak is reported instead. PH5b is the non-vacuity half: the
## restore spelling EXISTS, so PH5 is measuring a decision and not an absence.
check {PH5 the degrees line is not restored at the end of the block} \
  [m_lines $PHPHASE {^set units=radians}] {}

check {PH5b and the restore spelling does exist, so PH5 is a decision} \
  [m_ans ase::opt_restore_line ngspice units control] {set units=radians}

## ⚠ WHICH EXPRESSIONS COUNT AS A PHASE IS THE ADAPTER'S QUESTION, and a core
## that guessed it would be wrong for the next simulator in the direction that
## stays silent.
check {PH6 the phase test is the adapter's, over every expression field} \
  [list [m_ans ase::meas_needs_degrees ngspice {{target vp(out)}}] \
        [m_ans ase::meas_needs_degrees ngspice {{target ph(v(out))}}] \
        [m_ans ase::meas_needs_degrees ngspice {{when cph(v(out))}}] \
        [m_ans ase::meas_needs_degrees ngspice {{expr {180 + vp(out)}}}] \
        [m_ans ase::meas_needs_degrees ngspice {{target vdb(out)}}] \
        [m_ans ase::meas_needs_degrees ngspice {{target v(phase_out)}}]] \
  {1 1 1 1 0 0}

check {PH6b a backend with no phase hook asks for no unit change} \
  [m_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzph [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x]
     set r [ase::meas_needs_degrees zzph {{target vp(out)}}]
     set ::ase::backends $save
     return $r }}] 0

} pherr]} { check {PH0 section PH ran to the end} "RAISED:$pherr" {} }

# ============================================================================
# SECTION PP -- THE PRODUCERS (§8c)
# ============================================================================
if {[catch {

proc pp {row {all {}}} {
  if {![llength $all]} { set all [list $row] }
  set st [m_state $all]
  return [ase::backend::ngspice::postproc_lines $st $row]
}

check {PP1 resample, spectrum, power spectral density and band spectrum} \
  [list [m_ans pp {name l analysis tran kind linearize}] \
        [m_ans pp {name l analysis tran kind linearize np auto2n}] \
        [m_ans pp {name s analysis tran kind fft target v(out)}] \
        [m_ans pp {name s analysis tran kind psd avgpts 4 target v(out)}] \
        [m_ans pp {name s analysis tran kind spec start 0 stop 5k step 100 target v(out)}]] \
  {linearize {{linearize np=auto2n}} {{fft v(out)}} {{psd 4 v(out)}} {{spec 0 5k 100 v(out)}}}

## ⚠ THE THD VECTOR IS NAMED AFTER THE CALL NUMBER, RUN-WIDE, and the name is a
## plain concatenation of two decimal numbers (`tprintf("thd%d%d", …)`,
## fourier.c:199-240). MEASURED 2026-09-13 on both binaries: the first `fourier`
## command in a run makes `thd11`, the second makes `thd21`. So it is copied
## into a name of the user's own IMMEDIATELY, which is what the dossier tells a
## GUI to do.
check {PP2 a Fourier request copies its THD into the user's own name at once} \
  [m_ans pp {name thd analysis tran kind fourier fund 1k target v(out)}] \
  {{fourier 1k v(out)} {let thd = thd11}}

check {PP2b and the SECOND Fourier request in the run takes the second name} \
  [m_ans apply {{} {
     set st [m_state {{name t1 analysis tran kind fourier fund 1k target v(out)}
                      {name t2 analysis tran kind fourier fund 2k target v(out)}}]
     return [list [lindex [ase::backend::ngspice::postproc_lines $st \
                     {name t1 analysis tran kind fourier fund 1k target v(out)}] 1] \
                  [lindex [ase::backend::ngspice::postproc_lines $st \
                     {name t2 analysis tran kind fourier fund 2k target v(out)}] 1]] }}] \
  {{let t1 = thd11} {let t2 = thd21}}

## ⚠ THE ORDINAL IS COUNTED IN DECK EMISSION ORDER, ACROSS ANALYSES, and core
## counts it from the `counter` token the adapter put on the kind -- so core
## never learns the naming rule itself.
check {PP2c the counter runs across analysis rows, in emit order} \
  [m_ans apply {{} {
     set st [m_state {{name t2 analysis tran row 3 kind fourier fund 2k target v(out)}
                      {name t1 analysis tran row 1 kind fourier fund 1k target v(out)}} \
                     {{type ac enabled 1 sweep dec points 10 start 1 stop 1k}
                      {type tran enabled 1 step 1u stop 1m}
                      {type ac enabled 0 sweep dec points 10 start 1 stop 1k}
                      {type tran enabled 1 step 1u stop 2m}}]
     return [list [ase::meas_counter_index ngspice $st \
                    {name t1 analysis tran row 1 kind fourier fund 1k target v(out)}] \
                  [ase::meas_counter_index ngspice $st \
                    {name t2 analysis tran row 3 kind fourier fund 2k target v(out)}]] }}] \
  {1 2}

## ⚠ AND A PRODUCER OF ANOTHER KIND DOES NOT ADVANCE IT. The ordinal counts
## rows that share the `counter` TOKEN, because the simulator names its output
## after the n-th call of THAT verb -- a spectrum taken between two Fourier
## requests changes nothing about either one's vector name. A fixture of two
## Fourier rows alone cannot tell the two rules apart.
check {PP2e a producer of another kind does not advance the counter} \
  [m_ans apply {{} {
     set st [m_state {{name t1 analysis tran kind fourier fund 1k target v(out)}
                      {name s1 analysis tran kind fft target v(out)}
                      {name t2 analysis tran kind fourier fund 2k target v(out)}}]
     return [list [ase::meas_counter_index ngspice $st \
                    {name t1 analysis tran kind fourier fund 1k target v(out)}] \
                  [ase::meas_counter_index ngspice $st \
                    {name t2 analysis tran kind fourier fund 2k target v(out)}] \
                  [lindex [ase::backend::ngspice::postproc_lines $st \
                    {name t2 analysis tran kind fourier fund 2k target v(out)}] 1]] }}] \
  {1 2 {let t2 = thd21}}

check {PP2d a kind with no counter has no ordinal} \
  [m_ans apply {{} {
     set st [m_state {{name s analysis tran kind fft target v(out)}}]
     return [ase::meas_counter_index ngspice $st \
              {name s analysis tran kind fft target v(out)}] }}] 0

## ⚠ EVERY TRANSFORM AFTER THE FIRST IS SENT BACK TO THE TIME-DOMAIN SOURCE,
## AND THAT IS A MEASURED DEFECT REPAIRED. `fft`, `psd` and `spec` make their
## own output the CURRENT plot, so a second transform written straight after
## the first reads a SPECTRUM. MEASURED 2026-09-13 on both binaries:
## `fft v(mid)` then `psd 1 v(mid)` gives `Error: fft needs real time scale`,
## creates NO plot, and the run still exits 0.
check {PP3 a second transform is sent back to the time-domain source} \
  [m_ans apply {{} {
     set st [m_state {{name a analysis tran kind fft target v(out)}
                      {name b analysis tran kind psd avgpts 1 target v(out)}}]
     set out {}
     foreach l [ase::backend::ngspice::meas_block $st tran 1] {
       if {[regexp {^(setplot|fft|psd|set ase)} $l]} { lappend out $l }
     }
     return $out }}] \
  {{set aseplt = $curplot} {set asesrc = $curplot} {fft v(out)} {setplot $asesrc} {psd 1 v(out)} {setplot $aseplt}}

## ⚠ AND A RESAMPLE UPDATES THE SOURCE, so every transform after it reads the
## uniform grid -- the order §5.3 of the dossier says is MANDATORY for fft and
## psd. PP4b is the non-vacuity half: without the resample the source is never
## reassigned.
check {PP4 a resample becomes the source every later transform reads} \
  [m_ans apply {{} {
     set st [m_state {{name l analysis tran kind linearize}
                      {name a analysis tran kind fft target v(out)}}]
     set out {}
     foreach l [ase::backend::ngspice::meas_block $st tran 1] {
       if {[regexp {^(setplot|fft|linearize|set ase)} $l]} { lappend out $l }
     }
     return $out }}] \
  {{set aseplt = $curplot} {set asesrc = $curplot} linearize {set asesrc = $curplot} {setplot $asesrc} {fft v(out)} {setplot $aseplt}}

check {PP4b without a resample nothing reassigns the source, and one producer declares none} \
  [m_ans apply {{} {
     set two [m_state {{name a analysis tran kind fft target v(out)}
                       {name b analysis tran kind psd avgpts 1 target v(out)}}]
     set one [m_state {{name a analysis tran kind fft target v(out)}}]
     set n 0
     foreach l [ase::backend::ngspice::meas_block $two tran 1] {
       if {$l eq {set asesrc = $curplot}} { incr n }
     }
     set m 0
     foreach l [ase::backend::ngspice::meas_block $one tran 1] {
       if {$l eq {set asesrc = $curplot}} { incr m }
     }
     return [list $n $m] }}] {1 0}

## ⚠ THE BLOCK PUTS THE ANALYSIS'S OWN PLOT BACK, so the `setplot previous`
## walk that follows starts exactly where it always did.
check {PP5 a block that changed the current plot puts it back} \
  [m_ans apply {{} {
     set st [m_state {{name a analysis tran kind fft target v(out)}}]
     return [lindex [ase::backend::ngspice::meas_block $st tran 1] end] }}] \
  {setplot $aseplt}

## ⚠ AND A BLOCK WHOSE ONE PRODUCER MAKES NO PLOT EMITS NO PLOT BOOKKEEPING
## EITHER. A Fourier request creates `fourier<m><n>` and `thd<m><n>` IN THE
## CURRENT PLOT and leaves `$curplot` where it was -- measured on both binaries
## -- so there is nothing to remember and nothing to put back, and an inert
## `set` in a generated deck is a line the next reader has to work out.
check {PP5c a Fourier-only block emits no plot bookkeeping at all} \
  [m_ans apply {{} {
     set st [m_state {{name thd analysis tran kind fourier fund 1k target v(out)}}]
     set out {}
     foreach l [ase::backend::ngspice::meas_block $st tran 1] {
       if {[regexp {^(setplot|set ase)} $l]} { lappend out $l }
     }
     return $out }}] {}

check {PP5b a measurements-only block changes no plot and restores none} \
  [m_ans apply {{} {
     set st [m_state {{name a analysis tran kind max target v(out)}}]
     set out {}
     foreach l [ase::backend::ngspice::meas_block $st tran 1] {
       if {[regexp {^(setplot|set ase)} $l]} { lappend out $l }
     }
     return $out }}] {}

## ⚠ A MEASUREMENT MADE ON A PRODUCER'S PLOT IS EMITTED WHILE THAT PLOT IS
## CURRENT, which is the only moment it can be: `get_measure2` measures the
## CURRENT plot and nothing in a deck can name a plot by hand (issue 1430's C1).
check {PP6 a measurement bound to a producer follows that producer immediately} \
  [m_ans apply {{} {
     set st [m_state {{name s1 analysis tran kind fft target v(out)}
                      {name pk analysis tran kind max target v(out) on s1}}]
     set out {}
     foreach l [ase::backend::ngspice::meas_block $st tran 1] {
       if {[regexp {^(fft|meas )} $l]} { lappend out [string trim [lindex [split $l >] 0]] }
     }
     return [string trim [join $out |]] }}] \
  {fft v(out)|meas sp pk MAX v(out)}

## ⚠ NO PRODUCER PLOT IS WRITTEN INTO THE RESULTS FILE, AND THAT IS A MEASURED
## REFUSAL. read_dataset() maps a `Plotname:` to a sim_type by SUBSTRING:
## "transient analysis" at save.c:957 and "spectrum" at :987. MEASURED through
## this tree's own reader on a file holding a real transient, a linearized copy
## made to disagree, and an fft spectrum: `raw read … tran` -> datasets=2 and
## `raw read … ac` -> datasets=1 sim_type=ac with no ac analysis in the deck.
check {PP7 a post-processing block writes no plot into the results file} \
  [m_ans apply {{} {
     set st [m_state {{name l analysis tran kind linearize}
                      {name a analysis tran kind fft target v(out)}
                      {name b analysis tran kind psd avgpts 1 target v(out)}
                      {name c analysis tran kind spec start 0 stop 5k step 100 target v(out)}}]
     set bad {}
     foreach l [ase::backend::ngspice::meas_block $st tran 1] {
       if {[regexp {^(write |echo "PLOT )} $l]} { lappend bad $l }
     }
     return $bad }}] {}

## ⚠ NON-VACUITY FOR PP7: the deck as a whole DOES write and DOES record, so
## PP7 is measuring the block and not an empty deck.
check {PP7b and the deck around it still writes and records, once per analysis} \
  [m_ans apply {{} {
     set st [m_state {{name l analysis tran kind linearize}
                      {name a analysis tran kind fft target v(out)}}]
     set d [m_deck $st]
     return [list [regexp -all -line {^write } $d] \
                  [regexp -all -line {^echo "PLOT } $d]] }}] {2 2}

} pperr]} { check {PP0 section PP ran to the end} "RAISED:$pperr" {} }

# ============================================================================
# SECTION DK -- THE DECK
# ============================================================================
if {[catch {

## ⚠ BYTE IDENTITY IS THE ACCEPTANCE CRITERION FOR EVERY BENCH THAT CARRIES NO
## MEASUREMENT. The list is absent by default and in ase::omit_if_empty, which
## is what keeps the 104 committed .state files round-tripping.
check {DK1 a bench with no measurements renders byte-identically, and so does one whose rows are all off} \
  [m_ans apply {{} {
     set a [m_deck [m_state {}]]
     set b [m_deck [m_state {{name x analysis ac kind max target vdb(out) enabled 0}}]]
     set c [m_deck [m_state {{name x analysis ac kind sorcery target vdb(out)}}]]
     return [list [string equal $a $b] [string equal $a $c]] }}] {1 1}

check {DK1b the state key defaults to empty and is omitted from the serialized form} \
  [list [dict get [m_ans ase::state_default] measurements] \
        [expr {[string first measurements \
          [m_ans ase::state_serialize [m_ans ase::state_default]]] >= 0}] \
        [llength [dict get [m_ans ase::state_default] analyses]]] {{} 0 4}

## ⚠ WHERE THE BLOCK GOES IS ITSELF A MEASUREMENT AND ALL FOUR BOUNDS ARE
## LOAD-BEARING:
##   1. BELOW the $sim_status guard -- an analysis that failed never measures,
##      because the guard `quit 1`s above here;
##   2. BELOW the row's first `write` -- the length-1 result vectors never reach
##      the results file. MEASURED 2026-09-13 on both binaries: a `fourier`
##      before the write on a 1,000,001-point transient grew the rawfile from
##      48,000,724 to 64,000,905 bytes, +16 MB for TWO SCALARS, because the
##      plot's default scale is imposed and a length-1 vector is expanded to the
##      whole record;
##   3. ABOVE the `setplot previous` walk -- get_measure2 measures the CURRENT
##      plot (com_measure2.c:1661) and the walk leaves a different one current;
##   4. ABOVE the printed outputs (0967/1243) and above the per-analysis option
##      restores (§7e), which are end-of-row anchors belonging to other issues.
## Issue 1442's sabotage S24 was this same case and it SURVIVED the first time,
## because the row's bound admitted the wrong placement. This row bounds all
## four sides.
set DKST [m_state {{name gain analysis ac kind max target vdb(out)}} \
                  {{type ac enabled 1 sweep dec points 10 start 1 stop 1k}}]
dict set DKST outputs {{name out expr v(out) save 1}}
dict set DKST options {{name itl4 value 200 analysis ac}}
set DKDECK [m_deck $DKST]
check {DK2 the measurement block sits below the guard and the write, and above the walk, the prints and the option restores} \
  [m_ans apply {{} {
     set d $::DKDECK
     set g [m_at $d {^  quit 1$}]
     set w [m_at $d {^write }]
     set m [m_at $d {^meas ac gain }]
     set p [m_at $d {^print }]
     set r [m_last $d {^option itl4=}]
     return [list [expr {$g >= 0 && $g < $m}] \
                  [expr {$w >= 0 && $w < $m}] \
                  [expr {$p >= 0 && $m < $p}] \
                  [expr {$r >= 0 && $m < $r}]] }}] {1 1 1 1}

## ⚠ NON-VACUITY FOR DK2: every anchor it names is really in that deck. A row
## whose landmarks are absent compares -1 against -1 and passes over anything.
check {DK2b every anchor DK2 bounds against is really in that deck} \
  [m_ans apply {{} {
     set d $::DKDECK
     return [list [expr {[m_at $d {^  quit 1$}] >= 0}] \
                  [expr {[m_at $d {^write }] >= 0}] \
                  [expr {[m_at $d {^meas ac gain }] >= 0}] \
                  [expr {[m_at $d {^print }] >= 0}] \
                  [expr {[m_last $d {^option itl4=}] > [m_at $d {^option itl4=}]}]] }}] {1 1 1 1 1}

## ⚠ AND THE SAME FOUR BOUNDS, READ OFF render_deck's OWN BODY. DK2 can only
## bound what a PARTICULAR fixture emits, and three of the four moves are
## invisible on a single-capture analysis -- there is no walk to be below. This
## row reads the emitter instead, so a block moved above the write, below the
## walk, below the prints or below the option restores is caught whatever the
## fixture does. Issue 1442's S24 hid in exactly that gap.
check {DK2c render_deck calls the block between the write and the walk, above the prints and above the restores} \
  [m_ans apply {{} {
     set b [m_nocomment [info body ase::backend::ngspice::render_deck]]
     set call [string first {meas_block $state $type $ai} $b]
     set wr   [string first {lappend lines "write [raw_file $state]"} $b]
     set walk [string first {lappend lines "setplot previous"} $b]
     set pr   [string first {foreach pl $printlines} $b]
     set rest [string first {foreach _ol $scopepost} $b]
     return [list [expr {$call > 0 && $wr > 0 && $walk > 0 && $pr > 0 && $rest > 0}] \
                  [expr {$wr < $call}] [expr {$call < $walk}] \
                  [expr {$call < $pr}] [expr {$call < $rest}]] }}] {1 1 1 1 1}

## ⚠ THE SIDECAR IS OPENED BY A COMMAND THAT CANNOT FAIL, AND EVERY MEASUREMENT
## APPENDS. MEASURED 2026-09-13 on both binaries: a `meas … > file` whose
## measurement FAILS creates the file and leaves it at ZERO BYTES. Opening with
## `>` on the first measurement would therefore truncate the whole sidecar
## whenever that one row fails.
check {DK3 the sidecar is opened by an echo and every measurement appends} \
  [m_ans apply {{} {
     set out {}
     foreach l [split $::DKDECK "\n"] {
       if {[regexp {^(echo ASE-MEAS|meas )} $l]} {
         lappend out [string map [list $::scratch/ {}] $l]
       }
     }
     return $out }}] \
  {{echo ASE-MEAS >> rc_ase.meas} {meas ac gain MAX vdb(out) >> rc_ase.meas}}

## ⚠ NOTHING ANALYSIS-SHAPED EVER GOES IN THE CARD SLOT, AND BOTH HALVES OF THE
## CARD/COMMAND RULE ARE MEASURED. `.meas` cards are refused under `-r` (`No
## .measure possible in batch mode (-b) with -r rawfile set!`) AND a dot card --
## `.meas` or `.four` -- runs the whole simulation a SECOND time: measured on
## both binaries, `Doing analysis at TEMP` appears TWICE beside a `.control`
## block and ONCE with the command form.
check {DK4 no dot card is ever emitted for a measurement or for a Fourier request} \
  [m_ans apply {{} {
     set st [m_state {{name gain analysis ac kind max target vdb(out)}
                      {name thd analysis tran kind fourier fund 1k target v(out)}}]
     set d [m_deck $st]
     return [list [regexp -all -line {^\.meas} $d] \
                  [regexp -all -line {^\.measure} $d] \
                  [regexp -all -line {^\.four} $d] \
                  [regexp -all -line {^fourier } $d]] }}] {0 0 0 1}

## ⚠ A MEASUREMENT THE SIMULATOR WOULD CRASH ON REFUSES THE WHOLE DECK, BEFORE A
## SINGLE LINE IS BUILT -- issue 1424's third refusal tier, one level down. A
## `.state` can be hand-edited, so the dialog having been happy once is not
## evidence about this deck.
check {DK5 a measurement that would segfault the simulator refuses the deck} \
  [m_ans apply {{} {
     set st [m_state {{name a analysis sp kind rms target S_2_1}} {{type sp enabled 1}}]
     set rc [catch {m_deck $st} e]
     return [list $rc [expr {[string first {nothing was rendered} $e] >= 0}]] }}] {1 1}

## ⚠ NON-VACUITY FOR DK5, AND IT SAYS WHAT THE OTHER REFUSAL IS. `sp` is still
## a probe stub with no `emit` template, so a deck carrying one is refused
## whatever its measurements say -- by ase::analysis_unrenderable_msg, with a
## DIFFERENT sentence that names no measurement. DK5 is therefore measuring its
## own refusal and not that one.
check {DK5b a SAFE measurement on the same analysis is refused by something else, and by a different sentence} \
  [m_ans apply {{} {
     set fat [m_state {{name a analysis sp kind rms target S_2_1}} {{type sp enabled 1}}]
     set ok  [m_state {{name a analysis sp kind max target S_2_1}} {{type sp enabled 1}}]
     catch {m_deck $fat} efat
     catch {m_deck $ok}  eok
     return [list [expr {$efat ne $eok}] \
                  [expr {[string first {measurement 'a'} $efat] >= 0}] \
                  [expr {[string first {measurement} $eok] >= 0}]] }}] {1 1 0}

## ⚠ THE WALK, THE PLOTMAP AND analysis_captures ARE UNTOUCHED BY STAGE 8, and
## that is what keeps issue 1430's over-walk guard (test_ase_core WK8) meaning
## what it meant: an over-walk SATURATES on the built-in `constants` plot and
## appends twelve mathematical constants at rc 0 with every count agreeing.
check {DK6 a bench full of post-processing predicts exactly the plots its analyses make} \
  [m_ans apply {{} {
     set st [m_state {{name l analysis tran kind linearize}
                      {name a analysis tran kind fft target v(out)}
                      {name t analysis tran kind fourier fund 1k target v(out)}} \
                     {{type tran enabled 1 step 5u stop 1m}}]
     set plain [m_state {} {{type tran enabled 1 step 5u stop 1m}}]
     set row {type tran enabled 1 step 5u stop 1m}
     return [list [llength [ase::analysis_captures ngspice $row $st]] \
                  [llength [ase::analysis_captures ngspice $row $plain]] \
                  [regexp -all -line {^setplot previous$} [m_deck $st]]] }}] {1 1 0}

## ⚠ TWO ROWS OF ONE TYPE GET THEIR OWN MEASUREMENTS, which is the case the
## type alone cannot answer -- the same fact issue 1430's row index exists for.
check {DK7 a measurement bound to the second row of a type is emitted in that row's block} \
  [m_ans apply {{} {
     set st [m_state {{name a analysis tran row 0 kind max target v(out)}
                      {name b analysis tran row 1 kind min target v(out)}} \
                     {{type tran enabled 1 step 5u stop 1m}
                      {type tran enabled 1 step 5u stop 2m}}]
     set out {}
     foreach l [split [m_deck $st] "\n"] {
       if {[regexp {^(tran |meas )} $l]} { lappend out [string trim [lindex [split $l >] 0]] }
     }
     return [string trim [join $out |]] }}] \
  {tran 5u 1m|meas tran a MAX v(out)|tran 5u 2m|meas tran b MIN v(out)}

} dkerr]} { check {DK0 section DK ran to the end} "RAISED:$dkerr" {} }

# ============================================================================
# SECTION SC -- THE SIDECAR AND WHAT COMES BACK
# ============================================================================
if {[catch {

## ⚠ IT RAISES FOR A STATE WITH NO DESIGN CELL, exactly as its five siblings do,
## so every core caller catches. Issue 1429's sabotage S31 removed one such
## `catch` and killed a suite at a row a year older than the seam.
check {SC1 the sidecar sits beside the results file, and raises without a cell} \
  [m_ans apply {{} {
     set st [m_state {}]
     set a [ase::meas_path $st]
     set b [catch {ase::meas_path [dict remove $st design]}]
     return [list [file tail $a] [file dirname $a] $b] }}] \
  [list rc_ase.meas $scratch 1]

## ⚠ THE NAME COMES BACK FOLDED, AND THAT IS MEASURED RATHER THAN DEFENSIVE.
## Under the default case mode the simulator lower-cases the names it prints
## back: a `print thdA` comes back as `thda`. MEASURED 2026-09-13, both
## binaries.
check {SC2 the printed lines parse, and the lookup is case-insensitive} \
  [m_ans apply {{} {
     set t "ASE-MEAS\ngain                =  -4.342728e-04 at=  1.000000e+01\n"
     append t "f3db                =  1.000000e+03\n"
     append t "thda = 5.292412e-12\n"
     set d [ase::meas_parse $t]
     return [list [lsort [dict keys $d]] \
                  [lindex [dict get $d f3db] 0] \
                  [lindex [dict get $d gain] 1]] }}] \
  {{f3db gain thda} 1.000000e+03 {at=  1.000000e+01}}

## ⚠ NON-VACUITY FOR SC2's FOLD, AND SC2 ALONE COULD NOT SEE IT: every name in
## that fixture is already lower case, so folding and not folding give the same
## key. The simulator really does fold -- MEASURED 2026-09-13 on both binaries,
## `print thdA` comes back `thda` -- but a sidecar written by something that did
## not would still have to be read by the name the bench stored.
check {SC2c a name the file spells in capitals is still found by the bench's own spelling} \
  [m_ans apply {{} {
     set d [ase::meas_parse "ASE-MEAS\nTHD_A = 5.29e-12\nGain    =  -4.34e-04 at=  1.0e+01\n"]
     return [list [lsort [dict keys $d]] \
                  [lindex [dict get $d thd_a] 0] [lindex [dict get $d gain] 0]] }}] \
  {{gain thd_a} 5.29e-12 -4.34e-04}

## ⚠ THE SIMULATOR'S OWN PRINTED LINE IS BINARY-DEPENDENT AND THE PARSE MUST
## NOT BE. Measured by the driver 2026-09-13 on both binaries, the same
## measurement on the same deck:
##
##     apt 45.2   vmax                =  1.000000e+00 at=  2.000000e-08
##     the fork   vmax                =  1.00000e+00 at=  2.00000e-08
##
## -- SIX decimals against FIVE, because `measure_get_precision()`'s default is
## honoured on the fork and `measureprec` is inert on 45.2 (C146). A reader that
## took the value by field width or by digit count would pass on one binary and
## fail on the other. `ase::meas_parse` takes it as a TOKEN and the caller reads
## it as a NUMBER, so the two spellings answer the same.
check {SC2d both binaries' spellings of one measurement parse to the same number} \
  [m_ans apply {{} {
     set apt  "vmax                =  1.000000e+00 at=  2.000000e-08"
     set fork "vmax                =  1.00000e+00 at=  2.00000e-08"
     set a [ase::meas_parse $apt]
     set b [ase::meas_parse $fork]
     return [list [expr {[lindex [dict get $a vmax] 0] == [lindex [dict get $b vmax] 0]}] \
                  [lindex [dict get $a vmax] 0] [lindex [dict get $b vmax] 0] \
                  [expr {[lindex [dict get $a vmax] 1] eq [lindex [dict get $b vmax] 1]}]] }}] \
  {1 1.000000e+00 1.00000e+00 0}

## ⚠ AND THE `print` FORM, WHICH THE DRIVER MEASURED BYTE-IDENTICAL ACROSS THE
## TWO BINARIES, PARSES THROUGH THE SAME READER. That is what a Fourier row's
## THD comes back as, and it is why the sidecar can hold both shapes at once.
check {SC2e the print form and the meas form come back through one parser} \
  [m_ans apply {{} {
     set d [ase::meas_parse "ASE-MEAS\nvmax                =  1.000000e+00 at=  2.0e-08\nthd = 9.870397e-05\n"]
     return [list [lsort [dict keys $d]] \
                  [lindex [dict get $d thd] 0] [lindex [dict get $d thd] 1]] }}] \
  {{thd vmax} 9.870397e-05 {}}

check {SC2b the marker line and blank lines are not measurements} \
  [m_ans apply {{} { return [dict keys [ase::meas_parse "ASE-MEAS\n\n   \n"]] }}] {}

## ⚠ A ROW THAT EMITTED AND PRODUCED NOTHING IS ITS OWN VERDICT, not a blank.
## A measurement whose extractor returns nothing cannot disagree with anything,
## and an empty cell is read as zero.
check {SC3 every row gets a verdict, and a row the run did not report says so} \
  [m_ans apply {{} {
     set st [m_state {{name gain analysis ac kind max target vdb(out)}
                      {name f3db analysis ac kind when target vdb(out) value -3 dir fall}
                      {name off analysis ac kind max target vdb(out) enabled 0}
                      {name bad analysis ac kind sorcery target vdb(out)}}]
     set t "ASE-MEAS\ngain                =  -4.342728e-04 at=  1.000000e+01\n"
     set o {}
     foreach e [ase::meas_results ngspice $st $t] {
       lappend o [lindex $e 0]/[lindex $e 1]
     }
     return $o }}] {gain/ok f3db/failed off/off bad/refused}

## ⚠ A ROW THAT WAS NEVER GOING TO REPORT A NUMBER IS NOT A FAILED ONE. A
## Resample row makes a PLOT; a report that walked every row and complained
## about the silent ones would say *"the simulator did not report this
## measurement"* beside a row that did exactly what it was asked to -- which is
## the false-alarm class issue 1442 spent three verdicts on.
check {SC3c a producer that yields a plot reports `produced`, and says nothing in the report} \
  [m_ans apply {{} {
     set st [m_state {{name lin analysis tran kind linearize}
                      {name thd analysis tran kind fourier fund 1k target v(out)}
                      {name vmax analysis tran kind max target v(out)}}]
     set t "ASE-MEAS\nthd = 9.870397e-05\n"
     set o {}
     foreach e [ase::meas_results ngspice $st $t] { lappend o [lindex $e 0]/[lindex $e 1] }
     return [list $o [llength [ase::meas_report ngspice $st $t]]] }}] \
  {{lin/produced thd/ok vmax/failed} 2}

check {SC3d and the kind catalogue is what says which rows those are} \
  [list [m_ans ase::meas_kind_yields ngspice linearize] \
        [m_ans ase::meas_kind_yields ngspice fft] \
        [m_ans ase::meas_kind_yields ngspice fourier] \
        [m_ans ase::meas_kind_yields ngspice max] \
        [m_ans ase::meas_kind_yields ngspice nosuchkind]] \
  {plot plot number number number}

check {SC3b a caution row keeps its number AND its warning} \
  [m_ans apply {{} {
     set st [m_state {{name s1 analysis tran kind fft target v(out)}
                      {name pk analysis tran kind max target v(out) on s1}}]
     set t "ASE-MEAS\npk                  =  2.47026e-01 at=  1.09945e+03\n"
     foreach e [ase::meas_results ngspice $st $t] {
       if {[lindex $e 0] eq {pk}} { return [list [lindex $e 1] [lindex $e 2]] }
     }
     return notfound }}] {ok 2.47026e-01}

check {SC4 one measurement can be looked up by the name the bench stored} \
  [m_ans apply {{} {
     set st [m_state {{name thd analysis tran kind fourier fund 1k target v(out)}}]
     set t "ASE-MEAS\nthd = 9.870397e-05\n"
     return [list [ase::meas_result ngspice $st thd [ase::meas_parse $t]] \
                  [ase::meas_result ngspice $st nosuch [ase::meas_parse $t]]] }}] \
  {9.870397e-05 {}}

check {SC5 the report says a number for what was measured and a reason for what was not} \
  [m_ans apply {{} {
     set st [m_state {{name gain analysis ac kind max target vdb(out)}
                      {name f3db analysis ac kind when target vdb(out) value -3 dir fall}}]
     set t "ASE-MEAS\ngain                =  -4.342728e-04 at=  1.000000e+01\n"
     set r [ase::meas_report ngspice $st $t]
     return [list [llength $r] [lindex $r 0] \
                  [expr {[string first {did not report} [lindex $r 1]] >= 0}]] }}] \
  {2 {gain = -4.342728e-04} 1}

check {SC6 nothing armed means nothing to read and nothing to say} \
  [m_ans apply {{} {
     set st [m_state {}]
     return [list [ase::meas_armed ngspice $st] [ase::meas_report ngspice $st] \
                  [ase::meas_read ngspice $st]] }}] {0 {} {}}

check {SC6b and one enabled row arms it} \
  [m_ans ase::meas_armed ngspice \
     [m_state {{name gain analysis ac kind max target vdb(out)}}]] 1

## ⚠ A ROW THAT CANNOT BE SPELLED ARMS NOTHING, AND NEITHER DOES ONE THAT IS
## TURNED OFF. `ase::meas_armed` asks whether this run has anything to MEASURE,
## not whether the bench has anything stored -- a list holding only refused rows
## produces no `meas` line, so a report guarded on it would have nothing to
## describe. SC6 and SC6b alone cannot tell that from "the list is non-empty".
check {SC6c a list of rows that cannot be spelled arms nothing} \
  [list [m_ans ase::meas_armed ngspice \
           [m_state {{name gain analysis ac kind sorcery target vdb(out)}}]] \
        [m_ans ase::meas_armed ngspice \
           [m_state {{name gain analysis ac kind max target vdb(out) enabled 0}}]] \
        [m_ans ase::meas_armed ngspice \
           [m_state {{name gain analysis tran kind max target v(out)}
                     {name g2 analysis ac kind sorcery target vdb(out)}}]]] {0 0 1}

## ⚠ THE SIDECAR IS DELETED BEFORE THE RUN, WITH ITS FIVE SIBLINGS AND AT THE
## TOP OF run_deck -- not just before `eval execute`. The deck APPENDS to it, so
## a file left from the previous run is not truncated and a row whose condition
## never occurs in THIS run would be served the PREVIOUS run's answer under its
## own name. Issue 1430 learned where; issue 1442's S24 learned it again.
check {SC7 the deletion sits in the pre-run block, above every other line of run_deck} \
  [m_ans apply {{} {
     set body [m_nocomment [info body ase::run_deck]]
     set del [string first {ase::meas_path $state} $body]
     set exe [string first {eval execute} $body]
     set raw [string first {file delete -- [[ase::backend_hook $sim raw_file] $state]} $body]
     set eff [string first {ase::effective_path $state} $body]
     return [list [expr {$del > 0}] [expr {$exe > 0}] [expr {$del < $exe}] \
                  [expr {$del > $raw}] [expr {$del > $eff}]] }}] {1 1 1 1 1}

} scerr]} { check {SC0 section SC ran to the end} "RAISED:$scerr" {} }

# ============================================================================
# SECTION HK -- ASE-L OWNS THE SCHEMA, THE ADAPTER OWNS THE CONTENT (D34)
# ============================================================================
if {[catch {

## ⚠ COMMENTS ARE STRIPPED BEFORE THE SCAN, exactly as issues 1441 and 1442 do
## it. Every comment in this issue's core procs QUOTES an ngspice measurement on
## purpose -- that is what makes them evidence -- and a scanner that read them
## would redden on the documentation rather than on the code.
##
## ⚠ AND THE LIST HOLDS SPELLINGS, NOT WORDS. Issue 1442's C142 paid for that
## three times: `option` is ngspice's command AND ASE-L's own noun. Here
## `measurements` is ASE-L's own state key, `meas` is ngspice's command word,
## and the two differ by four characters -- so the guard looks for the LINE
## SHAPES a deck would carry.
set HKTOK {{meas $} {let $} {fourier } {linearize} {fft } {psd } {spec }
           {units degrees} {TRIG} {TARG} {WHEN} {RISE=} {FALL=} {CROSS=}
           {setplot } {curplot} {thd} {cph} {vdb} {vp|}}
set HKPROCS {ase::meas_kinds ase::meas_kind_entry ase::meas_kind_form
             ase::meas_kind_unsupported ase::meas_kind_fields ase::meas_kind_field
             ase::meas_kind_yields
             ase::meas_analyses ase::meas_rows ase::meas_enabled ase::meas_name
             ase::meas_field_value ase::meas_binding ase::meas_on
             ase::meas_producer_of ase::meas_name_ok ase::meas_verdict
             ase::meas_for ase::meas_fatals ase::meas_armed
             ase::meas_counter_index ase::meas_path ase::meas_marker
             ase::meas_parse ase::meas_read ase::meas_result ase::meas_results
             ase::meas_report ase::meas_needs_degrees ase::meas_schema_errors
             ase::meas_cache_clear}
check {HK1 no core measurement proc spells a single ngspice word} \
  [m_ans apply {{} {
     set bad {}
     foreach p $::HKPROCS {
       if {![llength [info commands ::$p]]} { lappend bad "$p:MISSING" ; continue }
       set body [m_nocomment [info body ::$p]]
       foreach t $::HKTOK {
         if {[string first $t $body] >= 0} { lappend bad "$p:$t" }
       }
     }
     return $bad }}] {}

## ⚠ NON-VACUITY FOR HK1, AND IT RUNS HK1'S OWN TOKEN LIST. A guard that found
## nothing anywhere would be measuring its own emptiness.
check_true {HK1b the same token list finds those spellings in the adapter} \
  [m_ans apply {{} {
     set n 0
     foreach p {ase::backend::ngspice::meas_line ase::backend::ngspice::postproc_lines
                ase::backend::ngspice::meas_block ase::backend::ngspice::meas_kinds} {
       set body [m_nocomment [info body ::$p]]
       foreach t $::HKTOK { if {[string first $t $body] >= 0} { incr n } }
     }
     return [expr {$n >= 8}] }}]

## ⚠ AND THE ADAPTER HOOKS ARE OPTIONAL. A backend that registers the five
## required hooks and nothing else still registers, and gets no measurement
## content at all.
check {HK2 the measurement hooks are optional, and a five-hook backend still registers} \
  [m_ans apply {{} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zzho [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x]}]
     set r [list $rc [ase::meas_kinds zzho]]
     set ::ase::backends $save
     ase::meas_cache_clear zzho
     return $r }}] {0 {}}

} hkerr]} { check {HK0 section HK ran to the end} "RAISED:$hkerr" {} }

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
