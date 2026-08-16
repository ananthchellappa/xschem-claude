# 0366 — `descend` with an EMPTY selection reuses the stale `sel_array[0]` and descends again

STATUS: OPEN (stub claimed by the D4 Measure agent, 2026-08-10; measured, not fixed)
FOUND BY: item D4 (descend census part 1) while baselining `xschem descend`'s return channel.
RELATED: 0249 (the commented-out `lastsel != 1` guard is the direct cause), 0251.

## Summary

`descend_schematic()` (src/actions.c:3639) calls `rebuild_selected_array()` and then tests only

```c
 if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
```

(src/actions.c:3653-3654). With `xctx->lastsel == 0` the array holds no live entry, so
`sel_array[0]` is whatever the LAST rebuild left there. `descend` therefore accepts an
empty selection, descends into the previously-descended instance, and returns `1`.

A user path reaches this with two keystrokes: descend (`e`), `go_back`, then press `e`
again with nothing selected — `go_back` leaves `lastsel = 0`, and the editor drops a level
anyway. This is the sharp edge of the same defect class as D4: not a refusal that stays
silent, but a refusal that never happens and reports success.

## Measured (binary rebuilt at HEAD ee290c5b, 2026-08-10)

Two DIFFERENT children in the parent proves the stale index is reused, not merely re-derived:

```
STALE 1 instances=2  ()
STALE 2 selected xB : selected_set={{xB}}
STALE 3 descend -> '1'  schname=childB.sch currsch=1
STALE 4 back at parent, lastsel=0 selected_set={} schname=descend_parent.sch
STALE 5 descend with NOTHING selected -> '1'  schname=childB.sch currsch=1
```

A process that has NEVER selected anything refuses correctly, which is why this has not
been caught before — the array is zeroed, so `.type` is not `ELEMENT`:

```
B1a FRESH SESSION, nothing ever selected: lastsel=0 descend -> '0' currsch=0
```

Repro: `/tmp/.../scratch_D4/stale.tcl` (throwaway; recreate from the transcript above).

## Not fixed

Left for the D4 Implement agent or a later item. Any fix must respect risk note 10 of the
D4 scout report: `lastsel` counts inert `INST_PIN` pseudo-selections (instance + its own
pin = 2 while `selected_set` reports one ELEMENT), so the guard must be phrased against the
ELEMENT count, not a bare `lastsel != 1` — reinstating the commented-out test verbatim
would break the accidental-shape cases C4-C6 measured in the same probe.

---

# RESOLUTION — FIXED (item D4, run 2026-08-09, branch open_pdk)

Fixed by the same `descend_pick_target()` callee that closed 0249. Part of the mechanism in
0251's resolution.

## BEFORE (quoted from the stub above)

```
STALE 3 descend -> '1'  schname=childB.sch currsch=1
STALE 4 back at parent, lastsel=0 selected_set={} schname=descend_parent.sch
STALE 5 descend with NOTHING selected -> '1'  schname=childB.sch currsch=1
```

## AFTER

```
R15  descend with NOTHING selected -> ret=0  sch=two_child_parent.sch  moved=0
     descend_error = {no-selection}
```

`descend_pick_target()` counts **ELEMENT** entries over `[0, lastsel)` and never reads
`sel_array[0]` before proving an entry is live — which is precisely this defect. With
`lastsel == 0` the loop body never executes, so the stale index cannot be reached.

The stub's own constraint was honoured: the guard is phrased against the **ELEMENT count**,
not a bare `lastsel != 1`, so the accidental shapes (instance + its own `INST_PIN`) still
descend — see 0249 rows R05/R06.

## Coverage

R15 in `tests/headless/test_descend_refusal_channel_0251.tcl`, with **two different children**
in the fixture so that reusing a stale index lands on the wrong one and is detectable.
Sabotage S5, S5b and S1 all turn it red.

Verify-C additionally failed to break it one level deeper: descending into a child and
immediately pressing `e` again with nothing selected in the child returns `0` /
`no-selection`, and no stale-nonzero `lastsel` could be produced across a load.
