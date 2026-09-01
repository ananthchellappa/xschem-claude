# 0944 — the simulator list shows no problem against an entry for another simulator

**Status: OPEN.** Measured on the `Setup > Simulators…` dialog that issue 0937
shipped. Reproduced first-hand. Lowest severity of the seven filed against this
change, but it is the same class the brief calls out.

## What the user sees

An entry registered for a **different** simulator backend than the session runs
— `-backend spectre` in an ngspice session — shows an **empty Problem column**,
i.e. the dialog says nothing is wrong with it. The moment the user picks it, it
turns out to be unusable:

```
F7 sim_entry_why (what the Problem column shows) = ''
F7 but the moment it is picked: ok=0
F7   why = The simulator named spec was registered for spectre, so it cannot be
          used to run ngspice. Pick one that was registered for ngspice, or make
          no choice at all and the program named ngspice on your PATH will be used.
```

The sentence exists and is a good one. The list just never asks for it.

## Why it happens

`ase::sim_entry_why` validates the **path only** and never looks at the backend,
and the list is not filtered by backend either. So a row reads as healthy right
up to the point the user commits to it.

## Why this matters

The brief asks for validation feedback in the dialog *"because silence is this
area's failure mode"*. Every other way an entry can be unusable is now shown in
the Problem column. This one class is not.

## What is still open

Either have `ase::sim_entry_why` take the session's backend and return the
existing `wrongbackend` sentence, or filter the list to the current backend and
say how many entries are hidden. The first keeps every registered entry visible,
which is friendlier for a user who switches backends between sessions, and it
reuses a sentence that is already minted.
