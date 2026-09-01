# 0473 — `prepare_netlist_structs()`'s `set_modify(-2)` wipes every `xText` floater cache from INSIDE the SVG and PS renderers

Status: **OPEN, measured, NOT fixed** (S9b worked around it for the annotation
cache only, deliberately, and did not widen the workaround).
Filed by the S9b write-up agent from the Implement agent's instrumentation.

## Measured

S9b's six planned invalidation hooks took `test_op_annot` from 33 FAILED to
2 FAILED. The two survivors — **O32** (`{2}`, expected `{1}`) and **O34**
(`{2 0}`, expected `{1 0}`) — pin a single load-plus-export at exactly **one**
cache flush and were seeing **two**. A temporary field-by-field epoch dump built
into `annot_overlay_sync()` named the culprit exactly:

    dseq=8/7      <- a SECOND data_seq bump arriving DURING the export

The source is `prepare_netlist_structs()`'s `set_modify(-2)` at
`src/netlist.c:1798`, which **`svg_draw()` (`svgdraw.c:1282`) and `create_ps()`
(`psprint.c:1653`) both call AFTER their instance loop**. So a single export
tore down the very per-object caches the export had just filled.

## The part S9b fixed, and the part it did not

S9b bracketed that one line with a depth-counted
`annot_invalidate_hold(1)` / `annot_invalidate_hold(0)` (decision **D11**,
ladder rung L2, `actions.c:1323`, exactly one call site). That covers the
**annotation overlay cache** and nothing else.

**`set_modify(-2)` also frees every `xctx->text[i].floater_ptr`**
(`actions.c:237`). That reset still happens, on both export back ends, on every
export. Nobody asked for it and it is not what `prepare_netlist_structs()` is
for. The open question is whether a **renderer** should be resetting every
floater cache in the document at all — S9b did not widen its hold to cover that,
because widening a suppression is not the same as deciding the reset is wrong.

## Related residual risk on the workaround itself

`annot_invalidate_hold()` **DROPS** a suppressed invalidation rather than
deferring it. That is safe at its single call site (one bracketed line, whose
only Tcl in the window is `catch`-wrapped menu configuration under `has_x`), and
safe by argument (`prepare_netlist_structs()` only does work when the netlist
structs were already invalidated, and every path that invalidates them has
already bumped through HOOK A `clear_drawing()` or HOOK B `set_modify()`).
It is **not** safe as a general primitive: a second call site with real work
inside the bracket would silently strand blocks. A pending-flag design that
replays the bump on release would be strictly safer, and the header comment
should say **"drops"** out loud.

## Rejected alternative, recorded

Loosening O32/O34's goldens from 1 to 2. Rejected: it would have legitimised one
wasted full-cache rebuild per load AND blunted the `annot_overlay_flushes` seam
against any future over-invalidating hook — which is the exact defect class the
seam was added to catch.

## Still open

Yes, for the floater half and for the drop-vs-defer contract.
