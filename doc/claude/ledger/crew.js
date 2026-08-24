export const meta = {
  name: 'backlog-crew',
  description: 'Run one open_pdk backlog item end to end: scout, measure, plan, RED, implement, verify, write-up, commit, ledger',
  whenToUse: 'Driver dispatch of a single backlog item (D1-D10) on branch open_pdk of xschem-claude',
  phases: [
    { title: 'Scout', detail: 'locate code, existing tests, exact current behaviour' },
    { title: 'Measure', detail: 'reproduce headlessly, record BEFORE lines and the tier baseline' },
    { title: 'Plan', detail: 'fix, test rows, sabotage variants, ratification questions' },
    { title: 'RED', detail: 'write the failing checks first and confirm they are red' },
    { title: 'Implement', detail: 'the ONLY agent allowed to run make' },
    { title: 'Verify', detail: '3 parallel: tier diff, sabotage matrix, adversarial refutation' },
    { title: 'Writeup', detail: 'issue file, doc updates, git add + git commit' },
    { title: 'Ledger', detail: 'append the run row (always runs)' },
  ],
}

/* ------------------------------------------------------------------ */
/* constants                                                           */
/* ------------------------------------------------------------------ */

let ARGS = args
if (typeof ARGS === 'string') {
  try { ARGS = JSON.parse(ARGS) } catch (e) { ARGS = {} }
}
if (!ARGS || typeof ARGS !== 'object') ARGS = {}

const ID = ARGS.id || 'UNKNOWN'
const BRIEF = ARGS.brief || '(no brief supplied)'
const REPO = '/home/analog/dev/xschem-claude'
const LEDGER = REPO + '/doc/claude/ledger/driver_run_2026-08-09.md'
const SESSION_URL = 'https://claude.ai/code/session_01WRDmzMK6C5VEBLc5Q34CX9'

