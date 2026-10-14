# 1660 — two operating-point rows the R-OUT11 sweep could not convert: `test_mos_binning`'s stale `i(curr)` refuses the whole bench, and the Calculator reads no `vdc(a,b)`

**STAMP:** `v1 claim=open tree=fc562525 stamped=2026-10-13 fix=none open=2`

Both were met by `tools/migrate/op_measures.tcl` (ase_l.md R-OUT11) and both predate it. Each
row is recorded with its reason in `tests/headless/data/op_measures.txt`, and band OM7 of
`tests/headless/test_ase_op_measures.tcl` re-measures the second reason every run, so it reds
("convert them") the day it stops holding.

## 1. `test_mos_binning` is refused before it runs

`sky130A/xschem_libs/sky130_tests_ase/test_mos_binning` is an op-only test bench (no port
pins). Its Outputs hold `i(vd2)` and `i(curr)`. The circuit has no `curr`, so ASE-L's pre-flight
refuses the run: *"ase: REFUSED — 1 output expression names something this circuit does not
have"*. So the bench shows nothing at all, and `i(vd2)` — the row R-OUT11 would make
`idc(vd2)` — cannot be measured. With the stale row removed by hand the bench runs and `i(vd2)`
reads a real operating-point current (measured once, 2026-10-13, registry ngspice).

Open question for whoever fixes it: is the right repair to drop or correct the stale committed
row (data), or for the pre-flight to refuse only the offending row rather than the whole run
(product)? Neither is done.

## 2. The Calculator reads no `vdc(a,b)`

`sky130A/xschem_libs/sky130_tests_ase/montecarlo_mismatch_sim`'s op-only row `v(vm,vcm)` is a
two-node save. Its operating-point measure would be `vdc(vm,vcm)`, but `calc::eval_text`
does not accept the two-node form, so the row would show a refusal instead of a number and it
stays a save. A one-node `vdc(x)` reads fine on the same bench.
