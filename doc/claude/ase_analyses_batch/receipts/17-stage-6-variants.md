# Stage 6 — the four variant mitigations, and a refusal turned back into a run

**One commit, issue 1434, and the sixth of Stage 6.** The first is **1429** (⚖ R3's
reader seam, `595ab274`); the second **1430** (the writer, the plot sidecar and
reconciliation, `7ea9f1dc`); the third the **1431** co-simulation golden note
(`b6b408fd`); the fourth **1432** (`noise`, `disto` and `sens`'s AC mode, `873ab265`);
the fifth **1433** (checkpointed salvage, `97974b42`). Stage 5 is **1426** (`tf`),
**1427** (`pz`), **1428** (`sens`, DC only). This is **6g**.

**Floors:** `test_ase_core` 523 → **558** · `test_ase_preflight` 218 → **229** —
**forty-six new rows**, and every other ASE suite byte-unmoved. Both are in
`tests/run_regression.tcl`, so **T1 covers every row this commit adds** and nothing
here is outside T1's reach.

⚠ **⚖ R3 IS STILL UNANSWERED and this issue does not touch it.** Nothing here reads a
number or moves a print line.

---

## THE 6g-1 RULING, WHICH IS THE POINT OF THE TASK

The brief asked for a choice between three named alternatives. **The answer is (c),
with two refinements neither the plan nor the brief anticipated**, and it rests on a
measurement that is new to this batch.

> **(c) §6g-1 genuinely needs the emission rule, because a precondition that refuses
> the run and an emitter that makes the run work are different user-visible behaviours,
> and the plan asks for the second.** Issue 1432's `vecsaves` is therefore **demoted
> from `fatal` to `caution`** rather than kept beside the new rule — once the leader is
> forced, a refusal on the same condition is a **false** refusal, and this tree's own
> rule is that a false refusal is worse than a missed one. It is not **deleted**,
> because it is the only thing that tells the user their narrowing was overridden, and
> *"nothing the deck contains may be unshowable in the window"* is a non-negotiable.

**Refinement 1 — the class is not the four verbs the plan names.** `pz` is in it and
`disto` is not, both measured, both against every document in this batch.

**Refinement 2 — 1433's `tran` hand-off is not a fifth type.** A save list that
resolves to **nothing** starves **every** analysis. It gets its own precondition,
`saves_resolve`, at `caution`, with `disto_saves`' `fatal` untouched.

### Why (a) and (b) are wrong, stated as the measurement that refutes them

**(a) "already satisfied by those preconditions"** — refuted by what the user gets.
Measured end to end below: with the precondition, an ordinary bench (one ticked output,
a `noise` row) is **refused, with nothing generated**. With the emission rule it
**runs**, three plots, rc 0, on both binaries. Those are not the same product.

**(b) "needs the `tran` case added"** — refuted twice. `tran`'s starvation is a
*different shape* from `noise`'s (it needs the list to resolve to nothing, not merely
to be narrow), and it is not `tran`'s: `op`, `dc` and `ac` are starved identically and
`pz` is starved at rc 0. Adding `tran` to `vecsaves` would have been wrong about the
trigger and wrong about the membership.

### THE MEASUREMENT THAT DECIDES IT, AND IT IS THE `pz` ROW

End to end through ASE-L's own `render_deck`, four states, scratch rundir under `/tmp`,
**both binaries, row-for-row identical on the two.** `6g-1` is the deck this tree now
renders; `_noleader` is the same deck with the one `.save all` line removed, which is
what ASE-L emitted before this commit for a bench 1432 would have refused outright:

```
opnoise  6g-1       rc=0  map=3  RUN-FAILED=0  Operating Point/Integrated Noise/Noise Spectral Density Curves
opnoise  _noleader  rc=1  map=1  RUN-FAILED=1  Operating Point           Error: no data saved for Noise analysis
optf     6g-1       rc=0  map=2  RUN-FAILED=0  Operating Point/Transfer Function
optf     _noleader  rc=1  map=1  RUN-FAILED=1  Operating Point           Error: no data saved for transfer function
opsens   6g-1       rc=0  map=2  RUN-FAILED=0  Operating Point/Sensitivity Analysis
opsens   _noleader  rc=1  map=1  RUN-FAILED=1  Operating Point           Error: no data saved for Sensitivity analysis
oppz     6g-1       rc=0  map=2  RUN-FAILED=0  Operating Point/Pole-Zero Analysis
oppz     _noleader  rc=0  map=2  RUN-FAILED=0  Operating Point/OPERATING POINT   <-- !!
```

⚠ **THE LAST LINE IS A WRONG ANSWER WEARING A RIGHT ANSWER'S LABEL.** Identical on the
fork and on apt 45.2, the `pz` deck without the leader produces:

```
ecell_ase.plotmap:   PLOT op 0 |Operating Point|
                     PLOT pz 1 |Operating Point|
ecell_ase.raw:       Plotname: Operating Point
                     Plotname: Operating Point
```

`pz` never ran; `$curplot` was still the operating point; the second `write` wrote the
**operating point again**, and the sidecar recorded it as the `pz` row's plot. rc **0**,
`$sim_status` **0**, no `RUN-FAILED`, no refusal, nothing on stdout but a line the user
would have to go looking for. Issue 1430's `ase::reconcile_plots` *would* call that
`mislabel` — the registry's `select` is `Pole-Zero Analysis` — which is that machinery
earning its keep, but nothing stops the run and nothing fails.

**That is the strongest argument in the task**, and it exists only because `pz` turned
out to be in the class that three documents say it is not.

---

## What shipped

### `src/ase.tcl` — the schema half (core `ase::`)

