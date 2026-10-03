# 1637 — `xschem raw pos_at` answers −1 or a wrong index on a non-monotonic column, and the readout bar asks it about column 0 whatever the trace's own sweep is

**STAMP:** `v1 claim=open tree=a90ffb98 stamped=2026-10-02 fix=none open=3`

Status: **OPEN**, found 2026-10-02 by the calculator batch's recon stages while establishing which
accessor a scratch column may be read back through. Pre-existing; no Calculator change caused it.

Area: `raw_get_pos()` — `src/save.c` — behind the `pos_at` arm of the `raw` dispatcher in
`xschem_cmds_r()`; and its shipped Tcl caller `wviewer::interp_value` — `src/wave_viewer.tcl`.
The C-side in-graph measurement is `show_node_measures()` fed by `measure_p`, both in `src/draw.c`.
Found: `env -u DISPLAY ./src/xschem --pipe -q --nogui --script …` against
`tests/headless/data/calc_fixture.raw`, with a seeded scratch column and a control on `time`

## Part 1 — the search is a bisection and a non-monotonic column defeats it

`raw_get_pos()` seeds a single search direction from the two **window endpoints**
(`sign = (vend > vstart) ? 1 : -1`), refuses anything not between them in that direction, and then
halves. Issue **1631** files the help text's "first crossing" claim and characterises the
monotone-column assumption exhaustively on `v(sq)`. **This issue is the other half: what happens to
a caller holding a column that ascends and then drops**, which is the ordinary shape of a scratch
column whose head carries results and whose tail is still `raw_add_vector()`'s zero fill.

Reproduced by taking the five crossing times `calc::cross {v(sq)} 0.5 0 either 0` answers, seeding
them into a fresh column through `xschem raw set`, and leaving the remaining 96 points at the zero
fill:

```
calcx head = 0.0009999999999999998 0.002200000000000001 0.005 0.006199999999999998 0.008999999999999998 0 0 0 0 0
calcx tail = 0 0 0 0

pos_at calcx 0.0009999999999999998  -> 4     (the value is at index 0)
pos_at calcx 0.0022000000000000006  -> -1
pos_at calcx 0.005                  -> -1    (the value is at index 2)
pos_at calcx 0.006199999999999998   -> -1    (the value is at index 3)
pos_at calcx 0.008999999999999998   -> -1    (the value is at index 4)

control, the same five values on the monotone sweep column:
pos_at time 0.0009999999999999998 -> 9
pos_at time 0.0022000000000000006 -> 22
pos_at time 0.005                 -> 50
pos_at time 0.006199999999999998  -> 61
pos_at time 0.008999999999999998  -> 89
```

**Both failure modes in one column.** The mechanism is readable from the code: `vstart` is
`calcx[0] = 0.000999…` and `vend` is `calcx[100] = 0`, so `sign` comes out **−1** and the admitted
band is `[0, 0.000999…]` — every later crossing time is *larger* than the first and therefore
refused. The one value that is admitted is the first, because it equals `vstart`, and the bisection
then walks the zero tail and lands on index 4.

The wrong-index half is the one worth noting, because issue 1631's measurement over 5151 windows of
`v(sq)` found **0 non-bracketing answers** and concluded *"the failure mode is a false negative,
not a wrong index"*. That conclusion is correct for `v(sq)` and **does not generalise**: a column
with a flat tail produces a confident wrong index, and a caller that only tests `pos < 0` will not
see it. The number 4 is a property of this column's length and crossing count, not a constant —
a column with eight seeded values answers 7 by the same walk.

## Part 2 — `wviewer::interp_value` asks about column 0, not the trace's own sweep

The shipped caller's first three lines are the defect:

```tcl
proc wviewer::interp_value {var x} {
  set names [split [xschem raw list] "\n"]
  set sweep [lindex $names 0]
  set n [xschem raw points]
  …
  set pos [xschem raw pos_at $sweep $x]
```

`[lindex $names 0]` is **column 0 of the database**, unconditionally. On a transient that is
`time` and the readout is right. A trace plotted against **its own X column** — which is what the
Calculator's Plot path and `wviewer::add_trace`'s sweep argument both produce — gets a cursor
readout computed by locating `x` in `time` and then reading `$var` at that index. The interpolation
that follows (`$xa`, `$xb` from `$sweep`) compounds it.

Part 1 and Part 2 interact: the column a trace is plotted against is exactly the kind of column
Part 1 mishandles, and `interp_value` cannot even reach it.

## ⚠ The C-side in-graph measurement does NOT have this defect, and that asymmetry is the finding

`src/draw.c` resolves the per-trace sweep correctly and does not use `pos_at` at all. The trace
loop reads `register SPICE_DATA *gv = xctx->raw->values[sweep_idx]` — the trace's **own** sweep
index — and finds the cursor point by a linear scan for a sign change:

```c
if(XSIGN(xx - curs1) != XSIGN(prev_x - curs1)) {
  measure_p = p;
  measure_x = xx;
  measure_prev_x = prev_x;
}
```

That takes the first crossing of the cursor in sweep order, needs no monotonicity assumption and no
endpoint guard, and is per-trace by construction. So **the graph and the readout bar disagree about
both questions** — which column the cursor is located in, and how. Only the Tcl readout is wrong.

## Open items

1. **`interp_value` must take the trace's own sweep.** The trace dict already carries what is
   needed — the proc immediately below it switches databases by `rawfile`/`sim_type` from the same
   dict for exactly this class of reason — so the sweep name can be passed in rather than guessed.
   This is the item with the user-visible value in it, and it is independent of items 2 and 3.
2. **`pos_at` should refuse a column it cannot search, rather than answering an index.** Issue
   1631's item 1 asks for the help text to state the monotone assumption; this asks for the code to
   notice. A cheap and honest form is to verify the admitted band's endpoints bracket the value
   *and* that the returned pair actually brackets it, and answer −1 otherwise — which turns the
   wrong-index half into the false-negative half that callers already handle.
3. **A fence is owed on both halves and none exists.** The row to write for Part 1 seeds a column
   with a known ascending head and a zero tail and asserts `pos_at` against hand-computed indices,
   with the monotone sweep column as the control in the same run — the control matters, because
   without it a reader cannot tell a `pos_at` defect from a fixture defect. For Part 2 the row
   plots a trace against a non-`time` X column and compares the readout against the sample.

## What this is NOT

Not a duplicate of issue 1631, which files the *help text's* "first crossing" promise and the
monotone assumption, measured on `v(sq)`. That file's own conclusion — false negatives only, no
wrong indices — is what Part 1 refutes for a different column shape, and the two should be read
together.

Not a duplicate of issue 1630, which is `interp_value` reporting **another dataset's** value at and
past the end of the sweep. That is the dataset axis; this is the column axis. Both reach the same
proc and a fix for either leaves the other live.

Not reachable through the C annotation path: `backannot_pos_at` and the Location bar pass the sweep
variable, which is monotone, exactly as issue 1631 measured.
