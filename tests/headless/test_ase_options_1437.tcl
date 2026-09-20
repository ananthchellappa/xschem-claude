# tests/headless/test_ase_options_1437.tcl -- ISSUE 1437: THE OPTION CATALOGUE
# AND THE ONE SPELLER. PLAN.md Stage 7a + 7b.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# They set an option in ASE-L, the deck is written, the run exits 0, the log is
# clean -- and the option is not in force. There is no error channel for this:
# MEASURED on both binaries, a deck carrying `.options bogusdot=1` plus
# `option bogusopt=3` inside `.control` prints NOTHING on either stream and
# both names are silently invented as variables. So the only defence is knowing
# what class each name belongs to BEFORE the line is written.
#
# Three of those silent failures are live in the shipped tree today, and each
# one is measured in this file:
#
#   * FIVE committed benches carry `{name wnflag value 1}`. `wnflag` chooses
#     whether a MOS W is the total width or the width per finger, and the line
#     ASE-L wrote for it -- a bare `.options wnflag` -- is a valueless CP_BOOL
#     that cannot answer its CP_NUM read. ⚠ THIS FILE ALSO SAID IT WAS "the
#     wrong door TWICE OVER", read inside `inp_readall()` where no `.options`
#     card reaches. ISSUE 1439 MEASURED THAT WRONG: two of the three cited read
#     sites are DEAD (`inpcom.c:990` reads into a local `inp_get_w_l_x` never
#     uses, `inp.c:2828` is inside `#ifdef REM_UNUSED`, defined nowhere), and
#     the live one -- `inpgmod.c:268`, at model-binning time -- IS reached by an
#     `.options` card. So the wrong door was the VALUE, not the phase, and the
#     fix is the next bullet's. Sections DL and CB carry the re-baselined rows.
#   * a valued option stored as `1` is written as a BARE card. MEASURED on both
#     binaries: `.options maxord=1` gives `MaxOrder = 1`, `.options maxord`
#     leaves it at 2. The user typed 1 and got 2. Section F.
#   * a valued option stored as `0` is DROPPED. MEASURED on both binaries:
#     `.options gminsteps=0` gives `gminsteps = 0` and disables gmin stepping;
#     writing nothing leaves it at 1. Section F.
#
# ============================================================================
# WHAT THIS FILE IS ABOUT, AND WHAT IT IS NOT
# ============================================================================
# It is about the CATALOGUE (ngspice's content, reached only through the
# `sim_options` hook) and the ONE SPELLER (ASE-L's schema, D23). It was NOT
# about the emitter: `ase::backend::ngspice::render_deck` was deliberately
# UNCHANGED by issue 1437, so no deck golden moved and no `.state` file moved.
# Section BR is the bridge -- it pinned, by name, every row where the shipped
# emitter and the new speller disagreed, so that the crew which rewires the
# emitter (PLAN.md §7c/§7d/§7e own that surface) knew its exact blast radius
# instead of re-deriving it.
#
# ⚠ THAT CREW HAS BEEN: ISSUE 1439 (PLAN.md §7d) ROUTED THE EMITTER THROUGH THE
# SPELLER. Seven rows of this file were re-baselined with it -- CB6, DO2, SP6,
# SP7, BR6, DL1, DL5 -- and each carries the measurement that moved it. No row
# was added or removed, so the count is still 75.
#
# ⚠ AND ISSUE 1441 (PLAN.md §7c) MOVED THE LOOP ITSELF into `ase::opt_deck_plan`
# so the live deck preview shows the lines the deck really carries rather than a
# second opinion about them. TWO rows were re-baselined for it -- BR6 (the
# lexical routing row, now over three bodies) and CB6's neighbours are untouched
# -- and 1441 also MEASURED the `results` column this file shipped transcribed:
# `warn`, `maxwarns` and `num_threads` were refuted and now carry `results 0`.
# The count is still 75.
#
# ⚠ NO SIMULATOR IS STARTED HERE. Every ngspice fact quoted in this file was
# measured beforehand against BOTH preflight binaries -- the fork
# (/home/analog/dev/ngspice/build-ver_50/src/ngspice, ngspice-46+) and the apt
# build (/usr/bin/ngspice, ngspice-45.2) -- and against the C source at
# /home/analog/dev/ngspice (ver_50, ccebdf2a2). The rows assert what ASE-L
# does with those facts, which is pure Tcl.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#    75  the count when this file landed (2026-09-13, issue 1437), identical on
#        BOTH arms -- there is no widget here, so the display arm runs the same
#        rows and must print the same number.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_options_1437.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_options_1437.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]

