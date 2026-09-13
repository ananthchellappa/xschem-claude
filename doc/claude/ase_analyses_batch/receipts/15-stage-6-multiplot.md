# Stage 6 — `noise`, `disto` and `sens`'s AC mode, and the walk's first real load

**One commit, issue 1432, and the fourth of Stage 6.** The first is **1429** (⚖ R3's
reader seam, `595ab274`); the second **1430** (the writer, the plot sidecar and
reconciliation, `7ea9f1dc`); Stage 5 is **1426** (`tf`), **1427** (`pz`), **1428**
(`sens`, DC only). This is 6d.

**Floors:** `test_ase_core` 453 → **476** · `test_ase_preflight` 194 → **210** ·
`test_ase_simcaps_0948` 190 → **199** · `test_ase_optier_0963` 105 → **106** —
**forty-nine new rows**, and every other ASE suite byte-unmoved.
All four are in `tests/run_regression.tcl`, so **T1 covers every row this commit
adds** and nothing here is outside T1's reach.

⚠ **⚖ R3 IS STILL UNANSWERED and this issue does not touch it.** Nothing here reads
a number or moves a print line.

⚠ **NO DECK GOLDEN MOVED.** Issue 1430 budgeted "every deck golden moves" for Stage 6
and spent it: `test_ase_core`'s **D1** took the sidecar line then. This commit adds
three analysis types and moves no golden, because no golden renders one of them.

---

## The one sentence this task is for

**Issue 1430 shipped the `setplot previous` walk with no production exerciser and
said so** — its correction **C64**: every type in the registry as it stood captured
exactly **one** plot, because `ac`'s and `pz`'s second plots are `role opinfo` and
declined. `noise` and `disto` are the first that genuinely capture more. This receipt
is the walk driven by the **shipped registry**, end to end, on both binaries.

**And an over-walk is silent.** Measured again here on both binaries: `setplot
previous` past an analysis's first plot neither fails nor wraps — it **saturates** on
ngspice's built-in `constants` plot, and the next `write` appends the twelve
mathematical constants to the results file at rc 0, with the only trace a stderr
warning. So every capture set below is declared as a **set of names**, per type, per
binary, and not as a count.

---

## What shipped

### `src/ase.tcl` — the schema half (core `ase::`)

| proc / change | what it answers |
|---|---|
| `ase::plot_when_valid` / `ase::plot_when {when state ?row? ?sim?}` | **three new `when` forms** — `{field N}`, `{nofield N}`, `{hook P}` — beside `{opt N}` |
| `ase::plot_results {p}` | **D30's destination**, read in one place |
| `ase::field_depends {fd}` / `ase::field_active {row fd flds}` | a field that is only real when another one says so |
| `ase::analysis_expand` | a field whose `depends` is unsatisfied emits **nothing**, checked **before** the default |
| `ase::analysis_emit_check` | an inactive field is not required; a declared `min` is refused by name |
| `ase::analysis_emit_msg` | one new clause, `belowmin` |
| `ase::analysis_schema_errors` | **five new refusals**: `noplotresults`, `badplotroute`, `badplotwhenfield`, `badplotwhenhook`, `baddepends` — and `fieldunused` now exempts a field named by another field's `depends` |
| `ase::needs_eval` / `ase::analysis_needs` | gain an optional **`state`**, because two of the new preconditions read the bench's *output rows* rather than the analysis row |

### `src/ase.tcl` — the content half (`ase::backend::ngspice`)

* **`noise`** — 8 fields, 3 plots, 4 preconditions, `emitorder 40`.
* **`disto`** — 5 fields, 6 plots (2 XOR 3 plus the companion), 4 preconditions, `emitorder 80`.
* **`sens`** — the **AC mode**: a `mode` field and four AC-only fields gated by
  `depends {mode ac}`, a second plots row, and the KLU cross-rule.
* Four new readers: `noise_integrated`, `noise_total_vectors`,
  `noise_contributor_kind`, `sens_is_dc` / `sens_is_ac`.
* **`ac`'s and `pz`'s `opinfo` companions move from `results viewer` to `results none`.**

**`src/ase_window.tcl` is untouched.** No new state key, no `seed_enabled`,
`ase::state_default` still seeds exactly four rows, and the **104 committed `.state`
files are byte-identical** — section **CP** of `test_ase_core.tcl` is the row that
would notice.

---

## Every measured fact this rests on

All 2026-09-12, scratch decks under `/tmp/mp6probe`, **never a bench under
`sky130A/`** and nothing written under `~/.xschem/`. Binary 3 is
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (`ngspice-46+`); binary 1 is
`/usr/bin/ngspice` (`ngspice-45.2`). **Both were run for every measurement below and
every one came back identical on the two.**

### 1. The plot sets, per type, walked with `setplot previous`

```
noise dec 10 1 10k        W0 Integrated Noise   W1 Noise Spectral Density Curves
noise lin 2 1k 10k        the same two
noise dec 1 1000 1001     the same two
noise oct 1 1k 2k         the same two
noise lin 1 1k 10k        W0 Noise Spectral Density Curves   W1 constants
noise lin 5 1k 1k         the same ONE
noise dec 10 1k 1k        the same ONE
disto dec 2 1k 10k        W0 - 3rd harmonic   W1 - 2nd harmonic
disto dec 2 1k 10k 0.9    W0 - IM: 2f1-f2  W1 - IM: f1-f2  W2 - IM: f1+f2
sens … dc   /  sens … ac  ONE plot each, and the SAME literal
+ .options keepopinfo     noise -> NOISE Operating Point (created FIRST)
                          disto -> Distortion Operating Point (either mode)
                          sens  -> NOTHING, in EITHER mode
```

### 2. ⚠ `PLAN.md` 6b's predicate for `Integrated Noise` is WRONG

The plan writes `when {expr {start ne stop}}`. Line five above refutes it: **`noise …
lin 1 1k 10k` has start ≠ stop and produces one plot.** The rule is *more than one
frequency point*, and it has exactly two ways of being one — `noisean.c:93-109`
collapses start ≈ stop, and `:145-168`'s LINEAR arm divides by `N-1`. `dec` and `oct`
step by a **ratio** and always reach a second point whenever start ≠ stop, which
`dec 1 1000 1001` was measured to confirm.

Had the plan's predicate shipped, every `noise … lin 1` run would have declared one
capture too many, and an over-walk is silent.

### 3. ⚠ `.options sqrnoise` RENAMES BOTH NOISE PLOTS

```
default            Noise Spectral Density Curves     Integrated Noise
.options sqrnoise  ... - (V^2 or A^2)/Hz             ... - V^2 or A^2
```

`ase::reconcile_plots` has matched `select` with `string match -nocase` since issue
1430, so the two `noise` rows declare **globs**. An exact literal would report
`mislabel` on every `sqrnoise` run — for a run in which nothing went wrong.

### 4. ⚠ `sens … ac oct` IS BROKEN TOO, AND NOBODY HAD MEASURED IT

