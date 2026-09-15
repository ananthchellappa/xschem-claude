# tests/headless/test_ase_effective_1442.tcl -- ISSUE 1442: A SCOPE THE
# SIMULATOR DOES NOT HAVE, A READ-BACK CHANNEL THAT WAS HALF BROKEN, AND THE
# FOUR RULES. PLAN.md Stage 7e + 7f + 7g.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# Three faults, and they are one task because all three are about what ASE-L
# CLAIMS versus what the simulator DID.
#
# 1. THE PER-ANALYSIS OPTIONS SHEET WAS A LIE. Issue 1441 gave the analysis
#    form a `Simulator Options…` button that opens the options sheet with the
#    scope preset -- and then writes into the same GLOBAL list. A value set
#    "for this tran" was set for the whole run. ngspice has no per-analysis
#    option scope at all: MEASURED on both binaries, `option keepopinfo` inside
#    `.control` stays set for every later analysis.
#
# 2. THERE IS NO ERROR CHANNEL FOR A MISSPELLED OPTION. RE-MEASURED 2026-09-13
#    on both binaries with a positive control in the same batch:
#      .options bogusdot=1 + option bogusopt=3   -> NOT ONE WORD
#      .options frobnicate + .op                 -> NOT ONE WORD
#      .options reltol=0.05                      -> `reltol (current) = 0.05`
#    The `Error: unknown option %s - ignored` branch is real (`inpdoopt.c:75`)
#    and neither route reaches it. A catalogue going stale against an
#    unfamiliar binary is therefore SILENT.
#
# 3. AC SENSITIVITY UNDER KLU CRASHES THE SIMULATOR. rc 139, a SIGSEGV, on
#    both binaries -- and ASE-L's answer was to REFUSE THE WHOLE RUN.
#
# ============================================================================
# ⚠ THE MEASUREMENT THAT REFUTED THE PLAN'S OWN RECIPE
# ============================================================================
# `PLAN.md` §7f writes the verification channel as
#
#       option   > <cell>_ase.effective
#       set     >> <cell>_ase.effective
#
# MEASURED 2026-09-13 on BOTH binaries, in ONE deck, with `echo … > f` and
# `print … > f` beside them so a null result could not be the measurement
# failing:
#
#       echo   > f  ->  22 bytes          set    >> f  ->  440 / 450 bytes
#       print  > f  ->  22 bytes          option >  f  ->  **0 BYTES**
#
# `com_option.c` writes its whole dump with bare `printf` -- stdout -- while
# ngspice's `>` rebinds `cp_out`, which is what `out_printf` uses and what
# makes `set`'s redirection work. So HALF the plan's channel writes nothing,
# by construction, and a deck built to that recipe would produce a plausible
# half-empty sidecar whose missing half always diffs clean. The task dump is
# taken from the run log instead, bracketed by two markers.
#
# ============================================================================
# ⚠ AND THE NUMBERS THAT RESHAPED §7e
# ============================================================================
# Counted over the shipped catalogue, live, on 2026-09-13:
#
#     247 rows        60 carry a `default`      39 restorable through `control`
#      32 analysis-scoped                       15 BOTH scoped AND restorable
#
# (Issue 1441's receipt says 65 carry a default. It is 60; 65 is the `help`
# count. See the receipt's C134.)
#
# §7e's escape hatch -- "an option with no known default is labelled global and
# offered only on the global surface" -- would therefore REMOVE 17 rows from a
# surface 1441 already shipped. What ships instead: every analysis-scoped row
# stays offered and each one SAYS whether it is `scoped` or `leaks`.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#    sections RS SP DK EF DF GT RU HK, all pure Tcl, on both arms
#    section UI drives the real widgets and self-skips without an X connection
#
# THE HISTORY:
#   92 on both arms at HEAD 02288c30 (measured; the file was last changed by 1456).
#   92 -> 94 AND RAISED, issue 1468 (receipt 44): RU12 -- rule 4 warns from 2^32
#   points up and quotes the whole count -- and RU13 -- the one estimator takes
#   a whole number of any size and still nothing else. Pure Tcl, both arms.
#
# ⚠ NO SIMULATOR IS STARTED HERE. Every ngspice number quoted above was
# measured beforehand on both binaries; the rows below assert what ASE-L does
# with those facts, which is pure Tcl.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_effective_1442.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_effective_1442.tcl

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
set scratch [test_scratch effective1442]

proc s_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc s_state {opts {ans {}}} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell rc lib $scratch]
  dict set st rundir $scratch
  dict set st simulator ngspice
  dict set st options $opts
  if {[llength $ans]} { dict set st analyses $ans }
  return $st
}
proc s_netlist {} {
  return "* rc\nv1 in 0 dc 1 ac 1\nr1 in mid 1k\nc1 mid 0 1n\n.end\n"
}
proc s_deck {st} { return [ase::backend::ngspice::render_deck $st [s_netlist]] }
## ⚠ COMMENTS ARE STRIPPED BEFORE THE LEXICAL SCAN, exactly as issue 1441's
## section HK does it. Every comment in this issue's core procs QUOTES an
## ngspice measurement on purpose -- that is what makes them evidence -- and a
## scanner that read them would redden on the documentation rather than on the
## code. What must not contain a simulator's word is the CODE.
proc s_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} { continue } ; lappend out $l }
  return [join $out "\n"]
}
proc s_greplines {text pat} {
  set out {}
  foreach l [split $text "\n"] { if {[regexp $pat $l]} { lappend out [string trim $l] } }
  return $out
}

# ⚠ THE REGISTRY IS CLEARED IN MEMORY, exactly as issues 1439 and 1441 do and
# for the same measured reason: the developer's own saved entry can carry `-n`,
# which changes what the pre-deck half of a plan reports. `ase::sim_clear`
# writes no file.
catch {ase::sim_clear}

# ============================================================================
# SECTION RS -- THE RESTORE SPELLING (§7e's mechanism)
# ============================================================================
if {[catch {

## ⚠ THE ROW THIS SECTION EXISTS FOR. `ase::opt_restore_line` used to answer
## `{}` for the whole flag class, under the comment "a valueless option restores
## by ABSENCE, and absence has no line" -- true of the FORWARD spelling, false
## of the reverse one. MEASURED on both binaries with the plan's own example:
## `option keepopinfo` then `ac` puts `op1` in $plots; `option keepopinfo=0`
## then `ac` does not.
check {RS1 a flag restores with an explicit zero, not with silence} \
  [s_ans ase::opt_restore_line ngspice keepopinfo control] {option keepopinfo=0}

check {RS2 and so does the solver flag, which is what §7g rule 1 rests on} \
  [s_ans ase::opt_restore_line ngspice klu control] {option klu=0}

check {RS3 a valued option still restores through the forward speller} \
  [s_ans ase::opt_restore_line ngspice itl4 control] {option itl4=10}

## ⚠ NON-VACUITY: the reverse table must be a DIFFERENT answer from the forward
## one for the flag class, or RS1 would pass over a table that merely echoed
## `option_spell`.
check {RS4 the forward and reverse spellings of a flag are not the same line} \
  [s_ans apply {{} {
     set f [ase::opt_line ngspice keepopinfo 1 control]
     set r [ase::opt_restore_line ngspice keepopinfo control]
     if {$f eq $r} { return same }
     return different }}] different

## ⚠ A BACKEND WITH NO HOOK GETS NO RESTORE CONTENT (D34). `option @name=@value`
## is ngspice syntax; core may not invent it.
check {RS5 a backend that declares no reverse table can restore nothing} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzrs [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_rscat \
       option_spell ::ase_t_rsspell]
     proc ::ase_t_rscat {} { return {fl {cptype optflag phase any default 0}} }
     proc ::ase_t_rsspell {} { return {control {optflag {option @name}}} }
     set r [ase::opt_restore_line zzrs fl control]
     set ::ase::backends $save
     return $r }}] {}

