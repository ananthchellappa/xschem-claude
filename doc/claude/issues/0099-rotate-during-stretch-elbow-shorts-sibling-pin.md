# 0099 — rotate during a connected stretch shorts/disconnects the follow wires (elbow picks a leg through the rotated sibling pin)

**Branch:** fluid-editing   **Status:** FIXED for rotations/flips where a clean per-wire L exists
(rot90 — the reported case, flip, rot90+flip). RED-first regression, sabotage-verified, all existing
rotate/cadence/fluid suites green, translation path byte-identical. rot180/rot270 remain a
**documented known limitation** (see below). UNCOMMITTED.
**Fixture:** the user's `tests/from_user/before_7.sch` → `after_17.sch`.
**Repro launch (user):** `FLUID_TRACE=/tmp/fltrace_7_8_14.log src/xschem --script src/cadence_style_rc --logdir /tmp`
**Test:** `tests/headless/test_rotate_stretch_reconnect_0099.tcl` (X-required, self-skips under `--nogui`).
**Related:** [rotate_keep_connected_stretch spec](../specs/rotate_keep_connected_stretch.md) (Case 4 /
Phase 4b enabled the elbow picker under rotation but left its hazard math translation-only),
[0098](0098-fluid-stretch-pin-on-sibling-net-backbone-short.md) (sibling-pin self-short, same *class* of
symptom via a different mechanism — a mid-span backbone landing, de-shorted by a route-around jog).

## Name (short)
**"rotated-sibling-pin elbow short"** — during a connected stretch, ALT-R rotates a device so its two
pins swap arrangement; `place_moved_wire`'s elbow for one follow wire routes a leg straight through the
*other* (rotated) pin's new position, shorting the two pins — because the elbow's hazard picker measured
the co-moving sibling pin at `pre-move-coord + delta` (translation only) and never saw its rotated
landing.

## Gesture / symptom
Load `before_7.sch`. R18 is a `res`, pin P on `#net2` (with C12), pin M on `#net1`. Select R18, press
`m` (cadence connected stretch), press ALT-R once mid-drag (rotate 90°), drop at delta (30,20). Saved as
`after_17.sch`: R18 rotated to `-90 -60 1 1` but **both pins torn onto fresh nets #net4/#net5** (or, at a
slightly different delta, both pins shorted onto `#net2` and C12's backbone split off). The built-in
fluid P1/P2 invariant printer fires: *"instance 'R18' pins 0,1 were on distinct nets ('#net2','#net1'),
now both on '#net2' after move — device short/merge."*

## Root cause
`fluid_ml_hazards()` (src/move.c) scores the two connecting L orientations of a partially-selected
follow wire and the caller (`place_moved_wire`, ~move.c:1187) picks the lower-severity one. Phase 4b
enabled this picker under rotation ("only chooses between two connecting L's — can't disconnect"). But
the function's whole body is written for a pure translation:

* the co-moving-pin (MOVPIN) loop computes a sibling pin's post-move position as
  `get_inst_pin_coord() + delta` — the rotation about the grab pivot is **never applied**;
* `pmx = mx - delta` (M's pre-move position, used for the pristine-net lookup and the pre-move span
  tests) is likewise only valid under translation.

Under ALT-R, R18.M rotates to `(-120,-60)`, exactly on the vertical leg of R18.P's `ml=2` elbow. The
MOVPIN loop looked for M at `pre+delta = (-90,-30)`, found nothing, scored `ml=2` **clean** and the
(correct, non-crossing) `ml=1` **hazardous** → picked `ml=2` → net2 wire runs through M(net1) → short.
The active reroute engine that could otherwise route around (`fluid_shove_connected_wire` /
`fluid_reroute_around_obstacles` / `fluid_offset_foreign_pin_landing`, move.c ~5866) is *also* still
gated `move_rot==0 && move_flip==0`, so nothing downstream repairs the short.

## Fix (src/move.c `fluid_ml_hazards`, 2 edits, both gated on `move_rot||move_flip`)
1. **MOVPIN loop:** apply `ROTATION(move_rot, move_flip, x1, y1, px, py, ...)` to a co-moving pin's live
   coordinate *before* adding delta, so a rotated sibling pin is tested at its TRUE post-move position.
2. **Pre-move-M recovery:** replace `pmx = mx - delta` with the inverse of the forward ROTATION
   (un-rotate by `(4-rot)&3` with flip=0, then re-apply the involutive flip `2*x1-fx`) so `nf` and the
   pre-move span tests reference the real pin.

Pivot is `xctx->{x1,y1}` — the same point the commit block rotates the instance and every follow-wire
moving endpoint about **under plain ROTATE**. ⚠ CORRECTION (issue 0100): the claim "a fluid stretch is
never rotatelocal" was WRONG — the user's actual key, ALT-R mid-move, issues
`move_objects(ROTATE|ROTATELOCAL)` (callback.c:5100), and this test drove Shift-R (plain ROTATE)
instead, so the 0099 fix was green-but-hollow for the reported gesture. Issue 0100 fixes the
rotatelocal pivots (per-instance owner pivot for follow wires; pristine pre-move endpoint handed to
`fluid_ml_hazards`; per-instance MOVPIN pivot). Both edits are **skipped** when
`move_rot==0 && move_flip==0` (ROTATION is the identity, flip branch not taken) ⇒ **byte-identical**
translation path. The picker still only chooses between two *connecting* L's, so it can never
disconnect; it now scores the shorting orientation as MOVPIN and keeps the clean one.

With the fix the rot90 gesture preserves the partition: R18.P→#net2 (going up-and-over on the far side),
R18.M→#net1 (straight riser), C12's #net2 backbone intact, no short.

## Known limitation (NOT fixed here — documented, deferred to Phase 4c)
**rot180 / rot270** swap R18's two pins onto the *same vertical line* while their anchors stay put, so
the two follow-wire routes must **cross** to reach them. No single L per wire avoids the other; resolving
it needs the fluid reroute engine (shove / route-around-obstacle), which is still translation-only under
rotation (Phase 4b deferred as risky). The elbow-hazard fix alone cannot route crossing wires apart. The
test records these as informational notes (not hard failures); flip them to real assertions when the
reroute engine is made rotation-aware.

## Verification
* RED→GREEN, sabotage-verified: on baseline the test's 3 rot90 partition checks fail and the engine's own
  P1/P2 invariant prints the short; with the fix all rot90/flip/rot90+flip checks pass and the invariant
  is silent.
* Inverse-rotation math checked numerically for flip × {rot1,rot2,rot3} (recovers the exact pre-move
  point).
* `test_rotate_stretch_reconnect` 17/17, `test_cadence_stretch_move`, `test_fluid_editing` (only the
  PRE-EXISTING FE8 arc/modified-flag failure, unrelated), `test_fluid_loop_0088`,
  `test_fluid_reversal_0089/0096`, `test_fluid_*_0098` all green.
