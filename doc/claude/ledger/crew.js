export const meta = {
  name: 'annot-crew',
  description: 'One backlog item end to end: scout, measure, plan, RED, implement, verify x3, write up, commit, ledger row',
  phases: [
    { title: 'Scout',     detail: 'locate code, tests, current behaviour' },
    { title: 'Measure',   detail: 'reproduce headlessly, record BEFORE transcript' },
    { title: 'Plan',      detail: 'fix shape, test rows, sabotage variants, open questions' },
    { title: 'RED',       detail: 'write the checks first and prove them red' },
    { title: 'Implement', detail: 'the ONLY agent allowed to run make' },
    { title: 'Verify',    detail: 'tier diff, structure, adversarial refute' },
    { title: 'Sabotage',  detail: 'SERIAL and build-permitted: prove every guard is seen by a row' },
    { title: 'Writeup',   detail: 'issue + docs + commit' },
    { title: 'Ledger',    detail: 'append the row' },
  ],
}

const ID = args.id
const BRIEF = args.brief
const LEDGER = 'doc/claude/ledger/sim_registry_run_2026-08-29.md'
const REPO = '/home/analog/dev/xschem-claude'

const HOUSE = `
=== HOUSE RULES (repo ${REPO}, branch \`annotate\`) ===

Read ${REPO}/CLAUDE.md first if you have not. It is authoritative and it OVERRIDES
your defaults. The points that bite hardest:

BUILD / OOM
* This is a ~7.8 GB WSL box. Running \`make\` while other agents are live is the
  recorded OOM path. **Only TWO agents in this crew may ever run \`make\`: the
  Implement agent, and the Sabotage agent — and the Sabotage agent runs alone,
  after everyone else has finished.** If you are neither of those, run the binary
  already built at \`${REPO}/src/xschem\` and do not rebuild, ever, for any reason.
  If your own prompt does not explicitly grant you \`make\`, you do not have it.

RUNNING TESTS
* Headless is the default and the preferred arm:
  \`cd ${REPO} && ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl\`
* A suite that needs Tk/X self-SKIPs under --nogui. Run those on the persistent
  dev display, NEVER on a bare \$DISPLAY:
  \`cd ${REPO} && tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/<t>.tcl\`
  \`\$DISPLAY\` here is the user's REAL screen (a Windows X server over TCP), not the
  harness's \`:0\` (which is Xwayland). Never flood it.
* Do NOT set GUI_GATE=0 globally and do NOT touch ~/.claude/gui_test_gate/control.
  The gate is already pre-granted; Pause/Stop must keep working for the user.
* A suite passes only on exit 0 AND a whole-line completion banner
  (\`OVERALL: ok\`, or \`RESULT: ALL PASS (N checks)\`) AND no column-0 death marker.
  The exit code alone is not enough: --nogui --pipe exits 0 on an uncaught Tcl error.
* \`tests/run_regression.tcl\` (T1) baseline is **ZERO** counted failures. If you
  see a red there, name the case and the reason; never carry a count forward.

WRITING A NEW SUITE
* A new headless suite MUST be \`tests/headless/test_*.tcl\`. Nothing in the repo
  automatically runs a \`test_*.sh\`.
* Register it in TWO places (\`grep -c\` each, expect 1):
  \`tests/headless/full_audit.sh\`'s \`nogui_tests\` string, and \`tests/run_regression.tcl\`'s
  \`hcases\`. \`hcases\` needs the DUAL banner: emit both \`RESULT: ALL PASS (N checks)\`
  and \`OVERALL: ok\`.
* If the subject can CRASH the interpreter, run the crash-provoking sequence in a
  spawned child (\`exec timeout N [info nameofexecutable] --nogui --pipe -q --nolog
  --script <f>\`) and assert on the child's exit plus a printed sentinel. Copy the
  machinery from \`tests/headless/test_raw_read_failure_0306.tcl\`. xschem installs its
  own SIGSEGV handler, so **a crash exits 1, not 139** — never assert 139.
* Braces inside Tcl COMMENTS still count for brace matching. A \`}\` in a comment
  inside a braced body is a syntax error. Write comments with no brace characters.

SABOTAGE (a sabotage run LIES if done sloppily)
* Back up EVERY file the patch touches. Restore with an mtime bump:
  \`cp backup src/file.c && touch src/file.c\` — **never \`cp -p\`**. A preserved mtime
  makes \`make\` a no-op and every later number is measured against the PREVIOUS
  sabotage's binary.
* A \`/* SABOTAGE */\` comment PREFIXED to a line does not disable the call on it.
  Neutralize by renaming the callee to a no-op, or by deleting the guard body.
* Afterwards assert \`grep -rn SABOTAGE ${REPO}/src/\` is empty AND re-assert the
  restored baseline is green, BEFORE publishing any number.
* Report every PREDICTED red that did NOT appear. A guard no behavioural row can
  see needs a STRUCTURAL row (grep the function body; strip C comments first with
  \`regsub -all {/\\*.*?\\*/}\` or the comment text itself matches).

C CONVENTIONS
* C89 throughout. Declarations at the top of a block. No \`//\` comments.
* Allocation wrappers take the literal placeholder macro \`_ALLOC_ID_\` as their
  first argument. Write \`_ALLOC_ID_\`; never hand-number it.
* Almost all state hangs off the single global \`Xschem_ctx *xctx\`.
* New user-facing operations are a branch in \`scheduler()\` in \`src/scheduler.c\`,
  driven from Tcl, not a new C entry point.
* Config variables mirrored between C and Tcl are marked \`MIRRORED IN TCL\` in
  \`src/xschem.h\` — change both sides.
* Editing \`src/Makefile.in\` obliges a \`./configure\` re-run. \`src/Makefile\` has no
  self-regeneration rule.

GIT
* **NEVER \`git push\`. NEVER open a PR. NEVER \`git checkout\` / \`switch\` /
  \`reset --hard\`.** Commit on \`annotate\` and stop.
* \`git add\` the EXACT paths you touched. Never \`git add -A\` — the tree has a lot of
  untracked scatter that must stay untracked.
* Commit trailer: \`Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\`

ISSUE NUMBERS
* Next free on this branch is whatever \`doc/claude/issues/NUMBERING.md\` says at
  the moment you file. READ IT; do not trust any number written here or in a
  brief - crews file eight at a time and this line goes stale within hours.
* \`0500-0599\`, \`0700-0799\` and \`1000-1199\` are RESERVED for other
  branches. Never use them: after 0499 file 0600, after 0699 file 0800, after
  0999 file 1200.
* Claim a number by creating \`doc/claude/issues/NNNN-<slug>.md\` as a stub
  IMMEDIATELY, before doing the work, so a later crew cannot collide.

DEBT LEDGER
* \`tests/headless/owed.sh add look <what> [why]\` the MOMENT a pixel deliverable is
  incurred. Never report a pixel deliverable "done" because a suite went green.
* \`tests/headless/owed.sh add rule <issue-id> [why]\` for any user-visible decision
  you made that the user has not ratified.

REPORTING STYLE (the user has corrected this twice)
* Speak in terms of what the USER SEES AND INTERACTS WITH — windows, menus,
  checkbuttons, the vertical cursor line on a waveform. Not internal command names,
  not variable names, when a UI noun exists.
=== END HOUSE RULES ===
`

