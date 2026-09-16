# tests/headless/test_ase_optsheet_1441.tcl -- ISSUE 1441: FINDING ONE OPTION
# AMONG 247, AND THE BADGE THAT HAD NOT BEEN MEASURED. PLAN.md Stage 7c.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# Issue 1437 gave ASE-L a 247-row option catalogue and issue 1439 gave it a
# delivery. Neither gave the user a way to FIND anything: Simulation > Options…
# was a two-column list of the rows this bench already stored, so an option you
# had not already typed the name of was unreachable from the GUI entirely.
#
# And the three columns a finder has to stand on -- `group`, `scope`, `results`
# -- were shipped 0/247 VERIFIED. 1437's own receipt says so in as many words:
# they were TRANSCRIBED out of evidence/hidden-vars.md and evidence/options.md.
# The worst of the three is `results`, because §7c asks for a ⚠ badge on every
# `results 1` row that tells the user THIS OPTION CHANGES YOUR NUMBERS. A badge
# is an assertion, and an assertion with a transcription behind it is a guess in
# a uniform.
#
# ============================================================================
# ⚠ THE MEASUREMENT, AND THE THREE ROWS IT REFUTED
# ============================================================================
# All 22 `results` rows were probed on BOTH preflight binaries -- the fork
# (/home/analog/dev/ngspice/build-ver_50/src/ngspice, ngspice-46+) and the apt
# build (/usr/bin/ngspice, ngspice-45.2) -- on 2026-09-13, each on a deck built
# to make its own documented mechanism fire:
#
#   MEASURED to move a printed value                                  9 rows
#     scale .options scale=0.5    -> @m1[w] 2.000000e-06 -> 1.000000e-06
#     wnflag .options wnflag=1    -> @m1[vth] 1.088900 -> 0.688900 across a
#                                    BSIM4 W bin edge, i(vd) 8x
#     sqrnoise                    -> onoise_total 3.147875e-07 -> 9.909116e-14
#     cshunt_value=1n             -> every AC/TRAN/NOISE value of the probe deck
#     notrnoise                   -> a trnoise source to 0 at every timepoint
#     seed=12345 vs 999           -> different samples, both unlike unseeded
#     autostop  (with one .meas)  -> 226 data rows -> 2
#     diode_cj0=10p  (ngbehavior=ps, run-directory file)
#                                 -> AC imag 0.000000e+00 -> 1.066292e-04
#     diode_rser=100 (same route) -> i(vb) 5.670347e-03 -> 5.867302e-04
#
#   MEASURED NOT TO, with the mechanism demonstrably firing               3 rows
#     warn=1        0 -> 5 SOA `Bv_max` messages, EVERY printed value identical
#     maxwarns=2    5 -> 2 messages, every printed value identical
#     num_threads=1 against the default: identical OP, AC, TRAN and NOISE
#
#   NOT MEASURED -- no probe deck made the mechanism fire                10 rows
#     auto_bridge no_auto_bridge_family noisyxspice xtrtol (event/A-device
#     XSPICE), ng_nomodcheck enable_noisy_r (model/netlist shapes), dyngmin
#     topo_reduce nostepsizelimit (nothing distinguished the two runs),
#     soacheck (needs a PDK library that reads SWSOA)
#
# ⚠ SO THE TRANSCRIPTION WOULD HAVE PUT AN AUTHORITATIVE BADGE ON `warn`,
# `maxwarns` AND `num_threads`, TWO OF THEM PURE DIAGNOSTIC PRINTERS. The
# column now carries its own evidence key and `ase::opt_results` answers
# `yes` / `no` / `unverified`; the sheet draws a DIFFERENT badge for the third,
# so the uncertainty is on the surface instead of hidden behind it.
#
# ============================================================================
# WHAT THIS FILE IS ABOUT
# ============================================================================
# The SCHEMA answers the options sheet draws (src/ase.tcl, `ase::opt_*`), the
# shared emitter body they rest on, and the widgets themselves
# (src/ase_window.tcl). It is NOT about §7e's emit-then-restore, §7f's
# read-back or §7g's caps rules -- those are Stage 7 task 4 and the `control`
# slot of the preview is EMPTY here, which section PV asserts as a fact so the
# day it fills, this file says so.
#
# ⚠ NO SIMULATOR IS STARTED HERE. Every ngspice number quoted above was
# measured beforehand on both binaries; the rows below assert what ASE-L does
# with those facts, which is pure Tcl.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#    64  headless -- sections GR SC RB FN CH DP PV HK, all pure Tcl
#    89  on the dev display (:99) -- the same 64 plus section UI's 25
#
#    AND RAISED 62 -> 64 / 87 -> 89, ⚖ R9 ruling A1 (2026-09-15): HK4 and HK5,
#    the two rows that pin the capitals the user KEPT. A1 lowercased every word
#    shouted for emphasis inside a sentence -- VOLTAGE, DEGREES, both NOTs, ONE
#    -- and kept this sheet's row PREFIXES, which leaves the interface looking
#    inconsistent on purpose. An exception held only in memory is one a later
#    consistency pass deletes in good faith, so it is held by a row. Pure Tcl,
#    both arms.
#
#    The two arms DIFFER on purpose: section UI drives the real widgets and
#    self-skips without an X connection, so the display arm is a measurement of
#    a BIGGER thing rather than a stronger measurement of the same one (the
#    distinction issue 1405 cost 100 checks to learn). BOTH arms are registered
#    in tests/run_regression.tcl -- `hcases` AND `dcases` -- because this is the
#    only suite in Stage 7 whose subject is a window, and its display arm costs
#    0.40 s against 0.10 s headless, measured 2026-09-13.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_optsheet_1441.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_optsheet_1441.tcl

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
set scratch [test_scratch optsheet1441]

proc s_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc s_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} { continue } ; lappend out $l }
  return [join $out "\n"]
}
proc s_state {opts} {
  set st [ase::state_default]
  dict set st options $opts
  return $st
}

# ⚠ THE REGISTRY IS CLEARED IN MEMORY, exactly as issue 1439's suite does and
# for the same measured reason: the developer's own saved entry can carry `-n`,
# which changes what the pre-deck half of the preview reports. `ase::sim_clear`
# writes no file.
catch {ase::sim_clear}

# ============================================================================
# SECTION GR -- GROUPS, NOT AN ALPHABET (§7c-3)
# ============================================================================
if {[catch {

check {GR1 every catalogue row answers a group, and none of them falls through to `other`} \
  [s_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       if {[ase::opt_group ngspice $n] eq {other}} { lappend bad $n }
     }
     return $bad }}] {}

## ⚠ `other` IS NOT DECORATION, AND THIS IS THE ROW THAT SAYS SO. GR1 passing
## over a catalogue where every row happens to carry a group proves nothing
## about the fallback; a second adapter whose descriptor omits the key is what
## gets it, which is D37's paper validation exactly.
check {GR2 a row that declares no group answers `other` rather than empty} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzgrp [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_grpcat]
     proc ::ase_t_grpcat {} { return {bare {cptype bool}} }
     set r [ase::opt_group zzgrp bare]
     set ::ase::backends $save
     return $r }}] other

