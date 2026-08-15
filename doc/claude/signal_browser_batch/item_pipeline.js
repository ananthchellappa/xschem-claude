export const meta = {
  name: 'signal-browser-item',
  description: 'One Signal Browser batch item: scout -> gate -> implement -> adversarial verify -> ledger',
  phases: [
    { title: 'Scout', detail: 'verify anchors from source, verdict PROCEED/DEFER' },
    { title: 'Implement', detail: 'build + test + sabotage-verify + commit' },
    { title: 'Verify', detail: 'adversarial re-check in a fresh context' },
    { title: 'Repair', detail: 'one repair attempt when verify fails' },
    { title: 'Ledger', detail: 'PLAN.md line + receipts/NN_*.md' },
  ],
}

// Invoked by the batch driver (DRIVER_PROMPT.md), one call per plan item.
// args = {
//   item:      <int>     ledger line number 0..14
//   title:     <string>  the ledger line title
//   notes:     <string>  the FULL item section pasted verbatim from PLAN.md
//   decisions: <string>  the FULL "Settled design decisions" section, verbatim
//   pixel:     <bool>    true when the heading says PIXEL (verdict [E], never [x])
//   baseline:  <string>  the baseline fail list from the PLAN.md header
// }

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCHDIR = REPO + '/doc/claude/signal_browser_batch'
const PLAN = BATCHDIR + '/PLAN.md'

const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || A.item === undefined || !A.title) throw new Error('args {item, title, notes, decisions, pixel, baseline} required')
const NN = String(A.item).length < 2 ? '0' + String(A.item) : String(A.item)
const PIXEL = !!A.pixel
const RECEIPT = BATCHDIR + '/receipts/' + NN + '_receipt.md'

const DISCIPLINE = [
  'DISCIPLINE (non-negotiable):',
  '- Re-verify EVERY anchor line from source before trusting it. The PLAN cites line numbers; they drift, and at least one citation in the source research was already wrong.',
  '- A green suite does not prove the changed code ran. Sabotage-verify: each named sabotage must fail EXACTLY its target check and nothing else, then be reverted, then a clean re-run must be green.',
  '- Revert a sabotage with a targeted `git checkout -- <file>` ONLY after `git diff` confirms that file holds nothing but the sabotage.',
  '- Git: NEVER `git reset --hard`, NEVER `git add -A` / `git commit -a`, NEVER `git push`. Stage an explicit file list only.',
  '- Tcl 9 is in play: count out-params are Tcl_Size*, and a relative `ns::var` resolves in-namespace (TIP 278). This batch is Tcl-only per decision 8 — if you conclude you need C, that is a DEFER, not a C patch.',
  '- Headless tests: each test is its own process; relative paths need repo-root cwd; a script error IDLES rather than hangs; a Tcl error inside an `after` handler pops bgerror and hangs, so override bgerror in every probe.',
  '- Key/gesture tests must replay the WHOLE Tk event sequence in the shipping rc profile (gesture-test-full-sequence lesson). A bare `event generate` drops keys ~1-in-5 under WSLg.',
  '- Run suites through tests/headless/run_suites.sh or gated_xschem.sh — never a bare for-loop over ./src/xschem, which enrols in no GUI gate.',
  '- NEVER run `make` while a suite is running.',
  '- Use tests/from_user/ or a test_scratch dir for scratch files; do not leave droppings in the repo.',
  '- Known flakes that are NOT regressions: TG9 root-coords (4-in-10 on a pristine tree), test_ase_plot P4/P6/P8 (1-2/10), bare event-generate key delivery. Re-run before calling one a fail.',
].join('\n')

const CONTEXT = [
  '=== SETTLED DESIGN DECISIONS (binding; you may not silently substitute your own) ===',
  A.decisions || '(driver passed none — read the "Settled design decisions" section of ' + PLAN + ')',
  '',
  '=== THIS ITEM, VERBATIM FROM THE PLAN ===',
  A.notes || '(driver passed none — read item ' + NN + ' in ' + PLAN + ')',
  '',
  '=== BASELINE FAILS (anything outside this list is YOUR problem) ===',
  A.baseline || '(driver passed none — read the Baseline block in ' + PLAN + ')',
].join('\n')

