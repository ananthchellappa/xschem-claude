# Spec: "Nice" multi-pin drag rerouting

Status: **DRAFT / not started** (2026-07-05, branch `fluid-editing`). Written after the
narrow single-pin case landed (net-label mid-span tap, FAQ Q27, commits `d5163559` /
`6925e724`). This spec generalizes that to the hard case: **dragging an instance with
several connected pins and getting a good-looking, electrically-safe result.**

Prereq reading: `doc/claude/specs/wire_segment_splitting.md`,
`doc/claude/code_analysis/wire_editing_spec_and_plan.md`,
`doc/claude/code_analysis/wire_follow_stretch_move.md`, `doc/claude/FAQ.md` Q26/Q27.

---

## 1. Problem statement

When the user drags an instance, the wires attached to its pins must follow. Today this is
done by a set of interacting local rules at move START/END:

- `select_attached_nets()` (select.c) — grab wires whose endpoint sits on a moved pin.
- `connect_by_kissing()` (actions.c) — drop a stub where a moved pin abuts a pin / touches a
  wire mid-span.
- `place_moved_wire()` (move.c) — per-wire orthogonal jog for a single moved endpoint.
- `compute_wire_slide()` (move.c) — corner-slide: translate a perpendicular wire whose far
  end forms a corner, dragging neighbours (Issue-D fix).
- release-time cleanup: `trim_wires()`, `remove_move_orphan_wires()`, `merge_collinear_wires()`.

These are **one-way constraint-propagation rules**, cheap and local. They work for simple
cases but their pairwise interactions explode: the single-pin bug we just fixed was
`split × slide × kissing` producing a U-detour. For a **multi-pin** instance the result is
frequently not "nice": stubs go the wrong way, bundles cross the body, collinear runs get
dragged, and — worst — two different nets can end up coincident (a silent short).

This is not an xschem-specific accident. It is a recognized class:

- **HCI:** direct manipulation with *semantic snapping / augmented feedback* (Bier & Stone,
  snap-dragging); the Cadence term is **rubber-band routing**. The system must repair derived
  structure (wires) silently while keeping the manipulated object responsive and the user's
  mental model intact.
- **CS:** *constraint maintenance under perturbation* (Sketchpad → ThingLab → one/multi-way
  constraint solvers) **combined with** *incremental orthogonal (Manhattan) rip-up-and-reroute*
  (VLSI/PCB detailed routing, pin **escape routing**) **under** a *net-separation / planarity*
  constraint (no shorts). General detailed routing is NP-hard → heuristic + local solver.

One line: **interactive, constraint-preserving, incremental rip-up-and-reroute of orthogonal
wiring under direct manipulation, with pin-escape and net-separation constraints.**

## 2. Why multi-pin is not "single-pin × N"

The net-label case is degenerate: one pin, zero body extent, no escape direction. A real
instance adds four couplings that single-pin lacks:

1. **Rigid bundle** — all pins of the instance translate together; their wire re-routes
   interact (a shared move delta, not independent).
2. **Body as obstacle** — a wire may not cross the instance body; a pin on the "far" side must
   escape perpendicular, then detour around the body.
3. **Escape collisions** — two escapes from the same edge, or from adjacent edges, compete for
   the same channel → need lane assignment / net ordering (which wire bends first / routes
   "outside").
4. **Global no-short** — after the move the whole moving bundle plus everything it slides past
   must have no distinct-net coincidence (the H2/H3 hazards from wire-splitting, now global).

So each drag is a **local detailed-routing subproblem**, not a set of independent jogs.

## 3. Model & terminology

- **Instance** `xInstance`; its **pins** are `PINLAYER` rects, world coords via
  `get_inst_pin_coord(inst, r, &x, &y)`.
- **Pin edge** — the side of the instance bbox the pin lies on. **Escape normal** — the
  outward unit direction perpendicular to that edge (see §6, an open sub-problem).
- **Attached wire** — a wire with an endpoint on a pin (grabbed by `select_attached_nets`), or
  a wire the pin touches mid-span (handled by `connect_by_kissing`).