const COMMON = [
  'You are one agent of an autonomous crew working item ' + ID + ' of an unattended backlog run.',
  'Repository: ' + REPO + '   Branch: open_pdk   (already checked out; do NOT switch branches)',
  '',
  'ITEM ' + ID + ' BRIEF (verbatim from the driver):',
  BRIEF,
  '',
  '=== HARD RULES FOR EVERY AGENT IN THIS CREW ===',
  '1. NO HUMAN IS WATCHING. Never ask a question, never wait for approval. Decide using the',
  '   ratified-rules ladder below and record the decision in writing.',
  '2. ONLY the Implement agent may run make / cmake / any build. If you are not the Implement',
  '   agent and you think you need to rebuild, you are wrong - use the binary at ' + REPO + '/src/xschem',
  '   as it stands. Two concurrent builds OOM this ~7.8GB WSL box.',
  '3. NEVER git push. NEVER open a PR. NEVER git checkout/switch/reset --hard a branch.',
  '4. Default to headless: ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl',
  '   A suite that genuinely needs X runs under xvfb: GUI_GATE=0 xvfb-run -a <cmd>. That is correct,',
  '   not a cheat - the gate protects the USER display, and xvfb is not the user display.',
  '   Do NOT set GUI_GATE=0 globally and do NOT touch ~/.claude/gui_test_gate/control.',
  '   If a human must eyeball pixels: screenshot to doc/claude/evidence/, and the item is status E.',
  '5. Every file you create under doc/claude/ must be committed by the Write-up agent, not left',
  '   untracked. Leave no stray scratch files in the repo; use',
  '   /tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_' + ID + ' for scratch.',
  '',
  '=== TIERS THAT MUST STAY GREEN (baseline measured 2026-08-09 at bc4ff4a2) ===',
  '  test_shape_draw_gate.tcl ......................... 421',
  '  test_paste_modify_flag_0244.tcl .................. 376',
  '  test_add_wire_label.tcl .......................... 178',
  '  test_placement_wire_gate.tcl ..................... 171',
  '  test_label_ride.tcl .............................. 157',
  '  test_placement_preview_doors.tcl ................. 115',
  '  test_label_strand_oracle.tcl ..................... 32',
  '  test_sch_add_pin.tcl ............................. 21',
  '  test_wire_split / test_crossview_paste / test_instance_update ... OVERALL: ok',
  '  tests/headless/wireedit/run_wireedit.sh .......... WIREEDIT: ALL PASS',
  '  tests/headless/run.sh ............................ 6 goldens, HARNESS: PASS',
  '  cd tests && tclsh run_regression.tcl ............. exactly 3 pre-existing FAIL lines',
  '',
  '=== KNOWN-RED BEFORE THIS RUN - NOT YOURS, DO NOT CHASE ===',
  '  - run_regression.tcl: 3 lines from ONE defect - test_ihp_sg13g2_libmgr expects 9 libs, tree has',
  '    10 (sg13g2_tests_ase), which also fails test_pdk_launcher.',
  '  - test_selflog_output: 6 transform-key checks (Shift-F/Alt-F/Shift-R/Alt-R/Shift-V/Alt-V).',
  '  - test_fluid_editing under X: FAIL: FE8 drag-and-return changed the arc AND left buffer',
  '    MODIFIED. It self-SKIPs under --nogui. Only run it if this item touches move.c.',
  '  - test_action_replay.sh and test_ciw: carried forward, not re-verified since 0265.',
  '',
  '=== RATIFIED RULES LADDER (apply in order, and SAY which rung you used) ===',
  '  R1. Already-ratified rules:',
  '      - whatever you just pressed is what you meant (0240/0242/0243/0247/0265/0269)',
  '      - a teardown must name what it is tearing down (0241)',
  '      - gates live at the VERBS, never at the shared per-click primitive (0243 F2)',
  '      - never gate a pure-commit coordinate form - those are the replay/test seams (landmine 2)',
  '      - an aborted gesture must not lie about the modify flag (0244/0267/0270)',
  '  R2. If R1 does not settle it: pick the option LEAST SURPRISING to a user mid-gesture and',
  '      SMALLEST in blast radius, implement it, and write both the decision AND the rejected',
  '      alternative into the issue file.',
  '  R3. If the choice changes USER-VISIBLE behaviour and no prior ratification covers it: still',
  '      implement it, then the item is status E and the exact question goes in the ledger row.',
  '',
  '=== NEW ISSUE NUMBERING ===',
  '  Number new issues from 0350 upward. 0200-0272 are taken on open_pdk. 0212-0229, 0278/0279,',
  '  0285, 0290, 0295-0300, 0305, 0306 belong to the fluid-editing branch. The 0273-0349 gap is',
  '  left clear ON PURPOSE - do not fill it. Claim a number by creating',
  '  doc/claude/issues/NNNN-<slug>.md IMMEDIATELY as a stub before doing the work, so a later crew',
  '  in this same run cannot collide. File anything measured and not fixed. Never fix a discovered',
  '  defect silently.',
  '',
  '=== PROJECT ORIENTATION ===',
  '  Almost all state hangs off the global Xschem_ctx *xctx (xschem.h). The C core exposes',
  '  functionality through one Tcl command dispatched by scheduler() in scheduler.c; GUI events',
  '  arrive as xschem callback <win> <event> ... into callback.c. src/xschem.tcl is the GUI layer',
  '  and mirrors many C config vars (search MIRRORED IN TCL in xschem.h).',
  '  Before touching ANYTHING that creates, moves, deletes or reroutes wires, read',
  '  doc/claude/WIRING.md and keep it updated.',
  '  Allocations use my_malloc/my_realloc/my_strdup with the literal placeholder _ALLOC_ID_ as the',
  '  first argument - write _ALLOC_ID_, never a hand-picked number.',
  '  C89 only. src/Makefile lists objects explicitly in OBJ - a new .c file needs an OBJ entry and',
  '  a compile rule.',
].join('\n')

/* ------------------------------------------------------------------ */
/* schemas                                                             */
/* ------------------------------------------------------------------ */

const SCOUT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['anchors', 'existing_tests', 'repro_command', 'current_behaviour', 'risk_notes'],
  properties: {
    anchors: {
      type: 'array', maxItems: 25, items: { type: 'string' },
      description: 'file:line anchors with a few words each, e.g. "src/callback.c:1204 ESC handler ignores placement form"',
    },
    existing_tests: {
      type: 'array', maxItems: 20, items: { type: 'string' },
      description: 'paths of tests that already cover or nearly cover this area',
    },
    repro_command: { type: 'string', description: 'exact shell command that should exhibit the defect headlessly' },
    current_behaviour: { type: 'string', description: 'what the code actually does today, in prose, no proposed fix' },
    risk_notes: { type: 'array', maxItems: 10, items: { type: 'string' }, description: 'call sites / seams a fix would disturb' },
  },
}

