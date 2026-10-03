# Unit J1 -- the red-first suite, the three attacks and the repair
Five crews. The `repair:j1` section's **ready_for_implementation** is the producer's
SPECIFICATION, in eight numbered steps. **still_open** lists every declared hole.


## suite:j1

**mt10_measurement**

Row MT10's transitive-closure row derives its closure DOWNWARD (callee-ward) from the literal verb set `{riseTime delay dutyCycle}` and never from a wrapper. Quoted from `tests/headless/test_calc_measure.tcl`, band MT10:

    set verbs {riseTime delay dutyCycle}
    check "MT10 T1 ...and NO proc in any of those closures, cross alone excepted, issues an xschem raw add, values, value or del of its own -- which is SR5's discipline seen from the other side, and which is what forbids T1's evaluate-once helper: such a helper has to evaluate into a column of its own, so it appears here by name" \
        [list $present [lmap v $verbs {mt_closure_raw $v}]] \
        [list $verbs {{} {} {}}]

`mt_calc_closure` walks `::calc::` names out of each verb's DECOMMENTED body (`mt_calc_names`), stopping AT `cross`; `mt_direct_raw` matches `xschem\s+raw\s+(add|values|value|del)`.

MEASURED on this tree (probe `scratchpad/J-wire-dest/j1-rows/p2.tcl`, which LIFTS all five procs out of the suite's own text rather than reimplementing them):

    CLOSURE-dutyCycle= cross cross_absent cross_msg cross_ordinal cross_refusal dutyCycle eval_finite
    CLOSURE-RAW-dutyCycle= {}
    DIRECT-RAW-wave_dest= yes
    DIRECT-RAW-dutyCycle_scalar= no
    dutyCycle_scalar-IN-dutyCycle-CLOSURE= 0
    HYPO-CLOSURE-dutyCycle= cross_msg dutyCycle eval_finite wave_dest wave_dest_answer wave_dest_cur wave_dest_refusal wave_dest_restore
    HYPO-CLOSURE-RAW-dutyCycle= {wave_dest}

(The HYPO lines are with `calc::dutyCycle` monkey-patched in-process to name `calc::wave_dest`; `src/` was not touched.)

THEREFORE: **`calc::dutyCycle_scalar` may reach `calc::wave_dest`; `calc::dutyCycle` may not.** The wrapper is invisible to MT10 because the closure runs callee-ward and nothing in `dutyCycle`'s body names `dutyCycle_scalar`. The measurement proc is not invisible: `calc::wave_dest` issues `xschem raw add $yname {}`, so `mt_direct_raw wave_dest` answers `yes` and `mt_closure_raw dutyCycle` becomes `{wave_dest}` against an expectation of `{}`.

CONFIRMED BEHAVIOURALLY, not only by derivation: sabotage `I_wrong_layer` puts the destination inside `calc::dutyCycle` and MT10 reddens with `{{riseTime delay dutyCycle} {{} {} wave_dest}}` against `{{riseTime delay dutyCycle} {{} {} {}}}`. So J1 wires the WRAPPER, exactly as WIRING_CONTRACT §4 warns, and that is now a measurement rather than a reading.


### new_rows

**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11 (new band, inserted between WD9 and WD10 so WD10 still runs last) -- hcases alone, counted arm

**name**

WD11 R419/R420 dutyCycle_scalar's DEFAULT cycle stops deferring and answers a REGISTERED two-column destination rather than a bare list: the answer names a database, its two column names differ, the database's OWN point count is the series length, and BOTH columns read back out of it element-wise -- the X at the time tolerance and the Y at the series one -- with the user's own slot current again afterwards.  Driven on v(lp) and NOT on v(sq), whose two fractions agree to a relative 1.8e-15 so that the distinctness leg below would answer `same`

**what_it_pins**

The keystone. `calc::dutyCycle_scalar {v(lp)} 0.5` (default cycle) answers `measured`; `db` matches the `__calc_dest*` glob; `xname ne yname` and neither empty; `xschem raw points 0` AFTER switching into the destination equals the derived series length; both columns read back element-wise against this file's own D3+D4 derivation over the `v(lp)` column (X at WDTOL_TIME 1e-12, Y at WDTOL 1e-7); every adjacent Y is `distinct`; and `wd_curslot` is the user's slot again.

**red_output**

FAIL: WD11 R419/R420 dutyCycle_scalar's DEFAULT cycle stops deferring ... -> {refused NOKEY-db twonames notacount:{} {count=0 want=2 got={}} {count=0 want=2 got={}} tooshort:0 0} (exp {measured named twonames sized ok ok distinct 0}) : FAIL

**discriminates_how**

Kills trap (2) -- 'deleting the guard is enough'. Sabotage A_guard_only (the three-line guard deleted, `calc::dutyCycle`'s own dict returned) prints `{measured NOKEY-db twonames notacount:{} {count=0 want=2 got={}} {count=0 want=2 got={}} tooshort:0 0}`: the DISPOSITION leg goes green and six registration legs stay red, which is exactly the vacuity the critic named. Also kills B_swapped (X and Y handed to the producer the wrong way round; both element-wise legs name the offending element and the relative error), G_offbyone (`{pts:1 want:2}`) and H_stride (`{pts:1 want:2}`). Uses `near`/`wd_listcmp`, never `string equal`, because the round-trip is not byte-exact (measured: 0.0011279962723246316 in, 0.001127996272324632 out).


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 ...and the answer's KEY SET is exactly the measurement's own keys plus the destination's, with `dest` left holding the RETIRED __calc_tmp the measurement evaluated into -- a name R402 has already deleted, which is why no __calc_tmp survives in the inventory -- and `db` holding the LIVE __calc_dest that IS registered: the two keys are different names and mean different things, so a wiring that put the live destination in `dest` reddens here instead of quietly redefining the key MT9b reads.  The last leg is the CONTROL for the distinctness instrument the row above leans on, which must be able to answer `same` or its `distinct` is a constant

**what_it_pins**

The key set, chosen deliberately and asserted EXACTLY: `{absent dataset db dest msg n ok sweep type value xname yname}`. Plus: `dest` matches `__calc_tmp*`, `wd_leaked` is empty (so that name really is retired), `db` matches `__calc_dest*` and `wd_registered $db table` answers `registered`. Last leg is the `wd_alldistinct {1.0 1.0}` -> `same` instrument control.

**red_output**

FAIL: WD11 ...and the answer's KEY SET is exactly the measurement's own keys plus the destination's ... -> {{absent dataset dest msg ok value} {} {} NOKEY-db absent same} (exp {{absent dataset db dest msg n ok sweep type value xname yname} tmp {} named registered same}) : FAIL

**discriminates_how**

Kills the 'two destination-shaped keys' trap. Sabotage C_dest_key puts the live destination in `dest` and leaves `db` out; the row prints `{{absent dataset dest msg n ok sweep type value xname yname} __calc_dest9 {} NOKEY-db absent same}` -- it names the live destination sitting in the key MT9b reads BY NAME to tell a deferral from an absence. It is also the row that will redden when unit J1b adds §4's `shape` key, by design: the set is exact so the widening is deliberate rather than silent.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 R402 the destination is a REGISTRY SLOT and every existing leak fence in this batch is BLIND to it, which is measured rather than argued: wd_leaked and wd_probeleft both answer EMPTY -- they glob __calc_tmp*/__wd_* over the CURRENT database's COLUMN names, and the destination's columns are calcx/calcy in a database nobody switched to -- while the slot count has gone UP by one and the new slot's sim_type is the one odd type that works.  A leak fence for this stage counts SLOTS

**what_it_pins**

Trap (4). Asserts POSITIVELY that `wd_leaked` and `wd_probeleft` are both empty while `wd_nslots` is 2, `wd_slottype 1` is `table` and `wd_registered $db table` answers `registered` -- i.e. the column globs are blind and only the slot count sees the stage's leak.

**red_output**

FAIL: WD11 R402 the destination is a REGISTRY SLOT and every existing leak fence in this batch is BLIND to it ... -> {{} {} 1 NOSLOT absent 0} (exp {{} {} 2 table registered 0}) : FAIL

**discriminates_how**

Kills trap (4) as a POSITIVE claim instead of as prose: the two glob legs are green on the red run AND on every sabotage, which is what proves they cannot see this leak, while the slot-count leg moves. It also catches D_drop_on_success (`{{} {} 1 NOSLOT absent 0}`) and C_dest_key (`{{} {} 2 table absent 0}` -- a slot appeared but no answer key names it).


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 ...and the stage ANSWERS the destination WITHOUT DROPPING IT, which is declared and not an oversight: a trace resolves its database by registry NAME and wviewer::restore cannot re-read it, so a drop on the SUCCESS path would free the database the user is looking at.  The slot is still there after the answer, the answer is enough to drop it, and dropping it leaves the user's slot current -- so WHO drops it is unit J1b's question and this row is the fence that it was not answered here

**what_it_pins**

The DECLARED leak, as a fence rather than a sentence: slot count is 2 before the drop, `calc::wave_dest_drop` on the verb's own answer returns 1, slot count is 1 after, the destination is `absent` from the inventory, the user's slot is current and no `__calc_tmp*` survives.

**red_output**

FAIL: WD11 ...and the stage ANSWERS the destination WITHOUT DROPPING IT ... -> {1 0 1 absent 0 {}} (exp {2 1 1 absent 0 {}}) : FAIL

**discriminates_how**

Kills D_drop_on_success -- the shape `recon:contract` prescribed and section 10(c) overturned. With a drop on the success path the row prints `{1 1 1 absent 0 {}}`: the slot is gone before the band can see it, which is precisely the state in which a trace's `%__calc_dest<N> table` resolves to nothing. It also proves the answer dict is SUFFICIENT to drop (the `1` from `wave_dest_drop`), which is what unit J1b needs and what a dict missing `db`/`type` would not give.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 ...and the same claim on a series LONG enough to be worth making: many times more points than any committed column can give, out of the fixture's own time column through the shipped engine, where the destination's point count is the count the derivation found, both columns read back element-wise in ORDER, the X column is strictly increasing and every adjacent Y differs -- so a stride, an off-by-one in the fill loop, a dropped middle sample and a reversal are each a different failure here, which is exactly what a two-point series cannot say.  The length floor is DERIVED from the two-point series this band already measured, four times over, rather than written down

**what_it_pins**

A TWENTY-point destination. The RPN is built, not written down: `set wd_lw [expr {2.0 * acos(-1) * 2100.0}]` / `set wd_lrpn [list time $wd_lw * sin()]`, level 0.25. `wd_rpncol` evaluates the SAME expression into a `__wd_series` probe column and deletes it, so `wd_duty_derive` has an independent derivation. Legs: disposition, `db` named, `wd_sized` against the derived length, a length floor of 4x the two-point series' length, both columns element-wise, `wd_increasing` on X, `wd_alldistinct` on Y.

**red_output**

FAIL: WD11 ...and the same claim on a series LONG enough to be worth making ... -> {refused NOKEY-db notacount:{} atleast {count=0 want=20 got={}} {count=0 want=20 got={}} tooshort:0 tooshort:0} (exp {measured named sized atleast ok ok increasing distinct}) : FAIL

**discriminates_how**

This is the answer to the task's 'try it and report what you got', and it closes most of the structural weakness the two-point limit leaves. Measured properties of the series: 20 points, every crossing STRICTLY between two samples, X strictly increasing with a non-uniform stride, and the CLOSEST adjacent Y pair differing by a relative 1.6e-3 (four orders outside WDTOL), so `wd_alldistinct` answers `distinct`. Sabotage H_stride (every other point) prints `{pts:10 want:20}`; G_offbyone prints `{pts:19 want:20}` plus `count=19 want=20`; B_swapped names 20 offending elements. A dropped middle sample moves the count AND the element-wise legs. None of those four is visible on a two-point series.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 ...and this row's own DISCRIMINATION, derived rather than claimed: against the very same comparison, the series REVERSED does not satisfy either column, and a column filled with its own first element does not satisfy either -- so the two element-wise legs above are telling a correct destination from the three wrong fills a reasonable person would write, and they answer WORDS so no reproducible number lands in the verdict

**what_it_pins**

The instrument, not the product: `wd_cmpword` of the reversed X, the reversed Y, an X filled with its own element 0 and a Y filled with its own element 0 must each answer `distinct`, while the UNALTERED columns must answer `same`. Six word-valued legs, no number anywhere.

**red_output**

FAIL: WD11 ...and this row's own DISCRIMINATION, derived rather than claimed ... -> {distinct distinct distinct distinct distinct distinct} (exp {distinct distinct distinct distinct same same}) : FAIL

**discriminates_how**

This is trap (1) answered head-on, and it is why the WD8 finding could not happen again here: the row ASSERTS in the run, every run, that the comparison it leans on separates a correct column from a reversed one and from a constant-filled one. On the red tree the last two legs fail (there is no destination to be correct); with the simulated J1 all six are as expected. It answers words, so nothing reproducible lands in the T1 verdict, which is the house rule `wd_distinct` exists for.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 R402 the long series' probe column is GONE -- wd_rpncol minted __wd_series through the engine, read it and deleted it -- and the destination the band dropped took its slot with it, so the registry is the single tran slot this half of the band runs on and it is current

**what_it_pins**

The band's own hygiene for the new `wd_rpncol` instrument: no `__calc_tmp*`, no `__wd_*`, one slot, slot 0 current, and the long series' destination `absent`.

**red_output**

GREEN ON THE RED RUN, and declared as such rather than claimed as a fence. It printed `ok:   WD11 R402 the long series' probe column is GONE ...`. It is the suite-defect watch for the new probe column -- a probe that forgot to clean up would be reported as a SUITE defect, never as a product leak -- and on the red tree there is no destination to leak, so it cannot redden. The suite header's existing 'which rows pass with no feature present' section now names this class.

**discriminates_how**

It is the fence that keeps the new instrument honest: `wd_rpncol` is the first proc in this file to issue `xschem raw add`, so without this row a probe column left behind would make every later `wd_probeleft` row in WD10 lie. Under the simulated J1 it is green with the destination dropped; it reddens on C_dest_key (`{{} {} 2 0 absent}`), where the band could not drop a destination whose name the answer never gave it.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 the user's own slot is theirs again after the default cycle lands a destination, driven from slot TWO of THREE -- the fixture read as op, ac and tran in that order so that the measurement is possible from the user's slot while the slot is still non-zero, because from there a bare raw switch steps round-robin and switch_back lands on the destination, so neither wrong restore can pass.  The destination is APPENDED as a fourth slot, typed table, and the user's tran slot is untouched at index two

**what_it_pins**

The restore, through a new loader `wd_load3t` that reads the fixture as `op`, `ac`, `tran` IN THAT ORDER -- the inverse of `wd_load3`, so the user ends on `tran` at slot 2 where a `dutyCycle` is actually possible. Legs: disposition, `db` named, `wd_curslot` 2, `wd_nslots` 4, `wd_slottype 3` = `table`, `wd_slottype 2` = `tran`, `wd_slottype 0` = `op`, destination `registered`.

**red_output**

FAIL: WD11 the user's own slot is theirs again after the default cycle lands a destination, driven from slot TWO of THREE ... -> {refused NOKEY-db 2 3 NOSLOT tran op absent} (exp {measured named 2 4 table tran op registered}) : FAIL

**discriminates_how**

Three loads with the user on a NON-ZERO slot is what the task's pre-existing-defect (b) note requires: measured on this registry, a bare `xschem raw switch <path>` from slot 2 of 4 lands on slot 3 and `switch_back` lands on the destination, so a two-slot fixture would have passed against either. Sabotage E_left_current (the wiring switches into the destination to read it back and never switches away) prints `{measured named 3 4 table tran op registered}` -- the `3` is the destination, and that state makes `results::current` answer {} and lets `wviewer::graph_props` re-axe every trace on every strip.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 ...and dropping it from the non-zero slot puts the user back there too, which is TWO switches and not one because raw clear forces the current slot to 0 whatever it was -- so a dropper that switched once would leave the user on the tran slot's index 0 neighbour, which on this registry is the op slot and is a different analysis

**what_it_pins**

The post-clear half of the restore from slot 2 of 3: `wave_dest_drop` returns 1, `wd_curslot` is 2 again, `wd_nslots` is 3, `wd_slottype 2` is still `tran`, the destination is `absent`.

**red_output**

FAIL: WD11 ...and dropping it from the non-zero slot puts the user back there too ... -> {0 2 3 tran absent} (exp {1 2 3 tran absent}) : FAIL

**discriminates_how**

Pins the SECOND restore, which exists because `xschem raw clear <name> <type>` forces the current slot to 0 unconditionally (issue 1636, load-bearing for `ase::attach_dbs`). On this registry slot 0 is the `op` read, so a one-switch dropper lands the user on a different ANALYSIS of the same file -- which a two-slot or slot-0 fixture cannot distinguish. Reddens on E_left_current (`{1 0 3 tran absent}`) and on C_dest_key (`{0 2 4 tran absent}`).


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 the CONTROL: a NAMED cycle is the scalar it always was and builds NO destination -- no db key at all, the registry still the single tran slot -- and neither does the default cycle at a level the wave never reaches, which answers an ABSENCE: so the wiring landed on the default-cycle arm of a request that HAS a series, and not on every call

**what_it_pins**

That the wiring is on the DEFAULT-CYCLE arm only. A named cycle answers `measured`, has NO `db` key (`NOKEY-db`), equals the derived first fraction, and keeps `calc::dutyCycle`'s historic key set `{absent dataset dest msg ok sweep value}`; a default cycle at a level nothing crosses also has no `db`; the registry is one slot and nothing leaked.

**red_output**

GREEN ON THE RED RUN, declared. It printed `ok:   WD11 the CONTROL: a NAMED cycle is the scalar it always was and builds NO destination ...`. Its job is not to observe the wiring -- it is to forbid the other plausible wrong implementation -- so it is true before the change and must stay true after it. The suite header's green-on-the-red-run section names it explicitly.

**discriminates_how**

This is the row that kills sabotage F_merge_always (the destination's keys merged into EVERY answer, so a named cycle and an absence both grow an empty `db`): it prints `{measured {} ok {absent dataset db dest msg n ok sweep type value xname yname} NOKEY-db 1 {}}` against `{measured NOKEY-db ok {absent dataset dest msg ok sweep value} NOKEY-db 1 {}}`. No other row in either suite catches that shape on its own.


**suite**

tests/headless/test_calc_wave_dest.tcl

**band**

WD11

**name**

WD11 R402 the whole band left no __calc_tmp*, no __wd_* and no destination slot behind, across its measured, absent, dropped and three-slot paths

**what_it_pins**

The band's exit state for the bands that follow it: no `__calc_tmp*`, no `__wd_*`, one slot, slot 0 current.

**red_output**

GREEN ON THE RED RUN, declared -- the same class as the suite's existing per-band R402 inventory rows, which its header already declares cannot redden while the feature is absent.

**discriminates_how**

Keeps WD11 from poisoning WD10, which runs after it and asserts the whole suite's inventory. It is a real fence for the implementation (a wiring that leaked a destination out of the band's last path reddens it) and vacuous against the feature's absence, which is stated rather than left to be noticed.



### rows_moved

**suite**

tests/headless/test_calc_measure.tcl

**row**

MT8 (the default-cycle row, band MT8)

**old_assertion**

"MT8 D8 the UI surface defers the wave case behind the SAME sentence cross already uses for nth=0, rather than truncating the series to its first element" -- [list [mt_disp [mt_call dutyCycle_scalar {v(sq)} 0.5]] [string equal [mt_msg $a] [pcall calc::cross_msg listdefer]] [mt_disp [mt_call dutyCycle_scalar {v(sq)} 0.5 1]] [mt_is $b ...]] == {refused 1 measured ok}

**new_assertion**

"MT8 D8 the UI surface NO LONGER defers the wave case: the DEFAULT cycle measures and names a REGISTERED destination of its own, while the shared sentence is RETIRED here rather than reworded -- so the identity leg is 0 for this caller and the three still waiting keep it unchanged -- and a NAMED cycle is the scalar it always was, with no destination key at all" -- same four legs plus `[mt_destname [mt_key $a db]]` and `[mt_key $b db]` == {measured 0 named measured ok NOKEY-db}. Followed by `pcall calc::wave_dest_drop $a` so the band leaves no slot. New helper `mt_destname` added (a PROC, not a ternary: a braced `expr` whose branch is a command substitution answering `NOKEY-db` raises *invalid bareword* and would abandon the band).

**why_not_a_weakening**

It gains two legs and loses none. The identity leg is kept and INVERTED to 0 rather than retargeted at a new string, which is what asserts the sentence was RETIRED for this caller and not REWORDED -- a rewording would still redden WD9's pairwise chain. The row now also demands a REGISTERED destination (`named`), which the old row could not ask for, and demands that a named cycle still has no `db` key. Verbatim red against the unmodified tree: `-> {refused 1 NOKEY-db measured ok NOKEY-db} (exp {measured 0 named measured ok NOKEY-db})`. It reddens on A_guard_only (`NOKEY-db`), C_dest_key (`NOKEY-db`), E_left_current and F_merge_always.


**suite**

tests/headless/test_calc_wave_dest.tcl

**row**

WD9, the four-caller identity row

**old_assertion**

"WD9 EVERY deferring caller answers THAT SAME SENTENCE BY IDENTITY -- cross_scalar's nth 0, delay's nth 0 on a side, dutyCycle_scalar's default cycle and riseTime's nth 0 ..." == {refused 1 refused 1 refused 1 refused 1}

**new_assertion**

"WD9 EVERY caller STILL WAITING answers THAT SAME SENTENCE BY IDENTITY -- cross_scalar's nth 0, delay's nth 0 on a side and riseTime's nth 0 -- while dutyCycle_scalar's DEFAULT CYCLE, which stage J wired, MEASURES and carries none of it ..." == {refused 1 refused 1 measured 0 refused 1}. The wired caller is STILL DRIVEN, with `pcall wd_call wave_dest_drop $c` after the check so the band leaves no slot.

**why_not_a_weakening**

The fourth caller is not dropped from the row -- dropping it would leave nothing asserting that it STOPPED saying the shared sentence, and a future reader could not tell a wired caller from a forgotten one. Keeping it driven means a re-deferral reddens here, a claim nothing else in the tree makes. Verbatim red: `-> {refused 1 refused 1 refused 1 refused 1} (exp {refused 1 refused 1 measured 0 refused 1})`.


**suite**

tests/headless/test_calc_wave_dest.tcl

**row**

WD9, the pairwise-chain row

**old_assertion**

msg(cross_scalar)==msg(delay), msg(delay)==msg(dutyCycle_scalar), msg(dutyCycle_scalar)==msg(riseTime) == {1 1 1}

**new_assertion**

msg(cross_scalar)==msg(delay), msg(delay)==msg(riseTime), msg(dutyCycle_scalar)==cross_msg(listdefer), msg(dutyCycle_scalar)==msg(cross_scalar) == {1 1 0 0}

**why_not_a_weakening**

The chain is re-linked over the three callers that still share the sentence (so it is still a closed chain, not two separate comparisons), and TWO NEGATIVE legs are added for the wired caller: its message must equal NEITHER `calc::cross_msg listdefer` NOR a sibling's. The row goes from three legs to four and now forbids a wiring that measured while still carrying the deferral sentence. Verbatim red: `-> {1 1 1 1} (exp {1 1 0 0})`.


**suite**

tests/headless/test_calc_wave_dest.tcl

**row**

WD9, the derived-caller keystone

**old_assertion**

set derived over the namespace by `regexp {cross_msg +listdefer}` on each `::calc::*` decommented body -- [list $wd_defcallers [wd_atleast [llength $wd_defcallers] 4]] == {{cross_scalar delay dutyCycle_scalar riseTime} atleast}

**new_assertion**

TWO sets derived in ONE walk: `wd_defcallers` by `regexp {cross_msg +listdefer}` and `wd_wiredcallers` by `regexp {calc::wave_dest[^A-Za-z0-9_]}`, plus their union -- [list $wd_defcallers $wd_wiredcallers $wd_bothsides [wd_atleast [llength $wd_bothsides] 4]] == [list {cross_scalar delay riseTime} {dutyCycle_scalar} {cross_scalar delay dutyCycle_scalar riseTime} atleast]

**why_not_a_weakening**

The `atleast` floor was RE-DERIVED, not decremented: it now runs over the UNION of the deferring and the wired callers, so it holds at four on both sides of every unit of stage J, where an `atleast 3` would have been a floor that each unit lowers. A caller that fell out of BOTH sets -- wired to nothing, or wired to something that is not the destination -- reddens the union leg naming itself, which the old single-set row could not see. MEASURED that this is live: sabotage A_guard_only prints `{{cross_scalar delay riseTime} {} {cross_scalar delay riseTime} only:3}` -- the floor itself catches a guard deleted with no destination built. The `[^A-Za-z0-9_]` in the pattern is load-bearing: without it `calc::wave_dest_answer/_refusal/_cur/_restore/_drop` would all read as wired callers and the union leg would be the trivially-true claim that `::calc::` contains the producer's own implementation. Verbatim red: `-> {{cross_scalar delay dutyCycle_scalar riseTime} {} {cross_scalar delay dutyCycle_scalar riseTime} atleast} (exp {{cross_scalar delay riseTime} dutyCycle_scalar {cross_scalar delay dutyCycle_scalar riseTime} atleast})`. Sabotage I_wrong_layer prints `dutyCycle` where `dutyCycle_scalar` is expected, so the row names the wrong LAYER too.


**suite**

tests/headless/test_calc_wave_dest.tcl

**row**

WD8, the end-to-end row -- ⚠ A FIFTH ROW, AND NOT PART OF J1'S RED. It is green before and after; it was moved because it was MEASURED not to discriminate the defect it was written for.

**old_assertion**

Fed `calc::dutyCycle {v(sq)} 1/3`'s own two lists to `calc::wave_dest` and compared the read-back element-wise against the band's `$xstart`/`$duty` -- {measured measured ok ok}

**new_assertion**

Drives `v(lp)` at L = 0.5, derives `$dutylp`/`$startlp` with `wd_duty_derive` over the `v(lp)` column, and adds four legs: `wd_alldistinct` on the read-back Y, `wd_alldistinct` on the read-back X, and `wd_cmpword` of each column REVERSED against its derivation -- {measured measured ok ok distinct distinct distinct distinct}

**why_not_a_weakening**

This is the hole section 10(a) found, closed rather than reported. MEASURED: `v(sq)`'s two duty fractions agree to a RELATIVE 1.8e-15 at both L = 0.5 and L = 1/3 (the square is periodic, so every complete period has the same high time) against this file's own WDTOL of 1e-7 -- so the only end-to-end row in the file passed against a producer that wrote element 0 into both points or wrote the Y column backwards. `v(lp)`'s duty at L = 0.5 differs between its two cycles by a relative 1.2e-4 and is the only committed column on the fixture that differs at all. The X half was never vacuous (the two cycle-start times are 4 ms apart) and is unchanged. The four added legs assert the discrimination IN THE RUN rather than in the comment, so the hole cannot reopen silently. The row count is unchanged (still one `check`), so the published count does not move for this. VERIFIED green before (`ALL PASS (90 checks)`) and after the edit on the unmodified tree -- it is not in the red run's failure list -- and green under the simulated J1.


**four_rows_confirmed**

CONFIRMED by running, with one qualification that is about scope and not about the count.

J1 moves EXACTLY FOUR rows in the sense the critic meant -- rows whose verdict flips with the product change: `MT8`'s default-cycle row (×1, `test_calc_measure`) and `WD9`'s three rows (×3, `test_calc_wave_dest`). Method: I wrote the four moved expectations plus the new band, then ran every Calculator suite BOTH against the unmodified tree and against a simulated J1 injected at suite file scope (`src/` untouched).

Against the unmodified tree, the only pre-existing rows that reddened are those four:
  test_calc_wave_dest -> 11 FAILED (90 passed): WD9 ×3 (moved) + WD11 ×8 (new)
  test_calc_measure   -> 1 FAILED (159 passed): MT8 ×1 (moved)

Against the simulated J1, EVERY Calculator suite is green on its own arm:
  counted arm   test_calc_wave_dest ALL PASS (101)   test_calc_measure ALL PASS (160)
                test_calc_cross ALL PASS (187)        test_calc_engine ALL PASS (265)
                test_calc_scratch_reuse ALL PASS (54)
  display arm   test_calc_skeleton ALL PASS (573)     test_calc_widgets ALL PASS (259)
                test_calc_buffer ALL PASS (130)       test_calc_plot ALL PASS (105)

NO FIFTH ROW. In particular the four conditional rows the cost receipt flagged all hold, and I ran them rather than reading them: `S24`'s closed `returns` vocabulary and its eight category counts (`test_calc_skeleton`, dcases-only, 573 on its real arm), `CW13`'s `-command` list (`test_calc_widgets`, 259), `PL9`/`CE8`'s `calc::dest_*` globs (`test_calc_plot` 105, `test_calc_engine` 265) and `SR5`'s two viewer-door literals and four-way equality (`test_calc_scratch_reuse`, 54). SR5 holds because the wired wrapper's body names `calc::wave_dest` but no `wviewer::*` and no direct `xschem raw add`.

QUALIFICATION: I also EDITED a fifth row -- `WD8`'s end-to-end row -- but J1 does not move it. It is green before the edit, green after the edit on the unmodified tree, and green under the simulated J1. It was changed because it was measured not to discriminate the defect it was written for (section 10(a)), which is a hole closure and not part of the stage's red. It is listed under `rows_moved` with that stated.

⚠ TWO DISPLAY-ARM READINGS WERE INJECTION ARTEFACTS BEFORE THEY WERE MEASUREMENTS, and the correction is worth passing on: run from a scratch copy, `test_calc_skeleton` row `S27` reddened (`the source really was read (positive control)` -> `{0}`) and `test_calc_plot` reddened on `PL0`/`PL9`, because both suites resolve `src/calculator.tcl`, `test_calc_engine.tcl` and `sky130A/...` from `[file dirname [info script]] .. ..`. Re-run through a symlink mirror whose `..` resolves to the real repo, both are ALL PASS. A crew that read those two reds as J1 findings would have chased nothing.

**check_counts**

Every figure below was RUN, and each is derived rather than preserved -- a published check count is an instrument's output, not a baseline.

=== THE SUITES J1 TOUCHES -- counted arm (hcases alone) ===
Command (both before and after, identical):
  tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure

  BEFORE (my edits not yet applied, unmodified product):
    PASS | test_calc_wave_dest   RESULT: ALL PASS (90 checks)
    PASS | test_calc_measure     RESULT: ALL PASS (160 checks)

  AFTER the rows, against the UNMODIFIED product (the red):
    FAIL | test_calc_wave_dest   RESULT: 11 FAILED (90 passed)     -> 101 checks
    FAIL | test_calc_measure     RESULT: 1 FAILED (159 passed)     -> 160 checks

  AFTER the rows, against a SIMULATED J1 (injected at suite file scope; src/ untouched):
  Command: env -u DISPLAY HOME=<scratch>/fakehome ./src/xschem --nogui --pipe -q --nolog --script <scratch>/sim/<suite>.tcl
    test_calc_wave_dest   OVERALL: ok (101 checks) / RESULT: ALL PASS (101 checks)
    test_calc_measure     OVERALL: ok (160 checks) / RESULT: ALL PASS (160 checks)

  SO THE PUBLISHED COUNTS J1 MUST RE-DERIVE:
    test_calc_wave_dest  90 -> 101  (+11: eleven new WD11 rows)
    test_calc_measure   160 -> 160  (UNCHANGED: MT8's row was MOVED, not added; WD8's
                                     end-to-end row is likewise still one `check`)

=== THE SUITES J1 DOES NOT TOUCH -- counted arm, unmodified product, after my edits ===
Command: tests/headless/run_suites.sh --nogui test_calc_cross test_calc_engine test_calc_scratch_reuse
    PASS | test_calc_cross            RESULT: ALL PASS (187 checks)
    PASS | test_calc_engine           RESULT: ALL PASS (265 checks)
    PASS | test_calc_scratch_reuse    RESULT: ALL PASS (54 checks)
  Same three under the simulated J1: 187 / 265 / 54, all ALL PASS.

=== THE DISPLAY ARM, under the simulated J1 ===
Command: DISPLAY=:99 GUI_GATE=0 HOME=<scratch>/fakehome ./src/xschem --pipe -q --nolog --script <mirror>/tests/headless/<suite>.tcl
(the dev display :99 was ATTACHED to and left exactly as found; the user's 172.20.160.1:0 screen was never addressed)
    test_calc_skeleton  RESULT: ALL PASS (573 checks)
    test_calc_widgets   RESULT: ALL PASS (259 checks)
    test_calc_buffer    RESULT: ALL PASS (130 checks)
    test_calc_plot      RESULT: ALL PASS (105 checks)
  All four unchanged from the figures the cost receipt measured, so nothing display-only moves.

=== THE T1 TRAILER -- DERIVED with summarize_all's own shapes, NOT predicted ===
Both suites were already registered in `hcases`, so the registration delta is ZERO. Census over
each suite's real output, before and after:
    test_calc_wave_dest: lowercase ^skip: = 0, uppercase ^SKIP:/^SKIPPED: = 0, ^RESULT: lines = 1
    test_calc_measure:   lowercase ^skip: = 0, uppercase ^SKIP:/^SKIPPED: = 0, ^RESULT: lines = 1
`banner_complete` from tests/banner_rule.tcl on the simulated-green output: 1 for both, with
`banner_died` 0 for both, and the last ^RESULT: line is the ALL PASS one.
Therefore cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with
the NUMBER of `RESULT:`/`skip:` lines, not with the counts inside them, and neither number moved.
I am NOT quoting a remembered trailer; the driver reads the trailer.

**red_proof**

Armed spelling, repo root, unmodified product tree (`git diff --stat -- src/` empty). Transcript kept at
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J-wire-dest/j1-rows/red2.txt

  $ tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
  test home: throwaway /tmp/xschem-test-home.3221387.l6ERQn (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (90 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 1 FAILED (159 passed)
  RESULT: 0/2 runs passed
  (exit 1)

The twelve failing rows, verbatim got/exp tails, in run order:

  WD9  -> {refused 1 refused 1 refused 1 refused 1} (exp {refused 1 refused 1 measured 0 refused 1}) : FAIL
  WD9  -> {1 1 1 1} (exp {1 1 0 0}) : FAIL
  WD9  -> {{cross_scalar delay dutyCycle_scalar riseTime} {} {cross_scalar delay dutyCycle_scalar riseTime} atleast} (exp {{cross_scalar delay riseTime} dutyCycle_scalar {cross_scalar delay dutyCycle_scalar riseTime} atleast}) : FAIL
  WD11 -> {refused NOKEY-db twonames notacount:{} {count=0 want=2 got={}} {count=0 want=2 got={}} tooshort:0 0} (exp {measured named twonames sized ok ok distinct 0}) : FAIL
  WD11 -> {{absent dataset dest msg ok value} {} {} NOKEY-db absent same} (exp {{absent dataset db dest msg n ok sweep type value xname yname} tmp {} named registered same}) : FAIL
  WD11 -> {{} {} 1 NOSLOT absent 0} (exp {{} {} 2 table registered 0}) : FAIL
  WD11 -> {1 0 1 absent 0 {}} (exp {2 1 1 absent 0 {}}) : FAIL
  WD11 -> {refused NOKEY-db notacount:{} atleast {count=0 want=20 got={}} {count=0 want=20 got={}} tooshort:0 tooshort:0} (exp {measured named sized atleast ok ok increasing distinct}) : FAIL
  WD11 -> {distinct distinct distinct distinct distinct distinct} (exp {distinct distinct distinct distinct same same}) : FAIL
  WD11 -> {refused NOKEY-db 2 3 NOSLOT tran op absent} (exp {measured named 2 4 table tran op registered}) : FAIL
  WD11 -> {0 2 3 tran absent} (exp {1 2 3 tran absent}) : FAIL
  MT8  -> {refused 1 NOKEY-db measured ok NOKEY-db} (exp {measured 0 named measured ok NOKEY-db}) : FAIL

EVERY ROW FAILED, NONE THREW: zero `UNEXPECTED ERROR:`, zero `BGERROR:`, zero `group ... ABORTED`
lines in either transcript, and the three WD11 control rows and all of WD0-WD8 and WD10 kept
measuring (90 of 101 checks still passed in the wave_dest suite). That is the issue-1616 trap the
brief names, and it was avoided by routing every product call through `wd_call`/`pcall`, every
count/index through `wd_len`/`wd_at`, every word-valued answer through a PROC rather than a braced
`expr` ternary, and by guarding `wd_sized`'s comparison with `string is integer -strict` (an out-of-range
`xschem raw points 0` answers the EMPTY STRING, on which a bare `>` raises).

AND THE GREEN SIDE IS REACHABLE, measured rather than asserted. A simulated J1 -- the obvious
correct implementation, which forwards a non-zero cycle unchanged, calls `calc::dutyCycle` with
cycle 0, hands `sweep`/`value` to `calc::wave_dest`, propagates a refusal through
`calc::cross_refusal` and merges `{db type xname yname n}` -- was injected at suite file scope and
gives, with src/ still untouched:

  test_calc_wave_dest | OVERALL: ok (101 checks) / RESULT: ALL PASS (101 checks)
  test_calc_measure   | OVERALL: ok (160 checks) / RESULT: ALL PASS (160 checks)

NINE SABOTAGES, every one caught, and each by the row written for it (full table in
<scratch>/J-wire-dest/j1-rows/, generators `mksab.py` + `runsab.py`):

  A_guard_only      the three-line guard deleted, dutyCycle's own dict returned -- THE NAMED
                    VACUOUS RISK. 9 wave_dest rows + MT8. Its first leg goes `measured`, so a
                    disposition-only row would have been GREEN; the registration legs stay red,
                    and WD9's re-derived union floor prints `only:3`.
  B_swapped         X and Y handed to the producer the wrong way round -- 3 rows, both
                    element-wise legs naming the offending elements.
  C_dest_key        the live destination put in `dest`, nothing in `db` -- 9 rows; the key-set row
                    prints `__calc_dest9` sitting in the key MT9b reads by name.
  D_drop_on_success the shape recon:contract prescribed and section 10(c) overturned -- 7 rows,
                    the slot-count and no-drop rows first.
  E_left_current    switched into the destination to read it back and never switched away -- the
                    two three-slot restore rows print `3` and `0` where `2` is the user's slot.
  F_merge_always    the destination's keys merged into EVERY answer -- caught ONLY by the CONTROL
                    row (plus WD10's/MT10's dict-site rows), which is why that control exists.
  G_offbyone        one point short -- `{pts:1 want:2}` and `{pts:19 want:20}`.
  H_stride          every other point -- `{pts:1 want:2}` and `{pts:10 want:20}`.
  I_wrong_layer     the engine door opened inside `calc::dutyCycle` instead of the wrapper --
                    MT10's closure row prints `{{riseTime delay dutyCycle} {{} {} wave_dest}}`, and
                    WD9's partition names `dutyCycle` where `dutyCycle_scalar` belongs.

**product_untouched**

  $ git status --short
   M tests/headless/test_calc_measure.tcl
   M tests/headless/test_calc_wave_dest.tcl
  ?? .xschem/
  ?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
  ?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/

  $ git diff --stat -- src/
  (no output -- src/ is byte-identical to HEAD)

  $ git diff --stat
   tests/headless/test_calc_measure.tcl   |  45 ++-
   tests/headless/test_calc_wave_dest.tcl | 498 +++++++++++++++++++++++++++++++--
   2 files changed, 522 insertions(+), 21 deletions(-)

The three `??` entries were present in this session's starting git-status snapshot and are not mine.
NO PRODUCT CHANGE WAS IMPLEMENTED, as the task requires: the simulated J1 lives only in
/tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J-wire-dest/j1-rows/j1impl.tcl
and was injected into SCRATCH COPIES of the suites at file scope. Nothing was committed, pushed or
gated; no full T1 was run; the owed.sh ledger was not touched; `~/dev/xschem-op-wcard`,
`~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display` and `~/.claude/gui_test_gate` were not
written. `devdisplay.sh start|stop|view` was never run -- the display-arm readings ATTACHED to the
already-running `:99` with `GUI_GATE=0` and a throwaway HOME, and it was left as found. Every
binary call carried `--nogui` or `env -u DISPLAY` or an explicit `DISPLAY=:99`; no bare `xschem`
was invoked; `/usr/bin/grep` throughout. Both edited files pass `info complete`.

No receipt .md was written: this harness instructs that findings come back as the structured
answer and that report files are not to be created, so this IS the receipt.


### declared_holes

- ⚠⚠ TWO POINTS IS THE MOST ANY COMMITTED COLUMN YIELDS, and the keystone row lives with that. `v(sq)` has three rising crossings, so two complete periods; `dataset 1` is identical; three is the most ANYTHING on the committed fixture gives (`calc::cross {v(sq)} 0.5 0 rising` -> 3). A two-point destination cannot catch a stride, an off-by-one in the fill loop or a dropped middle sample, and gives the X list only two values to put in the wrong order. Declared in the suite as hole H10.

- ⚠ THE LONG SERIES CLOSES MOST OF THAT, AND COSTS ONE THING EVERY OTHER NUMBER IN THE FILE HAS. I DID construct a longer series, as the task asked: `{time [expr {2*pi*2100}] * sin()}` at level 0.25 over the fixture's own `time` column gives TWENTY complete periods -- measured 20 points, every crossing strictly between two samples, X strictly increasing with a non-uniform stride, and the closest adjacent Y pair differing by a relative 1.6e-3, four orders outside WDTOL. Sabotage-verified: it catches a stride (`pts:10 want:20`), an off-by-one (`pts:19 want:20`), a reversal and a constant fill. WHAT IT COSTS: the suite's other numbers are derived TWICE (from the deck and from the columns); this one is derived ONCE, from the columns, because a sine sampled on a 0.1 ms grid crosses where the LINEAR INTERPOLATION puts it and not where the closed form does. The verb and the derivation are handed the identical expression string and evaluate it through the same engine, so they agree by construction -- which is honest about the hand-off and says nothing new about the duty arithmetic (WD8 owns that).

- ⚠ THE CLICK PATH IS NOT FENCED AND ITS DEFECT IS REAL, NOT HYPOTHETICAL. On a tree carrying J1 alone, a click on `dutyCycle` with the default cycle reaches `calc::fn_measure`, whose success arm is unconditionally `set num [calc::buf_set_number $v]` with no branch on the answer's shape and no numeric check in `buf_set_number` -- so the whole per-cycle LIST is pasted into the RPN buffer, violating R404 and R421 SILENTLY. Both procs return early on `calc::has_win .calc.buf`, so headless they are no-ops and nothing in either suite can observe it; I checked and no dcases row reddens either (`test_calc_buffer` 130 and `test_calc_widgets` 259 are ALL PASS under the simulated J1). Declared as suite hole H12. J1b owns it, and it is the strongest argument for J1b following J1 closely.

- ⚠ WHO FREES A DESTINATION THE USER IS LOOKING AT IS NOT DECIDED HERE, AND THE ROWS DO NOT DECIDE IT. WD11 asserts that the slot SURVIVES a successful answer and that the band can drop it; it says nothing about whether the product should, ever, or when. Declared as suite hole H11 and owned by J1b.

- NO VIEWER ARM. `wviewer::plot_sweeps_arm` still has zero callers, so J1 alone leaves the user with a registered two-column database and NO TRACE ON SCREEN. Nothing in these rows claims otherwise. (This is also why SR5's `$viaviewer == {plot_rpn}` one-name literal still holds -- verified by running, 54 checks.)

- THE DESTINATION'S USER-VISIBLE NAME IS STILL UNRULED, and the rows deliberately do not pre-empt it. Every row reads `xname`/`yname` OUT OF THE ANSWER and matches `db` against a GLOB, never a literal -- because `calcx` is printed on the X axis by `draw_graph_variables`, `calcy` becomes the legend entry, `__calc_dest<N>` appears in the Results picker, and none of the three has been ruled. The glob is also required for a second reason: `__calc_dest<N>` carries a namespace serial that this suite's own earlier bands advance.

- THE `shape` KEY OF SECTION 4 IS NOT REQUIRED BY J1. I chose the key set `{absent dataset db dest msg n ok sweep type value xname yname}` -- `calc::dutyCycle`'s own keys plus `calc::wave_dest`'s `db type xname yname n`, with `dest` LEFT HOLDING THE RETIRED `__calc_tmp` and `prev`/`prevtype` deliberately NOT merged (they are the producer's restore bookkeeping and one of them is an absolute filesystem path, which has no business in a measurement answer; `calc::wave_dest_drop` re-reads the current slot itself, verified). The key-set row is EXACT, so when J1b adds `shape` it reddens naming the new key and J1b widens it on purpose. That is a declared future red, not an accident.

- THE RESTORE ROWS ASSERT THE CURRENT SLOT AND SAY NOTHING ABOUT `prev`. That half is a pre-existing defect (see the exclusions) and asserting it would be red on correct J1 code.

- I DID NOT RUN A FULL T1, DID NOT COMMIT, AND DID NOT GATE -- all three are the driver's. The trailer figures above are DERIVED from `summarize_all`'s own shapes over the real output; the driver reads the trailer.


### preexisting_defects_excluded

- (a) `switch_back` AFTER A SUCCESSFUL `calc::wave_dest` LANDS ON THE DESTINATION -- `calc::wave_dest_restore` puts back one half of a registry cursor that is a pair. I RE-MEASURED it rather than taking it on trust (probe p6.tcl): parked at `cur=2 prev=<tran>` of three slots, after `calc::wave_dest` the inventory reads `cur=2` correctly, and then `xschem raw switch_back` -> rc 1, `CUR-NOW= 3` -- the destination. HOW I KEPT IT OUT: no row in WD11 or in the moved rows issues `xschem raw switch_back` or reads `prev`/`prevtype` at all, and I excluded `prev`/`prevtype` from the key set I chose for the answer dict, so no row can reach them. The two three-slot restore rows assert `wd_curslot` ONLY, which is the half J1 is responsible for, and the exclusion is written into the band's own comment so the next reader does not 'complete' the row and redden it. Verified: both restore rows are GREEN on the `wd_curslot` leg today (it prints `2`) and red only on the destination legs, so the stage's red is unambiguous about what it is about.

- (b) A BARE `raw switch <name>` IS ROUND-ROBIN, NOT 'silently slot 0' as DESTINATION_CONTRACT.md section 7 hazard 1 says. I RE-MEASURED it (probe p6.tcl): from slot 2 of a four-slot registry, `xschem raw switch <path>` answers rc 1 and lands on slot 3, i.e. `(cur+1) % n`; and a non-matching `raw switch <bogus> table` answers 0 and moves nothing. HOW I KEPT IT OUT: I wrote NO row asserting anything about a bare one-argument switch -- that is band WD0's subject, where it is already measured on the bare verbs. Where it matters is the OPPOSITE direction, and that is where I used it: the task's warning is that a restore fence written from section 7's account PASSES ON A TWO-SLOT FIXTURE, so the restore rows use THREE loads with the user on a NON-ZERO slot. New loader `wd_load3t` reads the fixture as `op`, `ac`, `tran` IN THAT ORDER -- the inverse of the existing `wd_load3`, which leaves the user on `op` where there is no sweep column at all and a `dutyCycle` is refused for a reason that has nothing to do with a destination (band WD8's own comment records that correction). From slot 2 of 3, a bare switch lands on 0 and `switch_back` lands on the destination; neither is 2, so both wrong restores stay live and the fence is not vacuous.

- (c) A THIRD ONE I HAD TO KEEP OUT AND THE TASK DID NOT NAME: `calc::fn_measure`'s unconditional success arm. A structural row asserting 'fn_measure has a wave arm' would be the name-describes-coverage trap, and a behavioural one is unreachable headless (both procs return early on `calc::has_win .calc.buf`). I wrote NO row about it and declared it as suite hole H12 instead, naming the owner.



## attack:guard-deleted

**sabotage**

A_guard_only, exactly as assigned: `calc::dutyCycle_scalar`'s three-line `cycle == 0` deferral guard deleted, so the wrapper is a bare pass-through to `calc::dutyCycle`, which already answers `ok 1` today with the per-cycle fraction series in `value` and R420's parallel X series in `sweep`. No destination is built, nothing is registered, no `db` key exists.

Product diff is a pure three-line deletion (`git diff -- src/calculator.tcl`), in the worktree:

    proc calc::dutyCycle_scalar {rpn level {cycle 0} {dataset 0} {xaxis start}} {
    -    if {[calc::eval_finite $cycle] && [expr {double($cycle) == 0.0}]} {
    -        return [calc::cross_refusal [calc::cross_msg listdefer] $dataset]
    -    }
         return [calc::dutyCycle $rpn $level $cycle $dataset $xaxis]
     }

This is plausible precisely because it is what the shipped banner invites: `calc::dutyCycle`'s own comment says the verb "ALREADY returns the complete series", and `calc::dutyCycle_scalar`'s banner says the wave case "DEFERS ... and waits for a destination that can hold a wave with its own X axis -- which `calc::wave_dest` NOW BUILDS". An engineer who reads only those two sentences concludes the wait is over and deletes the guard. It is a one-line-net change that makes the verb stop refusing, which is the user-visible symptom the stage was opened to fix.

I ALSO measured the natural stealth variant of the same family, because the lazy fix normally ships with a note: the same deletion plus a three-line whole-line comment and a trailing `;# calc::wave_dest` inside the proc body, aimed at `wd_wiredcallers`' `regexp {calc::wave_dest[^A-Za-z0-9_]}`. It does NOT work. `wd_code` strips both the whole-line form and the trailing form (its trailing arm tests `info complete` on the head), so `wd_wiredcallers` stayed `{}`, the union floor still printed `only:3`, and the run was byte-identical at `9 FAILED (92 passed)`. The instrument is not fooled by prose.

Environment: worktree `/home/analog/dev/xschem-claude/.claude/worktrees/wf_1b9f924a-41d-2`. ⚠ It arrived checked out at `052b29f1`, an unrelated old commit, NOT at `fluid-editing`; I `git reset --hard 82711083` and copied in the author's two UNCOMMITTED suite files from the main checkout (`tests/headless/test_calc_wave_dest.tcl`, `tests/headless/test_calc_measure.tcl` -- a fresh worktree cannot see uncommitted work). The main working directory was read only. `src/xschem` was copied from the main tree and `XSCHEM_SHAREDIR` verified to resolve to the WORKTREE's own `src/` (`SHAREDIR=/home/analog/dev/xschem-claude/.claude/worktrees/wf_1b9f924a-41d-2/src`), so the runs below really do exercise the edited `calculator.tcl`. Every call carried `env -u DISPLAY` plus `--nogui`; no bare `xschem`; `/usr/bin/grep` throughout; nothing committed, pushed or gated; no full T1; the owed ledger untouched.

**why_wrong**

The user clicks `dutyCycle`, leaves the cycle ordinal at its default (meaning *all* cycles), and gets no refusal and no error -- and no measurement either.

The verb answers success carrying a LIST of per-cycle fractions in `value`. Nothing is registered: there is no database, no `db` key, no two-column destination, and no trace. On the click path `calc::fn_measure`'s success arm is unconditional -- `set v {}; catch {set v [dict get $d value]}; set num [calc::buf_set_number $v]` -- and `calc::buf_set_number` does `.calc.buf delete 1.0 end; .calc.buf insert end $n` with no numeric check. So the whole series is pasted into the RPN buffer as if it were a number: on the fixture's `v(lp)` at level 0.5 the user's RPN entry fills with `0.2999385393208259 0.2999017475874794`. R404 ("a literal number") and R421 ("the number lands in the buffer") are both violated SILENTLY -- a wrong buffer, not a message. The next Evaluate then operates on that.

And it reads as a shipped feature. The deferral sentence is gone, so the one signal that told the user the feature was not ready is gone too, replaced by a success. Worse than the old refusal in exactly the way the batch cares about: before, the product said plainly it could not do this yet; after, it says it did it, and the artefact the user is shown is garbage in a number field. Nothing appears on screen, because `wviewer::plot_sweeps_arm` is never armed, so there is nothing for the user to compare the buffer against.

**verdict**

CAUGHT

**evidence**

BASELINE (author's rows, UNMODIFIED product, worktree at 82711083):

  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
  test home: throwaway /tmp/xschem-test-home.3232230.PKqTD4 (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (90 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 1 FAILED (159 passed)
  RESULT: 0/2 runs passed
  (failing bands: WD9 x3, WD11 x8, MT8 x1 -- reproduces the author's red_proof exactly)

SABOTAGE RUN (guard deleted), same spelling, same tree otherwise:

  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure
  test home: throwaway /tmp/xschem-test-home.3233542.ie6NTb (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 9 FAILED (92 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 1 FAILED (159 passed)
  RESULT: 0/2 runs passed
  (exit 1; transcript kept at <scratch>/J-wire-dest/adv-guard/sab.txt)

  $ /usr/bin/grep -o 'FAIL: WD[0-9]*\|FAIL: MT[0-9]*' sab.txt | sort | uniq -c
        1 FAIL: MT8
        8 FAIL: WD11
        1 FAIL: WD9

The ten verbatim got/exp tails, in run order:

  WD9  -> {{cross_scalar delay riseTime} {} {cross_scalar delay riseTime} only:3} (exp {{cross_scalar delay riseTime} dutyCycle_scalar {cross_scalar delay dutyCycle_scalar riseTime} atleast}) : FAIL
  WD11 -> {measured NOKEY-db twonames notacount:{} {count=0 want=2 got={}} {count=0 want=2 got={}} tooshort:0 0} (exp {measured named twonames sized ok ok distinct 0}) : FAIL
  WD11 -> {{absent dataset dest msg ok sweep value} tmp {} NOKEY-db absent same} (exp {{absent dataset db dest msg n ok sweep type value xname yname} tmp {} named registered same}) : FAIL
  WD11 -> {{} {} 1 NOSLOT absent 0} (exp {{} {} 2 table registered 0}) : FAIL
  WD11 -> {1 0 1 absent 0 {}} (exp {2 1 1 absent 0 {}}) : FAIL
  WD11 -> {measured NOKEY-db notacount:{} atleast {count=0 want=20 got={}} {count=0 want=20 got={}} tooshort:0 tooshort:0} (exp {measured named sized atleast ok ok increasing distinct}) : FAIL
  WD11 -> {distinct distinct distinct distinct distinct distinct} (exp {distinct distinct distinct distinct same same}) : FAIL
  WD11 -> {measured NOKEY-db 2 3 NOSLOT tran op absent} (exp {measured named 2 4 table tran op registered}) : FAIL
  WD11 -> {0 2 3 tran absent} (exp {1 2 3 tran absent}) : FAIL
  MT8  -> {measured 0 NOKEY-db measured ok NOKEY-db} (exp {measured 0 named measured ok NOKEY-db}) : FAIL

STEALTH VARIANT (same deletion + a whole-line comment and a trailing `;# calc::wave_dest` in the body, attacking `wd_wiredcallers`):

  FAIL     | test_calc_wave_dest          run 1/1  RESULT: 9 FAILED (92 passed)
  FAIL: WD9 ... PARTITION ... -> {{cross_scalar delay riseTime} {} {cross_scalar delay riseTime} only:3} (exp {{cross_scalar delay riseTime} dutyCycle_scalar {cross_scalar delay dutyCycle_scalar riseTime} atleast}) : FAIL
  RESULT: 0/1 runs passed

COLLATERAL -- the three counted-arm Calculator suites J1 does not touch, under the sabotage:

  $ env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_cross test_calc_engine test_calc_scratch_reuse
  PASS     | test_calc_cross              run 1/3  RESULT: ALL PASS (187 checks)
  PASS     | test_calc_engine             run 2/3  RESULT: ALL PASS (265 checks)
  PASS     | test_calc_scratch_reuse      run 3/3  RESULT: ALL PASS (54 checks)
  RESULT: 3/3 runs passed

So nothing outside WD9/WD11/MT8 sees this defect -- confirming the author's apportionment and confirming that without WD11 the stage would have had no fence.

**which_row_caught_it**

CAUGHT by TEN rows, which matches the author's prediction of "9 wave_dest rows + MT8" exactly. The decisive ones, ranked by what they contribute:

1. **WD9's derived-caller partition row** (the re-derived union floor) -- the ONLY pre-existing row that catches it, and it does so by itself: `wd_wiredcallers` is empty and the union collapses to three, printing `only:3`. This vindicates section 10(f)'s instruction that the `atleast` leg be **re-derived over the union rather than decremented**. Had it been decremented to 3, as the obvious edit would have, this row would have gone GREEN and the entire pre-existing-row set would have been vacuous against the sabotage.
2. **All eight WD11 rows** -- the registration legs (`NOKEY-db`, `notacount:{}`, `count=0 want=2`, `NOSLOT`, `absent`, slot count `1` not `2`) and the no-drop row's `{1 0 1 ...}`. These are the new band's whole justification.
3. **MT8's moved row**, red on its `named` leg alone (`NOKEY-db`).

⚠⚠ **THE FINDING WORTH THE DRIVER'S ATTENTION IS WHAT WENT GREEN, AND IT IS WORSE THAN THE AUTHOR'S OWN PREDICTION.** The author wrote that A_guard_only's "first leg goes `measured`, so a disposition-only row would have been GREEN". Measured, it is not one leg -- it is **two entire rows of the four the author counts as J1's red**. The baseline is 12 red rows; the sabotage is 10. The two that flipped fully green are:

  * `WD9 EVERY caller STILL WAITING answers THAT SAME SENTENCE BY IDENTITY ...` -- baseline `{refused 1 refused 1 refused 1 refused 1}` vs expected `{refused 1 refused 1 measured 0 refused 1}`; **satisfied exactly** by the sabotage.
  * `WD9 ...and pairwise along the whole chain ...` -- baseline `{1 1 1 1}` vs expected `{1 1 0 0}`; **satisfied exactly** by the sabotage.

Both pass against an implementation that builds nothing. So of the stage's four "moved rows", **two fence nothing for J1** -- they assert only that the shared deferral sentence was retired, which a three-line deletion does. That is not an argument to change them (they still forbid a re-deferral and a per-caller split, which is their stated job, and the author's `why_not_a_weakening` for both is about identity rather than registration). It IS the argument that **WD11 and the un-decremented union floor are the whole of J1's fence**, and it should be stated that way in the ledger rather than implying four rows of coverage. The honest count is: 1 pre-existing row + 8 new rows + 1 leg of MT8.

Two further measurements, both negative results that close holes rather than open them:
* The union-floor leg is **not** fooled by prose. `wd_code` strips whole-line comments and, via its `info complete` head test, trailing `;#` comments too, so a lazy fix carrying a TODO that names `calc::wave_dest` still prints `only:3` with a byte-identical `9 FAILED (92 passed)`. The `[^A-Za-z0-9_]` exclusion the row's own comment flags as load-bearing is intact.
* No row anywhere else sees this. `test_calc_cross` (187), `test_calc_engine` (265) and `test_calc_scratch_reuse` (54) are all ALL PASS under the sabotage.

Nothing survived, so there is no hole to declare in this family. By construction every registration leg is red whenever no destination is built, so **no variant of guard-deletion can pass WD11** -- the only attack surface left in the family was the WD9 derivation, and it held.



## attack:constant-y

**sabotage**

CONSTANT-Y, planted in `calc::dutyCycle_scalar` (src/calculator.tcl) and nowhere else. The wiring is byte-for-byte what a correct J1 does — the only defect is one index.

The shape, exactly as implemented:
 * guard INVERTED rather than deleted: a non-finite or non-zero `cycle` forwards to `calc::dutyCycle` unchanged (so the named-cycle scalar and R420's `xaxis` pass-through are untouched);
 * the default cycle calls `calc::dutyCycle $rpn $level 0 $dataset $xaxis` and returns a refusal or an absence straight through (`if {![dict get $d ok]} { return $d }`), so the CONTROL row's "a level the wave never reaches" arm still answers an absence with no `db`;
 * the destination is reached from the WRAPPER, never from `calc::dutyCycle` — MT10's callee-ward closure over `{riseTime delay dutyCycle}` cannot see a wrapper, which I confirmed by running it (test_calc_measure ALL PASS);
 * `{db type xname yname n}` merged onto the measurement's own dict, `dest` left holding the retired `__calc_tmp`, `prev`/`prevtype` deliberately not merged — so the exact key set `{absent dataset db dest msg n ok sweep type value xname yname}` is answered;
 * NOT dropped on the success path.

THE DEFECT. Instead of handing the two parallel lists over directly, the producer builds them in an explicit normalising loop — plausibly motivated, since R420's `number` axis hands back 1-based integer ordinals and the engine's columns are doubles:

    for {set i 0} {$i < $np} {incr i} {
        lappend xs [expr {double([lindex $sw $i])}]
        lappend ys [expr {double([lindex $vals 0])}]     ;# <-- 0 where $i belongs
    }

The Y line is the X line copied and edited, with the subscript missed. Y is filled with `value`'s element 0 at every point. Nothing else about the destination is wrong: right registry name, right `table` type, right point count, right column names, and the X column is R420's `start` axis element-for-element correct.

**why_wrong**

The user asks `dutyCycle` for what R416 rules it means — "a wave, one value per cycle" — and gets a FLAT LINE at the first cycle's duty fraction. Every per-cycle variation, which is the only reason to ask for a wave rather than a number, is gone.

And it is wrong in the way that is hardest to notice, because nothing looks broken. The destination is a properly registered `__calc_dest<N>` of sim_type `table` with `calcx`/`calcy` at the right point count, so it appears in the Results picker, a trace resolves it by registry name through `wviewer::db_suffix`, the X axis is correct, and the trace draws. A user glancing at the status line sees a plausible duty-cycle number. The only tell is that the curve is flat — and on a signal whose duty really is near-constant, a user would never tell at all.

The magnitudes, measured on this tree: on the fixture's own `v(lp)` at L=0.5 the second of the two points is wrong by a relative 1.23e-4; on the 20-point sine series the band builds, 19 of 20 points are wrong, by up to a relative 3.4e-2 (3.4%). So on a real waveform it is a visibly wrong plot, and on the committed two-point square it would have been invisible.

**verdict**

CAUGHT

**evidence**

RED BASELINE FIRST (author's rows, product UNMODIFIED, in this worktree — proving the harness is faithful before the sabotage went in):

  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 11 FAILED (90 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 1 FAILED (159 passed)
  RESULT: 0/2 runs passed

AGAINST THE SABOTAGE — armed spelling, `tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure`, reproduced twice:

  test home: throwaway /tmp/xschem-test-home.3237045.AWBI5n (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 3 FAILED (98 passed)
  PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (160 checks)
  RESULT: 1/2 runs passed

THE THREE FAILING ROWS, verbatim got/exp tails:

  FAIL: WD11 R419/R420 dutyCycle_scalar's DEFAULT cycle stops deferring ... -> {measured named twonames sized ok {[1]off:{0.2999385393208259} rel=0.00012267928960900344} same 0} (exp {measured named twonames sized ok ok distinct 0}) : FAIL

  FAIL: WD11 ...and the same claim on a series LONG enough to be worth making ... -> {measured named sized atleast ok {[1]off:{0.4121560065252599} rel=0.0028797431727400256 [2]off:{0.4121560065252599} rel=0.03058003913132591 [3]off:{0.4121560065252599} rel=0.03220582364586997 [4]off:{0.4121560065252599} rel=0.0044903189881143855 [5]off:{0.4121560065252599} rel=0.016520413031054164 [6]off:{0.4121560065252599} rel=0.02715219408403952 [7]off:{0.4121560065252599} rel=0.03380748439709456 [8]off:{0.4121560065252599} rel=0.013559849337495832 [9]off:{0.4121560065252599} rel=0.012095661226958224 [10]off:{0.4121560065252599} rel=0.022404076866616083 [11]off:{0.4121560065252599} rel=0.03443999618795028 [12]off:{0.4121560065252599} rel=0.02049032131410743 [13]off:{0.4121560065252599} rel=0.007963873705509217 [14]off:{0.4121560065252599} rel=0.01607792682972712 [15]off:{0.4121560065252599} rel=0.03413253562139628 [16]off:{0.4121560065252599} rel=0.02572055543332712 [17]off:{0.4121560065252599} rel=0.00402965220507771 [18]off:{0.4121560065252599} rel=0.007814818866772677 [19]off:{0.4121560065252599} rel=0.03286758510649135} increasing same} (exp {measured named sized atleast ok ok increasing distinct}) : FAIL

  FAIL: WD11 ...and this row's own DISCRIMINATION, derived rather than claimed ... -> {distinct distinct distinct distinct same distinct} (exp {distinct distinct distinct distinct same same}) : FAIL

NO COLLATERAL — the three counted suites J1 does not touch, identical to the author's figures for a CORRECT J1, so the sabotage is indistinguishable from correct code everywhere except the Y-reading legs:

  PASS     | test_calc_cross              run 1/3  RESULT: ALL PASS (187 checks)
  PASS     | test_calc_engine             run 2/3  RESULT: ALL PASS (265 checks)
  PASS     | test_calc_scratch_reuse      run 3/3  RESULT: ALL PASS (54 checks)
  RESULT: 3/3 runs passed

THE COUNTERFACTUAL I DROVE RATHER THAN QUOTED (section 10(a), measured against a live sabotage instead of against a numeric spread). Scratch copy of the suite with the KEYSTONE's column changed `v(lp)` -> `v(sq)` and its distinctness leg written as `same` — which is what correct code answers on `v(sq)`, so an author on that fixture could not have written `distinct`:

  FAIL | test_sabcy_vsq run 1/1 RESULT: 3 FAILED (98 passed)
  FAIL: WD11 ...and the same claim on a series LONG enough to be worth making: many times more points
  FAIL: WD11 ...and this row's own DISCRIMINATION, derived rather than claimed: against the very same
  FAIL: WD11 the CONTROL: a NAMED cycle is the scalar it always was and builds NO destination -- no db

The keystone is ABSENT from that failure list: on `v(sq)` it goes GREEN against this sabotage. (The CONTROL row's red there is an ARTEFACT of my edit, not a finding — it compares `[wd_is $e [lindex $dy 0]]` and my edit repointed `$dy` to `v(sq)`, so it measured `v(lp)`'s cycle-1 scalar against `v(sq)`'s first fraction: `{off:{0.2999385393208259} rel=0.00020486893058095168}`.)

ENVIRONMENT. Isolated worktree at a 54-char path, `src/calculator.tcl` the only product file touched; `git diff --stat -- src/` is 31 lines in one proc. No commit, no push, no gate, no T1, no `owed.sh`, no `devdisplay.sh start|stop|view`, nothing written in `~/dev/xschem-op-wcard`, `~/.xschem/ase_simulators`, `~/.claude/*`. Every call went through `run_suites.sh --nogui`; no bare `xschem`; `/usr/bin/grep` throughout; `info complete` on the edited file answers 1.

**which_row_caught_it**

CAUGHT BY THREE ROWS AND FIVE LEGS, every one of them a NEW WD11 row. The author drove `v(lp)` and carried the distinctness legs, exactly as the task anticipated.

1. **WD11 keystone** — two legs, independently sufficient:
   * leg 6, `wd_listcmp $apy $dy $WDTOL`, naming the offending element and the relative error: `{[1]off:{0.2999385393208259} rel=0.00012267928960900344}`;
   * leg 7, `wd_alldistinct $apy` -> `same` where `distinct` is expected.
   ⚠ The diagnostic quality is the thing worth reporting: legs 1-5 are ALL GREEN (`measured named twonames sized ok`). The row says, in one line, "the destination is registered, correctly named, correctly sized, and its X column is right — and its Y column is a constant." That is the exact defect, read straight off the verdict with no re-run.

2. **WD11 long series (20 points)** — the same two legs, 19 times over, every offending element holding the identical value `0.4121560065252599`, which is y[0]. A reader sees "one value repeated" without being told.

3. **WD11 discrimination row** — its LAST leg, `wd_cmpword $bpy $ldy $WDTOL` -> `distinct` where `same` is expected.

WHAT MT8 COULD NOT SEE, AND WHY THAT IS RIGHT. `test_calc_measure` is **ALL PASS (160 checks)**. MT8's moved legs are `{measured 0 named measured ok NOKEY-db}` — disposition, sentence-retirement identity, and a `db` name. It never reads a column, so it cannot see a wrong fill. That is correct scoping, not a hole: the column claim lives in WD11, which is where the author put it.

TWO FINDINGS THE FENCE SHOULD KEEP, BOTH MEASURED HERE:

(a) **THE KEYSTONE'S COLUMN CHOICE IS LOAD-BEARING FOR THE KEYSTONE AND NOTHING ELSE SAVES IT.** Driven on `v(sq)`, the keystone is GREEN against this sabotage (evidence above). Section 10(a) is therefore not merely an arithmetic observation about a 1.8e-15 spread — it is the difference between a row that catches constant-y and a row that reads as coverage of it. **The long-series row is the independent catcher**: it drives the 20-point sine and reddened in BOTH fixtures, so the band survives a future editor "simplifying" the keystone back onto the committed square. That redundancy is the most valuable property of the band and should be stated in its comment, because the two rows look like the same claim twice and are not.

(b) ⚠ **ONE LEG OF THE DISCRIMINATION ROW IS BLIND TO THE VERY DEFECT ITS NAME ADVERTISES.** The row's name says *"a column filled with its own first element does not satisfy either"*, and its legs 3-4 build exactly that: `wd_cmpword [lrepeat [wd_len $ldy] [wd_at $bpy 0]] $ldy $WDTOL`. Under constant-y those legs DO NOT MOVE — `lrepeat n bpy[0]` is already equal to `$bpy`, so the leg compares the sabotage's own column against the derivation and answers `distinct`, which is what the expectation says. Only the row's unaltered-column legs (5-6) move. So the constant-fill controls are an instrument check on `wd_cmpword`, not a fence on a constant fill, and anyone reading that row's name as covering this defect would be wrong. The fence is sound because legs 5-6 exist; the NAME overstates what legs 3-4 do, which is this tree's own "name describes coverage, not method" trap in miniature. Worth one clause in the row's name, or a sentence in the band comment.

DECLARED UNMEASURED: the display arm (`test_calc_skeleton`, `test_calc_widgets`, `test_calc_buffer`, `test_calc_plot`). My standing constraints require `--nogui` or `env -u DISPLAY` on every call, so I did not run it. Reasoning, not measurement: the sabotage adds no proc, no `-command`, no catalogue or `returns` edit, so no display-only row's subject moves, and the author's hole H12 records that nothing on that arm observes a wave answer at all (both `calc::fn_measure` and `calc::buf_set_number` return early on `calc::has_win .calc.buf`). If anything there could see a wrong Y column, H12 would be false.

TWO HOUSEKEEPING NOTES FOR THE DRIVER. (1) **This worktree was created at the WRONG commit** — `052b29f1 Add Claude Code GitHub Actions workflow`, not the batch HEAD — and had no `doc/claude/calculator_batch/` at all. I reset my own isolated branch to `82711083` to do the work; any other crew spawned the same way should check `git log --oneline -1` before reading the contract, or it will read nothing. (2) To exercise the author's rows I copied the two uncommitted suite files out of the shared checkout and copied the main tree's `src/xschem` into this worktree's `src/` (so `XSCHEM_SHAREDIR` resolves here, via the exe-path detection in `xinit.c`, and my sabotaged `calculator.tcl` is the one that loads). Both are staged-in artefacts, not product changes: the only product diff is `src/calculator.tcl`.



## attack:restore-skipped

**sabage**

placeholder

**sabotage**

RESTORE-SKIPPED, implemented in J1's own layer — `calc::dutyCycle_scalar`'s default-cycle arm restores the user's slot with ONE BARE NAME-ONLY `xschem raw switch`.

The producer is otherwise correct and plausible: the default-cycle arm calls `calc::dutyCycle` with cycle 0, returns early on a refusal or an absence, hands `sweep`/`value` to `calc::wave_dest`, propagates a destination refusal through `calc::cross_refusal`, merges `{db type xname yname n}` into the measurement's own dict (leaving `dest` holding the retired `__calc_tmp`), and does NOT drop on success.

The defect is a defensive read-back. Hazard 3's own shipped comment in `calc::wave_dest` says `xschem raw new` answers rc 1 for a database it did not allocate, so "the only honest test is the point count" — a competent engineer applies that one layer up and re-reads the destination's own `xschem raw points 0` before telling the user it exists. To do that the wrapper must switch INTO the destination, and it then puts the user back with:

    catch {xschem raw switch [dict get $d prev]}

one argument, name only, because the answer dict carries `prev` and the engineer reasons that one raw file is loaded so the name is unambiguous. It is not: a bare one-arg `raw switch` is ROUND-ROBIN, and on this fixture all three analysis slots share ONE path, so a name cannot express a slot at all.

Also measured, two neighbouring members of the same family:
 * variant B — the restore line deleted entirely (= what `calc::wave_dest_restore` does when handed an empty type, since it returns 0 before switching). The user is left parked ON the destination.
 * variant C — `xschem raw switch [dict get $d prev] tran`, the type HARDCODED rather than omitted. **This one SURVIVES.**

Worktree left carrying variant A. Scratch, probes and all four transcripts under /tmp/claude-1000/-home-analog-dev-xschem-claude/f12b1fd5-2898-41a7-9dd9-9fd4b899f2af/scratchpad/J-wire-dest/adv-restore/ (`calculator.sabA.tcl`, `p1.tcl`-`p4.tcl`, `sabA_final.txt`, `sabB.txt`, `sabC.txt`, `control.txt`).

**why_wrong**

The user measures a duty cycle and `results::current` stops answering their own analysis. Measured through the product on the sabotaged tree (probe `p2.tcl`), and the slot counts the task asked for:

TWO registered slots (the user's single `tran` read + the destination) — user was on slot 0, destination is slot 1 and current, round-robin lands on slot 0. **The user ends up RIGHT, by accident.** `results::current -> ... type tran ... label {calc_fixture.raw (tran)}`, unchanged. The defect is invisible.

FOUR registered slots (`op`, `ac`, `tran` + the destination) — user was on slot 2, their `tran`; destination is slot 3 and current; round-robin `(3+1)%4` lands on slot 0:

    before: slots=3 current=2
       results::current -> {idx 2 ... type tran ... label {calc_fixture.raw (tran)}}
    answer ok=1 db=__calc_dest2 n=2
    after : slots=4 current=0
       results::current -> {idx 0 ... type op ... label {calc_fixture.raw (op)}}
       xschem raw sim_type -> {op}

The user asked for a duty cycle on their transient and is silently moved onto the **operating point of the same file** — a different analysis, with no sentence. Every later Calculator evaluation, the Results row, and `xschem raw sim_type` now answer `op`, so the next RPN the user types is evaluated against a 1-point database.

And the drop cannot recover it: `calc::wave_dest_drop` captures the CURRENT slot, which is already wrong, so after `drop -> 1` the user is still on slot 0 `op`. The damage outlives the destination.

Variant B is worse and also reachable: with no restore at all the user is left parked on `__calc_dest<N>` itself, where `xschem raw sim_type` is `table`, their own vectors do not exist, and the very next measurement refuses (MT8 reddened in exactly that way: `NOTANUMBER:{refused}`).

Variant C — the SURVIVING one — hardcodes `tran`. Measured reachable (probe `p4.tcl`): a user parked on the `ac` slot of a three-slot registry, running a default-cycle `dutyCycle` over an RPN of their own across the ac sweep column, is moved off their ac analysis onto the tran one:

    before: current=2 sim_type=ac   label={calc_fixture.raw (ac)}
    answer ok=1 db=__calc_dest1 n=4 value=0.40351800717019476 0.4110461761009056 ...
    after : current=1 sim_type=tran label={calc_fixture.raw (tran)}

**verdict**

CAUGHT — my assigned sabotage. But a neighbouring member of the same family SURVIVES, and that is the finding worth keeping: see `which_row_caught_it`.

**evidence**

All runs: armed spelling, `--nogui`, worktree root, author's two edited suites copied in verbatim.

=== BASELINE: the author's red, reproduced in this worktree (product unmodified) ===
  FAIL     | test_calc_wave_dest          run 1/1  RESULT: 11 FAILED (90 passed)
  RESULT: 0/1 runs passed

=== MY ASSIGNED SABOTAGE (variant A, name-only round-robin restore) ===
$ tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure test_calc_cross test_calc_engine test_calc_scratch_reuse
  test home: throwaway /tmp/xschem-test-home.3240743.THVlZe (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)
  display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
  FAIL     | test_calc_wave_dest          run 1/5  RESULT: 2 FAILED (99 passed)
  PASS     | test_calc_measure            run 2/5  RESULT: ALL PASS (160 checks)
  PASS     | test_calc_cross              run 3/5  RESULT: ALL PASS (187 checks)
  PASS     | test_calc_engine             run 4/5  RESULT: ALL PASS (265 checks)
  PASS     | test_calc_scratch_reuse      run 5/5  RESULT: ALL PASS (54 checks)
  RESULT: 4/5 runs passed

The two failing rows, verbatim got/exp tails:

  FAIL: WD11 the user's own slot is theirs again after the default cycle lands a destination, driven from slot TWO of THREE -- ... -> {measured named 0 4 table tran op registered} (exp {measured named 2 4 table tran op registered}) : FAIL
  FAIL: WD11 ...and dropping it from the non-zero slot puts the user back there too, which is TWO switches and not one because raw clear forces the current slot to 0 whatever it was -- ... -> {1 0 3 tran absent} (exp {1 2 3 tran absent}) : FAIL

So 10 of the 12 rows that were red on the clean tree (nine of the eleven new WD11 rows, plus MT8) went GREEN against a producer that strands the user on a different analysis.

=== CONTROL: one word changed, nothing else (`switch $prev` -> `switch $prev $prevtype`) ===
  PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (101 checks)
  PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (160 checks)
  RESULT: 2/2 runs passed
That attributes the 2-row red to the restore alone: the rest of the producer, the key set, the no-drop choice and both element-wise legs are correct.

=== VARIANT B: no mid-life restore at all (user parked ON the destination) ===
  FAIL     | test_calc_wave_dest          run 1/2  RESULT: 2 FAILED (99 passed)
  FAIL     | test_calc_measure            run 2/2  RESULT: 1 FAILED (159 passed)
  RESULT: 0/2 runs passed
  FAIL: WD11 the user's own slot is theirs again ... -> {measured named 3 4 table tran op registered} (exp {measured named 2 4 table tran op registered}) : FAIL
  FAIL: WD11 ...and dropping it from the non-zero slot ... -> {1 0 3 tran absent} (exp {1 2 3 tran absent}) : FAIL
  FAIL: MT8 ... -> {measured 0 named refused NOTANUMBER:{refused} NOKEY-db} (exp {measured 0 named measured ok NOKEY-db}) : FAIL
⚠ STILL ONLY TWO wave_dest rows, and the keystone is not one of them — see below.

=== VARIANT C: the restore type HARDCODED (`switch $prev tran`) -- SURVIVES ===
  PASS     | test_calc_wave_dest          run 1/2  RESULT: ALL PASS (101 checks)
  PASS     | test_calc_measure            run 2/2  RESULT: ALL PASS (160 checks)
  RESULT: 2/2 runs passed

=== THE ROUND-ROBIN ACCIDENT, measured directly (probe p1.tcl) ===
  A: one slot + dest, dest current at 1: bare one-arg switch rc=1 -> cur=0   (user wanted 0)  ACCIDENT
  B: three slots + dest, dest current at 3: bare one-arg switch rc=1 -> cur=0 (user wanted 2)  WRONG
     repeated: cur=0 -> 1 -> 2, i.e. (cur+1) mod n, confirming round-robin
  C: two-arg switch <name> tran from slot 3 of 4 -> cur=2  correct
  D: switch_back immediately after `raw new` from slot 3 of 4 -> cur=2  correct

**which_row_caught_it**

CAUGHT BY: `WD11 the user's own slot is theirs again after the default cycle lands a destination, driven from slot TWO of THREE ...` and its sibling `WD11 ...and dropping it from the non-zero slot puts the user back there too ...`, both in `tests/headless/test_calc_wave_dest.tcl`. The author's `wd_load3t` loader (`op`, `ac`, `tran`, user on slot 2) is exactly right and is the ONLY thing in either suite that can see this defect. Its own comment predicted this attack verbatim — *"from slot 1 of 2 that lands on slot 1 -- the right answer for the wrong reason"* — and the prediction held.

TWO FINDINGS THE AUTHOR SHOULD HAVE, both measured rather than argued.

(1) ⚠ FOUR OF THE FIVE `wd_curslot` LEGS IN WD11 ARE VACUOUS AGAINST ANY RESTORE DEFECT, and the fence rests on a single row pair. The keystone row, the slot-count row, the no-drop row and the probe-gone row all read `wd_curslot` AFTER the band has itself issued `pcall xschem raw switch $::fixture tran` — a name-AND-type switch that lands correctly whatever the producer did. PROVED by variant B: with NO restore at all the user is left parked on the destination, and the keystone's `wd_curslot` leg is still green; only the `wd_load3t` pair reddens. So those four `0`s are the band's own switch answering, not the producer. They are not wrong to be there (they fence a leak), but they must not be read as restore coverage, and the critic's row sketch in `J-wiring-recon-critic.md` had the same `pcall xschem raw switch $::fixture tran` immediately before the check — that vacuity shipped from the sketch into the band.

(2) ⚠⚠ A SURVIVING SABOTAGE IN THE SAME FAMILY: THE RESTORE TYPE HARDCODED RATHER THAN OMITTED. `catch {xschem raw switch [dict get $d prev] tran}` gives `ALL PASS (101 checks)` and `ALL PASS (160 checks)`, and it is a real, reachable, user-visible defect: measured (probe `p4.tcl`), a user on the `ac` slot of a three-slot registry running a default-cycle `dutyCycle` over an RPN across the ac sweep column is moved off their analysis — `before: current=2 sim_type=ac` → `after: current=1 sim_type=tran`. It survives because EVERY path in WD11 has the user sitting on a `tran` slot, and in `wd_load3t`'s order (`op`, `ac`, `tran`) a hardcoded `tran` happens to land on index 2 — the same index AND the same type the row expects. This is the hardcoded-sweep-column sabotage that CLAUDE.md already records for this suite, arriving a second time at the restore: *"every row in the band drives the `tran` fixture where that name IS `time`."*

WHAT WOULD CATCH IT: one more row in WD11, driven from a three-slot registry whose slot 2 is NOT `tran`. A sibling loader to `wd_load3t` reading the fixture as `op`, `tran`, `ac` leaves the user on `ac` at slot 2; the default cycle is reachable there over an RPN of the ac database's own sweep column (measured: `[list frequency $w * sin()]` with `$w` derived from the `frequency` span for five periods, level 0.25, answers `ok 1` with a FOUR-point series — so it also gives the band a third series length). Legs: `wd_disp` = measured, `wd_destname` = named, `wd_curslot` = 2, **and `wd_slottype 2` = `ac`** — the type leg is the load-bearing half, since with that load order a hardcoded `tran` lands on index 1 and the index leg alone already moves, while with the EXISTING order neither leg moves. Cost: one `check`, taking the published count 101 → 102 on the counted arm, which this batch has twice ruled is a figure three instruments recompute and not a baseline.



## repair:j1


### survivors

- ATTACK 3, VARIANT C -- `catch {xschem raw switch [dict get $d prev] tran}`, the restore with the ANALYSIS TYPE WRITTEN DOWN instead of carried. This was the one SURVIVED verdict and it is now CLOSED by a new row in band WD11 of /home/analog/dev/xschem-claude/tests/headless/test_calc_wave_dest.tcl. Re-measured as a live producer against the EDITED suite: `1 FAILED (101 passed)` on test_calc_wave_dest and `ALL PASS (160 checks)` on test_calc_measure -- the single failure being the new row, printing `{measured named 1 ac tran 4 table registered}` against `{measured named 2 ac tran 4 table registered}`. No other row in either suite sees it, which is exactly why it survived.

- ATTACK 1, A_guard_only -- CAUGHT, and the attacker's apportionment is confirmed. The only PRE-EXISTING row that catches it is WD9's derived-caller PARTITION row, whose union floor prints `only:3`: `{{cross_scalar delay riseTime} {} {cross_scalar delay riseTime} only:3}`. Everything else that moves is new WD11 (now 9 rows, up from 8 -- my new row reddens on it too, on the registration legs) plus MT8's `named` leg (`{measured 0 NOKEY-db measured ok NOKEY-db}`). ⚠ I CONFIRMED THE ATTACKER'S WARNING BY RE-RUNNING IT: WD9's identity row and WD9's pairwise-chain row go FULLY GREEN under this sabotage, so TWO of the four `rows_moved` are not J1's fence at all. The honest count of J1's fence is 1 pre-existing row + 9 new rows + 1 leg of MT8.

- ATTACK 2, CONSTANT-Y -- CAUGHT, by three WD11 rows and five legs, re-measured on the edited suite: `3 FAILED (99 passed)`. The keystone's `wd_listcmp` leg (`{[1]off:{0.2999385393208259} rel=0.00012267928960900344}`) and its `wd_alldistinct` leg (`same` where `distinct` is expected); the long-series row, 19 elements all carrying the identical value `0.4121560065252599`; and the instrument row's fifth leg. test_calc_measure is ALL PASS, which is correct scoping -- MT8 reads no column. I ALSO CONFIRMED THE ATTACKER'S FINDING (b) AND FIXED IT: the instrument row's middle two legs build `lrepeat <n> <the DESTINATION's own element 0>`, so against a real constant fill the comparand IS the column and those legs do NOT move. Their old name claimed they fenced a constant fill. That is this tree's name-describes-coverage trap, so the row's NAME was corrected to say they are an instrument check and to name where the constant-fill fence actually lives (the distinctness leg above). Legs unchanged, count unchanged.

- ATTACK 3, VARIANTS A AND B -- CAUGHT by the existing `wd_load3t` restore pair. Re-measured: variant A (bare one-argument round-robin restore) `3 FAILED (99 passed)`, printing `0` where `2` is the user's slot; variant B (no mid-life restore, user parked ON the destination) `3 FAILED (99 passed)`, printing `3`. Both also redden my new row.

- B_swapped -- CAUGHT, re-measured on the edited suite: `3 FAILED (99 passed)`, both element-wise legs naming every offending element.


### rows_added

- ONE NEW CHECK, in band WD11 of /home/analog/dev/xschem-claude/tests/headless/test_calc_wave_dest.tcl, inserted after the existing two three-slot restore rows and before THE CONTROL (so WD10 still runs last). Name: "WD11 ...and the user's own slot is read back BY TYPE rather than written down, driven from a registry whose slot TWO is the `ac` read with a `tran` slot at index ONE for a hardcoded spelling to land on -- so this row and the one above forbid between them any restore that names an analysis type, because no single type is right in both orders and whichever one is written down, one of the two rows names the slot it landed on.  The request is built over the ac database's OWN frequency sweep, read back every run, because that is the column dutyCycle takes its X from there". EIGHT LEGS: `wd_disp`, `wd_destname`, `wd_curslot`, `wd_slottype 2`, `wd_slottype 1`, `wd_nslots`, `wd_slottype 3`, `wd_registered $gdb table`. Expectation `{measured named 2 ac tran 4 table registered}`. The `wd_slottype 1` = `tran` leg is the NON-VACUITY half: it asserts that a written-down `tran` has somewhere else to land, so the pairing cannot rot into two copies of the same claim.

- RED AGAINST THE UNMODIFIED PRODUCT, armed spelling, `src/` byte-identical to HEAD: `-> {refused NOKEY-db 2 ac tran 3 NOSLOT absent} (exp {measured named 2 ac tran 4 table registered}) : FAIL`. Five of the eight legs are red; three (`2 ac tran`) are green today and are the ones that say the fixture really is the discriminating one. Zero `UNEXPECTED ERROR:`, zero `BGERROR:`, zero `group ... ABORTED` -- the band keeps measuring, which is the issue-1616 trap the brief names.

- GREEN AGAINST A SIMULATED J1, two independent shapes, `src/` untouched (injected at suite file scope): the MINIMAL producer (hands `sweep`/`value` to `calc::wave_dest` and switches nothing, because `calc::wave_dest` already does its own mid-life restore by name AND type) gives `ALL PASS (102 checks)`, and the producer that ADDS the defensive point-count read-back and restores with `[dict get $d prev] [dict get $d prevtype]` also gives `ALL PASS (102 checks)`. So the row is not red on correct code of either shape.

- THE FENCE IS THE PAIR OF ORDERS AND NEITHER ROW ALONE -- MEASURED IN BOTH DIRECTIONS, which is the argument for the row rather than a preference. Hardcoding `tran`: existing `wd_load3t` row GREEN, new row RED (lands on slot 1). Hardcoding `ac`: new row GREEN, existing `wd_load3t` row RED (lands on slot 1, `{measured named 1 4 table tran op registered}`) plus its drop sibling and MT8. So whichever type a producer writes down, exactly one of the two rows names the slot it landed on, and no single-order fixture could have done it.

- TWO NEW SUITE HELPERS, both procs and not inline expressions. `wd_load3a` reads the fixture as `op`, `tran`, `ac` -- measured: leaves the user on the `ac` read at slot 2 with a `tran` slot at index 1. `wd_wspan {col n}` answers the angular frequency fitting `n` whole periods across a column's OWN span, so the row's request carries NO written-down frequency (the sweep endpoints are read back every run); it is a proc because the column is product-authored text and an `ERR:` sentinel inside a braced `expr` RAISES and would abandon the band through `group`'s catch -- a sentinel instead travels into the RPN, where the verb refuses it and the row says so.

- FOUR PROSE CORRECTIONS, no leg and no count moved by any of them. (1) The instrument row's NAME, per attack 2 finding (b). (2) Hole H5's "a destination built from an `ac` or `op` measurement is unfenced" gained its second exception, since the new row builds one from AC samples -- what is left of H5 is the `op` case, which has no sweep column and therefore no series to build one from. (3) The header's WD11 band summary now records that the restore is fenced by a pair of orders and by neither alone. (4) WD8's own comment said `v(sq)`'s two duty fractions "AGREE TO A RELATIVE 1.8e-15" -- at WD8's own level of 1/3 I measured them to be THE SAME DOUBLE, relative spread exactly 0.0, so the quoted figure understated the hole; the sentence now states the shape (identity) and notes 1.8e-15 is the figure at 0.5. That is the fourth quoted-rather-than-derived figure in this batch and the fifth now corrected.

- ⚠ I ALSO REMOVED TWO NUMBERS I HAD WRITTEN INTO MY OWN NEW BAND COMMENT (`ALL PASS (101 checks)` / `(160 checks)` for the surviving sabotage). They were already stale the moment the row landed -- the count is 102 now -- which is CLAUDE.md's rule demonstrating itself inside the comment written to record a sabotage. The comment quotes the SHAPE: `ALL PASS` on both suites with no row moving.

**wd8_decision**

SETTLED, AND IT WAS ALREADY FIXED IN THE WORKING TREE -- but I measured it rather than accepting the author's word, and the measurement is worth more than the fix. The task text was written against the shipped `v(sq)` row; the J1 author had already repointed WD8's end-to-end row at `v(lp)` with L = 0.5 and added four legs (`wd_alldistinct` on each read-back column, `wd_cmpword` of each column REVERSED). I drove all three fills through the REAL producer with the suite's own comparison procs LIFTED by a line scan out of the suite's text (so the instrument measured is the row's own, not a reimplementation of it). On `v(sq)` at L = 1/3 -- WD8's own level -- a correct fill, a y[0]-repeated fill and a REVERSED fill ALL answer `wd_listcmp = ok`: the row could not tell them apart, and its own added legs would have had to be written `same same` there, so they would have been blind too. On `v(lp)` at L = 0.5 as it now stands: correct answers `ok / distinct / distinct`; y[0]-repeated moves TWO legs (`[1]off:{0.2999385393208259} rel=0.00012267928960900344` and `alldistinct = same`); reversed moves TWO legs (both elements named, and `cmpword(reversed) = same`). Neither added leg catches both shapes alone -- reversing a constant list is still that constant, and a reversal's neighbours are still distinct -- so all three legs together are the fence, which is why I left all three. I did NOT move it to L = 1/3 even though the contract calls 1/3 the better level (1.83e-4 against 1.23e-4): the margin at 0.5 is already three orders outside the row's own 1e-7 tolerance, measured, and 0.5 is the level WD11's keystone drives, so the two rows now compare against the same derivation rather than two. The one thing I did change is the comment's figure (see rows_added, item 6). WD8 is green before and after and is not part of J1's red: it is a hole closure.

**counts_after**

RE-DERIVED, NEVER PRESERVED -- every figure below was run after my edits.

=== THE TWO SUITES J1 TOUCHES, counted arm ===
Command (identical for red and green):
  env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure

  RED, against the UNMODIFIED product (`git diff --stat -- src/` empty):
    FAIL | test_calc_wave_dest   RESULT: 12 FAILED (90 passed)    -> 102 checks
    FAIL | test_calc_measure     RESULT: 1 FAILED (159 passed)    -> 160 checks
    (12 = WD9 x3 moved + WD11 x9; 1 = MT8 moved.  exit 1)

  GREEN, against a SIMULATED J1 injected at suite file scope, src/ untouched:
    test_calc_wave_dest   OVERALL: ok (102 checks) / RESULT: ALL PASS (102 checks)
    test_calc_measure     OVERALL: ok (160 checks) / RESULT: ALL PASS (160 checks)
  Both the minimal producer and the read-back-with-correct-restore producer give the same figures.

PUBLISHED COUNTS THE IMPLEMENTER MUST RE-DERIVE:
  test_calc_wave_dest   90 -> 102   (+12: the author's eleven WD11 rows, plus mine)
  test_calc_measure    160 -> 160   (UNCHANGED: MT8's row was MOVED; WD8's row is still one `check`)

=== THE THREE COUNTED SUITES J1 DOES NOT TOUCH, after my edits, unmodified product ===
Command: env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_cross test_calc_engine test_calc_scratch_reuse
    PASS | test_calc_cross            ALL PASS (187 checks)
    PASS | test_calc_engine           ALL PASS (265 checks)
    PASS | test_calc_scratch_reuse    ALL PASS (54 checks)     RESULT: 3/3 runs passed

=== THE DISPLAY ARM: NOT RE-RUN, DECLARED, with the structural check that licenses it ===
My change is confined to ONE `hcases`-only suite's own text and adds no product proc, no catalogue
entry, no `-command` and no `calc::dest_*` name.  `/usr/bin/grep -ln 'tests/headless/test_'` over
test_calc_skeleton / test_calc_widgets / test_calc_buffer / test_calc_plot matches all four, and
every match inspected is a PROSE cross-reference -- none of the four reads another suite's text, so
none can see this edit.  The author's figures for those four (573 / 259 / 130 / 105) therefore stand
unmoved; that is reasoning plus a grep, not a measurement, and is stated as such.

=== THE T1 TRAILER -- DERIVED with summarize_all's own regexp arms and banner_rule.tcl's own
=== predicates over REAL captured output, before and after.  I did NOT run T1.
Both suites are ALREADY in `hcases` (verified in tests/run_regression.tcl), so the registration
delta is ZERO.  Census (lowercase ^skip: / uppercase ^SKIP:|^SKIPPED: / ^RESULT: / counted shapes /
banner_complete / banner_died):
  before test_calc_wave_dest (HEAD, 90 checks)   0 / 0 / 1 / 0 / 1 / 0
  before test_calc_measure   (HEAD, 160 checks)  0 / 0 / 1 / 0 / 1 / 0
  after  test_calc_wave_dest (102 checks)        0 / 0 / 1 / 0 / 1 / 0
  after  test_calc_measure   (160 checks)        0 / 0 / 1 / 0 / 1 / 0
THEREFORE cases +0, blocks +0, counted_failures +0, skips +0, and `wc -l` +0 -- `wc -l` moves with
the NUMBER of `RESULT:`/`skip:` lines, not with the counts inside them, and neither number moved.
This is the PLAN 5.4 shape again: a stage that moves a published check count and no trailer term.
The driver reads the trailer.


### still_open

- ⚠ TWO OF THE FOUR `rows_moved` ARE NOT J1'S FENCE, measured. WD9's identity row and WD9's pairwise-chain row both go FULLY GREEN under A_guard_only -- a three-line deletion that builds nothing. They are still right to be moved (they forbid a re-deferral and a per-caller split), but the ledger must not imply four rows of coverage. The honest apportionment is 1 pre-existing row (WD9's partition row, whose union floor prints `only:3`) + 9 new WD11 rows + 1 leg of MT8.

- ⚠ `WIRING_CONTRACT.md` §2 says `calc::wave_dest` is "built, gated at 90 checks". That figure goes stale the moment J1 lands (102). I did not edit it: it is the driver's document and §10's own policy is to keep superseded text as evidence. Named here rather than left to rot.

- ⚠ FOUR OF THE SIX `wd_curslot` LEGS IN WD11 ARE NOT RESTORE COVERAGE, and this is now written into the band comment so no future reader mistakes them. The keystone, the slot-count row, the no-drop row and the probe-gone row all read the current slot AFTER the band itself issues `xschem raw switch $::fixture tran`, a name-and-type switch that lands correctly whatever the producer did -- PROVED by variant B, where the user is left parked on the destination and the keystone's leg is still green. Those legs fence a LEAK; the restore is fenced by the two three-slot rows and by nothing else.

- PRE-EXISTING DEFECT, deliberately unfenced and needing its own unit: `calc::wave_dest_restore` puts back one half of a registry cursor that is a pair, so `xschem raw switch_back` after a successful destination lands ON THE DESTINATION. No row in WD11 or in the moved rows issues `switch_back` or reads `prev`/`prevtype`, and `prev`/`prevtype` are excluded from the answer's key set, so no row can reach it. A row asserting it would be RED ON CORRECT J1 CODE.

- HOLE H5's RESIDUE: a destination built from an `op` measurement is unfenced, and unbuildable -- the `op` read has no sweep column, so there is no series. The `ac` half of H5 is now closed by the new row.

- HOLE H11, UNRULED AND OWNED BY J1b: who frees a destination the user is looking at. WD11 asserts the slot SURVIVES a successful answer and that the band can drop it; it says nothing about whether the product should.

- HOLE H12, REAL AND UNFENCEABLE HERE: on a tree carrying J1 alone, a click on `dutyCycle` with the default cycle reaches `calc::fn_measure`, whose success arm is unconditionally `set num [calc::buf_set_number $v]` with no shape branch and no numeric check -- so the whole per-cycle LIST is pasted into the RPN buffer, violating R404 and R421 SILENTLY. Both procs return early on `calc::has_win .calc.buf`, so headless they are no-ops and nothing on the counted arm can observe it. J1b owns it and should follow J1 closely.

- NO VIEWER ARM: `wviewer::plot_sweeps_arm` still has zero callers, so J1 alone leaves the user with a registered two-column database and NO TRACE ON SCREEN. Nothing in these rows claims otherwise. This is also why row SR5's `$viaviewer == {plot_rpn}` one-name literal still holds (re-run: 54 checks).

- THE DESTINATION'S USER-VISIBLE NAME IS STILL UNRULED (`__calc_dest<N>` in the Results picker, `calcx`/`calcy` on the axis and in the legend). Every row reads the names OUT of the answer and matches `db` against a GLOB, never a literal, so nothing here pre-empts the ruling.

- THE `shape` KEY OF §4 IS NOT REQUIRED BY J1, and the key-set row is EXACT on purpose: when J1b adds `shape` that row reddens naming the new key and J1b widens it deliberately. A declared future red.

- THE LONG SERIES IS DERIVED ONCE, FROM THE COLUMNS (hole H10's cost), and the new `ac` row's request is likewise built from the database's own sweep endpoints -- so it says nothing new about the duty arithmetic, which WD8 owns. Both are honest about the hand-off.

- I DID NOT RUN A FULL T1, DID NOT COMMIT, DID NOT GATE, AND DID NOT TOUCH THE owed.sh LEDGER. `git diff --stat -- src/` is empty. The display arm was not run (see counts_after); the dev display was never started, stopped or viewed.

**ready_for_implementation**

YES. In order: (1) Implement the producer and NOTHING ELSE -- in `calc::dutyCycle_scalar`, forward any non-zero or non-finite `cycle` to `calc::dutyCycle` unchanged, and on the DEFAULT cycle call `calc::dutyCycle $rpn $level 0 $dataset $xaxis`, return its dict straight through if `ok` is 0 (so a refusal and an absence both stay exactly what they are, which is what the CONTROL row forbids merging a `db` key into), hand `sweep` and `value` to `calc::wave_dest` in THAT ORDER (X first -- swapping them reddens three rows naming every offending element), propagate a destination refusal through `calc::cross_refusal`, and merge EXACTLY `{db type xname yname n}` onto the measurement's own dict, leaving `dest` holding the retired `__calc_tmp` and NOT merging `prev`/`prevtype`. (2) Wire the WRAPPER and never `calc::dutyCycle` itself -- that is a measurement, not a reading: `mt_direct_raw wave_dest` answers `yes`, so an engine door inside `calc::dutyCycle` makes MT10's callee-ward closure print `{{} {} wave_dest}` against `{}`, while the wrapper is invisible to it because nothing in `dutyCycle`'s body names `dutyCycle_scalar`. (3) DO NOT ADD A DEFENSIVE POINT-COUNT READ-BACK IN THE WRAPPER -- `calc::wave_dest` already does its own mid-life restore by name AND type, and the minimal producer that switches nothing is green at 102/160. If you add one anyway, you MUST restore with `xschem raw switch [dict get $d prev] [dict get $d prevtype]`: a bare one-argument switch is round-robin and reddens three rows, no restore at all reddens three, and the type WRITTEN DOWN as `tran` reddens exactly one -- the new `ac` row, which exists because that shape was green on all eleven rows before it. (4) DO NOT DROP THE DESTINATION ON THE SUCCESS PATH; the drop belongs on the failure paths only, and the undropped slot is a declared leak J1b owns. (5) Run `env -u DISPLAY tests/headless/run_suites.sh --nogui test_calc_wave_dest test_calc_measure` and expect `ALL PASS (102 checks)` and `ALL PASS (160 checks)`; then the three untouched counted suites at 187/265/54. (6) Re-derive the two published check counts in the same commit -- 90 -> 102 and 160 -> 160 -- and update `WIRING_CONTRACT.md` §2's \"gated at 90 checks\". (7) Both suites are already in `hcases`, so no registration change and no trailer term moves; the driver gates and reads the trailer. (8) Say in the report that J1 alone puts NO TRACE ON SCREEN and that the click path still pastes the whole list into the RPN buffer (holes H12/H11), so the feature is not done until J1b lands. NOTHING IS RUNNING NOW.

