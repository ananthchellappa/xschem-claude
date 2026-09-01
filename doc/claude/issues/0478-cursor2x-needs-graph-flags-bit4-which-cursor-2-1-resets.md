# 0478 — cursor-B annotation needs `graph_flags & 4`, whose only setter resets the cursor position

Status: **OPEN. MEASURED before and after S11, DELIBERATELY NOT FIXED.**
Filed by the S11 crew (2026-08-20).
Related: 0477 (the rect-zero gate), 0479, 0480, spec §4.7 / step S11.

## Two measured facts that combine badly

1. `scheduler.c`'s `set cursor2_x` arm annotates only when `xctx->graph_flags &
   4` is set. Bit 4 is a **drawing** flag — "draw x-cursor2" in the
   `graph_flags` table in `xschem.h` — not a data flag. Nothing about
   *computing* an annotation needs a cursor to be painted.
2. Its only setter, `xschem cursor 2 1` (`scheduler.c`), **resets
   `xctx->graph_cursor2_x` to 0.0** as a side effect. So `xschem cursor 2 1`
   must precede `xschem set cursor2_x <t>` in every script, and a caller who
   gets the order wrong silently annotates **t = 0** while believing it asked
   for t.

## Measured — BEFORE S11 (Measure agent, fresh process, verbatim)

    S11BEFORE F1 gate3 (graph_flags&4) off: raw annot={0 0 -1}  v(d)=0  gm=0
    S11BEFORE F2 'cursor 2 1' RESETS x    : graph_flags=4  get cursor2_x=0
    S11BEFORE F3 now it works             : raw annot={2 3e-09 0}  v(d)=3  gm=0.00030000001

F1 is a fully built, node-set, `fullyzoom`'d graph on a sheet with a transient
raw annotated — everything a user would call "plotted" — with cursor B never
enabled. Nothing annotates. F2 shows the reset. F3 is the same command again
after the flag went on.

## Measured — AFTER S11 (write-up agent, same script, binary `2f41eadd…`)

    S11AFTER  F0 graph present, cursor B NEVER enabled: graph_flags=0
    S11AFTER  F1 gate3 (graph_flags&4) off: raw annot={0 0 -1}  v(d)=0  gm=0
    S11AFTER  F2 'cursor 2 1' RESETS x    : graph_flags=4  get cursor2_x=0
    S11AFTER  F3 now it works             : raw annot={2 3e-09 0}  v(d)=3  gm=0.00030000001

**Unchanged, on purpose** — and note the shape this leaves: after S11 a
schematic with **no** graph annotates at any timepoint with one command, while
the same schematic with a graph on it needs `xschem cursor 2 1` first and
silently answers t = 0 if you forget. *A graph makes timepoint annotation harder
to reach than no graph.*

## Consequence for the feature that owns this branch

`utils/annot_mode.tcl` — the `6` / `Ctrl-6` / `Alt-6` bodies — contains no
`xschem cursor` and no `set cursor2_x` at all (re-grepped at S11). The keys load
a raw and set the mask; they never move cursor B. So S11 built the mechanism the
keys would need and the keys still do not use it: after S11 the three keys land
the user on point 0 until something else moves the cursor.

## Why S11 did not fix it

Decision **D5**, ladder rung **L2**: the new graphless arm **neither requires
nor sets** bit 4.

* **Rejected (a)** — require it. The feature's own keys never enable cursor B,
  and the only setter destroys the position being set, so requiring it would
  buy nothing and reproduce this trap on the new path.
* **Rejected (b)** — set it. That turns on a cursor-*drawing* flag for a canvas
  with no graph, and it persists into any graph the user later creates.
* **Not touched** — the graph arm's own requirement, because moving it is a
  user-visible change to graph-present behaviour, which S11's acceptance forbids.

Pinned by row **T15** of `tests/headless/test_op_annot.tcl`, which asserts the
current behaviour (a real graph, cursor B off ⇒ nothing annotates) so a later
repair reds a named line.

## Suggested repair, when someone takes it

Split the flag: keep bit 4 for *drawing* the cursor and gate the annotation on
"a cursor-B position has been set", or make `xschem cursor 2 1` preserve
`graph_cursor2_x` instead of zeroing it (that half is a two-line change and is
the part that actually bites scripts). Both move graph-present behaviour, so
they need their own before/after transcript and their own step.