| proc | what it answers |
|---|---|
| `ase::analysis_resultvecs {sim type}` | `netlist` (default) or `own` — the adapter's key, read in one place |
| `ase::saves_narrowed {state}` | would this deck carry a narrowed save list |
| `ase::saves_widen_types {sim state}` | the enabled `own` types, in emit order, or `{}` |
| `ase::saves_all_forced {sim state}` | **the one body the emitter and the preconditions share** |
| `ase::saves_op_phantom_risk {sim state ?opcards?}` | 6g-3's condition: an op plot that would hold exactly one save |
| `ase::saves_op_cards_coming {state netlist}` | will the operating-point tier emit its own leader (C91) |
| `ase::raw_drop_phantom_all {vars}` | 6g-2, the free half |
| `ase::deck_case_lint {sim deck ?exempt?}` | 6g-4, over the `.control` block |
| `ase::saves_unresolved {sim state facts}` | class B's fact, one body for two tiers |
| `ase::analysis_schema_errors` | one new refusal, `badresultvecs` |
| the `vecsaves` precondition | `fatal` → **`caution`**, and it now reports the widening |
| the `saves_resolve` precondition | **new**, `caution`, on `op`/`dc`/`ac`/`tran` |
| the `disto_saves` precondition | `fatal`, unmoved, with one stand-down added |

### `src/ase.tcl` — the content half (`ase::backend::ngspice`)

* `resultvecs own` on the `noise`, `tf`, **`pz`** and `sens` entries.
* `saves_resolve` in `op`/`dc`/`ac`/`tran`'s `needs`; `vecsaves` added to `pz`'s.
* a new `deck_keywords` hook — the words **this emitter** writes, not ngspice's 134.
* `render_deck`'s `.save all` leader, with its three grounds spelled apart.

**`src/ase_window.tcl` is untouched.** No new state key, no `seed_enabled`,
`ase::state_default` still seeds exactly four rows, and the **104 committed `.state`
files are byte-identical** — section **CP** of `test_ase_core.tcl` is the row that
would notice.

⚠ **AND NO COMMITTED BENCH'S DECK CHANGES AT ALL**, which is stronger than byte
identity of the state files and is measured rather than hoped: `git ls-files | grep
'\.state$'` is **104**, and `grep -ho 'type [a-z]*'` over all of them is **104 `op` /
104 `dc` / 104 `ac` / 104 `tran` and nothing else**. Not one of them can enable an
`own` type, so 6g-1 cannot fire on any of them.

---

## Every measured fact this rests on

All **2026-09-12**, scratch decks under `/tmp/vm6probe`, **never a bench under
`sky130A/`** and nothing written under `~/.xschem/`. Binary 3 is
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary 1 is
`/usr/bin/ngspice` (`ngspice-45.2`). **Both were run for every measurement below, and
every one came back identical on the two unless the row says otherwise.**

### 1. TWO starvations wear the same error message, and only one of them is §6g-1's

One analysis per deck, `.save` dot cards above `.control` — `render_deck`'s own shape.

```
                      no save    .save v(mid)     .save v(nosuchnode)   .save all + .save v(nosuchnode)
op                    rc 0       rc 0             rc 1  ss=1            rc 0
dc  v1 0 1 0.25       rc 0       rc 0             rc 1  ss=1            rc 0
ac  dec 10 1k 100k    rc 0       rc 0             rc 1  ss=1            rc 0
tran 10n 1u           rc 0       rc 0             rc 1  ss=1            rc 0
disto dec 5 1k 10k    rc 0       rc 0             rc 139 SIGSEGV        rc 0
noise … dec 5         rc 0       rc 1  ss=1       rc 1                  rc 0
tf v(out) v1          rc 0       rc 1  ss=1       rc 1                  rc 0
sens v(out)           rc 0       rc 1  ss=1       rc 1                  rc 0
sens v(out) ac dec …  rc 0       rc 1  ss=1       rc 1                  rc 0
pz in 0 out 0 vol pz  rc 0       rc 0 ss=0 + `no data saved` + Plotname: constants   rc 0
```

**Class A** is the middle column: *any* narrowing starves it. **Class B** is the third:
only a list that resolves to nothing does, and then it starves everything. **The last
column is the mitigation, and it is one line.**

### 2. ⚠ `pz` IS STARVED, AND THREE DOCUMENTS SAY IT IS NOT

`APPENDIX` §7.5.2's table row writes *"(runs)"* with `$sim_status` 0; `PLAN.md`
§0.13.7 writes *"`pz` survives"*; `src/ase.tcl`'s own `vecsaves` comment, as issue 1432
shipped it, writes *"`pz` is the exception that proves it: its results are
`pole(n)`/`zero(n)`, and it survives a narrowed save"*. Measured three ways, both
binaries:

```
.save v(out) + pz in 0 out 0 vol pz   -> `no data saved for pole-zero analysis`, rc 0
.save v(mid) + pz in 0 mid 0 vol pz   -> the same          (the appendix's own deck)
.save v(mid) + pz in 0 out 0 vol pz   -> the same
```

⚠ **And it is the WORST member of the class, not a late addition to it**: `$sim_status`
is **0**, so the deck's guard never fires, `RUN-FAILED` never appears, and the run
continues into the next analysis. Every other member of the class is caught by
machinery that already exists.

### 3. ⚠ `disto` IS NOT IN THE CLASS, AND EVERY DOCUMENT SAYS IT IS

`PLAN.md` §6g-1's list is *"`disto`, `noise`, `tf`, dc `sens`"*; §0.13.7 and
`DECISIONS.md` D46 repeat it. Measured, the `disto` plot's own `Variables:` block:

```
no save      frequency v(in) v(mid) v(out) i(v1)     <- netlist names, every one
.save v(mid) frequency v(mid)                        <- rc 0, the narrowing HONOURED
.save all …  frequency v(in) v(mid) v(out) i(v1)
```

So a narrowed save does not starve `disto`; it *narrows* `disto`, correctly.
`disto`'s defect is class B, `disto_saves` already refuses it, and this commit changes
neither.

### 4. ⚠ `sens` IS STARVED IN BOTH MODES

`PLAN.md` §6g-1 and §0.13.7 both say *"dc `sens`"*. Measured: `sens v(out) ac dec 5 1k
10k` with `.save v(mid)` is rc 1 on both binaries, exactly as the DC mode is.

### 5. ⚠ THERE IS NO "FIFTH TYPE" — CLASS B IS UNIVERSAL

Issue 1433's fact 7b found `tran` starved by a list that resolves to nothing and handed
it on as *"a FIFTH type"*. Row 1 above is the whole answer: `op`, `dc`, `ac` and `tran`
behave identically, `pz` does it at rc 0, `disto` SIGSEGVs. It is not a type's property
at all — it is a property of the save list.

