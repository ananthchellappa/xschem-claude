export const meta = {
  name: 'results-item',
  description: 'One results-batch item: implement, verify, adversarially review, fix, commit',
  phases: [
    { title: 'Implement' },
    { title: 'Verify' },
    { title: 'Review' },
    { title: 'Fix' },
    { title: 'Commit' },
  ],
}

// ===========================================================================
// results batch item pipeline — doc/claude/results_batch/item_pipeline.js
//
// Cloned from doc/claude/casemode_batch/item_pipeline.js. STAGE ORDER AND
// CONTRACT ARE UNCHANGED — only the paths, the batch name, the base HEAD and
// the baseline file differ. Batch-specific traps and discipline are NOT baked
// in here; they live in doc/claude/results_batch/CREW_BRIEF.md, which the
// driver puts in every item's `load` list.
//
// Invoked by the DRIVER as
//   Workflow({ scriptPath: 'doc/claude/results_batch/item_pipeline.js', args: {...} })
//
// args = {
//   n:     <int>      item number (PLAN.md §1)
//   slug:  <string>   kebab-case slug, used for the receipt filename
//   title: <string>   short title (goes in prompts and the receipt header)
//   brief: <string>   the FULL scope text for the item, verbatim from PLAN.md §4
//   load:  <string[]> files the crew MUST read before starting
//   hints: <string>   free-text extra guidance, may be empty
// }
//
// Returns a SMALL object and nothing else — see the bottom of this file. The
// driver's context is protected by that; everything longer lives in the receipt
// at doc/claude/results_batch/receipts/<NN>-<slug>.md (120 lines max).
//
// Stage order is fixed: Implement -> Verify -> Review(3 hostile lenses in
// parallel) -> Fix(only if confirmed findings) -> Commit. The verifier, the
// reviewers and the fixer are all DIFFERENT agents from the implementer: every
// agent() call is a fresh subagent with no memory of the previous one, and each
// prompt says so explicitly so nobody rubber-stamps their own work.
// ===========================================================================

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCHDIR = REPO + '/doc/claude/results_batch'
const LEDGER = BATCHDIR + '/LEDGER.md'
// Shot fresh at the batch's base HEAD 226302f9 (2026-08-19), on the dev display
// :99, with GUI_GATE=1. The driver rolls this constant forward when an item adds
// a suite of its own, exactly as the casemode batch did: diffing against the
// immediately preceding state is strictly more sensitive, not less. BASELINE_SUMMARY
// below must be rolled forward with it.
const BASELINE = REPO + '/doc/claude/results_batch/baseline_2026-08-19_226302f9.txt'
const BASELINE_SUMMARY = '331 pass / 15 fail / 0 crash-timeout / 0 skip of 346, taken at HEAD 226302f9 on the dev display :99 with GUI_GATE=1. Its 15 reds are: test_ase_window, test_cadence_drag, test_ciw, test_gf180mcud_libmgr, test_ihp_sg13g2_libmgr, test_lib_manager_gui, test_lib_manager_locate, test_lib_sweep, test_reopen_readonly, test_rotate_stretch_short_0104, test_selflog_output, test_sky130a_libmgr, test_wave_markers, test_wave_sigbrowser_0312, test_wave_sigbrowser_keys. Two of those are known and are NOT yours to chase: test_wave_markers passes standalone and FAILs in the audit, and the four libmgr reds are the documented environment failure where the working tree untracked SANDBOX / TEST dirs show up in library_list. This baseline is byte-for-byte the same status set as the casemode batch closer audit, so the tree is stable going in. SUITES THIS BATCH HAS ADDED, which legitimately appear as extra PASS rows and are NOT a diff you must explain: test_results_select (item 1, total 347). The current list is in LEDGER.md; anything NOT on it that moves in either direction is yours.'
const VOID_BASELINE = REPO + '/doc/claude/batch_F/baseline_status.txt'

const A = (typeof args === 'string') ? JSON.parse(args) : (args || {})
if (A.n === undefined || A.n === null) throw new Error('args.n (item number) is required')
if (!A.slug) throw new Error('args.slug (kebab-case receipt slug) is required')

const N = Number(A.n)
const NN = (N < 10 ? '0' : '') + String(N)
const TITLE = String(A.title || ('item ' + NN))
const BRIEF = String(A.brief || '(driver passed no brief — read the item ' + NN + ' row in ' + LEDGER + ')')
const LOAD = Array.isArray(A.load) ? A.load : (A.load ? [String(A.load)] : [])
const HINTS = String(A.hints || '')
const RECEIPT = BATCHDIR + '/receipts/' + NN + '-' + A.slug + '.md'
const TAG = NN + ':' + A.slug

// ---------------------------------------------------------------- shared text

