# WIRING.md — the wiring & connected-drag reference (for Claude Code)

**Read this before touching anything that creates, moves, deletes, or reroutes wires** —
`move.c`, `select.c` follow-set code, `check.c` trim/break/merge, fluid passes, or any
feature where a drag/rotate/flip must keep wires attached. It condenses the data model,
the END pipeline, every pass's contract, the known landmines, and the open risks.

Line numbers are as of commit `f1692607` (branch `fluid-editing`) and WILL drift — anchor
by function name, use the line as a hint. Companion documents:
`doc/claude/code_analysis/wiring_support_assessment.md` (human-readable assessment +
retrospective), `doc/claude/specs/nice_drag_rerouting.md` (the P1–P8 contract),
`doc/claude/specs/incremental_wire_reroute.md` (mechanism), issues `doc/claude/issues/0079–0111`.

---

## 0. Operating rules (learned the hard way — issues cited)

1. **Every fluid geometry mutation must be verified, then reverted exactly on failure.**
   Tentative-apply → partition verify → exact revert is the house pattern ("never worse").
   Four P1/P2 escapes (0085, 0093-D2, 0102, 0109) came from commit paths that skipped the
   verify. If you add a commit path, arm the safety net (`leg_snap`) or prove why not.
2. **Pick the correct verify direction** (§5). *Restore-START* vs *preserve-pass-entry* vs
   *geometric-vs-name partition*. Wrong choice either never fires or blesses deleting
   load-bearing copper (comment at `move.c:1938-1945`; issue 0104's first fix was rejected
   for comparing across models).
3. **Never enable a translation-written pass under rotation without auditing every
   coordinate expression** — `+delta` arithmetic is everywhere; the transform authority is
   `ROTATION(...)` + pivot rules (§2.4). Bred 0099/0100/0101.
4. **Negate every condition of any gate you write** and classify each negation:
   covered / deferred-with-xfail-test / impossible. 0101's three holes (H1/H2/H3) are the
   negations of 0100's fix gate; 0093/0105/0109 are the same shape.
5. **Every safety decline leaves residue; name the pass that cleans it.** Decline-based
   safety mathematically guarantees dead copper (0088–0092 family). A new decline without
   a designated cleaner is a future issue.
6. **Deferred items must ship as RED/xfail tests, not prose.** ~15 of 33 issues were
   literally pre-written in deferred lists / comments. The one xfail tripwire that existed
   (0104's) worked perfectly.
7. **Repro with the user's exact gesture** — real keysyms (ALT-R = `ROTATE|ROTATELOCAL`,
   callback.c:5100), real GUI callback path, `src/xschem --script src/cadence_style_rc`.
   Headless `move_objects` is byte-identical to the *release* only; per-motion commit bugs
   (0109) need real pointer waypoints under X. See [[green-but-hollow]], [[user-run-config]].