- **Anchor** — the far (non-moving) endpoint of an attached wire, or the fixed object it
  connects to. Must stay put (connectivity).
- **Leg** — a maximal straight segment of a routed wire. **Bend** — a leg junction.
- **Net** — resolved via `prepare_netlist_structs()`; distinct nets must never coincide.
- **Move axis** — pure `deltax` xor `deltay` for the common orthogonal drag (rotations/flips
  and diagonal moves are separate, lower-priority cases).

## 4. "Nice" — formal predicates

The whole point: turn the subjective word "nice" into **testable predicates** `P(before, after)`.
Split into **hard invariants** (never violate) and **quality objectives** (optimize, may trade
off). Every phase in §8 lands exactly one predicate with a RED-first test.

Hard (correctness — a violation is a bug, block/undo the move rather than ship it):

- **P1 Connectivity (INV-1):** `netlist(after) == netlist(before)`. No pin loses/gains a net.
  Test: `instance_nodemap` / `resolved_net` byte-identical before vs after.
- **P2 No-short:** for every pair of wires on **distinct** nets, no `touch()` / overlap /
  coincident collinear run. Moving must not merge two nets. Test: enumerate wire pairs, assert
  distinct-net pairs never `touch()`.

Quality (optimize; ordered by priority when they conflict):

- **P3 Pin-escape:** the first leg of every wire leaving a moved pin is **perpendicular to the
  pin's edge**, length ≥ `Lmin` (grid-multiple), and does **not** re-enter the instance bbox.
- **P4 Orthogonality:** every leg is axis-aligned (when `orthogonal_wiring`).
- **P5 No body crossing:** no wire leg passes through the instance bbox interior.
- **P6 Minimality:** minimize Σ bends, then Σ length, over routes satisfying P1–P5.
- **P7 Stability:** wires/nets **not** attached to the dragged instance are left byte-identical
  (don't reroute the world; keep the diff local and the user's mental model intact).
- **P8 Determinism:** same drag ⇒ same result (no dependence on iteration order / hash order).

Conflict order when quality objectives fight: **P1 = P2 > P3 > P5 > P4 > P7 > P6**. (Escape
direction beats a bend saved; never short to save a bend.)

## 5. Solution architecture — hybrid

Two families, use both:

**(a) Fast rule-based path** (what exists). `place_moved_wire` + `compute_wire_slide` +
`connect_by_kissing` + cleanup. O(pins). Keep it for the common, non-interacting case
(pins whose escapes don't collide and whose runs aren't shorted). Cheap, already shipped,
byte-stable when off.

**(b) Local solver fallback** for the hard sub-region. Trigger when the fast path violates a
predicate: P2 short detected, OR P3 escape violated, OR two escapes collide, OR a wire crosses
the body. Then, on **only the affected sub-region** (the moving bundle + wires within its
bounding box), run a cost-minimizing **rip-up-and-reroute**:

```
minimize   wb·Σbends + wl·Σlen + We·escapeViol + Wbody·bodyCross + Wshort·shortViol
subject to P1 (connectivity), Wshort = +inf (P2 hard)
over       discrete orthogonal route topologies of the affected wires
```

Solver = A*/Lee on a **routing grid** built from: pin escape points, anchors, obstacles
(instance bodies, fixed pins, other-net wires), net-ordered by a cheap heuristic (bounding-box
/ left-edge). Small bundle (≤ ~6 nets) → ILP is feasible if A* net-ordering is unstable. This
cleanly separates **what is nice** (the cost fn / P-predicates) from **how to achieve it** (the
solver) — which is exactly what stops the rule-interaction blowup.

**(c) Interactive layer.** Live drag preview showing the proposed reroute; user can nudge /
override / cycle candidate topologies (Cadence lets you cycle route "corners"). Commit on
release. Escape hatch: hold a modifier to fall back to rigid move (no reroute).

Recommended staging: harden the fast path to *detect* its own failures (predicates as guards),
ship the solver behind them, add the interactive layer last.

## 6. Open sub-problem: escape normal