## The index is the drawer set, and it is ORDERED -- a sheet whose drawers move
## as you type is a sheet you cannot learn.
check {GR3 the group index is alphabetical by group and by name inside a group} \
  [s_ans apply {{} {
     set ix [ase::opt_group_index ngspice {vntol reltol gmin abstol}]
     return $ix }}] {convergence gmin tolerances {abstol reltol vntol}}

## ⚠ THE `numerics` GROUP IS GONE, AND IT WAS A CATEGORY ERROR. Issue 1437's
## transcription put all 20 of the catalogue's `results`-carrying `cp_getvar`
## rows in one drawer called `numerics` -- which is not a FUNCTION, it is the
## `results` column wearing a group's clothes. `sqrnoise` belongs in the drawer
## a user opens looking for noise output, not in a drawer named after a property
## the ⚠ badge already carries. All 20 were re-filed into the function category
## evidence/hidden-vars.md §7 itself places them in.
check {GR4 no row is filed under a group named after the results property} \
  [s_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       if {[ase::opt_group ngspice $n] eq {numerics}} { lappend bad $n }
     }
     return $bad }}] {}

check {GR5 and the re-filed rows landed in the function drawers §7 places them in} \
  [s_ans apply {{} {
     set out {}
     foreach n {sqrnoise scale wnflag warn maxwarns autostop cshunt_value
                diode_cj0 num_threads seed} {
       lappend out [ase::opt_group ngspice $n]
     }
     return $out }}] \
  {output device device diagnostics diagnostics integration convergence device solver netlist}

} grerr]} { check {GR0 section GR ran to the end} "RAISED:$grerr" {} }

# ============================================================================
# SECTION SC -- TWO SCOPES ON TWO SURFACES, AND WHY A WRONG ONE CANNOT HIDE
# ============================================================================
if {[catch {

## ⚠ THE MITIGATION FOR A TRANSCRIBED COLUMN, STATED AS A ROW. `PLAN.md` §7c
## says "an option shown in the wrong scope is worse than one not shown", and
## that failure is only possible if a scope can HIDE a row. The global surface
## offers every row in the catalogue, so a wrong `scope` costs a SHORTCUT and
## never costs the option.
check {SC1 the global surface offers every row in the catalogue, without exception} \
  [s_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       if {![ase::opt_in_scope ngspice $n global]} { lappend bad $n }
     }
     return $bad }}] {}

check {SC2 an analysis surface offers the rows scoped to it and refuses the rest} \
  [list [s_ans ase::opt_in_scope ngspice itl4 {analysis tran}] \
        [s_ans ase::opt_in_scope ngspice itl4 {analysis ac}] \
        [s_ans ase::opt_in_scope ngspice reltol {analysis tran}]] {1 0 0}

check {SC3 a row scoped to several types is offered on each of them} \
  [list [s_ans ase::opt_in_scope ngspice keepopinfo {analysis ac}] \
        [s_ans ase::opt_in_scope ngspice keepopinfo {analysis noise}] \
        [s_ans ase::opt_in_scope ngspice keepopinfo {analysis dc}]] {1 1 0}

## Cross-checked against the document the column was transcribed from. Of the
## catalogue's analysis-scoped rows, evidence/options.md §10.2 names the SAME
## analysis set for every one it lists -- measured 2026-09-13, zero set-level
## disagreements over 27 shared rows.
check {SC4 the analysis-scoped rows name the analysis sets options.md §10.2 names} \
  [s_ans apply {{} {
     set want {itl1 {analysis op} itl2 {analysis dc} itl4 {analysis tran}
               trtol {analysis tran} method {analysis tran} maxord {analysis tran}
               noopiter {analysis op} gminsteps {analysis op} srcsteps {analysis op}
               copynodesets {analysis op} nodedamping {analysis op}
               sqrnoise {analysis noise sp} noopac {analysis ac sp}
               keepopinfo {analysis ac noise pz tf disto sp}}
     set bad {}
     dict for {n sc} $want {
       if {[ase::opt_scope ngspice $n] ne $sc} { lappend bad [list $n [ase::opt_scope ngspice $n]] }
     }
     return $bad }}] {}

## ⚠ TWO ROWS THE CROSS-CHECK MOVED. §10.2 lists `dyngmin` under OP/DC-op and
## `chgtol` under TRAN; the transcription had both `global`. Fixing them can
## only ADD the row to an analysis short list -- SC1 is what says it cannot
## remove them from anywhere.
check {SC5 dyngmin and chgtol carry the scope §10.2 gives them} \
  [list [s_ans ase::opt_scope ngspice dyngmin] [s_ans ase::opt_scope ngspice chgtol]] \
  {{analysis op} {analysis tran}}

check {SC6 a row that declares no scope is global, which is the safe default} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzsc [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_sccat]
     proc ::ase_t_sccat {} { return {bare {cptype bool}} }
     set r [list [ase::opt_scope zzsc bare] [ase::opt_in_scope zzsc bare {analysis tran}]]
     set ::ase::backends $save
     return $r }}] {global 0}

} scerr]} { check {SC0 section SC ran to the end} "RAISED:$scerr" {} }

# ============================================================================
# SECTION RB -- THE ⚠ BADGE, AND THE EVIDENCE BEHIND IT (§7c-5)
# ============================================================================
if {[catch {

check {RB1 a row MEASURED to move a printed value answers yes} \
  [list [s_ans ase::opt_results ngspice sqrnoise] \
        [s_ans ase::opt_results ngspice scale] \
        [s_ans ase::opt_results ngspice wnflag] \
        [s_ans ase::opt_results ngspice autostop] \
        [s_ans ase::opt_results ngspice diode_rser]] {yes yes yes yes yes}

## ⚠ THE THREE REFUTATIONS. Each was measured with its own mechanism firing --
## `warn` took a deck from 0 to 5 SOA messages and changed no printed value.
check {RB2 the three rows measured NOT to change a number answer no} \
  [list [s_ans ase::opt_results ngspice warn] \
        [s_ans ase::opt_results ngspice maxwarns] \
        [s_ans ase::opt_results ngspice num_threads]] {no no no}

## ⚠ AND THE DEFAULT IS `unverified`, NOT `yes`. A catalogue cannot acquire a
## measured badge by being edited -- only by someone taking the measurement.
check {RB3 a results row with no evidence key answers unverified, not yes} \
  [list [s_ans ase::opt_results ngspice xtrtol] \
        [s_ans ase::opt_results ngspice noisyxspice] \
        [s_ans ase::opt_results ngspice soacheck]] \
  {unverified unverified unverified}

check {RB4 a row that claims nothing answers no} \
  [list [s_ans ase::opt_results ngspice reltol] [s_ans ase::opt_results ngspice itl4]] {no no}

## NON-VACUITY: the `unverified` answer must come from the MISSING evidence key
## and not from the row being absent or the proc answering one constant.
check {RB5 the evidence key is what separates yes from unverified, on one synthetic row} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzrb [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_rbcat]
     proc ::ase_t_rbcat {} { return {a {cptype bool results 1}
                                     b {cptype bool results 1 results_ev measured}
                                     c {cptype bool results 0 results_ev measured}
                                     d {cptype bool}} }
     set r [list [ase::opt_results zzrb a] [ase::opt_results zzrb b] \
                 [ase::opt_results zzrb c] [ase::opt_results zzrb d]]
     set ::ase::backends $save
     return $r }}] {unverified yes no no}

