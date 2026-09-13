# 1453 — ASE-L's probe decks took over the user's File > Open Recent

**Branch:** fluid-editing · **Filed:** 2026-09-13 · **Status:** open, **rule debt filed**
**Found by:** Stage 9's crew, in passing. **Verified by the driver, read-only.**

## What the user sees

`File > Open Recent` holds **ten entries and not one of them is the user's**. Every one is an
ASE-L capability-probe scratch deck:

```
/home/analog/.xschem/simulations/.ase_probe/p3438206_3/probe_a.sp
/home/analog/.xschem/simulations/.ase_probe/p3438206_2/probe_a.sp
/home/analog/.xschem/simulations/.ase_probe/p3438206_1/probe_a.sp
/home/analog/.xschem/simulations/.ase_probe/p3390969_3/probe_a.sp
…
```

Four different pids, three decks each. **The directories no longer exist**, so every entry is
also dead. Whatever the user had in that menu has been pushed out of it.

⚠ **This is the SECOND time this file has been damaged.** Issue **0924** is the first: a bare
`xschem` on `PATH` resolving to a 3.4.6 binary that predates the gate emptied it. That one was
about a stale binary; this one is **ASE-L's own probe**, in this tree, today.

## The mechanism, read rather than guessed

`src/xinit.c:3546`:

```c
tclsetintvar("no_recent_files",
  (cli_opt_nogui || cli_opt_pipe || cli_opt_norecent) ? 1 : 0);
```

and the comment above it says the suppression lasts **for the duration of the `--script` body**
and is **restored before the event loop**, *"so loads the human performs afterward record
normally"* (issue **0119**).

So the gate is doing exactly what it was designed to do. The probe is on the wrong side of it:
a **`--pipe` run with Tk** reaches the event loop with `no_recent_files` back at 0, and anything
that loads a file **from the event loop** — an `after` handler, a Tk callback, a probe that runs
once the GUI is up — records normally. A `--nogui --pipe` run provably cannot do it: the crew
measured the file's md5 unchanged across one.

## What has to change, and what must not

**The fix belongs in ASE-L, not in the gate.** The gate's behaviour is correct for a human's
loads; a capability probe is not a human's load. Either the probe suppresses
`no_recent_files` around its own `xschem load`s and restores it, or it stops loading a deck into
the editor at all — it is measuring the *simulator*, and `evidence/binary-differences.md` records
that a probe launch costs ≈5 ms, so there is no reason the editor has to see the file.

⚠ **The existing ten entries are the USER'S to repair, and nobody else's.** The standing rule in
this tree is that nothing touches, moves, backs up or read-modify-writes anything under
`~/.xschem/` — and that rule exists *because* of 0924. This issue does not repair the list, and
whoever fixes the probe must not repair it either.

## Options for the ruling

| | what | cost |
|---|---|---|
| **A** | **(recommended)** the probe sets `no_recent_files` around its loads and restores it | small, local to the probe, and it keeps the probe's current shape |
| **B** | the probe stops loading its deck into the editor entirely | larger; it may exist for a reason this issue has not established |
| **C** | `--norecent` is passed on every probe launch | only works if the probe launches a separate process |
| **D** | do nothing about the list, fix the probe only | the ten dead entries stay until the user clears them |

**A, plus telling the user their list is theirs to restore**, is the recommendation.

## Where it lives

The probe: `src/ase.tcl`'s capability-probe path (`.ase_probe` under
`~/.xschem/simulations/`). The gate: `src/xinit.c:3546`, and `xschem.tcl`'s
`update_recent_file` / `update_recent_dir` / `write_recent_file`, all gated on
`no_recent_files`. Prior art: issues **0119** and **0924**.
