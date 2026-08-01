export const meta = {
  name: 'ovb-2026-08-01-feature',
  description: 'One overnight-batch feature item: scout+spec-resolution -> gate -> implement -> adversarial verify -> ledger',
  phases: [
    { title: 'Scout', detail: 'read source, resolve spec holes, write decision doc + implementation prompt' },
    { title: 'Implement', detail: 'execute the generated prompt end-to-end: code, tests, sabotage, suites, commit' },
    { title: 'Verify', detail: 'adversarial re-verification in a fresh context (+ one repair attempt)' },
    { title: 'Ledger', detail: 'PLAN.md checkbox + receipt file' },
  ],
}

// Invoked by the batch driver, one call per ledger item, strictly sequential.
// args = {
//   item: <int>     ledger number in PLAN.md (1..5)
//   slug: <string>  ledger slug, e.g. 'marker-anywhere-in-plotbox'
// }
// Everything else the stages need lives on disk in PLAN.md — the driver never
// pastes item detail through its own context.

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCHDIR = REPO + '/doc/claude/overnight_batch_2026_08_01'
const PLAN = BATCHDIR + '/PLAN.md'

const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || !A.item || !A.slug) throw new Error('args {item, slug} required')
const SLUG = A.slug
const NN = String(A.item).length < 2 ? '0' + String(A.item) : String(A.item)
const PROMPT_PATH = BATCHDIR + '/prompts/' + NN + '_' + SLUG + '.md'
const RECEIPT_PATH = BATCHDIR + '/receipts/' + NN + '_' + SLUG + '.md'
const DECISION_PATH = REPO + '/doc/claude/code_analysis/ovb01_' + NN + '_' + SLUG.replace(/-/g, '_') + '_decision.md'

const READ_FIRST = [
  'READ FIRST, in this order (do not skip 1 — it is the WIRING.md of the waveform subsystem):',
  '1. ' + REPO + '/doc/claude/code_analysis/waveform_subsystem_reference.md',
  '2. ' + PLAN + ' — the header (verdict alphabet, spec-hole policy, run policy, PREFLIGHT baseline, universal facts + test discipline) AND the "## ' + NN + ' ' + SLUG + '" section under "# Item detail". That section is your contract.',
  '3. ' + REPO + '/doc/claude/specs/waveform_viewer_modes.md (§12 strip reorder, §13 trace drag, §14 viewer undo, §15 the LMB/RMB ownership table)',
  '4. ' + REPO + '/doc/claude/specs/graph_markers.md',
  '5. ' + REPO + '/CLAUDE.md',
].join('\n')

