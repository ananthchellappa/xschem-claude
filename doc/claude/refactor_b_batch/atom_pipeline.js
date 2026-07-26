export const meta = {
  name: 'refactor-b-atom',
  description: 'One Refactor B batch item: fresh-scout friction test -> gate -> implement -> adversarial verify -> ledger',
  phases: [
    { title: 'Scout', detail: 'fresh-scout + friction verdict (PROCEED/DEFER)' },
    { title: 'Implement', detail: 'execute the generated atom prompt end-to-end' },
    { title: 'Verify', detail: 'adversarial receipt check in a fresh context' },
    { title: 'Ledger', detail: 'PLAN.md + receipts update' },
  ],
}

// Invoked by the batch driver (see DRIVER_PROMPT.md), one call per plan item.
// args = {
//   item:      <int>  rank number in PLAN.md (ledger line "NN")
//   verb:      <string>
//   atom:      <int>  atom number to use IF the verdict is PROCEED (driver computes 26 + count of prior [x])
//   notes:     <string> the full "Item detail" section for this verb, pasted from PLAN.md
//   prescoped: <bool>  true when a decision doc already exists (e.g. item 1 check_unique_names)
//   decisionDoc: <string> existing decision-doc path when prescoped, else ''
// }

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCHDIR = REPO + '/doc/claude/refactor_b_batch'
const PLAN = BATCHDIR + '/PLAN.md'

const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || !A.verb || !A.item || !A.atom) throw new Error('args {item, verb, atom, notes} required')
const VERB = A.verb
const NN = String(A.item).length < 2 ? '0' + String(A.item) : String(A.item)
const ATOM = String(A.atom)
const PROMPT_PATH = BATCHDIR + '/prompts/atom' + ATOM + '_' + VERB + '.md'
const DECISION_PATH = A.prescoped && A.decisionDoc ? A.decisionDoc
  : REPO + '/doc/claude/code_analysis/perform_action_atom' + ATOM + '_' + VERB + '_decision.md'

const DISCIPLINE = [
  'DISCIPLINE (non-negotiable):',
  '- Re-verify EVERY anchor line from source before trusting it; line numbers drift.',
  '- A green suite does not prove the changed code ran: sabotage-verify (each sabotage must fail EXACTLY its target test, then revert, then a clean re-run must be green).',
  '- C89: declarations at block top. Allocations use my_malloc/my_strdup with the _ALLOC_ID_ placeholder (never hand-number).',
  '- Headless tests: each test is its own process; relative paths need repo-root cwd; a script error idles rather than hangs.',
  '- Key/gesture tests replay the WHOLE Tk event sequence in the shipping rc profile (gesture-test-full-sequence lesson).',
  '- Git: NEVER git reset --hard, NEVER git add -A / git commit -a, NEVER git push. Stage an explicit file list only. Revert a sabotage with a targeted git checkout -- <file> ONLY after git diff confirms that file holds nothing but the sabotage.',
  '- Do not touch the _nhangle_*/_allm_*/_bold_* etc. junk dirs or any file outside your declared scope.',
  '- Auto-memory updates: per-atom DETAIL goes in the memory dir file action-logging.md (batch-mode block); the MEMORY.md index line stays ONE short line (atoms landed, next item, ledger pointer) - never put memory content in the index.',
].join('\n')

