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
- `leg_snap` P2 safety net armed on **four** branches (all fluid+stretch+ortho):
  diagonal decomposition (nlegs=2, rot-free, `fluid_startsel_wires==0`, issue 0081);
  rotated/flipped stretch (0102); pure-axis tool-owned-only (0109); **mixed-selection
  rot-free** (`fluid_startsel_wires>0`, nlegs=1, hardening B2 — closes the 0093-D2 hole).
  The X-then-Y decomposition and the push-through slide stay tool-owned-only (their gates
  are unchanged); the mixed arm only VERIFIES. **A gesture outside these arms commits
  sight-unseen** (`if(!leg_snapped) break`) — with B2 the only rot-free stretch left
  unarmed is a zero-delta one (no motion, cannot short). Caveat: arming a mixed drag makes
  the ladder RUN, but a pure-axis collinear plow has a degenerate relay it cannot repair —
  that residue is REFUSED by the B3 enforcement gate, not fixed here (risk §11.2).
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
    rotfree = rot==0&&flip==0] — as of Track D (D3) driven by the pass table
    `fluid_end_passes[]` (move.c, after manhattanize): array order = execution order;
    gate bits END_ONLY|ORTHO|FINAL_LEG|ROTFREE_ONLY|ROTATED_ONLY|NEEDS_RIPPED|
    SETS_RIPPED|MANUAL_SITE replace the inline `if(!rotfree)`/`if(ripped)` checks
    (ROTATED_ONLY = the old `if(!rotfree)`); ripup's int return threads via SETS_RIPPED.
    The driver fltraces `pass <name>: run` per firing. insert_exit_stubs (step 10) and
    manhattanize (step 13) are MANUAL_SITE entries — cataloged for order/contract,
    still called at their own sites (different gate sets: the stub pass is NOT END-only
    and fires for wire_exit_stub without fluid; manhattanize is per-gesture):
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
13b. fluid_shove_body_crossing_backbone                 [0132 §11.9c/§11.9d; the COMPLEMENTARY path:
    !diag_relay accepted pure-ortho, rot-free, startsel==0 — BODY-driven shove of an engulfed
    same-net perpendicular backbone. Gate (§11.9d): same-net copper strictly INSIDE the body
    along-span by > 1 grid — a pin MID-run (copper both sides) OR a ONE-SIDED inward feed (pin on
    the run's END, diving through the body); a clean escape feed ≤1 grid inside declines. Runs
    LIVE on every RUBBER step AND the real END (§11.9d: the body shoves its own copper on the
    slightest drag, like the pin-driven shove, not only at release) — on CLEAN post-attempt-ladder
    geometry; mem-snapshot + dual partition verify, exact revert. release==stepwise-safe: each
    RUBBER step + END restore-to-pristine and re-derive, so the shove never accumulates. Do NOT
    resite into the shared commit block — THAT dirty-state siting bred phantom merges (issue doc)]
14. END finalizers: clear stretch state (exactly once — per-leg clearing = UAF),
    fluid_check_move_invariants → ROLLBACK-OR-REFUSE on a residual P2 short/dev-merge when
    `fluid_enforce_invariants` (hardening B3): restore the `enf_snap` pristine snapshot (taken at
    push_undo), drop the undo push, ciw_echo, skip set_modify; else set_modify, draw. Disconnects
    stay log-only (published to the Tcl vars).
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
| `fluid_straighten_reversals` :3093 | 0089/0090/0096/0110/0111/**0137**/**0138** | novel-SPAN, deg==1 corners, not prot[], no explicit lab. **0137: ALSO admits a non-novel jog that is a moved-pin escape-stub OVERSHOOT (`fluid_jog_is_moved_pin_escape_overshoot`: same-side reversal, nearer neighbour on a MOVED pin, stub >1 grid, rot==flip==0) — min-copper compaction of the push-only pipeline's un-reclaimed retreat slack; the verified 0111 pin-landing slide then compacts it to the 1-grid escape.** **0138: the escape-overshoot admits EXPLICIT (named) nets too (buses excluded) — the slide is a same-net inward shorten the partition/foreign verify keeps rename-safe; the pass-1 explicit-lab skip is bypassed ONLY for a verified overshoot. Adds an OUTWARD SEARCH (pin+1,+2,… nearest verifying row, ≤8) so a sibling holding the 1-grid row (after_41: TRIANG at y=130) pushes the other net one grid out (CTRL1 y=140), and a mandatory BODY GUARD on every overshoot slide (else a named trunk shoved clear of a device — 0136 — gets pulled back THROUGH it).** | slide jog (near→far; 0111 pin-landing reschedule + 0138 outward search), tail retract | preserve-entry + foreign-merge + (0138) body guard |
| `fluid_collapse_axis_overshoot_stub` :3362 | 0092 | brand-new dangle (START-deg==0); **deliberately not prot[]-gated** | shove riser or trim stub | preserve-entry |
| `fluid_prune_novel_orphan_stub` :4085 | 0094-tail | `if(ripped)` only; free-end START-deg==0 | retract/delete | preserve-entry |
| `insert_exit_stubs` :1816 | P3 / 0132 / **0135 D2** | rot-free, one wire exactly on pin | slide the perpendicular pin-incident leg out along the escape normal + fill the pin gap with a stub. **DISTANCE: normally 1 grid; 0135 D2 — when the CURRENT feed leg grazes/crosses the moved instance's OWN pin-inclusive body (`graze`), OUTWARD-SEARCH `d=1..6` for the nearest row that clears the body AND shorts no foreign net (walks a grazing whole-TRANSLATED feed off its body edge — the two-leg/diagonal decomposition pure-translates a `SELECTED`-whole feed so the elbow/P6 layer never re-orients it, after_39 REF)** | **0132: DECLINE if stub/leg threads the own PIN-INCLUSIVE body (`fluid_seg_crosses_sel_body`, escape-normal exempt) — guards the `get_pin_escape_normal` text-inflated-bbox mis-pick on corner pins. 0134: DECLINE if the slid stub/leg touches a DIFFERENT-net-label wire (`fluid_seg_touches_foreign_lab`). 0135 D2 search per-distance: own-body-cross → continue; STATIONARY-body cross → BREAK/decline (local beautifier never detours a feed past another device — this is what stops R18's grazing feed from flinging 8 grids past C12 in the 0090 staircase); foreign short → continue (try a farther row → walks REF past LED's row). NON-grazing keeps `dmax==1` → byte-identical. NO partition snapshot: the slide never disconnects by construction (pin gap stubbed, corner + its wires dragged together); the foreign-lab guard is the short guard (as 0134); `mem_restore_slot` `unselect_all`s and would strip the pin loop's `.sel`. Unlabeled-foreign gap pre-existing/shared with 0134, B3-backstopped** |
| `fluid_manhattanize_relay_diagonals` :4214 (`fluid_try_reanchor` :4188) | 0107/0108/0130/0133/0132 | accepted relay, entry partition-clean | re-anchor to live same-net copper (**0132: body-aware — reject a candidate whose leg crosses a moved body**), else `fluid_manh_route` (body-free L/Z/escaped-stub route around the PIN-INCLUSIVE body, else body-crossing, else keep diagonal); stale-feed prune; **then `fluid_reroute_body_crossing_feeds` (0132)** | restore-START per candidate |
| `fluid_reroute_body_crossing_feeds` / `_delete_body_crossing_copper` / `_wire_end_on_moved_pin` / `_nearest_outside_body_anchor` / `_net_crosses_sel_body` :4520+ | 0132 (§11.9e P-D) | body dropped on its OWN copper: a moved pin's net crosses the body (2nd incremental drag) | re-route the pin feed to nearest same-net vertex OUTSIDE the union body box (`fluid_manh_route`), then verified-delete the redundant through-body backbone — **deletes even NAMED copper** when the pin partition is provably unchanged without it (§11.1 crack). **§11.9e: NEVER delete a wire whose endpoint is on a moved pin (`fluid_wire_end_on_moved_pin`) — that is the pin's own lead; when the pin sits inside the pin-inclusive box its lead MUST cross the box, and the partition-verify is fooled by a transient relay weld a later prune removes → the delete would orphan the pin (after_37 REF-net-drop)** | `fluid_manh_route` partition-verify + per-delete restore-START + moved-pin-lead protect |
| `fluid_manh_route` / `_manh_commit_path` / `_manh_pushpath` :4498 | 0133 | manhattanize per relay diagonal | enumerate L / Z (grid channels) / escaped-stub L/Z, index-sort by (len,legs), commit first body-free (pref0) else any (pref1) | partition-verify + exact revert per candidate |
| `fluid_shove_body_crossing_backbone` :6790 | 0132 §11.9c/§11.9d/**§11.9f**/**0135 D1** | LIVE every RUBBER step + real END on the `!diag_relay` pure-ortho path; **ALSO END-only on the `diag_relay` path (§11.9f) — invoked twice, once per axis, by scoping `xctx->delta[xy]` to a single axis (the internal pure-axis gate would else decline a diagonal); delta is read ONLY at that gate**, rot-free, startsel==0; **0135 D1 ESCAPE-SIDE gate (:7074): DECLINE when the moved pin's lead escape normal has a component ALONG the shove axis OPPOSING the relocation dir (`dirpos`) — the per-axis SPOOF makes `dirpos` mis-model a pin whose real escape is on the OTHER axis, so the rebuild lands the backbone one grid past the FAR body edge and drags the feed THROUGH the body (after_39 REF's horizontal feed shoved south to ct=100). Legit perp-backbone shoves have escape ⊥ shove-axis (en=0) → untouched**; owning inst ≥2 pins (1-pin symbols straddle the pin — CRITICAL over-fire, review wf_cff67bed); pin column strictly in OWN body; same-net perp copper strictly INSIDE the body along-span by **> 1 grid** (§11.9d: covers a pin MID-run *and* a ONE-SIDED inward feed with the pin on the run's END; excludes a clean escape feed leaving the body within a grid — the TRIANG +y exit); no pin on run; EVERY wire endpoint on run = plain same-net axis corner else DECLINE (bus/diag/foreign); new backbone welds no foreign copper, crosses no other moved / stationary body | BODY-driven shove: collapse run to pin, rebuild ONE backbone 1 grid past OWN body edge (not union — fling guard) spanning [pin..corners] (dead overhang dropped), translate attachments (pin-row overlap dedup), re-feed via jog; may reshape NAMED copper (§11.1 crack #2, prop copied) | mem-snapshot + restore-START name AND preserve-entry geometric, exact revert |
| `fluid_shove_jog_separated_trunk` :7326 | **0136** (after_40); **0139** (after_42) | per-axis END on BOTH diag_relay + pure-ortho sites (same per-axis spoof as the shove); rot-free, startsel==0. The COMPLEMENT of the pin-incident shove: a body-threading same-net backbone NOT incident to any moved pin (one JOG off the pin column — the delta didn't align pin.col with trunk.col; after_35 aligned them → pin-incident shove fired instead). Gates: **PRE-EXISTING span** (`!fluid_wire_is_novel_span` — never a fresh reroute detour leg, wireedit_36 case j; **0139: OR `fluid_wire_pretracked_shrink` — re-admit a novel-span wire that is collinear INSIDE a start footprint AND has an endpoint on a MOVED pin's column, i.e. a pre-existing trunk a SECOND gesture merely SHRANK as its end tracked the pin (after_42 LED crossbar x2 90→80); a genuine detour leg is neither**); **LOAD-BEARING bridge** (dooming the run via `fluid_loop_partition` doomed-mask must change the pin partition — never a redundant user-ring/loop edge the body merely overlaps, wireedit_45 U/T; **0139: pin-partition is BLIND to a SINGLE-PIN net (after_42 `#net1` = LED pin + dead-end rail) → WIRE-level cut-edge fallback: flood touch-connectivity with the run doomed, a genuine bridge disconnects its attachments; a ring keeps them reachable via its other arc → still redundant**); **FOLLOW net** (a moved pin carries the node — only own copper, §11.1); no moved pin on run (shove's job), no fixed pin on run; attachments all plain same-net axis thin wires | TRANSLATE (not collapse): shift the run to `ct` = 1 grid past the crossed body edge (side the attachments lean toward first, then the other; body-free side wins — CTRL1 x=140→170), move each attachment's near end to ct. **0139: STEP `ct` grid-by-grid FURTHER out (bounded 12) when a NEIGHBOUR net's copper occupies the one-grid line (after_42: REF `#net2` crossbar straighten parked at y=−170, so `#net1` → y=−180); a BODY block still fails the side. The resulting rail mid-span crossing of the neighbour shares no endpoint → benign near-miss (0136 defect 2), verify-clean.** No new wires (named rail reshaped, never renamed) | body-free precheck (sel+stationary body, foreign-weld) THEN mem-snapshot + DOUBLE partition-verify (restore-START name AND preserve-entry geometric), exact revert |
| `fluid_inst_body_box` / `_seg_crosses_sel_body` / `_union_sel_body_box` :4415 | 0130/0133 | manhattanize route pick | **PIN-INCLUSIVE** box = symbol no-text bbox (`sym->minx..maxy` rotated, spans all pins; excludes @name text); strict-interior crossing over SELECTED bodies WITH escape-normal exemption (box-centre dominant axis, NOT get_pin_escape_normal) | pure geometric (no verify) |

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
- **Explicit label** `fluid_wire_explicit_lab` :2471 (**not** `is_auto_net_name()` — i.e. not
  a literal `#net<digits>` — or contains `[`/`:`) = universal hard decline (except loops'
  own sole-carrier logic :2719-2735). Note this makes **every named rail and every bus a
  repair blackout** (risk §11.1). The test was `lab[0] != '#'` until issue 0162: a
  user-authored `lab=#foo` failed it and every de-shorter treated the user's net as tool
  copper. The H2 sole-carrier guard in `fluid_loop_eligible` carries the same swap.
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
   **As of Track D (D1/D2) these + the four START snapshots are fields of the one file-scope
   `Fluid_gesture fluid_g` (armed at START by `fluid_gesture_arm`, freed at END/ABORT/clear by
   `fluid_gesture_free`); each field carries its validity-window comment. The early-return leaks
   above are byte-identically harmless — every watermark is re-written before its next read, and
   `n >= watermark` is equal for -1 and 0 over wire indices ≥ 0 — but stay tidy when adding fields.**
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
follow set lives in `wire.sel`; Phase-I decoupling never built (0079/0091/0093/0095/0097/0113 —
0113: keyboard-`m` placement commits on the PRESS, so the RELEASE's cadence deselect-others
collapsed the moved multi-selection; latched `place_click_committed`) · G **Decomposition
future-blindness** (0081/0086/0087) · H **Blanket gates / ordering** (0091/0098-B/0110/0103)
· I **Live-commit overlay must be identity** (0080/0082/0084/0115) — under
`fluid_reroute_dirty` the geometry is ALREADY committed with the full move transform, so
`draw_selection()` must paint it with NO extra transform. 0080 zeroed the delta (translation
ghost at 2·δ); 0115 also zeroes `move_rot/move_flip/rotatelocal` (a mid-drag ALT-R re-rotated the
committed overlay about the pivot → highlight ghost hundreds of units off). Any NEW move-preview
state added to `draw_selection_impl` must be neutralized in the same wrapper. · J **Transform
altitude** — a per-object (`ROTATELOCAL`) transform applied to a multi-object group instead of a
rigid group op about a shared pivot (0114: in-drag ALT-R/F/V; 0116-bug2: standalone ALT-R/F, group
pivot = grid-snapped selection bbox centre — coerce to group ROTATE/FLIP when >1 user object). Also
**transform latency** — a mid-drag ALT-R/F during a LIVE fluid stretch must `commit_now` (re-run the
RUBBER commit) so it repaints without a mouse jiggle; a bare move_rot/flip bump only shows on the
next motion (0116-bug1; release==stepwise keeps the END result identical). · K **Intermediate-leg
strokes bypass the overlay wrapper** (0117) — `select_wire(fast&2==0)` strokes the highlight
DIRECTLY via `drawtempline`, NOT through `draw_selection()`, so landmine I's neutralization does not
protect it. `move_regrab_follow_set()` (between the X and Y legs, `nlegs==2`) calls
`select_attached_nets()` on the X-moved-not-yet-Y geometry; without suppression that strokes a ghost
highlight into `save_pixmap` at the leg-A pin row that the END redraw never clears. Fix: the regrab
sets `xctx->select_attached_nodraw` so those grabs pass `fast=3` (SET only, no stroke). Any new
between-leg / intermediate-geometry SET re-derivation must likewise suppress drawing. NB: does NOT
reproduce in the scripted/headless END (its full `draw()` flushes over the stroke) — interactive/WSLg
blit timing only.

Open issues as of f1692607: **0079** (follow-set drawn as selection), **0084** (replay
grep), **0101** (rotatelocal H1/H2/H3 tears).

## 9. Invariant contract & enforcement status

P1 connectivity = P2 no-short > P3 escape-perp > P5 no-body-cross > P4 Manhattan > P7
stability > P6 min-bends (nice_drag_rerouting.md §4; merged 25-invariant checklist in the
spec digest). Enforcement TODAY:
- P2 no-short/merge: enforced on `leg_snap`-armed paths via the attempt ladder AND, as of
  hardening B3, by the END gate `fluid_check_move_invariants` — its P2 return
  (shorts + dev_merges) drives ROLLBACK-OR-REFUSE when `fluid_enforce_invariants` is set (the
  default). A short no healer can repair (named-rail blackout, degenerate relay) is REFUSED,
  not saved. Escape hatch: `set fluid_enforce_invariants 0` reverts to log-only.
  Both P2 sub-signals are now **DELTA vs the gesture-START baseline**, not absolute: the
  device-merge pass always was (compares `fluid_snap_pinnet[]` start-vs-end); the label-short pass
  (`fluid_count_label_shorts`) was ABSOLUTE until issue 0123 and vetoed valid moves whenever ANY
  pre-existing naming short existed on a FOREIGN net the gesture never touched. Now the pristine
  enforce snapshot also captures `enf_short_base = fluid_count_label_shorts()`, and the gate refuses
  on `max(0, end_shorts − base) + dev_merges`. Landmine: a schematic can carry a legit-looking
  short at rest (multiple conflicting `lab_pin`/`ipin` names on one net); the gate must never punish
  an unrelated move for it.
- P1 disconnect: still **log-only** (Tcl var `fluid_last_move_disconnects`). NOT part of the
  refuse signal — a disconnect is visible (a dangling pin), the count is cascade-sensitive (§5),
  and the never-worse healers legitimately accept a baseline disconnect (test_wireedit_42).
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
   schematics. All historical fixtures used auto `#net` copper. **MITIGATED (hardening B3)**:
   such a short no longer SAVES silently — the END enforcement gate REFUSES the whole move and
   leaves the schematic byte-identical (test_wireedit_54). The REPAIR gap remains: the de-shorters
   still can't reshape named copper (the jog could safely relax — bump inherits the lab), so the
   user gets a refusal, not a routed result. Relaxing the jog for named rails is the open follow-up.
2. **Mixed-selection rot-free commits sight-unseen** (0093-D2): ~~both diagonal and
   pure-axis `leg_snap` arms require `fluid_startsel_wires==0`; only the rotated arm
   doesn't.~~ **PARTLY FIXED (hardening B2)**: a 4th arm now arms `leg_snap` for
   nlegs==1 rot-free mixed selections, so no mixed drag commits UNVERIFIED
   (test_wireedit_53). The attempt ladder REPAIRS a mixed short only when the relay is
   non-degenerate (a diagonal drop lifts the plow off the row); a **pure-axis collinear**
   mixed drag (after_26 topology, drag along the anchor row) has a degenerate relay the
   ladder cannot repair — that residue is caught by the B3 enforcement gate (rollback-or-
   refuse), not repaired. Push-through stays tool-owned-only, so a mixed pure-axis drag
   still plows at attempt 0.
3. **Multi-pin devices**: ripup's pair-axis derivation `else continue` (:3964-3968) skips
   any non-axis-aligned merged pin pair (transistor gate/drain) → short saved. Whole
   wireedit suite is transistor-free. **Delta-sweep evidence (hardening C4,
   `c4_transistor`):** a leg-across-nmos short from an R18 drag is REFUSED by B3 (repair still
   owed), but dragging the NMOS ITSELF DISCONNECTS its d/s pins (the 2-pin follow set doesn't
   cover a 4-pin device) — a P1 partition change that B3 does NOT refuse (disconnect is
   log-only, §9), so it SAVES **even under enforcement** (an enforcement gap). Pinned as an
   xfail RED in `tests/headless/fuzz/test_fuzz_c4_blindspots.tcl`.
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
   The 0110 un-gating argument applies verbatim — audit and un-gate. **PARTLY MITIGATED (0130/0133)**:
   the manhattanize pass — the only shaper on the accepted rotated relay — now runs `fluid_manh_route`,
   which reshapes each relay diagonal into a body-free L / Z / escape-stub route around the
   **PIN-INCLUSIVE** body (`fluid_inst_body_box` = symbol no-text bbox spanning all pins, with a
   box-centre escape-normal exemption for pin feed legs), so the common rotated drag no longer saves
   wires that thread under the pins or a leftover diagonal (test 0130, after_33). REMAINING gap:
   (a) a **fully congested** layout (no body-free route verifies) still falls back to a body-crossing
   route (never worse), the elbow/reroute/exit-stub layers stay gated off — un-gating is the complete
   fix. ~~(b) second incremental drag onto own copper (after_32)~~ **FIXED (0132)**: the phase-1
   re-anchor is now body-aware (rejects a candidate whose leg crosses a moved body → falls through to
   `fluid_manh_route`), and a new END phase `fluid_reroute_body_crossing_feeds` re-routes each moved
   pin whose net threads the body to an outside-body anchor then **verified-deletes** the redundant
   through-body backbone (`fluid_delete_body_crossing_copper` — removes even NAMED copper when the pin
   partition is provably unchanged without it, a first verified crack in the §11.1 blackout). Test
   `test_fluid_rotate_second_drag_0132.tcl`. ~~(§11.9b) STILL OPEN — the PURE-ORTHO variant (after_34)~~
   **FIXED (0132 §11.9b)**: the SAME body-on-own-copper defect via a plain +dx translation of an
   already-rotated body (move_rot==0, accepts at attempt 0, `diag_relay==0`) NEVER reaches
   `fluid_manhattanize_relay_diagonals` (trace: `manhattanize_relay_diagonals: SKIP`) so the 0132
   reroute doesn't fire. ROOT CAUSE (traced, NOT the earlier `place_moved_wire` guess): `place_moved_wire`
   lays a CLEAN +y feed (`100 80 100 90`); the END-cluster **`insert_exit_stubs`** then SLIDES it -x back
   through the body because `get_pin_escape_normal`'s nearest-edge test on the TEXT-INFLATED `inst.x1..y2`
   mis-picks a -x/Left normal for the rot-1 solar_ctl TRIANG pin (a corner pin of an asymmetric symbol),
   so a route already exiting +y straight reads as "bends at the pin → slide". (The reverted hoist of
   `fluid_reroute_body_crossing_feeds` to every accepted fluid stretch false-fired on ordinary 2-pin
   moves and deleted legit copper — that whole approach was wrong; the real defect was never in the elbow
   or a reroute.) FIX: a pin-inclusive body-box guard in `insert_exit_stubs` (move.c ~2046) — if the stub
   or the slid leg would thread the moved instance's OWN `fluid_inst_body_box` (escape-normal exempt),
   DECLINE the slide and keep the pre-slide over-the-top route. Never worse (P3 aesthetic pass; a TRUE
   outward normal slides AWAY from the body and is exempt, so ordinary device feeds are untouched); gated
   `fluid_editing` so the legacy `wire_exit_stub` feature is byte-identical. Test
   `test_fluid_ortho_second_drag_0132.tcl` (P5 promoted xfail→hard check; XPASS), evidence
   `before_10.sch`/`after_34.sch`. Regression: wireedit ALL PASS, all 15 `test_fluid_*` GREEN.
   ~~(§11.9c) the CTRL1 sibling (after_35): BODY-driven backbone shove~~ **FIXED (0132 §11.9c)**: the
   SAME gesture left a second defect on the OTHER pin — CTRL1's stationary vertical backbone
   `N 140 -20 140 100` perpendicular to the move, engulfed by the advancing body (pin (140,80) landed
   mid-run), threading it in the save. PIN-driven shove never matches (needs a parallel stub driven
   past its junction), reroute/delete layers gated `diag_relay`. FIX: `fluid_shove_body_crossing_backbone`
   (move.c) — a per-gesture real-END pass on the accepted PURE-ORTHO path (`!diag_relay`), sited AFTER
   the attempt ladder + trim/cleanup/ownership-normalize on CLEAN committed geometry (an earlier
   mid-gesture siting fought dirty transient state — phantom merges — and was reverted; timing IS the
   fix). Gates: pure-axis, rot-free, `fluid_startsel_wires==0`, pin column strictly inside own body
   box, same-net perpendicular THROUGH-RUN with copper strictly BOTH sides of the pin (excludes
   one-sided escape feeds — the over-fire guard), no foreign pin on the run, no pin-less foreign weld.
   REBUILD: collapse run to pin, ONE new backbone at `fluid_grid_above(body edge)` spanning only
   [pin..attachment corners] (dead overhang DROPPED — shoving it would cross the foreign rail),
   attachments translated, pin re-fed via jog; mem-snapshot + dual verify (restore-START name AND
   preserve-entry geometric partition) with exact revert. Reshapes NAMED copper under verify (second
   §11.1 crack; props copied from the run, never renamed). Test `test_fluid_ortho_ctrl1_shove_0132.tcl`
   (P5 promoted xfail→hard; new P5b WHOLE-NET body-clearance invariant — the after_34 single-wire-check
   lesson — sabotage-verified RED on after_35). Evidence `after_35.sch`/`after_35_fixed.sch`.
   ~~(§11.9d) the SECOND-generation incremental drag (after_36): the one-sided inward feed~~
   **FIXED (0132 §11.9d)**: every subsequent +dx drag re-engulfs the previously-shoved backbone and
   lands the moved pin on the run's END (copper only on the body-interior side), so the feed threads
   the WHOLE body to reach its rail yet reads as a "one-sided escape" — the after_35 shove's
   strictly-both-sides over-fire guard DECLINED it and the through-body wire was saved (the user's
   after_36 complaint, recreated on every incremental drag). ROOT CAUSE: the both-sides gate was a
   crude proxy for "threads the body"; it rejected BOTH the CTRL1 inward feed (bad) and the TRIANG +y
   escape (good). FIX: re-gate on `min(run_hi,ahi) − max(run_lo,alo) > grid` — same-net copper strictly
   INSIDE the body along-span by more than one grid (the user's spec: own copper stays ≥1 grid outside
   the body). A pin mid-run OR a one-sided inward feed both qualify; the TRIANG +y exit (2.5 < grid
   inside) still declines. The downstream rebuild already handles a pin at the run END (span from
   palong + corners, jog re-feed). Also (user request) the shove now fires LIVE on every RUBBER
   live-commit step, not only at the LMB release — the `!commit_now` gate at the call site was dropped;
   release==stepwise-safe because each RUBBER step and the real END both restore-to-pristine and
   re-derive from the total delta (verified: FLUID_TRACE shows `bodyshove … SHOVED` under a
   `what=RUBBER commit_now=1` step and again at `what=END`, identical result). Test
   `test_fluid_ortho_ctrl1_shove_0132.tcl` drag-2 (was xfail, promoted to hard check + drag-2 P5b
   whole-net clearance). Evidence `before_10.sch`/`after_36.sch`. Guards G1–G5
   (`test_fluid_bodyshove_guards_0132.tcl`) unaffected — all first-drag pin-mid-run, identical gate.

   ~~(§11.9e) the DIAGONAL drag (after_37, defect P-D "ref-net-drop"): a moved pin's OWN feed deleted~~
   **FIXED (0132 §11.9e)**: a two-axis drag (delta +20,−10) whose pure-ortho X-then-Y decomposition
   shorts + rolls back to the rigid `diag_relay` fallback. The fallback is repaired ONLY by
   `fluid_manhattanize_relay_diagonals` (the whole `!diag_relay` ortho shove/END battery is gated off);
   its post-accept cleanup `fluid_reroute_body_crossing_feeds` → `fluid_delete_body_crossing_copper`
   DELETED REF's own feed `-60 -140 120 -140` because REF's pin (120,-140) lies strictly INSIDE the
   pin-inclusive body box (under rot1 the symbol-left pins map to the box interior, so the lead must
   cross the box — yet it is clear of the real device-body polygon at y=-140 vs body y[-120,50]). The
   delete's partition-verify passed because a transient relay weld momentarily bridged REF to sibling
   copper; a later prune removed the weld → REF ORPHANED, and the surviving LED net annexed #net1. It
   SAVED silently because a P1 disconnect is not in the B3 refuse signal (`fluid_check_move_invariants`
   returns `short_delta + dev_merges`, disconnects excluded — the documented log-only P1 design). ROOT CAUSE (from the
   trace, NOT the static after-file): at the accepted state both nets were connected (partition_changed
   =0); the corruption is entirely in the diag_relay cleanup's false-positive deletion. FIX:
   `fluid_wire_end_on_moved_pin` — the delete NEVER removes a wire whose endpoint is exactly on a moved
   (SELECTED) instance pin; that is the pin's lead and deleting it can only orphan the pin. Safe for the
   §11.9b self-drop case (there the feed is re-routed body-free first so it is not a delete candidate;
   the deleted stale backbone does not touch the pin). Reproduction NEEDS a real-X multi-motion gesture
   (a single `move_objects` starts from pristine and does not accumulate the RUBBER history the END
   cleanup consumes — it does not reproduce the orphan). Test
   `test_fluid_diagonal_ref_drop_0132.tcl` (self-skips without DISPLAY; geometric pin-touch check —
   `instance_net` reports a phantom auto-name for an orphaned pin and cannot tell connected from
   orphaned). Verified: real gesture REF geom-connected 0→1 pre/post-fix, both top nets stay separate;
   5 fluid suites green; wireedit 57/57. Evidence `before_10.sch`/`after_37.sch`.

   ~~(§11.9f) the DIAGONAL drag (after_37, defects P-A/P-C): CTRL1 vertical left threading the body~~
   **FIXED (0132 §11.9f)**: on the same diagonal drag the CTRL1 x=140 backbone (the moved pin lands on
   it MID-SEGMENT) is left threading x1's body. The diag_relay cleanup
   (`fluid_manhattanize_relay_diagonals` → `fluid_reroute_body_crossing_feeds`) can only RE-ROUTE a
   moved pin's feed to an existing same-net vertex; the nearest outside-body vertex is IN-COLUMN
   (140,100) so the feed never pulls past the body edge, and the verified delete reverts the vertical
   as LOAD-BEARING (only path to the naming label l1). The sideways body-driven shove
   (`fluid_shove_body_crossing_backbone`, §11.9c/d) is the one pass that fixes this — but it derives
   its motion axis from `xctx->delta[xy]` and PURE-AXIS-gates itself off (returns 0) for a diagonal
   delta (both nonzero). FIX: on the diag_relay branch, right AFTER the manhattanize (so wires are
   already Manhattan), run the shove ONCE PER AXIS by scoping `xctx->deltax/deltay` to one axis at a
   time (x-run: deltay→0; y-run: deltax→0; restored after). `delta` is read ONLY at the shove's
   pure-axis gate (6833-6835, verified — every downstream gate uses xmove/pc/palong), so the spoof is
   side-effect-free; each pass double-verifies with exact revert, so a pin whose run is on the other
   axis, escapes the body within a grid, or would short is left byte-identical (never worse). END only
   (rides under the END-only diag manhattanize). Result: CTRL1 shoved to x=160 (one grid past body
   edge 150), pin re-fed via jog; REF/LED untouched (the y-run pass DECLINES REF's horizontal feed).
   Test `test_fluid_diagonal_ref_drop_0132.tcl` extended with P-A/P-C body-clearance checks (same
   gesture; 9 checks). Verified: CTRL1 SHOVED trace, ctrl1_shove 14/14 (ortho path untouched), P-D
   preserved, wireedit 57/57.

   ~~(§11.9g) the DIAGONAL drag (after_37, defect P-B): old-elbow overhangs left dangling~~
   **FIXED (0132 §11.9g)**: the same diagonal drag leaves DANGLING named-copper stubs at the OLD
   pin-riser elbows the moved pin vacated — TRIANG's `80 90 100 90` (free at 80,90) and CTRL1's elbow
   (free at 120,100). The diag_relay stale-feed prune (0108, inside `fluid_manhattanize_relay_diagonals`)
   that should retract these SKIPPED them via the §11.1 named-rail blackout
   (`if(fluid_wire_explicit_lab(i)) continue;`): both overhangs carry an explicit lab. trim keeps each
   fragment SPLIT at the riser T (100,90 / 140,100), so they are WHOLE stubs with no interior junction
   → `fluid_retract_orphan_tail` reaches its DELETE branch, which refused named copper
   (`&& !fluid_wire_explicit_lab(kw)`). FIX: (1) drop the prune's per-wire §11.1 gate so named copper
   reaches the pruner (RETRACT is already name-safe — keeps the wire+lab, partition-verified); (2) add
   `fluid_same_name_survivor(kw,ox,oy)` + an `allow_named_stale` param so the DELETE branch may remove a
   named stub ONLY when its label survives on live copper touching the FAR end AND the partition is
   preserved. The survivor check closes the pin-indexed partition-verify's blind spot (a pin-less named
   net — a `lab=VDD` stub — is invisible to `fluid_loop_partition`, so partition-equal alone would let
   the SOLE carrier of a name be deleted, silently dropping the label); requiring a same-lab survivor
   guarantees the last carrier is never removed. Scoped by flag to the diag_relay prune ONLY (the other
   two `fluid_retract_orphan_tail` callers pass 0 → byte-identical §11.1 delete-blackout); the per-end
   gates (drag-orphaned NOW, not on a pin, START deg≥2 = was a real junction, never a user's deliberate
   deg≤1 named-stub tip) scope it to genuinely stale elbows. Because the prune runs BEFORE the §11.9f
   shove, it deletes the x=140 elbow tails first and the shove then moves a CLEAN CTRL1 to x=160 (no
   residual dead branch). Result: TRIANG = `100 70 100 90`+`100 90 220 90`+`220 20 220 90`; CTRL1 =
   `140 70 160 70`+`160 -20 160 70`+`160 -20 220 -20` — both clean. Test extended (12 checks; the 3 P-B
   checks FAIL without this). Verified: ctrl1_shove 14/14, bodyshove_guards 14/14, rotate_body/second
   green, wireedit 57/57 (incl wireedit_54 named-rail). ALL FOUR after_37 defects (P-A/P-B/P-C/P-D) fixed.
10. **Mid-drag unguarded keys**: Delete and descend 'e' run during STARTMOVE (no
    `!(ui_state&STARTMOVE)` guard) → undo corruption / resurrected geometry / UAF class.
    Sweep the whole key dispatch.
11. **Novelty laundering**: trim's split/weld makes untouched user copper read novel-span
    → straighten reshapes user detours (P7). Fix: id watermark (`id <= START counter` ⇒
    pre-existing) + sub-span-of-START-span test — both strict narrowings.
    **Dual (0139, after_42)**: the OPPOSITE hazard — a MULTI-GESTURE drag SHRINKS a
    pre-existing trunk (its end tracks a moved pin's column, per-gesture snapshot re-captured
    each arm) so it reads novel and the jog-trunk shove WRONGLY skips it, leaving a body-cross.
    Fix: `fluid_wire_pretracked_shrink` re-admits a novel wire that is collinear inside a
    START footprint AND has an endpoint on a moved-pin column. Novelty is a two-sided gate:
    over-fire (laundered user copper) AND under-fire (pin-tracked shrink) both bite.
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
14. ~~**Ripup jogs the wrong pin → welds 1-grid-apart neighbor buses → cleanup deletes both
    nets** (0134, after_38)~~ **FIXED (0134)** — but the *true* root was NOT the ripup jog
    (static analysis mis-fingered it; runtime tracing corrected it, like 0132 P-D).
    `doc/claude/issues/0134-*.md`. Diagonal drag (-20,-10) of a device with two NORTH-edge
    input pins on parallel buses one grid apart (REF y=-140, LED y=-150). The accepted path is
    END **attempt=0 (leg-split, `diag_relay=0`)**, and the wire that welds REF↔LED is
    **`insert_exit_stubs` (:1996) sliding REF's exit leg one grid north (y=-140→y=-150) onto
    LED's bus** — the documented no-short gap (comment ~:8500: the exit slide can shift a leg
    one grid onto a DIFFERENT net's wire, caught log-only). It had only a body-cross decline,
    no foreign-net decline. **FIX** (2 hunks, gated `fluid_editing`): (a) `insert_exit_stubs`
    foreign-net guard — `fluid_seg_touches_foreign_lab` (:1996) + decline (:2094): DECLINE the
    slide if the stub/leg touches a stationary wire of a different net label (P3, never worse);
    (b) pure-ortho body-shove **per-axis spoof** (:8705): a diagonal drag now accepted on the
    pure-ortho path needs `fluid_shove_body_crossing_backbone` fed ONE axis at a time (it
    pure-axis-gates off a diagonal delta) — mirrors the §11.9f diag_relay site (:8680); restores
    the after_37 CTRL1 x=160 shove that (a) exposed. RED test
    `test_fluid_diagonal_neighbor_bus_0134.tcl` 10/10; ref_drop_0132 12/12; exit_stub_0111 20/20.
    **0135 D1 (follow-on of hunk-2, FIXED)**: the per-axis spoof made the shove run on diagonal drags,
    exposing an over-fire — on a SW diagonal (−10,+20) of solar_ctl the y-run shove dragged REF's
    HORIZONTAL escape feed one grid past the FAR (south) body edge (`ct=100`), threading the whole body
    (after_39). `dirpos` (motion "ahead") mis-models a pin whose real escape is on the other axis. FIX:
    an escape-side decline gate in the shove (:7074) — DECLINE when the pin's lead escape normal opposes
    the relocation dir along the shove axis; legit CTRL1 shoves (escape ⊥ shove axis) untouched.
    `doc/claude/issues/0135-*.md`, test `test_fluid_diagonal_shove_throughbody_0135.tcl`. **0135 D2 (FIXED,
    route-quality, candidate #1 / §11.9a)**: the same drag left REF's declined feed exiting perpendicular-WEST
    grazing the body top, not NORTH along its lead normal. Root (trace, not static — the P6 hypothesis was
    wrong, P6 is never called for REF): after leg-0 the `move_regrab_follow_set` re-selects REF's feed as
    `SELECTED`-whole, so leg-1 takes `place_moved_wire`'s pure-translation branch and the fixture's horizontal
    orientation is preserved (grazing once the body moves under it). FIX: `insert_exit_stubs` turns its
    single-grid slide into an OUTWARD SEARCH `d=1..6` for grazing feeds (own-body → continue; STATIONARY body
    → break/decline; foreign short → continue), walking REF past LED's y=−130 to a clean y=−140 north exit;
    non-grazing keeps `dmax==1` byte-identical. Dissolves D1 at the source in this fixture. Test extended (9
    checks, 3 D2 RED pre-fix); wireedit 57/57 (the STATIONARY-body break closed a 0090-staircase regression).
    **STILL LATENT (no test reaches it after the fix, so NOT fixed):** the ripup jog
    (`fluid_ripup_foreign_pin_short` :4220 → `fluid_jog_pin_off_backbone` :4071) CAN still jog
    the wrong pin (walks pin-pairs **in index order**, reaches the non-invader first) and its
    verify (:4188) is **pin-pair-indexed + single-pin-net BLIND** (orphaned/merged singleton
    ids :2483 ≡ START singleton :2481 → `partition_changed()==0` masks an orphan/weld). Add its
    foreign-touch + no-orphan guard WITH a test that forces attempt=1 before touching that
    load-bearing function. **Route-quality (defect C) — ROOTED (candidate #1)**: `get_pin_escape_normal`
    now derives the moved pin's outward normal from the symbol **lead geometry**
    (`get_pin_lead_normal`, move.c: pin-rect-centre tip → the `L` lead line ending there → tip−inner,
    rotated by the inst rot/flip) instead of the text-inflated-bbox nearest-edge PROXY, gated
    `fluid_editing` (legacy `wire_exit_stub` path byte-identical; ambiguous/absent lead falls through
    to the proxy). This feeds the P6 L-elbow bias (`fluid_p6_bias_ml`), so TRIANG (solar_ctl rot1,
    symbol +x lead → world +y/south) exits VERTICALLY rather than staircasing — and nmos4 bulk `b`
    (near-centre) now escapes +x (its lead) not the proxy's −y (into the body). The raw ml default
    (`recompute_orthogonal_manhattanline` actions.c, |dx| vs |dy|, tie→ml=2) is unchanged but overridden
    by the p6 bias when a lead resolves; `dir=in|out` (electrical) is NOT used. Test
    `tests/headless/wireedit/test_wireedit_28_escape_normal.tcl`.
15. ~~**Body engulfs a same-net trunk NOT incident to a moved pin → saved through the body** (0136,
    after_40)~~ **FIXED (0136)**. SE diagonal drag (+60,+30) of solar_ctl; accepted END attempt=0
    leg-split (`diag_relay=0`, pure-ortho). CTRL1 reaches its label through a STATIONARY x=140 trunk the
    advancing body now engulfs, connected to the moved pin (150,100) through a JOG (150,130)→(140,130) —
    so the trunk column x=140 is NOT any moved pin's column. `fluid_shove_body_crossing_backbone` is
    pin-incident (seeds the run at the pin's OWN column :7056/:7067/:7077) → invisible (all pins decline
    `corners=0`); the diag_relay reroute/delete is gated off on the ortho path AND its nearest-outside
    anchor is the pin's own riser end (the §11.9f situation that needed a SHOVE, not a reroute). FIX: new
    `fluid_shove_jog_separated_trunk` (pass catalog) — TRANSLATE a PRE-EXISTING, LOAD-BEARING (bridge),
    jog-separated same-net trunk 1 grid past the crossed body edge (x=140→170) + re-anchor attachments,
    body-free + DOUBLE-verified, exact revert. Two over-fires gated during dev: a NOVEL detour leg
    (novelty gate, wireedit_36 j) and a REDUNDANT user-ring edge (bridge gate, wireedit_45 U/T).
    `doc/claude/issues/0136-*.md`, test `test_fluid_jog_separated_trunk_0136.tcl` (RED→GREEN, self-skips
    without X); wireedit 57/57. **DEFERRED (defect 2, `neighbor-net-riser-near-miss`):** REF's #net2
    riser `130 -130 130 -110` crosses the LED #net1 rail at (130,-120) — a 4-way crossing, NOT a short
    (no endpoint coincidence); a separate REF/LED routing near-miss, no test yet.
    **NOTE (0136 defect 2, superseded analysis):** the REF/LED crossing is TOPOLOGICALLY FORCED, not a
    routable defect — REF{pin,src} and LED{pin,src} interleave on the convex hull (the two nets are
    LINKED), so a crossing is forced by the Jordan curve theorem for ANY routing; before_39 carried it
    too (at (-50,-140), near the sources), the drag only RELOCATED it to the pin-exit. There is also no
    invariant against different-net wire crossings (WIRING §9: P1/P2/P3/P4/P5-BODY/P6/P7 — none forbid a
    wire-wire cross; a non-endpoint cross is electrically correct, drawn with no junction dot). Left as-is
    (WONTFIX class): not an invariant violation, and unremovable without moving a fixed terminal.
16. ~~**Push-only pipeline leaves un-reclaimed retreat slack → non-minimal copper** (0137)~~ **FIXED
    (0137).** Minimum copper is a first-class goal on EVERY move, not just P3/P5 compliance. The
    push-through slide shoves a moved pin's perpendicular jog OUT on approach but nothing pulls it IN on
    retreat; the stretched escape stub becomes pre-existing copper the straightener's novelty gate
    protects, so the overshoot grows 2·δ per round trip (before_41: up30/dn30 → copper 130 vs minimal 70,
    unbounded). FIX: `fluid_jog_is_moved_pin_escape_overshoot` re-admits exactly that reversal shape into
    `fluid_straighten_reversals`, whose verified 0111 pin-landing slide compacts it to the 1-grid escape;
    narrow (moved pin only = P7 guard; rot==flip==0; reversal-only = shorten-safe), never worse by the
    pass's own exact-revert verify. `doc/claude/issues/0137-*.md`,
    `test_fluid_compact_escape_stub_0137.tcl` (RED→GREEN), wireedit 57/57.
    **Extended by 0138 (FIXED):** the reclaim BAILED on explicit (named) nets, so `after_41`'s TRIANG/CTRL1
    crossbars stayed stranded (y=150/160) while the auto `#net` pins compacted. Fix opens the escape-overshoot
    to named nets (buses excluded; verify keeps it rename-safe), adds an OUTWARD SEARCH (nearest verifying
    row when a sibling holds the 1-grid row → CTRL1 y=140) and a BODY GUARD on every overshoot slide (so the
    named-net reclaim never plows a device — keeps 0136 fixed). `doc/claude/issues/0138-*.md`,
    `test_fluid_compact_named_crossbar_0138.tcl` (RED→GREEN, 13/13), stable fixpoint. **STILL OPEN (min-copper
    family):** multi-jog staircases whose whole run could shift. Extend the predicate family RED-first as
    cases surface.
17. ~~**Second gesture buries a pin-tracked trunk in the moved body** (0139, after_42)~~ **FIXED (0139).**
    Sibling of 0136, SAME fixture/symbol/pass. A TWO-gesture drag of solar_ctl: gesture 1 drags the LED
    `#net1` crossbar to y=−130 (clear then), gesture 2 advances the body top to y=−140 engulfing it; the
    moved pin's stub stretches south to the trapped elbow (80,−130) → crossbar threads the body. The 0136
    `fluid_shove_jog_separated_trunk` — the pass built for exactly this — declined for TWO independent
    over-strict gates: (a) its `!fluid_wire_is_novel_span` PRE-EXISTING gate read the crossbar as
    this-drag copper because gesture 2 SHRANK its span (x2 90→80, the end tracked the LED column; per-arm
    snapshot re-capture — landmine 11 dual); (b) its pin-partition LOAD-BEARING gate is BLIND to a
    SINGLE-PIN net (`#net1` = LED + dead-end rail). FIX (3 parts): `fluid_wire_pretracked_shrink`
    re-admits a collinear-inside-START, endpoint-on-moved-pin-column shrink; a WIRE cut-edge fallback
    (flood with run doomed) for the 1-pin case; and the side loop STEPS the target grid-by-grid past a
    NEIGHBOUR net (REF `#net2` at y=−170 → `#net1` to y=−180). Result: crossbar y=−130→−180, body-clear,
    nets distinct (the rail's mid-span crossing of #net2 at (−50,−170) shares no endpoint → benign, per
    0136 defect 2). `doc/claude/issues/0139-*.md`, `test_fluid_second_gesture_body_cross_0139.tcl`
    (RED→GREEN 13/13, baseline fails exactly the 3 body-cross checks), wireedit 57/57, 0136 11/11.

15. ~~**A user-authored `#` label is read as regenerable by the fluid label guards**~~
    **FIXED (0162)**. `fluid_wire_explicit_lab` (~:2945) returned `lab[0] != '#' ||
    strpbrk(lab, "[:")` and the H2 doom guard (~:3196) exempted `lab[0] == '#'`; both now test
    `is_auto_net_name()` (strictly `#net<digits>`), so a user-authored `lab=#foo` is protected
    like any other name. The symptom was worse than "drops a label": `fluid_wire_explicit_lab`
    is the **universal named-copper decline** consulted by 12 call sites, so a `#foo` net was
    reshapeable by every de-shorter (measured on the 0105 topology: a `#foo` backbone was
    rebuilt as a jog, 16→17 wires, where a `VDD` backbone is a blackout and the move is
    REFUSED; and on the 0088 loop, 2 of the user's 4 wires deleted). The direction is monotone
    (`is_auto_net_name` ⊂ `[0]=='#'`) — it can only protect MORE copper — and a sweep of every
    committed `.sch`/`.sym` found zero non-`#net<digits>` `#` labels, so nothing in-tree moves.
    **Consequence to know:** a `#foo` net now inherits the named-rail blackout of risk §11.1 —
    the de-shorters decline and the END gate REFUSES instead of rerouting.
    **Caveat:** the H2 half has **no discriminating fixture** — sabotaging it either way changes
    nothing, and a 36-shape sweep on an H2-only diagnostic build found zero differences (the
    branch only fires when the loop pass would doom the LAST carrier of a name, which a
    lab_pin-named net never presents). Kept as policy alignment, verified by inspection only.
    `doc/claude/issues/0162-*.md`, test `test_wireedit_58_user_hash_label_0162.tcl` (9 checks,
    three-way VDD/`#foo`/`#net99` comparison so it cannot pass by blanket-protecting `#`).

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
get_pin_escape_normal :1896 (0134: lead-geometry primary source `get_pin_lead_normal` just above it,
fluid-gated; proxy is the fallback), snapshots :2262-2328, novelty :2432-2478, partition/verify
:2232/2378/2496/3641, healers (§4 table), obstacle router :5148, restore/discard
:5935/5955, regrab :5975, invariant check :5869, FLTRACE :1986.
Track-D gesture context: `typedef struct {...} Fluid_gesture` + the one instance `fluid_g`
(declared ahead of the first consumer, ~:1437) hold the four START snapshots AND the folded
hidden-parameter scratch (slide_pushthrough_on / leg_future_* / stretch_premove_* / *_doomed_from);
lifecycle `fluid_gesture_arm` / `fluid_gesture_free` (the latter also called by clear_schematic).
Track-D pass table (D3): `Fluid_pass` typedef + FLUID_PASS_* gate bits + `Fluid_verify_dir`/
`Fluid_mut_class` enums + `static const Fluid_pass fluid_end_passes[]` (all just after
fluid_manhattanize_relay_diagonals); the END cluster driver loop lives at the old call site
inside move_objects (§3 step 9). Observability + oracles (D4/D5/D6, same region after the table):
`fluid_pass_skip_gate` (SKIP-reason name), `fluid_wsig_*` (id-keyed changed-count / geom-set
compare), `fluid_dump_wires` (FLUID_TRACE_DUMP), `fluid_end_cluster_idempotence_probe`
(FLUID_IDEMPOTENT_CHECK, called after insert_exit_stubs), `fluid_harness_snapshot_arm` /
`fluid_harness_run_pass` (the `xschem fluid_snapshot arm` / `xschem fluid_pass <name>` verbs in
scheduler.c `xschem_cmds_f`). Env knobs: FLUID_TRACE (per-pass firing + changed=N),
FLUID_TRACE_DUMP (wire-array dump), FLUID_IDEMPOTENT_CHECK (fixpoint oracle; `run_wireedit.sh
--idempotent`). All default-off / byte-identical.
`select.c`: select_attached_nets :1579, select_wire fold :1040.
`callback.c`: cadence drag :6213-6268, 'm'/'M' :4796-4891, mid-drag transforms
:4592/:5100/:5124 (ALT-R/F/V coerce ROTATELOCAL→group via `connected_drag_group_transform`
when >1 user object, issue 0114); placement-commit latch `place_click_committed`
set at the end_place_move_copy_zoom press site, consumed at handle_button_release top
(forces mouse_moved=1 to suppress the cadence deselect-others, issue 0113).
`check.c`: trim_wires :182, maintain_wire_segments :725, break_wires_at_attach_points :672.
`store.c`: wire funnel :339-468. `netlist.c`: prepare_netlist_structs :1663,
get_inst_pin_coord :753, touch → clip.c:234. `xschem.h`: xWire :497, ROTATION :386,
sel macros :258, fluid xctx fields :1286-1299.
Tcl feedback to user: `ciw_echo` ([[ciw-feedback-channels]]), never puts/statusbar.

**Maintenance**: when you fix a wiring issue, update §11 (retire the risk or add the new
one), the pass catalog if a pass changed, and the ordering list if the pipeline moved.
