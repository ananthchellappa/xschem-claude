# 0135 — fluid diagonal drag: body-shove rebuilds a moved input pin's feed as a through-body U

**Status: FIXED (defects D1 + D2). Branch `fluid-editing`.**

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

## Fixed (defect D2, route-quality)

**Status: FIXED (candidate #1 follow-up, uncommitted at time of writing → see commit).**

### Root cause (trace-verified, not static)

REF's declined feed exited WEST (perpendicular), grazing the body top edge by 2.5, instead of NORTH along
its lead escape normal (0,−1). The workflow's first hypothesis (P6 length veto in `fluid_p6_bias_ml`) was
WRONG — the FLUID_TRACE `p6-DIAG`/`pmw-DIAG` probes showed **P6 is never called for REF's feed**. The true
root: the END re-derives the two-leg (X-then-Y) decomposition from pristine, and after leg-0 the per-gesture
`move_regrab_follow_set` re-selects REF's horizontal feed wire as **`SELECTED` (whole wire, sel==1)**, not
`SELECTED1/2` (endpoint). So leg-1 takes `place_moved_wire`'s **pure-translation `else` branch** (both
endpoints move by the delta) — the elbow / P6 orientation layer is never consulted, and REF's horizontal
orientation is preserved from the fixture (the pre-existing `-60 -140 70 -140` feed, translated +20 to
`-60 -120 60 -120`, now grazing since the body moved under it). LED differs only because its fixture feed
already had a NORTH stub (`90 -150 90 -140`), so it exits north after translation. This is the WIRING §11.9a
class: the diagonal/decomposed path routes some feeds by pure translation, bypassing the elbow/reroute/
exit-stub re-orientation layers.

Note the geometric conflict that makes the naive "route REF north at y=−130" WRONG: REF pin (60,−120) and
LED pin (80,−120) are at the same y; both exit north; the minimal clearance row y=−130 is LED's row, so a
1-grid north slide of REF SHORTS onto LED. The clean escape is y=−140 (clears the body top −122.5, sits one
row past LED).

### Fix (`insert_exit_stubs`, move.c ~2064, gated `fluid_editing`)

Turn the single-grid exit-stub slide into an **outward search** that engages only when the current
pin-incident perpendicular feed leg **grazes/crosses the instance's OWN pin-inclusive body** (`graze =
fluid_seg_crosses_sel_body(px,py,fx,fy)`; a NON-grazing leg keeps `dmax==1` → the historical single-grid
behaviour byte-identical). Walk `d = 1..6` grids along the lead escape normal; per distance:

- still threads the own body (`fluid_seg_crosses_sel_body`) → **continue** (not cleared yet);
- crosses a **STATIONARY** device body (`fluid_seg_crosses_stationary_body`) → **break/DECLINE** — the exit
  stub is a LOCAL beautifier, never detour a feed past another device (this guard is load-bearing: without
  it the search flings R18's grazing P feed 8 grids north past C12 in the 0090 multi-gesture staircase,
  which then cascades and corrupts the route — the regression that drove this guard in);
- shorts a foreign net (`fluid_seg_touches_foreign_lab`, the 0134 guard) → **continue** (a farther row may
  be free — this is what walks REF past LED's y=−130 to y=−140);
- else accept: slide the leg there, drag the far corner + its wires, fill the pin gap with the stub.

Result: REF exits NORTH — stub `60 -120 60 -140` (vertical, the pin's own exempt lead) + west run
`-60 -140 60 -140` (clears the body) + riser `-60 -140 -60 0`; LED untouched at y=−130; no short. This also
DISSOLVES D1 at the source in this fixture (no through-body feed for the shove to see; D1's escape-side
decline remains the safety net if the search declines).

**Why geometric guards, not a mem_snapshot partition verify:** the slide never DISCONNECTS by construction
(the pin gap is filled by the stub and the far corner + every wire on it are dragged together, so the net
stays whole); the only failure mode is a short, exactly what the foreign-lab guard rejects (identical
mechanism to the shipped 0134 single-grid slide). A `mem_snapshot` verify is the wrong tool: `mem_restore_slot()`
`unselect_all()`s, which would strip the instance `.sel` the pin loop iterates on and silently skip every
later pin. The residual gap (a short onto an UNLABELED distinct net, both `lab=""`) is pre-existing / shared
with 0134 and is backstopped at END by the B3 `fluid_check_move_invariants` rollback (`fluid_enforce_invariants`)
and the D1 shove-decline.

### Verification

RED test (extended `test_fluid_diagonal_shove_throughbody_0135.tcl`, 3 new D2 checks): REF's pin-incident
first segment is VERTICAL/NORTH; no wire grazes the body top interior at y=−120. Both RED on the pre-D2
binary (`FAIL: REF first segment ... other end (-60,-120)`), GREEN post-fix (9/9). Regression: 0134
neighbor_bus 10/10, ref_drop_0132 12/12, ctrl1_shove/bodyshove_guards 14/14, rotate_body_route_0130 7/7,
ortho/rotate_second_0132, exit_stub_0111 20/20, **wireedit 57/57** (the 0090 staircase regression that the
stationary-body BREAK closed), test_fluid_editing only pre-existing FE8. WIRING.md §11.9a.

### Adversarial review (workflow wf_ae8e4446, 4 lenses × verify)

2 CONFIRMED, 2 refuted:

- **NIT — `fluid_seg_touches_foreign_lab` fed unordered (pin→tip) segments** → `touch()`'s "foreign endpoint
  on MY span" probes die on a reversed (-x/-y-normal) segment, missing a foreign endpoint on the multi-grid
  stub/leg interior. **FIXED**: order the segment at the top of the helper (also hardens the shipped 0134
  single-grid slide; verified no test-outcome change).
- **MINOR — the corner neighbour-drag re-routes every other wire at the corner unchecked**; the outward
  search widens it (grazing + up to 6 grids), so a same-net corner backbone could sweep onto foreign copper
  unseen by the leg/stub guards, and B3 misses a label-less cross-instance merge. Latent, "not reproduced on
  any current fixture," contrived confluence. **DEFERRED**: a guard validating the neighbours' post-drag
  spans OVER-FIRED on the legitimate SAME-NET T-tap CARRY this pass exists to perform (`test_wireedit_31`) —
  distinguishing a carried same-net tap from a swept foreign backbone needs real net resolution, which this
  geometric P3 pass deliberately avoids. Left as a documented limitation (code comment + here), backstopped
  by B3 `fluid_check_move_invariants` and the fact that the unguarded 1-grid neighbour-drag is pre-existing
  (0132/0134). The 2 refuted findings restated the same neighbour-drag concern (verifier: pre-existing /
  unconstructible on any fixture).

## Verification

RED test `tests/headless/test_fluid_diagonal_shove_throughbody_0135.tcl` (real-X callback replay,
self-skips headless): D1 through-body-vertical check RED pre-fix, GREEN post-fix. Regression:
ctrl1_shove_0132 14/14 (shove STILL fires for CTRL1), bodyshove_guards_0132 14/14, 0134 neighbor_bus
10/10, ref_drop_0132 12/12, rotate_body_route_0130 7/7, ortho/rotate_second_0132, exit_stub_0111 20/20,
wireedit 57/57; test_fluid_editing only the pre-existing FE8 fails.