## The measurement itself is readable, so a user can tell a number somebody took
## from a sentence somebody wrote.
check {RB6 every measured row carries the measurement that made it measured} \
  [s_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       if {[ase::opt_results ngspice $n] eq {yes} \
           && [ase::opt_results_why ngspice $n] eq {}} { lappend bad $n }
     }
     return $bad }}] {}

check {RB7 and every unverified row says why it could not be measured} \
  [s_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       if {[ase::opt_results ngspice $n] eq {unverified} \
           && [ase::opt_results_why ngspice $n] eq {}} { lappend bad $n }
     }
     return $bad }}] {}

## THE CENSUS, so a later pass that measures one more row has to move a number
## here rather than quietly changing the badge population.
check {RB8 the badge population is 9 measured, 10 unverified, and 3 refuted} \
  [s_ans apply {{} {
     set y 0 ; set u 0 ; set r 0
     foreach n [ase::sim_option_names ngspice] {
       switch -- [ase::opt_results ngspice $n] {
         yes { incr y } unverified { incr u }
       }
       set d [ase::sim_option_entry ngspice $n]
       if {[dict exists $d results] && [dict get $d results] eq {0} \
           && [dict exists $d results_ev]} { incr r }
     }
     return [list $y $u $r] }}] {9 10 3}

} rberr]} { check {RB0 section RB ran to the end} "RAISED:$rberr" {} }

# ============================================================================
# SECTION FN -- SEARCH FIRST (§7c-1)
# ============================================================================
if {[catch {

check {FN1 an empty needle matches every row} \
  [s_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       if {![ase::opt_match ngspice $n {}]} { lappend bad $n }
     }
     return $bad }}] {}

check {FN2 the search reads the NAME} \
  [list [s_ans ase::opt_match ngspice reltol relt] \
        [s_ans ase::opt_match ngspice reltol zznothing]] {1 0}

## ⚠ SUBSTRING, NOT PREFIX, AND THE DIFFERENCE IS THE WHOLE FEATURE.
## `ase::ui::combo_filter` matches a PREFIX because a combobox is completing a
## value the user is typing. This is the opposite job: the user knows a word
## from the middle of the description and not the name, which is exactly why
## they could not find the option.
check {FN3 the search reads the HELP TEXT, by substring and not by prefix} \
  [list [s_ans ase::opt_match ngspice reltol tolerence] \
        [s_ans ase::opt_match ngspice keepopinfo {operating point}]] {1 1}

check {FN4 the search reads the GROUP} \
  [s_ans ase::opt_match ngspice reltol tolerances] 1

check {FN5 the search is case-insensitive on all three fields} \
  [list [s_ans ase::opt_match ngspice reltol RELT] \
        [s_ans ase::opt_match ngspice reltol TOLERENCE] \
        [s_ans ase::opt_match ngspice reltol TOLERANCES]] {1 1 1}

## ⚠ NON-VACUITY: a needle that matches nothing must narrow the sheet to NOTHING.
## A filter that falls back to the full list when it finds no match -- which is
## what `combo_filter` does, deliberately, for a combobox -- would make every
## FN row above pass while the feature did not work.
check {FN6 a needle nothing matches narrows the sheet to zero rows, never back to all of them} \
  [llength [s_ans ase::opt_browse ngspice -needle zznosuchoptionanywhere]] 0

check {FN7 the needle really narrows -- a whole catalogue, a handful, one} \
  [s_ans apply {{} {
     return [list [expr {[llength [ase::opt_browse ngspice]] >= 220}] \
                  [expr {[llength [ase::opt_browse ngspice -needle tolerance]] > 0
                      && [llength [ase::opt_browse ngspice -needle tolerance]] < 40}] \
                  [llength [ase::opt_browse ngspice -needle sqrnoise]]] }}] {1 1 1}

check {FN8 search and scope compose -- both filters, not the last one} \
  [s_ans apply {{} {
     set a [ase::opt_browse ngspice -needle iteration]
     set b [ase::opt_browse ngspice -needle iteration -scope {analysis tran}]
     return [list [expr {[llength $a] > [llength $b]}] \
                  [expr {[lsearch -exact $b itl4] >= 0}] \
                  [expr {[lsearch -exact $b itl1] >= 0}]] }}] {1 1 0}

check {FN9 an unknown browse switch is refused rather than ignored} \
  [expr {[string first {unknown option browse switch} \
          [s_ans ase::opt_browse ngspice -nosuchswitch 1]] >= 0}] 1

## ⚠ THE SEARCH IS ONLY AS GOOD AS THE HELP COLUMN, AND ONLY 64 OF 247 ROWS
## CARRY ONE. Issue 1437 deliberately did not mint 190 new sentences (⚖ R9 --
## they would be the user's to ratify), and block A's 57 carry ngspice's own
## description strings. But `units` -- the 57.2958x phase error, which 1437's
## own C104 calls "the single most consequential option in this batch" -- was
## one of the five sentences that receipt says ASE-L wrote, and the shipped row
## carried none. It does now, and this row is what keeps it.
check {FN10 the one option the batch cares most about has a sentence, and it names the factor} \
  [s_ans apply {{} {
     set h [ase::opt_help ngspice units]
     return [list [expr {$h ne {}}] [expr {[string first 57.2958 $h] >= 0}] \
                  [ase::opt_match ngspice units angle]] }}] {1 1 1}

check {FN11 and the help column is a real minority of the catalogue, so search leans on name and group} \
  [s_ans apply {{} {
     set n 0
     foreach o [ase::sim_option_names ngspice] {
       if {[ase::opt_help ngspice $o] ne {}} { incr n }
     }
     return [list [expr {$n >= 57}] [expr {$n < 120}]] }}] {1 1}

} fnerr]} { check {FN0 section FN ran to the end} "RAISED:$fnerr" {} }

