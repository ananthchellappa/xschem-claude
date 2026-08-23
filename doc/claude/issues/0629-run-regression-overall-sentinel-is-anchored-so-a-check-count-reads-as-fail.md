# 0629 — `run_regression.tcl`'s `OVERALL: ok` sentinel is anchored, so a PASSING suite that prints its check count is reported FAIL

STATUS: **OPEN.** Measured 2026-08-22 on branch `annotate` at `4853cbd2` by the
S3 crew's Measure agent, and re-confirmed by the Implement agent. **Pre-existing
and unrelated to op_annot** — filed here because it makes one of T1's three FAIL
lines a lie, and every future crew reading `results.log` will trip on it.

---

## MEASURED

`tests/run_regression.tcl` prints:

```
HARNESS: headless/test_pdk_launcher did not complete cleanly (exit=0, OVERALL_ok=0) … : FAIL
```

while the suite's own log ends:

```
OVERALL: ok (30 checks)
```

with 30 `ok:` lines and zero failures. The suite **passed**; the harness says
FAIL.

## ROOT CAUSE — ONE LINE

`tests/run_regression.tcl:117` tests

```tcl
regexp -line {^OVERALL: ok$} $log
```

The `$` anchor forbids **any** suffix. Dumping the final `OVERALL` line of all 29
suites in one run:

* 26 print a bare `OVERALL: ok`
* `headless/test_ihp_sg13g2_libmgr` prints `OVERALL: 1 FAILED (65 passed)` — a
  genuine red, see below
* `headless/test_pdk_launcher` is the **sole** suite that prints its check count:
  `OVERALL: ok (30 checks)`

So the anchored sentinel converts one suite's extra helpfulness into a false red.

## FIX (either, and the first is smaller)

1. **Widen the sentinel** to `{^OVERALL: ok}`. It must still *not* match
   `OVERALL: 1 FAILED` — it does not, `ok` is not a prefix of `1`.
2. Drop the `(30 checks)` suffix from `test_pdk_launcher`. Loses information for
   no gain.

## THE OTHER PRE-EXISTING RED IN THE SAME RUN, so a later crew does not chase it

`headless/test_ihp_sg13g2_libmgr` fails one check:

```
library_list = exactly the 9 intended libs -> {… sg13g2_tests sg13g2_tests_ase …}
```

`ihp-sg13g2/xschem_libs/sg13g2_tests_ase/` is a **tracked** library (140 files
under `git ls-files`) added by the ASE work; the suite's expected list still
names 9. Pure fixture drift from a sibling feature. It accounts for 2 of T1's 3
FAIL lines (the check plus the HARNESS sentinel); 0629 accounts for the third.

**Neither red is caused by, or affected by, op_annot S3.** Baseline and post-S3
`results.log` carry the same three lines.
