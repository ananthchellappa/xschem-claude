# 1469 — A campaign seed outside ngspice's range runs unseeded and says it was seeded

**Status:** FIXED 2026-09-15 — verified by the driver (suites re-run on both arms, its own sabotage of the fold reddening SR4 SR4b SR4c SR5 SR10 EE7 EE8 on both binaries, T1 80 cases / zero counted) — see *The fix* at the end of this file
and `doc/claude/ase_analyses_batch/receipts/45-1469-campaign-seed-range.md`. Filed by the driver 2026-09-15. Surfaced by issue 1468's crew as *"a campaign seed of
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

## The fix — 2026-09-15, the crew (receipt 45)

**Measured before the fix, through ASE-L's own campaign runner, fork first then apt 45.2.** A campaign
seeded 2147483647 over two points that differ only by their seed wrote `seed=2147483648` into its second
shard; that shard's `rc_ase.log` carried `Cannot convert 'option seed=2147483648' to seed value, skipped!`
and its measurement changed between two runs of the same campaign (fork 5.13913e-01 → 4.75481e-01, apt
5.257042e-01 → 4.713302e-01), while the first shard repeated exactly on each binary.

1. **The range is the adapter's.** `ase::backend::ngspice::campaign_seed_range` → `{1 2147483647}`,
   registered beside `campaign_seed_option`, carrying this file's table and `eval_opt()`'s
   `atoi` / `sr <= 0`. Core reads it through `ase::campaign_seed_range`. A backend with no hook gets `{}`:
   no refusal, no fold, its typed whole number. A malformed answer is also `{}`, and
   `ase::campaign_schema_errors` names it.
2. **`ase::campaign_seed` answers only a seed the simulator honours** — `string is entier -strict`, then
   the range of its new optional `sim` argument, else of the state's own `simulator` key, which is the key
   `ase::ui::camp_sim` reads. The three dialog readers this file names needed no edit for that reason.
3. **Refused at the form and at run, before anything is written.** `ase::campaign_seed_refusals` →
   `badseed`, *"the seed must be a whole number from 1 to 2147483647, the only seeds this simulator
   honours"*. It is asked by `ase::campaign_refusals` (so `ase::campaign_run` and Re-run Point refuse
   before a directory exists), by the dialog's note line and Run button (also before the first axis), by
   OK (refused; the dialog stays) and by Run Campaign **before** it commits the form. A `.state` already
   carrying such a seed still loads and saves byte for byte.
4. **Every shard's seed stays in the range — folded, not refused.** `ase::campaign_shard_seed`: base+N,
   and past the top it counts on from the bottom. A refusal of `seed+(n−1)` would depend on the point
   count, so adding an axis would turn a valid seed refused. The fold is deterministic (Re-run Point
   rewrites the shard's deck byte for byte) and collision-free while the campaign has no more points than
   the range has seeds (2147483647 against a 2000-point ceiling); a smaller declared range is refused
   (`seedspan`). The per-shard sentence says `, wrapping to 1 after 2147483647` exactly when a campaign
   crosses the top.
5. **The seed report agrees with the simulator.** `ase::stimuli_seeded` — and so
   `ase::stimuli_seed_report` — counts a campaign seed only through `ase::campaign_seed`, and under a
   declared range counts an options `seed` row only when ngspice honours its value: `seed 0`,
   `seed 2147483648` and `seed random` no longer make the noise section say RTS noise "repeats exactly
   under the seed". A backend with no range keeps the old answer.

### The rows that prove it

`test_ase_campaign_1462` **133 → 161** on both arms, `test_ase_campaign_gui_1464` **156 → 162** on the dev
display (headless unchanged at 78).

| claim | rows |
|---|---|
| the range is the adapter's; no hook means no range and no fallback; a malformed range is named | SR1 SR2b SR2c SR7c SR8 |
| `ase::campaign_seed` answers only an honoured seed | SR2 SR2c |
| a typed seed outside the range is refused, in any spelling, and both ends and no seed are not | SR3 SR3b SR3c SR3d SR5 |
| refused by the runner and by Re-run Point before any directory — and on each real binary's entry | SR9, EE9/apt EE9/fork |
| refused at the form: note line, OK, Run before commit, with no axes; the axis editor is not refused over it | GS1 GS2 GS3 GS4 GS6 |
| every shard in the range, folded, collision-free at the 2000-point ceiling, re-run reproduces the deck | SR4 SR4b SR4c SR5 SR10 |
| more points than seeds is refused | SR5b |
| the notes, the noise seed sentence and the dialog say what the simulator will do | SR6 SR6b SR7 SR7b GS5 |
| seeded at the top, every shard reproduces across two runs on the real binary | EE7/apt EE7/fork |
| no shard log carries `Cannot convert … seed value`, with a control log that does | EE8/apt EE8/fork |
| a `.state` carrying such a seed loads and saves byte for byte | SR11; the 104 files: `tracked 104 bad {} control_disagrees 1 control_agrees 1` |

Before the fix those rows read, among others: EE7 `{done done {seed=2147483647 seed=2147483648} 0 1}`,
EE8 `{4 2 {4 0} 1 1 seed=0}`, EE9 `{done {} 1 0}`, SR9 `{{done {}} {done {}} 1}`, GS2 `{0 2147483648}`,
GS3 `{{done {}} 2147483648 1 1}`. Sabotage: 23 arms, every one of the 34 new rows red under at least one,
every restore md5-clean, ending on the restored tree `ALL PASS` for both suites on both arms.

### Found beside it, not fixed here

* **The Options sheet still takes a `seed` row of `0`, `2147483648` or `random`** and renders it
  (`.options seed=0` — EE8's control measures the warning it produces). The seed report now calls such a
  run unseeded, which is true; refusing the value at the Options sheet is that form's question.
* **`08` is not a whole number to Tcl 8.6, and `010` is 8** (`string is entier -strict 08` → 0, invalid
  octal; `expr {entier(010)}` → 8; measured on `tclsh` 8.6.17). So `08` typed as a seed is now refused with
  the sentence and `010` seeds shard 0 with 8. Before the fix `08` was silently no seed and `010` was
  silently 8.
