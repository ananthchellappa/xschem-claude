# 0884 - the waveform viewer plots a results file the annotation refuses as stale

**Status:** OPEN, needs a USER RULING. Filed 2026-08-27 by item A10 while closing
issue 0881. Not a defect in either half on its own — it is two correct rules
colliding, and only the user can say which wins.

## What the user can be shown

1. Run a transient. The waveform viewer plots it. `ase::last_rawfile` answers
   "the path, if the file exists" and deliberately checks nothing else — the
   three waveform callers are right to plot the last good run, and refusing to
   draw traces after a failed netlist would be a regression (that reasoning is
   written into `ase::ui::annot_ensure_loaded`, `src/ase_window.tcl`).
2. Edit the schematic, or re-netlist without re-running, so the deck on disk is
   now newer than the `.raw`.
3. Put a cursor on and press **Alt-Shift-6**, or tick
   **Results > Annotate > Transient Node Voltages (at cursor)**.

The annotation refuses, and now says why:

    Transient annotation -- the results file <name>.raw is older than the
    circuit it describes, so it was not used. Re-run the simulation.

So the traces are on the screen and the numbers are withheld.

## Why both halves are right

**The refusal is ruling 0838's.** A number painted onto a schematic carries no
provenance and no timestamp, so a stale one is indistinguishable from a live one.
`cadence::_annot_raw_candidate` already refuses a stale file for the `6` chord
and deliberately does NOT fall through to the `$netlist_dir/<cell>.raw` arm,
because that is very often the same stale file under another name.

**The plot is right too.** A trace is captioned by the viewer's own title and the
user chose to look at it; nothing about drawing it claims it is current.

## What A10 chose, and why it is not a ruling

Item A10 carried 0838's rule through the new supply door unchanged — a stale file
is named and not used — because widening a refusal is a change the item's brief
did not carry, and because the alternative silently reopens the defect 0838 was
filed about. Row **V36** of `tests/headless/test_op_annot.tcl` pins it.

But it sits directly against the user's ruling of the same day:

> "Given that results are being loaded and plotted, we have enough info to
> satisfy user intent. The ultimate goal of any UI is to satisfy user intent."

If the data is on the user's screen, "the answer is never 'not loaded'" — and
"not used because it is old" is one word away from that. The honest reading is
that this case is the one place the intent ruling and 0838 point in opposite
directions.

## The options

1. **Keep refusing, say why** (shipped today). Safe under D5-1, and the sentence
   tells the user what to do. Cost: the user sees traces and no numbers.
2. **Annotate it, and caption it as stale.** Satisfies intent; needs the sentence
   to carry the staleness on the SAME line the number's time is on, and needs a
   decision about whether the numbers on the sheet should look different.
3. **Refuse, but stop the viewer plotting it too.** Consistent, and almost
   certainly wrong — it takes away a plot the user asked for.

Option 2 is the one that matches the intent ruling; it is not taken because
nobody has ruled it.

## Owed

`owed.sh add rule 0884`.
