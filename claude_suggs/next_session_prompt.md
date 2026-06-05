# Opening prompt for the next session

Paste the block below as the first message of a fresh Claude Code session (run it
from this repo directory so the referenced files are on disk). It is deliberately
objective-first and points at the already-committed artifacts so the new session
starts warm instead of re-analyzing the codebase.

---

```
Goal for this session: enable UI/UX improvements in xschem, starting with the
single highest-impact win — a command palette + a data-driven action registry.
This is UI-layer (Tcl) work only; do NOT touch the C engine.

Warm-start context — read these first instead of re-analyzing the codebase:
- CLAUDE.md (architecture, build, the `xschem` Tcl dispatcher)
- claude_suggs/refactor_plan_action_registry.md  (THE plan for this session)
- claude_suggs/using_claude_for_ui_ux_refactoring.md  (how to approach this)
- code_analysis/menu_inventory/menu_items.csv  (the 221 menu items, already inventoried — seed data)
- tests/headless/run.sh  (the behavior harness — must stay green)

Definition of done for this session (Phase 1 from the plan):
1. An action table seeded from menu_items.csv (add `id` + `help` columns).
2. Tcl generators that build the File menu from the table (leave other menus as-is).
3. A working command palette (Ctrl+Shift+P) that fuzzy-searches the table and runs
   the chosen action — reuse the existing fuzzy_subseq_score in xschem.tcl.
4. The C keysym chain (callback.c handle_key_press) stays UNTOUCHED.

Constraints / how I want you to work:
- Behavior-preserving: after each step, run tests/headless/run.sh and confirm gold
  is unchanged (the engine must be untouched). Commit small, in logical steps.
- Before writing code, help me LAUNCH the actual GUI (this is WSL — check $DISPLAY /
  X server) so I can see the current UX first. If it can't run here, tell me what I
  need and we'll proceed with the plan.
- Work on a feature branch. Don't push or do anything outward-facing without asking.

Start by: (a) trying to launch the app so I can observe it, then (b) showing me the
proposed action-table schema and the File-menu generator design before implementing.
```

---

## Why it's shaped this way
- **Objective + "done" in the first lines** — the habit that fixes most of the
  slips noted in `retrospective_new_user_lessons.md`.
- **Warm-start pointers** so the new session reads the committed plans/inventory
  instead of re-running the style/orthogonality analysis (already paid for once).
- **One scoped objective** (Phase 1 PoC), engine explicitly off-limits — keeps it
  on the safe seam.
- **Run-the-app-first** baked in, addressing the biggest gap (optimizing UX
  without ever seeing it).
- **Verification loop + small commits + ask-before-outward** as standing constraints.

## Before starting that session
- `main` is several commits ahead of GitHub `main` (all local) — push or note where
  things stand first if you want a clean baseline.
- Run the new session from this repo directory so the referenced files exist on disk.
