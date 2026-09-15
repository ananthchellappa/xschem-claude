# PSS on the two binaries in the matrix — the plan's table came from a build users do not have

**Measured 2026-09-15 by the driver, before Stage 14 was briefed**, the way M9 was measured before
Stage 12. `PLAN.md` §14 and `APPENDIX` §2.12 build Stage 14 on `evidence/builds.md` Part 1 — and
every PSS number there was taken on a **scratch** `--enable-pss` build (`builds/pss/src/ngspice`,
from the `ver_50` source at `ccebdf2a2`). The only PSS measurement on the two binaries a user can
run was `pss-stage14.md`'s argument count. This file re-takes the rest.

* **fork** — `/home/analog/dev/ngspice/build-ver_50/src/ngspice`, md5 `c435f1431e68…`, `ngspice-46+`, rebuilt `--enable-pss --enable-cider` on 2026-09-10
* **apt 45.2** — `/usr/bin/ngspice`, md5 `67decb018967…`, Ubuntu `45.2+ds-1`

Both answer `help pss` with `pss [.pss line args] : Do a periodic state analysis.` today.

## The headline

1. ⚠ **On apt 45.2 PSS converges on NOTHING measured** — not on ngspice's own shipped
   `examples/pss/ring_osc_pss_ctrl.cir` with its own arguments, not on any of nineteen
   perturbations. The fork converges on that example in 0.81 s to `3.758894068e9` Hz, the same
   number the scratch build gave. 45.2 answers `Convergence not reached … 3857280067 Hz`, rc **0**,
   both plots full.
2. ⚠ **The Van der Pol example ABORTS on 45.2** — `Timestep too small; … trouble with node "gib"`,
   rc 1, only the TD plot — and converges on the fork in 0.41 s.
3. ⚠ **45.2 writes the verdict, and every progress line, to STDERR.** The fork writes them to
   stdout. `PLAN.md` §14 and APPENDIX §2.12 say *"scrape stdout"*, which finds nothing on 45.2.
4. ⚠ **45.2 ran into the timeout on three inputs the fork answers in under a second** —
   `fguess = 0` (fork: clean rc-1 abort in 0.11 s; 45.2: still running at **60 s**), and
   `sc_iter = 1023` and `1024` (fork: converged at iteration 3 in 0.71 s; 45.2: still running at
   **90 s**). Killed by `timeout` (SIGTERM, no core). "Did not finish", not "hangs forever" — not
   measured further.

## Why — it is upstream, and no release carries the fix

`git log ngspice-45.2..ccebdf2a2` over `src/spicelib/analysis/{dcpss,pssinit,psssetp}.c`:

| commit | date | what | in a release tag? |
|---|---|---|---|
| `8351188e6` | 2025-12-15 | *PSS: new breakpoint deletion, copied from dctran.c: **no more endless loop**. … PSSDEBUG flag added* | **no** |
| `a2a22c0ce` | 2026-04-11 | *Improve PSS error messages* | **no** |
| `668329ca3` | 2026-04-20 | *PSS updates: Remove 1e6 factor … **this will re-enable convergence*** | **no** |
| `4614452f1` | 2026-04-21 | *Info message to stdout, not stderr* | **no** |
| `35b487108` | 2026-04-24 | *Use stderr or stdout adequately* | **no** |
| `5333bf658` | 2026-04-28 | *Use updated eng() to print frequency …* | **no** |

`git tag --contains` is empty for every one of them. `668329ca3` is **not** an ancestor of
`ngspice-46` (2026-03-29) or `ngspice-45.2`; it **is** an ancestor of the fork's `ccebdf2a2` and of
the stock-47 build's `c5cd68015` — but that stock build was a bare `configure` and has no PSS at
all. **So every released ngspice that has PSS — the one Ubuntu ships included — has PSS that does
not converge on its own example**, and the only binary here on which Stage 14's plan is true is a
master-era source build with `--enable-pss`. 45.2's stderr also carries the
`Shooting cycle iteration number: … || rr: … || predsum: …` line that `builds.md` §1.7 said never
prints; on 45.2 it does.

## The table — ring oscillator unless named, `pss 2G 10n bout 1024 10 5 5e-3 uic` varied

Verdicts read from **both** streams. `TD`/`FD` = plots of each kind; `rel` = relaunches.

