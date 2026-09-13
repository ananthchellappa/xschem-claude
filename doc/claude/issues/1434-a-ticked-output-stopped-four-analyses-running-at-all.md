# 1434 — a ticked output stopped four analyses running at all, and one of them said nothing

**Stage 6g of `doc/claude/ase_analyses_batch/`**, the sixth commit of Stage 6 and the
last before Stage 7: **1429** is ⚖ R3's reader seam, **1430** the writer and the plot
sidecar, **1431** the co-simulation golden note, **1432** the three multi-plot types,
**1433** checkpointed salvage. This is the four variant mitigations of `PLAN.md` §6g,
`DECISIONS.md` **D46**/**D47**/**D48**, `APPENDIX` §7.5.1/§7.5.2.

## The defect

ASE-L emits one `.save <expr>` card per ticked row of the Outputs pane. Measured on
the fork (`build-ver_50`, `ngspice-46+`) and on `/usr/bin/ngspice` (`ngspice-45.2`),
identically, through `render_deck`'s own shape — `.save` dot cards above `.control`:

```
.save v(mid) + noise / tf / sens(dc) / sens(ac)
     -> rc 1, $sim_status 1, `Error: no data saved for <X> analysis; analysis not run`
.save v(mid) + pz
     -> THE SAME MESSAGE AT rc 0 AND $sim_status 0
.save v(mid) + op / dc / ac / tran / disto            -> rc 0
```

**One ticked output is enough**, and one ticked output is the shape of every committed
bench in this repository. Four of the eleven analysis types therefore could not run at
all on an ordinary bench — and for `pz` the failure is silent end to end: rc 0,
`$sim_status` 0, the deck's own guard never fires, `RUN-FAILED` never appears, and what
reaches the user depends on what ran *before* it. On a bare `pz` deck the results file
holds `Plotname: constants` — ngspice's built-in constants plot, still current because
nothing else set one. **On an ordinary bench, where an `op` row precedes it, the results
file holds `Plotname: Operating Point` TWICE, and the sidecar records the second as the
`pz` row's plot.** That second shape is the dangerous one and it is the one a user
actually gets: `constants` announces itself as junk, whereas a duplicated operating
point wears a label a reader trusts. (Driver-verified independently 2026-09-12 on both
binaries, from raw decks with no ASE-L in the path: `op` then `pz` under `.save v(mid)`
→ rc 0, `$sim_status` 0, and the second `write` emits the operating point again.)

Issue **1432** shipped the first half of this as a **`fatal` precondition** — the run
was **refused**, and the user was told to go and tick *Save all voltages* themselves.
That is the defect this issue is really about: **ASE-L can emit one deck line and the
run works.** A refusal where the emitter can make the run correct is a false refusal,
and this file's own rule is that a false refusal is worse than a missed one.

## What shipped

**One deck line, with three different grounds for emitting it**, and the grounds are not
interchangeable:

| | why | gate |
|---|---|---|
| the user's own Save-All tick | they asked | none |
| **6g-1** | an enabled analysis's result vectors are not netlist names, so without the leader it **does not run at all** | **none** — D46's named exception: a correctness precondition is applied unconditionally even though it is M-artifact |
| **6g-3** | the phantom duplicate column apt 45.2 and stock 47 write beside a lone op save | `ase::caps_measured_as $caps one_vector_write 0` (D48) |

**Core (`ase::`, schema):** `analysis_resultvecs`, `saves_narrowed`,
`saves_widen_types`, `saves_all_forced`, `saves_op_phantom_risk`,
`saves_op_cards_coming`, `raw_drop_phantom_all`, `deck_case_lint`,
`saves_unresolved`; a `badresultvecs` refusal in `analysis_schema_errors`; the
`vecsaves` precondition rewritten from `fatal` to `caution`; a new `saves_resolve`
precondition. **Adapter
(`ase::backend::ngspice`, content):** a `resultvecs own` key on the `noise`, `tf`, `pz`
and `sens` entries, a `deck_keywords` hook, and the leader in `render_deck`.

