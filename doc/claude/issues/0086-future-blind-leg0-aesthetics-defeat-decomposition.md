# 0086 — Future-blind leg-0 aesthetics defeat the two-leg decomposition (diagonal copper despite a clean Manhattan solution)

**Status: FIXED** (2026-07-08)

## Name for the phenomenon

**"Future-blind leg-0 aesthetics"**: during leg 0 of the 0081 X-then-Y decomposition, three
aesthetic/quality passes (corner slide, free elbow tie-break, P3 exit stub) each made a locally
harmless choice that parked copper or an anchor exactly on a co-moving pin's **final** (post-leg-1)
landing point. By leg 1 the follow stretch from that anchor is a **degenerate straight run**
(the elbow has no freedom left), so the short is unavoidable, the partition check rolls back
attempt 0 and attempt 1, and the gesture collapses to the 0085 **rigid diagonal relay** — saving
diagonal wires even though a clean Manhattan route exists. This closes the 0085 deferred item
"ortho-quality route where no clean L exists" for the (common) case where a clean L **does** exist
but the decomposition self-sabotaged.

## From-user repro

- Scene: `tests/from_user/before_3.sch`; result: `tests/from_user/after_6.sch`
- Gesture: fluid drag of R18 (vertical res between #net2 stub above and #net1 riser below) by
  `move_objects 150 -80` (interactive log `/tmp/Xschem.log.8`, trace `/tmp/fltrace_7_8_2.log`)
- Saved damage: `N -400 140 -250 -90` and `N -400 -90 -250 -150` — two diagonals (connectivity
  correct: the rigid relay did its job; the ROUTE quality is the bug)

Trace signature:

```
attempt=0 done (nlegs=2) partition_changed=4 -> ROLLBACK to single diagonal pass
attempt=1 done (nlegs=1) partition_changed=4 -> ROLLBACK to rigid diagonal relay
attempt=2 done (nlegs=1 diag_relay=1) partition_changed=0 -> ACCEPT
```

`partition_changed=4` is ONE real merge (#net1 ∪ #net2) plus canonical-id cascade (the OUT pins
renumber); the new `FLTRACE pchg:` per-pin dump makes this readable directly.

## Mechanism (three vectors, uncovered one under the other)

Key geometry: R18.M (bottom pin) finally lands at **(-250,-90)**; net2 must route from the C12
stub junction (-400,-90) to R18.P's final (-250,-150). The clean solution keeps net2 on column
x=-400 (corner at (-400,-160)) and jogs the net1 riser via the offset pass's V-H-V (col x=-250,
jog y=0) — the offset pass already produced the net1 side correctly in attempt 0.

1. **Corner slide** (`compute_wire_slide`): leg 0 (pure X) slid the perpendicular stub
   (-400,-90)-(-400,-70) rigidly, dragging the corner to (-250,-90) — the stretching collinear
   neighbour's endpoint became a fixed anchor exactly on M's landing. Leg 1's follow stretch
   from (-250,-90) to (-250,-150) crosses/lands on the pin: short, no elbow involved at all.
2. **Free elbow tie** (`place_moved_wire`): with the slide declined, the stub relay's two L
   orientations are both P2-clean *at leg-0 sight* (M's landing pin is still at (-250,-10) during
   leg 0); the default tie keeps H-first, whose corner is (-250,-90) — same trap.
3. **P3 exit stub** (`insert_exit_stubs`): with (1)+(2) fixed, leg 0 still inserted the escape
   stub at the pin's INTERMEDIATE position: (-250,-80)-(-250,-70). That stub's far end is an
   anchor inside leg 1's corridor; the leg-1 stretch from (-250,-80) to (-250,-150) sweeps
   (-250,-90). Same disease, third vector.

Also tried and rejected: **Y-then-X leg order** — here the bottom pin's intermediate position is
the net2 junction itself (-400,-90), and the X leg leaves an H wire anchored there: shorts too.
The leg order is not the culprit; the future-blindness is.

## Fix (all three vectors, all inert outside decomposed fluid legs)

`src/move.c`:

- `fluid_leg_future_dx/dy` statics: the REMAINING legs' delta, set per-leg inside the 0081/0085
  attempt loop (leg 0 of nlegs==2 → (0, totdy); every other pass → (0,0)), cleared after the loop.
  Every new check keys on "future ≠ 0", so single-axis moves, plain moves, attempts 1/2 and
  default-off builds are byte-identical.
