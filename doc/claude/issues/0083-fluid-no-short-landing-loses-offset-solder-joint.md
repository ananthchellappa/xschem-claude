# Issue 0083 — fluid follow-set: a no-short landing onto a foreign pin loses the offset solder-joint and runs flush against the device body

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