## ...and its non-vacuity half: the SAME backend with a reverse table answers.
check {RS5b and the same backend with one does} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzrs2 [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_rscat2 \
       option_spell ::ase_t_rsspell2 option_restore_spell ::ase_t_rsrev]
     proc ::ase_t_rscat2 {} { return {fl {cptype optflag phase any default 0}} }
     proc ::ase_t_rsspell2 {} { return {control {optflag {option @name}}} }
     proc ::ase_t_rsrev {} { return {control {optflag {putback @name @value}}} }
     set r [ase::opt_restore_line zzrs2 fl control]
     set ::ase::backends $save
     return $r }}] {putback fl 0}

check {RS6 a row with no default cannot be restored, whatever the table says} \
  [s_ans ase::opt_restore_line ngspice sqrnoise control] {}

check {RS7 and the verdict names which of the reasons it is} \
  [list [s_ans ase::opt_restorable ngspice itl4] \
        [s_ans ase::opt_restorable ngspice sqrnoise] \
        [s_ans ase::opt_restorable ngspice ramptime] \
        [s_ans ase::opt_restorable ngspice casemode] \
        [s_ans ase::opt_restorable ngspice nosuchoption]] \
  {yes {no nodefault} {no inert} {no owned} {no unknown}}

## ⚠ THE SHAPE OF THE CATALOGUE, NOT ITS EXACT SIZE. A row asserting `60` would
## redden the day somebody adds a default, which is the change this batch WANTS.
## What must hold is that a per-analysis scope can promise less than a quarter
## of the sheet -- which is the fact the surface has to say out loud.
check {RS8 fewer than half the catalogue can be restored at all} \
  [s_ans apply {{} {
     set n 0 ; set r 0
     foreach o [ase::sim_option_names ngspice] {
       incr n
       if {[ase::opt_restorable ngspice $o] eq {yes}} { incr r }
     }
     if {$r > 0 && $r * 2 < $n} { return ok }
     return "$r of $n" }}] ok

check {RS9 and some analysis-scoped rows cannot be restored, so `leaks` is reachable} \
  [s_ans apply {{} {
     set leak 0 ; set scoped 0
     foreach o [ase::sim_option_names ngspice] {
       if {![ase::opt_in_scope ngspice $o {analysis tran}] \
           && ![ase::opt_in_scope ngspice $o {analysis noise}]} { continue }
       if {[ase::opt_restorable ngspice $o] eq {yes}} { incr scoped } else { incr leak }
     }
     if {$leak > 0 && $scoped > 0} { return both }
     return "leak=$leak scoped=$scoped" }}] both

} rserr]} { check {RS0 section RS ran to the end} "RAISED:$rserr" {} }

# ============================================================================
# SECTION SP -- THE PER-ANALYSIS SCOPE (§7e)
# ============================================================================
if {[catch {

check {SP1 a stored row that names an analysis is scoped; one that does not is global} \
  [list [s_ans ase::opt_row_analysis {name itl4 value 200 analysis tran}] \
        [s_ans ase::opt_row_analysis {name itl4 value 200}]] {tran {}}

check {SP2 a scoped row is set before its analysis and put back after it} \
  [s_ans ase::opt_scope_plan ngspice \
     [s_state {{name itl4 value 200 analysis tran}}] tran] \
  {{itl4 200 scoped {option itl4=200} {option itl4=10}}}

check {SP3 a scoped row with no restore is reported as leaking, not dropped} \
  [s_ans ase::opt_scope_plan ngspice \
     [s_state {{name sqrnoise value 1 analysis noise}}] noise] \
  {{sqrnoise 1 leaks {set sqrnoise} {}}}

check {SP4 a scoped row belongs to its own analysis and to no other} \
  [list [llength [s_ans ase::opt_scope_plan ngspice \
                    [s_state {{name itl4 value 200 analysis tran}}] ac]] \
        [llength [s_ans ase::opt_scope_plan ngspice \
                    [s_state {{name itl4 value 200 analysis tran}}] tran]]] {0 1}

## ⚠ THE HALF THAT MAKES THE SCOPE REAL. A scoped row must NOT also be written
## above the analysis block -- two requests on one run, the second one standing
## for every later analysis, which is the leak the scope exists to stop.
check {SP5 the deck slot does not also write a scoped row} \
  [s_ans ase::opt_deck_plan ngspice \
     [s_state {{name itl4 value 200 analysis tran}}]] \
  {{itl4 200 scoped {analysis tran} {}}}

check {SP5b and an unscoped row of the same name still takes the deck slot} \
  [s_ans ase::opt_deck_plan ngspice [s_state {{name itl4 value 200}}]] \
  {{itl4 200 spelled options {.options itl4=200}}}

check {SP6 the restores come off in reverse order of the sets} \
  [s_ans apply {{} {
     set st [s_state {{name itl4 value 200 analysis tran}
                      {name trtol value 3 analysis tran}}]
     set l [ase::opt_scope_lines ngspice $st tran]
     return [list [dict get $l pre] [dict get $l post]] }}] \
  {{{option itl4=200} {option trtol=3}} {{option trtol=7} {option itl4=10}}}

check {SP7 the verdict the surface shows is the one the emitter acts on} \
  [list [s_ans ase::opt_analysis_verdict ngspice itl4 tran] \
        [s_ans ase::opt_analysis_verdict ngspice sqrnoise noise] \
        [s_ans ase::opt_analysis_verdict ngspice reltol tran]] \
  {scoped {leaks nodefault} global}

## ⚠ C135, AS A ROW. §7e says an unrestorable option is "offered only on the
## global surface". That would take 17 rows off a surface issue 1441 shipped.
## ⚠ THE CASE OF THE STORED ANALYSIS NAME IS NOT THE USER'S PROBLEM, AND A
## SABOTAGE IS WHY THIS ROW EXISTS. S05 -- *"match the analysis
## case-sensitively"* -- SURVIVED the first campaign, because every fixture in
## this file spells `tran` in lower case. The hole it leaves is not cosmetic: a
## hand-edited `.state` carrying `analysis TRAN` would be skipped by
## `opt_scope_plan` (the case differs) **and** skipped by `opt_deck_plan` (the
## `analysis` key is non-empty), so the option would be stored, shown in the
## sheet as scoped, and **emitted nowhere at all**. A setting that vanishes with
## nothing said is the exact defect class this whole stage exists to close.
check {SP8b a stored scope matches its analysis whatever case it was typed in} \
  [s_ans apply {{} {
     set out {}
     foreach spelling {tran TRAN Tran} {
       set st [s_state [list [list name itl4 value 200 analysis $spelling]]]
       lappend out [llength [ase::opt_scope_plan ngspice $st tran]]
     }
     return $out }}] {1 1 1}

## ...and its non-vacuity half: a scope naming a DIFFERENT analysis still does
## not match, so SP8b is not passing because the comparison was removed.
check {SP8c and a scope naming another analysis still does not match} \
  [s_ans apply {{} {
     set st [s_state {{name itl4 value 200 analysis TRAN}}]
     return [llength [ase::opt_scope_plan ngspice $st ac]] }}] 0

check {SP8 the per-analysis surface still offers a row it cannot put back} \
  [s_ans apply {{} {
     if {[lsearch -exact [ase::opt_scoped_names ngspice noise] sqrnoise] >= 0} {
       return offered
     }
     return hidden }}] offered

} sperr]} { check {SP0 section SP ran to the end} "RAISED:$sperr" {} }

