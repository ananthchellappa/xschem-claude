# `result_probe` reads a log whose SPELLING is the simulator's, not ours —
# casemode batch item 11 (PLAN.md §3b item 11 and §F3; DECISIONS.md B4 and D2;
# spec doc/claude/specs/simulator_profiles.md §15).
#
# THE DEFECT, MEASURED 2026-08-17 ON THIS TREE. A deck whose net is drawn `In`:
#
#   /usr/local/bin/ngspice -b            print v(In)  ->  v(in) = 3.000000e+00
#   build-ver_50 -D casemode=fold        print v(In)  ->  v(in) = 3.000000e+00
#   build-ver_50 -D casemode=preserve    print v(In)  ->  v(In) = 3.000000e+00
#   build-ver_50 -D casemode=distinguish print v(in)  ->  NOTHING (a warning),
#                                        while `v(In) = 3.000000e+00` prints
#                                        two lines away
#
# The old matcher was literal, so a mixed-case expression run on a FOLDING
# binary matched nothing and the Outputs pane's Value column was silently empty
# (ase_window.tcl:1383 and :1414 fill that cell from this dict, keyed by
# ase::ui::output_result_key). Two ways to get there, and the second is wider
# than spec §13.6's first cut said:
#
#   * B4's run-and-report path — requested `preserve`, measured `fold`. Item 9
#     emits the schematic's `v(In)`, the run folds, the echo is `v(in)`.
#   * A `fold` run whose expression did NOT come from item 9's pick path. The
#     Add/Edit Output dialog stores exactly what was typed
#     (ase_window.tcl ase::ui::output_editor_ok, no fold anywhere in it), and a
#     hand-written state file stores exactly what it says.
#
# THE FIX IS A LADDER, not a `-nocase` flag: exact first, case-insensitive
# second, and DECLINE when the second offers more than one differently-cased
# label (DECISIONS.md D2 — a wrong number in a Value column is worse than an
# empty one). Rung 2 is OFF under `distinguish`, because there the log line
# beside a stale row belongs to a DIFFERENT signal (measured, above).
#
# Legs (NC*):
#   NC222  the defect itself: requested preserve, measured fold
#   NC223  rung 1 is unchanged — exact spelling, first line wins
#   NC224  delivered preserve still matches exactly
#   NC225  the `distinguish` gate: no lenient match, and its positive control
#   NC226  D2 — two case-variant labels decline, and SAY SO; one label twice
#          is not a collision
#   NC226e the LADDER'S ORDER: rung 1 before rung 2, so an exactly-spelled row
#          inside a collision reads its own line and is never declined
#   NC227  the `\W` escape survives rung 2 (parentheses, dots and quotes stay
#          literal)
#   NC230  what the run DELIVERED outranks what it REQUESTED (spec §15.4b): a
#          log that announces `casemode=distinguish` turns rung 2 off even for
#          a `fold` request, it is announced once, and the detector is pinned
#          by a positive control
#   NC228  the REAL simulator, when there is one (skipped, never failed) —
#          NC228d is the §15.4b run on the case-capable binary
#
# True headless (no X, no Tk). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_result_case.tcl

set fail 0
set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp})"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## abort-proof numeric compare: a value the probe did NOT record is the empty
## string, and arithmetic on it raises a Tcl error that would abort the file
## with no RESULT line (the LEDGER's item-2 finding, under which every sabotage
## reads as "nothing went red").
proc approx {v want} {
  if {![string is double -strict $v]} { return 0 }
  return [expr {abs($v - $want) < 1e-6 ? 1 : 0}]
}
# ABORT-PROOFING (LEDGER carry-forward from items 1, 2, 5b, 6, 7, 8): a proc
# sabotaged away must FAIL a check, never abort the file with no RESULT line —
# under which every sabotage reads as "nothing went red".
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
## the value this dict holds for a row, through the pane's OWN key proc — the
## Outputs Value cell is exactly this lookup (ase_window.tcl:1381-1385)
proc cell {res row} {
  if {[catch {ase::ui::output_result_key $row} k]} { return "ERR:$k" }
  if {[catch {dict exists $res $k} e]} { return "ERR:$e" }
  if {!$e} { return {} }
  return [dict get $res $k]
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_result_case]
set ::USER_CONF_DIR [file join $scratch conf]
file mkdir $::USER_CONF_DIR

