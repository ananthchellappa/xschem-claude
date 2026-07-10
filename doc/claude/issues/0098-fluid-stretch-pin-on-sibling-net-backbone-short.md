# 0098 — fluid connected-stretch lands a device pin mid-span on its SIBLING pin's net backbone → device self-short ("loop")

**Branch:** fluid-editing   **Status:** FIXED (route-around, Option A) + facet B (un-gate under rotation);
RED-first regression tests (horizontal + vertical), full fluid/rotate suite green, netlists byte-identical,
valgrind-clean. UNCOMMITTED.
**Fixture:** `tests/headless/fixture_0098_pre.sch` (distilled from the user session; = the settled
pre-final-gesture state) and the user's `tests/from_user/before_7.sch` → `after_16.sch`.
**Repro launch (user):** `FLUID_TRACE=/tmp/fltrace_7_8_13.log src/xschem --script src/cadence_style_rc --logdir /tmp`
**Tests:** `tests/headless/test_fluid_sibling_pin_backbone_short_0098.tcl` (horizontal backbone, vertaxis==1)
+ `tests/headless/test_fluid_backbone_short_vertical_0098.tcl` (vertical backbone, vertaxis==0). Both
X-required, self-skip under `--nogui`.
**Related:** [0094](0094-fluid-group-drag-offpin-lands-foreign-backbone-short-loop.md) (pin lands on a
foreign backbone — same *class*, but there the whole-backbone slide de-shorts; here it can't),
[0096](0096-fluid-reroute-reversal-near-shorts-moved-body.md) (straighten reversal-collapse partition
guard), [rotate_keep_connected_stretch spec](../specs/rotate_keep_connected_stretch.md) (facet B below).

## Name (short)
**"sibling-pin-on-backbone self-short"** — a connected stretch drops one device pin exactly mid-span on
the *other* pin's net wire, and no 2-segment L can route around it, so the device shorts to itself.

## Gesture
Cadence `m` **connected stretch** of **R18** (a `devices/res`, flip=1). From the distilled pre-gesture
state R18 is at **(-40,-120)**:
- pin **P** (idx 0) at **(-40,-150)** → **#net3** — a horizontal backbone `N -320 -160 -40 -160`
  whose left end **(-320,-160) is C12.m**; P's short riser drops onto it.
- pin **M** (idx 1) at **(-40,-90)** → **#net1** — drops to `N -400 -80 -40 -80`.

Drag R18 by **(-20,-70)** → R18 to **(-60,-190)**: **P(-60,-220)**, **M(-60,-160)**.

## Symptom
Saved result (`after_16.sch`, reproduced byte-for-byte by the test) — **both R18 pins on #net1**:
```
N -60 -160 -60 -80  {lab=#net1}
N -60 -220 -60 -160 {lab=#net1}   <- P's riser doubles back down onto M's junction ("the loop")
N -320 -160 -60 -160 {lab=#net1}  <- WAS #net3; M's pin sits mid-span on it -> merge
N -400 -80 -60 -80  {lab=#net1}
C {devices/res} -60 -190 0 1 {name=R18 ...}
```
`fluid_check_device_merge()` prints the diagnosis at END and does nothing about it:
```
fluid_editing INVARIANT (P2 device): instance 'R18' pins 0,1 were on distinct nets
('#net3','#net1'), now both on '#net1' after move -- device short/merge
```

## Root cause
When R18 lands at (-60,-190), **M's new pin (-60,-160) falls exactly MID-SPAN on P's #net3 backbone**
`[-320 -160 -40 -160]` (that row spans x∈[-320,-40] at y=-160; M is at x=-60, inside it). The pin
physically coincides with foreign copper → the two nets merge. It is **not** a follow-wire *leg* crossing
a pin — it is the pin landing on pre-existing stationary copper — so every layer that guards routing legs
is blind to it:

1. **Elbow hazard picker** (`fluid_ml_hazards`, move.c:3858). It routes each pin's OWN follow-wire and
   scores whether *those legs* plow a co-moving pin / foreign pin / stray wire. Both follow-wires are laid
   cleanly (trace: `elbow wire=10 h0=0x0`). The backbone is neither pin's follow-wire, so nothing flags M
   sitting on it.

2. **P2 3-attempt safety net** (move.c:5388-6008). All three attempts (diagonal decomposition → single
   diagonal → rigid relay) compute `fluid_partition_changed()==4` and roll back; the last resort
   (move.c:5972 `kept ortho attempt-1 result`) **commits the shorted geometry** because no attempt is clean.

3. **`fluid_ripup_foreign_pin_short`** (move.c:3350) — the pass *designed* for "a moved pin merged with a
   sibling" — can't fix THIS one. Its only tool is *sliding the whole collinear backbone onto the other
   pin's line* (y=-160 → y=-220). But **C12 pins #net3 at y=-160 (C12.m) and its OTHER net at y=-220
   (C12.p)**, so the slide just swaps the short from M onto C12.p → the post-slide partition still differs →
   it reverts (silently; no `ripup:` trace line). The comment at move.c:3458 already flags this: *"Route-
   around is deferred."*

4. **`fluid_straighten_reversals`** (move.c:2941) runs on the already-shorted geometry; its `fluid_part_equal`
   check is against the **straighten-ENTRY** partition (itself already merged), so it cannot detect or undo
   the pre-existing short — it only reshapes within it (`slid jog wire=12 x->-60`).

**Why no 2-segment L works.** P(-60,-220) is directly *above* M(-60,-160) on the same column. #net3 must
reach P from C12.m(-320,-160). Any L that comes down column x=-60 passes through M; any route along y=-220
hits **C12.p(-320,-220)**. A clean path exists only as a **3-segment staircase** (e.g. `-320,-160 → -70,-160
→ -70,-220 → -60,-220`), which the follow-wire **L-router cannot express**. So the short is genuinely
unroutable by the current 2-segment machinery — the fix requires a route-around detour (retract the backbone
short of M and bend, or add the third segment).

## Facet B — ALT-R during the `m` stretch (what the user also noticed)
When the user presses **ALT-R** mid-stretch, `move_rot != 0`, which gates OFF the entire END cleanup block
(`fluid_ripup_foreign_pin_short` + `fluid_remove_redundant_loops` + straighten), move.c:5814. Phase 4b of the
rotate spec deferred these under rotation ("reshape/delete copper, riskier under rotation"). Trace:
`FLTRACE fluid-block: SKIPPED (fluid=1 stretch=1 rot=1 flip=0)`. This is a *separate* gap: a rotate-during-
stretch can't even *attempt* de-shorting. It did **not** cause `after_16.sch` (that final gesture is rot=0),
but it is the behaviour the user hit with ALT-R and worth closing once the route-around exists — the delete-
only, partition-verified passes are safe to run under rotation (their guards are geometric, not rot-gated).

## Fix (implemented — Option A, route-around)
New helper **`fluid_jog_pin_off_backbone(qx, qy, vertaxis)`** in `move.c`, called from
`fluid_ripup_foreign_pin_short` **when the whole-backbone slide is declined**. When the landed pin Q sits
MID-LINE on the backbone (the backbone extends to BOTH sides of Q along its axis), it JOGs the backbone one
grid AROUND Q's pin: clip every backbone wire away from a one-grid gap `[qx-grid, qx+grid]` centred on Q
(retract/split), then bridge the gap with a **3-segment bump** on whichever perpendicular side clears. Both
sides are tried; the bump is KEPT only if `fluid_partition_changed()==0` (the START pin-partition is
restored) — otherwise every touched wire is reverted (coords restored + added wires dropped via
`wire_delete_compact`). So it is **add/reshape-and-verify**: it can only de-short or decline, never corrupt.
`vertaxis==1` bumps in y (horizontal backbone); `vertaxis==0` bumps in x (vertical). The straightener then
tidies the bump into a clean staircase.

Result for the repro (`after_16` scene): `#net3` routes `P(-60,-220)→(-60,-170)→(-70,-170)→(-70,-160)→
(-320,-160)=C12.m` — AROUND M — and `#net1` is `M(-60,-160)→(-60,-80)→(-400,-80)`. R18 lands at (-60,-190)
AND stays unshorted (P=net3, M=net1).

**Facet B (implemented):** the END de-short block gate was `move_rot==0 && move_flip==0`; it now runs the
DE-SHORT passes (`fluid_ripup_foreign_pin_short` incl. the jog, and `fluid_remove_redundant_loops` — both
partition-VERIFY) under rotation too, so ALT-R during an `m` stretch can de-short. Only the AESTHETIC
reshapers (`fluid_straighten_reversals`, `fluid_collapse_axis_overshoot_stub`) stay pinned to the pure-
translation path (`rotfree`), per the Phase-4b conservatism (they slide/extend copper to tidy, not to
de-short).

**Gating / safety:** the whole path is reached only under `fluid_editing` (default OFF), so netlist output is
byte-identical when off (verified: demo/bcd/rom8k SPICE identical to pristine). Full fluid + rotate headless
suite green (the one `test_fluid_editing` FE8 arc failure is PRE-EXISTING on pristine HEAD). Valgrind: no
leaks attributed to the jog/ripup path.

### Considered and not taken
- **Decline-to-safe** (refuse the stretch + warn when `fluid_check_device_merge()>0`): simpler, but refuses a
  move the user clearly wanted; the route-around keeps the move AND the connectivity, which the clean 3-seg
  path (proved to exist above) makes achievable.

## Reproduction (deterministic, headless-under-X)
`tests/headless/test_fluid_sibling_pin_backbone_short_0098.tcl` loads `fixture_0098_pre.sch`, drives the
cadence `m` connected stretch by (-20,-70), and asserts R18's two pins stay on distinct nets. Currently RED
(`P=net1 M=net1`), and saving reproduces `after_16.sch` byte-for-byte in the R18 region.
