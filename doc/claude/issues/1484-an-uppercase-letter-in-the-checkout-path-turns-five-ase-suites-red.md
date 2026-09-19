# 1484 — an uppercase letter in the checkout path turns five ASE suites red

**STAMP:** `v1 claim=open tree=7a46275f stamped=2026-09-18 fix=none open=1 by=F-docs`

**Status: OPEN — filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D12, where it is recorded as **a new
stranger finding**. **Class** stranger-facing false red in T1, with a product defect likely
underneath it (INFERRED, see below).

---

## What happens

Clone this repository into a directory whose path contains an uppercase letter, build it,
run T1, and five ASE suites go red. The suites are the same, and fail the same way, in the
old harness and the new one.

* **MEASURED (S2a redirect study, `receipts/S2a.md`):** a variant tree named `cloneB`
  turned five suites red: `test_ase_sp_1452` (row `SE1`), `test_ase_campaign_1462`,
  `test_ase_campaign_gui_1464`, `test_ase_converge_1459` and `test_ase_variant_1470`.
  For `test_ase_sp_1452` the variable was isolated: a tree at `clonB` gave `2 FAILED`,
  and one at `clone2` gave `ALL PASS`. **For the other four, case and path length were
  not separated.**
* **MEASURED (S2c-T, `receipts/S2c-T.md`):** a T1 in a stage directory named `s2c_T`
  carried **26** counted failures. The same code in a lowercase sibling carried **8**,
  which are the DISPLAY-unset segfaults of issue 1483. The difference is **18 counted
  lines, all in the five suites above** (`test_ase_campaign_gui_1464` on both arms), and
  they were identical in the fixed tree and the unfixed base, after pid normalisation.
* **MEASURED (S2c-U, `receipts/S2c-U.md`):** under a scratch root named `s2c_U`,
  `test_ase_converge_1459` `EE5` and `test_ase_sp_1452` `SE1` were red in tree and base
  alike. Both were green under a lowercase root.

Later crews moved their clones to lowercase siblings to get a clean comparison (the S2c
regression refuter's `s2cv2`, the R3 prover's `r3p`). The S2c safety refuter stayed at its
assigned uppercase path and saw the same reds, identical per case in tree and base
(`receipts/S2c_refute_r1.md`, "Per case, tree and base are IDENTICAL").

## Why — INFERRED, not measured

`ase::sp_export_lines` in `src/ase.tcl` writes the S-parameter export into the ngspice
deck as `wrs2p [s2p_file $state $idx]`: a bare, **unquoted** path (READ). The S2a study
inferred that ngspice lowercases an unquoted word on that control line, so the file is
written to a path that does not exist when the directory has capitals, and the suite's
check then finds nothing. **That is inferred from the red/green split, not read in
ngspice's source and not traced.** The mechanism for the other four suites is not
established at all, and it may be a different one.

If the inference holds, **this is a product defect, not only a test one**: a user whose
project lives under `~/Projects/…`, `~/Documents/…`, or a home directory with a capital
in the user name would get an S-parameter export that silently lands nowhere (INFERRED).

## What it is not

* **Not the test home.** The throwaway HOME's `mktemp` suffix is mixed-case about 96% of
  the time. S2a measured 11 ASE-heavy hcases identical under a mixed-case HOME
  (`xschem-test-home.4242.QmZxKe_…`) and a lowercase control, and every later T1 ran
  green under mixed-case throwaways. The "lowercase only" rule is about paths that reach
  an ngspice control line, and the checkout is one of those.
* **Not the git-export reds (1485) or the DISPLAY-unset segfaults (1483).** Those appear
  in lowercase paths too.

## Fix direction

1. Measure it first: run `test_ase_sp_1452` in `…/caseA` and `…/casea` clones, and
   inspect the deck and the directory ngspice actually wrote into. Then quote the
   `wrs2p` argument the way the deck quotes its other paths, if ngspice accepts that.
2. Separate case from length for the other four suites before assuming they share the
   cause.
3. Add a T1-visible row: a two-character uppercase directory in the S-parameter export
   path, which must round-trip.

## Evidence

`doc/claude/outsider_fixes_batch/receipts/S2a.md` (the paragraph beginning "Confound
found and removed"), `receipts/S2c-T.md` (the per-case attribution under the T1 table,
and open problem 6), `receipts/S2c-U.md` (deviation 2).
