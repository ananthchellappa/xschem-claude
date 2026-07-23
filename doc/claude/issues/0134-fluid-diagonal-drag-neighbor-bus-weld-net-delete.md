# 0134 — Diagonal fluid drag welds two 1-grid-apart neighbor buses, then cleanup deletes both nets (after_38); + TRIANG staircase

> Numbering note: "0133" is already an informal label for the pin-inclusive-box refinement
> of 0130/0132 (see `0130-*.md` "## 0133 refinement"); this issue is **0134**.

Status: **FIXED** (2026-07-23). Runtime-verified against `src/move.c`.
Sibling of 0130/0132 (the diagonal/incremental fluid-drag family).

## RESOLUTION (implemented) — and a diagnosis correction

The workflow's *static* diagnosis fingered the `fluid_ripup_foreign_pin_short` jog as the
root (Defect A below). **Runtime tracing corrected that** (same lesson as 0132 P-D, where
static analysis was also wrong): the accepted path for the *observed* corruption is END
**attempt=0 (leg-split, `diag_relay=0`)**, and the wire that actually welds REF↔LED is
`insert_exit_stubs` (move.c:1996) sliding REF's exit leg **one grid north (y=-140 → y=-150)
onto LED's parallel bus**. The ripup jog was only ever reached because attempt=0 first
*failed* on that insert_exit_stubs short and fell through to attempt=1. Fix the upstream
short and attempt=0 accepts cleanly — the ripup jog + the delete-only cleanup (Defect B) are
never entered.

