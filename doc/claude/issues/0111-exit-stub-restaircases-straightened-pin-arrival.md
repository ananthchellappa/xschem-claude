# 0111 — exit-stub/straighten round trip saves a 4-segment staircase (3 suffice)

**Status: FIXED**

## Report

`tests/from_user/before_8.sch`, mouse over R18, plain LMB drag north-west, released at
(-110,-90) → saved as `tests/from_user/after_28.sch`. User: "#net3 is staircased — should use 3
segments instead of 4."

Trace: `/tmp/fltrace_7_8_25.log` (launched with `FLUID_TRACE=... src/xschem --script
src/cadence_style_rc --logdir /tmp`).

## Saved geometry (the defect)

```
N -320 -150 -190 -150 {lab=#net3}   horizontal @y=-150
N -190 -150 -190 -90  {lab=#net3}   riser at x=-190 (one grid OFF the pin)
N -190 -90  -180 -90  {lab=#net3}   10-unit stub east into R18's P pin (-180,-90)
```

## Root cause — an undo/redo pair between two END passes

The trace shows the two passes fighting:

1. `fluid_straighten_reversals()` (0090 staircase collapse) slides the riser ONTO the pin:
   `straighten: slid jog wire=13 x->-180 (staircase collapse)` — the near collapse target was
   the far end of the pin's own P3 exit stub, so the stub is absorbed and the leg lands
   straight on the pin.
2. `insert_exit_stubs()` (P3, runs after) re-jogs that leg one grid back off the pin along
   the escape normal and re-inserts the stub.

Net effect of the round trip: the jog is NORMALIZED to one grid on the outward-normal side.
That is exactly what the committed goldens rely on (`test_wireedit_37/40` connected-wire
shove, the 0089/0090/0091 clean-route shapes) — **except** when the decomposed drag has
already left the jog exactly there: then the round trip is a no-op and the redundant
staircase survives into the save. before_8's pre-existing one-grid stub relayed by the
push-through slide (0109) is precisely that case.

## Failed approaches (kept for the record — both broke committed goldens)

- **Shape-based skip in insert_exit_stubs** (skip the stub when the far corner's single
  continuation heads along the normal): fires on every monotone arrival, not just the
  round-trip no-op. A/B-verified regressions: wireedit 37/39/40/46/47/48 (26 checks) — the
  shove displacement is CARRIED by the insert slide, and the 0089-0091 goldens assert the
  one-grid outward jog.
- **Landing registry** (straighten records pins it collapsed onto; insert skips those):
  closer, but still suppressed the shove (37/40) and de-stubbed the 0090/0091 shapes (47/48),
  because those goldens ARE the round-trip result.

## Fix (in `fluid_straighten_reversals`, move.c) — reschedule the pin-landing collapse

When the NEAR collapse target sits on a **moving** instance pin whose escape normal runs
**along the slide axis** (i.e. the absorbed neighbour is the pin's P3 exit stub):

1. try the **FAR** target first — where legal it removes the jog entirely and the route
   arrives straight along the pin's lead (P3-perfect, minimum segments). Because this is a
   brand-new route choice (pre-0111 it was never reached), it is additionally guarded
   against the **moved** body (`fluid_seg_crosses_body(..., moved=1)`, with the p5-style
   pin-endpoint exemption so a lead run INTO the pin is not flagged by the text-inflated
   bbox — mirrors `predicates.tcl p5_no_body_cross`);
2. else collapse the jog to **one grid OUTWARD of the pin** (`pin + grid × normal`) — the
   old collapse + re-stub round trip's exact result, so every golden shape is preserved;
   skipped when the jog already sits there (the no-op that used to save the 0111 staircase —
   in that case nothing fires and the far target was the only improvement possible).

A stationary-pin landing, or a pin whose normal is perpendicular/ambiguous, keeps the plain
near-first schedule (insert_exit_stubs never re-jogged those along the slide axis, so plain
collapse is the baseline there). `insert_exit_stubs` itself is byte-identical.

Direction subtlety: the outward candidate must use the **escape normal**, not "one grid on
the side the jog came from" — test_wireedit_48 case A approaches the pin from the body side,
and the round trip normalized it to the outward side (y=50 under-run), not back toward the
body (y=30).

## Result on the reported case (`tests/from_user/after_28_fixed.sch`)

- `#net3`: far collapse succeeds → **2 segments** (better than the reported ask of 3):
  `(-320,-160)→(-320,-90)` (C12 foot column, merged by trim) then `(-320,-90)→(-180,-90)`
  straight along the lead into R18's P pin.
- `#net1`: far collapse is foreign-blocked (would touch the new #net3 column) → normalized
  one-grid outward jog, byte-identical to the pre-0111 shape (stub `[-120,-90 → -110,-90]`,
  riser at x=-110).

## Verification

- `tests/headless/test_fluid_exit_stub_staircase_0111.tcl` — RED-first (reproduced after_28
  byte-exact pre-fix), 20/20 post-fix; covers the user's multi-commit NW hand path and a
  single-step NW drag, asserts the 2-segment #net3, the absence of the (-190,±) jog corners,
  and the deliberately-kept #net1 outward jog.
- Full `tests/headless/wireedit/` suite (canonical `--nogui` invocation): 49/51 PASS; the two
  failures (36, 38) fail identically on the pristine pre-fix binary (pre-existing).
- Fluid family under a live display: 0105/0106/0107/0108/0109/0110/0111 + test_fluid_editing
  all PASS. `test_wire_split` W7 fails identically on baseline (pre-existing).

## Files

- `src/move.c` — `fluid_seg_crosses_body()` (parameterized obstacle class + moving-pin
  exemption; `fluid_seg_crosses_stationary_body` is now a wrapper), candidate schedule in
  `fluid_straighten_reversals`, ordering-invariant comment at the insert_exit_stubs call site.
- `tests/headless/test_fluid_exit_stub_staircase_0111.tcl` — regression test.
- `tests/from_user/after_28_fixed.sch` — reference save of the fixed gesture.
