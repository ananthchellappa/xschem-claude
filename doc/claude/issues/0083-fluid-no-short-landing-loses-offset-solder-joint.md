# Issue 0083 — fluid follow-set: a no-short landing onto a foreign pin loses the offset solder-joint and runs flush against the device body

**Opened:** 2026-07-07
**Status:** IMPLEMENTED 2026-07-07 (branch `fluid-editing`, first increment — vertical-riser/horizontal-bus,
pure-axis). See **Implementation** below; the original write-up follows.

---

## Implementation (2026-07-07)

**Mechanism (pre-code design-critique workflow `wf_0b98812c`: 3 proposals → judge → 2 critics).** A new
stateless post-detection sibling pass `fluid_offset_foreign_pin_landing()` (`src/move.c`), called at the
shared pre-trim commit seam immediately after `fluid_reroute_around_obstacles()`, gated `nlegs==1` (pure
axis only — never stacks on the 0081 diagonal decomposition) inside the existing
`fluid_editing && stretch_select && rot==flip==0` block. It reads the naive-committed geometry and, when
it finds a **same-net** tool-owned riser whose far corner landed on a stationary device pin with a bus on
the pin's row, rebuilds the riser into the user's **V-H-V**: pin escapes one grid, jogs one grid away from
the body, drops a long clear leg landing one grid **outside** the body onto the bus at a restored
**degree-3 solder-dot**, with a short stub reaching the pin. The bus is shrunk to the dot and the stub
re-added, so the bus-row copper is **union-identical to baseline** (copper-neutral — only the three new
riser legs are guarded). before_3 (`R18 +10 x`) → `leg1 -390 -10→0`, `leg2 -390→-400 @0`,
`leg3 -400 0→140`, stub `-400→-390 @140`, bus `-550→-400`, degree-3 T at (-400,140).

**Safety.** Pure fn of (pristine snapshot + total delta + geometry) ⇒ **release==stepwise** free; whole
block gated on `fluid_editing` ⇒ **default-off byte-identical** (verified: fixed fluid=0 ≡ baseline
fluid=0 segset). P5/beautify, lowest-but-one in the conflict order — every guard **declines to the naive
baseline** (never worse): same-net-only (a distinct-net pin is a straddle owned by the earlier reroute);
exactly-one riser / exactly-one bus / no other wire stranded at the corner; per-leg
`fluid_seg_crosses_stationary_body` + `fluid_seg_hits_foreign_pin` + `fluid_seg_hits_moving_pin` +
`fluid_seg_stray_contact`; offset column clear of pins. Critic fixes folded in: near-M legs built from the
riser's OWN endpoint (off-grid P1 safety), the diagonal `nlegs==1` gate, per-leg body guard, autotrim=1 in
the test. **First-increment limitations (all decline-safe):** vertical-riser/horizontal-bus only
(rotated-bus / horizontal-riser decline); one landing per pass; a collinear-split riser/bus under autotrim
declines (doesn't fire). **Tests:** `test_wireedit_41_no_short_offset_solder` (exact before_3, RED-first @
HEAD 6 discriminators → GREEN; release==stepwise; P1/P2 rails). Full wireedit ALL PASS (41) + wire_split +
fluid_editing OVERALL ok; `--memcheck` clean (test_41 + test_34).

**Adversarial review `wf_3029984d` (4 worktree-isolated lenses: P1/P2, invariants, detection, memory).**
memory lens clean; P1/P2 lens **REFUTED** any short/disconnect (structural proof: the offset column
`Cpx=Px±grid` is one grid from the baseline riser, so any on-grid distinct wire crossing it mid-span must
also cross the baseline riser — same net-pair, not new — or end at `Cpx` and be caught by
`fluid_seg_stray_contact`; the pass even converts a *baseline* short into a benign mid-span non-connection).
**1 CONFIRMED minor** (invariants + detection both): the `nlegs==1` call gate did not *literally* enforce
"pure-axis" — the 0081 P2 fallback resets `nlegs=1` with the full diagonal delta still set, and a diagonal
drag with a user-preselected follow wire keeps `nlegs==1`; both leave `deltax,deltay` BOTH nonzero. Harm
was **not reproducible** (the pass's internal guards declined on every diagonal — the vertical-riser-corner-
on-pin + bus signature is effectively pure-axis), but the contract was guard-enforced not gate-enforced.
**FIXED**: gate tightened to `if(nlegs==1 && (deltax==0 || deltay==0))` — makes "pure-axis only" literally
true + defense-in-depth, zero cost, before_3 (deltay==0) still fires. Re-verified: suite ALL PASS (41),
byte-identical fluid=0 ≡ baseline.