# ============================================================================
# SECTION DK -- WHAT REACHES THE DECK
# ============================================================================
if {[catch {

set DKANS {{type tran enabled 1 step 1u stop 100u}}
set DKST  [s_state {{name itl4 value 200 analysis tran}} $DKANS]
set DKDECK [s_deck $DKST]

check {DK1 the set line is above the analysis and the restore below it} \
  [s_greplines $DKDECK {^(option itl4|tran )}] \
  {{option itl4=200} {tran 1u 100u} {option itl4=10}}

## ⚠ ISSUE 1419's ADJACENCY IS NOT DISTURBED. The verbatim hatch must stay
## IMMEDIATELY above its own analysis line; the option lines go above the
## checkpoint arm, which is above the hatch.
check {DK2 the verbatim hatch is still the line immediately above the analysis} \
  [s_ans apply {{} {
     set st [s_state {{name itl4 value 200 analysis tran}} \
               {{type tran enabled 1 step 1u stop 100u x {{echo HATCH}}}}]
     set lines [split [s_deck $st] "\n"]
     set i [lsearch -exact $lines {tran 1u 100u}]
     return [list [lindex $lines [expr {$i-1}]] [lindex $lines [expr {$i-2}]]] }}] \
  {{echo HATCH} {option itl4=200}}

## ⚠ A BENCH WITH NO SCOPED OPTION GETS A BYTE-IDENTICAL DECK. This is what
## keeps every committed golden where it is.
check {DK3 a bench with no scoped option has no option line inside the block} \
  [s_ans apply {{} {
     set st [s_state {{name reltol value 0.05}} {{type tran enabled 1 step 1u stop 100u}}]
     return [s_greplines [s_deck $st] {^option }] }}] {}

## --- §7f in the deck ------------------------------------------------------
## ⚠ ABOVE THE COMPLETION MARKER, NOT BELOW IT. Issue 1433's row CK17 says the
## marker is the last line inside `.control`; the first cut of this issue put
## the read-back under it and reddened CK17 by name.
check {DK4 the read-back sits above the completion marker and below everything else} \
  [s_ans apply {{} {
     set st [s_state {{name reltol value 0.05}} {{type tran enabled 1 step 1u stop 100u}}]
     set lines [split [s_deck $st] "\n"]
     set i [lsearch -exact $lines {.endc}]
     return [lrange $lines [expr {$i-4}] [expr {$i-1}]] }}] \
  [list "echo [ase::effective_marker begin]" {option} \
        "echo [ase::effective_marker end]" \
        "set >> [file join $scratch rc_ase.effective]"]

## ⚠ ONLY ONE OF THE TWO IS A REDIRECTION, AND THIS ROW IS WHY THE OTHER IS NOT.
## `option > file` writes ZERO BYTES on both binaries.
check {DK5 the task dump is NOT redirected -- it is a bare command} \
  [s_ans apply {{} {
     set st [s_state {{name reltol value 0.05}} {{type tran enabled 1 step 1u stop 100u}}]
     foreach l [split [s_deck $st] "\n"] {
       if {[regexp {^option( |$)} $l] && [string first > $l] >= 0} { return REDIRECTED }
     }
     return bare }}] bare

check {DK6 a bench that stores no option gets no read-back at all} \
  [s_ans apply {{} {
     set st [s_state {} {{type tran enabled 1 step 1u stop 100u}}]
     return [s_greplines [s_deck $st] {ASE-EFFECTIVE|^set >>}] }}] {}

## --- §7g rule 1 in the deck -----------------------------------------------
check {DK7 an AC sens under klu runs, with klu off for that analysis alone} \
  [s_ans apply {{} {
     set st [s_state {{name klu value 1}} \
               {{type tran enabled 1 step 1u stop 100u}
                {type sens enabled 1 out v(mid) mode ac sweep dec points 1 start 1k stop 10k}}]
     return [s_greplines [s_deck $st] {^(option klu|sens |tran )}] }}] \
  {{tran 1u 100u} {option klu=0} {sens v(mid) ac dec 1 1k 10k} {option klu}}

check {DK8 and a DC-mode sens under klu is left completely alone} \
  [s_ans apply {{} {
     set st [s_state {{name klu value 1}} \
               {{type sens enabled 1 out v(mid) mode dc}}]
     return [s_greplines [s_deck $st] {^option klu}] }}] {}

check {DK9 and a bench that never asked for klu gets no suppression either} \
  [s_ans apply {{} {
     set st [s_state {{name reltol value 0.05}} \
               {{type sens enabled 1 out v(mid) mode ac sweep dec points 1 start 1k stop 10k}}]
     return [s_greplines [s_deck $st] {^option }] }}] {}

## ⚠ THE STANDING NON-NEGOTIABLE, IN ITS EASY-TO-FAIL DIRECTION: nothing the
## deck contains may be unshowable in the window. §7g rule 1's two lines are
## ASE-L's choice, not the user's, and a pane that omitted them would show a
## deck running under KLU while the deck turns KLU off.
check {DK10 every line the deck writes inside the block is in the preview} \
  [s_ans apply {{} {
     set st [s_state {{name klu value 1} {name itl4 value 200 analysis tran}} \
               {{type tran enabled 1 step 1u stop 100u}
                {type sens enabled 1 out v(mid) mode ac sweep dec points 1 start 1k stop 10k}}]
     set shown {}
     foreach e [dict get [ase::opt_preview ngspice $st] control] {
       lappend shown [lindex $e 1]
     }
     set missing {}
     foreach l [s_greplines [s_deck $st] {^option }] {
       if {[lsearch -exact $shown $l] < 0} { lappend missing $l }
     }
     return $missing }}] {}

check {DK10b and the preview says WHY klu is not the user's setting for that run} \
  [s_ans apply {{} {
     set st [s_state {{name klu value 1}} \
               {{type sens enabled 1 out v(mid) mode ac sweep dec points 1 start 1k stop 10k}}]
     foreach n [dict get [ase::opt_preview ngspice $st] notes] {
       if {[lindex $n 0] eq {klu}} { return [lindex $n 1] }
     }
     return none }}] suppressed

} dkerr]} { check {DK0 section DK ran to the end} "RAISED:$dkerr" {} }