const DISCIPLINE = [
  'DISCIPLINE (non-negotiable):',
  '- RE-VERIFY every claim in the PLAN.md item notes from source before trusting it. Those notes are distilled from memory files and line numbers/API shapes HAVE drifted. A claim you cannot reproduce from source is a finding, not a blocker.',
  '- C89 throughout: declarations at block top, no // comments in .c files that follow the surrounding style. Allocations use my_malloc/my_strdup/my_realloc with the literal _ALLOC_ID_ placeholder — never hand-number it.',
  '- Config variables mirrored between C and Tcl (search "MIRRORED IN TCL" in src/xschem.h) must be changed on BOTH sides.',
  '- New user-facing operations go in a scheduler.c branch (letter-dispatched: `xschem get` groups sub-keys by first letter, `xschem set` splits on argv[2][0] < \'n\' — a key filed in the wrong half is SILENTLY unreachable).',
  '- A green suite does NOT prove the changed code ran. Sabotage-verify: each named sabotage must fail EXACTLY its target check, then be reverted with a targeted `git checkout -- <file>` ONLY after `git diff` confirms that file holds nothing but the sabotage, then a clean re-run must be green.',
  '- Headless tests: each test is its own process; relative paths need repo-root cwd; a script error IDLES rather than hangs. Register new suites in tests/headless/full_audit.sh (logdir_tests). Copy the shipped footer EXACTLY: `RESULT: ALL PASS ($npass checks)` + exit 0/1 — run_suites.sh classifies on the literal string "ALL PASS".',
  '- Gesture/key tests replay the WHOLE Tk event sequence in the shipping rc profile. NEVER a bare `event generate` + one `update`: loop, `focus -force`, confirm `[focus -displayof $w] eq $w`, generate, retry until an expr in the caller\'s scope reports the effect. For a NEGATIVE leg, confirm focus, deliver once, and add a check that the probe was actually delivered.',
  '- Run every suite with GUI_GATE=0 in the environment (overnight run, nobody at the desk; see PLAN.md run policy). Prefer tests/headless/run_suites.sh; never a bare for-loop over ./src/xschem.',
  '- KNOWN-FLAKY, not yours: test_cadence_drag (12/12 red on pristine); test_wave_trace_menu TG9 (4-in-10 WSLg); test_ase_plot P4/P6/P8 (1-2 in 10). The CHECK COUNT is the signal, not the verdict — test_ase_plot prints ALL PASS at 30 checks when WSLg geometry fails and it skips P1-P7 (145 = a real run); test_wave_clear_all 68 real vs 58 skipped. A whole-suite wipeout with NORESULT/connection errors is a WSLg Xwayland abort killing every X client — re-run before attributing it to your change.',
  '- Git: NEVER `git push`. NEVER `git reset --hard`. NEVER `git add -A` or `git commit -a`. Stage an EXPLICIT file list only. Do not touch files outside your declared scope, and do not touch the untracked junk/scratch dirs already present in the tree.',
  '- Scratch files go in the test\'s own test_scratch dir, never the repo root.',
  '- Do not "re-fix" pre-existing bugs you notice outside scope — record them in your summary instead.',
].join('\n')

const SCOUT_SCHEMA = {
  type: 'object',
  required: ['verdict', 'reasons', 'decisions'],
  properties: {
    verdict: { enum: ['PROCEED', 'DEFER'] },
    reasons: { type: 'array', items: { type: 'string' } },
    decisions: {
      type: 'array',
      description: 'Every spec hole resolved, one entry each. These are surfaced verbatim in the final report to the user.',
      items: {
        type: 'object',
        required: ['question', 'decision', 'rationale'],
        properties: {
          question: { type: 'string' },
          decision: { type: 'string' },
          rationale: { type: 'string' },
          rejected: { type: 'string', description: 'the alternative(s) not taken' },
        },
      },
    },
    planClaimsRefuted: { type: 'array', items: { type: 'string' }, description: 'claims in the PLAN.md item notes that source contradicts' },
    decisionDoc: { type: 'string' },
    promptPath: { type: 'string' },
    pixelAspects: { type: 'array', items: { type: 'string' }, description: 'deliverables of this item that are pixels/feel/layout and cannot be asserted' },
  },
}

const IMPL_SCHEMA = {
  type: 'object',
  required: ['commit', 'filesChanged', 'testFiles', 'checksTotal', 'sabotage', 'nonBaselineFails', 'summary'],
  properties: {
    commit: { type: 'string', description: 'commit hash, or the literal NONE if the implementation was aborted' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    testFiles: { type: 'array', items: { type: 'string' } },
    checksTotal: { type: 'integer' },
    checksBefore: { type: 'integer' },
    sabotage: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'target', 'failedExactly'],
        properties: { name: { type: 'string' }, target: { type: 'string' }, failedExactly: { type: 'boolean' }, note: { type: 'string' } },
      },
    },
    nonBaselineFails: { type: 'array', items: { type: 'string' } },
    docsUpdated: { type: 'array', items: { type: 'string' } },
    unassertable: { type: 'array', items: { type: 'string' }, description: 'deliverables no check in the suite can reach' },
    tunableConstants: { type: 'array', items: { type: 'string' }, description: 'file:name=value the user can tune at eyeball time' },
    summary: { type: 'string' },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['ok', 'problems', 'unassertable'],
  properties: {
    ok: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' } },
    unassertable: { type: 'array', items: { type: 'string' }, description: 'YOUR OWN list, established independently: deliverables of this item that no check in the suite can reach. Non-empty forces the [E] verdict.' },
    sabotageReproduced: { type: 'boolean', description: 'true if you re-ran at least one named sabotage yourself and it killed exactly its target' },
    auditMatchesBaseline: { type: 'boolean' },
    notes: { type: 'array', items: { type: 'string' } },
  },
}

