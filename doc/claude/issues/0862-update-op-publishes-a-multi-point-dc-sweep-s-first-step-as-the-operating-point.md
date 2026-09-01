# 0862 - `update_op()` publishes a multi-point DC sweep's FIRST STEP as the operating point

**Status:** **OPEN, MEASURED, NOT FIXED.** Filed 2026-08-27 by the write-up pass
of the [0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md)
landing. **Pre-existing** — the 0856 gate did not change the `dc` path — but the
gate's headline claim is *"ONLY AN OPERATING POINT PUBLISHES AN OPERATING
POINT"*, and this is the case where that is not yet true. RULING **D5-1**.

## What the user sees

**Annotate Operating Point** on a bench that ran a `.dc` sweep puts the sweep's
**first step** on the schematic, labelled as the operating point. It is the same
defect shape the user reported for transients in 0856, in a different analysis,
and after the 0856 landing the behaviour is **inconsistent**: a transient is
refused, a DC sweep still publishes.

## The measurement

A genuine 5-point `Plotname: DC transfer characteristic` whose `v(d)` runs
0.25 -> 2.25 over `v-sweep` 0 -> 2.0, measured on the landed binary 2026-08-27:

    5-POINT DC SWEEP: sim_type=dc points=5 annot=0 0 -1 update_op=1
      schematic text = VDNODE=0.25
      ngspice_data(n points) = 1        <-- declares 1 while the database holds 5
      ngspice_data(n vars)   = 2
      ngspice_data(v(d))     = 0.25
      ngspice_data(v-sweep)  = 0

`v(d) = 0.25` at `v-sweep = 0` is a sweep step, not an operating point.

## Root cause

The 0856 guard tests the **type only**, `src/save.c:2239-2240`:

```c
  if(!xctx->raw || !xctx->raw->sim_type ||
     (strcmp(xctx->raw->sim_type, "op") && strcmp(xctx->raw->sim_type, "dc"))) {
```

Both `raw switch` gates it consolidates carry a **third term** —
`src/scheduler.c:10481-10483` and `:10495-10497`:

```c
        /* only update_op() if switching into a 1-point OP or DC */
        if(ret && raw && raw->rawfile && raw->allpoints == 1 &&
           (!strcmp(xctx->raw->sim_type, "op") || !strcmp(xctx->raw->sim_type, "dc"))) {
```

`allpoints == 1` is exactly the term that catches this, and it is the term the
new guard omits. The 0856 comment's sentence *"Both `raw switch` gates already
spell the pair the same way"* is true of the **op/dc pair** and silently omits
it. (That sentence has been corrected in the same commit that files this issue.)

## Why `dc` is accepted at all, and why that does not ask for this

Both justifications in the 0856 comment are **one-point** cases: `read_dataset()`
rewrites a multi-point `Operating Point` to `dc`, and Xyce spells its operating
point as a 1-point DC transfer characteristic. Neither asks for a multi-point
`dc` sweep to publish. Rows `T25` (1-point dc) and `T26` (multi-point OP
rewritten to dc, 3 points) pin the two cases that must keep working; **neither is
a sweep**, and `T26` is why a bare `allpoints == 1` term is not the whole fix.

## The likely shape of the fix

Accept `op` unconditionally; accept `dc` only when the database is a rewritten
operating point rather than a swept one. `T26`'s 3-point `Operating Point` ->
`dc` rewrite means point count alone cannot separate them — the distinguishing
fact is the **sweep variable**: a real `.dc` sweep names `v-sweep` as vector 0
and steps it, while a rewritten OP does not sweep. Measure before choosing.

## Not covered by the sabotage set

`S2` (drop the `dc` term) predicts `T25`/`T26` red, correctly — the `dc` half is
tested only for **acceptance**, never for **over-acceptance**. No variant adds an
`allpoints == 1` term, so nothing in the current sabotage set can discover that
the guard is one term weaker than `scheduler.c:10481`.

## Acceptance if fixed

1. The 5-point sweep above publishes **nothing**; the schematic stays blank.
2. **Positive twin 1.** `T25`'s 1-point `dc` still publishes 8.5.
3. **Positive twin 2.** `T26`'s 3-point `Operating Point` (rewritten to `dc`)
   still publishes 6.5. This is the row that makes the fix non-trivial.
4. `ngspice_data(n points)` never claims 1 for a database holding more.
5. Sabotage: restore the type-only test and confirm row 1 reds.
