export const meta = {
  name: 'ase-l-item',
  description: 'One ASE-L batch item: scout anchors -> implement -> 3-lens adversarial verify -> fix loop -> ledger',
  phases: [
    { title: 'Scout', detail: 'anchor re-verify + implementation prompt authoring' },
    { title: 'Implement', detail: 'code + tests + sabotage-verify + one commit' },
    { title: 'Verify', detail: 'hygiene / tests / spec lenses, parallel, adversarial' },
    { title: 'Fix', detail: 'repair loop, max 2 rounds' },
    { title: 'Ledger', detail: 'PLAN.md ledger line + receipt' },
  ],
}

// Driver invokes once per PLAN.md ledger item, strictly sequential.
// args = {
//   item: <int 1..4>, slug: '<ase-core|view-dispatch|ase-window|proof-final>',
//   notes: '<the full "Item detail" section pasted from PLAN.md>',
//   baselineFails: '<the preflight baseline full_audit fail list, verbatim>'
// }

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCH = REPO + '/doc/claude/ase_l_batch'
const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || !A.item || !A.slug || !A.notes) throw new Error('args {item, slug, notes, baselineFails} required')
const NN = String(A.item).length < 2 ? '0' + String(A.item) : String(A.item)
const PROMPT_PATH = BATCH + '/prompts/item' + NN + '_' + A.slug + '.md'
const RECEIPT_PATH = BATCH + '/receipts/' + NN + '_' + A.slug + '.md'
const BASELINE = A.baselineFails || '(none recorded)'

const COMMON = [
  'Repo: ' + REPO + ', branch fluid-editing. ASE-L mini-batch item ' + NN + ' (' + A.slug + ').',
  'READ FIRST (in order): ' + BATCH + '/RUNBOOK.md (policies are non-negotiable), the spec ' +
    REPO + '/doc/claude/specs/ase_l.md, and this item detail from PLAN.md:',
  '--- ITEM DETAIL START ---',
  A.notes,
  '--- ITEM DETAIL END ---',
  'Baseline full_audit fail list at batch start (pre-existing, NOT yours to fix, and the ONLY tolerated fails): ' + BASELINE,
  'Pre-existing dirty tracked files are listed in PLAN.md preflight — NEVER stage them.',
].join('\n')

