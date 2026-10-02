# Stage F — `cross` recon

Five crews, 2026-10-01, before any `cross` code existed. Driver collected. The decided contract is
`../CROSS_CONTRACT.md`; this file is the **evidence**, and in particular the golden crossing data
the red-first rows are written against.

## What recon overturned

Three documents the implementer would otherwise have followed were wrong, and all three are
corrected in the contract:

1. **Landmine L2 does not apply to a named `xschem raw add`.** Named columns are persistent and
   independent; the shared scratch column `values[nvars]` is taken only when `yname == NULL`,
   which happens at twelve `src/draw.c` call sites and nowhere else
   (`/usr/bin/grep -c 'plot_raw_custom_data' src/scheduler.c` → **0**). So `cross` carries no
   re-evaluate-before-reading rule, and R402's delete is **leak hygiene**, not a staleness remedy.
2. **PLAN row 7.2's "exact"** was unachievable; the fixture README says *"Use a tolerance, not
   equality"*. Corrected in `PLAN.md`.
3. **`xschem raw add` never returns −1**, so spec §3.1's failure value cannot arrive at a Tcl
   caller. A bad expression on a fresh name answers **1** and leaves an all-zeros column behind.

## Golden data — dataset 0 of `tests/headless/data/calc_fixture.raw`

⚠ **The next crew RE-DERIVES these independently and reports any disagreement.** They are one
crew's measurement passed through the driver's transcription, which is exactly the kind of number
this batch has learned not to trust. A disagreement is a finding either way.

`v(sq)`, level **0.5**, computed with the contract's own D3 predicate and D4 interpolation:

```
rising   {p 10 0.0009999999999999998} {p 50 0.005} {p 90 0.008999999999999998}
falling  {p 23 0.0022000000000000006} {p 62 0.006199999999999998}
```

These reproduce the README's hand derivation — *"rising 50 % crossings at t = 1.0, 5.0, 9.0 ms;
falling at 2.2, 6.2 ms"*. Sample values at the interesting points:

```
v(sq) at 10, 22, 50, 62, 90, 100 =
  0.5000000000000009 0.5000000000000018 0.5 0.4999999999999751 0.5000000000000142 1
time[100] = 0.009999999999999995          <- five ulps under 0.01, and the cause of issue 1630
```

**Sample 50 is bit-exactly 0.5, and D4's formula returned exactly `0.005` = `x[50]` with no
special case** — the exact-sample-hit claim, verified on real data rather than argued.

### Level choice is constrained, and the constraints are not obvious

- **Only levels strictly inside (0, 1) are assertable.** At 0.0 and 1.0 the two plausible
  strict/non-strict conventions disagree in **count and direction**, and 1.0 carries a
  dust-driven recrossing (`v[51] = 1.000000000000039`).
- **0.3 and 0.75** are convention-independent and fully interpolated. **0.5** is
  convention-independent in its X values but not in its bracket indices.
- **R414d (interpolated, never snapped) cannot be fenced at 0.5** — those crossings sit on
  samples. Use an off-sample level such as **0.25**.
- **D3's flat-on-`L` limit is unreachable through the fixture**: four of the five 50 % samples are
  9e-16 to 1.8e-15 off exact. That row needs a **synthetic clamped column** (`min()`/`max()`).

### One row would have passed by luck

On `v(sq)` the last crossing overall is **rising**, so `rising nth=-1` equals `either nth=-1` and
a broken direction filter survives the test. The fix needs no fixture change: `1 v(sq) -`
(measured working on both datasets). The crew's numbers for it — **to be re-derived** —

```
rising nth=-1 on `1 v(sq) -`  must be 0.0061599999999999997, NOT 0.0090399999999999994
```

## The dataset seam invents a crossing nothing could reject

At level 0.5 over `dataset -1` (allpoints), the X column has exactly **one** non-increasing step,
at the seam, and it manufactures a phantom falling crossing:

