# 1290 — `test_ase_optier_0963` check X7 fails nondeterministically on a simulator launch

**Filed by:** item **B2a-2**, 2026-09-03, from Verify-A's two full audits.
**FILED, NOT FIXED.**

**Status:** open. A **harness/environment** defect, not a code defect — but it
is a standing red waiting to happen, and this branch's rule is that a standing
red is a defect and not furniture.

---

## 1. What was measured

Full audit run **#1** on the (then patched) tree:

```
MEASURE X7 rc=1 raw=-1bytes op-vectors=0   ->  {0 0 0}  (exp {1 1 1})
SUMMARY: 366 pass  13 fail  0 crash/timeout  2 skip  (total 381)
```

Full audit run **#2**, same tree, no change of any kind between them:

```
SUMMARY: 367 pass  12 fail  0 crash/timeout  2 skip  (total 381)
non-PASS diff vs audit_B1_2026-09-03.txt: EMPTY by name and verdict
```

The suite also **passed twice when run alone** through the audit's own arm
(`tests/headless/full_audit.sh test_ase_optier_0963`).

## 2. Why it is a flake and not a regression

Four pieces of evidence, all from Verify-A:

1. **Inside the same failing process**, check `XC`
   (`tests/headless/test_ase_optier_0963.tcl:2586`) issues the *identical* call
   `x_run2 c $X_TRAN 1 {}` and **succeeded** — `rc=0`, a 284381-byte raw — and
   `X1`–`X5` all ran real ngspice simulations green. Same input, opposite
   outcome, one process.
2. It passed twice in isolation on the same tree.
3. A second full audit returned the baseline exactly, diff empty by name and
   verdict.
4. The change under test could not reach that bench: `op_param_lists::apply`
   had **no caller** anywhere in `src/`, so no descriptor ever gained a display
   key and the annotation path was byte-unchanged.

The failure mode is **the simulator exiting 1 and writing no raw at all**
(`raw=-1bytes`, i.e. `ase::wait`'s rc), not any vector name or shape. `ngspice`
itself was healthy at the time (`/usr/bin/ngspice`, a throwaway `.op` deck
returned rc=0) and the box had 13.6 GB free.

## 3. Why it still needs fixing

An intermittently-red check in a 381-suite audit is exactly where a real
regression hides: the next crew that sees `366 pass 13 fail` has to spend an
audit re-running it to learn nothing changed, and the crew after that will be
tempted to wave it through as "the known X7 flake" — which is how this branch
carried three false-red suites for days (see the T1 paragraph in `CLAUDE.md`).

## 4. Where to look

`X7` launches a real ngspice through `ase::wait`. The suspects, in order:
a launch racing a previous run's process or lock; a temp path collided between
concurrent audit legs; or a missing readiness wait before the raw is read. The
diagnostic to add first is **the simulator's own stderr on the failing leg** —
`rc=1` with no captured message is why nothing above is more specific than
"exited 1".

## 5. Acceptance

* 30 consecutive audit runs with X7 green, or a deterministic reproduction and a
  fix.
* On failure the check reports the simulator's stderr, so the next occurrence is
  diagnosable from the transcript alone.
