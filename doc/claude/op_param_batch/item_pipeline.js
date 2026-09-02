export const meta = {
  name: 'op-param-crew',
  description: 'Run one item of the OP-parameter-lists batch (1244 declutter / 1245 Results Display Window) end to end: scout, measure, plan, RED, implement, verify, write-up, commit, ledger',
  whenToUse: 'Driver dispatch of a single item (A1 A2 A3 B1 B2 B3 B4 B5) of the OP-parameter-lists batch on branch fluid-editing',
  phases: [
    { title: 'Scout', detail: 'locate code, existing tests, exact current behaviour' },
    { title: 'Measure', detail: 'record the BEFORE state and the tier baseline as observed right now' },
    { title: 'Plan', detail: 'the change, the test rows, sabotage variants, ratification questions' },
    { title: 'RED', detail: 'write the failing checks first and confirm they are red' },
    { title: 'Implement', detail: 'the ONLY agent allowed to run make' },
    { title: 'Verify', detail: '3 parallel: tier diff, sabotage matrix, adversarial refutation' },
    { title: 'Writeup', detail: 'issue/spec/plan updates, git add + git commit' },
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
const LEDGER = REPO + '/doc/claude/op_param_batch/LEDGER.md'
const SPEC = 'doc/claude/specs/op_param_lists.md'
const PLAN = 'doc/claude/op_param_batch/PLAN.md'
const SESSION_URL = 'https://claude.ai/code/session_01178ETXPaQzMeMf8iEYEeaY'
const DECISIONS = 'doc/claude/op_param_batch/DECISIONS.md'
const MEASURED = 'doc/claude/code_analysis/1244_op_param_list_measurements.md'

const COMMON = [
  'You are one agent of an autonomous crew working item ' + ID + ' of an unattended fix run.',
  'This batch implements TWO FEATURES the user asked for on 2026-09-02 and then RULED ON, in two',
  'rounds of questions, before any code was written. It is not a defect batch. The rulings are',
  'D-1 .. D-8 in ' + DECISIONS + ' and they are BINDING: where a ruling and the spec',
  'disagree, the ruling wins and the spec is wrong. If your item seems to need something a ruling',
  'forbids, STOP and say so in your write-up - do not implement around it.',
  'Repository: ' + REPO + '   Branch: fluid-editing   (already checked out; do NOT switch branches)',
  '',
  'ITEM ' + ID + ' BRIEF (verbatim from the driver):',
  BRIEF,
  '',
  '=== READ THESE FIRST, IN FULL ===',
  '  ' + DECISIONS + '   - READ THIS FIRST AND IN FULL. Eight rulings, one table.',
  '      D-4 and D-5 in particular forbid a whole class of "improvement": you may NOT add a',
  '      `show` parse, a per-model parameter catalogue, or a probe-and-prune warm-up to make',
  '      key 3 look richer. All three were measured and all three were rejected by the user.',
  '  ' + SPEC + '   - the design. Section 0 (the rulings), 3 (what was MEASURED, including',
  '      3.6 on what ngspice will and will not publish), 5 (invariants) and 6 (the twelve',
  '      landmines) are binding on you.',
  '  ' + MEASURED + ' - every number the design rests on, each with the',
  '      command that produced it. If you doubt one, RE-RUN IT rather than reasoning about it.',
  '  ' + PLAN + '   - the authoritative item list. Find YOUR item (A1 A2 A3 B1 B2 B3 B4 B5) and',
  '      follow its Files / Deliver / Acceptance / Risk cells literally, and do not do a later',
  '      step\'s work. If your item is an ISSUE NUMBER, read doc/claude/issues/<NNNN>-*.md IN FULL -',
  '      it carries the measurement, the recommended option, the landmines and the acceptance rows,',
  '      and it is as binding on you as a plan step. Where the issue names a RECOMMENDED option and',
  '      says why the others were rejected, take the recommendation unless your own measurement',
  '      refutes its reasoning - and if it does, say exactly which sentence it refutes.',
  '  doc/claude/op_param_batch/CREW_BRIEF.md - the short form of the rules below.',
  '  doc/claude/op_param_batch/LEDGER.md - the baseline, the debts, and the carried risks.',
  '      Your ledger row goes here; append it yourself.',
  '',
  '=== THE NEAREST WORKING PRECEDENTS, WHICH YOU SHOULD COPY RATHER THAN INVENT ===',
  '  src/op_annot.tcl        - the descriptor registry (register / descriptor / type / devpath /',
  '      vector / text). The `params` list IS the annotation list; `match` IS the device-flavor',
  '      narrowing. Both features plug in here. Do not build a second store.',
  '  src/actions.c:1228-1290 - annot_class_free + annot_content_class + set_text_flags. A text is',
  '      already classified FROM ITS OWN CONTENT, on a WHOLE-STRING match, and only when the',
  '      explicit hide= chain set no bit. Item A2 is the same shape, one class further.',
  '  src/actions.c:1541      - text_hidden(flags, ctx). ELEVEN call sites, not ten; the eleventh',
  '      is actions.c:1832 inside get_annot_overlay(), passing a SYNTHETIC literal. Verify that',
  '      yourself before you touch this function.',
  '  src/cmdmode.tcl + ASE Direct Plot (Ctrl-4) - the canvas command-mode precedent for item B4.',
  '  xschem instance_at <x> <y> (scheduler.c:6919) - the READ-ONLY coordinate pick. It selects',
  '      nothing. That is exactly what verb-noun mode needs; do not use select_at.',
  '  ase::sim_write_conf / sim_write_body (src/ase.tcl) - the write-beside-and-move idiom',
  '      (issue 0937) for item B2s settings file.',
  '',
  '=== HARD RULES FOR EVERY AGENT IN THIS CREW ===',
  '1. NO HUMAN IS WATCHING. Never ask a question, never wait for approval. Decide using the',
  '   ladder below and record the decision in writing.',
  '2. ONLY the Implement agent may run make / cmake / any build. If you are not the Implement',
  '   agent and you think you need to rebuild, you are wrong - use the binary at ' + REPO + '/src/xschem',
  '   as it stands. Two concurrent builds OOM this ~7.8GB WSL box.',
  '2b. ./configure is a build action and follows the same rule, with one addition: the Implement',
  '   agent MUST run ./configure (from ' + REPO + ', then rebuild) whenever the step edited',
  '   src/Makefile.in - and MUST NOT otherwise. src/Makefile and src/config.h are GENERATED,',
  '   gitignored and have no self-regeneration rule, so a tracked-correct Makefile.in coexists',
  '   with a stale generated Makefile and every in-tree test still passes. Issue 0424: the',
  '   install list lost op_annot.tcl that way and the INSTALLED binary segfaulted at startup',
  '   (exit 139, via 0423) while all 275 in-tree checks stayed green. Receipt required in notes:',
  '   the before and after of  grep -c <newfile> src/Makefile  (0 then 2 - install + uninstall).',
  '   (Many steps in this plan are PURE TCL and need no build at all - xschem sources .tcl at',
  '   startup, so a Tcl-only change takes effect on the next launch with no make.)',
  '3. NEVER git push. NEVER open a PR. NEVER git checkout/switch/reset --hard a branch.',
  '4. Default to headless: ./src/xschem --nogui --pipe -q --nolog --script <t>.tcl',
  '   A suite that genuinely needs X runs under xvfb: GUI_GATE=0 xvfb-run -a <cmd>. That is correct,',
  '   not a cheat - the gate protects the USER display, and xvfb is not the user display.',
  '   Do NOT set GUI_GATE=0 globally and do NOT touch ~/.claude/gui_test_gate/control.',
  '   If a human must eyeball pixels: screenshot to doc/claude/evidence/, and the step is status E.',
  '5. Every file you create under doc/claude/ must be committed by the Write-up agent, not left',
  '   untracked. Leave no stray scratch files in the repo; use',
  '   /tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_' + ID + ' for scratch.',
  '6. The repo has a LARGE untracked scatter (untitled*.sch, _g*/ , fixtures, .agents/). Never',
  '   git add -A and never git add . - add exact paths only, and check git status --short before',
  '   and after. Untracked untitled*.sch in the repo root turns three tests red; do not create any.',
  '',
  '=== TIER BASELINE: MEASURE IT, DO NOT ASSUME IT ===',
  'The baseline IS recorded, in ' + LEDGER + ': 364 pass / 11 fail / 0 crash-timeout / 2 skip of 377',
  'The Measure agent runs the tiers below and whatever it observes IS the baseline of record for',
  'this step; Verify-A diffs against that, never against a remembered number.',
  '  T1  cd ' + REPO + '/tests && tclsh run_regression.tcl        -> count FAIL / GOLD? / FATAL lines',
  '  T2  ' + REPO + '/tests/headless/run.sh                       -> goldens + HARNESS verdict',
  '  T3  any tests/headless/test_*.tcl suite whose subject this step touches (name them)',
  '  T4  cd ' + REPO + '/src && make                              -> must succeed (Implement agent only)',
  'Reading results.log: a FAIL ending a line, GOLD?, RESULT?, or a leading FATAL counts.',
  'couldn\'t execute "xschem" or exit 127 anywhere means the binary never launched and NOTHING in',
  'that run is meaningful. create_save / open_close / netlisting have NO committed gold baseline and',
  'can only report NOGOLD - they verify nothing; the trustworthy signal is the headless cases.',
  '',
  '=== THE MEASURED SIMULATOR RULES (spec section 3) - BINDING ===',
  '  R1. gm / gds / vth / vdsat / cgg exist in the raw ONLY if the deck saved them explicitly,',
  '      one card per device per parameter. `save all` does NOT include them.',
  '  R2. Any explicit `save` CANCELS the implicit save-everything. A generated block must also',
  '      carry `save all` or every node voltage disappears from the raw.',
  '  R3. Vector shapes are fixed: kind 0 -> i(<dev>[p]), kind 1 -> bare <dev>[p], kind 2 ->',
  '      v(<dev>[p]). Same convention as get_fqdevice() (token.c:4514) modelparam 0/1/2.',
  'These were measured with /usr/bin/ngspice on throwaway decks. If your step depends on one of',
  'them, RE-MEASURE it rather than trusting this paragraph, and say what you observed.',
  '',
  '=== THE INVARIANTS (spec section 5) - APPLY IN ORDER, AND SAY WHICH ONE YOU USED ===',
  '  I1. ONE name builder (op_annot::vector), TWO consumers (save cards, display). Never two',
  '      independent builders - when they drift the failure is SILENT.',
  '  I2. A generated save block always carries `save all` (rule R2).',
  '  I3. A missing vector renders BLANK. Not 0, not NaN on screen, not the previous run\'s number.',
  '      Precedent: save.c RULING D5-1 - a plausible wrong number on a schematic is worse than none.',
  '  I4. The overlay never modifies the schematic: no instance placed, no set_modify, nothing',
  '      written to the .sch.',
  '  I5. A user\'s op_annot::register in their own rc overrides the PDK\'s, and takes effect on',
  '      redraw - no restart, no rebuild.',
  '  I6. The hierarchy walk restores no_draw, no_undo, keep_symbols and the original sch_path on',
  '      EVERY exit path including error paths. sg13g2_hier_sch_expand\'s go_back pairing is the',
  '      reference.',
  '  I7. hide=true / hide=instance semantics are unchanged for every existing symbol in every',
  '      library.',
  '',
  '=== DECISION LADDER (when the docs do not settle a choice) ===',
  '  L1. Apply an invariant I1-I7 above, and name which one.',
  '  L2. If none settles it: pick the option that is LEAST SURPRISING to a user reading a',
  '      schematic and SMALLEST in blast radius, implement it, and write both the decision AND',
  '      the rejected alternative into the issue/spec.',
  '  L3. If the choice changes USER-VISIBLE behaviour and no prior ratification covers it: still',
  '      implement it, then the step is status E and the exact question goes in the ledger row.',
  '',
  '=== NEW ISSUE NUMBERING ===',
  '  Number new issues from 0619 upward (0614-0618 are this batch and already exist). HARD CEILING: do NOT file past 0499.',
  '  0500-0599 are RESERVED for the fluid-editing branch, so the number after 0499 is 0600 - skip',
  '  the whole 05xx block. Check `ls doc/claude/issues/` for the highest taken before claiming. Claim a number',
  '  by creating doc/claude/issues/NNNN-<slug>.md IMMEDIATELY as a stub before doing the work, so a',
  '  later crew in this same run cannot collide. File anything measured and not fixed. Never fix a',
  '  discovered defect silently.',
  '  Two issues are ALREADY SPECIFIED as work for step S12 - do not file them earlier under other',
  '  numbers: 0418 (@spice_get_modelparam_<p>(<dev>) and @spice_get_modelvoltage_<p>(<dev>) are',
  '  matched by the regex at token.c:4646 then silently produce nothing) and 0419 (the bare generic',
  '  tokens build i(@x...[i]) for every spiceprefix=X subcircuit-wrapped PDK device).',
  '',
  '=== PROJECT ORIENTATION ===',
  '  Almost all state hangs off the global Xschem_ctx *xctx (xschem.h). The C core exposes',
  '  functionality through one Tcl command dispatched by scheduler() in scheduler.c; GUI events',
  '  arrive as xschem callback <win> <event> ... into callback.c. src/xschem.tcl is the GUI layer',
  '  and mirrors many C config vars (search MIRRORED IN TCL in xschem.h).',
  '  Allocations use my_malloc/my_realloc/my_strdup with the literal placeholder _ALLOC_ID_ as the',
  '  first argument - write _ALLOC_ID_, never a hand-picked number.',
  '  C89 only. src/Makefile lists objects explicitly in OBJ - a new .c file needs an OBJ entry and',
  '  a compile rule. A new .tcl file needs sourcing from src/xschem.tcl and an install rule.',
  '',
  '  ANNOTATION SUBSYSTEM ANCHORS (verified on this tree):',
  '    scheduler.c:2329   `xschem annotate_op [raw] [level] [sim_type]` - op -> dc -> tran fallback',
  '    save.c:1988        update_op() - point 0 into raw->cursor_b_val[] AND ngspice::ngspice_data',
  '    callback.c:1531    backannotate_at_cursor_b_pos() - the cursor-B live path',
  '    scheduler.c:10312  `xschem raw value <vector> -1` - THE value accessor (falls through to',
  '                       cursor_b_val[idx], i.e. the OP point or the cursor-B point)',
  '    scheduler.c:5150   `xschem get sim_sch_path` - hierarchy path from the raw load level',
  '    token.c:4451       spice_get_node(); token.c:4514 get_fqdevice(); token.c:4719 @path',
  '    token.c:5163       the bare @spice_get_current_/modelparam_/modelvoltage_ token branch',
  '    actions.c:1121     set_text_flags() - hide= parsing. An UNRECOGNISED hide= value sets no bit',
  '                       (strboolcmp, util.c:72, falls through to strcmp), so hide=op is inert',
  '                       until the class work lands. Verified.',
  '    The nine copy-pasted visibility tests: draw.c:868,1131,10266,10556 svgdraw.c:923,1290',
  '                       psprint.c:1205,1664 select.c:709 actions.c:4422',
  '    ase.tcl:3162/3166  render_deck emits `.save all` then `.save <expr>` per output row',
  '    ase_window.tcl:2854 the Outputs > Save All dialog (save_all_v / save_all_i)',
  '    cadence_style_rc:264 the Ctrl-4 override precedent (binds must end in `break`)',
  '    callback.c:7272    plain 6 is a no-op unless Control is held; Ctrl-<digit> selects a layer',
].join('\n')

/* ------------------------------------------------------------------ */
/* schemas                                                             */
/* ------------------------------------------------------------------ */

const SCOUT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['anchors', 'existing_tests', 'repro_command', 'current_behaviour', 'risk_notes', 'prototype_reuse'],
  properties: {
    anchors: {
      type: 'array', maxItems: 25, items: { type: 'string' },
      description: 'file:line anchors with a few words each',
    },
    existing_tests: {
      type: 'array', maxItems: 20, items: { type: 'string' },
      description: 'paths of tests that already cover or nearly cover this area',
    },
    repro_command: { type: 'string', description: 'exact headless command that shows the CURRENT state (feature absent / defect present)' },
    current_behaviour: { type: 'string', description: 'what the code does TODAY - not what it should do' },
    risk_notes: { type: 'array', maxItems: 10, items: { type: 'string' }, description: 'call sites / seams this step would disturb' },
    prototype_reuse: {
      type: 'array', maxItems: 12, items: { type: 'string' },
      description: 'which existing precedent in the tree this item should copy rather than reinvent, line-referenced, and what must change',
    },
  },
}

const MEASURE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['reproduced', 'before_transcript', 'baseline', 'baseline_matches_expected', 'notes'],
  properties: {
    reproduced: { type: 'boolean', description: 'true if the current state was actually observed (for a feature step: the capability is measurably absent)' },
    before_transcript: {
      type: 'array', maxItems: 20, items: { type: 'string' },
      description: 'LITERAL output lines proving the BEFORE state - quoted verbatim in the write-up',
    },
    baseline: {
      type: 'array', maxItems: 20, items: { type: 'string' },
      description: 'one line per tier: "<tier> = <observed>" as measured RIGHT NOW, before any edit',
    },
    baseline_matches_expected: { type: 'boolean', description: 'false if a tier looks broken for a reason unrelated to this step' },
    notes: { type: 'string' },
  },
}

const PLAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['code_change_needed', 'c_change_needed', 'fix_summary', 'files_to_touch', 'test_rows', 'sabotage_variants', 'decisions', 'user_visible_change'],
  properties: {
    code_change_needed: { type: 'boolean', description: 'false for a pure documentation step' },
    c_change_needed: { type: 'boolean', description: 'true only if a .c/.h edit and therefore a make is required' },
    fix_summary: { type: 'string' },
    files_to_touch: { type: 'array', maxItems: 20, items: { type: 'string' } },
    test_rows: {
      type: 'array', maxItems: 30, items: { type: 'string' },
      description: 'one line per new check: what it asserts and which suite file it joins',
    },
    sabotage_variants: {
      type: 'array', maxItems: 8,
      items: {
        type: 'object', additionalProperties: false,
        required: ['name', 'how', 'predicted_red'],
        properties: {
          name: { type: 'string' },
          how: { type: 'string', description: 'how to neutralize - rename the callee to a no-op, never a prefixed comment' },
          predicted_red: { type: 'array', maxItems: 12, items: { type: 'string' } },
        },
      },
    },
    decisions: {
      type: 'array', maxItems: 10, items: { type: 'string' },
      description: 'each: the choice, the ladder rung (L1 + which invariant / L2 / L3), and the rejected alternative',
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
    built: { type: 'boolean', description: 'true if make ran and succeeded; also true when no build was needed (Tcl-only step) - say which in notes' },
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
    clean: { type: 'boolean', description: 'true only if every tier is at or above its measured baseline and no NEW failure appeared' },
    per_tier: { type: 'array', maxItems: 20, items: { type: 'string' }, description: '"<tier>: baseline -> after (verdict)"' },
    regressions: { type: 'array', maxItems: 15, items: { type: 'string' } },
  },
}

