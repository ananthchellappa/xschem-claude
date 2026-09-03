# 1258 — the value gate accepts a descriptor label that contains an `=`

Status: **FIXED by item A6-a**, 2026-09-02 · Branch: `fluid-editing`

> ⚠ **NOT LANDED. The fix below was implemented, built and verified, then its
> write-up agent destroyed `src/save.c`'s half with `git checkout -- src/save.c`.
> The code is preserved in
> `doc/claude/op_param_batch/A6_working_tree_UNVERIFIED.patch` and in the working
> tree; PLAN.md's A6 entry says what to do first. Everything recorded below was
> measured and is correct.**

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

---

## FIXED — item A6-a, 2026-09-02

**Before** (Measure agent's transcript, `xschem raw loaded` = −1, i.e. before any
simulation, `params {{v=x zid 0} {q zgm 1}}`):

```
PROBE 1258 op_annot::text(M1) block = v=x =|q   =|
PROBE 1258 mask1 texts = M1 P6W=1u P6GATE {v=x =} {q   =}
PROBE 1258 mask9 texts = M1 {v=x =} {q   =}
PROBE 1258 mask9==mask1 (1 == gate correctly CLOSED, 0 == decluttered on a valueless block) = 0
PROBE 1258 CONTROL mask9==mask1 (expected 1: no value, so no declutter) = 1
```

**After.** `annot_block_has_value()` (`src/actions.c`) splits each block row at
the **LAST** `=` on the line instead of latching the first. Body unchanged in
every other respect — still a pure function of its argument, so row A35's
purity slice is unmoved.

**⚠ THE REPAIR IS NOT THE ONE THIS ISSUE RECOMMENDED, and the refuted sentence is
named.** The "Still open" clause above said:

> This issue recommends parsing correctly (the separator is ` = `)

A label spelled `a = b` mints the **blank** row `a = b   =`, which *carries* the
` = ` separator and which the separator reading therefore calls **valued**. The
last-`=` reading calls it blank, correctly. Both are two-line repairs; only one
is right. Row **A44** of `tests/headless/test_annot_declutter_1244.tcl` is that
difference expressed as a check, and it is red under the separator repair.
Ladder rung **L2**. Also rejected, as this issue already did: validating the
label at `op_annot::register` time, which moves the check to the registry layer
and makes a perfectly renderable rc entry fail loudly.

**Rows.** A42 (a `=`-bearing label over no raw: mask 9 == mask 1, the user's
parameter and pin label survive) · A43 (the same label over a **valued** raw is
still decluttered — the row that reds a fix refusing any two-`=` row) · A44 (the
last-`=` contract).

**Adversary battery, all eight shapes held**: `zid` (control), `v=x`, `a=b`,
`a=b=c`, `zid=` (trailing), `=z` (leading), a label containing a CR, and a label
containing a TAB plus `=`. No fooling case was constructible within the mint
contract — the value half is always `eng_or_blank()` output, which can neither
contain nor end in `=`.

**Sabotage.** `SB-A6a-FIRSTEQ` (A5's first-`=` latch restored verbatim) →
**exactly** A42 and A44 red, nothing else. `SB-A6a-ALWAYS`
(`return 1;`) → 17 red.