8. **After every fix ask**: (a) what does the new guard over-protect? (0091→0092)
   (b) what residue does the decline leave, who cleans it? (0086/0087→0088)
   (c) what do downstream passes do with the new output? (0109's push-through→0111).
9. **Ordering is load-bearing.** The END pass order encodes ≥7 hard edges (§4). Never
   insert/move a pass without walking the dependency list. Especially: NOTHING that
   collapses jogs may run after `insert_exit_stubs` (0111 invariant, move.c:6925-6932).
10. **Watch pointer/index staleness**: `xctx->wire` reallocs on every `storeobject` and
    every snapshot restore — re-fetch local aliases (move.c:6333-6334, 6438). Indices are
    invalidated by every `trim_wires`/`wire_delete_compact`; only `wire[].id` is stable.
11. **`prepare_netlist_structs(0)` frees every `wire[].node` string** — never hoist a
    `node` pointer across anything that might call it (UAF, move.c:3948-3953).
12. **fltrace, not stderr** — GUI launch freopens stderr to /dev/null. `FLUID_TRACE=path`
    writes to a dedicated file (move.c:1986-1997).

---

## 1. Data model

### 1.1 The wire record (`xWire`, xschem.h:497-513)
- `x1,y1,x2,y2` doubles, **unordered** endpoints; routines normalize ad hoc
  (`order_wire_points` move.c:1097, `order_wire_coords` move.c:1806). An **unordered wire
  silently breaks `touch()`** → pin lands on a fresh `#net` with no visible error
  (move.c:1799-1805). Always order after rewriting endpoints.
- `sel`: 0 | `SELECTED`(whole) | `SELECTED1`(endpoint-1 moves) | `SELECTED2`(endpoint-2
  moves). Grabbed-at-both-ends folds to `SELECTED` (select.c:1040-1045). `SELECTED4` =
  transient doom mark in `break_wires_at_pins`. Partial-select **is** the stretch handle
  and drives `place_moved_wire`'s four branches.
- `node`: resolved net name, owned by the netlister; freed + rebuilt by every
  `prepare_netlist_structs(0)`; `#netN` numbering is traversal-order-dependent (never
  compare across rebuilds — use partition vectors, §5).
- `end1,end2`: lazy viewport-scoped junction-dot counters, tri-state stale (-1). NOT
  usable as degree — fluid code uses `fluid_deg_at` (full scan) instead.
- `id`: session-stable, monotonic, never reused; stamped at birth (`wire_store`
  store.c:369); split gives the new piece a fresh id; **trim's collinear merge loses the
  absorbed wire's id** (check.c:388). `wire_index_from_id` = O(W) scan by design.

### 1.2 Connectivity = coordinates, nothing else
There is **no net graph**. Wire A connects to B iff an endpoint lies on the other's span —
exact-double `touch()` (clip.c:234-245, needs ordered segment; mishandles zero-length
wires — see the degenerate skips in move.c:2504-2511). A pin connects iff a wire touches
its exact center. Consequences:
- **Every coordinate coincidence is an electrical event.** A route passing *through* a
  point where something else ends changes the netlist (0104, 0107).
- "Same net?" is answered by name compare after a full-sheet flood, or by geometric
  union-find `fluid_loop_partition` (move.c:2496, O(W²)).
- ~24-30 `prepare_netlist_structs(0)` calls per gesture in move.c — each a full
  free-everything flood. This is the interactive-performance ceiling.
- Sub-grid jitter breaks connectivity; tolerance is inconsistent (§7.6).

### 1.3 Mutation funnel (all wire birth/death goes through these — store.c:339-433)
`wire_store` (birth; pos>=0 shifts every index ≥ pos), `wire_store_split`,
`wire_delete_compact` (death; every index ≥ first deletion changes). Callers own hash/
netlist invalidation (`prep_hash_wires/prep_net_structs/prep_hi_structs = 0`).
Normalizers: `trim_wires` (check.c:182 — break at T, dedup, merge collinear pin-aware;
heavy renumbering), `maintain_wire_segments` (= attach-split + trim, autotrim mode),
`check_collapsing_objects` (move.c:151, kills zero-length), `remove_move_orphan_wires`
(move.c:1706). `break_wires_at_point/at_pins` push their OWN undo — **never call
mid-END-pipeline**. Save-time coalescer `merge_collinear_wires` works on a scratch copy.

### 1.4 Spatial hash
Four toroidal bucket tables (NBOXES=50 mod-aliased, netlist.c:433-444) of **array
indices** — invalidated by any compaction; the stale-flag trap (`prep_hash_wires==1` with
a stale table silently serves garbage, check.c:679-684). Fluid predicates bypass it
entirely and do O(W) scans; if you need the pin table, `prepare_netlist_structs` must run
first (it's built only there).

---

## 2. Gesture lifecycle

### 2.1 Entry (callback.c)
- Cadence plain LMB drag / `m` key: `connect_by_kissing=2` armed **before**
  `select_attached_nets()` (ordering load-bearing) then `move_objects(START,0,0,0)`
  (callback.c:6232-6236, 4813-4818). Ctrl = detached; Shift = copy; `Shift+M` = rigid move.
- Tip/edge grabs (`grab_free_wire_vertex`, `try_grab_shape_point`) bypass
  `select_attached_nets` → **no** `stretch_select`, no fluid pipeline.
- Mid-drag transforms: ALT-R = `ROTATE|ROTATELOCAL` (callback.c:5100), Shift-R = `ROTATE`,
  ALT-F/Shift-F flips — they only accumulate `move_rot/move_flip`; nothing bakes until
  END/commit_now.

### 2.2 Follow set (`select_attached_nets`, select.c:1579-1689)
Sets `stretch_select=1` (the master gate); snapshots `fluid_startsel_wires` (count of
user-selected wires BEFORE grabbing — the user-vs-tool ownership discriminator) and
`fluid_startsel_id[]` (session-stable ids, issues 0091/0093); marks follow wires
SELECTED1/SELECTED2 by `endpoint_near` (cadsnap/2) to moving pins / selected-wire ends;
snapshots grabbed endpoint coords into `stretch_grabbed_xy` (consumed by
`remove_move_orphan_wires`; **retaken at MOVED coords by mid-gesture regrabs** — unusable
for pristine-anchor reasoning, move.c:2904-2907; use `fluid_start_endpoint_at`/
`fluid_start_deg_at` instead).

### 2.3 START snapshots (`fluid_snapshot_partition`, move.c:2262)
Four snapshots, all position-indexed by an instance×pin walk that must be replicated
byte-identically in every consumer (§7.5):
- `fluid_snap_pinnet[]` — strdup'd per-pin net names (P2/device-merge checks).
- `fluid_snap_id[]` — canonical name partition (rename-immune; `fluid_build_partition`).
- `fluid_start_wire[]` — normalized span+lab set (novelty scoping, issue 0088).
- `fluid_geo_snap_id[]` — **geometric** partition via `fluid_loop_partition` (issue 0104;
  the name partition merges disjoint same-name islands like GND/VDD and misses
  spice_ignore wires).
Plus the Phase-II full-geometry snapshot `xctx->fluid_reroute_snap` (an undo slot taken
after kissing) + the 4 session-stable id counters.

### 2.4 RUBBER live-commit protocol (move.c:6112-6139)
Fluid stretch: each snap step = `fluid_reroute_restore()` (full `mem_restore_slot` back to
pristine + restore ui_state + **4 id counters** for deterministic tool-wire ids +
`rebuild_selected_array` + `movelastsel=lastsel`) then set `commit_now=1` and fall through
the shared END commit with the TOTAL delta. Release==stepwise by construction. Rotation is
re-applied from pristine each step, never incrementally. `set_modify` deliberately not
called mid-drag. ABORT and real END both roll dirty geometry back to pristine before
pop/push_undo.

### 2.5 Transform math
`ROTATION(rot,flip,pivotx,pivoty,x,y,rx,ry)` (xschem.h:386): **flip first, then rotate**,
about pivot. Pivot = grab snap `xctx->x1/y1` for rigid rotate; per-object origin for
rotatelocal; **rotatelocal + partial follow wire needs the owning instance's origin**,
found by scanning selected instances' pristine pins (move.c:6382-6403, issue 0100).
Commit rule: only SELECTED endpoints get ROTATION+delta; the anchored endpoint stays at
its **pristine** coordinate (move.c:6404-6419) — this is *the* stale-anchor source (§8,
class C). **Instances commit AFTER wires** (move.c:6754-6775): during the wire pass
`get_inst_pin_coord` returns PRE-move coords; every helper must add ROTATION/delta itself
(relied on at move.c:2194, 4760). Pre-move lookup under rotation uses the hand-down
statics `fluid_stretch_premove_x/y` (valid for exactly one `place_moved_wire` call); the
inverse-ROTATION fallback assumes the global pivot and is wrong under rotatelocal.

---

## 3. Master END pipeline (`move_objects`, `(what&END)||commit_now`, move.c:6154-7137)

Outer scaffold: `for(attempt=0..2)` × `for(leg=0..nlegs-1)`.
- `leg_snap` P2 safety net armed on three branches (all fluid+stretch+ortho):
  diagonal decomposition (nlegs=2, rot-free, `fluid_startsel_wires==0`, issue 0081);
  rotated/flipped stretch (0102); pure-axis tool-owned-only (0109).
  **A gesture outside these arms commits sight-unseen** (`if(!leg_snapped) break`,
  move.c:6990) — the known open hole is mixed selections rot-free (0093-D2, risk §11.2).
- Attempts: 0 = normal (push-through slide on); 1 = single-pass ortho diagonal;
  2 = rigid diagonal relay (`leg_ortho=0`, `manhattan_lines=0`, `diag_relay=1`).
  Verdict per attempt: `prepare_netlist_structs(0)` + `fluid_partition_changed()==0`
  accepts; attempt-2-still-dirty restores attempt-1's result from `alt_snap`
  (**zero/nonzero only — partition-diff counts are cascade-sensitive, never compare
  magnitudes**, move.c:7012-7034).

Ordered passes per leg (gates in brackets):

```
 1. pre-commit: dirty rollback + push_undo (END only)
 2. update_symbol_bboxes
 3. compute_wire_slide + fluid_slide_push_through      [ortho, pure-axis, rot-free]
 4. per-object commit loop: WIRE→place_moved_wire (elbow: hazards>future>P6),
    0102 axis-degenerate relay bend; then ELEMENT commit (AFTER wires!)
 5. fluid_shove_connected_wire                          [fluid+stretch, rot==flip==0]
    fluid_reroute_around_obstacles                      [same]
    fluid_offset_foreign_pin_landing                    [same + pure-axis delta]
 6. check_collapsing_objects
 7. maintain_wire_segments | trim_wires                 [autotrim | stretch]
 8. remove_move_orphan_wires                            [stretch]
 9. END cleanup cluster [!commit_now, fluid+stretch+leg_ortho+final leg;
    rotfree = rot==0&&flip==0]:
    a. fluid_ripup_foreign_pin_short  (+ fluid_jog_pin_off_backbone)   → ripped
    b. fluid_prune_shorting_anchor_tails
    c. fluid_remove_redundant_loops
    d. if(!rotfree) fluid_prune_anchor_tails            ← must precede (e), 0110
    e. fluid_straighten_reversals                        (0111 reschedule inside)
    f. fluid_collapse_axis_overshoot_stub
    g. if(ripped) fluid_prune_novel_orphan_stub
10. insert_exit_stubs + check_collapsing_objects        [rot==flip==0, final leg]
    ← INVARIANT: after all straighteners; nothing jog-collapsing after it (0111)
11. unselect_partial_sel_wires; ownership normalize (0091/0093 by id)
12. if(nlegs==2 && leg==0) move_regrab_follow_set
—— per gesture, after the attempt loop ——
13. fluid_manhattanize_relay_diagonals                  [accepted relay only —
    that path had leg_ortho==0 and SKIPPED steps 5-10 entirely]
14. END finalizers: clear stretch state (exactly once — per-leg clearing = UAF),
    fluid_check_move_invariants (LOG-ONLY backstop), set_modify, draw
```

Hard ordering edges (all documented in-code, all discovered by bugs):
- ripup **first**: straighten pass-2 is the designated pruner of ripup's orphaned riser
  tails (move.c:3912-3913, 6862).
- de-short (a,b) before aesthetics (c,e,f): aesthetic passes verify against *pass entry* —
  an unfixed short entering them is **frozen in as the invariant they preserve**.
- trim/orphan before loops (c): needs deduped geometry.
- anchor-tails (d) before straighten (e): a dangling tail holds the jog endpoint at
  degree 2, masking the staircase (0110).
- straighten (e) before exit stubs (10); the reverse antagonism (collapse-onto-pin →
  re-jog) is solved *inside* straighten by the 0111 pin-landing reschedule (far-target
  first, else collapse to pin+grid×normal, skip if already there).
- orphan-stub (g) after straighten: its target only becomes prunable once straighten
  deletes the riser it was joined to.
- manhattanize (13) last: the relay path skipped everything; it self-gates on
  partition-clean entry and carries its own stale-feed prune.

---

## 4. Pass catalog (one line each; full details in the issue docs)

| pass (move.c) | bred by | scope gates | transform | verify |
|---|---|---|---|---|
| `place_moved_wire` elbow flip :1173 | Ph-III/0085 | partial-sel, snapshot present | pick less-hazardous L (BRIDGE/MOVPIN/FPIN/STRAY/SPANLOSS via `fluid_ml_hazards` :4709) | severity compare only |
| P6 bias `fluid_p6_bias_ml` :2179 | P6 | many declines (see :2183-2215) | prefer along-normal exit L | veto-based |
| `fluid_slide_push_through` :1456 | 0109/0112 | pure-axis, pin dragged past anchor | promote stub+legs to translate | future-hazard + NEW-foreign-wire-contact decline (0112: bbox touch, pre-existing pair contact grandfathered — the leg_snap verify is label-blind and cannot catch these) |
| `fluid_shove_connected_wire` :5709 | shove decision | pure-axis, rot-free | shove perpendicular stub/riser | partition |
| `fluid_reroute_around_obstacles` :5148 | 0083 | one moving-pin endpoint, straddle detected | 3-leg detour outside body, outward row search | 9 guards/candidate, declines to baseline |
| `fluid_offset_foreign_pin_landing` :5467 | 0083 | pure-axis leg | V-H-V offset solder joint | partition |
| `fluid_ripup_foreign_pin_short` :3918 | 0094/0098/0105 | device pin-pair merge, axis-aligned pair only | slide whole backbone / jog around pin | restore-START (name) |
| `fluid_jog_pin_off_backbone` :3769 | 0098/0106 | called from ripup only | gap + 3-seg bump ±1 grid, 0106 gap expansion | restore-START |
| `fluid_prune_shorting_anchor_tails` :3682 | 0104 | novel-span, no-pin free end, live deg≥1 | delete-only, greedy, commit only at full restore | restore-START (**geometric**) |
| `fluid_remove_redundant_loops` :2761 | 0088 | chord + clean interior + novelty commit gate; START-cycle decline | delete-only fixpoint | preserve-entry (geometric) |
| `fluid_prune_anchor_tails` :3577 | 0103 | **only !rotfree**; deg-0 free end at pristine junction | delete-only | preserve-entry |
| `fluid_straighten_reversals` :3093 | 0089/0090/0096/0110/0111 | novel-SPAN, deg==1 corners, not prot[], no explicit lab | slide jog (near→far; 0111 pin-landing reschedule), tail retract | preserve-entry + foreign-merge guard |
| `fluid_collapse_axis_overshoot_stub` :3362 | 0092 | brand-new dangle (START-deg==0); **deliberately not prot[]-gated** | shove riser or trim stub | preserve-entry |
| `fluid_prune_novel_orphan_stub` :4085 | 0094-tail | `if(ripped)` only; free-end START-deg==0 | retract/delete | preserve-entry |
| `insert_exit_stubs` :1816 | P3 | rot-free, one wire exactly on pin | slide leg 1 grid out along escape normal + stub | none (geometric construction) |
| `fluid_manhattanize_relay_diagonals` :4214 (`fluid_try_reanchor` :4188) | 0107/0108 | accepted relay, entry partition-clean | re-anchor to live same-net copper, else L to stale anchor, else keep diagonal; stale-feed prune | restore-START per candidate |

Dangling-tail candidacy exists in **4 variants with deliberately different START-degree
thresholds** — that split IS the domain contract (0103 deg-0 vs 0104 deg≥1, stated at
move.c:3671-3672). Don't "unify" them without preserving the domains.

---

## 5. Verify-direction taxonomy (get this wrong and you ship or freeze corruption)

- **Preserve-pass-entry** (geometric `fluid_loop_partition` base-vs-now): loops(0088),
  straighten, overshoot(0092), anchor-tails(0103), novel-orphan-stub, manhattanize prune.
  Semantics: "my cleanup must not change connectivity from what I found."
- **Restore-START, name-based** (`fluid_partition_changed()==0` vs `fluid_snap_id`):
  ripup, jog, manhattanize core, the attempt-ladder verdict. Semantics: "the gesture as a
  whole must end where it started." Inherits the same-name-island blindness.
- **Restore-START, geometric** (`fluid_part_diff_pairs==0` vs `fluid_geo_snap_id`):
  prune_shorting_anchor_tails only (0104). Needed when same-name islands exist.
- Never compare across models (0104 lesson). Never trust diff *counts*, only zero/nonzero.
- Foreign-copper (pin-less labeled net) blindness of all pin-indexed partitions is patched
  by ad-hoc guards in three inconsistent flavors: reach-set (`fluid_slide_merges_foreign`
  :3044 + 2 inline copies) vs node-string (`fluid_seg_welds_foreign` :4163, needs fresh
  prepare). Prefer reach-set (no staleness/UAF exposure) for new code.

## 6. Scope-gate vocabularies (who may touch a wire)

- **Novelty** ×3: `fluid_wire_is_novel` (span+lab; 0088 commit gate only),
  `fluid_wire_is_novel_span` (span-only, lab-independent — the straightener's primary
  gate; a `#netN` renumber must not read as novel, move.c:2447-2453), and the implicit
  id-counter-reset trick. Known weakness: trim split/weld launders spans (risk §11.11).
- **Ownership** `prot[]`: flood from `fluid_startsel_id` (`fluid_mark_user_protected`
  :3076) — "selection wins" per touch-component. Deliberately NOT used by overshoot
  (0092) and absent from novel-orphan-stub. **prot[] must be realloc'd+refilled per
  fixpoint iteration** — trim grows `xctx->wires` mid-pass (move.c:3105-3110).
- **Explicit label** `fluid_wire_explicit_lab` :2471 (non-`#` lab, or contains `[`/`:`)
  = universal hard decline (except loops' own sole-carrier logic :2719-2735). Note this
  makes **every named rail and every bus a repair blackout** (risk §11.1).
- **START-degree thresholds** — see pass catalog note.

## 7. Landmines checklist (walk before ANY move.c change)

1. `xctx->manhattan_lines` is a global mutated per-wire inside `place_moved_wire` and
   forced 0 for the relay attempt (restored :7070) — code in between sees the override.
2. Instances commit after wires (§2.4). Reordering breaks ~8 helpers silently.
3. Re-fetch `wire`/`line` aliases after every restore/storeobject (UAF history).
4. `movelastsel = lastsel` re-sync ritual at 5 sites — all defending the dce0bea6
   symbol_bbox heap overflow. Any new restore path must repeat it (plus ui_state +
   4 id counters + `rebuild_selected_array`).
5. Snapshot index alignment: the instance×pin walk (skip ptr<0; label-skip rule differs
   by consumer — intentional) must match `fluid_snapshot_partition` byte-identically;
   guarded only by pin-count bailouts, which **silently disable all fluid safety**.
6. Tolerance split: `point_near_pin`/`fluid_pin_on_seg` = cadsnap/2; `fluid_moving_pin_normal`
   / manhattanize pin test = exact `==` (deliberate, must match `insert_exit_stubs`).
   A sub-grid pin passes the tolerant test and fails the exact one — silent fall-through.
7. Known predicate drift (fix opportunistically): `fluid_deg_at` :2479 and
   `fluid_is_chord` :2600 **lack the degenerate-wire skip** their siblings carry;
   cadsnap fallback 10.0 (:3779) vs 1.0 (:3228).
8. `stretch_select`/`stretch_grabbed_xy`/`fluid_startsel_*` freed exactly once at real
   END/ABORT — folding into the per-step commit = UAF on step 2.
9. File-scope statics as hidden parameters with validity windows: `fluid_stretch_premove_*`
   (one place_moved_wire call), `fluid_leg_future_dx/dy` (one leg), `fluid_slide_pushthrough_on`
   (one attempt), doom watermarks. An early return inside the attempt loop can leak them.
10. `leg_snap`/`alt_snap` stack slots must be memset before `mem_snapshot_alloc`.
11. All fluid helpers fail-safe to no-op when `fluid_snap_pinnet==NULL` — a gesture that
    skipped the snapshot silently degrades to naive routing (log-only backstop only).
12. Zero-delta early-out (move.c:6187) tests deltas only — currently transform-blind
    (risk §11.8) and skips kissing cleanup.

## 8. Root-cause classes from issues 0079–0111 (name the class before fixing)

A **Unverified commit path** (0085/0093/0102/0109) · B **Trigger-bound detection** — the
contact matrix {endpoint-on-pin, pin-on-span, endpoint-on-span, collinear} × {own/foreign}
× {moving/stationary} × {perp/parallel} was never enumerated; each cell found by a user
(0083/0085/0094/0098/0105/0106/0109; 0112 found by the A3 audit fold-in) · C **Stale anchor** — pristine-anchor-by-design +
no liveness concept for vacated points (0103/0104/0108/0111) · D **Decline residue** —
cleanup accreted shape-by-shape (0088/0089/0090/0092/0096/0111) · E **Transform
blindness** — scattered `+delta` (0099/0100/0101/0102) · F **Selection/ownership debt** —
follow set lives in `wire.sel`; Phase-I decoupling never built (0079/0091/0093/0095/0097)
· G **Decomposition future-blindness** (0081/0086/0087) · H **Blanket gates / ordering**
(0091/0098-B/0110/0103) · I one-offs (0080/0082/0084).

Open issues as of f1692607: **0079** (follow-set drawn as selection), **0084** (replay
grep), **0101** (rotatelocal H1/H2/H3 tears).

## 9. Invariant contract & enforcement status

P1 connectivity = P2 no-short > P3 escape-perp > P5 no-body-cross > P4 Manhattan > P7
stability > P6 min-bends (nice_drag_rerouting.md §4; merged 25-invariant checklist in the
spec digest). Enforcement TODAY:
- P1/P2: enforced ONLY on `leg_snap`-armed paths via the attempt ladder; the general check
  `fluid_check_move_invariants` (:5869) is **log-only** (Tcl vars
  `fluid_last_move_violations/disconnects/dev_merges`).
- P4: never asserted; relay may legally save diagonals ("electrically correct beats pretty").
- P3/P5/P6/no-dead-copper: produced procedurally by the healer ladder, never verified.
- P7: approximated by prot[] + novelty; never asserted globally.
- P8 determinism: id-counter reset trick + pure-function pass design; asserted only by
  release==stepwise tests.

## 10. Testing (see tests map; traps first)

- **CI is a hole**: run_regression runs `test_fluid_editing` with `--nogui` where it
  SELF-SKIPS → permanent hollow pass; the 52-test wireedit suite and all 16 gesture tests
  are manual-only; GitHub CI xvfb audit is `|| true`. A fluid regression cannot fail CI.
- Tiers: **wireedit** (true headless, `xschem move_objects dx dy stretch`, predicates.tcl
  P1–P7) · **gesture** (real X callbacks `xschem callback $WIN 4/6/5 ...`; keysyms for
  ALT-R; self-skip without X) · **test_fluid_editing** (tip-grab basics).
- Net readback: `xschem resolved_net 0` then `getprop wire <i> lab` — **bare
  `resolved_net` stamps every wire with the selected net and hides shorts**.
- `wire_coord` endpoint order is not canonical — normalize before compare.
- Fixture conventions (`tests/from_user/`): `before_N.sch` user pre-state (N = fixture
  generation: before_3→0085-0090, before_7→0099-0104, before_8→0105-0111); `after_M.sch`
  the buggy save (global counter); `preferred_M.sch` hand-authored target (P6 oracle);
  `after_M_fixed.sch` post-fix reference. Much of the corpus is **untracked** — commit
  new evidence files.
- New gesture test: copy the 0111 test shape (~150 lines, self-contained); transcribe
  waypoints from the user's FLUID_TRACE log; RED-first against exact coordinates from
  after_M; prefer HERE-relative fixture paths.
- Every new predicate/check needs a sabotage variant ([[green-but-hollow]]).

## 11. Open risks — predicted next failures (verified against source; check before
declaring any wiring feature done, convert to xfail tests when touching the area)

1. **Named-rail blackout**: `fluid_wire_explicit_lab` hard-declines VDD/GND/bus copper in
   EVERY de-shorter → the whole 0094-0106 repair family is inert on real (labeled)
   schematics; shorts save with only the log-only backstop. All historical fixtures used
   auto `#net` copper. Jog could safely relax (bump inherits the lab).
2. **Mixed-selection rot-free commits sight-unseen** (0093-D2): both diagonal and
   pure-axis `leg_snap` arms require `fluid_startsel_wires==0` (:6249, :6287); only the
   rotated arm doesn't. Fix: arm unconditionally for nlegs==1 rot-free.
3. **Multi-pin devices**: ripup's pair-axis derivation `else continue` (:3964-3968) skips
   any non-axis-aligned merged pin pair (transistor gate/drain) → short saved. Whole
   wireedit suite is transistor-free.
4. **0101 rotatelocal tears** (documented OPEN): strap between co-selected instances (H1),
   wire-grab follower (H2), tolerant-grab vs exact-== owner match (H3) under ALT-R.
5. **1-pin labels have no owner pass**: ripup skips label instances (:3940) and needs a
   pin *pair*; dragging a lab_pin onto foreign copper / legs across label pins /
   label-occupied anchors (0103/0104 prunes require free end on NO pin) are unhandled.
   The wire-stub+netlabel feature mass-produces these shapes.
6. **T-tap on follow-wire interior**: SPANLOSS is only an orientation-chooser input; when
   both L orientations lose the tap, nothing restores it. Pin-less labeled branch variant
   is silent (partition blind).
7. **Jog landing gaps**: pin on a foreign wire's free ENDPOINT (jog needs both-side
   extension, :3854) and 1-grid-pitch parallel channels (bump fixed at ±1 grid, no
   outward search) — direct 0098→0105→0106 series continuation.
8. **Zero-delta early-out transform-blind** (:6187): in-place ALT-R/flip during a fluid
   hold is silently discarded; return-to-origin leaks kiss stubs + consumed undo slot.
9. **Rotation lacks the Layer-2/3 + exit-stub machinery** (gates :6788, :6933): rotated
   drops near a straddle save diagonals or shorted ortho where the translated twin routes
   clean; straighten can land arrivals ON a rotated pin (0111 reschedule is rot-gated off).
   The 0110 un-gating argument applies verbatim — audit and un-gate.
10. **Mid-drag unguarded keys**: Delete and descend 'e' run during STARTMOVE (no
    `!(ui_state&STARTMOVE)` guard) → undo corruption / resurrected geometry / UAF class.
    Sweep the whole key dispatch.
11. **Novelty laundering**: trim's split/weld makes untouched user copper read novel-span
    → straighten reshapes user detours (P7). Fix: id watermark (`id <= START counter` ⇒
    pre-existing) + sub-span-of-START-span test — both strict narrowings.
12. **rot180 relay-bend × manhattanize composition**: the 0102 midpoint bend's anchor-side
    half survives as a dangling saved diagonal (manhattanize gate needs an endpoint
    exactly on a SELECTED pin; stale-feed prune needs START-deg≥2; orphan-stub runs only
    `if(ripped)` in the block the relay skipped).
13. **Corner-slide promotion has no foreign-wire landing guard** (0112 sibling, review
    wf_bfc3c5e4 verified): the perpendicular corner-slide in `compute_wire_slide` rigidly
    translates promoted copper with only pin-corridor vetoes; a slid corner landing its
    span on a label-only foreign net's wire endpoint welds it silently (pin-indexed
    verifies blind, backstop log-only). Same fix shape as the push-through's
    `fluid_pushthrough_new_foreign_contact`; needs its own RED test first.