const SABOTAGE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['trustworthy', 'variants', 'missing_predicted_reds', 'restore_clean', 'baseline_green_after_restore'],
  properties: {
    trustworthy: { type: 'boolean', description: 'false if any restore was partial, a needed rebuild was skipped, or the restored baseline was not re-asserted green' },
    variants: { type: 'array', maxItems: 10, items: { type: 'string' }, description: '"<name>: predicted <n> red, observed <n> red - <which>"' },
    missing_predicted_reds: { type: 'array', maxItems: 15, items: { type: 'string' }, description: 'predicted reds that did NOT appear - holes in the test' },
    restore_clean: { type: 'boolean', description: 'grep -rn SABOTAGE over src/ is empty' },
    baseline_green_after_restore: { type: 'boolean' },
  },
}

const REFUTE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['refuted', 'central_claim', 'attacks', 'residual_risks'],
  properties: {
    refuted: { type: 'boolean', description: 'true if the change does NOT do what it claims. Default to true when genuinely uncertain.' },
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
    tests_line: { type: 'string', description: 'suites + counts, one line' },
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
    'YOU ARE THE SCOUT. Read-only. Write nothing, build nothing, propose no implementation.',
    'Deliver: (a) the exact code paths this step must touch, as file:line anchors; (b) every',
    'existing test that touches this area; (c) an exact headless command showing the CURRENT state;',
    '(d) prose describing what the code does TODAY; (e) the seams this step would disturb.',
    '',
    'THE PRECEDENTS: this batch reinvents nothing. For your item, find the nearest thing already',
    'working in this tree and report line-referenced what to COPY and what must change. The',
    'candidates are listed in the READ THESE FIRST block above (op_annot.tcl descriptor registry,',
    'annot_content_class + set_text_flags, text_hidden and its ELEVEN call sites, cmdmode.tcl and',
    'ASE Direct Plot, xschem instance_at, ase::sim_write_conf). Reinventing one of those is a',
    'failed item. If none applies, say so in ONE line and move on.',
    '',
    'VERIFY, DO NOT TRUST, the file:line anchors you are given. This tree has a documented history',
    'of stale in-source citations - the recon that produced this batch found the spec citing ten',
    'text_hidden call sites when there are eleven, and annot_show_sync_cache listing its OWN call',
    'sites wrongly in its own comment. Open every line you cite.',
    '',
    'Take the plan step\'s claims as HYPOTHESES and corroborate them in the source. Say explicitly',
    'which you could and could not confirm. If a claimed file:line anchor in the spec or plan is',
    'wrong, say so with the correct one - the spec was written from a survey and may have drifted.',
    'Grep widely (rg over src/, tests/, doc/claude/, the PDK trees) rather than guessing filenames.',
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
    'A previous crew may have edited sources without rebuilding, leaving ' + REPO + '/src/xschem',
    'containing code no longer in the tree - every number you then measure would be a lie.',
    'Check whether any .c/.h/.y/.l under ' + REPO + '/src/ is newer than ' + REPO + '/src/xschem.',
    'If the binary is stale, run cd ' + REPO + '/src && make ONCE and record that you did so in notes.',
    'You are the only agent alive in this phase, so this cannot collide. If it is fresh, do NOT build.',
    'After JOB 0 you may not build again for any reason.',
    '',
    'JOB 1 - RECORD THE TIER BASELINE AS IT IS RIGHT NOW, before anything is edited. Run T1, T2 and',
    'any T3 suite the Scout named, against the CURRENT binary, and record the observed number or',
    'verdict for each. There is NO documented baseline for this branch - what you observe IS the',
    'baseline of record, and Verify-A diffs against it. If a tier looks broken for a reason that has',
    'nothing to do with this step, record it anyway, set baseline_matches_expected=false and name the',
    'drift in notes so nobody later mistakes it for a regression.',
    '',
    'JOB 2 - RECORD THE BEFORE STATE. For a feature step the "defect" is a missing capability: prove',
    'it is missing with a literal transcript (the proc does not exist, the vector is absent from the',
    'raw header, the key does nothing, the text renders "-"). Write any throwaway driver under',
    '/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_' + ID + '/ - NEVER in the repo, and never',
    'create untitled*.sch anywhere in the repo (three tests go red if you do).',
    'Capture LITERAL output lines. The write-up quotes these verbatim, so never paraphrase.',
    '',
    'If the step turns out to be ALREADY DONE, or its premise is false (the capability already',
    'exists, the anchor does not, the prototype already covers it), that is a legitimate and valuable',
    'outcome: set reproduced=false with the evidence of non-reproduction. The step then ends F with',
    'the measurement recorded, and nothing is invented to keep the crew busy.',
  ].join('\n'), { label: 'measure:' + ID, phase: 'Measure', schema: MEASURE_SCHEMA })

  if (!measure) throw new Error('measure produced nothing')

  const baselineText = block('MEASURED BASELINE + BEFORE STATE', measure)

  if (!measure.reproduced) {
    /* -------- premise false: straight to write-up as F -------- */
    phase('Writeup')
    const wu = await agent([
      COMMON, '', block('SCOUT REPORT', scout), '', baselineText,
      '',
      'YOU ARE THE WRITE-UP AGENT. The step\'s PREMISE DID NOT HOLD - the capability already exists,',
      'or the anchor does not, or the prototype already covers it. Do NOT implement anything.',
      '',
      'Update ' + PLAN + ': amend this step\'s section with a NOT NEEDED / ALREADY PRESENT note quoting',
      'the measurement transcript verbatim, stating exactly what was run and observed, and either',
      'narrowing the step to the part that does still hold or striking it with the reasoning.',
      'If the spec ' + SPEC + ' asserted something the measurement contradicts, correct the spec too.',
      'Then git add ONLY the doc paths you touched and git commit. Docs-only commit is legitimate;',
      'the step status is still F because no capability was added.',
      'Commit subject: "docs(op_param): ' + ID + ' premise does not hold - <what was measured>"',
      'Body: what was measured, how, and what remains open.',
      'Trailers, exactly:',
      'Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>',
      'Claude-Session: ' + SESSION_URL,
      'NEVER git push. Leave the working tree clean of scratch files.',
      'Set status="F", blocker="premise did not hold", and make result_line say so in one line.',
    ].join('\n'), { label: 'writeup:' + ID, phase: 'Writeup', schema: WRITEUP_SCHEMA })
    carried = wu || carried
  } else {
    /* ---------------- Plan ---------------- */
    phase('Plan')
    const plan = await agent([
      COMMON, '', block('SCOUT REPORT', scout), '', baselineText,
      '',
      'YOU ARE THE PLANNER. Decide the change. Do not write it.',
      'Deliver: the change in prose; the exact files to touch; the test rows (one line each: what the',
      'check asserts and which suite file it joins - PREFER extending an existing suite over inventing',
      'a new file); the sabotage variants NAMED UP FRONT with, for each, how to neutralize the change',
      '(rename the callee to a no-op - a /* SABOTAGE */ comment PREFIXED to a line does NOT disable',
      'the call on it) and which specific checks that variant must turn red; and every decision the',
      'docs do not settle, each tagged with the ladder rung (L1 + which invariant, L2, or L3) and the',
      'alternative you rejected.',
      '',
      'Set c_change_needed=false when the step is pure Tcl / data / symbols - most of S1-S6 and S12',
      'are. That tells the Implement agent not to build and the Sabotage agent it owns no build lock.',
      'Set user_visible_change=true if a user would notice a behaviour difference; that forces status',
      'E and the exact question must appear in your decisions list.',
      '',
      'HARD CONSTRAINTS FOR THIS FEATURE, from the spec:',
      '  - I1: if this step builds a raw-vector name ANYWHERE, it must call the single builder, not',
      '    reimplement the shape. If the builder does not exist yet, this step defines it and every',
      '    later consumer uses it.',
      '  - I3: never emit 0 or NaN for a vector that is absent. Blank.',
      '  - I6: any hierarchy walk restores no_draw / no_undo / keep_symbols / sch_path on every exit.',
      '  - Smallest blast radius wins. Do not refactor beyond the step. Do not do a later step\'s work',
      '    (in particular: do not touch the nine visibility sites unless your step IS S7, and do not',
      '    add the draw overlay unless your step IS S9).',
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
        'You may NOT edit production files - only test scripts. You may NOT run make.',
        'Add the planned test rows to the suites named in the plan. Match that suite\'s house style',
        'exactly (numbering, the check helper it uses, the pass/fail counter).',
        'Then RUN them against the current unmodified binary and confirm they are red.',
        '',
        'CRITICAL: a check that fails for an unrelated reason (typo, wrong path, harness error) is a',
        'BROKEN TEST, not a RED. Read each failure line and confirm it is red for exactly the reason',
        'the Measure agent recorded. Set red_for_measured_reason accordingly and quote literal lines.',
        'If a planned check is already GREEN before the change, say so loudly in evidence - that check',
        'proves nothing and the plan needs to know.',
        '',
        'For a Tcl-only step the check usually drives the binary headlessly and asserts on a returned',
        'STRING (a built vector name, a generated save block, a formatted annotation line). Golden',
        'strings beat eyeballing: assert the exact expected text, so a later drift is caught.',
      ].join('\n'), { label: 'red:' + ID, phase: 'RED', schema: RED_SCHEMA })

      /* ---------------- Implement ---------------- */
      phase('Implement')
      impl = await agent([
        COMMON, '', block('SCOUT REPORT', scout), '', baselineText, '', planText, '',
        block('RED REPORT', red || { note: 'RED agent produced nothing - write the checks yourself first' }),
        '',
        'YOU ARE THE IMPLEMENT AGENT. You are the ONLY agent in this crew permitted to run make.',
        'Implement the planned change.',
        '',
        'If the plan set c_change_needed=false: do NOT build. Tcl and symbol files are read at',
        'startup; just relaunch the binary. Set built=true and say "no build needed" in notes.',
        'If it set c_change_needed=true: C89 only; _ALLOC_ID_ as the literal first argument to',
        'my_malloc/my_realloc/my_strdup; a new .c needs an OBJ entry AND a compile rule in',
        'src/Makefile.in (NOT the generated src/Makefile - see rule 2b); keep C-side and',
        'Tcl-side mirrored config vars in sync.',
        'Build with: cd ' + REPO + '/src && make 2>&1 | tail -40',
        '',
        'A new .tcl file must be sourced from src/xschem.tcl the way the other helpers are, and must',
        'be added to whatever install list ships the existing .tcl helpers - a helper that only works',
        'from the source tree is half a feature. That list lives in src/Makefile.in, so editing it',
        'obliges you to run ./configure and rebuild per rule 2b, and to quote the grep receipt.',
        '',
        'Then run the new checks, confirm GREEN, re-run the tier list and record the counts.',
        'If the change needs more than the plan allowed, do the smallest thing that makes the red',
        'checks green and record the overrun in notes. If you discover a SEPARATE defect, do not fix',
        'it silently - note it so the Write-up agent files it from 0418 up.',
        'If you cannot get it green, set built=false, explain, and REVERT your edits so the tree still',
        'compiles and no half-feature is left behind.',
      ].join('\n'), { label: 'impl:' + ID, phase: 'Implement', schema: IMPL_SCHEMA })
    }

    const implText = block('IMPLEMENT REPORT', impl || { note: 'no code change - documentation step' })

    /* ---------------- Verify (3 in parallel, none wrote the change) ---------------- */
    phase('Verify')
    const verifies = await parallel([
      () => agent([
        COMMON, '', baselineText, '', planText, '', implText,
        '',
        'YOU ARE VERIFY-A (TIER DIFF). You did not write the change. You may NOT run make - run the',
        'binary as it stands at ' + REPO + '/src/xschem.',
        'Re-run every tier the Measure agent recorded and diff against the MEASURED BASELINE above -',
        'that recorded set is the truth for this run, not any remembered table.',
        'For each tier report "baseline -> after" and a verdict. A count going UP is fine when the',
        'step added checks; a count going DOWN, or any NEW failure line, is a regression.',
        'Check specifically that the step left no untracked untitled*.sch in the repo root (three',
        'tests go red if it did) and that git status --short shows no stray scratch files.',
        'Set clean=false if there is any new failure at all.',
      ].join('\n'), { label: 'verify-tiers:' + ID, phase: 'Verify', schema: TIER_VERIFY_SCHEMA }),

      () => agent([
        COMMON, '', baselineText, '', planText, '', implText,
        '',
        'YOU ARE VERIFY-B (SABOTAGE). You did not write the change. You ARE permitted to run make,',
        'but ONLY sequentially and ONLY as part of this sabotage loop - never at the same time as',
        'anyone else. (Verify-A and Verify-C are forbidden to build; you own the build lock.)',
        'If the plan set code_change_needed=false there is nothing to sabotage: return',
        'trustworthy=true, variants=["n/a - no code change"], restore_clean=true,',
        'baseline_green_after_restore=true and stop.',
        '',
        'For each planned sabotage variant, in sequence:',
        '  1. Back up EVERY file the patch touches, not just the one you are editing.',
        '  2. Neutralize the change by renaming the callee to a no-op. A /* SABOTAGE */ comment',
        '     PREFIXED to a line does NOT disable the call on it - that trick proves nothing.',
        '     For a Tcl-only change, neutralize by renaming the proc so callers hit the old path,',
        '     and remember Tcl is read at STARTUP: relaunch the binary, do not expect a live reload.',
        '  3. Rebuild if C was touched, run the affected suites, record which checks went red.',
        '  4. Restore with cp + touch (NOT cp -p). A preserved mtime makes make a no-op and every',
        '     later number is then measured against the PREVIOUS sabotage binary.',
        '  5. Rebuild again and RE-ASSERT the restored baseline is green before publishing a number.',
        'After the loop assert a grep for SABOTAGE over ' + REPO + '/src/ is empty.',
        '',
        'Report per variant: predicted red vs observed red. Any PREDICTED red that does NOT appear is',
        'the finding that matters - list every one in missing_predicted_reds, because it means the',
        'check does not cover the mechanism it claims to.',
        'Set trustworthy=false if any restore was partial, a needed rebuild was skipped, or the',
        'restored baseline was not re-asserted green.',
      ].join('\n'), { label: 'verify-sabotage:' + ID, phase: 'Verify', schema: SABOTAGE_SCHEMA }),

      () => agent([
        COMMON, '', block('SCOUT REPORT', scout), '', baselineText, '', planText, '', implText,
        '',
        'YOU ARE VERIFY-C (ADVERSARY). You did not write the change. You may NOT run make and may NOT',
        'edit any file. Your job is to REFUTE the change\'s central claim, not to bless it.',
        'State the central claim in one sentence, then attack it. Read git diff and reason about what',
        'it does NOT cover. Drive the binary headlessly to try to produce a counterexample.',
        '',
        'ATTACK THIS FEATURE SPECIFICALLY:',
        '  - I1: is there now MORE THAN ONE place that builds a raw-vector name? Grep for the bracket',
        '    shape and for i(/v( wrapping. Two builders is the silent-failure mode this whole design',
        '    exists to prevent, and it is the single most valuable thing you can find.',
        '  - I-A: does toggling the declutter leave the .sch BYTE-IDENTICAL and the modify flag',
        '    clear? Diff the bytes, do not trust the absence of a dirty marker.',
        '  - I-C: with ANNOT_SHOW_OP clear, does the declutter bit change ANYTHING at all? It must',
        '    not. Fire it with annotation off and diff the rendering.',
        '  - THE ELEVENTH CALL SITE: does get_annot_overlay() (actions.c:1832) still paint exactly',
        '    when it did before? It calls text_hidden with a SYNTHETIC literal, so a new rung placed',
        '    too early switches the annotation itself off. This is the highest-value check here.',
        '  - D-4 / D-5: does any code path INFER which parameters exist - a show parse, a catalogue,',
        '    a probe-and-prune? The user forbade all three. Grep for it and report it as a defect',
        '    even if it works.',
        '  - ABSENT vs ZERO: does any reader treat a dims=0 or zero-length vector as the value 0?',
        '    Measured: savecurrents publishes a sky130 FET ig/is/ib as 0 long, and an explicit',
        '    save [ib] card yields a dims=0 column of 0.0. Both are ABSENT and neither warns.',
        '  - SHARED SYMBOL TEXT: does anything assume a per-instance answer can live in',
        '    xText.flags? draw_symbol walks symptr->text[j], the SYMBOLs array.',
        '  - THE CLICK TARGET: select.c:709 shrinks the with-text bbox that findnet.c:461 gates on.',
        '    Did the clickable area of a decluttered device change, and was that recorded?',
        '  - Does any existing library symbol render differently than before?',
        '    sch_waves_loaded() ties data to raw->schname/level and silently returns -1.',
        '  - Case: instance names are mixed case and ngspice lowercases. Does the built name survive?',
        '  - PDK portability: does anything hardcode the element letter m? IHP uses n (psp103 via',
        '    OSDI) and q (HBT). Hardcoding m works on two PDKs out of three and fails silently on the',
        '    third.',
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
      'YOU ARE THE WRITE-UP AND COMMIT AGENT. You decide this step\'s final status. Be honest.',
      '',
      'STATUS RULES:',
      '  x = implemented, tiers clean, sabotage trustworthy, adversary did not refute, committed.',
      '  E = it landed and is committed, but a human must look: the plan set user_visible_change=true',
      '      with no prior ratification, OR the only proof is a GUI screenshot. result_line must BE',
      '      the one-line question the user has to answer.',
      '  F = not implemented / broke something / sabotage untrustworthy / adversary refuted. Then',
      '      REVERT the code changes so the tree is clean and compiles, commit NOTHING but',
      '      (optionally) the write-up recording what was measured, and say why in blocker.',
      '  D = blocked before implementation was possible. Nothing committed except the note.',
      'If VERIFY-A reports a regression, or VERIFY-B reports trustworthy=false, or VERIFY-C reports',
      'refuted=true, you may NOT claim x. Downgrade and say why. Never round a partial result up.',
      '',
      'DELIVERABLES:',
      '1. Update ' + PLAN + ': tick this step, and record anything the crew learned that changes a',
      '   LATER step - a wrong anchor, a constraint discovered, a decision that binds the next crew.',
      '   That propagation is the single most valuable thing you write, because the next crew reads',
      '   the plan and not your receipt.',
      '2. Update ' + SPEC + ' where the implementation settled or contradicted something the spec',
      '   asserted. The spec is the design of record; leaving it stale is a defect.',
      '3. Any issue file under doc/claude/issues/ for something measured-and-not-fixed, numbered from',
      '   0418 up (create the stub file IMMEDIATELY to claim the number). Quote the Measure agent\'s',
      '   BEFORE transcript verbatim, then the AFTER lines. Record every decision with its ladder rung',
      '   and rejected alternative, the sabotage matrix including any predicted red that did NOT',
      '   appear, and the adversary\'s residual risks under a "still open" heading.',
      '4. git add the EXACT paths (never git add -A, never git add .) and git commit. The repo has a',
      '   large untracked scatter that must NOT be swept in. Verify with git status --short before and',
      '   after that you added only your paths, and that no untitled*.sch was created.',
      '   Commit subject in house style: type(scope): imperative summary (' + ID + ')',
      '   Body: what was measured BEFORE (quote a line), what changed, why, what is still open.',
      '   Trailers, exactly these two lines at the end:',
      '   Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>',
      '   Claude-Session: ' + SESSION_URL,
      '   NEVER git push. NEVER open a PR.',
      '5. Delete any scratch files your crew left inside the repo.',
      '6. Do NOT touch ' + LEDGER + '. A dedicated Ledger agent appends the row after you, from the',
      '   receipt fields you return. Writing a row yourself produces a duplicate.',
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
  'You are the LEDGER agent for step ' + ID + '. You do exactly one thing and nothing else.',
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
