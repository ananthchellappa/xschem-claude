# tests/headless/test_ase_simreg_0931.tcl -- ISSUE 0931: THERE IS NO WAY TO
# POINT ASE-L AT A SIMULATOR THAT IS NOT ON PATH.
#
# ============================================================================
# WHAT THE USER CANNOT DO
# ============================================================================
# They have a custom ngspice build in a directory of their own. There is no
# place in ASE-L to say so. The Setup and Simulation menus have no entry for
# it; the bottom bar's "Simulator:" segment shows the backend name, never the
# program that will actually be started; nothing is remembered between
# restarts. The only lever is the PATH of the shell that launched xschem --
# global to the whole process, invisible from inside it, and impossible to
# name, list or take back.
#
# ⚠ THE BOTTOM-BAR CLAUSE ABOVE IS HISTORY NOW, and 0931 is the reason it was
# still true for so long: this item named that segment in its own problem
# statement and shipped without touching it, and issue 0937 then wrote the
# exclusion down as a decision. The user overturned it directly in issue 1370
# ("in ASE-L, in status bar, Simulator: <name> should show the correct name").
# Section L below owns what the segment is told to say; rows S20-S23 of
# tests/headless/test_ase_simdlg_0937.tcl own the pixels.
#
# ============================================================================
# THE MECHANISM, MEASURED AT HEAD 0e6cb3cb AND NOT RE-DERIVED HERE
# ============================================================================
# The entire body of ase::backend::ngspice::run_cmd, src/ase.tcl:4205-4207:
#
#     return [list ngspice -b $deckpath 2>@1]
#
# It takes a state argument and never reads it -- five different states, five
# byte-identical answers. And even a run_cmd that consulted its argument would
# have nothing to consult: no proc in ase:: resolves a binary, no schema key
# carries one, no rc variable is read, and nothing under USER_CONF_DIR names
# one. The absent thing is the whole configuration surface, not one literal
# word.
#
# ============================================================================
# THE FAILURE MODE THIS FILE EXISTS TO FORBID -- ALREADY SHIPPED NEXT DOOR
# ============================================================================
# ase::cosim_build_script -- src/ase.tcl:1970 -- is this tree's only other
# "an rc variable names an executable" resolver. Measured in BOTH bad arms: a
# path that does not exist, and a file that exists at mode 644 and is not
# executable. Both return empty, both say NOTHING, and the sentence the user
# then reads blames the variable as unset when it is set and merely wrong.
# Row C7 pins that behaviour as KNOWN so nobody "fixes" this item by copying
# the neighbour. Rows C1-C4 are the same four questions asked of the new
# surface, where silence is the defect.
#
# ============================================================================
# THE ANSWER DISCIPLINE -- an absent proc must never satisfy a golden
# ============================================================================
# Every helper answers NOPROC when the command it calls does not exist and
# RAISED:<text> when it blows up. A bare catch-and-discard would let
# "invalid command name ase::sim_status" satisfy a row that expects an empty
# string -- the file would go green against the very tree it was written to
# redden.
#
# ============================================================================
# TWO INTERNAL NAMES THIS FILE DEPENDS ON, DELIBERATELY
# ============================================================================
# Row D2 reaches the resolver's "the selection names an entry nobody
# registered" arm by setting the namespace variable ::ase::sim_use directly,
# because every documented route to that state is refused at the door. The
# plan names that variable verbatim, so it is a contract, not a guess. Nothing
# else in this file touches ASE-L internals: the registry is driven through
# sim_register / sim_unregister / sim_select / sim_list / sim_status /
# sim_exe / sim_write_conf / sim_load_conf, and the rc layer is driven through
# real child processes.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE -- READ BEFORE TRUSTING IT
# ============================================================================
# * NO PIXELS. There is no dialog here; the GUI front door is S2's job. A
#   green run proves the writer a dialog would call, not the dialog.
# * NO SIMULATOR IS EVER STARTED. Every "binary" is a two-line /bin/sh stub
#   or a deliberately broken file. What is under test is which program would
#   be started and what the user is told, never the run itself.
# * DECK RENDERING IS UNTOUCHED. Rows A2/B5/B6 assert -b and 2>@1 survive
#   byte for byte, which is what keeps test_ase_core's E1e/E2b/E4 goldens
#   green without editing them.
#
# ⚠ THE CHECK COUNT IS A FLOOR AND IT ONLY EVER GOES UP: 111 as of 2026-09-08,
# AND RAISED 111 -> 117 on 2026-09-13 by issue 1439 (section P, the pre-deck
# `-D` arm), AND RAISED 117 -> 118 on 2026-09-15 by issue 1473 (row L12 -- the
# `stop      :` field says what stopping THIS run would cost, so a checkpointed
# transient is no longer told in its own log that it would be discarded).
# It was 95 before section S (the registry-is-environment /
# choice-is-state ruling) and R8b landed. If a run reports fewer, a row went
# missing -- do not edit this number down to match it.
#
# ⚠ AND `PLAN.md` §7 EXPECTED SIX ROWS OF THIS FILE TO MOVE AT 1439 AND THEY DO
# NOT. Its prediction was that A2 / B5 / B6 / B11 / B12 / D4 would be
# re-baselined "the first time `-D` is emitted for an option". All six build
# the command from an EMPTY state, which carries no pre-deck option, so the new
# arm contributes nothing and every one of those commands is byte-identical.
# That is 0931's compatibility contract holding -- a user who sets no pre-deck
# option must not be able to tell the arm exists -- so the arm is pinned by NEW
# rows in section P instead of by moved goldens.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_simreg_0931.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_simreg_0931.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations, cwd-independent ---------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch simreg0931]

## ⚠ THE SAVED LIST GOES TO A SCRATCH DIRECTORY, AND AS OF 2026-09-08 THAT IS
## NOT OPTIONAL. ase::sim_register and ase::sim_unregister now persist the
## registry at the moment it changes (the user's ruling: registering "can make
## it to disk right away"), and their target is
## $::USER_CONF_DIR/ase_simulators. This file registers stubs by the dozen, so
## without this redirect every run of it would REWRITE the developer's own
## ~/.xschem/ase_simulators with two-line /bin/sh stubs and take away the build
## they actually use. Reading the real one is fine; writing it is not ours.
## The CHILD processes below are isolated a different way (a HOME of their
## own, $A_CLEANHOME / $E6HOME), which is what E6's real-restart row measures.
set ::USER_CONF_DIR [file join $scratch conf]
file mkdir $::USER_CONF_DIR

set ASETCL  [file join $repo src ase.tcl]
set XTCL    [file join $repo src xschem.tcl]
set SPECMD  [file join $repo doc claude specs ase_l.md]

# --- the answer discipline ---------------------------------------------------
proc a_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}

## For the rows whose subject IS the refusal: classify the raise instead of
## quoting it, so a reworded sentence does not red a row about the refusal.
proc a_refused {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {!$rc} { return "NORAISE:$r" }
  if {[string match {ase:*} $r]} { return REFUSED-ase }
  return "REFUSED-other:$r"
}
proc a_raisetext {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {!$rc} { return {} }
  return $r
}

# --- fixtures ----------------------------------------------------------------
proc a_wr {path body {mode 0644}} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
  catch {file attributes $path -permissions $mode}
}

set STUB    [file join $scratch bin ngstub]
set STUB2   [file join $scratch bin ngstub2]
set NOEXEC  [file join $scratch bin notexec.sh]
set MISSING [file join $scratch bin there-is-no-such-file]
set ADIR    [file join $scratch bin adir]
set DECK    [file join $scratch deck.spice]
a_wr $STUB   "#!/bin/sh\nexit 0\n" 0755
a_wr $STUB2  "#!/bin/sh\nexit 0\n" 0755
a_wr $NOEXEC "#!/bin/sh\nexit 0\n" 0644
a_wr $DECK   "* deck\n.end\n" 0644
file mkdir $ADIR
file delete -force $MISSING

## The measured trap row C3 exists for: a DIRECTORY answers 1 to
## `file executable`, so an executable-only guard lets a folder through.
set A_DIRTRAP [list [file executable $ADIR] [file isfile $ADIR] [file executable $NOEXEC]]

