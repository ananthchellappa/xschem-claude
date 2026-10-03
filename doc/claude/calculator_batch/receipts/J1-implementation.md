# Unit J1 -- the shape guard's rows, the implementation, and an independent verification
Three crews. `guard:rows` wrote band MT12 red-first and found a SEQUENCING HAZARD that
changed one step of the producer's spec. `impl:j1` implemented both halves and weakened
nothing -- proven by arithmetic over the diffstat. `verify:j1` re-measured everything in its
own worktree, reproduced the red BYTE FOR BYTE (22 rows, `diff` empty) and re-ran five
sabotages against the finished code.


## guard:rows

**arity_pins_checked**

THE KEY-SET PIN -- WIDENED DELIBERATELY, AND THE SEQUENCING WAS MEASURED IN BOTH DIRECTIONS.

`tests/headless/test_calc_wave_dest.tcl`, band WD11, the key-set row (the one the previous crew declared would "redden naming the new key"). It asserted the answer's key set EXACTLY as
  {absent dataset db dest msg n ok sweep type value xname yname}
and now asserts
  {absent dataset db dest msg n ok shape sweep type value xname yname}
Its NAME was extended to say the widening is the router's doing and why an explicit declaration is required ("...plus the one key the SURFACE routes on -- WIRING_CONTRACT section 4's `shape`, WIDENED HERE DELIBERATELY by the unit that added the router rather than left to be noticed, because the surface must read the shape off an explicit DECLARATION and inferring it from the value's list length would mis-route a legitimate one-cycle waveform into the buffer..."). Verbatim red against the unmodified tree:
  -> {{absent dataset dest msg ok value} {} {} NOKEY-db absent same} (exp {{absent dataset db dest msg n ok shape sweep type value xname yname} tmp {} named registered same}) : FAIL
It GAINS a key and loses nothing: still exact, still the row that reddens if a wiring puts the live destination in `dest`, and now additionally the row that reddens if a producer builds a destination and says nothing about its shape.

⚠⚠ MEASURED SEQUENCING HAZARD, AND IT CHANGES ONE STEP OF J1's SPEC. I ran a producer that merges `{db type xname yname n}` WITHOUT `shape` (scratch `j1_noshape.tcl`): `test_calc_wave_dest RESULT: 1 FAILED (101 passed)`, the single failure being this row, printing the 12-key set against the 13-key expectation. And a producer that DOES declare it (`j1_only.tcl`, producer only, no router): `test_calc_wave_dest OVERALL: ok (102 checks) / ALL PASS (102 checks)`, with `test_calc_measure` at `8 FAILED (162 passed)` -- the eight MT12 rows the guard closes. SO:
 * J1's step 1 must merge `{db type xname yname n}` PLUS `dict set r shape wave`. The previous receipt's `ready_for_implementation` step 1 says "merge EXACTLY {db type xname yname n}"; that is now one word short.
 * The widened key-set row and the `shape wave` merge must land in the SAME commit. Measured both ways: the row ahead of the producer is a gate red for a key nothing sets; the producer ahead of the row is a gate red for a key the row does not expect.
 * Band MT12 must land in J1b's commit, NOT J1's -- it is 8 standing reds on a producer-only tree.
The band's own comment in `test_calc_wave_dest.tcl` now records this, so nobody meets it as a gate red.