// A schema'd agent USUALLY returns the validated object, but it can return its
// final TEXT instead (seen on item 01: the verifier printed its JSON in prose and
// never called the structured-output tool). Recover the payload rather than
// crashing the round on a formatting slip: pull the last well-formed top-level
// JSON object out of the text.
function asObj(x) {
  var i, j, c, depth, instr, esc, best, o
  if (!x) return null
  if (typeof x === 'object') return x
  if (typeof x !== 'string') return null
  best = null
  for (i = 0; i < x.length; i++) {
    if (x[i] !== '{') continue
    depth = 0; instr = false; esc = false
    for (j = i; j < x.length; j++) {
      c = x[j]
      if (esc) { esc = false; continue }
      if (c === '\\') { esc = true; continue }
      if (c === '"') { instr = !instr; continue }
      if (instr) continue
      if (c === '{') depth++
      else if (c === '}') {
        depth--
        if (depth === 0) {
          try { o = JSON.parse(x.slice(i, j + 1)); if (o && typeof o === 'object') best = o } catch (e) { /* not JSON */ }
          i = j
          break
        }
      }
    }
  }
  return best
}
// Agents do not always honour a schema's array types (seen on item 04: `notes`
// came back as a bare string). Coerce rather than crash the round.
function arr(x) {
  if (Array.isArray(x)) return x
  if (x === null || x === undefined || x === '') return []
  if (typeof x === 'string') return [x]
  if (typeof x === 'object') return [JSON.stringify(x)]
  return [String(x)]
}

phase('Scout')
const scoutRaw = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the SCOUT / spec-resolution stage for overnight-batch item ' + NN + ' "' + SLUG + '".',
  '',
  READ_FIRST,
  '',
  'YOUR JOB, in order:',
  '1. Fresh-read the SOURCE for everything the item touches. Establish, from source: which functions own the behaviour today, which file:line the gesture/key/verb arms live at, what the existing data model stores and where, which existing gestures the new one could collide with, and which suite already owns the relevant fixtures.',
  '2. Resolve EVERY spec hole. PLAN.md lists the questions with a recommended answer for each — take the recommendation UNLESS source contradicts it, in which case take what source supports and say so. Record each one in `decisions` (question / decision / rationale / rejected alternative). This list is shown to the user in the final report, so write it for a human.',
  '   A SPEC HOLE IS NEVER A REASON TO DEFER (explicit user instruction, PLAN.md "Spec-hole policy").',
  '3. Report any PLAN.md claim that source refutes, in `planClaimsRefuted`.',
  '4. Identify the deliverables that are pixels / feel / layout and that no assertion can reach, in `pixelAspects`.',
  '',
  'VERDICT RULES:',
  '- DEFER ONLY when: the item genuinely cannot fit one implement stage (it needs a data-model rewrite, not an additive extension), or source fundamentally contradicts the request (the thing it asks to change does not exist / already behaves that way). A DEFER writes NO files and records precise, source-cited reasons plus a proposal for what would unlock it. DEFER is a SUCCESS outcome — never a fudge for "this looks hard".',
  '- PROCEED otherwise.',
  '',
  'IF PROCEED, write EXACTLY TWO files and nothing else:',
  '(a) Decision doc ' + DECISION_PATH + ' — the full scope: what exists today with verified file:line anchors, the design, every resolved spec hole with its rationale, the collision map against existing gestures, the exact formulas/invariants the suite will assert, and a Status line.',
  '(b) Implementation prompt ' + PROMPT_PATH + ' — house style: READ FIRST list; DISCIPLINE; ANCHORS (file:line, verified BY YOU TODAY, with a one-line "what it does" each, marked "verify, do not trust"); DO steps in order; TEST plan naming the suite file, each check with the exact thing it asserts, and each NAMED SABOTAGE with the single check it must kill; the build + suite-run step naming the PLAN.md baseline; docs steps (spec section, landmine entry in waveform_subsystem_reference.md, issue file if one is warranted); the COMMIT step with an explicit file list and a message ending with the trailer below; and CONSTRAINTS.',
  '',
  'Commit message trailer for this batch (goes at the end of every commit in it):',
  '  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>',
  '',
  DISCIPLINE,
  '',
  'Return ONLY via the structured output tool.',
].join('\n'), { label: 'scout:' + SLUG, schema: SCOUT_SCHEMA })