const SCOUT_SCHEMA = {
  type: 'object', required: ['verdict', 'fr', 'reasons'],
  properties: {
    verdict: { enum: ['PROCEED', 'DEFER'] },
    fr: { type: 'integer' },
    reasons: { type: 'array', items: { type: 'string' } },
    decisionDoc: { type: 'string' },
    promptPath: { type: 'string' },
    anchorsVerified: { type: 'boolean' },
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
    docsUpdated: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}

const VERIFY_SCHEMA = {
  type: 'object', required: ['ok', 'problems'],
  properties: { ok: { type: 'boolean' }, problems: { type: 'array', items: { type: 'string' } } },
}

phase('Scout')
const scout = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the fresh-scout / friction-test stage for Refactor B batch item ' + NN + ': verb "' + VERB + '" (atom ' + ATOM + ' if you verdict PROCEED).',
  '',
  'READ FIRST (in order):',
  '1. ' + PLAN + ' (header + rules + the item detail for ' + VERB + ')',
  '2. doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md (rubric: D1-D4, F-* codes, current log-on-success contract)',
  '3. doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md - section 4 (boundary), section 33 (log-on-success), sections 40/43 (query/mutate split), 30/38/42 (readonly-gate-as-correctness-fix), 32 (route-the-equivalent-key), 44/45 (delete / add_pin_stubs, the latest shapes)',
  '4. If keys/menus are involved: doc/claude/issues/0068-unmigrated-legacy-switch-keys-not-logged.md',
  A.prescoped ? '5. EXISTING decision doc (this item is PRE-SCOPED): ' + DECISION_PATH : '',
  '',
  'Plan notes for this item (from PLAN.md - claims to RE-VERIFY, not trust):',
  A.notes || '(none)',
  '',
  'FRESH-SCOUT from source (line numbers in the notes have likely drifted):',
  '- the scheduler.c branch for "' + VERB + '" (which dispatch group fn; what it does argc-form by argc-form)',
  '- the core C function(s) it calls; WHO owns push_undo/set_modify (core vs branch); any early TCL_ERROR validation',
  '- is it logged today (inline log_action/log_action_argv? conditional?); does it set a Tcl result anyone consumes (grep consumers)',
  '- second entry points: callback.c keys, xschem.tcl menu -command lines, keybindings.csv rows',
  '- readonly semantics: what happens today on a read-only cell; would the boundary gate over-reject a read-only-legal form (query/mutate split needed?)',
  '',
  'VERDICT RULES:',
  '- DEFER when: a defer-trigger listed in the plan notes is CONFIRMED from source; the verb is confirmed D2/D3/D4 and no accepted boundary pattern covers it; the migration needs a NEW boundary pattern or a GUI/dialog redesign (scope balloons past a single-verb atom); or the scout contradicts the plan item fundamentally. DEFER is a success outcome - record precise reasons.',
  '- PROCEED when the migration fits accepted patterns (log-on-success, query/mutate split, log-gate reconcile, per-verb core_log_action arm, raw second-entry no-double-log) at single-atom scope.',
  '',
  'IF PROCEED, write TWO files (and nothing else):',
  '1. Decision doc ' + DECISION_PATH + (A.prescoped ? ' - it EXISTS: re-verify every anchor from source, update drifted line numbers and its Status line only.' : ' - the full scope: the split/shape decision, key-path resolution, grep-guard plan, test+sabotage plan (house style: mirror perform_action_atom26_check_unique_names_asymmetric_split_decision.md).'),
  '2. Implementation prompt ' + PROMPT_PATH + ' in the atom-26 house style: READ FIRST list; DISCIPLINE line; ANCHORS (verify, do not trust) with the line numbers YOU verified today; DO steps (run_core arm, core_log_action arm, branch delegation, keys if any); TEST plan (fixture, checks a..f incl. readonly-reject, replay-no-relog, undo depth, no-op-still-logs where applicable) + named sabotages each targeting exactly one check; grep-guard row changes; build+full_audit step with the baseline-fails note; docs step (audit section, issue files, memory); CONSTRAINTS (C89, commit message ends with the atom-' + ATOM + ' line + Co-Authored-By trailer, list of migrated verbs 1..' + String(Number(ATOM) - 1) + ').',
  'IF DEFER, write NO files.',
  '',
  DISCIPLINE,
  'Return ONLY via the structured output tool: verdict, fr (verified friction score), reasons (specific, from source), decisionDoc, promptPath, anchorsVerified.',
].filter(Boolean).join('\n'), { label: 'scout:' + VERB, schema: SCOUT_SCHEMA })

