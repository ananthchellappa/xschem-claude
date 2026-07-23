# 0132 — Second incremental fluid drag lands the body on its OWN copper (through-body backbone)

Status: **FIXED** (body-aware re-anchor + verified rip-up-reroute of stationary same-net copper the
moved body crosses). Was WIRING.md §11.9b, the distinct open follow-up of 0130/0133.

## Symptom (user report / after_32.sch)

A **second** incremental fluid connected-drag of an already-rotated instance moves its body **onto its
own previously-routed copper** (`tests/from_user/after_32.sch`, `x1` = `SANDBOX/solar_ctl` at
`(130,20) rot 1`). The saved schematic runs a Manhattan backbone **straight through the pin-inclusive
body** (`N 100 50 220 50` TRIANG, `N 140 -20 140 80` CTRL1) plus an **orphan stub** (`N 80 50 100 50`).
The netlist is electrically correct, but the geometry threads the body. 0130/0133 improved the
*single-drag* case; this second-drag case remained open.

## Root cause

Under rotation the whole obstacle/exit-stub healer layer is gated OFF (`move.c` fluid-block,
`rot==flip==0`), so the ONLY shaper of the accepted rigid-diagonal relay is
`fluid_manhattanize_relay_diagonals`. Two distinct failure modes combine (isolated by the two RED
reproductions below):

1. **Body-blind phase-1 re-anchor** (the after_32 variant). Phase-1
   (`fluid_manhattanize_relay_diagonals`, the candidate scan) connects the moved pin to the
   **distance-nearest** same-net copper and verifies only that the name partition is unchanged — never
   `fluid_seg_crosses_sel_body`. Because the body moved *onto* its own backbone, the nearest same-net
   copper **is** the through-body backbone; the pin solders to it and `done=1` **short-circuits** the
   body-aware `fluid_manh_route`.

2. **No pass reshapes stationary same-net copper the body crosses** (the pure/minimal variant). Even
   with a body-aware re-anchor, the offending backbone is **stationary, already Manhattan, its far end
   on a lab_pin** → invisible to the diagonal manhattanizer (which only reshapes non-Manhattan wires
   with one end on a moved pin). And it is **named** copper (TRIANG/CTRL1), which the explicit-lab
   orphan prune refuses to touch (WIRING.md §11.1 named-rail blackout). So nothing removes it.

The minimal reproduction (`tests/headless/test_fluid_rotate_second_drag_0132.tcl`, two clean drags of
`x1`: `10 10 rot 1` then `0 20`) is a **pure mode-2** case: the drag-1 TRIANG backbone sits at `y=70`;
drag 2 raises the pins to `y=80` so the stationary `y=70` backbone is now 10u under the pin-inclusive
top — a body crossing with **no** diagonal and **no** re-anchor involved.

## Fix (`fluid_manhattanize_relay_diagonals`, move.c)

Both modes, purely on the baked coords (rotation-safe), every mutation partition-verified + reverted
exactly (house never-worse pattern):

- **Mode 1 — body-aware re-anchor.** In the phase-1 candidate accept loop, reject any re-anchor
  candidate whose leg(s) strictly cross a moved body (`fluid_seg_crosses_sel_body`). If every
  candidate crosses, `done` stays 0 and the body-aware `fluid_manh_route` runs instead.
- **Mode 2 — `fluid_reroute_body_crossing_feeds()` (new phase, after the diagonal loop).** For each
  moved pin whose net `fluid_net_crosses_sel_body`, re-route the pin's feed to the **nearest same-net
  vertex strictly OUTSIDE the union body box** (`fluid_nearest_outside_body_anchor`) via the body-aware
  `fluid_manh_route`, then **verified-delete** the now-redundant through-body copper
  (`fluid_delete_body_crossing_copper`): each candidate wire is removed **only if the pin partition is
  unchanged without it**, so a load-bearing crossing is kept and a redundant one — even **named**
  copper — is dropped. This is a first, verified crack in the §11.1 named-rail repair blackout.

Trigger is narrow (`fluid + stretch + diag_relay` accepted, AND a moved instance's own net actually
crosses its body), so the common drag is untouched.

### Result on the minimal reproduction (`after drag2`)

```
TRIANG: pin (100,80) -> (100,100) -> N 100 100 220 100 -> N 220 20 220 100 (l0)   [escapes +y, clear]
CTRL1 : pin (140,80) -> (140,90)  -> N 140 90 160 90   -> N 160 -20 160 90  (l1)   [escapes +y, clear]
```