const RULINGS = `
=== STANDING RULINGS THAT BIND THIS WORK ===
* **D5-1** — never put a fabricated number on a schematic. A number that was not
  measured for the thing it is displayed next to is the defect.
* **D5-3** — a digital database publishes nothing.
* **D5-4** — a user-facing sentence is minted in ONE place and rendered by callers.
* **D4** — one cursor, every database.
* **D4-3 / D4-4** — VCD holds its value; a boundary holds, it never extrapolates.
* **0856 (user, verbatim)** — *"if OP is part of the run, then plot from OP. We
  haven't yet built anything for annotating from TRAN results, so it should do
  nothing silently. Why complicate things?"*
* **0857 (user, verbatim)** — *"6 - if OP has been run but we don't have device
  info, and user is wanting to annotate by pressing 6, then, yes, we want to say
  something in the CIW."*
* **The feature request (user, verbatim)** — *"MUST ONLY HAPPEN WHEN USER
  REQUESTS IT!! Alt-6 and 6 are for OP info and OP node voltages. We can add a
  menu item in Results > Annotate for annotating TRAN node voltages for time-point
  given by cursor B, or A - whatever the convention is - if there is only one
  cursor in the waveform viewer's active tab, use that. If A and B are there, then
  use cursor-A. Give user a way to enter this mode with a different shortcut
  through cadence_style_rc - maybe Alt-Shift-6"*
* **INTENT OVER MECHANISM (user, verbatim 2026-08-27)** — *"Given that results
  are being loaded and plotted, we have enough info to satisfy user intent. The
  ultimate goal of any UI is to satisfy user intent."* A refusal that is locally
  correct at every joint and collectively absurd is a defect. If the data the user
  is asking about is already on their screen, the answer is never "not loaded".
* **0881 (user, verbatim 2026-08-27)** — *"The info should already be available -
  it's been loaded to display waveforms in the waveform viewer."* The transient
  annotation MUST use the database the viewer already attached.
* **PLAIN ENGLISH (user, verbatim 2026-08-27)** — *"wording too cryptic. Give it in
  plain english with context, 9th grade level."* Every user-facing sentence in the
  annotation surface. No internal vocabulary, no bare state names, say what
  happened AND what the user can do about it.
* **0857 (user, verbatim 2026-08-27)** — *"Yes, 6 does nothing when there is ONLY a
  TRAN result. But, it's a good idea to say 'No OP results available' in the CIW."*
=== END RULINGS ===
`

