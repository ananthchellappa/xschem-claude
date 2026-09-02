# 1258 — the value gate accepts a descriptor label that contains an `=`

Status: **open** (measured first-hand by item A5's adversary pass and again by
its write-up pass, 2026-09-02; **not fixed**) · Branch: `fluid-editing`
Related: **1244**, ruling **D-6**, invariant **I5**, items **A3** / **A5-a**

## The defect, in one sentence

`annot_block_has_value()` (`src/actions.c`) splits every block row at the
**first** `=` on the line, so a descriptor whose *label* contains an `=` looks
valued even when the raw published nothing — and item A5-a's fix does not fire.

## Why it is reachable

Invariant **I5**: *"a user's `op_annot::register` in their own rc overrides the
PDK's, and takes effect on redraw"*. The label is whatever the user typed in the
`params` list. Nothing rejects an `=` in it, and `::op_annot::text` pads and
prints it verbatim:

```tcl
append txt [format "%-*s =" $w [lindex $r 0]] \n          ;# src/op_annot.tcl, the width pass
```

so the minted row for a label `v=x` is the literal `v=x =`. The C scan sees the
`=` inside the label, treats the `x` that follows as a value, and opens the gate.

## Measured, first-hand, 2026-09-02, against the A5 binary

```
op_annot::register wunmos [list devpath {@m.@path@name} params {{v=x zid 0} {q zgm 1}}]

C1 raw loaded         = -1
C1 op_annot::text M1  = <<v=x =|q   =|>>          (| = newline; NO values at all)
C1 mask 1 texts       = M1 VCW=1u PD {v=x =} {q   =}
C1 mask 9 texts       = M1 {v=x =} {q   =}
```

That is **the exact defect item A5-a was written to fix**, reproduced through a
label spelling: `VCW=1u` and the pin label `PD` are traded for two empty rows,
with `xschem raw loaded` = −1, i.e. before any simulation has been run. The
correctly-spelled control on the same fixture is A5's row **A30**, which is green.

## The repair, and why A5 did not take it

One character of narrowing: the mint writes the separator as `%-*s = %s`, so a
**valued** row always carries the three-byte sequence `` ` = ` `` (space, `=`,
space) and a blank row always ends `` ` =` `` at end of line. Requiring the
separator to be ` = ` — or, equivalently, taking the **last** `=` on the line —
closes it. Either is a two-line change inside the existing helper.

**Not taken by item A5** (ladder **L2**): it was measured by the adversary pass,
after the tiers, the six-variant sabotage matrix and the full audit had all been
run against the shipped helper. A silent widening of the predicate at that point
would ship a change with no sabotage row and no audit behind it, which is the
failure mode this batch has a standing rule about. It is filed instead, with the
fixture above, so the next crew that may build can add the row (a `params` list
with an `=` in a label, no raw, asserting mask 9 == mask 1) **and show it
failing** before fixing it.

**Rejected alternative:** validating the label at `op_annot::register` time and
refusing an `=`. It moves the check to the wrong layer — the block format is the
contract, not the registry — and it would make a user's rc entry fail loudly for
a label that renders perfectly well.

## Still open

* Whether a label containing `=` should be *rejected*, *escaped*, or merely
  parsed correctly. This issue recommends parsing correctly (the separator is
  ` = `), because that leaves `::op_annot::text` — the one minter, invariant I1 —
  untouched.