EVERY OTHER PIN I TOUCH OR COULD TOUCH, each RUN rather than read:
 * MT10's `mt_dictsites` (`test_calc_measure`, expects exactly `{mt_asanswer mt_stub_run}`): my band builds its probe answers in `sk_ans` with `list` plus `dict set`, never `dict create` -- band MT11's own measured precedent. MT10 is not in the red run's failure list and is green under the simulated J1b.
 * WD9's derived partition (`wd_wiredcallers`, pattern `calc::wave_dest[^A-Za-z0-9_]` over every `::calc::*` body, expects `{dutyCycle_scalar}`): the router's body names `calc::wave_dest` NOWHERE, so it cannot enter that set.
 * WD10's `calc::dest_*` exact-literal row: the new proc is `calc::fn_sink`, NOT `dest_*`. Checked for the same reason `calc::wave_dest` was not named `dest_*`.
 * SR5 of `test_calc_scratch_reuse` -- the `$viaviewer == {plot_rpn}` ONE-NAME literal and the four-way `minters`/`adders`/`readers`/`deleters` equality: the router names no `wviewer::*`, no `xschem raw add|value|del`, no `calc::tmpvec` and no `calc::rpn_bad_token`. RUN against the simulated J1b: `ALL PASS (54 checks)`.
 * CE8 (`test_calc_engine`) and PL9 (`test_calc_plot`) glob `eval_*`/`rpn_*`/`plot_*`/`dest_*` PROC NAMES and assert `>=` floors plus "names `.calc` implies names `has_win`". `fn_sink` matches none of the four globs, and names no `.calc` anyway. `test_calc_engine` RUN against the sim: `ALL PASS (265 checks)`.
 * MT11's arity row (`calc::fn_fields` still the six ruled fields, 108 catalogue rows, every row arity 6) and MT10's closure rows: no catalogue entry, no new field, and `fn_sink` is in no verb's callee-ward closure. Green in the red run and under the sim.
 * `wviewer::plot_signals` (4 formals, pinned as a LITERAL SOURCE STRING by BM05) and `wviewer::graph_props` (3 formals, GT8 + WD4's `{3 grid 4 1 1}`): NOT TOUCHED. This unit adds no viewer call of any kind.
 * S28/D's `grab` sweep over `[info procs ::calc::*]` (`>50` procs, no `-global`, at least one local `grab set`): `fn_sink` names no `grab`, so neither list moves.
 * CB2 of `test_calc_buffer` (`edit canundo|canredo` in exactly `{::calc::buf_can ::calc::edit_can_probe}`): the router names neither.
 * S24's `>72`-character bound is on `calc::fn_reason`, NOT on `calc::arg_msg`, so three new `arg_msg` arms are swept by nothing. See `counted_arm_only` -- this is a real measured gap I am declaring, not closing.

THE THREE COUNTED SUITES I DO NOT TOUCH, run on the UNMODIFIED product AFTER my edits (`env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_cross test_calc_engine test_calc_scratch_reuse`): `ALL PASS (187)`, `ALL PASS (265)`, `ALL PASS (54)`, `RESULT: 3/3 runs passed`. Same three under the simulated J1b: 187 / 265 / 54, all ALL PASS.

PUBLISHED CHECK COUNTS THE IMPLEMENTER MUST RE-DERIVE (a count is an instrument's output, not a baseline):
  test_calc_measure    160 -> 170  (+10: the ten MT12 rows)
  test_calc_wave_dest  102 -> 102  (UNCHANGED: the key-set widening moved an EXPECTATION, not a row)
T1 TRAILER: both suites are already in `hcases`, so the registration delta is zero. Census over each suite's real output before and after, with `summarize_all`'s own shapes: lowercase `^skip:` 0, uppercase `^SKIP:`/`^SKIPPED:` 0, `^RESULT:` lines 1, counted shapes 0, for both suites both ways. So cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines, not with the counts inside them. I did not run T1; the driver reads the trailer.

**counted_arm_only**

WHAT HALF TWO CONTAINS THAT THE COUNTED ARM CANNOT OBSERVE -- THE ACT, NOT THE DECISION -- AND IT IS DECLARED DISPLAY-ONLY RATHER THAN QUIETLY LEFT OUT.

Three things, all for one mechanical reason: `calc::fn_measure` returns early on `calc::has_win .calc.buf` and so does `calc::buf_set_number`, so under `--nogui` BOTH are no-ops and nothing a `--nogui` run can drive reaches either body.

 1. THAT THE RPN BUFFER IS REALLY LEFT UNTOUCHED on a wave answer. `.calc.buf` does not exist headless; `buf_set_number` returns `{}` before it reads or writes anything, so a run cannot tell a guarded paste from an unguarded one by looking at the buffer. MEASURED, not assumed: the `R_unasked` sabotage -- the router present and `fn_measure` keeping its unconditional `set num [calc::buf_set_number $v]` -- reddens exactly ONE row in either suite, MT12's structural act row, which catches it STRUCTURALLY (`-> {fn_measure atleast1 has}`). Nothing behavioural sees it.
 2. THAT THE SENTENCE REALLY REACHES `.calc.status.msg`. `calc::status` returns `{}` before it writes the widget or records the history, for the same reason. What MT12 measures is the COMPOSER (`calc::arg_msg`, pure) -- that a sentence exists, is in the house shape and names the destination -- never the delivery.
 3. THAT THE UNDO IS STILL ONE STEP. R421 part 3's `-autoseparators` pair is inside `buf_set_number`; a wave answer must not touch it at all, and that claim is only askable with a real text widget.

THESE THREE BELONG TO band S28 of `tests/headless/test_calc_skeleton.tcl` (which already rides `calc::fn_click`'s own return value in S28/4 for exactly this kind of claim) and band CW14 of `tests/headless/test_calc_widgets.tcl`, both `dcases` ALONE -- so only the gate's DISPLAY arm verifies them and a `--nogui` number proves nothing about any of them. I wrote NO display row: this unit's brief is the counted arm, and the display arm is the driver's gate.

⚠ WHAT I DID NOT LEAVE ON TRUST. Of half two, the DECISION and the SENTENCE are both fully on the counted arm, which is the whole reason the routing predicate was factored out instead of branching inside `fn_measure`. Nine of ten MT12 rows are red against the unmodified tree and all ten are green under a simulated J1b, with zero `UNEXPECTED ERROR:`, zero `BGERROR:` and zero `ABORTED` in any run. The one part of the ACT that text can honestly answer IS fenced: no proc in `::calc::` reaches `calc::buf_set_number` without naming `calc::fn_sink`, derived over the namespace in one walk.

⚠ ONE MEASURED GAP I AM DECLARING RATHER THAN CLOSING, and it is a display-arm obligation for J1b. `tests/headless/test_calc_skeleton.tcl` row S24 bounds a status-line sentence at 72 characters -- measured on the shipped 656x680 window, where `.calc.status.msg` is 613 px wide and a 94-character line rendered 85 characters and died mid-word. That row sweeps `calc::fn_reason` ONLY. NOTHING in the tree bounds `calc::arg_msg`, and the three candidate sentences measure 68, 78 and 67 characters with SHORT details -- so the `badshape` one is already over the bound before the detail grows, and its detail is a user-supplied token of unbounded length, as `badvalue`'s is the whole rejected value. A length row therefore cannot be written without first deciding a TRUNCATION policy, which nobody has. I did not duplicate S24's 72 into a second file (that is the figure-in-two-places defect this tree warns about); the right home is S24 itself, widened to sweep `arg_msg`, and that is a `dcases` edit. Named here so J1b meets it as a decision rather than as a cut-off sentence on the user's screen.

⚠ AND ONE LIMIT OF MY OWN PARITY ROW, measured rather than claimed. MT12's `calc::arg_msg` arm sweep is the only behavioural confirmation that no comment landed between two of its switch patterns. I drove both parities. An ODD-word comment (`# R419 applies`, 3 words) makes every arm raise and reddens three MT12 rows, printing Tcl's own *"extra switch pattern with no body..."*. An EVEN-word comment (`# R419 applies here`, 4 words) is a COMPLETE NO-OP: `test_calc_wave_dest ALL PASS (102)` and `test_calc_measure ALL PASS (170)`. The row's name says so in those words -- "A green run proves only that the word count is even" -- so the limit is in the verdict and not only in a receipt.


### new_rows

**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12 (new band, appended after MT11 so no existing band's order moves) -- hcases alone, counted arm

**name**

MT12 R404/R421 the routing decision is a PURE PROC with no Tk in it -- `calc::fn_sink` exists and its decommented body names none of winfo, tkwait, grab, toplevel, event generate, a .calc widget path, calc::has_win, the engine or the viewer -- which is the ONLY reason half two's decision can be measured on the counted arm at all: `calc::fn_measure` and `calc::buf_set_number` BOTH return early on `calc::has_win .calc.buf`, so anything left inside either is observable on a gate's DISPLAY arm and nowhere else.  The POSITIVE CONTROL rides along on both of those procs, because an empty hit list over a proc that does not exist is the same empty list

**red_output**

-> {0 NOPROC:calc::fn_sink has has has {}} (exp {1 {} has has has {}}) : FAIL

**discriminates_how**

This is the row that makes every other row in the band EVIDENCE rather than a claim, so it is first. The two positive-control legs are green TODAY and are what prove the scan is live: `sk_tkhits fn_measure` really answers `widget haswin` and `sk_tkhits buf_set_number` really answers `haswin`, so an empty hit list on `fn_sink` is a measurement and not an artefact of a blind regexp. The fourth control leg asserts `calc::fn_argspec` -- the precedent this factoring copies -- is itself clean. A guard implemented INSIDE `fn_measure` reddens the first two legs; one that reached for `winfo` or a `.calc` path to decide reddens the second.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 ...and the words it can answer are a CLOSED vocabulary, DERIVED from the proc's own literal `return` words and never listed in this file -- the method WD10's cross_msg arm sweep uses, because a hand-kept list is the same defect one level up and the one row on this batch that kept one drove a hand-kept list of message kinds against a proc that had grown more arms than the list named, with a name that claimed every arm.  The derivation does not invent a word the proc has no `return` for, which is the leg that keeps an empty failure list below from being an empty set

**red_output**

-> {NOPROC:calc::fn_sink missing} (exp {{badshape badvalue buffer destination refusal} missing}) : FAIL

**discriminates_how**

Kills `T_varreturn` -- a router that answers through a variable (`set out buffer ... return $out`), which is the shape that would make every derivation over the vocabulary silently vacuous. It prints `-> {{} missing} (exp {{badshape badvalue buffer destination refusal} missing})` and the sentence row beside it prints `{{} {}}`: so the vocabulary leg is what catches a derivation that has gone blind, which is why `[sk_vocab]` rides along as a leg of the sentence row too. It also names the dropped word for every router that loses a disposition: `L_length` prints `{badvalue buffer destination refusal}` and `N_nocheck` prints `{badshape buffer destination refusal}`.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 R404/R421 THE ROUTING DECISION, over every disposition that vocabulary admits: a declared WAVE goes to the destination; a declared SCALAR and an answer that declares NOTHING -- which is every verb that shipped before this stage -- both go to the buffer; a shape this build does not know goes NOWHERE; a buffer route carrying something that is not a literal number goes NOWHERE either, which is R404's own words and the half of hole H12 that calc::buf_set_number has no check for; and anything that is not a measured answer at all, a non-dict included, is a refusal.  FAIL CLOSED, so neither an unknown shape nor a non-number can reach the user's expression by falling through

**red_output**

-> {NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink} (exp {destination buffer buffer badshape badvalue badvalue badvalue refusal refusal refusal}) : FAIL

**discriminates_how**

The keystone, ten legs, one per disposition. Kills `N_nocheck` (no numeric check -- prints `buffer` where `badvalue` belongs THREE times: for a declared scalar carrying a list, for an empty value and for an answer with no `value` key at all, which is R404 violated three ways) and `O_openshape` (an unknown shape DEFAULTS to the buffer: `-> {destination buffer buffer buffer badvalue badvalue badvalue refusal refusal refusal}`, the third `buffer` being the token the build does not know). `L_length` reddens it too. Every answer is a WORD, so no reproducible number reaches the T1 verdict.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 ...and the decision is read OFF THE DECLARATION and never inferred from the value's LENGTH, asserted as the three cases where the two implementations disagree: a legitimate ONE-cycle waveform is a length-1 list and still goes to the DESTINATION, an EMPTY declared wave goes there too, and a declared SCALAR carrying a list goes NOWHERE rather than to the destination.  A router that tested the value's list LENGTH instead answers buffer, buffer and destination for those three, which is the rejected door of WIRING_CONTRACT section 4 and the same silent-wrong-buffer failure arriving by a second route; the multi-element declared wave rides along so the row is not three cases of one claim

**red_output**

-> {NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink} (exp {destination destination badvalue destination}) : FAIL

**discriminates_how**

Section 4's REJECTED DOOR, asserted positively in the run instead of described in a comment. Kills `L_length` (the router spelled as a list-length test), which prints `-> {buffer badvalue destination destination} (exp {destination destination badvalue destination})`: the one-cycle waveform is routed into the BUFFER -- the exact silent-wrong-buffer failure section 4 rejects the inference for -- the empty wave becomes a `badvalue`, and the declared scalar carrying a list is plotted. Three legs move in three different directions, so the row says WHICH of the three a length router got wrong rather than that something was wrong. The fourth leg is the multi-element wave, where the two implementations AGREE, and it is there so the row is not a vacuous restatement of the row above.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 R507 every disposition that reaches the user has a SENTENCE, derived over the vocabulary rather than listed: each word calc::fn_sink can answer except `buffer`, whose sentence is R404's provenance line, and `refusal`, which carries the verb's own msg through unchanged by identity, answers a NON-EMPTY sentence in the house shape through calc::arg_msg -- so a SIXTH disposition added without one reddens here naming itself.  The WORDS are never asserted: they are unratified user-visible wording and a `rule` debt covers them

**red_output**

-> {NOPROC:calc::fn_sink NOPROC:calc::fn_sink} (exp {{badshape badvalue buffer destination refusal} {}}) : FAIL

**discriminates_how**

Derived over the vocabulary, so a disposition added later without a sentence reddens here NAMING ITSELF -- the method-not-coverage discipline, where the alternative (three literal `arg_msg` calls) would go stale the moment a fourth disposition landed. Kills `P_nosentence` (the `destination` arm present but not a sentence), which prints `{destination:nocolon:wave -> __calc_dest9}` inside the failure list, i.e. it names the word AND the shape defect. `buffer` and `refusal` are exempt and the exemption is in the row's own name with its reason, because a sentence of their own would redden MT7, MT8 and WD9, which compare the verb's `msg` BY IDENTITY. The house shape is asked of the VOCABULARY's members and not of every `arg_msg` arm, which is measured rather than lazy: the shipped `real`/`int`/`rpn`/`enum` arms are colon-less field sentences, so a sweep over every arm would be red on shipped prose nobody has ruled.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 ...and the sentence for the one disposition the user will actually see -- a measurement that was a wave and landed in a destination -- NAMES THAT DESTINATION and names the verb, which is the only thing about it this row asserts: one non-empty sentence in the house shape, matched as a GLOB against the name the answer itself gave, so no destination serial lands in the verdict and a RULING on the words reddens nothing here.  WD9's deferral row makes its claim the same way.  The non-vacuity leg is that a DIFFERENT destination name gives a different sentence, so the name is interpolated rather than decoration

**red_output**

-> {empty missing: missing: same} (exp {ok named named distinct}) : FAIL

**discriminates_how**

THE ROW NOTHING ELSE CATCHES. Kills `Q_noname` -- a sentence that is in the house shape, is non-empty, passes the derived sentence row above, and says *"went to a destination"* instead of naming it. It is the ONLY row in either suite that moves: `-> {ok {missing:Measured wave: dutyCycle went to a destination instead of the buffer.} named same} (exp {ok named named distinct})`, with BOTH the glob leg and the non-vacuity leg moving -- the latter because two different destination names give the identical sentence when the name is decoration. The row asserts the shape and the name and never the words, so the open ruling on the wording cannot redden it; that is WD9's own treatment of the shared deferral sentence.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 every calc::arg_msg arm -- DERIVED from the proc's own switch patterns and never listed here -- answers a non-empty sentence without raising, which is the only confirmation there is that no comment landed between two of its patterns: that balances the braces, satisfies `info complete`, and is PARITY-DEPENDENT, so an EVEN word count re-pairs the list into a silent no-op while an ODD one makes Tcl raise out of EVERY arm.  A green run proves only that the word count is even.  The arm this band's own vocabulary requires rides along, so the row is red until that arm exists rather than green over the ones that already do, and an unknown kind must still fall through to the empty string rather than raise

**red_output**

-> {{} missing has missing atleast7 {}} (exp {{} has has missing atleast7 {}}) : FAIL

**discriminates_how**

`calc::arg_msg` had NO arm sweep anywhere in the tree -- so the proc half two adds three sentences to was the one `switch` catalogue in the Calculator with no behavioural parse fence at all. Kills `U_commentarm` (`# R419 applies`, THREE words, ODD) which prints `{empty:RAISED real:RAISED int:RAISED rpn:RAISED enum:RAISED failed:RAISED nosurf:RAISED destination:RAISED badshape:RAISED badvalue:RAISED}` plus Tcl's own *"extra switch pattern with no body, this may be due to a comment incorrectly placed outside of a switch body"*, and it reddens two other MT12 rows at the same time. ⚠ MEASURED IN BOTH DIRECTIONS: an EVEN-word comment (`# R419 applies here`) is a COMPLETE NO-OP -- ALL PASS on both suites -- which is why the row's own name says a green run proves only that the word count is even. The arm set is DERIVED from the proc's switch patterns, never listed, so the three arms J1b adds are swept the moment they exist; the `destination` leg is what makes the row red-first rather than green over the seven arms that already pass.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 ...and the ONE thing about the act itself this arm can see: every proc in the namespace whose CODE names calc::buf_set_number also names calc::fn_sink, derived over the namespace in one walk with neither set listed here -- so a success arm that pastes into the user's expression without first asking where the answer goes reddens naming itself.  The paster set rides along as a lower bound, because an empty one would make the subset claim vacuous.  That the buffer is really left UNTOUCHED and that the sentence really reaches .calc.status.msg are display-only and are NOT measured by this band

**red_output**

-> {fn_measure atleast1 has} (exp {{} atleast1 has}) : FAIL

**discriminates_how**

THE ROW THAT STOPS THE WHOLE BAND BEING A FENCE AROUND NOTHING. Kills `R_unasked` -- the router written, the vocabulary derived, every sentence composed, and `calc::fn_measure` still ending in the unconditional `set num [calc::buf_set_number $v]`. It is the ONLY row in either suite that moves (`-> {fn_measure atleast1 has}`), and it names the offending proc. Derived in one walk over `[info procs ::calc::*]` on DECOMMENTED bodies, so a comment mentioning either name cannot satisfy it and a second paster added later cannot hide from it. The subset is asserted with the paster count as a lower bound plus `fn_measure` by name, so an `info procs` answering nothing cannot pass it. It is structural and says so: the behavioural half is display-only.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 ...and what keeps `shape absent means buffer` honest, which is not this proc: every caller that builds a destination also DECLARES the shape, derived over the namespace as a SUBSET claim with a lower bound on the wired set rather than as an exact list -- so a future verb that answers a wave and forgets to say so reddens here naming itself, while units J2 and J3 wiring two more callers move no leg of this row.  The bound is why it cannot pass over an empty set, and the subset is why it does not have to be edited per caller

**red_output**

-> {{} only:0} (exp {{} atleast1}) : FAIL

**discriminates_how**

The default `shape`-absent-means-buffer is only safe if nothing can build a destination silently, and THIS is the row that makes that true rather than the router. Kills `S_silentwave` -- the producer merging the destination's keys and declaring nothing -- which prints `-> {dutyCycle_scalar atleast1} (exp {{} atleast1})`, naming the caller, while the key-set row in the sibling suite reddens on the same sabotage in the other file. ⚠ Note the red's SHAPE: the `sk_silent` leg is `{}` today, VACUOUSLY, because the wired set is empty -- and the `only:0` floor is exactly what catches that, which is why the bound is a leg of the same row and not a separate one. Written as a SUBSET with a floor rather than as an exact list on purpose: an exact `{dutyCycle_scalar}` would have to be edited by J2 and again by J3, and a floor that each unit lowers is not a floor.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT12

**name**

MT12 R402 this band mints nothing and loads no fixture -- it drives a pure routing predicate and a sentence table with no database read at all, so no `__calc_tmp*` and no `__mt_*` may appear in the inventory because of it

**red_output**

GREEN ON THE RED RUN, and declared as such rather than claimed as a fence. It is the only green row in the band, and the suite header's "which rows pass with no feature present" section now names it and says explicitly that the arm sweep's non-vacuity legs do NOT put that row in the list, because the row as a whole is red.

**discriminates_how**

It is the band's own hygiene statement and the same class as MT11's closing row: MT12 is the first band in this file that loads NO fixture at all, so the claim it makes is that a purely structural band cannot poison the bands before it or the inventory rows that cover them. A real fence for the implementation (a router or a sentence composer that reached for the engine would redden it along with the purity row) and vacuous against the feature's absence, which is stated rather than left to be noticed.


**red_proof**

ARMED SPELLING, repo root, PRODUCT UNTOUCHED. Transcript kept at /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J-wire-dest/j1b-guard/red_final.txt

  $ git diff --stat -- src/
  (no output -- src/ is byte-identical to HEAD)

  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
  test home: throwaway /tmp/xschem-test-home.3277350.pY9Hyq (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 12 FAILED (90 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 10 FAILED (160 passed)
  RESULT: 0/2 runs passed
  (exit 1)

So test_calc_measure is 170 checks, 10 of them failing: the nine new MT12 rows plus MT8's moved row from the producer half. test_calc_wave_dest is 102 checks and still 12 failing -- my key-set widening moved an EXPECTATION on an already-red row, not a row count.

FAIL TALLY OVER THE WHOLE RUN, by band: MT12 x9 (mine, new), MT8 x1, WD11 x9, WD9 x3 (all four of those the producer half's). NO OTHER BAND MOVED -- in particular MT10's `mt_dictsites` enumeration, MT11's arity row and WD10's `calc::dest_*` literal are all green.

THE NINE VERBATIM MT12 TAILS, in run order:

  MT12 -> {0 NOPROC:calc::fn_sink has has has {}} (exp {1 {} has has has {}}) : FAIL
  MT12 -> {NOPROC:calc::fn_sink missing} (exp {{badshape badvalue buffer destination refusal} missing}) : FAIL
  MT12 -> {NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink} (exp {destination buffer buffer badshape badvalue badvalue badvalue refusal refusal refusal}) : FAIL
  MT12 -> {NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink NOPROC:calc::fn_sink} (exp {destination destination badvalue destination}) : FAIL
  MT12 -> {NOPROC:calc::fn_sink NOPROC:calc::fn_sink} (exp {{badshape badvalue buffer destination refusal} {}}) : FAIL
  MT12 -> {empty missing: missing: same} (exp {ok named named distinct}) : FAIL
  MT12 -> {{} missing has missing atleast7 {}} (exp {{} has has missing atleast7 {}}) : FAIL
  MT12 -> {fn_measure atleast1 has} (exp {{} atleast1 has}) : FAIL
  MT12 -> {{} only:0} (exp {{} atleast1}) : FAIL

AND THE WIDENED KEY-SET ROW IN THE SIBLING SUITE:

  WD11 -> {{absent dataset dest msg ok value} {} {} NOKEY-db absent same} (exp {{absent dataset db dest msg n ok shape sweep type value xname yname} tmp {} named registered same}) : FAIL

EVERY ROW FAILED, NONE THREW: zero `UNEXPECTED ERROR:`, zero `BGERROR:`, zero `group ... ABORTED` in either transcript, and the bands kept measuring (160 of the 170 checks in test_calc_measure still passed). That is the issue-1616 trap, avoided by routing every product call through `sk_sink`/`sk_msg`/`pcall`, answering every word-valued leg from a PROC rather than a braced `expr` ternary, and keeping every `[` and `$` out of the check NAMES -- a `check` name is a double-quoted word, so a name quoting the rejected `[llength $value] > 1` spelling would have been COMMAND SUBSTITUTION. I wrote that name, measured the hazard and re-spelled it as prose.

AND THE GREEN SIDE IS REACHABLE, measured rather than asserted. A simulated J1+J1b -- producer declaring `shape wave`, plus `calc::fn_sink` as specified, three new `calc::arg_msg` arms, and `calc::fn_measure` branching on the router -- injected at suite FILE SCOPE with src/ still untouched:

  test_calc_wave_dest   OVERALL: ok (102 checks) / RESULT: ALL PASS (102 checks)
  test_calc_measure     OVERALL: ok (170 checks) / RESULT: ALL PASS (170 checks)
  test_calc_cross       ALL PASS (187)   test_calc_engine ALL PASS (265)
  test_calc_scratch_reuse ALL PASS (54)

TEN SABOTAGES, EVERY ONE CAUGHT, each by the row written for it (generators and transcripts under <scratch>/J-wire-dest/j1b-guard/sab/):

  L_length      section 4's REJECTED DOOR -- the router as a list-length test.  4 rows; the
                rejected-door row prints `{buffer badvalue destination destination}`, routing
                a one-cycle waveform into the BUFFER.
  N_nocheck     no numeric check: anything not a wave goes to the buffer.  4 rows; `buffer`
                where `badvalue` belongs three times.
  O_openshape   an unknown shape DEFAULTS to the buffer instead of failing closed.  3 rows.
  T_varreturn   the router answers through a VARIABLE, so no derivation can see its
                vocabulary.  2 rows, the vocabulary leg printing `{}` -- and this is the one
                that shows why `[sk_vocab]` rides along as a leg of the sentence row.
  P_nosentence  the `destination` arm present but not a sentence.  2 rows.
  Q_noname      a house-shaped sentence that does NOT name the destination.  ONE row, the
                destination-sentence row, both its legs moving.  Nothing else sees it.
  R_unasked     the router written and `fn_measure` never asking it.  ONE row, the structural
                act row, printing `fn_measure`.  Nothing else sees it.
  S_silentwave  the producer builds a destination and declares nothing.  ONE row in EACH
                suite: MT12's declaration row prints `dutyCycle_scalar`, and WD11's key-set
                row prints the 12-key set against the 13-key expectation.
  U_commentarm  an ODD-word comment between two `arg_msg` switch patterns.  3 rows, with
                Tcl's own *"extra switch pattern with no body"* in the output.
  V_evenarm     the SAME comment with an EVEN word count -- a COMPLETE NO-OP, ALL PASS on both
                suites.  Measured on purpose: it is the half a green run cannot rule out, and
                the parity row's own name says so.

PRODUCT UNTOUCHED AND NOTHING ELSE DONE.  `git diff --stat -- src/` empty; my two edited files are `tests/headless/test_calc_measure.tcl` (+388 lines: band MT12, its helpers and two header sections) and `tests/headless/test_calc_wave_dest.tcl` (the key-set row's expectation, that row's name, and the band comment recording the sequencing). Both pass `info complete`. The simulated implementation lives ONLY at <scratch>/J-wire-dest/j1b-guard/j1b_impl.tcl and was injected into scratch COPIES. Nothing committed, pushed or gated; NO full T1; the owed.sh ledger untouched; `~/dev/xschem-op-wcard`, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display` and `~/.claude/gui_test_gate` not written; `devdisplay.sh start|stop|view` never run and no `DISPLAY=:99` run made -- EVERY binary call carried `--nogui` AND `env -u DISPLAY`, so the user's 172.20.160.1:0 screen was never addressed. `/usr/bin/grep` throughout; no bare `xschem`. Scratch swept of its sim copies afterwards (`/tmp` is tmpfs here and charged to RAM): 6.0 MB down to 168 KB.

⚠ TWO THINGS IN THE WORKING TREE ARE NOT MINE. `doc/claude/issues/1641-...md` became modified and `doc/claude/specs/fluid_editing.md` / `tests/headless/test_fluid_editing.tcl` stopped being modified DURING my run -- another crew is working issue 1641 in this same checkout. I touched only the two files named above. Also `doc/claude/calculator_batch/receipts/J1-producer-suite.md` appeared untracked; that is the driver collecting the previous receipt.

⚠ THE CONTRACT STALENESS THE TASK ASKED ME TO NAME, AND IT HAS MOVED AGAIN. `WIRING_CONTRACT.md` section 2 says `calc::wave_dest` is *"built, gated at 90 checks"*. The task said the figure is 102 after the suite work; it is 102 today and `test_calc_measure` goes 160 -> 170 with my band, which section 5's table does not mention at all. I did NOT edit the document -- it is the driver's, and section 10's own policy is to keep superseded text as evidence.

⚠ UNRATIFIED USER-VISIBLE SENTENCE, FOR A `rule` DEBT. With the guard in place a click on `dutyCycle` at the default cycle builds a destination, leaves the RPN buffer untouched, and says:
    "Measured wave: dutyCycle went to __calc_dest3 instead of the buffer."
68 characters, house shape (capital, `: `, full stop), terse, names the verb and the destination. NO ROW ASSERTS ITS WORDS -- the rows assert one non-empty sentence in the house shape that names the destination, so the ruling cannot redden anything. Two further sentences are needed for the fail-closed dispositions and are equally unratified; I deliberately did NOT prescribe them, because the rows derive their requirement over the vocabulary rather than naming them. The candidates I measured are "Measuring $a: the result has a shape this build cannot place ($b)." (78 characters) and "Measuring $a: the result is not a literal number ($b)." (67) -- and see `counted_arm_only` for the 72-character status-line bound that nothing currently applies to `calc::arg_msg`.

NOTHING IS RUNNING NOW. No background job of mine is live; the scratch is swept; the two suite files are the whole deliverable and are red against the unmodified tree.

**routing_proc**

`calc::fn_sink {d}` -- ONE formal, the verb's whole answer dict. Answers ONE WORD of a CLOSED, FAIL-CLOSED vocabulary saying where that answer goes:

  destination  the answer DECLARES `shape wave`.
  buffer       the answer declares `shape scalar`, OR declares no `shape` at all -- which is
               every verb that shipped before this stage -- AND its `value` is a literal
               number by `calc::eval_finite`.
  badshape     the answer declares a `shape` this build does not know.
  badvalue     the route is the buffer and the `value` is not a literal number (missing,
               empty, a list, or non-finite).  R404's own words, and the half of hole H12
               that `calc::buf_set_number` has no check for.
  refusal      `ok` is not 1, is missing, or the answer is not a dict at all.

WHY FIVE AND NOT TWO: an unknown shape and a non-number each answer a word that is NEITHER `buffer` NOR `destination`, so neither can reach the user's expression by falling through. That is R420's own discipline one layer up -- `calc::dutyCycle` validates `xaxis` against a closed member list and refuses an unknown token rather than defaulting it.

WHY `shape` ABSENT MEANS `buffer`, AND WHY THAT IS NOT THE REJECTED INFERENCE: it is read from a KEY over a closed vocabulary, never from the data, so a one-cycle waveform (a length-1 list) still routes to the destination. What keeps the default honest is NOT this proc but a derived row -- every caller whose body names `calc::wave_dest` must also declare `shape wave` -- so a future verb that answers a wave and forgets to say so REDDENS instead of pasting a list. Section 4's rejected door (`[llength $value] > 1`) is asserted against positively in a row of its own, and the sabotage measurement is in `new_rows`.

PROOF IT NEEDS NO Tk, SO IT GATES ON THE COUNTED ARM -- MEASURED, NOT ARGUED. The body's only commands are `dict exists`, `dict get`, `set`, `if`, string comparison and `calc::eval_finite`, which is one `regexp` and nothing else. A derived scan over the DECOMMENTED body for `winfo`, `tkwait`, `grab `, `toplevel`, `event generate`, a `.calc` widget path, `calc::has_win`, `xschem ` and `wviewer::` answers the EMPTY LIST, and the same scan over `calc::fn_measure` answers `widget haswin` and over `calc::buf_set_number` answers `haswin` -- so the empty list is a measurement and not a blind regexp. That is row 1 of the band, with both positive controls as legs, and it is the reason the other nine rows are evidence rather than claims.

WHY A PROC AT ALL: `calc::fn_measure` and `calc::buf_set_number` BOTH return early on `calc::has_win .calc.buf`, so a shape branch left inside either is observable only on a gate's DISPLAY arm. Factoring the decision out is the same move that put `calc::fn_argspec` outside the dialog so MT11 could gate on both arms -- and that precedent's own body scans clean on the identical instrument.

NAMING, CHECKED AGAINST THREE DERIVED SETS RATHER THAN CHOSEN: `fn_*` is the route-T click's family (`fn_measure`, `fn_argspec`, `fn_click`, `fn_hover`, `fn_fields`). It is deliberately NOT `calc::dest_*`, which row WD10 of `test_calc_wave_dest.tcl` pins as an exact literal list, and not `plot_*`/`rpn_*`/`eval_*`, which rows CE8 and PL9 glob. The body names `calc::wave_dest` NOWHERE, so it cannot enter WD9's `wd_wiredcallers` set, and it names no `wviewer::*` and no `xschem raw`, so SR5's two viewer-door literals and four-way equality hold -- RUN, at 54 checks.

A SECOND, SMALLER ADDITION, and it is a table rather than a proc: `calc::arg_msg` -- already the one place every route-T sentence lives, already pure -- gains one arm per disposition that reaches the user. The rows derive that requirement OVER THE VOCABULARY, so they do not name the arms and a sixth disposition added without a sentence reddens naming itself.

⚠ ONE CONSTRAINT THE DERIVATION IMPOSES ON THE IMPLEMENTATION, stated as one in the row's own name: the vocabulary is read off LITERAL `return <word>` spellings in the body. A router that computed into a variable and ended `return $out` would redden the vocabulary row rather than be measured by a derivation that cannot see it -- sabotage `T_varreturn`, measured, prints `{}` for the vocabulary.



## impl:j1

**producer**

WHAT CHANGED IN `calc::dutyCycle_scalar` (src/calculator.tcl), following the previous crew's eight steps in order:

    proc calc::dutyCycle_scalar {rpn level {cycle 0} {dataset 0} {xaxis start}} {
        if {!([calc::eval_finite $cycle] && [expr {double($cycle) == 0.0}])} {
            return [calc::dutyCycle $rpn $level $cycle $dataset $xaxis]
        }
        set m [calc::dutyCycle $rpn $level 0 $dataset $xaxis]
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

Step by step: (1) the guard is INVERTED, so any non-zero or non-finite `cycle` is forwarded to `calc::dutyCycle` unchanged and the default cycle is the only arm that does anything new; the measurement's dict is returned STRAIGHT THROUGH when `ok` is 0, so a refusal and an absence each stay exactly what they are. (2) `sweep` FIRST, `value` second -- X before Y. (3) a destination refusal is propagated through `calc::cross_refusal` in the destination's own sentence. (4) EXACTLY `{db type xname yname n}` are merged, plus `dict set m shape wave` as the task's amended step 1 requires; `dest` is left holding the retired `__calc_tmp`, and `prev`/`prevtype` are NOT merged. (6) NO defensive point-count read-back and NO restore of my own -- `calc::wave_dest` already restores by name AND type. (7) NO drop on the success path; the undropped slot is the declared leak J1b/H11 owns.

The prose above the proc was rewritten (it claimed the wrapper still defers and was still waiting on the click), and the architecture, the key-set reasoning, the no-drop decision and the X-before-Y hazard are now recorded there.

⚠ CONFIRMATION THAT THE **WRAPPER** IS WIRED AND `calc::dutyCycle` IS NOT -- MEASURED, NOT READ. Derived over the live namespace on decommented bodies: `wired={dutyCycle_scalar}` and `declarers={dutyCycle_scalar}`, with `defcallers={cross_scalar delay riseTime}`. Then driven as a sabotage (`W_verbwired`): the destination build moved INTO `calc::dutyCycle`'s `k == 0` arm and the wrapper reduced to a pure forwarder. Result `2 FAILED (100 passed)` / `1 FAILED (169 passed)`, and the MT10 consequence is exactly the one the spec predicted:

  MT10 -> {{riseTime delay dutyCycle} {{} {} wave_dest}} (exp {{riseTime delay dutyCycle} {{} {} {}}}) : FAIL
  WD9  -> {{cross_scalar delay riseTime} dutyCycle {cross_scalar delay dutyCycle riseTime} atleast} (exp {... dutyCycle_scalar {cross_scalar delay dutyCycle_scalar riseTime} atleast}) : FAIL
  WD8  -> {{} {} 14 0} (exp {{} {} 1 0}) : FAIL

MT10's callee-ward closure prints `wave_dest` as an engine door the verb opened of its own; WD9's partition names `dutyCycle` where `dutyCycle_scalar` belongs; and WD8's leak row shows FOURTEEN registry slots, because every `dutyCycle` call in that band then mints a destination nobody drops. Zero anomalies in that run. So the wrapper choice is enforced by three rows in two suites, not only stated.

**guard**

THE ROUTING PROC, as implemented in src/calculator.tcl (new symbol `calc::fn_sink`, placed immediately above `calc::fn_measure`):

    proc calc::fn_sink {d} {
        set ok 0
        if {[catch {dict get $d ok} ok]} { return refusal }
        if {$ok ne {1}} { return refusal }
        set hasdecl 0
        if {[catch {dict exists $d shape} hasdecl]} { return refusal }
        set sh scalar
        if {$hasdecl} { set sh [dict get $d shape] }
        if {$sh eq {wave}} { return destination }
        if {$sh ne {scalar}} { return badshape }
        set v {}
        if {[catch {dict get $d value} v]} { return badvalue }
        if {![calc::eval_finite $v]} { return badvalue }
        return buffer
    }

Measured against the band's own derivations: vocabulary (read off the LITERAL `return <word>` spellings, never through a variable) `{badshape badvalue buffer destination refusal}`; Tk/widget/window-guard/engine/viewer hit list EMPTY, against the positive controls `fn_measure -> {widget haswin}` and `buf_set_number -> {haswin}`. Behavioural sweep over all twelve dispositions the band drives: wave->destination, scalar->buffer, no-declaration->buffer, unknown-shape->badshape, scalar-carrying-a-list->badvalue, empty-value->badvalue, no-value-key->badvalue, refused->refusal, absent->refusal, ONE-cycle wave->destination, EMPTY wave->destination, non-dict->refusal. No `switch` anywhere in it.

`calc::arg_msg` gained THREE arms and no comment inside the switch body (prose above the proc only):

    destination { return "Measured wave: $a went to $b instead of the buffer." }
    badshape { return "Measuring $a: that result shape cannot be placed ($b)." }
    badvalue { return "Measuring $a: the result is not a literal number ($b)." }

`calc::fn_measure`'s SUCCESS ARM, which was unconditionally `set num [calc::buf_set_number $v]`, is now an if/elseif ladder -- deliberately NOT a `switch`, the same choice `calc::dutyCycle`'s three-axis selector records -- and it FAILS CLOSED, because only the word `buffer` falls through to the paste:

    set sink [calc::fn_sink $d]
    if {$sink eq {destination}} {
        set db {}
        catch {set db [dict get $d db]}
        return [calc::status [calc::arg_msg destination $name $db]]
    }
    if {$sink eq {badshape}} {
        set sh {}
        catch {set sh [dict get $d shape]}
        return [calc::status [calc::arg_msg badshape $name $sh]]
    }
    if {$sink ne {buffer}} {
        return [calc::status [calc::arg_msg badvalue $name $v]]
    }
    set num [calc::buf_set_number $v]
    return [calc::status [calc::arg_provenance $name $vals $num]]

Derived sets after the change: `pasters={fn_measure}`, `askers={fn_measure}` -- so no proc reaches `calc::buf_set_number` without naming `calc::fn_sink`.

TWELVE SABOTAGES RUN AGAINST THE REAL PRODUCT (not a simulation), every one caught except the one declared no-op, zero `UNEXPECTED ERROR:` / `BGERROR:` / `ABORTED` in any run. Verbatim tails:

  L_length (section 4's REJECTED DOOR, the router as a list-length test) -- 4 MT12 rows:
    -> {buffer badvalue destination destination} (exp {destination destination badvalue destination})
    i.e. a legitimate one-cycle waveform routed into the BUFFER.
  N_nocheck (no numeric check) -- 4 MT12 rows:
    -> {destination buffer buffer badshape buffer buffer buffer refusal refusal refusal}
  O_openshape (unknown shape defaults to the buffer) -- 3 MT12 rows.
  T_varreturn (router answers through a variable) -- 2 MT12 rows, vocabulary `{badvalue buffer refusal}`.
  Q_noname (house-shaped sentence that does not name the destination) -- ONE row, both legs:
    -> {ok {missing:Measured wave: dutyCycle went to a destination instead of the buffer.} named same} (exp {ok named named distinct})
  R_unasked (router written, `fn_measure` never asking) -- ONE row: `-> {fn_measure atleast1 has} (exp {{} atleast1 has})`.
  S_silentwave (producer merges the keys, declares no shape) -- ONE row in EACH suite:
    WD11 -> {{absent dataset db dest msg n ok sweep type value xname yname} ...} (exp {... shape ...})
    MT12 -> {dutyCycle_scalar atleast1} (exp {{} atleast1})
  B_swapped (X and Y handed over in the wrong order) -- 3 WD11 rows naming every offending element.
  A_guardonly (deferral deleted, no destination built) -- 12 rows: WD9 x1 (`only:3`), WD11 x10, MT8 x1, MT12 x1.
  D_dropsuccess (drop on the success path) -- 8 WD11 rows.
  W_verbwired -- see `producer`.
  V_evenarm -- the DECLARED no-op, see `switch_comment_check`.

**green_proof**

COMMAND (repo root, every call carrying BOTH `--nogui` and `env -u DISPLAY`, so the user's 172.20.160.1:0 screen was never addressed):

  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse

VERBATIM, final tree, run twice with identical figures:

  PASS     | test_calc_wave_dest          run 1/5  RESULT: ALL PASS (102 checks)
  PASS     | test_calc_measure            run 2/5  RESULT: ALL PASS (170 checks)
  PASS     | test_calc_cross              run 3/5  RESULT: ALL PASS (187 checks)
  PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
  PASS     | test_calc_scratch_reuse      run 5/5  RESULT: ALL PASS (54 checks)
  RESULT: 5/5 runs passed
  (exit 0; zero `UNEXPECTED ERROR:`, zero `BGERROR:`, zero `ABORTED`, zero live-peer lines)

THE RED THIS REPLACED, same command on the two suites, `git diff --stat -- src/` EMPTY:

  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 12 FAILED (90 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 10 FAILED (160 passed)
  RESULT: 0/2 runs passed   (exit 1)

Failing bands in that red: WD9 x3, WD11 x9, MT8 x1, MT12 x9 -- and nothing else moved. Representative tails, verbatim:

  WD11 -> {refused NOKEY-db twonames notacount:{} {count=0 want=2 got={}} {count=0 want=2 got={}} tooshort:0 0} (exp {measured named twonames sized ok ok distinct 0}) : FAIL
  WD11 -> {{absent dataset dest msg ok value} {} {} NOKEY-db absent same} (exp {{absent dataset db dest msg n ok shape sweep type value xname yname} tmp {} named registered same}) : FAIL
  MT8  -> {refused 1 NOKEY-db measured ok NOKEY-db} (exp {measured 0 named measured ok NOKEY-db}) : FAIL
  MT12 -> {0 NOPROC:calc::fn_sink has has has {}} (exp {1 {} has has has {}}) : FAIL
  MT12 -> {NOPROC:calc::fn_sink x10} (exp {destination buffer buffer badshape badvalue badvalue badvalue refusal refusal refusal}) : FAIL
  MT12 -> {fn_measure atleast1 has} (exp {{} atleast1 has}) : FAIL
  MT12 -> {{} only:0} (exp {{} atleast1}) : FAIL

Raw per-suite captures taken EXACTLY as T1's `hcases` loop takes them (`env -u DISPLAY ./src/xschem --nogui --pipe -q --script <t>.tcl` under an armed throwaway HOME):

  test_calc_measure    OVERALL: ok (170 checks) / RESULT: ALL PASS (170 checks)   exit 0
  test_calc_wave_dest  OVERALL: ok (102 checks) / RESULT: ALL PASS (102 checks)   exit 0

and scored with the tree's OWN predicates out of `tests/banner_rule.tcl`: `banner_complete=1`, `banner_died=0`, `regression_case_failed 0 <body> = 0` for both.

**rows_weakened**

NO. I weakened, deleted and loosened NOTHING, and that is arithmetic rather than a claim.

I never opened either suite file with an editor. At the red baseline `git diff --stat -- tests/` read `999 insertions(+), 21 deletions(-)` across the two files (388 and 632 insertions). After all my work the full diffstat reads `1222 insertions(+), 54 deletions(-)` across three files with `src/calculator.tcl` at `223 insertions(+), 33 deletions(-)`: 1222 - 223 = 999 and 54 - 33 = 21, both exact. So the two suite files are byte-for-byte what the suite and guard crews left, and the ONLY file I changed is `src/calculator.tcl`.

`git status --short` at the end: ` M src/calculator.tcl`, ` M tests/headless/test_calc_measure.tcl`, ` M tests/headless/test_calc_wave_dest.tcl`, plus the five untracked entries that were already there before I started (`.claude/`, `.xschem/`, `receipts/J1-producer-suite.md`, `code_analysis/open_feature_build_survey_2026_09_30.md`, `sky130A/.../debug_st1/`). Nothing committed, nothing pushed, no T1 run, no `git stash`, owed.sh ledger untouched, `devdisplay.sh start|stop|view` never run, `~/dev/xschem-op-wcard` / `~/.xschem/ase_simulators` / `~/.claude/xschem_dev_display` / `~/.claude/gui_test_gate` not written.

Every sabotage run installed its copy over `src/calculator.tcl` and restored it from a snapshot, each restore verified with `cmp -s` before the next run; the final `cmp` against HEAD confirms the tree still carries the change and the suites are untouched.

**counts_rederived**

RE-DERIVED AT THREE TREE STATES, never preserved. Identical command every time:

  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure

(1) ALL THREE FILES AT HEAD (`git show HEAD:` copies swapped in, `git diff --stat` empty at that instant, all three restored afterwards and cmp-verified):
      PASS | test_calc_wave_dest   RESULT: ALL PASS (90 checks)
      PASS | test_calc_measure     RESULT: ALL PASS (160 checks)

(2) SUITES AS DELIVERED, src/ AT HEAD -- the red:
      FAIL | test_calc_wave_dest   RESULT: 12 FAILED (90 passed)     -> 102 checks
      FAIL | test_calc_measure     RESULT: 10 FAILED (160 passed)    -> 170 checks

(3) THE DELIVERED TREE:
      PASS | test_calc_wave_dest   RESULT: ALL PASS (102 checks)
      PASS | test_calc_measure     RESULT: ALL PASS (170 checks)

SO THE PUBLISHED CHECK COUNTS THE DRIVER CARRIES FORWARD:
      test_calc_wave_dest    90 -> 102   (+12, the suite crew's eleven WD11 rows plus the `ac`-order restore row)
      test_calc_measure     160 -> 170   (+10, band MT12)
Unmoved, run on the delivered tree: test_calc_cross 187, test_calc_engine 265, test_calc_scratch_reuse 54.

T1 TRAILER -- DERIVED with `summarize_all`'s own regexp shapes and `banner_rule.tcl`'s own predicates over REAL captured per-suite output, not predicted. I did NOT run T1.
Both suites are ALREADY in `hcases` (verified in `tests/run_regression.tcl`), so the registration delta is ZERO. Census on the delivered tree, per suite: lowercase `^skip:` 0, uppercase `^SKIP:` 0, `^SKIPPED:` 0, `^RESULT:` 1, `^OVERALL:` 1, counted shapes (`(FAIL|GOLD\?|RESULT\?)$|^FATAL`) 0, `banner_complete` 1, `banner_died` 0.
THEREFORE cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines, not with the counts inside them, and neither suite's line SHAPE changed. This is the PLAN 5.4 pattern again: a stage that moves two published check counts and not one trailer term. The driver reads the trailer.

⚠ A STALE PUBLISHED COUNT I DID NOT EDIT, named rather than left to rot: `tests/run_regression.tcl`'s registration comment for `test_calc_wave_dest` says *"both arms of that suite run the identical 88 checks"*. 88 is two stages stale (the figure is 102). The SHAPE claim is still true. It is the gate driver's file and its own count is the defect CLAUDE.md warns about, so the right fix is to drop the number rather than update it -- the driver's call, not mine. `WIRING_CONTRACT.md` section 2's *"built, gated at 90 checks"* is stale the same way and section 5's table does not mention `test_calc_measure`'s 170 at all; I did not edit that document either, per the task and per section 10's own keep-the-evidence policy.

**switch_comment_check**

I TOUCHED ONE PROC CONTAINING A `switch`: `calc::arg_msg`, which gained three arms. I added NO `switch` of my own -- `calc::fn_sink` and `calc::fn_measure`'s new branch are both if/elseif ladders, deliberately, which is the choice `calc::dutyCycle`'s three-axis selector already records for this exact reason. All explanatory prose went ABOVE the proc; there is no comment anywhere inside the switch body.

CONFIRMED BEHAVIOURALLY, THREE WAYS, AND A BRACE SCAN WAS NOT ONE OF THEM:

(a) THE ARM SWEEP IS DERIVED AND IT RAN. Band MT12 lifts the arm set out of `calc::arg_msg`'s own switch patterns -- never a hand-kept list -- and asks every one for a sentence. On the delivered tree it derives TEN arms, `{empty real int rpn enum failed nosurf destination badshape badvalue}`, every one answering non-empty without raising, with an unknown kind still falling through to the empty string, and the floor `atleast7` plus `has destination` / `has empty` / `missing __mt_no_such_arm__` legs beside it. That is the only behavioural confirmation that exists, and the three arms I added are swept by it the moment they exist rather than being taken on trust.

(b) I DROVE THE ODD PARITY AS A SABOTAGE. `U_commentarm` inserts `    # R419 applies` (THREE words, `#` included -- ODD) between the `nosurf` and `destination` patterns. Result `test_calc_measure 3 FAILED (167 passed)` with Tcl's own words in the output:
      MT12 -> {{empty:RAISED real:RAISED int:RAISED rpn:RAISED enum:RAISED failed:RAISED nosurf:RAISED destination:RAISED badshape:RAISED badvalue:RAISED} has has missing atleast7 {RAISED:extra switch pattern with no body, this may be due to a comment incorrectly placed outside of a switch body - see the "switch" documentation}} : FAIL
    plus two further MT12 rows. The FILE STILL PARSED and the suite still ran 167 checks -- the raise is at `switch` RUNTIME, which is precisely why `info complete` cannot see it.

(c) I DROVE THE EVEN PARITY TOO, AND IT IS THE HALF THAT MATTERS. `V_evenarm` is the SAME comment with one word added (`    # R419 applies here`, FOUR words -- EVEN): `test_calc_wave_dest ALL PASS (102 checks)` and `test_calc_measure ALL PASS (170 checks)`. A COMPLETE NO-OP. So a green run on my own tree proves only that the word count is even, never that a comment there would be safe -- and `info complete` answered `1` over the whole 5.9k-line file in BOTH parities, which is the measurement that says the brace scan is worthless against this shape.


### declared_holes

- CARRIED FORWARD, H12 IS NOW CLOSED ON THE COUNTED ARM BUT ONLY THE DECISION AND THE SENTENCE ARE: `calc::fn_measure` and `calc::buf_set_number` both return early on `calc::has_win .calc.buf`, so THREE claims about the ACT are display-only and I measured none of them -- that the RPN buffer is really left untouched on a wave answer, that the sentence really reaches `.calc.status.msg`, and that R421's one-step undo (`-autoseparators` inside `buf_set_number`) is untouched. They belong to band S28 of `test_calc_skeleton.tcl` and band CW14 of `test_calc_widgets.tcl`, both `dcases` ALONE. My brief forbade every non-`--nogui` call, so the gate's DISPLAY arm is the first thing that will verify them. What IS fenced of the act is one structural half: `pasters` == `askers` == `{fn_measure}`, derived over the namespace in one walk.

- ⚠ NOTHING BOUNDS A `calc::arg_msg` SENTENCE'S LENGTH, and this is the gap the guard crew handed J1b as a DECISION. Row S24 bounds a status-line sentence at 72 characters -- measured on the shipped 656x680 window, where `.calc.status.msg` is 613 px and a 94-character line rendered 85 and died mid-word -- but it sweeps `calc::fn_reason` ONLY. I shortened the `badshape` candidate from the receipt's 78 characters to 66 (`"Measuring $a: that result shape cannot be placed ($b)."`), and measured the other two at 68 (`destination`, with `__calc_dest3`) and 62 (`badvalue`, with a short value). ⚠ BUT THE `($b)` DETAIL IS UNBOUNDED: `badshape`'s is a user-supplied token and `badvalue`'s is the WHOLE rejected value, so a rejected 20-element list is a several-hundred-character line. No wording fixes that -- a TRUNCATION POLICY has to be decided first and nobody has. I did NOT duplicate S24's 72 into a second file (the figure-in-two-places defect); the right home is S24 itself, widened to sweep `arg_msg`, and that is a `dcases` edit. Also: `destination` reaches EXACTLY 72 at a five-digit serial (`__calc_dest99999`), measured.

- THE TWO FAIL-CLOSED DISPOSITIONS ARE UNREACHABLE THROUGH TODAY'S CLICK PATH, which I measured rather than assumed, and it bounds what the sabotages proved. `badshape` needs a verb declaring a shape this build does not know and `badvalue` needs a `scalar`/undeclared answer whose value is not a literal number; every shipped verb answers a scalar or a refusal, and `cross_scalar`'s nth 0 still defers. So both arms are a guard for a FUTURE verb, fenced structurally and behaviourally through `calc::fn_sink` but driven end-to-end by nothing. Their sentences are correspondingly the least exercised prose in the change.

- NO TRACE ON SCREEN. `wviewer::plot_sweeps_arm` still has ZERO callers, so the user gets a registered two-column database and no plot. That was J1b's other half in WIRING_CONTRACT section 6 and this unit did not do it: SR5's `$viaviewer == {plot_rpn}` one-name literal still holds (re-run at 54 checks), which is the row that makes arming the viewer a deliberate next choice rather than a free one.

- HOLE H11, UNRULED AND NOW OWNED BY WHOEVER ARMS THE VIEWER: who frees a destination the user is looking at. The destination is deliberately NOT dropped on the success path -- a trace resolves its database by registry NAME and `wviewer::restore` cannot re-read it -- so the undropped slot is a DECLARED LEAK. Sabotage `D_dropsuccess` reddened 8 WD11 rows, so the choice is fenced in both directions.

- PRE-EXISTING DEFECT, deliberately unfenced, needs its own unit: `calc::wave_dest_restore` puts back one half of a registry cursor that is a pair, so `xschem raw switch_back` after a successful destination lands ON THE DESTINATION. No row issues `switch_back` or reads `prev`/`prevtype`, and those keys are excluded from the answer's key set, so a row asserting it would be RED ON CORRECT J1 CODE.

- THREE UNRATIFIED USER-VISIBLE SENTENCES, needing a `rule` debt I am not permitted to file. The one a user will actually meet: "Measured wave: dutyCycle went to __calc_dest3 instead of the buffer." The other two are the fail-closed pair quoted above. NO ROW ASSERTS THEIR WORDS -- the rows assert one non-empty sentence in the house shape that names the destination and the verb -- so a ruling on the wording reddens nothing.

- THE DESTINATION'S USER-VISIBLE NAME IS STILL UNRULED: `__calc_dest<N>` appears in the Results picker (`results::list` filters by nothing) and the trace legend shows `calcx`/`calcy`. Every row reads those names OUT of the answer and matches `db` against a GLOB, so nothing pre-empts the ruling -- but the name is now on a user's screen, which it was not before this change.

- THE DISPLAY ARM WAS NOT RUN AT ALL (my brief forbade every call without `--nogui`/`env -u DISPLAY`). Instead I LIFTED the display-only suites' structural predicates and evaluated them against the live namespace headlessly: S28/D `{nproc=144 >50, global={}, localgrab=1}` -> `{1 {} 1}`; PL9/CE8's `plot_*|dest_*` set unchanged with `dest_*={dest_changed}`; CB2's `edit canundo|canredo` sites exactly `{::calc::buf_can ::calc::edit_can_probe}`; S24's `returns` vocabulary `{bool scalar scalar/list scalar/wave wave}` over 108 catalogue rows and `fn_fields` still the six ruled fields. All hold. That is a lift plus a probe, NOT the gate's arm, and is stated as such. The four `dcases` suites' own headless arms self-skip (`test_calc_skeleton ALL PASS (0 checks)`, the other three skipped by the runner), so they measured nothing.

- TWO POINTS IS STILL THE MOST THE COMMITTED `v(lp)`/`v(sq)` COLUMNS YIELD, carried forward from the suite crew: WD11's long-series row builds twenty points through the shipped RPN engine to get past that, but the duty ARITHMETIC on real committed data is still a two-point claim. Three points arrives with J2.

- I DID NOT SWEEP TWO EARLIER CREWS' SCRATCH, and `/tmp` is tmpfs here so it is charged to RAM: `<scratch>/J-wire-dest/j1-close` is 3.9 MB and `j1-rows` 1.9 MB, both cited by receipts that are not mine. My own `j1-impl` is 220 KB of transcripts with every sabotage copy and file snapshot deleted (13 MB down to 7.2 MB for the stage directory). The driver should decide whether the older crews' transcripts are still wanted.

- I WROTE NO RECEIPT FILE. The harness instruction for this crew forbids writing report `.md` files and says the parent reads the structured answer, which contradicts CREW_BRIEF's `receipts/<stage>-<role>.md` requirement. I followed the harness; if the ledger needs a receipt on disk, this schema is its content.

**user_visible**

WHAT A USER CAN NOW DO THAT THEY COULD NOT BEFORE

Open the Calculator, type an expression in the buffer, click `dutyCycle`, and leave the Cycle field at its default of 0 -- which means *all* cycles. Before this change that combination simply refused, with a sentence borrowed from a different verb: *"Cross: nth 0 answers every crossing and the buffer takes one number (R404), so a destination that can hold more than one has to come first."* A user who clicked `dutyCycle` was told about `cross` and about `nth`, neither of which they had asked for, and got no measurement at all.

Now it measures. Every complete cycle of the expression at the chosen level gets its duty fraction, and the whole series is written into a real two-column waveform database -- the duty fractions against whichever X axis R420's dialog offered (the time each cycle started, the cycle midpoint, or the cycle number). The RPN expression they typed is left exactly as it was, and the status line says, for example:

    Measured wave: dutyCycle went to __calc_dest3 instead of the buffer.

The second half of the change is a guard, and without it shipping the first half would have been WORSE for the user than today's refusal. A measured series is a list, and the click path pasted whatever came back straight into the RPN buffer with no check at all -- so the producer alone would have silently replaced the user's expression with a row of numbers. That is now impossible: the click asks where an answer goes before anything is pasted, and only a literal number ever reaches the buffer. An answer with a shape this build does not recognise, or a buffer-bound answer that is not a number, is refused in a sentence rather than pasted.

WHAT STILL DOES NOT WORK

* NO PLOT APPEARS. The database exists and is registered, but nothing draws it -- the viewer hand-off has no caller yet. A user has to go and find the result themselves through ASE-L's Results picker, where it shows up under the machine-generated name `__calc_dest3` with axes labelled `calcx` and `calcy`. Nobody has ruled what those should be called, and this is the first change that puts them in front of a person.
* THE RESULT IS NEVER CLEANED UP. Each default-cycle measurement leaves one more database behind for the session, on purpose: freeing it would destroy the very thing the user is looking at, and who should free it is an open question.
* THE OTHER THREE VERBS STILL REFUSE. `riseTime` and `delay` at their own "all occurrences" setting still give the old deferral sentence, `frequency` is still not implemented at all, and `cross`'s "all crossings" still waits on a table control that is a later phase.
* THE THREE NEW SENTENCES ARE MY WORDING, NOT RULED WORDING, and one of them can run long enough to be cut off on the status bar if the value it quotes is long -- there is no truncation rule yet.
* NOBODY HAS LOOKED AT ANY OF IT. Everything above is verified by tests on the headless arm; the claims that need a real window -- that the buffer is genuinely untouched, that the sentence genuinely lands on the status line, that one undo still puts the expression back -- are verified by the gate's display arm and not by me.



## verify:j1

**independent_rerun**

I RE-RAN EVERY COUNTED CALCULATOR SUITE MYSELF, TWICE, and did not quote the implementer's numbers.

COMMAND (repo root /home/analog/dev/xschem-claude, the armed spelling, `env -u DISPLAY` so the user's real Windows screen was never addressed):

  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse

RUN 1 (verbatim, <scratch>/J-wire-dest/j1-verify/rerun1.txt, exit 0):

  test home: throwaway /tmp/xschem-test-home.3288100.Y464EP (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  PASS     | test_calc_wave_dest          run 1/5  RESULT: ALL PASS (102 checks)
  PASS     | test_calc_measure            run 2/5  RESULT: ALL PASS (170 checks)
  PASS     | test_calc_cross              run 3/5  RESULT: ALL PASS (187 checks)
  PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
  PASS     | test_calc_scratch_reuse      run 5/5  RESULT: ALL PASS (54 checks)
  RESULT: 5/5 runs passed

RUN 2 (verbatim, rerun2.txt, exit 0, a different throwaway home /tmp/xschem-test-home.3291118.eGIYph): IDENTICAL five lines, `RESULT: 5/5 runs passed`.

ZERO anomalies across all ten capture files I produced: no `UNEXPECTED ERROR:`, no `BGERROR:`, no `ABORTED`, no `WATCHDOG`, no `couldn't execute`, no `exit 127`, and zero live-peer lines.

PER-SUITE CAPTURE TAKEN EXACTLY AS T1's `hcases` LOOP TAKES IT (I read the loop body at `foreach hc $hcases` in tests/run_regression.tcl first: `$xschem_cmd --nogui --pipe -q --script <t>.tcl`), under an armed throwaway HOME, then scored with the tree's OWN predicates sourced out of `tests/banner_rule.tcl`:

  test_calc_wave_dest  exit=0  OVERALL: ok (102 checks) / RESULT: ALL PASS (102 checks)
     lcskip=0 ucSKIP=0 SKIPPED=0 RESULT=1 OVERALL=1 countedshapes=0
     banner_complete=1 banner_died=0 regression_case_failed=0
  test_calc_measure    exit=0  OVERALL: ok (170 checks) / RESULT: ALL PASS (170 checks)
     lcskip=0 ucSKIP=0 SKIPPED=0 RESULT=1 OVERALL=1 countedshapes=0
     banner_complete=1 banner_died=0 regression_case_failed=0

⚠ THE DELIVERED `test_calc_measure` FIGURE IS 170 AND THE DRIVER'S OWN TASK TEXT SAYS 160. The task says *"Green is `ALL PASS (102 checks)` and `ALL PASS (160 checks)`"* -- that is the PRODUCER-HALF-ONLY figure. The delivered suite carries the guard band MT12 (ten rows), so the delivered green is 170, measured twice. Do not commit 160.

I did NOT run T1 (the driver gates). No commit, no push, no stash, no owed.sh, no devdisplay.sh start|stop|view.

**rows_weakened_audit**

NO ROW WAS WEAKENED. I did not take that on the implementer's arithmetic -- I reproduced the red byte for byte and then classified every hunk.

=== THE DECISIVE MEASUREMENT (this is the one that settles it) ===

In my own worktree at `/home/analog/j1v` (git worktree of HEAD 39355c22, a 14-character path, the main tree's built `src/xschem` copied in so the binary resolves XSCHEM_SHAREDIR to the worktree's own `src/`), I copied in ONLY the two delivered suite files and left `src/` at HEAD:

  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 12 FAILED (90 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 10 FAILED (160 passed)
  RESULT: 0/2 runs passed

So the delivered suites are red against the UNMODIFIED product: 90+12 = 102 and 160+10 = 170, reconciling with the green totals. An implementation that had turned a row green by editing it would show here as a shortfall in the red.

Then I compared my 22 failing-row detail lines -- title, actual AND `(exp {...})` -- against the GUARD CREW's own recorded pre-implementation red, left on disk at `<scratch>/J-wire-dest/j1b-guard/red_final.txt` BEFORE the implementer started:

  lines mine=22 theirs=22
  diff -> (no output)
  IDENTICAL: every failing row title, actual and expectation matches the guard crew's pre-implementation red BYTE FOR BYTE

That is independent of the implementer's narrative: 22 row titles and 22 expectation literals, unchanged. I also extracted the current MT12 band and diffed it against the guard crew's own `j1b-guard/mt12.tcl` -- byte-identical over all 311 lines (the only diff was a blank line at the opposite end, an off-by-one in my sed window).

=== EVERY HUNK IN `git diff -- tests/`, CLASSIFIED ===

`tests/` is 999 insertions / 21 deletions over two files. Full diffstat 1222/54 with `src/calculator.tcl` at 223/33; 1222-223 = 999 and 54-33 = 21, both exact.

tests/headless/test_calc_measure.tcl -- 7 hunks:
  1. @@ -391,0 +392,26   NEW BAND DOC (MT12 header index entry). Comment only, 0 check lines.
  2. @@ -419,0 +446,6   NEW: MT12's entry on the vacuity-exemption list. Comment only.
  3. @@ -664,0 +697,16  NEW HELPER `mt_destname`. 4 non-comment lines, a proc and not a ternary (stated reason: a braced `expr` with a command-substitution false branch raises *invalid bareword* and `group`'s catch would ABANDON the band).
  4. @@ -1890 +1938,23   MT8 D8: ROW DELIBERATELY INVERTED, NOT DROPPED. Old title asserted the surface DEFERS the wave case; new title asserts it NO LONGER defers. Legs went 4 -> 6: `{refused 1 measured ok}` -> `{measured 0 named measured ok NOKEY-db}`. STRICTLY MORE -- it adds the destination-name leg and the leg that a NAMED cycle carries no `db` key at all. WIRING_CONTRACT §5 names MT8 as a row that exists to pin exactly the behaviour this stage changes.
  5. @@ -1892,0 +1963   NEW: `pcall calc::wave_dest_drop $a` -- the band drops the destination the verb deliberately does not, so its own R402 row stays honest.
  6. @@ -1894 +1965,3   the MT8 expectation line, part of the same row as hunk 4.
  7. @@ -2636,0 +2710,311  NEW BAND MT12, 10 new check lines. Byte-identical to the guard crew's source.

tests/headless/test_calc_wave_dest.tcl -- 14 hunks:
  1. @@ -34,5 +34,13   PROSE CORRECTION of the suite header's three-caller sentence (§9's rot list: `frequency` out, `riseTime` in). Comment only. The suite's own header carried the rot its WD9 row never had.
  2-5. @@ -296 / -316 / -362 / -385   NEW BAND DOC + helpers for WD11. Comment and helper only, 0 check lines.
  6. @@ -967,0 +1047,191  NEW HELPERS for WD11 (89 non-comment lines). 0 check lines.
  7-8. @@ -1597 / @@ -1605,4   WD8 REPAIRED, which is §10(a)'s demand: fixture `v(sq)` -> `v(lp)`, and the row went from 4 legs to 8. `{measured measured ok ok}` -> `{measured measured ok ok distinct distinct distinct distinct}`, adding an all-distinct leg per column and a REVERSAL-rejection leg per column. STRENGTHENING, and it closes the blindness §10(a) measured (on `v(sq)` at L=1/3 the two duty fractions are the SAME DOUBLE, so the row passed against a column filled with element 0 or filled backwards).
  9-10. @@ -1633 / @@ -1642,4   WD9 row 1 INVERTED for the wired caller only: 8 legs in, 8 legs out, `{refused 1 refused 1 refused 1 refused 1}` -> `{refused 1 refused 1 measured 0 refused 1}`. The wired caller is STILL DRIVEN rather than dropped from the row, which is the honest move -- dropping it would leave nothing asserting it stopped saying the shared sentence. WD9 row 2 (pairwise identity) went 3 legs -> 4, adding the NEGATIVE half for the wired one: `{1 1 1}` -> `{1 1 0 0}`. STRENGTHENING.
  11-13. @@ -1655 / @@ -1656 / @@ -1660 / @@ -1662   THE DERIVATION WIDENED, not loosened: one walk now runs two regexps over the same decommented bodies, adding `wd_wiredcallers` via `calc::wave_dest[^A-Za-z0-9_]` (that character class is what keeps `wave_dest_answer`/`_refusal`/`_cur`/`_restore`/`_drop` out, or the union leg would be trivially true).
  14. @@ -1664,3 +1989,6   WD9's keystone row RE-DERIVED, exactly what §10(f) demanded and NOT decremented: 2 legs -> 4, `{{cross_scalar delay dutyCycle_scalar riseTime} atleast}` -> `{{cross_scalar delay riseTime} {dutyCycle_scalar} {cross_scalar delay dutyCycle_scalar riseTime} atleast}`. The non-vacuity floor is now over the UNION, so it HOLDS AT FOUR on both sides of every unit of stage J; wiring a caller MOVES it between sets instead of lowering a floor.
  15. @@ -1670,0 +1999,266  NEW BAND WD11, 12 new check lines.

=== ALL 21 DELETIONS ACCOUNTED FOR, INDIVIDUALLY ===
5 (stale three-caller prose) + 1 + 1 (MT8 title + expectation) + 1 (WD8 fixture line) + 4 (WD8 row) + 1 (WD9 r1 title) + 1 (WD9 r1 expectation) + 3 (WD9 r2) + 1 (WD9 derivation `if`) + 3 (WD9 keystone row) = 21. EXACT. Not one deleted row lacks a replacement, no tolerance was loosened anywhere (`WDTOL` untouched), no expectation was broadened, and no leg was removed without two more added in its place. The only thing LOOSENED in either file is a COMMENT that had quoted `ALL PASS (101 checks)` and now quotes the shape without the number -- the correct direction per CLAUDE.md.

=== AND THE PRODUCT DIFF HAS NO SCOPE CREEP ===
`git diff -U0 -- src/calculator.tcl` touches exactly four code sites: `calc::dutyCycle_scalar` (guard inverted), `calc::arg_msg` (three arms), the new `calc::fn_sink`, and `calc::fn_measure`'s success ladder. Every other hunk is comment. EXACTLY ONE proc added (`calc::fn_sink`), ZERO removed. Mechanically, over added/removed non-comment lines: `-command` 0 (CW13 cannot move), `wviewer::` 0 in code (SR5's viewer-door literals hold), `proc calc::dest_*`/`plot_*` 0 (PL9/CE8 hold), `catalogue`/`fn_fields` 0 in code (S24's 108 catalogue rows and the six ruled fields hold), `autoseparators` 0 (R421's one-step undo structurally untouched). The three greps that did hit `returns`/`wviewer::`/`catalogue` were all comment lines. Both suites are in `hcases` and NEITHER in `dcases`, so the registration delta is zero.

Final tree state is byte-for-byte what the implementer left; `src/calculator.tcl`'s md5 is unchanged by me and my worktree is removed.

**sabotage_resurvey**

FIVE SABOTAGES RE-RUN AGAINST THE IMPLEMENTED TREE in my own worktree (`/home/analog/j1v`, HEAD + the delivered suites + the delivered `src/calculator.tcl`, confirmed green there first at `ALL PASS (102 checks)` / `ALL PASS (170 checks)`). Each installed over `src/calculator.tcl`, run, then restored and `cmp`-verified. ALL FIVE STILL REDDEN. Zero anomalies in any run.

(1) CONSTANT-Y -- the one the driver named as costing the most to catch. One wrong index: the Y column built as element 0 repeated, same length, `foreach __e $__xs { lappend __ys [lindex $__vs 0] }`.

  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 3 FAILED (99 passed)
  PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (170 checks)

  THREE ROWS, FIVE LEGS -- exactly the cost the driver quoted, and I counted the legs rather than taking the figure:
   * WD11 two-point row, legs 6 and 7: `-> {measured named twonames sized ok {[1]off:{0.2999385393208259} rel=0.00012267928960900344} same 0}` (exp `{measured named twonames sized ok ok distinct 0}`) : FAIL
   * WD11 long-series row, legs 6 and 8: `-> {measured named sized atleast ok {[1]off:{0.4121560065252599} rel=0.0028797431727400256 ... [19]off:{0.4121560065252599} rel=0.03286758510649135} increasing same}` (exp `{measured named sized atleast ok ok increasing distinct}`) : FAIL -- nineteen named offending elements.
   * WD11 instrument-control row, leg 6: `-> {distinct distinct distinct distinct same distinct}` (exp `{distinct distinct distinct distinct same same}`) : FAIL
  ⚠ `test_calc_measure` CANNOT SEE IT (ALL PASS), so a wrong Y column is fenced in ONE suite only. That is a real bound on coverage and the WD11 rows are the whole fence.

(2) THE SURVIVING RESTORE VARIANT -- the type WRITTEN DOWN instead of carried. The delivered producer does no restore of its own, so I injected the exact line the driver named, after the shape declaration: `catch {xschem raw switch [dict get $h prev] tran}`.

  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 1 FAILED (101 passed)
  PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (170 checks)

  ONE ROW -- the `ac`-order row the suite crew added to close it, and the mechanism is visible in leg 3:
   * `WD11 ...and the user's own slot is read back BY TYPE rather than written down ... -> {measured named 1 ac tran 4 table registered}` (exp `{measured named 2 ac tran 4 table registered}`) : FAIL
  Current slot 1 (the `tran` slot the hardcoded type landed on) where the user's `ac` slot 2 belongs. CONFIRMED: without that one new row this sabotage is green on all 101 other checks, exactly as the driver described.

(3) THE COMPLEMENT, which I added because a one-sided pair is a vacuity risk -- the same line with `ac` written down instead:

  FAIL     | test_calc_wave_dest          run 1/1  RESULT: 2 FAILED (100 passed)
  -> the OTHER TWO WD11 rows (the three-slot `tran`-order row and its drop row).
  So the PAIR genuinely forbids any written-down type IN BOTH DIRECTIONS, measured -- which is what the suite's own comment claims and now has evidence for.

(4) THE ODD-PARITY SWITCH COMMENT -- re-surveyed because this batch's own lesson says the arm sweep is the fence that rots. Inserted `    # R419 applies` (THREE words, `#` included, ODD) between `calc::arg_msg`'s `nosurf` and `destination` patterns:

  info complete = 1        <- over the whole file. The brace scan is blind to this shape.
  FAIL     | test_calc_measure            run 1/1  RESULT: 3 FAILED (167 passed)
  RAISED:extra switch pattern with no body, this may be due to a comment incorrectly placed outside of a switch body - see the "switch" documentation

  And the delivered tree has ZERO comment lines inside `calc::arg_msg`'s switch body, derived over the proc body (`count=0`).

(5) §4's REJECTED DOOR -- `calc::fn_sink` rewritten as a list-length test (`if {[llength $v] > 1} { return destination }`), the inference WIRING_CONTRACT §4 rejects by name:

  FAIL     | test_calc_measure            run 1/2  RESULT: 4 FAILED (166 passed)
  PASS     | test_calc_wave_dest          run 2/2  RESULT: ALL PASS (102 checks)
  -> {buffer badvalue destination destination} (exp {destination destination badvalue destination})
  -> {destination buffer buffer buffer destination badvalue badvalue refusal refusal refusal} (exp {destination buffer buffer badshape badvalue badvalue badvalue refusal refusal refusal})

  The first tail is the whole point: a legitimate ONE-cycle waveform routed into the user's RPN BUFFER -- the silent-wrong-buffer regression arriving by the second door -- and MT12 names it.

**verdict**

GREEN AND HONEST.

The five counted Calculator suites are green on my own two independent runs at 102 / 170 / 187 / 265 / 54, scored with the tree's own `banner_rule.tcl` predicates, zero anomalies, zero live-peer lines. No row was weakened: the delivered suites reproduce the guard crew's recorded pre-implementation red BYTE FOR BYTE across all 22 failing-row lines, and every one of the 21 deletions in `tests/` is either a prose correction from §9's rot list or a row replaced by a strictly stronger or deliberately inverted one -- MT8 4 legs -> 6, WD8 4 -> 8 on the discriminating `v(lp)` column, WD9 pairwise 3 -> 4, WD9's keystone 2 -> 4 with the floor RE-DERIVED over the union rather than decremented. Five sabotages still redden, including both the driver named.

FIVE THINGS TO KNOW BEFORE COMMITTING, none of which blocks:

1. ⚠ THE DRIVER'S OWN TASK TEXT CARRIES A STALE GREEN FIGURE. It says green is `ALL PASS (160 checks)` for `test_calc_measure`; that is the producer half alone. The delivered suite is 170 (the guard band MT12 is ten rows). Measured twice.

2. ⚠ THE IMPLEMENTER'S SENTENCE-LENGTH FIGURE UNDERSTATES ITS OWN HOLE, and I measured rather than read it. It reports shortening `badshape` to 66 characters. With a realistic shape token that sentence is ALREADY OVER S24's 72-character bound: `"Measuring dutyCycle: that result shape cannot be placed (percentofperiod)."` is 74. `destination` reaches exactly 72 at a five-digit serial (confirmed), and `badvalue` with a 20-element rejected value is 319. The declared hole is real and already crossable, not merely crossable in principle. `badshape` is unreachable through today's click path, so no user can produce it today.

3. The two display-only halves are structurally fenced and behaviourally unfenced, exactly as declared. I checked the structural halves mechanically rather than by reading: zero `-command` added (CW13), zero `wviewer::` in code (SR5), no `calc::dest_*`/`plot_*` proc (PL9/CE8), no `catalogue`/`fn_fields`/`autoseparators` code change (S24, R421). The ACTS -- buffer untouched, sentence on `.calc.status.msg`, one-step undo -- are the gate's DISPLAY arm's to verify; my brief forbade every non-`--nogui` call.

4. CONSTANT-Y is fenced in `test_calc_wave_dest` ONLY; `test_calc_measure` is ALL PASS against it. The WD11 rows are the entire fence for a wrong Y column, which matters when J2 and J3 land.

5. Three stale published figures confirmed, none of them mine to edit -- listed in the driver section.

**for_the_driver**

WHAT TO CHECK BEFORE COMMITTING

1. The tree is clean of me. ` M src/calculator.tcl`, ` M tests/headless/test_calc_measure.tcl`, ` M tests/headless/test_calc_wave_dest.tcl` plus the five pre-existing untracked entries (`.claude/`, `.xschem/`, `doc/claude/calculator_batch/receipts/J1-producer-suite.md`, `doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md`, `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/`). Diffstat `1222 insertions(+), 54 deletions(-)` over three files, `src/calculator.tcl` at `223/33`. My git worktree at `/home/analog/j1v` is REMOVED (`git worktree list` is back to the five pre-existing `.claude/worktrees/` entries). No commit, no push, no stash, no T1, no owed.sh, no `devdisplay.sh start|stop|view`, nothing written in `~/dev/xschem-op-wcard`, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display` or `~/.claude/gui_test_gate`.

2. ⚠ DO NOT COMMIT 160 FOR `test_calc_measure`. The task text you wrote carries the producer-half-only figure; the delivered suite is 170.

3. A `rule` debt is still owed and neither the implementer nor I was permitted to file it: three unratified user-visible sentences (the one a user meets is `"Measured wave: dutyCycle went to __calc_dest3 instead of the buffer."`), plus the `__calc_dest<N>` / `calcx` / `calcy` names this change puts on a user's screen for the first time.

4. Neither of us wrote a receipt `.md` (harness instruction vs CREW_BRIEF's `receipts/<stage>-<role>.md`). This schema is the verification receipt's content.

5. Scratch: `<scratch>/J-wire-dest` is 7.1 MB, of which `j1-close` 3.9 MB and `j1-rows` 1.9 MB belong to earlier crews -- your call whether those transcripts are still wanted. `/tmp` is tmpfs at 752M of 7.7G, so no pressure, but it is charged to RAM for the session. My own `j1-verify` is 204 KB with every sabotage copy deleted.

THE EXACT PUBLISHED COUNTS FOR THE COMMIT MESSAGE (each re-derived by me at two tree states, never preserved)

  test_calc_wave_dest       90 -> 102   (+12)
  test_calc_measure        160 -> 170   (+10)

UNMOVED, measured on the delivered tree in both of my runs:

  test_calc_cross          187
  test_calc_engine         265
  test_calc_scratch_reuse   54

T1 TRAILER -- NO TERM MOVES. Both suites are already in `hcases` and NEITHER is in `dcases`, so the registration delta is zero. Census of each suite's real captured output, taken as the `hcases` loop takes it and scored with `summarize_all`'s own regexp shapes and `banner_rule.tcl`'s own predicates: lowercase `^skip:` 0, uppercase `^SKIP:` 0, `^SKIPPED:` 0, `^RESULT:` 1, `^OVERALL:` 1, counted shapes `(FAIL|GOLD\?|RESULT\?)$|^FATAL` 0, `banner_complete` 1, `banner_died` 0, `regression_case_failed 0 <body>` 0 -- for BOTH suites. THEREFORE cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0, since `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines and neither suite's line SHAPE changed. This is the PLAN 5.4 pattern again: two published check counts move and not one trailer term. I did NOT run T1 -- read the trailer.

THREE STALE FIGURES TO DECIDE ABOUT (your files, not mine to edit)

  tests/run_regression.tcl, the registration comment at line 140: *"both arms of that suite run the identical 88 checks"* -- 88 is two stages stale (102). The SHAPE claim is still true. Per CLAUDE.md the fix is to DROP the number, not update it.
  WIRING_CONTRACT.md line 43: *"built, gated at 90 checks"* -- the staleness your task told me to name rather than edit. Confirmed stale; the figure is 102.
  WIRING_CONTRACT.md line 105, §5's cost table: `test_calc_wave_dest ALL PASS (90)  test_calc_measure ALL PASS (160)` -- both figures now stale, and the table never mentioned `test_calc_measure` reaching 170.

ONE CORRECTION TO THE IMPLEMENTER'S RECEIPT WORTH CARRYING ONTO THE LEDGER: its sentence-length figure for `badshape` (66 characters) was measured with a short placeholder. With a realistic shape token the sentence is 74 and already over S24's 72-character bound. That STRENGTHENS its declared hole about there being no truncation policy -- and S24 itself, widened to sweep `calc::arg_msg`, is still the right home for the fix rather than a second copy of the 72.

