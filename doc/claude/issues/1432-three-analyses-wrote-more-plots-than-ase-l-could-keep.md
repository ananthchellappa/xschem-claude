# 1432 — three analyses wrote more plots than ASE-L could keep, and one of them crashed the simulator

**Stage 6d of `doc/claude/ase_analyses_batch/`**, the fourth commit of Stage 6 and
the last of the writer chain: **1429** is ⚖ R3's reader seam, **1430** the writer,
the plot sidecar and reconciliation, and this is the three types that make the
writer necessary. Stage 5 is 1426 (`tf`), 1427 (`pz`), 1428 (`sens`, DC only).

## The defect

`noise`, `disto` and `sens`'s **AC** mode were registered **probe-only**: listed in
*Choose Analyses* so the user could see they exist, with no fields, no `emit` and no
way to run them. Everything about them a user would want was unreachable.

Three of them are also the only types in ngspice that write **more than one plot per
analysis**, which is what issue 1430 built the `setplot previous` walk for — and that
walk shipped **with no production exerciser**, by its own correction C64, because
every type in the registry as it stood captured exactly one plot.

## Four measured facts the plan got wrong

All measured 2026-09-12 on the fork (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`,
`ngspice-46+`) **and** on `/usr/bin/ngspice` (`ngspice-45.2`), identically on both.

**1. `PLAN.md` 6b's predicate for `Integrated Noise` is wrong, in the direction that
corrupts the results file.** The plan writes `when {expr {start ne stop}}`:

```
noise v(mid) v1 lin 1 1k 10k   -> ONE plot    <- start NE stop
noise v(mid) v1 lin 5 1k 1k    -> ONE plot
noise v(mid) v1 dec 10 1k 1k   -> ONE plot
noise v(mid) v1 lin 2 1k 10k   -> TWO plots
noise v(mid) v1 dec 1 1000 1001-> TWO plots
```

The rule is *more than one frequency point*, and it has two ways of being one:
`noisean.c:93-109` collapses start ≈ stop, and `:145-168`'s LINEAR arm divides by
`N-1`. Had the plan's predicate shipped, every `noise … lin 1` run would have
declared one capture too many — and **an over-walk is silent**: `setplot previous`
saturates on the built-in `constants` plot and the next `write` appends ngspice's
twelve mathematical constants at rc 0, with only a stderr warning.

**2. `.options sqrnoise` RENAMES BOTH NOISE PLOTS**, so an exact `select` literal
would report `mislabel` on every such run:

```
Noise Spectral Density Curves  ->  ... - (V^2 or A^2)/Hz
Integrated Noise               ->  ... - V^2 or A^2
```

**3. `sens … ac oct` is broken as well as `sens … ac lin`, and nobody had measured
it.** `count_steps`' OCTAVE arm (`cktsens.c:862-900`) divides by `M_LOG2E`
(log₂e = 1.4427) where an octave count needs `M_LN2` (0.6931), so it produces 48 % of
the points asked for:

```
sens v(mid) r1 ac oct 2 1k 4k  ->  TWO points (1000, 1414)   [ac oct 2 1k 4k: five]
sens v(mid) r1 ac oct 4 1k 2k  ->  TWO points                [ac: five]
sens v(mid) r1 ac oct 1 1k 4k  ->  ONE point                 [ac: three]
sens v(mid) r1 ac dec N …      ->  matches `ac dec N` exactly
```

Receipt 12 recommended `values {dec oct}`; the field declares **`values {dec}`**.

**4. The contributor-table names live in a different plot from the one the appendix
gives.** `APPENDIX §2.6` names them `onoise_total_<inst>_<mech>` while `§6.2` routes
the table to *inside the spectrum plot*. Both spellings are real, in different plots
(`cktnoise.c`, `resnoise.c:68-82`): `N_DENS` builds `onoise_%s%s`, `INT_NOIZ` builds
`onoise_total_%s%s`. And **`onoise_spectrum` has exactly the shape of a device
total**, so a reader splitting on the first `_` counts the circuit as a device and
doubles the table's sum — a fifth naming hazard beside the three the appendix lists.

## Two defects this put in a user's reach

**`disto` SEGFAULTS when its save list resolves to nothing**, through ASE-L's own
deck shape — `.save` dot cards above `.control`, which is what an Outputs row emits:

```
.save v(nosuchnode)                     + disto -> rc 139, SIGSEGV, both binaries
.save v(nosuchnode) / .save v(alsonone) + disto -> rc 139
.save v(mid) / .save v(nosuchnode)      + disto -> rc 0
.save all / .save v(nosuchnode)         + disto -> rc 0
no save card at all                     + disto -> rc 0
```

The trigger is the **whole list** resolving to nothing, so `design-C`'s proposed
refusal (*`disto` enabled AND zero saved outputs*) would refuse a deck that runs.

**And `noise`, `tf` and `sens` are starved by an ordinary bench.** `APPENDIX §7.5.2`
assigns this to "Stage 6's precondition" by name: an analysis whose result vectors
are not netlist names cannot run under a save list made of netlist names.

```
.save v(mid) + noise / tf / sens -> rc 1, `Error: no data saved for <analysis>;
                                    analysis not run`, $sim_status 1
.save all    + the same          -> rc 0
```

**One ticked output is enough**, which is the shape of every committed bench — three
of this tree's own test fixtures were rendering decks ngspice would have refused.

## What shipped

Registry entries for `noise` (8 fields, 3 plots), `disto` (5 fields, 6 plots) and
`sens`'s AC mode (4 more fields, a second plots row). Core gains three `when` forms
(`field`, `nofield`, `hook`), the `depends` field gate, a `min` bound, D30's
per-plot `results` as a **load-time refusal**, and `ase::plot_results`. The adapter
gains `noise_integrated`, `noise_total_vectors`, `noise_contributor_kind`,
`sens_is_dc`/`sens_is_ac` and seven preconditions.

**⚠ `role opinfo` plots route to `none`.** Issue 1430's C61 measured that the deck
cannot capture them at all — `src/save.c`'s `read_dataset()` matches
`strstr(lowerline, "operating point")` before its AC arm — so declaring them
`viewer` would be the registry asserting a route that does not exist.

**⚠ The registry lists a multi-plot type's plots in WRITE order, which is REVERSE
creation order.** The walk runs backwards and `ase::reconcile_plots` compares its
prediction positionally against a write-ordered sidecar, so a registry in creation
order would mislabel every two-plot run. That refutes `ase::analysis_plots`' own
header as issue 1430 left it.

## Verified

End to end through `ase::backend::ngspice::render_deck`, four decks, **both
binaries**, byte-identical sidecars and `Plotname:` lists on each:
`ok`, 5 / 5 / 5, nothing said, and **no `constants` record in any results file**.

Suites: `test_ase_core` 453 → **475** · `test_ase_preflight` 194 → **210** ·
`test_ase_simcaps_0948` 190 → **199** · `test_ase_optier_0963` 105 → **106**.

Receipt: `doc/claude/ase_analyses_batch/receipts/15-stage-6-multiplot.md`.