const SCOUT_SCHEMA = {
  type: 'object',
  required: ['verdict', 'reasons', 'anchors'],
  additionalProperties: false,
  properties: {
    verdict: { enum: ['PROCEED', 'DEFER'] },
    reasons: { type: 'array', items: { type: 'string' } },
    anchors: {
      type: 'array',
      description: 'every PLAN-cited anchor, re-checked against source',
      items: {
        type: 'object', required: ['cited', 'actual', 'ok'], additionalProperties: false,
        properties: { cited: { type: 'string' }, actual: { type: 'string' }, ok: { type: 'boolean' } },
      },
    },
    scopeFiles: { type: 'array', items: { type: 'string' } },
    plan: { type: 'string', description: 'the concrete implementation plan the next stage executes' },
    risks: { type: 'array', items: { type: 'string' } },
  },
}

const IMPL_SCHEMA = {
  type: 'object',
  required: ['commit', 'filesTouched', 'testFile', 'checksAdded', 'checksTotal', 'sabotage', 'nonBaselineFails', 'summary'],
  additionalProperties: false,
  properties: {
    commit: { type: 'string' },
    filesTouched: { type: 'array', items: { type: 'string' } },
    testFile: { type: 'string' },
    checksAdded: { type: 'integer' },
    checksTotal: { type: 'integer' },
    sabotage: {
      type: 'array',
      items: {
        type: 'object', required: ['name', 'target', 'failedExactly', 'reverted'], additionalProperties: false,
        properties: {
          name: { type: 'string' }, target: { type: 'string' },
          failedExactly: { type: 'boolean' }, reverted: { type: 'boolean' },
          note: { type: 'string' },
        },
      },
    },
    nonBaselineFails: { type: 'array', items: { type: 'string' } },
    divergences: { type: 'array', items: { type: 'string' }, description: 'anything done differently from the PLAN, with why' },
    summary: { type: 'string' },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['ok', 'problems', 'reran'],
  additionalProperties: false,
  properties: {
    ok: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' } },
    reran: { type: 'array', items: { type: 'string' }, description: 'what the verifier ran ITSELF, not what it was told' },
    scopeClean: { type: 'boolean' },
  },
}

// ---------------------------------------------------------------- Scout

phase('Scout')
const scout = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the SCOUT stage for Signal Browser batch item ' + NN + ': "' + A.title + '".',
  '',
  'Your job is a VERDICT and a plan, not an implementation. Write no code, edit no files.',
  '',
  CONTEXT,
  '',
  'Do this:',
  '1. Re-verify every line-number anchor the item section cites, against current source. Report cited vs actual for each. An anchor that moved is fine; an anchor that does not exist at all is a DEFER signal.',
  '2. Confirm the item is achievable in Tcl only (decision 8). If it needs a new scheduler.c branch or any C change, verdict DEFER and say exactly what C surface is missing.',
  '3. Confirm the item does not require overturning a settled design decision. If it does, verdict DEFER and name the decision.',
  '4. Check for prior art in the repo you would be duplicating (grep first — this codebase repeatedly turns out to already have the primitive).',
  '5. Produce a concrete implementation plan: exact procs to add or change, exact widget paths, exact check names for the test file, and how each named sabotage will be injected.',
  '',
  'DEFER is a SUCCESS outcome. Do not force a PROCEED on an item whose premise you just disproved.',
  '',
  DISCIPLINE,
].join('\n'), { schema: SCOUT_SCHEMA, phase: 'Scout', label: 'scout:' + NN })

// A DEAD AGENT IS NOT A VERDICT. agent() returns null when the subagent dies on a
// terminal API error (e.g. "Connection closed mid-response") or when the user skips it.
// Item 8 hit exactly this and the pipeline wrote `[D] DEFERRED: the scout returned
// nothing` into the ledger -- an infrastructure failure wearing the costume of a
// considered engineering judgement, which is the worst kind of wrong entry in a file
// whose whole job is to be trusted later. Fail loudly instead: touch NO ledger line,
// write NO receipt, and let the driver re-launch. A DEFER must come from a scout that
// actually looked at the code and said no.
if (!scout) {
  log('item ' + NN + ': scout agent DIED (null result) -- not a defer. Ledger untouched.')
  return {
    item: A.item,
    verdict: 'INFRA_FAILURE',
    stage: 'scout',
    ledgerTouched: false,
    note: 'scout agent returned null (terminal API error or skipped). This is NOT a DEFER '
        + 'verdict and NOTHING was written to PLAN.md or receipts/. Re-launch the item.',
  }
}

