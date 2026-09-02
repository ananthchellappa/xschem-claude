# 1259 — the value gate accepts a published zero, so a `savecurrents` run still declutters

Status: **open** (measured first-hand by item A5's adversary pass and again by
its write-up pass, 2026-09-02; **not fixed** — arguably not a defect, see the
open question) · Branch: `fluid-editing`
Related: **1244**, ruling **D-6**, invariant **I3**, item **A5-a**

## The defect, in one sentence

Item A5-a's gate asks whether a block row carries *anything after the `=`*; a raw
that publishes a column of `0.0` renders `zid = 0`, so the device is decluttered
on a number that carries no information — which is the shape of "got OP numbers"
D-6 was meant to exclude.

## Measured, first-hand, 2026-09-02, against the A5 binary

```
C2 vectors            = i(m1[zid]) | m1[zgm]
C2 raw loaded         = 0
C2 op_annot::text M1  = <<zid = 0|zgm = 0|>>
C2 mask 1 texts       = M1 VCW=1u PD {zid = 0} {zgm = 0}
C2 mask 9 texts       = M1 {zid = 0} {zgm = 0}
```

`VCW=1u` and the pin label `PD` are hidden in exchange for two zeros.

## Why it is a real PDK case, not a fixture artefact

`.option savecurrents` publishes `sky130` terminal currents `ig` / `is` / `ib` as
**0**, and `save [ib]` yields a `dims=0` column of `0.0` — both recorded in
`doc/claude/code_analysis/1244_op_param_list_measurements.md`. A user who runs
with `savecurrents` and registers those rows therefore gets a decluttered sheet
whose whole annotation is zeros.

## Not a regression, and not obviously wrong

Item A3's gate opened here too (a non-blank block), so nothing got worse. And
`::op_annot::eng_or_blank` prints a **measured** `0.0` as `0` deliberately: a
zero that the simulator actually reported is a fact about the circuit, and
invariant **I3** says a *missing* vector renders blank — it does not say a
measured zero should. Suppressing zeros would make a legitimately-zero current
indistinguishable from an absent one, which is the failure I3 exists to prevent.

## Why item A5 did not act on it (ladder L1, invariant I3)

The distinction the gate would need is **absent vs. zero**, and that distinction
does not exist in the block string A5-a reads — by design, because reading it
from a second source is issue **0466** re-opened (see the comment above
`annot_block_has_value()` in `src/actions.c`). Making it visible means the
*minter* publishing an absence count, i.e. the `::op_annot::dropped` side-channel
shape in `src/op_annot.tcl` — a file item A5 does not own, and a change that
belongs with item **B1**'s backend seam, where "a zero-length or `dims=0` vector
is **absent**, not zero" is already the stated rule.

**Rejected alternative:** treating the rendered string `0` as blank in the C
helper. It cannot tell a measured zero from an absent one, so it would suppress
the declutter on a device that really is at zero bias — a wrong answer in the
other direction, and one the user can never diagnose from the screen.

## Still open (the question a later item must put to the user)

Should a device whose every published OP number is **0** count as "got OP
numbers" for ruling D-6? If not, the fix is B1-shaped: `op_annot::text` (or
`op_param_set`) must distinguish an absent vector from a zero-valued one and the
gate must read that distinction, not the rendered digits.
