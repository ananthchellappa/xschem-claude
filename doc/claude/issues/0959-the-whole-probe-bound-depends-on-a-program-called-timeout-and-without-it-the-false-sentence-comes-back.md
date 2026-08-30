# 0959 — the whole probe bound depends on a program called `timeout`, and on a box without one the false sentence comes straight back

**STATUS: OPEN.** Found by item S3a's verification pass, reproduced first-hand by
the write-up before filing. Not a regression — the code S3a replaced needed
`timeout(1)` too — but S3a's central promise is silently conditional on a program
the code itself treats as optional, and nothing says so.

## What the user sees

On a machine without GNU coreutils' `timeout` on the PATH — a stripped container,
a BSD, a Windows build — a user whose simulator is slow to start gets **exactly
the behaviour issue 0953 was filed to remove**: a long freeze on Run, then a false
sentence saying their working simulator is not a circuit simulator, remembered for
the rest of the session. There is no warning, no degraded-mode notice, and nothing
in the Command window that would let them tell this box from a healthy one.

## Measured

Same box, same session, same program (`#!/bin/sh` + `exec sleep 8`), probe budget
3000 ms. The only difference is `ase::cap_timeout_prefix` being empty, which is
exactly what `ase::cap_timeout_cmd` returns when `auto_execok timeout` finds
nothing:

```
A: with timeout(1)     waited  3011 ms  ->  kind = cap_no_answer
B: without timeout(1)  waited 16008 ms  ->  kind = cap_not_a_simulator
B: remembered now: .../bin/slow8
B: second press        waited     0 ms  ->  kind = cap_not_a_simulator
```

Three separate promises fail together, silently:

* **the bound is not applied at all** — 16.008 s is two runs of the full 8 s
  program, so the 3 s budget was not merely exceeded, it was ignored;
* **the sentence reverts** to `cap_not_a_simulator`, the false accusation;
* **and it is remembered**, so issue 0950(a)'s never-cache rule evaporates with
  it — the second press is instant and still wrong.

## Mechanism

`ase::cap_timeout_cmd` (`src/ase.tcl`) returns `{}` when the box has no
`timeout`, and `ase::cap_run` then prepends nothing:

```tcl
set cap [ase::cap_timeout_cmd]
set cmd {}
if {[llength $cap]} { set cmd [concat $cap [list $secs]] }
```

and its cut-off test opens with `[llength $cap] &&`, so `was-it-cut-off` can never
be 1. That guard is *right* on its own terms — a cap that was never applied must
not manufacture a timeout, which is one of the two holes issue 0953 closed
deliberately. The defect is that its consequence is invisible: the answer falls
through to the ordinary `usable 0` verdict, which is `known 1`, which is cached.

## Why the suite cannot see it

`tests/headless/test_ase_simcaps_0948.tcl` rows J5, J6 and J7 all depend on a
cut-off actually happening, so on such a box they do not fail — they measure
something else and pass. Only row **J3** (the kill grace) self-skips loudly.
A green suite on a box with no `timeout` therefore proves nothing about the bound.

## Fix shape, none of it chosen

1. **Do not need the external program.** A `timeout` written in Tcl — spawn with
   `open |...`, `after` a deadline, `exec kill` the pid, then `SIGKILL` after a
   grace — removes the dependency entirely and works on Windows. It is more code
   than the one-liner it replaces, and it is the only option that keeps the
   promise everywhere.
2. **Say so.** When no cap can be applied, answer `{known 0 unmeasured nocap}`
   and mint a sentence for it — the same shape as `noplace` but not silent (see
   issue 0960, which is the argument against a new silent reason).
3. **At minimum, stop remembering it.** A verdict reached with no bound in force
   is still a real measurement of the program, so `known 0` overstates it — but
   caching a `usable 0` that the user cannot clear is what issue 0950 is about.
4. Have the suite **skip loudly** rather than pass, so a box without `timeout`
   reports "the bound was not tested here" instead of a green run.

## Acceptance

* A box with no `timeout(1)` either bounds the probe anyway, or says out loud
  that it could not, and never renders `cap_not_a_simulator` about a program that
  was still running when the probe gave up.
* The suite tells the difference between "the bound held" and "the bound was
  never in force".
