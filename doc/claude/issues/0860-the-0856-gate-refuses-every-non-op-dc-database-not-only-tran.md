# 0860 - the 0856 gate refuses EVERY database that is not op/dc, not only `tran` — a widening the user has not ratified

**Status:** **OPEN — awaiting the user's ruling.** The behaviour LANDED WIDE on
2026-08-27 with the
[0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md)
gate, and is pinned by row `T27` of `tests/headless/test_op_annot.tcl` so it
cannot drift unnoticed. A `rule` debt carrying both questions below is recorded
in `tests/headless/owed.sh`; only the user clears it.

## The gap between the ruling and the code

The user ruled, verbatim, 2026-08-26:

> "if OP is part of the run, then plot from OP. We haven't yet built anything for
> annotating from TRAN results, so it should do nothing silently. Why complicate
> things?"

That sentence is about **TRAN**. The guard that landed in `update_op()`
(`src/save.c`) refuses everything whose `sim_type` is not `op` or `dc` — `tran`,
`ac`, `noise`, `table` and `vcd` alike.

**Measured live** on the landed binary: an ascii **table** database answers
`xschem update_op` -> `0` and puts nothing on the schematic. Pinned by row `T27`
of `tests/headless/test_op_annot.tcl`.

## Why it landed wide

One rule, one answer. Nothing but `op`/`dc` has ever held a meaningful operating
point, and the narrow alternative — `strcmp(sim_type, "tran")` only — leaves
`ac`, `noise` and `table` publishing their point 0 as though it were an operating
point, which is **RULING D5-1**'s exact failure (a number that was not measured
for the thing it is displayed next to). A per-type allow-list would drift.

`T27` exists so this is a VISIBLE decision rather than a silent one: if the user
later rules that tables should publish, that row reds and forces the
conversation.

## Second, smaller, observation: the log line

The gate is silent everywhere the user looks — no CIW line, no status line, no
number on the schematic — but it prints one `dbg(0)` line per call:

```
update_op(): 'tran' is not an operating point database, publishing nothing
```

`dbg(0)` is the uniform level of both neighbouring refusals in the same function,
so it was left alone rather than made a lone `dbg(1)`. A script grepping an
action log WILL see these lines. Not ratified either way.

## Owed

- Does the widening stand, or should it narrow to `tran` only?
- Does the `dbg(0)` log line stand, or demote to `dbg(1)`?