### 6. ⚠ THE PHANTOM COLUMN TAKES THE WRAPPER OF THE REAL SAVE

`PLAN.md` §6g-2 says *"a phantom raw column literally named `all`"*; `APPENDIX` §7.5.1's
table shows only `v(all)`. Measured on apt 45.2 (the fork writes none of these):

```
.save v(mid)        + op   ->  0 v(mid) voltage   1 v(all) voltage
                               both carrying 7.392094525460902e-01
.save i(v1)         + op   ->  0 i(v1) current    1 i(all) current      <- NEW
.save v(mid) v(out) + op   ->  clean
.save v(mid)        + tran ->  clean  (`time` is a second vector)
.save all + .save v(mid)   ->  clean, 4 real vectors
.SAVE V(MID)        + op   ->  the phantom is STILL THERE
```

A filter written to either document's letter misses `i(all)` entirely — and a single
ticked output on a bench with `.options savecurrents` off is exactly as likely to be a
current as a voltage.

### 7. ⚠ THE DOT-CARD REGION IS FOLDED ON EVERY BINARY; ONLY `.control` ARGUMENTS ARE NOT

`PLAN.md` §6g-4 says *"no rendered deck golden may contain a capitalised ngspice
keyword"* without saying where. Measured:

```
.SAVE V(MID) + op          identical to `.save v(mid)` on BOTH binaries, phantom included
WRITE <path> ALL           inside `.control`:  fork -> the file is written
                                               apt 45.2 -> NO FILE AT ALL, rc 0, and the
                                               only trace is `Warning from checkvalid:
                                               vector ALL is not available or has zero
                                               length.` on STDERR
```

So the command WORD is folded everywhere and the ARGUMENT is not — `APPENDIX` §7.5.1's
`keyword_case` probe seen from the emitter's side. A lint that flagged dot cards would
be flagging provably harmless text, and would fire on a **user's** own `.INCLUDE` in
their own netlist, which ASE-L did not write.

### 8. Issue 1432's OWN `disto_saves` FACTS, RE-MEASURED INDEPENDENTLY

Not because they were doubted — because `disto_saves` is the one `fatal` this task
leaves standing, and a crew that changes the code around a refusal should re-take the
measurement the refusal rests on. Both binaries, identical:

```
.save i(vnope)                        + disto  ->  rc 139 SIGSEGV
.save v(nosuchnode) / .save v(alsonone) + disto ->  rc 139 SIGSEGV
.save v(mid) / .save v(nosuchnode)    + disto  ->  rc 0
.save v(mid) + `save all` in the .control hatch + noise -> rc 0
```

---

## The deck, as it now renders

```
.temp 27
.save all                  <- 6g-1, when an enabled analysis declares `resultvecs own`
.save v(mid)               <- the user's ticks, kept, so the window still reaches the deck
.control
  …unchanged…
```

One line, above the per-output cards, at deck level — the same position and the same
literal `save_all_v` has used since issue 0964's guard G-LEADER, and the same one the
operating-point tier emits for its own reason. **Two `.save all` lines in one deck were
re-measured harmless** (the comment at G-LEADER already recorded it; confirmed again
here on both binaries).

---

## What the plan and the tree said that this refuted

The batch's eighty-first through eighty-eighth corrections (Stage 5 took C43–C55, issue
1429 C56–C59, 1430 C60–C64, 1432 C65–C71, 1433 C72–C80).

### C81 — §6g-1's four-verb list is wrong in three places at once

Facts 2, 3 and 4. `pz` is in, `disto` is out, `sens` is in twice over. The registry
therefore declares the property **per entry** (`resultvecs own`) rather than ASE-L
carrying a list of verbs, which is D34–D37 doing exactly the job it was written for:
the correction was a one-key edit in the adapter and no change at all in the schema.

### C82 — and `PLAN.md` §6g-1's own shape sentence is right, which is why the precondition had to move

The plan writes *"its shape is a refusal to narrow rather than a rewrite"*, and asks
for *"one test row per analysis type asserting the run survives a stale Outputs
entry"*. Against the tree as issue 1432 left it that row **could not be written**: the
run did not survive, it was refused. The two are not compatible shapes, and the plan's
is the one the user wants. Rows **WD5** and **PF230l** are the four rows the plan asked
for, and `vecsaves`' demotion is what makes them writable.

### C83 — `vecsaves`' stand-downs went from three to one, and the missed refusal went with them

Issue 1432 stood `vecsaves` down for `save_all_v`, for `save_op_params`, and for a
`save all` in issue 1419's verbatim hatch — each because the run was measured to survive
and refusing it would have been false. Its own comment named the `save_op_params` arm as
**a missed refusal**, because the operating-point tier emits its leader only when its
captured block is non-empty. With the leader emitted deterministically there is nothing
left to be false about, and nothing left to miss: the only bench with nothing to report
is one whose save list was never narrowed. **PF230m** is that row, rewritten.

### C84 — 1433's "`tran` is a FIFTH type" understates it by five

Fact 5. It is not a type's property; the whole save list resolving to nothing starves
every analysis, and the handed-on case is `disto_saves`' predicate with a different
verdict on the end. `ase::saves_unresolved` is the one body; `disto_saves` keeps `fatal`
and `saves_resolve` takes `caution`, because the fact rests on `ase::netlist_facts`
(`exact 0`) and a false **fatal** on `op` or `tran` would cost a user their ordinary
run over a hierarchical node inside an `.include`.

### C85 — and both tiers had to learn to stand down for the leader

Measured: `.save all` + `.save v(nosuchnode)` + `disto` is **rc 0** on both binaries.
Without the stand-down, a bench carrying a `noise` row beside a stale Outputs entry
would be refused, *fatally*, for a segfault 6g-1 has already prevented. Row **PF232e**
is the four-legged fixture; **PF232f** is its non-vacuity control, because the same
bench must still say *something* — the widening.

### C86 — `PLAN.md` §6g-2's "literally named `all`" misses half the defect

Fact 6. The phantom wears the wrapper of the save that produced it. The filter matches
`all` and `<wrapper>(all)`, case-insensitively, and **never** `allv`/`alli` — which the
plan is right to warn about, and which row **WD7** pins from both directions.

