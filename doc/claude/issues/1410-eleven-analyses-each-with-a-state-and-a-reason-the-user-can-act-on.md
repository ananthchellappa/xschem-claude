# 1410 — eleven analyses, each with a state and a reason the user can act on

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C5** of Stage 2 of `doc/claude/ase_analyses_batch/` (plan items **2b** + 2c's
core half)

## What ships

Eleven analysis types exist in ngspice and ASE-L offered four. A user who cannot find an analysis
in ADE-L has no way to learn why; **four states, never invisible**, is the first place this design
is plainly better.

`ase::caps_analysis_present`, `ase::requires_state`, `ase::analysis_renderable`,
`ase::analysis_state`, `ase::analysis_states`, `ase::sim_caps_cached`, `ase::analysis_detect`,
`ase::analysis_reasons`, the `analysis_caveat` hook and ngspice's one clause; the registry grows to
**eleven**. No widget moves.

## The honest grid for this tree today: four `ok`, seven `blocked`

The renderable test sits **above** the availability arms, deliberately: a type ASE-L cannot emit is
`blocked` whatever the binary says, because offering it would produce a run that emits nothing —
issue 1401's silent drop wearing a green cell. So the seven are **listed**, which is the point, and
blocked until Stage 6 gives them an `emit`.

## Five reason tokens, and the two a reader will want to collapse

| token | meaning |
|---|---|
| `ok/measured` | the probe ran and this build has it |
| `ok/baseline` | offered on a **source-verified invariant** — nobody measured anything |
| `absent/notpresent` | the probe ran and this build does not have it |
| `absent/unmeasured` | nobody measured, **and something here could** |
| `absent/noprobe` | nobody measured, **and nothing here ever can** |
| `blocked/unrenderable` | the adapter lists the type but cannot emit it yet |
| `caution/caveat` | it will run, and something about it will be worse than expected |

⚠ **`unmeasured` versus `noprobe` is the pair that ships a button that lies if collapsed.**
`unmeasured` is the token that carries **Detect**; for a backend with no `capabilities` hook Detect
is a *permanent* no-op — measured, the state list is byte-identical before Detect, after Detect and
after a second Detect. `ase::sim_has_probe` is the distinguishing fact and it was already in the
tree.

⚠ **An absent `baseline` defaults to 0**, which is the whole point of Stage 1's correction C42. The
key was `gated` and meant *"an `#ifdef` could remove this"*; renaming it to `baseline` **flipped**
what an absent key must mean. Defaulting the other way makes every unmeasured capability resolve
`ok/baseline` and **offers analyses nobody verified** — the inverse of this stage's stated worst
outcome, one `dict exists` default away.

## Four things I got wrong, each caught by a row or a sabotage

**1. I gave the seven new types a `viewrank`, and D7k went red.** `viewrank` is which analysis *the
viewer prefers* — a claim about **results** — and a type nothing can emit produces none. It made
`ase::plot_sim_type` answer `noise` for a bench enabling only noise. **The row was right and the
registry was wrong**: a surface may not prefer an analysis that cannot produce data for it.

**2. I put a `#` comment block inside a `dict create` argument list.** In Tcl that is not a comment,
it is an **argument** — it silently shifted the dict, `op` lost its `emit`, and optier broke in five
places with `analysis type 'op' is not one this simulator backend can render`. Third occurrence of
that exact shape in this batch.

**3. I composed the two-key sort backwards.** `lsort -index 1 [lsort -index 0 …]` puts the
*declaration index* outside, so the rank was being **ignored entirely**. It looked correct only
because the four ranked entries happen to be declared in rank order. A sabotage caught it: setting
the rank-less sentinel back to 0 changed nothing, because nothing was sorting by rank.

**4. The probe skipped all seven types**, because their token comes from the emit template and they
have none — so their availability could never be measured. Fixed with a **`role probe` card**:
invisible to `ase::analysis_line` (which selects `role analysis`), visible to the probe. That is the
role tag doing the job it was added for, rather than re-adding the `verb` key Stage 1 deleted (C41).

## The row that took four attempts, and why that is worth recording

**U2 fences guard 1** — a `sim_status` that says *no* still carries a `resolved` naming a real file
on the PATH, and reading the cache under that key attributes a measurement of the wrong program to
the simulator the user is actually using (issue **0935**).

Three fixtures in a row **looked fine and could not fail**:

1. nothing registered → `resolved` came back **empty**, and the empty-path guard one line below
   catches that on its own;
2. a program of the right name on the PATH, but **nothing cached under its key** → the lookup
   misses and both answers are `{}`;
3. both, but the second entry registered **after** the warm → `ase::sim_register` calls
   `ase::sim_caps_clear` (issue 0950), so registering **emptied the very cache the row needed warm**.

Deleting guard 1 outright left the row green all three times. The working fixture needs **all
three** of `ok 0`, a non-empty `resolved`, and a cache entry under exactly that key — so both
entries are registered first, the cache is warmed under the honoured selection, and only then is the
selection re-pointed.

## Verification

| suite | arm | before | after |
|---|---|---|---|
| `test_ase_core` (section **AG**, 16 rows) | headless | 273 | **289** |
| `test_ase_simcaps_0948` (section **U**, 7 rows) | both | 141 | **148** |
| `test_ase_dialogs` (G14g re-aimed at eleven) | display | 224 | 224 |

⚠ **`ase::state_default` is unmoved at four rows**, so ⚖ R4's recommended answer ships **by
construction** and the 104 committed `.state` files round-trip byte-identically. Before the one-line
`continue` in `ase::analysis_seed`, registering seven more types would have grown it to eleven and
reddened R1 **by accident** — which is exactly the *"this would change by accident"* that made R4 a
ruling rather than an edit.

**Nine sabotage passes**, each reddening named rows: the seed appending every registered type (R1,
AG3, AG4, AG16); a rank-less entry tying with `op` (AG1, AG2); `baseline` defaulting to 1 (AG8);
collapsing `noprobe` into `unmeasured` (AG7, U5); a `viewrank` on the seven (D7k, AG14); the caveat
spelled `![caps_is …]` (AG5, AG9); availability tested above renderable (AG5, AG6); the peek
starting a program (U1, U3); the peek dropping guard 1 (U2).

## Related

* **1407** — the capability vocabulary every reader here goes through.
* **1409** — the probe leg that publishes `analyses_available` / `analyses_probed`.
* **1401** — Stage 1, whose C41 deleted `verb` and whose C42 inverted `baseline`.
* ⚖ **R4** — shipped by construction; ⚖ **R9** — the reason sentences are on rule debt 1408.
