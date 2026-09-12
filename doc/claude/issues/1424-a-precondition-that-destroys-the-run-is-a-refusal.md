# 1424 — a precondition that destroys the run is a refusal

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C4** of Stage 4 of `doc/claude/ase_analyses_batch/`.

## What ships

`ase::preflight_gate` refuses on a **`fatal`** precheck verdict, in a block **above** the
`ase_preflight` escape. `ase::backend::ngspice::render_deck` re-checks the same thing before it
builds a single line. Together they are the plan's second and third refusal tiers.

## Why `fatal` is not a strong `blocked`

`caution` and `blocked` mean *"this run will be less useful than you think"*. **`fatal` means the
simulator will not reach the end of `.control`.** The measured case is a CIDER numerical device
under the KLU solver: ngspice calls **`exit(1)`** — not an error return, an **exit** — so every
analysis after it in the deck silently does not happen, and the run directory is left holding a
partial raw file that reads back as a perfectly valid result.

That is why it sits above the escape. `set ase_preflight 0` exists so a user can run a deck whose
save list this tree cannot resolve — a judgement call about a warning. It may not be a way past a
simulator that will not finish its own control block: that is letting the user past a **silent wrong
answer**, not past an inconvenience. Same reasoning as issues 1401 and 1415, and the sentence says
so in the same words.

## And the gate may only slam for `fatal`

A `caution` or a `blocked` belongs in the **window**, next to the control that causes it, where the
user can see it and decide — that is the four-state grid's job. The gate is the last door before a
process starts, and it may only slam for the verdicts that make starting the process pointless.
**PF225e** pins that a deck with no AC source — a real `ac_source` finding — goes through.

## Suites

`test_ase_preflight.tcl` **144 → 149** (section **PF225**). Four sabotages.

⚠ **One survived my own row and was caught by two older ones.** Making `render_deck` refuse on
*any* verdict left PF225d green — because PF225d's fixture had **no finding at all**, so it could
not tell *"refuses fatal"* from *"refuses anything"*. It reddened `PF221al` and `PF221an` instead,
rows written for something else entirely. The row is now given a deck carrying a real `caution`
(no AC source) and required to **render it**: a warning the user can act on is not a reason to
refuse to write their deck.

⚠ **And the first draft of that addition referenced a fixture defined lower in the file**, which the
suite reported as `FATAL: can't read "KNOAC": no such variable` rather than as a failed row — a
reminder that this suite wraps its whole body in one `catch`, so a typo in a late section is a
single FATAL rather than a located failure.