### C87 — §6g-4's lint has a measured scope, and it is the `.control` block

Fact 7.

### C88 — `set ase_preflight 0` turns off the REFUSAL and not the advice, and nothing had ever exercised that

The gate has carried the ruling in a comment since issue 1425 — *"`set ase_preflight 0`
turns off a REFUSAL; it is not a request to be told less about a circuit"* — and until
`saves_resolve` reached `op` there was no precondition on the gate's own TYPO fixture to
exercise it with. **PF216f found it**: the row asserted `[llength $::said] == 0` under
the escape, and a caution now legitimately fires. The row moved to assert the rule
rather than the absence of it, with **PF216f2** as its discriminator. The gate's own
sentence is the reason this is a repointing and not a special case: a crew inventing an
exception to a stated ruling is the failure this batch keeps writing down.

### C89 — §6g-2's OWN NAMED SEAM SWITCHES 6g-3 OFF, AND THE DECK GOLDENS ARE WHAT SAID SO

`PLAN.md` §6g-2 names `ase::cap_raw_plots` — *"the one Tcl proc in the tree that returns
a vector list"*. That is true, and it is exactly why it must not filter: **it is the
capability probe's own reader.** `ase::backend::ngspice::cap_leg_d` reads `probe_d.raw`
through it and hands the variable list to `cap_variant_verdicts`, which decides
`one_vector_write` by counting `v(*` entries. Drop the phantom there and the probe
answers **1 — no defect** — on exactly the binaries that have it, and the free half of
T17 silently disables the gated half.

**It was invisible until a sabotage took the filter back out.** With the filter in,
`test_ase_core`'s **D1, D5, C4 and C5** were green; the first cut of this task read that
as *"no golden moved, D47 holding a golden still"* and wrote a row saying so. Take the
filter out and the four redden — because 6g-3 then fires, correctly, against
`/usr/bin/ngspice` (45.2). The greenness was the bug.

The rule this is an instance of is already in this file, one proc away:
`ase::raw_content_verdict`'s header says a diagnosis that lied about what the file says
would be worse than a phantom. ⚠ **A reader whose answer feeds a MEASUREMENT may not be
improved.** The filter ships as `ase::raw_drop_phantom_all` applied at
`ase::cosim_db_inventory`; rows **WD7c**, **WD7d** and **WD7e** pin the reader's
faithfulness, the probe's dependence on it, and which body the call is actually in
(comments stripped first — `cap_raw_plots`' header *names* the filter in order to say it
is not applied, and the first cut of WD7e read that mention as a call).

### C90 — and the suite's isolation covers the registry, not `auto_execok`

`test_ase_core`'s ISO1377 block exists so that *"every expectation below that touches the
run command, **the save tier** or the case of a vector name"* is not an expectation about
the developer's machine. It isolates the **registry**; with no entry in force
`ase::sim_status` falls back to `[auto_execok ngspice]`, and a live capability **probe**
of whatever ngspice is on `$PATH` still runs.

Nothing in this file could see that before, because `ase::op_save_tier`'s answer reaches
the deck only through a **non-empty** captured op-cards block and the `nfet_clean`
fixture has none. **6g-3 reads a capability directly in `render_deck`**, so from this
issue on a deck golden taken without a stub says `.save all` on a machine whose ngspice
writes the phantom and does not on one whose ngspice does not — measured both ways on
this box. Row **ISO1434** declares the capability unmeasured for the whole suite, which
is also the honest description of a suite that registers no simulator; **WD6b** pins the
gate's three states by stubbing the same proc three ways, which is where a gate belongs
and where a golden is the wrong instrument.

### C91 — 6g-3 DOES move a real bench's deck, and `test_ase_final`'s F12 is what said so

`PLAN.md` §6g-3 is explicit that the leader *"fixes the **file**"*, so it is an
M-artifact and gated. What no document says is which of this tree's own benches it
reaches. **`test_nfet_final` — a committed `.state`, with one ticked output and `op`
enabled — is 6g-3's shape**, and the first cut gave its deck a **second** `.save all`
beside the operating-point tier's own leader. `test_ase_final`'s **F12** asserts
`^\.save all$` appears exactly ONCE (invariant I2/R2) and went red.

⚠ **The first cut had written the reasoning out and got it backwards.** Its comment said
`save_op_params` was *"deliberately not consulted"* because the tier's leader is
conditional on a non-empty captured block, and because two leaders are *measured
harmless* — which they are. **Harmless is not the same as invisible**, and an invariant
another suite has been holding since issue 0964 is not a thing to spend on a redundant
line.

The stand-down is not a patch on the symptom either: **the phantom exists only where the
op plot holds exactly ONE saved vector**, and a deck carrying device `.save @dev[param]`
cards puts many more into that same plot. `ase::saves_op_cards_coming` asks the tier's
own three conditions in one place; rows **WD6d** and **WD6e** pin the answer and the
fact that `render_deck` reads it. ⚠ And `test_ase_final` is **outside** the two suites
this task moves, which is why the whole ASE family was run rather than the two.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| `test_ase_core` | 523 → **558** | **558** | yes (`run_regression.tcl:75`) |
| `test_ase_preflight` | 218 → **229** | **229** | yes (`:29`) |
| `test_ase_simcaps_0948` | 199 → 199 | not run | yes (`:66`) |
| `test_ase_optier_0963` | 108 → 108 | not run | yes (`:67`) |
| `test_ase_cosim` | 341 → 341 | not run | ⚠ **no** — issue 1421's list |
| every other ASE suite (25) | unmoved | not run | — |

New sections: **WD** in `test_ase_core.tcl` (34 rows) and row **ISO1434**, **PF232**
in `test_ase_preflight.tcl` (10 rows), plus **PF216f2**. Both floor paragraphs raised
in the same change.

⚠ **`test_ase_preflight` NEEDS NO SUCH STUB, AND IT IS CHECKED RATHER THAN ASSUMED.**
Not one of its `deck_of` calls passes an `outs` list, so `ase::saves_narrowed` is 0 for
every deck it renders and 6g-3 cannot fire there whatever the developer's ngspice
answers. It is ALL PASS on this box with the probe live against a binary measured **0**,
which is the arm that would have caught it.

