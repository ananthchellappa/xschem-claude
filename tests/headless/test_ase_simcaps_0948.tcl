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
#      results go, RELATIVE TO THE PROGRAM'S OWN CURRENT DIRECTORY. Issue
#      0949: the name on that line is a bare file name and the program is
#      started with the probe's folder under it, which is the only form
#      measured to survive a space, a dollar, a bracket, a quote or a
#      semicolon in the simulation folder's name. The stub needs no change for
#      that -- it copies to whatever the line says, and it now runs with the
#      probe's folder as its own -- but a reader who believed the old wording
#      would look for an absolute path that is no longer there. Rows Z2 and Z3
#      still hand the stub a deck naming an absolute file by hand, which also
#      works, because the stub simply obeys the line;
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
## The folder this suite was started in, read while it is still certainly a
## real one. Row K4 puts the process back here before it measures, because a
## probe that failed to come back leaves `pwd` answering the empty string and
## two empty strings compare equal -- see K4's own note.
set A_HOME [file normalize [pwd]]
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

## 0952's MEASURED SHAPE -- a build that adds every analysis to the one
## results file exactly as it was asked to, but spells its device parameters
## differently. Nothing the probe saved matches, so the operating point
## degenerates to a constants-only plot and no plot in the file is called
## "Operating Point" at all. The S3a crew measured this file's real twin:
## TWO plots, constants with one point and Transient Analysis with the rest,
## i.e. THE WRITES APPENDED. Whether they appended and whether the device
## names are the ones this tree reads are two different questions, and this
## fixture is the one shape where the answers differ.
set RAW_CONSTTR [file join $scratch raw_consttr.raw]
a_wr $RAW_CONSTTR "$CONSTHDR$TITLE$TRHDR"

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
set S_RENAME  [a_stub [file join $BIN sim_rename]  rename  $RAW_CONSTTR $RAW_BCONST 0]
set S_D10     [a_stub [file join $BIN sim_d10]     d10     $RAW_BOTH $RAW_BCONST 0]
set S_D11     [a_stub [file join $BIN sim_d11]     d11     $RAW_BOTH $RAW_BCONST 0]

# ============================================================================
# THE WORD-FAITHFUL STUB -- a stand-in that reads its deck the way the real
# simulator on this box was measured to read it
# ============================================================================
# The ordinary stub above takes EVERYTHING after `write ` as one file name,
# which is far more forgiving than any real simulator. Measured first-hand on
# ngspice-46+ by the S3a crew, six write forms across five hostile folder
# names: given `write /a/b c/probe_a.raw` the real program reads the SECOND
# whitespace word as a VECTOR name, finds no such vector, prints
#     Error during 'write': no writable vector found.
# and writes nothing anywhere -- the probe directory afterwards holds
# probe_a.sp and probe_b.sp and no results file at all. A dollar sign, a
# single quote or a semicolon in the name kills it the same way, a square
# bracket does not, and NO quoting form inside the deck rescues the dollar
# because the program expands it regardless of quoting.
#
# This stub reproduces exactly that column of the measured table, so section K
# can prove the defect on a box with no simulator installed on it at all. Row
# K3 runs the same folder names through the REAL program, because a stub can
# never prove another program's parser.
set STUBSTRICT {#!/bin/sh
echo @MARK@ >> @COUNT@
deck=
for a in "$@"; do
  if [ -f "$a" ]; then deck="$a"; fi
done
if [ -z "$deck" ]; then exit @RC@; fi
@WAIT@
line=`grep -E '^[[:blank:]]*write[[:blank:]]' "$deck" | head -1 | sed -e 's/^[[:blank:]]*write[[:blank:]][[:blank:]]*//' -e 's/[[:blank:]]*$//'`
nw=`printf '%s\n' "$line" | wc -w`
out=
if [ "$nw" -eq 1 ]; then
  case "$line" in
    *'$'*) out= ;;
    *"'"*) out= ;;
    *';'*) out= ;;
    *) out="$line" ;;
  esac
fi
if [ -z "$out" ]; then
  echo "Error during 'write': no writable vector found."
  exit @RC@
fi
src=@NORMAL@
if grep -q '\[\*\]' "$deck"; then src=@BLANKET@; fi
if [ "$src" != NONE ] && [ -f "$src" ]; then cat "$src" > "$out"; fi
exit @RC@
}
proc a_stub_strict {path mark normal blanket rc {wait {}}} {
  global STUBSTRICT COUNT
  a_wr $path [string map [list @MARK@ $mark @COUNT@ $COUNT @NORMAL@ $normal \
                               @BLANKET@ $blanket @RC@ $rc @WAIT@ $wait] \
                $STUBSTRICT] 0755
  return $path
}
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

## The number of seconds the whole measurement is allowed, READ BEFORE ANY ROW
## LOWERS IT. Section J lowers it so a stuck program can be measured cheaply,
## so the shipped default has to be captured up here or row J1 would report
## whatever the last row set.
set J1BUDGET [expr {[info exists ::ase::cap_budget_ms] ? $::ase::cap_budget_ms : {NOVAR}}]
proc a_budget_set {ms} { set ::ase::cap_budget_ms $ms }

## --- the simulation folder, moved around and put back ------------------------
## Several rows below need the probe to run with a DIFFERENT simulation folder
## under it -- a fresh one nothing has littered, one whose name has a space in
## it, one nothing may be written into. ::netlist_dir is the documented global
## set_netlist_dir 0 answers with, and no new variable is invented here.
set NDBASE [file join $scratch simdir]
proc a_nd {dir} {
  file mkdir $dir
  set ::netlist_dir $dir
  return [set_netlist_dir 0]
}
## Everything under a folder, deepest last, so a row can say "nothing was left
## behind" and name what was.
proc a_entries {dir} {
  set out {}
  foreach f [glob -nocomplain -directory $dir -tails -types {f d l} * .*] {
    if {$f eq {.} || $f eq {..}} { continue }
    lappend out $f
  }
  return [lsort $out]
}
proc a_walk {dir} {
  set out {}
  if {![file isdirectory $dir]} { return $out }
  foreach f [a_entries $dir] {
    lappend out $f
    set p [file join $dir $f]
    if {[file isdirectory $p]} {
      foreach sub [a_walk $p] { lappend out [file join $f $sub] }
    }
  }
  return $out
}
## What a place the probe was handed looks like: it has to exist, be inside the
## simulation folder, and arrive EMPTY.
proc a_dirstate {d root} {
  if {$d eq {NOPROC} || [string match RAISED:* $d]} { return NOANSWER }
  if {$d eq {}} { return NOPLACE }
  if {![file isdirectory $d]} { return NOTADIR }
  if {![string match "[file normalize $root]/*" [file normalize $d]]} { return OUTSIDE }
  if {[llength [a_entries $d]]} { return NOTEMPTY }
  return EMPTY
}

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
## RESTATED FOR ISSUE 0952. The subject is unchanged -- an operating point
## that arrives holding no data points must not read as success -- but it has
## moved into the key that owns it. Whether the writes APPENDED is decided by
## whether a second plot arrived in the one file, which it did; whether this
## tree can read any device numbers out of the operating point is a different
## question, and a plot with no data points in it holds none. Letting the
## empty operating point answer the append question is what told a healthy
## build to "run one analysis at a time" in issue 0952.
check {B5 an operating point that arrives holding no data points is not counted as device numbers this tree can read, while the two analyses it arrived alongside are still counted as having been added to the one file} \
  [a_capfields ngspice {known usable appendwrite hier_op_names}] \
  [list 1 1 1 0]

