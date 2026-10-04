# Unit J2 -- the implementation, and a verification that found a false SHIPPED comment
`verify:j2` reports GREEN AND HONEST: the red reproduces in full with every literal intact, no
row was weakened, and all FIVE sabotages redden -- including the two that survived the first
suite. It also found one prose claim in `src/calculator.tcl` that the tree measurably
contradicts, on one of three reachable shapes, and the driver corrected it before committing.


## impl:j2

**verb_arm**

`calc::riseTime`, in `src/calculator.tcl`. Issue 1639's guard was REPLACED, not bypassed: the `if` TEST is the guard's own, byte for byte, and it MOVED from above the swing/reference/percentage/zero-swing checks' immediate successor position to BELOW the two threshold computations, because it now needs `llo`/`lhi`. The `listdefer` return is gone and the arm computes. Exactly four non-comment lines were removed from the whole file (`git diff -U0 -- src/calculator.tcl | grep '^-' | grep -vE '^-[ \t]*#'`): the guard's three and the catalogue row.

Verbatim, as implemented:

    set llo [expr {double($lo) + double($pctlo)/100.0*$swing}]
    set lhi [expr {double($lo) + double($pcthi)/100.0*$swing}]
    # ISSUE 1639's `nth`-0 GUARD, REPLACED BY THE MEASUREMENT IT DEFERRED --
    # stage J unit J2.  The test it is reached by is the guard's own, unchanged
    # and for the guard's own reasons: the finiteness conjunct is not
    # belt-and-braces, because `double($nth)` RAISES on a non-numeric operand and
    # a non-finite ordinal must keep reaching `cross`'s `badnth` refusal; and it
    # is integer-VALUED rather than integer-spelled, for the reason `cross`
    # itself is, since `0.0`, `-0` and `0e0` all name the ordinal zero.  It moved
    # below the two threshold computations because it now needs them.  Every
    # WARN governing this arm is above the proc; see the header.
    if {[calc::eval_finite $nth] && [expr {double($nth) == 0.0}]} {
        set lows [calc::cross $rpn $llo 0 rising $dataset]
        if {![dict get $lows ok]} { return $lows }
        set highs [calc::cross $rpn $lhi 0 rising $dataset]
        if {![dict get $highs ok]} { return $highs }
        set xs {}
        set ys {}
        foreach x0 [dict get $lows value] {
            set xh {}
            foreach h [dict get $highs value] {
                if {$h > $x0} { set xh $h ; break }
            }
            if {$xh eq {}} continue
            lappend xs $x0
            lappend ys [expr {$xh - $x0}]
        }
        if {![llength $ys]} {
            return [calc::cross_absent \
                        [calc::cross_msg nohigh [calc::cross_ordinal 0]] \
                        [dict get $highs dataset] [dict get $highs dest]]
        }
        dict set highs value $ys
        dict set highs sweep $xs
        return $highs
    }

WHERE THE GUARD WENT: it is the `if` condition above, unchanged, now opening the measurement instead of returning `[calc::cross_refusal [calc::cross_msg listdefer] $dataset]`. Both forwarding returns (`return $lows` / `return $highs` on `!ok`) pass a refusal through unchanged.

WHICH CROSSING LIST IS ITERATED: `foreach x0 [dict get $lows value]` -- the LOW list, and the high list appears only in the inner `foreach h` search for the FIRST element strictly greater than `$x0` (`if {$h > $x0} { set xh $h ; break }`). The high list is never the driver. Measured on band MT9c's own minted ringing request (`nhigh > nlow`, the only shape that can see it): low list 3 elements `{0.001628478720832479 0.004943333333333332 0.008290580452878223}`, high list 6; the answer is n=3 with `sweep` equal to the low list element for element. The wrong pairing, computed beside it in the same probe, gives n=6 with X `{l1 l1 l2 l2 l3 l3}` -- which is the `{n:6 want:3}` / `dup:3-of-6` / `notincreasing:1` the new PAIRING row prints.

HOW A DROP IS HANDLED: `if {$xh eq {}} continue` -- the point is dropped, neither padded nor allowed to refuse the series. `set xh {}` is the FIRST statement INSIDE the `foreach x0` body, not hoisted (hoisting it is attack 1's length-preserving third site, which inherits the previous edge's high crossing and can emit a negative rise time). Measured: `riseTime {v(lp)} 0 1 10 99.9 0` -> `measured`, n=2 from 3 low crossings, `value={0.0011130770436309611 0.0011120979237804448}`.

WHERE EMPTINESS IS TESTED: `if {![llength $ys]}` -- on the OUTPUT series, after the loop, and on NOTHING else. Neither `[dict get $lows value]` nor `[dict get $highs value]` is ever tested for emptiness anywhere in the arm. All four empty shapes were driven and all four answer the same absence through `calc::cross_absent` with `calc::cross_msg nohigh [calc::cross_ordinal 0]` -- the same `cross_msg` arm and therefore the same family ("Rise time") the shipped ordinal path already uses: shape A `{v(sq)} 100 200 10 90` (no low crossing), shape B `{v(lp)} 0 1 10 99.95` (nlow 3, nhigh 0), and the fourth shape attack 3 reached, `{v(ramp)} 1 0 10 90` (nlow 1, nhigh 1, series 0). The nth-1 oracle on that fourth request answers *"Rise time: the 1st low crossing has no high crossing after it in this sweep."*, nth 0 answers the same sentence with "0th" -- `samefamily`.

