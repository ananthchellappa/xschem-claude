# 1413 — T1 was quoted for coverage it did not have

**Status:** fixed
**Branch:** fluid-editing
**Found by:** the Stage 3 recon of `doc/claude/ase_analyses_batch/`, while checking a different
claim — and it is about **this driver's own reporting**, not about the product.

## What was wrong

`tests/run_regression.tcl` — T1, the one suite whose baseline is **zero** — ran exactly **four**
`test_ase_*` suites: `simreg_0931`, `simcaps_0948`, `optier_0963`, `simdlg_0937`. It ran
**`test_ase_core`, `test_ase_dialogs` and `test_ase_persist` on neither arm.**

**Seven commits of Stage 2 were reported as "T1 at zero".** That was true, and it said **nothing
about `test_ase_core`'s 289 checks** — which is where the analysis registry (D8), the Stop warning
(SW), the four-state resolver (AG) and the session-simulator contract (AD) all live. Every one of
those suites *was* run separately for every commit, so the work is verified; **the number was quoted
for more than it covered.**

## Why they could not simply be added

**There are two completion banners in this tree, and only one driver reads both.**

* `tests/headless/run_suites.sh` accepts **either** `RESULT: ALL PASS` **or** `OVERALL: ok`
  (issue 0228).
* `tests/banner_rule.tcl` — the rule `run_regression.tcl` consumes — accepts **only** a whole-line
  `OVERALL: ok` with an optional parenthesised trailer.

A suite printing `RESULT:` alone is scored a **HARNESS failure** by T1 however many of its own
checks passed. Measured: adding the three to `hcases` with no other change produced
`did not complete cleanly (exit=0, OVERALL_ok=0, died=0)` for all three, at `ALL PASS` — **issue
0689's exact shape, which has been filed four times** (0420, 0492, 0629, 0689).

⚠ **The rule was not the thing to change.** `test_ase_simcaps_0948` and `test_ase_optier_0963`
**already print both banners** — which is precisely why *they* are in T1 and the other three are
not. The convention existed; three suites simply never joined it.

## The fix

The three suites emit the second sentinel their siblings already emit, and join `hcases`.

⚠ **They go in `hcases`, not `dcases`.** `test_ase_dialogs` is **37** checks headless against **236**
on a display, and `test_ase_persist` is **44** against **148** — the headless arm of each is a
measurement of a **much smaller thing**, not a weaker measurement of the same one. Issue **1405**
cost 100 checks to that distinction. Putting them on the display arm as well is a bigger change and
wants its own measurement of what it costs in wall-clock here.

## Verification

```
before   cases: 58   all-zero: 58   (test_ase_core absent)
after    cases: 61   all-zero: 61   counted failures: 0
```

`test_ase_core` `Total num fail: 0`, `test_ase_dialogs` `Total num fail: 0`, `test_ase_persist`
`Total num fail: 0` — the three now appear in `results.log` by name.

## What this changes about how T1 may be cited

T1 at zero now covers **61** cases including `test_ase_core`'s 289 checks. It still runs
`test_ase_dialogs` and `test_ase_persist` **headless only**, so it exercises **no** row of dialogs'
sections G14 or GG and **none** of persist's G-block — those are display-arm rows, and a receipt
must say so rather than let a T1 zero imply them.

## Related

* **0689**, 0420, 0492, 0629 — the completion-sentinel false red, filed four times.
* **0228** — why `run_suites.sh` accepts both banners.
* **1405** — the 100 checks lost to treating a headless number as the same measurement.
