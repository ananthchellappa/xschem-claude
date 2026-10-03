# tests/headless/test_calc_wave_dest.tcl — THE DESTINATION FOR A RESULT THAT IS
# A WAVE WITH ITS OWN X AXIS, and R420's X-axis argument on `dutyCycle`.
#
# Spec     doc/claude/specs/calculator.md §7.2 (the catalogue rows), §7.3
#          (R401-R405), §11.2 (the fixture contract)
# Contract doc/claude/calculator_batch/DESTINATION_CONTRACT.md — R419, R420,
#          route A, the three hazards of §7, the four change sites of §8, the
#          one fence of §9 and the final shape of §10.
#          doc/claude/calculator_batch/CROSS_CONTRACT.md  — D1-D12, in force.
#          doc/claude/calculator_batch/TIMING_CONTRACT.md — R415/R416, T1-T7,
#          in force; R416's `dutyCycle` is this stage's first real consumer.
# Plan     doc/claude/calculator_batch/PLAN.md — the destination stage.
# Fixture  tests/headless/data/calc_fixture.raw, contract and HAND DERIVATIONS
#          in tests/headless/data/README.md
#
# ⚠⚠ THIS FILE WAS WRITTEN RED-FIRST, BEFORE ANY OF THE DESTINATION EXISTED.
# Every behavioural band below failed when it was written, each failure naming
# the proc or the token that is missing rather than printing a bare Tcl error,
# and the transcript of that red is in the stage receipt.  The suite is
# deliberately NOT registered in tests/run_regression.tcl by the commit that
# creates it -- an all-red registered suite is a standing red in T1 -- so
# REGISTERING IT IS THE IMPLEMENTATION COMMIT'S JOB, in `hcases`, in the same
# change as the code.
#
# ---------------------------------------------------------------------------
# WHAT THIS STAGE IS, in the words of the rulings that decided it
# ---------------------------------------------------------------------------
#
# R419  `cross` with nth 0 returns A PLAIN LIST OF CROSSING TIMES -- the user's
#       own words were *"Just a list of crossing times like cadence does."*  So
#       NO Y AXIS IS INVENTED for it and `cross` is NOT a waveform result at
#       all.  That ruling SPLIT this stage in two and SHRANK the half this file
#       fences: the verbs behind the WAVEFORM destination are `dutyCycle`'s
#       default, `delay` with nth 0 on either side, and the unbuilt `frequency`
#       -- THREE, enumerated mechanically from the enclosing proc of every
#       `listdefer` call site and not counted from a sentence.  The LIST surface
#       is a different destination (spec R606, the inert `Table` control) and is
#       NOT this file's business.
#
# R420  `dutyCycle`'s X axis is AN ARGUMENT WITH A DEFAULT -- the user's own
#       words were *"Make it an option to the function. Default can be time the
#       cycle started. Other choices you gave can be supported with non default
#       values to this argument."*  All three ship: the time the cycle started
#       (THE DEFAULT), the cycle number, and the cycle's midpoint.  Band WD8
#       asserts each INDEPENDENTLY and asserts that the default is cycle-start
#       WITH NO ARGUMENT GIVEN, because a default nobody drives without naming
#       it is not a default anyone has measured.
#
# Route A is decided on three crews' measurements: `xschem raw new` plus
# `xschem raw set`, with `sim_type` `table`.  Route B (an ASCII table through
# `xschem raw table_read`) is dead on PRECISION -- `table_read()` parses the
# float arm of `SPICE_DATA_TYPE` with a hand-rolled parser -- and route C (a
# staircase padded into the loaded sweep) cannot express an own-X result at all.
#
# ---------------------------------------------------------------------------
# ⚠⚠ THE SIGNATURES ARE DECIDED HERE, AND THE DECISION IS THIS FILE'S RATHER
# THAN THE CONTRACT'S
# ---------------------------------------------------------------------------
#
# DESTINATION_CONTRACT names the route, the hazards and the change sites, and
# leaves the argument lists to the implementer -- but a red-first row cannot
# call a proc whose argument list nobody has chosen, so this file chooses,
# following `calc::cross`'s own vocabulary.  THE IMPLEMENTATION STAGE MAY
# OVERRULE ANY OF THIS; what it may not do is leave the two disagreeing
# silently.  Every row reaches the product through the adapter procs named
# below, so a different choice is an edit to the adapter and not to a hundred
# rows.
#
#   calc::wave_dest       <xs> <ys> ?<xname>? ?<yname>?
#   calc::wave_dest_drop  <answer>
#   calc::dutyCycle       <rpn> <level> ?<cycle>? ?<dataset>? ?<xaxis>?
#
# ⚠ THE HELPER IS NOT NAMED `calc::dest_*`, AND THAT IS A MEASUREMENT RATHER
# THAN A PREFERENCE.  Row CE8 of tests/headless/test_calc_engine.tcl and row PL9
# of tests/headless/test_calc_plot.tcl each glob `dest_*` out of the `::calc::`
# namespace and then assert an EXACT LITERAL LIST of the procs in that set whose
# code names no widget path.  A `calc::dest_new` lands in both lists and reddens
# both -- one on `hcases`, one on the `dcases`-only arm that only a gate runs.
# `wave_dest` is matched by neither glob.  Band WD10 carries that as a row so
# the constraint is re-measured rather than remembered.
#
# `calc::wave_dest` takes TWO PARALLEL LISTS and nothing else, because the three
# verbs behind it already have both: `dutyCycle` computes its per-cycle
# fractions and (R420) its per-cycle X in the same loop.  The answer is a dict
# in `calc::cross`'s own three dispositions so a caller can propagate what it
# was told:
#
#   measured  -- `ok` 1, with `db` the destination's registry name, `type` its
#                sim_type, `xname`/`yname` its two column names and `n` the
#                point count
#   refused   -- `ok` 0, with a sentence in `msg`
#
# There is NO `absent` disposition here: a destination either got built or the
# request was malformed.  An EMPTY result list is a REFUSAL and not an absence,
# which is this file's choice and is declared in the holes below.
#
# `calc::wave_dest_drop` takes what `wave_dest` returned, removes the
# destination AND PUTS THE USER'S SLOT BACK -- see WD3 for why that is two
# switches and not one.
#
# THE PROCS THAT KNOW THE ANSWER SHAPE ARE ENUMERATED AND NOT COUNTED:
# `wd_disp`, `wd_val`, `wd_msg`, `wd_key` and `wd_asanswer`.  An implementer who
# wants a different representation edits exactly those, and row WD10 derives the
# set of sites in this file that BUILD such a dict and fails if it grows -- so a
# new inline site reddens instead of falsifying this sentence.  The enumeration
# is a list and not a number because the sibling suite shipped that same
# sentence wrong TWICE, once by forgetting a proc and once by counting procs
# while three ROW SITES built the dict inline.
#
# ---------------------------------------------------------------------------
# ⚠⚠ THE THREE HAZARDS ARE MEASURED ON THE BARE VERBS IN BAND WD0, BECAUSE A
# FENCE WHOSE HAZARD NOBODY DEMONSTRATED IS A FENCE NOBODY CAN TRUST
# ---------------------------------------------------------------------------
#
# Every one of these is a property of the shipped `xschem raw` verbs, measured
# here in the same run, with no Calculator code involved:
#
#  * `xschem raw switch <name>` WITH NO TYPE DOES NOT SWITCH BY NAME.  The
#    by-name arm needs both arguments; with one it falls past the digit arm to
#    "switch to the next database" and answers RC 1 WHILE LANDING SOMEWHERE
#    ELSE.  Measured round-robin from every slot.  So a row asserting only
#    `rc == 1` about a restore proves NOTHING, and every restore row below
#    asserts WHICH SLOT IT ENDED ON.
#  * `xschem raw clear <name> <type>` FORCES THE CURRENT SLOT TO 0, whatever it
#    was.  `src/ase.tcl`'s `ase::attach_dbs` depends on that, so it is
#    load-bearing elsewhere and cannot be fixed here -- which is why cleanup
#    needs a SECOND restore after it.
#  * `xschem raw new` ON AN EXISTING NAME ANSWERS 0, IGNORES THE REQUESTED
#    GEOMETRY AND KEEPS THE PREVIOUS SAMPLES.  So reuse without clearing freezes
#    the point count at the first call and serves stale data.
#  * `xschem raw new` ANSWERS 1 FOR A DATABASE IT DID NOT ALLOCATE.  An empty
#    result list asks for a span of `0 .. -1`, which yields a ZERO-POINT
#    database with rc 1; a span whose step does not divide it yields a NEGATIVE
#    point count and a failed allocation.  So the producer must check
#    `xschem raw points` and never the return value.
#  * A COLUMN CREATED BY `xschem raw add <name> {}` IS ZERO-FILLED TO THE
#    DATABASE'S WHOLE POINT COUNT.  `draw_graph` plots the whole dataset, so an
#    N-point result in a longer database draws a FALSE DIAGONAL from its last
#    real sample back to zero.  Band WD5 is that fence.
#  * THE PRECISION DOOR, BOTH SIDES.  `xschem raw values` prints "%.16g" and
#    round-trips a full-precision double BIT-EXACTLY; `xschem raw set`'s own
#    RETURN VALUE is `dtoa()` = "%.8g" and is a LOSSY ECHO of the value it just
#    stored exactly.  Band WD6 asserts both, and the level it drives is chosen
#    so the loss is REAL -- see the next warning.
#
# ---------------------------------------------------------------------------
# ⚠⚠ THE LEVEL `1/3` IS NOT DECORATION, AND A ROUND LEVEL WOULD HAVE MADE THE
# PRECISION BAND PASS VACUOUSLY
# ---------------------------------------------------------------------------
#
# `v(sq)`'s edges are linear on a 0.1 ms grid, so its level-L crossings are
# `0.9 + 0.2L` ms and INHERIT L'S OWN DIGIT COUNT.  At L = 0.5 or L = 0.27 the
# crossing has few significant digits, "%.8g" round-trips it to within one ulp,
# and a row asserting that the lossy door is DETECTABLY lossy would be RED ON A
# CORRECT TREE.  At L = 1/3 the crossing carries a full mantissa and "%.8g"
# loses it by several parts in a billion -- past the fixture's documented 1e-12
# relative headroom for `time` by three orders of magnitude.  The band DERIVES
# that discrimination every run rather than asserting a figure: `wd_distinct`
# answers a WORD, so a future Tcl or libc whose formatting differs reddens the
# row that says so instead of silently weakening the fence.
#
# ---------------------------------------------------------------------------
# ⚠⚠ THREE SLOTS, AND THE USER ON SLOT 2.  TWO SLOTS WOULD HAVE MADE HALF OF
# BAND WD3 PASS VACUOUSLY, AND THE CONTRACT ONLY ASKED FOR TWO.
# ---------------------------------------------------------------------------
#
# DESTINATION_CONTRACT §10 says the fence must "read the fixture twice and drive
# its Evaluate from a non-zero slot", because with the user on slot 0 the
# question "is the current slot back where it was?" answers YES whatever
# happened.  THAT IS NECESSARY AND IT IS NOT SUFFICIENT, measured here while
# writing the band:
#
#   slots {0 tran, 1 op}, user on 1
#     post-clear the current slot is forced to 0 and the WRONG, name-only
#     restore lands on "the next one" = slot 1 = `op` -- THE RIGHT ANSWER BY
#     ACCIDENT, and the row passes over a defect it was written to catch.
#
#   slots {0 tran, 1 ac, 2 op}, user on 2
#     mid-life the name-only restore lands on slot 0; post-clear it lands on
#     slot 1.  NEITHER is slot 2, so both halves are live.
#
# So `wd_load3` reads the fixture THREE times -- `tran`, `ac`, `op` -- and every
# restore row drives from the `op` slot, which is slot 2.  The two wrong
# landings are themselves rows in WD0, so the band's non-vacuity is measured in
# the same run rather than argued for here.
#
# ---------------------------------------------------------------------------
# ⚠ A ROW MUST FAIL, NEVER THROW, and in this file that has two radii
# ---------------------------------------------------------------------------
#
# A throw out of the PRODUCT is caught by `wd_call` / `wd_wv` and becomes a
# legible sentinel, failing ONE ROW.  A throw out of SUITE code is caught by
# `group`, which scores it as a counted FAIL and ABANDONS THAT BAND'S REMAINING
# ROWS while the next band still runs -- the worse of the two, because an
# abandoned band silently stops measuring.  The file-scope catch at the bottom
# sees only an error raised BETWEEN bands.  So every call into `::calc::` and
# `::wviewer::` goes through one of the two adapters, every engine call goes
# through `pcall`, and every `llength`/`lindex` on something the PRODUCT
# authored goes through `wd_len`/`wd_at`: `llength` of a string whose first
# character after a space is an unmatched open brace RAISES, and a refusal
# sentence or a `RAISED:` sentinel could carry one.  The claim is about what the
# product authored and nothing else -- the bands index `wd_col` columns and this
# file's own derived lists with a bare `lindex`, because those are "%.16g"
# numbers and arithmetic over them.
#
# ⚠⚠ NO COMMENT SITS BETWEEN TWO `switch` PATTERNS ANYWHERE IN THIS FILE, AND
# THERE IS NO `switch` IN IT AT ALL.  Measured one stage earlier in
# `calc::cross_msg`: a comment placed between two `switch` arms leaves the braces
# balanced and `info complete` answering 1, while Tcl raises *"extra switch
# pattern with no body"* out of EVERY arm -- 34 rows red at once, three of them
# in another suite.  A brace-balance scan cannot see it; only exercising every
# arm can.  Row WD10 exercises every `calc::cross_msg` arm this stage touches for
# exactly that reason.
#
# ---------------------------------------------------------------------------
# ⚠ EVERY NUMBER ASSERTED OFF A FIXTURE COLUMN IS DERIVED TWICE, AND NOTHING IS
# SHARED WITH THE SIBLING SUITES
# ---------------------------------------------------------------------------
#
# This file does NOT source, lift or copy a helper from test_calc_cross.tcl or
# test_calc_measure.tcl, and it introduces no `calc_common.tcl`: a shared
# fixture derivation would mean ONE WRONG DERIVATION GOING GREEN IN THREE
# SUITES.  The two independent derivations are
#
#  1. FROM THE DECK.  `v(sq)` is PULSE(0 1 0.9m 0.2m 0.2m 1m 4m) on a 0.1 ms
#     grid, so its rising edge k runs 0.9+4k -> 1.1+4k ms through 0 -> 1
#     linearly and crosses level L at t = 0.9 + 0.2L + 4k ms, while its falling
#     edge k runs 2.1+4k -> 2.3+4k ms through 1 -> 0 and crosses L at
#     t = 2.3 - 0.2L + 4k ms.  `wdk_rise` and `wdk_fall` are those two lines.
#     The duty fraction is (fall(L) - rise(L)) / 4 ms = (1.4 - 0.4L)/4, which is
#     LEVEL-DEPENDENT; R420's three X axes fall out of the same two lines --
#     cycle-start is rise(L,k), the midpoint is (rise(L,k) + rise(L,k+1))/2, and
#     the cycle number needs no data at all.
#  2. FROM THE COLUMNS, with this file's own copy of CROSS_CONTRACT D3's
#     predicate and D4's interpolation (`wd_derive`), run over
#     `xschem raw values`.  Band WD1 asserts the two agree for every number the
#     behavioural bands assert, and nothing in WD1 calls the feature.
#
# ⚠ TOLERANCE, NOT EQUALITY (`WDTOL` = 1e-7 relative), LOOSER THAN THE FIXTURE'S
# OWN HEADROOM ON PURPOSE: a duty fraction is a quotient of differences of
# fixture samples and a midpoint is a mean of two interpolations, so they carry
# more dust than the samples they are built from, and pinning them to the
# column's 1e-12 would fence the arithmetic's round-off rather than the
# behaviour.  THE ONE EXCEPTION IS BAND WD6, which is ABOUT the precision door
# and therefore asserts at the fixture's own 1e-12: a producer that stored
# through the lossy door would pass at 1e-7 and that is the whole defect.
#
# ---------------------------------------------------------------------------
#   WD0  Infrastructure and THE SIX HAZARDS, measured on the bare `xschem raw`
#        verbs with no Calculator code involved.  PASSES TODAY, and it is what
#        makes every band below non-vacuous: WD0 green with WD2+ red means the
#        feature is absent, WD0 red means the suite is broken and nothing else
#        it says counts.
#   WD1  Infrastructure: the deck arithmetic and this file's own D3+D4 over the
#        bulk columns agree, for the duty series and all three of R420's X axes;
#        every threshold falls strictly between samples so interpolation is
#        fenced.  Nothing here calls the feature.  PASSES TODAY.
#   WD2  The producer REGISTERS and NEVER CLEARS: a slot appears, the user's
#        result survives at its own slot, the destination's sim_type is the one
#        odd type that works, and both its columns read back as the lists given.
#   WD3  THE RESULT-SELECTION FENCE.  `results::current` is field-by-field
#        identical across an Evaluate that builds a destination -- MID-LIFE and
#        POST-CLEAR asserted SEPARATELY, because `raw clear` forces slot 0 and
#        the sequence therefore needs TWO explicit restores -- driven from the
#        `op` slot, which is slot 2 of three.
#   WD4  §9's ONE FENCE: `wviewer::graph_props` emits exactly one `sweep=` token
#        per trace, IN NODE ORDER, with the mixed-axis trace in the MIDDLE of
#        the strip; and a token list is never SHORT, which is the defect all
#        seven graph walkers share.  Plus `wviewer::add_trace` accepting a sweep,
#        and -- its LAST row, driven on the AC analysis rather than on `tran` --
#        that the ordinary traces' token is READ out of the current database and
#        not assumed to be `time`.  ⚠ That last row was ADDED after the band's
#        first revision shipped: a `set swdflt time` mutation passed every other
#        row in the file, because the `tran` fixture's own first raw vector IS
#        `time`.  A fence that passes against its own defect reads as coverage.
#   WD5  THE HOLD-PAD: an N-point result in a longer database must not end at
#        zero, which is the false diagonal `raw_add_vector`'s zero fill draws.
#   WD6  PRECISION: a real crossing time round-trips through the destination
#        inside the fixture's own 1e-12, read back ONLY with `xschem raw values`;
#        and the trap is proven in the same band -- `raw set`'s return is a
#        lossy echo of a value it stored exactly.
#   WD7  `raw new`'s LYING RC: an empty result is refused and registers nothing;
#        and a second evaluation with a different N serves ITS OWN data, never
#        the first evaluation's.
#   WD8  R420's THREE X MODES, each asserted independently, with the default
#        measured WITH NO ARGUMENT GIVEN; plus one end-to-end row feeding
#        `dutyCycle`'s own two lists to the destination.
#   WD9  THE DEFERRAL SENTENCE STAYS SHARED.  Rows MT7 and MT8 of
#        test_calc_measure.tcl compare against `[calc::cross_msg listdefer]` by
#        IDENTITY, so a reworded but still shared sentence costs nothing and a
#        sentence SPLIT PER CALLER reddens both.  This band pins the sharing by
#        name, so a future split fails HERE with a name instead of THERE with a
#        puzzle.  PASSES TODAY.
#   WD10 Hygiene and shape: no `__calc_tmp*` and no `__wd_*` left in any
#        inventory on any exit path; the helper is not named `calc::dest_*`; the
#        producer's code names no `.calc` widget path, so it stays reachable
#        headless; every `calc::cross_msg` arm this stage touches answers without
#        raising; and the answer-dict key sites in this file are exactly the
#        procs the header enumerates.
#
# ---------------------------------------------------------------------------
# ⚠ WHICH ROWS OUTSIDE WD0 AND WD1 PASS WITH NO FEATURE PRESENT, DECLARED RATHER
# THAN LEFT FOR A READER TO NOTICE, because a row that is green on the red run is
# the thing most likely to be read as a fence when it is not one yet.  BY KIND,
# not by count:
#
#   * the per-band R402 inventory rows.  Nothing mints a `__calc_tmp*` while the
#     producer does not exist, so these cannot redden TODAY -- they are real
#     fences for the implementation and vacuous against its absence.
#   * BAND WD9 ENTIRELY.  It pins behaviour that ships today, against a change
#     this stage is tempted to make.  That is its whole purpose.
#   * WD10's `calc::dest_*` row, its `cross_msg` arm sweep, its decommenter
#     non-vacuity row and its `wd_dictsites` row, which is a claim about THIS
#     FILE'S OWN TEXT and so has nothing to do with whether the feature exists.
#
# Every other row outside WD0 and WD1 was observed FAILING before any of the
# destination existed, each naming the proc or the token that is missing.
#
# ---------------------------------------------------------------------------
# ⚠ HOLES, DECLARED RATHER THAN PAPERED OVER.  Each of these is something this
# file does NOT measure, said plainly so nobody reads a green run as covering it.
# ---------------------------------------------------------------------------
#
#  H1 `wviewer::interp_value` IS NOT FENCED HERE.  It hardcodes
#     `set sweep [lindex $names 0]`, so the Tcl cursor readout on an own-X trace
#     is computed against the wrong column -- change site 3 of the contract's §8.
#     Reaching it needs a viewer window and a mixed strip, which needs a display;
#     the C-side in-graph measurement is already correct, so only the readout bar
#     is wrong.  It belongs in the `dcases` viewer suite, not here.
#  H2 THE RENDERING IS NOT FENCED HERE, ON PURPOSE AND NOT FOR WANT OF A DISPLAY.
#     All SEVEN graph walkers carry the `sweep=` token forward by name --
#     `graph_fullxzoom`, `graph_fullyzoom`, `find_closest_wave`, `graph_point_at`,
#     `wave_hilight_envelope`, `graph_wave_resolve` and `draw_graph` -- so a fence
#     that only renders misses six of them.  WD4 asserts the POSITIVE SHAPE of
#     what `graph_props` emits, which is upstream of all seven.  What stays
#     unmeasured is that the engine then draws it, and that is a `look` debt.
#  H3 `wviewer::add_trace`'s SWEEP KEY ON `trd` IS FENCED ONLY BY ARITY.
#     `add_trace` answers "unknown viewer window" with no viewer, so the key it
#     puts on the trace dict cannot be read headless.  WD4 asserts the parameter
#     EXISTS and is named; that the value reaches `trd` is unmeasured here.
#  H4 A RESTORE BY INDEX IS INDISTINGUISHABLE FROM A RESTORE BY NAME AND TYPE ON
#     THIS FIXTURE, and the reason is structural: `raw new` APPENDS, so the
#     destination is always at a HIGHER index than the user's slot and clearing it
#     never compacts the user's slot away from where it was.  WD3 asserts the
#     OBSERVABLE END STATE, which is what the contract's hazard is about; an
#     implementation that restored by captured index would pass.
#  H5 THE `op` AND `ac` SLOTS ARE DRIVEN AS SLOTS AND NOT AS SOURCES.  Every
#     measurement here reads the `tran` plot; the `op` slot exists to be the
#     non-zero current slot WD3 restores to, and the `ac` slot exists to make the
#     post-clear "next database" land somewhere wrong.  A destination built from
#     an `ac` or `op` measurement is unfenced.
#     ⚠ ONE EXCEPTION, AND IT IS NOT THE SAME CLAIM: band WD4's LAST row reads
#     the fixture AS the AC analysis, because its subject is that the `sweep=`
#     token is READ out of the current database rather than assumed to be `time`
#     -- and that is unmeasurable on `tran`, whose own X name is `time`.  It
#     still measures the GENERATOR and not a destination built from AC samples,
#     so the hole above stands as written.
#  H6 `wd_code` IS A HEURISTIC, NOT A Tcl PARSER: it drops comment-only lines and
#     a trailing comment whose preceding text is a complete script.  WD10's
#     non-vacuity row shows it answers `yes` for a proc that ships today, leaves a
#     long body behind and did remove something, so a `no` below is evidence
#     rather than an artefact of an empty string.  It is not a guarantee against a
#     pathological body.
#  H7 THE DISPOSITION OF AN EMPTY RESULT LIST IS THIS FILE'S CHOICE AND NOT THE
#     CONTRACT'S.  A `dutyCycle` at a level nothing crosses answers MEASURED WITH
#     AN EMPTY LIST (CROSS_CONTRACT T5), so an empty list really does arrive here.
#     This file requires a REFUSAL with nothing registered; an implementer may
#     instead choose an absence, provided it says so out loud.  The same applies
#     to a mismatched pair of list lengths and to the three X-axis tokens' own
#     spellings -- `start`, `number`, `mid` -- which are internal API words today
#     because phase 5 owns the dialog that will show them.
#  H8 LEAK HYGIENE ACROSS A THROW IS NOT FENCED.  WD10 asserts no `__calc_tmp*`
#     and no destination slot survives the paths the bands drive; what happens
#     when the producer raises BETWEEN `raw new` and its restore is unmeasured,
#     and it is the one path that would leave the user on the Calculator's own
#     scratch database.
#  H9 CROSS_CONTRACT D10's bulk read stays UNFENCEABLE, inherited from `cross`:
#     nothing observable distinguishes a bulk read from a consistently per-point
#     one except low-order bits.  WD6 fences the PRODUCER's door, which is a
#     different door and is observable.
#
# Standalone from the repo ROOT, headless.  NOT a bare `./src/xschem`, which
# inherits $DISPLAY and paints on the user's real screen:
#   env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script \
#       tests/headless/test_calc_wave_dest.tcl
# or, gated and with a throwaway HOME, which is the armed spelling:
#   tests/headless/run_suites.sh --nogui test_calc_wave_dest