const MEASURE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['reproduced', 'before_transcript', 'baseline', 'baseline_matches_expected', 'notes'],
  properties: {
    reproduced: { type: 'boolean', description: 'true only if the defect was actually observed' },
    before_transcript: {
      type: 'array', maxItems: 20, items: { type: 'string' },
      description: 'LITERAL output lines proving the BEFORE state - these are quoted verbatim in the issue',
    },
    baseline: {
      type: 'array', maxItems: 20, items: { type: 'string' },
      description: 'one line per tier: "<tier> = <observed>" as measured RIGHT NOW, before any edit',
    },
    baseline_matches_expected: { type: 'boolean', description: 'false if a tier already differs from the documented baseline' },
    notes: { type: 'string' },
  },
}

const PLAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['code_change_needed', 'fix_summary', 'files_to_touch', 'test_rows', 'sabotage_variants', 'decisions', 'user_visible_change'],
  properties: {
    code_change_needed: { type: 'boolean', description: 'false for a pure DECIDE / documentation item' },
    fix_summary: { type: 'string' },
    files_to_touch: { type: 'array', maxItems: 20, items: { type: 'string' } },
    test_rows: {
      type: 'array', maxItems: 30, items: { type: 'string' },
      description: 'one line per new check: what it asserts and which existing suite file it joins',
    },
    sabotage_variants: {
      type: 'array', maxItems: 8,
      items: {
        type: 'object', additionalProperties: false,
        required: ['name', 'how', 'predicted_red'],
        properties: {
          name: { type: 'string' },
          how: { type: 'string', description: 'how to neutralize - rename the callee to a no-op macro, never a prefixed comment' },
          predicted_red: { type: 'array', maxItems: 12, items: { type: 'string' } },
        },
      },
    },
    decisions: {
      type: 'array', maxItems: 10, items: { type: 'string' },
      description: 'each: the choice, the rung of the ladder used (R1/R2/R3), and the rejected alternative',
    },
    user_visible_change: { type: 'boolean' },
  },
}

const RED_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['test_files', 'is_red', 'red_for_measured_reason', 'evidence'],
  properties: {
    test_files: { type: 'array', maxItems: 20, items: { type: 'string' } },
    is_red: { type: 'boolean' },
    red_for_measured_reason: { type: 'boolean', description: 'false if it fails for an unrelated reason - that is a broken test, not a RED' },
    evidence: { type: 'array', maxItems: 12, items: { type: 'string' }, description: 'literal failing lines' },
  },
}

const IMPL_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['built', 'changed_files', 'new_checks_green', 'tier_counts_after', 'evidence', 'notes'],
  properties: {
    built: { type: 'boolean' },
    changed_files: { type: 'array', maxItems: 30, items: { type: 'string' } },
    new_checks_green: { type: 'boolean' },
    tier_counts_after: { type: 'array', maxItems: 20, items: { type: 'string' } },
    evidence: { type: 'array', maxItems: 12, items: { type: 'string' } },
    notes: { type: 'string' },
  },
}

const TIER_VERIFY_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['clean', 'per_tier', 'regressions'],
  properties: {
    clean: { type: 'boolean', description: 'true only if every tier is at or above its baseline and no NEW failure appeared' },
    per_tier: { type: 'array', maxItems: 20, items: { type: 'string' }, description: '"<tier>: baseline -> after (verdict)"' },
    regressions: { type: 'array', maxItems: 15, items: { type: 'string' } },
  },
}

const SABOTAGE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['trustworthy', 'variants', 'missing_predicted_reds', 'restore_clean', 'baseline_green_after_restore'],
  properties: {
    trustworthy: { type: 'boolean', description: 'false if any restore was partial, make did not rebuild, or the restored baseline was not re-asserted green' },
    variants: { type: 'array', maxItems: 10, items: { type: 'string' }, description: '"<name>: predicted <n> red, observed <n> red - <which>"' },
    missing_predicted_reds: { type: 'array', maxItems: 15, items: { type: 'string' }, description: 'predicted reds that did NOT appear - these are holes in the test' },
    restore_clean: { type: 'boolean', description: 'grep -rn SABOTAGE src/ is empty' },
    baseline_green_after_restore: { type: 'boolean' },
  },
}