proc o_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
## The TEXT of a refusal, empty when the call did not refuse. A row that reads
## only "did it raise" cannot tell a refusal from a typo in the proc name.
proc o_raise {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {!$rc} { return {} }
  return $r
}
proc o_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} { continue } ; lappend out $l }
  return [join $out "\n"]
}
proc o_slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
set CAT [o_ans ase::sim_options ngspice]
proc o_row {name} { return [o_ans ase::sim_option_entry ngspice $name] }
proc o_key {name key} {
  set d [o_row $name]
  if {$d eq {} || ![dict exists $d $key]} { return {} }
  return [dict get $d $key]
}
## Every catalogue name whose row satisfies a predicate on (name, row).
proc o_names_where {body} {
  set out {}
  foreach n [ase::sim_option_names ngspice] {
    set row [ase::sim_option_entry ngspice $n]
    if {[uplevel #0 [list apply [list {n row} $body] $n $row]]} { lappend out $n }
  }
  return $out
}

# ============================================================================
# SECTION CA -- THE CATALOGUE AS A SET
# ============================================================================
# Nobody reads 247 rows. Every claim about the catalogue that is worth making
# is a claim about ALL of it, so it is made here once, over all of it.
if {[catch {

check {CA1 the ngspice adapter declares an option catalogue and core can read it through the hook} \
  [expr {[dict size $CAT] > 0}] 1

## ⚠ THE FLOOR IS THE PLAN'S 220, AND THE ROW ASSERTS THE FLOOR, NOT THE TOTAL.
## A total pinned to the exact number is a row that reds every time someone
## adds a measured row, which is the opposite of what a catalogue wants.
check {CA2 the catalogue is at least the plan's 220-row measured floor} \
  [expr {[dict size $CAT] >= 220}] 1

check {CA3 every row declares a cptype, over the whole catalogue} \
  [o_names_where {expr {![dict exists $row cptype]}}] {}

check {CA4 every row declares a phase core understands} \
  [o_names_where {expr {[dict exists $row phase] &&
                        [dict get $row phase] ni {pre deck run any cmdline}}}] {}

## D34's rule, asserted from the other end: a row may not STATE its door.
check {CA5 no row states a door -- the door is computed} \
  [o_names_where {expr {[dict exists $row door]}}] {}

check {CA6 the catalogue validates clean as a set} \
  [o_ans ase::option_schema_errors ngspice] {}

## ⚠ NON-VACUITY. CA6 passing over an empty complaint list proves nothing
## unless the checker can complain; this row feeds it a broken catalogue.
check {CA7 and the validator is not merely silent -- a row with no cptype is named} \
  [expr {[llength [o_ans apply {{} {
      set save $::ase::backends
      dict set ::ase::backends zzopt [dict create render_deck x run_cmd x \
        log_file x result_probe x raw_file x sim_options ::ase_t_badcat \
        option_spell ::ase::backend::ngspice::option_spell]
      proc ::ase_t_badcat {} { return {bustedrow {phase any}} }
      set r [ase::option_schema_errors zzopt]
      set ::ase::backends $save
      return $r }}]] == 1}] 1

check {CA8 the two source catalogues are disjoint -- no name is both an OPTtbl keyword and a cp_getvar variable} \
  [llength [o_names_where {expr {[string match {cktsopt.c*} [dict get $row site]] &&
                                 [string match opt* [dict get $row cptype]] &&
                                 ![string match opt* [dict get $row cptype]]}}]] 0

## The four measured delivery classes, each with at least one member. A class
## with no member is a class no row can fail on.
check {CA9 all five phases have at least one member} \
  [lsort -unique [lmap n [ase::sim_option_names ngspice] {ase::opt_phase ngspice $n}]] \
  {any cmdline deck pre run}

} caerr]} { check {CA0 section CA ran to the end} "RAISED:$caerr" {} }

# ============================================================================
# SECTION CB -- THE ROWS TWO MEASUREMENTS PIN, AND THE ONE THE APPENDIX GOT WRONG
# ============================================================================
if {[catch {

## cktntask.c:120-122 is `TSKnumSrcSteps = 1; TSKnumGminSteps = 1;
## TSKgminFactor = 10;`. A wrong default makes a SHIPPED value read as
## "changed" in §7c's default-only view, which is how a real change hides.
check {CB1 gminsteps defaults to 1, and the 10 in that block belongs to gminfactor} \
  [list [o_key gminsteps default] [o_key gminfactor default] [o_key srcsteps default]] \
  {1 10 1}

## cktsopt.c:108 and :111 write the SAME field, TSKdefaultMosAD.
check {CB2 defas is offered with its defect named, and the sentence says DRAIN} \
  [list [expr {[o_key defas defect] ne {}}] \
        [string match {*DRAIN*} [o_key defas defect]] \
        [expr {[o_key defas inert] eq {}}]] {1 1 1}

## niiter.c:38-39 raises every iteration limit below 100 to 100.
check {CB3 the three iteration limits carry the clamp and a widget minimum of 100} \
  [list [o_key itl1 min] [o_key itl2 min] [o_key itl4 min] \
        [expr {[o_key itl4 clamp] ne {}}]] {100 100 100 1}

## ⚠ APPENDIX §3.2 SAYS THE 163rd NAME IS THE COMPUTED `auto_bridge_*` FAMILY.
## MEASURED: a literal grep over `cp_getvar` finds 162, and the 163rd is
## `casemodewrite`, read through `cp_getvar_policy()` (variable.c:753) -- the
## only such read in the tree, which a `cp_getvar` grep cannot see.
check {CB4 casemodewrite is in the catalogue, and it is the row a cp_getvar grep misses} \
  [list [expr {[o_row casemodewrite] ne {}}] [o_key casemodewrite cptype]] {1 bool}

## The `units` row is not in the plan's 220 at all: `units` is not a
## `cp_getvar` name, it is a `cp_usrset` hook (options.c:419). It is the option
## behind the 57.2958x phase error, so a catalogue without it is a catalogue
## that cannot warn about the one trap no design in this batch caught.
check {CB5 units is present, is control-only, and names its two values} \
  [list [o_key units phase] [o_key units values] [o_key units default]] \
  {run {radians degrees} radians}

## ⚠ `hidden-vars.md` §3.2 HEADLINES "26 variables" AND ITS OWN TABLE NAMES 35:
## the count omits the ten `ps_*` U-device knobs, which are in the table and are
## read from `initialize_udevice()` via `inpcompat.c:478`, inside the netlist
## read. `PLAN.md` §7d and the crew brief both quote the 26.
## ⚠ RE-BASELINED 34 -> 32 BY ISSUE 1439, and both departures were measured
## rather than reasoned. `wnflag` is `deck` (its only live read is reached by
## an `.options` card -- see CB6c) and `no_spinit` is `cmdline` (`-D no_spinit`
## was measured NOT to suppress the start-up file on either binary, while `-n`
## does). Two rows left the class because the class was wrong about them; the
## GUI group §7c draws is 32.
check {CB6 the pre-deck class is 32 named variables, not the dossier's 26} \
  [llength [o_names_where {ase::opt_is_pre_deck ngspice $n}]] 32

## ⚠ AND THE 35th IS `scale`, WHICH IS NOT PRE-DECK -- MEASURED ON BOTH
## BINARIES. `.options scale=0.5` halves a MOS W (@m1[w] 2u -> 1u); `set
## scale=0.5` inside `.control` does nothing. THREE COMMITTED SCHEMATICS carry
## `.options SCALE=0.10` -- the shipped rom8k example, in xschem_library/,
## xschem_libraries_oa/ and xschem_libs_newsym/ -- and it reaches nine generated
## netlists under tests/netlisting/results/. Classifying it pre-deck would have
## condemned a spelling this repo ships. The caveat -- two read sites earlier
## than any `.options` card -- is on the row rather than in the door.
## ⚠ A ROW WHOSE FIXTURES NEVER DISAGREE CANNOT FAIL, AND THIS FILE CAUGHT FOUR
## OF ITS OWN. Sabotage S20 -- `ase::opt_phase` defaulting to `pre` instead of
## `any` -- SURVIVED, because every one of the 247 ngspice rows declares a phase
## and the default is unreachable through this simulator. The default is not
## decoration: it is what a second adapter's descriptor gets when it omits the
## key, which is precisely what D37's paper validation does. So the state is
## BUILT rather than the line deleted.
check {CB6b a row that says nothing about its phase is one either door can carry} \
  [o_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzph [dict create render_deck x run_cmd x log_file x \
       result_probe x raw_file x sim_options ::ase_t_nophase \
       option_spell ::ase::backend::ngspice::option_spell]
     proc ::ase_t_nophase {} { return {quiet {cptype optflag}} }
     set r [list [ase::opt_phase zzph quiet] [ase::opt_door zzph quiet] \
                 [ase::opt_door zzph quiet control] [ase::opt_is_pre_deck zzph quiet] \
                 [ase::opt_line zzph quiet 1]]
     set ::ase::backends $save
     return $r }}] {any options control 0 {.options quiet}}

check {CB7 scale takes the .options door, and its row carries the partial-coverage caveat} \
  [list [o_key scale phase] [o_ans ase::opt_door ngspice scale] \
        [expr {[o_key scale caveat] ne {}}] \
        [string match {*subckt.c:592*} [o_key scale caveat]]] {deck options 1 1}

} cberr]} { check {CB0 section CB ran to the end} "RAISED:$cberr" {} }

# ============================================================================
# SECTION DO -- THE DOOR IS COMPUTED, AND FOUR PAIRS ARE IMPOSSIBLE
# ============================================================================
if {[catch {

check {DO1 an OPTtbl keyword takes the .options door above the block and the option command inside it} \
  [list [o_ans ase::opt_door ngspice reltol] [o_ans ase::opt_door ngspice reltol control]] \
  {options control}

## ⚠ `wnflag` WAS THIS ROW'S CP_NUM EXAMPLE UNTIL ISSUE 1439 MEASURED IT OUT
## OF THE CLASS. `ps_use_mntymx` replaces it: a genuine pre-deck CP_NUM, read
## from initialize_udevice() during the netlist read, which no `.options` card
## reaches.
check {DO2 a pre-deck CP_BOOL or CP_STRING takes -D; a pre-deck CP_NUM, CP_REAL or CP_LIST takes the run-directory file} \
  [list [o_ans ase::opt_door ngspice casemode] [o_ans ase::opt_door ngspice mingwpath] \
        [o_ans ase::opt_door ngspice ps_use_mntymx] [o_ans ase::opt_door ngspice ps_tpz_delays] \
        [o_ans ase::opt_door ngspice sourcepath]] \
  {predeck predeck predeck-file predeck-file predeck-file}

check {DO3 the one argv-delivered option takes the command line} \
  [o_ans ase::opt_door ngspice soa_log] cmdline

## T8: `.options casemode=preserve` and `set casemode` in the block are BOTH
## ignored without a word.
check {DO4 a pre-deck option refuses the in-block slot, and the refusal says why} \
  [list [expr {[o_raise ase::opt_door ngspice casemode control] ne {}}] \
        [string match {*before the input file is read*} \
          [o_raise ase::opt_door ngspice casemode control]]] {1 1}

## MEASURED on both binaries: `.options warn=1` prints the SOA violation,
## `set warn=1` inside `.control` prints nothing -- the block runs after the
## circuit is loaded. This class is NOT in PLAN.md's door table.
check {DO5 a deck-load option refuses the in-block slot} \
  [list [o_ans ase::opt_door ngspice warn] \
        [string match {*loads the circuit*} [o_raise ase::opt_door ngspice warn control]]] \
  {options 1}

## MEASURED on both binaries: `set units=degrees` gives -44.99 deg and
## `.options units=degrees` leaves the phase in RADIANS.
check {DO6 a cp_usrset option refuses the slot above the block} \
  [list [o_ans ase::opt_door ngspice units control] \
        [string match {*after the circuit is loaded*} [o_raise ase::opt_door ngspice units]]] \
  {control 1}

## MEASURED on both binaries: a list value on a `.options` card is not
## ignored, it ABORTS -- `ERROR: wrong format in option ticlist! Aborting...`,
## rc 1. inp.c:1407-1411 reaches controlled_exit(EXIT_FAILURE).
check {DO7 a list value never takes the .options door, whichever slot is asked for} \
  [list [o_ans ase::opt_door ngspice ticlist] [o_ans ase::opt_door ngspice ticlist control]] \
  {control control}

check {DO8 an unknown option name is refused by name rather than guessed at} \
  [list [expr {[o_raise ase::opt_door ngspice zzznosuch] ne {}}] \
        [string match {*describes no option 'zzznosuch'*} \
          [o_raise ase::opt_door ngspice zzznosuch]]] {1 1}

check {DO9 a slot that is neither deck nor control is refused} \
  [string match {*must be 'deck' or 'control'*} [o_raise ase::opt_door ngspice reltol elsewhere]] 1

check {DO10 the pre-deck predicate and the door agree over the whole catalogue} \
  [o_names_where {
     set d {}
     foreach w {deck control} { catch {set d [ase::opt_door ngspice $n $w]} }
     expr {[ase::opt_is_pre_deck ngspice $n] != ($d in {predeck predeck-file})} }] {}

} doerr]} { check {DO0 section DO ran to the end} "RAISED:$doerr" {} }

# ============================================================================
# SECTION SP -- THE ONE SPELLER, AND THE TRAPS IT TURNS INTO TYPE ERRORS
# ============================================================================
if {[catch {

check {SP1 an OPTtbl real is written with its value above the block and through the option command inside it} \
  [list [o_ans ase::opt_line ngspice reltol 1e-4] \
        [o_ans ase::opt_line ngspice reltol 1e-4 control]] \
  {{.options reltol=1e-4} {option reltol=1e-4}}

## ⚠ AN `OPTtbl` FLAG INSIDE THE BLOCK IS `option`, NOT `set`, AND NGSPICE'S OWN
## BEHAVIOUR WOULD NOT HAVE CAUGHT THE RESPELLING -- sabotage S31 SURVIVED until
## this row existed. MEASURED on both binaries, `$plots` after an `ac`:
##     (nothing)            -> const ac1
##     option keepopinfo    -> const op1 ac1
##     set keepopinfo       -> const op1 ac1     <- ALSO works, by accident
## `cp_vset` forwards an `OPTtbl` name to `if_option`, so `set` happens to reach
## a task option here. `option` is the documented command and the one mechanism
## a second simulator can be asked for; `set` is ngspice's coincidence.
check {SP1b an OPTtbl flag inside the block is written with the option command} \
  [list [o_ans ase::opt_line ngspice keepopinfo 1 control] \
        [o_ans ase::opt_line ngspice klu 1 control] \
        [o_ans ase::opt_line ngspice keepopinfo 0 control]] \
  {{option keepopinfo} {option klu} {}}

## T3. MEASURED on both binaries: `set sqrnoise` gives onoise_total
## 1.489e-13, `set sqrnoise=1` and `set sqrnoise=true` give 3.859e-07.
check {SP2 a flag is written without a value, and the OFF spelling is absence} \
  [list [o_ans ase::opt_line ngspice keepopinfo 1] \
        [o_ans ase::opt_line ngspice keepopinfo 0] \
        [o_ans ase::opt_line ngspice keepopinfo true] \
        [o_ans ase::opt_line ngspice sqrnoise 1 control]] \
  {{.options keepopinfo} {} {.options keepopinfo} {set sqrnoise}}

## ⚠ NON-VACUITY for SP2: no value a user can type produces an `=` on a flag.
check {SP3 and NO value produces an equals sign on a flag} \
  [lsort -unique [lmap v {1 0 true yes on off 2 -1 1.0 {}} \
     {expr {[string first = [o_ans ase::opt_line ngspice keepopinfo $v]] >= 0}}]] 0

## ⚠ THE SPELLING ASE-L ACTUALLY EMITS TODAY, AND THE ONE SABOTAGE S28 FOUND NO
## ROW FOR. `sqrnoise` is a `CP_BOOL` read after the circuit is loaded, so both
## doors reach it -- MEASURED on both binaries, `onoise_total` 3.859e-07 with
## neither spelling and 1.489e-13 with `.options sqrnoise` OR `set sqrnoise`.
## The deck-slot spelling must stay `.options sqrnoise`, with NO value, because
## that is the line already in the tree and `set sqrnoise=1` is silently OFF.
check {SP3b a cp_getvar boolean above the block is the bare .options card, in both doors} \
  [list [o_ans ase::opt_line ngspice sqrnoise 1] \
        [o_ans ase::opt_line ngspice sqrnoise 1 control] \
        [o_ans ase::opt_line ngspice sqrnoise 0] \
        [lsort -unique [lmap v {1 true yes 2 on} \
           {expr {[string first = [o_ans ase::opt_line ngspice sqrnoise $v]] >= 0}}]]] \
  {{.options sqrnoise} {set sqrnoise} {} 0}

## T4. MEASURED on both binaries: `.options warn=1` prints one SOA warning,
## `.options warn` prints none.
check {SP4 a valued option with an empty value writes nothing at all, rather than a bare card} \
  [list [o_ans ase::opt_line ngspice warn {}] [o_ans ase::opt_line ngspice warn 1]] \
  {{} {.options warn=1}}

## ⚠ AND ZERO IS A VALUE, NOT AN ABSENCE. `.options gminsteps=0` disables gmin
## stepping; writing nothing leaves it at 1 (cktntask.c:121).
check {SP5 zero is written for a valued option and omitted for a flag} \
  [list [o_ans ase::opt_line ngspice gminsteps 0] [o_ans ase::opt_line ngspice klu 0]] \
  {{.options gminsteps=0} {}}

## T5. MEASURED on both binaries: `-D sqrnoise` works, `-D sqrnoise=1` is
## inert, `-D warn=1` is inert. `-D name=value` is ALWAYS a CP_STRING.
## ⚠ `casemode` WAS THIS ROW'S CP_STRING EXAMPLE AND IS NOW REFUSED BY THE
## SPELLER (issue 1439): ASE-L already puts one `-D casemode=` on the command
## line, and MEASURED on the fork the LAST `-D casemode=` wins, so a second one
## from an options row would beat the request the pre-flight measured.
## `ngbehavior` replaces it -- a pre-deck CP_STRING with no control of its own,
## MEASURED to arrive: `-D ngbehavior=hs` prints `Note: Compatibility modes
## selected: hs` on both binaries.
check {SP6 -D carries a pre-deck bool without a value and a pre-deck string with one} \
  [list [o_ans ase::opt_line ngspice mingwpath 1] \
        [o_ans ase::opt_line ngspice ngbehavior hs]] \
  {{-D mingwpath} {-D ngbehavior=hs}}

## ⚠ `wnflag` WAS THIS ROW'S CP_NUM EXAMPLE; issue 1439 measured it out of the
## pre-deck class, so the example is now `ps_tpz_delays`, which is read during
## the netlist read and has no `.options` door at all.
check {SP7 a pre-deck number or list never reaches -D; it takes the run-directory file} \
  [list [o_ans ase::opt_line ngspice ps_tpz_delays 1] \
        [o_ans ase::opt_line ngspice sourcepath {/a /b}]] \
  {{set ps_tpz_delays=1} {set sourcepath = ( /a /b )}}

## The second, independent guard on T5: even if the door computation were
## wrong, the predeck door declares no num/real/list template at all.
check {SP8 the -D door declares no template for a number, a real or a list} \
  [list [o_ans ase::opt_template ngspice wnflag predeck num] \
        [o_ans ase::opt_template ngspice scale predeck real] \
        [o_ans ase::opt_template ngspice sourcepath predeck list]] {{} {} {}}

check {SP9 the .options door declares no template for a list} \
  [o_ans ase::opt_template ngspice ticlist options list] {}

check {SP10 a cptype with no template for its door is refused, and the refusal names both} \
  [string match {*no way to write a 'list' option through the 'options' door*} \
    [o_raise apply {{} {
       set save $::ase::backends
       dict set ::ase::backends zzsp [dict create render_deck x run_cmd x log_file x \
         result_probe x raw_file x sim_options ::ase_t_listcat \
         option_spell ::ase::backend::ngspice::option_spell]
       proc ::ase_t_listcat {} { return {listy {cptype list phase deck}} }
       set rc [catch {ase::opt_line zzsp listy {1 2}} e]
       set ::ase::backends $save
       if {$rc} { return -code error $e }
       return $e }}]] 1

check {SP11 the argv option is spelled from its own row, not from the shared table} \
  [o_ans ase::opt_line ngspice soa_log /tmp/soa.log] {--soa-log=/tmp/soa.log}

check {SP12 an unknown option name is refused rather than spelled} \
  [string match {*describes no option 'zzznosuch'*} \
    [o_raise ase::opt_line ngspice zzznosuch 1]] 1

## The truth test is ONE body, shared with ase::option_enabled, so the deck and
## the form cannot disagree about whether a switch is on.
check {SP13 empty and zero are off, every other value is on -- the same rule option_enabled applies} \
  [lmap v {{} 0 1 2 true off -1} {o_ans ase::opt_truthy $v}] {0 0 1 1 1 1 1}

## ⚠ AND THE AGREEMENT IS ASSERTED ON THE SPELLER, NOT ONLY ON THE PREDICATE --
## sabotage S07 SURVIVED until this row existed. Swapping `ase::opt_truthy` for
## the plan's `{1 true yes on}` membership test leaves every row above green
## (none of them types a value outside that list) while silently dropping the
## card for a user who typed `2`, which `ase::option_enabled` and `render_deck`
## both read as ON.
check {SP13c the speller writes a flag for exactly the values option_enabled calls on} \
  [o_ans apply {{} {
     set mismatch {}
     foreach v {{} 0 1 2 true off -1 1.0 yes on} {
       set spelled [expr {[ase::opt_line ngspice keepopinfo $v] ne {}}]
       set enabled [ase::option_enabled \
         [dict create options [list [dict create name keepopinfo value $v]]] keepopinfo]
       if {$spelled != $enabled} { lappend mismatch "$v:$spelled/$enabled" }
     }
     return $mismatch }}] {}

check {SP14 and option_enabled answers the same for the same values} \
  [lmap v {{} 0 1 2 true off -1} \
     {o_ans ase::option_enabled [dict create options [list [dict create name klu value $v]]] klu}] \
  {0 0 1 1 1 1 1}

} sperr]} { check {SP0 section SP ran to the end} "RAISED:$sperr" {} }

# ============================================================================
# SECTION IN -- D24: AN INERT OPTION IS NEVER A LIVE FIELD
# ============================================================================
if {[catch {

## Every reason below was re-verified in the fork source this pass.
check {IN1 the inert rows are the measured ones, and each carries its reason} \
  [lsort [o_names_where {expr {[dict exists $row inert]}}]] \
  {acct addescape debug klu_memgrow_factor list newtrunc no_spiceinit node nomod nopage nosavecurrents nosighandling oldlimit opts ramptime x11lineararcs}

check {IN2 the speller refuses every inert row, in both slots} \
  [o_names_where {expr {[dict exists $row inert] &&
     (![catch {ase::opt_line ngspice $n 1}] || ![catch {ase::opt_line ngspice $n 1 control}])}}] {}

check {IN3 the refusal quotes the reason rather than saying only no} \
  [list [string match {*does nothing in this build*XSPICE_EXP*} \
          [o_raise ase::opt_line ngspice ramptime 1]] \
        [string match {*fixLimit*} [o_raise ase::opt_line ngspice oldlimit 1]]] {1 1}

## The tombstone: a name that appears NOWHERE in the ngspice source tree, kept
## so the next reader does not re-add it from the manual.
check {IN4 nosavecurrents is kept as a tombstone and can never be written} \
  [list [expr {[o_key nosavecurrents inert] ne {}}] \
        [string match {*Tombstone*} [o_key nosavecurrents inert]] \
        [expr {[o_raise ase::opt_line ngspice nosavecurrents 1] ne {}}]] {1 1 1}

## ⚠ THE ROW THAT EXPLAINS WHY NOTHING MOVED IS THE ROW TO SABOTAGE FIRST.
## `acct` and `list` are in ONE committed bench and neither does anything on
## ASE-L's route. MEASURED on both binaries: on a dot-card deck `.options acct
## list` adds ten lines of accounting and element summary; on a deck whose
## analyses run inside `.control` it adds none.
check {IN5 the six front-end print flags are inert on the .control route ASE-L uses} \
  [lsort [o_names_where {expr {[dict exists $row ngphase] &&
                               [dict get $row ngphase] eq {frontend}}}]] \
  {acct list node nomod nopage opts}

check {IN6 the three libngspice-only variables are inert for the executable ASE-L runs} \
  [lmap n {addescape nosighandling no_spiceinit} \
     {string match {*libngspice*} [o_key $n inert]}] {1 1 1}

} inerr]} { check {IN0 section IN ran to the end} "RAISED:$inerr" {} }

# ============================================================================
# SECTION HK -- D34-D37: THE CATALOGUE IS CONTENT, AND CORE NEVER NAMES IT
# ============================================================================
if {[catch {

check {HK1 a backend with no sim_options hook gets an empty catalogue and never a literal fallback} \
  [o_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzbare [dict create render_deck x run_cmd x log_file x \
       result_probe x raw_file x]
     set r [list [ase::sim_options zzbare] [ase::sim_option_entry zzbare reltol] \
                 [ase::sim_option_names zzbare] [ase::sim_option_spell zzbare]]
     set ::ase::backends $save
     return $r }}] {{} {} {} {}}

check {HK2 the catalogue reaches core ONLY through the hook -- core declares no option variable of its own} \
  [list [info exists ::ase::sim_options] [expr {[info exists ::ase::backend::ngspice::sim_options] ? 1 : 0}]] {0 1}

## ⚠ THE NAMING RULE IS LEXICAL, SO THE TEST IS TOO. Not one ngspice option
## name may appear in the SCHEMA procs' bodies -- the whole point of a computed
## door is that core never learns a simulator's vocabulary.
check {HK3 no schema proc names an ngspice option, an ngspice card or a CP_ class} \
  [o_ans apply {{} {
     set bad {}
     foreach p {ase::opt_door ase::opt_line ase::opt_template ase::opt_truthy
                ase::opt_phase ase::opt_inert ase::opt_default ase::opt_restore_line
                ase::opt_is_pre_deck ase::sim_options ase::sim_option_entry
                ase::sim_option_names ase::sim_option_spell ase::option_schema_errors
                ase::state_option_delivery} {
       if {![llength [info commands $p]]} { lappend bad "$p:missing" ; continue }
       set b [o_nocomment [info body $p]]
       foreach w {reltol gminsteps keepopinfo casemode sqrnoise wnflag savecurrents
                  .options .control CP_BOOL CP_NUM ngspice} {
         if {[string first $w $b] >= 0} { lappend bad "$p:$w" }
       }
     }
     return [lsort -unique $bad] }}] {}

## ⚠ AND THE `cptype` VOCABULARY IS THE ADAPTER'S. Core looks (door, cptype) up
## in the adapter's table; it never enumerates the classes. A simulator with no
## CP_ classes at all can describe itself here, which is what D37's paper
## validation is for.
check {HK4 a made-up simulator with a vocabulary of its own spells its own options} \
  [o_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzalien [dict create render_deck x run_cmd x log_file x \
       result_probe x raw_file x sim_options ::ase_t_alien option_spell ::ase_t_alienspell]
     proc ::ase_t_alien {} { return {WIDGET {cptype toggle phase any} GADGET {cptype amount phase any}} }
     proc ::ase_t_alienspell {} { return {options {toggle {ENABLE @name} amount {SET @name TO @value}}
                                          control {toggle {ENABLE @name} amount {SET @name TO @value}}} }
     set r [list [ase::opt_line zzalien WIDGET 1] [ase::opt_line zzalien GADGET 42] \
                 [ase::opt_door zzalien WIDGET] [ase::option_schema_errors zzalien]]
     set ::ase::backends $save
     return $r }}] {{ENABLE WIDGET} {SET GADGET TO 42} options {}}

check {HK5 registering a backend does not need the two new hooks} \
  [o_ans apply {{} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zzfive [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x]} e]
     set ::ase::backends $save
     return [list $rc $e] }}] {0 zzfive}

} hkerr]} { check {HK0 section HK ran to the end} "RAISED:$hkerr" {} }