Receipt 12 recorded the `lin` defect (`inc_freq` testing against `#define LINEAR 3`
from `noisedef.h` while `SENS_LINEAR` is 15, so the sweep is always geometric) and
recommended `values {dec oct}`. Measured:

```
sens v(mid) r1 ac oct 2 1k 4k   ->  TWO points: 1000  1414        [ac oct 2 1k 4k: FIVE]
sens v(mid) r1 ac oct 4 1k 2k   ->  TWO points: 1000  1189        [ac: FIVE]
sens v(mid) r1 ac oct 1 1k 4k   ->  ONE point                     [ac: THREE]
sens v(mid) r1 ac dec 2 1k 100k ->  1e3 3.16e3 1e4 3.16e4 1e5     [ac dec: identical]
sens v(mid) r1 ac dec 4 1k 10k  ->  five points                   [ac dec: identical]
```

`count_steps`' OCTAVE arm (`cktsens.c:862-900`) is
`n = (int)(steps * log(high/low) / M_LOG2E + 1.01)` — **`M_LOG2E` is log₂e = 1.4427**,
where an octave count needs `M_LN2` = 0.6931. So it produces ~48 % of the points
asked for. `dec` is correct on every case tried. **The field declares `values {dec}`.**

### 5. ⚠ THE CONTRIBUTOR NAMES ARE IN A DIFFERENT PLOT FROM THE ONE THE APPENDIX POINTS AT

`APPENDIX §2.6` gives them as `onoise_total_<inst>_<mech>`; `§6.2` routes the
contributor table to *inside the **spectrum** plot*. Both are right about something
and neither is right about the pair. Measured with `ptspersummary 1` on a deck
carrying `rb rc re r9 q1 d1`, `display` run in each plot:

```
spectrum plot          onoise_r9   onoise_r9_thermal   onoise_q1_ib  …
                       onoise_spectrum   inoise_spectrum
Integrated Noise plot  onoise_total_r9   onoise_total_r9_thermal  …
                       onoise_total   inoise_total
```

Source agrees: `resnoise.c:68-82`'s `N_DENS` arm builds `onoise_%s%s` and its
`INT_NOIZ` arm builds `onoise_total_%s%s`; `cktnoise.c:56-82` adds the four
circuit-level names. **`noise_contributor_kind` takes either spelling.**

⚠ **A FIFTH NAMING HAZARD, BESIDE THE THREE §2.6 LISTS:** `onoise_spectrum` has
**exactly the shape of a device total** — and so does `onoise_total` once the
`onoise_` prefix is taken. A reader splitting on the first `_` reports the *circuit*
as a device and doubles the table's sum, twice over. The four circuit-level names are
excluded by name.

⚠ And the **fork emits more mechanisms than apt 45.2 for the same device**:
`onoise_d1_1overfsw`, `onoise_d1_idsw`, `onoise_d1_rsw` exist on the fork and not on
45.2. A table built from a fixed mechanism list is wrong on one of the two binaries.

### 6. ⚠ `disto` SEGFAULTS THROUGH ASE-L's OWN DECK SHAPE

`.save` **dot cards above `.control`** is what `render_deck` emits for an Outputs row
with the Save tick. Measured, both binaries:

```
.save v(nosuchnode)                      + disto  ->  rc 139, SIGSEGV
.save v(nosuchnode) / .save v(alsonone)  + disto  ->  rc 139
.save i(vnope)                           + disto  ->  rc 139
.save v(mid) / .save v(nosuchnode)       + disto  ->  rc 0
.save v(nosuchnode) / .save v(mid)       + disto  ->  rc 0
.save all / .save v(nosuchnode)          + disto  ->  rc 0
.save @m.x1.m1[id]  (absent device)      + disto  ->  rc 0
no save card at all                      + disto  ->  rc 0
```

The trigger is the **whole list resolving to nothing**. `design-C`'s proposed refusal
— *`disto` enabled AND zero saved outputs* — would refuse the deck on the last line,
which runs.

### 7. ⚠ AND ONE TICKED OUTPUT STARVES `noise`, `tf` AND `sens`

`APPENDIX §7.5.2` assigns this to *"Stage 6's precondition"* by name. Measured:

```
no save card at all   + noise -> rc 0, both plots
.save all             + noise -> rc 0, both plots
.save all / .save v(mid) + noise -> rc 0, both plots
.save v(mid)          + noise -> rc 1, `Error: no data saved for Noise analysis;
                                 analysis not run`, $sim_status 1, Plotname: constants
.save v(mid)          + tf    -> rc 1, the same shape
.save v(mid)          + sens  -> rc 1, the same shape
.save v(mid) with `save all` inside .control + noise -> rc 0, both plots
```

**One ticked output is enough**, and that is the shape of `nfet_state` — this tree's
own shared bench fixture. Three existing rows (`tf_lines`, `sens_lines`, `WKST2`)
had been asserting about decks ngspice would have refused to run.

### 8. The noise preconditions, measured one deck at a time

```
noise v(nosuchnode) v1 dec 2 1k 10k  -> rc 0, A FULL TWO-PLOT RESULT, silent
noise i(v1) v1 dec 2 1k 10k          -> rc 1, `Error: bad syntax [.noise v(OUT) …]`
noise v(mid,in) v1 …                 -> rc 0, right
noise v(mid) vnope …                 -> rc 1, `Noise input source vnope not in circuit`
noise v(mid) r1 …                    -> rc 1, `… r1 is not of proper type`
noise v(mid) v2 …                    -> rc 1, `… v2 has no AC value`
noise v(mid) v1 dec 0 1k 10k         -> rc 1, `Number of steps … has to be larger than 0`
noise v(mid) v1 dec 2 0 10k          -> rc 1, `Frequency of 0 is invalid`
.options klu + noise …               -> rc 1, `Noise simulation is not (yet) supported
                                        with 'option KLU'. Use 'option sparse' instead.`
disto, no source carrying distof1    -> rc 0, three rows of numbers, NOTHING said
disto … 0.9, no source with distof2  -> rc 1, `incomplete or empty netlist`
```

⚠ **The third line of the `insrc` block is the one `ac_source` cannot make.** `V2`
*is* a source and the deck *does* have an AC source, so `ac_source` is satisfied and
the run still dies.

⚠ **`noise`'s output is a voltage and only a voltage**, which `tf` and `sens` are
not — both of those take `i(<vsrc>)`.

### 9. END TO END, THROUGH ASE-L's OWN `render_deck`, ON BOTH BINARIES

Four states, a scratch library under `/tmp` with an explicit `rundir`, `paste(1)` of
the sidecar against the results file's `Plotname:` records. **rc 0 on both binaries,
row for row, byte for byte identical:**

