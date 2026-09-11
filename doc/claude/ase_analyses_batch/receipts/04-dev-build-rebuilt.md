# Receipt 04 — `build-ver_50` reconfigured with PSS and CIDER

**Date:** 2026-09-10. **Asked for, verbatim:** *"rebuild to get PSS and CIDER"*.

This receipt covers a change to the user's ngspice build, not to ASE-L. It is filed here because
several statements in this batch described that build as lacking PSS and CIDER, and those
statements are now historical. `PLAN.md` §0.14 is the in-plan record; this is the evidence.

## What was done

The original configure arguments were read back from `build-ver_50/config.status --config`
(`--prefix=/home/analog/dev/ngspice/build-ver_50/stage --with-readline=yes`) and reused verbatim
with the two flags added:

```
../configure --prefix=/home/analog/dev/ngspice/build-ver_50/stage --with-readline=yes \
             --enable-pss --enable-cider
make -j8 && make install
```

Configure 10 s, build finished at 75 s, install at 76 s. `make install` matters: the tree has a
live `stage/` holding `spinit` and the code models, and skipping it would leave the binary and its
runtime scripts from different builds. Configure printed `WARNING: PSS analysis enabled` and
`CIDER features enabled`. Same source commit, `ccebdf2a2`; `build-ver_50/` is gitignored.

## Verified, rather than taken from the configure banner

| check | result |
|---|---|
| `config.h` | `#define CIDER 1`, `#define WITH_PSS`, and unchanged `RFSPICE`, `XSPICE`, `OSDI`, `KLU` |
| binary | 8 206 760 → **8 848 296 bytes** (+7.8 %); md5 `eaa99c2238f35e29c70b40ac4c2a2fa1` → `c435f1431e68b471fdf8dfdffe8260ad` |
| version string | **still `ngspice-46+`** |
| `stage/bin/ngspice` | same size, installed 1.5 s after the build; `spinit` reinstalled |
| `help pss` | answers on `src/ngspice` and on `stage/bin/ngspice`; `Sorry, no help for pss.` on the bare-configure upstream build; answers on `/usr/bin/ngspice` |
| `devhelp` | lists `NBJT NBJT2 NUMD NUMD2 NUMOS` |
| PSS, shipped examples | `ring_osc_pss_ctrl.cir` rc 0, 1 008 ms, `Convergence reached … 3.758894068e9 Hz`; `vdp_osc_pss_ctrl.cir` rc 0, 405 ms, `Convergence reached … 4.590456891e6 Hz` |
| CIDER, shipped example | `examples/cider/resistor/sires.cir` rc 0, 107 ms, 101 data rows |

The size cost matches the earlier per-flag measurement (PSS +20 992 bytes, CIDER +628 736 bytes, on
otherwise identical stripped builds): PSS is effectively free, CIDER is the whole cost.

## The regression suite, and the one test the rebuild broke

**First full `make check`: rc 2.** It stopped at the failing directory — `make check`'s recursion
aborts on the first failure — so only 110 of the 128 directories ran. One failure, in
`tests/regression/pipe/`:

```
ERROR: lowercase 'rusage task' printed no simulator stat, line = []
FAIL: resource-keyword-case.cmd
```

Reproduced 2 of 2 in isolation. It was not taken on trust as the rebuild's fault, nor dismissed as
pre-existing; it was attributed.

### Attribution

A **control build** of the same fork source with the **original** arguments (no PSS, no CIDER) was
made at `/home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/builds/baseline-ver50`
(71 s, installed to its own `stage/`; `help pss` → `Sorry, no help for pss.`). With the harness's
own `SPICE_SCRIPTS=tests/bin` so that `spinit` is not a variable:

| build | `rusage task` capture | test |
|---|---|---|
| fork, original arguments (control) | 2 lines | **PASS** |
| fork + PSS only | 2 lines | **PASS** |
| fork + CIDER only | 31 lines, **line 2 blank** | FAIL |
| fork + PSS + CIDER (this rebuild) | 31 lines, **line 2 blank** | FAIL |
| bare-configure upstream | 2 lines | fails earlier, at `EVERYTHING` |
| apt 45.2 (built with CIDER) | 31 lines, line 2 blank | fails earlier, at `EVERYTHING` |

**`--enable-cider` is the cause; PSS is not.** The two stock binaries fail at the uppercase
`EVERYTHING` check because they lack the fork's case-insensitive `rusage` fix, `18a21697a` — which
is the defect the test was written for, so that is correct behaviour. The apt 45.2 capture has the
same shape as the CIDER rebuild's and differs from it only in timing values.