const SCOUT_SCHEMA = {
  type: 'object', required: ['verdict', 'promptPath', 'anchorsVerified', 'notes'],
  properties: {
    verdict: { enum: ['PROCEED', 'BLOCKED'] },
    promptPath: { type: 'string' },
    anchorsVerified: { type: 'boolean' },
    notes: { type: 'array', items: { type: 'string' } },
  },
}
const IMPL_SCHEMA = {
  type: 'object', required: ['commit', 'testFile', 'checksTotal', 'sabotage', 'nonBaselineFails', 'filesCommitted', 'summary'],
  properties: {
    commit: { type: 'string' },
    testFile: { type: 'string' },
    checksTotal: { type: 'integer' },
    sabotage: { type: 'array', items: { type: 'object', required: ['name', 'target', 'failedExactly'],
      properties: { name: { type: 'string' }, target: { type: 'string' }, failedExactly: { type: 'boolean' } } } },
    nonBaselineFails: { type: 'array', items: { type: 'string' } },
    filesCommitted: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}
const VERIFY_SCHEMA = {
  type: 'object', required: ['ok', 'problems'],
  properties: { ok: { type: 'boolean' }, problems: { type: 'array', items: { type: 'string' } } },
}

phase('Scout')
const scout = await agent([
  COMMON,
  'You are the SCOUT. Do not implement anything. Tasks:',
  '1. Re-verify from source EVERY file:line anchor named in the item detail and the spec sections it cites (lines drift; record the true current lines).',
  '2. Resolve every "scout decides/verifies" micro-decision in the item detail; make the call and justify in one line each.',
  '3. Write the COMPLETE implementation prompt to ' + PROMPT_PATH + ' (Write tool): scope, corrected anchors, decisions, exact deliverables, test list with named checks, sabotage plan, explicit commit file list, and the RUNBOOK policy block copied in verbatim.',
  '4. Verdict PROCEED unless code reality CONTRADICTS the spec in a way the prompt cannot honestly bridge — then BLOCKED with reasons.',
  'Return via StructuredOutput.',
].join('\n'), { label: 'scout:' + A.slug, phase: 'Scout', schema: SCOUT_SCHEMA })

if (!scout) return { verdict: 'FAILED', stage: 'scout', reason: 'scout agent died' }
if (scout.verdict === 'BLOCKED') return { verdict: 'BLOCKED', stage: 'scout', reasons: scout.notes }

phase('Implement')
const impl = await agent([
  COMMON,
  'You are the IMPLEMENTER. Execute the implementation prompt at ' + (scout.promptPath || PROMPT_PATH) + ' end-to-end:',
  '- Code + tests exactly as prompted (deviations allowed only when reality forces them — record each in the summary).',
  '- Sabotage-verify per RUNBOOK (each sabotage fails EXACTLY its target check, targeted revert, clean re-run green).',
  '- Run tests/headless/full_audit.sh; ONLY the baseline fails may remain.',
  '- ONE commit, explicit file list (git add <files>), message per repo convention with the Co-Authored-By trailer. NEVER stage pre-existing dirty files. NEVER push.',
  'Return via StructuredOutput (filesCommitted = exactly what you staged).',
].join('\n'), { label: 'impl:' + A.slug, phase: 'Implement', schema: IMPL_SCHEMA })

if (!impl) return { verdict: 'FAILED', stage: 'implement', reason: 'implement agent died' }

const LENSES = [
  { key: 'hygiene', prompt: 'Lens HYGIENE: inspect commit ' + impl.commit + ' (git show --stat + full diff). REFUTE on: any pre-batch dirty tracked file staged (list in PLAN.md preflight); junk dirs touched; files outside the prompt commit list; generated files hand-edited; style violations (TIP-278, C89 if C touched, ciw_echo policy); tests/run_regression.tcl touched.' },
  { key: 'tests', prompt: 'Lens TESTS: re-run the item test file fresh from repo root AND tests/headless/full_audit.sh; compare fails against the baseline list. Re-execute ONE claimed sabotage from scratch (apply, observe the exact target check fail, targeted revert, green re-run). REFUTE on any non-baseline fail, any sabotage that does not behave as claimed, or checks that cannot fail (green-but-hollow).' },
  { key: 'spec', prompt: 'Lens SPEC: read doc/claude/specs/ase_l.md + the item prompt at ' + PROMPT_PATH + ' + the item detail. Diff promised deliverables vs what commit ' + impl.commit + ' actually contains, by reading the landed code (not the summary). REFUTE on missing behaviors, silent scope cuts, contract drift (e.g. ase::open_state name, state schema keys, backend seam leaks).' },
]

async function runVerify(round) {
  return await parallel(LENSES.map(l => () =>
    agent([
      COMMON,
      'You are an ADVERSARIAL VERIFIER (round ' + round + '). Default to refuting; ok=true only when you actively failed to find a problem.',
      l.prompt,
      'Implementer claims: ' + JSON.stringify(impl),
      'Return via StructuredOutput: ok + concrete problems (file:line, command output quotes).',
    ].join('\n'), { label: 'verify:' + l.key + ':r' + round, phase: 'Verify', schema: VERIFY_SCHEMA })
  ))
}

phase('Verify')
let problems = []
let verdicts = await runVerify(1)
problems = verdicts.filter(Boolean).flatMap(v => v.ok ? [] : v.problems)
if (verdicts.some(v => !v)) problems.push('a verifier lens died — treat as unverified')

let fixRound = 0
while (problems.length && fixRound < 2) {
  fixRound++
  phase('Fix')
  const fix = await agent([
    COMMON,
    'You are the FIXER (round ' + fixRound + '). Verified problems to repair on top of commit ' + impl.commit + ':',
    problems.map((p, i) => (i + 1) + '. ' + p).join('\n'),
    'Fix with FIXUP commit(s) (explicit file lists, same policies; do NOT amend or rebase). Re-run the item tests + sabotage where the fix touches them. Return via StructuredOutput: summary=fixup commit hash(es) + what changed.',
  ].join('\n'), { label: 'fix:r' + fixRound, phase: 'Fix', schema: { type: 'object', required: ['summary'], properties: { summary: { type: 'string' } } } })
  if (!fix) return { verdict: 'FAILED', stage: 'fix', reason: 'fixer died', problems: problems }
  verdicts = await runVerify(1 + fixRound)
  problems = verdicts.filter(Boolean).flatMap(v => v.ok ? [] : v.problems)
  if (verdicts.some(v => !v)) problems.push('a verifier lens died — treat as unverified')
}

const finalVerdict = problems.length ? 'FAILED' : 'DONE'

phase('Ledger')
const ledger = await agent([
  COMMON,
  'You are the LEDGER agent. Item verdict: ' + finalVerdict + '.',
  'Implementer result: ' + JSON.stringify(impl),
  'Outstanding problems (empty means verified clean): ' + JSON.stringify(problems),
  '1. Edit ' + BATCH + '/PLAN.md: flip THIS item\'s ledger line to ' + (finalVerdict === 'DONE' ? '"[x]"' : '"[F]"') + ' and append " -> <commit short hash> <one-clause outcome>".',
  '2. Write ' + RECEIPT_PATH + ': what landed, commit(s), test file + check count, sabotage table, fix-round history, outstanding problems, corrected anchors worth keeping.',
  'Commit NOTHING. Return via StructuredOutput.',
].join('\n'), { label: 'ledger:' + A.slug, phase: 'Ledger', schema: { type: 'object', required: ['ok'], properties: { ok: { type: 'boolean' } } } })

return {
  verdict: finalVerdict,
  item: A.item, slug: A.slug,
  commit: impl.commit, testFile: impl.testFile, checksTotal: impl.checksTotal,
  fixRounds: fixRound, problems: problems,
  ledgerOk: !!(ledger && ledger.ok),
}