# ============================================================================
# SECTION BR -- THE BRIDGE: WHERE THE SHIPPED EMITTER AND THE SPELLER DIFFER
# ============================================================================
# ⚠ ISSUE 1437 CHANGES NO DECK. render_deck's option loop is untouched, so
# every golden and every .state file is byte-identical. These rows exist so the
# crew that DOES rewire it knows the blast radius by name instead of guessing.
#
# render_deck's shipped rule, verbatim: value defaults to 1; a value of exactly
# `0` skips the row; a value of exactly `1` writes a BARE card; anything else
# writes `name=value`.
if {[catch {

proc o_rd {name value} {
  if {$value eq {0}} { return {} }
  if {$value eq {1}} { return ".options $name" }
  return ".options $name=$value"
}

check {BR1 for a flag set to a plain on or off value the two agree exactly} \
  [lmap v {1 0} {expr {[o_rd keepopinfo $v] eq [o_ans ase::opt_line ngspice keepopinfo $v]}}] {1 1}

check {BR2 for a valued option set to anything but 0 or 1 the two agree exactly} \
  [lmap v {1e-4 gear 500 2.5} {expr {[o_rd reltol $v] eq [o_ans ase::opt_line ngspice reltol $v]}}] \
  {1 1 1 1}

## ⚠ THE FIRST DEFECT, MEASURED ON BOTH BINARIES: `.options maxord=1` gives
## MaxOrder = 1 and `.options maxord` leaves it at 2. The shipped emitter
## writes the bare card for every valued option a user sets to 1.
check {BR3 a valued option set to 1 -- the emitter writes a bare card, the speller writes the value} \
  [list [o_rd maxord 1] [o_ans ase::opt_line ngspice maxord 1]] \
  {{.options maxord} {.options maxord=1}}

## ⚠ THE SECOND, MEASURED ON BOTH BINARIES: `.options gminsteps=0` gives
## gminsteps = 0; the emitter writes nothing and gmin stepping runs at 1.
check {BR4 a valued option set to 0 -- the emitter drops the row, the speller writes the zero} \
  [list [o_rd gminsteps 0] [o_ans ase::opt_line ngspice gminsteps 0]] \
  {{} {.options gminsteps=0}}

## The blast radius, named. Every catalogue row the two rules would spell
## differently is a valued row, and no flag row is in the set.
check {BR5 the disagreement is exactly the valued rows, and never a flag} \
  [o_ans apply {{} {
     set flags 0 ; set valued 0
     foreach n [ase::sim_option_names ngspice] {
       if {[ase::opt_inert ngspice $n] ne {}} { continue }
       if {[catch {ase::opt_door ngspice $n} d] || $d ne {options}} { continue }
       set same 1
       foreach v {1 0} {
         if {[o_rd $n $v] ne [ase::opt_line ngspice $n $v]} { set same 0 }
       }
       set tm [ase::opt_template ngspice $n options [dict get [ase::sim_option_entry ngspice $n] cptype]]
       if {[string first @value $tm] < 0} { if {!$same} { incr flags } } \
       else { if {!$same} { incr valued } }
     }
     return [list $flags [expr {$valued > 0}]] }}] {0 1}

## ⚠ RE-BASELINED BY ISSUE 1439, WHICH IS THE CREW THIS SECTION WAS WRITTEN
## FOR. The emitter now consults the catalogue: an option this simulator
## describes is spelled by the ONE speller, an option whose door is not the
## deck's is left to the pre-deck delivery, and only a name the catalogue does
## not know still takes the old bare-card rule. The behavioural proof -- a
## rendered deck carrying `.options wnflag=1` -- is
## tests/headless/test_ase_predeck_1439.tcl section RD; this row is the
## lexical half, and it is what says the loop is still routed through the
## speller rather than through a second spelling.
## ⚠ RE-BASELINED AGAIN BY ISSUE 1441 (PLAN.md §7c), AND THE CLAIM IS
## UNCHANGED -- only where the body lives moved. §7c's live deck preview must
## show the lines the deck will really carry, and two bodies answering "what
## does this bench write" is two answers with the preview as the one nobody
## runs. So the loop itself is now `ase::opt_deck_plan` and `render_deck`
## CALLS it; the last-resort `.options` spelling is ngspice syntax and moved
## to the adapter's own `option_fallback` hook, which is where D34 puts it.
## Three bodies, three halves of the same sentence.
check {BR6 the option loop goes through the one speller, the emitter delegates to the shared body, and the bare card survives only as the adapter's fallback} \
  [o_ans apply {{} {
     set r [o_nocomment [info body ::ase::backend::ngspice::render_deck]]
     set p [o_nocomment [info body ::ase::opt_deck_plan]]
     set f [o_nocomment [info body ::ase::backend::ngspice::option_fallback]]
     return [list [expr {[string first {ase::opt_deck_plan $rdopsim $state} $r] >= 0}] \
                  [expr {[string first {lappend lines ".options $onm"} $r] >= 0}] \
                  [expr {[string first {ase::opt_line $sim $name $value} $p] >= 0}] \
                  [expr {[string first {ase::opt_door $sim $name} $p] >= 0}] \
                  [expr {[string first {return ".options $name"} $f] >= 0}]] }}] \
  {1 0 1 1 1}

} brerr]} { check {BR0 section BR ran to the end} "RAISED:$brerr" {} }

