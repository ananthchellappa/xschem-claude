# 0874 — `text_hidden()`'s widened `hide=voltage` arm has no row: masks 4 and 5 are the only discriminating ones and no suite reaches them

**Status:** ✅ **FIXED — the prediction was MEASURED, 2026-08-27, and it holds.**
Sabotage variant **S6b** (reverting the arm at `src/actions.c:1555` to
`ANNOT_SHOW_VOLTAGE` alone, rebuilt) reddens **V32 and only V32**:

    FAIL: V32 ... -> {{0 0 1 1 0 0 1 1} {1 1 1 1 1 1 1 1}}
                 (exp {{0 0 1 1 1 1 1 1} {1 1 1 1 1 1 1 1}})

Masks 4 and 5 lose visibility, byte for byte as predicted. This is the variant that
reddened **nothing** when A3 ran it, so the row closes the gap it was written for.
The rest of the suite stays green (409 passed), confirming V32 is the sole
discriminator and that S6 (guard G6) cannot reach it — measured separately: under S6,
V32 stays green.

The closing condition below was met by measurement, not by prediction. Originally filed by the A3 write-up, 2026-08-27,
from the sabotage leg of the 0868 run. Class: **a guard no row can see.**

Owner: issue **0868**, `text_hidden()` in `src/actions.c` (~:1541).

## The code and the claim it makes

0868 widened the explicit `hide=voltage` arm:

```c
if(flags & HIDE_TEXT_VOLTAGE)
  return (xctx->annot_show & (ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN)) ? 0 : 1;
```

with a comment saying the implicit and explicit classes *"must not disagree about
which masks show a node voltage, or the same number would appear on one sheet and
vanish on another for the same mask"*. That is a real invariant, and it is
unguarded.

## Measured, 2026-08-27

A probe injected into `test_op_annot`'s own `u_hv` fixture, reading the visibility of
an explicit `hide=voltage` text at all eight masks:

```
mask   0 1 2 3 4 5 6 7
shown  0 0 1 1 1 1 1 1
```

**Masks 4 and 5 are the only discriminating ones** — 6 and 7 have bit1 set anyway, so
they are visible either way. The shipped rows never reach them:

* **U11** sweeps `{0 1 2 3}`
* **L8** uses masks 1 and 2
* **U29** has the same shape

So sabotage variant **S6b** — reverting that arm to `ANNOT_SHOW_VOLTAGE` alone —
flips masks 4 and 5 from visible to hidden, creating precisely the inconsistency the
comment says it is preventing, **and every suite stays green.**

0868's own sabotage table anticipated this: *"if S6b reds nothing behaviourally, that
arm needs its own structural row before landing."* It reds nothing, and no row was
added.

## Fix shape

Extend U11's sweep from `{0 1 2 3}` to `{0 1 2 3 4 5 6 7}` and pin the eight-element
visibility vector `0 0 1 1 1 1 1 1` for BOTH the implicit class (a plain
`@spice_get_voltage` floater) and the explicit `hide=voltage` text, in one row, so a
divergence between them is what reds. That is a behavioural row, which is stronger
than the structural fallback and costs no more.


---

# The row (A3h, 2026-08-27) — V32, behavioural, in `tests/headless/test_op_annot.tcl`

**Not** the shape this file recommends, and the difference matters. Extending U11's
sweep would have entangled the implicit class and the explicit arm in one row, and
sabotage **S6** (`annot_class_mask()`'s return, `src/actions.c:1533`) would then have
reddened it too — so a red could not say WHICH arm moved. V32 is a **separate** row on
a **separate** fixture, and the separation is the point:

* the fixture is a fresh sheet carrying a **schematic-own** `T {ZZG6BHIDDEN} … {hide=voltage}`
  — not a symbol floater and not a text carrying the annotation class — so it reaches
  the `HIDE_TEXT_VOLTAGE` arm and **not** `annot_class_mask()`, which returns 0 for it.
  S6 must therefore leave V32 alone, and S6b must red it alone;
* the mask is swept `0..7` and the row pins the eight-element vector
  **`0 0 1 1 1 1 1 1`** — measured on the committed binary, exactly as this file
  records it. Masks **4 and 5** are the whole discrimination;
* a **plain** control text on the same sheet is asserted visible at all eight masks.
  That is the anti-hollow half: *"not visible"* is satisfied by a fixture that never
  rendered at all, so without it the two leading zeros are indistinguishable from a
  broken SVG export.

Predicted: **S6b reds V32 and only V32**, at its mask-4 and mask-5 legs, the vector
becoming `0 0 1 1 0 0 1 1`. **If it reds nothing, this issue stays OPEN** and a
structural row over `text_hidden()`'s body is owed instead — with C comments stripped
first (`regsub -all {/\*.*?\*/}`), because the guard's own explanatory comment above
it names both `ANNOT_SHOW_VOLTAGE` and `ANNOT_SHOW_TRAN` and would match in its place.
