# 0483 — a graphless cursor move while a digital database is current unpublishes `ngspice::ngspice_data`, and `raw switch_back` does not restore it

Status: **OPEN, measured on this tree after S11 (adversary pass, then
independently reproduced by the write-up agent). NOT FIXED — pre-existing in the
raw/backannotate layer; S11 made it reachable without a graph.**
Filed by the S11 crew (2026-08-20).
Related: RULING **D5-3** (a digital database publishes nothing — `save.c`),
`test_backannotate_digital.tcl`, issue 0470, invariant **I3**, spec §4.7.

## Measured (write-up agent, binary `2f41eadd…`)

Flat 1-FET sheet, **no graph object**, a 5-point analog tran raw annotated, then
a small VCD read on top of it:

    S11AFTER  I0 analog annotated      : names=5  v(d)=0  get_voltage(d)=0
    S11AFTER  I1 vcd read (now current): sim_type=vcd  names=5  get_voltage(d)=0
    S11AFTER  I2 GRAPHLESS cursor move : names=0  get_voltage(d)=?  v(d) via raw=
    S11AFTER  I3 switch_back to analog : sim_type=tran  names=0  get_voltage(d)=?  v(d) via raw=0
    S11AFTER  I4 one more cursor move  : names=5  get_voltage(d)=3  v(d) via raw=3

`names` is the size of `::ngspice::ngspice_data`, the array every schematic
voltage text reads through `ngspice::get_voltage`.

* **I2** — one `xschem set cursor2_x` on a sheet with **nothing plotted** now
  reaches the backannotation path, sees the current database is digital, and
  correctly publishes nothing (D5-3). Every voltage text on the sheet flips from
  a number to `?`. Before S11 this command did nothing on a graphless sheet, so
  this state was unreachable without a graph.
* **I3** — `xschem raw switch_back` returns to the analog database and **does
  not republish**. The array stays empty while `xschem raw value v(d) -1`
  answers `0`, so the two annotation surfaces on one sheet disagree: `op_annot`
  device rows (and the S9b overlay) read the raw and show numbers, while
  `lab_pin` / `ipin` / `opin` / probe texts read the array and show `?`.
* **I4** — any subsequent cursor move repairs it.

## Assessment

The unpublish in I2 is correct and ratified (D5-3). The defect is **I3**: a
database switch that changes what is annotatable must republish, or the sheet is
left in a state where two mechanisms that are supposed to agree do not. This is
the same shape as issue 0470 (`raw switch` without a sim type leaves the
outgoing raw's point published) and probably wants the same fix.

## Why S11 did not fix it

Ladder rung **L2** — smallest blast radius. The repair is in the `raw switch` /
`switch_back` arms (`scheduler.c`) and changes behaviour for every caller,
graph or no graph; S11's acceptance clause is that graph-present behaviour does
not move. Recorded here with a reproduction instead.

## Still open

All of it. No row in `test_op_annot.tcl` section T mixes databases (T18 uses one
raw), and `test_backannotate_digital.tcl`'s cursor rows all run **with** a graph,
so nothing in the tree exercises the graphless × digital combination.
