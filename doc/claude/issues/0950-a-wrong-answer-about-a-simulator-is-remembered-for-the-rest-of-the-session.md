# 0950 — a wrong answer about a simulator is remembered for the rest of the session, and the user cannot make the tree look again

**STATUS: FIXED (2026-08-30, item S3a) — an answer nobody worked out is never
remembered, and adding, editing or removing an entry in the simulator list makes
the tree look again. NO "Check again" button was added; that choice is on the
user's ruling queue (`owed.sh` rule 0950). Rows D10, D11, D12, J7 and J8 of
`tests/headless/test_ase_simcaps_0948.tcl`.**

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

## The fix (item S3a, 2026-08-30), in two parts

**(a) The cache no longer holds failures of the RUN dressed up as facts about
the PROGRAM.** `ase::sim_capabilities` writes the cache only when the answer
says `known 1`. One line, and it covers every measured case: the simulation
folder that could not be written into, the program that did not answer in time,
and every reason anyone adds later, because all of them say `known 0`. It is the
same rule the three existing guards already followed — they return before the
probe AND before any cache write.

A folder nothing can be written into now answers `{known 0 unmeasured noplace}`
and says nothing at all, instead of accusing the user's program of producing no
results. That was the actual cause of every case measured for this issue.

**(b) There is a door.** `ase::sim_caps_clear` is now called by
`ase::sim_register` and `ase::sim_unregister`. Adding or editing an entry is the
user saying something about their simulators changed, and it is the moment to
look again.

**The look-again is on the WRITER, not on the dialog, and that placement is the
decision.** Setup > Simulators and the Command window are two doors onto the same
registry writer. Putting it in `ase::ui::simdlg_ok` would leave the Command
window's door broken and would breach `src/ase_window.tcl`'s own stated rule that
no logic is re-implemented there. `src/ase_window.tcl` therefore needed no change
at all. Row D12 reddens on the wrong placement, which no behavioural row can see.

It is deliberately NOT in `ase::sim_select`: row D5 pins that switching back to a
simulator already measured does not start it again, and selecting an entry is not
a statement that anything about a program changed.

## The decision the user has not ratified, and the alternative rejected

**No "Check again" control was added to the Simulators window.** The reasoning:

1. a rebuilt program file is already re-measured with nothing for the user to do
   (the file stamp — rows D2, D3, D4);
2. Add / Edit / Remove now re-measure;
3. after (a), an answer that came from the run environment is never remembered in
   the first place — which is what every measured case actually was.

The rejected alternative is a **Check again** button in the dialog's button row
(`src/ase_window.tcl:3345-3352`) calling `ase::sim_caps_clear`. It is cheap and
it is discoverable; the argument against it is that it is a control for a state
that can no longer be reached, and a button that never has anything to do is a
button that teaches the user the tree cannot be trusted.

This is the user's to rule on, and it is recorded as such.

## Addendum, 2026-08-30 — the never-remember rule has a hole nothing announces

The rule "an answer nobody worked out is never remembered" holds only while a
probe that did not answer can be RECOGNISED as one. It cannot, on a box with no
`timeout(1)`: the run is then unbounded, the answer falls through to the ordinary
`usable 0` verdict, that verdict is `known 1`, and `known 1` is cached. Measured
on this box with the prefix emptied — 16.0 s unbounded, `cap_not_a_simulator`
said, remembered, second press instant and still wrong. Filed as **issue 0959**.

The two states that answer `{known 0 unmeasured noplace}` are correctly not
remembered, and are also completely silent, for good — filed as **issue 0960**.
