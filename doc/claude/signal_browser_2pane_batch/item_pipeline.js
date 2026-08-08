export const meta = {
  name: 'browser-2pane-item',
  description: 'One two-pane Signal Browser batch item: scout -> gate -> implement -> adversarial verify -> ledger',
  phases: [
    { title: 'Scout', detail: 'verify anchors + measure the band, verdict PROCEED/DEFER' },
    { title: 'Implement', detail: 'RED first, build, test, sabotage-verify, commit' },
    { title: 'Verify', detail: 'adversarial re-check in a fresh context' },
    { title: 'Repair', detail: 'one repair attempt when verify fails' },
    { title: 'Ledger', detail: 'LEDGER.md line + <NN>_receipt.md' },
  ],
}

// Invoked by the batch driver (DRIVER_PROMPT_2PANE.md), one call per remaining item.
// args = {
//   item:      <string>  ledger id: "13".."19", or "17b"
//   title:     <string>  the ledger line title
//   notes:     <string>  the FULL item section pasted verbatim from PLAN.md
//   carried:   <string>  the "Carried in from item 12" section of LEDGER.md, verbatim
//   baseline:  <string>  the "Recorded baseline" section of LEDGER.md, verbatim
//   pixel:     <bool>    true when the deliverable is visible UI (verdict [E], never [x])
// }
//
// Derived from doc/claude/signal_browser_detach_batch/item_pipeline.js. Deltas:
//   - BATCHDIR/LEDGER point at the two-pane batch; the SPEC (PLAN.md) is never written to
//   - receipts are FLAT files <NN>_receipt.md beside the existing 09/10/11/12/17/20 ones,
//     not a receipts/ subdir -- that is this batch's shipped convention
//   - the detach batch's "docked check count" (D2) invariant is replaced by this batch's
//     TWO recorded baselines (headless 1618 / X 11-of-11) and the check-count-shortfall rule
//   - the Tcl-only rule is REMOVED: items 16 and 17b deliberately touch C and the generated
//     key table, and a scout that defers them for "needs C" would be wrong
//   - two traps item 12 paid for are promoted into DISCIPLINE: measure the ID band, and
//     never name an accessor in a comment

const REPO = '/home/qflow/dev/xschem/claude_1/xschem'
const BATCHDIR = REPO + '/doc/claude/signal_browser_2pane_batch'
const LEDGER = BATCHDIR + '/LEDGER.md'
const SPEC = BATCHDIR + '/PLAN.md'

const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || A.item === undefined || !A.title) throw new Error('args {item, title, notes, carried, baseline, pixel} required')
const NN = String(A.item)
const PIXEL = !!A.pixel
const RECEIPT = BATCHDIR + '/' + NN + '_receipt.md'

