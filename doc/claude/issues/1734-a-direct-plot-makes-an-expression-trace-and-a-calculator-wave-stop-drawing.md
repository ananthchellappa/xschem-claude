# 1734 — A Direct Plot makes an expression trace and a Calculator wave stop drawing

**STAMP:** `v1 claim=open tree=e0c68fc79 stamped=2026-11-22 fix=none open=1 by=crew-zoomkeep`

Found while measuring issue 1733 (2026-11-22), as the brief asked: *does a Direct Plot make an
existing expression trace or Calculator wave stop drawing?* It does. Measured on a private Xvfb with
a probe that drives the real doors; not fixed. The readings are the same with the `wviewer::attach_raw`
from before issue 1733 (the same code as `e0c68fc79`'s, with the same `ase::ui::dp_finish` and
`ase::attach_dbs`) and with issue 1733's, so it is older than 1733 and not caused by it.

## What happens

A session on the bundled `test_nfet_final` raw (`tests/headless/data/probe_1724_tran.raw`), its
viewer open in single-plot. Before the Direct Plot:

- strip 0 holds `v(out)` and an expression trace `ex2` = `v(out) 2 *`, added through
  `wviewer::add_trace` (Graph > add expression's door). `xschem raw index ex2` answers 9, and its
  readout at 3 ns is 3.3168317 (`v(out)` reads 1.6584158);
- strip 1 holds a Calculator wave, made by the real `calc::wave_dest` and `calc::wave_in_token`: the
  table database `__calc_dest1`, trace `cy`, readout 2.5. `xschem raw info` lists slot 0 (the raw)
  and slot 1 (`__calc_dest1 table`).

Then `ase::ui::dp_finish <key> {i(v1)}` (a real Direct Plot of one signal). After it:

- `xschem raw index ex2` answers -1, and `ex2`'s readout is empty: the vector is gone;
- `__calc_dest1` is gone from `xschem raw info` (only slot 0 is left), and `cy`'s readout is empty;
- both traces are still in the model and on their strips, so the strips show a legend entry with
  nothing drawn; `xschem redraw` returns without an error;
- `i(v1)` landed in the Calculator wave's strip (the target strip), beside the dead `cy`.

## Why

`ase::ui::dp_finish` always calls `wviewer::attach_raw`, which calls `ase::attach_dbs`. That reads
the run's raw again and drops every database slot other than the one it just read. An expression
trace is a vector `xschem raw add` put into the old slot, and a Calculator wave is a database slot of
its own, so both go. Nothing re-creates them: the expression is not re-evaluated on the new slot, and
the Calculator's table is not re-registered.

## What a fix has to decide (not built)

Whether a Direct Plot of the same data should re-attach at all (issue 1733's R1 already knows when
the data is the same), or whether `ase::attach_dbs` should keep the slots it did not read, or
whether the viewer should re-evaluate expression traces and re-register Calculator tables after
every attach. Each needs a display-arm row that reads the readout of an expression trace and of a
Calculator wave after a real `dp_finish`, and a sabotage per arm. Outstanding: 1.
