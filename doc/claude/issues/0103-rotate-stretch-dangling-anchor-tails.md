# 0103 — rotate during connected stretch leaves dangling tails at the pristine anchors

**Status: FIXED (uncommitted). Test `tests/headless/test_rotate_stretch_dangling_0103.tcl`
77/77 GREEN (rot90/flip/rot180/rot270, ±dx drops; dangle-SET-subset + stub-survival +
placement anti-vacuity + structural partition asserts), sabotage-verified RED with the
prune disabled, valgrind memcheck clean; 0099 (21), 0100 (51), wireedit aggregate, fluid
0088/0089/0096/0098 and `run_regression.tcl` all pass. Adversarially reviewed
(wf_8b4088de, 5 lenses): 1 code finding fixed (added the 0091 `fluid_mark_user_protected`
"selection wins" guard — novelty-span alone could match a user-selected pin-free wire
whose rotated tip lands on a vacated anchor, invisible to the pin-partition verify),
2 test findings fixed (count-only dangle assert → set-subset + stub-survival; 8/9 cases
were no-op-vacuous → per-case R18 landing/rot/flip asserts).**

## Fix (src/move.c)
- New `fluid_prune_anchor_tails()` (defined after `fluid_collapse_axis_overshoot_stub`),
  called from the END-only fluid cleanup block under `if(!rotfree)`. Delete-only prune:
  novelty-span-scoped auto copper with exactly one free end (touch-deg 0, off-pin) whose
  coordinate was a START wire ENDPOINT with START touch-degree >= 2 (a drag-orphaned attach
  point, never a pre-existing user dangler tip), kept end still a junction (deg >= 2 without
  the tail), each doom pin-partition-verified via `fluid_loop_partition(doomed,..)` vs pass
  entry before committing.
- New helper `fluid_start_endpoint_at()`. NOTE: `coord_was_grabbed()` is unusable for this
  scope — its `stretch_grabbed_xy` snapshot is re-taken by the mid-gesture follow-set
  regrabs, so it holds the follow wires' MOVED coords (x=-110 after the first +10 MOTION),
  never the pristine anchors. That was the first (failed) implementation attempt.
- Bonus (known touch()-on-unordered-wire gotcha, both reachable under rotation):
  `fluid_jog_pin_off_backbone` now `order_wire_coords()`s every storeobject'd bump/straddle
  segment (one bump leg per jog was always stored against coordinate order); the
  `fluid_remove_redundant_loops` H4 rollback re-store orders each restored wire.

## Name (short)
"Rotate-stretch dangling anchor tails": after ALT-R during a connected `m` stretch,
the follow-wire elbows keep a redundant second leg reaching back to the pin's
*pristine pre-move* attach point, which by then is a bare spot — the stationary
backbone/rail endpoint has already slid to the elbow corner column. The leg
survives move END and save as a dangling stub.

## Repro (user, GUI)
1. `FLUID_TRACE=/tmp/fltrace_7_8_17.log src/xschem --script src/cadence_style_rc --logdir /tmp`
2. Load `tests/from_user/before_7.sch`. Select R18 (vertical res at (-120,-80),
   pins (-120,-110)=#net2 top, (-120,-50)=#net1 bottom).
3. Press `m` (connected stretch), drag a bit, mid-drag ALT-R (rot90), drag more,
   click to place. Saved result: `tests/from_user/after_20.sch`.

## Observed
Electrically CORRECT — both R18 pins reconnect, no short, no tear (0099/0100/0102
machinery works). But two dangling stub wires remain in the saved file:

- `N -190 -40 -120 -40 {lab=#net1}` — elbow horizontal leg from the new junction
  (-190,-40) back to R18's pristine bottom-pin anchor (-120,-40); runs under the
  rotated body, free end touches nothing.
- `N -130 -150 -120 -150 {lab=#net2}` — elbow leg from the new rail junction
  (-130,-150) back to the pristine top-pin rail attach (-120,-150), free end bare.

Both free ends are *former junctions*: degree 2 at gesture START, degree 1 (no pin)
at END. "Broken wires" appearance reported by the user.

## Mechanism (from trace /tmp/fltrace_7_8_17.log)
- Post-rotation previews compute follow-wire elbows anchored at the PRISTINE
  premove attach point (the 0100 fix: release is a pure function of the pristine
  snapshot + total delta), e.g.
  `elbow: wire=6 ... r1=(-120,-150) r2=(-130,-10)` and
  `elbow: wire=12 ... r1=(-190,-10) r2=(-120,-40)`.
- Meanwhile the stationary rail/backbone endpoint ends up AT the elbow corner
  column (`[-320,-150,-130,-150]`, `[-400,-40,-190,-40]`), so the elbow's second
  leg (corner → pristine anchor) duplicates nothing and dangles.
- Every post-rotation preview logs `fluid-block: SKIPPED (fluid=1 stretch=1 rot=1
  flip=0)` — a rot-gated cleanup block; the END orphan passes
  (`remove_move_orphan_wires`, orphan-retract) either don't run under rotation or
  don't own this tail shape. END ACCEPTs with partition_changed=0 (the tails are
  same-net, so no partition signal) and the stubs are saved.

## Why existing passes miss it
The tails are same-net redundant copper: they change no pin partition (so the
0098/0102 short/rollback ladders see a clean result) and their free ends are
drag-orphaned former junctions, exactly the shape the orphan-retract pass was
built for — but that pass (or its enclosing fluid block) is gated off under
rot!=0. See code-reading notes in the fix commit / test for exact gates.

## Fix direction
Un-gate (or add a rotation-aware equivalent of) the drag-orphaned dangling-end
retract at move END: a free end that was a junction at START, is degree-1 now,
sits on no pin, and belongs to a wire this gesture rerouted, gets retracted to
its nearest junction / deleted. Must NOT touch pre-existing user dangler tips
(START degree <= 1 protection already exists in the pass).

## Artifacts
- fixture: `tests/from_user/before_7.sch`
- user-saved bad result: `tests/from_user/after_20.sch`
- trace: `/tmp/fltrace_7_8_17.log` (also grep `fluid-block: SKIPPED`)
- prior art: 0094 (prune novel orphan stub), 0098 facet B (un-gating de-short
  under rotation), 0100 (pristine premove anchors), 0102 (relay safety net)
