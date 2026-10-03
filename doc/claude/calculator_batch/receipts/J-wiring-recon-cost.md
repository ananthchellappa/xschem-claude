# recon:cost

**derivation_command**: All scripts and raw output are kept at /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J-wire-dest/cost-measure/ (rowscan2.awk, zeroord.awk, derive.sh, DERIVATION.txt, run1..run6.txt).

=== PIPELINE 1 -- the deferring CALL SITES, by enclosing proc (never listed) ===
  awk '/^[ \t]*proc [a-zA-Z_:]/{p=$2; pl=NR}
       /calc::cross_msg listdefer/ && !/^[ \t]*#/ {print "  site "NR"  proc "p" (declared "pl")"}' src/calculator.tcl
RAW OUTPUT:
  site 2896  proc calc::cross_scalar (declared 2894)
  site 3050  proc calc::riseTime (declared 3012)
  site 3126  proc calc::delay (declared 3123)
  site 3327  proc calc::dutyCycle_scalar (declared 3325)
=> FOUR deferring callers, not three. The task statement and DESTINATION_CONTRACT.md section 1 both
   name only dutyCycle_scalar / delay / frequency. `calc::riseTime` with nth = 0 joined the set when
   issue 1639 was fixed (2026-10-03); TIMING_CONTRACT.md lines 54-57 record it, the four src/ prose
   copies do not.