| case | fork rc | fork verdict (stdout) | fork f0 | 45.2 rc | 45.2 verdict (stderr) | 45.2 f0 |
|---|---|---|---|---|---|---|
| base | 0 | reached | 3.758894068e9 | 0 | **not reached** | 3857280067 |
| Van der Pol, its own args | 0 | reached | 4.590456891e6 | **1** | — `Timestep too small` | — |
| 5 args `2G 10n bout 1024 10` | 1 | — `Panic: breakpoint in the past` | — | 1 | — | — |
| fguess 1G (low) | 0 | reached | 3.758895967e9 | 0 | not reached, rel 1 | 3848823454 |
| fguess 200meg (19× low) | 0 | ⚠ **not reached**, rel 1 (scratch build: reached) | 3.780955744e9 | 0 | not reached, rel 1 | 3848833854 |
| fguess 8G (2.1× high) | **1** | — `Error: Strange behavior` (as the plan says) | — | ⚠ **0** | not reached, both plots | 7999996571 |
| fguess 0 | 1 | — `Timestep too small` | — | ⚠ **124 at 60 s** | — | — |
| stabtime 0 | 0 | reached | 3.780876604e9 | 0 | not reached | 3848459789 |
| points 8 | 0 | reached, rel 1, stderr `Cannot find a minimum…` | 3.758894068e9 | 0 | not reached, rel 1 | 3857280067 |
| points 2 | 0 | reached, rel 1, the same stderr | 3.758894068e9 | 0 | not reached, rel 2 | 7714556828 |
| points 0 | 0 | reached | 3.758894068e9 | 0 | not reached | 3857280067 |
| harmonics 2 (the plan's minimum) | 0 | reached | 3.758894068e9 | 0 | not reached | 3857280067 |
| harmonics 1 | ⚠ **124 at 10 s** (hang, as the plan says) | *reached — printed BEFORE the hang* | — | skipped | — | — |
| harmonics 0 | ⚠ **139** (SIGSEGV, as the plan says) | *reached — printed BEFORE the crash* | — | skipped | — | — |
| sc_iter 5 | 0 | reached | 3.758894068e9 | 0 | not reached | 3857280067 |
| sc_iter 1 | 0 | not reached, rel 1 | 5.404006901e9 | 0 | not reached | 3857280067 |
| sc_iter 0 | 0 | not reached, rel 1 | 5.404006901e9 | 0 | not reached | 3857280617 |
| sc_iter 1023 | 0 | reached (iteration 3) | 3.758894068e9 | ⚠ **124 at 90 s** | — | — |
| sc_iter 1024 (above `HISTORY`) | 0 | reached (iteration 3) | 3.758894068e9 | ⚠ **124 at 90 s** | — | — |
| steady_coeff 1e-6 (the plan's minimum) | ⚠ **124 at 60 s** | — | — | skipped | — | — |
| steady_coeff 1e-9 | 0 | reached, `Panic: breakpoint in the past` — **false**, 4.5 % high (as the plan says) | 3.929556013e9 | 0 | not reached | 3928456360 |
| oscnode `nosuchnode` | 0 | reached | ⚠ **3.741491780e9** | 0 | not reached | 3857280342 |
| no `uic` | 0 | not reached | 3.961679599e9 | 0 | not reached | 7298635694 |
| `eprvcd` after `pss`, mixed deck | 0 | reached; **VCD valid, 158 timestamps** | 3.758893917e9 | skipped | — | — |

Plot literals are identical on both binaries: `Time Domain Periodic Steady State Analysis` and
`Frequency Domain Periodic Steady State Analysis`, typenames `pss1`/`pss2`, `pss3`/`pss4` after a
relaunch.

## What this changes for Stage 14

1. **The verdict scrape reads BOTH streams**, and parses both number spellings (`3.758894068e9` and
   `     3857280067`). It is adapter content by any reading.
2. ⚠ **A "reached" verdict is not an answer until the process has exited cleanly.** `harmonics 1`
   and `0` print `Convergence reached` and **then** hang or segfault. The verdict and rc are both
   necessary.
3. ⚠ **The plan's refusal thresholds are the scratch build's, and two are wrong on the fork**:
   `steady_coeff = 1e-6` is *allowed* by the plan and **did not finish in 60 s**; a `fguess` 19× low
   is called *fine* and **did not converge**. Keep the refusals the fork confirms (`harmonics < 2`,
   `fguess <= 0`, `steady_coeff` far below `5e-3`) and treat the thresholds as a floor measured
   on one binary, not a validated range.
4. ⚠ **`oscnode` steers nothing among REAL nodes** — `bout`, `inv1`, `inv2` give the identical f0,
   and `dcpss.c:126` assigns `oscnNode` and never reads it — **but a name that is not a node moves
   the answer** (3.7415e9 against 3.7589e9, 0.46 %), because the parser inserts a new floating node
   into the circuit. So the form **validates the name against the netlist**; *"ngspice never reads
   it"* is true and is not the whole sentence.
5. **`eprvcd` after `pss` is safe on the fork** (Stage 12's open question, answered for the fork
   only; 45.2 not run, by the rule against crashing the user's simulator).
6. ⚠ **The ruling underneath.** ⚖ **R7** ("ship the PSS panel, explicitly experimental") was
   answered on the scratch build's evidence. On the binary Ubuntu ships, the panel would offer an
   analysis that fails on ngspice's own example **every time**, reporting rc 0 and full plots. The
   capability probe cannot tell the two apart — both answer `help pss` — and this batch does not
   prune a declared capability by probing its behaviour. **Whether R7 still stands on this evidence
   is the user's question**, and Stage 14 should not open until it has been put to them.

## Hygiene

Fork first for every case; 45.2 skipped for the two known crashers, the `evt_after` case, and any
case the fork crashed or hung on. **45.2 was not crashed.** Its three timeouts were SIGTERM'd by
`timeout` with no core. No ngspice process of the driver's survived the run.
