# 1477 — a regression run killed mid-write leaves a truncated verdict that reads as a clean sweep

**Status:** OPEN — filed 2026-09-17 by the harness concurrency batch (task D3), measured in
the tree at `aa0e2213`. This is issue **0905**'s fix shape **(3)**, which that file argued
for and which the batch did **not** implement. 0905 is closed on its own subject (the
collision); the state it warned about is still reachable by another door, and this file is
that door.

**Class:** harness / test infrastructure. **Severity:** high — it is a fail-open on the one
file `CLAUDE.md` calls *"THE ONLY PLACE THE ANSWER IS"*, and it defeats the specific reader
rule that file tells you to trust.

## What the batch closed, and what it did not

The harness concurrency batch (`doc/claude/harness_concurrency_batch/`, issues 0384, 0867,
0905, 0955, 0990, 1476) closed the **collision** route into a short `results.log`: a second
`tclsh run_regression.tcl` in the same tree is now refused loudly, exits 2 and writes
nothing, so it can no longer truncate a finished run's verdict.

**It did not close the interrupted-state route.** A single run, with no second run anywhere,
that is killed between the `open … w` and the `close` leaves a short file behind — and a
short `results.log` is exactly what a clean sweep looks like.

## Mechanism

`tests/run_regression.tcl` opens the verdict at `:563`

```tcl
set a [catch "open \"$log_fn\" w" fd]
```

writes to it throughout the run, and closes it exactly once, at `:720`. The channel is
**never `fconfigure`d** — `grep -n fconfigure tests/run_regression.tcl` returns nothing — so
it carries Tcl's defaults, measured on this box:

```
-buffering  : full
-buffersize : 4096
```

Nothing is written to the file to mark that a run began or that a run ended. `summarize_all`
(`:321-345`) emits, per case, a filename line, any matched lines, and a `Total num fail: N`
line. There is no run-level header and no run-level footer; a repo-wide grep for
`REGRESSION START` / `REGRESSION END` finds the string **only in prose** — in this file's
predecessors and in the batch's own documents — and nowhere in `tests/`.

The counted-failure rule is `:327`:

```tcl
if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
```

**Four patterns, every one of which needs a line to EXIST.** This is the same structural
observation issue 1476 face 2 made about a case that dies before writing its block; here it
applies to the *whole run*. A file that stops early has fewer lines, and fewer lines cannot
match. The driver counts the lines that are there.

## Measured: a truncated verdict scores zero at every length

Run on a **copy** of the real `tests/results.log` left by V2's green run (169 lines, 4785
bytes, 83 `Total num fail:` lines, zero counted failures), applying the exact rule from
`:327`. No suite was run and the tree's own file was not touched.

```
     1 lines -> counted failures: 0   Total-num-fail lines (cases seen):  0
    10 lines -> counted failures: 0   Total-num-fail lines (cases seen):  3
    40 lines -> counted failures: 0   Total-num-fail lines (cases seen): 18
    80 lines -> counted failures: 0   Total-num-fail lines (cases seen): 38
   120 lines -> counted failures: 0   Total-num-fail lines (cases seen): 58
   170 lines -> counted failures: 0   Total-num-fail lines (cases seen): 83
  FULL lines -> counted failures: 0   Total-num-fail lines (cases seen): 83
```

Every prefix of a green run is itself a green run, as far as every automated reader is
concerned.

### And the buffering makes the realistic outcome worse than a prefix

Because the channel is full-buffered at 4096 bytes and the entire verdict file is **4785
bytes**, the whole run's answer is about **1.17 buffers**. Measured directly:

```
200 lines written, NOT closed  ->  on-disk size 4096 bytes
after close                    ->  on-disk size 8090 bytes
```

So a run killed before `:720` does not leave a tidy 90 %-complete log. It leaves whatever
crossed a 4 KiB boundary — for a T1-sized verdict that is **0 bytes or 4096 bytes**, and
0 bytes is precisely the symptom 0905 originally measured. The difference is that 0905's
0-byte file had a second run to blame and this one does not.