const DISCIPLINE = [
  'DISCIPLINE (non-negotiable):',
  '- ALWAYS write "two-pane item N". There is a second Signal Browser plan with overlapping numbers and a bare "item N" has caused real confusion three times. In source comments: "TWO-PANE item N".',
  '- MEASURE THE ID BAND BEFORE YOU USE IT. The PLAN assigns check-id bands that are ALREADY SPENT -- it gave item 12 BW40-BW49 when item 10 had taken BW40-BW53. Grep every test file AND the batch docs for the highest id actually in use, and never renumber anything existing. Item 15 owns BD60-BD70; do not take them for anything else.',
  '- EVERY NUMBER IN THE PLAN IS SUSPECT UNTIL YOU RE-MEASURE IT. Item 12 found its node counts wrong (44/128; measured 45/129 -- the PLAN counts instance nodes, the design root is a ROW) while its signal totals were right. Re-measure before writing a single expected literal.',
  '- "Existing checks it reds: none" IN THE PLAN IS NOT EVIDENCE. Item 12 red BW25, and item 9 had said in its own source comment that it would. Grep the test files for checks that assert the CURRENT behaviour of whatever you are changing, and RESTATE them rather than deleting them.',
  '- RED FIRST, AND THE RED RUN IS A MEASUREMENT. Write the checks, run them, and look at which ones PASS. A check that passes before the code exists is vacuous -- item 12 shipped two of them (both were "nothing changed", which is exactly what an unwired widget produces) and only the red run revealed it. Carry the positive evidence in the SAME tuple as the stability claim.',
  '- A CHECK MUST NOT READ ITS OWN HELPER\'S RESTORE. Item 12 had a check that survived the swap-the-defaults sabotage because its helper re-set the values on the way out. If a helper restores state, the check that asserts that state is asserting the helper.',
  '- A CONTROL CAN EAT THE FIXTURE. `browser_refresh $tok 1` runs browser_reload, which OVERWRITES browsersigs($token) from signal_list -- `{}` when no raw is loaded. Item 12 lost a hand-seeded 424-name corpus this way and three checks failed on an empty browser. Re-seed whatever a control consumes.',
  '- NEVER NAME AN ACCESSOR IN A COMMENT IN src/wave_viewer.tcl. BD06-style checks count a BARE NAME file-wide and expect 2 (defined once, called once); a mention in prose is indistinguishable from a call site. Item 12 red BD06 by writing "browser_alldbs" inside a comment.',
  '- A green suite does not prove the changed code ran. Sabotage-verify: each named sabotage must fail EXACTLY its target check and nothing else, then be reverted, then a clean re-run must be green. A sabotage that reds NOTHING is a coverage hole or a driver defect -- re-read the patch you applied before believing a zero.',
  '- A SHORTFALL IN THE CHECK COUNT IS THE ONLY WITNESS TO VACUITY. Diff the COUNT, not just the fail count, on every run and after every sabotage. A file that aborts early prints a plausible fail count while silently dropping checks.',
  '- A CHECK THAT CAN THROW INSTEAD OF FAILING IS NOT A CHECK. Make "the thing I am reading vanished" an assertable VALUE (pcall + bs_num/bs_set + stable sentinels), never an exception.',
  '- EXPECTED LITERALS ARE STRING REPS. `[list ok [list x]]` is `ok x`, not `{ok {x}}`. This has cost reds on correct code three times.',
  '- `pcall` returns the STRING `ERR:<msg>`. `expr` on it throws past the check; `lsearch` on it answers -1 and goes GREEN on a failed read.',
  '- SABOTAGE DRIVER: it must take a LOCK FILE, carry an EXIT/INT/TERM trap that restores the source, ASSERT A PRE-STATE COUNT before patching, prove the mutation reached disk, and `diff` the restore. Its output filter MUST count NORESULT and TIMEOUT as reds -- an anchored `^(PASS|FAIL|RESULT)` filter turns a CRASHED suite into a clean zero. NEVER edit src/ while the driver holds it: the restore silently discards your edit and its own diff still says "byte-identical".',
  '- WHILE THE ITEM IS UNCOMMITTED, revert a sabotage from a byte-exact BACKUP, NOT `git checkout -- <file>` (which reverts to the previous commit and deletes the item).',
  '- Git: NEVER `git reset --hard`, NEVER `git add -A` / `git commit -a`, NEVER `git push`. Stage an explicit file list only.',
  '- Items 16 and 17b DO touch C (the action registry in scheduler.c) and the generated key table. That is expected and is NOT a reason to DEFER. Every other item is Tcl-only; if one of those needs C, that IS a defer plus an issue.',
  '',
  'ENVIRONMENT TRAPS (each cost a previous session real time):',
  '- With a dead DISPLAY=:0 inherited from the shell, ./src/xschem HANGS FOREVER, even for --version, even with --nogui. Run headless probes as `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` from the repo ROOT.',
  '- A --script file must end in an explicit `exit 0` or the process idles forever.',
  '- DO NOT run full_audit.sh with DISPLAY stripped. Its claim that GUI tests self-SKIP is aspirational: without Tk the guards themselves throw `invalid command name "winfo"` and you get ~60 bogus CRASHes. The X arm means DISPLAY set.',
  '- WSLg Xwayland dies ~3x/session, killing every client mid-suite. A run whose log contains `X connection to :0 broken`, or that returns NORESULT, is NOT a measurement -- re-run it. You CANNOT revive it from inside (the cure is `wsl --shutdown` from Windows). If it stays dead, the X arm is unavailable: DEFER the item with that reason rather than marking it FAILED.',
  '- Run suites through tests/headless/run_suites.sh or gated_xschem.sh -- never a bare for-loop over ./src/xschem, which enrols in no GUI gate.',
  '- NEVER run `make` while a suite is running. Suites flake under CPU load and 4 repeat failures are not determinism.',
  '- Key/gesture tests must replay the WHOLE Tk event sequence in the shipping rc profile. A bare `event generate` drops keys ~1-in-5 under WSLg; `event generate <Double-Button-1>` is ILLEGAL in Tk. `event generate` stamps time 0, so two presses at one spot are a Double.',
  '- `bs_type` needs its focus loop; Tk routes KEY events to the focus widget.',
  '- Use tests/from_user/ or a test_scratch dir for scratch files; leave no droppings in the repo. A helper file must NOT be named test_*.tcl -- full_audit.sh globs those and scores a zero-check file FAIL forever.',
  '- Known flakes that are NOT regressions: BR25 (a <Return> through a bare event generate), MG16 (key delivery), test_ase_plot P4/P6/P8, TG9 root-coords. Re-run before calling one a fail.',
].join('\n')