Stale through-body backbone `N 100 70 220 70` **verified-deleted**; every wire clear of the
pin-inclusive box; netlist unchanged (P1 x1↔l0 TRIANG, x1↔l1 CTRL1 still connected). CTRL1 is
re-escaped too because its old `y=80` leg was 2.5u inside the sym pin-inclusive box (same
over-the-top intent as 0133's single-drag GREEN).

## Never-worse argument

`fluid_manh_route` commits only a partition-verified route (body-free pref 0 before body-crossing
pref 1; if nothing verifies, the feed is restored to its original shape).
`fluid_delete_body_crossing_copper` removes a wire only when the pin partition is **identical** without
it. The re-anchor body-cross filter only *skips* a candidate (falls through to the already-verified
`fluid_manh_route`). A case with a clean outside route strictly improves; a fully-congested one is
byte-identical or a verified fallback.

## Tests

- `tests/headless/test_fluid_rotate_second_drag_0132.tcl` — two-drag gesture via the `move_objects`
  END seam. **RED before** (`crossings=1`), **GREEN after** (11/11): P1 connectivity, P4 no diagonal,
  P5 no pin-inclusive-body crossing, no NOVEL dangling end (the fixture carries two pre-existing
  danglers `(-60,0)`/`(-50,-20)`, excluded via a load-time baseline — see the `dangle_set`/
  `novel_dangles` procs).
- Regression: 0130 single-drag 7/7; all 14 `test_fluid_*` headless GREEN (incl. 0107/0108 relay +
  re-anchor); wireedit **58/58 ALL PASS**.

## Provenance / notes

- Mode-2 is the RED-verified core (the minimal reproduction triggers exactly it). Mode-1 (body-aware
  re-anchor) is regression-guarded (0108 re-anchor test + wireedit clean) and defends the after_32
  re-anchor variant, which my minimal reproduction does not itself trigger (its cleaner drag deltas
  produce no diagonal/re-anchor).
- `fluid_delete_body_crossing_copper` deletes named copper under an explicit partition verify — the
  first repair that safely touches named rails (§11.1). The blanket explicit-lab decline in the older
  orphan prune is unchanged; this pass is verified per-deletion instead.

## OPEN follow-up — the PURE-ORTHO variant (after_34)

The fix above only covers the rotated diagonal-relay path (it lives in
`fluid_manhattanize_relay_diagonals`, gated `diag_relay`). The **same** body-on-own-copper defect also
occurs via a **plain +dx translation** of an already-rotated body (`/tmp/Xschem.log.2`:
`before_10.sch` x1 at (110,20) rot 1 → `move_objects 20 0` → `after_34.sch` (130,20) rot 1). That
gesture has `move_rot==0`, accepts cleanly at attempt 0 (`diag_relay==0`), so it **never reaches**
`fluid_manhattanize_relay_diagonals` (trace: `manhattanize_relay_diagonals: SKIP`, `diag_relay=0`). The
TRIANG pin feed routes **-x into the pin-inclusive body** (`N 90 80 100 80`) instead of escaping +y.

Attempted fix (hoist the reroute to run on *every* accepted fluid stretch) was **reverted**: the
body-crossing detector (`fluid_net_crosses_sel_body` + escape-normal `fluid_seg_crosses_sel_body` + an
"inward feed" gate) **false-fires on ordinary 2-pin device moves** (res/ammeter, wireedit 20/36/39/45)
— a normal lateral pin feed reads as "inward", and the pass then deletes legitimate copper. after_34's
crossing is the pin's *own* feed, geometrically indistinguishable from a normal device feed, so no
cheap gate separates them (the through-backbone at y=90 is *outside* the body; only the feed crosses).

**Correct fix (not yet done): a body-aware elbow in `place_moved_wire`.** The `-x` elbow is chosen by
the ortho placement's elbow picker (`fluid_ml_hazards`); adding a body-crossing hazard so the pin
escapes along its outward normal (+y) is the root fix, on the ortho path itself, and is verified by the
existing per-elbow severity compare. Tripwire: `tests/headless/test_fluid_ortho_second_drag_0132.tcl`
(xfail; the `after_34.sch` RED-reference detector check passes, the reproduction's P5 is the xfail).
WIRING.md §11.9b.