# ============================================================================
# SECTION CH -- "CHANGED ONLY" IS THE DEFAULT VIEW (§7c-2)
# ============================================================================
if {[catch {

set CHST [s_state {{name reltol value 1e-4} {name gminsteps value 1}
                   {name frobnicate value 7} {name minbreak value 1n}}]

## ⚠ THE BENCH'S OWN ROWS, IN THE BENCH'S OWN ORDER. The `.state` file and the
## sheet must list the same things in the same order or the row ids the shared
## editor indexes with mean different rows in the two places.
check {CH1 the changed view is the rows this bench stores, in the bench's own order} \
  [s_ans ase::opt_browse ngspice -changed 1 -state $CHST] \
  {reltol gminsteps frobnicate minbreak}

## ⚠ AND A STORED ROW IS SHOWN EVEN WHEN ITS VALUE EQUALS THE DEFAULT. This is
## the row the whole design turns on. `PLAN.md` §7c-2 calls the changed view "a
## FILTER, not a feature, because the catalogue carries `default`" -- but the
## catalogue's default is NOT what makes it safe. `gminsteps` defaults to 1 and
## this bench stores 1; hiding it would mean that a WRONG default hides a row
## the user typed, which is the same defect §7a's own gminsteps note is about,
## pointing the other way and worse, because the user cannot see what is missing.
check {CH2 a stored row whose value equals the catalogue default is STILL in the view} \
  [expr {[lsearch -exact [ase::opt_browse ngspice -changed 1 -state $CHST] gminsteps] >= 0}] 1

check {CH3 the default column decides the ANNOTATION and never the visibility} \
  [list [s_ans ase::opt_stored_verdict ngspice $CHST reltol] \
        [s_ans ase::opt_stored_verdict ngspice $CHST gminsteps] \
        [s_ans ase::opt_stored_verdict ngspice $CHST frobnicate] \
        [s_ans ase::opt_stored_verdict ngspice $CHST minbreak]] \
  {changed default unknown nodefault}

## ⚠ THE THREE BLOCK-A ROWS WITH NO APPLICATION DEFAULT. `cktntask.c` gives
## `minbreak`, `maxopalter` and `maxevtiter` none, so the catalogue carries
## none, so the comparison CANNOT be made. They are shown and the annotation
## says so -- a view that guessed would be inventing evidence and one that
## called them unchanged would hide them.
check {CH4 the three defaultless block-A rows answer nodefault rather than changed} \
  [s_ans apply {{} {
     set out {}
     foreach n {minbreak maxopalter maxevtiter} {
       lappend out [ase::opt_stored_verdict ngspice \
         [dict create options [list [list name $n value 5]]] $n]
     }
     return $out }}] {nodefault nodefault nodefault}

## The catalogue can only compare for the rows that carry a default, and it is a
## minority: 65 of 247 when this landed. A row, rather than a footnote, because
## the changed view's usefulness is proportional to it.
check {CH5 the number of rows a default comparison is possible for is a real minority of the catalogue} \
  [s_ans apply {{} {
     set n 0
     foreach o [ase::sim_option_names ngspice] {
       if {[ase::opt_default ngspice $o] ne {}} { incr n }
     }
     return [list [expr {$n >= 57}] [expr {$n < [llength [ase::sim_option_names ngspice]] / 2}]] }}] {1 1}

check {CH6 an unstored catalogue row is NOT in the changed view but IS in show-all} \
  [list [expr {[lsearch -exact [ase::opt_browse ngspice -changed 1 -state $CHST] abstol] >= 0}] \
        [expr {[lsearch -exact [ase::opt_browse ngspice] abstol] >= 0}]] {0 1}

check {CH7 the changed view honours the search and the scope too} \
  [list [s_ans ase::opt_browse ngspice -changed 1 -state $CHST -needle relt] \
        [s_ans ase::opt_browse ngspice -changed 1 -state $CHST -scope {analysis op}]] \
  {reltol {gminsteps frobnicate}}

## ⚠ A STORED NAME THE CATALOGUE DOES NOT DESCRIBE STAYS IN THE LIST. §7a's
## rule: a catalogue is a claim about one simulator and a short one does not
## outrank the user. Scope-filtering it away would delete the user's own row
## from their own sheet.
## ⚠ AND A ROW THE BENCH DOES NOT STORE IS `unset`, WHICH IS NOT `nodefault`.
## Show-all asks this question about some 240 untouched rows; answering "no
## default to compare with" for a row that HAS one and is simply not set would be
## a wrong sentence on 65 rows of the sheet. The detail line draws nothing for it.
check {CH9 a row this bench does not store is `unset`, whether or not the catalogue gives it a default} \
  [list [s_ans ase::opt_stored_verdict ngspice $CHST abstol] \
        [s_ans ase::opt_stored_verdict ngspice $CHST maxopalter] \
        [s_ans ase::opt_stored_verdict ngspice $CHST zznosuchoptionanywhere]] \
  {unset unset unset}

check {CH8 a stored name the catalogue has never heard of survives every filter but the search} \
  [list [expr {[lsearch -exact [ase::opt_browse ngspice -changed 1 -state $CHST \
                  -scope {analysis tran}] frobnicate] >= 0}] \
        [expr {[lsearch -exact [ase::opt_browse ngspice -changed 1 -state $CHST \
                  -needle frob] frobnicate] >= 0}] \
        [expr {[lsearch -exact [ase::opt_browse ngspice -changed 1 -state $CHST \
                  -needle zzz] frobnicate] >= 0}]] {1 1 0}

} cherr]} { check {CH0 section CH ran to the end} "RAISED:$cherr" {} }

# ============================================================================
# SECTION DP -- ONE BODY FOR THE DECK LINES, SHARED WITH THE EMITTER
# ============================================================================
# ⚠ THIS IS §7c's NON-NEGOTIABLE MADE TESTABLE: "nothing the window shows may
# fail to reach the deck; nothing the deck contains may be unshowable in the
# window". Two bodies answering "what does this bench write" is two answers,
# with the preview as the one nobody runs.
if {[catch {

set DPOPTS {{name reltol value 1e-4} {name wnflag value 1}
            {name units value degrees} {name frobnicate value 7}
            {name casemode value preserve} {name sqrnoise value 1}
            {name acct value 1} {name savecurrents value 0}}
## A state shaped like the emitter's own callers: a design, a simulator, a run
## directory of this suite's own under tests/headless/.scratch. NOTHING IS RUN.
set DPDIR [file join $scratch rdeck] ; file mkdir $DPDIR
set DPST [dict create design [dict create lib L cell c1 view schematic] \
          simulator ngspice rundir $DPDIR options $DPOPTS \
          analyses {{type op enabled 1}} outputs {} temperature 27]
set DPNL "* t\nr1 a 0 1k\nv1 a 0 1\n.end\n"

check {DP1 every stored option gets exactly one record, in the bench's own order} \
  [s_ans apply {{} {
     set out {}
     foreach r [ase::opt_deck_plan ngspice $::DPST] { lappend out [lindex $r 0] }
     return $out }}] \
  {reltol wnflag units frobnicate casemode sqrnoise acct savecurrents}

check {DP2 the four statuses each have a member, and each says the right thing} \
  [s_ans apply {{} {
     set out {}
     foreach r [ase::opt_deck_plan ngspice $::DPST] {
       lappend out [lindex $r 0] [lindex $r 2]
     }
     return $out }}] \
  [join {reltol spelled wnflag spelled units fallback frobnicate fallback\
         casemode elsewhere sqrnoise spelled acct fallback savecurrents off}]

check {DP3 the spelled rows are the ONE speller's own lines, byte for byte} \
  [s_ans apply {{} {
     set out {}
     foreach r [ase::opt_deck_plan ngspice $::DPST] {
       if {[lindex $r 2] eq {spelled}} { lappend out [lindex $r 4] }
     }
     return $out }}] \
  {{.options reltol=1e-4} {.options wnflag=1} {.options sqrnoise}}

