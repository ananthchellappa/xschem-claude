# 1468 — The "gigabytes and hours" caution goes silent at four billion points

**Status:** OPEN — filed by the driver 2026-09-15, found by Stage 13 task 3's crew (receipt
`doc/claude/ase_analyses_batch/receipts/43-stage-13-m22.md`, headline 4), boundary measured by the
driver. Not fixed.

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
