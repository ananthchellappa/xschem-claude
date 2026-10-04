# Unit J2 -- the red-first suite, three attacks, and the repair
TWO SABOTAGES SURVIVED and were closed by the repair stage:

  * `wrong-x` -- the WRONG PAIRING DIRECTION: drive the HIGH crossing list and pair each high
    with the last low BEFORE it, instead of driving the LOW list and pairing each low with the
    first high AFTER it. One point per completed TRANSITION where a rise time is one per
    rising EDGE. Nothing in nine suites caught it on either arm.
  * `absence-as-refusal` FORM 2 -- the absence guard on the two INPUT crossing lists instead of
    on the OUTPUT series. A complete, fully green J2 that still ships the `destempty` sentence
    for a signal that never crossed.

The `repair:j2` section's **ready_for_implementation** is the specification.


## suite:j2

**series_measured**

WHAT IT SHOULD ANSWER (per the J-recon `sites` entry for `calc::riseTime`): X = the list of LOW crossings, `calc::cross $rpn $llo 0 rising $dataset`; Y = for each `xlo`, the first element of `calc::cross $rpn $lhi 0 rising $dataset` strictly greater than it, minus `xlo`. I implemented exactly that as a derivation and drove it over EVERY column of the tran fixture at FIVE level pairs (10/90, 20/80, 30/70, 5/95, 40/60). Probe: `<scratch>/J2/rowsmith/p1.tcl`, `p2.tcl`, `p5.tcl`.

PER-COLUMN RESULT, with relative spread of each series (max-min over max |value|):

* `@m1[gm]`, `i(@m1[id])`, `i(@rdc1[i])`, `i(@rtop[i])` -- NOT MEASURABLE AT ALL through `calc::cross`. A one-element RPN list carrying a bracket is braced by Tcl and the engine refuses: `Cannot measure: unknown token '{@m1[gm]}'`. Five level pairs each, all refused. Worth passing on: these four columns are unusable as single-token RPNs for any `cross`-layered verb.
* `v(dcmid)` -- ONE point at four of the five levels (numerical wiggle around 3.0 V crossing once), ZERO at 5/95 (the one low crossing has no high after it). Flat.
* `v(div)` -- ONE point at every level. Monotone ramp/2.
* `v(ramp)` -- ONE point at every level. Monotone.
* `v(sq)` -- THREE points at every level. Y relative spread 4.34e-14 .. 4.61e-14 across the five levels; at 10/90 the three are {1.6000000000000758e-4, 1.6000000000000042e-4, 1.6000000000000562e-4}. X = {9.2e-4, 4.92e-3, 8.92e-3}, spread 0.897. **Y IS BLIND, X DISCRIMINATES.**
* `v(lp)` -- THREE points at every level. Y max-min spread 7.59e-4 .. 2.35e-3, which LOOKS adequate; it is not, and that is the finding. At lo=0 hi=1 10/90 the three are {0.0004106982258026196, 0.00040973182841977113, 0.00040973182841067164}: the ADJACENT pair (0,1) differs by a relative 2.36e-3 but the adjacent pair (1,2) differs by **2.22e-11**, inside a 1e-7 tolerance. The pole is in periodic steady state after the first edge. At 2/98 the (1,2) pair is 5.69e-13. So `wd_alldistinct`/`mt_alldistinct` answers `{distinct same}` on `v(lp)`, not `distinct`. **X discriminates (adjacent relative 0.804, 0.446); Y is adjacent-blind on its last pair at every level.**

CONCLUSION: on the committed fixture only two columns yield more than one point and **both are blind on Y** -- `v(sq)` wholly, `v(lp)` on its last adjacent pair. The max-min spread is the WRONG statistic here; the adjacent-pair spread is the one that matters, and this is issue 1643's finding arriving at a second verb from a direction the J1 receipt did not cover (J1 found `v(lp)`'s duty fractions DO discriminate; `v(lp)`'s rise times do not).

THE COLUMN I CHOSE, measured: the RPN `{v(sq) v(ramp) *}` at lo=0 hi=1 pctlo=10 pcthi=90. The ramp scales each edge, so against FIXED absolute thresholds the three edges have three different widths:
  Y = {1.466666666666655e-4, 3.200000000000078e-5, 1.7777777777776282e-5}  adjacent relative 3.58 and 0.80
  X = {9.200000000000001e-4, 4.9039999999999995e-3, 8.902222222222223e-3}  adjacent relative 0.812 and 0.449
Seven orders outside MTTOL/WDTOL. Both thresholds cross STRICTLY BETWEEN samples at all three edges (measured, `mt_allstrict`/`strict`). Nine other candidate expressions were measured and rejected -- `{v(sq) v(lp) +}` (adjacent 8.5e-13), `{v(lp) v(lp) *}` (3.9e-12), `{v(lp)}` at 2/98 (5.7e-13) are all blind; `{v(lp) v(ramp) *}` works (1.54, 0.506) and `{v(sq) v(div) *}` works (12.4, 0.80) but the chosen one is the only pair of columns whose product a row can derive in Tcl from two values the fixture README gives closed-form.

EVERY ROW CARRIES AN EXPLICIT DISTINCTNESS LEG, and the band's own control row asserts the instrument can still answer `same` -- over `v(sq)` (`same`) and `v(lp)` (`{distinct same}`) -- so the `distinct` above it is a measurement of the fixture and not a constant, and the two blind columns are NAMED by the row that would have been blind on them.

**three_points**

CONFIRMED BY MEASUREMENT. `calc::cross {v(sq)} 0.5 0 rising` answers 3 crossings; at the supplied-swing LOW threshold the row actually drives (`{v(sq) v(ramp) *}` at llo=0.1) `calc::cross` also answers 3, and the resulting rise-time series is 3 points with 0 drops. The band does not write "3" down anywhere: it reads the edge count back off `calc::cross` with a literal 0 and sizes every other leg against that, with an `mt_atleast ... 3` floor as the non-vacuity leg.

WHAT THE THIRD POINT BUYS, measured rather than argued -- and the honest list is SHORTER than the J1 receipt's wording suggests:

NOT new (two points already catch these, via the count leg): a stride (3->2 or 2->1), an off-by-one in the fill loop (3->2 or 2->1), a whole-series reversal of two elements.

