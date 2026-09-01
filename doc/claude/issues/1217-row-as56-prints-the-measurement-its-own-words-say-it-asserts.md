# 1217 - row AS56 prints the measurement its own words say it asserts

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6b, folded into the EXISTING row AS56 as a
fourth element, so it costs no new check. Was: OPEN - measured, not fixed; no
live gap at the time of filing.
**Filed by:** item S6a, write-up pass, 2026-08-31. Measured by that item's verify
pass; re-read here.
**Related:** [[1208]], whose fix this row verifies.

## What is wrong

Row **AS56** of `tests/headless/test_auto_specialize_1201.tcl` (and the
[[1208]] issue file beside it) states that the two header shapes the fingerprint
strip drops - `** sch_path:` and `** sym_path:` - are the *only* lines in those
decks carrying this checkout's own path, and that this **was measured, not
assumed**.

The row computes both numbers and prints them:

```
puts "AS-HDR lines carrying the checkout root: $HD_ALL of which headers $HD_LINES ..."
```

but the check asserts neither against the other:

```
[list [expr {$HD_LINES >= 1 ? 1 : 0}] ...]
```

`HD_MOVED` rewrites only the header lines, so a **non-header** line carrying the
repository root would stay identical in both halves and the stripped
fingerprints would still match. AS56 would pass while rows AS6 and AS26 had
quietly become checkout-specific again - which is exactly [[1208]]'s defect
coming back under a row written to prevent it.

Today there is no live gap: 15 of 15 root-bearing lines in those decks are the
two header shapes, measured on both arms and at a relocated root. This is a row
one `expr` short of proving its own claim, not a false green.

## What would fix it

Add the comparison the prose already makes - `[expr {$HD_ALL == $HD_LINES}]`
as a fourth element, expecting 1. If a deck ever grows another root-bearing line
(an `.include` written with an absolute path, say), the row reds and whoever
widened the strip has to measure it rather than assume it.

## Rows

This IS the row. It needs one element added, not a new row.

---

## FIXED, item S6b (2026-08-31)

Folded into the EXISTING row AS56 as a fourth element, `HD_ALL == HD_LINES`, so
it adds no check and no new fixture. Green before and after; it pins the fact
the row was already printing.
