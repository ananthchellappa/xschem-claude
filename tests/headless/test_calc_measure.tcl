# tests/headless/test_calc_measure.tcl — the three timing verbs layered on
# `cross`: `riseTime`, `delay` and `dutyCycle`.
#
# Spec     doc/claude/specs/calculator.md §7.2 (the catalogue rows), §7.2aa
#          (R414-R414e, inherited through `cross`), §7.3 (R401-R405) and §11.2
#          (the fixture contract)
# Contract doc/claude/calculator_batch/TIMING_CONTRACT.md — R415, R416, T1-T7.
#          doc/claude/calculator_batch/CROSS_CONTRACT.md — D1-D12, STILL IN
#          FORCE for these three, since all three answer through `calc::cross`.
#          ⚠ D10 in that file is REVERSED; the live half is the heading, the
#          superseded reasoning sits in a collapsed block below it.
# Evidence doc/claude/calculator_batch/receipts/F2-cross-suite-and-implementation.md
# Plan     doc/claude/calculator_batch/PLAN.md row 7.3
# Fixture  tests/headless/data/calc_fixture.raw, contract and HAND DERIVATIONS
#          in tests/headless/data/README.md
#
# ⚠⚠ THIS FILE WAS WRITTEN RED-FIRST, BEFORE ANY OF THE THREE VERBS EXISTED.
# Every behavioural band below failed when it was written, each failure naming
# the proc that is missing rather than printing a bare Tcl error, and the
# transcript of that red is in the stage receipt.  A row written after the code
# has never been observed to fail and is unproven as a fence; these were.  The
# suite is deliberately NOT registered in tests/run_regression.tcl by the commit
# that creates it — an all-red registered suite is a standing red in T1 — so
# REGISTERING IT IS THE IMPLEMENTATION COMMIT'S JOB, in `hcases`, in the same
# change as the code (TIMING_CONTRACT T6).
#
# ⚠ A LATER REPAIR STAGE ADDED ROWS, AND SAYS SO RATHER THAN LETTING THE PARAGRAPH
# ABOVE COVER THEM.  Two adversarial lenses found four mutations that reddened NO
# row, and the rows written to close them were written against a conforming
# scratch reference — so they were green before they were red, which is the
# opposite order.  They were then run against the real tree with none of the three
# verbs present and each was OBSERVED FAILING there, which is the property the
# red-first rule is actually about; what they do NOT have is the authoring-stage
# history of having been written blind.  The receipt names them.
#
# ---------------------------------------------------------------------------
# WHAT THE THREE VERBS ARE, in the words of the rulings that decided them
# ---------------------------------------------------------------------------
#
# `riseTime`  R415.  The reference levels are SUPPLIED, never derived from the
#             waveform — the user's own words were *"Cadence makes you supply
#             them"*.  The thresholds are percentages OF THAT SUPPLIED SWING, so
#             the verb is arithmetic over `cross` and there is no min/max search,
#             no first/last-sample rule and no settled-value estimator anywhere
#             in it.  OMITTING THE SWING IS A REFUSAL, not a guess: band MT3.
#             T2: the high crossing is the FIRST ONE AFTER the low crossing of
#             the requested occurrence, never "the nth crossing at each level" —
#             band MT4 measures the difference on a column where the two
#             readings disagree, and where the naive one answers NEGATIVE.
#
# `delay`     T3.  A full edge specification PER SIDE — level, direction and
#             occurrence each independent, not one shared level and not one
#             shared `nth`.  AND A NEGATIVE ANSWER IS LEGITIMATE AND IS
#             RETURNED, never refused: band MT6.  That is not taste, it follows
#             from a standing project rule — ADE-L is a FLOOR, so a restriction
#             ADE-L does not have is a defect, and refusing a negative delay
#             would be exactly such a restriction.
#
# `dutyCycle` R416.  Returns a WAVE, one value per cycle — the user's own words
#             were *"a wave — one value per cycle"*.  Not the first period, not
#             the mean.  T4: a FRACTION, never a percent, because the shipped
#             catalogue help already promises *"Fraction of a period the signal
#             spends high"* and answering 30 against that text would make
#             shipped user-visible prose false.  A trailing PARTIAL period is
#             not a period and is EXCLUDED — and NEITHER of those two claims can
#             be fenced on `v(sq)`, which is measured and is why band MT8 has a
#             second half: `v(sq)`'s two periods have identical duty, so "one value
#             per cycle" is satisfied by one duty repeated, and its trailing rising
#             crossing has no fall after it, so the exclusion is satisfied by a verb
#             that closes the last period at the end of the sweep.  T5 is the sharp
#             edge this stage owns: `calc::cross_scan`'s nth=0 arm answers SUCCESS
#             WITH AN EMPTY LIST for a level nothing reaches, so the guard against
#             that list reaching the period arithmetic is a ROW and not a comment.
#
# ---------------------------------------------------------------------------
# ⚠⚠ THE SIGNATURES AND THE ANSWER REPRESENTATION ARE DECIDED HERE, AND THE
# DECISION IS THIS FILE'S RATHER THAN THE CONTRACT'S
# ---------------------------------------------------------------------------
#
# TIMING_CONTRACT names the three verbs, their dispositions and their
# arithmetic, and leaves the argument lists to the implementer — but a red-first
# row cannot call a proc whose argument list nobody has chosen, so this file
# chooses, following `calc::cross`'s own vocabulary.  THE IMPLEMENTATION STAGE
# MAY OVERRULE ANY OF THIS; what it may not do is leave the two disagreeing
# silently.  Every row reaches the product through the adapter procs named
# below, so a different choice is an edit to the adapter and not to two hundred
# rows.
#
#   calc::riseTime        <rpn> ?<lo>? ?<hi>? ?<pctlo>? ?<pcthi>? ?<nth>? ?<dataset>?
#   calc::delay           <rpnA> <levelA> <edgeA> <nthA> \
#                         <rpnB> <levelB> <edgeB> <nthB> ?<dataset>?
#   calc::dutyCycle       <rpn> <level> ?<cycle>? ?<dataset>? ?<xaxis>?
#   calc::dutyCycle_scalar <rpn> <level> ?<cycle>? ?<dataset>? ?<xaxis>?
#
# ⚠ THE WRAPPER'S `?<xaxis>?` ARRIVED WITH PLAN 5.4 AND THE TWO PARAGRAPHS
# BELOW ARE THE DATED RECORD OF WHY IT WAS ABSENT, not a live description.  Hole
# H9 offered the implementer two fixes -- extend the wrapper, or have the result
# path call `calc::dutyCycle` directly -- and the wrapper was extended, because
# the dialog calls the SURFACE and a field the dialog offers must reach the proc
# it calls.  MT11's surface-formals row is what was red for it.
#
# ⚠ `?<xaxis>?` WAS MISSING FROM THE LINE ABOVE UNTIL 2026-10-03, AND THE GAP
# WAS A MEASUREMENT OWED BY PLAN 5.4 RATHER THAN A TYPO.  R420 made the X axis
# an argument with a default AFTER this block was written, CLICK_CONTRACT
# section 8's field table puts `X axis` SECOND in the dialog, and
# DESTINATION_CONTRACT names neither the argument nor its position -- three live
# documents, three different answers.  READ OFF THE SHIPPED PROC:
# `calc::dutyCycle` is `{rpn level {cycle 0} {dataset 0} {xaxis start}}`, so
# `xaxis` is FIFTH AND LAST, AFTER `dataset`.  The dialog's display order and
# the proc's formal order therefore DIFFER, which is why band MT11 requires the
# call to be composed BY KEY and measures that the two orders really diverge.
# ⚠ And `calc::dutyCycle_scalar` -- the SURFACE wrapper, which is what a click
# must call -- has no `xaxis` formal at all and forwards four arguments.  Its
# own shipped comment says that is deliberate and names phase 5's dialog as the
# caller it is waiting for.  Hole H9 below.
#
# `lo` and `hi` are the SUPPLIED reference levels — the swing R415 says the user
# must give — and they are OPTIONAL WITH AN EMPTY DEFAULT ON PURPOSE: if they
# were mandatory positional arguments, omitting them would be a Tcl arity error,
# i.e. a THROW, where R415 demands a REFUSAL.  `pctlo`/`pcthi` default to 10 and
# 90, which is the reference tool's own default for the two thetas and is a
# default on the THRESHOLDS, not on the swing; R415 is about the swing.
# `cycle` 0 is every cycle, mirroring `cross`'s nth=0, and a named cycle is a
# scalar.
#
# The answer is `calc::cross`'s dict, unchanged, so a verb can propagate what it
# was told rather than re-encode it:
#
#   measured  -- key `ok` = 1, the answer under key `value` (a LIST for
#                dutyCycle's default, a single number otherwise)
#   absent    -- D5/R414b: `ok` = 0 and `absent` = 1, with a sentence in `msg`
#   refused   -- D7: `ok` = 0 and `absent` = 0, with a sentence in `msg`
#
# The keys a row may reach are exactly `ok`, `absent`, `value`, `msg` and
# `dataset`, ENUMERATED rather than counted.  `dest` is deliberately not in that
# list and no row reads it: a verb making two `cross` calls mints two temporary
# columns, so there is no one `dest` for it to carry, and what this suite
# actually cares about is that NEITHER SURVIVES — which band MT10 measures
# through `xschem raw list`, not through a key.
#
# THE PROCS THAT KNOW THAT SHAPE ARE ENUMERATED AND NOT COUNTED: `mt_call`,
# `mt_disp`, `mt_val`, `mt_msg`, `mt_key` — `mt_stub_run`, whose stub CONSTRUCTS
# a refusal dict — and `mt_asanswer`, which wraps a value DERIVED BY THIS FILE in
# the same shape so that a row comparing two derivations can reuse `mt_islist`.
# An implementer who wants a different representation edits exactly those.
#
# ⚠ THE LIST IS ENUMERATED BECAUSE A COUNT HERE WOULD BE THE ONE CLAIM NOTHING
# IN THIS FILE RE-MEASURES, AND BECAUSE THIS SENTENCE SHIPPED WRONG IN THIS VERY
# FILE TWICE.  Its first revision said FIVE and named five, having forgotten
# `mt_stub_run`; its second named six and was still false, because band MT1
# CONSTRUCTED the dict INLINE at three row sites — the grep that corrected the
# first revision had been run over proc names and not over `dict create`, which
# is the sibling suite's signature failure arriving one level up.  `mt_asanswer`
# exists so that the claim is true by construction, and the invariant is a ROW
# rather than a sentence here: `mt_dictsites` walks this file for every site that
# builds the answer dict, names the enclosing proc, and MT10 asserts that set is
# exactly the enumeration above — so a new inline site reddens instead of
# falsifying a comment, and no count is written down for nothing to re-check.
#
# ---------------------------------------------------------------------------
# ⚠ EVERY NUMBER ASSERTED OFF A FIXTURE COLUMN IS DERIVED TWICE, AND NEVER TAKEN
# FROM A RECEIPT — AND THE QUALIFIER IS NOT DECORATION
# ---------------------------------------------------------------------------
#
# ⚠ THIS HEADING USED TO READ "EVERY ASSERTED NUMBER IS DERIVED, TWICE" AND THAT
# WAS FALSE, found by an adversarial lens enumerating the swings MT2 drives against
# the swings MT1 seeds: `0.25 .. 0.75` at 10/90 was asserted ONCE, deck-only, and
# so its two thresholds got neither of MT1's interpolation fences either.  The same
# held of MT5's and MT6's per-side numbers, which came from the inverted column with
# no deck counterpart.  Both are fixed by SEEDING rather than by narrowing the
# claim — MT1 now covers all four swings, the inverted column through the
# 1-minus-v(sq) identity, and `v(div)` in both datasets — and the claim is now
# stated with the boundary it actually has:
#
# **THE SYNTHETIC COLUMNS THIS FILE BUILDS THROUGH THE ENGINE ARE DERIVED ONCE, FROM
# THE COLUMN, BY DESIGN.**  The glitch column, the false-start column and the
# divider-offset square have no deck: they are expressions this suite invented, the
# engine is free to disagree with the arithmetic in the comment above `mt_glitch`,
# and a second hand derivation would be a second chance to be wrong in the same
# place.  What those bands assert instead is that the column's CROSSING STRUCTURE
# is what the rows depend on, as a row, in the same run.  Every number taken off a
# column the FIXTURE DECK authored — `v(sq)`, `v(ramp)`, `v(div)` and the inverted
# square — is derived twice.
#
# Two independent derivations, and a row fails if they disagree:
#
#  1. FROM THE DECK.  `v(sq)` is PULSE(0 1 0.9m 0.2m 0.2m 1m 4m) on a 0.1 ms
#     grid, so its rising edge k runs 0.9+4k -> 1.1+4k ms through 0 -> 1
#     linearly and crosses level L at t = 0.9 + 0.2L + 4k ms, while its falling
#     edge k runs 2.1+4k -> 2.3+4k ms through 1 -> 0 and crosses L at
#     t = 2.3 - 0.2L + 4k ms.  `sq_rise` and `sq_fall` are those two lines and
#     nothing else, and the three verbs' deck values fall straight out of them:
#       riseTime over a supplied swing  =  0.2 ms * (Lhi - Llo)      `sq_rt`
#       dutyCycle at level L            =  (1.4 - 0.4L) / 4          `sq_duty`
#     ⚠ `sq_duty` IS WHERE THE 0.30 THE BRIEF QUOTES COMES FROM, AND IT WAS
#     RE-DERIVED RATHER THAN TRUSTED: high time is fall(L) - rise(L) =
#     (2.3 - 0.2L) - (0.9 + 0.2L) = 1.4 - 0.4L ms, the period is rising-to-
#     rising = 4 ms exactly at every level, so at L = 0.5 the fraction is
#     1.2/4 = 0.3.  The brief's arithmetic ("1 ms width + 0.2 ms edges = 1.2 ms
#     high of a 4 ms period") agrees, and so does the recon figure
#     0.3000000000000002 — but notice the deck formula is LEVEL-DEPENDENT and
#     the brief's sentence is not, which is why band MT8 also measures 0.3 and
#     0.75, where the answers are 0.32 and 0.275.  An implementation that
#     hardcoded the 50 % duty would pass a 0.5-only row.
#  2. FROM THE COLUMNS, with this file's own copy of CROSS_CONTRACT D3's
#     predicate and D4's interpolation (`mt_derive`), run over
#     `xschem raw values`.  Band MT1 asserts the two derivations agree, and
#     nothing in MT1 calls one of the three verbs.  (It does call
#     `calc::rpn_bad_token`, to show the engine accepted the synthetic expression
#     it builds, and MT0 calls `calc::eval_finite` and `calc::cross`: the claim is
#     about the three verbs under measurement, not about the namespace.)
#
# ⚠⚠ NEVER COMPARE ACROSS THE PRECISION DOOR, and that is a measured defect in
# the sibling suite rather than a caution.  `xschem raw values` prints "%.16g";
# `xschem raw value` prints `dtoa()` = "%.8g" (`src/util.c`).  Four legs of
# test_calc_cross.tcl were structurally dead because they compared a
# bulk-derived answer against a per-point comparand, and two more were alive
# only because 0.001 and 0.005 happen to round-trip.  SO NO ROW IN THIS FILE
# USES `xschem raw value` FOR A COMPARAND — every comparand comes from the bulk
# column, and MT0 carries a row that re-measures the door's disagreement so it
# cannot be reintroduced quietly.
#
# ⚠ TOLERANCE, NOT EQUALITY (`MTTOL`), and the figure is chosen rather than
# inherited.  The fixture README's measured headroom is 1e-12 relative for
# `time` and 1e-11 for `v(sq)` at its 50 % samples.  This file uses 1e-7
# relative, LOOSER than either on purpose: a rise time is a difference of two
# quotients of differences of fixture samples and a duty cycle is a quotient of
# two such differences, so they carry more dust than the samples they are built
# from, and pinning them to the column's headroom would fence the arithmetic's
# round-off rather than the behaviour.  What 1e-7 still discriminates is
# everything these rows are about, and each row derives its own discrimination
# rather than asserting it in a name: the snapped-to-sample candidates, the
# percent spelling of a fraction, the trace-derived swing, and the naive
# "nth at each level" reading are each enumerated in the row that rules them
# out, and each asked of this file's own `near` at `MTTOL`.
#
# ⚠ LEVELS STRICTLY INSIDE THE SWING OF THE COLUMN THEY ARE ASKED OF, WITH THREE
# DECLARED EXCEPTIONS, AND THE QUALIFIER MATTERS: this sentence used to say
# "strictly inside (0, 1)" without naming a column, which was true while every
# column here swung 0 to 1 and became false the moment the dataset rows started
# asking `v(div)` — which swings 0 to 5 — about the level 4.5.  On `v(sq)` the
# values 0.0 and 1.0 are unusable: the two plausible strict/non-strict conventions
# disagree there in COUNT and in DIRECTION, and 1.0 additionally carries a
# dust-driven recrossing at v[51] = 1.000000000000039.  So every level asserted to
# BE CROSSED is strictly inside its own column's swing — (0, 1) for `v(sq)`, the
# inverted square, the glitch column and the false-start column; (0, 5) for
# `v(div)` in dataset 0; (0, 10) for `v(ramp)`.  The three exceptions are all
# places where a level NOT being reached is the measurement:
#   * MT9's 2.0 on `v(sq)`, and the 2.0..3.0 swing it hands `riseTime`, chosen
#     precisely because NO sample reaches them under either convention;
#   * the dataset rows' upper levels in DATASET 1, where `v(div)` is `v(ramp)/4`
#     and tops out below them — which is exactly how those rows tell the two
#     datasets apart by DISPOSITION rather than by a tolerance;
#   * `riseTime`'s 88 % threshold on the false-start column, which the trailing
#     half-height bump cannot reach, which is what makes T2's other absence
#     reachable at all.
#
# ⚠ A ROW MUST FAIL, NEVER THROW, and in this file that has two distinct
# radii, both measured on the sibling suite rather than assumed.  A throw out of
# the PRODUCT is caught by `mt_call` and becomes a legible sentinel, failing ONE
# ROW.  A throw out of SUITE code is caught by `group`, which scores it as a
# counted FAIL and ABANDONS THAT BAND'S REMAINING ROWS while the next band still
# runs — the worse of the two, because an abandoned band silently stops
# measuring.  The file-scope catch at the bottom sees only an error raised
# BETWEEN bands.  So every call to one of the THREE VERBS goes through `mt_call`,
# every other call into `::calc::` — `eval_finite`, `rpn_bad_token`, `cross_msg` —
# goes through `pcall`, which turns a raise into an `ERR:` sentinel the same way,
# and
# every `llength` or `lindex` on something the product returned goes through
# `mt_len` or `mt_at`: `llength` of a string whose first character after a space
# is an unmatched open brace RAISES, and a refusal sentence or a `RAISED:`
# sentinel could carry one.  ⚠ THE CLAIM IS ABOUT WHAT THE PRODUCT AUTHORED AND
# NOTHING ELSE: the bands index `mt_col` and `mt_addcol` columns, and the lists
# `mt_derive_x` and `mt_duty_series` build out of them, with a bare `lindex` and
# `llength` on purpose — those are "%.16g" numbers written by `xschem raw values`
# and arithmetic over them, which the three verbs do not author, so no refusal
# sentence can reach them.
#
# ⚠⚠ NO ROW MAY ASSERT A PROPERTY OF AN ANSWER WITHOUT THE DISPOSITION BEING PART
# OF WHAT IT COMPARES — either as the FIRST ELEMENT the row supplies, or because
# the comparison itself carries it.  `mt_islist`, `mt_notlist` and `mt_is` return
# the DISPOSITION when the answer is not `measured`, so a row whose only leg is
# one of those already fails legibly on a sentinel and needs no separate
# `mt_disp` leg; `near`, `string equal`, `mt_len` and a bare `expr` do NOT, and a
# row using one of those supplies the disposition itself.  ⚠ THIS SENTENCE USED TO
# SAY "EVERY ROW ... CARRIES `mt_disp` AS THE FIRST ELEMENT" AND THAT WAS FALSE OF
# THIS FILE: MT8's level row has three `mt_islist` legs and no `mt_disp`, which is
# safe for the reason just given, so the claim was wrong where the file was right.
# (`mt_is` carries it by routing through `near`, which answers
# `NOTANUMBER:{absent}` rather than comparing a word against a number.)
#
# THE RULE ITSELF is a measured
# correction to the sibling suite's first draft, not decoration: on its red run
# A WHOLE CLASS OF ROWS PASSED ACCIDENTALLY, because a sentinel satisfies a
# bare identity or predicate exactly as a real answer does.  (The count that
# used to be in this sentence is gone on purpose: the sibling suite's receipt
# RETIRED its own "nineteen" as a figure taken over a revision of a file that no
# longer exists, so no instrument could reproduce it.  The SHAPE is
# re-measurable and is the useful claim.)  `f(a) eq f(b)` is true
# when both sides are the same error marker; `string is double -strict` is false
# for a sentinel exactly as for a genuine absence; `llength` of a one-word
# sentinel is 1.  The same trap has a structural form that bit this file during
# authoring: a row asserting that the three verbs issue NO direct
# `xschem raw` verb is VACUOUSLY TRUE while the three verbs do not exist, so
# MT10's rows carry the set of verbs that are PRESENT as the first element of
# what they compare.
#
# ⚠ NO DISPLAY GATE, ON PURPOSE.  Nothing here touches a widget, so this is an
# `hcases` suite with ONE exit path.  It must NOT copy test_calc_buffer's or
# test_calc_plot's whole-file no-X early exit: those exits print no
# `OVERALL: ok`, so an `hcases` entry carrying one is scored
# `HARNESS: ... (exit=0, OVERALL_ok=0, died=0)` with every one of its own checks
# passing — issue 1615's incident exactly.
#
#   MT0  Infrastructure: the fixture is the one §11.2 describes, read with an
#        EXPLICIT type; the sweep resolves BY NAME and not as index 0; the bulk
#        and per-point doors DISAGREE, which is why no comparand here comes from
#        the per-point one; `calc::cross` answers as it shipped, in all three
#        dispositions; and T5's hazard is REAL — nth=0 at an uncrossed level
#        answers MEASURED WITH AN EMPTY LIST.  PASSES TODAY.
#   MT1  Infrastructure: the deck arithmetic and this suite's own D3+D4 over the
#        bulk columns agree, for every number the behavioural bands assert — the
#        four supplied swings MT2 drives, the inverted column MT5 and MT6 subtract
#        through the 1-minus-v(sq) identity, and `v(div)`'s per-dataset relation the
#        dataset rows tell the two datasets apart by; every threshold falls
#        STRICTLY BETWEEN samples so interpolation is fenced; and the glitch column
#        MT4 needs has the crossing structure MT4 claims.  Nothing here calls a
#        verb.  PASSES TODAY, and it is what makes every band below non-vacuous:
#        MT1 green with MT2+ red means the feature is absent, MT1 red means the
#        suite is broken and nothing else it says counts.
#   MT2  R415 the supplied-swing arithmetic: thresholds are percentages OF THE
#        SUPPLIED SWING, with a row a trace-derived-swing implementation fails; and
#        the dataset READ, not merely reported — `v(div)` measures in one dataset
#        and is ABSENT in the other, which a verb echoing the argument cannot do.
#   MT3  R415 omitting the swing is a REFUSAL, and refused stays DISTINCT from
#        absent — D7's own reason for keeping the two apart.
#   MT4  T2 the high crossing is the first one AFTER the low crossing of the
#        requested occurrence.  Measured on a column where "nth at each level"
#        answers a different number at occurrence 2 and a NEGATIVE one at
#        occurrence 3, with occurrence 1 kept as a control where the two agree.
#        Plus R414c's NEGATIVE ordinal, measured POSITIVELY — `-1` and `-3` select
#        different low crossings, so an `abs(nth)` implementation reddens — and the
#        other T2 absence, a low crossing with NO high crossing after it, which
#        needs its own column because the glitch column's last bump is full height.
#   MT5  T3 a full edge spec PER SIDE, positive answer; each of the three
#        per-side fields moved ALONE; and the dataset READ, as in MT2.
#   MT6  T3 a NEGATIVE delay is MEASURED and RETURNED, never refused.
#   MT7  absence propagates from either side; a refusal composes and stays
#        distinct from an absence; and `nth` 0 on a side DEFERS rather than
#        reaching the subtraction, which is T5's hazard class one verb over.
#   MT8  R416/T4 the per-cycle WAVE, a FRACTION not a percent, level-dependent,
#        a named cycle as a scalar, the trailing PARTIAL period EXCLUDED — fenced
#        on the INVERTED square, because on `v(sq)` the plausible wrong
#        implementation answers the right COUNT for an unrelated reason — the
#        per-cycle values DIFFERING from each other and read IN ORDER, which
#        `v(sq)` cannot show because its two periods have identical duty, the
#        dataset READ, and the UI surface deferring behind the sentence `cross`
#        already uses.
#   MT9  T5 the empty crossing list is GUARDED at the point of use.
#   MT9b issue 1639 — the NON-EMPTY crossing list, which is the other half of the
#        same hazard and reaches a DIFFERENT operand: `nth` 0 handed to `riseTime`
#        put a list on the LOW side of its subtraction and RAISED, where the empty
#        list MT9 drives is covered by the absence test.  The disposition is
#        deferral behind the shared `listdefer` sentence, asserted by identity and
#        pairwise against `delay`; the ordinal is read by VALUE so every spelling
#        of zero defers; a request that is also MALFORMED is refused as malformed
#        rather than deferred; and a non-finite ordinal keeps `cross`'s own
#        refusal, which is what stops the guard trading one raise for another.
#        â  FOUR OF ITS ROWS MOVED WITH STAGE J UNIT J2, which retired the
#        deferral for this caller: `nth` 0 now MEASURES a series, carries no
#        `listdefer` sentence, opens the engine door it needs, and answers the
#        same series for all four spellings of zero.  `delay` is still driven in
#        the sentence row and still defers, so the row cannot go green by both
#        callers falling silent together.  The deferral rows that did NOT move
#        are the ones about requests that are malformed or non-finite, which are
#        refusals and not deferrals and were never J2's to change.
#   MT9c stage J unit J2 â `riseTime`'s `nth` 0 ANSWERING: the per-edge rise
#        time SERIES, one rise time per rising edge, with a parallel X.  The
#        edge count is read back off `calc::cross` and never written down;
#        the Y is derived THREE independent ways (the scalar ordinal path band
#        MT4 already fences, a Tcl element-wise product of two committed
#        columns, and the engine's own product column shown to agree with it);
#        the fixture is `{v(sq) v(ramp) *}` because the two obvious columns
#        cannot tell a reversed or a constant-filled Y from a correct one at
#        MTTOL, which is measured in the band's own control row; THREE points,
#        so a dropped middle sample and a rotation told apart from a reversal
#        are fenceable for the first time in this stage; a low crossing with no
#        high after it DROPS that point; an empty series is an ABSENCE and never
#        a `destempty` destination problem, asserted by family rather than by
#        words; and the new `calc::riseTime_scalar` surface, whose formals are
#        derived from the verb's own and whose ORDER is measured on two probe
#        surfaces that show a mid-list formal silently replacing the user's
#        ordinal with a default.
#   MT10 T1 all three are PURE DELEGATES on `calc::cross` — structurally, as a
#        TRANSITIVE closure that permits a `::calc::` chain and forbids any link
#        in it reading samples, and behaviourally with `calc::cross` replaced by a
#        refusing stub; every refusal in the house sentence shape; the answer
#        representation known only in the procs the header enumerates, derived over
#        this file's own text; and no `__calc_tmp*` surviving any exit path,
#        refusals and error paths included.
#   MT11 PLAN 5.4 / R412 — `calc::fn_argspec`, the ARGUMENT SPECIFICATION the
#        modal dialog is built from, and the one piece of phase 5 that needs no
#        Tk and therefore gates on BOTH arms.  The four specifications by
#        literal, one row each so that overruling one verb is a one-row edit;
#        the shape rules derived over whatever the four actually answer; the
#        30-verb fall-through swept over the whole catalogue; every key checked
#        against the formals of BOTH the measurement proc and the SURFACE proc a
#        click must call; the two enum member lists LIFTED out of their
#        validators' own bodies and shown to be ACCEPTED by the verbs with no
#        fixture at all; and a fence on the SHAPE OF THE SOLUTION — a proc, not a
#        seventh catalogue field.  ⚠ The dialog, the click, the browser gesture
#        and the `grab` are display-only and are band S28 of
#        tests/headless/test_calc_skeleton.tcl and band CW14 of
#        tests/headless/test_calc_widgets.tcl, both `dcases` ALONE — so only the
#        gate's DISPLAY arm verifies those, and a `--nogui` number proves nothing
#        about them.
#   MT12 stage J unit J1b / R404 / R421 — `calc::fn_sink`, THE ROUTING DECISION
#        for an answer that is a WAVE, and the second half of the stage that
#        wires the destination to the verbs that used to refuse.  A PURE
#        predicate with no Tk in it, so it gates on BOTH arms, and that is the
#        whole reason it was factored out of `calc::fn_measure`: that proc and
#        `calc::buf_set_number` BOTH return early on `calc::has_win .calc.buf`,
#        so a shape branch left inside either is observable on a gate's DISPLAY
#        arm and nowhere else, and the person this tree is built for reads the
#        transcript.  The CLOSED vocabulary derived from the proc's own literal
#        `return` words; the decision over every disposition that vocabulary
#        admits, fail-closed on both an unknown shape and a non-number; the
#        cases that tell a DECLARATION apart from an inference over the value's
#        list LENGTH, which WIRING_CONTRACT section 4 rejects by name; one
#        sentence per disposition that reaches the user, derived over the
#        vocabulary rather than listed; the destination sentence NAMING the
#        destination, never its words; the `calc::arg_msg` arm sweep, which is
#        the only behavioural confirmation that no comment landed between two of
#        its switch patterns; and two derived SUBSET claims over the namespace —
#        no proc pastes into the buffer without asking where the answer goes,
#        and no caller builds a destination without declaring the shape.
#        ⚠ WHAT THIS BAND CANNOT SEE is the ACT rather than the DECISION: that
#        the buffer is really left UNTOUCHED on a wave answer, and that the
#        sentence really reaches `.calc.status.msg`.  Both are display-only for
#        the reason above and belong to band S28 of
#        tests/headless/test_calc_skeleton.tcl and band CW14 of
#        tests/headless/test_calc_widgets.tcl, both `dcases` ALONE.
#
# ⚠ WHICH ROWS OUTSIDE MT0 AND MT1 PASS WITH NO FEATURE PRESENT, DECLARED RATHER
# THAN LEFT FOR A READER TO NOTICE, because a row that is green on the red run is
# the thing most likely to be read as a fence when it is not one yet.  They are,
# BY KIND and not by count:
#
#   * the per-band R402 inventory rows.  Nothing mints a `__calc_tmp*` while the
#     verbs do not exist, so these cannot redden TODAY — they are real fences for
#     the implementation and vacuous against its absence, which is the same
#     declared status the sibling suite's CX12 carries.
#   * MT9's first row, which re-measures T5's hazard on `calc::cross` itself and
#     is infrastructure sitting inside a behavioural band on purpose, so the band
#     is not vacuous if the sibling behaviour ever changes.
#   * MT10's four CONTROL rows: the structural instrument working on
#     `calc::cross`, `calc::cross` being restored after the stub probe,
#     `mt_shape` rejecting the three malformed sentences it is given, and
#     `mt_dictsites` — which is a claim about THIS FILE'S OWN TEXT and so has
#     nothing to do with whether the feature exists.
#   * MT11's FOUR CONTROL ROWS, which are claims about the tree as it already
#     stands and not about the feature: route `T` still having no refusal reason
#     (the property that keeps S23's catalogue-wide click loop away from all 34 T
#     rows); the clickable set being the four route-T names that have a proc; the
#     two enum member lists really having been LIFTED out of their validators'
#     bodies, which is the non-vacuity guard for the drift row beside it; and
#     this band minting no temporary.  ⚠ A FIFTH row — "every member the dialog
#     offers is one the verb ACCEPTS" — is HALF vacuous today and says so in its
#     own output: its two non-member legs already read `refused`, and only its
#     member count is red, which is the direction that needs the feature.
#   * MT12's R402 inventory row, which drives no fixture and loads no database
#     at all, so nothing in it can mint a temporary whether `calc::fn_sink`
#     exists or not.  ⚠ IT IS THE ONLY ONE IN THAT BAND: MT12's `calc::arg_msg`
#     arm sweep carries non-vacuity legs that pass today, but the row as a whole
#     is RED because the arm the routing vocabulary requires does not exist, so
#     it is not in this list.
#   * MT1's TWO DERIVATION SELF-CHECKS, each named `DERIVATION SELF-CHECK` in its
#     own row name: they are arithmetic over this file's deck procs with no column
#     and no product in them, so no product change can redden either.  They assert
#     that the deck formulas have the property the behavioural bands' `distinct`
#     legs rely on.  Declared because they are the only rows here that are
#     tautological in the strict sense, and a reader is entitled to know which.
#
# Every other row outside MT0 and MT1 was observed FAILING before any of the
# three verbs existed, each naming the proc that is missing.
#
# ---------------------------------------------------------------------------
# ⚠ HOLES, DECLARED RATHER THAN PAPERED OVER.  Each of these is something this
# file does NOT measure, said plainly so nobody reads a green run as covering it.
# ---------------------------------------------------------------------------
#
#  H1 `riseTime` has NO DIRECTION ARGUMENT in the signature above, so it
#     measures a RISING transition and nothing else.  A fall time is therefore
#     unreachable and unfenced; whether it becomes a `fallTime` verb, a
#     direction argument, or falls out of `delay` is the next decision, not this
#     file's.
#  H2 AN INVERTED THRESHOLD PAIR (`pctlo` above `pcthi`) IS UNFENCED.  On a
#     monotone edge it yields a negative rise time, and nothing in
#     TIMING_CONTRACT says whether that is a refusal (a malformed request) or a
#     returned negative (T3's own reasoning, one verb over).  Deliberately not
#     guessed at: it is a single question for the user, and the row to write is
#     `riseTime` with `pctlo` 90 and `pcthi` 10 asserting whichever they rule.
#  H2b AN INVERTED SWING (`lo` above `hi`, which is a DIFFERENT argument pair from
#     H2's thresholds) IS UNFENCED, for the same reason and awaiting the same single
#     question: it is well formed arithmetic that names a falling transition, and
#     nothing in TIMING_CONTRACT says whether that is a refusal, a negative answer,
#     or the fall time H1 says is unreachable.
#  H3 `mt_duty_series`'s `NOFALL` arm — a period that opens and closes on rising
#     crossings with NO falling crossing between them — is UNREACHABLE through this
#     fixture, on EVERY column MT8 drives and not only on `v(sq)`: each period that
#     opens also closes with a falling crossing inside it, which is visible in the
#     series lengths MT8's rows assert against the rising-crossing counts in the same
#     rows.  The arm is written so the derivation cannot silently produce a wrong
#     number, and it is not a fence.
#  H4 THE `dataset` A VERB ACTUALLY READS IS NOW FENCED FOR ALL THREE, which is a
#     correction to an earlier revision of this list that claimed it was fenced for
#     `riseTime` only — and BOTH halves of that claim were wrong.  No `dutyCycle`
#     call passed a dataset argument at all, good or bad; and `riseTime`'s row
#     checked that the answer CARRIED the key, which a verb reporting `$dataset`
#     while passing 0 to every `cross` call satisfies.  Now each verb has a row
#     where the two datasets answer DIFFERENTLY — `v(div)` by disposition for
#     `riseTime` and `delay`, the square offset by the divider by value for
#     `dutyCycle` — and each is given a bad dataset too.  WHAT STAYS OPEN is the
#     `op` and `ac` plots: every dataset row here is on the `tran` read.
#  H5 THE DELEGATION CLAIM'S KNOWN GAP IS CLOSED, and this entry records what it
#     was: MT10's two halves used to catch a verb reading samples directly and a
#     verb not reaching `cross` at all, while a verb that called `cross` AND ALSO
#     read samples through some THIRD `::calc::` proc passed both.  `mt_calc_closure`
#     now walks the namespace transitively, stopping at `cross`, and `mt_closure_raw`
#     names every proc in the chain that reads samples — the derived-set treatment
#     row SR5 of test_calc_scratch_reuse uses, applied here instead of deferred to
#     it.  The same widening is what makes a shared period derivation legal, which
#     is the shape `frequency` and `period_jitter` will want.
#  H6 `mt_decomment` IS A HEURISTIC, not a Tcl parser: it drops comment-only
#     lines and a trailing comment whose preceding text is a complete script.
#     MT10's first row is its non-vacuity guard — it shows the instrument answers
#     `yes` for `calc::cross`, leaves a long body behind, and did remove
#     something — so a `no` below is evidence rather than an artefact of an empty
#     string.  It is not a guarantee against a pathological body.
#  H7 CROSS_CONTRACT D10's bulk read is UNFENCEABLE and stays so here: nothing
#     observable distinguishes a bulk read from a consistently per-point one
#     except low-order bits, and the `ac` sweep arm has no AC read in this
#     fixture.  Both are inherited from `cross` and neither is this file's to
#     close.
#  H7b `mt_direct_raw` NAMES FOUR `xschem raw` SUBCOMMANDS — `add`, `values`,
#     `value` and `del` — and a sample door it does not name is not caught.
#     `table_read` is the one that exists today.  The four are the evaluate-and-read
#     pair; `loaded`, `datasets`, `index`, `points` and `sim_type` are pre-flight and
#     are deliberately allowed, so this is a narrow list by design rather than an
#     oversight, but it IS a list and a list is the defect `test_snprintf_fmt_1608`
#     row X1 exists to warn about one level up.
#  H8 THREE DISPOSITIONS HERE ARE THIS FILE'S CHOICE AND NOT THE CONTRACT'S, and
#     the implementation stage may overrule any of them provided it does so out
#     loud.  (a) A ZERO SWING (`lo == hi`) is refused — D7's reasoning, not R415's
#     words.  (b) `nth` 0 on a side of `delay` DEFERS behind `cross`'s own
#     `listdefer` sentence; the contract requires neither that nor any other
#     disposition, so an implementer may pick none and ship the raise a conforming
#     reference reaches.  (c) MT10's stub probe requires the three verbs to CARRY
#     the stubbed `cross`'s sentence THROUGH rather than replacing it with one of
#     their own — which is how the row knows the refusal came back through `cross`,
#     but is a constraint on message composition that nothing else states.
#  H9 `calc::dutyCycle_scalar` CANNOT CARRY R420's X AXIS, and MT11's
#     surface-formals row is red for that reason as well as for the absent spec.
#     The wrapper is `{rpn level {cycle 0} {dataset 0}}` and forwards four
#     arguments; the measurement proc has `{xaxis start}` fifth.  So the
#     implementer must either give the wrapper the formal and forward it, or have
#     the result path call `calc::dutyCycle` directly — and this file does NOT
#     choose between those, because the row it writes is satisfied by both.
#     ⚠ WHAT IS NOT FENCEABLE HERE AT ALL: whether the axis the dialog collects
#     reaches the data.  For a NAMED cycle the axis changes only the answer's
#     parallel `sweep` key and R404 puts a bare NUMBER in the buffer, so nothing
#     observable at the surface moves with it; the wave case, where it would be
#     observable, defers.
#  H10 EVERY FIELD LABEL, AND `cross`'s AND `delay`'s DEFAULT EDGE, ARE
#     UNRATIFIED USER-VISIBLE TEXT.  The `rule` debt
#     `calc_argdialog_field_labels_and_delay_second_signal` covers them; MT11
#     pins each verb's whole field list in ONE row so that an overrule is a
#     one-row edit, and this entry is the declaration that a green run here is
#     not ratification.
#  H11 NOTHING IN THIS FILE TOUCHES THE DIALOG, THE CLICK, THE CANVAS GESTURE OR
#     THE GRAB.  Those are display-only by construction (CLICK_CONTRACT section
#     6) and live in band S28 of tests/headless/test_calc_skeleton.tcl and band
#     CW14 of tests/headless/test_calc_widgets.tcl, both `dcases` ALONE.  A green
#     `--nogui` run of this file therefore says NOTHING about whether a user can
#     reach any of the four verbs; it says only that the specification the dialog
#     will be built from is the ruled one.
#
# Standalone from the repo ROOT, headless.  NOT a bare `./src/xschem`, which
# inherits $DISPLAY and paints on the user's real screen:
#   env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script \
#       tests/headless/test_calc_measure.tcl
# or, gated and with a throwaway HOME, which is the armed spelling:
#   tests/headless/run_suites.sh --nogui test_calc_measure

