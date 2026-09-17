# 0905 — two regression runs at once truncate each other's verdict, and the wreckage reads as a pass

**Status:** ✅ **FIXED 2026-09-17** by the harness concurrency batch — `43b40f04`
(the verdict lock) with `5f7164d4`. See "Closed" at the bottom, issue **1476**, and
`doc/claude/harness_concurrency_batch/`.

~~🔴 **OPEN — filed, not fixed.**~~ A **fail-open** harness defect: the
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

## Closed — 2026-09-17

Fixed by **`43b40f04`** (the verdict lock) with **`5f7164d4`** (per-run results
roots). Red suite at **`5114dd8b`**; registered and verified at **`d4946b61`** —
solo T1, **84 cases, ZERO counted failures, rc 0**. The two faces that were in no
issue file are **1476**. Batch record: `doc/claude/harness_concurrency_batch/`.

**Against this file's three proposed shapes:**

1. **An exclusive lock — landed, and it is what shipped.** `tests/results.log.lock`,
   taken with `open … {WRONLY CREAT EXCL}` (⚠ **not** `file mkdir`, which in Tcl
   *succeeds silently* on an existing directory and would hand the lock to both runs
   while reading as correct in review). The second run refuses loudly and **exits 2
   writing nothing**, naming the holder's pid, script and age, and saying in as many
   words that *"the `results.log` on disk is NOT YOURS"* — because a silent refusal
   is just another way to lose a verdict. Stale locks are broken on evidence (owner
   pid gone, or `/proc/<pid>/cmdline` no longer the script that took it, since a bare
   `kill -0` answers yes for a recycled pid), with `T1_LOG_LOCK_TTL` as a backstop.
   ⚠ This file said the second run should "refuse **rather than starting**"; note
   that the *other* obvious reading — let it wait — was measured to be the
   **data-losing** option. A run that queues politely and then opens mode `w` leaves
   `results.log` holding **0** of the first run's four case blocks. Waiting is
   therefore opt-in (`T1_LOG_LOCK_WAIT`) and **preserves** the prior verdict as
   `results.<pid>.log` before taking the canonical name.
2. **A run-unique log with `results.log` written at the end — considered and
   deliberately NOT taken** (ruling R1, `doc/claude/harness_concurrency_batch/DECISIONS.md`).
   It costs the canonical filename that `doc/claude/ledger/crew.js`, CLAUDE.md's own
   reading instructions and the user all name explicitly, and the second finisher's
   rename still overwrites the first's verdict — one run's answer is still lost, just
   lost *cleanly*. The lock keeps **both** answers, which is the one thing the rename
   shape cannot do. The option is costed in DECISIONS.md if it is ever reopened.
3. ⚠ **"Never let an empty file read as a pass" — NOT IMPLEMENTED.** There is still
   no `REGRESSION START/END` sentinel and `banner_rule.tcl` is unchanged, so a run
   killed mid-write (OOM on this ~7.8 GB box, or issue 1403's 900 s per-case timeout)
   can still leave a short file that reads as green. What closed is the *collision*
   route into that state, not the state itself. **CLAUDE.md's rules remain the
   reader's only guard**: confirm the log's mtime moved off its pre-run value, count
   `Start`/`Finish` pairs rather than log lines, and treat an empty log after a run as
   a death, never as a zero. This file's own argument that (3) is worth doing
   alongside (1) still stands, unaddressed.

⚠ **The second sighting's `.disp.log` residual is real — but the description that
stood here until 2026-09-17 was WRONG, and it sent readers hunting a writer that does
not exist.** This paragraph used to say that a standalone suite run on `:99` (a bare
`./src/xschem --script`, a `devdisplay.sh exec`, another clone's mutation loop) is not
enrolled in the lock and "can still race those files against a live T1". **It cannot.**
Measured repo-wide by task D3 and **re-measured independently by task F1**: the **only**
writer of `headless/*.disp.log` anywhere in this repository is `tests/run_regression.tcl`
itself, at `:669, 671, 691, 696, 700, 704`. The three ways a standalone suite is actually
launched all write somewhere else — `devdisplay.sh`'s `cmd_exec` (`:399-403`) performs
**no redirection at all**, being exactly `DISPLAY="$DPY" GUI_GATE=0 "$@"`;
`run_suites.sh` (`:121, 123, 125`) and `full_audit.sh` (`:475-485`) capture the child
into a shell **variable**, never into a file beside the suite; and
`tests/headless/scratch.tcl` already hands each process a **pid-qualified** directory.
A single writer cannot race itself. The 2026-08-29 sighting is not in doubt — what that
pair raced was the **display**, plus whichever of them was a `run_regression.tcl` run.

**The residual's real subject is different: four FIXED names whose only protection is a
lock that is documented to fail open.** `<case>.log`, `headless/<case>.log`,
`headless/<case>.disp.log` and the display arm's shared `--logdir`
(`tests/results/.actionlogs`, `run_regression.tcl:661-662`) are all unqualified names
shared by every run in the tree; and `t1_lock_take` **proceeds UNLOCKED after four
failed attempts** (`:502-505`), announcing it only on stdout — the stream this file's
own closure tells readers not to trust. **Filed as issue 1478**, which opens with this
correction. Do not repeat the standalone-race sentence.
