# 0139 — fluid connected-drag: a second gesture buries a pin-tracked trunk in the moved body

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** wiring / fluid connected-drag (`src/move.c`) — see `doc/claude/WIRING.md`
**Fixture:** `tests/from_user/before_39.sch` → `tests/from_user/after_42.sch` (buggy) /
`after_42_fixed.sch` (post-fix). Test `tests/headless/test_fluid_second_gesture_body_cross_0139.tcl`.
**Sibling of:** `0136` (same fixture/symbol/pass — `fluid_shove_jog_separated_trunk`).

## Gesture

Pointer on the body of `x1` (`SANDBOX/solar_ctl`, rot1), a **connected-drag done as TWO separate
press-drag-releases**. Action-log replay:
`select_at 80 -30 ; move_objects 0 20 ; move_objects -10 -40` → gesture 1 delta **(0,+20)**, gesture 2
delta **(-10,-40)**, net **(-10,-20)**. `x1` origin (80,10) → (80,30) → **(70,-10)**. FLUID trace
`/tmp/xschem_fltrace_290673.log`.

Because the pipeline arms once per gesture (`fluid_gesture_arm`, trace lines 1 and 107), **gesture 2's
START snapshot is gesture 1's RESULT** — this is what makes the trunk read "novel" below.

## Geometry

`x1` DEVICE body box after the move (symbol polygon `P 40 -20 -130 -20 -130 20 40 20`, rot1 about
(70,-10)) = world **x[50,90] y[-140,30]**. Moved pins: LED(80,-160) REF(60,-160) CTRL1(80,50)
TRIANG(40,50). The pin-inclusive symbol bbox `fluid_inst_body_box` uses (leads/pins included) is the
larger **x[37.5,90] y[-162.5,52.5]** — that is the box the shove passes actually gate on.