- **(a) `fluid_slide_future_hazard()`**: `compute_wire_slide` declines a corner slide whose
  post-slide copper — or a dragged collinear neighbour's stretched run — would cover a co-moving
  foreign-pristine-net pin's final landing (same walk/exemptions as `fluid_ml_hazards` class 2).
  Declining falls back to the ordinary jog relay, which has hazard machinery.
- **(b) `fluid_ml_future_covers()`**: new elbow **tie-break** (fires only when both orientations
  are P2-clean, BEFORE the P6 min-bend bias, and P6 may not flip into a future-covered
  orientation): prefer the L that avoids every co-moving foreign-net pin's final landing.
- **(c) exit stubs on the FINAL leg only** (`leg == nlegs-1`): the P3 stub is a final-state
  aesthetic; planting it at a leg-0 intermediate pin position creates an anchor in the later
  leg's corridor. The final leg re-inserts stubs at true post-move pin positions.

Trace upgrades (permanent, FLUID_TRACE-gated): `FLTRACE pchg:` per-pin partition diff,
`FLTRACE wires:` dump at each attempt end, elbow lines now carry `r1=(..) r2=(..)`,
`FLTRACE slide: ... DECLINE`, `FLTRACE elbow-future: ...`.

## Result

`(+150,-80)` now: attempt 0 ACCEPTs (`partition_changed=0`), all-Manhattan, nets distinct,
release == stepwise byte-identical:

```
net1: (-250,-90)→(-250,0)→(-400,0)→(-400,140)→rows   (offset-pass V-H-V, unchanged rows)
net2: (-420,-90)→(-400,-90)→(-400,-160)→(-250,-160)→(-250,-150)  (V-first elbow + final-leg stub)
```

## Verification

- `tests/headless/wireedit/test_wireedit_44_diagonal_manhattan_quality.tcl` (27 checks): D1
  one-shot, D2 stepwise (wandering waypoints from the user trace), D3 release==stepwise
  byte-compare, D4 pure-axis inertness, D5 the 0085 scene (+180,-90) stays connectivity-clean.
- Sabotage-verified: each of (a)/(b)/(c) and the future-delta plumbing individually disabled →
  test 44 FAILS (diagonals return); restored → ALL PASS. So all four pieces are load-bearing.
- Full wireedit suite (45 tests incl. 43) ALL PASS.

## Adversarial review round (wf_b333bd95, 6 lenses, 2-skeptic verify)

- **F1 (P2, CONFIRMED by code-read + live repro, FIXED)**: accepting a corner slide promotes any
  co-candidate at the shared corner whose other end is pin-grabbed to full SELECTED
  (`select_wire` folds SELECTED1|SELECTED2, select.c:965) — a RIGID translate of exactly the
  copper that co-candidate's own hazard test declined (or would decline: order-dependently its
  candidacy test is skipped entirely). Fix: corner-group veto — before accepting a slide, test
  every would-fold co-candidate with `fluid_slide_future_hazard`; any hit declines this slide
  too (`DECLINE (co-candidate at corner is future-hazardous)` trace). Verified on a two-instance
  split-run scene: veto fires in both wire orders; sabotaging it reproduces the silent promotion.
- **F2 (P3, CONFIRMED, FIXED)**: the `elbow-future` trace printed the pre-P6 guess; in the
  f0==f1 case P6 could still flip with no trace. The line now prints AFTER the whole decision.
- Unverified (review agents hit the session token limit mid-verify; re-examine on next touch):
  (i) claim that the future tie-break can flip into an orientation P6 would have vetoed for a
  moving-body cross (P5) — by the conflict order a future P2-class landing outranks P5, so the
  flip is defensible, but the interplay was not adversarially settled; (ii) claim that
  `fluid_slide_future_hazard` models a rigidly co-moving (fully SELECTED) corner neighbour as a
  far-end-anchored stretch (span modeled diagonal => exempt) — conservatism gap, not a short.

## Deferred

- Scenes where BOTH leg orders and all elbow choices are genuinely blocked still (correctly) end
  in the 0085 rigid diagonal relay — the general "ortho-quality route where no clean L exists"
  item stays open (0085 deferred list).
- `fluid_slide_future_hazard` tests only pin landings; a future-landing **wire** overlap (a slid
  wire parking under where a co-moving *wire end* lands) is not modeled — no known repro.
