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

## §11.9b — the PURE-ORTHO variant (after_34): FIXED

The rotated fix above only covers the diagonal-relay path (`fluid_manhattanize_relay_diagonals`, gated
`diag_relay`). The **same** body-on-own-copper defect also occurs via a **plain +dx translation** of an
already-rotated body (`/tmp/Xschem.log.2`: `before_10.sch` x1 at (110,20) rot 1 → `move_objects 20 0` →
`after_34.sch` (130,20) rot 1). That gesture has `move_rot==0`, accepts cleanly at attempt 0
(`diag_relay==0`), so it **never reaches** `fluid_manhattanize_relay_diagonals` (trace:
`manhattanize_relay_diagonals: SKIP`, `diag_relay=0`). The TRIANG pin feed saved as **-x into the
pin-inclusive body** (`N 90 80 100 80`) instead of escaping +y.

### Root cause (traced, NOT the earlier `place_moved_wire` guess)

FLUID_TRACE checkpoint dumps proved the birth site. `place_moved_wire` lays a **CLEAN** feed —
`w2 [100 80 100 90]` (pin (100,80) straight up +y) + backbone `[100 90 220 90]` — and stays clean
through the whole offset/trim/END-cluster (every pass reports `changed=0`, `b0=b1=0`). The −x jog is
born in the END-cluster's **`insert_exit_stubs`** (a MANUAL_SITE pass, move.c ~8055):

```
pre-exitstub : w2 [100 80 100 90]   (clean +y feed)
post-exitstub: w2 [90 80 90 90]  w10 [90 90 220 90]  w12 [90 80 100 80]   (-x jog)
ES-DBG: pin=(100,80) escape_normal=(-1,0)  box[97.5 -132.5 150 82.5]  stubX=1
```

`insert_exit_stubs` reads the escape direction from `get_pin_escape_normal`, whose nearest-edge test
runs on the **TEXT-INFLATED `inst.x1..y2`** and mis-picks **-x/Left** for the rot-1 `solar_ctl` TRIANG
pin (a corner pin of an asymmetric symbol; the @name halo pulls the nearest edge to Left). The route
already exits +y straight, but with a -x normal that reads as "first leg is PERPENDICULAR → bends at
the pin", so the pass **SLIDES** it one grid -x and drops a stub — straight back through the pin body.

The earlier "body-aware elbow in `place_moved_wire`" plan was **wrong about the site**: the elbow was
never the problem (place_moved_wire's output is already clean; a `fluid_ml_hazards` body-cross tie-break
is inert here). So was the reverted `fluid_reroute_body_crossing_feeds` hoist (it deleted legit copper
on 2-pin moves). The defect is purely `insert_exit_stubs` acting on a bad normal.

### Fix

A pin-inclusive body-box guard in `insert_exit_stubs` (move.c ~2046), right after the slide candidate is
computed:

```c
if(tclgetboolvar("fluid_editing") &&
   (fluid_seg_crosses_sel_body(px, py, sx, sy) ||          /* the stub */
    fluid_seg_crosses_sel_body(sx, sy, nfx, nfy))) {        /* the slid leg */
  continue;                                                 /* DECLINE the slide */
}
```

`fluid_seg_crosses_sel_body` (the 0130/0133 pin-inclusive `fluid_inst_body_box` strict-interior test
with the box-centre escape-normal exemption) returns 1 for the -x stub `(100,80)-(90,80)` (`stubX=1`
above) because y=80 is interior to `[−132.5, 82.5]` and the -x direction is NOT along the pin's outward
normal (+y), so it is not exempt. Declining leaves the pre-slide over-the-top route, which is already
the correct exit. Instances are POST-move-committed and still SELECTED at this call site, so no delta
shift is needed. Gated `fluid_editing`, so the legacy `wire_exit_stub` feature is byte-identical.

### Never-worse

`insert_exit_stubs` is the lowest-but-one aesthetic pass (P3). Declining a slide only ever keeps the
route `place_moved_wire`/the cleaners already produced (electrically identical, no disconnect). A **true**
outward-normal slide moves AWAY from the body and is exempt by construction, so ordinary device feeds
(res/ammeter/mos — wireedit 10/19/28/29/30…) are untouched. The guard only bites the mis-picked inward
slide.

