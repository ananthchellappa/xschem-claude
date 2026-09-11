# Receipt 05 — Stage 0 landed: the silent drop dies (issue 1401)

**Date.** 2026-09-10.
**Scope.** The first code this batch has ever written. `src/ase.tcl`, two suites,
`doc/claude/specs/ase_l.md`, a new issue file and `NUMBERING.md` — plus the batch documents
that record ⚖ R2's answer and this stage's own correction.

⚠ **`LEDGER.md`'s baseline for `src/ase.tcl` is now historical.** It recorded
`39531e402a3d2d2720ef834bc35b0009` / 11 745 lines, and that md5 held **unchanged through
every prior pass of this batch** — the plan, the adapter pivot, the salvage amendment and
the variant amendment all left `src/` untouched, and each of their receipts says so. This
is the receipt where that stops being true. `src/ase_window.tcl` is still
`1e8c6b5085ddc302f1d290a29c1258b7`: Stage 0 is entirely in the non-GUI half.

---

## ⚖ R2 was answered first, and alone

Before any code: *"May ASE-L write `<rundir>/.spiceinit`, copying the user's own file into
it?"* — **answered yes, with the four conditions**, 2026-09-10, in the user's words
*"yes, with those four conditions"*.

It ratified the recommendation **as written**, so no option moved and no cost line was
refuted; what changed is that the four conditions are **requirements** now, not advice, and
Stage 7's pre-deck class and Stage 11's design-variable axis are unblocked. Recorded in
`DECISIONS.md` ⚖ R2 (with the question kept below the answer), in `LEDGER.md`'s *Rulings
answered*, in `PLAN.md`'s ruling-ledger row and in the three stages that cite it, and in
`README.md` / `CREW_BRIEF.md` so a crew reading either does not re-ask it.

⚠ **One consequence a later crew must not read past.** Stage 7's suite list used to say the
six `test_ase_simreg_0931` argv rows move *"the first time `-D` is emitted … if the pre-deck
class emits no `-D` (⚖ R2 = no), none of them moves"*. R2 = **yes**, so that escape is gone
and the re-baseline of **A2 / B5 / B6 / B11 / B12 / D4 in one commit** is now expected work,
not a contingency. `PLAN.md` says so at the row.

**The next ruling is ⚖ R3**, and it is Stage 6's. R10 after the table, R11 last.

---

## What shipped, and where

| file | what changed |
|---|---|
| `src/ase.tcl` | **new** `ase::analysis_unrenderable_msg` (the sentence, minted once), `ase::analysis_emit_rank`, `ase::analysis_emit_order`, `ase::analysis_rank_authority`, `ase::analysis_unrenderable`, `ase::plot_sim_type_reason`; `ase::backend::ngspice::render_deck`'s emit loop now walks the enabled ROWS; `ase::preflight_gate` gains the non-defeasible clause **above** its `ase_preflight` early return |
| `tests/headless/test_ase_core.tcl` | section **D7**, 18 rows. Floor RAISED **230 → 248** |
| `tests/headless/test_ase_preflight.tcl` | section **PF222**, 10 rows. Floor **declared** for the first time, **115 → 125** |
| `doc/claude/specs/ase_l.md` | three paragraphs (the deck-assembly bullet, and **both** stale top-only sentences) |
| `doc/claude/issues/1401-*.md` | new. The measured deck, the shipped procs, the evidence |
| `doc/claude/issues/NUMBERING.md` | 1401 recorded; pointer **1401 → 1402**, both in this commit |

**The refusal, minted once:** `ase: analysis type '<t>' is not one this simulator backend
can render`. `owed.sh add rule 1401` filed the moment it landed — stamped
`repo:/home/analog/dev/xschem-claude`, `ref:` resolving to the issue file — and **updated
after the review**, which found that the gate's *second* sentence is equally user-facing and
was not named in the debt. Both are the **user's** to ratify, with Stage 3's ⚖ R9 batch.

---

## What was measured

**The defect, before anything was changed.** A state whose only enabled row is
`{type noise enabled 1 …}` rendered, at rc 0:

