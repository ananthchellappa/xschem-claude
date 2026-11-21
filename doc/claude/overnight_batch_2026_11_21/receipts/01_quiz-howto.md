# Receipt: item 01, how to build the tip-of-the-day quiz in another tree

Overnight batch of 2026-11-21. Kind: document. Base commit `23c551453`.

## 1. Verdict

**Done, and something has to be looked at (mark E).**

The work is one commit in the clone `/home/analog/ob21`, not pushed and not yet in the main tree:
`462c192b4` "docs(help): how to build the tip-of-the-day quiz in another tree".

You now have a how-to that a session working in `~/private/xschem-private` can follow to build the startup quiz there: `doc/claude/suggestions/howto_startup_quiz_in_another_tree.md`.
The same commit corrects one sentence of the quiz spec.

Three things need you:

- **Landing.** The how-to and the corrected spec sentence must reach `/home/analog/dev/xschem-claude` together. Cherry-picking `462c192b4` does that. Until then the how-to's step that copies the spec would copy the uncorrected sentence.
- **A ruling.** Once the private program has the quiz, both programs share the on/off switch and the answered list in `~/.xschem` (section 5 below).
- **The untested end of the document.** The check that no other suite's launch gets a quiz window, and the full regression in the private tree, were written from reading and run by nobody.

## 2. What to try

Nothing changes in the program, so there is no gesture to try. What you can do:

1. Read the document in the clone: `/home/analog/ob21/doc/claude/suggestions/howto_startup_quiz_in_another_tree.md`. It has eleven sections: what is being built, what to read first, a pre-check of the target tree, the wiring step by step, running the suite, making the question bank true for that tree, adding questions, the startup-window trap for other suites, registering and gating, what the user sees and is owed, and keeping two banks honest.
2. Land it: in `/home/analog/dev/xschem-claude`, `git cherry-pick 462c192b4`.
3. Hand the document to a session in the private tree and let it start at section 3, the pre-check block.

What to look at, because no row can see it:

- **Section 10 of the how-to**, on what you will experience. The design workarea's launcher runs the private tree's program straight from its source tree. The quiz therefore goes live for you as soon as that session builds the wiring, not at hand-over. The head of section 4 says so and offers working in a clone instead.
- **Whether the document reads well cold.** One dry run followed it without having to look anything up elsewhere, but that was a session, not you.
- **The quiz window on your real screen**, once the private program has it. The existing look debt for this repository's window (`startup_quiz_dialog`) is still open as well.

## 3. Decisions taken for you

Your rulings of 2026-11-21, one line each: this item is a how-to and not a patch; it invents no fix for the shared `~/.xschem` files; it does not edit the startup-guard suite or the share-farm header.

Holes the crews filled:

- **Where the four quiz files are copied from.** Chosen: one pinned commit of `fluid-editing`, read with `git show`, with the hash saved for the reader's commit message. Rejected: `cp` from the working tree, where another session may be mid-edit.
- **How the wiring edits are given.** Chosen: both the exact text to type per step, and a shortcut that applies the hunks of commit `d36cb429e` for the four files where they apply cleanly, followed by a comparison with this repository. Rejected: hand edits only, or a patch file made by this item.
- **When the suite is registered.** Chosen: last in the wiring section, after both arms are green. Rejected: registering before the first run.
- **How the reader proves the bank's proofs hold in their tree.** Chosen: by running the suite in their own binary. Rejected: printing a text-only comparison script of about ninety lines, whose answer is weaker.
- **How the bank's rules are stated.** Chosen: rules in words, a grep that prints the rows' own names, and a small reading aid printed in the document. Rejected: quoting thresholds and counts as facts, or adding the aid as a file under `tests/`.
- **How a launch is recorded for the census.** Chosen: temporary lines in the launch procedure that append to a fixed file. Rejected: a path passed through an environment variable, and `::argv`.
- **The spec sentence that said the suite measured "a bare launch".** The first crew left it. The repair crew fixed it in this repository's spec, because the suite gives every child launch a `--script` file. Rejected: leaving it wrong here and telling the reader to fix their copy.
- **The rows named per wiring step.** Chosen: measured by taking each step out of the clone, running both arms and restoring it. Rejected: trusting a reading of the suite.
- **The header's promise of a command beside every figure.** Chosen: narrowed, so that statements measured by breaking the wiring, statements that were read, and descriptions of a row say which they are. Rejected: printing the breaking commands for someone to repeat in the main tree.
- **Who files the ruling on the shared files.** Chosen: this repository's side files one; the reader checks the ledger first. Rejected: each side filing its own.
- **Shell variables between a reader's tool calls.** Chosen: two lines defining the source repository and a fixed scratch directory, repeated in every fresh shell. Rejected: `mktemp -d`.
- **Proof for a key outside the binding table.** Chosen: a literal of the key's arm in the C key handler. Rejected: a menu accelerator text, which binds nothing.
- **The regression's progress output.** Chosen: written to the scratch directory. Rejected: a stray file in the gate clone's root.