const GATE = [
  'GUI TEST GATE — MANDATORY, DO NOT DISABLE:',
  '- Export GUI_GATE=1 for every suite run and every render probe. NEVER GUI_GATE=0, not "just to check something quickly", not in a subshell. (tests/headless/xvfb_arm.sh forces GUI_GATE=0 for itself on the virtual display; that is the harness\'s business, not yours to imitate.)',
  '- The gate control dir ~/.claude/gui_test_gate/ is ALREADY armed with allow_until=forever. gate_start will therefore not take the asking path. Do NOT relaunch the panel, do NOT kill it, do NOT re-arm it, and do NOT write anything into ~/.claude/gui_test_gate/ .',
  '- Run suites through tests/headless/run_suites.sh, or single runs through tests/headless/gated_xschem.sh. A bare "for i in ...; do ./src/xschem ...; done" loop enrols in neither, cannot be paused by the user, and shows up on the panel as UNGATED — never write one.',
  '- The gate is the user\'s authority over their own screen. If a run stalls it may simply be PAUSED: wait for it, never override it.',
].join('\n')

const STANDING = [
  'STANDING RULES FOR THIS BATCH — from the batch brief, binding on every stage:',
  '- The persistent dev display is UP (:99, 1920x1080x24, openbox). full_audit.sh and run_suites.sh self-arm to it; a bare `./src/xschem --script` does NOT. Route a bare run as `tests/headless/devdisplay.sh exec ./src/xschem …`.',
  '- The shell inherits DISPLAY=:0. A bare tests/headless/test_gui_gate_*.sh will pop panels on the USER\'S REAL SCREEN. For the gate suites that is the prescribed arm; for anything else it is a mistake. Say so out loud when you do it.',
  '- NEVER run full_audit.sh with DISPLAY stripped (`env -u DISPLAY`) — the GUI guards themselves throw `invalid command name "winfo"` and you get ~62 bogus CRASHes.',
  '- full_audit.sh globs test_*.tcl only, so NO .sh suite is scored by it. If this item touches one, run it by hand and say so in the receipt.',
  '- An item whose deliverable is pixels may not be verdicted [x] — it is [E], and it owes a `tests/headless/owed.sh add look` entry.',
  '- Commit when green; NEVER push.',
].join('\n')

const TRAPS = [
  'TRAPS — these are already known; do not rediscover them:',
  '- "-q" on the xschem command line is --quit, NOT --quiet.',
  '- Set XSCHEM_LIBRARY_PATH UNQUALIFIED; set XSCHEM_LIBRARY_DEFS qualified.',
  '- NEVER print "RESULT: SKIP", "skipped: no X" or "SKIP: no X connection" from a per-group skip. full_audit.sh scores the WHOLE FILE as SKIP on that substring and silently discards every check that actually ran in it.',
  '- Never run make in the xschem tree while suites are running — CPU load makes the headless suites flake, and 4 repeat failures are not determinism.',
  '- Known WSLg flakes that are NOT regressions: test_ase_plot P4/P6/P8 (1-2 in 10), TG9 root-coords (4 in 10 on a pristine tree), and bare `event generate` key delivery (~1 in 5). Re-run before calling any of them a fail.',
  '- test_ase_window fails its W7 "simulator produced output before Stop" check. That is PRE-EXISTING and A/B-confirmed against a pre-merge binary — 1 failed / 168 passed on BOTH sides. Do not chase it.',
  '- The four libmgr reds (test_gf180mcud_libmgr, test_ihp_sg13g2_libmgr, test_sky130a_libmgr, test_lib_manager_*) are the documented environment failure: the working tree\'s untracked SANDBOX / TEST dirs show up in library_list.',
  '- A --script file must end in an explicit `exit 0` or the process idles forever.',
  '- Use tests/headless/scratch.tcl (test_scratch) for scratch files; leave no droppings in the repo. A helper file must NOT be named test_*.tcl — full_audit.sh globs those and scores a zero-check file FAIL forever.',
].join('\n')