# ============================================================================
# SECTION EF -- PARSING WHAT CAME BACK (§7f)
# ============================================================================
if {[catch {

## ⚠ THE FIRST CHARACTER IS THE DOOR, AND NOBODY IN THIS BATCH KNEW IT.
## `cp_vprint` (variable.c) tags each row: ' ' a shell variable, '+' a CIRCUIT
## variable (the `.options` card or the `option` command), '*' an environment
## one. MEASURED: `.options bogusdot=1` came back `+ bogusdot 1` and
## `option bogusopt=3` came back `  bogusopt 3`, in one deck.
check {EF1 the set dump's prefix says which door the value came through} \
  [s_ans ase::effective_parse_vars "  batchmode\n+ bogusdot\t1\n  bogusopt\t3\n* curplot\top1\n"] \
  {batchmode {{} control} bogusdot {1 deck} bogusopt {3 control} curplot {op1 env}}

check {EF2 a line with no prefix character is not a row} \
  [s_ans ase::effective_parse_vars "not a var line\n\n  ok\tyes\n"] {ok {yes control}}

## The three shapes measured in the real dump, and the four that are NOT rows.
check {EF3 the task dump parses its three shapes and skips its headings} \
  [s_ans ase::effective_parse_task "******************************\n* Current simulation options *\n\nTemperatures:\ntemp = 300.150000\n\nIntegration method summary:\nIntegration Method = GEAR\nMaxOrder = 2\n\nMatrix solver:\nSparse 1.3\nreltol      (current) = 0.05\nDefault M: 1.000000\n"] \
  {temp 300.150000 {Integration Method} GEAR MaxOrder 2 reltol 0.05}

check {EF4 the bracketed region is what the markers enclose, and the LAST one wins} \
  [s_ans ase::effective_region "noise\nASE-EFFECTIVE-BEGIN\nold = 1\nASE-EFFECTIVE-END\nmore noise\nASE-EFFECTIVE-BEGIN\nnew = 2\nASE-EFFECTIVE-END\ntail\n"] \
  {{new = 2}}

check {EF5 a log with no markers yields nothing rather than the whole log} \
  [s_ans ase::effective_region "reltol = 0.05\nitl4 = 7\n"] {}

## ⚠ THE UNIT. `option` prints the temperature in KELVIN -- MEASURED on both
## binaries, `.options temp=40` reads back `313.150000`. This catalogue's own
## comment said it comes back in Celsius. Without the conversion, §7f would
## report a difference on every bench that sets a temperature.
check {EF6 the temperature comes back in the unit the user typed} \
  [s_ans ase::effective_lookup ngspice temp {temp {313.150000 task task}}] {40 task}

check {EF7 and the label map finds the settings ngspice renames} \
  [list [s_ans ase::effective_lookup ngspice method {{Integration Method} {GEAR task task}}] \
        [s_ans ase::effective_lookup ngspice maxord {MaxOrder {4 task task}}]] \
  {{GEAR task} {4 task}}

check {EF8 a backend with no lookup hook reads the name verbatim and converts nothing} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzef [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x]
     set r [ase::effective_lookup zzef temp {temp {313.150000 task task}}]
     set ::ase::backends $save
     return $r }}] {313.150000 task}

check {EF9 numbers compare as numbers and keywords case-insensitively} \
  [list [s_ans ase::effective_same 7 7.000000] [s_ans ase::effective_same GEAR gear] \
        [s_ans ase::effective_same 0.05 0.06] [s_ans ase::effective_same 1e-12 1e-12]] \
  {1 1 0 1}

check {EF10 the sidecar path sits beside the rawfile and raises without a cell} \
  [list [file tail [s_ans ase::effective_path [s_state {}]]] \
        [string match RAISED:* [s_ans ase::effective_path {}]]] {rc_ase.effective 1}

check {EF11 the read-back is armed by there being something to verify} \
  [list [s_ans ase::effective_armed ngspice [s_state {}]] \
        [s_ans ase::effective_armed ngspice [s_state {{name reltol value 0.05}}]]] {0 1}

## ⚠ THE SIDECAR IS DELETED AT THE **TOP** OF `run_deck`, WITH ITS FOUR SIBLINGS,
## AND ISSUE 1430 ALREADY LEARNED WHY. The deck APPENDS to it (`set >> path`), so
## a file left from the previous run is not truncated and the diff would compare
## THIS run's request against LAST run's effect -- a stale verification channel
## does not fail quietly, it answers wrongly. And it must not sit just before
## `eval execute`: a second run arriving mid-flight would delete the live run's
## file on its way past, which is issue 0929's symptom manufactured by the fix
## written for it.
##
## Lexical, because the claim is about POSITION and there is no way to observe a
## deletion order from outside.
##
## ⚠ THE BOUND IS THE PRE-DECK BLOCK, NOT THE LAUNCH, AND A SABOTAGE IS WHY. The
## first cut of this row asked only that the delete sit above `eval execute` --
## and the plan's own placement, *"just before `eval execute`"*, satisfies that,
## so the sabotage that moved it there **SURVIVED**. The claim that matters is
## that it sits with its four siblings, above the **first line in `run_deck` that
## may create a file** (`ase::predeck_plan`'s block, ⚖ R2's file half). Above
## that line everything only reads, so a refusal leaves nothing behind and a
## second run arriving mid-flight cannot delete the live run's artefacts on its
## way past.
## ⚠ COMMENTS ARE STRIPPED FIRST, AND THE FIRST CUT OF THIS ROW DID NOT DO IT.
## `run_deck`'s own header comment contains the phrase *"just before `eval
## execute`"* -- it is the paragraph explaining why the deletions are at the TOP
## -- so a raw `string first` found the launch at offset 583, inside the
## documentation, and reported a correctly-placed delete as *"below the
## launch"*. That is the third time in this issue that a lexical scan read a
## comment as code (see section HK), and it is worth the sentence: **a lexical
## assertion over a proc body must strip comments, because in this tree the
## comments quote the very strings the assertion is looking for.**
check {EF12 the sidecar is deleted with the other artefacts, above the launch} \
  [s_ans apply {{} {
     set b [s_nocomment [info body ::ase::run_deck]]
     set eff [string first {ase::effective_path $state} $b]
     set ckt [string first {ase::ckpt_tmp_path $state} $b]
     set wri [string first {ase::predeck_plan} $b]
     if {$eff < 0} { return {no delete at all} }
     if {$wri < 0} { return {no first-writer found -- the anchor moved} }
     if {$ckt < 0} { return {no checkpoint delete -- the anchor moved} }
     if {$eff < $ckt} { return {above its siblings} }
     if {$eff > $wri} { return {below the first line that may write} }
     return ok }}] ok

## ⚠ ITS NON-VACUITY HALF: the three anchors EF12 rests on must all be real, or
## the row would pass on a body that had lost every one of them.
check {EF12b and all three anchors EF12 measures against are present} \
  [s_ans apply {{} {
     set b [s_nocomment [info body ::ase::run_deck]]
     set out {}
     foreach a {{ase::effective_path $state} {ase::ckpt_tmp_path $state}
                {ase::predeck_plan} {ase::plotmap_path $state}} {
       lappend out [expr {[string first $a $b] >= 0 ? 1 : 0}]
     }
     return $out }}] {1 1 1 1}

} eferr]} { check {EF0 section EF ran to the end} "RAISED:$eferr" {} }