P3 needs each pin's outward normal. The Phase-6 exit-stub work
(`wire_segment_splitting` memory) derived it from the **dominant axis of (pin − bbox
centroid)** and found it **crude**: pin-name text skews the centroid, asymmetric symbols
mislead it. Better sources, in preference order:

1. The pin rect's own geometry relative to the nearest bbox edge (which edge is the pin
   touching / closest to) → the normal is that edge's outward direction.
2. An explicit per-pin `dir`/`side` property in the symbol (schema addition; cleanest, but
   needs library migration — cf. `cadence_pin_name_text`).
3. Centroid heuristic as last-resort fallback.

Decide this early (Phase 2): unit-test the normal across a spread of real symbols before
building routing on top of it.

## 7. Golden-oracle harness

"Nice" is subjective, so **pin it with hand-authored examples** before writing any router.
For each fixture, author the desired `.sch` by hand (the "oracle"). Reuse the existing headless
harness (`tests/headless/wireedit/`, `tests/headless/test_wire_split.tcl`): build in memory,
drive `move_objects dx dy stretch kissing` (byte-identical to the interactive drag per
`wire_editing_spec_and_plan.md`), read back geometry via `wire_coord` / `saveas` parse, assert
the P-predicates. Predicate library as Tcl procs: `p1_netlist_invariant`, `p2_no_short`,
`p3_escape_perp`, `p4_orthogonal`, `p5_no_body_cross`, `p6_bends_len`, `p7_stability`.

Fixture matrix (grow as needed):

| # | fixture | exercises |
|---|---------|-----------|
| F1 | 1-pin net-label mid-span tap | regression of the shipped fix (P1,P2,P3) |
| F2 | 2-pin res, both pins on wires, drag ⟂ | independent escapes, no collision |
| F3 | 2-pin, both pins same edge, drag along | escape collision / lane order (P3) |
| F4 | pin behind body relative to anchor | body-detour escape (P5) |
| F5 | two adjacent nets, drag toward | no-short (P2) — the hazard case |
| F6 | pin on a through-run (rail) | tap-vs-run, must not drag run (FAQ Q27) |
| F7 | bus pin `[N:M]` | prop preservation (`bus=`), P1 with buses |
| F8 | 4-pin device (e.g. mos), mixed edges | full bundle, lane assignment, P6 |
| F9 | drag AWAY vs TOWARD a fixed pin | escape length, shove vs stretch (issue 0015) |

Each fixture also gets a **negative/sabotage** variant proving the check has teeth (cf.
[[green-but-hollow]] discipline).

## 8. RED-first phase plan

One predicate per phase, one commit each, sabotage-verified, gated behind
`cadence_compat`/`fluid_editing` (default off ⇒ stock byte-identical). Follows the cadence of
`wire_segment_splitting.md` (W0–W7) and `wire_editing_spec_and_plan.md` (TC1–TC19).

- **Phase 0 — oracle harness.** Fixtures F1–F9 + predicate library `p1..p7` + hand-authored
  golden `.sch`. Assert-only against current behaviour → record the RED/GREEN map (expect
  F1/F6 GREEN from the shipped fix; F3/F4/F5/F8 RED). No behaviour change.
- **Phase 1 — invariants as guards.** Wire P1 + P2 as *runtime* checks at move END (debug/assert
  build), so any reroute that shorts or disconnects is caught. Foundation for the solver.
- **Phase 2 — escape normal.** Implement the per-pin outward normal (§6) + unit tests across
  real symbols. Deliverable: `get_pin_escape_normal(inst, r, &nx, &ny)`.
- **Phase 3 — single-pin nice escape.** Generalize the net-label fix: ⟂ stub of length `Lmin`,
  then orthogonal L/Z route from stub-end to anchor, body as obstacle. Lands P3+P4+P5 for the
  1-pin instance (F2 subset). Reuse `place_moved_wire` shape logic.
- **Phase 4 — no-short guard + rip-up.** Detect distinct-net coincidence (reuse `touch()` +
  net compare, the H2/H3 machinery), and rip-up-reroute the offender. Lands P2 for the
  moving bundle (F5).
