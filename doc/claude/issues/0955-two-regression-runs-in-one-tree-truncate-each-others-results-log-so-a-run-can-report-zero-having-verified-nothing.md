# 0955 — two regression runs in one tree truncate each other's `results.log`, so a run can report ZERO having verified nothing

**STATUS: OPEN — measured 2026-08-30 by 0948's verification pass. A harness
defect, unrelated to the feature work that found it. Sibling of issue 0867,
which is the same collision in a different file and in the opposite direction.**

## Why this one is the dangerous direction

0867's collision produces phantom **FAILURES** — noisy, expensive, but loud. This
one produces a phantom **PASS**. A run whose log has been truncated under it
reports exit 0, a full set of Start/Finish lines on stdout, and zero counted
failures, having verified nothing whatsoever. On a branch whose baseline is
"ZERO counted failures", that is the number everyone is looking for, and it is
the number a destroyed log always gives.

It is issue **0147**'s failure mode — "a plausible `results.log` while nothing
was verified" — arriving through a new door: parallel runs, not a missing
binary.

## Measured

Two agents each ran `cd tests && tclsh run_regression.tcl` in the same checkout.
The second run started at 00:21:06 and truncated the first, still-running, run's
log to **zero bytes**. The first run's grep for counted failures then read an
empty file and would have published a vacuous ZERO.

The tell, for anyone reading a suspiciously clean run: a 0-byte `results.log`
whose modification time is the run's **start**, not its end.

The verifier recovered by waiting the other run out (`tail --pid`), re-running
alone, and snapshotting the log immediately; the two logs then came out
byte-identical, which is what makes that run's number trustworthy.

## Mechanism

```tcl
tests/run_regression.tcl:88   set log_fn "results.log"
```

A fixed **relative** path, opened `w`. Every run in a tree writes the same file
and truncates whatever is there. The per-case `<case>.log` files and the case
scratch directories are shared the same way, so while two runs overlap **both**
are suspect, not just the one that noticed.

## Fix shape

The tree already has the pattern, twice over: `run_parallel_cmds` writes
`.parallel_jobs.[pid]` (`tests/test_utility.tcl:82`), and 0867 asks for the same
pid scope on `open_close`'s work root. Either

* scope the log per run (`results.[pid].log`, with a stable symlink or a final
  copy to `results.log` for the readers that expect the name), or
* take a lock at start and make the second run say plainly that another run owns
  this tree — which is arguably better, because two concurrent runs in one tree
  are never really independent measurements anyway (see 0867's shared temp
  directories).

## Acceptance

* Two `tclsh run_regression.tcl` runs started ~30 s apart in one tree either both
  report their own complete results, or the second one refuses and says why.
* No run can end with a 0-byte log and a zero verdict.
* Fixing this together with 0867 is the sensible shape: same cause, same file
  family, one change.