const CONTEXT = [
  '=== THIS ITEM, VERBATIM FROM THE SPEC (' + SPEC + ') ===',
  A.notes || '(driver passed none -- read the item ' + NN + ' section in ' + SPEC + ')',
  '',
  '=== THE SPEC IS doc/claude/specs/waveform_signal_browser_two_pane.md ===',
  'R1-R12 and sections 3, 6, 7 are the rulings. Where the PLAN and the spec disagree, the',
  'spec wins and the divergence gets recorded. Where a MEASUREMENT and either of them',
  'disagree, the measurement wins and BOTH get corrected in the receipt.',
  '',
  '=== CARRIED IN FROM ITEM 12 (binding) ===',
  A.carried || '(driver passed none -- read the "Carried in from item 12" section of ' + LEDGER + ')',
  '',
  '=== RECORDED BASELINE -- anything outside this is YOUR problem ===',
  A.baseline || '(driver passed none -- read the "Recorded baseline" section of ' + LEDGER + ')',
].join('\n')

const SCOUT_SCHEMA = {
  type: 'object',
  required: ['verdict', 'reasons', 'anchors', 'band'],
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
    band: {
      type: 'string',
      description: 'the MEASURED first-free check-id band for this item, with the evidence (highest id found, and where)',
    },
    planNumbersChecked: {
      type: 'array',
      description: 'every numeric claim in the item section, re-measured: claim vs measured',
      items: { type: 'string' },
    },
    existingChecksItReds: {
      type: 'array',
      description: 'checks that assert the CURRENT behaviour this item changes, found by grep -- the PLAN says "none" and has been wrong',
      items: { type: 'string' },
    },
    frozenOracles: {
      type: 'array',
      description: 'every frozen/source-grep/bare-name-count/hard-equality oracle this item could red, named, with whether it is expected to stay green',
      items: { type: 'string' },
    },
    scopeFiles: { type: 'array', items: { type: 'string' } },
    plan: { type: 'string', description: 'the concrete implementation plan the next stage executes' },
    risks: { type: 'array', items: { type: 'string' } },
  },
}