## 4. How it was checked

No rows were added and no product code changed; this is a document. It was checked by reading it against both trees and by following it.

**Two independent reviews** of the first version found 26 problems, among them five blockers:

- The key switch was attributed to `callback()`; it is in `handle_key_press()`.
- The order in which a launch decides the switch missed the rc variable `user_startup_commands`.
- The document said no second install list names Tcl helpers; the Windows installer manifest does.
- It pointed the by-hand review at the viewer and the Calculator, while ASE-L differs most between the trees.
- A file typed by hand as printed could not pass the document's own comparison step, because the printed blocks left out their comments.

All are repaired in the text, except one that is not this item's (section 5).

**The repair crew measured each wiring step** in the clone by removing it, running the quiz suite on both arms, and putting it back:

- The line that loads the engine removed: the suite runner prints `NORESULT` on both arms, not `FAIL`. The first version had this wrong.
- The `--pipe` mirror removed: rows B11 and B12 on either arm, plus Z4 and L5 on the display arm, plus Z5 under the regression's flags.
- The launch hook removed: F5 and F6; on the display arm also L2 to L12 except L4.
- The Help menu block removed: A15 for the switch question, F12, F13; on the display arm also D25 to D28.
- The default line removed: Z6, A13 and A15.
- The line that loads the saved choice removed: the counted arm stays green; only L8 and L12 on the display arm go red.
- The two action-table rows removed: A15, F7 to F11; on the display arm also D29 and D30.
- The commented rc line removed: F14. A skipped `./configure`: F4, once per file.

**A dry run followed the document** in a scratch copy of the private tree at `a464b7f6b`, wiring typed by hand, and repeated every break above except Z5 under the regression's flags:

- The quiz suite passed on both arms: 256 checks counted, 316 on the display arm. With one trial question added: 257 and 317.
- The hand-typed files were byte-identical to the applied hunks.
- With the suite registered, the three guard suites passed: `test_registered_banner_1626` (10 checks), `test_suite_watchdog_1403` (40), `test_home_isolation` (120).
- `test_startup_guard_0663` passed on both arms (23 checks) after its two sentences were corrected in the copy.
- Two bad bank entries of the tester's own made row A15 go red in the two shapes the document prints.

The scratch copy was removed, and the private tree and `~/.xschem` were left as found.

**The gate.** No regression was run for this item, so there is no trailer line and no verdict file. The commit touches no product file, no test and not the regression driver, so no trailer term can move. `tclsh tests/headless/issue_stamp.tcl` answers `ISSUE-STAMP: ok (0 problems)`. The clone's baseline before the batch is `tests/results.2248040.log`: `cases=225 blocks=224 counted_failures=0 skips=13`, 1424 s.

**Not checked:**

- The census of section 8 over a full regression. Its temporary lines and two greps were tried on the quiz suite's display arm alone: 9 launches were recorded, all the suite's own.
- The gate in the private tree, and committing there.
- What the private tree's own suites do when one of their child launches is asked a question. Only the census shows it.
- The by-hand review of the bank against the private tree: 20 of 82 entries were read, and nothing false was found. The wrong options and the unproved reasons of the other 62 are checked by nothing.
- Two statements the document marks as read, not measured: that a process started by `new_xschem_process` is asked again, and that `--rcfile` alone does not keep the quiz away.
- The window on a real screen.

One figure in the facts disagrees with the tree: the build account calls the document "about 1160 lines". After the repair the committed file has 1549 lines.