const scout = asObj(scoutRaw)
if (!scout || !scout.verdict) throw new Error('scout agent died or returned no usable verdict for item ' + NN + ' ' + SLUG)
log('item ' + NN + ' ' + SLUG + ' — scout: ' + scout.verdict + ', ' + arr(scout.decisions).length + ' spec holes resolved')

function decisionsBlock(list) {
  if (!Array.isArray(list) || !list.length) return list ? String(JSON.stringify(list)) : '(none recorded)'
  return list.map(function (d, i) {
    if (!d || typeof d !== 'object') return (i + 1) + '. ' + String(d)
    return (i + 1) + '. **Q:** ' + d.question + '\n   **Decision:** ' + d.decision +
      '\n   **Why:** ' + d.rationale + (d.rejected ? '\n   **Rejected:** ' + d.rejected : '')
  }).join('\n')
}

async function ledger(status, body) {
  const mark = status === 'DONE' ? '[x]' : status === 'DONE_EYEBALL' ? '[E]' : status === 'DEFERRED' ? '[D]' : '[F]'
  const suffix = status === 'DONE' ? ' -> DONE'
    : status === 'DONE_EYEBALL' ? ' -> DONE, EYEBALL PENDING: <one clause naming what tests cannot see>'
    : status === 'DEFERRED' ? ' -> DEFERRED: <primary reason>'
    : ' -> FAILED: <primary problem>'
  return agent([
    'Repo: ' + REPO + '. You are the LEDGER stage. Edit EXACTLY ONE existing file (' + PLAN + ') and write EXACTLY ONE new file (' + RECEIPT_PATH + '). Touch nothing else. Make NO commit.',
    '',
    'In ' + PLAN + ', under "# Ledger", find the line beginning "- [ ] ' + NN + ' ' + SLUG + '".',
    'Change its checkbox to ' + mark + ' and append "' + suffix + '" (fill the angle-bracket part from the receipt body below; keep it to one clause).',
    'Then in the "## ' + NN + ' ' + SLUG + '" section under "# Item detail", fill the trailing "- receipt:" line with a pointer to ' + RECEIPT_PATH + ' plus a one-clause outcome.',
    'Change NOTHING else in PLAN.md — not the header, not other items.',
    '',
    'Write ' + RECEIPT_PATH + ' as markdown containing exactly the following facts, verbatim, formatted readably:',
    '',
    body,
  ].join('\n'), { label: 'ledger:' + SLUG, phase: 'Ledger', effort: 'low' })
}

if (scout.verdict === 'DEFER') {
  const body = [
    '# Item ' + NN + ' ' + SLUG + ' — DEFERRED at scout',
    '',
    '## Reasons (source-cited)',
    '- ' + (arr(scout.reasons).length ? arr(scout.reasons) : ['(none given)']).join('\n- '),
    '',
    '## Spec holes resolved before the defer',
    decisionsBlock(scout.decisions),
    '',
    '## PLAN.md claims refuted by source',
    arr(scout.planClaimsRefuted).length ? '- ' + arr(scout.planClaimsRefuted).join('\n- ') : '(none)',
  ].join('\n')
  await ledger('DEFERRED', body)
  return { status: 'DEFERRED', item: A.item, slug: SLUG, reasons: scout.reasons, decisions: scout.decisions, receipt: RECEIPT_PATH }
}