if (!scout) throw new Error('scout agent failed for ' + VERB)
log('scout verdict for ' + VERB + ': ' + scout.verdict + ' (fr ' + scout.fr + ')')

async function ledger(status, detailLines) {
  return agent([
    'Repo: ' + REPO + '. Edit EXACTLY ONE file (' + PLAN + ') and write EXACTLY ONE file (' + BATCHDIR + '/receipts/' + NN + '_' + VERB + '.md). Touch nothing else.',
    'In PLAN.md, find the ledger line starting "- [ ] ' + NN + ' " (verb ' + VERB + ').',
    status === 'DONE' ? 'Change its checkbox to [x] and append " -> atom ' + ATOM + ' DONE".'
      : status === 'DEFERRED' ? 'Change its checkbox to [D] and append a short " -> DEFERRED: <primary reason>".'
      : 'Change its checkbox to [F] and append " -> FAILED: <primary problem>".',
    'In the matching "Item detail" section, fill the "receipt:" line with a pointer to the receipt file plus a one-clause outcome.',
    'Write the receipt file with these facts (verbatim, formatted as markdown):',
    detailLines,
  ].join('\n'), { label: 'ledger:' + VERB, phase: 'Ledger', effort: 'low' })
}

if (scout.verdict === 'DEFER') {
  await ledger('DEFERRED', 'Item ' + NN + ' ' + VERB + ' - DEFERRED at scout stage.\nfr: ' + scout.fr + '\nreasons:\n- ' + scout.reasons.join('\n- '))
  return { status: 'DEFERRED', item: A.item, verb: VERB, fr: scout.fr, reasons: scout.reasons }
}

phase('Implement')
const impl = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You implement Refactor B atom ' + ATOM + ' (' + VERB + ').',
  'Execute the implementation prompt at ' + (scout.promptPath || PROMPT_PATH) + ' EXACTLY, start to finish: code, build (cd src && make), the new headless test (register it in tests/headless/full_audit.sh logdir_tests), sabotage-verify EVERY named sabotage (fail exactly its target, revert, clean re-run green), grep-guard rows in tests/headless/test_selflog_grep_guard.tcl, full_audit run, docs updates, and the COMMIT (explicit file list; message per the prompt, ending with the Co-Authored-By trailer).',
  'The decision doc is ' + (scout.decisionDoc || DECISION_PATH) + ' - keep its Status line updated.',
  'Baseline full_audit fails are listed in ' + PLAN + ' header - those are NOT yours; anything else failing IS yours.',
  DISCIPLINE,
  'CRASH RECOVERY: if the working tree ALREADY contains uncommitted edits for this atom (a prior implementer died mid-run), do not blindly re-apply. git diff the touched files first, verify each existing edit against the prompt, keep what is correct, complete only what is missing, then proceed to test/sabotage/commit as normal.',
  'ECONOMY: your context is finite. Run the full test suite (full_audit.sh) at most TWICE (once before commit is enough when the atom test + grep guard are green); do not re-read large docs you have already read; keep Bash output trimmed (tail/grep).',
  'If you hit a blocker that would balloon scope beyond the prompt, STOP implementing, revert your partial edits (targeted checkout of the files you touched), make NO commit, and report commit="NONE" with the blocker in summary.',
  'FINAL STEP (never skip, even if low on capacity): call the structured output tool with your receipt. If you must cut something, cut verification re-runs, never this call.',
  'Return ONLY via the structured output tool.',
].join('\n'), { label: 'implement:' + VERB, schema: IMPL_SCHEMA })

if (!impl) throw new Error('implement agent failed for ' + VERB)
if (impl.commit === 'NONE') {
  await ledger('FAILED', 'Item ' + NN + ' ' + VERB + ' - implementation aborted, no commit.\n' + impl.summary)
  return { status: 'FAILED', item: A.item, verb: VERB, problems: [impl.summary] }
}
log('implemented ' + VERB + ': commit ' + impl.commit + ', ' + impl.checksTotal + ' checks')

