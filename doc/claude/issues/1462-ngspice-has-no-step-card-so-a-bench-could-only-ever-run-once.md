# 1462 — ngspice has no `.step` card, so a bench could only ever run once

**Stage 11 task 1 of two — the campaign RUNNER (§11a) and the SAMPLER (§11b).**
`doc/claude/ase_analyses_batch/PLAN.md` §11, `APPENDIX_ngspice_analyses.md` §4.
⚖ **R8** (the campaign lives in the simulation state) and ⚖ **R2** (per-run
`<rundir>/.spiceinit`, four conditions) are both **answered**.

Files: `src/ase.tcl`, `tests/headless/test_ase_campaign_1462.tcl` (new),
`tests/headless/test_ase_core.tcl`, `tests/headless/test_ase_persist.tcl`,
`tests/run_regression.tcl`, `doc/claude/issues/NUMBERING.md`.
**`src/ase_window.tcl` was not opened for writing** — the campaign editor, the
progress readout and §11c's result table are task 2.

## What goes wrong for the user

`grep -rn '"\.step"' src/frontend/ src/spicelib/parser/` in the ngspice tree
returns nothing, and `.step param x 1 3 1` answers `unimplemented dot command
'.step'` and **aborts the run**. There is no corner statement, no `.MC` card, no
sort, no median, no percentile and no histogram. A parameter sweep, a corner set
and a Monte Carlo run are all the GUI's to generate — and ASE-L generated none of
them. The user's own `tb_bandgap` bench carries

    {name VCCGAUSS value {agauss(1.8, 'ABSVAR', 1)}}

in its `variables` — a Monte Carlo distribution written by hand — and ASE-L ran
it **once**.

## What shipped

A `sweep` state key (⚖ R8 Option A, the one named exception to D3, in
`ase::omit_if_empty` so all 104 committed `.state` files still round-trip
byte-identically and `version` stays 1), a Tcl sampler, an odometer over the
axes, a shard directory with one process per point, and `index.tsv` with one row
per point — **run or not**.

**The one idea: a shard is a STATE.** This point's coordinates are written into
the state keys they belong in — a design variable into `variables`, a temperature
into `temperature`, a corner into the `models` row it re-sections, the per-shard
seed into `options` — and `rundir` is pointed at the shard directory. The shard's
deck is `render_deck` of that state, so every guard, refusal, sidecar path and
measurement rides along and there is no second deck writer.

## ⚠ The measurement that reshaped the plan: `var()` kills apt 45.2

`PLAN.md` §11a ranks first a mechanism that makes the deck **byte-identical for
every shard**: `.param rv='var(myres)'` in the deck plus `set myres=4700` in the
shard's `.spiceinit`. Measured 2026-09-13 on both binaries:

| binary | answer |
|---|---|
| fork (`ngspice-46+`) | `@r1[resistance] = 4.700000e+03` |
| **apt 45.2** (`/usr/bin/ngspice`) | `Undefined parameter [var]` → `Expression err: var(myres)` → `Formula() error.` → **`ERROR: fatal error in ngspice, exit(1)`** |

`var()` and `vec()` were added upstream in `aa1242ac7` on **2025-10-16**, **50
commits after `ngspice-45.2`**, and first shipped in ngspice-46
(`git tag --contains` → `ngspice-46`). **The current Ubuntu LTS ships 45.2**, so
the plan's first-ranked mechanism is unavailable on the binary most users have
and asking for it does not degrade — it kills the run. Every axis therefore
re-renders the shard's own deck, or delivers its point with `alter`; no capability
probe is needed because nothing emits `var()`.

The replacement is honest and arguably better: `campaign/deck.spice` is the
**nominal** deck and `diff campaign/deck.spice shard-0007/deck.spice` is exactly
what is different about point 7. The variation is visible rather than hidden in a
sidecar.

## ⚠ The sixth *accepted-is-not-honoured* case: `setseed` in `.spiceinit`

Measured on both binaries, rc 0, nothing on either stream, and a **different
number every run** — indistinguishable from no seed at all:

| what was in `<rundir>/.spiceinit` | run 1 | run 2 |
|---|---|---|
| `setseed 12345`, apt 45.2 | `-1.52995e+00` | `6.545672e-01` |
| `setseed 12345`, fork | `-2.46074e+00` | `7.316806e-01` |
| *(the same line inside `.control`)* | `3.950885e-01` | `3.950885e-01` |

`main.c` reads the start-up file at `:1266-1330` and calls `initw()` —
`srand((unsigned int) getpid()); TausSeed();`, `wallace.c:76-86` — at **`:1371`**,
after it. A seed set at start-up is destroyed before the netlist is read.

## ⚠ And the seed the plan forbids is the right one **for a shard runner**

`APPENDIX` §4.4 Trap B: never emit `.option seed=<n>` for a statistical campaign,
because `eval_opt()` re-seeds on **every** re-parse, so a `.control` loop that
`reset`s draws the same sample every time. **A shard runner never `reset`s** —
each point is its own process with its own deck and its own seed. Measured with
seeds 7/8/9 on both binaries, one deck carrying a netlist-level `agauss` **and**
an interpreter-level `sgauss`:

| seed | `@r1[resistance]` | `sgauss(0)` |
|---|---|---|
| 7 | `9.068280e+02` | `-9.31720e-01` |
| 8 | `1.056375e+03` | `5.637512e-01` |
| 9 | `1.005625e+03` | `5.625111e-02` |

