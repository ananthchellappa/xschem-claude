# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

| id | task | crew status | commit | rows red→green | issues | notes |
|---|---|---|---|---|---|---|
| — | batch scaffolding | driver | `78d06f1e` | — | — | PLAN, BRIEF, DECISIONS, LEDGER; owed ledger backed up; R1 filed as a ruling debt against 0990 |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, identical across 4 runs | 1476 | 485 lines, private miniature fixture. **Refuted the plan's fix shape.** |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 RED → 2 RED**, `2 FAILED (18 passed)` in **10 of 10** runs | 0867, 0990, 0384(part) | Per-run `results.<pid>` + `publish_results`; scratch to `.work.<pid>`. Caught 1905 result files that would have varied run-to-run, invisibly. |
| **C1** | face 4, the verdict | **DONE** | — | **2 RED → 0**, `RESULT: ALL PASS (20 checks)` rc 0, in **18 of 18** runs | 0955, 0905, 0384(rest) | Lock on the verdict; `results.log` keeps its canonical name (`V1b` still green). Suite registered in `hcases`. |

## ⚠ R1 AMENDED AGAIN BY MEASUREMENT — "the second run waits" is UNSAFE

C1 measured the shape the ruling actually named. **A run that queues politely and then
truncates destroys exactly the verdict the lock exists to protect**: with
`T1_LOG_LOCK_WAIT=60`, `results.log` ends up holding **0** of the first run's four
blocks, which reds `V2b`.

So the built shape is: **refusal by default**; waiting is opt-in
(`T1_LOG_LOCK_WAIT`); and the waiting path **preserves** the previous verdict as
`results.<pid>.log` (measured 13268 bytes, all four blocks) before taking the name.
**D1 must not describe this as "it now takes a lock"** — that sentence would be
wrong in the direction that loses data.

Breaking is on **evidence**: a dead pid, *or* a live pid whose `/proc` cmdline is no
longer the script that took the lock — because a bare `kill -0` says yes to a recycled
pid — with `T1_LOG_LOCK_TTL` as backstop. Fails open in four places, including "can
neither take nor break it" → runs unlocked with a warning. Cost to a solo run:
**0.009 ms, once.**

## ⚠ The driver's own brief contained a trap, and C1 caught it

The brief pointed C1 at `gui_gate.sh:170` as the lock precedent. **It does not port.**
That idiom is mkdir-based, which is atomic in `/bin/sh` — but **Tcl's `file mkdir`
succeeds silently on an existing directory** (measured, rc 0). Ported as briefed, the
lock would have been handed to **both** runs and **would have read as correct in
review**. The Tcl primitive with O_EXCL's guarantee is
`open … {WRONLY CREAT EXCL}`. Recorded because the error was the driver's, not the
crew's.

## B1's correction 1, answered structurally

After the fix there is no coin left to land: the second run refuses ~2.7 s before the
first would release, so both `V2` rows are green **deterministically**, not merely
often. 18 runs, zero flakes.

## Registration — and a briefed number that did not reproduce

`headless/test_regression_concurrency_1476` is in `hcases`, which is 69 entries, every
one resolving to a file on disk. **The briefed 7.4 s did not reproduce**: measured
**8.53 / 8.63 / 8.63 s**, and C1 wrote the measured range into the comment instead of
the briefed figure. 2.1% of T1's ~410 s. Safe inside T1 — its two driver copies run in
its own scratch, so their verdict *and their lock* are never the live run's.

## ⚠ Three things V1 and D1 must carry

1. **T1 no longer "exits 0 whatever happens".** A refused run exits **2** and writes
   nothing. Nothing in the tree reads that exit code (C1 verified), so the exposure is
   a *reader* — **and CLAUDE.md's own bullet says the opposite and needs correcting.**
   That edit belongs to D1.
2. **`V2a`'s detail string now lies on the green path** — it hard-codes "the second run
   announced nothing". C1 deliberately did not edit another crew's suite; it will
   confuse the next reader and should be rekeyed.
3. **`V1a` is a whole-file regexp satisfiable by a comment.** `V2a`/`V2b` are the
   behavioural proof, not `V1a`.

## Alternative shape, costed from where C1 ended

`results.<pid>.log` + rename is **~15 lines** from here, since the preserve-on-wait arm
already builds both halves. But beyond the known "one run's answer is still lost, just
cleanly", **it would red `V2b`** — so overturning R1 retires or rekeys one of A1's rows
rather than merely editing `run_regression.tcl`.

## ⚠ Standing red is CLEARED

With the suite registered, the "any full audit shows red by design" warning no longer
applies. A red in this suite from here is a real red.

## Pre-batch baseline (driver, 2026-09-16)

Solo T1: `rc=0`, **410 s**, `Start=83 / Finish=83`, **ZERO counted failures**,
`results.log` mtime moved. **V1's run should now show 84 cases**, T1 at ~418 s, and
still zero counted failures.

## Resume point

Next task to dispatch: **V1** (solo T1 verification), then **D1** (issue writeups,
including the CLAUDE.md correction above), then companions E1/E2/E3.
