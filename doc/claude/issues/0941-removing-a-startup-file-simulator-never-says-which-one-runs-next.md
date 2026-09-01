# 0941 — removing a startup-file simulator never says which one runs next

**Status: FIXED 2026-08-29 (item S2a), folded into the 0938 repair.** The
measurement below is the BEFORE state and is kept verbatim.

**The original filing, unchanged.** Measured on the `Setup > Simulators…` dialog
that issue 0937 shipped, and reproduced first-hand by the write-up agent.

**This is a direct miss of the item brief's literal requirement** — *"Remove must
work on the entry currently in force and must say what happens next"* — in the
arm where the entry came from a startup configuration file.

## Why it happens

`ase::sim_said` holds exactly **one** string, and the rc sentence is deliberately
said **last** (row R4 pins that ordering, because the pre-existing row E13 reads
the last message). So for an rc-origin entry the rc sentence is the one the
dialog shows, and the what-happens-next sentence that was minted for this — the
whole point of the change — is overwritten before anyone sees it.

## Measured

Two entries, `rcsim` (from the startup file, in force) and `mine`. Press Remove
on `rcsim`:

```
F3 entries=rcsim mine in force='rcsim' origin of rcsim=rc
F3 after remove: in force='mine'
F3 the ONE sentence the dialog will show:
F3   |The simulator named rcsim was put there by a startup configuration file, so it will be back the next time xschem starts. Edit that file to remove it for good.
```

The simulator that will actually run **changed silently from `rcsim` to `mine`**
and no sentence says so. The minted sentence for exactly this — *"You removed
rcsim, and mine is now the simulator that will be used…"* — is never shown.

The three-entry arm is worse: in force becomes empty, the program that starts
changes to whatever is on the PATH, and again the only sentence is the rc one.
That is the **original BEFORE defect of 0937** (*"removing the in-force entry
SAID: (nothing at all)"*) still live in this arm.

## Why no row caught it

S8a and S8b are the remove-says-what-happens-next rows and both use
**session-origin** entries only. Neither suite removes an rc-origin entry.

## What shipped

**The first of the two ways out: `ase::sim_say` accumulates.** The recorder is a
list, `ase::sim_said` joins it in the order the sentences were said, and
`ase::sim_said_clear` still empties it. The dialog is unchanged — it already
clears, does the gesture, and renders whatever it gets back — so the status line
now carries **both** true sentences, the what-happens-next one first, wrapped.
`ase::sim_clear` empties the recorder too, so clearing the registry and then
reading back what one later gesture said cannot pick up sentences from before
the clear.

**A gesture with one thing to say hands back exactly that sentence and nothing
else**, so every caller written before this change sees no difference at all —
which is why rows R10, S7 and S11 needed no re-authoring. **No new sentence was
minted**, so ruling D5-4 and rows D6/R9 could not move. R4's say-order in
`ase::sim_unregister` is untouched, and it is now load-bearing from the other
side as well: it is what puts the what-happens-next sentence first in the
remembered string.

**REJECTED: giving the dialog a way to ask for one specific sentence.** That
would mean two different definitions of "what the gesture just said" living in
two files, which is the seam ruling D5-4 exists to prevent — and it answers the
wrong question anyway. Both sentences are true and both are the user's business.

## Acceptance rows

* **R17** in `tests/headless/test_ase_simreg_0931.tcl` — at the registry: two
  sentences reach the CIW, **both** are remembered, the what-happens-next one
  comes first in the remembered string, and `sim_said_clear` still empties it.
* **S19** in `tests/headless/test_ase_simdlg_0937.tcl` (display arm) — at the
  pixels: with a startup-file entry in force, picking its row in
  `Setup > Simulators…` and pressing Remove leaves the dialog's own status line
  carrying both sentences, in that order. Both are quoted from the mint, never
  from a literal, so the row cannot drift from `ase.tcl`.
* S8a and S8b, the session-origin rows, stay exactly as they were: they are the
  control that one sentence still renders as one sentence.

**A look debt is recorded**: two sentences on that status line is a taller
wrapped block than the dialog has ever shown, and a green suite is not a look.