```
.control
set appendwrite
print -i(v1)
.endc
.end
```

No analysis command, no `$sim_status` guard, no `remzerovec`, **no `write` at all**,
nothing on either stream, `ase::n_enabled_analyses` counting the row and the pane showing
it ticked.

**RED first, and the witness is the whole point.** The rows were written *inverted* — one
asserting the render succeeded, another asserting the deck carried `set appendwrite` and no
analysis command — run against the unfixed code, and both were **green**, in both arms, at
`ALL PASS (235)`. ⚠ **Named by assertion, not by letter:** that section had five rows and the
committed one has eighteen, so the letters moved and today's D7d is a different row that
discriminates nothing.
Then the code changed and both went red. Only then were they inverted to assert the
refusal. A defect that leaves nothing behind has no evidence it existed unless the witness
is taken while it is still live.

**Sabotage, four passes.** `ase::analysis_emit_rank`'s `return {}` → `return 0` — the shape
of the defect, not a syntax break — turned **exactly nine rows red**: D7a, D7b, D7c, D7e,
PF222a–e. The review's three fixes were sabotaged individually: deleting the backend-scope
guard reddened **D7e5 and PF222j**; dropping the `lsearch` dedup reddened **D7e2**; dropping
the rundir clause reddened **PF222h**. In all four passes every other row in both suites
stayed green, which is the half that says the rows pin *this* and not something adjacent.
Restored by `cp` from a pristine copy each time, md5 equal. **No `git checkout`, `restore`,
`stash` or `clean`.**

## The adversarial review, and what it changed

Run against the uncommitted diff **before** it was committed: four lenses (Tcl correctness,
byte-identity, test quality, house rules), and every finding handed to a separate agent
instructed to **refute** it. **Fifteen raised, ten refuted, five confirmed.** Nineteen agents.

Two changed the code:

1. **The refusal was not scoped to a backend.** `ase::preflight_gate` applied ngspice's
   four-entry rank table to *every* registered backend, so a second backend's run would have
   been refused before its own `render_deck` hook was called. The precedent for scoping was
   two statements above the call site — `ase::run_composes_registry`, whose header says *"a
   refusal about an entry it never runs would be a lie"* — and it had not been applied. Fixed
   with `ase::analysis_rank_authority`, which compares the state's simulator to the **schema
   default's** rather than naming `ngspice` in core.
2. **The refusal dropped the rundir clause a written ruling requires of this proc**
   (`doc/claude/specs/simulator_profiles.md`). Restored — and improved on the siblings, which
   call `ase::rundir` and therefore **create** the directory from inside a refusal whose whole
   claim is that nothing was written. This one names it only when it already exists; **PF222i**
   is the non-vacuity row.

Three were confirmed as documentation defects: row-letter drift across the red-first cycle
(today's D7d is not the historical D7d, and it discriminates nothing — cite the assertion,
never the letter); D7e's *"names it once"* being unobservable with a one-row fixture (now
**D7e2/D7e3/D7e4**); and the gate's **second** sentence being user-facing copy that the rule
debt did not name.

Ten were refuted, including *"the naming rule is breached"*, *"Stage 1 cannot replace the rank
table"* and *"D7i does not pin lsort stability"* — each traced to the code by a verifier that
was told to break it.

**Counts, per suite per arm** — measured, and cross-checked by name-diffing the `ok:` lines
rather than by subtracting:

| suite | before | after | `--nogui` | `:99` |
|---|---|---|---|---|
| `test_ase_core` | 230 | **248** | 248 | 248 |
| `test_ase_preflight` | 115 | **125** | 125 | 125 |

**T1: 0 counted failures**, solo, under a scratch `HOME` with `XSCHEM_DEVDISPLAY_DIR`
exported. Three `NOGOLD` notes (`create_save`, `open_close`, `netlisting`) are printed and
not counted — those three have no committed baseline, which is CLAUDE.md's standing note
and not this stage's.

---

## Two T1 baselines were thrown away first, and both were mine

Recorded because both are cheap to repeat and neither is a tree defect.