# the CIW spy: ase::echo resolves ::ciw_echo BY NAME at call time, and the TAG
# matters as much as the text (item 14's finding: a channel can be correct and
# still reach nobody).
set ::said {}
if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::ciw_echo_orig }
proc ::ciw_echo {line {tag {}}} { lappend ::said [list $tag $line] }
proc said_clear {} { set ::said {} }
proc said_count {pat {tag {}}} {
  set n 0
  foreach e $::said {
    if {$tag ne {} && [lindex $e 0] ne $tag} { continue }
    if {[string match $pat [lindex $e 1]]} { incr n }
  }
  return $n
}

# A private simulator configuration; nothing here reads or writes the user's own.
# With NOTHING REGISTERED, ase::sim_casemode_requested falls through to the
# GLOBAL FLOOR — which is what `casemode` below sets.
#
# ⚠ IT USED TO CLEAR A `sim()` ARRAY (the `annotate` merge). The per-simulator
# case mode moved onto the ASE-L registry entry, so the thing to clear is the
# registry; `sim()` no longer carries a case mode at all and reset_sim's own
# `set_sim_defaults` call went with it, which is also why NC229's spy below
# still reads 0 for a reason it no longer has to work for.
proc reset_sim {} { ase::sim_clear }
reset_sim
proc casemode {m} { set ::sim_case_mode $m }
casemode fold

set probe [ase::backend_hook ngspice result_probe]
proc outstate {outputs} {
  set st [ase::state_default]
  dict set st outputs $outputs
  return $st
}

# The log text below is BYTE-FOR-BYTE from the runs quoted in the header, not a
# hand-written approximation: `/usr/local/bin/ngspice -b` on a deck with
# `V1 In 0 3` / `R1 In MidNode 1k` / `R2 MidNode 0 1k`, `print v(In)`.
set LOG_FOLDED "Doing analysis at TEMP = 27.000000 and TNOM = 27.000000\n\
v(in) = 3.000000e+00\nv(midnode) = 1.500000e+00\ni(v1) = -1.50000e-03\n"
set LOG_KEPT "Doing analysis at TEMP = 27.000000 and TNOM = 27.000000\n\
v(In) = 3.000000e+00\nv(MidNode) = 1.500000e+00\ni(V1) = -1.50000e-03\n"

