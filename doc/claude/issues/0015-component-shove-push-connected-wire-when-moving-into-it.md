# Issue 0015 — moving a component toward a connected perpendicular wire should PUSH the wire, not cross it

**Opened:** 2026-06-19
**Status:** IMPLEMENTED 2026-07-06 (commit `897b3133`, branch `fluid-editing`) →
**SHOVE** (occupancy model), behind `fluid_editing`. `fluid_shove_connected_wire()`
in `move.c` at the pre-trim commit seam; tests `test_wireedit_37` (positive) +
`test_wireedit_38` (decline guards). See §7 for the design; §8 for the build notes.
Was DECIDED 2026-07-06, before that OPEN/deferred (scoped out of issue 0014).
**Affects:** interactive use with `cadence_compat` / `enable_stretch` /
`orthogonal_wiring` (stretch-move of an instance).
**Severity:** low — current behavior keeps connectivity correct; this is an
ergonomics/aesthetics gap, not a wrong netlist.
**Branch:** `fluid-editing`.
**Related:** [[wire-editing-on-move]]; issue 0014 (the wire-drag junction fix, the
*opposite* gesture); `compute_wire_slide` in `move.c` (the corner-slide, of which
this is the structural inverse); requirement R7/R8 family.

A tutorial / design note follows in §6.

---

## 1. Setup

An instance is connected to a perpendicular wire **V** by a horizontal **stub H**:

```
   V (vertical, with arms = a "reverse-C")
   │
   ●────────[ INST ]      H is the stub from J to the instance pin
   J                      instance sits to the right of J, on H's far end
   │
```

The instance is dragged **horizontally**, i.e. *along* the stub H — toward or away
from V. (This is distinct from TC6, where the instance moves *perpendicular* to its
stub and the corner slides sideways.)

---

## 2. Desired behavior

| Move | Desired |
|---|---|
| **Away** from J | the stub **H stretches**; V and J stay fixed |
| **Toward** J (and past) | the instance **pushes V ahead of it** ("shove"); the instance does **not** cross V; the connection is kept with the stub at ~zero length |

The away half is already correct (see §3). The toward half is the new behavior.

---

## 3. Current behavior (measured)

Headless, instance pin at `(40,0)` on stub `H = (0,0)-(40,0)`, V a reverse-C at
`J=(0,0)`:

- **Away (+40):** `H` → `(0,0)-(80,0)`; V halves and arms unchanged. ✅ matches desired.
- **Toward (−60):** the instance **crosses** V; `H` flips to a left stub
  `(-20,0)-(0,0)`; V stays at `x=0`. ❌ desired is V pushed to `x=-20`.

So only the **toward** direction needs work. Note the current result is
electrically fine (pin still connected to J via the flipped stub) — it just looks
wrong: a solid component slid straight through a wire.

This case is **not** touched by the issue-0014 fix: when the instance sits at H's
*far* end, V is never selected (only the pin-end of the parallel stub H is grabbed),
so `compute_wire_slide` has nothing to act on. The behavior is identical with or
without that fix.

---

## 4. Why this is the opposite rule from issue 0014

The two "toward" cases look similar but want opposite outcomes, and the distinction
is physical:

| You drag… | toward a perpendicular wire | because |
|---|---|---|
| a **wire** (issue 0014) | it **protrudes through** (reverse-E); the wire stays | two wires may overlap — they just connect at the crossing |
| a **component** (this issue) | it **pushes** the wire ahead; no crossing | a component is a solid body; it cannot occupy the wire's location, so it shoves |

Keeping these two consistent is the design's job: *wire-into-wire crosses;
component-into-wire shoves.*

---

## 5. Implementation sketch (for whoever picks this up)

Structurally this is the **inverse of `compute_wire_slide`**, and would likely be a
sibling pass at `move_objects(END)`:

- **Trigger:** a moving instance pin whose move vector is **parallel** to a connected
  stub, where continuing the move would carry the pin **onto or past** a connected
  perpendicular wire V.
- **Action:** translate V by the **overrun** — the amount the pin travels past V's
  line — so V stays just ahead of the pin (or exactly at it), keeping the stub at
  zero/near-zero length. Propagate to V's neighbours (the arms) so they stretch,
  exactly as corner-slide does.
- **Open questions to decide first (write the test from the answer):**
  1. Does the shove start the moment the pin reaches V, or only once it would pass?
  2. Stub length after the shove — zero, or preserve a one-grid exit stub (cf. the
     Phase-6 exit-stub idea, issue/spec)?
  3. Chains — if V is itself connected onward, how far does the shove propagate?
  4. Multiple wires in the pin's path — push all, or only the connected one?
  5. Undo fidelity and "no accidental net merge" must hold (R16/R17).
- **Guards that must stay green:** TC6 (perpendicular instance corner-slide),
  TC17 (wire-drag junction stays anchored), the away half of this case, golden +
  stable_handles.

A RED-first test mirroring §3's toward case (assert V ends at the pushed x, stub
collapses, arms stretch) is the natural starting point.

---

## 6. Design note — "what can share a location?" decides cross-vs-shove

The whole cross-vs-shove question reduces to one modelling fact: **what two things
are allowed to occupy the same point.** Two wires can — a coincident point is just a
connection. A component and a wire's mid-span cannot — the component is a solid
region. Once that rule is stated, both behaviors fall out of it: drag a wire into a
wire and they merge at the overlap (cross); drive a solid into a wire and the wire
must yield (shove).