```
deck 1  op + noise(dec) + disto(harmonic)
  PLOT op    0 |Operating Point|                 @ Plotname: Operating Point
  PLOT noise 1 |Integrated Noise|                @ Plotname: Integrated Noise
  PLOT noise 1 |Noise Spectral Density Curves|   @ Plotname: Noise Spectral Density…
  PLOT disto 2 |DISTORTION - 3rd harmonic|       @ Plotname: DISTORTION - 3rd harmonic
  PLOT disto 2 |DISTORTION - 2nd harmonic|       @ Plotname: DISTORTION - 2nd harmonic

deck 2  noise(lin 1) + disto(IM)          <- the ONE-plot noise row, and three IM plots
  PLOT noise 0 |Noise Spectral Density Curves|   @ Plotname: …
  PLOT disto 1 |DISTORTION - IM: 2f1-f2|         @ …
  PLOT disto 1 |DISTORTION - IM: f1-f2|          @ …
  PLOT disto 1 |DISTORTION - IM: f1+f2|          @ …

deck 3  sens(dc) + sens(ac)               <- ONE literal, told apart by 0 and by 1
  PLOT sens 0 |Sensitivity Analysis|             @ Plotname: Sensitivity Analysis
  PLOT sens 1 |Sensitivity Analysis|             @ Plotname: Sensitivity Analysis

deck 4  op + noise(dec) under keepopinfo   <- the companion is COMPUTED and NOT KEPT
  PLOT op    0 |Operating Point|                 @ …
  PLOT noise 1 |Integrated Noise|                @ …
  PLOT noise 1 |Noise Spectral Density Curves|   @ …
```

* **Zero `Plotname: constants` records in any of the eight results files.**
* **No `Warning: No previous plot is available` on either stream, anywhere** — the
  walk never over-stepped.
* `ase::reconcile_plots` over deck 1's artefacts: **`ok`, 5 / 5 / 5, and nothing
  said.**
* The sidecars and the `Plotname:` lists are **byte-identical between the fork and
  apt 45.2** for all four decks.

---

## Where the walk now stands, and the one thing the reader still cannot do

⚠ **`Integrated Noise` READS BACK AS `op`, AND THE WALK IS WHAT PUTS IT FIRST.**
This is the driver's own addition to the brief, followed through. `src/save.c`'s
`read_dataset()` runs its `Plotname:` arms in this order:

```
"noise spectral density curves"            -> noise
"operating point"                          -> op          <- above the AC arm
"integrated noise"                         -> op WHEN `type` IS NOT YET SET;
                                              noise only if `type` is already "noise"
"ac analysis" | "spectrum" | "sp analysis" -> ac
```

Re-read in the tree (`src/save.c`, the `read_dataset()` arm block) and it is exactly
as the brief describes. **What this commit adds to it is the file order**: the walk
writes an analysis's plots in REVERSE creation order, so a `noise` run puts
`Integrated Noise` **before** `Noise Spectral Density Curves` in the results file —
and `op` is written first (rank 0) or last (the 0964 `op`-last variant), so both
orders occur in production.

The measured consequence is in the table below. **Nothing in this commit changes it**:
`noise` declares no `viewrank`, so `ase::plot_sim_type` never answers `noise`, and
`ase::attach_dbs` is `src/ase_window.tcl`'s and out of scope. It is recorded here
because it is the next question in this seam and it belongs to ⚖ R3's reader, not to
the writer.

**MEASURED, on real results files this commit's own `render_deck` produced, read
through this tree's own binary:**

| results file, in WRITE order | `xschem raw read <f>` | `… <f> op` | `… <f> noise` |
|---|---|---|---|
| `Operating Point` / `Integrated Noise` / `Noise Spectral Density Curves` | `sim_type=op`, 1 dataset, `v(mid)` present, `onoise_total` **absent** | the same — **the real operating point wins** | `sim_type=noise`, `onoise_total` present, `v(mid)` absent — and it is the **Integrated Noise** plot, 1 point, **not** the spectrum |
| `Integrated Noise` / `Noise Spectral Density Curves` *(a noise-only bench)* | **`sim_type=op`**, carrying `onoise_total` | **read=1, `sim_type=op`** — a bench with **no operating point at all** answers an `op` read with noise scalars | `sim_type=noise`, again the **Integrated Noise** plot |

⚠ **Two findings, and neither is this commit's to fix.**

1. **A noise-only results file answers `xschem raw read … op`.** `Integrated Noise`
   is the first `Plotname:` the reader meets, `type` is unset, and the `integrated
   noise` arm takes `op`. Anything that annotates an operating point from such a file
   would publish noise scalars onto the schematic. **`noise` declares no `viewrank`,
   so nothing in ASE-L asks** — but the file is now producible, where before Stage 6d
   it was not.
2. **Asking for `noise` gets the SCALARS, not the spectrum.** Both plots match an arm
   (`noise spectral density curves` → `noise`, `integrated noise` → `noise` once
   `type` is set), and the reader stops at the first; the walk puts the scalars
   first. A waveform viewer handed `noise` would open on a one-point plot.

**Both belong to ⚖ R3's reader seam and to `ase::attach_dbs`, which is in
`src/ase_window.tcl`.** They are recorded here because Stage 6d is what made the file
shape reachable, and because the brief asked for both orders to be measured rather
than assumed.

---

## What the plan and the tree said that this refuted

The batch's twenty-seventh through thirty-third corrections (Stage 5 took C43–C55,
issue 1429 C56–C59, issue 1430 C60–C64).

### C65 — `PLAN.md` 6b's `Integrated Noise` predicate is wrong, and it fails silently

*`when {expr {start ne stop}}`.* Measured (fact 2): `noise … lin 1 1k 10k` has
start ≠ stop and produces **one** plot. The registry declares a `{hook …}` instead,
and `ase::plot_when_valid` **refuses the `expr` form outright** so that the next crew
is told to implement a different rule rather than an evaluator for this one.

⚠ This is issue 1430's C60 a second time and with a sharper edge: C60 caught the
plan's `keepopinfo` table listing `tf`, which produces no companion; this catches the
plan's *predicate* being wrong for a plot that exists most of the time. **Measure the
table AND the predicate, not only the conclusion.**

### C66 — the registry lists a multi-plot type's plots in WRITE order, not creation order

