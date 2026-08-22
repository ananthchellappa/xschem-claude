# 0608 — reading a raw while descended empties `sim_sch_path`, so every device row goes blank

STATUS: **OPEN**, measured 2026-08-22 on branch `annotate`. Ordering-dependent,
recoverable by re-ordering, silent while it happens.
Related: 0499(b) (section X cannot discriminate a basis), 0604 (I8), 0607.

## The measurement

Same file, same raw, same device. Only the ORDER of `descend` and
`raw read` differs.

**Descend first, then read the raw:**

```
simpath BEFORE raw read = 'x1.x1.'      devpath = @m.x1.x1.xm4.msky130_fd_pr__pfet_01v8
simpath AFTER  raw read = ''            devpath = @m.xm4.msky130_fd_pr__pfet_01v8
xschem raw value i(@m.x1.x1.xm4...[id]) -1  ->  4.8543545e-06
xschem raw value i(@m.xm4...[id])       -1  ->  ''
```

The raw holds the deck-absolute name. After the read, `op_annot::devpath` builds
the raw-relative one, which is not in the file, so **every device row on every
instance renders blank** — correctly, per I3, and with nothing said.

**Read the raw at the top, then descend** — the natural flow, and it works:

```
TOP simpath=''      L1 simpath='x1.'      L2 simpath='x1.x1.'
M4 id = 4.8543545e-06   gm = 7.6783977e-06   gds = 9.5339651e-06
   vgs = 1.7988249      vth = 1.0171152      vds = 0.33674577
```

## Reading

`xschem raw read <f> <type>` treats the raw as belonging to the cell on screen
and resets the simulation-hierarchy origin to it. That is defensible on its own
terms — a raw you loaded by hand while looking at cell C plausibly *is* C's.
The problem is that it is indistinguishable, from the user's side, from the
case where the raw is the top's: same command, same success, and the only
symptom is annotation that is uniformly empty.

Note this is exactly the basis distinction issue 0499(b) says the S3 acceptance
**cannot see**: "section X clears the raw, loads the top cell, and calls
`save_cards` at currsch 0 — where the `read` and `deck` bases produce the same
empty prefix." At currsch 0 the two spellings coincide. Here, at currsch 2, they
differ and the read basis is the wrong one. This is the concrete case that
section was missing.

## Directions, none taken

1. **A seam, not a fix.** When a `raw read` lands while `currsch > 0`, say so
   once: the raw is being treated as this cell's, and device names will be
   relative to here. Cheapest, and matches I8's spirit.
2. **Rebase on descend.** Recompute the origin from the raw's own top when one
   can be identified, so order stops mattering.
3. **Leave it, document it.** The Simulation-menu flow always reads at the top,
   so a user following the stock path never meets this; only a script or a
   hand-loaded raw does.

Whichever is chosen, `test_op_annot` should gain a row that reads a raw at
currsch 2 and asserts the device value resolves — the suite has never done it,
which is why 0499(b) called this end uncovered.