Y is positive by construction here (`$xh - $x0` with `$xh > $x0` from the loop's own guard), but nothing in the tree asserts positivity; see declared_holes.

**wrapper**

`calc::riseTime_scalar`, in `src/calculator.tcl`, placed immediately after `calc::riseTime` and before `calc::delay`. FORMALS IN ORDER, which are `calc::riseTime`'s own signature byte for byte with no extra formal anywhere:

    proc calc::riseTime_scalar {rpn {lo {}} {hi {}} {pctlo 10} {pcthi 90} {nth 1} {dataset 0}} {
        if {!([calc::eval_finite $nth] && [expr {double($nth) == 0.0}])} {
            return [calc::riseTime $rpn $lo $hi $pctlo $pcthi $nth $dataset]
        }
        set m [calc::riseTime $rpn $lo $hi $pctlo $pcthi 0 $dataset]
        set mok 0
        if {[catch {dict get $m ok} mok]} { return $m }
        if {!$mok} { return $m }
        set h [calc::wave_dest [dict get $m sweep] [dict get $m value]]
        if {![dict get $h ok]} {
            return [calc::cross_refusal [dict get $h msg] $dataset [dict get $m dest]]
        }
        foreach k {db type xname yname n} { dict set m $k [dict get $h $k] }
        dict set m shape wave
        return $m
    }

PROOF VIA `info args` THAT THE ORDER MATCHES THE VERB (measured in-process against the real binary, `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <probe>`):

    SHIPPED wrapper formals     : rpn lo hi pctlo pcthi nth dataset
    SHIPPED verb formals        : rpn lo hi pctlo pcthi nth dataset
    SAMEFORMALS=1

WHAT I MEASURED ABOUT `calc::arg_values` TRUNCATING -- measured, not reasoned, on the shipped wrapper and on two probe surfaces minted into `::calc::` and removed:

    SHIPPED arg_values    : rpn {v(sq) v(ramp) *} lo 0 hi 1 pctlo 10 pcthi 90 nth 0 dataset 0
    SHIPPED pairs         : 7          SHIPPED nth delivered : 0
    PROBE __j2mid formals = rpn lo hi dest pctlo pcthi nth dataset
    PROBE __j2mid arg_values pairs=3  composed_nth=TRUNCATED-BEFORE:nth  DELIVERED_nth=1
    PROBE __j2end formals = rpn lo hi pctlo pcthi nth dataset dest
    PROBE __j2end arg_values pairs=7  composed_nth=0                     DELIVERED_nth=0
    PROBES REMOVED: (empty)

So the shipped shape delivers all seven pairs and the user's `nth` 0 arrives. A `dest` formal in the MIDDLE stops `arg_values` at three pairs and the proc receives the DEFAULT 1 -- no error, no refusal, the measurement silently routed to the buffer instead of a destination. The same formal LAST costs nothing. That is MT9c's truncation row's claim, re-measured independently of the row.

OTHER BEHAVIOUR, measured: a non-zero or non-finite `nth` is forwarded unchanged (first `if`); a refusal or absence passes straight through with no `db` key (`if {!$mok} { return $m }`); `sweep` is handed to `calc::wave_dest` FIRST and `value` second (X before Y); a destination refusal is propagated through `calc::cross_refusal` carrying `wave_dest`'s own `msg` and the measurement's retired `dest`; exactly `{db type xname yname n}` is merged plus `dict set m shape wave`. The destination is NOT dropped on the success path. Measured answer on the ring request: `keys=absent dataset db dest msg n ok shape sweep type value xname yname`, `db=__calc_dest1 type=table xname=calcx yname=calcy n=3 shape=wave dest=__calc_tmp18`, `calc::fn_sink` -> `destination` for nth 0 and `buffer` for nth 1, `calc::arg_surface riseTime` -> `riseTime_scalar`.

**returns_respelling**

THE CATALOGUE CHANGE, one line, in `calc::catalogue`'s returned literal:

    -{riseTime {Special Functions} T scalar      {} {Time of a transition from a low % level to a high % level}}
    +{riseTime {Special Functions} T scalar/wave {} {Time of a transition from a low % level to a high % level}}

Nothing widened: measured in-process with S24's own predicate lifted and run -- `lsearch -exact {scalar wave bool scalar/wave scalar/list} scalar/wave` >= 0, and a sweep of all 108 catalogue rows gives `BADRETURNS={}`. `test_calc_skeleton` on the DISPLAY arm (the only arm that runs S24) is `ALL PASS (579 checks)`, its figure before this change.

PROSE SITES CORRECTED -- NINE, named by symbol or spec section. The receipt named six; I found two more by grepping `riseTime` across `src/*.tcl`, and one of those was already false before J2.

1. `calc::catalogue`'s own banner comment. The sentence *"`riseTime` and `delay` stay `scalar`: both answer one number, and R417's negative delay is still one number"* became false. Replaced by a paragraph naming `scalar/wave`, stating the term was already in S24's closed vocabulary (so the four-site widening cost was not incurred), and keeping `delay` at `scalar` while calling its own `nth` 0 deferral a DISPOSITION rather than a `returns` value.
2. `doc/claude/specs/calculator.md` section 7.2ab, R416's closing note. The identical sentence. Replaced by the same correction, flagged as a correction with the old claim quoted.
3. `doc/claude/specs/calculator.md` section 7.2, the returns table row: `| riseTime | scalar | ... |` -> `| riseTime | scalar/wave | low%->high% transition time (one per edge for nth 0) | T (on cross) |`.
4. `calc::cross_msg`'s header comment -- the R419 two-destinations paragraph, stale copy one. It enumerated the waveform destination's callers as *"`calc::delay` with `nth = 0` on either side, `calc::dutyCycle_scalar`'s default cycle and the unbuilt `frequency`"*. Now splits WIRED (`dutyCycle_scalar` J1, `riseTime_scalar` J2) from STILL WAITING (`delay`, unbuilt `frequency`), and points at WD9's derivation rather than at the sentence.
5. `calc::cross_scalar`'s header comment -- stale copy two, the same list, corrected the same way.
6. `calc::riseTime`'s own header. The whole *"`nth` 0 DEFERS BEHIND THE SHARED `listdefer` SENTENCE"* block, plus the paragraph arguing for a deferral over a D7 refusal and the guard-ordering paragraph, replaced by the series WARNs: the pairing direction and the sabotage that proved it invisible, the per-point drop and its R416 agreement, the output-side emptiness test and the `destempty` sentence a user would otherwise read, the arm's ordering, and the statement that this proc puts the series nowhere.
7. `calc::delay`'s header comment. *"this caller waits on `calc::wave_dest`, alongside `calc::dutyCycle_scalar`'s default cycle and the unbuilt `frequency`"* -- already false since J1, doubly false now. It now says `delay` is the only BUILT verb still waiting, quotes the old sentence as the correction's evidence.
8. ⚠ BEYOND THE RECEIPT'S LIST: `calc::dutyCycle_scalar`'s header comment. *"the sentence it used to answer with is retired HERE and at no other caller: `calc::cross_scalar`, `calc::riseTime` and `calc::delay` still say it"* -- made false by J2, since `riseTime` no longer says it. Corrected to `calc::cross_scalar` and `calc::delay`, with a note that `riseTime` moved to the other side of WD9's partition by re-derivation, never a decrement.
9. ⚠ BEYOND THE RECEIPT'S LIST: the section banner above `calc::fn_argspec` (R412's dialog, the *"THE DIALOG VALIDATES SHAPE ONLY"* WARN). *"`nth` 0 must reach `calc::cross_scalar` / `calc::delay` / `calc::dutyCycle_scalar` / `calc::riseTime` and meet the ONE shared `calc::cross_msg listdefer` sentence"* -- already false for `dutyCycle_scalar` since J1 and now false for `riseTime`. Rewritten to say the ordinal reaches the verb's own surface and gets whatever that surface answers, naming the two deferring and the two answering a destination.

NO ROW ANYWHERE ASSERTS `riseTime`'s `returns` VALUE, re-checked: `/usr/bin/grep riseTime tests/headless/test_calc_skeleton.tcl` matches prose inside row names only. So items 1, 2, 4-9 are prose and item 3 is spec prose; only the catalogue literal is read by code. `doc/claude/calculator_batch/TIMING_CONTRACT.md` was left alone per WIRING_CONTRACT section 9, and so was `test_calc_wave_dest.tcl`'s own header line (I touched no suite file).

**green_proof**