const IMPL_SCHEMA = {
  type: 'object',
  required: ['commit', 'filesTouched', 'testFiles', 'checksAdded', 'headlessTotal', 'xArm', 'sabotage', 'nonBaselineFails', 'summary'],
  additionalProperties: false,
  properties: {
    commit: { type: 'string' },
    filesTouched: { type: 'array', items: { type: 'string' } },
    testFiles: { type: 'array', items: { type: 'string' } },
    checksAdded: { type: 'integer' },
    headlessTotal: { type: 'integer', description: 'total --nogui checks over the 14 wave files; baseline 1618' },
    xArm: { type: 'string', description: 'e.g. "11/11" plus the per-suite counts that MOVED and why' },
    redRunVacuous: {
      type: 'array',
      description: 'checks that PASSED on the RED run before the code existed, and what was done about each',
      items: { type: 'string' },
    },
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
    restatedChecks: { type: 'array', items: { type: 'string' }, description: 'existing checks restated (never deleted), with why' },
    nonBaselineFails: { type: 'array', items: { type: 'string' } },
    divergences: { type: 'array', items: { type: 'string' }, description: 'anything done differently from the PLAN or the spec, with why' },
    declaredLimits: { type: 'array', items: { type: 'string' }, description: 'things measured NOT to work, declared rather than hidden' },
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
    baselineHeld: { type: 'boolean', description: 'headless 1618/0 and X 11/11, re-measured by the verifier' },
    ownSabotage: { type: 'string', description: 'the sabotage the verifier invented and what it red' },
  },
}

// ---------------------------------------------------------------- Scout

phase('Scout')
const scout = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the SCOUT stage for TWO-PANE Signal Browser item ' + NN + ': "' + A.title + '".',
  '',
  'Your job is a VERDICT, a MEASURED band, and a plan. Write no code, edit no files.',
  '',
  'Read first: ' + SPEC + ' (the item section and its header numbering block),',
  'doc/claude/specs/waveform_signal_browser_two_pane.md (the rulings), and the receipts of the',
  'items this one depends on -- 09/10/11/12/17/20_receipt.md in ' + BATCHDIR + '. The receipts',
  'carry the corrections; the PLAN does not always.',
  '',
  CONTEXT,
  '',
  'Do this:',
  '1. Re-verify every line-number anchor the item section cites, against current source. Cited vs actual for each. An anchor that MOVED is fine; one that does not exist at all is a DEFER signal.',
  '2. MEASURE THE CHECK-ID BAND. Grep every tests/headless/*.tcl AND every doc in ' + BATCHDIR + ' for the highest id in this item\'s prefix. Report the first free id and the evidence. The PLAN\'s stated band is not evidence -- it has been wrong at least twice. Item 15 owns BD60-BD70.',
  '3. RE-MEASURE EVERY NUMBER the item section states (counts, totals, node counts, key counts). Report claim vs measured into planNumbersChecked. Write no expected literal from the PLAN alone.',
  '4. FIND THE EXISTING CHECKS THIS ITEM WILL RED, by grep, into existingChecksItReds. The PLAN\'s "reds existing" column has been wrong; item 12 red BW25 and item 9 had predicted it in a source comment the PLAN never carried forward. Look especially for checks asserting the CURRENT behaviour of whatever this item changes.',
  '5. ENUMERATE THE FROZEN ORACLES this item could red, by name, re-derived by grep. Known families: test_wave_grid GH0 (16 keys / 11 accelerators), GH2, GH4, GH8, GH9; GS0/GS1/GS2; test_wave_sigbrowser BT08/BT09, BS01, BS02; BP07; the BD06-style BARE-NAME file-wide counts; test_bindings_file and test_keybindings_help (items 16/17b will move these BY DESIGN); and the .ph status-line pins BD52, BX37, BX42, BX44-BX46, BH50, BH51, BH54.',
  '6. Confirm the item does not require overturning a spec ruling. If it does, verdict DEFER and name the ruling.',
  '7. Produce a concrete implementation plan: exact procs, exact widget paths, exact check ids in the measured band, and for each named sabotage how it will be injected AND what its positive control is.',
  '',
  'DEFER is a SUCCESS outcome. Do not force a PROCEED on an item whose premise you just disproved.',
  '',
  DISCIPLINE,
].join('\n'), { schema: SCOUT_SCHEMA, phase: 'Scout', label: 'scout:' + NN })

