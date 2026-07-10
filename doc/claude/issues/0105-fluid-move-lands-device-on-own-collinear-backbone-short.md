# 0105 — fluid connected-move drops a device onto its own follow-net backbone: collinear pin-bridge short

**Status: FIXED** (src/move.c, `fluid_ripup_foreign_pin_short`, two new collinear-jog call sites)

## Name / class

**Collinear backbone pin-bridge**: a connected move ('m') lands a two-pin device back ON
the very wire run that fed one of its pins, so ONE straight backbone now covers BOTH pins.
The backbone splits at the pin coordinates and the span between the pins bridges the
device; the span beyond it welds the invader pin to the backbone net. Both distinct-net
pins collapse onto one net — the device is shorted out of the circuit.

Sibling class to 0094 (perpendicular backbone, whole-backbone slide) and 0098
(anchored perpendicular backbone, route-around jog) — but with the shorting copper
**along the pin→sibling axis**, which both existing de-shorters were blind to.

## Repro (user session, FLUID_TRACE=/tmp/fltrace_7_8_19.log)

- `tests/from_user/before_8.sch`, launch `src/xschem --script src/cadence_style_rc`.
- Select R18 (res at (-40,0), rot3 flip1, horizontal): pin P(-70,0) on #net3 (C12 bottom
  plate route), pin M(-10,0) on #net1 (backbone run `[-400 -40 0 -40]` at y=-40).
- Press `m` (cadence connected move), drop at (-130,-40) — delta (-90,-40).
- Both pins land exactly on the y=-40 #net1 backbone: P→(-160,-40), M→(-100,-40).
- Saved `tests/from_user/after_22.sch`: `N -400 -40 -100 -40 {lab=#net1}` runs straight
  through P to M; #net3 swallowed by #net1; R18 bridged.

## Why every layer missed it (trace forensics)

1. **Offset/trim**: backbone splits at both pins → short exists immediately after the
   final leg (`pchg` partition_changed=4).
2. **`fluid_ripup_foreign_pin_short` (0094)**: pair (P,Q) found (START nets differ, live
   nets merged, P/Q axis-aligned). But `vertaxis` assumes the backbone is PERPENDICULAR
   to the P→Q axis: with P,Q both at y=-40 it seeds *vertical* wires at P's column — that
   picks up P's own follow riser (wrong copper). The slide moves the riser onto Q's
   column, the partition verify rejects it, revert.
3. **0098 jog around Q** (only tried after a failed slide): looks for a *vertical*
   backbone on Q's column — none. Returns 0. (And when no perpendicular copper existed at
   all, `nslid==0` bailed out before any jog was tried.)
4. **`fluid_prune_shorting_anchor_tails` (0104, "short-tail")**: dooming the outer span
   `[-400 -40 -160 -40]` improved the pairwise diff 4→3 only (the P–M bridge span remains)
   → "partial improvement only", reverted. Delete-only can't fix this: any single deletion
   either leaves the bridge or splits the backbone net.
5. **Accept ladder**: all 3 attempts equally dirty (4) → kept ortho attempt-1 → shorted
   result saved. Straighten then tidied *within* the merged net, welding the capacitor
   route onto M's column — the after_22.sch cosmetics.

## Fix

`fluid_ripup_foreign_pin_short()` gains the collinear case, reusing the existing
verify-gated `fluid_jog_pin_off_backbone`:

- **`nslid == 0` path** (no perpendicular copper at P at all): instead of `continue`,
  try `fluid_jog_pin_off_backbone(px, py, !vertaxis)` — the collinear backbone through
  BOTH pins is on the P→Q axis, so the jog axis is the *complement* of the slide axis.
- **Slide-failed path**: after the 0098 jog around Q fails, try the same collinear jog
  around P.

Only around-P is attempted: gapping the backbone around Q would cut Q off its own net and
the jog's partition verify (`fluid_partition_changed()==0` = exact START restore) rejects
it; the mirrored (q,p) pair iteration covers swapped invader roles. A wrong-pin attempt is
a clean revert, so both new call sites are no-ops on every drag that doesn't have this
exact short (default `fluid_editing` off ⇒ byte-identical, as before).

On the repro, END attempt-0 (2-leg) stays dirty — its preview routes the capacitor
approach along the same y=-40 row, so the gap-bump cannot separate the nets and the jog
declines — but attempt-1 (single diagonal elbow, capa approach on its own column) jogs
cleanly (`ripup: jogged backbone around pin (-160,-40) vert side=-10`) and is ACCEPTED
with partition_changed=0. The aesthetic passes then tidy the bump into a genuinely nice
route-around; saved result:

```
N -320 -150 -170 -150 / N -170 -150 -170 -40 / N -170 -40 -160 -40   #net3 → P (clean L)
N -400 -50 -90 -50 / N -90 -50 -90 -40 / N -100 -40 -90 -40          #net1 over the body → M
```

No shorts, no dangles, no body crossing, original pin↔net pairings preserved.

## Verification

- `tests/headless/test_fluid_collinear_backbone_short_0105.tcl` (+ `fixture_0105_pre.sch`
  = before_8.sch): 5/5 PASS; sabotage-RED (disabling the two new call sites → P=M=net1).
- Prior battery all green: 0098×2, 0088, 0089, 0096, 0104 (77), 0103 (77), 0099 (21),
  0100 (51), rotate_stretch_reconnect (17), wireedit suite, run_regression.
