# Issue 0014 — dragging a wire drags the perpendicular junction wire (and beyond) when the junction has corners

**Opened:** 2026-06-19
**Status:** DIAGNOSED, not yet fixed — root cause pinned and confirmed by ablation
(see §4/§5); fix direction proposed in §7, awaiting a decision on approach.
**Affects:** interactive use with `cadence_compat` on (which now also enables
`autotrim_wires`, commit `808ad990`) — i.e. `src/cadence_style_rc`. Requires
`orthogonal_wiring` on (the Phase-4 corner-slide guard).
**Severity:** medium — connectivity/geometry surprise: a wire you drag pulls a
perpendicular wire (and its further-connected segments) along with it, when the
user expects the junction to stay anchored.
**Branch:** `fluid-editing`. Regression introduced by the interaction of two recent
changes: Phase-4 corner-slide (`75add456`, `compute_wire_slide`) and the
`cadence_compat → autotrim_wires` bundle (`808ad990`).
**Related:** [[wire-editing-on-move]] (Phase 4), issue 0013 (the previous
feature-interaction cascade), `code_analysis/wire_editing_spec_and_plan.md`.

A tutorial follows in §8.

---

## 1. Reproduction

With `cadence_compat`/`enable_stretch`/`orthogonal_wiring` on (so `autotrim_wires`
is also on), build the user's "reverse-C" and drag the right-hand prong **H**
horizontally:

```
  seg1 (-40,40)──(0,40)        ┐ top arm
                    │
   V (0,40)─────────(0,-40)    │ vertical spine, split by autotrim at J into
                    │            two halves: (0,0)-(0,40) and (0,-40)-(0,0)
                    ●  J=(0,0)──(40,0)  H   ← T-junction at V's midpoint
                    │
  seg2 (-40,-40)──(0,-40)      ┘ bottom arm
```

Grab **H** by its body and drag it +40 in x.

- **Observed:** V (both halves), the junction J, and **H** all translate +40; the
  two arms stretch to follow. The entire structure moves with H.
- **Expected:** J and V stay put; only **H** changes (it stretches from J, or at
  worst translates and disconnects) — the perpendicular wire is anchored at the
  junction.

Exact geometry (headless, real gesture via `xschem callback`):

| | before | after |
|---|---|---|
| seg1 | `(-40,40)-(0,40)` | `(-40,40)-(40,40)` (stretched) |
| seg2 | `(-40,-40)-(0,-40)` | `(-40,-40)-(40,-40)` (stretched) |
| V-top | `(0,0)-(0,40)` | `(40,0)-(40,40)` (**translated**) |
| V-bottom | `(0,-40)-(0,0)` | `(40,-40)-(40,0)` (**translated**) |
| H | `(0,0)-(40,0)` | `(40,0)-(80,0)` (**translated**) |

---

## 2. The decisive differential

Three knobs decide whether the bug fires. Holding the gesture fixed and toggling
each:

| Config | autotrim | `compute_wire_slide` | Result |
|---|---|---|---|
| **simple** V/J/H (no arms) | on | on | H stretches, J/V fixed ✓ |
| **reverse-C** (arms) | on | on | **everything translates with H** ✗ |
| reverse-C | **off** | on | V/arms fixed, H translates (disconnects) ✓-ish |
| reverse-C | on | **off** | **H stretches, V/J/arms fixed** ✓ (desired!) |

Reading the table:

- The bug needs **all three**: `autotrim` (to split V at J), the **arms** (to make
  the split halves' far ends into corners), and **`compute_wire_slide`** (to act on
  them). Remove any one and it's gone.
- The last row is the tell: with the Phase-4 corner-slide disabled, the reverse-C
  produces *exactly the desired behavior*. So `compute_wire_slide` is the proximate
  cause.

---

## 3. Why the simple case already works, and the arms break it

The difference is entirely at the **far ends** of the split V-halves:

- **simple V/J/H:** V splits into `(0,0)-(0,40)` and `(0,-40)-(0,0)`, whose far
  ends `(0,±40)` are **free** (nothing else there). The corner-slide rule requires
  a corner (another wire) at the far end, so it does **not** promote them → they
  stay put → H alone changes.
