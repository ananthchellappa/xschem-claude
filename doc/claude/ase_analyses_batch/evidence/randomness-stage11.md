# Randomness and seeding, measured on both binaries — before Stage 11 opens

Taken by the driver on **2026-09-13** while the crews held the code. Both binaries:
`/usr/bin/ngspice` (**45.2**) and `/home/analog/dev/ngspice/build-ver_50/src/ngspice`
(**46+**). Stage 11 is *Campaigns: sweeps, corners, Monte Carlo*, and ⚖ R8 has just ruled
that a campaign lives **in the state file**, so how the simulator draws its numbers is now
load-bearing for a feature the user can save, reopen and expect to reproduce.

## 1. ⚠ THE TWO RANDOM SOURCES BEHAVE DIFFERENTLY WHEN UNSEEDED

There are two places to ask ngspice for a random number, and they do **not** agree about
what "no seed" means.

**Netlist level** — `.param rv = agauss(1000, 100, 1)` on a resistor, `op`, read the current:

| run | 45.2 | the fork |
|---|---|---|
| unseeded, run 1 | `-1.05875e-03` | `-9.22535e-04` |
| unseeded, run 2 | `-1.10036e-03` | `-9.03344e-04` |

Different every run, which is what anyone would expect.

**Interpreter level** — `let c = sgauss(0)` / `let d = sunif(0)` inside `.control`:

| run | 45.2 | the fork |
|---|---|---|
| unseeded, run 1 | `c = -1.13966e+00`, `d = -6.17854e-01` | identical |
| unseeded, run 2 | `c = -1.13966e+00`, `d = -6.17854e-01` | identical |

**Identical every run, and identical across the two binaries.** The interpreter's generator
starts from a fixed default state.

⚠ **So a Monte Carlo loop written with `sgauss` in a `.control` block and no seed draws the
SAME SAMPLE every time** — a run that completes, produces a plausible spread of numbers and
is the same spread it produced yesterday. That is this batch's recurring failure shape (*a
thing that cannot disagree*) wearing a statistician's hat, and nothing in the output says so.
Whatever Stage 11 emits must set a seed **explicitly**, including when the user asked for
"random".

## 2. `.options seed=<n>` makes BOTH reproducible, and agrees ACROSS the two binaries

| seed | netlist `agauss` draw | interpreter `sgauss` / `sunif` |
|---|---|---|
| `seed=7` | `-1.10275e-03` on **both** binaries, both runs | `-9.31720e-01` / `-8.01086e-01` on **both** |
| `seed=9` | `-9.94406e-04` on **both** binaries | — |

Two runs of the same seed agree; two different seeds disagree; and **45.2 and the fork
produce the same numbers for the same seed**.

That is worth more than it looks: **a seeded campaign can have a committed golden**, and the
golden will hold across both binaries this batch verifies against. An unseeded one cannot.

⚠ **AND IT DOES NOT REACH `trnoise`.** Measured separately, three runs per binary with
`.options seed=5`: a `trrandom` source gives `1.031261e+00` every time on both binaries, and
a `trnoise` source gives **a different number every single run**, on both. The seed governs
`agauss`, `sgauss`/`sunif` and `trrandom`; `trnoise` is outside it. Full measurement and the
consequences for Stage 13's goldens: `evidence/events-and-trnoise.md` Part 2.

⚠ The measurement is two versions on one platform, one distribution, one draw. It is not a
promise about every ngspice ever built — Stage 11 should pin the seed in its own fixtures
rather than rely on the agreement continuing.

## 3. What is NOT available where you might reach for it

* `agauss(...)` and `unif(...)` are **netlist** functions, not interpreter ones. In a
  `.control` block they fail: `Error: no function as agauss with that arity.` followed by
  `Error: RHS "agauss(1,0.1,1)" invalid`. The interpreter's spellings are `sgauss(0)` and
  `sunif(0)`.
* **`seedinfo` is not a command**: `seedinfo: no such command available in ngspice` on 45.2.
  The catalogue's `seedinfo` row is a **`set` variable**, not a command, and any UI text that
  implies otherwise is wrong.

## 4. What this says about ⚖ R4's constraint

