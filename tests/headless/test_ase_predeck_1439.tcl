# tests/headless/test_ase_predeck_1439.tcl -- ISSUE 1439: THE PRE-DECK CLASS
# AND THE INERT LIST. PLAN.md Stage 7d, ⚖ R2's four conditions.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# FIVE COMMITTED BENCHES ASK FOR `wnflag` AND, UNTIL THIS ISSUE, NONE OF THEM
# GOT IT. `wnflag` decides whether a MOS `W` is the total width or the width
# per finger. MEASURED on BOTH binaries, on a flat `m` line AND on the sky130
# `x`-line shape, with two binned models 0.4 V apart:
#
#   .options wnflag       -> @m1[vth] 9.888996e-01   i(vd) -1.01728e-03   <- ASE-L
#   .options wnflag=1     -> @m1[vth] 5.888996e-01   i(vd) -1.73730e-03
#   set wnflag=1 (.control) -> 9.888996e-01                               <- too late
#   -D wnflag=1           -> 9.888996e-01                                 <- CP_STRING
#   <rundir>/.spiceinit `set wnflag=1` -> 5.888996e-01                    <- works
#
# A 71% difference in drain current, at rc 0, with a clean log and nothing said
# by anything. The user asked for W per finger and got W total.
#
# ⚠ AND THE ROOT CAUSE IS NOT THE ONE ISSUE 1438 NAMED. 1438 says `wnflag` is
# unreachable from `.options` because one of its three read sites runs during
# card reading. MEASURED IN THE SOURCE: two of the three are DEAD.
# `inpcom.c:990` reads it into a local `inp_get_w_l_x()` never uses again, and
# `inp.c:2828` is inside `#ifdef REM_UNUSED`, which is defined NOWHERE in the
# ngspice tree. The one live read is `inpgmod.c:268`, in `INPgetModBin()`, at
# model-binning time -- AFTER the `.options` cards become `ci_vars`. So the
# wrong door was the VALUE, not the phase: `wnflag` is a `deck` option and the
# fix is `.options wnflag=1`, which is issue 1438's defect 2.
#
# ============================================================================
# WHAT THIS FILE IS ABOUT
# ============================================================================
# The THIRTY-TWO options reachable from neither `.options` nor `.control`, the
# two doors that do reach them, the two refusals that close the file half, and
# the emitter finally asking what kind of option it is writing.
#
# ⚠ NO SIMULATOR IS STARTED HERE. Every ngspice fact quoted was measured
# beforehand against BOTH preflight binaries -- the fork
# (/home/analog/dev/ngspice/build-ver_50/src/ngspice, ngspice-46+) and the apt
# build (/usr/bin/ngspice, ngspice-45.2) -- and against the C source at
# /home/analog/dev/ngspice (ver_50, ccebdf2a2). The rows assert what ASE-L does
# with those facts, which is pure Tcl and pure file I/O in a scratch directory.
#
# ⚠ NOTHING HERE READS, WRITES, MOVES OR BACKS UP $HOME/.spiceinit. The user's
# own start-up file is reached only by `ase::backend::ngspice::predeck_user_file`,
# which opens it `r`, and section UF drives that proc with $HOME redirected into
# this suite's own scratch tree.
#
# ============================================================================
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
#    78  the count when this file landed (2026-09-13, issue 1439), identical on
#        BOTH arms -- there is no widget here, so the display arm runs the same
#        rows and must print the same number.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_predeck_1439.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_predeck_1439.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch predeck1439]

