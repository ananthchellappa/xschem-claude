# 0137 — fluid connected-drag: minimum-copper compaction (moved-pin escape-stub overshoot)

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** wiring / fluid connected-drag (`src/move.c`, `fluid_straighten_reversals`) — see `doc/claude/WIRING.md`
**Fixture:** `tests/from_user/before_41.sch`. Test `tests/headless/test_fluid_compact_escape_stub_0137.tcl`.

## Principle (spec)

**Every move must leave MINIMUM copper, cleanly.** Meeting the escape/no-body-cross invariants (P3/P5)
is necessary but not sufficient — the route must also not carry copper the gesture could remove without
changing connectivity or violating an invariant. This issue fixes the first concrete violation found:
a moved pin's **escape stub** left stretched far beyond the minimal one-grid escape.

## Reproduction (user-reported, trace-verified)

Fixture `before_41.sch`: `res` R1 @ (100,100). Its TOP pin `P` (100,70) escapes **NORTH** `(0,-1)`; the
net routes up-and-over to a destination BELOW/SOUTH at (130,90) through the minimal one-grid escape:

```
P(100,70) -> (100,60) [escape stub, 1 grid north] -> (130,60) [over] -> (130,90) [down to dest]
copper = 10 + 30 + 30 = 70                             (minimal, P3-respecting)
```

Gesture: connected-drag R1 UP by D (`select_at` the instance, drag, release), then DOWN by D back to
origin — a real multi-motion X gesture (headless `move_objects` does not move the instance). Result
(current binary, D=30):

```
after up30/dn30:  #net1 100,30-100,70   100,30-130,30   130,30-130,90     copper = 40+30+60 = 130
```

The escape stub is stretched to **40** and the down-leg to **60** — excess **2·D**, growing without
bound (D=60 → copper 190). Connected, no short: a pure **minimum-copper / beautification** defect. The
mirror case (an EAST-escape pin, `res` rot1, dest west) reproduces identically and is fixed by the same
code (the helper is axis-symmetric).

## Root cause (trace, not static)

The drag pipeline is **PUSH-only**:

- **Approach** (drag the instance so its pin moves TOWARD its own perpendicular jog): the push-through
  slide `fluid_slide_push_through` shoves the jog out along the escape normal, keeping the escape ≥ 1
  grid. Correct — the user's "drag up is perfect".
- **Retreat** (drag the instance so its pin moves AWAY): nothing PULLS the jog back in; the escape stub
  simply stretches (`slide: … PUSH-THROUGH …` fires only on approach).

Then each gesture's START snapshot is the **previous gesture's output**, so the stretched stub is now
pre-existing copper. The two passes that could reclaim it both skip it:

- `fluid_straighten_reversals` — gate `!fluid_wire_is_novel_span(kd)` (move.c ~3589): only reshapes a jog
  THIS drag created; the stub is no longer novel-span.
- `fluid_collapse_axis_overshoot_stub` — gate START-deg==0 (dangle only); the stub is connected.

So `changed=0` and the overshoot is frozen in. Crucially, `fluid_straighten_reversals` ALREADY classifies
this exact shape as a same-side **reversal** whose nearer neighbour lands on the moved pin, and its 0111
pin-landing reschedule already slides it to the one-grid escape row (far target first — blocked by the
pin's own body — then `pin + grid*normal`), with an exact-revert partition/foreign/body verify. It just
never *sees* the wire.

## Fix

A narrow predicate `fluid_jog_is_moved_pin_escape_overshoot(kd)` (move.c, just before
`fluid_straighten_reversals`) re-admits EXACTLY this shape into the pass; the straighten gate becomes

```c
if(!fluid_wire_is_novel_span(kd) && !fluid_jog_is_moved_pin_escape_overshoot(kd)) continue;
```

The predicate returns 1 only when **all** hold (each negation → 0 → straighten byte-identical):

- `fluid_editing` on; **rot == flip == 0** (mirrors straighten's 0111 pin-landing gate at ~3672 — under
  rotation straighten slides onto the pin, collapsing the escape, which the verify would NOT decline);
- `kd` is a plain (non-bus, non-explicit-lab) axis jog with two distinct perpendicular cornered
  neighbours;
- the neighbours are on the **same side** of `kd` — a REVERSAL (its near slide only ever SHORTENS, safe
  by construction; staircases, which EXTEND, are excluded);
- the **nearer** neighbour's far end lands EXACTLY on a **MOVED** pin (`fluid_moving_pin_normal` ≠ 0 —
  this is the P7 guard: an unrelated jog near a *stationary* pin is never touched);
- that pin's outward lead normal is collinear with, and points OUTWARD along, the stub;
- the stub is longer than one grid (a real overshoot).

The verified slide is entirely straighten's existing machinery — **never worse** by the same exact-revert
guarantee the pass already carries. No new mutation path, no new verify.

### Result

`up30/dn30` (and every D) → copper **70**, route `100,60-100,70` + `100,60-130,60` + `130,60-130,90`
(the minimal escape). Connected, no diagonal, partition intact.

## Verification

- New test `test_fluid_compact_escape_stub_0137.tcl`: **RED on baseline** (4 compaction checks fail,
  copper 130), **GREEN after fix** (8/8). Real-X; self-skips without DISPLAY. Sweep D∈{10..60}: all
  compact to 70 (was 90..190). EAST-escape mirror (res rot1) also compacts (trace `slid jog … reversal
  collapse`).
- Regression: **wireedit 57/57**; all `test_fluid_*` gesture suites green (bodyshove_guards 14/14,
  ortho_ctrl1_shove 14/14, diagonal_ref_drop 12/12, diagonal_neighbor_bus 10/10, shove_throughbody 9/9,
  jog_separated_trunk 0136, exit_stub_staircase 20/20, rotate_body_route 7/7, rotate_second_drag 11/11,
  relay_manhattanize/reanchor, drag_through_anchor 20/20, …). `test_fluid_editing` FE8 is a PRE-EXISTING
  arc-drag failure (confirmed identical with the fix stashed) — unrelated.

## Known limits / follow-ups

- Scope is the moved-pin escape-stub overshoot (the reversal shape). Other min-copper residues (a
  multi-jog staircase whose whole run could shift, a stranded far-leg) are NOT yet reclaimed — extend the
  predicate family as new cases surface, RED-first.
- The reversal near-slide path in straighten carries no stationary-body guard (`cext==0`); for an
  escape-stub the compacted positions are inward of the original (within the pin's escape corridor), so a
  body-clear original stays body-clear. If a future shape violates that, add the body guard to the
  reclaim path only.
