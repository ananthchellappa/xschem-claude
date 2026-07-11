# 0108 — relay re-anchors to stale feet: Manhattanized relay keeps detour routes + stale copper; rot180 relay stays diagonal

**Status: FIXED** (src/move.c, re-anchor phase + stale-feed prune inside
`fluid_manhattanize_relay_diagonals`)

## Name / class

**Stale-anchor relay routes**: when the accept ladder ends in the rigid diagonal relay, each
follow wire runs pin → *the pin's own pre-move foot* — a point whose only purpose was serving
the OLD pin position. The 0107 END pass Manhattanized that diagonal into an L **keeping the
stale foot as the far endpoint**, so the saved route detours through the vacated location and
the stale feed copper behind the foot survives. Two user-visible symptoms, one root:

1. **Detour + stale copper** (before_8.sch, plain LMB drag R18 NW by (-140,-100) →
   after_25.sch): a dead `[0,-40 0,0]` stub is kept on #net1 and #net3 is routed
   left-pin → down to the old y=0 row → east to the old `[-80,0]` riser foot → up the old
   riser — a huge U-turn. Total copper ~1900 vs ~1140 for the user's hand-drawn
   preferred_25.sch.
2. **rot180 relay saved raw diagonals** (same fixture, 'm' connected stretch + 2× ALT-R,
   e.g. drops (0,-80) or (60,-60)): rot180 swaps the pins, so the two stale-anchor Ls must
   CROSS each other's route — BOTH 0107 orientations verify dirty, the pass declines, and the
   raw diagonals are saved.

## Trace forensics (FLUID_TRACE=/tmp/fltrace_7_8_21.log)

Every RUBBER step and the END run the same ladder: attempt 0 (2-leg ortho) and attempt 1
(single ortho) both short — the two follow routes share the anchors' y=0 row, bridging the
stale feet (`[-80,0]`↔`[0,0]` corridor touches the `[0,-40 0,0]` stub) or, near the backbone
row, the pin row lands ON the backbone — so partition_changed=4 rolls both back and attempt 2
(rigid diagonal relay) is ACCEPTED. At END the 0107 pass converted the two diagonals to Ls via
the stale feet: `(-210,-100)→(-210,0)→(-80,0)` and `(-150,-100)→(0,-100)→(0,-40)`, keeping the
stub and riser. The relay path (leg_ortho==0) also skips the whole END cleanup block, so
nothing pruned or straightened the result.

## Fix (src/move.c)

`fluid_manhattanize_relay_diagonals()` now tries, per relay diagonal (pin P → anchor A),
best candidate first:

1. **Re-anchor (new)**: for every same-net wire (by `wire[].node`, non-bus, axis-aligned),
   compute the closest point Q to P; candidates are distance-ordered — a straight run when P
   and Q align, else the two L orientations via (P.x,Q.y) / (Q.x,P.y). Each candidate is
   pre-checked against welding pin-LESS foreign copper (`fluid_seg_welds_foreign` — the
   pin-indexed partition verify is blind to a lab= supply stub with no device pin) and then
   committed only if `fluid_partition_changed()==0`, else reverted exactly
   (`fluid_try_reanchor`).
2. **0107 fallback**: the pin→anchor L, V-first then H-first (unchanged).
3. **Last resort**: keep the diagonal (electrically correct beats pretty).

After any change: trim/collapse, then **stale-feed prune** — dangling ends that were JUNCTIONS
at START (live touch-degree 0, on no pin, START degree ≥ 2, so a user's pre-existing dangler
tip with START degree ≤ 1 is never touched) are retracted/deleted to fixpoint via
`fluid_retract_orphan_tail`, each action partition-verified; user-protected (0091) and
explicit-lab copper excluded. This eats the abandoned stub, the old riser, and retracts the
backbone overhang back to the new T. Only follow-net copper can newly dangle (END re-applies
the total delta from the pristine snapshot), so no extra net scoping is needed.

On the repro the saved result is now: #net3 = row trimmed to `[-320,-150 -210,-150]` + direct
drop `[-210,-150 -210,-100]`; #net1 = backbone trimmed to `[-400,-40 -150,-40]` + direct riser
`[-150,-100 -150,-40]`. Total copper ~1120 — slightly better than the hand-drawn
preferred_25.sch (~1140). Saved as tests/from_user/after_25_fixed.sch. Both rot180 diagonal
cases now save fully Manhattan with the partition preserved.

Known separate class (NOT this issue, unchanged pre/post): a rot180 drop that lands the pin
row exactly ON the foreign backbone row (e.g. (-60,-40), (-160,-40)) physically places pins on
live copper — the ladder's "intentional landing" tolerance keeps the merged result.

## Side effect: 0104 xfail promoted

The 0104 test's `case_known_tail` (rot180-ip (-30,70)) tolerated a known 0103-class relay tail
at (-120,-40) and carried an xfail tripwire "if this FAILS: relay path was fixed, promote to
full case". The 0108 prune removes that tail; the tripwire fired and the case was promoted
back to a full `case` (test_rotate_stretch_short_0104.tcl, now 76/76).

## Verification

- `tests/headless/test_fluid_relay_reanchor_0108.tcl`: 27/27 PASS. Case A (plain NW drag)
  asserts no diagonals, distinct nets, stale feet bare, no new dangling endpoints, total
  copper ≤ 1250; sabotage-RED (re-anchor + prune disabled): 4 FAILs, copper 1860. Cases B/C/D
  (rot180 'm' stretch, drops (-130,-90)/(0,-80)/(60,-60)): C and D were RED pre-fix (1 raw
  diagonal each, found by a 10-delta sweep), all green post-fix.
- Battery green: 0107 (5/5), 0105, 0106, 0098×2, 0088, 0089, 0096, 0099, 0100, 0103,
  0104 (promoted, 76/76), reconnect (17/17), wireedit suite (ALL PASS), run_regression 0 fail
  (needs `XSCHEM_SHAREDIR=<repo>/src PATH=<repo>/src:$PATH` when run from the source tree).
- Pre-existing, unrelated: test_fluid_editing FE8 (arc control-point drag) fails identically
  on HEAD without 0107/0108; X-only, self-skips under --nogui.