# ============================================================================
# SECTION DF -- REQUESTED VERSUS EFFECTIVE, AND THE FALSE ALARMS IT MUST NOT RAISE
# ============================================================================
if {[catch {

## The five verdicts, on one picture. Every value here was taken from a real
## run's artifacts (see the receipt), not invented.
set DFEFF [dict create \
  reltol   {0.05 task task} \
  gminsteps {1 task task} \
  klu      {{} deck vars} \
  bogusopt {3 deck vars} \
  batchmode {{} control vars} \
  history  {10000 control vars} \
  curplot  {op1 env vars}]

check {DF1 a setting that arrived as asked is `ok` and says nothing} \
  [s_ans ase::effective_diff ngspice [s_state {{name reltol value 0.05}}] $DFEFF] \
  {{reltol 0.05 0.05 ok task}}

check {DF2 a setting the simulator is using differently is `differs`} \
  [s_ans ase::effective_diff ngspice [s_state {{name gminsteps value 4}}] $DFEFF] \
  {{gminsteps 4 1 differs task}}

## ⚠ THE VERDICT THE WHOLE LEG EXISTS FOR. `.options bogusopt=3` prints NOTHING
## on either binary; the only trace is the circuit variable it became.
check {DF3 a name the catalogue does not describe, seen as a circuit variable, is `invented`} \
  [s_ans ase::effective_diff ngspice [s_state {{name bogusopt value 3}}] $DFEFF] \
  {{bogusopt 3 3 invented deck}}

## ⚠ AND THE ROW THAT KEEPS DF3 FROM FIRING TWELVE TIMES A RUN. MEASURED on the
## end-to-end deck: 13 of 24 dumped names are outside the catalogue and TWELVE
## are ngspice's own shell variables. Every one carries `control` or `env`; the
## one real stray carries `deck`.
##
## ⚠ THIS ROW USED TO ASK THE QUESTION OVER AN **EMPTY** BENCH, and it was
## therefore structurally unable to fail: `effective_diff` walks the bench's
## STORED options, so a state with none produces no rows at all and "no row said
## `invented`" was true of a diff that said nothing. Sabotage S18 -- *"any
## catalogue-unknown variable is invented, wherever it came from"* -- SURVIVED
## the first campaign against it. The fixture now STORES a name that ngspice
## owns (`batchmode`, which the catalogue does not describe and which the dump
## reports as a shell variable) beside the real stray, so the row turns on the
## origin tag rather than on there being nothing to look at.
check {DF4 a catalogue-unknown name that arrived through another door is not blamed on a typo} \
  [s_ans apply {{} {
     set st [s_state {{name batchmode value 1} {name bogusopt value 3}}]
     set out {}
     foreach r [ase::effective_diff ngspice $st $::DFEFF] {
       lappend out [list [lindex $r 0] [lindex $r 3]]
     }
     return $out }}] {{batchmode unverifiable} {bogusopt invented}}

check {DF5 an unknown name that left no trace at all is `unverifiable`, not `ok`} \
  [s_ans ase::effective_diff ngspice [s_state {{name frobnicate value 1}}] $DFEFF] \
  {{frobnicate 1 {} unverifiable {}}}

## ⚠ THE FALSE ALARM THAT WOULD GET THIS CHANNEL SWITCHED OFF. The read-back
## runs at the END of the block, by which time §7e has put a scoped option
## back. MEASURED end to end: `itl4` scoped to `tran` with value 200 reads back
## as 10, which is the restore working exactly as designed.
check {DF6 a scoped row is not compared against the end-of-run state} \
  [s_ans ase::effective_diff ngspice \
     [s_state {{name itl4 value 200 analysis tran}}] {itl4 {10 deck vars}}] \
  {{itl4 200 {} scoped {}}}

check {DF6b and without the scope the very same pair IS a difference} \
  [s_ans ase::effective_diff ngspice \
     [s_state {{name itl4 value 200}}] {itl4 {10 deck vars}}] \
  {{itl4 200 10 differs deck}}

## ⚠ A FLAG'S VARIABLE HAS NO VALUE AND ITS PRESENCE IS THE VALUE. `cp_vprint`
## prints a CP_BOOL as the bare name, so comparing 1 against {} would report
## every switched-on flag as a difference.
check {DF7 a flag that is present is not a difference} \
  [s_ans ase::effective_diff ngspice [s_state {{name klu value 1}}] $DFEFF] \
  {{klu 1 1 ok deck}}

## ⚠ `unreported` IS NOT `missing`, AND FUSING THEM WOULD BE THIS FEATURE'S
## WORST FAILURE. `option` reports the task and `set` reports the variables;
## between them they do not cover a 247-row catalogue, and a row NEITHER
## channel can speak for is one nobody asked about. Reported as "your option
## did not land" it would be a false alarm on ordinary settings -- which is how
## a verification channel gets switched off and stops catching the real one.
## `addcontrol` is a pre-deck row: it goes on the command line, where neither
## channel looks.
check {DF8 a catalogue row neither channel covers is `unreported`, never `missing`} \
  [s_ans ase::effective_diff ngspice [s_state {{name addcontrol value 1}}] $DFEFF] \
  {{addcontrol 1 {} unreported {}}}

check {DF9 a catalogue row the channels DO cover, absent from them, is `missing`} \
  [s_ans ase::effective_diff ngspice [s_state {{name trtol value 3}}] $DFEFF] \
  {{trtol 3 {} missing {}}}

## ⚠ THE POSITIVE CONTROL, SHIPPED. A diff over a picture that matched nothing
## is clean, always -- C133's vacuity defect inside a feature instead of a
## harness.
check {DF10 coverage counts how many rows the channels could speak for} \
  [list [s_ans ase::effective_coverage {{a 1 1 ok task} {b 2 {} unreported {}}}] \
        [s_ans ase::effective_coverage {{b 2 {} unreported {}}}]] {{2 1} {1 0}}

check {DF11 and a report resting on no comparison at all says so first} \
  [s_ans apply {{} {
     set l [ase::effective_report ngspice [s_state {{name frobnicate value 1}}] \
              [ase::effective_diff ngspice [s_state {{name frobnicate value 1}}] {}]]
     if {[string match {*rests on a comparison*} [lindex $l 0]]} { return warned }
     return [lindex $l 0] }}] warned

check {DF12 an all-ok run says nothing at all} \
  [s_ans ase::effective_report ngspice [s_state {{name reltol value 0.05}}] \
     [ase::effective_diff ngspice [s_state {{name reltol value 0.05}}] $DFEFF]] {}

} dferr]} { check {DF0 section DF ran to the end} "RAISED:$dferr" {} }

# ============================================================================
# SECTION GT -- §7g RULE 5, THE CAPABILITY-GATED OPTION ROW
# ============================================================================
if {[catch {

proc s_gate {gated baseline pred caps} {
  set save $::ase::backends
  set row {cptype optflag phase any}
  if {$gated ne {}} { lappend row gated $gated }
  if {$baseline ne {}} { lappend row baseline $baseline }
  if {$pred ne {}} { lappend row requires $pred }
  set ::ase_t_gtrow [list g $row]
  dict set ::ase::backends zzgt [dict create render_deck x run_cmd x \
    log_file x result_probe x raw_file x sim_options ::ase_t_gtcat \
    option_spell ::ase_t_gtspell]
  proc ::ase_t_gtcat {} { return $::ase_t_gtrow }
  proc ::ase_t_gtspell {} { return {options {optflag {.options @name}}} }
  set r [ase::opt_gate_state zzgt g $caps]
  set ::ase::backends $save
  return $r
}
proc ::ase_t_present {caps} { return present }
proc ::ase_t_absent  {caps} { return absent }
proc ::ase_t_unknown {caps} { return unknown }
proc ::ase_t_raises  {caps} { error boom }

check {GT1 an ungated row is offered without anyone asking a capability} \
  [s_ans s_gate {} {} {} {known 1}] {state ok reason ungated}

check {GT2 a gated row whose capability is present is offered} \
  [s_ans s_gate 1 0 ::ase_t_present {known 1}] {state ok reason measured}

## ⚠ §7g's own words: "listed and disabled with the reason and the door, never
## hidden" (D6).
check {GT3 a gated row whose capability is absent is `absent`, not gone} \
  [s_ans s_gate 1 0 ::ase_t_absent {known 1}] {state absent reason notpresent}

## ⚠ `baseline` DEFAULTS TO 0 AND THE DIRECTION IS STAGE 1's CORRECTION C42. An
## adapter that cannot assert a source-verified invariant must not have every
## unmeasured capability resolve to "offer it anyway".
check {GT4 unmeasured plus no baseline is absent; unmeasured plus baseline is offered} \
  [list [s_ans s_gate 1 {} ::ase_t_unknown {known 0}] \
        [s_ans s_gate 1 1 ::ase_t_unknown {known 0}]] \
  {{state absent reason unmeasured} {state ok reason baseline}}

check {GT5 a row that declares itself gated and names no predicate is a caution} \
  [s_ans s_gate 1 0 {} {known 1}] {state caution reason nopredicate}

check {GT6 and a predicate that raises is contained rather than fatal} \
  [s_ans s_gate 1 0 ::ase_t_raises {known 1}] {state caution reason requires_raised}

check {GT7 the sentence names the reason AND the door} \
  [s_ans apply {{} {
     set w [ase::opt_gate_why ngspice filetype {known 1 devices_available {}}]
     return [list [string match {*does not have this option*} $w] \
                  [string match {*above the analysis block*} $w]] }}] {1 1}

## ⚠ AND THE REAL CATALOGUE HAS EXACTLY ONE SUCH ROW, WHICH IS A MEASUREMENT.
## `filetype` is the ONLY `cp_getvar` variable in src/ciderlib -- verified by
## grep over the whole directory -- and src/ciderlib is compiled only under
## `--enable-cider` (configure.ac:1215, src/Makefile.am:15).
## ⚠ IT COMPARES `state` **AND** `reason`, AND A SABOTAGE IS WHY. This row used
## to read the `state` field alone -- and `absent/notpresent` and
## `absent/unmeasured` have the SAME state. Sabotage S30 -- *"answer a boolean;
## `unknown` is just a polite no"* -- SURVIVED the first campaign against it.
##
## ⚠ THE TWO ARE OPPOSITE ANSWERS TO THE USER. `notpresent` means *"this build of
## ngspice does not have this option"*; `unmeasured` means *"ASE-L has not found
## out"*. Fusing them turns "we never asked" into a statement about the user's
## simulator, which is the fabricated-number defect the whole capability
## vocabulary exists to prevent -- and `ase::opt_gate_why` really does say two
## different sentences, so the row has to look where the difference lives.
check {GT8 filetype is gated on CIDER and answers all three ways, reason included} \
  [s_ans apply {{} {
     return [list \
       [ase::opt_gate_state ngspice filetype \
          {known 1 devices_available {NUMD NBJT Resistor}}] \
       [ase::opt_gate_state ngspice filetype \
          {known 1 devices_available {Resistor Capacitor}}] \
       [ase::opt_gate_state ngspice filetype {known 0}]] }}] \
  {{state ok reason measured} {state absent reason notpresent} {state absent reason unmeasured}}

check {GT8b and the two absent reasons really do produce different sentences} \
  [s_ans apply {{} {
     set a [ase::opt_gate_why ngspice filetype {known 1 devices_available {Resistor}}]
     set b [ase::opt_gate_why ngspice filetype {known 0}]
     if {$a eq $b} { return same }
     if {![string match {*does not have this option*} $a]} { return "A: $a" }
     if {![string match {*has not been measured*} $b]} { return "B: $b" }
     return different }}] different

check {GT9 and no other catalogue row claims a gate nobody can evaluate} \
  [s_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       set g [ase::opt_gate_state ngspice $n {known 1 devices_available {NUMD}}]
       if {[dict get $g reason] eq {nopredicate}} { lappend bad $n }
     }
     return $bad }}] {}

} gterr]} { check {GT0 section GT ran to the end} "RAISED:$gterr" {} }

