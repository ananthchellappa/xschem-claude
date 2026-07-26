export const meta = {
  name: 'refactor-b-bugfix',
  description: 'One bug-fix batch item: verify bug from source -> gate -> fix+test+sabotage -> adversarial verify -> ledger',
  phases: [
    { title: 'Scout', detail: 'verify bug + scope fix (PROCEED/DEFER)' },
    { title: 'Implement', detail: 'fix, test, sabotage, commit' },
    { title: 'Verify', detail: 'adversarial receipt check, fresh context' },
    { title: 'Ledger', detail: 'BUGFIX_PLAN.md + issue Status + receipt' },
  ],
}

// args = { item: <int 1-5>, issue: '0126', slug: 'apply-properties-scripted-readonly-gap',
//          notes: '<Item detail block from BUGFIX_PLAN.md>' }

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCHDIR = REPO + '/doc/claude/refactor_b_batch'
const PLAN = BATCHDIR + '/BUGFIX_PLAN.md'

const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || !A.item || !A.issue) throw new Error('args {item, issue, slug, notes} required')
const NN = String(A.item)
const ISSUE = A.issue

const DISCIPLINE = [
  'DISCIPLINE (non-negotiable):',
  '- Re-verify EVERY anchor line from source before trusting it; line numbers drift.',
  '- A green suite does not prove the changed code ran: sabotage-verify (each sabotage must fail EXACTLY its target check, then revert, then a clean re-run must be green).',
  '- C89: declarations at block top. my_malloc/my_strdup with _ALLOC_ID_ placeholder.',
  '- Headless tests: each test its own process; relative paths need repo-root cwd.',
  '- Key/gesture tests replay the WHOLE Tk event sequence in the shipping rc profile.',
  '- Git: NEVER git reset --hard, NEVER git add -A / git commit -a, NEVER push. Explicit file lists only. Sabotage revert = targeted git checkout -- <file> after git diff confirms only the sabotage is in it.',
  '- Do not touch junk dirs (_nhangle_* etc.) or anything outside declared scope.',
  '- Memory: per-item detail goes in the auto-memory action-logging.md batch block; MEMORY.md index stays one short line.',
].join('\n')

const SCOUT_SCHEMA = {
  type: 'object', required: ['verdict', 'reasons'],
  properties: {
    verdict: { enum: ['PROCEED', 'DEFER'] },
    reasons: { type: 'array', items: { type: 'string' } },
    promptPath: { type: 'string' },
    scopeNote: { type: 'string' },
  },
}

const IMPL_SCHEMA = {
  type: 'object', required: ['commit', 'testFile', 'checksTotal', 'sabotage', 'nonBaselineFails', 'summary'],
  properties: {
    commit: { type: 'string' },
    testFile: { type: 'string' },
    checksTotal: { type: 'integer' },
    sabotage: { type: 'array', items: { type: 'object', required: ['name', 'target', 'failedExactly'],
      properties: { name: {type:'string'}, target: {type:'string'}, failedExactly: {type:'boolean'} } } },
    nonBaselineFails: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}

const VERIFY_SCHEMA = {
  type: 'object', required: ['ok', 'problems'],
  properties: { ok: { type: 'boolean' }, problems: { type: 'array', items: { type: 'string' } } },
}

const issueGlob = REPO + '/doc/claude/issues/' + ISSUE + '-' + (A.slug || '') + '.md'
const PROMPT_PATH = BATCHDIR + '/prompts/bugfix_' + ISSUE + '.md'

phase('Scout')
const scout = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. Scout/gate stage for bug-fix batch item ' + NN + ' = issue ' + ISSUE + '.',
  'READ FIRST: (1) the issue file ' + issueGlob + ' (grep doc/claude/issues/ for "' + ISSUE + '-" if the exact name differs); (2) the batch receipt it cites under ' + BATCHDIR + '/receipts/; (3) the plan notes below.',
  'Plan notes (claims to RE-VERIFY from source, not trust):',
  A.notes || '(none)',
  'Do a fresh source verification of every cited site (lines have drifted before). Decide the EXACT fix scope: files, edits, behavior deltas, consumers checked. The scout may NARROW scope (fix the safe part, record the residual in the issue file at implement time) - say so in scopeNote.',
  'VERDICT: DEFER only if the issue is not actually a bug (refuted from source), or every safe fix shape trips a defer trigger in the notes. Otherwise PROCEED.',
  'IF PROCEED write ONE file: ' + PROMPT_PATH + ' - a self-contained implementation prompt: ANCHORS you verified today; exact EDITS; TEST plan (new headless test file OR extension of an existing one - name it; checks incl. the regression the bug caused, the unchanged-behavior control, and readonly/undo controls as applicable) with named sabotages each targeting exactly one check; full_audit + baseline-fails note (baseline list = PLAN.md header, 14 tests); docs step (issue Status -> FIXED + what changed, memory update per discipline); commit message "fix(<area>): <what> (issue ' + ISSUE + ')" ending with the Co-Authored-By trailer.',
  'IF DEFER write nothing.',
  DISCIPLINE,
  'Return ONLY via the structured output tool.',
].join('\n'), { label: 'scout:' + ISSUE, schema: SCOUT_SCHEMA })
if (!scout) throw new Error('scout failed for ' + ISSUE)
log('scout ' + ISSUE + ': ' + scout.verdict + (scout.scopeNote ? ' (' + scout.scopeNote.slice(0, 120) + ')' : ''))