const REFUTE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['refuted', 'central_claim', 'attacks', 'residual_risks'],
  properties: {
    refuted: { type: 'boolean', description: 'true if the fix does NOT do what it claims. Default to true when genuinely uncertain.' },
    central_claim: { type: 'string' },
    attacks: { type: 'array', maxItems: 12, items: { type: 'string' }, description: 'each attempted counterexample and its outcome' },
    residual_risks: { type: 'array', maxItems: 10, items: { type: 'string' } },
  },
}

const WRITEUP_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'commit', 'tests_line', 'new_issues', 'result_line', 'evidence', 'blocker'],
  properties: {
    status: { type: 'string', enum: ['x', 'F', 'D', 'E'] },
    commit: { type: 'string', description: 'short sha, or the literal word none' },
    tests_line: { type: 'string', description: 'suites + counts, one line, e.g. "shape_draw 421->421, doors 115->121, wireedit ALL PASS"' },
    new_issues: { type: 'string', description: 'comma-separated issue numbers filed, or the literal word none' },
    result_line: { type: 'string', description: 'ONE line. If status is E, this must BE the question the user must answer.' },
    evidence: { type: 'array', maxItems: 3, items: { type: 'string' } },
    blocker: { type: 'string', description: 'blocker for F/D, else the literal word none' },
  },
}

/* ------------------------------------------------------------------ */
/* helpers                                                             */
/* ------------------------------------------------------------------ */

function block(title, obj) {
  return '=== ' + title + ' ===\n' + JSON.stringify(obj, null, 1)
}

function esc(s) {
  return String(s === undefined || s === null ? '' : s).split('|').join('\\|').split('\n').join(' ').slice(0, 400)
}

/* ------------------------------------------------------------------ */
/* the run                                                             */
/* ------------------------------------------------------------------ */

let receipt = null
let carried = { status: 'F', commit: 'none', tests_line: 'not reached', new_issues: 'none', result_line: 'crew aborted before write-up', evidence: [], blocker: 'crew aborted' }

