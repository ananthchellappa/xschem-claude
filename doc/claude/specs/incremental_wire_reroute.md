# Spec: Incremental, tool-owned wire re-routing (decoupled from selection)

Status: **DRAFT** (2026-07-05, branch `fluid-editing`). Written after the `nice_drag_rerouting`
Phase 0–3 work and a concrete failing case supplied by the user
(`tests/from_user/{before,after,beautified}.sch`). This spec is a **pivot** in mechanism, not a
throwaway of `nice_drag_rerouting.md`: the predicates P1..P8 (§4 of that spec) and the golden
harness still define *what "nice" means*; this document changes *how the follow is driven* and
*when it runs*.

Prereq reading: `doc/claude/specs/nice_drag_rerouting.md` (predicates, phase history),
`doc/claude/specs/wire_segment_splitting.md`, `doc/claude/specs/fluid_editing.md`,
`doc/claude/code_analysis/wire_follow_stretch_move.md`.

---

## 1. Three theses

The first two come from watching the tool fail the user's R18 case vs Cadence Virtuoso; the third
is the generalization that keeps the design honest.

1. **Decouple ownership.** When the user grabs and moves a **selection**, the *non-selected* wires
   that connect into that selection must **not** be folded into the user's selection. They are
   **tool-owned**: the router rips them up and re-draws them. The user owns the selected geometry;
   the tool owns the wiring that must follow. (Today the two are conflated — see §3 — and that
   conflation is the root of the short.)

2. **Incremental, not release-time.** Do **not** wait for the mouse release to recompute the
   route. Re-route **every time the selection's position changes by one snap-grid increment**
   (`cadsnap`), *during* the drag. Each step is a small local delta, so the reroute is a small
   local decision (extend/retract a leg, add/remove a bend, slide a corner one grid) instead of a
   from-scratch global solve that has to guess a whole new topology at once — and guesses wrong.

3. **The unit of motion is the SELECTION, not "an instance."** "Instance being dragged" is too
   narrow — a world-class tool moves *whatever the user selected*: instances, wire segments, or a
   mix. Generalize every rule below from "instance" to "selection" and from "instance pin" to
   **"terminal of the selection"** (§4): the points where non-selected wiring crosses into the
   moving set. The R18 case is then just the degenerate selection = {one instance}.

The user's key insight (§8): **the problem is far easier to solve incrementally.** A big
release-time jump forces a hard global routing problem (and the current heuristics lay a leg
straight across a device → short). A sequence of one-grid steps is a *continuous
constraint-maintenance* problem: at each tick you keep connectivity (P1) and no-short (P2) and
nudge toward beauty. The route "flows" with the cursor.

## 2. The failing case (ground truth)

Files in `tests/from_user/`. Launch used by the user: `src/xschem --script src/cadence_style_rc`
(so `cadence_compat=1`, `fluid_editing=1`, `orthogonal_wiring=1`, and `cadence_compat` forces
`autotrim_wires=1`).

**before.sch** — three distinct nets around an ammeter `v8` (pins `plus`=(-390,140),
`minus`=(-330,140); body spans x∈[-390,-330] at y=140):
- `#net1` = R18 pin `M` (-420,-80) → vertical riser up to the y=140 bus → left to x=-550, and
  right to v8.`plus` at (-390,140). (v8.plus is on `#net1`.)
- `#net2` = C12 bottom (-420,-170) → R18 pin `P` (-420,-140).
- `OUT` = v8.`minus` (-330,140) → opin `p5` at (-270,140).

