# 0130 — Rotated fluid connected-drag: Manhattan wires intrude the body + one diagonal

Status: **FIXED** (body-avoiding manhattanize). Residual fully-congested layouts fall back to a
clean body-crossing/diagonal route (never worse); the full rotated obstacle router is still the
§11.9 open follow-up.

## Symptom (user report)

`select x1`, `m` connected drag, **ALT-R** rotate 90°, click to place +30 in y. "Manhattan wires
intrude into body and one non-Manhattan wire."

Evidence: `/tmp/Xschem.log.3` (action log: load `test_hier_descend_etc.sch`, saved as
`tests/from_user/after_31.sch`) + `FLUID_TRACE=/tmp/xschem_fltrace_136212.log`. Fixture:
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`;
`x1` = `SANDBOX/solar_ctl` (4-pin body). After the gesture `x1` lands at `(120,20) rot 1`; the
drawn body maps to the world rectangle **x∈[100,140], y∈[-110,60]**. `after_31.sch`:

```
N 110 -130 110 0   #net1   <- vertical THROUGH the body
N 130 -130 130 -20 #net2   <- vertical THROUGH the body
N 90 20 220 20     TRIANG  <- horizontal THROUGH the body
N 130 80 220 -20   CTRL1   <- DIAGONAL (non-Manhattan)
```

## Root cause

Under rotation the entire obstacle/exit-stub healer block is gated OFF
(`move.c`, the `fluid-block` at the `move_rot==0 && move_flip==0` gate — trace line
`fluid-block: SKIPPED (fluid=1 stretch=1 rot=1 flip=0)`). The accept ladder therefore rolls the
shorting ortho attempts back and accepts the **rigid diagonal relay** (attempt 2), and the ONLY
thing that then shapes those diagonals is `fluid_manhattanize_relay_diagonals`. Its phase-2
L-picker accepted the **first partition-clean L regardless of geometry** — so it routed the
LED/REF/TRIANG feeds straight through the rotated body — and when **both** L corners shorted (CTRL1:
V-first hits `#net2`, H-first hits the `TRIANG` copper at l0) it gave up and **kept the diagonal**.
This is exactly WIRING.md risk §11.9 (rotation lacks the Layer-2/3 + exit-stub machinery) and §11.12
(relay-bend × manhattanize composition).

## Fix (`fluid_manhattanize_relay_diagonals`, move.c)

Make the manhattanize L-picker **body-aware** and give it a bounded body-skirting detour, purely
geometric on the baked relay coordinates (no transform math → rotation-safe), every candidate
partition-verified + reverted exactly on failure (the house never-worse pattern):

- `fluid_inst_body_box` — an instance's **tight drawn-body** world bbox: polygons + non-`PINLAYER`
  rects + arcs, **excluding** the pin whiskers, the connector `L` stub lines and all text. This is
  the box the user sees, not the label/pin-tip halo that inflates `symbol_bbox` (that coarse box
  wrongly flags a clean below-body route because a pin sits on its edge). Line-only symbols return 0
  → "no body to avoid" (conservative). Rotation is 0/90/180/270 so the rotated AABB is exact.
- `fluid_seg_crosses_sel_body` / `fluid_union_sel_body_box` — strict-interior crossing test / union
  box over the SELECTED (moved) instances.
- Preference order across a new `pref` outer loop (0 = body-free tried **before** 1 = body-crossing,
  and within each an L before a Z): **body-free L → body-free Z → body-crossing L → body-crossing Z**.
  So a body-free Z beats a body-crossing L (else the second feed, whose escape row the first feed
  already took, would grab the through-body L before the below-body Z was considered).
- **Phase 3** (new): when no straight L clears the body, lay a 3-leg **Z** through a
  geometrically-meaningful channel — one grid off the pin, one grid outside a body edge, or the
  anchor's own line — **length-sorted**, with an edge-clearance tiebreak (an on-edge channel draws
  the wire flush along the outline; prefer the one-grid-clear channel of equal length).

Result on the fixture (`tests/from_user/after_31_fixed.sch`): every wire Manhattan and strictly
outside the body, one-grid clearance, **netlist unchanged** (`p2_merges=0`, every pin on its
original net):

```
#net1: L below+left  ·  #net2: Z under the body (y=-120)  ·  TRIANG: Z over the body (y=70)
CTRL1: Z one grid right of the body (x=150)
```

## Never-worse argument

