# "Has this session got results?" must mean the raw describes the deck on disk —
# issue 0838.
#
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_results_freshness.tcl
#
# WHAT BROKE, on the user's bench. With every analysis unticked, `Netlist and
# Run` wrote a fresh deck, ngspice refused it ("Error: incomplete or empty
# netlist … no simulations run!", exit 1) and left the PREVIOUS run's raw
# untouched. ase::has_results was `[file isfile <raw>]` and nothing more, so
# ASE-L's `Results > Annotate` stayed live and annotating painted 08:52's
# operating point onto 08:57's netlist. Measured on the real artifacts: the raw
# was 5m28s OLDER than the deck. Nothing on screen distinguished it from a good
# run.
#
# The rule: a raw DESCRIBES a deck, and is usable iff it is at least as new as
# the deck it claims to describe. Every group below carries a positive twin, and
# group W is the anti-regression: plotting an old raw is LEGITIMATE and must not
# have been broken by tightening annotation.

set failed 0
set checks 0
# ⚠ THE FAILURE LINE ENDS IN " : FAIL", AND THE SUITE EXITS NONZERO. Neither was
# true until 2026-08-28, and between them they made this file a suite that could
# not report a failure to anything but a human reading its output. Measured: a
# deliberate break here printed "RESULT: 2 FAILED" and still exited 0, and
# tests/run_regression.tcl counts a failed check by grepping for a line that
# ENDS in FAIL, which "FAIL: <name>" does not. Registering a suite in a runner
# without both of these is registering a green light.
proc ck {name cond} {
  global failed checks
  incr checks
  if {[uplevel 1 [list expr $cond]]} {
    puts "ok:   $name"
  } else {
    puts "FAIL: $name : FAIL"
    incr failed
  }
}

set TMP [file normalize [file join /tmp xschem_fresh_test_[pid]]]
set RD  [file join $TMP run]
file mkdir $RD

set KEY  fresh/tb/ngspice_state1
set CELL tb
set RAW  [file join $RD ${CELL}_ase.raw]
set DECK [file join $RD ${CELL}_ase.spice]

# A session fixture: the three state keys the predicate reads. Injected directly
# rather than through session_open — the code under test is the predicate, and a
# real state file would only add a second thing that can fail.
proc seed_session {} {
  global KEY CELL RD
  set st [dict create simulator ngspice rundir $RD \
                      design [dict create lib fresh cell $CELL view schematic]]
  dict set ::ase::sessions $KEY [dict create path {} state $st saved $st]
}
proc mk {path when} { set f [open $path w]; puts $f "x"; close $f; file mtime $path $when }
seed_session
set ST [ase::session_state $KEY]

# ------------------------------------------------------------------- group D
# ase::deck_file: the one owner of the deck path.
ck "D1  deck_file is <rundir>/<cell>_ase.spice" \
   {[ase::deck_file $ST] eq $DECK}
ck "D2  deck_file on a state with no cell returns {} and does not raise\
 (it runs on a menu -postcommand)" \
   {![catch {ase::deck_file [dict create simulator ngspice]} r] && $r eq {}}
ck "D3  deck_file on an empty state returns {}" \
   {![catch {ase::deck_file {}} r] && $r eq {}}

# ------------------------------------------------------------------- group S
# The freshness rule itself.
mk $DECK 1000
mk $RAW  2000
ck "S1  POSITIVE TWIN: raw NEWER than the deck is not stale" \
   {[ase::results_stale $KEY] == 0}
ck "S1b and has_results agrees" \
   {[ase::has_results $KEY] == 1}

file mtime $RAW 1000
ck "S2  raw and deck in the SAME second is not stale (a run that finished fast)" \
   {[ase::results_stale $KEY] == 0}

file mtime $RAW 400
ck "S3  raw OLDER than the deck IS stale — THE REPORTED BUG" \
   {[ase::results_stale $KEY] == 1}
ck "S3b and has_results refuses it, so Results > Annotate greys" \
   {[ase::has_results $KEY] == 0}

file delete $DECK
ck "S4  no deck at all -> NOT stale: nothing contradicts the raw, and reading\
 saved results is legitimate" \
   {[ase::results_stale $KEY] == 0}
ck "S4b and has_results agrees" \
   {[ase::has_results $KEY] == 1}

file delete $RAW
ck "S5  no raw at all -> has_results 0" \
   {[ase::has_results $KEY] == 0}
ck "S5b results_stale is 0 too — no raw is not EVIDENCE of staleness" \
   {[ase::results_stale $KEY] == 0}

ck "S6  an unknown session key is NOT STALE (a positive claim needs evidence),\
 and does not raise" \
   {![catch {ase::results_stale no/such/key} r] && $r == 0}
ck "S6b ...while has_results still refuses it, via last_rawfile" \
   {[ase::has_results no/such/key] == 0}