## ⚠ THE FALLBACK IS THE ADAPTER'S AND A BACKEND WITH NO HOOK GETS NONE (D34).
## `.options <name>=<value>` is ngspice syntax; core may not spell it, and the
## rule it encodes -- 0 writes nothing, 1 writes a bare card -- is the rule this
## tree shipped for years, kept for exactly the names the catalogue does not
## describe.
check {DP4 the fallback line comes from the adapter's hook and keeps the old rule} \
  [list [s_ans ase::opt_fallback_line ngspice frobnicate 7] \
        [s_ans ase::opt_fallback_line ngspice frobnicate 1] \
        [s_ans ase::opt_fallback_line ngspice frobnicate 0]] \
  {{.options frobnicate=7} {.options frobnicate} {}}

check {DP5 a backend with no option_fallback hook gets NO fallback content} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzdp [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_dpcat]
     proc ::ase_t_dpcat {} { return {} }
     set r [list [ase::opt_fallback_line zzdp anything 7] \
                 [ase::opt_deck_plan zzdp [dict create options {{name anything value 7}}]]]
     set ::ase::backends $save
     return $r }}] {{} {{anything 7 fallback {} {}}}}

## ⚠ AND THE SECOND HALF OF THAT GUARD IS A DIFFERENT STATE. `ase::backend_hook`
## RAISES for a hook a backend does not declare, so the `catch` above is what
## answers for a backend with none -- and the `$h eq {}` line below it can only
## be reached by a backend that declares the hook and leaves it EMPTY. That is
## the same defensive idiom `ase::sim_options`, `ase::sim_option_spell` and
## `ase::predeck_deliver` all use, and it is a line no fixture had ever built.
check {DP5b a backend that declares the hook and leaves it empty gets no fallback content either} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzdpe [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_dpcat \
       option_fallback {}]
     set r [ase::opt_fallback_line zzdpe anything 7]
     set ::ase::backends $save
     return $r }}] {}

## ⚠ THE BYTE-IDENTITY ROW. The deck the emitter renders must carry EXACTLY the
## option lines the shared body produces, in that order, and no others -- which
## is what makes the preview a preview rather than an illustration.
check {DP6 every line the shared body produces appears in the rendered deck, in order} \
  [s_ans apply {{} {
     set st $::DPST
     set deck [ase::backend::ngspice::render_deck $st $::DPNL]
     set want {}
     foreach r [ase::opt_deck_plan ngspice $st] {
       if {[lindex $r 4] ne {}} { lappend want [lindex $r 4] }
     }
     set got {}
     foreach l [split $deck "\n"] {
       if {[lsearch -exact $want [string trim $l]] >= 0} { lappend got [string trim $l] }
     }
     return [list $want $got] }}] \
  [s_ans apply {{} {
     set st $::DPST
     set want {}
     foreach r [ase::opt_deck_plan ngspice $st] {
       if {[lindex $r 4] ne {}} { lappend want [lindex $r 4] }
     }
     return [list $want $want] }}]

## ⚠ NON-VACUITY FOR DP6: the deck must not carry an `.options` card for an
## option row that the shared body reports NO line for. `casemode` is the
## measured case -- issue 1439 took its card out of the deck on purpose, and a
## preview that showed nothing while the deck carried one would be the defect
## §7c exists to prevent, in mirror image.
check {DP7 and an option the shared body writes no line for has no card in the deck either} \
  [s_ans apply {{} {
     set st $::DPST
     set deck [ase::backend::ngspice::render_deck $st $::DPNL]
     set bad {}
     foreach n {casemode savecurrents} {
       foreach l [split $deck "\n"] {
         if {[regexp "^\\.options +$n\\b" [string trim $l]]} { lappend bad $n }
       }
     }
     return $bad }}] {}

} dperr]} { check {DP0 section DP ran to the end} "RAISED:$dperr" {} }