phase('Verify')
const verifyPrompt = function (claims) {
  return [
    'Repo: ' + REPO + ', branch fluid-editing. ADVERSARIAL verifier for Refactor B atom ' + ATOM + ' (' + VERB + '). Fresh eyes; trust NOTHING in the claims below - re-establish each fact yourself.',
    'Claims JSON: ' + JSON.stringify(claims),
    'Verify (read-only except running tests):',
    '1. The commit exists (git show --stat <hash>) and touches ONLY in-scope files (src code, the new test, full_audit.sh registration, grep-guard test, docs). Flag any stray file.',
    '2. Run the new test yourself, fresh (own process, repo-root cwd): tclsh ' + 'tests/headless/<testfile>. Must be green.',
    '3. Run tests/headless/test_selflog_grep_guard.tcl - green, and the claimed new/changed manifest rows for ' + VERB + ' are actually present in the file.',
    '4. Run tests/headless/full_audit.sh; the fail list must equal the baseline list in ' + PLAN + ' header (grep for ' + VERB + ' in any fail).',
    '5. The decision doc and implementation prompt exist and the decision doc Status says implemented.',
    '6. Spot-check the diff itself: the scheduler.c branch now delegates to perform_action for the mutate path; run_core adds NO push_undo when the core owns it; the core_log_action arm emits the documented literal.',
    'Return ONLY via the structured output tool: ok, problems (one string each, specific).',
  ].join('\n')
}
let verdict = await agent(verifyPrompt(impl), { label: 'verify:' + VERB, schema: VERIFY_SCHEMA })

if (verdict && !verdict.ok) {
  log('verify found ' + verdict.problems.length + ' problems - one repair attempt')
  const repair = await agent([
    'Repo: ' + REPO + ', branch fluid-editing. Repair stage for Refactor B atom ' + ATOM + ' (' + VERB + '), commit ' + impl.commit + '.',
    'An adversarial verifier found these problems:',
    '- ' + verdict.problems.join('\n- '),
    'Fix them at single-atom scope. Amend nothing; add a fixup commit (explicit file list, message "fixup: atom ' + ATOM + ' ' + VERB + ' - <what>", Co-Authored-By trailer). Re-run the atom test + grep guard + full_audit yourself before committing.',
    DISCIPLINE,
    'If a problem cannot be fixed at single-atom scope, say so plainly in your final text and make no commit.',
  ].join('\n'), { label: 'repair:' + VERB, phase: 'Verify' })
  verdict = await agent(verifyPrompt(Object.assign({}, impl, { repairNote: String(repair).slice(0, 2000) })), { label: 're-verify:' + VERB, phase: 'Verify', schema: VERIFY_SCHEMA })
}

const receiptBody = 'Item ' + NN + ' ' + VERB + ' - atom ' + ATOM + '.\ncommit: ' + impl.commit + '\ntest: ' + impl.testFile + ' (' + impl.checksTotal + ' checks)\nsabotage: ' + JSON.stringify(impl.sabotage) + '\nnon-baseline audit fails: ' + JSON.stringify(impl.nonBaselineFails) + '\ndocs: ' + JSON.stringify(impl.docsUpdated || []) + '\nverifier: ' + (verdict ? (verdict.ok ? 'OK' : 'PROBLEMS: ' + verdict.problems.join('; ')) : 'verifier agent failed') + '\nsummary: ' + impl.summary

if (!verdict || !verdict.ok) {
  await ledger('FAILED', receiptBody)
  return { status: 'FAILED', item: A.item, verb: VERB, commit: impl.commit, problems: verdict ? verdict.problems : ['verifier agent failed twice'] }
}

phase('Ledger')
await ledger('DONE', receiptBody)
return { status: 'DONE', item: A.item, verb: VERB, atom: A.atom, commit: impl.commit, checks: impl.checksTotal }
