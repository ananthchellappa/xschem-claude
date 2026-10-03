# tests/headless/test_calc_scratch_reuse.tcl — LANDMINE L2 and R605.
#
# Spec   doc/claude/specs/calculator.md §3.3 L2, §9 R605, §11.1 (this file's own
#        row in the test table), §7.3 R402
# Plan   doc/claude/calculator_batch/PLAN.md phase 3 step 3.2 and its sabotage
#        line ("remove the re-evaluate in 3.2, scratch_reuse goes red")
# Fixture tests/headless/data/calc_fixture.raw, hand derivations in that
#        directory's README.md
#
# §11.1's entry for this file says, in as many words: **"THIS TEST EXISTS
# BECAUSE THE BUG IS INVISIBLE WITHOUT IT."**  So the first thing it does is
# measure the bug, in the engine's own voice and with no Calculator in the way,
# and only then assert that `calc::eval_rpn` does not have it.
#
# ⚠⚠ WHAT L2 ACTUALLY IS ON THIS PATH, AND IT IS NOT WHAT THE SPEC SENTENCE
# DESCRIBES.  L2 is written for the GRAPH path: `plot_raw_custom_data()` called
# with `yname == NULL` writes `raw->values[raw->nvars]`, one shared scratch
# column, which the next evaluation overwrites.  The Calculator does not reach
# that call.  Its only door to the engine is `xschem raw add <name> <expr>`,
# where `raw_add_vector()` registers `<name>` FIRST and the evaluator therefore
# resolves `yname` and writes the NAMED column (`src/save.c`, the
# `get_raw_index(yname)` arm at the top of `plot_raw_custom_data`).  Measured on
# the fixture (rows SR1): a second, unrelated `raw add` leaves an earlier named
# column byte-identical, so the shared-scratch collision L2 describes is NOT
# reachable from Tcl.
#
# ⚠ BUT THE HARM IS, BY A DIFFERENT MECHANISM, AND IT IS WORSE.  Re-using a
# destination name is the reachable form: `xschem raw add <name> <rejected
# expr>` leaves the column holding **the previous evaluation's numbers**, and
# answers 0 — which means "the vector already existed", not "the expression
# failed".  `raw_add_vector()` DISCARDS `plot_raw_custom_data()`'s return value,
# so from Tcl a good expression and a rejected one are indistinguishable by
# return.  That is L2's own sentence — *"get_raw_value() on an expression trace
# returns whatever was evaluated last"* — arriving through a reused name instead
# of a shared column, and it is the defect this file fences.
#
#   SR1  THE HAZARD, measured with no Calculator: a reused destination plus a
#        rejected expression hands back the previous answer, and `raw add` says
#        nothing is wrong.  Also the negative control — an unrelated add does
#        not disturb a named column — which is what narrows L2 to the re-use
#        case rather than leaving it a general fear.
#   SR2  §11.1's literal scenario: evaluate A, evaluate B, read — you get B.
#        Through `calc::eval_rpn`, including the case that makes it sharp, where
#        B is the REJECTED expression.
#   SR3  THE INTERLEAVE: an engine call between one evaluation and the next
#        changes neither answer, because each evaluation owns a destination
#        nothing else has — asserted by reading the destinations the dict
#        reports and proving they differ.
#   SR4  THE GUARD, forced.  `calc::eval_rpn` refuses rather than read a
#        destination it did not create.  Forced by shadowing `calc::tmpvec` so
#        it hands back a name that already holds another expression's numbers,
#        which is the only way the arm is reachable once the minting proc skips
#        existing names.  This is the row PLAN 3.2's sabotage line is about.
#   SR5  R605 STRUCTURALLY: the engine call and the read are in ONE proc with
#        nothing between them that could evaluate anything else, and no other
#        proc in the file reads a `__calc_tmp` column.  Plus R402's four-way
#        equality over the namespace, and the VIEWER's door -- whose door set is
#        DERIVED out of `::wviewer::` (the procs that issue the direct engine
#        verb, closed transitively over their callers) rather than spelled as an
#        alternation of two names, because the alternation named one real door
#        and one proxy and would have missed a Calculator route through any
#        other viewer entry point.  A structural row cannot
#        see everything (receipts/B3-final.md §10.1: it cannot see statement
#        ORDER in general), which is why SR2 and SR4 carry the behaviour and
#        this band carries only what text can honestly answer.
#   SR6  R402 on the refusing paths: nothing is left behind by a refusal.
#
# Standalone from the repo ROOT, headless (NOT a bare `./src/xschem`, which
# inherits $DISPLAY):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_calc_scratch_reuse.tcl
# or, gated and with a throwaway HOME, which is the armed spelling:
#   tests/headless/run_suites.sh --nogui test_calc_scratch_reuse

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_expr {name cond} {
    if {[catch {uplevel 1 [list expr $cond]} v]} { set v "ERR:$v" }
    check $name [expr {$v eq {1} ? 1 : 0}] 1
}
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

