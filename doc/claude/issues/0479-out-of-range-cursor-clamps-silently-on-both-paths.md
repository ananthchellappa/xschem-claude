# 0479 — a cursor placed outside the data holds the endpoint and says nothing

Status: **OPEN QUESTION — this is S11's status-E ledger row.** The behaviour is
shipped and deliberate; what is unresolved is whether it should announce itself.
Filed by the S11 crew (2026-08-20).
Related: RULING **D4-4** in `doc/claude/specs/mixed_signal_signal_browser.md`
(`callback.c` `interpolate_yval`'s `frac` clamp), invariants **I1** and **I3**,
issues 0477/0478/0480, spec §4.7 / step S11.

## The behaviour, measured on BOTH paths

**BEFORE S11, graph path** (Measure agent, verbatim; raw sweep ends at 4 ns):

    S11BEFORE D1 GRAPH t=99e-9 past end   : raw annot={4 9.9e-08 0}  v(d)=4  gm=0.00039999999
    S11BEFORE D2 GRAPH t=-5e-9 before 0   : raw annot={0 -5e-09 0}  v(d)=0  gm=0
    S11BEFORE D3 GRAPH t=2.5e-9 between   : raw annot={2 2.5e-09 0}  v(d)=2.5  gm=0.00025

**AFTER S11, graph path** (write-up agent, same script, binary `2f41eadd…`) —
byte-identical, which is the regression clause of the step:

    S11AFTER  D1 GRAPH t=99e-9 past end   : raw annot={4 9.9e-08 0}  v(d)=4  gm=0.00039999999
    S11AFTER  D2 GRAPH t=-5e-9 before 0   : raw annot={0 -5e-09 0}  v(d)=0  gm=0
    S11AFTER  D3 GRAPH t=2.5e-9 between   : raw annot={2 2.5e-09 0}  v(d)=2.5  gm=0.00025

**AFTER S11, the NEW graphless path**, same raw, same process shape:

    S11AFTER  G1 DIRECT t=4e-9  (last) : annot={3 4e-09 0}   v(d)=4  gm=0.00039999999  text="gm  = 400u | gds ="
    S11AFTER  G2 DIRECT t=99e-9 past   : annot={4 9.9e-08 0} v(d)=4  gm=0.00039999999  text="gm  = 400u | gds ="
    S11AFTER  G3 DIRECT t=-5e-9 before : annot={0 -5e-09 0}  v(d)=0  gm=0
    S11AFTER  G4 DIRECT t=2.5e-9 mid   : annot={2 2.5e-09 0} v(d)=2.5  gm=0.00025

The endpoint is **held**, never extrapolated, never blanked, and the two paths
agree digit for digit (invariant I1 — one behaviour, not two).

**The honesty gap is the `text=` column of G1 and G2**: a cursor at the last
sample and a cursor 24× past the end of the sweep render the *identical block*,
`gm = 400u`, and nothing on screen distinguishes them.

## Why S11 shipped it this way

S11's brief asked for out-of-range to be "handled honestly rather than clamping
silently to a fabricated value (I3)". The crew resolved that **against the
brief's wording**, deliberately, decision **D3**:

* **Ladder rung L1, invariant I1.** The direct path reaches the same
  `interpolate_yval()` as the graph path, so it inherits RULING **D4-4**'s clamp.
  Blanking on the new arm only would give one cursor two behaviours — the exact
  silent drift I1 exists to prevent — and **no existing row compares the two
  paths**, so the divergence would have reddened nothing.
* **I3 read narrowly, and this is the load-bearing reading.** An endpoint hold
  is a *real measured sample of a present vector*, not a fabricated number for a
  *missing* one. Missing vectors still blank: `gds` is absent from the fixture
  raw and renders as `gds =` with nothing after it at 1 ns, 3 ns and 99 ns alike
  (row T7, and the `text=` columns above).
* **Rejected** — `annot_p = -1` or a blank on the direct path. Also rejected by
  D4-4 itself when it was ratified: a cursor at t deserves a real answer and the
  readout has no way to render "no answer" that is not itself a lie.

## What already exists, and what does not

`xschem raw annot` reports the **requested** `annot_x` (`9.9e-08`) beside the
**clamped** `annot_p` (`4`), so the condition *is* detectable — by a caller who
knows to look. There is no status-line note, no `xschem raw` seam that says
"the cursor is outside the data", and nothing on the schematic.

## ⚠ The clamp has thinner test coverage than it looks (S11 sabotage, SAB-7)

Deleting **both** clamp lines from `interpolate_yval()` left row **T16** ("past
the end holds the last sample") and rows **XCW4/XCW5** of
`test_wave_cursor_crossdb.tcl` **green**. Mechanism, measured: past the last
sample the function returns at the `(p + 1 < ofs_end)` guard *before* `frac` is
computed, so the upper hold is that guard, not the clamp; XCW4 is a VCD
sparse-stream early return, also clamp-independent. Only the **lower** bound has
behavioural coverage today. Anyone editing that arithmetic should not read a
green suite as protection.

## Rider, same family, measured at write-up time

    S11AFTER  G5 DIRECT t={abc} : rc=0 err="0" get cursor2_x=0 annot={0 0 0}  v(d)=0

`xschem set cursor2_x abc` (and the empty string) **succeeds**, means t = 0 via
`atof_spice()`, and now silently re-annotates the whole graphless sheet at t = 0
— overwriting the operating point the user just got from `annotate_op`, with no
error. Identical on the graph path, so it is not a divergence, but before S11 it
was unreachable from a sheet with nothing plotted.

## THE QUESTION FOR A HUMAN

> A cursor parked outside the loaded sweep now moves every annotated number on a
> **graphless** schematic to the last sample and says nothing. Is that silent
> endpoint hold the right answer, or should **both** paths (never one) gain a
> seam or a status-line note naming the condition?

Whatever the answer, it must be applied to both paths in the same change.
Diverging is the failure mode I1 was written for.