const TIERS = [
  'test_ase_core', 'test_ase_final', 'test_ase_final_gf180', 'test_ase_view',
  'test_ase_persist', 'test_ase_cosim', 'test_ase_plot', 'test_ase_launch',
  'test_annot_blank_cause_0909', 'test_op_annot',
]

const TIERTEXT = `
=== TIER LIST — these must be green when you are done ===
Headless (\`./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl\`),
baseline check counts measured 2026-08-29 AFTER commit 0e6cb3cb:
  test_ase_core 182 | test_ase_final 80 | test_ase_final_gf180 34
  test_ase_view 36 | test_ase_persist 109 | test_ase_cosim 341
  test_ase_plot 150 | test_annot_blank_cause_0909 27
Tk-only (\`tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script ...\`):
  test_ase_window 228 | test_ase_dialogs 174 | test_wave_viewer 404
Full: \`cd ${REPO}/tests && tclsh run_regression.tcl\` — baseline **ZERO** counted
failures, 46 blocks, 0 launch failures. Measured today at 0e6cb3cb.

NOTHING IS KNOWN-RED. If a tier is not at its number above, that is YOURS: say
which case and why, per case. A standing red is a defect, not furniture.

`

const SCHEMA_SCOUT = {
  type: 'object',
  additionalProperties: false,
  required: ['anchors', 'existing_tests', 'current_behaviour', 'repro_command'],
  properties: {
    anchors: { type: 'array', items: { type: 'string' }, description: 'file:line anchors, one per line, with a few words of what is there' },
    existing_tests: { type: 'array', items: { type: 'string' }, description: 'suite file plus the row ids that already cover this area' },
    current_behaviour: { type: 'string', description: 'what the code does today, precisely, no proposed fix' },
    repro_command: { type: 'string', description: 'a single shell command that exercises the area headlessly' },
    notes: { type: 'string' },
  },
}

const SCHEMA_MEASURE = {
  type: 'object',
  additionalProperties: false,
  required: ['reproduced', 'transcript', 'summary'],
  properties: {
    reproduced: { type: 'boolean' },
    transcript: { type: 'array', items: { type: 'string' }, description: 'literal output lines, the BEFORE state, quoted exactly' },
    summary: { type: 'string' },
    rescope: { type: 'string', description: 'if the defect is not what the issue says, what it actually is' },
  },
}

const SCHEMA_PLAN = {
  type: 'object',
  additionalProperties: false,
  required: ['fix', 'files', 'test_rows', 'sabotage', 'questions'],
  properties: {
    fix: { type: 'string', description: 'the change, concretely, function by function' },
    files: { type: 'array', items: { type: 'string' } },
    test_rows: { type: 'array', items: { type: 'string' }, description: 'row id + what it asserts + which suite it goes in' },
    sabotage: { type: 'array', items: { type: 'string' }, description: 'each variant: what is neutralized and which rows must red' },
    questions: { type: 'array', items: { type: 'string' }, description: 'decisions the docs do not settle; empty if none' },
    user_visible: { type: 'boolean', description: 'true if this changes what the user sees and no prior ruling covers it' },
  },
}

const SCHEMA_RED = {
  type: 'object',
  additionalProperties: false,
  required: ['rows_written', 'red_confirmed', 'evidence'],
  properties: {
    rows_written: { type: 'array', items: { type: 'string' } },
    red_confirmed: { type: 'boolean' },
    evidence: { type: 'array', items: { type: 'string' }, description: 'the literal FAIL lines' },
    notes: { type: 'string' },
  },
}

const SCHEMA_IMPL = {
  type: 'object',
  additionalProperties: false,
  required: ['built', 'green', 'files_changed', 'evidence'],
  properties: {
    built: { type: 'boolean' },
    green: { type: 'boolean' },
    files_changed: { type: 'array', items: { type: 'string' } },
    evidence: { type: 'array', items: { type: 'string' } },
    blocker: { type: 'string' },
  },
}

const SCHEMA_VERIFY = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'findings'],
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'FAIL', 'PARTIAL'] },
    findings: { type: 'array', items: { type: 'string' } },
    counts: { type: 'array', items: { type: 'string' }, description: 'suite name and check count, one per line' },
    unexpected: { type: 'array', items: { type: 'string' }, description: 'predicted reds that did not appear, or reds nobody predicted' },
  },
}

