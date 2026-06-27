# Tutorial: Taming a hairball codebase with a coding LLM

A worked, reproducible walkthrough of how we went from "never seen this code
before" to a **verified, behavior-preserving refactor** of a 64k-line C/Tcl
program (xschem) — using Claude (Opus 4.8) as the driver. It's written so you can
apply the same method to *your* hairball.

The thesis in one line: **on a tangled codebase you don't ask the LLM to
*understand* the code, you have it *build you instruments* (maps + a safety net),
then make small changes the instruments can prove safe.**

Everything below actually happened in one session; the artifacts it produced live
in `doc/claude/code_analysis/`, `tests/headless/`, and `CLAUDE.md`.

---

## The situation

- **Target:** xschem — schematic-capture EDA tool. ~64k lines of C, a ~12k-line
  Tcl GUI, files up to 7k lines, a single-author codebase grown over 25 years.
- **Goal:** be able to fix bugs and add UI features *without* breaking things.
- **Problem:** no one can hold this in their head, and (as we measured) effects
  aren't local — a change "here" can surface "there."

## The method, in seven phases

Each phase produced a durable artifact and de-risked the next.

### Phase 1 — Orient, and write it down (`CLAUDE.md`)
First move on any unfamiliar codebase: have the LLM read the build files, entry
points, and a few representative sources, then **write an architecture cheat
sheet**. Not for you — for *every future LLM session*, so it starts warm.

What mattered here: identifying the *one* central mechanism (every feature routes
through a single `xschem` Tcl command → a giant `scheduler.c` dispatcher), the
C↔Tcl split, and the landmines (generated parsers you must not hand-edit, the
`MIRRORED IN TCL` variables). Capture conventions, not file listings.

> Lesson: the first deliverable is *orientation*, and it should be reusable.

### Phase 2 — Measure the tangle, don't eyeball it
We asked: *how coupled is this, really?* and answered with `grep`/scripts, not
opinion:
- 14,648 `xctx->` references — almost everything reads/writes one global struct.
- ~1,900 C↔Tcl bridge calls.
- 59% of functions globally visible; one 535-line umbrella header.

Verdict: **horizontally orthogonal** (clean pluggable seams — netlist backends,
renderers) but **vertically coupled** through shared mutable state.

> Lesson: quantify coupling. "Feels messy" can't guide a refactor; numbers can.

### Phase 3 — Turn the hairball into queryable data (a call graph)
No `cflow`/`ctags` available, so we had the LLM *write* a function-level
call-graph extractor (`doc/claude/code_analysis/callgraph/analyze.py`), then layer it by
condensing strongly-connected components (`layered.py`).

Findings that changed our mental model:
- **60% of cross-file calls were leaf-utility noise** (`my_*`, `tcl*`, `dbg`).
  Stripping it revealed the *true* spine: `token.c` (property parsing) — not
  `editprop.c`, which only *looked* central because the allocator lived there.
- The core is one big cycle of *thin* back-edges that peels into a clean DAG
  above ~50 calls — i.e. the dominant flow is actually a tidy hierarchy.

> Lesson: make the model build instruments. A CSV you can sort beats any amount
> of the model "reading" 7k-line files. **But verify the instrument** — our first
> extractor silently missed 76 of `save.c`'s 78 functions until a sanity check
> caught it. LLM-generated analysis is a draft to validate, never gospel.

### Phase 4 — Build a cheap, empirical safety net (`tests/headless/`)
Because effects aren't local, you can't *reason* your way to "this didn't break
anything" — you have to *observe* it. We built a hermetic headless harness:
loads schematics with a pinned in-repo config (no dependence on `~/.xschem`),
netlists them, normalizes machine-specific paths, and diffs against a committed
golden baseline. One command, PASS/FAIL exit code.

We proved it actually catches regressions (injected a fake change → FAIL with a
precise diff → restored → PASS). A test harness that only ever passes is worthless.

> Lesson: buy the feedback loop *before* you change code. Every later edit is then
> verified in seconds, and the model's value compounds instead of accumulating
> unverified risk.

### Phase 5 — Use the data to pick the lowest-risk, highest-leverage move
We drew a **risk map** from the call graph:
- *Safe seams* (additive, isolated): netlist backends, renderers, new commands,
  the Tcl menu layer.
- *Hostile core* (non-local effects): `token.c`, `xctx` semantics, the
  `actions↔draw↔save↔select` editing cycle.

For the stated goal (un-hairball, **no functionality change yet**), the data
pointed at one obvious target: the 60%-of-calls utility cluster was *miscategorized*
inside `editprop.c`. Extracting it is pure structural cleanup with the best
leverage/risk ratio in the codebase.

