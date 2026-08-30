# tests/headless/test_ase_simcaps_0948.tcl -- ISSUE 0948: A REGISTERED
# SIMULATOR IS NEVER ASKED WHAT IT CAN ACTUALLY DO.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# They point ASE-L at a simulator build of their own, in Setup > Simulators.
# It starts, it exits without complaint, and its log has no warning and no
# error line in it. And their operating point is gone: pressing 6 on the
# schematic says there are no operating point results, because the deck asked
# the simulator to ADD each analysis to the results file and this build threw
# the earlier ones away as it went. Nothing anywhere told them. That is issue
# 0929's exact symptom, arriving silently through a door 0929 never guarded.
#
# ============================================================================
# THE BEFORE-STATE, MEASURED AT HEAD bb8fe6a2 AND NOT RE-DERIVED HERE
# ============================================================================
# * Asking the simulator registry what a registered build can do errors out:
#     ase: unknown hook 'capabilities' for simulator 'ngspice'
#   The registered hook set is exactly render_deck run_cmd log_file
#   result_probe raw_file. `grep -c capabilit` over src/ase.tcl and
#   src/ase_window.tcl is 0 in both.
# * Two decks identical but for one line, both through the real ngspice:
#   with the add-each-analysis line, one results file holding an Operating
#   Point plot AND a Transient Analysis plot; without it, one plot, the
#   transient. Both runs exit 0. BOTH LOGS ARE CLEAN -- no warning, no error.
# * A version string cannot tell the two builds apart: both print
#   "** ngspice-46+ : Circuit level simulation program", byte for byte.
# * The tree reports the unusable build as perfectly healthy: the validator
#   returns empty, the resolver returns ok 1 with nothing to say, and the
#   record a dialog reads back to the user is empty.
# * A blanket device save, ".save @m.xo1.xi1.m1[*]", exits 0, WRITES a results
#   file, and logs nothing -- and the file holds a constants plot and no
#   operating point at all. An "did the command error" check calls that
#   success. It is the reason every verdict in this file is taken from the
#   RESULT and never from the exit code.
#
# ============================================================================
# THE ANSWER DISCIPLINE -- an absent proc must never satisfy a golden
# ============================================================================
# Borrowed verbatim from tests/headless/test_ase_simreg_0931.tcl. Every
# helper answers NOPROC when the command it calls does not exist and
# RAISED:<text> when it blows up. A bare catch-and-discard would let
# "invalid command name ase::sim_capabilities" satisfy a row expecting an
# empty string, and this file would go green against the very tree it was
# written to redden.
#
# ============================================================================
# NO SIMULATOR IS NEEDED TO RUN THIS FILE -- THE STUB CONTRACT
# ============================================================================
# Sections B, C, D, E and G drive HERMETIC STUB SIMULATORS this file writes
# itself: a few-line /bin/sh script that reads the deck it was handed, takes
# the results path off the deck's own `write` line, copies a canned results
# file there, records the run in a counter file, and exits with a code the
# stub chooses. So the probe's behaviour is proved with no ngspice on the box.
# Row C4 is the one row that uses the real ngspice, and it says so loudly and
# skips itself when none resolves.
#
# THE STUB DEPENDS ON THREE THINGS THE PLAN NAMES, AND ON NOTHING ELSE:
#   1. the probe hands the deck to the program as a FILE ARGUMENT;
#   2. the probe deck carries a line beginning `write ` naming where the
#      results go;
#   3. THE PROBE RUNS TWO DECKS, and the blanket-save one is the one whose
#      save card carries the `[*]` wildcard form -- which row C3 asserts
#      structurally, so it is a contract and not a guess.
# A probe that merged both questions into one run would break rows B1-B6 for
# a reason that is not about the subject. Two runs, two decks.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE -- READ BEFORE TRUSTING IT
# ============================================================================
# * NO PIXELS. There is no dialog here. A green run proves the answer a
#   Simulators window would show, never the window.
# * NO DECK EMISSION CHANGES. Section H exists to prove the emitted deck did
#   NOT move: one add-each-analysis line, one write per analysis, unchanged.
# * NOTHING IS INSTALLED OR BUILT. Every binary here is a /bin/sh script in a
#   throw-away directory, except row C4's.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_simcaps_0948.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_simcaps_0948.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# --- locations, cwd-independent ---------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch simcaps0948]
set ASETCL [file join $repo src ase.tcl]

# --- the answer discipline ---------------------------------------------------
proc a_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
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
## The same, for a file that is NOT text. A results file written as numbers
## carries bytes no text channel may re-encode, so the channel is put in the
## mode that hands them through untouched.
proc a_wrbin {path bytes} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  fconfigure $fp -translation binary
  puts -nonewline $fp $bytes
  close $fp
}
proc a_slurp {path} {
  if {![file exists $path]} { return "ZZNOFILE" }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## Tcl comments dropped, so a sentence quoted in a comment cannot satisfy a
## row about where the sentence is MINTED.
proc a_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc a_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
## The comment-stripped BODY of a proc, read at run time. Reading the body
## rather than grepping the file means a probe that grew a helper cannot hide
## a forbidden command behind a proc name this file never heard of -- see
## a_probe_src below, which unions the whole family.
proc a_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [a_nocomment $b]
}

# ============================================================================
# THE CANNED RESULTS FILES -- the shapes the probe has to tell apart
# ============================================================================
# Plain-text ngspice rawfiles, header for header the shape the real one
# writes (measured against a real ngspice run in the before-state). Written
# as text on purpose: this tree's own reader accepts a text rawfile, so row
# G2's behavioural half can attach one, and a text file makes the fixtures
# readable by whoever has to debug a red row.
set OPHDR_HIER "Plotname: Operating Point\nFlags: real\nNo. Variables: 3\nNo. Points: 1\nVariables:\n\t0\ti(@m.xo1.xi1.m1\[id\])\tcurrent\n\t1\t@m.xo1.xi1.m1\[gm\]\tadmittance\n\t2\tv(@m.xo1.xi1.m1\[vdsat\])\tvoltage\nValues:\n 0\t1.2500002e-05\n\t5e-05\n\t5.000000e-01\n"
set OPHDR_FLAT "Plotname: Operating Point\nFlags: real\nNo. Variables: 3\nNo. Points: 1\nVariables:\n\t0\ti(@m1\[id\])\tcurrent\n\t1\t@m1\[gm\]\tadmittance\n\t2\tv(@m1\[vdsat\])\tvoltage\nValues:\n 0\t1.2500002e-05\n\t5e-05\n\t5.000000e-01\n"
set OPHDR_ZERO "Plotname: Operating Point\nFlags: real\nNo. Variables: 3\nNo. Points: 0\nVariables:\n\t0\ti(@m.xo1.xi1.m1\[id\])\tcurrent\n\t1\t@m.xo1.xi1.m1\[gm\]\tadmittance\n\t2\tv(@m.xo1.xi1.m1\[vdsat\])\tvoltage\nValues:\n"
set TRHDR "Plotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n\t0\ttime\ttime\n\t1\tv(dd)\tvoltage\nValues:\n 0\t0.000000e+00\n\t1.800000e+00\n 1\t1.000000e-09\n\t1.800000e+00\n 2\t2.000000e-09\n\t1.800000e+00\n"
set TITLE "Title: * ase capability probe\nDate: Sat Aug 29 00:00:00  2026\n"
set CONSTHDR "Title: Constant values\nDate: Sat Aug 29 00:00:00  2026\nPlotname: constants\nFlags: complex\nNo. Variables: 12\nNo. Points: 1\nVariables:\n\t0\tyes\tnotype\n\t1\tfalse\tnotype\n\t2\ttrue\tnotype\n\t3\tboltz\tnotype\n\t4\tc\tnotype\n\t5\te\tnotype\n\t6\techarge\tnotype\n\t7\ti\tnotype\n\t8\tkelvin\tnotype\n\t9\tno\tnotype\n\t10\tpi\tnotype\n\t11\tplanck\tnotype\nValues:\n 0\t1.000000e+00,0.000000e+00\n"

