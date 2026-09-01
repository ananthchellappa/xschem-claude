# 1215 - two copies asking for the same settings get two identical cell bodies, and the note says they share one

**Branch:** annotate
**Status:** FIXED 2026-08-31 by item S6b **for two copies on one design that
XSCHEM can compare**. Verified by rows AS70 and AS71 (the control that keeps
[[1202]] closed). Across sheets the note's "shares that one" sentence is still
false and is recorded as [[1220]], with row AS85.
Was: OPEN - measured, not fixed.
**Filed by:** item S6a, write-up pass, 2026-08-31. Measured by that item's verify
pass and re-measured independently here on the shipped binary.
**Caused by:** [[1202]]'s fix (GUARD AS-TYPEDNAME), landed in item S6a. This is
the over-refusal twin of that guard.

## What the user sees

Two copies of a cell ask for exactly the same thing. One of them also hand-types
the cell name the tool would have invented. Instead of sharing one version of
the cell, the deck gets **two identical ones** under two nearly identical names -
and the info window says the opposite of what happened.

## Measured, verbatim (2026-08-31, shipped binary)

```
C {w/wp.sym} 120 0 0 0 {name=xA W_P=0.5 modelp=pfet_01v8_lvt}
C {w/wp.sym} 320 0 0 0 {name=xB W_P=0.5 modelp=pfet_01v8_lvt schematic=wp__modelp_pfet_01v8_lvt}
```

Deck:

```
xA net1 wp__modelp_pfet_01v8_lvt_1 W_P=0.5
xB net2 wp__modelp_pfet_01v8_lvt W_P=0.5
.subckt wp A  W_P=1
.subckt wp__modelp_pfet_01v8_lvt_1 A  W_P=1
.subckt wp__modelp_pfet_01v8_lvt A  W_P=1
```

The two specialised bodies measured: **298 bytes each, identical**. The same
circuit twice, under two names one character apart. And the note about `xA` ends:

> ... Any other copy of wp on this design that asks for the same settings shares
> that one. You do not have to add anything to the sheet.

`xB` asks for the same settings and does **not** share it. The sentence is
false in the one case that produced it, which is the class RULING D5-1 covers.

Before [[1202]]'s fix these two shared one body, which was the right deck for
the wrong reason - the guard exists because in the [[1202]] case the two copies
ask for *different* things.

## Cause

GUARD AS-TYPEDNAME (`auto_spec_collides()`, `src/actions.c`) refuses a candidate
name that any copy on the sheet has typed, without asking whether that copy is
asking for the same settings. It cannot ask cheaply: at minting time the
hand-typed name is only a string inside another copy's property list, and the
tool does not know what settings the cell it names carries.

## What would fix it

When a hand-typed name blocks a candidate, compare the two copies' setting sets
before falling through to the `_1` suffix: identical set, identical intent, so
point both at the hand-typed name and say so. That comparison is available -
`auto_spec_qualifies()` already builds the canonical set for the copy being
netlisted, and the blocking copy's property list is right there in
`xctx->inst[]`.

Whatever is done, **the sentence has to match**. A note that says other copies
asking for the same settings share this one must not be printed beside a second
identical body.

## Reachability

Contrived - the designer has to hand-type the invented spelling on one copy of
a matched pair. Filed because it is the twin the [[1202]] fix creates, and
because half the defect is a false sentence rather than a wasteful deck.

## Rows

None. A row is the two-line fixture above: assert one shared body, or - if the
duplicate is deliberate - assert the note does not claim sharing.

---

## FIXED, item S6b (2026-08-31)

GUARD AS-TYPEDSAME, inside GUARD AS-TYPEDNAME in `src/actions.c`. A cell name a
designer typed by hand is no longer "taken" when the copy that typed it is a
copy of the SAME cell asking for the SAME settings: XSCHEM adopts the name the
designer typed, both call lines name it, one cell body is written, and the note
that says "Any other copy ... that asks for the same settings shares that one"
is finally true.

The settings of a hand-named copy are read through the new
`lost_attrs_typed_copy()` (`src/token.c`), which is the same classification with
the "this copy named its own cell body" test lifted -- one function with a flag,
not a second hand-written copy of the tests.

**The invariant this rests on, and it is in the comment:** equal keys mean equal
cell bodies. The only kind of setting that can make two bodies of one cell
differ is one the SPICE line drops and the drawing reads; everything the SPICE
line does read is a subcircuit parameter resolved per call line, the same body
either way.

A copy whose settings cannot be worked out loses the comparison and the name
stays taken -- today's behaviour. Answering "I do not know" can only cost a
numeric suffix; it can never share a body between two copies that wanted
different things.

**Rows:** AS70 (the fix, including that the sharing sentence is present), AS71
(control: the same shape with DIFFERENT settings still gets two cells with the
invented name stepping aside -- this is what keeps 1202 closed).

**On the user's ruling queue:** the cell name in the deck changes for this
shape, from two names to one, and the surviving name is the designer's rather
than the tool's.
