# Fluid connected-drag router v1 — spec

**Status:** proposed (not started)
**Area:** wiring / fluid connected-drag (`src/move.c`) — supersedes the healer-pass cascade
**Companion:** `doc/claude/code_analysis/fluid_connected_drag_reroute_teaching.md` (why the current
cascade is a hairball), `doc/claude/WIRING.md` (current data model / pass catalog / invariant contract),
`doc/claude/specs/nice_drag_rerouting.md` (the original P1–P8 contract).

---

## 0. Thesis

Replace the ~20 symptom-patching healer passes with **one computed router**. On a connected drag we do
not nudge the previous frame and we do not protect the user's existing bends — this is a **schematic**, so
re-routing for beauty is the whole point. We keep exactly two things invariant and maximize a third:

- **C1 — Electrical invariance (hard).** The connectivity partition of all *anchors* (instance pins +
  net-labels) is **byte-identical** before and after the gesture. This single constraint subsumes: no new
  short (no two distinct nets joined), no disconnect (no connected pair severed), no merge/split, no
  rename (labels stay on their nets).
- **C2 — No body crossing (hard).** No wire segment passes through the drawn body of any instance
  (other instances *and* the moved selection's own bodies), with the sole exemption of a pin's short lead
  escape stub.
- **B — Beauty (objective).** Among all routes satisfying C1 ∧ C2, pick the most beautiful (§4).

Everything the old cascade did (escape stubs, backbone shoves, jog-trunk shoves, reversal straightening,
overshoot collapse, redundant-loop removal, Manhattanization) becomes *emergent output of the router
computing a beautiful legal route*, not a stack of special cases.

### What this explicitly drops

- **The novelty / ownership proxy** (`fluid_wire_is_novel_span` and its narrowings). It only ever existed
  to satisfy layout-style P7 "don't reshape the user's copper." On a schematic we *want* to reshape.
  Gone → so are its two-sided misfires (laundering over-fire 0088–0090; pin-tracked-shrink under-fire
  0139).
- **Topology preservation as intent-respect.** We keep a net's tree topology across a frame only for
  *tractability* (don't re-solve a Steiner tree every mouse-move) and *stability* (don't jitter — a beauty
  property), and we are free to change it whenever that yields a more beautiful or a *legal* route.

### What this keeps

- The **restore + re-derive-from-total-delta** harness (`fluid_gesture_arm` / `fluid_reroute_restore`).
  `release == stepwise` is a good property; the router must remain a **pure, deterministic function** of
  `(pristine geometry, total delta)`.
- The **spatial hash** (`*_spatial_table[NBOXES][NBOXES]`) for body/obstacle queries.
- The **stable ids** (`xctx->wire[].id`, pin/instance handles) — now the *primary* connectivity key.
- The commit **safety gate** (`fluid_check_move_invariants`), promoted from log-to-refuse for C1/C2.

---

## 1. Data model

### 1.1 Anchor
A fixed connection endpoint that defines what must stay connected:
- an **instance pin** (`PINLAYER` rect), with an **escape normal** (the lead direction, already computed
  by `get_pin_lead_normal`, issue 0134);
- a **net-label** (`lab_pin`) — also names the net;
- a **junction**: a point of touch-degree ≥ 3, or an explicit solder dot.

Anchors on the moved selection translate with it; all others are fixed. Anchors are the *only* points the
router may not move.

### 1.2 Net
The set of anchors in one connectivity class, plus the wire copper drawing them together. A net is
**routed as a tree** over its anchors (Steiner points allowed at wire junctions). Buses are a net whose
edges carry a width/range (v1: preserve the bus flag, route like a scalar, defer bundle-beauty).

### 1.3 Connectivity model (Layer 1 — the foundation)
An incremental **union-find over stable ids** of `{wire segments, pins, junction points}` that answers,
in O(α):
- `same_net(a, b)` — are two anchors/segments in one class?
- `anchors_of(net)` — the anchor set of a class;
- `partition()` — the full anchor→class map (for the C1 verify).

This **replaces** `fluid_loop_partition` (instance-pin-indexed → blind to single-pin nets) and the
foreign-weld `touch()` scans (blind to nothing it need be, but O(n²) and ad-hoc). It must see **single-pin
nets** and **pin-less labeled nets** — the two blind spots behind 0134-A, 0094, and part 2 of 0139.
*Nothing else in this spec is safe to build until Layer 1 exists.*

### 1.4 Obstacle set
For C2: the body rectangles of every instance (the real drawn body, **not** the text-inflated bbox — the
0138 fix-the-fix landmine), queried through the spatial hash. Bodies of moved instances use their *new*
positions.

---

## 2. The router

### 2.1 `route_edge(a, b, ctx) -> polyline | INFEASIBLE`
Route one anchor-to-anchor connection.

Inputs: endpoints `a`, `b` with their escape normals; the obstacle set; the set of **foreign copper**
(every wire not in `a`'s net) as no-touch; and (optionally) the previous frame's embedding of this edge
for stability tie-breaking.

Output: a legal Manhattan polyline, or `INFEASIBLE`.

Algorithm (two tiers):
1. **Candidate enumeration** (handles the vast majority): the 2 basic Ls; the Z / one-jog family; routes
   that leave each pin along its escape normal for ≥1 grid before turning. Filter each for legality
   (C2 body-free via spatial hash; C1-local: touches no foreign wire except at a legitimate shared
   anchor). Rank surviving candidates by the beauty cost (§4). Return the best.
2. **A\* fallback** (rare, congested): if no candidate is legal, line-search A* over the escape graph
   (obstacle corners + anchor projections + grid) for the optimal legal Manhattan path. If even that is
   infeasible orthogonally, allow a single diagonal segment (electrically-correct-beats-blocked), flagged
   ugly so the ranker prefers any orthogonal alternative.

### 2.2 `reroute_net(net, ctx)`
Re-embed a net after the move:
1. Move the net's moved anchors to their new positions.
2. For each tree **edge** whose endpoint moved, or whose current embedding is now illegal (crosses a moved
   body / shorts), call `route_edge`. Leave already-legal-and-beautiful edges untouched (stability).
3. If an edge is `INFEASIBLE` under the current tree topology, **re-topologize**: recompute the net's
   rectilinear Steiner tree over its anchors and re-embed. (v1 may fall back to "keep old copper +
   refuse" here and log; v2 does the RSMT.)
4. Return the net's new copper, or `INFEASIBLE` for the whole net.

### 2.3 Driver (replaces the END pass cascade)
```
arm: snapshot pristine + partition0 (Layer 1)
on each RUBBER step and at END:
  restore pristine
  translate the selection by the TOTAL delta
  affected = { net : net has a moved anchor }  ∪  { net : net's copper now crosses a moved body }
  for net in affected: reroute_net(net)
  verify C1 (partition == partition0) and C2 (no body cross)  -- Layer 1 + spatial hash
  if verify fails: exact-revert to the translated-but-un-rerouted state (never worse), log
  commit
```
Note the affected set includes **stationary nets a moved body now overlaps** (no moved anchor of their
own) — that is exactly the 0136 / 0139 body-cross class, handled here as an ordinary reroute instead of a
bespoke shove pass.

---

## 3. The two hard constraints, precisely

**C1 electrical invariance.** Let `partition0` = the anchor→class map at gesture arm. After routing,
recompute `partition`. Require `partition == partition0` as an equivalence on anchors (canonical, not
id-numbering). Any inequality — a merge (short), a split (disconnect), or an anchor changing class — fails
the gate → revert. Because labels are anchors, net *names* are preserved by construction.

**C2 no body crossing.** For every routed segment, spatial-hash query the body rectangles; a strict
interior crossing of any body fails — except a segment incident to a pin and lying along that pin's escape
normal within one grid (the escape-stub exemption). Uses the real drawn body box.

Both are **promoted to REFUSE** at the commit gate (`fluid_check_move_invariants`). Today P2 refuses but
P1/P5 are only procedural/log — a router bug must be *caught*, not shipped.

---

## 4. Beauty cost B (the objective)

Among C1∧C2-legal routes, minimize lexicographically (each level breaks ties of the level above):

1. **Orthogonality** — number of diagonal segments (target 0; a diagonal only survives when nothing
   orthogonal is legal).
2. **Total wire length** (minimum copper).
3. **Bend count** (fewest corners).
4. **Pin-lead compliance** — each pin exits along its `get_pin_lead_normal` direction for ≥ 1 grid.
5. **Alignment / collinearity** — reward segments collinear with existing same-net runs and axis-aligned
   with their anchors (straight-through beats staircase); penalize needless jogs and dangling stubs.
6. **Symmetry** — for a fan-out, balanced/centered Steiner branching over lopsided.
7. **Stability** — on a tie, prefer the embedding closest to the previous frame's (kills jitter; keeps the
   deterministic-pure-function property).

Levels 1–4 are objective and cheap; 5–7 are the "beats Virtuoso" polish and can land incrementally.

---

## 5. Integration & migration (no big-bang)

The existing ~20 passes encode ~50 hard-won fixtures; replacing them at once regresses dozens. Ship the
router behind a flag and promote per-fixture.

1. `fluid_router` flag, default **off** → behavior byte-identical to today.
2. **Shadow mode**: with the flag on in *shadow*, run the router alongside the old cascade, commit the
   **old** result, and log a geometry diff of the two. Sweep the whole corpus:
   `tests/headless/wireedit` (57), every `tests/headless/test_fluid_*` gesture suite, and the
   `tests/from_user/after_*` fixtures.
3. Promote per fixture: flip a case to "router authoritative" once the router **matches or beats** the
   accepted route (RED→GREEN discipline, one case at a time — §6 plan).
4. Retire a healer pass only once the router is authoritative and green on **every** fixture that pass
   exists to satisfy. Delete passes bottom-up (the body-cross/shove family first — it is the most
   bug-dense and most directly subsumed).

### Risks / hard parts (call them out honestly)
- **RSMT re-topologize (§2.2 step 3)** is the research-grade core; v1 defers it (keep-old + refuse-log).
- **Buses / bundles** — v1 routes scalars, preserves bus flags, defers bundle beauty.
- **Fan-out nets** (K>2 anchors) — v1 re-embeds the existing tree edge-by-edge; full RSMT is v2.
- **Performance** — affected-nets-only + spatial hash keeps it interactive; measure on the largest
  fixture before promoting shadow→authoritative.

---

## 6. Plan

The atomic, checkable implementation plan (phases 0–8, each box PR-sized with a done-criterion) lives in
**`doc/claude/suggestions/fluid_router_v1_plan.md`** — check boxes off there as work lands.
