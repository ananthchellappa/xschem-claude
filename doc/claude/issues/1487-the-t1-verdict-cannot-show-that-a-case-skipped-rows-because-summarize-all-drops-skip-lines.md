# 1487 — the T1 verdict cannot show that a case skipped rows, because `summarize_all` drops `skip:` lines

**STAMP:** `v1 claim=open tree=7a46275f stamped=2026-09-18 fix=none open=1 by=F-docs`

**Status: OPEN — filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D12, and from the S2c completeness critic's
problems 4 and 5 (`receipts/S2c_refute_r1.md`). **Class** harness / verification method:
lost coverage that reads as a pass. **Related:** **0147** (NOGOLD, the precedent for a
printed-but-uncounted line), **0891** (NODISPLAY, the same precedent reapplied), **1485**
(nine suites whose honest fix is more skips).

---

## The defect

`summarize_all` in `tests/run_regression.tcl` copies exactly two kinds of line from a case
log into the verdict (READ at `7a46275f`):

* the counted shapes `FAIL$`, `GOLD?$`, `RESULT?$` and `^FATAL`;
* the uncounted notes `^(NOGOLD|NODISPLAY)`.

A suite's `skip:` lines, which name a row it could not run and why, are **not** carried.
Neither is its `RESULT: ALL PASS (N checks)` line, which states N. So a case that skipped
six rows and one that skipped none leave identical blocks: the log name, then `Total num
fail: 0`.

## Measured on the gate that proved the batch

The stage-F gate at `7a46275f` was `T1-RUN-END cases=87 blocks=86 counted_failures=0`.
Its HOME was a copy of the real `~/.xschem`, `.gitconfig` and `.ngspice_history`, and it
did **not** include the fork ngspice under `~/dev/ngspice`. Read from its own case logs
(mtimes inside the run, 19:12:52–19:21:29), MEASURED:

| case log | `skip:` lines | its `RESULT:` | with the fork present |
|---|---|---|---|
| `headless/test_ase_converge_1459.log` | 1: `skip: EE/fork -- no executable at '…/gate_f/home/dev/ngspice/build-ver_50/src/ngspice', so this leg did not run` | `ALL PASS (70 checks)` | 76 (D17; the S2c regression refuter, 70 unset and 76 set) |
| `headless/test_ase_sp_1452.log` | 2: `SE/fork`, `SE3/fork` | `ALL PASS (58 checks)` | 61 (D17) |
| `headless/test_op_annot.log` | 5: `M1/M2`, `O14/O36/O38`, `W23`, `W29`, `V53` (need a display or an action log on the headless arm) | `ALL PASS (485 checks)` | these rows run on the display arm |

**8 `skip:` lines in the case logs, 0 in the verdict** (`/usr/bin/grep -c 'skip:'
tests/results.1176485.log` → `0`). The verdict reads as a clean sweep of 87 cases, while
the fork-ngspice legs ran nine checks fewer than D17 recorded: (76 − 70) + (61 − 58),
the gate's counts set against the round-2 refuters'. The skips are **correct**: D10 made
those rows skip by name instead of passing silently. **Only the verdict hides them.**

This is exactly the risk the S2c critic named (problem 4): whether any suite runs fewer
checks under the throwaway HOME than under a real one cannot be read from a T1 verdict.
The crews answered it only by diffing per-case `RESULT` lines by hand.

## What already shows them

`run_suites.sh` does, since D13.11: it prints each `skip:` line a suite emitted, indented
under its verdict line. The R3 prover measured `| skip: W23 … (no action log -- run with
--logdir)` under `test_op_annot`. So the armed single-suite command shows skips and the
regression run does not.

## Fix direction

1. Carry `^skip:` lines into the verdict **uncounted**, next to `NOGOLD|NODISPLAY`, and
   the case's last `RESULT:` line with its check count. Then a per-case comparison between
   two verdicts is a `diff`, not an excavation.
2. Optionally add a `skips=` field to `T1-RUN-END`, as `cases=`, `blocks=` and
   `counted_failures=` already are.
3. ⚠ **Both change `wc -l`.** CLAUDE.md's green figure (177 at `7a46275f`) and
   `test_regression_concurrency_1476`'s V rows would move, so update them in the same
   change, from a measured run. ⚠ **A carried line must not be able to score.** A `skip:`
   reason that happens to end in `FAIL` would match `FAIL$`. Test the new branch after
   the counted one, as `NOGOLD` is, or anchor it.

## Evidence

`tests/results.1176485.log` and the case logs named above (the stage-F gate);
`doc/claude/outsider_fixes_batch/receipts/S2c_refute_r1.md` (critic problems 4 and 5;
regression refuter point 10); `DECISIONS.md` D10, D13.11, D17.
