# 1216 - one sentence about a setting the cell never reads is written out in four places

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6b. Verified by row AS75. Was: OPEN -
measured, not fixed; latent, the four copies agreed at the time of filing.
**Filed by:** item S6a, write-up pass, 2026-08-31. Measured by that item's verify
pass; the line numbers below were re-checked here.
**Caused by:** [[1205]]'s fix, which split the netlist warning's advice into four
shapes. RULING D5-4.

## What is wrong

RULING D5-4: *a user-facing sentence is minted in ONE place and rendered by
callers.* The opening clause of the netlist warning - the part that tells the
designer their setting went nowhere - is now a **separate string literal in each
of the four advice shapes**:

```
src/token.c:3725:  "%s never reads %s when the netlist is written", e_cell, e_prop);
src/token.c:3739:  "%s never reads %s when the netlist is written", e_cell, e_prop);
src/token.c:3754:  "%s never reads %s when the netlist is written", e_cell, e_prop);
src/token.c:3769:  "%s never reads %s when the netlist is written", e_cell, e_prop);
```

All four take the same two arguments, `e_cell` and `e_prop`. Only one of the
four is pinned by a row: `tests/headless/test_unused_attr_0970.tcl` asserts the
phrase on the population that reaches shape 2. Rows AS46, AS49 and AS54 assert
their own shapes' *advice* text, not this clause. Three of the four can drift
apart - a reworded warning, a typo, a changed tense - with every suite green.

The letter of D5-4 is not broken: the assembled sentence still goes out through
one `my_snprintf`. The spirit is: the words a user reads exist in four editable
places, and three of them are unwatched.

## What would fix it

Hoist one `my_snprintf(mid, sizeof(mid), "%s never reads %s when the netlist is
written", e_cell, e_prop);` above the if-chain and have all four shapes render
`mid`. The arguments are already identical, so this is a move, not a redesign.

## Rows

A structural row over `warn_unused_instance_attr()`'s own body, in the shape rows
AS50 and AS53 already use: the literal appears **once**. Or, behaviourally, a
row that asserts the clause on all four populations - the four shapes are
already reachable from the existing fixtures.

---

## FIXED, item S6b (2026-08-31)

The clause is minted once, above the shape chain in
`warn_unused_instance_attr()` (`src/token.c`), and the one shape that genuinely
differs -- the setting DOES reach another netlist of the same cell -- overwrites
it. Four literals became one, and issue 1213's new fifth shape did not make it
five. Row AS75 counts the literal in the comment-stripped file: exactly one.