proc p_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc p_raise {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {!$rc} { return {} }
  return $r
}
## Comments out of a proc body, so a lexical row asserts CODE and not prose.
proc p_nocomment {body} {
  set out {}
  foreach l [split $body "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc p_state {args} {
  set st [dict create design [dict create lib L cell c1 view schematic] \
                      simulator ngspice rundir {} options {} \
                      analyses {{type op enabled 1}} outputs {} temperature 27]
  foreach {k v} $args { dict set st $k $v }
  return $st
}
proc p_opts {args} {
  set o {}
  foreach {n v} $args { lappend o [list name $n value $v] }
  return $o
}
## ⚠ HERMETIC ABOUT THE SIMULATOR REGISTRY, AND IT WAS MEASURED. The developer
## running this suite may have a simulator of their own saved in
## USER_CONF_DIR/ase_simulators, which xschem.tcl reads at startup -- and if
## that entry carries `-n`, then "nothing is registered" is FALSE in this very
## process and six rows redden on a tree with nothing wrong with it. The clear
## is in-memory only: ase::sim_clear writes no file.
##
## ⚠ AND NOTHING HERE CALLS ase::sim_register. Registration PERSISTS -- it
## reaches ase::sim_touch -> ase::sim_write_conf -> the developer's real
## ~/.xschem/ase_simulators. A suite whose subject is writing files must not
## write that one, so the `-n` rows stub the one predicate they need instead.
catch {ase::sim_clear}

proc p_nospiceinit {script} {
  if {![llength [info commands ::ase::sim_nospiceinit]]} { return NOPROC }
  rename ::ase::sim_nospiceinit ::ase::__sim_nospiceinit_real
  proc ::ase::sim_nospiceinit {backend} { return 1 }
  set rc [catch {uplevel #0 $script} r]
  rename ::ase::sim_nospiceinit {}
  rename ::ase::__sim_nospiceinit_real ::ase::sim_nospiceinit
  if {$rc} { return "RAISED:$r" }
  return $r
}

proc p_read {path} {
  if {![file isfile $path]} { return NOFILE }
  set f [open $path r] ; set t [read $f] ; close $f
  return $t
}

# ============================================================================
# SECTION PD -- THE PLAN: WHICH OPTION GOES THROUGH WHICH DOOR
# ============================================================================
if {[catch {

set PDDIR [file join $scratch rd1]
file mkdir $PDDIR

check {PD1 a bench with no pre-deck option plans nothing, which is every bench in this tree today} \
  [p_ans ase::predeck_plan ngspice [p_state rundir $PDDIR options [p_opts reltol 1e-5 savecurrents 1]]] \
  {argv {} file {} refused {} filewhy {}}

## MEASURED on both binaries: `-D ngbehavior=hs` prints `Note: Compatibility
## modes selected: hs`; `-D mingwpath` arrives as a valueless CP_BOOL.
check {PD2 a pre-deck bool and a pre-deck string go on the command line} \
  [dict get [p_ans ase::predeck_plan ngspice \
     [p_state rundir $PDDIR options [p_opts ngbehavior hs mingwpath 1]]] argv] \
  {{-D ngbehavior=hs} {-D mingwpath}}

## MEASURED on both binaries: a `set ticlist = ( 1 2 3 )` line in the run
## directory's start-up file arrives as a CP_LIST; `-D` cannot carry one.
check {PD3 a pre-deck number and a pre-deck list go into the run-directory file} \
  [dict get [p_ans ase::predeck_plan ngspice \
     [p_state rundir $PDDIR options [p_opts ps_tpz_delays 1 sourcepath {/a /b}]]] file] \
  {{set ps_tpz_delays=1} {set sourcepath = ( /a /b )}}

check {PD4 the two doors are planned separately from one bench} \
  [p_ans apply {{} {
     global PDDIR
     set p [ase::predeck_plan ngspice [p_state rundir $PDDIR \
              options [p_opts ngbehavior hs ps_tpz_delays 1 reltol 1e-5]]]
     return [list [dict get $p argv] [dict get $p file] [dict get $p refused]] }}] \
  {{{-D ngbehavior=hs}} {{set ps_tpz_delays=1}} {}}

## ⚠ NON-VACUITY for PD1: an option this simulator does not describe is not a
## pre-deck option and is not refused either -- it is simply none of this
## mechanism's business, and render_deck still writes it.
check {PD5 an option the catalogue does not know is not planned and not refused} \
  [p_ans ase::predeck_plan ngspice \
     [p_state rundir $PDDIR options [p_opts frobnicate 1]]] \
  {argv {} file {} refused {} filewhy {}}

## Absence IS off for a pre-deck flag, exactly as it is everywhere else: there
## is no spelling for "off", so a switched-off row plans no line at all.
check {PD6 a pre-deck flag that is switched off plans nothing, because absence is the setting} \
  [p_ans apply {{} {
     global PDDIR
     set p [ase::predeck_plan ngspice [p_state rundir $PDDIR options [p_opts mingwpath 0]]]
     return [list [dict get $p argv] [dict get $p refused]] }}] {{} {}}

## ⚠ AND ZERO IS A VALUE FOR A NUMBER. The same defect issue 1438 names in the
## emitter would be a defect here: `set ps_tpz_delays=0` is a real setting.
check {PD7 zero is written for a pre-deck number, never dropped} \
  [dict get [p_ans ase::predeck_plan ngspice \
     [p_state rundir $PDDIR options [p_opts ps_tpz_delays 0]]] file] \
  {{set ps_tpz_delays=0}}

check {PD8 the argv half flattens to command-line words, in bench order} \
  [p_ans ase::predeck_argv ngspice \
     [p_state rundir $PDDIR options [p_opts ngbehavior hs mingwpath 1]]] \
  {-D ngbehavior=hs -D mingwpath}

check {PD9 a bench with nothing pre-deck contributes no command-line words at all} \
  [p_ans ase::predeck_argv ngspice [p_state rundir $PDDIR options [p_opts reltol 1e-5]]] {}

} pderr]} { check {PD0 section PD ran to the end} "RAISED:$pderr" {} }

# ============================================================================
# SECTION RF -- THE TWO REFUSALS, ⚖ R2 CONDITION 4
# ============================================================================
# Both must NAME what they are refusing over. A refusal the user cannot act on
# is a silence with extra words.
if {[catch {

set RFDIR [file join $scratch rd2]
file mkdir $RFDIR

## C19: ase::rundir falls back to `set_netlist_dir 0` -- ONE directory shared
## by every cell, by every state of every cell, and by xschem's own netlister.
## An audit agent's run into it destroyed a user's 20502-point rawfile once.
check {RF1 a bench that names no run directory is refused the file, and the refusal says what to do} \
  [p_ans apply {{} {
     set p [ase::predeck_plan ngspice [p_state rundir {} options [p_opts ps_tpz_delays 1]]]
     return [list [dict get $p file] \
                  [string match {*names no run directory*} [dict get $p filewhy]] \
                  [string match {*set a run directory first*} [dict get $p filewhy]] \
                  [llength [dict get $p refused]]] }}] {{} 1 1 1}

check {RF2 the predicate is about the FALLBACK, not about a path that happens to match} \
  [list [p_ans ase::rundir_is_shared [p_state rundir {}]] \
        [p_ans ase::rundir_is_shared [p_state rundir $RFDIR]]] {1 0}

## ⚠ A ROW WHOSE FIXTURES NEVER DISAGREE CANNOT FAIL, AND RF2's DID NOT.
## Sabotage S07 -- comparing the RESOLVED PATH instead of the state key --
## SURVIVED it, because for both of RF2's benches the two rules give the same
## answer. The state that tells them apart is a bench whose rundir is spelled
## out AND happens to be the shared one: the fallback was not taken, the user
## typed that directory, and refusing them there would be refusing a choice
## they made. Comparing paths would also call `set_netlist_dir`, a live xschem
## command with a session of its own, from a predicate.
check {RF2b a bench that spells out the shared directory has made a choice, and is not refused} \
  [p_ans apply {{} {
     set shared {}
     if {[catch {set shared [set_netlist_dir 0]}]} { return SKIP }
     if {$shared eq {}} { return SKIP }
     return [list [ase::rundir_is_shared [p_state rundir $shared]] \
                  [ase::rundir_is_shared [p_state rundir {}]]] }}] {0 1}

## MEASURED on both binaries: the same deck gave `ours 1` with the file
## honoured and nothing at all with `-n`, and the only thing printed was a
## resistor warning.
check {RF3 an entry that asks to skip start-up files is refused the file, by name, and the option is reported} \
  [p_nospiceinit {
     global RFDIR
     set p [ase::predeck_plan ngspice [p_state rundir $RFDIR options [p_opts ps_tpz_delays 1]]]
     list [dict get $p file] \
          [string match {*skip start-up files*} [dict get $p filewhy]] \
          [lindex [dict get $p refused] 0 0] }] {{} 1 ps_tpz_delays}

## ⚠ AND THE COMMAND-LINE DOOR IS **NOT** REFUSED BY EITHER, WHICH REFUTES
## `PLAN.md` §7d's "every pre-deck option ... refused when -n is in force".
## MEASURED on both binaries: `ngspice -b -n -D ngbehavior=hs <deck>` still
## prints `Note: Compatibility modes selected: hs` and the variable is in
## force. ⚖ R2's own text refuses THE FILE. Refusing `-D` too would delete
## `-D casemode=`, which this tree already emits under `-n` today.
check {RF4 -n and the shared run directory close the file and leave the command line open} \
  [p_nospiceinit {
     set p [ase::predeck_plan ngspice [p_state rundir {} options [p_opts ngbehavior hs]]]
     list [dict get $p argv] [dict get $p file] [dict get $p refused] }] \
  {{{-D ngbehavior=hs}} {} {}}

check {RF5 a refused pre-deck option is reported with the reason, never dropped in silence} \
  [p_ans apply {{} {
     set p [ase::predeck_plan ngspice [p_state rundir {} options [p_opts ps_tpz_delays 1]]]
     set say [ase::predeck_report ngspice {} $p {}]
     return [list [llength $say] \
                  [string match {option 'ps_tpz_delays' will not reach the simulator: *} [lindex $say 0]]] }}] \
  {1 1}

} rferr]} { check {RF0 section RF ran to the end} "RAISED:$rferr" {} }

# ============================================================================
# SECTION FW -- THE FILE WRITER, ⚖ R2 CONDITIONS 1 AND 2
# ============================================================================
if {[catch {

set FWDIR [file join $scratch rd3]
file mkdir $FWDIR
set FWST [p_state rundir $FWDIR]
set FWPATH [p_ans ase::backend::ngspice::predeck_file $FWST]

check {FW1 the file is the run directory's, and it is named for the simulator that reads it} \
  [list [file dirname $FWPATH] [file tail $FWPATH]] [list $FWDIR .spiceinit]

check {FW2 writing puts ASE-L's marker first and the bench's lines last} \
  [p_ans apply {{} {
     global FWST FWPATH
     set rep [ase::backend::ngspice::predeck_write $FWST {{set ps_tpz_delays=1}}]
     set txt [p_read $FWPATH]
     set ls [split [string trimright $txt "\n"] "\n"]
     return [list [dict get $rep status] [dict get $rep wrote] \
                  [expr {[lindex $ls 0] eq [ase::backend::ngspice::predeck_marker]}] \
                  [lindex $ls end]] }}] \
  {written 1 1 {set ps_tpz_delays=1}}

## ⚖ R2 CONDITION 1. A stale one is indistinguishable from a live one -- and
## unlike a stale rawfile it also SHADOWS the user's own file while it sits
## there, so it is deleted even when this run has nothing to put in it.
check {FW3 a run with nothing pre-deck deletes the file rather than leaving last run's settings in force} \
  [p_ans apply {{} {
     global FWST FWPATH
     ase::backend::ngspice::predeck_write $FWST {{set ps_tpz_delays=1}}
     set before [file exists $FWPATH]
     set rep [ase::backend::ngspice::predeck_write $FWST {}]
     return [list $before [dict get $rep status] [file exists $FWPATH]] }}] {1 removed 0}

check {FW4 a second run rewrites rather than appends} \
  [p_ans apply {{} {
     global FWST FWPATH
     ase::backend::ngspice::predeck_write $FWST {{set ps_tpz_delays=1}}
     ase::backend::ngspice::predeck_write $FWST {{set ps_tpz_delays=2}}
     set txt [p_read $FWPATH]
     return [list [regexp -all {set ps_tpz_delays} $txt] \
                  [expr {[string first {set ps_tpz_delays=2} $txt] >= 0}]] }}] {1 1}

## ⚠ THE ONE THING THIS FEATURE MUST NEVER DO. A file in that path that ASE-L
## did not write is somebody's, and a task whose subject is writing start-up
## files is exactly the task that could destroy one.
check {FW5 a file ASE-L did not write is left exactly as it was, and the run says so} \
  [p_ans apply {{} {
     global FWST FWPATH
     catch {file delete -- $FWPATH}
     set f [open $FWPATH w] ; puts $f "set theirs=1" ; close $f
     set rep [ase::backend::ngspice::predeck_write $FWST {{set ps_tpz_delays=1}}]
     set txt [p_read $FWPATH]
     catch {file delete -- $FWPATH}
     return [list [dict get $rep status] $txt] }}] \
  [list foreign "set theirs=1\n"]

check {FW6 the foreign file is reported to the user, not worked around in silence} \
  [p_ans apply {{} {
     global FWST FWPATH
     catch {file delete -- $FWPATH}
     set f [open $FWPATH w] ; puts $f "set theirs=1" ; close $f
     set rep [ase::backend::ngspice::predeck_write $FWST {{set ps_tpz_delays=1}}]
     set say [ase::predeck_report ngspice $FWST \
                [dict create argv {} file {} refused {} filewhy {}] $rep]
     catch {file delete -- $FWPATH}
     return [list [llength $say] [string match {*was not written by ASE-L*} [lindex $say 0]]] }}] \
  {1 1}

} fwerr]} { check {FW0 section FW ran to the end} "RAISED:$fwerr" {} }

# ============================================================================
# SECTION UF -- COPYING THE USER'S OWN FILE, ⚖ R2 CONDITIONS 2 AND 3
# ============================================================================
# ⚠ MEASURED, AND THE DOSSIER'S REASON IS NARROWER THAN IT SAYS -- WHICH MAKES
# COPYING MORE NECESSARY, NOT LESS. `[R-M7]` says `source <user file>` parses
# the target as a netlist and loses the variables. On both binaries that is
# true ONLY when the path does not contain `.spiceinit` or `spice.rc`:
#
#   source .../uinit/.spiceinit  -> frobnicate and uservar 7 both arrive
#   source .../uinit/spice.rc    -> both arrive
#   source .../uinit/myinit.txt  -> `Circuit: set frobnicate`,
#                                   `Unable to find definition of model`,
#                                   and the user's variables are GONE
#
# `com_source` (inp.c:1984) is `substring(INITSTR, owl->wl_word)` -- a plain
# substring test on the word that was typed. A mechanism that depends on a
# substring of a path ASE-L composes is not a mechanism.
if {[catch {

set UFDIR [file join $scratch rd4]
set UFHOME [file join $scratch fakehome]
file mkdir $UFDIR $UFHOME
set UFST [p_state rundir $UFDIR]
set UFPATH [p_ans ase::backend::ngspice::predeck_file $UFST]

proc p_withhome {home script} {
  set had [info exists ::env(HOME)] ; set old {}
  if {$had} { set old $::env(HOME) }
  set hadu [info exists ::env(SPICE_USERINIT_DIR)] ; set oldu {}
  if {$hadu} { set oldu $::env(SPICE_USERINIT_DIR) }
  catch {unset ::env(SPICE_USERINIT_DIR)}
  set ::env(HOME) $home
  set rc [catch {uplevel #0 $script} r]
  if {$had} { set ::env(HOME) $old } else { catch {unset ::env(HOME)} }
  if {$hadu} { set ::env(SPICE_USERINIT_DIR) $oldu }
  if {$rc} { return "RAISED:$r" }
  return $r
}

check {UF1 with no start-up file of the user's there is nothing to shadow} \
  [p_withhome $UFHOME {ase::backend::ngspice::predeck_user_file}] {}

check {UF2 the user's own file is found in their home directory} \
  [p_withhome $UFHOME {
     set f [open [file join $::env(HOME) .spiceinit] w] ; puts $f "set frobnicate" ; close $f
     ase::backend::ngspice::predeck_user_file }] [file join $UFHOME .spiceinit]

## The other documented location, and it wins -- ngspice looks there before
## $HOME (main.c's own comment lists the order).
check {UF3 SPICE_USERINIT_DIR is searched before the home directory} \
  [p_ans apply {{} {
     global UFHOME scratch
     set alt [file join $scratch userinit] ; file mkdir $alt
     set f [open [file join $alt .spiceinit] w] ; puts $f "set alt" ; close $f
     set had [info exists ::env(HOME)] ; set old {} ; if {$had} { set old $::env(HOME) }
     set ::env(HOME) $UFHOME ; set ::env(SPICE_USERINIT_DIR) $alt
     set r [ase::backend::ngspice::predeck_user_file]
     catch {unset ::env(SPICE_USERINIT_DIR)}
     if {$had} { set ::env(HOME) $old } else { catch {unset ::env(HOME)} }
     return $r }}] [file join $scratch userinit .spiceinit]

check {UF4 the user's lines are COPIED in under a banner, and ASE-L's come after them so the bench wins} \
  [p_withhome $UFHOME {
     global UFST UFPATH
     set rep [ase::backend::ngspice::predeck_write $UFST {{set ps_tpz_delays=1}}]
     set ls [split [string trimright [p_read $UFPATH] "\n"] "\n"]
     list [dict get $rep shadows] \
          [expr {[lsearch -exact $ls {set frobnicate}] >= 0}] \
          [expr {[lsearch -exact $ls {set frobnicate}] < \
                 [lsearch -exact $ls {set ps_tpz_delays=1}]}] \
          [expr {[string first {source } [join $ls "\n"]] < 0}] }] \
  [list [file join $UFHOME .spiceinit] 1 1 1]

## ⚠ AND "FIRST" IS NOT THE CLAIM -- "LAST" IS. Sabotage S21 -- appending the
## user's lines AFTER the bench's, so their global default wins -- SURVIVED UF4,
## because `lsearch -exact` finds the FIRST copy and the row only asked about
## an ordering, not about what the simulator reads last. `set` is last-writer-
## wins, so the only question that matters is which line is at the bottom.
check {UF4b the bench's own line is the last one in the file, and the user's appears once} \
  [p_withhome $UFHOME {
     global UFST UFPATH
     ase::backend::ngspice::predeck_write $UFST {{set ps_tpz_delays=1}}
     set ls [split [string trimright [p_read $UFPATH] "\n"] "\n"]
     list [lindex $ls end] \
          [llength [lsearch -all -exact $ls {set frobnicate}]] }] \
  [list {set ps_tpz_delays=1} 1]

check {UF5 the banner names the file being copied, so a reader knows whose lines those are} \
  [p_withhome $UFHOME {
     global UFST UFPATH
     ase::backend::ngspice::predeck_write $UFST {{set ps_tpz_delays=1}}
     set txt [p_read $UFPATH]
     list [expr {[string first "* copied from [file join $::env(HOME) .spiceinit]" $txt] >= 0}] \
          [expr {[string first {shadows it for this run} $txt] >= 0}] }] {1 1}

## ⚖ R2 CONDITION 3: the run log says ONCE that the file exists and what it
## shadows. Ours is hit number one in the search order, so for the length of
## the run the user's own file is not read at all.
check {UF6 the run says once where the settings went and whose file they hide} \
  [p_withhome $UFHOME {
     global UFST UFPATH
     set plan [dict create argv {} file {{set ps_tpz_delays=1}} refused {} filewhy {}]
     set rep [ase::backend::ngspice::predeck_write $UFST [dict get $plan file]]
     set say [ase::predeck_report ngspice $UFST $plan $rep]
     list [llength $say] \
          [expr {[string first $UFPATH [lindex $say 0]] >= 0}] \
          [expr {[string first "it shadows [file join $::env(HOME) .spiceinit]" [lindex $say 0]] >= 0}] }] \
  {1 1 1}

## ⚠ NON-VACUITY for UF6's shadow clause: with nothing of the user's there, the
## sentence must not invent one.
check {UF7 with no file of the user's the sentence says where the settings went and claims no shadow} \
  [p_ans apply {{} {
     global scratch
     set h2 [file join $scratch emptyhome] ; file mkdir $h2
     set d2 [file join $scratch rd5] ; file mkdir $d2
     set st [p_state rundir $d2]
     set had [info exists ::env(HOME)] ; set old {} ; if {$had} { set old $::env(HOME) }
     set hadu [info exists ::env(SPICE_USERINIT_DIR)] ; set oldu {}
     if {$hadu} { set oldu $::env(SPICE_USERINIT_DIR) }
     catch {unset ::env(SPICE_USERINIT_DIR)}
     set ::env(HOME) $h2
     set plan [dict create argv {} file {{set ps_tpz_delays=1}} refused {} filewhy {}]
     set rep [ase::backend::ngspice::predeck_write $st [dict get $plan file]]
     set say [ase::predeck_report ngspice $st $plan $rep]
     if {$had} { set ::env(HOME) $old } else { catch {unset ::env(HOME)} }
     if {$hadu} { set ::env(SPICE_USERINIT_DIR) $oldu }
     return [list [llength $say] [string match {*it shadows*} [lindex $say 0]] \
                  [dict get $rep shadows]] }}] {1 0 {}}

} uferr]} { check {UF0 section UF ran to the end} "RAISED:$uferr" {} }

# ============================================================================
# SECTION OW -- AN OPTION ASE-L ALREADY DELIVERS THROUGH A CONTROL OF ITS OWN
# ============================================================================
# ⚠ MEASURED on the fork, reading `$casemode`: `-D casemode=preserve -D
# casemode=fold` answers `fold`, and the reverse order answers `preserve`. THE
# LAST ONE WINS. ase::run_casemode_flag already puts one on the command line,
# gated by a pre-flight that MEASURES what the binary delivers; a second from an
# options row would land after it, win, and bypass the measurement entirely.
if {[catch {

check {OW1 the two owned rows name the control that really sets them} \
  [list [p_ans ase::opt_owner ngspice casemode] [p_ans ase::opt_owner ngspice no_spinit] \
        [p_ans ase::opt_owner ngspice reltol]] \
  {{the simulator entry's Case field} {the simulator entry's -n flag} {}}

check {OW2 the speller refuses an owned option and sends the user to the control} \
  [list [string match {*is set by the simulator entry's Case field, not here} \
           [p_raise ase::opt_line ngspice casemode preserve]] \
        [string match {*is set by the simulator entry's -n flag, not here} \
           [p_raise ase::opt_line ngspice no_spinit 1]]] {1 1}

check {OW3 an owned option is never planned as a pre-deck line, and is reported instead} \
  [p_ans apply {{} {
     global scratch
     set d [file join $scratch rd6] ; file mkdir $d
     set p [ase::predeck_plan ngspice [p_state rundir $d options [p_opts casemode preserve]]]
     return [list [dict get $p argv] [dict get $p file] [lindex [dict get $p refused] 0]] }}] \
  {{} {} {casemode {it is set by the simulator entry's Case field, not by the options sheet}}}

check {OW4 a stored owned option is reported as owned, not as a door problem} \
  [p_ans ase::state_option_delivery ngspice [p_state options [p_opts casemode preserve]]] \
  {{casemode elsewhere {this option is set by the simulator entry's Case field}}}

check {OW5 an owned option is never restored, because it was never this sheet's to set} \
  [list [p_ans ase::opt_restore_line ngspice casemode] \
        [p_ans ase::opt_restore_line ngspice no_spinit]] {{} {}}

## ⚠ AND OW5's FIXTURES NEVER DISAGREE EITHER. Sabotage S16 -- deleting the
## owned-row guard from ase::opt_restore_line -- SURVIVED it, because neither
## ngspice row carries a `default` and the proc answers `{}` two lines earlier
## for that reason instead. The guard is not decoration: it is what a second
## adapter's descriptor gets when its owned row DOES carry one, which is
## exactly what D37's paper validation does. So the state is BUILT.
check {OW5b an owned row that does carry a default is still never restored} \
  [p_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzrest [dict create render_deck x run_cmd x log_file x \
       result_probe x raw_file x sim_options ::ase_t_rest \
       option_spell ::ase::backend::ngspice::option_spell]
     proc ::ase_t_rest {} { return {KNOB  {cptype optint phase any default 3 owner {somewhere else}}
                                    PLAIN {cptype optint phase any default 3}} }
     set r [list [ase::opt_restore_line zzrest KNOB] [ase::opt_restore_line zzrest PLAIN]]
     set ::ase::backends $save
     return $r }}] {{} {option PLAIN=3}}

## The catalogue-wide assertion, so a row added later cannot claim an owner and
## still spell a line.
check {OW6 no catalogue row names an owner and still spells a line} \
  [p_ans apply {{} {
     set bad {}
     foreach n [ase::sim_option_names ngspice] {
       if {[ase::opt_owner ngspice $n] eq {}} { continue }
       foreach w {deck control} {
         if {![catch {ase::opt_line ngspice $n 1 $w}]} { lappend bad "$n:$w" }
       }
     }
     return [lsort -unique $bad] }}] {}

## ⚠ AN EMPTY `owner` IS THE ONE THAT CAN ACTUALLY HAPPEN, AND IT IS SILENT:
## `ase::opt_owner` answers `{}` for it, so the row is spelled, offered and
## delivered as if it had never claimed a control at all. The checker names it
## rather than leaving a run to discover it.
check {OW7 a row that names an owner and leaves it blank is a complaint, because an empty claim disappears} \
  [p_ans apply {{} {
     set save $::ase::backends
     dict set ::ase::backends zzown [dict create render_deck x run_cmd x log_file x \
       result_probe x raw_file x sim_options ::ase_t_own \
       option_spell ::ase::backend::ngspice::option_spell]
     proc ::ase_t_own {} { return {LOUD {cptype optflag phase any owner {}}
                                   QUIET {cptype optflag phase any owner {somewhere else}}} }
     set r [ase::option_schema_errors zzown]
     set ::ase::backends $save
     return $r }}] {{LOUD: names an owner and leaves it empty}}

} owerr]} { check {OW0 section OW ran to the end} "RAISED:$owerr" {} }

# ============================================================================
# SECTION OF -- THE INERT LIST'S THREE SHAPES, AS AN ANSWER §7c CAN DRAW
# ============================================================================
# PLAN.md §7d: "not offered at all"; "offered with a clamp and the reason";
# "kept as a tombstone, or offered only with the defect named beside it".
if {[catch {

check {OF1 a dead option is not offered at all} \
  [list [p_ans ase::opt_offer ngspice ramptime] [p_ans ase::opt_offer ngspice newtrunc] \
        [p_ans ase::opt_offer ngspice klu_memgrow_factor] \
        [p_ans ase::opt_offer ngspice nosavecurrents]] {no no no no}

## niiter.c:38-39 raises EVERY iteration limit below 100 to 100, so the shipped
## defaults 50 and 10 are already 100.
check {OF2 the three iteration limits are offered with a clamp} \
  [list [p_ans ase::opt_offer ngspice itl1] [p_ans ase::opt_offer ngspice itl2] \
        [p_ans ase::opt_offer ngspice itl4]] {clamp clamp clamp}

## ⚠ `.options defas` sets the DRAIN area: cktsopt.c:111-113's OPT_DEFAS arm
## writes TSKdefaultMosAD, the same field the OPT_DEFAD arm three lines above
## writes. Offered only with that sentence beside it. Trap T14.
check {OF3 an option that works and writes the wrong field is offered with the defect named} \
  [list [p_ans ase::opt_offer ngspice defas] \
        [expr {[string first {DRAIN area} \
          [dict get [ase::sim_option_entry ngspice defas] defect]] >= 0}]] {caveat 1}

check {OF4 an option delivered by a control of ASE-L's own says so rather than saying dead} \
  [list [p_ans ase::opt_offer ngspice casemode] [p_ans ase::opt_offer ngspice no_spinit]] \
  {elsewhere elsewhere}

check {OF5 an ordinary option is ordinary} \
  [list [p_ans ase::opt_offer ngspice reltol] [p_ans ase::opt_offer ngspice klu]] {yes yes}

## ⚠ `clamp` AND `caveat` ARE NOT `no`. Collapsing them loses the difference
## between a name that exists nowhere in the simulator's source and a name that
## works and writes the wrong field -- and a user who cannot SEE `defas` cannot
## be warned about it.
check {OF6 the three offered-with-a-warning shapes are not the not-offered shape} \
  [p_ans apply {{} {
     set counts [dict create]
     foreach n [ase::sim_option_names ngspice] { dict incr counts [ase::opt_offer ngspice $n] }
     return [list [dict exists $counts no] [dict exists $counts clamp] \
                  [dict exists $counts caveat] [dict exists $counts elsewhere] \
                  [dict get $counts no]] }}] {1 1 1 1 16}

check {OF7 a simulator that describes nothing offers everything, because it claims nothing} \
  [p_ans ase::opt_offer zznosuch anything] yes

} oferr]} { check {OF0 section OF ran to the end} "RAISED:$oferr" {} }

# ============================================================================
# SECTION RD -- THE EMITTER FINALLY ASKS WHAT KIND OF OPTION IT IS WRITING
# ============================================================================
# This is the section that fixes issue 1438, and the one the five benches are
# waiting on.
if {[catch {

set RDNL "* t\nr1 a 0 1k\nv1 a 0 1\n.end\n"
proc p_deck {opts} {
  global RDNL scratch
  set d [file join $scratch rdeck] ; file mkdir $d
  return [ase::backend::ngspice::render_deck [p_state rundir $d options $opts] $RDNL]
}
proc p_cards {opts} {
  set out {}
  foreach l [split [p_deck $opts] "\n"] {
    if {[string match {.options*} $l]} { lappend out $l }
  }
  return $out
}

## ⚠ THE HEADLINE. MEASURED on both binaries, on a flat `m` line AND on the
## sky130 `x`-line shape: `.options wnflag` leaves @m1[vth] at 9.888996e-01 and
## `.options wnflag=1` moves it to 5.888996e-01 -- a 71% change in i(vd).
check {RD1 a MOS width-per-finger tick reaches the deck as a value, not as a bare card} \
  [p_cards [p_opts wnflag 1]] [list {.options wnflag=1}]

## Issue 1438 defect 2. MEASURED on both binaries: `.options maxord=1` gives
## MaxOrder = 1 and `.options maxord` leaves it at 2.
check {RD2 a valued option set to 1 carries its value} \
  [p_cards [p_opts maxord 1]] [list {.options maxord=1}]

## Issue 1438 defect 3. MEASURED on both binaries: `.options gminsteps=0`
## disables gmin stepping; emitting nothing leaves it running at 1.
check {RD3 a valued option set to 0 is written, not dropped} \
  [p_cards [p_opts gminsteps 0]] [list {.options gminsteps=0}]

## ⚠ AND A FLAG IS STILL A BARE CARD. `sqrnoise` is a CP_BOOL and `.options
## sqrnoise=1` is SILENTLY OFF -- measured, onoise_total 3.859e-07 with the
## value and 1.489e-13 without it. The fix must not move this line.
check {RD4 a flag is still written with no value, because a value silently switches it off} \
  [p_cards [p_opts sqrnoise 1 klu 1]] [list {.options sqrnoise} {.options klu}]

check {RD5 a flag switched off is still absent, because absence is off} \
  [p_cards [p_opts klu 0]] {}

## §7d's own rule: a pre-deck option is NOT written as a card that does nothing.
## MEASURED on both binaries: `.options casemode=preserve` folds every name
## anyway and says not a word.
check {RD6 a pre-deck option is not written above the block at all -- the pre-deck doors carry it} \
  [p_cards [p_opts ngbehavior hs ps_tpz_delays 1 reltol 1e-5]] [list {.options reltol=1e-5}]

## A catalogue is a claim about one simulator and the user may know something
## it does not. Refusing to render a bench because a table is short would be
## the catalogue outranking the user.
check {RD7 an option this simulator does not describe still reaches the deck, on the old rule} \
  [p_cards [p_opts frobnicate 1 widget 2 gadget 0]] [list {.options frobnicate} {.options widget=2}]

## ⚠ THE ROW THAT EXPLAINS WHY NOTHING MOVED IS THE ROW TO SABOTAGE FIRST.
## `acct` and `list` are inert on ASE-L's `.control` route and ONE committed
## bench carries both. Dropping their cards would be a deck change with no
## measurement behind it, so the fallback keeps them exactly as they were --
## and §7c owns the surface that stops them being offered.
check {RD8 an inert option keeps the card the bench has always carried} \
  [p_cards [p_opts acct 1 list 1 oldlimit 1]] \
  [list {.options acct} {.options list} {.options oldlimit}]

## ⚠ AN OWNED PRE-DECK OPTION LEAVES THE DECK, AND THAT IS ARM 2 WINNING OVER
## THE FALLBACK ON PURPOSE. `.options casemode=preserve` was MEASURED on both
## binaries to fold every name anyway and say nothing; keeping it would be
## keeping the lie §7d exists to delete. An inert or owned row whose door IS
## the deck's still keeps its card -- RD8 is that case.
check {RD9 an owned pre-deck option leaves the deck entirely, and the run says which control sets it} \
  [list [p_cards [p_opts casemode preserve]] \
        [lindex [dict get [ase::predeck_plan ngspice \
           [p_state options [p_opts casemode preserve]]] refused] 0 0]] \
  [list {} casemode]

## THE MEASUREMENT OVER THE USER'S OWN TREE: the five benches that asked for
## wnflag and got nothing now get it.
check {RD10 every committed bench that stores wnflag now renders the value} \
  [p_ans apply {{} {
     ## ⚠ NOT `exec git ls-files` BARE (issue 1485): in a checkout with no
     ## `.git` that RAISED, and the raise landed in the row as its answer --
     ## `-> {RAISED:fatal: not a git repository ...} (exp {5 0 5})`, MEASURED
     ## 2026-09-20 in a `git archive` export. `test_corpus_files` enumerates
     ## the same files from the filesystem when git cannot answer.
     global repo
     set n 0 ; set bare 0 ; set valued 0
     set corpus [test_corpus_files $repo *.state]
     test_corpus_note $corpus "the committed .state corpus"
     foreach f [dict get $corpus files] {
       if {[catch {ase::state_load $f} st]} { continue }
       if {![ase::option_enabled $st wnflag]} { continue }
       incr n
       set line [ase::opt_line ngspice wnflag [dict get [ase::state_option_map $st] wnflag]]
       if {$line eq {.options wnflag}} { incr bare }
       if {$line eq {.options wnflag=1}} { incr valued }
     }
     ## ⚠ A FLOOR ON THE COUNT, EXACT ON THE SHAPE. The corpus is enumerated
     ## from the filesystem in a checkout with no `.git` (issue 1485) and then
     ## includes the tester's own saved benches: MEASURED 2026-09-20, copying
     ## the shipped `test_nmos` bench into a second run directory took this row
     ## to `{6 0 6}` and reddened it. `bare` must still be exactly 0 and EVERY
     ## bench that stores wnflag must render the value, which is the claim --
     ## `valued == n` says it for six benches as well as for five.
     return [list [expr {$n >= 5}] $bare [expr {$valued == $n}]] }}] {1 0 1}

## ⚠ AN EMPTY VALUE IS THE ONE PLACE THE SPELLER AND THE OLD RULE DISAGREE
## ABOUT NOTHING-VS-SOMETHING. The old rule wrote `.options klu=` -- a card with
## no value on it -- for a row the user had not filled in; the speller writes no
## line, and `ase::option_enabled` agrees with it (issue 1437's C113). The
## fallback must not run for a row the speller answered, or the disagreement
## comes straight back.
check {RD12 an option left blank writes no card, rather than a card with nothing on it} \
  [p_cards [p_opts klu {}]] {}

## ⚠ AND NOTHING THE PRE-DECK DOORS SPELL MAY LAND IN THE DECK AT ALL. The
## speller answers `-D ngbehavior=hs` for a pre-deck row asked for in the deck
## slot, because the door it computes is the pre-deck one -- so a loop that
## called the speller without testing the door first would write a COMMAND-LINE
## flag into a SPICE deck. Sabotage S31 does exactly that and RD9 alone did not
## see it: the card filter only looks at `.options` lines.
check {RD13 no command-line flag and no run-directory line ever lands in the deck} \
  [p_ans apply {{} {
     set bad {}
     foreach l [split [p_deck [p_opts ngbehavior hs mingwpath 1 ps_tpz_delays 1 \
                               sourcepath {/a /b} casemode preserve reltol 1e-5]] "\n"] {
       set t [string trim $l]
       ## the analysis block is the .control block's own; this row is about the
       ## deck slot, which is everything above it.
       if {$t eq {.control}} { break }
       if {[string match {-D *} $t]} { lappend bad $t }
       if {[string match {set *} $t]} { lappend bad $t }
     }
     return $bad }}] {}

check {RD11 the temperature card and the save-all blanket are where they were -- this change touches the option loop only} \
  [p_ans apply {{} {
     set d [p_deck [p_opts reltol 1e-5]]
     return [list [expr {[string first "\n.temp 27\n" $d] >= 0}] \
                  [expr {[string first "\n.options reltol=1e-5\n" $d] >= 0}]] }}] {1 1}

} rderr]} { check {RD0 section RD ran to the end} "RAISED:$rderr" {} }

# ============================================================================
# SECTION CM -- THE COMMAND LINE GROWS A -D ARM
# ============================================================================
# ⚠ THE PLAN EXPECTED SIX ROWS OF test_ase_simreg_0931 TO MOVE HERE, AND THEY
# DO NOT. All six build the command from an EMPTY state, which carries no
# pre-deck option, so the arm contributes nothing and the command is
# byte-identical. That is the compatibility contract working, not an accident:
# a user who sets no pre-deck option must not be able to tell this arm exists.
if {[catch {

set CMDECK [file join $scratch cm_deck.spice]

check {CM1 a bench with no pre-deck option builds the command it has always built} \
  [p_ans ase::backend::ngspice::run_cmd [p_state options [p_opts reltol 1e-5]] $CMDECK] \
  [list ngspice -b $CMDECK 2>@1]

check {CM2 a pre-deck bool and string land between the flags and the deck, in bench order} \
  [p_ans apply {{} {
     global CMDECK scratch
     set d [file join $scratch rd7] ; file mkdir $d
     return [ase::backend::ngspice::run_cmd \
              [p_state rundir $d options [p_opts ngbehavior hs mingwpath 1]] $CMDECK] }}] \
  [list ngspice -b -D ngbehavior=hs -D mingwpath $CMDECK 2>@1]

## ⚠ MEASURED on both binaries: `-n -D ngbehavior=hs` still prints `Note:
## Compatibility modes selected: hs`. `-n` closes the file and nothing else.
check {CM3 the command-line door survives the flag that closes the file} \
  [p_nospiceinit {
     global CMDECK
     set c [ase::backend::ngspice::run_cmd [p_state options [p_opts ngbehavior hs]] $CMDECK]
     list $c }] [list [list ngspice -b -n -D ngbehavior=hs $CMDECK 2>@1]]

check {CM4 a pre-deck number never reaches the command line, because -D cannot carry one} \
  [p_ans apply {{} {
     global CMDECK scratch
     set d [file join $scratch rd8] ; file mkdir $d
     return [ase::backend::ngspice::run_cmd \
              [p_state rundir $d options [p_opts ps_tpz_delays 1]] $CMDECK] }}] \
  [list ngspice -b $CMDECK 2>@1]

## ⚠ NON-VACUITY: the arm must be REACHED, not merely present. A catalogue
## defect must not stop a run, so it is caught -- and a `catch` that swallows
## everything would make CM2 unfalsifiable if the call were removed.
check {CM5 the arm is in the command builder and it calls the one router} \
  [expr {[string first {ase::predeck_argv ngspice $state} \
    [p_nocomment [info body ::ase::backend::ngspice::run_cmd]]] >= 0}] 1

## ⚠ THE ORDER IS LOAD-BEARING AND NO GOLDEN CAN SEE IT, because a bench that
## requests a case mode AND a pre-deck option is a state this suite cannot build
## without a registry. MEASURED on the fork: the LAST `-D casemode=` wins. The
## bench's own options must therefore come AFTER ASE-L's own flags, so that if a
## row ever slips past the `owner` refusal it displaces ASE-L's flag
## deliberately rather than by accident -- and the arm must sit ahead of the
## deck path, which is always last but for `2>@1`.
check {CM6 the bench's pre-deck words come after ASE-L's own flags and before the deck} \
  [p_ans apply {{} {
     set b [p_nocomment [info body ::ase::backend::ngspice::run_cmd]]
     set n [string first {ase::sim_nospiceinit ngspice} $b]
     set c [string first {ase::run_casemode_flag $state} $b]
     set d [string first {ase::predeck_argv ngspice $state} $b]
     set k [string first {lappend cmd $deckpath} $b]
     return [list [expr {$n >= 0 && $c > $n}] [expr {$d > $c}] [expr {$k > $d}]] }}] {1 1 1}

} cmerr]} { check {CM0 section CM ran to the end} "RAISED:$cmerr" {} }

# ============================================================================
# SECTION HK -- THE SPLIT: ASE-L OWNS THE SCHEMA, THE ADAPTER OWNS THE FILE
# ============================================================================
if {[catch {

check {HK1 a backend with no predeck_write hook writes nothing, and gets no fallback file} \
  [p_ans apply {{} {
     global scratch
     set save $::ase::backends
     dict set ::ase::backends zzbare [dict create render_deck x run_cmd x log_file x \
       result_probe x raw_file x]
     set d [file join $scratch rd9] ; file mkdir $d
     set plan [dict create argv {} file {{set x=1}} refused {} filewhy {}]
     set r [list [ase::predeck_deliver zzbare [p_state rundir $d] $plan] \
                 [file exists [file join $d .spiceinit]]]
     set ::ase::backends $save
     return $r }}] {{} 0}

## ⚠ THE NAMING RULE IS LEXICAL, SO THE TEST IS TOO. The pre-deck procs in core
## must not learn this simulator's filename, its flags or its option names --
## the point of a computed door is that core never does.
check {HK2 no core pre-deck proc names the simulator's file, its flags or its options} \
  [p_ans apply {{} {
     set bad {}
     foreach p {ase::predeck_plan ase::predeck_argv ase::predeck_deliver
                ase::predeck_report ase::opt_owner ase::opt_offer
                ase::rundir_is_shared} {
       if {![llength [info commands $p]]} { lappend bad "$p:missing" ; continue }
       set b [p_nocomment [info body $p]]
       foreach w {.spiceinit spice.rc casemode wnflag ngbehavior sqrnoise
                  .options .control CP_BOOL CP_NUM ngspice -D} {
         if {[string first $w $b] >= 0} { lappend bad "$p:$w" }
       }
     }
     return [lsort -unique $bad] }}] {}

check {HK3 registering a backend still does not need the new hook} \
  [p_ans apply {{} {
     set save $::ase::backends
     set rc [catch {ase::register_backend zznohook [dict create render_deck x run_cmd x \
       log_file x result_probe x raw_file x]} e]
     set ::ase::backends $save
     return [list $rc $e] }}] {0 zznohook}

## A made-up simulator with a vocabulary of its own reaches its own file
## through its own hook, and core routes by door alone.
check {HK4 a made-up simulator's pre-deck lines reach its own writer, unaltered} \
  [p_ans apply {{} {
     global scratch
     set save $::ase::backends
     set ::ase_t_seen {}
     dict set ::ase::backends zzalien [dict create render_deck x run_cmd x log_file x \
       result_probe x raw_file x sim_options ::ase_t_alien2 \
       option_spell ::ase_t_alienspell2 predeck_write ::ase_t_alienwrite]
     proc ::ase_t_alien2 {} { return {EARLY {cptype amount phase pre}} }
     proc ::ase_t_alienspell2 {} { return {predeck-file {amount {PUT @name = @value}}} }
     proc ::ase_t_alienwrite {state lines} { set ::ase_t_seen $lines
       return [dict create status written path /nowhere wrote [llength $lines] shadows {}] }
     set d [file join $scratch rd10] ; file mkdir $d
     set plan [ase::predeck_plan zzalien [p_state rundir $d options [p_opts EARLY 7]]]
     set rep [ase::predeck_deliver zzalien [p_state rundir $d] $plan]
     set r [list [dict get $plan file] $::ase_t_seen [dict get $rep wrote]]
     set ::ase::backends $save
     return $r }}] {{{PUT EARLY = 7}} {{PUT EARLY = 7}} 1}

## ⚠ THE REFUSAL IS CORE'S, THE FILE IS THE ADAPTER'S -- so a refused run hands
## the adapter an EMPTY list and the adapter still deletes, which is ⚖ R2
## condition 1 for the refused case too.
check {HK5 a refused file half reaches the writer as nothing to write, so a stale file still goes} \
  [p_ans apply {{} {
     global scratch
     set d [file join $scratch rd11] ; file mkdir $d
     set st [p_state rundir $d options [p_opts ps_tpz_delays 1]]
     ase::backend::ngspice::predeck_write $st {{set ps_tpz_delays=1}}
     set path [ase::backend::ngspice::predeck_file $st]
     set before [file exists $path]
     set shared [p_state rundir {} options [p_opts ps_tpz_delays 1]]
     set plan [ase::predeck_plan ngspice $shared]
     set rep [ase::predeck_deliver ngspice $st $plan]
     return [list $before [expr {[dict get $plan filewhy] ne {}}] \
                  [dict get $rep status] [file exists $path]] }}] \
  {1 1 removed 0}

} hkerr]} { check {HK0 section HK ran to the end} "RAISED:$hkerr" {} }

# ============================================================================
# SECTION CL -- THE CLASS ITSELF, AND THE TWO ROWS MEASURED OUT OF IT
# ============================================================================
if {[catch {

check {CL1 the pre-deck class is 32 rows, and every one of them takes one of the two pre-deck doors} \
  [p_ans apply {{} {
     set n 0 ; set bad {}
     foreach nm [ase::sim_option_names ngspice] {
       if {![ase::opt_is_pre_deck ngspice $nm]} { continue }
       incr n
       if {[catch {ase::opt_door ngspice $nm} d]} { lappend bad "$nm:raised" ; continue }
       if {$d ni {predeck predeck-file}} { lappend bad "$nm:$d" }
     }
     return [list $n $bad] }}] {32 {}}

## ⚠ THE CORRECTION THAT COST THE MOST TO FIND. Two of `wnflag`'s three cited
## read sites are DEAD -- `inpcom.c:990` reads it into a local `inp_get_w_l_x`
## never uses, and `inp.c:2828` is inside `#ifdef REM_UNUSED`, defined NOWHERE
## in the ngspice tree. The live one is `inpgmod.c:268`, at model-binning time,
## which an `.options` card reaches. MEASURED on both binaries and on both
## device shapes.
check {CL2 wnflag is a deck option with the .options door, and its row carries the measurement} \
  [list [p_ans ase::opt_phase ngspice wnflag] [p_ans ase::opt_door ngspice wnflag] \
        [p_ans ase::opt_is_pre_deck ngspice wnflag] \
        [expr {[string first {REM_UNUSED} [dict get [ase::sim_option_entry ngspice wnflag] caveat]] >= 0}]] \
  {deck options 0 1}

check {CL3 wnflag refuses the in-block slot, because set wnflag=1 there is measured to do nothing} \
  [string match {*loads the circuit*} [p_raise ase::opt_door ngspice wnflag control]] 1

## ⚠ MEASURED on both binaries: a run with `-D no_spinit` still read the run
## directory's start-up file; the same run with `-n` did not. So `-D` is not a
## door for it at all and the command-line flag is the only one.
check {CL4 no_spinit is a command-line option, not a pre-deck one} \
  [list [p_ans ase::opt_phase ngspice no_spinit] [p_ans ase::opt_door ngspice no_spinit] \
        [p_ans ase::opt_is_pre_deck ngspice no_spinit]] {cmdline cmdline 0}

check {CL5 the pre-deck split is exactly the cptype split -- bool and string on the command line, the rest in the file} \
  [p_ans apply {{} {
     set bad {}
     foreach nm [ase::sim_option_names ngspice] {
       if {![ase::opt_is_pre_deck ngspice $nm]} { continue }
       set t [dict get [ase::sim_option_entry ngspice $nm] cptype]
       set d [ase::opt_door ngspice $nm]
       set want [expr {$t in {bool string} ? {predeck} : {predeck-file}}]
       if {$d ne $want} { lappend bad "$nm:$t:$d" }
     }
     return $bad }}] {}

check {CL6 the catalogue still passes its own whole-set check} \
  [p_ans ase::option_schema_errors ngspice] {}

} clerr]} { check {CL0 section CL ran to the end} "RAISED:$clerr" {} }

# ============================================================================
# SECTION RN -- THE RUN PATH ACTUALLY CALLS IT
# ============================================================================
# ⚠ EVERY ROW ABOVE DRIVES A PROC DIRECTLY. A file writer nobody calls is a
# file writer that never runs, and the whole feature would pass 68 checks while
# delivering nothing. These rows are the seam, and they are lexical because
# ase::run_deck starts a process.
if {[catch {

set RNBODY [p_nocomment [info body ::ase::run_deck]]

check {RN1 the run plans, delivers and reports the pre-deck settings} \
  [list [expr {[string first {ase::predeck_plan $sim $state} $RNBODY] >= 0}] \
        [expr {[string first {ase::predeck_deliver $sim $state} $RNBODY] >= 0}] \
        [expr {[string first {ase::predeck_report $sim $state} $RNBODY] >= 0}]] {1 1 1}

## ⚠ IT SITS WITH THE OTHER PRE-RUN DELETIONS, NOT AFTER THE DECK IS WRITTEN.
## Everything above ase::preflight_gate only reads, so a refused run leaves
## nothing behind; this is the first line that may create a file.
check {RN2 the pre-deck delivery happens after the pre-flight gate and before the deck is rendered} \
  [p_ans apply {{} {
     global RNBODY
     set g [string first {ase::preflight_gate} $RNBODY]
     set p [string first {ase::predeck_deliver} $RNBODY]
     set r [string first {$render_deck $state $netlist_text} $RNBODY]
     return [list [expr {$g >= 0 && $p > $g}] [expr {$r >= 0 && $p < $r}]] }}] {1 1}

## ⚠ AND IT IS CAUGHT. A defect in an option catalogue must never stop a run
## from starting -- the same rule ase::cap_report and ase::op_tier_report
## already follow, and for the same reason: everything it says is advisory.
check {RN3 a defect in the catalogue cannot stop a run, because the whole delivery is caught} \
  [p_ans apply {{} {
     global RNBODY
     set i [string first {ase::predeck_plan} $RNBODY]
     set head [string range $RNBODY [expr {$i - 200}] $i]
     return [expr {[string last "catch \{" $head] >= 0}] }}] 1

## ⚠ NON-VACUITY for RN1: the sentence the run says is the one this file's UF6
## and RF5 rows build, and it reaches the user through ase::echo rather than
## being computed and dropped.
check {RN4 what the delivery says reaches the user, it is not computed and thrown away} \
  [expr {[regexp {ase::echo "ase: \$_pds"} $RNBODY]}] 1

} rnerr]} { check {RN0 section RN ran to the end} "RAISED:$rnerr" {} }

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
exit [expr {$fail ? 1 : 0}]