if (scout.verdict !== 'PROCEED') {
  const reasons = scout.reasons
  phase('Ledger')
  await agent([
    'Repo: ' + REPO + '. Ledger stage for Signal Browser batch item ' + NN + ' ("' + A.title + '"), verdict DEFERRED.',
    '',
    'Do exactly two things, and nothing else:',
    '1. In ' + PLAN + ', change the item ' + NN + ' ledger line from "- [ ]" to "- [D]" and append " -> DEFERRED: <one-sentence reason>" to that line. Do not reflow or reformat the rest of the file.',
    '2. Write ' + RECEIPT + ' with: the verdict, the full reason list, the anchor check table, and any pattern-unlock proposal the scout made.',
    '',
    'Reasons from the scout:',
    JSON.stringify(reasons, null, 1),
    'Anchor checks:',
    JSON.stringify(scout.anchors, null, 1),
    '',
    'Do NOT commit. Do NOT touch src/ or tests/.',
  ].join('\n'), { phase: 'Ledger', label: 'ledger:' + NN })
  return { item: A.item, verdict: 'DEFERRED', reasons: reasons, receipt: RECEIPT }
}

// ---------------------------------------------------------------- Implement

phase('Implement')
const impl = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the IMPLEMENTER for Signal Browser batch item ' + NN + ': "' + A.title + '".',
  '',
  CONTEXT,
  '',
  '=== THE SCOUT VERIFIED THESE ANCHORS AND WROTE THIS PLAN ===',
  JSON.stringify(scout.anchors, null, 1),
  '',
  scout.plan || '(scout returned no plan text — follow the item section)',
  '',
  'Risks the scout flagged:',
  JSON.stringify(scout.risks || [], null, 1),
  '',
  'Execute end to end:',
  '1. Implement the item. Stay inside the scope files the item names. Do not opportunistically fix neighbouring code.',
  '2. `cd src && make` green.',
  '3. Write/extend the item test file. Every check gets a distinct printed name so a sabotage can be attributed to exactly one.',
  '4. Run the item test file, then the FULL headless suite through tests/headless/run_suites.sh. Compare against the baseline list; any new fail is yours to fix before proceeding.',
  '5. Sabotage-verify every sabotage the item names. For each: inject, run, confirm it fails EXACTLY its target check and nothing else, `git diff` to confirm the file holds only the sabotage, `git checkout -- <file>`, re-run clean and green. Record each one.',
  '6. Commit. Explicit file list. Message: a conventional-commits subject <=50 chars, a body only where the "why" is not obvious, ending with the item line and the Co-Authored-By trailer. Do NOT push.',
  '',
  'If you cannot make it green: do NOT commit a broken state. Return with nonBaselineFails populated and say what blocked you. A truthful failure is worth more than a green lie.',
  '',
  DISCIPLINE,
].join('\n'), { schema: IMPL_SCHEMA, phase: 'Implement', label: 'impl:' + NN, effort: 'high' })

// ---------------------------------------------------------------- Verify

phase('Verify')
let verify = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the ADVERSARIAL VERIFIER for Signal Browser batch item ' + NN + ': "' + A.title + '".',
  '',
  'You did not write this code and you trust none of the claims below. Your default posture is that the receipt is optimistic.',
  '',
  '=== THE IMPLEMENTER CLAIMS ===',
  JSON.stringify(impl, null, 1),
  '',
  CONTEXT,
  '',
  'Verify by DOING, not by reading the claim:',
  '1. `git show --stat ' + (impl && impl.commit ? impl.commit : 'HEAD') + '` — does the commit touch ONLY the files the item scoped? Anything else is a scope leak; report it.',
  '2. Run the item test file yourself. Count the checks. Does the count match the claim?',
  '3. Run the full headless suite yourself through run_suites.sh. Diff the fail list against the baseline. A claimed-empty nonBaselineFails that is not empty is the single most important thing you can catch.',
  '4. Re-inject ONE sabotage of your own choosing that the implementer did NOT name, aimed at the item core. It must fail a check. If the suite stays green under your sabotage, the tests do not actually cover the feature — that is a FAIL regardless of how many checks passed.',
  '5. Read the new test code: does any check assert a tautology, or assert on a value it computed itself rather than on program behaviour?',
  '6. Check the divergences list. A divergence from a settled decision that was not flagged is a FAIL.',
  '',
  'Report ok=false with specific problems, or ok=true. Do not repair anything yourself.',
  '',
  DISCIPLINE,
].join('\n'), { schema: VERIFY_SCHEMA, phase: 'Verify', label: 'verify:' + NN, effort: 'high' })

