# `set interp` — what it touches and what it only claims to touch — debt **M8**, answered

**Measured 2026-09-13 by the driver**, four decks, on **both** binaries. M8 recorded that
`interp` had been measured *"only on a real transient (21 points from `tran 1u 20u`)"*, and asked
whether it changes a **complex AC** plot and a **nested DC** sweep correctly. The Tran form's
`grid` field is Stage 3; the AC and DC arms are Stage 6.

## The answer: it is a TRANSIENT-ONLY feature that announces itself on every analysis

| analysis | points without `interp` | with `interp` | rawfile `No. Points` | values |
|---|---|---|---|---|
| `tran 1u 20u` | **118** (apt) / **121** (fork) | **21** / **21** | 118 / 121 → 21 / 21 | resampled |
| `ac dec 10 1 1meg` (complex) | 61 | **61** | 61 → 61 | **byte-identical** |
| `dc v1 0 1 0.1 v2 0 1 0.5` (nested) | 33 | **33** | 33 → 33 | **byte-identical** |

`v(out)[5]` is unchanged on both the AC and the nested DC, to every printed digit, on both
binaries — `9.999900e-01,-3.16225e-03` and `2.500000e-01`.

## ⚠ AND IT PRINTS ITS WARNING ANYWAY

Every run with the variable set — transient, AC, nested DC — emits

```
Warning: Interpolated raw file data!
```

**On AC and DC that sentence is not true of the data.** Nothing was interpolated; the point count,
the scale and every value are identical. So a user who sets `interp` once (or an Options sheet that
carries it as a deck-level `set`) gets a warning in the run log claiming their AC results were
resampled when they were not.

That is a design constraint rather than a curiosity, and it points the same way twice:

* **ASE-L should not offer `interp` on an AC, DC or nested-DC row.** It does nothing there, and the
  only thing the user gets is a false line in their log.
* **Where it is offered — the Tran form's `grid` — it should say what it does**: resample onto a
  uniform time grid, changing the point count.

## ⚠ The bonus, and it is the sharper half: the two binaries disagree about a transient's length

The **same deck** produces **118** points on `/usr/bin/ngspice` (45.2) and **121** on the fork —
the timestep controllers are not identical. With `set interp` both answer exactly **21**.

Two consequences, neither previously recorded:

1. **Any golden that pins a transient point count is build-dependent**, and this batch has
   `.state` goldens and suite rows that count vectors. Recorded as difference **#7** in
   `evidence/binary-differences.md`.
2. **`interp` is the one setting that buys reproducibility across builds.** That is a better
   argument for offering it on the Tran form than "a uniform grid is tidier", and it is the
   sentence the field's caption should carry.

## What this leaves

* **M8 is closed** for AC and nested DC: the answer is *"it does nothing, and says it did"*.
* **Not measured:** whether `interp` is honoured for `sp`, `noise`, `pz` or `disto` — the same
  "announces and does nothing" shape is likely, and none of those has a uniform-grid meaning.
  Worth one deck each if any of them ever grows an `interp` control; nothing today offers one.
