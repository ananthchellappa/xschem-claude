# 1457 — the matrix picker hides the `Cy` family on any run with more than two ports

**Status:** FIXED (2026-09-13, crew receipt 35) · **Filed:** 2026-09-13 by the driver, from a spot-check of issue 1454's evidence
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

---

## RESOLUTION — 2026-09-13, `receipts/35-1457-the-cy-matrix.md`

### Re-measured independently before a line was edited

Six decks, not four: **two, three AND four ports**, flag off and on, counted from the
`Variables:` block of the written rawfile on `/usr/bin/ngspice` (apt 45.2) and on
`/home/analog/dev/ngspice/build-ver_50/src/ngspice`. The two binaries agree on every number.

| ports | flag | S/Y/Z | `Cy` | `NF NFmin Rn SOpt` | matrix total |
|---|---|---|---|---|---|
| 2 | off | 12 | 0 | 0 | **12** |
| 2 | **on** | 12 | **4** | **4** | **20** |
| 3 | off | 27 | 0 | 0 | **27** |
| 3 | **on** | 27 | **9** | 0 | **36** |
| 4 | off | 48 | 0 | 0 | **48** |
| 4 | **on** | 48 | **16** | 0 | **64** |

The **N == 4 row is new** and it is the reason the rule is now *measured* rather than
extrapolated from two points: `Cy` follows the flag at any N, N×N; only the four scalars are
restricted to N == 2.

`i(Cy_3_3)` was re-measured rather than assumed to generalise from N == 2: against the real
three-port variable list of **each** binary, `wviewer::validate_rpn` rejects the bare `Cy_3_3`,
accepts `i(Cy_3_3)`, and rejects `i(Cy_9_9)` as the control.

### What shipped

1. `ase::backend::ngspice::sp_matrix` — `Cy` gated on the **noise flag alone**, emitted N×N; the
   four scalars keep the flag **and** `n == 2`, as **two separate gates** with a comment saying
   why. `sp_vectors` inherits it by construction.
2. `test_ase_sp_1452.tcl` **50 → 58**: SX2 rewritten into SX2/SX2b/SX2c/SX2d/SX2e (one row cannot
   separate the two opposite mistakes), plus **SX2f** and **SE3** (both binaries) — see below.
   SX5 rewritten to ask its flattening at five shapes rather than only at N == 2.
3. `test_ase_dialogs.tcl` **382 → 384** on the display arm: **SP9b/SP9c**, the section's first
   three-port rows.

### Point 4 of "The fix" is answered: NO second caution sentence

The caution names the four scalars and is exactly right, and a family that is **present** needs
no warning. It is now **pinned verbatim** by new row **SN5b** — `SN5` asked only for the
*verdict*, so the clause this issue nearly added could have gone in silently.

### ⚠ But the FIELD LABEL is a live question, and it is the user's

`{Noise figure (2 ports only)}` (`ase.tcl`, the `sp` registry entry's `donoise` field). Measured:
ticking that box is also what summons the N×N `Cy` grid at **any** port count. So on a three-port
bench the label tells the user not to tick the only control that would give them the nine `Cy`
vectors — the same *hiding* this issue is about, one layer up. The label was **not changed**;
filed as `owed.sh add rule 1457`. Options:

* **(a) leave it** — "noise figure" names the four scalars precisely, and the caution already
  explains the N != 2 case when the box is ticked;
* **(b)** `{Noise figure and correlation matrix}` — drops the parenthetical, tells the truth at
  every N, and leans on the caution for the scalars;
* **(c)** `{Noise data (figure needs 2 ports)}`;
* **(d)** make the parenthetical follow the table, so it reads `(2 ports only)` at N == 2 and
  nothing above it — most accurate, and the only option that costs a relabel hook.

### The harder half: how the rows now fail properly

* The **fifth way a row fails to fail** named at the head of this issue — *pinned to a fact
  nobody measured* — is answered by construction: every number in SX2/SX2b/SX2c/SX2d/SX2e and in
  SP9b is a count of a rawfile this crew wrote and read, and **SE3 runs the real thing on both
  binaries** and compares the picker's promise against the file in **both directions**.
* The **surplus** direction is the load-bearing one and it was nearly missed: with `Cy` re-gated
  on N == 2 the *missing* list is empty, so an end-to-end row without a surplus check passes the
  defect. Measured, then fixed.
* **SX2f** is the mirror image nobody had asked about: dropping the emitted noise flag above two
  ports reads like a tidy-up next to the caution, and would leave 36 cells on screen no rawfile
  ever fills. The card and the matrix are now asserted together at every port count.

### And a suite defect this issue's campaign found

A mutation that made `ase::analysis_matrix_of` stop filtering by family had `matrix_dialog` build
`cS_1_1` once per family; `window name "cS_1_1" already exists in parent` came out of
`$cw.matrixbtn invoke` and **thirteen checks (SP7-SP13) stopped running** while the row that
should have gone red never reported. This is the "a read that raises kills the file at rc 0"
shape for the **sixth** time and the third-plus inside section SP. Every picker open, click and
read in section SP now goes through a total reader (`mx_open` / `mx_caps` / `mx_cells` /
`mx_slots` / `mx_title` / `mx_fmts` / `mx_click`). The same mutation now reddens **eight named
rows and loses zero checks**.