const POLICY = [
  'POLICY — binding on every stage:',
  '- NEVER push. There is no "git push" in this batch, not to any remote, not with any flag. Only the Commit stage commits; nothing leaves this machine.',
  '- Git hygiene: never `git reset --hard`, never `git add -A`, never `git commit -a`. Stage an explicit file list. Never stage a file that was already dirty before this item started.',
  '- AUDIT IS A DIFF, NOT A COUNT. Report any audit as a diff against ' + BASELINE + ', by test NAME and STATUS, naming every test whose status changed IN EITHER DIRECTION (red->green counts and must be explained too). Baseline: ' + BASELINE_SUMMARY + ' Anything going red that is not in that red list is YOURS, and it outranks everything else in the item. NOTE when you count the baseline yourself: lines reading "FAIL     | key ..." are within-file DETAIL, not test rows — a naive `grep -c \'^FAIL\'` over-counts. NEVER judge by the red count: full_audit.sh is never clean, and "the audit is red" is not a finding.',
  '- ' + VOID_BASELINE + ' (285/19/1) IS VOID. It was shot with the pre-rework audit scorer. Do NOT diff against it, do not cite it, do not average it in.',
  '- A DELIVERABLE MADE OF PIXELS MAY NOT BE VERDICTED [x]. If the real payload of the change is something only a human looking at the screen can confirm (layout, colour, what a widget looks like, whether a notice reads sensibly), the verdict is [E] — eyeball pending — however many checks passed. Say what to look at.',
  '- WHERE A DECISION IS GENUINELY OPEN, THE CREW MAKES THE RULING. Write the ruling and its rationale into the relevant spec under doc/claude/specs/, and record it in the receipt with the evidence that drove it. There is no human to ask. Never stop and ask; never leave the item half-done pending an answer.',
  '- A green suite does not prove the changed code ran. Sabotage is the evidence: break the thing under test, name the check that goes red, restore from a byte-exact backup, re-run green. A check with no sabotage is not evidence. If this item adds NO new checks (a harness or run-only item), say so explicitly and give the red/green drive that stands in for it — the same rule applies to a list edit as to a feature.',
  '- While the item is uncommitted, revert a sabotage from a byte-exact BACKUP, never `git checkout -- <file>` (that reverts to the previous commit and deletes the item).',
  '- Do NOT edit ' + LEDGER + '. The driver owns the ledger and appends the row itself.',
  '- Do NOT run tools/review_gate/review_gate.sh. That gate asks a human and there is no human in this batch.',
].join('\n')

const ITEM = [
  '=== RESULTS BATCH, ITEM ' + NN + ': ' + TITLE + ' ===',
  '',
  'Repo: ' + REPO + ' , branch fluid-editing, base HEAD 226302f9. Nothing is pushed.',
  'Context for the whole batch: ' + BATCHDIR + '/CREW_BRIEF.md (read it FIRST — it carries traps that have already cost real time, and the decisions you may not re-open).',
  '',
  '--- SCOPE (verbatim from the driver) ---',
  BRIEF,
  '',
  '--- FILES YOU MUST READ BEFORE STARTING ---',
  LOAD.length ? LOAD.map(f => '- ' + f).join('\n') : '(the driver named none — read the item ' + NN + ' row in ' + LEDGER + ' and the spec it points at)',
  '',
  '--- EXTRA GUIDANCE ---',
  HINTS || '(none)',
].join('\n')

const COMMON = [ITEM, '', GATE, '', STANDING, '', TRAPS, '', POLICY].join('\n')

// ---------------------------------------------------------------- schemas

