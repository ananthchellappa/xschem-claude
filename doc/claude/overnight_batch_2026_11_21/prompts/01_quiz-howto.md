# Work order 01 — a how-to for building the tip-of-the-day quiz in another tree

Prepared 2026-11-21. A document. No product code changes in this repository.

## The request

The user: "Write out a how-to for the private xschem batch to refer to to create a
tip-of-the-day quiz like this repo provides".

"The private xschem batch" is another Claude session. It works in
`~/private/xschem-private` (branch `assembler`), commits there itself, and has none of
this session's context. This repository got its quiz in commit `d36cb429e`
("feat(help): tip of the day at startup, asked as a quiz").

## What you write

One file, in the clone:

    doc/claude/suggestions/howto_startup_quiz_in_another_tree.md

Once the item lands, the reader finds it at
`/home/analog/dev/xschem-claude/doc/claude/suggestions/howto_startup_quiz_in_another_tree.md`,
and that is the path the document gives for itself. Every path it gives into THIS
repository is an absolute path under `/home/analog/dev/xschem-claude/` (the main tree,
which holds the same commits as the clone you work in).

## The reader, and what done means for them

A capable engineer who was not here tonight and will read the document from the top and
do what it says, in a tree you cannot write to. They need: what they are building and
how they will know it is done; what to copy unchanged and what to write new; each wiring
step with the check that proves it; how to make every question TRUE for their tree; how
to add their own; how to keep the quiz out of every other suite's launches; how to
register and gate it. They do not need the history of how this repository got there.

The next stage hands your document to a cold reader who follows it, with nothing else,
in a scratch copy of the private tree, and runs the checks it gives. Every step that
fails or has to be guessed comes back to you.

## Decided by the lead (do not reopen; the receipt lists them for the user)

1. **Port and extend, not rebuild.** The reader copies the engine, the suite, the spec and
   the bank from this tree, wires them in, lets the suite re-prove every question against
   THEIR product, and then adds questions for what only their tree has. A scout read both
   trees on 2026-11-21 (the private one at `a464b7f6b`) and found every dependency of the
   engine and the suite present there, and that the bank's proofs, checked statically,
   answer the same in both trees for all but the two questions about the quiz itself.
   That is dated evidence for choosing this route, not a baseline: the document prints
   the commands with which the reader re-derives it, and says what to do when the answer
   differs.
2. **A how-to, not a patch.** The other session does the work and commits it in its own
   flow. Nothing is applied to the private tree by this item.
3. **Same switch, same default.** The quiz is on by default there as it is here.
4. **The two programs share `~/.xschem`.** The document says so plainly and what follows
   (below); it does not invent a fix.

## What the document must carry

The scout's full notes are at
`/home/analog/dev/xschem-claude/doc/claude/overnight_batch_2026_11_21/maps/01_quiz-howto.map.json`
(read only). Its `recommended` field holds a section-by-section outline; use it as the
skeleton and check each fact in it against the tree before you write it down. The
skeptic's corrections to those notes, if any, are appended at the foot of this work
order: where the two differ, the correction wins, and where either differs from the
tree, the tree wins.

Sections, in this order:

1. **What you are building, and what done looks like.** One paragraph on what the user
   sees. Done: the quiz suite green on both arms in their tree; a census showing that no
   other suite's launch is asked a question; their full regression at zero counted
   failures in a clone at a short path; the dialog recorded as something the user has to
   look at.
2. **Read these first.** The spec, the bank's header comment, the suite's header. Say the
   two things a reader gets wrong without them: the engine stores a question's `proof` and
   never evaluates it, and the proof helpers live in the suite.
3. **Before you start: check that your tree still has what the engine leans on.** A
   command block the reader runs, not a list to believe. Give what the scout found, with
   its date and commit.
4. **Wiring, in the order it must be done, each step with its check.** The four files to
   copy; `src/Makefile.in` and what it obliges; the two edits in `Tcl_AppInit`; the four
   sites in `src/xschem.tcl`; the two rows of `src/actions.csv`; the block in
   `src/xschemrc`; the two registrations. For each: the exact text or the place to copy
   it from, the anchor it goes beside (named by its content, never by line number), and
   the row of the suite that goes red when the step is skipped or done wrong.
