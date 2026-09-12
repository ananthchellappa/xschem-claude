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
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
# ============================================================================
# ⚠ THIS FILE HAD NO FLOOR PARAGRAPH AND NO FLOOR CONSTANT UNTIL ISSUE 1406,
# AND THAT IS ITS OWN DEFECT, NOT A FORMALITY. A suite that records no expected
# count leaves NO TRACE when a row is silently deleted or when a whole section
# stops running: `ALL PASS` is printed just as happily over 110 checks as over
# 80, and nothing in the file or in any driver notices the difference. Sections
# here are added and reset in place (`a_resetall`), so a section that raises
# early costs every row below it in the same block -- which is exactly the shape
# that cost 100 checks in tests/headless/test_ase_persist.tcl (issue 1405).
#
# THE HISTORY, so that a number can be argued with:
#   110  the count as this paragraph was first written (2026-09-11, HEAD
#        bcb2fc59), measured on BOTH arms -- this suite is arm-independent
#        because every row drives stand-in simulators and canned files, never
#        a widget.
#   111  section L, issue 1406: a re-registered backend must stop answering
#        from the registry it replaced.
#   126  section P, issue 1407: the capability vocabulary -- three states, two
#        predicates, four bands. FIFTEEN rows, not the fourteen first planned:
#        P15 was added after a sabotage pass went GREEN against the fourteen,
#        respelling ase::cap_report's refusal as `![ase::caps_is $c usable 1]`
#        -- the exact defect the vocabulary exists to prevent.
#   141  section Q, issue 1409: which analyses this build actually has. Fifteen
#        rows, every canned fixture VERBATIM measured text from all three
#        preflight binaries -- a fixture nobody measured proves the parser agrees
#        with the fixture and says nothing about ngspice.
#   148  section U, issue 1410: the free peek and the one cold door. ⚠ Row U2
#        took FOUR fixtures -- three of them looked fine and could not fail
#        against their own named sabotage; the reasons are written into the row.
#   158  section V, issue 1412: leg D, the variant probe. ⚠ The `expr` bareword
#        that aborts this whole file has now cost THREE runs -- sections L, Q and
#        V. The rule is written beside V6: bare words do not go in `expr`.
#   164  section W, Stage 3: which kind of thing a dc sweep variable is.
#   170  section TV, Stage 5 (issue 1426): one ngspice output variable taken
#        apart, and the three vectors a `tf` row produces. ⚠ TV4's four fixtures
#        are VERBATIM `display` transcripts, because only the FIRST of the three
#        names is a constant -- PLAN.md writes all three as literals and the
#        other two carry the row's own source and node, folded to lower case.
#   175  section PV, Stage 5 (issue 1427): one `pz` root name read back. ⚠ IT IS
#        A READER AND TV's IS A PREDICTOR, and the difference is measured: a `pz`
#        row cannot know its own vector names, because `pole(1)…pole(n)` has an
#        `n` the root finder decides -- the same two-pole RC asked for `zer`
#        produces NO VECTORS AT ALL at rc 0. So the `pz` entry declares no
#        `vectors` key and PV1-PV3 pin the reader instead.
#   180  section SV, Stage 5 (issue 1428): one `sens` result name read back.
#        ⚠ SV1's underscore row is a COLLISION IN ngspice, not caution in a
#        reader -- measured on both binaries, a deck carrying `R1` and
#        `R1_temp` puts the vector name `r1_temp` in the plot TWICE, once as
#        `R1`'s instance `temp` parameter and once as `R1_temp`'s principal
#        resistance. ⚠ AND SV2 REFUTES APPENDIX §2.10's NAMING TABLE: a
#        subcircuit device is `<letter>.<instance path>.<name>`, so that table's
#        three rows are a FLAT-deck measurement and every xschem bench has
#        subcircuits.
#
# ⚠ RAISED, NEVER LOWERED. If a change makes this number fall, that is the
# finding -- say which rows went and why, per row, and do not edit the number
# downward to make the file agree with itself.

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

## ⚠ THIS SUITE REGISTERS SIMULATORS, AND REGISTRATION NOW REACHES THE DISK
## (2026-09-08). ase::sim_register persists the registry into
## $::USER_CONF_DIR/ase_simulators at the moment it changes, which is the
## developer's own ~/.xschem/ase_simulators here. The stubs below are /bin/sh
## and deliberately broken files; writing them over the user's real list would
## take away the build they actually use. This suite is not ABOUT the saving,
## so it opts out of it -- the one test seam ase::sim_touch honours.
catch {set ::ase::sim_autosave 0}
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
## deck THAT WRITES ONE and not merely the first. It is a request and not a
## requirement -- rows B7 and B8 prove the reader copes with a build that
## ignores it -- but a deck that quietly stopped asking would hand every later
## reader a file of raw numbers for no reason at all.
##
## ⚠ THE SUBJECT IS RAW-WRITING DECKS, NOT DECKS (issue 1342). The row used to
## count `.control` blocks, which was the same number until the altshow probe
## added a third deck whose OUTPUT IS TEXT BY CONSTRUCTION -- it redirects
## `show all` to a .txt and writes no raw at all, so `set filetype=ascii` would
## be a request about a file it never creates. Counting blocks reddened this row
## for a deck that cannot violate its promise. Both counts are still MEASURED
## from the probe's own source, so splitting or merging a deck still cannot
## redden it for a reason that is not about the subject, and a raw-writing deck
## that drops the request still does.
## ⚠ PER BLOCK, NOT PER LINE. Deck A writes its raw TWICE on purpose -- that
## repetition IS the appendwrite measurement -- so counting `write` lines
## answers 3 where the honest answer is 2 decks. The split is on `.control`.
proc a_c5_blocks {src} {
    set out {}
    foreach b [split [string tolower $src] "\n"] { lappend out $b }
    set blocks {}
    set cur {}
    set inb 0
    foreach ln $out {
        if {[string match {*.control*} $ln]} { set inb 1 ; set cur {} ; continue }
        if {$inb && [string match {*.endc*} $ln]} { lappend blocks $cur ; set inb 0 ; continue }
        if {$inb} { append cur $ln "\n" }
    }
    return $blocks
}
set C5SRC [a_probe_src]
set C5DECKS [a_count $C5SRC {.control}]
set C5RAW 0
set C5ASK 0
foreach blk [a_c5_blocks $C5SRC] {
    if {![string match {*write *} $blk]} { continue }
    incr C5RAW
    if {[string match {*set filetype=ascii*} $blk]} { incr C5ASK }
}
check {C5 STRUCTURAL every deck that writes a results file asks for it in plain text, not just the first one} \
  [list [expr {$C5SRC ne {NOPROBE}}] [expr {$C5DECKS >= 2}] [expr {$C5RAW >= 2}] \
        [expr {$C5ASK == $C5RAW}]] \
  [list 1 1 1 1]

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
##
## ⚠ THIS ROW USED TO REQUIRE THAT NOTHING WHATEVER WAS SAID, AND THAT WAS
## ISSUE 0960. Not accusing the program is right and still asserted here; not
## saying anything at all is what switched every capability warning off for
## the rest of the session, silently, for a user whose folder they could have
## fixed. The row now requires the ONE sentence about the FOLDER and asserts,
## by comparison, that it is not the one about the program. Section N is where
## the rest of that behaviour lives.
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
  set J8GOT [list $J8F [a_rep_n $J8R] $J8CACHE [a_rep_rv $J8R] \
                  [expr {[a_rep_msg $J8R] ne \
                         [a_ans ase::sim_why cap_not_a_simulator ngspice $S_GOOD]}]]
  set J8EXP [list [list 0 NOKEY-usable] 1 0 cap_noplace 1]
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

## ISSUE 0961 -- `./name` IS A PATH, NOT A PATH LOOKUP. The resolve-before-the-
## move above carves out a BARE name like `ngspice`, which exec looks up on the
## PATH and which the folder change cannot affect. The carve-out used to be
## spelled "[file dirname $prog] ne {.}", and [file dirname ./ng] is ALSO {.}:
## so `./ng` was left relative and then looked for inside the probe's own
## folder, where it does not exist, while `bin/ng` -- the same program, named
## differently -- ran. Row K5 above cannot see it: it builds a MULTI-segment
## repo-root-relative name, which takes the branch that always worked.
set K5BWD [file join $scratch k5bwd]
file delete -force $K5BWD
file mkdir $K5BWD
set K5BDECK [file join $K5BWD k5b.sp]
a_wr $K5BDECK "* deck\n.control\nwrite k5bout.raw\n.endc\n.end\n"
## A dot-slash name only names the program while the process is standing in the
## folder that holds it, so the reading is taken from there -- and the process
## is put back into a folder that certainly exists afterwards, for the reason
## row K4 records.
set K5BCD [catch {cd [file dirname $S_GOOD]}]
set K5BN0 [a_runs good]
set K5BANS [a_ans ase::cap_run ./[file tail $S_GOOD] [list -b $K5BDECK] $K5BWD 10]
set K5BSTARTED [expr {[a_runs good] > $K5BN0}]
catch {cd $A_HOME}
set K5BGOT [list $K5BCD [a_capran $K5BANS] [lindex $K5BANS 0] $K5BSTARTED \
                 [file exists [file join $K5BWD k5bout.raw]]]
