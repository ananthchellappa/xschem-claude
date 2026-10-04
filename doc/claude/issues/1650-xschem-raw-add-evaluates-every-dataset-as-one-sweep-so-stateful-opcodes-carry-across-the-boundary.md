# 1650 — `xschem raw add` evaluates every dataset as ONE sweep, so stateful opcodes carry across the boundary

**STAMP:** `v1 claim=fixed tree=ffa8e040 stamped=2026-10-04 fix=taken open=2`

Status: **OPEN**, found 2026-10-04 by two independent Calculator-batch recon crews, which reached it
from different directions and agreed on the mechanism and the numbers.
Area: `raw_add_vector()` in `src/save.c`, `plot_raw_custom_data()` in `src/draw.c`.

## The defect

`raw_add_vector()` — the function behind `xschem raw add`, i.e. the **Tcl** door — evaluates the
expression over the entire raw file in one pass:

```c
plot_raw_custom_data(sweep_idx, 0, raw->allpoints - 1, expr, varname);   /* src/save.c:1448 */
```

The **graph** door passes each dataset's own extent instead:

```c
plot_raw_custom_data(node_sweep_idx, ofs, ofs_end - 1, express, NULL);   /* src/draw.c:5973 */
```

`plot_raw_custom_data()`'s own comment already names `raw_add_vector()` as *"the one caller that
passes `first = 0` unconditionally"*. So every **stateful** opcode — `integ()`, `avg()`, `deriv()`,
`deriv2()`, `prev()`, `del()`, `ravg()`, and anything composed from them — carries its accumulator
across the dataset boundary, where the sweep variable jumps **backwards**. Measured on
`tests/headless/data/calc_fixture.raw`: `time` at index 100 is `0.009999999999999995` and at index
101 is `0`, a step of `-0.01`.

## What the user gets today, measured through the real path

`calc::eval_rpn` on dataset 1 of the committed fixture, against an independent hand computation:

| expression | reported | true | error |
|---|---|---|---|
| `v(sq) integ()` | `0.001800000000000001` | `0.0034` | **−47%** |
| `v(sq) dup() * integ() sqrt()` | `0.0393700393700591` | `0.05722761571129799` | **−31%** |
| `v(div) dup() * integ() sqrt()` | **refused** | `ok` | — |
| `v(sq) deriv()` at point 0 | `100.0000000000001` | `0` | — |

The third row is the sharpest: the boundary term drives `integ(y²)` **negative**
(`I2` at 100 is `0.003275`, at 101 is `-0.001725`), `sqrt()` has no clamp, and the user is told
*"Evaluate: the result is not a finite number (-nan)."* — a refusal whose stated reason is true and
whose cause is this defect rather than their expression.

⚠ **`average` and `rms` self-heal on this fixture by ACCIDENT, not by design.** Both tran datasets
share an identical time grid starting at 0, and `case AVG` divides by a carried count, so the two
errors cancel. A fixture whose datasets had different grids would show them wrong too. This is the
fixture-accident trap recorded in CLAUDE.md, arriving a third time: a number that looks right for a
reason unrelated to correctness.

## Why it is reachable today, and not only by unbuilt work

`calc::fn_argspec` already offers `{dataset {Dataset} int 0 0}` on the **shipped** `riseTime` and
`dutyCycle`. A user who types a dataset other than 0 into that field is already on this path. The
defect therefore is not gated behind the unbuilt composite verbs — it is live on `fluid-editing`
now, and it answers a confidently wrong number rather than refusing.

## The two candidate fixes, and why the cheap one is not enough

**(a) Tcl, per composition.** Read the `integ()` column at two points and subtract, with the dataset
offset: `integ = I[l] − I[f]`, `average = (I[l] − I[f]) / (x[l] − x[f])`, and so on. A crew measured
this giving the right answer on **both** datasets to ~1e-16, and it needs no C change. But it repairs
only the reductions somebody writes it for: `deriv()` at the first point of a dataset is still
`100.0` instead of `0`, and `prev()`, `del()` and `ravg()` stay wrong across the boundary, as does
any user-typed expression using them. It also leaves the `-nan` refusal class alive for compositions
nobody has enumerated.

**(b) C, at the door.** Loop over datasets in `raw_add_vector()` and call
`plot_raw_custom_data()` once per dataset with that dataset's offset and end — which is exactly what
`draw.c` already does at three sites. This fixes every stateful opcode for every caller of
`xschem raw add`.

⚠ **(b) is the correct fix and it is the one with the unmeasured blast radius.** It changes
`xschem raw add`'s numbers for every multi-dataset file, so any golden value anywhere in the tree
that baked in a boundary-crossing result becomes a red — and those reds would be the instrument
working. The population must be derived before the change, not discovered by a gate.
`plot_raw_custom_data()` is also known-delicate: issue **1628** was a C fix in this same function,
where the `DIVIS` arm read `y[p - 1]` at `p == first`, witnessed by valgrind as an invalid read
8 bytes *before* the block. A per-dataset loop makes `p == first` happen once per dataset instead of
once per file, so **every `p == first` guard in that function has to be re-read**, not assumed.

## Outstanding, as revised when the fix landed

Items 1 and 2 of the original list are **done**: the blast radius was derived (1091 raw-read
announcements, 66 multi-dataset reads, three distinct files) and every `p == first` guard was
re-derived from the function's own text and checked per arm, issue 1628's `DIVIS` arm included.
What remains:

