# Next step: Phase IV beautify — visible junction / solder-dot rendering

Fluid-editing branch. The correctness spine is done and GUI-confirmed; this is the next build increment on the roadmap.

## Orient first (read these)
- Memory `nice-drag-rerouting.md` (full status) + `MEMORY.md` index.
- Spec `doc/claude/specs/incremental_wire_reroute.md` §8 (phases) + §10 (open decisions); `doc/claude/specs/nice_drag_rerouting.md` §4 (predicates P1–P8, esp. P6) + the "solder-joint" beautifier rule.
- Issue `doc/claude/issues/0015-...shove...md` (just-landed shove).
- Discipline: `doc/claude/code_analysis/lessons_subagent_git_reset.md`, `.../lessons_green_is_not_correct.md`, `.../green-but-hollow` memory.

## Where things are (pushed, github/fluid-editing @ e190d88b)
Done + GUI-confirmed: Phase 0–III (predicate lib + harness), Phase I decouple-ownership, Phase II incremental per-snap reroute, Phase III obstacle-aware Layers 1–3 (R18 no-short — GUI ✓), 2δ ghost fix (issue 0080), and the F9 connected-wire SHOVE (issue 0015 — GUI ✓). Correctness spine + drag-toward complete; everything gated behind `fluid_editing` (default-off byte-identical).

## The task
Phase IV "beautify": **render visible junction/solder dots** where fluid reroute creates a real electrical connection point — the Layer-2 stop-short solder joint (a leg landing one grid short of a foreign pin), the shove landing, and any T/tap the reroute forms. Today those connections are geometrically correct but visually ambiguous (no dot), which is the biggest remaining "does this feel finished" gap before default-on.

Do it RED-first, spine-of-rigor identical to Layers 1–3:
1. **Recon:** does xschem already draw connection dots anywhere (grep draw.c for junction/dot/solder/bogus; check how a normal 3-way wire junction renders)? Where is the wire/junction draw path? Is there a data model for "this point is a solder node" or must it be derived (degree≥3, or a wire endpoint mid-span on another wire)? Decide: reuse an existing dot primitive vs add one. Keep it a rendering concern — do NOT change netlist/connectivity.
2. **Design** (consider a small design workflow + judge if the approach is non-obvious): where the dot set is computed, when it's drawn, gating.
3. **Implement**, gated on `fluid_editing` (or a dedicated draw toggle) ⇒ default-off byte-identical.
4. **Test**: headless assertion of the dot set for the R18 stop-short + the shove landing (a queryable "junction dots" list, or assert via the draw path); plus a real-window eyeball by the user.
5. **Adversarial review** (worktree-isolated agents — see the git-reset lesson) then commit + push.

## Hard constraints (every prior layer held these)
- **Default-off byte-identical** (gate everything; verify fluid=0 unchanged).
- **No netlist/connectivity change** — dots are pure rendering.
- **release==stepwise** if any per-step state is involved.
- **Commit WIP before spawning any subagent/Workflow that may run git; isolate tree-mutating agents in a worktree** (a review agent's `git reset --hard` wiped ~200 uncommitted lines last time).
- **Green-but-hollow guard**: sabotage-verify tests; port EXACT repro scenes, not simplified ones (trim/autotrim cleans simplified scenes and hides the bug).
- User runs `src/xschem --script src/cadence_style_rc --logdir /tmp`; the real-window feel test is the acceptance gate, not headless green.

## Acceptance
A solder dot renders at the fluid-created junctions (R18 stop-short, shove landing) in a real window; nothing draws in default-off; suite + memcheck green; user eyeball confirms it looks finished.

## If priorities shifted, the alternatives on the roadmap are:
- **P6 min-bend/length in the router** (Phase IV correctness/aesthetics; make the reroute prefer fewer bends then shorter length).
- **Default-on push**: broaden real-window feel across representative schematics, then flip the `fluid_editing` default (small change, broad regression — the endgame; no correctness blocker remains).
- **Narrow topologies**: mid-span-tap terminals (§10.8; shove currently declines on it), far-side wrap (§10.4), bus (F7).
Pick one and confirm with the user before diving in.