identical on a second run and **identical on the other binary**. `setseed` cannot
do this job: with `setseed 12345` in `.control` the interpreter's draw is fixed at
`3.950885e-01` while the **netlist's** `agauss` answers `1053.4` / `853.9` /
`995.4` on three consecutive runs, because a netlist-level draw happens at
**parse** time. The user's own bench is exactly that case.

So the campaign sets `.options seed=<base+N>` per shard, through the option row
`seed` the catalogue already declares — no new emit site, and "re-run just point
17" gives point 17's answer.

## ⚠ And ASE-L draws the samples, in Tcl (§11b)

Not `agauss` in the netlist and not `sgauss` in the control language. The
measured case: the two seeding traps above, issue **0210**'s model-level draw
*proven* to change between runs of the same migrated state, and the Wallace pool's
`getpid()` seeding of transient white and 1/f noise. When ASE-L draws, the sample
set is reproducible, inspectable, exportable, re-runnable point by point and **a
column in `index.tsv`**. *ADE-L cannot show you its samples.*

The generator is Park–Miller (`s ← 16807·s mod 2147483647`) — exact 64-bit integer
arithmetic, so the stream is identical on every platform and every Tcl build —
warmed up ten steps, with Box–Muller for the gaussian and six significant digits
on every sample so a golden is portable. Distribution names are **neutral**
(`normal`, `uniform`, `bounded`), because `agauss`/`gauss`/`aunif`/`unif`/`limit`
are ngspice's spellings and D34 keeps those out of core; all five map onto the
three.

## ⚠ AND THE ONE T1 FOUND: A CAMPAIGN IS NOT A FOURTH RUN DOOR

The first version of `ase::campaign_step` composed the command and `exec`ed it,
and `ase::campaign_run` applied the session's simulator choice with a second
`ase::sim_apply_choice`. Row **S12** of `test_ase_simreg_0931` is STRUCTURAL and
counts those calls: it asserts there is exactly **one**, in `ase::run_deck`,
between the in-flight refusal and the first resolver, *"because two calls would
say the stale-entry sentence twice for one gesture."* It went `{2 0}` against
`{1 1}`.

**The requirement was right and the fix was in the wrong place.** Every shard now
goes through `ase::run_deck` — the body `ase::run`, `ase::run_existing` and a
script paste already share — so the choice is applied once, structurally, and the
campaign needs no call of its own. `campaign_step` got *smaller*: it no longer
composes a command, `exec`s, writes a log, deletes the five append-target
sidecars, writes the ⚖ R2 pre-deck file, or takes the run lock. **A shard
directory is now literally a run directory**, holding `<cell>.spice`,
`<cell>_ase.spice`, `<cell>_ase.log`, `<cell>_ase.raw` and `<cell>_ase.plotmap`
under the names a single run gives them.

Three things that repair measured:

* **`ase::wait` is an unbounded `vwait`.** A single run's is bounded by the
  user's Stop button; a campaign's is not. `ase::campaign_wait` races it against
  an `after`, kills the overrunning process by the id the campaign started, and
  returns **124**.
* **A killed shard strands its in-flight lock**, because `ase::run_done` clears
  it on EOF and a killed process whose child holds the pipe never delivers one —
  so the next campaign over the same directory was refused by a run nobody was
  waiting for.
* ⚠ **A binary that never answers the capability probe pays `cap_budget_ms`
  (30 s) per shard**, because a timed-out probe is not cached. Measured: 31,296 ms
  for the probe, 64,420 ms for a two-point campaign with a one-second shard
  budget.

## Two defects this suite found rather than was written for

1. **A campaign ran whichever simulator was last *selected*, not the one the
   bench names.** Every shard resolves through `run_cmd`, which asks the
   process-global selection; with two ASE-L windows open that cache holds the
   other bench's answer. `ase::run_deck` already calls `ase::sim_apply_choice` for
   the 2026-09-08 ruling; `ase::campaign_run` did not. Row **RN12**.
2. **A stopped campaign left directories for points that never ran.**
   `ase::rundir` **creates** the directory it is asked about, and every sidecar
   path resolves through it — so asking a never-run shard for its rawfile path
   silently made the shard directory. A campaign stopped after two of four points
   left four directories, two of them empty and indistinguishable from a run that
   produced nothing. Row **RN8b**.

## What the runner says, once, before it starts

`ase::campaign_notes` mints the point/axis/mode sentence, the collapsibility
sentence (§11a: *"the runner SAYS which mode it chose"*), the seed sentence and
the adapter's two seed caveats. **`collapsible` is computed and reported, not
taken**: collapsing N points into one process means emitting `render_deck`'s
`.control` body N times, and a second emitter for it would be the **ninth** copy
of "what a `dc` analysis is" (`PLAN.md` §0.3) — the defect this batch exists to
remove. The decision ships with its inputs measured; the day `render_deck` can
repeat its own body, the mode has a caller.

## Suites

`test_ase_campaign_1462` **NEW, 133 checks, both arms, identical rows**
(`diff` of the two ok-lists empty). `test_ase_core` **638 → 638** and
`test_ase_persist` **49 → 49** — no row count moved; the schema-key expectation
moved from 22 to 23 in **both** copies of that list (receipt 36's correction C7
predicted the second copy, and it was still there).

104 committed `.state` files round-trip byte-identically, 0 mismatches, measured
live through `ase::state_load` → `ase::state_serialize`, **with a non-vacuity
control in the same loop**: one file given a non-empty `sweep` re-serializes
differently.