- **reverse-C:** the same far ends `(0,±40)` now meet the **arms** (seg1/seg2) →
  they *are* corners → the corner-slide promotes the V-halves to translate, and the
  translation cascades into J, H and the arms.

So the arms don't change what gets *grabbed*; they change what the corner-slide
decides to *promote*.

---

## 4. Root cause (instrumented, confirmed)

The chain, with the wire `sel` flags captured at move END
(`SELECTED=1` full, `SELECTED1=2` point-1, `SELECTED2=4` point-2):

1. **autotrim splits V at J.** Because `cadence_compat` now enables
   `autotrim_wires`, the T-junction where H meets V's midpoint is auto-split: V
   becomes two wires, each with an **endpoint exactly at J=(0,0)**.
2. **The body-drag fully selects H** (`sel=1`).
3. **`select_attached_nets()` grabs the V-halves.** Its wire→wire loop scans the
   endpoints of the fully-selected H; at H's J-end `(0,0)` it finds the two
   V-halves' coincident endpoints and partially selects them
   (`V-top sel=2`, `V-bottom sel=4`). *(This is why `xschem objects -selected`
   listed only H — that query surfaces full selections, not `SELECTED1/2` partials;
   the instrumentation showed the partials.)*
4. **`compute_wire_slide()` promotes them.** Both V-halves are vertical = perpendicular
   to the horizontal move, partially selected, far ends `(0,±40)` are **not** on a
   fixed pin and **do** form corners with the arms → the Phase-4 rule promotes each
   to a **full (translating) selection** and propagates the move into the arms.
   Instrumented: `CWS-PROMOTE wire 1 far=(0 40)` and `CWS-PROMOTE wire 4 far=(0 -40)`.
5. With V-top, V-bottom and H all fully selected, the commit translates them +40 and
   stretches the arms. → V, J and everything slide with H.

The semantic error: `compute_wire_slide` was designed and tested for **instance
moves** (TC6) — a perpendicular stub attached to a moving *pin* slides with the pin.
Here the perpendicular wires are attached not to a moving pin but to the **dragged
wire's own endpoint at a junction**. The rule treats the junction wires like
pin-stubs and slides them, when they should be anchored at J.

---

## 5. Ablation proof

Disabling just the `compute_wire_slide()` call (everything else identical) turns the
reverse-C result into the desired one:

```
before: seg1 seg2 V-top(0 0 0 40) V-bottom(0 -40 0 0) H(0 0 40 0)
after : seg1 seg2 V-top(0 0 0 40) V-bottom(0 -40 0 0) H(0 0 80 0)   # H stretches, rest fixed
```

So no other mechanism (select_attached_nets, kissing, autotrim) needs changing to
get the desired behavior here — the fix belongs in the corner-slide's promotion
rule.

---

## 6. Desired behavior / acceptance

- Dragging a wire **H** that terminates on a perpendicular wire **V** at a junction
  **J** must leave **J and V fixed**; only H changes. This holds **regardless** of
  what is further connected to V (free ends, arms, more corners).
- The Phase-4 **instance** corner-slide (TC6) must keep working: moving an instance
  whose pin drags a perpendicular stub still slides the stub.
- No accidental net merges; undo restores exact geometry.

(Separately and already correct: a *body*-drag of H **toward** J carries H through J
and it **protrudes** on the far side — H translates, J/V fixed. The "clamp at J / no
protrusion" rule applies only to the *other* gesture, grabbing H's far **vertex**
via `edit_wire_point` and moving it toward J. That clamp is a separate possible
enhancement, not part of this defect.)

---

## 7. Fix direction (proposed — not yet implemented)

The promotion in `compute_wire_slide` is too broad: it slides any perpendicular
partially-selected wire that corners at its far end, regardless of *what drove* its
moving endpoint. Candidate discriminators, narrowest first:

- **(a) Slide only pin-driven stretches.** Promote a perpendicular wire only if its
  *moving* endpoint sits on a **moving instance pin** (the TC6 case). A wire whose
  moving endpoint was grabbed because it coincides with the **dragged wire's**
  endpoint (a wire-wire junction) is anchored, not slid. This directly encodes the
  design intent and excludes the reverse-C exactly.
- **(b) Don't slide across a junction with the dragged object.** If a perpendicular
  wire's moving endpoint coincides with a fully-selected (dragged) **wire's**
  endpoint, leave it partial (anchor at the junction).