source [file join [file dirname [info script]] scratch.tcl]

# ⚠ CAPTURED AT FILE SCOPE, NOT READ INSIDE THE PROC THAT NEEDS IT.  `mt_dictsites`
# walks this file's own text, and `info script` is only reliably this file while
# this file is being sourced -- a relative spelling resolved from a different cwd
# later would answer NOFILE and redden a correct run.  Normalised here, once.
set MTSELF [file normalize [info script]]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# any command, with a raise turned into a legible `ERR:` sentinel so the ROW
# fails instead of the band dying.  `mt_call` is the same idea for the product's
# own verbs, where "the proc does not exist yet" needs its own sentinel.
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
# THE ADAPTER.  `mt_call`, `mt_disp`, `mt_val`, `mt_msg`, `mt_key` and
# `mt_asanswer` — plus `mt_stub_run` further down, which CONSTRUCTS one of these
# answers rather than reading one.  The same enumeration the header gives, over
# the same keys, and deliberately a list rather than a number: see the header's
# warning, which is about two earlier revisions of THIS comment, the second of
# which was false because three ROW SITES built the dict inline.
# ---------------------------------------------------------------------------

# a value DERIVED BY THIS FILE, in the answer shape, so that a row comparing two
# of this file's own derivations can go through `mt_islist` instead of
# open-coding the representation at the row site.  THIS IS THE ONLY PLACE
# OUTSIDE `mt_stub_run` THAT MAY NAME THE KEYS, and MT10 has a row that derives
# the set of places which do and fails if it grows.
proc mt_asanswer {v} { return [dict create ok 1 absent 0 value $v msg {} dataset 0] }

# One call to one of the verbs, BY NAME.  Names what is MISSING rather than
# raising an `invalid command name` that says nothing about the row, and turns
# any raise from inside the product — a wrong arity included, which is exactly
# what a different signature would produce — into a legible sentinel so the row
# fails instead of the band dying.
proc mt_call {verb args} {
    if {[info commands ::calc::$verb] eq {}} { return "NOPROC:calc::$verb" }
    if {[catch {uplevel 1 [list ::calc::$verb {*}$args]} r]} { return "RAISED:$r" }
    return $r
}
# measured / absent / refused, or a sentinel naming why none of the three could
# be read.  Checked in this order because a sentinel string is not a dict and
# `dict exists` on one would be answering a different question.
proc mt_disp {a} {
    if {[string match NOPROC:* $a]} { return $a }
    if {[string match RAISED:* $a]} { return $a }
    if {[catch {dict size $a} n]} { return "NOTADICT:$a" }
    if {![dict exists $a ok]} { return "NOKEY-ok:$a" }
    if {[dict get $a ok] eq {1}} { return measured }
    if {![dict exists $a absent]} { return "NOKEY-absent:$a" }
    if {[dict get $a absent] eq {1}} { return absent }
    return refused
}
# the answer, or the LIST of answers for dutyCycle's default cycle.  Never
# raises: a non-measured answer yields its own disposition string, which a
# comparison against a number fails on legibly.
proc mt_val {a} {
    set d [mt_disp $a]
    if {$d ne {measured}} { return $d }
    if {![dict exists $a value]} { return "NOKEY-value:$a" }
    return [dict get $a value]
}
proc mt_msg {a} { return [mt_key $a msg] }
# one key of an answer, with the disposition substituted when the answer is not
# one of the three dispositions at all, so a missing key or a non-dict answer
# fails the row legibly instead of raising inside it.
proc mt_key {a k} {
    set d [mt_disp $a]
    if {$d ne {absent} && $d ne {refused} && $d ne {measured}} { return $d }
    if {![dict exists $a $k]} { return "NOKEY-$k" }
    return [dict get $a $k]
}

# ⚠⚠ `llength` AND `lindex` RAISE ON A STRING WHOSE FIRST CHARACTER AFTER A
# SPACE IS AN UNMATCHED OPEN BRACE.  Measured on Tcl 8.6.17 for the sibling
# suite, where six bands used to abort that way: a verb whose refusal sentence,
# or whose raise text arriving through `mt_call`'s `RAISED:` sentinel, carried
# one would take the rest of the enclosing band out through `group`'s catch.
# These two never raise, and a row that gets one of their sentinels instead of a
# number fails legibly on the comparison.
#
# THE CLAIM THEY ARE HERE TO MAKE TRUE, STATED NARROWLY SO IT IS CHECKABLE: no
# verb ANSWER is ever indexed or measured bare in this file.  It is deliberately
# NOT extended to the `mt_col` / `mt_addcol` columns that MT1 and MT4 index
# directly — those are "%.16g" numbers written by `xschem raw values`, which the
# verbs do not author, so the product cannot put a brace in them.
proc mt_len {v} { if {[catch {llength $v} n]} { return "NOTALIST:{$v}" } ; return $n }
proc mt_at {v i} { if {[catch {lindex $v $i} e]} { return "NOTALIST:{$v}" } ; return $e }
# a count claim that cannot raise on a sentinel, for the one row that asserts a
# lower bound rather than an exact number.
proc mt_atleast {v n} {
    if {![string is integer -strict $v]} { return "notacount:$v" }
    if {$v >= $n} { return "atleast$n" }
    return "only:$v"
}
# ⚠ `distinct` / `same` FOR EVERY ROW THAT HAS TO SHOW IT CAN TELL TWO CANDIDATE
# ANSWERS APART, AND THE REASON IS THE HOUSE RULE ABOUT NUMBERS IN ROW NAMES.
# A row saying "the answer is X and not the naive reading Y" has to assert
# something about Y, and the obvious spelling -- comparing `near`'s failure
# sentence against a literal -- embeds a REPRODUCIBLE NUMBER in the expectation
# and therefore in the T1 verdict, which is exactly what sank a sibling row
# named "half a grid step off every sample" (measured at 6.9e-18, false by ten
# orders of magnitude).  These two answer a WORD, re-derived every run, and they
# are a POSITIVE claim about the instrument's discrimination rather than an
# assertion that a wrong answer is absent.
proc mt_distinct {a b} {
    if {![mt_finite $a] || ![mt_finite $b]} { return "NOTANUMBER:{$a}|{$b}" }
    return [expr {[near $a $b $::MTTOL] eq {ok} ? {same} : {distinct}}]
}
# `named` for a destination a wired measurement verb minted, the value itself
# otherwise -- the word MT8 asserts once stage J's first unit stops deferring
# the default cycle.
#
# ⚠ A GLOB AND NOT A LITERAL, because `__calc_dest<N>` carries a namespace
# serial that advances with every destination any band built, so a literal name
# would be a figure this file's own band order moves.
#
# ⚠⚠ AND A PROC AND NOT A TERNARY AT THE ROW SITE, for the same reason
# `mt_distinct` is one: a braced `expr` whose false branch is a command
# substitution answering `NOKEY-db` raises *invalid bareword*, which `group`'s
# catch turns into an ABANDONED BAND rather than one failed row.
proc mt_destname {v} {
    if {[string match __calc_dest* $v]} { return named }
    return $v
}
# ...the same claim where the candidate is a whole LIST, which is dutyCycle's
# percent spelling.  Carries the disposition through, so a sentinel cannot
# satisfy it: an answer that is not measured answers its own disposition and
# never `distinct`.
proc mt_notlist {a exps} {
    if {[mt_disp $a] ne {measured}} { return [mt_disp $a] }
    return [expr {[mt_islist $a $exps] eq {ok} ? {same} : {distinct}}]
}

# ---------------------------------------------------------------------------
# agreement with a derived value.  See the header for why MTTOL is looser than
# the fixture's own headroom, and why each row derives its own discrimination
# instead of claiming one in its name.
# ---------------------------------------------------------------------------
set MTTOL 1e-7
# ⚠ GATED WITH THIS SUITE'S OWN `mt_finite`, NOT WITH `string is double
# -strict`, and that is a measured correction rather than a style choice.
# `string is double -strict` answers 1 for all four non-finite spellings — the
# exact reason `calc::eval_finite` exists at all — so a measured `nan` would get
# past the guard and then RAISE out of the subtraction below, aborting the
# enclosing band through `group`'s catch instead of failing one row.  `inf` does
# not raise; it answers a relative error of Inf and compares false, which is
# the kind of half-working guard that survives review.
# The EXPECTED side is gated too, and with its OWN sentinel, so a broken
# derivation is distinguishable from a broken answer rather than silently
# becoming one.
proc near {got exp tol} {
    if {![mt_finite $got]} { return "NOTANUMBER:{$got}" }
    if {![mt_finite $exp]} { return "BADEXPECTED:{$exp}" }
    if {$exp == 0.0} {
        if {abs($got) <= $tol} { return ok }
        return "off:{$got} abs=[expr {abs($got)}]"
    }
    set r [expr {abs(($got - $exp) / double($exp))}]
    if {$r <= $tol} { return ok }
    return "off:{$got} rel=$r"
}
# a whole answer against one derived value.  `ok` or a sentence saying what went
# wrong, which is what the row compares, so a missing verb prints
# NOPROC:calc::riseTime rather than a bare mismatch.
proc mt_is {a exp} { return [near [mt_val $a] $exp $::MTTOL] }
# ...and against a LIST of derived values, element by element, reporting the
# count FIRST because a wrong count is a different defect from a wrong value —
# and for dutyCycle it is specifically the trailing-partial-period defect.
#
# ⚠ `mt_len` / `mt_at` on the ANSWER, bare `llength` / `lindex` on the EXPECTED,
# and the asymmetry is the point: the guard is for what the PRODUCT supplies.
proc mt_islist {a exps} {
    if {[mt_disp $a] ne {measured}} { return [mt_disp $a] }
    set v [mt_val $a]
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n != [llength $exps]} { return "count=$n want=[llength $exps] got={$v}" }
    set bad {}
    for {set i 0} {$i < $n} {incr i} {
        set r [near [mt_at $v $i] [lindex $exps $i] $::MTTOL]
        if {$r ne {ok}} { lappend bad "\[$i\]$r" }
    }
    if {[llength $bad]} { return [join $bad { }] }
    return ok
}
# the house refusal shape, measured off `calc::eval_msg`, `calc::plot_msg` and
# `calc::cross_msg`: leading verb, colon, one full sentence, a full stop.  The
# WORDS are never asserted — they are unratified user-visible wording and the
# `rule` debt filed against `calc::eval_msg`'s sentences covers these too.
proc mt_shape {s} {
    if {$s eq {}} { return empty }
    if {![regexp {^[A-Z]} $s]} { return "nocapital:$s" }
    if {![regexp {: } $s]} { return "nocolon:$s" }
    if {![string match {*.} $s]} { return "nofullstop:$s" }
    return ok
}

# ---------------------------------------------------------------------------
# DERIVATION 1 — FROM THE DECK.  Closed-form arithmetic, per the header: the
# square's two edges, the supplied-swing threshold, the rise time and the duty
# fraction they imply, the inversion identity, and the divider's per-dataset ramp.
# ---------------------------------------------------------------------------
proc sq_rise {L k} { return [expr {(0.9 + 0.2*double($L) + 4.0*$k) * 1e-3}] }
proc sq_fall {L k} { return [expr {(2.3 - 0.2*double($L) + 4.0*$k) * 1e-3}] }
# the threshold a supplied swing and a percentage name.  R415's whole content in
# one line: percentages OF THE SUPPLIED SWING, with no reference to the trace.
proc sq_thr {lo hi p} {
    return [expr {double($lo) + double($p)/100.0*(double($hi) - double($lo))}]
}
# `v(sq)`'s edges are 0.2 ms wide and linear, so the time between two thresholds
# on one edge is 0.2 ms times their separation.
proc sq_rt {lo hi plo phi} {
    return [expr {0.2e-3*([sq_thr $lo $hi $phi] - [sq_thr $lo $hi $plo])}]
}
# high time fall(L) - rise(L) = 1.4 - 0.4L ms over a 4 ms rising-to-rising
# period.  LEVEL-DEPENDENT, which is the half the brief's 0.30 sentence drops.
proc sq_duty {L} { return [expr {(1.4 - 0.4*double($L))/4.0}] }
# `1 v(sq) -` crosses L exactly where `v(sq)` crosses 1-L, with the direction
# flipped.  Stated as that identity rather than as a second trapezoid, because
# the identity is checkable by eye and a second table is not.
proc inv_fall {L k} { return [sq_rise [expr {1.0 - double($L)}] $k] }
proc inv_rise {L k} { return [sq_fall [expr {1.0 - double($L)}] $k] }
# the DATASET DISCRIMINATOR's deck relation, so the dataset rows in MT2 and MT5
# have a second derivation as well.  `v(ramp)` is PWL(0 0 10m 10) and therefore
# carries the time in MILLISECONDS as its value, and the README's own table makes
# `v(div)` `v(ramp)/2` in dataset 0 and `v(ramp)/4` in dataset 1 -- so `v(div)`
# reaches the level L at L*2 ms and at L*4 ms respectively, exactly.
proc div_t {L {ds 0}} {
    return [expr {double($L) * ($ds == 0 ? 2.0 : 4.0) * 1.0e-3}]
}

# ---------------------------------------------------------------------------
# THE GLITCH COLUMN that band MT4 needs, and WHY it is synthetic.
#
# T2's rule — find the low crossing for the requested occurrence, THEN take the
# first high crossing strictly after it — and the naive reading — take the nth
# crossing at each level independently — AGREE on `v(sq)`, at every level, at
# every occurrence.  They have to: `v(sq)` has three rising edges and every
# level in (0, 1) is crossed once per edge, so the two readings count the same
# crossings.  A band written against `v(sq)` alone would pass a naive
# implementation, which is the one thing T2 exists to catch.
#
# So MT4 drives a column built through the ENGINE out of `v(ramp)`, which is
# PWL(0 0 10m 10) and therefore carries the time in milliseconds as its value.
# `mt_tri` is one triangular bump, max(0, H*(1 - |t_ms - C|/HW)), written in the
# RPN the engine already has — `max()` returns the GREATER operand (spec §3.2,
# corrected against `case MAX` in src/save.c), so `0 <expr> max()` is a floor at
# zero.  `mt_glitch` is the maximum of the bumps in its own table, chosen so that the LOW
# threshold and the HIGH threshold are crossed a DIFFERENT NUMBER OF TIMES and
# in an interleaving the naive reading gets wrong:
#
#   * a half-height bump at 1.0 ms crosses the low threshold and never reaches
#     the high one — a false start, which is the shape TIMING_CONTRACT T2
#     describes as "a ringing edge can cross the low threshold three times
#     before crossing the high one once";
#   * three overlapping full-height bumps at 3.0 / 3.8 / 4.6 ms dip between
#     their peaks to a value BELOW the high threshold and ABOVE the low one, so
#     the high threshold is crossed three times inside ONE low-threshold
#     excursion;
#   * one clean full-height bump at 7.0 ms, well clear of the rest.
#
# ⚠ EVERY NUMBER MT4 ASSERTS IS DERIVED FROM THAT COLUMN AT RUN TIME, and the
# crossing STRUCTURE its rows depend on is asserted by a row too — MT1's for the
# glitch column, and MT4's own for the false-start column it builds in place —
# because a comment claiming "three low crossings and four high ones" is exactly
# the sort of figure that rots, and the engine is free to disagree with the
# arithmetic above it.  The bump centres and half-widths are all multiples of the
# 0.1 ms grid, so the sampled column is an exact piecewise-linear reading of the
# continuous shape; the LEVELS, 12 % and 88 % of a 0 .. 1 swing, are chosen so
# that no crossing lands on a sample.
#
# ⚠ MT4 BUILDS A SECOND COLUMN OUT OF THE SAME `mt_tri`, for T2's OTHER absence:
# one full-height bump followed by a HALF-height one, so the LAST low-threshold
# excursion has NO high crossing after it.  The glitch column cannot produce that
# — its last bump is full height — and perturbing the glitch table to produce it
# would have moved the counts MT1 asserts and made MT4's own "occurrence beyond
# the low crossings" row pass for a different reason, which is trap 7.  A second
# column costs two engine calls and keeps the two absences separable.
# ---------------------------------------------------------------------------
proc mt_tri {c hw h} { return "0 1 v(ramp) $c - abs() $hw / - $h * max()" }
proc mt_glitch {} {
    set parts {}
    foreach {c hw h} {1.0 0.5 0.5   3.0 1.0 1.0   3.8 1.0 1.0
                      4.6 1.0 1.0   7.0 1.0 1.0} {
        lappend parts [mt_tri $c $hw $h]
    }
    set e [lindex $parts 0]
    foreach p [lrange $parts 1 end] { append e " $p max()" }
    return $e
}