> Lesson: let the measurements choose the work. The best first refactor is the one
> with the highest (clarity gained ÷ risk taken), and you can compute that.

### Phase 6 — Execute as a *pure move*, let tools prove it safe
We wrote the plan to a doc first (`refactor_plan_util_extraction.md`), then:
1. Green baseline (build + harness).
2. Scripted the extraction (30 functions → `util.c`; 30 prototypes → `util.h`;
   `xschem.h` includes it) — **verbatim, no logic or signature changes**.
3. Built. The **linker is the proof** all symbols resolve with no duplicates.
4. Ran the harness → **byte-identical** gold netlists = behavior preserved,
   *demonstrated* not asserted.

Two **self-inflicted mistakes** — introduced by *our own* refactor, not
pre-existing defects — were caught by the tools before anything was committed.
That's exactly the safety net's job: catching the errors *you* make mid-refactor.
- The **linker** flagged `my_atof`/`my_atod` using `SPC`/`DGT` macros that hadn't
  travelled with them (in the original they sat in the same file, working fine) →
  moved the macros to `util.h`.
- The build wiring almost went into the *generated* `Makefile` (git-ignored,
  overwritten by `./configure`); the real fix was the tracked `Makefile.in`
  template.

We also surfaced **one pre-existing fragility** (not a user-facing bug): in the
original repo `my_strncat` had no prototype in any header — it compiled only
because its definition preceded its callers inside `editprop.c`. Moving it out
would have broken that, so we added the missing prototype to `util.h` and
hardened it. Nothing in *shipped* xschem behavior was ever defective.

Result: `editprop.c` 2137 → 1338 lines, an honest dependency graph, a real
utility floor — zero functional change.

> Lesson: keep behavior-preserving refactors *mechanical*. No "while I'm here"
> improvements. That makes review trivial and lets the compiler + linker +
> harness be your reviewers.

### Phase 7 — Persist the knowledge
Decisions and the *why* don't survive in flat commit messages or git ref
operations (branch renames, remotes, re-authoring leave no narrative). We wrote
a `doc/claude/code_analysis/WORKLOG.md` (journey + decisions + git/publishing log) and a
playbook (`doc/claude/suggestions/llm_on_a_hairball.md`). Cold-start liability → warm-start
asset.

---

## The reusable loop (copy this)

```
1. Orient        -> LLM reads build + entry points, writes an architecture cheat sheet
2. Measure       -> quantify coupling with grep/scripts (don't eyeball)
3. Instrument    -> LLM writes a call-graph / inventory tool; VERIFY it vs ground truth
4. Safety net    -> build a one-command, behavior-diffing test harness; prove it fails
5. Risk-map      -> classify modules into safe seams vs hostile core from the data
6. Pure move     -> smallest behavior-preserving change; compiler+linker+harness prove it
7. Persist       -> write down decisions + the why for the next session
```

## Principles distilled

- **Delegate tooling and verified iteration, not understanding.** The model's job
  on a hairball is cartography and a fast loop — not holding the map in its head.
- **Numbers over vibes.** Coupling, fan-in/out, call counts — measure before you cut.
- **Verify the model's own output.** It produces confident drafts; a
  plausible-but-wrong map is worse than none. Spot-check every instrument.
- **Observation beats reasoning about ripples.** A green harness is worth more
  than any argument that "this is safe."
- **Work the seams; treat the core as hostile.** Additive work behind clean
  interfaces is cheap; mutable-state surgery is not — and you can tell which is
  which from the graph.
- **Pure moves only.** Separate "relocate" from "improve." One commit, one intent.
- **Humans keep judgment.** Intent, risk tolerance, and irreversible/outward-facing
  calls (what to publish, what "done" means) stay with the person.

## Where to look in this repo
- `CLAUDE.md` — the orientation cheat sheet (Phase 1)
- `doc/claude/code_analysis/orthogonality_analysis.txt` — the coupling measurements (Phase 2)
- `doc/claude/code_analysis/callgraph/` — the call-graph + layering tools and outputs (Phase 3)
- `tests/headless/` — the hermetic verification harness (Phase 4)
- `doc/claude/code_analysis/ui_refactor_first_move.txt`, `menu_inventory/` — risk-mapped
  planning (Phase 5)
- `doc/claude/suggestions/refactor_plan_util_extraction.md` + commit "Extract utility layer
  from editprop.c" — the executed pure move (Phase 6)
- `doc/claude/code_analysis/WORKLOG.md`, `doc/claude/suggestions/llm_on_a_hairball.md` — persisted
  knowledge (Phase 7)