const SCHEMA_WRITEUP = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'commit', 'suites', 'new_issues', 'result', 'evidence'],
  properties: {
    status: { type: 'string', enum: ['x', 'F', 'D', 'E'] },
    commit: { type: 'string', description: 'sha, or the word none' },
    suites: { type: 'string', description: 'suite names with check counts, one line' },
    new_issues: { type: 'string', description: 'issue numbers filed, comma separated, or the word none' },
    result: { type: 'string', description: 'ONE line. If status is E, this is the exact question for the user.' },
    evidence: { type: 'array', items: { type: 'string' }, description: 'at most 3 lines' },
    blocker: { type: 'string' },
  },
}

// ---------------------------------------------------------------- Guard
// A workflow agent() returns null when its subagent dies on a terminal API
// error after retries -- an exhausted quota is the common way. This script is a
// straight line of awaits, so an unguarded null walks all the way to the LEDGER
// agent and buys a plausible-looking row over work that never ran. That is the
// exact failure class this branch keeps shipping. Die at the seam instead.
function must(label, value) {
  if (value === null || value === undefined) {
    log(`STOPPED: the ${label} agent returned nothing (terminal API error, or skipped). No ledger row will be written; the tree is left as it stands and nothing is committed.`)
    throw new Error(`${label} agent returned null -- crew halted before it could report work that did not happen`)
  }
  return value
}

// ---------------------------------------------------------------- Scout

phase('Scout')
const scout = must('SCOUT', await agent(
  `${HOUSE}${RULINGS}${TIERTEXT}
You are the SCOUT for backlog item **${ID}**.

ITEM BRIEF (verbatim):
${BRIEF}

Your job is READ-ONLY reconnaissance. Locate the code, the tests that already
touch it, and the exact current behaviour. Do NOT propose a fix. Do NOT edit
anything. Do NOT run \`make\`.

Read the issue file if the brief names one (\`doc/claude/issues/NNNN-*.md\`) — the
issues on this branch carry measured evidence and pre-written acceptance criteria,
and re-deriving them is waste.

Return file:line anchors precise enough that the next agent does not have to
search again, and one shell command that exercises the area headlessly.`,
  { label: `scout:${ID}`, phase: 'Scout', schema: SCHEMA_SCOUT }
))

// ---------------------------------------------------------------- Measure

phase('Measure')
const measure = must('MEASURE', await agent(
  `${HOUSE}${RULINGS}${TIERTEXT}
You are the MEASURE agent for backlog item **${ID}**.

ITEM BRIEF (verbatim):
${BRIEF}

The scout found:
${JSON.stringify(scout, null, 1)}

Reproduce the defect HEADLESSLY and record the BEFORE state as LITERAL transcript
lines — the actual bytes the program printed, not your paraphrase of them. This
phase is not optional and its output is what the issue write-up will quote.

Do NOT run \`make\`. Do NOT fix anything. Use the binary already built at
\`${REPO}/src/xschem\`.

Write any scratch fixtures under \`/tmp/\`, never into the repo.

If the defect does NOT reproduce, say so with the measurement as evidence and set
reproduced=false — that is a legitimate and valuable outcome, and the item will
end F with your measurement attached to the issue.

If the defect reproduces but is not what the issue says it is, fill \`rescope\`.`,
  { label: `measure:${ID}`, phase: 'Measure', schema: SCHEMA_MEASURE }
))

// ---------------------------------------------------------------- Plan

phase('Plan')
const plan = must('PLAN', await agent(
  `${HOUSE}${RULINGS}${TIERTEXT}
You are the PLANNER for backlog item **${ID}**.

ITEM BRIEF (verbatim):
${BRIEF}

Scout:
${JSON.stringify(scout, null, 1)}

Measurement (the BEFORE state, literal):
${JSON.stringify(measure, null, 1)}

Decide the fix, the test rows, and the sabotage variants. Do NOT implement.
Do NOT run \`make\`.

Rules for the plan:
* Smallest blast radius that actually fixes the measured thing. Do not widen scope.
* Every guard you add needs a row that can SEE it. If a guard is invisible to every
  behavioural row (because a second guard already covers the case), it needs a
  STRUCTURAL row that greps the function body — that is not optional, it is the
  lesson of this branch.
* Name the sabotage variants UP FRONT, one per guard, each with the rows it must
  redden. A guard whose sabotage reddens nothing is a guard with no test.
* If a decision is not settled by the standing rulings above or by
  \`doc/claude/\` docs: apply the least-surprising-to-a-user-mid-gesture option with
  the smallest blast radius, implement it, and record BOTH the decision and the
  rejected alternative in the issue. Put the question in \`questions\` and set
  \`user_visible\` if the user has not ratified it.
* NO human is watching this run. Never plan a step that waits for a human.`,
  { label: `plan:${ID}`, phase: 'Plan', schema: SCHEMA_PLAN }
))