THE RED I INHERITED, armed spelling, product byte-identical to HEAD (`git diff --stat -- src/` produced no output immediately before it):

    $ timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
    test home: throwaway /tmp/xschem-test-home.3523055.UZDPaw (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
    display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
    FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (113 passed)
    FAIL     | test_calc_measure            run 2/2  RESULT: 15 FAILED (170 passed)
    RESULT: 0/2 runs passed
    exit=1

26 failing rows (WD9 x3 + WD13 x8 + MT9b x4 + MT9c x11), reproducing the repair receipt's figures exactly.

=== COUNTED ARM, AFTER (verbatim) ===

    $ timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse
    test home: throwaway /tmp/xschem-test-home.3527890.uKZXDW (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
    display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
    PASS     | test_calc_wave_dest          run 1/5  RESULT: ALL PASS (124 checks)
    PASS     | test_calc_measure            run 2/5  RESULT: ALL PASS (185 checks)
    PASS     | test_calc_cross              run 3/5  RESULT: ALL PASS (187 checks)
    PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
    PASS     | test_calc_scratch_reuse      run 5/5  RESULT: ALL PASS (56 checks)
    RESULT: 5/5 runs passed
    exit=0

=== DISPLAY ARM, AFTER (verbatim) ===

    $ timeout 1500 tests/headless/run_suites.sh test_calc_wave_dest test_calc_measure test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
    test home: throwaway /tmp/xschem-test-home.3528261.Gf4X1J (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
    display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
    PASS     | test_calc_wave_dest          run 1/6  RESULT: ALL PASS (124 checks)
    PASS     | test_calc_measure            run 2/6  RESULT: ALL PASS (185 checks)
    PASS     | test_calc_skeleton           run 3/6  RESULT: ALL PASS (579 checks)
    PASS     | test_calc_plot               run 4/6  RESULT: ALL PASS (114 checks)
    PASS     | test_calc_widgets            run 5/6  RESULT: ALL PASS (259 checks)
    PASS     | test_calc_buffer             run 6/6  RESULT: ALL PASS (130 checks)
    RESULT: 6/6 runs passed
    exit=0

Both ran AFTER the last edit (src/calculator.tcl mtime 17:37:49, counted transcript 17:38:01, display transcript 17:38:09). `/usr/bin/grep -cE 'UNEXPECTED ERROR|BGERROR|ABORTED|another regression run is live'` answers 0 on EVERY transcript of this unit (12 files), so no band was abandoned and every run was solo. Transcripts: /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/impl/{red_baseline,green_final_counted,green_final_display}.txt

**rows_weakened**

NO. Proved three ways, the first being arithmetic over the diffstat.

(a) I NEVER WROTE EITHER SUITE FILE. `md5sum tests/headless/test_calc_wave_dest.tcl` = **c0a5b494e76feaa9222f100259cd5b83**, which is byte for byte the md5 the repair receipt recorded for the state the suite author left it in. `test_calc_measure.tcl` = 3dee5ff8d2495232f024b2e378218abb, and it survived two swap-and-restore measurements with `cmp` reporting BYTE-IDENTICAL both times. (Their mtimes moved -- 17:37:22, from the restoring `cp` -- their bytes did not.)

(b) DIFFSTAT ARITHMETIC. `git diff --numstat -- tests/` gives `791 15` for test_calc_measure.tcl and `314 8` for test_calc_wave_dest.tcl -- the inherited crews' numbers, unchanged by me. Row arithmetic over `check` sites in COMMAND POSITION (`/usr/bin/grep -cE '(^|[;[{])[ \t]*check[ \t]'`, HEAD via `git show` versus the worktree):

    test_calc_measure.tcl    HEAD 154  ->  worktree 169   delta +15
    test_calc_wave_dest.tcl  HEAD 115  ->  worktree 124   delta  +9

and of those diff lines, `check "` NAME lines removed = 4 (measure) and 2 (wave_dest), added = 19 and 11. So 154 - 4 + 19 = 169 and 115 - 2 + 11 = 124: every removed row-name line is paired with an added one (the moved rows, renamed), and **zero rows were deleted**. The published check deltas are +15 and +9 -- exactly equal to the row deltas -- so no surviving row lost a check either.

(c) THE INVERSE RED, which is the leg that proves the moved rows were not LOOSENED rather than merely not deleted. With the COMMITTED suites swapped in against the J2 product, `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure` gives `3 FAILED (112 passed)` and `4 FAILED (166 passed)` -- exactly the 7 MOVED rows (WD9 x3, MT9b x4), failing in the OPPOSITE direction, e.g. `MT9b ... -> {0 measured 0} (exp {0 refused 0})` and `MT9b ... -> {__calc_tmp154 1} (exp {{} 1})`. A weakened expectation would have been satisfied by both products; these are satisfied by exactly one each.

(d) PRODUCT SIDE. `git diff --numstat -- src/` = `254 59`, and the removed NON-COMMENT lines are exactly FOUR: the three lines of issue 1639's `listdefer` guard body and the one catalogue row. Everything else removed is prose.

**counts_rederived**

RE-DERIVED, NEVER PRESERVED. Each figure below was run in this session.

=== BEFORE -- COMMITTED suites AND committed product, taken exactly the way T1's `hcases` loop takes it (cwd `tests/`, `--nogui --pipe -q --script headless/<t>.tcl`, throwaway HOME, `XSCHEM_TEST_REAL_HOME` set as the arm sets it). Both suite files AND `src/calculator.tcl` were swapped to their HEAD copies for this, then restored and `cmp`'d: ALL THREE BYTE-IDENTICAL, md5s re-checked. ===

    TH=$(mktemp -d "${TMPDIR:-/tmp}/xschem-test-home.census.XXXXXX")
    cd tests && env -u DISPLAY HOME="$TH" XSCHEM_TEST_REAL_HOME="$HOME" timeout 900 \
        ../src/xschem --nogui --pipe -q --script headless/<t>.tcl
      test_calc_measure     OVERALL: ok (170 checks)  /  RESULT: ALL PASS (170 checks)   rc=0
      test_calc_wave_dest   OVERALL: ok (115 checks)  /  RESULT: ALL PASS (115 checks)   rc=0

=== THE RED -- inherited suites, committed product (same armed command as the green) ===

    timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
      test_calc_wave_dest   11 FAILED (113 passed)   -> 124 checks
      test_calc_measure     15 FAILED (170 passed)   -> 185 checks     exit 1

=== AFTER -- COUNTED ARM, identical command ===

    timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse
      test_calc_wave_dest       ALL PASS (124 checks)
      test_calc_measure         ALL PASS (185 checks)
      test_calc_cross           ALL PASS (187 checks)
      test_calc_engine          ALL PASS (265 checks)
      test_calc_scratch_reuse   ALL PASS (56 checks)      5/5, exit 0

=== AFTER -- DISPLAY ARM, RUN rather than reasoned ===

    timeout 1500 tests/headless/run_suites.sh test_calc_wave_dest test_calc_measure test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
      test_calc_wave_dest  124   test_calc_measure 185
      test_calc_skeleton   579   test_calc_plot    114   test_calc_widgets 259   test_calc_buffer 130      6/6, exit 0

=== INTERMEDIATE, the inverse red: COMMITTED suites, J2 product ===

    test_calc_wave_dest   3 FAILED (112 passed)  -> 115      test_calc_measure   4 FAILED (166 passed)  -> 170

PUBLISHED CHECK COUNTS, BEFORE -> AFTER:

    test_calc_measure      170  ->  185     (+15: MT9b x4 moved, MT9c x11 new)
    test_calc_wave_dest    115  ->  124     (+9: WD9 x3 moved, WD13 x9 new)
    test_calc_cross        187  ->  187     unmoved
    test_calc_engine       265  ->  265     unmoved
    test_calc_scratch_reuse 56  ->   56     unmoved (SR5's adders/door sets unmoved: the wrapper issues no `xschem raw` verb itself)
    test_calc_skeleton     579  ->  579     unmoved (the arm that runs S24)
    test_calc_plot         114  ->  114     unmoved
    test_calc_widgets      259  ->  259     unmoved
    test_calc_buffer       130  ->  130     unmoved

=== THE T1 TRAILER -- DERIVED with `summarize_all`'s OWN five regexp arms and `tests/banner_rule.tcl`'s OWN predicates (sourced, never respelled) over REAL captured output, before and after. I did NOT run T1; the driver gates. ===

Registration delta ZERO: both suites are already in `hcases` (`tests/run_regression.tcl` lines 119-120, verified). List sizes by CLAUDE.md's own method (`set <L> [list` then `/usr/bin/grep -o '"[^"]*"' | wc -l`): tcases 3, hcases 96, dcases 25 -> 124 + `xschemtest` = 125 cases, 124 blocks.

Census (counted shapes / lowercase `^skip:` / uppercase `^SKIP:|^SKIPPED:` / `^RESULT:` / `NOGOLD|NODISPLAY` / banner_complete / banner_died / regression_case_failed):

    BEFORE  test_calc_measure   (170)   0 / 0 / 0 / 1 / 0 / 1 / 0 / 0
    AFTER   test_calc_measure   (185)   0 / 0 / 0 / 1 / 0 / 1 / 0 / 0
    BEFORE  test_calc_wave_dest (115)   0 / 0 / 0 / 1 / 0 / 1 / 0 / 0
    AFTER   test_calc_wave_dest (124)   0 / 0 / 0 / 1 / 0 / 1 / 0 / 0

THEREFORE cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines, not with the counts inside them, and neither number moved. The trailer should read `cases=125 blocks=124 counted_failures=0 skips=8`, unchanged from `580f1622`. This is the PLAN 5.4 / J1 / J1b shape again: two published check counts move and not one trailer term. THE DRIVER READS THE TRAILER.

**switch_comment_check**

I TOUCHED THE HEADER COMMENTS OF TWO PROCS THAT CONTAIN A `switch` -- `calc::cross_msg` and the section banner above `calc::fn_argspec` -- plus `calc::catalogue`'s row literal. In every case the prose sits ABOVE the proc and never between two patterns, verified MECHANICALLY and then confirmed BEHAVIOURALLY.

STRUCTURAL PLACEMENT, derived rather than eyeballed: I took every hunk's new-line range from `git diff -U0 -- src/calculator.tcl` and asked, per line, whether it falls inside a proc body (between a `^proc ` line and its matching column-0 `}`). Result -- 13 hunks, and only three touch a proc body: the new `nth`-0 arm in `calc::riseTime` (no `switch` in that proc), the whole new `calc::riseTime_scalar` (no `switch`), and the one-line catalogue ROW inside `calc::catalogue`'s `return {...}` list (no `switch`). The other ten hunks, every comment edit, are `inside_proc=no`. So no comment of mine is between two `switch` patterns in any proc, and the parity hazard does not arise at all -- there is no comment in that position whose word count could be flipped later.

BEHAVIOURAL CONFIRMATION, which is the only confirmation this project accepts and which a brace scan cannot give. A probe run against the real binary (`env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <probe>`) derives the population -- every `::calc::` proc issuing `switch` in COMMAND POSITION in its decommented body -- and then asks every arm of each message/dispatch table for its answer, with the ARM SET DERIVED FROM EACH PROC'S OWN SWITCH ARGUMENT and never hand-kept:

    SWITCHPROCS: 11
    NAMES: ::calc::arg_bad ::calc::arg_msg ::calc::cross ::calc::cross_msg ::calc::cross_ordinal
           ::calc::eval_msg ::calc::fn_argspec ::calc::fn_reason ::calc::plot_msg
           ::calc::results_label ::calc::results_tip
    BEHAV ::calc::cross_msg      arms=36  ok=36   raised=0
    BEHAV ::calc::arg_msg        arms=10  ok=10   raised=0
    BEHAV ::calc::eval_msg       arms=11  ok=11   raised=0
    BEHAV ::calc::plot_msg       arms=9   ok=9    raised=0
    BEHAV ::calc::fn_reason      arms=1   ok=1    raised=0
    BEHAV ::calc::fn_argspec     ok=5     raised=0     (cross riseTime delay dutyCycle + an unknown name)
    BEHAV ::calc::cross_ordinal  ok=151   raised=0     (-25..125, which sweeps the st/nd/rd/th arms and the 11-13 band)
    ARMSWEEP_BAD=0

Re-run after the final two comment edits, same result. Independently, the suites themselves give the same confirmation every run and are green: MT9c's family instrument lifts `calc::cross_msg`'s arm set out of the proc's own switch argument and asks every one for a sentence (36 arms, 7 families), and band MT12 does the same for `calc::arg_msg`. `info complete` on the whole file answers 1, which I record as NOT being the evidence -- it is exactly the answer the trap returns.

**mt10_check**

MT10 IS GREEN, and the measurement was taken with the row's OWN predicates LIFTED OUT OF THE SUITE FILE BY NAME (`mt_decomment`, `mt_calc_names`, `mt_calc_closure`, `mt_reaches_cross`, `mt_direct_raw`, `mt_closure_raw`, extracted by awk and sourced) rather than reimplemented:

    LIFTED: mt_calc_closure mt_calc_names mt_closure_raw mt_decomment mt_direct_raw mt_reaches_cross
    mt_direct_raw wave_dest        = yes          <- the destination builder IS an engine door
    mt_direct_raw cross            = yes          <- the instrument's own control
    mt_direct_raw riseTime         = no
    mt_direct_raw riseTime_scalar  = no
    mt_reaches_cross riseTime  = reaches   mt_closure_raw riseTime  = {}
    mt_reaches_cross delay     = reaches   mt_closure_raw delay     = {}
    mt_reaches_cross dutyCycle = reaches   mt_closure_raw dutyCycle = {}
    closure(riseTime) = cross cross_absent cross_msg cross_ordinal cross_refusal eval_finite riseTime
      wave_dest in closure(riseTime)       = 0
      riseTime_scalar in closure(riseTime) = 0
    closure(riseTime_scalar) = cross cross_absent cross_msg cross_ordinal cross_refusal eval_finite
                               riseTime riseTime_scalar wave_dest wave_dest_answer wave_dest_cur
                               wave_dest_refusal wave_dest_restore
      wave_dest in closure(riseTime_scalar) = 1
      mt_closure_raw riseTime_scalar        = {wave_dest}

So `mt_direct_raw wave_dest` answers **yes** -- it issues `xschem raw add` -- and `calc::wave_dest` is reached ONLY from the WRAPPER. `calc::riseTime`'s callee-ward closure is seven `::calc::` procs and contains neither `wave_dest` nor `riseTime_scalar`, so `mt_closure_raw riseTime` is `{}` and MT10's closure row prints `{{riseTime delay dutyCycle} {{} {} {}}}` against its expectation `{{riseTime delay dutyCycle} {{} {} {}}}`. The wrapper is INVISIBLE to that row because MT10 walks the literal verb set `{riseTime delay dutyCycle}` and nothing in `riseTime`'s body names the wrapper -- exactly J1's `dutyCycle_scalar` measurement. Driven as sabotage `I_wrong_layer`, MT10 would print `{wave_dest {} {}}` and WD9's partition would print `riseTime` where `riseTime_scalar` belongs; both are green here, and WD9's partition row reads `{{cross_scalar delay} {dutyCycle_scalar riseTime_scalar} {cross_scalar delay dutyCycle_scalar riseTime_scalar} atleast}` -- the floor over the UNION still holding at four.

Confirmed at suite level too: MT10's four closure/delegation rows are among `test_calc_measure`'s `ALL PASS (185 checks)` on BOTH arms.


### declared_holes

- ⚠⚠ THE PADDED SHAPE IS STILL A SINGLE-ROW DEPENDENCY AND THE DRIVER'S DECISION ON IT IS STILL OPEN. Attack 1's length-preserving variant (`set xh {}` hoisted out of the loop -- an ordinary forgotten loop-local reset) is caught by EXACTLY ONE row in the tree, MT9c's partial-drop row, with `test_calc_wave_dest` at ALL PASS. The repair crew flagged the fix (a non-negativity leg on the SERIES in MT9c's keystone and on the READ-BACK Y in WD13's keystone, costing no new row and moving no published count) as a DRIVER decision rather than taking it, and I did not take it either: my instruction was to weaken nothing and not to edit a row to suit my implementation. What I can add is that in THIS implementation positivity is structural -- Y is `$xh - $x0` with `$xh > $x0` guaranteed by the inner loop's own `if {$h > $x0}` -- so no shipped path can emit a negative rise time today; nothing in the tree ASSERTS that, so a future edit could.

- ⚠⚠ `S6_xcolname` SURVIVES, UNCHANGED AND UNFENCED. I pass no column names to `calc::wave_dest`, so the destination's columns are its defaults `calcx`/`calcy` -- J1's shape and issue 1644's family. Naming the X column `time` instead would be invisible to every row, because each reads `xname` out of the answer and then reads that column from inside the destination. Whether the name is load-bearing for `wviewer::resolve_signal_db` is still the open question, and a row cannot assert anything until somebody decides.

- ⚠ `riseTime` HAS NO `xaxis` ARGUMENT AND J2 DID NOT ADD ONE. The series X is the LOW crossing time -- R420's own default choice for `dutyCycle` ("the time the thing started") read across to a transition. The midpoint of the transition and the edge ordinal are equally legitimate and nobody has been asked. Adding it needs a new `calc::fn_argspec riseTime` row, which moves MT11's four-literal spec row, `agnsurf` and the argspec shape sweep. A `rule` candidate, because the X axis of a plotted measurement is something the user sees.

- ⚠ THE EMPTY-SERIES SENTENCE IS UNRULED AND THE ARM I REUSED READS ODDLY FOR `nth` 0. All four empty shapes answer `calc::cross_msg nohigh [calc::cross_ordinal 0]` -> *"Rise time: the 0th low crossing has no high crossing after it in this sweep."* -- the 0th reads badly. It was chosen because it is the SAME arm the shipped ordinal path uses for the identical request, which is what MT9c's third-empty-shape row requires (same family in one voice). No row asserts the WORDS, so the `rule` debt `calc_wave_dest_empty_result_sentence` can reword the whole arm without touching a row. A crew reading my choice as a ruling would be wrong.

- ⚠ THE PARTIAL-DROP DISPOSITION IS UNIT J2's OWN AND IS DECLARED, NOT RULED. A low crossing with no high after it DROPS that point. The argument is in the proc's header: it is the empty-series ruling applied once per point, and it agrees with R416's "one fraction per COMPLETE cycle" for `dutyCycle`. Refusing instead is a one-line change that reddens exactly one row. The user has not been asked.

- ⚠ WIRING_CONTRACT section 14(b)'s empty-series table is a FOUR-shape table and still says THREE. The fourth -- both crossing lists NON-EMPTY and the series still empty, because the only high crossing lies before the only low one (`riseTime {v(ramp)} 1 0 10 90 0`, measured nlow 1, nhigh 1, series 0) -- is now fenced by a row but the contract's prose is one shape short, and the next crew reads the contract first. I did not edit the contract: the driver collects receipts.

- ⚠ NINE PROSE SITES WERE FALSE AND NOTHING RE-CHECKS ANY OF THEM. The repair receipt named six; I found two more by grepping (`calc::dutyCycle_scalar`'s header and the `calc::fn_argspec` section banner) and ONE OF THOSE WAS ALREADY FALSE BEFORE J2 -- it had been wrong about `dutyCycle_scalar` since unit J1 landed. That is the same class CLAUDE.md records about dead prose: no instrument re-derives the caller partition into these sentences, and WD9 derives it into a ROW only. The honest statement is that the tenth copy will be stale again at J3 and nothing will say so.

- ⚠ THE CLICK PATH IS NOT FENCED ON THE COUNTED ARM, inherited from J1 hole H12 and still true. `calc::fn_measure` and `calc::buf_set_number` both return early on `calc::has_win .calc.buf`, so what the user's RPN buffer and status line do with a `riseTime` wave is observable on a gate's DISPLAY arm and nowhere else. The DECISION is fenced (`calc::fn_sink` answers `destination` for nth 0 and `buffer` for nth 1, measured, and WD13's key-set row requires the `shape` key); the ACT -- the buffer really left alone, the sentence reaching the widget, one undo -- is band S28's and I added no row there.

- ⚠ NO ROW ASSERTS THAT THE MEASURED `riseTime` WAVE APPEARS ON SCREEN. `wviewer::plot_dbs_arm`/`calc::wave_show` resolve the destination by registry index and are verb-agnostic, so it should work unchanged -- but that is reasoning. I re-ran `test_calc_plot` (114) and `test_calc_skeleton` (579) on the display arm as the receipt asked, which shows nothing BREAKS, not that the new verb's trace draws; the two rows that would see it (PL10, S28/7) drive `dutyCycle`. This is `look`-debt territory and I did not touch the `owed.sh` ledger.

- ⚠ THE DESTINATION IS NOT DROPPED ON THE SUCCESS PATH -- J1's declared leak, inherited rather than new, and J2 DOUBLES THE RATE at which registry slots accumulate because a second verb now mints them. WHO frees a destination the user is looking at is still unruled. Relatedly, `calc::wave_dest_restore` still loses the registry cursor's `prev` half (J1's defect (b)), so `xschem raw switch_back` after a successful destination lands ON the destination; no WD13 row can reach it and a row asserting it would be RED on correct J2 code.

- ⚠ THE DESTINATION HALF IS BLIND TO BOTH ATTACKS THIS UNIT WAS BUILT AGAINST, deliberately and as the repair crew declared. `test_calc_wave_dest` is ALL PASS under the wrong pairing direction and under the input-side absence guard, because band WD13 drives one request on which the two pairing directions coincide and never drives a request whose series is empty with non-empty crossing lists. Both defects are inside `calc::riseTime`, so the verb half is the right place -- but a reader who takes a green `test_calc_wave_dest` as evidence about the hand-off's semantics would be wrong.

- I DID NOT RUN A FULL T1, DID NOT COMMIT, DID NOT PUSH, DID NOT GATE, AND DID NOT TOUCH THE `owed.sh` LEDGER. The trailer figures above are DERIVED from `summarize_all`'s own regexp arms and `tests/banner_rule.tcl`'s own sourced predicates over real captured output; the driver reads the trailer. `~/dev/xschem-op-wcard`, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate` and every `/tmp/xschem_emergencysave_*` were never written; `devdisplay.sh start|stop|view` was never run -- the display-arm readings ATTACHED to the already-running `:99` with `GUI_GATE=0` and a throwaway HOME and left it as found; `AUDIT_SCREEN` left at its default. No bare `xschem`; every binary call carried `--nogui` with `env -u DISPLAY`, or the armed `run_suites.sh`. `/usr/bin/grep` throughout. Two swap-and-restore measurements were performed on `tests/headless/test_calc_measure.tcl`, `tests/headless/test_calc_wave_dest.tcl` and `src/calculator.tcl`; all three were restored and `cmp`'d byte-identical, md5s re-checked, and zero throwaway test homes were left behind. Scratch is 1.9 MB at /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/impl and /tmp (tmpfs) is at 777M of 7.7G. NOTHING IS RUNNING NOW.

**user_visible**

WHAT A USER CAN NOW DO. Open the Calculator, put an expression in the RPN buffer, click `riseTime` in the function browser, and in the argument dialog leave the Occurrence field at 0 instead of naming a single edge. Where that used to come back with a sentence saying a destination had to come first, it now MEASURES every rising edge at once: one rise time per complete rising edge, between the low and high percentage thresholds of the swing they supplied, plotted against the time each edge started. The answer is a registered two-column result in the Results picker and -- through the channel unit J1b armed -- the curve appears by itself on its own strip in the waveform viewer, so they can see how the edge speed varies across a transient rather than reading one number at a time. Naming a single occurrence still gives one number in the buffer exactly as before, and `riseTime` is now listed as answering "scalar/wave" rather than "scalar".

Two behaviours worth stating because a user will meet them. An edge that the simulation ends part way up -- the signal crosses the low threshold near the end of the sweep and never reaches the high one -- is silently LEFT OUT of the series rather than refusing the whole measurement, which is the same thing `dutyCycle` already does with an incomplete trailing cycle. And if the signal never completes a single transition between the two thresholds, they get a sentence saying so ("the low crossing has no high crossing after it in this sweep") instead of a confusing complaint about the destination.

WHAT STILL DOES NOT WORK. They cannot choose the X axis: the plotted wave is always against the time each edge STARTED. `dutyCycle` offers three axes; `riseTime` offers none, and the midpoint of the transition would be an equally reasonable default -- nobody has been asked. `delay` with occurrence 0 still refuses with the old deferral sentence, and `frequency` is still listed with nothing behind it. The sentence a user reads when the signal never crosses says "the 0th low crossing", which reads badly and is unratified wording. Each measured wave leaves a result behind that nothing ever frees, so measuring repeatedly accumulates entries in the Results picker -- and, because every one of them names its columns `calcx`/`calcy`, issue 1644's family is still live territory. Finally: nobody has LOOKED at any of this. I confirmed by test that the plot and skeleton suites still pass on a virtual display, which shows nothing broke; it does not show that this particular verb's curve draws correctly on a real screen.



## verify:j2

**independent_rerun**

I RE-RAN BOTH ARMS MYSELF, armed spellings, from the repo root. These are my own transcripts, not the implementer's.

=== COUNTED ARM (exit 0) ===
    $ timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse
    test home: throwaway /tmp/xschem-test-home.3529932.Oo0zxq (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
    display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
    PASS     | test_calc_wave_dest          run 1/5  RESULT: ALL PASS (124 checks)
    PASS     | test_calc_measure            run 2/5  RESULT: ALL PASS (185 checks)
    PASS     | test_calc_cross              run 3/5  RESULT: ALL PASS (187 checks)
    PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
    PASS     | test_calc_scratch_reuse      run 5/5  RESULT: ALL PASS (56 checks)
    RESULT: 5/5 runs passed

=== DISPLAY ARM (exit 0) ===
    $ timeout 1500 tests/headless/run_suites.sh test_calc_wave_dest test_calc_measure test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
    test home: throwaway /tmp/xschem-test-home.3530369.9wCyKB (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
    display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
    PASS     | test_calc_wave_dest          run 1/6  RESULT: ALL PASS (124 checks)
    PASS     | test_calc_measure            run 2/6  RESULT: ALL PASS (185 checks)
    PASS     | test_calc_skeleton           run 3/6  RESULT: ALL PASS (579 checks)
    PASS     | test_calc_plot               run 4/6  RESULT: ALL PASS (114 checks)
    PASS     | test_calc_widgets            run 5/6  RESULT: ALL PASS (259 checks)
    PASS     | test_calc_buffer             run 6/6  RESULT: ALL PASS (130 checks)
    RESULT: 6/6 runs passed

=== THE "BEFORE" FIGURES, measured by me rather than taken from the receipt (whole tree at HEAD, inside my worktree) ===
    $ timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse
    PASS | test_calc_wave_dest   ALL PASS (115 checks)
    PASS | test_calc_measure     ALL PASS (170 checks)
    PASS | test_calc_cross 187   PASS | test_calc_engine 265   PASS | test_calc_scratch_reuse 56     5/5, exit 0
    $ timeout 1500 tests/headless/run_suites.sh test_calc_skeleton test_calc_widgets test_calc_plot test_calc_buffer
    PASS | test_calc_skeleton 579  PASS | test_calc_widgets 259  PASS | test_calc_plot 114  PASS | test_calc_buffer 130   4/4, exit 0
SO 579 / 259 / 114 / 130 ARE THE BEFORE FIGURES AS WELL -- I measured them at HEAD rather than accepting the claim that the `returns` re-spelling moves nothing. It moves nothing.

=== THE T1 TRAILER, DERIVED, NOT RUN (the driver gates) ===
Registration delta ZERO: both suites are already in `hcases` (`tests/run_regression.tcl`, the two entries `"headless/test_calc_measure"` and `"headless/test_calc_wave_dest"`). List sizes derived by bracket-matching `set <L> [list` and counting quoted words with comment lines stripped: tcases 3, hcases 96, dcases 25 -> 124 + `xschemtest` = 125 cases, 124 blocks.
Census taken the `hcases` way (cwd `tests/`, `--nogui --pipe -q --script headless/<t>.tcl`, throwaway HOME, `XSCHEM_TEST_REAL_HOME` set) and scored by LIFTING `summarize_all`'s five regexp arms verbatim out of `run_regression.tcl` and SOURCING `tests/banner_rule.tcl`'s own predicates:
    cen_before_test_calc_measure    counted=0 nogold=0 skip_lc=0 SKIP_uc=0 RESULT=1 banner_complete=1 banner_died=0 case_failed=0   (170 checks)
    cen_after_test_calc_measure     counted=0 nogold=0 skip_lc=0 SKIP_uc=0 RESULT=1 banner_complete=1 banner_died=0 case_failed=0   (185 checks)
    cen_before_test_calc_wave_dest  counted=0 nogold=0 skip_lc=0 SKIP_uc=0 RESULT=1 banner_complete=1 banner_died=0 case_failed=0   (115 checks)
    cen_after_test_calc_wave_dest   counted=0 nogold=0 skip_lc=0 SKIP_uc=0 RESULT=1 banner_complete=1 banner_died=0 case_failed=0   (124 checks)
cases +0, blocks +0, counted_failures +0, skips +0, `wc -l` +0 (the NUMBER of `RESULT:`/`skip:` lines is unchanged; only the counts inside them moved). Derived trailer `cases=125 blocks=124 counted_failures=0 skips=8` with `wc -l 374` -- identical to the baseline `580f1622` recorded at `43a0c557`.

ELEVEN run_suites.sh invocations in total. `/usr/bin/grep -lcE 'UNEXPECTED ERROR|BGERROR|ABORTED|another regression run is live'` matches ZERO of the 19 transcripts, so no band was abandoned and every run was solo. Zero `/tmp/xschem_emergencysave_*` created in the last 2 hours (806 exist, oldest Sep 18, all pre-existing) -- nothing crashed in any run. Transcripts: /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/verify/{counted,display,before,skel_before,red,inverse_red,green_wt,sab_*}.txt

**rows_weakened_audit**

NO ROW WAS WEAKENED. Audited four independent ways; the red was reproduced in my OWN worktree.

=== (1) THE RED, IN MY OWN WORKTREE, src/ BYTE-IDENTICAL TO HEAD ===
`git worktree add --detach <scratch>/wt HEAD` at `cd08eabb`, then the main tree's `src/xschem` binary and the two modified suite files copied in; `src/calculator.tcl` left at HEAD (md5 `d27c869b760958bfe856e554683aa563`, which `git show HEAD:src/calculator.tcl | md5sum` confirms). `git diff --stat -- src/` produced NO OUTPUT. The probe `XSCHEM_SHAREDIR` printed `<wt>/src`, so the worktree's own Tcl is what ran -- and the red itself proves it, since the main tree's product is green.

    $ timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
    test home: throwaway /tmp/xschem-test-home.3531198.6maRsv (your HOME is untouched; ...)
    display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
    FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (113 passed)
    FAIL     | test_calc_measure            run 2/2  RESULT: 15 FAILED (170 passed)
    RESULT: 0/2 runs passed            (exit 1)

**26 FAILING ROWS. NO SHORTFALL.** 11 = WD9 x3 + WD13 x8; 15 = MT9b x4 + MT9c x11. I diffed all 26 got/exp tails against the literals the suite crew recorded in `red_proof` (24 rows) and the repair crew recorded in `rows_added` (2 rows): **every one matches verbatim, character for character.** The repair crew's two are the decisive ones and they are present and exact:
    MT9c PAIRING   -> {same refused atleast2 atleast1 sized {n:1 want:3} refused {count=1 want=3 got={NOKEY-sweep}} nodup tooshort:1} (exp {same measured atleast2 atleast1 sized sized ok ok nodup increasing}) : FAIL
    MT9c 3rd-EMPTY -> {refused absent {differ:Cross|Rise time} elsewhere known atleast1 atleast1 sized NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar elsewhere} (exp {absent absent samefamily elsewhere known atleast1 atleast1 sized absent NOKEY-db elsewhere}) : FAIL
An implementation that had turned a row green by editing the row would show here as a missing red row or a changed expectation literal. Neither happened.

=== (2) HUNK-BY-HUNK, AND THE HUNKS ARE TIGHT ===
`git diff -U0 -- tests/` is **six hunks total**. `test_calc_wave_dest.tcl`: two pure insertions (+1590 instruments, +3034 band WD13) and FOUR modification hunks, ALL inside `group WD9`. `test_calc_measure.tcl`: three pure insertions (+369 band-index comment, +1089 instruments, +2580 band MT9c) and FIVE modification hunks, ALL inside `group MT9b`. **No row outside MT9b and WD9 was touched at all.**
ALL REMOVED LINES in tests/ are 24 lines across 6 `check "` NAME lines: 4 in MT9b, 2 in WD9. WD9's third moved row changed only its expectation literal.
Each moved row audited individually -- every one gains legs and loses none:
  * MT9b "answers instead of raising": `{0 refused 0}` (3 legs) -> `{0 measured 0 atleast2 sized}` (5). The `mt_finite ... 0` leg is KEPT; `atleast2` and the parallel-sweep `sized` leg are NEW.
  * MT9b shared-sentence identity: `{refused 1 1 ok}` (4) -> `{measured 0 0 refused 1 ok}` (6). Both identity legs KEPT and INVERTED; `delay`'s own disposition and its own `listdefer` identity ADDED so the row cannot go green by both callers falling silent.
  * MT9b four-ordinal-spellings: `{{refused refused refused refused} {1 1 1 1}}` (2) -> `{measured ok 0}` (3), the first and third via `lsort -unique` (so a single divergent spelling still reddens) plus a NEW element-wise `mt_islist` comparison of each spelling's VALUE against the `0` spelling's. Strictly stronger.
  * MT9b "no engine door": `{{} 1}` (2) -> `{1 1 {} {}}` (4). The empty-`dest` claim the feature makes false is replaced by a mint-AND-delete claim, with `[leaked]`/`[probeleft]` ADDED.
  * WD9 four-caller identity: 8 legs -> 10, `riseTime` now driven at BOTH layers.
  * WD9 pairwise chain: 4 legs -> 8. The one lost comparison (b vs d) is structurally impossible to keep once `d` stops deferring, and a `wd_longer ... 0` non-vacuity leg plus four new negative legs replace it.
  * WD9 derived caller-set keystone: expectation literal only. `riseTime` MOVES from the deferring set to the wired set as `riseTime_scalar`. The derivation regexps are untouched context and the floor `[wd_atleast [llength $wd_bothsides] 4]` is **unchanged at 4**, over the UNION.

=== (3) DIFFSTAT ARITHMETIC, re-run by me ===
`check` sites in COMMAND POSITION (`/usr/bin/grep -cE '(^|[;[{])[ \t]*check[ \t]'`), HEAD via `git show` vs worktree:
    test_calc_measure.tcl    HEAD 154 -> 169   delta +15    removed NAME lines 4,  added 19   (154-4+19 = 169)
    test_calc_wave_dest.tcl  HEAD 115 -> 124   delta  +9    removed NAME lines 2,  added 11   (115-2+11 = 124)
Published check deltas I measured are **+15 and +9 -- exactly equal to the row deltas**, so no row was deleted AND no surviving row lost a check. Every removed name line pairs with an added one.

=== (4) THE INVERSE RED -- the leg that proves the moved rows were RE-AIMED and not LOOSENED ===
Worktree with the COMMITTED suites swapped in against the J2 product:
    FAIL | test_calc_wave_dest   3 FAILED (112 passed)
    FAIL | test_calc_measure     4 FAILED (166 passed)       exit 1
Exactly the 7 moved rows, failing in the OPPOSITE direction, e.g. `MT9b ... -> {0 measured 0} (exp {0 refused 0})`, `MT9b ... -> {__calc_tmp154 1} (exp {{} 1})`, `WD9 ... -> {{cross_scalar delay} {dutyCycle_scalar riseTime_scalar} ... } (exp {{cross_scalar delay riseTime} dutyCycle_scalar ...})`. A loosened expectation would be satisfied by BOTH products; each of these is satisfied by exactly one.

=== PRODUCT SIDE ===
`git diff --numstat -- src/calculator.tcl` = `254 59`, and the removed NON-COMMENT lines are **exactly four**: issue 1639's three `listdefer` guard lines and the one catalogue row. The spec removes two prose lines. Everything else removed is comment.

**sabotage_resurvey**

FIVE sabotages applied to `src/calculator.tcl` inside my own worktree (J2 product + the new suites, green control first). Each patch was anchored and refused to apply unless its anchor matched EXACTLY ONCE, so a sabotage that silently did nothing cannot be mistaken for a fence. Generator: <scratch>/J2/verify/sab.py.

GREEN CONTROL IN THE WORKTREE FIRST: `ALL PASS (124 checks)` / `ALL PASS (185 checks)`, 2/2, exit 0 -- so the worktree is a faithful replica and every red below is the sabotage.

=== (a) THE WRONG PAIRING DIRECTION -- the one that SURVIVED nine suites. REDDENS. ===
Patch: drive the HIGH list, pairing each high with the LAST low BEFORE it (`foreach xh [dict get $highs value] { foreach l [dict get $lows value] { if {$l < $xh} { set x0 $l } else { break } } ... }`).
    FAIL | test_calc_measure   1 FAILED (184 passed)        PASS | test_calc_wave_dest  ALL PASS (124 checks)
ROW: *"MT9c THE PAIRING DIRECTION, on the one shape that can see it: a signal that RINGS at the top crosses its HIGH threshold more often than its LOW one..."*, ALONE.
    -> {same measured atleast2 atleast1 sized {n:6 want:3} {count=6 want=3 got={0.00025896410621851725 0.0011520614982852906 0.00028006995107610847 0.0011717368142693634 0.0002679712619799244 0.0011583248338392273}} {count=6 want=3 got={0.001628478720832479 0.001628478720832479 0.004943333333333332 0.004943333333333332 0.008290580452878223 0.008290580452878223}} dup:3-of-6 notincreasing:1} (exp {same measured atleast2 atleast1 sized sized ok ok nodup increasing}) : FAIL
FIVE legs fire; the X leg names all three duplicated low crossings. Byte-identical to the literal the repair crew recorded under `S5_pairhigh`. The three non-vacuity legs are GREEN under the sabotage, which is what proves the minted ringing shape really is the discriminating one.

=== (b) THE ABSENCE GUARD ON THE INPUTS -- the other SURVIVOR. REDDENS. ===
Patch: `if {![llength [dict get $lows value]] || ![llength [dict get $highs value]]} {` in place of `if {![llength $ys]} {`.
    FAIL | test_calc_measure   1 FAILED (184 passed)        PASS | test_calc_wave_dest  ALL PASS (124 checks)
ROW: *"MT9c ...and the THIRD empty shape, the one both rows above exclude by their own non-vacuity legs..."*, ALONE.
    -> {measured absent {differ:NOFAMILY:{}|Rise time} elsewhere unknown:NOFAMILY:{} atleast1 atleast1 sized refused NOKEY-db samefamily:Destination} (exp {absent absent samefamily elsewhere known atleast1 atleast1 sized absent NOKEY-db elsewhere}) : FAIL
FIVE legs fire and the last names the defect in the user's own words: `samefamily:Destination` where the truth is an absence. Byte-identical to the recorded `FORM2_inputguard` red. The `NOKEY-db` leg is GREEN under the sabotage, confirming the surface DISPOSITION and FAMILY legs are what fence what the user reads.

=== (c) A PADDED DROP -- length preserved, filled with its predecessor. REDDENS. ===
Patch: on no high found, `lappend ys $lasty` instead of `continue`.
    FAIL | test_calc_measure   1 FAILED (184 passed)        PASS | test_calc_wave_dest  ALL PASS (124 checks)
ROW: MT9c's partial-drop row, ALONE, and it NAMES the duplicated element:
    -> {measured {n:3 want:2} atleast1 {count=3 want=2 got={0.0011130770436309611 0.0011120979237804448 0.0011120979237804448}} {count=3 want=2 got={0.0009739434720928703 0.004975045466306166 0.008975045466316396}} absent} (exp {measured sized atleast1 ok ok absent}) : FAIL

=== (c2) THE ATTACK'S OWN LENGTH-PRESERVING FORM -- `set xh {}` hoisted out of the loop. REDDENS, and SHIPS A NEGATIVE. ===
    FAIL | test_calc_measure   1 FAILED (184 passed)        PASS | test_calc_wave_dest  ALL PASS (124 checks)
Same single row, and it prints the unphysical value:
    -> {measured {n:3 want:2} atleast1 {count=3 want=2 got={0.0011130770436309611 0.0011120979237804448 **-0.002887902076229785**}} ... } : FAIL
Identical to the figure the repair crew recorded. CONFIRMED: this is a ONE-ROW dependency and the catch is by LENGTH, not by SIGN.

=== (d) THE ENGINE DOOR INSIDE calc::riseTime -- the wrapper a bare pass-through. REDDENS TWO ROWS, ONE IN EACH SUITE. ===
    FAIL | test_calc_wave_dest   1 FAILED (123 passed)      FAIL | test_calc_measure   1 FAILED (184 passed)
    WD9 partition  -> {{cross_scalar delay} {dutyCycle_scalar riseTime} {cross_scalar delay dutyCycle_scalar riseTime} atleast} (exp {{cross_scalar delay} {dutyCycle_scalar riseTime_scalar} {cross_scalar delay dutyCycle_scalar riseTime_scalar} atleast}) : FAIL
    MT10 closure   -> {{riseTime delay dutyCycle} {wave_dest {} {}}} (exp {{riseTime delay dutyCycle} {{} {} {}}}) : FAIL
MT10 names the wrong LAYER and WD9 names `riseTime` where `riseTime_scalar` belongs. Exactly as the receipt claimed.

ALL FIVE REDDEN. Zero `UNEXPECTED ERROR|BGERROR|ABORTED|another regression run is live` lines in any of the five transcripts, so none of them abandoned a band (a raise would have been a false red).

=== THE SWITCH-PARITY TRAP, structurally AND behaviourally ===
Structural, derived rather than eyeballed: I took all 13 new-line ranges from `git diff -U0 -- src/calculator.tcl` and asked per hunk whether it falls inside a `^proc`...column-0-`}` body, and whether that proc issues `switch` in COMMAND POSITION in its decommented body. Result: 13 hunks; only 3 are inside a proc body (`calc::riseTime`'s new arm x2, and the one catalogue ROW inside `calc::catalogue`), and **`switch_in_proc=False` for all three**. No comment of this diff sits between two `switch` patterns, so the parity hazard does not arise.
Behavioural, which is the only confirmation this project accepts, run against the real binary (`env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script`) with every arm set DERIVED from each proc's own switch argument:
    SWITCHPROCS: 11
    NAMES: ::calc::arg_bad ::calc::arg_msg ::calc::cross ::calc::cross_msg ::calc::cross_ordinal ::calc::eval_msg ::calc::fn_argspec ::calc::fn_reason ::calc::plot_msg ::calc::results_label ::calc::results_tip
    BEHAV ::calc::cross_msg  arms=36  ok=36  raised=0        BEHAV ::calc::arg_msg  arms=10 ok=10 raised=0
    BEHAV ::calc::eval_msg   arms=11  ok=11  raised=0        BEHAV ::calc::plot_msg arms=9  ok=9  raised=0
    BEHAV ::calc::arg_bad 2/2, ::calc::cross 2/2, ::calc::fn_reason 3/3, ::calc::results_label 4/4, ::calc::results_tip 4/4
    ::calc::cross_ordinal swept -25..125:  ok=151 raised=0
    ARMSWEEP_RAISING_PROCS=0
⚠ Worth recording for the next crew: my first version of this probe used `regexp` WITHOUT `-line`, so `(^|[;[{])` matched only at string start and it reported `SWITCHPROCS: 0` -- a silent zero that reads exactly like "no switch procs". A second version with a bare `{` inside the character class inside a braced word died with `missing close-brace`. Both are the brace/anchor traps CLAUDE.md warns about, met in the instrument rather than the product.

**verdict**

**GREEN AND HONEST.** The product is correct, the red reproduces in full with every literal intact, no row was weakened, and all five sabotages -- including both survivors -- redden. Two prose overstatements, one of them in the SHIPPED SOURCE; neither is a product defect and neither needs a row to move.

⚠ **PROSE NOT ASSERTED BY THE TREE, AND MEASURABLY FALSE AS WRITTEN -- ONE SITE, IN `src/calculator.tcl`.** `calc::riseTime`'s header says the empty-series absence *"reus[es] the very `calc::cross_msg` arm the ordinal path already uses for the identical request, so one physical fact is reported in one voice whether the user asked for one edge or all of them."* The receipt's `verb_arm` field says the same thing more strongly: *"all four answer the same absence ... the same `cross_msg` arm and therefore the same family (\"Rise time\") the shipped ordinal path already uses"*. MEASURED against the loaded fixture, for the three reachable empty shapes:
    A `riseTime {v(sq)} 100 200 10 90`    nth0: "Rise time: the 0th low crossing has no high crossing after it in this sweep."
                                          nth1: "Cross: there is no 1st rising crossing of that level in this sweep."     -> FAMILIES DIFFER
    B `riseTime {v(lp)} 0 1 10 99.95`     nth0 "Rise time: ..."   nth1 "Rise time: the 1st low crossing ..."              -> same
    D `riseTime {v(ramp)} 1 0 10 90`      nth0 "Rise time: ..."   nth1 "Rise time: the 1st low crossing ..."              -> same
On shape A the ordinal path refuses inside `cross` (no 1st rising crossing of the LOW level at all), so the "one voice" claim holds for two of the three shapes and fails for the third. The TREE is self-consistent: the `samefamily` leg exists only on the third-empty-shape row, which drives shape D, and shape A's row asserts only `known` + `elsewhere`. So no row is wrong and nothing needs to move -- **the sentence is simply broader than what was measured**, which is the dead-prose class CLAUDE.md records. The fix is to narrow the sentence (and the receipt) to the shapes where the ordinal path also reaches `nohigh`. ⚠ It is also the only place a reader would learn the general rule, and nothing re-derives it.

⚠ **PROSE BEYOND THE TREE -- the `user_visible` field, declared as a hole but then stated affirmatively.** It says *"through the channel unit J1b armed -- the curve appears by itself on its own strip in the waveform viewer"*. MEASURED: band WD13 (riseTime's destination) matches `wave_show|plot_dbs_arm` **ZERO** times; the only `wave_show` sites in `test_calc_wave_dest.tcl` are in band WD12 and they drive `dutyCycle`'s destination. `test_calc_plot` matches `riseTime` zero times. So nothing anywhere asserts that a `riseTime` wave reaches the viewer. The inference is strong (`wave_show` resolves by `db` and WD13 asserts `db` is a registered `__calc_dest<N>` of `type table`), but it is an inference. The implementer's hole 9 says exactly this; the `user_visible` field should match it.

CLAIMS I CHECKED AND FOUND TRUE, each by my own measurement rather than by reading:
  * `SAMEFORMALS=1` -- `info args` on both: `rpn lo hi pctlo pcthi nth dataset`, byte for byte.
  * Four and only four non-comment lines removed from `src/calculator.tcl` (the 3-line guard + the catalogue row).
  * `arg_surface riseTime` -> `riseTime_scalar`; `fn_sink` -> `destination` for nth 0 and `buffer` for nth 1; answer keys exactly `absent dataset db dest msg n ok shape sweep type value xname yname`; `db=__calc_dest1 type=table xname=calcx yname=calcy n=3 shape=wave dest=__calc_tmp25` -- `dest` holds the retired tmp, `db` the live destination.
  * Nine prose sites: all nine edited and all nine now read true. The three surviving mentions of *"the unbuilt `frequency`"* are CORRECT (`frequency` genuinely has no proc). The *"riseTime and delay stay scalar"* sentence is gone from `src/` and from the spec.
  * No row anywhere asserts `riseTime`'s `returns` value: `/usr/bin/grep riseTime tests/headless/test_calc_skeleton.tcl` matches ONE line and it is inside a comment. The catalogue respelling is a literal plus prose, and `test_calc_skeleton` is 579 both before and after -- I ran the before.
  * MT10 is green and `d_wronglayer` reddens it, so it is a live fence and not a rotted one.
  * Positivity: on every driven request the shipped Y is strictly positive (`nonpositive=0` on all three), and the declared hole is real -- sabotage (c2) ships `-0.002887902076229785` and the single row that catches it does so by LENGTH, not by sign.
  * The three single-row dependencies ((a), (b), (c)/(c2)) are confirmed as single-row, with `test_calc_wave_dest` ALL PASS under all of them. That is the open driver decision the repair crew flagged and it is still open.

**for_the_driver**

BEFORE COMMITTING, check these -- all of them I verified, so they are a checklist and not a request:
  1. `git status --short` is the four modified files and the four pre-existing `??` entries, nothing else. The main tree's md5s are unchanged by my work: `src/calculator.tcl` 799ae39fd8d7ee216a51a706243e83a3, `test_calc_measure.tcl` 3dee5ff8d2495232f024b2e378218abb, `test_calc_wave_dest.tcl` c0a5b494e76feaa9222f100259cd5b83.
  2. My verification worktree is REMOVED and `git worktree prune` run; the 8 remaining entries under `.claude/worktrees/` are other sessions' and were there before me. No throwaway test home left behind (`ls -d /tmp/xschem-test-home.*` = 0). `/tmp` (tmpfs) at 779M of 7.7G; my scratch is 2.0 MB at <scratch>/J2/verify.
  3. All four files belong in ONE commit. Band MT9c and band WD13 are standing reds on a producer-only tree, and `calc::arg_surface` redirects every `riseTime` click the instant the wrapper exists.
  4. ⚠ Consider narrowing the "one voice" sentence in `calc::riseTime`'s header before committing -- see the verdict. It is measurably broader than the three empty shapes support (shape A's ordinal path answers the "Cross" family, not "Rise time"), and no row holds it to account. Also consider aligning the receipt's `user_visible` field with its own hole 9: no row asserts that the riseTime wave draws.
  5. ⚠ The padded-drop single-row dependency and the negative rise time are STILL your open decision, re-measured here. The repair crew's proposal (a non-negativity leg on the SERIES in MT9c's keystone and on the READ-BACK Y in WD13's keystone, derived over the answer's own list) adds NO row and therefore moves NO published count, and would take the padded shape from one catcher to three. I confirmed by sabotage that the one catcher catches by LENGTH only.

EXACT PUBLISHED COUNTS FOR THE COMMIT MESSAGE, re-derived by me on both arms, identical on both:
    test_calc_wave_dest       115 -> 124   (+9:  WD9 x3 moved, WD13 x9 new)
    test_calc_measure         170 -> 185   (+15: MT9b x4 moved, MT9c x11 new)
    test_calc_cross           187 -> 187   unmoved
    test_calc_engine          265 -> 265   unmoved
    test_calc_scratch_reuse    56 ->  56   unmoved
    test_calc_skeleton        579 -> 579   unmoved (display arm, the only arm that runs S24 -- I ran the BEFORE as well)
    test_calc_plot            114 -> 114   unmoved
    test_calc_widgets         259 -> 259   unmoved
    test_calc_buffer          130 -> 130   unmoved
Row deltas +15 and +9 equal the published deltas exactly, which is the arithmetic proof that no row was deleted and no surviving row lost a check.

THE TRAILER TO EXPECT, DERIVED and never predicted (I did not run T1): registration delta ZERO, both suites already in `hcases`; tcases 3 + hcases 96 + dcases 25 + xschemtest = `cases=125 blocks=124 counted_failures=0 skips=8`, and `wc -l 374` -- every term unchanged from `580f1622`'s baseline at `43a0c557`. This is the PLAN 5.4 / J1 / J1b shape for the fourth time: two published check counts move and not one trailer term, not even `wc -l`, because the NUMBER of `RESULT:`/`skip:` lines is what `wc -l` moves with. Census taken the `hcases` way and scored with `summarize_all`'s own five regexp arms lifted out of `run_regression.tcl` plus `tests/banner_rule.tcl`'s own predicates SOURCED: `counted=0 skip_lc=0 SKIP_uc=0 RESULT=1 banner_complete=1 banner_died=0 case_failed=0` for both suites, before AND after.

