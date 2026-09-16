# 1474 — The post-stop message still says nothing was written, seconds before the checkpoint report says what was kept

**Status:** OPEN — found by the issue 1473 crew and **confirmed by the independent verifier**
2026-09-15, both measuring the tree that issue 1473 leaves behind. It is the same defect class as
1473, one message later in the same run.

## What the user meets

Issue **1473** fixed the warning the user reads **before** stopping: a checkpointed transient is now
told it loses at most `100/(N+1)` % and that what is kept is marked partial. The message the user
reads **after** stopping was not touched, and still says:

> **nothing of this run was written**

Seconds later `ase::ckpt_report` says what actually was written — *"kept at 200000 points of an
estimated 500000"* (`test_ase_trnoise_1466` NP6). So the run that 1473 now correctly promises salvage
to is told, at the moment it stops, that it got none — and then contradicted by the next line.

This is worse than the state 1473 repaired, not better. Before 1473 the two messages agreed with each
other and both were wrong for checkpointed runs. Now the launch warning is right, the stop message is
wrong, and they disagree **within one run**.

## Measured

* `ase::run_stopped_msg` — `src/ase.tcl:16960` — **takes one argument** (the simulator) and composes
  the "nothing of this run was written" sentence unconditionally. It has no access to the run record
  and therefore none to `ckpt`.
* Its **sole caller** is `src/ase_window.tcl:12548`, which passes only the simulator.
* Issue 1473 resolved the checkpoint plan **once** in `ase::run_deck` and carried it in the run record
  as `ckpt` — so the value this message needs already exists and is already computed; it simply is not
  passed to this call site.

⚠ **Issue 1473's crew was right not to fix it.** The fix needs `src/ase_window.tcl`, which 1473's task
did not name, and a task that quietly widens its own scope is the thing the batch's receipts exist to
prevent. It was reported as *found, not fixed*, and this file is where it goes.

## The fix, expected small

1. **Pass the run record's `ckpt` to `ase::run_stopped_msg`** from `src/ase_window.tcl:12548`, the same
   plan 1473 already resolved — do not resolve it a second time, and do not recompute it from the
   bench, which may have been edited while the run was live.
2. **A checkpointed run's stop message says what was kept**, in the shape `ase::ckpt_report` already
   uses, and marks it **partial** from the deck's completion echo — **never** from rc or `$sim_status`,
   both of which are 0 after a stop (`evidence/salvage.md` §5.3).
3. **An un-checkpointed run keeps today's sentence byte for byte**, as do the residue kinds (`op`,
   `noise`, `disto`, `pss`, `sp`, `pz`, `sens`, `tf`).
4. **The frame stays ASE-L's and the clause stays the adapter's** (D34–D37): a backend with no hook
   says nothing at all.
5. **The two messages must be asserted against each other**, not merely each against itself — the
   defect is that they disagree, so a row that reds when the stop message contradicts the launch
   warning for the same run is the one that matters.

## Coverage this must also close

The verifier found issue 1473's suite covers **six** of the eight residue kinds, not seven as its
receipt said: **`pss` and `sp` are pinned by no row.** Both were confirmed independently to declare no
`salvage`, so the shipped behaviour is correct and only the coverage claim was overstated — but a
later change could move either in silence. Add the two rows with this fix.

## Copy

The new sentence is ⚖ **R9** copy: `owed.sh add rule 1474` and an `R9_COPY_REVIEW.md` entry, whose
header currently reads 725 strings from 37 issues.