# --- registry drivers --------------------------------------------------------
proc a_reset {} {
  catch {ase::sim_clear}
  ## A tree with no sim_clear yet: nothing to reset, and every row below
  ## answers NOPROC anyway.
}
proc a_runcmd {deck} {
  if {![llength [info commands ase::backend::ngspice::run_cmd]]} { return NOPROC }
  set rc [catch {ase::backend::ngspice::run_cmd {} $deck} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc a_runcmd_refused {deck} {
  if {![llength [info commands ase::backend::ngspice::run_cmd]]} { return NOPROC }
  set rc [catch {ase::backend::ngspice::run_cmd {} $deck} r]
  if {!$rc} { return "NORAISE:$r" }
  if {[string match {ase:*} $r]} { return REFUSED-ase }
  return "REFUSED-other:$r"
}
## Five named fields of the resolver's answer, as one comparable list.
proc a_s5 {backend} {
  set s [a_ans ase::sim_status $backend]
  if {$s eq {NOPROC} || [string match RAISED:* $s]} { return $s }
  set out {}
  foreach k {ok exe args source entry} {
    if {[catch {dict get $s $k} v]} { set v "NOKEY-$k" }
    lappend out $v
  }
  return $out
}
proc a_sfield {backend key} {
  set s [a_ans ase::sim_status $backend]
  if {$s eq {NOPROC} || [string match RAISED:* $s]} { return $s }
  if {[catch {dict get $s $key} v]} { return "NOKEY-$key" }
  return $v
}
proc a_entry {name} {
  set l [a_ans ase::sim_list]
  if {$l eq {NOPROC} || [string match RAISED:* $l]} { return $l }
  foreach e $l {
    if {[catch {dict get $e name} n]} { continue }
    if {$n eq $name} { return $e }
  }
  return "NOENTRY-$name"
}
proc a_efields {name keys} {
  set e [a_entry $name]
  if {![string match "* *" $e] || [string match NOENTRY-* $e] \
      || $e eq {NOPROC} || [string match RAISED:* $e]} { return $e }
  set out {}
  foreach k $keys {
    if {[catch {dict get $e $k} v]} { set v "NOKEY-$k" }
    lappend out $v
  }
  return $out
}
proc a_names {} {
  set l [a_ans ase::sim_list]
  if {$l eq {NOPROC} || [string match RAISED:* $l]} { return $l }
  set out {}
  foreach e $l { catch {lappend out [dict get $e name]} }
  return $out
}
## The same list, but asked for one KIND of simulator -- what a menu or the
## Setup dialog would be offered, and what the "pick one" sentence lists.
proc a_names_for {backend} {
  set l [a_ans ase::sim_list $backend]
  if {$l eq {NOPROC} || [string match RAISED:* $l]} { return $l }
  set out {}
  foreach e $l { catch {lappend out [dict get $e name]} }
  return $out
}

## The CIW / action-log channel, spied at ase::echo -- the one call the
## registry reports through. Returns a list of tag/message pairs.
proc a_echoed {script} {
  set ::a_said {}
  set had [expr {[info commands ::ase::echo] ne {}}]
  if {$had} { rename ::ase::echo ::a_saved_echo }
  proc ::ase::echo {msg {tag {}}} { lappend ::a_said [list $tag $msg] ; return 1 }
  catch {uplevel #0 $script}
  catch {rename ::ase::echo {}}
  if {$had} { rename ::a_saved_echo ::ase::echo }
  return $::a_said
}
proc a_regbad_do {name path} { set ::a_rv [a_ans ase::sim_register $name $path] }
## Register something broken and collect BOTH halves of the contract: what
## register answered, and what the user was told.  Returns rv / tag / message.
proc a_regbad {name path} {
  set ::a_rv NOPROC
  set said [a_echoed [list a_regbad_do $name $path]]
  set tag NONE ; set msg NONE
  foreach p $said {
    if {[lindex $p 0] eq {error}} { set tag error ; set msg [lindex $p 1] ; break }
  }
  if {$tag eq {NONE} && [llength $said]} {
    set tag [lindex [lindex $said 0] 0] ; set msg [lindex [lindex $said 0] 1]
  }
  return [list $::a_rv $tag $msg]
}
proc a_rv  {r} { return [lindex $r 0] }
proc a_tag {r} { return [lindex $r 1] }
proc a_msg {r} { return [lindex $r 2] }
proc a_says {r pat} {
  set m [a_msg $r]
  if {$m eq {NONE} || $m eq {NOPROC}} { return 0 }
  return [expr {[regexp -nocase -- $pat $m] ? 1 : 0}]
}
proc a_names_in {r s} {
  set m [a_msg $r]
  if {$m eq {NONE} || $m eq {NOPROC}} { return 0 }
  return [expr {[string first $s $m] >= 0 ? 1 : 0}]
}

# --- source readers, for the structural rows ---------------------------------
proc a_slurp {path} {
  if {![file exists $path]} { return "ZZNOFILE" }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## Tcl comments dropped, so a sentence quoted in a comment cannot satisfy a
## row about where the sentence is MINTED.
proc a_nocomment {path} {
  set out {}
  foreach l [split [a_slurp $path] "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc a_lines_matching {path pat} {
  set n 0 ; set res {}
  foreach l [split [a_slurp $path] "\n"] {
    incr n
    if {[regexp {^\s*#} $l]} { continue }
    if {[string first $pat $l] >= 0} { lappend res $n }
  }
  return $res
}
proc a_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}

# --- the child harness -------------------------------------------------------
## THE FORGERY TRAP. Every value lifted out of a child's stdout is scrubbed
## before it can reach a check's detail line, so a child that printed a
## banner or a crash marker cannot forge this suite's own verdict.
set ::SIGMARK [format {%s: %s} FATAL signal]
set ::SCRUB [list \
  $::SIGMARK                           {F#TAL sig} \
  [format {%s() %s} Tcl_AppInit error] {Tcl_App#nit err} \
  [format {%s:} RESULT]                {R#SULT:} \
  [format {%s: %s} OVERALL ok]         {OV#RALL ok} \
  {FAIL:}                              {F#IL:}]
proc scrub {s} { return [string map $::SCRUB $s] }

set ::XBIN [info nameofexecutable]

## Run $body in a fresh --nogui xschem, optionally with a --preinit string
## (which xinit.c runs BEFORE xschemrc and therefore before ase.tcl -- the
## only seam an rc layer has) and optionally with HOME redirected, which is
## what moves USER_CONF_DIR. Returns rc and the captured text. Never prints.
proc a_child {tag body {pre {}} {home {}}} {
  global scratch
  set script [file join $scratch c_$tag.tcl]
  set out    [file join $scratch c_$tag.out]
  a_wr $script "if {\[catch {\n$body\n} ::zerr\]} {\n  puts \"Z_ERR=\$::zerr\"\n  flush stdout\n  exit 9\n}\n"
  set had 0 ; set old {}
  if {$home ne {}} {
    set had [info exists ::env(HOME)]
    if {$had} { set old $::env(HOME) }
    file mkdir $home
    set ::env(HOME) $home
  }
  set rc 0
  if {$pre eq {}} {
    set e {} ; set opts {}
    if {[catch {exec timeout 25 $::XBIN --nogui --pipe -q --nolog --script $script >& $out} e opts]} {
      set rc [a_childrc $opts]
    }
  } else {
    set e {} ; set opts {}
    if {[catch {exec timeout 25 $::XBIN --nogui --pipe -q --nolog --preinit $pre --script $script >& $out} e opts]} {
      set rc [a_childrc $opts]
    }
  }
  if {$home ne {}} {
    if {$had} { set ::env(HOME) $old } else { catch {unset ::env(HOME)} }
  }
  set txt {}
  if {[file exists $out]} { set fp [open $out r] ; set txt [read $fp] ; close $fp }
  return [list $rc $txt]
}
proc a_childrc {opts} {
  set ec {}
  catch {set ec [dict get $opts -errorcode]}
  switch -- [lindex $ec 0] {
    CHILDSTATUS { return [lindex $ec 2] }
    CHILDKILLED { return 139 }
  }
  return 1
}
proc a_zrc  {r} { return [lindex $r 0] }
proc a_zval {r key} {
  set txt [lindex $r 1]
  set v {}
  regexp "${key}=(\[^\n\r\]*)" $txt -> v
  return [scrub [string trim $v]]
}

## The body every "restart" child runs: report the registry the way the user
## would see it, with the answer discipline intact.
set ::A_REPORT {
  set n NOPROC
  if {[llength [info commands ase::sim_list]]} { set n [llength [ase::sim_list]] }
  puts "Z_N=$n"
  set sel NOPROC
  if {[llength [info commands ase::sim_selected]]} { set sel [ase::sim_selected] }
  puts "Z_SEL=$sel"
  set ex NOPROC ; set ok NOPROC ; set org NOPROC ; set eok NOPROC
  if {[llength [info commands ase::sim_status]]} {
    set s [ase::sim_status ngspice]
    catch {set ex [dict get $s exe]}
    catch {set ok [dict get $s ok]}
  }
  puts "Z_EXE=$ex"
  puts "Z_OK=$ok"
  if {[llength [info commands ase::sim_list]]} {
    foreach e [ase::sim_list] {
      catch {set org [dict get $e origin]}
      catch {set eok [dict get $e ok]}
    }
  }
  puts "Z_ORIGIN=$org"
  puts "Z_EOK=$eok"
  puts "Z_DONE=1"
  exit 0
}

# ============================================================================
# A. THE STOCK TREE, WHERE NOTHING IS REGISTERED -- clause (c) of the item
# ============================================================================
# These four say the same thing four ways: a user who registers nothing must
# not be able to tell this change happened. A2 is a byte-identity guard, and
# it is the row that keeps test_ase_core's E1e / E2b / E4 goldens green
# without anyone editing them.

## HERMETIC BY CONSTRUCTION, AND THIS IS NOT PARANOIA -- IT WAS MEASURED.
## The person running this suite may have a simulator list of their own saved
## in USER_CONF_DIR/ase_simulators, which xschem.tcl reads at startup, and if
## they do then "nothing is registered" is FALSE in this very process:
## re-measured with such a file present, rows A1 A2 A3 A4 E8 E9 E10 all redden
## on a tree with nothing whatever wrong with it, and the next crew bisects
## that onto an unrelated change. So the in-process rows clear the registry
## first, and every claim about a FRESHLY STARTED xschem is measured in a
## child with HOME redirected into this suite's own scratch tree, where no
## such file exists.
a_reset
set A_CLEANHOME [file join $scratch home_clean]
file delete -force $A_CLEANHOME

## ⚠ AND IT IS EMPTIED AGAIN FOR EVERY CHILD THAT USES IT (2026-09-08).
## Deleting it once at the top was enough while registering wrote nothing:
## the only child that could leave a saved list behind was one that called
## ase::sim_write_conf, and the one that does (E3) was given an explicit path
## in the scratch tree. Registration now persists BY ITSELF, into
## $HOME/.xschem/ase_simulators, so E3's child leaves a real saved list in the
## shared clean HOME -- and every rc-layer row after it (E8-E10, E12, E13)
## then starts with a session entry it never asked for. Measured before this
## proc existed: E8 saw 2 entries instead of 1 and read `origin conf` for an
## entry an rc declared; E9's "empty list" was `sess-two`; E13 had 1 entry
## left after removing the only one it knew about. A clean HOME has to be
## clean per child, not per suite.
proc a_cleanhome {} {
  global A_CLEANHOME
  file delete -force $A_CLEANHOME
  file mkdir $A_CLEANHOME
  return $A_CLEANHOME
}

set AEO [lindex [auto_execok ngspice] 0]

check {A1 nothing registered: the resolver answers "the one on your PATH will run", in one dict} \
  [list [a_s5 ngspice] [a_sfield ngspice why]] \
  [list [list 1 ngspice {} path {}] {}]

check {A2 nothing registered: the command built for the run is byte-identical to today} \
  [a_runcmd $DECK] [list ngspice -b $DECK 2>@1]

check {A3 nothing registered: the resolver's own answer for WHICH FILE is auto_execok's -- said once, in one place} \
  [list [a_sfield ngspice resolved] $AEO] [list $AEO $AEO]

## A4 IS A REAL CHILD, not an in-process assertion. After the a_reset above,
## an in-process version of this row would only be re-reading what a_reset
## just wrote, which is a tautology, not a measurement. The claim -- a user
## who registered nothing cannot tell this change happened -- is about a
## freshly started xschem, so a freshly started xschem is what answers it,
## down to the command it would build for the run.
set A4B {
  set n NOPROC
  if {[llength [info commands ase::sim_list]]} { set n [llength [ase::sim_list]] }
  puts "Z_N=$n"
  set sel NOPROC
  if {[llength [info commands ase::sim_selected]]} { set sel [ase::sim_selected] }
  puts "Z_SEL=$sel"
  set c NOPROC
  if {[llength [info commands ase::backend::ngspice::run_cmd]]} {
    set c [ase::backend::ngspice::run_cmd {} @DECK@]
  }
  puts "Z_CMD=$c"
  puts "Z_DONE=1"
  exit 0
}
set A4C [a_child a4 [string map [list @DECK@ $DECK] $A4B] {} [a_cleanhome]]
check {A4 a freshly started xschem, on a machine where nobody has registered anything, has an empty list, nothing in force, and builds the same run command it always did} \
  [list [a_zrc $A4C] [a_zval $A4C Z_N] [a_zval $A4C Z_SEL] [a_zval $A4C Z_CMD] [a_zval $A4C Z_DONE]] \
  [list 0 0 {} [list ngspice -b $DECK 2>@1] 1]

# ============================================================================
# B. REGISTERING, LISTING, SELECTING AND REMOVING A BINARY OFF PATH
# ============================================================================
# The whole measured defect, inverted. B5 is the headline: the user's own
# build is what starts.

a_reset
set B1RV [a_ans ase::sim_register ng-one $STUB]
check {B1 a simulator with a name and an absolute path can be registered, and comes back with every field the user gave} \
  [list $B1RV [a_efields ng-one {name path args backend origin ok}]] \
  [list 1 [list ng-one $STUB {} {} session 1]]

check {B2 registering the only simulator puts it in force -- registering one does something visible} \
  [a_ans ase::sim_selected] ng-one

a_ans ase::sim_register ng-two $STUB2
check {B3 registering a SECOND simulator does not steal the choice away from the first} \
  [list [a_ans ase::sim_selected] [a_names]] [list ng-one [list ng-one ng-two]]

check {B4 with a registered simulator in force the resolver names THAT program, and says nothing is wrong} \
  [list [a_s5 ngspice] [a_sfield ngspice why]] \
  [list [list 1 $STUB {} registry ng-one] {}]

check {B5 THE HEADLINE the run now starts the user's own build, not whatever ngspice is on PATH} \
  [a_runcmd $DECK] [list $STUB -b $DECK 2>@1]

a_reset
a_ans ase::sim_register ng-args $STUB -args {-q --foo}
# ⚠ `-b` MOVED IN FRONT OF THE USER'S ARGS AT THE `annotate` MERGE, and this
# golden moved with it, deliberately. 0931 appended `-b` AFTER the user's words
# so that a user who registered nothing got a byte-identical command; the merge
# took `fluid-editing`'s order instead -- `<exe> -b <args> [-n] [-D casemode=]
# <deck>` -- because it is the order ase::sim_probe_argv composes, and a
# capability probe that measures a differently-shaped command from the one that
# runs is measuring the wrong thing. That is the class of defect the whole
# case-mode batch exists to close, so it outranks a one-token golden.
#
# WHAT 0931's CONTRACT ACTUALLY WAS is untouched and is asserted by B5 above: a
# user who registers nothing still gets `<exe> -b <deck> 2>@1`, byte for byte.
# The user's own words still land between the program and the deck, which is
# where they would type them; only `-b`, which is ours and not theirs, moved
# ahead of them.
check {B6 extra arguments the user typed land between the program and the deck, and 2>@1 is untouched} \
  [a_runcmd $DECK] [list $STUB -b -q --foo $DECK 2>@1]

a_reset
a_ans ase::sim_register ng-one $STUB
a_ans ase::sim_register ng-two $STUB2
set B7RV [a_ans ase::sim_unregister ng-two]
check {B7 a registered simulator can be removed, and removing one that was never there is refused by name} \
  [list [a_names] [a_refused ase::sim_unregister ng-nosuch]] \
  [list [list ng-one] REFUSED-ase]

a_reset
a_ans ase::sim_register ng-one $STUB
a_ans ase::sim_register ng-two $STUB2
a_ans ase::sim_unregister ng-one
check {B8 removing the one in force when a single simulator is left puts the survivor in force} \
  [list [a_names] [a_ans ase::sim_selected]] [list [list ng-two] ng-two]

a_reset
a_ans ase::sim_register ng-one $STUB
a_ans ase::sim_register ng-two $STUB2
a_ans ase::sim_register ng-three $STUB
a_ans ase::sim_select ng-one
a_ans ase::sim_unregister ng-one
check {B9 removing the one in force when two are left leaves nothing in force -- no guess is made for the user} \
  [list [a_names] [a_ans ase::sim_selected]] [list [list ng-two ng-three] {}]

set B10T [a_raisetext ase::sim_select ng-nosuch]
check {B10 asking for a simulator that was never registered is refused, and the refusal lists the ones that ARE} \
  [list [a_refused ase::sim_select ng-nosuch] \
        [expr {[string first ng-two $B10T] >= 0}] \
        [expr {[string first ng-three $B10T] >= 0}]] \
  [list REFUSED-ase 1 1]

a_reset
set ::ZZ_SIMDIR [file join $scratch bin]
a_ans ase::sim_register ng-var {$::ZZ_SIMDIR/ngstub}
check {B11 a path written the portable way the model files use is stored as the real file, and that file is what starts} \
  [list [a_efields ng-var {path}] [a_runcmd $DECK]] \
  [list [list $STUB] [list $STUB -b $DECK 2>@1]]

a_reset
set A_SAVEDCWD [pwd]
cd $scratch
a_ans ase::sim_register ng-rel [file join bin ngstub]
cd $A_SAVEDCWD
check {B12 a path typed relative to where the user was is stored as the real file, and survives the run moving to the run directory} \
  [list [a_efields ng-rel {path}] [a_runcmd $DECK]] \
  [list [list $STUB] [list $STUB -b $DECK 2>@1]]

a_reset
check {B13 nonsense in a registration is refused with a clean message, not swallowed and not a Tcl stack trace} \
  [list [a_refused ase::sim_register ng-bad $STUB -args "\{"] \
        [a_refused ase::sim_register ng-bad $STUB -nosuchoption 1] \
        [a_refused ase::sim_register {} $STUB]] \
  [list REFUSED-ase REFUSED-ase REFUSED-ase]

## B14 IS ITS OWN ROW AND NOT A FOURTH ARM OF B13, because the alternative to
## refusing is not a stack trace, it is SILENT PADDING: an option left without
## its value would be handed an empty one and the registration would appear to
## succeed with a setting the user never typed. Measured: with the refusal
## replaced by padding, every other row in this file still passes.
a_reset
set B14T [a_raisetext ase::sim_register ng-odd $STUB -args]
check {B14 an option typed without its value is refused and the offending option is named, instead of being quietly given a value the user never typed} \
  [list [a_refused ase::sim_register ng-odd $STUB -args] \
        [expr {[string first {-args} $B14T] >= 0}] \
        [regexp -nocase {pair|followed by a value|needs a value|without a value} $B14T] \
        [a_names]] \
  [list REFUSED-ase 1 1 {}]

## B15: WHICH SIMULATORS YOU ARE EVEN OFFERED. The Setup dialog item S2 will
## render this list, and the "more than one is waiting, pick one" sentence
## already does. Without the filter both would offer a simulator that cannot
## run this kind of analysis at all.
a_reset
a_ans ase::sim_register ng-spec $STUB  -backend spectre
a_ans ase::sim_register ng-any  $STUB2
a_ans ase::sim_register ng-ngsp $STUB  -backend ngspice
a_ans ase::sim_select {}
set B15WHY [a_sfield ngspice why]
check {B15 the list of simulators you are offered for one kind of run leaves out the ones registered for a different kind, and so does the "pick one" message} \
  [list [a_names_for {}] [a_names_for ngspice] [a_names_for spectre] \
        [expr {[string first ng-any $B15WHY] >= 0}] \
        [expr {[string first ng-ngsp $B15WHY] >= 0}] \
        [expr {[string first ng-spec $B15WHY] >= 0}]] \
  [list [list ng-spec ng-any ng-ngsp] [list ng-any ng-ngsp] [list ng-spec ng-any] 1 1 0]

# ============================================================================
# C. A REGISTERED PATH THAT IS WRONG MUST BE REPORTED, NOT SWALLOWED
# ============================================================================
# This whole feature area's failure mode is silence, and the silence is
# already shipped one proc away -- see C7. Four ways a path can be wrong,
# four separate things to say about it.

a_reset
set C1 [a_regbad ng-missing $MISSING]
set C2 [a_regbad ng-notexec $NOEXEC]
set C3 [a_regbad ng-folder  $ADIR]
set C4 [a_regbad ng-nopath  {}]

check {C1 a path with no file at it is reported, out loud, naming the entry and the path} \
  [list [a_rv $C1] [a_tag $C1] [a_names_in $C1 ng-missing] [a_names_in $C1 $MISSING] \
        [a_says $C1 {no file|does not exist|doesn't exist|is not there|isn't there|cannot find|can't find|no such file|nothing at}]] \
  [list 0 error 1 1 1]

check {C2 a file that is there but is not marked runnable is reported -- the exact case the neighbouring resolver drops on the floor} \
  [list [a_rv $C2] [a_tag $C2] [a_names_in $C2 ng-notexec] [a_names_in $C2 $NOEXEC] \
        [a_says $C2 {not marked|not executable|cannot run|can't run|not a program|permission|chmod}]] \
  [list 0 error 1 1 1]

check {C3 a FOLDER is reported as a folder -- the trap an executable-only check walks straight into} \
  [list [a_rv $C3] [a_tag $C3] [a_names_in $C3 ng-folder] [a_names_in $C3 $ADIR] \
        [a_says $C3 {folder|directory}] $A_DIRTRAP] \
  [list 0 error 1 1 1 [list 1 0 0]]

check {C4 a registration with no path at all is reported, naming the entry} \
  [list [a_rv $C4] [a_tag $C4] [a_names_in $C4 ng-nopath] \
        [a_says $C4 {no path|no file name|empty|blank|nothing was given|did not give|didn't give|no program}]] \
  [list 0 error 1 1]

check {C5 all four broken entries are KEPT in the list, flagged unusable, so the user can fix them instead of losing them} \
  [list [a_names] [a_efields ng-missing {ok}] [a_efields ng-notexec {ok}] \
        [a_efields ng-folder {ok}] [a_efields ng-nopath {ok}]] \
  [list [list ng-missing ng-notexec ng-folder ng-nopath] [list 0] [list 0] [list 0] [list 0]]

## PLAIN ENGLISH, asserted as a scan rather than as a vibe. The path and the
## entry name are removed first: they are the user's own words and may
## legitimately contain anything.
proc a_plain {r name path} {
  set m [a_msg $r]
  if {$m eq {NONE} || $m eq {NOPROC} || $m eq {}} { return NOSENTENCE }
  set m [string map [list $name {} $path {}] $m]
  foreach tok {auto_execok ase:: sim_ $::ASE_ dict} {
    if {[string first $tok $m] >= 0} { return "JARGON-$tok" }
  }
  if {[string first {ok 0} $m] >= 0} { return JARGON-state }
  return PLAIN
}
set C6M [list [a_msg $C1] [a_msg $C2] [a_msg $C3] [a_msg $C4]]
set C6DISTINCT 1
foreach m $C6M {
  if {$m eq {NONE} || $m eq {NOPROC} || $m eq {}} { set C6DISTINCT 0 }
}
if {[llength [lsort -unique $C6M]] != 4} { set C6DISTINCT 0 }
check {C6 the four sentences are four DIFFERENT sentences, and every one of them is plain English with no machinery in it} \
  [list $C6DISTINCT [a_plain $C1 ng-missing $MISSING] [a_plain $C2 ng-notexec $NOEXEC] \
        [a_plain $C3 ng-folder $ADIR] [a_plain $C4 ng-nopath {}]] \
  [list 1 PLAIN PLAIN PLAIN PLAIN]

## THE CONTRAST, PINNED AS KNOWN. ase::cosim_build_script gets the same
## question and answers with silence. This row asserts BOTH halves at once so
## nobody "fixes" the new surface by copying the old one, and so the day the
## old one is repaired this row is what tells them.
a_reset
set C7HAD [info exists ::ASE_COSIM_BUILD]
set C7OLD {}
if {$C7HAD} { set C7OLD $::ASE_COSIM_BUILD }
set ::ASE_COSIM_BUILD $NOEXEC
set C7SAID [a_echoed {set ::c7r [a_ans ase::cosim_build_script]}]
set C7R $::c7r
if {$C7HAD} { set ::ASE_COSIM_BUILD $C7OLD } else { catch {unset ::ASE_COSIM_BUILD} }
set C7NEW [a_regbad ng-c7 $NOEXEC]
check {C7 KNOWN the co-simulation build-script resolver answers the very same question with silence, while the new one speaks} \
  [list $C7R [llength $C7SAID] [a_rv $C7NEW] [expr {[a_msg $C7NEW] ne {NONE}}]] \
  [list {} 0 0 1]

## C8: THE PDK CASE, AND THE ONE WHERE THE OBVIOUS SENTENCE IS THE WRONG ONE.
## A workarea startup file names $::PDK_ROOT/bin/ngspice and PDK_ROOT is not
## set in this session. The file is not "missing" -- there is no file name yet
## to be missing -- and telling the user the file is not there would send them
## looking at a disk when the thing to fix is a setting. Measured: with this
## arm gone the entry falls through and gets the missing-file sentence, and
## every other row in this file still passes.
a_reset
set C8VARPATH {$::ZZ_ABSENT_ROOT/bin/ngspice}
set C8 [a_regbad pdk-build $C8VARPATH]
## THE USER'S OWN WORDS COME OUT BEFORE THE SENTENCE IS READ. The entry name
## and the location they typed are echoed back inside the sentence, so a
## fixture that happened to contain one of the words being looked for would
## satisfy this row all by itself -- measured: an earlier draft named the
## fixture $::ZZ_NO_SUCH_SETTING and passed with the WRONG sentence, because
## the word "setting" was in the path.
set C8REST [string map [list pdk-build {} $C8VARPATH {}] [a_msg $C8]]
check {C8 a location that mentions a setting this session does not know about is reported as exactly that, not blamed on a missing file, and the entry is kept so it can be fixed} \
  [list [a_rv $C8] [a_tag $C8] [a_names_in $C8 pdk-build] [a_names_in $C8 $C8VARPATH] \
        [regexp -nocase {setting|does not know|doesn't know|not know about} $C8REST] \
        [expr {[a_msg $C8] ne [a_msg $C1]}] \
        [a_plain $C8 pdk-build $C8VARPATH] \
        [a_efields pdk-build {ok}]] \
  [list 0 error 1 1 1 1 PLAIN [list 0]]

# ============================================================================
# D. WHICH BINARY WILL ACTUALLY RUN -- one resolver, and it never guesses
# ============================================================================

proc a_runcmd_do {deck} { set ::a_rc2 [a_runcmd $deck] }
proc a_runcmd_said {deck} {
  set ::a_rc2 NOPROC
  set said [a_echoed [list a_runcmd_do $deck]]
  set tag NONE ; set msg NONE
  foreach p $said {
    if {[lindex $p 0] eq {error}} { set tag error ; set msg [lindex $p 1] ; break }
  }
  if {$tag eq {NONE} && [llength $said]} {
    set tag [lindex [lindex $said 0] 0] ; set msg [lindex [lindex $said 0] 1]
  }
  return [list $::a_rc2 $tag $msg]
}

a_reset
set DGONE [file join $scratch bin nggone]
a_wr $DGONE "#!/bin/sh\nexit 0\n" 0755
set D1REG [a_ans ase::sim_register ng-gone $DGONE]
file delete -force $DGONE
check {D1 the simulator you picked has since been deleted: the run STOPS and says so, it does not quietly start a different program} \
  [list $D1REG [a_sfield ngspice ok] \
        [expr {[string first $DGONE [a_sfield ngspice why]] >= 0}] \
        [a_runcmd_refused $DECK]] \
  [list 1 0 1 REFUSED-ase]

a_reset
a_ans ase::sim_register ng-one $STUB
a_ans ase::sim_register ng-two $STUB2
## The one internal reach in this file, and the plan names the variable
## verbatim: every documented route to this state is refused at the door, so
## the resolver's own defensive arm is only reachable from here.
set D2FORCE NOVAR
if {[info exists ::ase::sim_use]} { set ::ase::sim_use zz-never-registered ; set D2FORCE OK }
set D2WHY [a_sfield ngspice why]
check {D2 a choice naming a simulator nobody registered is not honoured and not hidden: the answer says which name is missing and which ones exist} \
  [list $D2FORCE [a_sfield ngspice ok] \
        [expr {[string first zz-never-registered $D2WHY] >= 0}] \
        [expr {[string first ng-one $D2WHY] >= 0}] \
        [a_sfield ngspice source]] \
  [list OK 0 1 1 path]

a_reset
a_ans ase::sim_register ng-spec $STUB -backend spectre
a_ans ase::sim_select ng-spec
set D3WHY [a_sfield ngspice why]
set D3A [list [a_sfield ngspice ok] \
              [expr {[string first spectre $D3WHY] >= 0}] \
              [expr {[string first ngspice $D3WHY] >= 0}]]
a_reset
a_ans ase::sim_register ng-any $STUB
set D3B [a_sfield ngspice ok]
check {D3 a simulator registered for a different backend is not used for this one, and is said so by name; one registered for no particular backend serves} \
  [list $D3A $D3B] [list [list 0 1 1] 1]

a_reset
a_ans ase::sim_register ng-one $STUB
a_ans ase::sim_register ng-two $STUB2
a_ans ase::sim_select {}
set D4WHY [a_sfield ngspice why]
set D4SAID [a_runcmd_said $DECK]
check {D4 two simulators registered and none picked: today's PATH program still runs, and the user is TOLD both are waiting} \
  [list [a_sfield ngspice ok] [a_sfield ngspice source] [a_sfield ngspice resolved] \
        [expr {$D4WHY ne {} && [string first ng-one $D4WHY] >= 0 && [string first ng-two $D4WHY] >= 0}] \
        [lindex $D4SAID 0] [lindex $D4SAID 1]] \
  [list 1 path $AEO 1 [list ngspice -b $DECK 2>@1] error]

a_reset
a_ans ase::sim_register ng-broken $MISSING
set D5WHY [a_sfield ngspice why]
set D5T [a_raisetext ase::sim_exe ngspice]
check {D5 every caller renders the SAME sentence; it is written in one place and nobody re-words it} \
  [list [expr {$D5WHY ne {} && $D5WHY ne {NOPROC}}] \
        [a_refused ase::sim_exe ngspice] \
        [expr {$D5T ne {} && [string first $D5WHY $D5T] >= 0}]] \
  [list 1 REFUSED-ase 1]

## STRUCTURAL. Take the four sentences apart at the user's own words and
## count the fixed pieces in the source: each must exist exactly once, or
## some caller is re-wording what the mint already said.
set D6SRC [a_nocomment $ASETCL]
set D6N 0 ; set D6ALLONE 1
foreach pair [list [list $C1 ng-missing $MISSING] [list $C2 ng-notexec $NOEXEC] \
                   [list $C3 ng-folder $ADIR]    [list $C4 ng-nopath {}]] {
  set m [a_msg [lindex $pair 0]]
  if {$m eq {NONE} || $m eq {NOPROC} || $m eq {}} { set D6ALLONE 0 ; continue }
  set chunks [list $m]
  foreach word [list [lindex $pair 1] [lindex $pair 2]] {
    if {$word eq {}} { continue }
    set next {}
    foreach c $chunks { foreach piece [split [string map [list $word \x01] $c] \x01] { lappend next $piece } }
    set chunks $next
  }
  foreach c $chunks {
    set c [string trim $c]
    if {[string length $c] < 25} { continue }
    incr D6N
    if {[a_count $D6SRC $c] != 1} { set D6ALLONE 0 }
  }
}
check {D6 STRUCTURAL each fixed phrase the user reads exists in exactly one place in the source} \
  [list [expr {$D6N >= 4}] $D6ALLONE] [list 1 1]

# ============================================================================
# E. IT SURVIVES A RESTART, AND AN rc FILE CAN PUT ONE THERE AND TAKE IT AWAY
# ============================================================================
# E6 and E8-E10 are REAL child xschem processes. Nothing in-process can prove
# "survives a restart", and nothing in-process can reach the rc layer at all:
# an rc runs before ase.tcl exists, so --preinit is the only honest stand-in
# for it and xinit.c runs that even earlier.

proc a_shape {} {
  set l [a_ans ase::sim_list]
  if {$l eq {NOPROC} || [string match RAISED:* $l]} { return $l }
  set out {}
  foreach e $l {
    set row {}
    foreach k {name path args backend ok} {
      if {[catch {dict get $e $k} v]} { set v "NOKEY-$k" }
      lappend row $v
    }
    lappend out $row
  }
  return $out
}

a_reset
a_ans ase::sim_register ng-one $STUB -args {-q}
a_ans ase::sim_register ng-two $STUB2
a_ans ase::sim_select ng-two
set E1P [file join $scratch conf_written]
set E1RV [a_ans ase::sim_write_conf $E1P]
set E1TXT [a_slurp $E1P]
check {E1 the list can be saved to a file, and what lands there is a real, complete, re-readable script} \
  [list $E1RV [file exists $E1P] [info complete $E1TXT] \
        [expr {[string first {ase::sim_register} $E1TXT] >= 0}]] \
  [list 1 1 1 1]

## ⚠ WHAT COMES BACK IN FORCE IS THE INSTALLATION DEFAULT, NOT THE CHOICE THIS
## SESSION MADE, AND THAT IS THE 2026-09-08 RULING RATHER THAN A REGRESSION.
## This row used to demand "the same list AND the same choice", and it was
## right at the time: the saved list carried `ase::sim_select <what is in force
## right now>`. The user then ruled that registering is environment and reaches
## disk at once, while *which* registered simulator is used "is an option that
## is part of the ASE-L state. If changed, that results in dirtiness. User must
## explicitly save." So `ase::sim_write_body` now writes ase::sim_default -- the
## installation default -- and `ase::sim_select ng-two` above, made from the
## session layer, is deliberately NOT in the file. The default here is `ng-one`
## because registering the first simulator on an empty list seeds it.
##
## The LIST half is unchanged and still asserted field for field: that is what
## a restart must reproduce exactly.
set E2SHAPE [a_shape]
set E2SESSCHOICE [a_ans ase::sim_selected]
set E2DEF [a_ans ase::sim_default_choice]
a_reset
set E2LOAD [a_ans ase::sim_load_conf $E1P]
set E2AFTER [a_shape]
check {E2 saving then reading back gives the same list field for field, and what comes back in force is the INSTALLATION DEFAULT -- the choice this session made is state, and state does not travel in the machine's simulator list} \
  [list $E2LOAD [expr {$E2AFTER eq $E2SHAPE}] $E2SESSCHOICE $E2DEF \
        [a_ans ase::sim_selected] [a_ans ase::sim_default_choice] \
        [expr {[string first {ase::sim_select ng-two} $E1TXT] >= 0}] \
        [expr {[string first {ase::sim_select ng-one} $E1TXT] >= 0}]] \
  [list 1 1 ng-two {entry ng-one} ng-one {entry ng-one} 0 1]

## E3 needs a REAL rc-origin entry beside a session one, and only a real
## startup can make one, so this row is a child too.
set E3CONF [file join $scratch conf_e3]
set E3B {
  set r NOPROC
  if {[llength [info commands ase::sim_register]]} { set r [ase::sim_register sess-two @STUB2@] }
  puts "Z_REG=$r"
  set w NOPROC
  if {[llength [info commands ase::sim_write_conf]]} { set w [ase::sim_write_conf @CONF@] }
  puts "Z_WROTE=$w"
  set t {}
  if {[file exists @CONF@]} { set fp [open @CONF@ r] ; set t [read $fp] ; close $fp }
  puts "Z_HASRC=[expr {[string first rc-one $t] >= 0}]"
  puts "Z_HASSESS=[expr {[string first sess-two $t] >= 0}]"
  puts "Z_DONE=1"
  exit 0
}
set E3PRE "set ::ASE_SIMULATORS \[list \[list name rc-one path $STUB args {} backend {}\]\]"
set E3C [a_child e3 [string map [list @STUB2@ $STUB2 @CONF@ $E3CONF] $E3B] $E3PRE [a_cleanhome]]
check {E3 saving your list does not freeze a copy of what the startup configuration file already declares -- only your own entries are written} \
  [list [a_zrc $E3C] [a_zval $E3C Z_WROTE] [a_zval $E3C Z_HASRC] [a_zval $E3C Z_HASSESS] [a_zval $E3C Z_DONE]] \
  [list 0 1 0 1 1]

set ::E4PATH [file join $scratch no_such_dir deeper conf]
set E4SAID [a_echoed {set ::e4rv [a_ans ase::sim_write_conf $::E4PATH]}]
check {E4 saving to somewhere that cannot be written says so and gives up cleanly, instead of blowing up} \
  [list $::e4rv [expr {[llength $E4SAID] >= 1}]] [list 0 1]

set ::E5PATH [file join $scratch conf_corrupt]
a_wr $::E5PATH "this is not a simulator list at all \{\{\{\n"
a_reset
set E5SAID [a_echoed {set ::e5rv [a_ans ase::sim_load_conf $::E5PATH]}]
set E5AFTER [a_ans ase::sim_register ng-after $STUB]
check {E5 a damaged saved file is reported and shrugged off, and the simulator list still works afterwards} \
  [list $::e5rv [expr {[llength $E5SAID] >= 1}] $E5AFTER [a_names]] \
  [list 0 1 1 [list ng-after]]

# --- the real restart --------------------------------------------------------
set E6HOME [file join $scratch home_e6]
set E6W {
  puts "Z_UCD=$::USER_CONF_DIR"
  set r NOPROC
  if {[llength [info commands ase::sim_register]]} { set r [ase::sim_register ng-restart @STUB@] }
  puts "Z_REG=$r"
  set w NOPROC
  if {[llength [info commands ase::sim_write_conf]]} { set w [ase::sim_write_conf] }
  puts "Z_WROTE=$w"
  puts "Z_FILE=[file exists [file join $::USER_CONF_DIR ase_simulators]]"
  puts "Z_DONE=1"
  exit 0
}
set E6C1 [a_child e6w [string map [list @STUB@ $STUB] $E6W] {} $E6HOME]
set E6C2 [a_child e6r $::A_REPORT {} $E6HOME]
check {E6 a simulator registered and saved in one session is still there, and still in force, the next time xschem starts} \
  [list [a_zrc $E6C1] [a_zval $E6C1 Z_WROTE] [a_zval $E6C1 Z_FILE] \
        [a_zrc $E6C2] [a_zval $E6C2 Z_N] [a_zval $E6C2 Z_SEL] [a_zval $E6C2 Z_EXE] [a_zval $E6C2 Z_DONE]] \
  [list 0 1 1 0 1 ng-restart $STUB 1]

check {E7 STRUCTURAL the saved list is actually READ at startup, once, beside the other startup loaders} \
  [list [llength [a_lines_matching $XTCL {ase::sim_load_conf}]] \
        [expr {[llength [a_lines_matching $XTCL {ase::sim_load_conf}]] == 1 \
               && abs([lindex [a_lines_matching $XTCL {ase::sim_load_conf}] 0] \
                      - [lindex [a_lines_matching $XTCL {load_net_hilight_conf}] end]) <= 12}]] \
  [list 1 1]

# --- the rc layer, put there and taken away ----------------------------------
set E8PRE "set ::ASE_SIMULATORS \[list \[list name rc-one path $STUB args {} backend {}\]\]"
set E8C [a_child e8 $::A_REPORT $E8PRE [a_cleanhome]]
check {E8 a startup configuration file can put a simulator in the list and in force, exactly the way it already sets the default models} \
  [list [a_zrc $E8C] [a_zval $E8C Z_N] [a_zval $E8C Z_SEL] [a_zval $E8C Z_EXE] \
        [a_zval $E8C Z_ORIGIN] [a_zval $E8C Z_DONE]] \
  [list 0 1 rc-one $STUB rc 1]

set E9C [a_child e9 $::A_REPORT {} [a_cleanhome]]
check {E9 the same xschem started WITHOUT that line has an empty list and is back to the program on your PATH -- removable, proved not asserted} \
  [list [a_zrc $E9C] [a_zval $E9C Z_N] [a_zval $E9C Z_SEL] [a_zval $E9C Z_EXE] [a_zval $E9C Z_DONE]] \
  [list 0 0 {} ngspice 1]

set E10PRE_A {set ::ASE_SIMULATOR zz-not-registered-anywhere}
set E10PRE_B "set ::ASE_SIMULATORS \[list \[list name rc-bad path $MISSING args {} backend {}\]\]"
set E10A [a_child e10a $::A_REPORT $E10PRE_A [a_cleanhome]]
set E10B [a_child e10b $::A_REPORT $E10PRE_B [a_cleanhome]]
check {E10 a mistake in the startup configuration file does not take ASE-L down with it: xschem still starts and still answers} \
  [list [a_zrc $E10A] [a_zval $E10A Z_N] [a_zval $E10A Z_EXE] [a_zval $E10A Z_DONE] \
        [a_zrc $E10B] [a_zval $E10B Z_N] [a_zval $E10B Z_EOK] [a_zval $E10B Z_DONE]] \
  [list 0 0 ngspice 1 0 1 0 1]

## E11 IS A ROW ABOUT SILENCE, WHICH IS THE ONLY KIND OF ROW THAT CAN SEE
## THIS GUARD. E5 above proves a DAMAGED saved list is reported; the ordinary
## first run has no saved list at all, and that is not a failure. Both cases
## return 0, so a row that only asserted the answer could not tell them
## apart -- measured: with the "no file yet" guard removed, every fresh
## install gets a red error sentence at every startup and this file stayed
## green until this row existed.
a_reset
set ::E11PATH [file join $scratch there_is_no_saved_list_here]
file delete -force $::E11PATH
set E11SAID [a_echoed {set ::e11rv [a_ans ase::sim_load_conf $::E11PATH]}]
check {E11 a first run, with no saved simulator list yet, says NOTHING about it -- an ordinary fresh install is not an error to complain about} \
  [list $::e11rv [llength $E11SAID] [llength $E5SAID] [a_names]] \
  [list 0 0 1 {}]

## E12: THE ONE MALFORMATION THAT USED TO KILL THE EDITOR. `foreach x $v`
## parses $v AS A LIST before the body runs once, so a mismatched brace in
## the rc raised in the loop HEADER, outside the catch the body was wrapped
## in. Measured before the fix: exit 1, no schematic editor at all, "STARTUP
## ABORTED ... Failing file: ase.tcl". The second child is the CONTROL that
## makes this a parity claim and not a wish: the identical typo in
## ::ASE_DEFAULT_MODELS, one of the two older startup settings this one was
## modelled on, has always started normally.
set E12PRE_A {set ::ASE_SIMULATORS "\{name rc-x path /bin/sh"}
set E12PRE_B {set ::ASE_DEFAULT_MODELS "\{a b"}
set E12A [a_child e12a $::A_REPORT $E12PRE_A [a_cleanhome]]
set E12B [a_child e12b $::A_REPORT $E12PRE_B [a_cleanhome]]
check {E12 a simulator list with a mismatched brace in it costs the user a sentence, not the whole editor -- exactly like the older startup settings it sits beside} \
  [list [a_zrc $E12A] [a_zval $E12A Z_N] [a_zval $E12A Z_EXE] [a_zval $E12A Z_DONE] \
        [a_zrc $E12B] [a_zval $E12B Z_DONE]] \
  [list 0 0 ngspice 1 0 1]

## E13: THE OTHER HALF OF THE DECISION THAT AN ENTRY A STARTUP FILE DECLARES
## CANNOT BE REMOVED FOR GOOD FROM INSIDE XSCHEM. The removal itself works and
## is measured by B7; what this row measures is that the user is TOLD it will
## be back, and told where to go to make it stick. Without it the entry
## silently reappears at the next start and the user has no way to know why.
## It must be a child: only a real startup can make a real rc-declared entry.
set E13B {
  set ::zz_said {}
  set zz_had [expr {[info commands ::ase::echo] ne {}}]
  if {$zz_had} { rename ::ase::echo ::zz_old_echo }
  proc ::ase::echo {msg {tag {}}} { lappend ::zz_said [list $tag $msg] ; return 1 }
  set rv NOPROC
  catch {set rv [ase::sim_unregister rc-one]}
  catch {rename ::ase::echo {}}
  if {$zz_had} { rename ::zz_old_echo ::ase::echo }
  set tag NONE ; set msg NONE
  foreach zp $::zz_said { set tag [lindex $zp 0] ; set msg [lindex $zp 1] }
  puts "Z_RV=$rv"
  puts "Z_TAG=$tag"
  puts "Z_NAMES=[expr {[string first rc-one $msg] >= 0 ? 1 : 0}]"
  puts "Z_SAYS=[regexp -nocase {be back|comes back|again the next time} $msg]"
  puts "Z_TELLS=[regexp -nocase {startup configuration file} $msg]"
  puts "Z_FIX=[regexp -nocase {edit that file|remove it for good} $msg]"
  set zz_m [string map [list rc-one {}] $msg]
  set zz_jargon none
  foreach zt {auto_execok ase:: sim_ origin dict} {
    if {[string first $zt $zz_m] >= 0} { set zz_jargon $zt }
  }
  puts "Z_JARGON=$zz_jargon"
  set zz_n NOPROC
  if {[llength [info commands ase::sim_list]]} { set zz_n [llength [ase::sim_list]] }
  puts "Z_LEFT=$zz_n"
  puts "Z_DONE=1"
  exit 0
}
set E13PRE "set ::ASE_SIMULATORS \[list \[list name rc-one path $STUB args {} backend {}\]\]"
set E13C [a_child e13 $E13B $E13PRE [a_cleanhome]]
check {E13 taking out a simulator that a startup configuration file put there works, and you are told in plain English that it will be back next time and where to go to stop that} \
  [list [a_zrc $E13C] [a_zval $E13C Z_RV] [a_zval $E13C Z_LEFT] [a_zval $E13C Z_TAG] \
        [a_zval $E13C Z_NAMES] [a_zval $E13C Z_SAYS] [a_zval $E13C Z_TELLS] \
        [a_zval $E13C Z_FIX] [a_zval $E13C Z_JARGON] [a_zval $E13C Z_DONE]] \
  [list 0 1 0 note 1 1 1 1 none 1]

# ============================================================================
# F. ONE RESOLUTION, FED TO THE RUN AND TO EVERYONE ELSE WHO ASKS
# ============================================================================
# Twelve places across twelve suites still decide "is a simulator available"
# with their own auto_execok call. This row states the contract they would
# use, both arms in one line: with nothing registered the resolver agrees
# with them; with a simulator in force it does not, which is the measure of
# how wrong they will be. Repointing them is NOT this item's work.

a_reset
set F1A [a_sfield ngspice resolved]
a_ans ase::sim_register ng-one $STUB
set F1B [a_sfield ngspice resolved]
check {F1 with nothing registered the resolver names the same program the old checks name; with one registered it names the user's, and they no longer agree} \
  [list $F1A $F1B [expr {$F1B ne $AEO}]] [list $AEO $STUB 1]

# ============================================================================
# G. THE SPEC STOPS DESCRIBING A RUN THAT HAS NOT HAPPENED FOR A LONG TIME
# ============================================================================
set G1DOC [a_slurp $SPECMD]
check {G1 STRUCTURAL the written description matches the run that actually happens, and names where the choice of program is made} \
  [list [expr {[string first {-o <cell>_ase.log} $G1DOC] >= 0}] \
        [expr {[string first {ase::sim_status} $G1DOC] >= 0}]] \
  [list 0 1]

# ============================================================================
# H. THE NON-GUI HALF THE GUI FRONT DOOR CANNOT BE BUILT WITHOUT -- ISSUE 0937
# ============================================================================
# Backlog item S2 puts a Simulators dialog on the ASE-L session window's Setup
# menu. Three of the four things that dialog has to say do not exist yet, and
# none of them is a widget:
#
#   * REMOVE MUST SAY WHAT HAPPENS NEXT. Measured at 439d1087, all three arms:
#     taking out the simulator currently in force printed NOTHING AT ALL --
#     whether it was the only one (the choice is silently cleared and the
#     program on your PATH takes over), one of two (the survivor is silently
#     promoted into force), or one of three (nothing is left in force). Under
#     ruling D5-4 the sentence is minted in ase.tcl, not written in the dialog,
#     so it is measured here rather than in the dialog suite. R1 R2 R3 R4.
#
#   * A ROW MUST BE ABLE TO SAY WHY IT IS UNUSABLE. The stored entry carries
#     name path args backend origin ok and no reason, so a list has nothing to
#     put in a Problem column; and re-checking the stored path is not a
#     substitute -- for a location naming a setting this session does not know
#     about, registration says "setting" and a re-check says "there is no file
#     at", so the row would contradict, in writing, the sentence the user was
#     just given. R5 R6 R7.
#
#   * A CLEARED CHOICE MUST SURVIVE A RESTART. Issue 0932, on this item's path
#     rather than beside it: the dialog offers "none of mine, use the program
#     on my PATH", and today saving that writes two register lines and no
#     selection line, so reading it back at the next start puts the first entry
#     in force again and the user's own gesture is silently undone. R8.
#
#   * AND THE DIALOG MUST RENDER THE MINT, NEVER RE-WORD IT. R9 counts the
#     fixed pieces of the four new sentences in BOTH files -- exactly once in
#     ase.tcl, never in ase_window.tcl. R10 pins the seam that makes that
#     possible: one recorder, so the dialog can show the very sentence the CIW
#     was given instead of composing a second one. Row D6 above cannot see any
#     of this: it scans one file, and only the four registration sentences.
#
# THE WIDGETS ARE NOT HERE. tests/headless/test_ase_simdlg_0937.tcl drives the
# real menu entry and the real dialog; this section owns everything that is
# still true with no display attached.

set ASEWIN [file join $repo src ase_window.tcl]

## The removal channel, collected exactly the way a_regbad collects the
## registration one: what unregister answered, HOW MANY sentences the user
## got, and the tag and text of the first. The count matters on its own --
## "it says what happens next" and "it says it once" are different claims.
proc a_unreg_do {name} { set ::a_urv [a_ans ase::sim_unregister $name] }
proc a_unreg {name} {
  set ::a_urv NOPROC
  set said [a_echoed [list a_unreg_do $name]]
  set tag NONE ; set msg NONE
  if {[llength $said]} {
    set tag [lindex [lindex $said 0] 0] ; set msg [lindex [lindex $said 0] 1]
  }
  return [list $::a_urv $tag $msg [llength $said]]
}
proc a_n {r} { return [lindex $r 3] }

a_reset
a_ans ase::sim_register solo $STUB
set R1 [a_unreg solo]
check {R1 removing the simulator that was in use, with none of your own left, says so once: which one went, and that the program your system finds on your PATH is what will start now} \
  [list [a_rv $R1] [a_n $R1] [a_tag $R1] [a_names_in $R1 solo] \
        [a_says $R1 {PATH}] [a_names] [a_ans ase::sim_selected] \
        [a_plain $R1 solo {}]] \
  [list 1 1 note 1 1 {} {} PLAIN]

a_reset
a_ans ase::sim_register first-r2 $STUB
a_ans ase::sim_register second-r2 $STUB2
set R2 [a_unreg first-r2]
check {R2 removing the one in use when a single simulator is left names the survivor as the one that will start now -- the silent promotion, spoken} \
  [list [a_rv $R2] [a_n $R2] [a_tag $R2] [a_names_in $R2 first-r2] \
        [a_names_in $R2 second-r2] [a_ans ase::sim_selected] \
        [a_plain $R2 first-r2 {}]] \
  [list 1 1 note 1 1 second-r2 PLAIN]

## R3 IS A CONTROL AND IT IS GREEN TODAY. Removing a simulator that was not in
## use changes nothing the user needs telling about, and the new sentence must
## not be bought by making that case chatty too.
a_reset
a_ans ase::sim_register keep-r3 $STUB
a_ans ase::sim_register other-r3 $STUB2
set R3 [a_unreg other-r3]
check {R3 removing a simulator that was NOT the one in use still says nothing at all -- the correct silence is not traded away for the new sentence} \
  [list [a_rv $R3] [a_n $R3] [a_names] [a_ans ase::sim_selected]] \
  [list 1 0 [list keep-r3] keep-r3]

## STRUCTURAL, and it exists because NO BEHAVIOURAL ROW IN THIS FILE CAN SEE
## IT. Row E13 reads the LAST sentence a removal echoed, so a new say-site
## placed after the startup-configuration-file one would redden E13 instead of
## this, and the next reader would bisect onto the wrong change. The order is
## a contract: what-happens-next first, "it will be back next time" last.
proc a_procbody {src name} {
  set out {} ; set on 0
  foreach l [split $src "\n"] {
    if {!$on} {
      if {[string first "proc $name " $l] == 0} { set on 1 }
      continue
    }
    if {[regexp {^\}} $l]} { break }
    lappend out $l
  }
  return [join $out "\n"]
}
set R4BODY [a_procbody [a_nocomment $ASETCL] ase::sim_unregister]
set R4RC [string first {rc_removed} $R4BODY]
set R4P  [string first {removed_now_path} $R4BODY]
set R4O  [string first {removed_now_other} $R4BODY]
check {R4 STRUCTURAL both what-happens-next sentences are said inside the removal itself, and the startup-configuration-file one is still said LAST} \
  [list [expr {$R4P >= 0}] [expr {$R4O >= 0}] [expr {$R4RC >= 0}] \
        [expr {$R4RC > $R4P && $R4RC > $R4O}]] \
  [list 1 1 1 1]

## R5-R7: the per-entry reason. A Problem column has to come from somewhere,
## and the two obvious somewheres are both wrong: the `ok` field is a boolean
## with no words in it, and re-running the file check on the stored path
## answers `missing` for a location whose setting is unknown -- a DIFFERENT
## sentence from the one registration just gave the user, about the same entry.
a_reset
a_ans ase::sim_register ok5 $STUB
set R5M [a_regbad miss5 $MISSING]
set R5N [a_regbad nox5  $NOEXEC]
set R5D [a_regbad dir5  $ADIR]
set R5E [a_regbad none5 {}]
set R5V [a_regbad var5  $C8VARPATH]
set R5NOENT [ase::sim_why noentry zz-never-registered {} [a_names]]
check {R5 the list can say, entry by entry, what is wrong with THAT one -- and it is word for word the sentence the user was given when they registered it} \
  [list [a_ans ase::sim_entry_why ok5] \
        [expr {[a_ans ase::sim_entry_why miss5] eq [a_msg $R5M]}] \
        [expr {[a_ans ase::sim_entry_why nox5]  eq [a_msg $R5N]}] \
        [expr {[a_ans ase::sim_entry_why dir5]  eq [a_msg $R5D]}] \
        [expr {[a_ans ase::sim_entry_why none5] eq [a_msg $R5E]}] \
        [expr {[a_ans ase::sim_entry_why var5]  eq [a_msg $R5V]}] \
        [regexp -nocase {setting|does not know|doesn't know} [a_ans ase::sim_entry_why var5]] \
        [expr {[string first {no file at} [a_ans ase::sim_entry_why var5]] < 0}] \
        [a_ans ase::sim_entry_why zz-never-registered]] \
  [list {} 1 1 1 1 1 1 1 $R5NOENT]

a_reset
set R6BIN [file join $scratch bin ng6]
a_wr $R6BIN "#!/bin/sh\nexit 0\n" 0755
a_ans ase::sim_register live6 $R6BIN
set R6A [a_ans ase::sim_entry_why live6]
set R6OKA [a_efields live6 {ok}]
file delete -force $R6BIN
set R6B [a_ans ase::sim_entry_why live6]
set R6OKB [a_efields live6 {ok}]
a_wr $R6BIN "#!/bin/sh\nexit 0\n" 0755
set R6C [a_ans ase::sim_entry_why live6]
check {R6 the reason is worked out fresh every time it is asked for, never read back from what was true at registration: delete the program and the row explains itself, put it back and the row goes quiet} \
  [list $R6A [expr {$R6B ne {} && $R6B ne {NOPROC} && [string first $R6BIN $R6B] >= 0}] \
        $R6C $R6OKA $R6OKB] \
  [list {} 1 {} [list 1] [list 1]]

proc a_why_agree {name} {
  set w1 [a_ans ase::sim_entry_why $name]
  set w2 [a_sfield ngspice why]
  if {$w1 eq {NOPROC} || $w2 eq {NOPROC}} { return NOPROC }
  return [expr {$w1 eq $w2 ? 1 : 0}]
}
set R7 {}
foreach {r7n r7p} [list miss7 $MISSING nox7 $NOEXEC dir7 $ADIR var7 $C8VARPATH] {
  a_reset
  a_ans ase::sim_register $r7n $r7p
  lappend R7 [a_why_agree $r7n]
}
check {R7 ONE reason, wherever it is read: what the list shows against an entry and what the run refuses with are the same sentence, in all four broken arms} \
  $R7 [list 1 1 1 1]

## R8: ISSUE 0932, WHICH IS ON THIS ITEM'S PATH AND NOT BESIDE IT. The dialog
## offers "none of mine -- use the program on my PATH". Real restarts, HOME
## redirected, because nothing in-process can prove what the next start does.
## The second pair is the CONTROL: a choice that WAS made must still survive,
## so this cannot be satisfied by simply forgetting choices.
##
## ⚠ WHAT THIS ROW MEASURES MOVED ON 2026-09-08, AND THE THING 0932 EXISTS FOR
## DID NOT. It used to make the "none of mine" gesture IN THE SESSION and then
## restart. Under the user's ruling that gesture is a CHOICE -- ASE-L state,
## which dirties a session and waits for an explicit save -- so it no longer
## reaches the machine's simulator list, and R8b below measures exactly that.
## What 0932 is actually about survives untouched and is what is measured here:
## a saved list whose selection line says "none of mine" must come back with
## NOTHING of the user's in force, and NOT with the first entry silently
## promoted, which was 0932's defect. The list is written by hand because that
## is a documented way to have one ("Edit by hand if you like: it is a plain
## Tcl script of ase::sim_register lines") and because it states the file's
## contract without going through the writer that is under test elsewhere.
set R8HOME  [file join $scratch home_r8a]
set R8HOME2 [file join $scratch home_r8b]
file delete -force $R8HOME
file delete -force $R8HOME2
proc a_conf_in_home {home body} {
  a_wr [file join $home .xschem ase_simulators] $body
}
set R8LINES "ase::sim_register r8-a $STUB\nase::sim_register r8-b $STUB2\n"
a_conf_in_home $R8HOME  "$R8LINES[list ase::sim_select {}]\n"
a_conf_in_home $R8HOME2 "$R8LINES[list ase::sim_select r8-b]\n"
set R8C2 [a_child r8r1 $::A_REPORT {} $R8HOME]
set R8C4 [a_child r8r2 $::A_REPORT {} $R8HOME2]
check {R8 "use the program on my PATH" is a choice like any other and it survives a restart -- and the control arm proves a real pick still survives one too} \
  [list [a_zrc $R8C2] [a_zval $R8C2 Z_N] [a_zval $R8C2 Z_SEL] [a_zval $R8C2 Z_EXE] \
        [a_zval $R8C2 Z_DONE] \
        [a_zrc $R8C4] [a_zval $R8C4 Z_N] [a_zval $R8C4 Z_SEL] [a_zval $R8C4 Z_EXE] \
        [a_zval $R8C4 Z_DONE]] \
  [list 0 2 {} ngspice 1 0 2 r8-b $STUB2 1]

## R8b: THE RULING ITSELF, THROUGH TWO REAL STARTS AND NOT ONE ASSERTION.
## One child registers two simulators and picks the second -- and calls NO
## saver at all. The next start must find BOTH simulators (registering is
## environment: "something that can make it to disk right away as soon as
## done") and must NOT be running the second one (choosing is state: "if
## changed, that results in dirtiness. User must explicitly save"). The two
## halves of the user's sentence, in one restart, neither of which the old
## shape could see: before this change the registration would have been lost
## and the choice would have been the only thing that could reach disk.
set R8HOME3 [file join $scratch home_r8c]
file delete -force $R8HOME3
set R8B1 [a_child r8b1 [string map [list @STUB@ $STUB @STUB2@ $STUB2] {
  set r NOPROC
  if {[llength [info commands ase::sim_register]]} {
    ase::sim_register r8b-a @STUB@
    ase::sim_register r8b-b @STUB2@
    set r [ase::sim_select r8b-b]
  }
  puts "Z_PICK=$r"
  puts "Z_INFORCE=[ase::sim_selected]"
  puts "Z_FILE=[file exists [file join $::USER_CONF_DIR ase_simulators]]"
  puts "Z_DONE=1"
  exit 0
}] {} $R8HOME3]
set R8B2 [a_child r8b2 $::A_REPORT {} $R8HOME3]
check {R8b registering reaches the disk on its own and picking one does not: a session that registers two simulators and picks the second, and saves nothing, is followed by a start that has BOTH of them and is running the FIRST -- the two halves of the user's ruling in one restart} \
  [list [a_zrc $R8B1] [a_zval $R8B1 Z_PICK] [a_zval $R8B1 Z_INFORCE] \
        [a_zval $R8B1 Z_FILE] [a_zval $R8B1 Z_DONE] \
        [a_zrc $R8B2] [a_zval $R8B2 Z_N] [a_zval $R8B2 Z_SEL] [a_zval $R8B2 Z_EXE] \
        [a_zval $R8B2 Z_DONE]] \
  [list 0 r8b-b r8b-b 1 1 0 2 r8b-a $STUB 1]

## R9: THE SAME DISCIPLINE AS D6, EXTENDED TO THE SECOND FILE. D6 scans
## ase.tcl only, and only the four registration sentences, so it cannot see a
## dialog that quietly writes its own copy of "the program on your PATH will
## start". Every fixed piece of the four sentences the door needs must occur
## exactly once in ase.tcl and never in ase_window.tcl -- and the four must be
## four DIFFERENT sentences, none of them the catch-all.
set R9KINDS [list removed_now_path removed_now_other in_force path_in_force]
set R9NAME zz9name
set R9PATH /zz9/path/to/ngspice
set R9EXTRA zz9extra
set R9S {}
foreach r9k $R9KINDS { lappend R9S [a_ans ase::sim_why $r9k $R9NAME $R9PATH $R9EXTRA] }
set R9CATCH [a_ans ase::sim_why zz-no-such-kind $R9NAME $R9PATH $R9EXTRA]
set R9DISTINCT 1
if {[llength [lsort -unique $R9S]] != 4} { set R9DISTINCT 0 }
foreach r9s $R9S { if {$r9s eq $R9CATCH} { set R9DISTINCT 0 } }
set R9SRCA [a_nocomment $ASETCL]
set R9SRCW [a_nocomment $ASEWIN]
set R9N 0 ; set R9ONE 1 ; set R9ZERO 1
foreach r9s $R9S {
  set chunks [list $r9s]
  foreach r9w [list $R9NAME $R9PATH $R9EXTRA] {
    set next {}
    foreach c $chunks {
      foreach piece [split [string map [list $r9w \x01] $c] \x01] { lappend next $piece }
    }
    set chunks $next
  }
  foreach c $chunks {
    set c [string trim $c]
    if {[string length $c] < 25} { continue }
    incr R9N
    if {[a_count $R9SRCA $c] != 1} { set R9ONE 0 }
    if {[a_count $R9SRCW $c] != 0} { set R9ZERO 0 }
  }
}
check {R9 STRUCTURAL the four sentences the dialog needs are four different sentences, each written in exactly one place, and none of them is written in the window file} \
  [list $R9DISTINCT [expr {$R9N >= 4}] $R9ONE $R9ZERO] [list 1 1 1 1]

## R10: THE SEAM. A dialog that must show the user the SAME sentence the CIW
## just got has two ways to get it: re-derive it, which is ruling D5-4's
## defect, or read back what was actually said. One recorder, one render site,
## and no `echo the mint` construct left anywhere for a caller to copy.
set R10SRC [a_nocomment $ASETCL]
set R10ECHO [a_count $R10SRC {ase::echo [ase::sim_why}]
a_reset
set ::r10m NOPROC
set R10SAID [a_echoed {set ::r10m [a_ans ase::sim_say missing zz10 /zz10/ngspice {} error]}]
set R10A [a_ans ase::sim_said]
a_ans ase::sim_said_clear
set R10B [a_ans ase::sim_said]
check {R10 every sentence about a simulator is said in one place and remembered there, so the dialog can show the very words the CIW got instead of composing its own} \
  [list $R10ECHO \
        [expr {$::r10m ne {NOPROC} && $::r10m eq $R10A}] \
        [llength $R10SAID] $R10B] \
  [list 0 1 1 {}]

## R11-R12: THE SAVED LIST IS REPLACED, NEVER EMPTIED FIRST.
##
## ase::sim_write_conf builds the new list BESIDE the real file and moves it
## into place. That shape carries two promises to the user and neither had a
## row anywhere -- measured, by reverting each half in turn and watching this
## file stay at 58 and the dialog file at 23:
##
##   R11  a save that CANNOT happen leaves the list you already had exactly
##        as it was. The old writer opened the real file for writing, which
##        TRUNCATES it before the first line is written, so a failure after
##        that point -- a full disk, a close reporting a buffered write --
##        left the user with an empty simulator list and, because the close
##        raised out of a proc that promises never to raise, no sentence
##        about it either.
##   R12  the permissions you put on your own saved list survive a save. A
##        move replaces the file, and with it whatever mode the user had set;
##        the old truncate-in-place kept it.
##
## R11 MAKES THE SAVE FAIL IN A WAY THAT WORKS FOR ROOT TOO -- the file the
## writer builds beside the real one is already a DIRECTORY, and no user can
## open a directory for writing. The row cannot go quietly vacuous if that
## temporary name ever changes: the write would then SUCCEED and the second
## term reds. Both rows call the writer with an explicit path, so neither
## goes anywhere near the developer's own saved list.
proc a_perms {path} {
  if {![file exists $path]} { return NOFILE }
  if {[catch {file attributes $path -permissions} m]} { return NOPERM }
  set v 0
  if {![scan $m {%o} v]} { return "NOSCAN-$m" }
  return [format %04o [expr {$v & 0777}]]
}

set W11DIR [file join $scratch wconf]
file mkdir $W11DIR
set W11  [file join $W11DIR ase_simulators]
set W11N $W11.new
a_reset
a_ans ase::sim_register keep11 $STUB
set R11W1 [a_ans ase::sim_write_conf $W11]
set R11BEFORE [a_slurp $W11]
a_ans ase::sim_register gone11 $STUB2
catch {file delete -force $W11N}
file mkdir $W11N
a_ans ase::sim_said_clear
set R11W2 [a_ans ase::sim_write_conf $W11]
set R11SAID [a_ans ase::sim_said]
catch {file delete -force $W11N}
set R11AFTER [a_slurp $W11]
check {R11 a save that cannot happen leaves the simulator list you already had exactly as it was -- it never empties the file first and then fails -- and you are told in plain English that what you just added will be gone when xschem closes} \
  [list $R11W1 [expr {[a_count $R11BEFORE {keep11}] >= 1}] \
        $R11W2 [expr {$R11AFTER eq $R11BEFORE}] \
        [a_count $R11AFTER {gone11}] \
        [expr {[string first {could not be saved} $R11SAID] >= 0}]] \
  [list 1 1 0 1 0 1]

set W12 [file join $W11DIR ase_simulators_perm]
a_reset
a_ans ase::sim_register perm12 $STUB
set R12W1 [a_ans ase::sim_write_conf $W12]
catch {file attributes $W12 -permissions 0600}
set R12M0 [a_perms $W12]
a_ans ase::sim_register perm12b $STUB2
set R12W2 [a_ans ase::sim_write_conf $W12]
set R12M1 [a_perms $W12]
set R12TXT [a_slurp $W12]
check {R12 saving the list again keeps whatever permissions you had put on your own copy of it, instead of quietly handing the file back to you with the default ones} \
  [list $R12W1 $R12M0 $R12W2 $R12M1 [expr {[a_count $R12TXT {perm12b}] >= 1}]] \
  [list 1 0600 1 0600 1]

## ===========================================================================
## R11b-R11e: ISSUE 1286 -- A SAVE THAT WENT SOMEWHERE ELSE MUST NOT REPORT
## SUCCESS.
## ===========================================================================
## R11 above proves an interrupted save does not empty the list you had. It
## says nothing about the save that SUCCEEDS INTO THE WRONG PLACE, which is
## worse: the writer returns 1, the dialog's Save line names a path it did not
## write, and there is no sentence anywhere. Measured on this writer before
## these rows:
##   the path is a DIRECTORY -> rc 1, ZERO reports, the new list lands at
##                              <dir>/<name>.new INSIDE the directory, where no
##                              reader ever looks
##   the path is a SYMLINK   -> rc 1, ZERO reports, the LINK is REPLACED by a
##                              regular file and the real file stays as it was
## Both come from `file rename -force`, which succeeds in both cases, so there
## is nothing to check afterwards and the guard has to be a PRECONDITION.
## Symlinking a shared list into a dotfiles repo is the obvious use of a file
## whose whole point is that it is a plain script you can keep and share.
##
## ⚠ THE RELATIVE-TARGET CORRECTION IS THE POINT OF R11c. Issue 1276's own
## recommended one-liner, `file normalize [file link $path]`, resolves a
## RELATIVE link target against the CURRENT WORKING DIRECTORY: for a link at
## <d>/sub/link -> real it answers <d>/real, not <d>/sub/real. R11c makes
## exactly that link and calls the writer FROM A DIFFERENT DIRECTORY, so a fix
## built on that one-liner writes the user's list into the cwd and reds both
## the "the real file has the new entry" term and the stray-file term beside
## it. Join against the LINK's own directory instead.
##
## ⚠ AND THE ORDER IS PART OF THE SUBJECT. A symlink to a DIRECTORY answers
## `file isdirectory` 1, so the chain has to be resolved BEFORE the directory
## guard; a DANGLING symlink answers exists=0 / isfile=0 / isdirectory=0 while
## `file link` still succeeds, so resolution has to precede the permission
## capture and the temp name too.

set W11BDIR [file join $scratch w11b_target]
file mkdir $W11BDIR
a_reset
a_ans ase::sim_register dir11b $STUB
a_ans ase::sim_said_clear
set R11BR [a_ans ase::sim_write_conf $W11BDIR]
set R11BSAID [a_ans ase::sim_said]
## ⚠ THE SENTENCE IS A TERM, NOT DECORATION. Without it a build that merely
## FAILED somewhere further down -- an open that could not open a directory,
## say -- would satisfy "returns 0" and "left nothing inside" while telling the
## user something that does not name the actual problem.
check {R11b a path that is an existing FOLDER is refused before anything is opened -- the save returns failure, puts nothing at all inside the folder, and says in plain English that it is a folder rather than reporting some error from further down} \
  [list $R11BR [expr {[a_count $R11BSAID {a folder, not a settings file}] >= 1}] \
        [llength [glob -nocomplain -directory $W11BDIR *]] \
        [expr {[file isdirectory $W11BDIR] ? 1 : 0}]] \
  [list 0 1 0 1]

set W11CDIR [file join $scratch w11c sub]
file mkdir $W11CDIR
set W11CREAL [file join $W11CDIR real_simulators]
set W11CLINK [file join $W11CDIR link_simulators]
catch {file delete -force $W11CLINK}
a_wr $W11CREAL "# the simulator list the user really keeps here\n" 0644
set R11CMK [catch {file link -symbolic $W11CLINK real_simulators}]
a_reset
a_ans ase::sim_register link11c $STUB
a_ans ase::sim_said_clear
## Saved FROM the link's PARENT's parent, so the wrong resolution has a
## different, visible answer to the right one.
set R11CCWD [pwd]
cd [file join $scratch w11c]
set W11CSTRAY [file join [pwd] real_simulators]
catch {file delete -force $W11CSTRAY}
set R11CR [a_ans ase::sim_write_conf $W11CLINK]
set R11CSTRAY [expr {[file exists $W11CSTRAY] ? 1 : 0}]
cd $R11CCWD
set R11CTYPE [expr {[catch {file type $W11CLINK} R11CT] ? {RAISED} : $R11CT}]
set R11CTXT [a_slurp $W11CREAL]
check {R11c saving THROUGH a symbolic link whose target is written the relative way writes the real file and leaves your link a link -- it does not replace the link with a regular file, and it does not resolve the relative target against whatever directory xschem happened to be started from} \
  [list $R11CMK $R11CR $R11CTYPE \
        [expr {[a_count $R11CTXT {link11c}] >= 1}] $R11CSTRAY] \
  [list 0 1 link 1 0]

## A TWO-HOP CHAIN, A DANGLING LINK, AND A CHAIN TOO DEEP TO BE ANYTHING BUT A
## LOOP. A dangling link is the ordinary shape of `ln -s ase_simulators
## ~/dotfiles/...` made before the file exists; it must WRITE THE TARGET, not
## replace the link. ⚠ `file link` REFUSES to create a dangling link (measured:
## `could not create new link ...: target "..." doesn't exist`), so that one is
## made with `ln -s`.
set W11D [file join $scratch w11d]
file mkdir $W11D
set W11DREAL [file join $W11D hopreal]
a_wr $W11DREAL "# two hops away\n" 0644
catch {file delete -force [file join $W11D hop1]}
catch {file delete -force [file join $W11D hop0]}
set R11DMK1 [catch {file link -symbolic [file join $W11D hop1] hopreal}]
set R11DMK2 [catch {file link -symbolic [file join $W11D hop0] hop1}]
a_reset
a_ans ase::sim_register hop11d $STUB
a_ans ase::sim_said_clear
## ⚠ SAVED FROM SOMEWHERE THAT IS NOT THE LINKS' OWN FOLDER, for the same
## reason as R11c and for one more: a build that resolves a relative target
## against the CWD writes the user's list to a file named after the LINK's
## target in whatever directory xschem was started from. Measured while
## sabotaging this very fix -- `hop1`, `dangreal` and `l1` appeared in the
## REPO ROOT. Doing it from the scratch tree keeps that debris out of the
## developer's working tree.
set R11DCWD [pwd]
cd $scratch
set R11DR1 [a_ans ase::sim_write_conf [file join $W11D hop0]]
set R11DT1 [expr {[catch {file type [file join $W11D hop0]} R11DTT1] ? {RAISED} : $R11DTT1}]
set R11DTXT1 [a_slurp $W11DREAL]

set W11DDANG [file join $W11D dangreal]
catch {file delete -force $W11DDANG}
catch {file delete -force [file join $W11D dang]}
set R11DMK3 [catch {exec ln -s dangreal [file join $W11D dang]}]
a_reset
a_ans ase::sim_register dang11d $STUB
a_ans ase::sim_said_clear
set R11DR2 [a_ans ase::sim_write_conf [file join $W11D dang]]
set R11DT2 [expr {[catch {file type [file join $W11D dang]} R11DTT2] ? {RAISED} : $R11DTT2}]
set R11DTXT2 [a_slurp $W11DDANG]

set W11DDEEP [file join $W11D deepreal]
a_wr $W11DDEEP "# twenty hops away\n" 0644
set R11DMK4 0
for {set a_i 19} {$a_i >= 0} {incr a_i -1} {
  catch {file delete -force [file join $W11D l$a_i]}
  set a_tgt [expr {$a_i == 19 ? {deepreal} : "l[expr {$a_i + 1}]"}]
  if {[catch {file link -symbolic [file join $W11D l$a_i] $a_tgt}]} { set R11DMK4 1 }
}
a_reset
a_ans ase::sim_register deep11d $STUB
a_ans ase::sim_said_clear
set R11DR3 [a_ans ase::sim_write_conf [file join $W11D l0]]
set R11DSAID3 [a_ans ase::sim_said]
cd $R11DCWD
set R11DTXT3 [a_slurp $W11DDEEP]
## Nothing named after a link TARGET may appear where the save was made from.
set R11DSTRAY 0
foreach a_n {hop1 hopreal dangreal l1 deepreal} {
  if {[file exists [file join $scratch $a_n]]} { incr R11DSTRAY }
}
check {R11d a two-hop chain and a link made before its file exists both resolve to the real file and stay links, while a chain more than sixteen deep is refused with a sentence and writes nothing at all} \
  [list $R11DMK1 $R11DMK2 $R11DMK3 $R11DMK4 \
        $R11DR1 $R11DT1 [expr {[a_count $R11DTXT1 {hop11d}] >= 1}] \
        $R11DR2 $R11DT2 [expr {[a_count $R11DTXT2 {dang11d}] >= 1}] \
        $R11DR3 [expr {[a_count $R11DSAID3 {more than 16}] >= 1}] \
        [a_count $R11DTXT3 {deep11d}] \
        [llength [glob -nocomplain -directory $W11D *.new]] $R11DSTRAY] \
  [list 0 0 0 0 1 link 1 1 link 1 0 1 0 0 0]

## R11e IS THE COUNTERWEIGHT, and it is green before the fix on purpose: a
## guard that refuses the two shapes above is worthless if it also refuses the
## ordinary one. Its second half pins E4's promise unchanged -- a path whose
## FOLDER does not exist is still refused with a sentence, and no folder is
## made behind the user's back -- so the fix cannot quietly grow a `file mkdir`
## that the sibling writer in op_param_lists.tcl has and this one never had.
set W11E [file join $W11DIR plain_new_list]
catch {file delete -force $W11E}
a_reset
a_ans ase::sim_register plain11e $STUB
a_ans ase::sim_said_clear
set R11ER [a_ans ase::sim_write_conf $W11E]
set R11ESAID [a_ans ase::sim_said]
set R11ETXT [a_slurp $W11E]
set R11ETYPE [expr {[catch {file type $W11E} R11ETT] ? {RAISED} : $R11ETT}]
set W11ENODIR [file join $scratch w11e_nodir]
catch {file delete -force $W11ENODIR}
a_ans ase::sim_said_clear
set R11ER2 [a_ans ase::sim_write_conf [file join $W11ENODIR deeper conf]]
set R11ESAID2 [a_ans ase::sim_said]
check {R11e an ordinary save into a folder that exists still works -- the file is a real file at the path that was named, with the entry in it -- and a path whose folder does not exist is still refused with a sentence instead of the folder being made behind your back} \
  [list $R11ER $R11ETYPE [expr {[a_count $R11ETXT {plain11e}] >= 1}] $R11ESAID \
        $R11ER2 [expr {[string length $R11ESAID2] > 0}] \
        [expr {[file exists $W11ENODIR] ? 1 : 0}]] \
  [list 1 file 1 {} 0 1 0]

## ---------------------------------------------------------------------------
## R11f-R11i: THE TILDE, THE BOUND, AND THE ARM NOTHING PROVED.
## Repair round, 2026-09-07 -- issues 1286 AND 1276, because this resolver and
## op_param_lists::_resolve_target are copies of each other and the hole is in
## both.
## ---------------------------------------------------------------------------
## ⚠ `file join` AND `file normalize` EXPAND A LEADING TILDE; THE KERNEL DOES
## NOT. A symlink whose stored target is literally `~/notes` is, to the
## operating system, a link into a folder NAMED `~` beside the link: readlink
## says `~/notes`, and with no such folder there the link reads as DANGLING.
## Measured in tclsh: [file join /a/b {~/x}] answers `~/x`, and `file normalize`
## then answers `/home/<you>/x`. So the resolver turned such a link into a path
## in the user's HOME and the writer OVERWROTE WHATEVER FILE WAS ALREADY THERE
## while reporting success -- issue 1276's own headline symptom (bytes
## somewhere else, rc still 1) arriving through issue 1276's own fix.
##
## THE REMEDY IS MEASURED, NOT INVENTED: put a `./` in front of the target
## before joining. [file normalize [file join /a/b ./~/x]] answers `/a/b/~/x`,
## kernel-identical, and the other four target shapes are unchanged --
## `sub/y` -> /a/b/sub/y, `/abs/z` -> /abs/z (absolute still wins),
## `../up.conf` -> /a/up.conf.
##
## R11f overrides HOME for the duration of the call, so the row neither depends
## on nor writes into the developer's real home folder.
set W11F [file join $scratch w11f]
file delete -force $W11F
file mkdir $W11F
## A folder literally named ~, which is what the kernel makes of `~/...` in a
## stored link target. ⚠ `file join` CANNOT BUILD THIS PATH -- it treats a bare
## ~ as absolute and throws the prefix away -- so it is spelled with a slash.
file mkdir $W11F/~
set W11FHOME [file join $scratch w11f_home]
file delete -force $W11FHOME
file mkdir $W11FHOME
set W11FBYST [file join $W11FHOME w11f_notes]
a_wr $W11FBYST "KEEP ME: an unrelated file that happens to share the name\n" 0644
set W11FLINK [file join $W11F link_list]
set R11FMK [catch {exec ln -s {~/w11f_notes} $W11FLINK}]
a_reset
a_ans ase::sim_register tilde11f $STUB
a_ans ase::sim_said_clear
set R11FHOME0 $::env(HOME)
set ::env(HOME) $W11FHOME
set R11FR [a_ans ase::sim_write_conf $W11FLINK]
set ::env(HOME) $R11FHOME0
set R11FTYPE [expr {[catch {file type $W11FLINK} R11FT] ? {RAISED} : $R11FT}]
set R11FBYST [a_slurp $W11FBYST]
check {R11f a link whose stored target starts with a tilde is followed the way the system follows it -- as an ordinary folder named ~ beside the link -- so the list lands there, and an unrelated file of the same name in your home folder is left exactly as it was} \
  [list $R11FMK $R11FR $R11FTYPE \
        [expr {[a_count [a_slurp $W11F/~/w11f_notes] {tilde11f}] >= 1}] \
        [expr {[a_count $R11FBYST {KEEP ME}] >= 1}] \
        [a_count $R11FBYST {tilde11f}] \
        [llength [glob -nocomplain -directory $W11F *.new]]] \
  [list 0 1 link 1 1 0 0]

## R11g -- AND IT MUST NOT RAISE. `file normalize` RAISES on a `~nosuchuser`
## no password entry matches (measured: `user "nosuchuser_xschem" doesn't
## exist`), and ase::sim_write_conf's own doc comment says it NEVER raises.
## Measured before this repair: the writer raised, so the caller got no return
## value and the user got no sentence.
set W11G [file join $scratch w11g]
file delete -force $W11G
file mkdir $W11G
set W11GLINK [file join $W11G link_list]
set R11GMK [catch {exec ln -s {~nosuchuser_xschem/list} $W11GLINK}]
a_reset
a_ans ase::sim_register tilde11g $STUB
a_ans ase::sim_said_clear
set R11GR [a_ans ase::sim_write_conf $W11GLINK]
set R11GSAID [a_ans ase::sim_said]
set R11GTYPE [expr {[catch {file type $W11GLINK} R11GT] ? {RAISED} : $R11GT}]
## ⚠ AND IT MUST BE THE RIGHT SENTENCE. Measured in the close-out round: with
## the `./` guard dropped but the catch kept, `file normalize` raises, the
## catch answers empty, ase::sim_conf_target_why calls empty a link loop, and
## this row's old "some sentence was said" term was SATISFIED BY THE WRONG
## SENTENCE -- the user told about "a chain of symbolic links more than 16
## deep" against a link that is one link long. The two terms below name the
## sentence instead of counting it: it has to talk about the place the write
## was actually refused at, and it must NOT be the link-loop sentence.
check {R11g a link pointing into the home folder of a user who does not exist is refused with a sentence that names the folder beside the link -- not one about a chain of symbolic links, which this is not -- and does NOT raise, which is what this writer promises it never does, and your link is still a link} \
  [list $R11GMK $R11GR \
        [expr {[a_count $R11GSAID {~nosuchuser_xschem}] >= 1}] \
        [a_count $R11GSAID {more than 16}] $R11GTYPE \
        [llength [glob -nocomplain -directory $W11G *.new]]] \
  [list 0 0 1 0 link 0]

## R11h -- THE BOUND AND THE SENTENCE MUST NAME THE SAME NUMBER. The refusal
## says "more than 16 deep". The resolver spends one pass per link and needs
## one further pass to see that the last thing is not a link, so a loop of
## exactly 16 passes refused a chain of exactly 16. Measured before this
## repair: 15 saved, 16 was refused as "more than 16".
proc a_mkchain {dir n leaf} {
  file delete -force $dir
  file mkdir $dir
  a_wr [file join $dir $leaf] "# the real list\n" 0644
  for {set i [expr {$n - 1}]} {$i >= 0} {incr i -1} {
    set t [expr {$i == $n - 1 ? $leaf : "c[expr {$i + 1}]"}]
    catch {file link -symbolic [file join $dir c$i] $t}
  }
  return [file join $dir c0]
}
set W11H16 [a_mkchain [file join $scratch w11h16] 16 realA]
a_reset
a_ans ase::sim_register bound16 $STUB
a_ans ase::sim_said_clear
set R11H16R [a_ans ase::sim_write_conf $W11H16]
set R11H16TXT [a_slurp [file join $scratch w11h16 realA]]
set W11H17 [a_mkchain [file join $scratch w11h17] 17 realB]
a_reset
a_ans ase::sim_register bound17 $STUB
a_ans ase::sim_said_clear
set R11H17R [a_ans ase::sim_write_conf $W11H17]
set R11H17SAID [a_ans ase::sim_said]
check {R11h a chain of exactly sixteen links still saves and only the seventeenth is refused -- the number the refusal names and the number the resolver allows are the same number} \
  [list $R11H16R [expr {[a_count $R11H16TXT {bound16}] >= 1}] \
        [expr {[file type $W11H16] eq {link}}] \
        $R11H17R [expr {[a_count $R11H17SAID {more than 16}] >= 1}] \
        [a_count [a_slurp [file join $scratch w11h17 realB]] {bound17}]] \
  [list 1 1 1 0 1 0]

## R11i -- THE ARM NOTHING PROVED. The empty-path qualifier on the link-loop
## answer was defended by no row at all: last round's sabotage D DELETED it and
## the suite stayed ALL PASS. ase::sim_conf_file answers empty when there is no
## USER_CONF_DIR, and no path is not a chain of symbolic links -- that case has
## to fall through to the writer's own reporting or the user is told about a
## loop that does not exist.
check {R11i asking why an EMPTY path could not be written answers nothing at all -- having no path is not the same as a chain of symbolic links -- while a real path that resolved to nothing is still named as a link chain} \
  [list [a_ans ase::sim_conf_target_why {} {}] \
        [a_ans ase::sim_conf_target_why [file join $scratch w11i nosuch] {}]] \
  [list {} conf_linkloop]

## ---------------------------------------------------------------------------
## R11j-R11m: THE TEMPORARY FILE IS PART OF THE TARGET (issue 1378), AND THE
## TILDE SHAPE THAT NEITHER DANGLES NOR RAISES.
## Close-out round, 2026-09-07 -- issues 1286 AND 1276 again, because
## ase::sim_write_conf and op_param_lists::write_conf are copies of each other
## and issue 1378's hole is in BOTH. Fixed in both in one change.
## ---------------------------------------------------------------------------
## ⚠ THE RESOLVER ABOVE GUARDS `$path`. NOTHING GUARDED `$path.new`. The temp
## name is deterministic, `open <tmp> w` FOLLOWS a symbolic link and
## `file rename` does NOT, so a stale `<conf>.new` left behind as a link meant:
## the bytes were written THROUGH the link into an unrelated file, and then the
## LINK ITSELF was moved onto the user's simulator list. Measured on this
## writer before the repair: rc 1, nothing said, the list is now a `link`, and
## the bystander lost its own content and gained the simulator list. (All four
## facts hold -- re-driven on the as-found writer in the close-out round -- but
## this comment used to attribute them to "R11j's RED line", and R11j's tuple
## carries neither a `said` term nor a term about the bystander's own text; its
## fifth term says only "not byte-identical". The measurements are real; the row
## is not where all of them come from.) It is the same family as the two holes above -- rc 1,
## zero reports, bytes somewhere the user never named -- one step further down.
##
## THE REMEDY, AND WHAT IT DOES ABOUT THE RACE. A leftover temp of a kind this
## writer could have left (a regular file, or a link) is REMOVED first, and the
## temp is then created with CREAT|EXCL, which POSIX requires to FAIL on an
## existing path including a symbolic link, dangling or not. Measured in tclsh
## 8.6.17 on this tree: `open <link> {WRONLY CREAT EXCL} 0666` raises `file
## already exists` over a link to a real file, over a DANGLING link and over a
## directory, and the link's target is left untouched; `open <path> w` over a
## dangling link CREATES the target. So the unlink/create window is still there
## and is NOT closed by ordering -- what closes it is that anything planted in
## it makes the create FAIL and the user is told, instead of the write being
## followed somewhere else.
##
## ⚠ AND THE REMOVAL MUST NEVER BE `file delete -force`. Rows R11 above and W1
## in tests/headless/test_op_param_store_1245.tcl make `<path>.new` a DIRECTORY
## on purpose, and a user's directory at that name is not this writer's to
## delete: `file delete -force` removes a directory tree, and `file delete`
## with no -force removes an EMPTY one (measured, both). R11l below is the
## fence: a NON-EMPTY directory at the temp name, with a file inside it that
## must still be there afterwards.
##
## ⚠ THE PERMISSIONS DID NOT MOVE. `open <p> {WRONLY CREAT EXCL} 0666` and
## `open <p> w` both land at 00644 under this shell's umask 0022 (measured), so
## the explicit mode is the one Tcl was already using and R12 is unaffected.

## R11j -- RED ON THE TREE AS FOUND. This is the row issue 1378 was filed for.
set W11J [file join $scratch w11j]
file delete -force $W11J
file mkdir $W11J
set W11JCONF [file join $W11J ase_simulators]
set W11JBYST [file join $W11J unrelated_notes]
a_wr $W11JCONF "# the simulator list the user has\n" 0644
a_wr $W11JBYST "KEEP ME: an unrelated file the user also keeps in this folder\n" 0644
set W11JBEFORE [a_slurp $W11JBYST]
## The temp name is deterministic, so nothing has to be guessed to arrange this.
set R11JMK [catch {exec ln -s unrelated_notes $W11JCONF.new}]
a_reset
a_ans ase::sim_register temp11j $STUB
a_ans ase::sim_said_clear
set R11JR [a_ans ase::sim_write_conf $W11JCONF]
set R11JTYPE [expr {[catch {file type $W11JCONF} R11JT] ? {RAISED} : $R11JT}]
set R11JAFTER [a_slurp $W11JBYST]
check {R11j a stale temporary file left behind as a symbolic link is not written through -- your simulator list stays a real file of its own instead of quietly becoming a link, and the unrelated file that link pointed at keeps its own content byte for byte} \
  [list $R11JMK $R11JR $R11JTYPE \
        [expr {[a_count [a_slurp $W11JCONF] {temp11j}] >= 1}] \
        [expr {$R11JAFTER eq $W11JBEFORE}] \
        [a_count $R11JAFTER {temp11j}] \
        [llength [glob -nocomplain -directory $W11J *.new]]] \
  [list 0 1 file 1 1 0 0]

## R11k IS THE COUNTERWEIGHT AND IT WAS GREEN ON THE TREE AS FOUND. A guard
## that refuses a stale temp is worthless if it also refuses the ordinary
## leftover this writer itself drops on a mid-save failure -- the user would
## then have a Save that can never succeed again and no way to clear it from
## inside xschem. Its sabotage is dropping the removal and keeping the
## exclusive create.
set W11K [file join $scratch w11k]
file delete -force $W11K
file mkdir $W11K
set W11KCONF [file join $W11K ase_simulators]
a_wr $W11KCONF "# the simulator list the user has\n" 0644
a_wr $W11KCONF.new "ZZ_STALE_TEMP left behind by a save that was interrupted\n" 0644
a_reset
a_ans ase::sim_register temp11k $STUB
a_ans ase::sim_said_clear
set R11KR [a_ans ase::sim_write_conf $W11KCONF]
set R11KSAID [a_ans ase::sim_said]
set R11KTXT [a_slurp $W11KCONF]
check {R11k an ordinary leftover temporary file from an earlier interrupted save is simply replaced -- the save still succeeds, says nothing, leaves no temporary behind and none of the stale text is in your list} \
  [list $R11KR [expr {[catch {file type $W11KCONF} R11KT] ? {RAISED} : $R11KT}] \
        [expr {[a_count $R11KTXT {temp11k}] >= 1}] \
        [a_count $R11KTXT {ZZ_STALE_TEMP}] \
        [llength [glob -nocomplain -directory $W11K *.new]] $R11KSAID] \
  [list 1 file 1 0 0 {}]

## R11l IS A FENCE AND IT WAS GREEN ON THE TREE AS FOUND. It forbids the
## obvious wrong shape of R11j's fix -- an unconditional `file delete -force`
## on the temp name -- from becoming a new hole of the very family this issue
## is about. R11 above uses an EMPTY directory, which a plain `file delete`
## also removes; this one has a file inside it that has to still be there.
set W11L [file join $scratch w11l]
file delete -force $W11L
file mkdir $W11L
set W11LCONF [file join $W11L ase_simulators]
a_wr $W11LCONF "# keep11l the simulator list the user has\n" 0644
set W11LBEFORE [a_slurp $W11LCONF]
file mkdir $W11LCONF.new
a_wr [file join $W11LCONF.new inside_the_folder] "DO NOT DELETE ME\n" 0644
a_reset
a_ans ase::sim_register temp11l $STUB
a_ans ase::sim_said_clear
set R11LR [a_ans ase::sim_write_conf $W11LCONF]
set R11LSAID [a_ans ase::sim_said]
check {R11l a folder sitting at the temporary name is never deleted to make room -- the save is refused with a sentence, the folder and the file inside it are still there, and the list you already had is untouched} \
  [list $R11LR [expr {[string first {could not be saved} $R11LSAID] >= 0}] \
        [expr {[catch {file type $W11LCONF.new} R11LT] ? {RAISED} : $R11LT}] \
        [a_count [a_slurp [file join $W11LCONF.new inside_the_folder]] {DO NOT DELETE ME}] \
        [expr {[a_slurp $W11LCONF] eq $W11LBEFORE}] \
        [a_count [a_slurp $W11LCONF] {temp11l}]] \
  [list 0 1 directory 1 1 0]

## R11m -- THE TILDE SHAPE NO ROW COVERED, AND IT IS THE WORST OF THE THREE.
## GREEN ON THE TREE AS FOUND: the `./` guard landed last round and this row
## covers a shape that guard was never measured against. R11f uses `~/x`, which
## DANGLES, and R11g uses `~nosuchuser/x`, which RAISES. Neither is the shape
## that goes quietly wrong: `~<a user who really exists>/x` neither dangles nor
## raises -- `file normalize` hands back that user's REAL home folder and the
## writer would write there. Measured in tclsh: [file normalize [file join /a/b
## {~root/x}]] -> /root/x, against /a/b/~root/x with the guard.
##
## `root` is used because it is the one account every one of these machines
## has and the one no test may write into: if the guard is ever dropped the row
## reds on the RETURN VALUE, because the save into /root is refused by the
## operating system, rather than by actually putting a file there.
set W11M [file join $scratch w11m]
file delete -force $W11M
file mkdir $W11M
## The folder the kernel would traverse, named literally. `file join` cannot
## build this -- it treats a leading ~ as absolute -- so it is spelled with a
## slash, the same way R11f spells its `~`.
file mkdir $W11M/~root
set W11MLINK [file join $W11M link_list]
set R11MMK [catch {exec ln -s {~root/list} $W11MLINK}]
a_reset
a_ans ase::sim_register tilde11m $STUB
a_ans ase::sim_said_clear
set R11MR [a_ans ase::sim_write_conf $W11MLINK]
set R11MTYPE [expr {[catch {file type $W11MLINK} R11MT] ? {RAISED} : $R11MT}]
check {R11m a link whose stored target names the home folder of a user who really does exist is still followed the way the system follows it -- into an ordinary folder named after that user beside the link -- and not into that user's real home folder} \
  [list $R11MMK $R11MR $R11MTYPE \
        [expr {[a_count [a_slurp $W11M/~root/list] {tilde11m}] >= 1}] \
        [expr {[file exists /root/list] ? 1 : 0}] \
        [llength [glob -nocomplain -directory $W11M *.new]]] \
  [list 0 1 link 1 0 0]

## ===========================================================================
## R13-R18: ISSUE 0938 -- A SIMULATOR THAT IS RUNNABLE MUST RUN.
## ===========================================================================
## The user keeps their PDK under a folder whose name has a dollar sign in it.
## They add their simulator the documented portable way, as
## $::PDK_ROOT/bin/ngspice. The list takes it, says nothing is wrong with it,
## and shows no problem against it. Then they press run and are refused with
## "the location ... mentions a setting this session does not know about",
## printed back at them against a path that mentions no setting -- and the
## program at that path runs perfectly from a shell.
##
## WHY EVERY ROW ABOVE IS BLIND TO IT. R7 asks whether the list and the run
## say the SAME sentence. They do. Both are wrong, together. All four of R7's
## fixtures are paths that were already broken, and NOTHING IN THIS FILE HAS
## EVER STARTED A SIMULATOR -- so nothing here could notice a green list
## sitting in front of a dead run. R13 starts it. Measured before these rows:
## register returned 1, the entry's ok flag was 1, the file was runnable, the
## list showed no problem, and the run died.
##
## THE MECHANISM, MEASURED, NOT RE-DERIVED HERE. Turning a location into a
## file name is not idempotent -- doing it twice to a name that came out of
## the first pass carrying a literal dollar sign fails. Registration does it
## once and stores the RESULT; the validator the run consults did it a second
## time to that stored result.

## THE FIXTURE, and the braces are load-bearing: this suite must not
## substitute its own fixture away before the code under test ever sees it.
set DROOT [file join $scratch root {p$q}]
set DBIN  [file join $DROOT bin ngdollar]
set DDECK [file join $scratch deck13.spice]
a_wr $DBIN  "#!/bin/sh\necho ZZ_DOLLAR_RAN \"\$@\"\nexit 0\n" 0755
a_wr $DDECK "* deck\n.end\n" 0644
set ::ZZ_DOLLAR_ROOT $DROOT
## The portable form the documentation tells the user to type.
set DPORT {$::ZZ_DOLLAR_ROOT/bin/ngdollar}

## ACTUALLY START THE PROGRAM. run_cmd's list ends in the redirection token
## exec understands, so `eval exec` is the mechanism -- and Tcl's own list
## quoting braces the element carrying the dollar sign, so eval cannot
## substitute the path away before exec sees it.
proc a_runs {deck} {
  if {![llength [info commands ase::backend::ngspice::run_cmd]]} { return NOPROC }
  if {[catch {ase::backend::ngspice::run_cmd {} $deck} cmd]} { return "REFUSED:$cmd" }
  if {[catch {eval exec $cmd} out]} { return "RANFAIL:$out" }
  return $out
}
proc a_ran {deck marker} {
  set o [a_runs $deck]
  if {$o eq {NOPROC}} { return NOPROC }
  return [expr {[string first $marker $o] >= 0 ? 1 : 0}]
}
## One named field of one entry, raw -- a_efields answers with a LIST, whose
## string form braces a value containing a dollar sign, which would fail a
## comparison against the path itself for a reason that has nothing to do
## with the subject.
proc a_efield1 {name key} {
  set e [a_entry $name]
  if {[string match NOENTRY-* $e] || $e eq {NOPROC} || [string match RAISED:* $e]} { return $e }
  if {[catch {dict get $e $key} v]} { return "NOKEY-$key" }
  return $v
}
## The fixture's own witness: if this ever answers 0 the rows below are
## measuring a broken stub, not the subject.
proc a_direct {bin marker} {
  if {[catch {exec $bin -b /dev/null} out]} { return "RANFAIL:$out" }
  return [expr {[string first $marker $out] >= 0 ? 1 : 0}]
}

a_reset
set R13RV [a_rv [a_regbad d13 $DPORT]]
check {R13 a simulator kept under a folder whose name has a dollar sign in it, added the portable way, shows no problem in the list AND really starts when you run it} \
  [list [a_direct $DBIN ZZ_DOLLAR_RAN] \
        $R13RV [a_efield1 d13 ok] [a_ans ase::sim_entry_why d13] \
        [a_sfield ngspice ok] [a_sfield ngspice resolved] \
        [a_ans ase::sim_exe ngspice] \
        [a_ran $DDECK ZZ_DOLLAR_RAN]] \
  [list 1 1 1 {} 1 $DBIN $DBIN 1]

## R14: WHAT IS RECORDED AT REGISTRATION IS THE ANSWER ABOUT THE SETTING, AND
## NOTHING ELSE. The facts about the disk are still worked out fresh on every
## call, which is what R6 demands: delete the program under this live entry
## and the list must say the file is gone, not blame a setting; put it back
## and the run must start again. And a location that really does name a
## setting this session does not know about must still be reported as exactly
## that, or the fix bought R13 by going silent.
set R14A [a_ans ase::sim_entry_why d13]
file delete -force $DBIN
set R14B [a_ans ase::sim_entry_why d13]
set R14OK [a_sfield ngspice ok]
a_wr $DBIN "#!/bin/sh\necho ZZ_DOLLAR_RAN \"\$@\"\nexit 0\n" 0755
set R14C [a_ans ase::sim_entry_why d13]
set R14RUN [a_ran $DDECK ZZ_DOLLAR_RAN]
set R14V [a_msg [a_regbad var14 $C8VARPATH]]
set R14VW [a_ans ase::sim_entry_why var14]
check {R14 the answer about the setting is worked out once and remembered, but what is on the disk is not: delete the program and the list says the file is gone, put it back and it runs again -- and a location that really does mention a setting nobody set still says so} \
  [list $R14A \
        [expr {[string first {no file at} $R14B] >= 0}] \
        [regexp -nocase {setting|does not know} $R14B] \
        $R14OK $R14C $R14RUN \
        [expr {$R14VW eq $R14V}] \
        [regexp -nocase {setting|does not know} $R14VW] \
        [expr {[string first {no file at} $R14VW] >= 0}]] \
  [list {} 1 0 0 {} 1 1 1 0]

## R15: AND IT HAS TO SURVIVE A RESTART. Two real child processes sharing one
## redirected HOME, because nothing in-process can prove what the next start
## does. The first adds the simulator the portable way and saves the list; the
## second is a FRESH xschem in a session where the setting is not set at all,
## reading that saved list back through the same startup path a user's would
## go through. Measured before these rows: the saved line carries the location
## already turned into a file name, the next start turned it into one a second
## time, and the entry came back dead in a session that never mentioned a
## setting.
set R15HOME [file join $scratch home_r15]
file delete -force $R15HOME
set R15WT {
  set ::ZZ_DOLLAR_ROOT {@DROOT@}
  set r NOPROC
  if {[llength [info commands ase::sim_register]]} {
    set r [ase::sim_register d15 {$::ZZ_DOLLAR_ROOT/bin/ngdollar}]
  }
  puts "Z_REG=$r"
  set w NOPROC
  if {[llength [info commands ase::sim_write_conf]]} { set w [ase::sim_write_conf] }
  puts "Z_WROTE=$w"
  puts "Z_DONE=1"
  exit 0
}
set R15RT {
  set ok NOPROC ; set ex NOPROC ; set eok NOPROC ; set ran NOPROC
  if {[llength [info commands ase::sim_status]]} {
    set s [ase::sim_status ngspice]
    catch {set ok [dict get $s ok]}
    catch {set ex [dict get $s exe]}
  }
  if {[llength [info commands ase::sim_list]]} {
    foreach e [ase::sim_list] { catch {set eok [dict get $e ok]} }
  }
  if {[llength [info commands ase::backend::ngspice::run_cmd]]} {
    set ran 0
    if {![catch {ase::backend::ngspice::run_cmd {} {@DECK@}} cmd]} {
      if {![catch {eval exec $cmd} out]} {
        if {[string first ZZ_DOLLAR_RAN $out] >= 0} { set ran 1 }
      }
    }
  }
  puts "Z_VAR=[info exists ::ZZ_DOLLAR_ROOT]"
  puts "Z_OK=$ok"
  puts "Z_EXE=$ex"
  puts "Z_EOK=$eok"
  puts "Z_RAN=$ran"
  puts "Z_DONE=1"
  exit 0
}
set R15C1 [a_child r15w [string map [list @DROOT@ $DROOT] $R15WT] {} $R15HOME]
set R15C2 [a_child r15r [string map [list @DECK@ $DDECK] $R15RT] {} $R15HOME]
check {R15 the simulator you added under a dollar-sign folder is still there, still shows no problem and still really starts the next time xschem is opened -- in a session where the setting it was typed with is not set at all} \
  [list [a_zrc $R15C1] [a_zval $R15C1 Z_REG] [a_zval $R15C1 Z_WROTE] \
        [a_zrc $R15C2] [a_zval $R15C2 Z_VAR] [a_zval $R15C2 Z_OK] \
        [a_zval $R15C2 Z_EXE] [a_zval $R15C2 Z_EOK] [a_zval $R15C2 Z_RAN] \
        [a_zval $R15C2 Z_DONE]] \
  [list 0 1 1 0 0 1 $DBIN 1 1 1]

## R16: ISSUE 0945, THE SAME PATH TYPED EXACTLY AS THE DISK SPELLS IT. The
## portable form is a convenience, not a requirement: a user who types the
## real absolute location of their program must get their program. Measured
## before these rows: refused at the door, with the same sentence about a
## setting, against a path that names no setting. The second half of the row
## is the normalisation the older arm already has -- a location with a
## redundant step in it is cleaned once, at registration, so the value stored,
## the value every message shows and the value handed to the run are one
## string.
a_reset
set R16RV [a_rv [a_regbad lit16 $DBIN]]
set R16OK [a_efield1 lit16 ok]
set R16WHY [a_ans ase::sim_entry_why lit16]
set R16S [a_sfield ngspice ok]
set R16RUN [a_ran $DDECK ZZ_DOLLAR_RAN]
a_rv [a_regbad norm16 [file join $DROOT . bin ngdollar]]
set R16P [a_efield1 norm16 path]
check {R16 typing the real location of your simulator, dollar sign and all, adds it, shows no problem against it and starts it -- and a location written with a redundant step in it is cleaned up once, when you add it} \
  [list $R16RV $R16OK $R16WHY $R16S $R16RUN $R16P] \
  [list 1 1 {} 1 1 $DBIN]

## R17: ISSUE 0941, AT THE REGISTRY. Taking away a simulator that a startup
## configuration file put there, while it is the one in use, has TWO true
## things to say: which simulator takes over, and that this one will be back
## next time. Both reach the CIW. Only the last was remembered, so the one
## line the Simulators window can show never told the user that the program
## which will actually run had just changed. Measured before this row: two
## sentences said, one remembered, and the remembered one is the wrong half.
a_reset
set ::ase::sim_origin rc
a_rv [a_regbad rc17 $STUB]
set ::ase::sim_origin session
a_rv [a_regbad mine17 $STUB2]
a_ans ase::sim_select rc17
a_ans ase::sim_said_clear
set R17SAID [a_echoed {a_ans ase::sim_unregister rc17}]
set R17M [a_ans ase::sim_said]
set R17O [a_ans ase::sim_why removed_now_other rc17 {} mine17]
set R17R [a_ans ase::sim_why rc_removed rc17 {}]
set R17IO [string first $R17O $R17M]
set R17IR [string first $R17R $R17M]
a_ans ase::sim_said_clear
set R17CLR [a_ans ase::sim_said]
check {R17 taking away a simulator a startup file put there, while it is the one in use, remembers BOTH things it just told the user -- which simulator takes over, said first, and that this one comes back next time} \
  [list [llength $R17SAID] [expr {$R17IO >= 0}] [expr {$R17IR >= 0}] \
        [expr {$R17IO >= 0 && $R17IR > $R17IO}] $R17CLR \
        [a_ans ase::sim_selected]] \
  [list 2 1 1 1 {} mine17]

## R18 STRUCTURAL, and it exists because NO BEHAVIOURAL ROW CAN SEE IT. R13
## goes green the moment the run works, by any means; this pins the invariant
## the defect was made of, so a later reader who adds a "quick" second look at
## the location back into the validator is stopped by a row rather than by a
## comment. Comments are stripped first, so the words cannot be satisfied by
## a paragraph about them.
##
## THE LAST TERM IS THE SECOND HALF OF THE SAME INVARIANT, AND IT IS HERE
## RATHER THAN IN A ROW OF ITS OWN BECAUSE NOTHING CAN REACH IT. The recorded
## answer is read with a "if there is no answer recorded, there is nothing to
## complain about" default, so an entry built somewhere other than where
## simulators are added can never start silently calling itself broken.
## Measured: there is exactly ONE place in src/ase.tcl that builds an entry
## and it always records the answer, so no gesture a user can make reaches
## that default today. Deleting it changes nothing a user could see -- until
## the day a second builder appears, when it is the difference between a list
## that works and a stack trace. A structural term keeps it; a behavioural
## row would have to invent a caller that does not exist.
set R18SRC  [a_nocomment $ASETCL]
set R18KIND [a_procbody $R18SRC ase::sim_entry_kind]
set R18REG  [a_procbody $R18SRC ase::sim_register]
check {R18 STRUCTURAL the location is turned into a file name exactly once, where the simulator is added, and the answer is recorded there -- the check the run consults never does it a second time, and it reads that answer defensively} \
  [list [expr {[string length $R18KIND] > 0}] \
        [a_count $R18KIND {expand_path}] \
        [expr {[string length $R18REG] > 0}] \
        [a_count $R18REG {expand_path}] \
        [expr {[string first {varok} $R18KIND] >= 0}] \
        [expr {[string first {dict exists} $R18KIND] >= 0}]] \
  [list 1 0 1 1 1 1]

## R19: THE OTHER THREE THINGS THAT CAN BE AT A DOLLAR-SIGN LOCATION, AND THE
## ONE THAT IS NOT A ROW ABOVE. R13-R16 all point the dollar-sign arm at a
## working program, so only ONE of its outcomes was ever measured. The arm's
## whole promise is narrow: a location it could not read a setting out of is
## given the benefit of the doubt about the SETTING, and about nothing else --
## what is actually sitting at that location is still looked at, and a folder
## is still refused as a folder and a file nobody marked runnable is still
## refused as that.
##
## MEASURED, AND THE REASON THIS ROW EXISTS. With the "look at what is really
## there" half taken out of that arm, every other row in this file stays green:
## pointing a simulator at a FOLDER under a dollar-sign PDK path then answers
## "added, nothing wrong with it", the Simulators list shows no problem against
## it, the CIW says nothing at all, and the run starts a folder. Three of the
## arm's four outcomes were untested; this row is the other two, and the run
## side of them.
##
## THE WITNESSES COME FIRST. If the fixture ever stops containing a dollar
## sign, or stops being a folder, or the location starts reading cleanly as a
## setting, this row would go green while measuring the ORDINARY arm that C2
## and C3 already cover -- so the row asserts it is really standing in front
## of the dollar-sign arm before it asserts anything about what that arm says.
proc a_expfails {p} {
  if {![llength [info commands ase::expand_path]]} { return NOPROC }
  return [expr {[catch {ase::expand_path $p}] ? 1 : 0}]
}
set R19DIR [file join $DROOT bin adir19]
set R19NX  [file join $DROOT bin noexec19.sh]
file mkdir $R19DIR
a_wr $R19NX "#!/bin/sh\nexit 0\n" 0644

a_reset
set R19D  [a_regbad dir19 $R19DIR]
set R19DS [a_sfield ngspice ok]
set R19DW [a_ans ase::sim_entry_why dir19]
set R19DV [a_efield1 dir19 varok]
set R19DK [a_efield1 dir19 ok]
a_reset
set R19N  [a_regbad nx19 $R19NX]
set R19NS [a_sfield ngspice ok]
set R19NW [a_ans ase::sim_entry_why nx19]
set R19NV [a_efield1 nx19 varok]
check {R19 a dollar sign in the location buys it the benefit of the doubt about a SETTING and nothing else: pointing a simulator at a folder under such a path is still refused as a folder, a file nobody marked runnable is still refused as that, and neither one is ever started} \
  [list [a_expfails $R19DIR] [file isdirectory $R19DIR] \
        [a_rv $R19D] $R19DK $R19DS \
        [a_says $R19D {folder|directory}] \
        [regexp -nocase {setting|does not know|doesn't know} [a_msg $R19D]] \
        [expr {$R19DW eq [a_msg $R19D]}] [a_plain $R19D dir19 $R19DIR] $R19DV \
        [a_expfails $R19NX] [file exists $R19NX] [file executable $R19NX] \
        [a_rv $R19N] [a_efield1 nx19 ok] $R19NS \
        [a_says $R19N {not marked|not executable|cannot run|can't run|not a program|permission|chmod}] \
        [regexp -nocase {setting|does not know|doesn't know} [a_msg $R19N]] \
        [expr {$R19NW eq [a_msg $R19N]}] [a_plain $R19N nx19 $R19NX] $R19NV] \
  [list 1 1  0 0 0  1 0 1 PLAIN 1 \
        1 1 0  0 0 0  1 0 1 PLAIN 1]


# ============================================================================
# L. WHAT TO CALL THE SIMULATOR ON A ONE-LINE SURFACE -- ISSUE 1370
# ============================================================================
# THE USER'S WORDS: "which version of ngspice did the most recent run use? It's
# very confusing.. in ASE-L, to know if a change has had desired effect. In the
# ASE-L, in status bar, Simulator: <name> should show the correct name. If user
# has designated (registered) a new instance of ngspice named ngspice-ver50, and
# the 'use this one:' field shows that, then the status bar in ASE-L should show
# that."
#
# MEASURED BEFORE THE FIX, on a live .ase4 window with ngspice-ver50 registered
# and selected: the bar read `Simulator: ngspice` with the entry in force, with
# the choice cleared, and with it re-selected. Three registry states, one
# byte-identical bar, because ase::ui::refresh_status rendered the STATE's
# backend word and never asked the registry anything.
#
# THIS SECTION OWNS THE NON-GUI HALF: ase::sim_label (what the bar is told to
# say), the run's own naming line, and the run log's `using` field. The pixels
# -- the bar really changing, and changing without a session update -- are rows
# S20-S23 of tests/headless/test_ase_simdlg_0937.tcl.
#
# ⚠ THE MARKER'S WORDING IS THE USER'S RULING (issue 1370, on their queue with
# --eyes: it is a pixel decision on a five-segment bar). So NOT ONE ROW BELOW
# RETYPES IT. L0 lifts it off one known-broken arm and pins it structurally --
# non-empty, written in ase.tcl exactly once, and never in the window file --
# and every other row asks only WHICH arms carry it. A re-worded marker changes
# nothing here; a marker that stops discriminating reds nine rows.

## The label of a backend with the PATH pointed at $dir, or at nothing at all.
## ⚠ auto_execok CACHES in ::auto_execs, so a PATH change that does not clear
## it measures the PATH from before. Measured while writing this: without the
## unset, the empty-PATH leg answered with the program the previous leg found.
proc a_label_pathed {dir backend} {
  set saved {}
  if {[info exists ::env(PATH)]} { set saved $::env(PATH) }
  set ::env(PATH) $dir
  catch {unset ::auto_execs}
  set r [a_ans ase::sim_label $backend]
  set ::env(PATH) $saved
  catch {unset ::auto_execs}
  return $r
}
proc a_plaintext {m args} {
  if {$m eq {} || $m eq {NOPROC} || [string match RAISED:* $m]} { return NOSENTENCE }
  set map {}
  foreach w $args { lappend map $w {} }
  set m [string map $map $m]
  foreach tok {auto_execok ase:: sim_ dict backend} {
    if {[string first $tok $m] >= 0} { return "JARGON-$tok" }
  }
  return PLAIN
}
proc a_hdrfield {txt key} {
  if {$txt eq {NOPROC} || [string match RAISED:* $txt]} { return $txt }
  set i 0
  foreach l [split $txt "\n"] {
    if {[regexp "^${key} *: ?(.*)\$" $l -> v]} { return [list $i $v] }
    incr i
  }
  return [list -1 NOFIELD]
}

## A directory holding a real program literally named `ngspice`, so the
## "nothing of your own registered" rows do not depend on whether this machine
## happens to have one installed.
set LPATHDIR [file join $scratch pathbin]
a_wr [file join $LPATHDIR ngspice] "#!/bin/sh\nexit 0\n" 0755

## THE MARKER, LIFTED OFF ONE ARM AND NEVER RETYPED.
a_reset
a_ans ase::sim_register ng-mark $MISSING
set L0FULL [a_ans ase::sim_label ngspice]
set LMARK ZZ-NO-MARKER
if {[string first ng-mark $L0FULL] == 0} {
  set LMARK [string range $L0FULL [string length ng-mark] end]
}
a_reset
set L0SRCA [a_nocomment $ASETCL]
set L0SRCW [a_nocomment $ASEWIN]
check {L0 the bar's "this one is not going to run" marker is real text, written in one place in the simulator file, and never written in the window file} \
  [list [expr {$LMARK ne {ZZ-NO-MARKER} && [string trim $LMARK] ne {}}] \
        [expr {[string length [string trim $LMARK]] >= 5}] \
        [a_count $L0SRCA $LMARK] [a_count $L0SRCW $LMARK]] \
  [list 1 1 1 0]

## L1 THE HEADLINE. The user registered a build of their own and picked it; the
## one-line surface must say THAT name. The second term is what the bar said
## before this item and is the whole of the complaint: the backend word.
a_reset
a_ans ase::sim_register ngspice-l1 $STUB
a_ans ase::sim_select ngspice-l1
check {L1 THE HEADLINE the one-line surface names the simulator the user registered and picked, not the kind of simulator it is} \
  [list [a_ans ase::sim_label ngspice] \
        [expr {[a_ans ase::sim_label ngspice] eq {ngspice} ? {STILL-THE-BACKEND-WORD} : {named}}] \
        [a_sfield ngspice entry]] \
  [list ngspice-l1 named ngspice-l1]

## L2 NOTHING OF YOUR OWN REGISTERED. The backend word is the right answer here
## -- there is no other name -- but ONLY when the system really has that program.
## ⚠ `ok` IS NOT THE DISCRIMINATOR: the PATH arm answers `ok 1` whether or not
## it found anything, so an empty PATH gives `ok 1` with `resolved` EMPTY. The
## second term is the one that reds when a caller trusts `ok` alone.
a_reset
set L2A [a_label_pathed $LPATHDIR ngspice]
set L2B [a_label_pathed {} ngspice]
set L2OK [a_sfield ngspice ok]
check {L2 with nothing of your own registered the surface says the kind of simulator plain when your system really has that program, and marks it when your system has nothing to start} \
  [list $L2A $L2B $L2OK] [list ngspice "ngspice$LMARK" 1]

## L3 REGISTERED, AND THE PROGRAM IS NOT THERE ANY MORE. All three broken
## arms: the file was deleted, the file lost its executable bit, the entry
## points at a folder. Each is NAMED -- the user needs the name to go and fix
## it -- and each is MARKED, because it is not going to run.
a_reset ; a_ans ase::sim_register ng-gone   $MISSING ; set L3A [a_ans ase::sim_label ngspice]
a_reset ; a_ans ase::sim_register ng-noexec $NOEXEC  ; set L3B [a_ans ase::sim_label ngspice]
a_reset ; a_ans ase::sim_register ng-folder $ADIR    ; set L3C [a_ans ase::sim_label ngspice]
check {L3 a simulator you registered whose program has gone, lost its executable bit, or turns out to be a folder is still named -- and marked as one that is not going to run} \
  [list $L3A $L3B $L3C] \
  [list "ng-gone$LMARK" "ng-noexec$LMARK" "ng-folder$LMARK"]

## L4 REGISTERED FOR A DIFFERENT KIND OF SIMULATOR. The resolver refuses it by
## name; the surface must not quietly show it as the thing that will run.
a_reset
a_ans ase::sim_register spec-only $STUB -backend spectre
a_ans ase::sim_select spec-only
check {L4 a simulator registered for a different kind of run is named and marked, never shown as the one that is about to start} \
  [list [a_ans ase::sim_label ngspice] [a_sfield ngspice ok]] \
  [list "spec-only$LMARK" 0]

## L5 THE GHOST, and it is the row the user's own rule is written about: "It
## must never silently print a name for a simulator that is not going to run --
## a false name is worse than the backend word." A choice naming an entry
## nobody registered is a name for something that does not exist, so the
## surface falls back to the kind of simulator and marks it. The typo is named
## on the Simulators dialog's own status line, which is where it can be fixed.
## Reached the way row D2 reaches it -- ::ase::sim_use directly, the one
## internal name this file depends on and a documented contract.
a_reset
a_ans ase::sim_register ng-real $STUB
set ::ase::sim_use zz-ghost-l5
set L5 [a_ans ase::sim_label ngspice]
a_reset
check {L5 a choice naming a simulator nobody registered never puts that name on the surface: it says the kind of simulator, and says it will not run} \
  [list $L5 [string first zz-ghost-l5 $L5]] \
  [list "ngspice$LMARK" -1]

## L6 THE KIND OF SIMULATOR THE SESSION ASKS FOR HAS NO MACHINERY HERE. An
## entry registered for no particular kind answers for ANY backend name, so the
## resolver says `ok 1` about a `spectre` session this program cannot run at
## all -- and about a session whose `simulator` key is missing entirely, which
## ase::run_deck refuses with "state has no simulator". The third term is the
## witness that makes the first two non-vacuous.
a_reset
a_ans ase::sim_register mysim-l6 $STUB
check {L6 a session asking for a kind of simulator this program has no machinery for is marked, however healthy the registered entry is} \
  [list [a_ans ase::sim_label spectre] [a_ans ase::sim_label {}] \
        [a_refused ase::backend_hook spectre run_cmd] [a_sfield spectre ok]] \
  [list "mysim-l6$LMARK" "mysim-l6$LMARK" REFUSED-ase 1]

## L7 IT NEVER RAISES. This feeds a label redrawn on every session update; a
## status bar is no place to discover a stack trace. Same discipline as
## ase::sim_named_path, and driven the same way -- the resolver is renamed
## aside and replaced with one that blows up.
set L7 NOPROC
if {[llength [info commands ::ase::sim_status]]} {
  rename ::ase::sim_status ::a_l7_saved
  proc ::ase::sim_status {backend} { return -code error "l7: the resolver blew up" }
  set L7 [a_ans ase::sim_label zz-l7-kind]
  rename ::ase::sim_status {}
  rename ::a_l7_saved ::ase::sim_status
}
check {L7 a surface that is redrawn on every keystroke never blows up in the user's face: a resolver that raises costs the label its detail, not the window} \
  [list $L7 [expr {[llength [info commands ::ase::sim_status]] ? 1 : 0}]] \
  [list zz-l7-kind 1]

## L8 STRUCTURAL. The run's own naming sentence is minted where every other
## sentence about a simulator is minted, is written there exactly once, is
## never written in the window file, and is not one of the sentences the
## dialog already uses. Same shape as R9, extended to the kind 1370 adds.
set L8NAME zz8name
set L8PATH /zz8/path/to/ngspice
set L8S [a_ans ase::sim_why run_using $L8NAME $L8PATH {}]
set L8CATCH [a_ans ase::sim_why zz-no-such-kind $L8NAME $L8PATH {}]
set L8N 0 ; set L8ONE 1 ; set L8ZERO 1
set L8CHUNKS [list $L8S]
foreach l8w [list $L8NAME $L8PATH] {
  set next {}
  foreach c $L8CHUNKS {
    foreach piece [split [string map [list $l8w \x01] $c] \x01] { lappend next $piece }
  }
  set L8CHUNKS $next
}
foreach c $L8CHUNKS {
  set c [string trim $c]
  if {[string length $c] < 25} { continue }
  incr L8N
  if {[a_count $L0SRCA $c] != 1} { set L8ONE 0 }
  if {[a_count $L0SRCW $c] != 0} { set L8ZERO 0 }
}
check {L8 STRUCTURAL the sentence a run says about which simulator it is starting is written once, in the same place as every other sentence about a simulator, and names BOTH the name the user gave it and the program that is running} \
  [list [expr {$L8S ne $L8CATCH}] [expr {$L8N >= 1}] $L8ONE $L8ZERO \
        [expr {[string first $L8NAME $L8S] >= 0}] \
        [expr {[string first $L8PATH $L8S] >= 0}] \
        [a_plaintext $L8S $L8NAME $L8PATH]] \
  [list 1 1 1 1 1 1 PLAIN]

## L9 THE RUN SAYS WHICH ONE IT IS STARTING, ONCE -- and says NOTHING when the
## user has registered nothing, because then there is no name to say and
## `path_in_force` is the sentence for that state. The control half is the
## load-bearing one: a line on every run of an ordinary installation would be
## noise, and this is the term that reds for it.
a_reset
a_ans ase::sim_register ng-l9 $STUB
set ::l9rv NOPROC
set L9SAID [a_echoed {set ::l9rv [a_ans ase::run_using_report [dict create simulator ngspice]]}]
set L9MINT [a_ans ase::sim_why run_using ng-l9 [a_sfield ngspice exe] {}]
a_reset
set ::l9brv NOPROC
set L9BSAID [a_echoed {set ::l9brv [a_ans ase::run_using_report [dict create simulator ngspice]]}]
## ...AND IT IS REALLY WIRED INTO THE RUN. The last two terms are the ones the
## rest of this row cannot reach: nothing here starts a run, so a reporter that
## is perfect and unreferenced would satisfy every term above it. The call must
## exist exactly once, and it must be the CAUGHT one inside ase::run_deck's
## registry gate -- everything it says is advisory, and a defect in it must
## never stop a run (ase::op_tier_report's own reason, and its neighbour).
## ⚠ SHAPE, NOT LITERAL TEXT (1370's adversary). This term used to pin the call
## site as the exact string `catch {set using [ase::run_using_report $state]}`,
## so renaming the local variable or reflowing the catch across two lines --
## neither of which changes one thing the user sees -- red the row. It now
## matches the SHAPE: a catch, around a set of some variable, from this
## reporter, on some variable. Everything the row is actually about (the call
## exists, exactly once, and it is CAUGHT) is still pinned; delete the catch
## and it reds.
set L9WIRED [a_count $L0SRCA {ase::run_using_report}]
set L9CALL  [regexp -all {catch\s*\{\s*set\s+\w+\s+\[ase::run_using_report\s+\$\w+\]\s*\}} $L0SRCA]
check {L9 a run started with a simulator of your own says which one, once, in the words the mint owns -- and a run on an ordinary installation with nothing registered says nothing at all} \
  [list $::l9rv [llength $L9SAID] [lindex [lindex $L9SAID 0] 0] \
        [expr {[lindex [lindex $L9SAID 0] 1] eq $L9MINT}] \
        $::l9brv [llength $L9BSAID] $L9WIRED $L9CALL] \
  [list ng-l9 1 note 1 {} 0 2 1]

## L10 AND THE RUN LOG CARRIES IT TOO, AS A FIELD BESIDE THE OTHERS. It is
## ADDED, never re-pointed: `simulator :` is the KIND of simulator and row E1e
## of tests/headless/test_ase_core.tcl asserts the literal `ngspice` there,
## under the developer's own HOME -- re-pointing it would make a shipped
## suite's expectation depend on whose simulator list is live. Empty writes
## NOTHING, the `casenote` field's discipline, so an ordinary run's log is
## byte-identical to the framing issue 0618 committed.
set L10META [dict create cell c10 simulator ngspice using ng-l10 \
                  cmd {/x/ngspice -b /d/c10.spice 2>@1} dir /d deck /d/c10.spice started 0]
set L10A [a_ans ase::run_log_header $L10META]
set L10B [a_ans ase::run_log_header [dict remove $L10META using]]
## ...AND THE RUN REALLY PUTS IT IN THE RECORD. Same gap as L9's last two
## terms: run_log_header renders whatever it is handed, so a header that is
## perfect and a run record that never carries the field would satisfy every
## term above. The name in the record is the name the run SAID -- one resolve,
## so the log and the sentence cannot be answers about two different instants.
## Shape, not literal text, for L9's reason: the field's NAME is what a reader
## of the log sees, the local variable's name is not.
## ⚠ THE LINE COUNT MOVED 5 -> 6 IN STAGE 2e (issue 1404), AND ONLY THAT TERM.
## ase::run_log_header gained a `stop      :` field carrying what a Stop of this
## run would cost. It is APPENDED BELOW `deck` rather than inserted among the
## identifying fields, so the index of `command` -- the fifth term -- is
## unchanged at 3. Placed above `command` it moved that term too, which is
## exactly why it is where it is.
set L10WIRED [regexp -all {\yusing\s+\$\w+} $L0SRCA]
check {L10 the run log names the simulator you picked on a line of its own, right under the line that says what kind it is -- and a run with nothing of yours in force writes that line not at all} \
  [list [lindex [a_hdrfield $L10A simulator] 1] \
        [a_hdrfield $L10A using] \
        [a_hdrfield $L10B using] \
        [llength [split [string trimright $L10B "\n"] "\n"]] \
        [lindex [a_hdrfield $L10A command] 0] $L10WIRED] \
  [list ngspice [list 2 ng-l10] [list -1 NOFIELD] 6 3 1]

## L11 THE TWO LINES THAT USED TO CONTRADICT EACH OTHER. The user's own run log
## carried `simulator : ngspice` with `command : .../build-ver_50/src/ngspice`
## one line under it, and nothing anywhere joined them. Now the name that
## joins them is between them, and it is the name the run itself said out loud.
a_reset
a_ans ase::sim_register ng-l11 $STUB
set L11CMD [a_runcmd $DECK]
set L11EXE [a_sfield ngspice exe]
set ::l11rv NOPROC
a_echoed {set ::l11rv [a_ans ase::run_using_report [dict create simulator ngspice]]}
set L11HDR [a_ans ase::run_log_header [dict create cell c11 simulator ngspice \
                 using $::l11rv cmd $L11CMD dir /d deck $DECK started 0]]
a_reset
check {L11 the run log's three lines finally agree: the kind of simulator, the name you gave the one you picked, and the program that was actually started} \
  [list [lindex $L11CMD 0] $::l11rv \
        [lindex [a_hdrfield $L11HDR simulator] 1] \
        [lindex [a_hdrfield $L11HDR using] 1] \
        [expr {[string first $L11EXE [lindex [a_hdrfield $L11HDR command] 1]] >= 0}]] \
  [list $L11EXE ng-l11 ngspice ng-l11 1]

## L12 AND THE `stop` FIELD SAYS WHAT STOPPING **THIS** RUN WOULD COST (1473).
## Stage 2e put one sentence in every header; Stage 6f then made it false for
## exactly the runs it matters most for -- a transient over ase::ckpt_floor is
## rendered with the checkpoint loop, and a Stop keeps everything up to its last
## checkpoint. The field now renders the run record's own `ckpt` plan, resolved
## ONCE in ase::run_deck for L10's reason, so the log and the CIW note cannot be
## answers about two different states.
## ⚠ THE LINE DOES NOT MOVE, AND TWO TERMS SAY SO. A record with no `ckpt` is
## every pre-1473 caller and every un-checkpointed run: same sentence, same
## index, same line count -- which is what leaves L10's own `command` index at 3
## and its 6-line header where they are.
set L12PLAN {{30 0 tran {n 4 step 160000 points 800000 vector time}}}
set L12A [a_ans ase::run_log_header [dict replace $L10META ckpt $L12PLAN]]
set L12B [a_ans ase::run_log_header $L10META]
set L12WIRED [regexp -all {\yckpt\s+\$\w+} $L0SRCA]
check {L12 the run log says what stopping THIS run would cost -- a run that checkpoints is told what it keeps, an ordinary one that it keeps nothing, and the line moves for neither} \
  [list [a_hdrfield $L12A stop] [a_hdrfield $L12B stop] \
        [lindex [a_hdrfield $L12A command] 0] \
        [llength [split [string trimright $L12A "\n"] "\n"]] \
        [llength [split [string trimright $L12B "\n"] "\n"]] $L12WIRED] \
  [list [list 6 {Stopping this run loses at most its last 20 %, and what is kept is marked partial — ngspice keeps every point up to this run's last checkpoint.}] \
        [list 6 {Stopping this run discards it — ngspice in batch mode writes nothing on a stop.}] \
        3 7 7 1]

## ============================================================================
## L12-L15 -- 1370'S REPAIR, AFTER ITS ADVERSARIES. Four defects the first
## landing did not cover: a latent FALSE NAME the three-term test could not
## see, a marker printed with NO NAME in front of it, a bar that went STALE on
## the registry's other door, and a run that said it was STARTING and was then
## refused. Every one of them is the same rule -- the segment must never name a
## simulator that is not going to run -- reached from a direction the first
## nine rows did not look in.
## ============================================================================

## L12 A SECOND KIND OF SIMULATOR, WITH A BINARY OF ITS OWN, AND THE FOURTH
## TERM. `ok`, `resolved` and `known` ALL answer yes about a GENERIC entry
## (`-backend {}`, which is exactly how this user's own ngspice-ver50 is
## registered) asked about a backend whose `run_cmd` hardcodes its own program
## and consults no registry -- the shape ase::run_composes_registry exists to
## detect, and the shape test_ase_core's E2 backend already has. The run starts
## THAT program; the entry names another; so the entry's name on the bar is a
## false name. The last four terms are the witnesses that make the first
## non-vacuous: they show the three original terms all saying yes.
a_reset
set L12PRE [expr {[lsearch -exact [a_ans ase::backend_names] zzl12] >= 0 ? 1 : 0}]
a_ans ase::register_backend zzl12 [dict create render_deck zz_l12_hook \
        run_cmd zz_l12_hook log_file zz_l12_hook result_probe zz_l12_hook \
        raw_file zz_l12_hook]
a_ans ase::sim_register gen-l12 $STUB
set L12      [a_ans ase::sim_label zzl12]
set L12OK    [a_sfield zzl12 ok]
set L12RES   [expr {[string trim [a_sfield zzl12 resolved]] ne {} ? 1 : 0}]
set L12KNOWN [expr {[lsearch -exact [a_ans ase::backend_names] zzl12] >= 0 ? 1 : 0}]
set L12COMP  [a_ans ase::run_composes_registry zzl12]
catch {dict unset ::ase::backends zzl12}
set L12POST [expr {[lsearch -exact [a_ans ase::backend_names] zzl12] >= 0 ? 1 : 0}]
a_reset
check {L12 an entry registered for no particular kind, asked about a kind of\
 simulator that starts a program of its own and reads no list, is marked --\
 the entry names one program and the run would start another} \
  [list $L12 $L12PRE $L12OK $L12RES $L12KNOWN $L12COMP $L12POST] \
  [list "gen-l12$LMARK" 0 1 1 1 0 0]

## L13 THERE IS NOTHING TO NAME AT ALL. A state whose `simulator` key is
## missing, on an installation with nothing registered: `entry` is empty, the
## backend word it falls back to is empty too, and the bar used to render the
## marker with a blank in front of it and a DOUBLE SPACE where the name should
## be. That is byte for byte the shape row Z8 of
## tests/headless/test_ase_optier_0963.tcl exists to forbid of a sentence, and
## the bar owes the user the same. The second term is the one that reds for it.
a_reset
set L13 [a_ans ase::sim_label {}]
set L13NAME [string trim [string map [list $LMARK {}] $L13]]
check {L13 with nothing registered and no kind of simulator named either, the\
 surface still names the absence rather than printing a marker with a blank\
 and a double space in front of it} \
  [list [expr {$L13NAME ne {} ? 1 : 0}] [string first {  } $L13] \
        [expr {[string first $LMARK $L13] >= 0 ? 1 : 0}] $L13NAME] \
  [list 1 -1 1 {(none)}]

## L14 THE REGISTRY'S OTHER DOOR. 1370 hung the bar's refresh off
## ase::ui::simdlg_fill, which every gesture of the Simulators DIALOG funnels
## through -- and nothing else. `ase::sim_register <name> <path>` followed by
## `ase::sim_select <name>` typed into the Command window is the pre-0937 path
## and is how this user's own ngspice-ver50 entry was first created; measured
## live by this item's adversary, it left an open bar naming the OLD entry
## while ase::sim_label already answered the new one -- a name on the bar for a
## simulator that would not run, healed only by the run it was meant to
## predict. So the four mutators fire a seam of their own.
##
## ⚠ AND A BROKEN HOOK NEVER COSTS THE USER THE GESTURE. These mutators are
## called once per line of ~/.xschem/ase_simulators at startup; a GUI hook that
## raises must not cost a user their simulator list. Same discipline, and the
## same `catch {uplevel #0 ...}`, as ase::session_notify_fire.
a_reset
set L14SAVED {}
catch {set L14SAVED $::ase::sim_notify}
set ::l14n 0
set ::ase::sim_notify {incr ::l14n}
a_ans ase::sim_register ng-l14  $STUB  ; set L14A $::l14n
a_ans ase::sim_register ng-l14b $STUB  ; set L14B $::l14n
a_ans ase::sim_select   ng-l14b        ; set L14C $::l14n
a_ans ase::sim_select   {}             ; set L14D $::l14n
a_ans ase::sim_unregister ng-l14b      ; set L14E $::l14n
a_ans ase::sim_clear                   ; set L14F $::l14n
set ::ase::sim_notify {error {l14: the hook blew up}}
set L14RV  [a_ans ase::sim_register ng-l14c $STUB]
set L14SEL [a_ans ase::sim_select ng-l14c]
set ::ase::sim_notify $L14SAVED
a_reset
## ...AND IT IS REALLY POINTED AT THE BAR. Structural, for L9's reason: nothing
## here opens a window, so a seam that is perfect and unsubscribed would
## satisfy every term above it. The pixels are row S32 of
## tests/headless/test_ase_simdlg_0937.tcl.
set L14W    [a_count $L0SRCW {set ::ase::sim_notify ase::ui::refresh_status_all}]
set L14WALL [a_count $L0SRCW {proc ase::ui::refresh_status_all}]
check {L14 a simulator registered or picked from the Command window -- the\
 registry's other door, and the one this user's own entry came through --\
 tells every open window's bar, and a broken listener never costs the user the\
 registration} \
  [list $L14A $L14B $L14C $L14D $L14E $L14F $L14RV $L14SEL $L14W $L14WALL] \
  [list 1 2 3 4 5 6 1 ng-l14c 1 1]

## L15 A RUN THAT IS REFUSED NEVER SAYS IT IS STARTING. 1370 put the say beside
## ase::run_precheck at the TOP of ase::run_deck -- eleven lines above
## ase::preflight_gate and above the `open $netlistfile`. Measured by this
## item's adversary: a pre-flight refusal and a missing netlist BOTH said "This
## run is starting the simulator you named <name>, and the program it is
## running is <path>" and were then refused with "Nothing was generated: no
## deck, no raw, no log." The one channel the user reads to answer "which
## version did the most recent run use?" was claiming starts for runs that
## never started.
##
## HOW THIS DRIVES IT: ase::preflight_gate is replaced by one that refuses, so
## the refusal is deterministic and needs no fixture that can be repaired away.
## The THIRD term is the control that makes the silence mean something -- the
## same state, the same registry, the reporter called directly, DOES say it. A
## reporter that had simply been deleted would satisfy the first two terms and
## reds this one.
a_reset
a_ans ase::sim_register ng-l15 $STUB
set L15NL [file join $scratch l15.spice]
a_wr $L15NL "* l15\n.end\n" 0644
proc a_l15_refused {nl} {
  set ::a_l15_rc NOPROC
  if {![llength [info commands ::ase::preflight_gate]]} { return }
  rename ::ase::preflight_gate ::a_l15_saved_pfg
  proc ::ase::preflight_gate {state netlist_text} {
    return -code error "ase: l15 refuses this run"
  }
  set ::a_l15_rc [catch {ase::run_deck [dict create simulator ngspice] $nl}]
  rename ::ase::preflight_gate {}
  rename ::a_l15_saved_pfg ::ase::preflight_gate
}
set L15SAID [a_echoed [list a_l15_refused $L15NL]]
set L15STARTS 0
foreach p $L15SAID {
  if {[string first {starting the simulator} [lindex $p 1]] >= 0} { incr L15STARTS }
}
set ::l15d {}
set L15DSAID [a_echoed {set ::l15d [a_ans ase::run_using_report [dict create simulator ngspice]]}]
set L15DSTARTS 0
foreach p $L15DSAID {
  if {[string first {starting the simulator} [lindex $p 1]] >= 0} { incr L15DSTARTS }
}
## ...AND STRUCTURALLY, THE CALL IS BELOW BOTH GATES IT HAS TO BE BELOW: the
## pre-flight (the last thing that can REFUSE) and the line that composes the
## argument list `execute` is handed (so the sentence, the run log's `using :`
## field and its `command :` field are one instant and one resolve).
set L15PFG  [a_lines_matching $ASETCL {ase::preflight_gate $state}]
set L15CALL [a_lines_matching $ASETCL {ase::run_using_report $state}]
set L15CMD  [a_lines_matching $ASETCL {$run_cmd $state $deckpath}]
set L15ORD 0
if {[llength $L15PFG] == 1 && [llength $L15CALL] == 1 && [llength $L15CMD] == 1} {
  set L15ORD [expr {([lindex $L15CALL 0] > [lindex $L15PFG 0]) &&
                    ([lindex $L15CALL 0] > [lindex $L15CMD 0])}]
}
a_reset
check {L15 a run the pre-flight refuses never told the user it was starting a\
 simulator -- the say sits below the last gate that can refuse and below the\
 line that composes the command, so the channel a user reads to find out which\
 build ran never carries a start that did not happen} \
  [list $::a_l15_rc $L15STARTS $L15DSTARTS $::l15d $L15ORD \
        [llength $L15PFG] [llength $L15CALL] [llength $L15CMD]] \
  [list 1 0 1 ng-l15 1 1 1 1]

# ============================================================================
# S. THE REGISTRY IS ENVIRONMENT; THE CHOICE IS STATE -- THE 2026-09-08 RULING
# ============================================================================
# The user, verbatim:
#
#   "Yes, registering a simulator (so that future Xschems see the 'new'
#    simulator instance) is something that can make it to disk right away as
#    soon as done. But, registering a simulator is not part of the simulator
#    state that accompanies a test-bench cell in the library manager.
#
#    *Whether* the 'new' simulator just registered gets assigned as 'the one to
#    use' is an option that is part of the ASE-L state. If changed, that results
#    in dirtiness. User must explicitly save and, if user initiates an Xschem
#    shutdown, then she must get a warning and a prompt to save."
#
# WHAT WAS TRUE THE MORNING THAT WAS WRITTEN, measured on this tree: the ONLY
# caller of the saver was the Simulators dialog, which called it after every
# gesture of its own. So a registration typed into the Command window -- the
# door this user's own `ngspice-ver50` entry came through, recorded at
# src/ase_window.tcl:288 -- worked all session and was gone at the next start,
# while src/xschem.tcl's help text promised the opposite in writing. And the
# saved list carried `ase::sim_select <what is in force>`, so the one thing that
# was NOT supposed to reach disk was the one thing that always did.
#
# The split: `ase::sim_default` is the installation default and is what the
# saved list records; `ase::sim_use` is what is in force right now and is a
# cache; the `sim_entry` state key is the store of record for a session's own
# choice. One encoding, {} / none / {name <entry>}, and one decoder.
#
# R8/R8b above measure the restart. These rows measure the parts.

## S1: THE ENCODING. Three values and a forgiving reader, because a saved state
## is a text file a user may edit and the natural thing to type is a bare name.
## `{name none}` is the spelling that keeps an entry genuinely called `none`
## reachable, which is why the entry form is two words and no name is reserved.
check {S1 the three values a choice can have decode to three different things, a bare name is read as an entry so a hand-edited file works, and an entry actually called "none" is still reachable} \
  [list [a_ans ase::sim_choice_decode {}] \
        [a_ans ase::sim_choice_decode none] \
        [a_ans ase::sim_choice_decode zz-build] \
        [a_ans ase::sim_choice_decode {name zz-build}] \
        [a_ans ase::sim_choice_decode {name none}] \
        [a_ans ase::sim_choice_decode {name {}}] \
        [a_ans ase::sim_choice_decode {a b c}] \
        [a_ans ase::sim_choice_decode "\{unbalanced"]] \
  [list {unset {}} {path {}} {entry zz-build} {entry zz-build} {entry none} \
        {unset {}} {unset {}} {unset {}}]

## S2: AND IT ROUND-TRIPS. Whatever the encoder writes, the decoder reads back
## as the same kind and the same name -- including the name that collides with
## the PATH spelling.
set S2OK 1
foreach s2pair {{path {}} {entry zz-build} {entry none} {unset {}}} {
  set s2enc [a_ans ase::sim_choice_encode [lindex $s2pair 0] [lindex $s2pair 1]]
  if {[a_ans ase::sim_choice_decode $s2enc] ne $s2pair} { set S2OK 0 }
}
check {S2 every value the encoder can write reads back as itself, so the two stores that share this encoding can never disagree about what a stored choice meant} \
  [list $S2OK [a_ans ase::sim_choice_encode path] \
        [a_ans ase::sim_choice_encode entry zz-build] \
        [a_ans ase::sim_choice_encode entry none] \
        [a_ans ase::sim_choice_encode entry {}] \
        [a_ans ase::sim_choice_encode unset]] \
  [list 1 none {name zz-build} {name none} {} {}]

## S3: THE STATE KEY, AND THE 104 COMMITTED .state FILES IT MUST NOT DISTURB.
## `sim_entry` is a schema key, defaults to `{}` and is in ase::omit_if_empty,
## which together are what keeps the five load->save byte-identity rows green
## (F3 in test_ase_final, G3 in test_ase_final_gf180, R4 in test_ase_core, V4 in
## test_ase_view, R2 in test_ase_persist). A default that was anything else, or
## a key left out of that list, writes a `sim_entry` line into every one of them.
set S3D [a_ans ase::state_default]
set S3SER {}
set S3SERSET {}
if {$S3D ne {NOPROC} && ![string match RAISED:* $S3D]} {
  set S3SER [a_ans ase::state_serialize $S3D]
  set S3SERSET [a_ans ase::state_serialize [dict replace $S3D sim_entry none]]
}
check {S3 the new state key is in the schema, defaults to empty, is left OUT of a serialized state when it is empty and IS written when it is not -- which is the whole of why the 104 committed state files still round-trip byte for byte} \
  [list [expr {[lsearch -exact $::ase::schema_keys sim_entry] >= 0}] \
        [expr {[lsearch -exact $::ase::omit_if_empty sim_entry] >= 0}] \
        [a_ans ase::state_get $S3D sim_entry <absent>] \
        [expr {[string first sim_entry $S3SER] >= 0}] \
        [expr {[string first {sim_entry none} $S3SERSET] >= 0}]] \
  [list 1 1 {} 0 1]

## S4: NOBODY OUTSIDE ase.tcl HAND-SPELLS THE KEY. A dialog that wrote
## `dict set st sim_entry $name` would be right for every entry except one
## called `none`, and wrong in the one place a reader would never look. The
## setter answers a NEW dict, so a caller cannot dirty a state it was only
## reading.
set S4ST [a_ans ase::state_default]
set S4E [a_ans ase::sim_choice_set $S4ST entry none]
set S4P [a_ans ase::sim_choice_set $S4ST path]
set S4U [a_ans ase::sim_choice_set $S4E unset]
check {S4 a caller sets and reads one state's choice without ever spelling the stored form, the original state is left untouched, and clearing it puts the session back to "no choice of my own"} \
  [list [a_ans ase::state_get $S4E sim_entry] [a_ans ase::sim_choice_of $S4E] \
        [a_ans ase::state_get $S4P sim_entry] [a_ans ase::sim_choice_of $S4P] \
        [a_ans ase::state_get $S4U sim_entry] [a_ans ase::sim_choice_of $S4U] \
        [a_ans ase::state_get $S4ST sim_entry] [a_ans ase::sim_choice_of $S4ST]] \
  [list {name none} {entry none} none {path {}} {} {unset {}} {} {unset {}}]

## S5: THE FIRST REGISTRATION BECOMES THE INSTALLATION DEFAULT, AND NOTHING
## AFTER IT STEALS THE TITLE -- the same rule the in-force seed has always had,
## applied to the other variable. A session's own pick moves what is in force
## and leaves the default exactly where it was, which is the ruling in one line.
a_reset
set S5EMPTY [a_ans ase::sim_default_choice]
a_ans ase::sim_register s5-a $STUB
set S5ONE [list [a_ans ase::sim_default_choice] [a_ans ase::sim_selected]]
a_ans ase::sim_register s5-b $STUB2
set S5TWO [list [a_ans ase::sim_default_choice] [a_ans ase::sim_selected]]
a_ans ase::sim_select s5-b
set S5PICK [list [a_ans ase::sim_default_choice] [a_ans ase::sim_selected]]
check {S5 the first simulator registered on an empty list becomes both what is in force and the installation default, a later registration steals neither, and picking one in this session moves only what is in force} \
  [list $S5EMPTY $S5ONE $S5TWO $S5PICK] \
  [list {unset {}} {{entry s5-a} s5-a} {{entry s5-a} s5-a} {{entry s5-a} s5-b}]

## S6: HOW THE SAVED FILE'S DEFAULT GETS IN, AT NO COST TO THE FILE FORMAT.
## `ase::sim_select` reads which layer is talking. The file and the rc speak for
## the machine, so their selection line is a DEFAULT; a session speaks for one
## bench, so its selection is a choice and stops at `sim_use`. Driven through
## the real reader on a real file, never by poking the layer signal.
a_reset
set S6P [file join $scratch conf_s6]
a_wr $S6P "ase::sim_register s6-a $STUB\nase::sim_register s6-b $STUB2\n[list ase::sim_select s6-b]\n"
a_ans ase::sim_load_conf $S6P
set S6NAMED [list [a_ans ase::sim_default_choice] [a_ans ase::sim_selected]]
a_reset
set S6PNONE [file join $scratch conf_s6none]
a_wr $S6PNONE "ase::sim_register s6-a $STUB\nase::sim_register s6-b $STUB2\n[list ase::sim_select {}]\n"
a_ans ase::sim_load_conf $S6PNONE
set S6NONE [list [a_ans ase::sim_default_choice] [a_ans ase::sim_selected]]
check {S6 a selection line in the saved list sets the installation default, and a saved "none of mine" is recorded as the deliberate PATH choice issue 0932 established rather than as no opinion at all} \
  [list $S6NAMED $S6NONE] \
  [list {{entry s6-b} s6-b} {{path {}} {}}]

## S7: REMOVING THE DEFAULT. The same two arms the in-force choice has had
## since issue 0937, for the same reason: one left is not a guess, two or more
## is, and a guess is left to the user. No new sentence -- the user removed an
## entry and has already been told what will start now.
a_reset
a_ans ase::sim_register s7-a $STUB
a_ans ase::sim_register s7-b $STUB2
a_ans ase::sim_register s7-c $STUB
a_ans ase::sim_unregister s7-a
set S7THREE [a_ans ase::sim_default_choice]
a_reset
a_ans ase::sim_register s7-a $STUB
a_ans ase::sim_register s7-b $STUB2
a_ans ase::sim_unregister s7-a
set S7TWO [a_ans ase::sim_default_choice]
a_reset
a_ans ase::sim_register s7-a $STUB
a_ans ase::sim_unregister s7-a
set S7ONE [a_ans ase::sim_default_choice]
a_reset
a_ans ase::sim_register s7-a $STUB
a_ans ase::sim_register s7-b $STUB2
a_ans ase::sim_unregister s7-b
set S7OTHER [a_ans ase::sim_default_choice]
check {S7 taking away the entry that was the installation default leaves no default when what is left is a guess and the sole survivor when it is not, and taking away any OTHER entry leaves the default alone} \
  [list $S7THREE $S7TWO $S7ONE $S7OTHER] \
  [list {unset {}} {entry s7-b} {unset {}} {entry s7-a}]

## S8: A SAVE THAT CANNOT HAPPEN SAYS SO ONCE. ase::sim_write_conf already
## reports its own failures and returns 0 rather than raising, so the autosave
## must not add a second sentence about the same failure -- two sentences for
## one event is how a user learns to stop reading them. The registration itself
## is clean (a real stub), so every sentence counted here is about the save.
set S8HAD [info exists ::USER_CONF_DIR]
set S8OLD {}
if {$S8HAD} { set S8OLD $::USER_CONF_DIR }
a_reset
set ::USER_CONF_DIR [file join $scratch s8 nowhere deeper]
set S8SAID [a_echoed {a_ans ase::sim_register s8-a $::STUB}]
set S8N 0
foreach s8p $S8SAID { if {[regexp -nocase {could not be saved} [lindex $s8p 1]]} { incr S8N } }
if {$S8HAD} { set ::USER_CONF_DIR $S8OLD } else { catch {unset ::USER_CONF_DIR} }
check {S8 a registration that cannot be saved tells the user exactly once, and the entry is still in the list they can see and fix} \
  [list [llength $S8SAID] $S8N [a_names]] \
  [list 1 1 s8-a]

## S8b: AND A SESSION WITH NO CONFIGURATION DIRECTORY AT ALL SAYS NOTHING.
## There is no user file for such an installation, so there is nothing to keep
## the list in and nothing the user could do about it -- the same rule E11 pins
## for a first run with no saved list. Measured before the guard: every single
## registration said "Your simulator list could not be saved to , so the
## simulators you added will be gone when xschem closes" -- a sentence with a
## hole where the file name goes, about a save nobody asked for.
set S8BHAD [info exists ::USER_CONF_DIR]
set S8BOLD {}
if {$S8BHAD} { set S8BOLD $::USER_CONF_DIR }
a_reset
catch {unset ::USER_CONF_DIR}
set S8BSAID [a_echoed {a_ans ase::sim_register s8b-a $::STUB}]
set S8BFILE [a_ans ase::sim_conf_file]
if {$S8BHAD} { set ::USER_CONF_DIR $S8BOLD } else { catch {unset ::USER_CONF_DIR} }
check {S8b registering in a session that has no configuration directory at all says nothing about saving, because there is nowhere a list could live and nothing the user could do about it} \
  [list $S8BFILE [llength $S8BSAID] [a_names]] \
  [list {} 0 s8b-a]

## S9-S10: WHAT MAY WRITE THE USER'S LIST, AND WHAT MAY NOT.
##
## S9 is the rule in the source comment: *a mutation that expresses a user's
## choice persists; a teardown does not.* ase::sim_clear is "forget every
## registered simulator and every choice", and its callers are test resets and
## scripts. An autosave there is the one way an autosave-at-the-mutation design
## can DESTROY data, and it would blank the real list of anyone whose session
## ran a script that reset the registry.
##
## S10 is the landmine underneath the whole design: ase::sim_load_conf SOURCES
## the saved list, so every line in it is a real ase::sim_register call. Without
## the layer gate the reader rewrites the file it is halfway through reading,
## once per line, from a registry that is only partly built.
set S9HAD [info exists ::USER_CONF_DIR]
set S9OLD {}
if {$S9HAD} { set S9OLD $::USER_CONF_DIR }
a_reset
set ::USER_CONF_DIR [file join $scratch s9conf]
file mkdir $::USER_CONF_DIR
set S9F [file join $::USER_CONF_DIR ase_simulators]
file delete -force $S9F
a_ans ase::sim_register s9-a $STUB
a_ans ase::sim_register s9-b $STUB2
set S9MADE [file exists $S9F]
set S9TXT [a_slurp $S9F]
set S9MT0 [expr {$S9MADE ? [file mtime $S9F] : 0}]
after 1100
a_ans ase::sim_clear
set S9AFTERCLEAR [list [file exists $S9F] [expr {[file exists $S9F] ? [file mtime $S9F] : -1}]]
set S10LOAD [a_ans ase::sim_load_conf $S9F]
set S10AFTERLOAD [list [file exists $S9F] [expr {[file exists $S9F] ? [file mtime $S9F] : -1}]]
after 1100
a_ans ase::sim_select s9-b
set S9AFTERPICK [expr {[file exists $S9F] ? [file mtime $S9F] : -1}]
if {$S9HAD} { set ::USER_CONF_DIR $S9OLD } else { catch {unset ::USER_CONF_DIR} }
check {S9 registering writes the list with no save gesture at all, and then neither forgetting the whole registry nor picking a different simulator touches that file again -- a teardown is not a choice, and a choice is not the environment} \
  [list $S9MADE \
        [expr {[string first {ase::sim_register s9-a} $S9TXT] >= 0}] \
        [expr {[string first {ase::sim_register s9-b} $S9TXT] >= 0}] \
        $S9AFTERCLEAR $S9AFTERPICK] \
  [list 1 1 1 [list 1 $S9MT0] $S9MT0]
check {S10 reading the saved list back does not rewrite it -- every line in that file is a real registration, so an ungated writer would have the reader editing the file it is halfway through} \
  [list $S10LOAD $S10AFTERLOAD [a_names]] \
  [list 1 [list 1 $S9MT0] {s9-a s9-b}]

## S11: THE RUN APPLIES THE RUNNING SESSION'S CHOICE. `ase::sim_use` is
## process-global and every resolver reads it, so with two ASE-L windows open on
## two benches there is one answer for two questions; the run is where that
## stops being rhetorical. A state that says nothing falls through to the
## installation default, which is what all 104 committed states say. A state
## naming an entry that is no longer registered NEVER raises -- it is called
## from inside a run that is about to start -- and says the one sentence that
## already exists for it.
a_reset
a_ans ase::sim_register s11-a $STUB
a_ans ase::sim_register s11-b $STUB2
set S11UNSET [list [a_ans ase::sim_apply_choice [dict create]] [a_ans ase::sim_selected]]
set S11PICK  [list [a_ans ase::sim_apply_choice [dict create sim_entry {name s11-b}]] \
                   [a_ans ase::sim_selected]]
set S11PATH  [list [a_ans ase::sim_apply_choice [dict create sim_entry none]] \
                   [a_ans ase::sim_selected]]
a_ans ase::sim_select s11-b
set ::s11g {}
set S11GONESAID [a_echoed {set ::s11g [a_ans ase::sim_apply_choice [dict create sim_entry {name s11-gone}]]}]
set S11GONE [list $::s11g [a_ans ase::sim_selected]]
set S11NAMED 0
foreach s11p $S11GONESAID {
  if {[string first s11-gone [lindex $s11p 1]] >= 0} { incr S11NAMED }
}
check {S11 the session being run decides which program starts: a state with no choice of its own falls through to the installation default, a state naming an entry gets that entry, a state saying "the PATH program" gets the PATH, and a state naming a simulator that is no longer registered changes nothing and says so by name instead of blowing up mid-run} \
  [list $S11UNSET $S11PICK $S11PATH $S11GONE [llength $S11GONESAID] $S11NAMED] \
  [list {{entry s11-a} s11-a} {{entry s11-b} s11-b} {{path {}} {}} \
        {{entry s11-b} s11-b} 1 1]

## S12: STRUCTURAL -- WHERE THAT CALL SITS, which no behavioural row can see.
## Below the in-flight refusal (a run that will not happen must not change which
## program is in force) and above every line that resolves a simulator, so the
## pre-check, the capability report, the command that is composed and the
## sentence the user reads all name the same program. It is in ase::run_deck
## rather than ase::run because run_deck is the body all three doors share --
## ase::run, ase::run_existing and a script or Command-window paste come
## straight here -- and it appears ONCE, because two calls would say the
## stale-entry sentence twice for one gesture.
set S12APPLY [a_lines_matching $ASETCL {ase::sim_apply_choice $state}]
set S12LOCK  [a_lines_matching $ASETCL {ase::run_in_flight $rawlock}]
set S12PRE   [a_lines_matching $ASETCL {ase::run_precheck $state}]
set S12USING [a_lines_matching $ASETCL {ase::run_using_report $state}]
set S12CMD   [a_lines_matching $ASETCL {$run_cmd $state $deckpath}]
set S12ORD 0
if {[llength $S12APPLY] == 1 && [llength $S12LOCK] == 1 && [llength $S12PRE] == 1 \
    && [llength $S12USING] == 1 && [llength $S12CMD] == 1} {
  set S12ORD [expr {([lindex $S12APPLY 0] > [lindex $S12LOCK 0]) &&
                    ([lindex $S12APPLY 0] < [lindex $S12PRE 0]) &&
                    ([lindex $S12APPLY 0] < [lindex $S12USING 0]) &&
                    ([lindex $S12APPLY 0] < [lindex $S12CMD 0])}]
}
check {S12 STRUCTURAL the running session's choice is put in force once, in the one body all three run doors share, below the gate that refuses without looking at a simulator and above everything that resolves one} \
  [list [llength $S12APPLY] $S12ORD] [list 1 1]

## S12b: AND THE WIRING, NOT ONLY THE LINE. A run whose state names the SECOND
## simulator, started while the FIRST is what is in force, must leave the second
## in force -- that is "the window you clicked in wins". Driven through the real
## ase::run_deck with the pre-flight refusing, which is L15's trick: the refusal
## comes from BELOW the line under test, so the choice has already been applied
## and nothing is written, launched or deleted.
set S12NL [file join $scratch s12.spice]
a_wr $S12NL "* s12\n.end\n" 0644
proc a_s12_run {nl st} {
  set ::a_s12_rc NOPROC
  if {![llength [info commands ::ase::preflight_gate]]} { return }
  rename ::ase::preflight_gate ::a_s12_saved_pfg
  proc ::ase::preflight_gate {state netlist_text} {
    return -code error "ase: s12 refuses this run"
  }
  set ::a_s12_rc [catch {ase::run_deck $st $nl}]
  rename ::ase::preflight_gate {}
  rename ::a_s12_saved_pfg ::ase::preflight_gate
}
a_reset
a_ans ase::sim_register s12-a $STUB
a_ans ase::sim_register s12-b $STUB2
a_ans ase::sim_select s12-a
set S12BEFORE [a_ans ase::sim_selected]
a_echoed [list a_s12_run $S12NL [dict create simulator ngspice sim_entry {name s12-b}]]
set S12AFTER [a_ans ase::sim_selected]
a_echoed [list a_s12_run $S12NL [dict create simulator ngspice sim_entry none]]
set S12PATHAFTER [a_ans ase::sim_selected]
check {S12b a run started from a session that picked the second simulator really does put that one in force before anything resolves a program, and a session that picked the PATH program gets the PATH -- with two ASE-L windows open, the one you pressed Run in wins} \
  [list $S12BEFORE $S12AFTER $S12PATHAFTER $::a_s12_rc] \
  [list s12-a s12-b {} 1]

## S13: STRUCTURAL -- THE SAVED LIST IS WRITTEN FROM THE DEFAULT, NEVER FROM
## WHAT IS IN FORCE. The behavioural half is E2 and R8b; this is the half that
## stays true when somebody "restores" one line. `ase::sim_write_body` must not
## even be able to see `sim_use`.
set S13BODY [a_procbody [a_nocomment $ASETCL] ase::sim_write_body]
check {S13 STRUCTURAL the writer of the saved list cannot reach what is in force at all -- it reads the installation default and decodes it, so a choice can never leak back into the machine's own file} \
  [list [expr {[string first {variable sim_default} $S13BODY] >= 0}] \
        [expr {[string first {sim_use} $S13BODY] >= 0}] \
        [expr {[string first {sim_choice_decode} $S13BODY] >= 0}]] \
  [list 1 0 1]

# ============================================================================
# P. THE PRE-DECK OPTIONS THIS BENCH ASKED FOR -- ISSUE 1439, PLAN.md §7d
# ============================================================================
# ⚠ THIRTY-TWO of this simulator's options are reachable from NEITHER
# `.options` NOR `.control`. `-D name` / `-D name=<string>` is the only door to
# the CP_BOOL and CP_STRING ones. The words are spelled by the ONE speller and
# routed by the computed door; run_cmd learns nothing about what an option
# looks like.
#
# MEASURED on both binaries for this section: `-D ngbehavior=hs` prints
# `Note: Compatibility modes selected: hs`; `-D mingwpath` arrives as a
# valueless CP_BOOL; `-D warn=1` and `-D wnflag=1` are inert because
# `-D name=value` is ALWAYS a CP_STRING (main.c:984-999).
a_reset
set PDECK [file join $scratch p_deck.spice]
proc p_st {args} {
  set st [dict create design [dict create lib L cell c1 view schematic] \
                      simulator ngspice rundir {} options {}]
  foreach {k v} $args { dict set st $k $v }
  return $st
}
proc p_o {args} {
  set o {} ; foreach {n v} $args { lappend o [list name $n value $v] } ; return $o
}
set PRUN [file join $scratch prun] ; file mkdir $PRUN

## ⚠ THE ROW THE SIX GOLDENS WOULD HAVE BEEN. Same claim, stated as a fact
## about a bench that sets nothing rather than as six unmoved goldens.
check {P1 a bench that sets no pre-deck option builds exactly the command A2 pins} \
  [list [a_runcmd $PDECK] \
        [ase::backend::ngspice::run_cmd [p_st options [p_o reltol 1e-5]] $PDECK]] \
  [list [list ngspice -b $PDECK 2>@1] [list ngspice -b $PDECK 2>@1]]

check {P2 a pre-deck string and a pre-deck flag land after ASE-L's own flags and before the deck} \
  [ase::backend::ngspice::run_cmd \
     [p_st rundir $PRUN options [p_o ngbehavior hs mingwpath 1]] $PDECK] \
  [list ngspice -b -D ngbehavior=hs -D mingwpath $PDECK 2>@1]

## A registered binary and the user's own words still come first, and 2>@1 is
## still last: the arm is inserted, not spliced over anything.
check {P3 the arm composes with a registered binary and the arguments the user typed} \
  [a_ans apply {{} {
     global STUB PDECK PRUN
     a_reset
     ase::sim_register ng-pd $STUB -args {-q --foo}
     set c [ase::backend::ngspice::run_cmd \
              [p_st rundir $PRUN options [p_o ngbehavior hs]] $PDECK]
     a_reset
     return $c }}] \
  [list $STUB -b -q --foo -D ngbehavior=hs $PDECK 2>@1]

## ⚠ `-D name=value` IS ALWAYS A CP_STRING (main.c:984-999), so a CP_NUM,
## CP_REAL or CP_LIST pre-deck option must never reach the command line at all.
## MEASURED on both binaries: `-D wnflag=1` and `-D warn=1` are inert.
check {P4 a pre-deck number never reaches the command line, whatever the bench stores} \
  [ase::backend::ngspice::run_cmd \
     [p_st rundir $PRUN options [p_o ps_tpz_delays 1 sourcepath {/a /b}]] $PDECK] \
  [list ngspice -b $PDECK 2>@1]

## ⚠ MEASURED ON BOTH BINARIES: `-n` suppresses the START-UP FILE and nothing
## else. `ngspice -b -n -D ngbehavior=hs <deck>` still prints `Note:
## Compatibility modes selected: hs`. So `-n` and this arm are independent, and
## `-n` keeps the slot it has always had.
check {P5 the entry's -n flag and the pre-deck arm are independent, and -n keeps its slot} \
  [a_ans apply {{} {
     global PDECK PRUN
     rename ::ase::sim_nospiceinit ::ase::__nsi_real
     proc ::ase::sim_nospiceinit {backend} { return 1 }
     set c [ase::backend::ngspice::run_cmd \
              [p_st rundir $PRUN options [p_o ngbehavior hs]] $PDECK]
     rename ::ase::sim_nospiceinit {}
     rename ::ase::__nsi_real ::ase::sim_nospiceinit
     return $c }}] \
  [list ngspice -b -n -D ngbehavior=hs $PDECK 2>@1]

## ⚠ NON-VACUITY. A catalogue defect must never stop a run, so the arm is
## caught -- and a `catch` around a call that is no longer made would leave P2
## the only witness. This row says the router is reached by name.
check {P6 the command builder reaches the one router, rather than spelling an option itself} \
  [a_ans apply {{} {
     set b [info body ::ase::backend::ngspice::run_cmd]
     set code {}
     foreach l [split $b "\n"] { if {![regexp {^\s*#} $l]} { lappend code $l } }
     set code [join $code "\n"]
     return [list [expr {[string first {ase::predeck_argv ngspice $state} $code] >= 0}] \
                  [expr {[string first {-D } $code] >= 0}]] }}] {1 0}

# --- teardown ----------------------------------------------------------------
a_reset
catch {cd $A_SAVEDCWD}

# --- verdict -----------------------------------------------------------------
# THE DUAL BANNER IS REQUIRED by tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE OVERALL line
# as well as the RESULT line; registering a suite there without one reproduces
# the completion-sentinel false red filed four times as 0420 / 0492 / 0629 / 0689.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
