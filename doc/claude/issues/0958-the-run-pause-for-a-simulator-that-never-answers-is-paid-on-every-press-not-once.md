# 0958 — the Run pause for a simulator that never answers is paid on EVERY press, not once

**STATUS: OPEN.** Found and measured 2026-08-30 by item S3a's verification pass,
reproduced first-hand by the write-up before filing. It is a **consequence of
S3a's own fix**, not a defect S3a inherited, and it is filed rather than fixed
because the remedy is a design choice the user has not been offered.

## What the user sees

They pick a simulator that is slow to start, or one that never answers at all
(a licence server that is down, a network mount that has gone cold). They press
**Run**. The editor stops responding for thirty seconds, then tells them the
program had not finished with the test circuit, and the run goes ahead.

They press **Run** again. Another thirty seconds. And again. And again. Every
single press costs the full pause, for the whole session, with no way to switch
it off.

Before item S3a landed, the same user paid **twenty seconds once** and then
nothing at all, because the wrong answer was remembered. So for the user who
keeps pressing Run, this is worse than what it replaced, and it grows without
bound.

## Measured

Directly, on the built `src/xschem`, with the probe budget lowered to 3000 ms so
the shape is visible cheaply. The program is `#!/bin/sh` + `exec sleep 300`:

```
PRESS 1 : 3004 ms -> known 0 unmeasured timeout secs 3
PRESS 2 : 3003 ms -> known 0 unmeasured timeout secs 3
PRESS 3 : 3005 ms -> known 0 unmeasured timeout secs 3
```

At the shipped `ase::cap_budget_ms` of 30000 that is **thirty seconds a press —
ninety seconds across three presses of Run.** The verification pass measured
exactly that with the real budget: "press Run #1 frozen 30.0 s, #2 frozen 30.0 s,
#3 frozen 30.0 s — 90.0 s across three presses."

## Mechanism

Two correct rules meeting at a bad joint, neither of them wrong on its own.

* Issue **0950(a)**: an answer nobody worked out is never remembered.
  `ase::sim_capabilities` caches only `known 1`.
* Issue **0953**: a probe that is cut off answers `{known 0 unmeasured timeout}`.

So a cut-off is, correctly, not a fact about the program — and therefore,
correctly, not cached — and therefore re-measured from scratch on the next Run.
Both halves are right. The user pays for them.

## Why this was not visible

The rule debt on the user's queue (`owed.sh rule 0953`) reads "**30 s once for
the whole measurement**". That "once" means *once per measurement instead of once
per probe run* — it is about the 20 s that was two 10 s caps. A user reading it
would reasonably understand "once", full stop, and ratify a cost that is not the
one they will pay. **The debt text has been corrected to say per press.** Issue
0953's own "Still open" paragraph said "one bounded pause", singular, and has
been corrected too.

## The options, none of them ratified

1. **Remember that the program did not answer, without remembering it as a
   capability answer.** A second, separate note keyed on the program file and its
   stamp — "this one timed out at HH:MM" — consulted before probing again, so the
   second press is instant and the answer is still not a claim about what the
   program can do. Costs: a program that was merely slow because the machine was
   busy is not retried until its file changes.
2. **Back off.** Probe again, but with a much smaller budget after the first
   cut-off (say 30 s, then 5 s, then 1 s). The user pays the full pause once and a
   negligible one thereafter, and a program that starts working is still picked up.
3. **Re-probe only when the program file changes**, exactly like a `known 1`
   answer, and treat a cut-off as settled until then. Simplest; loses the retry
   that issue 0953 explicitly wanted.
4. **Get the probe off the Run gesture altogether** — issue 0953's own larger
   half. This closes the question rather than answering it, and is the real fix.
5. **Leave it.** Defensible only if pressing Run repeatedly at a dead simulator is
   rare, which nobody has measured.

## Acceptance

* Pressing Run three times at a program that never answers does not cost three
  full budgets.
* A cut-off is still never reported as a fact about the program, and a program
  that starts working is still measured correctly without the user doing anything.
* The healthy path stays at its measured ~14 ms cold, nothing warm.