set K5BEXP [list 0 OK 0 1 1]
check {K5b a simulator whose location is written ./name is started too, and is not looked for inside the probe's own folder} \
  $K5BGOT $K5BEXP

## AND THE CARVE-OUT ITSELF IS STILL THERE, which is the half a wrong fix
## breaks: a name with no separator in it at all is a PATH lookup, and making
## it absolute against the folder the editor happens to be standing in would
## stop every user who registered plain `ngspice` from being measured. This
## suite put $BIN on the PATH at the top, and the process is standing in the
## repo root, where no file of that name exists -- so a pass here can only have
## come from the PATH.
set K5CWD [file join $scratch k5cwd]
file delete -force $K5CWD
file mkdir $K5CWD
set K5CDECK [file join $K5CWD k5c.sp]
a_wr $K5CDECK "* deck\n.control\nwrite k5cout.raw\n.endc\n.end\n"
catch {cd $A_HOME}
set K5CHERE [file exists [file join [pwd] [file tail $S_GOOD]]]
set K5CN0 [a_runs good]
set K5CANS [a_ans ase::cap_run [file tail $S_GOOD] [list -b $K5CDECK] $K5CWD 10]
set K5CSTARTED [expr {[a_runs good] > $K5CN0}]
catch {cd $A_HOME}
set K5CGOT [list $K5CHERE [a_capran $K5CANS] [lindex $K5CANS 0] $K5CSTARTED \
                 [file exists [file join $K5CWD k5cout.raw]]]
set K5CEXP [list 0 OK 0 1 1]
check {K5c a name with no separator in it is still the PATH lookup it was, and is not resolved against the folder the editor was standing in} \
  $K5CGOT $K5CEXP

## STRUCTURAL, and it is the half of issue 0961 that costs the NEXT reader:
## the comment above the runner stated the false rule as fact -- "a bare name
## with no folder in it" -- which is the sentence that made `./ng` look safe.
## A rule stated in a comment and a rule implemented in code have to be the
## same rule, so this row reads both: the comment says SEPARATOR, and the body
## no longer decides it with [file dirname].
## The comment block immediately above a proc, which a_body deliberately throws
## away: it is the place the rule is STATED.
proc a_lead_comment {src procline} {
  set lines [split $src "\n"]
  set at -1
  for {set i 0} {$i < [llength $lines]} {incr i} {
    if {[string match "$procline*" [lindex $lines $i]]} { set at $i ; break }
  }
  if {$at < 0} { return NOPROC }
  set out {}
  for {set i [expr {$at - 1}]} {$i >= 0} {incr i -1} {
    set l [lindex $lines $i]
    if {![regexp {^\s*#} $l]} { break }
    set out [linsert $out 0 $l]
  }
  return [join $out "\n"]
}
set K5DC [string tolower [a_lead_comment [a_slurp $ASETCL] {proc ase::cap_run }]]
set K5DBODY [a_body ase::cap_run]
set K5DGOT [list [expr {$K5DC ne {noproc} && [string length $K5DC] > 40}] \
                 [expr {[string first {separator} $K5DC] >= 0}] \
                 [expr {[string first {no folder in it} $K5DC] >= 0}] \
                 [expr {[string first {file dirname} $K5DBODY] >= 0}]]
set K5DEXP [list 1 1 0 0]
check {K5d STRUCTURAL the rule the comment states and the rule the code tests are the same rule: a separator, not a dirname} \
  $K5DGOT $K5DEXP

## ============================================================================
## ISSUE 0961, THE HALF THE FIRST PASS GOT WRONG -- IT IS NOT LATENT
## ============================================================================
## That pass wrote "latent" into three documents and "reachable only by calling
## ase::cap_run directly, which nothing in the tree does" into the issue file.
## Both are false, and the route is ordinary:
##
##   ase::sim_status takes its PATH arm whenever NOTHING IS IN FORCE -- nothing
##   registered, or the choice deliberately cleared -- and puts
##   `[lindex [auto_execok $backend] 0]` in `resolved`. ase::sim_capabilities
##   hands that straight to the probe, which hands it to ase::cap_run.
##
## auto_execok answers a RELATIVE `./ngspice` whenever $PATH carries an EMPTY
## element -- a leading, doubled or trailing `:` -- or a literal `.`, and the
## program sits in the current directory. Measured on tcl 8.6.17, all four
## spellings; a relative PATH folder answers `bin/ngspice` the same way.
##
## WHAT IT COST, measured on this tree with the predicate put back to
## `[file dirname $prog] ne {.}`: this same gesture answered
##   known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0
## with the program STARTED ZERO TIMES. That is not a missing answer, it is a
## verdict about a simulator nobody ran -- issue 0929's symptom arriving
## through the PATH door.
proc k5_dg {d k} { if {[catch {dict get $d $k} v]} { return NOKEY } ; return $v }
set K5EPATH $::env(PATH)
set K5EDIR [file join $scratch k5e_cwd]
file delete -force $K5EDIR
file mkdir $K5EDIR
set S_K5E [a_stub [file join $K5EDIR ngspice] k5e $RAW_BOTH $RAW_BCONST 0]
a_resetall
## The name has to be looked up FRESH: auto_execok caches its answer per name
## for the life of the interpreter, and an entry left behind here would poison
## every later row that asks about the same word.
unset -nocomplain ::auto_execs
catch {cd $K5EDIR}
set ::env(PATH) ":/usr/bin:/bin"
set K5EAEO [lindex [auto_execok ngspice] 0]
set K5EST [a_ans ase::sim_status ngspice]
set K5EN0 [a_runs k5e]
set K5ECAPS [a_cap ngspice]
set K5ESTARTED [expr {[a_runs k5e] > $K5EN0}]
set ::env(PATH) $K5EPATH
unset -nocomplain ::auto_execs
catch {cd $A_HOME}
a_resetall
set K5EGOT [list $K5EAEO [k5_dg $K5EST source] [k5_dg $K5EST resolved] \
                 [k5_dg $K5ECAPS known] [k5_dg $K5ECAPS usable] $K5ESTARTED]
set K5EEXP [list ./ngspice path ./ngspice 1 1 1]
check {K5e with nothing in force the PATH arm hands the probe auto_execok's own answer, which is RELATIVE when $PATH has an empty element -- and the program is still started} \
  $K5EGOT $K5EEXP

## STRUCTURAL, and it is the sentence the adversary refuted. The note above
## ase::sim_capabilities_at said "Every caller of this proc hands it a path the
## user themselves named -- a registered entry's own `path`, or what they typed
## in the Program field". Row K5e is a caller that does neither. What issue
## 0935 actually forbids is measuring a REFUSED resolution's `resolved`, and
## guard 1 in the wrapper is what stops that; auto_execok's answer on the
## nothing-in-force arm is the file that really will start, and is right to
## measure. The note has to say that, because the next reader who believes the
## old one will look for a caller that cannot exist.
set K5FC [string tolower [a_lead_comment [a_slurp $ASETCL] {proc ase::sim_capabilities_at }]]
set K5FGOT [list [expr {$K5FC ne {noproc} && [string length $K5FC] > 40}] \
                 [expr {[string first {hands it a path the user themselves named} $K5FC] >= 0}] \
                 [expr {[string first {auto_execok} $K5FC] >= 0}] \
                 [expr {[string first {nothing is in force} $K5FC] >= 0}]]
set K5FEXP [list 1 0 1 1]
check {K5f STRUCTURAL the note above the probe core does not claim every caller names the path itself, and says where auto_execok supplies it instead} \
  $K5FGOT $K5FEXP

## STRUCTURAL, same defect one file over: ase::cap_run's own header is where
## the next reader lands, so the route that reaches it with a relative name is
## named THERE, and the word that was wrong is kept out.
set K5GC [string tolower [a_lead_comment [a_slurp $ASETCL] {proc ase::cap_run }]]
set K5GGOT [list [expr {[string first {auto_execok} $K5GC] >= 0}] \
                 [expr {[string first {latent} $K5GC] >= 0}]]
set K5GEXP [list 1 0]
check {K5g STRUCTURAL the runner's own header names the route that reaches it with a relative name, and never calls it latent} \
  $K5GGOT $K5GEXP

## THE WINDOWS BACKSLASH GATE, WHICH UNTIL NOW WAS GUARDED BY NOTHING -- the
## adversary deleted `&& $::tcl_platform(platform) eq {windows}` from the
## predicate and no row moved. On Unix a backslash is an ORDINARY CHARACTER in
## a file name, so `sim_k5h\bs` is a bare name and stays a PATH lookup; with
## the gate gone it would be read as a path, made absolute against the folder
## the editor is standing in, and not found. Measured first with tclsh 8.6.17:
## bare on the PATH runs (rc 0, with and without the wall-clock cap), the same
## name normalized against a folder that does not hold it fails with
## "no such file or directory".
if {$::tcl_platform(platform) eq {windows}} {
  puts "  K5h SKIPPED LOUDLY: a backslash IS a separator on this platform, so there is no bare name of this shape to test"
  set K5HGOT SKIP-WINDOWS ; set K5HEXP SKIP-WINDOWS
} else {
  set K5HWD [file join $scratch k5hwd]
  file delete -force $K5HWD
  file mkdir $K5HWD
  set K5HDECK [file join $K5HWD k5h.sp]
  a_wr $K5HDECK "* deck\n.control\nwrite k5hout.raw\n.endc\n.end\n"
  set K5HNAME {sim_k5h\bs}
  set S_K5H [a_stub [file join $BIN $K5HNAME] k5h $RAW_BOTH $RAW_BCONST 0]
  catch {cd $A_HOME}
  ## $BIN is on the PATH and the process is standing in the repo root, where no
  ## file of this name exists -- so a pass here can only have come from the PATH.
  set K5HHERE [file exists [file join [pwd] $K5HNAME]]
  set K5HN0 [a_runs k5h]
  set K5HANS [a_ans ase::cap_run $K5HNAME [list -b $K5HDECK] $K5HWD 10]
  set K5HSTARTED [expr {[a_runs k5h] > $K5HN0}]
  catch {cd $A_HOME}
  set K5HGOT [list [file exists $S_K5H] $K5HHERE [a_capran $K5HANS] \
                   [lindex $K5HANS 0] $K5HSTARTED \
                   [file exists [file join $K5HWD k5hout.raw]]]
  set K5HEXP [list 1 0 OK 0 1 1]
}
check {K5h a backslash is an ordinary character in a Unix file name, so a name carrying one and no slash is still the PATH lookup it was} \
  $K5HGOT $K5HEXP

## AND THE OTHER HALF OF THE GATE, WHICH NO BEHAVIOURAL ROW ON THIS BOX CAN
## REACH: on Windows the backslash IS a separator and must count. Row K5h
## cannot see that clause being deleted outright -- a bare name stays bare
## either way here -- so this row reads the decision itself: there is exactly
## one backslash test, and the line above it is the platform gate. Checking
## only "the body mentions windows" would be vacuous: line 2 of the body
## already does, for NUL vs /dev/null.
proc a_gateline {body} {
  if {$body eq {NOPROC} || [string match RAISED:* $body]} { return [list NOBODY 0 0] }
  set lines [split $body "\n"]
  set n 0 ; set gated 0
  for {set i 0} {$i < [llength $lines]} {incr i} {
    if {[string first {string first \\} [lindex $lines $i]] < 0} { continue }
    incr n
    set prev [expr {$i > 0 ? [lindex $lines [expr {$i - 1}]] : {}}]
    if {[string first {windows} $prev] >= 0 && \
        [string first {tcl_platform} $prev] >= 0} { set gated 1 }
  }
  return [list OK $n $gated]
}
check {K5i STRUCTURAL the backslash counts as a separator on Windows only, and the platform gate is the line that says so} \
  [a_gateline [a_body ase::cap_run]] [list OK 1 1]


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
# N. A SIMULATION FOLDER THE PROBE CANNOT USE -- ISSUE 0960
# ============================================================================
# Measured on the built binary before this section existed, both shapes, three
# presses of Run each, with a real ngspice registered and selected:
#
#   read-only simulation folder:
#     RO press 1..3 : caps={known 0 unmeasured noplace} kind='' said={}
#   a writable folder in which .ase_probe is an ordinary FILE:
#     BL press 1..3 : caps={known 0 unmeasured noplace} kind='' said={}
#
# Nothing said, on any press, for the rest of the session. Every warning the
# capability feature exists to give them is switched off with it -- including
# the one that costs them their results, that a build which keeps only the
# last analysis of a run will throw the other analyses away.
#
# THE SECOND SHAPE IS THE ONE THE USER DID NOTHING TO EARN: the folder is
# perfectly writable and one stray file -- a leftover from a crashed run -- is
# sitting at the name the probe needs. It is fixed by deleting one file, which
# is why the sentence has to say which file.
#
# ⚠ THE FAULT IS THE FOLDER'S, AND THE SENTENCE MAY NOT ACCUSE THE PROGRAM.
# That is issue 0949's category error, which the silence being fixed here was
# the price of. Row N1 asserts the sentence is not the one about a program
# that produced no results, and row N5 asserts the two shapes read as two
# different sentences that name the folder or the file, never the simulator.

## The two shapes, built here rather than described. Each returns the path the
## sentence has to name: the blocking FILE for the occupied shape, the FOLDER
## for the read-only one.
proc n_occupied {dir} {
  catch {file attributes $dir -permissions 0755}
  file delete -force $dir
  file mkdir $dir
  a_wr [file join $dir .ase_probe] "zz leftover from a crashed run\n"
  set b [a_nd $dir]
  return [file normalize [file join $b .ase_probe]]
}
proc n_readonly {dir} {
  catch {file attributes $dir -permissions 0755}
  file delete -force $dir
  file mkdir $dir
  catch {file attributes $dir -permissions 0555}
  return [file normalize [a_nd $dir]]
}
proc n_free {dir} {
  catch {file attributes $dir -permissions 0755}
  file delete -force $dir
}

## THE CONTROL FIRST, and it is half the acceptance: in an ordinary folder the
## same build and the same run still get the warning. Without it a fix that
## said the new sentence always would pass every row below.
set N1PLAIN [file join $scratch n1plain]
n_free $N1PLAIN
a_nd $N1PLAIN
a_resetall
a_use ngcap-n1a $S_F1
set N1CTRL [a_report ngspice 2]

set N1DIR [file join $scratch n1occupied]
set N1AT [n_occupied $N1DIR]
a_resetall
a_use ngcap-n1b $S_F1
set N1OCC [a_report ngspice 2]
set N1NOTSIM [a_ans ase::sim_why cap_not_a_simulator ngspice $S_F1]
check {N1 a stray file at the name the probe needs is said out loud, naming the file, and the same run in an ordinary folder still gets the warning it always got} \
  [list [a_rep_rv $N1CTRL] [a_rep_n $N1CTRL] \
        [a_rep_rv $N1OCC] [a_rep_n $N1OCC] \
        [expr {[string first $N1AT [a_rep_msg $N1OCC]] >= 0}] \
        [expr {[a_rep_msg $N1OCC] ne $N1NOTSIM}]] \
  [list cap_no_append 1 cap_noplace 1 1 1]

## THE OTHER SHAPE. Skips loudly rather than quietly where the box cannot
## build it -- a user who can write into a folder with no write permission on
## it is root, and root can never meet this state.
set N2DIR [file join $scratch n2readonly]
set N2AT [n_readonly $N2DIR]
if {[file writable $N2DIR]} {
  puts "  N2 SKIPPED LOUDLY: this box can write into a folder with no write permission on it"
  set N2GOT SKIP-NO-RO ; set N2EXP SKIP-NO-RO
} else {
  a_resetall
  a_use ngcap-n2 $S_F1
  set N2R [a_report ngspice 2]
  set N2W [a_capfields ngspice {known unmeasured noplace_why noplace_at}]
  set N2GOT [list [a_rep_rv $N2R] [a_rep_n $N2R] \
                  [expr {[string first $N2AT [a_rep_msg $N2R]] >= 0}] \
                  [expr {[a_rep_msg $N2R] ne [a_rep_msg $N1OCC]}] $N2W]
  set N2EXP [list cap_noplace 1 1 1 [list 0 noplace readonly $N2AT]]
}
a_nd $NDBASE
n_free $N2DIR
check {N2 a simulation folder nothing can be written into is said out loud too, in its own words, naming the folder} $N2GOT $N2EXP

## NOT A NAG. The state does not clear itself, so a sentence on every Run
## would be one on every Run for the rest of the session. Said once for the
## place it is about; the lever that forgets what was measured is the one that
## lets it be said again.
set N3DIR [file join $scratch n3occupied]
set N3AT [n_occupied $N3DIR]
a_resetall
a_use ngcap-n3 $S_F1
set N3A [a_report ngspice 2]
set N3B [a_report ngspice 2]
set N3C [a_report ngspice 2]
a_ans ase::sim_caps_clear
set N3D [a_report ngspice 2]
check {N3 the sentence is said once for the place it is about and not again on every Run, and forgetting what was measured lets it be said again} \
  [list [a_rep_rv $N3A] [a_rep_n $N3A] [a_rep_rv $N3B] [a_rep_n $N3B] \
        [a_rep_rv $N3C] [a_rep_n $N3C] [a_rep_rv $N3D] [a_rep_n $N3D]] \
  [list cap_noplace 1 {} 0 {} 0 cap_noplace 1]

## THE ANSWER CARRIES WHICH PLACE WAS IN THE WAY, so whoever says the sentence
## reads it rather than working it out a second time. Only the code that tried
## knows which of the two shapes it hit.
set N4DIR [file join $scratch n4occupied]
set N4AT [n_occupied $N4DIR]
a_resetall
a_use ngcap-n4 $S_F1
check {N4 the answer that nothing was measured says WHICH place was in the way and what was wrong with it} \
  [a_capfields ngspice {known unmeasured noplace_why noplace_at}] \
  [list 0 noplace occupied $N4AT]

## PLAIN ENGLISH, TWO SENTENCES, AND EACH PHRASE MINTED IN ONE PLACE -- the
## same technique rows F5 and F6 use on the 0948 sentences, because ruling
## D5-4 is the same ruling: no caller re-words what the mint already said.
set N5P [file join $scratch nowhere .ase_probe]
set N5A [a_ans ase::sim_why cap_noplace {} $N5P occupied]
set N5B [a_ans ase::sim_why cap_noplace {} [file dirname $N5P] readonly]
## ⚠ THE TWO ARE COMPARED ON ONE PATH, and a sabotage pass is why. With each
## arm asked about the path it would really be given, one arm's text can be
## pasted over the other's and the two sentences STILL differ -- by the path
## alone. Measured: the whole occupied arm replaced by the read-only wording
## left this row green.
set N5SAME [a_ans ase::sim_why cap_noplace {} $N5P readonly]
## THE THIRD ARM, asked for here so row N6 can take it apart too. `other` is
## the value ase::cap_noplace_at answers with for the catch-all, and any value
## the switch does not name reaches the same arm.
set N5C [a_ans ase::sim_why cap_noplace {} $N5P other]
## THE FOURTH ARM (close-out round). Reached when the simulation folder setting
## names something that is not a directory at all -- see ase::cap_noplace_at.
set N5D [a_ans ase::sim_why cap_noplace {} [file dirname $N5P] notdir]
set N5FALL [a_ans ase::sim_why zz_no_such_kind {} $N5P]
check {N5 the two shapes read as two different plain-English sentences, each naming what is in the way, and neither is the catch-all} \
  [list [a_plain $N5A {} $N5P] [a_plain $N5B {} [file dirname $N5P]] \
        [expr {$N5A ne $N5B}] [expr {$N5A ne $N5SAME}] \
        [expr {[string first $N5P $N5A] >= 0}] \
        [expr {[string first [file dirname $N5P] $N5B] >= 0}] \
        [expr {$N5A ne $N5FALL}] [expr {$N5B ne $N5FALL}]] \
  [list PLAIN PLAIN 1 1 1 1 1 1]

## THE SENTENCE IS COMPOSED FROM TWO PIECES OF SOURCE -- the shape both shapes
## share, and the arm that says what is in the way -- so unlike row F6, which
## measures the two flat 0948 sentences, EVERY piece here has to be measured
## and not just the runs between substitutions: the run that spans the join
## between the two source strings is text no source line can ever match.
##
## ⚠ THE PATH COMES OUT FIRST AND THE SENTENCE ENDINGS SECOND, in that order,
## because a path can have a full stop in it -- `.ase_probe` is the one this
## very section builds -- and splitting at full stops first cuts the path in
## half, so what is left of it is never taken out at all.
proc n_pieces {m path} {
  set out {}
  foreach chunk [split [string map [list $path \x01] $m] \x01] {
    foreach piece [split $chunk "."] {
      set t [string trim $piece]
      if {[string length $t] >= 25} { lappend out $t }
    }
  }
  return $out
}
##
## ⚠ ALL THREE ARMS, AND THE THIRD WAS MISSING. This row was named "each fixed
## piece of THE TWO SENTENCES" and looped `occupied` and `readonly` only, while
## ase::sim_why cap_noplace mints THREE -- so the catch-all could be re-worded
## in a second place, or half of it pasted into a caller, with this row green.
## That is the same hole the catch-all's missing behavioural row was.
set N6SRC [a_nocomment [a_slurp $ASETCL]]
set N6N 0 ; set N6ALLONE 1 ; set N6MISS {}
foreach m [list $N5A $N5B $N5C $N5D] \
        p [list $N5P [file dirname $N5P] $N5P [file dirname $N5P]] {
  if {$m eq {} || $m eq {NOPROC} || [string match RAISED:* $m] || $m eq $N5FALL} {
    set N6ALLONE 0 ; continue
  }
  foreach c [n_pieces $m $p] {
    incr N6N
    if {[a_count $N6SRC $c] != 1} { set N6ALLONE 0 ; lappend N6MISS $c }
  }
}
check {N6 STRUCTURAL each fixed piece of ALL FOUR sentences exists in exactly one place in the source} \
  [list [expr {$N6N >= 12}] $N6ALLONE $N6MISS] [list 1 1 {}]

## THE ACCEPTANCE'S OTHER HALF: a user who clears the obstruction gets the
## warnings back on the very next Run, with nothing else done and no restart.
set N7DIR [file join $scratch n7occupied]
set N7AT [n_occupied $N7DIR]
a_resetall
a_use ngcap-n7 $S_F1
set N7BEFORE [a_report ngspice 2]
file delete -force $N7AT
set N7AFTER [a_report ngspice 2]
check {N7 deleting the one file that was in the way brings the warnings back on the next Run, with nothing else done} \
  [list [a_rep_rv $N7BEFORE] [a_rep_rv $N7AFTER] \
        [expr {[a_rep_msg $N7AFTER] eq [a_ans ase::sim_why cap_no_append ngspice $S_F1]}]] \
  [list cap_noplace cap_no_append 1]

## BOTH SHAPES AT ONCE, WHICH IS THE ONLY PLACE THE ORDER OF THE TWO TESTS
## SHOWS. A read-only folder that ALSO has a file sitting at the name the
## probe needs is one the user cannot empty: deleting that file needs write
## permission on the folder it is in. "Delete or rename that file" is then a
## fix they cannot carry out, so the folder's own sentence is the one to say,
## and the other shape reports itself on the next Run once the folder is
## writable. A sabotage pass that swapped the two tests reddened NOTHING
## before this row existed.
set N8DIR [file join $scratch n8both]
n_free $N8DIR
file mkdir $N8DIR
a_wr [file join $N8DIR .ase_probe] "zz leftover in a folder that is read-only\n"
catch {file attributes $N8DIR -permissions 0555}
set N8AT [file normalize [a_nd $N8DIR]]
if {[file writable $N8DIR]} {
  puts "  N8 SKIPPED LOUDLY: this box can write into a folder with no write permission on it"
  set N8GOT SKIP-NO-RO ; set N8EXP SKIP-NO-RO
} else {
  a_resetall
  a_use ngcap-n8 $S_F1
  set N8R [a_report ngspice 2]
  set N8GOT [list [a_capfields ngspice {noplace_why noplace_at}] \
                  [a_rep_rv $N8R] \
                  [expr {[a_rep_msg $N8R] eq \
                         [a_ans ase::sim_why cap_noplace {} $N8AT readonly]}]]
  set N8EXP [list [list readonly $N8AT] cap_noplace 1]
}
a_nd $NDBASE
n_free $N8DIR
check {N8 a folder that is read-only AND has a file in the way is reported as the read-only one, because deleting that file is not something the user can do} $N8GOT $N8EXP

## ==========================================================================
## THE THIRD ARM -- THE ONE NOBODY MEASURED (issue 0960, repair round)
## ==========================================================================
## ase::sim_why cap_noplace has THREE arms, not two. Rows N1-N8 above measure
## `occupied` and `readonly`; the third, the catch-all, shipped with no row on
## it at all -- so it could regress to this issue's ORIGINAL defect, silence,
## with this section green.
##
## IT IS REACHED WITH ORDINARY FILESYSTEM SHAPES, and both of the two below
## were driven live through ase::sim_capabilities + ase::cap_report on the
## built binary before these rows were written:
##
##   a DANGLING SYMBOLIC LINK at .ase_probe -- the crashed-run leftover this
##     issue is about, one link deep. `file exists` follows the link and
##     answers 0, so the `occupied` test cannot see it; `file mkdir` fails
##     with EEXIST. Measured: caps = {known 0 unmeasured noplace noplace_why
##     other noplace_at <folder>}, rv = cap_noplace.
##   a .ase_probe DIRECTORY WITH NO WRITE PERMISSION -- it exists, it is a
##     directory, so the parent mkdir succeeds and all 64 attempts to make a
##     place inside it fail. Same answer.
##
## ⚠ THE FOLDER TEST RUNS FIRST IN ase::cap_noplace_at, SO THE CATCH-ALL IS
## REACHED ONLY AFTER THAT TEST HAS MADE A NEW ENTRY IN THE FOLDER AND REMOVED
## IT AGAIN. That is what lets the catch-all's sentence assert the folder can
## be written into.
##
## ⚠ AND FOR ONE ROUND IT DID NOT EARN THAT. The first test read
## `file writable`, which on a DIRECTORY is POSIX access(W_OK) and ignores the
## SEARCH bit, so mode 0600 and mode 0200 folders -- every create refused --
## fell through to this arm. Rows N14 and N15 are those two shapes, and the
## write-up that claimed "the catch-all is only ever reached when the folder
## IS writable" was false for the whole of that round. Do not restore that
## sentence: the ONLY thing the order licenses is what the first test actually
## measured.
##
## The sentence that shipped before the repair round said "<folder> is your
## simulation folder, and no place to write a test result could be made in it.
## Check that you can write into it." -- it names the folder, which for the
## shapes below is the one thing that is FINE. Row N11 holds the replacement
## to the state it is minted for.

## The two shapes, built here rather than described. Each returns the probe
## place the sentence has to name, or empty when this box cannot build it.
proc n_link {link target} {
  if {![catch {file link -symbolic $link $target}]} { return 1 }
  if {![catch {exec ln -s $target $link}]} { return 1 }
  return 0
}
proc n_probe_free {dir} {
  catch {file attributes $dir -permissions 0755}
  foreach p [glob -nocomplain -directory $dir .ase_probe] {
    catch {file attributes $p -permissions 0755}
  }
  file delete -force $dir
}
proc n_dangling {dir} {
  n_probe_free $dir
  file mkdir $dir
  set b [a_nd $dir]
  set link [file join $b .ase_probe]
  set tgt  [file join $b zzgone]
  a_wr $tgt "zz a target that is about to go away\n"
  if {![n_link $link $tgt]} { return {} }
  file delete -force $tgt
  if {[file exists $link]} { return {} }
  return [file normalize $link]
}
proc n_roprobe {dir} {
  n_probe_free $dir
  file mkdir $dir
  set b [a_nd $dir]
  set p [file join $b .ase_probe]
  file mkdir $p
  catch {file attributes $p -permissions 0555}
  return [file normalize $p]
}
## CREATABILITY, TESTED BY TRYING, which is the only honest test on a
## directory -- and this row-side copy is deliberately NOT the one under test,
## so a fix that answers by inference cannot make its own test agree with it.
## Leaves nothing behind on either answer.
proc n_can_create {dir} {
  set t [file join $dir .zz_row_try_[pid]_[clock clicks]]
  if {[file exists $t]} { return 0 }
  if {[catch {file mkdir $t}]} { return 0 }
  if {![file isdirectory $t]} { return 0 }
  catch {file delete -force -- $t}
  return 1
}


## SHAPE ONE, THROUGH THE REAL SEAM. The answer has to carry the probe place,
## not the folder: the folder is writable and there is nothing for the user to
## do to it, while `<folder>/.ase_probe` is the one thing they can delete.
set N9DIR [file join $scratch n9dangling]
set N9AT [n_dangling $N9DIR]
if {$N9AT eq {}} {
  puts "  N9 SKIPPED LOUDLY: this box could not make a dangling symbolic link"
  set N9GOT SKIP-NO-DANGLING ; set N9EXP SKIP-NO-DANGLING
} else {
  a_resetall
  a_use ngcap-n9 $S_F1
  set N9W [a_capfields ngspice {known unmeasured noplace_why noplace_at}]
  set N9R [a_report ngspice 2]
  set N9GOT [list $N9W [a_rep_rv $N9R] [a_rep_n $N9R] \
                  [expr {[string first $N9AT [a_rep_msg $N9R]] >= 0}] \
                  [expr {[file writable [file dirname $N9AT]]}]]
  set N9EXP [list [list 0 noplace other $N9AT] cap_noplace 1 1 1]
}
a_nd $NDBASE
check {N9 a dangling symbolic link left at the probe place is said out loud, and what is said names that place and not the folder, which is fine} $N9GOT $N9EXP

## SHAPE TWO. A .ase_probe that exists, is a directory, and cannot be written
## into: every one of the 64 attempts to make a place inside it fails. The
## sentence is neither of the other two arms'.
set N10DIR [file join $scratch n10roprobe]
set N10AT [n_roprobe $N10DIR]
if {[file writable $N10AT]} {
  puts "  N10 SKIPPED LOUDLY: this box can write into a folder with no write permission on it"
  set N10GOT SKIP-NO-RO ; set N10EXP SKIP-NO-RO ; set N10SAY {}
} else {
  a_resetall
  a_use ngcap-n10 $S_F1
  set N10W [a_capfields ngspice {known unmeasured noplace_why noplace_at}]
  set N10R [a_report ngspice 2]
  set N10SAY [a_rep_msg $N10R]
  set N10GOT [list $N10W [a_rep_rv $N10R] [a_rep_n $N10R] \
                   [expr {[string first $N10AT $N10SAY] >= 0}] \
                   [expr {$N10SAY ne [a_ans ase::sim_why cap_noplace {} $N10AT readonly]}] \
                   [expr {$N10SAY ne [a_ans ase::sim_why cap_noplace {} $N10AT occupied]}] \
                   [expr {[file writable [file dirname $N10AT]]}]]
  set N10EXP [list [list 0 noplace other $N10AT] cap_noplace 1 1 1 1 1]
}
a_nd $NDBASE
check {N10 a probe place that exists and cannot be written into is said out loud too, in words that are neither of the other two arms} $N10GOT $N10EXP

## THE SENTENCE HELD TO THE STATE IT IS MINTED FOR. The three literals below
## are this row's own, and they are the defect written down: the folder IS
## writable whenever this arm is reached, so a sentence that tells the user to
## check whether they can write into it names the wrong object and gives
## advice that cannot help. It must say instead that the folder is fine and
## name what they can act on.
##
## ⚠ THE LAST TWO FIELDS ARE THE POINT AND THEY ARE NOT THE SAME QUESTION.
## `file writable` is what the code used to infer from and is kept here only
## as the misleading witness; n_can_create is a REAL create, and it is the one
## that has to say yes before the sentence may claim the folder can be written
## into. Rows N14 and N15 are the shapes where the two disagree.
if {$N10SAY eq {}} {
  puts "  N11 SKIPPED LOUDLY: the catch-all sentence could not be reached on this box"
  set N11GOT SKIP-NO-RO ; set N11EXP SKIP-NO-RO
} else {
  set N11GOT [list [a_plain $N10SAY {} $N10AT] \
                   [expr {[string first {Check that you can write into it} $N10SAY] >= 0}] \
                   [expr {[string first {can be written into} $N10SAY] >= 0}] \
                   [expr {[file writable [file dirname $N10AT]]}] \
                   [n_can_create [file dirname $N10AT]]]
  set N11EXP [list PLAIN 0 1 1 1]
}
check {N11 the catch-all sentence is true of the state it is minted for: it says the simulation folder can be written into, instead of telling the user to check something that is already so} $N11GOT $N11EXP

## ISSUE 0960's OWN DEFECT SURVIVING INSIDE ITS FIX, and it is the reason this
## repair exists. Measured live on the built binary, ONE process, no registry
## edit and no ase::sim_caps_clear between the two facts: a read-only folder
## said its sentence; the user made the folder writable and met the catch-all;
## rv={} said={}. ase::cap_noplace_once was keyed on the PLACE alone and both
## arms answered with the folder, so the second fact was withheld -- which is
## exactly the silence this issue was filed about.
set N12DIR [file join $scratch n12fuse]
n_probe_free $N12DIR
file mkdir $N12DIR
set N12B [file normalize [a_nd $N12DIR]]
catch {file attributes $N12DIR -permissions 0555}
if {[file writable $N12DIR]} {
  puts "  N12 SKIPPED LOUDLY: this box can write into a folder with no write permission on it"
  set N12GOT SKIP-NO-RO ; set N12EXP SKIP-NO-RO
} else {
  a_resetall
  a_use ngcap-n12 $S_F1
  set N12A [a_report ngspice 2]
  catch {file attributes $N12DIR -permissions 0755}
  set N12P [file join $N12B .ase_probe]
  file mkdir $N12P
  catch {file attributes $N12P -permissions 0555}
  set N12C [a_report ngspice 2]
  set N12GOT [list [a_rep_rv $N12A] [a_rep_rv $N12C] \
                   [expr {[a_rep_msg $N12C] ne [a_rep_msg $N12A]}] \
                   [a_capf ngspice noplace_why]]
  set N12EXP [list cap_noplace cap_noplace 1 other]
}
a_nd $NDBASE
check {N12 a user who fixes the read-only folder and then meets the catch-all is told the second fact too, in one session and with no registry edit} $N12GOT $N12EXP

## AND THE KEY ITSELF, on the pair that shares a place. The catch-all and the
## occupied arm both answer with the probe place, so nothing but a key that
## carries WHAT was wrong can tell "a file is sitting there" from "it exists
## and cannot be used". The user deletes the leftover file, something puts a
## directory there that the probe cannot write into, and both facts are about
## one path in one session.
set N13DIR [file join $scratch n13key]
set N13AT [n_occupied $N13DIR]
a_resetall
a_use ngcap-n13 $S_F1
set N13A [a_report ngspice 2]
file delete -force $N13AT
file mkdir $N13AT
catch {file attributes $N13AT -permissions 0555}
if {[file writable $N13AT]} {
  puts "  N13 SKIPPED LOUDLY: this box can write into a folder with no write permission on it"
  set N13GOT SKIP-NO-RO ; set N13EXP SKIP-NO-RO
} else {
  set N13B [a_report ngspice 2]
  set N13GOT [list [a_rep_rv $N13A] [a_capf ngspice noplace_at] \
                   [a_capf ngspice noplace_why] [a_rep_rv $N13B] \
                   [expr {[a_rep_msg $N13B] ne [a_rep_msg $N13A]}]]
  set N13EXP [list cap_noplace $N13AT other cap_noplace 1]
}
a_nd $NDBASE
check {N13 two different things wrong at ONE probe place are two different facts, and the second is not swallowed by the first} $N13GOT $N13EXP

## ==========================================================================
## THE SHAPE `file writable` CANNOT SEE (issue 0960, close-out round)
## ==========================================================================
## `file writable` on a DIRECTORY is POSIX access(W_OK). It answers about the
## WRITE bit and says nothing whatever about the SEARCH (x) bit, and a create
## needs both. A simulation folder at mode 0600 -- what `chmod -R 600 project/`
## leaves behind, the reflex after a leaked secret -- therefore ANSWERS
## `file writable` 1 and REFUSES EVERY CREATE. Measured on this box, in one
## tclsh, before these rows were written:
##
##   mode 0600 : file writable = 1 | mkdir "permission denied" | touch the same
##   mode 0200 : file writable = 1 | mkdir "permission denied" | touch the same
##
## That is why the rows below exist and why they are not a corner case: an
## ordinary permission accident lands a whole family of folders here.
##
## ⚠ ON THE TREE THESE ROWS WERE WRITTEN AGAINST BOTH SHAPES LANDED IN THE
## CATCH-ALL, because ase::cap_noplace_at INFERRED creatability from
## `file writable`. Driven live through ase::sim_capabilities +
## ase::cap_report on the built binary, mode 0600:
##   noplace_why = other, noplace_at = <folder>/.ase_probe, rv = cap_noplace
## and the sentence the user read was
##   "... <folder>/.ase_probe is where a test result has to go, and it could
##    not be made or used. Your simulation folder itself can be written into,
##    so delete <folder>/.ase_probe or make it writable."
## BOTH CLAUSES FALSE: nothing can be written into that folder, and there is
## no .ase_probe to delete. These two rows hold the answer to what a real
## create does, not to what access(W_OK) says.

## The two shapes. Each returns the SIMULATION FOLDER -- the object the
## sentence has to name, because the fix is the folder's permissions.
proc n_mode {dir mode} {
  n_probe_free $dir
  file mkdir $dir
  set b [file normalize [a_nd $dir]]
  catch {file attributes $b -permissions $mode}
  return $b
}
## MODE 0600 -- rw, no search. The row pins the trap itself: `file writable`
## says 1 on this folder, a real create says no, and the answer has to follow
## the create. It must be the FOLDER's arm (the user's fix is chmod), it must
## name the folder, and it must NOT tell them the folder can be written into.
set N14DIR [file join $scratch n14mode0600]
set N14AT [n_mode $N14DIR 0600]
if {[n_can_create $N14AT]} {
  puts "  N14 SKIPPED LOUDLY: this box can create inside a folder with no search bit"
  set N14GOT SKIP-NO-NOX ; set N14EXP SKIP-NO-NOX
} else {
  a_resetall
  a_use ngcap-n14 $S_F1
  set N14W [a_capfields ngspice {known unmeasured noplace_why noplace_at}]
  set N14R [a_report ngspice 2]
  set N14SAY [a_rep_msg $N14R]
  set N14GOT [list $N14W [a_rep_rv $N14R] [a_rep_n $N14R] \
                   [expr {[file writable $N14AT]}] \
                   [expr {[string first $N14AT $N14SAY] >= 0}] \
                   [expr {[string first {can be written into} $N14SAY] >= 0}] \
                   [expr {$N14SAY eq [a_ans ase::sim_why cap_noplace {} $N14AT readonly]}] \
                   [a_plain $N14SAY {} $N14AT]]
  set N14EXP [list [list 0 noplace readonly $N14AT] cap_noplace 1 1 1 0 1 PLAIN]
}
catch {file attributes $N14AT -permissions 0755}
a_nd $NDBASE
check {N14 a simulation folder at mode 0600 -- write bit set, no search bit, so `file writable` says yes and every create is refused -- is reported as the folder that will not take a new entry, not as a probe place to delete} $N14GOT $N14EXP

## MODE 0200 -- write only. Same arm, and this row carries the half that makes
## the advice actionable: there is NOTHING at the probe place (the folder
## cannot even be looked into), so a sentence offering a file to delete is
## advice the user cannot carry out.
set N15DIR [file join $scratch n15mode0200]
set N15AT [n_mode $N15DIR 0200]
if {[n_can_create $N15AT]} {
  puts "  N15 SKIPPED LOUDLY: this box can create inside a write-only folder"
  set N15GOT SKIP-NO-NOX ; set N15EXP SKIP-NO-NOX
} else {
  a_resetall
  a_use ngcap-n15 $S_F1
  set N15W [a_capfields ngspice {known unmeasured noplace_why noplace_at}]
  set N15R [a_report ngspice 2]
  set N15SAY [a_rep_msg $N15R]
  set N15GOT [list $N15W [a_rep_rv $N15R] [a_rep_n $N15R] \
                   [expr {[file writable $N15AT]}] \
                   [expr {[file exists [file join $N15AT .ase_probe]]}] \
                   [expr {[string first {can be written into} $N15SAY] >= 0}] \
                   [expr {[string first {Delete or rename that file} $N15SAY] >= 0}] \
                   [expr {$N15SAY ne [a_ans ase::sim_why cap_noplace {} $N15AT occupied]}]]
  set N15EXP [list [list 0 noplace readonly $N15AT] cap_noplace 1 1 0 0 0 1]
}
catch {file attributes $N15AT -permissions 0755}
a_nd $NDBASE
check {N15 a write-only simulation folder lands in the same arm, and what is said offers no file to delete, because there is none and the folder cannot even be looked into} $N15GOT $N15EXP

## ⚠ THIS ROW WAS NOT RED BEFORE THE FIX AND CANNOT HAVE BEEN. It guards a
## cost the fix introduces: answering "will this folder take a new entry?" by
## TRYING means making and removing an entry in the user's simulation folder.
## Before the fix nothing tried, so there was nothing to leave behind. It is
## proved by SABOTAGE instead -- drop the delete from ase::cap_dir_takes_entry
## and this row reddens by name while N9 and N10 stay green.
##
## The shape is the catch-all one, which is the only one where the trial
## SUCCEEDS: the folder takes an entry and `.ase_probe` is what cannot be
## used. Expected leftovers are exactly what the fixture put there.
set N16DIR [file join $scratch n16litter]
set N16AT [n_roprobe $N16DIR]
if {[file writable $N16AT]} {
  puts "  N16 SKIPPED LOUDLY: this box can write into a folder with no write permission on it"
  set N16GOT SKIP-NO-RO ; set N16EXP SKIP-NO-RO
} else {
  set N16ND [file normalize [file dirname $N16AT]]
  a_resetall
  a_use ngcap-n16 $S_F1
  set N16BEFORE [a_walk $N16ND]
  set N16R [a_report ngspice 2]
  set N16AFTER [a_walk $N16ND]
  set N16GOT [list [a_rep_rv $N16R] $N16BEFORE $N16AFTER]
  set N16EXP [list cap_noplace [list .ase_probe] [list .ase_probe]]
}
a_nd $NDBASE
check {N16 finding out whether the folder will take a new entry leaves nothing behind in the user's simulation folder} $N16GOT $N16EXP

## ⚠ N17 -- THE ARM THIS ROUND ALMOST SHIPPED WRONG, and the shape an earlier
## comment in src/ase.tcl called unreachable. `set_netlist_dir` creates the
## folder only `if {![file exist $netlist_dir]}`, so a ::netlist_dir naming an
## existing REGULAR FILE is handed back verbatim and reaches the probe. Before
## the `notdir` arm the folder arm answered, and a regular file was called
## "your simulation folder" with advice -- give it write and search permission
## -- that cannot be carried out on a file. The row pins the object AND the
## advice: it must not say "your simulation folder", must not offer permissions
## as the fix, and must say it is a file.
set N17F [file join $scratch n17plainfile]
catch {file delete -force -- $N17F}
set n17fh [open $N17F w] ; puts $n17fh {not a folder} ; close $n17fh
set ::netlist_dir $N17F
set N17AT [file normalize [set_netlist_dir 0]]
a_resetall
a_use ngcap-n17 $S_F1
set N17W [a_capfields ngspice {known unmeasured noplace_why noplace_at}]
set N17R [a_report ngspice 2]
set N17SAY [a_rep_msg $N17R]
set N17GOT [list $N17W [a_rep_rv $N17R] \
                 [expr {[file isdirectory $N17AT]}] \
                 [expr {[file isfile $N17AT]}] \
                 [expr {[string first $N17AT $N17SAY] >= 0}] \
                 [expr {[string first {is your simulation folder} $N17SAY] >= 0}] \
                 [expr {[string first {search permission} $N17SAY] >= 0}] \
                 [expr {[string first {is a file, not a folder} $N17SAY] >= 0}] \
                 [a_plain $N17SAY {} $N17AT]]
set N17EXP [list [list 0 noplace notdir $N17AT] cap_noplace 0 1 1 0 0 1 PLAIN]
a_nd $NDBASE
catch {file delete -force -- $N17F}
check {N17 a simulation folder setting that names an existing regular file is reported as a file, never as "your simulation folder", and is not offered a permission fix that cannot be carried out} $N17GOT $N17EXP

## ⚠ N18 -- THE ADVICE CLAUSE, which rows N14 and N15 CANNOT see. They compare
## what was said against `ase::sim_why`'s own mint, so ANY wording satisfies
## them: reverting the folder arm's advice to the old "Make it writable, or
## choose another one" left the whole suite ALL PASS (measured 2026-09-07, the
## close-out round's adversary). That wording is the one mode 0600 disproves --
## `chmod u+w` changes nothing there, the missing bit is SEARCH -- and it is the
## sentence the user is being asked to ratify on rule debt 0960. A sentence with
## no row can regress green, so this row greps the clause itself.
set N18SAY [a_ans ase::sim_why cap_noplace {} [file dirname $N5P] readonly]
check {N18 the folder arm's advice names SEARCH permission, not just write -- the mode 0600 shape is refused by the search bit and chmod u+w does not help} \
  [list [expr {[string first {search permission} $N18SAY] >= 0}] \
        [expr {[string first {write and search} $N18SAY] >= 0}] \
        [expr {[string first {Make it writable, or choose another one} $N18SAY] >= 0}]] \
  [list 1 1 0]

n_probe_free $N14DIR
n_probe_free $N15DIR
n_probe_free $N16DIR

n_probe_free $N9DIR
n_probe_free $N10DIR
n_probe_free $N12DIR
n_probe_free $N13DIR

a_nd $NDBASE
n_free $N1PLAIN
n_free $N1DIR
n_free $N3DIR
n_free $N4DIR
n_free $N7DIR

# ============================================================================
# P. THE CAPABILITY VOCABULARY -- THREE STATES, TWO PREDICATES, FOUR BANDS
#    ISSUE 1407
# ============================================================================
#
# Every row here drives LITERAL DICTS. No simulator is started, no fixture is
# ordered, no stub is installed -- so a red row is about the vocabulary and can
# be about nothing else.
#
# WHAT THIS SECTION IS FENCING. Before the vocabulary the tree asked the same
# question of one dict in TWENTY-EIGHT hand-written expressions across six
# procs. The defect a copy introduces is always the same one: fusing "nobody
# asked" with "the answer is no". P6/P7 are that fusion, in both directions.

proc p_corpus {} {
  set out {}
  foreach ns [list ::ase ::ase::ui] {
    foreach pr [info procs ${ns}::*] { lappend out $pr }
  }
  # ⚠ `info procs` DOES NOT DESCEND. The adapter lives in a CHILD namespace, so
  # a corpus built from `::ase::*` alone leaves every backend outside the rule.
  foreach ns [namespace children ::ase::backend] {
    foreach pr [info procs ${ns}::*] { lappend out $pr }
  }
  return [lsort -unique $out]
}
# A BARE READ OF ONE KEY, matched as a READ and not as a bare word: the trailing
# boundary is what stops `known` matching inside `unmeasured_keys`.
proc p_scan {pr key} {
  if {![llength [info commands $pr]]} { return NOPROC }
  if {[catch {info body $pr} b]} { return "RAISED:$b" }
  return [regexp -all "dict\[ \t\]+(exists|get)\[ \t\]+\\\$\[A-Za-z_\]+\[ \t\]+${key}(\[^A-Za-z0-9_\]|$)" [a_nocomment $b]]
}
proc p_scanall {key} {
  set n 0
  foreach pr [p_corpus] { set r [p_scan $pr $key] ; if {[string is integer -strict $r]} { incr n $r } }
  return $n
}
proc p_countcall {call} {
  set n 0
  foreach pr [p_corpus] {
    if {[catch {info body $pr} b]} { continue }
    incr n [a_count [a_nocomment $b] $call]
  }
  return $n
}

## --- P1: THE THREE STATES, as data -----------------------------------------
check {P1 the three states are data: nothing measured, the whole answer unmeasured, and a measured value -- 0 included} \
  [list [a_ans ase::caps_get {} usable] \
        [a_ans ase::caps_get {known 0} usable] \
        [a_ans ase::caps_get {known 1 usable 1} usable] \
        [a_ans ase::caps_get {known 1 usable 0} usable]] \
  [list {measured 0} {measured 0} {measured 1 value 1} {measured 1 value 0}]

## --- P2: `known` is META and answers about ITSELF ---------------------------
## Every other key is gated on it, so it cannot be gated on itself without the
## reader having no way to ask whether anything was measured at all.
check {P2 the known key answers about itself -- present is a measurement even when its value is 0, absent is not} \
  [list [a_ans ase::caps_get {} known] \
        [a_ans ase::caps_get {known 0} known] \
        [a_ans ase::caps_get {known 1} known]] \
  [list {measured 0} {measured 1 value 0} {measured 1 value 1}]

## --- P3: `value` is ABSENT, never empty, when nothing was measured ----------
## ⚠ THE RAISE IS THE POINT. A caller who reads `value` without reading
## `measured` gets an error that shows up in a row, instead of a fabricated 0
## that shows up in a user's Outputs pane six months later.
set P3U [a_ans ase::caps_get {known 0} usable]
check {P3 an unmeasured answer carries NO value key at all, so reading it without reading measured first RAISES rather than fabricating a 0} \
  [list [dict exists $P3U value] \
        [catch {dict get $P3U value}] \
        [dict get $P3U measured]] \
  [list 0 1 0]

## --- P4: the WHOLE-ANSWER provenance reaches every capability key -----------
check {P4 when the whole answer is unmeasured the probe's reason reaches every capability key, so a reader can say WHY and not only THAT} \
  [list [a_ans ase::caps_get {known 0 unmeasured timeout} usable] \
        [a_ans ase::caps_get {known 0 unmeasured noplace} appendwrite]] \
  [list {measured 0 why timeout} {measured 0 why noplace}]

## --- P5: the PER-KEY provenance, on an answer that IS known -----------------
## This is the whole delivery of `unmeasured_keys`: the probe ran, three legs
## answered and one did not, and the one that did not says so BY NAME while the
## others stay measured.
check {P5 a probe that ran and lost one leg records WHICH key it lost, and the legs that answered stay measured} \
  [list [a_ans ase::caps_get {known 1 usable 1 unmeasured_keys {casemode_detected timeout}} casemode_detected] \
        [a_ans ase::caps_get {known 1 usable 1 unmeasured_keys {casemode_detected timeout}} usable] \
        [a_ans ase::caps_get {known 1 usable 1 unmeasured_keys {casemode_detected timeout}} altshow_op_dump]] \
  [list {measured 0 why timeout} {measured 1 value 1} {measured 0}]

## --- P6: the GATE-UP predicate. UNMEASURED ANSWERS 0 ------------------------
check {P6 asking may-I-offer-this answers no for a build nobody measured, yes only for a measured yes} \
  [list [a_ans ase::caps_is {} appendwrite 1] \
        [a_ans ase::caps_is {known 0} appendwrite 1] \
        [a_ans ase::caps_is {known 1} appendwrite 1] \
        [a_ans ase::caps_is {known 1 appendwrite 0} appendwrite 1] \
        [a_ans ase::caps_is {known 1 appendwrite 1} appendwrite 1]] \
  [list 0 0 0 0 1]

## --- P7: THE FUSION, IN BOTH DIRECTIONS -- and it is the row that matters ---
## ⚠ `![caps_is $c usable 1]` AND `caps_measured_as $c usable 0` ARE NOT THE
## SAME QUESTION, and the difference is exactly a program nobody measured. The
## first calls it "not a simulator"; the second says nothing. That is issue
## 0953, and ase::cap_report is the proc it was filed against.
set P7UN {known 0}
set P7NO {known 1 usable 0}
check {P7 a negative gate spelled as NOT-a-positive-gate fires on a program nobody measured, and the mitigation predicate does not -- they differ on exactly that program} \
  [list [expr {![a_ans ase::caps_is $P7UN usable 1]}] \
        [a_ans ase::caps_measured_as $P7UN usable 0] \
        [expr {![a_ans ase::caps_is $P7NO usable 1]}] \
        [a_ans ase::caps_measured_as $P7NO usable 0]] \
  [list 1 0 1 1]

## --- P8: STRUCTURAL -- the hand reads are GONE from the five readers --------
## ⚠ WITH ITS OWN NAMED EXEMPTION. ase::sim_capabilities_at's `known` test is
## the PRODUCER'S CACHE-WRITE GATE and must NOT convert: routing the writer
## through the readers' predicate makes what is remembered depend on the rule
## for reading what was remembered. The control below asserts that exemption is
## still exactly ONE read, so deleting it or adding a second both redden.
set P8R {}
foreach P8P {::ase::casemode_detected_in ::ase::casemode_selectable_in
             ::ase::casemode_report ::ase::cap_report ::ase::op_save_tier} {
  set P8N 0
  foreach P8K {known usable appendwrite hier_op_names blanket_op_save
               altshow_op_dump casemode_detected unmeasured} {
    set P8V [p_scan $P8P $P8K]
    if {[string is integer -strict $P8V]} { incr P8N $P8V } else { set P8N $P8V ; break }
  }
  lappend P8R $P8N
}
## ⚠ THE EXEMPTION COUNTS **2**, AND MEASURING IT IS WHY THIS ROW IS WORTH
## HAVING. It is ONE guard on ONE line -- `[dict exists $caps known] && [dict get
## $caps known] == 1` -- but p_scan counts READS, not lines, and that line makes
## two of them. The first expectation written here was 1, taken from the count of
## LINES in the census; the code was right and the expectation was wrong. Keep it
## at 2: deleting the exemption gives 0 and converting it gives 0, and adding a
## second guard gives 4, so every direction still reddens.
check {P8 STRUCTURAL the five capability READERS carry no hand-written dict read of a capability key, and the producer's cache-write gate keeps exactly the one guard it is exempted for -- two reads on one line} \
  [list $P8R [p_scan ::ase::sim_capabilities_at known]] \
  [list {0 0 0 0 0} 2]

## --- P9: STRUCTURAL -- and the corpus really reaches the ADAPTER ------------
## The non-vacuity control is the second element: a corpus that silently failed
## to descend into ::ase::backend::ngspice would report zero for everything and
## look like a clean tree.
check {P9 STRUCTURAL the scanned corpus reaches the adapter's own child namespace, so a hand read hiding there is inside the rule and not outside it} \
  [list [expr {[llength [p_corpus]] > 200}] \
        [expr {[lsearch -exact [p_corpus] ::ase::backend::ngspice::capabilities] >= 0}]] \
  [list 1 1]

## --- P10: the WRITER ---------------------------------------------------------
check {P10 recording that a leg did not deliver adds the key by name and disturbs nothing that was measured} \
  [list [a_ans ase::caps_unmeasured {known 1 usable 1} altshow_op_dump timeout] \
        [a_ans ase::caps_unmeasured_keys {known 1 unmeasured_keys {a b}}] \
        [a_ans ase::caps_unmeasured_keys {known 1}]] \
  [list {known 1 usable 1 unmeasured_keys {altshow_op_dump timeout}} {a b} {}]

## --- P11: TWO legs lost, and BOTH recorded ----------------------------------
## ⚠ THIS ROW IS CHAINED ON PURPOSE. Against a dict with no prior
## `unmeasured_keys` the correct body and a body that OVERWRITES the dict
## produce a byte-identical answer, so a single-call row cannot redden its own
## sabotage. The chain is what a real probe does -- two legs cut in one run --
## and it is the only shape that tells the two bodies apart.
set P11 [ase::caps_unmeasured [ase::caps_unmeasured {known 1 usable 1} \
           casemode_detected timeout] altshow_op_dump timeout]
check {P11 a probe that loses TWO legs records BOTH, rather than the second erasing the first} \
  [list [a_ans ase::caps_get $P11 casemode_detected] \
        [a_ans ase::caps_get $P11 altshow_op_dump] \
        [a_ans ase::caps_get $P11 usable]] \
  [list {measured 0 why timeout} {measured 0 why timeout} {measured 1 value 1}]

## --- P12: the ADAPTER uses the sanctioned writer and no other ---------------
check {P12 STRUCTURAL the adapter records a lost leg through the one sanctioned writer and never by building the provenance dict by hand} \
  [list [a_count [a_nocomment [a_body ::ase::backend::ngspice::capabilities]] {dict set out unmeasured_keys}] \
        [expr {[a_count [a_nocomment [a_body ::ase::backend::ngspice::capabilities]] {ase::caps_unmeasured }] >= 2}]] \
  [list 0 1]

## --- P13: THE COMPARISON IS STRING EQUALITY, AND IT IS NOT WHAT WAS THERE ----
## ⚠ RECORDED AS A BEHAVIOUR CHANGE, NOT AS AN IDENTITY. The guards this
## replaced were `== 1` / `== 0`, which are NUMERIC: `appendwrite '0.0'` was a
## match and is not one now, and an `altshow_op_dump` of `'1.0'` moves
## ase::op_save_tier from tier d to tier c. Latent for the shipped adapter --
## measured, all four values are expr-produced literal 0/1 -- and NOT latent for
## the second adapter this schema exists for. AN ADAPTER MUST PUBLISH CANONICAL
## 0 OR 1, and this row is where that requirement is written down as a fact.
check {P13 the predicates compare as STRINGS, so a non-canonical 0.0 or 1.0 is not a match and an adapter must publish canonical 0 or 1} \
  [list [a_ans ase::caps_measured_as {known 1 appendwrite 0.0} appendwrite 0] \
        [expr {{0.0} == 0}] \
        [a_ans ase::caps_is {known 1 altshow_op_dump 1.0} altshow_op_dump 1] \
        [expr {{1.0} == 1}]] \
  [list 0 1 0 1]

## --- P14: STRUCTURAL -- NO PREDICATE IS POINTED AT A LIST-VALUED KEY --------
## ⚠ WRONG **TODAY**, ON A BINARY A USER CAN HAVE, not in theory:
## `casemode_detected` is {fold} on apt 45.2 and {fold preserve distinguish} on
## the fork, so `caps_is $c casemode_detected fold` answers 1 on one box and 0 on
## the other. The second element is the non-vacuity control -- the corpus must
## contain at least one caps_get on that key, or a corpus that found nothing at
## all would pass this row.
check {P14 STRUCTURAL no boolean predicate is pointed at a list-valued capability key, and the list key really is read somewhere by the reader that can serve it} \
  [list [expr {[p_countcall {ase::caps_is $caps casemode_detected}] \
             + [p_countcall {ase::caps_measured_as $caps casemode_detected}] \
             + [p_countcall {ase::caps_is $c casemode_detected}] \
             + [p_countcall {ase::caps_measured_as $c casemode_detected}]}] \
        [expr {[p_countcall {ase::caps_get $caps casemode_detected}] >= 1}] \
        [a_ans ase::caps_list_valued]] \
  [list 0 1 casemode_detected]

## --- P15: NO GATE-UP PREDICATE UNDER A `!` ---------------------------------
## ⚠ THIS ROW EXISTS BECAUSE THE SABOTAGE THAT SHOULD HAVE REDDENED SECTION P
## WENT GREEN. Respelling ase::cap_report's refusal as
## `![ase::caps_is $c usable 1]` -- the exact defect the vocabulary was written
## to prevent, issue 0953 re-filed -- passed all fourteen rows. P7 proves the two
## predicates DIFFER; nothing proved the callers picked the right one.
##
## THE RULE IS THE CONSERVATIVE ONE, AND THE REASON IS THAT THE CALL SITE CANNOT
## SHOW YOU WHICH CASE IT IS. `![caps_is $c k 1]` is honest for "may I OFFER
## this?" -- you may not offer what nobody measured -- and a defect for "may I
## ACCUSE this program?", where unmeasured must stay silent. The two read
## identically. So the positive spelling is required in both: `caps_is` for the
## permission, `caps_measured_as` for the accusation, and neither under a `!`.
## Zero uses exist today, so the ban costs nothing now and forces the next author
## to say which question they are asking.
proc p_notpred {} {
  set n 0
  foreach pr [p_corpus] {
    if {[catch {info body $pr} b]} { continue }
    set b [a_nocomment $b]
    foreach form {{![ase::caps_is} {! [ase::caps_is} {![::ase::caps_is}
                  {![ase::caps_measured_as} {![::ase::caps_measured_as}} {
      incr n [a_count $b $form]
    }
  }
  return $n
}
check {P15 STRUCTURAL neither predicate is ever read through a NOT -- the permission and the accusation are both spelled positively, because the call site cannot show which one it is} \
  [list [p_notpred] \
        [expr {[p_countcall {ase::caps_is $caps}] + [p_countcall {ase::caps_measured_as $c}] >= 3}]] \
  [list 0 1]

# ============================================================================
# Q. WHICH ANALYSES THIS BUILD ACTUALLY HAS -- ISSUE 1409
# ============================================================================
#
# ASE-L never asked the simulator which analyses it can run, so the list was a
# guess -- four types, hardcoded, on every build. This section fences the leg
# that asks.
#
# ⚠ EVERY CANNED FIXTURE BELOW IS **VERBATIM MEASURED TEXT**, taken 2026-09-11
# from all three preflight binaries (/usr/bin/ngspice 45.2, the fork's
# build-ver_50, and a bare upstream 47). Nothing here is invented, because a
# fixture nobody measured proves the parser agrees with the fixture and says
# nothing about ngspice.
#
# THE FOUR RULES, EACH WITH ITS MEASUREMENT:
#   * the verdict is read from the FILE, never the exit code -- and the measured
#     reason is sharper than "the deck exits nonzero". Deck C, which carries the
#     leg and HAS a circuit, exits **0** on all three; a circuit-less probe deck
#     exits **1**; and BOTH write their files. rc tracks whether a CIRCUIT was
#     parsed and says nothing about whether the help answers arrived. ⚠ An
#     earlier revision of this comment said "all three exit 1" -- measured on a
#     probe deck of the author's own construction rather than on deck C, so true
#     of that deck and false of this one. A measurement is about the exact
#     artifact it was taken on;
#   * a stanza counts only when its FIRST TOKEN is the verb probed -- `help tf`
#     prints `tf [.tran line args] : Do a transient analysis.` on all three, the
#     wrong bracket AND the wrong sentence, and a rule matching the DESCRIPTION
#     would read `tf` as absent on every ngspice ever shipped;
#   * the comparison is CASE-INSENSITIVE -- ngspice looks the verb up with
#     `eqc()` = `cieq()`, so `help TRAN` answers the lower-case `tran` stanza and
#     the failure line echoes the verb FOLDED (`help XXNOSUCH` -> `Sorry, no help
#     for xxnosuch.`);
#   * never `help all`.

## The three measured cap.txt shapes, verbatim.
set Q_APT {== op
op [.op line args] : Determine the operating point of the circuit.
== tf
tf [.tran line args] : Do a transient analysis.
== pss
pss [.pss line args] : Do a periodic state analysis.
== sp
sp [.sp line args] : Do an S-parameter analysis.
}
set Q_STOCK47 {== op
op [.op line args] : Determine the operating point of the circuit.
== tf
tf [.tran line args] : Do a transient analysis.
== pss
Sorry, no help for pss.
== sp
sp [.sp line args] : Do an S-parameter analysis.
}
set Q_TOKS {{op op} {tf tf} {pss pss} {sp sp}}
## devhelp, verbatim -- name padded to column 21, then `:`, then a TAB.
set Q_FAM "Capacitor            :\tFixed capacitor
Resistor             :\tSimple linear resistor
NUMD                 :\tDiode
adc_bridge           :\tAnalog to digital bridge
not a device line at all
"
set Q_NS ase::backend::ngspice

## --- Q1: THE PROBE TOKEN HAS A SOURCE AGAIN ---------------------------------
## ⚠ Stage 1 DELETED the `verb` key (correction C41) as two ngspice words in the
## schema half, so the token had no source at all. It comes from the FIRST WORD
## OF WHAT THE ADAPTER EMITS, via ase::analysis_card_tmpl -- which core can ask
## for without learning any ngspice.
##
## ⚠ THE ROW ASSERTS THE FIRST WORD, NOT THE WHOLE TEMPLATE, AND THAT IS A
## CORRECTION MADE IN STAGE 3. It used to pin `{dc @source @start @stop @step}`
## verbatim, so the moment dc gained its second sweep nest the row went red for a
## reason that has nothing to do with its subject -- exactly the failure ase.tcl
## warns about beside ase::analysis_expand. What it pins now is the CLAIM: the
## probe token is the template's FIRST word, the template is longer than that one
## word, and its second token is a slot. A sabotage returning the bare string
## `dc` instead of reading the template still reds it.
check {Q1 the word each analysis is probed with is the first word of what this adapter emits, so the schema never has to carry the simulator's vocabulary} \
  [list [lindex [a_ans ase::analysis_card_tmpl ngspice dc] 0] \
        [expr {[llength [a_ans ase::analysis_card_tmpl ngspice dc]] > 1}] \
        [string index [lindex [a_ans ase::analysis_card_tmpl ngspice dc] 1] 0] \
        [a_ans ase::analysis_card_tmpl ngspice zznosuchtype]] \
  [list dc 1 @ {}]

## --- Q2: AND IT MUST NOT GO THROUGH THE ROW-TAKING READER -------------------
## ⚠ ase::analysis_cards resolves @slots with `dict get $row <field>`, so with
## only a type in hand it RAISES on every type that has required fields.
## MEASURED: op answers, dc/ac/tran raise. A driver following the plan's text
## would have reached for analysis_line and got a raise on three of four types.
set Q2 {}
foreach q2t {op dc ac tran} {
  ## ⚠ BRACE THE WORDS. `expr {... ? RAISES : ok}` is a BAREWORD in Tcl 8.6 and
  ## aborts the whole file -- which cost this section one run, and cost section L
  ## one before it. The tell is the count going DOWN, which is what the floor
  ## paragraph above exists to make visible.
  if {[catch {ase::analysis_expand [dict create type $q2t] \
               [ase::analysis_card_tmpl ngspice $q2t]}]} {
    lappend Q2 RAISES
  } else {
    lappend Q2 ok
  }
}
check {Q2 the row-free reader is necessary: expanding a template without a row raises for every type that has required fields, which is three of the four} \
  [list $Q2 [a_ans ase::analysis_card_tmpl ngspice op]] \
  [list {ok RAISES RAISES RAISES} op]

## --- Q3: THE FIRST-TOKEN RULE, AGAINST THE UPSTREAM COPY-PASTE BUG ----------
check {Q3 a stanza counts on its FIRST TOKEN, so tf is found present even though upstream prints the tran bracket and the tran sentence for it} \
  [a_ans ${Q_NS}::cap_help_verdict $Q_APT $Q_TOKS] {op tf pss sp}

## --- Q4: A `Sorry` LINE IS AN ABSENCE, AND THIS IS THE ONLY LIVE ONE --------
## ⚠ `pss` ON STOCK 47 IS THE ONLY REPRODUCIBLE `absent` FIXTURE ON THIS
## MACHINE. Measured: `help sp` ANSWERS on apt 45.2, on the fork AND on stock 47,
## so PLAN.md's `--enable-rfspice` example cannot be demonstrated here at all.
check {Q4 the verb a build was made without is absent, and every other verb in the same file is unaffected} \
  [a_ans ${Q_NS}::cap_help_verdict $Q_STOCK47 $Q_TOKS] {op tf sp}

## --- Q5: THE COMPARISON IS CASE-INSENSITIVE ---------------------------------
## ngspice resolves the verb with cieq(), so the stanza can come back in a
## different case from the question. A case-SENSITIVE rule reads it as absent.
check {Q5 a stanza answered in a different case than it was asked in still counts, because the simulator folds the lookup} \
  [list [a_ans ${Q_NS}::cap_help_verdict "== TRAN\ntran [list .tran line args] : Do a transient analysis.\n" {{tran TRAN}}] \
        [a_ans ${Q_NS}::cap_help_verdict "== tran\nTRAN [list .tran line args] : Do a transient analysis.\n" {{tran tran}}]] \
  {tran tran}

## --- Q6: AN EMPTY VERDICT PUBLISHES **NO KEY** ------------------------------
## ⚠ THE MOST DANGEROUS LINE IN THE ITEM. An empty list on a `known 1` answer
## reads as "this binary has NO analyses" and empties the grid; a MISSING key
## reads as "not measured" and falls back to the source-verified baseline. They
## are OPPOSITE answers to the user, and the difference is one `ne {}` guard.
check {Q6 STRUCTURAL the analyses key is published only for a NON-EMPTY verdict, because an empty list would say this binary has no analyses at all} \
  [list [a_count [a_nocomment [a_body ${Q_NS}::capabilities]] {if {$anames ne {}}}] \
        [a_ans ${Q_NS}::cap_help_verdict "== op\nSorry, no help for op.\n" {{op op}}]] \
  [list 1 {}]

## --- Q7: devhelp NAMES ARE MIXED CASE ---------------------------------------
## Measured on apt 45.2: 56 capitalised against 81 lower-initial. Folding them
## here would publish a list no reader could match against the binary's own
## spelling; the readers fold instead (ase::caps_family_state).
check {Q7 the device list keeps the binary's own spelling, mixed case and all, and lines that are not device lines are not names} \
  [a_ans ${Q_NS}::cap_devices_verdict $Q_FAM] {Capacitor Resistor NUMD adc_bridge}

## --- Q8: THE spinit TRAP -- AND IT IS A FABRICATED ABSENCE, NOT A SMALL LIST -
## ⚠ MEASURED: stock 47, uninstalled, logs `Warning: can't find the
## initialization file spinit.` and its devhelp answers **52** names against 136
## on apt 45.2 and 138 on the fork -- it loses every XSPICE code model.
## Publishing 52 as a fact about that binary would make the readers refuse
## analyses that would have run.
## ⚠ AND IT IS GREPPED, NEVER COUNTED. The count is exactly what the missing
## models move, so a threshold would be a guess about a number nobody controls.
check {Q8 a build whose initialisation file never loaded is not asked what devices it has, because its answer is short by every code model} \
  [list [a_ans ${Q_NS}::cap_devices_trustworthy {Circuit: probe}] \
        [a_ans ${Q_NS}::cap_devices_trustworthy \
          "Warning: can't find the initialization file spinit.\nCircuit: probe"] \
        [a_count [a_nocomment [a_body ${Q_NS}::cap_devices_trustworthy]] {spinit}]] \
  {1 0 1}

## --- Q9: CIDER IS GREPPED, NOT COUNTED --------------------------------------
check {Q9 the CIDER families are found by name in the device list, so a build that lost eighty other rows is still read correctly} \
  [list [a_ans ase::caps_family_state [dict create known 1 devices_available \
           [a_ans ${Q_NS}::cap_devices_verdict $Q_FAM]] devices_available NUMD] \
        [a_ans ase::caps_family_state [dict create known 1 devices_available \
           [a_ans ${Q_NS}::cap_devices_verdict $Q_FAM]] devices_available numd]] \
  {present present}

## --- Q10: THE THIRD STATE, AND IT IS NOT `absent` ---------------------------
## ⚠ `unknown` MUST NEVER BECOME A REFUSAL. `osdi_add_device` appends OpenVAF
## devices to the device list at LOAD time, so a devhelp taken against a SCRATCH
## deck CANNOT see a PDK's Verilog-A devices. Fusing unknown with absent produces
## the worst outcome this design can produce -- refusing something that would
## have run -- and on any Verilog-A PDK it would be the LIKELY outcome.
check {Q10 a device family nobody measured reads as unknown and never as absent, because a probe run against a scratch deck cannot see a PDK's own devices} \
  [list [a_ans ase::caps_family_state {known 0} devices_available NUMD] \
        [a_ans ase::caps_family_state {known 1} devices_available NUMD] \
        [a_ans ase::caps_family_state {known 1 devices_available Capacitor} devices_available NUMD]] \
  {unknown unknown absent}

## --- Q11: `analyses_probed` IS A DIFFERENT FACT FROM `analyses_available` ----
## A cache taken before a type was registered says nothing about that type.
## Without this key a reader cannot tell "measured absent" from "was not among
## the questions" -- the absent-versus-unknown fusion the capability vocabulary
## exists to prevent, one level up.
check {Q11 STRUCTURAL the list of types that were ASKED about is published beside the list that answered, so a cache older than a type does not read as a no} \
  [list [a_count [a_nocomment [a_body ${Q_NS}::capabilities]] {dict set out analyses_probed}] \
        [a_count [a_nocomment [a_body ${Q_NS}::capabilities]] {dict set out analyses_available}]] \
  {1 1}

## --- Q12: NEVER `help all`, AND THE REFUSAL IS STRUCTURAL -------------------
## ⚠ MEASURED, AND THE REASON THIS ROW EXISTS: `help all` TODAY lists every
## analysis verb and DOES distinguish pss present from absent -- it would
## accidentally work. Its count loop stops at the first NULL `co_func`, which is
## `while` in commands.c, and the analysis verbs sit above it. The refusal is ONE
## table edit away from being load-bearing, so it is fenced now rather than after
## a later reader "simplifies" eleven help calls into one.
check {Q12 STRUCTURAL the leg asks one verb at a time and never asks for all of them at once} \
  [list [a_count [a_nocomment [a_body ${Q_NS}::cap_help_lines]] {help all}] \
        [expr {[a_count [a_nocomment [a_body ${Q_NS}::cap_help_lines]] {help }] >= 1}]] \
  {0 1}

## --- Q13: THE PROBED SET IS THE ADAPTER'S, NOT THE DISPLAY SWITCH'S ---------
## ⚠ `ase::analysis_offered` filters on `registered`, which is ASE-L's DISPLAY
## switch. Sourcing the probe from it would change the probed set without
## changing the binary -- and the cache, keyed on the binary's path, mtime and
## size, would never notice.
check {Q13 STRUCTURAL the types probed come from what the adapter DESCRIBES, never from what ASE-L currently chooses to display} \
  [list [a_count [a_nocomment [a_body ${Q_NS}::cap_probe_tokens]] {analysis_types}] \
        [a_count [a_nocomment [a_body ${Q_NS}::cap_probe_tokens]] {analysis_offered}]] \
  {1 0}

## --- Q14: THE KEY HOLDS REGISTRY TYPE KEYS, NOT COMMAND WORDS ---------------
## They coincide for all four shipped ngspice entries and will not for the first
## adapter whose emitted word differs from its type name. Core compares this list
## against ase::analysis_offered, which is type keys.
set Q14 [a_ans ${Q_NS}::cap_help_verdict $Q_APT {{zzalias tf}}]
check {Q14 the published list names the REGISTRY TYPE, not the word the simulator was asked with, so a type whose command word differs is still reported under its own name} \
  $Q14 zzalias

## --- Q15: THE REAL BINARY, END TO END ---------------------------------------
## ⚠ ONE ROW AGAINST THE PROGRAM THE REGISTRY RESOLVES TO, because every row
## above is a stand-in and a stand-in can never prove another program's parser.
## SELF-RELATIVE: it asserts the leg agrees with the registry rather than naming
## a count, so it keeps measuring the tree the day more types are registered.
a_resetall
set Q15C [a_ans ase::sim_capabilities ngspice]
set Q15A [a_ans ase::caps_get $Q15C analyses_available]
set Q15D [a_ans ase::caps_get $Q15C devices_available]
if {[string is list $Q15C] && [dict exists $Q15C known] && [dict get $Q15C known] eq {1}} {
  ## ⚠ SELF-RELATIVE, AND ITS FIRST FORM WAS WRONG. It asserted
  ## `analyses_available == analysis_offered`, which held only while the probed set
  ## and the offered set happened to coincide. They are DIFFERENT QUESTIONS: the
  ## offered set is what the adapter describes, the available set is what the
  ## BINARY answered to, and a build missing a verb must make them differ -- that
  ## is the whole point of measuring. The fourth term is the one that cannot be
  ## satisfied by accident: a type the adapter never named reads **`unknown`**
  ## against a real `known 1` answer -- NOT `absent` -- because `analyses_probed`
  ## does not list it either, and a type that was never ASKED about is not a type
  ## measured to be missing. That is the absent-versus-unknown distinction this
  ## commit exists for, proved against the real binary, and the expectation
  ## written here first said `absent`: the code was right and the row was wrong.
  check {Q15 the real simulator this registry resolves to answers which analyses it has, its device list comes back non-empty, and a type it was never asked about reads absent against that answer} \
    [list [dict get $Q15A measured] \
          [expr {[llength [dict get $Q15A value]] > 0}] \
          [expr {[dict get $Q15D measured] && [llength [dict get $Q15D value]] > 20}] \
          [ase::caps_analysis_present zznosuchanalysis $Q15C]] \
    {1 1 1 unknown}
} else {
  puts "SKIPPED: Q15 (no usable simulator resolved -- known was not 1)"
}
a_resetall

# ============================================================================
# L. A RE-REGISTERED BACKEND MUST NOT KEEP ANSWERING FROM THE REGISTRY IT
#    REPLACED -- ISSUE 1406
# ============================================================================
# U. THE FREE PEEK, AND THE ONE COLD DOOR -- ISSUE 1410
# ============================================================================
#
# ⚠ THE DIALOG MUST NEVER START A PROGRAM. The measured worst case for a binary
# that exists, is executable and never answers is **31.2 s with Tk frozen**; a
# cold probe in front of the analyses list would make opening it take that long.
# Only Detect may pay that. These rows are about a probe that must NOT happen, so
# they use the counting hook -- a proc that counts is the only way to see one that
# did.

set ::UPROBES 0
proc u_cap_counting {args} {
  incr ::UPROBES
  return [dict create known 1 usable 1 appendwrite 1 blanket_op_save 0 \
                      hier_op_names 1 analyses_available {zzbase} \
                      analyses_probed {zzbase zzgate}]
}
proc u_types {} {
  return [dict create \
    zzbase [dict create label zzbase baseline 1 registered 1 emitorder 10 \
              emit {{role analysis tmpl {zzbase}}}] \
    zzgate [dict create label zzgate baseline 0 registered 1 emitorder 20 \
              emit {{role analysis tmpl {zzgate}}}]]
}
proc u_five {} {
  return [dict create \
    render_deck  [a_ans ase::backend_hook ngspice render_deck] \
    run_cmd      [a_ans ase::backend_hook ngspice run_cmd] \
    log_file     [a_ans ase::backend_hook ngspice log_file] \
    result_probe [a_ans ase::backend_hook ngspice result_probe] \
    raw_file     [a_ans ase::backend_hook ngspice raw_file]]
}
## ⚠ A PROGRAM OF THIS NAME MUST SIT ON THE PATH, or row U2 cannot be built at
## all. Guard 1 protects the case `ok 0` WITH a non-empty `resolved` -- the file a
## wrong choice would have started -- and with nothing on the PATH `resolved` comes
## back EMPTY and the guard one line below catches it instead. Written the same way
## `zzcapwrong` is, at the head of this file.
a_wr [file join $BIN zzupeek] "#!/bin/sh\nexit 0\n" 0755
a_ans ase::register_backend zzupeek [dict merge [u_five] \
  [dict create analysis_types u_types capabilities u_cap_counting]]
## ⚠ THE SAME TYPES, NO `capabilities` HOOK. This backend is the one that makes
## `noprobe` a different fact from `unmeasured`: Detect against it can never learn
## anything, for ever.
a_ans ase::register_backend zzunoprobe [dict merge [u_five] \
  [dict create analysis_types u_types]]

## --- U1: THE PEEK IS FREE, AND IT ANSWERS `{}` RATHER THAN `{known 0}` ------
## ⚠ `{}` NOT `{known 0}`, AND THE DIFFERENCE IS A CLAIM. With the capability
## vocabulary in place `[ase::caps_get {} k]` and `[ase::caps_get {known 0} k]` are
## byte-identical, so `{}` costs a reader nothing -- and `{known 0}` would ASSERT a
## probe that never ran.
a_resetall
set ::UPROBES 0
a_use ngcap-u1 $S_GOOD
set U1PEEK [a_ans ase::sim_caps_cached ngspice]
check {U1 asking what is already known about a simulator starts no program, and answers that nothing is recorded rather than that nothing is true} \
  [list $U1PEEK $::UPROBES \
        [expr {[a_ans ase::caps_get $U1PEEK usable] \
           eq [a_ans ase::caps_get {known 0} usable]}]] \
  [list {} 0 1]

## --- U2: GUARD 1 -- A REFUSED RESOLUTION IS NOT READ (issue 0935) -----------
## ⚠ A `sim_status` that says NO still carries a `resolved` naming a real file on
## the PATH -- the file a WRONG choice would have started. Reading the cache under
## THAT key hands back an answer measured about a program the resolver has already
## refused, and attributes it to the simulator the user is actually using.
##
## ⚠ THE FIXTURE TOOK **THREE** ATTEMPTS AND THE FIRST TWO WERE BLIND, WHICH IS
## THE POINT OF WRITING IT DOWN. (1) Nothing registered: `resolved` came back
## EMPTY and the empty-path guard one line below catches that on its own.
## (2) A program of the right name on the PATH, but nothing ever cached under its
## key: the lookup misses and both answers are `{}`. Deleting guard 1 outright left
## the row GREEN both times. The case the guard exists for needs ALL THREE of
## `ok 0`, a NON-EMPTY `resolved`, and a cache entry sitting under exactly that
## key -- so this row WARMS the cache while the entry is honoured, then re-points
## the selection and asks again.
a_resetall
set ::UPROBES 0
## phase 1 -- the entry IS honoured, so a real answer lands in the cache
## ⚠ BOTH ENTRIES ARE REGISTERED **BEFORE** THE WARM. `ase::sim_register` calls
## `ase::sim_caps_clear` (issue 0950), so registering the second entry after the
## probe would empty the very cache this row needs warm -- and the sabotage would
## pass for that reason instead of for the guard.
a_ans ase::sim_register zzupeek [file join $BIN zzupeek] -backend zzupeek
a_ans ase::sim_register ngcap-u2 $S_GOOD -backend ngspice
a_ans ase::sim_select zzupeek
set U2WARM [a_ans ase::sim_capabilities zzupeek]
set U2N1 $::UPROBES
## phase 2 -- a DIFFERENT entry is SELECTED (selection does not clear the cache),
## so the resolver refuses zzupeek while `resolved` still names the same PATH
## program the warm entry is keyed on
a_ans ase::sim_select ngcap-u2
set U2ST [a_ans ase::sim_status zzupeek]
if {[string is list $U2ST] && [dict exists $U2ST ok]} {
  set U2OK [dict get $U2ST ok] ; set U2RES [expr {[dict get $U2ST resolved] ne {}}]
} else { set U2OK $U2ST ; set U2RES $U2ST }
check {U2 a simulator the resolver has refused is not peeked at, even when a real measurement about a program of that name is sitting in the cache -- because the answer is about the program a WRONG choice would have started} \
  [list $U2N1 $U2OK $U2RES [a_ans ase::sim_caps_cached zzupeek] \
        [expr {$::UPROBES - $U2N1}]] \
  [list 1 0 1 {} 0]

## --- U3: DETECT IS THE ONLY COLD DOOR ---------------------------------------
a_resetall
set ::UPROBES 0
a_use zzupeek-u3 $S_GOOD
a_ans ase::sim_register zzupeek $S_GOOD
set U3BEFORE [a_ans ase::sim_caps_cached zzupeek]
set U3N0 $::UPROBES
set U3DET [a_ans ase::analysis_detect zzupeek]
set U3N1 $::UPROBES
set U3AFTER [a_ans ase::sim_caps_cached zzupeek]
check {U3 nothing is measured until Detect is pressed, Detect measures exactly once, and the answer is on record afterwards without measuring again} \
  [list $U3BEFORE $U3N0 [expr {$U3N1 - $U3N0}] \
        [dict get [a_ans ase::caps_get $U3AFTER analyses_available] measured] \
        [expr {$::UPROBES - $U3N1}]] \
  [list {} 0 1 1 0]

## --- U4: AND THE GRID CHANGES BECAUSE OF IT --------------------------------
## Cold, `zzbase` is offered on a source-verified invariant and `zzgate` -- which
## claims no such invariant -- is absent-but-askable. After Detect both are facts.
check {U4 before Detect one type is offered on the claim that every build has it and the other is not offered at all, and after Detect both answers are measurements} \
  [list [a_ans ase::analysis_states zzupeek [a_ans ase::sim_caps_cached zzupeek]]] \
  [list {{zzbase ok measured} {zzgate absent notpresent}}]

## --- U5: DETECT ON A BACKEND THAT CANNOT BE MEASURED IS A **PERMANENT** NO-OP
## ⚠ THIS IS WHY `noprobe` EXISTS AS A SEPARATE TOKEN. `unmeasured` is the token
## that carries Detect; here Detect can never learn anything, so a cell reading
## `unmeasured` would put a button in front of the user that does nothing, for
## ever. MEASURED: the state list is byte-identical before, after, and after a
## second Detect.
a_resetall
set U5A [a_ans ase::analysis_states zzunoprobe [a_ans ase::sim_caps_cached zzunoprobe]]
a_ans ase::analysis_detect zzunoprobe
set U5B [a_ans ase::analysis_states zzunoprobe [a_ans ase::sim_caps_cached zzunoprobe]]
a_ans ase::analysis_detect zzunoprobe
set U5C [a_ans ase::analysis_states zzunoprobe [a_ans ase::sim_caps_cached zzunoprobe]]
check {U5 for a simulator nothing can ever measure, the reason says so instead of offering a Detect that will never learn anything -- and pressing it twice changes nothing} \
  [list $U5A [expr {$U5A eq $U5B}] [expr {$U5B eq $U5C}] \
        [a_ans ase::sim_has_probe zzunoprobe] \
        [a_ans ase::sim_has_probe zzupeek]] \
  [list {{zzbase ok baseline} {zzgate absent noprobe}} 1 1 0 1]

## --- U6: DETECT NEVER RAISES, AND ITS TWO EMPTY ANSWERS DIFFER -------------
## A Detect on a name nothing knows is a no-op, not an error -- the button is in a
## dialog and a raise there is a stack trace in front of the user.
## ⚠ AND `{}` IS NOT `{known 0}` HERE, DELIBERATELY. `{}` means THERE IS NO SUCH
## SIMULATOR -- nothing to detect and nothing for the dialog to re-read. `{known 0}`
## means there IS one and nothing is known, which is a measurement OUTCOME and may
## carry the reason `ase::cap_report` needs (`unmeasured timeout`, `noplace`).
## Collapsing them would throw that reason away, so the row pins both.
check {U6 pressing Detect for a simulator that is not registered answers that there is no such simulator, while a registered one that cannot be measured answers that nothing is known -- two different facts} \
  [list [a_ans ase::analysis_detect zznosuchsimulator] \
        [a_ans ase::sim_caps_cached zznosuchsimulator] \
        [dict exists [a_ans ase::analysis_detect zzunoprobe] known]] \
  [list {} {} 1]

## --- U7: THE PEEK MIRRORS THE PRODUCER'S OWN CACHE KEY ---------------------
## ⚠ MEASURED AND IT IS THE DEFECT BOTH SPEC DRAFTS SHIPPED. `ase::sim_capabilities`
## keys on the RAW `resolved` string; `ase::sim_caps_have_path` normalises. Row K5e
## of this file is the fixture where they differ -- `PATH=":/usr/bin:/bin"` makes
## `auto_execok` answer a RELATIVE `./name`, which is what lands in the cache -- so
## a peek built on the normalised key MISSES after a successful Detect, for ever,
## on that arm, and the dialog says "nothing measured, press Detect" immediately
## after Detect. This row warms through the producer and then asks the peek.
a_resetall
set ::UPROBES 0
a_ans ase::sim_register zzupeek $S_GOOD
set U7WARM [a_ans ase::sim_capabilities zzupeek]
set U7PEEK [a_ans ase::sim_caps_cached zzupeek]
check {U7 what the peek looks up is what the probe recorded, so a warm cache is found rather than being asked for again} \
  [list [dict get [a_ans ase::caps_get $U7WARM known] value] \
        [expr {$U7PEEK ne {}}] \
        [expr {$U7PEEK eq $U7WARM}] \
        $::UPROBES] \
  [list 1 1 1 1]
a_resetall

# ============================================================================
# V. LEG D -- FOUR DEFECTS THIS NGSPICE HAS OR HAS NOT, MEASURED FROM FILES
#    ISSUE 1412
# ============================================================================
#
# ⚠ A VERSION STRING CANNOT TELL TWO BUILDS APART, AND THIS FILE'S OWN HEADER
# ALREADY RECORDS THE MEASUREMENT: two different builds both print
# `** ngspice-46+ : Circuit level simulation program`, byte for byte. So the
# variant questions are asked as BEHAVIOUR, from FILES, and the identity keys are
# display and log only -- never compared, never ordered (D44).
#
# MEASURED 2026-09-11 on all three preflight binaries:
#                        apt 45.2   the fork   upstream 47
#   one_vector_write        0          1           0
#   keyword_case            0          1           0
#   gnd_literal             0          1           0

set V_NS ase::backend::ngspice
## The two measured payload shapes, verbatim.
set V_FORK "@@gref=M7 my gnd rail\nngspice-46+\nFri Sep 11 03:44:45 UTC 2026\n"
set V_APT  "@@gref=M7 my 0 rail\nngspice-45.2\nFri Sep 12 11:58:13 UTC 2025\n"

## --- V1: THE DECK'S SHAPE ---------------------------------------------------
## ⚠ `write probe_k.raw ALL` IS UPPER CASE AND MUST STAY SO. MEASURED on apt
## 45.2: `write w.raw all` SUCCEEDS while `ALL` and `All` both fail with "vector
## ALL is not available or has zero length". Lower-casing it turns `keyword_case`
## into a probe that answers 1 on every binary -- a key that measures nothing.
set V1DECK [a_ans ${V_NS}::cap_deck_d]
set V1W {}
foreach v1l [split $V1DECK "\n"] {
  set v1t [string trim $v1l]
  if {[string first {write } $v1t] == 0} { lappend V1W [lrange $v1t 1 end] }
}
check {V1 the variant deck asks with a capitalised keyword, writes to bare lower-case names, and carries neither of the two commands the accumulating decks need} \
  [list $V1W \
        [a_count $V1DECK {remzerovec}] \
        [a_count $V1DECK {set appendwrite}] \
        [a_count $V1DECK {@@gref=}]] \
  [list {probe_d.raw {probe_k.raw ALL}} 0 0 1]

## --- V2: THE RENAME THAT MAKES THE GROUND VERDICT HONEST -------------------
## ⚠ THE KEY USED TO BE SPELLED `@@gnd=`, AND THAT MADE ITS OWN VERDICT VACUOUS:
## the natural test `string first gnd <line>` is TRUE on every binary INCLUDING
## the two that rewrite, because the KEY satisfies the search. Renaming the marker
## so it carries no `gnd` is what lets the payload answer the question.
check {V2 the ground marker's own name contains no ground token, so searching the answer for one is a question about the simulator rather than about the marker} \
  [list [expr {[string first {@@gnd=} $V1DECK] >= 0}] \
        [expr {[string first {@@gref=} $V1DECK] >= 0}] \
        [a_ans ${V_NS}::cap_d_field $V_FORK gref] \
        [a_ans ${V_NS}::cap_d_field $V_APT gref]] \
  [list 0 1 {M7 my gnd rail} {M7 my 0 rail}]

## --- V3: THE THREE VERDICTS, FROM THE TWO MEASURED SHAPES ------------------
proc v_verd {praw kex text} {
  return [a_ans ${::V_NS}::cap_variant_verdicts $praw $kex $text 1]
}
check {V3 a build that hands back one vector for a one-vector save, keeps a capitalised keyword and leaves a ground token alone is measured sound on all three, and a build that does none of them is measured unsound on all three} \
  [list [v_verd {v(mid)} 1 $V_FORK] \
        [v_verd {v(mid) v(all)} 0 $V_APT]] \
  [list {one_vector_write 1 keyword_case 1 gnd_literal 1} \
        {one_vector_write 0 keyword_case 0 gnd_literal 0}]

## --- V4: POLARITY IS "1 = SOUND", AND THE KEY IS NAMED FOR THE DEFECT -------
## ⚠ Every reader in the tree is written as `== 1` meaning GOOD; one key with
## inverted polarity is a defect waiting for a copy-paste. And naming the key for
## the DEFECT rather than the fix is what makes it survive somebody fixing it a
## different way -- or the fork being upstreamed.
check {V4 the defect band is declared, its three keys are the ones leg D writes, and a sound answer is 1 rather than 0} \
  [list [a_ans ase::caps_keys defect] \
        [a_ans ase::caps_measured_as {known 1 one_vector_write 1} one_vector_write 1]] \
  [list {one_vector_write keyword_case gnd_literal} 1]

## --- V5: A LEG THAT RAN AND DID NOT ANSWER IS NOT A LEG THAT WAS CUT -------
## ⚠ A THIRD PROVENANCE TOKEN, FOR A GENUINELY DIFFERENT CONDITION. `timeout`
## records a leg that was CUT; `noanswer` records one that RAN, was not cut, and
## whose artifact did not come back in a readable shape. Collapsing them would
## tell the user their box was slow when it was not.
check {V5 a variant leg whose artifact never arrived records that it ran and learned nothing, which is not the same as having been cut short} \
  [list [a_ans ${V_NS}::cap_variant_verdicts NOFILE UNKNOWN {} 1] \
        [a_ans ${V_NS}::cap_variant_verdicts {v(mid)} 1 $V_FORK 0]] \
  [list {} {}]

## --- V6: ⚠ HOSTILE TEXT MUST NOT KILL THE USER'S RUN -----------------------
## `probe_d.txt` is written by a program ASE-L does not control, and its payload
## can contain the USER'S OWN FOLDER NAME. Handing that to a Tcl LIST command --
## `foreach`, `lsearch` -- raises on a double quote or an unbalanced brace, inside
## `capabilities`, which `ase::sim_capabilities_at` DELIBERATELY RE-RAISES: the
## exception reaches the Run gesture as a stack trace. That is issue 0949's
## category error escalated from a silent wrong answer to a crash.
set V6HOSTILE "@@gref=M7 my \"quoted gnd \{unbalanced rail\nngspice-46+\n"
set V6RC [catch {${V_NS}::cap_variant_verdicts {v(mid)} 1 $V6HOSTILE 1} V6V]
## ⚠ BARE WORDS DO NOT GO IN `expr`. `expr {$c ? $x : NOKEY}` is a Tcl 8.6 SYNTAX
## ERROR that aborts the whole file, and the only symptom is the check count going
## DOWN -- which is what the floor paragraph at the head of this file exists to
## make visible. It has cost three runs in this suite alone; use `if`.
set V6G NOKEY
if {[string is list $V6V] && [dict exists $V6V gnd_literal]} {
  set V6G [dict get $V6V gnd_literal]
}
check {V6 a payload carrying a quote and an unbalanced brace is read as words rather than as a list, so a folder name cannot reach the user as a Tcl error} \
  [list $V6RC $V6G [catch {${V_NS}::cap_d_words $V6HOSTILE}]] \
  [list 0 1 0]

## --- V7: STRUCTURAL -- D52's FORBIDDEN INFERENCE IS NOT MADE ---------------
## ⚠ `$curcasemode` reports the CURRENT mode, never the supported SET. Populating
## `casemode_detected` from it would publish {fold} for the fork, NARROW its real
## {fold preserve distinguish} and SWITCH OFF THE ONE FEATURE THE FORK HAS. The
## scope is the whole `cap*` family, because a driver who put the identity readers
## in a fourth proc would land the defect outside a three-proc allowlist.
## ⚠ THE UNION EXCLUDES `capabilities` ITSELF, AND MEASURING THAT MATTERED:
## `capabilities` MATCHES `cap*`, and it writes the key TWICE by design -- once to
## publish the casemode leg's answer and once to record that leg as unmeasured
## when it is cut. The first scope written here counted those two and reddened a
## correct tree. The rule being fenced is that no VARIANT reader touches the key;
## the casemode leg's own writer is the one place it belongs.
proc v_capunion {} {
  set out {}
  foreach pr [info procs ::ase::backend::ngspice::cap*] {
    if {$pr eq {::ase::backend::ngspice::capabilities}} { continue }
    if {[catch {info body $pr} b]} { continue }
    append out [a_nocomment $b] "\n"
  }
  return $out
}
check {V7 STRUCTURAL no variant reader writes the case-mode key -- the one inference that would narrow a build's real answer to a single mode -- while the casemode leg's own writer still does} \
  [list [a_count [v_capunion] {casemode_detected}] \
        [a_count [a_nocomment [a_body ${V_NS}::capabilities]] {casemode_detected}] \
        [expr {[llength [info procs ::ase::backend::ngspice::cap*]] > 8}]] \
  [list 0 2 1]

## --- V8: THE IDENTITY KEYS ARE DISPLAY AND LOG ONLY ------------------------
## ⚠ AND THE TREE ITSELF PROVES WHY: this file's header records two DIFFERENT
## builds printing the same version string byte for byte. Any ordering operator on
## it is wrong TODAY, not in principle.
check {V8 the version line is collected for display and the band that holds it is the one nothing gates on} \
  [list [a_ans ${V_NS}::cap_d_identity $V_FORK] \
        [a_ans ase::caps_keys identity]] \
  [list {version_line ngspice-46+ build_date {Fri Sep 11 03:44:45 UTC 2026}} \
        {version_line build_date}]

## --- V9: LEG D RUNS **LAST**, AND ITS ABSENCE IS RECORDED BY NAME ----------
## ⚠ THE ORDERING HAS A COST WORTH NAMING: on a slow box leg D is the FIRST thing
## a spent budget kills, so Band 3 stays unmeasured for the whole session --
## `ase::sim_caps` is written only on `known 1` and cleared only by
## `ase::sim_caps_clear`. Going quiet there would leave the user with three keys
## silently missing and no way to tell why.
set V9B [a_nocomment [a_body ${V_NS}::capabilities]]
check {V9 the variant leg is the last thing the probe does, and a budget that runs out before it says which keys were lost rather than going quiet} \
  [list [expr {[string first {cap_leg_d} $V9B] > [string first {cap_help_verdict} $V9B]}] \
        [a_count [a_nocomment [a_body ${V_NS}::cap_leg_d]] {caps_unmeasured}] \
        [expr {[string first {timeout} [a_nocomment [a_body ${V_NS}::cap_leg_d]]] >= 0}] \
        [expr {[string first {noanswer} [a_nocomment [a_body ${V_NS}::cap_leg_d]]] >= 0}]] \
  [list 1 4 1 1]

## --- V10: THE REAL BINARY, END TO END --------------------------------------
## ⚠ SELF-RELATIVE. It asserts the three keys ARRIVED and agree with each other,
## not what they equal -- the answer differs by binary and naming one here would
## stop measuring the tree the day the registry resolves somewhere else.
a_resetall
set V10C [a_ans ase::sim_capabilities ngspice]
if {[string is list $V10C] && [dict exists $V10C known] && [dict get $V10C known] eq {1}} {
  set V10M {}
  foreach v10k {one_vector_write keyword_case gnd_literal} {
    lappend V10M [dict get [a_ans ase::caps_get $V10C $v10k] measured]
  }
  check {V10 the real simulator this registry resolves to is asked all three variant questions in the same run that asks what it can do, and answers every one of them} \
    [list $V10M \
          [dict get [a_ans ase::caps_get $V10C version_line] measured] \
          [a_ans ase::caps_unmeasured_keys $V10C]] \
    [list {1 1 1} 1 {}]
} else {
  puts "SKIPPED: V10 (no usable simulator resolved -- known was not 1)"
}
a_resetall

# ============================================================================
#
# Stage 1 of doc/claude/ase_analyses_batch/ gave `ase::analysis_types` a memo
# keyed on the backend NAME and gave it no invalidator: written by that proc,
# cleared by nothing -- not by `ase::sim_caps_clear`, not by anything. It was
# harmless while adapters register exactly once at source time, which is how it
# shipped green. It is wrong the moment a backend is re-registered, and BOTH of
# the Stage 2 sub-items that follow register stand-in registries per row.
#
# ⚠ L1 WAS RED BEFORE `ase::analysis_cache_clear` EXISTED, which is what makes
# it a row and not a decoration: the second read returned the FIRST registry's
# answer. Sabotage: delete the `ase::analysis_cache_clear $name` line from
# ase::register_backend and L1 reds with {zzl1a zzl1a} -- the replaced registry
# still speaking.
#
# THE ROW READS THE TYPE KEYS, NOT A COUNT. A count is equal for two registries
# of the same size, so it would pass while the wrong registry answered.

proc l_types {sim} {
  if {[catch {ase::analysis_types $sim} d]} { return "RAISED:$d" }
  if {$d eq {}} { return EMPTY }
  return [lsort [dict keys $d]]
}
proc l_reg {name typeproc} {
  return [a_ans ase::register_backend $name [dict create \
    render_deck  [a_ans ase::backend_hook ngspice render_deck] \
    run_cmd      [a_ans ase::backend_hook ngspice run_cmd] \
    log_file     [a_ans ase::backend_hook ngspice log_file] \
    result_probe [a_ans ase::backend_hook ngspice result_probe] \
    raw_file     [a_ans ase::backend_hook ngspice raw_file] \
    analysis_types $typeproc]]
}
proc l_typesA {} { return [dict create zzl1a [dict create label zzl1a registered 1]] }
proc l_typesB {} { return [dict create zzl1b [dict create label zzl1b registered 1]] }

l_reg zzl1 l_typesA
set L1FIRST [l_types zzl1]
l_reg zzl1 l_typesB
set L1SECOND [l_types zzl1]
## The control: reading a DIFFERENT name must not have been disturbed, so a
## clear-everything bug cannot pass this row by accident either.
set L1NG [l_types ngspice]
if {[string is list $L1NG] && [llength $L1NG] >= 4} { set L1NG OK }
check {L1 re-registering a backend replaces what it answers about its analyses, instead of the replaced registry going on speaking} \
  [list $L1FIRST $L1SECOND $L1NG] \
  [list zzl1a zzl1b OK]
a_resetall

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

# --- W: WHICH KIND OF THING A DC SWEEP VARIABLE IS --------------------------
## ⚠ CONTENT, NOT SCHEMA (D34-D37). ASE-L owns the fact that a dc sweep HAS a
## kind -- the form needs it to decide which picker to offer. Only ngspice knows
## that `dctrcurv.c` accepts exactly four and tells them apart the way the
## netlist does: by the instance name's FIRST CHARACTER.
##
## ⚠ THE SHAPE THIS BATCH FIRST PROPOSED WAS WRONG, AND THE CORPUS IS WHY. The
## plan's sketch classified "the literal word temp, else a voltage source".
## MEASURED over the 104 committed benches, the twelve distinct sweep variables
## are
##     I0 V1 VD Vce Vds Vin Vres i0 i1 temp v2 vd
## and three of those spellings are CURRENT sources, across seven committed
## rows. The sketch would have labelled every one of them a voltage source and
## offered the wrong picker on seven shipped benches.
set W_NS ase::backend::ngspice

check {W1 every sweep variable in every committed bench classifies by its SPICE device letter} \
  [list [a_ans ${W_NS}::dc_swkind I0]   [a_ans ${W_NS}::dc_swkind V1] \
        [a_ans ${W_NS}::dc_swkind VD]   [a_ans ${W_NS}::dc_swkind Vce] \
        [a_ans ${W_NS}::dc_swkind Vds]  [a_ans ${W_NS}::dc_swkind Vin] \
        [a_ans ${W_NS}::dc_swkind Vres] [a_ans ${W_NS}::dc_swkind i0] \
        [a_ans ${W_NS}::dc_swkind i1]   [a_ans ${W_NS}::dc_swkind temp] \
        [a_ans ${W_NS}::dc_swkind v2]   [a_ans ${W_NS}::dc_swkind vd]] \
  {isource source source source source source source isource isource temp source source}

## ⚠ THE ROW THE SUBSTRING BUG WOULD SURVIVE WITHOUT. `Vres` is a committed
## sweep variable and it is a VOLTAGE SOURCE whose name contains `res`. A
## classifier matching anywhere in the name calls it a resistor and offers a
## resistance picker for a voltage.
check {W2 the test is the first character and not a substring, so a voltage source named Vres is not a resistor} \
  [list [a_ans ${W_NS}::dc_swkind Vres] [a_ans ${W_NS}::dc_swkind R7] \
        [a_ans ${W_NS}::dc_swkind r2]] {source resistor resistor}

## ⚠ AND THE LITERAL IS CASE-INSENSITIVE, because a netlist is.
check {W3 temperature is recognised however it is spelled} \
  [list [a_ans ${W_NS}::dc_swkind temp] [a_ans ${W_NS}::dc_swkind TEMP] \
        [a_ans ${W_NS}::dc_swkind Temp] [a_ans ${W_NS}::dc_swkind { temp }]] \
  {temp temp temp temp}

## ⚠ A NAME THAT IS NONE OF THE THREE FALLS TO `source`, because that is the
## overwhelmingly common case and because ngspice itself will say so if it is
## wrong. It must NOT raise: a sweep variable is free text until the netlist is
## read, and a classifier that raised would take the dialog down.
check {W4 an unrecognised device letter is a source and never a raise} \
  [list [a_ans ${W_NS}::dc_swkind x9] [a_ans ${W_NS}::dc_swkind {}] \
        [a_ans ${W_NS}::dc_swkind 7]] {source source source}

## ⚠ RESOLVED THROUGH THE HOOK, NOT BY NAME. A caller that spelled the namespace
## itself would keep working for ngspice and silently do nothing for the next
## adapter -- which is the whole reason ase::backend_hook RAISES rather than
## returning empty for an unknown simulator.
check {W5 the classifier is reachable as a backend hook and the unknown-simulator arm still raises} \
  [list [expr {[a_ans ase::backend_hook ngspice dc_swkind] ne {}}] \
        [string range [a_ans ase::backend_hook zznosuchsim dc_swkind] 0 6] \
        [string range [a_ans ase::backend_hook ngspice zznosuchhook] 0 6]] \
  {1 RAISED: RAISED:}

## ⚠ AND THE MEASUREMENT ITSELF IS A ROW, so the claim above cannot rot. If a
## later change to the committed benches removes every current-source sweep, the
## reason this classifier is shaped the way it is has gone, and someone should
## be told rather than left reading a comment about seven rows that no longer
## exist.
set W_I 0
if {[catch {exec git -C $repo ls-files -- *.state} W_OUT]} { set W_OUT {} }
foreach W_REL [split $W_OUT "\n"] {
  if {[string trim $W_REL] eq {}} { continue }
  if {[catch {open [file join $repo $W_REL] r} W_FH]} { continue }
  set W_TXT [read $W_FH] ; close $W_FH
  foreach W_L [split $W_TXT "\n"] {
    if {[string first {analyses } $W_L] != 0} { continue }
    foreach W_R [lindex $W_L 1] {
      if {![dict exists $W_R source]} { continue }
      if {[a_ans ${W_NS}::dc_swkind [dict get $W_R source]] eq {isource}} { incr W_I }
    }
  }
}
check {W6 the committed benches really do sweep current sources, which is the measurement that chose this classifier over the one the plan sketched} \
  [expr {$W_I >= 7}] 1

# --- TV: ONE ngspice OUTPUT VARIABLE, AND THE THREE VECTORS IT PRODUCES -----
## Stage 5 of doc/claude/ase_analyses_batch/, issue 1426.
##
## ⚠ CONTENT, NOT SCHEMA (D34-D37), FOR BOTH PROCS. ASE-L owns the fact that a
## transfer function HAS an output and an input; `v(node)`, `v(node,ref)` and
## `i(vsrc)` are ngspice's spelling, and `Transfer_function` /
## `<uid>#Input_impedance` / `output_impedance_at_V(<node>)` are ngspice's
## result names. `ase::needs_eval`'s `tf_out` reaches the first through the
## `out_decompose` hook exactly as `sweep_target` reaches `dc_swkind`.
set TV_NS ase::backend::ngspice

## ⚠ `malformed` IS NOT `{}`, AND THE DIFFERENCE IS LOAD-BEARING. An empty
## answer would have to mean both "I cannot read this" and "there is nothing
## here to read", and the precondition has to tell them apart: a row with no
## `out` at all is the REQUIRED-FIELD check's business and must not also be
## reported as bad syntax.
check {TV1 an ngspice output variable comes apart into a kind and its names} \
  [list [a_ans ${TV_NS}::out_decompose {v(out)}] \
        [a_ans ${TV_NS}::out_decompose {v(out,ref)}] \
        [a_ans ${TV_NS}::out_decompose {i(vsense)}] \
        [a_ans ${TV_NS}::out_decompose {V(OUT)}] \
        [a_ans ${TV_NS}::out_decompose { v( out , ref ) }]] \
  {{voltage out} {voltage out ref} {current vsense} {voltage OUT} {voltage out ref}}

## ⚠ THE MISSING PARENTHESIS IS THE ONE A USER ACTUALLY TYPES, AND ngspice'S
## ANSWER TO IT NAMES THE WRONG THING. MEASURED 2026-09-12 on the fork and on
## apt 45.2: `tf v mid V1` fails with `Warning: Transfer function source  not
## in circuit` -- the EMPTY source name -- because the `v` branch with no `(`
## consumes nothing and the insrc slot is then never filled. A user reading that
## goes and looks at their source. APPENDIX §2.7 records the dot-card half of
## the same defect (`inp2dot.c:372-374` has an empty error arm).
check {TV2 an output this simulator cannot read is named malformed, including the missing parenthesis that ngspice blames on the source} \
  [list [a_ans ${TV_NS}::out_decompose {v mid}] \
        [a_ans ${TV_NS}::out_decompose {x(mid)}] \
        [a_ans ${TV_NS}::out_decompose {v(}] \
        [a_ans ${TV_NS}::out_decompose {v()}] \
        [a_ans ${TV_NS}::out_decompose {i(a,b)}] \
        [a_ans ${TV_NS}::out_decompose {v(a,b,c)}] \
        [a_ans ${TV_NS}::out_decompose {v(a,)}] \
        [a_ans ${TV_NS}::out_decompose {}]] \
  {malformed malformed malformed malformed malformed malformed malformed malformed}

## ⚠ IT IS REACHABLE THROUGH THE HOOK, NOT ONLY BY ITS FULLY QUALIFIED NAME.
## `ase::needs_eval` resolves it through `ase::backend_hook`, so a proc that
## exists and is not registered is a proc the precondition never calls -- and
## the precondition's own "an adapter with no hook gets no opinion" arm would
## swallow that into silence.
check {TV3 out_decompose is registered as a hook, and an unregistered one raises rather than answering} \
  [list [expr {[a_ans ase::backend_hook ngspice out_decompose] eq \
                 {::ase::backend::ngspice::out_decompose}}] \
        [string range [a_ans ase::backend_hook ngspice zznosuchhook] 0 6]] \
  {1 RAISED:}

## --- TV4/TV5: THE THREE VECTOR NAMES -----------------------------------------
## ⚠ PLAN.md Stage 5 WRITES THEM AS THREE LITERALS and only the FIRST is one.
## MEASURED 2026-09-12, `display` after each command on the fork:
##
##   tf v(mid) V1     -> Transfer_function / v1#Input_impedance /
##                       output_impedance_at_V(mid)
##   tf v(mid,out) V1 -> output_impedance_at_V(mid,out)      [no space]
##   tf i(Vsense) V1  -> vsense#Output_impedance             [the i() form
##                       replaces the output-impedance name entirely]
##   tf v(MID) v1     -> output_impedance_at_V(mid)          [the node is FOLDED
##                       and `output_impedance_at_V` keeps its capital V]
check {TV4 the three vectors a tf row will produce are computed from the row, and the UID prefixes are folded while the constants are not} \
  [list [a_ans ${TV_NS}::tf_vectors {type tf out v(mid) insrc V1}] \
        [a_ans ${TV_NS}::tf_vectors {type tf out v(mid,out) insrc V1}] \
        [a_ans ${TV_NS}::tf_vectors {type tf out i(Vsense) insrc V1}] \
        [a_ans ${TV_NS}::tf_vectors {type tf out v(MID) insrc V1}]] \
  [list {Transfer_function v1#Input_impedance output_impedance_at_V(mid)} \
        {Transfer_function v1#Input_impedance output_impedance_at_V(mid,out)} \
        {Transfer_function v1#Input_impedance vsense#Output_impedance} \
        {Transfer_function v1#Input_impedance output_impedance_at_V(mid)}]

## ⚠ IT NEVER RAISES AND AN UNREADABLE OR ABSENT FIELD SIMPLY DROPS A NAME. The
## caller is a results surface, not a validator: `tf_out` is the precondition
## that has a sentence for bad syntax, and a pane that blew up on a half-filled
## row would be issue 1405's shape again.
check {TV5 a half-filled or malformed tf row answers the names it can and does not raise} \
  [list [a_ans ${TV_NS}::tf_vectors {type tf}] \
        [a_ans ${TV_NS}::tf_vectors {type tf out v(mid)}] \
        [a_ans ${TV_NS}::tf_vectors {type tf insrc V1}] \
        [a_ans ${TV_NS}::tf_vectors {type tf out {v mid} insrc V1}]] \
  [list {Transfer_function} \
        {Transfer_function output_impedance_at_V(mid)} \
        {Transfer_function v1#Input_impedance} \
        {Transfer_function v1#Input_impedance}]

## ⚠ AND THE REGISTRY REALLY REACHES IT. `plots`' `vectors` key is opaque to
## core -- nothing reads it before Stage 6 -- so without this row the proc could
## be renamed and the registry would keep naming a command that does not exist,
## silently, until Stage 6 went looking.
set TV_PL [lindex [dict get [ase::analysis_entry ngspice tf] plots] 0]
check {TV6 the tf entry's plots row names a command that exists, and names the measured Plotname literal} \
  [list [dict get $TV_PL select] \
        [expr {[llength [info commands [dict get $TV_PL vectors]]] > 0}] \
        [a_ans [dict get $TV_PL vectors] {type tf out v(mid) insrc V1}]] \
  [list {Transfer Function} 1 \
        {Transfer_function v1#Input_impedance output_impedance_at_V(mid)}]

# --- PV: ONE `pz` ROOT NAME, READ BACK ---------------------------------------
## Stage 5 of doc/claude/ase_analyses_batch/, issue 1427.
##
## ⚠ CONTENT, NOT SCHEMA (D34-D37). ASE-L owns the fact that a pole-zero run
## produces roots; `pole(1)` / `zero(1)`, the parentheses being part of the name,
## and ngspice's own `v(…)` wrapper around them in the rawfile are ngspice's
## spelling. `pzan.c:151` and `:155` are the two `sprintf` calls.
set PV_NS ase::backend::ngspice

## ⚠ IT IS A **READER**, NOT A PREDICTOR, AND THAT IS THE ONE DIFFERENCE FROM
## `tf_vectors` ABOVE. A `tf` row determines its own three vector names; a `pz`
## row cannot determine ANY of its names, because the count is whatever the root
## finder converged on. MEASURED 2026-09-12 on both binaries, one two-pole RC:
##
##   pz in 0 out 0 vol pz   -> pole(1) pole(2)               (no zeros at all)
##   pz in 0 out 0 vol zer  -> NO VECTORS AT ALL, rc 0       (APPENDIX §2.8: a
##                                                            legitimately empty
##                                                            result is normal)
##   pz in 0 in  0 cur pz   -> pole(1) pole(2) zero(1) zero(2)
##
## So the `pz` entry declares no `vectors` key and this proc answers about a name
## somebody already has. Row PZ8 of tests/headless/test_ase_core.tcl is the other
## half: it asserts the key is ABSENT.
check {PV1 a pz root name comes apart into which kind of root it is and its index} \
  [list [a_ans ${PV_NS}::pz_root_kind {pole(1)}] \
        [a_ans ${PV_NS}::pz_root_kind {zero(12)}] \
        [a_ans ${PV_NS}::pz_root_kind {POLE(3)}] \
        [a_ans ${PV_NS}::pz_root_kind { zero(4) }]] \
  {{pole 1} {zero 12} {pole 3} {zero 4}}

## ⚠ THE RAWFILE WRAPS THE WHOLE NAME AGAIN, and a reader that only knew
## `pole(1)` would match nothing in one. ngspice types a root as `voltage`, so
## its own writer emits `v(pole(1))`. MEASURED 2026-09-12, the SAME deck written
## by the fork (`ngspice-46+`) and by apt 45.2 -- `Variables:` carries
## `v(pole(1))` and `v(pole(2))` on both, byte-identical, the only difference in
## either header being the `Command:` version line.
check {PV2 the rawfile's own v() wrapper is stripped, once} \
  [list [a_ans ${PV_NS}::pz_root_kind {v(pole(1))}] \
        [a_ans ${PV_NS}::pz_root_kind {v(zero(2))}] \
        [a_ans ${PV_NS}::pz_root_kind {V(POLE(9))}]] \
  {{pole 1} {zero 2} {pole 9}}

## ⚠ AND EVERYTHING ELSE IN THE PLOT ANSWERS `{}`, INCLUDING THE THINGS THAT LOOK
## CLOSEST. A pz raw written under `keepopinfo` carries an `op` plot full of
## `v(mid)`; the `const` plot carries `v(boltz)`. A reader that fell back to
## "anything in parentheses" would label them roots.
check {PV3 a name that is not a root answers nothing at all, and never raises} \
  [list [a_ans ${PV_NS}::pz_root_kind {v(mid)}] \
        [a_ans ${PV_NS}::pz_root_kind {pole}] \
        [a_ans ${PV_NS}::pz_root_kind {pole()}] \
        [a_ans ${PV_NS}::pz_root_kind {pole(x)}] \
        [a_ans ${PV_NS}::pz_root_kind {poles(1)}] \
        [a_ans ${PV_NS}::pz_root_kind {zero(1)x}] \
        [a_ans ${PV_NS}::pz_root_kind {}]] \
  {{} {} {} {} {} {} {}}

## ⚠ AND THE REGISTRY REALLY REACHES IT. `plots`' `rootname` key is opaque to
## core -- nothing reads it before Stage 6 -- so without this row the proc could
## be renamed and the registry would keep naming a command that does not exist,
## silently, until Stage 6 went looking. ⚠ THE `select` LITERAL IS CHECKED HERE
## TOO, because it is the measured `Plotname:` record and a respelling of it is
## invisible everywhere else in this suite.
set PV_PL [lindex [dict get [ase::analysis_entry ngspice pz] plots] 0]
check {PV4 the pz entry's plots row names a command that exists, and names the measured Plotname literal} \
  [list [dict get $PV_PL select] \
        [expr {[llength [info commands [dict get $PV_PL rootname]]] > 0}] \
        [a_ans [dict get $PV_PL rootname] {v(pole(1))}]] \
  [list {Pole-Zero Analysis} 1 {pole 1}]

## ⚠ AND THE SECOND ROW CARRIES ngspice's OWN MISLABEL. `pz`'s operating-point
## plot is written `Distortion Operating Point` -- a copy-paste from `distoan.c`
## at `pzan.c:52-61`. MEASURED 2026-09-12 on BOTH binaries, `.options keepopinfo`
## then `setplot`: `op1 … (Distortion Operating Point)`. Spelling it the way it
## reads would make Stage 6's reader match nothing on every ngspice that exists.
set PV_PL2 [lindex [dict get [ase::analysis_entry ngspice pz] plots] 1]
check {PV5 the keepopinfo plot carries the upstream mislabel exactly as ngspice writes it} \
  [list [dict get $PV_PL2 select] [dict get $PV_PL2 when]] \
  [list {Distortion Operating Point} {opt keepopinfo}]

# --- SV: ONE `sens` RESULT NAME, READ BACK -----------------------------------
## Stage 5 of doc/claude/ase_analyses_batch/, issue 1428.
##
## ⚠ CONTENT, NOT SCHEMA (D34-D37). ASE-L owns the fact that a sensitivity run
## produces one number per perturbable parameter; that a MODEL parameter is
## `<instance>:<param>`, that the first `IF_PRINCIPAL` instance parameter is the
## bare instance name and every other instance parameter is
## `<instance>_<param>`, is ngspice's spelling. `cktsens.c:222-249` is the code.
set SV_NS ase::backend::ngspice

## ⚠ IT SPLITS THE COLON AND REFUSES TO SPLIT THE UNDERSCORE, AND THAT IS A
## MEASUREMENT ABOUT ngspice's OWN OUTPUT RATHER THAN CAUTION IN A READER. The
## bare form and the underscore form COLLIDE in ngspice itself. MEASURED
## 2026-09-12 on the fork (`build-ver_50`) AND on apt 45.2, one deck carrying
## `R1` and `R1_temp`, reading `display` after `sens v(mid) dc`:
##
##     r1_temp             : voltage, real, 1 long
##     r1_temp             : voltage, real, 1 long
##
## -- the name appears TWICE in one plot, once as `R1`'s instance `temp`
## parameter and once as `R1_temp`'s own principal resistance. Two different
## quantities, one name. So `{instance <name>}` means "the instance side of the
## namespace, NOT split further", and a reader that split on `_` would be
## inventing an answer ngspice does not have.
check {SV1 a sens result name comes apart into a model parameter or an instance-side name, and the underscore form is deliberately not split} \
  [list [a_ans ${SV_NS}::sens_param_kind {r1:r}] \
        [a_ans ${SV_NS}::sens_param_kind {d1:is}] \
        [a_ans ${SV_NS}::sens_param_kind {r1}] \
        [a_ans ${SV_NS}::sens_param_kind {r1_temp}] \
        [a_ans ${SV_NS}::sens_param_kind { r1:tc1 }]] \
  {{model r1 r} {model d1 is} {instance r1} {instance r1_temp} {model r1 tc1}}

## ⚠ THE NAMES ARE HIERARCHICAL, AND THAT REFUTES APPENDIX §2.10's THREE-ROW
## NAMING TABLE. That table is measured on a FLAT deck and every xschem bench
## has subcircuits. MEASURED 2026-09-12 on both binaries -- `V1 / X1 / R9` at
## top level with `Ra` and `Rb` inside `.subckt divider` -- the COMPLETE
## bare-name set of the sens plot is
##
##     r.x1.ra   r.x1.rb   r9   v1
##
## A subcircuit device is `<letter>.<instance path>.<name>`; the subckt CALL
## `x1` produces nothing at all. The dots belong to the instance, so the split
## is on the FIRST colon and never on a dot.
check {SV2 a hierarchical instance keeps its dots and still splits on the colon} \
  [list [a_ans ${SV_NS}::sens_param_kind {r.x1.ra}] \
        [a_ans ${SV_NS}::sens_param_kind {r.x1.ra:r}] \
        [a_ans ${SV_NS}::sens_param_kind {r.x1.ra_temp}]] \
  {{instance r.x1.ra} {model r.x1.ra r} {instance r.x1.ra_temp}}

## ⚠ THE RAWFILE WRAPS THE WHOLE NAME IN `v(…)`, exactly as it does `pz`'s
## roots: ngspice types a sensitivity as a voltage, so its own writer adds the
## wrapper. MEASURED 2026-09-12, the SAME op+sens deck written by the fork
## (`ngspice-46+`) and by apt 45.2 -- `Variables:` carries `v(r1)` and `v(r2)`
## on both, BYTE-IDENTICAL, the only difference in either header being the
## `Command:` version line. So there are no capitals to fold here and `tf`'s
## C46 warning does not reach this entry; the strip is case-insensitive anyway,
## because that costs nothing.
check {SV3 the rawfile's own v() wrapper is stripped, once, whatever its case} \
  [list [a_ans ${SV_NS}::sens_param_kind {v(r1)}] \
        [a_ans ${SV_NS}::sens_param_kind {v(r1:r)}] \
        [a_ans ${SV_NS}::sens_param_kind {V(R1:TC1)}] \
        [a_ans ${SV_NS}::sens_param_kind {v(r.x1.ra:r)}]] \
  {{instance r1} {model r1 r} {model R1 TC1} {model r.x1.ra r}}

## ⚠ AND `{}` IS RESERVED FOR "I CANNOT READ THIS", NOT FOR "THIS IS NOT A
## RESULT" -- WHICH IS THE ONE PLACE THIS READER DIFFERS FROM `pz_root_kind` AND
## THE DIFFERENCE IS MEASURED. A pz plot's roots have a FIXED shape, so anything
## else in it is not a root and answers `{}`. A sens plot has no fixed shape and
## nothing else in it: MEASURED, every vector in a `Sensitivity Analysis` plot
## is a parameter sensitivity and there is no scale vector at all. So an
## ordinary-looking name is an ordinary answer, and only an empty or
## undecomposable one is nothing.
check {SV4 an unreadable name answers nothing at all, and never raises} \
  [list [a_ans ${SV_NS}::sens_param_kind {}] \
        [a_ans ${SV_NS}::sens_param_kind {   }] \
        [a_ans ${SV_NS}::sens_param_kind {:r}] \
        [a_ans ${SV_NS}::sens_param_kind {r1:}] \
        [a_ans ${SV_NS}::sens_param_kind {a:b:c}] \
        [a_ans ${SV_NS}::sens_param_kind {v()}]] \
  {{} {} {} {} {} {}}

## ⚠ AND THE REGISTRY REALLY REACHES IT. `plots`' `paramname` key is opaque to
## core -- nothing reads it before Stage 6 -- so without this row the proc could
## be renamed and the registry would keep naming a command that does not exist,
## silently, until Stage 6 went looking. ⚠ THE `select` LITERAL IS CHECKED HERE
## TOO, because it is the measured `Plotname:` record and a respelling of it is
## invisible everywhere else in this suite. MEASURED 2026-09-12 on both
## binaries: `sens v(mid) dc` leaves `$plots` = `const sens1` and
## `$curplotname` = `Sensitivity Analysis`.
## ⚠ EVERY KEY HERE IS READ ABORT-PROOF, AND THAT IS WHAT THE SABOTAGE ASKED
## FOR. A bare `dict get $SV_PL paramname` is only legal while the key is there,
## and the key's RENAMING is the exact change this row exists to catch -- so it
## raised `key "paramname" not known in dictionary` and killed the whole file
## with NO `RESULT:` LINE AT ALL, which reads in a sabotage log as "nothing went
## red". MEASURED (sabotage S12), the same lesson PZ2c's `pzkey` and G2pz's
## `g2pz_cget` record in their own files.
set SV_PL [lindex [dict get [ase::analysis_entry ngspice sens] plots] 0]
proc svkey {d k} {
  if {[catch {dict exists $d $k} e] || !$e} { return ABSENT }
  return [dict get $d $k]
}
check {SV5 the sens entry's plots row names a command that exists, and names the measured Plotname literal} \
  [list [svkey $SV_PL select] \
        [expr {[llength [info commands [svkey $SV_PL paramname]]] > 0}] \
        [a_ans [svkey $SV_PL paramname] {v(r1:r)}] \
        [llength [dict get [ase::analysis_entry ngspice sens] plots]]] \
  [list {Sensitivity Analysis} 1 {model r1 r} 1]

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