// ---------------------------------------------------------------- RED

phase('RED')
const red = must('RED', await agent(
  `${HOUSE}${RULINGS}${TIERTEXT}
You are the RED agent for backlog item **${ID}**. You write the checks FIRST and
prove they are red for the measured reason.

ITEM BRIEF (verbatim):
${BRIEF}

Measurement:
${JSON.stringify(measure, null, 1)}

Plan:
${JSON.stringify(plan, null, 1)}

Write the test rows the plan names. Run them. Confirm they fail, and that they fail
for the reason the measurement recorded — not for a typo, not for a missing fixture,
not because the suite did not launch. Quote the literal FAIL lines as evidence.

You may edit TEST files. You may NOT edit \`src/*.c\`, \`src/*.h\` or \`src/*.tcl\`.
You may NOT run \`make\`.

SPECIAL CASE — the fix may ALREADY BE PRESENT in the working tree (item A0 is
exactly this: the \`update_op()\` gate in \`src/save.c\` is already applied and
uncommitted). If your new rows come up GREEN immediately because the fix is already
there, that is NOT a red proof. Do this instead:
  1. Back up every source file the fix touches to /tmp.
  2. Neutralize the fix (rename the callee to a no-op, or delete the guard body —
     a \`/* SABOTAGE */\` comment prefix does NOT disable anything).
  3. You are permitted ONE \`make\` for this and only this purpose. State that you
     used it.
  4. Run the rows, confirm red, quote the lines.
  5. Restore with \`cp backup src/file.c && touch src/file.c\` (NEVER \`cp -p\`),
     rebuild, confirm green again, and assert \`grep -rn SABOTAGE ${REPO}/src/\`
     is empty.
Set red_confirmed=true only if you actually saw the rows red.`,
  { label: `red:${ID}`, phase: 'RED', schema: SCHEMA_RED }
))

// ---------------------------------------------------------------- Implement

phase('Implement')
const impl = must('IMPLEMENT', await agent(
  `${HOUSE}${RULINGS}${TIERTEXT}
You are the IMPLEMENT agent for backlog item **${ID}**. **You are the ONLY agent in
this crew permitted to run \`make\`.** Nobody else will build; the agents after you
run the binary you leave behind, so leave it built and correct.

ITEM BRIEF (verbatim):
${BRIEF}

Measurement:
${JSON.stringify(measure, null, 1)}

Plan:
${JSON.stringify(plan, null, 1)}

RED phase:
${JSON.stringify(red, null, 1)}

Implement the plan. Rebuild with \`cd ${REPO}/src && make\`. Make the new checks
green and keep every tier suite green.

* C89: declarations at the top of a block, no \`//\` comments.
* Every non-obvious guard gets a comment naming the ISSUE NUMBER and what a reader
  would otherwise assume. The comments on this branch are load-bearing documentation
  and they are quoted by structural test rows — write them deliberately.
* If a comment's text would match a structural grep the tests use, say so.
* Do not commit. The write-up agent commits.
* If you cannot make it green, set green=false and fill \`blocker\` with the exact
  failing line. Do NOT hack a row green by weakening its assertion.`,
  { label: `impl:${ID}`, phase: 'Implement', schema: SCHEMA_IMPL }
))

// ---------------------------------------------------------------- Verify x3

phase('Verify')
const VERIFY_COMMON = `${HOUSE}${RULINGS}${TIERTEXT}
Backlog item **${ID}**.

ITEM BRIEF (verbatim):
${BRIEF}

Measurement (BEFORE):
${JSON.stringify(measure, null, 1)}

Plan:
${JSON.stringify(plan, null, 1)}

What was implemented:
${JSON.stringify(impl, null, 1)}

You did NOT write this fix and you are not here to be agreeable.
**You may NOT run \`make\`** — another verify agent is running concurrently and two
builds on this box is the OOM. Run the binary already at \`${REPO}/src/xschem\`.
`

