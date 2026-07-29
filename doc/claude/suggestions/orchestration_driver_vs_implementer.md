# Two orchestration styles, and how to ask for the one you want

*Written 2026-07-29, after the ten-item waveform-viewer plan finished. It compares
how that session actually ran against the **driver** harness in
`doc/claude/refactor_b_batch/` (`RUNBOOK.md`, `DRIVER_PROMPT.md`,
`DESCEND_ROUND_PROMPT.md`), and answers the practical question: **what has to be
in the prompt to get driver behaviour instead of implementer behaviour.***

---

## The two styles

**IMPLEMENTER (what the viewer plan session did).** The main session reads the
source, writes the code, writes the tests, runs the suites, sabotage-verifies,
commits, and raises a review gate for the human between items. Subagents are used
occasionally for recon. All working knowledge lives in the conversation.

**DRIVER (what `refactor_b_batch` does).** The main session sequences items, launches
one `Workflow` per item, and reads a small structured receipt. It never touches
code. Scout / Implement / Verify / Ledger each run as fresh-context agents inside
`atom_pipeline.js`. All state lives on disk (`PLAN.md` ledger + `receipts/NN_*.md`).
No human interaction at all until the final report.

## Side by side

| | DRIVER (refactor_b_batch) | IMPLEMENTER (viewer plan) |
|---|---|---|
| main session's job | sequence + read receipts; **"you do not implement atoms yourself"** | write every line |
| where state lives | **on disk**: ledger + receipts, explicitly resumable after compaction | in the conversation |
| unit of work | one `Workflow({scriptPath: atom_pipeline.js, args})` per item | inline edits; one workflow all session |
| turn shape | launch → **end turn**; notification resumes it; "do not poll" | polled completion with `until [ -s … ]` waiters |
| context growth | flat — driver sees only receipts | linear in work done (457k tokens / 50 % of a 1M window) |
| human in the loop | **none** — "never ask the user anything" | review gate after **every** item |
| when unsure | **DEFER, recorded — a success outcome** | decide, then document the decision |
| commits | atoms self-commit; driver makes **one** ledger commit | 8 commits, all by the main session |
| failure policy | codified: 2 consecutive FAILED = systemic stop; broken build; non-baseline audit fail | ad-hoc judgement |
| baseline | **exact fail list recorded at preflight**, the contract every verifier compares to | none — counts compared to a handoff table |
| verification | fresh adversarial verifier told to trust nothing, re-runs everything itself | self-verified in the same context that wrote the code |

## What actually differed, in measured terms

Three consequences were real, not stylistic.

**1. Context.** The driver harness exists precisely so "20 items don't blow up its
context" (RUNBOOK "Why this shape"). The viewer session burned 457k tokens on
457 messages. The three biggest line items were all self-inflicted by the
implementer model: **85 KB of test-suite source authored inline** (`Write` puts the
whole file in context permanently), ~3,000 lines of source read to write it, and
~97 KB of files echoed back by post-edit hooks.

**2. Compaction survival.** The driver prompt's second sentence is *"State lives on
disk, not in your context — after any interruption or compaction, re-read PLAN.md
and continue from it."* The viewer session had a plan ledger and kept it current,
which is partial cover — but the load-bearing knowledge (which pixel sits on a
trace, *why* the click tolerance had to be zero) existed only in messages.

**3. The missing baseline cost real time.** `full_audit` has ~14 known fails, which
is why the driver preflight records the exact list. The viewer session had no
baseline, so when `test_ase_plot` and later `test_wave_modes` each failed once, it
took a re-run to distinguish flake from regression. Two avoidable round trips.

## But the human gate was right, not an oversight

The driver harness forbids asking the user because its atoms are mechanical pattern
extensions against a written exemption spec. The viewer items were
**design-unsettled**, and the plan's own prescriptions were wrong four times:

- the RMB travel tolerance (copied a Button-1 constant to Button-3, which has a box
  zoom to collide with);
- the item-8 gate was missing a plot-box predicate, so the menu fired over the wave
  labels where RMB already opens a dialog;
