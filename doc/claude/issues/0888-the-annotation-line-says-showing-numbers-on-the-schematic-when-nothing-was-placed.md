# 0888 — the annotation line says "Showing … on the schematic" when nothing was put there

**Status:** **OPEN**. Found by the item A11 verification pass, re-measured
independently at write-up on 2026-08-28. **Introduced by 0886**, the
plain-English wording pass — this is not a pre-existing defect and it is not a
behaviour bug. It is a wording defect, and the remedy is a wording decision the
user has not made, so it carries a rule debt under this number rather than a
quiet fix.

## What the user reads

Press **6** on a cell that has never been simulated:

    Showing device operating-point values on the schematic. There is no results
    file at /home/analog/proj/bg/run.raw yet. Run a simulation first.

Nothing is on the schematic. The first sentence says something is.

The sharpest one is the unreadable-file state, where the two halves contradict
each other inside a single line:

    Showing device operating-point values on the schematic. Could not read the
    results file /home/analog/proj/bg/run.raw, so nothing was placed on the
    schematic.

Measured verbatim, 2026-08-28, `cadence::_annot_msg 1 <state> <path> {}`, on the
shipped tree:

| state | what the user reads |
|---|---|
| `noraw` | `Showing device operating-point values on the schematic. There is no results file at <path> yet. Run a simulation first.` |
| `nopath` | `Showing device operating-point values on the schematic. No results file has been found for this cell. Run a simulation first.` |
| `failed` | `Showing device operating-point values on the schematic. Could not read the results file <path>, so nothing was placed on the schematic.` |
| `noop` | `Showing device operating-point values on the schematic. The loaded results do not include an operating point, so there are no device values to show. …` |
| `stale` | `Showing device operating-point values on the schematic. The results file run.raw is older than the circuit it describes, so it was not used - it is from an earlier run. Run the simulation again.` |

Five refusal states × seven non-zero masks = **35 combinations**, every one of
them opening with a claim about the screen that the rest of the line then
withdraws.

## Why it happens

`cadence::annot_mode` (`utils/annot_mode.tcl`) writes the mask **before** it
knows whether anything can be annotated:

    xschem set annot_show $mask      ;# line 607
    set state off
    …                                ;# the state is decided after this

and `cadence::_annot_msg` builds the line as `<mask clause> <state clause>`. The
mask clause is therefore emitted for every state.

The mask clause used to be a claim about a **mode** — `OP annotation ON (device
OP info)` — which is true in all five states: the mode really is on, the sheet
really does carry the `-` placeholders invariant I3 asks for, and a later
successful run really will fill them. 0886 rewrote it into a claim about the
**screen** — `Showing … on the schematic` — and a claim about the screen is
false whenever the screen has nothing on it.

## The pass's own reasoning already condemns it

`_annot_msg`'s `notop` guard carries this comment verbatim
(`utils/annot_mode.tcl`, and it was written by the pass that introduced the
defect):

> ⚠ IT RETURNS BEFORE THE MASK SWITCH, AND THAT IS THE POINT, NOT AN
> OPTIMISATION. Every other sentence in this proc opens with "Showing …" …
> which is a claim about what the screen is now showing. On both refusal paths
> the mask is never written, or is written and put straight back, so that prefix
> would describe a change that did not happen — RULING D5-1's shape, a caption
> with no measurement behind it.

That reasoning was applied to one state and to no other. The five states above
are the same shape: the mask **is** written, but nothing is painted, so the
caption still has no measurement behind it.

## Why no row saw it

Every affected sentence has a byte-exact golden — `A11_M1` plus the state clause
— and the goldens were written from the rendered output. A golden the crew
wrote from the code cannot tell the crew the code says the wrong thing; that is
0886's own recorded warning, hitting the sentence set it was written to protect.
Row **A11-7**'s ban list looks for the program's vocabulary, not for a false
claim, and there is no jargon here — the sentence is plain English and wrong.

## What is NOT wrong

Nothing about the behaviour. The mask really is armed, the placeholders really
are on the sheet, the refusal really does refuse, and the state clause is
accurate in all five cases. Only the opening clause is at fault.

## The decision the user has to make

Three shapes, and the choice is theirs:

1. **Say the mode, not the screen, whenever the state is a refusal** — e.g.
   *"Device operating-point values are turned on, but nothing is on the
   schematic yet. There is no results file at … yet. Run a simulation first."*
   Longest, and the most explicit; costs the most against the 255-byte budget
   (issue 0639), which is already eliding 62 of 192 combinations.
2. **Drop the mask clause entirely on a refusal**, exactly as the `notop` guard
   already does — *"There is no results file at … yet. Run a simulation
   first."* Shortest, buys budget back, and loses the confirmation that the key
   press did arm the mode.
3. **Keep it as it is** and accept that the opening clause describes the mode
   the user just chose rather than the pixels.

Recorded as a rule debt under this number. Until it is ruled, nothing changes.

## Acceptance rows this will need

A row that renders all 35 mask × refusal-state combinations and asserts none of
them claims the schematic is showing something. Note that such a row must not be
a substring ban on `Showing`, because option 1 keeps a positive clause — it has
to compare against the ruled shape, byte for byte, the way `A11-12` already does
for the state clauses.
