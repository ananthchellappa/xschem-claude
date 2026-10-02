# tests/headless/test_calc_cross.tcl — `cross()`: the X value where an
# expression crosses a threshold level, selected by an ORDINAL that reads from
# BOTH ENDS.
#
# Spec     doc/claude/specs/calculator.md §7.2aa (R414-R414e) and §7.3
#          (R401-R405); §11.2 (the fixture contract)
# Contract doc/claude/calculator_batch/CROSS_CONTRACT.md — D1-D12.  That file
#          decides what the spec leaves to the implementer, and every band here
#          names the decision it fences.
# Evidence doc/claude/calculator_batch/receipts/F-cross-recon.md
# Plan     doc/claude/calculator_batch/PLAN.md rows 7.1 and 7.2
# Fixture  tests/headless/data/calc_fixture.raw, contract and HAND DERIVATIONS
#          in tests/headless/data/README.md
#
# ⚠⚠ THIS FILE WAS WRITTEN RED-FIRST, BEFORE `calc::cross` EXISTED.  Every
# behavioural band below failed when it was written, with `calc::cross` absent,
# and the transcript of that red is in the stage receipt.  A row written after
# the code has never been observed to fail and is unproven as a fence; these
# were.  The suite is deliberately NOT registered in tests/run_regression.tcl
# by the commit that creates it — an all-red registered suite is a standing red
# in T1 — so REGISTERING IT IS THE IMPLEMENTATION COMMIT'S JOB, in `hcases`,
# in the same change as the code.
#
# ⚠ WHAT `cross` IS, in one line, because the negative half is the part that
# gets implemented wrongly: `cross(<expr> <level> <nth> <edge>)` answers the X
# where <expr> crosses <level>; <edge> is rising/falling/either; <nth> is an
# ORDINAL over the crossings IN THAT DIRECTION, positive counting forward from
# the start, NEGATIVE COUNTING BACK FROM THE END (-1 = last), and 0 meaning
# every crossing.  The semantics came from the USER, who uses the reference
# tool professionally.  It is behaviour to match, not a design choice (R414).
#
# ⚠⚠ THE ANSWER'S REPRESENTATION IS DECIDED HERE, AND IN EXACTLY ONE PLACE.
# CROSS_CONTRACT D5 says to "pick a representation that cannot be silently
# consumed as a number" and leaves the choice to the implementer — but a
# red-first row cannot assert a representation nobody has chosen yet, so this
# file chooses, following `calc::eval_rpn`'s own vocabulary:
#
#   measured  -- a dict with key `ok` = 1 and the X under key `value`
#                (for nth = 0, `value` is the LIST of every crossing's X)
#   absent    -- D5: `ok` = 0 and key `absent` = 1, with a sentence under `msg`
#   refused   -- D7: `ok` = 0 and key `absent` = 0, with a sentence under `msg`
#
# and every answer also carries the dataset it read, under key `dataset`, which
# CX11's last row reads so a verb layered on `cross` can propagate it rather
# than guess.
#
# EVERY ROW READS THAT THROUGH FOUR PROCS AND NOWHERE ELSE: `cx_disp`,
# `cx_val`, `cx_msg` and `cx_key`.  An implementer who wants a different
# representation rewrites those FOUR and every row below keeps its meaning —
# which is the point of routing them through an adapter rather than spreading
# `dict get` over two hundred rows.
#
# ⚠ AN EARLIER REVISION OF THIS PARAGRAPH NAMED ONLY `cx_disp` / `cx_val` /
# `cx_msg`, AND IT WAS FALSE IN BOTH HALVES.  `cx_key` is called DIRECTLY from
# a band — CX11's "the answer reports which dataset it read" row — and the key
# it is called with, `dataset`, was not in the representation list above
# either.  So an implementer who had rewritten the three named procs would
# have left that one row reading the old representation, with nothing saying
# so.  The keys a row can reach are exactly `ok`, `absent`, `value`, `msg` and
# `dataset`, enumerated rather than counted, because a count in a comment is
# the one claim nothing in this file re-measures.
#
# What is NOT negotiable, because the contract states it, is
# that the three dispositions stay mutually distinguishable: D7's own sentence
# is that keeping "refused" apart from "absent" is what lets `settlingTime`
# tell "you asked me something meaningless" from "this signal never settles".
#
# ⚠ EVERY EXPECTED NUMBER IS HAND-DERIVED FROM THE DECK, not read back out of
# the fixture and not transcribed from the recon receipt.  `v(sq)` is
# PULSE(0 1 0.9m 0.2m 0.2m 1m 4m) on a 0.1 ms grid, so its rising edge k runs
# 0.9+4k -> 1.1+4k ms through 0 -> 1 linearly and crosses level L at
# t = 0.9 + 0.2L + 4k ms, and its falling edge k runs 2.1+4k -> 2.3+4k ms
# through 1 -> 0 and crosses L at t = 2.3 - 0.2L + 4k ms.  `sq_rise`/`sq_fall`
# below are those two lines of arithmetic and nothing else.  At L = 0.5 they
# give 1.0 / 5.0 / 9.0 ms rising and 2.2 / 6.2 ms falling, which is the
# fixture README's own hand derivation, so the two agree independently.
#
# ⚠ TOLERANCE, NOT EQUALITY, and the figure is CHOSEN rather than inherited.
# PLAN row 7.2 used to say "exact" and that was corrected: the README's
# measured headroom for `v(sq)` is 1e-11 relative and for `time` 1e-12.  This
# file uses 1e-7 relative (`CXTOL`) for a crossing X, which is LOOSER than
# either on purpose: a crossing is a quotient of differences of fixture
# samples, so it carries more dust than the samples it is built from, and
# pinning it to the column's own headroom would be fencing the arithmetic's
# round-off rather than the behaviour.  What 1e-7 still discriminates is
# everything these rows are about: the grid step is 1e-4 s against crossings at
# 1e-3 to 1e-2 s, i.e. a RELATIVE 1e-2 to 1e-1, so a snapped-to-sample answer
# misses by five orders of magnitude more than the tolerance allows — PROVIDED
# the level is chosen so the crossing does not land on a sample, which is the
# whole subject of band CX6 and the one thing an earlier revision of this file
# got wrong.
#
# ⚠ AN EARLIER REVISION JUSTIFIED 1e-7 BY CROSS_CONTRACT D10's TWO READ PATHS,
# AND D10 HAS SINCE BEEN REVERSED, SO THAT JUSTIFICATION IS GONE.  It argued
# that a non-zero `nth` would read samples one at a time through
# `xschem raw value`, which prints through `dtoa()` (`"%.8g"`, src/util.c), so
# eight significant digits was the most such an implementation could see, while
# the `nth = 0` path read `xschem raw values` at `"%.16g"` — and that a
# tolerance tight enough to separate the two routes would be red on a correct
# implementation.  D10 now reads samples in BULK for EVERY `nth`, precisely
# because `%.8g` cannot produce an answer worth asserting against a column
# whose documented headroom is 1e-12.  ⚠⚠ THE CONSEQUENCE IS A ROW, NOT A
# COMMENT: with ONE read path the two ends of the same ordered set are
# BIT-IDENTICAL, so CX3's and CX5's `eq` legs are now a STRONGER claim than any
# tolerance, and they say so in their own names.  Under the two-route design
# they could never have held — measured, `0.0009999999999999998` against
# `0.001` — so whoever reintroduces a second read path gets a red from a row
# whose name explains why.
#
# ⚠ A ROW MUST FAIL, NEVER THROW.  Issue 1616: one row wrote `dict get` on a
# value that was `{}` on the broken tree, the raise reached the file-scope
# catch, and a suite aborted at 62 of 402 checks, hiding 340 unrelated ones.
# Every call into the product here goes through `cx_call` or `pcall`, which
# turn a raise into a legible sentinel string.  And CROSS_CONTRACT D6 makes
# that structural rather than stylistic: the interpolation arithmetic RAISES
# on an infinite sample pair (measured, band CX10's own derivation leg), so a
# `cross` built in the obvious order would throw rather than refuse.
#
# ⚠ THE BLAST RADIUS IN *THIS* FILE IS ONE BAND, NOT THE FILE, and that is
# measured rather than assumed -- by reproducing these three catch layers in
# isolation.  A throw out of `::calc::cross` is caught by `cx_call` and fails
# ONE ROW; a throw out of the suite's own code is caught by `group`, which
# scores it as a counted FAIL and abandons THAT BAND's remaining rows while the
# next band still runs; the file-scope catch below only sees an error raised
# BETWEEN bands.  CROSS_CONTRACT D6 and an earlier revision of CX10's own row
# name both said a throw would "reach the file-scope catch and abort the whole
# suite" -- that is 1616's shape, not this file's, and the correction matters
# because it is what tells you the true cost: `llength` on an unmatched open
# brace used to take CX5, CX7, CX8, CX10, CX11 and CX14 -- and all of their
# remaining rows -- out this way, which is a wrong implementation hiding rows,
# not a suite that stops.  See `cx_len`, whose comment records how those six
# names were re-measured.  ⚠ THE ROW COUNT IS DELIBERATELY NOT QUOTED: an
# earlier revision said "18 remaining rows" and it was already wrong when it
# shipped -- and two different hazard shapes lose two different numbers of rows
# from the same six bands, so there is no figure to put here at all.  The bands
# are named instead, because a name does not drift when a row is added.
#
# ⚠ NO DISPLAY GATE, ON PURPOSE.  Nothing here touches a widget, so this is an
# `hcases` suite with ONE exit path.  It must NOT copy test_calc_buffer's or
# test_calc_plot's whole-file no-X early exit: those exits print no
# `OVERALL: ok`, so an `hcases` entry carrying one is scored
# `HARNESS: ... (exit=0, OVERALL_ok=0, died=0)` with every one of its own
# checks passing — issue 1615's incident exactly, and row RB6 of the
# registered test_registered_banner_1626 would redden with it.
#
#   CX0  Infrastructure: the fixture is the one §11.2 describes, read with an
#        EXPLICIT type; the sweep column is resolved BY NAME (D12's last
#        paragraph); an out-of-range point answers the empty string rather than
#        raising (D10); and the four `calc::` procs D11's pre-flight is built
#        out of are present.  PASSES TODAY.
#   CX1  Infrastructure: this suite's OWN implementation of D3's predicate and
#        D4's interpolation, run over `xschem raw values`, reproduces the
#        hand-derived crossing times of the deck.  Nothing in this band calls
#        the product.  PASSES TODAY, and it is what makes every band below
#        non-vacuous: if CX1 is green and CX2+ are red, the feature is absent;
#        if CX1 is red, the suite is broken and nothing else it says counts.
#   CX2  R414 positive `nth`: 1, 2, 3 count FORWARD from the start of the sweep.
#   CX3  R414c negative `nth`: -1, -2, -3 count BACK from the end.  D1 calls
#        this the single most likely thing to be implemented wrongly.
#   CX4  R414a the count is WITHIN the selected direction.  Measured on the
#        INVERTED square at level 0.3, because on `v(sq)` at 0.5 the last
#        crossing overall happens to be rising, so `rising -1` equals
#        `either -1` and a broken direction filter passes BY LUCK.
#   CX5  D2/D8 `nth = 0` is every crossing, in sweep order, not truncated.
#   CX6  R414d interpolated, NEVER snapped — at off-sample levels, because at
#        0.5 the crossings sit on samples and the row would be vacuous.
#   CX7  D3/D4's exact-sample hit: sample 50 of `v(sq)` is bit-exactly 0.5 and
#        D4's formula yields exactly `x[50]` with no special case.
#   CX8  R414b/D5 out of range at BOTH ENDS, symmetrically, and the absent
#        answer cannot be mistaken for a number — 0 is a legitimate X value —
#        and it carries the sentence under `msg` the representation paragraph
#        promises, which nothing used to measure.
#   CX9  D7 a malformed request is REFUSED, and a refusal stays DISTINCT from
#        an absence; the refusal SENTENCE is in one house shape across every
#        refusal kind this band can reach, per kind and named per kind, which
#        is what makes "one builder" a measurement rather than an inference.
#   CX10 D6 the finiteness gate runs BEFORE D3's predicate, with a derivation
#        leg showing what the other order answers: five phantom crossings, of
#        which three are silent wrong numbers and two RAISE.
#   CX11 D12 one dataset, explicit, defaulting to 0, never allpoints; the
#        dataset validated against `xschem raw datasets` before it is passed
#        (issue 1632 is an out-of-bounds read behind it); and the seam phantom
#        that reading allpoints manufactures.
#   CX12 D11 the pre-flight, four rules, each a measured defect if skipped.
#   CX13 R402 no `__calc_tmp*` survives, on EVERY exit path including the
#        refusals — and it cannot be driven by `raw add`'s return code, which
#        answers 1 for an expression the engine rejected.
#   CX14 D3's ACCEPTED LIMIT, pinned rather than left as prose: a trace that
#        arrives at exactly L, sits flat on it and leaves downwards registers a
#        rising crossing on entry and NO falling crossing on exit.  Not
#        reachable through the fixture trace, so the band builds a clamped
#        column.  A change here is a DECISION, not a regression.
#
# Standalone from the repo ROOT, headless.  NOT a bare `./src/xschem`, which
# inherits $DISPLAY and paints on the user's real screen:
#   env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script \
#       tests/headless/test_calc_cross.tcl
# or, gated and with a throwaway HOME, which is the armed spelling:
#   tests/headless/run_suites.sh --nogui test_calc_cross

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# any command, with a raise turned into a legible `ERR:` sentinel so the ROW
# fails instead of the band dying.  `cx_call` is the same idea for the product
# itself, where "the proc does not exist yet" needs its own sentinel.
# (A `check_expr` taking a predicate as a SCRIPT used to sit here.  It was
# removed because NOTHING CALLED IT -- every row states its claim as a value
# comparison through `check`, which is the shape that prints what it got.)
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}
# ⚠ THE LINE ENDS IN `: FAIL` SO THAT A READER COUNTS IT.  A bare `BGERROR:`
# line is invisible to both readers — run_suites.sh echoes `^(FAIL|FATAL)` and
# summarize_all counts lines ENDING in FAIL — and without a handler at all the
# error would not touch $fail, so the suite would print `OVERALL: ok` over a
# real failure.
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

# ---------------------------------------------------------------------------
# THE ADAPTER.  The procs in this file that know what `calc::cross` returns,
# enumerated rather than counted: `cx_disp`, `cx_val`, `cx_msg` and `cx_key`.
# See the header's representation paragraph, which lists the same four and the
# same five keys.
#
# ⚠⚠ THIS BLOCK SAID "the only THREE procs" AFTER THE HEADER HAD ALREADY BEEN
# CORRECTED TO FOUR, which is this batch's named failure mode reappearing inside
# the change that fixed it -- and it is the copy that would have been obeyed,
# because this is the block an implementer reads when changing the
# representation.  They would have rewritten three procs and left `cx_key`
# reading the old shape, which is exactly what the header's warning exists to
# prevent.  Both copies now ENUMERATE, so there is no number to drift: if a
# fifth adapter proc is ever added it has to be named in both places or the
# lists visibly disagree.
# ---------------------------------------------------------------------------

# One call.  Names what is MISSING rather than raising an `invalid command
# name` that says nothing about the row, and turns any raise from inside the
# product into a legible sentinel so the row fails instead of the file dying.
proc cx_call {args} {
    if {[info commands ::calc::cross] eq {}} { return NOPROC:calc::cross }
    if {[catch {uplevel 1 [list ::calc::cross {*}$args]} r]} { return "RAISED:$r" }
    return $r
}
# measured / absent / refused, or a sentinel naming why none of the three
# could be read.  Checked in this order because a sentinel string is not a
# dict and `dict exists` on one would be answering a different question.
proc cx_disp {a} {
    if {[string match NOPROC:* $a]} { return $a }
    if {[string match RAISED:* $a]} { return $a }
    if {[catch {dict size $a} n]} { return "NOTADICT:$a" }
    if {![dict exists $a ok]} { return "NOKEY-ok:$a" }
    if {[dict get $a ok] eq {1}} { return measured }
    if {![dict exists $a absent]} { return "NOKEY-absent:$a" }
    if {[dict get $a absent] eq {1}} { return absent }
    return refused
}
# the X, or the LIST of X for nth = 0.  Never raises: a non-measured answer
# yields its own disposition string, which a comparison against a number
# fails on legibly.
proc cx_val {a} {
    set d [cx_disp $a]
    if {$d ne {measured}} { return $d }
    if {![dict exists $a value]} { return "NOKEY-value:$a" }
    return [dict get $a value]
}
proc cx_msg {a} { return [cx_key $a msg] }
# one key of an answer, with the disposition substituted when the answer is
# not one of the three dispositions at all, so a missing key or a non-dict
# answer fails the row legibly instead of raising inside it.
proc cx_key {a k} {
    set d [cx_disp $a]
    if {$d ne {absent} && $d ne {refused} && $d ne {measured}} { return $d }
    if {![dict exists $a $k]} { return "NOKEY-$k" }
    return [dict get $a $k]
}