const IMPL_SCHEMA = {
  type: 'object',
  required: ['done', 'filesTouched', 'testFiles', 'newChecks', 'summary'],
  properties: {
    done: { type: 'boolean', description: 'false when you could not finish — a truthful failure beats a green lie' },
    blocked: { type: 'string', description: 'what stopped you, empty when done' },
    filesTouched: { type: 'array', items: { type: 'string' } },
    testFiles: { type: 'array', items: { type: 'string' } },
    newChecks: { type: 'array', items: { type: 'string' }, description: 'the id of every check added or restated' },
    howToRun: { type: 'string', description: 'the exact command(s) that exercise this item, for the verifier' },
    rulings: { type: 'array', items: { type: 'string' }, description: 'open decisions ruled on, and where the rationale was written' },
    pixelPayload: { type: 'boolean', description: 'true when the real payload is something only a human eye can confirm' },
    declaredLimits: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['ok', 'checkCount', 'sabotages', 'suitesRun', 'problems'],
  properties: {
    ok: { type: 'boolean' },
    ranEndToEnd: { type: 'string', description: 'what you ran as the REAL thing, not a unit check' },
    checkCount: { type: 'integer', description: 'checks actually counted in the item test file(s)' },
    suitesRun: { type: 'array', items: { type: 'string' } },
    suiteResult: { type: 'string', description: 'the verbatim RESULT line(s)' },
    sabotages: {
      type: 'array',
      description: 'ONE ROW PER NEW CHECK. A check with no row is not evidence. For a run-only or harness item, one row per red/green drive.',
      items: {
        type: 'object',
        required: ['check', 'broke', 'wentRed', 'restoredGreen'],
        properties: {
          check: { type: 'string' },
          broke: { type: 'string', description: 'exactly what was broken, file:line level' },
          wentRed: { type: 'boolean' },
          restoredGreen: { type: 'boolean' },
          note: { type: 'string' },
        },
      },
    },
    uncovered: { type: 'array', items: { type: 'string' }, description: 'new checks that survived their own sabotage — coverage holes' },
    auditDiff: { type: 'array', items: { type: 'string' }, description: 'test name + old status -> new status, both directions; empty means no status moved' },
    pixelPayload: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' } },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['lens', 'refuted', 'findings'],
  properties: {
    lens: { type: 'string' },
    refuted: { type: 'boolean', description: 'true when you found something real' },
    ranItself: { type: 'array', items: { type: 'string' }, description: 'commands YOU ran — not what you were told' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['key', 'file', 'claim', 'reproducer'],
        properties: {
          key: {
            type: 'string',
            description: 'kebab-case slug naming the DEFECT, formed as <file-basename>-<symptom>, e.g. "full-audit-sh-logdir-list-misses-case". Two reviewers who found the SAME defect must land on the same slug, so name the defect, never your reasoning.',
          },
          file: { type: 'string' },
          claim: { type: 'string', description: 'one sentence: what is wrong' },
          reproducer: {
            type: 'string',
            description: 'CONCRETE reproducing scenario: inputs/state -> observed wrong output, ideally a command you ran and its output. Write the empty string if you have no reproducer — do not write "n/a" or a hypothesis.',
          },
          severity: { enum: ['blocker', 'major', 'minor'] },
          fix: { type: 'string' },
        },
      },
    },
    notProven: { type: 'array', items: { type: 'string' }, description: 'claims in the receipt you could NOT confirm, stated as not-proven' },
  },
}

const CLOSE_SCHEMA = {
  type: 'object',
  required: ['verdict', 'commit', 'checks', 'sabotages', 'filesChanged', 'eyeballNeeded', 'note'],
  properties: {
    verdict: { enum: ['[x]', '[E]', '[D]', '[F]'] },
    commit: { type: 'string', description: 'short hash, or the empty string when nothing was committed' },
    checks: { type: 'integer' },
    sabotages: { type: 'integer' },
    filesChanged: { type: 'integer' },
    eyeballNeeded: { type: 'boolean' },
    note: { type: 'string', description: 'AT MOST 40 WORDS. Everything longer belongs in the receipt.' },
    receipt: { type: 'string' },
    issue: { type: 'string', description: 'path of the filed issue — REQUIRED for [D] and [F], empty otherwise' },
  },
}

// ---------------------------------------------------------------- Implement

phase('Implement')
log('item ' + NN + ' (' + TITLE + '): implement')

const impl = await agent([
  'You are the IMPLEMENTER for results batch item ' + NN + '. You are the only agent that writes the change; a different agent verifies it, three more try to refute it, and a fifth commits it.',
  '',
  COMMON,
  '',
  'Do this, in order:',
  '1. READ EVERY FILE IN THE LIST ABOVE, FIRST, before touching anything. They carry corrections the brief does not. If one does not exist, say so and read the nearest equivalent rather than guessing.',
  '2. Implement the scope. Stay inside it: do not opportunistically fix neighbouring code, and do not renumber or delete an existing check — restate it if its expectation genuinely changed, and say why.',
  '3. WRITE OR EXTEND THE HEADLESS TEST(S) THAT PROVE IT, where the item has a testable surface. Measure the first free check-id band by grepping tests/headless/*.tcl for the highest id actually in use — a band quoted in a doc is not evidence, and doc-quoted bands in this repo have been wrong twice. Run the new checks BEFORE the code works: a check that passes before the feature exists is vacuous and must be rewritten to carry its positive evidence in the same assertion. If this item is a harness edit or a run-only item with no new checks, say so explicitly and name the red/green drive that stands in for them.',
  '4. Build with `cd src && make` if you touched C. Never run make while a suite is running.',
  '5. Run the relevant suite(s) through tests/headless/run_suites.sh with GUI_GATE=1 and confirm your own file is green and the counts did not shrink. A shortfall in the CHECK COUNT is the only witness to a file that aborted early.',
  '6. If the item is doc-only, the deliverable is still evidence-bearing: state which claim in the doc you verified against source, with file:line.',
  '',
  'DO NOT COMMIT. Do not `git add`. Leave the tree dirty for the verifier — the Commit stage owns the commit.',
  'If you cannot finish, return done=false with `blocked` filled in and leave the tree in a state you describe exactly. A truthful failure is worth more than a green lie.',
  'Set pixelPayload=true if the real payload of this change is something only a human looking at the screen can confirm.',
].join('\n'), { schema: IMPL_SCHEMA, phase: 'Implement', label: 'impl:' + TAG, effort: 'high' })

if (!impl) {
  log('item ' + NN + ': IMPLEMENTER DIED (null). No verification, no commit.')
}

// ---------------------------------------------------------------- Verify

let verify = null
if (impl) {
  phase('Verify')
  log('item ' + NN + ': verify + sabotage')

  verify = await agent([
    'You are the VERIFIER for results batch item ' + NN + '. You did NOT write this change and you trust none of the claims below. Your default posture is that the implementer is optimistic.',
    '',
    COMMON,
    '',
    '=== WHAT THE IMPLEMENTER CLAIMS ===',
    JSON.stringify(impl, null, 1),
    '',
    'Verify by DOING:',
    '1. RUN THE REAL THING END TO END, not only the unit checks. Drive the actual behaviour the way a user or the harness would reach it and confirm it with your own eyes on the output. A passing unit check on a helper proc is not the thing working.',
    '2. Count the checks in the item test file(s) yourself. Does the count match the claim? A shortfall means the file aborted early and every number in the receipt is unreadable.',
    '3. Run the relevant headless suite(s) through tests/headless/run_suites.sh with GUI_GATE=1. Record the VERBATIM RESULT line.',
    '4. SABOTAGE EVERY NEW CHECK — one row per check, no exceptions. For each: break the thing under test (the real code, not the test), prove the edit reached disk, run, name the check that went RED, confirm nothing else unrelated went red, restore from a byte-exact backup, diff the restore, re-run green. A check that stays GREEN under a sabotage aimed straight at it is a coverage hole: put it in `uncovered` and say so loudly. A check with no sabotage row is not evidence and must not be counted. For a harness or run-only item, the equivalent is the red/green drive: revert the change, show the SAME rows go back to failing on the SAME first line, restore, show them green again — and report BOTH directions.',
    '5. Run the audit and report it as a DIFF against ' + BASELINE + ' by test NAME and STATUS, both directions. Never as a red count. Never diff against ' + VOID_BASELINE + '.',
    '6. Judge the pixel question honestly: if what this item really delivers is something only a human eye can confirm, set pixelPayload=true regardless of how many checks passed.',
    '',
    'Do not repair anything. Report ok=false with specific, reproducible problems, or ok=true.',
    'Do NOT commit and do NOT push.',
  ].join('\n'), { schema: VERIFY_SCHEMA, phase: 'Verify', label: 'verify:' + TAG, effort: 'high' })

  if (!verify) log('item ' + NN + ': VERIFIER DIED (null) — there is no sabotage evidence for this item.')
}

// ---------------------------------------------------------------- Review

const LENSES = [
  {
    key: 'correctness',
    text: [
      'LENS 1 — CORRECTNESS. Read the actual diff (`git diff` plus `git status`) and the code around it, not the summary.',
      'Hunt for: wrong behaviour on edge inputs (empty, one element, trailing separator, escaped separator, missing file, unreadable file, a name that is also a prefix of another name); off-by-one in any index or count; a loop that skips its last element; state left behind on an error path; a return value nobody checks; memory freed twice or not at all if C was touched; a Tcl proc whose signature changed while a caller or a spy did not; a shell list membership test that matches on a substring where it meant a whole word.',
      'For any change to how a string is split or a name is matched, construct the input that breaks it and RUN IT.',
    ].join(' '),
  },
  {
    key: 'regression',
    text: [
      'LENS 2 — REGRESSION AND SIDE EFFECTS. Assume the change broke something it never mentions.',
      'Check: every other caller of every function, proc or shell variable that was touched (grep the whole tree, including *.tcl, *.sh and tests/); any frozen oracle or literal-string pin the change could red; any check elsewhere that asserts the OLD behaviour; scope leak in the diff — files touched that the brief never named; anything staged that was dirty before the item started.',
      'Then run a suite the implementer did NOT run, chosen because it exercises the same code, through tests/headless/run_suites.sh with GUI_GATE=1, and diff its status against ' + BASELINE + '.',
    ].join(' '),
  },
  {
    key: 'evidence',
    text: [
      'LENS 3 — DOES THE EVIDENCE ACTUALLY PROVE IT. Attack the tests and the run log, not the change.',
      'For each new check ask: could this check ever fail? Does it assert on program behaviour, or on a value the test computed itself? Does it read back state that its own helper just restored? Does it throw instead of failing (a Tcl error escapes the check and the file dies quietly)? Does a negative check have a positive control on the same fixture? Are the expected literals string reps — `[list ok [list x]]` is `ok x`, not `{ok {x}}`? For a run-only item: does the reported PASS actually come from the run they claim, on the display they claim, or from a log that pre-dates it?',
      'Then INVENT A SABOTAGE NOBODY NAMED, aimed at the core of the item, and run it. If the suite stays green under your sabotage, the tests do not cover the item — that is a finding with a reproducer, however many checks passed. Also re-run ONE sabotage from the verifier table from scratch and confirm it behaves exactly as claimed.',
    ].join(' '),
  },
]

let reviews = []
if (impl) {
  phase('Review')
  log('item ' + NN + ': 3 hostile reviewers')

  reviews = await parallel(LENSES.map(l => () => agent([
    'You are an ADVERSARIAL REVIEWER for results batch item ' + NN + '. You did NOT write this change and you did NOT verify it.',
    '',
    'YOUR JOB IS TO REFUTE THE WORK. You are not here to confirm it. Default to "NOT PROVEN" whenever you are uncertain: an unproven claim goes in `notProven`, and only something you can actually demonstrate goes in `findings`. Being unable to break it is a legitimate outcome — say so — but do not certify what you did not test.',
    '',
    l.text,
    '',
    COMMON,
    '',
    '=== IMPLEMENTER CLAIMS (treat as advertising) ===',
    JSON.stringify(impl, null, 1),
    '',
    '=== VERIFIER CLAIMS (treat as advertising) ===',
    verify ? JSON.stringify(verify, null, 1) : '(the verifier agent DIED — there is NO sabotage evidence for this item. That absence is itself a finding: raise it with a reproducer showing which new checks are unsabotaged.)',
    '',
    'HOW YOUR FINDINGS ARE COUNTED — this matters for how you write them:',
    'A finding is CONFIRMED, and gets fixed, when at least 2 of the 3 reviewers raise it, OR when ONE reviewer raises it with a concrete reproducing scenario. The three of you work independently and cannot talk, so the clustering is done by your `key` slug: name the DEFECT (<file-basename>-<symptom>), never your route to it, so a reviewer who found the same defect down a different path lands on the same slug.',
    'A `reproducer` must be a concrete scenario — inputs or state, the command you ran, the wrong output you observed. If you do not have one, write the empty string; a hypothesis dressed as a reproducer causes a fixer to churn real code on a guess.',
    '',
    'Run things. A review that only read files is worth little — put what you ran in `ranItself`.',
    'Do NOT fix anything, do NOT commit, do NOT push.',
  ].join('\n'), { schema: REVIEW_SCHEMA, phase: 'Review', label: 'review:' + l.key + ':' + TAG, effort: 'high' })))
}

// -------------------------------------------------- confirmation arithmetic
// CONFIRMED = raised by >= 2 of the 3 lenses, OR raised once WITH a concrete
// reproducer. Clustering is by normalised key slug, with a containment fallback
// so "logdir-list-misses-case" and "full-audit-sh-logdir-list-misses-case" are
// one finding rather than two singletons that each escape the >= 2 rule.

function norm(s) {
  return String(s === undefined || s === null ? '' : s)
    .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+/, '').replace(/-+$/, '')
}
function sameDefect(a, b) {
  if (!a || !b) return false
  if (a === b) return true
  if (a.length < 10 || b.length < 10) return false
  return a.indexOf(b) >= 0 || b.indexOf(a) >= 0
}
function hasRepro(f) {
  const r = norm(f && f.reproducer)
  if (r.length < 12) return false
  return r !== 'n-a' && r !== 'none' && r !== 'not-applicable' && r !== 'no-reproducer'
}

