# 1478 — the per-case log names are not pid-qualified, so their only protection is a lock that fails open

**Status:** OPEN — filed 2026-09-17 by the harness concurrency batch (task D3), measured in
the tree at `aa0e2213`. This is the residual of issue **0905**'s *second sighting*
(2026-08-29), which 0905 recorded without a number of its own and which its closing section
flags as *"only partly closed"*.

**Class:** harness / test infrastructure. **Severity:** low-to-medium and **latent** — the
verdict lock removes the configuration in which it was actually observed. It is filed
because the remaining exposure is real, is invisible when it bites, and depends on a
mechanism that is documented to fail open.

## ⚠ First, a correction: the inherited description of this residual is wrong

Issue 0905's closing section, and the D1 receipt that wrote it, both say:

> the per-suite `headless/*.disp.log` names are **still not pid-qualified**, and the lock
> covers `run_regression.tcl` only — a standalone suite run on `:99` (a bare `./src/xschem
> --script`, a `devdisplay.sh exec`, another clone's mutation loop) is not enrolled in it and
> can still race those files against a live T1.

**The standalone half of that does not hold.** Measured 2026-09-17 by a repo-wide grep, the
**only** writer of `headless/*.disp.log` anywhere in this repository is
`tests/run_regression.tcl` itself:

```
tests/run_regression.tcl:669   file delete -force ${dc}.disp.log
tests/run_regression.tcl:671   puts $fd "${dc}.disp.log"          (the NODISPLAY path)
tests/run_regression.tcl:691   eval exec $dccmd > ${dc}.disp.log 2>@1
tests/run_regression.tcl:696   open ${dc}.disp.log r              (read back for the verdict)
tests/run_regression.tcl:700   open ${dc}.disp.log a              (append the HARNESS line)
tests/run_regression.tcl:704   summarize_all ${dc}.disp.log $fd
```

Nothing else creates one, and the three ways a standalone suite is normally launched all
write somewhere else:

* **`devdisplay.sh exec`** performs **no redirection at all** — `cmd_exec` (`:399-403`) is
  `DISPLAY="$DPY" GUI_GATE=0 "$@"`. The child's output goes wherever the caller's stdout
  goes.
* **`run_suites.sh:121, 123, 125`** and **`full_audit.sh:475-485`** capture the child into a
  shell variable (`out=$(timeout "$TIMEOUT" "$XSCHEM" … )`), never into a file beside the suite.
* **`tests/headless/scratch.tcl`** hands each process a **pid-qualified** directory —
  `tests/headless/.scratch/_<tag>_<pid>` (`:46-50`, `:104`) — with a dead-pid sweep and a
  300 s age floor (`:68`). It is already safe by construction.

So a standalone suite on `:99` **cannot** write `<case>.disp.log` and cannot race it. The
sentence should not be repeated; it sends the next reader to look for a writer that is not
there. (0905's 2026-08-29 sighting itself is not in doubt — its evidence names a concurrent
`devdisplay.sh exec … test_annot_stale_0684.tcl` **and** a second agent's loop in another
checkout, alongside a T1. What that pair raced was the **display**, and whichever of them
was a `run_regression.tcl` run raced the file.)

## What is actually still exposed

Four paths in `run_regression.tcl` are fixed names shared by every run in the tree. The
batch made the per-case **results trees** per-run; it did not touch the **log names** or the
display arm's action-log directory:

| path | site | qualified? |
|---|---|---|
| `<case>.log`, `<case>_output.txt` (top-level cases) | `:571, 574, 582, 587` | no |
| `headless/<case>.log` | `:620, 625, 629, 633` | no |
| `headless/<case>.disp.log` | `:669, 671, 691, 696, 700, 704` | no |
| `tests/results/.actionlogs` (the display arm's `--logdir`) | `:661-662` | no |

That last one is worth naming separately: `set dlogdir [file join [pwd] results .actionlogs]`
is `tests/results/` — **not** any case's per-run root, and not covered by the `.gitignore`
rules the batch added for `tests/<case>/results.*/`. It exists on this tree right now and is
invisible to `git status` only because everything inside happens to be named `Xschem.log*`,
which `.gitignore:30-31` matches. Verified on a real file (a `check-ignore` against a path
that does not exist is not a check — V2's lesson):

```
git check-ignore -v tests/results                        -> rc 1, NO match
git check-ignore -v tests/results/.actionlogs/Xschem.log -> .gitignore:30:Xschem.log
git status --short --ignored -- tests/results/.actionlogs -> !! tests/results/.actionlogs/
```

The directory itself matches nothing. It disappears from `git status` because *all of its
contents* are ignored — so the day the display arm writes a file there under any other name,
it becomes untracked noise. Issue **1359** put the action logs here precisely so a display
case could read its own; it did not make the directory per-run.

**Their only protection is the verdict lock, and the lock is documented to fail open.**
`t1_lock_take` (`run_regression.tcl:481-523`) gives up after four failed attempts to take or
break the lock and says so:

```
WARNING: <lock> can be neither taken nor broken after N attempts.
WARNING: running UNLOCKED -- a second run in this tree can still erase this run's verdict.
```

(`:502-505`.) That is the right design — issue 1476's own rule is that *a lock must never
become the reason T1 does not run* — but it means the guarantee protecting these four paths
is best-effort, whereas the guarantee protecting the results trees is **structural** (a
different pid is a different directory name). Two mechanisms, two strengths, and only one of
them is named in the docs.

Two further gaps in the same protection: a TTL break (`T1_LOG_LOCK_TTL`, default 14400 s)
that misjudges a genuinely long run hands the tree to two writers, and on a box with no
`/proc` the liveness test degrades to `kill -0` (`t1_lock_owner_alive:464-475`), which answers
yes for a **recycled** pid — the case the cmdline check exists to catch on Linux.

## What a collision costs, when it happens

0905's second sighting is the measured record, and it produced a **false RED** rather than a
false green — the summariser judged a version of the file that another run had already
replaced:

```
HARNESS: headless/test_annot_stale_0684 (display arm) did not complete
cleanly (exit=0, OVERALL_ok=0, died=0) ... : FAIL
```

…while the file on disk ended `RESULT: ALL PASS (52 checks)` / `OVERALL: ok`, with **47**
blocks in a 45-case tree and one block header torn mid-write to
`/test_annot_stale_0684.disp.log` — its `headless` prefix clobbered. A single writer cannot
produce that. Re-run alone: `rc=0`, 52 checks, `OVERALL: ok`.

The cost is a crew bisecting a product defect that does not exist, which is the same bill
0384 recorded for the phantom `FATAL`s. It is cheaper than a false green, and that is the
whole reason this is filed at low severity rather than high.

## How to reproduce

**Not reproduced.** Doing so needs two concurrent `run_regression.tcl` runs in one tree,
which is what the verdict lock now refuses by default and what this batch's crew rules
forbid. What **was** measured, 2026-09-17, is the naming and the ownership: the repo-wide
grep for `.disp.log` writers above, the `devdisplay.sh`/`run_suites.sh`/`full_audit.sh`
redirection paths, the `scratch.tcl` pid-qualification, and the three `check-ignore` results.

To reproduce the exposure deliberately, force the lock out of the way — `T1_LOG_LOCK_WAIT`
with a second run, or by removing `tests/results.log.lock` mid-run — and watch two runs write
one `<case>.disp.log`. **PROPOSED AND UNMEASURED**; I did not run it.

## Fix shape

⚠ **PROPOSED AND UNMEASURED.** Nothing below has been implemented or run. The batch's
sharpest finding is that two of its five issue files prescribed a fix later measured to do
nothing, so this label is literal.

**The obvious shape is to pid-qualify the four names**, matching what `5f7164d4` did for the
results trees: `<case>.<pid>.log`, `<case>.<pid>.disp.log`, `results.<pid>/.actionlogs`, with
a publish-back to the canonical name at the end exactly as `publish_results`
(`test_utility.tcl:214-228`) already does for the results directory, and a `sweep_dead_run_dirs`
equivalent for the leftovers.

**Three things make it less obvious than it looks, and they should be costed before anyone
starts:**

1. **The file name goes INTO the verdict.** `summarize_all` writes its argument as the block
   header (`:322`, `puts $fd "$fn"`), and the display arm passes `${dc}.disp.log` (`:704`,
   and `:671` on the NODISPLAY path). Pid-qualifying the name therefore changes what
   `results.log` **contains** — every block header gains a pid. That breaks the
   byte-determinism of a green verdict that V2 relied on to detect a fossil, and any reader
   keying on the literal `headless/<name>.disp.log` sees new text. A publish-back before
   `summarize_all` avoids it; a publish-back after does not.
2. **A1's no-op has a lookalike here.** Pid-scoping the scratch *inside* the shared
   `results/` was measured at **658 phantoms against 660** because the shared object was the
   parent directory, not the leaf. Here the shared object **is the file name**, so the same
   trap does not obviously apply — but "obviously" is what 0867 and 0990 both said. Measure
   the fix against a forced collision before believing it.
3. **It may not be worth it.** The lock already removes the observed configuration, and the
   failure is a false red, not a false green. A cheaper answer to the same risk is to make
   the fail-open arm **loud in the verdict** rather than only on stdout — today
   `:503-504` `puts` to stdout, which is the stream `CLAUDE.md` tells readers not to trust,
   so a run that proceeded UNLOCKED leaves no trace in the file that is *"the only place the
   answer is"*. One `puts $fd` would make every unlocked run self-identifying. That is a
   smaller change than pid-qualifying four paths, and it addresses the part that is actually
   dangerous: not knowing which mode you were in.

## Not this issue

* **0905** — the collision that this is the residual of; **fixed** for the
  `run_regression.tcl`-versus-`run_regression.tcl` case. Its second sighting is the evidence
  quoted above.
* **1476 face 2** — the per-run **results trees**, which *were* fixed. This file is about the
  paths that fix did not cover.
* **1359** — why the display arm has a `--logdir` at all (it used to overwrite the user's own
  `/tmp/Xschem.log.N`). It placed the directory; it did not make it per-run.
* **1477** — the other 0905 residual: a killed run's truncated verdict. Independent
  mechanism, independent fix.
* **0891** — the display arm's existence and its NODISPLAY rule.

## Evidence

`tests/run_regression.tcl:661-662` (the shared `--logdir`), `:669-704` (the display arm's
fixed `.disp.log` name, six sites), `:481-523` (`t1_lock_take`), `:502-505` (the fail-open
WARNING), `:464-475` (`t1_lock_owner_alive`), `:322` (the block header). 
`tests/headless/devdisplay.sh:399-403` (`cmd_exec`, no redirection).
`tests/headless/run_suites.sh:121, 123, 125`, `tests/headless/full_audit.sh:475-485`
(variable capture).
`tests/headless/scratch.tcl:46-50, 68, 104` (pid-qualified scratch). `.gitignore:30-31, 94-96`.
Grep, ownership and ignore measurements taken 2026-09-17; no suite was run and no collision
was forced.