a_resetall
a_use ngcap-flat $S_FLAT
check {B6 a build whose device numbers arrive under flat names instead of the two-level ones this tree reads is caught, and separately from the keeps-every-analysis answer} \
  [a_capfields ngspice {known usable appendwrite hier_op_names}] \
  [list 1 1 1 0]

## ISSUE 0952. A build that adds every analysis to the one results file
## exactly as asked, but spells its device parameters differently. Measured by
## the S3a crew on a stand-in that was the real ngspice with only the save
## card's device path rewritten: the results file held TWO plots, a constants
## plot with one point and a Transient Analysis plot with fifty-nine -- the
## writes appended -- and the tree reported it as a build that keeps only the
## last analysis. Two different questions, and neither may be allowed to fail
## the other.
a_resetall
a_use ngcap-rename $S_RENAME
check {B9 a build that adds every analysis to the one results file but spells its device parameters differently is measured as adding them, and separately as not using the names this tree reads} \
  [a_capfields ngspice {known usable appendwrite hier_op_names}] \
  [list 1 1 1 0]

## THE SAY-SITE HALF. Without this row the verdict above could be right in the
## answer and still wrong at the user, which is where the whole defect lives:
## the sentence was a wrong diagnosis AND advice that changes nothing, because
## running one analysis at a time would not make the device names readable.
a_resetall
a_use ngcap-rename2 $S_RENAME
set B10 [a_report ngspice 2]
check {B10 and that build is not told to run one analysis at a time: nothing is said about it, and the record the Simulators window reads back is empty} \
  [list [a_rep_rv $B10] [a_rep_n $B10] [a_rep_rec $B10]] \
  [list {} 0 {}]

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

## ISSUE 0950(b) -- THERE HAS TO BE A DOOR. Measured: a wrong answer taken in
## a folder the simulator could not write into was then served for the whole
## session, in an ordinary folder, with nothing in the Simulators window able
## to clear it -- grep -c sim_caps_clear src/ase_window.tcl was 0. Adding or
## editing an entry is the user saying something about their simulators
## changed, and it is the moment the tree must look again.
a_resetall
a_use ngcap-d10 $S_D10
set D10N0 [a_runs d10]
a_cap ngspice
set D10N1 [a_runs d10]
## Exactly what the Edit gesture does: the same name, pointed at the same
## place. If only a CHANGED path re-measured, the user who rebuilt in place
## and re-saved the entry would still be served the stale answer.
a_ans ase::sim_register ngcap-d10 $S_D10
a_cap ngspice
set D10N2 [a_runs d10]
check {D10 adding or editing an entry in the simulator list makes the tree measure the program again} \
  [list [expr {$D10N1 > $D10N0}] [expr {$D10N2 > $D10N1}]] \
  [list 1 1]

## The removal arm, isolated: the entry removed is NOT the one in force, so
## nothing here can be satisfied by the registration arm above.
a_resetall
a_ans ase::sim_register ngcap-d11a $S_D11
a_ans ase::sim_register ngcap-d11b $S_GOOD
a_ans ase::sim_select ngcap-d11a
set D11N0 [a_runs d11]
a_cap ngspice
set D11N1 [a_runs d11]
a_ans ase::sim_unregister ngcap-d11b
a_cap ngspice
set D11N2 [a_runs d11]
check {D11 removing an entry from the simulator list does the same} \
  [list [expr {$D11N1 > $D11N0}] [expr {$D11N2 > $D11N1}]] \
  [list 1 1]

## STRUCTURAL: ONE DOOR, NOT TWO. The Simulators window and the Command window
## are two ways in to the SAME registry writer, and the look-again belongs on
## the writer. Put it in the dialog instead and the Command window's door is
## still broken, and that file's own rule -- no logic is re-implemented here --
## is broken with it. This row reddens on that placement, which no behavioural
## row can see.
set D12DLG [a_body ase::ui::simdlg_ok]
set D12REG [a_body ase::sim_register]
set D12UNR [a_body ase::sim_unregister]
check {D12 STRUCTURAL the Simulators window reaches the same registry writer the Command window does, and the look-again is on the writer} \
  [list [expr {$D12DLG ne {NOPROC} && [string first sim_register $D12DLG] >= 0}] \
        [expr {$D12REG ne {NOPROC} && [string first sim_caps_clear $D12REG] >= 0}] \
        [expr {$D12UNR ne {NOPROC} && [string first sim_caps_clear $D12UNR] >= 0}]] \
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
##
## THE SENTENCE IS TAKEN APART AT THE VALUES THAT GET SUBSTITUTED INTO IT,
## because a location dropped into the middle of a sentence leaves a fragment
## of itself glued to the words in front of it that no source line can match.
proc a_chunks {m words} {
  set chunks [list $m]
  foreach word $words {
    if {$word eq {}} { continue }
    set next {}
    foreach c $chunks {
      foreach piece [split [string map [list $word \x01] $c] \x01] { lappend next $piece }
    }
    set chunks $next
  }
  set out {}
  foreach c $chunks {
    set t [string trim $c]
    if {[string length $t] >= 25} { lappend out $t }
  }
  return $out
}
## ...AND THEN AT ITS OWN SENTENCE ENDINGS, WHICH IS NOT A REFINEMENT. A
## sabotage pass measured the coarse grain alone and it is not enough: with
## only whole runs of fixed text counted, one clause of either new sentence
## could be pasted verbatim into a second real `set` in src/ase.tcl and all
## 76 checks stayed green. Copying HALF a sentence into a second call site or
## a dialog is the realistic breach of ruling D5-4; copying all of it is not.
proc a_phrases {m words} {
  set out [a_chunks $m $words]
  foreach c [a_chunks $m $words] {
    foreach piece [split $c "."] {
      set t [string trim $piece]
      if {[string length $t] >= 25 && $t ne $c} { lappend out $t }
    }
  }
  return $out
}
set F6SRC [a_nocomment [a_slurp $ASETCL]]
set F6N 0 ; set F6ALLONE 1 ; set F6FINER 0
foreach m [list $F5A $F5B] {
  if {$m eq {} || $m eq {NOPROC} || [string match RAISED:* $m]} { set F6ALLONE 0 ; continue }
  ## The catch-all sentence is not one of these two, and counting ITS words
  ## would let a tree that never wrote either sentence pass this row.
  if {$m eq $F5FALL} { set F6ALLONE 0 ; continue }
  set F6WORDS [list ngspice $F5P]
  set F6PH [a_phrases $m $F6WORDS]
  incr F6FINER [expr {[llength $F6PH] - [llength [a_chunks $m $F6WORDS]]}]
  foreach c $F6PH {
    incr F6N
    if {[a_count $F6SRC $c] != 1} { set F6ALLONE 0 }
  }
}
check {F6 STRUCTURAL each fixed phrase of the two new sentences, and each sentence inside those phrases, exists in exactly one place in the source} \
  [list [expr {$F6N >= 2}] $F6ALLONE [expr {$F6FINER >= 2}]] [list 1 1 1]

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