phase('Implement')
const implRaw = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the IMPLEMENT stage for overnight-batch item ' + NN + ' "' + SLUG + '".',
  '',
  'Execute the implementation prompt at ' + (scout.promptPath || PROMPT_PATH) + ' EXACTLY, start to finish. Its companion decision doc is ' + (scout.decisionDoc || DECISION_PATH) + ' — keep its Status line current.',
  'That means: read it, re-verify its anchors, write the code, `cd src && make` green, write/extend the tests, register any new suite in tests/headless/full_audit.sh, sabotage-verify EVERY named sabotage (fail exactly its target, revert, clean re-run green), run the affected suites plus tests/headless/full_audit.sh, update the docs, and COMMIT with an explicit file list.',
  '',
  'Baseline audit fails are recorded in the PREFLIGHT section of ' + PLAN + '. Those are NOT yours. Anything else failing IS yours until you prove otherwise against the KNOWN-FLAKY list.',
  '',
  READ_FIRST,
  '',
  DISCIPLINE,
  '',
  'CRASH RECOVERY: if the working tree already holds uncommitted edits for THIS item (a prior implementer died mid-run), do not blindly re-apply. `git diff` the touched files first, check each existing edit against the prompt, keep what is correct, complete only what is missing, then test/sabotage/commit as normal.',
  '',
  'ECONOMY: your context is finite. Run full_audit.sh at most TWICE (once is enough when the item suites are green). Do not re-read large docs you have already read. Keep Bash output trimmed with tail/grep.',
  '',
  'IF YOU HIT A BLOCKER that would balloon scope past the prompt: STOP, revert your partial edits with a targeted checkout of the files YOU touched, make NO commit, and report commit="NONE" with the blocker spelled out in summary. That is a legitimate outcome, not a failure of nerve.',
  '',
  'FINAL STEP, never skip even if low on capacity: call the structured output tool with your receipt. `unassertable` must honestly list every deliverable of this item that no check you wrote can reach — the batch verdicts [E] rather than [x] on a non-empty list, and that is the desired behaviour, not a penalty. `tunableConstants` lists any magnitude the user may want to tune after looking at it (file:name=value). If you must cut something, cut a verification re-run, never this call.',
  '',
  'Return ONLY via the structured output tool.',
].join('\n'), { label: 'implement:' + SLUG, schema: IMPL_SCHEMA })

const impl = asObj(implRaw)
if (!impl) throw new Error('implement agent died or returned no usable receipt for item ' + NN + ' ' + SLUG)

if (!impl.commit || impl.commit === 'NONE') {
  const body = [
    '# Item ' + NN + ' ' + SLUG + ' — FAILED: implementation aborted, no commit',
    '',
    '## Blocker',
    impl.summary,
    '',
    '## Spec holes that had been resolved',
    decisionsBlock(scout.decisions),
    '',
    '## Scout artefacts',
    '- decision doc: ' + (scout.decisionDoc || DECISION_PATH),
    '- implementation prompt: ' + (scout.promptPath || PROMPT_PATH),
  ].join('\n')
  await ledger('FAILED', body)
  return { status: 'FAILED', item: A.item, slug: SLUG, commit: 'NONE', problems: [impl.summary], decisions: scout.decisions, receipt: RECEIPT_PATH }
}

log('item ' + NN + ' ' + SLUG + ' — implemented: ' + impl.commit + ', ' + impl.checksTotal + ' checks, ' + arr(impl.unassertable).length + ' unassertable')