- **(c) Gate corner-slide to moves that include a selected instance.** Coarsest;
  would disable corner-slide for pure wire drags entirely. Simplest but also
  forecloses any future "drag a wire, slide its corner" behavior.

(a) is the most faithful to the corner-slide's purpose and is the recommended
starting point; it should be expressible as a check at the top of the
per-wire loop in `compute_wire_slide` (is this wire's selected endpoint on a moving
instance pin?). A RED test mirroring §1 (reverse-C drag → J/V fixed) plus the
existing TC6 (instance corner-slide still works) are the two poles to satisfy.

---

## 8. Tutorial — a heuristic validated on one gesture class, leaking into another

### 8.1 The shape of the bug: a feature interaction, not a single fault

Nothing here is individually wrong. `autotrim_wires` correctly splits a wire at a
T-junction. `select_attached_nets` correctly grabs wires whose endpoints coincide
with a dragged wire's endpoint. `compute_wire_slide` correctly slides a perpendicular
stub off a corner. The defect lives in the **composition**: autotrim *manufactures*
the endpoints at J that let `select_attached_nets` grab V, and the arms *manufacture*
the corners that let `compute_wire_slide` promote it. Three correct rules, composed,
produce a wrong outcome.

> **Paradigm — bugs hide in the seams between correct features.** When you add a
> feature, the question is not only "is it correct in isolation?" but "what new
> inputs does it now hand to features downstream?" Autotrim's split is a *new input*
> to the selection logic; the selection is a *new input* to the corner-slide. This
> is the second feature-interaction defect in this work (issue 0013 was the first),
> and the pattern is worth naming: each feature is a correct function; the system is
> their composition, and composition is where untested combinations live.

### 8.2 The corner-slide's hidden precondition

`compute_wire_slide` was built and tested against **TC6** — an *instance* move whose
pin drags a stub. Its promotion rule ("perpendicular + far-end corner + far-end not a
fixed pin → translate") quietly assumed the thing being dragged was an instance pin.
That assumption was never written down because, at the time, the only caller that
produced perpendicular partial selections *was* an instance move. The
`cadence_compat → autotrim` bundle then introduced a *second* way to get a
perpendicular partial selection — a wire-wire junction — and the unwritten
precondition was silently violated.

> **Paradigm — a heuristic carries the assumptions of the cases you validated it on.**
> TC6 validated corner-slide on pin-driven stretches; the rule generalized itself to
> *all* perpendicular stretches the moment a new source of them appeared. When you
> codify a heuristic, write down the gesture class it was meant for, and guard for it
> — otherwise the next feature that produces the same intermediate state inherits the
> behavior whether it should or not.

### 8.3 Ablation beats inspection for a multi-feature bug

The decisive move here was not reading code — it was the **truth table** in §2:
hold the gesture fixed, toggle one feature at a time, watch the outcome. That
isolated the culprit (`compute_wire_slide`) and the enablers (autotrim + arms) in
four runs, before any hypothesis about *why*. Only then did instrumenting the `sel`
flags confirm the exact chain.

> **Paradigm — for an interaction bug, bisect the feature set, not just the code.**
> A breakpoint tells you *what* executed; a one-feature-at-a-time ablation tells you
> *which feature's presence is necessary*. The latter localizes a composition bug
> faster, and its table doubles as the regression matrix.

### 8.4 The query that lied (a smaller lesson)

`xschem objects -selected` reported only H, which would have sent a code reader
hunting for how the *other* wires moved without being selected. They *were* selected
— partially (`SELECTED1/2`) — but the query surfaces only full selections. The
instrumented `sel` dump corrected it.

> **Paradigm — know what your observability tool omits.** A view that silently drops
> a category (here, partial selections) is worse than no view, because it actively
> misleads. When a query's answer contradicts the behavior, suspect the query's
> filter before the behavior.

### Takeaways to carry forward

1. Correct features compose into incorrect systems; test the *combinations* a new
   feature enables, not just the feature.
2. A heuristic inherits the assumptions of the cases it was validated on; write the
   intended gesture class down and guard it.
3. Ablate features one at a time to localize an interaction bug; the truth table is
   also the regression matrix.
4. Know which categories your observability tools silently omit.