## RESTATED FOR ISSUE 0951. The old expectation was "the same number of files
## as last time, and at least one" -- which a probe that overwrites a shared,
## fixed set of names satisfies perfectly, and which is exactly the shape that
## let one process's results answer for another process's program. Measured by
## the S3a crew: after a probe the user's own simulation folder was left
## holding probe_a.raw, probe_a.sp and probe_b.sp. The probe's workings are
## nobody's deliverable and must not outlive the measurement.
##
## A FRESH simulation folder, so what is counted is this row's own litter and
## not the pile every earlier row left in the shared one.
set G4ND [file join $scratch g4simdir]
file delete -force $G4ND
a_nd $G4ND
a_resetall
a_use ngcap-g4 $S_G4
set G4N0 [a_runs g4]
a_cap ngspice
a_ans ase::sim_caps_clear
a_cap ngspice
## Two measurements, two decks each: four starts. Without this the row would
## go green on a tree that never ran the program at all.
set G4RAN [expr {[a_runs g4] - $G4N0}]
set G4LEFT [a_walk $G4ND]
a_nd $NDBASE
check {G4 measuring the simulator twice leaves nothing at all behind in the user's simulation folder: the place the probe wrote is gone once it has finished} \
  [list [expr {$G4RAN >= 4}] $G4LEFT] \
  [list 1 {}]

## THE OTHER HALF OF THE HANG BELT. Row G3 covers a program that stops to read
## something typed at it. This one covers a program that simply never comes
## back for any other reason at all -- a licence check that never answers, a
## file system that has gone away, a loop with no way out. Nothing in the run
## is waiting on what the measurement has to say, so the user's Run must not
## wait on it either.
## RESTATED FOR ISSUE 0953. The number of seconds was a literal buried in the
## runner, so nothing could ask for fewer and no caller could find out that a
## program had been cut off -- measured, the runner hands back the catch code
## and throws away the only place the truth survived, so a program cut off at
## ten seconds is indistinguishable from one that failed instantly. The caller
## says how long, and gets told whether it ran out.
set G5TO [lindex [auto_execok timeout] 0]
set G5WD [file join $scratch g5wd]
file mkdir $G5WD
set G5DECK [file join $G5WD g5.sp]
a_wr $G5DECK "* deck\n.end\n"
set G5SLEEP [file join $BIN sim_stuck]
## The shell REPLACES itself with the waiting program, so the cap has one
## process to stop and nothing is left holding the output open behind it.
a_wr $G5SLEEP "#!/bin/sh\nexec sleep 30\n" 0755
proc a_capran {ans} {
  if {$ans eq {NOPROC} || [string match RAISED:* $ans]} { return $ans }
  if {[llength $ans] < 4} { return "SHORT-[llength $ans]:$ans" }
  return OK
}
proc a_capcut {ans} {
  if {[a_capran $ans] ne {OK}} { return NOANSWER }
  return [lindex $ans 2]
}
if {$G5TO eq {}} {
  puts "  G5 SKIPPED LOUDLY: this box has no way to put a wall-clock cap on a program"
  set G5GOT [list SKIP-NO-CAP [expr {[string first timeout [a_body ase::cap_run]] >= 0}]]
  set G5EXP [list SKIP-NO-CAP 1]
} else {
  set G5T0 [clock milliseconds]
  set G5ANS [a_ans ase::cap_run $G5SLEEP [list -b $G5DECK] $G5WD 3]
  set G5MS [expr {[clock milliseconds] - $G5T0}]
  ## Over two seconds proves the program really did stick, so a stand-in that
  ## returned at once could not make this row green by accident. Under ten
  ## proves it was cut off at the number of seconds it was GIVEN and not at
  ## some larger number of somebody else's choosing.
  set G5GOT [list [a_capran $G5ANS] [a_capcut $G5ANS] \
                  [expr {$G5MS > 2000}] [expr {$G5MS < 10000}]]
  set G5EXP [list OK 1 1 1]
}
check {G5 a program that never comes back at all cannot hang the run: it is cut off at the number of seconds it was given, and the caller is told that is what happened} $G5GOT $G5EXP

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
# I. THE PROBE'S OWN SCRATCH AREA -- ISSUE 0951
# ============================================================================
# Measured by the S3a crew on the built binary: the probe wrote its results to
# a FIXED path, <simulation folder>/.ase_probe/probe_a.raw, shared by every
# process on the box. A registered program that was literally
#     #!/bin/sh
#     sleep 3
#     exit 0
# and that wrote NOT ONE BYTE was reported as
#     known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
# and the Command window said nothing at all, because a separate process
# dropped a healthy results file at that name one second into the probe. That
# is a false yes about a program that did nothing, and the deck emitter picks
# what it writes from exactly these answers, so a false yes here becomes a
# blank annotation on the user's schematic later -- issue 0929's symptom all
# over again, arriving through a new door.
#
# Two guards, and they are guards against different things. A place of its own
# per measurement means no other process can be writing where this one reads.
# Not trusting a results file this run did not see appear means a name that
# collides anyway -- a recycled process number, a predecessor that died
# without tidying up -- still cannot answer.

proc a_dictf {d key} {
  if {$d eq {NOPROC} || [string match RAISED:* $d]} { return $d }
  if {[catch {dict exists $d $key} h]} { return "NOTADICT:$d" }
  if {!$h} { return "NOKEY-$key" }
  return [dict get $d $key]
}

set I1ND [file join $scratch i1simdir]
file delete -force $I1ND
a_nd $I1ND
set I1A [a_ans ase::cap_workdir]
set I1B [a_ans ase::cap_workdir]
set I1AS [a_dirstate $I1A $I1ND]
set I1BS [a_dirstate $I1B $I1ND]
set I1DIFF [expr {$I1A ne $I1B}]
set I1D1 [a_ans ase::cap_workdir_done $I1A]
set I1D2 [a_ans ase::cap_workdir_done $I1B]
set I1LEFT [a_walk $I1ND]
a_nd $NDBASE
check {I1 the place the probe writes is a different place every time it is asked for, it arrives empty, and it is given back cleanly} \
  [list $I1AS $I1BS $I1DIFF \
        [expr {$I1D1 ne {NOPROC} && ![string match RAISED:* $I1D1]}] \
        [expr {$I1D2 ne {NOPROC} && ![string match RAISED:* $I1D2]}] \
        $I1LEFT] \
  [list EMPTY EMPTY 1 1 1 {}]

## A PROBE THAT BLOWS UP STILL TIDIES UP. The error must still reach the
## caller -- a defect in a probe has to stay loud -- and the user's simulation
## folder must be exactly as it was.
proc zz_cap_raiser {args} { return -code error "zz probe blew up" }
a_ans ase::register_backend zzcaprai [dict create \
  render_deck  [a_ans ase::backend_hook ngspice render_deck] \
  run_cmd      [a_ans ase::backend_hook ngspice run_cmd] \
  log_file     [a_ans ase::backend_hook ngspice log_file] \
  result_probe [a_ans ase::backend_hook ngspice result_probe] \
  raw_file     [a_ans ase::backend_hook ngspice raw_file] \
  capabilities zz_cap_raiser]
set I3ND [file join $scratch i3simdir]
file delete -force $I3ND
a_nd $I3ND
a_resetall
a_ans ase::sim_register ngcap-i3 $S_GOOD -backend zzcaprai
a_ans ase::sim_select ngcap-i3
set I3BEFORE [a_walk $I3ND]
set I3ANS [a_cap zzcaprai]
set I3AFTER [a_walk $I3ND]
a_nd $NDBASE
check {I3 a probe that blows up still leaves nothing behind, and the failure still reaches the caller} \
  [list [expr {[string match {RAISED:*zz probe blew up*} $I3ANS] ? 1 : 0}] \
        $I3AFTER] \
  [list 1 $I3BEFORE]

## THE ROW ISSUE 0951 ASKS FOR, THROUGH THE FRONT DOOR. A plausible healthy
## results file is planted at the OLD fixed name. A program that writes not one
## byte must still be reported as producing nothing -- and the planted file,
## which belongs to somebody else, must still be sitting there untouched
## afterwards. Measured today: the probe deletes it.
set I4ND [file join $scratch i4simdir]
file delete -force $I4ND
a_nd $I4ND
set I4PLANT [file join $I4ND .ase_probe probe_a.raw]
a_wr $I4PLANT [a_slurp $RAW_BOTH]
a_resetall
a_use ngcap-i4 $S_NONE
set I4ANS [a_capfields ngspice {known usable appendwrite}]
set I4STILL [expr {[file exists $I4PLANT] \
                   && [a_slurp $I4PLANT] eq [a_slurp $RAW_BOTH]}]
a_nd $NDBASE
check {I4 a healthy results file left at the old shared name by somebody else does not answer for a program that wrote nothing, and is not destroyed either} \
  [list $I4ANS $I4STILL] \
  [list [list 1 0 0] 1]

## THE BELT, AND THE ONLY ROW THAT CAN SEE IT. Row I4 is answered by the place
## being private; this one hands the probe a place that is NOT private, with
## results already sitting in it under the names it uses, and a program that
## writes nothing. The answer must still be that nothing was produced, and the
## files that were already there must survive: the probe may neither believe a
## results file it did not see appear, nor delete one it did not create.
set I5WD [file join $scratch i5wd]
file delete -force $I5WD
file mkdir $I5WD
set I5RA [file join $I5WD probe_a.raw]
set I5RB [file join $I5WD probe_b.raw]
a_wr $I5RA [a_slurp $RAW_BOTH]
a_wr $I5RB [a_slurp $RAW_BOP]
set I5ANS [a_ans ase::backend::ngspice::capabilities $S_NONE {} $I5WD]
set I5KEPT [expr {[file exists $I5RA] && [file exists $I5RB] \
                  && [a_slurp $I5RA] eq [a_slurp $RAW_BOTH] \
                  && [a_slurp $I5RB] eq [a_slurp $RAW_BOP]}]
check {I5 results already sitting in the place the probe was handed cannot answer for the program being measured, and are not thrown away either} \
  [list [a_dictf $I5ANS usable] [a_dictf $I5ANS appendwrite] $I5KEPT] \
  [list 0 0 1]

## STRUCTURAL, AND NOTHING BEHAVIOURAL ON THIS BOX CAN REACH THE SECOND HALF.
## A folder `file mkdir` has just made is writable here, so only a filesystem
## that answers otherwise -- a default ACL, a mount that went read-only under
## us -- gets past the make and fails the writability test. A sabotage pass
## deleted that half and no row noticed. It is still the difference between
## the probe having somewhere to write and the PROGRAM being blamed for a
## folder's fault, which is issue 0949's category error, so it is pinned by
## reading the body rather than by a fixture nobody on this box can build.
set I6B [a_body ase::cap_workdir]
check {I6 STRUCTURAL a place the probe is handed is accepted only after it is checked to be a folder AND to be one that can be written into} \
  [list [expr {$I6B ne {NOPROC} && ![string match RAISED:* $I6B]}] \
        [expr {[string first {file isdirectory $d} $I6B] >= 0}] \
        [expr {[string first {file writable $d} $I6B] >= 0}]] \
  [list 1 1 1]

# ============================================================================
# J. A PROGRAM THAT DOES NOT ANSWER IN TIME -- ISSUE 0953
# ============================================================================
# Measured: a stub that was slow to start blocked the editor for 20.0 seconds
# and was then called not a simulator. Two wrongs in one gesture. The 20.0 is
# two runs each paying a ten-second cap that nothing could ask to be smaller,
# and the sentence claims something the probe never established -- it found out
# that the program had not finished, which is not the same claim as "this is
# not a circuit simulator". A healthy probe costs 0.014 seconds cold and
# nothing at all warm, so the bound can be generous and never be felt.

check {J1 the number of seconds the whole measurement is allowed is a real and generous number} \
  [list $J1BUDGET \
        [expr {$J1BUDGET ne {NOVAR} && [string is integer -strict $J1BUDGET] \
               && $J1BUDGET > 0}]] \
  [list 30000 1]

## A PROGRAM THAT IGNORES THE POLITE STOP IS STILL CUT OFF. Measured on this
## box: `timeout 3` on a program that traps the polite stop lets it run its
## full thirty seconds, while `timeout -k 2 3` ends it at five. Without the
## grace the bound is not a bound at all for that program.
if {$G5TO eq {}} {
  puts "  J3 SKIPPED LOUDLY: this box has no way to put a wall-clock cap on a program"
  set J3GOT SKIP-NO-CAP ; set J3EXP SKIP-NO-CAP
} elseif {[catch {exec $G5TO -k 1 1 true}]} {
  puts "  J3 SKIPPED LOUDLY: the wall-clock cap on this box has no way to insist"
  set J3GOT SKIP-NO-GRACE ; set J3EXP SKIP-NO-GRACE
} else {
  set S_J3 [file join $BIN sim_termproof]
  a_wr $S_J3 "#!/bin/sh\ntrap '' TERM\ni=0\nwhile \[ \$i -lt 60 ]; do sleep 0.5; i=\$((i+1)); done\nexit 0\n" 0755
  set J3T0 [clock milliseconds]
  set J3ANS [a_ans ase::cap_run $S_J3 [list -b $G5DECK] $G5WD 3]
  set J3MS [expr {[clock milliseconds] - $J3T0}]
  set J3GOT [list [a_capran $J3ANS] [expr {$J3MS > 2000}] [expr {$J3MS < 12000}]]
  set J3EXP [list OK 1 1]
}
check {J3 a program that ignores the polite stop is still cut off} $J3GOT $J3EXP

## NON-VACUITY for G5 and J3: a program that answers normally is NOT reported
## as having been cut off, so "was it cut off" is a measurement and not a
## constant that happens to read the way those two rows want.
set J4T0 [clock milliseconds]
set J4ANS [a_ans ase::cap_run $S_GOOD [list -b $G5DECK] $G5WD 10]
set J4MS [expr {[clock milliseconds] - $J4T0}]
check {J4 a program that answers normally is not reported as having been cut off} \
  [list [a_capran $J4ANS] [a_capcut $J4ANS] [expr {$J4MS < 5000}]] \
  [list OK 0 1]

## THE SENTENCE. A simulator that did not answer in time must not be called
## "not a simulator" -- and the answer must carry NO capability keys at all,
## because "we never found out" and "we found out, and the answer is no" are
## different things and a reader that confused them would put a fabricated
## claim about the user's program on their screen.
set S_SLOW [file join $BIN sim_slow]
a_wr $S_SLOW "#!/bin/sh\nexec sleep 30\n" 0755
a_budget_set 3000
a_resetall
a_use ngcap-j5 $S_SLOW
set J5R [a_report ngspice 1]
set J5F [a_capfields ngspice {known usable}]
set J5MSG [a_rep_msg $J5R]
set J5NOTSIM [a_ans ase::sim_why cap_not_a_simulator ngspice $S_SLOW]
set J5FALL [a_ans ase::sim_why zz_no_such_kind ngspice $S_SLOW]
check {J5 a simulator that did not answer in time is told about as one that did not answer in time, and is never called not a simulator} \
  [list $J5F [a_rep_rv $J5R] [a_rep_n $J5R] \
        [expr {[string first $S_SLOW $J5MSG] >= 0}] \
        [expr {$J5MSG ne $J5NOTSIM}] [expr {$J5MSG ne $J5FALL}]] \
  [list [list 0 NOKEY-usable] cap_no_answer 1 1 1 1]

## ONE BOUND FOR THE WHOLE MEASUREMENT, NOT ONE PER RUN. This is the row that
## measures the difference between the 20.0 seconds the crew reproduced and
## the number the user was actually promised.
a_budget_set 3000
a_resetall
a_use ngcap-j6 $S_SLOW
set J6T0 [clock milliseconds]
a_cap ngspice
set J6MS [expr {[clock milliseconds] - $J6T0}]
## ⚠ THE UPPER BOUND IS TIED TO THE BUDGET THIS ROW ITSELF SET, and the old
## one was not. A sabotage pass gave each run the full budget instead of the
## shared deadline -- the exact pre-fix shape -- and this row stayed green:
## shipped 3003 ms, sabotaged 6003 ms, against a bound of 9000. A clean
## doubling sailed through. 5100 is 1.7x the budget: it passes at 3003 and
## fails at 6003. Rows J11 and J12 below pin the same guard by COUNTING, which
## is what a timing band can never do on its own.
check {J6 the whole measurement is bounded once, not each run inside it separately} \
  [list [expr {$J6MS > 1500}] [expr {$J6MS < 5100}]] \
  [list 1 1]

## AN ANSWER THAT COULD NOT BE WORKED OUT IS NOT REMEMBERED. Issue 0950's
## first half, reached through 0953's door: the wrong answer stuck for the
## rest of the session because a failure of the RUN was cached as if it were
## a fact about the PROGRAM.
set S_J7 [file join $BIN sim_j7]
a_wr $S_J7 "#!/bin/sh\necho j7 >> $COUNT\nexec sleep 30\n" 0755
a_budget_set 3000
a_resetall
a_use ngcap-j7 $S_J7
set J7N0 [a_runs j7]
a_cap ngspice
set J7N1 [a_runs j7]
a_cap ngspice
set J7N2 [a_runs j7]
set J7CACHE [a_capcache]
check {J7 an answer that could not be worked out is not remembered, so asking again starts the program again} \
  [list [expr {$J7N1 > $J7N0}] [expr {$J7N2 > $J7N1}] $J7CACHE] \
  [list 1 1 0]

## A SIMULATION FOLDER NOTHING CAN BE WRITTEN INTO IS A FACT ABOUT THE FOLDER.
## Blaming the program for it is issue 0949's category error wearing different
## clothes, and remembering the blame is issue 0950's.
a_budget_set 30000
set J8ND [file join $scratch j8simdir]
file delete -force $J8ND
file mkdir $J8ND
catch {file attributes $J8ND -permissions 0555}
if {[file writable $J8ND]} {
  puts "  J8 SKIPPED LOUDLY: a folder that cannot be written into could not be made here"
  set J8GOT SKIP-NO-READONLY ; set J8EXP SKIP-NO-READONLY
} else {
  a_nd $J8ND
  a_resetall
  a_use ngcap-j8 $S_GOOD
  set J8R [a_report ngspice 2]
  set J8F [a_capfields ngspice {known usable}]
  set J8CACHE [a_capcache]
  a_nd $NDBASE
  catch {file attributes $J8ND -permissions 0755}
  set J8GOT [list $J8F [a_rep_n $J8R] $J8CACHE]
  set J8EXP [list [list 0 NOKEY-usable] 0 0]
}
check {J8 a simulation folder nothing can be written into answers that nothing is known, instead of accusing the program} $J8GOT $J8EXP

## The sentence itself, held to the same standard as the two the file already
## has: plain English, it names the program, it is its own sentence, and it is
## not the catch-all.
set J9P /some/where/slowsim
set J9S [a_ans ase::sim_why cap_no_answer ngspice $J9P 7]
check {J9 the did-not-answer sentence is plain English, names the program, and is not one of the sentences that were already there} \
  [list [a_plain $J9S ngspice $J9P] [expr {$J9S ne $F5A}] [expr {$J9S ne $F5B}] \
        [expr {[string first $J9P $J9S] >= 0}] [expr {$J9S ne $F5FALL}]] \
  [list PLAIN 1 1 1 1]

## STRUCTURAL, the F6 technique applied to the third sentence: every fixed
## phrase of it exists in exactly one place, so no caller re-words what the
## mint already said (ruling D5-4).
set J10S [a_ans ase::sim_why cap_no_answer ngspice $F5P zzsecsmark]
set J10N 0 ; set J10ALLONE 1 ; set J10FINER 0
if {$J10S eq {} || $J10S eq {NOPROC} || [string match RAISED:* $J10S] \
    || $J10S eq $F5FALL} {
  set J10ALLONE 0
} else {
  set J10WORDS [list ngspice $F5P zzsecsmark]
  set J10PH [a_phrases $J10S $J10WORDS]
  set J10FINER [expr {[llength $J10PH] - [llength [a_chunks $J10S $J10WORDS]]}]
  foreach c $J10PH {
    incr J10N
    if {[a_count $F6SRC $c] != 1} { set J10ALLONE 0 }
  }
}
check {J10 STRUCTURAL each fixed phrase of the did-not-answer sentence, and each sentence inside those phrases, exists in exactly one place in the source} \
  [list [expr {$J10N >= 1}] $J10ALLONE [expr {$J10FINER >= 2}]] [list 1 1 1]

## ⚠ ONCE A RUN HAS BEEN CUT OFF, NOTHING MORE IS ASKED OF THE PROGRAM. This
## row COUNTS PROGRAM STARTS, because a sabotage pass proved that counting
## seconds cannot see this: give each run the full budget and attempt the
## second run anyway -- the exact shape the 20.0 second freeze had -- and the
## wait merely doubles, which row J6's band was too wide to notice. A start is
## a whole number and doubling it is unmissable.
set S_J11 [file join $BIN sim_j11]
a_wr $S_J11 "#!/bin/sh\necho j11 >> $COUNT\nexec sleep 30\n" 0755
a_budget_set 1000
a_resetall
a_use ngcap-j11 $S_J11
set J11N0 [a_runs j11]
set J11ANS [a_cap ngspice]
set J11N [expr {[a_runs j11] - $J11N0}]
check {J11 a measurement whose first run was cut off starts the program once and never asks it again} \
  [list $J11N [a_dictf $J11ANS known] [a_dictf $J11ANS unmeasured]] \
  [list 1 0 timeout]

## AND THE BUDGET IS ONE BUDGET, NOT ONE PER RUN -- the behavioural half of
## the same guard, and the half a start count cannot see. This stand-in
## ANSWERS, correctly and completely, but takes two seconds over it. Under one
## shared three-second budget the first run leaves the second one a single
## second and the second run is cut off. Under a budget handed out afresh to
## each run the second would get three seconds, finish comfortably, and the
## measurement would come back `known 1` -- which is what makes this row the
## one that tells the two shapes apart.
set S_J12 [a_stub [file join $BIN sim_j12] j12 $RAW_BOTH $RAW_BCONST 0 {sleep 2}]
a_budget_set 3000
a_resetall
a_use ngcap-j12 $S_J12
set J12N0 [a_runs j12]
set J12ANS [a_cap ngspice]
set J12N [expr {[a_runs j12] - $J12N0}]
check {J12 one budget covers every run of a measurement, so a first run that eats most of it leaves the second run only what is left} \
  [list $J12N [a_dictf $J12ANS known] [a_dictf $J12ANS unmeasured]] \
  [list 2 0 timeout]

## ⚠ THE NUMBER OF SECONDS THE USER IS TOLD THEY WAITED IS A MEASUREMENT, NOT
## A CONSTANT -- ruling D5-1, on a number that goes in front of the user. A
## sabotage pass replaced the whole body of the counter with `return 999` and
## all seventy-six checks stayed green while the Command window told a user who
## had waited three seconds that their program had not finished after 999.
##
## The last reading is the one that keeps the sentence honest the other way:
## the cap is handed to the program in WHOLE seconds, so a program that is cut
## off always comes back a few milliseconds PAST it. Rounding those few
## milliseconds up to a whole extra second made a thirty-second budget say 31,
## every time, and 30 became a number the sentence could never print.
check {J13 the number of seconds a measurement is said to have taken is read off the clock, a real part-second still counts as a whole one, and a few milliseconds past a whole second do not} \
  [list [a_ans ase::cap_spent [expr {[clock milliseconds] - 5000}]] \
        [a_ans ase::cap_spent [expr {[clock milliseconds] - 12000}]] \
        [a_ans ase::cap_spent [expr {[clock milliseconds] - 3200}]] \
        [a_ans ase::cap_spent [expr {[clock milliseconds] - 30005}]] \
        [a_ans ase::cap_spent [clock milliseconds]]] \
  [list 5 12 4 30 1]

## AND THE NUMBER THAT REACHED THE COMMAND WINDOW IS THAT MEASUREMENT. J13
## pins the counter; this pins that the sentence the user actually read in row
## J5 -- a real cut-off, on a real three-second budget, through the front door
## -- carries what the counter said about THEIR wait and not a number chosen
## anywhere else.
##
## WHERE THE NUMBER SITS IS ASKED OF THE MINT, NOT WRITTEN DOWN HERE. The
## sentence is rendered once with a marker where the number goes; the words
## on either side of that marker are what the number is fished out from. So a
## reworded sentence moves this row with it instead of stranding it.
proc a_between {m pre suf} {
  if {[string first $pre $m] != 0} { return NOPRE }
  set rest [string range $m [string length $pre] end]
  if {$suf eq {}} { return $rest }
  set at [string last $suf $rest]
  if {$at < 0} { return NOSUF }
  return [string trim [string range $rest 0 [expr {$at - 1}]]]
}
set J14MARK zzsecsmark
set J14TPL [a_ans ase::sim_why cap_no_answer ngspice $S_SLOW $J14MARK]
set J14AT [string first $J14MARK $J14TPL]
if {$J14AT < 0} {
  set J14N NOMARK
} else {
  set J14PRE [string range $J14TPL 0 [expr {$J14AT - 1}]]
  set J14SUF [string range $J14TPL [expr {$J14AT + [string length $J14MARK]}] end]
  set J14N [a_between $J5MSG $J14PRE $J14SUF]
}
if {[string is integer -strict $J14N]} {
  set J14KIND IS-A-NUMBER
  set J14BAND [expr {$J14N >= 2 && $J14N <= 4}]
} else {
  set J14KIND "NOT-A-NUMBER:$J14N"
  set J14BAND 0
}
check {J14 the sentence the user reads carries the number of seconds they actually waited} \
  [list $J14KIND $J14BAND] [list IS-A-NUMBER 1]

## ⚠ A PROGRAM THAT CHOOSES THE CAP'S OWN EXIT CODE, ON ITS OWN, INSTANTLY, IS
## NOT ONE THAT WAS CUT OFF. ase::cap_run's own header claims this and a
## sabotage pass proved no row could see it: delete the elapsed-time arm of the
## cut-off test and a program that exits 124 in one millisecond is announced to
## the user as one that "had still not finished with it after 1 seconds".
if {$G5TO eq {}} {
  puts "  J15 SKIPPED LOUDLY: this box has no way to put a wall-clock cap on a program, so nothing can be reported as cut off"
  set J15GOT SKIP-NO-CAP ; set J15EXP SKIP-NO-CAP
} else {
  set S_J15 [file join $BIN sim_j15]
  a_wr $S_J15 "#!/bin/sh\nexit 124\n" 0755
  set J15ANS [a_ans ase::cap_run $S_J15 [list -b $G5DECK] $G5WD 3]
  set J15GOT [list [a_capran $J15ANS] [a_capcut $J15ANS] \
                   [expr {[a_capran $J15ANS] eq {OK} && [lindex $J15ANS 3] < 1500}]]
  set J15EXP [list OK 0 1]
}
check {J15 a program that chooses the cap's own exit code on its own, instantly, is not reported as one that was cut off} $J15GOT $J15EXP

## ⚠ AND A PROGRAM THAT GENUINELY FAILED JUST BEFORE THE CAP RAN OUT IS NOT
## ONE EITHER. The other arm of the same test, and the other thing no row could
## see: delete the exit-code arm and a program that failed at 2.903 seconds
## under a three-second cap is reported to the user as one that had still not
## finished -- a false statement about their program, which is the whole class
## issues 0949 and 0953 exist to stop.
##
## THE WINDOW IS NARROW BY CONSTRUCTION -- the failure has to land in the last
## quarter-second before the cap, or the elapsed-time arm alone would already
## answer "not cut off" and the row would prove nothing. Measured on this box
## the landing is stable to about five milliseconds; it is retried rather than
## trusted, and it says so out loud if the box could not manage it.
if {$G5TO eq {}} {
  puts "  J16 SKIPPED LOUDLY: this box has no way to put a wall-clock cap on a program, so nothing can be reported as cut off"
  set J16GOT SKIP-NO-CAP ; set J16EXP SKIP-NO-CAP
} else {
  set S_J16 [file join $BIN sim_j16]
  a_wr $S_J16 "#!/bin/sh\nsleep 2.85\nexit 3\n" 0755
  set J16GOT SKIP-NO-WINDOW ; set J16EXP SKIP-NO-WINDOW
  for {set J16I 0} {$J16I < 3} {incr J16I} {
    set J16ANS [a_ans ase::cap_run $S_J16 [list -b $G5DECK] $G5WD 3]
    if {[a_capran $J16ANS] ne {OK}} { break }
    set J16MS [lindex $J16ANS 3]
    if {$J16MS >= 2750 && $J16MS < 3000} {
      set J16GOT [list IN-THE-LAST-QUARTER-SECOND [a_capcut $J16ANS] [lindex $J16ANS 0]]
      set J16EXP [list IN-THE-LAST-QUARTER-SECOND 0 1]
      break
    }
  }
  if {$J16GOT eq {SKIP-NO-WINDOW}} {
    puts "  J16 SKIPPED LOUDLY: this box could not land a failing program inside the last quarter-second before the cap"
  }
}
check {J16 a program that genuinely failed just before the cap ran out is not reported as one that was cut off} $J16GOT $J16EXP

# ============================================================================
# K. A SIMULATION FOLDER WHOSE NAME IS AWKWARD -- ISSUE 0949
# ============================================================================
# Measured, same session, same healthy ngspice, only the folder changed: a
# folder called `plain` answered known 1 usable 1 appendwrite 1 and said
# nothing, while `with space` and `do$llar` both answered usable 0 and put a
# FALSE sentence in the Command window about a working simulator --
#   "...produced no results at all when it was tried on a tiny test circuit.
#    Check that it really is a circuit simulator..."
# The mechanism is not a truncated path. The program reads the second word of
# the results line as a vector name, finds none, and writes nothing anywhere.
# Six write forms were measured against five hostile folder names and NO
# quoting form inside the deck covers them all -- the only form that produced
# the file for a space, a dollar, a bracket, a quote and a semicolon alike is
# giving the program the target folder as its own current directory and naming
# the results file with a bare name.

set HOSTILE [file join $scratch hostile]
file mkdir $HOSTILE
set S_K1 [a_stub_strict [file join $BIN sim_k1] k1 $RAW_BOTH $RAW_BCONST 0]

## The control first: the SAME stand-in in an ordinary folder. Without it a red
## K1 could be about the stand-in rather than about the folder's name.
set K1PLAINND [file join $HOSTILE plain]
file delete -force $K1PLAINND
a_nd $K1PLAINND
a_resetall
a_use ngcap-k1a $S_K1
set K1CTRL [a_capfields ngspice {known usable appendwrite}]

set K1ND [file join $HOSTILE {with space}]
file delete -force $K1ND
a_nd $K1ND
a_resetall
a_use ngcap-k1b $S_K1
set K1F [a_capfields ngspice {known usable appendwrite}]
set K1SAID [a_report ngspice 2]
a_nd $NDBASE
check {K1 a simulation folder whose name has a space in it measures the same healthy answer as an ordinary one, and nothing is said about the simulator} \
  [list $K1CTRL $K1F [a_rep_n $K1SAID]] \
  [list [list 1 1 1] [list 1 1 1] 0]

## The rest of the measured table, each name reported by name so a red says
## which one. A square bracket is in the list because the real program was
## measured to survive it -- a fix that only escaped whitespace would pass the
## bracket and fail the other three.
set K2NAMES [list {do$llar} {br[ack]et} {quo'te} {semi;colon}]
set K2GOT {} ; set K2EXP {}
foreach nm $K2NAMES {
  set d [file join $HOSTILE $nm]
  file delete -force $d
  a_nd $d
  a_resetall
  a_use ngcap-k2 $S_K1
  lappend K2GOT [list $nm [a_capfields ngspice {known usable appendwrite}]]
  lappend K2EXP [list $nm [list 1 1 1]]
}
a_nd $NDBASE
check {K2 the same for a folder named with a dollar, a bracket, a quote or a semicolon} $K2GOT $K2EXP

## THE REAL PROGRAM. A stand-in can prove what this tree hands the simulator;
## it can never prove another program's own parser, and the parser is where
## issue 0949 lives. Skips loudly rather than quietly on a box with no
## simulator on it.
set K3NG [lindex [auto_execok ngspice] 0]
if {$K3NG eq {}} {
  puts "  K3 SKIPPED LOUDLY: there is no ngspice on this box to measure"
  set K3GOT SKIP-NO-SIM ; set K3EXP SKIP-NO-SIM
} else {
  set K3GOT {} ; set K3EXP {}
  foreach nm [list plainish {with space} {do$llar}] {
    set d [file join $HOSTILE ng-$nm]
    file delete -force $d
    a_nd $d
    a_resetall
    a_use ngcap-k3 $K3NG
    lappend K3GOT [list $nm [a_capfields ngspice {known usable appendwrite}]]
    lappend K3EXP [list $nm [list 1 1 1]]
  }
  a_nd $NDBASE
}
check {K3 the simulator this box actually has measures the same in a folder whose name has a space or a dollar in it as in an ordinary one} $K3GOT $K3EXP

## THE PROGRAM IS STARTED WITH THE PROBE'S OWN FOLDER UNDER IT, and the folder
## the rest of the editor was working in is put back afterwards -- on the path
## where the probe worked and on the path where it did not.
set K4LOG [file join $scratch k4pwd.log]
set S_K4  [a_stub [file join $BIN sim_k4]  k4  $RAW_BOTH $RAW_BCONST 0 "pwd >> $K4LOG"]
set S_K4B [a_stub [file join $BIN sim_k4b] k4b NONE      NONE        1 "pwd >> $K4LOG"]
set K4ND [file join $scratch k4simdir]
file delete -force $K4ND
a_nd $K4ND
a_resetall
file delete -force $K4LOG
a_use ngcap-k4 $S_K4
## ⚠ THE PROCESS IS PUT SOMEWHERE REAL FIRST, AND THE FOLDER IT COMES BACK
## TO HAS TO STILL EXIST. Comparing two readings of `pwd` is NOT enough and a
## sabotage pass proved it: with the restore deleted from ase::cap_run this row
## stayed GREEN, because an earlier probe had already left the process sitting
## in a folder that was then removed, and Tcl's `pwd` answers the EMPTY STRING
## for both readings once that has happened. Two empty strings compare equal,
## so the half of the row that names the defect was vacuous under the defect.
catch {cd $A_HOME}
set K4PWD0 [pwd]
a_cap ngspice
set K4PWD1 [pwd]
set K4PROBE [file normalize [file join $K4ND .ase_probe]]
set K4LINES {}
foreach l [split [a_slurp $K4LOG] "\n"] {
  set l [string trim $l]
  if {$l ne {}} { lappend K4LINES $l }
}
set K4UNDER [expr {[llength $K4LINES] >= 2}]
foreach l $K4LINES {
  if {![string match "$K4PROBE*" [file normalize $l]]} { set K4UNDER 0 }
}
a_resetall
file delete -force $K4LOG
a_use ngcap-k4b $S_K4B
catch {cd $A_HOME}
set K4PWD2 [pwd]
a_cap ngspice
set K4PWD3 [pwd]
catch {cd $A_HOME}
a_nd $NDBASE
## A reading that is a folder which still EXISTS. The empty string is what
## `pwd` answers after the folder underneath the process has been deleted,
## and it is the reading this row must never accept as a match.
proc a_realdir {p} { return [expr {($p ne {} && [file isdirectory $p]) ? 1 : 0}] }
check {K4 the program is started with the probe's own folder under it, and the folder the editor was working in is a real one it is put back into afterwards} \
  [list $K4UNDER [a_realdir $K4PWD0] [a_realdir $K4PWD1] [expr {$K4PWD1 eq $K4PWD0}] \
        [a_realdir $K4PWD2] [a_realdir $K4PWD3] [expr {$K4PWD3 eq $K4PWD2}]] \
  [list 1 1 1 1 1 1 1]

## A program named by a relative location is still found after the folder
## changes underneath it. Without this the fix for 0949 would break every user
## who registered their simulator as ./build/ngspice.
set K5WD [file join $scratch k5wd]
file delete -force $K5WD
file mkdir $K5WD
set K5DECK [file join $K5WD k5.sp]
a_wr $K5DECK "* deck\n.control\nwrite k5out.raw\n.endc\n.end\n"
set K5PWD [file normalize [pwd]]
set K5REL {}
if {[string first "$K5PWD/" [file normalize $S_GOOD]] == 0} {
  set K5REL [string range [file normalize $S_GOOD] [expr {[string length $K5PWD] + 1}] end]
}
if {$K5REL eq {}} {
  puts "  K5 SKIPPED LOUDLY: the stand-in simulator is not below the folder this test was started from, so no relative location names it"
  set K5GOT SKIP-NO-RELPATH ; set K5EXP SKIP-NO-RELPATH
} else {
  set K5N0 [a_runs good]
  set K5ANS [a_ans ase::cap_run $K5REL [list -b $K5DECK] $K5WD 10]
  set K5GOT [list [a_capran $K5ANS] [expr {[a_runs good] > $K5N0}] \
                  [file exists [file join $K5WD k5out.raw]]]
  set K5EXP [list OK 1 1]
}
check {K5 a program named by a relative location is still found after the folder changes under it} $K5GOT $K5EXP

## STRUCTURAL, and no behavioural row can see it once the folder is right: the
## deck names its results with a bare file name and no folder in it. That is
## the only form measured to survive every hostile folder name, and a deck that
## quietly went back to an absolute name would pass every row above.
set K6LOG [file join $scratch k6deck.log]
set S_K6 [a_stub [file join $BIN sim_k6] k6 $RAW_BOTH $RAW_BCONST 0 "cat \"\$deck\" >> $K6LOG"]
set K6ND [file join $scratch k6simdir]
file delete -force $K6ND
a_nd $K6ND
a_resetall
file delete -force $K6LOG
a_use ngcap-k6 $S_K6
a_cap ngspice
a_nd $NDBASE
set K6W 0 ; set K6BARE 1
foreach l [split [a_slurp $K6LOG] "\n"] {
  set t [string trim $l]
  if {![string match {write *} $t]} { continue }
  incr K6W
  set arg [string trim [string range $t 6 end]]
  if {[string first / $arg] >= 0} { set K6BARE 0 }
  if {[string first \\ $arg] >= 0} { set K6BARE 0 }
}
check {K6 STRUCTURAL every results line in every deck the probe hands the simulator names a bare file, with no folder in it} \
  [list [expr {$K6W >= 3}] $K6BARE] \
  [list 1 1]

# ============================================================================
# M. THE SHARED RUNNER BELONGS TO NO ONE SIMULATOR -- ISSUE 0954
# ============================================================================
# The batch-mode flag is one program's spelling. Carried in the shared runner
# it is inherited by every backend that is ever added, including ones for which
# it means something else or nothing at all.

proc a_hasbflag {b} {
  if {$b eq {NOPROC} || [string match RAISED:* $b]} { return NOBODY }
  return [expr {[regexp {(?:^|\s)-b(?:\s|$)} $b] ? 1 : 0}]
}
check {M1 STRUCTURAL the shared probe runner carries no flag that belongs to one simulator, and the simulator's own probe carries it instead} \
  [list [a_hasbflag [a_body ase::cap_run]] \
        [a_hasbflag [a_body ase::backend::ngspice::capabilities]]] \
  [list 0 1]

## And the flag still reaches the program. Without this row, deleting it from
## both places would leave M1 green while every simulation stopped running in
## batch mode.
set M2LOG [file join $scratch m2args.log]
set S_M2 [a_stub [file join $BIN sim_m2] m2 $RAW_BOTH $RAW_BCONST 0 "echo \"\$@\" >> $M2LOG"]
a_resetall
file delete -force $M2LOG
a_use ngcap-m2 $S_M2
a_cap ngspice
set M2HAS 0
foreach l [split [a_slurp $M2LOG] "\n"] {
  if {[catch {llength $l}]} { continue }
  if {[lsearch -exact $l -b] >= 0} { set M2HAS 1 }
}
check {M2 the batch-mode flag still reaches the program that is measured} \
  [list $M2HAS] [list 1]

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


# ----------------------------------------------------------------------------
# H3 -- READING A RESULTS FILE'S HEADER MUST NOT MEAN READING THE WHOLE FILE
# ----------------------------------------------------------------------------
# WHY THIS ROW EXISTS NOW. The run report that tells the user how many devices
# were asked for and how many came back has to read the Operating Point plot's
# variable list out of the results file. The only reader in the tree for that
# is ase::cap_raw_plots, and it pulls the ENTIRE file into memory first.
#
# MEASURED, on the shipped sky130_tests_ase/tb_bandgap bench: the results file
# is 69,595,016 bytes with the device requests scoped to the operating point,
# and was 144,455,860 bytes before they were. This box has about 7.8 GB. And
# the plot the report needs is the LAST one in the file, so no read of the
# first few kilobytes can find it -- the reader must step over the numbers,
# which is exactly what its own `Binary:` arithmetic already knows how to do.
#
# The behavioural half of this row passes today, on the slurp. That is the
# recorded reason the structural half is not optional: nothing a suite can
# observe goes red when a reader quietly loads 69 MB to read 40 lines.
#
# ⚠ THE STRUCTURAL HALF ASKS FOR THE MECHANISM, NOT FOR ONE SPELLING. It used
# to look for the nine literal characters of a bracketed whole-file read, which
# a slurp written any other way walked straight past. It now requires: no
# whole-file read of the handle AT ALL, at least one line-at-a-time read, and
# at least one skip over a block of numbers -- which is the property the row is
# actually about.
set H3RAW [file join $scratch raw_oplast.raw]
a_wrbin $H3RAW "$TITLE$BINTRH[a_numblock [expr {3 * 2 * 8}] {} 0]$TITLE$BINOPH[a_numblock [expr {8 * 3 * 8}] $ZZGHOST 8]"
set H3GOT [a_ans ase::cap_raw_plots $H3RAW]
set H3BODY [a_body ase::cap_raw_plots]
check {H3 the plot a report needs is the LAST one in the results file, and the\
 reader finds it by stepping over the numbers rather than by loading a file\
 that is 69 MB on the user's own bench} \
  [list [a_plotnames $H3GOT] \
        [lindex [lindex $H3GOT 1] 1] \
        [lsearch -exact [lindex [lindex $H3GOT 1] 2] {@m.xo1.xi1.m1[gm]}] \
        [expr {($H3BODY eq {NOPROC}) ? $H3BODY : [a_count $H3BODY {read $f}]}] \
        [expr {($H3BODY eq {NOPROC}) ? $H3BODY :
               ([a_count $H3BODY {gets $f}] >= 1 ? 1 : 0)}] \
        [expr {($H3BODY eq {NOPROC}) ? $H3BODY :
               ([a_count $H3BODY {seek $f}] >= 1 ? 1 : 0)}]] \
  [list [list {Transient Analysis} {Operating Point}] 8 1 0 1 1]

} zzerr]} {
  puts "FATAL: uncaught error: $zzerr"
  puts "$::errorInfo"
  incr fail
}

# --- teardown ----------------------------------------------------------------
a_resetall
set ::env(PATH) $PATHSAVE
if {$NDSAVE eq {ZZUNSET}} { catch {unset ::netlist_dir} } else { set ::netlist_dir $NDSAVE }
if {$J1BUDGET eq {NOVAR}} { catch {unset ::ase::cap_budget_ms} } else { a_budget_set $J1BUDGET }

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