if {[catch {

# ===========================================================================
# NC222 — THE DEFECT. Requested `preserve`, measured `fold` (DECISIONS B4's
# run-and-report path): we ship `v(In)`, the simulator answers `v(in)`.
# ===========================================================================
casemode preserve
set row {expr v(In) save 1}
set res [pcall $probe [outstate [list $row]] $LOG_FOLDED]
check "NC222 a mixed-case expr reads its FOLDED echo (the empty Value column)" \
  [cell $res $row] 3.000000e+00
## the whole point of the item is a pane cell, so drive the pane's own key proc
## for a NAMED row too: the KEY must stay the name, untouched by any of this
set nrow {name vin expr v(In) save 1}
set res [pcall $probe [outstate [list $nrow]] $LOG_FOLDED]
check "NC222b a NAMED row keeps its key and gains the value" \
  [list [cell $res $nrow] [pcall dict keys $res]] {3.000000e+00 vin}
## a current, in the negated `-i(...)` form ase.tcl:1115 and test_ase_core D1
## already use for a source branch
set crow {expr -i(Vs) save 1}
set res [pcall $probe [outstate [list $crow]] \
   "i(vs) = -1.50000e-03\n-i(vs) = 4.096837e-04\n"]
check "NC222c the folded echo of a negated current is read too" \
  [cell $res $crow] 4.096837e-04
## and the row that has NO echo at all still records nothing — the ladder must
## not invent a value out of a neighbouring line
set mrow {expr v(NoSuchNet) save 1}
set res [pcall $probe [outstate [list $mrow]] $LOG_FOLDED]
check "NC222d a name the log never mentions still records nothing" \
  [list [cell $res $mrow] [pcall dict size $res]] {{} 0}

# ===========================================================================
# NC223 — rung 1 unchanged: the expression's own spelling, first line wins
# ===========================================================================
casemode fold
set frow {expr v(in) save 1}
set res [pcall $probe [outstate [list $frow]] $LOG_FOLDED]
check "NC223 the ordinary fold run matches exactly, as it always did" \
  [cell $res $frow] 3.000000e+00
## two analyses printing the same vector: FIRST wins, on rung 1 and rung 2 alike
set res [pcall $probe [outstate [list $frow]] \
  "v(in) = 1.000000e+00\nv(in) = 2.000000e+00\n"]
check "NC223b two echoes of the SAME spelling: the first wins (rung 1)" \
  [cell $res $frow] 1.000000e+00

# ===========================================================================
# NC224 — delivered `preserve`: both sides carry the case, rung 1 answers
# ===========================================================================
casemode preserve
set res [pcall $probe [outstate [list $row]] $LOG_KEPT]
check "NC224 delivered preserve matches exactly (rung 2 not needed)" \
  [cell $res $row] 3.000000e+00

# ===========================================================================
# NC225 — the `distinguish` GATE. Measured on build-ver_50: `print v(in)`
# against a design that only has `In` prints NOTHING, so the `v(In)` line two
# rows down belongs to a DIFFERENT signal. A lenient match there is a wrong
# number, not a rescue.
# ===========================================================================
casemode distinguish
set srow {expr v(in) save 1}
set res [pcall $probe [outstate [list $srow]] $LOG_KEPT]
check "NC225 under distinguish a stale folded row gets NO value" \
  [list [cell $res $srow] [pcall dict size $res]] {{} 0}
## POSITIVE CONTROL: the same log and the same row under `preserve` DO resolve,
## so NC225 is the mode gate and not a pattern that cannot match at all
casemode preserve
set res [pcall $probe [outstate [list $srow]] $LOG_KEPT]
check "NC225b the same row under preserve resolves — NC225 is the GATE" \
  [cell $res $srow] 3.000000e+00
## and the gate does not touch rung 1: an exact spelling still reads
casemode distinguish
set res [pcall $probe [outstate [list $row]] $LOG_KEPT]
check "NC225c distinguish still reads an EXACT match" [cell $res $row] 3.000000e+00

# ===========================================================================
# NC226 — D2: decline when two differently-cased labels are on offer, and SAY
# SO. This is the failure mode a flag-on-the-regexp `-nocase` would have.
# ===========================================================================
casemode fold
said_clear
set erow {expr v(En) save 1}
set res [pcall $probe [outstate [list $erow]] \
  "v(en) = 1.000000e+00\nv(EN) = 2.000000e+00\n"]
check "NC226 two case-variant labels: NOTHING is recorded (D2, no guess)" \
  [list [cell $res $erow] [pcall dict size $res]] {{} 0}
check "NC226b the decline reaches the CIW at tag `error`, naming both labels" \
  [said_count {*v(En)*v(EN), v(en)*} error] 1
## ONE spelling appearing twice is NOT a collision — the rule counts SPELLINGS,
## not lines, or every two-analysis run would lose its values
set res [pcall $probe [outstate [list $row]] \
  "v(in) = 1.000000e+00\nv(in) = 2.000000e+00\n"]
check "NC226c the same folded spelling twice is not ambiguous — first wins" \
  [cell $res $row] 1.000000e+00
## a declining row must not poison the rest of the pane
said_clear
set res [pcall $probe [outstate [list $erow $row]] \
  "v(en) = 1.000000e+00\nv(EN) = 2.000000e+00\nv(in) = 3.000000e+00\n"]
check "NC226d one ambiguous row does not cost the other rows their values" \
  [list [cell $res $erow] [cell $res $row]] {{} 3.000000e+00}
## LADDER ORDER, pinned: rung 1 runs BEFORE rung 2. Inside the very collision
## NC226 declines, a row spelled EXACTLY as one of the labels must read its own
## line and must NOT be declined — invert the two rungs and this is the only
## check that notices (verifier finding, item 11 fix round).
said_clear
set xrow {expr v(EN) save 1}
set res [pcall $probe [outstate [list $xrow]] \
  "v(en) = 1.000000e+00\nv(EN) = 2.000000e+00\n"]
check "NC226e an EXACT spelling inside a collision is read by rung 1, never declined" \
  [list [cell $res $xrow] [said_count {*differ only in case*}]] {2.000000e+00 0}

# ===========================================================================
# NC227 — the `\W` escape. It is what makes `v(In)`'s parentheses literal, and
# rung 2 must not lose it: an unescaped `(` turns the expression into a capture
# group and `.` matches anything.
# ===========================================================================
set drow {expr v(A.B) save 1}
set res [pcall $probe [outstate [list $drow]] "v(axb) = 9.000000e+00\n"]
check "NC227 rung 2 keeps `.` literal — v(A.B) does not match v(axb)" \
  [list [cell $res $drow] [pcall dict size $res]] {{} 0}
set res [pcall $probe [outstate [list $drow]] "v(a.b) = 9.000000e+00\n"]
check "NC227b ...and DOES match the real v(a.b)" [cell $res $drow] 9.000000e+00
## print_arg quotes a bracketed name and ngspice echoes the quotes (issue 0167);
## a hand-typed `A[0]` must still find the folded, quoted echo
set brow {expr {A[0]} save 1}
set res [pcall $probe [outstate [list $brow]] "\"a\[0\]\" = 1.500000e+00\n"]
check "NC227c a bracketed hand-typed row finds its quoted folded echo" \
  [cell $res $brow] 1.500000e+00

# ===========================================================================
# NC229 — where the mode comes from. Item 9 §13.4: the RUN'S REQUEST, resolved
# through the profile authority — and asked in the READ-ONLY form, because
# `::set_sim_defaults` is not a read (with the Simulation Configuration dialog
# open it slurps every unsaved `cmd` edit back into `sim()` and defeats that
# dialog's Cancel; item 9 reproduced it).
# ===========================================================================
casemode preserve
rename ::set_sim_defaults ase_rc_real_ssd
set ::ssd_calls 0
proc ::set_sim_defaults {args} {
  incr ::ssd_calls
  uplevel 1 [linsert $args 0 ase_rc_real_ssd]
}
set res [pcall $probe [outstate [list $row]] $LOG_FOLDED]
set nssd $::ssd_calls
rename ::set_sim_defaults {}
rename ase_rc_real_ssd ::set_sim_defaults
check "NC229 reading a log never calls set_sim_defaults (it cannot commit dialog edits)" [list $nssd [cell $res $row]] {0 3.000000e+00}
## and the PROFILE ROW outranks the global floor: a row that says `distinguish`
## gates rung 2 off while the floor still says `preserve`
reset_sim
casemode preserve
# ⚠ THE ENTRY MUST BE RUNNABLE, and the first draft of this row used
# `/nonexistent/ngspice` on the theory that a probe is never launched here. It is
# not -- but ase::sim_casemode_requested REFUSES to read a mode off an entry
# whose program cannot be started (a request must not be attributed to a
# simulator that is not going to run; test_sim_casemode_registry CS155f is that
# rule), so the floor answered and this row measured the floor against itself.
# `/bin/sh` is a program that certainly exists and is certainly never run here.
pcall ase::sim_register {rc probe sim} /bin/sh -casemode distinguish
set pst [outstate [list $srow]]
set res [pcall $probe $pst $LOG_KEPT]
check "NC229b the registered simulator's mode outranks the floor (its distinguish, floor preserve)" \
  [pcall dict size $res] 0
# ⚠ THE ENTRY IS DELIBERATELY UNRUNNABLE, and that is not a mistake in the
# fixture: what is being asserted is that the requested MODE is read off the
# entry, which is a question about the record and not about the program. An
# entry that pointed at a real binary would let a reader believe the answer came
# from a measurement.
check "NC229c ...and it really is the entry answering, not the floor" \
  [pcall ase::sim_casemode_requested ngspice] distinguish
reset_sim

# ===========================================================================
# NC230 — WHAT THE RUN DELIVERED OUTRANKS WHAT IT ASKED FOR (spec §15.4b).
# `~/.spiceinit` overrides `-D casemode=` (CREW_BRIEF §4) and item 7's probe /
# item 8's report only run for a NON-`fold` request (§12.6), so a plain `fold`
# run against a `set casemode=distinguish` init file is measured by nobody. The
# log below is line-for-line from such a run (build-ver_50, HOME holding that
# init file, deck `V1 In 0 DC 3` / `R1 In 0 1k`, cards `print v(in)` and
# `print v(In)`; only the banner's long third sentence is elided): the `v(in)`
# card printed NO value, so a request-gated rung 2
# would hand that row the `v(In)` line — the wrong-number-in-the-Value-column
# failure §15.4 exists to prevent.
# ===========================================================================
# each line exactly as the run printed it (the banner is verbatim but for its
# third sentence, elided as a paragraph of prose the matcher never looks at)
set LOG_DIST_LINES {
  {Warning: casemode 'distinguish' is experimental. Identifier identity is case sensitive.}
  {Warning: no vector named 'in'; 'In' differs only in case (casemode=distinguish)}
  {Warning from checkvalid: vector in is not available or has zero length.}
  {}
  {Circuit: * item 11 delivered distinguish}
  {}
  {Doing analysis at TEMP = 27.000000 and TNOM = 27.000000}
  {}
  {No. of Data Rows : 1}
  {v(In) = 3.000000e+00}
}
set LOG_DIST_BANNER [lindex $LOG_DIST_LINES 0]
set LOG_DIST [join $LOG_DIST_LINES \n]\n
casemode fold
said_clear
set inrow {expr v(in) save 1}
set res [pcall $probe [outstate [list $inrow $row]] $LOG_DIST]
check "NC230 a fold REQUEST against a distinguish-DELIVERING log fabricates nothing" \
  [list [cell $res $inrow] [cell $res $row] [pcall dict size $res]] \
  {{} 3.000000e+00 1}
## POSITIVE CONTROL: strip the two case warnings out of that same log and the
## folded row DOES resolve through rung 2 — so NC230 pins the DETECTOR and not
## a pattern that could never match.
set LOG_NOTELL {}
foreach l [split $LOG_DIST \n] {
  if {[string match {Warning*case*} $l]} { continue }
  append LOG_NOTELL $l \n
}
set res [pcall $probe [outstate [list $inrow]] $LOG_NOTELL]
check "NC230b the same log without the case warnings resolves — NC230 is the DETECTOR" \
  [cell $res $inrow] 3.000000e+00
## and the BANNER ALONE is enough: ver_50 prints it on EVERY distinguish run,
## mismatch or not (measured), while the per-miss warning only appears when a
## card happens to miss. A later row must not be fabricated just because this
## particular log had no miss in it.
set res [pcall $probe [outstate [list $inrow]] \
  "$LOG_DIST_BANNER\nv(In) = 3.000000e+00\n"]
check "NC230c the distinguish BANNER alone forces the strict path" \
  [list [cell $res $inrow] [pcall dict size $res]] {{} 0}
## the surprise is ANNOUNCED, once per log, at tag `note` — and a run that
## ASKED for distinguish learns nothing from its own log, so it stays quiet.
said_clear
set res [pcall $probe [outstate [list $inrow $row]] $LOG_DIST]
set n_fold [said_count {*casemode=distinguish*asked for 'fold'*} note]
casemode distinguish
said_clear
set res [pcall $probe [outstate [list $inrow $row]] $LOG_DIST]
set n_dist [said_count {*casemode=distinguish*} note]
casemode fold
check "NC230d the delivered-mode override is announced once, and not when it was requested" \
  [list $n_fold $n_dist] {1 0}


# ===========================================================================
# NC228 — THE REAL SIMULATOR. The only leg here that measures rather than
# asserts: it re-takes §F3 and drives the whole deck -> ngspice -> probe chain.
# Skipped, never failed, when no ngspice is installed, and it prints no
# substring full_audit.sh scores a whole file on.
# ===========================================================================
set NGSTOCK {}
foreach c {/usr/local/bin/ngspice /usr/bin/ngspice} {
  if {[file executable $c]} { set NGSTOCK $c ; break }
}
if {$NGSTOCK eq {}} {
  puts "note: NC228 not run (no released ngspice on this machine)"
} else {
  set rd [file join $scratch run]
  file mkdir $rd
  set st [ase::state_default]
  dict set st design {lib l cell rc view schematic}
  dict set st rundir $rd
  dict set st models {}
  dict set st analyses {{type op enabled 1}}
  dict set st outputs {{expr v(In) save 1 plot 0} {expr v(MidNode) save 1 plot 0}}
  set deck [pcall [ase::backend_hook ngspice render_deck] $st \
    "* item 11 case echo\nV1 In 0 3\nR1 In MidNode 1k\nR2 MidNode 0 1k\n.end\n"]
  set df [file join $rd rc.cir]
  set f [open $df w] ; puts -nonewline $f $deck ; close $f
  set logtext {}
  catch {exec $NGSTOCK -b $df 2>@1} logtext
  ## §F3 itself, re-measured: the released simulator answers a `v(In)` card in
  ## LOWER CASE. If this ever stops being true the item's premise is gone.
  check "NC228 F3 re-measured: a released ngspice echoes v(In) as `v(in)`" \
    [list [regexp -line {^v\(in\) = } $logtext] \
          [regexp -line {^v\(In\) = } $logtext]] {1 0}
  casemode preserve
  set res [pcall $probe $st $logtext]
  set r1 {expr v(In) save 1 plot 0}
  set r2 {expr v(MidNode) save 1 plot 0}
  check "NC228b the real folded log fills BOTH mixed-case Value cells" \
    [list [approx [cell $res $r1] 3.0] [approx [cell $res $r2] 1.5]] {1 1}
  ## and the same real log under `distinguish` is refused, end to end
  casemode distinguish
  set res [pcall $probe $st $logtext]
  check "NC228c the same real log records NOTHING under distinguish" \
    [pcall dict size $res] 0
  if {$fail} { puts "  log was:\n$logtext" }
}

# ===========================================================================
# NC228d — the DELIVERED-mode override, on the real case-capable binary. This
# is the reproducer of the fix-round finding, end to end: a plain `fold` run
# (no -D on our side, nothing for item 7/8 to probe) whose ~/.spiceinit says
# `set casemode=distinguish`. Skipped, never failed, when build-ver_50 is
# absent or has stopped honouring the setting — ver_50 keeps moving, so this
# asserts on MEASURED output, never on "this build has fix X".
# ===========================================================================
set NGVER /home/qflow/dev/ngspice_test/build-ver_50/src/ngspice
set dlog {}
if {[file executable $NGVER]} {
  set dd [file join $scratch dist]
  file mkdir $dd
  set f [open [file join $dd .spiceinit] w]
  puts $f "set casemode=distinguish" ; close $f
  set f [open [file join $dd d.spice] w]
  puts $f "* item 11 delivered distinguish"
  puts $f "V1 In 0 DC 3"
  puts $f "R1 In 0 1k"
  puts $f ".control"
  puts $f "op"
  puts $f "print v(in)"
  puts $f "print v(In)"
  puts $f "quit"
  puts $f ".endc"
  puts $f ".end"
  close $f
  ## cwd must BE the deck's directory: `.spiceinit` is read from there, and
  ## CREW_BRIEF §4 says run fixtures from a scratch dir
  set cwd0 [pwd]
  catch {cd $dd ; exec env HOME=$dd $NGVER -b d.spice 2>@1} dlog
  catch {cd $cwd0}
}
if {![regexp -nocase {casemode[ =]'?distinguish|differs only in case} $dlog] \
    || ![regexp -line {^v\(In\) = } $dlog]} {
  puts "note: NC228d not run (no case-capable ngspice honouring casemode here)"
} else {
  ## the run asked for nothing — a virgin sim() floor, i.e. `fold`
  reset_sim
  casemode fold
  set res [pcall $probe [outstate [list $inrow $row]] $dlog]
  check "NC228d a real distinguish-delivering run under a fold REQUEST fabricates nothing" \
    [list [cell $res $inrow] [approx [cell $res $row] 3.0] [pcall dict size $res]] \
    {{} 1 1}
  if {$fail} { puts "  dlog was:\n$dlog" }
}
casemode fold

} err]} { puts "FATAL: $err" ; incr fail }

## restore the real ciw_echo OUTSIDE the catch, so a FATAL cannot leave the stub
if {[info commands ::ciw_echo_orig] ne {}} {
  catch {rename ::ciw_echo {}}
  catch {rename ::ciw_echo_orig ::ciw_echo}
}

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else        { puts "RESULT: ALL PASS ($npass checks)" }
flush stdout
exit 0