5. **Run it.** The armed spelling for each arm, on a private display. What a bare
   `./src/xschem --script ...` does instead (child windows on the user's screen, the real
   HOME), so nobody types it.
6. **Make the bank true for your tree.** This is the section the document exists for. A
   red proof row names a question that is false there: fix the question, or delete the
   entry and never reuse its id; do not weaken the proof. Then what NO row checks: the
   wrong options of every multiple-choice question, any clause of `why` that the proof
   does not name, and whether a proof is the right proof (the standard: it must fail if
   the feature were removed or renamed). Say how to review those by hand against a tree
   that has features this one lacks, and what an `upcoming` question needs the day its
   feature is built.
7. **Adding your tree's own questions.** The entry format field by field with the rules
   the engine enforces; the kinds and the verdict each produces; the bank rules the suite
   enforces, each stated with the command that reads the present figure rather than with
   a number; which helper proves which kind of claim; how a wrong option is made (and the
   rule that it must not be a second way of doing the thing); `only` for anything tied to
   a profile or a PDK.
8. **The trap for a whole tree: a startup window in other suites' launches.** What keeps
   a launch from being asked (name the flags) and what does not (the throwaway test HOME
   has no saved switch, so the default there is ON). How to run the census. What to do
   with a hit. Name the launch the scout's static scan flagged in that tree as the first
   place to look, as a lead, not a finding.
9. **Register and gate.** In the reader's own tree's terms; point at their `CLAUDE.md` for
   the rules they already have instead of restating them.
10. **What the user sees and is owed.** Every interactive launch asks a question until
    the box is ticked, the design workarea's launcher included. The two files under
    `~/.xschem` are read and written by both programs: one switch for both; and the
    answered list is rewritten with only the ids the running program's bank holds, so
    with two different banks an answer given in one program forgets the other program's
    own ids. Say that neither tree changes this today and that it is the user's call.
11. **Keeping two banks honest afterwards.** A feature carried between the trees takes its
    reworded questions with it. The port tool of issue 1724 under
    `/home/analog/port_1724/tool` is written on the premise that the private tree has no
    quiz; say which of its files state that.

## Rules for this document

- Check every command, path, proc name, row id and quoted line against the tree it
  speaks about, by reading, at the moment you write it. A fact from the scout's notes
  that you cannot find again is left out.
- No count that only a command can produce, unless the document prints the command and
  presents the figure as "what it answered on 2026-11-21". The bank's size, the suite's
  check counts and the other tree's suite counts all move.
- No line numbers. Name the proc, the C function, the row, or quote the anchor text.
- Plain sentences, in the order the reader acts. A command block wherever the reader
  types something. No vocabulary from tonight's batch (no "item 01", no "the scout").
- It is not an issue file: it does not go under `doc/claude/issues/` and carries no
  stamp line.
- Leave the spec `doc/claude/specs/startup_quiz.md` as it is unless you find a sentence
  in it that the code contradicts; then fix that sentence and say so in your answer.

## Done means

The file exists at the path above, committed as work in progress in the clone, and you
have followed your own section 3 and section 4 against the private tree by reading
(nothing written there) and found each anchor you name.

---

## Corrections from the second reader (2026-11-21)

A second reader, told to refute the scout's notes, re-derived them against both trees.
Its full answer is `maps/01_quiz-howto.check.json` beside the scout's notes. The route
(port and extend) survived: it found every anchor and dependency again, and its own
static comparison of the proofs gave the same result. These points correct or add to the
notes; where they differ from the notes, these win.

**Wrong or stale in the notes**

1. The bank's two reworded questions are COMMITTED (`7c77f3594`), not uncommitted. Tell
   the reader to copy the four files from the main tree as it stands when they read
   (`git -C /home/analog/dev/xschem-claude log --oneline -- src/startup_quiz_bank.tcl`
   shows what moved it), not to apply commit `d36cb429e`, whose bank hunk holds the older
   wording. Later items of this batch may add to the bank again.
2. A missing `cli_opt_pipe` mirror is caught by four rows, not one: B11 and B12 on either
   arm, Z4 and L5 on the display arm.
