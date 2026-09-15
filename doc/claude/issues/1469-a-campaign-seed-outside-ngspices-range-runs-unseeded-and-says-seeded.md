# 1469 — A campaign seed outside ngspice's range runs unseeded and says it was seeded

**Status:** OPEN — filed by the driver 2026-09-15. Surfaced by issue 1468's crew as *"a campaign seed of
2³² or more reads as not seeded"* (receipt `doc/claude/ase_analyses_batch/receipts/44-1468-point-estimate-range.md`,
survey); the driver then measured what ngspice does with the seed, and **the defect is the other way
round and wider**.

## What the user meets

A Monte Carlo campaign with a seed typed into its dialog is reported as seeded — the Tran form's
noise sentence says random sources repeat, and a campaign's re-run is expected to reproduce its
shards. **For a large part of the range ASE-L accepts, ngspice throws the seed away**, prints one
warning into each shard's log, runs that shard unseeded at rc 0, and nothing in ASE-L says so. The
campaign cannot be reproduced and claims it can.

## What ngspice does with `.options seed=<n>` — measured, identical on both binaries

One deck, `v1 1 0 dc 0 trrandom(2 100u 0 1 0)`, `tran 100u 2m`, read `v(1)[5]` twice per seed;
apt 45.2 (`/usr/bin/ngspice`) and the fork (`build-ver_50`), fork first. No run crashed.

| seed | reproducible | `$rndseed` | warning |
|---|---|---|---|
| 1 | yes | 1 | — |
| **0** | **NO** | 1 | `Warning: Cannot convert 'option seed=0' to seed value, skipped!` |
| **−5** | **NO** | 1 | the same |
| 2147483647 (2³¹−1) | yes | 2147483647 | — |
| **2147483648 (2³¹)** | **NO** | 1 | the same |
| **3000000000** | **NO** | 1 | the same |
| **4294967295** | **NO** | 1 | the same |
| **4294967296 (2³²)** | **NO** | 1 | the same |
| 5000000000 | yes — **silently wrapped** | **705032704** (= 5000000000 mod 2³²) | — |
| **6442450944 (2³² + 2³¹)** | **NO** | 1 | the same |
| 8589934593 (2³³ + 1) | yes — **wrapped** | **1** | — |

**The rule the numbers fit:** ngspice keeps the low 32 bits as a signed `int` and refuses any value
that is then ≤ 0. So **only 1 … 2147483647 is honoured as typed**; everything else is either refused
(unseeded, one warning) or wrapped onto another seed (so two different typed seeds give the same
stream).

## What ASE-L does with it

* `ase::campaign_seed` (`src/ase.tcl` ~`:20257`) accepts the typed seed through
  `string is integer -strict`, which on Tcl 8.6.17 is true for **every** whole number up to
  4294967295 and for zero and negatives, and `{}` for 2³² and above (issue 1468's measurement).
* `ase::campaign_prepare` (~`:20578`) writes `.options seed=[expr {wide($seed) + $idx}]` into shard
  `idx`.

So, concretely:

| typed seed | what ASE-L reports | what ngspice does |
|---|---|---|
| 0, or any negative | seeded | shard 0 (and every shard until the sum is ≥ 1) **unseeded** |
| 2147483600, 100 shards | seeded | shards 0–47 seeded, **shards 48–99 unseeded** |
| any of 2147483648 … 4294967295 | seeded | **every shard unseeded** |
| 5000000000 | **not seeded** | would have been seeded (wrapped) — the opposite error |

The seed-reporting readers (`ase::stimuli_seed_report` via ~`:21946`, the campaign dialog at
`src/ase_window.tcl` ~`:13834`, `:14345`, `:14372`) all read `ase::campaign_seed`, so every surface
agrees with ASE-L and disagrees with the simulator.

This is the batch's **accepted-is-not-honoured** class (LEDGER.md) a seventh time, and the first where
the dishonoured value is typed by the user into ASE-L's own field.

## The fix is expected to be small, and is not taken here

The honoured range is a **simulator fact**, so it belongs to the adapter (D34–D37): ngspice's hook
states `1 … 2147483647`, core refuses a typed seed outside it at the form with a sentence, and the
per-shard seed must stay inside it for **every** shard — refuse a seed whose `seed + (shards − 1)`
leaves the range, or fold each shard's seed into the range the way `ase::mc_seed_norm` already folds
the sampler's (deterministically, so a re-run reproduces). Read the typed value with
`string is entier -strict` (issue 1468's lesson). Rows on both binaries: a shard seeded at the top of
the range reproduces, one just past it is refused before any deck exists, and a campaign whose last
shard would cross the boundary never writes an unhonoured seed. A backend with no hook gets no
seed range and no seed sentence — no fallback.

## Found beside it, not part of this issue

`ase::backend::ngspice::tran_points` wraps from 2⁶³ (`int()`), so `tran 1a 10` estimates a negative
count — issue 1468's receipt, headline 5. Named on the ledger, not filed.
