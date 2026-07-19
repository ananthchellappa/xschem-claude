# Refactor B batch driver prompt

Paste this into a Claude Code session (or tell the current session "run the refactor B batch").
Launching the batch IS the authorization for one commit per green atom (plus fixup commits).
Nothing is ever pushed by the batch.

------ start prompt ------

Run the Refactor B batch. Repo /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.
You are the DRIVER: you sequence items and read receipts; you do not implement atoms yourself.
State lives on disk, not in your context — after any interruption or compaction, re-read
doc/claude/refactor_b_batch/PLAN.md and continue from it.

READ FIRST:
1. doc/claude/refactor_b_batch/RUNBOOK.md  — roles, stage contracts, policies
2. doc/claude/refactor_b_batch/PLAN.md     — the ranked ledger (source of truth)

PREFLIGHT (once, before item 1):
1. `cd src && make` must be green. If not, STOP and report — do not start the batch on a broken build.
2. Run tests/headless/full_audit.sh once; write the EXACT fail list into the PLAN.md header line
   "Baseline fail list at batch start:". This list is the contract every verifier compares against.
3. `git -C . status --porcelain -- src tests doc/claude` — note any pre-existing dirty tracked files;
   they must still be the ONLY dirty tracked files (besides the batch dir) after every item.

LOOP (fully autonomous — never ask the user anything; when in doubt, the answer is DEFER, recorded):
1. Read PLAN.md. processed = count of [x] + [D] + [F]. If processed >= 20, go to FINAL REPORT.
2. Next item = first ledger line still "- [ ]". atom = 26 + (count of [x] lines).
3. Launch the per-item workflow and then END YOUR TURN (it notifies you on completion; do not poll,
   do not start a second item in parallel — items are strictly sequential, they share scheduler.c,
   the grep guard and the build tree):
   Workflow({
     scriptPath: "doc/claude/refactor_b_batch/atom_pipeline.js",
     args: { item: <rank int>, verb: "<verb>", atom: <atom int>,
             notes: "<the full Item detail section for this verb, pasted from PLAN.md>",
             prescoped: <true only if PLAN.md marks the item PRE-SCOPED>,
             decisionDoc: "<existing decision-doc path when prescoped, else ''>" }
   })
4. On the completion notification, read the workflow result AND re-read PLAN.md (the pipeline's
   ledger stage updates it — you never edit ledger lines yourself except in step 5-fallback):
   - DONE     → sanity-check: `git log -1 --stat` shows the atom commit; tracked-file dirt unchanged
                from preflight (batch dir excepted). Then loop to 1.
   - DEFERRED → loop to 1. A defer with recorded reasons is a SUCCESS outcome.
   - FAILED   → if the PREVIOUS processed item was also FAILED, STOP (two consecutive failures =
                systemic problem) and go to FINAL REPORT early. Else loop to 1.
   - Workflow died / hung (no notification and /workflows shows it stalled): TaskStop it, then ONE
     resume via Workflow({scriptPath, resumeFromRunId}). If it dies again, mark the ledger line [F]
     yourself with the reason, write receipts/NN_<verb>.md, and treat as FAILED in step 4.
5. Every 5 processed items: update the auto-memory action-logging.md + its MEMORY.md index line with
   current atom count and last commit (so a session loss costs at most 5 items of memory drift).

STOP CONDITIONS (whichever first): 20 items processed; two consecutive FAILED; build broken;
a non-baseline full_audit fail that no current atom explains (tree contamination).

FINAL REPORT:
1. Markdown table: rank | verb | verdict ([x]/[D]/[F]) | atom # | commit | one-clause reason/receipt.
2. Totals: done / deferred / failed; atoms landed (26..N); tests added; note any pattern-unlock
   proposals the scouts recorded in DEFER reasons (these seed the next planning round).
3. Update auto-memory (action-logging.md + MEMORY.md line).
4. ONE ledger commit: `git add doc/claude/refactor_b_batch` (and only that),
   message "refactor-b batch ledger: items 1..<N> (<x> done, <d> deferred, <f> failed)" +
   Co-Authored-By trailer. Do NOT push. Do NOT commit anything else.

------ end prompt ------