## 5. Left open

**Debt to file, kind rule (not in the ledger yet).** The two programs share `~/.xschem/startup_quiz` and `~/.xschem/startup_quiz_done`. "Don't show anymore" in either turns the quiz off in both. An answer in one rewrites the answered list with only that program's ids, so once the banks differ the other program's own questions come round again. Today the answered list holds six ids and there is no saved switch, so the private program's first interactive launch after the port will ask. Decide: one switch or two, one list or two. The how-to tells the other session this is filed from this repository's side.

**Debt, kind look.** None new from this item. `startup_quiz_dialog` is still open. The other session is told to file its own for its program.

**Five notes from the dry run, not repaired.** None blocks a reader.

- The loop over suites that read the action table walks only this repository's suites.
- Section 7 does not say where in the bank file a new entry goes. Appending at the end worked.
- There is no command that prints one bank entry by its id.
- The registration line is printed with 18 leading blanks against 17 in the other tree.
- The landing condition from section 1.

**Seen outside the work order, not touched:**

- `tests/headless/test_startup_guard_0663.tcl` (its header and the name of row SG0) and the header of `tests/headless/sharefarm.tcl` still call `ciw.tcl` the one caught source of `xschem.tcl`. With the quiz there are two. That suite is in neither regression list.
- Both `CLAUDE.md` files still describe exit 139 for a helper that is sourced but not installed. Since issue 0663 that is an announced abort with exit 1.
- No row of the quiz suite reads the line `set_ne startup_quiz_done {}`. The call that loads the saved choice is seen only on the display arm.
- The spec's precedence list for the switch is still shorter than the how-to's. It omits `--tcl`, the rc's `tcl_files`, `postinit_commands` and `user_startup_commands`. The code does not contradict it, so it was left.
- The port tool under `/home/analog/port_1724` assumes the private tree has no quiz. `make_port.sh` will stop with "edit the note" once the bank exists there.
- `PLAN.md`'s baseline line still reads `BASELINE_PENDING`, though the clone holds the finished verdict named in section 4.
- Reds seen while measuring the action-table suites, identical with and without the quiz rows, in the clone:
  - `test_action_log_dispatch` prints `NORESULT` on both arms.
  - `test_key_graph_context` and `test_keybindings_help` print `NORESULT` under `--nogui`.
  - `test_wave_sigbrowser_keys` fails BK22 on the counted arm and BK22, BK29 and BK31 on the display arm.
  - `test_descend_doors_1228` fails on the display arm.
  - `test_paste_modify_flag_0244` times out at 200 s on the display arm.

  The last two are registered for the counted arm only. None has been diagnosed.
- Two directories `/tmp/xschem-test-home.899554.*` and `/tmp/xschem-test-home.901629.*` are left over from some other run.

## 6. Files changed

Commit `462c192b4` in `/home/analog/ob21`, parent `23c551453`:

- `doc/claude/suggestions/howto_startup_quiz_in_another_tree.md` (new, 1549 lines)
- `doc/claude/specs/startup_quiz.md` (one sentence of section 4: every child launch of the suite carries a `--script` file; a launch with none is read in `Tcl_AppInit`, not measured)

The commit message file is at `/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/ovb01_commit_msg.txt`.

## Driver's note (2026-11-21 10:40)

- **Landed.** The main tree's branch had moved (another session committed `444126b6e`,
  the condensed `CLAUDE.md`), so the item was landed by cherry-pick: it is `d198fce04` in
  `/home/analog/dev/xschem-claude`. The how-to and the corrected spec sentence are both
  there. Read the how-to at
  `/home/analog/dev/xschem-claude/doc/claude/suggestions/howto_startup_quiz_in_another_tree.md`.
- **Section 3 above mislabels three lines.** "A how-to and not a patch", "no fix invented
  for the shared `~/.xschem` files" and "the startup-guard suite is not edited here" were
  decisions the lead took when writing the work order, not rulings of the user. The user
  can overrule any of them.
- **The ruling on the shared files is filed**: `owed.sh` rule `startup_quiz_shared_conf`.
- **`PLAN.md`'s baseline line** was filled in by the driver at 01:50; the clone's copy
  was older.