```
p=99..102  y: 1 1 0 0
p=99..102  x: 0.009899999999999996 0.009999999999999995 0 0.0001
phantom falling crossing at p=101, t = 0.0049999999999999975
```

That time is inside dataset 0's range and coincides to **2.5e-18** with a real *rising* crossing.
No caller rejects it by inspection; no tolerance-based row separates them. Hence the contract's
D12: one dataset, explicit, default 0, never −1.

## Non-finite handling: the first draft of D6 was not strong enough

```
y0=-inf y1=0.6 : rising=1 falling=0     <-- D3's predicate PASSES on an infinity
y0=-nan y1=0.6 : rising=0 falling=0
expr {$y - $L} with y = -nan : RAISED  (can't use non-numeric floating-point value)
expr {$y - $L} with y = -inf : RAISED  (domain error)
zero denominator             : RAISED  (domain error)
```

So the finiteness gate must run **before** D3 rather than filtering what D3 rejects, and an
unguarded `cross` would **throw rather than refuse** — which reaches the file-scope catch and
aborts a whole suite. `calc::eval_finite` is the correct guard (textual); `string is double
-strict` accepts all four non-finite spellings and `expr {$v == $v}` does **not** raise on this
Tcl, contrary to that proc's own header comment.

## Performance: the scan primitive choice is free today and matters later

100 000-point synthetic raw, Tcl `time`, count 1, quiet machine — **order-of-magnitude evidence,
not a benchmark, and not to be quoted in a comment**:

```
raw values + llength + lindex end : 15598 us
200 backward single-point reads   :   111 us
200 forward  single-point reads   :    88 us
(on the 101-point fixture, bulk wins: 14 us vs 40 us)
```

Hence D10: scan per point with `xschem raw value` for `nth ≠ 0`, bulk `raw values` for `nth = 0`.

## Defects filed, none fixed

| issue | what |
|---|---|
| **1630** | `wviewer::interp_value` reports another dataset's value at and past the end of the sweep — 2.5 V where the truth is 5 V, on a cursor readout |
| **1631** | `raw pos_at`'s help promises a crossing finder; `raw_get_pos()` is a monotonic bisection. 42 % of windows containing a crossing answer `-1` on `v(sq)`, 0 % on `v(ramp)` |
| **1632** | `raw values <name> <dataset>` reads `npoints` out of bounds; valgrind-confirmed, and the garbage became a loop bound — 1.1 GB of log in 3m35s |

Two prose corrections are owed by the implementation commit rather than filed, because they sit in
files that commit edits: `calc::eval_finite`'s header mechanism, and spec §3.1's `-1` as seen from
Tcl. Both are listed in the contract's §4.

## Blockers

**None.** Every door `cross` needs is present and measured: a persistent named column, an X column
readable by name, a verified round trip, a clean delete, a per-point reader that makes R414c's
early exit real, and a pre-flight that catches a bad expression before the engine runs.

## What the next stage must know

1. **`test_calc_scratch_reuse` row SR5 will redden** and that is correct — it asserts the set of
   `::calc::` procs touching `xschem raw add` is exactly `{eval_rpn}`. Own the widening in the
   same change, as a derived set rather than a hand-kept list.
2. **PLAN 7.1 is largely already done.** `calc::tmpvec` exists with a collision probe (which is
   **case-insensitive**), and R402's cleanup already works — no `__calc_tmp*` survived either
   measured call. 7.1 is mostly fencing what exists, plus D11's three pre-flight rules.
3. **Clip (R304) is not wired** (`calc::inert {Clip} 6`, phase 6's). `cross` scans the whole sweep
   and says so in its header.
4. **Read the sweep by NAME, not index 0.** The fixture's `Operating Point` plot has no sweep
   column; its index 0 is `v(sq)`.
5. Registration is `hcases`, no display gate. Derived trailer **122/121/0/8**, `Δskips = 0`.
   Read it, do not check it.
