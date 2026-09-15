# 1468 — The "gigabytes and hours" caution goes silent at four billion points

**Status:** FIXED 2026-09-15 — receipt `doc/claude/ase_analyses_batch/receipts/44-1468-point-estimate-range.md`.
Filed by the driver the same day, found by Stage 13 task 3's crew (receipt
`doc/claude/ase_analyses_batch/receipts/43-stage-13-m22.md`, headline 4), boundary measured by the
driver. **Proved by** `tests/headless/test_ase_effective_1442.tcl` **RU12** (the size caution from 2³²
up) and **RU13** (the estimator's range and type), and `tests/headless/test_ase_trnoise_1466.tcl`
**NX6** (the Tran form's estimate) and **NK22** (the noise check's base) — all four red on the
pre-change `src/ase.tcl` and with `string is integer -strict` put back. See *Fixed* at the end.

## What the user meets

§7g's size rule warns before a run that would write *"about N points — gigabytes of results file"*.
It is silent for exactly the runs it exists for. `tran 1n 3` (3 000 000 000 points) gets the
sentence; **`tran 1n 5` (5 000 000 000) gets nothing**, and neither does `tran 1f 10` (1e16).

## Cause

`ase::analysis_point_estimate` (`src/ase.tcl`, ~`:9345`) accepts the adapter's estimate only through

```tcl
if {![string is integer -strict $n]} { return {} }
```

and on this tree's Tcl, **8.6.17**, `string is integer -strict` is **not** "is a whole number".
Measured by the driver:

| value | `string is integer -strict` | `string is wideinteger -strict` |
|---|---|---|
| 2147483647 | 1 | 1 |
| 2147483648 | 1 | 1 |
| 4294967295 | **1** | 1 |
| **4294967296** (2³²) | **0** | 1 |
| 10000000000000 | 0 | 1 |
| 9223372036854775807 | 0 | 1 |

So any estimate of **2³² points or more** is dropped as `{}` and every reader treats the row as
having no estimate at all.

## Who reads it — three places lose their answer

| reader | effect at ≥ 2³² points |
|---|---|
| §7g `points_max` (`src/ase.tcl` ~`:12186`) | **the size caution is silent** |
| `ase::stimuli_points` → the Tran form's `≈ N points` (~`:21828`) | the noise section's estimate loses its base |
| the adapter's noise check (~`:29281`) | the noise caution's base is `{}` |

**Not affected:** `ase::ckpt_plan` calls the hook directly and tests `string is double -strict`, so
checkpointing still arms for such a run.

It is also why issue 1466's row NK20 (a 1e13-point fixture) was not reddened by receipt 43's
mutation M10 — the fixture's own number is above the range.

## The fix is expected to be small, and is not taken here

Read the estimate with `string is entier -strict` (Tcl 8.5+) or `string is wideinteger -strict`,
or with `string is double` as the planner does — whichever keeps the readers' arithmetic exact —
and give each of the three readers a row above 2³² that goes red without it. **Survey the other
`string is integer -strict` sites on counts** while there: `src/ase.tcl` ~`:15293` and
~`:17587`/`:17595`/`:17596` test point and vector counts the same way, and a rawfile's point count
is not bounded by 2³².

## Fixed

**The change** — one line in `ase::analysis_point_estimate`, `string is integer -strict` →
**`string is entier -strict`**, with the measurement in a comment above it. Nothing else in `src/`
moved; `ase::ckpt_plan` is untouched.

**Why `entier` and not the other two candidates.** Measured on 8.6.17 over 36 spellings: every string
`integer` accepts, `entier` accepts, and the only strings `entier` adds are whole numbers of magnitude
2³² or more — so `5e9`, `5000000000.0`, `3.5`, a word and `{}` still read as no estimate, and a
negative is still a number. `wideinteger` answers **0 from 2⁶⁴** (18446744073709551616) on this Tcl,
which moves the silence rather than removing it; `string is double` loosens the type. The readers
compare and multiply in `expr`, exact on an integer of any size.

| row | suite | what it pins | red on |
|---|---|---|---|
| **RU12** | `test_ase_effective_1442` | `tran 1n 4.294967296`, `1n 5`, `1f 10` warn and quote the whole count; `1n 4.294967295` is the control | pre-change file, `integer` put back, reader 1 alone re-bound |
| **RU13** | `test_ase_effective_1442` | through a fixture hook: 2³², 5e9, 2⁶⁴ and −5e9 are estimates; `5e9`, `5000000000.0`, `3.5`, `abc`, `{}` are not; under 2³² every spelling answers what the old test answered | pre-change file, `integer`, `wideinteger`, `double`, the test deleted |
| **NX6** | `test_ase_trnoise_1466` | `ase::stimuli_points` and the readout keep a 5e9 card with no table and under noise asking 2.5e7 (bytes 160 GB, not 800 MB) | pre-change file, `integer`, reader 2 alone |
| **NK22** | `test_ase_trnoise_1466` | a 5e9 card under noise asking 2e8: no noise caution, `points_max` speaks — the same as the 3e9 control | pre-change file, `integer`, reader 1 alone, reader 3 alone |

§7g's rows live in `test_ase_effective_1442` section RU (RU9–RU11), not in `test_ase_preflight` or
`test_ase_core`. And receipt 43's mutation M10, re-run on the fixed tree, now **reds NK20** as well as
NX2, NX6, NP1, NP2 and NP5 — the "why NK20 slipped past" paragraph above no longer holds.

### The survey — every other `string is integer` in `src/ase.tcl`, by proc

**None changed.** Only one reads a count that can reach 2³².

* **The rawfile header counts** — `ase::cap_raw_plots` and `ase::raw_scalars` (`No. Variables:` /
  `No. Points:`), `ase::raw_content_verdict` (the three this issue named, plus its `nv == 0` guard),
  and `ase::attach_dbs`' `xschem raw points`. **Correction to the paragraph above:** a rawfile's point
  count *is* bounded here, below 2³². ngspice's `write` prints `No. Points: %d` from an `int length`
  (`src/frontend/rawfile.c`, the declaration and the `fprintf`), fed by `int v_length`
  (`dvec.h`), and the `-r` writer back-fills with `%d` too. xschem's own C reader scans
  `No. Points: %d` into `int *npoints` (`save.c` `read_dataset`, `xschem.h`), and `xschem raw points`
  returns that `int`. So no file this tree writes or loads carries a count above 2³¹−1, and these
  readers were left alone.
* **~`:15293` is not a count.** It is `ase::with_design_current` reading `xschem get no_draw`, a 0/1
  flag, beside `modified`, `autosave_backup` and `readonly`, which are flags too.
* **Small declared numbers:** a `setup` contract's `min` (`ase::analysis_schema_errors`,
  `ase::analysis_setup_min`, the `two_ports` precondition), the emit rank, a `trrandom` `dist` of 1–4,
  S-parameter port numbers. **Indices and depths:** analysis and row indices, entry numbers
  (`ase::stimuli_readout`'s `k`), hierarchy levels (`currsch`), process and campaign job ids.
  **List lengths:** `ase::stat_bins`' `n`, `ase::stat_histogram`'s `nbins`, a distribution's sample
  count (a loop that allocates every sample). **`nvec`** in `ase::stimuli_readout` is
  `ase::stimuli_nvec`'s `llength` of one plot's variable list, read out of the rawfile by
  `ase::cap_raw_plots`.

### Found while surveying, NOT fixed — for the driver

1. **The adapter's hook wraps from 2⁶³.** `ase::backend::ngspice::tran_points` returns
   `int(double(stop - start) / step + 0.5)`, and Tcl 8.6's `int()` keeps the low 64 bits. Measured:
   `tran 1a 10` → **−8446744073709551616** (no caution, no checkpoint plan), `tran 1a 100000` →
   **200376420512301056** for 1e23 points (a caution quoting the wrong count). `entier()` does not
   wrap, but it would hand `ase::ckpt_plan` a bignum that `ase::ckpt_plan`'s own `int()` and `wide()`
   then wrap, so this fix does not touch the hook or the planner.
2. **A campaign seed of 2³² or more reads as "not seeded".** `ase::campaign_seed` tests
   `string is integer -strict` and answers `{}` for 5000000000 (measured), while `ase::mc_seed_norm`
   would fold any integer into range. It is not a count, so it is outside this issue.