LED (#net1) reaches its rail (`-50,-20`) through a horizontal **crossbar** the FIRST gesture already
dragged down to y=-130 (from before_39's y=-150, following the pin). At gesture 1's end the body top was
at y≈-100, so y=-130 was safely clear. Gesture 2 advances the body top up to y=-140, **engulfing** the
crossbar; the moved LED pin's stub stretches south into the body to meet the trapped elbow (80,-130).
Saved route (after_42):

```
LED(80,-160) → ↓ N 80 -160 80 -130 → elbow(80,-130) → ← N -50 -130 80 -130 → (-50,-130) → ↓ rail → (-50,-20)
                          the elbow (80,-130) and the crossbar's x[50,80] span are INSIDE the body
```

Two subsegments thread the body: horizontal `(50,-130)→(80,-130)` and the stub's `(80,-140)→(80,-130)`.

## Defect (named)

**`second-gesture-buries-pin-tracked-trunk`** (user-reported, P5 no-body-cross): the LED net's crossbar
threads `x1`'s body. Partition is unchanged (electrically correct) — a **P5** violation, not a short.

The 0136 pass `fluid_shove_jog_separated_trunk` is the one purpose-built to shove exactly such an
off-pin-row, jog-separated through-body trunk out of a moved body, yet it declined here for **two
independent reasons**, each an over-strict gate:

1. **`novel-span-rejects-pin-tracked-shrink`** — its PRE-EXISTING gate (`!fluid_wire_is_novel_span`,
   move.c ~7556) read the crossbar as this-drag copper. gesture 2 **shrank** the crossbar's span
   (x2 90→80: its right end tracked the LED column inward under the −10 x-delta), so it is no longer
   byte-identical to gesture 2's start snapshot (`[-50 -130 90 -130]`). The gate's premise "a
   pre-existing trunk's span is byte-identical at START" is false for a trunk whose endpoint tracks a
   moved pin. (My first-pass diagnosis blamed a y −150→−130 relocation; the verifier corrected it — the
   snapshot re-captures per gesture, so the novelty is purely the **x-extent shrink**.) A WIRING §11
   *novelty-laundering* instance (landmine 11).
2. **`single-pin-net-reads-redundant`** — its LOAD-BEARING gate (dooming the run must change the
   **pin** partition, move.c ~7666) is BLIND to a SINGLE-PIN net. `#net1` carries only the LED pin (the
   rail dead-ends with no second device pin), so dooming the sole stub→rail path moves no pin between
   components even though the crossbar IS the only bridge. The pin-partition proxy cannot see a 1-pin
   feed's cut-edge.

Two more passes correctly *do not* fix it (by-design non-coverage, not defects): the PIN-INCIDENT
`fluid_shove_body_crossing_backbone` seeds only the moved pin's OWN row/column (LED rows y=−160/50, never
the crossbar's y=−130 — its x-run grabs only the vertical stub, tries to shove the pin's own column, and
REVERTS on verify), and `fluid_straighten_reversals` declines every lift of a load-bearing Z it cannot
legally collapse ("reversal/staircase leg crosses body").

## Fix

Three surgical changes in `src/move.c`, all inside/around `fluid_shove_jog_separated_trunk`:

1. **`fluid_wire_pretracked_shrink(e, xmove)`** (new helper next to `fluid_wire_is_novel_span`): a
   novel-span wire is re-admitted iff it lies **collinear inside a START wire's along-footprint** AND an
   **along-endpoint sits on a MOVED pin's along-coord** (the end the pin dragged). A genuine detour leg
   (wireedit_36 case j) is neither — a novel row/column off every start footprint. The gate becomes
   `if(fluid_wire_is_novel_span(t) && !fluid_wire_pretracked_shrink(t, xmove)) continue;`.
2. **wire-level cut-edge fallback** in the load-bearing gate: when the pin-partition is unchanged, flood
   touch-connectivity **with the run doomed** from the first attachment; if any other attachment is
   unreachable, the run is a genuine BRIDGE (keep it). A redundant user ring (wireedit_45 U/T) keeps its
   attachments mutually reachable through its other arc, so it still reads redundant and is declined.
3. **step the shove target outward past a neighbour net**: at END, `straighten` parks the REF `#net2`
   crossbar at y=−170 — exactly the one-grid-past-the-edge line the `#net1` crossbar would land on, so a
   lone one-grid shove welds it foreign and declines. The side loop now STEPS the target grid-by-grid
   (bounded, 12) until the rail clears the neighbour; a BODY block (a far leg would thread a device body)
   still fails the side immediately. The clearance to y=−180 leaves the `#net1` rail crossing the `#net2`
   crossbar at (−50,−170) **mid-span only (shares no endpoint)** — not an electrical short, exactly the
   benign near-miss 0136 defect 2 already accepts.

Never worse: every candidate still passes the body-free precheck + **DOUBLE** partition-verify
(restore-START name AND preserve-entry geometric) with EXACT revert; a decline / failed verify keeps the
accepted route byte-identical. No new wires are created (a named rail is reshaped, never renamed).

### Result

`#net1` crossbar y=−130 → **y=−180** (one grid above `#net2`'s −170): route
LED(80,−160)→(80,−180)→(−50,−180)→rail(−50,−20), body-clear. Partition intact (LED=#net1, REF=#net2
distinct — verified across the mid-span crossing), no diagonals.

## Verification

- New test `test_fluid_second_gesture_body_cross_0139.tcl`: **RED on baseline** (exactly the 3 body-cross
  checks fail; the 10 setup/connectivity checks pass, proving the gesture replay is sound), **GREEN after
  fix** (13/13). Real-X; self-skips without DISPLAY.
- Regression (all GREEN): **wireedit 57/57** (the over-fire guards 36 case j + 45 U/T intact); sibling
  **jog_separated_trunk_0136 11/11**; bodyshove_guards 14/14, ortho_ctrl1_shove 14/14, ortho_second_drag
  8/8, rotate_second_drag 11/11, diagonal_ref_drop 12/12, diagonal_neighbor_bus 10/10,
  diagonal_shove_throughbody 9/9, compact_escape_stub 8/8, compact_named_crossbar 13/13, rotate_body_route
  7/7, exit_stub_staircase 20/20, relay_manhattanize/reanchor, drag_* / backbone / loop / reversal suites.
- `test_fluid_editing` FE8 is a **pre-existing** arc-drag failure (RED on baseline too, does not touch
  wiring) — unchanged by this fix.

## Deferred

The `#net1` rail's mid-span crossing of the `#net2` crossbar at (−50,−170) — a 4-way crossing, not an
electrical short (partition-verified). Same class as 0136 defect 2 (`neighbor-net-riser-near-miss`). A
neighbour-aware crossbar *stacking* (à la 0138) that avoids even the visual crossing is out of scope here.
