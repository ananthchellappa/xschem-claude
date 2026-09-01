# 0905 — two regression runs at once truncate each other's verdict, and the wreckage reads as a pass

**Status:** 🔴 **OPEN — filed, not fixed.** A **fail-open** harness defect: the
destroyed evidence is indistinguishable, to every reader in the tree and to a
human, from a clean run.

**Filed:** 2026-08-28 by the item A14 write-up. Measured during A14's
verification pass, when it happened to a real, finished, exit-0 run; the
mechanism confirmed at the statement by the write-up agent.

## What happens

`tests/run_regression.tcl` writes its summary to **`results.log` in the current
directory**, opened for writing with no lock and no run-unique name:

```tcl
set log_fn "results.log"
...
set a [catch "open \"$log_fn\" w" fd]        ;# run_regression.tcl:114
```

Mode `w` truncates on open. So when a second `tclsh run_regression.tcl` starts in
the same `tests/` directory — another agent, another terminal, a background job —
its `open` **empties the first run's finished summary**, whether that run is
still going or completed minutes ago.

Measured instance: a T1 run finished at 08:52 and exited 0. A second T1 started
at 08:55:55. The first run's `results.log` was **0 bytes** afterwards.

## Why it is worse than losing a file

**A 0-byte `results.log` passes every check anyone applies to it.** The rules in
`tests/banner_rule.tcl`, the two shell readers, `run_regression.tcl`'s own
summariser and a human reading the file all look for the *presence* of `FAIL`,
`FATAL`, `GOLD?` or `RESULT?`. An empty file has none of them. The reader
concludes **zero failures** — from a file that verifies nothing and that nobody
can still read.

`CLAUDE.md` already records the branch's standing rule that *"a standing red is a
defect, not furniture"* and that this branch has shipped two defects past
twenty-eight passing checks. This is the shape one level further back: not a red
mistaken for furniture, but a verdict that was never there being read as green.
It is the same fail-open class as issue **0147**, where an unlaunchable binary
still produced a plausible `results.log`.

## Blast radius beyond the summary

The two runs also share, and therefore corrupt:

* `<case>/results/` — every case's output directory;
* `<case>.log` — the per-case logs the summariser reads; and
* `headless/*.disp.log` — the display-arm logs, which are written on `:99` by
  both runs at once.

So an overlapping pair can produce a `results.log` that is not empty but is
**stitched from two runs**, which is worse: it looks entirely normal.

## Why it bites this branch specifically

T1 gained a display arm (`dcases`, `tests/run_regression.tcl`), which makes a run
take about five minutes; issue **0898** already records that its wall-clock row
flakes on a loaded box, so agents are told to *"run T1 alone"*. The instruction
exists, is easy to follow imperfectly with several agents live, and **there is
nothing that notices when it is not followed** — which is precisely why the
failure mode has to be closed in the harness rather than in the instructions.

## The shape of a fix — not attempted here

1. **An exclusive lock.** Take an `O_EXCL` lock file in `tests/` at startup; a
   second run refuses loudly (`HARNESS: another regression run is live, pid N`)
   rather than starting. Cheapest, and it makes the collision impossible instead
   of merely visible.
2. **A run-unique log**, `results.<pid>.<epoch>.log`, with `results.log` a
   symlink or copy written at the *end*. Allows concurrency; costs every reader
   an update.
3. **At minimum, never let an empty file read as a pass.** Have the runner write
   a first line (`REGRESSION START <pid> <date>`) and a last line
   (`REGRESSION END <pid> rc=<n>`), and have `banner_rule.tcl` treat a summary
   with no END line as `HARNESS`, not as zero failures. This does not stop the
   collision but removes the fail-open, and is the part that matters most.

(3) is worth doing even alongside (1) or (2): the same missing-END check also
catches a run killed by an OOM, which on this ~7.8 GB box is a documented event.

## Not this issue

* **0898** — T1's display arm makes a wall-clock row flake on a loaded machine.
  Same trigger (concurrent agents), different failure: 0898 produces a visible
  red, this one produces a silent green.
* **0147** — the historical fail-open where the suite ran no binary at all.

## Evidence

`tests/run_regression.tcl:77` and `:114` (the `results.log` name and the mode-`w`
open). The measured 0-byte instance is recorded in item A14's verification pass,
2026-08-28.

## Second sighting, 2026-08-29 — the stitched variant, and it produced a FALSE RED

Recorded here rather than given a new number, per `CLAUDE.md` on 0689/0690: this
is the same defect with a different surface, not a second defect.

Hit live by the verification pass of item **B3** (issue 0861). `results.log`
carried **47** blocks where the tree has 45, and one counted failure:

    HARNESS: headless/test_annot_stale_0684 (display arm) did not complete
    cleanly (exit=0, OVERALL_ok=0, died=0) ... : FAIL

It was not a real red, and four pieces of evidence say so:

1. **Two blocks for the same suite** — one at `Total num fail: 0`, and a second
   one whose block header was torn to `/test_annot_stale_0684.disp.log`, its
   `headless` prefix clobbered mid-write. A single writer cannot produce that.
2. **47 blocks against 45**, which is the same interleaving counted a second way.
3. `ps -ef` at that moment showed a concurrent
   `tests/headless/devdisplay.sh exec … test_annot_stale_0684.tcl` and a second
   agent's mutation loop in another checkout, both sharing `:99`.
4. `tests/headless/test_annot_stale_0684.disp.log` — the file the harness
   judged — ends with `RESULT: ALL PASS (52 checks)` and `OVERALL: ok` and
   carries **no appended HARNESS line**. The FAIL was recorded against a version
   of that file that had already been overwritten.

Re-run alone with the harness's exact command: `rc=0`, 52 checks, `OVERALL: ok`.
Re-run of the whole regression on a verified-quiet box: 45 blocks, all at
`Total num fail: 0`.

**The mechanism this sighting adds** is the one named under "Blast radius" above,
now measured: the per-suite `headless/*.disp.log` names are **not PID-qualified**,
so two regressions in the same tree race on them and the summariser reads a file
that a different run has since replaced. Fix shape (2) — run-unique names — has
to cover these, not only `results.log`.

**Operational note for anyone taking a number off this harness**, and especially
for a sabotage pass: `results.log` and the `.disp.log` files are shared and
truncating. A run that overlaps another agent's suite produces numbers that are
silently not its own — the same class of lie as a `cp -p` restore whose preserved
mtime makes `make` a no-op. Check the box is quiet first; `ps -ef | grep -E
"xschem|run_regression"` returning nothing is the cheap version.