proc near {got exp tol} {
    if {![string is double -strict $got]} { return "NOTANUMBER:{$got}" }
    if {$exp == 0.0} {
        if {abs($got) <= $tol} { return ok }
        return "off:{$got} abs=[expr {abs($got)}]"
    }
    set r [expr {abs(($got - $exp) / double($exp))}]
    if {$r <= $tol} { return ok }
    return "off:{$got} rel=$r"
}
proc dg {d k} {
    if {[catch {dict get $d $k} v]} { return "NOKEY:$k" }
    return $v
}
proc rawnames {} {
    set l {}
    if {[catch {xschem raw list} l]} { return {} }
    return [split [string trim $l] "\n"]
}
# ⚠ COMPARED AS ONE COMMA-JOINED STRING, not as a Tcl list.  `i(@m1[id])`
# contains brackets, so Tcl's canonical list representation braces it and a
# `$got eq $exp` against a hand-typed list literal fails on the BRACES rather
# than on the names -- which is a failing row that says nothing about the tree.
proc names_csv {} { return [join [rawnames] ,] }
proc leaked {} {
    set out {}
    foreach n [rawnames] { if {[string match __calc_tmp* $n]} { lappend out $n } }
    return $out
}
set fixture {}
if {[file exists tests/headless/data/calc_fixture.raw]} {
    set fixture [file normalize tests/headless/data/calc_fixture.raw]
} elseif {[info exists ::XSCHEM_SHAREDIR]} {
    set cand [file join [file dirname $::XSCHEM_SHAREDIR] tests headless data calc_fixture.raw]
    if {[file exists $cand]} { set fixture [file normalize $cand] }
}
# ALWAYS with an explicit type -- see test_calc_engine.tcl's `fread` for the
# measurement that makes the bare spelling unsafe once a file has been read as
# more than one analysis in one process.
proc fread {ty} {
    if {$::fixture eq {}} { return NOFIXTURE }
    if {[catch {xschem raw read $::fixture $ty} r]} { return "ERR:$r" }
    return [list $r [pcall xschem raw sim_type]]
}
proc ev {rpn {ds 0}} {
    set d [pcall calc::eval_rpn $rpn $ds]
    if {[string match ERR:* $d]} { return $d }
    if {[dg $d ok] ne {1}} { return "REFUSED:[dg $d msg]" }
    return [list [dg $d value] [dg $d at]]
}
proc evval {rpn {ds 0}} {
    set r [ev $rpn $ds]
    if {[llength $r] != 2} { return $r }
    return [lindex $r 0]
}

# The two expressions every band uses, and their HAND-DERIVED values at the last
# transient sample (k = 100, t = 10 ms), from the fixture README:
#   A = v(div)        dataset 0 is v(ramp)/2, and v(ramp) at k=100 is 10 V -> 5
#   B = v(div) 2 /    half of that                                        -> 2.5
# They are chosen to be FAR APART and neither of them zero, so "you got the
# other one" and "you got a rejected column" are three distinguishable answers.
set A {v(div)}         ; set Aval 5
set B {v(div) 2 /}     ; set Bval 2.5
set REJECT {v(nosuch) v(div) +}