**`src/ase_window.tcl` is untouched.** No new state key, no `seed_enabled`,
`ase::state_default` still seeds exactly four rows, and the 104 committed `.state`
files are byte-identical.

## Five measured refutations, and three documents say the same wrong thing

All 2026-09-12, on both binaries, identical on the two unless stated.

**1. `pz` IS starved, and three documents say it is not.** `APPENDIX` §7.5.2's table
row (*"(runs)"*), `PLAN.md` §0.13.7 (*"`pz` survives"*) and `src/ase.tcl`'s own
`vecsaves` comment as 1432 shipped it (*"`pz` is the exception that proves it"*).
Measured with the save naming the pz output node, naming another node, and on the
appendix's own two-node deck — starved every time, on both binaries. And it is the
**worst** member, because it is the only one whose starvation is invisible to
`$sim_status`.

**2. `disto` IS NOT in that class, and every document says it is.** A `disto` plot's own
`Variables:` block is `frequency v(in) v(mid) v(out) i(v1)` — netlist names, every one —
and `.save v(mid)` + `disto` is rc 0 on both binaries. What starves `disto` is the other
shape, below, and `disto_saves` already refuses it correctly.

**3. `sens` is starved in BOTH modes**, not in `dc` alone as §6g-1 and §0.13.7 say.

**4. There is no "fifth type": a save list that resolves to NOTHING starves EVERY
type.** Issue 1433 found `tran` starved that way and handed it on as a fifth type.
Measured with `.save v(nosuchnode)` as the only save card: `op` rc 1, `dc` rc 1, `ac`
rc 1, `tran` rc 1, `pz` the message at rc 0, `disto` rc 139 — and all six at rc 0 with
`.save v(mid)` instead. It is universal, and `disto` is the only one that may not be
allowed to reach the simulator.

**5. The phantom column takes the WRAPPER of the real save, and no document in this
batch has that.** `PLAN.md` §6g-2 says *"a phantom raw column literally named `all`"*
and `APPENDIX` §7.5.1's table shows only `v(all)`. Measured on apt 45.2:

```
.save v(mid) + op   ->  0 v(mid) voltage  AND  1 v(all) voltage
                        both carrying 7.392094525460902e-01
.save i(v1)  + op   ->  0 i(v1) current   AND  1 i(all) current
.save v(mid) v(out) ->  clean          tran, one save  ->  clean
.save all + .save v(mid) -> clean, 4 real vectors
```

A filter written to either document's letter misses `i(all)` entirely.

## And the mitigation was already in this file, pointing the wrong way

Guard **G-LEADER** (issue 0964) — the deck-level `.save all` the operating-point tier
emits for its own reason. Measured: a leader above the narrowed cards makes **every**
starved deck above run at rc 0, `disto`'s SIGSEGV included. Issue 1432's `vecsaves`
already *stood down* for a bench that happened to get one, and its own comment named the
`save_op_params` arm as **a missed refusal**, because the op tier emits its leader only
when its captured block is non-empty. 6g-1 is that stand-down turned the right way up:
instead of refusing a run because the leader is missing, **emit the leader** — and the
missed refusal goes with it.

## What the user is told, and it is a new sentence

The widening is a change to the user's results file that the user did not ask for, so
`vecsaves` survives as the thing that **says so** — a `caution` in the four-state grid
and in `preflight_gate`'s advice block, never a door. Without it the deck would contain
something the window cannot show, which this batch's own non-negotiable forbids. The
sentence, and `saves_resolve`'s, are ⚖ **R9** rulings and are on the user's queue.

## ⚠ AND 6g-2, APPLIED WHERE THE PLAN SAYS, SWITCHES 6g-3 OFF

