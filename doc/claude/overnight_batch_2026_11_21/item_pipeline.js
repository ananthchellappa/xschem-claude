export const meta = {
  name: 'ovb-2026-11-21-item',
  description: 'One item of the overnight batch of 2026-11-21, worked in the clone ~/ob21: build, review, attack, repair, gate and commit, receipt',
  phases: [
    { title: 'Build', detail: 'one crew works the work order end to end in the batch clone' },
    { title: 'Review', detail: 'two readers go through the change without running anything' },
    { title: 'Attack', detail: 'one runner re-runs the suites, rebuilds the sabotages and hunts rows that prove nothing; for a document, a cold reader follows it in a scratch copy of the tree it is for' },
    { title: 'Repair', detail: 'fix what was found, then attack again; at most three rounds' },
    { title: 'Gate', detail: 'full regression on a private display; one commit when it is green' },
    { title: 'Receipt', detail: 'the receipt file of the item' },
  ],
}

// Run by the batch driver, one call per item, strictly one at a time:
//   Workflow({scriptPath: <this file>, args: {item: 3, slug: 'viewer-ctrl-shift-m', kind: 'code', base: '<commit>'}})
// kind: 'doc'   a document only (no product change, xschem is never started, no regression gate)
//       'code'  a product change (the full pipeline)
//       'port'  the port of the batch's commits to ~/private/xschem-private (nothing is committed anywhere)
// base: the commit the clone stands on when the item starts (the driver passes it; every stage checks it).
// The item's detail is on disk (PLAN.md and prompts/NN_slug.md), not in these arguments.

const MAIN = '/home/analog/dev/xschem-claude'
const A = (typeof args === 'string') ? JSON.parse(args) : args
if (!A || !A.item || !A.slug || !A.kind || !A.base) throw new Error('args {item, slug, kind, base} required')
// args.clone: the work clone of this run (default /home/analog/ob21). Two items may run side by side in two clones.
const CLONE = (A.clone && typeof A.clone === 'string') ? A.clone : '/home/analog/ob21'
const BATCH = CLONE + '/doc/claude/overnight_batch_2026_11_21'
const PLAN = BATCH + '/PLAN.md'
const PORTDIR = '/home/analog/port_ob21'
const KIND = A.kind
if (['doc', 'code', 'port'].indexOf(KIND) < 0) throw new Error('kind must be doc, code or port')
const NN = A.nn ? String(A.nn) : (String(A.item).length < 2 ? '0' + String(A.item) : String(A.item))
// args.closeout: {file, wip}. An earlier run of this item ended with nothing committed and its work still in the
// clone as work-in-progress commits. file is its result (problems left, accounts of every stage), wip the last of
// those commits. The run then starts at the repair of what was left, checks it, gates and commits.
const CLOSEOUT = (A.closeout && A.closeout.file) ? A.closeout : null
const SLUG = A.slug
const BASE = A.base
const ORDER = BATCH + '/prompts/' + NN + '_' + SLUG + '.md'
const RECEIPT = BATCH + '/receipts/' + NN + '_' + SLUG + '.md'
const TAG = 'ovb ' + NN

const READ_FIRST = [
  'READ FIRST, in this order:',
  '1. ' + PLAN + ' from its top down to the heading "Item detail": the verdict alphabet, the rulings the user gave on 2026-11-21, the run rules, the baseline and the known reds. Then the section of item ' + NN + ' under "Item detail".',
  '2. ' + ORDER + ' : the work order. It is your contract. Its facts were read from the code on the day it was written and checked by a second reader, but the tree is the authority: where the two differ, the tree wins and the difference is a finding you report.',
  '3. Every spec, issue file and proc the work order names, before you change anything near them.',
].join('\n')