Below-cut (quality, keep on radar): elbow legs through pin-less stationary bodies (no
body class in `fluid_ml_hazards`); two moved devices sharing a channel (NULL node treated
as same-net :5681-5707); bus quality debt accumulates monotonically (every cleaner
declines buses); stacked coincident pins poison `fluid_geo_snap_id`.

## 12. Structural backlog (agreed direction; sequence matters)

R1 **CI wiring** (0.5-1d): wireedit + gesture tests under xvfb as hard gate; fix
full_audit is_skip; commit the untracked repro corpus. Prerequisite for everything.
R2 **`Fluid_gesture` context struct** (2-3d): replace the file-scope statics; lifecycle
arm-at-START/free-at-END; enables per-pass harness (`xschem fluid_pass <name>`).
R3 **Unified predicate layer** (2d): one deg_at (degenerate skip), one touch body, one
foreign-copper guard (reach-set), one tolerance policy, one `fluid_wire_eligible(w, bits)`.
R4 **Pass table + contracts** (2-3d): {name, gates, verify_direction, mutation_class,
after:...} driving the cleanup cluster; per-pass decline-reason trace; idempotence checker
(run cluster twice = fixpoint — the 0111 oscillation oracle).
R5 **Split move.c** (2-4d after R2-R4): fluid_verify.c / fluid_predicates.c / fluid_heal.c
/ fluid_place.c; add `pin_coord_asof(phase)` accessor.
P0 **Enforcing END gate** (~2-3wk with txn primitive): promote
`fluid_check_move_invariants` from log-only to rollback-or-refuse on every commit path —
the single highest-leverage change (kills class A+B ≈ 11 historical issues).
P1/R6 **Incremental connectivity** (id-keyed union-find maintained through the store.c
funnel): kills the ~30 full floods/gesture and O(W²) verifies — the ceiling on per-step
routing. P2 **birth/purpose metadata** (origin gesture + served anchor per wire id): makes
the stale-anchor family a query. P5 **occupancy index**: prerequisite for the spec's
A*/Lee solver. **Anti-recommendation**: do NOT build the Phase-6 solver before R2-R4 —
it would just become pass #10 in the soup.
Process: delta-sweep fuzzer over before_3/5/7/8 × grid×[-15..15]² × {plain, m, ALT-R,
ALT-R², split-gesture} asserting {partition clean, Manhattan, no novel deg-0 end, no
novel copper through bboxes, length ≤ k·Manhattan-distance} — would have caught ~11 of
the historical issues pre-user.

