# 1624 — a bus wire labelled with angle-bracket range syntax netlists silently wrong

**STAMP:** `v1 claim=open tree=1f42914d stamped=2026-09-29 fix=untried open=4`

Status: **OPEN**, filed 2026-09-29. Found while reconnoitring wish item 2's "vertical justification"
half; it is **not** caused by that work and is not fixed by it.
Measured on this tree at `1f42914d` · Branch: `fluid-editing`
Related: batch `doc/claude/wire_label_vjust_batch/`, receipt `receipts/R-recon-vjust.md` (Angle 3,
where the measurement lives); issue **1623** (the stacked-label feature, which deliberately keeps the
`<>`→`[]` normalisation that hides this).

## The defect

**In xschem, `<3:0>` is not bus-range syntax.** `<` and `>` are ordinary identifier characters in the
`LAB`, `LAB_NUM` and `LAB_NUM_SP` classes of `src/parselabel.l`. So `bg_trim<3:0>` is **one scalar
net** whose name happens to contain the characters `<3:0>`.

Label an 8-bit bus wire that way and the netlist is **wrong, with no warning of any kind.** Measured
end to end against a subcircuit symbol with one 8-bit bus pin (`name=P[7:0]`):

Correct, with square brackets — `lab=bg_trim[3:0],en_fast,iref_trim[2:0]`:

```
x1 bg_trim[3] bg_trim[2] bg_trim[1] bg_trim[0] en_fast iref_trim[2] iref_trim[1] iref_trim[0] bus8
```

Wrong, with angle brackets — `lab=bg_trim<3:0>,en_fast,iref_trim<2:0>`:

```
x1 bg_trim<3:0> en_fast iref_trim<2:0> bg_trim<3:0> en_fast iref_trim<2:0> bg_trim<3:0> en_fast bus8
```

`xschem expandlabel` on the angle form reports a multiplicity of **3**, not 8. The three-element list
is then **cycled over the eight pins**, so `bg_trim<3:0>` lands on pins 7, 4 and 1 — three different
bits of the bus shorted to one scalar net, and two bits of `iref_trim` silently dropped.

⚠ **Zero diagnostics.** No `yyerror`, no stderr line, no dialog. The Angle 3 crew counted: all 14
`yyerror` lines in its run came from a different probe case, none from this one. A reviewer reading
the deck sees eight plausible net names in the right column count and moves on.

## Why nobody has hit it yet, and why that is fragile

The Add Wire Label form protects you, but by accident of implementation rather than by design:
`addlabel::expand_names` normalises `<>`→`[]`, and it is the **only** path to `::label_new_name`. So
a label typed into that form as `bg_trim<3:0>` is stored and drawn as `bg_trim[3:0]` and netlists
correctly.

Every other route to a label's `lab=` property is unprotected:

* the property editor / `Edit ▸ Properties` on an existing label,
* `xschem setprop instance <name> lab <value>` from Tcl or the CIW,
* paste, or a copied label from another schematic,
* an imported or hand-edited `.sch` file,
* a generator or script that writes `lab=` directly.

⚠ **And the habit runs the wrong way.** This tool's users come from Cadence, where `<3:0>` *is* the
bus syntax — the user's own description of wish item 2 used `bg_trim<3:0>,en_fast,iref_trim<2:0>` as
the natural spelling. So the population most likely to type the dangerous form is the population the
tool is aimed at.

## What is NOT the defect

* **Not** a regression, and not introduced by issue 1623. The grammar has always treated `<` and `>`
  as name characters.
* **Not** an argument for making `<3:0>` mean a range. That would change the meaning of every
  existing label containing those characters, and a net legitimately named `a<b` is expressible today.
  Whatever is done here must not silently re-interpret existing designs.
* **Not** the form's fault. `expand_names` normalising is the thing that keeps people safe; the gap is
  everywhere else.

## Still open (open=4)

1. **Decide the remedy, which is a product question and therefore the user's.** Three shapes, in
   ascending intrusiveness: (a) **warn** at netlist time when a bus-width mismatch is resolved by
   cycling a short list over a wide pin — the honest minimum, and it catches more than this one
   spelling; (b) **warn** specifically when a `lab=` value contains `<` or `>` with a digit-colon-digit
   between them, which is narrow but unambiguous; (c) **normalise `<>`→`[]` everywhere a label is
   accepted**, matching what the form already does, which is the most helpful and the most likely to
   surprise someone who meant the literal characters.
2. **There is an existing checker that nearly does (a).** `hilight_net_pin_mismatches()` in
   `src/hilight.c` detects net/pin width mismatches — but it is a **user-invoked highlight command**,
   not a netlist-time guard. Establishing whether its predicate can be reused at netlist time is the
   concrete first step and needs no new detection logic.
3. **The cycling behaviour itself deserves a decision.** Silently repeating a 3-element list across 8
   pins is what converts a typo into wrong connectivity. Whether that is ever *wanted* — some tools
   treat it as broadcast — is unestablished here and should be checked before it is called a bug.
4. **No fence exists.** A row that netlists the angle form and asserts the multiplicity is the whole
   defect in one assertion, and it can be written today, before any remedy is chosen. It would redden
   now, which is why it is not added yet: per CLAUDE.md a standing red is a defect and not furniture,
   so the row goes in with the fix, not ahead of it.

⚠ One measurement worth keeping for whoever takes this: the third spelling the crew tried — a quoted
`lab="bg_trim[3:0]\nen_fast\niref_trim[2:0]"` with real newlines — is worse than both. The newline
after `]` drives `parselabel.l` into its `parse_trailer` start condition, so `en_fast\niref_trim` is
absorbed as a bus **trailer** and concatenated onto every bit, and the resulting net names contain
literal newlines that break the SPICE deck across physical lines. That is recorded in issue 1623 as
the reason stacked labels are a display transform and never a stored-string change.