const verdicts = await parallel([
  () => agent(
    `${VERIFY_COMMON}
You are VERIFY-A: the TIER agent.

Re-run every suite in the tier list and diff the check counts against the recorded
baseline. Report each suite as \`name N/M\` plus the banner you actually saw.

A suite passes only on exit 0 AND a whole-line completion banner AND no column-0
death marker. A count that went UP is fine and expected if this item added rows;
a count that went DOWN without an explanation is a finding.

Also run the Tk-only suite on the dev display:
\`cd ${REPO} && tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_annot_show_menu.tcl\`

Finally run \`cd ${REPO}/tests && tclsh run_regression.tcl\` and report the counted
failures. Baseline is ZERO. If it is not zero, name the case and the reason PER
CASE — never carry a count forward as a known quantity.

verdict=FAIL if any tier suite is red for a reason this item caused.`,
    { label: `verify-tier:${ID}`, phase: 'Verify', schema: SCHEMA_VERIFY }
  ),
  () => agent(
    `${VERIFY_COMMON}
You are VERIFY-B: the STRUCTURE agent.

⚠ **You must not modify ANY file in the repository, for any reason.** A dedicated
Sabotage phase runs later, alone and build-permitted, and it owns tree mutation.
On the A3h run a predecessor of yours sabotaged \`utils/annot_mode.tcl\` in place
while the other two verifiers were live; one of them caught it and had to re-take
every number. Work only on COPIES under /tmp. If you believe a variant can only be
tested by editing the tree, say so in \`findings\` and leave it to the Sabotage phase.

The variants the plan named, for reference — the Sabotage phase will run them:
${JSON.stringify(plan.sabotage || [], null, 1)}

**You may not run \`make\`.** Therefore you cannot do a rebuild-based sabotage of C
code. Do what you CAN do without building, and say plainly what you could not do:
  * Tcl-level sabotage needs no build — neutralize the Tcl guard, run, restore.
  * Test-row sabotage needs no build — weaken a row, confirm it stops catching.
  * STRUCTURAL rows: verify each guard the plan named is actually pinned by a row
    that greps for it. Delete the guard TEXT in a /tmp COPY of the file and confirm
    the structural row's pattern stops matching. This proves the row can see the
    guard without touching the tree.
  * For C-level behavioural sabotage you cannot build: instead READ the code and
    state, for each guard, exactly which row would go red and why — and flag any
    guard for which you cannot name such a row. **A guard with no row that can see
    it is a finding**, and it is the single most common defect on this branch.

Report every PREDICTED red that did NOT appear, and every red nobody predicted.
Afterwards assert \`grep -rn SABOTAGE ${REPO}/src/\` is empty and that
\`git status --porcelain\` shows only the files the plan said it would touch.`,
    { label: `verify-sabotage:${ID}`, phase: 'Verify', schema: SCHEMA_VERIFY }
  ),
  () => agent(
    `${VERIFY_COMMON}
You are VERIFY-C: the ADVERSARY. Your job is to REFUTE the fix's central claim.
Default to refuted if you are uncertain.

Attack in this order:
  1. **Is the measured defect actually gone?** Re-run the measurement's repro
     command yourself and compare byte for byte with the recorded BEFORE lines.
     Do not take the implement agent's word for it.
  2. **Does the fix over-refuse?** Every guard that refuses something can refuse
     something it should have allowed. Construct the POSITIVE TWIN — the input that
     must still work — and run it. This branch has shipped two defects past
     twenty-eight passing checks, both of them over-refusals.
  3. **Is a new row hollow?** A row that would pass on the BROKEN tree proves
     nothing. Pick the most important new row and argue whether it is real.
  4. **Boundaries.** Zero, one, negative, empty string, NULL, the last element,
     one past the last element.
  5. **Does it violate a standing ruling?** Especially D5-1: is there any path on
     which a number that was not measured for a node can now appear beside it?

Every finding must be a CONCRETE input plus the WRONG OUTPUT it produces, or a
literal transcript line. An opinion is not a finding.`,
    { label: `verify-adversary:${ID}`, phase: 'Verify', schema: SCHEMA_VERIFY }
  ),
])

// A dead verifier must never read as a passing one. filter(Boolean) drops the
// nulls a terminal API error leaves behind, so losing all three would make
// `failed` empty -- indistinguishable from three PASSes. Require every verifier
// to have actually answered.
const vs = verdicts.filter(Boolean)
if (vs.length !== verdicts.length) {
  log(`STOPPED: ${verdicts.length - vs.length} of ${verdicts.length} verify agents returned nothing (terminal API error, or skipped). A missing verdict is not a passing one. No ledger row will be written and nothing is committed.`)
  throw new Error('verify agents returned null -- crew halted rather than read silence as a pass')
}
const failed = vs.filter(v => v.verdict === 'FAIL')
log(`${ID}: verify ${vs.map(v => v.verdict).join('/')}`)

// ------------------------------------------------- Sabotage (SERIAL, builds)

/* ISSUE 0876: the verify agents are forbidden to build, so on earlier items in
 * this run NOBODY ever sabotage-tested a C-level guard -- eight of them shipped
 * with no proof that any row can see them. This phase runs ALONE, after the
 * parallel verifiers have finished, and IS permitted to build. It is the only
 * place in the crew where a C guard's test coverage is actually demonstrated. */