**BROADENED 2026-07-07 (user real-window feedback → the actual gesture).** The user's move is a
**continuous drag: +10 then +10 more** (LMB held). At +10 the fix fires (they confirmed a solder-dot
appeared to the left — the interactive path WORKS); at total **+20** the riser lands *inside* the ammeter
body with the corner **not on a pin**, so the narrow "corner exactly on pin" trigger declined → intrusion.
Broadened the trigger to **"corner column strictly inside the device body x-span"** (`bx1<Cx<bx2` of the
inflated symbol_bbox) — catches the exact-on-pin +1-grid case AND any drag past the pin. The same-net
anchor pin is found by search; the **overshoot stub** (pin→corner, left by a >1-grid drag) is reshaped
into the pin-reaching stub `C'→P` (or a fresh stub is stored for the exact-on-pin case where the overshoot
is degenerate). **All rightward deltas +10/+20/+30/+40 rebuild to the SAME canonical result** (riser V-H-V
to a degree-3 solder-dot at x=-400, one grid outside the body, stub to plus). Bus+stub row copper is a
**subset of baseline** (re-segmented, overshoot removed) ⇒ no new crossing; only the 3 new legs guarded.
Boundary: a drag so far the corner reaches the FAR (distinct-net) pin is a straddle `fluid_reroute_around_
obstacles` handles first (this pass then sees a detour and declines). **release==stepwise** holds (Phase II
re-solves each step from pristine+total delta, so +10-then-+10 == one-shot +20). test_41 gains +20
(release+stepwise) + +30 drives + multi-column body-clearance checks. Suite ALL PASS (41); byte-identical
fluid=0 (+10/+20/+30); `--memcheck` clean. Commits `5fa69442`/`8bf415a4`/`614bd6d5`. **NOT yet done:**
user real-window eyeball of the +20 continuous drag (the acceptance gate); adversarial review of the
broadening (`wf_e96154bf` running).

**BROADENED AGAIN 2026-07-07 (user trace `/tmp/fltrace.log`, before_3 → after_4: drag right +70 then up
-40).** The user's continuous gesture crossed the point where the riser corner lands **exactly ON the
FAR (distinct-net) pin** (v8.minus, x=-330 at totdx=70). Three-stage failure, read straight off the
FLUID_TRACE: (1) the offset pass **declined** — the stationary OUT wire ends at the corner →
`stranded=1`; (2) the presumed owner `fluid_reroute_around_obstacles` **cannot see this straddle**: the
straddling wire is the stretched BUS/overshoot whose endpoints are the anchor and the dragged corner —
no moving-pin endpoint (`e1mov==e2mov` → detection breaks out). The known-limits assumption "the far-pin
straddle is owned by the reroute" is FALSE for the translate topology (the moving pin rides the riser,
never the straddling wire). So the naive X-leg **genuinely shorts** (`#net1`+`OUT` merge; on a pure-axis
+70/+80 release the short LANDS — a P2 bug at HEAD, not just feel); (3) on the diagonal gesture the
two-leg P2 net catches it → `partition_changed=2` → ROLLBACK to the single diagonal pass, where neither
the offset pass (`pure_axis_gate=0`) nor the 0015 §7 shove runs → the `#net2` relay stub buries through
R18's **own body** (after_4.sch, wire `-330,-110..-330,-90`) — the defect the user saw.