const liveReviews = (reviews || []).filter(Boolean)
// Only count a lens as DEAD when the Review stage actually ran (it is skipped
// wholesale when the implementer died, and 3 "dead" lenses would misreport that).
const deadLenses = impl ? (LENSES.length - liveReviews.length) : 0

const clusters = []
// Iterate the RAW array so index i still lines up with LENSES: filtering first
// would shift the indices and mislabel a finding whenever a lens died.
;(reviews || []).forEach((rev, i) => {
  if (!rev) return
  const lens = String(rev.lens || (LENSES[i] ? LENSES[i].key : 'lens' + i))
  const flist = Array.isArray(rev.findings) ? rev.findings : []
  flist.forEach(f => {
    if (!f) return
    const k = norm(f.key) || norm(f.claim).slice(0, 60)
    let c = null
    for (let j = 0; j < clusters.length; j++) if (sameDefect(clusters[j].key, k)) { c = clusters[j]; break }
    if (!c) { c = { key: k, lenses: [], members: [] }; clusters.push(c) }
    if (c.lenses.indexOf(lens) < 0) c.lenses.push(lens)
    c.members.push({ lens: lens, file: f.file, claim: f.claim, reproducer: f.reproducer, severity: f.severity, fix: f.fix })
  })
})

const confirmed = clusters.filter(c => c.lenses.length >= 2 || c.members.some(hasRepro))
const unconfirmed = clusters.filter(c => confirmed.indexOf(c) < 0)
const notProven = liveReviews.flatMap(r => Array.isArray(r.notProven) ? r.notProven : [])

