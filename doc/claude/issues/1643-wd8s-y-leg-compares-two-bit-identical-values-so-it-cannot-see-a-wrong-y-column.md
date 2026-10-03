# 1643 — `WD8`'s Y leg compares two BIT-IDENTICAL values, so it cannot see a wrong Y column

**STAMP:** `v1 claim=open tree=a81ca259 stamped=2026-10-03 fix=none open=1`

Status: **OPEN**, found 2026-10-03 by the Calculator batch's stage J recon critic while choosing
a fixture for a new row. A **test** defect, not a product one: the product is correct and the row
that is supposed to prove it would pass if it were not.

Area: row `WD8` of `tests/headless/test_calc_wave_dest.tcl` — the end-to-end row this batch has
been citing as proof of the destination hand-off.
Found: printed the actual series every fixture column yields at two levels, and compared the
spread against the suite's own tolerance.

## The defect

`WD8`'s end-to-end row drives `v(sq)` at the band's level, and compares the Y column it reads back
out of the destination against a derived list **element-wise** with `near` at a **relative**
`WDTOL` of `1e-7`:

```tcl
set g [wd_call dutyCycle {v(sq)} $L 0 0 start]
set h [wd_call wave_dest [wd_key $g sweep] [wd_val $g]]
...
check "WD8 END TO END: ..." [list ... [wd_listcmp $gy $duty $WDTOL]] {measured measured ok ok}
```

⚠ **The band's level is `1/3`, and there the two values are BIT-IDENTICAL.** Measured on the
committed fixture, driving the real product:

| column | level | the two per-cycle fractions | relative spread | can the row see a wrong Y? |
|---|---|---|---|---|
| `v(sq)` | **1/3 — WD8's own level** | `0.31666666666666676`, `0.31666666666666676` | **exactly 0** | **no** |
| `v(sq)` | 0.5 | `0.3000000000000002`, `0.29999999999999966` | 1.85e-15 | no |
| `v(lp)` | 1/3 | `0.33106652549724797`, `0.3310059686087729` | **1.83e-4** | yes |
| `v(lp)` | 0.5 | `0.2999385393208259`, `0.2999017475874794` | **1.23e-4** | yes |

⚠ **A CORRECTION TO THE FIRST REPORT OF THIS DEFECT, KEPT VISIBLE.** The recon critic that found
it measured at `L = 0.5` and quoted 1.8e-15, and the driver repeated that figure into a commit
message as though 0.5 were the row's level. It is not: `WD8` sets `set L [expr {1.0/3.0}]`, where
the spread is not small but **zero** — the two fractions are the same double. So the original
report was right about the mechanism, wrong about the number, and **understated the defect**. This
is the fourth time in this batch that a figure quoted rather than re-derived has been wrong, which
is why CLAUDE.md's rule is to quote the shape and let a row carry the number.

So a producer that

* writes `y[0]` into **both** points, or
* writes the Y column **reversed**, or
* writes a **constant**,

passes `WD8`'s Y leg. ⚠ It was **confirmed by attack**: an adversary was asked to build the
destination correctly in every structural respect and fill the Y column wrong in a way the fixture
hides, precisely because this measurement said it would work.

**The X side is sound and should be said so.** `sweep` comes back as
`{0.0009666666666666667 0.004966666666666667}` — a factor of five apart — so `WD8` genuinely does
discriminate a wrong X column, which is what the band was written for. The blindness is one leg
wide, not the whole row.

The whole committed fixture is flat on the Y side: `riseTime` per edge on `v(sq)` agrees to ~4e-15,
and on `v(lp)` elements 1 and 2 agree to 9e-15. Exactly two series discriminate, both on `v(lp)`,
and `dutyCycle` at `L = 1/3` is the better of them.

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
