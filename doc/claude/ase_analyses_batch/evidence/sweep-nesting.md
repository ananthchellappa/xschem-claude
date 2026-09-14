# `.dc` nests exactly twice, and it drops the rest **in silence**

**Measured 2026-09-13 by the driver**, on **both** binaries, while pre-checking `PLAN.md` §11's
foundations. Stage 11's whole sweep design rests on how deep a DC sweep can nest, and the plan
states the depth (*"`.dc` nests exactly twice"*) without saying what happens to a third.

## What happens to a third

```
v1 a 0 1   v2 b 0 1   v3 c 0 1
r1 a m 1k  r2 m b 1k  r3 m c 1k

dc v1 0 1 0.5 v2 0 1 0.5 v3 0 1 0.5
```

| what was asked | rows produced | rc | stderr |
|---|---|---|---|
| two sweeps (`v1`, `v2`) | **9** | 0 | — |
| **three** sweeps (`v1`, `v2`, `v3`) | **9** | 0 | **empty** |
| **four** sweeps | **9** | 0 | **empty** |

**Identical on both binaries.** And the values are byte-identical too — `diff` of the two printed
tables is empty — so the third sweep did not merely fail to add rows, it **changed nothing at all**.

A user who asks for 3 × 3 × 3 = **27** operating points gets **9**, at rc 0, with nothing written
to stderr and nothing in the log to read. The extra sweep specification is consumed and discarded.

## Why this is a design constraint and not a curiosity

**ASE-L must REFUSE a third sweep level rather than pass it through.** This is the
*accepted-and-inert* class, and it is now the **fourth** member this batch has measured:

1. `set measureprec=10` on apt 45.2 — accepted, ignored, `meas` still prints 6 digits
   (`evidence/binary-differences.md` #5).
2. `set interp` on an AC or nested DC run — accepted, prints *"Interpolated raw file data!"*,
   changes nothing (`evidence/interp.md`).
3. `.options optran 0 0 0 0 0 0` and two other spellings — accepted, rung 4 still runs
   (`evidence/ladder-streams.md` §4).
4. **A third `.dc` sweep — accepted, silently dropped.**

The pattern is sharp enough to be a rule for the whole batch: **ngspice's usual answer to a request
it cannot honour is to take it and say nothing.** So *"the simulator did not complain"* is not
evidence that a setting reached anything, and every option ASE-L offers needs a measurement that it
does something — not a measurement that it is accepted.

That is also why a refusal is the right shape here rather than a caution. A caution says *"this may
not do what you want"*; what is true is *"this will produce a different experiment from the one you
described, and nothing downstream will tell you"*.

## What this leaves

* **Not measured:** whether a third sweep is dropped by the parser or by the analysis, and whether
  `dc` with a *source that does not exist* complains where a third *valid* one does not. Neither
  changes the rule for ASE-L, which is to refuse at the form.
* **Not measured:** the same question for `sp`, `ac` and `noise`, none of which takes a nested
  sweep at all today.
