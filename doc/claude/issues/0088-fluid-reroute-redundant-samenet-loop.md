# 0088 — fluid reroute leaves a redundant same-net wire loop (stale detour closes a cycle)

Status: **OPEN** (2026-07-08, branch `fluid-editing`). Reproduced deterministically.
Spec: `doc/claude/specs/incremental_wire_reroute.md`, `nice_drag_rerouting.md`. Code: `src/move.c`.
Sibling issues: 0083 (far-pin offset), 0085 (blind-elbow), 0086 (future-blind leg-0),
0087 (point-vs-riser-corridor). Teaching companion:
`doc/claude/code_analysis/redundant_loop_and_the_scoping_problem_tutorial.md`.

## Symptom

A fluid stretch-drag of a component that carries a corner-sliding stub can leave a **closed
rectangular loop of same-net wire** behind — copper that carries no connection (the net is already
whole without it). User-supplied repro: `tests/from_user/before_3.sch`, drag **R18 by (-20,-60)**
(origin `-400 -40` → `-420 -100`), saved as `tests/from_user/after_8.sch`. Net `#net2` ends as:

```
N -420 -90  -400 -90    #net2   (w4  horizontal bottom  — ORIGINAL stationary wire, never moved)
N -420 -130 -420 -90    #net2   (w5  vertical left)
N -420 -130 -400 -130   #net2   (w6  horizontal top)
N -400 -130 -400 -90    #net2   (w9  vertical right)
N -420 -170 -420 -130   #net2   (w10 cap-pin → res-pin riser — the ONLY wire actually needed)
```

Cycle: `(-420,-130) → (-420,-90) → (-400,-90) → (-400,-130) → (-420,-130)`. The only anchor on the
cycle is the res top pin `(-420,-130)`, which is *also* connected off-cycle via `w10` to the cap pin
`(-420,-170)`. So the entire cycle `{w4,w5,w6,w9}` is redundant. **Ideal clean net2 = just `w10`**
(`-420 -170 -420 -130`), a straight riser.

Reproduced with a single 2-motion drag (path-independent, a function of total delta):
`scratchpad/repro_loop.tcl` → output matches `after_8.sch` byte-for-byte on the net2 wires.

## Cause (from FLUID_TRACE `/tmp/fltrace_7_8_4.log`)

During the 0081 X-then-Y leg decomposition, the vertical res-top-pin stub `(-400,-90)-(-400,-70)`
is a corner-slide candidate at corner `(-400,-90)`. `fluid_slide_future_hazard()` (0086/0087)
**correctly DECLINES** the slide: sliding that #net2 corner left would park copper in the column
where the FOREIGN #net1 bottom pin lands in the later Y leg — a real short hazard. Declining →
the stub jogs and `place_moved_wire()` builds an elbow. The ORIGINAL stationary horizontal wire
`(-420,-90)-(-400,-90)` and the riser bottom stay put. When the moved pin ends up back on the
riser column (`x=-420`), the **stale detour to x=-400** and the direct riser connect the SAME two
rows → two parallel paths close a redundant loop.

The decline is right; the residue is never cleaned. The END cleanup chain
(`check_collapsing_objects` → `trim_wires`/`maintain_wire_segments` → `remove_move_orphan_wires` →
`insert_exit_stubs`) removes dangling **stubs** (one free end) but no redundant **cycle**
(every endpoint connected).

## Fix

New END-only cleanup pass `fluid_remove_redundant_loops()` in `src/move.c`, called after
`remove_move_orphan_wires()` (before `insert_exit_stubs()`), gated
`!commit_now && fluid_editing && stretch_select && rot==0 && flip==0 && leg_ortho && leg==nlegs-1 &&
fluid_startsel_wires==0`. Default `fluid_editing` off ⇒ never runs ⇒ byte-identical; the START-side
wire snapshot is also only captured when fluid is on (`fluid_snapshot_partition` early-returns).

**Delete-only, connectivity-verified, cycle-scoped greedy** (design workflow `wf_f40dc5a4-49b`, D1 +
hardenings):