try {
  /* ---------------- Scout ---------------- */
  phase('Scout')
  const scout = await agent([
    COMMON,
    '',
    'YOU ARE THE SCOUT. Read-only. Propose NO fix.',
    'Deliver: (a) the exact code paths that implement the behaviour named in the brief, as file:line',
    'anchors; (b) every existing test that touches this area; (c) an exact headless command that',
    'should exhibit the defect; (d) prose describing what the code does TODAY - not what it should',
    'do; (e) the seams a fix would disturb (callers, Tcl call sites, replay/action-log surfaces).',
    '',
    'If the brief names an issue number, read doc/claude/issues/ for that file first and take its',
    'claims as UNVERIFIED HYPOTHESES - several issues in this backlog were filed off code reading and',
    'never measured. Say explicitly which of the issue claims you could and could not corroborate in',
    'the source.',
    'If the brief names several issue numbers, cover ALL of them and look hard for the ONE mechanism',
    'that would close most of the batch - that consolidation is the point of the batched items.',
    'Grep widely (rg over src/, tests/, doc/claude/) rather than guessing at filenames.',
  ].join('\n'), { label: 'scout:' + ID, phase: 'Scout', schema: SCOUT_SCHEMA })

  if (!scout) throw new Error('scout produced nothing')

  /* ---------------- Measure ---------------- */
  phase('Measure')
  const measure = await agent([
    COMMON,
    '',
    block('SCOUT REPORT', scout),
    '',
    'YOU ARE THE MEASURE AGENT. Three jobs, in this order.',
    '',
    'JOB 0 - BINARY FRESHNESS (the ONE build you are allowed, and only if it is needed).',
    'A previous crew may have reverted sources without rebuilding, leaving ' + REPO + '/src/xschem',
    'containing code that is no longer in the tree - every number you then measure would be a lie.',
    'Check whether any .c/.h/.y/.l under ' + REPO + '/src/ is newer than ' + REPO + '/src/xschem, and',
    'whether git diff HEAD -- src/ is empty. If the binary is stale, run cd ' + REPO + '/src && make',
    'ONCE and record that you did so in notes. You are the only agent alive in this phase, so this',
    'cannot collide with another build. If the binary is already fresh, do NOT build.',
    'After JOB 0 you may not build again for any reason.',
    '',
    'JOB 1 - RECORD THE TIER BASELINE AS IT IS RIGHT NOW, before anything is edited. Run every tier',
    'in the tier list above against the CURRENT ./src/xschem binary and record the observed number or',
    'verdict for each. Report a tier honestly even if it already differs from the documented',
    'baseline; set baseline_matches_expected=false and name the drift in notes. This recorded set is',
    'what the Verify agents diff against, so it must be real measurement, not a copy of the table.',
    'Skip test_fluid_editing unless this item touches move.c.',
    '',
    'JOB 2 - REPRODUCE THE DEFECT HEADLESSLY. Write a throwaway .tcl driver under',
    '/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_' + ID + '/ if you need one (NOT in the repo).',
    'Capture LITERAL output lines that prove the BEFORE state. The issue write-up quotes these',
    'verbatim, so they must be real transcript lines, never paraphrase.',
    '',
    'If the defect DOES NOT reproduce, that is a legitimate and valuable outcome: set',
    'reproduced=false and make before_transcript the evidence of NON-reproduction (what you ran, what',
    'you expected, what you actually got). The item will end F and the issue will be updated to say',
    'so. Do not manufacture a reproduction to keep the crew busy.',
    '',
    'For a pure DECIDE or infrastructure item where "the defect" is a missing capability rather than',
    'a misbehaviour, set reproduced=true and let before_transcript be the literal evidence of the',
    'current state (e.g. the command that shows the suite is not gated, the grep count of call sites).',
  ].join('\n'), { label: 'measure:' + ID, phase: 'Measure', schema: MEASURE_SCHEMA })

  if (!measure) throw new Error('measure produced nothing')

  const baselineText = block('MEASURED BASELINE + BEFORE STATE', measure)

  if (!measure.reproduced) {
    /* -------- not reproduced: straight to write-up as F -------- */
    phase('Writeup')
    const wu = await agent([
      COMMON, '', block('SCOUT REPORT', scout), '', baselineText,
      '',
      'YOU ARE THE WRITE-UP AGENT. The defect DID NOT REPRODUCE. Do NOT attempt a fix.',
      'Update the relevant issue file under doc/claude/issues/ (create it only if the brief names an',
      'issue that has no file) with a NOT REPRODUCED section quoting the measurement transcript',
      'verbatim, stating exactly what was run and what was observed, and either narrowing the issue to',
      'the part that does still hold or marking it NOT A DEFECT with the reasoning.',
      'Then git add ONLY the doc paths you touched and git commit. This is a docs-only commit and is',
      'legitimate; the item status is still F because no defect was fixed.',
      'Commit message in house style, subject line "docs(issues): NNNN not reproduced - <what was',
      'measured>", body = what was measured, how, and what remains open.',
      'Trailers, exactly:',
      'Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>',
      'Claude-Session: ' + SESSION_URL,
      'NEVER git push. Leave the working tree clean of scratch files.',
      'Set status="F", blocker="did not reproduce", and make result_line say so in one line.',
    ].join('\n'), { label: 'writeup:' + ID, phase: 'Writeup', schema: WRITEUP_SCHEMA })
    carried = wu || carried
  } else {
    /* ---------------- Plan ---------------- */
    phase('Plan')
    const plan = await agent([
      COMMON, '', block('SCOUT REPORT', scout), '', baselineText,
      '',
      'YOU ARE THE PLANNER. Decide the fix. Do not write it.',
      'Deliver: the fix in prose; the exact files to touch; the test rows (one line each: what the',
      'check asserts and which suite file it joins - PREFER extending an existing suite over inventing',
      'a new file); the sabotage variants NAMED UP FRONT with, for each, how to neutralize the fix',
      '(rename the callee to a no-op macro - a /* SABOTAGE */ comment PREFIXED to a line does NOT',
      'disable the call on it) and which specific checks that variant must turn red; and every',
      'decision the docs do not already settle, each tagged with the ladder rung R1/R2/R3 you used and',
      'the alternative you rejected.',
      '',
      'Set code_change_needed=false ONLY for a genuine DECIDE-or-document item - and in that case the',
      'deliverable is a WRITTEN, RATIFIED decision in the issue file plus whatever doc updates make it',
      'permanent, not a shrug. Set user_visible_change=true if a user would notice a behaviour',
      'difference; that forces status E and the exact question must appear in your decisions list.',
      '',
      'Smallest blast radius wins. Gates go at the VERBS, never at the shared per-click primitive.',
      'Never gate a pure-commit coordinate form. Do not refactor beyond the item.',
    ].join('\n'), { label: 'plan:' + ID, phase: 'Plan', schema: PLAN_SCHEMA })

    if (!plan) throw new Error('plan produced nothing')
    const planText = block('PLAN', plan)

    let red = null
    let impl = null

    if (plan.code_change_needed) {
      /* ---------------- RED ---------------- */
      phase('RED')
      red = await agent([
        COMMON, '', block('SCOUT REPORT', scout), '', baselineText, '', planText,
        '',
        'YOU ARE THE RED AGENT. Write the failing checks FIRST, before any production code exists.',
        'You may NOT edit any file under src/ except test scripts. You may NOT run make.',
        'Add the planned test rows to the suites named in the plan. Match the surrounding house style',
        'of that suite exactly (numbering, the check helper it uses, the pass/fail counter).',
        'Then RUN them against the current unmodified binary and confirm they are red.',
        '',
        'CRITICAL: a check that fails for an unrelated reason (typo, wrong path, harness error) is a',
        'BROKEN TEST, not a RED. Read each failure line and confirm it is red for exactly the reason',
        'the Measure agent recorded. Set red_for_measured_reason accordingly and quote the literal',
        'failing lines as evidence.',
        'If a planned check turns out to be already GREEN before the fix, say so loudly in evidence -',
        'that check proves nothing and the plan needs to know.',
      ].join('\n'), { label: 'red:' + ID, phase: 'RED', schema: RED_SCHEMA })

      /* ---------------- Implement ---------------- */
      phase('Implement')
      impl = await agent([
        COMMON, '', block('SCOUT REPORT', scout), '', baselineText, '', planText, '',
        block('RED REPORT', red || { note: 'RED agent produced nothing - write the checks yourself first' }),
        '',
        'YOU ARE THE IMPLEMENT AGENT. You are the ONLY agent in this crew permitted to run make.',
        'Implement the planned fix. C89 only. Use _ALLOC_ID_ as the literal first argument to',
        'my_malloc/my_realloc/my_strdup - never hand-number it. A new .c file needs an OBJ entry and a',
        'compile rule in src/Makefile. Keep C-side and Tcl-side mirrored config vars in sync.',
        '',
        'Build with: cd ' + REPO + '/src && make 2>&1 | tail -40',
        'Then run the new checks and confirm they are GREEN, then re-run the full tier list and record',
        'the counts. Do not run two builds at once and do not background a build.',
        '',
        'If the fix turns out to need more than the plan allowed, do the smallest thing that makes the',
        'red checks green and record the overrun in notes. If you discover a SEPARATE defect, do not',
        'fix it silently - note it in notes so the Write-up agent files it as a new issue from 0350 up.',
        'If the build fails and you cannot get it green, set built=false and explain - do NOT leave a',
        'broken tree; revert your edits so the tree still compiles.',
      ].join('\n'), { label: 'impl:' + ID, phase: 'Implement', schema: IMPL_SCHEMA })
    }

    const implText = block('IMPLEMENT REPORT', impl || { note: 'no code change - decide/document item' })

    /* ---------------- Verify (3 in parallel, none wrote the fix) ---------------- */
    phase('Verify')
    const verifies = await parallel([
      () => agent([
        COMMON, '', baselineText, '', planText, '', implText,
        '',
        'YOU ARE VERIFY-A (TIER DIFF). You did not write the fix. You may NOT run make - run the',
        'binary as it stands at ' + REPO + '/src/xschem.',
        'Re-run EVERY tier in the tier list and diff against the MEASURED BASELINE above (not against',
        'the documented table - the baseline the Measure agent recorded is the truth for this run).',
        'For each tier report "baseline -> after" and a verdict. A count going UP is fine when the',
        'item added checks; a count going DOWN, or any NEW failure line, is a regression.',
        'Cross-check every failure against the KNOWN-RED list before calling it a regression.',
        'Set clean=false if there is any new failure at all.',
      ].join('\n'), { label: 'verify-tiers:' + ID, phase: 'Verify', schema: TIER_VERIFY_SCHEMA }),

      () => agent([
        COMMON, '', baselineText, '', planText, '', implText,
        '',
        'YOU ARE VERIFY-B (SABOTAGE). You did not write the fix. You ARE permitted to run make, but',
        'ONLY sequentially and ONLY as part of this sabotage loop - never at the same time as anyone',
        'else. (Verify-A and Verify-C are forbidden to build; you own the build lock for this phase.)',
        'If the plan set code_change_needed=false there is nothing to sabotage: return',
        'trustworthy=true, variants=["n/a - no code change"], restore_clean=true,',
        'baseline_green_after_restore=true and stop.',
        '',
        'For each planned sabotage variant, in sequence:',
        '  1. Back up EVERY file the patch touches (all of them, not just the one you are editing).',
        '  2. Neutralize the fix by renaming the callee to a no-op macro. A /* SABOTAGE */ comment',
        '     PREFIXED to a line does NOT disable the call on it - that trick silently proves nothing.',
        '  3. Rebuild, run the affected suites, record which checks went red.',
        '  4. Restore with cp + touch (NOT cp -p). A preserved mtime makes make a no-op and every',
        '     later number is then measured against the PREVIOUS sabotage binary.',
        '  5. Rebuild again and RE-ASSERT the restored baseline is green before publishing any number.',
        'After the loop assert grep -rn SABOTAGE ' + REPO + '/src/ is empty.',
        '',
        'Report, for each variant, predicted red vs observed red. Any PREDICTED red that does NOT',
        'appear is the finding that matters - list every one of them in missing_predicted_reds, because',
        'it means the check does not actually cover the mechanism it claims to.',
        'Set trustworthy=false if any restore was partial, any rebuild was skipped, or the restored',
        'baseline was not re-asserted green.',
      ].join('\n'), { label: 'verify-sabotage:' + ID, phase: 'Verify', schema: SABOTAGE_SCHEMA }),

      () => agent([
        COMMON, '', block('SCOUT REPORT', scout), '', baselineText, '', planText, '', implText,
        '',
        'YOU ARE VERIFY-C (ADVERSARY). You did not write the fix. You may NOT run make and may NOT',
        'edit any file. Your job is to REFUTE the fix\'s central claim, not to bless it.',
        'State the central claim in one sentence, then attack it: hunt for the input, ordering,',
        'hierarchy depth, window/tab, undo/redo path, action-log replay path, or Tcl call site where',
        'the old wrong behaviour still happens. Read the diff (git diff) and reason about what it does',
        'NOT cover. Drive the existing binary headlessly to try to produce a counterexample.',
        'Check specifically: does the fix gate a pure-commit coordinate form (forbidden)? does it sit',
        'at the shared per-click primitive instead of the verbs (forbidden)? does an aborted path still',
        'lie about the modify flag? does a teardown fail to name what it tears down?',
        'Default refuted=true when you are genuinely uncertain. A confident pass requires that you',
        'tried and failed to break it, and the attacks list must show the attempts.',
      ].join('\n'), { label: 'verify-adversary:' + ID, phase: 'Verify', schema: REFUTE_SCHEMA }),
    ])

    const tierV = verifies[0]
    const sabV = verifies[1]
    const advV = verifies[2]

    /* ---------------- Write-up + commit ---------------- */
    phase('Writeup')
    const wu = await agent([
      COMMON, '', block('SCOUT REPORT', scout), '', baselineText, '', planText, '', implText, '',
      block('VERIFY-A TIERS', tierV || { note: 'verify-A produced nothing - treat tiers as UNVERIFIED' }), '',
      block('VERIFY-B SABOTAGE', sabV || { note: 'verify-B produced nothing - treat sabotage as UNTRUSTWORTHY' }), '',
      block('VERIFY-C ADVERSARY', advV || { note: 'verify-C produced nothing - treat the claim as UNREFUTED-UNTESTED' }),
      '',
      'YOU ARE THE WRITE-UP AND COMMIT AGENT. You decide this item\'s final status. Be honest.',
      '',
      'STATUS RULES:',
      '  x = fixed, tiers clean, sabotage trustworthy, adversary did not refute, committed.',
      '  E = it landed and is committed, but a human must look: the plan set user_visible_change=true',
      '      with no prior ratification, OR the only proof is a GUI screenshot. result_line must BE',
      '      the one-line question the user has to answer.',
      '  F = not fixed / broke something / sabotage untrustworthy / adversary refuted. Then REVERT the',
      '      code changes so the tree is clean and compiles, commit NOTHING but (optionally) the issue',
      '      write-up recording what was measured, and say why in blocker.',
      '  D = blocked before a fix was possible. Nothing committed except the issue note.',
      'If VERIFY-A reports a regression, or VERIFY-B reports trustworthy=false, or VERIFY-C reports',
      'refuted=true, you may NOT claim x. Downgrade and say why. Never round a partial result up.',
      '',
      'DELIVERABLES:',
      '1. The issue file(s) under doc/claude/issues/. For an existing issue, append a resolution',
      '   section; for anything measured-and-not-fixed, create a NEW issue numbered from 0350 up',
      '   (create the stub file IMMEDIATELY to claim the number). Quote the Measure agent\'s BEFORE',
      '   transcript lines verbatim, then the AFTER lines. Record every decision with its ladder rung',
      '   and its rejected alternative. Record the sabotage matrix including any predicted red that did',
      '   not appear, and the adversary\'s residual risks under a "still open" heading.',
      '2. Doc updates the change EARNS - doc/claude/WIRING.md if wires were touched (mandatory in that',
      '   case), the relevant doc/claude/specs/ file, doc/claude/FAQ.md (newest entry on top) if a',
      '   design question was settled. Do not touch docs the change did not earn.',
      '3. git add the EXACT paths (never git add -A, never git add .) and git commit. The repo has a',
      '   large untracked scatter that must NOT be swept in. Verify with git status --short before and',
      '   after that you added only your paths.',
      '   Commit subject in house style: type(scope): imperative summary (issue NNNN)',
      '   Body: what was measured BEFORE (quote a line), what changed, why, what is still open.',
      '   Trailers, exactly these two lines at the end:',
      '   Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>',
      '   Claude-Session: ' + SESSION_URL,
      '   NEVER git push. NEVER open a PR.',
      '4. Delete any scratch files your crew left inside the repo.',
      '5. Do NOT touch ' + LEDGER + '. A dedicated Ledger agent appends the run row after you, from',
      '   the receipt fields you return. Writing a row yourself produces a duplicate.',
      '',
      'Then return the receipt fields. tests_line is ONE line of suite names with baseline->after',
      'counts. evidence is at most 3 literal lines. Keep every field short - this is the only thing',
      'that crosses back to the driver.',
    ].join('\n'), { label: 'writeup:' + ID, phase: 'Writeup', schema: WRITEUP_SCHEMA })

    carried = wu || carried
  }
} catch (e) {
  carried = {
    status: 'F', commit: 'none', tests_line: 'not reached', new_issues: 'none',
    result_line: 'crew aborted: ' + String(e && e.message ? e.message : e).slice(0, 200),
    evidence: [], blocker: 'crew exception',
  }
}