// ---------------------------------------------------------------- Repair (one attempt)

let repaired = null
if (verify && verify.ok === false) {
  phase('Repair')
  repaired = await agent([
    'Repo: ' + REPO + ', branch fluid-editing. ONE repair attempt on Signal Browser batch item ' + NN + ': "' + A.title + '".',
    '',
    'The adversarial verifier rejected the item. Problems:',
    JSON.stringify(verify.problems, null, 1),
    '',
    'What the verifier actually ran:',
    JSON.stringify(verify.reran || [], null, 1),
    '',
    CONTEXT,
    '',
    'Fix exactly those problems. Do not expand scope. Rebuild, re-run the item test and the full suite, re-run the sabotages, and commit a FIXUP commit (explicit file list, no push).',
    'If a problem is not actually a problem, say so with evidence rather than changing code to satisfy it.',
    '',
    DISCIPLINE,
  ].join('\n'), { schema: IMPL_SCHEMA, phase: 'Repair', label: 'repair:' + NN, effort: 'high' })

  phase('Verify')
  verify = await agent([
    'Repo: ' + REPO + '. RE-VERIFY Signal Browser batch item ' + NN + ' after one repair attempt.',
    '',
    'Original problems:', JSON.stringify(verify.problems, null, 1),
    '', 'Repair claims:', JSON.stringify(repaired, null, 1),
    '', CONTEXT,
    '',
    'Same rules as before: run everything yourself, including your own unnamed sabotage. This is the last gate — if it is not right now, the item is marked FAILED and a human looks at it.',
    '', DISCIPLINE,
  ].join('\n'), { schema: VERIFY_SCHEMA, phase: 'Verify', label: 'reverify:' + NN, effort: 'high' })
}

// ---------------------------------------------------------------- Ledger

const passed = !!(verify && verify.ok)
const mark = passed ? (PIXEL ? '[E]' : '[x]') : '[F]'
const verdict = passed ? (PIXEL ? 'DONE-PIXEL' : 'DONE') : 'FAILED'
const finalImpl = repaired || impl

phase('Ledger')
await agent([
  'Repo: ' + REPO + '. Ledger stage for Signal Browser batch item ' + NN + ' ("' + A.title + '"). Verdict: ' + verdict + '.',
  '',
  'Do exactly these, and nothing else. Touch no file outside ' + BATCHDIR + '.',
  '',
  '1. In ' + PLAN + ', change the item ' + NN + ' ledger line from "- [ ]" to "- ' + mark + '" and append " -> ' + verdict + ' (<commit>)" to that line.' +
    (passed && PIXEL ? ' Because this is a PIXEL item the mark is [E], NOT [x] — the deliverable is visible UI that no test can judge.' : '') +
    (passed ? '' : ' Append the failure reason to the line.'),
  (passed && PIXEL)
    ? '2. Add a row to the "Eyeball queue" table in ' + PLAN + ': item number, commit hash, the "Eyeball:" line from the item section, and an empty Eyeballed? cell.'
    : '2. (no eyeball-queue row for this item)',
  '3. Write ' + RECEIPT + ' containing: verdict; commit hash(es); files touched; test file and check counts (added / total); the sabotage table with failedExactly and reverted per row; the verifier\'s own unnamed sabotage and its outcome; non-baseline fails; every divergence from the PLAN with its reason; and — when FAILED — exactly what a human needs to look at first.',
  '',
  'Implementer result:', JSON.stringify(finalImpl, null, 1),
  '', 'Verifier result:', JSON.stringify(verify, null, 1),
  '', 'Scout anchors:', JSON.stringify(scout.anchors, null, 1),
  '',
  'Do NOT commit. Do NOT touch src/ or tests/. Do NOT reflow the rest of PLAN.md.',
].join('\n'), { phase: 'Ledger', label: 'ledger:' + NN })

return {
  item: A.item,
  title: A.title,
  verdict: verdict,
  mark: mark,
  commit: finalImpl ? finalImpl.commit : null,
  problems: passed ? [] : (verify ? verify.problems : ['verify agent returned nothing']),
  receipt: RECEIPT,
}