- **Phase 5 — bundle / lane assignment.** Rigid group of pins moving together; order escapes so
  bundles don't cross the body or each other; assign channels. Lands P3/P5/P6 for multi-pin
  (F3, F8).
- **Phase 6 — local solver fallback.** Cost fn (§5) + local A*/Lee rip-up-reroute over the
  affected sub-region when the fast path fails a predicate. Lands P6 optimality + the hard
  residue of F4/F8.
- **Phase 7 — cleanup + stability.** Ensure P7 (untouched wires byte-identical) and P8
  (determinism); wire in existing `trim_wires` / `remove_move_orphan_wires` /
  `merge_collinear_wires`. Re-run the whole golden matrix.
- **Phase 8 — interactive preview** (optional, behind switch). Live reroute preview + candidate
  cycling + rigid-move escape modifier.

Between phases: run the golden matrix + `wireedit` TC0-19 + `test_wire_split.tcl` (W0-W7) as
non-regression guards, and the golden netlist harness for INV-1.

## 9. Test / API notes (from the shipped work)

- `move_objects dx dy stretch kissing` == the cadence interactive drag's release, byte-identical
  → headless tests are faithful. Bare `move_objects dx dy` = plain move (no follow).
- Net identity for tests: `resolved_net 0` then `getprop wire <i> lab` (bare token); do **not**
  use `resolved_net`'s return value (adds inconsistent hierarchy prefix). `instance_nodemap
  <name>` for INV-1.
- Gesture (real callback) tests need a real X display and flake under WSLg (rerun 2-3×); prefer
  the scripted `move_objects` path for determinism.
- `wire_coord <i>` returns endpoints in a fixed but not-canonical order → normalize endpoint
  order before set-compare.
- Gate on `cadence_compat` / `autotrim_wires` / `orthogonal_wiring` / `fluid_editing`; default
  off must stay byte-identical (golden harness is the authoritative guard).

## 10. Decisions for the user (resolve before Phase 3)

1. **Escape normal source** (§6): pin-edge geometry vs explicit symbol `dir` property (library
   migration) vs centroid fallback.
2. **Solver scope** (§5b): rule-only (ship fast path + guards, punt hard cases to the user) vs
   full local solver. Cost vs polish.
3. **Shove vs stretch** on drag-toward (issue 0015): does a moved instance push a perpendicular
   wire ahead, or cross through it? (Occupancy model.) Affects P5.
   → **DECIDED 2026-07-06: SHOVE** (connected wire yields; unconnected = obstacle). Anchored
   to the occupancy model; resolves the `before_1` own-body intrusion. Implement as a new layer
   in the per-snap-step fluid reroute pipeline (not a release-only pass). Full resolution +
   5 sub-decisions in issue 0015 §7.
4. **Interactive preview** (Phase 8): worth it, or commit-on-release only?
5. **Default on?** Or keep behind `fluid_editing` indefinitely (Phase 6 exit-stub was deferred
   after eyeballing — real-schematic feel is the acceptance gate, not headless green).

## 11. References

Code: `move.c` (`place_moved_wire`, `compute_wire_slide`, `point_is_collinear_pass`,
`remove_move_orphan_wires`), `select.c` (`select_attached_nets`, `wire_through_tap_arm`),
`actions.c` (`connect_by_kissing`), `check.c` (`trim_wires`, `merge_collinear_wires`,
`break_wires_at_attach_points`, `touch`), `netlist.c` (`prepare_netlist_structs`).
Specs: `wire_segment_splitting.md`, `fluid_editing.md`, `cadence_modifier_drag.md`.
Analysis: `wire_editing_spec_and_plan.md`, `wire_follow_stretch_move.md`. FAQ Q26/Q27.
Literature (background, not required): Sutherland *Sketchpad*; Borning *ThingLab*; Bier &
Stone *snap-dragging*; Dai/Kong/Sato *rubber-band routing (SURF)*; rectilinear Steiner / escape
routing / channel routing (VLSI detailed routing).