if {[catch {

# =============================================================================
# SR1 — the hazard itself, with no Calculator in the way
# =============================================================================
group SR1 {
    check_expr "SR1 fixture: the fixture was located" {$::fixture ne {}}
    check "SR1 fixture: the transient read" [fread tran] {1 tran}
    check "SR1 fixture: the premise -- v(div) at the last sample of dataset 0" \
        [near [pcall xschem raw value v(div) 100 0] $Aval 1e-7] ok
    # --- the reachable form of L2 -------------------------------------------
    pcall xschem raw del __calc_tmp_sr1
    check "SR1 a destination created with expression A holds A's numbers" \
        [list [pcall xschem raw add __calc_tmp_sr1 $A] \
              [near [pcall xschem raw value __calc_tmp_sr1 100 0] $Aval 1e-7]] {1 ok}
    set rc [pcall xschem raw add __calc_tmp_sr1 $REJECT]
    check "SR1 ⚠ re-using it for a REJECTED expression leaves A's numbers in place -- THIS IS THE BUG" \
        [near [pcall xschem raw value __calc_tmp_sr1 100 0] $Aval 1e-7] ok
    check "SR1 ...and `xschem raw add` answers 0, which means 'the vector existed', NOT 'the expression failed'" \
        $rc 0
    check "SR1 ...while a FRESH destination for the same rejected expression answers zero" \
        [list [pcall xschem raw add __calc_tmp_sr1b $REJECT] \
              [near [pcall xschem raw value __calc_tmp_sr1b 100 0] 0 1e-30]] {1 ok}
    # ⚠⚠ AND THE WRITE CANNOT BE TAKEN BACK, WHICH IS WHERE THE GUARD HAS TO GO.
    # `xschem raw add <name> <expr>` is register-OR-FIND and *then* evaluate, so
    # a call that answers 0 ("the vector was already there") has nevertheless
    # written the caller's expression into that column.  A guard that read the
    # return value and refused AFTERWARDS would protect the reported number and
    # not the data; `calc::eval_rpn` therefore asks `xschem raw index` BEFORE
    # calling the engine.  Measured here rather than asserted in a comment.
    pcall xschem raw del __calc_tmp_sr1d
    pcall xschem raw add __calc_tmp_sr1d $A
    set rc2 [pcall xschem raw add __calc_tmp_sr1d $B]
    check "SR1 ⚠ a `raw add` that answers 0 has STILL overwritten that column -- register-or-find THEN evaluate" \
        [list $rc2 [near [pcall xschem raw value __calc_tmp_sr1d 100 0] $Bval 1e-7]] {0 ok}
    pcall xschem raw del __calc_tmp_sr1d
    # --- and the negative control, which is what narrows L2 to the re-use case.
    # If an unrelated add DID disturb a named column, the whole design below
    # (one private destination per evaluation) would be worthless, so this row
    # is load-bearing rather than decorative.
    check "SR1 an UNRELATED add does not disturb a named column -- the shared-scratch collision is not reachable here" \
        [list [pcall xschem raw add __calc_tmp_sr1c $B] \
              [near [pcall xschem raw value __calc_tmp_sr1c 100 0] $Bval 1e-7] \
              [near [pcall xschem raw value __calc_tmp_sr1 100 0] $Aval 1e-7]] {1 ok ok}
    foreach n {__calc_tmp_sr1 __calc_tmp_sr1b __calc_tmp_sr1c} { pcall xschem raw del $n }
    check "SR1 the band cleaned up after itself" [leaked] {}
}

# =============================================================================
# SR2 — §11.1's literal scenario: evaluate A, evaluate B, read, you get B
# =============================================================================
group SR2 {
    check "SR2 fixture: the transient read" [fread tran] {1 tran}
    check "SR2 calc::eval_rpn exists" [llength [pcall info procs ::calc::eval_rpn]] 1
    set a [pcall calc::eval_rpn $A 0]
    set b [pcall calc::eval_rpn $B 0]
    check "SR2 evaluate A, then B: A answered A's value" \
        [list [dg $a ok] [near [dg $a value] $Aval 1e-7]] {1 ok}
    check "SR2 ...and B answered B's value, not A's" \
        [list [dg $b ok] [near [dg $b value] $Bval 1e-7]] {1 ok}
    # ⚠ THE SHARP CASE, and the one the naive implementation gets wrong.  If
    # Evaluate re-used one destination, B being REJECTED would hand back A's
    # number with no indication at all (SR1 measured exactly that).
    #
    # ⚠⚠ RESTATED BY PLAN 3.4, AND THE RESTATEMENT IS STRICTLY STRONGER.  This
    # row used to assert `ok 1` plus "a defined zero" -- the engine's own answer
    # for a rejected expression since issue 0325 -- because that was the best
    # the product could do before R607 existed.  Now Evaluate REFUSES and names
    # the token, so the claim becomes "never A's value AND never a number at
    # all", with the token in the sentence.  The hazard this band exists for is
    # unchanged and is still what the rows measure: the answer must never be the
    # PREVIOUS expression's 5.
    set a2 [pcall calc::eval_rpn $A 0]
    set r2 [pcall calc::eval_rpn $REJECT 0]
    check "SR2 ⚠ evaluate A, then a REJECTED B: the answer is a REFUSAL naming the token, never A's value" \
        [list [dg $r2 ok] [dg $r2 value] [string match {*v(nosuch)*} [dg $r2 msg]]] {0 {} 1}
    check "SR2 ...and the premise held -- A really did answer 5 immediately before it" \
        [near [dg $a2 value] $Aval 1e-7] ok
    # the other direction too: a rejected expression must not poison the NEXT
    # evaluation either.
    set a3 [pcall calc::eval_rpn $A 0]
    check "SR2 ...and an evaluation AFTER a rejected one is unaffected" \
        [near [dg $a3 value] $Aval 1e-7] ok
}

# =============================================================================
# SR3 — the interleave
# =============================================================================
# §11.1 asks to "interleave a plot between evaluate and read".  From outside the
# product that interleave cannot be placed between the two, because R605's whole
# requirement is that there is no "between": `calc::eval_rpn` evaluates and
# reads in one proc.  What CAN be measured, and is what makes the interleave
# harmless, is that every evaluation owns a destination no other writer has --
# so an engine call before, after, or (by SR4's forcing) in place of it cannot
# change the answer.  PLAN 3.3's Plot is exactly such a writer: it will call
# `xschem raw add <auto name> <rpn>` through `wviewer::add_trace`.
# =============================================================================
group SR3 {
    check "SR3 fixture: the transient read" [fread tran] {1 tran}
    set a [pcall calc::eval_rpn $A 0]
    # what a Plot does to the raw, between two evaluations
    pcall xschem raw add sr3_plotlike {v(ramp) 3 /}
    set b [pcall calc::eval_rpn $B 0]
    pcall xschem raw add sr3_plotlike2 {v(sq) v(ramp) *}
    set a2 [pcall calc::eval_rpn $A 0]
    check "SR3 an engine call between two evaluations changes neither answer" \
        [list [near [dg $a value] $Aval 1e-7] [near [dg $b value] $Bval 1e-7] \
              [near [dg $a2 value] $Aval 1e-7]] {ok ok ok}
    check "SR3 ...and the three evaluations used three DIFFERENT destinations" \
        [llength [lsort -unique [list [dg $a dest] [dg $b dest] [dg $a2 dest]]]] 3
    check "SR3 ...each of which is a __calc_tmp<N> name and is gone again" \
        [list [regexp {^__calc_tmp[0-9]+$} [dg $a dest]] \
              [regexp {^__calc_tmp[0-9]+$} [dg $b dest]] \
              [pcall xschem raw index [dg $a dest]] \
              [pcall xschem raw index [dg $b dest]]] {1 1 -1 -1}
    pcall xschem raw del sr3_plotlike
    pcall xschem raw del sr3_plotlike2
    check "SR3 the band cleaned up after itself" \
        [list [leaked] [pcall xschem raw index sr3_plotlike]] {{} -1}
}

# =============================================================================
# SR4 — THE GUARD, forced.  This is PLAN 3.2's sabotage target.
# =============================================================================
# The guard is `xschem raw add`'s own return read as what it means: 1 = this
# call CREATED the column, 0 = it was already there and somebody else's
# evaluation may be in it.  `calc::tmpvec` skips names the raw already holds, so
# on an untouched tree the 0 arm is unreachable — which is exactly why it has to
# be forced here rather than hoped for.  Shadowing the minting proc is the
# mechanism test_calc_buffer.tcl's CB2/8.5 band uses for the Tk 8.5 fallback and
# test_calc_skeleton.tcl's S13 uses for R508's third case.
#
# Without the guard the product would answer A's 5 for a rejected B, which is
# SR1's bug with the Calculator's name on it.
# =============================================================================
group SR4 {
    check "SR4 fixture: the transient read" [fread tran] {1 tran}
    check "SR4 calc::tmpvec exists and is what eval_rpn mints through" \
        [list [llength [pcall info procs ::calc::tmpvec]] \
              [regexp {calc::tmpvec} [pcall info body ::calc::eval_rpn]]] {1 1}
    # plant a column holding A's numbers, under the name the shadow will hand back
    pcall xschem raw del __calc_tmp_sr4
    check "SR4 fixture: the planted column holds A's numbers" \
        [list [pcall xschem raw add __calc_tmp_sr4 $A] \
              [near [pcall xschem raw value __calc_tmp_sr4 100 0] $Aval 1e-7]] {1 ok}
    # ⚠⚠ THE TWO PROBE EXPRESSIONS CHANGED ROLES AT PLAN 3.4, AND THE REASON IS
    # A REAL ORDERING PROPERTY.  Both arms used to be the stale-destination
    # refusal -- that was the band's point, that the guard is about the COLUMN
    # and not the expression -- and the REJECT arm reached it because nothing
    # looked at the tokens first.  R607's pre-flight now runs BEFORE the mint,
    # so a rejected expression is refused BY NAME and never meets the column
    # guard at all.  That order is the right one (telling a user their
    # `__calc_tmp7` collided when what they typed was `v(nosuch)` is useless),
    # so the REJECT arm now measures the ORDER and `$d2`, the GOOD expression,
    # carries the whole of the column-guard claim it used to share.
    #
    # ⚠ A THIRD ARM IS ADDED so "the guard is about the COLUMN, not the
    # expression" is still measured against TWO different good expressions
    # rather than one -- otherwise a product that refused only `$B` would pass.
    # ⚠⚠ THE PLANTED COLUMN'S DATA IS RE-READ AFTER **EACH** CALL, NOT ONCE AT
    # THE END, AND THE FIRST DRAFT OF THIS RESTRUCTURE GOT THAT WRONG.  Adding a
    # third arm that evaluates `$A` again, after `$B`, DESTROYED the end-of-band
    # data check's observable: with the pre-engine guard removed, `$B` overwrote
    # the planted 5 with 2.5 and then `$A` wrote 5 back, so the final read saw
    # exactly the value the row expected and Stage C's sabotage `C` -- the
    # pre-engine guard removed, the belt kept -- went from ONE red to ZERO.
    # That is CLAUDE.md's "a fence keyed to a symptom dies quietly when
    # something else cures the symptom", caused here by the row added beside it.
    # Three reads, one per call, each immediately after its own call.
    pcall rename ::calc::tmpvec ::sr4_real_tmpvec
    proc ::calc::tmpvec {} { return __calc_tmp_sr4 }
    set d [pcall calc::eval_rpn $REJECT 0]
    set dat1 [pcall xschem raw value __calc_tmp_sr4 100 0]
    set d2 [pcall calc::eval_rpn $B 0]
    set dat2 [pcall xschem raw value __calc_tmp_sr4 100 0]
    set d3 [pcall calc::eval_rpn $A 0]
    set dat3 [pcall xschem raw value __calc_tmp_sr4 100 0]
    pcall rename ::calc::tmpvec {}
    pcall rename ::sr4_real_tmpvec ::calc::tmpvec
    check "SR4 the planted column's DATA survives EVERY ONE of the three refused calls, read after each -- which is what forces the guard in FRONT of the engine call rather than behind it" \
        [list [near $dat1 $Aval 1e-7] [near $dat2 $Aval 1e-7] [near $dat3 $Aval 1e-7]] \
        {ok ok ok}
    check "SR4 ⚠ a REJECTED expression is refused by TOKEN before the destination is even minted -- R607 is ahead of the column guard, which is why a mistyped name never reports a collision" \
        [list [dg $d ok] [string match {*v(nosuch)*} [dg $d msg]] \
              [string match *__calc_tmp_sr4* [dg $d msg]]] {0 1 0}
    check "SR4 ...and it does NOT hand back the planted value" \
        [expr {[near [dg $d value] $Aval 1e-7] eq {ok}}] 0
    check "SR4 ⚠ handed a destination it did not create, eval_rpn REFUSES instead of reading it, and the refusal names the destination" \
        [list [dg $d2 ok] [string match *__calc_tmp_sr4* [dg $d2 msg]] \
              [expr {[near [dg $d2 value] $Aval 1e-7] eq {ok}}]] {0 1 0}
    check "SR4 ...and the same refusal is taken for a SECOND good expression, because the guard is about the COLUMN, not the expression" \
        [list [dg $d3 ok] [string match *__calc_tmp_sr4* [dg $d3 msg]]] {0 1}
    # ⚠ THE NON-VACUITY CONTROL.  Without it this band would pass on a product
    # that refuses EVERYTHING, which is the cheapest wrong way to be green here.
    set ok [pcall calc::eval_rpn $A 0]
    check "SR4 non-vacuity: with the real minting proc back, the same expression is answered" \
        [list [dg $ok ok] [near [dg $ok value] $Aval 1e-7]] {1 ok}
    # ⚠ AND THE PLANTED COLUMN IS UNTOUCHED, IN BOTH SENSES -- not deleted, and
    # its DATA not overwritten.  The second half is what forces the guard to sit
    # in front of the engine call rather than behind it: SR1 measured that a
    # `raw add` answering 0 has already written the expression into that column,
    # so a product that refused on the RETURN VALUE would pass the three rows
    # above and still have clobbered somebody else's data.  5 here, not B's 2.5.
    check "SR4 the refused call neither deleted the planted column nor overwrote its data, because it refuses BEFORE the engine runs" \
        [list [expr {[pcall xschem raw index __calc_tmp_sr4] >= 0}] \
              [near [pcall xschem raw value __calc_tmp_sr4 100 0] $Aval 1e-7]] {1 ok}
    pcall xschem raw del __calc_tmp_sr4
    check "SR4 the band cleaned up after itself" [leaked] {}
}

# =============================================================================
# SR5 — R605 structurally
# =============================================================================
group SR5 {
    set body [pcall info body ::calc::eval_rpn]
    check_expr "SR5 eval_rpn's body was readable" {![string match ERR:* $body]}
    # ⚠⚠ COMMENTS STRIPPED FIRST, both whole-line and tail, IN EVERY SCAN IN
    # THIS BAND -- and the fact that it took a false red to make that true is the
    # most useful thing in this file.  A complete command parked in a tail
    # comment is read as code by any line scanner: that is why
    # test_registered_banner_1626.tcl grew `rb_decomment`, and why row RB5 there
    # went red on a comment before it did.  An earlier revision of THIS band
    # stripped comments for the adjacency scan below and then handed three
    # NAMESPACE-WIDE scans the raw `info body` -- so the moment
    # `calc::eval_cursor_point` grew an in-body comment NAMING `calc::eval_rpn`
    # (a declared-limit note saying that proc re-tests the point itself), the
    # caller row answered `{eval_cursor_point eval_in_token}` and reddened on
    # PROSE.  The band whose own comment cited RB5's false red reproduced it four
    # lines later.  The stripper is one proc now, used by all four scans, with a
    # poison control that proves it in both directions.
    proc sr_code {b} {
        set out {}
        foreach ln [split $b "\n"] {
            if {[regexp {^[ \t]*#} $ln]} continue
            regsub {;[ \t]*#.*$} $ln {} ln
            append out $ln "\n"
        }
        return $out
    }
    # every proc in the namespace, decommented ONCE, so no scan below can read
    # the raw body by accident.
    set pbody {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        set b [pcall info body $p]
        if {[string match ERR:* $b]} continue
        dict set pbody [namespace tail $p] [sr_code $b]
    }
    set code [sr_code $body]
    check_expr "SR5 the stripper left real code behind (positive control)" \
        {[string match {*raw add*} $code] && [string length $code] > 200}
    # ...and the NEGATIVE control, which is the half that was missing: a body
    # whose ONLY mention of each scanned command is in a comment must score
    # zero on all three predicates, whole-line and tail alike.
    set poison "    set z 1\n    # xschem raw value v(a) 0 and calc::eval_rpn and xschem raw add x\n    set y 2 ;# xschem raw add x {1 1 +}\n"
    set pc [sr_code $poison]
    check "SR5 negative control: three commands mentioned ONLY in comments survive the raw body and are gone from the stripped one" \
        [list [regexp {xschem raw value} $poison] [regexp {calc::eval_rpn} $poison] \
              [regexp {xschem raw add} $poison] \
              [regexp {xschem raw value} $pc] [regexp {calc::eval_rpn} $pc] \
              [regexp {xschem raw add} $pc]] {1 1 1 0 0 0}
    check "SR5 ...and the stripper keeps the real code on either side of those comments" \
        [list [regexp {set z 1} $pc] [regexp {set y 2} $pc]] {1 1}
    # The engine call and the first read, in order, with NOTHING between them
    # that could evaluate anything else.  What "nothing" means here is checkable:
    # the only commands allowed between the `raw add` line and the first
    # `raw value` line are none at all -- they are adjacent statements.
    set lines {}
    foreach ln [split $code "\n"] {
        set t [string trim $ln]
        if {$t eq {}} continue
        lappend lines $t
    }
    set iadd -1 ; set ival -1
    for {set i 0} {$i < [llength $lines]} {incr i} {
        set t [lindex $lines $i]
        if {$iadd < 0 && [regexp {xschem raw add} $t]} { set iadd $i ; continue }
        if {$iadd >= 0 && $ival < 0 && [regexp {xschem raw value} $t]} { set ival $i }
    }
    check "SR5 R605 the engine call and the read are both in eval_rpn's own body" \
        [list [expr {$iadd >= 0}] [expr {$ival >= 0}]] {1 1}
    check "SR5 R605 ...and the read is the statement IMMEDIATELY after the engine call -- nothing in between" \
        [expr {$ival - $iadd}] 1
    # ⚠⚠ THE TWO ROWS BELOW USED TO READ `{eval_rpn}` -- A ONE-NAME LITERAL --
    # AND THEY WERE WIDENED FOR `cross` (PLAN 7.2) BY DERIVING THE SET, NOT BY
    # LENGTHENING THE LITERAL.  While the T route had exactly one member the
    # literal and the truth coincided; they no longer do.  Writing
    # `{cross eval_rpn}` would be the same hand-kept list one name longer, and
    # seven more T-route verbs stand on `cross` (riseTime, slewRate, delay,
    # dutyCycle, frequency, settlingTime, overshoot), so the next one would have
    # to edit it again and whoever forgot would meet a red that says nothing
    # about what is actually wrong.  A hand-kept list is the same defect one
    # level up -- the reason row X1 of test_snprintf_fmt_1608.tcl exists.
    #
    # WHAT IS DERIVED, AND WHY THESE FOUR PROPERTIES.  R402's discipline is that
    # a proc which evaluates into a temporary column owns that column's whole
    # life: it MINTS the name (calc::tmpvec), it ADDS through the direct engine
    # verb, it READS the samples back, and it DELETES the column before it
    # returns, on every exit path including the error ones.  All four are visible
    # in a decommented body, so the four sets are computed INDEPENDENTLY and the
    # claim is about how they relate: an engine caller that forgets the mint, or
    # the delete, or reads back a column it did not create, reddens here, and the
    # row prints which set it fell out of.
    #
    # ⚠⚠ THE EQUALITY IS ANCHORED ON THE *READERS*, NOT ON THE ADDERS, AND THAT
    # IS A WIDENING THE R419 DESTINATION STAGE OWED -- the same edit `cross` owed
    # one stage earlier, and made the same way: by moving the anchor rather than
    # by lengthening a literal.
    #
    # R402's mint-and-delete discipline is about a TEMPORARY -- a column a verb
    # evaluates into, READS, and must remove before it returns -- and what makes
    # it temporary is precisely the read-back.  `calc::wave_dest` (R419/R421, the
    # destination for a result whose X axis is not the loaded sweep) issues the
    # direct verb because creating a second column is the only thing that verb is
    # for, but its Y column is PERSISTENT BY DESIGN: the trace keeps reading it
    # for the life of the database, so there is nothing to mint, nothing to read
    # back and nothing to delete.  Anchoring on the adders made it a counted
    # failure for doing the right thing.  That is the very exemption this band's
    # own comment already grants `calc::plot_rpn` for reaching the engine through
    # `wviewer::add_trace`; the destination is a THIRD door of the same kind, and
    # unlike Plot's it is VISIBLE to a scan over this namespace.
    #
    # The pre-flight obligation moved with the anchor for the same reason it
    # exists: `xschem raw add` answers 1 for an expression the engine rejected
    # and leaves defined zeros behind, so the harm is a caller READING BACK a
    # confident zero.  A producer handed VALUES, which sends the engine no
    # expression at all, has no expression to pre-flight and no number to
    # misreport.
    #
    # ⚠ AND THE WIDENING IS FENCED RATHER THAN OPEN: the adders that read nothing
    # back are asserted as a ONE-NAME LITERAL, so a SECOND add-without-read door
    # reddens here and has to justify itself instead of inheriting an exemption.
    # ⚠ THIS SENTENCE USED TO SAY *"exactly as the viewer-door row at the foot of
    # this band is"*, and that cross-reference went stale the moment the viewer
    # door became a derived set with a floor -- which is this tree's own rule
    # about cross-references being checked rather than trusted, caught here
    # rather than shipped.  The viewer-door row is NOT a literal any more; this
    # one still is, because the direct engine verb is a door a scan over THIS
    # namespace can see and the viewer's is not.  Rows WD10 of
    # tests/headless/test_calc_wave_dest.tcl carry the same invariant from the
    # producer's own side.
    #
    # ⚠ AND "EXACTLY ONE DIRECT VERB" IS KEPT AS A SEPARATE, NARROW CLAIM rather
    # than dissolved into the derivation -- see the disjointness row at the foot
    # of this band.  Plot reaches the SAME engine through `wviewer::add_trace`,
    # inside src/wave_viewer.tcl where no scan over this namespace can see it,
    # and L2 does not apply to that route: its destination is a persistent named
    # vector the trace keeps reading, so there is nothing to delete.  The two
    # doors must stay DISJOINT, because a proc on both would carry an R402
    # obligation its viewer half does not know it has.
    set minters {} ; set adders {} ; set readers {} ; set deleters {} ; set preflight {}
    dict for {nm b} $pbody {
        if {[regexp {calc::tmpvec} $b]}        { lappend minters   $nm }
        if {[regexp {xschem raw add} $b]}      { lappend adders    $nm }
        if {[regexp {xschem raw value} $b]}    { lappend readers   $nm }
        if {[regexp {xschem raw del} $b]}      { lappend deleters  $nm }
        if {[regexp {calc::rpn_bad_token} $b]} { lappend preflight $nm }
    }
    check_expr "SR5 the decommented namespace map is not vacuous -- every proc in it, bodies kept" \
        {[dict size $pbody] >= 25 && [string match {*raw add*} [dict get $pbody eval_rpn]]}
    set notadders {}
    foreach nm $readers {
        if {[lsearch -exact $adders $nm] < 0} { lappend notadders $nm }
    }
    check "SR5 R402 DERIVED: the procs that MINT a temporary, READ its samples back and DELETE the column are one and the same set, and every one of them issues the DIRECT engine verb -- computed four ways over the decommented namespace, so a caller that skips any one of the four reddens and the row prints which set it fell out of" \
        [list $readers $minters $deleters $notadders] \
        [list $readers $readers $readers {}]
    # ...and the other direction of the widening, as a ONE-NAME LITERAL: an adder
    # that reads nothing back owes no delete, and there is exactly one such door.
    set persistent {}
    foreach nm $adders {
        if {[lsearch -exact $readers $nm] < 0} { lappend persistent $nm }
    }
    check "SR5 R402 ...and the only direct adder that reads NOTHING back is the R419 destination producer, whose Y column is persistent by design -- a literal, because the direct engine verb is a door a scan over this namespace can see, so a SECOND add-without-read door reddens here and has to justify itself rather than inheriting the exemption" \
        $persistent {wave_dest}
    # ⚠ THE NON-VACUITY LEG, and it is not decoration: EMPTY lists satisfy the
    # equality above perfectly, which is how the row would read on a tree where
    # `info body` answered nothing.  Two names are named here as a positive
    # CONTROL on the derivation, never as the fence -- the fence is the equality.
    # BOTH sets carry a count, because the equality is now over `readers` while
    # the subset leg is over `adders`, and either one going empty would pass.
    check_expr "SR5 ...and neither derived set is empty or a single name any more: the readers hold both eval_rpn and cross, and the adders hold strictly more than the readers, which is what makes the equality a claim about real bodies" \
        {[llength $readers] >= 2 && [lsearch -exact $readers eval_rpn] >= 0 \
         && [lsearch -exact $readers cross] >= 0 \
         && [llength $adders] > [llength $readers]}
    # ...and the fifth property, as a SUBSET claim rather than an equality,
    # because `plot_rpn` pre-flights too while reaching the engine through the
    # viewer's door.  Every caller that sends the engine an EXPRESSION and reads
    # the column back must run calc::rpn_bad_token BEFORE the engine:
    # `xschem raw add` answers 1 for an expression the engine rejected and leaves
    # defined zeros behind, so there is no failure downstream to read and such a
    # caller would report a confident zero.  ⚠ ANCHORED ON THE READERS for that
    # exact reason -- the R419 destination producer is handed VALUES, sends the
    # engine no expression and reads nothing back, so it has neither an
    # expression to pre-flight nor a number to misreport.
    set notpreflighted {}
    foreach nm $readers {
        if {[lsearch -exact $preflight $nm] < 0} { lappend notpreflighted $nm }
    }
    check "SR5 ...and EVERY member of that derived set runs calc::rpn_bad_token, asserted as a subset with the member count riding along so an empty set cannot pass it" \
        [list [llength $readers] $notpreflighted] [list [llength $readers] {}]
    # ⚠⚠ "EXACTLY ONE" IS A CLAIM ABOUT THE DIRECT VERB AND NOTHING ELSE, AND
    # SINCE PLAN 3.3 THAT DISTINCTION IS LOAD-BEARING RATHER THAN PEDANTIC.
    # Plot reaches the SAME engine, through `wviewer::add_trace`, which issues
    # the `raw add` inside src/wave_viewer.tcl where no scan over this namespace
    # can see it.  Leaving the row's name as "calls the engine" would have made
    # it quietly false the moment Plot landed.  L2 does NOT apply to that route:
    # `add_trace`'s destination is a PERSISTENT named vector minted by
    # `wviewer::auto_expr_name` (which skips every name `xschem raw index`
    # already resolves) and the trace has to keep reading it, so there is
    # nothing to delete and no shared scratch column in play.  Asserted, not
    # claimed -- and derived from the namespace, so a Plot proc that grew its own
    # `raw add` would redden the row ABOVE instead of escaping this one.
    #
    # ⚠⚠ THE DERIVATION BELOW USED TO BE A HAND-KEPT ALTERNATION OF TWO NAMES --
    # `wviewer::(add_trace|plot_signals)` -- AND THAT IS THE SAME DEFECT ONE
    # LEVEL UP AS THE LITERAL THIS BAND ALREADY REPLACED TWICE.  Measured: the
    # `::wviewer::` procs that issue the direct engine verb THEMSELVES are three
    # (`add_trace`, `paste_traces`, `restore`) and `plot_signals` is not one of
    # them -- it reaches `add_trace` -- so the shipped pattern named one real
    # door and one proxy for another, and matched neither `browser_plot_ids`, nor
    # `paste_traces`, nor any new viewer entry point.  Also measured:
    # `regexp {wviewer::(add_trace|plot_signals)} wviewer::plot_sweeps_arm`
    # answers 0, so a Calculator proc that armed the one-shot sweep channel and
    # then plotted through a third route left this row GREEN at one name while a
    # second Calculator-to-viewer route existed.  So the DOOR SET is derived out
    # of the viewer's own namespace -- the direct issuers, closed transitively
    # over the procs that call them -- and the row matches any member.
    #
    # ⚠ AND THE SECOND DODGE IS CLOSED FROM THE OTHER SIDE, not here: `$pbody` is
    # built over `[info procs ::calc::*]` ONLY, so an armer placed in
    # `::wviewer::` would escape this row entirely.  Band WD12 of
    # tests/headless/test_calc_wave_dest.tcl derives the armer set over `::calc::`
    # and asserts it is NOT EMPTY, which is the leg that fails on that dodge.
    proc sr_floor {v n} {
        if {![string is integer -strict $v]} { return "notacount:$v" }
        if {$v >= $n} { return atleast }
        return "only:$v"
    }
    proc sr_has {l nm} { return [expr {[lsearch -exact $l $nm] >= 0 ? {has} : "MISSING:$nm"}] }
    set wbody {}
    foreach p [lsort [pcall info procs ::wviewer::*]] {
        set b [pcall info body $p]
        if {[string match ERR:* $b]} continue
        dict set wbody [namespace tail $p] [sr_code $b]
    }
    proc sr_nameref {nm} {
        set pat {}
        append pat {wviewer::} $nm {([^A-Za-z0-9_]|$)}
        return $pat
    }
    set direct {}
    dict for {nm b} $wbody { if {[regexp {xschem raw add} $b]} { lappend direct $nm } }
    set doors [lsort -unique $direct]
    for {set it 0} {$it < 40} {incr it} {
        set grew 0
        dict for {nm b} $wbody {
            if {[lsearch -exact $doors $nm] >= 0} continue
            foreach d $doors {
                if {[regexp [sr_nameref $d] $b]} { lappend doors $nm ; set grew 1 ; break }
            }
        }
        set doors [lsort -unique $doors]
        if {!$grew} break
    }
    check "SR5 ...and the VIEWER's door set is DERIVED out of the viewer's own namespace instead of spelled as an alternation of two names: the procs whose decommented body issues the direct engine verb, closed transitively over the procs that call them, with a floor on both and the two entry points this batch actually uses named as a positive control -- so a Calculator proc reaching the engine through a THIRD viewer entry point is caught rather than walking past a hand-kept pattern" \
        [list [sr_floor [llength $direct] 3] [sr_has $direct add_trace] \
              [expr {[llength $doors] > [llength $direct] ? {wider} : {NOTWIDER}}] \
              [sr_has $doors plot_signals] [sr_has $doors add_trace] \
              [sr_floor [dict size $wbody] 100]] \
        {atleast has wider has has atleast}
    set viaviewer {}
    dict for {nm b} $pbody {
        foreach d $doors {
            if {[regexp [sr_nameref $d] $b]} { lappend viaviewer $nm ; break }
        }
    }
    set viaviewer [lsort -unique $viaviewer]
    # ⚠ A FLOOR AND A MEMBERSHIP, NOT A SNAPSHOT LITERAL, and that is the
    # treatment this batch gave WD9's keystone when the caller set moved: the
    # floor is RE-DERIVED when a unit adds a route rather than decremented, and
    # the two names are a positive control on the derivation.  Plot reaches the
    # engine through `wviewer::add_trace` and the R419/R421 hand-off through
    # `wviewer::plot_signals`; both are inside src/wave_viewer.tcl where no scan
    # over this namespace can see the `raw add` itself.
    check "SR5 ...and the procs that reach the engine through the VIEWER's door instead are Plot's and the measured-wave hand-off's, which is why no R402 delete belongs to either -- asserted as a floor plus the membership of both, over the derived door set, so a unit that adds a route raises the floor by measuring rather than lowering it" \
        [list [sr_floor [llength $viaviewer] 2] [sr_has $viaviewer plot_rpn] \
              [sr_has $viaviewer wave_show] $viaviewer] \
        [list atleast has has $viaviewer]
    # ...and the REASON the exemption is sound, derived rather than asserted by
    # name: a viewer-door proc carries NO R402 obligation at all, because
    # `add_trace`'s destination is a PERSISTENT named vector the trace keeps
    # reading.  A proc that both reached the viewer's door AND minted, read back
    # or deleted a temporary would be one with a delete obligation on a column a
    # trace is still reading -- a vanishing trace rather than a stale number --
    # and this leg names it instead of leaving the exemption to a one-name list.
    set viaowing {}
    foreach nm $viaviewer {
        if {[lsearch -exact $minters $nm] >= 0 || [lsearch -exact $readers $nm] >= 0
                || [lsearch -exact $deleters $nm] >= 0} { lappend viaowing $nm }
    }
    check "SR5 ...and NO proc on the viewer's door carries an R402 obligation -- derived against the mint, read-back and delete sets this band already computed, with the viewer set's own count riding along so an empty one cannot pass it" \
        [list [llength $viaviewer] $viaowing] [list [llength $viaviewer] {}]
    # ⚠ THE NARROW HALF OF "EXACTLY ONE DIRECT VERB", now that the direct set has
    # more than one member: the two doors are DISJOINT.  A proc on both would be
    # one with an R402 delete obligation on a column the viewer's trace is still
    # reading -- which is the opposite failure from a leak and would show up as a
    # vanishing trace, not as a stale number.  Both counts ride along so neither
    # set can pass this by being empty.
    set bothdoors {}
    foreach nm $adders {
        if {[lsearch -exact $viaviewer $nm] >= 0} { lappend bothdoors $nm }
    }
    check "SR5 ...and no proc uses BOTH doors -- derived from the two sets, with both counts riding along" \
        [list [llength $adders] [llength $viaviewer] $bothdoors] \
        [list [llength $adders] [llength $viaviewer] {}]
    # ...and exactly one proc calls THAT one, which is what keeps the engine
    # step inside the borrowed context R603 names.  A press that called
    # `calc::eval_rpn` straight from `calc::eval_click` would evaluate against
    # whatever raw THIS window has -- the `self` arm U6 removed -- and would
    # redden nothing else in this file, so the row is here rather than assumed.
    set callers {}
    dict for {nm b} $pbody {
        if {$nm eq {eval_rpn}} { continue }
        if {[regexp {calc::eval_rpn} $b]} { lappend callers $nm }
    }
    check "SR5 ...and exactly ONE proc calls eval_rpn, the one that holds the context loan" \
        $callers {eval_in_token}
}

# =============================================================================
# SR6 — R402 on the refusing paths
# =============================================================================
group SR6 {
    check "SR6 fixture: the transient read" [fread tran] {1 tran}
    check "SR6 nothing is leaked before the band starts" [leaked] {}
    foreach {label rpn ds} {
        empty-expression   {}                      0
        rejected-token     {v(nosuch) v(div) +}    0
        bad-dataset        {v(div)}                9
    } {
        set d [pcall calc::eval_rpn $rpn $ds]
        check "SR6 R402 nothing is left behind after: $label" [leaked] {}
    }
    # ...including the forced-collision refusal, which is the one that returns
    # EARLY, before the proc has anything of its own to delete -- and must
    # therefore not delete the column it refused to read.
    pcall xschem raw add __calc_tmp_sr6 {v(div)}
    pcall rename ::calc::tmpvec ::sr6_real_tmpvec
    proc ::calc::tmpvec {} { return __calc_tmp_sr6 }
    pcall calc::eval_rpn {v(div)} 0
    pcall rename ::calc::tmpvec {}
    pcall rename ::sr6_real_tmpvec ::calc::tmpvec
    check "SR6 R402 the forced-collision refusal deleted nothing of somebody else's" \
        [expr {[pcall xschem raw index __calc_tmp_sr6] >= 0}] 1
    pcall xschem raw del __calc_tmp_sr6
    check "SR6 and the ten fixture vectors are untouched at the end of the file" \
        [names_csv] \
        {time,@m1[gm],i(@m1[id]),i(@rdc1[i]),i(@rtop[i]),v(dcmid),v(div),v(lp),v(ramp),v(sq)}
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

## ⚠⚠ THE `OVERALL: ok` SENTINEL IS WHAT T1 CAN SCORE -- `banner_complete` in
## tests/banner_rule.tcl is the ONLY Tcl reader of the rule and accepts no
## `RESULT: ALL PASS` spelling, while run_suites.sh and full_audit.sh carry their
## own EREs which DO accept it.  Passing standalone is therefore no evidence a
## suite can be registered (issue 1626).  `RESULT:` is kept LAST because
## summarize_all publishes a case's last `^RESULT:` line; a SECOND `RESULT:`
## line would silently rewrite the published check count (issue 1627, open), so
## this file has ONE exit path and any later one must print its verdict INSTEAD
## of this one.  Only the success path claims completion.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