# ---------------------------------------------------------------------------
# the fixture, and DERIVATION 2 — this suite's own D3 + D4
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
# also been read as `op` lands back on the OP slot, where a row then reads a
# wrong DATABASE as if it were a wrong number.
proc mt_load {{ty tran}} {
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
# R402's watch.  `__calc_tmp*` is the product's prefix; `__mt_*` is this file's
# own probe prefix, watched separately so a probe that forgot to clean up is
# reported as a SUITE defect and never as a product leak.
proc leaked {} {
    set out {}
    foreach n [rawnames] { if {[string match -nocase __calc_tmp* $n]} { lappend out $n } }
    return $out
}
proc probeleft {} {
    set out {}
    foreach n [rawnames] { if {[string match -nocase __mt_* $n]} { lappend out $n } }
    return $out
}
# one column, as a Tcl list, or a sentinel.  THE BULK DOOR, "%.16g", and the
# only door any comparand in this file comes from.
proc mt_col {name dset} {
    if {[catch {xschem raw values $name $dset} v]} { return "ERR:$v" }
    return [string trim $v]
}
# build one derived column through the engine, read it back, and delete it.  The
# name is NOT `__calc_tmp<N>`: that prefix belongs to R402 and `leaked` watches
# it, so a probe borrowing it would make every cleanup row lie.
proc mt_addcol {name expr dset} {
    catch {xschem raw del $name}
    if {[catch {xschem raw add $name $expr} rc]} { return "ERR:$rc" }
    set v [mt_col $name $dset]
    catch {xschem raw del $name}
    return $v
}
# ⚠ THIS SUITE'S OWN finiteness test, deliberately NOT a call to
# `calc::eval_finite`: the derivations in MT1 and MT4 must not stop working
# because the product proc they are used to check was renamed, and a suite that
# called it would be measuring that proc against itself.
#
# ⚠ BUT IT IS NOT *INDEPENDENT* EVIDENCE.  The regexp below is a byte-identical
# copy of `calc::eval_finite`'s, so a wrong pattern is wrong identically in both
# places and MT0's agreement row would still be green.  What this buys is a
# CHANGE DETECTOR — if either copy is edited, MT0 reddens and names the spelling
# they disagree on — and decoupling from the product's call graph.  It does not
# buy a second opinion, and no row below may be read as if it did.
proc mt_finite {v} {
    return [regexp {^-?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} [string trim $v]]
}
# CROSS_CONTRACT D3 + D4, in the order D6 requires: the finiteness gate FIRST,
# then the predicate, then the division — which cannot have a zero denominator
# once the predicate holds, because the predicate puts the endpoints strictly on
# opposite sides of L.  Returns `<dir> <x>` pairs in sweep order.
proc mt_derive {xs ys L edge} {
    set out {}
    set n [llength $ys]
    for {set p 1} {$p < $n} {incr p} {
        set y0 [lindex $ys [expr {$p-1}]] ; set y1 [lindex $ys $p]
        if {![mt_finite $y0] || ![mt_finite $y1]} continue
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
# the X values only, which is what a row compares against a verb's answer.
proc mt_derive_x {xs ys L edge} {
    set out {}
    foreach {d x} [mt_derive $xs $ys $L $edge] { lappend out $x }
    return $out
}
# `ok <x> <xleft> <xright>` for the k-th crossing, so a row can ask where in its
# straddling pair a crossing falls instead of asserting it in a name.
proc mt_bracket {xs ys L edge k} {
    set hits [mt_derive_x $xs $ys $L $edge]
    if {[llength $hits] <= $k} { return [list NOCROSSING {} {} {}] }
    set x [lindex $hits $k]
    set n [llength $xs]
    set p 0
    for {set i 1} {$i < $n} {incr i} {
        if {[lindex $xs $i] >= $x} { set p $i ; break }
    }
    if {$p < 1} { return [list NOPAIR $x {} {}] }
    return [list ok $x [lindex $xs [expr {$p-1}]] [lindex $xs $p]]
}
# `rejected rejected rejected` per snapping convention, in the order snap-DOWN,
# snap-UP, snap-to-NEAREST — asked of this file's OWN `near` at MTTOL, so the
# answer is about the instrument the behavioural rows actually use and not about
# an argument.  R414d, inherited through `cross`, requires all three rejected.
proc mt_snaps {xs ys L edge k} {
    lassign [mt_bracket $xs $ys $L $edge $k] st x xl xr
    if {$st ne {ok}} { return $st }
    set nearest [expr {($x - $xl) < ($xr - $x) ? $xl : $xr}]
    set out {}
    foreach cand [list $xl $xr $nearest] {
        lappend out [expr {[near $cand $x $::MTTOL] eq {ok} ? {accepted} : {rejected}}]
    }
    return $out
}
# the four DIFFERENCES a snapping implementation could report for one rise time,
# each asked of `near` against the interpolated truth.  R414d's consequence for
# a verb that subtracts two crossings, stated as the enumeration rather than as
# a claim in a row name.
proc mt_snapdiffs {xs ys Llo Lhi k} {
    lassign [mt_bracket $xs $ys $Llo rising $k] s1 x1 l1 r1
    lassign [mt_bracket $xs $ys $Lhi rising $k] s2 x2 l2 r2
    if {$s1 ne {ok}} { return "lo:$s1" }
    if {$s2 ne {ok}} { return "hi:$s2" }
    set truth [expr {$x2 - $x1}]
    set out {}
    foreach a [list $l2 $r2] {
        foreach b [list $l1 $r1] {
            lappend out [expr {[near [expr {$a - $b}] $truth $::MTTOL] eq {ok}
                               ? {accepted} : {rejected}}]
        }
    }
    return $out
}
# T2's two readings, side by side, over one column.  `correct` is the first HIGH
# crossing strictly after the n-th LOW crossing; `naive` is the n-th HIGH
# crossing.  Returns `<lox> <correctx> <naivex>` with the literal word NONE for
# a reading that has no answer, which is what band MT1 prints so MT4's rows are
# demonstrably non-vacuous rather than claimed to be.
proc mt_t2 {xs ys Llo Lhi n} {
    set los [mt_derive_x $xs $ys $Llo rising]
    set his [mt_derive_x $xs $ys $Lhi rising]
    if {[llength $los] < $n} { return [list NONE NONE NONE] }
    set lox [lindex $los [expr {$n-1}]]
    set correct NONE
    foreach h $his { if {$h > $lox} { set correct $h ; break } }
    set naive NONE
    if {[llength $his] >= $n} { set naive [lindex $his [expr {$n-1}]] }
    return [list $lox $correct $naive]
}
# the rise time each of those two readings would report, or NONE.
proc mt_t2_rt {xs ys Llo Lhi n which} {
    lassign [mt_t2 $xs $ys $Llo $Lhi $n] lox correct naive
    set h [expr {$which eq {correct} ? $correct : $naive}]
    if {$lox eq {NONE} || $h eq {NONE}} { return NONE }
    return [expr {$h - $lox}]
}
# dutyCycle's own arithmetic, derived here so MT8 compares a verb's answer
# against something computed WITHOUT the verb: a period is one rising crossing
# to the NEXT rising crossing, the high time is the falling crossing inside it
# minus the opening rising one, and a trailing rising crossing with no rising
# crossing after it opens NO period and is EXCLUDED.
proc mt_duty_series {xs ys L} {
    set rs [mt_derive_x $xs $ys $L rising]
    set fs [mt_derive_x $xs $ys $L falling]
    set out {}
    set nr [llength $rs]
    for {set i 0} {$i < $nr - 1} {incr i} {
        set r0 [lindex $rs $i] ; set r1 [lindex $rs [expr {$i+1}]]
        set hi NONE
        foreach f $fs { if {$f > $r0 && $f < $r1} { set hi $f ; break } }
        if {$hi eq {NONE}} { lappend out NOFALL ; continue }
        lappend out [expr {($hi - $r0)/($r1 - $r0)}]
    }
    return $out
}

# ---------------------------------------------------------------------------
# BAND MT9c's DERIVATIONS AND INSTRUMENTS -- stage J unit J2, `riseTime`'s
# per-edge rise time SERIES.  Every one answers a WORD or a list this file
# re-derives, never a reproducible number, and every one is a PROC rather than
# an expression written at the row site: a braced `expr` whose branch is a
# command substitution answering a sentinel raises *invalid bareword*, which
# `group`'s catch turns into an ABANDONED BAND rather than one failed row.
# ---------------------------------------------------------------------------

# the element-wise product of two columns, computed IN TCL and never through the
# engine -- so a row comparing `riseTime`'s series against a derivation over
# `{v(sq) v(ramp) *}` is not comparing the engine against itself.  Measured on
# this fixture: the engine's own product column and this one agree to a relative
# 4.0e-16 over all 101 samples, which is nine orders inside MTTOL, and band MT9c
# asserts that agreement in the run rather than here in prose.
proc mt_prod {a b} {
    if {[string match ERR:* $a]} { return $a }
    if {[string match ERR:* $b]} { return $b }
    if {[catch {llength $a} na]} { return "NOTALIST:{$a}" }
    if {[catch {llength $b} nb]} { return "NOTALIST:{$b}" }
    if {$na != $nb} { return "LENMISMATCH:$na|$nb" }
    set out {}
    foreach x $a y $b {
        if {![mt_finite $x] || ![mt_finite $y]} { return "NOTANUMBER:{$x}|{$y}" }
        lappend out [expr {double($x) * double($y)}]
    }
    return $out
}
# THE PER-EDGE RISE TIME SERIES, derived from two columns with no verb in it:
# one rise time per LOW crossing that HAS a high crossing after it, with X the
# low crossing itself -- which is R420's own default choice for `dutyCycle` ("the
# time the cycle started") read across to a transition.
#
# Answers `{<X> <Y> <nlow> <nhigh>}`, and the two counts ride along so a row can
# assert that a point was DROPPED -- `nlow` greater than the series length --
# rather than that the fixture only ever had that many edges.  That is the
# difference between a fence and a fixture property.
proc mt_rt_derive {xs ys lo hi plo phi} {
    if {[regexp {^(ERR|NOTALIST|LENMISMATCH|NOTANUMBER):} $ys]} {
        return [list $ys $ys $ys $ys]
    }
    if {[regexp {^(ERR|NOTALIST|LENMISMATCH|NOTANUMBER):} $xs]} {
        return [list $xs $xs $xs $xs]
    }
    set sw [expr {double($hi) - double($lo)}]
    if {$sw == 0.0} { return [list ZEROSWING ZEROSWING ZEROSWING ZEROSWING] }
    set llo [expr {double($lo) + double($plo)/100.0*$sw}]
    set lhi [expr {double($lo) + double($phi)/100.0*$sw}]
    set los [mt_derive_x $xs $ys $llo rising]
    set his [mt_derive_x $xs $ys $lhi rising]
    set rx {} ; set ry {}
    foreach a $los {
        set b {}
        foreach h $his {
            if {$h > $a} { set b $h ; break }
        }
        if {$b eq {}} continue
        lappend rx $a
        lappend ry [expr {$b - $a}]
    }
    return [list $rx $ry [llength $los] [llength $his]]
}
proc mt_rt_get {d i} { if {[catch {lindex $d $i} v]} { return "NODERIV:{$d}" } ; return $v }
proc mt_rt_x   {d} { return [mt_rt_get $d 0] }
proc mt_rt_y   {d} { return [mt_rt_get $d 1] }
proc mt_rt_nlo {d} { return [mt_rt_get $d 2] }
proc mt_rt_nhi {d} { return [mt_rt_get $d 3] }
# the two absolute thresholds a supplied swing and two percentages name, so a
# row can drive `calc::cross` at the SAME levels the verb will and compare the
# verb's X against `cross`'s own answer rather than against a second derivation.
proc mt_rt_thr {lo hi p} { return [sq_thr $lo $hi $p] }

# ⚠⚠ A SIGNAL WHOSE HIGH THRESHOLD IS CROSSED MORE OFTEN THAN ITS LOW ONE,
# WHICH IS THE ONLY SHAPE THAT CAN SEE WHICH WAY A PRODUCER PAIRED THE TWO
# CROSSING LISTS -- and the committed columns do not have it.  A rise time is
# one measurement per RISING EDGE, so the series must be driven from the LOW
# crossings, pairing each with the first high crossing after it.  A producer
# that drove the HIGH list instead, pairing each high with the last low before
# it, answers one point per COMPLETED TRANSITION: it keeps X a low crossing,
# keeps Y a high-minus-low difference, drops the same points, and reaches the
# same absence -- so every leg the band had before this one is green on it.
# MEASURED: on `{v(sq) v(ramp) *}` at 10/90 the low list is
# `{9.2e-4 4.904e-3 8.902e-3}` and the high list `{1.07e-3 4.936e-3 8.92e-3}`,
# which INTERLEAVE strictly one for one, and under strict 1:1 interleaving the
# two pairing directions are provably THE SAME LIST.  The partial-drop request
# cannot separate them either, and for a structural reason: a dropped point is
# always a SUFFIX of the low list, because if `low[i]` has no high crossing
# after it then no later low crossing has one either.
#
# So the band mints a signal that RINGS at the top: one rising edge per period
# whose high threshold is crossed TWICE, which is the commonest real transient
# there is.  `-(sin x + sin 3x / 2)` has a double-humped positive half with a
# dip between the humps, and an antisymmetric negative half whose own dip would
# add a second LOW crossing per period -- so the negative half is clamped at a
# floor ABOVE that dip, which merges the whole sub-threshold region into one
# flat block and leaves exactly one rising crossing of the low level per period.
# The floor doubles as the request's own `lo`, which is what the signal's low
# rail is.  The angular frequency is read back from the sweep column's OWN
# endpoints every run, so no period is written down anywhere -- `wd_acrpn`'s
# discipline in the sibling suite, for the same reason.
proc mt_ringfloor {} { return -0.3 }
proc mt_ringw {xs n} {
    set m [mt_len $xs]
    if {![string is integer -strict $m]} { return $m }
    if {$m < 2} { return "NOSPAN:$m" }
    set a [mt_at $xs 0]
    set b [mt_at $xs end]
    if {![mt_finite $a] || ![mt_finite $b]} { return "NOTANUMBER:{$a}|{$b}" }
    set s [expr {double($b) - double($a)}]
    if {$s <= 0.0} { return "NOSPAN:$s" }
    return [expr {double($n) * 2.0 * 3.141592653589793 / $s}]
}
proc mt_ringrpn {xs n} {
    set w [mt_ringw $xs $n]
    if {![mt_finite $w]} { return $w }
    set w3 [expr {3.0 * $w}]
    return "0 time $w * sin() - time $w3 * sin() 0.5 * - [mt_ringfloor] max()"
}
proc mt_ringcol {xs n} {
    set w [mt_ringw $xs $n]
    if {![mt_finite $w]} { return $w }
    set f [mt_ringfloor]
    set out {}
    foreach t $xs {
        if {![mt_finite $t]} { return "NOTANUMBER:{$t}" }
        set v [expr {-(sin($w * double($t)) + 0.5 * sin(3.0 * $w * double($t)))}]
        if {$v < $f} { set v $f }
        lappend out $v
    }
    return $out
}
# `atleast<n>` for the EXCESS of one count over another, through a proc rather
# than a braced `expr` at the row site: either count can be a sentinel, and a
# command substitution answering one inside `expr` raises *invalid bareword*,
# which `group`'s catch turns into an ABANDONED BAND rather than one failed row.
proc mt_excess {a b n} {
    if {![string is integer -strict $a]} { return "notacount:{$a}" }
    if {![string is integer -strict $b]} { return "notacount:{$b}" }
    return [mt_atleast [expr {$a - $b}] $n]
}
# `nodup` when no two elements of a series are the same value, and the two
# counts otherwise.  It is the ONE X-axis claim that is non-vacuous at any
# length, which `mt_increasing` and `mt_alldistinct` are not: both answer
# `tooshort:1` on a one-point series, and a wrong pairing direction can produce
# several points at ONE X where the truth is a single point.
proc mt_nodup {v} {
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n < 1} { return "tooshort:$n" }
    set u [llength [lsort -unique $v]]
    if {$u == $n} { return nodup }
    return "dup:$u-of-$n"
}
# `nonneg` when every element of a series is a finite number that is not
# negative, and the offending elements, INDEXED AND WITH THEIR VALUES, otherwise.
#
# ⚠ A RISE TIME CANNOT BE NEGATIVE, AND UNTIL THIS PROC NOTHING IN THE TREE SAID
# SO.  In the shipped implementation Y is positive by construction -- it is
# `$xh - $x0` where the loop guard has already proved `$xh > $x0` -- so the claim
# is free, and a free claim about the answer's own SHAPE is worth more than the
# element-wise comparisons it sits beside: those compare against a derivation
# this file computes, and would go quiet if the fixture or the derivation moved.
# Derived over the ANSWER's own list and answering a WORD, for the reason
# `mt_atleast`, `mt_nodup` and `mt_distinct` do: a row naming a number embeds a
# reproducible figure in the T1 verdict.
#
# ⚠ WHICH SABOTAGE EACH PLACEMENT OF THIS LEG ACTUALLY CATCHES, MEASURED RATHER
# THAN ASSUMED, because they are NOT the same and a reader would reasonably
# expect them to be.  Hoisting `set xh {}` out of `calc::riseTime`'s `foreach x0`
# body makes an edge with no high crossing after it INHERIT the previous edge's
# high crossing, which emits a negative Y -- but ONLY on a request where a point
# DROPS, so the partial-drop row is the only placement that sees it, and the
# whole of tests/headless/test_calc_wave_dest.tcl stays green under that
# mutation.  Flipping the subtraction to `$x0 - $xh` negates EVERY point of
# EVERY series instead, and that is what reddens this leg on the keystone rows
# of both suites.  So neither placement subsumes the other, which is why the
# leg sits on the keystone AND on the row that drops a point.
proc mt_nonneg {v} {
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n < 1} { return "tooshort:$n" }
    set bad {}
    for {set i 0} {$i < $n} {incr i} {
        set e [mt_at $v $i]
        if {![mt_finite $e]} { lappend bad "\[$i\]notanumber:$e" ; continue }
        if {$e < 0} { lappend bad "\[$i\]neg:$e" }
    }
    if {[llength $bad]} { return [join $bad { }] }
    return nonneg
}
# `samefamily` when two sentences share the word before their first colon, and
# both families otherwise.  `mt_notfamily` is the negative claim and answers
# `samefamily:<family>` when they agree, which puts a user-visible word in a
# row's EXPECTATION -- so this one exists for the POSITIVE claim, where the
# expectation must survive the `rule` debt filed against the wording.
proc mt_samefamily {a b} {
    if {[mt_family $a] eq [mt_family $b]} { return samefamily }
    return "differ:[mt_family $a]|[mt_family $b]"
}

# element-wise agreement for a PLAIN list -- a column read back, or a key of an
# answer that is not `value`.  `mt_islist` is the same comparison for a whole
# ANSWER and carries the disposition; this one is for the lists that travel
# beside it.  The COUNT is reported first because a wrong count is a different
# defect from a wrong value.
proc mt_listcmp {v exps {tol {}}} {
    if {$tol eq {}} { set tol $::MTTOL }
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n != [llength $exps]} { return "count=$n want=[llength $exps] got={$v}" }
    set bad {}
    for {set i 0} {$i < $n} {incr i} {
        set r [near [mt_at $v $i] [lindex $exps $i] $tol]
        if {$r ne {ok}} { lappend bad "\[$i\]$r" }
    }
    if {[llength $bad]} { return [join $bad { }] }
    return ok
}
# `same` / `distinct` for two whole LISTS, which is what a row showing it can
# tell a correct fill from a plausible wrong one must assert -- and it answers a
# WORD so no reproducible number lands in the T1 verdict.  A SENTINEL is carried
# through rather than collapsed into `distinct`: a missing key really is
# distinct from the expected list, and answering so would hide WHY behind a word
# that reads like a measurement.
proc mt_cmpword {v exps {tol {}}} {
    if {[regexp {^(NOPROC|RAISED|NOTADICT|NOKEY|NOTALIST|ERR|NODERIV|LENMISMATCH|NOTANUMBER|ZEROSWING):} $v]} { return $v }
    if {[mt_listcmp $v $exps $tol] eq {ok}} { return same }
    return distinct
}
# the words `mt_distinct` answers for every ADJACENT pair of a series,
# `lsort -unique`d, so the answer is `distinct` only when EVERY neighbour
# differs by more than MTTOL.
#
# ⚠⚠ THIS IS THE LEG THAT MAKES AN ELEMENT-WISE COMPARISON MEAN ANYTHING, AND
# THE MEASUREMENT BEHIND IT IS WHY BAND MT9c DRIVES NEITHER OBVIOUS COLUMN.
# `riseTime`'s per-edge series on `v(sq)` has all three edges agreeing to a
# RELATIVE 4.5e-14, because the square is periodic and every edge has the same
# width; on `v(lp)` the last two agree to 2.2e-11, because the pole is in
# periodic steady state after the first edge.  Both are inside MTTOL, so on
# either column a Y written backwards, or filled with its own first element,
# passes an element-wise comparison -- which is issue 1643's finding arriving at
# a different verb.  The band's own control row asserts that this instrument can
# still answer `same`, over `v(sq)`, so the `distinct` above it is a measurement
# and not a constant.
proc mt_alldistinct {v} {
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n < 2} { return "tooshort:$n" }
    set out {}
    for {set i 1} {$i < $n} {incr i} {
        lappend out [mt_distinct [mt_at $v [expr {$i - 1}]] [mt_at $v $i]]
    }
    return [lsort -unique $out]
}
# `increasing` / `notincreasing:<i>` over a series.  With THREE points this is
# two comparisons and not one, so a middle value out of order is a shape of its
# own -- which is exactly what a two-point series cannot have.
proc mt_increasing {v} {
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n < 2} { return "tooshort:$n" }
    for {set i 1} {$i < $n} {incr i} {
        set a [mt_at $v [expr {$i - 1}]]
        set b [mt_at $v $i]
        if {![mt_finite $a] || ![mt_finite $b]} { return "notanumber:$i" }
        if {$b <= $a} { return "notincreasing:$i" }
    }
    return increasing
}
# THE WRONG FILLS A REASONABLE PERSON WRITES, built FROM the correct series so
# they cannot drift away from it.  `mt_rot1` is a rotation by one; `mt_midmean`
# replaces the MIDDLE element with the mean of the two endpoints, which is what
# a producer that filled only the ends and interpolated would write; `mt_midleft`
# replaces it with its left neighbour, which is a dropped middle sample whose
# COUNT survives.  The last two exist only at three points or more, and that is
# the whole of what J2's third point buys over J1's two: `lreverse` and `mt_rot1`
# are THE SAME LIST at two points, and a middle element does not exist there at
# all.  The band asserts both of those in the run.
proc mt_rot1 {v} {
    if {[catch {llength $v} n]} { return "NOTALIST:{$v}" }
    if {$n < 2} { return $v }
    return [concat [lrange $v 1 end] [list [lindex $v 0]]]
}
proc mt_midmean {v} {
    if {[catch {llength $v} n]} { return "NOTALIST:{$v}" }
    if {$n < 3} { return "tooshort:$n" }
    set m [expr {($n - 1) / 2}]
    return [lreplace $v $m $m [expr {([lindex $v 0] + [lindex $v end]) / 2.0}]]
}
proc mt_midleft {v} {
    if {[catch {llength $v} n]} { return "NOTALIST:{$v}" }
    if {$n < 3} { return "tooshort:$n" }
    set m [expr {($n - 1) / 2}]
    return [lreplace $v $m $m [lindex $v [expr {$m - 1}]]]
}
# an answer's key set, sorted, sentinel-safe -- band WD11 of the sibling suite
# chose the destination's key set and this is the same instrument for the half
# that lives here.
proc mt_keys {a} {
    set d [mt_disp $a]
    if {$d ne {absent} && $d ne {refused} && $d ne {measured}} { return $d }
    if {[catch {dict keys $a} k]} { return "NOTADICT:$a" }
    return [lsort $k]
}
# THE SENTENCE FAMILIES `calc::cross_msg` BUILDS, DERIVED FROM THE ARM SET IN
# ITS OWN `switch` ARGUMENT and never listed here.  A hand-kept list is the same
# defect one level up, and this batch has already shipped one that rotted to 24
# of 31 arms while staying green.
#
# ⚠ A FAMILY -- the word before the first colon -- IS THE ONLY PART OF THESE
# SENTENCES A ROW MAY LEAN ON.  The words are unratified user-visible wording
# covered by the `rule` debt filed against `calc::eval_msg`'s sentences, and the
# wording for an EMPTY measured series is filed separately
# (`calc_wave_dest_empty_result_sentence`).  So band MT9c asserts that an
# absence's sentence is in a family this proc really builds and is NOT in
# `destempty`'s family, which is the claim the driver's call actually makes: an
# absence is not an error and must not be reported as a destination problem.
# Whichever arm the implementation reuses, and whatever the ruling later says,
# no row here moves.
proc mt_crossmsg_arms {} {
    if {[info commands ::calc::cross_msg] eq {}} { return "NOPROC:calc::cross_msg" }
    set b [pcall info body ::calc::cross_msg]
    if {[string match ERR:* $b]} { return "NOBODY:calc::cross_msg" }
    set out {}
    foreach ln [split [mt_decomment $b] "\n"] {
        if {[regexp {^[ \t]*([a-z][a-zA-Z0-9_]*)[ \t]+\{[ \t]*return} $ln -> nm]} {
            lappend out $nm
        }
    }
    return [lsort -unique $out]
}
proc mt_family {s} {
    if {[regexp {^([^:]+):} $s -> f]} { return $f }
    return "NOFAMILY:{$s}"
}
proc mt_crossmsg_families {} {
    set arms [mt_crossmsg_arms]
    if {[regexp {^(NOPROC|NOBODY):} $arms]} { return $arms }
    set out {}
    foreach a $arms {
        set s [pcall ::calc::cross_msg $a AAA BBB]
        if {[string match ERR:* $s]} { lappend out "ERR:$a" ; continue }
        lappend out [mt_family $s]
    }
    return [lsort -unique $out]
}
proc mt_infamily {s fams} {
    if {[catch {llength $fams}]} { return "NOTALIST:{$fams}" }
    if {[lsearch -exact $fams [mt_family $s]] >= 0} { return known }
    return "unknown:[mt_family $s]"
}
proc mt_notfamily {s other} {
    if {[mt_family $s] eq [mt_family $other]} { return "samefamily:[mt_family $s]" }
    return elsewhere
}
# the SURFACE proc a click reaches, and the formals it will be called with --
# `calc::arg_values` walks `info args` of that proc in FORMAL order, `break`s at
# the first formal it has no value for, and `calc::arg_invoke` then appends the
# values POSITIONALLY.  So a formal the dialog cannot answer, placed anywhere
# but LAST, TRUNCATES the call silently and every formal after it falls back to
# its own default.  `mt_ordinal_delivered` is the behavioural half: it reports
# the ordinal that really reached the proc, so the band measures the truncation
# instead of warning about it in a comment.
proc mt_surface {verb} {
    if {[info commands ::calc::arg_surface] eq {}} { return "NOPROC:calc::arg_surface" }
    if {[catch {::calc::arg_surface $verb} r]} { return "RAISED:$r" }
    return $r
}
proc mt_argvals {verb rpn ans} {
    if {[info commands ::calc::arg_values] eq {}} { return "NOPROC:calc::arg_values" }
    if {[catch {::calc::arg_values $verb $rpn $ans} r]} { return "RAISED:$r" }
    return $r
}
proc mt_argval_of {verb rpn ans key} {
    set v [mt_argvals $verb $rpn $ans]
    if {[regexp {^(NOPROC|RAISED):} $v]} { return $v }
    if {[catch {dict exists $v $key} has]} { return "NOTADICT:{$v}" }
    if {!$has} { return "TRUNCATED-BEFORE:$key" }
    return [dict get $v $key]
}
# the value a formal really RECEIVES after `arg_values` and `arg_invoke` have
# both run, measured against a probe surface whose body reports its own
# arguments -- so the row can show, in the run, that a mid-list formal the
# dialog cannot answer makes the user's own ordinal fall back to a default.
proc mt_delivered {verb rpn ans key} {
    set vals [mt_argvals $verb $rpn $ans]
    if {[regexp {^(NOPROC|RAISED):} $vals]} { return $vals }
    if {[info commands ::calc::arg_invoke] eq {}} { return "NOPROC:calc::arg_invoke" }
    if {[catch {::calc::arg_invoke $verb $vals} r]} { return "RAISED:$r" }
    if {[catch {dict exists $r $key} has]} { return "NOTADICT:{$r}" }
    if {!$has} { return "NOKEY-$key" }
    return [dict get $r $key]
}
# `sized` when a series length IS the length this file derived, and the two
# numbers otherwise -- so a wrong count says what it was and what it should have
# been without either figure being written down anywhere.
proc mt_sized {got want} {
    if {![string is integer -strict $got]} { return "notacount:{$got}" }
    if {![string is integer -strict $want]} { return "notawant:{$want}" }
    if {$got == $want} { return sized }
    return "n:$got want:$want"
}
# `strict` when EVERY crossing of one level falls strictly between two samples,
# `onsample:<x>` otherwise -- R414d, inherited through `cross`, over the whole
# crossing list rather than over one index, so a fixture regenerated onto a
# different grid says so instead of quietly making the rows above compare
# snapped values.
proc mt_allstrict {xs ys L edge} {
    set hits [mt_derive_x $xs $ys $L $edge]
    if {![llength $hits]} { return nocrossing }
    set out {}
    set n [llength $xs]
    foreach x $hits {
        set p 0
        for {set i 1} {$i < $n} {incr i} {
            if {[lindex $xs $i] >= $x} { set p $i ; break }
        }
        if {$p < 1} { lappend out NOPAIR ; continue }
        set xl [lindex $xs [expr {$p-1}]]
        set xr [lindex $xs $p]
        if {$x > $xl && $x < $xr} { lappend out strict ; continue }
        lappend out "onsample:$x"
    }
    return [lsort -unique $out]
}
proc mt_formals {p} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    if {[catch {info args ::calc::$p} a]} { return "RAISED:$a" }
    return $a
}
# `same` / `differ` for two formal lists, so the row that pins the new surface
# wrapper's signature DERIVES it from `calc::riseTime`'s own rather than writing
# seven names down -- which is the hand-kept-list defect one level up, and is
# also what keeps the row correct if the verb ever gains a formal.
proc mt_sameformals {a b} {
    if {[regexp {^(NOPROC|RAISED):} $a]} { return $a }
    if {[regexp {^(NOPROC|RAISED):} $b]} { return $b }
    if {$a eq $b} { return same }
    return "differ:{$a}|{$b}"
}
proc mt_arginvoke {verb rpn ans} {
    set vals [mt_argvals $verb $rpn $ans]
    if {[regexp {^(NOPROC|RAISED):} $vals]} { return $vals }
    if {[info commands ::calc::arg_invoke] eq {}} { return "NOPROC:calc::arg_invoke" }
    if {[catch {::calc::arg_invoke $verb $vals} r]} { return "RAISED:$r" }
    return $r
}
proc mt_sink {a} {
    if {[regexp {^(NOPROC|RAISED):} $a]} { return $a }
    if {[info commands ::calc::fn_sink] eq {}} { return "NOPROC:calc::fn_sink" }
    if {[catch {::calc::fn_sink $a} r]} { return "RAISED:$r" }
    return $r
}
# the ordinals 1..n, so the row that reads one scalar per edge derives its own
# loop bound from `calc::cross`'s answer instead of carrying a count.  Answers
# the EMPTY list for a non-count, so the enclosing `lmap` cannot raise on a
# sentinel and the row fails on the comparison instead.
proc mt_seq {a b} {
    if {![string is integer -strict $b]} { return {} }
    set out {}
    for {set i $a} {$i <= $b} {incr i} { lappend out $i }
    return $out
}

# ---------------------------------------------------------------------------
# MT10's structural instrument.  `info body` carries this tree's enormous block
# comments, and a comment saying "this proc issues no `xschem raw add` of its
# own" would satisfy a naive regexp — so comment-only lines go, and a trailing
# comment goes only where what precedes the `#` is itself a complete script,
# which is what keeps a `#` inside a string or an unclosed brace safe.
# MT10 carries a non-vacuity leg for this proc rather than trusting it.
# ---------------------------------------------------------------------------
proc mt_decomment {body} {
    set out {}
    foreach ln [split $body "\n"] {
        set s [string trimleft $ln]
        if {[string index $s 0] eq "#"} continue
        set i 0
        while {1} {
            set i [string first "#" $ln $i]
            if {$i < 0} break
            set pre [string range $ln 0 [expr {$i-1}]]
            set prev [expr {$i == 0 ? " " : [string index $ln [expr {$i-1}]]}]
            if {[info complete $pre] && ($prev eq " " || $prev eq "\t" || $prev eq ";")} {
                set ln $pre
                break
            }
            incr i
        }
        lappend out $ln
    }
    return [join $out "\n"]
}
# every `::calc::` proc this one's DECOMMENTED body names, as a bare list of
# tails.  The one place the namespace is parsed, so the closure below and the
# `calc::cross` test cannot drift apart.
proc mt_calc_names {p} {
    if {[info commands ::calc::$p] eq {}} { return {} }
    if {[catch {info body ::calc::$p} body]} { return {} }
    set b [mt_decomment $body]
    set out {}
    foreach {whole tail} [regexp -all -inline \
            {(?:^|[^A-Za-z0-9_:])(?:::)?calc::([A-Za-z_][A-Za-z0-9_]*)} $b] {
        if {[lsearch -exact $out $tail] < 0} { lappend out $tail }
    }
    return $out
}
# ⚠ THE TRANSITIVE CLOSURE, AND THE WIDENING IS A MEASURED CORRECTION RATHER
# THAN A RELAXATION.  This used to be `mt_calls_cross`, a one-level regexp whose
# row name claimed *"an intermediate evaluate-once helper would redden this"* —
# and an adversarial lens measured that it reddened on ANY intermediate
# `::calc::` proc, including one that calls `calc::cross` itself and touches no
# accessor.  That is not the shape T1 forbids: T1 forbids a helper that
# EVALUATES ONCE AND SCANS MANY, which necessarily issues its own
# `xschem raw add`, and the same lens measured that such a shape is caught three
# times over here plus independently by row SR5 of test_calc_scratch_reuse.
# Keeping the narrow form would have forced `dutyCycle` — and then `frequency`
# and `period_jitter`, which the spec layers on the same period derivation — each
# to inline the same loop, which is a worse implementation bought with no
# coverage.
#
# So the claim is derived over the namespace the way SR5 derives its five sets:
# a verb REACHES `calc::cross` through a chain of `::calc::` procs, and NO proc
# in that chain reads samples for itself.  The walk stops AT `cross`, which is
# the one proc allowed to be a direct reader, and `seen` bounds it against a
# cycle.  Returns the reached set INCLUDING `cross` when it is reached.
proc mt_calc_closure {p} {
    if {[info commands ::calc::$p] eq {}} { return NOPROC }
    set seen {}
    set q [list $p]
    while {[llength $q]} {
        set c [lindex $q 0]
        set q [lrange $q 1 end]
        if {[lsearch -exact $seen $c] >= 0} continue
        lappend seen $c
        if {$c eq {cross}} continue
        foreach n [mt_calc_names $c] {
            if {[info commands ::calc::$n] eq {}} continue
            if {[catch {info body ::calc::$n}]} continue
            lappend q $n
        }
    }
    return [lsort $seen]
}
# `reaches` / `no` / `NOPROC`.  A WORD and not a chain length, because a length
# is a reproducible number that would land in the T1 verdict and would redden a
# conforming implementation that merely added a helper.
proc mt_reaches_cross {p} {
    set cl [mt_calc_closure $p]
    if {$cl eq {NOPROC}} { return NOPROC }
    if {[lsearch -exact $cl cross] < 0} { return no }
    return reaches
}
# ...and does it issue a DIRECT `xschem raw` write or read of its own?  T1 says
# the three verbs are pure delegates, so the answer must be no for all three —
# which is also SR5's discipline in test_calc_scratch_reuse seen from the other
# side, where `cross` is allowed to be the one direct reader.
#
# ⚠ THE FOUR VERBS ARE THE SAMPLE DOOR AND THE COLUMN DOOR, NOT EVERY `raw`
# SUBCOMMAND.  `loaded`, `datasets`, `index`, `sim_type` and `points` are
# pre-flight, which a layered verb is free to do; `add`, `values`, `value` and
# `del` are evaluating into a column of one's own and reading samples out of it,
# which is exactly what T1 reserves to `cross`.  A door this list does not name
# — `table_read`, say — would not be caught, and that is declared as H7b rather
# than left for a reader to find.
proc mt_direct_raw {p} {
    if {[info commands ::calc::$p] eq {}} { return NOPROC }
    if {[catch {info body ::calc::$p} body]} { return NOPROC }
    set b [mt_decomment $body]
    foreach v {add values value del} {
        if {[regexp "xschem\[ \t\]+raw\[ \t\]+$v" $b]} { return yes }
    }
    return no
}
# every proc in a verb's closure EXCEPT `cross` itself, answered as
# `<name>:<yes|no>` pairs so a failure names WHICH link reads samples instead of
# only that one does.  This is what closes the hole the old pair left open: a
# verb that calls `cross` AND ALSO reads samples through some third `::calc::`
# proc passed both of the old rows.
proc mt_closure_raw {p} {
    set cl [mt_calc_closure $p]
    if {$cl eq {NOPROC}} { return NOPROC }
    set out {}
    foreach n $cl {
        if {$n eq {cross}} continue
        if {[mt_direct_raw $n] eq {yes}} { lappend out $n }
    }
    return $out
}
# ⚠ THE SUITE'S OWN TEXT, not a proc body: the three sites that used to build the
# answer dict inline were at ROW level, so a scan over `info body` could not have
# seen them and the comment claiming they did not exist stayed false through one
# repair.  Walks the file tracking the enclosing `proc`, and answers the sorted
# set of enclosing names — `BAND-LEVEL` for an occurrence inside no proc at all,
# which is precisely the shape that was missed.
proc mt_dictsites {} {
    set f $::MTSELF
    if {$f eq {} || ![file exists $f]} { return "NOFILE:$f" }
    if {[catch {open $f r} h]} { return "NOREAD:$h" }
    set txt [read $h]
    close $h
    set cur {}
    set out {}
    foreach ln [split $txt "\n"] {
        # ⚠ A ONE-LINE PROC MUST NOT LEAK ITS NAME FORWARD, and `mt_asanswer` is
        # one: an earlier draft of this walk did `continue` on the `proc` line and
        # so could not see a dict built on it at all, which is the same blind spot
        # the comment it checks had.
        set oneline 0
        if {[string index $ln 0] eq "\}"} { set cur {} }
        if {[regexp {^proc[ \t]+([^ \t]+)} $ln -> nm]} {
            set cur $nm
            if {[info complete $ln]} { set oneline 1 }
        }
        if {[string index [string trimleft $ln] 0] ne "#" \
                && [regexp {dict[ \t]+create} $ln]} {
            set nm [expr {$cur eq {} ? {BAND-LEVEL} : $cur}]
            if {[lsearch -exact $out $nm] < 0} { lappend out $nm }
        }
        if {$oneline} { set cur {} }
    }
    return [lsort $out]
}
# ⚠ `::calc::cross` REPLACED BY A REFUSING STUB, and restored on BOTH exit
# paths.  This is the behavioural half of T1: a verb that still answers a number
# with `cross` stubbed out is reading samples itself, whatever its body looks
# like, and a structural regexp cannot see that.  The slot is checked before the
# rename so a previous failed run inside the same interpreter cannot be mistaken
# for a product defect.
set mt_stub_calls 0
proc mt_stub_run {script} {
    if {[info commands ::calc::cross] eq {}} { return NOPROC:calc::cross }
    if {[info commands ::mt_cross_keep] ne {}} { return STUBSLOTBUSY }
    rename ::calc::cross ::mt_cross_keep
    proc ::calc::cross {args} {
        incr ::mt_stub_calls
        return [dict create ok 0 absent 0 value {} dataset 0 dest {} \
                    msg {Cross: MTSTUB refused this on purpose.}]
    }
    set ::mt_stub_calls 0
    set rc [catch {uplevel 1 $script} r]
    catch {rename ::calc::cross {}}
    catch {rename ::mt_cross_keep ::calc::cross}
    # ⚠ rc 2 IS `return`, NOT AN ERROR, and this proc shipped its first revision
    # treating it as one: the probe script ends in `return [join ...]`, `catch`
    # scores that as TCL_RETURN = 2, and the row got the right answer with
    # `ERR:` glued to the front of it.  A row that fails for the wrong reason is
    # worse than one that fails, because the next reader debugs the product.
    if {$rc != 0 && $rc != 2} { return "ERR:$r" }
    return $r
}