source [file join [file dirname [info script]] scratch.tcl]

# ⚠ CAPTURED AT FILE SCOPE, NOT READ INSIDE THE PROC THAT NEEDS IT.
# `wd_dictsites` walks this file's own text, and `info script` is only reliably
# this file while this file is being sourced -- a relative spelling resolved from
# a different cwd later would answer NOFILE and redden a correct run.
set WDSELF [file normalize [info script]]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
# any command, with a raise turned into a legible `ERR:` sentinel so the ROW
# fails instead of the band dying.
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        incr ::fail
    }
}
# ⚠ THE LINE ENDS IN `: FAIL` SO THAT A READER COUNTS IT.  A bare `BGERROR:`
# line is invisible to both readers -- run_suites.sh echoes `^(FAIL|FATAL)` and
# summarize_all counts lines ENDING in FAIL -- and without a handler at all the
# error would not touch $fail, so the suite would print `OVERALL: ok` over a
# real failure.
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

# ---------------------------------------------------------------------------
# THE ADAPTER.  `wd_disp`, `wd_val`, `wd_msg`, `wd_key` and `wd_asanswer` are
# the procs that know the answer shape -- the same enumeration the header gives,
# deliberately a list rather than a number, and held down by a row in WD10 that
# derives the set of sites in this file which build such a dict.
# ---------------------------------------------------------------------------

# a value DERIVED BY THIS FILE, in the answer shape, so that a row comparing two
# of this file's own derivations can go through `wd_islist` instead of
# open-coding the representation at the row site.  THE ONLY PLACE IN THIS FILE
# THAT MAY NAME THE KEYS.
proc wd_asanswer {v} {
    return [dict create ok 1 msg {} db {} type {} xname {} yname {} n [llength $v] value $v]
}

# One call to one `::calc::` proc, BY NAME.  Names what is MISSING rather than
# raising an `invalid command name` that says nothing about the row, and turns
# any raise from inside the product -- a wrong arity included, which is exactly
# what a different signature would produce -- into a legible sentinel so the row
# fails instead of the band dying.
proc wd_call {verb args} {
    set p ::calc::$verb
    if {[info commands $p] eq {}} { return "NOPROC:calc::$verb" }
    set a [wd_arity_check $p [llength $args]]
    if {$a ne {ok}} { return "NOARITY:calc::$verb $a" }
    if {[catch {uplevel 1 [list $p {*}$args]} r]} { return "RAISED:$r" }
    return $r
}
# ⚠ THE ARITY IS CHECKED BEFORE THE CALL, AND THAT IS NOT BELT-AND-BRACES.  A
# proc that EXISTS but does not yet take this stage's new argument answers Tcl's
# own *"wrong # args: should be ..."*, which `wd_call` would hand back as a
# `RAISED:` sentinel -- a legible failure, but one that reads as "the product
# threw" when the truth is "the parameter has not been added yet".  Pre-checking
# turns R420's whole band into failures that NAME THE MISSING ARGUMENT, which is
# the difference between a red run a reader can act on and one they have to
# decode.  The declared arity is derived from `info args` plus `info default`, so
# an `args` tail and every optional parameter are handled rather than assumed.
proc wd_arity_check {p n} {
    if {[catch {info args $p} as]} { return ok }
    set mn 0 ; set mx 0 ; set var 0
    foreach a $as {
        if {$a eq {args}} { set var 1 ; continue }
        incr mx
        if {![info default $p $a __wd_dflt]} { incr mn }
    }
    if {$n < $mn} { return "takes {$as} and was given only $n" }
    if {!$var && $n > $mx} { return "takes {$as} and was given $n" }
    return ok
}
# ...and the same for a `::wviewer::` proc, which is a different namespace and a
# different owner, so a missing one must say which.
proc wd_wv {verb args} {
    set p ::wviewer::$verb
    if {[info commands $p] eq {}} { return "NOPROC:wviewer::$verb" }
    set a [wd_arity_check $p [llength $args]]
    if {$a ne {ok}} { return "NOARITY:wviewer::$verb $a" }
    if {[catch {uplevel 1 [list $p {*}$args]} r]} { return "RAISED:$r" }
    return $r
}
# measured / refused, or a sentinel naming why neither could be read.  Checked
# in this order because a sentinel string is not a dict and `dict exists` on one
# would be answering a different question.  THERE IS NO `absent` DISPOSITION
# HERE -- see hole H7.
proc wd_disp {a} {
    if {[string match NOPROC:* $a]} { return $a }
    if {[string match RAISED:* $a]} { return $a }
    if {[catch {dict size $a} n]} { return "NOTADICT:$a" }
    if {![dict exists $a ok]} { return "NOKEY-ok:$a" }
    if {[dict get $a ok] eq {1}} { return measured }
    return refused
}
proc wd_val {a} {
    set d [wd_disp $a]
    if {$d ne {measured}} { return $d }
    if {![dict exists $a value]} { return "NOKEY-value:$a" }
    return [dict get $a value]
}
proc wd_msg {a} { return [wd_key $a msg] }
# one key of an answer, with the disposition substituted when the answer is not
# a disposition at all, so a missing key or a non-dict answer fails the row
# legibly instead of raising inside it.
proc wd_key {a k} {
    set d [wd_disp $a]
    if {$d ne {refused} && $d ne {measured}} { return $d }
    if {![dict exists $a $k]} { return "NOKEY-$k" }
    return [dict get $a $k]
}

