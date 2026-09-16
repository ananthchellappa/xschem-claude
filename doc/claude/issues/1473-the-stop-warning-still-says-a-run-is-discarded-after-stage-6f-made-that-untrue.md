# 1473 — The stop warning still says a run is discarded, after Stage 6f made that untrue

**Status:** OPEN — filed by the driver 2026-09-15, measured in the tree at `d761b630`. It is debt
**M18**'s unfinished half, and the ledger currently says M18 is closed in one place and open in two.

## What the user meets

Every ASE-L run says, once at launch — in the CIW and in the run log's `stop :` field:

> **Stopping this run discards it — ngspice in batch mode writes nothing on a stop.**

Since Stage 6f (issue 1433) that is **false for exactly the runs it matters most for**. A transient
whose estimated point count clears `ase::ckpt_floor` is rendered with the checkpoint loop: `stop after`,
`write` to a `.tmp`, `shell mv -f`, `resume`. Stopping such a run **keeps everything up to its last
checkpoint** — at the default N = 4 the worst case loses `100/(N+1)` = **20 %**, not all of it — and
`ase::ckpt_report` already says so afterwards (*"kept at 200000 points of an estimated 500000"*,
`test_ase_trnoise_1466` NP6).

So the user is warned that stopping costs everything, and then told afterwards that it did not. The
warning is the one a person acts on: someone who reads it and does not stop a ten-minute run has lost
the ten minutes the salvage was built to give back.

## Measured, at `d761b630`

* `ase::run_stop_warning` (`src/ase.tcl` ~`:16867`) composes ASE-L's frame plus the adapter's
  `run_stop_cost` clause. Its two callers are **the run door** (~`:16769`, just after the launch) and
  **`ase::run_log_header`** (~`:16914`).
* **Neither caller consults the checkpoint plan.** `grep` for `ckpt`, `checkpoint` or `salvage` within
  four lines of either call site finds nothing; the sentence is emitted for every run that reaches the
  launch, checkpointed or not.
* The adapter's clause (`src/ase.tcl` ~`:27882`) is `before {ngspice in batch mode writes nothing on a
  stop}` — true of ngspice, and no longer true of **an ASE-L run**, which is what the frame asserts.

## What debt M18 asked for, verbatim

> **Stage 6f landing discharges it**, and on the same commit Stage 2e's sentence is replaced by the two
> numbers `evidence/salvage.md` §5.2 makes computable — worst-case loss `100/(N+1)` %, **20 %** at the
> default N = 4, against the I/O the checkpoints cost — plus §5.3's marking of a salvaged result as
> partial, which must come from the deck's completion echo and **not** from rc or `$sim_status` (both
> are 0 after a stop).

Stage 6f landed. The sentence was not replaced.

⚠ **And the residue M18 names is real and permanent**: `op` has one point; `noise` and `disto` leave an
incomplete plot *set*; `pss`, `sp`, `pz`, `sens` and `tf` are unmeasured under a stop (`sens` is known
not to honour `bg_halt`). Those runs keep the old sentence — which is why the fix is a **split by what
this run actually is**, not a global rewording.

## The fix, expected small

1. **Gate the warning on this run's own checkpoint plan** — `ase::ckpt_rows` already answers which rows
   get one, and `ase::ckpt_plan` carries `n`, `step` and `points`. A run with no checkpointed row keeps
   today's sentence exactly.
2. **A checkpointed run gets M18's sentence instead**: what a stop costs at worst (`100/(N+1)` %, with
   the plan's own N), and that what is kept is marked partial. The numbers are the plan's, not a
   constant.
3. **The frame stays ASE-L's and the clause stays the adapter's** (D34–D37): a backend with no
   `run_stop_cost` hook still says nothing at all.
4. **Both callers**, so the CIW line and the log header's `stop :` field agree.
5. **Rows**: a checkpointed transient and an un-checkpointed one, each through the real
   `ase::run_log_header` and the run door; a bench of the residue kinds keeping the old sentence; and a
   row that reds if a checkpointed run is told it will be discarded. The new sentence is ⚖ R9 copy —
   `owed.sh add rule 1473` and an `R9_COPY_REVIEW.md` entry.

## Where the ledger disagrees with itself, and must be corrected with the fix

* Stage 6's block: *"⚠ What 6f does and does not discharge. **It closes debt M18** …"* — wrong; 6f
  shipped the loop and left the sentence.
* The debts table's **M18** row: open, and its *how it closes* text is the specification above.
* The *Still open and named* line: lists **M18** — correct.
