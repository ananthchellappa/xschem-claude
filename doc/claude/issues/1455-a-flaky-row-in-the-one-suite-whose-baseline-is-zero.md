# 1455 — X7 of `test_ase_optier_0963` kills a real ngspice run, and it has now cost T1 twice

**Status:** open — the diagnostic leg has landed; **what ngspice says on the failing run is the next measurement**
**Filed:** 2026-09-13, by the driver of the ASE-L analyses batch, from a solo T1 run
**Area:** tests / sky130 simulation
**Related:** 0970 (the feature X7 measures), 0990 (T1 must run solo), 1377 (the registry sweep
that first saw this row flake), 1456 (the other half of the same T1 read)

## What happens

Row **X7** of `tests/headless/test_ase_optier_0963.tcl` runs a real sky130 bench through
ngspice and reads three answers back out of the results file. Under `tests/run_regression.tcl`
on 2026-09-13 it read:

```
FAIL: X7 issue 0970 the bench now really does simulate what its schematic says: … -> {0 0 0} (exp {1 1 1})
HARNESS: headless/test_ase_optier_0963 did not complete cleanly (exit=1, OVERALL_ok=0, died=0)
Total num fail: 2
```

`{0 0 0}` is the shape of *the run produced nothing*: no raw file, so no vector, so no value.

Re-run standalone minutes later, same tree, same command, nothing else alive:

```
MEASURE X7 rc=0 raw=284381bytes op-vectors=891
MEASURE X7 lvt-vector=v(@m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt[vth]) value=0.47637798
         / standard-vector=v(@m.x1.x3.xm2.msky130_fd_pr__pfet_01v8[vth]) value=0.83716613
RESULT: ALL PASS (108 checks)
OVERALL: ok
```

## It IS intermittent — but it is six times more likely inside T1, and `rc=1` is new information

Measured 2026-09-13, six runs on one unchanged tree, in this order:

| how it was run | X7 |
|---|---|
| `tclsh run_regression.tcl` (solo), run 1 | **FAIL** — `rc=1 raw=-1bytes op-vectors=0` |
| `./src/xschem --nogui --pipe -q --nolog --script …` from the repo root | ALL PASS (108) |
| `tclsh run_regression.tcl` (solo), run 2 | **FAIL** — `rc=1 raw=-1bytes op-vectors=0` |
| `../src/xschem --nogui --pipe -q --script …` from `tests/`, **T1's own command line and cwd** | ALL PASS (108) |
| the same, with row X7d added | ALL PASS (109) |
| `tclsh run_regression.tcl` (solo), run 3 | **ALL PASS** — `rc=0 raw=284381bytes op-vectors=891` |

⚠ **An intermediate draft of this issue said it reproduced under T1 deterministically. Run 3
refutes that and the claim is withdrawn.** What the six runs support is narrower and still worth
having: **2 of 3 inside T1, 0 of 3 outside it**, where the outside runs include one that is byte
for byte the invocation `run_regression.tcl:309` builds — same binary, same flags, same working
directory, no `--nolog`. **The command is not the variable.** Being the 47th case of a long
sequential run is the leading candidate, on three runs' worth of evidence, which is not many.

`rc=1` is the genuinely new fact, and it survives run 3: on the failing runs the simulator **ran
and exited 1**, rather than never starting — which the suite reports as `rc=-1`. Something makes
ngspice itself fail; it is not the harness failing to launch it.

Candidates, none measured yet, in the order they are worth checking:

1. **The capability probe's path is a FIXED name shared by every suite.** `src/ase.tcl:2282` says so
   in its own words — *"the fixed name `<simulation folder>/.ase_probe/probe_a.raw` is shared by"* —
   and X7 is immediately preceded by `o_unprime` + `o_force {}` (row **X5**), which forces a **live**
   probe rather than a cached answer. The case that runs immediately before it in T1's list is
   `test_ase_simcaps_0948`, whose whole subject is capability probes. Two suites racing or colliding
   on one fixed path is the first thing to rule out, and `src/ase.tcl:1129-1132` already catalogues
   the shapes that directory has been found in.