1. Whether `sqrt()` of a negative accumulator should refuse or clamp. The fix removes the path that
   produced it here -- 101 of 101 dataset-1 points of `v(div) dup() * integ() sqrt()` were `-nan`
   before and all are finite now -- but it does not make the opcode safe for a user-typed
   expression that manufactures a negative argument some other way.
2. `idx()` is now the only **file-global** opcode in a dataset-local family, so `idx() 50 >` used as
   a per-run mask selects on dataset 0 only. Nothing in the tree asserts that `idx()` stays
   absolute. Measured unchanged at both doors on every build; recorded as a declared hole rather
   than changed, because changing it is a user-visible semantic and not a defect anybody reported.

## 2026-10-04 — the fix landed, and part 2 carried a regression of its own

Fixed in three parts: a per-dataset loop in `raw_add_vector()`, a clamp in
`plot_raw_custom_data()` that raises the token scan's backward-widened `first` back to the start of
the dataset the caller's `first` belonged to, and the re-enabling of the `#if 0` multi-OP coalesce
(moved from `scheduler.c`'s `raw add` arm into `raw_add_vector()`, next to the loop it protects).
Outstanding item 2 above was discharged: row **DS12** of `tests/headless/test_divis_zero_1628.tcl`
derives the set of `case` arms that test `p == first` from `src/save.c`'s own text and asserts it
against the set the suite drives, so a stateful arm added later cannot ship unexamined.

⚠⚠ **PART 2 REGRESSED THE MARKER/CURSOR READOUT ON A MULTI-DATASET OPERATING POINT RAW, AND THE
GATE COULD NOT SEE IT.** `graph_marker_sample()`, `find_closest_wave()` and
`wave_hilight_envelope()` walk the **real** dataset table and pass `(ofs, ofs_end - 1)`; they do
**not** apply the coalesce that `graph_x_extent()`, `graph_fullyzoom()` and `draw_graph()` apply.
On a parametric `.op` every dataset is one point, so those three call the evaluator with
`first == last`, where the backward widening had been reaching into the neighbouring "datasets" --
which on such a database are the neighbouring sweep points, and exactly what the opcode wants. The
clamp removed precisely that. Measured on a 4-dataset single-point OP raw (sweep 1,2,4,7 and
`v(out)` 2,5,13,22) through `xschem graph_marker add_at`:

| expression | HEAD | loop+clamp | with the repair |
|---|---|---|---|
| `v(out) deriv()`  | `{0 3 4 3}` | `{0 0 0 0}` | `{0 3 4 3}` |
| `v(out) prev()`   | `{2 2 5 13}` | `{2 5 13 22}` (identity) | `{2 2 5 13}` |
| `v(out) integ()`  | `{0 3.5 18 52.5}` | `{0 0 0 0}` | `{0 3.5 18 52.5}` |
| `v(out) deriv2()` | `{0 3 4.666666666666667 2.4000000000000008}` | `{0 0 0 0}` | same as HEAD |
| `v(out) 1 *` (control) | `{2 5 13 22}` | `{2 5 13 22}` | `{2 5 13 22}` |

**Repaired** by one condition at the head of `raw_dataset_start()`: on a multi-dataset single-point
`op` database the whole file is one dataset, so the clamp has nothing to clamp to. It goes there and
not as a fourth copy of the coalesce because that function is the single place the clamp asks "where
does this dataset begin" -- one definition, two call sites, asserted by DS12 -- so one condition
covers all three doors and any added later.

**Why the gate was blind, and what closed it.** DS10 drove a multi-OP raw through the **Tcl** door
only; DS13 drove the **marker** door through the **tran** fixture only. The fourth cell of that 2x2
was covered by neither -- the same shape of hole that made the per-dataset loop's own regression
invisible, one level in. Band **DS14** is that cell, and its reference is a contract rather than a
table: the same four points read back as **one** dataset must give the marker door the same series.
Bands DS15 (the visible-run window family and the y-autorange door), DS16 (`deriv0()`/`deriv20()` at
the graph door, driven with `sweep=v(ramp)` because on the default sweep they are numerically
identical to `deriv()`/`deriv2()`), DS17 (dataset 1's **second** point, where `deriv2()` is also
wrong on HEAD) and DS18 (`idx()`) were added in the same round.

## Still open after that round

1. Outstanding item 1 above -- the blast radius of the per-dataset change across the tree's golden
   values -- remains underived as a population; what exists instead is the instrument sweep in the
   closing receipt, which found no red.
2. Outstanding item 3 above (`sqrt()` of a negative accumulator) is untouched.
3. **The marker door and the trace door disagree about `integ()` on a parametric `.op`, and always
   have.** `integ()` widens `first` by one, so the marker evaluates a two-point window and answers
   one trapezoid (`{0 3.5 18 52.5}`) while the Tcl/trace door coalesces and answers the cumulative
   integral (`{0 3.5 21.5 74}`). Identical on HEAD and after the repair, so it is not this fix's
   doing; row DS14d fences today's behaviour and DS14d2 asserts the disagreement exists, so a
   future change to it is visible. Whether the marker door should coalesce is a product question.
4. **`idx()` is now the only file-global opcode in a dataset-local family.** It pushes the absolute
   point index, so a per-run mask typed as `idx() 50 >` is 1 for **every** point of every dataset
   after the first -- measured on the two-dataset fixture: 50 of dataset 0's 101 points pass, and
   101 of dataset 1's 101 do. Unchanged by this commit (identical on HEAD); row DS18 now pins it so
   a change is visible, and whether it should be dataset-local is a product question.