phase('Verify')
function verifyPrompt(claims, repairNote) {
  return [
    'Repo: ' + REPO + ', branch fluid-editing. You are the ADVERSARIAL VERIFIER for overnight-batch item ' + NN + ' "' + SLUG + '".',
    'You did NOT write this code and you trust NOTHING below. Every fact in the claims JSON is a hypothesis you must re-establish yourself. Your job is to try to REFUTE it.',
    '',
    'Claims JSON: ' + JSON.stringify(claims),
    repairNote ? 'A repair stage has since run. Its report: ' + repairNote : '',
    '',
    'The item contract is the "## ' + NN + ' ' + SLUG + '" section of ' + PLAN + '. The design is ' + (scout.decisionDoc || DECISION_PATH) + '. Read both.',
    '',
    'VERIFY (read-only on source; you may run tests, and you may read anything):',
    '1. The commit exists (`git show --stat <hash>`) and touches ONLY in-scope files. Flag every stray file, every unrelated hunk, and any file outside src/ + tests/headless/ + doc/claude/.',
    '2. Run the item\'s suite(s) YOURSELF, fresh, from repo-root cwd, with GUI_GATE=0. Green AND at the claimed check count. A suite that prints ALL PASS at a suspiciously low count has skipped its body — the COUNT is the signal.',
    '3. Re-run at least ONE named sabotage yourself end to end: apply it, confirm it kills EXACTLY its target check and nothing else, revert it with a targeted checkout after `git diff` shows only the sabotage, confirm the clean re-run is green. Report `sabotageReproduced`. If a sabotage does NOT kill its target, the suite is hollow there and that is a PROBLEM.',
    '4. Run tests/headless/full_audit.sh with GUI_GATE=0. Its fail list must equal the PREFLIGHT baseline in ' + PLAN + '. Judge any extra fail against the KNOWN-FLAKY list before blaming the item; re-run once before attributing. Report `auditMatchesBaseline`.',
    '5. Read the DIFF itself and ask the green-but-hollow questions: did the changed code actually run in the tests, and would the suite notice if it ran WRONG? Specifically hunt for: an assertion that passes because two index spaces coincide in the fixture; a leg driven from a pixel where the press never reaches the graph at all; a per-object state witnessed on ONE object; a threshold that a restored bug squeaks past; a negative leg that passes because the key was never delivered.',
    '6. Check the item contract clause by clause. Every "Questions and recommended answers" entry in PLAN.md must be answered by the code — either as recommended, or differently WITH a recorded rationale in the decision doc. An unaddressed clause is a problem.',
    '7. Establish YOUR OWN `unassertable` list: which deliverables of this item can no check in the suite reach? Do not copy the implementer\'s list — derive it. Pixels, animation, layout, cursor shape and "feel" belong here. This list is not a criticism; it decides [x] versus [E].',
    '8. Confirm the docs the prompt required were actually updated (spec section, landmine entry, issue file) and that the decision doc Status says implemented.',
    '',
    'Set ok=false if ANY of these hold: the commit is out of scope; a suite is red or hollow; a sabotage does not kill its target; the audit gained a fail the known-flaky list does not explain; a contract clause is unimplemented and unrecorded. Set ok=true only if you tried hard to break it and could not.',
    'Every problem is one specific string with the evidence in it.',
    '',
    'Return ONLY via the structured output tool.',
  ].filter(Boolean).join('\n')
}

let verdict = asObj(await agent(verifyPrompt(impl, null), { label: 'verify:' + SLUG, phase: 'Verify', effort: 'high' }))

let repairNote = null
if (verdict && verdict.ok !== true) {
  log('item ' + NN + ' — verify found ' + arr(verdict.problems).length + ' problems; one repair attempt')
  const repair = await agent([
    'Repo: ' + REPO + ', branch fluid-editing. You are the REPAIR stage for overnight-batch item ' + NN + ' "' + SLUG + '", commit ' + impl.commit + '.',
    'An adversarial verifier found these problems:',
    '- ' + arr(verdict.problems).join('\n- '),
    '',
    'Fix them at this item\'s scope. Do NOT amend the existing commit — add a fixup commit with an explicit file list and message "fixup: ' + NN + ' ' + SLUG + ' — <what>" ending with the Co-Authored-By trailer. Re-run the item suites AND full_audit.sh (GUI_GATE=0) yourself before committing.',
    'The design is ' + (scout.decisionDoc || DECISION_PATH) + '; the contract is the "## ' + NN + ' ' + SLUG + '" section of ' + PLAN + '.',
    '',
    DISCIPLINE,
    '',
    'If a problem CANNOT be fixed at this item\'s scope, say so plainly, fix the ones that can be, and name the one that cannot with what it would take. If NOTHING can be fixed, make no commit and say so.',
    'Your final text is read by a second verifier — make it a factual report: what you changed, what you ran, what remains.',
  ].join('\n'), { label: 'repair:' + SLUG, phase: 'Verify' })
  repairNote = String(repair || '(repair agent produced no report)').slice(0, 4000)
  verdict = asObj(await agent(verifyPrompt(impl, repairNote), { label: 're-verify:' + SLUG, phase: 'Verify', effort: 'high' }))
}