**The move.** R18 dragged south-east: (-420,-110) → (-310,10), i.e. Δ=(+110,+120). R18's own
pins land clean — neither pin touches a foreign net. **The move is legal.** (In the §4 model this
is the degenerate selection S = {R18}; its terminals are R18's two pins.)

**after.sch (BUG, current binary @ `c0ce9d06`).** The redraw of R18's `M`-pin riser lays its
horizontal leg along y=140 and `trim_wires` merges it into the bus, producing
`N -550 140 -310 140` — a single wire running **straight through v8** (past both -390 and -330).
Result: v8.plus and v8.minus are now the **same** wire → the ammeter is shorted → `#net1` and
`OUT` merge (`OUT` wins, `#net1`/`#net2` renamed). Reproduced headless in **every** gate combo
including fully default (`fluid=0 autotrim=0 stub=0`), so this is the **base stretch-follow**
(`place_moved_wire` manhattan jog + `trim_wires`), not the gated exit-stub code.

**beautified.sch (ACCEPTABLE target, illustrative — not a byte-golden).** A hand-authored nice
result (drawn for R18 near (-320,-60); treat the *style*, not the exact endpoint, as the spec):
- R18.`M` riser sits at **x=-410**, rises to y=140, and reaches v8.`plus` via a short horizontal
  `N -410 140 -390 140`. It **stops at -390 and never continues to -330** → v8 not shorted,
  `#net1` stays distinct from `OUT`.
- The corner where the riser meets the bus is a **visible T-junction at (-410,140)** — offset
  from the pin, not hidden underneath it.

## 3. Root cause — "follow" is implemented as "select + stretch"

Code path for a plain cadence instance drag (`callback.c:6045`→`6063`):

```c
select_attached_nets();      /* select.c:1504 */
move_objects(START,0,0,0);   /* move.c */
```

`select_attached_nets()` walks each **selected instance's pins** (ELEMENT branch, select.c:1518)
**and each selected wire's endpoints** (WIRE branch, select.c:1545) — so the notion of "attachment
points of the selection" already exists in the code; it just processes them wrongly. For each, it
finds every wire with an **endpoint on that point**, and marks **only that endpoint**:

```c
select_wire(i, SELECTED1, ...);   /* wire end-1 joins the move */
select_wire(i, SELECTED2, ...);   /* or end-2 */
```

`SELECTED1`/`SELECTED2` is a **partial (single-endpoint) selection**. The generic move machinery
then *stretches* that endpoint with the instance. `compute_wire_slide()` (`move.c:1329`)
**promotes** perpendicular corner wires to full `SELECTED` and ropes in neighbouring wires at the
corner so a whole run translates. At release `unselect_partial_sel_wires()` clears the marks.

Consequences, all of which the failing case exhibits:

- **Wire-follow == translating selected geometry.** The tool *moves existing wire segments*
  rather than *rip-up-and-reroute*. Translating a corner drags a whole bus segment sideways —
  which is exactly how the y=140 bus got stretched across v8.
- **The router is obstacle-blind.** `place_moved_wire`/`compute_wire_slide` are local jog rules
  keyed off `SELECTED1/2` and `manhattan_lines`; nothing consults instance bodies or foreign-net
  pins. There is no "route this net around v8" step.
- **Ownership is conflated.** User-selected wires (should translate rigidly, user owns them) and
  auto-grabbed follow-wires (should be tool-rerouted) share one `SELECTED*` mechanism, so the
  tool cannot treat them differently.
- **Release-time only.** The reroute (`place_moved_wire`, `trim_wires`,
  `remove_move_orphan_wires`, `insert_exit_stubs`) runs in `move_objects(END)`. During `RUBBER`
  only a rubber-band preview is drawn. The user sees the bad route only after committing.

The `nice_drag_rerouting` Phase-4 "detect-and-refuse at END" idea sits *on top of* this broken
mechanism. This spec replaces the mechanism instead.

## 4. Model — the selection and its terminals

Generalize away from "instance." Define three sets at move START:

- **Selection `S`** — everything the user selected: instances, wire segments, and any other
  objects. `S` translates **rigidly** by the drag delta. The user owns `S`'s geometry.
- **Terminal of `S`** — a point `p` where the *fixed* world connects into the *moving* selection.
  Formally: `p` is a connection point of some object **in** `S` (a selected instance's pin, a
  selected wire's endpoint, or a point on a selected wire that another wire taps mid-span) **and**
  some wire **not** in `S` touches `p`. Terminals are the **cut set** of the selection boundary —
  the electrical ports through which the moving group stays wired to the rest of the schematic.
  They translate with `S` (each terminal is carried by the selected object it belongs to).
- **Follow set `F`** — the **non-selected** wires incident at a terminal. `F` is **tool-owned**:
  not in the user selection, not drawn selected, **rip-up-and-rerouted** each step (not
  translated). Each `f ∈ F` has a fixed **anchor** (its far end, outside `S`) and a moving
  terminal (its near end, on `S`'s boundary); the router redraws `f` from anchor to the terminal's
  new position while preserving `f`'s net.

This is the whole reframe: **"instance" → `S`, "instance pin" → terminal of `S`.** Wire-follow is
then "for each terminal, reroute its follow-wires to track the terminal," regardless of whether the
terminal is an instance pin or a selected wire's endpoint. Internal wires (both endpoints in `S`)
are not follow-wires — they ride along rigidly inside `S`, no reroute.

### 4a. Ownership decoupling (the mechanism change)

Today `select_attached_nets()` finds the terminals (both branches, §3) but then **selects** the
follow-wires (`SELECTED1/2`) and translates them. The change:

- Discover terminals exactly as `select_attached_nets` does (selected instances' pins + selected
  wires' endpoints; add mid-span-tap terminals), but put the incident non-selected wires into a
  **tool-private follow set `F`**, *not* the user selection. Do not mark them `SELECTED*`; do not
  draw them selected.
- Snapshot each follow-wire's pre-move anchor + terminal (the existing `stretch_grabbed_xy`
  capture already stores endpoint coords — reuse/rename as the `F` snapshot).
- Key each `f ∈ F` to its terminal and its net (`prepare_netlist_structs` at START) so the router
  knows what to preserve.
- **User-explicitly-selected wires stay in `S`** (rigid), never in `F`, even if they also touch a
  terminal — the user asked for them (`nice_drag_rerouting` §2; user: "if the user intentionally
  adds wires to the selection, that is a different story"). This tie-break (§10.5) is: selection
  wins over follow.

Decoupling alone fixes the **UX complaint** (follow-wires stop appearing selected) and unlocks the
router, but does **not** by itself remove the short — that needs §5 + §6.

## 5. Design B — incremental per-snap-step reroute

Replace "reroute once at END" with "maintain the route every snap step."

Hook: `move_objects(RUBBER)` already fires on cursor motion and computes `deltax/deltay`. Add a
guard "the **selection** moved by ≥ one `cadsnap` since the last reroute" and, when true: translate
`S` (and its terminals) by the step, then run the **incremental router** on the follow set `F` for
that step, then draw. Gated on `fluid_editing` (default off ⇒ the whole incremental path is skipped
⇒ byte-identical release-time behaviour).

Per step, for each **terminal** `t` of `S` (in its new position) and each follow-wire `f ∈ F`
incident at `t`:
1. Anchor = `f`'s fixed far endpoint (outside `S`); moving end = `t`'s new, already-snapped
   position.
2. Apply a **local update** to `f`'s existing route toward `t`: extend/retract the terminal-incident
   leg, add/remove at most one bend, or slide a corner one grid — the smallest edit that keeps the
   route Manhattan and connected.
3. **Check the step invariants** (§6). If the naive local update would violate one (e.g. the leg
   would reach or cross a foreign-net pin/body), apply the beautifier rule instead (stop short,
   drop a junction) — see §6.

Because each step is one grid, the router never faces the "big jump" global problem; it only ever
decides a one-grid nudge, which is cheap and unambiguous. State carried between steps: the current
route topology per follow-wire (so step N+1 refines step N's result, not a fresh solve).

Determinism (P8): the per-step update must be a pure function of (previous route, new terminal pos,
obstacles) — no hash-order dependence.

Commit on release is then a **no-op reroute** (the geometry is already correct); END only runs
final cleanup (`trim_wires`/merge) and clears state.

## 6. Beautifier rules (invariants + aesthetics)

Hard invariants (never violate; from `nice_drag_rerouting` §4):
- **P1 connectivity** — every follow-net keeps exactly its pre-move node membership. No terminal
  (instance pin or selected-wire endpoint) gains/loses a net; every terminal that was wired to its
  anchor stays wired.
- **P2 no-short** — the router may never lay a leg so two **distinct** nets coincide/touch. This
  is the rule the current code breaks at v8.

Aesthetic / clarity rules (the "nice", quality-ordered):
- **Stop-short + visible junction ("solder joint").** When a moving leg would advance to sit
  *exactly on* a foreign object's connection point (e.g. the riser sweeping right until it lands
  on v8.`plus`), **stop it one grid short** and connect via a short explicit segment, leaving a
  **visible** T-junction/solder-dot. Rationale (user): a junction *at* a pin is invisible and
  reads as an ambiguous/accidental connection; an offset junction is clearer and prettier. In the
  R18 case: riser at x=-410, short horizontal to v8.`plus` at -390, junction visible at
  (-410,140) — never continue past -390 toward -330 (which is what shorts v8).
- **No device-body / foreign-pin crossing** (P5): a leg may not pass through an instance bbox
  interior or run across a device between its two pins.
- **Escape-perp, orthogonal, minimal bends/length, stability** (P3/P4/P6/P7) as in
  `nice_drag_rerouting` §4, same conflict order `P1=P2 > P3 > P5 > P4 > P7 > P6`.

Note the stop-short rule *is* a no-short mechanism: it is the local move that keeps a swept leg
from ever reaching the coincidence that would merge two nets.

## 7. Relationship to `nice_drag_rerouting.md`

- **Reuse** its predicate library (`tests/headless/wireedit/predicates.tcl`: `p1..p7`,
  `pin_escape_normal`, `pred_verdict`) and golden harness verbatim — they define "nice."
- **Reuse** `get_pin_escape_normal()` (`move.c`, Phase 2) for the escape leg direction.
- **Supersede** its Phase-4 "detect-and-refuse at move END" plan: with a tool-owned incremental
  router that never lays a shorting leg, there is nothing to refuse. Keep a cheap END-time P2
  assertion as a *backstop/telemetry* (`fluid_check_move_invariants`, already present, log-only).
- The `insert_exit_stubs` slide (Phase 3) becomes one *incremental* operation among several rather
  than a special END pass.

## 8. Phase plan (RED-first, gated on `fluid_editing`, default-off byte-identical)

- **Phase I — decouple ownership (bookkeeping).** Compute the selection's terminals + follow set
  `F`; split `F` out of the user selection into a tool-owned set; stop drawing them selected. Keep
  *current* jog behaviour for now (route unchanged) so the diff is isolated to ownership/visual.
  Test both selection shapes: S={instance} and S={instance + a wire}; after the drag the follow
  wires are not in `sel_array`, a user-explicitly-selected wire still is, and internal wires (both
  ends in S) ride along rigidly.
- **Phase II — incremental hook.** Run the (still-current) reroute per snap step in
  `move_objects(RUBBER)` behind the `cadsnap`-delta guard, instead of only at END. Test: route at
  release is identical to running it stepwise; live preview matches commit.
- **Phase III — obstacle-aware local update + stop-short.** Replace the per-step jog with the
  §5/§6 local update that consults obstacles (device bboxes, foreign-net pins) and applies the
  stop-short + visible-junction rule. Lands **P2** for the R18 case (the acceptance fixture).
- **Phase IV — beautify (escape-perp, min-bend, junction dots).** Fold in P3/P6 and the visible
  solder-joint rendering.
- **Phase V — cleanup + stability + determinism.** P7/P8; reconcile with
  `trim_wires`/`merge_collinear_wires`; re-run the whole golden matrix.

Between phases: golden `wireedit` suite (31 tests) + `test_wire_split` + `test_fluid_editing`
`OVERALL: ok`, and the `tests/from_user` fixture as the headline acceptance.

## 9. Test harness

- Build the `tests/from_user` case into a headless fixture
  (`tests/headless/wireedit/test_wireedit_3?_incremental_reroute.tcl`): load `before.sch`, drive
  the move both **stepwise** (a sequence of one-grid `move_objects` RUBBER updates) and via the
  **release** path, assert **P2** (v8.plus ≠ v8.minus net) and **P1** (net partition preserved)
  after each. RED against HEAD (today ships the short), GREEN after Phase III.
- **General P2 detector needed.** The current label-centric `p2_no_short` / C
  `fluid_check_move_invariants` **miss** this short (no net labels; it's a device short across
  v8). Add a device-pin-merge check: no instance **outside** the selection may have two pins that
  were on distinct nets pre-move end up on one net post-move (v8 is such an instance — its pins
  straddle the reroute). More generally, no two pre-move-distinct nets may merge unless the user's
  own geometry (a selected object landing on a foreign net) caused it. (This is why the bug shipped
  invisibly.)
- Sabotage/teeth per predicate ([[green-but-hollow]]); non-short control (a clean drag that must
  not trigger stop-short).
- Headless discipline: run from repo root via `./src/xschem --nogui --pipe -q --nolog --script`;
  net readback via `xschem resolved_net 0` (the `0`); `run_regression.tcl` env-FAILs are
  environmental ([[xschem-pipe-script-test-gotchas]]).

## 10. Open decisions

1. **Follow-set representation** — new `sel` bit vs a separate tool-private array. A separate
   array keeps user-selection semantics clean but the reroute code currently reads `SELECTED1/2`;
   decide the least-invasive carrier.
2. **Incremental state across steps** — where the per-net current-topology lives across `RUBBER`
   ticks (xctx field vs recomputed from geometry each tick).
3. **Continuous redraw cost** — rerouting every `cadsnap` step on a large schematic; scope the
   work to the follow set + a bounding box; measure.
4. **Stop-short granularity** — always one grid, or "nearest clear grid line"? And when the pin is
   dragged *past* the obstacle, does the junction hop to the far side?
5. **User-selected wire interaction (selection-wins tie-break)** — a wire the user selected *and*
   that also attaches to a terminal: rigid (in `S`) or follow (in `F`)? Proposed: selection wins →
   rigid. (Referenced from §4a.)
6. **Default on?** Keep behind `fluid_editing` until the real-schematic feel is confirmed
   (Phase-6 exit-stub was deferred on feel, not headless green — `nice_drag_rerouting` §10.5).
7. **Both-ends-on-`S` non-selected wire** — a fixed wire whose *both* endpoints are terminals of
   the same selection (spans across `S` externally). Both terminals move by the same delta, so the
   wire should translate rigidly (degenerate reroute) rather than be ripped up. Confirm and special-
   case, or let the general router handle it (anchor == the other moving terminal).
8. **Mid-span-tap terminals** — a non-selected wire tapping the *interior* of a selected wire (not
   an endpoint). Is that a terminal? (Proposed: yes — the tap point rides with the selected wire and
   the tapping wire follows.) Interacts with `wire_through_tap_arm` / wire-segment-splitting.
9. **Terminal discovery cost** — recomputing terminals + `F` only at START (then translating them)
   vs re-deriving each step. START-once is cheaper but must survive topology changes the reroute
   itself makes (a stop-short junction adds a wire); decide when `F` is refreshed.
10. **Diagonal (non-axis-aligned) drags for slide/shove** (issue 0081) — `compute_wire_slide` and
    `fluid_shove_connected_wire` bail on `dxnz == dynz`, so a diagonal drag-toward gets no shove
    (the reversed-stub-through-body re-appears). Obstacle Layers 1–3 already handle diagonal (R18 is
    diagonal). Proposed: decompose the total delta into an X-leg then a Y-leg (each a pure axis move
    the existing machinery handles) — deterministic ⇒ release==stepwise. Cadence has no such limit.

## 11. References

Code: `select.c` (`select_attached_nets`, `wire_through_tap_arm`, `select_wire`), `move.c`
(`move_objects` START/RUBBER/END, `place_moved_wire`, `compute_wire_slide`,
`get_pin_escape_normal`, `insert_exit_stubs`, `fluid_check_move_invariants`,
`unselect_partial_sel_wires`), `callback.c` (cadence modifier-drag ~6045, menu move 'm'/'M'),
`actions.c` (`connect_by_kissing`, `unselect_partial_sel_wires`), `check.c`
(`trim_wires`, `merge_collinear_wires`, `touch`), `netlist.c` (`prepare_netlist_structs`).
Specs: `nice_drag_rerouting.md` (predicates P1..P8, harness), `wire_segment_splitting.md`,
`fluid_editing.md`, `cadence_modifier_drag.md`. Fixtures: `tests/from_user/{before,after,
beautified}.sch`.
