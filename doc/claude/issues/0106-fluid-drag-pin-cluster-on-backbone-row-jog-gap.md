# 0106 — attached drag parks the pin's follow cluster on the backbone row: route-around gap welds or bails

**Status: FIXED** (src/move.c, `fluid_jog_pin_off_backbone` gap generalization)

## Name / class

**Pin-cluster-on-backbone jog defeat**: same collinear-landing family as 0105, but a plain
LMB attached drag brings not just the pins onto the sibling net's backbone line — it also
parks the invader pin's own follow copper there: its exit stub lies collinearly ON the
backbone and its riser's T-junction sits one grid from the pin. The 0098/0105 route-around
jog, built for a *bare* pin mid-span on a backbone, is structurally defeated by that
cluster.

## Repro (user session, FLUID_TRACE=/tmp/fltrace_7_8_20.log)

- `tests/from_user/before_8.sch`, launch `src/xschem --script src/cadence_style_rc`.
- Mouse over R18 body, plain LMB press, drag up 40, release → R18 (-40,0)→(-40,-40).
- Left pin (-70,-40) and right pin (-10,-40) land on the #net1 backbone row y=-40;
  the left pin's stub becomes `[-80,-70]` AT y=-40 (collinear overlap with the backbone)
  and the capacitor riser's bottom T-lands mid-span at (-80,-40) — three weld paths at once.
- Saved `tests/from_user/after_23.sch`: `N -80 -40 -10 -40` bridges the pins,
  `N -80 -150 -80 -40` T's into the backbone; #net3 swallowed by #net1, R18 shorted.

## Why the existing de-shorters lost (trace)

1. Rip-up slide: no perpendicular copper at P (riser is at x=-80, not through the pin) →
   `nslid==0` → 0105 collinear branch calls the jog around P.
2. Jog, old form: one-grid gap `[-80,-60]` centred on P(-70). The stub `[-80,-70]` lies
   wholly inside the gap → the "whole tiny wire in the gap" test **hard-bails** (and even
   without that, the qL bump leg at x=-80 would touch the riser T + stub end, welding the
   two nets the jog exists to separate — partition verify would reject every side).
3. `fluid_prune_shorting_anchor_tails`: dooming the riser `[-80,-150 -80,-40]` improves
   the pairwise diff 4→3 only (pin-on-backbone weld remains) → reverted.
4. Pure-axis drag is a single-leg move (nlegs==1) — there is no multi-attempt accept
   ladder to roll back to, so the shorted geometry commits directly.

## Fix

`fluid_jog_pin_off_backbone` generalized (0098/0105 callers unchanged):

- **Gap expansion**: before collecting clip wires, push each gap boundary outward one grid
  while it is *dirty*: a perpendicular wire occupies that column across the bump band, a
  row wire ends there without extending outward past the gap, or two row wires meet there.
  A bump leg must land on clean backbone interior. Bounded (16 grids) else decline.
- **Swallowed copper**: row wires lying wholly inside the (expanded) gap are now *skipped*
  — left untouched inside the gap — instead of aborting the jog. That is exactly the
  invader pin's own stub/riser cluster; it keeps carrying the pin's net through the gap.
- Collection widened from "wires covering Q" to "row wires overlapping the gap" (the outer
  backbone piece `[-400,-80]` ends before the pin and still must be clipped to the gap
  edge); a new `covers_q` check keeps the entry condition honest (some clipped wire must
  actually carry Q).

On the repro the gap expands `[-80,-60]` → `[-90,-60]` (riser T + stub end at -80), the
clip pass shortens `[-400,-80]`→`[-400,-90]` and `[-70,-10]`→`[-60,-10]`, skips the stub,
and the y=-50 bump verifies (`ripup: jogged backbone around pin (-70,-40) vert side=-10`).
The aesthetic passes then slide the whole backbone onto y=-50 with a drop into the right
pin at x=0; the capacitor route (riser + stub + pin) is byte-original. Saved result has no
shorts, no dangles, no body crossings.

All jog changes remain inside the partition-verified commit/revert envelope, so any
geometry this generalization mis-judges reverts to the pre-jog state — it can only
de-short or decline, exactly as before.

## Verification

- `tests/headless/test_fluid_drag_onto_backbone_row_0106.tcl` (fixture shared with 0105):
  3/3 PASS; sabotage-RED against the pre-0106 jog (git-checkout of move.c → P=M=net1).
- Battery green: 0105, 0098×2, 0088, 0089, 0096, 0099, 0100, 0103, 0104, reconnect,
  wireedit suite, run_regression.
