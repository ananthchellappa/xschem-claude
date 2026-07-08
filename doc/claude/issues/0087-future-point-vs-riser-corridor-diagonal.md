# 0087 — Future tests probe a POINT, not the riser CORRIDOR (razor-edge diagonal at +250,-90)

**Status: FIXED** (2026-07-08, src/move.c). Branch fluid-editing. Builds directly on
[0086](0086-future-blind-leg0-aesthetics-defeat-decomposition.md) / [0085](0085-blind-elbow-diagonal-fallback-shorts.md);
terminology in `doc/claude/code_analysis/fluid_editing_terminology.md`, spec `doc/claude/specs/incremental_wire_reroute.md`.

## Name for the phenomenon

**"Future point vs riser corridor"**: the 0086 future-aware hazard tests each project a co-moving
pin to its FINAL landing **point** and test whether leg-0 copper covers that single point. But a
co-moving pin is not a point — the remaining decomposition leg drags a **riser** from the pin's
intermediate (post-current-leg) position to its final one, and foreign copper anywhere on that
corridor shorts just as surely. When a slid stub / elbow corner parks a **single grid off** the
final point but squarely inside the riser, the point test misses, the two-leg decomposition shorts
its partition check, and the gesture collapses to the 0085 rigid **diagonal relay** — saving diagonal
copper although a clean Manhattan route exists. This is the exact **wire-overlap gap** 0086 deferred:
*"fluid_slide_future_hazard tests only pin landings; a future-landing wire overlap … is not modeled —
no known repro."* Now there is a repro.

## From-user repro

- Scene `tests/from_user/before_3.sch`; broken result `tests/from_user/after_7.sch`; fixed result
  `tests/from_user/after_7_fixed.sch`.
- Gesture: fluid stretch-drag of R18 by `(+250,-90)` (interactive log `/tmp/Xschem.log.9`, trace
  `/tmp/fltrace_7_8_3.log`; launch `FLUID_TRACE=… src/xschem --script src/cadence_style_rc --logdir /tmp`).
- Broken damage: `N -400 140 -150 -100` and `N -400 -90 -150 -160` — two diagonals (connectivity was
  correct: the diagonal relay preserved the partition; the ROUTE quality is the bug).