if {[catch {

# =========================================================================
group MT0 {
    # Infrastructure.  Nothing here calls one of the three verbs; all of it
    # passes on a tree with none of them, which is what lets a reader tell "the
    # suite works and the feature is absent" from "the suite is broken".
    check "MT0 fixture: tests/headless/data/calc_fixture.raw was located" \
        [expr {$::fixture ne {} ? 1 : 0}] 1
    check "MT0 fixture reads as the tran database spec 11.2 describes -- two datasets of 101 points, ten vectors -- when the type is given EXPLICITLY" \
        [list [pcall mt_load tran] [pcall xschem raw sim_type] [pcall xschem raw datasets] \
              [pcall xschem raw points 0] [pcall xschem raw points 1] [llength [rawnames]]] \
        {1 tran 2 101 101 10}
    # D12's last paragraph, inherited: every one of these verbs reaches the
    # sweep column through `cross`, which resolves it BY NAME -- and the
    # fixture's own operating-point plot has NO sweep column, with `v(sq)` at
    # index 0, so an index-0 implementation reads a node voltage as an X axis.
    check "MT0 D12 the sweep column is reachable BY NAME on the tran read, and is index 0 there -- which is exactly why an index-0 implementation scores the same as a correct one on nearly every row" \
        [list [pcall xschem raw index time] [pcall xschem raw sim_type]] {0 tran}
    check "MT0 D12 ...and on the OP read index 0 is v(sq) with no time column at all, so the index-0 reading is observably wrong somewhere" \
        [list [pcall mt_load op] [pcall xschem raw sim_type] [lindex [rawnames] 0] \
              [pcall xschem raw index time]] {1 op v(sq) -1}
    pcall mt_load tran
    # THE PRECISION DOOR, re-measured, because the sibling suite had four
    # structurally dead legs from comparing across it.  No comparand in this
    # file comes from the per-point door.
    # ⚠ SAMPLE 10, AND SAMPLE 50 IS THE WRONG ONE TO ASK -- measured while
    # writing this row, which had it at 50 and PASSED THE DOORS AS EQUAL.
    # CROSS_CONTRACT's own recon records that `v(sq)` at sample 50 is BIT-EXACTLY
    # 0.5, so it round-trips through "%.8g" and the two doors agree there; the
    # disagreement needs a sample whose value carries low-order bits, and sample
    # 10 is 0.5000000000000009.  The sibling suite has the same shape of mistake
    # recorded the other way round, where a row was alive ONLY because
    # `time[50]` round-trips.
    check "MT0 the bulk door and the per-point door DISAGREE on v(sq) sample 10 -- `raw values` prints %.16g and `raw value` prints dtoa() = %.8g -- so a comparand taken from the per-point door could never be string-equal to a bulk-derived answer, while both are still the same number to the fixture's documented 1e-11" \
        [list [string equal [mt_at [mt_col {v(sq)} 0] 10] [pcall xschem raw value {v(sq)} 10 0]] \
              [near [mt_at [mt_col {v(sq)} 0] 10] 0.5 1e-11] \
              [string equal [mt_at [mt_col {v(sq)} 0] 50] [pcall xschem raw value {v(sq)} 50 0]]] \
        {0 ok 1}
    # `calc::cross` as it shipped, in all three dispositions.  These three
    # answers are what the verbs are built on, so a change to any of them is a
    # change to all three verbs and should be seen here first.
    check "MT0 calc::cross exists and its measured answer carries every key a row below reads -- ok, absent, value, msg and dataset, enumerated here and nowhere counted" \
        [list [llength [pcall info procs ::calc::cross]] \
              [mt_disp [set a [mt_call cross {v(sq)} 0.5 1 rising]]] \
              [mt_key $a ok] [mt_key $a absent] [mt_key $a dataset] [mt_key $a msg] \
              [near [mt_val $a] [sq_rise 0.5 0] $MTTOL]] \
        {1 measured 1 0 0 {} ok}
    check "MT0 calc::cross reaches all three dispositions -- measured, absent for an occurrence the sweep has not got, refused for an edge it cannot interpret -- which is the distinction D7 says lets a layered verb tell a meaningless request from an unanswerable one" \
        [list [mt_disp [mt_call cross {v(sq)} 0.5 1 rising]] \
              [mt_disp [mt_call cross {v(sq)} 0.5 99 rising]] \
              [mt_disp [mt_call cross {v(sq)} 0.5 1 sideways]]] \
        {measured absent refused}
    # T5's hazard, measured rather than quoted.  THIS is what band MT9 is about.
    check "MT0 T5's hazard is REAL: calc::cross with nth=0 at a level no sample reaches answers MEASURED WITH AN EMPTY LIST, not absent -- so an unguarded dutyCycle feeds an empty crossing list to its period arithmetic" \
        [list [mt_disp [set a [mt_call cross {v(sq)} 2.0 0 rising]]] [mt_len [mt_val $a]] \
              [mt_disp [mt_call cross {v(sq)} 2.0 1 rising]]] \
        {measured 0 absent}
    check "MT0 ...and the same hazard with ONE rising crossing and no fall to close a period: v(ramp) is monotone, so level 5 gives one rising crossing and ZERO falling ones" \
        [list [mt_disp [set a [mt_call cross {v(ramp)} 5 0 rising]]] [mt_len [mt_val $a]] \
              [mt_disp [set b [mt_call cross {v(ramp)} 5 0 falling]]] [mt_len [mt_val $b]]] \
        {measured 1 measured 0}
    check "MT0 this suite's own mt_finite agrees with calc::eval_finite on every spelling dtoa and the MSVC runtime can emit -- a CHANGE DETECTOR over two byte-identical regexps, NOT independent evidence, because a wrong pattern would be wrong identically in both copies and this row would still be green" \
        [join [lmap v [list 0.5 -0 1e-35 .5 -3.5e-9 inf -inf nan -nan NaN INF 1.#INF -1.#IND 1.#QNAN {} abc] \
                   {list $v [mt_finite $v] [pcall calc::eval_finite $v]}] { }] \
        [join [lmap v [list 0.5 -0 1e-35 .5 -3.5e-9 inf -inf nan -nan NaN INF 1.#INF -1.#IND 1.#QNAN {} abc] \
                   {list $v [mt_finite $v] [mt_finite $v]}] { }]
    check "MT0 the loaded inventory carries no __calc_tmp* and no __mt_* at band exit, so every R402 row below starts from zero" \
        [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT1 {
    # Infrastructure, and the load-bearing band: the deck arithmetic and this
    # suite's own D3 + D4 over the bulk columns, against each other.  No verb is
    # called.  PASSES TODAY.
    pcall mt_load tran
    set t0 [mt_col time 0]
    set q0 [mt_col {v(sq)} 0]
    check "MT1 the two columns every derivation below runs over came back with 101 samples each" \
        [list [mt_len $t0] [mt_len $q0]] {101 101}
    check "MT1 D3+D4 over the bulk columns reproduce the deck's rising and falling 50% crossings -- three rising at 0.9+0.2L+4k ms and two falling at 2.3-0.2L+4k ms, which is the fixture README's own hand derivation reached independently" \
        [list [mt_islist [mt_asanswer [mt_derive_x $t0 $q0 0.5 rising]] \
                   [list [sq_rise 0.5 0] [sq_rise 0.5 1] [sq_rise 0.5 2]]] \
              [mt_islist [mt_asanswer [mt_derive_x $t0 $q0 0.5 falling]] \
                   [list [sq_fall 0.5 0] [sq_fall 0.5 1]]]] {ok ok}
    # ---- dutyCycle's two derivations, at three levels ----
    foreach L {0.5 0.3 0.75} {
        check "MT1 R416 the deck's own duty fraction (1.4-0.4L)/4 at level $L agrees with the columns' (fall - rise) over (next rise - rise), for BOTH complete periods -- so the figure MT8 asserts is derived twice and taken from no receipt" \
            [mt_islist [mt_asanswer [mt_duty_series $t0 $q0 $L]] \
                 [list [sq_duty $L] [sq_duty $L]]] ok
    }
    # ⚠ THE TWO ROWS FLAGGED BELOW AS DERIVATION SELF-CHECKS ARE THIS ONE AND THE
    # swing-ratio one further down.  Both are arithmetic over this file's OWN procs
    # with no column and no product in them, so NO PRODUCT CHANGE CAN REDDEN EITHER:
    # they check that the deck formulas have the property the behavioural rows'
    # discrimination legs rely on.  That is a defensible thing for a row to do and it
    # is the only kind of row in this file that is tautological in the strict sense,
    # so it is declared here and in the header's vacuity list rather than left to be
    # discovered as a dead fence.
    check "MT1 R416 DERIVATION SELF-CHECK, no product in it: the deck fraction MOVES with the level, which is the half a 1-ms-over-4-ms sentence drops -- the three levels above give three different fractions, so MT8's three level rows discriminate and a verb that hardcoded the 50% duty cannot pass all three" \
        [list [expr {[sq_duty 0.3] > [sq_duty 0.5]}] [expr {[sq_duty 0.5] > [sq_duty 0.75]}]] {1 1}
    check "MT1 T4 the trailing PARTIAL period is the reason the series is shorter than the rising-crossing list: three rising crossings open only two periods, because the third has no rising crossing after it to close one" \
        [list [llength [mt_derive_x $t0 $q0 0.5 rising]] \
              [llength [mt_derive_x $t0 $q0 0.5 falling]] \
              [llength [mt_duty_series $t0 $q0 0.5]]] {3 2 2}
    # ---- riseTime's two derivations, at EVERY supplied swing MT2 asserts ----
    # ⚠ THE 0.25..0.75 SWING WAS MISSING FROM THIS SEED AND MT2 ASSERTS IT, so the
    # header's claim that every asserted number is derived twice was false for
    # exactly one number -- and it was the number whose two thresholds (0.30 and
    # 0.70) therefore got neither the snapping fence nor the difference fence below.
    # The remedy is a seed entry, not a narrower claim: the set here is meant to be
    # the set MT2 drives, and `/usr/bin/grep -oE 'sq_rt [0-9.]+ [0-9.]+ [0-9]+ [0-9]+'`
    # over this file is how a reader re-checks that rather than trusting this
    # sentence.
    foreach {lo hi plo phi} {0 1 10 90   0.2 0.6 10 90   0 1 20 80   0.25 0.75 10 90} {
        check "MT1 R415 the deck's 0.2 ms times the threshold separation agrees with the columns' difference of the two rising crossings, for the supplied swing $lo..$hi at $plo%/$phi% -- the thresholds being percentages OF THAT SWING and of nothing the trace says" \
            [near [expr {[lindex [mt_derive_x $t0 $q0 [sq_thr $lo $hi $phi] rising] 0] \
                         - [lindex [mt_derive_x $t0 $q0 [sq_thr $lo $hi $plo] rising] 0]}] \
                  [sq_rt $lo $hi $plo $phi] $MTTOL] ok
        check "MT1 R414d ...and BOTH of that swing's thresholds cross STRICTLY BETWEEN samples, so every snapping convention -- down, up, nearest -- is rejected by this file's own near at MTTOL and MT2's rows cannot pass a snapping implementation" \
            [list [mt_snaps $t0 $q0 [sq_thr $lo $hi $plo] rising 0] \
                  [mt_snaps $t0 $q0 [sq_thr $lo $hi $phi] rising 0]] \
            {{rejected rejected rejected} {rejected rejected rejected}}
        check "MT1 R414d ...and so is every DIFFERENCE a snapping implementation could report for that swing's rise time -- all four combinations of the two brackets' endpoints, enumerated rather than claimed" \
            [mt_snapdiffs $t0 $q0 [sq_thr $lo $hi $plo] [sq_thr $lo $hi $phi] 0] \
            {rejected rejected rejected rejected}
    }
    check "MT1 R415 DERIVATION SELF-CHECK, no product in it: 10%/90% of 0..1 and 10%/90% of 0.2..0.6 are DISTINCT deck rise times at MTTOL and their ratio is the ratio of the two supplied swings -- which is what makes MT2's trace-derived-swing row discriminate, and is a property of the formulas rather than of the product" \
        [list [mt_distinct [sq_rt 0 1 10 90] [sq_rt 0.2 0.6 10 90]] \
              [near [expr {[sq_rt 0 1 10 90]/[sq_rt 0.2 0.6 10 90]}] \
                    [expr {(1.0 - 0.0)/(0.6 - 0.2)}] $MTTOL]] \
        {distinct ok}
    # ---- the INVERTED column, whose crossings MT5 and MT6 subtract ----
    # ⚠ MT5's AND MT6's PER-SIDE NUMBERS CAME FROM THE COLUMNS ALONE, so the
    # header's "derived twice" claim did not hold for them either.  The deck side is
    # the inversion identity rather than a second trapezoid table, because an
    # identity is checkable by eye and a table is not: the inverted square's FALLING
    # crossings at L are `v(sq)`'s RISING crossings at 1-L and vice versa.
    set iv [mt_addcol __mt_inv {1 v(sq) -} 0]
    foreach L {0.75 0.25 0.5} {
        check "MT1 T3 the inverted square's crossings at level $L agree with the deck through the 1-minus-v(sq) identity -- three falling crossings at v(sq)'s rising times for 1-L and two rising ones at v(sq)'s falling times for 1-L -- which is where MT5's and MT6's per-side numbers get their SECOND derivation" \
            [list [mt_islist [mt_asanswer [mt_derive_x $t0 $iv $L falling]] \
                       [list [inv_fall $L 0] [inv_fall $L 1] [inv_fall $L 2]]] \
                  [mt_islist [mt_asanswer [mt_derive_x $t0 $iv $L rising]] \
                       [list [inv_rise $L 0] [inv_rise $L 1]]]] {ok ok}
    }
    # ---- the DATASET DISCRIMINATOR, whose two datasets MT2 and MT5 tell apart ----
    check "MT1 D12 v(div)'s deck relation agrees with the columns in BOTH datasets at every level MT2 and MT5 ask about, and the high threshold of MT2's supplied swing is crossed ZERO times in dataset 1 -- so the dataset rows' ABSENT disposition is a property of the fixture derived here and not an assumption made there" \
        [list [mt_islist [mt_asanswer [mt_derive_x $t0 [mt_col {v(div)} 0] [sq_thr 0 5 10] rising]] \
                   [list [div_t [sq_thr 0 5 10] 0]]] \
              [mt_islist [mt_asanswer [mt_derive_x $t0 [mt_col {v(div)} 0] [sq_thr 0 5 90] rising]] \
                   [list [div_t [sq_thr 0 5 90] 0]]] \
              [mt_islist [mt_asanswer [mt_derive_x $t0 [mt_col {v(div)} 0] 1.03 rising]] \
                   [list [div_t 1.03 0]]] \
              [mt_islist [mt_asanswer [mt_derive_x $t0 [mt_col {v(div)} 0] 4.03 rising]] \
                   [list [div_t 4.03 0]]] \
              [mt_islist [mt_asanswer [mt_derive_x [mt_col time 1] [mt_col {v(div)} 1] 1.03 rising]] \
                   [list [div_t 1.03 1]]] \
              [llength [mt_derive_x [mt_col time 1] [mt_col {v(div)} 1] [sq_thr 0 5 90] rising]] \
              [llength [mt_derive_x [mt_col time 1] [mt_col {v(div)} 1] 4.03 rising]]] \
        {ok ok ok ok ok 0 0}
    # ---- the glitch column MT4 needs ----
    set gl [mt_glitch]
    set g0 [mt_addcol __mt_glitch $gl 0]
    check "MT1 the engine evaluates the glitch expression into a named column of 101 samples, and calc::rpn_bad_token accepts every token in it, so MT4 has a column whose two thresholds are crossed a different number of times" \
        [list [mt_len $g0] [pcall calc::rpn_bad_token $gl] [probeleft]] {101 {} {}}
    check "MT1 T2 that column crosses the 12% threshold THREE times rising and the 88% threshold FOUR times rising -- counts derived from the column at run time, because the arithmetic in mt_glitch's comment is not what the engine ran" \
        [list [llength [mt_derive_x $t0 $g0 [sq_thr 0 1 12] rising]] \
              [llength [mt_derive_x $t0 $g0 [sq_thr 0 1 88] rising]]] {3 4}
    check "MT1 T2 ...and no crossing of either threshold lands on a sample, for any of those occurrences, so MT4 fences interpolation as well as ordering" \
        [list [mt_snaps $t0 $g0 [sq_thr 0 1 12] rising 0] [mt_snaps $t0 $g0 [sq_thr 0 1 12] rising 1] \
              [mt_snaps $t0 $g0 [sq_thr 0 1 12] rising 2] [mt_snaps $t0 $g0 [sq_thr 0 1 88] rising 0] \
              [mt_snaps $t0 $g0 [sq_thr 0 1 88] rising 1] [mt_snaps $t0 $g0 [sq_thr 0 1 88] rising 2] \
              [mt_snaps $t0 $g0 [sq_thr 0 1 88] rising 3]] \
        [lrepeat 7 {rejected rejected rejected}]
    # ⚠ THE THREE ROWS BELOW ARE WHAT MAKE MT4 NON-VACUOUS, and they are the
    # reason MT4 exists at all: on `v(sq)` the two readings AGREE everywhere.
    check "MT1 T2 on that column the two readings AGREE at occurrence 1 -- so MT4's first row is a CONTROL that discriminates nothing, and saying so here is what stops it being read as evidence" \
        [list [near [mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 1 correct] \
                    [mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 1 naive] $MTTOL]] {ok}
    check "MT1 T2 ...they DISAGREE at occurrence 2, where the naive nth-at-each-level reading straddles two bumps and reports a LONGER rise time than the real edge has" \
        [list [expr {[mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 2 naive] \
                     > [mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 2 correct]}] \
              [mt_distinct [mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 2 naive] \
                           [mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 2 correct]]] \
        {1 distinct}
    check "MT1 T2 ...and at occurrence 3 the naive reading picks a high crossing BEFORE its low one, so it reports a NEGATIVE rise time while the correct reading reports a positive one -- which is the row no implementation can pass by luck" \
        [list [expr {[mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 3 naive] < 0}] \
              [expr {[mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 3 correct] > 0}]] {1 1}
    check "MT1 the band left no __calc_tmp* and no __mt_* behind" [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT2 {
    # R415's arithmetic.  Every expectation is the DECK value `sq_rt`, which
    # MT1 has already shown agrees with the columns.
    pcall mt_load tran
    check "MT2 R415 calc::riseTime exists -- NOPROC here is the whole of this band's red, and it names the proc rather than printing an invalid-command-name error" \
        [llength [pcall info procs ::calc::riseTime]] 1
    check "MT2 R415 with the swing supplied as 0..1 and the thresholds left at their 10/90 default, the answer is the deck's 0.2 ms times the threshold separation" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0 1]]] [mt_is $a [sq_rt 0 1 10 90]]] \
        {measured ok}
    check "MT2 R415 ...and with the thresholds given explicitly as 20/80 of the same swing, which is a DISTINCT answer at MTTOL, so the percentages are read rather than ignored" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0 1 20 80]]] [mt_is $a [sq_rt 0 1 20 80]] \
              [mt_distinct [sq_rt 0 1 20 80] [sq_rt 0 1 10 90]]] \
        {measured ok distinct}
    # THE ROW A TRACE-DERIVED-SWING IMPLEMENTATION FAILS.  `v(sq)` swings 0 to 1,
    # so a verb taking its references from the waveform answers the 0..1 figure
    # whatever swing it was handed; R415 says the handed swing is the only one.
    check "MT2 R415 the thresholds are percentages OF THE SUPPLIED SWING: 10/90 of 0.2..0.6 gives the deck's shorter rise time and is DISTINCT at MTTOL from the 0..1 figure, which is the only answer a verb deriving min and max from the trace can give -- v(sq) swings 0 to 1 whatever swing it was handed" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0.2 0.6]]] [mt_is $a [sq_rt 0.2 0.6 10 90]] \
              [mt_distinct [mt_val $a] [sq_rt 0 1 10 90]]] \
        {measured ok distinct}
    check "MT2 R415 ...and a swing that is a sub-interval of the trace's own is not clamped to it either: 25..75 gives its own deck figure" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0.25 0.75]]] [mt_is $a [sq_rt 0.25 0.75 10 90]]] \
        {measured ok}
    # ⚠ THIS ROW'S NAME USED TO CLAIM COVERAGE IT CANNOT DELIVER, which is trap 10
    # in this file's own list.  It read *"the occurrence selects WHICH edge"*, and
    # an adversarial lens measured that forcing the occurrence to 1 inside the
    # product reddens three rows in MT3 and three in MT4 and NONE here -- because
    # all three of `v(sq)`'s rising edges have the SAME rise time, so the
    # comparand for occurrence 2 equals the one for occurrence 1 and the row
    # cannot see the occurrence at all.  The row is kept because it IS a live
    # interpolation fence (a snapping implementation reddens it), the claim that
    # the occurrence is read lives in MT4 where the two occurrences differ, and
    # the `same` leg below DECLARES the indiscrimination instead of leaving a
    # reader to infer it.
    check "MT2 occurrence 2 is answered against the SECOND edge's own columns -- and the two occurrences are declared the SAME rise time here, which is why this row fences interpolation and NOT the occurrence: the row that discriminates the occurrence is MT4's, on a column where the edges differ" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0 1 10 90 2]]] \
              [near [mt_val $a] \
                    [expr {[lindex [mt_derive_x [mt_col time 0] [mt_col {v(sq)} 0] [sq_thr 0 1 90] rising] 1] \
                           - [lindex [mt_derive_x [mt_col time 0] [mt_col {v(sq)} 0] [sq_thr 0 1 10] rising] 1]}] \
                    $MTTOL] \
              [mt_distinct [expr {[lindex [mt_derive_x [mt_col time 0] [mt_col {v(sq)} 0] [sq_thr 0 1 90] rising] 1] \
                                  - [lindex [mt_derive_x [mt_col time 0] [mt_col {v(sq)} 0] [sq_thr 0 1 10] rising] 1]}] \
                           [sq_rt 0 1 10 90]]] {measured ok same}
    check "MT2 R414d the answer is interpolated: every difference the four snapped bracket endpoints could produce is rejected by near at MTTOL, re-derived here from the same columns MT1 enumerated them over" \
        [list [mt_disp [mt_call riseTime {v(sq)} 0 1]] \
              [mt_snapdiffs [mt_col time 0] [mt_col {v(sq)} 0] [sq_thr 0 1 10] [sq_thr 0 1 90] 0]] \
        {measured {rejected rejected rejected rejected}}
    check "MT2 D12 the answer reports the dataset it read, defaulting to 0, so a verb layered on this one propagates it rather than guessing" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0 1]]] [mt_key $a dataset] \
              [mt_disp [set b [mt_call riseTime {v(sq)} 0 1 10 90 1 1]]] [mt_key $b dataset]] \
        {measured 0 measured 1}
    # ⚠ REPORTING THE DATASET AND READING IT ARE TWO CLAIMS, AND THE ROW ABOVE
    # MAKES ONLY THE FIRST.  Measured: a `riseTime` that reports `$dataset` while
    # passing 0 to every `calc::cross` call passes it, because `v(sq)` is identical
    # in both transient datasets.  `v(div)` is the fixture's own dataset
    # discriminator -- `v(ramp)/2` in dataset 0 and `v(ramp)/4` in dataset 1 -- so
    # ONE supplied swing lands INSIDE the column in dataset 0 and ABOVE it in
    # dataset 1, and the two datasets answer in two different DISPOSITIONS rather
    # than two numbers a tolerance has to separate.
    check "MT2 D12 the dataset is READ and not merely reported: with the swing supplied as 0..5, v(div) measures in dataset 0 -- against THAT dataset's own columns -- and is ABSENT in dataset 1, where v(ramp)/4 never reaches the 90% threshold at all, so a verb that echoed the dataset while reading dataset 0 would answer the same number twice" \
        [list [mt_disp [set a [mt_call riseTime {v(div)} 0 5 10 90 1 0]]] \
              [near [mt_val $a] \
                    [expr {[lindex [mt_derive_x [mt_col time 0] [mt_col {v(div)} 0] [sq_thr 0 5 90] rising] 0] \
                           - [lindex [mt_derive_x [mt_col time 0] [mt_col {v(div)} 0] [sq_thr 0 5 10] rising] 0]}] \
                    $MTTOL] \
              [mt_key $a dataset] \
              [mt_disp [set b [mt_call riseTime {v(div)} 0 5 10 90 1 1]]] \
              [llength [mt_derive_x [mt_col time 1] [mt_col {v(div)} 1] [sq_thr 0 5 90] rising]]] \
        {measured ok 0 absent 0}
    check "MT2 D12 ...and a BAD dataset is REFUSED rather than absent or clamped, from either end -- out of range and allpoints, which is the disposition issue 1632's out-of-bounds read makes load-bearing" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0 1 10 90 1 7]]] [mt_shape [mt_msg $a]] \
              [mt_disp [mt_call riseTime {v(sq)} 0 1 10 90 1 -1]]] {refused ok refused}
    check "MT2 the band left no __calc_tmp* behind, on the measured path" [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT3 {
    # R415's refusal, and D7's distinction.  OMITTING THE SWING IS A REFUSAL,
    # NOT A GUESS -- and a refusal is not an absence, which is the distinction
    # D7 says lets a layered verb tell "you asked me something meaningless"
    # from "this signal never does that".
    pcall mt_load tran
    check "MT3 R415 with NO reference levels at all the request is REFUSED, carrying a sentence -- not measured off a waveform-derived swing, and not reported as an absence" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)}]]] [mt_shape [mt_msg $a]] \
              [mt_val $a]] {refused ok refused}
    check "MT3 R415 ...and so is a HALF-supplied swing, from either side: a low reference with no high one, and a high reference with no low one" \
        [list [mt_disp [mt_call riseTime {v(sq)} 0 {}]] \
              [mt_disp [mt_call riseTime {v(sq)} {} 1]]] {refused refused}
    # ⚠ THE ZERO SWING IS THIS FILE'S DECISION AND NOT R415's, and saying so is the
    # point of this comment: R415 rules that OMITTING the swing refuses and says
    # nothing whatever about `lo == hi`.  Refusing it follows from D7 -- every
    # percentage of a zero swing names the same threshold, so the request cannot be
    # interpreted as a rise time at all -- but it is a choice, it is declared as hole
    # H8 in the header, and the implementation stage may overrule it.
    check "MT3 D7 a ZERO swing is REFUSED -- THIS FILE'S CHOICE, not R415's, because every percentage of it names the same threshold so there is nothing for the two thresholds to be percentages of" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0.5 0.5]]] [mt_shape [mt_msg $a]]] {refused ok}
    check "MT3 R415 ...and a reference level that is not a finite number, which D6 says must REFUSE rather than raise out of the interpolation arithmetic" \
        [list [mt_disp [mt_call riseTime {v(sq)} nan 1]] \
              [mt_disp [mt_call riseTime {v(sq)} 0 inf]]] {refused refused}
    check "MT3 D7 a REFUSAL stays distinct from an ABSENCE in the same band: the swing omitted is refused, while a well-formed call for an occurrence this sweep has not got is ABSENT with its own sentence" \
        [list [mt_disp [mt_call riseTime {v(sq)}]] \
              [mt_disp [set b [mt_call riseTime {v(sq)} 0 1 10 90 99]]] [mt_shape [mt_msg $b]]] \
        {refused absent ok}
    check "MT3 D5 ...and the absent answer cannot be silently consumed as a number, because 0 is a perfectly good rise time" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0 1 10 90 99]]] \
              [mt_finite [mt_val $a]] [mt_val $a]] {absent 0 absent}
    check "MT3 R414b ...and it is symmetric: an occurrence out of range from the END answers the same way, through the same path" \
        [list [mt_disp [mt_call riseTime {v(sq)} 0 1 10 90 -99]] \
              [mt_disp [mt_call riseTime {v(sq)} 0 1 10 90 99]]] {absent absent}
    check "MT3 the empty expression is refused on its own account, because calc::rpn_bad_token answers clean for an empty RPN as well as for a good one" \
        [list [mt_disp [set a [mt_call riseTime {} 0 1]]] [mt_shape [mt_msg $a]]] {refused ok}
    check "MT3 R402 NO __calc_tmp* survives any of this band's refusing or absent paths -- the cleanup cannot be driven by raw add's return code, which answers 1 for an expression the engine rejected" \
        [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT4 {
    # T2.  The high crossing is the FIRST ONE AFTER the low crossing of the
    # requested occurrence.  Driven on the glitch column, because on `v(sq)` the
    # naive reading agrees everywhere -- MT1 measured that, and MT1's three
    # comparison rows are what make these non-vacuous.
    pcall mt_load tran
    set t0 [mt_col time 0]
    set gl [mt_glitch]
    set g0 [mt_addcol __mt_glitch $gl 0]
    set Llo [sq_thr 0 1 12]
    set Lhi [sq_thr 0 1 88]
    check "MT4 T2 CONTROL: at occurrence 1 the two readings agree, so this row cannot discriminate and is here to show the verb answers the glitch column at all" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 1]]] \
              [mt_is $a [mt_t2_rt $t0 $g0 $Llo $Lhi 1 correct]]] {measured ok}
    check "MT4 T2 at occurrence 2 the answer is the FIRST high crossing after the second low crossing, and is DISTINCT at MTTOL from the second high crossing -- which is the reading a nth-at-each-level implementation produces, and which straddles two bumps" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 2]]] \
              [mt_is $a [mt_t2_rt $t0 $g0 $Llo $Lhi 2 correct]] \
              [mt_distinct [mt_val $a] [mt_t2_rt $t0 $g0 $Llo $Lhi 2 naive]]] \
        {measured ok distinct}
    check "MT4 T2 at occurrence 3 the correct answer is POSITIVE while the nth-at-each-level reading picks a high crossing that happened BEFORE its low one and is NEGATIVE, so an implementation taking the nth at each level reports a rise time that never happened" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 3]]] \
              [mt_is $a [mt_t2_rt $t0 $g0 $Llo $Lhi 3 correct]] \
              [expr {[mt_finite [mt_val $a]] ? ([mt_val $a] > 0) : {NOTANUMBER}}] \
              [expr {[mt_t2_rt $t0 $g0 $Llo $Lhi 3 naive] < 0}]] {measured ok 1 1}
    check "MT4 T2 ...and the occurrence beyond the low threshold's own crossings is ABSENT rather than refused, because asking for a fourth edge of a three-edge trace is well-formed" \
        [mt_disp [mt_call riseTime $gl 0 1 12 88 4]] absent
    # ⚠ R414c/D1's NEGATIVE ORDINAL, WHICH CROSS_CONTRACT CALLS *"the single most
    # likely thing to be implemented wrongly"* AND WHICH THIS BAND USED NOT TO
    # MEASURE AT ALL.  The only negative occurrence anywhere in this file was MT3's
    # `-99`, which is out of range from EITHER end, so an `abs(nth)` implementation
    # answered the same absence and passed.  Here `-1` and `+1` select DIFFERENT
    # low crossings of the same column -- the last and the first -- and T2 then
    # anchors a different high crossing to each, so the two readings differ by far
    # more than MTTOL.  ⚠ NO FIGURE FOR THAT GAP IS WRITTEN HERE: the row's own
    # `mt_distinct` leg re-derives it every run, which is the house rule a sibling
    # row called "half a grid step off every sample" broke by being false by ten
    # orders of magnitude.
    check "MT4 R414c a NEGATIVE occurrence counts the LOW crossings from the END: -1 selects the last low crossing of the glitch column and anchors the first high crossing after IT, which is DISTINCT at MTTOL from what abs(nth) would answer -- the first low crossing's own edge, which is +1's answer and is also asserted here" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 -1]]] \
              [mt_is $a [mt_t2_rt $t0 $g0 $Llo $Lhi [llength [mt_derive_x $t0 $g0 $Llo rising]] correct]] \
              [mt_distinct [mt_val $a] [mt_t2_rt $t0 $g0 $Llo $Lhi 1 correct]] \
              [mt_disp [set b [mt_call riseTime $gl 0 1 12 88 1]]] \
              [mt_is $b [mt_t2_rt $t0 $g0 $Llo $Lhi 1 correct]]] \
        {measured ok distinct measured ok}
    # ⚠ -2 WOULD HAVE BEEN THE WRONG SECOND ROW TO WRITE, measured rather than
    # reasoned: on this column occurrences 2 and 3 have the SAME rise time -- each
    # of those low crossings is followed by a high one the same distance later --
    # so a `-2` row could not tell `-2` from `-1`.  `-3` is the one that discriminates -- it must reach
    # the FIRST low crossing, whose edge is the long straddling one -- and `-4`
    # must fall off the end from the far side.
    check "MT4 R414c ...and the negative ordinal is an ORDINAL, not a synonym for last: -3 on a three-crossing column must answer the FIRST occurrence's edge, DISTINCT at MTTOL from -1's, while -4 falls off the end and is ABSENT by R414b's symmetric path" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 -3]]] \
              [mt_is $a [mt_t2_rt $t0 $g0 $Llo $Lhi 1 correct]] \
              [mt_distinct [mt_t2_rt $t0 $g0 $Llo $Lhi 1 correct] \
                           [mt_t2_rt $t0 $g0 $Llo $Lhi 3 correct]] \
              [mt_disp [mt_call riseTime $gl 0 1 12 88 -4]]] \
        {measured ok distinct absent}
    # ⚠ T2'S OTHER ABSENCE, which nothing used to exercise: the low crossing for
    # the requested occurrence EXISTS and NO high crossing follows it.  The glitch
    # column cannot produce it -- its last low excursion is a full-height bump, so
    # a high crossing always follows -- so this needs a column whose LAST bump is
    # a half-height one.  The two counts are in the row, so a reader can see that
    # occurrence 2's low crossing exists and the absence is therefore not the
    # ran-off-the-end absence the row above measures.
    set fsx "[mt_tri 2.0 1.0 1.0] [mt_tri 7.0 1.0 0.5] max()"
    set f0 [mt_addcol __mt_fstart $fsx 0]
    check "MT4 T2 a low crossing WITH NO HIGH CROSSING AFTER IT is ABSENT with a sentence, and it is a DIFFERENT absence from running off the end of the low list: on one full bump followed by a HALF-height one the low threshold is crossed twice rising and the high one once, the counts being in this row, so occurrence 1 measures and occurrence 2 -- whose low crossing exists -- has nothing to close it" \
        [list [mt_len $f0] \
              [llength [mt_derive_x $t0 $f0 $Llo rising]] \
              [llength [mt_derive_x $t0 $f0 $Lhi rising]] \
              [mt_disp [set a [mt_call riseTime $fsx 0 1 12 88 1]]] \
              [mt_is $a [mt_t2_rt $t0 $f0 $Llo $Lhi 1 correct]] \
              [mt_disp [set b [mt_call riseTime $fsx 0 1 12 88 2]]] \
              [mt_shape [mt_msg $b]] [mt_finite [mt_val $b]]] \
        {101 2 1 measured ok absent ok 0}
    check "MT4 the band left no __calc_tmp* and no __mt_* behind" [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT5 {
    # T3's first half: a FULL EDGE SPECIFICATION PER SIDE -- level, direction
    # and occurrence each independent.  Two different expressions, so the row
    # cannot pass an implementation that measures one signal twice.  The band
    # closes with the dataset `delay` actually READS, which is a different claim
    # from MT7's two bad-dataset refusals and was not measured anywhere before.
    pcall mt_load tran
    set t0 [mt_col time 0]
    set q0 [mt_col {v(sq)} 0]
    set iv [mt_addcol __mt_inv {1 v(sq) -} 0]
    # side A: v(sq), level 0.3, rising, occurrence 1
    # side B: 1 v(sq) -, level 0.75, falling, occurrence 2
    # all three fields differ between the sides, and the deck derivation for
    # side B goes through the inversion identity rather than a second table.
    set xa [lindex [mt_derive_x $t0 $q0 0.3 rising] 0]
    set xb [lindex [mt_derive_x $t0 $iv 0.75 falling] 1]
    check "MT5 T3 calc::delay exists -- NOPROC here is the whole of this band's red" \
        [llength [pcall info procs ::calc::delay]] 1
    check "MT5 T3 a full edge spec PER SIDE, with level, direction and occurrence all different between the sides, answers the second edge's X minus the first's -- derived from the two columns, and agreeing with the deck through the 1-minus-v(sq) inversion identity" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.3 rising 1 {1 v(sq) -} 0.75 falling 2]]] \
              [mt_is $a [expr {$xb - $xa}]] \
              [near [expr {$xb - $xa}] [expr {[inv_fall 0.75 1] - [sq_rise 0.3 0]}] $MTTOL]] \
        {measured ok ok}
    check "MT5 T3 moving ONLY side B's occurrence moves the answer by one 4 ms period, which is what makes the occurrence per-side rather than shared" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.3 rising 1 {1 v(sq) -} 0.75 falling 1]]] \
              [mt_is $a [expr {[lindex [mt_derive_x $t0 $iv 0.75 falling] 0] - $xa}]] \
              [near [expr {[lindex [mt_derive_x $t0 $iv 0.75 falling] 0] - $xa}] \
                    [expr {$xb - $xa - 4.0e-3}] $MTTOL]] {measured ok ok}
    check "MT5 T3 moving ONLY side B's direction moves the answer to a value DISTINCT at MTTOL from the one before, which is what makes the direction per-side rather than shared" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.3 rising 1 {1 v(sq) -} 0.75 rising 2]]] \
              [mt_is $a [expr {[lindex [mt_derive_x $t0 $iv 0.75 rising] 1] - $xa}]] \
              [mt_distinct [lindex [mt_derive_x $t0 $iv 0.75 rising] 1] \
                           [lindex [mt_derive_x $t0 $iv 0.75 falling] 1]]] \
        {measured ok distinct}
    check "MT5 T3 moving ONLY side B's level moves the answer to a value DISTINCT at MTTOL from the one before, which is what makes the level per-side rather than shared" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.3 rising 1 {1 v(sq) -} 0.25 falling 2]]] \
              [mt_is $a [expr {[lindex [mt_derive_x $t0 $iv 0.25 falling] 1] - $xa}]] \
              [mt_distinct [lindex [mt_derive_x $t0 $iv 0.25 falling] 1] \
                           [lindex [mt_derive_x $t0 $iv 0.75 falling] 1]]] \
        {measured ok distinct}
    check "MT5 T3 moving ONLY side A's level moves the answer, so the independence is not one-sided" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.75 rising 1 {1 v(sq) -} 0.75 falling 2]]] \
              [mt_is $a [expr {$xb - [lindex [mt_derive_x $t0 $q0 0.75 rising] 0]}]]] {measured ok}
    # ⚠ THE DATASET `delay` ACTUALLY READS, which this band used not to measure at
    # all: the only dataset arguments anywhere in this file for `delay` were the two
    # BAD ones in MT7, so a verb that accepted the argument and read dataset 0
    # passed.  `v(div)` discriminates by DISPOSITION, as in MT2: the 4.03 level is
    # inside v(ramp)/2 and above v(ramp)/4.
    check "MT5 D12 the dataset is READ by delay too: both sides of the same v(div) measurement answer in dataset 0, against THAT dataset's columns, and the same call is ABSENT in dataset 1 where v(ramp)/4 never reaches the second side's level" \
        [list [mt_disp [set a [mt_call delay {v(div)} 1.03 rising 1 {v(div)} 4.03 rising 1 0]]] \
              [mt_is $a [expr {[lindex [mt_derive_x $t0 [mt_col {v(div)} 0] 4.03 rising] 0] \
                               - [lindex [mt_derive_x $t0 [mt_col {v(div)} 0] 1.03 rising] 0]}]] \
              [mt_key $a dataset] \
              [mt_disp [set b [mt_call delay {v(div)} 1.03 rising 1 {v(div)} 4.03 rising 1 1]]] \
              [mt_key $b dataset] \
              [llength [mt_derive_x [mt_col time 1] [mt_col {v(div)} 1] 4.03 rising]]] \
        {measured ok 0 absent 1 0}
    check "MT5 the band left no __calc_tmp* and no __mt_* behind" [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT6 {
    # T3's second half, and the row an over-cautious implementation fails: WHEN
    # THE SECOND EDGE PRECEDES THE FIRST, THE ANSWER IS NEGATIVE AND IS
    # RETURNED.  That follows from a standing project rule rather than taste --
    # ADE-L is a FLOOR, so a restriction ADE-L does not have is a defect, and
    # refusing a negative delay would be exactly such a restriction.
    pcall mt_load tran
    set t0 [mt_col time 0]
    set q0 [mt_col {v(sq)} 0]
    set iv [mt_addcol __mt_inv {1 v(sq) -} 0]
    set xa [lindex [mt_derive_x $t0 $q0 0.3 rising] 0]
    set xb [lindex [mt_derive_x $t0 $iv 0.75 falling] 1]
    check "MT6 T3 swapping the two sides of a positive delay answers MEASURED with the exact negation -- not refused, not absent, and not the absolute value" \
        [list [mt_disp [set a [mt_call delay {1 v(sq) -} 0.75 falling 2 {v(sq)} 0.3 rising 1]]] \
              [mt_is $a [expr {$xa - $xb}]] \
              [expr {[mt_finite [mt_val $a]] ? ([mt_val $a] < 0) : {NOTANUMBER}}]] \
        {measured ok 1}
    check "MT6 T3 ...and the two directions compose to zero, both sides measured, which is the identity an implementation returning an absolute value breaks" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.3 rising 1 {1 v(sq) -} 0.75 falling 2]]] \
              [mt_disp [set b [mt_call delay {1 v(sq) -} 0.75 falling 2 {v(sq)} 0.3 rising 1]]] \
              [expr {([mt_finite [mt_val $a]] && [mt_finite [mt_val $b]])
                     ? [near [expr {[mt_val $a] + [mt_val $b]}] 0.0 $MTTOL] : {NOTANUMBER}}]] \
        {measured measured ok}
    check "MT6 T3 a second negative, from a later occurrence on side A than on side B -- the falling 50% crossing of the first period measured against the third rising one, which is a span backwards across most of the sweep" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.5 rising 3 {v(sq)} 0.5 falling 1]]] \
              [mt_is $a [expr {[lindex [mt_derive_x $t0 $q0 0.5 falling] 0] \
                               - [lindex [mt_derive_x $t0 $q0 0.5 rising] 2]}]] \
              [expr {[mt_finite [mt_val $a]] ? ([mt_val $a] < 0) : {NOTANUMBER}}]] \
        {measured ok 1}
    check "MT6 T3 ...and a negative delay reached from the END of the sweep, so the sign is not an artefact of how the occurrence was counted" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.5 rising -1 {v(sq)} 0.5 falling -1]]] \
              [mt_is $a [expr {[lindex [mt_derive_x $t0 $q0 0.5 falling] end] \
                               - [lindex [mt_derive_x $t0 $q0 0.5 rising] end]}]] \
              [expr {[mt_finite [mt_val $a]] ? ([mt_val $a] < 0) : {NOTANUMBER}}]] \
        {measured ok 1}
    check "MT6 T3 a ZERO delay is measured too, not treated as an absence: the same edge on both sides" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.5 rising 1 {v(sq)} 0.5 rising 1]]] \
              [expr {[mt_finite [mt_val $a]] ? [near [mt_val $a] 0.0 $MTTOL] : {NOTANUMBER}}]] \
        {measured ok}
    check "MT6 the band left no __calc_tmp* and no __mt_* behind" [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT7 {
    # Absence propagates; a refusal composes; and the two stay distinct, which
    # is the whole reason D7 keeps them apart -- a verb layered on `delay` has
    # to be able to tell a meaningless request from an unanswerable one.  The band
    # ends with `nth` 0 on a side, which is T5's hazard class arriving at `delay`:
    # `cross` answers it with SUCCESS AND A LIST, and a verb that subtracted would
    # raise rather than refuse.
    pcall mt_load tran
    check "MT7 R414b an occurrence side A has not got makes the whole answer ABSENT, carrying a sentence -- not measured, not refused, and not a number a caller could arithmetic on" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.5 rising 99 {v(sq)} 0.5 falling 1]]] \
              [mt_shape [mt_msg $a]] [mt_finite [mt_val $a]]] {absent ok 0}
    check "MT7 R414b ...and an occurrence side B has not got does the same, so the propagation is not one-sided" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.5 rising 1 {v(sq)} 0.5 falling 99]]] \
              [mt_shape [mt_msg $a]] [mt_finite [mt_val $a]]] {absent ok 0}
    check "MT7 R414b ...and a level no sample reaches is an absence on either side, which is the same empty-crossing-list hazard MT9 fences for dutyCycle arriving at delay instead" \
        [list [mt_disp [mt_call delay {v(sq)} 2.0 rising 1 {v(sq)} 0.5 falling 1]] \
              [mt_disp [mt_call delay {v(sq)} 0.5 rising 1 {v(sq)} 2.0 falling 1]]] {absent absent}
    check "MT7 D7 a side's edge that cannot be interpreted REFUSES, and the refusal is distinct from the absence above -- from either side" \
        [list [mt_disp [set a [mt_call delay {v(sq)} 0.5 sideways 1 {v(sq)} 0.5 falling 1]]] \
              [mt_shape [mt_msg $a]] \
              [mt_disp [mt_call delay {v(sq)} 0.5 rising 1 {v(sq)} 0.5 sideways 1]]] \
        {refused ok refused}
    check "MT7 D7 ...and so do a non-finite level, a non-integer occurrence and an empty expression, each from either side" \
        [list [mt_disp [mt_call delay {v(sq)} nan rising 1 {v(sq)} 0.5 falling 1]] \
              [mt_disp [mt_call delay {v(sq)} 0.5 rising 1.5 {v(sq)} 0.5 falling 1]] \
              [mt_disp [mt_call delay {} 0.5 rising 1 {v(sq)} 0.5 falling 1]] \
              [mt_disp [mt_call delay {v(sq)} 0.5 rising 1 {} 0.5 falling 1]]] \
        {refused refused refused refused}
    check "MT7 D12 an out-of-range dataset is refused before any accessor sees it, because issue 1632 is an out-of-bounds read behind it, and allpoints is refused on its own account" \
        [list [mt_disp [mt_call delay {v(sq)} 0.5 rising 1 {v(sq)} 0.5 falling 1 7]] \
              [mt_disp [mt_call delay {v(sq)} 0.5 rising 1 {v(sq)} 0.5 falling 1 -1]]] \
        {refused refused}
    # ⚠ MT9's HAZARD CLASS ARRIVING ONE VERB OVER, AND A DISPOSITION THE CONTRACT
    # DOES NOT STATE, SO THIS FILE STATES IT.  `calc::cross` answers nth 0 with
    # SUCCESS AND A LIST (MT0 measures that), and a `delay` that subtracted the two
    # sides would reach `can't use non-numeric string as operand of "-"` -- measured
    # on a conforming reference built straight from TIMING_CONTRACT, which is the
    # point: nothing in the contract requires either disposition, so an implementer
    # may pick neither and ship the raise.  The choice here is `cross_scalar`'s own:
    # DEFER behind the same `listdefer` sentence, because the request is for a wave
    # on at least one side and `delay` has no wave to subtract from.  The row
    # asserts the identity with cross's sentence, never the words.
    check "MT7 D8 nth 0 on EITHER side of delay is REFUSED rather than raising out of the subtraction, carrying the very sentence calc::cross_scalar defers nth 0 behind -- not measured, not absent, and never a Tcl error reaching the caller" \
        [list [string match RAISED:* [set a [mt_call delay {v(sq)} 0.5 rising 0 {v(sq)} 0.5 falling 1]]] \
              [mt_disp $a] [string equal [mt_msg $a] [pcall calc::cross_msg listdefer]] \
              [string match RAISED:* [set b [mt_call delay {v(sq)} 0.5 rising 1 {v(sq)} 0.5 falling 0]]] \
              [mt_disp $b] [string equal [mt_msg $b] [pcall calc::cross_msg listdefer]]] \
        {0 refused 1 0 refused 1}
    check "MT7 R402 NO __calc_tmp* survives any of this band's absent or refusing paths" \
        [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT8 {
    # R416 and T4.  A WAVE, one value per cycle; a FRACTION, never a percent;
    # the level read rather than assumed; a named cycle as a scalar; and the
    # trailing PARTIAL period EXCLUDED.
    #
    # ⚠ THE FIRST HALF OF THIS BAND IS ON `v(sq)` AND `v(sq)` CANNOT FENCE TWO OF
    # ITS OWN CLAIMS, which was measured rather than noticed.  Its two complete
    # periods have IDENTICAL duty at every level, so "one value per cycle" was
    # satisfied by a verb computing one duty and repeating it; and its trailing
    # rising crossing has no FALLING crossing after it, so the trailing-partial
    # exclusion was satisfied by a verb that closes the last period at the end of
    # the sweep.  Both defects answered the right COUNT for the wrong reason.  The
    # second half of the band therefore drives the INVERTED square (whose trailing
    # crossing does have a fall after it) and the GLITCH column (whose periods are
    # different widths), plus the divider-offset square for the dataset.
    pcall mt_load tran
    set t0 [mt_col time 0]
    set q0 [mt_col {v(sq)} 0]
    check "MT8 R416 calc::dutyCycle exists -- NOPROC here is the whole of this band's red" \
        [llength [pcall info procs ::calc::dutyCycle]] 1
    check "MT8 R416 the default answers a WAVE: one value per COMPLETE cycle, two of them for this sweep, each the deck's own (1.4-0.4L)/4 at level 0.5 -- which MT1 has already shown agrees with the columns" \
        [list [mt_disp [set a [mt_call dutyCycle {v(sq)} 0.5]]] \
              [mt_islist $a [list [sq_duty 0.5] [sq_duty 0.5]]]] {measured ok}
    # ⚠ T4's row.  The percent spelling is enumerated and rejected, rather than
    # the row asserting in its name that it would be.
    check "MT8 T4 the answer is a FRACTION and not a percent: the series matches the deck fraction and is DISTINCT at MTTOL from the hundred-times spelling of itself, which is what makes the shipped catalogue sentence about a fraction of a period true" \
        [list [mt_disp [set a [mt_call dutyCycle {v(sq)} 0.5]]] \
              [mt_islist $a [list [sq_duty 0.5] [sq_duty 0.5]]] \
              [mt_notlist $a [list [expr {100.0*[sq_duty 0.5]}] [expr {100.0*[sq_duty 0.5]}]]]] \
        {measured ok distinct}
    check "MT8 T4 the LEVEL is read: at 0.3 and at 0.75 the series matches the deck formula AT THAT LEVEL, and the three levels' fractions are DISTINCT at MTTOL, so a verb hardcoding the 50% threshold cannot pass all three" \
        [list [mt_islist [mt_call dutyCycle {v(sq)} 0.3]  [list [sq_duty 0.3] [sq_duty 0.3]]] \
              [mt_islist [mt_call dutyCycle {v(sq)} 0.75] [list [sq_duty 0.75] [sq_duty 0.75]]] \
              [mt_distinct [sq_duty 0.3] [sq_duty 0.5]] \
              [mt_distinct [sq_duty 0.75] [sq_duty 0.5]]] \
        {ok ok distinct distinct}
    # ⚠ `mt_len` ALONE CANNOT TELL A SCALAR FROM A ONE-ELEMENT LIST -- `llength` is
    # 1 for both -- so the scalar leg carries `mt_finite` as well, which is 0 for a
    # braced one-element list and 1 for a bare number.
    check "MT8 R416 naming a cycle answers a SCALAR -- a bare number, which mt_finite accepts and a one-element LIST would not, since llength cannot tell those two apart -- equal to that cycle's element of the default series, for cycle 1 and cycle 2 each" \
        [list [mt_disp [set a [mt_call dutyCycle {v(sq)} 0.5 1]]] [mt_len [mt_val $a]] \
              [mt_finite [mt_val $a]] [mt_is $a [lindex [mt_duty_series $t0 $q0 0.5] 0]] \
              [mt_disp [set b [mt_call dutyCycle {v(sq)} 0.5 2]]] [mt_len [mt_val $b]] \
              [mt_finite [mt_val $b]] [mt_is $b [lindex [mt_duty_series $t0 $q0 0.5] 1]] \
              [mt_len [mt_val [mt_call dutyCycle {v(sq)} 0.5]]]] \
        {measured 1 1 ok measured 1 1 ok 2}
    # T4's exclusion row.  `v(sq)` has THREE rising 50 % crossings and the
    # third opens no period, so a series of three would be reporting a duty
    # cycle for a cycle that never completed.
    #
    # ⚠⚠ AND THIS ROW ALONE IS NOT A FENCE, WHICH WAS MEASURED RATHER THAN
    # ARGUED.  The plausible wrong implementation -- close the last period AT THE
    # END OF THE SWEEP -- answers 2 here as well, because `v(sq)`'s third rising
    # 50 % crossing at 9.0 ms has no FALLING crossing after it inside the 10 ms
    # sweep, so the defect's extra period has no high time and drops out for a
    # reason that has nothing to do with the exclusion.  That is trap 7 exactly: a
    # fence keyed to a symptom that something else cures.  The row below is the
    # fence; this one is the shape claim it rests on.
    check "MT8 T4 the trailing PARTIAL period is EXCLUDED: the sweep holds three rising crossings of the level and the series holds two values, so the third crossing -- which has no rising crossing after it to close a period -- opens nothing" \
        [list [mt_disp [set a [mt_call dutyCycle {v(sq)} 0.5]]] [mt_len [mt_val $a]] \
              [llength [mt_derive_x $t0 $q0 0.5 rising]]] {measured 2 3}
    # THE FENCE FOR IT, on the INVERTED square, where the trailing rising crossing
    # IS followed by a falling one -- so a verb closing the last period at the end
    # of the sweep answers a second value and this row's count leg reddens.
    set iv [mt_addcol __mt_inv {1 v(sq) -} 0]
    check "MT8 T4 ...and on the INVERTED square the exclusion is observable rather than accidental: its last rising crossing of the level IS followed by a falling one and by no further rising one, so the correct series holds ONE value while a verb closing the last period at the end of the sweep would hold two -- the counts and the value are both in this row, derived from the columns" \
        [list [llength [mt_derive_x $t0 $iv 0.5 rising]] \
              [llength [mt_derive_x $t0 $iv 0.5 falling]] \
              [mt_disp [set a [mt_call dutyCycle {1 v(sq) -} 0.5]]] \
              [mt_len [mt_val $a]] \
              [mt_islist $a [mt_duty_series $t0 $iv 0.5]]] \
        {2 3 measured 1 ok}
    # ⚠ R416's "ONE VALUE PER CYCLE" WAS FENCED IN SHAPE AND NEVER IN CONTENT.
    # Measured: every level the rows above ask about has IDENTICAL duty in both of
    # `v(sq)`'s complete periods, so a verb computing ONE duty and `lrepeat`ing it
    # to the period count passes all of them -- the named-cycle rows included,
    # because series[0] and series[1] are equal there.  The glitch column MT4
    # already builds and MT1 already fences has periods of DIFFERENT widths, so its
    # per-cycle values differ from each other, which fences the content AND the
    # ORDER of the series.
    set gl [mt_glitch]
    set g0 [mt_addcol __mt_glitch $gl 0]
    set Glo [sq_thr 0 1 12]
    set Ghi [sq_thr 0 1 88]
    check "MT8 R416 the series is ONE VALUE PER CYCLE and the values DIFFER between cycles, which is what a verb computing the first period's duty and repeating it cannot do: on the glitch column the two complete periods at the low threshold are different widths, so their fractions are DISTINCT at MTTOL and the row asserts them IN ORDER" \
        [list [mt_disp [set a [mt_call dutyCycle $gl $Glo]]] \
              [mt_islist $a [mt_duty_series $t0 $g0 $Glo]] \
              [mt_len [mt_val $a]] \
              [mt_distinct [lindex [mt_duty_series $t0 $g0 $Glo] 0] \
                           [lindex [mt_duty_series $t0 $g0 $Glo] 1]] \
              [mt_notlist $a [lrepeat 2 [lindex [mt_duty_series $t0 $g0 $Glo] 0]]]] \
        {measured ok 2 distinct distinct}
    check "MT8 R416 ...and at the HIGH threshold the same column opens three cycles whose last is the odd one out, so the series' LENGTH and its ORDER are both read off the column rather than off a period count -- a first-period value repeated three times is rejected here too" \
        [list [mt_disp [set a [mt_call dutyCycle $gl $Ghi]]] \
              [mt_islist $a [mt_duty_series $t0 $g0 $Ghi]] \
              [mt_len [mt_val $a]] \
              [mt_distinct [lindex [mt_duty_series $t0 $g0 $Ghi] 2] \
                           [lindex [mt_duty_series $t0 $g0 $Ghi] 0]] \
              [mt_notlist $a [lrepeat 3 [lindex [mt_duty_series $t0 $g0 $Ghi] 0]]]] \
        {measured ok 3 distinct distinct}
    # ⚠ THE DATASET `dutyCycle` ACTUALLY READS, which this band used not to pass at
    # all -- not a good one and not a bad one.  `v(sq)` is identical in both
    # transient datasets, so it cannot discriminate; `v(div)` is the fixture's
    # discriminator but is monotone and opens no cycle, so the column here is the
    # square OFFSET BY the divider, whose crossing times therefore move with the
    # dataset while its cycle structure does not.
    set dsq {v(sq) v(div) 10 / +}
    set s0 [mt_addcol __mt_dsq $dsq 0]
    set s1 [mt_addcol __mt_dsq $dsq 1]
    check "MT8 D12 the dataset is READ: the square offset by the divider has the same cycle structure in both datasets and DIFFERENT crossing times, so the two series are element-wise DISTINCT at MTTOL, each matching the columns of the dataset asked for, and each answer carries the dataset it read" \
        [list [mt_disp [set a [mt_call dutyCycle $dsq 0.5 0 0]]] \
              [mt_islist $a [mt_duty_series $t0 $s0 0.5]] [mt_key $a dataset] \
              [mt_disp [set b [mt_call dutyCycle $dsq 0.5 0 1]]] \
              [mt_islist $b [mt_duty_series [mt_col time 1] $s1 0.5]] [mt_key $b dataset] \
              [mt_notlist $b [mt_duty_series $t0 $s0 0.5]] \
              [mt_distinct [lindex [mt_duty_series $t0 $s0 0.5] 0] \
                           [lindex [mt_duty_series [mt_col time 1] $s1 0.5] 0]]] \
        {measured ok 0 measured ok 1 distinct distinct}
    check "MT8 D12 ...and a BAD dataset is REFUSED here too, from either end" \
        [list [mt_disp [set a [mt_call dutyCycle {v(sq)} 0.5 0 7]]] [mt_shape [mt_msg $a]] \
              [mt_disp [mt_call dutyCycle {v(sq)} 0.5 0 -1]]] {refused ok refused}
    check "MT8 T4 ...and naming the cycle the trailing crossing would have opened is ABSENT with a sentence, rather than a value computed against the end of the sweep" \
        [list [mt_disp [set a [mt_call dutyCycle {v(sq)} 0.5 3]]] [mt_shape [mt_msg $a]] \
              [mt_finite [mt_val $a]]] {absent ok 0}
    # ⚠ WHAT THIS ROW ASSERTS IS IDENTITY WITH `cross`'s SENTENCE, NEVER THE WORDS,
    # which is what R416 and D8 ask for -- one deferral sentence for every caller
    # waiting on a destination it has not got, so a landing destination retires one
    # string rather than one per caller.  ⚠ AND THE CALLERS ARE NOT ALL WAITING ON
    # THE SAME DESTINATION, which R419 is what changed: `cross`'s own `nth = 0`
    # answers a LIST of crossing times and wants spec R606's `Table` surface, while
    # THIS caller's default cycle and `calc::delay`'s `nth = 0` want a wave with its
    # own X axis, which `calc::wave_dest` builds.  The shared sentence is silent
    # about which, deliberately -- and that silence is what lets it stay shared.
    # But the identity DOES freeze a user-visible consequence worth
    # naming: that sentence opens *"Cross:"* and mentions *"nth 0"*, and a user who
    # clicked dutyCycle asked for neither.  THE WORDING IS UNRATIFIED, the `rule`
    # debt filed against `calc::eval_msg`'s sentences covers it, and if it is ever
    # ruled that each verb speaks for itself THIS ROW IS WHERE THAT LANDS -- it
    # reddens, and the fix is to compare against whatever the ruling makes the one
    # deferral sentence, not to drop the row.
    # ⚠⚠ STAGE J UNIT J1 INVERTED THE FIRST TWO LEGS OF THIS ROW, AND THE ROW WAS
    # NOT DROPPED.  It used to assert that the surface DEFERS the wave case
    # behind cross's own sentence; the wiring is exactly that reversal, which the
    # shipped comment above `calc::riseTime` predicted in those words.  What the
    # row asserts now is the other side of the same claim and is strictly more:
    # the default cycle MEASURES, it names a destination of its OWN under the
    # `__calc_dest` prefix, and `calc::cross_msg listdefer` was RETIRED for this
    # caller rather than REWORDED -- the identity leg is 0, not a comparison
    # against a new string -- so the sentence stays shared by the three callers
    # still waiting, which is what band WD9 of test_calc_wave_dest.tcl derives.
    # A re-deferral reddens here, and so does a wiring that answered a number
    # with no database behind it.
    #
    # ⚠ THE DESTINATION IS DROPPED BY THIS BAND AND NOT BY THE VERB.  Unit J1
    # deliberately does not drop on its success path -- a trace resolves the
    # database by registry NAME, so dropping would free what the user is looking
    # at -- so the slot survives the call, and the band removes it before its own
    # R402 row.  ⚠ Note that the R402 row CANNOT SEE it either way: `leaked` and
    # `probeleft` glob column names out of the CURRENT database, and a leaked
    # destination is a SLOT whose columns live in a database nobody switched to.
    # Band WD11 of test_calc_wave_dest.tcl counts slots, which is the only
    # instrument in this batch that can.
    check "MT8 D8 the UI surface NO LONGER defers the wave case: the DEFAULT cycle measures and names a REGISTERED destination of its own, while the shared sentence is RETIRED here rather than reworded -- so the identity leg is 0 for this caller and the three still waiting keep it unchanged -- and a NAMED cycle is the scalar it always was, with no destination key at all" \
        [list [mt_disp [set a [mt_call dutyCycle_scalar {v(sq)} 0.5]]] \
              [string equal [mt_msg $a] [pcall calc::cross_msg listdefer]] \
              [mt_destname [mt_key $a db]] \
              [mt_disp [set b [mt_call dutyCycle_scalar {v(sq)} 0.5 1]]] \
              [mt_is $b [lindex [mt_duty_series $t0 $q0 0.5] 0]] \
              [mt_key $b db]] {measured 0 named measured ok NOKEY-db}
    pcall calc::wave_dest_drop $a
    check "MT8 D7 a malformed request is refused here too, and stays distinct from the absence above" \
        [list [mt_disp [mt_call dutyCycle {v(sq)} nan]] \
              [mt_disp [mt_call dutyCycle {} 0.5]] \
              [mt_disp [mt_call dutyCycle {v(sq)} 0.5 1.5]]] {refused refused refused}
    check "MT8 R402 the band left no __calc_tmp* and no __mt_* behind, across its measured, absent and refusing paths" \
        [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT9 {
    # T5 -- the sharp edge this stage owns.  `calc::cross_scan`'s nth=0 arm
    # answers SUCCESS WITH AN EMPTY LIST for a level no sample reaches, which is
    # declared behaviour and fenced by name in the sibling suite.  dutyCycle is
    # its first real caller, and an empty crossing list reaching the period
    # arithmetic is exactly how that contract turns into a raise.
    pcall mt_load tran
    # the hazard, re-measured inside this band so the rows below are not
    # vacuous if the sibling behaviour ever changes.
    check "MT9 T5 the hazard this band exists for, re-measured here: calc::cross answers MEASURED with an EMPTY list at a level no sample reaches, so dutyCycle receives success and nothing to divide by" \
        [list [mt_disp [set a [mt_call cross {v(sq)} 2.0 0 rising]]] [mt_len [mt_val $a]]] \
        {measured 0}
    # ⚠ THE PRESENCE OF THE PROC IS THE FIRST ELEMENT HERE, AND IT HAS TO BE.
    # "does not raise and does not answer a number" is satisfied EXACTLY by
    # `mt_call`'s own NOPROC sentinel, so without the presence leg this row would
    # be green on a tree with no dutyCycle in it -- which is the sibling suite's
    # accidental passes arriving in this file.
    check "MT9 T5 THE GUARD, as the uncontroversial half: the proc exists, and at that level it does not RAISE and does not answer a number -- so whatever it reports, the empty crossing list never reached the period arithmetic" \
        [list [llength [pcall info procs ::calc::dutyCycle]] \
              [string match RAISED:* [set a [mt_call dutyCycle {v(sq)} 2.0]]] \
              [mt_finite [mt_val $a]]] {1 0 0}
    check "MT9 T5 THE GUARD'S DISPOSITION, which is THIS FILE'S CHOICE and not the contract's: the request is well formed and its answer does not exist, so D5 makes it ABSENT with a sentence rather than a measured empty wave" \
        [list [mt_disp [set a [mt_call dutyCycle {v(sq)} 2.0]]] [mt_shape [mt_msg $a]]] \
        {absent ok}
    check "MT9 T5 ...and a level crossed ONCE rising with no fall to close the period is the same absence by a different route: v(ramp) is monotone, so level 5 gives one rising crossing and no falling one at all" \
        [list [mt_disp [mt_call cross {v(ramp)} 5 0 rising]] \
              [mt_len [mt_val [mt_call cross {v(ramp)} 5 0 rising]]] \
              [mt_len [mt_val [mt_call cross {v(ramp)} 5 0 falling]]] \
              [mt_disp [mt_call dutyCycle {v(ramp)} 5]]] \
        {measured 1 0 absent}
    check "MT9 T5 ...and naming a cycle at an uncrossed level is absent too, by the same guard rather than by a second one" \
        [mt_disp [mt_call dutyCycle {v(sq)} 2.0 1]] absent
    check "MT9 T5 the same empty list reaching riseTime and delay is an absence rather than a raise, so the guard is not dutyCycle's alone" \
        [list [string match RAISED:* [mt_call riseTime {v(sq)} 2.0 3.0]] \
              [mt_disp [mt_call riseTime {v(sq)} 2.0 3.0]] \
              [string match RAISED:* [mt_call delay {v(sq)} 2.0 rising 1 {v(sq)} 0.5 falling 1]] \
              [mt_disp [mt_call delay {v(sq)} 2.0 rising 1 {v(sq)} 0.5 falling 1]]] \
        {0 absent 0 absent}
    check "MT9 the band left no __calc_tmp* and no __mt_* behind" [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT9b {
    # ISSUE 1639 -- `nth` 0 ARRIVING AT `riseTime`, WHICH IS A THIRD HAZARD CLASS
    # AND NOT EITHER OF THE TWO ALREADY FENCED ABOVE, which is why it is a band of
    # its own rather than two more rows in MT3 or MT9.  MT3's hazard is a request
    # that cannot be INTERPRETED at all.  MT9's is `cross` answering SUCCESS WITH
    # AN EMPTY LIST at a level no sample reaches.  THIS one is a NON-EMPTY list
    # arriving on the LOW side of a subtraction: `cross` with `nth` 0 answers
    # success and a list of every crossing, `riseTime` passed its own `nth`
    # straight through to the low-side measurement, and the subtraction then met a
    # list and RAISED -- `can't use non-numeric string as operand of "-"`, a Tcl
    # error reaching the caller where D7 requires an answer.
    #
    # ⚠ THE PROC'S OWN COMMENT CLAIMED THIS PATH WAS GUARDED, AND THE CLAIM WAS
    # TRUE OF ONE OF THE TWO OPERANDS.  The HIGH side is read with a literal 0, so
    # its list is covered by the test that reports an absence when no candidate is
    # found; the LOW side's comes from the caller's `nth` and nothing tested it.
    # The EMPTY-list case does NOT raise either, which is why this survived a
    # reviewer: at a swing nothing reaches, the loop finds no candidate and a clean
    # absence is reported, so a reader probing the degenerate cases first sees a
    # guard that appears to work.  The path is reachable only when the measurement
    # would otherwise have SUCCEEDED.
    #
    # THE DISPOSITION IS DEFERRAL BEHIND THE SHARED `listdefer` SENTENCE, joining
    # `calc::cross_scalar`, `calc::delay` and `calc::dutyCycle_scalar`, and this
    # file states the reason because no contract does.  The request is WELL FORMED
    # on the proc's own published meaning of `nth`: it selects the LOW crossing,
    # and the high one is DERIVED as the first strictly after it, so `nth` 0 names
    # exactly one rise time per low crossing -- a wave with its own X axis, with no
    # ambiguity for D7 to refuse.  A D7 refusal would say the request cannot be
    # interpreted, which is false and would have to be REVERSED as user-visible
    # behaviour when the surface lands; a deferral retires silently, which is the
    # whole reason `listdefer` is shared.  The rows below assert the identity with
    # `calc::cross_msg listdefer` and never its words, which are unratified.
    #
    # ⚠ WHICH ROWS HERE PASS ON THE PRE-FIX TREE, declared BY KIND so nobody reads
    # one as the band's red: the hazard re-measurement, which is about `cross` and
    # not about `riseTime`; the measuring control; the malformed-request ORDER row;
    # and the non-finite `nth` row.  The last two are not spare -- the order row
    # reddens if the guard is placed before the request validation, and the
    # non-finite row reddens if the guard drops its finiteness conjunct and trades
    # one raise for another.
    pcall mt_load tran
    check "MT9b the hazard this band exists for, re-measured here rather than quoted from the issue: calc::cross with nth 0 at a threshold v(sq) DOES reach answers MEASURED with a list of more than one crossing, so riseTime's low side receives success and a list where its subtraction wants one number" \
        [list [mt_disp [set a [mt_call cross {v(sq)} [sq_thr 0.0 1.0 10] 0 rising]]] \
              [mt_atleast [mt_len [mt_val $a]] 2]] \
        {measured atleast2}
    check "MT9b 1639/J2 riseTime with nth 0 still ANSWERS instead of raising -- no Tcl error escapes to the caller, which is what can't use non-numeric string as operand of \"-\" was doing -- and stage J unit J2 made that answer a MEASURED SERIES rather than the deferral 1639 shipped: more than one Y, a PARALLEL sweep of the same length, and a value that is still not a single finite number, so a verb that silently truncated the series to its first element reddens here instead of looking like a success" \
        [list [string match RAISED:* [set a [mt_call riseTime {v(sq)} 0.0 1.0 10 90 0]]] \
              [mt_disp $a] [mt_finite [mt_val $a]] \
              [mt_atleast [mt_len [mt_val $a]] 2] \
              [mt_sized [mt_len [mt_key $a sweep]] [mt_len [mt_val $a]]]] \
        {0 measured 0 atleast2 sized}
    check "MT9b 1639/J2 the shared sentence is RETIRED for this caller rather than reworded: riseTime's nth 0 no longer carries calc::cross_msg listdefer -- the identity leg is 0 and so is the pairwise one against delay, which is STILL DRIVEN here and still deferring, so the row cannot go green by both callers falling silent together -- and the sentence delay carries is still the shared one in the house shape.  A wiring that measured while still carrying the deferral sentence reddens here, and so does one that split the string per caller" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0.0 1.0 10 90 0]]] \
              [string equal [mt_msg $a] [pcall calc::cross_msg listdefer]] \
              [string equal [mt_msg $a] \
                   [mt_msg [set b [mt_call delay {v(sq)} 0.5 rising 0 {v(sq)} 0.5 falling 1]]] ] \
              [mt_disp $b] \
              [string equal [mt_msg $b] [pcall calc::cross_msg listdefer]] \
              [mt_shape [mt_msg $b]]] \
        {measured 0 0 refused 1 ok}
    check "MT9b 1639/J2 the arm reads the ordinal's VALUE and not its SPELLING, which is the same reason cross's own badnth test is integer-VALUED: 0, 0.0, -0 and 0e0 all name the ordinal zero on the published contract, so each must now reach the SAME SERIES -- measured ELEMENT FOR ELEMENT against the 0 spelling's own answer and not merely by disposition, so a dispatch that matched the literal 0 as a string and fell through to the scalar path for the other three reddens naming the spelling.  None of the four carries the retired deferral sentence" \
        [list [lsort -unique [lmap n {0 0.0 -0 0e0} {mt_disp [mt_call riseTime {v(sq)} 0.0 1.0 10 90 $n]}]] \
              [lsort -unique [lmap n {0 0.0 -0 0e0} {mt_islist \
                   [mt_call riseTime {v(sq)} 0.0 1.0 10 90 $n] \
                   [mt_val [mt_call riseTime {v(sq)} 0.0 1.0 10 90 0]]}]] \
              [lsort -unique [lmap n {0 0.0 -0 0e0} {string equal \
                   [mt_msg [mt_call riseTime {v(sq)} 0.0 1.0 10 90 $n]] \
                   [pcall calc::cross_msg listdefer]}]]] \
        {measured ok 0}
    check "MT9b 1639/J2 nth 0 now OPENS the engine door it needs and leaves no name behind: where the deferral carried an EMPTY dest -- it answered before reaching the database at all -- the series carries the __calc_tmp name cross minted for it, exactly as the ABSENCE at a swing nothing reaches already did, and R402 has deleted both so neither survives in the inventory.  The two legs that watch the inventory are what stop this row reading as permission to leak" \
        [list [string match __calc_tmp* \
                   [mt_key [mt_call riseTime {v(sq)} 0.0 1.0 10 90 0] dest]] \
              [string match __calc_tmp* \
                   [mt_key [mt_call riseTime {v(sq)} 100.0 200.0 10 90 1] dest]] \
              [leaked] [probeleft]] \
        {1 1 {} {}}
    check "MT9b 1639 a request that is ALSO malformed is refused as MALFORMED and never deferred, which is this file's ordering choice because no contract states one: a deferral promises an answer once a destination lands, and an omitted swing or a zero swing will still be malformed then -- so each carries its own builder's sentence by identity and neither carries listdefer" \
        [list [string equal [mt_msg [set a [mt_call riseTime {v(sq)} {} {} 10 90 0]]] \
                   [pcall calc::cross_msg noswing {} {}]] \
              [string equal [mt_msg $a] [pcall calc::cross_msg listdefer]] \
              [string equal [mt_msg [set b [mt_call riseTime {v(sq)} 0.5 0.5 10 90 0]]] \
                   [pcall calc::cross_msg zeroswing 0.5]] \
              [string equal [mt_msg $b] [pcall calc::cross_msg listdefer]] \
              [mt_disp $a] [mt_disp $b]] \
        {1 0 1 0 refused refused}
    check "MT9b 1639 a non-finite or non-numeric nth keeps cross's OWN badnth refusal and does not get the deferral, which is what the guard's finiteness conjunct buys: converting the argument to a double raises on a non-numeric operand, so a guard written without that conjunct trades one raise for another" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0.0 1.0 10 90 nan]]] \
              [string equal [mt_msg $a] [pcall calc::cross_msg badnth nan]] \
              [string equal [mt_msg $a] [pcall calc::cross_msg listdefer]] \
              [string match RAISED:* [set b [mt_call riseTime {v(sq)} 0.0 1.0 10 90 zz]]] \
              [string equal [mt_msg $b] [pcall calc::cross_msg badnth zz]]] \
        {refused 1 0 0 1}
    check "MT9b 1639 the CONTROL that the guard swallows nothing: nth 1 and nth -1 still MEASURE, each equal to the deck's own edge width times the separation of the two supplied-swing thresholds, so a guard refusing every occurrence would redden here" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0.0 1.0 10 90 1]]] \
              [near [mt_val $a] [sq_rt 0.0 1.0 10 90] $MTTOL] \
              [mt_disp [set b [mt_call riseTime {v(sq)} 0.0 1.0 10 90 -1]]] \
              [near [mt_val $b] [sq_rt 0.0 1.0 10 90] $MTTOL]] \
        {measured ok measured ok}
    check "MT9b 1639 ...and D5's ABSENCE is still an absence rather than the new deferral: an occurrence this sweep has not got answers absent with its own sentence, from either end, so the guard did not convert one disposition into the other" \
        [list [mt_disp [set a [mt_call riseTime {v(sq)} 0.0 1.0 10 90 99]]] \
              [string equal [mt_msg $a] [pcall calc::cross_msg listdefer]] \
              [mt_disp [mt_call riseTime {v(sq)} 0.0 1.0 10 90 -99]]] \
        {absent 0 absent}
    check "MT9b R402 NO __calc_tmp* and no __mt_* survives this band's deferring, refusing, absent and measured paths" \
        [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
group MT9c {
    # STAGE J UNIT J2 -- `riseTime`'s `nth` 0 STOPS DEFERRING AND ANSWERS THE
    # PER-EDGE RISE TIME SERIES: one rise time per rising edge, as a wave with
    # its own X axis.  This band is the VERB half and it gates on the COUNTED
    # arm; the DESTINATION half -- the registered two-column database, its
    # read-back, the slot bookkeeping and the undropped slot -- is band WD13 of
    # tests/headless/test_calc_wave_dest.tcl, and the click's buffer and status
    # behaviour is display-only and belongs to band S28 of
    # tests/headless/test_calc_skeleton.tcl.  Nothing here calls
    # `calc::wave_dest`, so nothing here needs the registry.
    #
    # Spec     doc/claude/specs/calculator.md §7.2ac (R419-R421) and §7.2ab
    #          (R415, R416's two-destinations correction).
    # Contract doc/claude/calculator_batch/WIRING_CONTRACT.md §11 (unit J1, the
    #          worked producer) and §13 (unit J1b).  §7.1 and §7.2 carry the two
    #          traps this band measures rather than quotes.
    #
    # ⚠⚠ THE COLUMN IS `{v(sq) v(ramp) *}` AND NEITHER OF THE TWO OBVIOUS ONES,
    # AND THAT IS A MEASUREMENT RATHER THAN A PREFERENCE.  `riseTime`'s per-edge
    # series on `v(sq)` has all three of its edges agreeing to a RELATIVE 4.5e-14
    # -- the square is periodic and every edge has the same width -- and on
    # `v(lp)` the last two agree to 2.2e-11, because the pole is in periodic
    # steady state after the first edge.  Both are inside this file's own MTTOL
    # of 1e-7, so on EITHER column a Y written backwards, or filled with its own
    # first element, passes an element-wise comparison.  That is issue 1643's
    # finding arriving at a second verb, and this band answers it the way the
    # contract's §10(a) requires: the column that discriminates is driven, the
    # ones that do not are named, and the DISTINCTNESS is asserted in the run by
    # a row that also shows the instrument can still answer `same`.
    #
    # The product of the square and the ramp scales each edge by the ramp's
    # value there, so against FIXED absolute thresholds the three edges have
    # three different widths: adjacent relative differences of 3.6 and 0.80,
    # seven orders outside MTTOL.  Its X values are three low crossings a factor
    # of ten apart.
    #
    # ⚠ THREE POINTS, WHICH IS THE FIRST TIME THIS STAGE HAS HAD MORE THAN TWO.
    # Unit J1 declared its own ceiling: `dutyCycle`'s series on this fixture is
    # two points, and two cannot carry a middle element at all, so a dropped
    # middle sample, a rotation told apart from a reversal, and an X misordered
    # anywhere but end-to-end are all invisible there.  The row below builds
    # those fills FROM the correct series and asserts, in the run, that a
    # two-point reversal and a two-point rotation are THE SAME LIST while the
    # three-point ones are not -- so the third point's value is measured here
    # rather than claimed.
    #
    # ⚠ WHICH ROWS HERE PASS WITH NO FEATURE PRESENT, declared BY KIND so nobody
    # reads one as the band's red: the `cross` re-measurement that establishes
    # the edge count, the family-instrument control, and the band's own R402
    # inventory.  The partial-drop row's non-vacuity legs pass too; its
    # disposition legs do not.
    pcall mt_load tran
    set rtR {v(sq) v(ramp) *}
    set rtLO 0
    set rtHI 1
    set rtPL 10
    set rtPH 90
    set rtTLO [mt_rt_thr $rtLO $rtHI $rtPL]
    set rtTHI [mt_rt_thr $rtLO $rtHI $rtPH]
    set rtT [mt_col time 0]
    # DERIVATION 2, over the two committed columns with no engine in it.
    set rtTCL [mt_prod [mt_col v(sq) 0] [mt_col v(ramp) 0]]
    set rtENG [mt_addcol __mt_rtprod $rtR 0]
    set rtD [mt_rt_derive $rtT $rtTCL $rtLO $rtHI $rtPL $rtPH]
    set rtDY [mt_rt_y $rtD]
    set rtDX [mt_rt_x $rtD]
    # ...and the edge count read back off `calc::cross` itself, so no row below
    # writes down how many edges this fixture has.
    set rtLOW [mt_call cross $rtR $rtTLO 0 rising 0]
    set rtNLOW [mt_len [mt_val $rtLOW]]
    check "MT9c the edge count this band's rows are sized against is read back off calc::cross with a literal 0 rather than written down, and the fixture really has more than two rising edges at the LOW threshold a supplied swing names -- which is what makes the third-point rows below possible at all" \
        [list [mt_disp $rtLOW] [mt_atleast $rtNLOW 3] [mt_sized [llength $rtDY] $rtNLOW]] \
        {measured atleast3 sized}
    check "MT9c R419/R416 riseTime with nth 0 MEASURES the per-edge series instead of deferring: one Y per rising edge and a PARALLEL X of the same length, both sized against the low-crossing count calc::cross answers rather than against a number, and the X is calc::cross's own low-crossing list element for element -- so a verb that answered the HIGH crossings, or the midpoints, reddens on the X leg naming every offending element" \
        [list [mt_disp [set a [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH 0]]] \
              [mt_sized [mt_len [mt_val $a]] $rtNLOW] \
              [mt_sized [mt_len [mt_key $a sweep]] $rtNLOW] \
              [mt_listcmp [mt_key $a sweep] [mt_val $rtLOW]] \
              [mt_finite [mt_val $a]] \
              [mt_nonneg [mt_val $a]]] \
        {measured sized sized ok 0 nonneg}
    # ⚠⚠ THE ROW ABOVE IS BLIND TO WHICH WAY THE TWO CROSSING LISTS WERE
    # PAIRED, AND SO IS EVERY OTHER ROW IN EITHER SUITE.  That was measured, not
    # feared: a producer driving the HIGH list and pairing each high crossing
    # with the last low crossing before it answers one point per COMPLETED
    # TRANSITION instead of one per RISING EDGE, keeps X a low crossing, keeps Y
    # a high-minus-low difference, drops the same trailing points and reaches the
    # same absence -- and passes `test_calc_measure`, `test_calc_wave_dest`,
    # `test_calc_cross`, `test_calc_engine`, `test_calc_scratch_reuse` and all
    # four display-arm suites with every check count unmoved.  The reason is in
    # `mt_ringfloor`'s banner: on `{v(sq) v(ramp) *}` the two crossing lists
    # interleave strictly one for one, and under strict 1:1 interleaving the two
    # directions are provably the same list.
    #
    # What a user meets is a single rising edge with overshoot ringing -- the
    # commonest real transient there is.  Correct is one rise time; the wrong
    # pairing answers one per ring peak, every one of them plotted at the SAME X,
    # and the later ones are not rise times at all but the time from the edge's
    # start to the second and third peaks.
    #
    # THE REQUEST IS THEREFORE A RINGING SIGNAL, minted here because no
    # committed column has `nhigh > nlow` at any level pair -- the band's own
    # non-vacuity legs assert that it does, so the row cannot go quiet if the
    # fixture is regenerated.  The comparand is the same Tcl-side derivation the
    # rows above lean on, driven on the one shape where the two pairing
    # directions disagree, and the engine's own column is asserted against the
    # Tcl one in the run so the two derivations cannot silently become one.
    set rgN 3
    set rgLO [mt_ringfloor]
    set rgHI 1
    set rgRPN [mt_ringrpn $rtT $rgN]
    set rgTCL [mt_ringcol $rtT $rgN]
    set rgENG [mt_addcol __mt_rtring $rgRPN 0]
    set rgD [mt_rt_derive $rtT $rgTCL $rgLO $rgHI $rtPL $rtPH]
    check "MT9c THE PAIRING DIRECTION, on the one shape that can see it: a signal that RINGS at the top crosses its HIGH threshold more often than its LOW one, and a rise time is one measurement per RISING EDGE -- so the series is sized against the LOW-crossing count, its X is the low-crossing list element for element, no two of its points share an X, and the X is strictly increasing.  Three non-vacuity legs say the shape really is the one that discriminates: more than one edge, the high level crossed strictly more often than the low one, and not one point dropped -- so a producer that drove the HIGH list, pairing each high crossing with the last low before it, reddens on the count AND on the duplicated X instead of passing as it does on every other request in this band" \
        [list [mt_cmpword $rgENG $rgTCL] \
              [mt_disp [set rga [mt_call riseTime $rgRPN $rgLO $rgHI $rtPL $rtPH 0]]] \
              [mt_atleast [mt_rt_nlo $rgD] 2] \
              [mt_excess [mt_rt_nhi $rgD] [mt_rt_nlo $rgD] 1] \
              [mt_sized [mt_len [mt_rt_y $rgD]] [mt_rt_nlo $rgD]] \
              [mt_sized [mt_len [mt_val $rga]] [mt_rt_nlo $rgD]] \
              [mt_islist $rga [mt_rt_y $rgD]] \
              [mt_listcmp [mt_key $rga sweep] [mt_rt_x $rgD]] \
              [mt_nodup [mt_key $rga sweep]] \
              [mt_increasing [mt_key $rga sweep]]] \
        {same measured atleast2 atleast1 sized sized ok ok nodup increasing}
    check "MT9c T2 the series IS the scalar path, edge by edge: riseTime at nth 1, 2 ... up to the derived edge count each MEASURES one number, and those numbers are the nth-0 series element for element -- a derivation that runs entirely through the ordinal path bands MT2 and MT4 already fence, so it shares no code with the series arm and a series assembled in the wrong ORDER reddens here" \
        [list [lsort -unique [lmap n [mt_seq 1 $rtNLOW] \
                   {mt_disp [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH $n]}]] \
              [mt_sized [llength [set rtSC [lmap n [mt_seq 1 $rtNLOW] \
                   {mt_val [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH $n]}]]] $rtNLOW] \
              [mt_islist [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH 0] $rtSC]] \
        {measured sized ok}
    check "MT9c ...and a SECOND derivation with no engine in it agrees: the element-wise product of the two committed columns computed in Tcl, crossed at the two supplied-swing thresholds by this file's own D3+D4, gives the same Y and the same X -- and the engine's own product column agrees with the Tcl one, asserted in the run so the two derivations cannot silently become one.  Both thresholds cross STRICTLY BETWEEN samples at every edge, so no snapping convention could have produced these numbers" \
        [list [mt_cmpword $rtENG $rtTCL] \
              [mt_islist [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH 0] $rtDY] \
              [mt_listcmp [mt_key [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH 0] sweep] $rtDX] \
              [mt_allstrict $rtT $rtTCL $rtTLO rising] \
              [mt_allstrict $rtT $rtTCL $rtTHI rising]] \
        {same ok ok strict strict}
    check "MT9c the series DISCRIMINATES, and the CONTROL is the two columns this band refuses to drive: every adjacent Y of the answer differs by more than MTTOL and so does every adjacent X, the X is strictly increasing over TWO comparisons rather than one -- and the SAME instrument over v(sq)'s own per-edge series answers `same`, while over v(lp)'s it answers one of each.  So the `distinct` above is a measurement of this fixture and not a constant, and the two blind columns are named by the row that would have been blind on them" \
        [list [mt_alldistinct [mt_val [set a [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH 0]]]] \
              [mt_alldistinct [mt_key $a sweep]] \
              [mt_increasing [mt_key $a sweep]] \
              [mt_alldistinct [mt_rt_y [mt_rt_derive $rtT [mt_col v(sq) 0] 0 1 10 90]]] \
              [mt_alldistinct [mt_rt_y [mt_rt_derive $rtT [mt_col v(lp) 0] 0 1 10 90]]]] \
        [list distinct distinct increasing same {distinct same}]
    check "MT9c THE THIRD POINT, measured rather than argued: against the very same element-wise comparison the rows above lean on, the series REVERSED, ROTATED BY ONE, with its MIDDLE replaced by the mean of the endpoints, and with its middle replaced by its left neighbour are each distinct from the answer while the unaltered derivation is the same -- and the last two legs show WHY two points could not have said it, because at two points a reversal and a rotation are the identical list and at three they are not" \
        [list [mt_cmpword [mt_val [set a [mt_call riseTime $rtR $rtLO $rtHI $rtPL $rtPH 0]]] [lreverse $rtDY]] \
              [mt_cmpword [mt_val $a] [mt_rot1 $rtDY]] \
              [mt_cmpword [mt_val $a] [mt_midmean $rtDY]] \
              [mt_cmpword [mt_val $a] [mt_midleft $rtDY]] \
              [mt_cmpword [mt_val $a] $rtDY] \
              [string equal [lreverse [lrange $rtDY 0 1]] [mt_rot1 [lrange $rtDY 0 1]]] \
              [string equal [lreverse $rtDY] [mt_rot1 $rtDY]]] \
        {distinct distinct distinct distinct same 1 0}
    # ⚠ A LOW CROSSING WITH NO HIGH CROSSING AFTER IT IS A PER-POINT HOLE AND THE
    # POINT IS DROPPED, which is unit J2's own disposition choice and is declared
    # here because no contract states one.  It follows from the driver's call on
    # the EMPTY series -- an absence is not an error -- applied once per point
    # rather than once per request: the series is one rise time per low crossing
    # THAT HAS a high crossing after it, and when every point drops the whole
    # answer becomes the absence the next two rows drive.  One rule, two
    # outcomes.  The alternative, refusing the series, would refuse every
    # transient that ends part way up its last edge, which is the common case
    # rather than the odd one.  Refusing instead reddens exactly this row.
    check "MT9c a low crossing with NO high crossing after it DROPS THAT POINT rather than refusing the series or padding it: the answer is shorter than the low-crossing list, equals the scalar path at the occurrences that DO complete, and the occurrence that does not is still the ABSENCE it always was -- with the non-vacuity leg asserting that a point really was dropped, so the row cannot be satisfied by a fixture that simply had fewer edges" \
        [list [mt_disp [set p [mt_call riseTime {v(lp)} 0 1 10 99.9 0]]] \
              [mt_sized [mt_len [mt_val $p]] [llength [mt_rt_y [set pd [mt_rt_derive $rtT [mt_col v(lp) 0] 0 1 10 99.9]]]]] \
              [mt_atleast [expr {[mt_rt_nlo $pd] - [llength [mt_rt_y $pd]]}] 1] \
              [mt_islist $p [mt_rt_y $pd]] \
              [mt_listcmp [mt_key $p sweep] [mt_rt_x $pd]] \
              [mt_nonneg [mt_val $p]] \
              [mt_disp [mt_call riseTime {v(lp)} 0 1 10 99.9 [mt_rt_nlo $pd]]]] \
        {measured sized atleast1 ok ok nonneg absent}
    # ⚠⚠ THE EMPTY SERIES IS AN ABSENCE AND NEVER A DESTINATION PROBLEM, which
    # is the driver's call and the one user-visible disposition this unit decides.
    # `calc::wave_dest` refuses an empty list with `destempty` -- *"an empty
    # result has nothing to put in a destination, so none was built"* -- a
    # sentence that is right about the mechanism and WRONG about what happened:
    # the signal never crossed.  So the verb answers the absence itself and the
    # surface never reaches the destination at all.
    #
    # THE WORDS ARE NOT ASSERTED.  They are unratified, the `rule` debt
    # `calc_wave_dest_empty_result_sentence` is filed against exactly this
    # sentence, and both of `calc::cross_msg`'s reusable arms carry an ORDINAL
    # that reads oddly for `nth` 0.  What the rows assert instead is derived: the
    # disposition, a NEGATIVE identity against `destempty`, and that the
    # sentence's family is one `calc::cross_msg` itself builds and is NOT
    # `destempty`'s -- so whichever arm the implementation reuses, and whatever
    # the ruling later says, no row here moves.
    check "MT9c R402/D7 a swing the signal never reaches at all answers an ABSENCE and not a destination problem: the disposition is absent, the sentence is NOT calc::cross_msg destempty by identity, its family is one calc::cross_msg itself builds and is NOT destempty's family -- and the SURFACE answers the same absence, with no db key, so the empty list never reaches calc::wave_dest at all: the last three legs are the ones that fence what the USER reads, because a wrapper that handed an empty list to the destination refuses with destempty and still carries no db key.  The non-vacuity leg asserts the low-crossing list really is empty, so this is the no-crossing shape and not the next row's" \
        [list [mt_disp [set e [mt_call riseTime {v(sq)} 100.0 200.0 10 90 0]]] \
              [string equal [mt_msg $e] [pcall calc::cross_msg destempty]] \
              [mt_infamily [mt_msg $e] [mt_crossmsg_families]] \
              [mt_notfamily [mt_msg $e] [pcall calc::cross_msg destempty]] \
              [mt_shape [mt_msg $e]] \
              [mt_sized [mt_rt_nlo [set ed [mt_rt_derive $rtT [mt_col v(sq) 0] 100.0 200.0 10 90]]] 0] \
              [mt_key [set se [mt_call riseTime_scalar {v(sq)} 100.0 200.0 10 90 0]] db] \
              [mt_disp $se] \
              [string equal [mt_msg $se] [pcall calc::cross_msg destempty]] \
              [mt_notfamily [mt_msg $se] [pcall calc::cross_msg destempty]]] \
        {absent 0 known elsewhere ok sized NOKEY-db absent 0 elsewhere}
    check "MT9c ...and the OTHER empty shape, which is a different cause and therefore a second row: low crossings EXIST and not one of them has a high crossing after it, so every point drops and the series is empty -- same absence at the verb AND at the surface, same negative identity against destempty at both, same family claim, still no db key, with two non-vacuity legs saying the low list is non-empty and the high list is empty so the row cannot be the one above wearing different arguments" \
        [list [mt_disp [set e [mt_call riseTime {v(lp)} 0 1 10 99.95 0]]] \
              [string equal [mt_msg $e] [pcall calc::cross_msg destempty]] \
              [mt_infamily [mt_msg $e] [mt_crossmsg_families]] \
              [mt_notfamily [mt_msg $e] [pcall calc::cross_msg destempty]] \
              [mt_atleast [mt_rt_nlo [set ed [mt_rt_derive $rtT [mt_col v(lp) 0] 0 1 10 99.95]]] 1] \
              [mt_sized [mt_rt_nhi $ed] 0] \
              [mt_key [set se [mt_call riseTime_scalar {v(lp)} 0 1 10 99.95 0]] db] \
              [mt_disp $se] \
              [string equal [mt_msg $se] [pcall calc::cross_msg destempty]] \
              [mt_notfamily [mt_msg $se] [pcall calc::cross_msg destempty]]] \
        {absent 0 known elsewhere atleast1 sized NOKEY-db absent 0 elsewhere}
    # ⚠⚠ AND A THIRD EMPTY SHAPE, WHICH THE TWO ROWS ABOVE ARE STRUCTURALLY
    # BLIND TO BECAUSE OF THEIR OWN NON-VACUITY LEGS.  Each pins its shape with
    # a crossing-list COUNT -- the first asserts the low list is empty, the
    # second that the high list is -- and those are precisely the two tests a
    # defensive implementer writes if the emptiness is guarded on the INPUT
    # lists instead of on the OUTPUT series.  The complement is both lists
    # NON-EMPTY and the series still empty, which happens whenever the only high
    # crossing lies BEFORE the only low one, and it was driven by nothing in the
    # tree: an implementation guarding the inputs ships the `destempty` sentence
    # for it and passes every suite in this batch on both arms.
    #
    # THE ORACLE IS THE SHIPPED ORDINAL PATH, not a third hand-picked shape and
    # not a sentence.  The SAME request at `nth` 1 already answers an absence
    # today, through code this unit does not touch, so the row asserts that
    # `nth` 0 agrees with it -- same disposition, and a sentence from the same
    # `calc::cross_msg` FAMILY.  One physical fact (this low crossing never
    # completes) must be reported in one voice whether the user asked for one
    # edge or for all of them.  That is a derivation over the shipped path, so
    # it cannot rot into a list of shapes, and it pins no words: the `rule` debt
    # `calc_wave_dest_empty_result_sentence` can reword the whole arm and both
    # sides of the comparison move together.
    #
    # ⚠ What the row DOES constrain, stated so nobody meets it as a surprise:
    # the `nth`-0 absence must reuse the family the ordinal path already uses
    # for the identical request, so reaching for `cross_msg absent` on one side
    # and `nohigh` on the other reddens here.  That is this unit's own internal
    # choice, declared rather than ruled.  ⚠ The `nth`-1 leg is green on the red
    # run, by construction -- it is the oracle, not the claim.
    set seR {v(ramp)}
    set seD [mt_rt_derive $rtT [mt_col v(ramp) 0] 1 0 10 90]
    set se0 [mt_call riseTime $seR 1 0 10 90 0]
    set se1 [mt_call riseTime $seR 1 0 10 90 1]
    set seS [mt_call riseTime_scalar $seR 1 0 10 90 0]
    check "MT9c ...and the THIRD empty shape, the one both rows above exclude by their own non-vacuity legs: the low list and the high list are BOTH non-empty and the series is still empty, because the only high crossing lies before the only low one.  The oracle is the SHIPPED ordinal path -- the same request at nth 1 is already an absence today -- so nth 0 must agree with it in disposition AND in calc::cross_msg family, must not be destempty's family, and the SURFACE must answer the same absence with no db key.  Three non-vacuity legs assert the shape: at least one low crossing, at least one high crossing, and a derived series of length zero" \
        [list [mt_disp $se0] [mt_disp $se1] \
              [mt_samefamily [mt_msg $se0] [mt_msg $se1]] \
              [mt_notfamily [mt_msg $se0] [pcall calc::cross_msg destempty]] \
              [mt_infamily [mt_msg $se0] [mt_crossmsg_families]] \
              [mt_atleast [mt_rt_nlo $seD] 1] \
              [mt_atleast [mt_rt_nhi $seD] 1] \
              [mt_sized [mt_len [mt_rt_y $seD]] 0] \
              [mt_disp $seS] [mt_key $seS db] \
              [mt_notfamily [mt_msg $seS] [pcall calc::cross_msg destempty]]] \
        {absent absent samefamily elsewhere known atleast1 atleast1 sized absent NOKEY-db elsewhere}
    check "MT9c the FAMILY INSTRUMENT the two absence rows lean on, derived over calc::cross_msg's own switch patterns and never listed: the arm set is large, it builds more than two distinct families, destempty's family is one of them -- so `elsewhere` above is a claim about a family that really exists -- a sentence with no colon in it answers a sentinel rather than a family, and two sentences from one family answer samefamily.  GREEN WITH NO FEATURE PRESENT, declared: it measures the instrument and not the verb" \
        [list [mt_atleast [llength [mt_crossmsg_arms]] 30] \
              [mt_atleast [llength [mt_crossmsg_families]] 3] \
              [mt_infamily [pcall calc::cross_msg destempty] [mt_crossmsg_families]] \
              [mt_infamily {nocolonhere} [mt_crossmsg_families]] \
              [mt_notfamily [pcall calc::cross_msg destempty] [pcall calc::cross_msg destlen]] \
              [mt_notfamily [pcall calc::cross_msg destempty] [pcall calc::cross_msg nohigh 1st]]] \
        [list atleast30 atleast3 known {unknown:NOFAMILY:{nocolonhere}} samefamily:Destination elsewhere]
    # ⚠⚠ MINTING `calc::riseTime_scalar` SILENTLY REDIRECTS EVERY CLICK ON
    # `riseTime`.  `calc::arg_surface` is literally *"if `::calc::<name>_scalar`
    # exists, return it"*, so the wrapper is not opt-in: the moment it exists,
    # MT11's surface-formals row starts asserting against it instead of against
    # the verb.  The wrapper is REQUIRED rather than optional, and that is a
    # measurement: `calc::wave_dest` issues an `xschem raw add` of its own, so
    # `mt_direct_raw wave_dest` answers `yes` and an engine door opened inside
    # `calc::riseTime` would make MT10's callee-ward closure print
    # `{{} {} wave_dest}` against `{}`.  The verb computes; the surface decides
    # where the answer goes.
    check "MT9c R412 the click's SURFACE for riseTime is the new wrapper, and its formals are calc::riseTime's own DERIVED on both sides rather than seven names written down -- so a wrapper that dropped a formal, renamed one, or gained one reddens here naming both lists.  The dialog's own answer then survives the walk: the user's nth 0 reaches arg_values, the composed call answers a DESTINATION, and the destination is dropped by this row so the band leaves no slot" \
        [list [mt_surface riseTime] \
              [mt_sameformals [mt_formals riseTime_scalar] [mt_formals riseTime]] \
              [mt_argval_of riseTime $rtR [list lo $rtLO hi $rtHI pctlo $rtPL pcthi $rtPH nth 0 dataset 0] nth] \
              [mt_sink [set iv [mt_arginvoke riseTime $rtR [list lo $rtLO hi $rtHI pctlo $rtPL pcthi $rtPH nth 0 dataset 0]]]] \
              [mt_sink [mt_arginvoke riseTime $rtR [list lo $rtLO hi $rtHI pctlo $rtPL pcthi $rtPH nth 1 dataset 0]]]] \
        {riseTime_scalar same 0 destination buffer}
    pcall calc::wave_dest_drop $iv
    # ⚠⚠ A FORMAL THE DIALOG CANNOT ANSWER, PLACED ANYWHERE BUT LAST, TRUNCATES
    # THE CALL AND THE USER'S OWN ORDINAL IS SILENTLY REPLACED BY A DEFAULT.
    # `calc::arg_values` walks the surface proc's formals in FORMAL order and
    # `break`s at the first one it has no value for; `calc::arg_invoke` then
    # appends the values POSITIONALLY.  This row MEASURES that on two probe
    # surfaces of its own -- the same extra formal in the middle and at the end
    # -- rather than warning about it in a comment, and then removes them.  It is
    # the only thing in the tree that asserts the ORDER requirement, because
    # MT11's surface row checks MEMBERSHIP only and is green on the truncating
    # shape.
    proc ::calc::__mt_mid_scalar {rpn {lo {}} {hi {}} {dest {}} {pctlo 10} {pcthi 90} {nth 1} {dataset 0}} {
        return [list ok 1 absent 0 msg {} value 0 nth $nth pctlo $pctlo dest $dest]
    }
    proc ::calc::__mt_end_scalar {rpn {lo {}} {hi {}} {pctlo 10} {pcthi 90} {nth 1} {dataset 0} {dest {}}} {
        return [list ok 1 absent 0 msg {} value 0 nth $nth pctlo $pctlo dest $dest]
    }
    set rtANS [list lo $rtLO hi $rtHI pctlo $rtPL pcthi $rtPH nth 0 dataset 0]
    check "MT9c R412 THE SILENT TRUNCATION, measured on two probe surfaces this row mints and removes: an extra formal the dialog cannot answer, placed in the MIDDLE, stops arg_values before the ordinal and the proc then receives the DEFAULT 1 where the user asked for 0 -- no error, no refusal, a different measurement.  The same formal placed LAST costs nothing and the ordinal arrives.  MT11's surface row is green on both, which is why this row exists; the four legs are two shapes times what arg_values composed and what the proc really received" \
        [list [mt_argval_of __mt_mid $rtR $rtANS nth] \
              [mt_delivered __mt_mid $rtR $rtANS nth] \
              [mt_argval_of __mt_end $rtR $rtANS nth] \
              [mt_delivered __mt_end $rtR $rtANS nth]] \
        {TRUNCATED-BEFORE:nth 1 0 0}
    catch {rename ::calc::__mt_mid_scalar {}}
    catch {rename ::calc::__mt_end_scalar {}}
    check "MT9c R402 the band left no __calc_tmp*, no __mt_* column and neither of the two probe surfaces behind -- which is the hygiene claim for an instrument that writes into the product's OWN namespace, and the reason it is a row rather than a habit is that MT10 and MT11 both derive over ::calc:: and would measure a leftover probe as a product proc" \
        [list [leaked] [probeleft] [info procs ::calc::__mt_*]] {{} {} {}}
}

# =========================================================================
group MT10 {
    # T1.  All three are PURE DELEGATES on `calc::cross`, measured two ways,
    # because neither way alone is enough: a one-level structural regexp cannot see
    # a verb that reads samples through a helper -- which is why the structural half
    # is a TRANSITIVE CLOSURE rather than a regexp over one body -- and the
    # behavioural stub cannot see a verb that calls `cross` AND also reads samples
    # itself.
    #
    # ⚠ EVERY ROW HERE THAT MAKES A CLAIM ABOUT THE THREE VERBS CARRIES THE SET OF
    # VERBS THAT ARE PRESENT AS THE FIRST ELEMENT OF WHAT IT COMPARES.  Without
    # that, "none of the three issues a direct `xschem raw` verb" is VACUOUSLY TRUE
    # while the three do not exist, and the row would pass on a tree with no feature
    # in it -- which is the sibling suite's accidental passes in structural form.
    # TWO ROWS HERE MAKE NO SUCH CLAIM and so carry no `present` leg, which is
    # stated rather than left as an apparent exception: the closure instrument's own
    # non-vacuity row is about the INSTRUMENT (and reddens on the featureless tree
    # anyway, because a NOPROC closure is not `deeper`), and `mt_dictsites` is about
    # THIS FILE'S OWN TEXT, where the feature's existence is irrelevant.
    pcall mt_load tran
    set verbs {riseTime delay dutyCycle}
    set present {}
    foreach v $verbs { if {[info commands ::calc::$v] ne {}} { lappend present $v } }
    # the instrument's own control, which PASSES TODAY: `calc::cross` is
    # legitimately a direct adder and reader, and the decommenter must not have
    # eaten its body to reach that answer.
    check "MT10 the structural instrument works: calc::cross IS a direct xschem raw adder and reader, the decommenter leaves its body non-empty, and it does remove something -- so a `no` below is evidence and not an artefact of an empty string" \
        [list [mt_direct_raw cross] \
              [expr {[string length [mt_decomment [info body ::calc::cross]]] > 200}] \
              [expr {[string length [mt_decomment [info body ::calc::cross]]] \
                     < [string length [info body ::calc::cross]]}]] {yes 1 1}
    check "MT10 T1 each of the three REACHES calc::cross -- derived as a transitive closure over the ::calc:: names in the decommented bodies, stopping AT cross, so a shared period derivation that itself calls cross is permitted while a verb that never reaches cross at all is not" \
        [list $present [lmap v $verbs {mt_reaches_cross $v}]] \
        [list $verbs {reaches reaches reaches}]
    check "MT10 T1 ...and NO proc in any of those closures, cross alone excepted, issues an xschem raw add, values, value or del of its own -- which is SR5's discipline seen from the other side, and which is what forbids T1's evaluate-once helper: such a helper has to evaluate into a column of its own, so it appears here by name" \
        [list $present [lmap v $verbs {mt_closure_raw $v}]] \
        [list $verbs {{} {} {}}]
    check "MT10 T1 ...and the closure instrument is NOT vacuous: calc::cross's own closure is itself, every verb's closure is strictly larger than the bare verb, and a name no such proc has answers NOPROC rather than an empty set that would satisfy the row above" \
        [list [mt_calc_closure cross] \
              [lmap v $verbs {expr {[llength [mt_calc_closure $v]] > 1 ? {deeper} : {bare}}}] \
              [mt_reaches_cross nosuchverb_zz] [mt_closure_raw nosuchverb_zz]] \
        [list cross {deeper deeper deeper} NOPROC NOPROC]
    check "MT10 the answer representation is known in exactly the procs the header enumerates -- derived by walking THIS FILE for every site that builds the answer dict and naming the enclosing proc, because the three sites that broke this claim were at ROW level where no scan of info body could reach them" \
        [mt_dictsites] {mt_asanswer mt_stub_run}
    # THE BEHAVIOURAL HALF.  A verb that still answers a number with
    # `calc::cross` replaced by a refusing stub is reading samples itself,
    # whatever its body looks like.
    set stub [mt_stub_run {
        set o {}
        foreach call {{riseTime {v(sq)} 0 1 10 90 1}
                      {delay {v(sq)} 0.5 rising 1 {v(sq)} 0.5 falling 1}
                      {dutyCycle {v(sq)} 0.5 1}} {
            set a [mt_call {*}$call]
            lappend o [mt_disp $a] \
                      [expr {[string match {*MTSTUB*} [mt_msg $a]] ? {marker} : {nomarker}}]
        }
        return [join $o { }]
    }]
    check "MT10 T1 with ::calc::cross replaced by a refusing stub, all three verbs REFUSE and all three carry the stub's own sentence through -- so each answer came back through cross rather than from samples the verb read itself, and the refusal composes rather than being replaced" \
        [list $present $stub] \
        [list $verbs {refused marker refused marker refused marker}]
    check "MT10 T1 ...and the stub was called at least once per verb, so the three refusals are delegation and not three verbs refusing for their own unrelated reasons" \
        [list $present [mt_atleast $::mt_stub_calls 3]] [list $verbs atleast3]
    check "MT10 ::calc::cross is RESTORED by that probe and answers the shipped value again, so no row after this one is measuring a stubbed namespace" \
        [list [mt_disp [set a [mt_call cross {v(sq)} 0.5 1 rising]]] \
              [near [mt_val $a] [sq_rise 0.5 0] $MTTOL] \
              [llength [info commands ::mt_cross_keep]]] {measured ok 0}
    # THE HOUSE SENTENCE SHAPE, per verb and per refusal kind, named so a
    # failure says WHICH sentence fell out of shape rather than that one did.
    # The WORDS are never asserted: they are unratified user-visible wording.
    check "MT10 every refusal these three verbs can reach is in the house shape calc::eval_msg, calc::plot_msg and calc::cross_msg all use -- a capital, a colon and a full stop -- stated as the shape and never as the words, which are unratified" \
        [list $present \
              [mt_shape [mt_msg [mt_call riseTime {v(sq)}]]] \
              [mt_shape [mt_msg [mt_call riseTime {v(sq)} 0.5 0.5]]] \
              [mt_shape [mt_msg [mt_call riseTime {} 0 1]]] \
              [mt_shape [mt_msg [mt_call delay {v(sq)} 0.5 sideways 1 {v(sq)} 0.5 falling 1]]] \
              [mt_shape [mt_msg [mt_call delay {v(sq)} nan rising 1 {v(sq)} 0.5 falling 1]]] \
              [mt_shape [mt_msg [mt_call dutyCycle {v(sq)} nan]]] \
              [mt_shape [mt_msg [mt_call dutyCycle {} 0.5]]]] \
        [list $verbs ok ok ok ok ok ok ok]
    check "MT10 the CONTROL for that shape test, which passes today: calc::cross's own refusal sentences are in the shape, so an `ok` above is the verbs' doing and not mt_shape accepting anything" \
        [list [mt_shape [mt_msg [mt_call cross {v(sq)} 0.5 1 sideways]]] \
              [mt_shape [mt_msg [mt_call cross {v(sq)} nan 1 rising]]] \
              [mt_shape [mt_msg [mt_call cross {} 0.5 1 rising]]] \
              [mt_shape {no capital here.}] [mt_shape {No colon here.}] \
              [mt_shape {Shape: no full stop here}] [mt_shape {}]] \
        {ok ok ok {nocapital:no capital here.} {nocolon:No colon here.} {nofullstop:Shape: no full stop here} empty}
    check "MT10 R402 the whole suite leaves no __calc_tmp* and no __mt_* in the inventory, which is the one claim that covers every exit path every band above drove" \
        [list [leaked] [probeleft]] {{} {}}
    pcall xschem raw clear
}

# ---------------------------------------------------------------------------
# MT11 -- PLAN 5.4 / R412: `calc::fn_argspec`, the ARGUMENT SPECIFICATION the
# modal dialog is built from.  NO Tk, so it gates on BOTH arms.
#
# Contract doc/claude/calculator_batch/CLICK_CONTRACT.md sections 8 and 9.
# Fence    the dialog itself, the click, the browser gesture and the grab are
#          display-only and live in tests/headless/test_calc_skeleton.tcl
#          (band S28) and tests/headless/test_calc_widgets.tcl (band CW14),
#          both `dcases` ALONE.  This band is the largest piece of phase 5 that
#          can be measured on the counted arm, and it costs nothing.
#
# ⚠⚠ WRITTEN RED-FIRST, BEFORE `calc::fn_argspec` EXISTED.  Every row below
# failed when it was written and each failure named `NOPROC:calc::fn_argspec`
# rather than raising; the transcript is in the stage receipt.
#
# WHY A NEW PROC AND NOT A SEVENTH CATALOGUE FIELD, measured rather than
# preferred (CLICK_CONTRACT section 3): `insert` is non-empty for all 56 route-P
# and all 4 route-C rows and EMPTY for all 34 route-T rows, and two registered
# rows in test_calc_skeleton FORBID filling it for a T row -- so the existing
# field is not an empty slot waiting for a call template.  A seventh field is
# worse still: it reddens S24's arity rows and D3's schema row AND SILENTLY
# SKIPS two S23 loops that `continue` on `llength != 6`, which is a row that
# stops measuring rather than failing.  The first row of this band is therefore
# a fence on the SHAPE OF THE SOLUTION and not only on its content.
#
# THE SHAPE, which this band is the specification of:
#
#   calc::fn_argspec <name>  ->  a list of `{key label kind required default}`
#                                rows IN DISPLAY ORDER, or {} for any name with
#                                no arguments.
#
#   key       the formal name on the proc the click's result path calls, so the
#             call can be composed BY KEY.  ⚠ NOT positionally: `dutyCycle`'s
#             display order and its formal order DELIBERATELY DIFFER and a row
#             below measures that they do, so an implementation that zips the
#             spec onto `info args` reddens instead of mis-measuring.
#   label     the user-visible field label.  UNRATIFIED -- the `rule` debt
#             `calc_argdialog_field_labels_and_delay_second_signal` covers these
#             and the one literal row per verb is where an overrule lands.
#   kind      `real` | `int` | `rpn` | `{enum <member> ...}`.  The dialog
#             validates SHAPE ONLY (CLICK_CONTRACT section 8): `real` is a
#             finite double, `int` is `string is integer -strict`, an `rpn` field
#             is non-empty text that is NEVER PARSED (R401), and an `enum` is
#             membership in its own member list.  ⚠ SEMANTIC refusals stay with
#             the verb -- `nth` 0 must reach `cross_scalar`/`delay`, because MT7,
#             MT8 and MT9b compare against `[calc::cross_msg listdefer]` BY
#             IDENTITY, so a dialog that re-worded one of those sentences would
#             redden three bands in this file.
#   required  1 or 0.  A required field's default is EMPTY -- a required field
#             carrying a default is a contradiction, and it is a row.
#   default   the value the field opens at.
#
# ⚠ THE MEMBER LISTS ARE LIFTED OUT OF THE VALIDATORS' OWN BODIES, not written
# out again: `calc::cross` tests `edge` against one literal and `calc::dutyCycle`
# tests `xaxis` against another, so a dialog offering a fourth edge or a renamed
# axis is caught by the drift rather than by someone noticing.  `ag_enum_in` is
# the lift and its non-vacuity control is the row beside it.
#
# ⚠ WHAT IS **MINE** AND NOT THE CONTRACT'S, said out loud so an overrule is a
# one-row edit: CLICK_CONTRACT section 8's table gives labels, kinds, the
# requiredness of `riseTime`'s two references and `cross`'s level, and the
# defaults 1 / 10 / 90 / `start`.  It gives NO default for `cross`'s `Edge` nor
# for any of `delay`'s eight.  This band chooses (a) the KEY NAMES, which are
# the formals so that the call composes by name; (b) `rising` as the default edge
# for `cross` and for both of `delay`'s sides -- because `riseTime` measures a
# rising transition (hole H1) and `calc::dutyCycle` opens its periods on
# `rising`, so `either`, which conflates two transitions, would be the surprising
# answer to one click; and (c) a default of 1 for every occurrence field and 0
# for every dataset field, which is where the shipped formals already sit.
#
# ⚠ ONE MEASUREMENT WAS OWED BEFORE THIS BAND COULD BE WRITTEN AND IT CHANGED
# THE ANSWER.  `dutyCycle`'s formals disagreed between two live documents --
# this file's own header said `<rpn> <level> ?<cycle>? ?<dataset>?` and R420 adds
# an X axis.  READ OFF THE SHIPPED PROC: `calc::dutyCycle` is
# `{rpn level {cycle 0} {dataset 0} {xaxis start}}`, so `xaxis` is FIFTH and
# LAST, AFTER `dataset`, and NOT third as section 8's field order would suggest.
# The header above is corrected in the same change.  AND the surface wrapper
# `calc::dutyCycle_scalar` is `{rpn level {cycle 0} {dataset 0}}` -- it has NO
# `xaxis` formal at all and forwards four arguments, which its own shipped
# comment declares deliberate: *"phase 5's argument dialog (R412) is what will
# offer the choice, and giving the surface wrapper an argument nothing can
# surface yet would be a parameter with no caller."*  So the row below that
# checks every key against the SURFACE proc's formals is RED FOR THAT REASON
# TOO, and it is red on purpose: phase 5 is the caller that comment is waiting
# for, and the dialog cannot offer an axis the proc it calls cannot take.
# ---------------------------------------------------------------------------

# the spec for one name, or a legible sentinel -- never a raise, and the two
# failure modes are told apart because "the proc is missing" and "the proc threw"
# want different fixes.
proc ag_spec {name} {
    if {[info commands ::calc::fn_argspec] eq {}} { return "NOPROC:calc::fn_argspec" }
    if {[catch {::calc::fn_argspec $name} r]} { return "RAISED:$r" }
    return $r
}
proc ag_ok {s} {
    if {[string match NOPROC:* $s]} { return 0 }
    if {[string match RAISED:* $s]} { return 0 }
    if {[catch {llength $s}]} { return 0 }
    return 1
}
# the rows, or {} when the spec could not be read at all -- so every loop below
# is over a real list and `foreach` cannot raise on a sentinel.
proc ag_rows {name} {
    set s [ag_spec $name]
    if {![ag_ok $s]} { return {} }
    return $s
}
# a canonical string for a spec, so a literal written with newlines and tabs
# compares equal to one the product built with single spaces.  Raise-proof: a
# malformed row answers a sentinel that fails the comparison legibly.
proc ag_canon {spec} {
    if {[catch {llength $spec}]} { return "NOTALIST:{$spec}" }
    set out {}
    foreach row $spec {
        if {[catch {lrange $row 0 end} r]} { return "NOTAROW:{$row}" }
        lappend out $r
    }
    return $out
}
proc ag_keys {name} {
    set out {}
    foreach row [ag_rows $name] {
        if {[catch {lindex $row 0} k]} continue
        lappend out $k
    }
    return $out
}
proc ag_cell {row i} { if {[catch {lindex $row $i} v]} { return "NOTAROW" } ; return $v }
# the field of one named key, by index, or a sentinel naming what was missing.
proc ag_field {name key i} {
    foreach row [ag_rows $name] {
        if {[ag_cell $row 0] ne $key} continue
        return [ag_cell $row $i]
    }
    return "NOSUCHKEY:$name/$key"
}

# ⚠ THE CLICKABLE SET IS DERIVED FROM THE TREE, NEVER HAND-KEPT.  A route-T
# catalogue row that has a proc of its own is a verb this stage makes reachable;
# the other thirty have no handler and must fall through (CLICK_CONTRACT
# section 3: "a blanket route-T branch strands 30 verbs with no handler").  A
# list written out here would be the defect `test_snprintf_fmt_1608` row X1
# exists to warn about, one level up.
proc ag_verbs {} {
    set out {}
    foreach row [pcall calc::catalogue] {
        if {[ag_cell $row 2] ne {T}} continue
        set nm [ag_cell $row 0]
        if {[info commands ::calc::$nm] ne {}} { lappend out $nm }
    }
    return [lsort $out]
}
# the proc the click's RESULT PATH must call for a verb: the `_scalar` surface
# wrapper where one exists, else the verb itself.  CLICK_CONTRACT section 3:
# "the click must call `calc::cross_scalar`, not `calc::cross` -- the raw proc
# answers `nth = 0` with success and a *list*, and has no deferral."
proc ag_surface {verb} {
    if {[info commands ::calc::${verb}_scalar] ne {}} { return ${verb}_scalar }
    return $verb
}
# the key/value list the result path would compose for one verb, or a legible
# sentinel -- never a raise.  Added by the implementation stage for the row at
# the foot of this band; see that row's comment for the measurement that earned
# it.
proc ag_vals {verb rpn ans} {
    if {[info commands ::calc::arg_values] eq {}} { return "NOPROC:calc::arg_values" }
    if {[catch {::calc::arg_values $verb $rpn $ans} r]} { return "RAISED:$r" }
    return $r
}
proc ag_formals {p} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    if {[catch {info args ::calc::$p} a]} { return "RAISED:$a" }
    return $a
}
# `info default` as a two-element answer that never raises: {1 <value>} when the
# formal has one, {0 {}} when it does not.
proc ag_default {p formal} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    set v {}
    if {[catch {info default ::calc::$p $formal v} has]} { return [list 0 {}] }
    return [list $has $v]
}
# an enum's member list, lifted out of the validator's OWN body.
proc ag_enum_in {p var} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    if {[catch {info body ::calc::$p} b]} { return "RAISED:$b" }
    # ⚠ THE NEGATED BRACKET EXPRESSION BELOW SPELLS ITS CLOSE BRACE WITH A
    # BACKSLASH, AND THAT IS NOT STYLE.  Tcl does not count a backslashed brace
    # when it scans a braced word and it DOES count a bare one, so the bare
    # spelling closes the enclosing word right there -- and the file then dies
    # with `missing close-bracket` reported against the file-scope `catch` a
    # thousand lines above, naming nothing useful.  MEASURED TWICE while writing
    # this band: once in the pattern, and then again IN THE COMMENT THAT WARNED
    # ABOUT IT, which quoted both spellings and so unbalanced the proc body a
    # second time -- CLAUDE.md records the same accident in the comment warning
    # about it, and this is why the characters are described here instead of
    # shown.  The escape is also legal inside an ARE bracket expression, which
    # POSIX would not allow, so the regexp still means what it reads.
    set pat {lsearch -exact \{([^\}]*)\} \$%s}
    if {![regexp [format $pat $var] $b -> lst]} { return "NOLITERAL:$p/$var" }
    if {[catch {lrange $lst 0 end} r]} { return "NOTALIST:$p/$var" }
    return $r
}