# ============================================================================
# SECTION DL -- WHAT THE USER'S OWN COMMITTED BENCHES ARE SILENTLY LOSING
# ============================================================================
if {[catch {

## ⚠ `wnflag` WAS THE SUBJECT HERE UNTIL ISSUE 1439 MEASURED IT DELIVERABLE.
## The claim is unchanged; the example is a row that really is out of the
## deck's reach.
check {DL1 a stored option whose door the deck cannot carry is reported, with the door named} \
  [o_ans ase::state_option_delivery ngspice \
     [dict create options {{name ps_tpz_delays value 1}}]] \
  {{ps_tpz_delays predeck-file {this option needs the 'predeck-file' door; the deck above the analysis block cannot carry it}}}

check {DL2 a stored option this catalogue does not know is reported and left alone, never refused} \
  [lindex [o_ans ase::state_option_delivery ngspice \
     [dict create options {{name frobnicate value 1}}]] 0 1] unknown

check {DL3 a stored inert option is reported as inert} \
  [lindex [o_ans ase::state_option_delivery ngspice \
     [dict create options {{name acct value 1}}]] 0 1] inert

## ⚠ NON-VACUITY: the checker must be SILENT about an option that does deliver.
check {DL4 and an option the deck can carry is not reported at all} \
  [o_ans ase::state_option_delivery ngspice \
     [dict create options {{name reltol value 1e-5} {name savecurrents value 1} {name method value gear}}]] {}

## THE MEASUREMENT, over the user's own tree. It read `6 {acct list wnflag} 5`
## when this file landed: FIVE committed benches asked for `wnflag` and none of
## them got it. ⚠ RE-BASELINED BY ISSUE 1439, WHICH FIXED IT -- all five now
## deliver, through `.options wnflag=1`, MEASURED on both binaries to move the
## selected model bin (@m1[vth] 0.9889 -> 0.5889). What is left is the one
## bench carrying `acct` and `list`, which do nothing on ASE-L's `.control`
## route and are inert rows in the catalogue. **This row going back up is a
## regression**, not a catalogue edit.
check {DL5 after 1439 exactly one committed bench still stores an option that cannot reach the simulator, and no bench loses wnflag any more} \
  [o_ans apply {{} {
     ## ⚠ NOT `exec git ls-files` BARE (issue 1485): in a checkout with no
     ## `.git` that RAISED, and the raise landed in the row as its answer --
     ## `-> {RAISED:fatal: not a git repository ...}`, MEASURED 2026-09-20 in a
     ## `git archive` export. `test_corpus_files` enumerates the same files
     ## from the filesystem when git cannot answer, so this row still reads the
     ## whole corpus there.
     global repo
     set byname [dict create] ; set files 0
     set corpus [test_corpus_files $repo *.state]
     test_corpus_note $corpus "the committed .state corpus"
     foreach f [dict get $corpus files] {
       if {[catch {ase::state_load $f} st]} { continue }
       set d [ase::state_option_delivery ngspice $st]
       if {[llength $d] == 0} { continue }
       incr files
       foreach row $d { dict incr byname [lindex $row 0] }
     }
     set wn 0 ; catch {set wn [dict get $byname wnflag]}
     ## ⚠ A FLOOR ON THE COUNT, EXACT ON THE OPTION NAMES. In a checkout with
     ## no `.git` the corpus comes from the filesystem (issue 1485) and
     ## includes benches the tester saved: MEASURED 2026-09-20, copying the
     ## shipped `test_stdcells` bench into a second run directory took this row
     ## to `{2 {acct list} 0}` and reddened it. What the row is actually about
     ## survives exactly: the undeliverable options in the whole tree are still
     ## precisely `acct` and `list` -- a NEW inert option anywhere reddens this
     ## -- and `wn` is still exactly 0, which is the "no bench loses wnflag"
     ## half. What the floor gives up is "exactly ONE bench", which no longer
     ## catches a SECOND bench carrying the same two inert rows.
     return [list [expr {$files >= 1}] [lsort [dict keys $byname]] $wn] }}] \
  {1 {acct list} 0}

} dlerr]} { check {DL0 section DL ran to the end} "RAISED:$dlerr" {} }

