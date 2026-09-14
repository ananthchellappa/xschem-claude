# `alterparam` + `reset` — what survives the re-parse — debt **M11**, answered

**Measured 2026-09-13 by the driver**, five decks, on **both** binaries, every run from a scratch
directory of its own. M11 asked whether `alterparam` + `reset` preserves `.options` and `set`
variables across the re-parse, and whether it re-reads `<rundir>/.spiceinit`. Stage 11's
collapse-into-one-shard mode depends on the answer.

⚠ **Nothing here touched `$HOME/.spiceinit`.** The `.spiceinit` below is in the run directory, which
is where ngspice looks first and which is what ⚖ R2 ratified.

## What survives

| | before `reset` | after `reset` | verdict |
|---|---|---|---|
| the altered parameter (`alterparam rr=2k`) | `@r1[resistance] = 1.000000e+03` | **`2.000000e+03`** | ✅ **the point of the exercise works** |
| a deck `.options reltol=0.005` card | `reltol (current) = 0.005` | **`0.005`** | ✅ **preserved** — the re-parse re-reads the deck |
| an interactive `option abstol=1e-15` set **before** the first analysis | `abstol (current) = 1e-15` | **`1e-15`** | ✅ **preserved** |
| a `set myshellvar=before` | `before` | **`before`** | ✅ **shell variables are not touched by `reset`** |
| `<rundir>/.spiceinit` | `SPICEINIT-WAS-READ` printed **once** | **not printed again** | ⚠ **read at startup only — `reset` does NOT re-read it** |

**Identical on both binaries, every row.**

So Stage 11 may collapse shards into one process: an `alterparam` + `reset` loop keeps the deck's
options, the interactive options and the shell variables, and re-applies the deck's own cards by
re-parsing them. The one thing it does **not** do is re-read `.spiceinit` — which is the correct
behaviour for a loop (a startup file should apply once) and must be remembered by anything that
expects otherwise.

## ⚠ An option set BETWEEN two analyses does reach the later one

```
op                                   ->  Doing analysis at TEMP = 27.000000
option temp=100
op                                   ->  Doing analysis at TEMP = 100.000000
```

This is the property ASE-L's **per-analysis option scoping** rests on — the option lines rendered
above each analysis card really do govern that card and not only the first one. It was assumed and
is now measured, on both binaries.

## ⚠ AND `option`'s LISTING IS NOT A SAFE READBACK CHANNEL

An `option abstol=1e-15` issued **after** the first analysis lists as **unchanged** —
`abstol (current) = 1e-12` — while an `option temp=100` issued at exactly the same point
**visibly reaches the next analysis**, which prints `TEMP = 100.000000`. The same command at the
same moment: one option's listing reflects it and another's does not.

**So the `option` listing and the simulator's behaviour can disagree, and the listing is the one
that is wrong.** Anything in ASE-L that reports *effective* options by parsing that listing
(D26's reader, `test_ase_effective_1442`'s subject) is reading a channel that has now been
measured to lie in at least one direction. **Report what was emitted, or measure the behaviour;
do not treat the listing as ground truth.**

## What this leaves

* **M11 is closed** on all three of its questions.
* **Not measured:** *why* the two options differ in the listing — whether `abstol` is copied into
  the circuit at setup and the listing reads the copy, or whether it genuinely fails to apply. The
  distinction matters only if ASE-L ever wants to set `abstol` mid-run, which nothing does today.
  What is established is the rule for the reader, and that does not depend on the cause.
