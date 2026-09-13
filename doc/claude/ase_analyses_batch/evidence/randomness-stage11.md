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