⚠ **NO DECK GOLDEN MOVED, AND THAT IS D47 RATHER THAN LUCK.** `test_ase_core`'s
`nfet_state` fixture saves **exactly one output** and enables **exactly `op`** — it *is*
6g-3's own shape. The leader is withheld because no suite probes a simulator and
`ase::caps_measured_as` answers false for a capability nobody measured, which is the
whole of D48's third predicate. Row **WD6c** asserts both halves so the next reader is
not left to infer it. ⚠ The sabotage that made `analysis_resultvecs` default to `own`
reddened **D1, D5, C4 and C5** — the goldens saying, in their own voice, that they are
the control for this.

### ⚠ FOUR EXISTING ROWS MOVED, EVERY ONE BECAUSE A REFUSAL BECAME A RUN

**PF230l** (`vecsaves` answers `caution`, `pz` joined, `disto` left), **PF230m** (three
stand-downs became one), **PF230n** (the sentence is about the widening), **PF216f**
(C88). Named per row in `test_ase_preflight.tcl`'s own floor paragraph.

---

## The sabotage table

**Fifty respellings of `src/ase.tcl`**, each a plausible rewrite rather than a
break — the tidy-up somebody would actually make. Restore was `cp` from
`/tmp/vm6probe/sab/good_ase.tcl` with an `md5` compare after **every** one, and the
campaign **aborts** on a restore mismatch rather than continuing; the log records
`RESTORED-OK` for all fifty, and for the three re-runs after them. **Fifty-three
applications in all, 53/53 restored, one survivor closed, one section kill.**

⚠ **The specs move through a JSON file, not through argv** — issue 1433's own campaign
lost all fifty-four of its first pass to a NUL separator that bash cannot carry, and
printed `PATCH-FAILED` fifty-four times rather than measuring nothing quietly. Anchor
uniqueness was checked against the pristine file **before** the campaign started: 50/50
unique, 0 bad.

⚠ **The campaign owned the working tree while it ran**; every measurement in this
receipt outside this table was taken before it started or after it finished.

⚠ **AND PASS 1's TABLE WAS THROWN AWAY, WHICH IS REPORTED RATHER THAN QUIETLY
RE-RUN.** Pass 1 ran forty-four of them against a tree in which the 6g-2 filter sat in
`ase::cap_raw_plots` — i.e. in which **6g-3 never fired at all** (C89). Every row of it
that mentions a deck golden, `WD6*` or the capability gate was therefore measuring a
configuration that is not the shipped one, so the whole table was re-taken rather than
patched. Pass 1's own findings are kept: the two survivors it produced (S30 and S31,
below) are what WD10 and WD10b exist for, and its S20/S22 rows are what found C89.

⚠ **AND THE DRIVER BROKE ITS OWN RULE ONCE, VISIBLY.** A source edit was made while a
campaign was live; `run.py`'s restore then overwrote it and the very next command
measured a tree that no longer held the change. The campaign was killed, the tree
restored from the pristine copy by `cp`, the edit re-applied, `good_ase.tcl` refreshed,
and the pass restarted from S01. It is recorded because a campaign that silently loses
an edit measures a tree nobody is looking at — the same class as issue 1433's
NUL-in-argv pass, one layer up.

### The fifty, by name