# ⚠⚠ `llength` AND `lindex` RAISE ON A STRING WHOSE FIRST CHARACTER AFTER A
# SPACE IS AN UNMATCHED OPEN BRACE, AND SIX BANDS HERE USED TO ABORT ON THAT.
# Measured on Tcl 8.6.17: `llength` of the two words `oops` and an open-brace
# word answers `unmatched open brace in list`, while the same open brace in the
# MIDDLE of a word (`SENT:` followed by it) is harmless and answers 1.  So the
# hazard is narrow and entirely real: a `cross` whose message, or whose raise
# text arriving through `cx_call`'s `RAISED:` sentinel, happened to carry one
# would take CX5, CX7, CX8, CX10, CX11 and CX14 out through `group`'s catch —
# each band's remaining rows would stop measuring and be replaced by one
# `ABORTED` line.  That is CONTAINED, because `group` scores each abort as a
# counted FAIL and the `OVERALL: ok` sentinel is not printed, so it is not
# issue 1615's shape; it is still every row below the raise in six bands that a
# wrong implementation could hide.
#
# ⚠ THE SIX BAND NAMES WERE RE-MEASURED, AND THE ROW COUNT IS DELIBERATELY ABSENT.
# Measured twice, by reverting these two procs to a bare `llength`/`lindex` in a
# scratch copy and driving a reference that (a) raises with an unmatched open
# brace as a word in its error text and (b) answers MEASURED with such a brace in
# its `value`.  Both shapes abort exactly CX5, CX7, CX8, CX10, CX11 and CX14, and
# with these two procs in place neither aborts anything.  But the two shapes lose
# DIFFERENT numbers of rows, because they enter through different helpers -- so
# there is no one row count to quote, which is why an earlier revision's "18
# remaining rows", repeated in two places, was already wrong when it shipped.  The
# band names hold; a count over this file's own text does not.
# These two never raise, and a row that gets one of their sentinels instead of
# a number fails legibly on the comparison.
#
# ⚠ THE CLAIM THESE TWO ARE HERE TO MAKE TRUE, STATED NARROWLY SO IT IS
# CHECKABLE: no `calc::cross` ANSWER is ever indexed or measured bare in this
# file.  `cx_islist` and `cx_increasing` are the two helpers that walk an
# answer's list, and an earlier revision left both of them reaching `llength $v`
# and `lindex $v $i` with a plain `catch` round only the `llength` -- safe solely
# because the `lindex` ran after the `llength` had already succeeded, which a
# reordering would silently undo.  Both now go through `cx_len` / `cx_at`.
# The claim is deliberately NOT extended to the `cx_col` / `cx_addcol` columns
# that CX10, CX11 and CX14 index directly: those are `%.16g` numbers written by
# `xschem raw values`, which `calc::cross` does not author, so the product cannot
# put a brace in them.
proc cx_len {v} { if {[catch {llength $v} n]} { return "NOTALIST:{$v}" } ; return $n }
proc cx_at {v i} { if {[catch {lindex $v $i} e]} { return "NOTALIST:{$v}" } ; return $e }

# ⚠⚠ EVERY ROW BELOW THAT COMPARES TWO ANSWERS, OR ASSERTS A BOOLEAN PROPERTY
# OF ONE, CARRIES `cx_disp` AS THE FIRST ELEMENT OF WHAT IT COMPARES.  That is
# not decoration, it is a measured correction to this file's own first draft:
# on the red run before `calc::cross` existed, a whole class of rows written as
# a bare identity or a bare predicate PASSED -- `cross(a) eq cross(b)` is true
# when both are the same sentinel, `string is double -strict` is false for a
# sentinel exactly as it is for an absence, and `llength` of a one-word
# sentinel is 1.  A row that passes on a tree with no feature in it is not a
# fence, so the disposition is part of every claim.
#
# ⚠ THE COUNT THAT USED TO BE IN THAT SENTENCE IS GONE ON PURPOSE.  It named a
# number of rows in a revision of this file that no longer exists, so no
# instrument here can reproduce it -- the same house rule that forbids a comment
# quoting a count over the tree's own text forbids one quoting a count over a
# tree that is gone.  THE SHAPE IS RE-MEASURABLE AND IS THE USEFUL CLAIM: with
# `::calc::cross` renamed away, every row that calls it fails, and the rows that
# still pass are the ones that never call it -- CX0 and CX1 entire, plus the
# derivation and inventory rows inside the behavioural bands.  Rename the proc
# away and read the band histogram if that ever needs checking again.


# ---------------------------------------------------------------------------
# agreement with a hand-derived value.  See the header for why CXTOL is
# looser than the fixture's own headroom.
# ---------------------------------------------------------------------------
set CXTOL 1e-7
# ⚠ GATED WITH THIS SUITE'S OWN `cx_finite`, NOT WITH `string is double
# -strict`, AND THAT IS A MEASURED CORRECTION RATHER THAN A STYLE CHOICE.
# `string is double -strict` answers 1 for all four non-finite spellings — the
# exact reason `calc::eval_finite` exists at all — so `near nan 0.001 1e-7` got
# past the guard and then RAISED out of the subtraction: measured, "can't use
# non-numeric floating-point value as operand of \"-\"".  A `cross` that
# answered a measured `nan` (the engine really does produce one: band CX10
# builds such a column) would therefore have ABORTED the enclosing band through
# `group`'s catch instead of failing one row.  `inf` did not raise — it answers
# a relative error of `Inf` and compares false — which is exactly the kind of
# half-working guard that survives review.
# `exp` is hand-derived everywhere in this file, but it is gated too and with
# its OWN sentinel, so a broken hand derivation is distinguishable from a
# broken answer rather than silently becoming one.
proc near {got exp tol} {
    if {![cx_finite $got]} { return "NOTANUMBER:{$got}" }
    if {![cx_finite $exp]} { return "BADEXPECTED:{$exp}" }
    if {$exp == 0.0} {
        if {abs($got) <= $tol} { return ok }
        return "off:{$got} abs=[expr {abs($got)}]"
    }
    set r [expr {abs(($got - $exp) / double($exp))}]
    if {$r <= $tol} { return ok }
    return "off:{$got} rel=$r"
}
# a whole answer against one hand value.  `ok` or a sentence saying what went
# wrong, which is what the row compares, so a missing proc prints
# NOPROC:calc::cross rather than a bare mismatch.
proc cx_is {a exp} { return [near [cx_val $a] $exp $::CXTOL] }
# ...and against a LIST of hand values, element by element, reporting the
# count first because a wrong count is a different defect from a wrong value.
#
# ⚠ `cx_len` / `cx_at`, NOT a bare `llength` / `lindex` WITH ONE `catch` ROUND
# THE FIRST OF THEM.  `$v` is a `calc::cross` answer, so the product authors the
# string; see the warning above `cx_len`.  `$exps` is hand-derived from `sq_rise`
# and friends and is always a proper list, so it keeps `llength`/`lindex` -- and
# that asymmetry is the point: the guard is for what the PRODUCT supplies.
proc cx_islist {a exps} {
    set v [cx_val $a]
    if {[cx_disp $a] ne {measured}} { return [cx_disp $a] }
    set n [cx_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n != [llength $exps]} { return "count=$n want=[llength $exps] got={$v}" }
    set bad {}
    for {set i 0} {$i < $n} {incr i} {
        set r [near [cx_at $v $i] [lindex $exps $i] $::CXTOL]
        if {$r ne {ok}} { lappend bad "\[$i\]$r" }
    }
    if {[llength $bad]} { return [join $bad { }] }
    return ok
}

# ---------------------------------------------------------------------------
# THE HAND DERIVATION.  Two lines of arithmetic off the deck, per the header.
# ---------------------------------------------------------------------------
proc sq_rise {L k} { return [expr {(0.9 + 0.2*double($L) + 4.0*$k) * 1e-3}] }
proc sq_fall {L k} { return [expr {(2.3 - 0.2*double($L) + 4.0*$k) * 1e-3}] }
# `1 v(sq) -` crosses L exactly where `v(sq)` crosses 1-L, with the direction
# flipped.  Stated as that identity rather than as a second trapezoid, because
# the identity is checkable by eye and a second table is not.
proc inv_fall {L k} { return [sq_rise [expr {1.0 - double($L)}] $k] }
proc inv_rise {L k} { return [sq_fall [expr {1.0 - double($L)}] $k] }

# ---------------------------------------------------------------------------
# THE RAMP, which band CX6 needs and which is NOT a trapezoid.  `v(ramp)` is
# PWL(0 0 10m 10), i.e. 1 V/ms, so it crosses level L exactly once in the sweep,
# at t = L/1000 s -- one line of arithmetic, like sq_rise and sq_fall.
#
# ⚠ AND THE REASON THE PROCS BELOW EXIST -- `ramp_x`, `ramp_pair`, `ramp_frac`
# and `ramp_snaps`, enumerated because an earlier revision of this sentence
# called them "THE THREE PROCS BELOW" and there are four: on a 0.1 ms grid
# sample k carries EXACTLY 0.1*k V, so a level that is a multiple of 0.1 V lands
# ON a sample and is useless to R414d.  CX6's earlier revision used levels 3 and
# 3.5, which are exactly that, under a row name claiming the opposite.  These
# procs let CX6 MEASURE where in its straddling pair a crossing falls, and what
# this file's own `near` says about each snapping convention there, so the choice
# of level is re-derived every run instead of asserted in a name.
# ---------------------------------------------------------------------------
proc ramp_x {L} { return [expr {double($L)/1000.0}] }
# `ok <x> <xleft> <xright>` for the level-L crossing, derived with this file's
# OWN D3 + D4 over the real columns.  Needs the tran read loaded.
proc ramp_pair {L} {
    set xs [cx_col time 0] ; set ys [cx_col {v(ramp)} 0]
    set n [cx_len $ys]
    if {![string is integer -strict $n]} { return [list BADCOL $n {} {}] }
    set x [lindex [cx_derive_x $xs $ys $L rising] 0]
    if {![cx_finite $x]} { return [list NOCROSSING $x {} {}] }
    set p 0
    for {set i 1} {$i < $n} {incr i} {
        if {[lindex $xs $i] >= $x} { set p $i ; break }
    }
    if {$p < 1} { return [list NOPAIR $x {} {}] }
    return [list ok $x [lindex $xs [expr {$p-1}]] [lindex $xs $p]]
}
# how far through that pair the crossing falls: 0.0 is the left sample, 1.0 the
# right.  A multiple of 0.1 V answers 1.000, which is the whole point.
proc ramp_frac {L} {
    lassign [ramp_pair $L] st x xl xr
    if {$st ne {ok}} { return $st }
    return [expr {($x - $xl)/($xr - $xl)}]
}
# `accepted` or `rejected`, per snapping convention, in the order snap-DOWN,
# snap-UP, snap-to-NEAREST -- asked of this file's own `near` at CXTOL, so the
# answer is about the instrument the behavioural rows actually use and not about
# an argument.  R414d requires all three to be `rejected`.
proc ramp_snaps {L} {
    lassign [ramp_pair $L] st x xl xr
    if {$st ne {ok}} { return $st }
    set nearest [expr {($x - $xl) < ($xr - $x) ? $xl : $xr}]
    set out {}
    foreach cand [list $xl $xr $nearest] {
        lappend out [expr {[near $cand $x $::CXTOL] eq {ok} ? {accepted} : {rejected}}]
    }
    return $out
}

# ---------------------------------------------------------------------------
# the fixture, and the suite's own D3 + D4
# ---------------------------------------------------------------------------
set fixture {}
foreach cand {tests/headless/data/calc_fixture.raw} {
    if {[file exists $cand]} { set fixture [file normalize $cand] }
}
if {$fixture eq {} && [info exists ::XSCHEM_SHAREDIR]} {
    set cand [file join [file dirname $::XSCHEM_SHAREDIR] tests headless data calc_fixture.raw]
    if {[file exists $cand]} { set fixture [file normalize $cand] }
}
# ALWAYS WITH AN EXPLICIT TYPE.  Measured 2026-10-01 and recorded in
# test_calc_engine.tcl: a second bare `xschem raw read <f>` after the file has
# also been read as `op` lands back on the OP slot, where `raw value <v> 30 0`
# answers EMPTY and a row reads that as a wrong number rather than as a wrong
# database.
proc cx_load {{ty tran}} {
    if {$::fixture eq {}} { return NOFIXTURE }
    catch {xschem raw clear}
    if {[catch {xschem raw read $::fixture $ty} r]} { return "ERR:$r" }
    return $r
}
proc rawnames {} {
    set l {}
    if {[catch {xschem raw list} l]} { return {} }
    return [split [string trim $l] "\n"]
}
proc leaked {} {
    set out {}
    foreach n [rawnames] { if {[string match -nocase __calc_tmp* $n]} { lappend out $n } }
    return $out
}
# one column, as a Tcl list, or a sentinel.  `xschem raw values` prints
# "%.16g" and a non-finite sample arrives as the literal token `inf`, `-inf`,
# `nan` or `-nan` with `llength` still correct (measured).
proc cx_col {name dset} {
    if {[catch {xschem raw values $name $dset} v]} { return "ERR:$v" }
    return [string trim $v]
}
# build one derived column through the engine, read it back, and delete it.
# The name is NOT `__calc_tmp<N>`: that prefix belongs to R402 and `leaked`
# watches it, so a probe borrowing it would make every cleanup row lie.
proc cx_addcol {name expr dset} {
    catch {xschem raw del $name}
    if {[catch {xschem raw add $name $expr} rc]} { return "ERR:$rc" }
    set v [cx_col $name $dset]
    catch {xschem raw del $name}
    return $v
}
# ⚠ THIS SUITE'S OWN finiteness test, deliberately NOT a call to
# `calc::eval_finite`: the derivation in CX1 and CX10 must not stop working
# because the product proc it is used to check was renamed or moved, and a
# suite that called it would be measuring that proc against itself.
#
# ⚠ BUT IT IS NOT *INDEPENDENT* EVIDENCE, AND AN EARLIER REVISION OF THIS
# COMMENT CLAIMED IT WAS.  The regexp below is a BYTE-IDENTICAL COPY of
# `calc::eval_finite`'s, so a regexp that is wrong is wrong identically in both
# places and CX0's agreement row would still be green.  What this buys is a
# CHANGE DETECTOR — if either copy is edited, CX0 reddens and names the
# spelling they disagree on — and decoupling from the product's call graph.  It
# does not buy a second opinion, and no row below may be read as if it did.
# Textual, for the reason that proc's own header gives: `%g` spells a
# non-finite differently on different C libraries, and `string is double
# -strict` accepts all four spellings as numbers.
proc cx_finite {v} {
    return [regexp {^-?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} [string trim $v]]
}
# CROSS_CONTRACT D3 + D4, in the order D6 requires: the finiteness gate FIRST,
# then the predicate, then the division — which cannot have a zero denominator
# once the predicate holds, because the predicate puts the endpoints strictly
# on opposite sides of L.  Returns a list of `<dir> <x>` pairs in sweep order.
proc cx_derive {xs ys L edge} {
    set out {}
    set n [llength $ys]
    for {set p 1} {$p < $n} {incr p} {
        set y0 [lindex $ys [expr {$p-1}]] ; set y1 [lindex $ys $p]
        if {![cx_finite $y0] || ![cx_finite $y1]} continue
        set r [expr {$y0 <  $L && $y1 >= $L}]
        set f [expr {$y0 >  $L && $y1 <= $L}]
        if {!$r && !$f} continue
        set dir [expr {$r ? {rising} : {falling}}]
        if {$edge ne {either} && $edge ne $dir} continue
        set x0 [lindex $xs [expr {$p-1}]] ; set x1 [lindex $xs $p]
        lappend out $dir [expr {$x0 + ($L - $y0)*($x1 - $x0)/($y1 - $y0)}]
    }
    return $out
}
# the X values only, which is what a row compares against `cross`.
proc cx_derive_x {xs ys L edge} {
    set out {}
    foreach {d x} [cx_derive $xs $ys $L $edge] { lappend out $x }
    return $out
}
# ⚠ THE ORDER D6 FORBIDS, kept as a proc so CX10's behavioural rows are not
# vacuous.  D3's predicate FIRST and the finiteness filter after it — which is
# the reading CROSS_CONTRACT's own first draft had, and measurement showed it
# is not strong enough: `-inf < L` is perfectly true, so an infinity sails
# through as a crossing.  Each hit is reported as `<dir> <x>` where <x> may be
# the literal string RAISED, because the interpolation throws when both
# endpoints are infinite.
proc cx_derive_naive {xs ys L edge} {
    set out {}
    set n [llength $ys]
    for {set p 1} {$p < $n} {incr p} {
        set y0 [lindex $ys [expr {$p-1}]] ; set y1 [lindex $ys $p]
        if {[catch {expr {$y0 <  $L && $y1 >= $L}} r]} { set r 0 }
        if {[catch {expr {$y0 >  $L && $y1 <= $L}} f]} { set f 0 }
        if {!$r && !$f} continue
        set dir [expr {$r ? {rising} : {falling}}]
        if {$edge ne {either} && $edge ne $dir} continue
        set x0 [lindex $xs [expr {$p-1}]] ; set x1 [lindex $xs $p]
        if {[catch {expr {$x0 + ($L - $y0)*($x1 - $x0)/($y1 - $y0)}} x]} { set x RAISED }
        lappend out $dir $x
    }
    return $out
}
# is this list strictly increasing?  `cross`'s nth = 0 answer must be in sweep
# order, and "increasing" is a property a row can state without knowing the
# numbers.
#
# ⚠ THE FINITENESS GATE IS `cx_finite` AND IT RUNS OVER EVERY ELEMENT BEFORE
# ANY COMPARISON, which is three corrections to one proc and all three were
# measured.  (1) The old guard was `string is double -strict`, which admits
# `nan`, and NaN comparisons are QUIET in Tcl 8.6.17 — so this proc answered
# `ok` for a list of 1, a NaN and 3, meaning a `cross` whose scan produced a
# NaN would have been reported as correctly ordered.  It rejected `inf`
# already, by luck rather than by design: `inf <= 1` is false but `3 <= inf` is
# true, so the step AFTER the infinity is what caught it.  (2) The old loop
# started at element 1, so element 0 was never tested at all and a list
# beginning with a NaN was unexamined.  (3) `llength` on a string carrying an
# unmatched open brace RAISES, so it is taken through `cx_len` -- and so is every
# `lindex` below, which the revision making correction (3) left bare.  It was
# safe only because the `lindex` ran after `cx_len` had answered an integer, i.e.
# by statement order rather than by construction, and a reordering would have
# reopened it with nothing saying so.
proc cx_increasing {l} {
    set n [cx_len $l]
    if {![string is integer -strict $n]} { return $n }
    for {set i 0} {$i < $n} {incr i} {
        if {![cx_finite [cx_at $l $i]]} { return "NOTANUMBER at $i:[cx_at $l $i]" }
    }
    for {set i 1} {$i < $n} {incr i} {
        if {[cx_at $l $i] <= [cx_at $l [expr {$i-1}]]} { return "notincreasing at $i" }
    }
    return ok
}

