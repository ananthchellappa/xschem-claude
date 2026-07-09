# 0092 — fluid reroute: an along-axis wire drag leaves an overshoot stub + solder dot instead of shoving the riser

Status: FIXED (2026-07-09)
Branch: fluid-editing
Repro: `tests/from_user/before_6.sch` → `tests/from_user/after_12.sch` (bad), `preferred_12.sch` (wanted)
Trace: `FLUID_TRACE=/tmp/fltrace_7_8_9.log` (the user's session)
Test: `tests/headless/wireedit/test_wireedit_49_axis_overshoot_0092.tcl` (RED-first)
Related: [0083](0083-fluid-offset-foreign-pin-landing.md) (the V-H-V riser-into-body offset, a sibling
rebuild), issue 0015 §7 `fluid_shove_connected_wire` (the pin-driven parallel-stub shove this generalises
to a wire grab), [0088](0088-fluid-reroute-redundant-samenet-loop.md)–[0091](0091-fluid-reroute-samenet-crosses-moved-body.md)
(the END same-net cleanup family this joins).

## Symptom

`before_6.sch` has R18's **M** pin fed by a 3-segment staircase on `#net1`:

```
  N -470  50 -360  50   H   (middle horizontal rung, grabbed)
  N -470  50 -470 140   V_L (left riser, up to the top rail)
  N -360  20 -360  50   V_R (pin riser, down to R18.M)
  N -550 140 -470 140 / N -470 140 -390 140   top rail (T-junction at -470,140)
```

Grab the middle horizontal rung and drag it up-and-to-the-**left**. Saved as `after_12.sch`:

```
  N -470  60 -360  60   H
  N -490  60 -470  60   <-- DANGLING OVERSHOOT STUB (tip -490,60 connects nothing)
  N -470  60 -470 140   V_L  (riser STILL at x=-470)
  N -360  20 -360  60   V_R
```

The leftward drag component (−20) produced a **dangling stub** `-490..-470` and a **solder dot** at
`(-470,60)` where H + stub + V_L meet, while the riser stayed at `x=-470`. The user wants the riser
**shoved** left to follow the drag (`preferred_12.sch`):

```
  N -490  60 -360  60   H     (single wire, stub absorbed)
  N -490  60 -490 140   V_L   (riser shoved to x=-490)
  N -550 140 -490 140 / N -490 140 -390 140   top rail (T-junction shoved to -490)
  N -360  20 -360  60   V_R
```

A single-gesture `grab (-460,50); drag (dx=-20,dy=+10)` reproduces `after_12.sch` byte-for-byte. A **pure**
along-axis `dx=-20,dy=0` reproduces the stub alone (the perpendicular component is always clean), so this
is an along-axis-drag defect, not a diagonal-decomposition one.

## Root cause — no shove reaches a WIRE-grabbed along-axis drag

* `compute_wire_slide` and `fluid_shove_connected_wire` both require the moving stub to have a **moving
  INSTANCE-PIN** endpoint (`point_on_moving_pin`). The user grabbed a **wire**, not a device, so no pin
  drives the stub and neither fires (both are inert by construction — issue 0014 anchors a wire grabbed at
  a junction).
* The 0088–0090 `straighten`/`loop` cleanups miss it: the overshoot tip is a **brand-new dangling end**
  (touch-degree 0), not the clean-corner jog (`fluid_deg_at == 1` each end) those passes collapse; and
  pass-2 orphan-retract requires the tip to have been a START **junction** (`fluid_start_deg_at >= 2`),
  which a fresh overshoot tip never was.
* Even if it matched, issue 0091's `prot[]` shields the **user's own grabbed net** from those passes —
  but removing drag-created overshoot *junk* on the grabbed net is exactly what the user wants here.

The right side of the same drag is clean because V_R's far end is R18.M — a fixed pin anchors H's right
endpoint at `x=-360`, so no overshoot forms there.

## Fix — `fluid_collapse_axis_overshoot_stub()` (move.c), a new END-time pass

For each **novel** (this-drag) dangling overshoot stub `S` collinear with a same-net continuation `H` at a
drag-created junction `J` that also carries **exactly one** perpendicular riser `V` (and nothing else):

* **SHOVE** (honours the drag): if `V`'s far corner `C` is not pinned and the reshape is
  partition-invariant and lands on no foreign copper, translate the riser column `{V, the arms at C}` by
  `(T − J)` and pull `H`'s and `S`'s `J`-endpoints to the stub tip `T`, so `S` collapses to zero length
  and `H` absorbs it → `preferred_12.sch`.
* **TRIM** (fallback): otherwise delete the dangling stub `S` (partition-verified), snapping `J` back —
  the only safe move when the riser is pin-anchored (a *rightward* drag past R18.M's own pin leaves a
  stub `-360..-340` that cannot shove the pinned V_R) or when a shove would short.

Every mutation is pin-partition VERIFIED against the pass-entry base (pure `touch()`, `node[]`-independent)
and reverted on any change, so no pin strands and no two nets merge; a foreign-wire touch by any shoved
segment (the pin-less-net short the partition can't see) also reverts. NOVELTY-scoped (a user's
pre-existing dangler/staircase is never touched) and a strict no-op otherwise. Deliberately does **not**
consult `prot[]` (unlike straighten): the target is always drag-created junk on the grabbed net.

Runs in the same 0091-relaxed END block, right after `fluid_straighten_reversals()`, gated on
`fluid_editing && stretch_select && rot==flip==0 && leg_ortho && final-leg`. Default `fluid_editing` off ⇒
never runs ⇒ byte-identical.

## Scope / known limitations (all never-worse: decline to baseline)

* First increment handles the single perpendicular riser at `J`. A `J` with extra copper, an `H` passing
  *through* `J` (mid-span tap), or a riser continuation collinear with `V` at `C` all DECLINE the shove
  (and fall through to TRIM only if a plain stub delete is partition-safe).
* Only auto (`#net`) copper is reshaped; an explicit user label on `S`/`H`/`V` declines (never rename a
  named net).
