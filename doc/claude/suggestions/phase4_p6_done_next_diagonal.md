# Next step: diagonal drag decomposition (issue 0081) — and the mid-drag big-delta lead

Fluid-editing branch. P6 min-bend just landed + pushed; this is the next roadmap increment.

## Orient first (read these)
- Memory `nice-drag-rerouting.md` (full status, newest entries at the bottom) + `MEMORY.md` index.
- Spec `doc/claude/specs/incremental_wire_reroute.md` §5 (per-snap-step shape), §8 (phases), §10.10
  (diagonal decomposition open decision). `doc/claude/specs/nice_drag_rerouting.md` §4 (predicates
  P1..P8, conflict order P1=P2 > P3 > P5 > P4 > P7 > P6).
- Issue `doc/claude/issues/0081-diagonal-drag-shove-slide-via-per-axis-decomposition.md`.
- Issue `doc/claude/issues/0015-...shove...md` (shove layer).
- Discipline: `doc/claude/code_analysis/lessons_subagent_git_reset.md`,
  `.../lessons_green_is_not_correct.md`, and the `green-but-hollow` memory.

## Where things are (pushed, github/fluid-editing @ `f0bbca13`)
Done + pushed: Phase 0–III (predicate lib + harness), decouple-ownership, incremental per-snap
reroute (Phase II), obstacle-aware Layers 1–3 (R18 no-short — GUI ✓), 2δ ghost fix (0080), connected-
wire SHOVE (0015 — GUI ✓), and **P6 min-bend** (along-normal escape orientation: −1 bend at identical
length; 3 review bugs fixed = P5 body-cross guard / exact pin match / pin-corridor length veto;
design+review+re-review workflows; full wireedit suite ALL PASS (39) + `--memcheck` clean; default-off
byte-identical). Everything gated behind `fluid_editing` (default-off byte-identical). Junction/solder
dots = NON-task: `update_conn_cues()` (check.c) already renders them, default-on, live + committed.

## Two open GUI-feel threads (user's 2026-07-07 eyeball)
1. **MID-DRAG big-delta divergence (user collecting more data — pick up when it arrives).** During a
   continuous LMB-held drag through positions A→B→…→F→G, bad wiring can appear at a step (e.g. F→G),
   but re-doing that same F→G as a FRESH click-drag is clean. Mechanism suspicion: Phase-II reroutes
   each RUBBER step as **restore-pristine + reapply TOTAL delta from the origin A**, so step G solves
   the whole A→G jump (a big-delta global route), while release-at-F re-baselines pristine to F so F→G
   is a small clean delta. The spec §5 premise ("small local delta per step = tractable") is NOT
   actually realized by the total-delta-reapply shape — each step re-solves the full delta. Options to
   weigh with the user: (a) re-baseline pristine on some cadence (breaks single-undo / release==stepwise
   guarantees — needs a decision), (b) make the router itself delta-path-independent so big and small
   deltas converge, (c) accept + document. Get the user's repro (which step, is it diagonal?).
2. **Diagonal drags (issue 0081) — the recommended concrete increment, likely OVERLAPS thread 1.** Free
   2D drags are usually diagonal. `compute_wire_slide` and `fluid_shove_connected_wire` both bail on
   `dxnz == dynz` (axis-only), so a diagonal drag-toward gets NO aesthetic slide/shove (the reversed-
   stub-through-body / staircase reappears) even though obstacle Layers 1–3 already handle diagonal
   (R18 IS diagonal). Spec §10.10 proposal: decompose the total delta into an X-leg then a Y-leg (each a
   pure axis move the existing machinery handles); deterministic ⇒ release==stepwise; Cadence has no
   such limit. This is well-scoped, high-feel-value, and a diagonal F→G step is a prime suspect for
   thread 1's bad wiring — so doing 0081 may directly improve the mid-drag feel.

## The task (recommended: issue 0081 diagonal decomposition)
RED-first, spine-of-rigor identical to the Layers/shove/P6 work:
1. **Recon:** confirm the `dxnz==dynz` bail sites (`compute_wire_slide` move.c; `fluid_shove_connected_wire`
   move.c:~2417). Reproduce headless: a diagonal drag-toward that Layers-1–3 keep no-short but whose
   slide/shove decline → reversed-stub / staircase. Decide the decomposition point (per spec §10.10:
   apply X-delta then Y-delta through the existing per-axis machinery, in the shared commit block so
   release==stepwise holds by construction).
2. **Design** (small design workflow + judge if non-obvious): where to split the delta, ordering
   (X-then-Y vs Y-then-X — deterministic tie-break), how it composes with Layers 1–3 + shove + P6.
3. **Implement**, gated on `fluid_editing` ⇒ default-off byte-identical.
4. **Test:** headless RED-first fixture (diagonal drag: slide/shove now fires per-axis; P1/P2/P3/P4/P5
   hold; release==stepwise) + sabotage-verify + port the EXACT repro scene. Real-window eyeball = gate.
5. **Adversarial review** (worktree-isolated agents — commit WIP first) then commit + push.

## Hard constraints (every prior layer held these)
- **Default-off byte-identical** (gate everything; verify fluid=0 unchanged).
- **Conflict order P1=P2 > P3 > P5 > P4 > P7 > P6**; never trade a higher predicate for a lower one.
- **release==stepwise** if any per-step state is involved (pure fn of pristine snapshot + total delta
  + obstacles).
- **Commit WIP before spawning any subagent/Workflow that may run git; isolate tree-mutating agents in
  a worktree** (a review agent's `git reset --hard` wiped uncommitted work once; work committed = safe).
- **Green-but-hollow guard**: sabotage-verify tests; port EXACT repro scenes, not simplified ones
  (autotrim cleans simplified scenes and hides the bug). Compare fluid-OFF-vs-ON, never
  no-obstacle-vs-obstacle.
- User runs `src/xschem --script src/cadence_style_rc --logdir /tmp`; the real-window feel test is the
  acceptance gate, not headless green. Headless net readback via `xschem resolved_net 0` (the `0`).
- Baseline binaries live in `scratchpad/` (xschem.head pre-P6, xschem.p6 bias-no-guards for RED proofs,
  xschem.p6fix) — regenerate if stale (`make`, then `XSCHEM_SHAREDIR=$PWD/src ./scratchpad/<bin>`).

## Acceptance
The diagonal drag-toward slides/shoves nicely (no reversed stub / staircase) in a real window;
P1/P2/P3/P4/P5 hold; release==stepwise; nothing draws in default-off; suite + memcheck green; user
eyeball confirms the feel improved (and ideally the mid-drag F→G case is better).

## If priorities shifted, the alternatives on the roadmap are:
- **Mid-drag big-delta divergence** (thread 1 above) once the user supplies repro data — this is the
  deeper blocker for default-on and may subsume 0081.
- **Default-on push**: broaden real-window feel across representative schematics, then flip the
  `fluid_editing` default (the endgame; no correctness blocker remains, but feel threads 1–2 gate it).
- **Narrow topologies**: mid-span-tap terminal (§10.8, shove declines today), far-side wrap (§10.4),
  bus (F7); deferred-within-shove component-toward-parallel-wire + two-abutted-components.
Pick one and confirm with the user before diving in.