# ============================================================================
# SECTION RU -- §7g's OTHER RULES, AS PRECONDITIONS
# ============================================================================
if {[catch {

proc s_need {need st row} {
  set facts [ase::netlist_facts [s_netlist]]
  return [ase::analysis_needs ngspice $row $facts \
            [ase::state_option_map $st] $st]
}
## ⚠ `ase::analysis_precheck` ANSWERS IN PAIRS -- an analysis type, then the
## LIST of that type's findings. A reader that walked it flat would find no
## findings at all and every row here would pass over nothing, which is this
## batch's own vacuity defect. Flattened to {name tier} so a row can name both.
proc s_pre {st} {
  set out {}
  set pc [ase::analysis_precheck ngspice $st [ase::netlist_facts [s_netlist]]]
  foreach {type finds} $pc {
    foreach f $finds { lappend out [list [lindex $f 0] [lindex $f 1]] }
  }
  return $out
}

## --- rule 1 ---------------------------------------------------------------
## ⚠ THE DECISION THIS ISSUE RETURNED. It WAS a `fatal` that refused the run.
## Stage 6's 6g-1 settled the principle -- a refusal where the emitter can make
## the run correct is a FALSE refusal -- and the emitter can: MEASURED on both
## binaries, the suppressed deck is rc 0 and the sens numbers are BYTE-IDENTICAL
## to the same analysis on a deck that never asked for KLU.
check {RU1 an AC sens under klu is a caution now, not a refusal} \
  [s_ans apply {{} {
     set st [s_state {{name klu value 1}} \
       {{type sens enabled 1 out v(mid) mode ac sweep dec points 1 start 1k stop 10k}}]
     return [s_pre $st] }}] {{sens_klu caution}}

## ⚠ AND THE REFUSAL SURVIVES FOR THE CASE THE EMITTER CANNOT FIX, because the
## alternative there is the SIGSEGV. A backend with no suppression hook gets it.
check {RU2 a backend that cannot suppress still refuses} \
  [s_ans apply {{} {
     set st [s_state {{name klu value 1}}]
     set row {type sens enabled 1 out v(mid) mode ac}
     set save $::ase::backends
     set e [dict get $::ase::backends ngspice]
     dict unset e analysis_suppress
     dict set ::ase::backends ngspice $e
     set r [lindex [lindex [ase::analysis_needs ngspice $row \
              [ase::netlist_facts [s_netlist]] [ase::state_option_map $st] $st] 0] 1]
     set ::ase::backends $save
     return $r }}] fatal

## ⚠ THE SECOND HALF OF THE GUARD, AND NO FIXTURE COULD REACH IT UNTIL NOW.
## `ase::analysis_suppresses` requires BOTH that the adapter names the option AND
## that the speller can actually write the off-line. RU2 above builds the first
## failure (no hook at all); sabotage S26 -- *"trust the rule; if the adapter
## names it, suppress it"* -- SURVIVED the first campaign, because nothing built
## the second: an adapter that NAMES an option the speller cannot take back.
##
## ⚠ IT IS THE CLAUSE THAT GUARANTEES THE USER NEVER GETS A SIGSEGV. Without it,
## a `caution` would be returned on the strength of a suppression that never
## reaches the deck, and the run would crash with ASE-L having said the crash was
## handled. `zzsup`'s `klu` row carries no `default`, so `opt_restore_line`
## answers `{}` -- which is the shape 60-of-247 of the real catalogue has.
check {RU2b an adapter that names an option the speller cannot take back does not suppress it} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzsup [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_supcat \
       option_spell ::ase_t_supspell analysis_suppress ::ase_t_supname]
     proc ::ase_t_supcat {} { return {klu {cptype optflag phase any}} }
     proc ::ase_t_supspell {} { return {control {optflag {option @name}}} }
     proc ::ase_t_supname {state type row} { return {klu} }
     set named [ase::analysis_suppress zzsup {} sens {type sens mode ac}]
     set able  [ase::analysis_suppresses zzsup {} sens {type sens mode ac} klu]
     set ::ase::backends $save
     return [list $named $able] }}] {klu 0}

## ...and its non-vacuity half: the SAME synthetic adapter, with a default the
## speller can write back, DOES suppress. Without this row RU2b would pass over
## an `analysis_suppresses` that had simply been made to answer 0.
check {RU2c and the same adapter with a restorable row does suppress} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzsup2 [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_supcat2 \
       option_spell ::ase_t_supspell2 option_restore_spell ::ase_t_suprev2 \
       analysis_suppress ::ase_t_supname2]
     proc ::ase_t_supcat2 {} { return {klu {cptype optflag phase any default 0}} }
     proc ::ase_t_supspell2 {} { return {control {optflag {option @name}}} }
     proc ::ase_t_suprev2 {} { return {control {optflag {option @name=@value}}} }
     proc ::ase_t_supname2 {state type row} { return {klu} }
     set able [ase::analysis_suppresses zzsup2 {} sens {type sens mode ac} klu]
     set ::ase::backends $save
     return $able }}] 1

check {RU3 and the DC mode is untouched in both worlds} \
  [s_ans apply {{} {
     set st [s_state {{name klu value 1}} {{type sens enabled 1 out v(mid) mode dc}}]
     return [s_pre $st] }}] {}