phase('Sabotage')
const sabotage = must('SABOTAGE', await agent(
  `${HOUSE}${RULINGS}${TIERTEXT}
You are the SABOTAGE agent for backlog item **${ID}**. You run ALONE — every other
agent in this crew has finished — so **you ARE permitted to run \`make\`**, and you
are the only agent besides Implement who is.

What was implemented:
${JSON.stringify(impl, null, 1)}

Sabotage variants the plan named:
${JSON.stringify((plan && plan.sabotage) || [], null, 1)}

What the no-build verifiers could and could not establish:
${JSON.stringify(vs, null, 1)}

Your job is the one thing this run kept failing to do: **prove that every guard this
item added is actually seen by a test row.** A guard no row can see is not a guard,
it is a comment.

For EACH guard, in turn:
  1. Back up EVERY file you are about to touch, to /tmp.
  2. Neutralize the guard properly. A \`/* SABOTAGE */\` comment PREFIXED to a line
     does NOT disable the call on it. Delete the guard body, or rename the callee to
     a no-op macro. Deleting the whole line is usually cleanest.
  3. \`cd ${REPO}/src && make\`.
  4. Run the rows the plan predicted would redden. Record which actually reddened.
  5. Restore: \`cp /tmp/<backup> ${REPO}/src/<file> && touch ${REPO}/src/<file>\`.
     **NEVER \`cp -p\`** — a preserved mtime makes \`make\` a no-op and every later
     number is measured against the PREVIOUS sabotage's binary.
  6. \`make\` again and re-assert the baseline is green BEFORE moving to the next
     guard. A sabotage run lies if the restore was partial or the rebuild did not
     happen.

Do them ONE AT A TIME. Do not batch several neutralizations into one build — you
cannot attribute a red to a guard that way.

**Report every PREDICTED red that did NOT appear.** That is the finding, not an
inconvenience: it means the guard shipped untested, and on this branch that is the
defect that has twice slipped past twenty-eight passing checks.

When finished:
  * assert \`grep -rn SABOTAGE ${REPO}/src/\` is empty,
  * assert \`git status --porcelain\` shows only files this item legitimately changed,
  * assert \`git diff\` against the item's own commit is empty for every src file you
    touched — i.e. you really did restore them,
  * and confirm the tier list is green on the RESTORED, REBUILT binary.

verdict=FAIL if any guard has no row that can see it, or if you could not restore
the tree cleanly. List each unseen guard in \`unexpected\`.`,
  { label: `sabotage:${ID}`, phase: 'Sabotage', schema: SCHEMA_VERIFY }
))

if (sabotage && sabotage.verdict === 'FAIL') {
  vs.push(sabotage)
  if (!failed.includes(sabotage)) failed.push(sabotage)
  log(`${ID}: sabotage FAIL — ${(sabotage.unexpected || []).length} guard(s) unseen`)
} else {
  log(`${ID}: sabotage ${sabotage ? sabotage.verdict : 'null'}`)
}

// ------------------------------------------------- Repair loop (bounded)

let repair = null
if (failed.length > 0 && impl.green !== false) {
  phase('Implement')
  repair = await agent(
    `${HOUSE}${RULINGS}${TIERTEXT}
You are the REPAIR agent for backlog item **${ID}**. You ARE permitted to run
\`make\` — the verify agents have all finished, so you are alone on the box.

What was implemented:
${JSON.stringify(impl, null, 1)}

The verifiers found problems:
${JSON.stringify(failed, null, 1)}

The sabotage pass reported:
${JSON.stringify(sabotage, null, 1)}

If the sabotage pass found a guard that NO row can see, the fix is to ADD THE ROW,
not to delete the guard. A structural row that greps the function body is the
honest answer when a second guard already covers the case behaviourally.

Fix what they found. Then re-run the tier list yourself and confirm green.

If a finding is WRONG — the verifier misread the code, or ran the wrong thing —
say so with evidence and do not change the code to satisfy it. A verifier being
mistaken is common; a fix bent to satisfy a mistaken verifier is a real defect.

If you cannot resolve it, set green=false and fill \`blocker\`. The item will land
as F or D and that is an honest outcome.`,
    { label: `repair:${ID}`, phase: 'Implement', schema: SCHEMA_IMPL }
  )
}

// ---------------------------------------------------------------- Write-up

