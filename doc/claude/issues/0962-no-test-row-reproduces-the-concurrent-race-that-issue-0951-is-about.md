# 0962 — no test row reproduces the concurrent race that issue 0951 is actually about

**STATUS: OPEN — a coverage gap, not a behaviour defect.** Issue 0951 IS fixed;
this is about what proves it. Found by item S3a's verification pass.

## What is missing

Issue 0951's measured defect needs **two processes overlapping in time**: one
probe running, and something else dropping a healthy results file at the shared
fixed name `<simulation folder>/.ase_probe/probe_a.raw` while it runs. That is how
a program which wrote not one byte came back
`known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1` — a false YES
about a binary that did nothing, and the reason item S4 could not trust these
answers.

The suite has two rows for it and neither reproduces that shape:

* **I4** plants a plausible foreign raw at the OLD fixed name *before* the probe
  starts, then asserts a program that writes nothing still answers
  `known 1 usable 0 appendwrite 0`, and that the planted file survives.
* **I5** calls the ngspice probe hook directly with a scratch folder already
  holding `probe_a.raw` and `probe_b.raw`.

## Why that matters — measured

The verification pass restored the pre-fix behaviour in-process (fixed shared
scratch folder, plus the delete-of-the-two-raws that used to run at the top of the
probe) and re-ran I4's own assertion:

> OLD tree, planted foreign raw, program writes nothing -> `1 0 0`, **identical to
> the fixed tree**. Only I4's second half reddens (the planted file is destroyed).

So I4's headline claim — "does not answer for a program that wrote nothing" —
**passes on the defective tree**, because the old delete-at-top happened to mask a
file planted beforehand. The row is not vacuous (its file-survival half is real and
does redden), but the claim it is named for is not the one it tests.

The same pass then built the race and confirmed the fix against it: with a helper
dropping a healthy raw at `.ase_probe/probe_a.raw` one second into the probe, the
OLD tree answers `known 1 usable 1 appendwrite 1 ...` (the false YES) and the NEW
tree answers `known 1 usable 0 appendwrite 0 ...`. **The fix is real. Nothing
committed measures it.**

## Fix shape

One row. Fork a helper that sleeps briefly and then writes a healthy results file
at the old fixed name, start a probe of a program that writes nothing, and assert
`usable 0`. The machinery for a spawned child already exists in this tree
(`tests/headless/test_raw_read_failure_0306.tcl`, and the argument-logging stubs in
this suite). Bound the helper's sleep against the stub's own run time so the row
cannot become timing-flaky; assert the helper actually got its write in, so a row
that races the wrong way self-skips loudly instead of passing.

## Acceptance

* One row that reddens on a tree with `ase::cap_workdir` returning the shared
  fixed folder, and that I4 and I5 together do not already cover.
* It states out loud whether the planting helper won the race, so it can never
  pass by having missed.