## 13. Symbol quick map

`move.c`: move_objects :5986 (START :6009, RUBBER :6112, END :6154), place_moved_wire
:1149, compute_wire_slide :1539, insert_exit_stubs :1816, escape normal
get_pin_escape_normal :1896, snapshots :2262-2328, novelty :2432-2478, partition/verify
:2232/2378/2496/3641, healers (§4 table), obstacle router :5148, restore/discard
:5935/5955, regrab :5975, invariant check :5869, FLTRACE :1986.
`select.c`: select_attached_nets :1579, select_wire fold :1040.
`callback.c`: cadence drag :6213-6268, 'm'/'M' :4796-4891, mid-drag transforms
:4592/:5100/:5124.
`check.c`: trim_wires :182, maintain_wire_segments :725, break_wires_at_attach_points :672.
`store.c`: wire funnel :339-468. `netlist.c`: prepare_netlist_structs :1663,
get_inst_pin_coord :753, touch → clip.c:234. `xschem.h`: xWire :497, ROTATION :386,
sel macros :258, fluid xctx fields :1286-1299.
Tcl feedback to user: `ciw_echo` ([[ciw-feedback-channels]]), never puts/statusbar.

**Maintenance**: when you fix a wiring issue, update §11 (retire the risk or add the new
one), the pass catalog if a pass changed, and the ordering list if the pipeline moved.