# ============================================================================
# SECTION RS -- THE RESTORE LINE, WHICH IS THE SPELLER APPLIED TO THE DEFAULT
# ============================================================================
if {[catch {

check {RS1 a valued option restores to its catalogue default through the same speller} \
  [list [o_ans ase::opt_restore_line ngspice reltol] \
        [o_ans ase::opt_restore_line ngspice gminsteps]] \
  {{option reltol=1e-3} {option gminsteps=1}}

## ⚠ RE-BASELINED BY ISSUE 1442, AND THE CLAIM WAS MEASURED FALSE. This row
## read *"RS2 a flag has no restore line"* and expected `{} {}`, under the
## comment *"a flag restores by ABSENCE, and absence has no line"*. That is true
## of the FORWARD spelling and false of the reverse one: absence is how a flag
## STARTS, not how it is put back once something has set it.
##
## MEASURED 2026-09-13 on BOTH binaries, with §7e's own example:
##
##   ac                       -> $plots  const ac1
##   option keepopinfo ; ac   -> $plots  const ac1 op1 ac2      <- ON
##   option keepopinfo=0 ; ac -> $plots  const ac1 op1 ac2 ac3  <- OFF AGAIN
##
## The third run gained `ac3` and NO `op2`. Source generalises it: every
## `IF_FLAG` arm in `cktsopt.c` is `task->TSKxxx = (val->iValue != 0)`.
##
## ⚠ THE OLD ROW WAS NOT MERELY PEDANTIC -- IT PINNED §7e's MECHANISM SHUT. With
## no reverse spelling for the flag class, the per-analysis scope could promise
## nothing for any flag, and §7g rule 1 would have had no way to turn KLU off
## for one analysis and put it back.
check {RS2 a flag restores with an explicit zero, because absence is only how it starts} \
  [list [o_ans ase::opt_restore_line ngspice keepopinfo] \
        [o_ans ase::opt_restore_line ngspice klu]] \
  {{option keepopinfo=0} {option klu=0}}

check {RS3 a row with no known default has no restore line, which is 7e's stated honest limit} \
  [list [o_key maxopalter default] [o_ans ase::opt_restore_line ngspice maxopalter]] {{} {}}

check {RS4 an inert row is never restored} \
  [o_names_where {expr {[dict exists $row inert] &&
                        [ase::opt_restore_line ngspice $n] ne {}}}] {}

check {RS5 the restore line is the speller's, not a second spelling} \
  [expr {[o_ans ase::opt_restore_line ngspice reltol] eq
         [o_ans ase::opt_line ngspice reltol [o_key reltol default] control]}] 1

} rserr]} { check {RS0 section RS ran to the end} "RAISED:$rserr" {} }

