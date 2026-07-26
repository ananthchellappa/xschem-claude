# Fluid connected-drag router v1 — implementation plan

**Spec:** `doc/claude/specs/fluid_router_v1.md` (read first — data model, the two hard constraints
C1/C2, the beauty objective B, the router algorithm, and the shadow-mode migration).
**Status:** proposed (not started).

Each box is one PR-sized unit with an explicit done-criterion (a test or a shadow-diff). Ordered by
dependency; do not start a box until its prerequisites are checked. `[ ]` = todo, `[x]` = done.

## Phase 0 — scaffolding
- [ ] **0.1** Add `fluid_router` Tcl/C mirrored flag (default off). Done: flag toggles; off ⇒ byte-identical
  to HEAD on the full `wireedit` + `test_fluid_*` sweep.
- [ ] **0.2** Add a shadow-diff harness: when `fluid_router=shadow`, run the router, log a canonical
  geometry diff vs the committed (old) result, commit the **old** result. Done: harness emits a per-gesture
  diff line; no behavior change.
- [ ] **0.3** Freeze the fixture corpus (wireedit 57 + every `test_fluid_*` + `after_*`) into one driver
  `tests/headless/router_shadow.sh`. Done: script runs, prints one PASS/DIFF line per fixture.

## Phase 1 — connectivity model (Layer 1, the foundation)
- [ ] **1.1** Implement `net_uf`: union-find over stable ids of wires+pins+junctions, built from current
  geometry. Done: `net_uf_partition()` reproduces the netlister's node assignment on 10 hand-fixtures incl.
  a single-pin net and a pin-less labeled net.
- [ ] **1.2** `same_net(a,b)` / `anchors_of(net)` / `partition()` queries + a `xschem net_uf ...` debug verb.
  Done: verb dumps classes; unit test vs `xschem instance_net` on the corpus.
- [ ] **1.3** Replace the C1 check in `fluid_check_move_invariants` with a `net_uf` partition compare (behind
  the flag). Done: flag-on C1 verdict == flag-off for every accepted gesture on the corpus, AND flags a
  known single-pin short the old pin-partition missed (new RED→GREEN unit test).

## Phase 2 — anchors & obstacles
- [ ] **2.1** `anchor_set(schematic)`: enumerate pins + labels + junctions with escape normals. Done: unit
  test on the solar_ctl fixture lists the 4 pins + 2 labels + junctions with correct normals.
- [ ] **2.2** `obstacle_set()`: real-drawn body rects via spatial hash (moved instances at new pos). Done:
  unit test — a moved body's rect updates; text does not inflate it (0138 guard).

## Phase 3 — single-edge router
- [ ] **3.1** `route_edge` tier-1 candidate enumeration (Ls + Z/one-jog + escape-normal-first) with the
  legality filter (C2 body-free, C1-local no-foreign-touch). Done: routes the after_42 LED feed to a
  body-clear L/Z **without** any shove pass, in a standalone unit test.
- [ ] **3.2** Beauty ranker levels 1–4 (orthogonality, length, bends, pin-lead). Done: on 6 hand geometries
  the ranked pick equals the hand-optimal route.
- [ ] **3.3** A\* fallback (tier-2) for congested/no-candidate cases; diagonal last-resort flagged. Done: a
  synthetic congested fixture where tier-1 fails routes legally via A\*.

## Phase 4 — net router & driver
- [ ] **4.1** `reroute_net`: re-embed a net's moved/illegal edges via `route_edge`; leave clean edges. Done:
  single-net fixtures (after_42 #net1, 0136 CTRL1) route body-clear under the router alone.
- [ ] **4.2** Affected-net detection = moved-anchor nets ∪ moved-body-overlapped nets. Done: unit test
  proves a stationary net a moved body engulfs (0136) is selected.
- [ ] **4.3** Wire the driver into the END path behind the flag (translate → affected → reroute → verify →
  revert-or-commit), keeping the restore/re-derive harness. Done: `after_42` + `after_40` pass under
  `fluid_router=on` with the old cascade disabled *for those two nets only* (scaffolded bypass).

## Phase 5 — verify gate & beauty polish
- [ ] **5.1** Promote C1 **and** C2 to REFUSE at the commit gate under the flag (revert-on-fail, log). Done:
  a deliberately-buggy router variant is caught+reverted, never shipped (unit test).
- [ ] **5.2** Beauty ranker levels 5–7 (alignment, symmetry, stability). Done: jitter test — the same drag
  replayed frame-by-frame yields a monotone, non-oscillating sequence (the 0111 oscillation oracle).

## Phase 6 — shadow bake
- [ ] **6.1** Run `router_shadow.sh` over the full corpus; triage every DIFF into {router-better,
  router-equal, router-worse, router-illegal}. Done: a checked-in triage table.
- [ ] **6.2** Fix every router-worse / router-illegal case RED-first until the corpus is {better ∪ equal}.
  Done: shadow diff shows 0 worse, 0 illegal.
- [ ] **6.3** Performance gate on the largest fixture. Done: per-frame reroute < an agreed budget (e.g.
  16 ms) at flag-on.

## Phase 7 — promote & retire
- [ ] **7.1** Flip `fluid_router` default to **on** (cascade still present as fallback). Done: full corpus
  green with router authoritative.
- [ ] **7.2** Delete the body-cross/shove family (`fluid_shove_body_crossing_backbone`,
  `fluid_shove_jog_separated_trunk`, `fluid_reroute_body_crossing_feeds`,
  `fluid_delete_body_crossing_copper`). Done: corpus green without them.
- [ ] **7.3** Delete the straighten/compact family (`fluid_straighten_reversals`,
  `fluid_collapse_axis_overshoot_stub`, `fluid_remove_redundant_loops`, the prune passes) and the novelty
  proxy (`fluid_wire_is_novel_span`, `fluid_wire_pretracked_shrink`). Done: corpus green; `move.c` net line
  count down; teaching-doc "hairball" §6 modes 1–5 no longer reachable.
- [ ] **7.4** Delete `insert_exit_stubs` / `fluid_p6_bias_ml` / `manhattanize_relay_diagonals` once the
  router's escape-normal + orthogonality handle them. Done: corpus green; remove the flag; router is the
  only path.

## Phase 8 — v2 backlog (not v1)
- [ ] **8.1** RSMT re-topologize for fan-out and infeasible-topology nets.
- [ ] **8.2** Bus/bundle beauty.
- [ ] **8.3** Homotopy-aware routing for congested boards (obstacle-side preservation as a *beauty* choice,
  not intent).