| # | the respelling | rows reddened |
|---|---|---|
| S01 | resultvecs defaults to `own` ("safer to widen than to starve") | core **D1** **D5** **C4** **C5** **WD1** **WD1b** **WD3** **WD3c** **WD4** **WD5b** **WD5d** **WD6** **WD6b** **WD6c** **WD6d** **WD10** · preflight **PF216f** **PF220b** **PF220c** **PF220d** **PF230g** **PF230h** **PF230i** **PF232a** **PF232b** **PF232e** |
| S02 | resultvecs accepts anything non-empty as `own` | core **WD9c** |
| S03 | saves_narrowed counts a blank expression as a save | core **WD2** |
| S04 | saves_narrowed ignores the Save-All blanket | core **WD2** **WD3b** · preflight **PF230a** **PF230d2** **PF230f** **PF230m** **PF230o** |
| S05 | saves_narrowed ignores the per-output Save tick | core **WD2** |
| S06 | saves_widen_types walks disabled rows too | core **WD3b** **WD10b** |
| S07 | saves_widen_types answers in state order, not emit order | core **WD3** |
| S08 | saves_widen_types goes back through ase::analysis_emit_order | core **E2b** **NO-RESULT** |
| S09 | saves_all_forced drops the users own Save-All arm | core **D5** **D5** **WD4** **WD5c** · preflight **PF230g** **PF232e** |
| S10 | saves_all_forced drops the 6g-1 arm | core **WD4** **WD5** **WD6** · preflight **PF232e** |
| S11 | the leader is emitted BELOW the per-output cards | core **D5** **WD5** **WD5c** **WD6b** |
| S12 | 6g-3 gate spelled `![ase::caps_is ...]`, the D48 inversion | core **D1** **D5** **C4** **C5** **C8** **WD5b** **WD6b** **WD6c** |
| S13 | the 6g-3 arm becomes unconditional (the gate deleted) | core **D1** **D5** **C4** **C5** **C8** **WD5b** **WD6b** **WD6c** |
| S14 | the two arms become one `if`, so 6g-1 is gated on the capability too | core **D5** **D5** **WD5** **WD5c** |
| S15 | phantom risk drops the `op` requirement | core **WD6** · preflight **PF220b** **PF220c** **PF220d** |
| S16 | phantom risk allows any number of saves | core **WD6** |
| S17 | phantom risk ignores a leader that is already forced | core **WD6** |
| S18 | the filter drops its "something must survive" clause | core **WD7b** |
| S19 | the filter also eats ASE-Ls own Save-All tokens | core **WD7** |
| S20 | the filter matches only the bare token, as PLAN.md 6g-2 words it | core **WD7** **WD7d** |
| S21 | the filter matches only `v(all)`, as APPENDIX 7.5.1 shows it | core **WD7** |
| S22 | cap_raw_plots hands back an empty list for a filtered plot | core **WD7c** **WD7d** **WD7e** |
| S23 | the lint falls back to ngspice keywords for an unknown backend | core **WD8f** |
| S24 | the lint runs over the whole deck, not only `.control` | core **WD8c** |
| S25 | the lint checks only the first token of a line | core **WD8b** **WD8e** |
| S26 | the lint ignores the callers exempt list | core **WD8e** |
| S27 | a capitalised `.CONTROL` / `.ENDC` is folded away unreported | core **WD8d** |
| S28 | `deck_keywords` loses the one word that is an ARGUMENT | core **WD8b** **WD8e** |
| S29 | vecsaves goes back to refusing the run | core **WD5** **WD10** · preflight **PF230l** **PF230m** |
| S30 | vecsaves fires for every type, not only the `own` ones | core **WD10** |
| S31 | vecsaves asks saves_narrowed instead of the shared body | core **WD10b** |
| S32 | saves_resolve becomes a refusal, ignoring netlist_facts blind spot | preflight **PF216b** **PF216c** **PF216d** **PF216e** **PF216f** **PF216g** **PF217c** **PF221i** **PF221v** **PF220c** **PF220d** **PF232b** |
| S33 | saves_resolve stops standing down for a forced leader | preflight **PF232e** |
| S34 | disto_saves stops standing down for a forced leader | preflight **PF230g** **PF232e** |
| S35 | disto_saves is demoted to a caution like its sibling | core **WD5d** · preflight **PF230g** **PF230i** **PF232b** **PF232e** |
| S36 | the shared reader counts an undecomposable expression as UNresolved | preflight **PF232h** |
| S37 | the shared reader demands that EVERY save resolve | preflight **PF230g** |
| S38 | the shared reader answers about an empty state instead of standing down | preflight **PF232i** |
| S39 | the badresultvecs refusal is deleted | core **WD9** |
| S40 | pz loses its `resultvecs own` -- the claim three documents make | core **WD1** **WD5** · preflight **PF230l** |
| S41 | disto gains `resultvecs own` -- the claim every document makes | core **WD1** **WD3** **WD5b** **WD5d** · preflight **PF230g** **PF230h** **PF230i** **PF232b** **PF232e** |
| S42 | sens loses `vecsaves` from its needs | preflight **PF230l** |
| S43 | op loses `saves_resolve` from its needs | preflight **PF216f** **PF232a** **PF232b** |
| S44 | tran loses `saves_resolve` -- the case 1433 handed on | preflight **PF232a** **PF232b** |
| S45 | cap_raw_plots filters after all, as PLAN.md 6g-2 asks | core **WD7c** **WD7d** **WD7e** |
| S46 | cosim_db_inventory stops filtering | core **WD7e** |
| S47 | vecsaves drops its resultvecs guard (the wrong-row sentence) | core **WD10** |
| S48 | 6g-3 ignores the operating-point tiers own cards (F12s second leader) | core **WD6d** |
| S49 | saves_op_cards_coming ignores the captured block and answers on the tick | core **WD6b** |
| S50 | saves_op_cards_coming ignores whether an operating point is enabled | **NOTHING** *(survivor)* |

### The three re-runs, after the fix S48 bought

`test_ase_final`'s F12 (C91) sent three of them back, so they were re-specified against
the corrected code and re-run with an `r` suffix — and **WD6d had to be given a primed
op-cards cache before S50r could redden it**, because with an empty block all three of
`saves_op_cards_coming`'s conditions answer 0 for the same reason. *A row whose fixtures
never disagree cannot fail*, for the seventh time in this batch.

| # | the respelling | rows reddened |
|---|---|---|
| S48r | 6g-3 ignores the operating-point tiers own cards (F12s second leader) | core **WD6d** **WD6d2** |
| S49r | saves_op_cards_coming ignores the captured block and answers on the tick | core **WD6b** **WD6d** |
| S50r | saves_op_cards_coming ignores whether an operating point is enabled | core **WD6d** |

### The one that survived, and the one that killed a section

**S50 — `saves_op_cards_coming` ignoring whether an operating point is enabled — survived
its first run**, and the reason was the fixture rather than the guard: with an EMPTY
op-cards block every leg of WD6d answers 0 because there are no cards at all, so the row
could not tell the three conditions apart. `ase::op_cards_put` primes the cache for the
row and hands it back empty immediately afterwards (the C section's fixtures own it);
**S50r** then reddens **WD6d**. ⚠ Nothing was deleted here — unlike issue 1432's S32 and
1433's S12r, this line is genuinely reachable in production (a bench with `op` off and
cards cached from an earlier netlist), so it earned a fixture rather than a deletion.

**S08 — `saves_widen_types` going back through `ase::analysis_emit_order` — killed the
suite**, at row **E2b**, with **no RESULT line at all**. That is the strongest possible
statement of what `WD3c` is about: `analysis_emit_order` RAISES for an unrenderable type,
`saves_widen_types` is read by a PRECONDITION, and a raise there travels out through
`ase::analysis_precheck` and `render_deck` and takes the file with it. ⚠ It is reported
as a section kill rather than counted as a clean red, because the abort happens in
section E — long before WD runs — so **WD3c never got the chance to fail**. The row is
still the right one for the property; S08 says the property matters more than the row
can.


---

## What I did NOT ship, and why

* **A `.save all` leader for class B.** It would rescue `op`/`dc`/`ac`/`tran` and
  `disto` too — measured — and it was refused, because the condition rests on
  `ase::netlist_facts` (`exact 0`) and silently saving everything to paper over what is
  usually a **typo** teaches the user nothing. A `caution` that names the typo and lets
  the run proceed to its honest rc-1 failure is the better trade, and `disto`'s
  `fatal` stays because a SIGSEGV leaves no log to read.
* **`disto_saves` demoted.** It is the one case where the simulator dies with no exit
  status, no log and no results file. It keeps `fatal`, keeps its sentence, and gains
  exactly one stand-down (C85).
* **The 6g-2 filter at `ase::cap_raw_plots`.** It is one of the two seams `PLAN.md`
  §6g-2 names and it is measurably the wrong one — see C89. The filter ships as
  `ase::raw_drop_phantom_all` applied at `ase::cosim_db_inventory`, and `cap_raw_plots`
  carries a header saying why it does not filter, so the next reader who reaches for the
  plan's sentence is told before they write it.