**The true root** is the *documented* no-short gap in `insert_exit_stubs` (see the comment
block ~move.c:8500: "the SLIDE can still shift the leg/stub one grid onto a DIFFERENT net's
wire → a no-short (P2) hazard … caught log-only"). It had only a body-cross decline
(`fluid_seg_crosses_sel_body`), never a foreign-net decline.

**Fix (2 hunks, `src/move.c`, gated `fluid_editing`):**
1. **`insert_exit_stubs` foreign-net guard** — new `fluid_seg_touches_foreign_lab(ax,ay,bx,by,
   mylab,excl)` (move.c:1996) + a decline before the slide commits (move.c:2094): if the exit
   stub `(px,py)-(sx,sy)` or the slid leg `(sx,sy)-(nfx,nfy)` would touch a stationary wire
   whose net label differs from the leg's, DECLINE (keep the clean pre-slide route). P3 is the
   lowest aesthetic pass, so declining is never worse. This alone makes after_38 route
   correctly: REF stays on y=-140 (#net2), LED on y=-150 (#net1), TRIANG a clean vertical-first
   L — all 10 RED checks pass.
2. **Pure-ortho body-shove per-axis spoof** (move.c:8705) — making attempt=0 accept for a
   *diagonal* drag exposed a latent gap: on `+20,-10` the CTRL1 x=140 backbone threads the
   moved body, and the pure-ortho `fluid_shove_body_crossing_backbone` call was fed the
   **diagonal** total delta, which its internal pure-axis gate rejects. Mirror the §11.9f
   diag_relay site: call it once per axis (x-run with `deltay=0`, y-run with `deltax=0`). A
   pure-axis drag is byte-identical (the zero-axis run self-declines). This restores the
   after_37 CTRL1 shove (`test_fluid_diagonal_ref_drop_0132` P-A) that hunk 1 had exposed.

**Verification:** new RED test `tests/headless/test_fluid_diagonal_neighbor_bus_0134.tcl`
10/10; `test_fluid_diagonal_ref_drop_0132` 12/12 (was 2-FAIL mid-fix); `exit_stub_staircase_0111`
20/20; all 16 fluid GUI tests + wireedit 57/57 green; core regression unchanged (the 3
netlisting `*_debug` FAILs and `test_fluid_editing` FE8 pre-date this branch — confirmed on
clean HEAD).

**Defect C (route-quality) — ROOTED (candidate #1, follow-up commit).** The moved out-pin's
escape normal is now derived from the symbol's **lead geometry** instead of the text-inflated-bbox
nearest-edge PROXY. `get_pin_escape_normal` (move.c) gains a fluid-gated primary source
`get_pin_lead_normal`: a symbol pin is a PINLAYER rect whose centre (symbol coords) is the tip, and
its connector `L` lead line has one endpoint exactly at that tip; outward = tip − inner_end,
transformed by the instance rot/flip via `ROTATION(rot,flip,0,0,…)` (a direction vector — linear, so
rotating the difference == difference of rotations; flip negates x correctly). `dir=in|out` is
electrical only and is *not* read. This is strictly more accurate on asymmetric/corner/near-centre
pins where the proxy ties out or mis-picks: TRIANG (solar_ctl rot1) symbol +x lead → world +y/south,
so the moved pin exits VERTICALLY (the after_38 staircase, RED check "C: first segment … VERTICAL",
is now rooted, not merely masked by the downstream shove); the proxy had returned −x (Left) by tie.
Sanity: nmos4 bulk `b` (a classic near-centre pin) proxy → −Y (into the body), lead → +X (east, the
side its `L 4 10 0 20 0` lead actually points), corrected in all 8 orientations.

Consumers unchanged in shape but now fed the true normal: `insert_exit_stubs`,
`fluid_moving_pin_normal`→`fluid_p6_bias_ml` (the P6 L-elbow axis bias — this is what turns the
staircase into a vertical-first L), and `fluid_seg_crosses_body`'s moved-pin exemption. The raw ml
default (`recompute_orthogonal_manhattanline`, actions.c, |dx| vs |dy|, tie→ml=2) is untouched but is
overridden by the p6 bias when a lead resolves. The 0132 body-cross decline and the hunk-1 foreign-net
label guard in `insert_exit_stubs` remain as defense-in-depth (a correct normal makes them fire less,
but they still catch the residual no-short/body gaps). **Gated `fluid_editing`**: with fluid off the
legacy `wire_exit_stub` path stays byte-identical to the proxy (and to the Tcl reference
`predicates.tcl pin_escape_normal`); an ambiguous/absent lead falls through to the proxy unchanged.
Test: `tests/headless/wireedit/test_wireedit_28_escape_normal.tcl` rewritten — legacy proxy==Tcl
byte-identity (fluid off), fluid lead-accuracy + documented b-pin divergence (RED on the pre-fix
all-proxy binary). 0134 stays 10/10; wireedit 57/57; all fluid gesture suites green.

**Not implemented (latent, no test reaches it after the fix):** Defect A — the ripup jog can
still orphan a pin / weld a neighbor bus via the single-pin-net partition blind spot. Left as
open risk (WIRING §11 item 14); add the jog's foreign-touch + no-orphan guard **with a test
that actually reaches attempt=1** before touching that load-bearing function.

---

Original diagnosis (three defects, static-verified; A's causal role corrected above):

The accepted path in the *user's raw trace* was the pure-ortho attempt=1 (`diag_relay=0`) with
the ripup jog, so the fault *appeared* to be `fluid_ripup_foreign_pin_short`. Three distinct
defects were catalogued.

## Reproduction

- Fixture: `tests/from_user/before_10.sch`; action log `/tmp/Xschem.log.3`; fluid trace
  `/tmp/xschem_fltrace_50534.log`; user-saved result `tests/from_user/after_38.sch`.
- Gesture: LMB-drag instance `x1` (`SANDBOX/solar_ctl`, rot=1 @ origin 110,20) by delta
  **(-20,-10)** diagonal, then save. Equivalent replay:
  `select_at 120 -50; move_objects -20 -10`.

## Geometry (why this fixture triggers it)

`solar_ctl` rot1 places four pins; the two NORTH-edge input pins feed two parallel buses
stacked **only one grid apart**:

| pin | schem coord | dir | lead | net | backbone |
|-----|-------------|-----|------|-----|----------|
| REF | (100,-130) | in | ↑ N | `#net1` | `N -60 -140 100 -140` at **y=-140** |
| LED | (120,-130) | in | ↑ N | `#net2` | `N -50 -150 120 -150` at **y=-150** |
| TRIANG | (80,80) | out | ↓ S | TRIANG | `N 80 90 220 90` |
| CTRL1 | (120,80) | out | ↓ S | CTRL1 | `N 120 100 140 100 …` |

The -10 vertical component of the drag closes the 1-grid REF/LED gap: LED pin lands at
(100,-140), on REF's y=-140 backbone row.

## Symptom (after_38.sch)

- **`#net1` and `#net2` are entirely GONE** from the saved file — every REF and LED
  segment deleted. User: "there was plenty of room to push to wire segments."
- **TRIANG got a staircase**: `N 60 70 80 70` + `N 80 70 80 90` + `N 80 90 220 90` — first
  segment out of the pin is HORIZONTAL. User: "first segment out of instance should be
  vertical" (the pin lead is SOUTH).

## Trace of the accepted END attempt=1 (`diag_relay=0`, leg-split -20 then -10)

```
pass ripup_foreign_pin_short: changed=7 ("jogged backbone around pin (80,-140) vert side=-10")  15->19
pass remove_redundant_loops:  changed=8 ("collapsed redundant same-net loop, removed 8 wire(s)") 19->11
pass straighten_reversals:    changed=3 ("deleted orphan stub" x3)                                11->8
attempt=1 done ... partition_changed=0 -> ACCEPT
```

Earlier legs logged `pin snap=#net1(id 2) now=#net1(id 1)` → `#net2` merged into `#net1`.

---

## DEFECT A (ROOT) — `ripup-jogs-wrong-pin-welds-neighbor-bus`

**Mechanism.** LED (x=100) is the invader that lands on REF's y=-140 backbone. But
`fluid_ripup_foreign_pin_short` walks pin-pairs **in pin-index order** and reaches REF
(index 2 — the *non*-invader, legitimately on its own backbone) first. The 0105 collinear
path then jogs REF's y=-140 backbone one grid **DOWN to y=-150** — directly onto `#net2`'s
parallel backbone. The jog **welds** the two buses instead of separating them, and orphans
REF (it sits strictly inside the removed gap with no riser to the bump). Because both nets
are single-device-pin, the jog's verify reads clean; that clean verdict — **not** the later
deletion — is what makes END accept (`partition_changed=0` at `move.c:8549`).

**Location** (`src/move.c`): def `fluid_ripup_foreign_pin_short` :4220; pin-pair-in-index
loop :4234/:4243/:4263; 0105 collinear jog on REF :4313 → `fluid_jog_pin_off_backbone`
:4071, one-grid bump :4143-4177; sole verify :4188 `if(fluid_partition_changed()==0)`.
Self-documented blindness: :4317-4319, :4360-4361.

**Why existing guards miss it.**
- restore-START verify (:4188) is **pin-PAIR-indexed and single-pin-net blind**: `#net1`
  and `#net2` each carry exactly one device pin, so the orphaned/merged pins map to fresh
  singleton ids (`nextid++` :2483) byte-identical to the START singleton id a named single-
  pin net's pin got (:2481) → START vector lines up → `fluid_partition_changed()==0`. A
  short between *multi-pin* nets would collapse ids and be caught; the 1-pin topology is the
  blind spot.
- named-net protection (:4134/:4279) is **label-only** and `#net1`/`#net2` are auto names.
- P-D `fluid_wire_end_on_moved_pin` (:4796) guards the `diag_relay`
  `fluid_delete_body_crossing_copper` path, **not** this ripup jog.
- the jog lacks the foreign-touch guard its sibling **slide** branch carries (:4330-4335).

**Most surgical point.** Jog around the **actual invader** (the pin whose START net ≠ the
backbone's net), not pin index 0 (:4243-4269); or, before the :4188 keep, add the slide's
foreign-touch check + a "jogged-around pin retains degree ≥1 on its own net" check.

---

## DEFECT B (DATA-LOSS) — delete-only cleanup eats the welded/orphaned copper

Two passes share one guard-gap: both verify against a **pass-entry geometric partition that
already contains Defect A's transient short**, using a **name-blind, pin-indexed** partition,
with name protection for *explicit* labels only.

**B1 `fluid_remove_redundant_loops`** (:3027) — the welded rectangle reads as one
"redundant same-net loop" → −8 wires. Reference captured POST-short (:3059
`np = fluid_loop_partition(NULL, base)`); per-doom verify :3092-3093; `fluid_loop_partition`
(:2762) reads no net names. Eligibility gate :2985-3001 exempts auto `#` names. restore-START
backstop :3119-3120 defeated: `fluid_check_device_merge` (:2602) skips now-unconnected pins.

**B2 `fluid_straighten_reversals` pass-2** (:3616-3627) — the three leftover `#net` spans
(`[-60 -140 -60 0]`, `[-50 -150 -50 -20]`, `[100 -150 120 -150]`) are now degree-0 → whole-
stub DELETE branch in `fluid_retract_orphan_tail` (:3240, keep-test :3296-3298). Guard
`fluid_wire_explicit_lab` (:2737) is explicit-label-only; `allow_named_stale=0` at the call
site (:3625) so the §11.9g escape-hatch never evaluates; pass-2 has **no novelty gate**, so
it deletes *pre-existing* backbone (`[-60 -140 -60 0]` predates the drag).

**Most surgical point.** Gate both keep-tests (:3092-3093, :3296) on "every START-named net
retains ≥1 live carrier after the doom set"; or gate pass entry on a **true START snapshot**
(`fluid_partition_changed()==0 && fluid_check_device_merge()==0` measured before Defect A's
jog). Downstream mitigation only — fixing A removes the corrupt input.

---

## DEFECT C (independent, route-quality) — `elbow-axis-ignores-pin-lead-direction`

**Mechanism.** The follow-wire L axis is `xctx->manhattan_lines`, set from `|dx|` vs `|dy|`
alone; the diagonal `|dx|==|dy|` tie defaults to **ml=2 (horizontal-first)**. The moved pin's
true lead direction is never a first-class input — the only "normal" consumer is a below-P2
tiebreak using a **bbox-nearest-edge proxy** (not `dir=`) that declines for TRIANG. So the
SOUTH-normal out-pin exits sideways → `N 60 70 80 70` + `N 80 70 80 90` staircase.

**Location.** Branches read only `manhattan_lines`+`SELECTED1/2`: `place_moved_wire`
:1255/:1284/:1309/:1334 (def :1163). Baseline `recompute_orthogonal_manhattanline`
`src/actions.c:5150-5153` (tie→ml=2). Hazard flip `fluid_ml_hazards` :5816 (shorts only, no
normal). Only normal-consumer `fluid_p6_bias_ml` :2411 → `fluid_moving_pin_normal` :2253 →
`get_pin_escape_normal` :2104-2124 (nearest-bbox-edge proxy, tie order L,R,B,T). For TRIANG
the rot1 bbox yields a dead L/R/B/T tie → WEST; P6 toward-gate :2434 rejects → stays ml=2.
CTRL1 is correct only by luck (its SOUTH lead is the uniquely-nearest bbox edge).

**Why guards miss it.** Not a short/data-loss, so restore-START / named-net / P-D guards are
out of scope — none evaluate elbow orientation.

**Most surgical point.** Feed the symbol pin's real `dir=`/lead normal into
`fluid_moving_pin_normal` (:2253-2279) instead of the bbox proxy — or minimally break the
L/R/B/T tie toward the edge the lead actually crosses — so a moved out-pin with a SOUTH lead
prefers ml=1 regardless of the `|dx|==|dy|` tie. Ideally promote lead-normal to a first-class
axis input rather than a hazard-gated afterthought.

---

## Causal chain

Defect A (ripup jogs REF, the wrong pin) is the **root**: it welds `#net1` onto `#net2`
(buses 1 grid apart) and orphans REF, yet its pin-pair partition verify reads clean because
both nets are single-pin (id blindness :2483≡:2481). That clean verdict makes END accept
(`partition_changed=0` :8549) **before** any deletion. Defect B (two delete-only cleanup
passes sharing one name-blind/pin-indexed/post-short guard-gap) is why the copper is
physically **gone** from after_38. Defect C is independent and only shapes TRIANG's route.

## Fix sequencing

1. **Defect A first** (root) — either correct the pin-pair selection to jog the invader, or
   add the foreign-touch + pin-degree guard before the jog keep. Removing the weld removes
   B's corrupt input.
2. Defect B as defense-in-depth (START-carrier gate) — a wiring op must never leave a START
   net with zero live wires; this is the general anti-data-loss invariant.
3. Defect C independently (pin-lead-normal into the axis chooser).

## Test to add (RED first)

`tests/headless/test_fluid_diagonal_neighbor_bus_0134.tcl`: load before_10, replay
`select_at 120 -50` + `move_objects -20 -10`, assert (a) `#net1` and `#net2` each still have
≥1 wire and are DISTINCT partitions (no REF/LED merge), (b) TRIANG first segment out of
(60,70) is vertical. All three checks FAIL today.

## Related

- 0132 (`doc/claude/issues/0132-fluid-second-drag-own-copper.md`) — same diagonal-drag
  family, different root (`diag_relay` body-shove vs this ortho ripup jog). P-D "ref-net-drop"
  there was the *diag_relay* delete path; this is the *ortho* ripup path.
- WIRING.md §11 open-risk item added; §11.1 named-rail blackout and the single-pin-net
  partition blind spot are the two crosscutting weaknesses this exercises.