3. A new Tcl file that fails to load no longer segfaults: since issue 0663 a failed BARE
   source is an announced abort with exit 1 (`xschem_startup_announce` in `src/xinit.c`,
   in both trees). The quiz's source is caught, so its own failure is silent absence and
   one degraded notice. Do not tell the reader to expect a crash; cite 0663 beside 0423
   and 0424.
4. The precedence of the switch has two more doors: `--tcl` text runs before `xschem.tcl`
   is sourced (so it behaves like an rc line and loses to a saved choice), and
   `postinit_commands` runs after it and before `--script` (so it wins for that launch).
   Read the order in `Tcl_AppInit` and give it whole.
5. The spec and the note beside the registration cannot be copied word for word: the
   spec's section on the gates ends with a census sentence about THIS tree's regression,
   and the note after the `hcases` list says both arms were captured and scored before
   the entries went in. The reader copies, then rewrites those two sentences from their
   own census and their own capture.

**Missing from the notes**

6. The user's `~/.xschem/startup_quiz_done` already holds answered ids and there is no
   saved switch, so the default is ON: the first interactive launch of the other program
   after the port WILL ask. With the same ids in both banks, what the user answered here
   stays answered there.
7. Once per launch means once per PROCESS. `new_xschem_process` (`src/actions.c`) starts
   another xschem with none of the flags that keep the quiz away, so each such process
   asks again until the box is ticked; new windows and tabs in one process do not.
8. The design workarea's launcher (`build_cmd` in `/home/analog/dev/hdo-design/run.tcl`)
   starts xschem with `--rcfile` and `--script` and none of those flags, so those
   sessions are asked.
9. One question's `why` text is within a few characters of the length budget the suite
   enforces; rewording it for the other tree can redden that row. Tell the reader how to
   see each entry's lengths against the budgets instead of quoting figures.
10. The key-binding helper can prove only keys that are rows of the binding table, and
    reads the LIVE table: the shipped file plus the user's own `keybindings.csv` under
    the configuration directory, loaded before the suite redirects that directory. Under
    the throwaway test home there is none; with the real home a user's remap can redden
    a proof for a reason that is not the bank. Keys that still live in the editor's key
    switch are proved in the bank by menu or palette TEXT, which the bank itself says
    binds nothing: for such a key, name a literal in `src/callback.c` as the honest
    proof.
11. Where the by-hand review in the other tree should look first: the viewer and the
    Calculator differ most there (histogram plots and hand moves in the viewer; variables,
    rounding and crossings on a DC sweep in the Calculator), and the menus gain "Launch
    xlay" and the integrator entries. No statement of the bank was found false there,
    but those are the features with no question and the places where an unproved clause
    can go stale.
12. The other tree's `CLAUDE.md` is a condensed edition. It has the rules the document
    leans on (the configure obligation with its check, registering a suite with its
    fence, the completion banner, the short clone path, the stall bound, the armed
    launchers), not this tree's long measurements. State each trap in the document and
    cite that file only for a rule it has.
13. No second install list and no manual page needs the new files: nothing outside
    `src/Makefile.in` names the shipped Tcl helpers.
14. The scout's static scan flagged one launch in the other tree's suites
    (`tests/headless/test_asemc_u5.tcl`); read through, its child script exits inside the
    script phase, before the hook, so it is not asked. Launches assembled in pieces or
    through helpers escape a text scan, so the census stays a required step and that
    suite is only an example of how to read one.
15. A sentence this tree's own commit made untrue, which the other tree will inherit the
    same way: `tests/headless/test_startup_guard_0663.tcl` (its header and the name of
    row SG0) and the header of `tests/headless/sharefarm.tcl` call `ciw.tcl` the one
    caught source of `xschem.tcl`; with the quiz there are two. Tell the reader to
    correct those sentences in their tree when they add the second caught source. In
    THIS tree, do not edit them in this item: report them in your answer.

**The dry run exists.** The notes and the second reader both assumed nobody would follow
the document tonight. The pipeline does: after the readers, a cold reader follows your
document in a scratch copy of the private tree and runs the suite there on both arms.
The census and the full regression are the only steps it reads without running.