**Razor edge**: in the trace, `(+250,-90)` was the ONE delta that failed — its neighbours
`(+250,-80)`, `(+250,-100)`, `(+240,-80)`, `(+260,-100)` all produced clean Manhattan routes. R18's
two pins land STACKED on the shared column x=-150 (M=#net1 at y=-100, P=#net2 at y=-160, body between).

## Mechanism

Geometry after the drag: M(net1) at (-150,-100), P(net2) at (-150,-160); the C12 net2 stub junction
is at (-400,-90). On leg 0 (pure X, +250) the net2 stub corner slid east to **(-150,-90)** — one grid
below M's final point (-150,-100) but on M's riser column x=-150. M's riser (net1) runs down that
column from -100 to the row, so the slid net2 copper at (-150,-90) sits on it → net1 ∪ net2.

- 0086's `fluid_slide_future_hazard` tested only M's final POINT (-150,-100): the slid endpoint
  (-150,-90) is 10 off it → **missed** → slide accepted.
- With the slide (hypothetically) declined, 0086's `fluid_ml_future_covers` elbow tie-break also
  tested only the point, so it could not distinguish the two orientations either.

At `(+250,-80)` M's final point is (-150,-90) — coincidentally EXACTLY the slid endpoint, so the
point test happened to fire; at `(+250,-90)` the pin moved one grid further and slipped off the point.

## Fix (src/move.c)

Two new geometry helpers (next to `fluid_pin_on_seg`):

- **`fluid_seg_pair_touch(A,B)`** — do two AXIS-ALIGNED segments share any point? Handles
  both-horizontal / both-vertical (collinear overlap) and perpendicular (cross-point) cases; a
  degenerate (point) input falls back to `fluid_pin_on_seg`; diagonal input returns 0 (callers only
  pass H/V copper and single-axis corridors). Same `cadsnap/2` tolerance.
- **`fluid_seg_pair_touch_except(A,B,ex,ey)`** — as above but a shared contact EXACTLY at `(ex,ey)`
  does not count (returns 1 iff they share some point OTHER than `(ex,ey)`).

Both future tests now probe the co-moving pin's **riser corridor** = segment from its intermediate
position `(px+deltax, py+deltay)` to its final `(+fluid_leg_future_dx/dy)`, instead of the final point:

- **`fluid_slide_future_hazard`** uses `fluid_seg_pair_touch` (the slid copper's far end is not the
  pin, so no exemption). Now DECLINES the corner slide at `(+250,-90)` → falls back to the jog relay.
- **`fluid_ml_future_covers`** uses `fluid_seg_pair_touch_except`, exempting the elbow's OWN moving
  pin `(mx,my)`: the L must legitimately terminate at its own pin, and that pin travels on in the
  next leg — only copper crossing the corridor ELSEWHERE is a future short. Without the exemption
  BOTH orientations flag (f0=f1=1, because both L's end at P's intermediate, which sits on M's
  corridor) and the tie-break cannot pick the clean one. With it, `f0=1 f1=0` → picks V-first
  (net2 stays on column x=-400, over the top, down to P). Trace: `elbow-future … f0=1 f1=0 -> ml=2`.

**Inert outside decomposed diagonal legs.** The corridor is non-degenerate only on leg 0 (where
`fluid_leg_future=(0,totdy)`); leg 1, pure-axis moves and plain moves have `fluid_leg_future=(0,0)`
so the corridor collapses to a point and the helpers reduce to the pre-0087 `fluid_pin_on_seg` test —
byte-identical. Both callers still early-return 0 when `fluid_leg_future_*` are both 0.

**Safety envelope.** The corridor is a strict SUPERSET of the old point, so the change can only make
the future tests fire MORE often. A slide-test hit only DECLINES to the hazard-aware jog relay; an
elbow-test hit only BIASES between two already-P2-clean orientations (a bug there is at worst
aesthetic — a false miss just rolls back to the old diagonal relay, connectivity-safe). So the fix
cannot introduce a short or disconnect; the risk is only an aesthetic over-decline in untested scenes.

## Result

`(+250,-90)` now all-Manhattan, nets distinct (`after_7_fixed.sch`):

```
net1: (-150,-100)→(-150,0)→(-400,0)→(-400,140)→rows          (M down its own column)
net2: (-420,-90)→(-400,-90)→(-400,-170)→(-150,-170)→(-150,-160)=P   (up x=-400, over the top, down to P)
```

## Verification

- `tests/headless/wireedit/test_wireedit_44_diagonal_manhattan_quality.tcl` extended: **D6** pins the
  `(+250,-90)` razor-edge quality (9 asserts: all-Manhattan, both pins connected, R18 not
  self-shorted, C12/rail nets distinct, v8 not shorted, OUT untouched); **D7** locks the whole
  `(+230..+270, -60..-110)` band (30 deltas) as all-Manhattan + partition-clean.
- Full wireedit suite 44/44 PASS (incl. 43, 44).
- **Sabotage-verified**: collapsing EITHER corridor to a point (revert to pre-0087) → D6+D7 go RED
  (diagonals return); restored → ALL PASS. Both pieces are load-bearing.
- End-to-end replay of the user gesture on the real `before_3.sch` (`move_objects 250 -90 stretch
  kissing`) → 13 wires, 0 diagonal, R18.P=#net2 / R18.M=#net1 distinct.
- The rest of the full regression suite is unaffected (the change is compile-gated to fluid diagonal
  leg-0; save/load/netlist output is untouched). Golden create_save/open_close/netlisting harness
  cases and the stefan xschemtest step fail only on the pre-existing PATH-resolved-`xschem`
  environmental limitation, not on this change.

## Adversarial review round (wf_5b3917ed, 3 lenses — segment-math / connectivity / inertness — + refute-verify)

**0 confirmed defects** (`confirmed:[]`, refuted_count 1). segmath and connectivity lenses found nothing;
the inertness lens raised ONE **P3** (refuted, high confidence):

- **Parked P3 — pin-exemption could aesthetically over-decline (REFUTED).** Claim: if a foreign pin's
  riser corridor touched ml0's L only at `(mx,my)` (exempted) and ml1's L nowhere, the exemption would
  turn a decisive clean pick into the P6 coin-flip and could yield a diagonal. Verdict: not a real
  defect — (1) the tie-break fires ONLY between two orientations already `fluid_ml_hazards`-clean, so a
  miss can never pick a hazardous L; (2) if a shorting orientation were nonetheless committed, the
  attempt-loop `fluid_partition_changed()` re-check rolls back to the rigid relay → no persistent short
  (P2) / disconnect (P1); so the worst realizable consequence is an aesthetic diagonal in a contrived,
  untested corner. Stronger geometric note (beyond the verifier): the harmful ASYMMETRY the claim needs
  is in fact impossible — `(mx,my)` is the L's own moving-pin ENDPOINT, shared by BOTH orientations, so
  a corridor through `(mx,my)` touches ml0 AND ml1 there; the exemption fires symmetrically. In the one
  realizable variant (ml0 only-at-pin, ml1 at-pin+elsewhere) the exemption KEEPS the strictly-better
  orientation. The reviewer's proposed "fix" (drop the exemption) would REGRESS this very bug: at
  `(+250,-90)` without the exemption both orientations flag (`f0=f1=1`, both L's end at P's intermediate
  on M's corridor) → P6 → the diagonal returns. The exemption is load-bearing.

## Deferred

- Inherited from 0086/0085: scenes where BOTH leg orders and all elbow choices are genuinely blocked
  still (correctly) end in the rigid diagonal relay — the general "ortho-quality route where no clean
  L exists" item stays open.
- `fluid_slide_future_hazard` still models a rigidly co-moving (fully SELECTED) corner neighbour's
  span as diagonal (exempt) — the conservatism gap noted in 0086 review (ii); no known repro.
