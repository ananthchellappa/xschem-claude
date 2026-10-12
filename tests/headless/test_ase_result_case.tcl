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
# ⚠⚠ SINCE 2026-10-11 THE LOG IS NOT READ AT ALL. The user ruled that an
# output expression must not reach the netlist (ase_l.md R-OUT1), so the deck
# carries no `print`, `result_probe_log` is gone and its rows (NC222-NC230,
# NC228, NC228d) are retired. What survives is the ladder's other half:
#
# Legs:
#   NCR*   the DISPATCHER: a row naming exactly one vector reads the RESULTS
#          FILE through the same casemode ladder (fold on rung 2, off under a
#          delivered `distinguish`), and an expression is the Calculator's
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

if {[catch {

# ===========================================================================
# NC222-NC230, NC228, NC228d -- RETIRED 2026-10-11 WITH THE LOG READER.
# They pinned the casemode ladder of `result_probe_log`, which read the Outputs
# Value column out of ngspice `print` lines. The user ruled output expressions
# out of the netlist (ase_l.md R-OUT1), so the deck prints nothing and there is
# no log to read: every row is answered from the results file. The ladder lives
# on in the results-file reader, pinned by NCR1/NCR2 below; an expression row is
# the Calculator's, which matches names the way the Calculator always does.
# ===========================================================================

# ===========================================================================
# NCR — ⚖ R3's DISPATCHER over this file's own subject (issue 1429).
#
# Everything above drives the LOG reader by name. These rows drive the
# REGISTERED hook, so that what a user actually gets is measured too, and so
# that the one-line swap above cannot quietly stop being equivalent.
#
# ⚠ ⚖ R3 WAS ANSWERED 2026-09-12 — Option C, RATIFIED: named vectors from the
# results file, arbitrary expressions from the print log. It was implemented
# ahead of the ruling so that A or B would have removed one reader rather than
# invalidating the work, which is the shape this file still pins. DECISIONS.md
# records R3 as EXTENDING the user's own ruling in issue 1243, not reversing
# it.
#
# No simulator: the results file is canned, which is this batch's idiom for a
# reader row.
# ===========================================================================
proc ncr_raw {vars} {
  set out "Title: * ncr\nDate: Sat Sep 12 00:00:00  2026\n"
  append out "Plotname: Operating Point\nFlags: real\n"
  append out "No. Variables: [expr {[llength $vars]/2}]\nNo. Points: 1\nVariables:\n"
  set i 0
  foreach {nm v} $vars { append out "\t$i\t$nm\tvoltage\n" ; incr i }
  append out "Values:\n"
  set i 0
  foreach {nm v} $vars {
    if {$i == 0} { append out " 0\t$v\n" } else { append out "\t$v\n" }
    incr i
  }
  return $out
}
proc ncr_state {cell outs} {
  set st [ase::state_default]
  dict set st design [dict create lib l cell $cell view schematic]
  dict set st rundir $::scratch
  dict set st outputs $outs
  return $st
}
set NCRD [ase::backend_hook ngspice result_probe]
set NCRF [file join $scratch ncr_ase.raw]
set f [open $NCRF w]
## the FOLDED spelling a released ngspice writes, against a row drawn `v(In)`
puts -nonewline $f [ncr_raw {v(in) 3.000000000000000e+00 v(midnode) 1.500000000000000e+00}]
close $f

reset_sim
casemode fold
set NCRST [ncr_state ncr {{expr v(In) save 1 plot 0}}]
set NCR1 [pcall $NCRD $NCRST {}]
check "NCR1 `v(In)` names one vector, so the dispatcher reads it from the\
 RESULTS FILE -- with no log at all -- through the folded spelling" \
  [cell $NCR1 {expr v(In) save 1 plot 0}] 3.000000e+00

## ⚠ AND THE RAWFILE READER OBEYS THE SAME LADDER, not a second one. The
## fixture above is the FOLDED spelling; rung 2 is what matches it, and rung 2
## is OFF when the log says the run delivered `distinguish` — measured for the
## log half in NC230, asserted for the raw half here.
set NCR3 [pcall $NCRD $NCRST "Warning: differs only in case\n"]
check "NCR2 the results-file reader is gated by the SAME delivered-casemode\
 rule as the log reader: a folded file is not matched under distinguish" \
  [pcall dict size $NCR3] 0

## ⚠ THE ROUTING IS THE RULE'S, AND IT IS ONE PROC. An expression that does NOT
## name exactly one vector is the Calculator's (2026-10-11), evaluated on the
## same results file -- 2 x 3 -- and never the log's rival 9.9.
set NCR4 [pcall $NCRD [ncr_state ncr {{expr v(In) save 1 plot 0}
                                      {expr {v(In) 2 *} save 1 plot 0}}] \
  "v(in) 2 * = 9.900000e+00\n"]
check "NCR3 one dict, two sources: the vector from the file and the expression\
 from the Calculator on the same file, never from the log" \
  [list [cell $NCR4 {expr v(In) save 1 plot 0}] \
        [cell $NCR4 {expr {v(In) 2 *} save 1 plot 0}]] \
  {3.000000e+00 6.000000e+00}
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