check {RU4 the suppression predicate is the adapter's, and it names one option} \
  [list [s_ans ase::analysis_suppress ngspice [s_state {}] sens \
           {type sens mode ac}] \
        [s_ans ase::analysis_suppress ngspice [s_state {}] sens \
           {type sens mode dc}] \
        [s_ans ase::analysis_suppress ngspice [s_state {}] tran \
           {type tran}]] {klu {} {}}

## ⚠ §7g RULE 2 IS ALREADY SHIPPED AND IS NOT RE-IMPLEMENTED HERE. It is 6g-1,
## issue 1434: `render_deck` forces a `.save all` leader and `vecsaves` is a
## `caution` saying the narrowing was overridden. This row CONFIRMS it rather
## than duplicating it, so a regression in 1434 reddens here too.
check {RU5 rule 2 is still the caution issue 1434 shipped, not a refusal} \
  [s_ans apply {{} {
     set st [s_state {} {{type noise enabled 1 out v(mid) insrc v1 sweep dec points 1 start 1k stop 10k}}]
     dict set st outputs {{expr v(mid) save 1}}
     foreach r [s_pre $st] { if {[lindex $r 0] eq {vecsaves}} { return [lindex $r 1] } }
     return none }}] caution

## --- rule 3 ---------------------------------------------------------------
## MEASURED on both binaries with `lin 3` and `dec 2` beside it as positive
## controls: ac lin 2 -> length(frequency) = 1; lin 3 -> 3; dec 2 -> 3.
check {RU6 a linear sweep of two points warns and names the fix} \
  [s_ans apply {{} {
     set st [s_state {} {{type ac enabled 1 sweep lin points 2 start 1k stop 11k}}]
     foreach r [s_pre $st] { if {[lindex $r 0] eq {lin_points}} { return [lindex $r 1] } }
     return none }}] caution

## ⚠ D47: REFUSING REMOVES A NUMBER THE USER TYPED INTO A FORM. This row is what
## stops the next crew promoting it.
check {RU6b and it never refuses} \
  [s_ans apply {{} {
     set st [s_state {} {{type ac enabled 1 sweep lin points 2 start 1k stop 11k}}]
     return [ase::precheck_worst [ase::analysis_precheck ngspice $st \
               [ase::netlist_facts [s_netlist]]]] }}] caution

check {RU7 three points, one point and a dec sweep of two are all silent} \
  [s_ans apply {{} {
     set out {}
     foreach spec {{lin 3} {lin 1} {dec 2} {oct 2}} {
       set st [s_state {} [list [list type ac enabled 1 sweep [lindex $spec 0] \
                 points [lindex $spec 1] start 1k stop 11k]]]
       set hit none
       foreach r [s_pre $st] { if {[lindex $r 0] eq {lin_points}} { set hit fired } }
       lappend out $hit
     }
     return $out }}] {none none none none}

check {RU8 and the rule reaches every analysis that has a linear sweep} \
  [s_ans apply {{} {
     set out {}
     foreach t {ac noise disto} {
       set e [ase::analysis_entry ngspice $t]
       lappend out [expr {[lsearch -exact [dict get $e needs] lin_points] >= 0 ? yes : no}]
     }
     return $out }}] {yes yes yes}

## --- rule 4 ---------------------------------------------------------------
## ⚠ THE REASON `PLAN.md` GIVES DOES NOT APPLY TO THE DECK ASE-L WRITES. D4 is
## `-r`'s 8-character `No. Points:` field (outitf.c:1011/1190); ASE-L writes
## with the `write` COMMAND, rawfile.c:209, which has no reservation at all --
## VERIFIED on both binaries, a 1008-point write gives `No. Points: 1008`. The
## rule ships with the reason that IS true: the size.
check {RU9 an enormous transient warns about its size and does not refuse} \
  [s_ans apply {{} {
     set st [s_state {} {{type tran enabled 1 step 1n stop 100m}}]
     foreach r [s_pre $st] { if {[lindex $r 0] eq {points_max}} { return [lindex $r 1] } }
     return none }}] caution

check {RU10 an ordinary transient says nothing} \
  [s_ans apply {{} {
     set st [s_state {} {{type tran enabled 1 step 1u stop 100u}}]
     foreach r [s_pre $st] { if {[lindex $r 0] eq {points_max}} { return fired } }
     return none }}] none

check {RU11 the size rule uses the ONE point estimator the checkpointer uses} \
  [list [s_ans ase::analysis_point_estimate ngspice tran {type tran step 1u stop 100u}] \
        [s_ans ase::analysis_point_estimate ngspice ac {type ac sweep lin points 2}]] \
  {100 {}}

## ⚠ ISSUE 1468: THE RULE WAS SILENT FROM 2^32 POINTS UP -- the runs it exists
## for. The estimator took the hook's answer through `string is integer -strict`,
## which on Tcl 8.6.17 is 1 for 4294967295 and 0 for 4294967296, so `tran 1n 5`
## (5e9 points) and `tran 1f 10` (1e16) read as no estimate and said nothing
## while `tran 1n 3` warned. The first term is the control one point under the
## boundary, and every sentence must carry the WHOLE count.
proc ru12_pm {step stop} {
  set st [s_state {} [list [list type tran enabled 1 step $step stop $stop]]]
  set pc [ase::analysis_precheck ngspice $st [ase::netlist_facts [s_netlist]]]
  foreach {type finds} $pc {
    foreach f $finds {
      if {[lindex $f 0] ne {points_max}} { continue }
      return [list [lindex $f 1] [lindex [regexp -inline {about [0-9]+ points} [lindex $f 2]] 0]]
    }
  }
  return none
}
check {RU12 a transient asking 2^32 points or more still warns, and quotes the whole\
 count} \
  [s_ans apply {{} {
     list [ru12_pm 1n 4.294967295] [ru12_pm 1n 4.294967296] [ru12_pm 1n 5] [ru12_pm 1f 10] }}] \
  {{caution {about 4294967295 points}} {caution {about 4294967296 points}}\
 {caution {about 5000000000 points}} {caution {about 10000000000000000 points}}}

## ⚠ AND THE FIX WIDENS THE RANGE, NOT THE TYPE. A fixture backend whose `tran`
## is ngspice's own entry with the `salvage` points hook swapped for one that
## hands back the row's `ans`, so each spelling reaches the ONE estimator as it
## is. A whole number of any size is an estimate -- 2^32, 5e9 and 2^64, the last
## of which is why the test is `entier` and not `wideinteger` (0 from 2^64 on
## this Tcl, which would move the silence rather than remove it). A float
## spelling, a fraction, a word and the empty string are not, and a negative is
## a number -- all as before. The last term uses the OLD test as its oracle over
## spellings under 2^32, accepted and refused alike: it must find no difference.
proc ru13_types {} {
  set e [dict get [ase::analysis_types ngspice] tran]
  dict set e salvage points ::ru13_hook
  return [dict create tran $e]
}
proc ru13_hook {row {state {}}} { return [dict get $row ans] }
proc ru13_est {ans} {
  set save $::ase::backends
  ase::register_backend zz1468 [dict create render_deck x run_cmd x log_file x \
    result_probe x raw_file x analysis_types ru13_types]
  ase::analysis_cache_clear zz1468
  set r [s_ans ase::analysis_point_estimate zz1468 tran \
           [list type tran enabled 1 ans $ans] {}]
  set ::ase::backends $save
  ase::analysis_cache_clear zz1468
  return $r
}
## ⚠ `if`, NOT `expr {… ? $v : {}}`, FOR THE ORACLE: `expr` hands back the
## NUMBER, so ` 7` came back `7` and `0x10` came back `16`, and the first cut of
## this row reported both as differences on the unfixed tree. The estimator
## returns the hook's own string, and so must the oracle.
set RU13PAR {}
foreach v [list 100 4294967295 -1 -4294967295 { 7} 0x10 5e9 3.5 abc {} 08] {
  if {[string is integer -strict $v]} { set old $v } else { set old {} }
  if {[ru13_est $v] ne $old} { lappend RU13PAR $v }
}
check {RU13 the estimator takes a whole number of any size and still nothing else --\
 under 2^32 every spelling answers what the old test answered} \
  [list [ru13_est 100] [ru13_est 4294967296] [ru13_est 5000000000] \
        [ru13_est 18446744073709551616] [ru13_est -5000000000] \
        [ru13_est 5e9] [ru13_est 5000000000.0] [ru13_est 3.5] [ru13_est abc] \
        [ru13_est {}] $RU13PAR] \
  {100 4294967296 5000000000 18446744073709551616 -5000000000 {} {} {} {} {} {}}

} ruerr]} { check {RU0 section RU ran to the end} "RAISED:$ruerr" {} }

