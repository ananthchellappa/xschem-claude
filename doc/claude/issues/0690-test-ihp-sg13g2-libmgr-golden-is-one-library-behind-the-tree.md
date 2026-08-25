# 0690 — `test_ihp_sg13g2_libmgr`'s 9-library golden is one library behind the tree

STATUS: OPEN — measured 2026-08-25 by the 0683+0684 crew (measure pass), unchanged
before and after that step. Filed, not fixed.
FOUND IN: `tests/headless/test_ihp_sg13g2_libmgr.tcl:68`.

---

## 1. The defect

```
FAIL: library_list = exactly the 9 intended libs
  -> {analyses devices examples ngspice ngspice_verilog_cosim sg13g2_pr sg13g2_stdcells sg13g2_tests sg13g2_tests_ase xschem_simulator}
  (exp {analyses devices examples ngspice ngspice_verilog_cosim sg13g2_pr sg13g2_stdcells sg13g2_tests xschem_simulator}) : FAIL
```

A tenth library directory exists on disk —
`ihp-sg13g2/xschem_libs/sg13g2_tests_ase` — and the suite's golden lists nine. That
is **two of the three FAIL lines in this branch's T1 baseline of record** (the check
itself, plus the HARNESS line it triggers).

## 2. Which side is wrong

Unresolved, and that is the reason this is filed rather than fixed. Either
`sg13g2_tests_ase` is an intended library and the golden is stale, or it is a
by-product of ASE-L work that should not be on the library path. Bumping the golden
to ten would settle the symptom and silence the question — a crew that adds a library
directory by accident would then get a green suite.

## 3. Still open

The ruling on which side is wrong, then the one-line fix on that side. Until then, T1
carries two standing FAIL lines that every crew has to re-derive as benign.
