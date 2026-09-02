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
set A4C [a_child a4 [string map [list @DECK@ $DECK] $A4B] {} $A_CLEANHOME]
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

set E2BEFORE [list [a_shape] [a_ans ase::sim_selected]]
a_reset
set E2LOAD [a_ans ase::sim_load_conf $E1P]
set E2AFTER [list [a_shape] [a_ans ase::sim_selected]]
check {E2 saving then reading back gives the same list and the same choice, field for field} \
  [list $E2LOAD [expr {$E2AFTER eq $E2BEFORE}] $E2AFTER] \
  [list 1 1 $E2BEFORE]

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
set E3C [a_child e3 [string map [list @STUB2@ $STUB2 @CONF@ $E3CONF] $E3B] $E3PRE $A_CLEANHOME]
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
set E8C [a_child e8 $::A_REPORT $E8PRE $A_CLEANHOME]
check {E8 a startup configuration file can put a simulator in the list and in force, exactly the way it already sets the default models} \
  [list [a_zrc $E8C] [a_zval $E8C Z_N] [a_zval $E8C Z_SEL] [a_zval $E8C Z_EXE] \
        [a_zval $E8C Z_ORIGIN] [a_zval $E8C Z_DONE]] \
  [list 0 1 rc-one $STUB rc 1]

set E9C [a_child e9 $::A_REPORT {} $A_CLEANHOME]
check {E9 the same xschem started WITHOUT that line has an empty list and is back to the program on your PATH -- removable, proved not asserted} \
  [list [a_zrc $E9C] [a_zval $E9C Z_N] [a_zval $E9C Z_SEL] [a_zval $E9C Z_EXE] [a_zval $E9C Z_DONE]] \
  [list 0 0 {} ngspice 1]

set E10PRE_A {set ::ASE_SIMULATOR zz-not-registered-anywhere}
set E10PRE_B "set ::ASE_SIMULATORS \[list \[list name rc-bad path $MISSING args {} backend {}\]\]"
set E10A [a_child e10a $::A_REPORT $E10PRE_A $A_CLEANHOME]
set E10B [a_child e10b $::A_REPORT $E10PRE_B $A_CLEANHOME]
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
set E12A [a_child e12a $::A_REPORT $E12PRE_A $A_CLEANHOME]
set E12B [a_child e12b $::A_REPORT $E12PRE_B $A_CLEANHOME]
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
set E13C [a_child e13 $E13B $E13PRE $A_CLEANHOME]
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
set R8HOME  [file join $scratch home_r8a]
set R8HOME2 [file join $scratch home_r8b]
file delete -force $R8HOME
file delete -force $R8HOME2
set R8W {
  set r NOPROC
  if {[llength [info commands ase::sim_register]]} {
    ase::sim_register r8-a @STUB@
    ase::sim_register r8-b @STUB2@
    set r [ase::sim_select @PICK@]
  }
  puts "Z_PICK=$r"
  set w NOPROC
  if {[llength [info commands ase::sim_write_conf]]} { set w [ase::sim_write_conf] }
  puts "Z_WROTE=$w"
  puts "Z_DONE=1"
  exit 0
}
set R8WNONE [string map [list @STUB@ $STUB @STUB2@ $STUB2 @PICK@ "{}"] $R8W]
set R8WPICK [string map [list @STUB@ $STUB @STUB2@ $STUB2 @PICK@ "r8-b"] $R8W]
set R8C1 [a_child r8w1 $R8WNONE {} $R8HOME]
set R8C2 [a_child r8r1 $::A_REPORT {} $R8HOME]
set R8C3 [a_child r8w2 $R8WPICK {} $R8HOME2]
set R8C4 [a_child r8r2 $::A_REPORT {} $R8HOME2]
check {R8 "use the program on my PATH" is a choice like any other and it survives a restart -- and the control arm proves a real pick still survives one too} \
  [list [a_zrc $R8C1] [a_zval $R8C1 Z_WROTE] \
        [a_zrc $R8C2] [a_zval $R8C2 Z_N] [a_zval $R8C2 Z_SEL] [a_zval $R8C2 Z_EXE] \
        [a_zval $R8C2 Z_DONE] \
        [a_zrc $R8C3] [a_zval $R8C3 Z_WROTE] \
        [a_zrc $R8C4] [a_zval $R8C4 Z_SEL] [a_zval $R8C4 Z_EXE] [a_zval $R8C4 Z_DONE]] \
  [list 0 1 0 2 {} ngspice 1 0 1 0 r8-b $STUB2 1]

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