phase('Writeup')
const writeup = must('WRITE-UP', await agent(
  `${HOUSE}${RULINGS}${TIERTEXT}
You are the WRITE-UP AND COMMIT agent for backlog item **${ID}**. You are last
before the ledger. Everything below is the crew's work; your job is to make it
durable and then commit it.

ITEM BRIEF (verbatim):
${BRIEF}

Measurement (BEFORE, literal):
${JSON.stringify(measure, null, 1)}

Plan:
${JSON.stringify(plan, null, 1)}

Implementation:
${JSON.stringify(impl, null, 1)}

Verification:
${JSON.stringify(vs, null, 1)}

Sabotage pass (guards actually proven visible to a row):
${JSON.stringify(sabotage, null, 1)}

Repair pass (null if none was needed):
${JSON.stringify(repair, null, 1)}

DO:
1. **Issue file.** Update the existing \`doc/claude/issues/NNNN-*.md\` if the brief
   names one, or create a new one numbered from the next free number upward
   (never 0500-0599, never 0700-0799, never 1000-1199). Record: what was measured BEFORE (quote the literal lines),
   what changed, why, what is still open, and the acceptance rows that now pin it.
   Mark it FIXED only if it is.
2. **File anything measured and not fixed** as its own issue, numbered the same way.
   Do NOT fix a discovered defect silently and do not leave it unfiled.
3. **Docs that the change earns**: \`doc/claude/WIRING.md\` if wires were touched,
   \`doc/claude/FAQ.md\` for a design Q&A worth keeping (newest on top),
   \`doc/claude/specs/\` for a feature contract, \`CLAUDE.md\` ONLY if a build/test
   invariant changed.
4. **Debt.** If any deliverable can only be confirmed by a human looking at pixels,
   run \`cd ${REPO} && tests/headless/owed.sh add look "<what>" "<why>"\`.
   If you made a user-visible decision nobody ratified, run
   \`tests/headless/owed.sh add rule <issue-number> "<why>"\`.
   Do this even if every suite is green. **A green suite never discharges an
   eyeball debt.**
5. **Commit.** \`git add\` the EXACT paths — never \`git add -A\`, the tree has
   untracked scatter that must stay untracked. Include
   \`doc/claude/ledger/annot_run_2026-08-27.md\` ONLY if you also edited it (you
   should not; the ledger agent appends after you).
   Commit body in house style: what was measured before, what changed, why, what is
   still open. Subject line \`<type>(<issue>): <plain sentence>\`.
   Trailer: \`Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\`
   **NEVER \`git push\`. NEVER open a PR.**
6. Report the commit sha.

STATUS you must choose:
  **x** — done, verified, committed.
  **E** — landed and committed, but a human must eyeball it (GUI-only proof) OR it
      changed user-visible behaviour nobody ratified. Put the EXACT question for the
      user in \`result\`, one line.
  **F** — failed. Leave the tree CLEAN: revert your own edits, commit nothing.
  **D** — deferred/blocked. Tree clean, nothing committed.

If the implement agent set green=false and repair did not rescue it, the status is
F or D and you commit NOTHING except possibly the issue file recording the
measurement. Say so plainly. An honest F is worth more than a green-looking x.`,
  { label: `writeup:${ID}`, phase: 'Writeup', schema: SCHEMA_WRITEUP }
))

// ---------------------------------------------------------------- Ledger

phase('Ledger')
const rowResult = await agent(
  `Append EXACTLY ONE markdown table row to \`${REPO}/${LEDGER}\` and do nothing else.

Use a shell append so you cannot damage the file:
\`cat >> ${REPO}/${LEDGER} <<'EOF'\` ... \`EOF\`

The row, in this column order, pipe delimited, on ONE line:
| ${ID} | <status> | <commit sha or none> | <suites+counts> | <new issues or none> | <one-line result> |

Values to use, verbatim from the crew's receipt:
  status:     ${writeup && writeup.status ? writeup.status : 'F'}
  commit:     ${writeup && writeup.commit ? writeup.commit : 'none'}
  suites:     ${writeup && writeup.suites ? writeup.suites : 'unknown'}
  new issues: ${writeup && writeup.new_issues ? writeup.new_issues : 'none'}
  result:     ${writeup && writeup.result ? writeup.result : 'crew produced no receipt'}

Rules:
* Escape any literal \`|\` inside a cell as \`\\|\` or the table breaks.
* Keep the result cell to ONE line. Collapse newlines to \`; \`.
* Do NOT rewrite, reformat or reorder any existing line in the file.
* Do NOT commit. Do NOT run git at all.
Then reply with the single word \`appended\`.`,
  { label: `ledger:${ID}`, phase: 'Ledger' }
)

return {
  id: ID,
  status: writeup ? writeup.status : 'F',
  commit: writeup ? writeup.commit : 'none',
  suites: writeup ? writeup.suites : 'unknown',
  new_issues: writeup ? writeup.new_issues : 'none',
  result: writeup ? writeup.result : 'crew produced no receipt',
  evidence: writeup ? (writeup.evidence || []).slice(0, 3) : [],
  blocker: writeup ? (writeup.blocker || '') : 'no writeup',
  ledger: rowResult,
}
