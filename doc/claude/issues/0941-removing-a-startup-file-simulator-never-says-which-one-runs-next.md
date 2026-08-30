# 0941 — removing a startup-file simulator never says which one runs next

**Status: OPEN.** Measured on the `Setup > Simulators…` dialog that issue 0937
shipped, and reproduced first-hand by the write-up agent.

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

## What is still open

The recorder holding one string is the root cause. Either make `ase::sim_say`
accumulate (and have the dialog show all of them, which is the honest answer
when two true things happened), or give the dialog a way to ask for the
what-happens-next sentence specifically rather than "the last thing said". The
first is the smaller change and does not disturb R4's ordering, which E13 depends
on; the dialog would show both sentences, which is what actually happened.