# ------------------------------------------------------------------- group W
# ANTI-REGRESSION. last_rawfile stays loose on purpose: the three waveform
# callers (ase_window.tcl :2118, :4035, :4583) are RIGHT to plot an old raw, and
# refusing to plot the last good run's traces after a failed netlist would be a
# regression traded for the fix. Only ANNOTATION — a number painted on a
# schematic with no provenance and no timestamp — needs the strict door.
mk $DECK 1000
mk $RAW  400
ck "W1  last_rawfile STILL returns the stale raw, so the waveform viewer can\
 still plot the last good run" \
   {[ase::last_rawfile $KEY] eq $RAW}
ck "W2  ...while has_results, the annotation door, refuses the same file" \
   {[ase::has_results $KEY] == 0}

# ------------------------------------------------------------------- group M
# The chord's refusal has a message. `6` has no session gate at all (see
# utils/annot_mode.tcl's header), so greying the menu while leaving the chord
# live would make the menu a decoration; the chord reports `stale` instead.
set _am [file join [file dirname [file normalize [info script]]] .. .. utils annot_mode.tcl]
ck "M0  fixture: utils/annot_mode.tcl sources cleanly" \
   {![catch {uplevel #0 [list source [file normalize $_am]]}]}
# ⚠ RE-AIMED BY ISSUE 0886, AND TIGHTENED WHILE IT MOVED. These three used to
# match FRAGMENTS -- "*STALE RESULTS NOT USED*" and the like -- which is exactly
# the shape that cannot tell a good sentence from a bad one. They now compare
# whole sentences. The user's ruling, verbatim: "wording too cryptic. Give it in
# plain english with context, 9th grade level."
set A11_M1S {Showing device operating-point values on the schematic.}
set msg [cadence::_annot_msg 1 stale $RAW {}]
ck "M1  the out-of-date-results message says what happened, names the file, and says what to do" \
   {$msg eq "$A11_M1S The results file [file tail $RAW] is older than the circuit\
 it describes, so it was not used - it is from an earlier run. Run the simulation again."}
ck "M2  POSITIVE TWIN: the other states still speak, in the user's own words" \
   {[cadence::_annot_msg 1 nopath {} {}] eq "$A11_M1S No results file has been found\
 for this cell. Run a simulation first." &&
    [cadence::_annot_msg 1 live {} {}] eq "$A11_M1S These results were already loaded."}
ck "M3  and the mask half still says what the schematic is showing" \
   {[string first $A11_M1S $msg] == 0}

# ------------------------------------------------------------------ group M
# A11-11 — EVERY REFUSAL THE USER CAN ACT ON ENDS WITH WHAT TO DO
#
# ⚠ THE THIRD LEG OF THE USER'S STANDARD, MADE MECHANICAL. A sentence has to say
# WHAT HAPPENED, give the CONTEXT that makes it make sense, and -- where the user
# can act -- say WHAT TO DO. The first two are a matter of reading; the third is
# not. Nine states leave the user holding a key that did nothing, and every one
# of them has a next step: run a simulation, turn on a cursor, load a different
# results file, plot the results again. A refusal that names the problem and
# stops is the silence this whole mode exists to remove.
set A11_REMEDIES [list {Run } {Turn on } {Load } {Plot } {try again}]
set a11_mute {}
foreach a11st {noop noraw nopath stale} {
  set a11m {}
  catch {set a11m [cadence::_annot_msg 1 $a11st $RAW {}]}
  set a11ok 0
  foreach a11r $A11_REMEDIES { if {[string match "*$a11r*" $a11m]} { set a11ok 1 } }
  if {!$a11ok} { lappend a11_mute [list press-6 $a11st $a11m] }
}
foreach a11st {nocursor noraw notran staleraw viewerdiff viewerunread viewergone viewerfilling} {
  set a11m {}
  catch {set a11m [cadence::_annot_tran_msg $a11st 1e-09 A $RAW]}
  set a11ok 0
  foreach a11r $A11_REMEDIES { if {[string match "*$a11r*" $a11m]} { set a11ok 1 } }
  if {!$a11ok} { lappend a11_mute [list cursor-annotate $a11st $a11m] }
}
if {[llength $a11_mute]} {
  foreach a11e $a11_mute { puts "     A11-11 no next step offered: $a11e" }
}
ck "A11-11 every refusal the user can act on says what to do next" \
   {[llength $a11_mute] == 0}

file delete -force $TMP
# ⚠ THE DUAL BANNER IS WHAT tests/run_regression.tcl's hcases list REQUIRES.
# banner_complete in tests/banner_rule.tcl wants a WHOLE-LINE "OVERALL: ok"
# alongside the RESULT line, and it tolerates the parenthesised check count. The
# count used to be printed on a line of its own, which no reader looks at.
if {$failed} {
  puts "RESULT: $failed FAILED ($checks checks)"
  puts "OVERALL: notok"
} else {
  puts "RESULT: ALL PASS ($checks checks)"
  puts "OVERALL: ok"
}
flush stdout
exit [expr {$failed == 0 ? 0 : 1}]
