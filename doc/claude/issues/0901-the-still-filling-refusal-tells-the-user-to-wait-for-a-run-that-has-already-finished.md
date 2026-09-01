# 0901 — the "still filling" refusal tells the user to wait for a run that has already finished

**Status:** 🔴 **OPEN — measured, filed, NOT fixed.** The refusal itself is
correct (RULING D5-1 holds: nothing is attached, the mask is untouched, the
sheet stays bare). The **reason and the remedy** in the sentence are wrong, and
under the user's PLAIN ENGLISH ruling — *"say what happened"* — a wrong reason
is the same defect class as a wrong number.

Filed 2026-08-28 by the item A13 write-up, from the A13 adversarial
verification pass. Measured on **both** arms, byte-identical.

**Introduced by item A13**, in the same commit that files this. The sentence is
new; it is right for the case it was written for and wrong for the neighbouring
one, and the neighbouring one is issue 0896's own headline scenario.

## The sentence

`utils/annot_mode.tcl`, `cadence::_annot_tran_msg`, state `viewerfilling`:

> The waveform window is showing the results file `<name>`, but the run has not
> produced any values yet, so nothing was placed on the schematic. **Wait for
> the simulation to finish, then try again.**

## Where it is wrong

The state is decided from what the **waveform window** holds. The waveform
window attached the file while it had `No. Points: 0` and holds that snapshot;
the run then finishes and writes its measured points to the very path the
sentence names. Measured:

```
P6 disk_points_at_that_path=5  (the file the sentence is about to name)
P6 annot_tran=0 viewerfilling
P6 msg=The waveform window is showing the results file vrun.raw, but the run has
       not produced any values yet, so nothing was placed on the schematic.
       Wait for the simulation to finish, then try again.
```

The run **has** finished. Its five points are on disk, at that path, readable.
The user is told to wait for something that already happened, and waiting will
never clear it — the waveform window will hold its zero-point snapshot until it
is told to re-plot. The advice is a dead end.

The neighbouring state already says the right thing for this world. `viewerdiff`
ends *"Plot the results again in the waveform window, then try again."*, which
is the action that actually resolves it.

## Where it is right

The case A13 wrote it for: the run genuinely is still going, the file on disk
still has no points, and waiting **is** the correct advice. That case is real
and common (issue 0836 calls a zero-point read *"THE ORDINARY CASE, NOT A
CORNER"*), and row V59 covers it.

So one sentence is doing duty for two different worlds and can only be true in
one of them at a time. The state does not currently distinguish them.

## The shape of a fix — not attempted here

The code already holds the evidence needed to tell the two apart: it has the
path, and `cadence::_annot_db_print`'s machinery can read the point count of the
file **on disk** as against the snapshot the window holds. Options, in the order
they should be considered:

1. **Split the state.** Keep `viewerfilling` for "the file on disk also has no
   points yet — wait", and add a second state for "the file has points but the
   waveform window's copy does not — re-plot", which is `viewerdiff`'s advice
   and arguably `viewerdiff`'s sentence.
2. **Do not claim anything about the run's progress.** Say the waveform window
   has no values to read yet and offer *both* next steps ("if the run is still
   going, wait; otherwise plot the results again"). One sentence, true in both
   worlds, at the cost of being longer.
3. Leave it. Rejected as a recommendation: it is the wrong-reason defect the
   PLAIN ENGLISH ruling is about, and it arrived in the commit that fixed two
   others of exactly that kind.

Option 1 mints a new user-facing sentence and therefore owes the user a ruling
and an eyeball before it ships; option 2 rewords an existing unratified one.
Either needs rows on both arms, per the A13 acceptance standard.

## Rows

**None.** Row V59 pins the sentence for the world where it is true. Nothing
exercises the world where the run has finished behind the waveform window's
back — probe `P6` below is the only witness, and it is not a row.

A fix owes a row on both arms whose fixture is: waveform window attached at zero
points, the finished run then written to the same path, chord pressed — and it
must assert the sentence the user is given names the action that actually works.

## Related

* **0896** — the defect whose fix minted this sentence. Fixed.
* **0885** — the sibling wrong reason from the other side: a waveform window
  holding a *partially* filled run while the file on disk has grown is told the
  results are "from a different simulation run" when it is the **same** run,
  further along. Same family, already fenced and open.
* **0893 / 0895** — the wrong-reason defect class this belongs to.

## Debt

The `viewerfilling` sentence already carries an unpaid **look** debt (the user
has never seen it) and its wording was invented by item A13. This issue is the
measured argument for changing it before the user is asked to ratify it, and the
look debt should be read together with this file.

## Evidence

Probe `.../scratchpad/vc/q.tcl` row **P6**, re-run by the write-up agent rather
than inherited, against the already-built `src/xschem` (Aug 27 14:58) with the
A13 fix in the tree. Reproduces byte-identically headless and on the persistent
dev display (`:99`, 1920x1080x24, **openbox 3.6.1** live per
`devdisplay.sh status`).