// A DEAD AGENT IS NOT A VERDICT. agent() returns null when the subagent dies on a terminal
// API error or when the user skips it. A previous batch wrote "[D] DEFERRED: the scout
// returned nothing" into a ledger -- an infrastructure failure wearing the costume of a
// considered engineering judgement, which is the worst kind of wrong entry in a file whose
// whole job is to be trusted later. Fail loudly: touch NO ledger line, write NO receipt.
if (!scout) {
  log('item ' + NN + ': scout agent DIED (null result) -- not a defer. Ledger untouched.')
  return {
    item: NN,
    verdict: 'INFRA_FAILURE',
    stage: 'scout',
    ledgerTouched: false,
    note: 'scout agent returned null (terminal API error or skipped). This is NOT a DEFER '
        + 'verdict and NOTHING was written to LEDGER.md or the receipt. Re-launch the item.',
  }
}

if (scout.verdict !== 'PROCEED') {
  const reasons = scout.reasons
  phase('Ledger')
  await agent([
    'Repo: ' + REPO + '. Ledger stage for two-pane item ' + NN + ' ("' + A.title + '"), verdict DEFERRED.',
    '',
    'Do exactly two things, and nothing else:',
    '1. In ' + LEDGER + ', change the item ' + NN + ' ledger line from "- [ ]" to "- [D]" and append " -> DEFERRED: <one-sentence reason>" to that line. Do not reflow or reformat the rest of the file. DO NOT touch ' + SPEC + '.',
    '2. Write ' + RECEIPT + ' with: the verdict, the full reason list, the anchor table, the MEASURED band, the re-measured PLAN numbers, the existing-checks-it-reds list and the frozen-oracle list.',
    '',
    'Reasons from the scout:', JSON.stringify(reasons, null, 1),
    'Anchor checks:', JSON.stringify(scout.anchors, null, 1),
    'Measured band:', String(scout.band),
    'PLAN numbers re-measured:', JSON.stringify(scout.planNumbersChecked || [], null, 1),
    'Existing checks it would red:', JSON.stringify(scout.existingChecksItReds || [], null, 1),
    'Frozen oracles named:', JSON.stringify(scout.frozenOracles || [], null, 1),
    '',
    'Do NOT commit. Do NOT touch src/ or tests/.',
  ].join('\n'), { phase: 'Ledger', label: 'ledger:' + NN })
  return { item: NN, verdict: 'DEFERRED', reasons: reasons, receipt: RECEIPT }
}

// ---------------------------------------------------------------- Implement

