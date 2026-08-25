# 0687 — `test_backannotate_digital` drops `untitled~.sch` into its launch dir while reporting ALL PASS, and `test_no_untitled_litter` does not catch a pre-existing one

STATUS: OPEN — measured 2026-08-25 by the 0683+0684 crew (measure pass), reproduced
by the implement and verify passes. Filed, not fixed.
FOUND IN: `tests/headless/test_backannotate_digital.tcl` (suspected producer: the
`xschem clear force` at `:374`) and `tests/headless/test_no_untitled_litter.tcl`.
RELATED: issue 0609 (`test_ase_core` row C11), issue 0601, issue 0673 (the same class
in `test_wave_markers`).

---

## 1. Two defects, one row

**(a) The litter.** `tests/headless/test_backannotate_digital.tcl` leaves
`untitled~.sch` in its current working directory, in **both** `--nogui` and X modes,
while itself printing `RESULT: ALL PASS (81 checks)`. Run from the repo root — which
is how tiers T1 and T3 are invoked — it lands in the repo root.

Consequence, measured: it reds the **next** run of `test_ase_core`:

```
FAIL: C11 no untitled~.sch was dropped in the repo root (issue 0609) -> {1} (exp {0}) : FAIL
```

With the root cleaned, `test_ase_core` in isolation is `ALL PASS (172 checks)`. So a
crew that runs the suites in the wrong order measures a failure in a suite that is
green, caused by a suite that reported itself green.

**(b) The guard does not guard.** `tests/headless/test_no_untitled_litter.tcl` exists
for exactly this and does **not** fire on a pre-existing file: the measure pass
planted an `untitled~.sch` in the repo root and the suite still printed
`RESULT: ALL PASS`. It only notices litter it created itself.

## 2. Why this matters beyond the annoyance

Three tests go red on untracked `untitled*.sch` in the repo root
(`save_as_cellview`, `untitled_reuse`, `descend_untitled_preserve`, plus
`test_ase_core` C11). A suite that both creates that state and passes, next to a
guardian suite that cannot see it, means the failure surfaces one run later in an
unrelated suite — which is precisely how it cost this crew a wasted verify batch.

## 3. Workaround in force until it is fixed

Run `test_backannotate_digital` **last**, or from a scratch cwd, and clean the repo
root before `test_ase_core`. Recorded in the plan's tier notes.

## 4. Still open

Both halves. (a) needs the producer confirmed and the file removed at teardown;
(b) needs `test_no_untitled_litter` to assert the root is clean **on entry** as well
as on exit — and the entry assertion has to be able to fail, which the current shape
cannot.