`ase::analysis_plots`' own header, as issue 1430 left it, says *"in the registry's own
order (which is creation order: the analysis's own plot first, then its companions)"*.
It cannot be creation order, and 1430 could not see it because every shipped type
captured one plot. The walk runs **backwards**, and `ase::reconcile_plots` compares
its prediction **positionally** against a sidecar written in write order — so `noise`
must declare `Integrated Noise` **before** `Noise Spectral Density Curves`, and
`disto`'s IM plots must run `2f1-f2`, `f1-f2`, `f1+f2`. A registry in creation order
passes every static row and **mislabels every real run**; row MP19 is the reverse
fixture that says so, and the header is corrected.

This is C62 one level deeper: C62 said the *sidecar* is write-ordered; this says the
*registry* must be.

### C67 — `.options sqrnoise` means `select` has to be a glob

Fact 3. `PLAN.md` 6b writes `match {Noise Spectral Density Curves*}` and is **right**;
issue 1430 shipped `select` as an exact literal for four entries that happen to glob
to themselves. The comparison was already `string match -nocase`, so the star costs
nothing — but nothing in the tree said the key was a pattern until now.

### C68 — receipt 12's `values {dec oct}` for SENS AC offers a second broken sweep

Fact 4. `oct` produces ~48 % of the points asked for on both binaries, from a
`M_LOG2E`/`M_LN2` confusion in `count_steps`. Nobody had measured it — receipt 12
measured `lin` and reasoned about `oct` from the fact that "`dec`/`oct` are unaffected
because their `step_size` is a ratio", which is true of `inc_freq` and false of the
**point count**. The field declares **`values {dec}`**.

### C69 — `APPENDIX §2.6`'s contributor names are the other plot's

Fact 5, with the source to match. And the appendix's three naming hazards are
**five**: `onoise_spectrum` and `onoise_total` both have the shape of a device total.

### C70 — `PLAN.md` §6d's *"checked in the dialog AND re-checked in `render_deck`"* is already the tree's shape

The plan asks for the DISTO save rule to be *"checked in the dialog and re-checked in
`render_deck`, and not defeasible by `set ase_preflight 0`"*. As of issue **1424**
that is exactly what a **`fatal` precondition** already gets, in three tiers and
without a line of new plumbing: `ase::analysis_precheck` feeds the Choose Analyses
grid; `ase::preflight_gate` refuses **above** the `ase_preflight` escape and says so
in its own sentence; and `render_deck` re-checks before it builds a line. Declaring
`disto_saves` `fatal` is the whole implementation.

### C71 — `ase::needs_eval` could not see the bench, and two of these predicates must

Every precondition through Stage 5 asks about the **analysis row** it is handed.
`disto_saves` and `vecsaves` ask about the bench's **output rows**, which no argument
carried. `needs_eval` and `analysis_needs` take an optional `state`; existing
two-argument callers are unaffected by construction.

⚠ **The cost is named rather than hidden**: a predicate that reads the state is one a
caller can starve by not passing it, so both answer `{}` — satisfied — for an empty
state. A reader that cannot see the save list may not refuse a run because of it.

---

## Suites moved, before → after

| suite | headless | display (`:99`) | in T1? |
|---|---|---|---|
| `test_ase_core` | 453 → **476** | **476** | yes (`run_regression.tcl:75`) |
| `test_ase_preflight` | 194 → **210** | **210** | yes (`:29`) |
| `test_ase_simcaps_0948` | 190 → **199** | **199** | yes |
| `test_ase_optier_0963` | 105 → **106** | **TIMEOUT** — see below | yes (`:67`) |
| `test_ase_cosim` | 341 → 341 | **341** | ⚠ **no** — issue 1421's list |
| every other ASE suite (24) | unmoved | not run | — |

The display arm was taken through `tests/headless/run_suites.sh` with
`SUITE_TIMEOUT=400`, which reported *"display arm: ATTACHED to persistent dev display
:99 (devdisplay.sh), GUI_GATE=0"* — `devdisplay.sh status` before the run: alive,
openbox (Openbox 3.6.1), `1920x1080x24`. **`4/4 runs passed.`**

⚠ **`test_ase_optier_0963`'s display arm TIMED OUT at 400 s, and it is the filed
pre-existing stall**, not a regression: `CLAUDE.md` names it (*"86 of 103 rows, stops
after row N3"*), and the three Stage 5 crews and the 1429 and 1430 crews all hit it
in the same place. Its **headless** arm — the one `run_regression.tcl` runs — is
**ALL PASS (106)** before and after. Bounded by `run_suites.sh`'s own per-arm
`timeout`; `pgrep -af src/xschem` afterwards shows **no orphan from this run** (the
only live one belongs to the other clone, `xschem-op-wcard`).

✅ **Nothing this commit MOVES is outside T1's reach**, verified by reading
`tests/run_regression.tcl`'s own lists rather than assuming: `test_ase_preflight`
(`:29`), `test_ase_simcaps_0948` (`:66`), `test_ase_optier_0963` (`:67`) and
`test_ase_core` (`:75`) are all there. Issue 1421 lists twenty-one `test_ase_*`
suites T1 cannot verify and **none of them moved** — the same unusual position issue
1430 was in, and worth saying plainly rather than assuming.

⚠ **`test_ase_cosim` IS one of the twenty-one, and it did NOT move** — 341 before and
341 after, on both arms. It is listed above because this crew ran it, not because
this commit touched it; **a T1 number does not cover it** and it needs a standalone
run from anyone who wants that number.

New sections: **MP** in `test_ase_core.tcl` (23 rows), **PF230** in
`test_ase_preflight.tcl` (16 rows), **NV** in `test_ase_simcaps_0948.tcl` (9 rows),
row **E5d** in `test_ase_optier_0963.tcl`. All four floor paragraphs raised in the
same change.

### ⚠ FOURTEEN EXISTING ROWS MOVED, AND EVERY ONE BECAUSE A TYPE STOPPED BEING PROBE-ONLY

`test_ase_core.tcl`: **AG1**/**AG2** (the offered list splits at nine; only `sp` and
`pss` are rank-less, and `noise` took its fifth place back from `sens` by earning
`emitorder 40`), **EM7**/**CP6** (two probe-only types, not four), **GP1** (nine
renderable types, not seven), **TF1**/**PZ1**/**SE1** (leading slices each grew by
one; not one of the three ranks moved), **D7a–D7e4** and
**TF3b**/**PZ3b**/**SE3b** (their unrenderable control type was `noise` and is now
`sp`, with `pss` still the second for D7e3), **SE8**/**SE9** (`sens` declares two
plots rows and a second destination). `test_ase_simcaps_0948.tcl`: **SV5**.
`test_ase_preflight.tcl`: **PF222a–e / PF222h–j** changed their unrenderable fixture
from `noise` to `sp`.

⚠ **Row TF3b warned in as many words that these would move**: *"rows PF222a-e and
PF222h-j … are BUILT on `noise` being unrenderable, so the day it changes those rows
move too and this one is not the only warning."* It did, and they did, in one change.
The warning was load-bearing and it is kept, re-pointed at `sp`.

### ⚠ THREE FIXTURES MOVED WITHOUT THEIR ROWS MOVING

`em_bad_types`'s `emb` and `gp_types`' `gpc`/`gpd` each gained an entry-level
`results` key, because D30's new `badplotroute` refusal would otherwise have made
each of them answer **one error more than its row is about** — turning a row about
the field/slot contradiction into a test of two unrelated checks. That is issue
1430's own `em_bad_types` lesson, met a second time in the same file.

### ⚠ AND FOUR FIXTURES GAINED `save_all_v 1`, WHICH IS A DEFECT FIRING, NOT TIDINESS

`tf_lines`, `pz_lines`, `sens_lines` and `WKST2` all build on `nfet_state`, which
saves **one named output** and sets no blanket — exactly the bench shape measured
(fact 7) to make ngspice answer *"no data saved for \<analysis\>; analysis not run"*,
rc 1, for `tf`, `sens` and `noise` alike. **The decks those rows have been asserting
about could never have run.** `pz` is unaffected and its helper is corrected for the
`tf` row inside it, not for itself.

---

## What I did NOT ship, and why

* **Checkpointed salvage (6f) and the four variant mitigations (6g).** `render_deck`
  emits no `stop after`, no `resume`, no `delete all`, no `.ckpt`.
* **The precondition banner under the form**, deferred from Stage 4. The seven new
  sentences reach the user through the existing three tiers — the four-state grid,
  `ase::preflight_gate` and `render_deck`'s re-check — and nothing new is drawn.
* **Anything in `src/ase_window.tcl`.** The consequence is named rather than hidden:
  **`depends` has no surface.** `ase::ui::chana_field_row` renders `bool` and `mode`
  and falls through to an entry for everything else; it does not grey out a field
  whose gate is off. So `Report every N points` is **visible under Advanced whatever
  the checkbox says**, and the only thing that changes is whether it reaches the
  deck. A user can type a number into a box that does nothing, which is the shape
  issue 1418 deleted for `Options…` — it is **narrower** here (the field is real, the
  gate is real, only the greying is missing) and it is a surface change, which this
  task may not make. Recorded as the one follow-up worth a row.
* **A tooltip/`help` key.** `PLAN.md` §6d writes `help {…}` on both NOISE fields.
  Nothing in this tree reads a `help` key, so shipping one would be exactly the *"a
  key read by nothing is a key checked by nothing"* smell issue 1428's S35 named. The
  two sentences are in the registry's comments, where the next crew will find them.
* **A second results file for the `opinfo` companions** (`<cell>_ase.opinfo.raw`).
  That is issue 1430's C61 consequence and its ⚖ R9 design call; this commit routes
  all four companions to `results none` and says so per run, which is what makes the
  question askable.
* **`viewrank` for any of the three.** `noise` is the interesting case and the answer
  is the same as `tf`'s and `pz`'s and `sens`'s: `src/save.c`'s `read_dataset()` has
  a `noise spectral density curves` arm, so `xschem raw read <file> noise` **would**
  work for the spectrum — but the same function's `integrated noise` arm answers
  **`op`** unless a spectrum record preceded it, which is the driver's own addition
  to this brief and is a reader-side question ⚖ R3 owns. Left alone deliberately.
* **`seed_enabled`, anywhere.** Four seeded rows, 104 byte-identical `.state` files,
  section CP unmoved. That is now four commits in a row shipping ⚖ R4's recommended
  answer by construction.
* **Any change to `render_deck`'s print anchor, its `$sim_status` guard, its
  `remzerovec` placement or its `.save` cards.** Row WK7 asserts every one of them is
  still where issues 1243, 0964, 0929 and 0963 put it, and it is green.

---

## The sabotage table

**Fifty-one distinct respellings of `src/ase.tcl`**, each a plausible rewrite rather
than a break — the tidy-up somebody would actually make. Restore was `cp` from
`/tmp/mp6probe/good2/` with an `md5sum` compare after **every** one; **every restore
was verified before the next sabotage ran**, and the log records `RESTORED-OK` for
all fifty-one.

Counted by first attempt: **forty-eight reddened a named row**, **one survived**
(S32), **one could not be applied** (S24 — my own anchor was wrong, re-run as S24r),
and **not one killed a section**: `FATAL=0` on every line of the log, and the only
appearance of an unnamed sentinel row is **MP0 beside six named rows** in S47, where
the section's own `catch` caught a genuine raise that the named rows had already
reported.

⚠ **Each sabotage was run against the suites that should see it and no others**, so a
blank column below means "not run", never "green". The four suites were all run
together, green, before the campaign and again after it.

| # | the respelling | rows reddened |
|---|---|---|
| S01 | `noise_integrated` uses `PLAN.md` 6b's `start ne stop` | core **MP4** **MP4b** **MP7** · simcaps **NV1** **NV2** |
| S02 | `noise_integrated` drops the `lin` clause | core **MP4** **MP7** · simcaps **NV1** **NV2** |
| S03 | `noise_integrated` compares the frequencies as strings | core **MP4b** · simcaps **NV2** |
| S04 | `noise_integrated` is strict about an unreadable row | simcaps **NV2** |
| S05 | `noise`'s plots listed in CREATION order | core **MP4** **MP4b** **MP6** **MP17** **MP18** **MP19** |
| S06 | `noise`'s `select` literals lose their `*` | core **MP4** **MP4b** **MP6** **MP17** **MP18** |
| S07 | `disto`'s harmonic rows use `field` instead of `nofield` | core **MP5** **MP7** |
| S08 | `disto`'s IM rows listed in creation order | core **MP5** |
| S09 | `plot_when`'s `field` takes a blank string as present | core **MP2** |
| S10 | `plot_when`'s `hook` believes a non-boolean answer | core **MP3** |
| S11 | `plot_when_valid` accepts a three-element form | core **MP1** |
| S12 | `plot_when_valid` accepts the plan's `expr` form | core **GP2** **MP1** |
| S13 | `field_active` reads a bool gate through `field_emits` | core **MP9** **MP10** |
| S14 | `analysis_expand` checks `depends` after the default | core **SE2** **SE2b** **SE2c** **SE4** **SE4b** **MP9** **MP12** |
| S15 | `emit_check` demands a value for an inactive field | core **SE3** **MP11** |
| S16 | the `min` bound is deleted | core **MP11** |
| S17 | the `noplotresults` refusal is deleted | core **MP16** |
| S18 | the `opinfo`-route refusal is deleted | core **MP16** |
| S19 | the entry-`results` route refusal is deleted | core **MP16** **MP16b** |
| S20 | the `badplotwhenfield` refusal is deleted | core **MP16** |
| S21 | the `badplotwhenhook` refusal is deleted | core **MP16** |
| S22 | the `baddepends` refusal is deleted | core **MP16** |
| S23 | `fieldunused` stops exempting a gate | core **EM9** **CP5** **CP6** **GP1** **MP14** |
| S24r | `ac`'s and `pz`'s companions go back to `results viewer` | core **EM9** **CP5** **CP6** **GP1** **MP14** **MP15** |
| S25 | `plot_results` answers nothing | core **MP14** **MP15** |
| S26 | `sens` collapses to one plots row | core **SE8** · simcaps **SV5** |
| S27 | `sens_is_dc` reads the row instead of `field_value` | simcaps **NV3** |
| S28 | `sens` offers the broken `oct` sweep too | core **MP13** |
| S29 | `sens`'s AC fields lose their `depends` | core **SE2** **SE2b** **SE2c** **SE4** **SE4b** **MP11** **MP12** **MP13** |
| S30 | the contributor reader splits on the first `_` | simcaps **NV5** **NV7** **NV8** |
| S31 | the contributor reader stops excluding the circuit names | simcaps **NV6** **NV8** |
| S32 | the contributor reader stops trimming OSDI's trailing space | **NOTHING** *(survivor — see below)* |
| S33 | the contributor reader forgets the BSIM dot family | simcaps **NV7** |
| S34 | the contributor reader answers `{}` instead of `ambiguous` | simcaps **NV8** |
| S35 | `vecsaves` is dropped from `tf` and `sens` | preflight **PF230l** |
| S36 | `vecsaves` stops standing down for the op tier | preflight **PF230m** |
| S37 | `vecsaves` stops standing down for the verbatim hatch | preflight **PF230m** |
| S38 | `disto_saves` demands that EVERY save resolve | preflight **PF230g** |
| S39 | `disto_saves` becomes a `caution` | preflight **PF230g** **PF230i** |
| S40 | `disto_f1src` is deleted | preflight **PF230j** |
| S41 | `disto_f2src` fires whatever the mode | preflight **PF230j** |
| S42 | `noise_out` allows a current | preflight **PF230b** |
| S43 | `noise_insrc` only checks membership, not the AC value | preflight **PF230d** **PF230d2** |
| S44 | `noise_klu` is deleted | preflight **PF230e** |
| S45 | `sens_klu` fires in the DC mode too | preflight **PF229n** **PF230f** |
| S46 | the walk length comes from `analysis_plots` — **the over-walk** | core **WK5** **WK8** **MP7b** · optier **E5b** **E5c** |
| S47 | `noise` loses its `emitorder` | core **AG1** **AG2** **TF1** **PZ1** **SE1** **MP7** **MP0** |
| S48 | the `ptssum` slot is dropped from the template | core **EM9** **CP5** **CP6** **GP1** **MP9** **MP14** |
| S32r | the contributor reader stops trimming the NAME | simcaps **NV7** *(after the row was rewritten)* |
| S32s | ...and stops trimming inside the `v(…)` wrapper | simcaps **NV7** *(after the row was rewritten)* |

### The one that SURVIVED, and the dead line it found

**S32 deleted a `string trimright` written for OSDI's trailing space, and
`test_ase_simcaps_0948` stayed at ALL PASS (199).** The reason is better than a weak
fixture: **the line could never run.** `noise_contributor_kind` already trims the
name twice — once on the way in and once after the `v(…)` strip — so by the time the
instance-and-mechanism half is reached there is no trailing space left to remove. A
line whose comment claims to handle a case that another line has already handled is
not defended by a row; it is **deleted**, and it was.

⚠ **And then it took two more sabotages to give NV7 a fixture per trim.** Deleting
the FIRST trim also left the row green (S32r's first run), because the second takes a
leading space just as happily. The only input the first can take and the second
cannot is one whose whitespace sits **outside** a `v(…)` wrapper — the regexp is
anchored `^v\(`, so a leading space stops it matching at all. The row now carries
`" v(onoise_total_q1)"` and `"v(onoise_total_q1 )"`, one per trim, and **S32r and
S32s each redden it**.

⚠ **The lesson is not "the fixture was weak".** It is that *"a row whose fixtures
never disagree cannot fail"* has a sibling: **a row whose subject is implemented
twice cannot tell you which half works** — and the first thing it will find is that
one of the halves is dead.

### The one that could not be applied

**S24 named an anchor that was not in the file** (a line-continuation backslash I got
wrong when generating the patch), and the driver printed `PATCH-FAILED` and restored
before running anything. ⚠ **That is the driver doing its job and it is reported
rather than quietly re-run**: a sabotage campaign whose failures are invisible is a
campaign that measures fewer things than its table claims. Re-run as **S24r**, which
reddens six rows.

### The three rows that a sabotage proved were doing MORE than their own job

Not failures — findings about the shape of the suite.

* **S14** (drop the `depends` check) and **S29** (drop `sens`'s `depends` keys) both
  reddened **SE2 / SE2b / SE2c / SE4 / SE4b**, which are issue **1428**'s deck-line
  rows and know nothing about `depends`. They are right to redden: without the gate,
  a stored AC sweep leaks into the DC line as positional arguments. ⚠ **Stage 5's
  rows are what protect Stage 6d's byte-identity claim**, which is the best argument
  there is for keeping an old golden row rather than replacing it.
* **S23** and **S48** both reddened **EM9 / CP5 / CP6 / GP1** — a `fieldunused` error
  for `contributors` makes the whole registry's `analysis_schema_errors` non-empty,
  and four rows in three sections assert it is `{}`. ⚠ **The registry's
  self-consistency is asserted from four directions**, which is why a sabotage there
  is loud rather than quiet.
* **S45** reddened **PF229n** — issue 1428's `cider_klu` row — as well as its own
  **PF230f**. A `sens_klu` that fires in DC mode adds a second fatal to a deck that
  1428's row counts.

---

## What this stage learned that binds later ones

**A PLAN'S PREDICATE IS AS CHECKABLE AS ITS TABLE, AND THIS ONE WAS WRONG.** Issue
1430's closing lesson was *"measure the table, not only the conclusion"*, after
`PLAN.md` §6's `keepopinfo` list named `tf`. Twenty minutes of decks here found the
same file's **predicate** wrong: `when {expr {start ne stop}}` is false for
`noise … lin 1 1k 10k`, which has two different frequencies and one plot. ⚠ **The two
failures rhyme and the fix is the same**: every factual claim a plan makes about a
simulator is a deck you can run before you write a line of Tcl, and the ones that
sound most obviously true are the ones nobody runs.

**A REGISTRY THAT IS "IN THE OBVIOUS ORDER" IS IN THE WRONG ORDER.** Issue 1430's
`ase::analysis_plots` header says its answer is in *creation* order, which reads as
self-evidently right — the analysis's own plot first, then its companions. The walk
runs **backwards**, and reconciliation compares positionally, so the registry must be
in **write** order or every two-plot run reports `mislabel`. ⚠ **Nothing could have
caught this until a type captured two plots**, which is exactly what C64 said about
the walk itself. A comment describing an order that no fixture exercises is a claim
with no test behind it, and it sat there for one commit.

**THE ROW THAT WARNS YOU IT WILL MOVE IS WORTH MORE THAN THE ROW THAT DOES NOT.**
`test_ase_core`'s TF3b carries the sentence *"rows PF222a-e and PF222h-j … are BUILT
on `noise` being unrenderable, so the day it changes those rows move too and this one
is not the only warning."* It was written two commits before it was needed, it was
exactly right, and it turned what would have been eight mysterious reds in a second
file into a two-minute edit. ⚠ **When a row's fixture depends on a fact another
stage will change, name the other file in the comment.** It costs one sentence.

**AND THE ROW THAT NAMES ITS SUCCESSOR IS WORTH MORE STILL.** D7e3's comment says its
second unrenderable type is *"picked for DISTANCE rather than convenience"* and
predicts that when `pss` becomes renderable the row *"wants a FIXTURE backend rather
than a fourth shipped type"*. Two types are left. **The next stage that makes one of
them renderable should do what that comment says rather than moving the fixture a
fourth time.**

**A PRECONDITION FOUND THREE OF THIS SUITE'S OWN FIXTURES ASSERTING ABOUT DECKS
ngspice WOULD REFUSE.** `vecsaves` reddened `tf_lines`, `sens_lines` and `WKST2` the
moment it landed, and every one of them was right to redden: `nfet_state` saves one
named output and no blanket, which is measurably the configuration that makes
ngspice answer *"no data saved for \<analysis\>; analysis not run"*. ⚠ **A new
precondition reddening old rows is evidence, not collateral damage** — the rows had
been green about a deck that could not run. Read the reds before editing them away.

**A BOOL DOES NOT ANSWER `1`, AND THE FIRST CUT OF `depends` BELIEVED IT DID.**
`ase::field_emits` answers a bool with the adapter's `when_true` word (or the field's
own name) because **ngspice has no way to spell "off"** — a fact this tree measured
at issue 1417 and wrote into that proc's header. The gate compared its answer against
the `depends` value `1`, so `noise … contributors 1` rendered **without** its
argument: the checkbox on, the deck silent, rc 0. ⚠ **Caught by a row, in the first
run, because the row asserted the DECK LINE and not the predicate.** A row that had
asked `field_active` alone would have passed.

**WHEN A NEW REFUSAL LANDS, EVERY OLD FIXTURE BECOMES A CANDIDATE FOR ANSWERING TWICE.**
Three fixtures written for other refusals (`emb`, `gpc`, `gpd`) started answering
`badplotroute` as well, turning three single-subject rows into tests of two unrelated
checks. Issue 1430 met this once, with `em_bad_types`; it is not a one-off but the
standing cost of a validator that grows. ⚠ **A validator row's fixture must be valid
in every respect but the one it is about**, and that is a property to re-establish on
every commit that adds a refusal, not a thing to notice when the row reds.

**THE MEASUREMENT THAT DECIDED THE MOST HERE WAS AN ACCIDENT.** The first end-to-end
deck failed with `Error: no data saved for Noise analysis; analysis not run` — not
because anything in the registry was wrong, but because the probe state carried one
saved output, like every bench in this repository. That one rc 1 produced the
`vecsaves` precondition, three corrected fixtures, and a defect reaching back into
two Stage 5 entries that had shipped with it live. ⚠ **Run the thing end to end
before you believe the unit rows**, and when it fails for a reason you did not
predict, that reason is the finding.

**⚠ AND A WAITER THAT GREPS FOR ITS OWN COMMAND LINE STILL NEVER RETURNS.** Issue
1429's receipt closes on it; issue 1430's found one from the `sens` crew still
spinning after five and a half hours and reported it *"because a lesson written down
in a receipt is not the same as a lesson applied"*. This crew wrote one anyway —
`until ! pgrep -f 'nolog --script tests/headless/test_ase'` — and it hung for exactly
that reason, on the third try, after reading both receipts. It was killed and
replaced with a pattern the waiter cannot contain
(`pgrep -f '^timeout 400 \./src/xschem'`). **Three receipts is enough: the rule is
not "remember"; it is `pgrep -f` on a bare string is unusable from a shell, full
stop** — anchor it, or match a pid, or touch a marker file.

---

## Rulings

⚖ **R9 — nineteen new user-facing sentences, and no new surface.** Every one of them
reaches the user through machinery that already exists: the field labels through
`ase::ui::form_label`, the refusal clauses through `ase::analysis_emit_msg` and the
frame `ase::ui::chana_ok` already composes, the seven precondition sentences through
the four-state grid, `ase::preflight_gate` and `render_deck`'s re-check. **Nothing
new is drawn, so no `look` debt is filed.**

**The field labels (15).** NOISE: *Output*, *Input source*, *Sweep type*,
*Points per decade* / *Points per octave* / *Number of points (1 gives ONE point)*,
*Start frequency*, *Stop frequency*, *Per-device contributor table*,
*Report every N points*. DISTO: *Sweep type*, *Points per decade*, *Start frequency*,
*Stop frequency*, *F2/F1 ratio (switches to intermodulation)*. SENS: *Mode*,
*Sweep type*, *Points per decade*, *Start frequency*, *Stop frequency*.

⚠ **Two of those are doing work and are worth the user's eye.**
*`Number of points (1 gives ONE point)`* is the `lin` relabel, and it exists because
a `lin 1` noise run silently loses its integrated-noise scalars — the form is the only
place that can be said before the run. And *`F2/F1 ratio (switches to
intermodulation)`* names a **mode switch disguised as a number**: setting it changes
which three plots the analysis produces, and `dsetparm.c:60-63` is where one field
sets two things.

**One new refusal clause.** `belowmin` → *"needs '\<field\>' to be at least N"*.

**Seven precondition sentences**, each with its fix:

1. `noise_out` (current) — *"a noise analysis measures a VOLTAGE, and 'i(V1)' is a
   current"* → *"name a node, as `v(out)` or `v(out,ref)`"*.
2. `noise_out` (missing node) — *"this circuit has no 'x' for the noise analysis to
   measure, and ngspice answers a missing node with a full spectrum of numbers rather
   than failing"* → *"name a node this netlist has"*.
3. `noise_insrc` — three: *"'V2' carries no AC value, and a noise analysis is referred
   to its input source's AC magnitude"*; *"'R1' is not an independent source, and
   noise can only be referred to one"*; *"this circuit has no 'Vnope' to refer the
   noise to"*.
4. `noise_klu` — *"ngspice does not support noise analysis under the KLU solver"* →
   *"select the `sparse` solver for this run"*.
5. `sens_klu` — *"AC sensitivity crashes ngspice outright under the KLU solver — the
   process dies and nothing is written"* → *"select the `sparse` solver for this run,
   or use the DC mode, which is safe under KLU"*.
6. `disto_saves` — *"every saved output names something this circuit does not have …
   and a distortion analysis does not fail on that — ngspice SEGFAULTS, so there is no
   exit status, no log and no results file to explain it"* → *"correct the output
   names, or tick Save all voltages, or switch the distortion analysis off"*.
7. `disto_f1src` / `disto_f2src` — *"no source in this circuit carries a `distof1`
   excitation, and a distortion analysis without one runs to completion and answers
   zeros"* → *"add `distof1 <mag> <phase>` to the input source (phase is in DEGREES)"*;
   and *"this row asks for intermodulation, which needs a second excitation, and no
   source in this circuit carries a `distof2`"*.
8. `vecsaves` — *"this bench saves N named outputs and nothing else, and a \<type\>
   analysis answers in vectors that are not netlist names — ngspice refuses to run it
   at all and every analysis after it in the deck is abandoned with it"* → *"tick Save
   all voltages, or clear the per-output Save ticks so the deck carries no save
   list"*.

Recorded as `owed.sh add rule 1432` at the moment it was incurred, pointing at the
issue file. **Batch with 1426, 1427, 1428, 1429 and 1430, which are all still
waiting**, per ⚖ R9 and the standing one-question-at-a-time preference.

⚠ **THE LEDGER WAS BACKED UP FIRST**, per `CLAUDE.md`'s one-ledger-every-clone
paragraph, to `/tmp/mp6probe/owed_backup_20260912_190144` (**150 rule / 56 look /
9 suite** at the time). The new entry is stamped `repo:/home/analog/dev/xschem-claude`.

⚠ **AND THE FOUR UNSTAMPED ENTRIES ARE STILL THERE, UNTOUCHED.** Measured again
2026-09-12 19:01, before the `add`:

```
/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*
  ->  rule/1357   rule/1357@xschem-claude
      look/hier_pdf_nav_1357_H6.1789071932.2875683
      suite/test_hier_pdf_links_1333
```

Identical to what issue 1430's crew found, which is the point: **nothing has cleared
them and nothing has claimed them**, and a rule debt clears only when the user says
so. The two `rule/1357` entries still point at two different issue files — issue
**1400**'s collision, standing in the ledger itself.

**No `look` debt.** `src/ase_window.tcl` is untouched and nothing new is drawn.

**⚠ One `look`-shaped thing that is NOT a `look` debt, and is named rather than
filed:** `depends` has no surface (see *What I did NOT ship*). A user sees *Report
every N points* under Advanced whether or not the contributor checkbox is on. That is
a **defect to fix in `ase_window.tcl`**, not a pixel deliverable to inspect, so it
belongs in the next window stage's list and not on the user's queue.

---

## For the driver

* T1 was **not** run by this crew (issue 0990 — the driver runs it solo).
* **Nothing was committed, added, stashed, restored or cleaned.** No `git checkout --`,
  no `git restore`, no `git stash`, no `git clean`, no `git push`.
* `NUMBERING.md`'s pointer was advanced **1432 → 1433** in the same change as the
  entry. Both mint checks were run at the moment of minting: the reserved-band scan
  over this clone's head table (**silent** for 1432) and
  `ls ~/dev/*/doc/claude/issues/1432-*` plus `/usr/bin/grep -lw 1432` across every
  clone's `NUMBERING.md` (only this clone's own pointer line).
* ✅ **All four suites this task moves ARE in `tests/run_regression.tcl`.** Nothing
  here is outside T1's reach; issue 1421's twenty-one unreachable `test_ase_*` suites
  are all unmoved.
* **Both binaries were exercised end to end**, through ASE-L's own `render_deck`, in
  a scratch directory under `/tmp`: the fork
  (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+`) and
  `/usr/bin/ngspice` (`ngspice-45.2`). Four decks each, byte-identical sidecars and
  `Plotname:` lists on both, `ase::reconcile_plots` answering `ok` 5/5/5, and **no
  `constants` record in any of the eight results files**. **Nothing under
  `~/.xschem/` was touched and no bench under `sky130A/` was run**; every xschem
  invocation was given a path (`./src/xschem`) and `--nolog`, never `--logdir`,
  never a bare `xschem`.
* ⚠ **THE USER'S WINDOWS X SERVER WENT AWAY MID-SESSION, AND `xschem` HANGS RATHER
  THAN FAILING WHEN IT DOES.** `$DISPLAY` is `172.20.160.1:0` (the TCP server, per
  `CLAUDE.md`'s three-server table), and when it stopped answering, **`./src/xschem
  --version` hung with no output at all** — not `--nogui`, not `--pipe`: the bare
  version query. It cost several minutes of hunting a defect in this commit's own
  `src/ase.tcl`, including a pointless revert to the pristine copy, before
  `env -u DISPLAY ./src/xschem --version` answered instantly. `CLAUDE.md` records
  the shape for `xdpyinfo` (*"against a dead display HANGS on the TCP fallback rather
  than failing"*); **it is true of `xschem` itself and of every arg, and the tell is
  that the run produces NOTHING — not even the `XSCHEM_SHAREDIR` line.** Everything
  after that point was run on the persistent dev display (`DISPLAY=:99`,
  `devdisplay.sh status` → alive, openbox, 1920x1080x24), which is what `CLAUDE.md`
  recommends anyway.
* **The whole ASE family (29 suites) was re-run headless**, every run `timeout
  400`-bounded: **27/27 passed, 2 self-skipped** (`test_ase_dirty` and
  `test_ase_log_seam_0207`, both of which need an X connection and say so in their
  own first line). `test_ase_core` **476**, `test_ase_preflight` **210**,
  `test_ase_simcaps_0948` **199**, `test_ase_optier_0963` **106**, `test_ase_cosim`
  **341** (unmoved). The four suites this commit moves were re-run again, green,
  after the sabotage campaign and after the registry's own documentation went in.
* **The display arm** was taken through `run_suites.sh` (`SUITE_TIMEOUT=400`),
  attached to the persistent dev display `:99`: **4/4 runs passed**, with
  `test_ase_optier_0963` run separately and TIMING OUT as it has for every crew
  since Stage 5.
* ⚠ **THE DISPLAY ARM WROTE `~/.xschem/geometry`, AND IT IS REPORTED RATHER THAN
  LEFT FOR SOMEONE TO FIND.** The standing rule is *never touch anything under
  `~/.xschem/`*, and every one of this crew's own invocations honoured it: `--nogui
  --pipe -q --nolog`, a path to the binary, a scratch `rundir` under `/tmp`, no bench
  under `sky130A/`. But the display arm goes through `tests/headless/run_suites.sh`,
  which this batch's brief and `CLAUDE.md` both name as the right entry point, and
  which launches xschem **without** `--nogui` — so a real window opens and xschem
  saves its size to `~/.xschem/geometry` on exit. Measured by timestamp:
  `geometry` is stamped **19:49:00**, inside the `test_ase_optier_0963` display run
  (started ~19:49, timed out 19:55:39); the other four display runs finished at
  19:38:39.
  ⚠ **Nothing of the user's was destroyed** — `geometry` is window sizes, rewritten
  by every xschem the user starts, and it is neither `recent_files` (issue 0924) nor
  `simulations` (the `ase_l_ux_batch` incident). **But no receipt in this batch has
  recorded that the armed display path writes there at all**, and a rule stated as
  absolute deserves to have its one measured exception written down rather than
  quietly tolerated. Whoever owns the harness should decide whether
  `run_suites.sh` ought to give its arm a scratch `HOME` the way issue 1397 gave one
  to the suites themselves.
* ⚠ **A sabotage campaign of fifty-one respellings ran against the working tree**,
  and `src/ase.tcl`'s md5 was compared against the pristine copy after every one.
  The tree is at the pristine md5 now.
* ⚠ **`test_cosim_golden_e2e`'s ONE KNOWN RED (row GE24, issue 1431) was not
  re-measured by this crew and nothing here touches co-simulation.** It is not in
  `run_regression.tcl`. `test_ase_cosim` is ALL PASS (341) before and after.