GENUINELY NEW at three points, and each is a row:
1. **A DROPPED MIDDLE SAMPLE WHOSE COUNT SURVIVES.** At two points there is no middle to drop. `mt_midleft`/`wd_midleft` replaces the middle with its left neighbour, keeping the length; measured `distinct`. Sabotage `K_padded` -- a producer that pads a dropped point with the previous value -- is caught by exactly one row in the tree (MT9c's partial-drop row, `{n:3 want:2}` plus both element-wise legs naming the padded element) and by NOTHING in `test_calc_wave_dest`.
2. **A ROTATION TOLD APART FROM A REVERSAL.** Measured and asserted IN THE RUN: `[string equal [lreverse [lrange $Y 0 1]] [mt_rot1 [lrange $Y 0 1]]]` is **1** and `[string equal [lreverse $Y] [mt_rot1 $Y]]` is **0**. At two points a rotation IS the reversal, so a fence against one is a fence against both and there is nothing to separate; at three they are different lists.
3. **A WRONG INTERIOR WITH CORRECT ENDPOINTS.** `mt_midmean`/`wd_midmean` is what a producer that filled only the ends and interpolated writes: measured, the mean of the endpoints is 8.22e-5 against the real middle 3.2e-5, a relative 1.57. Invisible at two points by construction.
4. **A MIDDLE X OUT OF ORDER.** `wd_increasing` is TWO comparisons at three points and one at two, so `wd_increasing [wd_rot1 $rDX]` answers `notincreasing:2` -- an index that cannot exist in a two-point series. Asserted as a leg of WD13's third-point row.

Two rows (MT9c #6, WD13 #4) carry these four fills plus the unaltered series as a `same` control, so the row asserts its own discrimination every run rather than in a comment.

⚠ AND THE THREE POINTS COST SOMETHING J1's TWENTY-POINT SINE DID NOT: the series is derived THREE independent ways, not one. J1's hole H10 says its long series is "derived ONCE, from the columns, because the verb and the derivation are handed the identical expression string". Here the Y is also compared against `calc::riseTime` at nth 1, 2, 3 -- one scalar per edge, through the ordinal path bands MT2/MT4 already fence, sharing no code with the series arm -- and MEASURED to be byte-identical to the series. That is a derivation with no new code in it at all, which is strictly better evidence than a longer series through the same door.

**wrapper_decision**

YES, `calc::riseTime_scalar` IS REQUIRED, and it is a measurement rather than a copy of J1.

WHY IT CANNOT BE SKIPPED. `calc::wave_dest` issues `xschem raw add $yname {}`, so `mt_direct_raw wave_dest` answers `yes`. Row MT10's transitive-closure row walks callee-ward from the literal verb set `{riseTime delay dutyCycle}` and forbids any `::calc::` proc in those closures from issuing `xschem raw add|values|value|del`, `cross` alone excepted. DRIVEN as sabotage `I_wrong_layer` (the engine door inside `calc::riseTime`): MT10 prints `{{riseTime delay dutyCycle} {wave_dest {} {}}}` against `{{riseTime delay dutyCycle} {{} {} {}}}`, and WD9's partition row prints `riseTime` where `riseTime_scalar` belongs. The wrapper is invisible to MT10 because nothing in `riseTime`'s body names it -- exactly J1's `dutyCycle_scalar` measurement.

THE FORMALS MUST BE, IN THIS ORDER: `rpn {lo {}} {hi {}} {pctlo 10} {pcthi 90} {nth 1} {dataset 0}` -- `calc::riseTime`'s own signature, byte for byte, which is also `calc::fn_argspec riseTime`'s display order (`lo hi pctlo pcthi nth dataset`). MEASURED on five candidate shapes:

| wrapper formals | `arg_values` returned | what the proc RECEIVED |
|---|---|---|
| identical to the verb | all 7 pairs | `nth 0` -- correct |
| the 7 REORDERED (`nth` moved up) | all 7 pairs | `nth 0` -- also correct, because `arg_invoke` appends in the WRAPPER's own formal order |
| 7 + `dest` LAST | 7 pairs | `nth 0`, `dest {}` -- safe |
| 7 + `dest` in the MIDDLE | **only `rpn lo hi`** | **`nth 1`** -- the user's 0 silently replaced by the default |
| `nth` dropped as a formal | 6 pairs | the user's ordinal never passed at all |

So the TRUNCATION is real and silent: `calc::arg_values` walks `info args` in formal order and `break`s at the first formal it has no value for; `calc::arg_invoke` then appends positionally. A mid-list formal the dialog cannot answer truncates the call and everything after it falls back to a default. Reordering among the SEVEN is mechanically harmless (all seven are in `have`), but I pinned the verb's own order anyway, derived on both sides (`mt_sameformals [mt_formals riseTime_scalar] [mt_formals riseTime]`), so the row cannot rot into seven written-down names.

⚠ **MT11 IS BLIND TO THE TRUNCATING SHAPE, AND THAT IS NEW.** MT11's surface-formals row checks MEMBERSHIP only (`agnsurf` 21, `agbadsurf` {}). Measured: with `dest` inserted in the middle, all six keys are still formals, so MT11 is GREEN on the shape that silently delivers the wrong ordinal. MT9c's truncation row closes it on two probe surfaces it mints into `::calc::` and removes, printing `TRUNCATED-BEFORE:nth` and the delivered `1`. Sabotage `H_midformal` against the finished wrapper reddens MT9c's surface row with `differ:{rpn lo hi dest pctlo pcthi nth dataset}|{rpn lo hi pctlo pcthi nth dataset}`, `TRUNCATED-BEFORE:nth` and a sink of **`buffer`** instead of `destination` -- the user asked for every edge and got one number pasted into the buffer -- plus 8 rows in `test_calc_wave_dest`.

ALSO MEASURED, so the implementer does not have to: minting the wrapper moves NO other MT11 leg. `agnsurf` is 21 and `agbadsurf` {} both with and without it; `agnmand` is 12 both ways (all six riseTime formals carry defaults, so the mandatory-reachability loop skips them); `ag_verbs` is catalogue-driven and still `{cross delay dutyCycle riseTime}`.

ARCHITECTURE I CHOSE (and it is the dutyCycle precedent, not a third shape): `calc::riseTime`'s nth-0 arm COMPUTES the series and returns `value` = the Y list plus `sweep` = the parallel X, exactly as `calc::dutyCycle` already does for cycle 0; the deferral guard is REPLACED, not bypassed. `calc::riseTime_scalar` forwards any non-zero or non-finite `nth` unchanged, passes a refusal or an absence straight through, hands `sweep` then `value` to `calc::wave_dest` (**X FIRST**), propagates a destination refusal through `calc::cross_refusal`, merges exactly `{db type xname yname n}` and sets `shape wave`. The alternative -- leaving the deferral in `calc::riseTime` and intercepting in the wrapper -- was rejected on a measurement: it leaves `riseTime` in `wd_defcallers`, so WD9's union floor reads 5 and WD9's identity row stays GREEN, i.e. the keystone fence would not announce the stage.

**absence_decision**

TODAY: `calc::riseTime` with `nth` 0 never reaches the question -- issue 1639's guard defers first. With the guard replaced, the empty series is reachable TWO ways and a PARTIAL drop a third. All three measured:

* **SHAPE A -- no low crossing at all.** `riseTime {v(sq)} 100.0 200.0 10 90 0` -> llo=110, lhi=190, `nlow=0`, `nhigh=0`. `calc::cross` with `nth` 0 answers **SUCCESS with an EMPTY list** (`ok=1 absent=0 value={} dest=__calc_tmp1`), confirmed directly, so nothing upstream turns this into an absence.
* **SHAPE B -- low crossings exist, none has a high after it.** `riseTime {v(lp)} 0 1 10 99.95 0` -> llo=0.1, lhi=0.9995 (`v(lp)` peaks at 0.9991150350359748), `nlow=3`, `nhigh=0`, every point drops, series empty.
* **SHAPE C -- PARTIAL drop, which the driver's call does not cover.** `riseTime {v(lp)} 0 1 10 99.9 0` -> `nlow=3`, `nhigh=2`, series of **2**. Reachable, and it is the common real case (a transient that ends part way up its last edge).

So YES, the absence is reachable, by two distinct causes, and `calc::wave_dest`'s `destempty` would be reached in both.

I AGREE WITH THE DRIVER'S CALL AND IMPLEMENTED IT IN THE SIMULATION: the verb answers `calc::cross_absent` itself, so the empty list never reaches `calc::wave_dest` at all. Measured: `ok=0 absent=1`, `mt_disp` -> `absent`, and the surface passes it straight through with no `db` key.

⚠ ONE THING THE CALL DOES NOT SETTLE, AND I AM NOT INVENTING A SENTENCE FOR IT. Both reusable `calc::cross_msg` arms carry an ORDINAL that reads oddly for `nth` 0: `nohigh` gives *"Rise time: the 0th low crossing has no high crossing after it in this sweep."* and `absent` gives *"Cross: there is no 0th rising crossing..."*. I used `nohigh` with `[calc::cross_ordinal 0]` in the simulation and the ROWS DO NOT ASSERT IT. What they assert instead is derived and wording-free: the disposition is `absent`; the sentence is NOT `[calc::cross_msg destempty]` by identity; its FAMILY (the word before the first colon) is one `calc::cross_msg` itself builds, over an arm set lifted from the proc's own `switch` patterns, and is NOT `destempty`'s family; and the SURFACE answers the same absence with no `db` key. Whichever arm the implementation reuses, and whatever `calc_wave_dest_empty_result_sentence` is ruled to be, no row moves.

THE SURFACE LEGS ARE THE ONES THAT FENCE WHAT THE USER READS, and I only added them after measuring that the verb-level legs alone were not enough. Sabotage `J_destempty` (the absence branch deleted, so the empty lists go to `calc::wave_dest`): with verb-level legs only, the `db` leg read `NOKEY-db` and was GREEN, because a `destempty` refusal carries no `db` either. With the three surface legs added the row prints `... refused 1 samefamily:Destination` against `... absent 0 elsewhere` -- it names the defect exactly: the user reads a *"Destination:"* sentence where the truth is that the signal never crossed. Two rows catch it, both in MT9c; `test_calc_wave_dest` is ALL PASS under that sabotage, which is correct scoping.

SHAPE C IS J2's OWN DECISION, declared in the band comment rather than invented silently: **the point is DROPPED**, not padded and not a refusal. It follows from the driver's call applied once per point rather than once per request -- the series is one rise time per low crossing THAT HAS a high after it, and when every point drops the whole answer becomes the absence above. One rule, two outcomes. Refusing instead would refuse every transient that ends part way up its last edge; padding is sabotage `K_padded`, caught by exactly one row. The row carries a non-vacuity leg (`nlow` minus the series length is at least 1) so it cannot be satisfied by a fixture that simply had fewer edges, and it checks that the occurrence that did NOT complete is still the `absent` it always was.


### new_rows

**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c (new, between MT9b and MT10)

**name**

MT9c the edge count this band's rows are sized against is read back off calc::cross with a literal 0 rather than written down, and the fixture really has more than two rising edges at the LOW threshold a supplied swing names -- which is what makes the third-point rows below possible at all

**red_output**

GREEN ON THE RED RUN, declared. It measures `calc::cross` and the fixture, not `riseTime`. It printed `ok:` and is named in the band's own green-on-the-red-run declaration.

**discriminates_how**

It is the non-vacuity root of every `mt_sized` leg in the band: with a fixture regenerated onto a different grid, or a level pair that yields fewer edges, this row reddens with `only:<n>` and names the cause instead of letting eight rows below compare against a shorter list and still pass.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c R419/R416 riseTime with nth 0 MEASURES the per-edge series instead of deferring: one Y per rising edge and a PARALLEL X of the same length, both sized against the low-crossing count calc::cross answers rather than against a number, and the X is calc::cross's own low-crossing list element for element

**red_output**

-> {refused {n:1 want:3} {n:1 want:3} {count=1 want=3 got={NOKEY-sweep}} 0} (exp {measured sized sized ok 0}) : FAIL

**discriminates_how**

The keystone of the verb half. The X leg is `calc::cross`'s OWN answer, not a second derivation, so a producer that put the HIGH crossings, the midpoints or the rise times themselves on the X axis reddens naming every element -- a defect the Y derivation cannot see. Caught by sabotages A_guard_only (no sweep key), E_offbyone (`n:2 want:3`), H_midformal.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c T2 the series IS the scalar path, edge by edge: riseTime at nth 1, 2 ... up to the derived edge count each MEASURES one number, and those numbers are the nth-0 series element for element -- a derivation that runs entirely through the ordinal path bands MT2 and MT4 already fence, so it shares no code with the series arm

**red_output**

-> {measured sized refused} (exp {measured sized ok}) : FAIL

**discriminates_how**

The strongest of the three derivations because it introduces no new code: the comparand is the shipped scalar verb at nth 1..N, measured byte-identical to the series. A series assembled in the wrong ORDER, with a repeated element, or one short reddens here. Caught by C_consty, D_revy, E_offbyone.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c ...and a SECOND derivation with no engine in it agrees: the element-wise product of the two committed columns computed in Tcl, crossed at the two supplied-swing thresholds by this file's own D3+D4, gives the same Y and the same X -- and the engine's own product column agrees with the Tcl one, asserted in the run so the two derivations cannot silently become one. Both thresholds cross STRICTLY BETWEEN samples at every edge

**red_output**

-> {same refused {count=1 want=3 got={NOKEY-sweep}} strict strict} (exp {same ok ok strict strict}) : FAIL

**discriminates_how**

Closes J1 hole H10's cost (its long series is derived ONCE, through the same engine as the verb). The first leg asserts the engine/Tcl agreement IN THE RUN (measured 4.0e-16), so a change to either arithmetic says so instead of making the two derivations one. The `strict` legs make a snapping implementation impossible to pass.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c the series DISCRIMINATES, and the CONTROL is the two columns this band refuses to drive: every adjacent Y of the answer differs by more than MTTOL and so does every adjacent X, the X is strictly increasing over TWO comparisons rather than one -- and the SAME instrument over v(sq)'s own per-edge series answers `same`, while over v(lp)'s it answers one of each

**red_output**

-> {tooshort:1 tooshort:1 tooshort:1 same {distinct same}} (exp {distinct distinct increasing same {distinct same}}) : FAIL

**discriminates_how**

Issue 1643's trap answered head-on. The last two legs ASSERT IN THE RUN that the instrument can still answer `same` -- over `v(sq)` (all three edges agree to 4.5e-14) and `v(lp)` (last two agree to 2.2e-11) -- so `distinct` above is a measurement of this fixture and not a constant, and the two blind columns are named by the row that would have been blind on them. Caught by C_consty, D_revy.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c THE THIRD POINT, measured rather than argued: against the very same element-wise comparison the rows above lean on, the series REVERSED, ROTATED BY ONE, with its MIDDLE replaced by the mean of the endpoints, and with its middle replaced by its left neighbour are each distinct from the answer while the unaltered derivation is the same -- and the last two legs show WHY two points could not have said it

**red_output**

-> {distinct distinct distinct distinct distinct 1 0} (exp {distinct distinct distinct distinct same 1 0}) : FAIL

**discriminates_how**

The row that justifies the third point IN THE RUN: `[string equal [lreverse [lrange $Y 0 1]] [mt_rot1 [lrange $Y 0 1]]]` is 1 and the three-point version is 0, so a two-point series provably cannot separate a rotation from a reversal. Four wrong fills built FROM the correct series, so they cannot drift away from it. Four of its seven legs are satisfied by an absent feature (declared in the band comment); its red is the `same` leg.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c a low crossing with NO high crossing after it DROPS THAT POINT rather than refusing the series or padding it: the answer is shorter than the low-crossing list, equals the scalar path at the occurrences that DO complete, and the occurrence that does not is still the ABSENCE it always was -- with the non-vacuity leg asserting that a point really was dropped

**red_output**

-> {refused {n:1 want:2} atleast1 refused {count=1 want=2 got={NOKEY-sweep}} absent} (exp {measured sized atleast1 ok ok absent}) : FAIL

**discriminates_how**

The ONLY row in the tree that catches sabotage K_padded (a producer that pads a dropped point with the previous value): `{measured {n:3 want:2} atleast1 {count=3 want=2 got={... 0.0011120979237804448 0.0011120979237804448}} ...}` -- it names the duplicated element. `test_calc_wave_dest` is ALL PASS under that sabotage. The `atleast1` leg is the non-vacuity half: it asserts `nlow` exceeds the series length, so the row cannot be satisfied by a fixture with fewer edges.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c R402/D7 a swing the signal never reaches at all answers an ABSENCE and not a destination problem: the disposition is absent, the sentence is NOT calc::cross_msg destempty by identity, its family is one calc::cross_msg itself builds and is NOT destempty's family -- and the SURFACE answers the same absence, with no db key, so the empty list never reaches calc::wave_dest at all

**red_output**

-> {refused 0 known elsewhere ok sized NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 0 elsewhere} (exp {absent 0 known elsewhere ok sized NOKEY-db absent 0 elsewhere}) : FAIL

**discriminates_how**

The driver's call fenced without committing to wording. Sabotage J_destempty (the absence branch deleted) prints `{measured 0 unknown:NOFAMILY:{} elsewhere empty sized NOKEY-db refused 1 samefamily:Destination}` -- it names the defect exactly: the user reads a `Destination:` sentence where the signal never crossed. ⚠ The three SURFACE legs were added only after MEASURING that the `db` leg alone was green under that sabotage, because a destempty refusal carries no `db` either.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c ...and the OTHER empty shape, which is a different cause and therefore a second row: low crossings EXIST and not one of them has a high crossing after it, so every point drops and the series is empty -- same absence at the verb AND at the surface, same negative identity against destempty at both, same family claim, still no db key, with two non-vacuity legs

**red_output**

-> {refused 0 known elsewhere atleast1 sized NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 0 elsewhere} (exp {absent 0 known elsewhere atleast1 sized NOKEY-db absent 0 elsewhere}) : FAIL

**discriminates_how**

A SECOND row rather than more arguments to the first, because the two empty series have different CAUSES and an implementation can get one right and the other wrong. Its two non-vacuity legs (`nlow` at least 1, `nhigh` exactly 0) are what stop it being the row above wearing different arguments -- measured: nlow=3, nhigh=0.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c the FAMILY INSTRUMENT the two absence rows lean on, derived over calc::cross_msg's own switch patterns and never listed: the arm set is large, it builds more than two distinct families, destempty's family is one of them, a sentence with no colon in it answers a sentinel rather than a family, and two sentences from one family answer samefamily

**red_output**

GREEN ON THE RED RUN, declared. It measures the instrument and not the verb.

**discriminates_how**

The instrument control for the two absence rows: without it `elsewhere` could be a claim about a family that does not exist, and `known` could be vacuous over an empty family set. The arm set is DERIVED from `calc::cross_msg`'s own `switch` argument (measured: 36 arms, 7 families) rather than hand-kept -- which is the repair for the rot CLAUDE.md records, where a hand-kept arm list had drifted to 24 of 31 while green.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c R412 the click's SURFACE for riseTime is the new wrapper, and its formals are calc::riseTime's own DERIVED on both sides rather than seven names written down -- so a wrapper that dropped a formal, renamed one, or gained one reddens here naming both lists. The dialog's own answer then survives the walk: the user's nth 0 reaches arg_values, the composed call answers a DESTINATION

**red_output**

-> {riseTime NOPROC:calc::riseTime_scalar 0 refusal buffer} (exp {riseTime_scalar same 0 destination buffer}) : FAIL

**discriminates_how**

The end-to-end click composition, which MT11 does not drive for `riseTime`. Caught by H_midformal (`differ:{...dest...}|{...}`, `TRUNCATED-BEFORE:nth`, sink `buffer` not `destination`), A_guard_only (sink `badvalue` -- a list with no `shape` key), F_merge_always (`RAISED:key "sweep" not known in dictionary` on the nth-1 control leg). The last leg is the scalar control: nth 1 must still route to the `buffer`.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c R412 THE SILENT TRUNCATION, measured on two probe surfaces this row mints and removes: an extra formal the dialog cannot answer, placed in the MIDDLE, stops arg_values before the ordinal and the proc then receives the DEFAULT 1 where the user asked for 0 -- no error, no refusal, a different measurement. The same formal placed LAST costs nothing and the ordinal arrives

**red_output**

GREEN ON THE RED RUN, declared: `calc::arg_values` and `calc::arg_invoke` both exist today, so the mechanism is measurable before the wrapper exists.

**discriminates_how**

⚠ It is the ONLY thing in the tree that asserts the formal-ORDER requirement. MEASURED that MT11's surface-formals row is GREEN on the truncating shape, because it checks MEMBERSHIP only: with `dest` in the middle all six keys are still formals, `agnsurf` is 21 and `agbadsurf` is empty. This row turns a comment in WIRING_CONTRACT section 7.2 into a measurement, on two probe surfaces whose REMOVAL the band's last row then asserts.


**suite**

tests/headless/test_calc_measure.tcl

**band**

MT9c

**name**

MT9c R402 the band left no __calc_tmp*, no __mt_* column and neither of the two probe surfaces behind -- which is the hygiene claim for an instrument that writes into the product's OWN namespace, and the reason it is a row rather than a habit is that MT10 and MT11 both derive over ::calc:: and would measure a leftover probe as a product proc

**red_output**

GREEN ON THE RED RUN, declared -- the same class as the suite's existing per-band R402 inventory rows.

**discriminates_how**

The band is the first in this file to mint a proc into `::calc::`, so the usual column-glob hygiene row is not enough: `info procs ::calc::__mt_*` is the new leg. Without it a leftover probe surface would be measured by MT10's and MT11's own namespace derivations as a product proc, in a band that runs after this one.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13 (new, between WD12 and WD10 so WD10 still runs last)

**name**

WD13 R419/R415 riseTime_scalar's nth 0 stops deferring and answers a REGISTERED two-column destination rather than a bare list: the answer names a database, its two column names differ, the database's OWN point count is the derived series length, and BOTH columns read back out of it element-wise -- the X at the time tolerance and the Y at the series one -- with the user's own slot current again afterwards

**red_output**

-> {same NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar equal:NOPROC:calc::riseTime_scalar notacount:{} {count=0 want=3 got={}} {count=0 want=3 got={}} 0} (exp {same measured named twonames sized ok ok 0}) : FAIL

**discriminates_how**

The destination keystone, built on J1's measured lesson that a disposition-only row goes green on a guard deletion: every leg here reaches for a non-empty `db`, the destination's own `xschem raw points 0` AFTER switching into it, and both columns read back OUT of it. Uses `wd_listcmp`/`near`, never `string equal` -- measured round-trip drift: `3.200000000000078e-5` in, `3.200000000000078e-05` out; `1.7777777777776282e-5` in, `1.777777777777628e-05` out. Caught by A_guard_only, B_swapped, C_consty, E_offbyone, G_dest_key, H_midformal.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 ...and the X the destination holds is calc::cross's OWN low-crossing list, read back at the same supplied-swing threshold the verb uses -- so a producer that put the HIGH crossings, the midpoints or the rise times themselves on the X axis reddens here naming every offending element, which the derivation leg above cannot distinguish from a wrong interpolation. Every adjacent Y differs by more than WDTOL and the X is strictly increasing over TWO comparisons rather than one

**red_output**

-> {{count=0 want=3 got={}} sized tooshort:0 tooshort:0 tooshort:0} (exp {ok sized distinct distinct increasing}) : FAIL

**discriminates_how**

Separates a wrong X AXIS CHOICE from a wrong interpolation, which the keystone's derivation leg cannot: the comparand is `calc::cross`'s own answer at the same threshold. Its `sized` leg ties the crossing count to the series length so the comparison cannot be vacuous. Caught by B_swapped, C_consty, E_offbyone.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 ...and the answer's KEY SET is exactly riseTime's own keys plus the SERIES X it now carries plus the destination's plus the shape the surface routes on, with `dest` left holding the RETIRED __calc_tmp the measurement evaluated into and `db` holding the LIVE __calc_dest that IS registered: the two keys are different names and mean different things

**red_output**

-> {NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar {} NOPROC:calc::riseTime_scalar absent NOPROC:calc::riseTime_scalar same} (exp {{absent dataset db dest msg n ok shape sweep type value xname yname} tmp {} named registered wave same}) : FAIL

**discriminates_how**

Kills the two-destination-shaped-keys trap for the second caller: sabotage G_dest_key (the live destination put in `dest`) reddens 7 WD13 rows and this one names the live `__calc_dest` sitting in the key MT9b reads BY NAME. The set is EXACT and carries `shape wave` from the start -- J1b's sequencing hazard already paid for -- so the producer must declare the shape in the same commit. Last leg is the distinctness instrument control.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 THE THIRD POINT, measured rather than argued: against the very same element-wise comparison the keystone leans on, the read-back Y REVERSED, ROTATED BY ONE, with its MIDDLE replaced by the mean of the endpoints and with its middle replaced by its left neighbour are each distinct from the derivation while the read-back itself is the same -- and the last three legs show WHY unit J1's two points could not have said it

**red_output**

-> {distinct distinct distinct distinct distinct 1 0 notincreasing:2} (exp {distinct distinct distinct distinct same 1 0 notincreasing:2}) : FAIL

**discriminates_how**

The destination-side half of the third-point claim, asserted on the READ-BACK rather than on the answer, so it fences the hand-off and not only the verb. Its eighth leg -- `wd_increasing` of a rotated X answering `notincreasing:2` -- is an index that cannot exist in a two-point series, which is the cleanest single statement of what the third point buys. Four of its eight legs are satisfied by an absent feature (declared).


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 R402 the destination is a REGISTRY SLOT and every existing leak fence in this batch is BLIND to it, re-measured for this caller rather than inherited from unit J1's row: wd_leaked and wd_probeleft both answer EMPTY while the slot count has gone UP by one and the new slot's sim_type is the one odd type that works

**red_output**

-> {{} {} 1 NOSLOT absent 0} (exp {{} {} 2 table registered 0}) : FAIL

**discriminates_how**

Section 10(d) as a POSITIVE claim for the second caller: the two glob legs are green on the red run AND under every sabotage, which is what proves they cannot see this leak, while the slot-count leg moves. Re-measured rather than inherited, because a per-caller leak is a per-caller claim. Caught by A_guard_only, H_midformal, and by a drop on the success path.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 ...and this caller ANSWERS the destination WITHOUT DROPPING IT either, which is unit J1's declared leak inherited rather than a new one: the slot is still there after the answer, the answer is enough to drop it, and dropping it leaves the user's slot current

**red_output**

-> {1 0 1 absent 0 {}} (exp {2 1 1 absent 0 {}}) : FAIL

**discriminates_how**

Pins the shape section 10(c) overturned, for the second caller: a drop on the SUCCESS path frees the database the trace resolves BY NAME. The `wave_dest_drop` returning 1 also proves the answer dict is SUFFICIENT to drop, which a dict missing `db`/`type` would not give -- and which J1b's `wviewer::plot_dbs_arm` resolution needs.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 the user's own slot is theirs again whichever analysis type they were parked on, driven from BOTH three-slot reading orders in ONE row so that a restore naming a type cannot be green on one and red on the other: read op/ac/tran the user is on tran at slot TWO with an ac slot at index ONE, read op/tran/ac the user is on ac at slot TWO with a tran slot at index ONE, and in both the destination is APPENDED as a fourth slot typed table

**red_output**

-> {NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 2 3 ac NOSLOT NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 2 3 tran NOSLOT} (exp {measured named 2 4 ac table measured named 2 4 tran table}) : FAIL

**discriminates_how**

Three loads with the user on a NON-ZERO slot, in BOTH orders, deliberately in ONE row because the claim is that the PAIR is the fence and the pairing is exactly what rots. Whichever analysis type a defensive read-back writes down, one half names the slot it landed on. ⚠ The ac half's request is `{frequency <w> * sin()}` with w READ BACK from that database's own sweep endpoints every run (`wd_wspan`), because NO committed ac column has a rising edge: `v(sq)` is the AC 1 reference and reads flat, `v(lp)` falls monotonically, and the sweep column itself is one monotone ramp giving one edge. Measured: n=4 gives a 4-point series with every adjacent Y distinct.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 the CONTROL: a NAMED occurrence is the scalar it always was and builds NO destination -- no db key at all, no shape key, riseTime's historic key set, and the registry still the single tran slot -- and neither does a swing the signal never reaches, which answers an ABSENCE

**red_output**

-> {NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 1 {}} (exp {measured NOKEY-db NOKEY-shape {absent dataset dest msg ok value} refused NOKEY-db 1 {}}) : FAIL

**discriminates_how**

The row that kills F_merge_always (the destination merged into EVERY answer), which no other row in either suite catches on its own -- J1's sabotage table records the same for WD11's equivalent. ⚠ Declared NOT green on the red run, unlike WD11's control: it drives the wrapper, which does not exist yet, so it reddens with `NOPROC:` rather than with a missing destination. It is still a control and not part of the unit's fence.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD13

**name**

WD13 R402 the whole band left no __calc_tmp*, no __wd_* probe column and no destination slot behind, across its measured, absent, dropped and two three-slot paths -- which is what keeps band WD10 below measuring the suite's inventory and not this band's residue

**red_output**

GREEN ON THE RED RUN, declared -- the same class as the suite's existing per-band R402 inventory rows, which its header already declares cannot redden while the feature is absent.

**discriminates_how**

Keeps WD13 from poisoning WD10, which runs after it and asserts the whole suite's inventory. It is a real fence for the implementation (a wiring that leaked a destination out of the band's last path reddens it) and vacuous against the feature's absence, which is stated rather than left to be noticed.



### rows_moved

- **MT9b, `test_calc_measure.tcl` -- the "ANSWERS instead of raising" row.** OLD: `{0 refused 0}` (no raise, a REFUSAL, not finite). NEW: `{0 measured 0 atleast2 sized}` -- no raise, MEASURED, still not a single finite number, more than one Y, and a parallel `sweep` of the SAME length. NOT A WEAKENING: it gains two legs and loses none. The `mt_finite ... 0` leg is KEPT, which is what forbids a wiring that truncated the series to its first element; the two new legs demand what the old row could not ask for. Verbatim red against the unmodified tree: `-> {0 refused 0 only:1 sized} (exp {0 measured 0 atleast2 sized})`.

- **MT9b -- the shared-sentence identity row.** OLD: `{refused 1 1 ok}` (refused, carries `cross_msg listdefer`, equals `delay`'s sentence). NEW: `{measured 0 0 refused 1 ok}` -- measured, carries NEITHER the shared sentence NOR `delay`'s, and `delay` is STILL DRIVEN in the same row and still deferring with the shared sentence in the house shape. NOT A WEAKENING: the identity leg is kept and INVERTED rather than deleted, which is what asserts the sentence was RETIRED for this caller and not REWORDED; and `delay`'s two legs are ADDED so the row cannot go green by both callers falling silent together -- a failure mode the old row's pairwise comparison had no guard against. Verbatim red: `-> {refused 1 1 refused 1 ok} (exp {measured 0 0 refused 1 ok})`.

- **MT9b -- the four-ordinal-spellings row.** OLD: `{{refused refused refused refused} {1 1 1 1}}` (all four defer, all four with the shared sentence). NEW: `{measured ok 0}` -- all four MEASURE, all four give the SAME SERIES compared ELEMENT FOR ELEMENT against the `0` spelling's own answer, and none carries the retired sentence. NOT A WEAKENING, it is the one clear STRENGTHENING in the set: the old row compared only the disposition and the message, so a dispatch that matched the literal `0` as a string and fell through to the scalar path for `0.0`, `-0` and `0e0` would have been caught only if the scalar path refused. Now it is caught on the VALUES. Verbatim red: `-> {refused refused 1} (exp {measured ok 0})`.

- **MT9b -- the "deferral opens NO engine door" row.** OLD: `{{} 1}` (the deferral carries an EMPTY `dest`, the absence carries a `__calc_tmp*`). NEW: `{1 1 {} {}}` -- `nth` 0 now carries the `__calc_tmp*` name `cross` minted for it, exactly as the absence already did, and R402 has deleted both so NEITHER survives the inventory. NOT A WEAKENING: the old row's claim was true only while the verb answered before reaching the database, so keeping it would have been asserting something the feature makes false. The two inventory legs are ADDED precisely so the row cannot read as permission to leak -- the empty-`dest` claim is replaced by a mint-and-delete claim, which is strictly more than it said. Verbatim red: `-> {0 1 {} {}} (exp {1 1 {} {}})`.

- **WD9, `test_calc_wave_dest.tcl` -- the four-caller identity row. ⚠ BAND WD9 PINS riseTime's DEFERRAL and this is the row that retires it.** OLD: `{refused 1 refused 1 measured 0 refused 1}` over cross_scalar / delay / dutyCycle_scalar / riseTime. NEW: `{refused 1 refused 1 measured 0 measured 0 measured 0}` -- the two still-waiting callers unchanged, and `riseTime` driven at BOTH LAYERS: the raw verb AND the new `riseTime_scalar` surface. NOT A WEAKENING: the wired caller is not dropped (dropping it would leave nothing asserting that it STOPPED saying the shared sentence), and a FIFTH leg pair is added because `calc::arg_surface` redirects silently the moment the wrapper exists -- a row driving only the raw proc would stop measuring what a click gets. Verbatim red: `-> {refused 1 refused 1 measured 0 refused 1 NOPROC:calc::riseTime_scalar 0} (exp {refused 1 refused 1 measured 0 measured 0 measured 0})`.

- **WD9 -- the pairwise-chain row.** OLD: `{1 1 0 0}` (a three-caller chain plus two negatives for the one wired caller). NEW: `{1 long 0 0 0 0 0 0}` -- the chain is now TWO callers long so the positive leg is one comparison, with a `wd_longer ... 0` NON-VACUITY leg beside it asserting that sentence is non-empty, and SIX negative legs: three wired callers (dutyCycle_scalar, riseTime, riseTime_scalar) each against `cross_msg listdefer` and against a still-waiting sibling. NOT A WEAKENING: it goes from four legs to eight. ⚠ The non-vacuity leg is ADDED for a reason the old row did not need: with only two callers left in the chain, a positive identity leg could be satisfied by two callers that had BOTH fallen silent (two empty strings compare equal). Verbatim red: `-> {1 long 0 0 1 1 0 0} (exp {1 long 0 0 0 0 0 0})`.

- **WD9 -- the DERIVED caller-set keystone. ⚠ MOVED BY RE-DERIVING, NEVER BY DECREMENTING A FLOOR.** OLD expectation `[list {cross_scalar delay riseTime} {dutyCycle_scalar} {cross_scalar delay dutyCycle_scalar riseTime} atleast]`. NEW `[list {cross_scalar delay} {dutyCycle_scalar riseTime_scalar} {cross_scalar delay dutyCycle_scalar riseTime_scalar} atleast]`. The two sets and the regexps that derive them are UNTOUCHED; only the expectation moves, and `riseTime` MOVES FROM ONE SET TO THE OTHER as `riseTime_scalar`. **The `atleast 4` floor is UNCHANGED and still holds at four**, because it runs over the UNION -- which is exactly why J1 re-derived it over the union instead of decrementing it. NOT A WEAKENING: nothing is lowered, no name is written down that the derivation does not find, and the floor still catches a caller that fell out of BOTH sets. MEASURED LIVE: sabotage A_guard_only prints `{{cross_scalar delay} dutyCycle_scalar {cross_scalar delay dutyCycle_scalar} only:3}` -- the floor itself catches a guard replaced with no destination built; sabotage I_wrong_layer prints `riseTime` where `riseTime_scalar` belongs, so the row names the wrong LAYER too. Verbatim red: `-> {{cross_scalar delay riseTime} dutyCycle_scalar {cross_scalar delay dutyCycle_scalar riseTime} atleast} (exp {{cross_scalar delay} {dutyCycle_scalar riseTime_scalar} {cross_scalar delay dutyCycle_scalar riseTime_scalar} atleast})`.

**returns_respelling**

MEASURED RATHER THAN REASONED, by simulating the re-spelling in process and RUNNING every implicated suite against it. `calc::catalogue` was wrapped so the `riseTime` row answers `scalar/wave` instead of `scalar` (field index 3), and every suite was re-run.

PER-`returns`-VALUE -- NOTHING MOVES, because `scalar/wave` is ALREADY in the vocabulary:
* **S24's closed vocabulary** `{scalar wave bool scalar/wave scalar/list}` -- its `lsearch -exact` already permits the value, so the term list does NOT widen. MEASURED: `test_calc_skeleton` on the DISPLAY arm under the simulation plus the re-spelling is **ALL PASS (579 checks)**, identical to its figure without it. That arm is the only one that runs S24 at all (`dcases` alone; it self-skips to 0 checks under `--nogui`), and it was run.
* **The three prose copies in `src/calculator.tcl`** -- `calc::fn_fields`' schema comment and `calc::catalogue`'s own, twice -- enumerate the five WORDS. None moves.
* **Spec §7.2ab's R416 vocabulary note** -- enumerates the same five words. Does not move.
So the four-site widening R419 cost is NOT incurred. That was WIRING_CONTRACT §5's claim and it holds, now by measurement.

PER-CATEGORY -- NOTHING MOVES: S24's eight arm counts `{56 26 12 4 3 3 4 108}` come from `calc::fn_entries $cat`, which counts rows per §7.1 CATEGORY and never reads `returns`. `riseTime` stays in `Special Functions`. Confirmed by the 579 figure above.

PER-VERB -- FOUR SITES MOVE, and they are the implementer's prose list:
1. `src/calculator.tcl`, `calc::catalogue`'s `riseTime` row: `scalar` -> `scalar/wave`.
2. `src/calculator.tcl`, `calc::catalogue`'s banner: *"`riseTime` and `delay` stay `scalar`: both answer one number, and R417's negative delay is still one number"* -- becomes FALSE for `riseTime`.
3. `doc/claude/specs/calculator.md` R416's closing note: *"`riseTime` and `delay` stay `scalar` -- each answers one number, R417's negative one included."* Same sentence, same falsehood.
4. `doc/claude/specs/calculator.md` §7.2's table row: `| `riseTime` | scalar | ...`.
Plus two STALE copies J2 should correct while it is there: `src/calculator.tcl`'s comments that still enumerate the deferring callers as *"delay, dutyCycle_scalar and the unbuilt frequency"*, which WIRING_CONTRACT §9 already counts among its twenty.

NO ROW ANYWHERE ASSERTS `riseTime`'s `returns` VALUE: `/usr/bin/grep riseTime tests/headless/test_calc_skeleton.tcl` matches one PROSE line only. So the four sites above are prose and a catalogue literal, not fences.

FULL MEASUREMENT UNDER SIM + RE-SPELLING -- counted arm: wave_dest 124, measure 183, cross 187, engine 265, scratch_reuse 56, all ALL PASS. Display arm (`DISPLAY=:99 GUI_GATE=0`, attached to the existing dev display and left as found): skeleton **579**, plot **114**, widgets **259**, buffer **130**, all ALL PASS -- every one identical to its figure without the re-spelling.

**check_counts**

EVERY FIGURE BELOW WAS RUN IN THIS SESSION AND RE-DERIVED, NEVER PRESERVED.

=== THE TWO SUITES J2 TOUCHES -- counted arm, identical command for before, red and green ===
  env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure

BEFORE (the PRISTINE suites swapped back in, unmodified product; my edited files were backed up to scratch first and restored byte-identical afterwards, verified with `cmp`):
  PASS | test_calc_wave_dest   RESULT: ALL PASS (115 checks)
  PASS | test_calc_measure     RESULT: ALL PASS (170 checks)

AFTER the rows, against the UNMODIFIED product (THE RED):
  FAIL | test_calc_wave_dest   RESULT: 11 FAILED (113 passed)   -> 124 checks
  FAIL | test_calc_measure     RESULT: 13 FAILED (170 passed)   -> 183 checks
  (11 = WD9 x3 moved + WD13 x8 new;  13 = MT9b x4 moved + MT9c x9 new.  exit 1)

AFTER the rows, against a SIMULATED J2 injected at suite file scope (`src/` untouched):
  env -u DISPLAY HOME=<scratch>/fakehome ./src/xschem --nogui --pipe -q --nolog --script <scratch>/sim/r_<suite>.tcl
  test_calc_wave_dest   OVERALL: ok (124 checks) / RESULT: ALL PASS (124 checks)
  test_calc_measure     OVERALL: ok (183 checks) / RESULT: ALL PASS (183 checks)
  Identical with and without the `returns` re-spelling.

PUBLISHED COUNTS THE IMPLEMENTER MUST RE-DERIVE:
  test_calc_wave_dest   115 -> 124  (+9: nine new WD13 rows; WD9's three were MOVED, not added)
  test_calc_measure     170 -> 183  (+13: thirteen new MT9c rows; MT9b's four were MOVED)

=== THE SUITES J2 DOES NOT TOUCH -- counted arm, after my edits ===
  env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_cross test_calc_engine test_calc_scratch_reuse
  PASS | test_calc_cross          ALL PASS (187 checks)
  PASS | test_calc_engine         ALL PASS (265 checks)
  PASS | test_calc_scratch_reuse  ALL PASS (56 checks)      RESULT: 3/3 runs passed
  Same three under the simulated J2, and again under sim + re-spelling: 187 / 265 / 56, all ALL PASS.

=== THE DISPLAY ARM -- RUN, not reasoned ===
  tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
  (announced: `display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0`; attached and left as found)
  PASS | test_calc_skeleton  ALL PASS (579 checks)
  PASS | test_calc_plot      ALL PASS (114 checks)
  PASS | test_calc_widgets   ALL PASS (259 checks)
  PASS | test_calc_buffer    ALL PASS (130 checks)          RESULT: 4/4 runs passed
  And all four again under the simulated J2 PLUS the `returns` re-spelling (DISPLAY=:99 GUI_GATE=0, throwaway HOME): 579 / 114 / 259 / 130, all ALL PASS. NOTHING DISPLAY-ONLY MOVES.
  ⚠ The last of my edits (the two absence rows' three extra surface legs) landed after that display run; it touches only `test_calc_measure.tcl`'s own text. `/usr/bin/grep -n 'test_calc_measure\|test_calc_wave_dest'` over the four `dcases` suites matches 3 / 4 / 1 / 0 lines and EVERY match is a prose cross-reference inside a row NAME -- none of the four opens or reads either edited file. That is reasoning plus a grep for that one edit, and it is stated as such.

=== THE T1 TRAILER -- DERIVED with `summarize_all`'s own regexp arms and `tests/banner_rule.tcl`'s own predicates over REAL captured output. I did NOT run T1. ===
Both suites are ALREADY in `hcases` (`tests/run_regression.tcl` lines 119-120, verified), so the registration delta is ZERO. List sizes by CLAUDE.md's own method (`set <L> [list` then `grep -o '\"[^\"]*\"' | wc -l`): tcases 3, hcases 96, dcases 25 -> 124 + `xschemtest` = 125 cases, 124 blocks, unchanged.
Census (lowercase `^skip:` / uppercase `^SKIP:|^SKIPPED:` / `^RESULT:` / counted shapes / banner_complete / banner_died), before and after, over real output:
  before test_calc_measure   (170 checks)   0 / 0 / 1 / 0 / 1 / 0
  after  test_calc_measure   (183 checks)   0 / 0 / 1 / 0 / 1 / 0
  before test_calc_wave_dest (115 checks)   0 / 0 / 1 / 0 / 1 / 0
  after  test_calc_wave_dest (124 checks)   0 / 0 / 1 / 0 / 1 / 0
THEREFORE cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines, not with the counts inside them, and neither number moved. This is the PLAN 5.4 / J1 shape again: a stage that moves two published check counts and not one trailer term. **The driver reads the trailer.**

**red_proof**

Armed spelling, repo root, PRODUCT UNTOUCHED. `git diff --stat -- src/` produces NO OUTPUT (src/ byte-identical to HEAD), verified immediately before and after this run. Transcript: /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/rowsmith/red_final.txt

  $ git diff --stat -- src/
  (no output)
  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
  test home: throwaway /tmp/xschem-test-home.3495656.Rrv2iW (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (113 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 13 FAILED (170 passed)
  RESULT: 0/2 runs passed
  (exit 1)

THE TWENTY-FOUR FAILING ROWS, verbatim got/exp tails, in run order:

  WD9  -> {refused 1 refused 1 measured 0 refused 1 NOPROC:calc::riseTime_scalar 0} (exp {refused 1 refused 1 measured 0 measured 0 measured 0}) : FAIL
  WD9  -> {1 long 0 0 1 1 0 0} (exp {1 long 0 0 0 0 0 0}) : FAIL
  WD9  -> {{cross_scalar delay riseTime} dutyCycle_scalar {cross_scalar delay dutyCycle_scalar riseTime} atleast} (exp {{cross_scalar delay} {dutyCycle_scalar riseTime_scalar} {cross_scalar delay dutyCycle_scalar riseTime_scalar} atleast}) : FAIL
  WD13 -> {same NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar equal:NOPROC:calc::riseTime_scalar notacount:{} {count=0 want=3 got={}} {count=0 want=3 got={}} 0} (exp {same measured named twonames sized ok ok 0}) : FAIL
  WD13 -> {{count=0 want=3 got={}} sized tooshort:0 tooshort:0 tooshort:0} (exp {ok sized distinct distinct increasing}) : FAIL
  WD13 -> {NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar {} NOPROC:calc::riseTime_scalar absent NOPROC:calc::riseTime_scalar same} (exp {{absent dataset db dest msg n ok shape sweep type value xname yname} tmp {} named registered wave same}) : FAIL
  WD13 -> {distinct distinct distinct distinct distinct 1 0 notincreasing:2} (exp {distinct distinct distinct distinct same 1 0 notincreasing:2}) : FAIL
  WD13 -> {{} {} 1 NOSLOT absent 0} (exp {{} {} 2 table registered 0}) : FAIL
  WD13 -> {1 0 1 absent 0 {}} (exp {2 1 1 absent 0 {}}) : FAIL
  WD13 -> {NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 2 3 ac NOSLOT NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 2 3 tran NOSLOT} (exp {measured named 2 4 ac table measured named 2 4 tran table}) : FAIL
  WD13 -> {NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 1 {}} (exp {measured NOKEY-db NOKEY-shape {absent dataset dest msg ok value} refused NOKEY-db 1 {}}) : FAIL
  MT9b -> {0 refused 0 only:1 sized} (exp {0 measured 0 atleast2 sized}) : FAIL
  MT9b -> {refused 1 1 refused 1 ok} (exp {measured 0 0 refused 1 ok}) : FAIL
  MT9b -> {refused refused 1} (exp {measured ok 0}) : FAIL
  MT9b -> {0 1 {} {}} (exp {1 1 {} {}}) : FAIL
  MT9c -> {refused {n:1 want:3} {n:1 want:3} {count=1 want=3 got={NOKEY-sweep}} 0} (exp {measured sized sized ok 0}) : FAIL
  MT9c -> {measured sized refused} (exp {measured sized ok}) : FAIL
  MT9c -> {same refused {count=1 want=3 got={NOKEY-sweep}} strict strict} (exp {same ok ok strict strict}) : FAIL
  MT9c -> {tooshort:1 tooshort:1 tooshort:1 same {distinct same}} (exp {distinct distinct increasing same {distinct same}}) : FAIL
  MT9c -> {distinct distinct distinct distinct distinct 1 0} (exp {distinct distinct distinct distinct same 1 0}) : FAIL
  MT9c -> {refused {n:1 want:2} atleast1 refused {count=1 want=2 got={NOKEY-sweep}} absent} (exp {measured sized atleast1 ok ok absent}) : FAIL
  MT9c -> {refused 0 known elsewhere ok sized NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 0 elsewhere} (exp {absent 0 known elsewhere ok sized NOKEY-db absent 0 elsewhere}) : FAIL
  MT9c -> {refused 0 known elsewhere atleast1 sized NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar 0 elsewhere} (exp {absent 0 known elsewhere atleast1 sized NOKEY-db absent 0 elsewhere}) : FAIL
  MT9c -> {riseTime NOPROC:calc::riseTime_scalar 0 refusal buffer} (exp {riseTime_scalar same 0 destination buffer}) : FAIL

EVERY ROW FAILED, NONE THREW: `/usr/bin/grep -cE 'UNEXPECTED ERROR|BGERROR|ABORTED|another regression run is live'` answers **0** on the transcript, so no band was abandoned (the issue-1616 trap) and zero live-peer lines. 113 of 124 and 170 of 183 checks kept measuring. Avoided by routing every product call through `mt_call`/`wd_call`/`pcall`, every count and index through `mt_len`/`mt_at`/`wd_len`/`wd_at`, every word-valued answer through a PROC rather than a braced `expr` ternary, and by guarding `mt_sized`/`mt_atleast`/`mt_listcmp` with `string is integer -strict`.

AND THE GREEN SIDE IS REACHABLE, measured rather than asserted. A simulated J2 -- the architecture named in `wrapper_decision` -- injected at suite file scope with `src/` still untouched gives `ALL PASS (124 checks)` / `ALL PASS (183 checks)`, and 187 / 265 / 56 / 579 / 114 / 259 / 130 everywhere else.

ELEVEN SABOTAGES, EVERY ONE CAUGHT (generators and overlays in <scratch>/J2/rowsmith/sab/):
  A_guard_only    the wrapper a bare pass-through to the verb, which already computes the series -- measure 1 FAILED, wave_dest 8 FAILED. ⚠ WD9's union floor prints `only:3`, vindicating J1's decision to re-derive it over the union rather than decrement it; MT9c's surface row prints sink `badvalue`.
  B_swapped       X and Y handed to wave_dest the wrong way round -- measure ALL PASS (correct scoping: MT9c reads no destination column), wave_dest 3 FAILED.
  C_consty        Y filled with its own element 0 -- measure 5 FAILED, wave_dest 3 FAILED.
  D_revy          Y written backwards -- measure 4 FAILED, wave_dest 2 FAILED.
  E_offbyone      one point short -- measure 5 FAILED, wave_dest 3 FAILED.
  F_merge_always  the destination merged into EVERY answer -- measure 1, wave_dest 1, and the ONLY catcher in each is the CONTROL/surface row (`RAISED:key \"sweep\" not known in dictionary`), which is why those controls exist.
  G_dest_key      the live destination put in `dest`, nothing in `db` -- measure ALL PASS, wave_dest 7 FAILED.
  H_midformal     the wrapper's extra formal in the MIDDLE -- measure 1 FAILED with `TRUNCATED-BEFORE:nth` and sink `buffer`, wave_dest 8 FAILED.
  I_wrong_layer   the engine door inside `calc::riseTime` -- MT10's closure row prints `{{riseTime delay dutyCycle} {wave_dest {} {}}}`, WD9's partition names `riseTime` where `riseTime_scalar` belongs.
  J_destempty     the empty series routed to wave_dest -- caught by MT9c's two absence rows ONLY (`refused 1 samefamily:Destination`); wave_dest ALL PASS.
  K_padded        a dropped point padded with the previous value -- caught by MT9c's partial-drop row ONLY (`{n:3 want:2}` plus the element-wise legs naming the duplicate); wave_dest ALL PASS.

PRODUCT UNTOUCHED, final state:
  $ git status --short
   M tests/headless/test_calc_measure.tcl
   M tests/headless/test_calc_wave_dest.tcl
  ?? .claude/
  ?? .xschem/
  ?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
  ?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
  $ git diff --stat
   tests/headless/test_calc_measure.tcl   | 626 ++++++++++++++++++-
   tests/headless/test_calc_wave_dest.tcl | 322 ++++++++++-
The four `??` entries were in this session's starting git-status snapshot and are not mine. NO PRODUCT CHANGE WAS IMPLEMENTED: the simulated J2 lives only at <scratch>/J2/rowsmith/sim/j2impl.tcl and the `returns` re-spelling only at sim/respell.tcl, both injected at FILE SCOPE into wrappers that `source` the real suites. Nothing committed, pushed or gated; no full T1; the owed.sh ledger untouched; `~/dev/xschem-op-wcard`, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display` and `~/.claude/gui_test_gate` never written; `devdisplay.sh start|stop|view` never run -- the display-arm readings ATTACHED to the already-running `:99` with `GUI_GATE=0` and a throwaway HOME and left it as found. Every binary call carried `--nogui` or `env -u DISPLAY` or an explicit `DISPLAY=:99`; no bare `xschem`; `/usr/bin/grep` throughout. Both edited files answer `info complete` = 1. No `switch` was touched in either file and no comment sits between two patterns anywhere in my additions. Scratch is 1.4 MB and `/tmp` (tmpfs) is at 763M of 7.7G.


### declared_holes

- ⚠⚠ `riseTime` HAS NO `xaxis` ARGUMENT AND J2 DOES NOT ADD ONE. R420 gave `dutyCycle` three X axes (`start`/`number`/`mid`) as an argument with a default; `riseTime`'s series X is the LOW crossing time, which is R420's own default choice ("the time the thing started") read across to a transition. The midpoint of the transition and the edge ordinal are equally legitimate and nobody has been asked. Adding the argument is NOT free: it needs a new `calc::fn_argspec riseTime` row, which moves MT11's four-literal spec row, `agnsurf`, and the argspec shape sweep. Out of scope, declared, and a `rule` candidate because the X axis of a plotted measurement is something the user sees.

- ⚠ THE EMPTY-SERIES SENTENCE IS UNRULED AND BOTH REUSABLE ARMS READ ODDLY. `calc::cross_msg nohigh [calc::cross_ordinal 0]` gives *"Rise time: the 0th low crossing has no high crossing after it in this sweep"* and `cross_msg absent` gives *"Cross: there is no 0th rising crossing..."*. The simulation uses the first. NO ROW ASSERTS THE WORDS -- they assert the disposition, a negative identity against `destempty`, and that the FAMILY is one `calc::cross_msg` itself builds -- so the filed `rule` debt `calc_wave_dest_empty_result_sentence` can land without touching a row. A crew that reads the simulation's choice as a decision would be wrong.

- ⚠ THE PARTIAL-DROP DISPOSITION IS J2's OWN AND IS DECLARED, NOT RULED. A low crossing with no high after it DROPS that point; the alternative (refuse the series) is a one-line change that reddens exactly one row (MT9c's partial-drop row). The argument for dropping is in the band comment: it is the driver's empty-series call applied once per point, and refusing would refuse every transient that ends part way up its last edge. The user has not been asked.

- ⚠ THE CLICK PATH IS NOT FENCED ON THE COUNTED ARM, inherited from J1's hole H12 and still true: `calc::fn_measure` and `calc::buf_set_number` both return early on `calc::has_win .calc.buf`, so what the user's RPN buffer and status line do with a `riseTime` wave is observable on a gate's DISPLAY arm and nowhere else. J1b's `calc::fn_sink` router means the WAVE will not be pasted (MT12 fences the decision on both arms), but the ACT -- the buffer really left alone, the sentence reaching the widget, one undo -- is band S28's and I did not add a row there. J2's unit does not need one: the router already routes on `shape`, which WD13's key-set row requires.

- ⚠ NO ROW ASSERTS THAT THE MEASURED `riseTime` WAVE APPEARS ON SCREEN. J1b's `calc::wave_show` resolves the destination by REGISTRY INDEX and is verb-agnostic, so it should work unchanged -- but that is reasoning, not a measurement, and the two display-arm rows that would see it (PL10, S28/7) drive `dutyCycle`. A J2 implementer should re-run `test_calc_plot` and `test_calc_skeleton` on the display arm after landing; I ran both under the simulation (114 / 579, ALL PASS) which shows nothing BREAKS, not that the new verb's trace draws.

- ⚠ THE AC HALF OF THE RESTORE ROW IS DERIVED ONCE, FROM THE COLUMNS. Its request is `{frequency <w> * sin()}` with `w` read back from the ac database's own sweep endpoints, and the verb and the row evaluate the same expression string through the same engine -- so it says nothing new about the rise-time arithmetic (the tran half owns that) and is honest only about the registry bookkeeping. Same cost J1's long series declared.

- ⚠ `@m1[gm]`, `i(@m1[id])`, `i(@rdc1[i])` AND `i(@rtop[i])` ARE UNMEASURABLE through `calc::cross` as single-token RPNs: a one-element RPN list carrying a bracket is braced by Tcl and the engine answers `Cannot measure: unknown token '{@m1[gm]}'`. Measured at five level pairs each. That is four of the fixture's ten columns closed to every `cross`-layered verb, and it is not written down anywhere in the fixture README or in any contract. Not a J2 defect; worth a row of its own in band MT0 or a line in the fixture README, which I did not write.

- ⚠ THE RESTORE ROW ASSERTS THE CURRENT SLOT AND SAYS NOTHING ABOUT `prev`. `calc::wave_dest_restore` puts back one half of a registry cursor that is a pair, so `xschem raw switch_back` after a successful destination lands ON THE DESTINATION -- J1's pre-existing defect (b), still open and still unfenced. No row in WD13 issues `switch_back` or reads `prev`/`prevtype`, and those keys are excluded from the answer's key set, so no row can reach it. A row asserting it would be RED ON CORRECT J2 CODE.

- ⚠ WHO FREES A DESTINATION THE USER IS LOOKING AT IS STILL UNRULED (J1 hole H11). WD13 asserts the slot SURVIVES a successful answer and that the band can drop it; it says nothing about whether the product should, and J2 now DOUBLES the leak rate because a second verb mints slots nobody frees.

- ⚠ THE DESTINATION'S USER-VISIBLE NAME IS STILL UNRULED. Every WD13 row reads `xname`/`yname` OUT OF the answer and matches `db` against a GLOB, never a literal, so nothing here pre-empts the ruling -- and the glob is required anyway, because `__calc_dest<N>` carries a serial this suite's own earlier bands advance.

- ⚠ FOUR OF WD13's `wd_curslot` LEGS ARE LEAK COVERAGE AND NOT RESTORE COVERAGE, the same correction J1's receipt had to make: the keystone, the slot-count row, the no-drop row and the band's inventory row all read the current slot AFTER the band itself issues `xschem raw switch $::fixture tran`, which lands correctly whatever the producer did. The restore is fenced by the two-order row and by nothing else.

- ⚠ TWO OF MT9c's THIRTEEN ROWS AND ONE OF WD13's NINE ARE GREEN WITH NO FEATURE PRESENT, and four of two rows' legs are satisfied by an absent feature. Declared in each band's comment by KIND. The honest apportionment of J2's fence is: 1 pre-existing row (WD9's union floor, which prints `only:3` on a guard-replacement that builds nothing) + 1 pre-existing row (MT10's closure row, which catches the wrong layer) + 9 new MT9c rows + 8 new WD13 rows + legs of four moved rows.

- I DID NOT RUN A FULL T1, DID NOT COMMIT, DID NOT GATE, AND DID NOT TOUCH THE owed.sh LEDGER. `git diff --stat -- src/` is empty. The trailer figures are DERIVED from `summarize_all`'s own regexp arms and `banner_rule.tcl`'s own predicates over real captured output; the driver reads the trailer. NOTHING IS RUNNING NOW.



## attack:off-by-one

**sabotage**

ASSIGNED CLASS: off-by-one in the per-edge fill. I drove THREE distinct sites, all plausible, all against a from-scratch J2 implementation built to the architecture the suite author's receipt names (`calc::riseTime`'s nth-0 arm computes the series; `calc::riseTime_scalar` forwards non-zero `nth`, hands `sweep` then `value` to `calc::wave_dest`, merges `{db type xname yname n}` plus `shape wave`). My correct implementation is `ALL PASS (124 checks)` / `ALL PASS (183 checks)` -- exactly the author's published counts -- so every red below is the sabotage and not my wiring.

PRIMARY (the assigned one), in `calc::riseTime`'s nth-0 series loop. ONE TOKEN:
    -        for {set i 0} {$i < $nl} {incr i} {
    +        for {set i 0} {$i < $nl - 1} {incr i} {
WHY IT IS PLAUSIBLE AND NOT CONTRIVED: the brief points the implementer at `calc::dutyCycle_scalar`/`calc::dutyCycle` as THE worked producer, and `calc::dutyCycle`'s own series loop reads `for {set i 0} {$i < $nr - 1} {incr i}`. There the `- 1` is CORRECT -- a duty cycle is measured between a PAIR of consecutive rising edges, so N edges give N-1 cycles. A rise time is measured within ONE edge, so N edges give N rise times. An engineer who pattern-matches the precedent loop instead of reading the J-recon `sites` entry ("for each `xlo` ...") keeps the `- 1` and silently drops the LAST edge. My own comment in the sabotaged proc even says "The loop is `calc::dutyCycle`'s shape, which is the worked producer", which is how this bug would really be justified in review.

SECOND SITE, in `calc::riseTime_scalar` -- the handoff layer, which the author's sabotage table never drove:
    +    # The final edge of a transient is the one most likely to be clipped by the
    +    # end of the sweep, so the last point is left out of the plotted wave.
    +    set xs [lrange [dict get $m sweep] 0 end-1]
    +    set ys [lrange [dict get $m value] 0 end-1]
    -    set h [calc::wave_dest [dict get $m sweep] [dict get $m value]]
    +    set h [calc::wave_dest $xs $ys]
The verb's own answer stays correct (3 points); only what reaches the destination is short.

THIRD SITE -- the LENGTH-PRESERVING variant, which is the only shape with any chance of surviving, and a far more plausible route to it than the author's synthetic padder. `set xh {}` hoisted OUT of the loop (a forgotten loop-local reset):
    +        set xh {}
             for {set i 0} {$i < $nl} {incr i} {
                 set x0 [lindex $los $i]
    -            set xh {}
                 foreach h $his {
A low crossing with no high after it then inherits the PREVIOUS edge's high crossing instead of being dropped, so the point is padded and the count survives. On the committed fixture it emits a NEGATIVE rise time.

**why_wrong**

PRIMARY: a user who asks `riseTime` for the whole per-edge series on a signal with three rising edges gets TWO rise times. The last edge is silently absent -- from the answer, from the plotted wave and from the destination database -- with no refusal, no absence and no sentence. On a real transient the last edge is the one the designer most often cares about (the slowest, the most loaded), and on any periodic signal the user has no way to notice the series is one short: the two points that are there are correct. Measured on the fixture: Y = {1.4667e-4, 3.2e-5} where the truth is {1.4667e-4, 3.2e-5, 1.7778e-5}, X = {9.2e-4, 4.904e-3} where the truth has 8.902e-3 as well.

SECOND SITE: the number the user reads and the wave the user SEES disagree. `calc::riseTime` answers three rise times, the plotted destination holds two, and the answer's own `n` key says 2 -- so the trace drawn on the strip is missing its final point while the verb's value list is complete.

THIRD SITE: strictly worse than a dropped point. A transient that ends part way up its last edge produces a rise time of **-0.002887902076229785** -- a negative rise time, pasted into the series as if measured, because the point inherited the previous edge's high crossing (which lies BEFORE its own low crossing). The series is also one point longer than the number of measurable edges.

**verdict**

CAUGHT

**evidence**

All runs: armed counted arm from the worktree root, `timeout 900 env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure`. Zero raises and zero live-peer lines in every run (`/usr/bin/grep -cE 'UNEXPECTED ERROR|BGERROR|ABORTED|another regression run is live'` = 0 on all five transcripts).

=== A. RED BASELINE, pristine product (reproduces the author's receipt exactly) ===
FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (113 passed)
FAIL     | test_calc_measure            run 2/2  RESULT: 13 FAILED (170 passed)
RESULT: 0/2 runs passed            (exit=1)

=== B. MY CORRECT J2 IMPLEMENTATION (proves the fence is green on correct code) ===
PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (124 checks)
PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (183 checks)
RESULT: 2/2 runs passed            (exit=0)

=== C. PRIMARY SABOTAGE -- `$i < $nl - 1` (dutyCycle-precedent copy) ===
FAIL     | test_calc_wave_dest          run 1/2  RESULT: 3 FAILED (121 passed)
FAIL     | test_calc_measure            run 2/2  RESULT: 4 FAILED (179 passed)
RESULT: 0/2 runs passed            (exit=1)

SEVEN failing rows, verbatim got/exp tails, in run order:
WD13 -> {same measured named twonames {pts:2 want:3} {count=2 want=3 got={0.0009200000000000001 0.004904}} {count=2 want=3 got={0.0001466666666666655 3.200000000000078e-05}} 0} (exp {same measured named twonames sized ok ok 0}) : FAIL
WD13 -> {{count=2 want=3 got={0.0009200000000000001 0.004904}} sized distinct distinct increasing} (exp {ok sized distinct distinct increasing}) : FAIL
WD13 -> {distinct distinct distinct distinct distinct 1 0 notincreasing:2} (exp {distinct distinct distinct distinct same 1 0 notincreasing:2}) : FAIL
MT9c -> {measured {n:2 want:3} {n:2 want:3} {count=2 want=3 got={0.0009200000000000001 0.0049039999999999995}} 0} (exp {measured sized sized ok 0}) : FAIL
MT9c -> {measured sized {count=2 want=3 got={0.0001466666666666655 3.200000000000078e-5}}} (exp {measured sized ok}) : FAIL
MT9c -> {same {count=2 want=3 got={0.0001466666666666655 3.200000000000078e-5}} {count=2 want=3 got={0.0009200000000000001 0.0049039999999999995}} strict strict} (exp {same ok ok strict strict}) : FAIL
MT9c -> {distinct distinct distinct distinct distinct 1 0} (exp {distinct distinct distinct distinct same 1 0}) : FAIL

=== D. SECOND SITE -- off-by-one in the WRAPPER (`lrange ... 0 end-1`) ===
FAIL     | test_calc_wave_dest          run 1/2  RESULT: 3 FAILED (121 passed)
PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (183 checks)
RESULT: 1/2 runs passed            (exit=1)
WD13 -> {same measured named twonames {pts:2 want:3} {count=2 want=3 got={0.0009200000000000001 0.004904}} {count=2 want=3 got={0.0001466666666666655 3.200000000000078e-05}} 0} (exp {same measured named twonames sized ok ok 0}) : FAIL
WD13 -> {{count=2 want=3 got={0.0009200000000000001 0.004904}} sized distinct distinct increasing} (exp {ok sized distinct distinct increasing}) : FAIL
WD13 -> {distinct distinct distinct distinct distinct 1 0 notincreasing:2} (exp {distinct distinct distinct distinct same 1 0 notincreasing:2}) : FAIL
(measure ALL PASS is CORRECT SCOPING: MT9c never reads a destination column.)

=== E. THIRD SITE -- LENGTH-PRESERVING (`set xh {}` hoisted out of the loop) ===
PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (124 checks)
FAIL     | test_calc_measure            run 2/2  RESULT: 1 FAILED (182 passed)
RESULT: 1/2 runs passed            (exit=1)
MT9c -> {measured {n:3 want:2} atleast1 {count=3 want=2 got={0.0011130770436309611 0.0011120979237804448 -0.002887902076229785}} {count=3 want=2 got={0.0009739434720928703 0.004975045466306166 0.008975045466316396}} absent} (exp {measured sized atleast1 ok ok absent}) : FAIL

Transcripts and the three product variants:
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/red_baseline.txt
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/green_correct.txt
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/sab_droplast.txt
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/sab_wrapper_droplast.txt
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/sab_stale_xh.txt
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/calc_CORRECT.tcl
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/calc_SABOTAGED.tcl
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv-offbyone/calc_SAB_stale_xh.tcl

Product left pristine: `git diff --stat -- src/` produces no output; `git status --short` shows only the author's two modified suite files (copied in from the main checkout so this worktree carries the rows under test). Worktree reset to `580f1622` and running the main tree's `src/xschem` (no C change since it was built, verified), so `XSCHEM_SHAREDIR` resolves to this worktree's `src/` and the Tcl edits took effect -- which run B's 124/183 confirms. No commit, no push, no T1, no owed.sh, no `devdisplay.sh start|stop|view`, no bare `xschem`, `/usr/bin/grep` throughout, `info complete` = 1 on every edited file, no `switch` touched.

**which_row_caught_it**

CAUGHT, and by SEVEN rows across both suites -- four in `tests/headless/test_calc_measure.tcl` band MT9c and three in `tests/headless/test_calc_wave_dest.tcl` band WD13. The author's third-point series is exactly what made it catchable, and the elements (not just the lengths) are compared, so both halves of the task's escape clause are closed.

CATCHERS, named:
* MT9c keystone ("R419/R416 ... MEASURES the per-edge series instead of deferring") -- `mt_sized` on BOTH the Y and the parallel `sweep` against the edge count read back off `calc::cross`, plus `mt_listcmp` of the X against `cross`'s own low-crossing list: `{n:2 want:3} {n:2 want:3} {count=2 want=3 ...}`. This is the single strongest leg set, because the want is DERIVED every run.
* MT9c T2 ("the series IS the scalar path, edge by edge") -- the comparand is the shipped scalar verb at nth 1..N, which my sabotage does not touch, so the series is measured against 3 independent numbers with no shared code.
* MT9c second-derivation row -- `mt_rt_derive` over the Tcl element-wise product of the two committed columns; no engine in it at all.
* MT9c third-point row -- its `same` leg against `$rtDY`.
* WD13 keystone -- `wd_sized $apts [llength $rDY]` reads the DESTINATION's own `xschem raw points 0` after switching into it: `{pts:2 want:3}`. This is what also catches the wrapper-layer off-by-one that MT9c cannot see.
* WD13 "the X the destination holds is calc::cross's OWN low-crossing list".
* WD13 third-point row -- its `same` leg on the READ-BACK.

TWO BANDS THAT ARE BLIND TO IT, worth knowing because a reader might expect them to fire:
* MT9b's four MOVED rows are all GREEN under the primary sabotage. Their series leg is `mt_atleast ... 2`, which a 2-point series satisfies. So the four rows the author "moved rather than deleted" do NOT fence this class -- MT9c's derived `mt_sized` legs are the whole fence. That is correct design (MT9b is about the deferral being retired, not about the series length) but it means the moved rows buy nothing against an off-by-one.
* MT9c's "the series DISCRIMINATES" row is GREEN under the primary sabotage: two points are still all-distinct and still increasing. So the distinctness row is not an off-by-one fence either.

THE ONE NARROWNESS I FOUND, and it is a SINGLE-ROW DEPENDENCY reached by a far more plausible bug than the author's: the LENGTH-PRESERVING variant (`set xh {}` hoisted out of the loop -- a forgotten loop-local reset, which is an ordinary slip rather than a contrived padder) is caught by EXACTLY ONE row in the whole tree, MT9c's partial-drop row, with `test_calc_wave_dest` at `ALL PASS (124 checks)`. The author declared this scoping for their synthetic sabotage `K_padded`; what is new is that the same single row is also the only thing standing between the user and a **negative rise time** (`-0.002887902076229785` reached the answer). Nothing asserts that a rise time is positive, anywhere, at either layer.
  * What would close it: a `riseTime`-specific non-negativity leg on the SERIES -- every Y strictly greater than zero -- on the main three-edge request in MT9c's keystone, and on the read-back Y in WD13's keystone. It costs no new row (two extra legs on rows that already exist, so the published check count does not move) and it is derived rather than written down (`a > 0` over the answer's own list). A negative element in a rise-time series is unphysical whatever the fixture, so unlike the distinctness legs it cannot go vacuous on a regenerated fixture. That single addition would take the padded shape from one catcher to three, and would catch it in `test_calc_wave_dest` too, where today it is invisible.



## attack:wrong-x

**sabotage**

WRONG-X BY PAIRING DIRECTION (`S5_pairhigh`), in `calc::riseTime`'s new `nth`-0 series arm.

The honest arm iterates the LOW-crossing list and pairs each low crossing with the first high crossing after it, with X = that low crossing:

```tcl
foreach xlo [dict get $la value] {
    set xhi {}
    foreach x [dict get $lb value] { if {$x > $xlo} { set xhi $x ; break } }
    if {$xhi eq {}} { continue }
    lappend sxs $xlo
    lappend sys [expr {$xhi - $xlo}]
}
```

The sabotage reverses the drive and iterates the HIGH list, pairing each high crossing with the last low crossing before it:

```tcl
foreach xhi [dict get $lb value] {
    set xlo {}
    foreach x [dict get $la value] { if {$x < $xhi} { set xlo $x } else { break } }
    if {$xlo eq {}} { continue }
    lappend sxs $xlo
    lappend sys [expr {$xhi - $xlo}]
}
```

It is plausible precisely because it LOOKS right in every respect the recon receipt names: X is still a LOW crossing (never a high crossing, never a midpoint, never reversed), Y is still `xhi - xlo`, the dropped-point rule still falls out of the `continue`, and the empty series still reaches `calc::cross_absent`. It is also the shape a competent engineer reaches for naturally, because `calc::riseTime` ALREADY materialises the full high list with a literal 0 (`set b [calc::cross $rpn $lhi 0 rising $dataset]`) and leaving that as the outer loop is the smaller edit. The semantic difference is one sentence: it answers one point per COMPLETED TRANSITION instead of one point per RISING EDGE.

Everything else in the unit is the honest implementation (the `returns` re-spelling to `scalar/wave`, the wrapper `calc::riseTime_scalar` with `calc::riseTime`'s own formals in order, X-first to `calc::wave_dest`, the `{db type xname yname n}` merge plus `shape wave`), so the sabotage is one loop and nothing else.

ALSO TESTED AND ALSO SURVIVING, harm NOT proven, reported as an observation and not a finding: `S6_xcolname`, naming the destination's X column `time` instead of `calcx` (`calc::wave_dest [dict get $m sweep] [dict get $m value] time calcy`) "so the viewer resolves the right axis" -- `ALL PASS (124 checks)` / `ALL PASS (183 checks)`. Every row reads `xname` OUT OF the answer and then reads that column from INSIDE the destination after switching into it, so no row can see a name collision with the loaded tran database's own `time` column (issue 1644's family). I did not demonstrate user-visible harm for it, so it is flagged rather than claimed.

Final worktree state is the S5 sabotage. The honest implementation is kept at `/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/wrongx/calculator.HONEST.tcl`.

**why_wrong**

A user measures the rise time of ONE rising edge that has overshoot ringing -- the commonest real transient there is -- and gets THREE rise times back, all plotted at the SAME X.

Correct behaviour is one rise time per rising edge. The sabotage emits one per high-threshold crossing, so an edge that rings above and back below the 90% level before settling produces several points whose X is the SAME low crossing. On the plotted strip that is a vertical stack of points at one X instead of one point, the X series is not strictly increasing, and the reported edge count is wrong (3 where the signal has 1 edge). The two later Y values are not rise times at all -- they are the time from the edge's start to the second and third ring peaks (2.39e-3 and 4.24e-3 against the real 3.76e-4, a factor of 6 and 11 out).

PROVEN ON THE COMMITTED FIXTURE with an ordinary RPN, no new fixture and no synthetic data. The request is a damped step, `y = 1 - exp(-500t)cos(3000t)`, spelled `{1 0 time 500 * - exp() time 3000 * cos() * -}`, at `lo=0 hi=1 pctlo=10 pcthi=90`. `calc::cross` answers ONE low crossing at 0.1 and THREE high crossings at 0.9:

    non-vacuity: nlow=1 nhigh=3

    HONEST    sweep = {0.00010539931993072891}
              value = {0.0003760108928609481}
              sweep is increasing, n=1

    SABOTAGE  sweep = {0.00010539931993072891 0.00010539931993072891 0.00010539931993072891}
              value = {0.0003760108928609481 0.002393781655854132 0.004243049433884933}
              sweep is notincreasing:1, n=3

Measured at four level pairs (10/90, 10/80, 20/90, 5/95); the sabotage answers 3, 2, 3 and 3 points where the truth is 1 at every one.

The converse shape also diverges and is equally real -- a signal that dips below the 10% level and comes back up without reaching 90% (two lows, one high) gives the correct 2 points and the sabotage 1, so a transition is silently LOST rather than duplicated. Measured over crossing lists: `L={1 2} H={3}` -> correct `X={1 2}`, sabotage `X={2}`.

WHY IT IS INVISIBLE TO THE BAND, which is the finding rather than the sabotage. Every X leg in both new bands is driven on ONE request, `{v(sq) v(ramp) *}` at 10/90, where the two crossing lists interleave strictly 1:1 -- lows `{9.2e-4, 4.904e-3, 8.902e-3}`, highs `{1.0667e-3, 4.936e-3, 8.92e-3}`, alternating low-high-low-high-low-high. When `nlow == nhigh` and the lists strictly alternate, the two pairing directions are provably THE SAME LIST, element for element. The partial-drop row (`{v(lp)} 0 1 10 99.9 0`, nlow=3 nhigh=2) cannot separate them either, and for a structural reason worth writing down: a dropped point is always a SUFFIX of the low list -- if `low[i]` has no high after it then neither does any later low -- so both directions agree there too. Neither band ever drives `nhigh > nlow`, which is the only shape that separates them.

So the band's X fence is genuinely tight against WRONG VALUES and completely open to a wrong PAIRING RULE, and the receipt's claim that the keystone's X leg catches "a producer that put the HIGH crossings, the midpoints or the rise times themselves on the X axis" is true and is not the whole space of wrong X.

**verdict**

SURVIVED

**evidence**

All runs from the repo root of the isolated worktree `/home/analog/dev/xschem-claude/.claude/worktrees/wf_26c2c6d6-0fa-3`, armed spelling, binary built in this worktree.

=== RED BASELINE REPRODUCED (product byte-identical to HEAD; `git diff --stat -- src/` no output) ===
  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
  test home: throwaway /tmp/xschem-test-home.3495656... (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (113 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 13 FAILED (170 passed)
  RESULT: 0/2 runs passed
(matches the suite author's receipt exactly: 11 and 13)

=== GREEN REACHABLE -- the honest J2 implementation ===
  PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (124 checks)
  PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (183 checks)
  RESULT: 2/2 runs passed
(matches the author's predicted 124 / 183)

=== THE THREE WRONG-X SHAPES THE BRIEF NAMED -- ALL CAUGHT ===
  S1_highx   X = the HIGH crossing (the edge's END) instead of the LOW one
    FAIL     | test_calc_wave_dest          run 1/2  RESULT: 2 FAILED (122 passed)
    FAIL     | test_calc_measure            run 2/2  RESULT: 3 FAILED (180 passed)
    RESULT: 0/2 runs passed
  S2_midx    X = the MIDPOINT of the transition
    FAIL     | test_calc_wave_dest          run 1/2  RESULT: 2 FAILED (122 passed)
    FAIL     | test_calc_measure            run 2/2  RESULT: 3 FAILED (180 passed)
    RESULT: 0/2 runs passed
  S3_swap    `value` and `sweep` handed to calc::wave_dest in the WRONG ORDER
    FAIL     | test_calc_wave_dest          run 1/2  RESULT: 6 FAILED (118 passed)
    PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (183 checks)
    RESULT: 1/2 runs passed
    (note: my sed hit BOTH wrapper call sites, so this figure includes dutyCycle_scalar's;
     the author's own J1-scoped figure for the same shape is 3 FAILED)
  S4_revx    the X list written BACKWARDS
    FAIL     | test_calc_wave_dest          run 1/2  RESULT: 2 FAILED (122 passed)
    FAIL     | test_calc_measure            run 2/2  RESULT: 4 FAILED (179 passed)
    RESULT: 0/2 runs passed

  Rows that fire on S1 / S4 (verbatim row-name heads):
    FAIL: WD13 R419/R415 riseTime_scalar's nth 0 stops deferring and answe...
    FAIL: WD13 ...and the X the destination holds is calc::cross's OWN low...
    FAIL: MT9c R419/R416 riseTime with nth 0 MEASURES the per-edge series ...
    FAIL: MT9c ...and a SECOND derivation with no engine in it agrees: the...
    FAIL: MT9c the series DISCRIMINATES, and the CONTROL is the two column...   (S4 only)
    FAIL: MT9c a low crossing with NO high crossing after it DROPS THAT PO...

=== S5_pairhigh -- MY SABOTAGE -- SURVIVES EVERYTHING ===
counted arm, five Calculator suites:
  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse
  test home: throwaway /tmp/xschem-test-home.3512713.kUx19G (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  PASS     | test_calc_wave_dest          run 1/5  RESULT: ALL PASS (124 checks)
  PASS     | test_calc_measure            run 2/5  RESULT: ALL PASS (183 checks)
  PASS     | test_calc_cross              run 3/5  RESULT: ALL PASS (187 checks)
  PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
  PASS     | test_calc_scratch_reuse      run 5/5  RESULT: ALL PASS (56 checks)
  RESULT: 5/5 runs passed

display arm, four Calculator suites:
  $ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
  PASS     | test_calc_skeleton           run 1/4  RESULT: ALL PASS (579 checks)
  PASS     | test_calc_plot               run 2/4  RESULT: ALL PASS (114 checks)
  PASS     | test_calc_widgets            run 3/4  RESULT: ALL PASS (259 checks)
  PASS     | test_calc_buffer             run 4/4  RESULT: ALL PASS (130 checks)
  RESULT: 4/4 runs passed

Every one of those nine check counts is IDENTICAL to the honest implementation's. Zero rows
moved on either arm. `/usr/bin/grep -cE 'UNEXPECTED ERROR|BGERROR|ABORTED|another regression
run is live'` answers 0 on the final transcript, so no band was abandoned and the run was solo.

=== S6_xcolname -- A SECOND SURVIVOR (harm unproven, flagged not claimed) ===
  PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (124 checks)
  PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (183 checks)
  RESULT: 2/2 runs passed

=== THE DEFECT, MEASURED ON THE COMMITTED FIXTURE ===
RPN `{1 0 time 500 * - exp() time 3000 * cos() * -}`, lo=0 hi=1 pctlo=10 pcthi=90, dataset 0:
  lows  @0.1 : 0.00010539931993072891
  highs @0.9 : 0.000481410212791677 0.002499180975784861 0.004348448753815661
  HONEST    PRODUCT riseTime nth 0 : sweep={0.00010539931993072891}
            PRODUCT riseTime nth 0 : value={0.0003760108928609481}
            PRODUCT sweep is increasing, n=1
  SABOTAGE  PRODUCT riseTime nth 0 : sweep={0.00010539931993072891 0.00010539931993072891 0.00010539931993072891}
            PRODUCT riseTime nth 0 : value={0.0003760108928609481 0.002393781655854132 0.004243049433884933}
            PRODUCT sweep is notincreasing:1, n=3

Pairing directions over crossing lists, showing where they agree and where they do not:
  fixture-shape        L={1 5 9} H={2 6 10}    IDENTICAL=1
  ringing-at-the-top   L={1}     H={2 3}       IDENTICAL=0  correct X={1}      sabotage X={1 1}
  two-lows-one-high    L={1 2}   H={3}         IDENTICAL=0  correct X={1 2}    sabotage X={2}
  ring-in-mid-series   L={1 5 9} H={2 3 6 10}  IDENTICAL=0  correct X={1 5 9}  sabotage X={1 1 5 9}

=== THE PROPOSED LEG, DRIVEN BOTH WAYS ===
  UNDER THE SABOTAGE
    non-vacuity: nlow=1 nhigh=3   nhigh-exceeds-nlow = 1
    got -> {measured {n:3 want:1} {n:3 want:1} notincreasing:1}
    exp    {measured sized sized single:1}
    VERDICT: FAIL
  UNDER THE HONEST IMPLEMENTATION
    non-vacuity: nlow=1 nhigh=3   nhigh-exceeds-nlow = 1
    got -> {measured sized sized single:1}
    exp    {measured sized sized single:1}
    VERDICT: PASS

=== HYGIENE ===
  $ git status --short
   M src/calculator.tcl
   M tests/headless/test_calc_measure.tcl
   M tests/headless/test_calc_wave_dest.tcl
Nothing committed, nothing pushed, no full T1, owed.sh ledger untouched. `~/dev/xschem-op-wcard`,
`~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate` never
written; `devdisplay.sh start|stop|view` never run -- the display-arm readings ATTACHED to the
already-running `:99` with GUI_GATE=0 and a throwaway HOME and left it as found. Every binary
call carried `--nogui` or `env -u DISPLAY`; no bare `xschem`; `/usr/bin/grep` throughout;
`AUDIT_SCREEN` left at its default. `src/calculator.tcl` answers `info complete` = 1. No
`switch` was touched and no comment sits between two patterns in my edits. Scratch 460K,
`/tmp` at 772M of 7.7G.

NOTE ON WORKTREE SETUP: the worktree arrived checked out at `052b29f1` ("Add Claude Code GitHub
Actions workflow"), which has no `tests/headless/test_calc_*` and no `doc/claude/calculator_batch/`
at all. I reset the worktree's own branch to the `fluid-editing` tip `580f1622` and copied in the
two uncommitted suite files from the main checkout; `git diff --stat` on them then reproduced the
author's receipt figures exactly (626 / 322 insertions), and the red baseline reproduced at 11/13.
`./configure` and `make -C src` were run here because the worktree had no binary.

**which_row_caught_it**

NOTHING CAUGHT IT. Nine suites, both arms, every check count unmoved.

THE ROW THAT SHOULD HAVE CAUGHT IT ALREADY HOLDS THE RIGHT PREDICATE AND IS BLIND ONLY BECAUSE OF ITS INPUT. Two rows are one argument away:

1. `WD13 ...and the X the destination holds is calc::cross's OWN low-crossing list...` -- its fifth leg is `[wd_increasing $apx]`, which is EXACTLY the predicate that names this defect (`notincreasing:1`). It cannot fire because the band's single request has three distinct, strictly increasing low crossings whichever direction the producer pairs from.

2. `MT9c R419/R416 riseTime with nth 0 MEASURES the per-edge series instead of deferring...` -- it already sizes the series against `$rtNLOW`, the LOW-crossing count read back off `calc::cross` with a literal 0, which is the correct discipline. It cannot fire because on `{v(sq) v(ramp) *}` at 10/90 `nlow == nhigh == 3`, so sizing against the low count is indistinguishable from sizing against the high count.

The band's own comment states the hazard it guarded against -- a fixture whose Y values are too close to discriminate -- and answered it by choosing a column with widely separated values. The hazard it did not see is a different one: a fixture whose two CROSSING LISTS are too regular to discriminate. Lows `{9.2e-4, 4.904e-3, 8.902e-3}` and highs `{1.0667e-3, 4.936e-3, 8.92e-3}` interleave strictly 1:1, and under strict 1:1 interleaving the two pairing directions are provably the same list. The partial-drop row is no help: a dropped point is always a SUFFIX of the low list, because if `low[i]` has no high after it then no later low does either, so both directions agree there as well. Across both bands the relation `nhigh > nlow` is never driven, and that is the only shape that separates them.

WHAT IT WOULD TAKE -- one more request, measured in both directions rather than argued:

Add to MT9c (and, for the hand-off, to WD13) a row driving a RINGING rising edge, where the high threshold is crossed more often than the low one. It needs no new fixture: `{1 0 time 500 * - exp() time 3000 * cos() * -}` -- a damped step, `y = 1 - exp(-500t)cos(3000t)` -- at `lo=0 hi=1 pctlo=10 pcthi=90` gives `nlow=1 nhigh=3` on the committed `calc_fixture.raw`.

Legs, all in the band's existing idiom with helpers it already has:
  * `mt_sized [mt_len [mt_val $a]] $nlow`   -- the series is sized against the LOW-crossing count
  * `mt_sized [mt_len [mt_key $a sweep]] $nlow`
  * a NON-VACUITY leg asserting `nhigh > nlow`, both counts read off `calc::cross` with a literal 0 -- without it the row is satisfiable by any request and measures nothing
  * on the destination side, `wd_increasing $apx` on a request shaped so the duplication is visible

Driven both ways in this session, so the recommendation is a measurement and not a suggestion:
  under the sabotage  got -> {measured {n:3 want:1} {n:3 want:1} notincreasing:1}   FAIL
  under honest code   got -> {measured sized sized single:1}                        PASS
  non-vacuity in both runs: nlow=1 nhigh=3

A sharper variant, if a three-point X that duplicates is wanted rather than a one-point one, is a request giving `nlow=3 nhigh=4`: there the sabotage answers `X={L1 L1 L2 L3}`, which moves BOTH the length leg and the `increasing` leg at once. The `nlow=1 nhigh=3` request above is the one I measured and is sufficient.

COST: this moves the two published check counts the stage already moves (`test_calc_measure` 183, `test_calc_wave_dest` 124), by +1 or +2 each. Per CLAUDE.md a published check count is NOT a baseline -- every site carrying it recomputes it -- and no trailer term moves, since both suites are already in `hcases`. This batch has twice closed a surviving sabotage over exactly that objection.

SECOND, WEAKER ITEM: `S6_xcolname` also survives (`ALL PASS (124)` / `ALL PASS (183)`). No row can see the destination's X column NAME, because every row reads `xname` out of the answer and then reads that column from inside the destination after switching into it. Closing it would mean asserting `xname` against a literal or at least against a pattern that excludes the loaded database's own sweep names. I did NOT prove user-visible harm for it and do not claim it as a defect; it is reported so somebody can decide whether the name is load-bearing for `wviewer::resolve_signal_db`.

NOTHING IS RUNNING NOW.



## attack:absence-as-refusal

**sabotage**

Two forms of the assigned absence-as-refusal sabotage, both implemented in `src/calculator.tcl` in my worktree. Both wire J2 the way `calc::dutyCycle_scalar` does: `calc::riseTime`'s `nth`-0 arm replaces the issue-1639 deferral and computes the per-edge series (`value` = Y, `sweep` = the low-crossing X, a point with no high crossing after it dropped), and a new `calc::riseTime_scalar` with the verb's own seven formals hands `sweep` then `value` to `calc::wave_dest`, propagates a destination refusal through `calc::cross_refusal`, and merges `{db type xname yname n}` plus `shape wave`. The catalogue's `riseTime` row was re-spelled `scalar` -> `scalar/wave`.

FORM 1 -- exactly as assigned: NO absence branch anywhere. An empty series is handed to `calc::wave_dest`, which refuses with `destempty`.

FORM 2 -- the same sabotage with the guard moved by one line: the absence is tested on the two INPUT crossing lists (`![llength [dict get $a value]] || ![llength $highs]`) instead of on the OUTPUT series. It carries a comment explaining itself, so it reads as deliberate care about the empty case. Verbatim at `calc::riseTime`:

        set highs [dict get $b value]
        if {![llength [dict get $a value]] || ![llength $highs]} {
            return [calc::cross_absent \
                        [calc::cross_msg nohigh [calc::cross_ordinal 0]] \
                        [dict get $b dataset] [dict get $b dest]]
        }

**why_wrong**

The user asks for the rise time of every edge, their request never completes a transition, and they read a sentence blaming the destination instead of being told their signal never got there: "Destination: an empty result has nothing to put in a destination, so none was built."

FORM 1 reaches that on the two shapes the driver named -- no low crossing at all (`riseTime {v(sq)} 100.0 200.0 10 90 0`, `nlow=0 nhigh=0`) and low crossings with no high after any of them (`{v(lp)} 0 1 10 99.95 0`, `nlow=3 nhigh=0`).

FORM 2 reaches it on a THIRD shape nothing drives: both crossing lists NON-EMPTY and the series still empty, because no high crossing follows any low one. Measured on the committed `tran` fixture, two spellings of it:

  riseTime_scalar {v(ramp)} 1 0 10 90 0        (negative swing: the levels typed high-then-low)
      llo=0.9 lhi=0.09999999999999998 nlow=1 nhigh=1 serieslen=0
      verb_ok=1 verb_absent=0  surf_ok=0 surf_absent=0
      surf_msg={Destination: an empty result has nothing to put in a destination, so none was built.}

  riseTime_scalar {v(ramp)} 0 1 90 10 0        (percentages swapped)
      llo=0.9 lhi=0.1 nlow=1 nhigh=1 serieslen=0  -- same answer, same sentence

THE DECISIVE ASYMMETRY, measured on the same request: the SHIPPED named-occurrence path, which FORM 2 does not touch, already calls this an absence.

  SHAPE_D_negswing-nth1 verb_ok=0 verb_absent=1 surf_ok=0 surf_absent=1
      msg={Rise time: the 1st low crossing has no high crossing after it in this sweep.}

So one request, one cause, two sentence families: `nth 1` says "Rise time: ... has no high crossing after it", `nth 0` says "Destination: an empty result ...". The second is precisely what the driver ruled wrong, and it ships green.

**verdict**

CAUGHT as assigned (FORM 1). SURVIVED as FORM 2 -- the same sabotage class with the guard one line further up, which passes EVERY suite in the batch on both arms.

**evidence**

Armed spellings only, repo root of my worktree, `src/xschem` the main tree's binary copied in (gitignored; `XSCHEM_SHAREDIR` resolves from `exe_path`, so it loads my worktree's `src/calculator.tcl` -- confirmed by the suites resolving `calc::riseTime_scalar` instead of `NOPROC:`).

########## FORM 1 -- the assigned sabotage: CAUGHT ##########
$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
test home: throwaway /tmp/xschem-test-home.3504655.JRbMdD (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (124 checks)
FAIL     | test_calc_measure            run 2/2  RESULT: 2 FAILED (181 passed)
RESULT: 1/2 runs passed
(exit 1; reproduced twice, identical)

The two failing rows, verbatim got/exp tails -- both MT9c absence rows and nothing else:
-> {measured 0 unknown:NOFAMILY:{} elsewhere empty sized NOKEY-db refused 1 samefamily:Destination} (exp {absent 0 known elsewhere ok sized NOKEY-db absent 0 elsewhere}) : FAIL
-> {measured 0 unknown:NOFAMILY:{} elsewhere atleast1 sized NOKEY-db refused 1 samefamily:Destination} (exp {absent 0 known elsewhere atleast1 sized NOKEY-db absent 0 elsewhere}) : FAIL

Both are byte-identical to what the suite author's receipt predicted for their `J_destempty`, which is independent reproduction. The author's own measurement is confirmed in both directions: `NOKEY-db` is GREEN in both tails (a `destempty` refusal carries no `db` either), so the three SURFACE legs are what name the defect -- `refused 1 samefamily:Destination` against `absent 0 elsewhere`. `test_calc_wave_dest` ALL PASS is correct scoping, as declared.

########## FORM 2 -- same class, guard on the INPUT lists: SURVIVED ##########
$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
test home: throwaway /tmp/xschem-test-home.3507524.Vdz51p (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (124 checks)
PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (183 checks)
RESULT: 2/2 runs passed
(exit 0 -- and 124/183 are exactly the author's published green counts)

$ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_cross test_calc_engine test_calc_scratch_reuse
PASS     | test_calc_cross              run 1/3  RESULT: ALL PASS (187 checks)
PASS     | test_calc_engine             run 2/3  RESULT: ALL PASS (265 checks)
PASS     | test_calc_scratch_reuse      run 3/3  RESULT: ALL PASS (56 checks)
RESULT: 3/3 runs passed

$ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_calc_skeleton           run 1/4  RESULT: ALL PASS (579 checks)
PASS     | test_calc_plot               run 2/4  RESULT: ALL PASS (114 checks)
PASS     | test_calc_widgets            run 3/4  RESULT: ALL PASS (259 checks)
PASS     | test_calc_buffer             run 4/4  RESULT: ALL PASS (130 checks)
RESULT: 4/4 runs passed

Every figure matches the author's published green exactly, with the `returns` re-spelling in (S24's closed vocabulary already holds `scalar/wave`, so nothing widened). FORM 2 is a complete, fully green J2 that still ships the defect.

########## the leak, under FORM 2, from a throwaway probe suite ##########
SHAPE_A llo=110.0 lhi=190.0 nlow=0 nhigh=0 verb_absent=1 surf_absent=1 surf_msg={Rise time: the 0th low crossing has no high crossing after it in this sweep.}
SHAPE_B llo=0.1 lhi=0.9995 nlow=3 nhigh=0 verb_absent=1 surf_absent=1 surf_msg={Rise time: the 0th low crossing has no high crossing after it in this sweep.}
SHAPE_D_swapped_pct llo=0.9 lhi=0.1 nlow=1 nhigh=1 serieslen=0 verb_ok=1 verb_absent=0 surf_ok=0 surf_absent=0 surf_msg={Destination: an empty result has nothing to put in a destination, so none was built.}
SHAPE_D_negswing llo=0.9 lhi=0.09999999999999998 nlow=1 nhigh=1 serieslen=0 verb_ok=1 verb_absent=0 surf_ok=0 surf_absent=0 surf_msg={Destination: an empty result has nothing to put in a destination, so none was built.}
SHAPE_D_negswing-nth1 verb_ok=0 verb_absent=1 surf_ok=0 surf_absent=1 msg={Rise time: the 1st low crossing has no high crossing after it in this sweep.}

Probe suite kept at /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/adv/probe_suite.tcl and REMOVED from tests/headless/ (it would otherwise be reached by full_audit.sh). Transcripts: run_v1.txt, run_v2.txt, probe_out.txt in the same directory.

########## housekeeping ##########
Worktree arrived at 052b29f1, an unrelated commit NOT on fluid-editing; reset to 580f1622 (the branch tip) and the author's two uncommitted suites copied in from the main tree byte-for-byte. `git status --short` at the end: `M src/calculator.tcl`, `M tests/headless/test_calc_measure.tcl`, `M tests/headless/test_calc_wave_dest.tcl` -- the two suites unmodified by me. `info complete` on the edited `src/calculator.tcl` = 1. No `switch` touched; no comment between two patterns. Nothing committed, pushed or gated; no full T1; owed.sh ledger untouched; `~/dev/xschem-op-wcard`, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate` never written; `devdisplay.sh start|stop|view` never run -- the display arm ATTACHED to the running `:99` and was left as found. No bare `xschem`; every call carried `env -u DISPLAY` or the armed `run_suites.sh`. `/usr/bin/grep` throughout. NOTHING IS RUNNING NOW.

**which_row_caught_it**

CAUGHT FORM 1: the two MT9c absence rows in `tests/headless/test_calc_measure.tcl` -- "a swing the signal never reaches at all answers an ABSENCE and not a destination problem" and "...and the OTHER empty shape". Nothing else in either suite sees it: `test_calc_wave_dest` is ALL PASS (124), exactly as the author declared.

WHAT SHOULD HAVE CAUGHT FORM 2 AND DOES NOT. Both MT9c absence rows pin their shape with a non-vacuity leg on a CROSSING-LIST count -- row 1 `mt_sized [mt_rt_nlo $ed] 0`, row 2 `mt_atleast nlo 1` plus `mt_sized [mt_rt_nhi $ed] 0`. Those are precisely the two conditions `nlow == 0` and `nhigh == 0`, which are precisely the two tests a plausible input-side guard writes. So the rows are keyed to the two shapes a *correct* implementation distinguishes, and the complement -- both lists non-empty, series empty -- is driven by nothing in the tree. The fence is on the two shapes, not on the class.

And WD13 structurally cannot help, which is worth stating because its control row looks like it should. `wd_disp` in `test_calc_wave_dest.tcl` has NO `absent` arm at all -- it returns `measured` on `ok 1` and `refused` otherwise -- so WD13's control row leg `[wd_disp [wd_call riseTime_scalar {v(sq)} 100.0 200.0 10 90 0]]` expects the literal word `refused` and is green on a true absence AND on a `destempty` refusal alike; its partner leg `[wd_key $d db]` reads `NOKEY-db` for both. Those two legs are green under every member of this class, including FORM 1.

THE ROW THAT WOULD CLOSE IT, and the author already built the instrument for a sibling claim without applying it here. Row "MT9c T2" uses the shipped ordinal path as the oracle for the VALUES -- "the series IS the scalar path, edge by edge ... shares no code with the series arm". The same move closes the whole absence class in ONE row and needs no third hand-picked shape: for a request whose derived series is empty, require `nth` 0's disposition AND its sentence FAMILY to agree with the SAME request at `nth` 1. Measured above: under correct code both are absences in a `cross_msg` family that is not `destempty`'s; under FORM 1 they differ (`measured`/`NOFAMILY` vs `absent`/`Rise time`), and under FORM 2 they differ on SHAPE_D (`refused`/`Destination` vs `absent`/`Rise time`). It is a derivation over the shipped ordinal path, so it cannot rot into a list of shapes.

The weaker, shape-specific alternative is a third absence row driving `riseTime {v(ramp)} 1 0 10 90 0` with non-vacuity legs `nlow >= 1`, `nhigh >= 1` and derived series length exactly 0 -- it catches FORM 2 today but leaves the class open to the next shape nobody enumerated.

Either costs +1 check on `test_calc_measure` (183 -> 184) and moves no trailer term, and CLAUDE.md records that a published check count is not a baseline -- it is a figure `OVERALL:`, `RESULT:` and `summarize_all` all recompute. This batch has twice chosen to move one rather than leave a sabotage unfenced, which is the precedent.

One honest qualification I will not hide: SHAPE_D is a malformed request (reference levels swapped, or percentages swapped). It is still the ruling's own target, because the ruling is that an absence must not be reported as a destination problem, and the SHIPPED `nth 1` path already gives that same request the absence sentence. A user who swaps their levels currently learns "the 1st low crossing has no high crossing after it" and, after FORM 2 lands, learns "an empty result has nothing to put in a destination" for the identical mistake.



## repair:j2


### survivors

- **ATTACK 2 -- `S5_pairhigh`, the WRONG PAIRING DIRECTION inside `calc::riseTime`'s new `nth`-0 arm.** The producer drives the HIGH crossing list and pairs each high crossing with the last low crossing before it, instead of driving the LOW list and pairing each low crossing with the first high crossing after it. It answers one point per COMPLETED TRANSITION where a rise time is one per RISING EDGE. Reproduced here in full: against an honest J2 both suites are `ALL PASS (124)` / `ALL PASS (183)` and against the sabotage they are the IDENTICAL `124` / `183`, with `cross` 187, `engine` 265, `scratch_reuse` 56 and the four display-arm suites 579 / 114 / 259 / 130 all unmoved. The adversary's diagnosis is confirmed by measurement and it is structural, not a tuning accident: on the band's own request `{v(sq) v(ramp) *}` at 10/90 the low list `{9.2e-4 4.904e-3 8.902e-3}` and the high list `{1.07e-3 4.936e-3 8.92e-3}` INTERLEAVE strictly one for one, and under strict 1:1 interleaving the two pairing directions are provably the same list; the partial-drop request cannot separate them either, because a dropped point is always a SUFFIX of the low list (if `low[i]` has no high after it, no later low has one). Across both new bands the relation `nhigh > nlow` was never driven, and that is the only shape that separates them. CLOSED by one new row -- see `rows_added` -- which reddens with `{n:6 want:3}`, `dup:3-of-6` and `notincreasing:1`.

- **ATTACK 3 -- `FORM 2`, the ABSENCE GUARD ON THE INPUT CROSSING LISTS instead of on the OUTPUT series.** `if {![llength [dict get $a value]] || ![llength $highs]}` in place of `if {![llength $ys]}`, one line further up, carrying a comment that reads as care about the empty case. It is a complete, fully green J2 that still ships the defect the driver's own ruling forbids: for a request whose two crossing lists are BOTH non-empty and whose series is still empty, the empty lists reach `calc::wave_dest` and the user reads *"Destination: an empty result has nothing to put in a destination, so none was built"* where the truth is that the signal never completed a transition. Reproduced here: `ALL PASS (124)` / `ALL PASS (183)` on the counted arm plus 187 / 265 / 56, i.e. the author's published green figures exactly. The adversary's root cause is confirmed and is the sharpest thing in the three attacks: the two existing absence rows pin their shapes with crossing-list COUNT legs -- one asserts the low list is empty, the other that the high list is -- and those are PRECISELY the two tests an input-side guard writes, so the rows are keyed to the two shapes a correct implementation distinguishes and the complement is driven by nothing. Measured reachable shape on the committed fixture: `riseTime {v(ramp)} 1 0 10 90 0` -> `llo=0.9`, `lhi=0.1`, `nlow=1`, `nhigh=1`, series length 0, because the only high crossing lies BEFORE the only low one. The shipped ordinal path already calls that same request an absence (`nth 1` -> `absent`, *"Rise time: the 1st low crossing has no high crossing after it in this sweep."*). CLOSED by one new row that uses that shipped path as its ORACLE.


### rows_added

- **ROW 1 -- `tests/headless/test_calc_measure.tcl`, band MT9c, inserted immediately AFTER the keystone row** (so the keystone's claim *"the X is `calc::cross`'s own low-crossing list"* is followed at once by the request on which that claim has teeth).

NAME: *"MT9c THE PAIRING DIRECTION, on the one shape that can see it: a signal that RINGS at the top crosses its HIGH threshold more often than its LOW one, and a rise time is one measurement per RISING EDGE -- so the series is sized against the LOW-crossing count, its X is the low-crossing list element for element, no two of its points share an X, and the X is strictly increasing. Three non-vacuity legs say the shape really is the one that discriminates: more than one edge, the high level crossed strictly more often than the low one, and not one point dropped -- so a producer that drove the HIGH list, pairing each high crossing with the last low before it, reddens on the count AND on the duplicated X instead of passing as it does on every other request in this band"*

THE REQUEST IS MINTED, because no committed column has `nhigh > nlow` at any level pair -- measured across all ten columns by the suite author and re-measured here. It is `-(sin x + sin 3x / 2)` clamped below, which has a DOUBLE-HUMPED positive half (one rising edge whose 90% level is crossed twice: overshoot ringing, the commonest real transient there is) and whose antisymmetric negative half would add a second LOW crossing per period -- so the negative half is clamped at a floor ABOVE that half's own dip, merging the whole sub-threshold region into one flat block and leaving exactly one rising crossing of the low level per period. The floor doubles as the request's `lo`, which is what a signal's low rail is. **The angular frequency is read back from the sweep column's OWN endpoints every run** (`mt_ringw`), so no period is written down anywhere -- `wd_acrpn`'s discipline in the sibling suite, for the same reason. MEASURED on the committed fixture at `lo=-0.3 hi=1 10/90`: `nlow=3`, `nhigh=6`, all three lows complete; LOW-driven X `{1.628e-3 4.943e-3 8.291e-3}` and Y `{2.5896e-4 2.8007e-4 2.6797e-4}` (adjacent relative 8.2e-2 and 4.3e-2, five orders outside MTTOL) against HIGH-driven X `{l1 l1 l2 l2 l3 l3}` and six Y values.

TEN LEGS, in order: the ENGINE's own column of that expression agrees with the Tcl-side one (asserted in the run -- measured worst relative disagreement 1.1e-14, so the two derivations cannot silently become one); the disposition is `measured`; **three NON-VACUITY legs** -- more than one edge (`atleast2`), the high level crossed strictly more often than the low one (`mt_excess ... 1`), and the derived series as long as the low list, i.e. not one point dropped; the series sized against the LOW-crossing count; the Y element for element against the Tcl derivation; the X element for element against the Tcl derivation; **no two points share an X** (`mt_nodup`, the one X-axis claim that is non-vacuous at ANY length, where `mt_increasing` and `mt_alldistinct` both answer `tooshort:1` on a one-point series); and the X strictly increasing.

RED ON THE UNTOUCHED TREE, verbatim from the armed run:
`-> {same refused atleast2 atleast1 sized {n:1 want:3} refused {count=1 want=3 got={NOKEY-sweep}} nodup tooshort:1} (exp {same measured atleast2 atleast1 sized sized ok ok nodup increasing}) : FAIL`
Note the first five legs: the engine/Tcl agreement and all three non-vacuity legs are GREEN on the red run, which is what proves the minted shape really is the discriminating one rather than asserting it in prose.

RED UNDER `S5_pairhigh`, verbatim, and it is the ONLY failing row in either suite:
`-> {same measured atleast2 atleast1 sized {n:6 want:3} {count=6 want=3 got={0.00025896410621851725 0.0011520614982852906 0.00028006995107610847 0.0011717368142693634 0.0002679712619799244 0.0011583248338392273}} {count=6 want=3 got={0.001628478720832479 0.001628478720832479 0.004943333333333332 0.004943333333333332 0.008290580452878223 0.008290580452878223}} dup:3-of-6 notincreasing:1} (exp {same measured atleast2 atleast1 sized sized ok ok nodup increasing}) : FAIL`
FIVE legs fire and the X leg names every offending element, including the three duplicated low crossings. GREEN under the honest implementation.

- **ROW 2 -- `tests/headless/test_calc_measure.tcl`, band MT9c, inserted immediately AFTER the second absence row** and before the family-instrument row, because it is the THIRD empty shape.

NAME: *"MT9c ...and the THIRD empty shape, the one both rows above exclude by their own non-vacuity legs: the low list and the high list are BOTH non-empty and the series is still empty, because the only high crossing lies before the only low one. The oracle is the SHIPPED ordinal path -- the same request at nth 1 is already an absence today -- so nth 0 must agree with it in disposition AND in calc::cross_msg family, must not be destempty's family, and the SURFACE must answer the same absence with no db key. Three non-vacuity legs assert the shape: at least one low crossing, at least one high crossing, and a derived series of length zero"*

THE ORACLE IS THE SHIPPED CODE, not a third hand-picked shape and not a sentence. The same request at `nth` 1 answers an absence today through a path this unit does not touch, so the row asserts that `nth` 0 agrees with it -- same disposition, and a sentence from the same `calc::cross_msg` FAMILY. One physical fact (this low crossing never completes) must be reported in one voice whether the user asked for one edge or for all of them. **It pins no wording**: the `rule` debt `calc_wave_dest_empty_result_sentence` can reword the whole arm and both sides of the comparison move together. The positive family claim needed a new instrument, `mt_samefamily`, answering the bare word `samefamily` -- the existing `mt_notfamily` answers `samefamily:<family>`, which would have put a user-visible word into a row's EXPECTATION.

ELEVEN LEGS: `nth` 0 is `absent`; `nth` 1 is `absent` (the oracle, declared green on the red run); the two sentences are `samefamily`; `nth` 0's sentence is NOT in `destempty`'s family; it IS in a family `calc::cross_msg` itself builds; **three NON-VACUITY legs** -- at least one low crossing, at least one high crossing, and a derived series of length exactly zero, which is what stops the row being either of the two rows above wearing different arguments; and three SURFACE legs -- `calc::riseTime_scalar` answers `absent`, carries no `db` key, and its sentence is not in `destempty`'s family.

RED ON THE UNTOUCHED TREE, verbatim from the armed run:
`-> {refused absent {differ:Cross|Rise time} elsewhere known atleast1 atleast1 sized NOPROC:calc::riseTime_scalar NOPROC:calc::riseTime_scalar elsewhere} (exp {absent absent samefamily elsewhere known atleast1 atleast1 sized absent NOKEY-db elsewhere}) : FAIL`

RED UNDER `FORM2_inputguard`, verbatim, and it is the ONLY failing row in either suite:
`-> {measured absent {differ:NOFAMILY:{}|Rise time} elsewhere unknown:NOFAMILY:{} atleast1 atleast1 sized refused NOKEY-db samefamily:Destination} (exp {absent absent samefamily elsewhere known atleast1 atleast1 sized absent NOKEY-db elsewhere}) : FAIL`
FIVE legs fire and the last one names the defect in the user's own words: `samefamily:Destination` where the truth is an absence. ⚠ Confirming the author's measurement from the other direction, the `NOKEY-db` leg is GREEN under the sabotage -- a `destempty` refusal carries no `db` either -- so the surface DISPOSITION and FAMILY legs are what fence what the user reads, not the `db` leg. GREEN under the honest implementation.

⚠ WHAT THIS ROW CONSTRAINS, declared in its own comment rather than left as a trap: the `nth`-0 absence must reuse the family the ordinal path already uses for the identical request, so reaching for `cross_msg absent` on one side and `nohigh` on the other reddens here. That is this unit's internal choice, stated so nobody meets it as a gate red.

- **FIVE NEW INSTRUMENTS**, all in `tests/headless/test_calc_measure.tcl` beside the existing MT9c derivations, every one a PROC answering a word or a list the file re-derives (never a braced `expr` ternary at a row site, which `group`'s catch would turn into an abandoned band): `mt_ringfloor` / `mt_ringw` / `mt_ringrpn` / `mt_ringcol` (the minted ringing signal, frequency and floor sourced once so the RPN and the Tcl column cannot drift apart), `mt_excess` (`atleast<n>` for one count's excess over another, sentinel-safe), `mt_nodup`, and `mt_samefamily`. `mt_ringrpn` builds the expression as a **STRING** and never with `[list ...]`, per WIRING_CONTRACT section 14(a). The probe column is minted through `mt_addcol __mt_rtring` and deleted, so the band's own R402 inventory row still answers `{}` -- verified in the green run.

- **NOTHING WAS WEAKENED OR DELETED.** `tests/headless/test_calc_wave_dest.tcl` is byte-identical to the state the suite author left it in (`cmp` against a start-of-session backup, md5 `c0a5b494e76feaa9222f100259cd5b83`). In `test_calc_measure.tcl` no existing row, leg or expectation was touched: the red run's passing count is 170 before and after my edit, and the green run's is 183 + 2 = 185, so no existing row changed state in either direction.

**counts_after**

"RE-DERIVED, NEVER PRESERVED. Identical command for the red, green and sabotage sides.\n\n=== THE RED THE IMPLEMENTER INHERITS -- armed spelling, repo root, `git diff --stat -- src/` produces NO OUTPUT immediately before and after ===\n  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure\n  test home: throwaway /tmp/xschem-test-home.3520274.nFLsjx (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)\n  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0\n  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (113 passed)\n  FAIL     | test_calc_measure            run 2/2  RESULT: 15 FAILED (170 passed)\n  RESULT: 0/2 runs passed            (exit 1)\n  -> 124 and 185 checks.  26 FAIL rows total; `/usr/bin/grep -cE 'UNEXPECTED ERROR|BGERROR|ABORTED|another regression run is live'` answers **0**, so no band was abandoned and the run was solo.  15 = MT9b x4 moved + MT9c x11 new (the author's 9 plus my 2); wave_dest's 11 unchanged.\n  Transcript: /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/closer/red_final.txt\n\n=== THE GREEN SIDE IS REACHABLE, MEASURED NOT ASSERTED -- a simulated J2 injected at suite FILE SCOPE, `src/` untouched ===\n  $ env -u DISPLAY HOME=<scratch>/fakehome ./src/xschem --nogui --pipe -q --nolog --script <scratch>/sim/r_<suite>.tcl\n  test_calc_measure     OVERALL: ok (185 checks) / RESULT: ALL PASS (185 checks)   exit 0\n  test_calc_wave_dest   OVERALL: ok (124 checks) / RESULT: ALL PASS (124 checks)   exit 0\n\nPUBLISHED COUNTS THE IMPLEMENTER MUST RE-DERIVE:\n  test_calc_measure     170 -> **185**   (the author's +13, plus my +2; all fifteen are new MT9c rows or moved MT9b ones, none added to any other band)\n  test_calc_wave_dest   115 -> **124**   (unchanged by me)\n\n=== THE SUITES I DO NOT TOUCH -- counted arm, armed spelling, with my edits in ===\n  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_cross test_calc_engine test_calc_scratch_reuse\n  PASS | test_calc_cross 187   PASS | test_calc_engine 265   PASS | test_calc_scratch_reuse 56   RESULT: 3/3 runs passed\n\n=== THE DISPLAY ARM -- RUN, not reasoned, with my edits in ===\n  $ tests/headless/run_suites.sh test_calc_skeleton test_calc_plot test_calc_widgets test_calc_buffer\n  (announced: `display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0`; attached and left as found)\n  PASS | test_calc_skeleton 579   PASS | test_calc_plot 114   PASS | test_calc_widgets 259   PASS | test_calc_buffer 130   RESULT: 4/4 runs passed\n  NOTHING DISPLAY-ONLY MOVES.\n\n=== SABOTAGE MATRIX, six product states, all re-run rather than re-read ===\n                        measure        wave_dest     which row\n  honest J2             ALL PASS 185   ALL PASS 124  --\n  S5_pairhigh           1 FAILED       ALL PASS 124  the new PAIRING row, alone\n  FORM2_inputguard      1 FAILED       ALL PASS 124  the new THIRD-EMPTY-SHAPE row, alone\n  FORM1 (no absence)    3 FAILED       ALL PASS 124  the two existing absence rows + my new one (was 2, now 3)\n  K_padded              1 FAILED       ALL PASS 124  the partial-drop row, STILL alone (see still_open)\n  E_offbyone            5 FAILED       3 FAILED      the new PAIRING row is among them\n  C_consty              6 FAILED       3 FAILED      the new PAIRING row is among them\n  Zero raises in every run.  `test_calc_wave_dest` ALL PASS under S5 and FORM2 is CORRECT SCOPING: both defects are inside `calc::riseTime`, and the destination half only carries whatever the verb produced on a request that does not ring.\n\n=== THE T1 TRAILER -- DERIVED with `summarize_all`'s own five regexp arms and `tests/banner_rule.tcl`'s own predicates over REAL captured output, taken the way the `hcases` loop takes it (cwd `tests/`, `--nogui --pipe -q --script headless/<t>.tcl`).  I did NOT run T1. ===\nBoth suites are ALREADY in `hcases` (`tests/run_regression.tcl` lines 119-120, verified), so the registration delta is ZERO.  List sizes by CLAUDE.md's own method (`set <L> [list` then `/usr/bin/grep -o '\"[^\"]*\"' | wc -l`): tcases 3, hcases 96, dcases 25 -> 124 + `xschemtest` = **125 cases, 124 blocks**, unchanged.\nCensus (lowercase `^skip:` / uppercase `^SKIP:|^SKIPPED:` / `^RESULT:` / counted shapes / banner_complete / banner_died), on GREEN output both sides:\n  before  test_calc_measure   (committed suite + unmodified product)  ALL PASS (170 checks)   0 / 0 / 1 / 0 / 1 / 0\n  after   test_calc_measure   (my suite + simulated J2)               ALL PASS (185 checks)   0 / 0 / 1 / 0 / 1 / 0\n  after   test_calc_wave_dest (unchanged suite + simulated J2)        ALL PASS (124 checks)   0 / 0 / 1 / 0 / 1 / 0\nTHEREFORE cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with the NUMBER of `RESULT:`/`skip:` lines, not with the counts inside them, and neither number moved.  This is the PLAN 5.4 / J1 / J1b shape again: a stage that moves two published check counts and not one trailer term.  **The driver reads the trailer.**"


### still_open

- ⚠⚠ **`S6_xcolname` SURVIVES AND I DID NOT FENCE IT, because the attack itself did not claim harm.** Naming the destination's X column `time` instead of `calcx` (`calc::wave_dest [dict get $m sweep] [dict get $m value] time calcy`) gives `ALL PASS (124)` / `ALL PASS (183)` -- no row can see it, because every row reads `xname` OUT OF the answer and then reads that column from INSIDE the destination after switching into it. The attack reported it as *"harm NOT proven, reported as an observation and not a finding"* and its verdict field named `S5_pairhigh` as the sabotage. It is in issue 1644's family (a name collision with the loaded `tran` database's own `time` column) and whether the name is load-bearing for `wviewer::resolve_signal_db` is the open question. **Not actioned, and a row for it would need somebody to decide whether the name matters before it could assert anything.**

- ⚠⚠ **THE PADDED SHAPE IS STILL A SINGLE-ROW DEPENDENCY AND IT CAN STILL SHIP A NEGATIVE RISE TIME. The driver's instruction forbade a second row for a CAUGHT attack, so I measured it and left it.** Attack 1's verdict was CAUGHT, by seven rows; its own finding was that the LENGTH-PRESERVING variant (`set xh {}` hoisted out of the loop -- a forgotten loop-local reset, an ordinary slip rather than a contrived padder) is caught by EXACTLY ONE row in the whole tree, MT9c's partial-drop row, and that it reaches the answer with **-0.002887902076229785**, an unphysical negative rise time that nothing anywhere forbids. **Re-measured with my two rows in: still 1 FAILED in `test_calc_measure` and `ALL PASS (124)` in `test_calc_wave_dest`** -- my pairing row does not catch it (nothing is dropped on the ring request), so the dependency is unchanged. The attack's own proposal costs NO new row and therefore does not move a published count: a non-negativity leg on the SERIES in MT9c's keystone and on the READ-BACK Y in WD13's keystone, derived over the answer's own list, which would take the padded shape from one catcher to three and make it visible in `test_calc_wave_dest` too. **A driver decision, flagged here rather than taken, because the instruction was explicit.**

- ⚠ **WIRING_CONTRACT section 14(b)'s empty-series table is now a FOUR-shape table and says THREE.** Its A / B / C are no-low-crossing, no-high-after-any-low, and the partial drop. The fourth is the one ATTACK 3 reached and nothing had driven: both crossing lists NON-EMPTY and the series still empty, because the only high crossing lies before the only low one -- `riseTime {v(ramp)} 1 0 10 90 0`, measured `nlow=1 nhigh=1 serieslen=0`. It is now fenced by a row, but the contract's prose is one shape short and the next crew reads the contract first. I did not edit the contract: the working tree already carries uncommitted changes to it and the driver collects receipts.

- ⚠ **THE FAMILY CONSTRAINT MY SECOND ROW IMPOSES IS THIS UNIT'S OWN CHOICE AND IS NOT RULED.** The `nth`-0 absence must reuse the `calc::cross_msg` family the ordinal path already uses for the identical request, so `cross_msg absent` on one side and `nohigh` on the other reddens. The argument is that one physical fact must be reported in one voice; the alternative is to drop that leg and assert only *not destempty's family*, which would leave the two paths free to disagree. **Declared in the row's own comment** so nobody meets it as a gate red. The WORDS remain unasserted and the `rule` debt `calc_wave_dest_empty_result_sentence` can land without touching a row.

- ⚠ **THE MINTED RINGING REQUEST IS AN INSTRUMENT, NOT A FIXTURE CHANGE, AND ITS FLOOR IS A TUNED CONSTANT.** `mt_ringfloor` returns `-0.3`, which must sit ABOVE the antisymmetric half's own dip (measured at -0.5) or the low threshold gains a second rising crossing per period and the shape stops discriminating. The reason is in the helper's banner and the row's three non-vacuity legs re-measure the consequence every run (`atleast2`, `nhigh` exceeds `nlow`, nothing dropped), so a fixture regenerated onto a different grid reddens naming the cause instead of going quiet -- but the floor itself is a number in the tree, and the only thing re-checking it is those three legs.

- ⚠ **NO COMMITTED COLUMN HAS `nhigh > nlow` AT ANY LEVEL PAIR**, which is why the request had to be minted. Re-measured here on the damped step the attack used (`nlow=1 nhigh=3` at 10/90, 10/80, 20/90 and 5/95) and on two periodic shapes. The suite author's census of all ten columns is consistent with it. That is a property of `tests/headless/data/calc_fixture.raw` worth a line in its README, which I did not write -- it bears on every `cross`-layered verb, not only `riseTime`.

- ⚠ **THE DESTINATION HALF REMAINS BLIND TO BOTH DEFECTS, deliberately and declared.** `test_calc_wave_dest` is `ALL PASS (124)` under `S5_pairhigh` and under `FORM2_inputguard`, because band WD13 drives one request on which the two pairing directions coincide and never drives a request whose series is empty with non-empty crossing lists. Both defects are inside `calc::riseTime`, so the verb half is the right place -- but a reader who takes a green `test_calc_wave_dest` as evidence about the hand-off's semantics would be wrong, exactly as the author declared for `J_destempty` and `K_padded`.

- **Every hole the suite author declared is inherited unchanged and none is closed by this work**: `riseTime` has no `xaxis` argument (R420's three axes exist only for `dutyCycle`, and the X axis of a plotted measurement is a `rule` candidate); the click path is unfenced on the counted arm (`calc::fn_measure` and `calc::buf_set_number` both return early on `calc::has_win .calc.buf`); no row asserts that the measured `riseTime` wave APPEARS on screen; `calc::wave_dest_restore` still loses the registry cursor's `prev` half (J1's defect (b)); who frees a destination the user is looking at is still unruled and J2 doubles the leak rate; the destination's user-visible name is still unruled; and four of WD13's `wd_curslot` legs are leak coverage rather than restore coverage.

- **I DID NOT RUN A FULL T1, DID NOT COMMIT, DID NOT PUSH, DID NOT GATE, AND DID NOT TOUCH THE `owed.sh` LEDGER.** `git diff --stat -- src/` produces no output before and after every run. No product change was implemented: the simulated J2 and all six sabotage variants live only under `/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J2/closer/`, injected at suite FILE SCOPE into wrappers that `source` the real suites. `~/dev/xschem-op-wcard`, `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display` and `~/.claude/gui_test_gate` were never written; `devdisplay.sh start|stop|view` was never run -- the display-arm readings ATTACHED to the already-running `:99` with `GUI_GATE=0` and a throwaway HOME and left it as found; `AUDIT_SCREEN` left at its default. No bare `xschem`; every binary call carried `--nogui` plus `env -u DISPLAY`, or the armed `run_suites.sh`. `/usr/bin/grep` throughout. `info complete` is 1 on both suite files. **No `switch` was touched and no comment sits between two patterns anywhere in my additions** -- the only two `switch` strings in the diff are the author's prose lines. Scratch 2.1 MB; `/tmp` (tmpfs) at 774M of 7.7G. **NOTHING IS RUNNING NOW.**

**ready_for_implementation**

"YES. In this order, and all of it in ONE commit with the two suite files, because band MT9c and band WD13 are standing reds on a producer-only tree and `calc::arg_surface` redirects every click the instant the wrapper exists. (1) Re-spell `riseTime`'s `returns` from `scalar` to `scalar/wave` in `calc::catalogue`'s own row, and correct the four prose sites that then become false -- `calc::catalogue`'s banner sentence (*\"riseTime and delay stay scalar\"*), spec `doc/claude/specs/calculator.md` R416's closing note carrying the same sentence, spec section 7.2's table row, and the two stale comment copies still enumerating the deferring callers as *\"delay, dutyCycle_scalar and the unbuilt frequency\"*; S24's closed vocabulary already holds `scalar/wave`, so nothing widens and no count moves, measured. (2) In `calc::riseTime`, REPLACE issue 1639's `nth`-0 deferral rather than bypassing it, moving it below the two threshold computations: read `calc::cross $rpn $llo 0 rising $dataset` and `calc::cross $rpn $lhi 0 rising $dataset`, forwarding either refusal unchanged; then **iterate the LOW crossing list and never the high one**, pairing each low crossing with the FIRST high crossing strictly greater than it and dropping a low crossing that has none -- driving the high list instead passes every other row in the tree and is the defect the new PAIRING row exists to catch; set `value` to the Y list and `sweep` to the parallel X list of low crossings. (3) Test emptiness **on the OUTPUT series and never on the two input lists** -- `if {![llength $ys]}`, not `if {![llength [dict get $a value]] || ![llength $highs]}` -- and answer `calc::cross_absent` with `calc::cross_msg nohigh [calc::cross_ordinal 0]`, which is the SAME `cross_msg` family the shipped ordinal path already uses for the identical request; the input-side guard is a complete, fully green J2 that ships the `destempty` sentence for a signal that never crossed, and the new THIRD-EMPTY-SHAPE row is the only thing that sees it. (4) Mint `calc::riseTime_scalar` carrying `calc::riseTime`'s own seven formals in the verb's own order (`rpn {lo {}} {hi {}} {pctlo 10} {pcthi 90} {nth 1} {dataset 0}`) with no extra formal anywhere but LAST, since a mid-list formal the dialog cannot answer truncates `calc::arg_values` before the ordinal and silently delivers the default 1 where the user asked for 0; forward a non-zero or non-finite `nth` unchanged; pass a refusal or an absence straight through with no `db` key; hand `sweep` then `value` to `calc::wave_dest` (**X FIRST**); propagate a destination refusal through `calc::cross_refusal`; and merge exactly `{db type xname yname n}` plus `dict set m shape wave`, the shape key in the same commit as the key-set row. (5) Do NOT drop the destination on the success path -- a trace resolves it by registry name and dropping frees what the user is looking at; the undropped slot is J1's declared leak, inherited. (6) Then re-derive, never preserve: `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure` must give `ALL PASS (124)` and `ALL PASS (185)`, with `test_calc_cross` 187, `test_calc_engine` 265, `test_calc_scratch_reuse` 56 on the counted arm and `test_calc_skeleton` 579, `test_calc_plot` 114, `test_calc_widgets` 259, `test_calc_buffer` 130 on the display arm, and the T1 trailer unchanged at `cases=125 blocks=124 counted_failures=0 skips=8`."