* **The 6g-2 filter in `src/wave_viewer.tcl`.** That is §6g-2's *other* named seam —
  *"the `xschem raw list` consumer behind the Outputs/trace surface"* — and it is
  `signal_list`, in **a file Stage 6's own *Files and procs* table does not name**. It
  is one call, in whichever stage owns that file, and it is named here rather than
  silently skipped: **that is where the substantial user-visible half of 6g-2 still
  is.**
* **A runtime consumer for the 6g-4 lint.** `PLAN.md` classes it M-free because *"it is
  an assertion about goldens, not about a binary"*. A lint that refused a run would be a
  refusal built on token-equality against a user's own node names; a suite that runs it
  over every rendered fixture costs a user nothing.
* **A `keyword_case`-gated warning about the user's verbatim hatch.** That is
  `APPENDIX` §7.5.1's V2 row and it belongs to the pass-through linter, which is Stage
  7's surface.
* **`seed_enabled`, anywhere.** Four seeded rows, 104 byte-identical `.state` files,
  section CP unmoved. Six commits in a row now shipping ⚖ R4's recommended answer by
  construction.
* **Anything in `src/ase_window.tcl`.** The consequence is named rather than hidden:
  **the widening has no surface of its own.** It reaches the user through the
  four-state grid's `caution` and `preflight_gate`'s advice block, which is where every
  other precondition sentence in this file already lands; what it does not do is grey
  the Save ticks or mark them overridden while an `own` analysis is enabled. That is a
  one-row follow-up for the next window stage, and it is the same shape as issue 1432's
  own `depends`-has-no-surface note.
* **Any change to `render_deck`'s print anchor, its `$sim_status` guard, its
  `remzerovec` placement, the plotmap record or the checkpoint block.** Rows **WK7**,
  **CK15**, **CK21** and **PF231e/f** assert every one of them is still where issues
  1243, 0964, 0929, 0963, 1430 and 1433 put them, and they are green.

---

## What this stage learned that binds later ones

**A PRECONDITION THAT REFUSES AND AN EMITTER THAT REPAIRS ARE DIFFERENT PRODUCTS, AND
THE DIFFERENCE IS INVISIBLE IN A TEST SUITE.** Issue 1432's `vecsaves` was correct,
measured, sabotage-verified and green — and what it shipped was *"ASE-L will not run
your bench"* where one deck line would have made the bench run. ⚠ **When a precondition
is written, ask what the emitter could do instead**, because the suite cannot tell the
two apart: both are "the user does not get a wrong answer".

**A GUARD'S STAND-DOWN LIST IS A MAP OF WHAT THE EMITTER SHOULD HAVE DONE.** `vecsaves`
already stood down three ways, and every one of them was *"…because something else
emitted the leader"*. The fix was sitting inside the refusal, written out, for a whole
commit. ⚠ **Read a precondition's exemptions as a specification for the emitter.**

**AND WHEN A DOCUMENT SAYS A THING SURVIVES, THAT IS THE ONE TO MEASURE.** `pz` was
recorded as *"the exception that proves the rule"* in three places, in the same
sentence, from one measurement. The exception is what makes a rule feel finished, so it
is the claim nobody re-takes — and here it was both wrong and the worst case in the set.
⚠ **Measure the exception before the rule.** This is issue 1430's C60 (*"measure the
table"*) and 1432's C65 (*"measure the predicate"*) arriving at the **counter-example**,
which is the one a reader trusts most.

**A READER WHOSE ANSWER FEEDS A MEASUREMENT MAY NOT BE IMPROVED, AND THE IMPROVEMENT
LOOKS EXACTLY LIKE THE FIX.** `PLAN.md` §6g-2 names the right proc for the right reason
— it is the one that returns a vector list — and filtering there switches 6g-3 off,
because the same proc is the capability probe's own reader. ⚠ **Before adding a filter
to a reader, list its CALLERS and ask which of them is measuring something.** The tell
was already in the file one proc away: `ase::raw_content_verdict` carries the same rule
in its own header.

**AND THE GREEN SUITE WAS THE BUG.** The first cut wrote a row saying *"no deck golden
moved — that is D47 holding a golden still rather than luck"*, and it was neither: the
goldens were still because the emitter was broken. ⚠ **A row that explains why nothing
moved is a row to sabotage FIRST**, because the only evidence it has is an absence.

**AND A SUITE'S "ISOLATION" IS ONLY THE LEAKS SOMEBODY THOUGHT OF.** ISO1377 isolates
the registry so that no expectation is really about the developer's machine, and it says
so in as many words — and with no entry registered the fallback is `auto_execok`, so a
live probe of whatever ngspice is on `$PATH` ran anyway. It had never mattered, because
no measured capability reached the deck. ⚠ **When a new value reaches an asserted
artifact, re-derive what that artifact still depends on**; an isolation written for
yesterday's dependencies is not a property.

**A FIX THAT ONLY MOVES AN ERROR CODE IS NOT FINISHED.** Class A starves four types;
three of them fail loudly and one fails at rc 0 with the previous analysis's plot
written under its name. A crew that had stopped at *"`$sim_status` catches it"* — which
`APPENDIX` §7.5.2 says in as many words, and which is true for three of the four —
would have shipped the fourth. ⚠ **Check the quiet member of every set.**

---

## Rulings

⚖ **R9 — two new user-facing sentences, and no new surface.** Both reach the user
through the existing precondition channel — the four-state grid cell and
`preflight_gate`'s advice block — so **nothing new is drawn and no `look` debt is
filed.**

1. **the widening (`vecsaves`, `caution`)** — *"a `<type>` analysis answers in vectors
   that are not netlist names, so it cannot run under a save list made of them — this
   run saves everything, and the N per-output Save tick(s) on this bench will not narrow
   it."* Fix: *"tick Save all voltages to say so explicitly, or switch the `<type>`
   analysis off to keep the narrowed save list."*
2. **the unresolvable save list (`saves_resolve`, `caution`)** — *"every saved output
   names something this circuit does not have, and ngspice will not run the `<type>`
   analysis at all under a save list that resolves to nothing — the run fails with `no
   data saved`."* Fix: *"correct the output names, or tick Save all voltages."*