R4's batch non-negotiable is that **no new analysis type gains a `seed_enabled` key**.
Nothing here argues against it: seeding is a **deck option** (`.options seed=`), already one
of the 247 rows in the options catalogue, and it applies to the whole run rather than to one
analysis. A per-analysis seed key would be a second way to say a thing the sheet already
says, and the two would disagree the first time a user set both.

---

## ⚠ THE SEED IS A COMMAND, AND THE VARIABLE THAT LOOKS LIKE THE SEED IS A READBACK

**Measured 2026-09-13 by the driver**, on **both** binaries, one deck —
`v1 1 0 trrandom(2 1m 0 1)` into 1 kΩ, `tran 1m 5m`, reading `v(1)` at the second time point.

| what was in the `.control` block | run 1 | run 2 | reproducible? |
|---|---|---|---|
| nothing | `-5.06766e-01` | `-8.24668e-01` | **no** — as expected |
| `set rndseed=12345` | `7.059813e-01` | `1.035454e-02` | ⚠ **NO** |
| **`setseed 12345`** | `3.950885e-01` | `3.950885e-01` | ✅ **yes** |
| `setseed 12345` **in `<rundir>/.spiceinit`** | `1.164426e+00` | `3.497468e-01` | ⚠ **NO** |

**And `setseed 12345` gives `3.950885e-01` on `/usr/bin/ngspice` (45.2) as well** — the same value,
to every digit, on both binaries and on every run.

### ⚠ AND WHERE YOU PUT IT DECIDES WHETHER IT WORKS — added 2026-09-13, after Stage 11 task 1

The row above was measured with `setseed` **inside the `.control` block**, and there it works. **In
`<rundir>/.spiceinit` it does nothing** — rc 0, silent, a different answer every run, on both
binaries. Driver-re-measured against the same deck: `.spiceinit` gives `1.164426e+00` then
`3.497468e-01`; the identical command in `.control` gives `3.950885e-01` twice.

The mechanism is an ordering one and it is not guessable from the outside: `main.c` reads the
start-up file at `:1266-1330` and **then** calls `initw()` at `:1371`, which does
`srand(getpid())`. **The start-up file's seed is set and then overwritten before the circuit
runs.**

⚠ **So this is the SIXTH *accepted-is-not-honoured* case**, and the sharpest of them for a reader
of this file: the first table says *"`setseed` works"*, and that sentence is true in one place and
false in another with no diagnostic to tell them apart. **A campaign that seeds from `.spiceinit`
is unseeded and cannot know it.**

### Why `set rndseed=` looks right and is not

`rndseed` is a variable ngspice **writes**, not one it reads: `src/frontend/inp.c:455` and `:465`
call `cp_vset("rndseed", CP_NUM, &rseed)` to **report** the seed it chose. The mechanism that
*sets* one is the `setseed` **command** (`src/frontend/commands.c:204`, `com_sseed`).

So `set rndseed=12345` is a perfectly-formed line that assigns to a readback channel, is accepted
without complaint, and changes nothing about the numbers. **That is the batch's
*accepted-is-not-honoured* class again** — the fifth case, and the only one so far with a correct
alternative sitting next to it.

### What this buys Stage 11, which is more than it looks

* **A Monte Carlo campaign can be made exactly reproducible** — `setseed <n>` per shard, emitted in
  the `.control` block. A user can re-run a corner that failed and get *the same* failure.
* **Reproducible ACROSS BUILDS.** The same seed gives the same numbers on 45.2 and on the fork,
  which is unusual in this evidence base (see `evidence/binary-differences.md`, where a transient's
  very point count differs) and means a campaign's results can be compared between binaries.
* ⚠ **It does not weaken the batch's rule that no new analysis type gets a `seed_enabled` field.**
  The opposite: the seed is a property of a **campaign**, emitted once as a command, not a
  per-analysis checkbox. This measurement says where it belongs rather than that it should exist
  per row.

**Not measured:** whether `setseed` reaches `trnoise` and the `.model` statistical distributions as
well as `trrandom`, and what `setseed` with no argument does. Both are one deck each when Stage 11
is picked up.