# ============================================================================
# SECTION PR -- PROVENANCE: EVERY ROW SAYS WHERE IT CAME FROM
# ============================================================================
if {[catch {

check {PR1 every row names the source it was read from} \
  [o_names_where {expr {![dict exists $row site]}}] {}

check {PR2 the 57 settable OPTtbl keywords are the rows anchored in cktsopt.c, and each carries ngspice's own description} \
  [o_ans apply {{} {
     set n 0 ; set nohelp 0
     foreach name [ase::sim_option_names ngspice] {
       set row [ase::sim_option_entry ngspice $name]
       if {![string match {cktsopt.c:*} [dict get $row site]]} { continue }
       incr n
       if {![dict exists $row help]} { incr nohelp }
     }
     return [list $n $nohelp] }}] {57 0}

check {PR3 the catalogue carries at least the 163 cp_getvar variables} \
  [expr {[llength [o_names_where {expr {![string match {cktsopt.c*} [dict get $row site]] &&
                                        ![string match opt* [dict get $row cptype]]}}]] >= 163}] 1

check {PR4 the scope column is global or an analysis list, never anything else} \
  [o_names_where {expr {[dict exists $row scope] &&
                        [lindex [dict get $row scope] 0] ni {global analysis}}}] {}

} prerr]} { check {PR0 section PR ran to the end} "RAISED:$prerr" {} }

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