phase('Implement')
const impl = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the IMPLEMENTER for TWO-PANE Signal Browser item ' + NN + ': "' + A.title + '".',
  '',
  CONTEXT,
  '',
  '=== THE SCOUT VERIFIED THESE ANCHORS ===', JSON.stringify(scout.anchors, null, 1),
  '=== MEASURED CHECK-ID BAND (use it; do not renumber anything existing) ===', String(scout.band),
  '=== PLAN NUMBERS, RE-MEASURED (trust these, not the PLAN) ===', JSON.stringify(scout.planNumbersChecked || [], null, 1),
  '=== EXISTING CHECKS THIS ITEM REDS (restate, never delete) ===', JSON.stringify(scout.existingChecksItReds || [], null, 1),
  '=== FROZEN ORACLES TO RE-GREP AFTERWARDS ===', JSON.stringify(scout.frozenOracles || [], null, 1),
  '=== THE SCOUT\'S PLAN ===', scout.plan || '(none -- follow the item section)',
  '=== RISKS THE SCOUT FLAGGED ===', JSON.stringify(scout.risks || [], null, 1),
  '',
  'Execute end to end:',
  '1. RE-MEASURE THE TWO BASELINES FIRST, on the unchanged tree, and confirm they match the recorded ones. If they do not, STOP and report -- every red afterwards would be unattributable.',
  '2. WRITE THE CHECKS FIRST AND RUN THEM RED. Then read the red run: any check that PASSED before the code exists is vacuous and must be rewritten to carry its positive evidence in the same tuple. Record every one in redRunVacuous -- an empty list on a non-trivial item is itself suspicious.',
  '3. Implement the item. Stay inside the scope files. Do not opportunistically fix neighbouring code.',
  '4. `cd src && make` green (and for items 16/17b, regenerate whatever the key table is generated from -- do not hand-edit a generated file).',
  '5. Re-run: the item test files, then the FULL headless arm (14 wave files, baseline 1618) and the FULL X arm through run_suites.sh (11 suites). Report headlessTotal and xArm, naming every per-suite count that MOVED and why. A count that moved without a reason is a defect.',
  '6. RE-GREP every frozen oracle the scout named and confirm its state. A source-grep or bare-name-count check can red with NO behavioural regression at all.',
  '7. Sabotage-verify every sabotage the item names, under a LOCKED, TRAPPED, PRE-STATE-ASSERTING driver whose filter counts NORESULT/TIMEOUT as reds. For each: inject, prove it reached disk, run, confirm it fails EXACTLY its target and nothing else, confirm the positive control, restore from a byte-exact backup, diff, re-run clean. A zero-red row is a coverage hole or a driver defect -- say which.',
  '8. Record declaredLimits: anything you MEASURED not to work and are shipping anyway with the limit stated. A declared limit is a success outcome; a hidden one is a defect.',
  '9. Commit. Explicit file list. Conventional-commits subject <=50 chars, a body carrying the measurements and the traps, ending with the Co-Authored-By trailer. Do NOT push.',
  '',
  'If you cannot make it green: do NOT commit a broken state. Return with nonBaselineFails populated and say what blocked you. A truthful failure is worth more than a green lie.',
  '',
  DISCIPLINE,
].join('\n'), { schema: IMPL_SCHEMA, phase: 'Implement', label: 'impl:' + NN, effort: 'high' })

// ---------------------------------------------------------------- Verify