# THE FOUR SPECIFICATIONS, BY LITERAL, one row each so that overruling one verb
# is a one-row edit.  See the header for which parts are section 8's and which
# are this band's.
# ⚠ `list` AND NOT `dict create`, AND MT10 IS WHY.  `mt_dictsites` walks this
# file for every line that builds a dict and names the enclosing proc, so a
# band-level `dict create` -- even one holding a SPECIFICATION TABLE and not an
# answer -- is a new site and reddens MT10's enumeration row.  MEASURED: the
# first draft of this band used `dict create` here and MT10 came back
# `{BAND-LEVEL mt_asanswer mt_stub_run}`.  The instrument cannot tell the two
# kinds of dict apart and should not have to; an even-length list is a dict to
# `dict get` anyway, so nothing is lost.
set AG_WANT [list \
    cross {
        {level   {Level}               real                         1 {}}
        {nth     {Occurrence (Nth)}    int                          0 1}
        {edge    {Edge}                {enum rising falling either} 0 rising}
    } \
    riseTime {
        {lo      {Low level}           real                         1 {}}
        {hi      {High level}          real                         1 {}}
        {pctlo   {Low threshold %}     real                         0 10}
        {pcthi   {High threshold %}    real                         0 90}
        {nth     {Occurrence (Nth)}    int                          0 1}
        {dataset {Dataset}             int                          0 0}
    } \
    delay {
        {rpnA    {Signal A (RPN)}      rpn                          1 {}}
        {levelA  {Level A}             real                         1 {}}
        {edgeA   {Edge A}              {enum rising falling either} 0 rising}
        {nthA    {Occurrence A (Nth)}  int                          0 1}
        {rpnB    {Signal B (RPN)}      rpn                          1 {}}
        {levelB  {Level B}             real                         1 {}}
        {edgeB   {Edge B}              {enum rising falling either} 0 rising}
        {nthB    {Occurrence B (Nth)}  int                          0 1}
    } \
    dutyCycle {
        {level   {Level}               real                         1 {}}
        {xaxis   {X axis}              {enum start number mid}      0 start}
        {cycle   {Cycle}               int                          0 0}
        {dataset {Dataset}             int                          0 0}
    }]

