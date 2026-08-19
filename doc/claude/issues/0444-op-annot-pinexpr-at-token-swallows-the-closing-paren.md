# 0444 — a registered `pinexpr` whose @-token abuts `)` can never produce a number

Status: FIXED in the two shipped descriptors (S5). The underlying C tokenisation
is UNCHANGED and still bites any template written the natural way.
Found: S5 (the display formatter), doc/claude/specs/op_annotation.md.
Related: 0422 (the same SPACE(c) rule, for `devpath` templates), 0446.

## What is wrong

`xschem translate` tokenises on `SPACE(c)` only — `{\n, space, \t, \0, ;}`,
token.c:24. `)` is **not** in that set, so it does not terminate an @-token. In
the spelling both PDK descriptors shipped with,

    expr(@#1:spice_get_voltage - @#2:spice_get_voltage)

the second token is `@#2:spice_get_voltage)`, which misses `get_tok_value()` and
appends **nothing** (token.c:5351-5366). No error, no warning.

Measured live on one sky130 nfet with an annotated OP raw, same instance, same
call, the two spellings side by side:

    …spice_get_voltage)     ->  `0.9 - `    string is double -strict = 0
    …spice_get_voltage )    ->  `0.9`       string is double -strict = 1
    (vds behaves identically: ` -  ` vs 1.8)

An escaped `\ ` does not work; only a literal space.

## Why it mattered enough to fix outside S5's declared Files cell

`0.9 - ` is not a number, so S5's formatter renders it BLANK (I3, correctly). The
consequence is that on sky130 **and** gf180 — two of the three PDKs — the `vgs`
and `vds` rows would have been permanently blank for every device, on every run,
with the save cards present and everything else correct. S5's own acceptance
golden would then have blessed the defect in writing.

Every symbol shipped in this tree already spells it with the space
(`sky130_fd_pr/nfet_01v8.sym:65-66`, `xschem_library/devices/nmos4.sym:56-57`),
so the fix makes the descriptors agree with the tree's own convention rather
than introducing one.

## The fix

One space per line, four lines total:

    sky130A/sky130_procs.tcl:377-378
    gf180mcuD/gf180_procs.tcl:84-85

plus a `DO NOT TIDY IT AWAY` comment above each `foreach` (outside the braced
dict literal — inside it a `#` is dict DATA, not a comment).

`tests/headless/test_op_annot.tcl` guards it in three places: S28 on the stored
strings, S29 on the live translate with both spellings in one call, and P10's
translate golden, which moves from `{ - }` to `{ -  }` — the extra space IS the
token that used to be swallowed.

## Residual, NOT fixed here

The C is untouched: any user writing the natural `…(@a - @b)` in their own
descriptor, symbol text or template hits this silently. A `)`-terminates-a-token
change in token.c:24 would touch every @-token in the tree and is not an S5-sized
change. Options if it is ever taken up: terminate an @-token on `)` as well as
SPACE(c); or have `translate` warn once when an @-token misses `get_tok_value()`
and ends in a bracket. Both are user-visible and neither is ratified.

## Ratification owed

S5 edited two PDK procs files outside its declared Files cell (`src/op_annot.tcl`)
to make its own acceptance honest. Ratify the out-of-cell edit, or revert it and
ship `vgs`/`vds` permanently blank on sky130 and gf180.