phase('Verify')
let verify = await agent([
  'Repo: ' + REPO + ', branch fluid-editing. You are the ADVERSARIAL VERIFIER for TWO-PANE item ' + NN + ': "' + A.title + '".',
  '',
  'You did not write this code and you trust none of the claims below. Your default posture is that the receipt is optimistic.',
  '',
  '=== THE IMPLEMENTER CLAIMS ===', JSON.stringify(impl, null, 1),
  '', CONTEXT,
  '',
  'Verify by DOING, not by reading the claim:',
  '1. `git show --stat <commit>` -- does it touch ONLY the scoped files? Anything else is a scope leak.',
  '2. Run the item test files yourself. Count the checks. Does the COUNT match the claim? A shortfall means the file aborted early and every zero in the receipt is unreadable.',
  '3. Re-measure BOTH baselines yourself: the 14-file headless arm (expect 1618 + whatever this item added) and the 11-suite X arm. Set baselineHeld. A claimed-empty nonBaselineFails that is not empty is the single most important thing you can catch.',
  '4. Read the new test code for VACUITY. Does any check assert a tautology, or assert on a value the test computed itself rather than on program behaviour? Does any negative check lack a positive control on the same fixture? Does any check read back a value its own helper just restored? Does any check THROW where it should return a value? Item 12 shipped three of these into its first draft.',
  '5. INVENT A SABOTAGE THE IMPLEMENTER DID NOT NAME, aimed at the item core, and run it. It must red something. If the suite stays green under your sabotage, the tests do not cover the feature -- that is a FAIL regardless of how many checks passed. Report it in ownSabotage.',
  '6. Re-grep the frozen oracles yourself. Confirm no bare-name count moved because of a COMMENT.',
  '7. Check divergences and declaredLimits. A divergence from a spec ruling that was not flagged is a FAIL. A limit that was measured and NOT declared is also a FAIL.',
  '8. If the deliverable is visible UI, say so plainly: a claim about what the user SEES that no check can judge must be reported as owing an eyeball, not accepted as verified.',
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
    'Repo: ' + REPO + ', branch fluid-editing. ONE repair attempt on two-pane item ' + NN + ': "' + A.title + '".',
    '',
    'The adversarial verifier rejected the item. Problems:', JSON.stringify(verify.problems, null, 1),
    '', 'What the verifier actually ran:', JSON.stringify(verify.reran || [], null, 1),
    '', 'The verifier\'s own sabotage:', String(verify.ownSabotage || '(none reported)'),
    '', CONTEXT,
    '',
    'Fix exactly those problems. Do not expand scope. Rebuild, re-run the item tests and BOTH arms, re-run the sabotages, re-grep the frozen oracles, and commit a FIXUP commit (explicit file list, no push).',
    'If a problem is not actually a problem, say so with EVIDENCE rather than changing code to satisfy it.',
    '', DISCIPLINE,
  ].join('\n'), { schema: IMPL_SCHEMA, phase: 'Repair', label: 'repair:' + NN, effort: 'high' })

  phase('Verify')
  verify = await agent([
    'Repo: ' + REPO + '. RE-VERIFY two-pane item ' + NN + ' after one repair attempt.',
    '', 'Original problems:', JSON.stringify(verify.problems, null, 1),
    '', 'Repair claims:', JSON.stringify(repaired, null, 1),
    '', CONTEXT,
    '',
    'Same rules as before: run everything yourself, including a fresh unnamed sabotage of your own and both baselines. This is the last gate -- if it is not right now, the item is marked FAILED and a human looks at it.',
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
  'Repo: ' + REPO + '. Ledger stage for two-pane item ' + NN + ' ("' + A.title + '"). Verdict: ' + verdict + '.',
  '',
  'Do exactly these, and nothing else. Touch no file outside ' + BATCHDIR + ', and NEVER ' + SPEC + '.',
  '',
  '1. In ' + LEDGER + ', change the item ' + NN + ' ledger line from "- [ ]" to "- ' + mark + '" and append " -> ' + verdict + ' (<commit>)".' +
    (passed && PIXEL ? ' Because the deliverable is visible UI the mark is [E], NOT [x] -- no test can judge it.' : '') +
    (passed ? '' : ' Append the failure reason to the line.'),
  (passed && PIXEL)
    ? '2. Add a row to the "Eyeball queue" table in ' + LEDGER + ': item, commit, what to look at, empty Eyeballed? cell.'
    : '2. (no eyeball-queue row for this item)',
  '3. If either recorded baseline MOVED, update the "Recorded baseline" section of ' + LEDGER + ' with the new per-suite numbers AND a one-line reason. Never silently adopt a new baseline.',
  '4. Write ' + RECEIPT + ' in the shape of 12_receipt.md: the baselines before and after; WHAT THE PLAN GOT WRONG with the measurement that says so; the traps that cost real time; what landed (source, then tests); the sabotage table with failedExactly / positive control / reverted per row, plus the verifier\'s own unnamed sabotage; the checks that were VACUOUS on the red run and what was done about them; every existing check restated and why; every divergence; every declared limit; and what is still owed to the next item.',
  '',
  'Implementer result:', JSON.stringify(finalImpl, null, 1),
  '', 'Verifier result:', JSON.stringify(verify, null, 1),
  '', 'Scout anchors:', JSON.stringify(scout.anchors, null, 1),
  '', 'Measured band:', String(scout.band),
  '', 'PLAN numbers re-measured:', JSON.stringify(scout.planNumbersChecked || [], null, 1),
  '', 'Frozen oracles:', JSON.stringify(scout.frozenOracles || [], null, 1),
  '',
  'Do NOT commit. Do NOT touch src/ or tests/. Do NOT reflow the rest of the ledger.',
].join('\n'), { phase: 'Ledger', label: 'ledger:' + NN })

return {
  item: NN,
  title: A.title,
  verdict: verdict,
  mark: mark,
  commit: finalImpl ? finalImpl.commit : null,
  headlessTotal: finalImpl ? finalImpl.headlessTotal : null,
  xArm: finalImpl ? finalImpl.xArm : null,
  baselineHeld: verify ? verify.baselineHeld : null,
  problems: passed ? [] : (verify ? verify.problems : ['verify agent returned nothing']),
  receipt: RECEIPT,
}