group MT11 {
    # --- the shape of the solution, which is a fence in its own right --------
    set agbadarity {}
    foreach row [pcall calc::catalogue] {
        if {[catch {llength $row} L] || $L != 6} {
            lappend agbadarity [ag_cell $row 0]=arity$L
        }
    }
    check "MT11 the argument spec is a PROC and the catalogue is UNTOUCHED: `calc::fn_argspec` exists, `calc::fn_fields` is still the six ruled fields and every catalogue row is still arity 6 -- a spec added as a SEVENTH field reddens S24's arity row and SILENTLY SKIPS two S23 loops that `continue` on `llength != 6`" \
        [list [expr {[info procs ::calc::fn_argspec] ne {} ? 1 : 0}] \
              [pcall calc::fn_fields] \
              [llength [pcall calc::catalogue]] $agbadarity] \
        [list 1 {name category route returns insert help} 108 {}]
    # ⚠ THE CONTROL FOR EVERY `{}` BELOW.  An empty answer and a missing proc are
    # the same empty string to a careless reader; `ag_spec` tells them apart, and
    # without this row the fall-through sweep would be green on a tree with no
    # `fn_argspec` at all.
    check "MT11 the instrument distinguishes a MISSING proc from an EMPTY spec, which is what makes the fall-through sweep below a measurement rather than a tautology" \
        [list [ag_ok [ag_spec average]] [ag_ok [ag_spec cross]]] {1 1}
    check "MT11 route T still has NO refusal reason, so the S23 loop that clicks every entry the browser drew still skips all 34 T rows -- the truthful click message belongs in a route-T branch of `calc::fn_click` and NOT in `calc::fn_reason`, where it would make that loop assert the \"is not available\" phrasing over four verbs that ARE available" \
        [list [pcall calc::fn_reason T] [pcall calc::fn_reason P] \
              [expr {[pcall calc::fn_reason N] ne {} ? 1 : 0}]] {{} {} 1}

    # --- the clickable set, derived -----------------------------------------
    check "MT11 the clickable set is DERIVED from the tree -- every route-T catalogue row that has a proc of its own -- and it is the four verbs this stage makes reachable" \
        [ag_verbs] {cross delay dutyCycle riseTime}
    set agempty {}
    set agnswept 0
    set agnonempty 0
    foreach row [pcall calc::catalogue] {
        set nm [ag_cell $row 0]
        incr agnswept
        set rows [ag_rows $nm]
        if {[lsearch -exact [ag_verbs] $nm] >= 0} {
            if {[llength $rows] == 0} { lappend agempty $nm=EMPTY }
            incr agnonempty
            continue
        }
        if {[llength $rows] != 0} { lappend agempty $nm=([ag_canon $rows]) }
    }
    check "MT11 the 30-verb fall-through is LEGIBLE rather than accidental: every catalogue name that is not one of the four answers an EMPTY spec, and each of the four answers a non-empty one -- swept over the whole table, with both counts riding along so neither direction can be vacuous" \
        [list $agnswept $agnonempty $agempty] {108 4 {}}

    # --- the four specifications, by literal --------------------------------
    foreach agv {cross riseTime delay dutyCycle} {
        check "MT11 the argument spec for $agv is exactly the ruled field list -- key, label, kind, requiredness and default, in DISPLAY order (labels and the edge default are UNRATIFIED: the `rule` debt names them and this row is where an overrule lands)" \
            [ag_canon [ag_rows $agv]] [ag_canon [dict get $AG_WANT $agv]]
    }

    # --- the shape rules, derived over whatever the four actually answer -----
    set agbadshape {} ; set agnfields 0 ; set agkinds {}
    foreach agv [ag_verbs] {
        set seenk {} ; set seenl {}
        foreach row [ag_rows $agv] {
            incr agnfields
            if {[catch {llength $row} L] || $L != 5} {
                lappend agbadshape $agv/[ag_cell $row 0]=arity$L ; continue
            }
            foreach {k lbl kind req def} $row break
            if {$k eq {}}   { lappend agbadshape $agv=blank-key }
            if {$lbl eq {}} { lappend agbadshape $agv/$k=blank-label }
            if {[lsearch -exact $seenk $k] >= 0}     { lappend agbadshape $agv/$k=dup-key }
            if {[lsearch -exact $seenl $lbl] >= 0}   { lappend agbadshape $agv/$k=dup-label($lbl) }
            lappend seenk $k ; lappend seenl $lbl
            if {![string is boolean -strict $req]}   { lappend agbadshape $agv/$k=req($req) }
            set kw [ag_cell $kind 0]
            lappend agkinds $kw
            if {$kw eq {enum}} {
                if {[llength $kind] < 3} { lappend agbadshape $agv/$k=enum<2($kind) }
            } elseif {[lsearch -exact {real int rpn} $kind] < 0} {
                lappend agbadshape $agv/$k=kind($kind)
            }
            # a required field carrying a default is a contradiction: the dialog
            # would open pre-answered and still refuse to be left alone.
            if {$req eq {1} && $def ne {}} { lappend agbadshape $agv/$k=required-with-default($def) }
        }
    }
    check "MT11 every field of every spec is a well-formed five-field row with a closed `kind` vocabulary, a boolean `required`, a key and a label unique WITHIN its verb -- which is the copy-paste `delay` would suffer, both sides carrying side A's labels -- and no required field carrying a default; the field COUNT rides along so an empty population cannot pass" \
        [list [mt_atleast $agnfields 15] $agbadshape] {atleast15 {}}
    check "MT11 ...and the kind vocabulary is really exercised: all four words appear across the four specs, so the closed-vocabulary leg above is not a claim about one kind" \
        [lsort -unique $agkinds] {enum int real rpn}

    # --- R421: ONE operand comes from the buffer, and only `delay` needs two -
    set agbadrpn {}
    foreach agv [ag_verbs] {
        set n 0
        foreach row [ag_rows $agv] { if {[ag_cell [ag_cell $row 2] 0] eq {rpn}} { incr n } }
        set want [expr {$agv eq {delay} ? 2 : 0}]
        if {$n != $want} { lappend agbadrpn $agv=$n/want$want }
    }
    check "MT11 R421 the expression operand comes from the BUFFER and is not a dialog field -- so no spec offers an `rpn` field except `delay`, whose two sides are two operands and whose B side no ruling supplies (driver's recorded decision, filed as a `rule` debt)" \
        [list [llength [ag_verbs]] $agbadrpn] {4 {}}

    # --- the keys are the formals, in two directions ------------------------
    set agbadformal {} ; set agnchecked 0
    foreach agv [ag_verbs] {
        set fm [ag_formals $agv]
        if {![ag_ok $fm]} { lappend agbadformal $agv=$fm ; continue }
        foreach k [ag_keys $agv] {
            incr agnchecked
            if {[lsearch -exact $fm $k] < 0} { lappend agbadformal $agv/$k=not-a-formal }
        }
    }
    check "MT11 every key is a FORMAL of the measurement proc, derived with `info args` rather than read off a table -- so a renamed or mistyped key is a failure here instead of a wrong positional argument three phases later; the checked count rides along" \
        [list [mt_atleast $agnchecked 15] $agbadformal] {atleast15 {}}
    set agbadsurf {} ; set agnsurf 0
    foreach agv [ag_verbs] {
        set sp [ag_surface $agv]
        set fm [ag_formals $sp]
        if {![ag_ok $fm]} { lappend agbadsurf $sp=$fm ; continue }
        foreach k [ag_keys $agv] {
            incr agnsurf
            if {[lsearch -exact $fm $k] < 0} { lappend agbadsurf $sp/$k=not-a-formal }
        }
    }
    check "MT11 ...and every key is also a formal of the SURFACE proc the click must call -- the `_scalar` wrapper where one exists, because the raw proc answers `nth` 0 with a list and has no deferral.  ⚠ `calc::dutyCycle_scalar` TAKES NO `xaxis`, which its own shipped comment declares is waiting for exactly this caller, so the dialog cannot offer R420's axis until the wrapper can carry it" \
        [list [mt_atleast $agnsurf 15] $agbadsurf] {atleast15 {}}
    # ⚠ THE CALL IS COMPOSED BY KEY AND NOT POSITIONALLY, and this row MEASURES
    # that the two orders really differ rather than asserting it: `dutyCycle`'s
    # display order is level / xaxis / cycle / dataset and its formal order is
    # rpn / level / cycle / dataset / xaxis, so an implementation that zips the
    # spec onto `info args` gets `xaxis` where `cycle` belongs and measures the
    # wrong thing silently.
    set agduty [ag_keys dutyCycle]
    set agdutyfm [ag_formals dutyCycle]
    set agdutypos {}
    foreach k $agdutyfm { if {[lsearch -exact $agduty $k] >= 0} { lappend agdutypos $k } }
    check "MT11 `dutyCycle`'s DISPLAY order deliberately DIFFERS from its formal order, so the call must be composed BY KEY -- an implementation that zips the spec onto `info args` would hand the verb its X axis where its cycle ordinal belongs" \
        [list $agduty $agdutypos [expr {$agduty ne $agdutypos ? {differ} : {SAME}}]] \
        [list {level xaxis cycle dataset} {level cycle dataset xaxis} differ]

    # --- a mandatory formal must be reachable -------------------------------
    set agunreach {} ; set agnmand 0
    foreach agv [ag_verbs] {
        set sp [ag_surface $agv]
        foreach row [ag_rows $agv] {
            set k [ag_cell $row 0]
            set d [ag_default $sp $k]
            if {[ag_cell $d 0] eq {1}} continue
            if {[lsearch -exact [ag_formals $sp] $k] < 0} continue
            incr agnmand
            if {[ag_cell $row 3] eq {1}} continue
            if {[ag_cell $row 4] ne {}} continue
            lappend agunreach $sp/$k=no-value-and-no-formal-default
        }
    }
    check "MT11 a field whose formal has NO default on the proc is either marked required or carries a non-empty default, so the dialog can never compose a call with an empty positional argument the proc has nothing to fall back on -- the mandatory-formal count rides along" \
        [list [mt_atleast $agnmand 6] $agunreach] {atleast6 {}}

    # --- the defaults agree with the formals that already have them ---------
    set agbaddef {} ; set agndef 0
    foreach agv [ag_verbs] {
        set sp [ag_surface $agv]
        foreach row [ag_rows $agv] {
            set k [ag_cell $row 0]
            set d [ag_default $sp $k]
            if {[ag_cell $d 0] ne {1}} continue
            incr agndef
            if {[ag_cell $row 4] ne [ag_cell $d 1]} {
                lappend agbaddef $sp/$k=spec([ag_cell $row 4])formal([ag_cell $d 1])
            }
        }
    }
    check "MT11 wherever the shipped proc ALREADY states a default, the spec's default is that one -- derived with `info default`, so the dialog cannot open on a value the verb would not have chosen for itself; the pair count rides along and is a FLOOR, because extending `dutyCycle_scalar` with `xaxis` correctly adds one" \
        [list [mt_atleast $agndef 6] $agbaddef] {atleast6 {}}

    # --- the enums come from the validators' own literals --------------------
    set agedge [ag_enum_in cross edge]
    set agax [ag_enum_in dutyCycle xaxis]
    check "MT11 fixture: the two member lists really were LIFTED out of the validators' own bodies -- `calc::cross`'s `edge` test and `calc::dutyCycle`'s `xaxis` test -- so a drift row below is evidence and not an artefact of an empty match" \
        [list $agedge $agax] {{rising falling either} {start number mid}}
    set agbadenum {} ; set agnenum 0
    foreach {agv agk aglit} [list cross edge $agedge dutyCycle xaxis $agax \
                                  delay edgeA $agedge delay edgeB $agedge] {
        incr agnenum
        set kind [ag_field $agv $agk 2]
        set mem [lrange $kind 1 end]
        if {[ag_cell $kind 0] ne {enum}} { lappend agbadenum $agv/$agk=notenum($kind) ; continue }
        if {$mem ne $aglit} { lappend agbadenum $agv/$agk=members($mem)vs($aglit) }
    }
    check "MT11 every enum field offers EXACTLY the members its own validator tests against, lifted from the shipped body -- so a dialog offering a fourth edge, or a renamed axis, is caught by the drift instead of by someone noticing a refusal in the field" \
        [list $agnenum $agbadenum] {4 {}}
    set agbadmem {} ; set agnmem 0
    foreach agv [ag_verbs] {
        foreach row [ag_rows $agv] {
            set kind [ag_cell $row 2]
            if {[ag_cell $kind 0] ne {enum}} continue
            incr agnmem
            if {[lsearch -exact [lrange $kind 1 end] [ag_cell $row 4]] < 0} {
                lappend agbadmem $agv/[ag_cell $row 0]=default([ag_cell $row 4])
            }
        }
    }
    check "MT11 every enum field's default is one of its OWN members, so no field can open on a value its verb would refuse; the enum-field count rides along" \
        [list [mt_atleast $agnmem 4] $agbadmem] {atleast4 {}}
    check "MT11 R420 the X axis opens on the time the cycle STARTED, which is the user's own ruling -- *\"Default can be time the cycle started\"* -- and that word is also the shipped formal's default" \
        [list [ag_field dutyCycle xaxis 4] [ag_cell [ag_default dutyCycle xaxis] 1]] \
        {start start}

    # --- and the members are REACHABLE: the verbs really take them -----------
    # ⚠ NO FIXTURE NEEDED, and that is why this row can live on the counted arm:
    # both validators run BEFORE anything reaches the database, so with no raw
    # loaded a MEMBER gets past the membership test and lands on the no-data
    # refusal while a NON-MEMBER is refused by the membership test itself.  The
    # two sentences are therefore the whole measurement.
    set agunreachable {} ; set agnreach 0
    foreach m [lrange [ag_field dutyCycle xaxis 2] 1 end] {
        incr agnreach
        set got [mt_msg [mt_call dutyCycle {v(sq)} 0.5 0 0 $m]]
        if {$got eq [pcall calc::cross_msg badxaxis $m]} { lappend agunreachable xaxis/$m }
    }
    foreach m [lrange [ag_field cross edge 2] 1 end] {
        incr agnreach
        set got [mt_msg [mt_call cross {v(sq)} 0.5 1 $m]]
        if {$got eq [pcall calc::cross_msg badedge $m]} { lappend agunreachable edge/$m }
    }
    check "MT11 every member the dialog offers is one the verb ACCEPTS: with no result loaded each member gets past its own membership test and meets the no-data refusal, while a non-member is refused by the membership test itself -- so the two sentences tell acceptance from rejection with no fixture at all" \
        [list [mt_atleast $agnreach 6] $agunreachable \
              [expr {[mt_msg [mt_call dutyCycle {v(sq)} 0.5 0 0 sideways]] eq [pcall calc::cross_msg badxaxis sideways] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call cross {v(sq)} 0.5 1 sideways]] eq [pcall calc::cross_msg badedge sideways] ? {refused} : {ACCEPTED}}]] \
        {atleast6 {} refused refused}
    # --- and the call REALLY IS composed by key -----------------------------
    # ⚠⚠ ADDED BY THE IMPLEMENTATION STAGE, AND THE REASON IS A MEASUREMENT THE
    # SUITE AUTHOR'S OWN HOLE SH2 PREDICTED.  The row above measures only that
    # `dutyCycle`'s display order and its formal order DIFFER -- which tells an
    # implementer to compose by key and catches nothing if they do not.  Driven
    # as a sabotage against the shipped code: composing POSITIONALLY, by zipping
    # the dialog's answer onto `info args`, passes ALL THREE SUITES -- every one
    # of MT11's rows, every one of band S28's and every one of CW14's -- because
    # hole SH2 drives only `cross` through the OK path and `cross`'s two orders
    # COINCIDE.  So the one verb whose orders diverge is the one no behavioural
    # row reaches, and the defect it ships is silent: `calc::dutyCycle` would be
    # handed the X AXIS where its cycle ordinal belongs and refuse with
    # `badcycle`, naming a field the user never touched.
    #
    # This row needs no Tk and no fixture: the composition is a pure function of
    # the spec, the surface proc's formals and the dialog's answer.
    # ⚠ THE `cross` LEG IS THE NON-VACUITY CONTROL AND ALSO THE EXPLANATION: it
    # is the same probe on the verb whose orders coincide, where the positional
    # and the by-key answers are IDENTICAL -- so it documents, in the file, why
    # the behavioural arm cannot see this.
    check "MT11 the call really is COMPOSED BY KEY and not positionally: handed `dutyCycle`'s answer in the dialog's DISPLAY order, each formal of the surface proc is paired with ITS OWN key's value, in FORMAL order, with the buffer's expression under `rpn` -- an implementation that zipped the answer onto `info args` would hand the verb its X axis where the cycle ordinal belongs, which this band's order row only WARNS about and hole SH2 leaves unreachable behaviourally because only `cross`, whose two orders coincide, is driven through OK" \
        [ag_vals dutyCycle {v(sq) 2 *} \
             [list level 0.5 xaxis mid cycle 2 dataset 0]] \
        {rpn {v(sq) 2 *} level 0.5 cycle 2 dataset 0 xaxis mid}
    check "MT11 ...and the control that says why the behavioural arm is blind to it: on `cross`, whose display order and formal order COINCIDE, the by-key and the positional composition are the same list -- so the row above is the only thing in the three suites that measures the difference; a name with no surface proc composes NOTHING rather than guessing, and the composer's presence rides along so neither leg can be green over a missing proc" \
        [list [ag_vals cross {v(sq) 2 *} [list level 0.5 nth 3 edge falling]] \
              [ag_vals __mt_no_such_verb__ {v(sq)} {}] \
              [expr {[info commands ::calc::arg_values] ne {} ? 1 : 0}]] \
        [list {rpn {v(sq) 2 *} level 0.5 nth 3 edge falling} {} 1]
    check "MT11 R402 this band mints nothing -- it reads specifications and refuses requests, so no `__calc_tmp*` and no `__mt_*` may appear in the inventory because of it" \
        [list [leaked] [probeleft]] {{} {}}
}