log('item ' + NN + ': reviewers ' + liveReviews.length + '/3, findings ' + clusters.length
  + ', confirmed ' + confirmed.length + ', unconfirmed ' + unconfirmed.length)

// ---------------------------------------------------------------- Fix
// Skipped ENTIRELY — no agent call at all — when nothing was confirmed.

let fix = null
if (impl && confirmed.length) {
  phase('Fix')
  log('item ' + NN + ': fixing ' + confirmed.length + ' confirmed finding(s)')

  fix = await agent([
    'You are the FIXER for results batch item ' + NN + '. You did not write this change and you did not review it.',
    '',
    COMMON,
    '',
    '=== CONFIRMED FINDINGS — FIX EXACTLY THESE, AND NOTHING ELSE ===',
    'Each was raised by at least two independent reviewers, or by one with a concrete reproducer.',
    JSON.stringify(confirmed.map(c => ({ key: c.key, raisedBy: c.lenses, members: c.members })), null, 1),
    '',
    '=== RAISED BUT NOT CONFIRMED — DO NOT ACT ON THESE ===',
    'They go in the receipt as "raised, not confirmed" so the record is honest. Changing code to satisfy an unconfirmed finding is how a batch churns.',
    JSON.stringify(unconfirmed.map(c => ({ key: c.key, raisedBy: c.lenses, members: c.members })), null, 1),
    '',
    '=== ORIGINAL IMPLEMENTER CLAIMS ===', JSON.stringify(impl, null, 1),
    '=== ORIGINAL VERIFIER RESULT ===', verify ? JSON.stringify(verify, null, 1) : '(verifier died)',
    '',
    'Do this:',
    '1. Fix each confirmed finding. If one of them is NOT actually a defect, do not change code to appease it: say so with EVIDENCE (the command you ran and its output) and move on.',
    '2. Rebuild if you touched C, then re-run the relevant suite(s) through tests/headless/run_suites.sh with GUI_GATE=1.',
    '3. RE-SABOTAGE EVERY CHECK YOU TOUCHED, and every check whose subject your fix changed: break it, name the red check, restore, re-run green. A fix that quietly disarmed a check is worse than the bug.',
    '4. Re-run the audit and report the diff against ' + BASELINE + ' by name and status, both directions.',
    '',
    'Do NOT commit and do NOT push — the Commit stage owns that. Return the updated picture in the same shape as the verifier: checkCount, the full sabotage table (including the rows you re-ran), suiteResult, auditDiff, and problems that remain.',
  ].join('\n'), { schema: VERIFY_SCHEMA, phase: 'Fix', label: 'fix:' + TAG, effort: 'high' })

  if (!fix) log('item ' + NN + ': FIXER DIED (null) — confirmed findings remain unfixed.')
}

