# 1402 — the shipped bandgap bench does not converge reproducibly, so `test_ase_optier_0963` X7 flaps

**Filed so it stops being furniture**, in the shape of issue 1399. Row **X7** of
`tests/headless/test_ase_optier_0963.tcl` has been called a flake in that suite's own header
since the 1377 sweep. It is a flake. **But the flake is not in the assertion — it is in the
simulation**, and the row has been telling the truth the whole time.

## The measurement, 2026-09-11

Three consecutive runs of the suite, alone, `--nogui`, **identical code, identical scratch
`HOME`, identical binary**:

```
run 1:  RESULT: 1 FAILED (102 passed)      X7 red
run 2:  RESULT: ALL PASS (103 checks)
run 3:  RESULT: ALL PASS (103 checks)
```

Plus one red in a preceding family run and one green inside `run_regression.tcl`. **Roughly
one red in three.** Intermittency under fixed conditions is what a flake is — and it is why
the change under verification at the time (issue 1401) was exonerated by measurement rather
than by argument.

## What the row actually reported, and it is not an assertion problem

X7 prints its own measurements before it checks anything. Side by side:

```
red    MEASURE X7 rc=1 raw=-1bytes op-vectors=0
       MEASURE X7 lvt-vector= value=ZZNONE / standard-vector= value=ZZNONE

green  MEASURE X7 rc=0 raw=284381bytes op-vectors=891
       MEASURE X7 lvt-vector=v(@m.x1.x5.xm2.msky130_fd_pr__pfet_01v8_lvt[vth]) value=0.42189628
              / standard-vector=v(@m.x1.x3.xm2.msky130_fd_pr__pfet_01v8[vth]) value=0.8658252
```

**`rc=1`, `raw=-1bytes`, `op-vectors=0`.** The simulator exited non-zero and wrote no results
file at all, so there were no vectors to read, so both lookups came back `ZZNONE` and the row
reported `{0 0 0}` where it wanted `{1 1 1}`. The check is honest: it says *"the low-threshold
device is not in the results file"*, and it was not, because **there was no results file**.

⚠ **This is not a setup or environment failure.** The same process ran the same bench
successfully three times immediately before, in the same session, on the same scratch tree:

```
MEASURE X bench form=c    rc=0 deck=36493bytes/363lines wall=11617ms raw=284381bytes
MEASURE X bench form=b    rc=0 deck=18839bytes/362lines wall=11380ms raw=706223bytes
MEASURE X bench tick-off  rc=0 raw=252407bytes
```

Three good runs, then X7's own fourth run of the same circuit fails. Run-to-run, not
configuration.

## The second finding, which is the more interesting one

**Even when it succeeds, the answer moves.** Across the two green runs:

| vector | run 2 | run 3 | spread |
|---|---|---|---|
| `…pfet_01v8_lvt[vth]` (the low-threshold passgate) | **0.42189628** | **0.485901** | **~15 %** |
| `…pfet_01v8[vth]` (the ordinary passgate) | 0.8658252 | 0.86520977 | 0.07 % |

A DC operating point is supposed to be a deterministic answer to a deterministic question.
One device's threshold voltage moving 15 % between identical runs while its neighbour holds to
four significant figures says the solver is **landing in different places on different runs** —
which is exactly the signature of a bias point with more than one solution, and a bandgap
reference is the textbook circuit that has one. An occasional outright convergence failure
(`rc=1`, no rawfile) is the same phenomenon with the dice rolled once more.

⚠ **So the blast radius is wider than one test row.** Any number read off this bench's
low-threshold passgates — in a suite, in a receipt, in a screenshot pasted into a write-up —
is reproducible only by luck. That includes measurements taken to *prove* something else.

## What this supersedes

The suite header's own account, written during the 1377 sweep:

> *"That single failure DID NOT REPRODUCE: the unisolated file was re-run three more times
> under the same hostile registry and read ALL PASS (102) every time, so X7 is a FLAKE and
> this suite is NOT one of the eleven the sweep convicted."*

Both halves stand, and the first is now **too weak**: it *does* reproduce, at about one in
three, and three clean runs is simply the likeliest outcome of three trials at that rate
(~30 %). The conclusion the sweep drew — that the registry was not steering it — is
unaffected and is confirmed here, since these runs were on an isolated registry too.

## Why it matters even though "it is only a flake"

A row that flaps carries **no information in either direction**. It cannot confirm the
behaviour it was written for (issue 0970 — that the two overriding passgates are really
simulated as the device their schematic names) and it cannot refute a regression in it, which
means 0970's only device-level guard is unreliable. A header comment naming it is a note, not
a fix, and the tree has a standing rule about exactly this: *a standing red is a defect, not
furniture*.

## What is owed

1. **Capture the failing run's simulator log.** X7 discards it — it reads `rc` and the
   rawfile and nothing else. One `catch`-and-keep of the run log on the failing path names the
   cause in one red run: a convergence message, a `$sim_status` guard firing, or something
   else entirely.
2. **Then decide whether the bench needs a deterministic start**: a `.nodeset` or `.ic` for the
   bandgap's start-up node, or `wrnodev` + `.include` to pin a converged solution. Both are
   surfaces `doc/claude/ase_analyses_batch/PLAN.md` Stage 3d and Stage 10c already design, and
   this issue is a concrete customer for them — the plan's convergence story is not
   hypothetical, it is this bench.
3. **Until then, X7 must not be silently unreliable.** Either it retries and reports the retry
   count, or it declares itself a non-deterministic measurement. What it may not keep doing is
   producing a red that every reader learns to wave through, because that is how a real
   regression hides.
4. **Re-measure the rate.** One-in-three is five observations, not a rate. A twenty-run soak
   with the `MEASURE X7` lines kept is cheap and settles it.

## Not related to issue 1401

The change being verified when this surfaced touches the deck-render emit loop, the preflight
gate and one new reader. `test_ase_optier_0963` reads **`ALL PASS (103)` with 1401 in the
tree**, three runs out of three headless, and the rows 1401 could plausibly disturb — E5, M1,
R2, R4, R6, E17 — are all green on both arms. A code defect is deterministic; this is not.

## Not the same as issue 1375

That suite also **hangs for ever on the display arm**, which is a different defect with a
different root cause — `descend_schematic()`'s `ask_save` modal, gated on `has_x` alone,
raised under `--script` where nothing can click it. It is already filed as **1375**, the
suite's own header says so, and this issue does not restate it.