## Why it costs a reader more than the collision did

**It passes the mtime test.** `CLAUDE.md`'s guard against a fossil `results.log` is
*"confirm the log's MTIME moved off its pre-run value"*, with an explicit warning that the
md5 proves nothing because a green run is byte-deterministic. A killed run **really did
write the file**: the mtime moves, and the content differs from the previous green run, so
both halves of that rule are satisfied by a verdict that verified a fraction of the tree.

**The one surviving guard is not in the file.** `CLAUDE.md` also says to count
`Start`/`Finish` pairs rather than log lines — but `Start`/`Finish` are printed to
**stdout**, and the same document insists the answer lives in `results.log` and that
grepping the stdout capture is the error. A reader who follows the file-not-stdout rule has
no way to detect this; a reader who counts `Total num fail:` lines gets 58 instead of 83 and
must already know the tree runs 84 cases to notice. That number has been re-derived wrongly
**twice** in this file's own history (the 82/83/84 corrections), which is not a promising
foundation for a safety check.

**Killed runs are routine here, not hypothetical.** `run_regression.tcl:380-392` gives every
case a `T1_CASE_TIMEOUT` (default 900 s) and prefixes it with `timeout --kill-after=20`;
issue 1403 exists because stalls happen. The batch's own doctrine is a `timeout` on every
long command, and V2 ran T1 as `timeout 1800 tclsh run_regression.tcl` — an outer bound that
fires kills the driver itself, mid-write, with nothing to say so. An OOM would do the same,
as 0905 noted.

⚠ **CORRECTION, 2026-09-17 — the OOM was the weakest cause on that list, not the strongest.**
This paragraph said *"An OOM on this ~7.8 GB box"*, inheriting a figure from CLAUDE.md that
nobody had measured. Measured that day, twice: `MemTotal: 16091816 kB` = **15.35 GiB**
(16.48 GB decimal), plus **4 GiB of swap, none of it in use** — wrong by **2×**. During a
deliberate two-run collision the box held **5282 MB minimum available against 487 MB peak
combined `xschem` RSS over 31 processes**, and `dmesg` carries **zero** OOM kills. No file in
this repo records an *observed* OOM: the phrase 0905 used — *"a documented event"* —
documents nothing but another assertion. **The defect is unaffected**, because the timeout
kills above are measured, memory-free and sufficient on their own. Only the attribution
changes. (⚠ Still unmeasured, and not claimed safe: concurrent `make`, and the arms that
start real `ngspice`.)

