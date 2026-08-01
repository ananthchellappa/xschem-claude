export const meta = {
  name: 'ovb-2026-08-01-remediate',
  description: 'Remediate a [F] item from the overnight batch: targeted fix -> adversarial re-verify -> ledger re-tick',
  phases: [
    { title: 'Fix', detail: 'close the named problems at item scope, fixup commit' },
    { title: 'Verify', detail: 'adversarial: the named hollow spot must now be covered' },
    { title: 'Ledger', detail: 'PLAN.md re-tick + receipt addendum' },
  ],
}

// Launched by the driver when a user asks for a specific [F] item to be closed out.
// args = {
//   item:      <int>
//   slug:      <string>
//   mandate:   <string>  what must be true when this is done, in the verifier's words
//   problems:  [<string>] the verifier's verbatim findings from the failed run
// }

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCHDIR = REPO + '/doc/claude/overnight_batch_2026_08_01'
const PLAN = BATCHDIR + '/PLAN.md'

const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || !A.item || !A.slug || !A.mandate) throw new Error('args {item, slug, mandate, problems} required')
const SLUG = A.slug
const NN = String(A.item).length < 2 ? '0' + String(A.item) : String(A.item)
const RECEIPT_PATH = BATCHDIR + '/receipts/' + NN + '_' + SLUG + '.md'
const DECISION_PATH = REPO + '/doc/claude/code_analysis/ovb01_' + NN + '_' + SLUG.replace(/-/g, '_') + '_decision.md'
const PROBLEMS = (A.problems && A.problems.length) ? A.problems : ['(see the receipt)']

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
// Agents do not always honour a schema's array types. Coerce rather than crash.
function arr(x) {
  if (Array.isArray(x)) return x
  if (x === null || x === undefined || x === '') return []
  if (typeof x === 'string') return [x]
  if (typeof x === 'object') return [JSON.stringify(x)]
  return [String(x)]
}

const DISCIPLINE = [
  'DISCIPLINE (non-negotiable):',
  '- C89: declarations at block top. Allocations use my_malloc/my_strdup with the literal _ALLOC_ID_ placeholder.',
  '- Headless tests: own process, repo-root cwd, a script error IDLES rather than hangs. Keep the shipped footer EXACTLY: `RESULT: ALL PASS ($npass checks)` + exit 0/1.',
  '- NEVER a bare `event generate` + one `update`: loop, `focus -force`, confirm `[focus -displayof $w] eq $w`, generate, retry until an expr in the caller\'s scope reports the effect. A NEGATIVE leg confirms focus, delivers once, and adds a check that the probe was actually delivered.',
  '- Run every suite with GUI_GATE=0 in the environment.',
  '- KNOWN-FLAKY, not yours: test_cadence_drag, test_wave_trace_menu TG9, test_ase_plot P4/P6/P8. The CHECK COUNT is the signal, not the verdict. A whole-suite wipeout with NORESULT/connection errors is a WSLg Xwayland abort — re-run before attributing.',
  '- Git: NEVER `git push`, NEVER `git reset --hard`, NEVER `git add -A` / `git commit -a`. Explicit file list only. Revert a sabotage with a targeted `git checkout -- <file>` ONLY after `git diff` confirms that file holds nothing but the sabotage.',
  '- Do not touch files outside this item\'s scope, and do not touch the pre-existing untracked scratch/log dirs.',
  '- The ONLY dirty tracked files at the end must be doc/claude/suggestions/next_session_prompt_0165.md and sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state.',
].join('\n')

