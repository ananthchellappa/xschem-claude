#
#  File: test_raw_schname_0514.tcl
#
#  This file is part of XSCHEM,
#  a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
#  simulation.
#  Copyright (C) 1998-2023 Stefan Frederik Schippers
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#
# ---------------------------------------------------------------------------
# ISSUE 0514 -- Tcl could ask whether a database's schematic stamp RESOLVES and
# could not ask WHAT THE STAMP SAYS.
#
# Every reader in src/save.c stamps the Raw it just built with the schematic
# that was current at read time -- `my_strdup2(&raw->schname,
# xctx->sch[xctx->currsch])` in raw_read(), new_rawfile() and table_read(), and
# raw_restamp_design() re-stamps it -- and sch_waves_loaded() (src/draw.c) gates
# every name lookup on that stamp still sitting on the current hierarchy stack.
# The `raw`/`raw_query` arm of scheduler.c published `rawfile`, `sim_type`,
# `loaded`, `casemode` and thirty more tokens, and NOT `schname`.
#
# ⚠ WHY A SUBSTITUTE DOES NOT EXIST, AND WHY THAT IS THE WHOLE POINT OF THIS
# SUITE. `xschem get raw_level` answers raw->level, and `xschem get schname <n>`
# answers xctx->sch[n] -- THE CURRENT STACK. In exactly the state the missing
# accessor is wanted for (the database no longer resolves, because the user
# moved to another cell) those two compose into a CONFIDENT WRONG ANSWER: the
# level indexes a different stack and `get schname $raw_level` names the cell
# the user is standing in, not the cell the data was read against. Measured at
# 087fc9c1 before the fix:
#
#   xschem raw loaded            -> -1     (the stamp does not resolve)
#   xschem raw rawfile           -> .../an.raw
#   xschem raw schname           -> ERROR "Wrong command"        THE DEFECT
#   xschem get raw_level         -> 0
#   xschem get schname 0         -> .../cellB.sch    THE WRONG CELL, confidently
#
# So a row that merely asserts `xschem raw schname` returns a non-empty string
# is worth nothing here. Group C is the load-bearing one: it asserts IN ONE
# TUPLE that the accessor names cellA while the stack query names cellB, i.e.
# that the two DISAGREE and the accessor is the one that is right. A tree where
# `schname` was implemented as a synonym for the stack query would pass every
# other row in this file and fail C2/C3.
#
# ⚠ THE ERROR BEFORE THE FIX WAS THE ARM'S GENERIC `Wrong command`, NOT a
# per-token message, so it is BYTE-IDENTICAL to what any typo answers. Group A
# therefore does not assert a string: it asks the arm a deliberately bogus token
# in the same breath and asserts that `schname`'s reply DIFFERS from it, so the
# row cannot go green on a tree that merely re-worded the refusal.
#
# ---------------------------------------------------------------------------
# THE NULL, AND WHY GROUP G IS STATIC
# ---------------------------------------------------------------------------
# raw->schname is a char * that my_strdup2() leaves NULL when
# xctx->sch[xctx->currsch] is NULL (src/util.c: a NULL src frees the destination
# and returns), and free_rawfile() (src/save.c) drops it. Both
# sch_waves_loaded() (src/draw.c) and raw_case_mode_schematic() (src/save.c)
# explicitly test for it, which is what row G0 MEASURES rather than trusting --
# this repo has shipped comments citing checks that do not exist, so every
# symbol named in this header was grepped, and G0 re-greps the two that matter
# on every run. The NEIGHBOURING `rawfile` token does not guard its pointer and
# is not a precedent: a NULL there is a different reachability argument nobody
# made.
#
# It is NOT reachable from Tcl: measured at 087fc9c1, xctx->sch[0] is
# `<cwd>/untitled.sch` at startup, survives `xschem clear force`, and every
# reader stamps. So the guard is fenced by reading the token's own arm out of
# src/scheduler.c with C comments stripped and whitespace removed (G1/G2)
# instead of by a behavioural row that cannot be written. Stated plainly rather
# than dressed up as coverage.
#
# ---------------------------------------------------------------------------
# FIXTURES: two one-wire schematics and two hand-written ASCII raw files, so the
# suite needs no simulator. The two cells differ in their single wire's length
# purely so they are different files; F1 asserts their paths really are
# distinct, because every disagreement row below is vacuous if they are not.
#
# Run standalone (pure engine, no Tk, no display):
#   tests/headless/run_suites.sh --nogui test_raw_schname_0514
# ---------------------------------------------------------------------------

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "->got ($got) (exp $want)"
}
# Every engine call goes through this: the arm answers several of the states
# under test with a TCL_ERROR, and an error is a RESULT here, not an accident.
proc p {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc tl {s} { return [file tail $s] }

set tmp [test_scratch rawschname0514]
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}
proc mkcell {path len} {
  wr $path "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 0 $len 0 {}\n"
}
proc mkraw {path title node} {
  wr $path "Title: $title
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv($node)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00

1\t1.000000000000000e-08
\t2.000000000000000e+00

"
}

