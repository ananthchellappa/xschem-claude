# tests/headless/test_calc_measure.tcl — the Calculator's MEASUREMENT verbs: the
# ones layered on `calc::cross`, and the ones that own an engine door of their
# own.
#
# ⚠ THE BANNER NAMES NO VERBS AND CARRIES NO COUNT, DELIBERATELY.  It used to
# read *"the three timing verbs layered on `cross`: `riseTime`, `delay` and
# `dutyCycle`"* and stayed that way while five more verbs landed under it, so the
# first thing a reader saw was a population the file had outgrown.  THE
# POPULATION IS DERIVED AND ASSERTED, not listed: `mt_spec_verbs` reads it off
# the catalogue and `calc::fn_argspec`, band MT10 partitions it into the
# delegating half and the own-door half and asserts the split, and MT11 derives
# the clickable set.  A new verb therefore enlists itself in those rows instead
# of needing this sentence edited -- which is the only arrangement under which
# the sentence cannot go stale again.
#
# Spec     doc/claude/specs/calculator.md §7.2 (the catalogue rows), §7.2aa
#          (R414-R414e, inherited through `cross`), §7.3 (R401-R405) and §11.2
#          (the fixture contract)
# Contract doc/claude/calculator_batch/TIMING_CONTRACT.md — R415, R416, T1-T7.
#          doc/claude/calculator_batch/CROSS_CONTRACT.md — D1-D12, STILL IN
#          FORCE for every verb of the DELEGATING half, which is the half that
#          answers through `calc::cross`; band MT10 derives and asserts which
#          verbs those are.
#          ⚠ D10 in that file is REVERSED; the live half is the heading, the
#          superseded reasoning sits in a collapsed block below it.
# Evidence doc/claude/calculator_batch/receipts/F2-cross-suite-and-implementation.md
# Plan     doc/claude/calculator_batch/PLAN.md row 7.3 for the first three verbs;
#          later rows of the same PLAN for the verbs added since.
# Fixture  tests/headless/data/calc_fixture.raw, contract and HAND DERIVATIONS
#          in tests/headless/data/README.md
#
# ⚠⚠ THIS FILE WAS WRITTEN RED-FIRST, BEFORE ANY OF THE VERBS IT WAS OPENED FOR
# EXISTED -- `riseTime`, `delay` and `dutyCycle`, named here because the claim is
# about the AUTHORING STAGE's own history and not about today's population.
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
# opposite order.  They were then run against the real tree with none of those
# verbs present and each was OBSERVED FAILING there, which is the property the
# red-first rule is actually about; what they do NOT have is the authoring-stage
# history of having been written blind.  The receipt names them.
#
# ⚠⚠ A COMMENT SWEEP THEN ADDED TWO MORE, AND BOTH WERE OPENED BY A SABOTAGE
# THIS FILE WAS GREEN OVER -- which is the only reason they are here rather than
# being prose corrections.  Band MT18/E drove ONE percentage pair, so a probe that
# restores the pre-repair pairing at `riseTime`'s OWN DEFAULT percentages left the
# whole file at ALL PASS while the shipped verb answered the wrong series for the
# request a user reaches by pressing go; E now takes its second pair from
# `info default`.  Row MT14/Q named *"every switch this stage touched"* while
# driving the message builders it lists, so an EVEN-word comment between
# `calc::overshoot`'s two switch patterns -- a verb the same stage minted -- also
# left the file at ALL PASS, where an odd-word one in the same place reddens rows
# across several bands at once; MT14/Q2 derives the whole switch-bearing
# population from the namespace. Row MT18/H does the same for
# `calc::transition_end`'s call sites, which three prose sentences counted and
# nothing measured.
#
# ---------------------------------------------------------------------------
# WHAT THE VERBS ARE, in the words of the rulings that decided them.  ⚠ THIS
# SECTION IS NOT THE POPULATION -- band MT10 derives that.  A verb whose ruling
# is recorded in its own band's header is not repeated here.
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
#   MT10 T1 the derived verb set PARTITIONS into the verbs that DELEGATE to
#        `calc::cross` and the verbs that own an engine door of their own, and
#        each half carries the claim that is true of it: a delegate reaches
#        `cross` and reads no samples -- structurally, as a TRANSITIVE closure
#        that permits a `::calc::` chain and forbids any link in it reading
#        samples, and behaviourally with `calc::cross` replaced by a refusing
#        stub -- while an own-door verb reaches `cross` NOWHERE and is the only
#        reader in its own closure.  ⚠ T1's original single claim was that ALL
#        of them delegate; `calc::overshoot` makes that FALSE of one, because an
#        extremum is not a crossing and no running min/max opcode exists, so the
#        band derives the split rather than hand-excluding the one verb.
#        Plus: every refusal in the house sentence shape; the answer
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
#  H12 WHAT T2's PAIRING BOUND COSTS IS UNRULED, AND IT IS A USER-VISIBLE
#     DISPOSITION.  `calc::transition_end` requires the end crossing to fall
#     before the NEXT start crossing, which is the only reading under which a
#     measurement is never a number for a transition that did not happen -- and it
#     necessarily changes TIMING_CONTRACT T2's own worked example.  On a trace that
#     WOBBLES across the start level before rising, the earlier wobble crossings
#     now answer an ABSENCE and the single measurement is anchored on the LAST
#     start crossing before the end one.  ⚠ The two situations are the SAME DATA:
#     a wobbling start and a transition that fails and is followed by one that
#     succeeds present the identical pair of crossing lists, so no rule reading
#     only those lists can tell them apart, and a rule reading the samples is
#     forbidden to these verbs by T1 (band MT10).  Whether the reference tool
#     measures a bouncing edge from its FIRST crossing of the start level is a
#     single question for the user; band MT18 asserts the disposition the tree has,
#     so a ruling either way reddens one named row instead of arriving as a puzzle.
#  H13 AN ABSOLUTE-THRESHOLD MODE IS NOT OFFERED AND `pctlo` 0 / `pcthi` 100 IS NOT
#     ONE.  Band MT19 measures that the spelling is exact where the trace passes
#     THROUGH both references and ill-posed where a reference is a value the trace
#     SITS AT, which is every rail-clamped digital trace -- the case an absolute
#     threshold is wanted for.  The reference tool's `initType`/`finalType` pair
#     would need a plateau-DEPARTURE rule rather than a crossing: the last sample
#     at the rail rather than an interpolated crossing of it.  That is a product
#     decision, it is NOT what this stage shipped, and `calc::slewRate`'s header no
#     longer claims otherwise.  ⚠ Band MT19/F is the fence against the repair that
#     looks obvious and is not.
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
# WARN THE SENTINEL IS MADE PARSEABLE AS A TCL LIST, AND THAT IS NOT COSMETIC.
# Tcl's list parser raises on an unmatched open brace or double quote that
# BEGINS A WORD -- the two characters, derived by sweeping every printable
# ASCII code rather than assumed -- and a product raise message carries either.
# So the bare `ERR:$r` this replaces could not be handed to `llength`,
# `lindex`, `foreach`, `lsort` or `dict keys`, and every site that did turned a
# product raise into ONE `group ... ABORTED` line that DELETED the whole band
# from the verdict instead of reddening one row.  That is strictly worse than a
# failure: the rows vanish, the count moves, and the next reader is sent to
# debug the product.  CLAUDE.md records the live incident this is not
# hypothetical about -- a comment between two `switch` patterns made
# `calc::fn_argspec` raise out of EVERY arm, 18 rows at once.
#
# The message is kept VERBATIM whenever it already parses, which is the common
# case, so a failing row's detail is unchanged except where it could not have
# been printed at all.  The mapped form is CHECKED rather than trusted, and a
# message that still will not parse is reduced to a shape that must.
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[pcall_listable $r]" }
    return $r
}
proc pcall_listable {s} {
    if {![catch {llength $s}]} { return $s }
    set m [string map [list \{ ( \} ) \" '] $s]
    if {![catch {llength $m}]} { return $m }
    return [regsub -all {[^A-Za-z0-9 ._:,/()=+*<>?!-]} $s ?]
}
# WARN A BAND THAT ABORTS DELETES ITS REMAINING ROWS FROM THE VERDICT, WHICH IS
# STRICTLY WORSE THAN FAILING, so the name is RECORDED and not only printed.
# One `FAIL: group ... ABORTED` line among dozens of row failures is easy to
# read past, and the rows that never ran are invisible -- the check total simply
# comes in short, which nothing compares against anything.  Measured 2026-10-05
# on this file: a product sabotage took MOST of band MT14's rows out and the
# verdict showed ONE extra failure.  ⚠ No row count is given, because this file's
# band sizes move and nothing re-measures a figure written here -- the very next
# stage to add a row to MT14 made the figure that used to sit in this sentence
# wrong.  `::abortnames` is asserted EMPTY by the
# band-abort guard at the foot of this file, which names every band that
# vanished instead of leaving the shortfall to be noticed.
set ::abortnames {}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        lappend ::abortnames $name
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
# open-coding the representation at the row site.  THE ONLY OTHER PLACES THAT
# MAY NAME THE KEYS ARE THE TWO STUBS -- `mt_stub_run`, which refuses, and
# `mt_st_record`, which ABSENTS and records its requests -- and MT10 has a row
# that derives the set of places which do and fails if it grows.
#
# ⚠ THAT ROW CAUGHT THE THIRD SITE ARRIVING, which is the only reason this
# sentence is correct: band MT16's recording stub was written with no thought
# for it, and MT10's derivation reddened on the very first green run of the
# verb naming `mt_st_record`.  A sentence nothing re-checks would have gone
# stale instead.
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
# ...and a SLICE, which `lrange` can no more take of a sentinel than `lindex`
# can.  Band MT15/D slices `cross`'s OWN crossing list to build its comparand,
# so the sliced value is a product answer and the bare spelling that used to be
# there took the band out through `group`'s catch.
proc mt_range {v a b} { if {[catch {lrange $v $a $b} r]} { return "NOTALIST:{$v}" } ; return $r }
# a count claim that cannot raise on a sentinel, for the one row that asserts a
# lower bound rather than an exact number.
proc mt_atleast {v n} {
    if {![string is integer -strict $v]} { return "notacount:$v" }
    if {$v >= $n} { return "atleast$n" }
    return "only:$v"
}

# ⚠⚠ FOUR MORE TOTAL ACCESSORS, AND THEY EXIST BECAUSE THE CLAIM ABOVE WAS TRUE
# ONE LEVEL IN AND FALSE ONE LEVEL OUT.  `mt_len` and `mt_at` made INDEXING
# total, and four bands reached a raise anyway, each by a DIFFERENT route: one
# divided a bare `expr` by an element of `[mt_val ...]`, which is a disposition
# WORD when the verb did not measure; one subtracted 1 from `mt_len`'s OWN
# sentinel; and two handed a producer answer straight to `lmap`, which PARSES
# ITS LIST ARGUMENT before the body runs at all -- so a body built entirely out
# of total procs was still not enough.  Each raise became one
# `group ... ABORTED` line and silently deleted every remaining row of its band
# from the verdict, which is worse than a failure because the reader is sent to
# debug the product.  Band MT20 derives the population of the shape over this
# file's own text and asserts it is empty, and drives these procs on a poison
# sentinel to show they are total.
proc mt_nminus {n k} {
    if {![string is integer -strict $n]} { return $n }
    return [expr {$n - $k}]
}
# two COUNTS, as a word.  `expr {$a != $b}` does not raise on a sentinel -- it
# falls back to a string comparison -- so the bare spelling this replaces could
# answer `differ` about two things that were not counts at all, and band MT15/H
# leans on that `differ` to say it is not reading one number twice.
# a BOOLEAN answer as a word.  `expr`'s `?:` raises on an operand that is not a
# boolean, so a `pcall` sentinel in the condition -- which is what a raise
# inside the product produces -- took band MT20 out through `group`'s catch
# instead of failing the row.  This names what it got instead.
proc mt_boolword {v yes no} {
    if {![string is boolean -strict $v]} { return "NOTABOOL:{$v}" }
    return [expr {$v ? $yes : $no}]
}
proc mt_countsdiffer {a b} {
    if {![string is integer -strict $a]} { return "notacount:{$a}" }
    if {![string is integer -strict $b]} { return "notacount:{$b}" }
    return [expr {$a != $b ? {differ} : {SAME}}]
}
# a scalar over every element of a series.  THE QUOTIENT IS STILL A PLAIN `expr`
# ON TWO DOUBLES, deliberately, so that a caller comparing this against a verb's
# own series with `string equal` and no tolerance keeps its bit-identity claim
# exactly; what is added is the guard and a sentinel that FAILS the row rather
# than killing the band.
proc mt_ratios {num series} {
    if {![mt_finite $num]} { return "NOTANUMBER:{$num}" }
    set n [mt_len $series]
    if {![string is integer -strict $n]} { return $n }
    set out {}
    for {set i 0} {$i < $n} {incr i} {
        set e [mt_at $series $i]
        if {![mt_finite $e]} { return "NOTANUMBER:\[$i\]{$e}" }
        if {double($e) == 0.0} { return "ZEROELEM:\[$i\]" }
        lappend out [expr {$num / $e}]
    }
    return $out
}
# `mt_distinct` over every element of a series against one comparand, answering
# the `lsort -unique` of the per-element words -- the shape a row site spelled
# `lsort -unique [lmap e [mt_val ...] {mt_distinct $e $b}]`, where the raise was
# the `lmap` and never the body.
proc mt_distinctmap {series b} {
    set n [mt_len $series]
    if {![string is integer -strict $n]} { return $n }
    set out {}
    for {set i 0} {$i < $n} {incr i} {
        lappend out [mt_distinct [mt_at $series $i] $b]
    }
    return [lsort -unique $out]
}
# ...and the same claim over TWO series pairwise, which is the two-varlist
# `lmap` spelling.  Unequal lengths answer a WORD rather than being padded:
# `lmap`'s own padding compares a real element against the EMPTY STRING and
# calls the pair distinct, so the shorter answer a dropped point produces would
# have read as discrimination.
proc mt_distinctmap2 {s1 s2} {
    set n1 [mt_len $s1]
    set n2 [mt_len $s2]
    if {![string is integer -strict $n1]} { return $n1 }
    if {![string is integer -strict $n2]} { return $n2 }
    if {$n1 != $n2} { return "LEN:$n1|$n2" }
    set out {}
    for {set i 0} {$i < $n1} {incr i} {
        lappend out [mt_distinct [mt_at $s1 $i] [mt_at $s2 $i]]
    }
    return [lsort -unique $out]
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
# ...the same claim over two SERIES THAT NEED NOT BE THE SAME LENGTH, aligned on
# their TAILS.  Answers the `lsort -unique` of the per-element words, so one word
# is a claim about every pair it compared, plus a sentinel for anything that is
# not a list or is empty.
#
# ⚠ THE TAIL AND NOT THE HEAD, and the alignment is the whole reason this proc
# exists.  Two readings of one signal in two datasets drop a point when a
# transition fails, and a dropped point is always a PREFIX of the series here --
# the failing transition is the first one -- so indexing from the front compares
# dataset 0's transition 1 against dataset 1's transition 2 and the `distinct` it
# answers is about two different edges.  From the back the k-th-from-last
# transitions line up.  ⚠ It is NOT a replacement for a length leg: a row using
# this must assert both lengths separately, because a producer that answered one
# element would satisfy the word and say nothing.
proc mt_tailpairs {a b} {
    if {[catch {llength $a} na]} { return "NOTALIST:{$a}" }
    if {[catch {llength $b} nb]} { return "NOTALIST:{$b}" }
    set k [expr {$na < $nb ? $na : $nb}]
    if {$k < 1} { return "tooshort:$na|$nb" }
    set out {}
    for {set i 1} {$i <= $k} {incr i} {
        lappend out [mt_distinct [lindex $a end-[expr {$i-1}]] [lindex $b end-[expr {$i-1}]]]
    }
    return [lsort -unique $out]
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
# ⚠⚠ BOTH SIDES GO THROUGH `mt_len` / `mt_at`, AND THE COMMENT HERE USED TO
# DECLARE THE OPPOSITE.  It read *"bare `llength` / `lindex` on the EXPECTED,
# and the asymmetry is the point: the guard is for what the PRODUCT supplies"*,
# which was false at the one site that mattered: band MT15/D's comparand is a
# SLICE OF `cross`'S OWN CROSSING LIST, so the expected side is a product answer
# too, and a sabotage that made the producer raise reached a bare `llength`
# here.  The sibling suite's `wd_listcmp` carried the identical asymmetry and
# the identical caller.  The guard is for whatever the PRODUCT supplies, which
# is not always the first argument.
proc mt_islist {a exps} {
    if {[mt_disp $a] ne {measured}} { return [mt_disp $a] }
    set v [mt_val $a]
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    set m [mt_len $exps]
    if {![string is integer -strict $m]} { return "EXPS:$m" }
    if {$n != $m} { return "count=$n want=$m got={$v}" }
    set bad {}
    for {set i 0} {$i < $n} {incr i} {
        set r [near [mt_at $v $i] [mt_at $exps $i] $::MTTOL]
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
#
# ⚠⚠ TWO LEGS, AND THE SECOND ONE IS WHY THE PARAGRAPH ABOVE NO LONGER SAYS
# "the regexp IS the predicate".  THE SPELLING OF A NUMBER AND THE NUMBER ITSELF
# ARE DIFFERENT QUESTIONS: `1e309` is a perfectly ordinary decimal spelling whose
# VALUE is an infinity, so a regexp-only predicate vouched for every overflowing
# literal a user can type and the arithmetic downstream then computed on an
# infinity.  The copy here mirrors BOTH legs, so it keeps being a change
# detector over the whole predicate rather than over half of it, and band MT0's
# agreement row drives the overflowing spellings as well as the ones `%g` emits.
# The regexp runs FIRST and is what makes the second leg total: `double()` raises
# on `nan` and on an empty string, and every string that reaches it here has
# already been admitted as a decimal.  Row CE10 of
# tests/headless/test_calc_engine.tcl measures that totality over a population
# derived from the regexp's own alternatives, including a mantissa and an
# exponent long enough to be parsed as bignums.
proc mt_finite {v} {
    set v [string trim $v]
    if {![regexp {^-?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} $v]} { return 0 }
    set d [expr {double($v)}]
    return [expr {$d > -Inf && $d < Inf}]
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

# ⚠⚠ T2's PAIRING, DERIVED BY A SINGLE PASS OVER THE SAMPLES AND NOT BY A WALK
# OVER TWO CROSSING LISTS -- WHICH IS THE WHOLE OF ITS INDEPENDENCE FROM THE
# PRODUCT, AND IS WHY IT REPLACED THE WALK THIS FILE USED TO DO.  The derivations
# that feed `riseTime`'s and `slewRate`'s per-transition rows used to pair *"the
# first end crossing after this start"*, which is the loop the product had, so the
# comparand reproduced the product's pairing BY CONSTRUCTION and agreed with it on
# the one axis the rows were supposed to be measuring.  Measured: on
# `{v(sq) v(ramp) *}` with the start level crossed three times and the end level
# twice, both answered a THREE-element series where two transitions complete, and
# every element-wise row was green over it.
#
# This is a STATE MACHINE over the straddling pairs and it holds at most ONE open
# transition: a start crossing REPLACES whatever start was open, and an end
# crossing closes the open start and emits the pair.  So a transition that reaches
# the start level and falls back without reaching the end level is discarded when
# the next start arrives, and there is no list for a later transition's end
# crossing to be taken out of -- the defect is not expressible in this shape,
# which is what makes the disagreement with an unbounded producer evidence.
#
# ⚠ BOTH LEVELS ARE TESTED IN THE SAME PAIR, start first.  A steep edge against a
# coarse grid crosses both thresholds between two samples, and for a rising
# request `L1 < L2` while for a falling one `L1 > L2`, so in BOTH directions the
# `L1` crossing interpolates to the smaller X -- the start is processed first with
# no direction-dependent ordering and the pair is emitted from one sample pair.
#
# ⚠ THE PREDICATE AND THE INTERPOLATION ARE `mt_derive`'s, reached by calling it on
# the one pair, so this proc introduces no third copy of D3/D4 -- the thing MT0
# already watches for drift against `calc::cross_pair`.
#
# Answers a flat list of `<startx> <endx>` pairs in sweep order.
proc mt_pair_scan {xs ys L1 L2 edge} {
    set out {}
    set open {}
    set n [llength $ys]
    set nx [llength $xs]
    if {$nx < $n} { set n $nx }
    for {set p 1} {$p < $n} {incr p} {
        set px [list [lindex $xs [expr {$p-1}]] [lindex $xs $p]]
        set py [list [lindex $ys [expr {$p-1}]] [lindex $ys $p]]
        set s [mt_derive $px $py $L1 $edge]
        set e [mt_derive $px $py $L2 $edge]
        if {[llength $s]} { set open [lindex $s 1] }
        if {[llength $e] && $open ne {}} {
            lappend out $open [lindex $e 1]
            set open {}
        }
    }
    return $out
}
# the start X values of those pairs, and the end X values, as two lists.
proc mt_pair_starts {pr} { set o {} ; foreach {a b} $pr { lappend o $a } ; return $o }
proc mt_pair_ends   {pr} { set o {} ; foreach {a b} $pr { lappend o $b } ; return $o }
# ...and the UNBOUNDED pairing this file used to do, kept ON PURPOSE as the
# comparand a discrimination leg needs: a row claiming the bound matters has to
# assert something about the reading that ignores it, and the only honest way to
# do that is to compute it.  Never used as an expectation.
proc mt_pair_unbounded {xs ys L1 L2 edge} {
    set ss [mt_derive_x $xs $ys $L1 $edge]
    set es [mt_derive_x $xs $ys $L2 $edge]
    set out {}
    foreach a $ss {
        set b {}
        foreach e $es { if {$e > $a} { set b $e ; break } }
        if {$b eq {}} continue
        lappend out $a $b
    }
    return $out
}
# the first element of a sorted list strictly greater than `x`, or the empty
# string.  ⚠ THIS IS NOT A PAIRING RULE and no derivation may use it as one --
# that is `mt_pair_scan`'s job and the distinction is the whole of band MT18.
# It exists for the one row that rebuilds a slope out of `calc::cross`'s OWN two
# crossing answers on a column that has exactly ONE start crossing, where there
# is no next start for a bound to be.
proc mt_firstafter {lst x} {
    if {[catch {llength $lst}]} { return "NOTALIST:{$lst}" }
    foreach e $lst { if {$e > $x} { return $e } }
    return {}
}
# `c + k*y` element-wise, so a row can derive in Tcl the column an RPN of the
# shape `<y> <k> * <c> +` mints through the engine, without a `lrepeat` at the
# row site.  `mt_prod` and `mt_offprod` are the two-column forms; this is the
# scalar one.
proc mt_affine {ys k c} {
    if {[string match ERR:* $ys]} { return $ys }
    if {[catch {llength $ys}]} { return "NOTALIST:{$ys}" }
    set out {}
    foreach y $ys {
        if {![mt_finite $y]} { return "NOTANUMBER:{$y}" }
        lappend out [expr {double($c) + double($k) * double($y)}]
    }
    return $out
}
# how a column stands against a LEVEL, as the three counts `<on> <below>
# <above>`: samples bit-exactly ON it, strictly below it and strictly above it.
#
# ⚠ BIT-EXACT AND NEVER `near`, which is the point of the proc.  A level a trace
# is CLAMPED to has samples exactly equal to it, and `calc::cross_pair`'s rising
# arm is `y0 < L` STRICTLY -- so `below` being zero while `on` is large is
# precisely the state in which no rising crossing of that level exists, and a
# tolerance-based count could not say so.
proc mt_railcounts {ys L} {
    if {[catch {llength $ys}]} { return "NOTALIST:{$ys}" }
    set on 0 ; set below 0 ; set above 0
    foreach y $ys {
        if {![mt_finite $y]} continue
        if {double($y) == double($L)} { incr on ; continue }
        if {double($y) < double($L)} { incr below ; continue }
        incr above
    }
    return [list $on $below $above]
}
# the samples strictly above a level, as their own values, so a row can assert
# HOW MANY there are and then derive the dust from the one that is there rather
# than quoting it.
proc mt_dustabove {ys L} {
    if {[catch {llength $ys}]} { return "NOTALIST:{$ys}" }
    set out {}
    foreach y $ys { if {[mt_finite $y] && double($y) > double($L)} { lappend out $y } }
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
    # ⚠ `correct` IS THE HIGH CROSSING OF THE TRANSITION THIS LOW CROSSING OPENED,
    # read out of `mt_pair_scan`, and that is a CORRECTION rather than a
    # refinement: it used to be *"the first high crossing anywhere after `lox`"*,
    # the same unbounded walk the product had, so this derivation shared the
    # product's defect and the rows comparing the two were green over a stolen
    # crossing.  NONE now covers both "this low crossing opened no completed
    # transition" and "there is no high crossing after it at all", which are the
    # same answer for a rise time and are told apart by the SENTENCE the verb
    # answers, not by this proc.
    set correct NONE
    foreach {a b} [mt_pair_scan $xs $ys $Llo $Lhi rising] {
        if {$a == $lox} { set correct $b ; break }
    }
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
    # ⚠ THE PAIRING IS `mt_pair_scan`'s AND NOT A WALK OVER THOSE TWO LISTS.  The
    # lists are still read, because `nlo`/`nhi` ride along so a row can assert
    # that a point was DROPPED rather than that the fixture had fewer edges -- but
    # the SERIES comes from the sample scan, which cannot take a later
    # transition's high crossing.  See `mt_pair_scan`'s header for the
    # measurement that moved it.
    set rx {} ; set ry {}
    foreach {a b} [mt_pair_scan $xs $ys $llo $lhi rising] {
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
# The claim that does the work is the CONDITIONAL one: wherever the two crossing
# lists interleave strictly one for one, the two pairing directions are provably
# THE SAME LIST, and on the committed columns a request whose two thresholds lie
# inside one monotone edge interleaves that way.
#
# ⚠⚠ AND IT IS A PROPERTY OF THE REQUEST, NOT OF THE COLUMN -- which an
# earlier revision of this paragraph got wrong by quoting one request's two
# crossing lists as if they characterised the column.  `{v(sq) v(ramp) *}`
# interleaves 1:1 at some swings and does NOT at the swing band MT18 drives,
# where the start level is crossed three times and the end level fewer -- that
# IS the band's whole fixture.  So no pair of lists is written down here: band
# MT18/A derives both counts from the column at run time, and MT18/E drives the
# same column at TWO percentage pairs precisely because the structure moves with
# the request.
#
# ⚠⚠ THE PARTIAL-DROP REQUEST CANNOT SEPARATE THEM EITHER, AND THE REASON GIVEN
# HERE USED TO BE FALSE IN A WAY WORTH KEEPING VISIBLE.  It said *"a dropped point
# is always a SUFFIX of the low list, because if `low[i]` has no high crossing
# after it then no later low crossing has one either"* -- true of the UNBOUNDED
# pairing this file and the product both used, and false now that
# `calc::transition_end` requires the high crossing to fall before the next low
# one: an INTERIOR or LEADING low crossing drops whenever its own transition fails
# to reach the high threshold, which is precisely the shape band MT18 drives and
# the shape the glitch column's occurrence 1 is.  What survives is the narrow
# claim, which is all this paragraph needed: on a request whose two lists
# interleave 1:1 no point drops at all, so the two pairing directions coincide
# there whatever rule closes a transition -- and the band therefore has to mint a
# column rather than pick a request, because no request on a committed column
# separates them.
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
    set m [mt_len $exps]
    if {![string is integer -strict $m]} { return "EXPS:$m" }
    if {$n != $m} { return "count=$n want=$m got={$v}" }
    set bad {}
    for {set i 0} {$i < $n} {incr i} {
        set r [near [mt_at $v $i] [mt_at $exps $i] $tol]
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
# ...and the complementary derivation: the `calc::cross_msg` arms ONE VERB can
# reach, taken from its own decommented body with the same regexp
# `mt_sl_handoff_kinds` uses, split into the arms whose names begin with the
# supplied prefix (the verb's OWN voice) and the rest (the ones it REUSES from
# `cross`).  Answers `{own {...} reused {...}}`.
#
# ⚠ THIS EXISTS BECAUSE THREE PROSE SITES AND ONE ROW NAME CARRIED A REUSED-ARM
# COUNT AND ALL THREE DISAGREED WITH THE TREE AND WITH EACH OTHER.  A count
# over a proc's own text is a figure an instrument must recompute; band MT17/K
# now compares the arms it drives against this derivation instead of against a
# number, so an arm added to the verb cannot sit outside the row while the row
# reads as covering it.
proc mt_verb_msg_arms {p pfx} {
    if {[info commands ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    set b [pcall info body ::calc::$p]
    if {[string match ERR:* $b]} { return "NOBODY:calc::$p" }
    set own {} ; set reused {}
    foreach {all k} [regexp -all -inline \
                         {calc::cross_msg[ \t]+([a-zA-Z_][a-zA-Z0-9_]*)} \
                         [mt_decomment $b]] {
        if {$pfx ne {} && [string match $pfx* $k]} { lappend own $k ; continue }
        lappend reused $k
    }
    return [list own [lsort -unique $own] reused [lsort -unique $reused]]
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
# ...the same answer with the X values STRIPPED, as the words `strict` and
# `onsample` only.  ⚠ IT EXISTS BECAUSE `mt_allstrict`'s OWN ANSWER CARRIES A
# NUMBER, and a row comparing that against an expectation would put a
# reproducible figure in the T1 verdict -- the house rule a sibling row called
# *"half a grid step off every sample"* broke.  One word per outcome is a claim
# about the whole crossing list and about nothing else.
proc mt_strictwords {xs ys L edge} {
    set r [mt_allstrict $xs $ys $L $edge]
    if {[regexp {^(ERR|NOTALIST|NOTANUMBER|NOPAIR):} $r]} { return $r }
    set out {}
    foreach w $r { lappend out [lindex [split $w :] 0] }
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
# ...and does it issue a DIRECT `xschem raw` write or read of its own?  This is
# SR5's discipline in test_calc_scratch_reuse seen from the other side, where
# `cross` is allowed to be the one direct reader.
#
# ⚠ WHICH VERBS ANSWER `yes` IS NOT WRITTEN HERE, AND THAT IS THE FIX FOR A
# SENTENCE THAT WAS FALSE TWICE OVER.  It used to say T1 made the answer `no`
# for all three verbs; by then the population was neither three nor uniformly
# `no`.  Band MT10 DERIVES the partition with this proc and ASSERTS it, and
# MT17/O carries the per-verb claim for the half that owns a door -- so the
# membership is a measurement in a row and never a count in this comment.
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
# THE LAYERED MEASUREMENT VERBS, DERIVED FROM THE PRODUCT'S OWN TWO TABLES:
# every route-T catalogue name that answers a NON-EMPTY `calc::fn_argspec`,
# minus `cross`, which is the primitive the others are layered ON.
#
# ⚠ A hand-kept list here is the same defect one level up, and band MT10 carried
# one until a fourth verb arrived.  Deriving it makes a new verb ENLIST ITSELF
# in every delegation claim instead of being measured by nothing while the band
# stays green -- the shape row X1 of test_snprintf_fmt_1608.tcl exists to warn
# about and the shape a sibling arm sweep shipped for a month at 24 of 31 arms.
#
# ⚠⚠ THE PROC'S EXISTENCE IS DELIBERATELY NOT PART OF THE DERIVATION, and that
# is load-bearing rather than an omission.  MT10 compares this set against the
# subset whose procs really exist, so an argument spec that landed WITHOUT its
# measurement proc appears here and is missing there -- which is what forces the
# two halves of a verb into one commit and makes the gap a named red instead of
# a dialog that composes a call to nothing.
proc mt_spec_verbs {} {
    set out {}
    foreach row [pcall calc::catalogue] {
        if {[catch {lindex $row 2} r]} continue
        if {$r ne {T}} continue
        if {[catch {lindex $row 0} nm]} continue
        if {$nm eq {cross}} continue
        if {[llength [pcall calc::fn_argspec $nm]] == 0} continue
        lappend out $nm
    }
    return [lsort $out]
}
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

# ⚠⚠ `::calc::transition_end` REPLACED BY THE EXACT UNBOUNDED LOOP ALL FOUR CALL
# SITES USED TO CARRY INLINE, which is band MT18's sabotage and is BUILT rather
# than argued.  `calc::riseTime` and `calc::slewRate` each had this loop twice --
# once in the `nth`-0 arm and once in the ordinal arm -- so swapping the one proc
# they now share reproduces the pre-repair behaviour at all four sites exactly,
# and that is the second thing the probe measures: a site that still had a loop
# of its own would NOT move when this proc is swapped.
#
# The slot is checked BEFORE the rename, so a previous failed run inside the same
# interpreter cannot be mistaken for a product defect, and the original is
# restored on BOTH exit paths.  rc 2 is `return` and not an error -- `mt_stub_run`
# shipped its first revision treating it as one.
# ⚠⚠ `::calc::cross_pair` REPLACED BY THE TOLERANCE-AWARE PREDICATE THAT IS THE
# OBVIOUS REPAIR FOR THE RAIL LIMIT BAND MT19 DECLARES -- BUILT, SO THE DECISION
# NOT TO SHIP IT IS A MEASUREMENT AND NOT AN OPINION.  The scale is the PAIR'S OWN
# MAGNITUDE together with the level's, which is the only scale that proc has: it
# sees one level and two samples and nothing about the column.  A scale taken from
# the level alone is undefined at a zero level, and `v(sq)`'s own low reference IS
# zero, which band MT19/A asserts.
#
# The slot is checked before the rename and the original restored on both exit
# paths; `eps` rides in a global so the body is fixed text rather than an
# interpolated string, which is how a probe like this grows a quoting defect.
set mt_tolpair_eps 0
proc mt_tolpair_run {eps script} {
    if {[info commands ::calc::cross_pair] eq {}} { return NOPROC:calc::cross_pair }
    if {[info commands ::mt_cp_keep] ne {}} { return CPSLOTBUSY }
    rename ::calc::cross_pair ::mt_cp_keep
    set ::mt_tolpair_eps $eps
    proc ::calc::cross_pair {x0 x1 y0 y1 L edge} {
        if {![calc::eval_finite $y0] || ![calc::eval_finite $y1]} { return {} }
        if {![calc::eval_finite $x0] || ![calc::eval_finite $x1]} { return {} }
        set sc [expr {max(abs(double($L)), max(abs(double($y0)), abs(double($y1))))}]
        if {$sc == 0.0} { set sc 1.0 }
        set tol [expr {double($::mt_tolpair_eps) * $sc}]
        set d0 [expr {double($y0) - double($L)}]
        set d1 [expr {double($y1) - double($L)}]
        if {abs($d0) <= $tol} { set d0 0.0 }
        if {abs($d1) <= $tol} { set d1 0.0 }
        set rise [expr {$d0 <  0.0 && $d1 >= 0.0}]
        set fall [expr {$d0 >  0.0 && $d1 <= 0.0}]
        if {$rise} {
            set dir rising
        } elseif {$fall} {
            set dir falling
        } else {
            return {}
        }
        if {$edge ne {either} && $edge ne $dir} { return {} }
        set x [expr {$x0 + ($L - $y0)*($x1 - $x0)/($y1 - $y0)}]
        if {![calc::eval_finite $x]} { return {} }
        return [list $dir $x]
    }
    set rc [catch {uplevel 1 $script} r]
    catch {rename ::calc::cross_pair {}}
    catch {rename ::mt_cp_keep ::calc::cross_pair}
    if {$rc != 0 && $rc != 2} { return "ERR:$r" }
    return $r
}
# THE RIPPLE THE TOLERANCE HAS TO NOT ERASE: an amplitude of 1e-12 on a unit
# rail, which is about 4500 units in the last place of a double and is therefore
# a quantity the engine, the raw file and the viewer all represent exactly.  A
# predicate that calls it noise is deciding a measurement does not exist.  The
# angular frequency is read off the sweep column's own endpoints, so no period is
# written down.
proc mt_ripple_amp {} { return 1e-12 }
proc mt_ripplerpn {xs n} {
    set w [mt_ringw $xs $n]
    if {![mt_finite $w]} { return $w }
    return "1 time $w * sin() [mt_ripple_amp] * +"
}
# THREE WORDS ABOUT ONE CANDIDATE PREDICATE, each a claim about the FIXTURE and
# never about a tolerance: does the first rising crossing of the high reference
# agree with the deck's own arrival time (`deck`) or not (`late`); does the low
# reference's falling-crossing count match the number of falling edges the trace
# has (`sized`) or exceed it (`extra`); and are the ripple's rising crossings
# still all there (`kept`) or gone (`erased`).
#
# ⚠ WRITTEN WITH `if` AND NOT A TERNARY, because a braced `expr` whose branch is a
# command substitution answering a sentinel raises *invalid bareword*, which
# `group`'s catch turns into an abandoned band rather than one failed row.
proc mt_railverdict {rpn L0 L1 arrival nedge ripple nrip} {
    set a late
    set hi [mt_call cross $rpn $L1 0 rising 0]
    if {[near [mt_at [mt_val $hi] 0] $arrival $::MTTOL] eq {ok}} { set a deck }
    set b extra
    set lo [mt_call cross $rpn $L0 0 falling 0]
    if {[mt_len [mt_val $lo]] eq $nedge} { set b sized }
    set c erased
    set rp [mt_call cross $ripple 1.0 0 rising 0]
    if {[mt_len [mt_val $rp]] eq $nrip} { set c kept }
    return [list $a $b $c]
}

set mt_tend_calls 0
proc mt_tend_unbounded {script} {
    if {[info commands ::calc::transition_end] eq {}} { return NOPROC:calc::transition_end }
    if {[info commands ::mt_tend_keep] ne {}} { return TENDSLOTBUSY }
    rename ::calc::transition_end ::mt_tend_keep
    proc ::calc::transition_end {starts ends x0 {whyvar {}}} {
        if {$whyvar ne {}} { upvar 1 $whyvar why }
        set why none
        incr ::mt_tend_calls
        foreach e $ends { if {$e > $x0} { set why ok ; return $e } }
        return {}
    }
    set ::mt_tend_calls 0
    set rc [catch {uplevel 1 $script} r]
    catch {rename ::calc::transition_end {}}
    catch {rename ::mt_tend_keep ::calc::transition_end}
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
    # ⚠ THE POPULATION HAS TWO HALVES AND THE SECOND IS NOT A SPELLING `%g` CAN
    # EMIT.  The first half is every non-finite spelling `dtoa` and the MSVC
    # runtime write, which is what the predicate's own header is about.  The
    # second is DERIVED FROM THE DOUBLE FORMAT rather than listed: an exponent
    # sequence past the double range and the `%.16g` spelling of the largest
    # finite double, which `xschem raw values` really writes and which reads back
    # as an infinity because sixteen significant digits round that value UP past
    # itself.  Those are ordinary decimal spellings, so the SPELLING leg accepts
    # every one of them and only the parsed leg can tell them apart -- which is
    # what makes this row a change detector over the whole predicate instead of
    # over its regexp.
    set mt0DMAX [expr {(2.0 - 2.0**-52) * 2.0**1023}]
    set mt0POP [list 0.5 -0 1e-35 .5 -3.5e-9 inf -inf nan -nan NaN INF \
                     1.#INF -1.#IND 1.#QNAN {} abc 1e308 1e-400]
    for {set mt0k 1} {$mt0k <= 3} {incr mt0k} {
        lappend mt0POP [format {1e%d} [expr {308 + $mt0k * $mt0k}]]
        lappend mt0POP [format {-1e%d} [expr {308 + $mt0k * $mt0k}]]
    }
    lappend mt0POP [format {%.16g} $mt0DMAX] [format {%.8g} $mt0DMAX]
    check "MT0 this suite's own mt_finite agrees with calc::eval_finite on every spelling dtoa and the MSVC runtime can emit AND on an overflow population derived from the double format -- a CHANGE DETECTOR over two copies of the same two-leg predicate, NOT independent evidence, because a wrong leg would be wrong identically in both copies and this row would still be green.  ⚠ THE DISCRIMINATION LEG IS THE POPULATION'S OWN: the members whose SPELLING is an ordinary decimal while the value is an infinity must be a non-empty set, or the overflow half is green over spellings the regexp already got right" \
        [list [join [lmap v $mt0POP {list $v [mt_finite $v] [pcall calc::eval_finite $v]}] { }] \
              [expr {[llength [lsearch -all -inline -regexp $mt0POP {^-?[0-9.]+e}]] > 0 ? {reaches} : {VACUOUS}}] \
              [mt_finite [format {%.16g} $mt0DMAX]] [mt_finite [format {%.8g} $mt0DMAX]] \
              [mt_finite 1e309] [mt_finite 1e308]] \
        [list [join [lmap v $mt0POP {list $v [mt_finite $v] [mt_finite $v]}] { }] \
              reaches 0 1 0 1]
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
    #
    # ⚠⚠ THE FIRST OF THE THREE USED TO ASSERT THAT THE TWO READINGS AGREE AT
    # OCCURRENCE 1 AND NAMED MT4's FIRST ROW A CONTROL THAT DISCRIMINATES NOTHING.
    # Both halves of that were an artefact of this file's own derivation sharing
    # the product's unbounded pairing: the glitch at occurrence 1 peaks BETWEEN
    # the two thresholds, so the transition it opens reaches no high threshold at
    # all, and the number the two readings used to agree on was a high crossing
    # taken from the SECOND excursion.  With `mt_t2`'s `correct` reading derived
    # by `mt_pair_scan` the agreement is gone and occurrence 1 is the sharpest of
    # the three: the correct reading has NO answer and the naive one is a finite
    # number.  The non-vacuity leg says the low crossing itself exists, so this is
    # the no-completed-transition shape and not a short list.
    check "MT1 T2 at occurrence 1 the two readings DISAGREE ABOUT WHETHER THERE IS AN ANSWER AT ALL -- the transition that low crossing opens never reaches the high threshold, so the per-transition reading answers NONE while the naive nth-at-each-level reading answers a finite number taken from a later excursion.  Derived from the column at run time, with the low crossing asserted to exist so the NONE is a failed transition and not an empty list" \
        [list [mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 1 correct] \
              [mt_finite [mt_t2_rt $t0 $g0 [sq_thr 0 1 12] [sq_thr 0 1 88] 1 naive]] \
              [mt_atleast [llength [mt_derive_x $t0 $g0 [sq_thr 0 1 12] rising]] 1]] \
        {NONE 1 atleast1}
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
    # ⚠⚠ THIS ROW WAS A DECLARED CONTROL THAT DISCRIMINATED NOTHING AND IS NOW THE
    # BAND'S SHARPEST ROW, and the reason is T2's BOUND rather than a new fixture.
    # The glitch at occurrence 1 peaks between the two thresholds, so the
    # transition it opens reaches no high threshold; the unbounded pairing took the
    # high crossing of the SECOND excursion and answered a rise time straddling
    # two bumps, and this file's own derivation made the same mistake, which is why
    # the two "agreed".  The absence is reported in `calc::cross_msg`'s `nohighin`
    # arm by IDENTITY, which is what tells it from the off-the-end absence the
    # fourth row below measures -- those two are in different FAMILIES.
    #
    # ⚠ `nohighin` AND NOT `nohigh`, AND THE DIFFERENCE IS THE POINT.  A LATER
    # high crossing does exist here -- it belongs to the SECOND excursion, which
    # is precisely the one the unbounded pairing used to steal -- so the sentence
    # that says there is "no high crossing after it in this sweep" would be FALSE
    # of this request.  `nohigh` is the arm for the other reason, measured by the
    # row two below, where no high crossing follows at all.  Both are absences and
    # both are in the *Rise time* family; what separates them is which true thing
    # the user is told, and `calc::transition_end`'s reason out-parameter is what
    # lets the verb tell them apart.
    check "MT4 T2 occurrence 1 is an ABSENCE in the nohighin arm, asserted by identity against the sentence calc::cross_msg builds for that ordinal: the excursion that opens it peaks between the two thresholds, so the transition reaches no high threshold before the next one begins, while a later excursion's high crossing DOES exist -- which is why this is the bounded-pairing arm and not the no-crossing-at-all one.  The naive nth-at-each-level reading's own finite answer rides along, so the row shows it can discriminate rather than claiming it" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 1]]] \
              [mt_t2_rt $t0 $g0 $Llo $Lhi 1 correct] \
              [mt_finite [mt_t2_rt $t0 $g0 $Llo $Lhi 1 naive]] \
              [string equal [mt_msg $a] \
                   [pcall calc::cross_msg nohighin [pcall calc::cross_ordinal 1]]] \
              [string equal \
                   [pcall calc::cross_msg nohighin [pcall calc::cross_ordinal 1]] \
                   [pcall calc::cross_msg nohigh [pcall calc::cross_ordinal 1]]] \
              [mt_family [mt_msg $a]]] \
        {absent NONE 1 1 0 {Rise time}}
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
    # ⚠⚠ THE DISCRIMINATION HERE IS NOW A DISPOSITION AND NOT A VALUE, AND THAT IS
    # STRONGER RATHER THAN WEAKER.  It used to be that `-1` and `+1` selected low
    # crossings whose rise times differed by far more than MTTOL, so an `abs(nth)`
    # implementation answered a different NUMBER.  With T2's bound in place `+1`
    # opens no completed transition at all, so an `abs(nth)` implementation answers
    # an ABSENCE where the correct one measures -- a difference no tolerance is
    # involved in.  `-2` rides along so the row is not satisfied by "every negative
    # ordinal measures", and the last leg DECLARES what this column cannot show:
    # occurrences 2 and 3 are the same slope, so their rise times are the SAME and
    # nothing here tells `-1` from `-2` by value.
    check "MT4 R414c a NEGATIVE occurrence counts the LOW crossings from the END, discriminated by DISPOSITION: -1 selects the last low crossing and measures the derivation for the last occurrence, -2 the one before it, while +1 -- what an abs(nth) implementation would select -- opens no completed transition and is an ABSENCE.  The low-crossing count rides along, and the final leg states that this column's last two occurrences have the SAME rise time so no value leg here could separate them" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 -1]]] \
              [mt_is $a [mt_t2_rt $t0 $g0 $Llo $Lhi [llength [mt_derive_x $t0 $g0 $Llo rising]] correct]] \
              [mt_disp [set c [mt_call riseTime $gl 0 1 12 88 -2]]] \
              [mt_is $c [mt_t2_rt $t0 $g0 $Llo $Lhi \
                             [expr {[llength [mt_derive_x $t0 $g0 $Llo rising]] - 1}] correct]] \
              [mt_disp [mt_call riseTime $gl 0 1 12 88 1]] \
              [mt_sized [llength [mt_derive_x $t0 $g0 $Llo rising]] 3] \
              [mt_distinct [mt_t2_rt $t0 $g0 $Llo $Lhi 2 correct] \
                           [mt_t2_rt $t0 $g0 $Llo $Lhi 3 correct]]] \
        {measured ok measured ok absent sized same}
    # ⚠⚠ -3 AND -4 ARE BOTH ABSENCES NOW, AND THE ROW SEPARATES THEM BY THE
    # SENTENCE'S FAMILY RATHER THAN BY THE DISPOSITION.  `-3` must reach the FIRST
    # low crossing -- which exists and opens no completed transition -- so it
    # answers `calc::cross_msg`'s `nohigh` arm, in the *Rise time* family; `-4`
    # falls off the end of the low list from the far side, which `calc::cross`
    # itself refuses to find, so it answers that proc's own `absent` arm in the
    # *Cross* family.  Compared by IDENTITY against both sentences and asserted to
    # be in different families, which is what a `-3` wrongly treated as a synonym
    # for last, or an `abs(nth)` reading, cannot produce.  An earlier revision of
    # this row discriminated by VALUE and could only do so because the pairing was
    # unbounded.
    check "MT4 R414c ...and the negative ordinal is an ORDINAL, not a synonym for last: -3 reaches the FIRST low crossing, which exists and completes no transition before the next one begins, so the absence is calc::cross_msg's nohighin arm by identity, while -4 falls off the end of the low list and is calc::cross's OWN absent arm by identity -- two absences in two different families from one column, which is what separates an ordinal from a clamp" \
        [list [mt_disp [set a [mt_call riseTime $gl 0 1 12 88 -3]]] \
              [string equal [mt_msg $a] \
                   [pcall calc::cross_msg nohighin [pcall calc::cross_ordinal -3]]] \
              [mt_disp [set b [mt_call riseTime $gl 0 1 12 88 -4]]] \
              [string equal [mt_msg $b] \
                   [pcall calc::cross_msg absent [pcall calc::cross_ordinal -4] rising]] \
              [mt_notfamily [mt_msg $a] [mt_msg $b]]] \
        {absent 1 absent 1 elsewhere}
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
    # T1.  THE DELEGATING HALF of the derived verb set is measured two ways,
    # because neither way alone is enough: a one-level structural regexp cannot see
    # a verb that reads samples through a helper -- which is why the structural half
    # is a TRANSITIVE CLOSURE rather than a regexp over one body -- and the
    # behavioural stub cannot see a verb that calls `cross` AND also reads samples
    # itself.  THE OWN-DOOR HALF carries the complementary claim, structurally
    # only, because a verb that never calls `cross` cannot be measured through a
    # `cross` stub at all; its per-verb legs are band MT17/O.
    #
    # ⚠ EVERY ROW HERE THAT MAKES A CLAIM ABOUT THE VERBS CARRIES THE SET OF
    # VERBS THAT ARE PRESENT AS THE FIRST ELEMENT OF WHAT IT COMPARES, and every
    # row about one HALF carries that half as well.  Without the first, "none of
    # them issues a direct `xschem raw` verb" is VACUOUSLY TRUE while they do not
    # exist, and the row would pass on a tree with no feature in it -- which is
    # the sibling suite's accidental passes in structural form.  Without the
    # second, a partition that put every verb in the other half would make a
    # sweep vacuous instead of reddening.
    # TWO ROWS HERE MAKE NO SUCH CLAIM and so carry no `present` leg, which is
    # stated rather than left as an apparent exception: the closure instrument's own
    # non-vacuity row is about the INSTRUMENT (and reddens on the featureless tree
    # anyway, because a NOPROC closure is not `deeper`), and `mt_dictsites` is about
    # THIS FILE'S OWN TEXT, where the feature's existence is irrelevant.
    pcall mt_load tran
    # ⚠⚠ THE VERB SET IS DERIVED FROM THE PRODUCT'S OWN TWO TABLES AND IS NO
    # LONGER A LIST WRITTEN HERE, WHICH IS THE DEFECT ROW X1 OF
    # test_snprintf_fmt_1608.tcl EXISTS TO WARN ABOUT, ONE LEVEL UP.  It used to
    # read `{riseTime delay dutyCycle}`, and a fourth layered verb would have
    # been measured by nothing in this band while every row stayed green -- the
    # same shape as the sibling arm sweep that drove 24 of its proc's 31 arms for
    # a month and read as coverage.  `mt_spec_verbs` is every route-T catalogue
    # name that answers a non-empty argument spec, minus `cross`, which is the
    # primitive the others are layered ON and so cannot be a delegate to itself.
    #
    # ⚠ THE PROC IS DELIBERATELY NOT REQUIRED BY THAT DERIVATION, AND THAT IS
    # WHAT MAKES THE `present` LEG BELOW A REAL MEASUREMENT RATHER THAN A
    # TAUTOLOGY: a verb whose argument spec has landed and whose proc has not
    # appears in `verbs` and is absent from `present`, so the two halves of a
    # verb are forced to land in ONE commit and the gap reddens here naming the
    # missing proc.
    set verbs [mt_spec_verbs]
    set present {}
    foreach v $verbs { if {[info commands ::calc::$v] ne {}} { lappend present $v } }
    # ⚠⚠ THE PARTITION, DERIVED, AND IT IS NOT A RELAXATION OF WHAT THIS BAND
    # USED TO CLAIM.  T1 said every layered verb is a PURE DELEGATE on
    # `calc::cross`, and that was true of every member of the derived set until
    # `calc::overshoot` joined it.  THE SENTENCE CARRIES NO COUNT, DELIBERATELY:
    # the sizes of the two halves are what the row below measures, as FLOORS
    # rather than as figures, and an earlier revision of this paragraph quoted a
    # membership count that no instrument re-checks and that was arithmetically
    # impossible -- the set only reaches that size once `overshoot` is in it, and
    # `overshoot` is the one member the claim is false of.
    #
    # `calc::overshoot` makes it FALSE of itself: an extremum is not a crossing,
    # there is no running
    # min/max opcode in the RPN engine and no min/max accessor on `xschem raw`,
    # so that verb opens its own engine door.  A band whose only shape was ONE
    # claim about ALL of them had exactly two ways out -- hand-exclude the new
    # verb, which is the hand-kept-list defect one level up, or weaken the claim
    # for everybody.  Neither is taken.  The set is SPLIT by the same structural
    # instrument, each half carries the claim that is TRUE of it, and the split
    # itself is asserted -- so a verb that quietly grew a door MOVES from one
    # half to the other and is measured there, and a delegate that was never a
    # delegate still reddens.  Band WD9 of
    # tests/headless/test_calc_wave_dest.tcl already derives a partition this
    # way for the deferral sentence's callers; this is the same shape.
    set delegates {} ; set owndoor {}
    foreach v $verbs {
        if {[mt_direct_raw $v] eq {yes}} { lappend owndoor $v ; continue }
        lappend delegates $v
    }
    check "MT10 T1 the derived verb set PARTITIONS into the verbs that DELEGATE to calc::cross and the verbs that own an engine door of their own, split by the same structural instrument the claims below use -- with a floor on BOTH halves and the partition asserted, so a verb that quietly grew a door moves from one half to the other and is measured there instead of being hand-excluded from a single claim.  ⚠ The two halves are NOT interchangeable: a delegate must reach cross and must read no samples, an own-door verb must NOT reach cross and must be the ONLY reader in its own closure, and each row below says which half it is about.  The membership of one name per half rides along as a positive control on the instrument"         [list $present [lsort [concat $delegates $owndoor]] \
              [mt_atleast [llength $delegates] 3] [mt_atleast [llength $owndoor] 1] \
              [expr {[lsearch -exact $delegates riseTime] >= 0 ? {has} : {MISSING}}] \
              [expr {[lsearch -exact $owndoor overshoot] >= 0 ? {has} : {MISSING}}]] \
        [list $verbs $verbs atleast3 atleast1 has has]
    check "MT10 the verb set this band's claims are about is DERIVED from the catalogue and from calc::fn_argspec -- every route-T name with a non-empty argument spec, minus the primitive they are layered on -- so a new layered verb ENLISTS ITSELF in every row below instead of being measured by nothing.  The floor rides along because an empty derivation would make all of them vacuous, and `cross` is asserted absent because it is the one name that must not be in it" \
        [list [mt_atleast [llength $verbs] 3] \
              [expr {[lsearch -exact $verbs cross] < 0 ? {nocross} : {CROSS}}] \
              [expr {[lsearch -exact $verbs riseTime] >= 0 ? {has} : {MISSING}}] \
              [expr {[lsearch -exact $verbs average] < 0 ? {noP} : {ROUTEP}}]] \
        {atleast3 nocross has noP}
    # the instrument's own control, which PASSES TODAY: `calc::cross` is
    # legitimately a direct adder and reader, and the decommenter must not have
    # eaten its body to reach that answer.
    check "MT10 the structural instrument works: calc::cross IS a direct xschem raw adder and reader, the decommenter leaves its body non-empty, and it does remove something -- so a `no` below is evidence and not an artefact of an empty string" \
        [list [mt_direct_raw cross] \
              [expr {[string length [mt_decomment [info body ::calc::cross]]] > 200}] \
              [expr {[string length [mt_decomment [info body ::calc::cross]]] \
                     < [string length [info body ::calc::cross]]}]] {yes 1 1}
    check "MT10 T1 each verb of the DELEGATING half REACHES calc::cross -- derived as a transitive closure over the ::calc:: names in the decommented bodies, stopping AT cross, so a shared period derivation that itself calls cross is permitted while a verb that never reaches cross at all is not.  The half's own membership rides along, because an empty half would make the sweep vacuous" \
        [list $present $delegates [lmap v $delegates {mt_reaches_cross $v}]] \
        [list $verbs $delegates [lrepeat [llength $delegates] reaches]]
    check "MT10 T1 ...and NO proc in any of those closures, cross alone excepted, issues an xschem raw add, values, value or del of its own -- which is SR5's discipline seen from the other side, and which is what forbids T1's evaluate-once helper: such a helper has to evaluate into a column of its own, so it appears here by name" \
        [list $present $delegates [lmap v $delegates {mt_closure_raw $v}]] \
        [list $verbs $delegates [lrepeat [llength $delegates] {}]]
    # ...and the COMPLEMENTARY claim for the other half, which is what stops the
    # split being an escape hatch: a verb with its own door must NOT reach
    # `cross` -- a verb that did both would be evaluating twice and reporting
    # once -- and must be the ONLY direct reader inside its own closure, so a
    # helper it reached for would appear here by name exactly as it would in the
    # delegating half's row.
    check "MT10 T1 ...and each verb of the OWN-DOOR half makes the COMPLEMENTARY claim: it issues the direct engine verb itself, it reaches calc::cross NOWHERE -- a verb that did both would evaluate the expression twice and report once -- and it is the ONLY direct reader in its own ::calc:: closure, so a helper it reached for appears here by name.  This is the half `calc::overshoot` is in, and the per-verb legs for it are band MT17/O" \
        [list $present $owndoor [lmap v $owndoor {mt_direct_raw $v}] \
              [lmap v $owndoor {mt_reaches_cross $v}] \
              [lmap v $owndoor {mt_closure_raw $v}]] \
        [list $verbs $owndoor [lrepeat [llength $owndoor] yes] \
              [lrepeat [llength $owndoor] no] $owndoor]
    check "MT10 T1 ...and the closure instrument is NOT vacuous: calc::cross's own closure is itself, every verb's closure is strictly larger than the bare verb, and a name no such proc has answers NOPROC rather than an empty set that would satisfy the row above" \
        [list [mt_calc_closure cross] \
              [lmap v $verbs {expr {[llength [mt_calc_closure $v]] > 1 ? {deeper} : {bare}}}] \
              [mt_reaches_cross nosuchverb_zz] [mt_closure_raw nosuchverb_zz]] \
        [list cross [lrepeat [llength $verbs] deeper] NOPROC NOPROC]
    check "MT10 the answer representation is known in exactly the procs the header enumerates -- derived by walking THIS FILE for every site that builds the answer dict and naming the enclosing proc, because the three sites that broke this claim were at ROW level where no scan of info body could reach them" \
        [mt_dictsites] {mt_asanswer mt_st_record mt_stub_run}
    # THE BEHAVIOURAL HALF.  A verb that still answers a number with
    # `calc::cross` replaced by a refusing stub is reading samples itself,
    # whatever its body looks like.
    # ⚠⚠ THE ARGUMENT TABLE IS HAND-WRITTEN BECAUSE EACH VERB NEEDS DIFFERENT
    # ARGUMENTS, AND THE KEY-SET LEG BESIDE IT IS WHAT STOPS THAT BEING A
    # HAND-KEPT LIST ONE LEVEL UP: the names it carries must be EXACTLY the
    # DERIVED verb set, so a new layered verb reddens here until it is really
    # driven through the stub instead of being quietly left out of the sweep.
    # That is the enlisting half the old flat list of three calls had no way to
    # express, and it is the same correction `mt_crossmsg_arms` made for the
    # sentence table.
    set stubargs [list \
        riseTime  {{v(sq)} 0 1 10 90 1} \
        delay     {{v(sq)} 0.5 rising 1 {v(sq)} 0.5 falling 1} \
        dutyCycle {{v(sq)} 0.5 1} \
        slewRate  {{v(sq)} 0 1 10 90 1 rising 0} \
        frequency {{v(sq)} 0.5 rising 1} \
        freq      {{v(sq)} 0.5 rising 1} \
        settlingTime {{v(sq)} 1 0.01 0}]
    set stub [mt_stub_run {
        set bad {} ; set n 0
        foreach v $delegates {
            if {![dict exists $stubargs $v]} { lappend bad "$v=NOARGS" ; continue }
            incr n
            set a [mt_call $v {*}[dict get $stubargs $v]]
            if {[mt_disp $a] ne {refused}} { lappend bad "$v=[mt_disp $a]" ; continue }
            if {![string match {*MTSTUB*} [mt_msg $a]]} { lappend bad "$v=nomarker" }
        }
        return [list $bad $n]
    }]
    check "MT10 T1 with ::calc::cross replaced by a refusing stub, EVERY verb of the DELEGATING half REFUSES and carries the stub's own sentence through -- so each answer came back through cross rather than from samples the verb read itself, and the refusal composes rather than being replaced.  The probe's own argument table must name EXACTLY that half, which is the leg that enlists a new delegating verb rather than letting it sit outside the sweep -- and an own-door verb left in the table would redden here too, which is what keeps the partition honest in both directions" \
        [list $present [lindex $stub 0] [mt_sized [lindex $stub 1] [llength $delegates]] \
              [lsort [dict keys $stubargs]]] \
        [list $verbs {} sized $delegates]
    check "MT10 T1 ...and the stub was called at least once per delegating verb, so the refusals are delegation and not several verbs refusing for their own unrelated reasons" \
        [list $present [mt_atleast $::mt_stub_calls [llength $delegates]]] \
        [list $verbs atleast[llength $delegates]]
    check "MT10 ::calc::cross is RESTORED by that probe and answers the shipped value again, so no row after this one is measuring a stubbed namespace" \
        [list [mt_disp [set a [mt_call cross {v(sq)} 0.5 1 rising]]] \
              [near [mt_val $a] [sq_rise 0.5 0] $MTTOL] \
              [llength [info commands ::mt_cross_keep]]] {measured ok 0}
    # THE HOUSE SENTENCE SHAPE, per verb and per refusal kind, named so a
    # failure says WHICH sentence fell out of shape rather than that one did.
    # The WORDS are never asserted: they are unratified user-visible wording.
    check "MT10 every refusal these hand-named requests reach is in the house shape calc::eval_msg, calc::plot_msg and calc::cross_msg all use -- a capital, a colon and a full stop -- stated as the shape and never as the words, which are unratified" \
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
    } \
    slewRate {
        {lo      {Low level}           real                         1 {}}
        {hi      {High level}          real                         1 {}}
        {pctlo   {Low threshold %}     real                         0 10}
        {pcthi   {High threshold %}    real                         0 90}
        {edge    {Edge}                {enum rising falling}        0 rising}
        {nth     {Occurrence (Nth)}    int                          0 1}
        {dataset {Dataset}             int                          0 0}
    } \
    frequency {
        {level   {Level}               real                         1 {}}
        {edge    {Edge}                {enum rising falling}        0 rising}
        {xaxis   {X axis}              {enum start number mid}      0 start}
        {cycle   {Cycle}               int                          0 0}
        {dataset {Dataset}             int                          0 0}
    } \
    freq {
        {level   {Level}               real                         1 {}}
        {edge    {Edge}                {enum rising falling}        0 rising}
        {xaxis   {X axis}              {enum start number mid}      0 start}
        {cycle   {Cycle}               int                          0 0}
        {dataset {Dataset}             int                          0 0}
    } \
    settlingTime {
        {final   {Final value}         real                         1 {}}
        {tol     {Tolerance}           real                         1 {}}
        {start   {Start time}          real                         1 {}}
        {dataset {Dataset}             int                          0 0}
    } \
    overshoot {
        {initial {Initial value}       real                         1 {}}
        {final   {Final value}         real                         1 {}}
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
    # ⚠ THE NAME BELOW CARRIES NO COUNT, DELIBERATELY.  It used to say the loop
    # skips `all 34 T rows` and that the wrong phrasing would be asserted `over
    # four verbs that ARE available`: both are figures a command produces over
    # the catalogue's own text, nothing here re-measured either, and the second
    # was already false -- the very next row DERIVES the available set and names
    # every member of it.  The route-T population is the catalogue's business and
    # the arity row above is what fences the table; what THIS row measures is the
    # three `fn_reason` answers, and that is all its name now claims.
    check "MT11 route T still has NO refusal reason, so the S23 loop that clicks every entry the browser drew still skips every route-T row -- the truthful click message belongs in a route-T branch of `calc::fn_click` and NOT in `calc::fn_reason`, where it would make that loop assert the \"is not available\" phrasing over the verbs that ARE available, which is the set the next row derives and row S28 of tests/headless/test_calc_skeleton.tcl asserts that sentence is never said over" \
        [list [pcall calc::fn_reason T] [pcall calc::fn_reason P] \
              [expr {[pcall calc::fn_reason N] ne {} ? 1 : 0}]] {{} {} 1}

    # --- the clickable set, derived -----------------------------------------
    check "MT11 the clickable set is DERIVED from the tree -- every route-T catalogue row that has a proc of its own -- so a verb whose proc lands without its argument spec, or the reverse, reddens here and in the fall-through sweep below rather than composing a call to nothing" \
        [ag_verbs] {cross delay dutyCycle freq frequency overshoot riseTime settlingTime slewRate}
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
    check "MT11 the route-T fall-through is LEGIBLE rather than accidental: every catalogue name that is not one of the clickable set answers an EMPTY spec, and each member of that set answers a non-empty one -- swept over the whole table, with both counts riding along so neither direction can be vacuous" \
        [list $agnswept $agnonempty $agempty] {108 9 {}}

    # --- the specifications, by literal, ONE ROW EACH ------------------------
    # ⚠ `frequency` AND `freq` ARE TWO CATALOGUE NAMES SERVED BY ONE `switch`
    # ARM through Tcl's documented fall-through, so the two rows below compare
    # two literals against one spec.  That is deliberate: the fall-through is
    # what keeps the spec from existing twice in the product, and these two rows
    # are what would catch a second copy drifting if somebody ever wrote one.
    foreach agv {cross riseTime delay dutyCycle slewRate frequency freq settlingTime \
                 overshoot} {
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
        [list [llength [ag_verbs]] $agbadrpn] {9 {}}

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
    # ⚠⚠ `slewRate`'s EDGE LIST IS ITS OWN AND IS SHORTER THAN `cross`'s BY ONE
    # MEMBER, WHICH IS WHY IT IS LIFTED SEPARATELY RATHER THAN SHARING `$agedge`.
    # `either` is refused by this verb before anything reaches the database: a
    # slew rate pairs TWO threshold crossings, so under `either` the first
    # threshold's nth crossing can be a falling one whose next crossing of the
    # second threshold belongs to the following transition -- a confident number
    # for a transition that never happened.  So the verb validates `edge`
    # ITSELF, against its own literal, and this lift is what stops the dialog
    # offering a third edge the verb would refuse in the field.
    set agsledge [ag_enum_in slewRate edge]
    # ⚠⚠ `frequency`'s TWO LISTS ARE LIFTED FROM `calc::frequency` AND SERVE
    # `freq` TOO, because `calc::freq` IS A PURE DELEGATE and `ag_enum_in`
    # therefore answers `NOLITERAL:freq/edge` for it -- which band MT15/O asserts
    # from the other side as the claim that the member lists exist exactly ONCE
    # in the tree.  Lifting `freq`'s members from its own body would either
    # require a second copy of them in the product or make the drift rows below
    # vacuous for the alias, and the first of those is the defect the delegate
    # exists to avoid.
    set agfqedge [ag_enum_in frequency edge]
    set agfqax [ag_enum_in frequency xaxis]
    check "MT11 fixture: the member lists really were LIFTED out of the validators' own bodies -- `calc::cross`'s `edge` test, `calc::dutyCycle`'s `xaxis` test, `calc::slewRate`'s OWN shorter edge test and `calc::frequency`'s own two -- so a drift row below is evidence and not an artefact of an empty match, and both shorter edge lists being strict subsets of cross's is asserted rather than assumed.  `calc::freq` is a pure delegate and carries NO literal of its own, which is asserted here as a NOLITERAL sentinel rather than left to be discovered as an empty match" \
        [list $agedge $agax $agsledge $agfqedge $agfqax \
              [expr {[llength $agsledge] < [llength $agedge] ? {shorter} : {NOTSHORTER}}] \
              [expr {[llength $agfqedge] < [llength $agedge] ? {shorter} : {NOTSHORTER}}] \
              [ag_enum_in freq edge] [ag_enum_in freq xaxis]] \
        [list {rising falling either} {start number mid} {rising falling} \
              {rising falling} {start number mid} shorter shorter \
              NOLITERAL:freq/edge NOLITERAL:freq/xaxis]
    set agbadenum {} ; set agnenum 0
    foreach {agv agk aglit} [list cross edge $agedge dutyCycle xaxis $agax \
                                  delay edgeA $agedge delay edgeB $agedge \
                                  slewRate edge $agsledge \
                                  frequency edge $agfqedge frequency xaxis $agfqax \
                                  freq edge $agfqedge freq xaxis $agfqax] {
        incr agnenum
        set kind [ag_field $agv $agk 2]
        set mem [lrange $kind 1 end]
        if {[ag_cell $kind 0] ne {enum}} { lappend agbadenum $agv/$agk=notenum($kind) ; continue }
        if {$mem ne $aglit} { lappend agbadenum $agv/$agk=members($mem)vs($aglit) }
    }
    check "MT11 every enum field offers EXACTLY the members its own validator tests against, lifted from the shipped body -- so a dialog offering a fourth edge, or a renamed axis, is caught by the drift instead of by someone noticing a refusal in the field; the alias's two fields are swept against the literals of the proc it DELEGATES to, which is the only body that has any" \
        [list $agnenum $agbadenum] {9 {}}
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
    # ⚠ `slewRate` BELONGS IN THIS LOOP ONLY BECAUSE IT VALIDATES `edge` BEFORE
    # IT TOUCHES THE DATABASE, which is a constraint on the implementation and
    # not an accident of where the test sits.  A verb that deferred the
    # membership test until after the first accessor would answer the no-data
    # refusal for a NON-member too, and the control legs below -- which require a
    # non-member to be refused by slewRate's own arm -- would redden.
    foreach m [lrange [ag_field slewRate edge 2] 1 end] {
        incr agnreach
        set got [mt_msg [mt_call slewRate {v(sq)} 0 1 10 90 1 $m 0]]
        if {$got eq [pcall calc::cross_msg slewbadedge $m]} { lappend agunreachable slewedge/$m }
    }
    # ⚠ `frequency` VALIDATES BOTH OF ITS ENUMS BEFORE IT TOUCHES THE DATABASE
    # for the same reason `slewRate` does, and that is a constraint on the
    # implementation rather than an accident of where this loop sits: a verb that
    # deferred either membership test until after the first accessor would answer
    # the no-data refusal for a NON-member too, and the control legs below -- which
    # require a non-member to be refused by frequency's own arms -- would redden.
    foreach m [lrange [ag_field frequency edge 2] 1 end] {
        incr agnreach
        set got [mt_msg [mt_call frequency {v(sq)} 0.5 $m 0 0 start]]
        if {$got eq [pcall calc::cross_msg freqedge $m]} { lappend agunreachable freqedge/$m }
    }
    foreach m [lrange [ag_field frequency xaxis 2] 1 end] {
        incr agnreach
        set got [mt_msg [mt_call frequency {v(sq)} 0.5 rising 0 0 $m]]
        if {$got eq [pcall calc::cross_msg freqxaxis $m]} { lappend agunreachable freqxaxis/$m }
    }
    check "MT11 every member the dialog offers is one the verb ACCEPTS: with no result loaded each member gets past its own membership test and meets the no-data refusal, while a non-member is refused by the membership test itself -- so the two sentences tell acceptance from rejection with no fixture at all.  ⚠ slewRate's own shorter edge list is swept here too, and `either` is driven as a NON-member against it: cross accepts that word and slewRate must not, which is the one place the two validators are shown to disagree behaviourally" \
        [list [mt_atleast $agnreach 13] $agunreachable \
              [expr {[mt_msg [mt_call dutyCycle {v(sq)} 0.5 0 0 sideways]] eq [pcall calc::cross_msg badxaxis sideways] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call cross {v(sq)} 0.5 1 sideways]] eq [pcall calc::cross_msg badedge sideways] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call slewRate {v(sq)} 0 1 10 90 1 sideways 0]] eq [pcall calc::cross_msg slewbadedge sideways] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call slewRate {v(sq)} 0 1 10 90 1 either 0]] eq [pcall calc::cross_msg slewbadedge either] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call frequency {v(sq)} 0.5 sideways 0 0 start]] eq [pcall calc::cross_msg freqedge sideways] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call frequency {v(sq)} 0.5 either 0 0 start]] eq [pcall calc::cross_msg freqedge either] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call frequency {v(sq)} 0.5 rising 0 0 sideways]] eq [pcall calc::cross_msg freqxaxis sideways] ? {refused} : {ACCEPTED}}] \
              [expr {[mt_msg [mt_call freq {v(sq)} 0.5 either 0 0 start]] eq [pcall calc::cross_msg freqedge either] ? {refused} : {ACCEPTED}}]] \
        {atleast13 {} refused refused refused refused refused refused refused refused}
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
    # ⚠ `frequency` IS A SECOND WITNESS FOR THE SAME CLAIM, and its display order
    # was chosen to differ from its formal order deliberately so that it is one:
    # the dialog shows level / edge / X axis / cycle / dataset while the proc
    # takes rpn / level / edge / cycle / dataset / xaxis, so a positional
    # composition hands it `start` where its cycle ordinal belongs.  One witness
    # for a rule this consequential is one verb away from zero.
    check "MT11 ...and a SECOND witness for the by-key composition, on a verb whose display order differs from its formal order in a DIFFERENT place: `frequency` shows its X axis third and takes it last, so a positional composition hands it the axis where the cycle ordinal belongs.  The two orders are shown to differ in the run rather than asserted in this row's name" \
        [list [ag_vals frequency {v(sq) 2 *} \
                   [list level 0.4 edge falling xaxis mid cycle -1 dataset 1]] \
              [ag_keys frequency] \
              [expr {[ag_keys frequency] ne [mt_formals frequency] ? {differ} : {SAME}}]] \
        [list {rpn {v(sq) 2 *} level 0.4 edge falling cycle -1 dataset 1 xaxis mid} \
              {level edge xaxis cycle dataset} differ]
    check "MT11 ...and the control that says why the behavioural arm is blind to it: on `cross`, whose display order and formal order COINCIDE, the by-key and the positional composition are the same list -- so the rows above are the only things in the three suites that measure the difference; a name with no surface proc composes NOTHING rather than guessing, and the composer's presence rides along so neither leg can be green over a missing proc" \
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

# ---------------------------------------------------------------------------
# MT13 -- PLAN 5.1 / R410: `calc::fn_action`, THE ROUTING DECISION BEHIND A
# FUNCTION-BROWSER CLICK, FACTORED OUT SO IT GATES ON THE COUNTED ARM.
#
# Spec     doc/claude/specs/calculator.md section 7.4 (R410-R413) and section
#          8.1 (R506).
# Contract doc/claude/calculator_batch/CLICK_CONTRACT.md sections 1, 4 and 5.
# Fence    the ACT -- the token really reaching `.calc.buf`, the one-step undo
#          and the status sentence really reaching `.calc.status.msg` -- is
#          display-only and lives in band S23 of
#          tests/headless/test_calc_skeleton.tcl and band CW13 of
#          tests/headless/test_calc_widgets.tcl, both `dcases` ALONE.
#
# ⚠⚠ WRITTEN RED-FIRST, BEFORE `calc::fn_action` EXISTED.  Every row below
# failed when it was written and each failure named `NOPROC:calc::fn_action`
# rather than raising; the transcript is in the stage receipt.
#
# WHY A PURE PROC AND NOT A BRANCH INSIDE `calc::fn_click`, which is the shape
# the defect had.  `calc::buf_insert_token` and `calc::status` both return `{}`
# with no window, so the whole of the ACT is invisible on the counted arm and
# every row that could see it would be `dcases`-only -- which is how stage J1
# shipped a producer whose success arm pasted a measured LIST over the user's
# expression with nothing registered able to notice.  The axis that works is
# DECISION versus ACT: this proc is the decision, it needs no Tk, and so the
# question "does a click on this entry reach a live arm at all" is answered on
# the arm that gates every commit.
#
# THE SHAPE, which this band is the specification of:
#
#   calc::fn_action <name>  ->  {insert <token>}      route P or C: R410's token
#                               {measure}            route T: R412's dialog
#                               {unavailable <why>}  a dead route (RULING-3)
#                               {inert}              a live route with no token
#                               {}                   no such catalogue entry
#
# The vocabulary is a list whose FIRST word is the act and whose remainder is
# the datum that act needs, so the dispatcher is a `switch` on one word and
# never has to look a second thing up -- which is the property the structural
# row below asserts, because a dispatcher that re-read the catalogue would have
# moved half the decision back off this arm.
#
# ⚠ `{inert}` IS A DEFENSIVE ARM AND THE CENSUS ROW BELOW IS WHAT SAYS SO.  It
# is reached by NO catalogue row today -- every row carries a dead route, or
# route T, or a non-empty `insert` -- so `calc::inert`'s phase-5 promise is now
# unreachable from a browser click, and that is asserted as a DERIVED property
# of the live catalogue rather than left as a remark.  A future live row with an
# empty token would land there and say so instead of inserting an empty string.
#
# ⚠ WHAT THIS BAND DOES NOT MEASURE, said out loud: the STATUS SENTENCE.
# `calc::status` is a silent no-op with no window (R508), so the sentence
# `function <name>: inserted <token>` cannot be read here at all; it is fenced
# on the display arm in S23 and CW13, and the rows there compare it against the
# catalogue's own `insert` field rather than against a re-spelled literal.  The
# same goes for a `fn_click` that ignored this proc's token and inserted its own
# `name` formal instead -- that is its formal, not a catalogue read, so the
# structural row below cannot see it and the display arm is the only reader.
# ---------------------------------------------------------------------------

# the decision for one name, or a legible sentinel -- never a raise, and "the
# proc is missing" and "the proc threw" are told apart because they want
# different fixes.
proc ac_act {name} {
    if {[info commands ::calc::fn_action] eq {}} { return "NOPROC:calc::fn_action" }
    if {[catch {::calc::fn_action $name} r]} { return "RAISED:$r" }
    return $r
}
# the act word of a decision, or the sentinel, so a row comparing words cannot
# raise on one.  `mt_at` is this file's non-raising `lindex`.
proc ac_verb {a} {
    if {[string match NOPROC:* $a] || [string match RAISED:* $a]} { return $a }
    if {$a eq {}} { return {none} }
    return [mt_at $a 0]
}

# =========================================================================
group MT13 {
    check "MT13 `calc::fn_action` EXISTS and is a proc of exactly one formal, read off the interpreter with `info args` rather than scanned for out of the file's text -- the instrument that caught every one of the 43 derived sabotages a sibling signature pin slept through" \
        [list [expr {[info commands ::calc::fn_action] ne {} ? 1 : 0}] \
              [pcall info args ::calc::fn_action]] \
        {1 name}
    # --- the four acts, one name each, each one read off the table -----------
    # ⚠ THE TOKEN IS COMPARED AGAINST `calc::fn_row`'s OWN `insert` FIELD, never
    # against a literal spelled here: R413's "one table, not two" is exactly the
    # defect a test that re-types `avg()` would re-introduce one level up.
    check "MT13 a route-P name decides INSERT, carrying the `insert` field of its own catalogue row -- compared against `calc::fn_row` BY IDENTITY, so a decision that invented a token or read a second table reddens" \
        [list [ac_act average] [ac_act integ]] \
        [list [list insert [lindex [pcall calc::fn_row average] 4]] \
              [list insert [lindex [pcall calc::fn_row integ] 4]]]
    check "MT13 a route-C name decides INSERT too, with its whole multi-token recipe intact -- routes P and C differ in whether the engine has one opcode for the job, which is nothing a CLICK can act on, so a branch that refused the four C rows would be an artificial restriction" \
        [ac_act rms] [list insert [lindex [pcall calc::fn_row rms] 4]]
    check "MT13 a route-T name decides MEASURE and carries no token -- R401/R404: a T verb's click never inserts the word `cross`, it opens R412's dialog and puts a NUMBER in the buffer" \
        [list [ac_act cross] [ac_act dutyCycle]] {measure measure}
    check "MT13 a dead-route name decides UNAVAILABLE and carries `calc::fn_reason`'s OWN sentence for its route, compared BY IDENTITY -- the reason is budgeted for the composed line (fn_reason's own comment) and re-spelling it in a test is how two wordings for one fact get shipped" \
        [list [ac_act dft] [ac_act pzbode]] \
        [list [list unavailable [pcall calc::fn_reason N]] \
              [list unavailable [pcall calc::fn_reason X]]]
    check "MT13 a name that is in no catalogue row decides NOTHING -- an empty answer, not a raise and not an `inert` promise about a function that does not exist" \
        [list [ac_act __no_such_function__] [ac_verb [ac_act __no_such_function__]]] \
        {{} none}

    # --- THE CENSUS, DERIVED OVER THE WHOLE LIVE CATALOGUE ------------------
    # ⚠ THE POPULATION IS THE CATALOGUE ITSELF AND THE PREDICATES ARE
    # INDEPENDENT OF THE PROC UNDER TEST: each row's EXPECTED act is derived
    # from its own route and `insert` field plus `calc::fn_dead_routes`, and the
    # row reports every DISAGREEMENT by name.  A hand-kept list of names would
    # be the same defect one level up, and a sweep over an empty population is
    # green while measuring nothing -- so both counts ride along.
    set ac_bad {} ; set ac_n 0
    array unset ac_cnt
    foreach ac_v {insert measure unavailable inert none} { set ac_cnt($ac_v) 0 }
    foreach ac_row [pcall calc::catalogue] {
        incr ac_n
        set ac_nm [lindex $ac_row 0]
        set ac_rt [lindex $ac_row 2]
        set ac_ins [lindex $ac_row 4]
        set ac_got [ac_act $ac_nm]
        set ac_w [ac_verb $ac_got]
        if {[info exists ac_cnt($ac_w)]} { incr ac_cnt($ac_w) } else { set ac_cnt($ac_w) 1 }
        if {[lsearch -exact [pcall calc::fn_dead_routes] $ac_rt] >= 0} {
            set ac_want [list unavailable [pcall calc::fn_reason $ac_rt]]
        } elseif {$ac_rt eq {T}} {
            set ac_want {measure}
        } elseif {$ac_ins ne {}} {
            set ac_want [list insert $ac_ins]
        } else {
            set ac_want {inert}
        }
        if {$ac_got ne $ac_want} { lappend ac_bad $ac_nm=[ac_verb $ac_got] }
    }
    check "MT13 EVERY catalogue row reaches a LIVE arm, derived row by row from its own route and `insert` field against `calc::fn_dead_routes` and `calc::fn_reason` with no name written out here -- a row whose decision disagrees with its own table entry is reported BY NAME, and the sweep count rides along because a walk over an empty catalogue would be this same green" \
        [list $ac_bad [mt_atleast $ac_n 1]] {{} atleast1}
    check "MT13 ...and the four-way census of those decisions is the shape the catalogue really has: every row decides INSERT, MEASURE or UNAVAILABLE, ZERO rows decide `inert`, and ZERO decide nothing -- so `calc::inert`'s phase-5 promise is UNREACHABLE from a browser click today, which is a derived property of the live table and the reason the `inert` arm is a DEFENSIVE one" \
        [list $ac_cnt(insert) $ac_cnt(measure) $ac_cnt(unavailable) \
              $ac_cnt(inert) $ac_cnt(none) $ac_n] \
        {60 34 14 0 0 108}
    # the census above pins four numbers; this row is what keeps the FIRST of
    # them honest against the field it is supposed to be counting, since
    # `insert` is the only one of the six catalogue fields the decision reads.
    set ac_ins_n 0 ; set ac_t_n 0 ; set ac_dead_n 0
    foreach ac_row [pcall calc::catalogue] {
        set ac_rt [lindex $ac_row 2]
        if {[lsearch -exact [pcall calc::fn_dead_routes] $ac_rt] >= 0} { incr ac_dead_n ; continue }
        if {$ac_rt eq {T}} { incr ac_t_n ; continue }
        if {[lindex $ac_row 4] ne {}} { incr ac_ins_n }
    }
    check "MT13 ...and those three populations are re-derived straight off the table without calling the proc at all, so the census row above is a claim about AGREEMENT between two independent readings and not a number the proc under test got to choose" \
        [list $ac_ins_n $ac_t_n $ac_dead_n] \
        [list $ac_cnt(insert) $ac_cnt(measure) $ac_cnt(unavailable)]

    # --- the dispatcher is THIN: the decision may not leak back into it ------
    # ⚠ `mt_calc_names` DECOMMENTS FIRST, which matters here more than anywhere
    # else in this file: every claim below is about what `calc::fn_click` CALLS,
    # and this tree's block comments name `calc::fn_reason` and `calc::fn_row`
    # repeatedly in prose about exactly this split.
    set ac_click [pcall mt_calc_names fn_click]
    check "MT13 `calc::fn_click` CALLS `calc::fn_action` and no longer looks the decision up for itself: its decommented body names neither `calc::fn_row` nor `calc::fn_reason` nor `calc::catalogue`, so the branch that decides cannot drift back off the counted arm one call site at a time" \
        [list [sk_in $ac_click fn_action] [sk_in $ac_click fn_row] \
              [sk_in $ac_click fn_reason] [sk_in $ac_click catalogue] \
              [mt_atleast [llength $ac_click] 1]] \
        {has missing missing missing atleast1}
    check "MT13 ...and it still names all four acts' callees -- `calc::fn_insert` for R410's token, `calc::fn_measure` for R412's dialog, `calc::status` for R506's refusal sentence and `calc::inert` for the defensive arm the census above shows nothing reaches -- so a dispatcher that dropped an arm reddens here even though no catalogue row exercises the last of them" \
        [list [sk_in $ac_click fn_insert] [sk_in $ac_click fn_measure] \
              [sk_in $ac_click status] [sk_in $ac_click inert]] \
        {has has has has}
    check "MT13 NON-VACUITY for the instrument above: `mt_calc_names` really reads a body and really answers `missing` for something that is not in it, measured against `calc::fn_click` itself -- without this leg a lift that silently answered the empty list would make all four `missing` claims pass" \
        [list [sk_in $ac_click __no_such_callee__] \
              [sk_in [pcall mt_calc_names __no_such_proc__] anything]] \
        {missing missing}
    check "MT13 the ACT for routes P and C is its own proc, a sibling of `calc::fn_measure`: `calc::fn_insert` takes the name AND the token -- read off `info args` -- guards the window itself and reaches `calc::buf_insert_token`, which is the UNCHANGED primitive that already brackets its insert with `edit separator` on both sides for R421 and already supplies R410's space through `calc::token_sep`" \
        [list [pcall info args ::calc::fn_insert] \
              [sk_in [pcall mt_calc_names fn_insert] has_win] \
              [sk_in [pcall mt_calc_names fn_insert] buf_insert_token] \
              [sk_in [pcall mt_calc_names fn_insert] status] \
              [sk_in [pcall mt_calc_names fn_insert] fn_row] \
              [sk_in [pcall mt_calc_names fn_insert] fn_action]] \
        {{name tok} has has has missing missing}

    # --- EVERY `switch` ARM OF THE DISPATCHER, DRIVEN -----------------------
    # ⚠⚠ THIS IS THE ONLY CONFIRMATION THERE IS THAT NO COMMENT LANDED BETWEEN
    # TWO OF `calc::fn_click`'s PATTERNS.  Measured 2026-10-02 in
    # `calc::cross_msg`: a comment there leaves the braces balanced and
    # `info complete` answering 1 while Tcl raises *"extra switch pattern with no
    # body"* out of EVERY arm, and the trap is PARITY-DEPENDENT -- an even word
    # count is a silent no-op that detonates the moment one word is edited into
    # or out of it.  Nothing structural distinguishes it and a brace-balance scan
    # is blind to it.
    # ⚠ THE ARM SET IS DERIVED FROM THE PROC'S OWN BODY, never listed here: a
    # hand-kept list is the same defect one level up, and the sibling row this
    # one is modelled on was measured driving two thirds of its proc's arms
    # because the list had stopped growing with the code.
    # ⚠ `calc::fn_action` IS SHADOWED so each act can be forced, which is also
    # the only way to reach the `inert` arm at all -- the census above is the
    # row that says no catalogue entry does.  The slot is checked before the
    # rename and restored on every path.
    set ac_arms {}
    foreach ac_ln [split [pcall mt_decomment [pcall info body ::calc::fn_click]] "\n"] {
        if {[regexp {^[ \t]*([a-z][a-z0-9_]*)[ \t]+\{[ \t]*return} $ac_ln -> ac_k]} {
            lappend ac_arms $ac_k
        }
    }
    set ac_armbad {}
    if {[info commands ::calc::fn_action] eq {} || [info commands ::ac_keep_action] ne {}} {
        set ac_armbad SHADOWSLOTBUSY
    } else {
        rename ::calc::fn_action ::ac_keep_action
        foreach ac_k $ac_arms {
            proc ::calc::fn_action {name} [list return $ac_k]
            if {[catch {::calc::fn_click cross} ac_r]} { lappend ac_armbad "$ac_k:RAISED:$ac_r" }
        }
        catch {rename ::calc::fn_action {}}
        catch {rename ::ac_keep_action ::calc::fn_action}
    }
    check "MT13 EVERY arm of `calc::fn_click`'s switch is DRIVEN and none raises, with the arm set derived from the proc's own body and `calc::fn_action` shadowed to force each act in turn -- the only confirmation there is that no comment landed between two patterns, which balances the braces, satisfies `info complete` and reddens every arm at once on an odd word count while being a silent no-op on an even one" \
        $ac_armbad {}
    check "MT13 ...and that derivation is NOT VACUOUS, or the empty failure list above would be an empty arm set: it finds all four act words the decision can answer, it does NOT invent a fifth, and the shadow was taken and GIVEN BACK -- `calc::fn_action` answers for a real catalogue name again after the sweep" \
        [list [sk_in $ac_arms insert] [sk_in $ac_arms measure] \
              [sk_in $ac_arms unavailable] [sk_in $ac_arms inert] \
              [sk_in $ac_arms __ac_no_such_arm__] [mt_atleast [llength $ac_arms] 4] \
              [expr {[info commands ::ac_keep_action] eq {} ? 1 : 0}] \
              [ac_act average]] \
        [list has has has has missing atleast4 1 \
              [list insert [lindex [pcall calc::fn_row average] 4]]]

    # --- the pure half really is pure ---------------------------------------
    check "MT13 R402 this band mints nothing and reads no database -- it drives a pure decision over the catalogue, so no `__calc_tmp*` and no `__mt_*` may appear in the inventory because of it" \
        [list [leaked] [probeleft]] {{} {}}
    check "MT13 ...and the decision names no widget at all: its decommented body reaches `calc::fn_row` and `calc::fn_reason` and NOTHING that needs a window, which is what makes every row of this band readable on the arm with no X" \
        [list [sk_in [pcall mt_calc_names fn_action] fn_row] \
              [sk_in [pcall mt_calc_names fn_action] fn_reason] \
              [sk_in [pcall mt_calc_names fn_action] has_win] \
              [sk_in [pcall mt_calc_names fn_action] status] \
              [sk_in [pcall mt_calc_names fn_action] buf_insert_token]] \
        {has has missing missing missing}
}


# ---------------------------------------------------------------------------
# BAND MT14's DERIVATIONS AND INSTRUMENTS -- `slewRate`, the dV/dt of one
# transition.  Same discipline as MT9c's and for the same reasons: every one
# answers a WORD or a list this file re-derives, never a reproducible number,
# and every one is a PROC rather than an expression written at the row site,
# because a braced `expr` whose branch is a command substitution answering a
# sentinel raises *invalid bareword* and `group`'s catch turns that into an
# ABANDONED BAND rather than one failed row.
# ---------------------------------------------------------------------------

# `1 - x` element-wise, the Tcl counterpart of the engine's `1 <col> -`.
proc mt_complement {v} {
    if {[string match ERR:* $v]} { return $v }
    if {[catch {llength $v}]} { return "NOTALIST:{$v}" }
    set out {}
    foreach x $v {
        if {![mt_finite $x]} { return "NOTANUMBER:{$x}" }
        lappend out [expr {1.0 - double($x)}]
    }
    return $out
}
# `k + a*b` element-wise, the Tcl counterpart of the engine's `<a> <b> * <k> +`.
#
# ⚠⚠ THE OFFSET IS NOT DECORATION AND IT IS WHY THE FALLING KEYSTONE AND THE
# DATASET COLUMN BOTH CARRY ONE.  `near` compares RELATIVELY unless the expected
# value is bit-exactly zero, and a product column built from `v(sq)` passes
# through values that are nearly but not exactly zero -- `v(sq)`'s own plateau
# carries samples a hair away from its rails, so `1 v(sq) -` on the high plateau
# is a tiny NEGATIVE number rather than 0.  MEASURED on the committed fixture:
# `{1 v(sq) - v(ramp) *}` and this file's own Tcl product agree to an ABSOLUTE
# difference far below that column's own full scale, and DISAGREE by a large
# RELATIVE one at the single sample whose expected value IS that dust -- so an
# element-wise relative comparison reddens on correct code.  Lifting the whole
# column by a constant puts every element at the scale of the offset, where the
# relative comparison is the right instrument again, and it costs nothing because
# the thresholds are percentages of a SUPPLIED swing that lifts with it.  The
# agreement itself is a ROW leg (`mt_cmpword`), not a figure quoted here.
proc mt_offprod {a b k} {
    if {[string match ERR:* $a]} { return $a }
    if {[string match ERR:* $b]} { return $b }
    if {[catch {llength $a} na]} { return "NOTALIST:{$a}" }
    if {[catch {llength $b} nb]} { return "NOTALIST:{$b}" }
    if {$na != $nb} { return "LENMISMATCH:$na|$nb" }
    set out {}
    foreach x $a y $b {
        if {![mt_finite $x] || ![mt_finite $y]} { return "NOTANUMBER:{$x}|{$y}" }
        lappend out [expr {double($k) + double($x) * double($y)}]
    }
    return $out
}

# THE TWO THRESHOLDS A SLEW REQUEST NAMES, IN THE ORDER THE TRANSITION MEETS
# THEM: the low one first on a rising transition, the HIGH one first on a
# falling one.  `sq_thr` is R415's whole content and this is the direction read
# across it -- so a row can drive `calc::cross` at the level the verb will and
# compare the verb's X against `cross`'s own answer rather than against a second
# derivation of the same arithmetic.
proc mt_slew_levels {lo hi plo phi edge} {
    set llo [sq_thr $lo $hi $plo]
    set lhi [sq_thr $lo $hi $phi]
    if {$edge eq {falling}} { return [list $lhi $llo] }
    return [list $llo $lhi]
}
# ...and the NUMERATOR, which is the second threshold minus the first and
# therefore POSITIVE on a rising transition and NEGATIVE on a falling one.  The
# answer's sign is a free shape claim built out of exactly this.
proc mt_slew_dv {lo hi plo phi edge} {
    lassign [mt_slew_levels $lo $hi $plo $phi $edge] L1 L2
    if {![mt_finite $L1] || ![mt_finite $L2]} { return "NOTANUMBER:{$L1}|{$L2}" }
    return [expr {$L2 - $L1}]
}
# THE PER-TRANSITION SLEW SERIES, derived from two columns with no verb in it:
# one dV/dt per crossing of the FIRST threshold that HAS a crossing of the
# second after it, with X the first-threshold crossing -- the time the
# TRANSITION STARTED, which is R420's own default choice for `dutyCycle` read
# across to a transition and is what makes the rising series share its X axis
# with `riseTime`'s.
#
# Answers `{<X> <Y> <nstart> <nend>}`, and the two counts ride along so a row
# can assert that a point was DROPPED -- `nstart` greater than the series length
# -- rather than that the fixture only ever had that many transitions.  That is
# the difference between a fence and a fixture property.
proc mt_slew_derive {xs ys lo hi plo phi edge} {
    foreach side [list $ys $xs] {
        if {[regexp {^(ERR|NOTALIST|LENMISMATCH|NOTANUMBER):} $side]} {
            return [list $side $side $side $side]
        }
    }
    set dv [mt_slew_dv $lo $hi $plo $phi $edge]
    if {![mt_finite $dv] || $dv == 0.0} { return [list NODV NODV NODV NODV] }
    lassign [mt_slew_levels $lo $hi $plo $phi $edge] L1 L2
    set ss [mt_derive_x $xs $ys $L1 $edge]
    set es [mt_derive_x $xs $ys $L2 $edge]
    # ⚠ THE PAIRING IS `mt_pair_scan`'s, for the reason its header gives: this
    # proc used to walk the two lists with the SAME "first end after this start"
    # loop the product had, so it agreed with the product's pairing by
    # construction and could not see a stolen end crossing.  The two list lengths
    # still ride along as `nstart`/`nend` for the drop legs.
    set rx {} ; set ry {}
    foreach {a b} [mt_pair_scan $xs $ys $L1 $L2 $edge] {
        lappend rx $a
        lappend ry [expr {$dv / ($b - $a)}]
    }
    return [list $rx $ry [llength $ss] [llength $es]]
}
proc mt_sl_x  {d} { return [mt_rt_get $d 0] }
proc mt_sl_y  {d} { return [mt_rt_get $d 1] }
proc mt_sl_ns {d} { return [mt_rt_get $d 2] }
proc mt_sl_ne {d} { return [mt_rt_get $d 3] }

# `pos` / `neg` / `zero` / `notanumber`, `lsort -unique`d over a whole series,
# so a one-word answer is a claim about EVERY element.
#
# ⚠ THIS IS `mt_nonneg`'s COUNTERPART AND IT IS A STRONGER CLAIM, which is the
# whole of what a signed answer buys over a duration.  A rise time cannot be
# negative, so `mt_nonneg` is the most a series of them can say; a slew rate's
# sign carries the DIRECTION, so a rising answer must be strictly positive and a
# falling one strictly negative -- and the leg that asserts it catches an
# `abs()` or a flipped subtraction over the whole series at once, with no
# tolerance anywhere in it.
proc mt_signs {v} {
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n < 1} { return "tooshort:$n" }
    set out {}
    for {set i 0} {$i < $n} {incr i} {
        set e [mt_at $v $i]
        if {![mt_finite $e]} { lappend out notanumber ; continue }
        if {$e > 0} { lappend out pos ; continue }
        if {$e < 0} { lappend out neg ; continue }
        lappend out zero
    }
    return [lsort -unique $out]
}
# the magnitudes, so a row can ask whether two answers differ by more than their
# shared sign -- which is what tells an `abs()` from a correct answer on a
# column where the two directions have different slopes, and what the CONTROL
# leg shows a column where they do not.
proc mt_absmap {v} {
    set n [mt_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n < 1} { return "tooshort:$n" }
    set out {}
    for {set i 0} {$i < $n} {incr i} {
        set e [mt_at $v $i]
        if {![mt_finite $e]} { return "NOTANUMBER:{$e}" }
        lappend out [expr {abs($e)}]
    }
    return $out
}

# ⚠⚠ A COLUMN WHOSE ONLY SECOND-THRESHOLD CROSSING LIES BEFORE ITS ONLY
# FIRST-THRESHOLD CROSSING, WHICH IS THE ONE EMPTY SHAPE A GUARD ON THE INPUT
# LISTS CANNOT TELL FROM A WORKING ANSWER -- and no committed column has it.
# The two other empty shapes pin themselves with a crossing-list COUNT, one
# asserting the start list is empty and the other the end list, and those are
# precisely the two tests a defensive implementer writes if the emptiness is
# guarded on the INPUTS instead of on the OUTPUT series.  The complement is both
# lists NON-EMPTY and the series still empty.  `riseTime`'s own band reaches it
# with an INVERTED swing, `lo` above `hi` -- which this verb REFUSES before any
# accessor, so that request cannot serve here and a column has to be minted.
#
# The shape: start at a value BETWEEN the two thresholds, bump up over the high
# one, dip down under the low one, and settle back between them.  The high
# threshold is then crossed rising ONCE, early; the low threshold is crossed
# rising ONCE, later; and the later start has no end after it.  ⚠ ONE TABLE
# feeds both the engine's RPN and this file's Tcl column, so the two cannot
# drift, and the Tcl side takes `v(ramp)` ITSELF as its abscissa rather than
# scaling the sweep -- `mt_tri` is written against that column and the
# millisecond scaling is the deck's property, not this band's.
# ⚠⚠ THE ARM SET OF A `switch`, DERIVED FROM THE PROC'S OWN TRAILING ARGUMENT BY
# PARSING IT AS THE LIST TCL PARSES IT -- which is the only derivation that can
# see the parity trap, and the only one in this tree that can see HALF of it.
#
# `switch`'s trailing argument is ONE Tcl LIST, so every word of a comment placed
# between two patterns becomes an element of it.  An ODD word count shifts the
# pairing and Tcl raises out of EVERY arm; an EVEN count re-pairs the list so
# every real pattern keeps its real body and the comment is swallowed as one
# harmless pattern/body pair -- a COMPLETE NO-OP that can sit green for months and
# detonate the moment one word is edited into or out of it.  `info complete`
# answers 1 in both parities and a brace-balance scan is blind to both.
#
# ⚠ SO THE DERIVATION IS RUN TWICE, ON THE DECOMMENTED BODY AND ON THE RAW ONE,
# AND THE CLAIM IS THAT THE TWO AGREE.  The decommented parse says what the arm
# set WOULD be with no comment in the way; the raw parse says what TCL really
# sees.  Measured, both ways, on this stage's own `fn_argspec`: an ODD-word
# comment between two patterns gives `ODDPAIRING` from the raw parse and makes
# EVERY arm raise, and an EVEN-word one leaves every arm answering correctly while
# the raw parse reports EXTRA patterns made out of the comment's own words.
# Nothing else in this tree detects the second case at all.
#
# ⚠ A comment INSIDE an arm's body is safe and stays invisible here, which is
# right rather than a gap: the body is one braced element whatever it contains, so
# its word count cannot move the pairing.
proc mt_switch_arms {p {strip 1}} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    if {[catch {info body ::calc::$p} b]} { return "NOBODY:calc::$p" }
    if {$strip} { set b [mt_decomment $b] }
    if {![regexp -indices -line {^[ \t]*switch[ \t]} $b mtidx]} { return "NOSWITCH:$p" }
    set o [string first "\{" $b [lindex $mtidx 0]]
    if {$o < 0} { return "NOBRACE:$p" }
    set d 0 ; set n [string length $b] ; set j $o
    for {} {$j < $n} {incr j} {
        set c [string index $b $j]
        if {$c eq "\{"} { incr d ; continue }
        if {$c eq "\}"} { incr d -1 ; if {$d == 0} break }
    }
    if {$d != 0} { return "UNBALANCED:$p" }
    set body [string range $b [expr {$o + 1}] [expr {$j - 1}]]
    if {[catch {llength $body} L]} { return "NOTALIST:$p" }
    if {$L % 2} { return "ODDPAIRING:$p/$L" }
    set out {}
    foreach {mtpat mtbody} $body { lappend out $mtpat }
    return $out
}
# ⚠⚠ ...AND THE POPULATION THOSE TWO ARE APPLIED TO, DERIVED FROM THE
# NAMESPACE RATHER THAN NAMED.  `<tail>:<n>` for every `::calc::` proc whose
# DECOMMENTED body opens a `switch` in command position, with `n` the number of
# such openings -- so a verb that grows a `switch` enlists itself in the parity
# fence instead of waiting for someone to add it to a list.
#
# ⚠ `n` IS PART OF THE ANSWER BECAUSE `mt_switch_arms` SCANS THE FIRST SWITCH
# ONLY.  A proc with two of them would be half covered, silently, so the row
# asserts that every member has exactly one and a second one arrives as a red
# rather than as a blind spot.
#
# ⚠ COMMAND POSITION, not a bare word: the scan is line-anchored at
# `^[ \t]*switch[ \t]`, so the word `switch` inside a string or a comment is not
# a member -- the distinction row W20h of tests/headless/test_suite_watchdog_1403.tcl
# had to learn, where a bare-word scan enlisted a proc whose only `toplevel` was
# inside an English sentence.
proc mt_switch_procs {} {
    set out {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        if {[catch {info body $p} b]} continue
        set n [regexp -all -line {^[ \t]*switch[ \t]} [mt_decomment $b]]
        if {$n > 0} { lappend out "[namespace tail $p]:$n" }
    }
    return [lsort $out]
}
# one word per member of that population: `<tail>=<mt_switch_agree's answer>`.
proc mt_switch_parity {} {
    set out {}
    foreach e [mt_switch_procs] {
        set t [lindex [split $e :] 0]
        lappend out "$t=[mt_switch_agree $t]"
    }
    return $out
}
# the field at index `i` of every `<a><sep><b>` element, uniqued -- so one word is
# a claim about every member and a dissenter names itself.
proc mt_switch_words {l sep i} {
    set out {}
    foreach e $l { lappend out [lindex [split $e $sep] $i] }
    return [lsort -unique $out]
}
proc mt_switch_agree {p} {
    set a [mt_switch_arms $p 1]
    set b [mt_switch_arms $p 0]
    if {$a eq $b} { return agree }
    return "differ:{$a}|{$b}"
}
# ...and the BEHAVIOURAL half, which is the only confirmation there is: every
# derived arm is DRIVEN, with the arity read off `info args` so one instrument
# serves a one-argument proc and a three-argument one, and each must answer a
# NON-EMPTY result without raising.  The raise catches the odd parity; the
# non-empty answer catches a bogus pattern made out of a comment's words, which
# falls through to the empty string.
proc mt_switch_drive {p} {
    set arms [mt_switch_arms $p 1]
    if {[regexp {^(NOPROC|NOBODY|NOSWITCH|NOBRACE|UNBALANCED|NOTALIST|ODDPAIRING):} $arms]} {
        return $arms
    }
    if {[catch {info args ::calc::$p} na]} { return "NOARGS:$p" }
    set na [llength $na]
    set bad {}
    foreach a $arms {
        set call [list ::calc::$p $a]
        for {set k 1} {$k < $na} {incr k} { lappend call MTPARITY }
        if {[catch {uplevel #0 $call} r]} { lappend bad "$a:RAISED" ; continue }
        if {$r eq {}} { lappend bad "$a:EMPTY" }
    }
    return $bad
}
# `tmp` for a name the measurement's own `calc::tmpvec` minted and R402 has
# already deleted, the value itself otherwise -- the counterpart of
# `mt_destname`, and a GLOB rather than a literal because the prefix carries a
# namespace serial that advances with every temporary any band evaluated.
proc mt_tmpname {v} {
    if {[string match __calc_tmp* $v]} { return tmp }
    return $v
}
proc mt_sl_gaptab {} { return {0.5 2.0 1.0 0.6 6.0 1.0 0.6} }
proc mt_sl_gaprpn {} {
    lassign [mt_sl_gaptab] b cu wu hu cd wd hd
    return "$b [mt_tri $cu $wu $hu] + [mt_tri $cd $wd $hd] -"
}
proc mt_sl_gapcol {rs} {
    if {[string match ERR:* $rs]} { return $rs }
    lassign [mt_sl_gaptab] b cu wu hu cd wd hd
    set out {}
    foreach r $rs {
        if {![mt_finite $r]} { return "NOTANUMBER:{$r}" }
        set up [expr {double($hu)*(1.0 - abs(double($r)-$cu)/$wu)}]
        if {$up < 0.0} { set up 0.0 }
        set dn [expr {double($hd)*(1.0 - abs(double($r)-$cd)/$wd)}]
        if {$dn < 0.0} { set dn 0.0 }
        lappend out [expr {double($b) + $up - $dn}]
    }
    return $out
}


# =========================================================================
# MT14 -- `slewRate`, THE dV/dt OF ONE TRANSITION.  The fourth layered verb,
# and the VERB-AND-SURFACE half; it gates on the COUNTED arm.
#
# Spec     doc/claude/specs/calculator.md section 7.2 (the catalogue row) and
#          section 7.2ab/ac (R415, R419-R421), whose rulings this verb inherits
#          rather than re-opening.
# Fence    the DESTINATION's own bookkeeping is band WD9/WD13 of
#          tests/headless/test_calc_wave_dest.tcl; the dialog, the click, the
#          buffer and the status sentence are display-only and belong to band
#          S28 of tests/headless/test_calc_skeleton.tcl and band PL10 of
#          tests/headless/test_calc_plot.tcl, both `dcases` ALONE.
#
# ⚠⚠ WRITTEN RED-FIRST, BEFORE `calc::slewRate` EXISTED.  Every behavioural row
# below failed when it was written and each failure named
# `NOPROC:calc::slewRate` rather than raising; the transcript is in the stage
# receipt.
#
# ⚠⚠ `v(sq)` IS TOTALLY BLIND FOR THIS VERB AND IS NOT BLIND FOR `riseTime`,
# WHICH IS ISSUE 1643's TRAP ARRIVING AT A THIRD VERB AND ARRIVING WITH THE
# PAIRING REVERSED.  The square's edges are straight lines, so EVERY secant of
# an edge has the same slope: swept over seven different swings and threshold
# pairs, `slewRate` on `v(sq)` answers the same number every time to well inside
# this file's MTTOL -- which row MT14/F asserts in the run rather than this
# sentence quoting it -- while the same seven requests on `riseTime` DO
# discriminate.  So a `slewRate` row driven on `v(sq)` passes an implementation
# that ignores `pctlo`/`pcthi` entirely, uses the wrong swing, or derives the
# swing from the trace.  CLAUDE.md records `v(lp)`'s duty fractions
# discriminating where its rise times do not; here it is the reverse pairing,
# and the lesson is the one both instances teach -- a column discriminates for a
# VERB and not for a fixture.
#
# What this band drives instead, with the reason in each case:
#
#   * the RISING keystone is `{v(sq) v(ramp) *}`, whose three edges are scaled
#     by the ramp so against fixed absolute thresholds they have three different
#     slopes, every adjacent pair of them orders of magnitude OUTSIDE MTTOL --
#     which is row MT14/C's `distinct`, re-measured every run.  MT9c's own
#     keystone, for the same reason one verb up.
#   * the FALLING keystone is `{1 v(sq) - v(ramp) * 1 +}` at 10/80, and both of
#     those choices are measurements.  The inversion makes the column fall where
#     `v(sq)` rises; the OFFSET is `mt_offprod`'s banner; and at 10/90 the
#     column sits bit-exactly ON the high threshold at one sample, where CX14's
#     `y0 > L` strict asymmetry DROPS the first transition and the series is two
#     points instead of three.  10/80 registers all three.
#   * R415's supplied-swing row is driven on `v(lp)`, the ONE column where a
#     trace-derived swing answers a different number: `v(lp)` tops out SHORT of
#     the supplied 1, so substituting its own maximum moves the answer, while
#     `v(sq)` tops out at 1 to within floating-point dust and the same
#     substitution does not move it at all.  Both halves are legs of MT14/F,
#     which names `v(sq)` in its CONTROL so nobody moves the row there.
#   * the PAIRING DIRECTION needs a signal that RINGS at the top, `mt_ringrpn`'s
#     own banner one verb up, because on every committed column the two crossing
#     lists interleave strictly one for one and the two pairing directions are
#     provably the same list.
#
# ⚠ EVERY NUMBER THE DESIGN WAS BUILT ON IS FOR THE IMPLEMENTER'S CONFIDENCE AND
# NO ROW CARRIES ONE.  The comparands come from `mt_slew_derive` over the
# committed columns and from `sq_thr`, and the `distinct`/`same` legs answer
# WORDS that are re-measured every run.
#
# ⚠ EXACTLY ONE ROW HERE PASSES WITH NO FEATURE PRESENT, and it is named
# rather than left for a reader to work out: MT14/N, the R402 inventory, which is
# a claim about this band's own hygiene and not about the verb.  MEASURED on the
# red run -- every other row of this band failed, each naming
# `NOPROC:calc::slewRate` rather than raising.  Individual non-vacuity LEGS pass there too, because
# they measure the FIXTURE and not the verb (the crossing counts, the strictness,
# the engine-against-Tcl column agreements, and the two-versus-three-point
# controls in MT14/E), and two legs had to be ADDED after the red run because
# they passed over a sentinel: MT14/K's family claim recorded no family at all
# when every request answered `NOPROC`, and MT14/G's two `string equal` identities
# were satisfied by two readings answering the SAME sentinel.  Both now carry a
# leg that fails on the featureless tree.
#
# THE DIVERGENCES FROM `riseTime`, declared because each is a decision and not
# an inheritance:
#
#   * `edge` IS a member of the argument spec, because the shipped catalogue help
#     is *"Rate of change dV/dt of a transition"* and not "of a rising
#     transition".  `riseTime`'s NAME carries its direction; this one's does not.
#   * `either` is NOT a member, and that is a divergence from `cross` and
#     `delay` with a mechanical reason: those two locate ONE crossing, where
#     "either direction" is well defined, while a slew rate pairs TWO threshold
#     crossings -- under `either` the nth crossing of the first threshold can be
#     a falling one and "the first crossing of the second threshold after it" is
#     then the NEXT transition's, giving a confident number for a transition that
#     never happened.
#   * `pctlo >= pcthi` and `lo >= hi` are REFUSED through one guard over the
#     COMPUTED pair, where `riseTime` allows all four.  That is because the
#     wrong answers here are numbers a user would believe: measured on the
#     committed fixture, `pctlo == pcthi` answers EXACTLY ZERO at every point of
#     a live 5000 V/s edge, and `pctlo > pcthi` pairs ACROSS two transitions and
#     answers a confident -208.3.  `riseTime`'s own holes H2/H2b are the filed
#     open questions and this band does not answer them for `riseTime`; the
#     disagreement is ASSERTED rather than only stated, so a later ruling that
#     brings the two verbs into line reddens one named leg.
#   * `calc::riseTime` IS NOT REFACTORED, so the transition-pairing loop exists
#     in two bodies.  The protection is one leg and nothing else: on the rising
#     arm `slewRate` must equal `dv / riseTime` BIT-IDENTICALLY, `string equal`
#     with no tolerance, with `dv` built from `sq_thr` twice so the two sides are
#     bit-identical by construction.  Delete that leg and the duplication
#     becomes unfenced.
# =========================================================================
group MT14 {
    pcall mt_load tran
    set slT   [mt_col time 0]
    set slRA  [mt_col v(ramp) 0]
    set slSQ  [mt_col v(sq) 0]
    set slLP  [mt_col v(lp) 0]
    # the RISING keystone's column, both ways: the engine's and this file's.
    set slR   {v(sq) v(ramp) *}
    set slTCL [mt_prod $slSQ $slRA]
    set slENG [mt_addcol __mt_slprod $slR 0]
    set slD   [mt_slew_derive $slT $slTCL 0 1 10 90 rising]
    lassign [mt_slew_levels 0 1 10 90 rising] slL1 slL2
    # ...and the transition count read back off `calc::cross` itself, so no row
    # below writes down how many transitions this fixture has.
    set slSTART  [mt_call cross $slR $slL1 0 rising 0]
    set slNSTART [mt_len [mt_val $slSTART]]

    # --- A: the SURFACE is the wrapper, and both signatures are DERIVED -----
    # ⚠ `info args` AND NEVER A TEXT SCAN.  Five text-scanning legs on a sibling
    # signature pin were each defeated in turn -- a comment copy quoting the
    # signature, an unqualified callee, a backslash continuation -- while not one
    # `info args` leg was defeated by any of the 43 derived sabotages.
    check "MT14/A the click's SURFACE for slewRate is the wrapper, and the wrapper's formals are the verb's own DERIVED on both sides with `info args` rather than written down as a list here -- so a wrapper that dropped, renamed or gained a formal reddens here naming both lists.  The name carries no formal COUNT: that is a figure the derivation recomputes" \
        [list [mt_surface slewRate] \
              [mt_sameformals [mt_formals slewRate_scalar] [mt_formals slewRate]]] \
        {slewRate_scalar same}
    # ⚠⚠ THE SECOND VERB WHOSE DISPLAY ORDER AND FORMAL ORDER REALLY DIFFER, AND
    # THAT IS WHY `edge` SITS AFTER `nth` IN THE FORMALS AND BEFORE IT IN THE
    # SPEC.  Until this verb only `dutyCycle` could see a positional
    # composition, and hole SH2 of band MT11 records that a positional
    # implementation passed all three suites because `cross`'s two orders
    # coincide.  Here a zip onto `info args` hands the verb its EDGE where its
    # ordinal belongs and its ordinal where its edge belongs -- two wrong
    # arguments from one mistake, both of them refusable.
    check "MT14/A ...and the call is COMPOSED BY KEY: handed slewRate's answer in the dialog's DISPLAY order -- edge before the ordinal -- each formal of the surface proc is paired with ITS OWN key's value in FORMAL order, where the ordinal comes before the edge.  An implementation that zipped the answer onto `info args` would hand the verb `falling` as its ordinal and `2` as its edge.  The dialog's own ordinal surviving the walk rides along" \
        [list [mt_argvals slewRate $slR \
                   [list lo 0 hi 1 pctlo 10 pcthi 90 edge falling nth 2 dataset 0]] \
              [mt_argval_of slewRate $slR \
                   [list lo 0 hi 1 pctlo 10 pcthi 90 edge falling nth 0 dataset 0] nth]] \
        [list {rpn {v(sq) v(ramp) *} lo 0 hi 1 pctlo 10 pcthi 90 nth 2 edge falling dataset 0} 0]

    # --- B: the keystone rising series, against THREE derivations -----------
    check "MT14/B the transition count this band's rows are sized against is read back off calc::cross at the FIRST threshold a supplied swing names, with a literal 0, rather than written down -- and the fixture really has more than two rising transitions there, which is what makes the middle-element rows below possible at all" \
        [list [mt_disp $slSTART] [mt_atleast $slNSTART 3] \
              [mt_sized [llength [mt_sl_y $slD]] $slNSTART]] \
        {measured atleast3 sized}
    check "MT14/B slewRate with nth 0 MEASURES the per-transition series: one dV/dt per rising transition and a PARALLEL X of the same length, both sized against the start-crossing count calc::cross answers rather than against a number, the X being calc::cross's own start-crossing list element for element -- so a verb that answered the SECOND threshold's crossings, or the midpoints, reddens on the X leg naming every offending element.  Every point is strictly POSITIVE, which is free by construction and is the leg that catches an abs() or a flipped subtraction over the whole series at once" \
        [list [mt_disp [set sla [mt_call slewRate $slR 0 1 10 90 0 rising 0]]] \
              [mt_sized [mt_len [mt_val $sla]] $slNSTART] \
              [mt_sized [mt_len [mt_key $sla sweep]] $slNSTART] \
              [mt_listcmp [mt_key $sla sweep] [mt_val $slSTART]] \
              [mt_finite [mt_val $sla]] \
              [mt_signs [mt_val $sla]]] \
        {measured sized sized ok 0 pos}
    check "MT14/B ...and a derivation with no engine in it agrees: the element-wise product of the two committed columns computed in Tcl, crossed at the two supplied-swing thresholds by this file's own D3+D4 and divided by the threshold difference, gives the same Y and the same X -- with the engine's own product column asserted against the Tcl one in the run so the two derivations cannot silently become one, and both thresholds crossing STRICTLY BETWEEN samples at every transition so no snapping convention could have produced these numbers" \
        [list [mt_cmpword $slENG $slTCL] \
              [mt_islist [mt_call slewRate $slR 0 1 10 90 0 rising 0] [mt_sl_y $slD]] \
              [mt_listcmp [mt_key [mt_call slewRate $slR 0 1 10 90 0 rising 0] sweep] [mt_sl_x $slD]] \
              [mt_allstrict $slT $slTCL $slL1 rising] \
              [mt_allstrict $slT $slTCL $slL2 rising]] \
        {same ok ok strict strict}
    # ⚠⚠ THE ONE LEG THAT FENCES THE DUPLICATED PAIRING LOOP, AND IT HAS NO
    # TOLERANCE IN IT.  `calc::riseTime` is not refactored, so the loop that
    # anchors each end crossing to its own start crossing exists in two bodies.
    # On the rising arm the two verbs differ by exactly one thing -- the
    # numerator -- so `slewRate` must equal `dv / riseTime` to the last bit, and
    # `dv` is built here from `sq_thr` TWICE so that the two sides are
    # bit-identical by construction rather than to a tolerance.  If the two
    # bodies ever drift this is the row that names it.
    set slDV [mt_slew_dv 0 1 10 90 rising]
    check "MT14/B ...and BIT-IDENTICALLY equal to dv divided by riseTime's own per-edge series, compared with string equal and no tolerance at all -- which is the ONLY fence over the transition-pairing loop existing in two bodies, since calc::riseTime is deliberately not refactored.  The denominator cancels in that comparison and is fenced by the independent Tcl derivation above; what this leg pins exactly is the numerator and the pairing" \
        [list [string equal \
                   [mt_val [mt_call slewRate $slR 0 1 10 90 0 rising 0]] \
                   [mt_ratios $slDV [mt_val [mt_call riseTime $slR 0 1 10 90 0]]]] \
              [mt_atleast [mt_len [mt_val [mt_call riseTime $slR 0 1 10 90 0]]] 3]] \
        {1 atleast3}
    check "MT14/B ...and the series IS the scalar path, transition by transition: slewRate at nth 1, 2 ... up to the derived transition count each MEASURES one number, and those numbers are the nth-0 series element for element -- a derivation that runs entirely through the ordinal path, so it shares no code with the series arm and a series assembled in the wrong ORDER reddens here" \
        [list [lsort -unique [lmap sln [mt_seq 1 $slNSTART] \
                   {mt_disp [mt_call slewRate $slR 0 1 10 90 $sln rising 0]}]] \
              [mt_sized [llength [set slSC [lmap sln [mt_seq 1 $slNSTART] \
                   {mt_val [mt_call slewRate $slR 0 1 10 90 $sln rising 0]}]]] $slNSTART] \
              [mt_islist [mt_call slewRate $slR 0 1 10 90 0 rising 0] $slSC]] \
        {measured sized ok}

    # --- C: the series DISCRIMINATES, and the control names the blind ones ---
    check "MT14/C the series DISCRIMINATES, and the CONTROL drives the two columns this band refuses to drive BY NAME: every adjacent Y of the answer differs by more than MTTOL and so does every adjacent X, the X is strictly increasing over TWO comparisons rather than one -- and the SAME instrument over v(sq)'s own per-transition slew answers `same` while over v(lp)'s it answers one of each, the pair (1,2) there being inside MTTOL because the pole is in periodic steady state after the first edge.  So the `distinct` above is a measurement of this fixture and not a constant, and the ADJACENT PAIR is the statistic rather than the range: the RANGE over v(lp)'s series looks perfectly adequate while the instrument still answers `same` for one of its pairs, which is the half a max-minus-min check would have missed" \
        [list [mt_alldistinct [mt_val [set sla [mt_call slewRate $slR 0 1 10 90 0 rising 0]]]] \
              [mt_alldistinct [mt_key $sla sweep]] \
              [mt_increasing [mt_key $sla sweep]] \
              [mt_alldistinct [mt_sl_y [mt_slew_derive $slT $slSQ 0 1 10 90 rising]]] \
              [mt_alldistinct [mt_sl_y [mt_slew_derive $slT $slLP 0 1 10 90 rising]]]] \
        [list distinct distinct increasing same {distinct same}]

    # --- D: the DIRECTION is honoured and the SIGN carries it ---------------
    check "MT14/D the direction is honoured and the SIGN carries it with no tolerance at all: one column and one swing, the rising answer strictly POSITIVE over its whole series and the falling answer strictly NEGATIVE over its whole series, with the two MAGNITUDES distinct on this column -- and the CONTROL is v(sq), where the two magnitudes answer `same`, which is why the magnitude leg is on the product column and why only the SIGN catches an abs() on the square" \
        [list [mt_signs [mt_val [mt_call slewRate $slR 0 1 10 90 0 rising 0]]] \
              [mt_signs [mt_val [mt_call slewRate $slR 0 1 10 90 0 falling 0]]] \
              [mt_distinct [mt_at [mt_absmap [mt_val [mt_call slewRate $slR 0 1 10 90 1 rising 0]]] 0] \
                           [mt_at [mt_absmap [mt_val [mt_call slewRate $slR 0 1 10 90 1 falling 0]]] 0]] \
              [mt_distinct [mt_at [mt_absmap [mt_val [mt_call slewRate {v(sq)} 0 1 10 90 1 rising 0]]] 0] \
                           [mt_at [mt_absmap [mt_val [mt_call slewRate {v(sq)} 0 1 10 90 1 falling 0]]] 0]]] \
        {pos neg distinct same}
    check "MT14/D ...and `either` is REFUSED by slewRate's OWN membership test and not by cross's, because a slew rate pairs TWO threshold crossings and under `either` the first threshold's nth crossing can be a falling one whose `next crossing of the second threshold` belongs to the following transition -- a confident number for a transition that never happened.  The refusal is in the house shape, in a family calc::cross_msg really builds, and is NOT cross's own badedge sentence by identity, so a verb that passed `edge` straight through to cross reddens on the identity leg instead of measuring across two transitions" \
        [list [mt_disp [set sle [mt_call slewRate $slR 0 1 10 90 1 either 0]]] \
              [mt_shape [mt_msg $sle]] \
              [mt_infamily [mt_msg $sle] [mt_crossmsg_families]] \
              [string equal [mt_msg $sle] [pcall calc::cross_msg badedge either]] \
              [mt_notfamily [mt_msg $sle] [pcall calc::cross_msg badedge either]]] \
        {refused ok known 0 elsewhere}

    # --- E: the falling arm's three-point series and its middle element -----
    set slFR  {1 v(sq) - v(ramp) * 1 +}
    set slFTCL [mt_offprod [mt_complement $slSQ] $slRA 1]
    set slFENG [mt_addcol __mt_slinv $slFR 0]
    set slFD  [mt_slew_derive $slT $slFTCL 1 2 10 80 falling]
    lassign [mt_slew_levels 1 2 10 80 falling] slFL1 slFL2
    set slFSTART [mt_call cross $slFR $slFL1 0 falling 0]
    check "MT14/E the FALLING arm, element for element against the Tcl derivation and with its X taken from the HIGH threshold -- the time the transition STARTED, which on a falling transition is the high crossing and not the low one, so a falling series assembled from the LOW list has an X that is the transition's END and reddens here.  Every point strictly NEGATIVE, both thresholds strict at every transition, the engine's own inverted column asserted against the Tcl one, and the series sized against the start count calc::cross answers with more than two members so the middle-element rows below are reachable" \
        [list [mt_cmpword $slFENG $slFTCL] \
              [mt_disp [set slf [mt_call slewRate $slFR 1 2 10 80 0 falling 0]]] \
              [mt_atleast [mt_len [mt_val $slFSTART]] 3] \
              [mt_sized [mt_len [mt_val $slf]] [mt_len [mt_val $slFSTART]]] \
              [mt_islist $slf [mt_sl_y $slFD]] \
              [mt_listcmp [mt_key $slf sweep] [mt_val $slFSTART]] \
              [mt_listcmp [mt_key $slf sweep] [mt_sl_x $slFD]] \
              [mt_signs [mt_val $slf]] \
              [mt_allstrict $slT $slFTCL $slFL1 falling] \
              [mt_allstrict $slT $slFTCL $slFL2 falling]] \
        {same measured atleast3 sized ok ok ok neg strict strict}
    check "MT14/E THE THIRD POINT, measured rather than argued: against the very same element-wise comparison the row above leans on, the falling series REVERSED, ROTATED BY ONE, with its MIDDLE replaced by the mean of the endpoints, and with its middle replaced by its left neighbour are each distinct from the answer while the unaltered derivation is the same -- and the last two legs show WHY two points could not have said it, because at two points a reversal and a rotation are the identical list and at three they are not" \
        [list [mt_cmpword [mt_val [set slf [mt_call slewRate $slFR 1 2 10 80 0 falling 0]]] [lreverse [mt_sl_y $slFD]]] \
              [mt_cmpword [mt_val $slf] [mt_rot1 [mt_sl_y $slFD]]] \
              [mt_cmpword [mt_val $slf] [mt_midmean [mt_sl_y $slFD]]] \
              [mt_cmpword [mt_val $slf] [mt_midleft [mt_sl_y $slFD]]] \
              [mt_cmpword [mt_val $slf] [mt_sl_y $slFD]] \
              [string equal [lreverse [lrange [mt_sl_y $slFD] 0 1]] [mt_rot1 [lrange [mt_sl_y $slFD] 0 1]]] \
              [string equal [lreverse [mt_sl_y $slFD]] [mt_rot1 [mt_sl_y $slFD]]]] \
        {distinct distinct distinct distinct same 1 0}

    # --- F: R415, the swing is SUPPLIED and never derived -------------------
    # ⚠ DRIVEN ON `v(lp)` AND THE CONTROL LEG IS WHY.  R415 came from the user
    # -- *"Cadence makes you supply them"* -- so there is no min/max search, no
    # settled-value estimator and no first/last-sample rule anywhere in the verb.
    # The only way to SEE that is a column whose own maximum differs from the
    # supplied `hi` by enough to move the answer, and on `v(sq)` it does not.
    set slLPMAX 0
    foreach slv $slLP { if {[mt_finite $slv] && $slv > $slLPMAX} { set slLPMAX $slv } }
    set slSQMAX 0
    foreach slv $slSQ { if {[mt_finite $slv] && $slv > $slSQMAX} { set slSQMAX $slv } }
    check "MT14/F R415 the swing is SUPPLIED and is never derived from the trace: on v(lp), whose own maximum is short of the supplied 1, the request 0..1 and the request 0..max answer DISTINCT numbers -- and the CONTROL is the same substitution on v(sq), whose maximum is 1 to within floating-point dust, where the two answers are the SAME.  So a min/max search, a settled-value estimator or a first/last-sample rule is caught on the one column that can see it, and the row names the one that cannot so nobody moves it" \
        [list [mt_distinct [mt_at [mt_val [mt_call slewRate {v(lp)} 0 1 10 90 1 rising 0]] 0] \
                           [mt_at [mt_val [mt_call slewRate {v(lp)} 0 $slLPMAX 10 90 1 rising 0]] 0]] \
              [mt_distinct [mt_at [mt_val [mt_call slewRate {v(sq)} 0 1 10 90 1 rising 0]] 0] \
                           [mt_at [mt_val [mt_call slewRate {v(sq)} 0 $slSQMAX 10 90 1 rising 0]] 0]]] \
        {distinct same}
    set slLPSET {} ; set slSQSET {}
    foreach {sllo slhi slpl slph} {0 1 10 90  0 1 20 80  0 1 30 70  0 1 40 60
                                   0 1 5 95   0 0.5 10 90  0.2 0.8 10 90} {
        lappend slLPSET [mt_at [mt_val [mt_call slewRate {v(lp)} $sllo $slhi $slpl $slph 1 rising 0]] 0]
        lappend slSQSET [mt_at [mt_val [mt_call slewRate {v(sq)} $sllo $slhi $slpl $slph 1 rising 0]] 0]
    }
    check "MT14/F ...and the threshold PERCENTAGES really reach the arithmetic: swept over seven different swing-and-threshold requests, every adjacent pair of v(lp)'s answers differs by more than MTTOL, while the SAME sweep on v(sq) answers `same` throughout because a straight edge has one slope at every secant.  That is the measurement behind this band's choice of column, asserted in the run, and it is what catches a verb that ignores pctlo/pcthi or uses the swing where the threshold difference belongs" \
        [list [mt_sized [llength $slLPSET] 7] [mt_alldistinct $slLPSET] \
              [mt_sized [llength $slSQSET] 7] [mt_alldistinct $slSQSET]] \
        [list sized distinct sized same]

    # --- G: the ordinal path reads from BOTH ENDS ---------------------------
    check "MT14/G the ordinal reads from BOTH ENDS and the two readings are the same number to the last bit: on a column with exactly two falling transitions, nth 1 equals nth -2 and nth 2 equals nth -1 by string equal, the two numbers are DISTINCT so neither identity is satisfied by one value appearing twice, and an ordinal past the transitions that exist is an ABSENCE carrying calc::cross's OWN family rather than a slewRate sentence -- because that absence is cross's to report and is reached before any pairing happens.  An abs(nth) implementation answers nth 1's number for -1 and reddens on the first identity.  ⚠ ALL FOUR DISPOSITIONS RIDE ALONG AND THEY ARE THE NON-VACUITY LEG: `string equal` is satisfied by two readings that answer the SAME SENTINEL, which is exactly what both identities did on the tree with no verb in it" \
        [list [lsort -unique [lmap sln {1 -2 2 -1} \
                   {mt_disp [mt_call slewRate $slR 0 1 10 90 $sln falling 0]}]] \
              [string equal [mt_val [mt_call slewRate $slR 0 1 10 90 1 falling 0]] \
                            [mt_val [mt_call slewRate $slR 0 1 10 90 -2 falling 0]]] \
              [string equal [mt_val [mt_call slewRate $slR 0 1 10 90 2 falling 0]] \
                            [mt_val [mt_call slewRate $slR 0 1 10 90 -1 falling 0]]] \
              [mt_distinct [mt_val [mt_call slewRate $slR 0 1 10 90 1 falling 0]] \
                           [mt_val [mt_call slewRate $slR 0 1 10 90 2 falling 0]]] \
              [mt_disp [set slg [mt_call slewRate $slR 0 1 10 90 3 falling 0]]] \
              [mt_samefamily [mt_msg $slg] [pcall calc::cross_msg absent 3rd falling]] \
              [mt_shape [mt_msg $slg]]] \
        {measured 1 1 distinct absent samefamily ok}

    # --- H: the PAIRING DIRECTION, on the one shape that can see it ---------
    # ⚠⚠ EVERY OTHER ROW IN THIS BAND IS BLIND TO WHICH WAY THE TWO CROSSING
    # LISTS WERE PAIRED, and that was measured one verb up rather than feared: a
    # producer driving the SECOND threshold's list and pairing each of its
    # crossings with the last first-threshold crossing before it keeps X a
    # start crossing, keeps Y a difference over the same denominator, drops the
    # same points and reaches the same absence.  On every committed column the
    # two lists interleave strictly one for one, and under strict 1:1
    # interleaving the two directions are provably THE SAME LIST.
    set slRGN 3
    set slRGLO [mt_ringfloor]
    set slRGR [mt_ringrpn $slT $slRGN]
    set slRGTCL [mt_ringcol $slT $slRGN]
    set slRGENG [mt_addcol __mt_slring $slRGR 0]
    set slRGD [mt_slew_derive $slT $slRGTCL $slRGLO 1 10 90 rising]
    check "MT14/H THE PAIRING DIRECTION, on the one shape that can see it: a signal that RINGS at the top crosses its SECOND threshold more often than its first, and a slew rate is one measurement per TRANSITION -- so the series is sized against the FIRST threshold's crossing count, its X is that list element for element, no two of its points share an X, and the X is strictly increasing.  Three non-vacuity legs say the shape really is the discriminating one: more than one transition, the second level crossed strictly more often than the first, and not one point dropped -- so a producer that drove the second list, pairing each of its crossings with the last start before it, reddens on the count AND on the duplicated X instead of passing as it does on every other request in this band" \
        [list [mt_cmpword $slRGENG $slRGTCL] \
              [mt_disp [set slrg [mt_call slewRate $slRGR $slRGLO 1 10 90 0 rising 0]]] \
              [mt_atleast [mt_sl_ns $slRGD] 2] \
              [mt_excess [mt_sl_ne $slRGD] [mt_sl_ns $slRGD] 1] \
              [mt_sized [mt_len [mt_sl_y $slRGD]] [mt_sl_ns $slRGD]] \
              [mt_sized [mt_len [mt_val $slrg]] [mt_sl_ns $slRGD]] \
              [mt_islist $slrg [mt_sl_y $slRGD]] \
              [mt_listcmp [mt_key $slrg sweep] [mt_sl_x $slRGD]] \
              [mt_nodup [mt_key $slrg sweep]] \
              [mt_increasing [mt_key $slrg sweep]] \
              [mt_signs [mt_val $slrg]]] \
        {same measured atleast2 atleast1 sized sized ok ok nodup increasing pos}

    # --- I: a transition that never completes DROPS THAT POINT --------------
    # ⚠ THE PER-POINT HOLE, which is `riseTime`'s own disposition read across:
    # the series is one dV/dt per start crossing THAT HAS an end crossing after
    # it, and when every point drops the whole answer becomes an absence.  One
    # rule, two outcomes.  Refusing the series instead would refuse every
    # transient that ends part way up its last edge, which is the common case.
    # ⚠ PADDING a dropped point with its predecessor keeps the LENGTH, so no
    # count leg can see it; and HOISTING the inner `set x1 {}` out of the loop
    # makes a dropped transition INHERIT the previous one's end crossing, which
    # emits a point of the WRONG SIGN -- so the sign leg is on this row as well
    # as on the keystone, because neither placement subsumes the other.
    set slPD [mt_slew_derive $slT $slLP 0 1 10 99.9 rising]
    check "MT14/I a transition that never reaches the second threshold DROPS THAT POINT rather than refusing the series or padding it: the rising answer is shorter than the start-crossing list, equals the Tcl derivation element for element with its X too, is sign-correct, and the occurrence that does NOT complete is still an ABSENCE -- with the non-vacuity leg asserting that a point really was dropped, so the row cannot be satisfied by a fixture that simply had fewer transitions" \
        [list [mt_disp [set slp [mt_call slewRate {v(lp)} 0 1 10 99.9 0 rising 0]]] \
              [mt_sized [mt_len [mt_val $slp]] [llength [mt_sl_y $slPD]]] \
              [mt_atleast [expr {[mt_sl_ns $slPD] - [llength [mt_sl_y $slPD]]}] 1] \
              [mt_islist $slp [mt_sl_y $slPD]] \
              [mt_listcmp [mt_key $slp sweep] [mt_sl_x $slPD]] \
              [mt_signs [mt_val $slp]] \
              [mt_disp [mt_call slewRate {v(lp)} 0 1 10 99.9 [mt_sl_ns $slPD] rising 0]]] \
        {measured sized atleast1 ok ok pos absent}
    set slIR {1 v(lp) -}
    set slITCL [mt_complement $slLP]
    set slIENG [mt_addcol __mt_slilp $slIR 0]
    set slID [mt_slew_derive $slT $slITCL 0 1 0.1 90 falling]
    check "MT14/I ...and on the FALLING arm too, which is a second row and not the same one wearing different arguments: the inverted low-pass drops exactly one of its falling transitions, the series is shorter than the start list, element-wise equal to the derivation, strictly NEGATIVE, and the dropped occurrence is still an absence -- with the engine's own inverted column asserted against the Tcl one so the comparand is not the engine compared with itself" \
        [list [mt_cmpword $slIENG $slITCL] \
              [mt_disp [set sli [mt_call slewRate $slIR 0 1 0.1 90 0 falling 0]]] \
              [mt_sized [mt_len [mt_val $sli]] [llength [mt_sl_y $slID]]] \
              [mt_atleast [expr {[mt_sl_ns $slID] - [llength [mt_sl_y $slID]]}] 1] \
              [mt_islist $sli [mt_sl_y $slID]] \
              [mt_listcmp [mt_key $sli sweep] [mt_sl_x $slID]] \
              [mt_signs [mt_val $sli]] \
              [mt_disp [mt_call slewRate $slIR 0 1 0.1 90 [mt_sl_ns $slID] falling 0]]] \
        {same measured sized atleast1 ok ok neg absent}

    # --- J: the DEGENERATE THRESHOLD PAIR, refused through ONE guard --------
    # ⚠⚠ WHAT THE UNGUARDED VERB ANSWERS, MEASURED, because that is the test a
    # guard is chosen by -- can the wrong answer pass for a right one.  On the
    # committed fixture `pctlo == pcthi` answers EXACTLY `{0 0}` on a live
    # 5000 V/s edge and `pctlo > pcthi` pairs ACROSS two transitions and answers
    # a confident -208.3.  Both are numbers a user would believe.  For
    # `riseTime` the same four requests give a period or an absence -- odd, but
    # not a confident falsehood -- which is why its holes H2/H2b stay open and
    # this guard is a DECLARED DIVERGENCE rather than a quiet copy.
    set slJBAD {} ; set slJDISP {} ; set slJAGREE {}
    foreach {sllo slhi slpl slph} {0 1 50 50   0 1 90 10   1 0 10 90   1 1 10 90} {
        set slj [mt_call slewRate {v(sq)} $sllo $slhi $slpl $slph 0 rising 0]
        if {[mt_disp $slj] ne {refused}} { lappend slJBAD "$sllo/$slhi/$slpl/$slph=[mt_disp $slj]" }
        if {[mt_shape [mt_msg $slj]] ne {ok}} { lappend slJBAD "$sllo/$slhi/$slpl/$slph=shape" }
        if {[mt_infamily [mt_msg $slj] [mt_crossmsg_families]] ne {known}} {
            lappend slJBAD "$sllo/$slhi/$slpl/$slph=family"
        }
        if {[mt_notfamily [mt_msg $slj] [pcall calc::cross_msg noswing {} {}]] ne {elsewhere}} {
            lappend slJBAD "$sllo/$slhi/$slpl/$slph=risetimefamily"
        }
        lappend slJDISP [mt_disp [mt_call riseTime {v(sq)} $sllo $slhi $slpl $slph 0]]
        lappend slJAGREE [expr {[mt_disp [mt_call riseTime {v(sq)} $sllo $slhi $slpl $slph 0]]
                                eq [mt_disp $slj] ? {agree} : {differ}}]
    }
    check "MT14/J all four degenerate threshold requests are REFUSED through ONE guard over the computed pair -- equal percentages, inverted percentages, an inverted swing and a zero swing -- each in the house shape, each in a family calc::cross_msg really builds, and none of them in riseTime's family: the equal-percentage request would otherwise answer EXACTLY ZERO on a live edge and the inverted one a confident number measured ACROSS two transitions, which are the plausible wrong answers the guard is chosen by" \
        $slJBAD {}
    # ⚠⚠ THE FIRST OF THE FOUR DISPOSITIONS MOVED WHEN T2's BOUND LANDED, AND THE
    # MOVE IS AN IMPROVEMENT STATED RATHER THAN ABSORBED.  Equal percentages put
    # both of `riseTime`'s thresholds on ONE level, so every start crossing's own
    # "end" crossing IS the next start crossing -- which `calc::transition_end`'s
    # bound excludes -- and the verb now answers an ABSENCE where it used to answer
    # the PERIOD.  That is not holes H2/H2b, which are about the inverted pair and
    # the inverted swing and are still unruled: those two still answer a confident
    # cross-transition number here, because an inverted pair's end level is crossed
    # on the NEXT edge BEFORE that edge's own start level and so is inside the
    # bound.  So this leg now reads `absent measured measured refused`, and the
    # disagreement with `slewRate` is unchanged at three of four.
    check "MT14/J ...and the DECLARED DIVERGENCE from riseTime is ASSERTED rather than only stated: at the same four requests the two verbs DISAGREE on three of them and AGREE only on the zero swing, with riseTime's own dispositions riding along so the disagreement names what it is -- holes H2 and H2b filed and unruled, where riseTime answers a confident cross-transition number for the two inverted requests slewRate refuses, while equal percentages reach an ABSENCE through T2's bound.  A later ruling that brings the two verbs into line reddens exactly this leg instead of being met as a puzzle.  On the one request both refuse, slewRate does not reuse riseTime's own zeroswing sentence, which the two identity legs say" \
        [list $slJAGREE $slJDISP \
              [string equal [mt_msg [mt_call slewRate {v(sq)} 1 1 10 90 0 rising 0]] \
                            [pcall calc::cross_msg zeroswing 1]] \
              [mt_notfamily [mt_msg [mt_call slewRate {v(sq)} 1 1 10 90 0 rising 0]] \
                            [pcall calc::cross_msg zeroswing 1]]] \
        [list {differ differ differ agree} {absent measured measured refused} 0 elsewhere]

    # --- K: every refusal is in the house shape and in ITS OWN family -------
    # ⚠ THE WORDS ARE NEVER ASSERTED.  They are unratified user-visible wording
    # and the `rule` debt filed against `calc::eval_msg`'s sentences is extended
    # to cover them; the family -- the word before the first colon -- is the only
    # part a row may lean on.  A family of its own is not decoration: reusing
    # `riseTime`'s arms would print *"Rise time: both reference levels must be
    # supplied..."* at a user who clicked slewRate, which is shipped prose made
    # false and the failure this batch has repeated most.
    set slKREQ [list [list {v(sq)} {} {} 10 90 1 rising 0] \
                     [list {v(sq)} nan 1 10 90 1 rising 0] \
                     [list {v(sq)} 0 nan 10 90 1 rising 0] \
                     [list {v(sq)} 0 1 nan 90 1 rising 0] \
                     [list {v(sq)} 0 1 10 nan 1 rising 0] \
                     [list {v(sq)} 0 1 10 90 1 sideways 0] \
                     [list {v(sq)} 0 1 50 50 1 rising 0]]
    set slKBAD {} ; set slKN 0 ; set slKFIRST {}
    foreach slreq $slKREQ {
        set slk [mt_call slewRate {*}$slreq]
        incr slKN
        if {[mt_disp $slk] ne {refused}} { lappend slKBAD "$slreq=[mt_disp $slk]" ; continue }
        if {[mt_shape [mt_msg $slk]] ne {ok}} { lappend slKBAD "$slreq=shape" }
        if {[mt_infamily [mt_msg $slk] [mt_crossmsg_families]] ne {known}} {
            lappend slKBAD "$slreq=unknownfamily"
        }
        if {$slKFIRST eq {}} { set slKFIRST [mt_msg $slk] ; continue }
        if {[mt_samefamily [mt_msg $slk] $slKFIRST] ne {samefamily}} {
            lappend slKBAD "$slreq=[mt_samefamily [mt_msg $slk] $slKFIRST]"
        }
    }
    check "MT14/K every request-level refusal this verb can reach is in the house shape, in a family calc::cross_msg really builds, and in ONE family shared by all of them -- derived over a table of requests with the family compared pairwise rather than spelled, and the request count riding along so an empty population cannot pass.  The WORDS are unratified and no leg asserts one" \
        [list [mt_atleast $slKN 7] $slKBAD] {atleast7 {}}
    check "MT14/K ...and that family is NOT riseTime's and NOT cross's, which is the whole point of minting six arms rather than reusing four: a reused arm would print `Rise time:` at a user who clicked slewRate.  Asserted as four negative identities against the sentences the cheap implementation would have borrowed, plus the derived family set gaining a member -- so a future verb that reuses an arm reddens here.  ⚠ THE NON-VACUITY LEG COMES FIRST AND IT IS NOT DECORATION: on a tree with no verb at all every request answers a sentinel, nothing is ever recorded as the family under test, and three `elsewhere` answers about an EMPTY string would read exactly like a passing row -- measured, because the first revision of this row did pass that way" \
        [list [mt_shape $slKFIRST] \
              [mt_notfamily $slKFIRST [pcall calc::cross_msg noswing {} {}]] \
              [mt_notfamily $slKFIRST [pcall calc::cross_msg badref nan]] \
              [mt_notfamily $slKFIRST [pcall calc::cross_msg badedge sideways]] \
              [mt_notfamily $slKFIRST [pcall calc::cross_msg destempty]] \
              [mt_atleast [llength [mt_crossmsg_families]] 4] \
              [mt_atleast [llength [mt_crossmsg_arms]] 30]] \
        {ok elsewhere elsewhere elsewhere elsewhere atleast4 atleast30}

    # --- L: the SURFACE routes nth 0 to a destination and nth 1 to the buffer
    # ⚠⚠ THE DESTINATION IS READ BACK HERE AND NOT ONLY ROUTED, BECAUSE
    # `calc::wave_dest {xs} {ys}` TAKES X FIRST AND SWAPPING THE TWO IS SILENT ON
    # A SAME-LENGTH PAIR.  Band WD13 of tests/headless/test_calc_wave_dest.tcl
    # reads the two columns back for `riseTime_scalar`, and there is no such row
    # for this caller -- so without these legs a wrapper handing
    # `calc::wave_dest` its Y list as the X axis still answers `destination` and
    # every other leg in this band passes.  Measured as a sabotage, not argued.
    #
    # ⚠⚠ THE KEY SET BELOW IS ASSERTED **EXACTLY**, WHICH MAKES ANY WIDENING A
    # SEQUENCING OBLIGATION AND NOT A FREE EDIT.  That is the right shape -- an
    # exact set is what catches a wiring that puts a live value in a retired key
    # -- but it means a new key and the row that expects it MUST LAND IN ONE
    # COMMIT: a producer ahead of the row reddens a gate for a key the row does
    # not expect, and a row ahead of the producer reddens one for a key nothing
    # sets.  Said here so the next person meets it as a stated obligation rather
    # than as a gate red they clear by weakening the row.  The same set is
    # asserted exactly in band MT15/Q of this file and in two bands of
    # tests/headless/test_calc_wave_dest.tcl, so a widening is a FOUR-SITE edit.
    set sliv [mt_arginvoke slewRate $slR \
                  [list lo 0 hi 1 pctlo 10 pcthi 90 edge rising nth 0 dataset 0]]
    set slDBX {} ; set slDBY {} ; set slDBN {}
    if {[pcall xschem raw switch [mt_key $sliv db] table] eq {1}} {
        set slDBN [pcall xschem raw points 0]
        set slDBX [mt_col [mt_key $sliv xname] 0]
        set slDBY [mt_col [mt_key $sliv yname] 0]
    }
    pcall xschem raw switch $::fixture tran
    check "MT14/L R404/R421 the SURFACE routes the two shapes apart AND puts the series the right way round: the composed call at nth 0 answers a DESTINATION and the same call at nth 1 answers the BUFFER, read off calc::fn_sink which is a pure proc with no Tk in it -- so the routing DECISION gates on the counted arm even though the ACT, the buffer really being left alone and the sentence really reaching the status line, is display-only and is declared.  Then BOTH columns are read back out of the registered database and compared element-wise against the Tcl derivation, because calc::wave_dest takes X FIRST and swapping the two is SILENT on a same-length pair: the X is the transition-start list and the Y the slew rates, the point count is the derived series length, the two column names differ, and the user's own slot is current again afterwards.  ⚠ THE KEY SET IS ASSERTED EXACTLY and `dest` must still hold the RETIRED __calc_tmp the measurement evaluated into -- a name R402 has already deleted -- while `db` holds the LIVE __calc_dest, because band MT9b reads `dest` BY NAME to tell a deferral from an absence and a wiring that put the live destination there would make one key mean two things depending on the verb.  Measured as a sabotage: without those two legs that wiring passes every other row in this band and the whole sibling suite.  The destination this row built is dropped by this row" \
        [list [mt_sink $sliv] \
              [mt_sink [mt_arginvoke slewRate $slR \
                   [list lo 0 hi 1 pctlo 10 pcthi 90 edge rising nth 1 dataset 0]]] \
              [mt_destname [mt_key $sliv db]] \
              [expr {[mt_key $sliv xname] ne [mt_key $sliv yname] ? {twonames} : {ONENAME}}] \
              [mt_sized $slDBN [llength [mt_sl_y $slD]]] \
              [mt_listcmp $slDBX [mt_sl_x $slD]] \
              [mt_listcmp $slDBY [mt_sl_y $slD]] \
              [mt_signs $slDBY] \
              [mt_key $sliv shape] \
              [mt_keys $sliv] \
              [mt_tmpname [mt_key $sliv dest]] \
              [leaked]] \
        [list destination buffer named twonames sized ok ok pos wave \
              {absent dataset db dest msg n ok shape sweep type value xname yname} \
              tmp {}]
    pcall calc::wave_dest_drop $sliv
    # ⚠⚠ THE EMPTY SERIES IS AN ABSENCE AND NEVER A DESTINATION PROBLEM, which
    # is the one user-visible disposition this verb decides for itself.
    # `calc::wave_dest` refuses an empty list with `destempty` -- *"an empty
    # result has nothing to put in a destination, so none was built"* -- a
    # sentence that is right about the mechanism and WRONG about what happened:
    # the signal never completed a transition.  So the verb answers the absence
    # itself and the surface never reaches the destination builder at all.  THREE
    # shapes, each with a different cause, and the first two exclude the third by
    # their own non-vacuity legs.
    set slE1 [mt_slew_derive $slT $slSQ 100.0 200.0 10 90 rising]
    check "MT14/L a swing the signal never reaches at all answers an ABSENCE and not a destination problem: the disposition is absent at the VERB and at the SURFACE, the sentence is NOT calc::cross_msg destempty by identity at either layer, its family is one calc::cross_msg itself builds and is NOT destempty's, no db key is carried -- so an implementation that handed the empty list to calc::wave_dest would ship destempty and still carry no db key, which is why the identity legs and not the key leg are what fence it.  The non-vacuity leg asserts the start list really is empty, so this is the no-crossing shape and not the next row's" \
        [list [mt_disp [set sle [mt_call slewRate {v(sq)} 100.0 200.0 10 90 0 rising 0]]] \
              [string equal [mt_msg $sle] [pcall calc::cross_msg destempty]] \
              [mt_infamily [mt_msg $sle] [mt_crossmsg_families]] \
              [mt_notfamily [mt_msg $sle] [pcall calc::cross_msg destempty]] \
              [mt_shape [mt_msg $sle]] \
              [mt_sized [mt_sl_ns $slE1] 0] \
              [mt_disp [set sls [mt_call slewRate_scalar {v(sq)} 100.0 200.0 10 90 0 rising 0]]] \
              [mt_key $sls db] \
              [string equal [mt_msg $sls] [pcall calc::cross_msg destempty]] \
              [mt_notfamily [mt_msg $sls] [pcall calc::cross_msg destempty]]] \
        {absent 0 known elsewhere ok sized absent NOKEY-db 0 elsewhere}
    set slE2 [mt_slew_derive $slT $slLP 0 1 10 99.95 rising]
    check "MT14/L ...and the OTHER empty shape, a different cause and therefore a second row: start crossings EXIST and not one of them has an end crossing after it, so every point drops and the series is empty -- same absence at both layers, same negative identity against destempty at both, same family claim, still no db key, with two non-vacuity legs saying the start list is non-empty and the end list is empty so the row cannot be the one above wearing different arguments" \
        [list [mt_disp [set sle [mt_call slewRate {v(lp)} 0 1 10 99.95 0 rising 0]]] \
              [string equal [mt_msg $sle] [pcall calc::cross_msg destempty]] \
              [mt_infamily [mt_msg $sle] [mt_crossmsg_families]] \
              [mt_notfamily [mt_msg $sle] [pcall calc::cross_msg destempty]] \
              [mt_atleast [mt_sl_ns $slE2] 1] \
              [mt_sized [mt_sl_ne $slE2] 0] \
              [mt_disp [set sls [mt_call slewRate_scalar {v(lp)} 0 1 10 99.95 0 rising 0]]] \
              [mt_key $sls db] \
              [mt_notfamily [mt_msg $sls] [pcall calc::cross_msg destempty]]] \
        {absent 0 known elsewhere atleast1 sized absent NOKEY-db elsewhere}
    # ⚠⚠ AND A THIRD EMPTY SHAPE THE TWO ROWS ABOVE ARE STRUCTURALLY BLIND TO
    # BECAUSE OF THEIR OWN NON-VACUITY LEGS.  Each pins its shape with a
    # crossing-list COUNT, and those are precisely the two tests a defensive
    # implementer writes if the emptiness is guarded on the INPUT lists instead
    # of on the OUTPUT series.  The complement is both lists NON-EMPTY and the
    # series still empty.  `riseTime`'s band reaches it with an INVERTED swing;
    # this verb refuses that before any accessor, so the shape has to be minted
    # -- see `mt_sl_gaptab`.  THE ORACLE IS THE SHIPPED ORDINAL PATH at nth 1 on
    # the same request, so the row pins no words and cannot rot into a list of
    # shapes.
    set slGR [mt_sl_gaprpn]
    set slGTCL [mt_sl_gapcol $slRA]
    set slGENG [mt_addcol __mt_slgap $slGR 0]
    set slGD [mt_slew_derive $slT $slGTCL 0 1 10 90 rising]
    check "MT14/L ...and the THIRD empty shape, the one both rows above exclude by their own non-vacuity legs: the start list and the end list are BOTH non-empty and the series is still empty, because the only end crossing lies BEFORE the only start crossing.  The oracle is the SHIPPED ordinal path -- the same request at nth 1 must be an absence too -- so nth 0 must agree with it in disposition AND in calc::cross_msg family, must not be destempty's family, and the SURFACE must answer the same absence with no db key.  Four non-vacuity legs assert the shape: the engine's minted column agrees with the Tcl one, at least one start crossing, at least one end crossing, and a derived series of length zero" \
        [list [mt_cmpword $slGENG $slGTCL] \
              [mt_disp [set slg0 [mt_call slewRate $slGR 0 1 10 90 0 rising 0]]] \
              [mt_disp [set slg1 [mt_call slewRate $slGR 0 1 10 90 1 rising 0]]] \
              [mt_samefamily [mt_msg $slg0] [mt_msg $slg1]] \
              [mt_notfamily [mt_msg $slg0] [pcall calc::cross_msg destempty]] \
              [mt_infamily [mt_msg $slg0] [mt_crossmsg_families]] \
              [mt_atleast [mt_sl_ns $slGD] 1] \
              [mt_atleast [mt_sl_ne $slGD] 1] \
              [mt_sized [mt_len [mt_sl_y $slGD]] 0] \
              [mt_disp [set slgs [mt_call slewRate_scalar $slGR 0 1 10 90 0 rising 0]]] \
              [mt_key $slgs db] \
              [mt_notfamily [mt_msg $slgs] [pcall calc::cross_msg destempty]]] \
        {same absent absent samefamily elsewhere known atleast1 atleast1 sized absent NOKEY-db elsewhere}

    # --- M: the DELEGATION claim --------------------------------------------
    check "MT14/M T1 slewRate is a PURE DELEGATE: it REACHES calc::cross through a transitive closure over the ::calc:: names in the decommented bodies, and NO proc in that closure except cross itself issues an xschem raw add, values, value or del of its own -- which is what keeps SR5 of test_calc_scratch_reuse green and what forbids an evaluate-once helper, since such a helper has to evaluate into a column of its own and would appear here by name.  The SURFACE is excluded from that claim on purpose and the leg beside it says why: calc::wave_dest IS a direct adder, so a destination built inside the verb would print here" \
        [list [mt_reaches_cross slewRate] [mt_closure_raw slewRate] \
              [mt_direct_raw slewRate] [mt_direct_raw wave_dest] \
              [expr {[llength [mt_calc_closure slewRate]] > 1 ? {deeper} : {bare}}]] \
        {reaches {} no yes deeper}
    set slSTUB [mt_stub_run {
        set slo [mt_call slewRate {v(sq)} 0 1 10 90 1 rising 0]
        return [list [mt_disp $slo] \
                     [expr {[string match {*MTSTUB*} [mt_msg $slo]] ? {marker} : {nomarker}}] \
                     [mt_atleast $::mt_stub_calls 1]]
    }]
    check "MT14/M ...and the BEHAVIOURAL half, which the structural closure cannot give: with ::calc::cross replaced by a refusing stub slewRate REFUSES and carries the stub's OWN sentence through, and the stub was called at least once -- so the answer came back through cross rather than from samples the verb read for itself, whatever its body looks like.  calc::cross is restored by the probe and answers the shipped value again, which the last two legs say" \
        [list $slSTUB \
              [mt_disp [set sla [mt_call cross {v(sq)} 0.5 1 rising]]] \
              [llength [info commands ::mt_cross_keep]]] \
        [list {refused marker atleast1} measured 0]

    # --- P: the DATASET is READ, not echoed ---------------------------------
    set slDR {v(sq) v(div) * 1 +}
    set slDTCL0 [mt_offprod $slSQ [mt_col v(div) 0] 1]
    set slDTCL1 [mt_offprod [mt_col v(sq) 1] [mt_col v(div) 1] 1]
    set slDENG0 [mt_addcol __mt_sldiv $slDR 0]
    set slDD0 [mt_slew_derive $slT $slDTCL0 1 2 10 90 rising]
    set slDD1 [mt_slew_derive [mt_col time 1] $slDTCL1 1 2 10 90 rising]
    # ⚠⚠ THE TWO SERIES ARE NOT THE SAME LENGTH, AND THAT IS A PROPERTY OF THE
    # COMMITTED FIXTURE RATHER THAN OF THE REQUEST.  In dataset 1 the FIRST of the
    # three transitions reaches the low threshold and never the high one -- the
    # divider is `v(ramp)/4` there against `v(ramp)/2` in dataset 0 -- so T2's
    # bound drops that point and the series is one shorter.  Before the bound
    # landed both datasets answered three elements, the first of dataset 1's being
    # paired ACROSS two transitions, and this row's own derivation made the same
    # pairing, so the element-wise leg was green over it.  The lengths are now
    # asserted SEPARATELY, each against its own derivation, and the distinctness
    # leg aligns the two series on their TAILS so it compares the same transitions.
    check "MT14/P the dataset is READ and never echoed, by VALUE: the same request in the two datasets answers two series that agree element for element with two separate Tcl derivations over the two datasets' OWN columns, each series' LENGTH is its own derivation's, the two lengths DIFFER because dataset 1's first transition does not complete, and the tail-aligned elements are DISTINCT between them -- so a verb that passed the argument through and read dataset 0 twice reddens on the lengths and on every element.  The engine's minted column is asserted against the Tcl one so the comparand is not the engine compared with itself" \
        [list [mt_cmpword $slDENG0 $slDTCL0] \
              [mt_islist [set sld0 [mt_call slewRate $slDR 1 2 10 90 0 rising 0]] [mt_sl_y $slDD0]] \
              [mt_islist [set sld1 [mt_call slewRate $slDR 1 2 10 90 0 rising 1]] [mt_sl_y $slDD1]] \
              [mt_key $sld0 dataset] [mt_key $sld1 dataset] \
              [mt_sized [mt_len [mt_val $sld0]] [llength [mt_sl_y $slDD0]]] \
              [mt_sized [mt_len [mt_val $sld1]] [llength [mt_sl_y $slDD1]]] \
              [mt_atleast [mt_len [mt_val $sld0]] 3] \
              [expr {[mt_len [mt_val $sld0]] eq [mt_len [mt_val $sld1]] ? {EQUAL} : {shorter}}] \
              [mt_sized [mt_sl_ns $slDD1] [expr {[llength [mt_sl_y $slDD1]] + 1}]] \
              [mt_tailpairs [mt_val $sld0] [mt_val $sld1]]] \
        {same ok ok 0 1 sized sized atleast3 shorter sized distinct}
    check "MT14/P ...and by DISPOSITION, which an echoing verb cannot produce at all: v(div) at a swing dataset 0 reaches and dataset 1 does not MEASURES in one and is ABSENT in the other, from one request differing only in the dataset argument.  A non-integer and a negative dataset are REFUSED through calc::cross's OWN arms, compared by identity, because the dataset belongs to cross and this verb must not re-spell its sentences" \
        [list [mt_disp [mt_call slewRate {v(div)} 3 4.5 10 90 1 rising 0]] \
              [mt_disp [mt_call slewRate {v(div)} 3 4.5 10 90 1 rising 1]] \
              [string equal [mt_msg [mt_call slewRate {v(sq)} 0 1 10 90 1 rising 1.5]] \
                            [pcall calc::cross_msg intdataset 1.5]] \
              [mt_disp [mt_call slewRate {v(sq)} 0 1 10 90 1 rising -1]]] \
        {measured absent 1 refused}

    # --- Q: THE PARITY TRAP, on the builders whose arms can be CALLED --------
    # ⚠⚠ A COMMENT BETWEEN ANY TWO PATTERNS OF ANY `switch` IS A PARSE ERROR
    # `info complete` CANNOT SEE, and this stage wrote new patterns into several.
    # ⚠ THIS ROW'S POPULATION IS THREE PROCS AND ITS NAME NO LONGER CLAIMS MORE.
    # An earlier revision was named *"for every switch this stage touched"* while
    # driving these three, and `calc::overshoot` -- a verb the SAME stage minted,
    # carrying its own `switch` on the sim type -- was in neither this row nor any
    # other.  MEASURED: an EVEN-word comment between that proc's two patterns left
    # this whole file at ALL PASS, while an odd-word one in the same place reddened
    # rows across several bands at once -- the parity asymmetry, on this stage's own
    # verb.  No row count is given, because this file's band sizes move and nothing
    # re-measures a figure written into a comment here.  The population is row MT14/Q2's subject; what Q adds is the
    # BEHAVIOURAL half, which is only available where an arm can be reached by
    # calling the proc with the pattern as its first argument.  Band MT12 already drives
    # `calc::arg_msg`'s arms from a line scan over its own body; this row is the
    # same claim for all three procs by a DIFFERENT and stronger derivation -- the
    # switch's trailing argument parsed as the list Tcl parses it -- and it is the
    # only thing in the tree that sees the EVEN-parity case, where every arm still
    # answers correctly and the damage is latent until one word is edited.  The
    # two derivations are cross-checked against each other on `cross_msg`, which
    # is the non-vacuity leg: if the list parse ever silently answered nothing,
    # the line scan would disagree.
    check "MT14/Q THE PARITY TRAP, fenced on both sides for the three message and spec builders whose arms can be DRIVEN by calling them: for calc::fn_argspec, calc::cross_msg and calc::arg_msg the arm set is DERIVED from the proc's own trailing switch argument, parsed as the list Tcl parses it, and EVERY arm is driven with the arity read off info args -- none raises and none answers the empty fall-through.  The decommented parse and the RAW parse must AGREE, which is what catches an EVEN-word comment between two patterns: that is a complete no-op today and detonates the moment a word is edited into or out of it, and nothing else in this tree sees it.  Measured both ways on this stage's own fn_argspec.  The floors ride along because an empty arm set drives nothing, a missing proc answers a sentinel rather than an empty set, and the line-scan derivation MT12 uses must agree with the list parse on cross_msg" \
        [list [mt_switch_agree fn_argspec] [mt_switch_drive fn_argspec] \
              [mt_atleast [llength [mt_switch_arms fn_argspec]] 5] \
              [mt_switch_agree cross_msg] [mt_switch_drive cross_msg] \
              [mt_atleast [llength [mt_switch_arms cross_msg]] 30] \
              [mt_switch_agree arg_msg] [mt_switch_drive arg_msg] \
              [mt_atleast [llength [mt_switch_arms arg_msg]] 7] \
              [mt_switch_arms __mt_no_such_switch__] \
              [mt_switch_drive __mt_no_such_switch__] \
              [expr {[lsort [mt_switch_arms cross_msg]] eq [mt_crossmsg_arms] ? {agree} : {DIFFER}}]] \
        [list agree {} atleast5 agree {} atleast30 agree {} atleast7 \
              NOPROC:calc::__mt_no_such_switch__ \
              NOPROC:calc::__mt_no_such_switch__ agree]

    # --- Q2: THE SAME TRAP, over the POPULATION instead of three names -------
    # ⚠⚠ THE PARSE HALF NEEDS NO CALL, SO IT COSTS NOTHING TO MAKE IT TOTAL --
    # which is the whole argument for this row existing next to Q.  `mt_switch_agree`
    # compares the decommented parse against the raw one and never invokes the
    # proc, so it applies to a `switch` on a LOCAL variable -- `calc::overshoot`'s
    # on the sim type, `calc::cross`'s on the same -- exactly as it applies to a
    # message builder's on its first argument.  Q could never have reached those:
    # driving an arm means calling the proc with the pattern, and a pattern that is
    # not an argument cannot be driven that way.
    #
    # ⚠ DECLARED LIMIT: this is the PARSE half alone.  It catches both parities --
    # the odd one as `ODDPAIRING` from the raw parse, the even one as a disagreement
    # where the raw parse carries extra patterns made of the comment's own words --
    # and it says nothing about whether an arm answers correctly.  Q is the
    # behavioural half and covers three of the members; the rest are parse-only, and
    # that is stated rather than left to be discovered.
    check "MT14/Q2 the parity fence is TOTAL over a population derived from the namespace rather than named: every ::calc:: proc whose decommented body opens a switch in command position is a member, each has exactly ONE such opening so the first-switch scan is total over it, and for EVERY member the decommented parse and the RAW parse agree -- so a comment between two patterns of ANY of them reddens here whichever parity it has, including the even one that is a complete no-op today and detonates when one word is edited.  The population is asserted as a FLOOR and strictly larger than the set row Q drives behaviourally, so a shrinking namespace cannot make this vacuous and nobody can read Q's three names as the whole set" \
        [list [mt_switch_words [mt_switch_procs] : 1] \
              [mt_switch_words [mt_switch_parity] = 1] \
              [mt_atleast [llength [mt_switch_procs]] 10] \
              [mt_excess [llength [mt_switch_procs]] 3 1]] \
        [list 1 agree atleast10 atleast1]

    # --- N: R402, the band leaks nothing ------------------------------------
    check "MT14/N R402 the band left no __calc_tmp*, no __mt_* column and no probe proc behind -- the hygiene claim for an instrument that mints columns in the product's own inventory, and a row rather than a habit because MT10 and MT11 both derive over ::calc:: and would measure a leftover probe as a product proc" \
        [list [leaked] [probeleft] [info procs ::calc::__mt_*]] {{} {} {}}
    pcall xschem raw clear
}

# ⚠⚠ BAND MT15's KEYSTONE IS SYNTHETIC, AND THE MEASUREMENT THAT FORCED IT IS
# THE WHOLE REASON THIS HELPER EXISTS.  A frequency is one value per COMPLETE
# PERIOD, so a series with three members needs FOUR same-edge crossings, and the
# committed deck cannot supply them: the fixture's 10 ms sweep holds two and a
# half square periods, so `v(sq)` gives three rising crossings and two values,
# `v(lp)` gives three and two, `1 v(sq) -` gives two and one, and `v(ramp)` and
# `v(div)` are MONOTONE and give one crossing and no period at all.
#
# ⚠⚠ AND `v(sq)` IS BLIND FOR THIS VERB AT EVERY LEVEL, WHICH IS ISSUE 1643's
# TRAP ARRIVING AT A FOURTH VERB.  The square's period is 4 ms by construction
# and does not move with the level, so its two frequencies agree to a RELATIVE
# well inside this file's MTTOL -- row MT15/N asserts that in the run rather
# than this sentence quoting it -- and on that column a producer that writes
# element 0 into every element, REVERSES the series or fills a CONSTANT passes
# an element-wise comparison.  So `v(sq)` is this band's declared CONTROL,
# driven BY NAME and asserted `same`, and the discriminating evidence comes from
# the train below and from `v(lp)`, whose first period carries the initial
# transient while its second is periodic steady state.
#
# THE TRAIN: four triangular bumps of EQUAL half-width at UNEQUAL spacings, so
# the three periods it opens are three different numbers.  It is carried by
# `v(div)` rather than `v(ramp)` on purpose, and that ONE choice does three jobs:
#
#   * `v(div)` is `v(ramp)/2` in dataset 0 and `v(ramp)/4` in dataset 1 (the
#     deck's own table, which `div_t` already encodes for two other bands), so
#     the SAME request answers halved frequencies in the second dataset and the
#     dataset argument is discriminated element by element with no value shared
#     between the two answers;
#   * `v(ramp)` is PWL(0 0 10m 10) and therefore carries the time in
#     MILLISECONDS as its value, so the bump centres have a CLOSED FORM and this
#     band has a second derivation that contains no product verb;
#   * every centre and every `c ± hw` is a multiple of 0.05 in `v(div)` units,
#     so every breakpoint lands on the deck's own sampling grid in BOTH
#     datasets and the sampled column is an exact piecewise-linear reading of
#     the continuous shape.
#
# ⚠ THE RPN SHAPE IS `mt_tri`'s, WITH ITS COLUMN SWAPPED, so the triangle's
# expression exists ONCE in this file and a correction to it cannot reach one
# band and miss the other.
#
# ⚠ THE PERIOD OF THIS TRAIN IS LEVEL-INDEPENDENT, which is stated here because
# it is the one place the keystone is weaker than it looks: equal half-widths
# move both of a period's crossings by the same amount, so `value` is BLIND to
# the level on this column and only the X series sees it.  Row MT15/F fences the
# level through the X series and asserts the level-independence POSITIVELY, so
# nobody can read MT15/B as covering it.
proc mt_fq_tri {c hw h} { return [string map {v(ramp) v(div)} [mt_tri $c $hw $h]] }
proc mt_fq_centres {} { return {0.5 1.15 1.7 2.15} }
proc mt_fq_hw {} { return 0.15 }
proc mt_fq_rpn {} {
    set parts {}
    foreach c [mt_fq_centres] { lappend parts [mt_fq_tri $c [mt_fq_hw] 1] }
    set e [lindex $parts 0]
    foreach p [lrange $parts 1 end] { append e " $p max()" }
    return $e
}
# DERIVATION 1 for this band -- the closed form.  `v(div)` reaches the level L on
# a bump's rising branch at `c - hw*(1-L)` of its own units and on the falling
# branch at `c + hw*(1-L)`; one unit of `v(div)` is `S` milliseconds of sweep,
# with S from the deck's per-dataset divider ratio.  `div_t` encodes the same
# ratio for two other bands and is deliberately not reused: it answers a TIME for
# a level, which is a different question from this one.
proc mt_fq_scale {ds} { return [expr {$ds == 0 ? 2.0 : 4.0}] }
proc mt_fq_cross {L ds} {
    set out {}
    foreach c [mt_fq_centres] {
        lappend out [expr {[mt_fq_scale $ds] \
            * (double($c) - [mt_fq_hw]*(1.0 - double($L))) * 1.0e-3}]
    }
    return $out
}
# the frequencies a crossing list implies -- ONE PER COMPLETE PERIOD, so the
# answer is one element SHORTER than the list it came from and a trailing
# crossing that opens nothing contributes nothing.  R416 gives `dutyCycle` the
# same rule, which is why it is spelled once here and fed from BOTH derivations: the closed form above, and this file's own D3 + D4
# over the bulk column.
proc mt_fq_fromx {xs} {
    if {[catch {llength $xs} n]} { return "NOTALIST:{$xs}" }
    if {$n < 2} { return {} }
    set out {}
    for {set i 0} {$i < $n - 1} {incr i} {
        set T [expr {double([lindex $xs [expr {$i+1}]]) - double([lindex $xs $i])}]
        if {$T <= 0} { return "NONPOSITIVE:$i" }
        lappend out [expr {1.0/$T}]
    }
    return $out
}
# R420's three axes, all out of the two crossings each period is already built
# from, so none of them costs a read.  `start` is the OPENING crossing.
proc mt_fq_axis {xs which} {
    if {[catch {llength $xs} n]} { return "NOTALIST:{$xs}" }
    if {$n < 2} { return {} }
    set out {}
    for {set i 0} {$i < $n - 1} {incr i} {
        set a [lindex $xs $i] ; set b [lindex $xs [expr {$i+1}]]
        if {$which eq {number}} {
            lappend out [expr {$i + 1}]
        } elseif {$which eq {mid}} {
            lappend out [expr {(double($a) + double($b))/2.0}]
        } else {
            lappend out $a
        }
    }
    return $out
}
# two answers compared KEY BY KEY with the minted temporary excluded, which is
# the instrument the alias rows need: `calc::tmpvec` never re-uses a name, so a
# delegate's answer carries a different `dest` serial from its target's and that
# is a property of the minter rather than a disagreement.  The disposition is
# checked FIRST and carried through, because two readings that answer the SAME
# SENTINEL have equal key sets and equal values at every key -- which is exactly
# how a row of this shape passes on a tree with no verb in it.
proc mt_fq_dictcmp {a b {skip dest}} {
    foreach d [list [mt_disp $a] [mt_disp $b]] {
        if {$d ne {measured} && $d ne {absent} && $d ne {refused}} { return $d }
    }
    set ka [mt_keys $a] ; set kb [mt_keys $b]
    if {$ka ne $kb} { return "keys:{$ka}|{$kb}" }
    set bad {}
    foreach k $ka {
        if {[lsearch -exact $skip $k] >= 0} continue
        if {[mt_key $a $k] ne [mt_key $b $k]} { lappend bad $k }
    }
    if {[llength $bad]} { return "differ:$bad" }
    return same
}
# `absent` when a literal does NOT occur in a proc's decommented body, the match
# itself otherwise -- the leg that says the enum member lists and the period
# formula exist exactly ONCE in the tree, inside `calc::frequency`, and that the
# alias is a pure delegate rather than a second implementation.
#
# ⚠ A TEXT SCAN IS THE WEAK HALF OF ROW MT15/O AND IS DECLARED AS SUCH.  Five
# rounds of text-scanning legs were each defeated in turn on a sibling signature
# pin -- a comment quoting the literal, an unqualified callee, a backslash
# continuation -- while no `info args` leg was ever defeated by any of the
# sabotages derived against it.  So the row's PIN is `info args` and
# `info default`; this scan only says the second copy is absent, and it runs over
# a DECOMMENTED body so a comment quoting the literal cannot satisfy it.
proc mt_fq_absent {p pat} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    if {[catch {info body ::calc::$p} b]} { return "RAISED:$p" }
    if {[string first $pat [mt_decomment $b]] < 0} { return absent }
    return "present:$pat"
}

# =========================================================================
# MT15 -- `frequency` AND ITS ALIAS `freq`, THE FIFTH LAYERED VERB.  The
# VERB-AND-SURFACE half; it gates on the COUNTED arm.
#
# Spec     doc/claude/specs/calculator.md section 7.2 (the catalogue row) and
#          section 7.2ac (R419-R421).  R420 rules the X axis IN SO MANY WORDS
#          for this verb -- *"`frequency` inherits the same argument"* -- so all
#          three axes ship and the default is the time the period started.
# Fence    the DESTINATION's own bookkeeping is band WD9 of
#          tests/headless/test_calc_wave_dest.tcl; the dialog, the click, the
#          buffer and the status sentence are display-only and belong to band
#          S28 of tests/headless/test_calc_skeleton.tcl and band PL10 of
#          tests/headless/test_calc_plot.tcl, both `dcases` ALONE.
#
# ⚠⚠ WRITTEN RED-FIRST, BEFORE `calc::frequency` EXISTED.  Every behavioural row
# below failed when it was written and each failure named
# `NOPROC:calc::frequency` or `NOPROC:calc::freq` rather than raising; the
# transcript is in this stage's report.
#
# ⚠ THREE ROWS HERE PASS WITH NO FEATURE PRESENT, AND THEY ARE NAMED RATHER THAN
# LEFT FOR A READER TO WORK OUT, because the red-first transcript is the only
# evidence that the rest are fences at all.  MEASURED on the red run,
# not predicted: MT15/A, the fixture's own crossing structure; MT15/C, the two
# derivations agreeing with each other, which contains no product verb on either
# side by design; and MT15/S, the R402 inventory, which is a claim about this
# band's own hygiene.  Individual non-vacuity LEGS pass there too, for the same
# reason -- the crossing counts, the strictness, the engine-against-closed-form
# agreements and the two-against-three-point controls all measure the FIXTURE.
#
# THE ARGUMENT SET, AND WHY EACH MEMBER IS THERE RATHER THAN DECIDED HERE:
#
#   * `level` is REQUIRED and is a MANDATORY POSITIONAL formal, the shape `cross`
#     and `dutyCycle` already have rather than `riseTime`'s optional-with-empty
#     default.  That shape exists only because R415 demands a REFUSAL for a
#     missing SWING, and no ruling demands one for a missing level; the dialog
#     cannot produce an empty one either, because `calc::arg_bad` rejects a
#     `real` field through `calc::eval_finite` before the call is composed.  A
#     Tcl caller that omits it gets a `wrong # args` THROW, which row MT15/O's
#     formal pin makes visible and which no row here calls a refusal.
#   * `cycle`, not `nth`, and 0 means EVERY period -- `dutyCycle`'s own word for
#     the same thing, with the ordinal reading from either end exactly as R414's
#     does.  ⚠ THAT IS WHAT DISSOLVES THE "AVERAGE OR FIRST?" QUESTION RATHER
#     THAN ANSWERING IT, and the reason it must be dissolved is arithmetic:
#     mean(1/T) and 1/mean(T) are DIFFERENT NUMBERS, so silently picking one
#     would be a wrong answer dressed as a right one, and `period_jitter` /
#     `freq_jitter` are already catalogued separately for the statistics.
#   * `xaxis` is RATIFIED by R420 for this verb by name, so it is inherited and
#     not chosen.
#   * `edge` is {rising falling} and `either` is DELIBERATELY NOT A MEMBER, which
#     is a divergence from `cross`'s own three-member list with a mechanical
#     reason: a period runs between two crossings of the SAME edge, so `either`
#     interleaves the two directions and answers alternating HALF-periods --
#     dimensionally a frequency, so nothing downstream could reject it by
#     inspection.  Row MT15/I refuses it and carries what it would otherwise
#     have answered, measured in the run.
#   * `dataset` defaults to 0, D12 inherited through `cross` and stated rather
#     than inherited, as every verb in this family does.
#
# THE NEW `calc::cross_msg` ARMS ARE NEW AND NOT REUSES, and that is a decision
# rather than an accident of naming: `badcycle`, `badxaxis`, `nocycle`
# and `nocycleat` all open with *"Duty cycle:"* and `badedge` says the edge may
# be *"rising, falling or either"*, which is FALSE for this verb.  Borrowing any
# of them would put the wrong verb's voice, or a wrong claim, on a frequency
# refusal.  No row here asserts the WORDS -- they are unratified user-visible
# wording covered by the `rule` debt filed against `calc::eval_msg`'s sentences;
# the rows assert `mt_shape`, the FAMILY, and identities.
#
# DECLARED LIMITS, so nobody reads a green band as covering them:
#
#  F1 A frequency measured on an `ac` database is a WRONG-UNIT number and this
#     verb does not refuse it: `cross` maps sim_type `ac` to the column
#     `frequency`, so a "period" there is a frequency difference in Hz and the
#     answer is seconds.  `riseTime` and `slewRate` have the identical exposure
#     and shipped without a refusal, and the `ac` arm is unreachable through the
#     committed fixture, so a refusal would be unfenced in exactly the way the
#     arm it guards is.
#  F2 `freqspan` -- two crossings at the same X -- is DECLARED UNREACHABLE
#     through the committed fixture: the linearized grid is strictly increasing
#     within a dataset and `allpoints` is already refused by `cross`.  It exists
#     because a non-linearized raw can carry duplicate timepoints at a
#     breakpoint, where the alternative is a divide-by-zero raise degrading into
#     *"Measuring frequency did not complete"*.  Same declared status as
#     `dutyCycle`'s `nofall` arm.  MT14/Q drives the arm for PARSE; nothing
#     drives it for BEHAVIOUR.
#  F3 Nothing checks that the crossings are a PERIODIC TRAIN.  A ringing or noisy
#     signal gives one "frequency" per adjacent crossing pair, the spurious high
#     ones included.  That is the published meaning of the shipped help text,
#     *"Frequency measured from the wave's crossings"*, and it is the same
#     exposure `cross` has.  Not guarded and not fenced.
#  F4 No column anywhere gives an EQUAL-COUNT, DIFFERENT-VALUE rising/falling
#     pair -- the train's periods are the centre spacings and are the same in
#     both directions -- so `edge` is fenced by COUNT and by DISPOSITION and
#     never by value.  Adequate because there is exactly ONE `cross` call to pass
#     it to, but stated so nobody reads MT15/H as a value claim.
#  F5 `v(lp)`'s transient crossing times have NO hand derivation in
#     tests/headless/data/README.md, so MT15/M is a SINGLE derivation from the
#     column.  Only the train and the `v(sq)` control are derived twice.
#  F6 Everything the user actually touches is display-only: the click, the modal,
#     the `grab`, the buffer really being left untouched on a wave answer, the
#     destination sentence really reaching `.calc.status.msg`, R421's one-step
#     undo, and the trace really drawing against its own X.  Nothing asserts that
#     a frequency wave DRAWS; that is a `look` debt.
#  F7 The destination built on the success path is NOT dropped by the product --
#     the declared leak unit J1 introduced, whose rate this caller adds to.  Who
#     frees it is hole H11 and is unruled.  The rows that build one drop it
#     themselves so MT15/S stays a claim about the band.
# =========================================================================
group MT15 {
    pcall mt_load tran
    set fqT  [mt_col time 0]
    set fqT1 [mt_col time 1]
    set fqSQ [mt_col v(sq) 0]
    set fqLP [mt_col v(lp) 0]
    set fqR  [mt_fq_rpn]
    # the train's column, both ways: the engine's and this file's closed form.
    set fqENG  [mt_addcol __mt_fqtrain $fqR 0]
    set fqENG1 [mt_addcol __mt_fqtrain $fqR 1]
    # ...and the crossing list read back off `calc::cross` itself, so no row
    # below writes down how many crossings this column has.
    set fqX0 [mt_val [mt_call cross $fqR 0.4 0 rising 0]]
    set fqX1 [mt_val [mt_call cross $fqR 0.4 0 rising 1]]

    # --- A: NON-VACUITY, the only row here that may be green with no verb ----
    check "MT15/A the train this band is measured on really has the crossing STRUCTURE every row below depends on, measured rather than claimed: calc::rpn_bad_token accepts the expression, its token count is well inside calc::rpn_maxtokens, calc::cross answers the same number of rising crossings in BOTH datasets as the train has bumps, every one of them falls STRICTLY between two samples so no snapping convention could have produced these numbers, and the engine's crossing times agree with this file's own closed form S*(c - hw*(1-L)) to better than 1e-12 relative in both datasets.  A fixture or engine change that silently altered this column would make every number below wrong in the SAME direction, which is the one defect an element-wise comparison cannot see" \
        [list [pcall calc::rpn_bad_token $fqR] \
              [mt_atleast [llength $fqR] 40] \
              [expr {[llength $fqR] < [pcall calc::rpn_maxtokens] ? {fits} : {TOOLONG}}] \
              [mt_sized [mt_len $fqX0] [llength [mt_fq_centres]]] \
              [mt_sized [mt_len $fqX1] [llength [mt_fq_centres]]] \
              [mt_allstrict $fqT  $fqENG  0.4 rising] \
              [mt_allstrict $fqT1 $fqENG1 0.4 rising] \
              [mt_listcmp $fqX0 [mt_fq_cross 0.4 0] 1e-12] \
              [mt_listcmp $fqX1 [mt_fq_cross 0.4 1] 1e-12]] \
        [list {} atleast40 fits sized sized strict strict ok ok]

    # --- B: THE SERIES, element-wise, with the ADJACENT-PAIR spread in the row
    # ⚠⚠ THE STATISTIC IS THE ADJACENT PAIR AND NOT THE RANGE, and that is a
    # measured house lesson rather than a preference: a sibling band's per-edge
    # series had a RANGE that looked perfectly adequate while its pair (1,2)
    # agreed to well inside MTTOL, because the pole was in periodic steady state
    # -- and a producer that repeated the second value into the third passed it.
    # `mt_alldistinct` answers `distinct` only when EVERY neighbour differs.
    set fqSER [mt_fq_fromx [mt_fq_cross 0.4 0]]
    check "MT15/B cycle 0 MEASURES the per-period series, element for element against this file's own closed form, with the ADJACENT-PAIR spread of the compared series carried in the row rather than its range: every neighbour of the answer differs by more than MTTOL, and the count is one SHORTER than the crossing list calc::cross answered.  So a constant fill, a reversal, element 0 repeated into every element, a dropped point and an off-by-one slice of the crossing list are each caught here -- the four wrong fills are built FROM the correct series so they cannot drift away from it, and the two-point control beside them says why a three-period column was needed at all: at two points a reversal and a rotation are the IDENTICAL list" \
        [list [mt_islist [set fqa [mt_call frequency $fqR 0.4 rising 0 0 start]] $fqSER] \
              [mt_alldistinct [mt_val $fqa]] \
              [mt_sized [mt_len [mt_val $fqa]] [mt_nminus [mt_len $fqX0] 1]] \
              [mt_notlist $fqa $fqSER] \
              [mt_notlist $fqa [lreverse $fqSER]] \
              [mt_notlist $fqa [mt_rot1 $fqSER]] \
              [mt_notlist $fqa [mt_midleft $fqSER]] \
              [mt_notlist $fqa [mt_midmean $fqSER]] \
              [mt_notlist $fqa [lrepeat [llength $fqSER] [lindex $fqSER 0]]] \
              [expr {[lreverse $fqSER] ne [mt_rot1 $fqSER] ? {tellapart} : {SAME}}] \
              [expr {[lreverse {1 2}] eq [mt_rot1 {1 2}] ? {twoblind} : {TWOSEES}}]] \
        [list ok distinct sized same distinct distinct distinct distinct distinct \
              tellapart twoblind]

    # --- C: THE SECOND DERIVATION, with no product verb in either half -------
    check "MT15/C the closed form and this file's OWN D3+D4 over the bulk column agree on the same series and on the same crossing list, with no product verb anywhere in the comparison -- so a wrong closed form in MT15/B's expectation would show up as the two derivations DISAGREEING rather than as both being wrong in the same place.  The non-vacuity leg is that the derivation is dataset-sensitive: the two datasets' closed forms are distinct element for element, so an agreement is not an artefact of a constant" \
        [list [mt_listcmp [mt_derive_x $fqT $fqENG 0.4 rising] [mt_fq_cross 0.4 0] 1e-12] \
              [mt_listcmp [mt_fq_fromx [mt_derive_x $fqT $fqENG 0.4 rising]] $fqSER 1e-9] \
              [mt_listcmp [mt_fq_fromx [mt_derive_x $fqT1 $fqENG1 0.4 rising]] \
                          [mt_fq_fromx [mt_fq_cross 0.4 1]] 1e-9] \
              [mt_cmpword [mt_fq_fromx [mt_fq_cross 0.4 1]] $fqSER]] \
        {ok ok ok distinct}

    # --- D: THE X SERIES IS THE OPENING CROSSING ----------------------------
    check "MT15/D the X series is the OPENING crossing of each period and the series is one element SHORTER than the crossing list, so a trailing crossing that opens nothing contributes nothing -- the same one-value-per-COMPLETE-period rule R416 gives dutyCycle, read across from a cycle to a period.  sweep is calc::cross's own crossing list minus its last element, element for element, and it is DISTINCT from the closing-crossing candidate at every element: a producer driven from the CLOSING crossing reddens here rather than being caught by nobody" \
        [list [mt_listcmp [mt_key $fqa sweep] [mt_range $fqX0 0 end-1] 1e-12] \
              [mt_sized [mt_len [mt_key $fqa sweep]] [mt_len [mt_val $fqa]]] \
              [mt_cmpword [mt_key $fqa sweep] [mt_range $fqX0 1 end]] \
              [mt_distinctmap2 [mt_range $fqX0 0 end-1] [mt_range $fqX0 1 end]] \
              [mt_atleast [mt_len $fqX0] 4]] \
        {ok sized distinct distinct atleast4}

    # --- E: R420's THREE AXES ------------------------------------------------
    check "MT15/E R420's three axes all ship and all three are derived from the two crossings their period is already built from, so none costs a read: start is the opening crossing, number is the 1-based ordinal and mid is the mean of the pair, each compared element-wise against this file's own derivation.  They are shown MUTUALLY DISTINCT at element 0 -- which is what catches an axis argument accepted and ignored, a mid computed from the wrong pair and a 0-based number -- and the VALUE is identical across all three, because the axis moves the X and nothing else" \
        [list [mt_listcmp [mt_key [set fqs [mt_call frequency $fqR 0.4 rising 0 0 start]] sweep] \
                          [mt_fq_axis $fqX0 start] 1e-12] \
              [mt_listcmp [mt_key [set fqn [mt_call frequency $fqR 0.4 rising 0 0 number]] sweep] \
                          [mt_fq_axis $fqX0 number] 1e-12] \
              [mt_listcmp [mt_key [set fqm [mt_call frequency $fqR 0.4 rising 0 0 mid]] sweep] \
                          [mt_fq_axis $fqX0 mid] 1e-12] \
              [mt_distinct [mt_at [mt_key $fqs sweep] 0] [mt_at [mt_key $fqn sweep] 0]] \
              [mt_distinct [mt_at [mt_key $fqs sweep] 0] [mt_at [mt_key $fqm sweep] 0]] \
              [mt_distinct [mt_at [mt_key $fqn sweep] 0] [mt_at [mt_key $fqm sweep] 0]] \
              [mt_islist $fqs $fqSER] [mt_islist $fqn $fqSER] [mt_islist $fqm $fqSER] \
              [mt_shape [mt_msg [mt_call frequency $fqR 0.4 rising 0 0 sideways]]] \
              [string equal [mt_msg [mt_call frequency $fqR 0.4 rising 0 0 sideways]] \
                            [pcall calc::cross_msg freqxaxis sideways]] \
              [mt_disp [mt_call frequency $fqR 0.4 rising 0 0 {}]]] \
        [list ok ok ok distinct distinct distinct ok ok ok ok 1 refused]

    # --- F: THE LEVEL, measured through the X series -------------------------
    # ⚠⚠ THE PERIOD OF THIS COLUMN DOES NOT MOVE WITH THE LEVEL, so an
    # element-wise `value` row on the train CANNOT see a hardcoded level and this
    # row asserts BOTH halves positively rather than leaving the first as an
    # untested assumption.
    set fq4 [mt_call frequency $fqR 0.4 rising 0 0 start]
    set fq6 [mt_call frequency $fqR 0.6 rising 0 0 start]
    check "MT15/F the LEVEL is really read, measured through the X SERIES because the period of a train of equal-half-width triangles is LEVEL-INDEPENDENT -- which this row asserts POSITIVELY, value `same` across two levels, so nobody can read MT15/B as covering the level.  The X series is DISTINCT across the same two levels at every element and each one agrees with its own closed form, so a hardcoded level reddens here and nowhere else in this band" \
        [list [mt_cmpword [mt_val $fq4] [mt_val $fq6]] \
              [mt_distinctmap2 [mt_key $fq4 sweep] [mt_key $fq6 sweep]] \
              [mt_listcmp [mt_key $fq4 sweep] [mt_fq_axis [mt_fq_cross 0.4 0] start] 1e-12] \
              [mt_listcmp [mt_key $fq6 sweep] [mt_fq_axis [mt_fq_cross 0.6 0] start] 1e-12] \
              [mt_cmpword [mt_fq_cross 0.4 0] [mt_fq_cross 0.6 0]] \
              [mt_shape [mt_msg [mt_call frequency $fqR nan rising 0 0]]] \
              [string equal [mt_msg [mt_call frequency $fqR nan rising 0 0]] \
                            [pcall calc::cross_msg badlevel nan]]] \
        [list same distinct ok ok distinct ok 1]

    # --- G: THE DATASET is READ and not echoed -------------------------------
    check "MT15/G the dataset is READ and never echoed, by VALUE: the same request answers HALVED frequencies in dataset 1 -- the divider is v(ramp)/2 in one and v(ramp)/4 in the other -- each agreeing element for element with its OWN closed form, with every element DISTINCT between the two answers and no value shared between the two lists.  That is the hole an earlier row in a sibling band was satisfied by: a verb that REPORTS the dataset it was handed while passing 0 to cross.  A bad dataset propagates cross's own refusal, which names BOTH numbers, and a non-integer and a negative one propagate cross's own arms by identity because the dataset belongs to cross and this verb must not re-spell its sentences" \
        [list [mt_islist [set fqd0 [mt_call frequency $fqR 0.4 rising 0 0]] $fqSER] \
              [mt_islist [set fqd1 [mt_call frequency $fqR 0.4 rising 0 1]] \
                         [mt_fq_fromx [mt_fq_cross 0.4 1]]] \
              [mt_key $fqd0 dataset] [mt_key $fqd1 dataset] \
              [mt_distinctmap2 [mt_val $fqd0] [mt_val $fqd1]] \
              [string equal [mt_msg [mt_call frequency $fqR 0.4 rising 0 7]] \
                            [pcall calc::cross_msg dataset 7 [pcall xschem raw datasets]]] \
              [string equal [mt_msg [mt_call frequency $fqR 0.4 rising 0 1.5]] \
                            [pcall calc::cross_msg intdataset 1.5]] \
              [mt_disp [mt_call frequency $fqR 0.4 rising 0 -1]]] \
        [list ok ok 0 1 distinct 1 1 refused]

    # --- H: THE EDGE reaches `cross` ----------------------------------------
    set fqNR [mt_len [mt_val [mt_call cross {v(sq)} 0.5 0 rising 0]]]
    set fqNF [mt_len [mt_val [mt_call cross {v(sq)} 0.5 0 falling 0]]]
    check "MT15/H the EDGE reaches cross, measured by crossing COUNT and by DISPOSITION because no column in this deck gives an equal-count different-value rising/falling pair -- the train's periods are its centre spacings and are the same in both directions, which limit F4 states.  v(sq) at 0.5 opens one fewer period falling than rising, each series sized against the count cross itself answers for that direction, and the two counts really DIFFER so the row is not two readings of one number; then a mixed column at a level only its rising edge reaches MEASURES one way and is ABSENT the other.  A verb hardcoded to rising answers the rising count for the falling request and one hardcoded to falling answers the falling count for the rising one" \
        [list [mt_sized [mt_len [mt_val [mt_call frequency {v(sq)} 0.5 rising 0 0]]] \
                        [mt_nminus $fqNR 1]] \
              [mt_sized [mt_len [mt_val [mt_call frequency {v(sq)} 0.5 falling 0 0]]] \
                        [mt_nminus $fqNF 1]] \
              [mt_countsdiffer $fqNR $fqNF] \
              [mt_disp [mt_call frequency {v(sq) v(div) +} 1.3 rising 0 0]] \
              [mt_disp [mt_call frequency {v(sq) v(div) +} 1.3 falling 0 0]] \
              [mt_islist [mt_call frequency {v(sq)} 0.5 falling 0 0] \
                         [mt_fq_fromx [mt_derive_x $fqT $fqSQ 0.5 falling]]] \
              [mt_islist [mt_call frequency {v(sq)} 0.5 rising 0 0] \
                         [mt_fq_fromx [mt_derive_x $fqT $fqSQ 0.5 rising]]]] \
        [list sized sized differ measured absent ok ok]

    # --- I: `either` IS REFUSED, and the row carries what it would answer ----
    set fqEI [mt_call frequency {v(sq)} 0.5 either 0 0]
    set fqHALF [mt_fq_fromx [mt_val [mt_call cross {v(sq)} 0.5 0 either 0]]]
    check "MT15/I `either` is REFUSED by this verb's OWN membership test and not by cross's, and the row carries what it WOULD have answered so the refusal is a measurement and not a style rule: a period runs between two crossings of the SAME edge, so interleaving the two directions answers alternating HALF-periods -- dimensionally a frequency, oscillating, and DISTINCT from the rising answer element for element, which is why nothing downstream could have rejected it by inspection.  The refusal is compared BY IDENTITY against calc::cross_msg freqedge, is in the house shape, lives in a family calc::cross_msg really builds, and is NOT cross's own badedge sentence -- so a verb that passed edge straight through to cross reddens on the identity leg.  Widening the enum to three members would ship that oscillating number with no refusal anywhere" \
        [list [mt_disp $fqEI] \
              [string equal [mt_msg $fqEI] [pcall calc::cross_msg freqedge either]] \
              [mt_shape [mt_msg $fqEI]] \
              [mt_infamily [mt_msg $fqEI] [mt_crossmsg_families]] \
              [mt_notfamily [mt_msg $fqEI] [pcall calc::cross_msg badedge either]] \
              [mt_notfamily [mt_msg $fqEI] [pcall calc::cross_msg badcycle 1]] \
              [mt_atleast [llength $fqHALF] 3] \
              [mt_cmpword $fqHALF [mt_fq_fromx [mt_derive_x $fqT $fqSQ 0.5 rising]]] \
              [string equal [mt_msg [mt_call frequency {v(sq)} 0.5 sideways 0 0]] \
                            [pcall calc::cross_msg freqedge sideways]]] \
        [list refused 1 ok known elsewhere elsewhere atleast3 distinct 1]

    # --- J: THE NAMED CYCLE reads from either end ---------------------------
    check "MT15/J the named cycle reads from EITHER END and every ordinal is driven: 1, 2, 3 against the series and -1, -2, -3 against it reversed, each MEASURED, with the two ends shown to DISAGREE on the pair (+1, -1) so neither reading is satisfied by one value appearing twice.  An abs(cycle) implementation answers +1's number for -1 and reddens on that leg; an `end-\$want` off by one reddens on the sweep.  The sweep is a SCALAR in this shape and is the period's OPENING crossing, so the parallel-series invariant holds for the scalar case too, and BOTH of the two sites that can refuse an ordinal -- the non-integer one and the NON-FINITE one -- are driven against this verb's own arm by identity, which is a correction measured as a sabotage rather than reasoned: with only the non-integer site driven, a revision that reused Duty cycle's sentence at the other one passed this whole band" \
        [list [lsort -unique [lmap fqk [mt_seq 1 [llength $fqSER]] \
                   {mt_is [mt_call frequency $fqR 0.4 rising $fqk 0] \
                          [lindex $fqSER [expr {$fqk - 1}]]}]] \
              [lsort -unique [lmap fqk [mt_seq 1 [llength $fqSER]] \
                   {mt_is [mt_call frequency $fqR 0.4 rising [expr {-$fqk}] 0] \
                          [lindex $fqSER end-[expr {$fqk - 1}]]}]] \
              [lsort -unique [lmap fqk [mt_seq 1 [llength $fqSER]] \
                   {mt_disp [mt_call frequency $fqR 0.4 rising $fqk 0]}]] \
              [mt_distinct [mt_val [mt_call frequency $fqR 0.4 rising 1 0]] \
                           [mt_val [mt_call frequency $fqR 0.4 rising -1 0]]] \
              [near [mt_key [mt_call frequency $fqR 0.4 rising 2 0] sweep] \
                    [lindex [mt_fq_axis $fqX0 start] 1] $MTTOL] \
              [near [mt_key [mt_call frequency $fqR 0.4 rising -1 0] sweep] \
                    [lindex [mt_fq_axis $fqX0 start] end] $MTTOL] \
              [mt_atleast [llength $fqSER] 3] \
              [string equal [mt_msg [mt_call frequency $fqR 0.4 rising 1.5 0]] \
                            [pcall calc::cross_msg freqcycle 1.5]] \
              [string equal [mt_msg [mt_call frequency $fqR 0.4 rising abc 0]] \
                            [pcall calc::cross_msg freqcycle abc]] \
              [mt_disp [mt_call frequency $fqR 0.4 rising abc 0]] \
              [mt_disp [mt_call frequency $fqR 0.4 rising 3.0 0]]] \
        [list ok ok measured distinct ok ok atleast3 1 1 refused measured]

    # --- K: FEWER THAN TWO CROSSINGS IS AN ABSENCE, by BOTH routes ----------
    # ⚠⚠ `cross`'s `nth` 0 ANSWERS SUCCESS WITH AN EMPTY LIST for a level
    # nothing reaches, which is CROSS_CONTRACT T5's hazard, and that is
    # re-measured in this row rather than assumed: if that sibling behaviour ever
    # changed, the two non-vacuity legs would say so instead of the band quietly
    # measuring one route twice.
    set fqK1 [mt_call frequency {v(sq)} 99 rising 0 0]
    set fqK2 [mt_call frequency {v(ramp)} 0.5 rising 0 0]
    check "MT15/K fewer than two crossings is an ABSENCE and never a refusal and never a destination problem, reached by BOTH routes with ONE guard: a level no sample reaches, where cross answers SUCCESS WITH AN EMPTY LIST, and a MONOTONE column with exactly one crossing.  Both absent, both carrying noperiod by identity, neither in calc::wave_dest's destempty family -- asserted by FAMILY rather than by words -- and the SURFACE answers the same absence with no db key, so an implementation that handed the empty list to the destination builder would tell the user about a destination for a physical fact.  A guard that tested for fewer than ONE crossing rather than fewer than two passes the first route and divides by nothing on the second, which the two non-vacuity legs separate by reporting cross's own crossing count for each route" \
        [list [mt_disp $fqK1] [mt_disp $fqK2] \
              [string equal [mt_msg $fqK1] [pcall calc::cross_msg noperiod 99]] \
              [string equal [mt_msg $fqK2] [pcall calc::cross_msg noperiod 0.5]] \
              [mt_notfamily [mt_msg $fqK1] [pcall calc::cross_msg destempty]] \
              [mt_notfamily [mt_msg $fqK2] [pcall calc::cross_msg destempty]] \
              [mt_infamily [mt_msg $fqK1] [mt_crossmsg_families]] \
              [mt_len [mt_val [mt_call cross {v(sq)} 99 0 rising 0]]] \
              [mt_len [mt_val [mt_call cross {v(ramp)} 0.5 0 rising 0]]] \
              [mt_disp [set fqKS [mt_call frequency_scalar {v(sq)} 99 rising 0 0]]] \
              [mt_key $fqKS db] \
              [mt_notfamily [mt_msg $fqKS] [pcall calc::cross_msg destempty]]] \
        [list absent absent 1 1 elsewhere elsewhere known 0 1 absent NOKEY-db elsewhere]

    # --- L: THE OUT-OF-RANGE ORDINAL -----------------------------------------
    check "MT15/L an ordinal past the periods that exist is an ABSENCE NAMING THE ORDINAL, symmetric by construction because both ends reach it through calc::cross_absent: cycle 4 and cycle -4 on a three-period series are each absent and each carry noperiodat with calc::cross_ordinal's own spelling by identity, and the two sentences DIFFER from each other because naming the ordinal that was asked for is what tells a reader which end they counted from.  An lindex returning the empty string for an ordinal past the end would answer MEASURED with nothing in it, which the disposition legs catch; the series length rides along so the chosen ordinal really is past the end" \
        [list [mt_disp [set fqL1 [mt_call frequency $fqR 0.4 rising 4 0]]] \
              [mt_disp [set fqL2 [mt_call frequency $fqR 0.4 rising -4 0]]] \
              [string equal [mt_msg $fqL1] \
                   [pcall calc::cross_msg noperiodat [pcall calc::cross_ordinal 4]]] \
              [string equal [mt_msg $fqL2] \
                   [pcall calc::cross_msg noperiodat [pcall calc::cross_ordinal -4]]] \
              [expr {[mt_msg $fqL1] ne [mt_msg $fqL2] ? {named} : {SAME}}] \
              [mt_sized [llength $fqSER] 3] \
              [mt_infamily [mt_msg $fqL1] [mt_crossmsg_families]]] \
        [list absent absent 1 1 named sized known]

    # --- M: THE COMMITTED-COLUMN WITNESS -------------------------------------
    check "MT15/M the committed deck is a WITNESS and not only the synthetic train: v(lp) at 0.3, whose FIRST period carries the initial transient while its second is periodic steady state, answers two frequencies that agree element for element with this file's own D3+D4 over the committed column and whose adjacent pair is DISTINCT at MTTOL -- the only committed column in this deck that discriminates for this verb.  Limit F5 says this is a SINGLE derivation: v(lp)'s transient crossing times have no hand derivation in the data README, so unlike the train it is not derived twice" \
        [list [mt_islist [set fqM [mt_call frequency {v(lp)} 0.3 rising 0 0]] \
                         [mt_fq_fromx [mt_derive_x $fqT $fqLP 0.3 rising]]] \
              [mt_alldistinct [mt_val $fqM]] \
              [mt_sized [mt_len [mt_val $fqM]] \
                        [mt_nminus [mt_len [mt_val [mt_call cross {v(lp)} 0.3 0 rising 0]]] 1]] \
              [mt_allstrict $fqT $fqLP 0.3 rising]] \
        [list ok distinct sized strict]

    # --- N: THE CONTROL -- the BLIND column, driven BY NAME ------------------
    check "MT15/N CONTROL: v(sq) is BLIND for this verb at every level and is driven BY NAME so every `distinct` above is a MEASUREMENT OF THIS FIXTURE and not a constant.  The square's period is 4 ms by construction and does not move with the level, so its two frequencies agree to well inside MTTOL and the SAME instrument that answers `distinct` on the train answers `same` here -- at two levels, so it is not one reading.  A REVERSAL of this column's series is therefore INVISIBLE at MTTOL, which the row asserts positively rather than leaving to be inferred: that is issue 1643's defect in its own habitat, and it is why no value row in this band is driven here" \
        [list [mt_alldistinct [mt_val [set fqN [mt_call frequency {v(sq)} 0.5 rising 0 0]]]] \
              [mt_alldistinct [mt_val [mt_call frequency {v(sq)} 0.3 rising 0 0]]] \
              [mt_islist $fqN [mt_fq_fromx [mt_derive_x $fqT $fqSQ 0.5 rising]]] \
              [mt_notlist $fqN [lreverse [mt_fq_fromx [mt_derive_x $fqT $fqSQ 0.5 rising]]]] \
              [mt_alldistinct [mt_val $fqa]]] \
        [list same same ok same distinct]

    # --- O: THE ALIAS IS A PURE DELEGATE, pinned from the INTERPRETER --------
    # ⚠⚠ `info args` AND `info default`, NEVER A TEXT SCAN, and that choice is a
    # measured house lesson: five rounds of text-scanning legs on a sibling
    # signature pin were each defeated in turn -- a comment quoting the
    # signature, an unqualified callee, a backslash continuation -- while not one
    # `info args` leg was ever defeated by any sabotage derived against it.  The
    # text scan below is the WEAK half and says only that the second copy is
    # ABSENT; it runs over a DECOMMENTED body so a comment cannot satisfy it.
    set fqBADDEF {}
    foreach fqf [mt_formals frequency] {
        if {[ag_default frequency $fqf] ne [ag_default freq $fqf]} { lappend fqBADDEF $fqf }
    }
    foreach fqf [mt_formals frequency_scalar] {
        if {[ag_default frequency_scalar $fqf] ne [ag_default freq_scalar $fqf]} {
            lappend fqBADDEF scalar/$fqf
        }
    }
    check "MT15/O the alias is a PURE DELEGATE with no second copy of anything, pinned from the INTERPRETER and not from the text: info args of calc::freq equals calc::frequency's and info args of calc::freq_scalar equals calc::frequency_scalar's, compared in BOTH directions, and info default agrees for every formal that has one.  Then freq's decommented body carries no lsearch member list, no cross_msg and no reciprocal -- so the two enum member lists and the period formula exist exactly ONCE in the tree -- which is also why MT11 must lift freq's enum literals out of calc::frequency: ag_enum_in answers NOLITERAL on a pure delegate, and that is this claim seen from the other side.  A delegate that gains, loses or renames a formal reddens on the pin; one that re-validates with its own member list reddens on the scan" \
        [list [mt_sameformals [mt_formals freq] [mt_formals frequency]] \
              [mt_sameformals [mt_formals frequency] [mt_formals freq]] \
              [mt_sameformals [mt_formals freq_scalar] [mt_formals frequency_scalar]] \
              [mt_sameformals [mt_formals frequency_scalar] [mt_formals freq_scalar]] \
              $fqBADDEF \
              [mt_atleast [llength [mt_formals frequency]] 6] \
              [mt_fq_absent freq {lsearch -exact}] \
              [mt_fq_absent freq cross_msg] \
              [mt_fq_absent freq 1.0/] \
              [mt_fq_absent freq_scalar wave_dest] \
              [ag_enum_in freq edge] \
              [ag_enum_in frequency edge] \
              [ag_enum_in frequency xaxis] \
              [mt_surface freq] [mt_surface frequency]] \
        [list same same same same {} atleast6 absent absent absent absent \
              NOLITERAL:freq/edge {rising falling} {start number mid} \
              freq_scalar frequency_scalar]

    # --- P: THE ALIAS FORWARDS EVERY ARGUMENT -------------------------------
    # ⚠ EVERY FORMAL IS DRIVEN AWAY FROM ITS DEFAULT, because a delegate
    # forwarding FOUR of six arguments is silent: the late formals fall back to
    # their own defaults with no error and no refusal, just a different
    # measurement.  The non-vacuity leg beside it drops the last three arguments
    # and shows that the answer really does move.
    check "MT15/P the alias forwards EVERY argument, measured with every formal driven AWAY from its default -- falling, the last cycle, the second dataset and the mid axis -- and the two answers compared KEY BY KEY with the minted temporary excluded, because calc::tmpvec never re-uses a name and a different serial there is a property of the minter rather than a disagreement.  The non-vacuity leg drops the last three arguments and shows the answer really moves, so a four-of-six delegate cannot pass by the comparison being vacuous; the same comparison on the two surface wrappers rides along, and the composed call through calc::arg_values proves the alias is CLICKABLE rather than only callable" \
        [list [mt_fq_dictcmp [mt_call freq $fqR 0.4 falling -1 1 mid] \
                             [mt_call frequency $fqR 0.4 falling -1 1 mid]] \
              [mt_disp [mt_call freq $fqR 0.4 falling -1 1 mid]] \
              [expr {[mt_fq_dictcmp [mt_call freq $fqR 0.4 falling -1 1 mid] \
                             [mt_call freq $fqR 0.4 falling]] eq {same} ? {SAME} : {moves}}] \
              [mt_fq_dictcmp [mt_call freq_scalar $fqR 0.4 falling -1 1 mid] \
                             [mt_call frequency_scalar $fqR 0.4 falling -1 1 mid]] \
              [mt_islist [mt_call freq $fqR 0.4 rising 0 0 start] $fqSER] \
              [mt_argvals freq {v(sq) 2 *} \
                   [list level 0.4 edge falling xaxis mid cycle -1 dataset 1]]] \
        [list same measured moves same ok \
              {rpn {v(sq) 2 *} level 0.4 edge falling cycle -1 dataset 1 xaxis mid}]

    # --- Q: THE SURFACE sends the series to a registered destination ---------
    # ⚠⚠ BOTH COLUMNS ARE READ BACK AND NOT ONLY ROUTED, because
    # `calc::wave_dest {xs} {ys}` TAKES X FIRST and swapping the two is SILENT on
    # a same-length pair.  Band WD9 of tests/headless/test_calc_wave_dest.tcl
    # derives the caller sets and says nothing about which way round this one
    # hands its lists over.
    #
    # ⚠⚠ THE KEY SET BELOW IS ASSERTED **EXACTLY**, so a new key and the row that
    # expects it MUST LAND IN ONE COMMIT -- the same sequencing obligation band
    # MT14/L of this file states in full, and the same set.  An exact assertion is
    # the right shape, because it is what catches a wiring that puts a live value
    # in a retired key; what it costs is that a widening is not a free edit, and
    # whoever meets it as a gate red must widen the four sites rather than weaken
    # one row.
    set fqIV [mt_arginvoke frequency $fqR \
                  [list level 0.4 edge rising xaxis start cycle 0 dataset 0]]
    set fqDBX {} ; set fqDBY {} ; set fqDBN {}
    if {[pcall xschem raw switch [mt_key $fqIV db] table] eq {1}} {
        set fqDBN [pcall xschem raw points 0]
        set fqDBX [mt_col [mt_key $fqIV xname] 0]
        set fqDBY [mt_col [mt_key $fqIV yname] 0]
    }
    pcall xschem raw switch $::fixture tran
    check "MT15/Q R404/R421 the SURFACE routes the two shapes apart AND puts the series the right way round: the composed call at cycle 0 answers a DESTINATION and the same call at a named cycle answers the BUFFER, read off calc::fn_sink which is a pure proc with no Tk in it -- so the routing DECISION gates on the counted arm even though the ACT is display-only and limit F6 declares it.  Then BOTH columns are read back out of the registered database and compared element-wise against this file's own closed form, X against the period-opening crossings and Y against the frequencies, with the point count the derived series length and the two column names differing.  ⚠ THE KEY SET IS ASSERTED EXACTLY and `dest` must still hold the RETIRED __calc_tmp the measurement evaluated into while `db` holds the LIVE __calc_dest, because band MT9b reads `dest` BY NAME to tell a deferral from an absence; `shape wave` is a DECLARATION and never inferred from llength, since a legitimate one-period series is a length-1 list; and prev/prevtype are NOT merged, because they are the registry cursor calc::wave_dest_drop reads off its own answer.  This row drops the destination it built" \
        [list [mt_sink $fqIV] \
              [mt_sink [mt_arginvoke frequency $fqR \
                   [list level 0.4 edge rising xaxis start cycle -1 dataset 0]]] \
              [mt_destname [mt_key $fqIV db]] \
              [expr {[mt_key $fqIV xname] ne [mt_key $fqIV yname] ? {twonames} : {ONENAME}}] \
              [mt_sized $fqDBN [llength $fqSER]] \
              [mt_listcmp $fqDBX [mt_fq_axis $fqX0 start] 1e-12] \
              [mt_listcmp $fqDBY $fqSER] \
              [mt_key $fqIV shape] \
              [mt_keys $fqIV] \
              [mt_tmpname [mt_key $fqIV dest]] \
              [leaked]] \
        [list destination buffer named twonames sized ok ok wave \
              {absent dataset db dest msg n ok shape sweep type value xname yname} \
              tmp {}]
    pcall calc::wave_dest_drop $fqIV

    # --- R: ...AND THE NAMED CYCLE TAKES THE BUFFER ROUTE -------------------
    set fqIVS [mt_arginvoke freq $fqR \
                   [list level 0.4 edge rising xaxis start cycle -1 dataset 0]]
    set fqIVW [mt_arginvoke freq $fqR \
                   [list level 0.4 edge rising xaxis start cycle 0 dataset 0]]
    check "MT15/R ...and a named cycle takes the BUFFER route through the ALIAS as well as through the verb: no db key and no shape key, calc::fn_sink answering `buffer` for it against `destination` for the wave answer, and the value a finite number rather than a list.  A wrapper that built a destination for a scalar would paste nothing into the buffer and name a database instead, which is the one user-visible consequence this arm can see; that the buffer is really left alone is display-only and limit F6 declares it" \
        [list [mt_sink $fqIVS] [mt_key $fqIVS db] [mt_key $fqIVS shape] \
              [mt_finite [mt_val $fqIVS]] \
              [mt_is $fqIVS [lindex $fqSER end]] \
              [mt_sink $fqIVW] [mt_key $fqIVW shape] \
              [mt_destname [mt_key $fqIVW db]]] \
        [list buffer NOKEY-db NOKEY-shape 1 ok destination wave named]
    pcall calc::wave_dest_drop $fqIVW

    # --- S: R402, the band leaks nothing ------------------------------------
    check "MT15/S R402 the band left no __calc_tmp*, no __mt_* column and no probe proc behind -- the hygiene claim for an instrument that mints columns in the product's own inventory, and a row rather than a habit because MT10 and MT11 both derive over ::calc:: and would measure a leftover probe as a product proc" \
        [list [leaked] [probeleft] [info procs ::calc::__mt_*]] {{} {} {}}
    pcall xschem raw clear
}


# ---------------------------------------------------------------------------
# MT16's own instruments -- stage J unit J4, `calc::settlingTime`.
#
# ⚠ THE RECORDING STUB BELOW ANSWERS AN *ABSENCE* AND NOT A REFUSAL, WHICH IS
# WHY IT IS A SECOND INSTRUMENT RATHER THAN A SECOND CALL TO `mt_stub_run`.
# That proc's stub REFUSES, so a verb that forwards a refusal returns after the
# FIRST delegated call and the probe can only ever count one -- which is exactly
# what MT10's row measures and all it can measure.  This verb's defining
# property is that it makes FOUR calls, one per physical band-edge event, and
# that three of them coming back ABSENT is the common case rather than a
# failure.  An absenting stub is the only shape that can see all four.
#
# ⚠ THE STUB'S FORMALS ARE WRITTEN OUT AND THE ROW PINS `calc::cross`'s OWN WITH
# `info args`, so a signature change on the primitive reddens the row instead of
# silently making the recorder read the wrong positional argument.
set mt_st_log {}
proc mt_st_record {script} {
    if {[info commands ::calc::cross] eq {}} { return "NOPROC:calc::cross" }
    if {[info commands ::mt_st_keep] ne {}} { return STUBSLOTBUSY }
    rename ::calc::cross ::mt_st_keep
    proc ::calc::cross {rpn level nth edge {dataset 0}} {
        lappend ::mt_st_log [list $level $nth $edge $dataset]
        return [dict create ok 0 absent 1 value {} dataset $dataset \
                    dest __calc_tmp_mtst msg {Cross: MTSTUB found none.}]
    }
    set ::mt_st_log {}
    set rc [catch {uplevel 1 $script} r]
    catch {rename ::calc::cross {}}
    catch {rename ::mt_st_keep ::calc::cross}
    if {$rc != 0 && $rc != 2} { return "ERR:$r" }
    return $r
}
# one recorded (level, nth, edge) request named by the PHYSICAL EVENT it asks
# about, so the row compares four WORDS instead of four floating-point levels --
# `entlo` is an entry from below, `exitlo` a departure downwards, `enthi` an
# entry from above, `exithi` a departure upwards.  A level that is neither band
# edge, or an edge asked for in the other direction, answers its own sentinel
# rather than being silently binned.
proc mt_st_name {req lo hi} {
    if {[catch {lindex $req 0} L]} { return "NOTALIST:{$req}" }
    set nth  [mt_at $req 1]
    set edge [mt_at $req 2]
    set which OTHERLEVEL
    if {[near $L $lo 1e-12] eq {ok}} { set which lo }
    if {[near $L $hi 1e-12] eq {ok}} { set which hi }
    set e "UNEXPECTED($which/$edge)"
    switch -exact -- "$which/$edge" {
        lo/rising  { set e entlo }
        lo/falling { set e exitlo }
        hi/falling { set e enthi }
        hi/rising  { set e exithi }
    }
    return "$e@nth$nth"
}
proc mt_st_sig {log lo hi} {
    if {[regexp {^(NOPROC|ERR|STUBSLOTBUSY)} $log]} { return $log }
    if {[catch {llength $log}]} { return "NOTALIST:{$log}" }
    set out {}
    foreach req $log { lappend out [mt_st_name $req $lo $hi] }
    return $out
}
# the four delegated measurements as the verb makes them, driven HERE through
# the real `calc::cross`, so a row can say which physical events a configuration
# really has instead of claiming it in its name.  The disposition WORD per
# event, in the verb's own order.
proc mt_st_calls {rpn final tol {dataset 0}} {
    set w  [expr {double($tol)}]
    set lo [expr {double($final) - $w}]
    set hi [expr {double($final) + $w}]
    set out {}
    foreach {nm L edge} [list entlo $lo rising  exitlo $lo falling \
                              enthi $hi falling exithi $hi rising] {
        lappend out $nm [mt_disp [pcall calc::cross $rpn $L -1 $edge $dataset]]
    }
    return $out
}
# ...and the same as three counts, `m<n>/a<n>/r<n>`, so the row that proves an
# absence must not propagate can say HOW MANY came back absent without naming
# which.  A disposition that is none of the three is counted apart rather than
# folded in, because a sentinel folded into `a` would read as a measurement.
proc mt_st_counts {calls} {
    set m 0 ; set a 0 ; set r 0 ; set o 0
    if {[catch {llength $calls}]} { return "NOTALIST:{$calls}" }
    foreach {nm d} $calls {
        switch -exact -- $d {
            measured { incr m }
            absent   { incr a }
            refused  { incr r }
            default  { incr o }
        }
    }
    return "m$m/a$a/r$r/x$o"
}
# which ENTRY event a configuration's settling instant comes from, and either
# entry's instant on demand, both through the real `calc::cross` at row level.
# The ring band needs them because the cell where the HI-edge entry WINS while
# the LO-edge entry also exists is reached by no committed column.
proc mt_st_winner {rpn final tol {dataset 0}} {
    set w  [expr {double($tol)}]
    set best {} ; set wn none
    foreach {nm L edge} [list entlo [expr {double($final) - $w}] rising \
                              enthi [expr {double($final) + $w}] falling] {
        set a [pcall calc::cross $rpn $L -1 $edge $dataset]
        if {[mt_disp $a] ne {measured}} continue
        set x [mt_val $a]
        if {$best eq {} || $x > $best} { set best $x ; set wn $nm }
    }
    return $wn
}
proc mt_st_entry {rpn final tol which {dataset 0}} {
    set w [expr {double($tol)}]
    set L [expr {$which eq {entlo} ? double($final) - $w : double($final) + $w}]
    set e [expr {$which eq {entlo} ? {rising} : {falling}}]
    return [mt_val [pcall calc::cross $rpn $L -1 $e $dataset]]
}
# THIS FILE'S OWN WHOLE ALGORITHM over a bulk column, with no product proc in it
# at all: the last crossing of either band edge, which must be an ENTRY, minus
# the start reference.  Answers the DURATION for a settling trace and the
# disposition WORD for each of the three absences, so one instrument serves
# MT16/D's numeric sweep and MT16/I's dispositions.  `mt_derive_x` is this
# file's D3+D4.
proc mt_st_derive {xs ys final tol start} {
    if {![mt_finite $final] || ![mt_finite $tol] || ![mt_finite $start]} {
        return "NOTANUMBER:{$final}|{$tol}|{$start}"
    }
    set w [expr {double($tol)}]
    if {$w <= 0.0} { return "ZEROBAND:$tol" }
    set lo [expr {double($final) - $w}]
    set hi [expr {double($final) + $w}]
    set tent {} ; set tex {}
    foreach {nm L edge} [list entlo $lo rising  exitlo $lo falling \
                              enthi $hi falling exithi $hi rising] {
        set hits [mt_derive_x $xs $ys $L $edge]
        if {![llength $hits]} continue
        set x [lindex $hits end]
        if {$nm eq {entlo} || $nm eq {enthi}} {
            if {$tent eq {} || $x > $tent} { set tent $x }
        } else {
            if {$tex eq {} || $x > $tex} { set tex $x }
        }
    }
    if {$tent eq {} && $tex eq {}} { return nocross }
    if {$tent eq {} || ($tex ne {} && $tex >= $tent)} { return nosettle }
    if {$tent < double($start)} { return presettled }
    return [expr {$tent - double($start)}]
}
# every `calc::cross_msg` arm whose sentence is in one FAMILY, derived over the
# arm set the proc's own switch patterns give -- so this verb's eight new kinds
# are counted without one of their names being written down here.  A hand-kept
# list is the same defect one level up.
proc mt_st_famarms {fam} {
    set arms [mt_crossmsg_arms]
    if {[regexp {^(NOPROC|NOBODY):} $arms]} { return $arms }
    set out {}
    foreach a $arms {
        set s [pcall ::calc::cross_msg $a AAA BBB]
        if {[string match ERR:* $s]} { lappend out "ERR:$a" ; continue }
        if {[mt_family $s] eq $fam} { lappend out $a }
    }
    return [lsort $out]
}
# a difference that cannot RAISE on a sentinel, which is why it is a proc and
# not an `expr` at the row site: MT16/J subtracts the measured instant from a
# start reference, and on a tree with no verb the measured instant is the string
# `NOPROC:calc::settlingTime` -- a bare `expr` there ABANDONS the whole band
# through `group`'s catch instead of failing one row.  Measured on the red run.
proc mt_st_minus {a b} {
    if {![mt_finite $a] || ![mt_finite $b]} { return "NOTANUMBER:{$a}|{$b}" }
    return [expr {double($a) - double($b)}]
}
# `alldifferent` when no two members of a list are the same string, the list
# otherwise -- the claim MT16/I needs over three absence SENTENCES, where
# `mt_distinct` would be the wrong instrument because these are words and not
# numbers.
proc mt_st_alldiff {v} {
    if {[catch {llength $v} n]} { return "NOTALIST:{$v}" }
    if {$n < 2} { return "tooshort:$n" }
    if {[llength [lsort -unique $v]] == $n} { return alldifferent }
    return "dup:{$v}"
}
# THE MINTED RING, and the reason it exists: no committed column OVERSHOOTS, so
# on every committed settling configuration `enthi` and `exithi` are ABSENT and
# the hi-edge half of the verb does no work at all.  `1 - e^(-600 t) cos(w t)`
# overshoots, settles, and has all four events.  `w` is read back from the sweep
# column's OWN endpoints every run, so no period and no answer is written down
# anywhere -- `mt_ringw`'s discipline one verb up.
proc mt_st_ringrpn {xs} {
    set w [mt_ringw $xs 4]
    if {![mt_finite $w]} { return $w }
    return "1 time 600.0 * -1 * exp() time $w * cos() * -"
}
proc mt_st_ringcol {xs} {
    set w [mt_ringw $xs 4]
    if {![mt_finite $w]} { return $w }
    set out {}
    foreach t $xs {
        if {![mt_finite $t]} { return "NOTANUMBER:{$t}" }
        lappend out [expr {1.0 - exp(-600.0*double($t))*cos($w*double($t))}]
    }
    return $out
}

# ---------------------------------------------------------------------------
# MT16 -- STAGE J UNIT J4 / `calc::settlingTime`: THE TIME TAKEN TO SETTLE AND
# STAY INSIDE A BAND.
#
# Spec     doc/claude/specs/calculator.md section 7.2 -- the catalogue row
#          `{settlingTime {Special Functions} T scalar {} {Time taken to settle
#          and stay inside a band}}`, which already carries route T and
#          `returns scalar`, so nothing in the catalogue or in S24's closed
#          `returns` vocabulary moves for this verb.
# Contract doc/claude/calculator_batch/CROSS_CONTRACT.md D1-D12, inherited
#          whole: this verb owns no engine door and `calc::cross` keeps the
#          `raw loaded` gate, the dataset validation, the sweep-by-name
#          resolution, `calc::rpn_bad_token`, `calc::tmpvec` and R402's
#          unconditional cleanup.
#
# ⚠⚠ WRITTEN RED FIRST, BEFORE `calc::settlingTime` AND ITS ARGUMENT SPEC
# EXISTED.  Every behavioural row below failed when it was written, each naming
# `NOPROC:calc::settlingTime` or an empty spec rather than raising; the
# transcript is in the stage receipt.  A row written after the code has never
# been observed to fail and is unproven as a fence.
#
# WHAT THE QUANTITY IS.  The band is `[final-tol, final+tol]`.  A trace is
# settled from the moment after which it never again changes which side of
# either band edge it is on, given that it is then inside -- so the answer is
# the LAST crossing of either edge, which must be an ENTRY (rising through `lo`
# or falling through `hi`), minus the supplied `start` reference.  If that last
# crossing is an EXIT the trace ends outside the band and never settled in this
# sweep.
#
# ⚠ "THE LAST TIME THE WAVE LEAVES THE BAND" IS A DIFFERENT QUANTITY and was the
# reading this unit was first described with.  The last exit PRECEDES the last
# entry: on `v(lp)` with final 1 and tol 0.01 the two differ by a relative 0.37,
# and on `v(sq)` with `start` at the edge's own foot by a relative 15.  Band
# MT16/C catches that reading with a number.
#
# R415's DISPOSITION, WHICH IS WHY THERE ARE THREE REQUIRED FIELDS.  The user's
# own words about the swing were *"Cadence makes you supply them"*, and
# `calc::riseTime` contains no min/max search, no first/last-sample rule and no
# settled-value estimator for exactly that reason.  Inferring the final value
# from the trace is that estimator; inferring `start` from the sweep's first
# sample is the same guess about the other axis.  `ase::meas_templates`' `ts`
# template in src/ase.tcl -- THIS TREE'S OTHER SETTLING-TIME MEASUREMENT,
# commissioned by the same user -- asks for `final` and `tol` as two required
# real fields and computes `final-tol` / `final+tol`, so the two surfaces agree.
# There is also a structural reason: reading the trace's last sample means
# reading a column this verb did not create, which reddens MT10 and row SR5 of
# tests/headless/test_calc_scratch_reuse.tcl.
#
# NO `nth`.  "and stay" names the last event BY DEFINITION, so there is no
# occurrence to select -- which removes the whole `nth 0` family from this verb:
# no list case, no `listdefer`, no waveform destination and no `_scalar`
# wrapper.  MT16/L asserts the absence of the wrapper rather than leaving it as
# a fact about today's tree, because `calc::arg_surface` is literally *"if
# `::calc::<name>_scalar` exists, return it"* and minting one later silently
# redirects every click.
#
# ⚠⚠ THE ONE FINDING NOBODY MAY DROP: THE EXIT CHECK IS FENCED ONLY WHERE THE
# ANSWER IS AN ABSENCE, AND THAT IS A THEOREM RATHER THAN A FIXTURE SHORTFALL.
# On any trace that SETTLES, the last band-edge crossing IS the last entry -- so
# an implementation with no entry/exit test agrees with the correct one BIT FOR
# BIT on every configuration that measures a number, and both such wrong
# readings were BUILT and measured as identical on every measuring configuration
# this band drives.  No count of them is written here: it is a figure over this
# file's own text that no row recomputes, and the sibling figure in
# `calc::settlingTime`'s header disagreed with it.  They
# differ only where the truth is `nosettle`, and there they differ from each
# other too.  THE `nosettle` CONFIGURATIONS OF MT16/I ARE THEREFORE THE
# ONLY FENCE IN THE TREE ON THE DIFFERENCE BETWEEN "IT SETTLED" AND "IT RAN
# AWAY", which is the single thing a settling-time measurement is for.  Dropping
# any of them removes the only fence; no amount of extra numeric coverage can
# replace them.
#
# ⚠ AN ABSENCE FROM ONE DELEGATED CALL IS NORMAL AND MUST NOT PROPAGATE, which
# is this verb's one real divergence from `calc::riseTime`.  That proc writes
# `if {![dict get $a ok]} { return $a }` and so forwards an absence; here THREE
# of the four calls coming back absent is the common case -- `v(div)` with final
# 4.0 and tol 1.58 measures with exactly one of four -- so the test is on BOTH
# keys, `ok 0 && absent 0` being a refusal that returns unchanged and
# `ok 0 && absent 1` meaning that event does not occur.  This proc is the
# consumer row CX9 of tests/headless/test_calc_cross.tcl names in so many words.
#
# ⚠ ONE ROW HERE PASSES WITH NO FEATURE PRESENT and it is named rather than left
# for a reader to find: MT16/O, the R402 inventory, which is a claim about this
# band's own hygiene.  Individual non-vacuity LEGS pass on the featureless tree
# too, because they measure the FIXTURE and not the verb -- the per-event
# dispositions, the ring column's agreement with its Tcl reconstruction, and the
# two deck closed forms MT16/I's `nosettle` leg names.
#
# ⚠ A KEY AND THE ROW THAT ASSERTS ITS KEY SET LAND IN ONE COMMIT.  MT16/N
# asserts the answer's key set EXACTLY -- `{absent dataset dest msg ok value}`,
# `cross`'s own with `value` replaced -- so a future widening that gives this
# verb a `shape` or a `db` has to land its row in the same change or meet this
# as a gate red and be tempted to weaken it.
#
# ⚠ EVERY FIELD LABEL IS UNRATIFIED USER-VISIBLE TEXT.  `{Final value}` and
# `{Tolerance}` are ASE's `ts` labels copied verbatim so the two surfaces read
# the same; `{Start time}` is new.  The `rule` debt
# `calc_argdialog_field_labels_and_delay_second_signal` covers them, MT11 pins
# the strings in one row, and a green run here is not ratification.
#
# ⚠ FOUR OF THE FIVE REQUEST REFUSALS ARE SCRIPT-REACHABLE ONLY.
# `calc::arg_bad` validates every `real` field with `calc::eval_finite` before
# the verb is called and a `required 1` field cannot be left empty, so through
# the DIALOG `noband`, `nostart`, `badband` and `badstart` are unreachable --
# exactly as `riseTime`'s `noswing` is, which band MT3 drives by calling the
# proc directly.  They exist because R415's disposition says a malformed request
# is REFUSED and never thrown.  `zeroband` is the one a user reaches by filling
# in the form, so its wording is the one that matters.
#
# DECLARED LIMITS, each measured rather than assumed:
#
#  L1 "it was inside the band for the whole sweep" and "it never reached the
#     band" are INDISTINGUISHABLE from inside a pure delegate and both answer
#     `nocross`.  Telling them apart needs the value of one sample, i.e. an
#     engine door of this verb's own.  MT16/I drives BOTH configurations and
#     asserts they produce the same kind, so the limit is measured; the sentence
#     names both readings instead of guessing one.
#  L2 A PER-STEP settling series is not built.  With no `nth` a transient with
#     several steps gets one answer, the last settling event.  A per-step series
#     needs a step-detection rule nobody has ruled on and would make this verb a
#     wave producer with a wrapper and a `calc::wave_dest` caller.
#  L3 NO `ac` RESTRICTION.  `calc::cross` accepts `tran` and `ac` and refuses
#     everything else; this verb inherits that gate and adds nothing.  A
#     settling time on a frequency axis is meaningless and is not refused,
#     because `riseTime` and `dutyCycle` do not refuse it either and a
#     restriction one sibling has and two do not is worse for a user than the
#     meaningless answer.
#  L4 `start` IS NOT CHECKED AGAINST THE SWEEP'S OWN EXTENT, for L1's reason: a
#     `start` before the first sample or after the last is accepted.  A `start`
#     after the settling instant answers `presettled`; one before the sweep
#     answers a duration measured from outside it.  Both are arithmetic on
#     numbers the user supplied and R421's provenance line names the `start`
#     used.
#  L5 THE TIE RULE IS UNREACHABLE AND UNFENCED.  An exit and an entry at the
#     same instant reports `nosettle`, failing closed.  Two crossings cannot
#     share an instant -- within one sample pair two different levels interpolate
#     to two different x by construction -- so it is a declared belt and no row
#     forces it.
#  L6 THE DISPLAY HALF IS NOT MEASURED HERE.  The answer is a scalar, so
#     `calc::fn_measure` routes it through `calc::buf_set_number`, which returns
#     early on `calc::has_win .calc.buf`.  That the number really lands in the
#     buffer, that the provenance sentence really reaches `.calc.status.msg` and
#     that one undo restores the user's expression belong to band S28 of
#     tests/headless/test_calc_skeleton.tcl, `dcases` ALONE.  The DECISION --
#     `calc::fn_sink` answering `buffer` for this verb's real answer -- is on the
#     counted arm, as MT16/N.  Decision versus act, split where the house splits
#     it, and on a decision-only tree the verb still behaves correctly because
#     `fn_sink`'s ladder fails closed and a scalar is the one shape it already
#     routes.
#  L7 COST: four RPN evaluations and eight bulk column reads per measurement,
#     against `riseTime`'s two of each.  Unmeasurable on the 101-point fixture.
#     Accepted rather than optimised: a three-call variant needs a second arm
#     chosen BY THE DATA, and a branch whose arm depends on the data is the shape
#     that leaves one leg unfenced.
#  L8 THE RING OF MT16/M IS A MINTED FIXTURE, not part of the committed fixture
#     contract in tests/headless/data/README.md.  Its `w` follows the sweep
#     column's own endpoints and every asserted value is re-derived each run,
#     which is why no ring number appears in any comment.
# =========================================================================
group MT16 {
    pcall mt_load tran
    set stT  [mt_col time 0]
    set stSQ [mt_col v(sq) 0]
    set stLP [mt_col v(lp) 0]

    # --- A: FOUR delegated calls, one per named physical event, in order ----
    # ⚠ THE ORDER IS ASSERTED and it is load-bearing for exactly one thing: an
    # ABSENCE carries the `dataset` and `dest` of the LAST of the four, so
    # reordering them would change which retired temporary an absent answer
    # names.  Nothing else in the verb depends on it.
    set stLO [expr {1.0 - 0.01}] ; set stHI [expr {1.0 + 0.01}]
    set stREC [mt_st_record {
        set a [mt_call settlingTime {v(lp)} 1 0.01 0]
        return [list [mt_st_sig $::mt_st_log $stLO $stHI] [mt_disp $a]]
    }]
    check "MT16/A the verb issues EXACTLY four delegated calc::cross calls, one per NAMED physical band-edge event, each at nth -1 -- measured through a stub that ANSWERS AN ABSENCE rather than a refusal, which is the only shape that can see all four, since MT10's refusing stub returns after the first.  The requests are named by matching their levels against final-tol and final+tol, so no level is written down; a verb that read only the lo edge, swapped lo and hi, asked `rising` for the hi-edge entry, used nth 0, or made three data-dependent calls prints a different four-word list.  With every event absent the answer is an ABSENCE and not a refusal, which is the disposition the whole band hangs on" \
        [list [mt_at $stREC 0] [mt_at $stREC 1] \
              [info args ::calc::cross] [llength [info commands ::mt_st_keep]]] \
        [list {entlo@nth-1 exitlo@nth-1 enthi@nth-1 exithi@nth-1} absent \
              {rpn level nth edge dataset} 0]
    check "MT16/A ...and ::calc::cross is RESTORED by that probe and measures again, so no row below is reading a stubbed namespace -- the control that stops the row above being satisfiable by a probe that never put the real proc back" \
        [list [mt_disp [set stA [mt_call cross {v(sq)} 0.5 1 rising]]] \
              [near [mt_val $stA] [sq_rise 0.5 0] $MTTOL]] {measured ok}

    # --- B: the signature pinned with `info args` and `info default` ---------
    # ⚠ `info args` AND NEVER A TEXT SCAN.  Five text-scanning legs on a sibling
    # signature pin were each defeated in turn -- a comment copy quoting the
    # signature, an unqualified callee, a backslash continuation -- while not one
    # `info args` leg was defeated by any of the 43 derived sabotages there.
    # `info args` reports NAMES ONLY and cannot see a default, which is its own
    # trap, so `info default` rides along per formal.
    set stDEF {}
    foreach stF [mt_formals [mt_surface settlingTime]] {
        set stV {}
        if {[catch {info default ::calc::[mt_surface settlingTime] $stF stV} stH]} {
            lappend stDEF "RAISED:$stF" ; continue
        }
        if {$stH} { lappend stDEF "dflt:$stV" } else { lappend stDEF NODEFAULT }
    }
    set stKNF {}
    foreach stR [pcall calc::fn_argspec settlingTime] {
        set stK [mt_at $stR 0]
        if {[lsearch -exact [mt_formals [mt_surface settlingTime]] $stK] < 0} {
            lappend stKNF $stK=not-a-formal
        }
    }
    check "MT16/B the argument list is pinned with `info args` and its defaults with `info default`, and every spec key is a FORMAL -- so a mandatory positional formal (a Tcl ARITY THROW where R415 demands a refusal), a renamed key, or a lost {} default reddens here.  `final`, `tol` and `start` are required 1 in the SPEC and optional with an EMPTY default as Tcl formals, which is riseTime's split and is what makes an omitted field a REFUSAL instead of a throw.  The non-vacuity legs: a key the spec does not name answers TRUNCATED-BEFORE from arg_values, and a verb with no proc answers NOPROC" \
        [list [mt_formals [mt_surface settlingTime]] $stDEF $stKNF \
              [mt_argval_of settlingTime {v(lp)} \
                   {final 1 tol 0.01 start 0 dataset 0} start] \
              [mt_argval_of settlingTime {v(lp)} \
                   {final 1 tol 0.01 start 0 dataset 0} __mt_nokey__] \
              [mt_formals __mt_nosuchverb__]] \
        [list {rpn final tol start dataset} \
              {NODEFAULT dflt: dflt: dflt: dflt:0} {} 0 \
              TRUNCATED-BEFORE:__mt_nokey__ NOPROC:calc::__mt_nosuchverb__]

    # --- C: the deck's own closed form, swept over tol, pairs measured -------
    # The closed form is this file's shipped `sq_rise`: the band's lower edge is
    # `1 - tol`, `v(sq)`'s third rising edge is linear, and the last entry is
    # where it crosses that edge.  The `start` leg shifts the same series by the
    # edge's own foot, which is what catches an implementation that forgets to
    # subtract the reference at all.
    set stTOLS {0.1 0.05 0.02 0.01 0.005 0.002}
    set stCDECK {} ; set stCGOT {} ; set stCGOT2 {} ; set stCDECK2 {}
    foreach stTt $stTOLS {
        lappend stCDECK  [sq_rise [expr {1.0 - $stTt}] 2]
        lappend stCDECK2 [expr {[sq_rise [expr {1.0 - $stTt}] 2] - 8.9e-3}]
        lappend stCGOT   [mt_val [mt_call settlingTime {v(sq)} 1 $stTt 0]]
        lappend stCGOT2  [mt_val [mt_call settlingTime {v(sq)} 1 $stTt 8.9e-3]]
    }
    check "MT16/C the deck's own closed form, swept over SIX tolerances, element for element, at start 0 and again at start 8.9e-3 -- with the ADJACENT-PAIR spread of the compared series carried in the row rather than its range, because the range is the wrong statistic: every neighbour must differ by more than MTTOL for the comparison to mean anything.  This is the row that catches a verb ignoring `tol` and crossing `final` itself, reading `tol` as a PERCENT, forgetting to subtract `start`, taking the FIRST entry instead of the last, and taking the last EXIT -- the reading this unit was first described with" \
        [list [mt_listcmp $stCGOT $stCDECK] [mt_alldistinct $stCGOT] \
              [mt_listcmp $stCGOT2 $stCDECK2] [mt_alldistinct $stCGOT2] \
              [mt_cmpword $stCGOT $stCDECK2]] \
        {ok distinct ok distinct distinct}

    # --- D: the same sweep taken from the COLUMN, not from the deck ----------
    set stDTOLS {0.05 0.03 0.02 0.01 0.005 0.003 0.002}
    set stDGOT {} ; set stDEXP {}
    foreach stTt $stDTOLS {
        lappend stDEXP [mt_st_derive $stT $stLP 1 $stTt 0]
        lappend stDGOT [mt_val [mt_call settlingTime {v(lp)} 1 $stTt 0]]
    }
    set stD001 [mt_call settlingTime {v(lp)} 1 0.001 0]
    check "MT16/D the same claim through a SECOND INSTRUMENT CLASS: the physical pole's column, with the whole algorithm re-derived in this file over the bulk %.16g samples and no product proc anywhere in the expectation -- so a change in how `cross` interpolates shows up here as a disagreement rather than as two numbers wrong in the same direction.  Seven tolerances, every adjacent pair distinct, and the eighth tolerance is the one the trace CANNOT satisfy: v(lp) tops out short of 1 - 0.001, so it answers an ABSENCE whose sentence is cross_msg's own nosettle arm by IDENTITY, and this file's own derivation agrees on that word too" \
        [list [mt_listcmp $stDGOT $stDEXP] [mt_alldistinct $stDGOT] \
              [mt_disp $stD001] \
              [string equal [mt_msg $stD001] [pcall calc::cross_msg nosettle]] \
              [mt_st_derive $stT $stLP 1 0.001 0]] \
        {ok distinct absent 1 nosettle}

    # --- E: the inversion identity, with the WINNING EVENT swapping ----------
    # ⚠ WITHOUT THIS ROW THE HI-EDGE HALF OF THE VERB IS FENCED BY NOTHING on
    # any committed column that measures: `v(lp)` and `v(sq)` never overshoot, so
    # `enthi` and `exithi` are ABSENT on every committed settling configuration.
    # The inversion reaches the same physical instant through the OTHER edge.
    set stEGOT {} ; set stEINV {} ; set stESAME {}
    foreach stTt {0.05 0.01} {
        set stEa [mt_val [mt_call settlingTime {v(lp)} 1 $stTt 0]]
        set stEb [mt_val [mt_call settlingTime {1 v(lp) -} 0 $stTt 0]]
        lappend stEGOT $stEa ; lappend stEINV $stEb
        lappend stESAME [mt_distinct $stEa $stEb]
    }
    check "MT16/E THE INVERSION IDENTITY, and the non-vacuity leg is the point of the row: `settlingTime v(lp) 1 tol` and `settlingTime {1 v(lp) -} 0 tol` must be the SAME instant, while the four delegated calls show that the plain column reaches it through the LO-edge entry with both hi-edge events ABSENT and the inverted column reaches it through the HI-edge entry with both lo-edge events absent.  So the identity is two different code paths agreeing and not one path called twice -- which is what makes it a fence on the `hi -1 falling` call, on a lo/hi swap, and on using `rising` for the hi-edge entry.  The suite already uses this idiom for `delay`'s side B" \
        [list $stESAME \
              [mt_st_calls {v(lp)} 1 0.05] [mt_st_calls {1 v(lp) -} 0 0.05] \
              [mt_st_winner {v(lp)} 1 0.05] [mt_st_winner {1 v(lp) -} 0 0.05] \
              [mt_alldistinct $stEGOT]] \
        [list {same same} \
              {entlo measured exitlo measured enthi absent exithi absent} \
              {entlo absent exitlo absent enthi measured exithi measured} \
              entlo enthi distinct]

    # --- F: three of four come back ABSENT and the answer is still a number --
    # ⚠ `v(lp)` CANNOT BE THE DATASET ROW: it is bytewise identical in both
    # datasets, because the deck `alter`s `rtop`, which sits in the ramp->div
    # divider and not in the rlp/clp pole.  `v(div)` is `v(ramp)/2` in dataset 0
    # and `v(ramp)/4` in dataset 1, so the two answers differ by exactly a factor
    # of two -- a relative spread of 1.0, which `mt_distinct` re-measures.  The
    # level 2.42 is deliberately not a multiple of the 0.05 grid, so neither
    # crossing lands on a sample.
    set stF0 [mt_call settlingTime {v(div)} 4.0 1.58 0 0]
    set stF1 [mt_call settlingTime {v(div)} 4.0 1.58 0 1]
    check "MT16/F THREE of the four delegated measurements come back ABSENT and the verb still answers a NUMBER, which is this verb's one real divergence from riseTime: a riseTime-style guard that returns the delegated answer whenever its `ok` key is false forwards the absence and turns a measuring configuration into an absent one.  THAT 3-of-4 SPLIT IS THE LEG AND NOT A REMARK -- `mt_st_counts` re-derives measured/absent/refused per dataset every run, which is why this name carries that ratio and no count of how many of the band's own configurations a wrong guard would break: nothing re-measures the latter.  The two answers are checked against the divider's own deck relation and their relative spread is re-measured as `distinct` so the dataset really reached the data.  ⚠ This is the consumer row CX9 of test_calc_cross.tcl was written in anticipation of -- the refused-versus-absent split finally has one" \
        [list [mt_st_counts [mt_st_calls {v(div)} 4.0 1.58 0]] \
              [mt_st_counts [mt_st_calls {v(div)} 4.0 1.58 1]] \
              [mt_is $stF0 [div_t 2.42 0]] [mt_is $stF1 [div_t 2.42 1]] \
              [mt_distinct [mt_val $stF0] [mt_val $stF1]] \
              [mt_key $stF0 dataset] [mt_key $stF1 dataset]] \
        {m1/a3/r0/x0 m1/a3/r0/x0 ok ok distinct 0 1}

    # --- G: a refusal from any delegated call propagates by IDENTITY ---------
    set stG7 [mt_call settlingTime {v(lp)} 1 0.01 0 7]
    set stGT [mt_call settlingTime {v(nosuch)} 1 0.01 0]
    check "MT16/G a REFUSAL from a delegated call propagates BY IDENTITY and is never re-worded or re-classified: an out-of-range dataset and an unknown token both come back `refused` carrying calc::cross's own sentence, compared with `string equal` against cross_msg's arms with the dataset COUNT read off the database rather than written here.  The counts leg shows all four calls refuse, and the CONTROL is the same configuration at dataset 0, which measures -- without it the row would be green over a verb that refused everything" \
        [list [mt_disp $stG7] \
              [string equal [mt_msg $stG7] \
                   [pcall calc::cross_msg dataset 7 [pcall xschem raw datasets]]] \
              [mt_disp $stGT] \
              [string equal [mt_msg $stGT] \
                   [pcall calc::cross_msg badtoken \
                        [pcall calc::rpn_bad_token {v(nosuch)}]]] \
              [mt_st_counts [mt_st_calls {v(lp)} 1 0.01 7]] \
              [mt_disp [mt_call settlingTime {v(lp)} 1 0.01 0 0]]] \
        {refused 1 refused 1 m0/a0/r4/x0 measured}

    # --- H: the request refusals happen with NO DATABASE LOADED at all -------
    # MT3's method for `noswing`, lifted.  The NON-VACUITY leg is what makes it
    # a measurement of the GATE ORDER rather than of the fact that nothing reads:
    # with every field well formed and no database loaded the answer IS `nodata`.
    pcall xschem raw clear
    set stHBAD {} ; set stHN 0
    foreach {stHf stHt stHs} [list {} 0.01 0   1 {} 0   1 0.01 {} \
                                   nan 0.01 0  1 nan 0   1 0.01 nan \
                                   1 0 0        1 -1 0] {
        incr stHN
        set stHa [mt_call settlingTime {v(lp)} $stHf $stHt $stHs]
        if {[mt_disp $stHa] ne {refused}} {
            lappend stHBAD "($stHf,$stHt,$stHs)=[mt_disp $stHa]" ; continue
        }
        if {[mt_shape [mt_msg $stHa]] ne {ok}} {
            lappend stHBAD "($stHf,$stHt,$stHs)=shape"
        }
        if {[string equal [mt_msg $stHa] [pcall calc::cross_msg nodata]]} {
            lappend stHBAD "($stHf,$stHt,$stHs)=NODATA"
        }
    }
    set stHOK [mt_call settlingTime {v(lp)} 1 0.01 0]
    check "MT16/H every REQUEST refusal happens before anything reaches the database, measured with the database CLEARED: a blank final, a blank tolerance, a blank start, a non-finite value in each of the three, and a zero and a negative tolerance all answer `refused` with their own sentence in the house shape and NOT with cross's `nodata`.  A verb that validated after its first delegated call tells the user there is no simulation data when their actual mistake was a blank tolerance.  The NON-VACUITY leg is the gate order itself: with every field well formed and no database loaded the answer IS nodata, carried by identity" \
        [list [mt_atleast $stHN 8] $stHBAD [mt_disp $stHOK] \
              [string equal [mt_msg $stHOK] [pcall calc::cross_msg nodata]]] \
        {atleast8 {} refused 1}
    pcall mt_load tran

    # --- I: every absence kind on a real column, the three kinds DISTINCT ----
    # ⚠⚠ THE THREE `nosettle` CONFIGURATIONS BELOW ARE THE ONLY FENCE IN THE
    # TREE ON THE ENTRY/EXIT TEST, for the structural reason in this band's
    # header: on every trace that settles, an implementation with no exit check
    # agrees with the correct one BIT FOR BIT.  Dropping one of them removes the
    # only fence on the difference between "it settled" and "it ran away".
    #
    # ⚠ THE `nosettle` NON-VACUITY LEG IS THE ONE THAT MATTERS.  Without it the
    # word could be satisfied by a verb that never settles anything, so the row
    # names the two DECK closed forms the two wrong readings answer on
    # `v(sq)` with final 0: the last ENTRY is `sq_fall 0.01 1` and the last EXIT
    # is `sq_rise 0.01 2`, and they must be `mt_distinct`.
    set stIa [mt_call settlingTime {v(dcmid)} 3 1e-9 0]
    set stIb [mt_call settlingTime {v(lp)} 5 0.1 0]
    set stIc [mt_call settlingTime {v(ramp)} 5 0.1 0]
    set stId [mt_call settlingTime {v(sq)} 0 0.01 0]
    set stIe [mt_call settlingTime {v(lp)} 1 0.001 0]
    set stIf [mt_call settlingTime {v(lp)} 1 0.01 9.75e-3]
    set stIg [mt_call settlingTime {v(dcmid)} 3 1e-12 0]
    check "MT16/I every absence kind is reached on a REAL column and the three kinds are DISTINCT sentences: `nocross` twice, on a trace that never leaves the band and on a band the trace never reaches -- the same kind for opposite physical reasons, which is limit L1 measured rather than asserted -- `nosettle` on THREE configurations, and `presettled` on one.  Each is `absent` and not `refused`, because the request is well formed and this sweep simply has no answer; each sentence is in the house shape; and the three are pairwise different strings so a kind collapsed onto another reddens.  The controls: v(dcmid) at a tighter band MEASURES, so `nocross` is a property of the band and not of the column; and the two deck closed forms the two no-exit-check readings would answer on v(sq) are distinct, so `nosettle` cannot be satisfied by a verb that settles nothing" \
        [list [mt_disp $stIa] [mt_disp $stIb] [mt_disp $stIc] [mt_disp $stId] \
              [mt_disp $stIe] [mt_disp $stIf] [mt_disp $stIg] \
              [mt_st_alldiff [list [mt_msg $stIa] [mt_msg $stIc] [mt_msg $stIf]]] \
              [string equal [mt_msg $stIa] [mt_msg $stIb]] \
              [mt_shape [mt_msg $stIa]] [mt_shape [mt_msg $stIc]] \
              [mt_shape [mt_msg $stIf]] \
              [mt_distinct [sq_fall 0.01 1] [sq_rise 0.01 2]] \
              [mt_st_derive $stT $stSQ 0 0.01 0] \
              [mt_st_derive $stT $stLP 5 0.1 0]] \
        [list absent absent absent absent absent absent measured \
              alldifferent 1 ok ok ok distinct nosettle nocross]

    # --- J: the `presettled` boundary is the MEASURED instant ----------------
    set stJT [mt_val [mt_call settlingTime {v(lp)} 1 0.01 0]]
    set stJ1 [mt_call settlingTime {v(lp)} 1 0.01 9.7e-3]
    set stJ2 [mt_call settlingTime {v(lp)} 1 0.01 $stJT]
    check "MT16/J the presettled boundary is the instant the SAME call measures and not a constant: a start just inside it answers a duration that equals the measured instant minus that start, a start just outside it answers `presettled`, and a start AT the instant exactly answers a measured ZERO -- which is the `<` and not `<=` leg, and the reason the disposition is an absence rather than a negative number.  `start` is an ORIGIN and not a second measurement, so a negative duration from it would say the request named the wrong window; delay's negative answer is a different thing, two independent edges in order" \
        [list [mt_disp $stJ1] [near [mt_val $stJ1] [mt_st_minus $stJT 9.7e-3] $MTTOL] \
              [mt_disp [mt_call settlingTime {v(lp)} 1 0.01 9.75e-3]] \
              [mt_disp $stJ2] [near [mt_val $stJ2] 0 $MTTOL] \
              [mt_distinct $stJT 9.7e-3]] \
        {measured ok absent measured ok distinct}

    # --- K: cross_msg still parses, with the arm set DERIVED -----------------
    # ⚠ A comment between two switch patterns is PARITY-DEPENDENT and invisible
    # to `info complete` and to a brace scan: an EVEN word count re-pairs the
    # trailing list into a silent no-op and an ODD one makes Tcl raise out of
    # EVERY arm.  A green run proves only that the word count is even, so the
    # confirmation has to DRIVE every arm, with the arm set derived from the
    # proc's own switch argument.  MT14/Q does the parse-agreement half for this
    # proc; this row owns the family half for the eight arms this unit adds, as a
    # RATCHET floor rather than a count, and asserts that every refusal and
    # absence the verb really produces is in that family.
    set stKF [mt_st_famarms {Settling time}]
    set stKBAD {}
    foreach stKa $stKF {
        set stKs [pcall ::calc::cross_msg $stKa AAA BBB]
        if {[string match ERR:* $stKs]} { lappend stKBAD "$stKa:RAISED" ; continue }
        if {$stKs eq {}} { lappend stKBAD "$stKa:EMPTY" ; continue }
        if {[mt_shape $stKs] ne {ok}} { lappend stKBAD "$stKa:[mt_shape $stKs]" }
    }
    set stKMINE {}
    foreach stKa [list $stIa $stIc $stIf $stG7 \
                       [mt_call settlingTime {v(lp)} {} 0.01 0] \
                       [mt_call settlingTime {v(lp)} 1 0 0]] {
        lappend stKMINE [mt_infamily [mt_msg $stKa] [mt_crossmsg_families]]
    }
    check "MT16/K calc::cross_msg still parses and the eight arms this unit adds are really there, with the arm set DERIVED from the proc's own switch patterns and the family derived from the sentences -- never a list of kind names written here, which is the hand-kept-list defect one level up.  The floor over the `Settling time` family is a RATCHET and not a baseline; every derived arm answers a non-empty sentence in the house shape without raising; and every sentence the verb itself produces is in a family this proc really builds, which is the leg that catches an arm reached through a kind nobody added.  ⚠ cross's OWN refusal is deliberately in cross's family and not in this one, which is what propagation BY IDENTITY means" \
        [list [mt_atleast [llength $stKF] 8] $stKBAD $stKMINE \
              [mt_infamily [mt_msg $stG7] [mt_crossmsg_families]] \
              [mt_family [mt_msg $stIc]] [mt_family [mt_msg $stG7]]] \
        [list atleast8 {} [lrepeat 6 known] known {Settling time} Cross]

    # --- L: NO `_scalar` wrapper, so the click reaches the verb ---------------
    check "MT16/L there is NO settlingTime_scalar and that is a decision rather than an omission: with no `nth` the verb's only success shape is one number, so calc::arg_surface answers the verb itself, the click reaches it, and calc::fn_sink reads the default scalar and routes to the buffer.  ⚠ MINTING A WRAPPER LATER SILENTLY REDIRECTS EVERY CLICK -- arg_surface is literally if `::calc::<name>_scalar` exists return it, not opt-in -- so the absence is asserted rather than left as a fact about today's tree, and a future widening that gives this verb a wave shape has to land its wrapper, its formals and its rows in one commit.  The CONTROL is riseTime, which DOES have one, so the row is a claim about this verb and not about the proc.  ⚠ THE `present` LEG IS NOT DECORATION: without it this row is green on a tree with NO verb at all, because a wrapper nobody wrote is absent either way -- measured on the red run, where it was the one behavioural row here that passed over a sentinel" \
        [list [llength [info procs ::calc::settlingTime]] \
              [mt_surface settlingTime] \
              [llength [info procs ::calc::settlingTime_scalar]] \
              [mt_surface riseTime] [mt_surface dutyCycle]] \
        {1 settlingTime 0 riseTime_scalar dutyCycle_scalar}

    # --- M: the RING -- the only configuration where all four events exist ---
    set stRR  [mt_st_ringrpn $stT]
    set stRC  [mt_st_ringcol $stT]
    set stREN [mt_addcol __mt_st_ring $stRR 0]
    set stRTOLS {0.1 0.05 0.03 0.02 0.01}
    set stRGOT {} ; set stREXP {} ; set stRW {} ; set stRHI {}
    foreach stTt $stRTOLS {
        lappend stRGOT [mt_val [mt_call settlingTime $stRR 1 $stTt 0]]
        lappend stREXP [mt_st_derive $stT $stRC 1 $stTt 0]
        set stRwn [mt_st_winner $stRR 1 $stTt]
        lappend stRW $stRwn
        if {$stRwn eq {enthi} && $stRHI eq {}} { set stRHI $stTt }
    }
    set stRHIok [expr {$stRHI ne {} ? {reached} : {NOHIWIN}}]
    if {$stRHI eq {}} { set stRHI 0.02 }
    check "MT16/M THE MINTED RING, which is the only configuration in the tree where all four band-edge events EXIST and the HI-EDGE entry WINS: no committed column overshoots, so on every committed settling configuration enthi and exithi are absent and the hi-edge half of the verb does no work.  The column is `1 - e^(-600 t) cos(w t)` with w read back from the sweep column's OWN endpoints, so no period and no answer is written down; the engine's column is checked against a Tcl reconstruction, all four calls answer `ok` at the tolerance where the hi entry wins, the answers match this file's own derivation over five tolerances with every adjacent pair distinct, and the winner takes BOTH values across the sweep.  ⚠ At that tolerance the LO-edge entry also exists and is EARLIER, so a verb reading the lo edge only answers a confident WRONG NUMBER rather than a wrong disposition -- which is the cell no committed column can reach" \
        [list [pcall calc::rpn_bad_token $stRR] \
              [mt_listcmp $stREN $stRC 1e-12] \
              [mt_listcmp $stRGOT $stREXP] [mt_alldistinct $stRGOT] \
              [lsort -unique $stRW] \
              $stRHIok \
              [mt_st_counts [mt_st_calls $stRR 1 $stRHI]] \
              [mt_distinct [mt_st_entry $stRR 1 $stRHI entlo] \
                           [mt_val [mt_call settlingTime $stRR 1 $stRHI 0]]] \
              [expr {[mt_st_entry $stRR 1 $stRHI entlo] < \
                     [mt_st_entry $stRR 1 $stRHI enthi] ? {earlier} : {NOTEARLIER}}]] \
        [list {} ok ok distinct {enthi entlo} reached m4/a0/r0/x0 distinct earlier]

    # --- N: the answer is cross's own dict with `value` replaced -------------
    # ⚠ A KEY AND THE ROW THAT ASSERTS ITS KEY SET LAND IN ONE COMMIT.  The set
    # is asserted EXACTLY, which is what catches a wiring that puts a live value
    # in a retired key -- and it makes any future widening a SEQUENCING
    # obligation rather than a surprise gate red to be cleared by weakening this.
    set stN [mt_call settlingTime {v(lp)} 1 0.01 0 1]
    check "MT16/N the answer is cross's OWN dict with `value` replaced, propagated and never rebuilt: the key set is exactly {absent dataset dest msg ok value} -- no `shape`, no `sweep`, no `db` -- so calc::fn_sink reads the default scalar and answers `buffer`, and the number lands in the user's expression with arg_provenance's R421 sentence.  `dataset` is the one cross really read and `dest` still holds the retired __calc_tmp the measurement evaluated into, which band MT9b reads BY NAME to tell a deferral from an absence.  A rebuilt dict that dropped `absent` would make mt_disp answer NOKEY-absent and break the refused/absent split one layer up, and a declared `shape wave` would route a scalar into a destination" \
        [list [mt_keys $stN] [mt_sink $stN] [mt_key $stN dataset] \
              [mt_tmpname [mt_key $stN dest]] [mt_key $stN msg] \
              [mt_key $stN absent] [mt_finite [mt_val $stN]] \
              [mt_keys $stIc] [mt_tmpname [mt_key $stIc dest]]] \
        [list {absent dataset dest msg ok value} buffer 1 tmp {} 0 1 \
              {absent dataset dest msg ok value} tmp]

    # --- O: R402, the band leaks nothing ------------------------------------
    check "MT16/O R402 the band left no __calc_tmp*, no __mt_* column and no probe proc behind -- the hygiene claim for an instrument that mints a column in the product's own inventory, and a row rather than a habit because MT10 and MT11 both derive over ::calc:: and would measure a leftover probe as a product proc.  This is the ONE row here that is green with no feature present" \
        [list [leaked] [probeleft] [info procs ::calc::__mt_*] \
              [llength [info commands ::mt_st_keep]]] {{} {} {} 0}
    pcall xschem raw clear
}

# ---------------------------------------------------------------------------
# MT17's instruments.  THE EXTREMUM, DERIVED TWO WAYS WITH NO PRODUCT PROC IN
# EITHER, plus the shape of a probe column, the sign of an answer, and the
# UNGATED scan that is the other half of the finiteness-gate rows.
#
# ⚠⚠ THE FINITENESS GATE COMES FIRST IN BOTH DERIVATIONS, AND IN THE SORTING
# ONE IT IS NOT A BELT: `lsort -real` RAISES `floating point value is Not a
# Number` on a column that carries a `-nan`, measured on this fixture's own
# `{v(ramp) 5 - sqrt()}` and `{1000 exp()}` columns.  A derivation that sorted
# first would abort the band through `group`'s catch instead of failing a row.
# ---------------------------------------------------------------------------
proc mt_osh_scan {ys which} {
    if {[catch {llength $ys}]} { return "NOTALIST:{$ys}" }
    set e {}
    foreach y $ys {
        if {![mt_finite $y]} continue
        if {$e eq {}} { set e $y ; continue }
        if {$which eq {max}} {
            if {$y > $e} { set e $y }
        } else {
            if {$y < $e} { set e $y }
        }
    }
    if {$e eq {}} { return NOFINITE }
    return $e
}
proc mt_osh_sort {ys which} {
    if {[catch {llength $ys}]} { return "NOTALIST:{$ys}" }
    set f {}
    foreach y $ys { if {[mt_finite $y]} { lappend f $y } }
    if {![llength $f]} { return NOFINITE }
    if {[catch {lsort -real $f} s]} { return "RAISED:$s" }
    if {$which eq {max}} { return [lindex $s end] }
    return [lindex $s 0]
}
# the DIRECTION the supplied step names, as a word, so the direction row asserts
# the rule rather than a branch of the implementation.
proc mt_osh_which {initial final} {
    if {![mt_finite $initial] || ![mt_finite $final]} { return "NOTANUMBER:{$initial}|{$final}" }
    set sw [expr {double($final) - double($initial)}]
    if {$sw == 0.0} { return ZERO }
    return [expr {$sw > 0 ? {max} : {min}}]
}
# THE WHOLE QUANTITY, re-derived in this file: the column through this file's own
# `__mt_` door, the gated forward scan, and the arithmetic.  No `::calc::` proc
# appears in it, so a row comparing a verb's answer against this is comparing two
# instrument classes and not one implementation against itself.
proc mt_osh_ref {rpn initial final {dataset 0}} {
    set ys [mt_addcol __mt_osh $rpn $dataset]
    if {[string match ERR:* $ys]} { return $ys }
    set w [mt_osh_which $initial $final]
    if {$w ne {max} && $w ne {min}} { return $w }
    set e [mt_osh_scan $ys $w]
    if {![mt_finite $e]} { return $e }
    return [expr {100.0*(double($e) - double($final))/(double($final) - double($initial))}]
}
# ...and the WRONG readings, built FROM the same column so they cannot drift
# away from the correct one.  `which` is forced rather than derived for the two
# direction sabotages; `mode` names the arithmetic sabotages.
proc mt_osh_wrong {rpn initial final dataset mode} {
    set ys [mt_addcol __mt_osh $rpn $dataset]
    if {[string match ERR:* $ys]} { return $ys }
    set sw [expr {double($final) - double($initial)}]
    if {$sw == 0.0} { return ZERO }
    set w [expr {$sw > 0 ? {max} : {min}}]
    switch -exact -- $mode {
        alwaysmax { set w max }
        alwaysmin { set w min }
    }
    set e [mt_osh_scan $ys $w]
    if {![mt_finite $e]} { return $e }
    switch -exact -- $mode {
        fraction  { return [expr {1.0*(double($e) - double($final))/$sw}] }
        divfinal  { return [expr {100.0*(double($e) - double($final))/double($final)}] }
        divinit   { return [expr {100.0*(double($e) - double($final))/double($initial)}] }
        lastsample { return [expr {100.0*(double($e) - double([lindex $ys end]))/$sw}] }
    }
    return [expr {100.0*(double($e) - double($final))/$sw}]
}
# THE UNGATED SCAN, which is what the two gate rows measure the product against:
# it either RAISES -- because a non-finite SEED survives every comparison and
# then meets the subtraction -- or answers a non-finite number, and both are a
# throw or a shrug where D7 requires an answer.  Answers a WORD, so no engine
# spelling of an infinity lands in a row's expectation.
proc mt_osh_ungated {ys initial final} {
    set sw [expr {double($final) - double($initial)}]
    set which [expr {$sw > 0 ? {max} : {min}}]
    set e {}
    set c 0
    foreach y $ys {
        if {$e eq {}} { set e $y ; continue }
        if {$which eq {max}} {
            if {[catch {expr {$y > $e}} c]} { return "RAISED:$c" }
        } else {
            if {[catch {expr {$y < $e}} c]} { return "RAISED:$c" }
        }
        if {$c} { set e $y }
    }
    if {$e eq {}} { return NOSAMPLES }
    if {[catch {expr {100.0*(double($e) - double($final))/$sw}} v]} { return "RAISED:$v" }
    return $v
}
proc mt_osh_ungated_word {ys initial final} {
    set v [mt_osh_ungated $ys $initial $final]
    if {[string match RAISED:* $v]} { return raises }
    if {$v eq {NOSAMPLES}} { return nosamples }
    if {![mt_finite $v]} { return nonfinite }
    return finite
}
# the SHAPE of a probe column, derived at run time: whether the first and last
# samples are finite and whether all, some or none of them are.  The gate and
# absence rows are keyed partly to a SYMPTOM -- that this engine still answers
# `-nan` and `inf` for these three expressions -- and a fence keyed to a symptom
# dies quietly when something else cures it, so the symptom is asserted.
proc mt_osh_shape {ys} {
    if {[catch {llength $ys} n]} { return "NOTALIST:{$ys}" }
    if {$n < 1} { return empty }
    set f 0
    foreach y $ys { if {[mt_finite $y]} { incr f } }
    set all [expr {$f == 0 ? {nofinite} : ($f == $n ? {allfinite} : {somefinite})}]
    return [list [expr {[mt_finite [lindex $ys 0]] ? {first-finite} : {first-nonfinite}}] \
                 [expr {[mt_finite [lindex $ys end]] ? {last-finite} : {last-nonfinite}}] $all]
}
# the SIGN of every member of a list, as words, so a row about negative answers
# asserts the signs and never the numbers.  BOTH ZEROS ANSWER `zero`, which is
# what the negative-percent row's sign set wants and is exactly why this proc
# CANNOT carry the signed-zero claim: see `mt_ieee_signbit` below.
proc mt_osh_signs {l} {
    if {[catch {llength $l} n]} { return "NOTALIST:{$l}" }
    if {!$n} { return empty }
    set out {}
    foreach v $l {
        if {![mt_finite $v]} { lappend out "notanumber:$v" ; continue }
        if {$v < 0} { lappend out neg ; continue }
        if {$v > 0} { lappend out pos ; continue }
        lappend out zero
    }
    return $out
}
# the IEEE-754 SIGN BIT, read out of the double's own eight bytes --
# `negzero` / `zero` / `neg` / `pos` / a sentinel.  THE INSTRUMENT CLASS IS THE
# POINT: `near`, `string equal`, `calc::eval_finite`, `calc::fn_sink` and
# `mt_osh_signs` all answer IDENTICALLY for -0.0 and +0.0, so a row that wants
# to say a measured zero is NOT normalised has to read the bit.  Measured: two
# spellings of normalising it -- adding 0.0, and applying abs() -- left MT17/E
# at ALL PASS before this existed.
#
# ⚠ NOT a test on the value's STRING FORM, which cannot carry the claim either:
# `format %.17g` on the double -0.0 answers a string that `binary format q`
# resolves back to +0.0 when it is read as an integer, so a string test
# conflates the two.  This reads the bit the arithmetic set.  A raise from
# either `binary` step answers a sentinel, so an interpreter that cannot do it
# reddens the row by name instead of passing it.
proc mt_ieee_signbit {v} {
    if {![mt_finite $v]} { return "notanumber:$v" }
    if {[catch {binary format q $v} b]} { return "NOTADOUBLE:$v" }
    if {[catch {binary scan $b wu u}]} { return "NOSCAN:$v" }
    set s [expr {($u >> 63) & 1}]
    if {$v != 0} { return [expr {$s ? {neg} : {pos}}] }
    return [expr {$s ? {negzero} : {zero}}]
}
# `pure` when a proc's DECOMMENTED body names no engine door and no Tk command,
# the offending words otherwise.  The decision/act split made a measurement:
# `calc::extremum` is the DECISION half of this verb and must gate on the
# counted arm with nothing loaded at all.
proc mt_osh_pure {p} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    if {[catch {info body ::calc::$p} b]} { return "NOBODY:calc::$p" }
    set b [mt_decomment $b]
    set bad {}
    foreach w {xschem winfo toplevel wm grab tkwait bind destroy} {
        if {[regexp "(^|\[^A-Za-z0-9_\])$w\[ \t\n\]" $b]} { lappend bad $w }
    }
    if {[llength $bad]} { return [lsort -unique $bad] }
    return pure
}
# the five SR5 sets, over ONE proc's decommented body -- the same five regexps
# row SR5 of tests/headless/test_calc_scratch_reuse.tcl derives its sets with,
# applied to one name so the row that says this verb owns a complete door can
# name which of the five it fell out of.
proc mt_osh_doors {p} {
    if {[info procs ::calc::$p] eq {}} { return "NOPROC:calc::$p" }
    if {[catch {info body ::calc::$p} b]} { return "NOBODY:calc::$p" }
    set b [mt_decomment $b]
    set out {}
    foreach {lbl pat} [list mint {calc::tmpvec} add {xschem raw add} \
                            read {xschem raw value} del {xschem raw del} \
                            preflight {calc::rpn_bad_token}] {
        if {[regexp $pat $b]} { lappend out $lbl }
    }
    return $out
}

# =========================================================================
# MT17 -- `calc::overshoot`: THE PERCENT BY WHICH A WAVE PASSES ITS FINAL VALUE.
#
# Spec     doc/claude/specs/calculator.md section 7.2 -- the catalogue row
#          `{overshoot {Special Functions} T scalar {} {Percent by which the
#          wave passes its final value}}`, which already carries route T and
#          `returns scalar`, so neither the catalogue nor S24's closed `returns`
#          vocabulary moves for this verb.
# Contract doc/claude/calculator_batch/CROSS_CONTRACT.md D7 and D10-D12, which
#          this verb implements FOR ITSELF rather than inheriting: it is the
#          first measurement verb in this family that is NOT a `calc::cross`
#          delegate.
#
# ⚠⚠ WRITTEN RED FIRST, BEFORE `calc::overshoot`, `calc::extremum` AND THE
# ARGUMENT SPEC EXISTED.  Every behavioural row below failed when it was
# written, each naming `NOPROC:calc::overshoot` or an `ERR:invalid command name`
# rather than raising; the transcript is in the stage receipt.  A row written
# after the code has never been observed to fail and is unproven as a fence.
#
# WHAT THE QUANTITY IS.  `100*(extremum - final)/(final - initial)`.  The two
# references are the two ENDS OF THE STEP the excursion is a percentage of, so
# `final - initial` IS the denominator and `sign(final - initial)` IS the
# direction: a rising step looks for a MAXIMUM and a falling one for a MINIMUM,
# and in both cases a wave that passes its final value answers a POSITIVE
# percent because the numerator and the denominator share a sign.
#
# R415's DISPOSITION, READ ACROSS.  Both references are REQUIRED and nothing is
# derived from the trace.  The user's own words about `riseTime`'s swing were
# *"Cadence makes you supply them"*, and deriving either end here would be the
# settled-value estimator R415 removed from that verb on purpose.  There is a
# structural consequence too: the last sample and the extremum are the two
# obvious guesses, and MT17/A asserts that neither is used by driving `final`
# over six values on ONE column -- a verb that read `final` off the trace
# answers one number six times.
#
# ⚠⚠ THIS VERB IS NOT A `cross` DELEGATE AND OPENS ITS OWN ENGINE DOOR, which
# is the one place the whole family's structure moves.  An extremum is not a
# crossing: `max()`/`min()` in the RPN engine are two-operand ELEMENTWISE
# clamps, there is no stateful running-max opcode, and `xschem raw` has no
# min/max accessor.  So `calc::overshoot` MINTS through `calc::tmpvec`, ADDS
# through `xschem raw add`, READS through the bulk `xschem raw values` door,
# DELETES through `xschem raw del` and PRE-FLIGHTS through
# `calc::rpn_bad_token` -- all five of SR5's sets, asserted as such by MT17/O.
# `xschem raw value` is NOT used anywhere: it returns through `%.8g` and ROUNDS,
# which no comparison in this file could survive.
#
# ⚠ BAND MT10 WAS RESTRUCTURED IN THE SAME CHANGE, AND THAT IS NOT A
# RELAXATION.  Its claim used to be that every verb with an argument spec is a
# pure delegate on `cross`; that is now FALSE of one of them, so the band
# DERIVES the partition -- delegate or own-door -- out of the same structural
# instrument and makes the complementary claim about each half, with a floor on
# both and the partition itself asserted.  A verb that quietly grew a door
# moves from one half to the other and is measured there, which is what the
# single-claim shape could not express.
#
# ⚠ THE DECISION IS SPLIT FROM THE ACT, at the house's own seam.
# `calc::extremum` is the pure half: a list in, one element out, no engine and
# no Tk, so the direction choice and the finiteness gate gate on the COUNTED arm
# with nothing loaded at all (MT17/P).  It stands to `calc::overshoot` as
# `calc::cross_scan` stands to `calc::cross`.
#
# NO `nth`, NO `edge`, NO WINDOW, NO `_scalar` WRAPPER.  There is exactly one
# extremum per (column, dataset, direction), so there is no occurrence to
# select and no series to put anywhere; the direction is DERIVED from the step's
# own sign, so an explicit `edge` would be a second and contradictory way to say
# the same thing; and R304's Clip is unwired (`::calc::clip` has no reader),
# so there is no X window to search inside.  MT17/R asserts the absence of the
# wrapper rather than leaving it as a fact about today's tree, because
# `calc::arg_surface` is literally *"if `::calc::<name>_scalar` exists, return
# it"* and minting one later silently redirects every click.
#
# ⚠⚠ THREE SPECIFIC FIXTURE CHOICES ARE LOAD-BEARING AND EACH WAS MEASURED
# BEFORE THE ROW WAS WRITTEN, because the OBVIOUS spelling of each is VACUOUS at
# `MTTOL`.  This is issue 1643's finding arriving at a fourth verb, and the
# statistic that settles it is the ADJACENT PAIR and never the range.
#
#  1. THE DIRECTION ROW MUST USE AN ASYMMETRIC REFERENCE.  The natural spelling
#     -- one column, one magnitude of step, two directions -- compares
#     `v(ramp) 0->5` against `v(ramp) 10->5` and they agree to a RELATIVE 3.0e-14,
#     four thousand times INSIDE `MTTOL`.  The cause is structural rather than a
#     fixture accident: every driven column here has a minimum of exactly 0, so
#     a `final` at the midpoint of `(0, max)` makes `max - final` and
#     `final - min` identical by construction.  MT17/C therefore drives
#     `0->3` against `10->3` on a `0 .. 10` column, and MT17/NV4 carries the
#     symmetric pair as a CONTROL that must answer `same`, so the next person to
#     simplify the row reddens there instead of shipping a vacuous fence.
#  2. THE EXPRESSION ROW MUST NOT USE THE INVERTED SQUARE.  `{v(sq)}` against
#     `{1 v(sq) -}` at the same references agree to a relative 3.9e-13, because
#     both columns top out at about 1.  That pair is the second CONTROL in
#     MT17/NV4 and the row uses `{v(sq) v(ramp) *}` instead.
#  3. AT LEAST ONE VALUE ROW MUST CARRY A NONZERO `initial`.  With `initial 0`
#     the "divide by `final` alone" sabotage is INDISTINGUISHABLE from correct
#     arithmetic; at `0.2 -> 0.6` it is a relative 0.33 away.  MT17/B sweeps
#     `initial` over six values for exactly that reason and carries both
#     one-reference divisions as named wrong readings.
#
# ⚠ `-0.0` IS A REACHABLE ANSWER AND IS NOT NORMALISED.  `v(sq) 1 -> 0` returns
# it: the minimum is exactly 0 and the step is negative.  `calc::eval_finite`
# accepts it, `calc::fn_sink` says `buffer`, and `strtod` lexes it -- but
# `string equal $v 0` is FALSE, so NO ROW IN THIS BAND MAY COMPARE AN ANSWER
# WITH STRING EQUALITY.  MT17/E is the fence, and it also fences a future
# `fn_sink` or `eval_finite` change that would route a correct measurement to
# `badvalue`.
#
# ⚠ THERE IS EXACTLY ONE REACHABLE ABSENCE.  Every well-formed request over a
# loaded column with at least one finite sample has an answer, so `absent` is
# reachable only when NO sample of the evaluated column is finite.
# `{1000 exp()}` reaches it on the committed fixture, which is what makes
# MT17/J a fence and not a belt.
#
# DECLARED LIMITS, each measured rather than assumed:
#
#  L1 NO X WINDOW.  The extremum is over the WHOLE requested dataset, because
#     R304's Clip is unwired: `::calc::clip` has no reader anywhere in the tree
#     and the checkbutton's `-command` is still `calc::inert`.  On a sweep with
#     several transitions the answer is the worst excursion in the run, not the
#     overshoot of one chosen edge, and a pre-transition glitch above `final` is
#     reported as overshoot.  Nothing here measures a per-transition reading
#     because nothing can.
#  L2 NO PEAK ANCHORING, same cause.  The alternative -- the extremum after the
#     first crossing of `final` -- EQUALS the global extremum for every signal
#     that rises into its overshoot, needs an absence family of its own for a
#     `final` the trace never reaches, and has no window to anchor in.
#  L3 NO DIRECTION OVERRIDE.  A request for "the maximum even though the step
#     falls" is unreachable and therefore unfenced.
#  L4 THE `rc ne 1` BELT AFTER `xschem raw add` IS UNFENCED, inherited from
#     `calc::cross` with its reason: while the `xschem raw index` check above it
#     stands, that arm needs another writer to claim the name between two
#     adjacent statements.  No row forces it and it is not claimed as fenced.
#  L5 NO `points` CHECK.  A dataset with zero points would read back an empty
#     column and be reported as the ABSENCE rather than as `nodata`.
#     Unreachable on the committed fixture (both transient datasets are 101
#     points); `calc::eval_rpn` does check and `calc::cross` does not, and this
#     follows `cross` so the family's pre-flight stays identical.
#  L6 `dc` SWEEPS ARE REFUSED, inherited from `cross`'s two-arm `sim_type`
#     switch and unreachable on the committed fixture.
#  L7 THE `op` PLOT IS REFUSED BY CHOICE, NOT BY NECESSITY.  This verb's answer
#     has no X in it, so it would compute on a single DC point -- MT17/L shows
#     that an answer really was available and that the verb refused anyway, in
#     the same sentence `calc::riseTime` answers for the same database.  The
#     reasons are that an overshoot is a statement about a TRANSITION, that a
#     user clicking four verbs of this family on one database must not get three
#     refusals and one number, and that a refusal can be relaxed later while a
#     shipped number cannot be withdrawn.  Nothing proves it is the better
#     product behaviour; it is a disposition, declared so an overrule is a
#     one-row edit.
#  L8 THIS VERB'S OWN SENTENCES' WORDS ARE UNRATIFIED and no row asserts them --
#     only the house SHAPE and, for the arms it REUSES, identity against
#     `calc::cross_msg`.  NO COUNT OF EITHER SET IS WRITTEN HERE: both are
#     figures over `calc::overshoot`'s own body, MT17/K derives them with
#     `mt_verb_msg_arms`, and the figure this limit used to quote was wrong --
#     measured off the proc, the reused set is larger than it said and the
#     paired sweep smaller.  MT17/K now declares that subset instead.
#     The two field labels are unratified user-visible text
#     covered by the `rule` debt
#     `calc_argdialog_field_labels_and_delay_second_signal`; MT11 pins them in
#     one row so an overrule is a one-row edit.  A green run here is not
#     ratification.
#  L9 BOTH LONG REFUSAL SENTENCES EXCEED S24's MEASURED STATUS-LINE BUDGET,
#     exactly as `calc::riseTime`'s own `noswing` already does.  S24 sweeps
#     `calc::fn_reason` only, so nothing asserts either.  Same declared hole,
#     not a new one -- a TRUNCATION POLICY has to be decided before any wording
#     fixes it.
# L10 NOTHING HERE TOUCHES THE DIALOG, THE CLICK, THE BUFFER PASTE, THE STATUS
#     SENTENCE OR THE UNDO STEP.  `calc::fn_measure` and
#     `calc::buf_set_number` both return early on `calc::has_win .calc.buf`, so
#     the ACT is observable only on a gate's DISPLAY arm -- bands S28 of
#     tests/headless/test_calc_skeleton.tcl and CW14 of
#     tests/headless/test_calc_widgets.tcl, both `dcases` ALONE.  A green
#     `--nogui` run says only that the DECISION is right.  The narrowed tree is
#     SAFE: a scalar answer routes to `buffer` through a `fn_sink` ladder that
#     already fails closed, so there is no half-feature that could paste
#     something wrong.
# L11 THE `ac` ARM IS FENCED FOR THIS VERB ONLY.  `calc::cross`'s own `ac` arm
#     stays unfenced for its own reason -- its answer is an X -- and nothing in
#     MT17 improves `cross`'s coverage.
# L13 THE `engine` REFUSAL ARM IS FENCED BY NOTHING, declared rather than
#     claimed.  A raise out of `xschem raw add` or `xschem raw values` has no
#     reachable trigger: band CX9 of tests/headless/test_calc_cross.tcl records
#     the same hole for `calc::cross` in so many words, and band CX13 measures
#     why -- an expression the PRE-FLIGHT approves and the ENGINE rejects
#     (`v(sq) -1 del()`) makes `xschem raw add` answer 1 over a column of
#     defined zeros rather than raising.  MT17/N drives that expression and the
#     non-finite columns as EXIT PATHS for the R402 claim, which is all they can
#     fence.
# L12 TWO ROWS HERE PASS WITH NO FEATURE PRESENT and they are named rather than
#     left for a reader to find: MT17/N, the R402 inventory, which is a claim
#     about this band's own hygiene, and MT17/NV3, which measures the FIXTURE's
#     probe columns and not the verb.  MT17/NV2's agreement leg is in the same
#     class.  Every other row carries the feature's presence as the first
#     element of what it compares, which is MT10's discipline.
# =========================================================================
group MT17 {
    pcall mt_load tran
    # the presence leg every claim below carries, MT10's discipline: without it
    # a structural or inventory row reads green on a tree with no feature in it.
    set oP [list [llength [info procs ::calc::overshoot]] \
                 [llength [info procs ::calc::extremum]]]
    set oPW {1 1}

    # --- NV1: the two procs and the spec are really here ---------------------
    check "MT17/NV1 the feature is PRESENT -- both procs and a non-empty argument spec -- which is the leg carried as the first element of every claim below, because `no proc issues a direct engine verb` and `every refusal is in the house shape` are both VACUOUSLY TRUE on a tree with nothing in it.  The negative controls ride along so the instrument is shown to be able to answer zero" \
        [list $oP [llength [pcall calc::fn_argspec overshoot]] \
              [llength [info procs ::calc::__mt_nosuch_zz]] \
              [llength [pcall calc::fn_argspec __mt_nosuch_zz]]] \
        [list $oPW 3 0 0]

    # --- NV2: the extremum, two instrument classes, neither of them the verb -
    set oNV2 {} ; set oNV2N 0
    foreach oCol {v(sq) v(lp) v(ramp) v(div) v(dcmid)} {
        foreach oDs {0 1} {
            set oYs [mt_col $oCol $oDs]
            foreach oW {max min} {
                incr oNV2N
                set oA [mt_osh_scan $oYs $oW]
                set oB [mt_osh_sort $oYs $oW]
                if {![mt_finite $oA] || ![mt_finite $oB]} {
                    lappend oNV2 "$oCol/$oDs/$oW=notanumber" ; continue
                }
                if {[near $oA $oB 0] ne {ok}} { lappend oNV2 "$oCol/$oDs/$oW=$oA|$oB" }
            }
        }
    }
    check "MT17/NV2 the comparand this whole band leans on is derived TWO WAYS with no product proc in either -- this file's own gated forward scan and `lsort -real` over the FINITE samples -- and they must agree EXACTLY, at tolerance zero, over every driven column in both datasets and in both directions.  Without this the band could be measuring itself.  ⚠ The sorting leg gates FIRST because `lsort -real` RAISES on a column carrying a -nan, which is asserted as a sentinel below rather than met as an aborted band; the pair count rides along so an empty sweep cannot pass" \
        [list [mt_atleast $oNV2N 20] $oNV2 \
              [mt_osh_scan {1 2 3} max] [mt_osh_sort {1 2 3} max] \
              [catch {lsort -real [list -nan 1 2]}] \
              [mt_osh_sort [list -nan 1 2] max]] \
        {atleast20 {} 3 3 1 2}

    # --- NV3: the three probe columns' SHAPE, derived at run time -------------
    # ⚠ THIS IS A FENCE KEYED PARTLY TO A SYMPTOM, which is the one shape that
    # dies quietly: the gate rows and the absence row need this engine to keep
    # answering `-nan` and `inf` for these expressions, and it already clamps
    # `ln(0)` to -35 and, since issue 1628, `x/0` to 0.  If a future change
    # clamped these too, MT17/H, MT17/I and MT17/J would go VACUOUS in silence.
    # This row makes that reddening instead.
    set oNANF {v(ramp) 5 - sqrt()}
    set oNANL {5 v(ramp) - sqrt()}
    set oINF  {1000 exp()}
    set oITAIL {v(sq) v(ramp) 9.5 - 0 max() 1e308 * 1e308 * +}
    check "MT17/NV3 the three probe columns really have the SHAPES the gate and absence rows need, derived at run time and never written into an expectation: a nan-FIRST column with some finite samples, an all-non-finite column, an inf-TAILED column with a finite first sample, and the CONTROL column whose non-finite samples are all at the END -- which is the shape that CANNOT discriminate the gate and is driven in MT17/H to show why the nan-first one is the only one that can.  A fence keyed to a symptom dies quietly when something else cures the symptom; this is what makes that reddening" \
        [list [mt_osh_shape [mt_addcol __mt_osh $oNANF 0]] \
              [mt_osh_shape [mt_addcol __mt_osh $oINF 0]] \
              [mt_osh_shape [mt_addcol __mt_osh $oITAIL 0]] \
              [mt_osh_shape [mt_addcol __mt_osh $oNANL 0]] \
              [mt_osh_shape {}] [mt_osh_shape {1 2 3}]] \
        [list {first-nonfinite last-finite somefinite} \
              {first-nonfinite last-nonfinite nofinite} \
              {first-finite last-nonfinite somefinite} \
              {first-finite last-nonfinite somefinite} \
              empty {first-finite last-finite allfinite}]

    # --- NV4: the distinctness of every pair this band compares, MEASURED ----
    # ⚠⚠ AND THE TWO CONTROLS, WHICH ARE THE POINT OF THE ROW.  Both answer
    # `same` -- they are the two obvious spellings of the direction row and the
    # expression row, and both are INSIDE MTTOL on this fixture.  Carrying them
    # proves the instrument can still say `same`, so every `distinct` above is a
    # measurement of the fixture and not a constant, and the next person to
    # simplify either row reddens here with a name.
    check "MT17/NV4 every pair the rows below actually compare is `distinct` at MTTOL, element by element and never as a range -- and the TWO CONTROLS that must answer `same` are the obvious spellings of the direction row and the expression row, both of which are VACUOUS on this fixture: `v(ramp) 0->5` against `v(ramp) 10->5` agree because every driven column here bottoms at exactly 0, so a midpoint `final` makes the two excursions identical by construction, and `{v(sq)}` against `{1 v(sq) -}` agree because both columns top out at about 1.  A direction-blind or expression-blind producer passes either control and fails the rows that use the asymmetric reference instead" \
        [list [mt_distinct [mt_osh_ref {v(ramp)} 0 3 0] [mt_osh_ref {v(ramp)} 10 3 0]] \
              [mt_distinct [mt_osh_ref {v(sq)} 0 0.9 0] [mt_osh_ref {v(sq) v(ramp) *} 0 0.9 0]] \
              [mt_distinct [mt_osh_ref {v(div)} 0 2 0] [mt_osh_ref {v(div)} 0 2 1]] \
              [mt_distinct [mt_osh_ref {v(ramp)} 0 2 0] [mt_osh_wrong {v(ramp)} 0 2 0 fraction]] \
              [mt_alldistinct [list [mt_osh_ref {v(lp)} 0 0.5 0] [mt_osh_ref {v(lp)} 0 0.6 0] \
                                    [mt_osh_ref {v(lp)} 0 0.7 0] [mt_osh_ref {v(lp)} 0 0.8 0] \
                                    [mt_osh_ref {v(lp)} 0 0.9 0] [mt_osh_ref {v(lp)} 0 0.95 0]]] \
              [mt_distinct [mt_osh_ref {v(ramp)} 0 5 0] [mt_osh_ref {v(ramp)} 10 5 0]] \
              [mt_distinct [mt_osh_ref {v(sq)} 0 0.9 0] [mt_osh_ref {1 v(sq) -} 0 0.9 0]]] \
        {distinct distinct distinct distinct distinct same same}

    # --- A: the step comes from the SUPPLIED references, `final` swept -------
    set oAF {0.5 0.6 0.7 0.8 0.9 0.95}
    set oAGOT {} ; set oAEXP {}
    foreach oF $oAF {
        lappend oAGOT [mt_val [mt_call overshoot {v(lp)} 0 $oF 0]]
        lappend oAEXP [mt_osh_ref {v(lp)} 0 $oF 0]
    }
    check "MT17/A the step is read from the SUPPLIED references and from nothing the trace says -- `final` swept over six values on ONE column, element for element against this file's own derivation, with every ADJACENT pair of the resulting series asserted distinct so the comparison means something.  A verb that took `final` from the trace's LAST sample, or from the extremum itself, answers ONE number six times and reddens on the distinctness leg before it reddens on the values; both wrong readings are built here and carried as `distinct` so the row cannot be read as a claim about an absent alternative" \
        [list $oP [mt_listcmp $oAGOT $oAEXP] [mt_alldistinct $oAGOT] \
              [mt_distinct [lindex $oAGOT 0] [mt_osh_wrong {v(lp)} 0 0.5 0 lastsample]] \
              [mt_atleast [llength $oAGOT] 6]] \
        [list $oPW ok distinct distinct atleast6]

    # --- B: `initial` is READ and DIVIDES, swept, with a NONZERO member ------
    set oBI {0 0.1 0.2 0.3 0.4 0.5}
    set oBGOT {} ; set oBEXP {}
    foreach oI $oBI {
        lappend oBGOT [mt_val [mt_call overshoot {v(sq)} $oI 0.6 0]]
        lappend oBEXP [mt_osh_ref {v(sq)} $oI 0.6 0]
    }
    set oB2 [mt_val [mt_call overshoot {v(sq)} 0.2 0.6 0]]
    check "MT17/B ...and `initial` is read and DIVIDES: swept over six values with `final` held, element for element, every adjacent pair distinct.  ⚠ AT LEAST ONE REQUEST HERE CARRIES A NONZERO `initial`, and that is load-bearing and measured: with `initial 0` the `divide by final alone` reading is INDISTINGUISHABLE from correct arithmetic, while at 0.2 -> 0.6 it is a relative 0.33 away.  Both one-reference divisions are built from the same column and carried as `distinct`, so the row fences the denominator and not only the numerator" \
        [list $oP [mt_listcmp $oBGOT $oBEXP] [mt_alldistinct $oBGOT] \
              [mt_distinct $oB2 [mt_osh_wrong {v(sq)} 0.2 0.6 0 divfinal]] \
              [mt_distinct $oB2 [mt_osh_wrong {v(sq)} 0.2 0.6 0 divinit]] \
              [mt_distinct [lindex $oBGOT 0] [mt_osh_wrong {v(sq)} 0 0.6 0 divfinal]]] \
        [list $oPW ok distinct distinct distinct same]

    # --- C: the DIRECTION is the sign of the step, ASYMMETRIC reference ------
    set oCUP [mt_call overshoot {v(ramp)} 0 3 0]
    set oCDN [mt_call overshoot {v(ramp)} 10 3 0]
    check "MT17/C the DIRECTION is the sign of the supplied step and the extremum follows it -- a rising step takes the maximum, a falling one the minimum -- measured on ONE column with an ASYMMETRIC reference, because the symmetric spelling of this row is VACUOUS and MT17/NV4's control proves it.  Both answers are checked against this file's derivation, they are distinct from each other, and the two direction-blind readings are built from the same column: always-max on the FALLING request and always-min on the RISING one, each distinct from the correct answer AND OPPOSITE IN SIGN, which is the leg that says a direction-blind producer is not merely imprecise here" \
        [list $oP [mt_is $oCUP [mt_osh_ref {v(ramp)} 0 3 0]] \
              [mt_is $oCDN [mt_osh_ref {v(ramp)} 10 3 0]] \
              [mt_distinct [mt_val $oCUP] [mt_val $oCDN]] \
              [mt_distinct [mt_val $oCDN] [mt_osh_wrong {v(ramp)} 10 3 0 alwaysmax]] \
              [mt_distinct [mt_val $oCUP] [mt_osh_wrong {v(ramp)} 0 3 0 alwaysmin]] \
              [mt_osh_signs [list [mt_val $oCUP] [mt_val $oCDN] \
                                  [mt_osh_wrong {v(ramp)} 10 3 0 alwaysmax] \
                                  [mt_osh_wrong {v(ramp)} 0 3 0 alwaysmin]]] \
              [mt_osh_which 0 3] [mt_osh_which 10 3] [mt_osh_which 3 3]] \
        [list $oPW ok ok distinct distinct distinct {pos pos neg neg} max min ZERO]

    # --- D: a wave that never passes `final` answers a NEGATIVE percent ------
    set oD1 [mt_call overshoot {v(sq)} 0 2 0]
    set oD2 [mt_call overshoot {v(lp)} 0 1.5 0]
    set oD3 [mt_call overshoot {i(@rtop[i])} 0 0.003 1]
    check "MT17/D a wave that never passes its final value answers a NEGATIVE percent -- not zero, not a refusal, not absolute-valued -- on three columns, with the three SIGNS asserted as a set and each value against this file's derivation.  T3's ruling read across: ADE-L is a FLOOR, so refusing a legitimately computable number is a defect, and `delay`'s negative answer settled that such a number is returned rather than clamped.  Clamping to zero would destroy the one thing a designer wants when a settling spec fails -- how far short it fell.  The DISPOSITIONS ride along, because a clamp and a refusal are different wrong answers" \
        [list $oP [mt_osh_signs [list [mt_val $oD1] [mt_val $oD2] [mt_val $oD3]]] \
              [list [mt_disp $oD1] [mt_disp $oD2] [mt_disp $oD3]] \
              [mt_is $oD1 [mt_osh_ref {v(sq)} 0 2 0]] \
              [mt_is $oD2 [mt_osh_ref {v(lp)} 0 1.5 0]] \
              [mt_is $oD3 [mt_osh_ref {i(@rtop[i])} 0 0.003 1]]] \
        [list $oPW {neg neg neg} {measured measured measured} ok ok ok]

    # --- E: the SIGNED ZERO, and why no row may use string equality ----------
    set oE [mt_call overshoot {v(sq)} 1 0 0]
    check "MT17/E a wave that reaches its final value and passes it by nothing answers ZERO, compared with `near` and NEVER with `string equal`, and the SIGN of that zero is read through the one instrument that can see it: v(sq) 1 -> 0 has a minimum of exactly 0 against a negative step, so the answer carries the IEEE SIGN BIT, asserted off the double's own bytes.  That leg is not a belt -- `near`, `string equal`, `calc::eval_finite`, `calc::fn_sink` AND `mt_osh_signs` were MEASURED to answer identically for -0.0 and +0.0, so before it existed two built spellings of normalising the zero (adding 0.0, applying abs) left this row at ALL PASS while its name claimed the number was unnormalised.  The two CONTROLS show the same instrument answering `zero` and `neg` on hand-built values, so `negzero` is a reading and not a constant; `calc::eval_finite` and `calc::fn_sink` are the fence on a future change that would route a correct measurement to `badvalue` and refuse it" \
        [list $oP [mt_disp $oE] [near [mt_val $oE] 0 $MTTOL] \
              [string equal [mt_val $oE] 0] \
              [pcall calc::eval_finite [mt_val $oE]] [mt_sink $oE] \
              [mt_osh_signs [list [mt_val $oE]]] \
              [mt_ieee_signbit [mt_val $oE]] \
              [mt_ieee_signbit [expr {0.0}]] [mt_ieee_signbit [expr {-1.0}]]] \
        [list $oPW measured ok 0 1 buffer zero negzero zero neg]

    # --- F: a PERCENT and not a fraction -------------------------------------
    set oF [mt_call overshoot {v(ramp)} 0 2 0]
    check "MT17/F the answer is a PERCENT and not a fraction, which is what the shipped catalogue help promises -- driven where the answer is far from both 0 and 1, so the two readings are two orders apart and the row is not a claim about a rounding difference.  The fraction spelling is built from the same column and asserted `distinct`" \
        [list $oP [mt_is $oF [mt_osh_ref {v(ramp)} 0 2 0]] \
              [mt_distinct [mt_val $oF] [mt_osh_wrong {v(ramp)} 0 2 0 fraction]] \
              [expr {[mt_finite [mt_val $oF]] && [mt_val $oF] > 10 ? {farfromboth} : {NEAR}}]] \
        [list $oPW ok distinct farfromboth]

    # --- G: the DATASET is READ, with the ALLPOINTS read named ---------------
    set oG0 [mt_call overshoot {v(div)} 0 2 0]
    set oG1 [mt_call overshoot {v(div)} 0 2 1]
    set oH0 [mt_call overshoot {i(@rtop[i])} 0 0.003 0]
    set oH1 [mt_call overshoot {i(@rtop[i])} 0 0.003 1]
    set oGAP [mt_osh_ref {v(div)} 0 2 -1]
    set oGBAD {}
    foreach {oDs oKind oArgs} [list 2 dataset [list 2 [pcall xschem raw datasets]] \
                                    -1 allpoints {-1} 1.5 intdataset {1.5}] {
        set oA [mt_call overshoot {v(sq)} 0 0.5 $oDs]
        if {[mt_disp $oA] ne {refused}} { lappend oGBAD "$oDs=[mt_disp $oA]" ; continue }
        if {![string equal [mt_msg $oA] [pcall calc::cross_msg $oKind {*}$oArgs]]} {
            lappend oGBAD "$oDs=notidentical"
        }
    }
    check "MT17/G the DATASET is READ and not echoed: one expression, one argument pair, two datasets, two different numbers -- on two columns, the second of which CROSSES ZERO between the datasets -- with the ALLPOINTS read named as a third comparand, because it answers dataset 0's number and so is what an unvalidated dataset would silently report for dataset 1.  The three bad datasets are refused with cross's own sentences by IDENTITY.  ⚠ Measured and load-bearing: `xschem raw values v(sq) 2` returns an EMPTY string with rc 0 and does not raise, so without the validation an out-of-range dataset would be reported as an ABSENCE rather than a refusal" \
        [list $oP [mt_is $oG0 [mt_osh_ref {v(div)} 0 2 0]] \
              [mt_is $oG1 [mt_osh_ref {v(div)} 0 2 1]] \
              [mt_distinct [mt_val $oG0] [mt_val $oG1]] \
              [mt_distinct $oGAP [mt_val $oG1]] [mt_distinct $oGAP [mt_val $oG0]] \
              [mt_key $oG0 dataset] [mt_key $oG1 dataset] \
              [mt_osh_signs [list [mt_val $oH0] [mt_val $oH1]]] \
              [mt_distinct [mt_val $oH0] [mt_val $oH1]] $oGBAD] \
        [list $oPW ok ok distinct distinct same 0 1 {pos neg} distinct {}]

    # --- H: the FINITENESS GATE, measured as RAISE versus ANSWER -------------
    # ⚠⚠ THE NAN-FIRST SHAPE IS THE ONLY ONE THAT DISCRIMINATES, AND THE
    # CONTROL IS WHY.  `expr {"-nan" > 0}` answers 0 QUIETLY, so a nan never
    # WINS a comparison and a reader concluding "the predicate filters it
    # already" is right about that half.  What a nan wins is the SEED: with
    # sample 0 non-finite an ungated scan puts `-nan` in the accumulator, every
    # later comparison answers 0, and the subtraction then RAISES -- a throw
    # where D7 requires an answer.  On a column whose non-finite samples are all
    # at the END the gated and ungated scans agree exactly, which the control
    # leg measures rather than asserting.
    set oHYS [mt_addcol __mt_osh $oNANF 0]
    set oHLYS [mt_addcol __mt_osh $oNANL 0]
    set oHA [mt_call overshoot $oNANF 0 1 0]
    set oHB [mt_call overshoot $oNANL 0 1 0]
    check "MT17/H the finiteness gate is a FENCE and not a belt, measured as RAISE-versus-ANSWER on a column whose FIRST sample is non-finite: the verb answers this file's own gated derivation while the same scan WITHOUT the gate RAISES on the subtraction.  The CONTROL is the column whose non-finite samples are all at the END, where gated and ungated agree exactly -- so the row shows which shape can see the defect and which cannot, instead of leaving the choice of column to look arbitrary.  ⚠ `lsort -real` is no shortcut here: it raises on the same column, which is why the second derivation gates before it sorts" \
        [list $oP [mt_disp $oHA] [mt_is $oHA [mt_osh_ref $oNANF 0 1 0]] \
              [mt_osh_ungated_word $oHYS 0 1] \
              [mt_disp $oHB] [mt_is $oHB [mt_osh_ref $oNANL 0 1 0]] \
              [mt_osh_ungated_word $oHLYS 0 1] \
              [mt_cmpword [list [mt_osh_ref $oNANL 0 1 0]] \
                          [list [mt_osh_ungated $oHLYS 0 1]] 0] \
              [catch {lsort -real $oHYS}] [mt_osh_sort $oHYS max]] \
        [list $oPW measured ok raises measured ok finite same 1 \
              [mt_osh_scan $oHYS max]]

    # --- I: the OTHER half of the same gate, which no nan column can show ----
    set oIYS [mt_addcol __mt_osh $oITAIL 0]
    set oIA [mt_call overshoot $oITAIL 0 0.5 0]
    set oIB [mt_call overshoot {v(sq)} 0 0.5 0]
    check "MT17/I ...and the other half of the same gate, which NO nan column can show: `expr {\"inf\" > 0}` answers 1, so an inf sample DOES win a maximum and poisons the answer.  The inf-TAILED column answers exactly what plain v(sq) answers at the same references -- asserted as that IDENTITY, so the inf tail is shown to change nothing -- while the ungated scan on the same samples answers a NON-FINITE number that `calc::eval_finite` rejects, which would route a correct measurement to `badvalue` and tell the user their result is not a literal number" \
        [list $oP [mt_disp $oIA] [string equal [mt_val $oIA] [mt_val $oIB]] \
              [mt_is $oIA [mt_osh_ref $oITAIL 0 0.5 0]] \
              [mt_osh_ungated_word $oIYS 0 0.5] \
              [pcall calc::eval_finite [mt_osh_ungated $oIYS 0 0.5]] \
              [pcall calc::eval_finite [mt_val $oIA]]] \
        [list $oPW measured 1 ok nonfinite 0 1]

    # --- J: the ONE reachable absence, with its negative half ----------------
    set oJA [mt_call overshoot $oINF 0 1 0]
    set oJB [mt_call overshoot $oINF {} 1 0]
    check "MT17/J a dataset in which NO sample is finite is an ABSENCE and never a refusal, and the NEGATIVE half on the SAME column is a malformed request, which is a refusal and never an absence -- D7's two dispositions through the one verb in this family with exactly one reachable absence.  The absence carries its own sentence by IDENTITY against `calc::cross_msg`'s arm, the refusal carries the request-level one, the two sentences differ, both are in the house shape, and `dest` still holds the RETIRED temporary on the absence so nothing is left behind" \
        [list $oP [mt_disp $oJA] [mt_disp $oJB] \
              [string equal [mt_msg $oJA] [pcall calc::cross_msg oshnoextremum]] \
              [string equal [mt_msg $oJB] [pcall calc::cross_msg oshnoswing {} 1]] \
              [string equal [mt_msg $oJA] [mt_msg $oJB]] \
              [mt_shape [mt_msg $oJA]] [mt_shape [mt_msg $oJB]] \
              [mt_tmpname [mt_key $oJA dest]] [mt_key $oJB dest]] \
        [list $oPW absent refused 1 1 0 ok ok tmp {}]

    # --- K: the refusals this verb can reach, each NAMED ---------------------
    # ⚠ THE REUSED ARMS THIS BAND DRIVES THROUGH BOTH VERBS ARE ASSERTED BY
    # IDENTITY AGAINST WHAT `calc::riseTime` ANSWERS FOR THE SAME REQUEST, which
    # is the one-voice property: a user clicking two verbs of this family on the
    # same broken database must read the same words.  The arms that are
    # `overshoot`'s OWN are asserted NON-identical to their `cross` counterparts,
    # which is what catches a future generalisation that merged them -- that
    # would redden band MT9b with a puzzle instead of here with a name.
    #
    # ⚠⚠ THE ARM SETS ARE DERIVED FROM THE VERB'S OWN BODY, AND THE PAIRED
    # SWEEP IS A DECLARED SUBSET RATHER THAN A SILENT ONE.  Three prose sites
    # and this row's own name used to quote a reused-arm count; all of them
    # disagreed with the tree and with each other, and the row that claimed to
    # assert the reused arms drove fewer of them than the number it printed --
    # which is a name describing coverage rather than method, the defect row X1
    # of tests/headless/test_snprintf_fmt_1608.tcl exists to warn about.  What
    # the legs now say: `mt_verb_msg_arms` derives the OWN set and the REUSED
    # set, the own set is asserted EXACTLY (a fifth own arm reddens), the reused
    # set carries a RATCHET floor, and every id the paired loop drives must be a
    # MEMBER of the derived reused set with its own floor -- so an arm added to
    # the verb cannot sit outside this row while the row reads as covering it.
    set oKarms [mt_verb_msg_arms overshoot osh]
    set oKown {} ; set oKreused {}
    if {[catch {dict get $oKarms own} oKown]}    { set oKown  "NOTADICT:$oKarms" }
    if {[catch {dict get $oKarms reused} oKreused]} { set oKreused "NOTADICT:$oKarms" }
    set oKBAD {} ; set oKN 0
    foreach {oKid oKargs oKkind oKms} [list \
            noswing  {{v(sq)} {} 0.5 0}   oshnoswing   {{} 0.5} \
            noswing2 {{v(sq)} 0 {} 0}     oshnoswing   {0 {}} \
            badrefi  {{v(sq)} nan 0.5 0}  oshbadref    {nan} \
            badreff  {{v(sq)} 0 inf 0}    oshbadref    {inf} \
            zero     {{v(sq)} 0.5 0.5 0}  oshzeroswing {0.5} \
            tiny     {{v(sq)} 0 5e-324 0} oshtinystep  {0 5e-324} \
            empty    {{} 0 0.5 0}         empty        {} \
            badtok   {{v(nosuch)} 0 0.5 0} badtoken    {@BADTOK@} \
            ds2      {{v(sq)} 0 0.5 2}    dataset      {2 @NDS@} \
            dsneg    {{v(sq)} 0 0.5 -1}   allpoints    {-1} \
            dsfrac   {{v(sq)} 0 0.5 1.5}  intdataset   {1.5}] {
        incr oKN
        set oKa [mt_call overshoot {*}$oKargs]
        set oKe {}
        foreach oKx $oKms {
            if {$oKx eq {@BADTOK@}} { lappend oKe [pcall calc::rpn_bad_token {v(nosuch)}] ; continue }
            if {$oKx eq {@NDS@}} { lappend oKe [pcall xschem raw datasets] ; continue }
            lappend oKe $oKx
        }
        if {[mt_disp $oKa] ne {refused}} { lappend oKBAD "$oKid=[mt_disp $oKa]" ; continue }
        if {![string equal [mt_msg $oKa] [pcall calc::cross_msg $oKkind {*}$oKe]]} {
            lappend oKBAD "$oKid=notidentical" ; continue
        }
        if {[mt_shape [mt_msg $oKa]] ne {ok}} { lappend oKBAD "$oKid=[mt_shape [mt_msg $oKa]]" }
    }
    # ⚠⚠ THE ARMS THIS BAND DOES NOT DRIVE ARE DECLARED AS A SET AND ASSERTED
    # AGAINST THE DERIVATION, which is what makes the row's `swept` claim a
    # measurement instead of an advertisement.  `oKDRIVEN` names the kinds the
    # bands above really reach -- the loop just above, band J's absence and its
    # malformed half, K2's cleared-database arm and L's operating-point refusal.
    # The complement is asserted EXACTLY, so an arm added to `calc::overshoot`
    # that nobody sweeps appears there and reddens by name, instead of sitting
    # outside a row whose title says it is covered.  Each surviving member has a
    # reason: `stale` is limit L4's unforced belt, and `noname`/`engine` need
    # `calc::tmpvec` or the engine itself to fail, which no request can arrange.
    set oKDRIVEN {allpoints badtoken dataset empty intdataset nodata nosweep \
                  oshbadref oshnoextremum oshnoswing oshtinystep oshzeroswing}
    set oKUNSWEPT {}
    foreach oKk [concat $oKown $oKreused] {
        if {[lsearch -exact $oKDRIVEN $oKk] < 0} { lappend oKUNSWEPT $oKk }
    }
    set oKUNSWEPT [lsort -unique $oKUNSWEPT]
    # the reused arms this band drives through BOTH verbs on the same database.
    # The ids are request shapes, not arm names; `oKPAIRKIND` carries the
    # `cross_msg` kind each one reaches so the legs can check membership of the
    # DERIVED reused set rather than of a list written here.
    set oKONE {} ; set oKPAIRN 0 ; set oKNOTREUSED {}
    foreach {oKid oKkind2 oKo oKr} [list \
            empty  empty      {{} 0 0.5 0}          {{} 0 1} \
            badtok badtoken   {{v(nosuch)} 0 0.5 0} {{v(nosuch)} 0 1} \
            ds2    dataset    {{v(sq)} 0 0.5 2}     {{v(sq)} 0 1 10 90 1 2} \
            dsneg  allpoints  {{v(sq)} 0 0.5 -1}    {{v(sq)} 0 1 10 90 1 -1} \
            dsfrac intdataset {{v(sq)} 0 0.5 1.5}   {{v(sq)} 0 1 10 90 1 1.5}] {
        incr oKPAIRN
        if {[lsearch -exact $oKreused $oKkind2] < 0} {
            lappend oKNOTREUSED "$oKid=$oKkind2-NOT-IN-DERIVED-REUSED-SET"
        }
        set oKa [mt_call overshoot {*}$oKo]
        set oKb [mt_call riseTime {*}$oKr]
        if {![string equal [mt_msg $oKa] [mt_msg $oKb]]} { lappend oKONE "$oKid=differ" }
    }
    check "MT17/K the refusals this band DRIVES are each asserted by IDENTITY against the `calc::cross_msg` arm they claim and each in the house sentence shape -- never by their words, which are unratified -- and WHAT IS NOT DRIVEN IS ASSERTED TOO, as the exact complement of the verb's own derived arm set, so an arm added to `calc::overshoot` that nobody sweeps reddens here by name rather than sitting outside a row that reads as covering it.  THE ARM SETS COME FROM THE VERB'S BODY, NOT FROM A COUNT IN THIS NAME: the OWN set is asserted exactly, so a new `osh*` arm reddens, the REUSED set carries a ratchet floor, and the arms driven through BOTH verbs -- a declared SUBSET, each member asserted to be in the derived reused set, with its own floor so the subset cannot shrink to nothing -- are BYTE-IDENTICAL to what `calc::riseTime` answers for the same request on the same database, which is the one-voice property.  The own arms are asserted NON-identical to their `cross` counterparts: a future generalisation that merged them would redden band MT9b with a puzzle instead of here with a name.  Both sweep counts ride along so an empty table cannot pass" \
        [list $oP [mt_atleast $oKN 10] [mt_atleast $oKPAIRN 5] $oKBAD $oKONE \
              $oKown [mt_atleast [llength $oKreused] 10] $oKNOTREUSED $oKUNSWEPT \
              [string equal [pcall calc::cross_msg oshnoswing {} 1] \
                            [pcall calc::cross_msg noswing {} 1]] \
              [string equal [pcall calc::cross_msg oshbadref nan] \
                            [pcall calc::cross_msg badref nan]] \
              [string equal [pcall calc::cross_msg oshzeroswing 0.5] \
                            [pcall calc::cross_msg zeroswing 0.5]] \
              [mt_infamily [pcall calc::cross_msg oshnoextremum] [mt_crossmsg_families]] \
              [mt_family [pcall calc::cross_msg oshnoextremum]] \
              [mt_family [pcall calc::cross_msg oshbadref nan]]] \
        [list $oPW atleast10 atleast5 {} {} \
              {oshbadref oshnoextremum oshnoswing oshtinystep oshzeroswing} \
              atleast10 {} \
              {engine noname stale} \
              0 0 0 known Overshoot Overshoot]

    # --- K2: the REQUEST refusals happen with NO DATABASE LOADED at all ------
    pcall xschem raw clear
    set oK2 {} ; set oK2N 0
    foreach {oK2i oK2f} [list {} 0.5   0 {}   nan 0.5   0 nan   inf 0.5   0.5 0.5] {
        incr oK2N
        set oK2a [mt_call overshoot {v(sq)} $oK2i $oK2f 0]
        if {[mt_disp $oK2a] ne {refused}} { lappend oK2 "($oK2i,$oK2f)=[mt_disp $oK2a]" ; continue }
        if {[string equal [mt_msg $oK2a] [pcall calc::cross_msg nodata]]} {
            lappend oK2 "($oK2i,$oK2f)=NODATA"
        }
        if {[mt_shape [mt_msg $oK2a]] ne {ok}} { lappend oK2 "($oK2i,$oK2f)=shape" }
    }
    set oK2OK [mt_call overshoot {v(sq)} 0 0.5 0]
    check "MT17/K2 every REQUEST refusal happens before anything reaches the database, measured with the database CLEARED: a blank reference on either side, a non-finite one on either side, and an equal pair all answer `refused` with their own sentence and NOT with cross's `nodata`.  A verb that validated after its first engine call would tell the user there is no simulation data when their actual mistake was a blank final value.  ⚠ THE NON-VACUITY LEG IS THE GATE ORDER ITSELF: with both references well formed and nothing loaded the answer IS `nodata`, carried by identity against the arm and against what riseTime answers for the same database" \
        [list $oP [mt_atleast $oK2N 6] $oK2 [mt_disp $oK2OK] \
              [string equal [mt_msg $oK2OK] [pcall calc::cross_msg nodata]] \
              [string equal [mt_msg $oK2OK] [mt_msg [mt_call riseTime {v(sq)} 0 1]]]] \
        [list $oPW atleast6 {} refused 1 1]
    pcall mt_load tran

    # --- L: the sweep is REQUIRED although the answer never uses it ----------
    pcall mt_load op
    set oLa [mt_call overshoot {v(sq)} 0 0.5 0]
    set oLb [mt_call riseTime {v(sq)} 0 1]
    set oLalt [mt_osh_ref {v(sq)} 0 0.5 0]
    check "MT17/L the sweep is REQUIRED although the answer never uses it, so the whole family refuses the operating-point plot in ONE VOICE -- asserted by IDENTITY against what calc::riseTime answers for the same database rather than against a sentence re-spelled here.  ⚠ THE CHOICE IS MADE VISIBLE RATHER THAN HIDDEN: this file derives, on the same database, that an answer really WAS available -- a finite number off the single DC point -- and the verb refused anyway.  An overshoot is a statement about a TRANSITION and one DC point has none; a user clicking four verbs of this family on one database must not get three refusals and one number; and a refusal can be relaxed later while a shipped number cannot be withdrawn.  Nothing here proves that is the better product behaviour, which is why limit L7 declares it" \
        [list $oP [mt_disp $oLa] [mt_disp $oLb] \
              [string equal [mt_msg $oLa] [mt_msg $oLb]] \
              [string equal [mt_msg $oLa] [pcall calc::cross_msg nosweep op]] \
              [mt_shape [mt_msg $oLa]] [mt_finite $oLalt]] \
        [list $oPW refused refused 1 1 ok 1]

    # --- M: the `ac` read, which cross's own ac arm is declared unable to fence
    pcall mt_load ac
    set oMa [mt_call overshoot {im(lp)} 0 -0.3 0]
    set oMb [mt_call overshoot {v(lp)} 1.2 0.9 0]
    set oMc [mt_call overshoot {v(ramp)} 0 0.5 0]
    check "MT17/M the `ac` read, which `calc::cross`'s own ac arm is DECLARED unable to fence because its answer is an X -- this verb's answer has no X in it, so this is the one arm of the family that is measurable.  Two columns, both against this file's derivation and distinct from each other, both driven with a FALLING step so the minimum is the extremum on a magnitude column.  ⚠ THE UNDRIVEN-MAGNITUDE TRAP IS EXCLUDED BY NAME AND BY MEASUREMENT rather than by luck: v(ramp) sits on the engine's 1e-35 magnitude floor across the whole ac sweep, so its column is CONSTANT -- asserted here as `same` over the column's own adjacent pairs -- and any answer taken off it would be an artefact of the floor and not of the signal" \
        [list $oP [mt_is $oMa [mt_osh_ref {im(lp)} 0 -0.3 0]] \
              [mt_is $oMb [mt_osh_ref {v(lp)} 1.2 0.9 0]] \
              [mt_distinct [mt_val $oMa] [mt_val $oMb]] \
              [mt_osh_which 0 -0.3] [mt_osh_which 1.2 0.9] \
              [mt_alldistinct [mt_col v(ramp) 0]] \
              [mt_is $oMc [mt_osh_ref {v(ramp)} 0 0.5 0]]] \
        [list $oPW ok ok distinct min min same ok]
    pcall mt_load tran

    # --- N: R402, no temporary survives ANY exit path ------------------------
    set oNL {} ; set oNN 0 ; set oND {}
    foreach oNargs [list [list {v(sq)} 0 0.5 0] [list {v(sq)} {} 0.5 0] \
                         [list {v(sq)} nan 0.5 0] [list {v(sq)} 0.5 0.5 0] \
                         [list {} 0 0.5 0] [list {v(nosuch)} 0 0.5 0] \
                         [list {v(sq)} 0 0.5 2] [list {v(sq)} 0 0.5 -1] \
                         [list {v(sq)} 0 0.5 1.5] [list $oINF 0 1 0] \
                         [list {v(sq) -1 del()} 0 0.5 0] \
                         [list {v(sq) 1e300 * 1e300 *} 0 0.5 0]] {
        incr oNN
        set oNa [mt_call overshoot {*}$oNargs]
        lappend oND [mt_disp $oNa]
        if {[llength [leaked]]} { lappend oNL "$oNN/[mt_disp $oNa]:[leaked]" }
    }
    check "MT17/N R402: no __calc_tmp* survives any exit path THIS ROW DRIVES -- a request set enumerated in the loop above and NOT derived from the proc's own returns, so the coverage claim is the enumeration and nothing more: the measured request, the request-level refusals, the empty expression, the bad token, the bad datasets and the absence, each checked IMMEDIATELY after its own call so a leak names the disposition that left it.  The set size is a FLOOR and the dispositions reached are asserted as a SET, so a request deleted from the loop and a loop that only ever refuses both redden here.  The __mt_* probe prefix is watched separately, so a probe that forgot to clean up is reported as a SUITE defect and never as a product leak, and no probe proc is left in the product's own namespace" \
        [list $oP $oNL [mt_atleast $oNN 12] [lsort -unique $oND] \
              [leaked] [probeleft] [info procs ::calc::__mt_*]] \
        [list $oPW {} atleast12 {absent measured refused} {} {} {}]

    # --- O: NOT a cross delegate, asserted POSITIVELY ------------------------
    check "MT17/O this verb is NOT a `calc::cross` delegate and that is asserted POSITIVELY rather than left as an absence: it issues the direct engine verb itself, its ::calc:: closure reaches calc::cross NOWHERE, the only direct reader in that closure is the verb itself, and it is a member of ALL FIVE of SR5's derived sets -- mint, add, read, delete and pre-flight -- so a door opened without one of the four obligations names which one it dropped.  ⚠ The CONTROLS are the instrument working on two verbs whose answers are known: calc::cross is a direct reader that trivially reaches itself, and calc::riseTime reaches cross with no door of its own.  ⚠ This verb must NOT be enlisted in MT10's delegation half -- that band now DERIVES the partition, and this row is the per-verb claim for the half MT10 measures as a population" \
        [list $oP [mt_direct_raw overshoot] [mt_reaches_cross overshoot] \
              [mt_closure_raw overshoot] [mt_osh_doors overshoot] \
              [mt_direct_raw cross] [mt_reaches_cross cross] \
              [mt_direct_raw riseTime] [mt_reaches_cross riseTime] \
              [mt_closure_raw riseTime] [mt_osh_doors riseTime] \
              [mt_osh_doors __mt_nosuch_zz]] \
        [list $oPW yes no overshoot {mint add read del preflight} \
              yes reaches no reaches {} {} NOPROC:calc::__mt_nosuch_zz]

    # --- P: `calc::extremum` is a PURE list predicate ------------------------
    # The decision/act split made a row.  Driven with the database CLEARED, so
    # the direction choice and the finiteness gate are shown to need no engine.
    pcall xschem raw clear
    set oPB {} ; set oPN 0
    foreach {oPl oPmax oPmin} [list \
            {}                 {}    {} \
            {3.5}              3.5   3.5 \
            {-nan 1 2}         2     1 \
            {-nan -nan}        {}    {} \
            {1 inf 2}          2     1 \
            {5 1 2 3 -4}       5     -4 \
            {-4 1 2 3 5}       5     -4 \
            {0 -0.0}           0     0] {
        incr oPN
        set oPa [pcall ::calc::extremum $oPl max]
        set oPi [pcall ::calc::extremum $oPl min]
        if {$oPa ne $oPmax} { lappend oPB "{$oPl}/max={$oPa}want{$oPmax}" }
        if {$oPi ne $oPmin} { lappend oPB "{$oPl}/min={$oPi}want{$oPmin}" }
    }
    check "MT17/P `calc::extremum` is a PURE list predicate -- no xschem, no Tk, no database -- so the DIRECTION choice and the FINITENESS GATE gate on the counted arm with nothing loaded at all, which is the decision/act split made a row.  Driven over hand-built lists covering the shapes the fixture cannot guarantee: empty, one element, nan-FIRST (the seed case), all-nan, inf-containing (the case where an ungated scan WINS a comparison and poisons the answer), and a list whose extrema sit at the two ends in both orders.  ⚠ The `-0.0` list is here because the answer `0` and the answer `-0.0` are the same number and different strings, and this proc must not be the place that normalises one into the other" \
        [list $oP $oPB [mt_atleast $oPN 8] [mt_osh_pure extremum] \
              [mt_osh_pure __mt_nosuch_zz] [mt_direct_raw extremum]] \
        [list $oPW {} atleast8 pure NOPROC:calc::__mt_nosuch_zz no]
    pcall mt_load tran

    # --- Q: the answer's key set is EXACTLY calc::cross's --------------------
    # ⚠ A KEY AND THE ROW THAT ASSERTS ITS KEY SET LAND IN ONE COMMIT.  Derived
    # by comparing the two dicts' key sets rather than by writing either down,
    # for ALL THREE dispositions, so a future widening that gives this verb a
    # `shape` or a `db` has to land its row in the same change instead of
    # meeting this as a gate red and being tempted to weaken it.
    set oQm [mt_call overshoot {v(sq)} 0 0.5 1]
    set oQr [mt_call overshoot {v(sq)} 0.5 0.5 0]
    set oQa [mt_call overshoot $oINF 0 1 0]
    set oQc [mt_call cross {v(sq)} 0.5 1 rising]
    check "MT17/Q the answer's key set is EXACTLY calc::cross's, for all three dispositions, derived by comparing the two dicts' own key sets rather than by writing this verb's down -- so a wiring that put a live value in a retired key, or a rebuilt dict that dropped `absent` and broke the refused/absent split one layer up, reddens here.  `dataset` is the one the caller asked for, `dest` holds the RETIRED temporary the measurement evaluated into on the two paths that minted one and is empty on a request refused before the mint, and there is NO `shape` key -- a declared `shape wave` would route a scalar into a destination.  ⚠ THE LAST LEG PINS `cross`'s OWN SET as a NON-VACUITY CONTROL and not as this verb's expectation: without it the three identity legs are green over two dicts that both answer an EMPTY key set, which is what a sentinel from a missing proc looks like.  ⚠ COMPARED WITH `string equal` AND NOT with this file's list comparator, which is NUMERIC: `near absent absent` answers a NOTANUMBER sentinel, so mt_cmpword reports `distinct` for two identical key sets -- measured on the first green run, where it was this row alone that failed" \
        [list $oP [string equal [mt_keys $oQm] [mt_keys $oQc]] \
              [string equal [mt_keys $oQr] [mt_keys $oQc]] \
              [string equal [mt_keys $oQa] [mt_keys $oQc]] \
              [expr {[catch {dict exists $oQm shape} oQh] ? {NOTADICT} : $oQh}] \
              [mt_key $oQm dataset] [mt_tmpname [mt_key $oQm dest]] \
              [mt_key $oQr dest] [mt_key $oQm msg] [mt_key $oQm absent] \
              [mt_keys $oQc]] \
        [list $oPW 1 1 1 0 1 tmp {} {} 0 {absent dataset dest msg ok value}]

    # --- R: the SURFACE and the SINK -----------------------------------------
    check "MT17/R `calc::arg_surface overshoot` answers the VERB and there is NO `_scalar` wrapper, which is a decision rather than an omission: this verb answers one number for every well-formed request -- no ordinal, no per-cycle case, no series -- so a wrapper would have nothing to do.  ⚠ MINTING ONE LATER SILENTLY REDIRECTS EVERY CLICK, because arg_surface is literally `if ::calc::<name>_scalar exists return it` and is not opt-in, so the ABSENCE is asserted rather than left as a fact about today's tree.  calc::fn_sink routes the three dispositions to buffer / refusal / refusal and to nothing else, and the CONTROLS are riseTime and dutyCycle, which DO have wrappers, so the row is a claim about this verb and not about arg_surface" \
        [list $oP [mt_surface overshoot] \
              [llength [info procs ::calc::overshoot_scalar]] \
              [mt_sink [mt_call overshoot {v(sq)} 0 0.5 0]] \
              [mt_sink [mt_call overshoot {v(sq)} 0.5 0.5 0]] \
              [mt_sink [mt_call overshoot $oINF 0 1 0]] \
              [mt_surface riseTime] [mt_surface dutyCycle]] \
        [list $oPW overshoot 0 buffer refusal refusal riseTime_scalar dutyCycle_scalar]

    check "MT17/Z R402 the band left no __calc_tmp*, no __mt_* column and no probe proc behind -- the hygiene claim for an instrument that mints columns in the product's own inventory, and a row rather than a habit because MT10 and MT11 both derive over ::calc:: and would measure a leftover probe as a product proc.  This is the one row here that is green with no feature present" \
        [list [leaked] [probeleft] [info procs ::calc::__mt_*]] {{} {} {}}
    pcall xschem raw clear
}

# ---------------------------------------------------------------------------
# BAND MT18's REQUEST SET AND ITS ORDINAL SWEEP, both read off something that
# recomputes itself -- the interpreter for the percentages, the column for the
# ordinals.
# ---------------------------------------------------------------------------

# `{pctlo pcthi}` AS THE VERB ITSELF DEFAULTS THEM, with `info default` and
# never a literal -- the pair a user reaches by opening the argument dialog and
# pressing go without touching the percentage fields.  A verb that loses,
# renames or empties either default answers a sentinel, so the row reddens
# instead of driving an empty percentage through `sq_thr`.
proc mt_rt_defpct {verb} {
    set out {}
    foreach f {pctlo pcthi} {
        set d [ag_default $verb $f]
        if {[regexp {^(NOPROC|RAISED):} $d]} { return $d }
        if {[lindex $d 0] ne {1}} { return "NODEFAULT:$verb.$f" }
        lappend out [lindex $d 1]
    }
    return $out
}
# `differ`, or a sentinel carrying the pair, so a row driving two percentage
# pairs can show they are two and not one request driven twice.
proc mt_pairsdiffer {a b} {
    if {$a eq $b} { return "SAMEPAIR:{$a}" }
    return differ
}
# the k-th rise time an UNBOUNDED pairing reports, as a number or a sentinel.
# A COMPARAND for a distinctness leg and never an expectation -- see
# `mt_pair_unbounded`, whose answer this indexes.
proc mt_pair_dv {pr i} {
    set a [mt_at $pr [expr {2*$i}]]
    set b [mt_at $pr [expr {2*$i+1}]]
    if {![mt_finite $a] || ![mt_finite $b]} { return "NOTANUMBER:{$a}|{$b}" }
    return [expr {double($b) - double($a)}]
}

# ⚠⚠ EVERY ORDINAL THE START-CROSSING LIST ADMITS, POSITIVE AND NEGATIVE,
# AGAINST THE DISPOSITION `mt_pair_scan` IMPLIES FOR IT.  The POPULATION is the
# crossing list's own length, derived from the column at run time, so a fixture
# with more or fewer rising edges changes what is driven and nothing here needs
# editing -- the hand-kept-list defect one level up, which this file has paid for
# elsewhere.  The EXPECTATION per ordinal is the sample scan's, which is the
# derivation with no product pairing in it: an ordinal is `measured` exactly when
# the crossing it names is one the scan closed.
#
# ⚠ BOTH SIGNS, because the two spellings reach the verb's ordinal arm through
# `calc::cross`'s two scan directions and the bound has to hold in both.  The
# negative spelling of the i-th crossing of n is `i - n - 1`.
#
# Answers {<disposition words> <message words> <absences>}: the `lsort -unique`
# of one word per ordinal -- `measured`/`absent` where the verb agrees with the
# derivation and `ord<k>:<got>-want-<want>` where it does not -- the
# `lsort -unique` of one word per absence, `nohigh` where the sentence is
# EXACTLY the one `calc::cross_msg` builds for that ordinal and `ord<k>:MSG`
# otherwise, and the NUMBER of ordinals that answered an absence.  That last
# term is a count, so no row may compare it against a literal: it is there to be
# compared BETWEEN two percentage pairs.
proc mt_rt_ordsweep {rpn lo hi plo phi xs ys} {
    if {![mt_finite $plo] || ![mt_finite $phi]} { return "NOTAPCT:{$plo}|{$phi}" }
    set llo [sq_thr $lo $hi $plo]
    set lhi [sq_thr $lo $hi $phi]
    set los [mt_derive_x $xs $ys $llo rising]
    set closed [mt_pair_starts [mt_pair_scan $xs $ys $llo $lhi rising]]
    set n [llength $los]
    if {$n < 2} { return "TOOFEWSTARTS:$n" }
    set words {} ; set msgs {} ; set nabs 0
    for {set i 1} {$i <= $n} {incr i} {
        set x [lindex $los [expr {$i - 1}]]
        set want absent
        foreach c $closed {
            if {[mt_distinct $c $x] eq {same}} { set want measured ; break }
        }
        foreach k [list $i [expr {$i - $n - 1}]] {
            set a [mt_call riseTime $rpn $lo $hi $plo $phi $k]
            set d [mt_disp $a]
            if {$d ne $want} { lappend words "ord$k:$d-want-$want" ; continue }
            lappend words $d
            if {$want ne {absent}} continue
            incr nabs
            set named {}
            foreach arm {nohigh nohighin} {
                if {[string equal [mt_msg $a] \
                         [pcall calc::cross_msg $arm [pcall calc::cross_ordinal $k]]]} {
                    set named $arm ; break
                }
            }
            if {$named ne {}} {
                lappend msgs $named
            } else {
                lappend msgs "ord$k:MSG"
            }
        }
    }
    return [list [lsort -unique $words] [lsort -unique $msgs] $nabs]
}
# ⚠⚠ THE PAIRING RULE'S CALL SITES, FROM THE INTERPRETER'S OWN PARSED BODIES
# AND NOT FROM A FILE SCAN.  `<tail>:<n>` per `::calc::` proc whose DECOMMENTED
# body names `calc::transition_end`, sorted -- so the population is the whole
# namespace as the interpreter holds it and a fifth caller enlists itself.
#
# ⚠ `strip` 0 ANSWERS THE SAME POPULATION WITHOUT `mt_decomment`, and it is a
# DISCRIMINATION COMPARAND rather than a second opinion: the prose inside these
# two verbs' bodies names this proc several times in order to say that the rule
# lives in it, so an unstripped count is larger and is counting the comments as
# evidence.  That is the defect a sibling suite's signature pin shipped for a
# month -- a predicate scanning text sees every occurrence, including the ones in
# prose about the predicate.
#
# ⚠ DECLARED LIMIT, not chased: a caller that RE-INLINES the loop instead of
# calling this proc names nothing and is invisible here.  MT18/F covers that
# behaviourally for the requests it drives, and no text-shaped predicate could
# cover it in general.
proc mt_tend_sites {{strip 1}} {
    set out {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        if {[catch {info body $p} b]} continue
        if {$strip} { set b [mt_decomment $b] }
        set n [regexp -all \
                   {(?:^|[^A-Za-z0-9_:])(?:::)?calc::transition_end[^A-Za-z0-9_]} $b]
        if {$n > 0} { lappend out "[namespace tail $p]:$n" }
    }
    return [lsort $out]
}
proc mt_rt_ordwords {s} { return [mt_rt_get $s 0] }
proc mt_rt_ordmsgs  {s} { return [mt_rt_get $s 1] }
proc mt_rt_ordabs   {s} { return [mt_rt_get $s 2] }

# =========================================================================
# MT18 -- T2's PAIRING BOUND: an end crossing must belong to the SAME
#         TRANSITION as the start it closes
# =========================================================================
#
# ⚠⚠ WHAT WAS WRONG, STATED AS THE MEASUREMENT RATHER THAN AS A DESCRIPTION.
# `calc::riseTime` and `calc::slewRate` both paired *"the first end crossing
# strictly after this start"*, which is TIMING_CONTRACT T2's own sentence and is
# narrower than T2's own stated PURPOSE -- that a measurement must never
# *"straddle two different transitions and report a rise time that never
# happened"*.  T2's rule guards the shape where the START level is crossed
# several times before the END level once; it is blind to the complementary
# shape, where a transition reaches the start level, FAILS to reach the end
# level and falls back.  There the first end crossing after it belongs to a
# LATER transition, and both verbs answered a confident number with `ok=1` and
# kept the series length.
#
# ⚠⚠ AND THIS FILE'S OWN DERIVATIONS SHARED THE DEFECT BY CONSTRUCTION, WHICH IS
# WHY NO EXISTING ROW COULD SEE IT.  `mt_rt_derive` and `mt_slew_derive` walked
# the two crossing lists with the IDENTICAL loop, so the comparand agreed with
# the product on exactly the axis the rows were measuring.  Both now pair through
# `mt_pair_scan`, a single pass over the SAMPLES that holds at most one open
# transition and in which the defect is not expressible.  The disagreement
# between the two readings is this band's evidence and is computed, not claimed:
# `mt_pair_unbounded` is kept for that one purpose and is never an expectation.
#
# ⚠ THE COLUMN IS `{v(sq) v(ramp) *}` WITH `lo` 0 AND `hi` 10, AND THE
# PERCENTAGES ARE WHAT MAKE THE SHAPE.  The three rising excursions of that
# product peak at roughly 1.1, 5.1 and 9.1 V, so a start threshold below the
# first peak is crossed three times while an end threshold above it is crossed
# fewer -- the first excursion never reaches the end level.  Every count below is
# derived from the column at run time; none is written into a row name.
#
# ⚠⚠ TWO PERCENTAGE PAIRS, NOT ONE, AND THE SECOND IS THE VERB'S OWN DEFAULT.
# Rows A to D and F to G drive the pair this band CHOSE, where two of the three
# transitions still complete; row E drives that pair AND the pair
# `calc::riseTime` defaults `pctlo`/`pcthi` to, read with `info default` -- which
# is what a user gets by opening the argument dialog and pressing go, and on this
# column collapses FURTHER than the chosen pair.  That magnitude is a row and not
# a sentence: E compares the two pairs' series lengths and absence counts against
# each other every run, so neither figure is written down anywhere.
#
# ⚠ THE BOUND'S COST IS DECLARED AND IS NOT FENCEABLE AS A DEFECT, because the
# two shapes are the same data: a wobbling start and a failed transition present
# the identical pair of crossing lists.  Hole H12 records it.
group MT18 {
    pcall mt_load tran
    set t18T   [mt_col time 0]
    set t18R   {v(sq) v(ramp) *}
    set t18TCL [mt_prod [mt_col v(sq) 0] [mt_col v(ramp) 0]]
    set t18ENG [mt_addcol __mt_t18prod $t18R 0]
    set t18LO 0 ; set t18HI 10 ; set t18PL 5 ; set t18PH 30
    lassign [mt_slew_levels $t18LO $t18HI $t18PL $t18PH rising] t18L1 t18L2
    set t18D  [mt_slew_derive $t18T $t18TCL $t18LO $t18HI $t18PL $t18PH rising]
    set t18U  [mt_pair_unbounded $t18T $t18TCL $t18L1 $t18L2 rising]
    # ⚠ THE UNBOUNDED READING'S FIRST POINT, COMPUTED OUTSIDE THE ROWS AND
    # GUARDED, because a command substitution inside a braced `expr` that answers
    # a sentinel raises *invalid bareword*, which `group`'s catch turns into an
    # ABANDONED BAND rather than one failed row.  It is a COMPARAND for a
    # distinctness leg and never an expectation.
    set t18DV [mt_slew_dv $t18LO $t18HI $t18PL $t18PH rising]
    set t18STEAL NOSTEAL
    set t18STEALRT NOSTEAL
    if {[llength $t18U] >= 2 && [mt_finite $t18DV] \
            && [mt_finite [lindex $t18U 0]] && [mt_finite [lindex $t18U 1]]} {
        set t18STEALRT [expr {double([lindex $t18U 1]) - double([lindex $t18U 0])}]
        if {$t18STEALRT != 0.0} { set t18STEAL [expr {$t18DV / $t18STEALRT}] }
    }

    # --- A: the fixture really is the failing-transition shape --------------
    # ⚠ WITHOUT THIS ROW EVERY ROW BELOW IS VACUOUS, and the leg that matters
    # most is the last one: the bounded and the unbounded readings must pair a
    # DIFFERENT NUMBER of transitions on this column, or the band is measuring
    # two spellings of one answer.
    check "MT18/A the column drives the shape no other row in this file reaches, derived from the column at run time: the engine's minted product agrees with the Tcl one element-wise, the start level is crossed three times rising and the end level twice, the sample-scan pairing closes TWO transitions while the unbounded first-end-after-the-start reading closes THREE, and the two X axes have no duplicate -- so the two readings really disagree here and every row below discriminates" \
        [list [mt_cmpword $t18ENG $t18TCL] \
              [llength [mt_derive_x $t18T $t18TCL $t18L1 rising]] \
              [llength [mt_derive_x $t18T $t18TCL $t18L2 rising]] \
              [llength [mt_sl_y $t18D]] \
              [expr {[llength $t18U] / 2}] \
              [mt_nodup [mt_sl_x $t18D]] \
              [mt_nodup [mt_pair_starts $t18U]]] \
        {same 3 2 2 3 nodup nodup}

    # --- B: `calc::transition_end` as a UNIT, with no engine in it ----------
    # ⚠ HAND-MADE LISTS, which is the only way to drive the rule's own corner
    # cases -- an end landing bit-exactly ON the next start, two ends inside one
    # window, an end before the first start -- none of which the fixture has.
    # The formals are pinned with `info args` and never with a text scan, which
    # is the house rule a sibling row's dead signature pin cost a month to learn.
    check "MT18/B the pairing rule as a UNIT over hand-made lists, with no engine and no fixture in it: a start whose end lies inside its own window pairs, a start whose first later end lies AT or AFTER the next start answers the empty string, the LAST start has no bound and pairs with any later end, two ends inside one window take the FIRST of them -- which is the high-side ringing reading and is what a last-start-before-each-end rule would get wrong -- and an end before the only start, an empty end list and a start with nothing after it all answer the empty string.  The formals are read off info args" \
        [list [mt_formals transition_end] \
              [pcall calc::transition_end {1 5 9} {5.2 9.2} 1] \
              [pcall calc::transition_end {1 5 9} {5.2 9.2} 5] \
              [pcall calc::transition_end {1 5 9} {5.2 9.2} 9] \
              [pcall calc::transition_end {1 5} {5} 1] \
              [pcall calc::transition_end {1} {2 3} 1] \
              [pcall calc::transition_end {5} {1} 5] \
              [pcall calc::transition_end {1} {} 1] \
              [pcall calc::transition_end {1 5} {0.5} 1]] \
        [list {starts ends x0 whyvar} {} 5.2 9.2 {} 2 {} {} {}]

    # --- C: `slewRate`'s series, and the stolen number is NOT in it ---------
    check "MT18/C slewRate at nth 0 answers one point per COMPLETED transition: the series and its X agree element for element with the sample-scan derivation, the point count is SHORTER than the start-crossing list so a point really dropped, every element is strictly positive on a rising request, and the number the unbounded pairing would have put FIRST is DISTINCT at MTTOL from every element of the answer -- which is the leg that fails if the bound is removed, computed from the column rather than quoted" \
        [list [mt_islist [set t18a [mt_call slewRate $t18R $t18LO $t18HI $t18PL $t18PH 0 rising 0]] \
                   [mt_sl_y $t18D]] \
              [mt_listcmp [mt_key $t18a sweep] [mt_sl_x $t18D]] \
              [mt_sized [mt_len [mt_val $t18a]] [llength [mt_sl_y $t18D]]] \
              [mt_excess [mt_sl_ns $t18D] [llength [mt_sl_y $t18D]] 1] \
              [mt_signs [mt_val $t18a]] \
              [mt_finite $t18STEAL] \
              [mt_distinctmap [mt_val $t18a] $t18STEAL]] \
        {ok ok sized atleast1 pos 1 distinct}

    # --- D: the occurrence whose transition fails is an ABSENCE -------------
    check "MT18/D the ORDINAL path agrees with the series: the occurrence whose transition never reaches the second threshold is an ABSENCE in calc::cross_msg's slewnoend arm, asserted by identity against the sentence that proc builds for that ordinal and direction, while occurrences 2 and 3 MEASURE the series' own two elements in order -- so the bound is in the ordinal arm too and not only in the nth-0 one, and the absence is the verb's own and not calc::cross's" \
        [list [mt_disp [set t18b [mt_call slewRate $t18R $t18LO $t18HI $t18PL $t18PH 1 rising 0]]] \
              [string equal [mt_msg $t18b] \
                   [pcall calc::cross_msg slewnoend [pcall calc::cross_ordinal 1] rising]] \
              [mt_disp [set t18c [mt_call slewRate $t18R $t18LO $t18HI $t18PL $t18PH 2 rising 0]]] \
              [mt_is $t18c [mt_at [mt_sl_y $t18D] 0]] \
              [mt_disp [set t18d [mt_call slewRate $t18R $t18LO $t18HI $t18PL $t18PH 3 rising 0]]] \
              [mt_is $t18d [mt_at [mt_sl_y $t18D] 1]] \
              [mt_distinct [mt_at [mt_sl_y $t18D] 0] [mt_at [mt_sl_y $t18D] 1]]] \
        {absent 1 measured ok measured ok distinct}

    # --- E: SHIPPED `riseTime`, OVER A REQUEST SET AND NOT OVER ONE CASE ----
    # ⚠ THIS IS THE HALF THAT MATTERS MOST, because `riseTime` is committed,
    # gated and in front of users: it carried the identical loop and therefore
    # the identical defect, and its numbers on this column MOVED when the bound
    # landed.  The absence here is the `nohigh` arm, which is `riseTime`'s own.
    #
    # ⚠⚠ THE REQUEST SET IS TWO PERCENTAGE PAIRS AND THE SECOND IS THE VERB'S
    # OWN DEFAULT, READ WITH `info default` AND NOT WRITTEN DOWN.  An earlier
    # revision of this row drove the band's chosen pair ALONE, and the pair a
    # user actually gets -- open the argument dialog, press go, touch no
    # percentage field -- was asserted NOWHERE.  That was not a cosmetic gap:
    # BUILT as a probe that drops the bound for a start list of three against an
    # end list of one, the default pair's answer goes back to the unbounded
    # reading while this band's own pair is untouched, and the whole file passed
    # over it.  `mt_rt_defpct` closes that by construction, because the request
    # follows the formal.
    #
    # ⚠ HOW FAR THE TWO PAIRS COLLAPSE IS A ROW TOO, AND IT IS THE COMPARISON
    # THAT IS ASSERTED RATHER THAN EITHER FIGURE: the default pair's series is
    # SHORTER than this band's and its absences MORE NUMEROUS, both derived every
    # run, with the two pairs asserted DIFFERENT so neither leg can be one
    # request driven twice.  Writing either count into the row would put a
    # reproducible number in the T1 verdict, which is the house rule
    # `mt_strictwords` exists for.
    set t18PD [mt_rt_defpct riseTime]
    set t18EOUT {} ; set t18ELEN {} ; set t18EABS {}
    foreach t18p [list [list $t18PL $t18PH] $t18PD] {
        lassign $t18p t18pl t18ph
        set t18rd [mt_rt_derive $t18T $t18TCL $t18LO $t18HI $t18pl $t18ph]
        set t18sw [mt_rt_ordsweep $t18R $t18LO $t18HI $t18pl $t18ph $t18T $t18TCL]
        set t18uu [mt_pair_unbounded $t18T $t18TCL \
                       [sq_thr $t18LO $t18HI $t18pl] [sq_thr $t18LO $t18HI $t18ph] rising]
        set t18e [mt_call riseTime $t18R $t18LO $t18HI $t18pl $t18ph 0]
        lappend t18EOUT \
            [mt_islist $t18e [mt_rt_y $t18rd]] \
            [mt_listcmp [mt_key $t18e sweep] [mt_rt_x $t18rd]] \
            [mt_excess [mt_rt_nlo $t18rd] [mt_len [mt_val $t18e]] 1] \
            [mt_nonneg [mt_val $t18e]] \
            [mt_rt_ordwords $t18sw] \
            [mt_rt_ordmsgs $t18sw] \
            [mt_distinctmap [mt_val $t18e] [mt_pair_dv $t18uu 0]]
        lappend t18ELEN [mt_len [mt_val $t18e]]
        lappend t18EABS [mt_rt_ordabs $t18sw]
    }
    check "MT18/E shipped riseTime over a request set whose second member is the verb's OWN default percentage pair, read with info default so the request follows the formal: for EACH pair the nth-0 series and its X agree element for element with the sample-scan derivation, the point count is short of the start-crossing list, every element is non-negative, EVERY ordinal that list admits -- both signs, population derived from the column -- carries the disposition the sample scan implies and every absence carries EXACTLY the sentence calc::cross_msg builds for its own ordinal in whichever of riseTime's TWO absence arms the derivation names -- on this column that is nohighin for every absence in both pairs, because a later excursion's high crossing always exists -- and the unbounded pairing's first rise time is DISTINCT at MTTOL from every element of the answer.  Then the two pairs are COMPARED rather than quoted: the default pair's series is shorter and its absences more numerous, with the pairs asserted different so neither leg is one request driven twice" \
        [list $t18EOUT \
              [mt_finite [lindex $t18PD 0]] [mt_finite [lindex $t18PD 1]] \
              [mt_pairsdiffer [list $t18PL $t18PH] $t18PD] \
              [mt_excess [lindex $t18ELEN 0] [lindex $t18ELEN 1] 1] \
              [mt_excess [lindex $t18EABS 1] [lindex $t18EABS 0] 1]] \
        [list [concat {ok ok atleast1 nonneg} [list {absent measured} nohighin distinct] \
                      {ok ok atleast1 nonneg} [list {absent measured} nohighin distinct]] \
              1 1 differ atleast1 atleast1]

    # --- F: THE SABOTAGE, BUILT RATHER THAN ARGUED -------------------------
    # ⚠⚠ `calc::transition_end` IS REPLACED BY THE EXACT LOOP ALL FOUR SITES
    # USED TO CARRY INLINE -- *"the first end strictly after the start"* -- and
    # all four requests are driven through it.  That is two claims in one row and
    # the second is the one no structural scan could make: if any of the four
    # sites still had a loop of its own, that request's answer would NOT move
    # when this proc is swapped.  All four move.  The counter rides along so a
    # swap that was never reached cannot read as a pass, and the slot is checked
    # and restored on both exit paths.
    set t18SAB [mt_tend_unbounded {
        return [list [mt_len [mt_val [mt_call slewRate $t18R $t18LO $t18HI $t18PL $t18PH 0 rising 0]]] \
                     [mt_disp [mt_call slewRate $t18R $t18LO $t18HI $t18PL $t18PH 1 rising 0]] \
                     [mt_len [mt_val [mt_call riseTime $t18R $t18LO $t18HI $t18PL $t18PH 0]]] \
                     [mt_disp [mt_call riseTime $t18R $t18LO $t18HI $t18PL $t18PH 1]] \
                     [mt_atleast $::mt_tend_calls 4]]
    }]
    check "MT18/F THE SABOTAGE: with calc::transition_end replaced by the unbounded first-end-after-the-start loop the four sites used to carry inline, slewRate's series grows to the unbounded pairing's own length, its occurrence 1 becomes a MEASURED number where the bound makes it an absence, and riseTime's two requests move the same way -- so all four call sites really go through that one proc, which no structural scan could establish.  The call counter and the restored slot ride along, and the two legs after the probe show calc::transition_end answers the shipped bound again" \
        [list $t18SAB \
              [expr {[llength $t18U] / 2}] \
              [pcall calc::transition_end {1 5 9} {5.2 9.2} 1] \
              [llength [info commands ::mt_tend_keep]]] \
        [list [list 3 measured 3 measured atleast4] 3 {} 0]

    # --- G: THE CONTROL -- the bound is INERT where it must be --------------
    # ⚠ A BOUND THAT CHANGED THE RINGING READING WOULD BE A REGRESSION, not a
    # repair, and this is the row that says it does not.  The ringing column
    # MT9c mints crosses the HIGH threshold twice per edge inside one
    # transition, which is exactly the shape the bound must leave alone: both
    # high crossings fall before the next low crossing, so the first is still
    # the one taken.  Driven here as well as in MT9c on purpose -- MT9c would
    # have reddened for this, but a control belongs in the band whose claim it
    # bounds.
    set t18RN 3
    set t18RR [mt_ringrpn $t18T $t18RN]
    set t18RC [mt_ringcol $t18T $t18RN]
    set t18RRD [mt_rt_derive $t18T $t18RC [mt_ringfloor] 1 10 90]
    check "MT18/G THE CONTROL: on a column that RINGS at the top -- one rising edge per period whose high threshold is crossed TWICE inside a single transition -- the bound changes nothing, because both high crossings fall before the next low one.  The high crossings outnumber the low ones, the series is as long as the low-crossing list so NO point dropped, it agrees element for element with the sample-scan derivation, and its X has no duplicate -- the duplicate a last-start-before-each-end pairing would produce here" \
        [list [mt_cmpword [mt_addcol __mt_t18ring $t18RR 0] $t18RC] \
              [mt_excess [mt_rt_nhi $t18RRD] [mt_rt_nlo $t18RRD] 1] \
              [mt_sized [llength [mt_rt_y $t18RRD]] [mt_rt_nlo $t18RRD]] \
              [mt_islist [set t18i [mt_call riseTime $t18RR [mt_ringfloor] 1 10 90 0]] \
                   [mt_rt_y $t18RRD]] \
              [mt_nodup [mt_key $t18i sweep]]] \
        {same atleast1 sized ok nodup}

    # --- H: ONE IMPLEMENTATION, over a population the interpreter holds ----
    # ⚠ MT18/F SWAPS THE PROC AND DRIVES FOUR FIXED REQUESTS, so it shows that
    # those four paths go through it and says NOTHING about how many paths there
    # are.  The sentences in `calc::transition_end`'s own header and in
    # `calc::slewRate`'s -- *"at one site for all four callers"* -- are a count
    # over the tree, and this is the row that re-measures it every run instead of
    # leaving it as prose.
    check "MT18/H the pairing rule has ONE implementation, derived from the INTERPRETER's own parsed bodies rather than from a file scan: over every proc in the ::calc:: namespace the DECOMMENTED bodies naming calc::transition_end are riseTime's and slewRate's and each names it twice, one per arm -- so a fifth caller, a verb that grew a third arm, and a deleted site all move this answer, which is the half MT18/F's four fixed requests cannot see.  The discrimination leg is the UNDECOMMENTED count over the SAME population, which must DIFFER, because these two bodies' own prose names the proc in order to say the rule lives there -- a text predicate that counted those would be reading its own documentation as evidence" \
        [list [mt_tend_sites] \
              [mt_pairsdiffer [mt_tend_sites] [mt_tend_sites 0]]] \
        [list {riseTime:2 slewRate:2} differ]

    check "MT18 R402 the band left no __calc_tmp*, no __mt_* column and no probe proc behind" \
        [list [leaked] [probeleft] [info procs ::calc::__mt_*]] {{} {} {}}
    pcall xschem raw clear
}

# =========================================================================
# MT19 -- A THRESHOLD ON A RAIL THE TRACE SITS AT, which is the limit the
#         `slewRate` header used to deny having
# =========================================================================
#
# ⚠⚠ WHAT THE HEADER USED TO CLAIM.  `calc::slewRate`'s own header said
# *"ABSOLUTE THRESHOLDS NEED NO EXTRA ARGUMENT: `pctlo` 0 with `pcthi` 100 puts
# the two thresholds exactly ON `lo` and `hi`"* and used that as the stated
# reason the reference tool's `initType`/`finalType` pair -- absolute or
# percentage -- is *"deliberately NOT offered"*.  The arithmetic half is true and
# band MT19/C measures it.  The INFERENCE is false in exactly the case it was
# offered for: an absolute threshold on a rail-clamped trace is a level the data
# SITS AT, and what a crossing-based verb reports there is decided by which side
# of the level the stored samples' last bits fell on.
#
# ⚠ THE LIMIT IS `calc::cross_pair`'s AND NOT `slewRate`'s, which is why this
# band drives `cross`, `riseTime`, `slewRate` and `frequency`.  That proc's own
# header has declared the limit all along -- *"a threshold is normally mid-swing
# and exact float equality with it is vanishingly rare outside rail-clamped
# digital traces"* -- and `v(sq)` is such a trace.  Nothing in the product is
# changed by this band; the header's claim was.
#
# ⚠ WHY NO REPAIR, AS A MEASUREMENT RATHER THAN A PREFERENCE.  Row MT19/D builds
# the two candidates and shows both are worse: a tolerance inside
# `calc::cross_pair` needs a SCALE that proc does not have, and a refusal keyed
# to the request alone would have to refuse the `0/100` spelling MT19/C measures
# as exact.  An absolute-threshold mode on a clamped rail needs a
# plateau-DEPARTURE rule rather than a crossing, which is a product decision:
# hole H13.
group MT19 {
    pcall mt_load tran
    set t19T  [mt_col time 0]
    set t19SQ [mt_col v(sq) 0]
    set t19LO 0 ; set t19HI 1
    set t19L0 [sq_thr $t19LO $t19HI 0]
    set t19L1 [sq_thr $t19LO $t19HI 100]

    # --- A: the two rails, derived from the column -------------------------
    check "MT19/A the two rails as the column really stores them, every count derived at run time: the low reference has samples bit-exactly ON it and NONE below it, so the strictly-below side of calc::cross_pair's rising predicate is never satisfied and cross answers an EMPTY crossing list there; the high reference has exactly ONE sample above it inside an otherwise flat plateau, which cross reads as one more rising crossing than the trace has edges AND as a falling crossing of a plateau the deck never leaves.  The low reference is bit-exactly zero, which is where a tolerance relative to the level has no scale at all.  The mid-swing control is the 10 % threshold and NOT the 50 % one, because this trace has a sample bit-exactly ON its own midpoint" \
        [list [mt_railcounts $t19SQ $t19L0] \
              [llength [mt_dustabove $t19SQ $t19L1]] \
              [llength [mt_derive_x $t19T $t19SQ $t19L0 rising]] \
              [mt_len [mt_val [mt_call cross {v(sq)} $t19L0 0 rising 0]]] \
              [mt_len [mt_val [mt_call cross {v(sq)} $t19L1 0 rising 0]]] \
              [mt_len [mt_val [mt_call cross {v(sq)} $t19L1 0 falling 0]]] \
              [expr {$t19L0 == 0.0}] \
              [mt_strictwords $t19T $t19SQ [sq_thr $t19LO $t19HI 10] rising] \
              [mt_strictwords $t19T $t19SQ $t19L1 rising]] \
        [list {62 0 39} 1 0 0 3 1 1 strict {onsample strict}]

    # --- B: what the verbs answer there, and that it is cross's own reading --
    # ⚠ THE SECOND LEG IS THE ONE THAT MATTERS: the falling answer is
    # BIT-IDENTICAL to the slope computed from `cross`'s OWN two crossing
    # answers at the two rails, so the verb is a faithful delegate and the
    # ill-posedness is one layer down.  The third leg says the number is not the
    # deck's, which is the declared limit; it is a DERIVED comparand -- `sq_rt`'s
    # own 0.2 ms edge -- and no figure is written into the row.
    set t19DV [mt_slew_dv $t19LO $t19HI 0 100 falling]
    set t19S  [mt_key [mt_call cross {v(sq)} $t19L1 1 falling 0] value]
    set t19E  [mt_firstafter [mt_val [mt_call cross {v(sq)} $t19L0 0 falling 0]] $t19S]
    # ⚠ THE TWO COMPARANDS ARE BUILT HERE AND GUARDED, NOT AT THE ROW SITE, and
    # that is not tidiness: the first draft divided inside a braced `expr` at the
    # row site, and when a candidate repair to `calc::cross_pair` removed the
    # phantom falling crossing the division met an EMPTY STRING and raised, which
    # `group`'s catch turned into an ABANDONED BAND instead of one failed row --
    # measured, on the very sabotage this band exists to reject.  A row must fail
    # legibly even when what it is measuring has gone away.
    set t19SLOPE NOSLOPE
    set t19DECKSL NODECK
    if {[mt_finite $t19DV] && [mt_finite $t19S] && [mt_finite $t19E] \
            && double($t19E) != double($t19S)} {
        set t19SLOPE [expr {$t19DV / (double($t19E) - double($t19S))}]
    }
    if {[mt_finite $t19DV] && [mt_finite [sq_rt $t19LO $t19HI 0 100]]} {
        set t19DECKSL [expr {$t19DV / [sq_rt $t19LO $t19HI 0 100]}]
    }
    check "MT19/B the absolute-threshold spelling on this trace: the RISING request is an ABSENCE through calc::cross's OWN absent arm by identity, because the low rail has no rising crossing at all; the FALLING request MEASURES, and the number is BIT-IDENTICAL to the slope built out of cross's own two crossing answers at the same two rails -- so the verb delegates faithfully -- while being DISTINCT at MTTOL from the deck's own edge slope, which is the limit this band declares.  riseTime at the same thresholds is distinct from the deck too, from the same cause one layer down" \
        [list [mt_disp [set t19a [mt_call slewRate {v(sq)} $t19LO $t19HI 0 100 1 rising 0]]] \
              [string equal [mt_msg $t19a] \
                   [pcall calc::cross_msg absent [pcall calc::cross_ordinal 1] rising]] \
              [mt_disp [set t19b [mt_call slewRate {v(sq)} $t19LO $t19HI 0 100 1 falling 0]]] \
              [mt_finite $t19SLOPE] [mt_finite $t19DECKSL] \
              [string equal [mt_val $t19b] $t19SLOPE] \
              [mt_distinct [mt_val $t19b] $t19DECKSL] \
              [mt_disp [set t19c [mt_call riseTime {v(sq)} $t19LO $t19HI 10 100 1]]] \
              [mt_distinct [mt_val $t19c] [sq_rt $t19LO $t19HI 10 100]]] \
        {absent 1 measured 1 1 1 distinct measured distinct}

    # --- C: and OFF the rails the same spelling is exact -------------------
    # ⚠ THIS IS THE ROW THE HEADER'S SURVIVING CLAIM LEANS ON, and it is why the
    # limit is stated about the RAIL and not about the percentages.  The column
    # is `v(ramp)` scaled and lifted so that it passes cleanly THROUGH both
    # references, and the deck slope is derived from that column's own endpoints
    # every run rather than written down.
    set t19LR {v(ramp) 1.2 * 1 -}
    set t19RM [mt_col v(ramp) 0]
    set t19DECK [expr {1.2 * (double([mt_at $t19RM end]) - double([mt_at $t19RM 0]))
                       / (double([mt_at $t19T end]) - double([mt_at $t19T 0]))}]
    check "MT19/C off the rails the SAME 0/100 spelling is exact: on a column lifted clear of both references so that it really passes through them, slewRate at 0/100 and at 10/90 both agree with the slope derived from that column's own endpoints, and the two agree with each other -- so the limit MT19/B measures belongs to a threshold ON a value the trace sits at, and not to the percentage spelling.  The crossing of each reference is strictly between two samples here, which is the structural difference from the rail" \
        [list [mt_is [set t19d [mt_call slewRate $t19LR 0 10 0 100 1 rising 0]] $t19DECK] \
              [mt_is [set t19e [mt_call slewRate $t19LR 0 10 10 90 1 rising 0]] $t19DECK] \
              [mt_distinct [mt_val $t19d] [mt_val $t19e]] \
              [mt_strictwords $t19T [mt_affine $t19RM 1.2 -1] 0.0 rising] \
              [mt_strictwords $t19T [mt_affine $t19RM 1.2 -1] 10.0 rising]] \
        {ok ok same strict strict}

    # --- D: why neither candidate repair was taken, BUILT not argued -------
    # ⚠⚠ A TOLERANCE INSIDE `calc::cross_pair` NEEDS A SCALE THAT PROC HAS NOT
    # GOT, and this row builds the counterexample instead of reasoning about it:
    # a column whose whole range is at 1e-15 has crossings `cross` finds
    # correctly, and the level of one of them is SMALLER IN MAGNITUDE than the
    # float dust on `v(sq)`'s own high rail -- so any absolute dust threshold
    # big enough to suppress the rail phantom also erases this real crossing.
    # The relative alternative has no scale either: the low reference is
    # bit-exactly zero, which MT19/A asserts.
    set t19TN {v(ramp) 1e-16 *}
    set t19DUST [mt_dustabove $t19SQ 1.0]
    check "MT19/D the candidate repairs, built rather than argued: a column whose whole range sits at 1e-15 has a real rising crossing of a 1e-16 level and cross finds it, agreeing with this file's own derivation -- and that level is SMALLER IN MAGNITUDE than the single float dust sample on v(sq)'s high rail, so an absolute dust threshold inside calc::cross_pair large enough to suppress the rail phantom erases a real crossing.  This row rules out an ABSOLUTE dust threshold only; the RELATIVE candidate is band MT19/F's, which builds it.  The dust itself is derived from the column, and the ordering is the row's claim rather than either number" \
        [list [mt_disp [set t19f [mt_call cross $t19TN 1e-16 1 rising 0]]] \
              [mt_is $t19f [mt_at [mt_derive_x $t19T [mt_affine $t19RM 1e-16 0] 1e-16 rising] 0]] \
              [mt_sized [llength $t19DUST] 1] \
              [expr {1e-16 < abs(double([lindex $t19DUST 0]) - 1.0)}]] \
        {measured ok sized 1}

    # --- E: the same limit reaches `frequency`, which is a DIFFERENT verb ---
    # ⚠ `frequency` does not pair two levels at all, so the bound of band MT18
    # cannot be what is happening here -- which is the leg that separates the
    # two findings.  At a MID-SWING level the verb answers the deck's own
    # frequency on both periods; at the rail the first period is distinct from
    # it, because the rail crossing of the first edge lands a whole sample step
    # late while the second edge's dust sample puts its crossing in the right
    # place.
    check "MT19/E the limit reaches frequency, which pairs no two levels and so cannot be band MT18's bound: at a mid-swing level every period agrees with the deck's own, at the rail the series has the same length and its FIRST element is DISTINCT at MTTOL from the deck while its LAST agrees -- the asymmetry being which side of the rail the two edges' stored samples fell on, which MT19/A derives" \
        [list [mt_islist [set t19g [mt_call frequency {v(sq)} [sq_thr $t19LO $t19HI 10] rising 0 0]] \
                   [lrepeat 2 [expr {1.0 / 4.0e-3}]]] \
              [mt_disp [set t19h [mt_call frequency {v(sq)} $t19L1 rising 0 0]]] \
              [mt_sized [mt_len [mt_val $t19h]] [mt_len [mt_val $t19g]]] \
              [mt_distinct [mt_at [mt_val $t19h] 0] [expr {1.0 / 4.0e-3}]] \
              [mt_distinct [mt_at [mt_val $t19h] end] [expr {1.0 / 4.0e-3}]]] \
        {ok measured sized distinct same}

    # --- F: CANDIDATE REPAIR (a) BUILT AND MEASURED, NOT ARGUED --------------
    # ⚠⚠ THE TOLERANCE SWEEP IS THE WHOLE ANSWER, AND ITS SAMPLE POINTS ARE
    # DERIVED FROM THE COLUMN'S OWN DUST rather than chosen: the high rail's
    # single excursion above the reference sets the scale, and the four
    # tolerances are that figure divided by ten, itself, and multiplied by ten
    # and a hundred.  MEASURED, and sharper than the argument that sent anyone
    # looking: a TENTH of the high rail's dust already manufactures an extra
    # falling crossing at the LOW reference while still leaving the high rail's
    # arrival a sample step late -- a tolerance that costs and buys nothing -- and
    # the cause is that the scale is PAIR-LOCAL, so one level gets two different
    # tolerances in two adjacent pairs and the low reference is reached in one and
    # not in the other.  A hundred times the dust additionally erases every
    # crossing of a ripple double precision represents exactly.  NO value of the
    # tolerance reaches `deck sized`, and that count is the row's claim.
    #
    # ⚠ AND THE COST TO `test_calc_cross` IS ZERO, MEASURED: every one of that
    # suite's checks passes against this predicate.  So the keystone's own suite is
    # not what would stop this repair -- this row is.
    set t19RIPN 3
    set t19RIP [mt_ripplerpn $t19T $t19RIPN]
    set t19DUST [mt_dustabove $t19SQ $t19L1]
    set t19ARR [sq_rise 1.0 0]
    set t19NED [mt_len [mt_val [mt_call cross {v(sq)} [sq_thr $t19LO $t19HI 10] 0 falling 0]]]
    set t19NRIP [mt_len [mt_val [mt_call cross $t19RIP 1.0 0 rising 0]]]
    set t19EPS {}
    if {[llength $t19DUST] == 1 && [mt_finite [lindex $t19DUST 0]]} {
        set t19d [expr {abs(double([lindex $t19DUST 0]) - double($t19L1))}]
        foreach t19k {0.1 1.0 10.0 100.0} { lappend t19EPS [expr {$t19k * $t19d}] }
    }
    set t19SWEEP {}
    set t19GOOD 0
    foreach t19e $t19EPS {
        set t19v [mt_tolpair_run $t19e [list mt_railverdict {v(sq)} $t19L0 $t19L1 \
                                            $t19ARR $t19NED $t19RIP $t19NRIP]]
        lappend t19SWEEP $t19v
        if {[lrange $t19v 0 1] eq {deck sized}} { incr t19GOOD }
    }
    check "MT19/F candidate repair (a) BUILT: calc::cross_pair made tolerance-aware with the only scale that proc has -- the pair's own magnitude -- and swept over four tolerances DERIVED from the high reference's own dust.  Below the dust nothing moves; at the dust the high reference's arrival becomes the deck's AND the low reference gains a falling crossing the trace has not got, because a pair-local scale gives one level two different tolerances in two adjacent pairs; a hundred times the dust also erases every crossing of a 1e-12 ripple on a unit rail, which is thousands of units in the last place and is represented exactly.  NOT ONE tolerance reaches both halves, which is the count this row asserts, and the shipped predicate is restored afterwards and answers the shipped reading again" \
        [list [mt_sized [llength $t19EPS] 4] \
              [mt_sized $t19NED 2] [mt_sized $t19NRIP 3] \
              $t19SWEEP $t19GOOD \
              [mt_railverdict {v(sq)} $t19L0 $t19L1 $t19ARR $t19NED $t19RIP $t19NRIP] \
              [llength [info commands ::mt_cp_keep]]] \
        [list sized sized sized \
              {{late extra kept} {deck extra kept} {deck extra kept} {deck extra erased}} \
              0 {late sized kept} 0]

    check "MT19 R402 the band left no __calc_tmp*, no __mt_* column and no probe proc behind" \
        [list [leaked] [probeleft] [info procs ::calc::__mt_*]] {{} {} {}}
    pcall xschem raw clear
}

# ---------------------------------------------------------------------------
# MT20 -- THE STATUS LINE'S BUDGET.  Nothing in the tree bounded a sentence this
# stage composes, and one of them put a WRONG NUMBER on screen.
#
# Spec     doc/claude/specs/calculator.md section 8.1 (R506-R509)
# Contract doc/claude/calculator_batch/CLICK_CONTRACT.md, the ratification
#          section -- every sentence this stage ships is collected there.
#
# ⚠⚠ WRITTEN RED-FIRST, AGAINST A TREE WITH NO `calc::status_fit`, NO
# `calc::prov_fit` AND NO `calc::handoff_sentence` IN IT.  Every row below failed
# on that tree and each failure named the missing proc rather than raising; the
# transcript is in the stage receipt.
#
# ---------------------------------------------------------------------------
# WHAT WAS MEASURED, AND WHY A ROW AND NOT A SENTENCE
# ---------------------------------------------------------------------------
#
# `.calc.status.msg` is an `Entry` with `-state readonly`, packed `-fill x` into
# `.calc.status`, so its room is a PIXEL width that moves with the window and a
# FONT the user's Tk resolves.  On the shipped window it renders the opening
# characters of a `TkTextFont` sentence and then simply stops: no ellipsis, no
# scrollbar, `xview` sitting at 0.0, and nothing anywhere to say that there is
# more text.  Two consequences were measured on a real window, and the second is
# the one that matters:
#
#   * a refusal sentence dies mid-word.  Row S24 of
#     tests/headless/test_calc_skeleton.tcl already bounds the catalogue `help`
#     field and the `calc::fn_reason` refusal for exactly this reason -- and it
#     sweeps those two and nothing else, so every sentence `calc::cross_msg`,
#     `calc::arg_msg`, `calc::eval_msg` and `calc::plot_msg` build was bounded
#     by NOTHING.
#   * R421's PROVENANCE line dies mid-NUMBER.  R421 part 2 puts the measured
#     value LAST, so a verb with eight arguments pushes the answer past the end
#     of the entry and the user reads a readable, plausible, wrong-magnitude
#     figure with nothing to say it is a prefix.  That is not an overflow, it is
#     a wrong number on screen.
#
# ⚠ THE UNIT IS CHOSEN BY WHAT EXISTS, which is why this band can be `hcases`.
# `calc::status_room` answers `px <n>` against the real entry when Tk and the
# widget are there and `ch <n>` otherwise, and `calc::status` returns `{}` with
# no window (R508), so EVERY fit a user ever sees goes through the pixel arm.
# This band therefore measures the DECISION -- the elision algorithm, the
# marker, the answer surviving, the hand-off ordering -- on the character arm,
# and the pixel arm's agreement with a real widget belongs to band S28/8 of
# tests/headless/test_calc_skeleton.tcl, which is `dcases` alone.  That is the
# stage-J1 lesson applied in advance: the decision is a pure proc so it gates on
# the counted arm, and the act is declared where only a display can see it.
#
# ⚠ NO WORDING IS ASSERTED ANYWHERE BELOW.  Every sentence here is unratified and
# carries the open `rule` debt against `calc::eval_msg`'s family; the rows assert
# WIDTH, the marker, and which substrings survive -- never the words.
#
# ⚠ AND NO PIXEL FIGURE REACHES AN EXPECTATION.  A width is environment
# dependent -- font, DPI, window size, the user's Tk -- so every width claim
# below goes through `mt_sl_word`, which answers `fits` or `over`.  The numbers
# appear only inside a FAILURE detail, where they are what a reader needs.
# ---------------------------------------------------------------------------

# the message builders, DERIVED from the namespace rather than listed -- a
# hand-kept list is the same defect one level up.
proc mt_sl_builders {} {
    set out {}
    foreach p [lsort [pcall info procs ::calc::*_msg]] { lappend out [namespace tail $p] }
    return $out
}
# ...and a builder's arms, DERIVED from its own `switch` patterns.  The same walk
# row WD10 of tests/headless/test_calc_wave_dest.tcl uses, and for the same
# reason: a comment landing between two patterns balances the braces, satisfies
# `info complete` and raises out of every arm.  A builder with no `switch` in it
# answers the empty list and is called with no arguments instead.
proc mt_sl_arms {nm} {
    if {[info procs ::calc::$nm] eq {}} { return "NOPROC:calc::$nm" }
    set out {}
    foreach ln [split [info body ::calc::$nm] "\n"] {
        if {[regexp {^[ \t]*([a-zA-Z_][a-zA-Z0-9_]*)[ \t]+\{[ \t]*return} $ln -> k]} {
            lappend out $k
        }
    }
    return $out
}
# the two representative details, DERIVED from the tree so that no token is
# typed here: the longest clickable verb name, and the longest catalogue name.
proc mt_sl_longest {l} {
    set best {}
    foreach nm $l { if {[string length $nm] > [string length $best]} { set best $nm } }
    return $best
}
proc mt_sl_det1 {} { return [mt_sl_longest [ag_verbs]] }
proc mt_sl_det2 {} {
    set out {}
    foreach row [pcall calc::catalogue] { lappend out [lindex $row 0] }
    return [mt_sl_longest $out]
}
# every sentence every builder can compose, as {builder arm sentence}.
proc mt_sl_sentences {} {
    set out {}
    foreach nm [mt_sl_builders] {
        set arms [mt_sl_arms $nm]
        if {[string match NOPROC:* $arms]} { lappend out [list $nm {} $arms] ; continue }
        if {[llength $arms] == 0} {
            set s [pcall calc::$nm]
            if {$s ne {}} { lappend out [list $nm {} $s] }
            continue
        }
        foreach k $arms {
            set s [pcall calc::$nm $k [mt_sl_det1] [mt_sl_det2]]
            if {$s eq {}} continue
            lappend out [list $nm $k $s]
        }
    }
    return $out
}
# the room, as {unit n}, with a sentinel for a missing proc.
proc mt_sl_room {} {
    if {[info procs ::calc::status_room] eq {}} { return {NOPROC:calc::status_room} }
    return [pcall calc::status_room]
}
proc mt_sl_roomn {} {
    set r [mt_sl_room]
    if {[llength $r] != 2} { return -1 }
    if {![string is integer -strict [lindex $r 1]]} { return -1 }
    return [lindex $r 1]
}
proc mt_sl_span {s} {
    if {[info procs ::calc::status_span] eq {}} { return -1 }
    set r [mt_sl_room]
    if {[llength $r] != 2} { return -1 }
    set n [pcall calc::status_span [lindex $r 0] $s]
    if {![string is integer -strict $n]} { return -1 }
    return $n
}
# `fits` / `over` / a sentinel, and NEVER a number -- the only shape a width
# claim takes in a `got` position here.
proc mt_sl_word {s} {
    if {[info procs ::calc::status_fit] eq {}} { return {NOPROC:calc::status_fit} }
    set room [mt_sl_roomn]
    if {$room < 0} { return {NOROOM} }
    set n [mt_sl_span $s]
    if {$n < 0} { return {NOSPAN} }
    return [expr {$n <= $room ? {fits} : {over}}]
}
# ...and the same with the figures, for a FAILURE detail only.
proc mt_sl_why {s} {
    set w [mt_sl_word $s]
    if {$w eq {fits}} { return fits }
    if {$w ne {over}} { return $w }
    return "over:[mt_sl_span $s]/[mt_sl_roomn]"
}
proc mt_sl_fitted {s} {
    if {[info procs ::calc::status_fit] eq {}} { return {NOPROC:calc::status_fit} }
    return [pcall calc::status_fit $s]
}
proc mt_sl_marker {} {
    if {[info procs ::calc::status_marker] eq {}} { return {NOPROC:calc::status_marker} }
    return [pcall calc::status_marker]
}
# the hand-off failure kinds, DERIVED from the two procs that compose them --
# the `calc::cross_msg` arms named in `calc::wave_in_token` and
# `calc::wave_show`'s decommented bodies, which is where a hand-off refusal is
# really built.
proc mt_sl_handoff_kinds {} {
    set out {}
    foreach p {wave_in_token wave_show} {
        set b [pcall info body ::calc::$p]
        if {[string match ERR:* $b]} { lappend out "NOBODY:$p" ; continue }
        foreach {all k} [regexp -all -inline \
                             {calc::cross_msg[ \t]+([a-zA-Z_][a-zA-Z0-9_]*)} \
                             [mt_decomment $b]] {
            lappend out $k
        }
    }
    return [lsort -unique $out]
}
# the formal-ordered values a click really composes for a verb, built the way
# `calc::arg_values` builds them: the buffer's expression under the `rpn`
# formal, each spec field under its own key, with the spec's own default (or the
# expression where the spec has none, which is what a REQUIRED field opens on
# being filled with).
proc mt_sl_vals {nm rpn} {
    set sp [pcall calc::arg_surface $nm]
    if {[string match ERR:* $sp]} { return $sp }
    if {[info procs ::calc::$sp] eq {}} { return "NOPROC:calc::$sp" }
    set have [list rpn $rpn]
    foreach row [pcall calc::fn_argspec $nm] {
        set d [lindex $row 4]
        if {$d eq {}} { set d $rpn }
        lappend have [lindex $row 0] $d
    }
    set out {}
    foreach f [pcall info args ::calc::$sp] {
        if {![dict exists $have $f]} break
        lappend out $f [dict get $have $f]
    }
    return $out
}
# the raw, UNFITTED provenance line, composed here the way `arg_provenance`
# composes one -- so the defect can be re-measured every run instead of
# remembered.  Built with `append` and not one interpolated word, because
# `"$name(...)"` is an ARRAY ELEMENT reference and raises.
proc mt_sl_raw {nm vals num} {
    set s $nm
    append s {(}
    set sep {}
    foreach {k v} $vals {
        append s $sep
        if {$k eq {rpn}} { append s $v } else { append s $k = $v }
        set sep {, }
    }
    append s {) = } $num
    return $s
}
proc mt_sl_prov {nm vals num} {
    if {[info procs ::calc::arg_provenance] eq {}} { return {NOPROC:calc::arg_provenance} }
    return [pcall calc::arg_provenance $nm $vals $num]
}
proc mt_sl_hand {nm db hok hm} {
    if {[info procs ::calc::handoff_sentence] eq {}} { return {NOPROC:calc::handoff_sentence} }
    return [pcall calc::handoff_sentence $nm $db $hok $hm]
}
proc mt_sl_has {s w} { return [expr {[string first $w $s] >= 0 ? {has} : "MISSING:$w"}] }
proc mt_sl_in {l nm} { return [expr {[lsearch -exact $l $nm] >= 0 ? {has} : "missing:$nm"}] }

group MT20 {
    # --- A: the instruments exist, and which arm this one is -----------------
    set slR [mt_sl_room]
    check "MT20/A the budget is a PROC SET and not a constant buried in one caller: `calc::status_room`, `calc::status_span`, `calc::status_elide`, `calc::status_fit`, `calc::status_marker`, `calc::prov_fit` and `calc::handoff_sentence` all exist, the room answers a UNIT plus a number, and on this arm the unit is the character fallback -- which is what makes every row in this band a measurement of the decision rather than of a display" \
        [list [expr {[info procs ::calc::status_room] ne {} ? 1 : 0}] \
              [expr {[info procs ::calc::status_span] ne {} ? 1 : 0}] \
              [expr {[info procs ::calc::status_elide] ne {} ? 1 : 0}] \
              [expr {[info procs ::calc::status_fit] ne {} ? 1 : 0}] \
              [expr {[info procs ::calc::status_marker] ne {} ? 1 : 0}] \
              [expr {[info procs ::calc::prov_fit] ne {} ? 1 : 0}] \
              [expr {[info procs ::calc::handoff_sentence] ne {} ? 1 : 0}] \
              [expr {[llength $slR] == 2 ? [lindex $slR 0] : "SHAPE:$slR"}] \
              [expr {[mt_sl_roomn] > 20 ? 1 : "room:[mt_sl_roomn]"}]] \
        {1 1 1 1 1 1 1 ch 1}
    check "MT20/A R508 keeps the two arms apart rather than leaving it to be assumed: with no window `calc::status` writes nothing and answers {}, so the character fallback this band measures is reached by a test and never by a user, and the pixel arm is a display row's subject" \
        [list [pcall calc::status {a sentence that would otherwise be written}] \
              [mt_boolword [pcall calc::has_win .calc.status.msg] WINDOW nowindow]] \
        {{} nowindow}

    # --- B: every sentence every builder can compose FITS once fitted --------
    set slAll [mt_sl_sentences]
    set slBad {} ; set slOver {}
    foreach row $slAll {
        set nm [lindex $row 0] ; set k [lindex $row 1] ; set s [lindex $row 2]
        if {[string match NOPROC:* $s] || [string match ERR:* $s]} {
            lappend slBad "$nm/$k:$s" ; continue
        }
        if {[mt_sl_word $s] eq {over}} { lappend slOver "$nm/$k" }
        set v [mt_sl_word [mt_sl_fitted $s]]
        if {$v ne {fits}} { lappend slBad "$nm/$k:[expr {$v eq {over} ? [mt_sl_why [mt_sl_fitted $s]] : $v}]" }
    }
    check "MT20/B EVERY sentence EVERY `calc::*_msg` builder can compose fits the status line once `calc::status_fit` has seen it -- the builder set derived from the namespace with `info procs ::calc::*_msg` and each builder's arms derived from its own body by a line scan matching each arm's own leading pattern word followed by a brace and `return` -- NOT from the switch argument, which row MT14/Q parses and cross-checks against this scan on `cross_msg` -- so a sentence added later is swept with no edit here.  This is the claim row S24 of test_calc_skeleton.tcl makes for the catalogue `help` field and `calc::fn_reason` ALONE; four switch builders, every arm of each, and three ruled zero-argument sentences were bounded by nothing at all" \
        $slBad {}
    check "MT20/B ...and the sweep is NOT VACUOUS, which it has to show or an empty failure list above is an empty population: the builder set holds the four `switch` builders AND a ruled zero-argument one, the `cross_msg` arm set holds this stage's newest patterns and not an invented one, the population clears a floor, and a NON-EMPTY subset is over budget BEFORE fitting -- so the row above measures the fitter and not a tree that already fitted" \
        [list [mt_sl_in [mt_sl_builders] cross_msg] [mt_sl_in [mt_sl_builders] arg_msg] \
              [mt_sl_in [mt_sl_builders] eval_msg] [mt_sl_in [mt_sl_builders] plot_msg] \
              [mt_sl_in [mt_sl_builders] no_result_msg] \
              [mt_sl_in [mt_sl_arms cross_msg] slewthr] \
              [mt_sl_in [mt_sl_arms cross_msg] noband] \
              [mt_sl_in [mt_sl_arms cross_msg] oshzeroswing] \
              [mt_sl_in [mt_sl_arms cross_msg] __mt_no_such_arm__] \
              [mt_atleast [llength $slAll] 80] \
              [expr {[llength $slOver] > 0 ? {someover} : {NONEOVER}}]] \
        {has has has has has has has has missing:__mt_no_such_arm__ atleast80 someover}

    # --- C: the elision ANNOUNCES ITSELF -------------------------------------
    set slShort [pcall calc::cross_msg noname]
    set slLong {}
    foreach row $slAll {
        set s [lindex $row 2]
        if {[string length $s] > [string length $slLong]} { set slLong $s }
    }
    set slLongF [mt_sl_fitted $slLong]
    check "MT20/C the elision ANNOUNCES ITSELF, which is the half of this defect that is not about width: a sentence already inside the room comes back BYTE-IDENTICAL and carries no marker, while the longest sentence the tree can compose comes back shorter, carrying the marker, still opening on its own first words and still ending on its own last ones -- so a reader can SEE that text was dropped instead of meeting a sentence that stopped mid-word with nothing to say so" \
        [list [expr {[mt_sl_fitted $slShort] eq $slShort ? {identical} : {CHANGED}}] \
              [mt_sl_word $slShort] \
              [expr {[string first [mt_sl_marker] $slShort] < 0 ? {nomarker} : {MARKED}}] \
              [mt_sl_word $slLong] [mt_sl_word $slLongF] \
              [mt_sl_has $slLongF [mt_sl_marker]] \
              [expr {[string length $slLongF] < [string length $slLong] ? {shorter} : {NOTSHORTER}}] \
              [expr {[string first [string range $slLong 0 11] $slLongF] == 0 ? {opens} : {LOSTHEAD}}] \
              [expr {[string first [string range $slLong end-11 end] $slLongF] >= 0 ? {closes} : {LOSTTAIL}}]] \
        {identical fits nomarker over fits has shorter opens closes}

    # --- D: an UNBOUNDED detail, the leg no wording can satisfy --------------
    # `($a)` in these sentences is a user-supplied value -- a token they typed, a
    # rejected number, the engine's own error text -- so NO shortening bounds it.
    # That is the measurement behind choosing a structural fitter over rewriting
    # sentences one at a time, and it is why the twelve this stage DID shorten
    # were shortened for legibility and not as the fence.
    set slHuge [string repeat Z 500]
    set slHugeBad {} ; set slHugeN 0
    foreach nm [mt_sl_builders] {
        set arms [mt_sl_arms $nm]
        if {[string match NOPROC:* $arms]} continue
        foreach k $arms {
            set s [pcall calc::$nm $k $slHuge $slHuge]
            if {$s eq {}} continue
            incr slHugeN
            if {[mt_sl_word [mt_sl_fitted $s]] ne {fits}} { lappend slHugeBad "$nm/$k" }
        }
    }
    check "MT20/D a FIVE-HUNDRED-character detail still fits, over the same derived population, with the sweep count riding along so an empty offender list cannot be an empty sweep -- the leg that cannot be satisfied by rewording anything, because the detail belongs to the user or to the engine and not to this tree" \
        [list $slHugeBad [mt_atleast $slHugeN 60]] {{} atleast60}

    # --- E: R421's ANSWER is never the part that gets dropped ----------------
    set slNum 4999.999999999956
    set slProvBad {} ; set slProvOver {} ; set slNverb 0
    foreach nm [ag_verbs] {
        incr slNverb
        set vals [mt_sl_vals $nm {v(sq)}]
        if {[string match NOPROC:* $vals] || [string match ERR:* $vals]} {
            lappend slProvBad "$nm:$vals" ; continue
        }
        if {[mt_sl_word [mt_sl_raw $nm $vals $slNum]] eq {over}} { lappend slProvOver $nm }
        set got [mt_sl_prov $nm $vals $slNum]
        if {[string match NOPROC:* $got] || [string match ERR:* $got]} {
            lappend slProvBad "$nm:$got" ; continue
        }
        if {![string match "* = $slNum" $got]} { lappend slProvBad "$nm:TAIL-LOST" ; continue }
        set v [mt_sl_word $got]
        if {$v ne {fits}} { lappend slProvBad "$nm:[expr {$v eq {over} ? [mt_sl_why $got] : $v}]" ; continue }
        if {[string first $nm $got] != 0} { lappend slProvBad "$nm:VERB-LOST" }
    }
    check "MT20/E R421 part 2 puts the measured value LAST, so the provenance line is the one sentence whose truncation changes a NUMBER rather than losing a word -- and for every verb in the derived clickable set the whole answer survives: the line still opens on the verb's own name, still ends on the complete number, and fits.  What gets elided is the ARGUMENT LIST, inside the parentheses, which is the part a reader can recover from the dialog they have just filled in" \
        $slProvBad {}
    check "MT20/E ...and the DEFECT is re-measured here rather than remembered, which is what keeps the row above non-vacuous: a NON-EMPTY subset of the derived clickable set composes a raw line that is OVER the room, the subset is a proper part of that set, and the set itself clears a floor -- so if a future entry got wide enough that nothing overflowed, this row reddens and says so instead of the one above passing over a population it never stressed" \
        [list [expr {[llength $slProvOver] > 0 ? {someover} : {NONEOVER}}] \
              [mt_atleast $slNverb 4] \
              [expr {[llength $slProvOver] <= $slNverb ? {subset} : {BAD}}]] \
        {someover atleast4 subset}
    # the HARM, derived over that subset rather than asserted of one member.
    #
    # ⚠ THE FIRST SPELLING OF THIS ROW PICKED THE WIDEST MEMBER AND WAS WRONG,
    # which is worth leaving recorded because it is the same mistake in miniature
    # that the band is about.  On the widest line (`delay`, nine arguments) the
    # cut lands in the middle of the ARGUMENT LIST and the answer is missing
    # ENTIRELY -- visibly wrong, and not the dangerous case.  The dangerous case
    # is the member whose cut lands INSIDE the digits, and which member that is
    # depends on the sentence's length, so it has to be derived.  Measured on the
    # real entry, `frequency` renders `= 49` for an answer of 4999.999999999956.
    set slPref {} ; set slKeeps {}
    foreach nm $slProvOver {
        set vals [mt_sl_vals $nm {v(sq)}]
        if {[string match NOPROC:* $vals] || [string match ERR:* $vals]} continue
        set vis [string range [mt_sl_raw $nm $vals $slNum] 0 [expr {[mt_sl_roomn] - 1}]]
        if {[string first $slNum $vis] >= 0} { lappend slKeeps "$nm:ANSWER-VISIBLE" }
        set t {}
        regexp {([0-9][0-9.eE+-]*)$} $vis -> t
        if {$t ne {} && $t ne $slNum && [string first $t $slNum] == 0} { lappend slPref $nm }
    }
    check "MT20/E ...and the HARM, DERIVED over that subset instead of asserted of one member: no over-budget line's rendered prefix contains the whole answer, so the figure on screen is never the right one -- and for a NON-EMPTY derived part of the subset the prefix ends in a run of digits that is a STRICT PREFIX of the answer, which is a different number of the SAME SHAPE rather than a visibly missing one.  That is the reading that made this a wrong number on screen and not a cosmetic overflow" \
        [list $slKeeps \
              [expr {[llength $slPref] > 0 ? {somemagnitude} : {NOMAGNITUDE}}] \
              [expr {[llength $slPref] <= [llength $slProvOver] ? {subset} : {BAD}}]] \
        {{} somemagnitude subset}

    # --- E2: a NARROW room, where middle elision alone is not enough --------
    #
    # ⚠⚠ THIS LEG EXISTS BECAUSE A BUILT SABOTAGE SURVIVED EVERYTHING ELSE.
    # With `calc::prov_fit` replaced by the plain composition -- the tree exactly
    # as it was before this stage -- band S28/8's answer-survives row stayed
    # GREEN on the shipped window, because `calc::status_fit`'s head-and-tail
    # elision happens to leave a tail long enough for that number at that width.
    # It does not at the toplevel's own minimum width (`calc::min_floor`), and it
    # does not for the widest value `%.16g` can print.  So the discrimination is
    # driven at a NARROW room, with the plain composition carried alongside as a
    # CONTROL that must lose the answer -- otherwise this row would be green over
    # a width where the two implementations cannot be told apart, which is the
    # shape of fence this file's header calls coverage rather than measurement.
    #
    # The room is narrowed by shadowing `calc::status_chars`, the mechanism row
    # S13 of tests/headless/test_calc_skeleton.tcl uses on `winfo`, and the real
    # proc is put back and asserted back before the row is scored.
    set slLongnum -1.234567890123456e-308
    set slChars0 [pcall calc::status_chars]
    set slE2 {} ; set slE2ctl 0 ; set slE2ran 0
    if {[info procs ::calc::status_chars] ne {} && [info commands ::mt_sl_keepchars] eq {}} {
        rename ::calc::status_chars ::mt_sl_keepchars
        proc ::calc::status_chars {} { return 40 }
        foreach nm [ag_verbs] {
            set vals [mt_sl_vals $nm {v(sq)}]
            if {[string match NOPROC:* $vals] || [string match ERR:* $vals]} continue
            incr slE2ran
            set got [mt_sl_prov $nm $vals $slLongnum]
            if {![string match "* = $slLongnum" $got]} { lappend slE2 "$nm:ANSWER-CUT" }
            if {[mt_sl_word $got] ne {fits}} { lappend slE2 "$nm:OVER" }
            set ctl [mt_sl_fitted [mt_sl_raw $nm $vals $slLongnum]]
            if {![string match "* = $slLongnum" $ctl]} { incr slE2ctl }
        }
        catch {rename ::calc::status_chars {}}
        catch {rename ::mt_sl_keepchars ::calc::status_chars}
    }
    check "MT20/E ...and at a NARROW room the answer STILL survives, which is the only leg that tells `calc::prov_fit` apart from `calc::status_fit`'s middle elision: at the room this leg installs the plain composition put through the general fitter LOSES the value for a derived, non-empty part of the clickable set -- that is the CONTROL -- while `calc::arg_provenance` ends on the whole of it for every member and fits.  Written after the plain composition survived every other row in two suites" \
        [list $slE2 \
              [expr {$slE2ctl > 0 ? {control-loses-it} : {CONTROL-KEEPS-IT}}] \
              [mt_atleast $slE2ran 4] \
              [expr {[pcall calc::status_chars] eq $slChars0 ? {restored} : {NOTRESTORED}}] \
              [expr {[info commands ::mt_sl_keepchars] eq {} ? {norename} : {RENAMELEFT}}]] \
        {{} control-loses-it atleast4 restored norename}

    # --- F: the hand-off failure, which the user never saw at all ------------
    set slKinds [mt_sl_handoff_kinds]
    set slDb [mt_sl_det2]
    set slHandBad {} ; set slHandOver 0
    foreach k $slKinds {
        if {[string match NOBODY:* $k]} { lappend slHandBad $k ; continue }
        set hm [pcall calc::cross_msg $k $slDb $slDb]
        if {$hm eq {}} { lappend slHandBad "$k:NOSENTENCE" ; continue }
        set got [mt_sl_hand [mt_sl_det1] $slDb 0 $hm]
        if {[string match NOPROC:* $got] || [string match ERR:* $got]} {
            lappend slHandBad "$k:$got" ; continue
        }
        if {[mt_sl_word $got] eq {over}} { incr slHandOver }
        set f [mt_sl_fitted $got]
        set v [mt_sl_word $f]
        if {$v ne {fits}} { lappend slHandBad "$k:[expr {$v eq {over} ? [mt_sl_why $f] : $v}]" ; continue }
        if {[string first [string range $hm 0 19] $f] != 0} { lappend slHandBad "$k:FAILURE-NOT-FIRST" }
        if {[string first $slDb $f] < 0} { lappend slHandBad "$k:DEST-LOST" }
    }
    check "MT20/F when the measured WAVE could not be handed to the viewer, the sentence the user actually reads OPENS ON THE FAILURE and still names the destination -- over the hand-off kind set DERIVED from `calc::wave_in_token` and `calc::wave_show`'s own `calc::cross_msg` call sites, so a kind added later is swept with no edit here -- the population is derived and its size is asserted only as a FLOOR, so no sentence in this file or in CLICK_CONTRACT.md names it.  Before this stage the failure was APPENDED to a sentence that already filled the entry, so it rendered not at all for ANY kind and the user went looking for a trace that was never drawn" \
        $slHandBad {}
    check "MT20/F ...and that derivation is NOT VACUOUS while the SUCCESS path is untouched: the kind set clears a floor, holds the no-viewer and the busy kinds, holds no invented one, the composed failure line really is over the room before fitting for every member, and on `ok 1` -- and on a failure that carried no sentence -- the result is `calc::arg_msg destination`'s own string BY IDENTITY, so the re-ordering reaches the failure path alone" \
        [list [mt_atleast [llength $slKinds] 4] \
              [mt_sl_in $slKinds destnoview] [mt_sl_in $slKinds destbusy] \
              [mt_sl_in $slKinds __mt_no_such_kind__] \
              [expr {$slHandOver == [llength $slKinds] ? {alloverraw} : "only:$slHandOver"}] \
              [expr {[mt_sl_hand [mt_sl_det1] $slDb 1 {}] eq
                     [pcall calc::arg_msg destination [mt_sl_det1] $slDb] ? {identity} : {DIFFERS}}] \
              [expr {[mt_sl_hand [mt_sl_det1] $slDb 0 {}] eq
                     [pcall calc::arg_msg destination [mt_sl_det1] $slDb] ? {identity} : {DIFFERS}}]] \
        {atleast4 has has missing:__mt_no_such_kind__ alloverraw identity identity}
    set slComposers {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        set b [pcall info body $p]
        if {[string match ERR:* $b]} continue
        if {[regexp {calc::handoff_sentence[^A-Za-z0-9_]} [mt_decomment $b]]} {
            lappend slComposers [namespace tail $p]
        }
    }
    check "MT20/F ...and the composition is a PURE PROC the click reaches rather than four lines inside `calc::fn_measure`, derived over the decommented namespace -- which is the only reason the two rows above can run on the counted arm at all, since `fn_measure` returns early on `calc::has_win .calc.buf`" \
        [list $slComposers [expr {[info procs ::calc::handoff_sentence] ne {} ? 1 : 0}]] \
        {fn_measure 1}

    # --- G: hygiene ----------------------------------------------------------
    check "MT20 R402 the band composes sentences and reads no database at all, so no `__calc_tmp*` and no `__mt_*` column may appear" \
        [list [leaked] [probeleft]] {{} {}}
}

# =========================================================================
# MT21 — AN OVERFLOWING DECIMAL LITERAL IS NOT A FINITE NUMBER, AND EVERY VERB
#        MUST SAY SO IN ITS OWN VOICE
# =========================================================================
# ⚠⚠ THE SPELLING OF A NUMBER AND THE NUMBER ITSELF ARE TWO DIFFERENT
# QUESTIONS, AND THIS BAND IS ABOUT WHAT THE USER GETS WHEN A PREDICATE ANSWERS
# THE FIRST ONE.  `1e309` is an ordinary decimal literal -- a plain mantissa and
# an exponent one past the double range -- so it is nothing like the four
# non-finite spellings `calc::eval_finite`'s own header is about, and a predicate
# that is a regexp over the spelling vouches for it.  `double("1e309")` is `Inf`.
# Band CE10 of tests/headless/test_calc_engine.tcl fences the predicate; this
# band fences what reached the USER through it, and every row here was RED on the
# tree that had the regexp alone.  Measured on that tree, and these are the four
# shapes a user could reach by typing one field of one dialog:
#
#  * `slewRate` with an overflowing low level, and `overshoot` with an
#    overflowing final value, each RAISED a bare Tcl *"domain error: argument not
#    in valid range"* out of the verb's own pre-flight -- a throw where D7
#    requires an answer, surfaced verbatim by `calc::fn_measure`.
#  * `overshoot` with an overflowing INITIAL value answered `ok 1 value 0.0`,
#    `calc::fn_sink` said `buffer`, and the status line read
#    `overshoot(..., initial=1e309, final=1, dataset=0) = 0.0` -- a confident
#    "0.0 % overshoot" pasted into the user's expression buffer.
#  * `settlingTime` with an overflowing start reference answered `ok 1 value Inf`,
#    which R607 forbids; `calc::fn_sink` caught it one layer later as `badvalue`
#    and the user got a shrug instead of a sentence about their request.
#  * and the WRONG-FAMILY refusals: with the overflowed `Inf` carried into
#    `calc::cross` as a level, `settlingTime`, `slewRate` and -- at HEAD, so this
#    one is PRE-EXISTING rather than new -- shipped `riseTime` each answered
#    *"Cross: the level is not a finite number (Inf)."*, a `Cross`-family sentence
#    about a "level" field those verbs do not have, quoting the overflowed `Inf`
#    rather than the text the user typed.
#
# WHAT THE ROWS ASSERT, AND WHY IN THIS SHAPE.  The population is DERIVED twice
# over: the fields come from `calc::fn_argspec` (every `real` field of every
# clickable verb, so a verb or a field added later enlists itself) and the
# spellings from the double format (an exponent sequence past its range, plus the
# `%.16g` spelling of the largest finite double, which is the precision
# `xschem raw values` writes with and which reads back as an infinity because
# sixteen significant digits round that value UP past itself).  The CORRECTNESS
# claim is not a list of sentences -- those are unratified wording -- but an
# IDENTITY: an overflowing spelling must be refused in exactly the same voice,
# through exactly the same `calc::cross_msg` arm, as `nan` in the same field,
# which is the spelling the predicate already got right.  That is checked by
# mapping each detail out of its own sentence and comparing the remainders, so a
# rewording costs nothing and a wrong ARM reddens by name.
#
# ⚠ AND THE DETAIL MUST ECHO WHAT THE USER TYPED, NOT THE OVERFLOWED `Inf`.
# `1e309` is what is in their dialog field; `Inf` is an artefact of the
# conversion, names no field and tells them nothing about what to change.
#
# ⚠ THE DIALOG'S OWN GATE IS A SEPARATE LEG.  `calc::arg_bad` validates a `real`
# field with the same predicate, so after the repair the user never reaches the
# verb at all -- they get `calc::arg_msg real` naming THAT FIELD'S OWN LABEL.
# The verb's pre-flight is still asserted because the verbs are reachable from
# Tcl without the dialog, and because defence in depth is only defence if both
# layers are measured.
#
# ---------------------------------------------------------------------------
# LIMITS, DECLARED RATHER THAN CHASED
# ---------------------------------------------------------------------------
# L1. ⚠ BAND A'S IDENTITY IS AGAINST `nan`, SO A CHANGE THAT MOVES BOTH
#     SPELLINGS TO THE WRONG FAMILY IS INVISIBLE TO IT.  That is deliberate and
#     is the right comparand for the defect this band exists for -- the overflow
#     spelling went down a DIFFERENT path from `nan`, and a comparison against
#     `nan` is exactly what detects that.  It is not a fence on which family a
#     verb owns.  The instruments for that are already here and elsewhere:
#     `MT17/K` derives `calc::overshoot`'s own arm set and asserts its members
#     are NON-identical to their `cross` counterparts, `MT9b` compares
#     `riseTime`'s reused arms against `cross`'s by identity, and `MT21/B` pins
#     each field's own LABEL.  Built and measured: disabling `calc::cross`'s own
#     level guard reddens band A through its `nan` control, and reddens `MT7`,
#     `MT8`, `MT10`, `MT15/F` and ten rows of `test_calc_cross` beside it.
# L2. ⚠ THE DELEGATING VERBS ANSWER IN `cross`'s VOICE AND THAT IS NOT A DEFECT
#     HERE.  `dutyCycle`, `frequency`, `freq` and `delay` have no refusal of
#     their own for a level, so an overflowing one reaches `calc::cross`'s
#     `badlevel` and the user reads a `Cross:` sentence about "the level".  That
#     is `MT17/K`'s one-voice property working as designed -- a reused arm is
#     surfaced byte-identically -- and the sentence names the right quantity.
#     What the user sees FIRST is `MT21/B`'s: the dialog refuses with that
#     field's own label, `Level A` included.
# L3. THE ACT IS DISPLAY-ONLY AND IS NOT CLAIMED HERE.  `calc::fn_measure` and
#     `calc::buf_set_number` both return early on `calc::has_win .calc.buf`, so
#     this band measures the DECISION -- which sentence, which disposition, which
#     field -- and never that the sentence reached the status entry or that the
#     buffer was left alone.  `MT20` drives the new sentence through the width
#     ladder on the character fallback; the pixel arm is a display row's subject.
# =========================================================================

# the clickable verbs that take arguments, DERIVED: `ag_verbs` reads the route-T
# catalogue rows that have a proc, and a verb with no field list has no `real`
# field to drive.  `cross` is deliberately NOT excluded the way `mt_spec_verbs`
# excludes it -- its `Level` field is exactly one of the fields this band is
# about.
proc m21_verbs {} {
    set out {}
    foreach nm [ag_verbs] {
        if {[llength [pcall calc::fn_argspec $nm]] == 0} continue
        lappend out $nm
    }
    return [lsort -unique $out]
}
proc m21_cells {nm k i} {
    foreach row [pcall calc::fn_argspec $nm] {
        if {[catch {lindex $row 0} rk]} continue
        if {$rk ne $k} continue
        if {[catch {lindex $row $i} c]} { return "NOCELL:$nm/$k/$i" }
        return $c
    }
    return "NOSUCHKEY:$nm/$k"
}
# every `real` field of one verb, and every REQUIRED field whatever its kind --
# the first is what this band drives, the second is what the base answer below
# has to supply for the call to be well formed at all.
proc m21_realkeys {nm} {
    set out {}
    foreach row [pcall calc::fn_argspec $nm] {
        if {[catch {lindex $row 2} kd]} continue
        if {$kd ne {real}} continue
        lappend out [lindex $row 0]
    }
    return $out
}
proc m21_reqkeys {nm} {
    set out {}
    foreach row [pcall calc::fn_argspec $nm] {
        if {[catch {lindex $row 3} rq]} continue
        if {$rq ne {1}} continue
        lappend out [lindex $row 0]
    }
    return $out
}
# the spec's OWN defaults for the optional fields, so the base answer below
# declares values for the required fields only and everything else is whatever
# the dialog would have opened pre-filled with.
proc m21_optdefaults {nm} {
    set out {}
    foreach row [pcall calc::fn_argspec $nm] {
        if {[catch {lindex $row 3} rq]} continue
        if {$rq eq {1}} continue
        lappend out [lindex $row 0] [lindex $row 4]
    }
    return $out
}
# ONE CALL THROUGH THE CLICK'S OWN COMPOSITION PATH, with no Tk in it:
# `calc::arg_values` walks the surface proc's `info args` and indexes the answer
# BY KEY, and `calc::arg_invoke` makes the call.  Driving the verbs through these
# two rather than positionally is what makes a field name in this band's tables
# mean the same thing it means in the dialog.
proc m21_run {nm ans} {
    set vals [pcall calc::arg_values $nm {v(lp)} $ans]
    if {[string match ERR:* $vals]} { return $vals }
    if {![llength $vals]} { return "NOVALS:$nm" }
    if {[catch {calc::arg_invoke $nm $vals} r]} { return "RAISED:$r" }
    return $r
}
# ...and the dialog's SHAPE gate over the same answer, through the same array
# `calc::arg_bad` really reads.  Every key the spec names is set, so no leftover
# from another verb can decide the answer, and all of them are removed again.
proc m21_argbad {nm ans} {
    set sp [pcall calc::fn_argspec $nm]
    if {[catch {llength $sp}]} { return "NOTALIST:$sp" }
    foreach row $sp { catch {unset ::calc::argval([lindex $row 0])} }
    foreach {k v} $ans { set ::calc::argval($k) $v }
    set r [pcall calc::arg_bad $sp]
    foreach row $sp { catch {unset ::calc::argval([lindex $row 0])} }
    return $r
}
# a sentence with ONE substring mapped out, so two sentences that differ only in
# their detail compare equal and the comparison is about the ARM rather than
# about the words.
proc m21_blank {s d} {
    if {$d eq {}} { return $s }
    return [string map [list $d @D@] $s]
}

group MT21 {
    pcall mt_load tran
    # --- NV: the instruments, and the two derived populations ----------------
    set m21V [m21_verbs]
    set m21DMAX [expr {(2.0 - 2.0**-52) * 2.0**1023}]
    set m21SP [list]
    foreach m21k {1 2} { lappend m21SP [format {1e%d} [expr {308 + $m21k}]] }
    lappend m21SP [format {-1e%d} 309] [format {%.16g} $m21DMAX]
    # THE BASE ANSWER, one per verb: a value for each REQUIRED field, merged with
    # the spec's own defaults for the rest.  This is the band's declared fixture
    # and the only part of it written out here; the leg below asserts it covers
    # every required field of every DERIVED verb, so a verb added to the
    # catalogue reddens this band by name instead of being skipped by it.
    # ⚠ A DICT *LITERAL* AND NOT `dict create`, WHICH ROW MT10 CAUGHT.  That row
    # derives, over this file's own text, the set of places that build the answer
    # representation, and its instrument is the words `dict create` on a
    # non-comment line -- so a FIXTURE built that way lands in the same set as a
    # site that really composes an answer and reddens it at BAND-LEVEL, which is
    # exactly the shape MT10 exists to catch.  The row was right and this was the
    # thing to change: `dict exists`, `dict get` and `dict replace` all read an
    # even-length list, so nothing is lost.
    set m21BASE {
        cross        {level 0.5}
        riseTime     {lo 0 hi 1}
        slewRate     {lo 0 hi 1}
        delay        {rpnA {v(lp)} levelA 0.5 rpnB {v(sq)} levelB 0.5}
        settlingTime {final 1.0 tol 0.05 start 0}
        overshoot    {initial 0 final 1}
        dutyCycle    {level 0.5}
        frequency    {level 0.5}
        freq         {level 0.5}
    }
    set m21MISSING {} ; set m21NOREAL {}
    foreach m21n $m21V {
        if {![dict exists $m21BASE $m21n]} { lappend m21MISSING "$m21n=NOBASE" ; continue }
        set m21b [dict get $m21BASE $m21n]
        foreach m21k [m21_reqkeys $m21n] {
            if {![dict exists $m21b $m21k]} { lappend m21MISSING "$m21n/$m21k" }
        }
        if {![llength [m21_realkeys $m21n]]} { lappend m21NOREAL $m21n }
    }
    check "MT21/NV the two populations are DERIVED and the band's own fixture is asserted to cover them: the verbs come from the route-T catalogue rows that have a proc and a field list, their `real` and REQUIRED fields from `calc::fn_argspec`, and the overflowing spellings from the double format -- an exponent sequence past its range plus the `%.16g` spelling of the largest finite double, which is the precision `xschem raw values` writes with.  Every derived verb must have a declared base answer covering every one of its required fields, so a verb added to the catalogue reddens here by NAME rather than being silently skipped; and every one must have at least one `real` field, or the field sweep below would drive nothing for it.  The negative controls show the derivations can answer empty" \
        [list [expr {[llength [info procs ::calc::arg_values]] ? 1 : 0}] \
              [expr {[llength [info procs ::calc::arg_invoke]] ? 1 : 0}] \
              [expr {[llength [info procs ::calc::arg_bad]] ? 1 : 0}] \
              [mt_atleast [llength $m21V] 8] $m21MISSING $m21NOREAL \
              [mt_atleast [llength $m21SP] 4] \
              [m21_realkeys __mt_nosuch_zz] [m21_reqkeys __mt_nosuch_zz] \
              [mt_finite [format {%.16g} $m21DMAX]] [mt_finite 1e308]] \
        {1 1 1 atleast8 {} {} atleast4 {} {} 0 1}

    # --- A: every `real` field of every clickable verb, every spelling -------
    # ⚠ THE EXPECTATION IS AN IDENTITY AGAINST `nan`, NOT A SENTENCE.  For each
    # (verb, field) the same request is also run with `nan` in that field --
    # the spelling the regexp-only predicate already refused -- and the
    # overflowing spelling must reach the SAME arm: the two sentences, each with
    # its own detail mapped out, must be byte-identical.  So a rewording costs
    # nothing, a wrong FAMILY reddens, and so does the right family through the
    # wrong arm.
    set m21BAD {} ; set m21N 0 ; set m21NANOK 0 ; set m21RAISED 0
    set m21WASCROSS {}
    foreach m21n $m21V {
        set m21b [dict get $m21BASE $m21n]
        set m21full [concat [m21_optdefaults $m21n] $m21b]
        foreach m21k [m21_realkeys $m21n] {
            set m21nanans [m21_run $m21n [dict replace $m21full $m21k nan]]
            if {[mt_disp $m21nanans] ne {refused}} {
                lappend m21BAD "$m21n/$m21k/nan=[mt_disp $m21nanans]" ; continue
            }
            incr m21NANOK
            set m21nanmsg [mt_msg $m21nanans]
            foreach m21s $m21SP {
                incr m21N
                set m21a [m21_run $m21n [dict replace $m21full $m21k $m21s]]
                set m21d [mt_disp $m21a]
                if {[string match RAISED:* $m21d]} {
                    incr m21RAISED ; lappend m21BAD "$m21n/$m21k/$m21s=RAISED" ; continue
                }
                if {$m21d ne {refused}} {
                    lappend m21BAD "$m21n/$m21k/$m21s=$m21d" ; continue
                }
                set m21m [mt_msg $m21a]
                if {[mt_shape $m21m] ne {ok}} {
                    lappend m21BAD "$m21n/$m21k/$m21s=shape:[mt_shape $m21m]" ; continue
                }
                if {![string equal [m21_blank $m21m $m21s] [m21_blank $m21nanmsg nan]]} {
                    lappend m21BAD "$m21n/$m21k/$m21s=ARM-DIFFERS-FROM-nan" ; continue
                }
                if {[string first $m21s $m21m] < 0} {
                    lappend m21BAD "$m21n/$m21k/$m21s=DETAIL-NOT-TYPED-TEXT" ; continue
                }
                if {[regexp -nocase {inf} $m21m]} {
                    lappend m21BAD "$m21n/$m21k/$m21s=QUOTES-THE-OVERFLOWED-INF"
                }
            }
        }
    }
    # the CONTROL: the same base answers, untouched, must not be refused at all,
    # or every row above would be green over verbs that refuse everything.
    set m21CTL {}
    foreach m21n $m21V {
        set m21a [m21_run $m21n [concat [m21_optdefaults $m21n] [dict get $m21BASE $m21n]]]
        if {[mt_disp $m21a] eq {refused}} { lappend m21CTL "$m21n=[mt_msg $m21a]" }
    }
    check "MT21/A an overflowing decimal literal in any `real` field of any clickable verb is REFUSED, in that verb's own voice, through the SAME `calc::cross_msg` arm the same field reaches for `nan` -- asserted as an identity between the two sentences with each detail mapped out, never by their words, which are unratified.  The detail is the text the USER TYPED and never the overflowed `Inf`, and no sentence may contain `inf` at all.  Driven through `calc::arg_values` plus `calc::arg_invoke`, which is the click's own composition path, over a population derived from `calc::fn_argspec` and the double format.  ⚠ FOUR CONTROLS RIDE ALONG so the row cannot be green over a tree that refuses everything: every field's `nan` request must itself be a refusal (it is the comparand), the raise count is reported separately because a RAISE was one of the four shapes this band was opened for, the sweep counts bound the population from below, and every base answer unmodified must NOT be refused" \
        [list $m21BAD $m21CTL $m21RAISED [mt_atleast $m21N 50] \
              [mt_atleast $m21NANOK 15] \
              [regexp -nocase {inf} [pcall calc::cross_msg badlevel Inf]]] \
        {{} {} 0 atleast50 atleast15 1}

    # --- B: and the DIALOG never lets it reach the verb ----------------------
    set m21AB {} ; set m21ABN 0
    foreach m21n $m21V {
        set m21full [concat [m21_optdefaults $m21n] [dict get $m21BASE $m21n]]
        if {[m21_argbad $m21n $m21full] ne {}} {
            lappend m21AB "$m21n=REFUSES-A-WELLFORMED-ANSWER" ; continue
        }
        foreach m21k [m21_realkeys $m21n] {
            foreach m21s $m21SP {
                incr m21ABN
                set m21g [m21_argbad $m21n [dict replace $m21full $m21k $m21s]]
                set m21w [pcall calc::arg_msg real [m21_cells $m21n $m21k 1] $m21s]
                if {![string equal $m21g $m21w]} {
                    lappend m21AB "$m21n/$m21k/$m21s=[expr {$m21g eq {} ? {ACCEPTED} : {notidentical}}]"
                }
            }
        }
    }
    check "MT21/B the ARG DIALOG's own shape gate refuses the same spellings one layer earlier, with the sentence asserted by IDENTITY against `calc::arg_msg real` carrying THAT FIELD'S OWN LABEL read off the spec -- so the user is told which field to change rather than being handed a measurement sentence about a field the verb renamed on the way through.  The non-vacuity leg is the well-formed answer: for every derived verb `calc::arg_bad` must pass it, or every refusal above would be a gate that rejects everything" \
        [list $m21AB [mt_atleast $m21ABN 50]] {{} atleast50}

    # --- C: `calc::overshoot` may not answer a value that is not a number ----
    # ⚠⚠ THE SEPARATE HOLE, AND THE ONE THE PREDICATE DOES NOT CLOSE.  Every
    # reference can be a perfectly finite number and the ANSWER still not be
    # one: the quantity is `100*(extremum - final)/(final - initial)`, so a step
    # that is finite but very small drives the quotient past `DBL_MAX` and the
    # verb answered `ok 1 value Inf` -- `calc::fn_sink` says `badvalue` and the
    # user gets a shrug, which is word for word what the `oshzeroswing` guard's
    # own comment says that guard exists to prevent.  That guard tested the step
    # for EXACT equality with zero, so it never fired here.
    #
    # ⚠ THE EXPECTATION IS DERIVED PER MEMBER AND NOT WRITTEN DOWN.  For each
    # pair, `mt_osh_ref` recomputes the whole quantity in this file from the bulk
    # `%.16g` column with no `calc::` proc in it; if that number is finite the
    # verb must MEASURE it, and if it is not the verb must REFUSE in its own
    # voice.  So the table says which members do which rather than this comment,
    # and a member that changes side moves there.
    #
    # ⚠ AND THE DECISION THE ROW RECORDS IS THAT A BIG FINITE ANSWER IS KEPT.
    # A step of `1e-300` against a wave of order one really is passed by
    # `9.99e+301` percent, and a step of one ULP at 1.0 really is undershot by
    # `-3.99e+14` percent; both numbers are correct and both reach the buffer.
    # The verb's own header rules twice over that refusing a legitimately
    # computable number is a defect -- ADE-L is a FLOOR, and `calc::delay`
    # already settled that a negative answer is returned rather than clamped --
    # so the line is drawn at REPRESENTABILITY and nowhere else.  Nothing proves
    # that is the better product behaviour; what is asserted is that the line is
    # where it is said to be.
    set m21ULP [expr {1.0 + 2.0**-52}]
    set m21OSH {} ; set m21OSHN 0 ; set m21REF 0 ; set m21MEAS 0
    foreach {m21i m21f} [list 0 5e-324   0 1e-300   0 1e-20   1.0 $m21ULP \
                              0 1   0.5 0.5] {
        incr m21OSHN
        set m21a [mt_call overshoot {v(lp)} $m21i $m21f 0]
        set m21r [mt_osh_ref {v(lp)} $m21i $m21f 0]
        if {$m21r eq {ZERO}} {
            if {[mt_disp $m21a] ne {refused}} { lappend m21OSH "($m21i,$m21f)=[mt_disp $m21a]" }
            incr m21REF ; continue
        }
        if {[mt_finite $m21r]} {
            incr m21MEAS
            if {[mt_disp $m21a] ne {measured}} {
                lappend m21OSH "($m21i,$m21f)=[mt_disp $m21a] want measured" ; continue
            }
            if {[mt_is $m21a $m21r] ne {ok}} {
                lappend m21OSH "($m21i,$m21f)=[mt_is $m21a $m21r]"
            }
            continue
        }
        incr m21REF
        if {[mt_disp $m21a] ne {refused}} {
            lappend m21OSH "($m21i,$m21f)=[mt_disp $m21a] value [mt_val $m21a] want refused" ; continue
        }
        if {![string equal [mt_msg $m21a] [pcall calc::cross_msg oshtinystep $m21i $m21f]]} {
            lappend m21OSH "($m21i,$m21f)=notidentical" ; continue
        }
        if {[mt_shape [mt_msg $m21a]] ne {ok}} {
            lappend m21OSH "($m21i,$m21f)=shape"
        }
    }
    check "MT21/C `calc::overshoot` never answers `ok` with a value that is not a number, which is R607 at the verb rather than one layer later at `calc::fn_sink`.  THE EXPECTATION IS RECOMPUTED PER MEMBER by this file's own second derivation over the bulk column, with no product proc in it: where that quotient is finite the verb must MEASURE it to tolerance, and where it is not the verb must REFUSE with its own `oshtinystep` sentence by identity.  ⚠ BOTH SIDES OF THE POPULATION ARE ASSERTED NON-EMPTY, which is what stops the row being green over a verb that refuses every small step -- and that is the decision the row records: a big finite percent is KEPT, because refusing a legitimately computable number is the defect the verb's own header rules against twice" \
        [list $m21OSH [mt_atleast $m21OSHN 6] [mt_atleast $m21REF 2] \
              [mt_atleast $m21MEAS 3]] \
        {{} atleast6 atleast2 atleast3}

    # --- D: ...and the boundary is at DBL_MAX, derived from both sides -------
    # The step at which the quotient stops being representable is not a constant
    # and is not written here: it is `|100*(extremum - final)| / DBL_MAX`, read
    # off the double format and off this database's own column.  One decade
    # either side of it the verb must flip, which is the sharpest statement the
    # fence can make and the one a guard with an invented threshold fails.
    set m21YS [mt_col v(lp) 0]
    set m21EXT [mt_osh_scan $m21YS max]
    set m21THR [expr {[mt_finite $m21EXT] ? abs(100.0*double($m21EXT))/$m21DMAX : {}}]
    set m21LO {} ; set m21HI {}
    if {$m21THR ne {} && $m21THR > 0.0} {
        set m21LO [expr {$m21THR / 10.0}]
        set m21HI [expr {$m21THR * 10.0}]
    }
    set m21BND {}
    if {$m21LO eq {} || $m21HI eq {}} {
        set m21BND NOTHRESHOLD
    } else {
        set m21BND [list [mt_disp [mt_call overshoot {v(lp)} 0 $m21LO 0]] \
                         [mt_disp [mt_call overshoot {v(lp)} 0 $m21HI 0]] \
                         [mt_finite [mt_osh_ref {v(lp)} 0 $m21LO 0]] \
                         [mt_finite [mt_osh_ref {v(lp)} 0 $m21HI 0]]]
    }
    check "MT21/D the step at which the answer stops being representable is DERIVED from the double format and from this database's own extremum -- `|100*(extremum - final)| / DBL_MAX` -- and the verb flips across it: a decade below that step it refuses and a decade above it measures, with this file's own second derivation agreeing on both sides.  A guard built on an invented constant passes the two rows above and fails this one, which is why the boundary is asserted rather than only the two ends of the population" \
        $m21BND {refused measured 0 1}

    # --- E: the header sentence that was FALSE, now a row -------------------
    # ⚠ `calc::overshoot`'s own header declares its `eval_finite` guard
    # LOAD-BEARING because *"`double("inf")` quietly gives `Inf` -- which would
    # then poison the swing and the answer"*.  That sentence was false for a
    # whole class of input: `1e309` walked straight through the guard and
    # poisoned exactly that.  It is a row now, so the sentence is re-measured
    # every run rather than believed, and the leg is the SWING: the guard must
    # refuse before `double()` is reached, which is why the request-validation
    # order is asserted with the database CLEARED.
    pcall xschem raw clear
    set m21E {} ; set m21EN 0
    foreach m21s [concat $m21SP {inf -inf nan -nan}] {
        foreach {m21i m21f} [list $m21s 1 0 $m21s] {
            incr m21EN
            set m21a [mt_call overshoot {v(lp)} $m21i $m21f 0]
            if {[mt_disp $m21a] ne {refused}} { lappend m21E "($m21i,$m21f)=[mt_disp $m21a]" ; continue }
            if {[string equal [mt_msg $m21a] [pcall calc::cross_msg nodata]]} {
                lappend m21E "($m21i,$m21f)=NODATA-SO-THE-GATE-IS-AFTER-THE-READ"
            }
        }
    }
    set m21EOK [mt_call overshoot {v(lp)} 0 1 0]
    check "MT21/E the guard `calc::overshoot`'s header calls LOAD-BEARING really is in front of the arithmetic for an OVERFLOWING literal and not only for the four non-finite spellings, measured with the database CLEARED so a verb that validated after its first engine call would answer `nodata` here and be caught.  The header sentence used to be false for exactly this class and is a row now rather than a claim.  The non-vacuity leg is the gate ORDER itself: with both references well formed and nothing loaded the answer IS `nodata`" \
        [list $m21E [mt_atleast $m21EN 14] [mt_disp $m21EOK] \
              [string equal [mt_msg $m21EOK] [pcall calc::cross_msg nodata]]] \
        {{} atleast14 refused 1}

    # --- G: no arm may BORROW another arm's sentence ------------------------
    # ⚠⚠ THIS ROW EXISTS BECAUSE A SABOTAGE SURVIVED EVERY ROW ABOVE.  Band C
    # asserts the new refusal by IDENTITY against `[calc::cross_msg oshtinystep]`,
    # which is the house shape -- and it is trivially satisfied if that arm simply
    # RETURNS another arm's sentence.  Built and measured: making `oshtinystep`
    # answer `[calc::cross_msg oshzeroswing $b]` left this file at `ALL PASS` with
    # the whole band green, while a user whose step is `5e-324` would read *"the
    # initial and final values are equal, so there is no step"* -- a sentence that
    # is FALSE about their request, which is the exact class of defect this band
    # was opened for, reintroduced by the fence meant to close it.
    #
    # THE REMEDY IS AN INVARIANT OVER THE WHOLE BUILDER AND NOT A ROW ABOUT ONE
    # ARM: no two arms may compose the same sentence.  The arm set is DERIVED from
    # the proc's own trailing `switch` argument -- `mt_switch_arms`, the same
    # instrument MT14/Q uses, so a comment landing between two patterns is caught
    # there rather than silently shrinking this population -- and the comparison
    # is run under SEVERAL detail pairs, because two arms that differ only in
    # where they interpolate a detail would collide under one pair and not under
    # another.  The pairs include a degenerate one (both details equal) for that
    # reason.  Nothing here asserts a WORD: it asserts that the words are
    # distinguishable, which is the property that makes every identity row in
    # this file and in its siblings capable of failing.
    set m21ARMS [pcall mt_switch_arms cross_msg]
    set m21DUP {} ; set m21PN 0
    if {[catch {llength $m21ARMS}]} {
        set m21DUP "NOTALIST:$m21ARMS"
    } else {
        foreach m21det [list {AAA BBB} {0 5e-324} {1 1} {{} {}}] {
            incr m21PN
            array unset m21seen ; array set m21seen {}
            foreach m21p $m21ARMS {
                set m21s [pcall calc::cross_msg $m21p {*}$m21det]
                if {$m21s eq {}} { lappend m21DUP "{$m21det}/$m21p=EMPTY" ; continue }
                if {[info exists m21seen($m21s)]} {
                    lappend m21DUP "{$m21det}/$m21seen($m21s)==$m21p"
                } else {
                    set m21seen($m21s) $m21p
                }
            }
        }
    }
    check "MT21/G no two arms of `calc::cross_msg` compose the same sentence, over an arm set DERIVED from the proc's own trailing `switch` argument and under several detail pairs including a degenerate one -- which is what makes every by-identity assertion in this file capable of failing, since an arm that RETURNS a sibling's sentence satisfies its own identity row trivially.  ⚠ BUILT AND MEASURED: `oshtinystep` returning `oshzeroswing`'s sentence passed this whole band before this row existed, and would have told a user with a `5e-324` step that their two references were equal.  The floors ride along so a derivation that answered an empty arm set, or a single detail pair, could not pass" \
        [list $m21DUP [mt_atleast [llength $m21ARMS] 40] [mt_atleast $m21PN 4] \
              [expr {[lsearch -exact $m21ARMS oshtinystep] >= 0 ? {present} : {MISSING}}] \
              [pcall mt_switch_agree cross_msg]] \
        {{} atleast40 atleast4 present agree}

    # --- F: hygiene ---------------------------------------------------------
    pcall mt_load tran
    check "MT21 R402 every exit path this band drove cleans up after itself, so no `__calc_tmp*` and no `__mt_*` column is left behind" \
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
# ---------------------------------------------------------------------------
# THE BAND-ABORT GUARD.  Last, because it is a claim about every band above it.
#
# WARN THIS IS THE ROW THE WHOLE FILE'S SENTINEL DISCIPLINE EXISTS FOR, and it
# is here because the discipline was silently false in four bands.  Every
# accessor in this file -- `mt_disp`, `mt_val`, `mt_key`, `mt_msg`, `mt_len`,
# `mt_at`, `mt_range`, `mt_ratios`, `mt_nminus`, `mt_boolword` and the rest --
# exists so that a product answer which is NOT a measurement fails a row
# legibly.  A site that indexes, slices, iterates, divides or tests a product
# answer BARE raises instead, `group`'s catch turns that into one line, and
# every remaining row of the band is gone from the verdict.
#
# WARN A COUNT IS NOT ENOUGH AND THE NAMES ARE THE POINT.  A shortfall in the
# check total is a number nothing compares against anything; a named band is a
# failure about itself.  Derived from `group`'s own bookkeeping, so a band added
# tomorrow enlists itself.
# ---------------------------------------------------------------------------
check "EVERY band above this one RAN TO ITS END: no band was abandoned through `group`'s catch, which is the failure mode that DELETES a band's remaining rows from the verdict instead of reddening them -- and the names of any that were are the value here, since the only other evidence is a check total that came in short.  Derived from `group`'s own record rather than a list kept here, so a band added later is covered without this row being edited"     [list [llength $::abortnames] $::abortnames] {0 {}}

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