const unassertable = arr(verdict && verdict.unassertable).length
  ? arr(verdict.unassertable)
  : arr(impl.unassertable)

const receiptBody = [
  '# Item ' + NN + ' ' + SLUG,
  '',
  '- commit: `' + impl.commit + '`' + (repairNote ? ' (+ a fixup commit from the repair stage — see git log)' : ''),
  '- files changed: ' + JSON.stringify(impl.filesChanged || []),
  '- tests: ' + JSON.stringify(impl.testFiles || []) + ' — ' + impl.checksTotal + ' checks' + (impl.checksBefore ? ' (was ' + impl.checksBefore + ')' : ''),
  '- non-baseline audit fails claimed: ' + JSON.stringify(impl.nonBaselineFails || []),
  '- docs updated: ' + JSON.stringify(impl.docsUpdated || []),
  '- decision doc: ' + (scout.decisionDoc || DECISION_PATH),
  '- implementation prompt: ' + (scout.promptPath || PROMPT_PATH),
  '',
  '## Spec holes resolved (SURFACE THESE TO THE USER)',
  decisionsBlock(scout.decisions),
  '',
  '## PLAN.md claims refuted by source',
  arr(scout.planClaimsRefuted).length ? '- ' + arr(scout.planClaimsRefuted).join('\n- ') : '(none)',
  '',
  '## Sabotage',
  JSON.stringify(impl.sabotage || [], null, 1),
  '',
  '## Verifier (fresh adversarial context, not the implementer)',
  verdict ? ('- ok: ' + verdict.ok +
    '\n- sabotage reproduced independently: ' + verdict.sabotageReproduced +
    '\n- audit matches baseline: ' + verdict.auditMatchesBaseline +
    (verdict.auditDetail ? '\n- audit detail: ' + verdict.auditDetail : '') +
    (verdict.scopeVerdict ? '\n- commit scope: ' + verdict.scopeVerdict : '') +
    (verdict.hollownessProbe ? '\n- hollowness probe: ' + verdict.hollownessProbe : '') +
    (verdict.verdictRecommendation ? '\n- verifier recommendation: ' + verdict.verdictRecommendation : '') +
    '\n- problems: ' + (arr(verdict.problems).length ? '\n  - ' + arr(verdict.problems).join('\n  - ') : '(none)') +
    '\n- notes: ' + (arr(verdict.notes).length ? '\n  - ' + arr(verdict.notes).join('\n  - ') : '(none)'))
    : '- verifier agent DIED (no verdict)',
  repairNote ? '\n## Repair stage report\n\n' + repairNote : '',
  '',
  '## What the tests structurally CANNOT see (eyeball list)',
  arr(unassertable).length ? '- ' + arr(unassertable).join('\n- ') : '(nothing — every deliverable is reachable by an assertion)',
  '',
  '## Tunable constants (for the eyeball pass)',
  arr(impl.tunableConstants).length ? '- ' + arr(impl.tunableConstants).join('\n- ') : '(none declared)',
  '',
  '## Implementer summary',
  impl.summary,
].join('\n')

if (!verdict || verdict.ok !== true) {
  await ledger('FAILED', receiptBody)
  return {
    status: 'FAILED', item: A.item, slug: SLUG, commit: impl.commit,
    problems: verdict ? arr(verdict.problems) : ['verifier agent died twice'],
    decisions: arr(scout.decisions), unassertable: unassertable, receipt: RECEIPT_PATH,
  }
}

phase('Ledger')
const finalStatus = arr(unassertable).length ? 'DONE_EYEBALL' : 'DONE'
await ledger(finalStatus, receiptBody)
return {
  status: finalStatus, item: A.item, slug: SLUG, commit: impl.commit,
  checks: impl.checksTotal, decisions: arr(scout.decisions), unassertable: unassertable,
  tunableConstants: arr(impl.tunableConstants), receipt: RECEIPT_PATH,
}
