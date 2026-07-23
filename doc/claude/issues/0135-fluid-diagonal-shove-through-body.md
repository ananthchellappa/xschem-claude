# 0135 — fluid diagonal drag: body-shove rebuilds a moved input pin's feed as a through-body U

**Status: FIXED (defect D1). Branch `fluid-editing`.**

## Reproduction

- Fixture `tests/from_user/before_39.sch`; buggy save `tests/from_user/after_39.sch`; action log
  `/tmp/Xschem.log.3`; fluid trace `/tmp/xschem_fltrace_97951.log` (empty — GUI freopen'd stderr;
  re-captured via the callback replay below).
- Gesture: LMB connected-drag instance `x1` (`SANDBOX/solar_ctl`, rot1 @ origin 80,10) by delta
  **(−10,+20)** = SW diagonal, then save. Equivalent replay: `select_at 70 -20; move_objects -10 20`
  (headless `move_objects` does NOT move the instance — the interactive multi-motion gesture is
  required; use the real-X callback replay in the test).
- User report: "Net connected to LED pin of instance ends up going through instance body." (The
  body-threading wire is actually REF's net #net2, the sibling north-edge input pin — same shape.)

## Geometry

solar_ctl rot1: two north-edge input pins on parallel buses 1 grid apart (as in 0134). After the
(−10,+20) move: REF (70,−140)→(60,−120) net #net2; LED (90,−140)→(80,−120) net #net1. x1 pin-inclusive
body box world ≈ x∈[37.5,90], y∈[−122.5,92.5]. after_39 #net2 = `60 -120 60 100` + `-60 100 60 100` +
`-60 0 -60 100` — REF plunges from its north pin straight DOWN through the whole body to y=100.

## Root cause (trace-verified, not static)

Accepted path = END **attempt=0 leg-split** (nlegs=2, `diag_relay=0`), partition clean. At the END,
BEFORE the shove, REF/#net2 is a **clean L**: `-60 -120 60 -120` + `-60 -120 -60 0` (trace L90–94).
Then the per-gesture `fluid_shove_body_crossing_backbone`, run on this diagonal path via the **0134
hunk-2 per-axis spoof** (move.c ~8779), mis-fires (trace L102):

```
bodyshove: pin=(60,-120) pc=-120 run=[-60 60] -> ct=100 span=[-60 60] corners=1 SHOVED
```

- The **y-run** (deltay spoofed to +20, deltax=0) makes `xmove=0`, `dirpos = (deltay>0) = 1`.
- REF's HORIZONTAL escape feed `-60 -120 60 -120` (at row y=−120) is a same-net run whose along-axis
  (x) overlap with the body [37.5,90] is 22.5 > 1 grid → the §11.9d one-sided-inward-feed gate accepts
  it as shoveable.
- `ct = dirpos ? grid_above(by2=92.5) : … = 100` — the SOUTH edge, "one grid ahead of the (spoofed +y)
  motion". So the rebuild collapses the feed and lays a vertical backbone at REF's column x=60 from the
  north pin down to y=100: the through-body U.

The single-axis **spoof** is the trap: it makes the shove model REF as moving purely +y (south), so
`dirpos` picks the SOUTH body edge — but REF's real lead escape normal is NORTH (0,−1). The shove drags
the feed ACROSS the body to the far side. LED (same north normal, pin nearer the east edge) got a clean
north-first exit and was untouched — the asymmetry is why only REF threads the body.

**Regression origin:** this over-fire is reachable only because 0134 hunk-2 runs the shove on diagonal
drags accepted at attempt=0 (pre-0134 the shove pure-axis-gated OFF a diagonal delta). The comment at
move.c ~8770 documents that this path "became reachable once the 0134 exit-stub foreign-net guard keeps
the leg-split clean."

## Fix (defect D1)

A decline gate inside `fluid_shove_body_crossing_backbone` (move.c ~7074, right after the through-run
both/one-sided gate):

```c
if(!bad) {
  double enx, eny, en, rel;
  get_pin_escape_normal(i, p, &enx, &eny);
  en  = xmove ? enx : eny;         /* escape component on the shove axis */
  rel = dirpos ? 1.0 : -1.0;       /* backbone relocation direction (toward ct) */
  if(en != 0.0 && en * rel < 0.0) bad = 1;   /* shove would drag the feed across the body — DECLINE */
}
```

If the pin's outward escape normal has a component ALONG the shove axis that OPPOSES the relocation
direction, the rebuilt backbone would land on the FAR side of the body from where the feed should
escape — DECLINE and keep the accepted route (never worse). The legitimate perpendicular-backbone
shoves (after_35/36 CTRL1, the 0134 x=140 column, all guards-test shapes) have their escape normal
PERPENDICULAR to the shove axis (component 0), so the gate never touches them. Uses the issue-0134
lead-geometry normal via `get_pin_escape_normal` (the shove call sites are fluid-only); an ambiguous
(0,0) normal → en=0 → gate no-ops (safe fallback). Applies to BOTH spoof call sites (diag_relay §11.9f
and pure-ortho 0134 hunk-2) since it lives inside the shove.

Post-fix REF routes the clean L `-60 -120 60 -120` + `-60 -120 -60 0` (the pre-shove accepted route);
trace: `bodyshove: pin=(60,-120) escape=(0,-1) rel=1 -- shove OPPOSES escape, DECLINE`.

## Not fixed (defect D2, route-quality, out of scope)

REF's declined feed still exits WEST (perpendicular), grazing the body top edge by 2.5, instead of NORTH
along its lead escape normal (0,−1). LED exited north cleanly; the two-leg decomposition does not route
REF's feed along its now-correct normal. Dissolving D2 (route north-first) would remove D1 at the source.

## Verification

RED test `tests/headless/test_fluid_diagonal_shove_throughbody_0135.tcl` (real-X callback replay,
self-skips headless): D1 through-body-vertical check RED pre-fix, GREEN post-fix. Regression:
ctrl1_shove_0132 14/14 (shove STILL fires for CTRL1), bodyshove_guards_0132 14/14, 0134 neighbor_bus
10/10, ref_drop_0132 12/12, rotate_body_route_0130 7/7, ortho/rotate_second_0132, exit_stub_0111 20/20,
wireedit 57/57; test_fluid_editing only the pre-existing FE8 fails.