**Fix (same pass, two changes):** (a) guard-1 trigger: corner strictly past the **pin-side body edge,
inward — unbounded far side** (was: strictly inside the body x-span) — catches on-far-pin (+70),
past-body (+80), and far landings (+130 = ON p5's pin); (b) classification: a **STATIONARY (unselected)
wire ending at C is ignored** (not `stranded`) **when C sits exactly on a stationary pin whose pristine
net ≠ nf** (new helper `fluid_point_on_foreign_fixed_pin`, snapshot-net + `point_near_pin` walk) — such
a wire is pristinely attached to THAT pin (foreign net by construction), and the V-H-V rebuild vacates
the corner, restoring its pristine contact set exactly. Firing now **repairs the would-be short** (the
rebuild removes the bus/overshoot copper past the dot column); every other decline is unchanged, and a
SELECTED wire at C still declines. Cascade win: the X-leg no longer shorts → two-leg **ACCEPT** → the
pure-Y leg runs → the 0015 shove pushes the `#net2` bus row ahead of the pin (y=-90 → -120) → both nets
canonical; the user's exact gesture ends CLEANER than after_4 (offset dot at (-400,140) AND no own-body
cross). release==stepwise holds (verified on the exact 10-commit gesture vs one-shot (70,-40)).

**Layer-3 coverage preserved:** test_36 shapes j/l/m reached the Layer-3 step-out **via the rollback**
(their X-legs short at HEAD the same way); post-fix the offset pass owns those diagonals with an equally
clean route, which would have left the step-out/off-grid-cap/collinear machinery untested. Their scenes
now place a same-net `lab_pin` on the offset column (-400,140) so `point_on_any_pin(Cpx,Py)` makes the
offset pass decline → rollback → Layer 3 exercised as designed (labels are invisible to the reroute
layers; electrically a no-op). **Tests:** test_41 drives 6–9 (+70 release+stepwise+equality, +80, +130,
the exact user gesture + release equality, own-body `(-330,-95)` discriminator) — 22 RED @ HEAD → GREEN.
Suite ALL PASS; fluid=0 byte-identical vs `scratchpad/xschem.base0083` (9 deltas × release+stepwise).

**Adversarial review `wf_dfd3e463` (4 worktree attack lenses + independent refute-verify per finding) →
3 CONFIRMED P1 never-worse holes in the first cut (`6bb9eaa4`), all HARDENED in the follow-up commit
(all reachable only with `autotrim_wires=0` — the STOCK default; the user's cadence rc autotrim=1
pre-splits buses at taps/pins so classification already declined — or with off-grid pins):**
1. *Tolerance-band `c_on_foreign`*: the helper matched pins within `point_near_pin`'s ±cadsnap/2 box
   while classification compares exactly — an off-grid foreign pin NEAR (not at) C exempted an
   unrelated stationary wire ending at C → vacated → disconnect. **Fix: exact coordinate match.**