- landmine 33's direction for item 7 was inverted;
- item 6's shrink was specified Y-only at 10 %, and **the user rejected it on sight**.

A pipeline would have implemented all four faithfully and ticked the ledger green.
The last one is the clean proof: no test could ever have caught it, and item 6's
pixel effect is still unassertable by construction.

**So the triage rule is about the work, not about taste:**

| the item is… | use |
|---|---|
| mechanical, prescoped, pattern to follow, verifiable by assertion | **DRIVER** |
| design-unsettled, or its deliverable is pixels/feel | **IMPLEMENTER** + review gate |
| unsettled design **with** a mechanical tail (e.g. "write the suite") | **HYBRID** — decide inline, delegate the tail |

The hybrid is the one the viewer session should have used and didn't: once each
item's contract was settled, writing its test suite was mechanical. 85 KB of test
code went into the main context that a builder stage could have written for a
receipt.

---

# How to ask for DRIVER mode

## The honest precondition

**You cannot get driver behaviour from a phrasing alone.** "Be a driver" or
"delegate this" without machinery degenerates into the implementer model within a
few turns, because there is nowhere for state to live and no pipeline to hand work
to. Driver mode needs four things to exist on disk:

1. **A ledger** that is the single source of truth — one checkbox line per item,
   per-item scope notes, and a slot for the verdict. (`PLAN.md`)
2. **A pipeline script** the `Workflow` tool can run by `scriptPath`, with the stages
   spelled out so each gets a fresh context. (`atom_pipeline.js`:
   Scout → gate → Implement → adversarial Verify → Ledger)
3. **Receipt files** the stages write and the driver reads instead of transcripts.
4. **A recorded baseline** of known-failing tests.

If those exist, asking is trivial. If they don't, your prompt has to say which of
the two things to do about it — see "If the machinery does not exist" below.

## If the machinery exists

Paste the driver prompt block. That is the whole interface:

> Run Refactor B round 3 (descend-family pattern extension) …

or just: **"run the refactor B batch"** / **"run the descend round"**. RUNBOOK
§"Starting / resuming" is explicit that resuming is the same act — re-paste the
prompt; it preflights only if the baseline line is still empty.

## If the machinery does not exist

Say so and pick one. Either is fine, but the prompt must choose:

- **(a) Build it first.** *"Phase 0: write a ledger + a per-item pipeline script in
  `doc/claude/<name>/`, modelled on `doc/claude/refactor_b_batch/`. Then paste
  yourself the driver prompt and run it."* Costs one session up front, pays back
  over 10+ items.
- **(b) Inline the contract.** For a short round (≤5 items) skip the script and put
  the nine clauses below straight in the prompt, with `Agent` calls instead of a
  pipeline.

## The nine clauses that actually change behaviour

Ranked by how much is lost if you omit them.

1. **Role negation — the single most important sentence.**
   > "You are the DRIVER: you sequence items and read receipts; **you do not
   > implement items yourself.**"

   Without an explicit *negation*, "orchestrate this" reads as "do this well".

2. **State location.**
   > "State lives on disk, not in your context — after any interruption or
   > compaction, re-read `<ledger path>` and continue from it."

3. **Turn discipline.**
   > "Launch the per-item workflow and then **END YOUR TURN** (it notifies you on
   > completion; do not poll, do not start a second item in parallel)."

   Omit this and the driver sits in `until`-loop waiters, spending context on the
   thing delegation was meant to avoid.

4. **Ledger ownership.**
   > "The pipeline's ledger stage updates `<ledger>`; you never edit ledger lines
   > yourself except `<named fallback>`."

   Two writers to one ledger is how a resumable round stops being resumable.

5. **Autonomy + DEFER-as-success.**
   > "Fully autonomous — never ask the user anything; when in doubt the answer is
   > DEFER, recorded. **A defer with recorded reasons is a SUCCESS outcome.**"

   Without the second half, ambiguity turns into a guess rather than a record.

