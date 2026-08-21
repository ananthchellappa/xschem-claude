# 0480 — a graph that has never been drawn resolves the cursor against a stale or degenerate window

Status: **OPEN. MEASURED before and after S11, DELIBERATELY NOT FIXED.**
Filed by the S11 crew (2026-08-20).
Related: 0477, 0478, 0479, invariant **I3** (`save.c` RULING D5-1 — a plausible
wrong number on a schematic is worse than none), spec §4.7 / step S11.

## What it is

`scheduler.c`'s `set cursor2_x` arm hands the cursor arithmetic the **shared**
`xctx->graph_struct`, which only `setup_graph_data()` (`draw.c`) ever fills —
from `draw_graph()`, whose entire body is inside `if(has_x)`, or from a
`fullyzoom`. A graph rect's own `x1`/`x2` tokens do not necessarily participate
at all, so **the same command answers differently depending on whether, and
when, a frame was painted**, and in a `--nogui` process it can answer from a
window that belongs to a schematic which is no longer loaded.

Same script, same schematic, same `xschem set cursor2_x 3e-9`, 5-point raw whose
point 3 holds `v(d) = 3.0`:

| state | `annot_p` | `v(d)` |
|---|---|---|
| fresh process, nothing ever drawn or zoomed — window `[0,0]` | 0 | **1** |
| `--nogui`, an EARLIER schematic's window still in the shared struct | 2 | 3 |
| under a display, this rect's own window `[0,1e-9]` painted | 1 | 2 |

Row 1 is a plausible wrong number on a schematic, reachable with no user error
at all.

## Measured — BEFORE S11 (Measure agent, verbatim)

    S11BEFORE C1 GRAPH not-zoomed  t=3e-9 : raw annot={0 3e-09 0}  v(d)=1  gm=9.9999997e-05
    S11BEFORE C2 GRAPH fullyzoom'd t=3e-9 : raw annot={2 3e-09 0}  v(d)=3  gm=0.00030000001  text="gm  = 300u | gds ="  flushes=7

## Measured — AFTER S11 (write-up agent, same script, binary `2f41eadd…`)

    S11AFTER  C1 GRAPH not-zoomed  t=3e-9 : raw annot={0 3e-09 0}  v(d)=1  gm=9.9999997e-05
    S11AFTER  C2 GRAPH fullyzoom'd t=3e-9 : raw annot={2 3e-09 0}  v(d)=3  gm=0.00030000001  text="gm  = 300u | gds ="  flushes=7

**Unchanged, on purpose** — the acceptance clause forbids moving graph-present
behaviour.

## Mechanism, and why the zeroed window is *worse* than "no window"

`rescan_no_window()` (`callback.c`, RULING **D4-7**) exists precisely so that a
scan which finds nothing inside the window is redone against the whole sweep.
A `memset`-0 `Graph_ctx` looks like it would land there — and does not. The
degenerate window is `[0,0]`, **every transient raw has a sample at exactly
t = 0**, that sample passes `xx >= start && xx <= end`, so `first` becomes 0
rather than −1, the rescan never fires, the scan exits with `p = first = 0`, and
`interpolate_yval()` then clamps `frac` to 1 and walks one segment forward:
**point 1's value for every t past the second sample**.

## Why this issue is the reason S11's new arm looks the way it does

S11's graphless path could have borrowed the shared struct or zeroed one.
Decision **D2**, ladder rung **L1 / invariant I3**: it carries its **own
stack-local** `Graph_ctx` with an **explicit whole-sweep window**
(`gx1 = -HUGE_VAL`, `gx2 = HUGE_VAL`).

* **Rejected — the memset-0 ctx.** Refuted by measurement, not by argument: the
  S11 implement agent and the S11 sabotage agent independently built exactly
  that variant (SAB-2, "delete the two `HUGE_VAL` lines") and the suite went
  **12 rows red**, with `T2 -> {1} (exp {3})` and `T5 -> {{1 100u} {1 100u} {1
  100u}}` — the wrong number above, shipped.
* **Rejected — `&xctx->graph_struct`.** `save.c`'s `raw_read()` already carries
  the rule and the reason in a comment: the shared struct is live inside
  `draw_graph()`, which calls `raw_read()`. There is also no rect 0 to
  `setup_graph_data()` from on a graphless sheet.
* Row **T4** of `tests/headless/test_op_annot.tcl` is the single row that
  separates a correct local ctx from the zeroed one.

## ⚠ A second window divergence, found by the S11 adversary and untested

A graph **zoomed to a subrange** answers a different number from the graphless
path for the same cursor: with the graph windowed to 0–2 ns, `t = 4.5 ns` gives
`gm = 300u` on the graph path and `gm = 400u` graphless. That is the graph
window's pre-existing semantics, not an S11 divergence — but row **T18** (the
I1 anti-drift row) compares the graphless path only against a **fully zoomed**
graph, so nothing covers it.

## Pinned, so a repair reds a named line

Row **T13** of `tests/headless/test_op_annot.tcl` asserts the **current, wrong**
first row of the table above (never zoomed ⇒ `annot_p 0`, `v(d) 1`).

## Suggested repair, when someone takes it

Fill a **local** `Graph_ctx` from the rect's own `x1`/`x2` tokens (or from the
whole sweep when they are absent) instead of reading the shared struct, in the
`set cursor2_x` arm only — the drawing path keeps its own. That is the same
shape S11's helper already uses, so the two paths would converge rather than
drift, and it must be done together with issue 0477 (whose repair changes *which*
rect the window would have to come from).