⚠ **One of those REPLACES a refusal rather than adding a sentence**, which is the part
worth the user's eye: what the same bench got before this commit was *"the `noise`
analysis cannot run: this bench saves 1 named output and nothing else … Nothing was
generated: no deck, no raw, no log."* The bench now runs.

⚠ **And one of them is newly audible under `set ase_preflight 0`** (C88). That is the
gate's own stated ruling holding, but it is a change in what a user who set that lever
hears, so it is named here rather than left in a test row.

Recorded as `owed.sh add rule 1434` at the moment it was incurred, pointing at the issue
file. ⚠ Its blurb was **corrected once**, in place, because the first one said *"four new
sentences"* from an earlier draft and the ruling is two; the ledger was backed up again
before that write and `cleared.log` holds the pre-image. **Batch with 1426, 1427, 1428, 1429, 1430, 1432 and 1433, which are all still
waiting**, per ⚖ R9 and the standing one-question-at-a-time preference.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/vm6probe/owed_backup_20260912_223612` (**152 rule / 56 look / 9
suite** at the time). The new entry is stamped `repo:/home/analog/dev/xschem-claude`.

⚠ **AND THE FOUR UNSTAMPED ENTRIES ARE STILL THERE, UNTOUCHED.** Measured 2026-09-12
22:36, before the `add`:

```
/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*
  ->  rule/1357   rule/1357@xschem-claude
      look/hier_pdf_nav_1357_H6.1789071932.2875683
      suite/test_hier_pdf_links_1333

/usr/bin/grep -h '^repo:' … | sort | uniq -c   ->  200 xschem-claude / 13 op-wcard
```

Identical in kind to what issues 1430, 1432 and 1433 found. **Nothing has cleared them
and nothing has claimed them**, and a rule debt clears only when the user says so. The
two `rule/1357` entries still point at two different issue files — issue **1400**'s
collision, standing in the ledger itself. ⚠ The op-wcard count has moved **13 → 13 → 13
→ 13** across four receipts while this clone's moved **197 → 199 → 200**.

**No `look` debt.** `src/ase_window.tcl` is untouched and nothing new is drawn.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* **Nothing was committed, added, stashed, restored or cleaned.** No `git checkout --`,
  no `git restore`, no `git stash`, no `git clean`, no `git push`.
* `NUMBERING.md`'s pointer was advanced **1434 → 1435** in the same change as the entry.
  Both mint checks were run at the moment of minting: the reserved-band scan over this
  clone's head table (**silent** for 1434) and `ls ~/dev/*/doc/claude/issues/1434-*`
  plus `/usr/bin/grep -lw 1434` across every clone's `NUMBERING.md` (only this clone's
  own pointer line).
* ✅ **Both suites this task moves ARE in `tests/run_regression.tcl`.** Nothing here is
  outside T1's reach; issue 1421's twenty-one unreachable `test_ase_*` suites are all
  unmoved.
* **Both binaries were exercised end to end**, through ASE-L's own `render_deck`, in a
  scratch directory under `/tmp` with an explicit `rundir`: the fork
  (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+`) and
  `/usr/bin/ngspice` (`ngspice-45.2`). **Nothing under `~/.xschem/` was touched and no
  bench under `sky130A/` was run**; every xschem invocation was given a path
  (`./src/xschem`) and `--nolog`, never `--logdir`, never a bare `xschem`.
* ⚠ **THE WHOLE ASE FAMILY (30 suites) WAS RUN HEADLESS, TWICE**, every run `timeout
  500`-bounded so a stall would be a NAMED outcome: **27 ALL PASS, 2 self-skips**
  (`test_ase_dirty`, `test_ase_log_seam_0207`, each of which says in its own first line
  that it needs an X connection) and **1 known red** —
  `test_cosim_golden_e2e` **45 passed / 1 failed**, row **GE24**, issue **1431**,
  unchanged and not in T1. `test_ase_window` is **ALL PASS (56)**.
  ⚠ **The first of the two is why `test_ase_final` is in this receipt at all** — it went
  **1 FAILED (81)** on row F12 with the first cut of 6g-3 (C91), and it is outside the
  two suites this task moves. Running the family rather than the pair is what caught it.
* ⚠ **`test_ase_optier_0963` RED ONCE AND PASSED STANDALONE, AND BOTH ARE REPORTED.** It
  answered **2 FAILED (106)** in one back-to-back sequential batch, immediately after
  `test_ase_final`'s real bandgap simulation, and **ALL PASS (108)** standalone
  afterwards and in both family runs. That is issue **1402**'s filed flap — the bandgap
  bench not converging reproducibly under load — and the brief's own instruction was to
  re-run standalone before believing it, which is what the second number is.
* ⚠ **THE DISPLAY ARM: `2/2 runs passed`, AND THE COUNTS ARE IDENTICAL TO HEADLESS.**
  Taken through `tests/headless/run_suites.sh` with `SUITE_TIMEOUT=400` and
  `AUDIT_SCREEN=1920x1080x24`, which reported *"display arm: ATTACHED to persistent dev
  display :99 (devdisplay.sh), GUI_GATE=0"* — `devdisplay.sh status` before the run:
  alive, **openbox (Openbox 3.6.1)**, `1920x1080x24`.

  | suite | headless | display (`:99`) |
  |---|---|---|
  | `test_ase_core` | **558** | **558** |
  | `test_ase_preflight` | **229** | **229** |

  ⚠ **AND IT WROTE `~/.xschem/geometry` AGAIN, at 23:22:57.** Issue **1397**, already on
  the user's queue and already reported by the 1430, 1432 and 1433 crews. Every one of
  this crew's own invocations honoured the rule — `--nogui --pipe -q --nolog`, a path to
  the binary, a scratch `rundir` under `/tmp`, no bench under `sky130A/` — but
  `run_suites.sh`'s display arm launches xschem **without** `--nogui`, so a real window
  opens and saves its size on exit. ⚠ **This task's subject is deck TEXT and pure-Tcl
  procs, none of which has an X dependency**, so the display arm added no information
  here; it was taken because the reporting duty asks for both arms.
