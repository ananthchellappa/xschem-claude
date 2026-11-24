# 1734 — A Direct Plot makes an expression trace and a Calculator wave stop drawing

**STAMP:** `v1 claim=fixed tree=6e16cf473 stamped=2026-11-24 fix=taken open=0 by=crew-pdfix`

**FIXED 2026-11-23** on top of the tree above, after the user met it with the difference of
two nets: *"Most serious - after plotting a difference waveform, if one plots a regular
waveform using Ctrl-4, then this recently plotted waveform's strip becomes empty."* What was
built is at the foot of this file; the text between is the report as it was filed, and its
"not fixed" and "Outstanding: 1" are history.

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

## What was built (2026-11-23)

The rules are in `doc/claude/specs/waveform_viewer.md`, "Expression traces and Calculator waves
across a load of results"; the difference's own are R-PD6 of `doc/claude/specs/ase_l.md`.

**The third way, with a narrow form of the second.** After every load that read something,
`wviewer::attach_raw` evaluates every expression trace again from the model
(`wviewer::expr_remake`: each trace's postfix, over every tab), and the load is told to keep the
databases the window's traces draw from that the Calculator made in memory (`ase::attach_dbs`'
last argument; `wviewer::mem_dbs` asks the Calculator which tables it made,
`calc::wave_dest_made`): a Calculator wave's table. `wviewer::restore` now evaluates through
the same proc, which also reaches the tabs that are not shown; it used to walk the shown tab only.
So do undo and redo (`wviewer::state_apply`), for the traces they put back whose vector the data
no longer holds, or holds as a later trace's (below).

**Why not the other two.** Not loading the same data again cannot serve a run, where the data is
new, so the evaluation was needed whatever else was done; and its test of "the same data" is a
file's time and size, blind to a file written again at the same size within the same second.
Keeping every database a load did not read would keep copies of files, which is how an earlier
run stays on screen.

**What a load now leaves.** An expression trace reads the same after a Direct Plot, a second
difference and any other load of the same result, and the new run's numbers after a run. A trace
whose expression names a vector the new result lacks stays in its strip, empty, with one sentence
that names the trace, the vector and what to do; so does one computed on another analysis than
the viewer now shows, which is never drawn from that analysis's columns and draws again when the
viewer shows its own. A Calculator wave stays as the user made it.

That is about a trace no plot removes. Under the destination Replace, the plot that `~` or a
finished run makes loads the results and then empties the target subwindow: the traces there are
not evaluated (`ase::ui::auto_plot` hands the load the strips to leave out), nothing is said of
them, and one `u` in the viewer brings them back, evaluated on the data the viewer then has. The
load of that plot says nothing at all; what is still empty once the rows are in is told of then
(`wviewer::expr_settle`), so a named row plotted again under Append is not called empty a moment
before it draws.

**What the review of 2026-11-24 found, and what was changed for it.**

- *A false sentence under Replace.* The load evaluated, and announced as empty, traces that the
  same press then removed. Now they are left out and the load is quiet, as above. The same
  sentence was false under Append of a named row the press plots again; that is row GG12. Band GG
  of the difference's suite.
- *A database whose file is gone was kept.* The first form of `wviewer::mem_dbs` kept every
  database a trace names whose path is no file on disk. That is a Calculator table, and equally a
  file-read database whose file was deleted: a run deletes the digital results of the run before
  it, and the trace then went on showing them beside the new analog result. What a database is
  now decides, by the Calculator's own list of the tables it made. Rows RK6, RK7, RV1.
- *Undo and redo.* A trace brought back by `u` after a load had no vector until the next load.
  Rows RU1 to RU4, GG2, GG4, GG10.
- *The cure in the sentence.* "Save it in ASE-L and run again" was said of names no run can save:
  a phase column of an AC text read on the transient (a restored AC difference), the vector of
  another expression trace, a name two vectors answer to. Each has its own sentence now
  (`wviewer::expr_lost_why`). Rows RM5 to RM15, GG8, GG9, GYA1.
- *Two traces, one vector.* A load made the vector from the first trace in the strips, where the
  vector had held the expression computed last. Rows RC4, RC5.
- *Parts with no row.* The records dropped at a restore (row GYA4), a Calculator wave in a tab
  that is not shown (row RW5), the analysis recorded at a paste (rows RP1, RP2).

**What the second review found, the same day.** The undo repair evaluated "the vectors the data
lacks", and a vector the data holds can be another trace's. A difference is removed by `~` under
Replace after a run, or deleted before a Direct Plot; the load makes no vector for it, so the
name of its vector is free; the next difference is computed into that name; one `u` brings the
first difference back. Its label then stood over the second one's numbers, with nothing said,
until the next load of results. The pass undo and redo run (`wviewer::expr_remake` with
`absent`) now tells such a vector by the window's record of the postfix it was computed from
last (`wviewer::expr_note`): when that is the postfix of none of the traces the model has for
the vector, the vector is taken out of the data and evaluated from the trace that is there.
Three things follow from the same record, each with its row: a vector the data holds whose
expression names such a vector is evaluated after it; a trace that cannot be evaluated (a net
the result lacks) draws nothing and is told of; and the trace that is back is held to the
analysis its own postfix was computed on, for which the window now keeps the analysis per
postfix as well. Rows RS1 to RS5 (both arms, on the file a real ngspice wrote), RU5 to RU7,
GG14 to GG16. A vector whose record matches is still not computed again (rows RU3, RS1, RS2). With the
analysis kept per postfix, a restored trace of another text than the window's own is told apart
without the records being dropped, so row GYA4, which fences the dropping, now loads a state
over a viewer that computed the same text on another analysis.

**Rows.** `tests/headless/test_wave_expr_reattach_1734.tcl`, on a results file a real ngspice
wrote, with real keys and clicks: a difference, the Calculator's Plot button, the Add Trace door,
an ASE-L Outputs expression row and a Calculator wave, each followed by a real Direct Plot and
read off the readout bar; `ase::attach_dbs`' keeping on the counted arm. The difference's own
bands are GA, GB, GJ, GS, GU, GV, GY, GG and GYA of
`tests/headless/test_ase_plot_difference_1727.tcl`.

**Not built.** The Location bar and Results > Select load another result through
`results::select`; an expression vector lives in the database it was computed in and nothing
evaluates it in the result selected. A Calculator wave is not saved with a state, and one whose
trace was deleted and brought back by undo after a load has nothing to draw. A restored trace of
the transient or the DC sweep is evaluated on whichever analysis the restore shows. The replay
form of a paste (`wviewer::paste_payload`) computes no vector; the next load does. A paste into
the window a trace was copied from computes into the trace's vector name as it stands
(`wviewer::paste_traces` gives a pasted vector a new name only in another window): with the
trace deleted, the results loaded and a later expression computed into that name, the paste
makes the later trace draw the pasted expression under its own label until the next load.
Measured 2026-11-24 on the real results file, a difference copied and deleted, a Direct Plot, a
second difference and a paste: the second difference then read the first one's two nets. The
lines of `wviewer::paste_traces` that compute the vector are as they were before this work, which
added only the record of the analysis after them. Not changed here.