const FIX_SCHEMA = {
  type: 'object',
  required: ['commit', 'filesChanged', 'checksTotal', 'newLegs', 'hollowSabotage', 'summary'],
  properties: {
    commit: { type: 'string', description: 'fixup commit hash, or NONE if nothing could be fixed' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    checksTotal: { type: 'integer' },
    checksBefore: { type: 'integer' },
    newLegs: { type: 'array', items: { type: 'string' }, description: 'the new check names, verbatim' },
    hollowSabotage: {
      type: 'object',
      required: ['sabotage', 'killsNow', 'killedBefore'],
      properties: {
        sabotage: { type: 'string', description: 'the exact edit that used to leave the suite green' },
        killsNow: { type: 'array', items: { type: 'string' }, description: 'checks it now kills' },
        killedBefore: { type: 'integer', description: 'how many checks it killed BEFORE this fix (was 0)' },
        cleanRerunGreen: { type: 'boolean' },
      },
    },
    nonBaselineFails: { type: 'array', items: { type: 'string' } },
    unassertable: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['ok', 'problems', 'unassertable', 'hollowSpotClosed'],
  properties: {
    ok: { type: 'boolean' },
    hollowSpotClosed: { type: 'boolean', description: 'YOU applied the sabotage yourself and YOU watched the suite go red' },
    problems: { type: 'array', items: { type: 'string' } },
    unassertable: { type: 'array', items: { type: 'string' } },
    auditMatchesBaseline: { type: 'boolean' },
    notes: { type: 'array', items: { type: 'string' } },
  },
}

phase('Fix')
const fix = asObj(await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the REMEDIATION stage for overnight-batch item ' + NN + ' "' + SLUG + '", which an adversarial verifier marked [F].',
  '',
  'THE MANDATE — what must be true when you are done:',
  A.mandate,
  '',
  'THE VERIFIER\'S FINDINGS, verbatim (it did the measuring; its recipe is trustworthy but re-derive the specifics yourself):',
  '- ' + arr(PROBLEMS).join('\n\n- '),
  '',
  'READ FIRST:',
  '1. ' + RECEIPT_PATH + ' — the failed run\'s full receipt, including the verifier block',
  '2. ' + DECISION_PATH + ' — the item\'s design',
  '3. ' + PLAN + ' — the "## ' + NN + ' ' + SLUG + '" section (the contract) and the PREFLIGHT baseline',
  '4. ' + REPO + '/doc/claude/code_analysis/waveform_subsystem_reference.md — landmines',
  '',
  'SCOPE: close the named problems and NOTHING else. This is a coverage repair, not a redesign. If the underlying code is correct (the verifier says it is — it proved the line load-bearing by probe), do NOT rewrite it; write the leg that watches it.',
  '',
  'THE ACCEPTANCE TEST, and it is not optional: apply the exact sabotage the verifier used to prove the spot was hollow, rebuild, and confirm the suite now goes RED naming your new leg. Then revert it (targeted `git checkout -- <file>` after `git diff` shows only the sabotage), rebuild, and confirm the clean re-run is green. Report both numbers in `hollowSabotage` — `killedBefore` was 0, which is the whole point.',
  '',
  'Also re-run the item\'s full suite and tests/headless/full_audit.sh (GUI_GATE=0) and compare against the PLAN.md PREFLIGHT baseline.',
  '',
  'COMMIT: a fixup commit, explicit file list, message "fixup: ' + NN + ' ' + SLUG + ' — <what>" ending with:',
  '  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>',
  'Update the decision doc Status line and the issue file to record the closed gap.',
  '',
  DISCIPLINE,
  '',
  'If the mandate genuinely cannot be met at item scope, make NO commit, report commit="NONE", and say exactly what blocks it.',
  'FINAL STEP, never skip: call the structured output tool.',
].join('\n'), { label: 'fix:' + SLUG, schema: FIX_SCHEMA }))

if (!fix) throw new Error('fix agent died for item ' + NN)

async function ledger(mark, suffix, body) {
  return agent([
    'Repo: ' + REPO + '. You are the LEDGER stage. Edit EXACTLY ONE existing file (' + PLAN + ') and APPEND to EXACTLY ONE existing file (' + RECEIPT_PATH + '). Touch nothing else. Make NO commit.',
    '',
    'In ' + PLAN + ', under "# Ledger", find the line beginning "- [F] ' + NN + ' ' + SLUG + '".',
    'Replace its checkbox with ' + mark + ' and REPLACE everything from " -> FAILED:" onward with "' + suffix + '" (fill the angle-bracket part from the body below, one clause).',
    'Then in the "## ' + NN + ' ' + SLUG + '" section under "# Item detail", update the "- receipt:" line to mention the remediation.',
    'Change NOTHING else in PLAN.md.',
    '',
    'APPEND to ' + RECEIPT_PATH + ' (do not rewrite what is already there) a section titled "# Remediation (' + (mark === '[F]' ? 'still FAILED' : 'gap closed') + ')" containing exactly these facts, formatted readably:',
    '',
    body,
  ].join('\n'), { label: 'ledger:' + SLUG, phase: 'Ledger', effort: 'low' })
}

if (!fix.commit || fix.commit === 'NONE') {
  await ledger('[F]', ' -> FAILED: <primary problem>', '# Remediation attempt failed\n\nNo commit. Blocker:\n\n' + fix.summary)
  return { status: 'FAILED', item: A.item, slug: SLUG, commit: 'NONE', problems: [fix.summary], receipt: RECEIPT_PATH }
}

log('item ' + NN + ' remediation: ' + fix.commit + ', ' + fix.checksTotal + ' checks, ' + arr(fix.newLegs).length + ' new legs')

