# 0109: pure-axis fluid drag THROUGH a follow anchor shorts the device (collinear stub sweep)

**Status: FIXED**
**Repro:** `tests/from_user/before_8.sch` (== `tests/headless/fixture_0105_pre.sch`), plain LMB
attached drag of R18 left by (-110, 0). Saved by the user as `tests/from_user/after_26.sch`.
**Trace:** `/tmp/fltrace_7_8_22.log` (user session), reproduced deterministically headless.

## Symptom

R18 sits inline on the y=0 row: pins (-70,0) on `#net3` and (-10,0) on `#net1`. The left pin's
follow stub is `[-80,0 -70,0]` anchored at the `#net3` riser foot `(-80,0)`; the right pin's stub
is `[-10,0 0,0]` anchored at `(0,0)` where the `#net1` feed `[0,-40 0,0]` descends. Dragging R18
left by 110 slides both pins ALONG that shared row, past the left stub's anchor:

- left stub stretches straight THROUGH its anchor: `[-80,0 -180,0]` — it now spans the right
  pin's landing point (-120,0);
- right stub stretches straight to `[-120,0 0,0]` — it now covers the `#net3` riser foot
  endpoint `(-80,0)` (endpoint-on-span = a junction in the netlister's touch model).

Both contacts merge `#net1` + `#net3`: R18 is shorted out; the save keeps one net
(`after_26.sch`, wires `[-180 0 -80 0]` + `[-80 0 0 0]` all `#net1`).

## Why nothing caught it

1. **No slide.** `compute_wire_slide()` only slides wires PERPENDICULAR to the move
   (move.c corner-slide rule); a follow stub PARALLEL to a pure-axis move is skipped, so the
   `#net3` riser (the perpendicular wire cornered at the stub's anchor) is never promoted and
   the stub just stretches straight through everything on the row.
2. **No safety net.** The P2 attempt loop (rollback -> single diagonal pass -> rigid relay) is
   armed only for `nlegs==2` diagonal decomposition or a rotated/flipped stretch
   (`move.c` `leg_snapped`). A pure-axis translation hits `if(!leg_snapped) break;` and commits
   sight-unseen — `fluid_partition_changed()` is never consulted.
3. The END `short-tail` pass sees the merge but removing any single tail only improves the
   partition diff 4 -> 3 (two independent contact points), so it reverts ("partial improvement
   only") and the short survives.

## Fix (move.c)

Two layers:

1. **Push-through corner slide** (`fluid_slide_push_through()`, called from
   `compute_wire_slide()`): when a partial-selected follow wire runs PARALLEL to a pure-axis
   move, its moving end is on a moving instance pin, and the move carries the pin strictly PAST
   the far (anchored) end, and every other wire at that anchor is a stationary PERPENDICULAR
   corner leg (riser): promote the stub AND each corner leg to full SELECTED (they translate
   with the pin) and partial-select the wires cornered at each leg's far end so they stretch to
   follow. The riser vacates the row: no crossing, no short, and the result is the minimal
   Cadence-like route (riser slides with the pin, sibling stub stays straight). Declines (plain
   stretch, today's geometry) when the anchor is a fixed pin / another moving pin / a collinear
   pass-through tap / a dangling end, when any corner wire is itself selected, or on a
   `fluid_slide_future_hazard()` hit. Gated on `fluid_editing` + `fluid_startsel_wires==0` +
   `fluid_slide_pushthrough_on` (see below).
2. **P2 safety net for pure-axis fluid stretches**: arm the `leg_snap` snapshot (nlegs stays 1)
   for a fluid, orthogonal, non-rotated, tool-owned-only (`fluid_startsel_wires==0`) pure-axis
   stretch, so the existing attempt loop verifies the partition and rolls back on damage.
   Attempts >= 1 clear `fluid_slide_pushthrough_on`, so a hazardous push-through falls back to
   the exact pre-0109 route (then the rigid relay as last resort). A clean attempt 0 breaks out
   immediately; intentional landings keep the attempt-1 (== old) result as before.

## Verification

- `tests/headless/test_fluid_drag_through_anchor_0109.tcl`: pure-left (-110,0) drag = the repro
  (RED before: pins merge onto one net), plus wobble-past-and-return and diagonal-dip drag
  paths, pull-away and pass-through-right variants, pins-distinct + no-diagonal + no-new-dangle
  checks on each.
- Full headless suite + `tests/` regression: no regressions.