### Mechanism — an upstream divergence, not a fork defect

`printres()` in `src/frontend/resource.c` has two arms for the simulator half of the report:

- **without CIDER**, `task` fetches the whole statistics list with `if_getstat(ckt, NULL)`, but
  because `name` is set it takes the `if (name && v)` branch and prints **only the first
  statistic** — `Nominal temperature`;
- **with CIDER** (`#ifdef CIDER`), `task` sets `paramname = NULL`, which takes the list branch:
  `putc('\n')`, then **every statistic**.

`origin/pre-master-47` has the identical two arms (spelled with `eq`). The fork's commit `18a21697a`
changed only `eq` to `eqc`. So the two builds disagreeing about what `rusage task` prints is
**upstream ngspice behaviour** that predates the fork. The test's header already described `task`
as *"give me everything"* — the CIDER arm's meaning — while its *"the report is then two lines"*
encoded the non-CIDER arm's truncation.

### Repair

`tests/regression/pipe/resource-keyword-case.cmd`, both the lowercase `task` block and the uppercase
`TASK` block:

- the frontend statistic is line 1 in both builds, so it is still read directly;
- the simulator marker is now **scanned for** — `repeat 100` / `fread` / `strstr`, breaking when it
  is found or when `fread` reports end of file. `com_fread()` in `src/frontend/com_fileio.c` sets
  the length variable to `-1` at EOF through `cp_vset(lvar, CP_NUM, &length)`, which is what the loop
  tests;
- the comment block now states the two arms and why the scan exists.

The failure messages are unchanged, so a failing run reads the same as before.

### Repair verified — green on both arms, and not vacuous

| run | CIDER rebuild | no-CIDER control |
|---|---|---|
| `make -C …/tests/regression/pipe check` | **All 33 tests passed** | **All 33 tests passed** |
| sabotage A1 — marker renamed in the lowercase block | rc 1, `lowercase 'rusage task' printed no simulator stat` | same |
| sabotage A2 — marker renamed in the uppercase block only | rc 1, `uppercase TASK not matched for the simulator stats` | same |
| sabotage B — `rusage TASK` → `rusage TASKX` | rc 1, `uppercase TASK not matched for the frontend stats` | same |

A1 and A2 prove each scan reaches end of file and reports failure rather than passing vacuously; B
proves the test still guards the defect it was written for. Sabotage ran on copies in `/tmp`; the
committed test was never edited to fail.

**Full `make check` after the repair: rc 0.** All **128** directories ran — including the 18 the
first run never reached — with **335 `PASS:` lines and 0 `FAIL:`**. One line in the log reads
`ERROR: (internal)  tried to destroy non-existent graph`: it is console output from
`tests/regression/casedist/vector-probe-report.cir`, which **passes**, and the no-CIDER control build
prints the identical line while passing the same test — so it predates this rebuild and is not a
failure.

## What changed

**ngspice** (`/home/analog/dev/ngspice`, uncommitted):

- `CLAUDE.md` — the build-directory sentence said the tree was configured with bare `../configure`;
  it now gives the real configure line and the `make install` reminder.
- `tests/regression/pipe/resource-keyword-case.cmd` — the repair above.

**This batch:** `README.md` (the measured-split paragraph, the dated re-verification note, the
receipts row), `CREW_BRIEF.md` (the preflight PSS paragraph and the `absent` fixture),
`DECISIONS.md` (a dated amendment to D34's reason), `APPENDIX_ngspice_analyses.md` (a dated note
under §1.7 `[A-M7]`), `PLAN.md` (§0.14, the environment table row, §1's ownership paragraph, Stage
15's probe fixture), `LEDGER.md` (a baseline row for the new binary).

**Deliberately not changed:** the dossiers in `evidence/`, whose `help pss` and CIDER-absent
transcripts are left exactly as measured; and `printres()` itself — making both builds print the
same `rusage task` report would change ngspice's output, and upstream's, which is a decision for the
user rather than part of a rebuild. Nothing was committed in either repository.

## Where things are left

- `build-ver_50` has PSS and CIDER, installed.
- The `absent` fixture for Stage 2's grid and Stage 15's probe check is the bare-configure upstream
  build at `workpad/builds/upstream47`.
- The control build at `workpad/builds/baseline-ver50` is kept: it is the only no-PSS, no-CIDER build
  of the fork's own source on the machine.