phase('Verify')
const verify = asObj(await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the ADVERSARIAL VERIFIER for the REMEDIATION of overnight-batch item ' + NN + ' "' + SLUG + '".',
  'You did not write this and you trust nothing. Your single most important job is to establish, WITH YOUR OWN HANDS, that the previously-hollow spot is now covered.',
  '',
  'Claims JSON: ' + JSON.stringify(fix),
  '',
  'The original failure is recorded in ' + RECEIPT_PATH + '. The mandate was:',
  A.mandate,
  '',
  'VERIFY:',
  '1. **The hollow spot.** Apply the sabotage named in the claims (and in the receipt) YOURSELF. Rebuild. Run the suite. It MUST go red, and the red legs must include the new ones. Then revert it with a targeted checkout after `git diff` confirms only the sabotage is present, rebuild, and confirm green. Report `hollowSpotClosed` — true ONLY if you personally watched it go red and come back green. This is the entire point of the remediation; if you cannot reproduce it, ok=false.',
  '2. The fixup commit exists, touches only in-scope files, and adds no unrelated hunk.',
  '3. Run the item suite yourself, fresh, repo-root cwd, GUI_GATE=0. Green at the claimed count.',
  '4. Run tests/headless/full_audit.sh (GUI_GATE=0). Compare to the PREFLIGHT baseline in ' + PLAN + '. Judge extras against the KNOWN-FLAKY list; re-run once before attributing.',
  '5. The new leg is not itself hollow: could it pass for the wrong reason? Specifically — is the gesture it drives actually delivered (not a silently-lost key/press), does it assert an effect rather than an absence, and does it discriminate the right code path? Try to make it pass with the feature broken in a DIFFERENT way than the named sabotage.',
  '6. Read the diff for scope creep: a coverage repair that also changed behaviour is a problem, not a bonus.',
  '7. Establish your OWN `unassertable` list for this item as a whole (pixels / feel / layout no check can reach). Non-empty means [E] rather than [x] — that is a classification, not a criticism.',
  '',
  'Set ok=false if the sabotage does not kill the new leg, the suite is red, the commit is out of scope, the audit gained an unexplained fail, or the new leg passes for the wrong reason.',
  '',
  DISCIPLINE,
  '',
  'Return ONLY via the structured output tool.',
].join('\n'), { label: 'verify-fix:' + SLUG, phase: 'Verify', effort: 'high' }))

const unassertable = arr(verify && verify.unassertable).length ? arr(verify.unassertable) : arr(fix.unassertable)
const closed = !!(verify && verify.ok === true && verify.hollowSpotClosed === true)

const body = [
  '- fixup commit: `' + fix.commit + '`',
  '- files: ' + JSON.stringify(arr(fix.filesChanged)),
  '- checks: ' + fix.checksTotal + (fix.checksBefore ? ' (was ' + fix.checksBefore + ')' : ''),
  '- new legs: ' + (arr(fix.newLegs).length ? '\n  - ' + arr(fix.newLegs).join('\n  - ') : '(none)'),
  '',
  '## The hollow spot, closed',
  '- sabotage: ' + (fix.hollowSabotage ? fix.hollowSabotage.sabotage : '(not reported)'),
  '- checks it killed BEFORE the remediation: ' + (fix.hollowSabotage ? fix.hollowSabotage.killedBefore : '?') + ' (this is why the item was [F])',
  '- checks it kills NOW: ' + (fix.hollowSabotage ? JSON.stringify(fix.hollowSabotage.killsNow) : '?'),
  '- clean re-run green: ' + (fix.hollowSabotage ? fix.hollowSabotage.cleanRerunGreen : '?'),
  '',
  '## Verifier (fresh adversarial context)',
  verify ? ('- ok: ' + verify.ok +
    '\n- **hollow spot closed, reproduced by the verifier itself: ' + verify.hollowSpotClosed + '**' +
    '\n- audit matches baseline: ' + verify.auditMatchesBaseline +
    '\n- problems: ' + (arr(verify.problems).length ? '\n  - ' + arr(verify.problems).join('\n  - ') : '(none)') +
    '\n- notes: ' + (arr(verify.notes).length ? '\n  - ' + arr(verify.notes).join('\n  - ') : '(none)'))
    : '- verifier agent DIED',
  '',
  '## What the tests still structurally CANNOT see',
  arr(unassertable).length ? '- ' + arr(unassertable).join('\n- ') : '(nothing)',
  '',
  '## Remediation summary',
  fix.summary,
].join('\n')

if (!closed) {
  await ledger('[F]', ' -> FAILED: <primary problem>', body)
  return {
    status: 'FAILED', item: A.item, slug: SLUG, commit: fix.commit,
    problems: verify ? arr(verify.problems) : ['verifier died'], receipt: RECEIPT_PATH,
  }
}

phase('Ledger')
const mark = arr(unassertable).length ? '[E]' : '[x]'
const suffix = arr(unassertable).length
  ? ' -> DONE, EYEBALL PENDING: <one clause naming what tests cannot see> (latch coverage gap closed, fixup ' + fix.commit + ')'
  : ' -> DONE (latch coverage gap closed, fixup ' + fix.commit + ')'
await ledger(mark, suffix, body)
return {
  status: arr(unassertable).length ? 'DONE_EYEBALL' : 'DONE', item: A.item, slug: SLUG,
  commit: fix.commit, checks: fix.checksTotal, newLegs: arr(fix.newLegs),
  unassertable: unassertable, receipt: RECEIPT_PATH,
}
