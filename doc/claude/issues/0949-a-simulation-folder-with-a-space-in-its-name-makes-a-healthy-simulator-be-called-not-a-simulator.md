# 0949 — a simulation folder with a space in its name makes a healthy simulator be called "not a simulator"

**STATUS: OPEN — measured 2026-08-30 on the tree that landed 0948, by that
item's write-up pass, reproducing a finding from its verification. NOT fixed
here: the fix belongs with the same unquoted-path defect in the real deck (see
"The half that is older than this", below), and it wants its own row.**

## What the user sees

Their simulation folder is somewhere ordinary for this machine — say
`/mnt/c/Users/First Last/designs` — and they press Run. The Command window
tells them, every single time:

> `/usr/local/bin/ngspice`, which is the program the simulator you picked will
> start, produced no results at all when it was tried on a tiny test circuit.
> Check that it really is a circuit simulator, or point this entry at a
> different file.

Nothing is wrong with their simulator. It is the stock ngspice-46+ that this
box has always had, and it answers every question correctly the moment the
folder name has no space in it. The sentence sends them to replace a working
program.

## Measured

Same session, same binary, one thing changed — the folder the probe writes
into:

```
resolved: /usr/local/bin/ngspice
--- A: simulation folder with an ordinary name ---
  caps    : known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
  said    :
--- B: simulation folder whose name has a space in it ---
  caps    : known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0
  said    : cap_not_a_simulator
```

A dollar sign in the folder name does the same thing — measured by 0948's
verification pass, with the identical sentence.

## Mechanism

`ase::cap_workdir` puts the probe's scratch inside the simulation directory,
and the probe deck names its results file **unquoted**:

```tcl
src/ase.tcl   write $rawa
```

ngspice's `write` takes the first whitespace-separated word as the file name,
so `write /mnt/c/Users/First Last/designs/.ase_probe/probe_a.raw` writes to
`/mnt/c/Users/First`, and the probe reads back nothing at the name it asked
for. Nothing wrote nothing; the probe simply cannot see what was written.

The verdict is then honest about what it saw and wrong about what it means:
`usable 0` says "no results came back", and `ase::cap_report` renders that as
a statement about the user's **program**. This is 0948's own guard failing in
the direction the branch keeps failing in — a sentence that is locally correct
at every joint and collectively an accusation against the wrong thing. It is
also, one commit later, the same shape as **0938** ("a simulator under a folder
with a dollar sign in it runs again"), whose own write-up says a dollar sign in
a folder name used to "send them looking at a disk".

## The half that is older than this

The real deck has the identical unquoted line:

```tcl
src/ase.tcl:5345        lappend lines "write [raw_file $state]"
```

so in a folder with a space in it the user's actual simulation already fails to
produce a results file, and has since before 0948. That is the deeper defect
and it is why this is filed rather than patched in the probe alone: quoting only
the probe would leave a user in that folder with working capability detection
and a run that still writes its results somewhere else.

## Fix shape

1. Quote the file name in **both** places — the probe deck and `render_deck` —
   and confirm the quoting ngspice actually honours (`write "..."`), on a name
   containing a space, a dollar sign and a bracket.
2. Then, separately, make `cap_report` unable to blame a program for a
   condition that is about a path: a probe that could not even write where it
   asked should answer `known 0` (nothing was measured) rather than
   `usable 0` (measured, and it produced nothing). Absent means "nobody
   measured" — 0948's own contract already says so for the guards; this is the
   arm that violates it.

## Acceptance

* With the simulation folder named `with space`, a stock ngspice measures
  `usable 1 appendwrite 1 hier_op_names 1` and **nothing is said**.
* The same folder produces a real results file from a real Run.
* A program that genuinely writes nothing still answers `usable 0` and is still
  reported — the honest arm must not be lost to the fix.