# ⚠⚠ `llength` AND `lindex` RAISE ON A STRING WHOSE FIRST CHARACTER AFTER A
# SPACE IS AN UNMATCHED OPEN BRACE.  A verb whose refusal sentence, or whose
# raise text arriving through `wd_call`'s `RAISED:` sentinel, carried one would
# take the rest of the enclosing band out through `group`'s catch.  These two
# never raise, and a row that gets one of their sentinels instead of a number
# fails legibly on the comparison.
#
# THE CLAIM THEY ARE HERE TO MAKE TRUE, STATED NARROWLY SO IT IS CHECKABLE: no
# PRODUCT ANSWER is ever indexed or measured bare in this file.  It is
# deliberately NOT extended to the `wd_col` columns or to this file's own derived
# lists, which are "%.16g" numbers and arithmetic over them.
proc wd_len {v} { if {[catch {llength $v} n]} { return "NOTALIST:{$v}" } ; return $n }
proc wd_at {v i} { if {[catch {lindex $v $i} e]} { return "NOTALIST:{$v}" } ; return $e }

# ---------------------------------------------------------------------------
# agreement with a derived value.  See the header for why WDTOL is looser than
# the fixture's own headroom, and why band WD6 is the one exception.
# ---------------------------------------------------------------------------
set WDTOL 1e-7
set WDTOL_TIME 1e-12
# ⚠ GATED WITH THIS SUITE'S OWN `wd_finite`, NOT WITH `string is double -strict`,
# which answers 1 for all four non-finite spellings -- the exact reason
# `calc::eval_finite` exists -- so a measured `nan` would get past the guard and
# then RAISE out of the subtraction, aborting the enclosing band instead of
# failing one row.  `inf` does not raise; it answers a relative error of Inf and
# compares false, which is the kind of half-working guard that survives review.
# The EXPECTED side is gated too, with its OWN sentinel, so a broken derivation
# is distinguishable from a broken answer rather than silently becoming one.
proc near {got exp tol} {
    if {![wd_finite $got]} { return "NOTANUMBER:{$got}" }
    if {![wd_finite $exp]} { return "BADEXPECTED:{$exp}" }
    if {$exp == 0.0} {
        if {abs($got) <= $tol} { return ok }
        return "off:{$got} abs=[expr {abs($got)}]"
    }
    set r [expr {abs(($got - $exp) / double($exp))}]
    if {$r <= $tol} { return ok }
    return "off:{$got} rel=$r"
}
# ⚠ THIS SUITE'S OWN finiteness test, deliberately NOT a call to
# `calc::eval_finite`: the derivations here must not stop working because the
# product proc they are used to check was renamed, and a suite that called it
# would be measuring that proc against itself.
#
# ⚠ BUT IT IS NOT *INDEPENDENT* EVIDENCE.  The regexp is a byte-identical copy
# of `calc::eval_finite`'s, so a wrong pattern is wrong identically in both
# places and WD0's agreement row would still be green.  What this buys is a
# CHANGE DETECTOR -- if either copy is edited, WD0 reddens and names the
# spelling they disagree on -- and decoupling from the product's call graph.  It
# does not buy a second opinion, and no row below may be read as if it did.
proc wd_finite {v} {
    return [regexp {^-?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} [string trim $v]]
}
# a whole answer's `value` against one derived number.
proc wd_is {a exp {tol {}}} {
    if {$tol eq {}} { set tol $::WDTOL }
    return [near [wd_val $a] $exp $tol]
}
# ...and against a LIST of derived values, element by element, reporting the
# COUNT FIRST because a wrong count is a different defect from a wrong value --
# and for a per-cycle series it is specifically the trailing-partial-period
# defect.  Carries the disposition through, so a sentinel can never satisfy it.
#
# ⚠ `wd_len` / `wd_at` on the ANSWER, bare `llength` / `lindex` on the EXPECTED,
# and the asymmetry is the point: the guard is for what the PRODUCT supplied.
proc wd_islist {a exps {tol {}}} {
    if {$tol eq {}} { set tol $::WDTOL }
    if {[wd_disp $a] ne {measured}} { return [wd_disp $a] }
    return [wd_listcmp [wd_val $a] $exps $tol]
}
# the same comparison for a plain list -- a column read back through
# `xschem raw values`, or one key of an answer that is not `value`.
proc wd_listcmp {v exps tol} {
    set n [wd_len $v]
    if {![string is integer -strict $n]} { return $n }
    if {$n != [llength $exps]} { return "count=$n want=[llength $exps] got={$v}" }
    set bad {}
    for {set i 0} {$i < $n} {incr i} {
        set r [near [wd_at $v $i] [lindex $exps $i] $tol]
        if {$r ne {ok}} { lappend bad "\[$i\]$r" }
    }
    if {[llength $bad]} { return [join $bad { }] }
    return ok
}
# ⚠ `distinct` / `same` FOR EVERY ROW THAT HAS TO SHOW IT CAN TELL TWO CANDIDATE
# ANSWERS APART.  A row saying "the answer is X and not the plausible wrong
# reading Y" has to assert something about Y, and the obvious spelling --
# comparing `near`'s failure sentence against a literal -- embeds a REPRODUCIBLE
# NUMBER in the expectation and therefore in the T1 verdict, which is the house
# rule's exact prohibition.  These answer a WORD, re-derived every run, and they
# are a POSITIVE claim about the instrument's discrimination rather than an
# assertion that a wrong answer is absent.
proc wd_distinct {a b {tol {}}} {
    if {$tol eq {}} { set tol $::WDTOL }
    if {![wd_finite $a] || ![wd_finite $b]} { return "NOTANUMBER:{$a}|{$b}" }
    return [expr {[near $a $b $tol] eq {ok} ? {same} : {distinct}}]
}
# ...the same claim where both sides are whole LISTS, which is what R420's three
# X axes need: a row saying "the default IS cycle-start and is NOT the midpoint"
# must assert something about the midpoint, and `wd_listcmp`'s failure string
# carries per-element numbers that would then live in the T1 verdict.
proc wd_cmpword {v exps {tol {}}} {
    if {$tol eq {}} { set tol $::WDTOL }
    # ...but a SENTINEL is carried through rather than collapsed into `distinct`:
    # a missing key really is distinct from the expected list, and answering so
    # would hide WHY behind a word that reads like a measurement.
    if {[regexp {^(NOPROC|NOARITY|RAISED|NOTADICT|NOKEY|NOTALIST|ERR):} $v]} { return $v }
    return [expr {[wd_listcmp $v $exps $tol] eq {ok} ? {same} : {distinct}}]
}
# ⚠ THE EXPR OPERANDS BELOW ARE ALL BRACED OR SUBSTITUTED, NEVER BARE.  A literal
# bareword in a braced `expr` is a RAISE -- *invalid bareword "long"* -- which
# would abandon the enclosing band through `group`'s catch instead of failing one
# row, so every word-valued answer in this file comes out of a proc like these
# rather than out of a ternary written at the row site.
# WD5's tail, with the one arithmetic that can go NEGATIVE guarded.  Measured on
# the red run: with no producer the column reads back EMPTY, `[llength $col] - $n`
# is -2, and `lrepeat` RAISES *"bad count: must be integer >= 0"* -- which
# ABANDONED THE WHOLE BAND through `group`'s catch, three rows of it, exactly the
# failure mode this file's own warning is about.  The guard answers a sentinel so
# the row fails and the band keeps measuring.
proc wd_tailholds {col n last tol} {
    if {![string is integer -strict $n]} { return "notacount:$n" }
    set m [llength $col]
    if {$m < $n} { return "tooshort:$m want>=$n" }
    if {$m == $n} { return ok }
    return [wd_listcmp [lrange $col $n end] [lrepeat [expr {$m - $n}] $last] $tol]
}
proc wd_atleast {v n} {
    if {![string is integer -strict $v]} { return "notacount:$v" }
    if {$v >= $n} { return atleast }
    return "only:$v"
}
proc wd_countin {v allowed} {
    if {![string is integer -strict $v]} { return "notacount:$v" }
    if {[lsearch -exact $allowed $v] >= 0} { return inrange }
    return "count:$v"
}
proc wd_longer {s n} {
    if {[string length $s] > $n} { return long }
    return "short:[string length $s]"
}
proc wd_shrunk {a b} {
    if {[string length $a] < [string length $b]} { return shorter }
    return same
}
proc wd_hascomments {s} {
    if {[regexp -line {^[ \t]*#} $s]} { return comments-left }
    return clean
}
# ⚠ AND IT NAMES WHAT IS MISSING RATHER THAN ANSWERING `clean` FOR A PROC THAT
# DOES NOT EXIST.  `info body` on a missing proc answers an `ERR:` sentinel, in
# which a `.calc` regexp finds nothing -- so the obvious spelling of this check
# is GREEN ON THE RED RUN, which is exactly the vacuous shape this batch keeps
# catching.
proc wd_nowidget {p} {
    if {[info commands $p] eq {}} { return "NOPROC:$p" }
    set b [pcall info body $p]
    if {[string match ERR:* $b]} { return "NOBODY:$p" }
    set c [wd_code $b]
    if {[string trim $c] eq {}} { return "NOCODE:$p" }
    if {[regexp {\.calc} $c]} { return named }
    return clean
}
# the house refusal shape, measured off `calc::eval_msg`, `calc::plot_msg` and
# `calc::cross_msg`: leading capital, colon-space, one full sentence, a full
# stop.  THE WORDS ARE NEVER ASSERTED -- they are unratified user-visible wording
# and the `rule` debt filed against `calc::eval_msg`'s sentences covers these.
proc wd_shape {s} {
    if {$s eq {}} { return empty }
    if {![regexp {^[A-Z]} $s]} { return "nocapital:$s" }
    if {![regexp {: } $s]} { return "nocolon:$s" }
    if {![string match {*.} $s]} { return "nofullstop:$s" }
    return ok
}

# ---------------------------------------------------------------------------
# DERIVATION 1 -- FROM THE DECK.  `v(sq)`'s two edges, the duty fraction they
# imply, and R420's three X axes.  Closed form, no simulator in it.
# ---------------------------------------------------------------------------
proc wdk_rise {L k} { return [expr {(0.9 + 0.2*double($L) + 4.0*$k) * 1e-3}] }
proc wdk_fall {L k} { return [expr {(2.3 - 0.2*double($L) + 4.0*$k) * 1e-3}] }
# high time fall(L) - rise(L) = 1.4 - 0.4L ms over a 4 ms rising-to-rising
# period.  LEVEL-DEPENDENT, which is the half a "50 % duty" sentence drops.
proc wdk_duty {L} { return [expr {(1.4 - 0.4*double($L))/4.0}] }
# R420's three axes for cycle k (0-based), from the same two lines.
proc wdk_x_start {L k} { return [wdk_rise $L $k] }
proc wdk_x_mid {L k} { return [expr {([wdk_rise $L $k] + [wdk_rise $L [expr {$k+1}]])/2.0}] }
proc wdk_x_number {L k} { return [expr {$k + 1}] }

# ---------------------------------------------------------------------------
# the fixture, the registry, and DERIVATION 2 -- this file's own D3 + D4
# ---------------------------------------------------------------------------
set fixture {}
foreach cand {tests/headless/data/calc_fixture.raw} {
    if {[file exists $cand]} { set fixture [file normalize $cand] }
}
if {$fixture eq {} && [info exists ::XSCHEM_SHAREDIR]} {
    set cand [file join [file dirname $::XSCHEM_SHAREDIR] tests headless data calc_fixture.raw]
    if {[file exists $cand]} { set fixture [file normalize $cand] }
}
# ⚠ ALWAYS WITH AN EXPLICIT TYPE.  A bare `xschem raw read <f>` after the file
# has also been read as `op` lands back on the OP slot, where a row then reads a
# wrong DATABASE as if it were a wrong number.
#
# THREE READS, AND THE ORDER IS THE POINT -- see the header: `tran` at slot 0,
# `ac` at slot 1, `op` at slot 2, and the user left on `op`.  With `op` at slot 1
# the post-clear restore row passes by accident.
proc wd_load3 {} {
    if {$::fixture eq {}} { return NOFIXTURE }
    catch {xschem raw clear}
    set out {}
    foreach ty {tran ac op} {
        if {[catch {xschem raw read $::fixture $ty} r]} { return "ERR:$ty:$r" }
        lappend out $r
    }
    return $out
}
# just the transient read, for the bands that do not care about the registry.
proc wd_load1 {} {
    if {$::fixture eq {}} { return NOFIXTURE }
    catch {xschem raw clear}
    if {[catch {xschem raw read $::fixture tran} r]} { return "ERR:$r" }
    return $r
}
# ...and the same fixture read as the AC analysis, whose sweep column is
# `frequency` and NOT `time`.
#
# ⚠ IT EXISTS FOR EXACTLY ONE ROW, and that row closes a hole the first revision
# of band WD4 had.  Every other measurement in this file reads the `tran` plot,
# whose first raw vector IS `time` -- so a `sweep=` generator that HARDCODED the
# word `time` for an ordinary trace was indistinguishable from one that reads the
# database's own X name, and the mutation `set swdflt time` in
# `wviewer::graph_props` passed all of WD4 and the whole suite.  A fence that
# passes against its own defect reads as coverage and is worse than no fence.
# The defect is live rather than theoretical: a measurement taken from an AC
# analysis wants `frequency`, and a hardcoded `time` resolves to nothing there.
proc wd_load1ac {} {
    if {$::fixture eq {}} { return NOFIXTURE }
    catch {xschem raw clear}
    if {[catch {xschem raw read $::fixture ac} r]} { return "ERR:$r" }
    return $r
}
# the registry, parsed out of `xschem raw info`'s own text.  `<n> current` on the
# first line, then one `<idx> <path> <type>` line per slot.
proc wd_info {} {
    if {[catch {xschem raw info} t]} { return "ERR:$t" }
    return $t
}
proc wd_curslot {} {
    set t [wd_info]
    if {[string match ERR:* $t]} { return $t }
    foreach ln [split $t "\n"] {
        if {[string match {* current} [string trim $ln]]} { return [lindex $ln 0] }
    }
    return NOCURRENT
}
proc wd_slots {} {
    set t [wd_info]
    if {[string match ERR:* $t]} { return $t }
    set out {}
    foreach ln [split $t "\n"] {
        set ln [string trim $ln]
        if {$ln eq {} || [string match {* current} $ln]} continue
        lappend out [list [lindex $ln 0] [lindex $ln 1] [lindex $ln 2]]
    }
    return $out
}
proc wd_nslots {} {
    set s [wd_slots]
    if {[string match ERR:* $s]} { return $s }
    return [llength $s]
}
proc wd_slottype {i} {
    foreach s [wd_slots] { if {[lindex $s 0] eq $i} { return [lindex $s 2] } }
    return NOSLOT
}
# one column, as a Tcl list, or a sentinel.  THE BULK DOOR, "%.16g", and the only
# door any comparand in this file comes from.
proc wd_col {name dset} {
    if {[catch {xschem raw values $name $dset} v]} { return "ERR:$v" }
    return [string trim $v]
}
proc wd_rawnames {} {
    set l {}
    if {[catch {xschem raw list} l]} { return {} }
    return [split [string trim $l] "\n"]
}
# R402's watch.  `__calc_tmp*` is the product's prefix; `__wd_*` is this file's
# own probe prefix, watched separately so a probe that forgot to clean up is
# reported as a SUITE defect and never as a product leak.
proc wd_leaked {} {
    set out {}
    foreach n [wd_rawnames] { if {[string match -nocase __calc_tmp* $n]} { lappend out $n } }
    return $out
}
proc wd_probeleft {} {
    set out {}
    foreach n [wd_rawnames] { if {[string match -nocase __wd_* $n]} { lappend out $n } }
    return $out
}
# CROSS_CONTRACT D3 + D4, in the order D6 requires: the finiteness gate FIRST,
# then the predicate, then the division -- which cannot have a zero denominator
# once the predicate holds, because the predicate puts the endpoints strictly on
# opposite sides of L.  Returns the X values in sweep order.
proc wd_derive {xs ys L edge} {
    set out {}
    set n [llength $ys]
    for {set p 1} {$p < $n} {incr p} {
        set y0 [lindex $ys [expr {$p-1}]] ; set y1 [lindex $ys $p]
        if {![wd_finite $y0] || ![wd_finite $y1]} continue
        set r [expr {$y0 <  $L && $y1 >= $L}]
        set f [expr {$y0 >  $L && $y1 <= $L}]
        if {!$r && !$f} continue
        set dir [expr {$r ? {rising} : {falling}}]
        if {$edge ne {either} && $edge ne $dir} continue
        set x0 [lindex $xs [expr {$p-1}]] ; set x1 [lindex $xs $p]
        lappend out [expr {$x0 + ($L - $y0)*($x1 - $x0)/($y1 - $y0)}]
    }
    return $out
}
# `ok <x> <xleft> <xright>` for the k-th crossing, so a row can ask where in its
# straddling pair a crossing falls instead of asserting it in a name.  R414d
# (interpolated, never snapped) is inherited through `cross`, and WD1 uses this
# to show every threshold it drives falls STRICTLY BETWEEN two samples.
proc wd_bracket {xs ys L edge k} {
    set hits [wd_derive $xs $ys $L $edge]
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
proc wd_strictly_between {xs ys L edge k} {
    lassign [wd_bracket $xs $ys $L $edge $k] st x xl xr
    if {$st ne {ok}} { return $st }
    if {$x > $xl && $x < $xr} { return strict }
    return "onsample:$x"
}
# THE PER-CYCLE SERIES AND ITS THREE X AXES, derived from the columns.  A period
# is one rising crossing to the NEXT rising crossing; the high time is the
# falling crossing INSIDE it minus the opening rising one; a trailing PARTIAL
# period is not a period and is excluded.  Returns a dict with keys `duty`,
# `start`, `mid` and `number`, or `NOFALL` naming the cycle whose high time
# cannot be closed.
proc wd_duty_derive {xs ys L} {
    set rs [wd_derive $xs $ys $L rising]
    set fs [wd_derive $xs $ys $L falling]
    if {[llength $rs] < 2} { return NOCYCLE }
    set duty {} ; set start {} ; set mid {} ; set number {}
    set nr [llength $rs]
    for {set i 0} {$i < $nr - 1} {incr i} {
        set r0 [lindex $rs $i] ; set r1 [lindex $rs [expr {$i+1}]]
        set xf {}
        foreach x $fs { if {$x > $r0 && $x < $r1} { set xf $x ; break } }
        if {$xf eq {}} { return "NOFALL:$i" }
        lappend duty [expr {($xf - $r0)/($r1 - $r0)}]
        lappend start $r0
        lappend mid [expr {($r0 + $r1)/2.0}]
        lappend number [expr {$i + 1}]
    }
    return [dict create duty $duty start $start mid $mid number $number]
}
proc wd_duty_get {d k} {
    if {[catch {dict get $d $k} v]} { return "NODERIV:$d" }
    return $v
}

# ---------------------------------------------------------------------------
# §9's INSTRUMENT: the `sweep=` tokens `wviewer::graph_props` emits, read the way
# `draw_graph()` reads them -- `get_tok_value` takes the quoted value, then
# `my_strtok_r` splits it on whitespace.  Answers a LIST, so a row asserts the
# COUNT and the ORDER rather than a rendering.
#
# ⚠ `ABSENT` AND `SHORT` ARE TWO DIFFERENT FAILURES AND THIS TELLS THEM APART:
# an absent token list makes every trace fall to column 0, while a SHORT one
# carries its last token forward and re-axes every trace after the special one.
# `wd_sweeptoks` answers `{}` for absent and a short list for short, and the rows
# compare the count against the trace count.
proc wd_sweeptoks {props} {
    if {[string match NOPROC:* $props] || [string match RAISED:* $props]} { return $props }
    if {![regexp -line {^sweep="([^"]*)"$} $props -> v]} {
        if {[regexp -line {^sweep=(\S*)$} $props -> v]} { return [regexp -all -inline {\S+} $v] }
        return {}
    }
    return [regexp -all -inline {\S+} $v]
}
# a strip of traces, built the way `wviewer::add_trace` builds them -- `expr`,
# `name`, `vec`, `color`, and the optional `sweep` this stage adds.  Nothing here
# calls the product: the dict shape is the model's and a row that built it
# through `add_trace` would need a viewer window (hole H3).
proc wd_trace {vec {sweep {}}} {
    set d [dict create expr $vec name $vec vec $vec color 4]
    if {$sweep ne {}} { dict set d sweep $sweep }
    return $d
}
proc wd_graph {traces} {
    return [dict create x1 0 x2 1 y1 0 y2 1 traces $traces]
}

# ---------------------------------------------------------------------------
# WD10's instruments: a decommenter (hole H6) and a walk of this file's own text
# for every site that builds an answer dict.
# ---------------------------------------------------------------------------
proc wd_code {body} {
    set out {}
    foreach ln [split $body "\n"] {
        set t [string trimleft $ln]
        if {[string index $t 0] eq "#"} continue
        set keep $ln
        set h [string first "#" $ln]
        while {$h >= 0} {
            set head [string range $ln 0 [expr {$h-1}]]
            if {[info complete $head] && [string trim $head] ne {}} { set keep $head ; break }
            set h [string first "#" $ln [expr {$h+1}]]
        }
        lappend out $keep
    }
    return [join $out "\n"]
}
# every proc in THIS FILE whose body builds the answer dict, named by its own
# enclosing proc.  A `dict create` whose first key is the disposition flag is the
# one spelling that builds one; a row in WD10 asserts the set is exactly the
# header's enumeration, so a new inline site reddens instead of falsifying a
# comment.
#
# ⚠ THE PATTERN IS SPELLED WITH A CHARACTER CLASS SO THAT THIS PROC DOES NOT FIND
# ITSELF.  Written as the plain literal, the regexp's own source line matches it
# and the row's expectation grows a second member that has nothing to do with the
# claim -- an instrument that is its own counterexample, which is the
# `grep -c '#pragma'` failure CLAUDE.md records, one level in.
proc wd_dictsites {} {
    if {[catch {open $::WDSELF r} fh]} { return "NOFILE:$::WDSELF" }
    set txt [read $fh] ; close $fh
    set cur {} ; set hits {}
    foreach ln [split $txt "\n"] {
        if {[regexp {^proc ([A-Za-z_:][A-Za-z0-9_:]*)} $ln -> nm]} { set cur $nm }
        set code [wd_code $ln]
        if {[regexp {dict +create +o[k] } $code]} {
            if {$cur eq {}} { lappend hits FILESCOPE } else { lappend hits $cur }
        }
    }
    return [lsort -unique $hits]
}
# the procs in `::calc::` that a `dest_*` glob answers, which is what rows CE8
# and PL9 of the two sibling suites sweep into an exact literal list.
proc wd_calc_dest_procs {} {
    set out {}
    foreach p [pcall info procs ::calc::dest_*] { lappend out [namespace tail $p] }
    return [lsort $out]
}

if {[catch {

# =========================================================================
group WD0 {
    # Infrastructure AND THE SIX HAZARDS, on the bare verbs.  Nothing here calls
    # the feature; all of it passes on a tree without it.
    check "WD0 fixture: tests/headless/data/calc_fixture.raw was located" \
        [expr {$::fixture ne {} ? 1 : 0}] 1
    check "WD0 fixture reads as the tran database spec 11.2 describes -- two datasets of 101 points, ten vectors -- when the type is given EXPLICITLY" \
        [list [pcall wd_load1] [pcall xschem raw sim_type] [pcall xschem raw datasets] \
              [pcall xschem raw points 0] [pcall xschem raw points 1] [llength [wd_rawnames]]] \
        {1 tran 2 101 101 10}
    # THE THREE-SLOT FIXTURE, and the slot NUMBERS are the whole reason band WD3
    # is not vacuous.  `op` must be slot 2 and not slot 1: see the header.
    check "WD0 the three reads register THREE slots in read order -- tran 0, ac 1, op 2 -- and leave the user on the op slot, which is slot 2 and NOT slot 1, because at slot 1 the post-clear restore row below passes by accident" \
        [list [pcall wd_load3] [wd_nslots] [wd_slottype 0] [wd_slottype 1] [wd_slottype 2] \
              [wd_curslot]] \
        {{1 1 1} 3 tran ac op 2}
    check "WD0 results::current answers the op slot while the op slot is current, field by field, which is the value band WD3 compares against" \
        [list [pcall results::_get [pcall results::current] idx] \
              [pcall results::_get [pcall results::current] type] \
              [pcall results::_get [pcall results::current] cur]] {2 op 1}
    # HAZARD 1.  `raw switch <name>` with no type is "switch to the NEXT
    # database", round-robin, and it answers rc 1 from every slot -- so rc says
    # nothing about where it landed.  Driven from all three slots so the claim is
    # about the MECHANISM and not about one lucky starting point.
    check "WD0 HAZARD xschem raw switch <name> WITH NO TYPE does not switch by name at all: it answers rc 1 from every slot while landing on the NEXT one, round-robin -- which is why no restore row below asserts rc" \
        [list [pcall xschem raw switch 0] [pcall xschem raw switch $::fixture] [wd_curslot] \
              [pcall xschem raw switch 1] [pcall xschem raw switch $::fixture] [wd_curslot] \
              [pcall xschem raw switch 2] [pcall xschem raw switch $::fixture] [wd_curslot]] \
        {1 1 1 1 1 2 1 1 0}
    check "WD0 ...while xschem raw switch <name> <type> lands on the named slot from EVERY starting slot, which is the spelling the restore must use" \
        [list [pcall xschem raw switch 0] [pcall xschem raw switch $::fixture op] [wd_curslot] \
              [pcall xschem raw switch 1] [pcall xschem raw switch $::fixture op] [wd_curslot] \
              [pcall xschem raw switch 2] [pcall xschem raw switch $::fixture op] [wd_curslot]] \
        {1 1 2 1 1 2 1 1 2}
    # HAZARD 2 and the two WRONG landings band WD3 exists to exclude.  Measured
    # here, on the bare verbs, so WD3's non-vacuity is a measurement in the same
    # run rather than an argument in a comment.
    pcall xschem raw switch $::fixture op
    pcall xschem raw new __wd_haz table __wd_hazx 0 2 1
    set hazmid [list [wd_curslot] [pcall xschem raw switch $::fixture] [wd_curslot]]
    pcall xschem raw switch $::fixture op
    pcall xschem raw clear __wd_haz table
    set hazclear [list [wd_curslot] [pcall xschem raw switch $::fixture] [wd_curslot]]
    check "WD0 HAZARD raw clear <name> <type> FORCES the current slot to 0 even when the user was on slot 2, and the name-only restore then lands on slot 1 -- so with a two-slot fixture that wrong restore would answer the op slot BY ACCIDENT" \
        [list $hazmid $hazclear] {{3 1 0} {0 1 1}}
    pcall xschem raw switch $::fixture op
    # HAZARD 3.  Reuse without clearing freezes the geometry and serves the
    # previous evaluation's samples.
    pcall xschem raw new __wd_re table __wd_rex 0 2 1
    pcall xschem raw set __wd_rex 0 11.0
    set re_rc2 [pcall xschem raw new __wd_re table __wd_rex 0 9 1]
    check "WD0 HAZARD raw new ON AN EXISTING NAME answers 0, IGNORES the requested geometry and KEEPS the previous samples -- so a producer that reused the name would freeze the point count at its first call and serve stale data" \
        [list $re_rc2 [pcall xschem raw points 0] [wd_at [wd_col __wd_rex 0] 0]] {0 3 11}
    pcall xschem raw clear __wd_re table
    pcall xschem raw switch $::fixture op
    # HAZARD 4.  rc 1 for a database that was not allocated.  The ZERO-point
    # geometry is the one an EMPTY result list asks for, and it is driven here
    # rather than the negative-point one, whose allocation failure writes to
    # stderr and says nothing a row can read.
    set z_rc [pcall xschem raw new __wd_z table __wd_zx 0 -1 1]
    check "WD0 HAZARD raw new answers rc 1 for a database it did not allocate: the span an EMPTY result list asks for yields a database with no points at all, and the only honest test is xschem raw points and never the return value" \
        [list $z_rc [pcall xschem raw points 0] [wd_col __wd_zx 0] \
              [expr {[pcall xschem raw points 0] > 0 ? 1 : 0}]] {1 0 {} 0}
    pcall xschem raw clear __wd_z table
    pcall xschem raw switch $::fixture op
    # HAZARD 5.  The zero fill that draws the false diagonal.  A 5-point database
    # with 3 points written: the SWEEP column keeps new_rawfile's own grid in its
    # tail, and a column made by `raw add <n> {}` keeps ZEROS.
    pcall xschem raw new __wd_pad table __wd_padx 0 4 1
    pcall xschem raw add __wd_pady {}
    for {set i 0} {$i < 3} {incr i} {
        pcall xschem raw set __wd_padx $i [expr {1.0 + $i}]
        pcall xschem raw set __wd_pady $i [expr {7.0 + $i}]
    }
    check "WD0 HAZARD a column created by raw add <name> {} is ZERO-FILLED to the database's whole point count, so an N-point result in a longer database ends at zero -- which is the false diagonal band WD5 fences, measured here on the bare verbs" \
        [list [pcall xschem raw points 0] [wd_col __wd_padx 0] [wd_col __wd_pady 0] \
              [wd_at [wd_col __wd_pady 0] end]] \
        {5 {1 2 3 3 4} {7 8 9 0 0} 0}
    pcall xschem raw clear __wd_pad table
    pcall xschem raw switch $::fixture op
    # HAZARD 6, BOTH SIDES OF THE PRECISION DOOR, on a value with a full
    # mantissa.  `raw values` round-trips it bit-exactly; `raw set`'s own return
    # is "%.8g" and loses it by parts in a billion.
    set pv 0.0009666666666666667
    pcall xschem raw new __wd_pr table __wd_prx 0 1 1
    set set_echo [pcall xschem raw set __wd_prx 0 $pv]
    set bulk_back [wd_at [wd_col __wd_prx 0] 0]
    check "WD0 HAZARD the precision door, both sides: xschem raw values round-trips a full-mantissa double BIT-EXACTLY while xschem raw set's own RETURN is a LOSSY ECHO of the value it stored exactly -- so a producer that trusted the echo, or a row that read it, would be measuring dtoa()'s %.8g" \
        [list [expr {$bulk_back == $pv ? 1 : 0}] \
              [near $bulk_back $pv $WDTOL_TIME] \
              [wd_distinct $set_echo $pv $WDTOL_TIME] \
              [expr {$set_echo == $pv ? 1 : 0}]] \
        {1 ok distinct 0}
    pcall xschem raw clear __wd_pr table
    pcall xschem raw switch $::fixture op
    # §10's surviving half: trace resolution is type-agnostic, so an odd sim_type
    # costs nothing in drawing; and `results::current` answers {} while an
    # odd-typed slot is current, which is the FAIL-SAFE direction and is defence
    # in depth rather than an alternative to restoring the user's slot.
    pcall xschem raw new __wd_ty table __wd_tyx 0 2 1
    check "WD0 a table-typed slot is switchable by name AND type like any other, and results::current answers {} while it is current rather than reporting the Calculator's own scratch output as the user's selected result" \
        [list [pcall xschem raw sim_type] [pcall results::current] \
              [pcall xschem raw switch __wd_ty table] [wd_curslot] \
              [pcall xschem raw non_spice table] [pcall xschem raw non_spice tran]] \
        {table {} 1 3 1 0}
    check "WD0 ...but results::list DOES list it, so it appears in the Results picker whatever its type -- declared here, not fixed by this stage" \
        [llength [pcall results::list]] 4
    pcall xschem raw clear __wd_ty table
    pcall xschem raw switch $::fixture op
    check "WD0 this suite's own wd_finite agrees with calc::eval_finite on every spelling dtoa and the MSVC runtime can emit -- a CHANGE DETECTOR over two byte-identical regexps, NOT independent evidence, because a wrong pattern would be wrong identically in both copies and this row would still be green" \
        [join [lmap v [list 0.5 -0 1e-35 .5 -3.5e-9 inf -inf nan -nan NaN INF 1.#INF -1.#IND 1.#QNAN {} abc] \
                   {list $v [wd_finite $v] [pcall calc::eval_finite $v]}] { }] \
        [join [lmap v [list 0.5 -0 1e-35 .5 -3.5e-9 inf -inf nan -nan NaN INF 1.#INF -1.#IND 1.#QNAN {} abc] \
                   {list $v [wd_finite $v] [wd_finite $v]}] { }]
    check "WD0 wviewer::graph_props is reachable with NO viewer window and NO display, which is what makes band WD4 an hcases band" \
        [list [llength [pcall info procs ::wviewer::graph_props]] \
              [expr {[string match {*flags=graph*} [wd_wv graph_props [wd_graph [list [wd_trace {v(sq)}]]]]] ? 1 : 0}]] \
        {1 1}
    check "WD0 the loaded inventory carries no __calc_tmp* and no __wd_* at band exit, so every R402 row below starts from zero, and the registry is back to the three fixture slots with the user on op" \
        [list [wd_leaked] [wd_probeleft] [wd_nslots] [wd_curslot]] {{} {} 3 2}
}

# =========================================================================
group WD1 {
    # Infrastructure, and the load-bearing band: the deck arithmetic and this
    # file's own D3 + D4 over the bulk columns, against each other, for every
    # number the behavioural bands assert.  No feature is called.  PASSES TODAY.
    pcall wd_load1
    set t0 [wd_col time 0]
    set q0 [wd_col {v(sq)} 0]
    check "WD1 the two columns band WD8 measures read back as lists of 101 finite numbers each, so a count or a sentinel below is the product's doing and not the fixture's" \
        [list [llength $t0] [llength $q0] \
              [llength [lsearch -all -not -inline -exact [lmap v $t0 {wd_finite $v}] 1]] \
              [llength [lsearch -all -not -inline -exact [lmap v $q0 {wd_finite $v}] 1]]] \
        {101 101 0 0}
    # THE LEVEL IS 1/3, AND THE CHOICE IS THE PRECISION BAND'S.  A round level
    # makes band WD6 pass vacuously: see the header.
    set L [expr {1.0/3.0}]
    check "WD1 the level 1/3 is crossed three times rising and twice falling on v(sq), strictly inside its own swing, which is two COMPLETE periods and therefore a two-element per-cycle series" \
        [list [llength [wd_derive $t0 $q0 $L rising]] [llength [wd_derive $t0 $q0 $L falling]]] \
        {3 2}
    check "WD1 R414d every threshold the bands below drive falls STRICTLY BETWEEN two samples on both edges, so the interpolation is fenced and no row can be satisfied by a snapped-to-sample implementation" \
        [list [wd_strictly_between $t0 $q0 $L rising 0] [wd_strictly_between $t0 $q0 $L rising 1] \
              [wd_strictly_between $t0 $q0 $L rising 2] [wd_strictly_between $t0 $q0 $L falling 0] \
              [wd_strictly_between $t0 $q0 $L falling 1]] \
        {strict strict strict strict strict}
    set der [wd_duty_derive $t0 $q0 $L]
    # ⚠ THIS ONE GOES THROUGH `wd_asanswer` ON PURPOSE, and it is the only row that
    # does: it exercises the adapter path -- `wd_islist` -> `wd_disp` -> `wd_val` --
    # over a value this FILE derived, so WD10's claim that the answer shape is
    # known only to the enumerated procs has a live caller behind it rather than a
    # proc nothing runs.
    check "WD1 DERIVATION AGREEMENT the duty fraction from the DECK -- (1.4 - 0.4L)/4 over a 4 ms rising-to-rising period -- equals the one from this file's own D3+D4 over the bulk columns, for both complete cycles" \
        [wd_islist [wd_asanswer [wd_duty_get $der duty]] [list [wdk_duty $L] [wdk_duty $L]]] ok
    check "WD1 DERIVATION AGREEMENT R420's CYCLE-START axis from the deck -- rise(L,k) = 0.9 + 0.2L + 4k ms -- equals the opening rising crossing of each derived period" \
        [wd_listcmp [wd_duty_get $der start] [list [wdk_x_start $L 0] [wdk_x_start $L 1]] $WDTOL] ok
    check "WD1 DERIVATION AGREEMENT R420's MIDPOINT axis from the deck -- the mean of the period's two rising crossings -- equals the one derived from the columns" \
        [wd_listcmp [wd_duty_get $der mid] [list [wdk_x_mid $L 0] [wdk_x_mid $L 1]] $WDTOL] ok
    check "WD1 DERIVATION AGREEMENT R420's CYCLE-NUMBER axis needs no data at all, so the deck and the columns agree by construction -- asserted so that a verb answering an ORDINAL where a TIME was asked for, or the reverse, reddens on a number and not on a word" \
        [wd_listcmp [wd_duty_get $der number] [list [wdk_x_number $L 0] [wdk_x_number $L 1]] $WDTOL] ok
    # ⚠ DERIVATION SELF-CHECK.  Arithmetic over this file's deck procs with no
    # column and no product in it, so no product change can redden it.  It
    # asserts the property band WD8's `distinct` legs rely on: the three axes are
    # mutually distinguishable at WDTOL, which is what makes "the default is
    # cycle-start" a measurable claim rather than a coincidence.
    check "WD1 DERIVATION SELF-CHECK the three X axes are mutually DISTINCT at this file's own tolerance, for both cycles -- without which band WD8's default row could be satisfied by any of the three" \
        [list [wd_distinct [wdk_x_start $L 0] [wdk_x_mid $L 0]] \
              [wd_distinct [wdk_x_start $L 0] [wdk_x_number $L 0]] \
              [wd_distinct [wdk_x_mid $L 0] [wdk_x_number $L 0]] \
              [wd_distinct [wdk_x_start $L 1] [wdk_x_mid $L 1]] \
              [wd_distinct [wdk_x_start $L 1] [wdk_x_number $L 1]] \
              [wd_distinct [wdk_x_mid $L 1] [wdk_x_number $L 1]]] \
        {distinct distinct distinct distinct distinct distinct}
    # ⚠ DERIVATION SELF-CHECK, the second: the duty fraction is LEVEL-DEPENDENT,
    # so a hardcoded 0.3 passes a 0.5-only row.  Band WD8 drives two levels for
    # this reason and this row is why it can.
    check "WD1 DERIVATION SELF-CHECK the deck's duty fraction is LEVEL-DEPENDENT, so an implementation that hardcoded the 50 per cent answer would pass a one-level row -- which is why band WD8 drives two levels" \
        [wd_distinct [wdk_duty $L] [wdk_duty 0.5]] distinct
    check "WD1 the band left no __calc_tmp* and no __wd_* behind" \
        [list [wd_leaked] [wd_probeleft]] {{} {}}
}

# =========================================================================
group WD2 {
    # The producer REGISTERS and NEVER CLEARS.  Route A's first claim, and the
    # one that makes the destination a destination rather than a replacement for
    # the user's result.
    pcall wd_load3
    set L [expr {1.0/3.0}]
    set t0 {} ; set q0 {}
    pcall xschem raw switch $::fixture tran
    set t0 [wd_col time 0] ; set q0 [wd_col {v(sq)} 0]
    pcall xschem raw switch $::fixture op
    set der [wd_duty_derive $t0 $q0 $L]
    set xs [wd_duty_get $der start]
    set ys [wd_duty_get $der duty]
    set h [wd_call wave_dest $xs $ys]
    check "WD2 calc::wave_dest exists and MEASURES rather than refusing for two well-formed parallel lists, reporting the destination's registry name, its sim_type and its point count" \
        [list [wd_disp $h] [expr {[wd_key $h db] ne {} ? 1 : 0}] [wd_key $h type] \
              [wd_key $h n] [wd_msg $h]] \
        [list measured 1 table [llength $ys] {}]
    check "WD2 ...and it REGISTERED a fourth slot rather than clearing the three the user had, which is the whole difference between a destination and a replacement" \
        [list [wd_nslots] [wd_slottype 0] [wd_slottype 1] [wd_slottype 2]] {4 tran ac op}
    # the destination's two columns, read through the bulk door only.  Switching
    # to it and back is the SUITE's doing and is undone here, so a failure in
    # this row cannot move the registry under the next one.
    set dbnm [wd_key $h db]
    set xnm [wd_key $h xname]
    set ynm [wd_key $h yname]
    set gx {} ; set gy {} ; set gpts {} ; set gnames {}
    if {[pcall xschem raw switch $dbnm table] eq {1}} {
        set gx [wd_col $xnm 0] ; set gy [wd_col $ynm 0]
        set gpts [pcall xschem raw points 0] ; set gnames [wd_rawnames]
    }
    pcall xschem raw switch $::fixture op
    check "WD2 the destination holds exactly the two columns it reported, under the names it reported, with one point per value -- so a caller can find the data by the names the answer gave it and not by guessing" \
        [list [lsort $gnames] [expr {$xnm ne $ynm ? 1 : 0}] $gpts] \
        [list [lsort [list $xnm $ynm]] 1 [llength $ys]]
    check "WD2 ...and both columns read back as the lists they were given, element for element, which is the end-to-end claim the three waiting verbs need" \
        [list [wd_listcmp $gx $xs $WDTOL] [wd_listcmp $gy $ys $WDTOL]] {ok ok}
    set drop [wd_call wave_dest_drop $h]
    check "WD2 calc::wave_dest_drop removes the destination and leaves the user's three slots, so the registry is where it started" \
        [list [expr {[string match NOPROC:* $drop] ? $drop : 1}] [wd_nslots] \
              [wd_slottype 0] [wd_slottype 1] [wd_slottype 2]] {1 3 tran ac op}
    check "WD2 R402 the band left no __calc_tmp* and no __wd_* behind" \
        [list [wd_leaked] [wd_probeleft]] {{} {}}
}

# =========================================================================
group WD3 {
    # THE RESULT-SELECTION FENCE.  `results::current` field-by-field identical
    # across an Evaluate that builds a destination, MID-LIFE and POST-CLEAR
    # asserted SEPARATELY, driven from the `op` slot which is slot 2 of three.
    #
    # WHY IT MATTERS MORE THAN IT LOOKS: a leaked destination does not merely
    # redden, it makes every existing `__calc_tmp*` leak row in every sibling
    # suite VACUOUS, because `xschem raw list` then reads the wrong inventory.
    # A row that silently stops measuring is worse than a row that fails.
    pcall wd_load3
    set L [expr {1.0/3.0}]
    pcall xschem raw switch $::fixture tran
    set t0 [wd_col time 0] ; set q0 [wd_col {v(sq)} 0]
    pcall xschem raw switch $::fixture op
    set der [wd_duty_derive $t0 $q0 $L]
    set xs [wd_duty_get $der start]
    set ys [wd_duty_get $der duty]
    set before [pcall results::current]
    set beforeslot [wd_curslot]
    check "WD3 the Evaluate is driven from the op slot, which is slot 2 -- NOT slot 0, where the question this band asks answers YES whatever happened, and NOT slot 1, where the post-clear restore lands correctly by accident" \
        [list $beforeslot [pcall results::_get $before type] [pcall results::_get $before idx]] \
        {2 op 2}
    set h [wd_call wave_dest $xs $ys]
    set mid [pcall results::current]
    set midslot [wd_curslot]
    set midslots [wd_nslots]
    check "WD3 THE MID-LIFE RESTORE: with the destination still registered, the current slot is back on the user's op slot and results::current is byte-identical to what it was before -- and the row asserts WHICH SLOT, because raw switch <name> answers rc 1 while landing on another one" \
        [list $midslot [string equal $mid $before] $midslots] \
        [list 2 1 4]
    # ⚠⚠ THE DISPOSITION AND THE SLOT COUNT ARE THE FIRST TWO ELEMENTS OF EVERY
    # ROW BELOW, AND WITHOUT THEM THREE OF THEM ARE VACUOUS -- measured on this
    # file's own red run, where `results::current` before and after were
    # trivially equal BECAUSE NOTHING HAPPENED.  A restore row that only compares
    # two reads of an unmoved registry is green against a missing producer and
    # green against a correct one, and says nothing about either.
    check "WD3 ...and field by field, so a failure names the field that moved rather than printing two dicts -- with the destination's own disposition and the slot count carried first, because without them this row is green against a producer that never ran" \
        [list [wd_disp $h] $midslots \
              [pcall results::_get $mid idx] [pcall results::_get $mid path] \
              [pcall results::_get $mid type] [pcall results::_get $mid cur] \
              [pcall results::_get $mid label]] \
        [list measured 4 \
              [pcall results::_get $before idx] [pcall results::_get $before path] \
              [pcall results::_get $before type] [pcall results::_get $before cur] \
              [pcall results::_get $before label]]
    set drop [wd_call wave_dest_drop $h]
    set after [pcall results::current]
    set afterslot [wd_curslot]
    check "WD3 THE POST-CLEAR RESTORE, ASSERTED SEPARATELY: raw clear forces the current slot to 0 unconditionally, so cleanup owes a SECOND explicit restore -- and after it the user is back on slot 2 with results::current byte-identical again, with the FOUR-slot mid-life state carried in so the row cannot be satisfied by a destination that was never built" \
        [list [wd_disp $h] $midslots $afterslot [string equal $after $before] [wd_nslots]] \
        [list measured 4 2 1 3]
    check "WD3 ...field by field after the clear as well, which is where an implementation with ONE restore instead of two reports the tran slot at index 0" \
        [list [wd_disp $h] $midslots \
              [pcall results::_get $after idx] [pcall results::_get $after type] \
              [pcall results::_get $after cur]] \
        [list measured 4 \
              [pcall results::_get $before idx] [pcall results::_get $before type] \
              [pcall results::_get $before cur]]
    check "WD3 R402 the band left no __calc_tmp* and no __wd_* behind, across both restores" \
        [list [wd_leaked] [wd_probeleft]] {{} {}}
}

# =========================================================================
group WD4 {
    # §9's ONE FENCE, and it asserts THE POSITIVE SHAPE rather than the absence
    # of a wrong rendering -- that rule is in CLAUDE.md because a symptom-keyed
    # fence dies quietly when something else cures the symptom, and here it has a
    # second reason: ALL SEVEN graph walkers carry the `sweep=` token forward
    # with their own copy of the idiom, so a fence that only renders misses six.
    #
    # ⚠ THE MIXED-AXIS TRACE SITS IN THE MIDDLE OF THE STRIP.  In LAST position
    # the carry-forward defect is invisible: there is no later trace for the
    # carried token to re-axe.
    pcall wd_load1
    set sw [wd_at [wd_rawnames] 0]
    set plain [list [wd_trace {v(sq)}] [wd_trace {v(ramp)}] [wd_trace {v(div)}]]
    set mixed [list [wd_trace {v(sq)}] [wd_trace calcy calcx] [wd_trace {v(ramp)}]]
    set five [list [wd_trace {v(sq)}] [wd_trace {v(ramp)}] [wd_trace calcy calcx] \
                   [wd_trace {v(div)}] [wd_trace {v(lp)}]]
    set tp [wd_sweeptoks [wd_wv graph_props [wd_graph $plain]]]
    set tm [wd_sweeptoks [wd_wv graph_props [wd_graph $mixed]]]
    set tf [wd_sweeptoks [wd_wv graph_props [wd_graph $five]]]
    check "WD4 graph_props emits ONE sweep= token PER TRACE for a strip whose MIDDLE trace carries its own X axis -- the count is what matters, because a list SHORTER than node= carries its last token forward and silently re-axes every trace after the special one" \
        [wd_len $tm] 3
    check "WD4 ...and the tokens are IN NODE ORDER, with the middle one naming the own-X column and the two ordinary ones naming the same column as each other -- which is the order a reader of node= and sweep= side by side depends on" \
        [list [wd_at $tm 1] [string equal [wd_at $tm 0] [wd_at $tm 2]] \
              [string equal [wd_at $tm 0] calcx]] \
        {calcx 1 0}
    check "WD4 ...and the ordinary traces' token names a REAL column of the loaded database rather than a literal or an empty string, so the token is resolvable by name the way all seven walkers resolve it" \
        [list [pcall xschem raw index [wd_at $tm 0]] [string equal [wd_at $tm 0] $sw]] \
        {0 1}
    check "WD4 ...and the same claim on a FIVE-trace strip with the own-X trace third, so the count is a property of the generator and not of a three-element coincidence" \
        [list [wd_len $tf] [wd_at $tf 2] [string equal [wd_at $tf 0] [wd_at $tf 4]]] \
        {5 calcx 1}
    # ⚠ ABSENT AND SHORT ARE TWO DIFFERENT DEFECTS, and this row forbids SHORT in
    # both designs: a generator that emits the token only when some trace needs
    # one is a legitimate choice (it keeps every pre-existing strip's rect text
    # unchanged), and a generator that always emits it is too.  What neither may
    # do is emit a list shorter than the trace count, which is the one shape that
    # silently re-axes.
    check "WD4 a sweep= list is never SHORT: for a strip of three ordinary traces the generator emits either no token at all or exactly three, and never one or two -- absent makes every trace fall to column 0, short carries the last token forward, and only the second is silent" \
        [list [wd_countin [wd_len $tp] {0 3}] [wd_countin [wd_len $tm] {3}] \
              [wd_countin [wd_len $tf] {5}]] \
        {inrange inrange inrange}
    # change site 1 of the contract's §8.  `add_trace` answers "unknown viewer
    # window" with no viewer, so the key it puts on `trd` cannot be read here
    # (hole H3) -- the parameter can.
    set atargs [pcall info args ::wviewer::add_trace]
    check "WD4 wviewer::add_trace takes a SWEEP argument, so a caller can say which X axis a trace is on -- and it is the LAST parameter, which keeps every existing six-argument call site byte-identical" \
        [list [wd_len $atargs] [wd_at $atargs 6] [wd_at $atargs 5]] \
        {7 sweep db}
    # ⚠ TWO ARITIES THAT MUST NOT MOVE, measured rather than remembered.  Row GT8
    # of test_wave_grid.tcl asserts graph_props takes exactly three parameters
    # with the third named `grid`; row BM05 of test_wave_sigbrowser.tcl asserts
    # plot_signals' four-parameter signature as a LITERAL SOURCE STRING, and a
    # five-argument call to it raises "too many arguments" into a catch that
    # swallows it, so every browser gesture check would read as "the gesture did
    # nothing".  The sweep must therefore travel in the trace dict and through the
    # existing out-of-band one-shot channel, never as a new parameter on either.
    check "WD4 graph_props keeps its THREE parameters and plot_signals its FOUR, both of which are pinned by rows in other suites -- so the sweep travels in the trace dict and through the armed one-shot channel, never as a new parameter" \
        [list [llength [pcall info args ::wviewer::graph_props]] \
              [lindex [pcall info args ::wviewer::graph_props] 2] \
              [llength [pcall info args ::wviewer::plot_signals]] \
              [llength [pcall info procs ::wviewer::plot_dbs_arm]] \
              [llength [pcall info procs ::wviewer::plot_dbs_take]]] \
        {3 grid 4 1 1}
    # ⚠⚠ THE ONE ROW IN THIS BAND THAT IS NOT DRIVEN ON `tran`, AND IT IS HERE
    # BECAUSE A SABOTAGE SURVIVED THE BAND'S FIRST REVISION.  `set swdflt time`
    # in `wviewer::graph_props` -- hardcoding the ordinary trace's X name instead
    # of reading it -- gave `ALL PASS` on every row above, because the `tran`
    # fixture's own first raw vector IS `time`.  So the rows above cannot tell a
    # generator that READS the name from one that ASSUMES it, and this row is the
    # whole of that discrimination: on the AC analysis the same strip must name
    # `frequency`, and the last leg asserts it is NOT the `tran` name, which is
    # the hardcoded answer stated positively as a difference rather than as an
    # absence.
    #
    # ⚠ IT RUNS LAST IN THE BAND AND PUTS THE `tran` READ BACK, and that
    # placement is load-bearing in the other direction: three rows above resolve
    # a column name against the CURRENT database AT CHECK TIME
    # (`xschem raw index`, and `$sw` from `wd_rawnames`), so a band that left
    # `ac` current would make them fail instead of measuring -- which is exactly
    # how closing one hole opens another.  `$sw` and `$tp`/`$tm`/`$tf` are all
    # captured while `tran` was current, above, so nothing here can move them.
    set tmac {} ; set acsw {}
    if {[pcall wd_load1ac] eq {1}} {
        set acsw [wd_at [wd_rawnames] 0]
        set tmac [wd_sweeptoks [wd_wv graph_props [wd_graph $mixed]]]
    }
    check "WD4 the ordinary traces' token is READ out of the current database and never hardcoded: on the AC analysis the SAME strip names frequency in both ordinary positions and still names calcx in the middle, and the token is DIFFERENT from the tran sweep name -- which is the one claim every row above this one is blind to, because the tran fixture's own first vector IS time" \
        [list $acsw [wd_len $tmac] [wd_at $tmac 0] [wd_at $tmac 1] [wd_at $tmac 2] \
              [string equal [wd_at $tmac 0] $sw]] \
        [list frequency 3 frequency calcx frequency 0]
    pcall wd_load1
    check "WD4 R402 the band left no __calc_tmp* and no __wd_* behind, and the tran read the rows above resolve against is the current database again" \
        [list [wd_leaked] [wd_probeleft] [pcall xschem raw sim_type] \
              [pcall xschem raw index $sw]] {{} {} tran 0}
}

# =========================================================================
group WD5 {
    # THE HOLD-PAD.  `raw_add_vector()` makes every column as long as the
    # database and ZERO-FILLS it, and `draw_graph` plots the whole dataset, so an
    # N-point result in a longer database draws a FALSE DIAGONAL from its last
    # real sample back to (0, 0).  WD0's hazard row measured that on the bare
    # verbs; this band fences the producer against it.
    #
    # ⚠ THE CLAIM IS THE POSITIVE ONE -- the LAST sample of each column IS the
    # last real value -- and not the absence of a zero.  It holds for a producer
    # that sizes the database exactly to the result AND for one that hold-pads a
    # longer database, and it fails only for the zero fill.  The first row's
    # "first N samples" leg is what keeps it honest if the producer pads.
    pcall wd_load3
    set L [expr {1.0/3.0}]
    pcall xschem raw switch $::fixture tran
    set t0 [wd_col time 0] ; set q0 [wd_col {v(sq)} 0]
    pcall xschem raw switch $::fixture op
    set der [wd_duty_derive $t0 $q0 $L]
    set xs [wd_duty_get $der start]
    set ys [wd_duty_get $der duty]
    set h [wd_call wave_dest $xs $ys]
    set dbnm [wd_key $h db] ; set xnm [wd_key $h xname] ; set ynm [wd_key $h yname]
    set gx {} ; set gy {} ; set gpts {}
    if {[pcall xschem raw switch $dbnm table] eq {1}} {
        set gx [wd_col $xnm 0] ; set gy [wd_col $ynm 0] ; set gpts [pcall xschem raw points 0]
    }
    pcall xschem raw switch $::fixture op
    set n [llength $ys]
    # ⚠⚠ THE POINT COUNT IS ASSERTED EXACTLY, AND THAT IS A CORRECTION TO THE
    # CONTRACT RATHER THAN A RESTATEMENT OF IT.  DESTINATION_CONTRACT §7 says the
    # producer "must hold-pad the tail at the last real value", which is a remedy
    # for a database LONGER than the result -- and a database longer than the
    # result is a CHOICE, not a constraint: `xschem raw new <db> table <x> 0 <n-1>
    # 1` yields exactly n points, measured for every n this file drives.  Sizing
    # it exactly removes the false diagonal AT SOURCE instead of painting over it,
    # and it also removes the contract's second note, that `xschem raw pos_at` is
    # a binary search answering -1 or garbage on a padded column.  A padding
    # producer can still satisfy the two rows below; it cannot satisfy this one,
    # and this one is the only row in the band that a producer which SIZES
    # EXACTLY can fail -- measured, by a mutation that zero-padded and passed the
    # other two because there was no tail to get wrong.
    check "WD5 the destination is EXACTLY as long as the result on both columns, which is what makes the false diagonal unreachable rather than merely painted over -- a frozen, rounded or fixed geometry fails here and nowhere else in this band" \
        [list [wd_countin $gpts [list $n]] \
              [wd_listcmp [lrange $gx 0 [expr {$n-1}]] $xs $WDTOL] \
              [wd_listcmp [lrange $gy 0 [expr {$n-1}]] $ys $WDTOL]] \
        {inrange ok ok}
    check "WD5 THE LAST SAMPLE of each column IS the result's last value, so the trace does not run back to zero: that final segment from the last real sample to (0, 0) is what raw_add_vector's zero fill draws and it is the one thing a viewer shows that nobody asked for" \
        [list [near [wd_at $gy end] [lindex $ys end] $WDTOL] \
              [near [wd_at $gx end] [lindex $xs end] $WDTOL]] \
        {ok ok}
    check "WD5 ...and NO sample of either column past the result's last one differs from it, which is the whole tail stated positively rather than as the absence of a zero -- VACUOUS when the producer sizes the database exactly, which is declared and is why the row above is the live one" \
        [list [wd_tailholds $gy $n [lindex $ys end] $WDTOL] \
              [wd_tailholds $gx $n [lindex $xs end] $WDTOL]] \
        {ok ok}
    pcall wd_call wave_dest_drop $h
    check "WD5 R402 the band left no __calc_tmp* and no __wd_* behind, and the registry is back to three slots with the user on op" \
        [list [wd_leaked] [wd_probeleft] [wd_nslots] [wd_curslot]] {{} {} 3 2}
}

# =========================================================================
group WD6 {
    # PRECISION, at the fixture's OWN tolerance and not at this file's looser
    # one: a producer that stored through the lossy door would pass at 1e-7, and
    # that is the whole defect.  The level is 1/3 for the reason the header
    # gives -- at a round level "%.8g" round-trips to within one ulp and this
    # band's discrimination leg would be red on a correct tree.
    pcall wd_load3
    set L [expr {1.0/3.0}]
    pcall xschem raw switch $::fixture tran
    set t0 [wd_col time 0] ; set q0 [wd_col {v(sq)} 0]
    pcall xschem raw switch $::fixture op
    set der [wd_duty_derive $t0 $q0 $L]
    set xs [wd_duty_get $der start]
    set ys [wd_duty_get $der duty]
    # the discrimination, DERIVED every run rather than asserted as a figure: the
    # "%.8g" spelling of each crossing time must be DETECTABLY different from the
    # crossing time at the fixture's own 1e-12.
    set lossy {}
    foreach x $xs { lappend lossy [wd_distinct [format %.8g $x] $x $WDTOL_TIME] }
    check "WD6 THE DISCRIMINATION IS REAL AT THIS LEVEL: every cycle-start time the band asserts is DETECTABLY changed by the %.8g door at the fixture's own 1e-12 for time -- which is false at a round level such as 0.5, where this band would be red on a correct tree" \
        $lossy [lrepeat [llength $xs] distinct]
    set h [wd_call wave_dest $xs $ys]
    set dbnm [wd_key $h db] ; set xnm [wd_key $h xname]
    set gx {}
    if {[pcall xschem raw switch $dbnm table] eq {1}} { set gx [wd_col $xnm 0] }
    pcall xschem raw switch $::fixture op
    set n [llength $xs]
    check "WD6 a real interpolated crossing time round-trips through the destination inside the fixture's documented 1e-12 relative headroom for time, read back ONLY with xschem raw values -- a producer storing through dtoa()'s %.8g lands three orders of magnitude outside it" \
        [wd_listcmp [lrange $gx 0 [expr {$n-1}]] $xs $WDTOL_TIME] ok
    set exact {}
    for {set i 0} {$i < $n} {incr i} {
        set g [wd_at $gx $i]
        if {![wd_finite $g]} { lappend exact "notanumber:{$g}" ; continue }
        lappend exact [expr {$g == [lindex $xs $i] ? 1 : 0}]
    }
    check "WD6 ...and BIT-EXACTLY, which is what route A buys and route B could not: raw set parses with C atof() and stores the double, so nothing between the measurement and the destination rounds" \
        $exact [lrepeat $n 1]
    pcall wd_call wave_dest_drop $h
    check "WD6 R402 the band left no __calc_tmp* and no __wd_* behind" \
        [list [wd_leaked] [wd_probeleft] [wd_nslots]] {{} {} 3}
}

# =========================================================================
group WD7 {
    # `raw new`'s LYING RC, and the name-reuse hazard, both as producer fences.
    pcall wd_load3
    set before [pcall results::current]
    set nslots0 [wd_nslots]
    set he [wd_call wave_dest {} {}]
    check "WD7 an EMPTY result list is REFUSED in the house sentence shape rather than minting a database raw new would have answered rc 1 for -- the span 0..-1 yields a database with no points, and CROSS_CONTRACT T5 says an empty crossing list really does arrive here" \
        [list [wd_disp $he] [wd_shape [wd_msg $he]]] {refused ok}
    # ⚠ THE DISPOSITION IS CARRIED FIRST HERE TOO: "nothing was registered" is
    # trivially true of a producer that does not exist, so without the `refused`
    # leg this row is green on the red run and measures nothing.
    check "WD7 ...and it REGISTERED NOTHING, which is the half rc cannot tell you: the registry and the user's selected result are both where they were, asserted together with the REFUSAL so the row cannot be satisfied by a producer that never ran" \
        [list [wd_disp $he] [wd_nslots] [wd_curslot] \
              [string equal [pcall results::current] $before]] \
        [list refused $nslots0 2 1]
    check "WD7 a MISMATCHED pair of lists is refused too, in the same shape, so a caller cannot build a destination whose two columns disagree about how many points it has" \
        [list [wd_disp [set a [wd_call wave_dest {1 2 3} {0.1 0.2}]]] [wd_shape [wd_msg $a]] \
              [wd_nslots]] \
        [list refused ok $nslots0]
    check "WD7 a NON-FINITE value on either side is refused, which is the D7 disposition cross already uses and is not an absence" \
        [list [wd_disp [wd_call wave_dest {1 nan 3} {0.1 0.2 0.3}]] \
              [wd_disp [wd_call wave_dest {1 2 3} {0.1 inf 0.3}]] \
              [wd_nslots]] \
        [list refused refused $nslots0]
    # THE NAME-REUSE HAZARD.  Two evaluations, the second SHORTER, and the second
    # must serve its OWN data.  `raw new` on an existing name answers 0, keeps the
    # old geometry and keeps the old samples, so a producer with a fixed
    # destination name freezes at the first call.
    # ⚠⚠ THE FIRST DESTINATION IS DELIBERATELY NOT DROPPED BEFORE THE SECOND CALL,
    # and dropping it is what made an earlier revision of this row VACUOUS --
    # measured, by a mutation that pinned the destination to a single fixed name
    # and PASSED, because with the first destination already cleared `raw new`
    # created a fresh one and the hazard never fired.  The hazard IS reuse of a
    # name that is still registered, so the row has to leave it registered.
    set h1 [wd_call wave_dest {1.0 2.0 3.0 4.0} {0.11 0.22 0.33 0.44}]
    set h2 [wd_call wave_dest {5.0 6.0} {0.55 0.66}]
    set dbnm [wd_key $h2 db] ; set xnm [wd_key $h2 xname] ; set ynm [wd_key $h2 yname]
    set gx {} ; set gy {} ; set gpts {}
    if {[pcall xschem raw switch $dbnm table] eq {1}} {
        set gx [wd_col $xnm 0] ; set gy [wd_col $ynm 0] ; set gpts [pcall xschem raw points 0]
    }
    pcall xschem raw switch $::fixture op
    check "WD7 a SECOND evaluation with a DIFFERENT point count serves ITS OWN data and not the first evaluation's -- raw new on an existing name answers 0, ignores the requested geometry and keeps the previous samples, so a fixed destination name would freeze the count at four and serve 0.11 where 0.55 was measured" \
        [list [wd_key $h2 n] $gpts [wd_listcmp $gx {5.0 6.0} $WDTOL] \
              [wd_listcmp $gy {0.55 0.66} $WDTOL] \
              [string equal [wd_key $h1 db] [wd_key $h2 db]]] \
        {2 2 ok ok 0}
    pcall wd_call wave_dest_drop $h2
    pcall wd_call wave_dest_drop $h1
    check "WD7 R402 the band left no __calc_tmp* and no __wd_* behind, and both evaluations' destinations are gone" \
        [list [wd_leaked] [wd_probeleft] [wd_nslots] [wd_curslot]] {{} {} 3 2}
}

# =========================================================================
group WD8 {
    # R420's THREE X MODES, each asserted independently, and the default measured
    # WITH NO ARGUMENT GIVEN -- because a default nobody drives without naming it
    # is not a default anyone has measured.
    pcall wd_load1
    set L [expr {1.0/3.0}]
    set t0 [wd_col time 0] ; set q0 [wd_col {v(sq)} 0]
    set der [wd_duty_derive $t0 $q0 $L]
    set duty [wd_duty_get $der duty]
    set xstart [wd_duty_get $der start]
    set xmid [wd_duty_get $der mid]
    set xnum [wd_duty_get $der number]
    # the Y half is R416's and ships today; it is asserted here so that a failure
    # in an X row is demonstrably about the X and not about the series.
    set a [wd_call dutyCycle {v(sq)} $L]
    check "WD8 R416 the per-cycle series itself is unchanged by this stage -- one FRACTION per COMPLETE cycle, two of them at this level -- so a failure in an X row below is about the X axis and not about the series" \
        [list [wd_disp $a] [wd_islist $a $duty]] {measured ok}
    check "WD8 R420 THE DEFAULT IS CYCLE-START, MEASURED WITH NO ARGUMENT GIVEN: the answer carries a parallel X series and it is the time each cycle STARTED, which is the user's own words -- *default can be time the cycle started*" \
        [list [wd_disp $a] [wd_listcmp [wd_key $a sweep] $xstart $WDTOL]] {measured ok}
    check "WD8 R420 ...and the default is not merely A series: it is the SAME as cycle-start and DISTINCT from the other two axes, so a default that answered the midpoint or the ordinal reddens here on a word rather than on a reproducible number" \
        [list [wd_cmpword [wd_key $a sweep] $xstart] [wd_cmpword [wd_key $a sweep] $xmid] \
              [wd_cmpword [wd_key $a sweep] $xnum]] \
        {same distinct distinct}
    check "WD8 R420 the CYCLE-START axis named EXPLICITLY answers the same series the default does, so the default is the named value and not a fourth behaviour" \
        [list [wd_disp [set s [wd_call dutyCycle {v(sq)} $L 0 0 start]]] \
              [wd_listcmp [wd_key $s sweep] $xstart $WDTOL] \
              [wd_islist $s $duty]] {measured ok ok}
    check "WD8 R420 the CYCLE-NUMBER axis answers the ordinals 1..N and nothing scaled by a time, which is the one of the three that needs no data at all" \
        [list [wd_disp [set s [wd_call dutyCycle {v(sq)} $L 0 0 number]]] \
              [wd_listcmp [wd_key $s sweep] $xnum $WDTOL] \
              [wd_islist $s $duty]] {measured ok ok}
    check "WD8 R420 the CYCLE-MIDPOINT axis answers the mean of each period's two rising crossings -- derived twice, from the deck and from the columns, in band WD1" \
        [list [wd_disp [set s [wd_call dutyCycle {v(sq)} $L 0 0 mid]]] \
              [wd_listcmp [wd_key $s sweep] $xmid $WDTOL] \
              [wd_islist $s $duty]] {measured ok ok}
    check "WD8 R420 the three axes ANSWER DIFFERENTLY from each other on the same call, which is what makes each row above a measurement of ITS axis rather than of whichever one the verb happens to build" \
        [list [wd_distinct [wd_at [wd_key [wd_call dutyCycle {v(sq)} $L 0 0 start] sweep] 0] \
                           [wd_at [wd_key [wd_call dutyCycle {v(sq)} $L 0 0 mid] sweep] 0]] \
              [wd_distinct [wd_at [wd_key [wd_call dutyCycle {v(sq)} $L 0 0 start] sweep] 0] \
                           [wd_at [wd_key [wd_call dutyCycle {v(sq)} $L 0 0 number] sweep] 0]] \
              [wd_distinct [wd_at [wd_key [wd_call dutyCycle {v(sq)} $L 0 0 mid] sweep] 0] \
                           [wd_at [wd_key [wd_call dutyCycle {v(sq)} $L 0 0 number] sweep] 0]]] \
        {distinct distinct distinct}
    # the level-dependence, so a hardcoded answer fails: band WD1's second
    # self-check is what says this row can tell the two levels apart.
    set b [wd_call dutyCycle {v(sq)} 0.5]
    set der5 [wd_duty_derive $t0 $q0 0.5]
    check "WD8 R420 the X axis is read from the LEVEL like the series is: at 0.5 both the fractions and the cycle-start times differ from their values at 1/3, so an implementation that hardcoded either reddens" \
        [list [wd_islist $b [wd_duty_get $der5 duty]] \
              [wd_listcmp [wd_key $b sweep] [wd_duty_get $der5 start] $WDTOL] \
              [wd_distinct [wd_at [wd_key $b sweep] 0] [lindex $xstart 0]]] \
        {ok ok distinct}
    # a NAMED cycle is a scalar, and its X must be that cycle's X and not the
    # whole series -- the one shape where `value` and `sweep` are both scalars.
    check "WD8 R420 a NAMED cycle answers a SCALAR fraction and a SCALAR X for that cycle, from either end, so the parallel-series invariant holds for the scalar case too rather than only for the wave case" \
        [list [wd_is [set c [wd_call dutyCycle {v(sq)} $L 2]] [lindex $duty 1]] \
              [near [wd_key $c sweep] [lindex $xstart 1] $WDTOL] \
              [wd_is [set d [wd_call dutyCycle {v(sq)} $L -1]] [lindex $duty end]] \
              [near [wd_key $d sweep] [lindex $xstart end] $WDTOL] \
              [near [wd_key [wd_call dutyCycle {v(sq)} $L 1 0 number] sweep] 1 $WDTOL]] \
        {ok ok ok ok ok}
    check "WD8 D7 an X-axis token the verb cannot interpret is REFUSED in the house sentence shape, which is the same disposition a bad edge gets and is never an absence" \
        [list [wd_disp [set e [wd_call dutyCycle {v(sq)} $L 0 0 sideways]]] \
              [wd_shape [wd_msg $e]] \
              [wd_disp [set f [wd_call dutyCycle {v(sq)} $L 0 0 {}]]] \
              [wd_shape [wd_msg $f]]] \
        {refused ok refused ok}
    check "WD8 R420 the existing four-argument spelling still answers, so every call site written before this stage -- including the rows of test_calc_measure.tcl -- is byte-identical in behaviour" \
        [list [wd_disp [wd_call dutyCycle {v(sq)} $L]] [wd_disp [wd_call dutyCycle {v(sq)} $L 1]] \
              [wd_disp [wd_call dutyCycle {v(sq)} $L 1 0]] \
              [wd_disp [wd_call dutyCycle {v(sq)} $L 0 9]]] \
        {measured measured measured refused}
    # ONE END-TO-END ROW: the verb's own two lists, straight into the
    # destination, with nothing of this file's derivation in between.
    #
    # ⚠ IT STAYS ON THE `tran` READ, and that is a measured correction rather
    # than a simplification.  Written against the three-slot registry with the
    # user on `op`, the `dutyCycle` call here measures the OPERATING-POINT
    # database -- which has no sweep column at all -- so `cross` refuses it and
    # the row fails for a reason that has nothing to do with the destination.
    # The registry hazards are band WD3's subject; this row's subject is the
    # hand-off.
    set g [wd_call dutyCycle {v(sq)} $L 0 0 start]
    set h [wd_call wave_dest [wd_key $g sweep] [wd_val $g]]
    set dbnm [wd_key $h db] ; set xnm [wd_key $h xname] ; set ynm [wd_key $h yname]
    set gx {} ; set gy {}
    if {[pcall xschem raw switch $dbnm table] eq {1}} {
        set gx [wd_col $xnm 0] ; set gy [wd_col $ynm 0]
    }
    pcall xschem raw switch $::fixture tran
    check "WD8 END TO END: dutyCycle's OWN two lists reach the destination and read back out of it, with nothing of this suite's derivation in between -- which is the claim R416's deferred surface has been waiting on" \
        [list [wd_disp $g] [wd_disp $h] [wd_listcmp $gx $xstart $WDTOL] \
              [wd_listcmp $gy $duty $WDTOL]] \
        {measured measured ok ok}
    pcall wd_call wave_dest_drop $h
    check "WD8 R402 the band left no __calc_tmp* and no __wd_* behind, across its measured and refusing paths, and the single tran slot this band runs on is the current one again" \
        [list [wd_leaked] [wd_probeleft] [wd_nslots] [wd_curslot]] {{} {} 1 0}
}

# =========================================================================
group WD9 {
    # THE DEFERRAL SENTENCE STAYS SHARED.  Rows MT7 and MT8 of
    # test_calc_measure.tcl -- `hcases`, headless, and they gate -- compare
    # against `[calc::cross_msg listdefer]` by IDENTITY and never by words.  So a
    # REWORDED but still shared sentence costs nothing, and a sentence SPLIT PER
    # CALLER reddens both.  This band pins the sharing by name, so a future split
    # fails HERE with a name instead of THERE with a puzzle.  PASSES TODAY.
    #
    # ⚠ THE WORDS ARE NEVER ASSERTED.  That sentence is unratified user-visible
    # wording, the `rule` debt filed against `calc::eval_msg`'s sentences covers
    # it, and this stage's own contract requires it to CHANGE -- the clause
    # claiming a destination that can hold a WAVE has to come first is the
    # refuted claim R419 killed.  A row asserting the text would redden on the
    # correction.
    pcall wd_load1
    set s [pcall calc::cross_msg listdefer]
    check "WD9 the deferral sentence is ONE non-empty sentence in the house shape, which is what makes the identity rows below evidence rather than three empty strings compared against each other" \
        [list [expr {$s ne {} ? 1 : 0}] [wd_shape $s]] {1 ok}
    check "WD9 ALL THREE deferring callers answer THAT SAME SENTENCE BY IDENTITY -- cross_scalar's nth 0, delay's nth 0 on a side, and dutyCycle_scalar's default cycle -- so splitting it per caller reddens here with a name, and rewording it costs nothing anywhere" \
        [list [wd_disp [set a [wd_call cross_scalar {v(sq)} 0.5 0 rising]]] \
              [string equal [wd_msg $a] $s] \
              [wd_disp [set b [wd_call delay {v(sq)} 0.5 rising 0 {v(sq)} 0.5 falling 1]]] \
              [string equal [wd_msg $b] $s] \
              [wd_disp [set c [wd_call dutyCycle_scalar {v(sq)} 0.5]]] \
              [string equal [wd_msg $c] $s]] \
        {refused 1 refused 1 refused 1}
    check "WD9 ...and pairwise between the callers, so the row cannot be satisfied by three callers that each match cross_msg while differing from each other, which is impossible by construction and is asserted anyway because that is what identity means" \
        [list [string equal [wd_msg $a] [wd_msg $b]] [string equal [wd_msg $b] [wd_msg $c]]] {1 1}
    # ⚠ THE CALLER SET IS DERIVED FROM THE NAMESPACE, NOT LISTED, because a hand-kept
    # list is the same defect one level up -- and there is a live FOURTH candidate:
    # `calc::riseTime` with nth 0 RAISES today where its two siblings defer, which is
    # issue 1639 and is filed OPEN.  If that is fixed by making it defer, this row
    # reddens saying the band does not drive the new caller, which is a legible
    # instruction; without the derivation the fourth caller would simply go unfenced.
    set wd_defcallers {}
    foreach pr [lsort [pcall info procs ::calc::*]] {
        set b [pcall info body $pr]
        if {[string match ERR:* $b]} continue
        if {[regexp {cross_msg +listdefer} [pcall wd_code $b]]} {
            lappend wd_defcallers [namespace tail $pr]
        }
    }
    check "WD9 the set of callers that defer behind that sentence is DERIVED over the namespace and is exactly the three this band drives -- so a FOURTH deferring caller reddens here naming itself, instead of inheriting a shared sentence nothing checks" \
        [list $wd_defcallers [wd_atleast [llength $wd_defcallers] 3]] \
        {{cross_scalar delay dutyCycle_scalar} atleast}
    check "WD9 R402 the band left no __calc_tmp* and no __wd_* behind" \
        [list [wd_leaked] [wd_probeleft]] {{} {}}
}

# =========================================================================
group WD10 {
    # Hygiene and shape.  Runs last.
    pcall wd_load1
    # ⚠ THE HELPER IS NOT NAMED `calc::dest_*`, MEASURED AND NOT PREFERRED.  Rows
    # CE8 and PL9 glob `dest_*` out of `::calc::` and then assert an EXACT LITERAL
    # LIST of the members whose code names no widget path.  A `calc::dest_new`
    # lands in both and reddens both -- one on `hcases`, one on the `dcases`-only
    # arm that only a gate runs.  A naming collision with another suite's glob is
    # not a thing to discover in a gate.
    check "WD10 the destination helper is NOT named calc::dest_*, because rows CE8 and PL9 of two sibling suites glob that prefix into a proc set and assert an exact literal list -- so this prefix answers exactly what it answered before this stage" \
        [wd_calc_dest_procs] {dest_changed}
    check "WD10 ...and calc::wave_dest exists under a name NEITHER of those two globs matches, which is the positive half of the same claim" \
        [list [llength [pcall info procs ::calc::wave_dest]] \
              [llength [pcall info procs ::calc::wave_dest_drop]] \
              [llength [pcall info procs ::calc::plot_wave_dest]] \
              [llength [pcall info procs ::calc::dest_new]]] \
        {1 1 0 0}
    # the decommenter's own non-vacuity, before anything is concluded from it.
    set cb [pcall info body ::calc::cross]
    set cc [pcall wd_code $cb]
    check "WD10 the decommenter is NOT VACUOUS: on a proc that ships today it leaves a long body behind, it DID remove something, and it keeps the code -- so a `no widget path` verdict below is evidence rather than an artefact of an empty string" \
        [list [wd_longer $cc 400] [wd_shrunk $cc $cb] \
              [expr {[regexp {calc::cross_refusal} $cc] ? 1 : 0}] \
              [wd_hascomments $cc]] \
        {long shorter 1 clean}
    check "WD10 the producer's CODE names no .calc widget path, which is what keeps it reachable with no window and makes this an hcases band -- the same claim CE8 makes of every engine-side phase-3 proc, and it NAMES a missing proc instead of answering clean for one, which is how the obvious spelling of this row would have been green on the red run" \
        [list [wd_nowidget ::calc::wave_dest] [wd_nowidget ::calc::wave_dest_drop]] \
        {clean clean}
    # ⚠⚠ EVERY `calc::cross_msg` ARM EXERCISED, AND THE REASON IS A PARSE ERROR
    # `info complete` CANNOT SEE.  One stage earlier a four-line comment placed
    # BETWEEN TWO `switch` PATTERNS in this very proc left the braces balanced and
    # `info complete` answering 1, while Tcl raised *"extra switch pattern with no
    # body"* out of EVERY arm -- 34 rows red at once, three of them in another
    # suite.  Nothing structural distinguishes a safe comment above a proc from a
    # fatal one between two patterns, and a brace-balance scan is blind to it.
    # THE ONLY CONFIRMATION IS BEHAVIOURAL, so this row asks every arm this stage
    # touches and asserts that none raises and none answers empty.
    set arms {empty nodata dataset allpoints intdataset nosweep badnth badlevel badedge
              badtoken noname stale engine absent listdefer noswing zeroswing badref
              badpct nohigh badcycle nocycle nocycleat nofall}
    set bad {}
    foreach k $arms {
        set m [pcall calc::cross_msg $k a b]
        if {[string match ERR:* $m]} { lappend bad "$k:RAISED" ; continue }
        if {$m eq {}} { lappend bad "$k:EMPTY" }
    }
    check "WD10 every calc::cross_msg arm this stage touches answers a non-empty sentence without raising -- the only confirmation there is that no comment landed between two switch patterns, which balances the braces, satisfies info complete and reddens every arm at once" \
        $bad {}
    check "WD10 ...and an UNKNOWN kind still falls through to the empty string rather than raising, so a caller naming an arm that does not exist gets a legible empty message and not a Tcl error" \
        [pcall calc::cross_msg __wd_no_such_kind__] {}
    # ⚠⚠ A REGISTERED `hcases` SUITE WILL REDDEN ON THIS STAGE, AND IT IS NOT A
    # DEFECT -- IT IS THE SAME EDIT `cross` OWED ONE STAGE EARLIER.  Row SR5 of
    # tests/headless/test_calc_scratch_reuse.tcl derives FOUR sets over the
    # `::calc::` namespace -- the procs that MINT a temporary through
    # `calc::tmpvec`, the ones that issue `xschem raw add`, the ones that READ
    # samples back and the ones that `xschem raw del` -- and asserts they are ONE
    # SET, plus that every member pre-flights with `calc::rpn_bad_token`.
    # MEASURED against a conforming reference: SR5 reports
    #   {cross eval_rpn wave_dest} {cross eval_rpn} {cross eval_rpn} {cross eval_rpn}
    # and a second failure naming `wave_dest` as the unpreflighted member.
    #
    # THE PRODUCER IS RIGHT AND SR5 IS NARROW.  R402's mint-and-delete discipline
    # is about a TEMPORARY column -- one a verb evaluates into, reads and must
    # remove before returning.  The destination's Y column is PERSISTENT by
    # design: the trace keeps reading it for the life of the database, so there
    # is nothing to mint and nothing to delete, which is the very exemption SR5's
    # own comment already grants `plot_rpn` for reaching the engine through
    # `wviewer::add_trace`.  The destination is a THIRD door of the same kind, and
    # it is visible to SR5's scan where Plot's is not.
    #
    # SO THIS ROW CARRIES THE CORRECTED INVARIANT, HERE, WHERE THE PRODUCER LIVES:
    # the four-way equality holds for every member EXCEPT the destination
    # producer, which adds without minting, reading or deleting.  It reddens today
    # on the two `wave_dest` legs, it reddens again if a future producer starts
    # minting or deleting, and it tells whoever widens SR5 exactly what the
    # widened claim is -- rather than leaving them a gate red with a four-list
    # diff in it.
    set wd_minters {} ; set wd_adders {} ; set wd_readers {} ; set wd_deleters {}
    set wd_preflight {}
    foreach p [lsort [pcall info procs ::calc::*]] {
        set nm [namespace tail $p]
        set b [pcall info body $p]
        if {[string match ERR:* $b]} continue
        set b [pcall wd_code $b]
        if {[regexp {calc::tmpvec} $b]}        { lappend wd_minters   $nm }
        if {[regexp {xschem raw add} $b]}      { lappend wd_adders    $nm }
        if {[regexp {xschem raw value} $b]}    { lappend wd_readers   $nm }
        if {[regexp {xschem raw del} $b]}      { lappend wd_deleters  $nm }
        if {[regexp {calc::rpn_bad_token} $b]} { lappend wd_preflight $nm }
    }
    set wd_others [lsearch -all -inline -not -exact $wd_adders wave_dest]
    check "WD10 R402's derived four-way equality holds for every DIRECT engine caller EXCEPT this stage's destination producer, which ADDS a PERSISTENT column and therefore mints nothing, reads nothing back and deletes nothing -- the corrected invariant row SR5 of test_calc_scratch_reuse.tcl must widen to, stated here where the producer lives so nobody meets it first as a gate red" \
        [list [expr {[lsearch -exact $wd_adders wave_dest] >= 0 ? 1 : 0}] \
              [lsearch -exact $wd_minters wave_dest] \
              [lsearch -exact $wd_readers wave_dest] \
              [lsearch -exact $wd_deleters wave_dest] \
              [lsearch -exact $wd_preflight wave_dest] \
              [lsort $wd_minters] [lsort $wd_readers] [lsort $wd_deleters]] \
        [list 1 -1 -1 -1 -1 \
              [lsort $wd_others] [lsort $wd_others] [lsort $wd_others]]
    check "WD10 ...and the non-vacuity leg for that derivation: the four sets are computed over real decommented bodies and the ADDERS set holds more than one name, so an equality over four empty lists cannot pass it" \
        [list [wd_atleast [llength $wd_adders] 2] \
              [expr {[lsearch -exact $wd_adders eval_rpn] >= 0 ? 1 : 0}] \
              [expr {[lsearch -exact $wd_adders cross] >= 0 ? 1 : 0}] \
              [expr {[lsearch -exact $wd_adders wave_dest] >= 0 ? 1 : 0}]] \
        {atleast 1 1 1}
    # the answer-dict key sites in THIS FILE, derived over its own text, so the
    # header's enumeration cannot drift into a false sentence.
    check "WD10 the procs in this file that BUILD the answer dict are exactly the one the header enumerates, derived over this file's own text rather than counted -- so a row that started constructing the representation inline reddens here instead of falsifying a comment" \
        [wd_dictsites] {wd_asanswer}
    check "WD10 R402 the whole suite leaves no __calc_tmp* and no __wd_* in the inventory, which is the one claim that covers every exit path every band above drove" \
        [list [wd_leaked] [wd_probeleft]] {{} {}}
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