# ---------------------------------------------------------------------------
# MT12 -- stage J unit J1b / R404 / R421: `calc::fn_sink`, THE ROUTING DECISION
# for an answer that is a WAVE.  NO Tk, so it gates on BOTH arms.
#
# Spec     doc/claude/specs/calculator.md section 7.2ac (R419-R421), section 7.3
#          (R401-R405).
# Contract doc/claude/calculator_batch/WIRING_CONTRACT.md section 4 -- the
#          explicit `shape` key, and the inference over the value's LENGTH that
#          section rejects by name.  Section 10(b) splits the stage: J1 is the
#          PRODUCER (band WD11 of tests/headless/test_calc_wave_dest.tcl), J1b
#          is this.
# Fence    this band, plus the key-set row of band WD11, which widens by one key
#          for the `shape` the producer now declares.
#
# ⚠⚠ WHY THE DECISION IS A PROC OF ITS OWN, AND IT IS AN EVIDENCE ARGUMENT
# RATHER THAN A STYLE ONE.  `calc::fn_measure` and `calc::buf_set_number` BOTH
# return early on `calc::has_win .calc.buf`, so headless they are no-ops and
# nothing this suite can drive observes what either does.  A shape branch left
# inside them would be measured only on a gate's DISPLAY arm -- and the person
# this tree is built for is remote with a phone and reads the transcript.  A
# PURE predicate -- given an answer, say where it goes -- is measurable here,
# every run, which is the same argument that put `calc::fn_argspec` outside the
# dialog one stage earlier (band MT11's header).
#
# ⚠⚠ THE DEFECT THIS BAND EXISTS FOR IS REAL AND IS NOT HYPOTHETICAL.  On a tree
# carrying J1's producer ALONE, a click on `dutyCycle` with the default cycle
# reaches `calc::fn_measure`, whose success arm is unconditionally
# `set num [calc::buf_set_number $v]` with NO branch on the answer's shape and
# NO numeric check inside `buf_set_number` -- so the whole per-cycle LIST is
# pasted into the user's RPN buffer, violating R404 (*"a literal number"*) and
# R421 silently.  A wrong buffer, not an error.  Declared as hole H12 of
# tests/headless/test_calc_wave_dest.tcl, and the reason the producer may not
# ship without this half: today's refusal is correct and the producer alone would
# be a user-visible REGRESSION against it.
#
# THE SHAPE, which this band is the specification of:
#
#   calc::fn_sink <answer>  ->  one word of a CLOSED vocabulary saying where the
#                               answer goes.
#
#     destination  the answer DECLARES `shape wave`.
#     buffer       the answer declares `shape scalar`, or declares no `shape` at
#                  all -- which is every verb that shipped before this stage --
#                  AND its `value` is a literal number by `calc::eval_finite`.
#     badshape     the answer declares a `shape` this build does not know.
#     badvalue     the route is the buffer and the `value` is not a literal
#                  number.  R404's own words, and the half of hole H12 that
#                  `calc::buf_set_number` has no check for.
#     refusal      `ok` is not 1, is missing, or the answer is not a dict.
#
# ⚠ FAIL CLOSED, WHICH IS WHY THERE ARE FIVE WORDS AND NOT TWO.  An unknown
# shape and a non-number both answer a word that is NEITHER the buffer nor the
# destination, so neither can reach the user's expression by falling through.
# That is R420's own discipline arriving one layer up: `calc::dutyCycle`
# validates `xaxis` against a closed member list and REFUSES an unknown token
# rather than defaulting it, and `cross_msg badxaxis` is the sentence.
#
# ⚠ `shape` ABSENT MEANS `buffer`, AND THAT IS A DECLARATION DEFAULT RATHER THAN
# AN INFERENCE.  It is read from a KEY, over a closed vocabulary, and it cannot
# be fooled by the data: a one-cycle waveform is a length-1 list and still goes
# to the destination.  What keeps the default honest is NOT this proc but a
# derived row at the foot of this band -- every caller that builds a destination
# also declares the shape -- so a future verb that answers a wave and forgets to
# say so reddens here instead of pasting a list.
#
# ⚠ SECTION 4'S REJECTED DOOR IS ASSERTED POSITIVELY AND NOT DESCRIBED.  Routing
# on `[llength [dict get $d value]] > 1` is rejected there because a legitimate
# ONE-cycle waveform has length 1 and would be mis-routed into the buffer -- the
# same silent-wrong-buffer failure arriving by a second route.  One row below
# drives the three cases where a length-based router and a declaration-based one
# disagree, so the rejection is measured in the run rather than argued in a
# comment.
#
# ⚠ WHAT THIS BAND CANNOT SEE, AND IT IS THE ACT RATHER THAN THE DECISION: that
# `calc::fn_measure` really leaves the buffer untouched on a wave answer, and
# that the sentence really reaches `.calc.status.msg`.  Both are display-only for
# the reason at the head of this comment, and belong to band S28 of
# tests/headless/test_calc_skeleton.tcl and band CW14 of
# tests/headless/test_calc_widgets.tcl, both `dcases` ALONE -- so only the gate's
# DISPLAY arm verifies them and a `--nogui` number proves nothing about either.
# What IS measured here is one structural half of the act: no proc in the
# namespace reaches `calc::buf_set_number` without naming `calc::fn_sink`.
#
# ⚠ THE DESTINATION SENTENCE'S WORDS ARE UNRATIFIED and no row asserts them.
# The rows assert that it is ONE NON-EMPTY SENTENCE IN THE HOUSE SHAPE and that
# it NAMES THE DESTINATION, which is how WD9's first row treats the shared
# deferral sentence; a row asserting the text would redden on the ruling.  The
# `rule` debt filed against `calc::eval_msg`'s sentences, which already covers
# `calc::arg_msg`, is extended to it.
# ---------------------------------------------------------------------------