1. Snapshot the geometric **pin-partition** over ALL wires via a `touch()` union-find (pure geometry
   — reproduces the netlister's endpoint + mid-span-T connectivity; immune to a stale `node[]` lab).
2. Greedily, each round: **collect** every eligible candidate, **sort** by canonical normalized span
   (H1 determinism, record-order-independent), **try each once** — tentatively doom (mask only,
   geometry untouched) and KEEP the doom iff the pin-partition is byte-preserved, else revert. Trying
   each once (not re-picking the global min) is essential: a bridge like the riser reverts, and the
   pass must go on to the redundant chords. Dooming a chord exposes its former junctions as prunable
   dead-ends → re-collect and repeat to a fixpoint.
3. **Eligibility gates** (each maps to an invariant):
   - SEED = grabbed / moving-pin-incident **AND a CHORD** (removing it keeps its own two endpoints
     connected via other wires) **AND clean interior**. The chord gate is the **cycle-membership**
     requirement — without it a single-pin net's dangling routing looks "partition-preserving"
     (a lone pin is a partition singleton with or without its wires) and would be wrongly deleted
     (the 38B/39 over-reach found in regression).
   - DEAD-END = adjacent to an already-doomed wire, whose freed endpoints are former junctions
     (entry-degree ≥ 2) or still-connected — never a born-free user dangler tip (predeg ≤ 1, no pin).
   - Never a bus (`wire.bus` or `[`/`:` in lab); never the sole carrier of an explicit (non-`#`)
     label (issue 0040 rename guard — copy the lab before the inner `get_tok_value`, shared buffer).
4. **H3 novelty scope**: require ≥ 1 doomed wire ABSENT from the move-START wire set ⇒ a pre-existing
   untouched user ring never collapses.
5. Commit via `wire_delete_compact`; then **H4 backstop** — `prepare_netlist_structs(0)` + require
   `fluid_partition_changed()==0 && fluid_check_device_merge()==0` (fail-closed on an incomparable
   snapshot), else re-create the removed wires (never-worse).

For the repro this doo­ms `{w4,w5,w6,w9}` and keeps the riser `w10`, giving `#net2 = (-420,-170)-
(-420,-130)` — exactly the ideal. Regression fix: added the chord gate after tests 38/39 over-reached
(no-cycle single-pin nets); fixed a `get_tok_value` shared-buffer aliasing invalid-read (valgrind).

### Pre-existing-user-loop decline guard (review `wf_fce167ed`)

Adversarial review found two over-reach defects where the pass consumed a **pre-existing user cycle**:
(F1, HIGH) a user ring on `#net2` sharing the stale-detour junction `(-400,-90)` was deleted by the
seed/dead-end cascade — the global H3 novelty gate (`≥1` doomed wire novel) is too weak, and
`trim_wires` merged a collinear ring edge into the novel detour so a coordinate match against the
START snapshot missed it; (F2, LOW) a lone device pin whose only copper is a user self-loop — all
edges are chords and partition-invariant (lone pin is a singleton), so the whole loop was deleted.

Fix: `fluid_start_grabbed_component_has_cycle()` — **decline the whole collapse if the wire
component(s) the drag grabbed already contained a cycle at move START.** A pre-existing loop on the
dragged net is user copper; leave the net entirely alone. Computed purely from START data
(`fluid_start_wire[]` snapshot + `coord_was_grabbed`, both captured at START and never mutated), so it
is immune to the `trim_wires` coordinate drift a live match suffers. Node graph over distinct START
endpoints; a grabbed component has a cycle iff `edges ≥ nodes`. The repro's `#net2` is a tree at START
(3 edges, 4 nodes) → not declined → still collapses. Cost: under-reach — a junk loop on a net the
user *already* looped is left un-collapsed; safe and rare. Regression: `test_wireedit_45` case U
(user ring sharing the junction stays 100% intact), sabotage-verified RED when the guard is neutered.

A second review (`wf_257dddae`) hardened the guard three ways:
- **Tap-aware (HIGH).** The first guard's endpoint-only node graph was blind to mid-span T-junctions,
  so a user loop closing through a *tap* read as a tree and slipped past. The guard now **splits each
  START wire at every node on its span** (`touch()`, the same tap-aware model the pass uses) before the
  `edges ≥ nodes` test. Regression: case T (tap-closed loop on the riser).
- **Destination reach (MEDIUM).** The guard only marked *grabbed* (old-position) components; a loop the
  moved pin *lands on* at its destination was uncovered. A component is now reached if a node is
  `coord_was_grabbed(...) || point_on_moving_pin(...)`. Regression: case D (pin dragged onto a loop).
- **Zero-length wires (nit)** are skipped so a degenerate stub can't masquerade as a self-loop.

A third focused audit (`wf_d53bd986`) found one further nit — overlapping/duplicate collinear START
wires emit parallel sub-edges (a multigraph) that inflate the edge count into a *conservative
false-decline* (safe: never eats copper, never a false-negative). Fixed by **de-duplicating sub-edges**
so `edges ≥ nodes` is an exact simple-graph cycle test.

Accepted residuals (safe, documented): (a) wholesale decline suppresses collapse on the *other*
acyclic nets of a multi-pin drag when one net is user-looped — pure under-reach; (b) a pre-existing
*acyclic* user wire that the drag makes loop-redundant is removed — but only ever redundant copper the
partition check proves carries no connection (this is the feature's purpose; the repro's `w4` is
exactly this case), and H3 novelty bounds it to drag-created redundancy.

## Test

`tests/headless/test_fluid_loop_0088.tcl` — self-skips without X; drives the real gesture; asserts
net2 collapses to the single riser and no closed loop remains; plus guard cases that must be
untouched.