# ============================================================================
# SECTION PV -- THE LIVE DECK PREVIEW (§7c-6)
# ============================================================================
if {[catch {

set PVST [s_state {{name reltol value 1e-4} {name units value degrees}
                   {name ngbehavior value hs} {name ps_tpz_delays value 3}
                   {name savecurrents value 0}}]
dict set PVST rundir /tmp/zz_optsheet_1441_never_run

check {PV1 the preview answers four slots and a notes block, always} \
  [lsort [dict keys [s_ans ase::opt_preview ngspice $PVST]]] \
  {cmdline control deck notes prefile}

check {PV2 the deck slot carries exactly the shared body's lines} \
  [s_ans apply {{} {
     set out {}
     foreach e [dict get [ase::opt_preview ngspice $::PVST] deck] { lappend out [lindex $e 1] }
     return $out }}] {{.options reltol=1e-4} {.options units=degrees}}

## ⚠ AND THE DECK SLOT CARRIES THE SPELLER'S SPELLING, NOT A GENERIC
## `name=value`. Every row of PVST happens to spell as `name=value`, so a preview
## that composed its own line would read identically on it -- fixtures that
## cannot disagree. A FLAG is what separates them: `sqrnoise` is a `CP_BOOL` and
## the line ASE-L emits is the VALUELESS `.options sqrnoise`, measured on both
## binaries to square the noise (3.147875e-07 -> 9.909116e-14) where
## `.options sqrnoise=1` leaves it alone. A preview that showed `sqrnoise=1`
## would be showing the user the spelling that silently turns the option OFF.
check {PV2b a flag previews as the valueless card the speller writes, never as name=value} \
  [s_ans apply {{} {
     set st [ase::state_default]
     dict set st options {{name sqrnoise value 1} {name keepopinfo value 1}}
     set out {}
     foreach e [dict get [ase::opt_preview ngspice $st] deck] { lappend out [lindex $e 1] }
     return $out }}] {{.options sqrnoise} {.options keepopinfo}}

## ⚠ THE PRE-DECK HALVES ARE THE SAME PLAN THE RUN USES, NOT A SECOND OPINION.
check {PV3 a command-line option appears on the command-line slot and nowhere else} \
  [s_ans apply {{} {
     set pv [ase::opt_preview ngspice $::PVST]
     set cmd {} ; foreach e [dict get $pv cmdline] { lappend cmd [lindex $e 1] }
     set pre {} ; foreach e [dict get $pv prefile] { lappend pre [lindex $e 1] }
     return [list $cmd $pre] }}] \
  {{{-D ngbehavior=hs}} {{set ps_tpz_delays=3}}}

## ⚠ AND THE CONVERSE GUARD, WHICH IS THE HALF PEOPLE FORGET. "A setting with
## no line in the preview is a setting that does nothing" must not be read
## backwards. `units` is read AFTER the circuit is loaded; the deck slot still
## carries the `.options units=degrees` card this tree writes today, and that
## card is MEASURED on both binaries to leave the phase in RADIANS -- the
## 57.2958x error no design in this batch caught. So the line is shown AND a
## note says it will not arrive.
check {PV4 a line that is written but cannot take effect is shown WITH a note saying so} \
  [s_ans apply {{} {
     set pv [ase::opt_preview ngspice $::PVST]
     set shown 0
     foreach e [dict get $pv deck] { if {[lindex $e 0] eq {units}} { set shown 1 } }
     set noted {}
     foreach n [dict get $pv notes] { if {[lindex $n 0] eq {units}} { set noted [lindex $n 1] } }
     return [list $shown $noted] }}] {1 refused}

check {PV5 a switched-off option shows no line and says why} \
  [s_ans apply {{} {
     set pv [ase::opt_preview ngspice $::PVST]
     set shown 0
     foreach e [dict get $pv deck] { if {[lindex $e 0] eq {savecurrents}} { set shown 1 } }
     set noted {}
     foreach n [dict get $pv notes] { if {[lindex $n 0] eq {savecurrents}} { set noted [lindex $n 1] } }
     return [list $shown $noted] }}] {0 off}

## ⚠ ONE NOTE PER OPTION. Both the pre-deck plan and the delivery report answer
## for an owned row, and printing both makes the pane look like two problems
## where there is one.
check {PV6 an option gets at most one note, however many readers have an opinion} \
  [s_ans apply {{} {
     set st [ase::state_default]
     dict set st options {{name casemode value preserve}}
     set seen {} ; set dup {}
     foreach n [dict get [ase::opt_preview ngspice $st] notes] {
       if {[lsearch -exact $seen [lindex $n 0]] >= 0} { lappend dup [lindex $n 0] }
       lappend seen [lindex $n 0]
     }
     return $dup }}] {}

## ⚠ THE `control` SLOT IS EMPTY TODAY AND THAT IS A FACT, NOT A PLACEHOLDER.
## No option line is written inside the analysis block by this tree -- §7e owns
## the emit-then-restore that will fill it. THE ROW EXISTS SO THE DAY IT FILLS,
## THIS FILE SAYS SO, and the state it is measured on is one that WOULD put a
## line there if anything did: `units` is a `run`-phase row whose only working
## door is the block.
check {PV7 nothing is written inside the analysis block yet -- §7e owns that slot} \
  [dict get [s_ans ase::opt_preview ngspice $PVST] control] {}

check {PV8 a bench that stores nothing previews four empty slots and no notes} \
  [s_ans apply {{} {
     set pv [ase::opt_preview ngspice [ase::state_default]]
     return [list [dict get $pv deck] [dict get $pv control] \
                  [dict get $pv cmdline] [dict get $pv prefile] [dict get $pv notes]] }}] \
  {{} {} {} {} {}}

## ⚠ THE FILE HALF IS REFUSED WHERE ⚖ R2 REFUSES IT, and the preview must not
## show a line that will not be written. A bench naming no run directory falls
## back to the shared one, so the file is refused and the row becomes a note.
check {PV9 a bench with no run directory shows no start-up file lines, and a note instead} \
  [s_ans apply {{} {
     set st [ase::state_default]
     dict set st options {{name ps_tpz_delays value 3}}
     set pv [ase::opt_preview ngspice $st]
     set noted {}
     foreach n [dict get $pv notes] { if {[lindex $n 0] eq {ps_tpz_delays}} { set noted [lindex $n 1] } }
     return [list [dict get $pv prefile] $noted] }}] {{} refused}

## ⚠ THE FILE HALF'S REFUSAL, ON THE ONE STATE `ase::predeck_plan` CANNOT
## PRODUCE. It never returns lines AND a refusal at once -- the refusal is
## applied per option inside its own loop -- so a preview built only from its own
## call can never exercise the guard that drops them, and a row over it would be
## one whose fixtures cannot disagree (this batch has hit that eighteen times).
## `ase::opt_preview` therefore takes the plan, as `ase::predeck_report` already
## does, and this row hands it the state the run could reach if that loop ever
## changed: lines to write, and a reason not to.
check {PV10 a plan that carries BOTH lines and a refusal writes no start-up file lines} \
  [s_ans apply {{} {
     set pl [dict create argv {{-D zz=1}} file {{set zz=1} {set yy=2}} \
                         refused {} filewhy {no run directory}]
     set pv [ase::opt_preview ngspice [ase::state_default] $pl]
     return [list [dict get $pv prefile] [llength [dict get $pv cmdline]]] }}] {{} 1}

## NON-VACUITY for PV10: the same plan WITHOUT the refusal does write them, so
## the row is measuring the guard rather than an empty list.
check {PV11 and the same plan without the refusal writes both of them} \
  [s_ans apply {{} {
     set pl [dict create argv {} file {{set zz=1} {set yy=2}} refused {} filewhy {}]
     set pv [ase::opt_preview ngspice [ase::state_default] $pl]
     set out {} ; foreach e [dict get $pv prefile] { lappend out [lindex $e 1] }
     return $out }}] {{set zz=1} {set yy=2}}

} pverr]} { check {PV0 section PV ran to the end} "RAISED:$pverr" {} }

# ============================================================================
# SECTION HK -- THE SCHEMA HALF NAMES NO NGSPICE FACT (D34/D36)
# ============================================================================
if {[catch {

## The same lexical assertion issues 1437 (HK3) and 1439 (HK2) make, over THIS
## pass's core procs. A core proc that spells an ngspice word has taken the
## wrong turn, and the check is the whole body rather than a reviewer's memory.
check {HK1 not one of the new core procs contains an ngspice literal} \
  [s_ans apply {{} {
     set bad {}
     foreach p {ase::opt_group ase::opt_scope ase::opt_in_scope ase::opt_results
                ase::opt_results_why ase::opt_help ase::opt_match ase::opt_browse
                ase::opt_group_index ase::opt_stored_verdict ase::opt_fallback_line
                ase::opt_deck_plan ase::opt_preview} {
       if {![llength [info commands ::$p]]} { lappend bad "$p MISSING" ; continue }
       set b [string tolower [s_nocomment [info body ::$p]]]
       foreach lit {reltol gminsteps keepopinfo casemode sqrnoise wnflag
                    savecurrents .options .control cp_bool cp_num ngspice
                    spiceinit "-d "} {
         if {[string first $lit $b] >= 0} { lappend bad [list $p $lit] }
       }
     }
     return $bad }}] {}

## ⚠ NON-VACUITY: the scanner must find a literal that IS there.
check {HK2 and the scanner is not merely silent -- the adapter's own fallback trips it} \
  [s_ans apply {{} {
     set b [string tolower [s_nocomment [info body ::ase::backend::ngspice::option_fallback]]]
     return [expr {[string first {.options} $b] >= 0}] }}] 1

## The four preview slots are ASE-L's vocabulary, fixed, so the GUI can label
## them without asking a simulator what to call them.
check {HK3 the preview's slot names are ASE-L's own and do not vary by backend} \
  [s_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzhk [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x sim_options ::ase_t_hkcat]
     proc ::ase_t_hkcat {} { return {} }
     set r [lsort [dict keys [ase::opt_preview zzhk [ase::state_default]]]]
     set ::ase::backends $save
     return $r }}] {cmdline control deck notes prefile}

