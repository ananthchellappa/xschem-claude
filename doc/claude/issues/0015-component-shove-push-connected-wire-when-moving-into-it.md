# Issue 0015 — moving a component toward a connected perpendicular wire should PUSH the wire, not cross it

**Opened:** 2026-06-19
**Status:** OPEN — **deferred** (feature, not a regression). Specified here; not yet
implemented. Scoped out of issue 0014 deliberately.
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
