# Using a coding LLM to refactor spaghetti code for UI/UX

How to drive Claude (Opus 4.8) when the codebase is tangled **and** the goal is
specifically to enable UI/UX improvements. This sharpens the general hairball
playbook (`llm_on_a_hairball.md`) for the UI case, where one fact dominates:

> **The LLM cannot see pixels.** It is blind to the rendered window — spacing,
> colour, affordance, "does this feel right." It is excellent at *structure and
> wiring*, useless at *visual judgment*. So you keep the eyes; it does the plumbing.

## Best practices

### 1. Pin the UX objective and success criteria *before* any code
"Poor UX" is not actionable. Name the specific pains (discoverability? shortcuts?
feedback? modality?) and what "better" looks like *for users*. Otherwise the LLM
optimizes a proxy. For an editor, the usual high-value axes are discoverability
(command palette, searchable help) and shortcut ergonomics — decide which matters
most first.

### 2. Run and *observe* the real app first — UX is experiential
You cannot refactor a feel you have not felt. Drive the actual GUI, write down the
friction (clicks to do X, undiscoverable command, confusing modal state). The LLM
can analyze the *code* behind the UI but cannot experience the UI; that half is
yours and it is not optional for UX work.

### 3. Separate the *enabling refactor* from the *UX feature*
First make the structure data-driven (e.g. an action registry); *then* build the
feature (command palette) on top. Two changes, two intents, two reviews. Don't
entangle "reorganize" with "add."

### 4. Keep UI work on the safe seam, prove the engine is untouched
UI/UX usually lives in the scripting/presentation layer (Tcl here), not the C
engine. Refactor there. After every change, run the behavior harness to prove the
engine paths (load, netlist) are byte-identical — so "I only touched the UI" is
demonstrated, not assumed.

### 5. Behavior-preserving first, enhance second
For each UI refactor: first prove the *existing* behavior is unchanged (the menus
still fire the same commands), then add the new capability as an additive layer.
Additive + reversible means you can ship one menu, observe, and continue.

### 6. Get a verification loop for the UI too (it's harder than for logic)
The netlist harness can't test a palette. Use what you can automate — golden
snapshots of generated menu structure / keybinding tables — and an explicit
**human smoke-test checklist** for the interactive parts the LLM can't see.
Decide in advance what "works" means and who checks it.

### 7. Use the LLM for what it's *great* at here
Inventorying scattered UI definitions into data (it parsed 221 menu items into a
table in seconds), writing generators, reusing existing helpers it discovers
(e.g. an in-repo fuzzy matcher), drafting the wiring. Let it do the mechanical
data-ification; that's its strength.

### 8. Don't ask it to design the look
Layout, visual hierarchy, colour, icon choice, "is this intuitive" — it can't
see the result, so it will guess plausibly and confidently. Have it implement
*your* design decisions; don't outsource taste to a blind collaborator.

### 9. Small, reversible, incremental — never big-bang a GUI
Convert one menu, ship, look at it, continue. A monolithic "rewrite the UI" PR is
unreviewable and unverifiable. The table can coexist with hand-written widgets
during migration.

## Common pitfalls (easy to get wrong)

- **Objective drift** — starting broad ("clean this up") and only discovering the
  real goal (UX) after a lot of analysis. Decide the objective first; let analysis
  serve it, not precede it.
- **Analysis as procrastination** — measuring is cheap and satisfying; shipping a
  small verified change teaches more. Analyze *to a decision*, then act.
- **One mega-session** — a single endless conversation bloats context and blurs
  intent. Prefer focused sessions per task; start fresh for a new objective.
- **Not running the app** for UX work — the single most common UX mistake.
- **Committing late / large** — small, frequent, logically-scoped commits are
  cheap checkpoints; big untracked piles are risk.
- **Acting against your own stated constraints** under outward-facing pressure
  (e.g. wanting privacy, then publishing a real email anyway). Slow down on
  irreversible/public actions.
- **Outsourcing judgment** — visual taste, what to publish, "is this good UX" stay
  with the human; the LLM advises and implements.

## The loop (UI/UX flavour)
```
0. Observe the running app; write down concrete UX pains + success criteria
1. Pick ONE pain with the best (user impact ÷ risk)
2. Enabling refactor: data-ify the relevant UI definitions (LLM's strength)
3. Prove behavior-preserving (harness green + UI smoke-test)
4. Add the UX feature as an additive layer
5. Run the app, look at it (human), iterate
6. Commit small; capture the decision
```
