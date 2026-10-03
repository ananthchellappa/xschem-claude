# 1643 — `WD8` drives a fixture whose two values agree to 1.8e-15, so it cannot see a wrong Y column

**STAMP:** `v1 claim=open tree=a81ca259 stamped=2026-10-03 fix=none open=1`

Status: **OPEN**, found 2026-10-03 by the Calculator batch's stage J recon critic while choosing
a fixture for a new row. A **test** defect, not a product one: the product is correct and the row
that is supposed to prove it would pass if it were not.

Area: row `WD8` of `tests/headless/test_calc_wave_dest.tcl` — the end-to-end row this batch has
been citing as proof of the destination hand-off.
Found: printed the actual series every fixture column yields at two levels, and compared the
spread against the suite's own tolerance.

## The defect

`WD8` drives `v(sq)`. Measured, `calc::dutyCycle {v(sq)} 0.5 0 0 start` answers

```
value = {0.3000000000000002 0.29999999999999966}      relative spread 1.8e-15
sweep = {0.001 0.005}
```

against the suite's own `WDTOL` of **1e-7**, with `near` being a *relative* comparison.

So the two Y values are **indistinguishable at the row's own tolerance**, and a producer that

* wrote `y[0]` into **both** points, or
* wrote the Y column **reversed**, or
* wrote a constant,

passes `WD8`. The row reads as coverage of the destination hand-off and does not discriminate that
hand-off's most obvious defect. ⚠ It was **confirmed by attack**: an adversary was asked to build
the destination correctly in every structural respect and fill the Y column wrong in a way the
fixture hides, precisely because this measurement said it would work.

The whole committed fixture is this flat: `riseTime` per edge on `v(sq)` agrees to ~4e-15, and on
`v(lp)` elements 1 and 2 agree to 9e-15. **One** series on the fixture discriminates —
`dutyCycle` on `v(lp)` at `L = 0.5`, `{0.2999385393208259 0.2999017475874794}`, a relative
**1.2e-4**.

## Why this is the same family as a trap the batch already recorded

`DESTINATION_CONTRACT.md` §11(c) records that *the precision band's level is load-bearing*: at
`L = 0.5` a quantity came out at 2.2e-16, **inside** a 1e-12 door, so a discrimination row there
was **red on correct code** and the level had to move to `L = 1/3`.

This is the same mechanism from the other side. There a fixture choice made a correct
implementation look broken; here it makes a broken implementation look correct. **The lesson is
one lesson:** a row that compares two numbers must be driven on inputs whose two numbers actually
differ by more than the tolerance, and that has to be *measured* when the row is written, not
assumed from the fixture's name.

## The fix

Drive `v(lp)` and carry an explicit **distinctness leg** — a check that the two values the row is
comparing are not equal at the row's own tolerance — so the row cannot silently become vacuous
again if the fixture is ever regenerated. A non-vacuity leg is what this batch's derivation rows
already do for *populations*; this is the same discipline for *values*.

⚠ **Two points is also the structural ceiling here**, and that is worth saying in the same breath
because fixing the fixture does not fix it: `v(sq)` has three rising crossings, so `dutyCycle`
yields at most two periods, and three is the most any verb yields on the committed fixture
(`calc::cross {v(sq)} 0.5 0 rising` → 3). Two points cannot catch a stride, an off-by-one inside
the fill loop, or a dropped middle sample, and gives the X list only two values to be misordered.
A longer series needs a new fixture column or an RPN that manufactures one.