**(a) A scratch-`HOME` race.** The first run reported **1 FATAL** in
`create_save/simple_inv` — `Tcl_AppInit(): failure creating …/t1home/.xschem`. Sixteen
parallel workers raced to create `$HOME/.xschem` in a scratch `HOME` that did not exist
yet; the loser is scored as a case failure. Issue **1397** tells a crew to use a scratch
`HOME`; it does not mention this corner. **Pre-create `$HOME/.xschem` before a parallel
run.** `create_save` touches no ASE-L code path at all, which is what made the attribution
clean rather than assumed.

**(b) Editing product code under a running suite.** The second run reported **3 failures in
`test_ase_simcaps_0948`** — because `src/ase.tcl` was being edited while the run was in
flight, and the suite sources it. **Do not edit product code while a suite is running.** A
suite that reads a half-written file reports a defect that exists for nobody, and it looks
exactly like a real one.

Neither number was carried forward and neither was reported as "pre-existing". CLAUDE.md's
rule is that a standing red is a defect, not furniture; the corollary is that a red with a
proven harness-side cause must be *named and eliminated*, not explained away.

---

## What was corrected in the plan — C36

**`PLAN.md` Stage 0 described the defect wrongly, in the direction that made it look
milder.** It said today's deck was *".control / set appendwrite / remzerovec / write /
.endc"* — a rawfile written and merely empty. There is no `remzerovec` and no `write`:
0929 moved both inside the per-analysis loop, so the run writes **no raw file whatsoever**.
That is worse, because `ase::attach_dbs` then says `NOT ATTACHED … the analysis did not
run` about a run that never contained the analysis, and a user reads that as the simulator
failing.

Recorded as **C36** in `PLAN.md`'s corrections table, and fixed in place at Stage 0 with a
⚠ block rather than silently. **The general form of it is the thing to carry:** this plan's
prose about *today's* behaviour is a claim, not a measurement, even where it is specific
enough to look like one. Render the deck and look. Stages 1–16 all open with a description
of what the tree does now.

---

## What was NOT done, deliberately

* **The eight copies of *"what is a `dc` analysis"* are not collapsed.** That is Stage 1.
  The rank table shipped here is explicitly temporary and its comment says so: Stage 1
  replaces it with the registry's `emitorder`, reached through the `analysis_types` hook.
  **The loop shape is final; only the table is Stage 1's to replace.**
* **The print anchor is untouched** — the *separate* `foreach type {dc ac tran op}` twelve
  lines below the old `anorder`, governed by issue 1243's ruling rather than 0964's. It is
  the eighth copy and it is Stage 1's. A row of an unknown type can no longer reach it,
  because the refusal fires first.
* **No analysis type was added.** `noise` is this stage's fixture, not a feature.
* **`ase::plot_sim_type` itself is unchanged** — row R6 of `test_ase_optier_0963.tcl` pins
  its preference ranking, and issue 0964's warning that the coupling to emit order must not
  be re-established still stands. What was added is a second question (`…_reason`), not a
  different answer to the first.
* **No look debt.** This stage is headless by construction: it changes no widget, no label
  and no layout, and its entire deliverable is a refusal the headless suites read.

---

## What the next session should do first

1. **Do not re-ask ⚖ R1 or ⚖ R2.** Both are answered, both on 2026-09-10. **⚖ R3 is next**
   — where the Outputs Value column's numbers come from — and it is Stage 6's, so it is not
   urgent; Stage 1 carries no ruling at all.
2. **Stage 1, and treat its acceptance as a stop condition.** If today's four types cannot
   be re-expressed through `ase::analysis_types` and reproduce `test_ase_core` **D1** under
   `string equal` — the whole `expected_deck`, netlist and cards included — the descriptor's
   shape is wrong and the plan stops there. Do not adjust the golden; do not add a
   compatibility arm.
3. **Do sub-item 1e before claiming byte-identity**: Xyce's descriptor on paper, now
   including `requires` / `notes` / `lint`. *"Nothing broke"* is a suspicious answer.
4. **Stage 2e is the next cheapest honest thing** — the Stop warning — and it ships before
   any checkpoint code exists (⚖ R1's requirement, debt M18).