if {[catch {

set A [file join $tmp cellA.sch] ; mkcell $A 200
set B [file join $tmp cellB.sch] ; mkcell $B 300
set AR [file join $tmp an.raw]   ; mkraw $AR A n1
set BR [file join $tmp bn.raw]   ; mkraw $BR B n2

# ===========================================================================
# N -- WITH NO DATABASE AT ALL. Measured truth, not an assumption: the token
# sits inside the arm's `raw && raw->values` gate beside `rawfile`, so it gives
# that gate's own refusal. The row compares the TWO TOKENS rather than quoting
# one string, so "schname refuses like its neighbour" is what is fenced.
# ===========================================================================
eqcheck {N1-with-no-database-schname-refuses-through-the-same-gate-as-its-neighbour-rawfile} \
  [list [p xschem raw schname] [p xschem raw rawfile]] \
  {{ERR:No raw file loaded} {ERR:No raw file loaded}}

# ===========================================================================
# F -- the fixture really is two cells, and the database really is bound to the
# first one while the first one is current.
# ===========================================================================
check {F1-the-two-fixture-cells-are-distinct-paths-so-a-later-disagreement-can-mean-something} \
  [expr {[file normalize $A] ne [file normalize $B] && [file exists $A] && [file exists $B]}] \
  "->got ([tl $A] vs [tl $B])"

p xschem load -inplace $A
p xschem unselect_all
eqcheck {F2-PRECONDITION-cellA-is-current-the-read-succeeds-and-raw-loaded-resolves-it} \
  [list [p xschem raw read $AR tran] [p xschem raw loaded] [tl [p xschem get schname]]] \
  {1 0 cellA.sch}

# ===========================================================================
# A -- IS THE TOKEN ANSWERED AT ALL. This is the red: before the fix
# `raw schname` fell through to the arm's unknown-token path and answered the
# generic `Wrong command`, indistinguishable from a typo. The bogus token is
# asked in the same state so the comparison cannot drift.
# ===========================================================================
set bogus [p xschem raw zzz_not_a_token_0514]
set got_s [p xschem raw schname]
eqcheck {A1-raw-schname-is-answered-instead-of-falling-into-the-arms-unknown-token-Wrong-command-path} \
  [list $bogus [expr {$got_s ne $bogus}]] {{ERR:Wrong command} 1}
eqcheck {A2-the-arms-other-name-raw_query-reaches-the-same-token-with-the-same-answer} \
  [list [p xschem raw_query schname] [p xschem raw schname]] [list $got_s $got_s]

# ===========================================================================
# B -- WHILE THE STAMP STILL RESOLVES the accessor and the stack query agree.
# Without this row, C2's disagreement could be satisfied by an accessor that is
# simply always different from the stack query.
# ===========================================================================
eqcheck {B1-while-the-stamp-resolves-the-accessor-and-get-schname-raw_level-both-name-cellA} \
  [list [tl [p xschem raw schname]] [tl [p xschem get schname [p xschem get raw_level]]]] \
  {cellA.sch cellA.sch}

# ===========================================================================
# C -- THE LOAD-BEARING GROUP. Move to cellB in place; the database is now
# bound to a cell that is not on the stack, and the stack query becomes a liar.
# ===========================================================================
p xschem load -inplace $B
p xschem unselect_all
eqcheck {C1-PRECONDITION-loading-cellB-in-place-makes-raw-loaded-report-the-non-resolving--1} \
  [list [p xschem raw loaded] [tl [p xschem get schname]]] {-1 cellB.sch}

eqcheck {C2-the-accessor-names-cellA-while-get-schname-raw_level-confidently-names-cellB} \
  [list [tl [p xschem raw schname]] [tl [p xschem get schname [p xschem get raw_level]]]] \
  {cellA.sch cellB.sch}

# ⚠ `$acc ne $stk` ALONE IS VACUOUS ON THE BROKEN TREE -- an error message
# differs from a path too, and this row passed at 087fc9c1 before the fix for
# exactly that reason. So it also asserts the accessor answers a path that
# EXISTS on disk: that is the property `results::select` needs and the one an
# error string, an empty string or a bare cell name all fail.
set acc [p xschem raw schname]
set stk [p xschem get schname [p xschem get raw_level]]
eqcheck {C3-the-accessor-answers-an-existing-file-that-is-NOT-the-one-the-stack-query-names} \
  [list [file exists $acc] [expr {$acc ne $stk}] \
        [expr {[file normalize $acc] eq [file normalize $A]}]] \
  {1 1 1}

# A `schname` line copy-pasted from the neighbouring `rawfile` line and left
# reading the wrong field answers the raw FILE here, which is not a schematic.
eqcheck {C4-the-accessor-reads-the-schname-field-not-a-copy-of-the-neighbouring-rawfile-line} \
  [list [tl [p xschem raw schname]] [tl [p xschem raw rawfile]] \
        [expr {[p xschem raw schname] ne [p xschem raw rawfile]}]] \
  {cellA.sch an.raw 1}

# ===========================================================================
# E -- READ-ONLY, and the four clauses R804's sentence needs.
# The stamp is owned by save.c's readers and by raw_restamp_design(), and WHEN
# that re-stamp fires is a ruling (results_selection.md R110a: only when the
# current stamp does not already resolve against the stack). A token that took a
# value would be a second way to move it, outside that condition and audited by
# nothing -- so E1 asserts the extra argument is IGNORED rather than obeyed.
# ===========================================================================
eqcheck {E1-an-extra-argument-is-ignored-so-the-token-cannot-be-used-to-re-stamp-the-binding} \
  [list [tl [p xschem raw schname $B]] [tl [p xschem raw schname]] [p xschem raw loaded]] \
  {cellA.sch cellA.sch -1}

eqcheck {E2-all-four-clauses-R804-needs-are-answerable-from-the-engine-in-the-non-resolving-state} \
  [list [tl [p xschem raw rawfile]] [p xschem raw sim_type] \
        [tl [p xschem raw schname]] [tl [p xschem get schname]]] \
  {an.raw tran cellA.sch cellB.sch}

# ===========================================================================
# D -- PER-SLOT, NOT GLOBAL. schname is a field of the Raw, so it must follow
# `raw switch` to whichever slot is selected. This is the R404 dialog's case: a
# Loaded row per slot, each bound to its own cell.
# ===========================================================================
eqcheck {D1-a-second-read-in-cellB-stamps-the-new-slot-against-cellB-not-against-the-first-slots-cell} \
  [list [p xschem raw read $BR tran] [tl [p xschem raw rawfile]] [tl [p xschem raw schname]]] \
  {1 bn.raw cellB.sch}
eqcheck {D2-raw-switch-carries-the-accessor-to-the-slot-it-switched-to-rather-than-answering-a-global} \
  [list [p xschem raw switch 0] [tl [p xschem raw rawfile]] [tl [p xschem raw schname]] \
        [p xschem raw loaded]] \
  {1 an.raw cellA.sch -1}

eqcheck {N2-after-raw-clear-the-token-refuses-again-through-the-same-gate-as-rawfile} \
  [list [p xschem raw clear] [p xschem raw schname] [p xschem raw rawfile]] \
  {1 {ERR:No raw file loaded} {ERR:No raw file loaded}}

# ===========================================================================
# G -- THE NULL GUARD, read out of the source.
#
# METHOD, stated so a future reader can judge it: the C file is read, block and
# line comments are removed, and ALL whitespace is removed. Matching a
# character string was the defect behind issue 1608's four hardening rounds, so
# nothing here depends on how the code is spaced; what it does still depend on
# is the SPELLING of the guard, and the row lists the spellings it accepts.
# The `raw`/`raw_query` arm is cut out FIRST, between two anchors that are each
# unique in the file, because `!strcmp(argv[2],"schname")` also appears in the
# `get` arm -- the very stack query this issue is about -- and a row that
# matched the whole file would have been satisfied by it.
# ===========================================================================
proc cstrip {s} {
  regsub -all {/\*.*?\*/} $s { } s
  regsub -all -line {//[^\n]*} $s {} s
  return $s
}
proc squash {s} {
  regsub -all {[ \t\n\r]+} [cstrip $s] {} s
  return $s
}
proc slurp {path} {
  set fd [open $path r] ; set t [read $fd] ; close $fd ; return $t
}
set REPO [__scratch_repo]
set SCHED [squash [slurp [file join $REPO src scheduler.c]]]
set DRAWC [squash [slurp [file join $REPO src draw.c]]]
set SAVEC [squash [slurp [file join $REPO src save.c]]]

# G0 -- the reachable-NULL claim, MEASURED in the tree rather than trusted from
# the issue file. If neither of these sites tests the pointer, the guard below
# is cargo cult and this row says so by name.
set g0_draw [regexp {&&xctx->raw->schname} $DRAWC]
set g0_save [regexp {!raw->schname} $SAVEC]
eqcheck {G0-the-NULL-is-real-because-draw-c-and-save-c-each-test-raw-schname-before-using-it} \
  [list $g0_draw $g0_save] {1 1}

set a_beg [string first {!strcmp(argv[1],"raw")||!strcmp(argv[1],"raw_query")} $SCHED]
set a_end [string first {!strcmp(argv[1],"raw_clear")} $SCHED]
check {G1a-the-raw-arm-can-be-cut-out-of-scheduler-c-between-its-two-unique-anchors} \
  [expr {$a_beg >= 0 && $a_end > $a_beg}] "->got (beg=$a_beg end=$a_end) (exp 0<=beg<end)"
set ARM {}
if {$a_beg >= 0 && $a_end > $a_beg} { set ARM [string range $SCHED $a_beg $a_end] }

set t_at [string first {!strcmp(argv[2],"schname")} $ARM]
check {G1b-the-schname-token-is-compared-inside-the-raw-arm-itself-not-only-in-the-get-arm} \
  [expr {$t_at >= 0}] "->got (index=$t_at in a [string length $ARM]-char arm) (exp >=0)"

set TOK {}
if {$t_at >= 0} { set TOK [string range $ARM $t_at [expr {$t_at + 199}]] }
# The guard spellings this row accepts. A list, and named as such: it is a
# closed set of C idioms for "is this pointer NULL", not a hand-kept inventory
# of sites.
set g1_guarded 0
foreach pat {{raw->schname\?} {\(raw->schname\)\?} {if\(raw->schname\)} \
             {if\(!raw->schname\)} {raw->schname!=NULL} {raw->schname==NULL}} {
  if {[regexp $pat $TOK]} { set g1_guarded 1 ; break }
}
check {G1c-the-schname-tokens-own-arm-guards-raw-schname-against-NULL-before-publishing-it} \
  $g1_guarded "->got (guarded=$g1_guarded in {[string range $TOK 0 129]}) (exp 1)"

# G2 -- both directions in one tuple, with both counts printed. The bare-pointer
# count alone is an absence assertion and would go quietly green if the token
# were deleted; pairing it with the guarded count means the row can only pass
# while a guarded publish actually exists.
set g2_bare 0
foreach s [list $SCHED $DRAWC $SAVEC] {
  incr g2_bare [regexp -all {Tcl_(Set|Append)Result\(interp,raw->schname,} $s]
  incr g2_bare [regexp -all {Tcl_(Set|Append)Result\(interp,xctx->raw->schname,} $s]
}
set g2_guarded [regexp -all {raw->schname\?raw->schname:} $SCHED]
eqcheck {G2-no-bare-raw-schname-pointer-reaches-a-Tcl-result-setter-and-at-least-one-guarded-one-does} \
  [list $g2_bare [expr {$g2_guarded >= 1}]] {0 1}

} err]} {
  puts "FATAL: $err"
  puts "  $::errorInfo"
  incr fail
}

catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_schname_0514: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; flush stdout; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; flush stdout; exit 1 }
