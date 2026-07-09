# Tutorial — straightening a same-net U-turn (issue 0089), and why it is NOT the 0088 loop

A companion to `redundant_loop_and_the_scoping_problem_tutorial.md`. 0088 and 0089 look like the same
"the fluid drag left junk copper" complaint, but they are topologically different and need different
tools. Getting the distinction right is the whole point.

## The two shapes

Drag R18 in `before_3.sch`. `#net2` connects C12's bottom pin to R18's M pin.

**0088 — a CYCLE.** Move R18 by (-20,-60): it lands on C12's own column (x=-420). Now two *parallel*
same-net paths join the same two rows — a closed rectangle. A graph cycle. You can DELETE one edge and
every pin stays connected. `fluid_remove_redundant_loops` does exactly that: greedily doom a chord, keep
the doom iff the pin-partition is byte-preserved.

**0089 — a REVERSAL (no cycle).** Move R18 by (-80,-60): it lands on a *different* column (x=-480). Now
there is ONE meandering path (a tree) that bulges out to x=-400 and comes straight back:

```
C12(-420,-170) →down→ (-420,-90) →right→ (-400,-90) →up→ (-400,-140) →left→ (-480,-140) →down→ R18.M
                                   \_______ +20 then all the way back -80: the wasted excursion _______/
```

Nothing here is deletable — it is a simple path; drop any edge and a pin strands. Delete-only is the
WRONG tool. You have to *reshape*.

## Why the reversal forms (it is a correct-but-ugly fallback)

At the X-then-Y decomposition END, leg 0 (the -80 X move) WANTS to corner-slide the R18-M stub, but
declines (0086 `fluid_slide_future_hazard`): sliding it would, *during that intermediate leg*, park
`#net2` copper on R18 pin2's final landing (-480,-70) — a short. The safe fallback is a jog. By the
final geometry both legs are done and the short hazard is gone — but the jog is already committed. So
0089 is inherently a POST-HOC cleanup, exactly like 0088.

## The primitive: slide the jog, then retract the tail

The reversal's middle rung is the vertical `d` at x=-400. Its two neighbours (`C` at y=-90 toward
x=-420, `A` at y=-140 toward x=-480) both leave on the SAME side of x=-400 → that is the reversal
signature. Slide `d` to the NEARER neighbour's far column (x=-420): `C` collapses to zero (dropped),
`A` shortens, `trim` merges the remainder.

But watch the trap that cost an afternoon: sliding `d` to x=-420 makes the C12 riser (which already runs
past y=-140 down to y=-90) OVERSHOOT — its (-420,-90) end is now a dangling tail below the real junction
at (-420,-140). The slide alone does not clean it. So there is a SECOND pass: retract a dangling end
that *was a junction at START* (`fluid_start_deg_at >= 2`) back to its nearest interior junction. Only
then is the result the clean 3-seg L the router wanted.

## Two guards you cannot skip (both cost real debugging)

1. **Scope by SPAN, not span+lab.** The obvious novelty test (`fluid_wire_is_novel`, span+lab) is wrong
   here: adding an isolated user ring on its own net RENUMBERS every other auto `#net`, so a pre-existing
   ring edge reads as "novel" and the straightener happily reshaped it. A span present at START IS the
   same physical wire (trim dedups spans). Use span-only novelty. (`test_wireedit_45` cases G/D.)

2. **`touch()` lies about zero-length segments.** `touch(x,y,x,y, qx,qy)`'s collinear test is trivially
   `0==0` and its axis branch never checks the off-axis coord, so a POINT on row y "touches" every query
   on that row. A label tap left one such point in the START snapshot; `fluid_start_deg_at` counted the
   run's free end as a junction and the pass deleted a legit user wire (`test_wireedit_20`). Skip
   degenerate spans everywhere they meet `touch` — including inside `fluid_loop_partition`, where a
   mid-collapse point would spuriously merge two nets and (safely, but wrongly) revert every good slide.

## The safety net that lets all this be aggressive

Every mutation is applied, then the geometric pin-partition (`fluid_loop_partition`, pure `touch()`,
independent of `node[]`) is compared to the pass-entry BASE. Any change to any pin's class ⇒ revert.
That single check subsumes "no short" (a merge is a partition change) and "no disconnect" (a strand is
too), so the slide/retract logic only has to be *plausible* — the verify makes it *never-worse*. The
one thing the partition verify canNOT see is a net RENAME (same groups, different name), which is why
explicit-labeled and bus copper are declined outright.