# the routing decision for one answer, or a legible sentinel -- never a raise,
# and "the proc is missing" is told apart from "the proc threw" because the two
# want different fixes.  `ag_spec`'s shape exactly.
proc sk_sink {d} {
    if {[info commands ::calc::fn_sink] eq {}} { return "NOPROC:calc::fn_sink" }
    if {[catch {::calc::fn_sink $d} r]} { return "RAISED:$r" }
    return $r
}
# one route-T sentence, or a legible sentinel.
proc sk_msg {args} {
    if {[info commands ::calc::arg_msg] eq {}} { return "NOPROC:calc::arg_msg" }
    if {[catch {::calc::arg_msg {*}$args} r]} { return "RAISED:$r" }
    return $r
}
# an answer dict built HERE, from the base every verb answers, with the row's
# own overrides applied BY KEY so a row site never spells the representation.
#
# ⚠ `list` PLUS `dict set`, NEVER `dict create`, AND MT10 IS WHY: `mt_dictsites`
# walks this file for every line that builds a dict with `dict create` and names
# the enclosing proc, so a band helper spelled that way is a new site and
# reddens MT10's enumeration row.  Band MT11 made the same choice for the same
# reason and records having measured it.
proc sk_ans {args} {
    set d [list ok 1 absent 0 value {} msg {} dataset 0]
    foreach {k v} $args { dict set d $k $v }
    return $d
}
# the words `calc::fn_sink` can answer, DERIVED FROM ITS OWN BODY and never
# listed in this file -- the method WD10's `cross_msg` arm sweep uses, for the
# reason row X1 of tests/headless/test_snprintf_fmt_1608.tcl exists: a hand-kept
# list is the same defect one level up.  The one row on this batch that kept one
# drove a hand-kept list of message kinds against a proc that had grown more arms
# than the list named, and its name claimed it drove every arm -- coverage, not
# method -- so nothing could detect the drift.
#
# ⚠ THIS IS A CONSTRAINT ON THE IMPLEMENTATION AND IS STATED AS ONE: the
# vocabulary is read off LITERAL `return <word>` spellings, so a router that
# answered through a variable would redden the vocabulary row rather than be
# measured by a derivation that cannot see it.  A trailing space is appended
# before the scan because the last `return` in a body has a newline after it and
# the pattern needs one non-word character.
proc sk_vocab {} {
    if {[info procs ::calc::fn_sink] eq {}} { return "NOPROC:calc::fn_sink" }
    set b [pcall info body ::calc::fn_sink]
    if {[string match ERR:* $b]} { return $b }
    set out {}
    foreach {whole w} [regexp -all -inline \
            {return[ \t]+([a-z][a-z0-9_]*)[^A-Za-z0-9_]} "[mt_decomment $b] "] {
        lappend out $w
    }
    return [lsort -unique $out]
}
# the tokens a proc's DECOMMENTED body must not name if a claim about it is to
# gate on the COUNTED arm: Tk, a widget path, the window guard that makes a proc
# a headless no-op, the engine and the viewer.  Answers the HITS, so `{}` is the
# claim and the positive control is a leg of the row beside it.
proc sk_tkhits {p} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    set b [pcall info body ::calc::$p]
    if {[string match ERR:* $b]} { return $b }
    set b [mt_decomment $b]
    set out {}
    foreach {nm pat} [list winfo winfo tkwait tkwait grab {grab[ \t]} \
                           toplevel toplevel evgen {event[ \t]+generate} \
                           widget {\.calc} haswin has_win \
                           engine {xschem[ \t]} viewer wviewer::] {
        if {[regexp $pat $b]} { lappend out $nm }
    }
    return $out
}
# `has` / `missing` for one member of a derived set.  A PROC rather than a
# ternary at the row site, for the reason `mt_destname` records: a braced `expr`
# whose branch is a command substitution raises *invalid bareword*, and
# `group`'s catch turns that into an ABANDONED BAND rather than one failed row.
proc sk_in {l w} {
    if {[catch {lsearch -exact $l $w} i]} { return "NOTALIST:{$l}" }
    return [expr {$i >= 0 ? {has} : {missing}}]
}
# `named` when a sentence really carries a name, `missing:<sentence>` otherwise.
# A GLOB and not a literal, and a WORD and not a number, so no destination
# serial reaches the T1 verdict -- `mt_destname`'s reason, and this suite's own
# house rule about reproducible figures in an expectation.
proc sk_names {s w} {
    if {[string match NOPROC:* $s]} { return $s }
    if {[string match RAISED:* $s]} { return $s }
    if {[string match *$w* $s]} { return named }
    return "missing:$s"
}
# `distinct` / `same` for two SENTENCES -- a WORD, so no user-visible text lands
# in an expectation and a ruling on the wording reddens nothing.  `mt_distinct`'s
# reason, for strings rather than for numbers.
proc sk_differ {a b} { return [expr {[string equal $a $b] ? {same} : {distinct}}] }
# the vocabulary members that do NOT have a sentence in the house shape, derived
# over `sk_vocab` -- so the claim is about the METHOD and a word added later
# cannot escape it.
#
# ⚠ `buffer` AND `refusal` ARE EXEMPT AND ARE NAMED HERE RATHER THAN LEFT OUT
# QUIETLY.  The buffer route's sentence is R404's PROVENANCE line, which
# `calc::arg_provenance` has composed since PLAN 5.4 and which band MT11's
# siblings already cover; a refusal carries the VERB's own `msg` through
# unchanged, which MT7, MT8 and WD9 compare BY IDENTITY, so a sentence of its
# own here would redden three bands in two files.
#
# ⚠ THE HOUSE SHAPE IS ASKED OF THE VOCABULARY'S MEMBERS AND NOT OF EVERY
# `calc::arg_msg` ARM, and that is measured rather than lazy: the shipped `real`,
# `int`, `rpn` and `enum` arms are field-validation sentences with no colon in
# them, so a sweep over every arm would be RED ON SHIPPED PROSE nobody has ruled.
proc sk_sentences {} {
    set v [sk_vocab]
    if {[string match NOPROC:* $v]} { return $v }
    if {[string match ERR:* $v]} { return $v }
    set bad {}
    foreach w $v {
        if {$w eq {buffer} || $w eq {refusal}} continue
        set s [sk_msg $w dutyCycle __calc_dest9]
        if {[string match NOPROC:* $s]} { lappend bad "$w:$s" ; continue }
        if {[string match RAISED:* $s]} { lappend bad "$w:$s" ; continue }
        set sh [mt_shape $s]
        if {$sh ne {ok}} { lappend bad "$w:$sh" }
    }
    return $bad
}

# =========================================================================
group MT12 {
    # --- the shape of the solution, which is a fence in its own right --------
    check "MT12 R404/R421 the routing decision is a PURE PROC with no Tk in it -- `calc::fn_sink` exists and its decommented body names none of winfo, tkwait, grab, toplevel, event generate, a .calc widget path, calc::has_win, the engine or the viewer -- which is the ONLY reason half two's decision can be measured on the counted arm at all: `calc::fn_measure` and `calc::buf_set_number` BOTH return early on `calc::has_win .calc.buf`, so anything left inside either is observable on a gate's DISPLAY arm and nowhere else.  The POSITIVE CONTROL rides along on both of those procs, because an empty hit list over a proc that does not exist is the same empty list" \
        [list [expr {[info procs ::calc::fn_sink] ne {} ? 1 : 0}] \
              [sk_tkhits fn_sink] \
              [sk_in [sk_tkhits fn_measure] widget] \
              [sk_in [sk_tkhits fn_measure] haswin] \
              [sk_in [sk_tkhits buf_set_number] haswin] \
              [sk_tkhits fn_argspec]] \
        {1 {} has has has {}}
    # --- the vocabulary, derived from the proc's own text --------------------
    check "MT12 ...and the words it can answer are a CLOSED vocabulary, DERIVED from the proc's own literal `return` words and never listed in this file -- the method WD10's cross_msg arm sweep uses, because a hand-kept list is the same defect one level up and the one row on this batch that kept one drove a hand-kept list of message kinds against a proc that had grown more arms than the list named, with a name that claimed every arm.  The derivation does not invent a word the proc has no `return` for, which is the leg that keeps an empty failure list below from being an empty set" \
        [list [sk_vocab] [sk_in [sk_vocab] __mt_no_such_sink__]] \
        [list {badshape badvalue buffer destination refusal} missing]
    # --- THE DECISION, over every disposition the vocabulary admits ----------
    check "MT12 R404/R421 THE ROUTING DECISION, over every disposition that vocabulary admits: a declared WAVE goes to the destination; a declared SCALAR and an answer that declares NOTHING -- which is every verb that shipped before this stage -- both go to the buffer; a shape this build does not know goes NOWHERE; a buffer route carrying something that is not a literal number goes NOWHERE either, which is R404's own words and the half of hole H12 that calc::buf_set_number has no check for; and anything that is not a measured answer at all, a non-dict included, is a refusal.  FAIL CLOSED, so neither an unknown shape nor a non-number can reach the user's expression by falling through" \
        [list [sk_sink [sk_ans shape wave value {0.3 0.32} db __calc_dest9]] \
              [sk_sink [sk_ans shape scalar value 0.315]] \
              [sk_sink [sk_ans value 0.315]] \
              [sk_sink [sk_ans shape __mt_no_such_shape__ value 0.315]] \
              [sk_sink [sk_ans shape scalar value {0.3 0.32}]] \
              [sk_sink [sk_ans value {}]] \
              [sk_sink [list ok 1]] \
              [sk_sink [list ok 0 absent 0 value {} dataset 0 msg {Duty cycle: no.}]] \
              [sk_sink [list ok 0 absent 1 value {} dataset 0 msg {Duty cycle: none.}]] \
              [sk_sink {an odd number of words is no dict}]] \
        {destination buffer buffer badshape badvalue badvalue badvalue refusal refusal refusal}
    # --- section 4's REJECTED DOOR, asserted positively ---------------------
    check "MT12 ...and the decision is read OFF THE DECLARATION and never inferred from the value's LENGTH, asserted as the three cases where the two implementations disagree: a legitimate ONE-cycle waveform is a length-1 list and still goes to the DESTINATION, an EMPTY declared wave goes there too, and a declared SCALAR carrying a list goes NOWHERE rather than to the destination.  A router that tested the value's list LENGTH instead answers buffer, buffer and destination for those three, which is the rejected door of WIRING_CONTRACT section 4 and the same silent-wrong-buffer failure arriving by a second route; the multi-element declared wave rides along so the row is not three cases of one claim" \
        [list [sk_sink [sk_ans shape wave value {0.315} db __calc_dest9]] \
              [sk_sink [sk_ans shape wave value {} db __calc_dest9]] \
              [sk_sink [sk_ans shape scalar value {0.3 0.32}]] \
              [sk_sink [sk_ans shape wave value {0.3 0.32} db __calc_dest9]]] \
        {destination destination badvalue destination}
    # --- one sentence per disposition that reaches the user ------------------
    check "MT12 R507 every disposition that reaches the user has a SENTENCE, derived over the vocabulary rather than listed: each word calc::fn_sink can answer except `buffer`, whose sentence is R404's provenance line, and `refusal`, which carries the verb's own msg through unchanged by identity, answers a NON-EMPTY sentence in the house shape through calc::arg_msg -- so a SIXTH disposition added without one reddens here naming itself.  The WORDS are never asserted: they are unratified user-visible wording and a `rule` debt covers them" \
        [list [sk_vocab] [sk_sentences]] \
        [list {badshape badvalue buffer destination refusal} {}]
    check "MT12 ...and the sentence for the one disposition the user will actually see -- a measurement that was a wave and landed in a destination -- NAMES THAT DESTINATION and names the verb, which is the only thing about it this row asserts: one non-empty sentence in the house shape, matched as a GLOB against the name the answer itself gave, so no destination serial lands in the verdict and a RULING on the words reddens nothing here.  WD9's deferral row makes its claim the same way.  The non-vacuity leg is that a DIFFERENT destination name gives a different sentence, so the name is interpolated rather than decoration" \
        [list [mt_shape [sk_msg destination dutyCycle __calc_dest9]] \
              [sk_names [sk_msg destination dutyCycle __calc_dest9] __calc_dest9] \
              [sk_names [sk_msg destination dutyCycle __calc_dest9] dutyCycle] \
              [sk_differ [sk_msg destination dutyCycle __calc_dest9] \
                         [sk_msg destination dutyCycle __calc_dest7]]] \
        {ok named named distinct}
    # --- the arm sweep, which is the only confirmation of the parity trap ----
    set sk_arms {}
    foreach ln [split [mt_decomment [pcall info body ::calc::arg_msg]] "\n"] {
        if {[regexp {^[ \t]*([a-zA-Z_][a-zA-Z0-9_]*)[ \t]+\{[ \t]*return} $ln -> k]} {
            lappend sk_arms $k
        }
    }
    set sk_armsbad {}
    foreach k $sk_arms {
        set m [sk_msg $k Level 1]
        if {[string match NOPROC:* $m]} { lappend sk_armsbad "$k:RAISED" ; continue }
        if {[string match RAISED:* $m]} { lappend sk_armsbad "$k:RAISED" ; continue }
        if {$m eq {}} { lappend sk_armsbad "$k:EMPTY" }
    }
    check "MT12 every calc::arg_msg arm -- DERIVED from the proc's own switch patterns and never listed here -- answers a non-empty sentence without raising, which is the only confirmation there is that no comment landed between two of its patterns: that balances the braces, satisfies `info complete`, and is PARITY-DEPENDENT, so an EVEN word count re-pairs the list into a silent no-op while an ODD one makes Tcl raise out of EVERY arm.  A green run proves only that the word count is even.  The arm this band's own vocabulary requires rides along, so the row is red until that arm exists rather than green over the ones that already do, and an unknown kind must still fall through to the empty string rather than raise" \
        [list $sk_armsbad [sk_in $sk_arms destination] [sk_in $sk_arms empty] \
              [sk_in $sk_arms __mt_no_such_arm__] \
              [mt_atleast [llength $sk_arms] 7] \
              [sk_msg __mt_no_such_arm__ a b]] \
        {{} has has missing atleast7 {}}
    # --- the one structural half of the ACT this arm can see ----------------
    set sk_pasters {} ; set sk_askers {} ; set sk_wired {} ; set sk_declarers {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        set nm [namespace tail $p]
        set b [pcall info body $p]
        if {[string match ERR:* $b]} continue
        set b [mt_decomment $b]
        if {[regexp {calc::buf_set_number} $b]} { lappend sk_pasters $nm }
        if {[regexp {calc::fn_sink[^A-Za-z0-9_]} $b]} { lappend sk_askers $nm }
        if {[regexp {calc::wave_dest[^A-Za-z0-9_]} $b]} { lappend sk_wired $nm }
        if {[regexp {shape[ \t]+wave} $b]} { lappend sk_declarers $nm }
    }
    set sk_unasked {}
    foreach nm $sk_pasters {
        if {[lsearch -exact $sk_askers $nm] < 0} { lappend sk_unasked $nm }
    }
    set sk_silent {}
    foreach nm $sk_wired {
        if {[lsearch -exact $sk_declarers $nm] < 0} { lappend sk_silent $nm }
    }
    check "MT12 ...and the ONE thing about the act itself this arm can see: every proc in the namespace whose CODE names calc::buf_set_number also names calc::fn_sink, derived over the namespace in one walk with neither set listed here -- so a success arm that pastes into the user's expression without first asking where the answer goes reddens naming itself.  The paster set rides along as a lower bound, because an empty one would make the subset claim vacuous.  That the buffer is really left UNTOUCHED and that the sentence really reaches .calc.status.msg are display-only and are NOT measured by this band" \
        [list $sk_unasked [mt_atleast [llength $sk_pasters] 1] \
              [sk_in $sk_pasters fn_measure]] \
        {{} atleast1 has}
    check "MT12 ...and what keeps `shape absent means buffer` honest, which is not this proc: every caller that builds a destination also DECLARES the shape, derived over the namespace as a SUBSET claim with a lower bound on the wired set rather than as an exact list -- so a future verb that answers a wave and forgets to say so reddens here naming itself, while units J2 and J3 wiring two more callers move no leg of this row.  The bound is why it cannot pass over an empty set, and the subset is why it does not have to be edited per caller" \
        [list $sk_silent [mt_atleast [llength $sk_wired] 1]] \
        {{} atleast1}
    check "MT12 R402 this band mints nothing and loads no fixture -- it drives a pure routing predicate and a sentence table with no database read at all, so no `__calc_tmp*` and no `__mt_*` may appear in the inventory because of it" \
        [list [leaked] [probeleft]] {{} {}}
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
## because nothing here needs a display, and a whole-file early exit that printed
## no sentinel would be scored `OVERALL_ok=0` with every one of its own checks
## passing (issue 1615).
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