`PLAN.md` §6g-2 names `ase::cap_raw_plots` as one of its two seams — *"the one Tcl proc
in the tree that returns a vector list"* — which is true, and is exactly why it may not
filter: **it is the capability probe's own reader.**
`ase::backend::ngspice::cap_leg_d` reads `probe_d.raw` through it and hands the variable
list to `cap_variant_verdicts`, which decides `one_vector_write` by counting `v(*`
entries. Drop the phantom there and the probe answers **1 (no defect)** on exactly the
binaries that have it.

**Found by sabotage, in the deck goldens' own voice.** With the filter in
`cap_raw_plots`, `test_ase_core`'s **D1, D5, C4 and C5** were green because 6g-3 never
fired; take the filter out and they redden, because it does. A reader whose answer feeds
a measurement may not be improved — the rule `ase::raw_content_verdict` already carries.

The filter therefore ships as `ase::raw_drop_phantom_all` applied at
`ase::cosim_db_inventory`, this file's own `xschem raw list` consumer. **6g-2's
substantial seam is `signal_list` in `src/wave_viewer.tcl`**, which Stage 6's *Files and
procs* table does not name; it is named here rather than silently skipped.

## And the same sabotage found a leak in a suite's isolation

`test_ase_core`'s ISO1377 block isolates the **registry** so that *"every expectation
below that touches the run command, the save tier or the case of a vector name"* is not
an expectation about the developer's machine. With no entry registered,
`ase::sim_status` falls back to `[auto_execok ngspice]` — so a live capability probe of
whatever ngspice is on `$PATH` still runs. Nothing could see it before, because
`ase::op_save_tier`'s answer reaches the deck only through a non-empty captured
op-cards block and this fixture has none. **6g-3 reads a capability directly in
`render_deck`**, so from this issue on a deck golden taken without a stub says
`.save all` on a machine whose ngspice writes the phantom and does not on one whose
ngspice does not. Row **ISO1434** declares the capability unmeasured for the whole
suite; **WD6b** pins the three capability states deterministically, which is where a
gate belongs.

`6g-4`'s lint has **no runtime consumer**, deliberately: `PLAN.md` classes it M-free
because *"it is an assertion about goldens, not about a binary"*. It lints the
`.control` block and nothing else, which is measured rather than chosen — `.SAVE V(MID)`
behaves identically to `.save v(mid)` on both binaries, while `WRITE <path> ALL` inside
`.control` dispatches fine on apt 45.2 and then writes **no file at all**, rc 0, one
stderr warning.

## And 6g-3 moves a real bench's deck, which `test_ase_final` caught

`test_nfet_final` — a committed `.state` with one ticked output and `op` enabled — **is**
6g-3's shape, and the first cut gave its deck a **second** `.save all` beside the
operating-point tier's own leader (guard G-LEADER). `test_ase_final`'s **F12** asserts
that line appears exactly once (invariant I2/R2) and went red. The stand-down is the
defect's own shape rather than a patch: the phantom exists only where the op plot holds
exactly ONE saved vector, and a deck carrying device `.save @dev[param]` cards puts many
more into that same plot. `ase::saves_op_cards_coming` asks the tier's three conditions
in one place. ⚠ `test_ase_final` is outside the two suites this issue moves, which is
why the whole ASE family was run rather than those two.

## Suites

`tests/headless/test_ase_core.tcl` **523 → 558** (section **WD**, plus row
**ISO1434**) · `tests/headless/test_ase_preflight.tcl` **218 → 229** (section
**PF232**, and four existing rows repointed). Both are in `tests/run_regression.tcl`.
**No deck golden moved**, and row **ISO1434** is what makes that a property rather than
an accident: `nfet_state` IS 6g-3's own shape, so the goldens declare the capability
unmeasured, and **WD6b** pins the gate's three states instead.

Receipt: `doc/claude/ase_analyses_batch/receipts/17-stage-6-variants.md`.
