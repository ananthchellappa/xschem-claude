# 0444 — a registered `pinexpr` whose @-token abuts `)` can never produce a number

Status: **RATIFICATION SUPERSEDED, C DIRECTION RULED (the user, 2026-08-22).**
The out-of-cell edit this issue owed a ratification for NO LONGER EXISTS -- ruling
D9 deleted the whole `pinexpr` entry it lived on. The underlying C tokenisation is
UNCHANGED and still bites any template written the natural way; the user has ruled
on what to do about that. See "RULING" at the bottom.
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

## Ratification owed -- SUPERSEDED, not answered

S5 edited two PDK procs files outside its declared Files cell (`src/op_annot.tcl`)
to make its own acceptance honest, and owed a ratification for it.

**That edit is gone.** Measured 2026-08-22:

```
9fe40128  (S5)  added `…spice_get_voltage )`   -- the load-bearing space
8534eb11  (D9)  removed the whole pinexpr entry the space lived on
```

`grep -rn spice_get_voltage sky130A/*.tcl gf180mcuD/*.tcl ihp-sg13g2/*.tcl`
returns **nothing**. Both MOS descriptors now read:

```tcl
params {{id id 0} {gm gm 1} {gds gds 1} {vgs vgs 2} {vth vth 2} {vds vds 2}}
```

So there is no out-of-cell edit left to bless. The alternative the debt offered --
*"revert it and ship `vgs`/`vds` permanently blank"* -- is also false now: under D9
those are real BSIM4 instance parameters read straight from the raw (kind 2), not
`pinexpr` output, so a revert would not blank them.

`owed.sh clear rule 0444` -- closed as superseded, 2026-08-22.

---

## RULING (the user, 2026-08-22) -- warn once, do NOT change the parsing

The question put to the user, in plain terms: a user writes `(@a - @b)` the
natural way in her own descriptor or symbol; XSCHEM reads the second name as
`b)`, finds nothing, substitutes nothing, and the line silently comes out short.
Three options were offered -- warn once; add `)` to `SPACE(c)`; document only.

**Chosen: warn once, leave `token.c:24` alone.**

When an @-token finds no value AND ends in a bracket, say so -- once, in the CIW
and in the logfile.

### Why this and not the parser change

Adding `)` to `SPACE(c)` fixes the *cause* rather than reporting it, which is
normally the better instinct. It was not chosen because that macro governs
**every** @-token in the tree -- symbols, templates, the netlist backends,
`devpath` strings -- so any place a `)` is today part of a token or of a value
changes meaning at once. That is an audit, not a fix, and it is not what this
issue is sized for. The user's decision leaves that door open; it does not shut it.

### This is the SAME mechanism as I8, and must be built with it

Issue **0604** (invariant **I8**, ratified by D9) already owes exactly this shape:
*a thing the tool was asked for and did not get is REPORTED, not merely blank*.
Both need the same three answers -- where the on-screen half goes, how the
once-per-pass dedup is keyed, and how a single miss reads differently from a
wholesale one. Building them separately would produce two warn-once mechanisms
with two dedup keys, which is the I1 drift shape.

**The bracket case generalises the I8 one and should be folded into it**: I8 as
filed covers *the raw did not deliver this vector*; this adds *the substitution
never asked for it, because the name was mis-tokenised*. From the user's chair
both are "the number is blank and nothing told me why", and the second is worse,
because her descriptor never even reached the simulator.

Recorded as a requirement on 0604. No separate issue number was minted.