## ⚠ THE PREFIXES ⚖ R9 RULING A1 part 3 DELIBERATELY KEPT IN CAPITALS, PINNED SO
## A LATER CONSISTENCY PASS CANNOT TIDY THEM AWAY IN GOOD FAITH. On 2026-09-15
## the user lowercased every word shouted for emphasis INSIDE a sentence in this
## batch -- VOLTAGE, DEGREES, both NOTs, ONE -- and KEPT these, because they are
## not emphasis: they label a CLASS OF ROW, the job a column heading would do if
## this sheet had one, and the repeated word in a fixed position is what makes
## the left edge of the detail line scannable.
##
## ⚠ THE USER WAS TOLD THE INTERFACE WOULD LOOK INCONSISTENT AS A RESULT and
## ruled anyway, which is exactly why the exception needs a row rather than a
## memory: the distinction is structural, and structural distinctions are the
## ones a later reader does not notice. The second foreach is the absence half --
## a guard against lowercasing must itself be tested against the lowercase form,
## or it is satisfied by a body that no longer contains the prefix at all.
check {HK4 the options sheet's row prefixes keep the capitals ruling A1 gave them} \
  [s_ans apply {{} {
     set b [info body ::ase::ui::optsheet_detail]
     set out {}
     ## ⚠ `if` RATHER THAN `expr ?:` ON PURPOSE. Tcl's expr takes `yes`/`no` as
     ## BOOLEAN LITERALS -- which is why RU8's idiom in test_ase_effective_1442
     ## works -- and rejects every other bareword, so a `? kept : GONE` here
     ## RAISES rather than answering. Measured while writing this row.
     foreach lit {{NOT OFFERED: } {SET ELSEWHERE: } {CLAMPED: } {SCOPED: }} {
       if {[string first $lit $b] >= 0} { lappend out kept } else { lappend out GONE }
     }
     foreach lit {{not offered: } {Not offered: } {set elsewhere: }} {
       if {[string first $lit $b] >= 0} { lappend out LOWERCASED } else { lappend out ok }
     }
     return $out }}] {kept kept kept kept ok ok ok}

## ⚠ AND THE OTHER PREFIX LIVES IN THE CATALOGUE, NOT IN THE WIDGET, so it needs
## a row of its own: `NOT MEASURED: ` opens the `results_why` of every option
## whose ⚠ badge no probe deck could settle. THE COUNT IS THE NON-VACUITY HALF --
## a row asserting only "each one that starts with the prefix is in capitals" is
## satisfied by a catalogue in which none of them starts with it any more. The
## `bad` list is the lowercase half: a reason that opens `not measured` in any
## casing names itself here rather than vanishing from the count.
check {HK5 every unsettled badge reason still opens with the NOT MEASURED prefix\
 ruling A1 kept, and there are ten of them} \
  [s_ans apply {{} {
     set n 0 ; set bad {}
     foreach name [ase::sim_option_names ngspice] {
       set w [ase::opt_results_why ngspice $name]
       if {$w eq {}} { continue }
       if {[string match {NOT MEASURED: *} $w]} { incr n ; continue }
       if {[string match -nocase {not measured*} $w]} { lappend bad $name }
     }
     return [list $n $bad] }}] {10 {}}

} hkerr]} { check {HK0 section HK ran to the end} "RAISED:$hkerr" {} }

