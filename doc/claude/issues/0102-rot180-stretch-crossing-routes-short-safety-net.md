# 0102 — rot180/270 during connected stretch: crossing follow-routes short; P2 safety net now armed under rotation

**Status: FIXED (uncommitted). Was the "documented known limitation" of 0099/0100 — the user hit it
in practice (before_7.sch → after_19.sch), so it is deferred no longer.**

## Repro

`tests/from_user/before_7.sch` → `after_19.sch`. Launch
`FLUID_TRACE=/tmp/fltrace_7_8_16.log src/xschem --script src/cadence_style_rc --logdir /tmp`.
Select R18, `m`, drag, **ALT-R twice** (rot180 in-place), move a bit, click to place at Δ(-50,80).

Symptom (saved after_19): R18.P, R18.M and C12's bottom pin ALL merged onto #net1 — a hard short.
Trace: every post-rotate elbow pass prints `h0=0x8 h1=0x2` for wire 6 (R18.P's follow) — BOTH L
orientations hazardous — and `fluid-block: SKIPPED (rot=2)`; no `ACCEPT/ROLLBACK` lines because the
P2 safety net never armed.

## Root cause

rot180 (and 270) swap R18's pins across the pivot, so P's follow route must cross either M's new
position (MOVPIN hazard, `0x2`) or M's net backbone end at (-120,-40) (STRAY T-touch, `0x8`). No
clean 2-leg L exists — the 0099/0100 elbow work is a *chooser*, it cannot invent a 3-segment
detour. The picker keeps the lower-severity orientation (STRAY) and lays the leg that T-touches the
#net1 backbone end → merge → short, and downstream cleanup consolidates the mess.

The machinery to catch exactly this already existed: the **P2 safety net** (issues 0081/0085) —
attempt loop with a pristine snapshot: `fluid_partition_changed()` after the composite route,
rollback, retry, final fallback = **rigid diagonal relay** (`leg_ortho=0`: place_moved_wire
translates the moved endpoint; the wire goes diagonal, lays no elbow copper, so it cannot merge —
xschem connectivity is endpoint/T-based, a diagonal crossing copper mid-span does not connect).
But its snapshot (`leg_snapped`) only armed in the nlegs==2 diagonal-decomposition branch, gated
`move_rot==0 && move_flip==0`. Under rotation: attempt 0 only, accepted sight-unseen.

## Fix part 2 (review wf_49325abb F2, live-confirmed): dx==0 drops — degenerate relay bend

The rigid relay's "a diagonal cannot merge" premise FAILS when the drop keeps anchor and rotated
pin COLLINEAR (dx==0 on this fixture — including the most natural gesture: `m`, ALT-R ×2, click in
place): the relay wire degenerates to an axis-aligned segment that SPANS the swapped sibling pin
(pin-on-span merges), every attempt stays dirty, never-worse kept the shorted ortho route. Fixed in
the commit WIRE case: when a relayed partial-selected wire ends axis-aligned AND a pin (co-moving
pins tested at their rotatelocal-aware post-move position) lies strictly inside its span, BEND it
at an off-axis midpoint (one grid step perpendicular, grid-snapped mid) into two true diagonals.
The attempt-loop partition check remains the arbiter (a dirty bend rolls back as before).

⚠ Gotcha found the hard way: the storeobject'd second half MUST get `order_wire_points()` — an
UNORDERED wire resolves fine in the wire graph (wire .node correct, chain intact) but the
INSTANCE-PIN attach misses it (pin lands on a fresh #net while every wire shows the right net;
`end2=0` on the unordered wire is the tell). The elbow code always orders after storeobject; so
must every new-wire writer.

## Fix part 1 (1 edit, src/move.c ~5517)

Arm the same `leg_snap` snapshot for a rotated/flipped fluid stretch (`fluid_editing &&
stretch_select && orthogonal_wiring && (move_rot || move_flip)`; nlegs stays 1). Flow: attempt 0
(ortho elbow route) → partition changed → rollback → attempt 1 (identical single ortho pass, fails
identically — one redundant pass on the failing path only) → alt-snapshot + relay armed →
attempt 2 (rigid diagonal relay) → partition preserved → accept. If even the relay is dirty, the
existing attempt-2 branch restores the ortho result (never-worse guarantee). A clean rotated route
(rot90/flip, the 0099/0100 cases) breaks after attempt 0 — zero behavior change. Translation path
untouched (the new branch requires rot/flip; the decomposition branch requires their absence).

Follow endpoints land exactly on the rotated pins because of the 0100 pivot fixes — the relay
depends on them (pre-0100 the diagonal would tether to a garbage point).

Result geometry (`tests/from_user/after_19_fixed.sch`): two diagonals, P (-170,30)→(-120,-150) on
#net2, M (-170,-30)→(-120,-40) on #net1. Ugly but CORRECT — P1/P2 outrank aesthetics (conflict
order P1=P2 > P3 > P5 > P4 > P7 > P6). Re-routing the diagonals as clean 3-segment manhattan
detours remains Phase 4c quality work.

## Tests

- `test_rotate_stretch_reconnect_0100.tcl` → 51 checks: rot180-ip at the user's exact drop
  (-50,80) + (30,20), rot270-ip, PLUS the dx==0 family (in-place drop 0,0 and dy-only 0,40 — RED
  pre-bend), all hard asserts now (notes removed). RED-first: 5 FAIL pre-arm + 2 FAIL pre-bend;
  sabotage (arm disabled) → rot180 cases FAIL. Partition asserts rewritten STRUCTURAL (P shares a
  C12 pin net; C12's own pins distinct — catches a C12 self-short; M on the v8/backbone subtree;
  P≠M) because auto `#netN` names drift with wire creation order under the relay — literal
  `#net2`/`#net1` asserts false-fail on rot270.
- `test_rotate_stretch_reconnect_0099.tcl` → 21 checks: the rot180/270 global-rotate notes flipped
  to hard structural asserts (same safety net covers plain ROTATE).
- Suites green: rotate_stretch(17), 0098×2, 0088, 0089, 0096, cadence_stretch_move,
  rotate_prompt_object; valgrind 0 errors (snapshot freed per commit — no leak).

## Notes

- rot270 on this fixture routes CLEANLY via the elbow with the 0100 pivots (P straight vertical,
  M H-first L) — only rot180 needs the relay here; the rot270 assert guards regressions.
- The relay path runs on live RUBBER commits too (release==stepwise): mid-drag the user sees the
  same diagonals that will be dropped.

Closes the limitation recorded in `0099-*.md` / `0100-*.md`. Remaining quality gap: Phase 4c
(manhattan detours instead of diagonals; plus the 0101 wire-owner holes).
