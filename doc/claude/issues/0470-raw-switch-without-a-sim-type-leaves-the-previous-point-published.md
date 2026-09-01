# 0470 — `xschem raw switch <file>` without a sim type returns success but leaves the OUTGOING raw's point published

Status: **OPEN, measured on the as-built S9b binary, NOT fixed.**
Filed by the S9b write-up agent from the S9b adversary pass (Verify-C).
Pre-existing in the raw layer; S9b paints its consequence on every device at once.

Related: `scheduler.c:10265-10290` (the `raw switch` / `switch_back` arms),
`save.c:1700` (`extra_rawfile()`), `save.c:1988` (`update_op()`),
spec §5 I3, issue 0466 (the same class of stale-number defect, in the cache).

## Measured

Two 1-point OP raws resident via `xschem raw read`. The **3-argument** form
behaves correctly in both directions:

    xschem raw switch <f> op    r1 -> r2 -> r1   renders 10u / 30u / 10u
    switch to a third raw lacking the device's vector  -> renders BLANK   (I3, correct)

The **2-argument** form does not:

    xschem raw switch <file>    ;# no sim type
    -> returns 1 (success)
    -> the render LAGS ONE SWITCH: every consumer still shows the OUTGOING raw

The adversary's first run looked like a break in S9b's cache and was
discriminated: `op_annot::text` and `xschem raw value <vec> -1` returned the
**same** wrong number as the overlay, which proves the C cache was faithful and
the lag lives one layer down, in what the raw layer publishes.

## Mechanism

`update_op()` (`save.c:1988`) is what points `cursor_b_val[]` at the OP point,
and the `raw switch` arm calls it only under

    raw->allpoints == 1 && sim_type in {op, dc}

With no `sim_type` argument that condition is not satisfied the same way, so the
pointer swap happens (`extra_rawfile()`, `save.c:1700`) while the published
point does not move. Every downstream reader — the S9b overlay, `op_annot::text`,
`xschem raw value ... -1`, and the schematic's own `@spice_get_voltage` texts —
then shows the previous raw's numbers.

⚠ **A second, separate smell in the same condition**, worth reading while fixing
this: `scheduler.c:10286` tests the **OLD** `raw` pointer's `->rawfile` /
`->allpoints` against the **NEW** `xctx->raw->sim_type` inside one expression.

## Coverage gap

Row **O37** of `tests/headless/test_op_annot.tcl` (added by S9b) covers the
raw-switch path — but only through the **3-argument** form, which is the one
that works. An O37 sibling row driving the 2-argument form would red today.

## Still open

Yes. Not caused by S9b and not fixed by it. Either make the 2-argument form
publish the new raw's point, or make it fail loudly instead of returning 1.
