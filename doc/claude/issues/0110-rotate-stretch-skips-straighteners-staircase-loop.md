# 0110: rotated fluid stretch keeps a staircase + U-loop (straighteners rotfree-gated)

**Status: FIXED**
**Repro:** `tests/from_user/before_8.sch`, select R18, `m` (connected stretch), one ALT-R
mid-drag, drop at (+10,-90) -> R18 at (-30,-90) rot0 flip1. Saved by the user as
`tests/from_user/after_27.sch`.

## Symptom (quality only — no short)

- `#net3` reaches the rotated pin (-30,-120) as a 4-segment STAIRCASE:
  backbone `[-320,-150 -80,-150]` + jog `[-80,-150 -80,-120]` + horizontal `[-80,-120 -30,-120]`
  (+ the cap stub). The jog sits at the pin's STALE pre-move anchor column x=-80; the clean
  route extends the backbone to x=-30 and drops one riser (3 segments).
- `#net1` reaches the pin (-30,-60) through a U-LOOP: down `[-30,-60 -30,0]`, right
  `[-30,0 0,0]`, back up the old feed `[0,-40 0,0]` — under the very backbone `[-400,-40 0,-40]`
  that passes 20 units above the pin. Clean route: `[-30,-60 -30,-40]`, one T.

## Why

Both shapes are exactly what `fluid_straighten_reversals()` collapses (opposite-side STAIRCASE
step, issue 0090; same-side REVERSAL/U-turn, issue 0089) — but the whole straightener (and the
0092 overshoot collapse) was pinned to `rotfree` (`move_rot==0 && move_flip==0`): Phase 4b
deferred the aesthetic reshapers under rotation out of caution, so one ALT-R mid-drag turns
them off entirely. Additionally the 0103 `fluid_prune_anchor_tails()` ran AFTER the (skipped)
straighteners; the elbow's dangling stale-anchor tail `[-80,-120 -80,0]` holds the jog's
endpoint at touch-degree 2, which would have masked the staircase from the straightener anyway.

## Fix (move.c END cleanup block)

- Run `fluid_prune_anchor_tails()` (still `!rotfree`-only, delete-only + partition-verified)
  BEFORE the straighteners, so the stale-anchor tail is gone when jog detection runs.
- Un-gate `fluid_straighten_reversals()` + `fluid_collapse_axis_overshoot_stub()` from
  `rotfree`: every slide/retract they perform is already pin-partition-verified, novelty-scoped
  (`fluid_wire_is_novel_span`), user-protected (0091) and body-guarded
  (`fluid_seg_crosses_stationary_body`, stationary instances only), i.e. their guards are
  geometric and rotation-independent — the same argument that un-gated the DE-SHORT passes for
  0098 facet B. Worst case they decline and the pre-0110 route is kept.

## Verification

- `tests/headless/test_rotate_stretch_route_quality_0110.tcl`: the repro gesture; PASS = pins
  on distinct nets, `#net3` extends the backbone to the pin column (no jog at x=-80), `#net1`
  Ts onto the y=-40 backbone (no copper below y=-40 on that route), wire count == 13,
  total copper strictly below the pre-fix 1470.
- rot180 (2x ALT-R) and flip variants exercised in the existing 0104/0108 suites: no regressions.