2. **An accumulated temp, lock or leftover under the shared simulation folder** after 46 cases.
3. **A resource the preceding cases have used up** — file descriptors, disk, or a stray simulator
   still holding something.

## Why the suite's own flake note is no longer sufficient

The suite's own header (`test_ase_optier_0963.tcl:104`) already calls X7 a flake, on the strength
of the issue 1377 sweep: one failure under a hostile registry, three clean re-runs under the
same conditions. That note is honest and it is no longer sufficient, for two reasons.

1. **It has now cost T1 twice.** `doc/claude/ase_analyses_batch/LEDGER.md`'s Stage 2 block records
   the first occasion — also two counted lines, also row X7, also `raw=-1bytes`. That one had a
   measured cause: **four ngspice processes belonging to this batch's own recon crews were live
   throughout the run**, which is exactly the condition `CLAUDE.md` names when it says a T1 number
   taken while another agent's suite is live is not evidence.
2. **This occasion had nothing else alive.** The run was solo, the driver launched nothing beside
   it, and the machine was otherwise doing markdown edits. So the standing explanation —
   contention from a concurrent simulator — does not cover it, and the row's flake note now rests
   on nothing measured.

`tests/run_regression.tcl` is the one suite in this tree whose baseline is **ZERO counted
failures**. A row that fails perhaps one run in five puts a permanent smear on the only signal
that would show a real regression, and `CLAUDE.md`'s own paragraph about standing reds — filed
four times by four people and waved through each time — is about precisely this.

## What is NOT known

* **Why the run dies.** ~~Nothing captures ngspice's own stderr for X7's invocation~~ — **fixed in
  this commit**: `x7_diag_lines` prints the newest log under the run directory, last twelve lines,
  **only on the failing path**, so a green run is unchanged. Row **X7d** is its positive control
  (a 30-line fixture, a newer file beside an older one, a directory with no log, and a directory
  that does not exist — the last two answer a sentence rather than raising, because a diagnostic
  that raises would kill the file at rc 0). What ngspice actually says on the failing run is
  therefore the **next** measurement, not a mystery.
* **Whether it is a timeout.** The run is a sky130 bench and is the slowest thing in the suite.
  T1 now wraps every case in `timeout --kill-after=20 $T1_CASE_TIMEOUT` (default 900 s, issue
  1403), and `t1_why` turns rc 124 into a counted `FAIL` that **says `TIMED OUT`** — this one did
  not say that, so it is not T1's cap. An inner cap inside the suite has not been ruled out.
* **Whether load is the trigger at all.** Both observed failures were under T1, which runs 70
  cases back to back; neither was under a standalone run. That is consistent with load and also
  with "T1 is simply where the row is run most often".

## What to do about it — recommendation

**Make the row diagnostic before making it stable.** A flake that prints nothing when it fails
costs a whole run to reproduce and tells you nothing when you do.

* **A — capture and print ngspice's own output on the failing path.** ✅ **DONE in this commit.**
  `x7_diag_lines` reads the newest `*.log` / `*.out` / `*.err` under the run directory and prints
  its last twelve lines under a `MEASURE X7 diag|` prefix, **only when the answer is missing**.
  Costs nothing on a green run. Row **X7d** is the positive control. It was a prerequisite for
  the others and it is why this issue can now ask a specific question.
* **B — give the row its own bounded retry**, one repeat on a no-answer, reporting both attempts.
  Cheap, and it hides the cause. ⚠ **Now much less attractive than when this was thought to be a
  flake**: a failure that reproduces on every T1 run is a condition to find, not noise to average
  out, and a retry that passed would bury it.
* **C — take the row out of T1's arm and leave it in the standalone suite.** Restores T1's zero
  at the price of the only end-to-end check that issue 0970's feature really reaches a simulator.
  Refused unless A and B both fail.
* **D — leave it.** What has been done twice; it is why this file exists.

## What this does NOT change

X7 is a **real** check of a **real** defect (0970 — a per-instance model override that was not
netlisted). Nothing here argues it is a bad row. It is a row that fails silently when the machine
under it does, and that is a property of its instrumentation rather than of its subject.
