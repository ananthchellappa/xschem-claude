# 1264 — a zero-length vector makes ngspice's `write` refuse the whole plot and produce no raw

**Filed** 2026-09-02 by item **A6**, from the Measure agent's re-measurement of
the simulator half of issue 1259. **A simulator/deck-generator defect, not a
declutter defect. Measured, not fixed.**

## What the batch believed

The A6 brief, quoting `1244_op_param_list_measurements.md` §22 and spec landmine
11 about the zero-length and `dims=0` flavours:

> NEITHER SAYS A WORD ON STDERR.

## What is actually true

**That flavour is loud, and it destroys the results file instead.** Measured
2026-09-02 on `/usr/bin/ngspice` 45.2, a BSIM4 with `.options savecurrents` (so
`ig`/`is`/`ib` are genuinely `0 long`), driven through a `.control` block ending
in `write`:

```
Warning from checkvalid: vector @m1[ib] is not available or has zero length.
Error during 'write': no writable vector found.
```

**No raw file is produced at all** — in `op` and in `tran` alike, the whole plot
is refused, not just the offending column. In one form (`-b` plus a `.control
write`) ngspice **segfaulted**, rc 139.

## Consequences

1. **The zero-length state cannot reach xschem as a zero-length vector.** It
   arrives as *no results at all*. So item A6-b could not have handled it inside
   the raw reader even in principle, and the ACCEPT row's "zero-length does not
   satisfy the gate" is vacuous on this path rather than met.
2. **It is the same class as measurement R5 / landmine 12** — "`save m`,
   `save @m*[*]` and friends do not merely fail, they destroy the plot". This is
   that landmine reached through `savecurrents` rather than through a wildcard
   `save` card, which means an *option line* can do it, not only a card the
   generator wrote.
3. **A generated block must not name a parameter the model does not publish.**
   That is the deck generator's job, and it is where a fix belongs.

## Still open

All of it. Related: issue **1263** (the other flavour, on the `-r` writer, which
is silent in the file and warns on stderr instead).