/* ---------------- Ledger (always runs) ---------------- */
phase('Ledger')
const row = '| ' + ID + ' | ' + esc(carried.status) + ' | ' + esc(carried.commit) + ' | ' +
  esc(carried.tests_line) + ' | ' + esc(carried.new_issues) + ' | ' + esc(carried.result_line) + ' |'

await agent([
  'You are the LEDGER agent for item ' + ID + '. You do exactly one thing and nothing else.',
  'Append this single line, verbatim, as the last line of ' + LEDGER + ':',
  '',
  row,
  '',
  'Rules: APPEND only - never rewrite, reorder or reformat any existing line in that file.',
  'Use a shell append (printf ... >> file) or read-then-write-with-the-line-added. Ensure the file',
  'ends with exactly one newline after your row and that your row is the last table row.',
  'If a row for ' + ID + ' already exists, leave it and append yours anyway - the driver reads the',
  'last line. Do NOT git commit the ledger. Do NOT touch any other file. Do NOT run tests or make.',
  'Reply with the literal word DONE and nothing else.',
].join('\n'), { label: 'ledger:' + ID, phase: 'Ledger' })

receipt = [
  'id: ' + ID,
  'status: ' + carried.status,
  'commit: ' + carried.commit,
  'suites: ' + carried.tests_line,
  'new issues: ' + carried.new_issues,
  'result: ' + carried.result_line,
].concat((carried.evidence || []).slice(0, 3).map(function (e) { return 'evidence: ' + String(e).slice(0, 200) }))
  .concat(['blocker: ' + (carried.blocker || 'none')])
  .join('\n')

return receipt
