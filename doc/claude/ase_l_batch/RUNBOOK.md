# ASE-L mini-batch — runbook

Executes doc/claude/specs/ase_l.md as 4 sequential items via per-item workflows
(doc/claude/ase_l_batch/ase_pipeline.js). Modeled on
doc/claude/refactor_b_batch/RUNBOOK.md; differences: items are feature slices
(not refactor atoms), no DEFER-friction economics — a scout may only verdict
PROCEED or BLOCKED (spec/anchor contradiction), and BLOCKED stops the batch.

## Roles

- **Driver** (main session): sequences items, reads receipts, never implements.
  State lives on disk (PLAN.md ledger) — after interruption/compaction re-read
  PLAN.md and continue. One item in flight at a time; launch workflow, END TURN,
  process completion notification.
- **Scout** (fresh context): re-verifies every anchor `file:line` from source
  (lines drift), resolves the item's open design micro-decisions, writes the
  full implementation prompt to `prompts/itemN_<slug>.md`. PROCEED or BLOCKED.
- **Implementer** (fresh context): executes the prompt end-to-end: code, tests,
  sabotage-verify, ONE commit with explicit file list.
- **Verifiers** (3 fresh contexts, parallel, adversarial — each tries to
  REFUTE the item):
  - lens `hygiene`: commit scope (no pre-existing dirty tracked files swept in,
    no junk dirs, explicit staging), C89/house-style, discipline adherence.
  - lens `tests`: re-run the item's tests + full_audit.sh; re-execute ONE
    sabotage claim from scratch; green-but-hollow hunting.
  - lens `spec`: deliverables vs doc/claude/specs/ase_l.md + the item prompt;
    missing behaviors, silent scope cuts.
- **Fixer** (fresh context, max 2 rounds): repairs verified problems via
  fixup commit(s); then all 3 lenses re-run.
- **Ledger** (fresh context): flips the PLAN.md ledger line, writes
  `receipts/NN_<slug>.md` (what landed, commit, checks, sabotage, problems
  history). Commits nothing — driver makes ONE ledger commit at final report.

## Policies (non-negotiable)

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.

## Stop conditions

Whichever first: all 4 items [x]/[F]; any BLOCKED scout; two consecutive
FAILED; build broken; non-baseline full_audit failure no current item explains.

## Final report

Table item|verdict|commit|reason, totals, auto-memory update (ase-l-plan.md +
MEMORY.md line), ONE ledger commit staging only doc/claude/ase_l_batch.