Phase 2 pref=1 and phase 3 pref=1 fall back to the pre-fix behavior (first partition-clean L, else a
clean body-crossing Z); if nothing verifies clean the diagonal survives untouched. So a case with a
body-free route strictly improves; a fully-congested one is byte-identical or a clean fallback. The
non-rotated relay corpus (0107/0108, before_8) is unaffected — its Ls were already body-free, so
pref=0 picks the same L (verified: R18 NW drag still lands `(-170,-90)`, 0 diagonals, distinct nets).

## Tests

- `tests/headless/test_fluid_rotate_body_route_0130.tcl` — replays the exact gesture via the
  `move_objects dx dy rot flip local stretch kissing` END seam; asserts x1 lands `(120,20) rot 1`,
  P1 connectivity (x1↔l0 TRIANG, x1↔l1 CTRL1), **no diagonal** (P4), **no body crossing** (P5).
  RED before the fix (`diag=1`, `crossings=5`), GREEN after (8/8).
- `tests/from_user/after_31.sch` (RED evidence) + `after_31_fixed.sch` (GREEN reference).
- Regression: wireedit 58/58 ALL PASS; 0107/0108 relay corpus clean; core regression fail-set
  identical to baseline (pre-existing harness/env noise, not this change).

## 0133 refinement — the body is the PIN-INCLUSIVE box, and a unified router

User feedback (`Xschem.log.7` → `after_33.sch`, single drag `select x1 → m → ALT-R → drop (10,10)`,
x1 → `(130,0) rot 1`): the wires still ran "through the body", where **the body is the widest bbox
that includes all the instance's pins** — not the tight central drawn body the first cut used. The
TRIANG backbone `N 100 50 220 50` ran at y=50, clear of the drawn P-polygon (y≤40) but straight
**under the top pins** (TRIANG/CTRL1 @ y=60).

Changes:
- **Body box = pin-inclusive.** `fluid_inst_body_box` now returns the symbol's NO-TEXT bbox
  (`sym->minx..maxy` rotated — spans every pin rect, stub line and body polygon; excludes the
  instance-variable @name text). `fluid_seg_crosses_sel_body` gains the **escape-normal exemption**
  (a pin sits ON this box, so every feed leg clips it — a leg leaving a pin OUTWARD, dominant axis
  from the box centre, is exempt; a backbone threading under the pins is not). NB `get_pin_escape_normal`
  is deliberately NOT reused — its nearest-edge heuristic on the text-inflated `inst.x1..y2` mis-picks
  the axis for a pin near a box corner (an output pin 2.5u from both the left and top edges ties to
  Left), which rejected the correct over-the-top route.
- **Unified router** `fluid_manh_route` replaces the ad-hoc phase-2/3 L/Z picker. It enumerates
  candidate Manhattan routes — direct **L**, direct **Z** (over grid-aligned channel lines: 1/2 grids
  off the pin, one grid outside a body edge, the anchor line), and **escaped L/Z** (a one/two-grid
  exit stub along the pin's outward normal, then L/Z from there — the only way out when the pin is
  INSET from the body edge, e.g. after_33 CTRL1). Each candidate is a point list committed by
  `fluid_manh_commit_path` (partition-verify + exact revert via the manh_doomed watermark);
  index-sorted by (length, legs); body-free (pref 0) committed before body-crossing (pref 1).
  Channels landing exactly on a body edge are dropped so a wire never grazes the outline.

Result (`after_33_fixed.sch`): TRIANG routes over the pins (y=70), CTRL1 escapes +y and skirts the
body one grid clear on the right (x=160), #net1/#net2 drop one grid below the pin tips — every wire
clear of the pin-inclusive box, netlist unchanged (`p2_merges=0`). Test
`test_fluid_rotate_body_route_0130.tcl` now asserts against the pin-inclusive box (pin feed stubs
exempt): RED before (`diag=1`, 3 crossings), GREEN after (7/7). wireedit 58/58, relay corpus
(0107/0108) clean.

## Open follow-up

A **fully congested** rotated layout (no body-free route verifies) still falls back to a body-crossing
route — the complete fix is §11.9's "audit and un-gate the obstacle router under rotation". Separately,
a **second incremental drag** that lands the body on its OWN already-routed copper (`after_32.sch`)
leaves through-body backbone + an orphan stub: the accepted relay's phase-1 re-anchor connects to
stale through-body copper and does not reshape it (the router only reshapes relay diagonals). TRIANG
improves (routes over the pins) but CTRL1 + the orphan stub remain — a distinct open issue (rip-up-
reroute of stationary copper the moved body crosses).