6. **Preflight and baseline.**
   > "`cd src && make` must be green or STOP. Run the audit once and write the
   > EXACT fail list into the ledger header — that list is the contract every
   > verifier compares against. Note pre-existing dirty tracked files; they must
   > still be the only dirty tracked files after every item."

7. **Stop conditions, enumerated.**
   > "N items processed; two consecutive FAILED (= systemic); broken build; a
   > non-baseline audit fail no current item explains."

8. **Commit authorization and scope.**
   > "Launching the round IS the authorization for one commit per green item (plus
   > fixup commits). Explicit file lists only — never `git add -A`, never
   > `git reset --hard`, **never push.** One final ledger commit touching only
   > `<batch dir>`."

9. **Final report shape.** A table of item | verdict | commit | one-clause reason,
   plus totals — so the round's output is auditable without reading transcripts.

## Two clauses to ADD that the existing prompts do not have

Both are lessons from the viewer session, not from the batch:

10. **Adversarial verify must be a different agent from the implementer.** The
    RUNBOOK already does this; make it explicit in any hand-rolled round, because
    self-verification in the writing context is exactly how green-but-hollow
    survives. The viewer session found **two** hollow legs by sabotage — one where
    a node-index assertion passed against model-index code because the fixture's
    two index spaces coincided.

11. **Name the deliverables that assertions cannot reach.** Add:
    > "If an item's deliverable is pixels, feel or layout, the pipeline may not
    > verdict it `[x]`. Mark it `[E]` (eyeball pending), record what the suite
    > structurally cannot check, and surface it in the final report."

    Otherwise a driver round *will* tick green on something no test can see. The
    viewer plan has three such items and item 6 is the extreme case: deleting the
    line that does the shrinking leaves all 46 of its checks passing.

## Drift diagnostics — how to tell mid-round that driver mode has lapsed

Any of these means the session has quietly become the implementer:

- `Read` on a source file (the driver reads receipts and the ledger, nothing else);
- `Write` or `Edit` on anything outside the batch directory;
- `until [ -s … ]` / `sleep` waiters, or re-reading a task output file more than once;
- a commit whose message the main session composed rather than a stage;
- two items in flight at once.

Say "you are the driver, re-read the ledger" and it should recover, because by
construction the state needed to continue is on disk.

## Copy-paste skeleton for a new round

```
Run <round name>. Repo <path>, branch <branch>.
You are the DRIVER: you sequence items and read receipts; you do not implement
items yourself. State lives on disk, not in your context — after any interruption
or compaction, re-read <ledger> and continue from it.

READ FIRST: <runbook>, <ledger>.

PREFLIGHT (once): build green or STOP; record the EXACT audit fail list into the
ledger header; note pre-existing dirty tracked files.

LOOP (fully autonomous — never ask the user; when in doubt, DEFER, recorded):
1. Read <ledger>. If all items are [x]/[D]/[F]/[E], go to FINAL REPORT.
2. Next item = first "- [ ]" line.
3. Launch Workflow({scriptPath: <pipeline>, args: {...}}) and END YOUR TURN.
   Do not poll. Do not start a second item in parallel.
4. On the notification: read the result AND re-read <ledger>.
   DONE → sanity-check the commit + dirt, loop. DEFERRED → loop.
   FAILED → if the previous item also FAILED, STOP. Else loop.
   Died/hung → TaskStop, ONE resume via resumeFromRunId, else [F].
5. An item whose deliverable is pixels/feel gets [E], never [x].

STOP: <N> items; two consecutive FAILED; broken build; unexplained audit fail.

FINAL REPORT: table (item | verdict | commit | reason), totals, [E] list,
auto-memory update, ONE ledger commit touching only <batch dir>. Never push.
```

---

## One-line takeaway

The batch prompts do not work because they are long — they work because of one
sentence (**"you do not implement items yourself"**), one invariant (**state on
disk**), and one habit (**launch, then end the turn**). Everything else is policy.
Ask for those three explicitly, and say what to do if the pipeline does not exist
yet.
