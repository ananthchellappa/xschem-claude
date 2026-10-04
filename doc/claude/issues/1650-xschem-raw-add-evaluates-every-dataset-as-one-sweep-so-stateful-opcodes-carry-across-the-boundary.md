# 1650 — `xschem raw add` evaluates every dataset as ONE sweep, so stateful opcodes carry across the boundary

**STAMP:** `v1 claim=open tree=ffa8e040 stamped=2026-10-04 fix=none open=3`

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

## Outstanding

1. Derive the blast radius of fix (b): every golden value in the tree produced through
   `xschem raw add` on a multi-dataset raw file.
2. Re-read every `p == first` guard in `plot_raw_custom_data()` against a per-dataset loop, issue
   1628's arm included.
3. Decide whether `sqrt()` of a negative accumulator should refuse or clamp. Fix (b) removes the
   path that produces it here, but it does not make the opcode safe for a user-typed expression.
