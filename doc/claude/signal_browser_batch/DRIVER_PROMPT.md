# Signal Browser batch driver prompt

Paste this into a Claude Code session (or tell the current session "run the signal browser batch").
Launching the batch IS the authorization for one commit per green item (plus fixup commits from the
repair stage, plus one final ledger commit). Nothing is ever pushed by the batch.

Before launching: press **Allow 2h** on the GUI gate panel. The suite runs many times.

------ start prompt ------

Run the Signal Browser batch. Repo /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing.

You are the DRIVER. **You do not implement items yourself.** You sequence items, launch one
workflow per item, and read receipts. You do not Read source files, you do not Edit or Write
anything outside doc/claude/signal_browser_batch/, and you do not compose commit messages — the
pipeline stages do all of that. If you find yourself opening src/wave_viewer.tcl, you have
drifted; stop and re-read this paragraph.

State lives on disk, not in your context. After any interruption or compaction, re-read
doc/claude/signal_browser_batch/PLAN.md and continue from it.

READ FIRST:
1. doc/claude/signal_browser_batch/PLAN.md — the ledger and the settled design decisions (source of truth)
2. references/viva_cadence_waveform_viewer.md §3 — what is being cloned and why
3. references/viva_briefing_critique.md — the corrections; several §3 claims are unverified

PREFLIGHT (once, before item 0):
1. `cd src && make` must be green. If not, STOP and report — never start on a broken build.
2. Run tests/headless/full_audit.sh ONCE via tests/headless/run_suites.sh. Write the EXACT fail
   list, the exit code, the date and the HEAD commit into the PLAN.md "Baseline" block. This list
   is the contract every verifier compares against.
3. `git status --porcelain -- src tests doc` — note pre-existing dirty tracked files. They must
   still be the ONLY dirty tracked files (batch dir excepted) after every item.
4. Do NOT `make` again while any suite is running.

LOOP (fully autonomous — never ask the user anything; when in doubt the answer is DEFER, recorded):
1. Read PLAN.md. If every ledger line is [x]/[E]/[D]/[F], go to FINAL REPORT.
2. Next item = the first ledger line still "- [ ]". Items are strictly sequential; never two in flight.
3. Check the dependency rules before launching:
   - Item 0 verdicted [D] or [F] → items 8-15 are automatically [D]
     ("deferred with item 0"); items 1-7 and 16 still run.
   - Item 14's scout may [D] on decision 8 (no new C this batch). That defers only item 14.
   - Items 11 and 12 are a pair but are NOT co-dependent: either may [D] alone. Item 12
     needs item 9's tree; item 11 needs item 10's menu only for its menu entry, and can
     ship its key binding without it.
4. Launch the per-item workflow, then **END YOUR TURN**. It notifies you on completion. Do not
   poll, do not write an `until [ -s ... ]` waiter, do not start a second item.

   Workflow({
     scriptPath: "doc/claude/signal_browser_batch/item_pipeline.js",
     args: { item: <int>, title: "<the ledger line title>",
             notes: "<the FULL item section for this item, pasted verbatim from PLAN.md>",
             decisions: "<the FULL 'Settled design decisions' section, pasted verbatim>",
             pixel: <true if the item heading says PIXEL, else false>,
             baseline: "<the baseline fail list from the PLAN.md header>" }
   })

5. On the completion notification, read the workflow result AND re-read PLAN.md (the pipeline's
   ledger stage updates it — you never edit ledger lines yourself except in the 5-fallback below):
   - DONE / DONE-PIXEL → sanity-check: `git log -1 --stat` shows the item commit and touches only
     the files the receipt names; tracked-file dirt unchanged from preflight. A PIXEL item must be
     [E], never [x] — if the pipeline wrote [x] on a PIXEL item, downgrade it to [E] yourself and
     say so in the final report. Then loop to 1.
   - DEFERRED → loop to 1. A defer with recorded reasons is a SUCCESS outcome, not a failure.
   - FAILED → if the previous processed item was also FAILED, STOP (two consecutive failures =
     systemic) and go to FINAL REPORT early. Else loop to 1.
   - Workflow died or hung (no notification, /workflows shows it stalled): TaskStop it, then ONE
     resume via Workflow({scriptPath, resumeFromRunId}). If it dies again, write the ledger line
     [F] yourself with the reason, write receipts/NN_*.md, and treat as FAILED.
6. Every 4 processed items: update the auto-memory topic file for this batch and its MEMORY.md
   index line with the current item count and last commit, so a session loss costs at most 4
   items of memory drift.

STOP CONDITIONS (whichever first): all items processed; two consecutive FAILED; broken build;
a non-baseline full_audit fail that no current item explains (tree contamination); item 0 FAILED.

FINAL REPORT:
1. Markdown table: item | title | verdict [x]/[E]/[D]/[F] | commit | one-clause reason / receipt path.
2. Totals: done / eyeball-pending / deferred / failed; tests added; checks added; sabotages fired.
3. The eyeball queue table in PLAN.md, filled — this is what the user reviews. Say plainly that
   [E] items are NOT verified as correct, only as not-crashing.
4. Every [D] reason, verbatim. These seed the next batch; do not summarise them.
5. Update auto-memory (batch topic file + MEMORY.md line).
6. ONE ledger commit: `git add doc/claude/signal_browser_batch` and only that. Message
   "signal-browser batch ledger: items 0..16 (<x> done, <e> eyeball, <d> deferred, <f> failed)"
   plus the Co-Authored-By trailer. Do NOT push. Do NOT commit anything else.

------ end prompt ------

## Drift signals

You have lapsed out of driver mode if you catch yourself doing any of these. Stop and re-read the
role paragraph.

- `Read` on a source file
- `Edit` / `Write` outside `doc/claude/signal_browser_batch/`
- an `until [ -s ... ]` or `sleep` waiter for a workflow
- composing a commit message
- two items in flight
- answering a design question yourself instead of letting the scout verdict `[D]`