set RAW_BOTH    [file join $scratch raw_both.raw]
set RAW_LAST    [file join $scratch raw_last.raw]
set RAW_FLAT    [file join $scratch raw_flat.raw]
set RAW_ZERO    [file join $scratch raw_zero.raw]
set RAW_BCONST  [file join $scratch raw_bconst.raw]
set RAW_BOP     [file join $scratch raw_bop.raw]
a_wr $RAW_BOTH   "$TITLE$OPHDR_HIER$TITLE$TRHDR"
a_wr $RAW_LAST   "$TITLE$TRHDR"
a_wr $RAW_FLAT   "$TITLE$OPHDR_FLAT$TITLE$TRHDR"
a_wr $RAW_ZERO   "$TITLE$OPHDR_ZERO$TITLE$TRHDR"
a_wr $RAW_BCONST $CONSTHDR
a_wr $RAW_BOP    "$TITLE$OPHDR_HIER"

# --- and the same results in the shape a build that ignores the text request
# The probe deck ASKS for a results file it can read as text, but a simulator
# is free to ignore that and write its numbers as raw bytes instead. Every
# plot's header still arrives as text; what sits BETWEEN one plot's header and
# the next one's is then a block of numbers that is not text at all.
#
# THE BLOCK WRITTEN HERE SPELLS A PLOT HEADER IN THE MIDDLE OF ITSELF. That is
# not a curiosity: a reader that walked those bytes looking for lines would
# report a plot that does not exist, i.e. would describe a simulator that does
# not behave the way it does. Rows B7 and B8 are about exactly that, and the
# fixture has to contain the trap or the rows cannot see it being avoided.
set ZZGHOST "\nPlotname: ZZGHOST\nFlags: real\nNo. Variables: 1\nNo. Points: 1\nVariables:\n\t0\tzzghostvar\tvoltage\nBinary:\n"
## A block of <n> bytes with the fake header buried <off> bytes into it.
proc a_numblock {n ghost off} {
  set p [string repeat \xE7 $n]
  if {$ghost eq {}} { return $p }
  if {[string length $ghost] + $off > $n} {
    return -code error "a_numblock: fixture block too small for the trap"
  }
  return [string replace $p $off [expr {$off + [string length $ghost] - 1}] $ghost]
}
set BINOPH "Plotname: Operating Point\nFlags: real\nNo. Variables: 3\nNo. Points: 8\nVariables:\n\t0\ti(@m.xo1.xi1.m1\[id\])\tcurrent\n\t1\t@m.xo1.xi1.m1\[gm\]\tadmittance\n\t2\tv(@m.xo1.xi1.m1\[vdsat\])\tvoltage\nBinary:\n"
set BINOPHC [string map [list {Flags: real} {Flags: complex}] $BINOPH]
set BINTRH "Plotname: Transient Analysis\nFlags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n\t0\ttime\ttime\n\t1\tv(dd)\tvoltage\nBinary:\n"
set RAW_BINREAL [file join $scratch raw_binreal.raw]
set RAW_BINCPLX [file join $scratch raw_bincplx.raw]
## PLAIN numbers take eight bytes each, so the operating point's block is
## 8 points x 3 signals x 8 bytes.
a_wrbin $RAW_BINREAL "$TITLE$BINOPH[a_numblock [expr {8 * 3 * 8}] $ZZGHOST 8]$TITLE$BINTRH[a_numblock [expr {3 * 2 * 8}] {} 0]"
## Numbers with a phase to them take SIXTEEN bytes each. The trap sits in the
## second half of that block on purpose, so a reader that stepped over only
## half of it would walk straight into it -- which is what makes B8 a row
## about the wider numbers and not a copy of B7.
a_wrbin $RAW_BINCPLX "$TITLE$BINOPHC[a_numblock [expr {8 * 3 * 16}] $ZZGHOST [expr {8 * 3 * 16 / 2 + 8}]]$TITLE$BINTRH[a_numblock [expr {3 * 2 * 8}] {} 0]"

# ============================================================================
# THE STUB SIMULATOR
# ============================================================================
# Reads the deck it was handed, copies a canned results file to the path the
# deck's own `write` line names, records the run, and exits with the code it
# was built with. The blanket arm is chosen by the `[*]` wildcard in the
# deck's save card -- contract item 3 at the top of this file.
set COUNT [file join $scratch probe_runs.log]
set STUBTPL {#!/bin/sh
echo @MARK@ >> @COUNT@
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
if [ -z "$deck" ]; then exit @RC@; fi
@WAIT@
out=`grep -E '^[ 	]*write[ 	]' "$deck" | head -1 | sed -e 's/^[ 	]*write[ 	][ 	]*//' -e 's/[ 	]*$//'`
src=@NORMAL@
if grep -q '\[\*\]' "$deck"; then src=@BLANKET@; fi
if [ -n "$out" ] && [ "$src" != NONE ] && [ -f "$src" ]; then cat "$src" > "$out"; fi
exit @RC@
@PAD@}
proc a_stub {path mark normal blanket rc {wait {}} {pad {}}} {
  global STUBTPL COUNT
  a_wr $path [string map [list @MARK@ $mark @COUNT@ $COUNT @NORMAL@ $normal \
                               @BLANKET@ $blanket @RC@ $rc @WAIT@ $wait \
                               @PAD@ $pad] $STUBTPL] 0755
  return $path
}
## How many times the program marked <mark> has been started, ever.
proc a_runs {mark} {
  global COUNT
  if {![file exists $COUNT]} { return 0 }
  set n 0
  foreach l [split [a_slurp $COUNT] "\n"] { if {[string trim $l] eq $mark} { incr n } }
  return $n
}

set BIN [file join $scratch bin]
file mkdir $BIN
set S_GOOD    [a_stub [file join $BIN sim_good]    good    $RAW_BOTH $RAW_BCONST 0]
set S_LAST    [a_stub [file join $BIN sim_last]    last    $RAW_LAST $RAW_BCONST 0]
set S_NONE    [a_stub [file join $BIN sim_none]    none    NONE      NONE        0]
set S_BADRC   [a_stub [file join $BIN sim_badrc]   badrc   $RAW_BOTH $RAW_BCONST 1]
set S_ZERO    [a_stub [file join $BIN sim_zero]    zero    $RAW_ZERO $RAW_BCONST 0]
set S_FLAT    [a_stub [file join $BIN sim_flat]    flat    $RAW_FLAT $RAW_BCONST 0]
set S_BOP     [a_stub [file join $BIN sim_bop]     bop     $RAW_BOTH $RAW_BOP    0]
set S_WAIT    [a_stub [file join $BIN sim_wait]    wait    NONE      NONE        0 {head -n 1 > /dev/null}]
set S_D1      [a_stub [file join $BIN sim_d1]      d1      $RAW_BOTH $RAW_BCONST 0]
set S_DCACHE  [a_stub [file join $BIN sim_dcache]  dcache  $RAW_BOTH $RAW_BCONST 0]
set S_D5A     [a_stub [file join $BIN sim_d5a]     d5a     $RAW_BOTH $RAW_BCONST 0]
set S_D5B     [a_stub [file join $BIN sim_d5b]     d5b     $RAW_LAST $RAW_BCONST 0]
set S_D6      [a_stub [file join $BIN sim_d6]      d6      $RAW_BOTH $RAW_BCONST 0]
set S_G2      [a_stub [file join $BIN sim_g2]      g2      $RAW_BOTH $RAW_BCONST 0]
set S_G4      [a_stub [file join $BIN sim_g4]      g4      $RAW_BOTH $RAW_BCONST 0]
set S_F1      [a_stub [file join $BIN sim_f1]      f1      $RAW_LAST $RAW_BCONST 0]
set S_F3      [a_stub [file join $BIN sim_f3]      f3      NONE      NONE        0]
set S_F4      [a_stub [file join $BIN sim_f4]      f4      $RAW_BOTH $RAW_BCONST 0]
## Two programs whose NAMES have to resolve on the PATH, for the two rows
## about a resolver that says no -- E2 needs a backend the PATH can answer
## for, or its arm is indistinguishable from E1's.
a_wr [file join $BIN zzcapfive]  "#!/bin/sh\nexit 0\n" 0755
a_wr [file join $BIN zzcapwrong] "#!/bin/sh\nexit 0\n" 0755
set PATHSAVE $::env(PATH)
set ::env(PATH) "$BIN:$PATHSAVE"