> **Paradigm — derive interaction rules from an occupancy model, not case-by-case.**
> It is tempting to enumerate gestures ("wire toward wire → X", "instance toward wire
> → Y") and hard-code each. But they are consequences of a single rule about which
> objects may share space. Encoding the *rule* (solids displace, wires merge) keeps
> the many gestures consistent and predicts cases you haven't enumerated yet — e.g.
> dragging two abutted components, or a component toward a *parallel* wire. When you
> implement the shove, anchor it to the occupancy rule, not to this one fixture.

Until then, the current cross-through is a safe, connectivity-preserving placeholder.

---

## 7. DECISION (2026-07-06) — SHOVE, anchored to the occupancy model

**Chosen: component-into-connected-wire SHOVES** (away = stretch, unchanged). The
moved instance pushes the connected perpendicular wire ahead of it; it never crosses.
Anchored to the §6 occupancy rule — *a solid body (instance + pins) may not occupy a
wire's location; a **connected** wire yields, an **unconnected** wire is an obstacle* —
not to this one fixture.

**Why (not merely ergonomics):**
- Cadence shoves; this project targets Cadence fidelity.
- It resolves the `tests/from_user/before_1.sch` feel-test failure directly: dragging
  R18 down drives its M pin along its stub *past* the connected horizontal wire.
  Today's pure-stretch lays a **reversed stub back through R18's own body**
  (the reported intrusion); the shove keeps the wire one exit-stub ahead of the pin,
  so the stub is always outward — never reversed, never through the body. The
  user's hand-authored `desired_beautified_1.sch` **is** the shove result. So shove
  also closes the *connected-wire* slice of P5 (own-body no-cross) for free.

**Sub-decisions (§5 open questions, resolved):**
1. **When** — shove engages when the pin would reach/cross V (overrun ≥ 0). Below
   that the stub just shortens. Invariant: V is kept one exit-stub-length ahead of the
   pin on the drive side; the pin never crosses V.
2. **Stub length** — preserve a **one-grid exit stub**, not zero. Reuses
   `insert_exit_stubs` / P3 escape-perp; a zero-length stub = pin sitting on the wire =
   invisible/ambiguous junction (same reason Layer-2 offsets the solder joint one grid).
3. **Chains** — shove **only the directly-connected** perpendicular wire V; its arms
   stretch (exactly like `compute_wire_slide`). **No transitive propagation** past
   further junctions — one level. If an arm then collides, that is the obstacle layers'
   job (decline/detour), not a deeper shove.
4. **Multiple wires in the path** — shove **only connected** wires (the follow-set /
   terminal). An **unconnected** wire the pin drives toward is an **obstacle** handled
   by the already-shipped no-short / stop-short / detour layers (Layers 1–3) — never
   shoved (moving a foreign net would be wrong and could short).
5. **Undo / no-merge (R16/R17)** — reuse the incremental pipeline's single-undo entry
   + P1/P2 guards. The yield target is the connected same-net wire, so no distinct-net
   contact is created by construction.

**Home / integration.** The original §5 sketch ("sibling pass at `move_objects(END)`")
is **superseded**: implement in the **per-snap-step fluid reroute pipeline**
(`move.c` `fluid_reroute_*`), as a new layer alongside Layers 1–3, so the wire visibly
slides ahead *during* the drag (fluid feel), and release==stepwise holds for free.
Gate on `fluid_editing` (default-off byte-identical), same as Layers 1–3.

**Conflict order** unchanged (P1=P2 > P3 > P5 > P4 > P7 > P6): shove serves P1 + P5 +
aesthetics and must not manufacture a P2 short (guaranteed — it only relocates the
connected same-net wire; arm collisions defer to the obstacle layers).

**Deferred within the shove** (predicted by the occupancy model, not built now):
component-toward-*parallel* wire, and two-abutted-components. Placeholder cross-through
stays until the shove layer lands. **Diagonal (non-axis-aligned) drag-toward is gated
out** (`dxnz == dynz` bail, mirroring `compute_wire_slide`) and tracked separately in
**issue 0081** (per-axis X-then-Y decomposition).

---

## 8. Implementation notes (commit `897b3133`)

Approach **B** (design workflow `wf_7c208608` + judge): a new sibling pass
`fluid_shove_connected_wire()` at the shared pre-trim commit seam next to
`fluid_reroute_around_obstacles` — **zero shipped-function-body edits**, one call
line. Runs for both a real END and a live RUBBER step ⇒ release==stepwise; gated on
`fluid_editing && stretch_select && rot==flip==0` ⇒ default-off byte-identical.

It **post-detects** the reversed stub `place_moved_wire` just laid (a parallel
single-endpoint stub is always relaid as one straight wire), finds the connected
perpendicular V at a clean corner J, sets `J' = pin + one grid outward`, translates
V wholesale by `J'-J`, drags one level of arm endpoints at V's far corner C, and
relays the stub as the one-grid outward exit stub.

**Adversarial review** (`wf_44288957`, 6 lenses) found the naive shove shorted/
disconnected on messy topologies. Guards added, each **collective-sabotage verified**
(with all guards off the review scenes fail 5 checks; with them, green):
- **clean SPAN of V** — decline if a wire taps V's interior (would strand → P1) or a
  collinear wire sits at C (an autotrim split of V; the arm-drag would bend it → P4);
- **P2 on new S / new V / each dragged arm** vs stationary foreign device pins
  (`fluid_seg_hits_foreign_pin`), co-moving distinct-net pins
  (`fluid_seg_hits_moving_pin`, mirroring Layer 3), and stationary foreign-net WIRES
  (new `fluid_seg_hits_foreign_wire`, closing the pin-only P2 gap).
Every guard **declines to baseline** (never worse). `prepare_netlist_structs(0)` is
called once at entry so the wire-level P2 guard sees pre-move net names.

**Process note:** a review subagent ran `git reset --hard` in the shared worktree
mid-run and wiped the then-uncommitted implementation; it was restored from context.
Lesson: commit before spawning tree-mutating subagents, or isolate them in a worktree.
