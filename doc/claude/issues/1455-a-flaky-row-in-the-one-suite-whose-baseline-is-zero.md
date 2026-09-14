# 1455 — X7 of `test_ase_optier_0963` kills a real ngspice run, and it has now cost T1 twice

**Status:** open
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

## Why this is being filed now rather than left as a known flake

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

* **Why the run dies.** Nothing captures ngspice's own stderr for X7's invocation; the row prints
  `rc` and the rawfile's size and stops. `rc=-1`/`raw=-1bytes` is the suite's own "no answer"
  sentinel, not a code ngspice returned.
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

* **A — capture and print ngspice's own output on the failing path.** X7 already builds a run
  directory; keep the log and, when `rc` is not 0 or the rawfile is missing, print its last ten
  lines under a `MEASURE X7` prefix. Costs nothing on a green run, and the next failure explains
  itself. **Recommended, and it is a prerequisite for the others.**
* **B — give the row its own bounded retry**, one repeat on a no-answer, reporting both attempts.
  Cheap, and it hides the cause; only worth doing *after* A has recorded what the cause is.
* **C — take the row out of T1's arm and leave it in the standalone suite.** Restores T1's zero
  at the price of the only end-to-end check that issue 0970's feature really reaches a simulator.
  Refused unless A and B both fail.
* **D — leave it.** What has been done twice; it is why this file exists.

## What this does NOT change

X7 is a **real** check of a **real** defect (0970 — a per-instance model override that was not
netlisted). Nothing here argues it is a bad row. It is a row that fails silently when the machine
under it does, and that is a property of its instrumentation rather than of its subject.