const RULES = [
  'RULES OF THIS BATCH (nobody is awake; there is no one to ask):',
  '- WHERE. Work only in ' + CLONE + ' (a clone made for this batch, branch fluid-editing; it must stand on a descendant of ' + BASE + '). Never write in ' + MAIN + ' (the driver lands commits there), in ~/private/xschem-private (read only), in /home/analog/dev/ngspice-ver_53 (never touch it; to use that ngspice, copy its binary and run the copy), in any other checkout or clone (/home/analog/gcp0, /home/analog/gcq0, /home/analog/g1724, /home/analog/pp1724, a second clone of this batch), or in ~/.xschem (the user\'s live configuration: read only).',
  '- DISPLAY. DISPLAY in your shell is the user\'s real screen. Never start xschem on it. Every xschem start goes through one of these, from ' + CLONE + ':',
  '      env -u DISPLAY AUDIT_DISPLAY=private tests/headless/run_suites.sh [--nogui] <suite>      (a suite; drop --nogui for the display arm)',
  '      env -u DISPLAY AUDIT_DISPLAY=private tests/headless/gated_xschem.sh <xschem arguments>    (a probe of your own)',
  '      cd tests && env -u DISPLAY T1_DISPLAY=private tclsh run_regression.tcl                     (the full regression: the Gate stage only)',
  '  Never a bare ./src/xschem, never xschem from PATH.',
  '- ONE RUNNER. In this clone and in scratch copies you make, you are the only crew that starts xschem while your stage runs, and you run ONE thing at a time: never two suites at once, never a suite while a full regression of this clone is live. Other checkouts are other people\'s: another session works in ~/private/xschem-private and gates in clones of its own (/home/analog/gcp0, /home/analog/gcq0), and this batch may have a second item running in another clone. Look once before a run (by COMMAND NAME, not by argument text: your own shell\'s arguments contain the words, and a grep of them finds itself):  ps -eo pid,comm,args | awk \'($2=="tclsh" && /run_regression/) || $2=="run_suites.sh" || $2=="full_audit.sh"\'  and  readlink /proc/<pid>/cwd  for each. A run whose directory is under this clone: wait for it in bounded steps. A run anywhere else: do NOT wait for it; write down that it was live. Several xschem processes that start in the same second can collide (issues 1706 and 1725: the same temporary names), so a red you get while another run was live is run once more, alone if you can, before you believe it or report it. An xschem the user has open for their own work is not a run: leave it alone.',
  '- TIME. Every command has a bound. run_suites.sh caps a suite at SUITE_TIMEOUT seconds (default 200; raise it by name for a suite that needs more). Put  timeout <seconds>  in front of anything else that could wait. One tool call must end within 9 minutes: start longer work detached (setsid nohup <command> > <log> 2>&1 &, and record the pid it prints) and poll it with loops that each end within 9 minutes. A stall is a result: report TIMEOUT with the last lines of output and go on; never wait without a bound.',
  '- PROCESSES. Never kill by name (no pkill, killall, pkill -f). Kill only a pid you started and wrote down.',
  '- GREP. /usr/bin/grep, never the bare grep.',
  '- GIT in the clone. No push. No git add -A, no git commit -a: stage an explicit file list. Do not reset, clean, stash or check out over work in the clone unless your stage\'s instructions say so. The untracked files under doc/claude/overnight_batch_2026_11_21/receipts/ are the batch\'s own; leave them.',
  '- OWED LEDGER. Do not run owed.sh add or clear: the ledger is shared by every clone and stamped with the path of the clone that files. Return each debt in your answer instead (kind look: something the user has to see with their eyes; kind rule: a user-visible decision you had to take) and the driver files it.',
  '- ISSUE NUMBERS. Mint a number only by the two checks of CLAUDE.md, with ' + CLONE + ' and the clones /home/analog/g* added to the greps, and record it in NUMBERING.md in the same change. A stamp line names tree=7c77f3594 (the commit the batch started from, an ancestor of everything made tonight), never a commit made tonight: one of those can get a new hash when it lands.',
  '- SPEC HOLES. What the user decided is in the work order under "Ruled". For a hole it does not cover: take the option that changes least for a user who did not ask for it, record the question, your decision and what you rejected, and go on. Do not stop to ask. The one exception: anything destructive, or anything outside the clone, is not done and is reported.',
  '- ROWS. A new row is run against the UNCHANGED product first and must be red there; a row that is green before the change proves nothing. A suite you add a row to is registered in tests/run_regression.tcl in the same change, after its epilogue was checked against banner_complete (tests/banner_rule.tcl), and both arms are measured: under --nogui every Tk row self-skips, so a suite that is only in hcases gates none of them. Every population a row walks is derived from the product, never a hand-kept list, and carries a count that cannot be zero.',
  '- DISCRIMINATION. A green suite does not prove the changed code ran. For each new row or band, build the break in the product that the row exists to catch, run, write down exactly which rows went red, and put the product back. Restore a sabotaged file with  git checkout -- <file>  only when  git diff -- <file>  shows nothing but the sabotage (the work is committed as work-in-progress before sabotage starts); then run once more and see it green.',
  '- C AND TCL. C89; allocations with the literal _ALLOC_ID_; a variable mirrored between C and Tcl changes on both sides; a new user-facing operation is a branch of scheduler.c; an edit of src/Makefile.in obliges ./configure. A comment between two switch patterns is a parse error info complete cannot see: prose goes above the proc.',
  '- WORDS. A comment, a spec line or a row name says what the code does and how the row checks it. It quotes no count a command produces, no line number, and not the literal a text-scanning row greps for. A decision the user overruled is amended with a line dated 2026-11-21 that says so; the old text is not silently rewritten.',
  '- NOT YOURS. A red that the baseline run of the same suite showed before your change is not yours: name it and leave it. test_wave_markers timing out (issue 1488) and test_ase_optier_0963 failing once with a NORAW line (a known flake: run it again and report the line) are not yours either. Do not repair a defect outside the work order; describe it in your answer.',
].join('\n')

const DEBT = { type: 'object', required: ['kind', 'what', 'why'], properties: { kind: { enum: ['look', 'rule'] }, what: { type: 'string' }, why: { type: 'string' } } }
const DECISION = { type: 'object', required: ['question', 'decision'], properties: { question: { type: 'string' }, decision: { type: 'string' }, rejected: { type: 'string' } } }
const PROBLEM = {
  type: 'object', required: ['severity', 'where', 'what'],
  properties: {
    severity: { enum: ['blocker', 'should', 'note'], description: 'blocker: wrong behaviour, a row that proves nothing, a red, a false sentence, a missed family member, a broken rule of the batch. should: worth fixing in this pass. note: for the receipt only.' },
    where: { type: 'string' }, what: { type: 'string' }, evidence: { type: 'string' },
  },
}