2. *Removed-span strand*: the rebuild deletes the naive `(P..C]` row copper; a tap-wire endpoint or a
   START-nf pin strictly inside (pristine in-body arm; a second device fed mid-span) was stranded.
   **Fix: `fluid_removed_span_unsafe` — decline unless everything strictly inside `(P..C)` is a
   stationary START-foreign pin('s attachment).**
3. *Stationary-wS reshape*: an unselected user wire spanning `[P..C]` could be taken as the overshoot
   and reshaped. **Resolution: `sel` CANNOT distinguish tool copper (place_moved_wire re-lays the
   follow wires with sel==0 at the pre-trim seam — a sel-based restriction broke every legit firing),
   so classification stays geometric: a duplicate candidate declines by ambiguity, and interior taps
   are protected by the removed-span scan.**
Regression rails: `test_wireedit_42_farpin_never_worse` (T1–T4 + repair-must-still-fire rails,
autotrim=0) — T1/T2/T3 RED at unhardened `6bb9eaa4` (sabotage-verified), GREEN after. Cleared by the
review: mirror/leftward drags (dir_off=+1 symmetric), +10000 extreme drag, edge-grid unreachability,
subset argument for kept row copper, test_36 blocker honesty (Layer 3 genuinely routes j/l/m; disabling
it flips 17 checks RED). **Known limits (decline==naive, never-worse holds, next-increment candidates):**
Y-axis transpose of the same gesture still shorts (horizontal-riser scope); a long instance name
(text-inflated bbox) makes leg guards decline → naive short returns; corner exactly on a foreign WIRE
endpoint (not a pin) declines while the mid-span landing repairs.

---

<details><summary>Original write-up (pre-implementation)</summary>

**Opened:** 2026-07-07
**Status:** OPEN (branch `fluid-editing`).
**Affects:** interactive fluid stretch-move of an instance with `fluid_editing` on, when a
tool-owned follow wire's corner is translated to land **exactly on / flush against** a stationary
foreign device's pin **without creating a short**.
**Severity:** low–medium — **quality/feel only** (P5-adjacent + lost solder-joint). Connectivity
is correct (no short, no disconnect, partition unchanged), so the netlist is right; this is the
kind of feel regression that gates the default-on push (issue-set candidate B), not a correctness
blocker.
**Branch:** `fluid-editing`.
**Related:** `incremental_wire_reroute.md` §6 (the "Stop-short + visible junction / solder joint"
beautifier rule) + §10.4 (stop-short granularity, junction-hops-past-obstacle open decision);
`nice_drag_rerouting.md` §4 predicate **P5** (no-body-cross) + the conflict order
`P1=P2 > P3 > P5 > P4 > P7 > P6`; the shipped obstacle layers `fluid_reroute_around_obstacles`
(Layers 1–3, `move.c`) which produce the offset solder-joint **only** on a two-distinct-net
straddle (a short scenario); the unimplemented P5-body-as-obstacle **driver** (noted in the
`nice-drag-rerouting` memory GUI-feel entry: "obstacle layers 1–3 only avoid STATIONARY instances'
distinct-net pins, never any body — own or foreign"). Distinct from issue 0081 (diagonal) and from
thread-1 (mid-drag big-delta): this reproduces on a **small pure-axis** move.

---

## 1. Ground truth (user testcase)

Files `tests/from_user/before_3.sch` → `after_3.sch`. Launch = the user's real window
`src/xschem --script src/cadence_style_rc --logdir /tmp` (so `fluid_editing=1`, `cadence_compat=1`,
`orthogonal_wiring=1`, `autotrim_wires=1`; `wire_exit_stub` off).

Scene (an ammeter `v8` at world (-360,140) rot 3; graphic body bbox **x∈[-390,-330]**, y∈[132.5,147.5];
pins `plus`=(-390,140) on `#net1`, `minus`=(-330,140) on `OUT`):

- `#net1` = R18 pin `M` → **vertical riser down** to a y=140 horizontal bus → left to x=-550, and
  a short hop right to v8.`plus`. In **before_3** the riser is at **x=-400**, meeting the bus at a
  **visible 3-way T-junction (solder dot) at (-400,140)**, then a short `N -400 140 -390 140`
  reaches v8.`plus`. (-400 clears v8's body by 10 units.)

**The move.** R18 dragged **right by +10 x only** (`-400,-40` → `-390,-40`; Δy=0). Legal, tiny,
pure-axis.

**after_3 (non-optimal result, current binary).** The base stretch-follow **rigidly translates**
R18's riser-L: the vertical riser moves `x=-400 → -390`, its bottom corner `(-400,140) → (-390,140)`,
and `trim_wires` **merges** the two collinear y=140 segments (`-550..-400` + `-400..-390`) into one
`N -550 140 -390 140`. Outcome:

- The riser now sits at **x=-390**, i.e. **flush on v8's left body edge** (grazes the outline for
  7.5 units down to the pin — strict-interior penetration is 0, so it is a *graze*, not a body
  crossing; see §3).
- The **visible solder dot at (-400,140) is gone** — the junction now sits **exactly on v8.`plus`**,
  which reads as an invisible/ambiguous connection (a junction *at* a pin, the very thing the
  stop-short rule exists to avoid — `incremental_wire_reroute.md` §6).
- No short: the horizontal stops at -390 (=`plus`), never continues to -330 (=`minus`), so v8 stays
  `plus=#net1`, `minus=OUT`. Netlist correct.

## 2. Desired (the acceptable target)

The riser should become the user's **three-segment V-H-V** ("two vertical, one horizontal"):
drop vertically from R18.`M` at x=-390, jog horizontally back to **x=-400** (clear of the ammeter),
drop vertically to y=140, meet the bus at a **restored visible solder dot at (-400,140)**, and reach
v8.`plus` via the short `N -400 140 -390 140`. This keeps the riser clear of the device body and
keeps the junction offset/visible — identical **style** to the original R18 `beautified.sch`
(`incremental_wire_reroute.md` §2: "riser at x=-410 … short horizontal to v8.plus at -390 …
visible T-junction at (-410,140), never continue past -390").

## 3. Root cause — the offset solder-joint / P5-body avoidance is bound to the short-detour trigger

Two shipped mechanisms could have kept the offset, and **neither fires here** (verified against
`move.c`, `fluid_editing=1`):

1. **Obstacle Layers 1–3** (`fluid_reroute_around_obstacles`, `move.c`, and the Layer-1 ml-flip in
   `place_moved_wire`). These emit the outward-offset visible solder-joint (via
   `fluid_wire_covers_on_line`) — **but only when triggered by a two-distinct-net STRADDLE** of one
   stationary device (both of its distinct-pre-move-net pins on **one** wire/L):
   - Layer-1 `fluid_L_bridges_device` needs a second distinct-net pin on the L
     (`if(!bq || !bq[0] || !strcmp(bp, bq)) continue;` … `return 1` only if the q-pin is on the L).
   - Layer-2/3 needs **both** pins on **one** wire
     (`if(!(fluid_pin_on_seg(pa…) && fluid_pin_on_seg(qb…))) continue;` … `if(wfound<0) break;`).

   Here v8's two pins are on **distinct** nets but **not both on one wire** (`plus`=#net1 on the
   riser's horizontal; `minus`=OUT on a separate wire). Only **one** foreign pin is contacted, and
   contacting it is not a short. So the straddle predicate is false → **no reroute, no offset**. The
   layers are P2/no-short machinery; there is **no short to avoid** here, so they correctly stand
   down — but that also means nothing generates the beautify offset on a plain landing.

2. **P5 body avoidance.** The only body test, `fluid_seg_crosses_stationary_body()` (`move.c`), is
   used **solely as a DECLINE veto** inside `fluid_p6_bias_ml` (it suppresses the P6 min-bend bias
   if that bias would cross a body); it is **never a driver** that reroutes a follow wire around a
   body. And it tests **strict interior**, so the after_3 riser flush on x=-390 (= the left edge)
   would not even trip it. There is no code that, seeing a follow-wire leg land flush against or
   grazing a stationary device body with no short, actively offsets it clear.

Also ruled out: the move is pure-X (Δy=0), so the **diagonal decomposition (0081)** never engages
(`totdx!=0 && totdy!=0` gate) and `fluid_partition_changed()` is 0 (no merge) so its P2 safety-net
never rolls anything back. This is a base stretch-follow translate + `trim_wires` merge, with every
fluid layer correctly declining.

**One-line root cause:** the **stop-short + visible-junction ("solder joint") beautifier rule**
(`incremental_wire_reroute.md` §6) — and P5-body clearance — are only realized as a **side effect of
the Layers 1–3 short-detour**, so a follow wire that lands its corner *on/flush against* a foreign
pin **without shorting** gets neither the offset junction nor body clearance; it just translates onto
the pin column.

## 4. Design direction (to refine before coding — do a small design workflow + judge)

The needed capability is a **no-short "stop-short + offset solder-joint" pass** that fires on a
follow-wire **landing**, independent of the two-distinct-net straddle trigger:

- **Detect the landing.** A tool-owned follow wire's translated corner comes to rest exactly on (or
  within one grid of) a **foreign** stationary device pin, OR a follow-wire leg would run **flush
  along / graze** a stationary device body edge — with **no partition change** (P1/P2 already
  satisfied; this pass is purely P5/beautify, lowest-but-one in the conflict order, must yield to
  P1=P2 and to P3/P5 correctness).
- **Apply the offset.** Reuse the Layers 1–3 offset machinery (`fluid_wire_covers_on_line` + the
  one-grid-outward solder-joint) to pull the riser one grid clear (x=-390 → -400), restore the
  visible T-junction, and connect to the pin via the short stub — the same construction the
  short-detour already builds, just triggered by a landing rather than a straddle.
- **Reuse, don't reinvent.** This is `incremental_wire_reroute.md` §6 generalized off the short
  trigger. Fold in §10.4's open questions: stop-short granularity (always one grid vs nearest clear
  grid line) and whether the junction hops to the far side when the pin is dragged **past** the
  device.
- **Guards / monotonicity.** Every guard must **decline to baseline** on any doubt (never make it
  worse than today's translate): no offset if the offset column is itself occupied by a foreign/
  co-moving pin or a distinct-net wire (mirror the Layer-2/3 guards `fluid_seg_hits_foreign_pin`,
  `fluid_seg_hits_moving_pin`, `fluid_seg_hits_foreign_wire`); no offset if it would touch a second
  device pin (that would be the straddle case → let Layers 1–3 own it).
- **Placement.** The pre-trim commit seam next to `fluid_reroute_around_obstacles` /
  `fluid_shove_connected_wire`, so it runs for both the live `commit_now` RUBBER step and real END ⇒
  **release == stepwise** for free; pure fn of `(pristine snapshot, total delta, obstacles)`.
- **Gate.** `fluid_editing && stretch_select && rot==flip==0` ⇒ default-off byte-identical.

Open question for the design workflow: is the right primitive **"P5 body-as-obstacle driver"**
(offset any follow leg off any stationary body it grazes — the general fix that also subsumes
own-body cases) or the **narrower "offset-solder-joint on a foreign-pin landing"** (this case only)?
The narrow one is a smaller, provably-safe first increment; the general P5 driver is the longer-term
item the `nice-drag-rerouting` memory flags as unimplemented. Recommend the narrow increment first,
then generalize.

## 5. Acceptance

- before_3 → the V-H-V result of §2: riser offset at x=-400, **visible solder dot restored at
  (-400,140)**, short hop to v8.`plus`, riser clear of the ammeter body; v8 stays un-shorted
  (`plus=#net1`, `minus=OUT`), partition unchanged.
- No regression: R18 diagonal (0081) + the whole obstacle spine stay no-short; full `wireedit` suite
  + `--memcheck` green; **default-off byte-identical**; **release == stepwise**.
- Real-window eyeball on `src/xschem --script src/cadence_style_rc --logdir /tmp` (the acceptance
  gate): nudging a device a small amount next to a neighbour leaves a clean offset solder-joint, not
  a junction buried on the neighbour's pin (the Cadence parity bar).

## 6. RED-first test to start from

`test_wireedit_41_no_short_offset_solder`: build the before_3 scene in memory (R18 riser at x=-400,
visible T at (-400,140), short hop to v8.`plus` at -390; v8 pins on distinct nets). Drive a small
`+10 x` fluid stretch of R18 both **stepwise** and via **release**; assert:
- **P2/P1** hold (v8.plus ≠ v8.minus net; partition preserved) — GREEN today (this is a feel bug,
  not a short) so this is a guard-rail, not the discriminator;
- the **discriminator**: after the move a **visible junction exists offset from v8.plus** (a
  degree-3 vertex NOT coincident with the plus pin) and the riser column is **clear of v8's body
  bbox** (x < -390). RED at HEAD (riser translates to x=-390, junction collapses onto the pin),
  GREEN after the offset pass.
- release == stepwise (identical segset). Sabotage-verify: disabling the new offset pass flips the
  discriminator RED; port the **exact** before_3 geometry (autotrim cleans simplified scenes —
  `green-but-hollow`).

</details>
