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
proc ck {name cond} {
  global failed checks
  incr checks
  if {[uplevel 1 [list expr $cond]]} { puts "ok:   $name" } else { puts "FAIL: $name"; incr failed }
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
set msg [cadence::_annot_msg 1 stale $RAW {}]
ck "M1  the stale state has its own message, and it names the file" \
   {[string match {*STALE RESULTS NOT USED*} $msg] &&
    [string match "*[file tail $RAW]*" $msg]}
ck "M2  POSITIVE TWIN: the other states still speak" \
   {[string match {*NO RAW FILE for this cell*} [cadence::_annot_msg 1 nopath {} {}]] &&
    [string match {*raw already loaded*}       [cadence::_annot_msg 1 live {} {}]]}
ck "M3  and the mask half of the message is untouched" \
   {[string match {OP annotation ON (device OP info)*} $msg]}

file delete -force $TMP
puts "test_results_freshness: $checks checks"
if {$failed} { puts "RESULT: $failed FAILED" } else { puts "RESULT: ALL PASS" }
xschem exit closewindow force