=== PIPELINE 2 -- rows whose CHECK BODY (not a neighbouring comment) names listdefer ===
rowscan2.awk splits each suite into per-check blocks; a block is the `check` line plus following
lines up to the first comment, blank line, or next check/group/proc -- which keeps a trailing
explanatory comment belonging to the NEXT row out of this row's text (the loose version attributed
MT10/MT11/WD8/WD9/S28 falsely for exactly that reason):
  for f in tests/headless/test_*.tcl tests/*.tcl; do awk -v pat='listdefer' -f rowscan2.awk "$f"; done
RAW OUTPUT (file, row, line):
  tests/headless/test_calc_measure.tcl	MT7	1739
  tests/headless/test_calc_measure.tcl	MT8	1890
  tests/headless/test_calc_measure.tcl	MT9b	1995
  tests/headless/test_calc_measure.tcl	MT9b	2002
  tests/headless/test_calc_measure.tcl	MT9b	2013
  tests/headless/test_calc_measure.tcl	MT9b	2022
  tests/headless/test_calc_measure.tcl	MT9b	2035
  tests/headless/test_calc_wave_dest.tcl	WD10	1733

=== PIPELINE 3 -- rows whose body spells a ZERO-ORDINAL call to a deferring surface proc ===
zeroord.awk walks every line tracking the enclosing `check`, and matches the zero-ordinal shapes
(cross_scalar nth 0; delay (rising|falling) 0; any dutyCycle_scalar; riseTime ...90 0; the
{0 0.0 -0 0e0} spelling sweep). Needed because WD9's rows reach the verbs through `wd_call` on
continuation lines that pipeline 2's block cut:
  for f in tests/headless/test_calc_*.tcl; do awk -f zeroord.awk "$f"; done |
    awk -F'\t' '$2 != "(outside-check)" && $4 !~ /^ freqverb$/ {print}'
RAW OUTPUT:
  test_calc_measure.tcl	MT7	1739	cross_scalar-nth0
  test_calc_measure.tcl	MT7	1740	delay-nth0
  test_calc_measure.tcl	MT7	1742	delay-nth0
  test_calc_measure.tcl	MT8	1891	dutyCycle_scalar
  test_calc_measure.tcl	MT8	1893	dutyCycle_scalar
  test_calc_measure.tcl	MT9b	1993	riseTime-nth0
  test_calc_measure.tcl	MT9b	1996	riseTime-nth0
  test_calc_measure.tcl	MT9b	1999	delay-nth0
  test_calc_measure.tcl	MT9b	2003	zero-spellings
  test_calc_measure.tcl	MT9b	2004	zero-spellings
  test_calc_measure.tcl	MT9b	2009	riseTime-nth0
  test_calc_measure.tcl	MT9b	2014	riseTime-nth0
  test_calc_measure.tcl	MT9b	2017	riseTime-nth0
  test_calc_measure.tcl	MT11	2498	dutyCycle_scalar
  test_calc_measure.tcl	MT11	2546	dutyCycle_scalar
  test_calc_wave_dest.tcl	WD9	1633	cross_scalar-nth0 dutyCycle_scalar
  test_calc_wave_dest.tcl	WD9	1634	cross_scalar-nth0
  test_calc_wave_dest.tcl	WD9	1636	delay-nth0
  test_calc_wave_dest.tcl	WD9	1638	dutyCycle_scalar
  test_calc_wave_dest.tcl	WD9	1640	riseTime-nth0
  test_calc_wave_dest.tcl	WD9	1666	dutyCycle_scalar

=== PIPELINE 4 -- the clickable-verb-set literals that move if `calc::frequency` is BUILT ===
  /usr/bin/grep -n 'ag_verbs\] {cross\|llength \[ag_verbs\]\|agnswept \$agnonempty\|ad_nfall\|ad_nlie' \
      tests/headless/test_calc_measure.tcl tests/headless/test_calc_skeleton.tcl
RAW OUTPUT:
  test_calc_measure.tcl:2408:        [ag_verbs] {cross delay dutyCycle riseTime}
  test_calc_measure.tcl:2424:        [list $agnswept $agnonempty $agempty] {108 4 {}}
  test_calc_measure.tcl:2474:        [list [llength [ag_verbs]] $agbadrpn] {4 {}}
  test_calc_skeleton.tcl:4018:    [list $ad_nfall [llength [ad_verbs]] $ad_fallbad] {30 4 {}}
  test_calc_skeleton.tcl:4049:    [list $ad_nlie $ad_liebad] {4 {}}
`ag_verbs` / `ad_verbs` are DERIVED as "every route-T catalogue row whose ::calc::<name> proc exists".
Shipping `calc::frequency` therefore reddens all five WITHOUT any behavioural change.

=== PIPELINE 5 -- the five-term `returns` vocabulary, every spelling in the tree ===
  /usr/bin/grep -rn -E 'scalar[ /|`]*\|?[ `]*wave[^a-z]*\|?[ `]*bool' src/ tests/ doc/claude/specs/
RAW OUTPUT:
  src/calculator.tcl:4596:#   returns   scalar | wave | bool | scalar/wave | scalar/list  - section 7.2's Returns
  src/calculator.tcl:4700:# `scalar` / `wave` / `bool` / `scalar/wave` / `scalar/list` is a counted failure
  tests/headless/test_calc_skeleton.tcl:2555:    if {[lsearch -exact {scalar wave bool scalar/wave scalar/list} $returns] < 0} {
  doc/claude/specs/calculator.md:687:  `scalar` / `wave` / `bool` / `scalar/wave` / **`scalar/list`**, widened by one term for R419.
=> TWO copies in src/calculator.tcl (the comment block above `calc::fn_fields`, line 4668, and the
   one above `calc::catalogue`, line 4746), one in the spec, one in the suite. The task statement's
   "the calc::catalogue comment (TWICE)" is NOT reproducible by grep; it comes from S24's own comment
   at test_calc_skeleton.tcl:2551-2553, which is a count in prose that no command confirms -- the
   `grep -c '#pragma'` class CLAUDE.md forbids.

=== PIPELINE 6 -- armers of the one-shot sweep channel ===
  /usr/bin/grep -rn 'plot_sweeps_arm\|plot_sweeps_take' src/ tests/
RAW OUTPUT:
  src/wave_viewer.tcl:7743:proc wviewer::plot_sweeps_arm {token sweeps} {
  src/wave_viewer.tcl:7748:proc wviewer::plot_sweeps_take {token} {
  src/wave_viewer.tcl:7783:  set sweeps [wviewer::plot_sweeps_take $token]
=> ZERO armers and ZERO test references. Stage J is the first armer, exactly as the proc's header
   declares. Arming it reddens nothing and is covered by nothing.

=== PIPELINE 7 -- registration of every suite touching plot_signals / graph_props ===
  H=$(sed -n '27,120p' tests/run_regression.tcl | /usr/bin/grep -o '"[^"]*"' | tr -d '"')
  D=$(sed -n '682,704p' tests/run_regression.tcl | /usr/bin/grep -o '"[^"]*"' | tr -d '"')
  for f in $(/usr/bin/grep -rl 'plot_signals\|graph_props' tests/headless/*.tcl | xargs -n1 basename |
             sed 's/\.tcl$//' | sort -u); do ... done
RAW OUTPUT (23 suites; only 4 registered):
  test_calc_plot DCASES | test_calc_scratch_reuse HCASES | test_calc_wave_dest HCASES |
  test_wave_viewer DCASES | the other 19 (test_wave_grid, test_wave_sigbrowser{,_digital,_sea},
  test_ase_current_repair, test_results_select, test_wave_modes, test_wave_clear_all,
  test_wave_crossdb_trace, ...) are in NEITHER list.
Line counts of the lists, derived the way CLAUDE.md prescribes: hcases 96, dcases 24 (matching the
124 = 3 + 96 + 24 + xschemtest baseline).

### rows_that_would_redden
  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE -- counted arm)

    **row**: MT7, check at line 1739: "MT7 D8 nth 0 on EITHER side of delay is REFUSED rather than raising out of the subtraction..."

    **what_it_asserts**: {0 refused 1 0 refused 1} -- delay with nth 0 on side A and on side B each answers disposition `refused`, does not raise, and carries a message STRING-EQUAL to [calc::cross_msg listdefer]. The moment delay nth 0 returns a waveform the disposition becomes `measured` and the identity leg goes 1 -> 0.

    **verified_how**: RAN it. tests/headless/run_suites.sh --nogui test_calc_measure -> RESULT: ALL PASS (160 checks).

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE)

    **row**: MT8, check at line 1890: "MT8 D8 the UI surface defers the wave case behind the SAME sentence cross already uses for nth=0..."

    **what_it_asserts**: {refused 1 measured ok} -- calc::dutyCycle_scalar called with only {rpn level} (R420's DEFAULT cycle) is `refused` with the listdefer sentence by identity, while a NAMED cycle still measures. The first two legs invert when the default cycle lands a wave.

    **verified_how**: RAN it (160 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE)

    **row**: MT9b, check at line 1995: "MT9b 1639 riseTime with nth 0 ANSWERS instead of raising... and the answer is a REFUSAL rather than a number computed off a list"

    **what_it_asserts**: {0 refused 0} -- riseTime nth 0 does not raise, is `refused`, and its `value` is not finite. A waveform answer makes leg 2 `measured`.

    **verified_how**: RAN it (160 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE)

    **row**: MT9b, check at line 2002: "...and the refusal carries the VERY sentence its three siblings defer behind -- asserted by identity against calc::cross_msg listdefer and pairwise against delay's own answer"

    **what_it_asserts**: {refused 1 1 ok} -- riseTime nth 0's message equals [calc::cross_msg listdefer] AND equals delay nth 0's message. BOTH pairwise legs break if the two callers are wired in different commits, which is the trap: wiring riseTime alone reddens this even though delay is untouched.

    **verified_how**: RAN it (160 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE)

    **row**: MT9b, check at line 2002 block, the four-spelling sweep at lines 2003-2007

    **what_it_asserts**: {{refused refused refused refused} {1 1 1 1}} -- the ordinals 0, 0.0, -0 and 0e0 all defer with the identical sentence (the guard reads the ordinal's VALUE, not its spelling). All eight legs move together when the deferral becomes an answer.

    **verified_how**: RAN it (160 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE)

    **row**: MT9b, check at line 2008: "MT9b 1639 the deferral opens NO engine door, which is observable rather than inferred: it carries an EMPTY dest..."

    **what_it_asserts**: {{} 1} -- riseTime nth 0's answer carries an EMPTY `dest` key, while riseTime's ABSENCE path carries a __calc_tmp* name. This is the row that reddens on the DESTINATION rather than on the message: a real wave destination necessarily puts a name in `dest`, so this row is red the instant the engine door opens, even if every sentence is left alone.

    **verified_how**: RAN it (160 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_wave_dest.tcl (hcases ALONE)

    **row**: WD9, check at line 1633: "WD9 EVERY deferring caller answers THAT SAME SENTENCE BY IDENTITY -- cross_scalar's nth 0, delay's nth 0 on a side, dutyCycle_scalar's default cycle and riseTime's nth 0"

    **what_it_asserts**: {refused 1 refused 1 refused 1 refused 1} -- all FOUR callers driven in one row. Two legs redden per caller stage J wires, so this is the single row that counts the stage's progress; it cannot be partially satisfied.

    **verified_how**: RAN it. tests/headless/run_suites.sh --nogui test_calc_wave_dest -> RESULT: ALL PASS (90 checks).

  - 
    **suite**: tests/headless/test_calc_wave_dest.tcl (hcases ALONE)

    **row**: WD9, check at line 1643: "...and pairwise along the whole chain, so the row cannot be satisfied by callers that each match cross_msg while differing from each other"

    **what_it_asserts**: {1 1 1} -- msg(cross_scalar) == msg(delay) == msg(dutyCycle_scalar) == msg(riseTime). Reddens on the FIRST caller wired, because the chain is then broken in the middle.

    **verified_how**: RAN it (90 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_wave_dest.tcl (hcases ALONE)

    **row**: WD9, check at line 1664: "WD9 the set of callers that defer behind that sentence is DERIVED over the namespace and is exactly the set this band drives -- so a FIFTH deferring caller reddens here naming itself"

    **what_it_asserts**: {{cross_scalar delay dutyCycle_scalar riseTime} atleast} -- the set is computed by regexp {cross_msg +listdefer} over [info body] of every ::calc::* proc, plus a lower-bound leg of 4. It was built to catch a caller being ADDED; stage J REMOVES callers, so the derived list shrinks and the lower-bound leg fails too. This is the keystone row and it names the caller that changed -- it is the fence reporting its own obsolescence, by design (DESTINATION_CONTRACT section (h)).

    **verified_how**: RAN it (90 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_wave_dest.tcl (hcases ALONE)

    **row**: WD10, check at line 1733: "...and that derivation is NOT VACUOUS... it finds the sentence this suite's own WD9 rows read by name"

    **what_it_asserts**: {has has has missing atleast} -- the FIRST leg requires the literal `listdefer` to still be an arm of calc::cross_msg. Reddens ONLY if stage J deletes the now-unused arm; keeping the arm costs nothing. The companion row above it (every cross_msg arm answers non-empty without raising, derived from the proc's own switch patterns) is the only behavioural confirmation that no comment landed between two switch patterns -- so a stage that edits calc::cross_msg must re-run it.

    **verified_how**: RAN it (90 checks, ALL PASS).

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE) -- CONDITIONAL on building calc::frequency

    **row**: MT11, check at line 2408: "MT11 the clickable set is DERIVED from the tree -- every route-T catalogue row that has a proc of its own -- and it is the four verbs this stage makes reachable"

    **what_it_asserts**: [ag_verbs] == {cross delay dutyCycle riseTime}, an EXACT LITERAL LIST. `calc::frequency` is already a route-T catalogue row (src/calculator.tcl:4771), so the day its proc exists this row reddens with no behavioural change at all.

    **verified_how**: RAN it (160 checks, ALL PASS). The conditional direction is read from the derivation in ag_verbs (test_calc_measure.tcl:2280-2288), not run against a tree that has calc::frequency.

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE) -- CONDITIONAL on building calc::frequency

    **row**: MT11, check at line 2424: "MT11 the 30-verb fall-through is LEGIBLE rather than accidental: every catalogue name that is not one of the four answers an EMPTY spec, and each of the four answers a non-empty one"

    **what_it_asserts**: {108 4 {}} -- 108 catalogue rows swept, exactly 4 with a non-empty fn_argspec, and no offender. A built calc::frequency moves the 4 to 5 AND, if it ships without a calc::fn_argspec arm, adds `frequency=EMPTY` to the offender list -- the row reddens twice over.

    **verified_how**: RAN it (160 checks, ALL PASS); conditional direction read from the row's own loop.

  - 
    **suite**: tests/headless/test_calc_measure.tcl (hcases ALONE) -- CONDITIONAL on building calc::frequency

    **row**: MT11, check at line 2474: "MT11 R421 the expression operand comes from the BUFFER and is not a dialog field -- so no spec offers an `rpn` field except `delay`"

    **what_it_asserts**: {4 {}} -- [llength [ag_verbs]] is 4. Same mechanism as above.

    **verified_how**: RAN it (160 checks, ALL PASS); conditional direction read from the row.

  - 
    **suite**: tests/headless/test_calc_skeleton.tcl (dcases ALONE -- DISPLAY ARM ONLY) -- CONDITIONAL on building calc::frequency

    **row**: S28/0, check at line 4018: "S28 the 30 route-T verbs with NO proc fall through legibly... the set and the sweep count are both DERIVED from the catalogue and the namespace"

    **what_it_asserts**: {30 4 {}} -- 30 route-T catalogue names with no proc, 4 with one. A built calc::frequency makes it {29 5 {}}.

    **verified_how**: RAN the suite on its real arm: env -u DISPLAY tests/headless/run_suites.sh test_calc_skeleton -> RESULT: ALL PASS (573 checks). The conditional direction is read from ad_verbs/ad_tnoproc (test_calc_skeleton.tcl:3859-3878), not run.

  - 
    **suite**: tests/headless/test_calc_skeleton.tcl (dcases ALONE -- DISPLAY ARM ONLY) -- CONDITIONAL on building calc::frequency

    **row**: S28/1, check at line 4049: "S28 no verb that IS built is told it is not: none of the four gets calc::inert's phase-5 sentence and none gets fn_reason's \"is not available\" one"

    **what_it_asserts**: {4 {}} -- the loop runs over ad_verbs and counts 4. Note the second consequence: calc::fn_measure's own first line is `if {[llength $spec] == 0} { return [calc::inert "function $name" 5] }`, so a calc::frequency built WITHOUT a fn_argspec arm would also be told it is not implemented, putting `frequency=STILL-SAYS-NOT-IMPLEMENTED` in the offender list.

    **verified_how**: RAN the suite on its real arm (573 checks, ALL PASS); conditional direction read from the row's loop and from calc::fn_measure's body.

  - 
    **suite**: tests/headless/test_calc_widgets.tcl (dcases ALONE -- DISPLAY ARM ONLY) -- CONDITIONAL on wiring the LIST surface

    **row**: CW13, the `allowed` -command list at line 1495 and the two checks on it ("no control is wired to anything but a phase-1 stub or one of the four phase-2 procs", "exactly fifteen controls are wired to a landed phase-2 proc")

    **what_it_asserts**: allowed == {calc::inert calc::status calc::sel_click calc::sel_refuse calc::dest_changed calc::res_toggle calc::eval_click calc::plot_click calc::browse_inert}, and nlive == 15. R419's LIST surface is spec R606's `Table` control, which today is `-command [list calc::inert {Table} 10]` (src/calculator.tcl:3954). Replacing that with a real handler puts a tenth first-word in $rogue. Stage J can avoid this entirely by routing cross_scalar's list through something that is not a new -command.

    **verified_how**: RAN the suite on its real arm: env -u DISPLAY tests/headless/run_suites.sh test_calc_widgets -> RESULT: ALL PASS (259 checks). The conditional direction is read from the row's `allowed` literal, not run.

  - 
    **suite**: tests/headless/test_calc_scratch_reuse.tcl (hcases ALONE) -- CONDITIONAL on the plotting route chosen

    **row**: SR5, check at line 564: "SR5 ...and the procs that reach the engine through the VIEWER's door instead are Plot's, which is why no R402 delete belongs there"

    **what_it_asserts**: $viaviewer == {plot_rpn}, a ONE-NAME LITERAL, derived by regexp {wviewer::(add_trace|plot_signals)} over the decommented body of every ::calc::* proc. If stage J's result path names wviewer::add_trace or wviewer::plot_signals from inside the calc:: namespace -- which is the obvious way to put the destination's trace on screen -- the set gains a second member and this row reddens naming it. The companion row at line 576 ("no proc uses BOTH doors", expected [list [llength $adders] 1 {}]) pins the viewer-door count at 1 and reddens for the same reason.

    **verified_how**: RAN it. tests/headless/run_suites.sh --nogui test_calc_scratch_reuse -> RESULT: ALL PASS (54 checks). The conditional direction is read from the row's own regexp, not run.

  - 
    **suite**: tests/headless/test_calc_scratch_reuse.tcl (hcases ALONE) -- CONDITIONAL on a new direct `xschem raw add`

    **row**: SR5, check at line 520: "SR5 R402 ...and the only direct adder that reads NOTHING back is the R419 destination producer, whose Y column is persistent by design -- a literal... so a SECOND add-without-read door reddens here"

    **what_it_asserts**: $persistent == {wave_dest}, a one-name literal. Stage J's callers should reach the engine through calc::wave_dest and issue no `xschem raw add` of their own; a caller that does (for instance a frequency implementation building its own column) reddens this and must justify itself.

    **verified_how**: RAN it (54 checks, ALL PASS); conditional direction read from the row.


### arity_and_schema_pins
  - WD4 of tests/headless/test_calc_wave_dest.tcl (HCASES -- the ONE gate-visible arity pin), check at line 1317: expects {3 grid 4 1 1} -- wviewer::graph_props has exactly THREE formals with the third named `grid`; wviewer::plot_signals has exactly FOUR; wviewer::plot_dbs_arm and plot_dbs_take both exist. STAGE J DOES NOT NEED TO TOUCH EITHER: the sweep already travels on wviewer::add_trace's 7th `sweep` parameter and through the wviewer::plot_sweeps_arm / plot_sweeps_take one-shot channel, which ships unarmed with zero callers (derived: pipeline 6). Watched green -- ran the suite, 90 checks ALL PASS.
  - WD4 of tests/headless/test_calc_wave_dest.tcl (HCASES), check at line 1306: expects {7 sweep db} -- wviewer::add_trace has SEVEN formals, the 7th named `sweep` and the 6th `db`. This is the parameter stage J actually uses, so it is a pin stage J must respect rather than move. Watched green.
  - GT8 of tests/headless/test_wave_grid.tcl -- graph_props has 3 args, 3rd named `grid`, with default 1 (lines 185-189). ** UNREGISTERED: in neither hcases nor dcases (derived, pipeline 7), so it gates NOTHING and a 5-arg change would only show in full_audit.sh.** Ran it anyway: tests/headless/run_suites.sh --nogui test_wave_grid -> ALL PASS (275 checks), so it is green-but-ungated today.
  - BM05 of tests/headless/test_wave_sigbrowser.tcl (line 2173) -- pins plot_signals' four-parameter signature as a LITERAL SOURCE STRING: [string first "proc wviewer::plot_signals {token exprs {colors {}} {destover {}}}" ...]. The hazard the contract records: a 5-argument call raises "too many arguments" into browser_plot_ids' own catch, which SWALLOWS it, so every browser gesture check would read as "the gesture did nothing" rather than as an error. ** ALSO UNREGISTERED.** Ran it: ALL PASS (135 checks).
  - Six 4-parameter `proc wviewer::plot_signals {token exprs {colors {}} {destover {}}}` spy stubs, derived by grep: test_ase_current_repair.tcl:305 (UNREGISTERED, ran it: ALL PASS 51 checks), test_calc_plot.tcl:731 (DCASES only), test_wave_sigbrowser.tcl:1135 and :2411, test_wave_sigbrowser_digital.tcl:1678, test_wave_sigbrowser_sea.tcl:519 (all UNREGISTERED). A fifth formal breaks each stub silently rather than loudly.
  - S24 of tests/headless/test_calc_skeleton.tcl (DCASES ONLY) -- the closed `returns` vocabulary {scalar wave bool scalar/wave scalar/list} (line 2555); the eight category counts {56 26 12 4 3 3 4 108} (line 2574); `All` as the union {108 108}; and calc::fn_fields == {name category route returns insert help} (line 2534). ** STAGE J NEEDS NO WIDENING: `scalar/list` already covers cross's list and `scalar/wave` already covers dutyCycle, frequency and freq, so the vocabulary is the one thing this stage was built not to move.** Watched green on its real arm -- env -u DISPLAY run, 573 checks ALL PASS.
  - MT11 of tests/headless/test_calc_measure.tcl (HCASES), check at line 2393: expects [list 1 {name category route returns insert help} 108 {}] -- the fn_fields schema row on the counted arm, so the six-field schema is pinned twice (once per arm). Watched green, 160 checks.
  - MT11 of tests/headless/test_calc_measure.tcl (HCASES), check at line 2626: expects the EXACT composed call {rpn {v(sq) 2 *} level 0.5 cycle 2 dataset 0 xaxis mid} from calc::arg_values for dutyCycle. A key or formal added to calc::dutyCycle_scalar (for instance a destination argument) reddens this literal. The sibling row at 2633 pins cross's composition as {rpn {v(sq) 2 *} level 0.5 nth 3 edge falling}. Watched green.
  - MT11 of tests/headless/test_calc_measure.tcl (HCASES), check at line 2563: expects {4 {}} -- exactly four enum fields across the four specs, each offering exactly the members its own validator tests against ({rising falling either}, {start number mid}). A fifth verb's enum field moves the 4. Watched green.
  - S28/4 of tests/headless/test_calc_skeleton.tcl (DCASES ONLY), check at line 4281: expects [list 1 {{v(out) v(in) -} 0.375 3 falling} 0] -- the recorder stub is BUILT from `info args ::calc::cross_scalar` with a sentinel default per formal, so the recorded argument list is an arity pin on calc::cross_scalar, and $::AD_RAWCALLS == 0 pins that the click never reaches the raw calc::cross. Watched green on the display arm (573 checks).
  - test_calc_measure MT10, check at line 2112: expects [list $verbs {refused marker refused marker refused marker}] -- all THREE verbs are pure delegates on calc::cross and must carry a stubbed cross's own sentence THROUGH. A stage-J result path that composed its own sentence instead of propagating reddens it. Watched green.
  - tests/headless/test_results_select.tcl redefines `proc calc::status {{msg {}} {record 1}}` (line 1985) -- an arity pin on calc::status, which calc::fn_measure's every exit calls. ** UNREGISTERED** (neither list), so it gates nothing; not run.
  - tests/headless/test_ase_window.tcl row W1m pins the Tools->Calculator -command as the bare `calc::open`. ** UNREGISTERED**; not run.

### prose_copies
  - src/calculator.tcl, comment block above `calc::cross_msg` (lines ~2416-2427): enumerates the two destinations and names the waveform callers as `calc::delay` with nth = 0, `calc::dutyCycle_scalar`'s default cycle and the unbuilt `frequency`. ** THIS IS A SOURCE COMMENT AND IT OMITS `calc::riseTime`**, while the same paragraph claims the set is "enumerated mechanically -- by the enclosing proc of every `listdefer` call site, which is the only method that has been right about this count". Pipeline 1 shows four sites. Stage J retires this paragraph.
  - src/calculator.tcl, comment block above `calc::cross` (lines ~2871-2875): "this proc is the ONE caller of `listdefer` that waits on the LIST surface... The waveform destination's callers are `calc::delay` with `nth = 0` on either side, `calc::dutyCycle_scalar`'s default cycle and the unbuilt `frequency`." Source comment; ALSO omits riseTime.
  - src/calculator.tcl, comment block above `calc::riseTime` (lines ~2986-3003): the whole deferral rationale, including "would have to be REVERSED as user-visible behaviour once R410/R412's argument dialog can route a wave into `calc::wave_dest`; a deferral retires silently, which is why the sentence is shared in the first place." Stage J is that reversal.
  - src/calculator.tcl, comment block above `calc::delay` (lines ~3114-3122): "so this caller waits on `calc::wave_dest`, alongside `calc::dutyCycle_scalar`'s default cycle and the unbuilt `frequency`." Source comment; ALSO omits riseTime.
  - src/calculator.tcl, comment block above `calc::dutyCycle_scalar` (lines ~3287-3292): "which `calc::wave_dest` now builds, so what this wrapper is still waiting on is the CLICK (R410/R412, phase 5) and not the destination." Stage J is that click.
  - src/calculator.tcl, comment block above `calc::catalogue` (lines ~4721-4726): "`calc::cross_scalar` waits on the `Table` surface, `calc::delay`'s `nth = 0` and `calc::dutyCycle_scalar`'s default wait on `calc::wave_dest`". Source comment; ALSO omits riseTime. This is also one of the two src/ copies of the five-term `returns` vocabulary (line 4700).
  - src/calculator.tcl, comment block above `calc::fn_fields` (line 4596): the five-term `returns` vocabulary as `scalar | wave | bool | scalar/wave | scalar/list`. The SECOND and LAST src/ copy -- ** NOT the three that S24's own comment claims** (see next entry).
  - tests/headless/test_calc_skeleton.tcl, S24's comment at lines 2551-2553: "The same five words are enumerated in three places in src/calculator.tcl (`calc::fn_fields`' schema comment and `calc::catalogue`'s own, twice) and in spec section 7.2ab's R416 note, so widening is a four-site edit." ** THE COUNT IS NOT REPRODUCIBLE: grep finds TWO copies in src/calculator.tcl, not three** (pipeline 5). This is a count written in prose that no command confirms -- the `grep -c '#pragma'` failure class CLAUDE.md forbids -- and the task statement inherited it as "the calc::catalogue comment (TWICE)".
  - src/calculator.tcl, comment block above `calc::fn_measure` (lines ~5619-5622): "`nth` 0 reaches the surface wrapper and comes back deferred behind the one shared `calc::cross_msg listdefer` sentence; re-wording it here would redden four bands in two files that compare it by identity." Stage J changes what reaches this proc.
  - src/calculator.tcl, comment block above `calc::arg_surface` (lines ~5298-5306): "`calc::cross_scalar` AND NOT `calc::cross`. The raw proc answers `nth` 0 with SUCCESS and a LIST and has no deferral, so a click that reached it would put a list where R404 wants one number." R419 now says the list IS the answer for nth = 0, so the reason this proc exists needs restating rather than deleting.
  - src/wave_viewer.tcl, comment block above `wviewer::plot_sweeps_arm` (lines ~7721-7741): "** DECLARED: NOTHING ARMS IT YET.** The Calculator's click wiring (R410/R412) is phase 5's, and `calc::wave_dest`'s own caller will be the first armer." ** MECHANICALLY CONFIRMED TRUE TODAY** (pipeline 6: zero callers in src/, zero references in tests/) and ** MADE FALSE BY STAGE J**. No row asserts the zero, so nothing reddens -- which also means the armed path ships with no coverage at all.
  - src/wave_viewer.tcl lines ~4812-4820 and ~4018: `calc::wave_dest`'s two columns as the viewer sees them, and the WD4 fence reference. Both describe a destination nothing yet plots.
  - tests/headless/test_calc_measure.tcl, the MT11 band header at lines ~2213-2220: "AND the surface wrapper `calc::dutyCycle_scalar` is `{rpn level {cycle 0} {dataset 0}}` -- it has NO `xaxis` formal at all and forwards four arguments... So the row below that checks every key against the SURFACE proc's formals is RED FOR THAT REASON TOO, and it is red on purpose." ** STALE AND SAYING THE OPPOSITE OF THE TREE: the shipped proc is `{rpn level {cycle 0} {dataset 0} {xaxis start}}` (PLAN 5.4 gave it one) and the row is GREEN.** Verified by reading the shipped formals at src/calculator.tcl:3325 and by running the suite.
  - tests/headless/test_calc_measure.tcl, declared hole H9 at lines ~505-511: "`calc::dutyCycle_scalar` CANNOT CARRY R420's X AXIS, and MT11's surface-formals row is red for that reason as well as for the absent spec." ** SAME STALE CLAIM, second copy.**
  - tests/headless/test_calc_measure.tcl, the MT11 CHECK NAME at line 2498: "...** `calc::dutyCycle_scalar` TAKES NO `xaxis`**, which its own shipped comment declares is waiting for exactly this caller, so the dialog cannot offer R420's axis until the wrapper can carry it". ** THIS IS THE WORST OF THE THREE, because it is a check NAME, it is GREEN, and it tells a future reader the opposite of what the tree does** -- the "a row's name must describe its method, not its coverage" defect wearing a third face.
  - tests/headless/test_calc_skeleton.tcl, the S28/1 band header at lines ~4027-4028: "today a click on `cross` prints `function cross: not implemented (phase 5)` and `cross` IS implemented, with 187 gating checks, as are the other three with 135." ** 135 IS STALE -- test_calc_measure measures 160 today** (PLAN 5.4 moved it), and the "today a click prints..." premise is the very condition the row below now asserts is gone. A count in a comment that an instrument recomputes every run.
  - tests/headless/test_calc_wave_dest.tcl header, line 34: "...default, `delay` with nth 0 on either side, and the unbuilt `frequency`" -- the same three-not-four omission, inside the suite whose own WD9 row derives the set as four.
  - doc/claude/specs/calculator.md line 687 (section 7.2ab, the R416 note): the five-term vocabulary. Lines 573, 584 and 585 carry the per-verb `returns` cells (`cross` scalar/list with the R419 note, `dutyCycle` and `frequency`/`freq` scalar/wave). Line 681: "was established by enumerating every `listdefer` call site mechanically, which is the only method that has been right about this count".
  - doc/claude/calculator_batch/DESTINATION_CONTRACT.md section 1, lines 11-13: names THREE waveform callers (dutyCycle_scalar's default, delay nth = 0, unbuilt frequency) and one list caller. Its own section (h) at lines 494-501 records that riseTime joined on 2026-10-03 and that WD9 reddened to announce it. Read the row, not either paragraph.
  - doc/claude/calculator_batch/TIMING_CONTRACT.md lines 45-57: states the three-caller count, then corrects it to four and says explicitly "The count is left wrong above on purpose... ** Do not quote any number here**; band `WD9` of tests/headless/test_calc_wave_dest.tcl derives the set every run, which is the only method that has been right about it." This is the one prose copy that is self-aware and should be left exactly as it is.

**current_green_counts**: All nine Calculator suites measured today on this tree (HEAD ff49a92f, fluid-editing), plus the three unregistered arity-spy suites. Every figure below I RAN; none is quoted from CLAUDE.md or a receipt.

=== THE COUNTED ARM -- 5 calc suites, `hcases` ALONE (derived: sed -n '27,120p' tests/run_regression.tcl, 96 entries; dcases is lines 682-704, 24 entries) ===
  tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross
    PASS | test_calc_wave_dest       RESULT: ALL PASS (90 checks)
    PASS | test_calc_measure         RESULT: ALL PASS (160 checks)
    PASS | test_calc_cross           RESULT: ALL PASS (187 checks)
  tests/headless/run_suites.sh --nogui test_calc_engine test_calc_scratch_reuse
    PASS | test_calc_engine          RESULT: ALL PASS (265 checks)
    PASS | test_calc_scratch_reuse   RESULT: ALL PASS (54 checks)
  Note test_calc_measure is 160, not the 135 that two shipped comments still quote; and
  test_calc_scratch_reuse is 54, not 53, because row SR5 was widened for the destination producer.

=== THE DCASES-ONLY SUITES, UNDER --nogui -- this is the blind spot, measured ===
  tests/headless/run_suites.sh --nogui test_calc_skeleton test_calc_widgets test_calc_buffer test_calc_plot
    PASS | test_calc_skeleton        RESULT: ALL PASS (0 checks)
    SKIP | test_calc_widgets         (self-skipped: no X -- nothing ran)
    SKIP | test_calc_buffer          (self-skipped: no X -- nothing ran)
    SKIP | test_calc_plot            (self-skipped: no X -- nothing ran)
    RESULT: 1/1 runs passed (3 skipped)
  So a crew running headless measures ZERO of S24, S28, CW13/CW14, PL5c, PL8 or PL9. Those four
  suites are in `dcases` ALONE -- they are not in `hcases`, so T1's --nogui loop never runs them at
  all, and the figures above are what a crew sees if it tries.

=== THE SAME FOUR ON THEIR REAL ARM (env -u DISPLAY, which run_suites.sh attached to the persistent
    dev display :99 with GUI_GATE=0 -- the user's 172.20.160.1:0 screen was never touched) ===
  env -u DISPLAY tests/headless/run_suites.sh test_calc_skeleton test_calc_widgets
    PASS | test_calc_skeleton        RESULT: ALL PASS (573 checks)
    PASS | test_calc_widgets         RESULT: ALL PASS (259 checks)
  env -u DISPLAY tests/headless/run_suites.sh test_calc_buffer test_calc_plot
    PASS | test_calc_buffer          RESULT: ALL PASS (130 checks)
    PASS | test_calc_plot            RESULT: ALL PASS (105 checks)
  573 / 259 / 130 all match the PLAN 5.4 figures; test_calc_plot at 105 is a figure CLAUDE.md does
  not carry.

=== THE THREE ARITY-SPY SUITES THAT PIN plot_signals / graph_props -- GREEN BUT UNGATED ===
  tests/headless/run_suites.sh --nogui test_wave_grid test_wave_sigbrowser test_ase_current_repair
    PASS | test_wave_grid            RESULT: ALL PASS (275 checks)   <- row GT8
    PASS | test_wave_sigbrowser      RESULT: ALL PASS (135 checks)   <- row BM05
    PASS | test_ase_current_repair   RESULT: ALL PASS (51 checks)    <- row CU238's 4-arg stub
  All three are in NEITHER `hcases` nor `dcases` (derived, pipeline 7): they pass today and gate
  nothing on either arm. Of the 23 suites that touch plot_signals or graph_props, only FOUR are
  registered -- test_calc_wave_dest and test_calc_scratch_reuse (hcases), test_calc_plot and
  test_wave_viewer (dcases). ** So the only gate-visible arity pin on plot_signals and graph_props is
  WD4 of test_calc_wave_dest.** The other spies would fail in full_audit.sh alone.

No full T1 was run (the task forbids it). No product, test, spec or CLAUDE.md file was edited; no
commit, no gate, no owed.sh touch. The dev display was left as found.

### dcases_blind_spots
  - S24 of tests/headless/test_calc_skeleton.tcl IN ITS ENTIRETY -- the closed `returns` vocabulary {scalar wave bool scalar/wave scalar/list}, the eight category counts {56 26 12 4 3 3 4 108}, the `All`-is-the-union {108 108} rows, the no-duplicate-name rows and the calc::fn_fields six-field schema. MEASURED: test_calc_skeleton reports `RESULT: ALL PASS (0 checks)` under --nogui, so a crew can only lift S24's predicates and evaluate them by hand. Only the gate's display arm runs them. Stage J should not need to move the vocabulary -- `scalar/list` and `scalar/wave` already spell both destinations -- but if it does, S24 is the arm that proves it.
  - S28/0 check at line 4018, {30 4 {}} -- the 30 route-T catalogue names with no proc against the 4 with one. This is the row a built `calc::frequency` reddens, and NO headless row covers it: MT11's three sibling literals (2408, 2424, 2474) are the counted-arm half of the same claim, so the two halves must be moved together or the gate reddens on the arm nobody watched.
  - S28/1 check at line 4049, {4 {}} -- no built verb is told it is not implemented. Same frequency sensitivity, display arm only.
  - S28/2, S28/3 and S28/4 -- the REAL pointer gesture on a route-T browser entry, the Cancel-leaves-the-buffer-byte-identical five-capture row, and the recorder/counter pair built from `info args ::calc::cross_scalar` with its {{v(out) v(in) -} 0.375 3 falling} / AD_RAWCALLS == 0 expectation. Every one drives real Tk (toplevel, grab, tkwait, event generate) and exists only on the display arm. If stage J touches calc::cross_scalar's formals or the click's result path, this is where it is measured.
  - S28/E check at line 4614 -- with no window a route-T click is a silent no-op that RETURNS, opens no dialog and enters no tkwait. Its own name declares it PARTLY VACUOUS on the red run, so even on the display arm it is a weaker fence than it reads.
  - CW13 of tests/headless/test_calc_widgets.tcl -- the `allowed` -command first-word list, the "exactly fifteen controls wired to a landed phase-2 proc" count, and "no ENABLED control is silent". MEASURED: the suite self-skips under --nogui ("no X -- nothing ran"), so wiring R606's `Table` control for cross_scalar's LIST surface is a change only the gate's display arm can see. CW14 (the argument dialog's widgets) is in the same position.
  - PL5c, PL8 and PL9 of tests/headless/test_calc_plot.tcl -- the wviewer::plot_signals failure-path stub (a 4-parameter redefinition), PL8's "calc::plot_rpn does name wviewer::plot_signals" non-vacuity row, and PL9's `calc::dest_*` glob asserting an exact literal proc list. WD10 of test_calc_wave_dest names PL9 explicitly as one of the two globs a `calc::dest_new` would redden; CE8 (the sibling glob) is in `hcases` and visible, PL9 is NOT. The suite self-skips under --nogui.
  - Every row of tests/headless/test_calc_buffer.tcl (130 checks on the display arm, self-skips headless). It is the phase-2 behaviour fence for the buffer the measurement result lands in, so a stage-J change to how a wave result reports itself in the buffer or status line is gated only there.
  - A SECOND KIND OF BLIND SPOT, not a dcases one and worth separating: the arity pins GT8 (test_wave_grid), BM05 (test_wave_sigbrowser) and CU238's 4-arg stub (test_ase_current_repair), plus the stubs in test_wave_sigbrowser_digital and _sea, are in NEITHER `hcases` nor `dcases` -- derived, pipeline 7. They are not display-only; they are run by NOTHING in T1, on either arm. Only full_audit.sh globs them. A fifth plot_signals parameter would therefore pass a clean gate and break five green suites silently, which is why WD4 of test_calc_wave_dest (hcases) exists and is the one pin a gate can see.
  - A THIRD: wviewer::plot_sweeps_arm / plot_sweeps_take have ZERO references in tests/ (pipeline 6). Stage J is their first armer, so the armed one-shot path has no coverage on any arm, registered or not -- that is a hole to fill rather than a blind spot to declare.