**The lock makes it rarer, not safer.** Fewer writers means fewer collisions, but a single
writer dying is untouched by mutual exclusion. There is one genuine interaction, and it is
in the wrong direction for a reader: a killed run **deliberately leaves its lock behind**
(`run_regression.tcl:724-732` — *"A RUN THAT DIES BEFORE THIS POINT LEAVES THE LOCK BEHIND,
ON PURPOSE"*), so the next run breaks it on evidence and truncates the fossil away. The
window in which the short file is readable is exactly the window between the kill and the
next run — which is when a human or an agent walks up and reads it.

## How to reproduce

**Cheap, no suite run, no concurrency** — this is what was measured above:

```sh
cp tests/results.log /tmp/full.log          # any green verdict
head -n 80 /tmp/full.log > /tmp/short.log   # simulate the kill
# apply run_regression.tcl:327 to each; both score 0 counted failures
```

**End-to-end — PROPOSED AND UNMEASURED.** I did not run it: a real T1 run is ~375 s and the
batch's rule is that a crew does not run suites while anything else might be live.

```sh
cd tests && timeout 120 tclsh run_regression.tcl   # kill it mid-run
stat -c '%y %s' results.log                        # mtime MOVED, size short
grep -cE 'FAIL$|GOLD\?|RESULT\?|^FATAL' results.log   # expect 0
grep -c 'Total num fail:' results.log                 # expect far fewer than 83
```

## Fix shape — 0905's (3), with two things that file did not know

⚠ **PROPOSED AND UNMEASURED.** I have not implemented or run any of this. This batch's
sharpest finding is that **two of five** issue files (0867 and 0990) confidently prescribed a
fix that was later measured to change nothing — `results/.work.[pid]`, 658 phantoms against
660 — so the label is literal, not modesty.

**0905's reasoning, preserved.** Write a first line (`REGRESSION START <pid> <date>`) and a
last line (`REGRESSION END <pid> rc=<n>`), and have a summary with no END line be treated as
`HARNESS`, not as zero failures. That file's own argument for why (3) is worth doing
*alongside* the lock still stands verbatim: the same missing-END check catches a run killed
by an OOM — ⚠ which 0905 called *"a documented event"* and which the 2026-09-17 correction
above found to be documented nowhere. Read it as *any* kill, which is what the check actually
catches, and the reason (3) survives the correction. It does not stop the interruption; it
removes the fail-open, and 0905 called that *"the part that matters most"*.

**What 0905 did not know — one.** With full buffering, a START line is not evidence of
anything unless it is flushed. A START written at the top of the run sits in the 4 KiB
buffer and dies with the process, so a killed run can leave a file with **neither** sentinel.
The rule must therefore be **"no END line → HARNESS"**, never *"START present but END
absent → HARNESS"*; the latter scores a 0-byte file as fine and reintroduces exactly the
state this issue is about. A `flush` after the START line is the cheap way to make the
START mean something, and the END line needs no flush because `close` follows it.

**What 0905 did not know — two.** It says *"have `banner_rule.tcl` treat a summary with no
END line as `HARNESS`"*. `banner_rule.tcl` today has no run-level predicate at all: its three
procs (`banner_complete`, `banner_died`, `regression_case_failed`, `:92-136`) each take **one
case's body**. A run-level check is a new consumer, not an adjustment of an existing one.
That file is also load-bearing in a way the change must respect — `test_audit_classifier.tcl`
**section K** locks the Tcl rule against `run_suites.sh`'s ERE and `full_audit.sh`'s crash
literals *by verdict*. Adding a proc is plausibly additive rather than drift, but **I have not
verified that section K tolerates one**, and whoever implements this should check before
assuming. Putting the run-level check in `run_regression.tcl` instead avoids the question
entirely, at the cost of the rule living in two files, which is the drift `banner_rule.tcl`
exists to prevent.

**A third option, cheaper than either and worth costing first.** The END line is only useful
to a reader who knows to look for it. An alternative with a smaller blast radius is to have
the run write its **expected case count** into the START line and its **actual** count into
the END line, so the file carries its own arithmetic and a short file is self-evidently
short. This would also retire the recurring 82/83/84 confusion, which has produced three
documented miscounts. Unmeasured, and it costs the byte-determinism of a green verdict
(V2 relied on two runs being byte-identical), so it is not free.

## Not this issue

* **0905** — the collision route into the same state, **fixed**. Its shape (3) is this file.
* **0955** — the same face, filed separately; its closing section already records that
  *"no run can end with a 0-byte log and a zero verdict"* is **met only for this cause**.
* **1476 face 2** — a *case* that dies before writing its block. Same structural
  observation (every counted shape needs a line to exist), one level down, **fixed**.
* **0147** — the historical fail-open where the suite ran no binary and still produced a
  plausible `results.log`. Same class, different cause.
* **1403** — the per-case timeout that makes killed runs routine rather than theoretical.

## Evidence

`tests/run_regression.tcl:321-345` (`summarize_all`), `:327` (the counted rule), `:563` (the
`open … w`), `:720` (the only `close`), `:724-732` (the deliberate lock-left-behind comment),
`:380-392` (`t1_timeout` / the `timeout --kill-after=20` prefix). `tests/banner_rule.tcl:92-136`
(three per-case predicates, no run-level one). Truncation and buffering measurements taken
2026-09-17 on a copy of `tests/results.log` and a scratch channel; no suite was run.
