# 0885 - the two-window results compare is a sample, not a proof

**Status:** OPEN, known limitation, recorded at the moment it was created
(item A10 repair, 2026-08-27). Not a regression: before this guard existed there
was no comparison at all.

## What exists

`cadence::annot_tran` (the `Alt-Shift-6` chord and
**Results > Annotate > Transient Node Voltages (at cursor)**) annotates from a
results file that the waveform viewer is showing. The viewer holds its copy in
memory; the annotation reads the same file again, off disk, into the schematic's
own window. Re-running the simulator overwrites that file in place, so the two
can be different runs — and the sheet would then carry the new run's numbers
beside traces from the old one, with nothing saying so (RULING D5-1). Measured
before the guard: the waveform screen showing **3 V** at the cursor and the
schematic painting **30 V**.

`cadence::_annot_db_print` compares the two copies before any number is
published. The comparison is:

* the analysis type,
* the dataset count and the point count,
* the full column-name list,
* every column's value at the **last** point.

A mismatch refuses by name and tells the user to plot the results again.

## What it cannot see

A re-run whose every column has the identical **final** sample, the identical
point count and the identical column list, and differs only somewhere in the
middle of the sweep. That run passes the comparison and its mid-sweep numbers
would be annotated onto the sheet while the viewer plots the previous run's.

It is a narrow shape — a change that moves a waveform without moving its endpoint
or its time base — but it is not empty: a settling or glitch change on a circuit
driven to the same final state has exactly that signature.

## The two honest closures, both larger than the item that found this

1. **Compare every sample of every column.** One `xschem raw values` call per
   column per window is O(columns) calls but O(columns x points) of string, on
   every key press. On a large flat netlist that is hundreds of megabytes of Tcl
   string per press. Not acceptable as written; would need a C-side digest verb
   (`xschem raw digest`) that walks the arrays and returns one number.
2. **Share the database between the two windows.** There is no cross-window raw
   registry in the engine — `xctx->raw` and the extra-raw array are per-context —
   so this is a C change of real size. It is also the *right* answer, because it
   removes the second read entirely rather than checking up on it: the annotation
   would then be reading the very bytes the viewer is plotting, which is what the
   user asked for on 2026-08-27 ("The info should already be available - it's been
   loaded to display waveforms in the waveform viewer").

Option 1 is a guard; option 2 is a fix. If either is taken, row **V51** of
`tests/headless/test_op_annot.tcl` is the row to keep and extend, and the
mid-sweep shape above is the fixture to add.

## Where the boundary is written down

`utils/annot_mode.tcl`, in the header of `cadence::_annot_tran_supply`, under
"WHAT THE COMPARISON CANNOT SEE, stated so nobody reads it as a proof".