async function ledger(status, detailLines) {
  return agent([
    'Repo: ' + REPO + '. Edit TWO files and write ONE file; touch nothing else.',
    '1. ' + PLAN + ': find the ledger line starting "- [ ] ' + NN + ' issue-' + ISSUE + '"; set its checkbox to ' +
      (status === 'DONE' ? '[x] and append " -> FIXED <commit>".' : status === 'DEFERRED' ? '[D] and append " -> DEFERRED: <primary reason>".' : '[F] and append " -> FAILED: <primary problem>".'),
    '   Also fill the matching "receipt:" line in its Item detail section.',
    '2. The issue file (grep doc/claude/issues/ for "' + ISSUE + '-"): ' +
      (status === 'DONE' ? 'ensure Status says FIXED with the commit hash (the implementer should have done it - fix if missing).' : 'append a dated note with the ' + status + ' reasons.'),
    '3. Write ' + BATCHDIR + '/receipts/bugfix_' + ISSUE + '.md with:',
    detailLines,
  ].join('\n'), { label: 'ledger:' + ISSUE, phase: 'Ledger', effort: 'low' })
}

if (scout.verdict === 'DEFER') {
  await ledger('DEFERRED', 'Item ' + NN + ' issue ' + ISSUE + ' - DEFERRED at scout stage.\nreasons:\n- ' + scout.reasons.join('\n- '))
  return { status: 'DEFERRED', item: A.item, issue: ISSUE, reasons: scout.reasons }
}

phase('Implement')
const impl = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You implement the fix for issue ' + ISSUE + ' (bug-fix batch item ' + NN + ').',
  'Execute the prompt at ' + (scout.promptPath || PROMPT_PATH) + ' EXACTLY: edits, build (cd src && make), tests (register any NEW test file in tests/headless/full_audit.sh logdir_tests), every named sabotage (fail exactly its target, revert, clean re-run green), full_audit once before commit, issue-file Status update, memory update, COMMIT (explicit file list, message per prompt + trailer).',
  'Baseline full_audit fails: the 14-test list in ' + BATCHDIR + '/PLAN.md header - those are NOT yours.',
  DISCIPLINE,
  'CRASH RECOVERY: if the tree already has uncommitted edits for this fix, verify+complete them, do not blindly re-apply.',
  'ECONOMY: full_audit at most TWICE; trim Bash output; do not re-read large docs.',
  'If blocked beyond prompt scope: revert your edits (targeted checkout), NO commit, return commit="NONE" with the blocker in summary.',
  'FINAL STEP (never skip): the structured output receipt.',
].join('\n'), { label: 'implement:' + ISSUE, schema: IMPL_SCHEMA })
if (!impl) throw new Error('implement failed for ' + ISSUE)
if (impl.commit === 'NONE') {
  await ledger('FAILED', 'Item ' + NN + ' issue ' + ISSUE + ' - implementation aborted, no commit.\n' + impl.summary)
  return { status: 'FAILED', item: A.item, issue: ISSUE, problems: [impl.summary] }
}
log('implemented ' + ISSUE + ': ' + impl.commit + ', ' + impl.checksTotal + ' checks')

phase('Verify')
const vPrompt = function (claims) {
  return [
    'Repo: ' + REPO + ', branch fluid-editing. ADVERSARIAL verifier for the issue-' + ISSUE + ' fix. Trust nothing below; re-establish each fact.',
    'Claims: ' + JSON.stringify(claims),
    '1. git show --stat <commit>: exists, touches ONLY in-scope files (src + tests + the issue file + memory is OK; flag anything else).',
    '2. Run the named test yourself, fresh, from repo root. Green.',
    '3. Run tests/headless/full_audit.sh; fail list must equal the 14-test baseline in ' + BATCHDIR + '/PLAN.md header.',
    '4. The BUG is actually fixed: reproduce the original symptom scenario from the issue file against the built binary and confirm the new behavior (not just that the test passes).',
    '5. Issue file Status says FIXED with the commit.',
    'Return ONLY via the structured output tool: ok, problems.',
  ].join('\n')
}
let verdict = await agent(vPrompt(impl), { label: 'verify:' + ISSUE, schema: VERIFY_SCHEMA })
if (verdict && !verdict.ok) {
  log('verify found ' + verdict.problems.length + ' problems - one repair attempt')
  const repair = await agent([
    'Repo: ' + REPO + '. Repair the issue-' + ISSUE + ' fix (commit ' + impl.commit + '). Problems:',
    '- ' + verdict.problems.join('\n- '),
    'Fix at issue scope; fixup commit "fixup: issue ' + ISSUE + ' - <what>" + trailer; re-run the test + full_audit first.',
    DISCIPLINE,
  ].join('\n'), { label: 'repair:' + ISSUE, phase: 'Verify' })
  verdict = await agent(vPrompt(Object.assign({}, impl, { repairNote: String(repair).slice(0, 1500) })), { label: 're-verify:' + ISSUE, phase: 'Verify', schema: VERIFY_SCHEMA })
}

const receipt = 'Item ' + NN + ' issue ' + ISSUE + '.\ncommit: ' + impl.commit + '\ntest: ' + impl.testFile + ' (' + impl.checksTotal + ' checks)\nsabotage: ' + JSON.stringify(impl.sabotage) + '\nnon-baseline fails: ' + JSON.stringify(impl.nonBaselineFails) + '\nscout scope: ' + (scout.scopeNote || '(full)') + '\nverifier: ' + (verdict ? (verdict.ok ? 'OK' : 'PROBLEMS: ' + verdict.problems.join('; ')) : 'verifier failed') + '\nsummary: ' + impl.summary

if (!verdict || !verdict.ok) {
  await ledger('FAILED', receipt)
  return { status: 'FAILED', item: A.item, issue: ISSUE, commit: impl.commit, problems: verdict ? verdict.problems : ['verifier failed twice'] }
}

phase('Ledger')
await ledger('DONE', receipt)
return { status: 'DONE', item: A.item, issue: ISSUE, commit: impl.commit, checks: impl.checksTotal }