# ============================================================================
# SECTION UI -- THE SHEET ITSELF (needs an X connection; self-skips without one)
# ============================================================================
if {![info exists ::has_x] || [info commands winfo] eq {}} {
  puts "SKIPPED: section UI needs an X connection (no ::has_x)"
} else {
if {[catch {

set sch_text "v {xschem version=3.4.8 file_version=1.3}\nG {}\nK {}\nV {}\nS {}\nE {}\n"
file mkdir [file join $scratch aselib nfet_ui schematic]
set f [open [file join $scratch aselib nfet_ui schematic nfet_ui.sch] w]
puts -nonewline $f $sch_text
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
library_new_view aselib nfet_ui ngspice_state1 ngspice_state1
set ukey [ase::session_key aselib nfet_ui ngspice_state1]
check_true {UI1 the fixture bench opens} [ase::open_state aselib nfet_ui ngspice_state1]
update
set top [ase::ui::window_for $ukey]
set st [ase::session_state $ukey]
dict set st options {{name reltol value 1e-4} {name units value degrees}
                     {name savecurrents value 0}}
ase::session_update $ukey $st
update

$top.mb.sim invoke "Options…"
update
check_true {UI2 Simulation > Options opens the sheet, at the path the list dialog had} \
  [winfo exists $top.simopt]

## ⚠ EVERY GESTURE THE LIST DIALOG HAD STILL WORKS, AND THAT IS DELIBERATE --
## the changed view IS the stored rows with the SAME integer ids, so the shared
## row editor indexes the same rows. test_ase_dialogs' G6 and GE9 drive exactly
## these paths and neither moved.
check_true {UI3 the finder bar, the badge column, the detail line and the preview pane are all up} \
  [expr {[winfo exists $top.simopt.bar.find] && [winfo exists $top.simopt.bar.all] \
      && [winfo exists $top.simopt.bar.scope] && [winfo exists $top.simopt.detail] \
      && [winfo exists $top.simopt.prev.t] && [winfo exists $top.simopt.tv] \
      && [winfo exists $top.simopt.ctx] && [winfo exists $top.simopt.btns.close]}]

check {UI4 the DEFAULT view is this bench's own rows, with integer ids in state order} \
  [$top.simopt.tv children {}] {0 1 2}

check {UI5 and the rows show the stored name and value} \
  [list [lindex [$top.simopt.tv item 0 -values] 0] \
        [lindex [$top.simopt.tv item 0 -values] 1] \
        [lindex [$top.simopt.tv item 1 -values] 0]] {reltol 1e-4 units}

## ⚠ THE BADGE, ON THE SURFACE. `units` is MEASURED to change a number and
## carries one; `reltol` claims nothing and carries none.
check {UI6 the badge column carries the measured phrase and leaves an unclaimed row blank} \
  [list [lindex [$top.simopt.tv item 0 -values] 2] \
        [lindex [$top.simopt.tv item 1 -values] 2]] \
  [list {} [ase::ui::optsheet_badge ngspice units]]

check {UI7 and the three badge phrases are distinguishable, with the unverified one saying so} \
  [list [ase::ui::optsheet_badge ngspice sqrnoise] \
        [ase::ui::optsheet_badge ngspice warn] \
        [expr {[string first UNVERIFIED [ase::ui::optsheet_badge ngspice xtrtol]] >= 0}]] \
  [list "⚠ CHANGES RESULTS" {} 1]

## The live search: type, and the sheet narrows without a Return.
set ::ase::ui::optsheet($ukey,needle) relt
ase::ui::optsheet_fill $ukey
update
check {UI8 the live search narrows the changed view as you type} \
  [$top.simopt.tv children {}] 0

set ::ase::ui::optsheet($ukey,needle) zznosuch
ase::ui::optsheet_fill $ukey
update
check {UI9 a needle nothing matches empties the sheet, never falls back to all of it} \
  [$top.simopt.tv children {}] {}
set ::ase::ui::optsheet($ukey,needle) {}

## Show all: the other ~240 rows, in GROUPS rather than an alphabet.
set ::ase::ui::optsheet($ukey,showall) 1
ase::ui::optsheet_fill $ukey
update
check_true {UI10 Show all switches to group parents, one per drawer, each naming its count} \
  [expr {[llength [$top.simopt.tv children {}]] > 5
      && [string match grp:* [lindex [$top.simopt.tv children {}] 0]]
      && [regexp {\(\d+\)$} [$top.simopt.tv item [lindex [$top.simopt.tv children {}] 0] -text]]}]

check_true {UI11 and a stored row keeps its INTEGER id under its group, so the editor still finds it} \
  [expr {[lsearch -exact [$top.simopt.tv children grp:tolerances] 0] >= 0}]

check_true {UI12 an unstored catalogue row is present under its own group with a name-keyed id} \
  [expr {[lsearch -exact [$top.simopt.tv children grp:tolerances] opt:abstol] >= 0}]

## The scope selector, which is §7c-4's second surface.
set ::ase::ui::optsheet($ukey,scope) tran
ase::ui::optsheet_fill $ukey
update
check_true {UI13 a scope pick filters the catalogue to the rows that analysis offers} \
  [expr {[llength [$top.simopt.tv children grp:iteration]] > 0
      && [lsearch -exact [$top.simopt.tv children grp:iteration] opt:itl4] >= 0
      && [lsearch -exact [$top.simopt.tv children grp:iteration] opt:itl1] < 0}]
set ::ase::ui::optsheet($ukey,scope) Global
set ::ase::ui::optsheet($ukey,showall) 0
ase::ui::optsheet_fill $ukey
update

## ⚠ THE PREVIEW PANE, AND IT IS THE POINT OF THE SHEET.
set uitxt [$top.simopt.prev.t get 1.0 end]
check_true {UI14 the preview pane names all four slots, every time} \
  [expr {[string first {above the analysis block} $uitxt] >= 0
      && [string first {inside the analysis block} $uitxt] >= 0
      && [string first {on the command line} $uitxt] >= 0
      && [string first {in the run-directory start-up file} $uitxt] >= 0}]

check_true {UI15 it shows the exact lines this bench will emit} \
  [expr {[string first {.options reltol=1e-4} $uitxt] >= 0
      && [string first {.options units=degrees} $uitxt] >= 0}]

check_true {UI16 a setting with no line shows none, and the empty slots say so} \
  [expr {[string first {.options savecurrents} $uitxt] < 0
      && [string first {(nothing)} $uitxt] >= 0}]

check_true {UI17 and the note that a shown line will not arrive is on the pane too} \
  [expr {[string first {not delivered} $uitxt] >= 0
      && [string first units $uitxt] >= 0}]

## The detail line: what the selected row is, in words.
$top.simopt.tv selection set 0
ase::ui::optsheet_detail $ukey
update
check_true {UI18 selecting a row says what it is and what the bench has done to it} \
  [expr {[string first {Relative error tolerence} [$top.simopt.detail cget -text]] >= 0
      && [string first {CHANGED from the default 1e-3} [$top.simopt.detail cget -text]] >= 0}]

## ⚠ AND THE ONE ROW THE BATCH CARES MOST ABOUT HAD NOTHING TO SAY. `units` is
## the 57.2958x phase error -- issue 1437's own C104 calls it "the single most
## consequential option in this batch" -- and it was the ONE of the five help
## lines that receipt mints which the shipped catalogue did not carry, so its
## detail line was the badge and nothing else. It has a sentence now.
$top.simopt.tv selection set 1
ase::ui::optsheet_detail $ukey
update
check_true {UI18b the units row says what it is, and names the factor} \
  [expr {[string first {angle unit} [$top.simopt.detail cget -text]] >= 0
      && [string first 57.2958 [$top.simopt.detail cget -text]] >= 0}]

## ⚠ AND THE PREVIEW IS LIVE. A commit through the shared editor must repaint
## it -- a preview that went stale the moment the user changed something would
## be worse than none, because they would believe it.
$top.simopt.ctx invoke "Add…"
update
$top.optrow.name insert 0 sqrnoise
$top.optrow.value insert 0 1
event generate $top.optrow.value <Return>
update
check_true {UI19 a commit through the shared row editor repaints the preview at once} \
  [expr {[string first {.options sqrnoise} [$top.simopt.prev.t get 1.0 end]] >= 0}]
check {UI20 and the new row is in the changed view, with its measured badge} \
  [lindex [$top.simopt.tv item 3 -values] 2] "⚠ CHANGES RESULTS"

$top.simopt.tv selection set 3
$top.simopt.ctx invoke Delete
update
check_true {UI21 Delete through the shared editor removes the row and repaints the preview} \
  [expr {[llength [$top.simopt.tv children {}]] == 3
      && [string first {.options sqrnoise} [$top.simopt.prev.t get 1.0 end]] < 0}]

## §7c-4's second entry point: the analysis form's Options… dialog opens the
## SAME sheet with the scope preset to the type being edited.
$top.mb.analyses invoke "Choose…"
update
set ::ase::ui::dlg($ukey,antype) tran
ase::ui::chana_show $ukey
update
check_true {UI22 the analysis form's Options dialog carries the second entry point} \
  [expr {[winfo exists $top.chana] && [ase::ui::chana_options $ukey] ne {}
      && [winfo exists $top.chana.x.btns.simopts]}]
$top.chana.x.btns.simopts invoke
update
check {UI23 and it opens the sheet already scoped to that analysis} \
  [ase::ui::optsheet_scope $ukey] {analysis tran}
check_true {UI24 which is the same sheet, not a second one} \
  [expr {[winfo exists $top.simopt] && ![winfo exists $top.chana.simopt]}]

catch {destroy $top.simopt}
catch {$top.chana.x.btns.cancel invoke}
catch {$top.chana.btns.cancel invoke}
update
ase::ui::close $ukey
update

} uierr]} { check {UI0 section UI ran to the end} "RAISED:$uierr" {} }
}

# ============================================================================
puts ""
if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456). `tests/banner_rule.tcl`'s `banner_complete`
# requires a WHOLE-LINE `OVERALL: ok`, and `run_regression.tcl` counts a case with
# no banner as a HARNESS failure however green its own checks are. This suite is in
# T1's case list, so without this line it was a standing red from the day it joined.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
exit [expr {$fail ? 1 : 0}]
