# 1457 — the matrix picker hides the `Cy` family on any run with more than two ports

**Status:** open · **Filed:** 2026-09-13 by the driver, from a spot-check of issue 1454's evidence
**Area:** ASE-L / `sp` · **Related:** 1452, 1454 (which introduced it), 0964

## The defect

`ase::backend::ngspice::sp_matrix` (`src/ase.tcl:24078`) adds the `Cy_i_j` noise correlation matrix
**only when the noise flag is set AND the port count is exactly 2**:

```tcl
if {[::ase::field_value ngspice sp $row donoise] eq {} || $n != 2} { return $out }
```

Measured on **both** binaries — `/usr/bin/ngspice` (apt 45.2) and
`/home/analog/dev/ngspice/build-ver_50/src/ngspice` — four decks, one per shape, counting the
`Variables:` block of the written rawfile:

| ports | noise flag | S/Y/Z | `Cy` | `NF NFmin Rn SOpt` | total |
|---|---|---|---|---|---|
| 2 | off | 12 | 0 | 0 | 12 |
| 2 | **on** | 12 | **4** | **4** | **20** |
| 3 | off | 27 | 0 | 0 | 27 |
| 3 | **on** | 27 | **9** | 0 | **36** |

**`Cy` follows the noise flag at ANY port count, N×N.** Only the four **scalars** are restricted to
N == 2. So a three-port row with the noise flag on really produces **36** vectors, and ASE-L's
picker offers **27** — nine vectors the run wrote and the user is never shown.

That is the defect class issue 1454's own receipt named in order to avoid it: *"a picker that
silently omitted a family the run produces would be this stage's own defect class, so it is
offered."* It was avoided for the two-port case and reintroduced for every other.

## ⚠ The row that should have caught it asserts the defect instead

`tests/headless/test_ase_sp_1452.tcl` row **SX2** reads:

> *a three-port row's matrix is 27, and the noise families do NOT appear on it even with the flag on*

It is **green and wrong**. Sabotage **s4** of receipt 33 (*"the noise families are offered whatever
the port count"*) reddens it — which means the campaign's own control was pinning the wrong
behaviour, and a mutation that moved the code **towards** correctness was scored as caught.

This is worth stating plainly because the batch's four measured failure modes do not cover it: the
row's fixtures disagree, it has a positive control, and it has a sabotage. It is simply **pinned to
a fact nobody measured** — the claim came from `span.c:74-178` computing the noise *parameters* for
N == 2, which is true of the four scalars and not of the correlation matrix.

## What is NOT wrong

* **The caution sentence is correct.** *"the noise figure is computed for exactly 2 ports and this
  analysis has 3, so NF, NFmin, Rn and SOpt will not be in the results"* names only the four
  scalars, which is exactly right. (A note added to that string in `R9_COPY_REVIEW.md` saying the
  sentence was incomplete because `Cy` is also absent at N ≠ 2 **was wrong** and is corrected.)
* **`Cy`'s plot expression is right.** It is typed `current`, so the rawfile writes `i(Cy_1_1)` and
  `wviewer::validate_rpn` rejects the bare name on both binaries — re-measured here, and it holds at
  N = 3 as well (`i(Cy_3_3)`).
* **The two-port answer is right**, in both the flag-on and flag-off directions.

## The fix

1. In `sp_matrix`, gate `Cy` on the **noise flag alone** and emit it N×N; keep the four scalars
   gated on the flag **and** N == 2.
2. Rewrite **SX2** to assert the measured table above — all four shapes, both binaries' spellings —
   rather than the sentence it pins today. It must redden if `Cy` is dropped at N ≠ 2 **and** if the
   scalars are offered at N ≠ 2.
3. Re-check `sp_vectors`, which is `sp_matrix` flattened and inherits the gap by construction, and
   row **SX5**, which asserts the flattening.
4. Consider whether the caution needs a second sentence for the `Cy` family at N ≠ 2. It probably
   does not: the vectors are **present**, so there is nothing to warn about — which is itself the
   argument for why the picker must offer them.

## How it was found

The driver re-measured issue 1454's own evidence table before appending it to
`evidence/sp-stage9.md`, because the table was a **correction** to that file and a correction is
the last thing to take on trust. The three-port-with-flag shape was not in the crew's table at all;
the crew measured three shapes and the fourth is where the defect lives.
