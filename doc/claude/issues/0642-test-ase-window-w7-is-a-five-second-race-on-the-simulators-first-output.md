# 0642 — `test_ase_window` W7 is a 5-second race on the simulator's first output

Status: **OPEN — flake, measured once, not fixed.** Filed by the 0617+0618 crew,
2026-08-23. Related: 0629 (the other harness-shaped false red).

## The row

`tests/headless/test_ase_window.tcl:990-997`, check *"simulator produced output before
Stop"*. It launches a 10-second `tran` and waits up to **5 seconds** for ngspice's first
stdout bytes to appear in `execute(data,$id7)` before pressing Stop.

## Observed

One FAIL during the 0617+0618 run; **PASS on the immediate re-run**, and PASS on every
subsequent run (the crew's Verify-A agent did not reproduce it at all — green first
try). ngspice's stdout is block-buffered through the pipe, so the first bytes arrive
when the buffer flushes, not when the simulation starts; under load on this box that
can exceed 5 s.

It reads `execute(data,$id7)` and never opens the log file, so it is **not** sensitive
to 0618's log framing — checked before filing, because a green-to-red flake in the same
session as a log change is exactly the coincidence worth ruling out.

## Recommended

Do not raise the timeout — that trades a flake for a slow suite and hides the real
signal. Either wait on a deterministic event (poll until `execute(data,$id7)` is
non-empty *or* the process exits, and skip the row if it exits first), or force the
race deterministically the way `test_calc_skeleton` S12 does. The project rule applies:
treat a bug only an environment can reproduce as a **test** defect.

---

## 2026-08-27 — reproduced TWICE more, during the 0868 (A3) run

Still open, still unfixed, and it cost two agents time on this run alone. Both hits
were on `:99` with openbox live, under load from a concurrent agent's builds:

* the tier leg saw `5 FAILED (216 passed)` once with W7 among the reds, then
  `221/221 ALL PASS` on a re-run against a **byte-identical tree hash** — the tree
  was hashed before and after each run precisely because a concurrent sabotage agent
  was editing Tcl files in the same tree;
* the sabotage leg saw W7 red during one variant run (`got {0} want {1}`) that
  touched **only** the ASE-L *Results > Annotate* submenu's `entryconfigure` and
  pull, which cannot be causal, and green in the baseline, in the other variant runs,
  and in the post-restore re-run.

Two more crews therefore re-derived the same conclusion the "Recommended" section
above already reached. This is now the **third** recorded sighting. Related: **0801**
(the same suite is load-sensitive more broadly).

⚠ For anyone reading a red W7 in a report: it is a 5-second poll for a real ngspice's
first buffered stdout, and it says nothing about the change under test. Re-run before
attributing it.
