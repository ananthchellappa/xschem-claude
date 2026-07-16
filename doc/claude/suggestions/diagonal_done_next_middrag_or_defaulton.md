# Next step: mid-drag big-delta (thread 1) or the default-on push

Fluid-editing branch. Diagonal decomposition (issue 0081) just landed + pushed; this is the next
roadmap increment. **Confirm the target with me before diving in** — the two live candidates are
below; pick with me first.

## Orient first (read these)
- Memory `nice-drag-rerouting.md` (full status, newest entries at the BOTTOM) + `MEMORY.md` index.
- Spec `doc/claude/specs/incremental_wire_reroute.md` §5 (per-snap-step shape — the total-delta-reapply
  that thread 1 is about), §10 (open decisions). `doc/claude/specs/nice_drag_rerouting.md` §4
  (predicates P1..P8, conflict order `P1=P2 > P3 > P5 > P4 > P7 > P6`).
- Issue `doc/claude/issues/0081-diagonal-drag-shove-slide-via-per-axis-decomposition.md` (just done —
  read its "Implementation" section: the two-leg X-then-Y decomposition + the **P2 partition-change
  safety net**).
- Discipline: `doc/claude/code_analysis/lessons_subagent_git_reset.md`,
  `.../lessons_green_is_not_correct.md`, and the `green-but-hollow` memory.

## Where things are (pushed, github/fluid-editing @ `90522bb7`)
Done + pushed: Phase 0–III (predicate lib + harness), decouple-ownership, incremental per-snap
reroute (Phase II), obstacle-aware Layers 1–3 (R18 no-short — GUI ✓), 2δ ghost fix (0080), connected-
wire SHOVE (0015 — GUI ✓), **P6 min-bend** (`f0bbca13`), and **diagonal decomposition** (`90522bb7`,
issue 0081): a fixed X-then-Y two-leg loop wrapping the shared commit region, follow set re-derived
between legs, gated so default-off/axis-aligned are byte-identical. Its **P2 safety net** rolls back
to the proven one-shot when the two legs change connectivity (`fluid_partition_changed()` — the
complete signal, after a review caught the narrow device-merge trigger missing a net-label merge).
Two review rounds (`wf_99e41f72` found + fixed the label hole, `wf_dab7c6e8` clean). Full wireedit
suite ALL PASS (40) + `--memcheck` clean; `test_wireedit_40_diagonal_shove`. Everything still behind
`fluid_editing` (default off). Also just committed: grid-toggle selection-GC fix (issue 0082,
`708618f8`) — unrelated, done.

## The two live candidates (pick one with me)

### A. MID-DRAG big-delta divergence (thread 1) — the deeper blocker for default-on
During a continuous LMB-held drag A→B→…→F→G, bad wiring can appear at a step, but re-doing that same
F→G as a FRESH click-drag is clean. Root suspicion (see `incremental_wire_reroute.md` §5): Phase II
reroutes each snap step as **restore-pristine + reapply the TOTAL delta from origin A**, so step G
re-solves the whole A→G jump (a big-delta global route) instead of the small F→G increment; a fresh
drag re-baselines pristine to F, so F→G is a small clean delta. **Diagonal decomposition (0081) may
have improved or subsumed this** (free 2D drags are diagonal; a diagonal F→G was a prime suspect) — so
the FIRST move is to re-run the mid-drag repro on `90522bb7` and see if it still diverges.
- **Needs from me:** the concrete repro (which schematic, which A→…→G path, is the bad step diagonal,
  the before/after). I was collecting this. Ask for it before coding.
- Options to weigh once repro is in hand: (a) re-baseline pristine on some cadence (breaks single-undo
  / release==stepwise — needs a decision); (b) make the router itself delta-path-independent so big
  and small deltas converge; (c) accept + document. Do a small design workflow + judge if non-obvious.

### B. DEFAULT-ON push — the endgame
No correctness blocker remains (Layers 1–3 + shove + P6 + diagonal all no-short, all gated, all GUI-
or headless-verified). The gate is FEEL. Broaden real-window eyeballing across representative
schematics (buses, multi-pin devices, dense corners, taps), fix any feel regressions, then flip the
`fluid_editing` default. Feel threads A (mid-drag) and the P4/P7 seam-artifact quality of the diagonal
X-only intermediate gate this — so B likely waits on A.

**Recommendation:** start with A (re-test the mid-drag repro on `90522bb7` first — 0081 may have
fixed it). If it's clean now, A collapses into B. Confirm with me + get the repro before coding.

## Hard constraints (every prior layer held these)
- **Default-off byte-identical** (gate everything on `fluid_editing`; verify fluid=0 unchanged vs the
  baseline binary `scratchpad/xschem.diagbase`, regenerate if stale).
- **Conflict order P1=P2 > P3 > P5 > P4 > P7 > P6**; never trade a higher predicate for a lower.
  Decomposition-class changes are lowest-priority and must yield to P2 (the 0081 safety-net pattern:
  snapshot pristine, try, `fluid_partition_changed()` check, roll back to the proven path if it broke).
- **release==stepwise** for anything per-step (pure fn of pristine snapshot + total delta + obstacles).
- **Commit WIP before spawning any subagent/Workflow that may run git; isolate tree-mutating agents in
  a worktree** (`isolation:'worktree'`) — a review agent's `git reset --hard` wiped uncommitted work
  once. NOTE: worktree agents build from the committed HEAD, so commit first or they test old code.
  There is separate uncommitted sandbox scratch (`xschem_libs_newsym/SANDBOX/*`) — do not sweep it in.
- **Green-but-hollow guard**: sabotage-verify tests; port EXACT repro scenes (autotrim cleans
  simplified scenes and hides the bug). Compare fluid-OFF-vs-ON (or vs `scratchpad/xschem.diagbase`),
  never no-obstacle-vs-obstacle.
- Headless net readback via `xschem resolved_net 0` (the trailing `0`). Tests: true-headless
  `--nogui`, harness `tests/headless/wireedit/` (fixtures.tcl, predicates.tcl, run_wireedit.sh
  [--memcheck]). The GUI-gesture tests need a real window (DISPLAY=:0 / WSLg).
- **The real-window feel test on `src/xschem --script src/cadence_style_rc --logdir /tmp` is the
  acceptance gate, not headless green.**

## Acceptance
- (A) The mid-drag big-delta case no longer diverges from a fresh click-drag at the same total, OR is
  root-caused with a chosen fix and a RED-first test; suite + memcheck stay green; default-off
  byte-identical; my eyeball confirms.
- (B) Fluid feel is clean across representative schematics; the `fluid_editing` default is flipped
  with my sign-off.

## Also on the roadmap (if priorities shift)
- **Narrow topologies**: mid-span-tap terminal (§10.8), far-side wrap (§10.4), bus (F7);
  deferred-within-shove component-toward-parallel-wire + two-abutted-components.
- **Diagonal quality follow-ups** (0081 deferred): re-arm `connect_by_kissing` at the between-leg
  re-grab (mid-span tap on a follow wire currently follows rigidly — P1-safe, less pretty); seam
  P4/P7 artifacts from the X-only intermediate; the per-snap-step `prepare_netlist_structs(0)` cost in
  the fallback (watch lag on large schematics).
