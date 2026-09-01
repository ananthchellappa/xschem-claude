# 1231 — The symbol form of get_sch_from_sym reads instance minus one

**Status:** FIXED (2026-08-31, item S7).

`src/scheduler.c`, the `get_sch_from_sym` branch: on the `-1 <symbol>` path `inst`
is left at -1, and the next line is

    if( xctx->inst[inst].ptr >= 0  && sym == -1)

which subscripts `xctx->inst[-1]` before the `sym == -1` test can help. A real
out-of-bounds read on a live path — `hi_descend_enum_views` takes it on every
enumeration. Harmless today only because the value read is discarded.

Behaviourally invisible: an out-of-bounds read does not reliably fault. Row E5 in
`tests/headless/test_descend_doors_1228.tcl` is its only witness.


## What landed

    if(inst >= 0 && xctx->inst[inst].ptr >= 0  && sym == -1)

Row E5 is the only witness and it is structural by construction: an out-of-bounds
read on `xctx->inst[-1].ptr` does not reliably fault, so nothing behavioural can
see it. The row's anchor was also widened to tolerate the `") )" ` spelling this
dispatcher uses in 24 of its branches — at HEAD it matched nothing, so the row was
failing for a reason that had nothing to do with the guard.