if {[catch {

# =========================================================================
group CX0 {
    # Infrastructure.  Nothing here calls `calc::cross`; all of it passes on
    # a tree with no `cross` at all, which is what lets a reader tell "the
    # suite works and the feature is absent" from "the suite is broken".
    check "CX0 fixture: tests/headless/data/calc_fixture.raw was located" \
        [expr {$::fixture ne {} ? 1 : 0}] 1
    check "CX0 fixture reads as the tran database §11.2 describes -- two datasets of 101 points, ten vectors -- when the type is given EXPLICITLY" \
        [list [pcall cx_load tran] [pcall xschem raw sim_type] [pcall xschem raw datasets] \
              [pcall xschem raw points 0] [pcall xschem raw points 1] [llength [rawnames]]] \
        {1 tran 2 101 101 10}
    # D12's last paragraph: the sweep column is resolved BY NAME, because the
    # fixture's `Operating Point` plot has NO sweep column and its index 0 is
    # `v(sq)` -- so an implementation that assumes index 0 is X reads a node
    # voltage as an X axis there.
    check "CX0 D12 the sweep column is reachable BY NAME on the tran read, and is index 0 there" \
        [list [pcall xschem raw index time] [pcall xschem raw sim_type]] {0 tran}
    check "CX0 D12 ...and on the OP read index 0 is v(sq), NOT a sweep column -- which is why `cross` must resolve the sweep by name and not by index" \
        [list [pcall cx_load op] [pcall xschem raw sim_type] [lindex [rawnames] 0] \
              [pcall xschem raw index time]] {1 op v(sq) -1}
    pcall cx_load tran
    # D10: the per-point reader is what makes R414c's bidirectional early exit
    # real, and it must answer rather than raise at the ends of the sweep, or
    # a backward scan cannot start.
    check "CX0 D10 `xschem raw value <name> <p> <dset>` answers a sample inside the sweep" \
        [pcall xschem raw value {v(sq)} 50 0] 0.5
    check "CX0 D10 ...and answers the EMPTY STRING for a point below and above the sweep rather than raising, which is what lets a bidirectional scan test its own bounds" \
        [list [pcall xschem raw value {v(sq)} -1 0] [pcall xschem raw value {v(sq)} 101 0]] {{} {}}
    # D11's pre-flight is assembled out of procs that already exist; a row
    # names each, so a rename shows up here and not as twenty mysterious reds.
    foreach p {rpn_bad_token tmpvec eval_finite eval_refusal} {
        check "CX0 D11 the pre-flight part calc::$p exists, so `cross` can copy calc::eval_rpn's pre-flight rather than invent one" \
            [llength [pcall info procs ::calc::$p]] 1
    }
    check "CX0 D11 ...and `xschem raw loaded` is the ONE accessor that answers with no raw loaded, which is why the gate is built on it" \
        [list [pcall xschem raw clear] [pcall xschem raw loaded] \
              [string match ERR:* [pcall xschem raw datasets]] \
              [string match ERR:* [pcall xschem raw index {v(sq)}]] \
              [string match ERR:* [pcall xschem raw values {v(sq)} 0]]] \
        {1 -1 1 1 1}
    pcall cx_load tran
    check "CX0 this suite's own cx_finite agrees with calc::eval_finite on every spelling dtoa and the MSVC runtime can emit -- a CHANGE DETECTOR over two byte-identical regexps, NOT independent evidence, because a wrong pattern would be wrong identically in both copies and this row would still be green" \
        [join [lmap v [list 0.5 -0 1e-35 .5 -3.5e-9 inf -inf nan -nan NaN INF 1.#INF -1.#IND 1.#QNAN {} abc] \
                   {list $v [cx_finite $v] [pcall calc::eval_finite $v]}] { }] \
        [join [lmap v [list 0.5 -0 1e-35 .5 -3.5e-9 inf -inf nan -nan NaN INF 1.#INF -1.#IND 1.#QNAN {} abc] \
                   {list $v [cx_finite $v] [cx_finite $v]}] { }]
    check "CX0 the loaded inventory carries no __calc_tmp* at band entry, so every R402 row below starts from zero" [leaked] {}
}

# =========================================================================
group CX1 {
    # Infrastructure, and the load-bearing band: this suite's OWN D3 + D4,
    # run over `xschem raw values`, against the deck's arithmetic.  No
    # product proc is called.  PASSES TODAY.
    pcall cx_load tran
    set t0 [cx_col time 0]
    set q0 [cx_col {v(sq)} 0]
    check "CX1 the two columns the derivation runs over came back with 101 samples each" \
        [list [cx_len $t0] [cx_len $q0]] {101 101}
    # ---- v(sq) at 0.5, which is the fixture README's own hand derivation ----
    check "CX1 D3+D4 derive v(sq)'s RISING 50% crossings at the deck's 1.0 / 5.0 / 9.0 ms" \
        [cx_islist [dict create ok 1 value [cx_derive_x $t0 $q0 0.5 rising]] \
             [list [sq_rise 0.5 0] [sq_rise 0.5 1] [sq_rise 0.5 2]]] ok
    check "CX1 D3+D4 derive v(sq)'s FALLING 50% crossings at the deck's 2.2 / 6.2 ms" \
        [cx_islist [dict create ok 1 value [cx_derive_x $t0 $q0 0.5 falling]] \
             [list [sq_fall 0.5 0] [sq_fall 0.5 1]]] ok
    check "CX1 D3+D4 `either` is the disjunction in sweep order, five crossings, and a pair satisfies at most one of the two predicates" \
        [cx_islist [dict create ok 1 value [cx_derive_x $t0 $q0 0.5 either]] \
             [list [sq_rise 0.5 0] [sq_fall 0.5 0] [sq_rise 0.5 1] [sq_fall 0.5 1] [sq_rise 0.5 2]]] ok
    # ---- the off-sample levels CX6 needs ----
    foreach L {0.25 0.3 0.75} {
        check "CX1 D3+D4 derive v(sq)'s rising crossings at the OFF-SAMPLE level $L, where the deck puts them at 0.9+0.2*$L ms and its 4 ms repeats" \
            [cx_islist [dict create ok 1 value [cx_derive_x $t0 $q0 $L rising]] \
                 [list [sq_rise $L 0] [sq_rise $L 1] [sq_rise $L 2]]] ok
        check "CX1 D3+D4 ...and its falling crossings at $L, where the deck puts them at 2.3-0.2*$L ms" \
            [cx_islist [dict create ok 1 value [cx_derive_x $t0 $q0 $L falling]] \
                 [list [sq_fall $L 0] [sq_fall $L 1]]] ok
    }
    # ---- the inverted square, which is what CX4 measures direction on ----
    set inv0 [cx_addcol __cx_inv {1 v(sq) -} 0]
    check "CX1 the engine evaluates `1 v(sq) -` into a named column of 101 samples, so CX4 has an inverted square to count directions on" \
        [cx_len $inv0] 101
    check "CX1 D3+D4 derive the inverted square's RISING crossings at level 0.3 -- which the identity `1-v(sq) crosses L where v(sq) crosses 1-L, direction flipped` puts at 2.16 / 6.16 ms" \
        [cx_islist [dict create ok 1 value [cx_derive_x $t0 $inv0 0.3 rising]] \
             [list [inv_rise 0.3 0] [inv_rise 0.3 1]]] ok
    check "CX1 D3+D4 ...and its FALLING crossings at 0.3, at 1.04 / 5.04 / 9.04 ms" \
        [cx_islist [dict create ok 1 value [cx_derive_x $t0 $inv0 0.3 falling]] \
             [list [inv_fall 0.3 0] [inv_fall 0.3 1] [inv_fall 0.3 2]]] ok
    # ⚠ THE METHOD ROW.  This is why CX4 does not use v(sq): on v(sq) at 0.5
    # the LAST crossing overall is a rising one, so `rising -1` and
    # `either -1` are the same number and a direction filter that ignores
    # `edge` entirely passes.  On the inverted square at 0.3 they differ by
    # 2.88 ms, which no tolerance can bridge.
    check "CX1 METHOD: on v(sq) at 0.5 the last crossing overall IS rising, so a rising/either pair at nth=-1 cannot tell a broken direction filter from a working one -- which is why CX4 uses the inverted square instead" \
        [list [lindex [cx_derive $t0 $q0 0.5 either] end-1] \
              [expr {[lindex [cx_derive_x $t0 $q0 0.5 rising] end] == [lindex [cx_derive_x $t0 $q0 0.5 either] end]}]] \
        {rising 1}
    check "CX1 METHOD: ...whereas on the inverted square at 0.3 the last crossing overall is FALLING and the last rising one is 2.88 ms earlier, so there the pair discriminates" \
        [list [lindex [cx_derive $t0 $inv0 0.3 either] end-1] \
              [expr {abs([lindex [cx_derive_x $t0 $inv0 0.3 rising] end] - [lindex [cx_derive_x $t0 $inv0 0.3 either] end]) > 2.8e-3}]] \
        {falling 1}
    # ---- the dataset discriminator CX11 needs ----
    set t1 [cx_col time 1]
    set d0 [cx_col {v(div)} 0]
    set d1 [cx_col {v(div)} 1]
    check "CX1 D12 v(div) crosses 1.5 V at 3.0 ms in dataset 0 (rtop=1k, v(div)=v(ramp)/2, so v(ramp)=3 V) and at 6.0 ms in dataset 1 (rtop=3k, v(div)=v(ramp)/4, so v(ramp)=6 V) -- one crossing each, and they are 3 ms apart" \
        [list [cx_islist [dict create ok 1 value [cx_derive_x $t0 $d0 1.5 either]] {0.003}] \
              [cx_islist [dict create ok 1 value [cx_derive_x $t1 $d1 1.5 either]] {0.006}]] \
        {ok ok}
    pcall xschem raw clear
}

# =========================================================================
group CX2 {
    # R414, positive nth: an ordinal counting FORWARD from the start of the
    # sweep.  Hand values from the deck's trapezoid, not from CX1.
    pcall cx_load tran
    check "CX2 R414 rising nth=1 is the FIRST rising crossing, at the deck's 1.0 ms" \
        [cx_is [cx_call {v(sq)} 0.5 1 rising] [sq_rise 0.5 0]] ok
    check "CX2 R414 rising nth=2 is the second, at 5.0 ms" \
        [cx_is [cx_call {v(sq)} 0.5 2 rising] [sq_rise 0.5 1]] ok
    check "CX2 R414 rising nth=3 is the third, at 9.0 ms" \
        [cx_is [cx_call {v(sq)} 0.5 3 rising] [sq_rise 0.5 2]] ok
    check "CX2 R414 falling nth=1 and nth=2 are the deck's 2.2 and 6.2 ms" \
        [list [cx_is [cx_call {v(sq)} 0.5 1 falling] [sq_fall 0.5 0]] \
              [cx_is [cx_call {v(sq)} 0.5 2 falling] [sq_fall 0.5 1]]] {ok ok}
    check "CX2 R414 `either` interleaves the two directions in sweep order: nth=1..5 are 1.0 2.2 5.0 6.2 9.0 ms" \
        [list [cx_is [cx_call {v(sq)} 0.5 1 either] [sq_rise 0.5 0]] \
              [cx_is [cx_call {v(sq)} 0.5 2 either] [sq_fall 0.5 0]] \
              [cx_is [cx_call {v(sq)} 0.5 3 either] [sq_rise 0.5 1]] \
              [cx_is [cx_call {v(sq)} 0.5 4 either] [sq_fall 0.5 1]] \
              [cx_is [cx_call {v(sq)} 0.5 5 either] [sq_rise 0.5 2]]] {ok ok ok ok ok}
    # the forward count as a PROPERTY, so an implementation that returns the
    # right set in the wrong order fails here rather than passing three rows
    # by coincidence.
    check "CX2 R414 the forward count is strictly increasing in nth, which an implementation returning the right set in the wrong order fails" \
        [cx_increasing [list [cx_val [cx_call {v(sq)} 0.5 1 either]] \
                             [cx_val [cx_call {v(sq)} 0.5 2 either]] \
                             [cx_val [cx_call {v(sq)} 0.5 3 either]] \
                             [cx_val [cx_call {v(sq)} 0.5 4 either]] \
                             [cx_val [cx_call {v(sq)} 0.5 5 either]]]] ok
    set m1 [cx_call {v(sq)} 0.5 1 rising]
    check "CX2 a measured answer's value IS a number -- reported WITH its disposition, because a bare `string is double` leg passes on a tree where cross is absent" \
        [list [cx_disp $m1] [string is double -strict [cx_val $m1]]] {measured 1}
    check "CX2 the band left no __calc_tmp* behind" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX3 {
    # R414c / D1: a negative nth counts BACK FROM THE END.  CROSS_CONTRACT
    # calls this the single most likely thing to be implemented wrongly,
    # because the forward loop a positive nth wants cannot answer "which was
    # last" without reaching the end of the sweep.
    pcall cx_load tran
    check "CX3 R414c rising nth=-1 is the LAST rising crossing, at the deck's 9.0 ms" \
        [cx_is [cx_call {v(sq)} 0.5 -1 rising] [sq_rise 0.5 2]] ok
    check "CX3 R414c rising nth=-2 is the second-to-last, at 5.0 ms" \
        [cx_is [cx_call {v(sq)} 0.5 -2 rising] [sq_rise 0.5 1]] ok
    check "CX3 R414c rising nth=-3 is the third-from-last, which is also the first, at 1.0 ms" \
        [cx_is [cx_call {v(sq)} 0.5 -3 rising] [sq_rise 0.5 0]] ok
    # the same ordered set read from both ends, stated as an identity rather
    # than as two independent number tables -- an implementation that scans
    # backwards over a DIFFERENT set fails this and not the three above.
    # ⚠ `eq`, NOT a tolerance, AND THAT IS NOW A STRONGER CLAIM THAN IT LOOKS.
    # CROSS_CONTRACT D10 as it now stands reads the column in BULK for EVERY
    # `nth`, so the forward and the backward scan divide the same two
    # `"%.16g"` operands by D4's one formula and the two answers are
    # BIT-IDENTICAL.  Under the reversed D10 -- per-point `xschem raw value` at
    # `"%.8g"` for a non-zero `nth` -- they would not have been.  So a future
    # reader who reintroduces a second read path reddens here, and the row name
    # is where they find out why.
    check "CX3 R414c the two signs index ONE ordered set from opposite ends and the answers are BIT-IDENTICAL, not merely within tolerance, BECAUSE D10 gives both scans one bulk read path: nth=-1 equals nth=3, nth=-2 equals nth=2 and nth=-3 equals nth=1, as strings" \
        [list [cx_disp [cx_call {v(sq)} 0.5 -1 rising]] \
              [expr {[cx_val [cx_call {v(sq)} 0.5 -1 rising]] eq [cx_val [cx_call {v(sq)} 0.5 3 rising]]}] \
              [expr {[cx_val [cx_call {v(sq)} 0.5 -2 rising]] eq [cx_val [cx_call {v(sq)} 0.5 2 rising]]}] \
              [expr {[cx_val [cx_call {v(sq)} 0.5 -3 rising]] eq [cx_val [cx_call {v(sq)} 0.5 1 rising]]}]] \
        {measured 1 1 1}
    check "CX3 R414c falling nth=-1 and nth=-2 are the deck's 6.2 and 2.2 ms, so the backward scan is not rising-only" \
        [list [cx_is [cx_call {v(sq)} 0.5 -1 falling] [sq_fall 0.5 1]] \
              [cx_is [cx_call {v(sq)} 0.5 -2 falling] [sq_fall 0.5 0]]] {ok ok}
    check "CX3 R414c `either` nth=-1..-5 walk back through 9.0 6.2 5.0 2.2 1.0 ms" \
        [list [cx_is [cx_call {v(sq)} 0.5 -1 either] [sq_rise 0.5 2]] \
              [cx_is [cx_call {v(sq)} 0.5 -2 either] [sq_fall 0.5 1]] \
              [cx_is [cx_call {v(sq)} 0.5 -3 either] [sq_rise 0.5 1]] \
              [cx_is [cx_call {v(sq)} 0.5 -4 either] [sq_fall 0.5 0]] \
              [cx_is [cx_call {v(sq)} 0.5 -5 either] [sq_rise 0.5 0]]] {ok ok ok ok ok}
    check "CX3 the band left no __calc_tmp* behind" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX4 {
    # R414a: the count is WITHIN the selected direction, never overall.
    # MEASURED ON THE INVERTED SQUARE AT LEVEL 0.3, for the reason CX1's two
    # METHOD rows measure: on v(sq) at 0.5 the last crossing overall is
    # rising, so `rising -1` == `either -1` and an implementation that ignores
    # `edge` when nth is negative passes.  On `1 v(sq) -` at 0.3 the last
    # crossing overall is FALLING at 9.04 ms and the last RISING one is at
    # 6.16 ms -- 2.88 ms apart, five orders of magnitude outside CXTOL.
    pcall cx_load tran
    check "CX4 R414a rising nth=-1 on `1 v(sq) -` at 0.3 is the last RISING crossing at 6.16 ms, NOT the last crossing overall at 9.04 ms -- the row an edge-blind implementation fails" \
        [cx_is [cx_call {1 v(sq) -} 0.3 -1 rising] [inv_rise 0.3 1]] ok
    check "CX4 R414a ...and `either` nth=-1 on the same column IS the 9.04 ms falling one, so the pair proves the filter is applied and not that the trace has no late crossing" \
        [cx_is [cx_call {1 v(sq) -} 0.3 -1 either] [inv_fall 0.3 2]] ok
    check "CX4 R414a ...and `falling` nth=-1 is that same 9.04 ms, so the three edge words partition one set rather than naming three traces" \
        [cx_is [cx_call {1 v(sq) -} 0.3 -1 falling] [inv_fall 0.3 2]] ok
    set r_rise [cx_call {1 v(sq) -} 0.3 -1 rising]
    set r_eith [cx_call {1 v(sq) -} 0.3 -1 either]
    check "CX4 R414a the rising answer and the either answer DIFFER by more than 2.8 ms on this column, which is the whole reason the band is written on it" \
        [list [cx_disp $r_rise] [cx_disp $r_eith] \
              [expr {[string is double -strict [cx_val $r_rise]]
                     && [string is double -strict [cx_val $r_eith]]
                     && abs([cx_val $r_rise] - [cx_val $r_eith]) > 2.8e-3}]] \
        {measured measured 1}
    check "CX4 R414a rising nth=-2 on that column is 2.16 ms, so the backward scan counts within the direction for more than its first step" \
        [cx_is [cx_call {1 v(sq) -} 0.3 -2 rising] [inv_rise 0.3 0]] ok
    check "CX4 R414a forward and backward agree on the SAME two-element rising set: nth=1 is 2.16 ms and nth=2 is 6.16 ms" \
        [list [cx_is [cx_call {1 v(sq) -} 0.3 1 rising] [inv_rise 0.3 0]] \
              [cx_is [cx_call {1 v(sq) -} 0.3 2 rising] [inv_rise 0.3 1]]] {ok ok}
    check "CX4 R414a falling counts within ITS direction on the same column: nth=1 2 3 are 1.04 5.04 9.04 ms and nth=-1 -2 -3 are 9.04 5.04 1.04 ms" \
        [list [cx_is [cx_call {1 v(sq) -} 0.3 1 falling] [inv_fall 0.3 0]] \
              [cx_is [cx_call {1 v(sq) -} 0.3 2 falling] [inv_fall 0.3 1]] \
              [cx_is [cx_call {1 v(sq) -} 0.3 3 falling] [inv_fall 0.3 2]] \
              [cx_is [cx_call {1 v(sq) -} 0.3 -1 falling] [inv_fall 0.3 2]] \
              [cx_is [cx_call {1 v(sq) -} 0.3 -2 falling] [inv_fall 0.3 1]] \
              [cx_is [cx_call {1 v(sq) -} 0.3 -3 falling] [inv_fall 0.3 0]]] \
        {ok ok ok ok ok ok}
    # out of range WITHIN a direction: there are two rising crossings, so a
    # third does not exist even though a third crossing overall does.  An
    # implementation that counted overall and then filtered would answer the
    # 9.04 ms falling one here.
    check "CX4 R414a rising nth=3 and nth=-3 are ABSENT although a third crossing OVERALL exists -- which an implementation that counts overall and filters afterwards would answer with 9.04 ms" \
        [list [cx_disp [cx_call {1 v(sq) -} 0.3 3 rising]] \
              [cx_disp [cx_call {1 v(sq) -} 0.3 -3 rising]]] {absent absent}
    check "CX4 the band left no __calc_tmp* behind" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX5 {
    # D2 / D8: nth = 0 is "every crossing", and it is not a special case
    # bolted on -- once both signs are ordinals from opposite ends, zero is
    # the only integer left over.  The PROC returns the list, because
    # frequency, period_jitter and dutyCycle all need the full set and they
    # call the proc.
    pcall cx_load tran
    check "CX5 D2 nth=0 with `either` returns ALL FIVE crossings of v(sq) at 0.5, in sweep order, at the deck's 1.0 2.2 5.0 6.2 9.0 ms" \
        [cx_islist [cx_call {v(sq)} 0.5 0 either] \
             [list [sq_rise 0.5 0] [sq_fall 0.5 0] [sq_rise 0.5 1] [sq_fall 0.5 1] [sq_rise 0.5 2]]] ok
    check "CX5 D2 nth=0 with `rising` returns the three rising ones only" \
        [cx_islist [cx_call {v(sq)} 0.5 0 rising] \
             [list [sq_rise 0.5 0] [sq_rise 0.5 1] [sq_rise 0.5 2]]] ok
    check "CX5 D2 nth=0 with `falling` returns the two falling ones only" \
        [cx_islist [cx_call {v(sq)} 0.5 0 falling] \
             [list [sq_fall 0.5 0] [sq_fall 0.5 1]]] ok
    check "CX5 D8 the list is NOT silently truncated to its first element: nth=0 has five elements and nth=1 has one, so they cannot be the same answer" \
        [list [cx_disp [cx_call {v(sq)} 0.5 0 either]] \
              [cx_len [cx_val [cx_call {v(sq)} 0.5 0 either]]] \
              [expr {[cx_val [cx_call {v(sq)} 0.5 0 either]] eq [cx_val [cx_call {v(sq)} 0.5 1 either]]}]] \
        {measured 5 0}
    check "CX5 D2 the list is in sweep order, which is a property an implementation returning a set in scan order from the wrong end fails" \
        [list [cx_disp [cx_call {v(sq)} 0.5 0 either]] \
              [cx_increasing [cx_val [cx_call {v(sq)} 0.5 0 either]]]] {measured ok}
    # ⚠⚠ THIS ROW WAS UNSATISFIABLE UNTIL CROSS_CONTRACT D10 WAS REVERSED, AND
    # IT IS THE ROW THAT CAUSED THE REVERSAL.  `eq` is string identity, and the
    # ORIGINAL D10 had `nth = 0` read the column in bulk (`"%.16g"`) while a
    # non-zero `nth` read it per point through `xschem raw value`, which prints
    # through `dtoa()` (`"%.8g"`, src/util.c).  Measured across that seam:
    # `0.0009999999999999998` against `0.001`.  No conforming implementation
    # could have passed this row -- while one that quietly used bulk for
    # everything turned it green, so the row SELECTED FOR ABANDONING D10 IN
    # SILENCE.  D10 now mandates the bulk read for every `nth`, for the
    # independent reason that `%.8g` carries ~1e-8 relative error against a
    # column whose documented headroom is 1e-12.
    #
    # With ONE read path the two answers come out of the same division on the
    # same operands, so bit-identity is not merely satisfiable, it is a
    # STRONGER assertion than `near` at CXTOL -- VERIFIED against a conforming
    # scratch reference before this name was written, not reasoned about.  The
    # name says WHY, so that reintroducing a second read path reddens with an
    # explanation attached rather than as a mystery.
    check "CX5 D2 nth=0's first and last elements are BIT-IDENTICAL to nth=1 and nth=-1 -- not within tolerance, identical, BECAUSE D10 gives the list path and the ordinal path ONE bulk read path; a second read path at a different precision cannot satisfy this row" \
        [list [cx_disp [cx_call {v(sq)} 0.5 0 rising]] \
              [cx_len [cx_val [cx_call {v(sq)} 0.5 0 rising]]] \
              [expr {[cx_at [cx_val [cx_call {v(sq)} 0.5 0 rising]] 0] eq [cx_val [cx_call {v(sq)} 0.5 1 rising]]}] \
              [expr {[cx_at [cx_val [cx_call {v(sq)} 0.5 0 rising]] end] eq [cx_val [cx_call {v(sq)} 0.5 -1 rising]]}]] \
        {measured 3 1 1}
    # D8 draws the line between the proc and the UI: the PROC must answer, so
    # the derived verbs can be built on it.  Refusing nth=0 in the measurement
    # proc would make `frequency` unimplementable.
    check "CX5 D8 the measurement proc does NOT refuse nth=0 -- the keypad path refuses it (R404 wants a literal number in the buffer), and putting that refusal in the proc would make frequency and dutyCycle unimplementable" \
        [cx_disp [cx_call {v(sq)} 0.5 0 either]] measured
    check "CX5 the band left no __calc_tmp* behind" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX6 {
    # R414d: interpolated between the two straddling samples, NEVER snapped.
    # ⚠ NOT FENCEABLE AT LEVEL 0.5, where v(sq)'s crossings sit exactly on
    # samples -- there a snapping implementation and an interpolating one give
    # the same number and the row measures nothing.  Both legs below use
    # off-sample levels and say in their own names how far the answer is from
    # the samples it is between.  The grid step is 0.1 ms.
    pcall cx_load tran
    # ⚠⚠ THE COMPARANDS FOR EVERY `eq` LEG IN THIS BAND COME OUT OF `$t0`, THE
    # BULK COLUMN, AND NOT OUT OF `xschem raw value`.  That is the correction
    # that put two of this band's rows back into service, and it is worth the
    # paragraph because both of them READ GREEN while measuring nothing.
    # `xschem raw value` prints through `dtoa()` -- `"%.8g"`, src/util.c -- while
    # `xschem raw values` prints `"%.16g"`, and CROSS_CONTRACT D10 now mandates
    # that `cross` build its answer from the BULK column for every `nth`.  So an
    # answer interpolated from `%.16g` operands can never be string-equal to a
    # `%.8g` comparand unless the sample happens to round-trip, and `eq` is
    # string identity.  Measured: the "six inequalities" row below printed `ok:`
    # for snap-down, snap-up AND snap-to-nearest alike -- SIX dead legs under a
    # name asserting six discriminating ones -- while the "two inequalities" row
    # had one dead leg and one live one, surviving only because `0.001`
    # round-trips through `%.8g` and `0.0009000000000000002` does not.  The row
    # after this comment states that asymmetry as a fact, so the door cannot be
    # reintroduced quietly.
    #
    # ⚠⚠ A NAMED HOLE, MEASURED RATHER THAN REASONED: D10's BULK READ IS FENCED BY
    # NOTHING IN THIS FILE, AND THAT AGREES WITH CROSS_CONTRACT'S OWN SENTENCE
    # ("D10 is therefore not fenceable by any row").  A reference that reads EVERY
    # sample per point through `xschem raw value` -- `"%.8g"` operands throughout,
    # the reversed D10 applied consistently -- passes this whole suite, ALL PASS,
    # reddening not one row.  What CX5's bit-identity row catches is only the
    # MIXED two-route design, where the `nth = 0` path and the ordinal path read at
    # different precisions; a consistently wrong read path is invisible, because
    # every tolerance here is 1e-7 and `%.8g` costs about 1e-9.  THE ONE WAY TO
    # FENCE IT would be a row asserting the answer is bit-equal to this file's own
    # `cx_derive_x` over the bulk columns -- and that is NOT written, deliberately,
    # because it would also pin D4's exact floating-point expression ORDER and
    # would redden a conforming implementation that merely re-parenthesised the
    # same formula.  If that trade is ever worth making, this is the comment to
    # argue with.
    set t0 [cx_col time 0]
    check "CX6 R414d DERIVED: the two sample-reading doors DISAGREE on the very samples this band's inequality legs are written against -- `xschem raw values` prints %.16g and `xschem raw value` prints dtoa()'s %.8g -- so an `eq` leg whose comparand came from the PER-POINT door could never be satisfied by an answer D10 builds from the BULK column, which is what made two rows below pass a snapper; sample 10 is the exception that round-trips, which is why one of those rows was half-alive rather than fully dead" \
        [list [cx_len $t0] \
              [expr {[cx_at $t0 9]  eq [pcall xschem raw value time 9 0]}] \
              [expr {[cx_at $t0 30] eq [pcall xschem raw value time 30 0]}] \
              [expr {[cx_at $t0 31] eq [pcall xschem raw value time 31 0]}] \
              [expr {[cx_at $t0 10] eq [pcall xschem raw value time 10 0]}]] \
        {101 0 0 0 1}
    # L = 0.3 on the first rising edge: the straddling samples are x[9] =
    # 0.9 ms (v = 0) and x[10] = 1.0 ms (v = 0.5), and 0.9 + 0.2*0.3 = 0.96 ms
    # -- 0.04 ms from the NEARER sample and 0.06 ms from the farther, i.e.
    # 40 % of a grid step from the nearest sample in the trace.
    check "CX6 R414d at level 0.3 the first rising crossing is 0.96 ms, which is 0.04 ms from the NEAREST sample (1.0 ms) and 0.06 ms from the other (0.9 ms) -- 40 percent of the 0.1 ms grid step, so no snapping convention produces it" \
        [cx_is [cx_call {v(sq)} 0.3 1 rising] [sq_rise 0.3 0]] ok
    check "CX6 R414d ...and the answer is not bit-equal to EITHER straddling sample's X, stated as the two inequalities against the BULK column rather than as a tolerance -- both legs live, where the earlier revision's `xschem raw value` comparands left the x\[9\] leg dead and the x\[10\] leg alive only because 0.001 round-trips through %.8g" \
        [list [cx_disp [cx_call {v(sq)} 0.3 1 rising]] \
              [expr {[cx_val [cx_call {v(sq)} 0.3 1 rising]] eq [cx_at $t0 9]}] \
              [expr {[cx_val [cx_call {v(sq)} 0.3 1 rising]] eq [cx_at $t0 10]}]] \
        {measured 0 0}
    # L = 0.25 is the harder case: 0.9 + 0.2*0.25 = 0.95 ms is EQUIDISTANT
    # from both straddling samples, half a grid step from each, so neither
    # "snap down" nor "snap up" nor "snap to nearest" can produce it.
    check "CX6 R414d at level 0.25 the first rising crossing is 0.95 ms, EQUIDISTANT from both straddling samples at 0.05 ms -- half the grid step each way, so snap-down, snap-up and snap-to-nearest are all excluded by one number" \
        [cx_is [cx_call {v(sq)} 0.25 1 rising] [sq_rise 0.25 0]] ok
    check "CX6 R414d the interpolation tracks the level CONTINUOUSLY: 0.25 0.3 0.5 0.75 give 0.95 0.96 1.0 1.05 ms on the same edge, a 0.1 ms spread over a level range the grid cannot resolve" \
        [list [cx_is [cx_call {v(sq)} 0.25 1 rising] [sq_rise 0.25 0]] \
              [cx_is [cx_call {v(sq)} 0.3  1 rising] [sq_rise 0.3  0]] \
              [cx_is [cx_call {v(sq)} 0.5  1 rising] [sq_rise 0.5  0]] \
              [cx_is [cx_call {v(sq)} 0.75 1 rising] [sq_rise 0.75 0]]] {ok ok ok ok}
    check "CX6 R414d the falling edge interpolates the OTHER way, as the deck's 2.3-0.2L requires: 0.25 0.3 0.5 0.75 give 2.25 2.24 2.2 2.15 ms, which an implementation that interpolated rising-only would get backwards" \
        [list [cx_is [cx_call {v(sq)} 0.25 1 falling] [sq_fall 0.25 0]] \
              [cx_is [cx_call {v(sq)} 0.3  1 falling] [sq_fall 0.3  0]] \
              [cx_is [cx_call {v(sq)} 0.5  1 falling] [sq_fall 0.5  0]] \
              [cx_is [cx_call {v(sq)} 0.75 1 falling] [sq_fall 0.75 0]]] {ok ok ok ok}
    # ⚠⚠ THE RAMP LEG USED TO BE WRITTEN AT LEVELS 3 AND 3.5 UNDER THE NAME
    # "half a grid step off every sample", AND THAT NAME STATED A FALSE NUMBER
    # WHICH MADE THE ROW VACUOUS.  `v(ramp)` is PWL(0 0 10m 10) = 1 V/ms on a
    # 0.1 ms grid, so sample k carries 0.1*k V EXACTLY and any level that is a
    # multiple of 0.1 V lands ON a sample: level 3 interpolates to the pair
    # (29,30) and comes out 6.9e-18 from time[30], i.e. 0.0000 % of the grid
    # step away, not 50 %.  Run through this file's own `near` at CXTOL, a
    # snap-to-nearest AND a snap-up implementation both scored `ok` on it.  So
    # the one row in CX6 named after the ramp measured nothing at all, which is
    # CLAUDE.md's "do not write down a number nothing re-checks" failing in the
    # worst available place — inside a ROW NAME, which lands in the T1 verdict.
    #
    # ⚠ R414d WAS NOT LEFT UNFENCED BY THAT, which is why this is a repair and
    # not a restoration: the 0.3 and 0.25 legs above are on `v(sq)`'s ramped
    # edges and do redden a snapper.  What was lost is the ramp's own
    # contribution — a column with no edges at all, where a direction filter
    # cannot be what makes the row pass.
    #
    # ⚠ THE FRACTION IS NOW RE-DERIVED BY THE ROW instead of asserted in its
    # name.  `ramp_x` is the deck arithmetic (t = L/1000 s); `ramp_frac` finds
    # the straddling pair in the sweep column and reports where in it the
    # crossing falls, and `ramp_snaps` reports what this file's own `near` says
    # about each of the three snapping conventions.  The levels are chosen so
    # the three conventions are separated in three different ways: 3.05 is
    # EQUIDISTANT, 3.02 puts snap-to-nearest on the LEFT sample and 3.08 puts it
    # on the RIGHT, so a snapper cannot be right by picking a side.
    check "CX6 R414d DERIVED: the ramp's own grid, measured rather than asserted -- level 3.02 3.05 3.08 fall at 0.200 0.500 0.800 of the way through their straddling pair, and at each of them `near` at CXTOL REJECTS snap-down, snap-up and snap-to-nearest alike" \
        [list [format %.3f [ramp_frac 3.02]] [format %.3f [ramp_frac 3.05]] [format %.3f [ramp_frac 3.08]] \
              [ramp_snaps 3.02] [ramp_snaps 3.05] [ramp_snaps 3.08]] \
        {0.200 0.500 0.800 {rejected rejected rejected} {rejected rejected rejected} {rejected rejected rejected}}
    check "CX6 R414d DERIVED: ...and level 3 and level 3.5 are exactly the levels this leg must NOT use -- 1 V/ms on a 0.1 ms grid puts a multiple of 0.1 V ON a sample, so they fall at 1.000 of the way through their pair and `near` ACCEPTS two of the three snapping conventions, which is why the earlier revision's ramp row passed a snapper" \
        [list [format %.3f [ramp_frac 3]] [format %.3f [ramp_frac 3.5]] \
              [ramp_snaps 3] [ramp_snaps 3.5]] \
        {1.000 1.000 {rejected accepted accepted} {rejected accepted accepted}}
    check "CX6 R414d the ramp is the check with NO EDGES at all, so no direction filter can carry it: at 3.02 3.05 3.08 V `cross` answers the deck's 3.02 3.05 3.08 ms, each strictly between its two samples at the fraction the row above measured" \
        [list [cx_is [cx_call {v(ramp)} 3.02 1 rising] [ramp_x 3.02]] \
              [cx_is [cx_call {v(ramp)} 3.05 1 rising] [ramp_x 3.05]] \
              [cx_is [cx_call {v(ramp)} 3.08 1 rising] [ramp_x 3.08]]] {ok ok ok}
    check "CX6 R414d ...and none of those three is bit-equal to either straddling sample's X, stated as the six inequalities against the BULK column rather than as a tolerance -- ALL SIX were dead under the earlier revision's `xschem raw value` comparands, which printed ok: for snap-down, snap-up and snap-to-nearest alike" \
        [list [cx_disp [cx_call {v(ramp)} 3.05 1 rising]] \
              [expr {[cx_val [cx_call {v(ramp)} 3.02 1 rising]] eq [cx_at $t0 30]}] \
              [expr {[cx_val [cx_call {v(ramp)} 3.02 1 rising]] eq [cx_at $t0 31]}] \
              [expr {[cx_val [cx_call {v(ramp)} 3.05 1 rising]] eq [cx_at $t0 30]}] \
              [expr {[cx_val [cx_call {v(ramp)} 3.05 1 rising]] eq [cx_at $t0 31]}] \
              [expr {[cx_val [cx_call {v(ramp)} 3.08 1 rising]] eq [cx_at $t0 30]}] \
              [expr {[cx_val [cx_call {v(ramp)} 3.08 1 rising]] eq [cx_at $t0 31]}]] \
        {measured 0 0 0 0 0 0}
    check "CX6 the band left no __calc_tmp* behind" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX7 {
    # D3's strict-below / inclusive-above asymmetry exists so that each
    # transition counts exactly once, and D3's own claim is that an exact
    # sample hit needs NO special case because D4's formula already yields
    # exactly x[p] there.  Sample 50 of v(sq) is bit-exactly 0.5 -- the one
    # sample of the five 50 % samples that is -- so this is checkable on real
    # data rather than argued.
    pcall cx_load tran
    # ⚠ THE X COMPARAND IS THE BULK COLUMN, for the reason CX6's own comment
    # measures: `xschem raw value` prints dtoa()'s `"%.8g"` and the operands D10
    # makes `cross` divide come from `"%.16g"`.  `time[50]` happens to be one of
    # the samples that round-trips, so this leg was live either way -- but it was
    # live BY LUCK, exactly as CX6's x[10] leg was, and a row asserting "bit for
    # bit" must not depend on a printf width agreeing with itself.
    set t0 [cx_col time 0]
    check "CX7 D3 sample 50 of v(sq) is bit-exactly 0.5 and sample 49 is 0, which is what makes the exact-hit case reachable through the fixture at all" \
        [list [pcall xschem raw value {v(sq)} 49 0] [pcall xschem raw value {v(sq)} 50 0] \
              [expr {[pcall xschem raw value {v(sq)} 50 0] == 0.5}]] {0 0.5 1}
    check "CX7 D3 the exact hit is counted as a RISING crossing of the pair (49,50) -- the inclusive-above half of the predicate -- and lands at the deck's 5.0 ms" \
        [cx_is [cx_call {v(sq)} 0.5 2 rising] [sq_rise 0.5 1]] ok
    check "CX7 D4 ...and the value is EXACTLY the sample's own X, bit for bit against the BULK column D10 reads, with no special case: a formula that is right here is right everywhere, which is why D3 could keep the asymmetry" \
        [list [cx_disp [cx_call {v(sq)} 0.5 2 rising]] \
              [expr {[string is double -strict [cx_val [cx_call {v(sq)} 0.5 2 rising]]]
                     && [cx_val [cx_call {v(sq)} 0.5 2 rising]] eq [cx_at $t0 50]}]] \
        {measured 1}
    check "CX7 D3 the exact hit is NOT ALSO counted as a falling crossing, so the pair satisfies at most one predicate and the 5.0 ms edge is not double-counted" \
        [list [cx_disp [cx_call {v(sq)} 0.5 0 rising]] \
              [cx_len [cx_val [cx_call {v(sq)} 0.5 0 rising]]] \
              [cx_len [cx_val [cx_call {v(sq)} 0.5 0 falling]]] \
              [cx_len [cx_val [cx_call {v(sq)} 0.5 0 either]]]] {measured 3 2 5}
    check "CX7 the band left no __calc_tmp* behind" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX8 {
    # R414b / D5: fewer than |nth| crossings is NO VALUE, on both ends and
    # symmetrically, reported the same way by the same path.  Not an error,
    # not zero, not an empty string a caller might arithmetic on by accident.
    # v(sq) at 0.5 has exactly THREE rising crossings, so +5 and -5 are both
    # two past the end, from opposite directions.
    pcall cx_load tran
    set p5 [cx_call {v(sq)} 0.5 5 rising]
    set m5 [cx_call {v(sq)} 0.5 -5 rising]
    # ⚠ THE `msg` LEGS ARE NOT DECORATION: THIS FILE'S REPRESENTATION PARAGRAPH
    # SAYS AN ABSENCE CARRIES "a sentence under `msg`" AND NOTHING MEASURED IT.
    # Verified by mutation: a reference whose absent builder set `msg {}`
    # reddened NOTHING in the whole suite -- 178 checks, ALL PASS -- so the
    # declared representation was half unfenced while every refusal's sentence
    # was fenced three ways over in CX9 and CX11.  The shape asserted is the same
    # one CX9 asserts of a refusal (capital, colon, non-empty) and for the same
    # reason: CROSS_CONTRACT's refusal-pattern section has `cross` build both
    # dispositions' sentences out of ONE `calc::cross_msg`, so a shape that holds
    # for one and not the other means two spellings.  The WORDING is deliberately
    # not pinned -- it is unratified and carries a `rule` debt, exactly as CX9
    # says of Evaluate's.
    check "CX8 R414b nth=+5 over three rising crossings is ABSENT, not an error and not a number, and it carries the SENTENCE under `msg` that this file's representation paragraph says an absence carries -- non-empty, capital, colon, in the one house shape CX9 asserts of a refusal, because both come from one calc::cross_msg" \
        [list [cx_disp $p5] [expr {[cx_msg $p5] ne {} ? 1 : 0}] \
              [regexp {^[A-Z]} [cx_msg $p5]] \
              [expr {[string first : [cx_msg $p5]] >= 0 ? 1 : 0}]] \
        {absent 1 1 1}
    check "CX8 R414b nth=-5 over the same three is ABSENT too, which is the symmetry R414b asks for in so many words" \
        [cx_disp $m5] absent
    # ⚠⚠ THE DISPOSITION AND THE VALUE, NOT THE WHOLE DICT.  This row used to be
    # `[expr {$p5 eq $m5}]`, a byte comparison of the two ANSWERS, and that is a
    # claim nobody declared: D5 says the two ends "give the same answer by the
    # same path", which is about the disposition and the value, not about the
    # prose.  Two ways it was wrong, and the second was measured on a conforming
    # reference rather than argued:
    #   -- An absence sentence naming the ordinal that was asked for ("there is
    #      no 5th rising crossing" against "...no 5th from the end...") is
    #      exactly the house style CX9 and CX11 REQUIRE of a refusal, so the
    #      helpful message reddened this row and the implementer would have met
    #      it as a mystery red pointing at D5.
    #   -- The answer also carries the `dest` name `calc::tmpvec` minted for the
    #      call, and that proc never re-uses a name BY DESIGN -- measured
    #      `__calc_tmp5` against `__calc_tmp6` on two successive calls -- so a
    #      whole-dict identity row could not have passed ANY conforming
    #      implementation, with or without a message.
    # The message is therefore left FREE TO BE HELPFUL and the row asserts the
    # two things D5 actually requires.
    check "CX8 R414b ...and the two ends agree in DISPOSITION and in VALUE, which is what `by the same path` means and what a separate out-of-range branch per sign would break -- while the SENTENCE may legitimately differ, because naming the ordinal asked for is the house style, and so may the minted temporary name, which calc::tmpvec never re-uses" \
        [list [cx_disp $p5] [cx_disp $m5] \
              [expr {[cx_val $p5] eq [cx_val $m5] ? 1 : 0}] \
              [expr {[cx_key $p5 absent] eq [cx_key $m5 absent] ? 1 : 0}]] \
        {absent absent 1 1}
    check "CX8 R414b the first value past the end is already absent on both sides: there are three, so +4 and -4 are absent and +3 and -3 are measured" \
        [list [cx_disp [cx_call {v(sq)} 0.5 4 rising]] [cx_disp [cx_call {v(sq)} 0.5 -4 rising]] \
              [cx_disp [cx_call {v(sq)} 0.5 3 rising]] [cx_disp [cx_call {v(sq)} 0.5 -3 rising]]] \
        {absent absent measured measured}
    # ⚠ D5's own requirement, and the reason it is a requirement: 0 IS a
    # legitimate X value, so an absence reported as 0 would be a wrong
    # measurement rather than a missing one, and `settlingTime` could not
    # propagate it.  Stated as the positive property -- the answer is not
    # consumable as a number at all -- rather than as a list of wrong values
    # it must not equal.
    check "CX8 D5 the absent answer is not consumable as a number by `string is double -strict`, which is the ONE property that rules out 0, the empty string, inf and nan together" \
        [list [cx_disp $p5] [string is double -strict $p5] [string is double -strict [cx_val $p5]]] {absent 0 0}
    check "CX8 D5 ...and it is not the empty string either, which D5 names because a bare empty value turns into an error at some distant call site instead of here" \
        [list [cx_disp $p5] [expr {$p5 eq {} ? 1 : 0}] [expr {$p5 eq {0} ? 1 : 0}]] {absent 0 0}
    check "CX8 D5 CONTROL: a MEASURED answer at the same call site IS consumable as a number, so the predicate above separates the two dispositions rather than rejecting everything" \
        [list [cx_disp [cx_call {v(sq)} 0.5 3 rising]] \
              [string is double -strict [cx_val [cx_call {v(sq)} 0.5 3 rising]]]] {measured 1}
    check "CX8 R414b a level NO sample reaches is absent for every nth, including nth=0 whose answer is the empty crossing LIST rather than an absence" \
        [list [cx_disp [cx_call {v(sq)} 7.5 1 either]] [cx_disp [cx_call {v(sq)} 7.5 -1 either]] \
              [cx_disp [cx_call {v(sq)} 7.5 0 either]] \
              [cx_len [cx_val [cx_call {v(sq)} 7.5 0 either]]]] {absent absent measured 0}
    check "CX8 the band left no __calc_tmp* behind, INCLUDING on the absent path -- R402 is not driven by whether a measurement was found" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX9 {
    # D7: a request that cannot be INTERPRETED is refused; a well-formed
    # request whose answer does not exist reports that it does not exist
    # (D5/CX8).  Keeping those two dispositions distinct is what lets
    # settlingTime tell "you asked me something meaningless" from "this signal
    # never settles", so the band ends on the rows that prove they are.
    pcall cx_load tran
    # ⚠ THE RULE IS INTEGER-VALUED, NOT INTEGER-SPELLED, and `1e3` used to be in
    # this list under the name "a non-integer nth".  It is 1000: a perfectly
    # well-formed request for the thousandth rising crossing, which simply does
    # not exist -- so D5 makes it ABSENT and D7 does not reach it.  An
    # implementation written to `string is integer -strict` refuses it, and the
    # row that had it here would have called that right.  The two rows after this
    # loop move it, and `3.0`, to where they belong.
    foreach n {1.5 -2.5 abc {} 0.0001 2.5e-1 {2 3}} {
        check "CX9 D7 an nth that is not INTEGER-VALUED is REFUSED rather than rounded or reported absent -- nth=<$n>" \
            [cx_disp [cx_call {v(sq)} 0.5 $n rising]] refused
    }
    check "CX9 D7 nth is INTEGER-VALUED and not integer-spelled: 1e3 and -1e3 ARE 1000 and -1000, well-formed requests that happen to lie past both ends of a three-crossing set, so they are ABSENT -- an implementation testing the spelling with `string is integer -strict` refuses them instead" \
        [list [cx_disp [cx_call {v(sq)} 0.5 1e3 rising]] \
              [cx_disp [cx_call {v(sq)} 0.5 -1e3 rising]]] {absent absent}
    check "CX9 D7 ...and 3.0 IS the ordinal 3, so it is MEASURED at the deck's 9.0 ms, which is the leg that makes the row above about integer VALUE rather than about exponent notation" \
        [list [cx_disp [cx_call {v(sq)} 0.5 3.0 rising]] \
              [cx_is [cx_call {v(sq)} 0.5 3.0 rising] [sq_rise 0.5 2]]] {measured ok}
    foreach l {nan -nan inf -inf abc {} {0.5 0.6}} {
        check "CX9 D7 a non-finite or non-numeric level is REFUSED before any evaluation happens -- level=<$l>" \
            [cx_disp [cx_call {v(sq)} $l 1 rising]] refused
    }
    foreach e {up down rise fall cross {} either2 0} {
        check "CX9 D7 an edge word outside rising/falling/either is REFUSED -- edge=<$e>" \
            [cx_disp [cx_call {v(sq)} 0.5 1 $e]] refused
    }
    # the house style, by SHAPE and not by vocabulary: the wording of
    # Evaluate's sentences is unratified and carries a `rule` debt, so a row
    # that pinned the words would pin an unratified user-visible string.  What
    # the contract DOES state is the shape -- leading verb, colon, offending
    # value -- so that is what is asserted.
    set r1 [cx_call {v(sq)} 0.5 1.5 rising]
    check "CX9 D7 the refusal carries a non-empty sentence in the house shape calc::eval_msg and calc::plot_msg use: it starts with a capital, contains a colon, and NAMES the offending value -- asserted as shape, because the wording is unratified" \
        [list [cx_disp $r1] [expr {[cx_msg $r1] ne {} ? 1 : 0}] \
              [regexp {^[A-Z]} [cx_msg $r1]] \
              [expr {[string first : [cx_msg $r1]] >= 0 ? 1 : 0}] \
              [string match *1.5* [cx_msg $r1]]] {refused 1 1 1 1}
    check "CX9 D7 ...and a bad level and a bad edge word are refused with a capital and the OFFENDING VALUE NAMED too -- which is three kinds naming their own value, not yet a claim about the builder; the loop below is where `one builder` is measured" \
        [list [cx_disp [cx_call {v(sq)} inf 1 rising]] \
              [regexp {^[A-Z]} [cx_msg [cx_call {v(sq)} inf 1 rising]]] \
              [string match *inf* [cx_msg [cx_call {v(sq)} inf 1 rising]]] \
              [cx_disp [cx_call {v(sq)} 0.5 1 sideways]] \
              [regexp {^[A-Z]} [cx_msg [cx_call {v(sq)} 0.5 1 sideways]]] \
              [string match *sideways* [cx_msg [cx_call {v(sq)} 0.5 1 sideways]]]] \
        {refused 1 1 refused 1 1}
    # ⚠⚠ THIS LOOP IS A REPAIR, AND THE NAME IT REPLACES IS WHY IT EXISTS.  The
    # row above used to end "so the refusals share one builder rather than three
    # spellings" -- an inference over ALL refusal kinds drawn from three of them.
    # Measured: a reference that lowercased the sentences of the kinds those three
    # rows do not reach (`empty`, `nodata`, `badtoken`, `stale`, `noname`,
    # `engine`) reddened NOTHING in this suite -- 178 checks, ALL PASS -- so the
    # inference was not merely broad, it was the only thing holding those kinds at
    # all.  Every kind reachable with the tran read loaded now gets the shape
    # asserted in its own row, named after the kind, so a failure says which
    # spelling drifted.
    #
    # ⚠ WHAT IS STILL NOT COVERED HERE, STATED RATHER THAN IMPLIED: `nodata`,
    # `stale` and `noname` need a different database state or a shadowed
    # `calc::tmpvec`, so CX12 asserts the same shape on those at its own sites;
    # and the `engine` kind -- a raise out of `xschem raw add` or `raw values` --
    # has no reachable trigger anywhere in this suite, so it is fenced by NOTHING
    # and a reader must not read this loop as covering it.
    set cx_shape_cases [list \
        nth       [list {v(sq)} 0.5 1.5 rising] \
        level     [list {v(sq)} inf 1 rising] \
        edge      [list {v(sq)} 0.5 1 sideways] \
        badtoken  [list {v(nosuch)} 0.5 1 rising] \
        empty     [list {} 0.5 1 rising] \
        stackmax  [list [string repeat {1 } 300] 0.5 1 rising] \
        dataset   [list {v(sq)} 0.5 1 rising 7] \
        allpoints [list {v(sq)} 0.5 1 rising -1]]
    foreach {cx_kind cx_args} $cx_shape_cases {
        set cx_a [cx_call {*}$cx_args]
        check "CX9 D7 the refusal for the <$cx_kind> kind is in the house shape calc::cross_msg builds -- refused, non-empty sentence, leading capital, a colon -- which is what turns `the refusals share one builder` from an inference over three kinds into a measurement over every kind this band can reach" \
            [list [cx_disp $cx_a] [expr {[cx_msg $cx_a] ne {} ? 1 : 0}] \
                  [regexp {^[A-Z]} [cx_msg $cx_a]] \
                  [expr {[string first : [cx_msg $cx_a]] >= 0 ? 1 : 0}]] \
            {refused 1 1 1}
    }
    # ⚠ THE TWO DISPOSITIONS STAY DISTINCT.  This is the pair of rows the
    # seven derived verbs depend on, and the reason D7 spells the difference
    # out instead of leaving it to the implementer.
    set abs5 [cx_call {v(sq)} 0.5 5 rising]
    set ref5 [cx_call {v(sq)} 0.5 5.5 rising]
    check "CX9 D7 an out-of-range nth and a malformed nth are DIFFERENT dispositions -- `absent` and `refused` -- which is what lets settlingTime tell a meaningless question from a signal that never settles" \
        [list [cx_disp $abs5] [cx_disp $ref5]] {absent refused}
    check "CX9 D7 ...and the two whole answers are not equal, so the distinction survives a caller that compares answers rather than reading a key" \
        [list [cx_disp $abs5] [cx_disp $ref5] [expr {$abs5 eq $ref5 ? 1 : 0}]] {absent refused 0}
    check "CX9 D7 ...and NEITHER is consumable as a number, so a caller that forgets to check cannot turn either into a wrong measurement" \
        [list [cx_disp $abs5] [cx_disp $ref5] \
              [string is double -strict $abs5] [string is double -strict $ref5] \
              [string is double -strict [cx_val $abs5]] [string is double -strict [cx_val $ref5]]] \
        {absent refused 0 0 0 0}
    check "CX9 D7 a refusal is not a raise: every malformed request above answered, and none reached the file-scope catch" \
        [list [cx_disp $ref5] [cx_disp $r1] \
              [string match RAISED:* [cx_disp $ref5]] [string match RAISED:* [cx_disp $r1]]] \
        {refused refused 0 0}
    check "CX9 the band left no __calc_tmp* behind, on every refusing path -- R402 covers the paths that never reached the engine too" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX10 {
    # D6: both endpoints of a candidate pair must be FINITE, and that is
    # checked BEFORE D3's predicate is evaluated at all.  The first draft of
    # D6 said "skipped as a bracket endpoint" and measurement showed that
    # reading is not strong enough: `-inf < L` is perfectly true, so an
    # infinity does not FAIL D3 -- it sails through as a crossing.
    pcall cx_load tran
    set t0 [cx_col time 0]
    # `v(sq) 1e300 * 1e300 *` is 0 where v(sq) is 0 and +inf everywhere it is
    # not, so it steps 0 -> inf and inf -> 0 five times in the sweep: one
    # column carrying BOTH of D6's failure modes.
    set infc [cx_addcol __cx_inf {v(sq) 1e300 * 1e300 *} 0]
    check "CX10 D6 the engine really does produce infinities: `v(sq) 1e300 * 1e300 *` comes back as 101 samples of which some are the literal token inf and some are finite zeros, with llength still correct" \
        [list [cx_len $infc] [lindex $infc 0] [lindex $infc 10] \
              [cx_finite [lindex $infc 0]] [cx_finite [lindex $infc 10]]] {101 0 inf 1 0}
    # ⚠ THE DERIVATION THAT MAKES THE NEXT ROW NON-VACUOUS.  With the gate
    # after D3 instead of before it, this column answers FIVE phantom
    # crossings -- three of them silent wrong numbers equal to x[p-1], and two
    # of them a raise out of the interpolation.  A row asserting "absent" here
    # is therefore asserting something a plausible wrong implementation gets
    # wrong in two different ways.
    set naive [cx_derive_naive $t0 $infc 0.5 either]
    check "CX10 D6 DERIVED: with the gate AFTER D3 this column yields five phantom crossings, of which three are silent numbers and two RAISE out of the interpolation -- which is what the next rows are fencing against" \
        [list [expr {[llength $naive] / 2}] \
              [llength [lsearch -all -exact $naive RAISED]]] {5 2}
    check "CX10 D6 ...and with the gate BEFORE D3, as D6 requires, the same column yields NONE" \
        [llength [cx_derive $t0 $infc 0.5 either]] 0
    # ⚠ THIS ROW'S NAME USED TO SAY "a throw here would reach the file-scope
    # catch and abort the whole suite", AND THAT IS FALSE.  Measured by
    # reproducing this file's own three catch layers: a throw out of
    # `::calc::cross` is caught by `cx_call` and becomes a `RAISED:` sentinel,
    # so it fails THIS ROW and the band keeps going; a throw out of the suite's
    # OWN code is caught by `group` and aborts THIS BAND's remaining rows, with
    # the next band still running.  Neither reaches the file-scope catch, and
    # the `UNEXPECTED ERROR:` arm is for an error raised BETWEEN the bands.  So
    # the reason this is a row and not a comment is the half that IS true and
    # that the two derivation rows above measure: a gate-after-D3
    # implementation answers a PLAUSIBLE TIME INSIDE THE SWEEP on three of the
    # five phantoms, which no reader would question.
    check "CX10 D6 `cross` answers ABSENT on that column and does not RAISE -- a throw out of the product is caught by cx_call and fails this row rather than the file, so what this row is really fencing is the SILENT wrong number the derivation above measured" \
        [list [cx_disp [cx_call {v(sq) 1e300 * 1e300 *} 0.5 1 either]] \
              [cx_disp [cx_call {v(sq) 1e300 * 1e300 *} 0.5 -1 either]] \
              [cx_disp [cx_call {v(sq) 1e300 * 1e300 *} 0.5 1 rising]] \
              [cx_disp [cx_call {v(sq) 1e300 * 1e300 *} 0.5 1 falling]]] \
        {absent absent absent absent}
    check "CX10 D6 ...and nth=0 on it returns the EMPTY crossing list rather than five phantoms or a raise" \
        [list [cx_disp [cx_call {v(sq) 1e300 * 1e300 *} 0.5 0 either]] \
              [cx_len [cx_val [cx_call {v(sq) 1e300 * 1e300 *} 0.5 0 either]]]] {measured 0}
    # ⚠ THE SILENT-WRONG-NUMBER HALF, NAMED.  Three of the five phantoms
    # interpolate to exactly x[p-1] -- 0.9, 4.9 and 8.8 ms -- because the
    # denominator is infinite and the quotient is zero.  So a gate-after-D3
    # implementation does not throw on those: it answers a plausible time
    # inside the sweep.  The row states the correct shape (absent) and the
    # derivation above states what the wrong shape looks like.
    # ⚠ THE COMPARANDS ARE `$t0`, THE BULK COLUMN, NOT `xschem raw value`.  The
    # phantoms are interpolated from `$t0`, so against the per-point door these
    # two legs were comparing a `"%.16g"` number to a `"%.8g"` one and passing
    # only because 1e-12 happens to be wider than those two samples' disagreement
    # -- which is not a property of %.8g, whose relative error reaches ~5e-9.
    # Against the bulk column the agreement is exact and the tolerance is no
    # longer load-bearing.  Same door, same repair, as CX6 and CX7.
    check "CX10 D6 the three non-raising phantoms interpolate to exactly the LEFT sample's X of the BULK column, so a gate-after-D3 implementation answers a plausible time inside the sweep rather than failing visibly" \
        [list [near [lindex $naive 1] [cx_at $t0 9] 1e-12] \
              [near [lindex $naive 5] [cx_at $t0 49] 1e-12]] {ok ok}
    # nan, which fails D3's predicate quietly and raises the arithmetic.
    set nanc [cx_addcol __cx_nan {v(ramp) -1 * sqrt()} 0]
    check "CX10 D6 the engine produces NaN too: `v(ramp) -1 * sqrt()` is a finite -0 at the first sample and -nan at every other, so the pair at p=1 is one finite endpoint and one not" \
        [list [cx_len $nanc] [lindex $nanc 0] [lindex $nanc 1] \
              [cx_finite [lindex $nanc 0]] [cx_finite [lindex $nanc 1]]] {101 -0 -nan 1 0}
    check "CX10 D6 `cross` answers ABSENT on the NaN column and does not raise, although comparison operators on NaN return 0 quietly and the arithmetic does NOT" \
        [list [cx_disp [cx_call {v(ramp) -1 * sqrt()} 0.5 1 either]] \
              [cx_disp [cx_call {v(ramp) -1 * sqrt()} 0.5 -1 either]] \
              [cx_disp [cx_call {v(ramp) -1 * sqrt()} 0.5 0 either]]] {absent absent measured}
    # the -inf side, so the gate is not tested on +inf alone.
    check "CX10 D6 a column that steps from a finite 1 to -inf is absent too, so the gate is not a positive-infinity special case" \
        [cx_disp [cx_call {1 v(ramp) 1e300 * 1e300 * -} 0.5 1 either]] absent
    # ⚠ CONTROL.  Without this row the four above are satisfied by a `cross`
    # that found nothing anywhere.
    check "CX10 D6 CONTROL: the finiteness gate did not simply disable the scan -- the same calls on a FINITE column still find the deck's five crossings" \
        [list [cx_disp [cx_call {v(sq)} 0.5 1 either]] \
              [cx_len [cx_val [cx_call {v(sq)} 0.5 0 either]]]] {measured 5}
    check "CX10 D6 CONTROL: ...and a column that is finite everywhere EXCEPT outside the level's neighbourhood still reports the crossings that are properly bracketed -- `v(sq) 0.5 min()` is finite throughout and has three" \
        [list [cx_disp [cx_call {v(sq) 0.5 min()} 0.5 0 either]] \
              [cx_len [cx_val [cx_call {v(sq) 0.5 min()} 0.5 0 either]]]] {measured 3}
    check "CX10 the band left no __calc_tmp* behind, on the non-finite paths as well" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX11 {
    # D12: ONE dataset, stated explicitly, defaulting to 0, never -1.  The
    # four accessors disagree about their own default -- pos_at 0, raw value
    # allpoints, raw values 0, raw points allpoints -- so `cross` states its
    # dataset rather than inheriting one.  v(div) is the discriminator: it is
    # v(ramp)/2 in dataset 0 and v(ramp)/4 in dataset 1, so its 1.5 V crossing
    # moves from 3.0 ms to 6.0 ms between them.
    pcall cx_load tran
    check "CX11 D12 with NO dataset argument `cross` reads dataset 0: v(div) crosses 1.5 V at 3.0 ms there, not at the 6.0 ms it crosses in dataset 1" \
        [cx_is [cx_call {v(div)} 1.5 1 rising] 0.003] ok
    check "CX11 D12 ...and an explicit dataset 1 reads dataset 1, at 6.0 ms -- so the default is a default and not the only thing it can do" \
        [cx_is [cx_call {v(div)} 1.5 1 rising 1] 0.006] ok
    check "CX11 D12 dataset -1 (allpoints) is REFUSED rather than read, because the X column is non-increasing at the seam and reading across it manufactures crossings" \
        [cx_disp [cx_call {v(div)} 1.5 1 rising -1]] refused
    # issue 1632 is an out-of-bounds read behind an out-of-range dataset, so
    # the validation has to happen BEFORE the dataset is passed to an
    # accessor.  The refusal naming BOTH the dataset asked for and the number
    # the database has is the evidence that `xschem raw datasets` was consulted
    # first -- which is the correct shape, rather than the absence of a crash.
    # ⚠ 2 IS NOT IN THIS LOOP ANY MORE, AND THAT IS THE WHOLE POINT OF THE
    # SPLIT.  The fixture has TWO datasets, so at d = 2 the dataset asked for
    # and the number the result has are THE SAME NUMBER, and the two
    # `string match` legs below -- "names the one asked for" and "names the
    # count" -- collapse into one leg wearing two names.  A message saying only
    # "dataset 2 is out of range" would have satisfied both.  7 and 99 keep the
    # two-number claim honest; 2 gets its own row asserting only what it can.
    foreach d {7 99} {
        check "CX11 D12 an out-of-range dataset $d is REFUSED, and the sentence names BOTH numbers -- the dataset asked for ($d) and the count the loaded result has (2), which are DIFFERENT numbers at this $d -- which is the evidence that `xschem raw datasets` was consulted BEFORE the dataset reached an accessor (issue 1632 is an out-of-bounds read behind it)" \
            [list [cx_disp [cx_call {v(div)} 1.5 1 rising $d]] \
                  [string match *$d* [cx_msg [cx_call {v(div)} 1.5 1 rising $d]]] \
                  [string match *2* [cx_msg [cx_call {v(div)} 1.5 1 rising $d]]]] \
            {refused 1 1}
    }
    check "CX11 D12 the FIRST out-of-range dataset, 2 -- the fixture has datasets 0 and 1 -- is refused at the boundary, asserted WITHOUT the two-number leg, because at d=2 the dataset asked for and the count the result has are the same number and one string match cannot tell which of the two the sentence named" \
        [list [cx_disp [cx_call {v(div)} 1.5 1 rising 2]] \
              [string match *2* [cx_msg [cx_call {v(div)} 1.5 1 rising 2]]]] {refused 1}
    check "CX11 D12 a non-integer dataset is refused too, so the validation is not a bare range test on something that was never a number" \
        [list [cx_disp [cx_call {v(div)} 1.5 1 rising abc]] \
              [cx_disp [cx_call {v(div)} 1.5 1 rising 0.5]]] {refused refused}
    # ⚠ THE SEAM PHANTOM, which is the row that catches a future
    # "simplification" to allpoints.  Over dataset -1 the X column has exactly
    # one non-increasing step, at the seam, and it manufactures a FALLING
    # crossing at 4.999999999999997 ms -- a time inside dataset 0's range that
    # coincides to 2.6e-18 with a real RISING crossing.  No caller could
    # reject that by inspection and no tolerance-based row could tell the two
    # apart, so the fence is stated as the CORRECT SHAPE: dataset 0 has exactly
    # two falling crossings, so a third does not exist.
    set tall [cx_col time -1]
    set qall [cx_col {v(sq)} -1]
    set ph [cx_derive $tall $qall 0.5 falling]
    check "CX11 D12 DERIVED: reading v(sq) across allpoints finds FIVE falling crossings where dataset 0 has two, and the extra one at the seam sits at 4.999999999999997 ms -- inside dataset 0's range and 2.6e-18 from a real RISING crossing, so no caller rejects it by inspection" \
        [list [expr {[llength $ph] / 2}] \
              [near [lindex $ph 5] 0.005 1e-12] \
              [expr {abs([lindex $ph 5] - [lindex [cx_derive_x $tall $qall 0.5 rising] 1]) < 1e-17}]] \
        {5 ok 1}
    check "CX11 D12 ...so falling nth=3 on the default dataset is ABSENT: dataset 0 has exactly two falling crossings, and the allpoints read that would answer this one is forbidden" \
        [cx_disp [cx_call {v(sq)} 0.5 3 falling]] absent
    check "CX11 D12 ...and falling nth=0 on the default dataset is exactly the deck's two, at 2.2 and 6.2 ms -- asserting the right set rather than the absence of the wrong one" \
        [cx_islist [cx_call {v(sq)} 0.5 0 falling] [list [sq_fall 0.5 0] [sq_fall 0.5 1]]] ok
    check "CX11 D12 ...and either nth=0 is the deck's five, not the eleven an allpoints read finds" \
        [list [cx_disp [cx_call {v(sq)} 0.5 0 either]] \
              [cx_len [cx_val [cx_call {v(sq)} 0.5 0 either]]] \
              [expr {[llength [cx_derive_x $tall $qall 0.5 either]]}]] {measured 5 11}
    check "CX11 D12 the answer reports which dataset it read, so a caller layering riseTime on cross can propagate it rather than guess" \
        [list [cx_key [cx_call {v(div)} 1.5 1 rising] dataset] \
              [cx_key [cx_call {v(div)} 1.5 1 rising 1] dataset]] {0 1}
    check "CX11 the band left no __calc_tmp* behind" [leaked] {}

    # ⚠⚠ D12's LAST PARAGRAPH -- "read the sweep column BY NAME, not as index
    # 0" -- AND UNTIL THESE ROWS IT WAS FENCED BY NOTHING.  CX0 measures the
    # two infrastructure facts (the OP plot has no `time` column; its index 0 is
    # `v(sq)`), but no row measured what `cross` DOES there, and ON THE TRAN
    # READ `time` IS INDEX 0 -- so a mutation resolving the sweep as
    # `[lindex [xschem raw list] 0]` scored EXACTLY the same as a conforming
    # implementation on every other row in this file.  Verified both ways
    # against a conforming scratch reference and against that mutation.
    #
    # THE DISCRIMINATOR IS THE DISPOSITION, and the two differ:
    #   by NAME   -- derive `time`/`frequency` from `xschem raw sim_type` and
    #                resolve it with `xschem raw index`.  An `op` plot maps to
    #                neither, so the request is REFUSED.
    #   by INDEX 0 -- takes `v(sq)` as the X axis, finds its ONE point cannot
    #                form a straddling pair, and reports ABSENT.
    # Measured: refused with "...(sim_type op)." against absent with "there is
    # no 1st either crossing...".  Two dispositions, so no tolerance and no
    # wording is doing the work.
    check "CX11 D12 on the OP read -- one point, no sweep column, index 0 is v(sq) -- `cross` REFUSES, where an implementation resolving the sweep as index 0 of `xschem raw list` instead reads v(sq) as the X axis, finds no straddling pair in one point, and answers ABSENT" \
        [list [pcall cx_load op] [pcall xschem raw sim_type] [pcall xschem raw points 0] \
              [pcall xschem raw index time] [lindex [rawnames] 0] \
              [cx_disp [cx_call {v(ramp)} 0.5 1 either]]] \
        {1 op 1 -1 v(sq) refused}
    # ⚠⚠ A LIMIT THE IMPLEMENTATION STAGE MUST BE TOLD, AND THIS ROW IS WHERE IT
    # LIVES BECAUSE THIS ROW IS THE ONLY THING STANDING NEAR IT.  `calc::eval_rpn`
    # gates its database on `np < 1` ("no points at all"), and a `cross` copying
    # that pre-flight inherits the same threshold.  NOTHING IN THIS SUITE SAYS THE
    # THRESHOLD MUST BE 1.  Measured: a reference writing the gate as `np < 2`
    # instead reddens EXACTLY this row and nothing else -- the OP read has one
    # point, so it is refused either way and the DISPOSITION is unchanged; only
    # the sentence differs, because the points gate answers "no simulation data"
    # where the sweep-name resolution answers "sim_type op".  The row catches it
    # only through the `*op*` leg, i.e. by accident of which sentence arrives.
    # WHY IT IS NOT FENCED PROPERLY: separating the two gates needs a database with
    # exactly ONE sweep point AND a resolvable sweep column, and the fixture has
    # no such plot -- its op plot has no `time` column at all.  A `cross` that
    # refused every 1-point TRAN read would therefore pass this entire suite.  If
    # a 1-point tran fixture is ever added, that is the row to write.
    check "CX11 D12 ...and the refusal names the sim_type it could not derive a sweep name for, in the same house shape CX9 asserts -- capital, colon, the offending value -- which is the evidence `xschem raw sim_type` was consulted rather than an index assumed" \
        [list [cx_disp [cx_call {v(ramp)} 0.5 1 either]] \
              [regexp {^[A-Z]} [cx_msg [cx_call {v(ramp)} 0.5 1 either]]] \
              [expr {[string first : [cx_msg [cx_call {v(ramp)} 0.5 1 either]]] >= 0 ? 1 : 0}] \
              [string match *op* [cx_msg [cx_call {v(ramp)} 0.5 1 either]]]] {refused 1 1 1}
    check "CX11 D12 CONTROL: the SAME call on the tran read, where `time` is resolvable by name AND happens to be index 0, is MEASURED -- so the refusal above is about the missing sweep column and not about the expression, the level or the edge word" \
        [list [pcall cx_load tran] [cx_disp [cx_call {v(ramp)} 0.5 1 either]]] {1 measured}
    check "CX11 D12 the OP-read refusal left no __calc_tmp* behind either -- a path that refuses before it mints a destination still has to leave the inventory as it found it" [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX12 {
    # D11: the pre-flight, because `xschem raw add`'s return value does not
    # mean what it looks like.  Four rules, each a measured defect if skipped,
    # and `cross` copies calc::eval_rpn's pre-flight rather than inventing one.
    # ---- rule 1: gate on `xschem raw loaded` ----
    pcall xschem raw clear
    # ⚠⚠ THE NAME BELOW USED TO END "so the gate CANNOT be built on any of the
    # other four", AND THAT IS FALSE -- MEASURED, NOT ARGUED.  A reference with the
    # `xschem raw loaded` gate DELETED still refuses here, because the next check
    # down is `catch {set nds [xschem raw datasets]}` with `nds` defaulting to 0,
    # so the dataset validation fires with a non-empty sentence and the suite goes
    # ALL PASS.  What this row and the one after it actually discriminate is
    # REFUSES-versus-RAISES, which `no_loaded_gate_raises` does redden.  The claim
    # about `raw loaded` being the one accessor that answers is CX0's -- it is a
    # fact about the four accessors, measured there, and not something any row in
    # THIS band can observe.
    check "CX12 D11 with NO raw loaded `cross` REFUSES rather than raising -- which is what this row measures; that `xschem raw loaded` is the ONE accessor that answers with nothing loaded is CX0's row, because an implementation gating on a caught `xschem raw datasets` instead refuses here too and no row in this band could tell" \
        [cx_disp [cx_call {v(sq)} 0.5 1 either]] refused
    check "CX12 D11 ...and the caller gets a sentence and not a stack trace -- the <nodata> refusal kind, in the same house shape CX9's loop asserts of every kind it can reach, which that loop cannot reach because it needs an empty database" \
        [list [cx_disp [cx_call {v(sq)} 0.5 1 either]] \
              [string match RAISED:* [cx_disp [cx_call {v(sq)} 0.5 1 either]]] \
              [expr {[cx_msg [cx_call {v(sq)} 0.5 1 either]] ne {} ? 1 : 0}] \
              [regexp {^[A-Z]} [cx_msg [cx_call {v(sq)} 0.5 1 either]]] \
              [expr {[string first : [cx_msg [cx_call {v(sq)} 0.5 1 either]]] >= 0 ? 1 : 0}]] \
        {refused 0 1 1 1}
    # ---- rule 2: an empty expression is rejected separately ----
    pcall cx_load tran
    check "CX12 D11 an EMPTY expression is refused on its own account, because calc::rpn_bad_token answers the empty string for a clean RPN *and* for an empty one -- so a `cross` that trusted that proc alone would send nothing to the engine and read a column of zeros" \
        [list [cx_disp [cx_call {} 0.5 1 either]] [cx_disp [cx_call {   } 0.5 1 either]] \
              [pcall calc::rpn_bad_token {}]] {refused refused {}}
    # ---- rule 3: calc::rpn_bad_token runs BEFORE the engine ----
    check "CX12 D11 an unresolvable vector name is refused with the token NAMED, which can only come from calc::rpn_bad_token running BEFORE the engine: `xschem raw add` answers 1 for a rejected expression and leaves a column of defined zeros, so there is no failure downstream to read" \
        [list [cx_disp [cx_call {v(nosuch)} 0.5 1 either]] \
              [string match *v(nosuch)* [cx_msg [cx_call {v(nosuch)} 0.5 1 either]]]] {refused 1}
    # ⚠ THE COLUMN'S VALUE, NOT ITS NUMBER OF DISTINCT VALUES.  This row used to
    # assert `[llength [lsort -unique ...]] == 1`, i.e. "the column holds one
    # distinct value" -- which a column of 101 fives satisfies just as well as a
    # column of 101 zeros, and the whole point of D11's first rule is that the
    # zeros are indistinguishable from an expression that legitimately evaluates
    # to zero.  The value is what makes the sentence true, so the value is what
    # the row asserts, together with the sample count so a one-element column
    # cannot pass it either.
    check "CX12 D11 ...and the engine's own return value is NOT what decided it: `xschem raw add <fresh> {v(nosuch)}` answers 1 and leaves 101 DEFINED ZEROS behind -- asserted as the value 0 and the count, not as `one distinct value`, which an all-fives column would also satisfy" \
        [list [pcall xschem raw add __cx_rejected {v(nosuch)}] \
              [pcall lsort -unique [cx_col __cx_rejected 0]] \
              [cx_len [cx_col __cx_rejected 0]] \
              [pcall xschem raw del __cx_rejected]] {1 0 101 1}
    check "CX12 D11 a token count over the engine's STACKMAX is refused as well, which is landmine L1 and the one rejection class a token-level test cannot see" \
        [cx_disp [cx_call [string repeat {1 } 300] 0.5 1 either]] refused
    # ---- rule 4: the destination is checked with `xschem raw index` BEFORE
    # the add, because `raw add` is register-OR-FIND and then evaluate, so by
    # the time its return says "that column was already there" the engine has
    # already written the caller's expression into somebody else's column.
    # Forced by shadowing the minting proc, which is how band SR4 of
    # test_calc_scratch_reuse reaches the same arm.  ⚠ The victim is NOT named
    # __calc_tmp*: `leaked` watches that prefix, and a probe borrowing it would
    # make every R402 row in this file lie.
    pcall cx_load tran
    pcall xschem raw add __cx_victim {v(ramp)}
    set vic_before [cx_col __cx_victim 0]
    pcall rename ::calc::tmpvec ::cx_real_tmpvec
    proc ::calc::tmpvec {} { return __cx_victim }
    set collided [cx_call {v(sq)} 0.5 1 either]
    set vic_after [cx_col __cx_victim 0]
    pcall rename ::calc::tmpvec {}
    pcall rename ::cx_real_tmpvec ::calc::tmpvec
    check "CX12 D11 when the minted destination already exists `cross` REFUSES, naming it, and in the same house shape CX9's loop asserts -- the <stale> kind, which that loop cannot reach because it needs a shadowed calc::tmpvec; asked with `xschem raw index` BEFORE the add, because `raw add` evaluates first and reports second" \
        [list [cx_disp $collided] [string match *__cx_victim* [cx_msg $collided]] \
              [regexp {^[A-Z]} [cx_msg $collided]] \
              [expr {[string first : [cx_msg $collided]] >= 0 ? 1 : 0}]] {refused 1 1 1}
    check "CX12 D11 ...and the column it did not create is UNCHANGED, which is the property a refusal taken after the add could not have protected -- asserted as the victim's own data surviving, not as the absence of an error" \
        [list [cx_disp $collided] [expr {$vic_before eq $vic_after ? 1 : 0}] \
              [cx_len $vic_before]] {refused 1 101}
    check "CX12 D11 ...and the refusing path did not DELETE somebody else's column either, since it did not make it: the victim is still in the inventory and still resolves" \
        [list [cx_disp $collided] \
              [expr {[pcall xschem raw index __cx_victim] >= 0 ? 1 : 0}] \
              [expr {[lsearch -exact [rawnames] __cx_victim] >= 0 ? 1 : 0}] \
              [cx_len $vic_after]] {refused 1 1 101}
    check "CX12 D11 CONTROL: the real calc::tmpvec is back and still mints a free __calc_tmp<N> name" \
        [list [llength [pcall info procs ::calc::tmpvec]] \
              [string match __calc_tmp* [pcall calc::tmpvec]]] {1 1}
    pcall xschem raw del __cx_victim
    # a minting proc with nothing left to mint, which calc::eval_rpn refuses on
    # and `cross` must too rather than calling `raw add` with an empty name.
    pcall rename ::calc::tmpvec ::cx_real_tmpvec
    proc ::calc::tmpvec {} { return {} }
    set noname [cx_call {v(sq)} 0.5 1 either]
    pcall rename ::calc::tmpvec {}
    pcall rename ::cx_real_tmpvec ::calc::tmpvec
    check "CX12 D11 with no free temporary name available `cross` refuses rather than calling `xschem raw add` with an empty destination, and in the same house shape CX9's loop asserts -- the <noname> kind, which that loop cannot reach because it needs a shadowed calc::tmpvec" \
        [list [cx_disp $noname] [expr {[cx_msg $noname] ne {} ? 1 : 0}] \
              [regexp {^[A-Z]} [cx_msg $noname]] \
              [expr {[string first : [cx_msg $noname]] >= 0 ? 1 : 0}]] {refused 1 1 1}
    # ⚠ A CONSISTENCY ROW, NOT A FENCE, AND IT IS KEPT ONLY FOR UNIFORMITY WITH
    # THE OTHER BANDS.  Every call in CX12 refuses in the PRE-FLIGHT, before
    # `calc::tmpvec`'s name has been handed to `xschem raw add` -- the collision
    # and no-name arms shadow the minting proc precisely so that no `__calc_tmp*`
    # is ever created -- so `leaked` has nothing to find here even on an
    # implementation that leaks every temporary it makes.  VERIFIED BY MUTATION: a
    # reference that never deletes its destination reddens the equivalent row in
    # every other band and leaves this one green.  Read a green here as "the band
    # agrees with its neighbours", never as "cleanup works".
    check "CX12 R402 CONSISTENCY ROW (NOT A FENCE): the band left no __calc_tmp* behind, which it cannot fail to do -- every pre-flight path here refuses before a temporary is minted, so a leaking implementation passes this row; the leak rows in the other bands are the ones that redden" \
        [leaked] {}
    pcall xschem raw clear
}

# =========================================================================
group CX13 {
    # R402: the temporary vector is deleted BEFORE the proc returns, on every
    # exit path INCLUDING error.  ⚠ Recon's correction to landmine L2 makes
    # this LEAK HYGIENE rather than a staleness remedy: a named column is
    # persistent and independent, so a leaked __calc_tmpN stays in
    # `xschem raw list` and the viewer's inventory for the life of the
    # database.  And it cannot be driven by `raw add`'s return code, because a
    # failed add leaves a column behind AND still answers 1.
    pcall cx_load tran
    set base [llength [rawnames]]
    check "CX13 R402 after a MEASURED crossing the inventory is back to its ten names and holds no __calc_tmp*" \
        [list [cx_disp [cx_call {v(sq)} 0.5 1 either]] [leaked] [llength [rawnames]]] \
        [list measured {} $base]
    check "CX13 R402 after an ABSENT measurement, where there was a successful add and nothing to report" \
        [list [cx_disp [cx_call {v(sq)} 0.5 9 either]] [leaked] [llength [rawnames]]] \
        [list absent {} $base]
    check "CX13 R402 after the nth=0 LIST path, which reads the whole column in bulk rather than per point" \
        [list [cx_disp [cx_call {v(sq)} 0.5 0 either]] [leaked] [llength [rawnames]]] \
        [list measured {} $base]
    foreach {what args} {
        bad-nth      {{v(sq)} 0.5 1.5 rising}
        bad-level    {{v(sq)} inf 1 rising}
        bad-edge     {{v(sq)} 0.5 1 up}
        bad-token    {{v(nosuch)} 0.5 1 rising}
        empty-expr   {{} 0.5 1 rising}
        bad-dataset  {{v(sq)} 0.5 1 rising 7}
        allpoints    {{v(sq)} 0.5 1 rising -1}
    } {
        check "CX13 R402 nothing is left behind on the REFUSING path for $what -- a refusal that never reached the engine still has to leave the inventory as it found it" \
            [list [cx_disp [cx_call {*}$args]] [leaked] [llength [rawnames]]] \
            [list refused {} $base]
    }
    # ⚠ THE PATH THE RETURN CODE CANNOT SEE.  `v(sq) -1 del()` passes
    # calc::rpn_bad_token (the Tcl mirror is looser than the C engine here --
    # one of the three disagreements band CE13 of test_calc_engine pins) and is
    # then REJECTED by the engine, which returns -1.  `xschem raw add` discards
    # that, answers 1, and leaves a column of defined zeros.  So the add
    # succeeded, the evaluation did not, and no return code says so -- and the
    # temporary must still be gone.
    check "CX13 R402 an expression the PRE-FLIGHT approves and the ENGINE rejects still leaves nothing behind: `v(sq) -1 del()` is a negative del() delay, which calc::rpn_bad_token passes and plot_raw_custom_data() returns -1 for, so `raw add` answers 1 over a column of zeros and the cleanup cannot be driven by the return code" \
        [list [pcall calc::rpn_bad_token {v(sq) -1 del()}] \
              [cx_disp [cx_call {v(sq) -1 del()} 0.5 1 either]] [leaked] [llength [rawnames]]] \
        [list {} absent {} $base]
    check "CX13 R402 ...and the same is true of the nth=0 path on that expression" \
        [list [cx_disp [cx_call {v(sq) -1 del()} 0.5 0 either]] [leaked] [llength [rawnames]]] \
        [list measured {} $base]
    check "CX13 R402 the non-finite columns leave nothing behind either, which is the exit path a guard that returns early from inside the scan loop would miss" \
        [list [cx_disp [cx_call {v(sq) 1e300 * 1e300 *} 0.5 1 either]] \
              [cx_disp [cx_call {v(ramp) -1 * sqrt()} 0.5 1 either]] \
              [leaked] [llength [rawnames]]] [list absent absent {} $base]
    # R403, narrowed by recon: no `xschem raw` verb takes a column index as
    # INPUT, so L4's dangling-pointer half is unreachable from Tcl.  What IS
    # Tcl-visible is that `raw del` RE-INDEXES, so a cached index or inventory
    # goes stale across one.  `cross` needs exactly one rule: do not cache an
    # index across its own delete -- and the observable consequence is that the
    # fixture's own indices are intact after a measurement.
    # ⚠ COMPARED AS ONE COMMA-JOINED STRING, not as a Tcl list: `i(@m1[id])`
    # contains brackets, so Tcl's canonical list representation braces it and a
    # comparison against a hand-typed list literal fails on the BRACES rather
    # than on the names -- a failing row that says nothing about the tree.
    check "CX13 R403 the fixture's own vector indices and inventory are intact after a measurement, which is the Tcl-visible half of landmine L4: `raw add` appends so existing indices survive it, and `raw del` re-indexes" \
        [list [pcall xschem raw index time] [pcall xschem raw index {v(sq)}] \
              [pcall xschem raw index {v(div)}] [join [rawnames] ,]] \
        [list 0 9 6 {time,@m1[gm],i(@m1[id]),i(@rdc1[i]),i(@rtop[i]),v(dcmid),v(div),v(lp),v(ramp),v(sq)}]
    pcall xschem raw clear
}

# =========================================================================
group CX14 {
    # ⚠ D3's ACCEPTED LIMIT, pinned as a row rather than left as a comment,
    # and named as a LIMIT rather than as a requirement.  A trace that arrives
    # at exactly L, sits flat on it for several samples and then leaves
    # DOWNWARDS registers a RISING crossing on entry and NO FALLING crossing
    # on exit, because the departing pair has y[p-1] == L which is not > L.
    # The behaviour is asymmetric.  It is accepted for v1 because a threshold
    # is normally mid-swing and exact float equality with it is vanishingly
    # rare outside rail-clamped digital traces -- but it is accepted
    # KNOWINGLY, so these rows say what the current behaviour IS.
    #
    # ⚠⚠ A CHANGE HERE IS A DECISION, NOT A REGRESSION.  If a real signal ever
    # hits this, these rows are where the fix starts: expect them to be
    # restated, and do not "fix" them to match a new convention without
    # recording the ruling.
    #
    # ⚠ NOT REACHABLE THROUGH THE FIXTURE TRACE.  Four of v(sq)'s five 50 %
    # samples are 9e-16 to 1.8e-15 off exact, so the asymmetry needs a
    # SYNTHETIC CLAMPED column: `v(sq) 0.5 min()` caps the square wave at 0.5,
    # and where v(sq) >= 0.5 the result is the CONSTANT operand, bit-exactly
    # 0.5.  The trace then arrives at 0.5, sits there for the whole flat-one
    # interval, and leaves downwards -- three times.
    pcall cx_load tran
    set t0 [cx_col time 0]
    set cl [cx_addcol __cx_clamp {v(sq) 0.5 min()} 0]
    check "CX14 the clamped column really is bit-exactly 0.5 on its flat intervals -- min() returns the lesser operand, so where v(sq) >= 0.5 the result is the constant -- which is what makes the limit reachable at all" \
        [list [cx_len $cl] [lindex $cl 10] [lindex $cl 11] [lindex $cl 22] [lindex $cl 100] \
              [expr {[lindex $cl 11] == 0.5}] [expr {[lindex $cl 9] < 0.5}] \
              [expr {[lindex $cl 23] < 0.5}]] {101 0.5 0.5 0.5 0.5 1 1 1}
    # ⚠ THE TRACE ARRIVES THREE TIMES AND DEPARTS TWICE, not three times: the
    # third arrival at sample 90 runs to the end of the sweep at sample 100.
    # So the asymmetry below is "3 rising, 0 falling" against a symmetric
    # convention's "3 rising, 2 falling", and the row names the 2 rather than
    # a 3 nobody can observe.
    check "CX14 ...and it arrives at the level three times (samples 10 50 90) and departs twice inside the sweep (the third arrival runs to sample 100), so a symmetric convention would find three rising and TWO falling here" \
        [list [expr {[lindex $cl 9] < 0.5}]  [expr {[lindex $cl 10] == 0.5}] \
              [expr {[lindex $cl 22] == 0.5}] [expr {[lindex $cl 23] < 0.5}] \
              [expr {[lindex $cl 49] < 0.5}] [expr {[lindex $cl 50] == 0.5}] \
              [expr {[lindex $cl 61] == 0.5}] [expr {[lindex $cl 62] < 0.5}] \
              [expr {[lindex $cl 89] < 0.5}] [expr {[lindex $cl 90] == 0.5}] \
              [expr {[lindex $cl 100] == 0.5}]] {1 1 1 1 1 1 1 1 1 1 1}
    check "CX14 D3 ACCEPTED LIMIT: on that column `cross` finds THREE rising crossings, at the entry samples 1.0 / 5.0 / 9.0 ms -- the inclusive-above half of the predicate counting the arrival" \
        [cx_islist [cx_call {v(sq) 0.5 min()} 0.5 0 rising] \
             [list [sq_rise 0.5 0] [sq_rise 0.5 1] [sq_rise 0.5 2]]] ok
    check "CX14 D3 ACCEPTED LIMIT: ...and ZERO falling crossings, although the trace leaves the level downwards twice -- because the departing pair has y at p-1 equal to L, which is not strictly greater than L.  THIS IS THE ACCEPTED ASYMMETRY, pinned so a change to it is a decision and not a regression" \
        [list [cx_disp [cx_call {v(sq) 0.5 min()} 0.5 0 falling]] \
              [cx_len [cx_val [cx_call {v(sq) 0.5 min()} 0.5 0 falling]]] \
              [cx_disp [cx_call {v(sq) 0.5 min()} 0.5 1 falling]] \
              [cx_disp [cx_call {v(sq) 0.5 min()} 0.5 -1 falling]]] \
        {measured 0 absent absent}
    check "CX14 D3 ACCEPTED LIMIT: ...so `either` on that column is the three rising ones and nothing else, and nth=-1 is the 9.0 ms arrival rather than the departure that follows it" \
        [list [cx_islist [cx_call {v(sq) 0.5 min()} 0.5 0 either] \
                   [list [sq_rise 0.5 0] [sq_rise 0.5 1] [sq_rise 0.5 2]]] \
              [cx_is [cx_call {v(sq) 0.5 min()} 0.5 -1 either] [sq_rise 0.5 2]]] {ok ok}
    check "CX14 CONTROL: the asymmetry is about exact equality with L and not about the clamp -- at level 0.25, which the clamp leaves untouched, the same column gives the deck's own three rising and two falling, at the same times v(sq) does" \
        [list [cx_islist [cx_call {v(sq) 0.5 min()} 0.25 0 rising] \
                   [list [sq_rise 0.25 0] [sq_rise 0.25 1] [sq_rise 0.25 2]]] \
              [cx_islist [cx_call {v(sq) 0.5 min()} 0.25 0 falling] \
                   [list [sq_fall 0.25 0] [sq_fall 0.25 1]]]] {ok ok}
    check "CX14 the band left no __calc_tmp* behind" [leaked] {}
    pcall xschem raw clear
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

## ⚠⚠ THE `OVERALL: ok` SENTINEL IS WHAT T1 CAN SCORE.  `banner_complete` in
## tests/banner_rule.tcl -- the ONLY Tcl reader of the rule, and the one
## tests/run_regression.tcl sources -- is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`
## and accepts NO `RESULT: ALL PASS` spelling, while run_suites.sh and
## full_audit.sh carry their own EREs which DO accept it.  So passing standalone
## is no evidence a suite can be registered: that is how both sibling calculator
## suites gated nothing for a month (issue 1626).
##
## ⚠ `RESULT:` IS LAST, AND THERE IS EXACTLY ONE OF IT.  summarize_all publishes
## a case's last `^RESULT:` line into the verdict; a SECOND one silently becomes
## the published check count with nothing reddening (issue 1627, OPEN and
## unfenced).  This file has ONE exit path on purpose -- there is no no-X gate,
## because nothing here needs a display, and a whole-file early exit that
## printed no sentinel would be scored `OVERALL_ok=0` with every one of its own
## checks passing (issue 1615).
##
## ⚠ ONLY THE SUCCESS PATH CLAIMS COMPLETION.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
