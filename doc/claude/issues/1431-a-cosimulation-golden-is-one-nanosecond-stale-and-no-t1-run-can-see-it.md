# 1431 — a co-simulation golden has been one nanosecond stale, and no T1 run can see it

**Status:** open
**Branch:** fluid-editing
**Found:** 2026-09-12, by the driver of `doc/claude/ase_analyses_batch/` while verifying
Stage 6 task 2. **It is not caused by that work** — see the baseline measurement below.

## The failure

`tests/headless/test_cosim_golden_e2e.tcl`, row **GE24-matches-the-golden**, headless arm:

```
RESULT: 1 FAILED (45 passed)
FAIL: GE24-matches-the-golden (6 difference(s):
  MISSING TOP.counter.next_count 1950011 (golden says 5)
  MISSING TOP.counter.phase      1950011 (golden says 0)
  MISSING TOP.counter.prev       1950011 (golden says 3)
  EXTRA   TOP.counter.next_count 1950012 (= 5)
  EXTRA   TOP.counter.phase      1950012 (= 0) ...)
```

Every difference is the **same three signals at the same values**, one nanosecond later than
the golden records them: **1950011 → 1950012**. Nothing about the values changed; only when
the VCD says they changed.

## It is deterministic, and it is older than the change that found it

Two measurements, both taken with `run_suites.sh --nogui` so each arm carried a timeout and
a named verdict:

| what was measured | result |
|---|---|
| working tree (Stage 6 task 2 applied), **3 runs** | `1 FAILED (45 passed)` **three times**, `1950011`/`1950012` identical every run |
| **`595ab274`** — the commit before the change — in a detached worktree carrying the **same compiled binary** | `1 FAILED (45 passed)`, the **same six differences**, the **same timestamps** |

⚠ **The baseline is the load-bearing half.** The suite calls
`ase::backend::ngspice::render_deck` directly (`test_cosim_golden_e2e.tcl:322`), so the
Stage 6 sidecar work *could* have reached it and "pre-existing" could not be taken on
anyone's word. The worktree was checked out at `595ab274` and the **working tree's own
`src/xschem` copied into it**, because the change is Tcl-only — that isolates `src/ase.tcl`
as the single variable and rules out the stale-binary trap `CLAUDE.md` warns about. The
answer came back identical, so the golden is stale and the change is innocent.

⚠ **It does not flap.** Three consecutive runs gave byte-identical differences, so this is
**not** the same class as issue **1402**'s bandgap non-determinism, and re-running is not a
fix.

## Why nobody noticed

`test_cosim_golden_e2e` is **not in `tests/run_regression.tcl`**. It is one of issue
**1421**'s twenty-one `test_ase_*`-family suites outside T1, and it prints `RESULT:` but no
`OVERALL:`, so T1 cannot count it and no T1 number has ever covered it. **T1 is at zero and
this red is real at the same time** — which is precisely the hole 1421 exists to name.

It also has **no issue file of its own**: `grep -rl GE24 doc/claude/issues/` returned
nothing before this one. `CLAUDE.md`'s rule is that *a standing red is a defect, not
furniture*; this one had become furniture by being invisible rather than by being waved
through.

## What is NOT yet known

Whether the golden or the current behaviour is right. A one-nanosecond shift in a VCD
timestamp is exactly what a changed time base, a changed rounding rule, or a corrected
off-by-one would produce, and this issue deliberately does **not** guess. The suite's own
history is two commits — `c2d775ef` (added) and `9be9c2d5` (*"the six clean auto-merges that
were nonetheless wrong"*), which is itself a reason to look at the merge before assuming the
golden is simply old.

⚠ **Do not re-baseline the golden to make it green.** Promoting a baseline without deciding
which side is correct converts an open question into a silent claim, and this file exists
because the question was invisible for long enough to become furniture once already.

## Related

* **1421** — the harness audit: 21 of 29 suites outside T1, where a red cannot be counted.
* **1402** — the other ASE-family red found in this batch; that one **does** flap, under
  load, and this one does not. They are different defects and the distinction is measured.
* **0990** — why the T1 run that reported zero beside this was taken solo.
