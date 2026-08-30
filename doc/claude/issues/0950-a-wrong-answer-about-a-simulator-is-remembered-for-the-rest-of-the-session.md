# 0950 — a wrong answer about a simulator is remembered for the rest of the session, and the user cannot make the tree look again

**STATUS: OPEN — measured 2026-08-30 on the tree that landed 0948, by that
item's write-up pass. Not fixed here: the lever exists, the door does not, and
which door it should be is a design question.**

## What the user sees

Something once made the answer about their simulator come out wrong — a folder
name with a space in it (issue 0949), a machine briefly out of memory, a
network mount that was not up yet. They fix it. They press Run again, and the
Command window says the same wrong thing. They fix something else. It says it
again. Nothing they can do from the program changes it, and nothing tells them
that a restart would.

## Measured

One session, one binary, the folder repaired between the second and third
question:

```
--- B: simulation folder whose name has a space in it ---
  caps    : known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0
  said    : cap_not_a_simulator
--- C: back to the ordinary folder, same session ---
  caps (no clear) : known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0
```

Arm C is the same program in the same session as the healthy arm A, which
measured `usable 1 appendwrite 1 hier_op_names 1`. The remembered answer is the
wrong one and it stays.

## Mechanism

The answer is filed under the program's location and stamped with the file's
own time and size (`ase::cap_stamp`), which is exactly right for the case it was
built for: a user who rebuilds their simulator in place is re-measured with
nothing to do. But it means the remembered answer only ever changes when **the
program file** changes. Every cause that lives outside the program file — the
folder it was asked to write into, the machine's state at that moment, a mount
that has since come up — is invisible to the stamp, so a wrong answer taken
under those conditions is permanent for the session.

`ase::sim_caps_clear` fixes it in one call and nothing calls it:

```
$ grep -rn sim_caps_clear src/ tests/ doc/
```
matches only its own definition, the suite `test_ase_simcaps_0948.tcl`, and
`doc/claude/specs/ase_l.md`. There is no menu item, no button in
**Setup > Simulators**, and no sentence that tells the user restarting would
help.

This was recorded as decision 5 in 0948's "what the user has not ratified" —
"no check-again control in the Simulators window" — under the narrow heading of
a rebuild inside one second that leaves the file the same size. The measurement
above is much wider than that heading: the hole is every cause that is not the
program file.

## Fix shape, in the order they are worth doing

1. **Do not remember an answer that came from a failed measurement.** A probe
   that could not write where it asked, or that was cut off by its own clock,
   has not measured the program; the same argument that keeps 0948 from writing
   a cache entry for an unresolved simulator applies here. This alone closes
   most of it.
2. **A door.** A `Check again` button in Setup > Simulators, calling
   `ase::sim_caps_clear`, next to the entry the answer is about.
3. Failing both, the sentence itself should say that the answer was worked out
   once and how to make the tree look again — a sentence that a user can act on
   beats one they can only re-read.

## Acceptance

* Take a wrong answer (easiest: 0949's spacey folder), remove the cause, ask
  again in the same session — the answer is right.
* A user with the Simulators window open can force a re-measure without
  restarting, and can see that it happened.
