# 0089 — fluid reroute leaves a redundant same-net U-turn (detour) after a far move

Status: FIXED (headless + X-gesture verified; wireedit 46/46, valgrind clean)
Related: [0086](0086-*.md) (transient-short corner-slide decline), [0088](0088-fluid-reroute-redundant-samenet-loop.md) (redundant same-net **cycle** collapse — the sibling this extends).

## Symptom

`tests/from_user/before_3.sch`, grab **R18** and drag it by **(-80, -60)** (from (-400,-40) to
(-480,-100)). Saved result = `tests/from_user/after_9.sch`. Net `#net2` (C12 bottom pin ↔ R18 M pin)
comes out as a **5-segment staircase that doubles back**:

```
C12 pin (-420,-170) --riser--> (-420,-90) --> (-400,-90)   [w: -420,-90  -400,-90 ]   right  +20
                                              (-400,-90) --> (-400,-140) [ -400,-90  -400,-140 ] UP  (reversal)
                                              (-480,-140) <-- (-400,-140) [ -480,-140 -400,-140 ] left -80
                                              (-480,-140) --> (-480,-130) = R18 M pin
```

The route rings out to column **x = -400** and comes straight back left — the excursion right of
x = -420 is pure waste. Both pins sit left of -400 (C12 at -420, R18 at -480), so the minimal route is
a clean 3-segment L via y = -140.

## Why 0088 did not catch it

0088's `fluid_remove_redundant_loops` is **delete-only**: it removes a redundant **cycle** (a chord
whose removal keeps every pin connected). Here `#net2` is a **tree** (a simple path, no cycle) — nothing
is deletable without disconnecting a pin. The (-20,-60) 0088 case DID form a cycle because R18 landed on
C12's own column (x=-420); at (-80,-60) R18 lands on a *different* column (-480), so the two rows are
joined by a single meandering path, not two parallel paths. Different topology ⇒ needs a different tool.

## Root cause (why the detour forms)

At the END X-then-Y decomposition (0081), leg 0 (the -80 X move) tries a corner-slide of the R18-M stub
but **declines** it (0086 `fluid_slide_future_hazard`): sliding the corner would park `#net2` copper on
R18 **pin2**'s FINAL landing (-480,-70) — a transient short during the intermediate leg. The safe
fallback is a jog. At the *final* geometry (both legs done) the short hazard is gone and the clean L is
safe — but the incremental process already committed the jog. This is a **post-hoc cleanup** problem.

## Fix — `fluid_straighten_reversals()` (move.c), sibling of the loop-remover

Runs at END right after `fluid_remove_redundant_loops`, same caller gate (fluid_editing + stretch +
non-rotating + final leg + no user-selected wires). Default off ⇒ byte-identical.

Two verified passes to a fixpoint:

1. **Slide the reversal jog.** A *novel* (this-drag) axis-aligned jog `d` whose two perpendicular
   same-net neighbours `A`,`C` (each a clean deg-2 corner, no pin) leave on the **same side** (a
   reversal) is slid to the **nearer** neighbour's far column. The nearer neighbour collapses
   (zero-length ⇒ dropped by `check_collapsing_objects`), the farther one shortens, `trim_wires` merges
   the collinear remainder.
2. **Retract the orphaned riser tail.** The slide leaves the C12 riser overshooting to the old corner
   (a dangling tail: deg-0 end, no pin, that was a real junction at START — `fluid_start_deg_at ≥ 2`).
   Retract it to its nearest interior junction (or delete a whole orphaned stub), verified.

**Safety:** every mutation is pin-partition VERIFIED (`fluid_loop_partition`, pure `touch()`,
node[]-independent) against the pass-entry BASE; any change to a pin's partition ⇒ revert. So no pin
strands and no two nets merge (a foreign-pin short shows up as a merge). **Scope:** the jog must be novel
(so a user's deliberate staircase is never rewritten); the tail must have been a START junction (so a
user's dangling stub is never pruned). Strict no-op unless a removable reversal exists.

Result `#net2`:
```
(-420,-170)-(-420,-140)   riser (retracted from -90 to -140)
(-480,-140)-(-420,-140)   cross
(-480,-140)-(-480,-130)   M stub
```
The clean L. Netlist pin-partition byte-identical to before_3 (C12.m = R18.P = #net2; R18.M = #net1).

## Gotchas hit while building

- **Novelty must be SPAN-only, not span+lab.** `fluid_wire_is_novel` keys on `lab=`; adding an isolated
  ring on its own net **renumbers** every other auto `#net`, so a pre-existing ring/loop edge reads as
  "novel" and the straightener reshaped it (test_wireedit_45 cases G/D regressed). A span present at
  START IS the same physical wire (trim dedups spans) regardless of lab ⇒ new `fluid_wire_is_novel_span`.
- **`touch()` mishandles a zero-length span.** A degenerate START snapwire (a label tap left a point
  `[-80,-60,-80,-60]`) matches `touch(...,110,-60)` for ANY point on row y=-60 (its collinear test is
  trivially 0==0 and the axis branch ignores the off-axis coord). That inflated `fluid_start_deg_at` and
  deleted a legit dangling user run piece (test_wireedit_20). `fluid_start_deg_at` now skips degenerate
  spans.

## Adversarial review finding (wf_bacae8eb) — the pin-less-net short, FIXED

The pin-partition verify (`fluid_loop_partition`) indexes only INSTANCE pins, so it is blind to a net
that has copper but **no instance pin** (a `lab=VDD` supply stub with no device on it). The delete-only
0088 loop-remover is immune (removing copper cannot create an adjacency), but the 0089 **slide MOVES
copper into a new column** — so it could land `d` on a foreign pin-less labeled wire and silently short
`#net2` to `VDD` (and rename it), invisibly to the verify. Reviewer's realizable scenario: a novel jog
`d=(-80,-60)-(-80,-160)`, neighbours to `x=-400` (near) and `x=-500` (far, same side); the near far-end
riser runs *away* from the jog, so the slid `d` at `x=-400,y∈[-160,-60]` newly overlaps a `lab=VDD` stub
at `x=-400,y∈[-140,-100]` that has no pin.

**Fix:** a slide is now KEPT only if the pin-partition is preserved AND the reshaped `d/A/C` did not land
on FOREIGN copper — `fluid_slide_merges_foreign()` rejects any wire outside `d`'s **pre-slide
touch-component** (`fluid_wire_reach_set`) that the slide newly touches. This allows the intended
same-net adjacency (the riser `B`, already in `d`'s component) and rejects a foreign short (`VDD`, not in
it) — catching the pin-less case the pin-partition misses, using the netlister's own endpoint-touch
connectivity model. (Scope-lens claim — that pass 1 reshapes non-novel neighbour copper — was
REFUTED: the novel jog `d` is the scope anchor, and the collapsing neighbour is exactly the drag-made
redundant copper, as in 0088's H3.)

## Tests

- `tests/headless/wireedit/test_wireedit_46_reversal_0089.tcl` — 14 checks (clean-L geometry, no x=-400
  excursion, P1/P2/P4, isolated-ring scope, non-reversing no-op). Sabotage-verified (5 RED with the pass
  compiled out). Runs true-headless (scripted move == interactive release).