const BUILD_SCHEMA = {
  type: 'object',
  required: ['status', 'wipCommit', 'filesChanged', 'summary'],
  properties: {
    status: { enum: ['DONE', 'ABORTED'] },
    wipCommit: { type: 'string', description: 'hash of the work-in-progress commit in the clone, or NONE' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    suites: { type: 'array', items: { type: 'object', required: ['name', 'arm', 'after'], properties: { name: { type: 'string' }, arm: { enum: ['nogui', 'display'] }, before: { type: 'string', description: 'result and check count before the change' }, after: { type: 'string' }, registered: { type: 'string', description: 'hcases, dcases, both or none, as tests/run_regression.tcl now has it' } } } },
    redFirst: { type: 'array', items: { type: 'object', required: ['row', 'redBefore'], properties: { row: { type: 'string' }, redBefore: { type: 'boolean' }, evidence: { type: 'string' } } } },
    sabotage: { type: 'array', items: { type: 'object', required: ['name', 'target', 'reddened'], properties: { name: { type: 'string' }, target: { type: 'string' }, reddened: { type: 'string' }, exact: { type: 'boolean' } } } },
    familyClosed: { type: 'array', items: { type: 'string' } },
    decisions: { type: 'array', items: DECISION },
    orderClaimsRefuted: { type: 'array', items: { type: 'string' }, description: 'facts of the work order that the tree contradicts' },
    textsUpdated: { type: 'array', items: { type: 'string' } },
    unassertable: { type: 'array', items: { type: 'string' }, description: 'deliverables no row can reach: pixels, feel, layout' },
    debts: { type: 'array', items: DEBT },
    notMine: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}

const REVIEW_SCHEMA = {
  type: 'object', required: ['ok', 'problems'],
  properties: { ok: { type: 'boolean' }, problems: { type: 'array', items: PROBLEM }, notes: { type: 'array', items: { type: 'string' } } },
}

const ATTACK_SCHEMA = {
  type: 'object', required: ['ok', 'problems', 'suitesRerun'],
  properties: {
    ok: { type: 'boolean' },
    problems: { type: 'array', items: PROBLEM },
    suitesRerun: { type: 'array', items: { type: 'string' }, description: 'suite, arm, result and check count, one per entry' },
    sabotageReproduced: { type: 'array', items: { type: 'string' }, description: 'a sabotage of the build crew that you rebuilt, and which rows it reddened' },
    sabotageNew: { type: 'array', items: { type: 'string' }, description: 'a break of your own, and whether any row caught it' },
    unassertable: { type: 'array', items: { type: 'string' }, description: 'YOUR OWN list: deliverables no row reaches' },
    cloneClean: { type: 'boolean', description: 'git status shows nothing you made and HEAD is the commit you were given' },
    notes: { type: 'array', items: { type: 'string' } },
  },
}

const REPAIR_SCHEMA = {
  type: 'object', required: ['wipCommit', 'fixed', 'summary'],
  properties: {
    wipCommit: { type: 'string' },
    fixed: { type: 'array', items: { type: 'string' } },
    refuted: { type: 'array', items: { type: 'string' }, description: 'a reported problem that is not one, with the evidence' },
    notFixed: { type: 'array', items: { type: 'string' } },
    filesChanged: { type: 'array', items: { type: 'string' } },
    decisions: { type: 'array', items: DECISION },
    debts: { type: 'array', items: DEBT },
    summary: { type: 'string' },
  },
}

const GATE_SCHEMA = {
  type: 'object', required: ['verdict', 'commit', 'summary'],
  properties: {
    verdict: { enum: ['GREEN', 'RED_ITEM', 'RED_OTHER', 'NOT_RUN'], description: 'GREEN: gated and committed. RED_ITEM: a counted failure this item causes. RED_OTHER: a counted failure it does not cause, still red after one more full run. NOT_RUN: the run could not be taken.' },
    commit: { type: 'string', description: 'hash of the one commit of the item in the clone, or NONE' },
    trailer: { type: 'string', description: 'the T1-RUN-END line of your run' },
    verdictFile: { type: 'string' },
    expectedDelta: { type: 'string', description: 'cases, blocks and skips you derived from the registration before the run, and whether the run agreed' },
    reds: { type: 'array', items: { type: 'string' }, description: 'each case that is not at zero, with its failing rows and whose it is' },
    skipsNamed: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
}

const RECEIPT_SCHEMA = { type: 'object', required: ['receipt', 'verdict'], properties: { receipt: { type: 'string' }, verdict: { enum: ['x', 'E', 'D', 'F'] }, headline: { type: 'string' } } }

function blockers(list) { return (list || []).filter(function (p) { return p && p.severity === 'blocker' }) }
function shoulds(list) { return (list || []).filter(function (p) { return p && p.severity === 'should' }) }
async function twice(prompt, opts) {
  let r = await agent(prompt, opts)
  if (!r) { log(opts.label + ': no answer, asking once more'); r = await agent(prompt + '\n\n(Second call: the first one returned nothing. Look at what is already in the clone before you start again.)', Object.assign({}, opts, { label: opts.label + ' (again)' })) }
  return r
}

const HEAD_LINE = 'Overnight batch of 2026-11-21, item ' + NN + ' (' + SLUG + '), kind ' + KIND + '.'
// args.note: one paragraph from the driver for the stages that repair (for instance after a run was cut short).
// It is not part of the build's or the readers' prompts, so a resumed run still finds their answers.
const NOTE = (A.note && typeof A.note === 'string') ? ['', 'NOTE FROM THE DRIVER:', A.note, ''] : []

// ------------------------------------------------------------------ Build
phase('Build')
let buildPrompt
if (KIND === 'code') {
  buildPrompt = [
    HEAD_LINE + ' You are the BUILD crew.', '', READ_FIRST, '', RULES, '',
    'DO, in this order:',
    'a. Check where you stand:  git -C ' + CLONE + ' status --short  and  git -C ' + CLONE + ' merge-base --is-ancestor ' + BASE + ' HEAD . Tracked files must be unmodified. If not, stop and answer ABORTED with what you found.',
    'b. BASELINE. Run every suite the work order names, on both arms, before you change anything. Write down result and check count per suite and arm.',
    'c. REPRODUCE. Show the present behaviour the work order describes with a probe or a row, on the private display. If the product does not behave as the work order says, the work order is wrong there: find out what is true and say so.',
    'd. RED FIRST. Write the rows the work order lists and the ones you find are needed. Run them against the unchanged product and keep the red output.',
    'e. BUILD the change. Close the family the work order lists in the same pass; a sibling with the same cause that it does not list is in scope too.',
    'f. REGISTER the suites and measure both arms.',
    'g. Update every text the work order lists (specs, issue files, guides, tables of keys), and grep for others that now say something untrue.',
    'h. Rebuild:  make -C src  must end with rc 0 (after ./configure if src/Makefile.in changed).',
    'i. COMMIT your work in the clone as one work-in-progress commit: explicit file list, subject  wip(' + TAG + '): ' + SLUG + ' . The Gate stage turns it into the one commit of the item.',
    'j. DISCRIMINATE, as the rules say, after the commit.',
    'k. Run every touched suite once more on both arms, and leave the clone with nothing uncommitted that you made (scratch files, a stray untitled~.sch, logs).',
    'Answer with the facts only. An honest ABORTED with the reason is worth more than a DONE that is not one.',
  ].join('\n')
} else if (KIND === 'doc') {
  buildPrompt = [
    HEAD_LINE + ' You are the WRITER.', '', READ_FIRST, '', RULES, '',
    'This item changes no product code and starts no xschem. You write one document, for a reader the work order describes.',
    'DO: check where you stand (git -C ' + CLONE + ' status --short; ' + BASE + ' must be an ancestor of HEAD); read everything the work order points at, in both trees; write the document at the path the work order gives, inside ' + CLONE + '; check every command, path, proc name and file name in it against the tree it speaks about by reading (do not quote from memory, and do not copy a fact of the work order you could not find again); commit it in the clone as one work-in-progress commit with an explicit file list, subject  wip(' + TAG + '): ' + SLUG + ' .',
    'In suites, redFirst and sabotage answer with empty lists.',
  ].join('\n')
} else {
  buildPrompt = [
    HEAD_LINE + ' You are the PORT crew.', '', READ_FIRST, '', RULES, '',
    'This item commits nothing anywhere. It produces, under ' + PORTDIR + ' , what the user needs to put tonight\'s product changes into ~/private/xschem-private: a patch, the proof that it was tried, and the exact commands to apply, build, restart and COMMIT it. The work order says how. The private tree is read only for you: every trial happens in a scratch copy at a short path that the work order names.',
    'In wipCommit answer NONE. In filesChanged list the files you wrote under ' + PORTDIR + ' .',
  ].join('\n')
}
const build = CLOSEOUT
  ? { status: 'DONE', wipCommit: CLOSEOUT.wip || 'HEAD', filesChanged: [], summary: 'This run closes out an earlier run of the item that ended with nothing committed. The earlier run\'s full result (the account of its build, of every repair, the problems its last attack left open, its decisions and debts) is the JSON file ' + CLOSEOUT.file + ' ; its work is in the clone as work-in-progress commits since ' + BASE + '.' }
  : await twice(buildPrompt, { label: 'build:' + NN, phase: 'Build', schema: BUILD_SCHEMA })
if (!build || build.status !== 'DONE') {
  log('item ' + NN + ': build did not finish (' + (build ? build.summary : 'no answer') + ')')
  return { item: A.item, slug: SLUG, kind: KIND, verdict: 'F', stage: 'build', build: build, commit: 'NONE', gate: null, receipt: null, decisions: [], debts: [], unassertable: [], problemsLeft: [], repairRounds: 0 }
}

// ------------------------------------------------------------------ Review (readers only: nothing is run, nothing is edited)
phase('Review')
const READER = 'You READ only. You do not edit, build, start xschem or run a suite, and you leave the clone as it is.'
const DIFF = KIND === 'port'
  ? 'This item commits nothing. What it made is under ' + PORTDIR + ' ; the commits it carries are named in the work order.'
  : 'The change is  git -C ' + CLONE + ' diff ' + BASE + ' HEAD  (the work-in-progress commit ' + build.wipCommit + ').'
let lenses
if (KIND === 'code') {
  lenses = [
    { key: 'code', text: 'LENS: does it work, everywhere. Read the diff and the code around it. Look for: behaviour that differs from the work order and the user\'s rulings; a caller, profile or window mode the change forgot (cadence_compat on and off, tabbed and windowed, a descended sheet, a read-only view, no display); a member of the family the work order lists that is still open, and members it does not list; a way the old behaviour was right that the change breaks; C89 slips, a mirrored variable changed on one side, an unbounded wait, a leak. For each finding give the path from a user gesture or a call to the wrong result.' },
    { key: 'rows-and-words', text: 'LENS: do the rows prove it, and is every sentence true. For each new or changed row: what would a broken product have to look like to pass it? Is its population derived or hand-kept, can it be empty, does it compare two numbers that differ by less than its tolerance, does it run on the arm that is registered? Is the suite registered and does its epilogue satisfy banner_complete? Then every sentence the change wrote in comments, specs, issue files and guides: check it against the code; flag a count, a line number, a quoted literal that a row greps for, a row id that does not exist, and a text the work order lists that was not updated. Grep for texts elsewhere that the change made untrue.' },
  ]
} else if (KIND === 'doc') {
  lenses = [
    { key: 'facts', text: 'LENS: is it true. Take every statement, path, proc name, file name, command and number in the document and check it against the tree it speaks about. A statement you cannot find again in the code is a blocker.' },
    { key: 'cold-reader', text: 'LENS: can the reader do it. You are the reader the work order describes: another session, in another checkout, with none of tonight\'s context. Go through the document step by step against THAT checkout (read only): at each step, is everything you need there, named so you can find it, in an order that works? What would you have to guess? Where would you go wrong and not notice? What does it not say that you need (how to test it, how to keep it from firing in other suites, how to register it, what to write new and what to copy)?' },
  ]
} else {
  lenses = [
    { key: 'handover', text: 'LENS: can the user do it tomorrow with no help. Read ' + PORTDIR + '/README.md as the user: are the commands complete and in order (apply, build, restart any open xschem, commit), does each name a real file, does the text say what the commit contains and what stays uncommitted, what to do when the private tree has moved, and what was and was not tested? Check the patch against the commits it claims to carry (file list and content) by reading.' },
  ]
}
const reviews = CLOSEOUT ? [] : (await parallel(lenses.map(function (l) {
  return function () {
    return agent([
      HEAD_LINE + ' You are a REVIEWER.', '', READER, '', READ_FIRST, '', DIFF, '', l.text, '',
      'The build crew\'s own account (do not trust it, check it):', JSON.stringify(build, null, 1), '',
      'Report problems with a severity. ok is true only with no blocker.',
    ].join('\n'), { label: 'review:' + l.key, phase: 'Review', schema: REVIEW_SCHEMA })
  }
}))).filter(Boolean)
let problems = []
reviews.forEach(function (r) { problems = problems.concat(r.problems || []) })
const repairs = []

// A document is cheap to fix and dear to try: what the readers found is fixed before the dry run.
if (KIND === 'doc' && (blockers(problems).length + shoulds(problems).length) > 0) {
  const pre = await twice([
    HEAD_LINE + ' You are the WRITER again, before the document is tried.', '', READ_FIRST, '', RULES, '',
    DIFF + ' Your repair is one more work-in-progress commit on top: explicit file list, subject  wip(' + TAG + '): after review .',
    'Two readers went through the document. For each problem below: make the document right, or refute the problem with evidence a reader can check. A sentence you cannot stand behind is removed, not softened.',
  ].concat(NOTE, ['Problems:', JSON.stringify(problems, null, 1)]).join('\n'), { label: 'repair:' + NN + '.0', phase: 'Review', schema: REPAIR_SCHEMA })
  repairs.push(pre)
}

// ------------------------------------------------------------------ Attack (the one runner)
const DRYCOPY = '/home/analog/pq21'
function dryRunPrompt(round, known, lastFix) {
  return [
    HEAD_LINE + ' You are the DRY RUNNER, round ' + round + '. You are the only one who runs anything in this stage.', '',
    'You stand in for the reader the document was written for: another session, in another checkout, that has the document and nothing else. So do NOT read the work order, the item detail in PLAN.md, the receipts or the scout notes, and do not look at how this repository built the feature beyond what the document itself tells you to read or copy. The document is ' + CLONE + '/doc/claude/suggestions/howto_startup_quiz_in_another_tree.md .', '',
    RULES, '',
    'EXCEPTION to the WHERE rule, for this stage only: you work in ' + DRYCOPY + ' , a scratch copy you make yourself, and the clone is read only for you.',
    'DO:',
    '1. Make the copy:  rm -rf ' + DRYCOPY + '  only if it exists and holds the marker file .git/OVB_SCRATCH_COPY from an earlier round; then  cp -a /home/analog/private/xschem-private ' + DRYCOPY + '  and  touch ' + DRYCOPY + '/.git/OVB_SCRATCH_COPY . The private tree itself is never written.',
    '2. Follow the document from its first line to its last, in the copy, as if the copy were your own tree. Do what it says, in its order, with its commands. Keep a log: for each step, did it work as written, what did you have to guess, what was wrong or missing.',
    '3. When a step cannot be done as written, write that down as a blocker, then find the way through yourself (now you may look wherever you need) so the later steps get tried too.',
    '4. Run the checks the document itself gives (its suite on both arms, through run_suites.sh on a private display, one at a time). A step that needs a full regression run (a census, a gate) is NOT run: read it and say whether you could have followed it.',
    '5. Commit nothing anywhere. At the end remove the copy ( rm -rf ' + DRYCOPY + ' , after checking the marker file is in it).',
    'Report: blocker = a step that fails or cannot be done as written, a missing step, a wrong name, path or command, a check that is red after the document was followed; should = something you had to guess or look up elsewhere. In suitesRerun give each suite, arm, result and check count you got in the copy. cloneClean is true when the copy is gone and git status of the clone is as you found it.',
    'What the readers and earlier rounds reported, and what the writer says it did about it (check each as you go):', JSON.stringify(known, null, 1), JSON.stringify(lastFix, null, 1),
  ].join('\n')
}
function attackPrompt(round, known, lastFix) {
  if (KIND === 'doc') {
    return [
      HEAD_LINE + ' You are the CHECKER, round ' + round + '.', '', READER, '', READ_FIRST, '', DIFF, '',
      'A dry run of the document went through without a blocker; the problems below were reported and a writer then changed the document. For each problem: is it gone, by reading the document and the tree it speaks about? Then read the whole document once more as the reader the work order describes and report what is still wrong or missing. In suitesRerun answer with an empty list and in cloneClean say whether git status shows only what belongs to the batch.',
      'Problems reported before:', JSON.stringify(known, null, 1), 'What the writer says it did:', JSON.stringify(lastFix, null, 1),
    ].join('\n')
  }
  if (KIND === 'port') {
    return [
      HEAD_LINE + ' You are the REPLAYER, round ' + round + '.', '', READ_FIRST, '', RULES, '',
      'Take ' + PORTDIR + '/README.md and do exactly what it tells the user, command by command, in a FRESH scratch replica of ~/private/xschem-private (its HEAD plus its uncommitted files, at a short path of your own under /home/analog, removed when you are done; the private tree itself is read only). Apply, build, run the suites the README names on both arms, then the commit commands, then look at what the commit holds and what is left uncommitted. Everything that does not go as the README says is a blocker. Then try the stale case: say what the commands do when the private tree\'s HEAD is not the one the patch was made for.',
      'Known so far:', JSON.stringify(known, null, 1), 'Last repair:', JSON.stringify(lastFix, null, 1),
    ].join('\n')
  }
  if (round >= 1) {
    return [
      HEAD_LINE + ' You are the CHECKER of repair round ' + round + '. You are the only one who runs anything in this stage.', '', READ_FIRST, '', RULES, '',
      DIFF + ' HEAD of the clone is where you start and where you must end: sabotage is restored with git checkout as the rules say, and git status at the end shows nothing you made.',
      'This is a CHECK of the repair, not a new hunt. An attack before you already hunted; a hunt has no end, and the item must reach its gate.',
      'DO:',
      '1. Rebuild (make -C src, rc 0) and re-run every suite the item touched on both arms. A red is a blocker unless the baseline had it or it is gone when the suite is run once more alone.',
      '2. Take the problems below one by one. For a break that no row caught: rebuild THAT break and see that a row now goes red, and that the row is green without it. For a wrong behaviour: drive it and see it right. For a sentence: read it against the code. A problem that is not fixed and not refuted with evidence stays a blocker.',
      '3. Read the repair\'s own diff (the last work-in-progress commit) for a mistake it introduced: a wrong behaviour, a row that cannot fail, a false sentence. Those are blockers.',
      '4. Anything ELSE you notice (a further break no row catches, a gap, an improvement) is severity should or note, never blocker, and at most five of them: they go into the receipt as known gaps. The only exceptions are a wrong behaviour the user would meet doing what the work order describes, and a suite that is red: those are blockers wherever you find them.',
      '5. Say what no row can reach (pixels, feel, layout).',
      'Problems to check:', JSON.stringify(known, null, 1),
      'What the repair says it did:', JSON.stringify(lastFix, null, 1),
    ].join('\n')
  }
  return [
    HEAD_LINE + ' You are the ATTACKER, round ' + round + '. You are the only one who runs anything in this stage.', '', READ_FIRST, '', RULES, '',
    DIFF + ' HEAD of the clone is where you start and where you must end: sabotage is restored with git checkout as the rules say, and git status at the end shows nothing you made.',
    'DO:',
    '1. Rebuild (make -C src, rc 0) and re-run every suite the item touched on both arms, and the neighbour suites the work order names. A red is a blocker unless the baseline had it.',
    '2. Rebuild at least two of the build crew\'s sabotages and see the rows they named go red, and only those.',
    '3. Attack the green rows: for each new row or band, think of a product that is wrong in a way the user would notice and that the row would still pass. Build at least three such breaks of your own. One that no row catches is a blocker, with the break described so a repair crew can write the row.',
    '4. Drive the user\'s own gesture end to end on the private display (the real event sequence, the shipping rc profile), not only the procs under it, and say what happened.',
    '5. Check each problem the readers reported below: confirm it by running where running can settle it, or refute it with the evidence.',
    '6. Say what no row can reach (pixels, feel, layout): that list decides whether the user is asked to look.',
    'Problems reported so far:', JSON.stringify(known, null, 1),
    lastFix ? 'What the last repair says it did:\n' + JSON.stringify(lastFix, null, 1) : '',
    'The build crew\'s account:', JSON.stringify(build, null, 1),
  ].join('\n')
}

phase('Attack')
let attack = null
let dryBlocked = false
if (KIND === 'doc') {
  attack = await twice(dryRunPrompt(0, problems, repairs[0] || null), { label: 'dryrun:' + NN, phase: 'Attack', schema: ATTACK_SCHEMA })
  if (attack) { problems = attack.problems || []; dryBlocked = blockers(problems).length > 0 }
  else { problems = [{ severity: 'blocker', where: 'dry run', what: 'the dry runner returned nothing twice, so the document was never followed by anyone' }]; dryBlocked = true }
} else if (CLOSEOUT) {
  problems = [{ severity: 'blocker', where: CLOSEOUT.file, what: 'The problems the earlier run\'s last attack left open are in the JSON file ' + CLOSEOUT.file + ' under the key problemsLeft, each with the break that was built, the evidence, and a line that starts "Repair:" saying which rows to write. Every one of them is a break no row catches while the product itself measured right: write those rows (red under the break, green without it), change the product only if writing a row shows it wrong. The scripts that build each break are named in the evidence; they are under the session scratchpad and may be read.' }]
} else {
  attack = await twice(attackPrompt(0, problems, null), { label: 'attack:' + NN, phase: 'Attack', schema: ATTACK_SCHEMA })
  if (attack) problems = problems.concat(attack.problems || [])
  else problems.push({ severity: 'blocker', where: 'attack stage', what: 'the attacker returned nothing twice, so nothing was re-run independently' })
}

// ------------------------------------------------------------------ Repair, then attack again (at most three rounds)
phase('Repair')
let round = 0
let open = blockers(problems).concat(shoulds(problems))
while (blockers(open).length > 0 && round < 3) {
  round++
  const fix = await twice([
    HEAD_LINE + ' You are the REPAIR crew, round ' + round + '.', '', READ_FIRST, '', RULES, '',
    (KIND === 'port' ? 'The deliverable is under ' + PORTDIR + ' ; nothing is committed anywhere.' : DIFF + ' Your repair is one more work-in-progress commit on top: explicit file list, subject  wip(' + TAG + '): repair ' + round + ' .'),
    'For each problem below: fix it, or refute it with evidence a reader can check. A fix to the product comes with the row that would have caught it, red before the fix. A problem about a sentence is fixed by making the sentence true or removing it. Blockers first; fix the ones marked should if they are cheap and safe. ' + (KIND === 'code' ? 'Re-run every touched suite on both arms before you commit.' : ''),
  ].concat(NOTE, ['Problems:', JSON.stringify(open, null, 1)]).join('\n'), { label: 'repair:' + NN + '.' + round, phase: 'Repair', schema: REPAIR_SCHEMA })
  repairs.push(fix)
  if (!fix) { log('item ' + NN + ': repair round ' + round + ' returned nothing'); break }
  const retry = (KIND === 'doc' && dryBlocked)
  const again = await twice(retry ? dryRunPrompt(round, open, fix) : attackPrompt(round, open, fix),
    { label: (retry ? 'dryrun:' : 'attack:') + NN + '.' + round, phase: 'Repair', schema: ATTACK_SCHEMA })
  if (!again) { open = [{ severity: 'blocker', where: 'attack round ' + round, what: 'the check of the repair returned nothing twice' }]; break }
  if (KIND !== 'doc' || retry) attack = again
  open = blockers(again.problems).concat(shoulds(again.problems))
  if (retry) dryBlocked = blockers(again.problems).length > 0
}
const blocked = blockers(open)
if (blocked.length > 0) log('item ' + NN + ': ' + blocked.length + ' blocker(s) left after ' + round + ' repair round(s)')

// ------------------------------------------------------------------ Gate and the one commit
phase('Gate')
let gate = null
const squash = [
  'THE ONE COMMIT of the item. All work-in-progress commits since ' + BASE + ' become one:  git -C ' + CLONE + ' reset --soft ' + BASE + '  (this stage alone may do that), check with  git -C ' + CLONE + ' diff --cached --stat  that the staged set is the item and nothing else, then commit with a message file: a subject in the house form (feat|fix|docs(<area>): what the user gets), a body in plain words (what changed for the user, what the user ruled on 2026-11-21, how it was gated: the trailer line and the verdict file), and these two last lines exactly:',
  '    Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>',
  '    Claude-Session: https://claude.ai/code/session_01DnfUK6yAfEtujJPgk2cdkR',
  'No push. Answer with the hash.',
].join('\n')
if (KIND === 'port') {
  gate = { verdict: blocked.length ? 'RED_ITEM' : 'GREEN', commit: 'NONE', summary: 'a port commits nothing' }
} else if (blocked.length > 0) {
  gate = { verdict: 'NOT_RUN', commit: 'NONE', summary: 'blockers left after repair; not gated, not committed' }
} else if (KIND === 'doc') {
  gate = await twice([
    HEAD_LINE + ' You are the COMMITTER.', '', READ_FIRST, '', RULES, '',
    'A document needs no regression run. Check that the change since ' + BASE + ' is the document the work order asks for and nothing else, that  tclsh tests/headless/issue_stamp.tcl  still answers ok, then:', squash,
    'Answer verdict GREEN with the hash, or NOT_RUN with the reason.',
  ].join('\n'), { label: 'commit:' + NN, phase: 'Gate', schema: GATE_SCHEMA })
} else {
  let tries = 0
  while (tries < 2) {
    tries++
    gate = await twice([
      HEAD_LINE + ' You are the GATEKEEPER' + (tries > 1 ? ' (second gate, after a repair)' : '') + '.', '', READ_FIRST, '', RULES, '',
      'DO:',
      '1. git -C ' + CLONE + ' status --short : nothing uncommitted but the batch\'s own receipts. make -C src : rc 0 and nothing left to compile.',
      '2. DERIVE what the run must say before you take it: count the entries of tcases, hcases and dcases in tests/run_regression.tcl as CLAUDE.md describes (find the list by name, stop at the first line without a trailing backslash), compare with the baseline trailer in PLAN.md, and write down the cases, blocks and skips you expect. Check it against planned_cases in the header of your run.',
      '3. Take the full regression, detached, and poll it in bounded steps:   cd ' + CLONE + '/tests && setsid nohup env -u DISPLAY T1_DISPLAY=private tclsh run_regression.tcl > <log outside the clone> 2>&1 &   . The run\'s pid is not always the one your shell printed (setsid may fork): read it from the first line of your log ("test home: throwaway ...xschem-test-home.<pid>...") and from the T1-RUN-BEGIN line of the tests/results.<pid>.log that appeared after your launch. That file is your verdict. The run takes about 25 minutes; give it 50, then kill that pid (after /proc/<pid>/cmdline confirmed it is your tclsh) and answer NOT_RUN.',
      '4. Read the verdict by shape, as CLAUDE.md says: T1-RUN-BEGIN and T1-RUN-END of your pid, counted_failures, every Total num fail that is not 0, the skip lines by name, and whether a live peer was announced.',
      '5. Not at zero: name each case and its rows and decide whose it is, by case and not by count. A known flake or a collision gets ONE more full run; what is still red after it is RED_OTHER. A red the item causes is RED_ITEM: do not commit, describe it so a repair crew can act.',
      '6. At zero, and the derived figures agree:', squash,
    ].join('\n'), { label: 'gate:' + NN + (tries > 1 ? '.2' : ''), phase: 'Gate', schema: GATE_SCHEMA })
    if (!gate || gate.verdict !== 'RED_ITEM' || tries >= 2) break
    const gfix = await twice([
      HEAD_LINE + ' You are the REPAIR crew for a red gate.', '', READ_FIRST, '', RULES, '',
      DIFF + ' The full regression is red because of this item. Fix the cause (not the row, unless the row is what is wrong, and then say why), with one more work-in-progress commit, subject  wip(' + TAG + '): gate repair . Re-run the red cases and every touched suite on both arms before you commit.',
      'The gatekeeper\'s account:', JSON.stringify(gate, null, 1),
    ].join('\n'), { label: 'repair:' + NN + '.gate', phase: 'Gate', schema: REPAIR_SCHEMA })
    repairs.push(gfix)
    if (!gfix) break
  }
}

// ------------------------------------------------------------------ Receipt
phase('Receipt')
const unass = ((attack && attack.unassertable) || []).concat(build.unassertable || [])
const green = gate && gate.verdict === 'GREEN'
const mark = !green ? 'F' : (unass.length > 0 ? 'E' : 'x')
const facts = { item: A.item, slug: SLUG, kind: KIND, base: BASE, mark: mark, build: build, reviews: reviews, attack: attack, repairs: repairs, problemsLeft: open, gate: gate }
const receipt = await agent([
  HEAD_LINE + ' You write the RECEIPT.', '', READER + ' The one file you write is ' + RECEIPT + ' (leave it uncommitted; the driver collects it).', '',
  'The reader is the user, tomorrow morning, who has not followed the night. Write plainly and in full sentences, lead with what they most need, define nothing by the labels the crews used. Sections, in this order:',
  '1. Verdict: the mark ' + mark + ' in words (x: done and every deliverable is reached by a row; E: done, and something has to be looked at; F: not landed), the commit hash if any, one sentence on what the user now has.',
  '2. What to try: the gesture or command, step by step, that shows the change.' + (mark === 'E' ? ' And what to LOOK at, since no row can see it.' : ''),
  '3. Decisions taken for you: each spec hole the crews filled, what they chose, what they rejected. The rulings you gave on 2026-11-21 are not repeated beyond one line each.',
  '4. How it was checked: the rows added and what each break of the product did to them, the suites and arms, the gate\'s trailer line and verdict file. Say what was NOT checked.',
  '5. Left open: problems not fixed, limits, defects seen outside the work order, debts to file (look and rule).',
  '6. Files changed.',
  (CLOSEOUT ? 'This run closed out an earlier run of the item that ended with nothing committed. That run wrote a receipt at the same path and its full result is the JSON file ' + CLOSEOUT.file + ' (decisions, debts, what each stage measured, what it could not reach). Read both. Write ONE receipt for the item as it stands now: keep everything of the earlier one that is still true, correct the verdict, the commit and the gate, and say in section 4 that the item took a second run and why.' : ''),
  'Use only the facts below and what you can read in the clone; where the facts disagree with the tree, the tree wins and you say so.',
  JSON.stringify(facts, null, 1),
].join('\n'), { label: 'receipt:' + NN, phase: 'Receipt', schema: RECEIPT_SCHEMA, effort: 'medium' })

let debts = build.debts || []
let decisions = build.decisions || []
repairs.filter(Boolean).forEach(function (r) { debts = debts.concat(r.debts || []); decisions = decisions.concat(r.decisions || []) })
return {
  item: A.item, slug: SLUG, kind: KIND, verdict: mark,
  commit: gate ? gate.commit : 'NONE', gate: gate,
  receipt: receipt ? receipt.receipt : null,
  decisions: decisions, debts: debts, unassertable: unass,
  problemsLeft: open, repairRounds: round,
}
