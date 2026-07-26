# Refactor B round 3 driver prompt - descend-family pattern extension

Paste this into a Claude Code session (or tell the current session "run the descend round").
Launching the round IS the authorization for one commit per green atom (plus fixup commits).
Nothing is ever pushed by the round.

------ start prompt ------

Run Refactor B round 3 (descend-family pattern extension). Repo
/home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
You are the DRIVER: you sequence items and read receipts; you do not implement atoms yourself.
State lives on disk, not in your context — after any interruption or compaction, re-read
doc/claude/refactor_b_batch/PLAN.md (section "Round 3 ledger") and continue from it.

READ FIRST:
1. doc/claude/refactor_b_batch/RUNBOOK.md          — roles, stage contracts, policies (unchanged)
2. doc/claude/refactor_b_batch/PLAN.md             — "Round 3 ledger" section + items 31-33 detail
3. doc/claude/refactor_b_batch/receipts/14_descend.md — the EXEMPTION SPEC this round implements

ROUND SCOPE: items 31 (descend, pattern + first consumer), 32 (descend_symbol), 33 (go_back).
Strictly sequential. Items 32/33 are prescoped on item 31's decision doc and AUTO-DEFER if 31
defers. The round's honest open question is item 31's scout verdict: the exemption variant may
reduce to a pass-through not worth landing — DEFER with that ratified in the decision doc is a
SUCCESS outcome that closes the family cleanly.

PREFLIGHT (once, before item 31):
1. `cd src && make` must be green. If not, STOP and report — do not start on a broken build.
2. Run tests/headless/full_audit.sh once; write the EXACT fail list into the PLAN.md Round-3
   header line "Baseline fail list at round-3 start:". This list is the contract every verifier
   compares against (the batch-start list from 2026-07-18 is stale — do not reuse it).
3. `git -C . status --porcelain -- src tests doc/claude` — note pre-existing dirty tracked files;
   they must still be the ONLY dirty tracked files (besides the batch dir) after every item.

LOOP (fully autonomous — never ask the user anything; when in doubt, the answer is DEFER, recorded):
1. Read PLAN.md Round-3 ledger. If all of 31/32/33 are [x]/[D]/[F], go to FINAL REPORT.
2. Next item = first Round-3 line still "- [ ]". atom = 26 + (count of [x] lines in the ENTIRE
   PLAN.md ledger, both sections). If the next item is 32 or 33 and item 31 is [D] or [F]:
   mark it "[D] ... -> DEFERRED: rank-31 automatic defer (pattern not landed)" yourself, write
   receipts/NN_<verb>.md saying so, and loop to 1 (this is the one ledger edit you make yourself,
   besides the step-4 dead-workflow fallback).
3. Launch the per-item workflow and then END YOUR TURN (it notifies you on completion; do not
   poll, do not start a second item in parallel):
   Workflow({
     scriptPath: "doc/claude/refactor_b_batch/atom_pipeline.js",
     args: { item: <31|32|33>, verb: "<descend|descend_symbol|go_back>", atom: <atom int>,
             notes: "<the full Item detail section for this item, pasted from PLAN.md>",
             prescoped: <false for 31; true for 32/33 once 31 is [x]>,
             decisionDoc: "<'' for 31; for 32/33 the decision doc item 31's scout wrote —
                           default path perform_action_atom<31's atom>_descend_decision.md
                           under doc/claude/code_analysis/, confirm from item 31's receipt>" }
   })
4. On the completion notification, read the workflow result AND re-read PLAN.md:
   - DONE     → sanity-check: `git log -1 --stat` shows the atom commit; tracked-file dirt
                unchanged from preflight (batch dir excepted). EXTRA round-3 check for item 31:
                the commit must include the grep-guard rows from the EXEMPTION SPEC (d) — if the
                guard test gained no descend-family rows, treat as FAILED and record why.
                Then loop to 1.
   - DEFERRED → loop to 1 (for item 31 this cascades: step 2 will auto-defer 32/33).
   - FAILED   → if the PREVIOUS processed item was also FAILED, STOP (two consecutive failures =
                systemic problem) and go to FINAL REPORT early. Else loop to 1.
   - Workflow died / hung (no notification and /workflows shows it stalled): TaskStop it, then
     ONE resume via Workflow({scriptPath, resumeFromRunId}). If it dies again, mark the ledger
     line [F] yourself with the reason, write receipts/NN_<verb>.md, and treat as FAILED.
5. After each processed item: update auto-memory action-logging.md + its MEMORY.md index line
   (current atom count + last commit) — the round is short, per-item is cheap.

HARD CONSTRAINTS carried from the receipts (the implement stage must honor these; the verify
stage must check them):
- The variant must NOT change behavior of any already-migrated verb (atoms 1-29 arms) — any
  observable change there is a hard stop.
- descend family stays readonly-EXEMPT (no scheduler_readonly_reject) — a gate breaks
  descend_readonly / hi_descend browse sessions by design, not by accident.
- Core self-logs stay the ONLY log sites (actions.c:3591 descend, save.c:5678 descend_symbol,
  actions.c:3747 go_back — verify anchors, lines drift). Boundary logs nothing for this family.
- In-core modal dialogs (unnamed-schematic save, vector-instance input_line, embedded-symbol
  save, ask_save) are OUT OF SCOPE — replay-nondeterminism there is documented, not fixed here.
- go_back machinery callers (xschem.tcl:3692-3908 walk-ups, window-close 13213, toolbar 12721)
  must behave byte-identically.

STOP CONDITIONS (whichever first): all 3 items processed; two consecutive FAILED; build broken;
a non-baseline full_audit fail that no current atom explains (tree contamination).

FINAL REPORT:
1. Markdown table: item | verb | verdict ([x]/[D]/[F]) | atom # | commit | one-clause reason.
2. Totals + whether the pattern landed; if item 31 deferred, quote the decision doc's ratified
   verdict — that closes the descend family permanently and the next planning round should skip
   self-logging-core verbs (08, 27, 28, 29 stay [D] for their own reasons regardless).
3. If the pattern LANDED: list the same-class verbs whose defers cited only the missing pattern
   as candidates for a round-4 re-scout (from the round-2 ledger: none qualify automatically —
   08/27/28/29 each have additional blockers; say so explicitly rather than implying a queue).
4. Update auto-memory (action-logging.md + MEMORY.md line).
5. ONE ledger commit: `git add doc/claude/refactor_b_batch` (and only that),
   message "refactor-b round-3 ledger: descend-family pattern (items 31-33, <x> done, <d>
   deferred, <f> failed)" + Co-Authored-By trailer. Do NOT push. Do NOT commit anything else.

------ end prompt ------