// ---------------------------------------------------------------- Commit

phase('Commit')
log('item ' + NN + ': receipt + audit diff + commit')

const evidence = fix || verify

const close = await agent([
  'You are the CLOSER for results batch item ' + NN + ': "' + TITLE + '". You write the receipt, run the audit diff, and make the single commit for this item.',
  '',
  COMMON,
  '',
  '=== IMPLEMENTER ===', impl ? JSON.stringify(impl, null, 1) : '(THE IMPLEMENTER AGENT DIED — nothing was implemented by a crew that reported back.)',
  '=== VERIFIER ===', verify ? JSON.stringify(verify, null, 1) : '(THE VERIFIER AGENT DIED — no independent sabotage evidence exists.)',
  '=== REVIEWERS (' + liveReviews.length + ' of 3 returned' + (deadLenses ? ', ' + deadLenses + ' DIED' : '') + ') ===',
  'CONFIRMED findings: ' + JSON.stringify(confirmed.map(c => ({ key: c.key, raisedBy: c.lenses, claims: c.members.map(m => m.claim) })), null, 1),
  'RAISED BUT NOT CONFIRMED: ' + JSON.stringify(unconfirmed.map(c => ({ key: c.key, raisedBy: c.lenses, claims: c.members.map(m => m.claim) })), null, 1),
  'NOT PROVEN (reviewers could not confirm these receipt claims): ' + JSON.stringify(notProven, null, 1),
  '=== FIXER ===', fix ? JSON.stringify(fix, null, 1) : (confirmed.length ? '(there were confirmed findings and the fixer did not return — they are UNFIXED)' : '(no confirmed findings; the Fix stage was skipped, which is the normal path)'),
  '',
  'DO THESE FOUR THINGS:',
  '',
  '1. WRITE THE RECEIPT at ' + RECEIPT + ' . 120 LINES MAXIMUM, exactly these five sections and no others:',
  '   1. Files changed, with line counts (use `git diff --stat` / `git diff --cached --stat`).',
  '   2. Decisions taken, and the evidence for each — including any open question the crew RULED on, where the ruling was written into the spec, and why.',
  '   3. Test name(s), check count, and the VERBATIM RESULT line.',
  '   4. The sabotage table: check id | what was broken | went red? | restored green? — one row per new check (or per red/green drive for a harness item). A check with no row must be listed as unsabotaged, i.e. not evidence.',
  '   5. What was NOT verified — including every reviewer finding that was raised but not confirmed, everything the reviewers marked not-proven, and any eyeball owed.',
  '   Keep it tight. Anything that does not fit belongs in the spec or an issue, not in a longer receipt.',
  '',
  '2. RUN THE AUDIT (tests/headless/full_audit.sh, GUI_GATE=1) and report it as a DIFF against ' + BASELINE + ' by test NAME and STATUS, naming every test that changed in EITHER direction. Never judge by the red count, and never diff against the void ' + VOID_BASELINE + '. If a test went red that is not in the baseline as red, that outranks everything else in this item: fix it or verdict [F] with an issue.',
  '',
  '3. COMMIT. Explicit file list (`git add <path> ...` — never -A, never -a), including the receipt and any spec or issue file you wrote. Conventional-commits style, subject in NORMAL ENGLISH (not caveman, not telegraphic), <= 72 chars, imperative mood; body explains what changed and why, names the checks added and the sabotage evidence, and ends with the Co-Authored-By trailer this repo uses. NEVER `git push` — not now, not after, not with any flag.',
  '   If there is nothing worth committing (implementer died, or the work is not safe to land), commit NOTHING, return commit="" and describe the exact state of the working tree in the receipt. Never `git reset --hard` and never delete another agent\'s work.',
  '',
  '4. RETURN THE VERDICT:',
  '   [x] = done and verified by checks that were sabotaged.',
  '   [E] = done, but the real payload is pixels — a human must look. Use [E] whenever the payload is visual, however many checks passed'
    + ((impl && impl.pixelPayload) || (verify && verify.pixelPayload) ? '. THE CREW ALREADY FLAGGED THIS ITEM AS A PIXEL DELIVERABLE, so [x] is not available unless you can show that flag was wrong.' : '.'),
  '   [D] = deferred. [F] = failed.',
  '   [D] AND [F] BOTH REQUIRE A FILED ISSUE: write doc/claude/issues/NNNN-<kebab-title>.md (next free number, follow the shape of the neighbouring issue files), commit it with the rest, and name the issue file in your `note` and in the `issue` field. A [D] or [F] without a filed issue is not an acceptable outcome.',
  '   `note` is AT MOST 40 WORDS — it is the only prose the driver ever sees. Everything else lives in the receipt.',
  '   Set eyeballNeeded=true for any [E], and for anything else where a human should still look.',
  '',
  'Do NOT edit ' + LEDGER + ' — the driver appends the row.',
].join('\n'), { schema: CLOSE_SCHEMA, phase: 'Commit', label: 'close:' + TAG, effort: 'high' })