**Known limitation (adversarial review wf_ea9a847a, CONFIRMED minor/cosmetic):** the escape exemption
in `fluid_seg_crosses_sel_body` derives the outward axis from the box-CENTRE dominant axis, which is
aspect-ratio-blind. For a near-corner pin on a WIDE/TALL asymmetric symbol it can misjudge a genuinely
outward slide as inward and DECLINE a legit beautifying stub. Still never-worse (the kept route is
connected, Manhattan AND body-clear — only the stub aesthetic is skipped, and that stub itself grazed
the body). No shipped symbol/test triggers it, and it is the same box-centre approximation already used
by the 0130/0133 manhattanize path. A poly-accurate crossing test would fix it but contradicts the
deliberate 0133 pin-inclusive-box design; deferred as not worth the complexity.

### Tests

`tests/headless/test_fluid_ortho_second_drag_0132.tcl` — P5 promoted **xfail → hard `check`** (XPASS):
the `after_34.sch` RED-reference detector still passes, and the reproduction now escapes +y
(`up=1 inward=0`), P1 connectivity + P4 no-diagonal intact. Regression: **wireedit ALL PASS**, all **15
`test_fluid_*` GREEN** (incl. `exit_stub_staircase_0111`, rotated `0130`/`0132`). WIRING.md §11.9b / §5
pass table.

## §11.9c — the CTRL1 sibling (after_35): body-driven backbone shove — OPEN (xfail)

The after_34 fix (§11.9b) only covered the TRIANG pin's *lateral feed*. The **same gesture**
(`before_10` + connected drag of x1 `+20x`, pure ortho) leaves a **second, distinct** defect on the
*other* pin, CTRL1. Evidence `/tmp/Xschem.log.7` → `after_35.sch`.

CTRL1's stationary vertical backbone `N 140 -20 140 100` runs perpendicular to the move. As x1's body
advances right it engulfs the column x=140 (body box `x[97.5,150]`), and the CTRL1 pin (140,80) lands
**mid-run on its own backbone**, which is left threading the body. **Expected** (user): the vertical
segment is pushed RIGHT clear of the body (to x=160), the pin reconnecting via a short jog. At human
drag speed the wire should be shoved out *as the body reaches it* (live, during the connected drag).

**Why the existing layers miss it:** `fluid_shove_connected_wire` (issue 0015, the PIN-driven shove)
needs a *parallel* stub with a moving-pin endpoint driven past its junction — CTRL1's pin exits +y then
jogs, so that trigger never matches. This is the **BODY-driven** counterpart (the advancing body, not
the pin, overruns the wire). The diag-relay reroute/`fluid_delete_body_crossing_copper` is gated off on
the pure-ortho path (`diag_relay==0`), and the reverted whole-net delete-hoist over-fired on ordinary
2-pin devices.

**Attempted + reverted (this session):** a new `fluid_shove_body_crossing_backbone` END pass — detect a
same-net perpendicular run *straddling* the pin (copper both above AND below it: the both-sides gate is
what excludes TRIANG's one-sided +y escape), collapse the run, rebuild one backbone at ct=160 spanning
only [pin..load-bearing-corner] (dropping the dead stub above the pin so it can't cross the TRIANG rail
at y=90), reconnect via a jog, partition-verify with exact revert. It produced the *correct geometry*
for CTRL1, but running in the mid-gesture shared commit block fought the dirty transient state
(mixed-sel split runs; a phantom CTRL1↔TRIANG merge that survived even with `jprop.lab=CTRL1` and no
geometric contact — likely RUBBER-vs-END / follow-selection interaction). Rather than ship a shove that
mangles connectivity or over-fires into the most landmine-heavy code, it was **reverted** to e6186956.

**Correct fix (not done):** run the shove on a CLEAN, fully-committed geometry (all `sel==0`, trimmed —
after `unselect_partial_sel_wires`) rather than mid-gesture, or reformulate as a first-class END-cluster
pass with its own restore snapshot; the both-sides + load-bearing-span + partition-verify design is
sound, the *timing/selection interaction* is the unsolved part.

**Tripwire:** `tests/headless/test_fluid_ortho_ctrl1_shove_0132.tcl` — P1 connectivity + P4 no-diagonal
are hard checks (both pass; the current save IS connected, just body-threading); **P5 (backbone clear of
body) is xfail** and flips to XPASS when the shove lands. Body box `x[97.5,150] y[-132.5,82.5]` from the
C `fluid_inst_body_box` trace.

**Lesson (repeat of the after_34 lesson at the test level):** the after_34 fix was declared done with a
test that only asserted the TRIANG feed — it never checked CTRL1, so a second real defect on the same
gesture passed "green" and the adversarial review (scoped to the guard's correctness) could not see it.
A per-pin/whole-net body-clearance invariant, not a single-wire check, is the right assertion.