# ============================================================================
# SECTION HK -- THE SCHEMA/CONTENT LINE (D34-D37)
# ============================================================================
if {[catch {

## ⚠ LEXICAL, AND IT IS THE ONLY CHECK THAT CATCHES AN NGSPICE NOUN DRIFTING
## INTO CORE. Every proc this issue added to `ase::` is scanned for the
## simulator's own words.
check {HK1 no core proc this issue added spells an ngspice word} \
  [s_ans apply {{} {
     set bad {}
     foreach p {ase::opt_restore_spell ase::opt_restore_template ase::opt_restorable
                ase::opt_row_analysis ase::opt_scope_plan ase::opt_scope_lines
                ase::opt_analysis_verdict ase::opt_scoped_names ase::opt_gate_state
                ase::opt_gate_why ase::opt_door_phrase ase::analysis_suppress
                ase::analysis_suppresses ase::analysis_suppress_lines
                ase::effective_path ase::effective_marker ase::effective_region
                ase::effective_parse_vars ase::effective_parse_task
                ase::effective_read ase::effective_lookup ase::effective_same
                ase::effective_diff ase::effective_coverage ase::effective_report
                ase::effective_armed ase::opt_door_reported ase::opt_leak_why
                ase::preview_analysis_types ase::analysis_point_estimate} {
       if {![llength [info commands ::$p]]} { lappend bad "$p MISSING" ; continue }
       set b [s_nocomment [info body ::$p]]
       ## ⚠ THE TOKENS ARE TEMPLATES AND LITERALS, NOT THE ENGLISH WORD. A bare
       ## `option ` in this list reddens on the SENTENCES -- "this simulator's
       ## catalogue", "any stored option on this run" -- because `option` is
       ## ASE-L's OWN vocabulary too: the sheet is called Options and every
       ## reader here is `ase::opt_*`. What may not be in core is the SPELLING,
       ## so the tokens are the two shapes a spelling takes: a template slot
       ## (`option @name=@value`) and a quoted literal (`"option klu=0"`).
       foreach w {.options .control ngspice spiceinit sqrnoise keepopinfo
                  reltol savecurrents CP_BOOL casemode {option @} {set @name}
                  {"option } {"set }} {
         if {[string first $w $b] >= 0} { lappend bad "$p:$w" }
       }
     }
     return $bad }}] {}

## ⚠ ITS NON-VACUITY HALF, AND IT USES **HK1's OWN TOKEN LIST**. A second,
## looser list here would prove that SOME scanner works and say nothing about
## the one HK1 runs -- which is this batch's own vacuity defect wearing a
## test's clothes. Each of the three adapter procs must be caught by the very
## tokens HK1 clears core of.
check {HK2 and HK1's exact token list catches all three adapter procs} \
  [s_ans apply {{} {
     set toks {.options .control ngspice spiceinit sqrnoise keepopinfo
               reltol savecurrents CP_BOOL casemode {option @} {set @name}
               {"option } {"set }}
     set missed {}
     foreach p {ase::backend::ngspice::option_restore_spell
                ase::backend::ngspice::effective_emit
                ase::backend::ngspice::analysis_suppress} {
       set b [s_nocomment [info body ::$p]]
       set hit 0
       foreach w $toks { if {[string first $w $b] >= 0} { set hit 1 } }
       if {!$hit} { lappend missed $p }
     }
     return $missed }}] {}

## ⚠ AND THE ONE ADAPTER PROC A BODY SCANNER CANNOT SEE, WHICH IS WORTH A ROW
## OF ITS OWN. `effective_lookup`'s ngspice content is not in its body at all --
## it is the `effective_labels` VARIABLE (`method` -> `Integration Method`,
## `maxord` -> `MaxOrder`) plus the Kelvin conversion. HK2 above would pass it
## only by accident, so it is asserted where it lives: in the adapter's
## namespace, and nowhere in core's.
check {HK2b the label map is the adapter's variable and core declares none} \
  [s_ans apply {{} {
     set adapter [info exists ::ase::backend::ngspice::effective_labels]
     set core 0
     foreach v [info vars ::ase::*] {
       if {[string match *effective_labels* $v]} { set core 1 }
     }
     return [list $adapter $core] }}] {1 0}

check {HK3 both new hooks are registered, and both are optional} \
  [s_ans apply {{} {
     set e [dict get $::ase::backends ngspice]
     set out {}
     foreach h {option_restore_spell effective_emit effective_lookup analysis_suppress} {
       lappend out [expr {[dict exists $e $h] ? 1 : 0}]
     }
     return $out }}] {1 1 1 1}

} hkerr]} { check {HK0 section HK ran to the end} "RAISED:$hkerr" {} }

# ============================================================================
# SECTION UI -- THE SURFACE (display arm only)
# ============================================================================
if {[catch {

## ⚠ THIS SECTION NEEDS NO X CONNECTION AND DELIBERATELY DOES NOT ASK FOR ONE.
## Every row below drives a PURE proc -- `optsheet_stamp` reads an array,
## `optsheet_where` reads the catalogue and the state -- and neither creates a
## widget. A `package require Tk` guard here would have made the section
## self-skip on an arm where it runs perfectly well, which is a check count
## that looks like coverage and is not. The guard that IS right is whether
## `src/ase_window.tcl` was sourced at all.
if {![llength [info commands ase::ui::optsheet_stamp]]} {
  puts "skip: section UI needs src/ase_window.tcl"
} else {

## ⚠ §7e's SURFACE FIX. The per-analysis sheet used to write into the global
## list, so a value set "for this tran" was set for the whole run.
check {UI1 the per-analysis sheet stamps the analysis onto a new row} \
  [s_ans apply {{} {
     set ::ase::ui::optsheet(k,scope) tran
     return [ase::ui::optsheet_stamp k] }}] {analysis tran}

check {UI2 and the global sheet stamps nothing at all} \
  [s_ans apply {{} {
     set ::ase::ui::optsheet(k,scope) [ase::ui::optsheet_global_label]
     return [ase::ui::optsheet_stamp k] }}] {}

## ⚠ THE `Written` COLUMN HAS TO AGREE WITH THE DECK, or the sheet and the
## emitter say different things about one row.
## ⚠ THE NEW-ROW GUARD, AND IT COULD NOT BE REACHED UNTIL THE API MOVED.
## `listdlg_ok` runs off a live dialog's entry widgets, so no headless row can
## drive it -- and sabotage S39, *"stamp every row, new or edited"*, SURVIVED the
## first campaign for exactly that reason. The decision now lives in
## `listdlg_stamp_pairs`, which takes the index, so a row can ask it directly.
##
## ⚠ THE HOLE IT LEAVES IS REAL. Editing an existing GLOBAL row while the tran
## sheet happens to be open would silently re-scope it to tran: the user opened
## the sheet to change a number and the option would stop applying to the rest of
## the run, with nothing said. Un-scoping is a Delete and a re-Add, which is
## visible.
check {UI2b a new row is stamped and an edited row is left alone} \
  [s_ans apply {{} {
     set ::ase::ui::optsheet(k,scope) tran
     set cfg [dict create stamp ase::ui::optsheet_stamp]
     return [list [ase::ui::listdlg_stamp_pairs $cfg k -1] \
                  [ase::ui::listdlg_stamp_pairs $cfg k 0] \
                  [ase::ui::listdlg_stamp_pairs $cfg k 3]] }}] \
  {{analysis tran} {} {}}

check {UI2c and a dialog whose config declares no stamp gets none} \
  [s_ans apply {{} {
     set ::ase::ui::optsheet(k,scope) tran
     return [ase::ui::listdlg_stamp_pairs [dict create win models] k -1] }}] {}

check {UI3 a scoped stored row says it is written inside that analysis's block} \
  [s_ans ase::ui::optsheet_where ngspice itl4 \
     [s_state {{name itl4 value 200 analysis tran}}]] {TRAN BLOCK}

check {UI3b and the same option unscoped says DECK} \
  [s_ans ase::ui::optsheet_where ngspice itl4 [s_state {{name itl4 value 200}}]] {DECK}

}

} uierr]} { check {UI0 section UI ran to the end} "RAISED:$uierr" {} }

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456). `tests/banner_rule.tcl`'s `banner_complete`
# requires a WHOLE-LINE `OVERALL: ok`, and `run_regression.tcl` counts a case with
# no banner as a HARNESS failure however green its own checks are. This suite is in
# T1's case list, so without this line it was a standing red from the day it joined.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
# AND AN EXPLICIT EXIT CODE. Without one a failing run still exited rc 0: measured
# 2026-09-15 by the driver, `RESULT: 2 FAILED (92 passed)` at rc 0 while sabotaging
# issue 1468. T1 counts it anyway through the banner and the FAIL lines, but any
# reader of the exit code alone -- a bespoke loop, `timeout`'s caller -- scored a
# red suite green. The established suites end this way.
exit [expr {$fail ? 1 : 0}]