## The probe scratch area must not land in the developer's own simulation
## directory, and G4 counts the files in it. ::netlist_dir is the documented
## global set_netlist_dir 0 answers with; no new variable is invented here.
set NDSAVE [expr {[info exists ::netlist_dir] ? $::netlist_dir : {ZZUNSET}}]
set ::local_netlist_dir 0
set ::netlist_dir [file join $scratch simdir]
file mkdir $::netlist_dir

# ============================================================================
# G1's MEASUREMENT IS TAKEN HERE, BEFORE ANYTHING ELSE RUNS
# ============================================================================
# Lazy means nothing was measured at startup. Both halves have to be read
# before this file starts any program of its own, so they are captured here
# and only reported down in section G.
proc a_capcache {} {
  if {![info exists ::ase::sim_caps]} { return NOVAR }
  if {[catch {dict size $::ase::sim_caps} n]} { return "RAISED:$n" }
  return $n
}
set G1CACHE [a_capcache]
set G1COUNT [file exists $COUNT]

# --- the surface under test --------------------------------------------------
proc a_cap {backend} { return [a_ans ase::sim_capabilities $backend] }
## One named field of the answer. NOKEY-<key> when the answer is a dict that
## does not carry it, so an answer that quietly drops a key cannot pass as an
## answer that says no.
proc a_capf {backend key} {
  set c [a_cap $backend]
  if {$c eq {NOPROC} || [string match RAISED:* $c]} { return $c }
  if {[catch {dict exists $c $key} h]} { return "NOTADICT:$c" }
  if {!$h} { return "NOKEY-$key" }
  return [dict get $c $key]
}
proc a_capfields {backend keys} {
  set c [a_cap $backend]
  if {$c eq {NOPROC} || [string match RAISED:* $c]} { return $c }
  set out {}
  foreach k $keys {
    if {[catch {dict exists $c $k} h]} { return "NOTADICT:$c" }
    if {$h} { lappend out [dict get $c $k] } else { lappend out "NOKEY-$k" }
  }
  return $out
}
proc a_reset {} { catch {ase::sim_clear} }
proc a_resetall {} { catch {ase::sim_clear} ; catch {ase::sim_caps_clear} }
## Point the tree at one program, the way a user does in the Simulators
## window, and hand back what the resolver then says will start.
proc a_use {name path} {
  a_reset
  set r [a_ans ase::sim_register $name $path]
  a_ans ase::sim_select $name
  return $r
}
proc a_resolved {backend} {
  set s [a_ans ase::sim_status $backend]
  if {$s eq {NOPROC} || [string match RAISED:* $s]} { return $s }
  if {[catch {dict get $s resolved} v]} { return NOKEY-resolved }
  return $v
}

## The CIW channel, spied at ase::echo. Returns a list of tag/message pairs.
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
proc a_report_do {backend n} { set ::a_repr [a_ans ase::cap_report $backend $n] }
## Both halves of a say-site: what reached the CIW, and what the record a
## dialog reads back holds afterwards.
proc a_report {backend n} {
  set ::a_repr NOPROC
  catch {ase::sim_said_clear}
  set said [a_echoed [list a_report_do $backend $n]]
  set rec [a_ans ase::sim_said]
  return [list $::a_repr [llength $said] [lindex [lindex $said 0] 1] $rec]
}
proc a_rep_rv   {r} { return [lindex $r 0] }
proc a_rep_n    {r} { return [lindex $r 1] }
proc a_rep_msg  {r} { return [lindex $r 2] }
proc a_rep_rec  {r} { return [lindex $r 3] }