// ---------------------------------------------------------------- return
// SMALL object, nothing else. Everything longer is in the receipt.

function words40(s) {
  const w = String(s === undefined || s === null ? '' : s).replace(/\s+/g, ' ').trim().split(' ').filter(x => x.length)
  return w.slice(0, 40).join(' ')
}
function toInt(v, fallback) {
  // null/undefined/'' are MISSING, not zero: Number(null) is 0, which would turn
  // a closer that omitted the field into a silent, plausible-looking "0 checks".
  if (v === undefined || v === null || v === '') return fallback
  const n = Number(v)
  if (!isFinite(n)) return fallback
  return Math.max(0, Math.round(n))
}

const VERDICTS = ['[x]', '[E]', '[D]', '[F]']
const sabRows = (evidence && Array.isArray(evidence.sabotages)) ? evidence.sabotages : []
const sabGood = sabRows.filter(s => s && s.wentRed === true).length
const pixel = !!((impl && impl.pixelPayload) || (verify && verify.pixelPayload))

let verdict = (close && VERDICTS.indexOf(close.verdict) >= 0) ? close.verdict : '[F]'
if (verdict === '[x]' && pixel) verdict = '[E]'          // a pixel payload can never be [x]
if (!impl || !close) verdict = '[F]'                     // a dead crew is a failure, not a pass

let note
if (!close) {
  note = 'Closer agent died: no receipt, no commit, no verdict. Working tree state unknown — inspect git status before relaunching item ' + NN + '.'
} else if (!impl) {
  note = 'Implementer agent died before any work landed. ' + words40(close.note)
} else {
  note = words40(close.note)
  if (confirmed.length && !fix) note = words40('Confirmed findings left unfixed (fixer died). ' + note)
  if (deadLenses) note = words40(note + ' (' + deadLenses + ' reviewer lens died.)')
}

return {
  item: N,
  verdict: verdict,
  commit: (close && typeof close.commit === 'string') ? close.commit : '',
  checks: toInt(close && close.checks, toInt(evidence && evidence.checkCount, 0)),
  sabotages: toInt(close && close.sabotages, sabGood),
  files_changed: toInt(close && close.filesChanged, (impl && Array.isArray(impl.filesTouched)) ? impl.filesTouched.length : 0),
  eyeball_needed: close ? (!!close.eyeballNeeded || verdict === '[E]') : true,
  note: words40(note),
}