if {[catch {

# ============================================================================
# Z. FIXTURE SANITY -- green today, on purpose
# ============================================================================
# Every row below this section is red on a tree with no capability surface.
# These five prove that when they go red it is about the SUBJECT: the stub
# really is a working stand-in simulator, the canned results files really do
# have the shapes the rows name, and the probe scratch area really is inside
# this test's own throw-away directory.

check {Z1 FIXTURE the probe scratch area is this test's own throw-away directory, not the developer's simulation directory} \
  [list [set_netlist_dir 0] [file isdirectory $::netlist_dir]] \
  [list [file join $scratch simdir] 1]

## Hand the stub a deck of the shape the probe emits and watch it behave like
## a simulator: it writes its results where the deck said, and it records the
## run.
set ZDECKDIR [file join $scratch zdeck]
file mkdir $ZDECKDIR
set ZOUT [file join $ZDECKDIR z.raw]
set ZDECK [file join $ZDECKDIR z.sp]
a_wr $ZDECK "* probe\n.control\nsave @m.xo1.xi1.m1\[id\]\nset appendwrite\nop\nremzerovec\nwrite $ZOUT\n.endc\n.end\n"
file delete -force $ZOUT
set ZRUNS0 [a_runs good]
set ZRC [catch {exec $S_GOOD -b $ZDECK < /dev/null 2>@1} zerr]
check {Z2 FIXTURE the stub stands in for a simulator: handed the probe's deck it writes its results where the deck said, and the run is recorded} \
  [list $ZRC [file exists $ZOUT] [expr {[a_runs good] - $ZRUNS0}] \
        [expr {[a_slurp $ZOUT] eq [a_slurp $RAW_BOTH]}]] \
  [list 0 1 1 1]

## The blanket arm, chosen by the wildcard in the save card.
set ZOUT2 [file join $ZDECKDIR zb.raw]
set ZDECK2 [file join $ZDECKDIR zb.sp]
a_wr $ZDECK2 "* probe\n.control\nsave @m.xo1.xi1.m1\[*\]\nop\nremzerovec\nwrite $ZOUT2\n.endc\n.end\n"
file delete -force $ZOUT2
catch {exec $S_GOOD -b $ZDECK2 < /dev/null 2>@1}
check {Z3 FIXTURE the same stub answers the blanket question differently, so a probe that asks it gets a different results file back} \
  [list [file exists $ZOUT2] [expr {[a_slurp $ZOUT2] eq [a_slurp $RAW_BCONST]}]] \
  [list 1 1]

## The canned results files are the shapes the rows below lean on. A fixture
## that lost a plot header would otherwise redden a row about the subject.
proc z_plots {p} { return [a_count [a_slurp $p] "\nPlotname: "] }
proc z_has {p s} { return [expr {[string first $s [a_slurp $p]] >= 0 ? 1 : 0}] }
check {Z4 FIXTURE the canned results files carry the shapes the rows below name} \
  [list [z_plots $RAW_BOTH] [z_plots $RAW_LAST] [z_plots $RAW_BCONST] \
        [z_has $RAW_BOTH {Plotname: Operating Point}] \
        [z_has $RAW_LAST {Plotname: Operating Point}] \
        [z_has $RAW_ZERO {No. Points: 0}] \
        [z_has $RAW_BOTH {@m.xo1.xi1.m1[gm]}] \
        [z_has $RAW_FLAT {@m1[gm]}] [z_has $RAW_FLAT {@m.xo1.xi1.m1[gm]}] \
        [z_has $RAW_BCONST {Plotname: constants}] \
        [z_has $RAW_BOP {Plotname: Operating Point}]] \
  [list 2 1 1  1 0 1  1 1 0  1 1]

## Row C4's subject. Recorded, never assumed.
set NGREAL [lindex [auto_execok ngspice] 0]
if {$NGREAL eq {}} { puts "  NOTE: no ngspice resolves on this box -- row C4 will record SKIP-NO-NGSPICE" }
check {Z5 FIXTURE whether a real simulator is on this box at all is recorded rather than assumed} \
  [expr {$NGREAL eq {} ? 0 : [file executable $NGREAL]}] \
  [expr {$NGREAL eq {} ? 0 : 1}]

# ============================================================================
# A. THE HOOK -- the registry can be asked what a build can do
# ============================================================================

set A1HOOK [a_ans ase::backend_hook ngspice capabilities]
set A1TXT [a_raisetext ase::backend_hook ngspice capabilities]
check {A1 the registered ngspice backend answers when asked what the build can do, and the answer is a real command} \
  [list [expr {![string match RAISED:* $A1HOOK] && $A1HOOK ne {NOPROC} \
                && [llength [info commands $A1HOOK]] > 0}] $A1TXT] \
  [list 1 {}]

## A backend that declares only the five required hooks must still register,
## and asking it what it can do must answer "not known" rather than raising
## or guessing a yes. The name resolves on the PATH on purpose, so this row
## is about the missing hook and not about a missing program.
set A2REG [a_ans ase::register_backend zzcapfive [dict create \
  render_deck  [a_ans ase::backend_hook ngspice render_deck] \
  run_cmd      [a_ans ase::backend_hook ngspice run_cmd] \
  log_file     [a_ans ase::backend_hook ngspice log_file] \
  result_probe [a_ans ase::backend_hook ngspice result_probe] \
  raw_file     [a_ans ase::backend_hook ngspice raw_file]]]
a_resetall
check {A2 a backend that declares only the five required hooks still registers, and asking what it can do answers that nothing is known -- never a guessed yes} \
  [list $A2REG [a_capfields zzcapfive {known}] \
        [a_capf zzcapfive appendwrite]] \
  [list zzcapfive [list 0] NOKEY-appendwrite]

## STRUCTURAL: the required-hook loop still names exactly the five. Making
## the new hook required would redden test_ase_core's hand-built five-hook
## registrations and force every future backend to write a probe before it
## may register at all.
set A3B [a_body ase::register_backend]
set A3LINE {}
foreach l [split $A3B "\n"] {
  if {[string first foreach $l] >= 0 && [string first render_deck $l] >= 0} { set A3LINE $l }
}
check {A3 STRUCTURAL the hooks a backend MUST have are still exactly the five, so a hand-built registration keeps working} \
  [list [expr {[string first {render_deck run_cmd log_file result_probe raw_file} $A3LINE] >= 0}] \
        [expr {[string first capabilities $A3LINE] >= 0}]] \
  [list 1 0]

# ============================================================================
# B. THE VERDICT IS THE RESULT, NEVER THE EXIT CODE
# ============================================================================

a_resetall
a_use ngcap-good $S_GOOD
check {B1 a build that keeps every analysis of a run is measured as keeping them, and its device numbers arrive under the names this tree reads} \
  [a_capfields ngspice {known usable appendwrite hier_op_names}] \
  [list 1 1 1 1]

a_resetall
a_use ngcap-last $S_LAST
check {B2 a build that keeps only the LAST analysis is caught -- it exits cleanly, its log says nothing, and the operating point is gone} \
  [a_capfields ngspice {known usable appendwrite}] \
  [list 1 1 0]

a_resetall
a_use ngcap-none $S_NONE
check {B3 a program that exits cleanly and produces no results at all is reported as producing nothing, and claims no ability whatever} \
  [a_capfields ngspice {known usable appendwrite blanket_op_save}] \
  [list 1 0 0 0]

a_resetall
a_use ngcap-badrc $S_BADRC
check {B4 THE INVERSION a program that exits with an error but produces the results anyway is measured on the results: the exit code is not the verdict} \
  [a_capfields ngspice {known usable appendwrite}] \
  [list 1 1 1]

a_resetall
a_use ngcap-zero $S_ZERO
check {B5 an operating point that arrives holding no data points is not counted as results -- the bogus empty answer must not read as success} \
  [a_capfields ngspice {known usable appendwrite}] \
  [list 1 1 0]

a_resetall
a_use ngcap-flat $S_FLAT
check {B6 a build whose device numbers arrive under flat names instead of the two-level ones this tree reads is caught, and separately from the keeps-every-analysis answer} \
  [a_capfields ngspice {known usable appendwrite hier_op_names}] \
  [list 1 1 1 0]

## READING THE RESULTS WHATEVER SHAPE THEY ARRIVE IN. No stub and no simulator
## here: the subject is the probe's own reader, and a written fixture is the
## only way to produce a results file of raw numbers on a box whose simulator
## writes text when it is asked to.
proc a_plotnames {p} {
  if {$p eq {NOPROC} || [string match RAISED:* $p]} { return $p }
  set out {}
  foreach pl $p { lappend out [lindex $pl 0] }
  return $out
}
set B7GOT [a_ans ase::cap_raw_plots $RAW_BINREAL]
check {B7 a build that writes its results as numbers rather than text is still read correctly, and a run of numbers that happens to spell a plot header is not mistaken for one} \
  [list [a_plotnames $B7GOT] \
        [expr {[string first ZZGHOST [a_slurp $RAW_BINREAL]] >= 0}] \
        [lindex [lindex $B7GOT 0] 1] \
        [lsearch -exact [lindex [lindex $B7GOT 0] 2] {@m.xo1.xi1.m1[gm]}]] \
  [list [list {Operating Point} {Transient Analysis}] 1 8 1]

set B8GOT [a_ans ase::cap_raw_plots $RAW_BINCPLX]
check {B8 the same when each number takes twice the room, so a reader that stepped over only half of them would report a plot that is not there} \
  [list [a_plotnames $B8GOT] \
        [expr {[string first ZZGHOST [a_slurp $RAW_BINCPLX]] >= 0}] \
        [lindex [lindex $B8GOT 0] 1]] \
  [list [list {Operating Point} {Transient Analysis}] 1 8]

# ============================================================================
# C. SAVING EVERY DEVICE AT ONCE -- the honest NO
# ============================================================================

a_resetall
a_use ngcap-c1 $S_GOOD
check {C1 a build that answers a save-every-device request with a file holding no operating point is measured as unable to do it} \
  [a_capfields ngspice {known blanket_op_save}] \
  [list 1 0]

a_resetall
a_use ngcap-c2 $S_BOP
check {C2 NON-VACUITY a build that CAN save every device at once is measured as able to, so the no above is a measurement and not a constant} \
  [a_capfields ngspice {known blanket_op_save}] \
  [list 1 1]

## STRUCTURAL: the probe really asks the question. The union of the probe
## family's bodies, so a helper cannot hide the card.
proc a_probe_src {} {
  set out {}
  set cmds [list [a_ans ase::backend_hook ngspice capabilities]]
  foreach p [info procs ::ase::cap_*] { lappend cmds $p }
  foreach p [info procs ::ase::backend::ngspice::cap*] { lappend cmds $p }
  foreach c $cmds {
    if {$c eq {NOPROC} || [string match RAISED:* $c]} { continue }
    set b [a_body $c]
    if {$b eq {NOPROC} || [string match RAISED:* $b]} { continue }
    append out $b "\n"
  }
  if {$out eq {}} { return NOPROBE }
  return $out
}
## The save card is a bracketed wildcard, which any Tcl source has to write
## with backslashes in front of the brackets or the interpreter would treat
## it as a command. Take the backslashes out before looking, or this row
## would be asking for something no Tcl file can contain.
proc a_unescape {s} { return [string map [list \\ {}] $s] }
set C3SRC [a_probe_src]
check {C3 STRUCTURAL the probe really asks the save-every-device question rather than answering it from a guess} \
  [list [expr {$C3SRC eq {NOPROBE} ? 0 : 1}] \
        [expr {$C3SRC ne {NOPROBE} && [string first {[*]} [a_unescape $C3SRC]] >= 0}]] \
  [list 1 1]

## THE REAL BUILD. Skipped loudly, never silently.
a_resetall
if {$NGREAL eq {}} {
  set C4GOT SKIP-NO-NGSPICE ; set C4EXP SKIP-NO-NGSPICE
  puts "  C4 SKIPPED: no ngspice on this box"
} else {
  a_use ngcap-real $NGREAL
  set C4GOT [a_capfields ngspice {known usable appendwrite blanket_op_save}]
  set C4EXP [list 1 1 1 0]
}
check {C4 the simulator this box actually has is measured in one go: it keeps every analysis, and it cannot save every device at once} $C4GOT $C4EXP

## STRUCTURAL: the probe asks for a results file it can read as text, in EVERY
## deck it writes and not merely the first. It is a request and not a
## requirement -- rows B7 and B8 prove the reader copes with a build that
## ignores it -- but a deck that quietly stopped asking would hand every later
## reader a file of raw numbers for no reason at all. Tied to the number of
## decks the probe emits rather than to a fixed count, so splitting or merging
## a deck cannot redden this row for a reason that is not about the subject.
set C5SRC [a_probe_src]
set C5DECKS [a_count $C5SRC {.control}]
set C5ASK [a_count [string tolower $C5SRC] {set filetype=ascii}]
check {C5 STRUCTURAL every deck the probe hands the simulator asks for a results file in plain text, not just the first one} \
  [list [expr {$C5SRC ne {NOPROBE}}] [expr {$C5DECKS >= 2}] [expr {$C5ASK == $C5DECKS}]] \
  [list 1 1 1]

# ============================================================================
# D. THE ANSWER IS WORKED OUT ONCE, AND RE-WORKED WHEN THE BUILD CHANGES
# ============================================================================

a_resetall
a_use ngcap-d1 $S_D1
set D1A [a_cap ngspice]
set D1N1 [a_runs d1]
set D1B [a_cap ngspice]
set D1N2 [a_runs d1]
check {D1 the answer is worked out once and remembered: asking twice in a row starts the program no more times, and hands back the same answer} \
  [list [expr {$D1N1 >= 1}] [expr {$D1N2 == $D1N1}] [expr {$D1A eq $D1B}] \
        [expr {$D1A eq {NOPROC} || [string match RAISED:* $D1A] ? 0 : 1}]] \
  [list 1 1 1 1]

## D2-D4 all act on ONE path, so the cache entry under test is one entry, and
## the program keeps the same recorded name however its contents change --
## which is the whole point: it is the same simulator, rebuilt.
a_resetall
a_use ngcap-d2 $S_DCACHE
set D2BEFORE [a_capf ngspice appendwrite]
## The user rebuilds their simulator in place. Nothing else happens: no
## restart, no re-registering, no button pressed.
a_stub $S_DCACHE dcache $RAW_LAST $RAW_BCONST 0 {} "# rebuilt in place\n"
file mtime $S_DCACHE [expr {[clock seconds] + 5}]
set D2AFTER [a_capf ngspice appendwrite]
check {D2 rebuilding the simulator in place is noticed with nothing for the user to do: the answer changes from keeps-every-analysis to keeps-only-the-last} \
  [list $D2BEFORE $D2AFTER] [list 1 0]

set D3N0 [a_runs dcache]
set D3SZ0 [file size $S_DCACHE]
a_stub $S_DCACHE dcache $RAW_LAST $RAW_BCONST 0 {} "# rebuilt in place\n"
file mtime $S_DCACHE [expr {[clock seconds] + 10}]
set D3ANS [a_capf ngspice appendwrite]
check {D3 a rebuild that happens to produce a file of exactly the same size is still noticed, because when it was built is part of what is remembered} \
  [list [file size $S_DCACHE] $D3SZ0 [expr {[a_runs dcache] > $D3N0}] $D3ANS] \
  [list $D3SZ0 $D3SZ0 1 0]

set D4N0 [a_runs dcache]
set D4MT [file mtime $S_DCACHE]
a_stub $S_DCACHE dcache $RAW_LAST $RAW_BCONST 0 {} "# rebuilt in place, longer\n"
file mtime $S_DCACHE $D4MT
## ASKED FIRST, COUNTED AFTER. A list built left to right would otherwise
## count the runs before the question that causes one had been asked.
set D4ANS [a_capf ngspice appendwrite]
check {D4 a rebuild whose file time did not move is still noticed, because how big the program is is part of what is remembered} \
  [list [expr {[file size $S_DCACHE] != $D3SZ0}] [file mtime $S_DCACHE] \
        [expr {[a_runs dcache] > $D4N0}] $D4ANS] \
  [list 1 $D4MT 1 0]

## Two programs at two locations, both registered, and the user switching
## between them. Neither answer may be served for the other.
a_resetall
a_ans ase::sim_register ngcap-d5a $S_D5A
a_ans ase::sim_register ngcap-d5b $S_D5B
a_ans ase::sim_select ngcap-d5a
set D5A1 [a_capf ngspice appendwrite]
set D5AN [a_runs d5a]
a_ans ase::sim_select ngcap-d5b
set D5B1 [a_capf ngspice appendwrite]
a_ans ase::sim_select ngcap-d5a
set D5A2 [a_capf ngspice appendwrite]
check {D5 two simulators at two locations never share one answer, and switching back to the first does not start it again} \
  [list $D5A1 $D5B1 $D5A2 [expr {[a_runs d5a] == $D5AN}]] \
  [list 1 0 1 1]

a_resetall
a_use ngcap-d6 $S_D6
a_cap ngspice
set D6N0 [a_runs d6]
set D6CLR [a_ans ase::sim_caps_clear]
a_cap ngspice
check {D6 there is a lever that makes the tree measure the simulator again, for a user who knows something changed} \
  [list [expr {$D6N0 >= 1}] $D6CLR [expr {[a_runs d6] > $D6N0}]] \
  [list 1 {} 1]

## THE PROGRAM THE REMEMBERED ANSWER IS ABOUT HAS GONE FROM THE DISK. This is
## reachable through the front door and it is not a curiosity: the name is
## resolved on the PATH, and Tcl remembers where it found a name the first
## time, so the tree still believes there is a program at that location after
## the file has been deleted. What must never happen is that the remembered
## answer keeps being served about a file that is no longer there.
##
## The counting stand-in is a Tcl proc rather than a program, for the reason
## section E gives: a proc that counts is the only way to SEE a measurement
## that did or did not happen.
set ::ZZD7 0
proc zz_cap_d7 {args} {
  incr ::ZZD7
  return [dict create known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1]
}
a_wr [file join $BIN zzcapvanish] "#!/bin/sh\nexit 0\n" 0755
a_ans ase::register_backend zzcapvanish [dict create \
  render_deck  [a_ans ase::backend_hook ngspice render_deck] \
  log_file     [a_ans ase::backend_hook ngspice log_file] \
  run_cmd      [a_ans ase::backend_hook ngspice run_cmd] \
  result_probe [a_ans ase::backend_hook ngspice result_probe] \
  raw_file     [a_ans ase::backend_hook ngspice raw_file] \
  capabilities zz_cap_d7]
a_resetall
set ::ZZD7 0
a_cap zzcapvanish
a_cap zzcapvanish
set D7N1 $::ZZD7
file delete -force [file join $BIN zzcapvanish]
set D7ANS [a_capfields zzcapvanish {known}]
set D7N2 $::ZZD7
check {D7 the program a remembered answer was about is deleted: the tree measures again instead of serving what it remembered about a file that is no longer there} \
  [list $D7N1 [expr {$D7N2 > $D7N1}] $D7ANS] \
  [list 1 1 [list 1]]

## THE DOUBT ARMS, DRIVEN DIRECTLY. The rule this whole section rests on is
## that ANY doubt about whether what was remembered is still true costs one
## cheap measurement, because being wrong the other way costs the user a
## silently truncated results file and no way to find out why. Row D7 above
## reaches the empty-record arm through the front door; this row drives it
## from both sides and from neither. The last two entries are the
## non-vacuity: an identical record really is trusted and a changed one
## really is not, so the first three are not green merely because the answer
## never varies.
check {D8 an empty record of what was remembered means the simulator is measured again, and only an exact match is trusted} \
  [list [a_ans ase::cap_stale {} {path /zz mtime 1 size 2}] \
        [a_ans ase::cap_stale {path /zz mtime 1 size 2} {}] \
        [a_ans ase::cap_stale {} {}] \
        [a_ans ase::cap_stale {path /zz mtime 1 size 2} {path /zz mtime 1 size 2}] \
        [a_ans ase::cap_stale {path /zz mtime 1 size 2} {path /zz mtime 9 size 2}]] \
  [list 1 1 1 0 1]

## STRUCTURAL, AND SAYING SO PLAINLY: THE SECOND DOUBT ARM CANNOT BE REACHED.
## MEASURED on this Tcl, not assumed -- handing the comparison two values and
## no options never raises, whatever those two values are, because options are
## only looked for when there are more than two. So no fixture anywhere can
## drive that arm, and a row claiming to have driven it would be claiming a
## measurement it did not take. What CAN be pinned is that the arm still
## answers measure-it-again rather than leave-it-alone, and that is what this
## row does: two arms answering 1, none answering 0, and the comparison still
## wrapped so a future value that COULD raise falls into it instead of out of
## the proc. Sabotaging either arm to answer 0 reddens this row.
set D9B [a_body ase::cap_stale]
check {D9 STRUCTURAL every doubtful case still answers measure-it-again, including the one no value can reach} \
  [list [expr {$D9B ne {NOPROC} && [a_count $D9B {return 1}] == 2}] \
        [expr {$D9B ne {NOPROC} && [a_count $D9B {return 0}] == 0}] \
        [expr {$D9B ne {NOPROC} && [a_count $D9B {catch}] >= 1}]] \
  [list 1 1 1]

# ============================================================================
# E. NEVER PROBE WHAT THE RESOLVER ALREADY REFUSED
# ============================================================================
# The counting stand-in is a Tcl proc, not a program: these two rows are
# about a probe that must NOT happen, and a proc that counts is the only way
# to see one that did.
set ::ZZPROBES 0
proc zz_cap_counting {args} {
  incr ::ZZPROBES
  return [dict create known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1]
}
foreach zzb {zzcapsim zzcapwrong} {
  a_ans ase::register_backend $zzb [dict create \
    render_deck  [a_ans ase::backend_hook ngspice render_deck] \
    run_cmd      [a_ans ase::backend_hook ngspice run_cmd] \
    log_file     [a_ans ase::backend_hook ngspice log_file] \
    result_probe [a_ans ase::backend_hook ngspice result_probe] \
    raw_file     [a_ans ase::backend_hook ngspice raw_file] \
    capabilities zz_cap_counting]
}

a_resetall
set ::ZZPROBES 0
set E1RES [a_resolved zzcapsim]
set E1ANS [a_capfields zzcapsim {known}]
check {E1 nothing registered and nothing on the PATH: the answer is that nothing is known, no program is started, and nothing is remembered about a simulator that does not exist} \
  [list $E1RES $E1ANS $::ZZPROBES [a_capcache]] \
  [list {} [list 0] 0 0]

## The arm where the resolver says no while still naming a file on the PATH
## (issue 0935). Probing that file would measure a program the resolver has
## already refused to start.
a_resetall
set ::ZZPROBES 0
a_ans ase::sim_register ngcap-e2 $S_GOOD -backend ngspice
a_ans ase::sim_select ngcap-e2
set E2OK [a_ans ase::sim_status zzcapwrong]
if {![string match RAISED:* $E2OK] && $E2OK ne {NOPROC}} {
  set E2OKV [dict get $E2OK ok] ; set E2RES [dict get $E2OK resolved]
} else { set E2OKV $E2OK ; set E2RES $E2OK }
set E2ANS [a_capfields zzcapwrong {known}]
check {E2 a choice that cannot be honoured is never measured behind the user's back, even though a program of that name does sit on the PATH} \
  [list $E2OKV [expr {$E2RES ne {}}] $E2ANS $::ZZPROBES] \
  [list 0 1 [list 0] 0]

## STRUCTURAL: two simulators that cannot be started must never be fused into
## one remembered answer.
a_resetall
set ::ZZPROBES 0
for {set i 0} {$i < 3} {incr i} {
  a_cap zzcapsim
  a_ans ase::sim_register ngcap-e3 $S_GOOD -backend ngspice
  a_ans ase::sim_select ngcap-e3
  a_cap zzcapwrong
  a_reset
}
proc a_capcache_emptykey {} {
  if {![info exists ::ase::sim_caps]} { return NOVAR }
  if {[catch {dict exists $::ase::sim_caps {}} v]} { return "RAISED:$v" }
  return [expr {$v ? 1 : 0}]
}
check {E3 STRUCTURAL nothing is remembered under a nameless location, so two simulators that cannot be started can never be fused into one answer} \
  [list [a_capcache] [a_capcache_emptykey] $::ZZPROBES] \
  [list 0 0 0]

# ============================================================================
# F. WHAT THE USER IS TOLD -- never a silent failure, never a nag
# ============================================================================

a_resetall
a_use ngcap-f1 $S_F1
set F1 [a_report ngspice 2]
check {F1 a run with two analyses on a build that keeps only the last one says exactly one thing, and the Simulators window can read back the very same sentence} \
  [list [a_rep_n $F1] \
        [expr {[a_rep_msg $F1] ne {} && [a_rep_msg $F1] eq [a_rep_rec $F1]}] \
        [expr {[string first $S_F1 [a_rep_msg $F1]] >= 0}] [a_rep_rv $F1]] \
  [list 1 1 1 cap_no_append]

## SAID NOTHING, not "there was nothing that could say anything". The
## returned kind is asserted too, so a tree with no say-site at all cannot
## satisfy a row about a say-site that chose to keep quiet.
set F2 [a_report ngspice 1]
check {F2 the same build with only one analysis to run says nothing at all, because nothing is lost} \
  [list [a_rep_n $F2] [a_rep_rec $F2] [a_rep_rv $F2]] [list 0 {} {}]

a_resetall
a_use ngcap-f3 $S_F3
set F3 [a_report ngspice 1]
check {F3 a program that produced no results at all on the tiny test circuit is reported even when there is only one analysis -- never a silent failure} \
  [list [a_rep_n $F3] [expr {[string first $S_F3 [a_rep_msg $F3]] >= 0}] [a_rep_rv $F3]] \
  [list 1 1 cap_not_a_simulator]

a_resetall
a_use ngcap-f4 $S_F4
set F4 [a_report ngspice 2]
check {F4 a build that keeps everything says nothing at all} \
  [list [a_rep_n $F4] [a_rep_rec $F4] [a_rep_rv $F4]] [list 0 {} {}]

## PLAIN ENGLISH, scanned rather than eyeballed. The user's own words -- the
## simulator name and the location -- come out first, because they may
## legitimately contain anything.
proc a_plain {m name path} {
  if {$m eq {} || $m eq {NOPROC} || [string match RAISED:* $m]} { return NOSENTENCE }
  set m [string map [list $name {} $path {}] $m]
  foreach tok {auto_execok ase:: sim_ $::ASE_ dict} {
    if {[string first $tok $m] >= 0} { return "JARGON-$tok" }
  }
  foreach tok {appendwrite remzerovec plotname vector subckt rawfile} {
    if {[string first $tok [string tolower $m]] >= 0} { return "JARGON-$tok" }
  }
  if {[string first {ok 0} $m] >= 0} { return JARGON-state }
  return PLAIN
}
set F5P /some/where/ngspice
set F5A [a_ans ase::sim_why cap_no_append ngspice $F5P]
set F5B [a_ans ase::sim_why cap_not_a_simulator ngspice $F5P]
set F5FALL [a_ans ase::sim_why zz_no_such_kind ngspice $F5P]
check {F5 both new sentences are plain English, they are two different sentences, they name the program, and neither is the catch-all sentence} \
  [list [a_plain $F5A ngspice $F5P] [a_plain $F5B ngspice $F5P] \
        [expr {$F5A ne $F5B}] \
        [expr {[string first $F5P $F5A] >= 0}] [expr {[string first $F5P $F5B] >= 0}] \
        [expr {$F5A ne $F5FALL}] [expr {$F5B ne $F5FALL}]] \
  [list PLAIN PLAIN 1 1 1 1 1]

## STRUCTURAL: each fixed phrase the user reads exists in exactly one place,
## so no caller re-words what the mint already said. Same technique as row D6
## of tests/headless/test_ase_simreg_0931.tcl.
set F6SRC [a_nocomment [a_slurp $ASETCL]]
set F6N 0 ; set F6ALLONE 1
foreach m [list $F5A $F5B] {
  if {$m eq {} || $m eq {NOPROC} || [string match RAISED:* $m]} { set F6ALLONE 0 ; continue }
  ## The catch-all sentence is not one of these two, and counting ITS words
  ## would let a tree that never wrote either sentence pass this row.
  if {$m eq $F5FALL} { set F6ALLONE 0 ; continue }
  set chunks [list $m]
  foreach word [list ngspice $F5P] {
    if {$word eq {}} { continue }
    set next {}
    foreach c $chunks { foreach piece [split [string map [list $word \x01] $c] \x01] { lappend next $piece } }
    set chunks $next
  }
  foreach c $chunks {
    set c [string trim $c]
    if {[string length $c] < 25} { continue }
    incr F6N
    if {[a_count $F6SRC $c] != 1} { set F6ALLONE 0 }
  }
}
check {F6 STRUCTURAL each fixed phrase of the two new sentences exists in exactly one place in the source} \
  [list [expr {$F6N >= 2}] $F6ALLONE] [list 1 1]

## The report is NOT in the command builder. run_cmd's answer and its echo
## behaviour are pinned byte for byte by test_ase_simreg_0931 row D4.
a_resetall
a_use ngcap-f7 $S_LAST
set F7DECK [file join $scratch f7.spice]
a_wr $F7DECK "* deck\n.end\n"
proc a_f7_do {deck} { set ::a_f7 [a_ans ase::backend::ngspice::run_cmd {} $deck] }
set F7SAID [a_echoed [list a_f7_do $F7DECK]]
check {F7 the command that starts the simulator is unchanged, and building it says nothing new to the user} \
  [list $::a_f7 [llength $F7SAID]] \
  [list [list $S_LAST -b $F7DECK 2>@1] 0]

## STRUCTURAL: THE WARNING BELONGS TO THE RUN. It is raised where the run is
## started and nowhere else, and the two ends are asserted together because
## either one alone is blind. Row F7 above can only see a command builder that
## SAYS something; it cannot see the warning disappearing out of the run,
## which is the whole feature's single wire to the user. Moving it from the
## one place to the other reddens this row at both ends.
set F8RUN [a_body ase::run_deck]
set F8CMD [a_body ase::backend::ngspice::run_cmd]
check {F8 STRUCTURAL the warning is raised where the run is started and nowhere else, so it cannot be refactored out of the only place the user meets it} \
  [list [expr {$F8RUN ne {NOPROC} && [string first cap_report $F8RUN] >= 0}] \
        [expr {$F8RUN ne {NOPROC} && [string first n_enabled_analyses $F8RUN] >= 0}] \
        [expr {$F8CMD ne {NOPROC} && [string first cap_report $F8CMD] >= 0}] \
        [expr {$F8CMD ne {NOPROC} && [string first sim_capabilities $F8CMD] >= 0}]] \
  [list 1 1 0 0]

## BEHAVIOURAL, THROUGH THE FRONT DOOR. Every row above this one measures the
## simulator or mints the sentence; this is the only row that STARTS A RUN the
## way pressing Run does and watches the sentence arrive in the CIW. Without
## it the entire feature could be wired to nothing at all and every other row
## in this file would still be green.
##
## The run really launches the stub and is waited for, so nothing is left
## running behind the test. The count is of the ONE sentence under test, not
## of everything said: a run has other perfectly good things to say.
set F9NL [file join $scratch f9.spice]
a_wr $F9NL "** sch_path: /zz.sch\n**.subckt zzcell\nV1 a 0 1\n**.ends\n.end\n"
proc a_rundeck_do {nan} {
  global scratch F9NL
  set st [ase::state_default]
  dict set st design {lib zzlib cell zzcell view schematic}
  dict set st rundir [file join $scratch f9run]
  dict set st simulator ngspice
  if {$nan == 2} {
    dict set st analyses {{type op enabled 1} {type tran enabled 1 step 1n stop 5n}}
  } else {
    dict set st analyses {{type tran enabled 1 step 1n stop 5n}}
  }
  set ::a_rd_rc [catch {ase::run_deck $st $F9NL} ::a_rd_id]
  if {$::a_rd_rc == 0 && [string is integer -strict $::a_rd_id]} {
    catch {ase::wait $::a_rd_id}
  }
}
proc a_rundeck {name path nan} {
  a_resetall
  a_ans ase::sim_register $name $path
  a_ans ase::sim_select $name
  set ::a_rd_rc RAISED-BEFORE-RUN
  set ::a_rd_id {}
  set said [a_echoed [list a_rundeck_do $nan]]
  set msgs {}
  foreach s $said { lappend msgs [lindex $s 1] }
  return [list $::a_rd_rc $msgs]
}
proc a_saidtimes {msgs want} {
  set n 0
  foreach m $msgs { if {$m eq $want} { incr n } }
  return $n
}
set F9BAD  [a_rundeck ngcap-f9a $S_F1 2]
set F9GOOD [a_rundeck ngcap-f9b $S_F4 2]
check {F9 starting a real run on a build that keeps only the last analysis puts the warning in the CIW exactly once, and the same run on a build that keeps everything says nothing} \
  [list [lindex $F9BAD 0] \
        [a_saidtimes [lindex $F9BAD 1] [a_ans ase::sim_why cap_no_append ngspice $S_F1]] \
        [lindex $F9GOOD 0] \
        [a_saidtimes [lindex $F9GOOD 1] [a_ans ase::sim_why cap_no_append ngspice $S_F4]]] \
  [list 0 1 0 0]

# ============================================================================
# G. THE PROBE MUST NOT DISTURB ANYTHING
# ============================================================================

check {G1 LAZY nothing was measured at startup: before this test started anything, the tree held no remembered answer and no program had been run} \
  [list $G1CACHE $G1COUNT] [list 0 0]

## STRUCTURAL: the probe reads its own results file itself and never asks the
## results database the waveform viewer has attached (ruling 0881).
set G2SRC [a_probe_src]
set G2STRUCT [expr {$G2SRC ne {NOPROBE} && [string first {xschem raw} $G2SRC] < 0}]
if {$G2SRC eq {NOPROBE}} { set G2STRUCT NOPROBE }
## The behavioural half: a results file attached, a probe run, the attached
## list of signals unchanged.
set G2BEH NOSUBJ
if {![catch {xschem raw read $RAW_BOTH op} g2r] && $g2r == 1} {
  set g2before [a_ans xschem raw list]
  a_resetall
  a_use ngcap-g2 $S_G2
  a_cap ngspice
  set g2after [a_ans xschem raw list]
  set G2BEH [expr {$g2before eq $g2after && $g2before ne {} ? 1 : 0}]
  catch {xschem raw clear}
} else {
  puts "  G2 behavioural half has no subject: this build cannot attach a results file here"
}
set G2BEHEXP [expr {$G2BEH eq {NOSUBJ} ? {NOSUBJ} : 1}]
check {G2 the probe reads its own results and never disturbs the results the waveform viewer is showing} \
  [list $G2STRUCT $G2BEH] [list 1 $G2BEHEXP]

a_resetall
a_use ngcap-g3 $S_WAIT
set G3T0 [clock milliseconds]
set G3ANS [a_capfields ngspice {known usable}]
set G3MS [expr {[clock milliseconds] - $G3T0}]
## THE STRUCTURAL HALF IS NOT DECORATION HERE, AND THAT IS A MEASUREMENT.
## Whether the behavioural half above can see this guard at all depends on
## what the program that launched this test had on its OWN input: a launcher
## whose input is already finished gives the waiting program nothing to wait
## for, and the row then goes green with the guard deleted. Seen both ways on
## this box -- red at twenty seconds from a shell whose input is live, green in
## a third of a second from one whose input is finished. So the redirect is
## asserted where no launcher can hide it either.
set G3B [a_body ase::cap_run]
set G3STRUCT [expr {$G3B ne {NOPROC} && [string first {< $nul} $G3B] >= 0 \
                    && [string first /dev/null $G3B] >= 0}]
check {G3 a program that sits waiting for something to be typed at it cannot hang the run: it is given nothing to read, the answer comes back at once, and it is that the program produced nothing} \
  [list $G3ANS [expr {$G3MS < 3000}] $G3STRUCT] \
  [list [list 1 0] 1 1]

a_resetall
a_use ngcap-g4 $S_G4
set G4DIR [a_ans ase::cap_workdir]
a_cap ngspice
if {$G4DIR eq {NOPROC} || [string match RAISED:* $G4DIR]} {
  set G4N1 $G4DIR ; set G4N2 $G4DIR ; set G4IN 0
} else {
  set G4N1 [llength [glob -nocomplain -directory $G4DIR *]]
  a_ans ase::sim_caps_clear
  a_cap ngspice
  set G4N2 [llength [glob -nocomplain -directory $G4DIR *]]
  set G4IN [string match [file normalize $scratch]* [file normalize $G4DIR]]
}
check {G4 measuring the simulator twice leaves the same number of files behind: the probe overwrites its scratch files instead of piling them up} \
  [list [expr {$G4N1 ne {NOPROC} && $G4N1 >= 1}] [expr {$G4N2 eq $G4N1}] $G4IN] \
  [list 1 1 1]

## THE OTHER HALF OF THE HANG BELT. Row G3 covers a program that stops to read
## something typed at it. This one covers a program that simply never comes
## back for any other reason at all -- a licence check that never answers, a
## file system that has gone away, a loop with no way out. Nothing in the run
## is waiting on what the measurement has to say, so the user's Run must not
## wait on it either.
set G5TO [lindex [auto_execok timeout] 0]
set G5DECK [file join $scratch g5.sp]
a_wr $G5DECK "* deck\n.end\n"
if {$G5TO eq {}} {
  puts "  G5 SKIPPED: this box has no way to put a wall-clock cap on a program"
  set G5GOT [list SKIP-NO-CAP [expr {[string first timeout [a_body ase::cap_run]] >= 0}]]
  set G5EXP [list SKIP-NO-CAP 1]
} else {
  set G5SLEEP [file join $BIN sim_stuck]
  ## The shell REPLACES itself with the waiting program, so the cap has one
  ## process to stop and nothing is left holding the output open behind it.
  a_wr $G5SLEEP "#!/bin/sh\nexec sleep 30\n" 0755
  set G5T0 [clock milliseconds]
  set G5ANS [a_ans ase::cap_run $G5SLEEP {} $G5DECK]
  set G5MS [expr {[clock milliseconds] - $G5T0}]
  ## Over five seconds proves the program really did stick, so a stand-in that
  ## returned at once could not make this row green by accident. Under
  ## twenty-five proves something cut it off well before its thirty.
  set G5GOT [list [expr {$G5ANS ne {NOPROC} && ![string match RAISED:* $G5ANS]}] \
                  [expr {$G5MS > 5000}] [expr {$G5MS < 25000}]]
  set G5EXP [list 1 1 1]
}
check {G5 a program that never comes back at all cannot hang the run: it is given a fixed number of seconds and then the answer arrives anyway} $G5GOT $G5EXP

## THE PROGRAM IS MEASURED THE WAY IT WILL BE STARTED. A user who registers a
## build together with extra arguments -- a mode switch, a licence server, a
## model path -- would otherwise have the tree measure the program in one mode
## and start it in another, and the sentence the CIW showed them would be
## about a program that is not the one they get.
set G6LOG [file join $scratch probe_args.log]
set S_G6 [a_stub [file join $BIN sim_g6] g6 $RAW_BOTH $RAW_BCONST 0 \
            "echo \"\$@\" >> $G6LOG"]
a_resetall
file delete -force $G6LOG
a_ans ase::sim_register ngcap-g6 $S_G6 -args {-zzcapargprobe}
a_ans ase::sim_select ngcap-g6
set G6ANS [a_capfields ngspice {known usable appendwrite}]
set G6WITH [expr {[string first -zzcapargprobe [a_slurp $G6LOG]] >= 0}]
a_resetall
file delete -force $G6LOG
a_use ngcap-g6b $S_G6
a_cap ngspice
set G6WITHOUT [expr {[string first -zzcapargprobe [a_slurp $G6LOG]] >= 0}]
check {G6 the extra arguments a user registered with their simulator are handed to it when it is measured too, so what was measured is the program they will actually get} \
  [list $G6WITH $G6WITHOUT $G6ANS] \
  [list 1 0 [list 1 1 1]]

# ============================================================================
# H. NOTHING ELSE MOVED
# ============================================================================

proc h_state {an} {
  global scratch
  set st [ase::state_default]
  dict set st design {lib zzlib cell zzcell view schematic}
  dict set st rundir [file join $scratch hrun]
  dict set st analyses $an
  return $st
}
set HNL "** sch_path: /zz.sch\n**.subckt zzcell\nV1 a 0 1\n**.ends\n.end\n"
set HREND [a_ans ase::backend_hook ngspice render_deck]
proc h_counts {an} {
  global HREND HNL
  if {$HREND eq {NOPROC} || [string match RAISED:* $HREND]} { return NOPROC }
  if {[catch {$HREND [h_state $an] $HNL} d]} { return "RAISED:$d" }
  set na 0 ; set nw 0
  foreach l [split $d "\n"] {
    set t [string trim $l]
    if {$t eq {set appendwrite}} { incr na }
    if {[string match {write *} $t]} { incr nw }
  }
  return [list $na $nw]
}
set HOP   {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
set HTR   {{type op enabled 0} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 5n}}
set HBOTH {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 5n}}
check {H1 the deck the simulator is handed did not change, and the count of analyses the report leans on is the same count the deck itself uses} \
  [list [h_counts $HOP] [h_counts $HTR] [h_counts $HBOTH] \
        [a_ans ase::n_enabled_analyses [h_state $HOP]] \
        [a_ans ase::n_enabled_analyses [h_state $HTR]] \
        [a_ans ase::n_enabled_analyses [h_state $HBOTH]]] \
  [list [list 1 1] [list 1 1] [list 1 2] 1 1 2]

set H2OK 1
foreach h {render_deck run_cmd log_file result_probe raw_file} {
  set p [a_ans ase::backend_hook ngspice $h]
  if {[string match RAISED:* $p] || $p eq {NOPROC} || [info commands $p] eq {}} { set H2OK 0 }
}
check {H2 the five hooks a backend must have still resolve, and the simulator the user can pick from the list is still there} \
  [list $H2OK [expr {[lsearch -exact [a_ans ase::backend_names] ngspice] >= 0}]] \
  [list 1 1]

} zzerr]} {
  puts "FATAL: uncaught error: $zzerr"
  puts "$::errorInfo"
  incr fail
}

# --- teardown ----------------------------------------------------------------
a_resetall
set ::env(PATH) $PATHSAVE
if {$NDSAVE eq {ZZUNSET}} { catch {unset ::netlist_dir} } else { set ::netlist_dir $NDSAVE }

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
