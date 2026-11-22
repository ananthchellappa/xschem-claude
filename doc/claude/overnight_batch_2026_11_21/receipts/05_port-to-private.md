# Receipt: item 05, the night's changes carried to the private tree

> **Driver's note, 2026-11-22 16:45.** This receipt was written in the clone `/home/analog/ob21`.
> Since then:
>
> - Nothing is applied or committed in `~/private/xschem-private`; that step is yours. The
>   hand-over is `/home/analog/port_ob21` and its `README.md` opens with the commands.
> - The lead asked the private tree again at 16:45, reading only: HEAD `2e0315892`,
>   nothing staged, `git apply --check` of `/home/analog/port_ob21/port.patch` status 0,
>   `git apply --cached --check` status 0. The patch names 53 files; the five kits name
>   18, 17, 10, 5 and 22.
> - The two full regressions the hand-over keeps are in
>   `/home/analog/port_ob21/regression/`: a clean clone with the five commits ended at
>   `cases=328 blocks=327 counted_failures=0 skips=46` (pid 2716035); the patched copy of
>   your working tree counted 29 failures in 13 cases (pid 1406882), each the same in an
>   unpatched copy (section 5).
> - Debts filed from the main tree (`tests/headless/owed.sh show`): looks
>   `private_options_preview_seed_note_and_groups` and `batch_looks_in_the_private_build`;
>   rules `private_preview_keeps_its_netlist_reader`, `private_seed_note_not_wrapped`,
>   `private_numbering_1657_line` and `port_tool_publishes_before_suites`.
> - The port tool of this hand-over is `/home/analog/port_ob21/tool/make_port.sh`; it
>   supersedes `/home/analog/port_1724/tool/` for a port of landed commits.

Overnight batch of 2026-11-21. Kind: port. Base commit `a3d442d7a`. Written 2026-11-22.

## 1. Verdict

**Done, and something has to be looked at (E).** There is no commit: a port commits
nothing, in any repository. What you have is a hand-over in `/home/analog/port_ob21`: one
patch for `~/private/xschem-private` at `2e0315892`, five commit kits (one per item), and
a `README.md` that opens with the commands to apply, build, restart and commit. Nothing
has been applied to the private tree; that step is yours.

The patch was still accepted by the private tree when this receipt was written
(`git apply --check`, status 0, at 16:41 on 2026-11-22; HEAD `2e0315892`, no tracked file
modified). That tree gets new commits daily, so ask it first (section 2).

The mark is E and not "fully done" for two reasons. Every check ran on a hidden display,
so nobody has seen any of it on your screen. And in the private tree the Options preview
had to be merged by hand onto that tree's own window code, which produced a pane no other
tree shows and one side effect you should rule on (section 5, first entry).

## 2. What to try

**Apply and build.** These are the README's commands; each was typed in a fresh copy of
the private tree.

    cd ~/private/xschem-private
    git rev-parse --short=9 HEAD

It must answer `2e0315892`. Any other answer: apply nothing, and read "If the private tree
has moved" in `/home/analog/port_ob21/README.md`. Then:

    git apply /home/analog/port_ob21/port.patch
    make -C src

`git apply` prints one whitespace warning and ends with status 0. `./configure` is not
needed. Then **restart every open xschem** of that tree: it reads its Tcl files once at
startup.

While the patch is applied and not committed, git refuses every merge into that checkout
that touches one of its files, and the other session merges there daily. To take the
patch out again: `git apply -R /home/analog/port_ob21/port.patch`, then `make -C src`.

**Try, on a real design:**

1. Open the waveform viewer, put the pointer over the plot and press Ctrl-Shift-M. The
   plot mode flips. Press other viewer keys with the pointer over the plot while the
   keyboard focus is in the schematic window: they are viewer keys now, and no editor
   command runs.
2. Double-click a wire to grow the selection along the net. The net-name labels on that
   net are selected with the wires. Press Delete: wires and labels go together. Power
   symbols, ports and devices stay.
3. Open ASE-L, open the Options sheet of a bench with more than one analysis, and read
   the deck preview. The options are grouped under their analysis, in the order the deck
   will run them. Where the order is not settled, a sentence says so.
4. Annotate an operating point from a raw file that also holds noise totals: `op` is read
   again and the operating point is shown.

**Look at, because no check can see it:**

- **The Options preview pane in the private tree.** That tree prints the run's default
  seed line with a note under it, above the new analysis groups. The note stays on one
  line (cut at the pane's edge when the pane is narrow); the new sentence about the order
  wraps. Nobody has seen the two kinds of line together. Is it readable?
- **The keys on your X server**: Ctrl-Shift-M and the other viewer chords as you really
  press them, and where the keyboard lands after a viewer opens or is raised.
- **The double-click grow** on a real design: the look of the selected labels, and that
  the delete takes what you expect.

**Commit, when you are satisfied.** First the line that says whether the ten lines after
it will commit the port and nothing else. It writes nothing:

    cd ~/private/xschem-private
    git diff --cached --quiet && git apply --cached --check /home/analog/port_ob21/port.patch && git apply -R --check /home/analog/port_ob21/port.patch && echo ready

It must answer `ready`. If it answers nothing, something is already staged there
(`git diff --cached --stat` lists it). If git answers with an error, the tree has moved.
In both cases type none of the ten lines and read the README. Then:

    git apply --cached --whitespace=nowarn /home/analog/port_ob21/commit/01/commit.patch
    git commit -F /home/analog/port_ob21/commit/01/message.txt
    git apply --cached --whitespace=nowarn /home/analog/port_ob21/commit/02/commit.patch
    git commit -F /home/analog/port_ob21/commit/02/message.txt
    git apply --cached --whitespace=nowarn /home/analog/port_ob21/commit/03/commit.patch
    git commit -F /home/analog/port_ob21/commit/03/message.txt
    git apply --cached --whitespace=nowarn /home/analog/port_ob21/commit/04/commit.patch
    git commit -F /home/analog/port_ob21/commit/04/message.txt
    git apply --cached --whitespace=nowarn /home/analog/port_ob21/commit/05/commit.patch
    git commit -F /home/analog/port_ob21/commit/05/message.txt

After each commit, `git show --stat --format='%h %s' HEAD | tail -1` answers 18, 17, 10,
5 and 22 files changed, in that order. The commit step changes no file of the working
tree, so there is nothing to rebuild for it.

| kit | main-tree commit | what it carries |
|---|---|---|
| 01 | `9eb647078` | Ctrl-Shift-M in the waveform viewer |
| 02 | `44f2d591f` | the double-click grow takes the net-name labels |
| 03 | `454030f5c` | a key typed with the pointer over a viewer's plot is a viewer key |
| 04 | `2631c7d1a` | one more check of the viewer window's own key handling, and three texts |
| 05 | `dcd53b124`, and two files of `6bd7ecfbb` | issue 1657's two open items (Options preview, `op` behind noise totals) |

The quiz how-to of the first item is not in the port, as planned.

**If the private tree has moved**, run `/home/analog/port_ob21/tool/make_port.sh`. It
writes into neither tree, makes the patch and kits again for the new HEAD, and its last
line (it begins `Suites:`) says whether the suites have anything against the new patch.
The README's section of that name gives the steps for every state that was tried,
including a commit block that stopped half way.

## 3. Decisions taken for you

Your rulings of 2026-11-21, one line each: the Options preview lists its groups in the
deck's order; a request for `op` reads the file again when the table holds noise totals;
the double-click grow takes net-name labels only; the earlier work was committed before
the batch. None was reopened.

What the crews decided where the work order was silent or wrong:

- **The Options preview could not be carried by a merge.** The work order assumed the
  private tree's window code was the main tree's. It is not: that tree has its own text
  for the pane (with the default seed's note under the seed line) and its own netlist
  reader. A three-way merge conflicts in three files. Chosen: merge by hand, keep both of
  the private tree's pieces, and add the groups, the order sentence, its wrap and the
  repaint of an open sheet. Rejected: leaving that part out of the port; replacing the
  private tree's code by the main tree's, which would have moved the seed note under
  "not delivered".
- **The seed note is not wrapped; only the new order sentence is.** The main tree's code
  would have wrapped both, since they have the same shape. Chosen: the option that changes
  least for a user who did not ask. This is a ruling owed to you (section 5).
- **The private tree's netlist reader is kept.** Rejected: importing the main tree's
  reader, which is a change of 2026-11-12 there and not one of the night's items. The
  cost of this choice was measured afterwards and is the first entry of section 5.
- **Three checks of the main tree changed shape.** Of the main tree's three run-seed rows
  one is carried (as RS13); the other two (RS10b, RS12) fence a reader the private tree
  does not have. Row UI25b was adapted to look under the right heading, and row UI25c is
  new: it holds that the sentence wraps and the seed note does not.
- **Five commits, not one.** The existing kit script makes one kit against one HEAD.
  Chosen: the tool makes the five items as five commits in a scratch repository and
  writes each commit's diff. Rejected: one commit for everything, which the work order
  allowed as a fallback.
- **Each commit's subject is the added port line**, of the form `port: <what>
  (xschem-claude <commit>; made 2026-11-22 for 2e0315892)`, with the main tree's message
  under it unchanged. Rejected: the main tree's subject first, as the 1724 hand-over did.
  A reviewer noted that this is not the private repository's `type(scope): subject`
  style, and that kit 05's subject runs to about 290 characters. Edit the first line of
  each `message.txt` before committing if you want it otherwise.
- **Two messages carry one extra paragraph** (kits 03 and 05), because a sentence of the
  main tree's message is false for the commit made in the private tree: kit 03's names a
  file that is not in that commit, and kit 05's says nothing creates the run directory.
- **Two files left out by name.** `doc/claude/TEST_LESSONS.md` does not exist in the
  private tree; rejected: creating it there. The one hunk of
  `doc/claude/issues/NUMBERING.md` rewrites a sentence that tree's line for 1657 never
  received; rejected: writing the missing sentence in.
- **The four FAQ entries keep their numbers** (Q96 to Q99): those were the private tree's
  next free numbers too.
- **The three new suites were registered** in the private tree's own lists, each after the
  same neighbour as in the main tree. Its regression goes from 324 to 328 planned cases.
- **The ported issue file of 1657 is stamped with `2e0315892`**, a commit the private
  tree has, with a note under the stamp. Rejected: the main tree's commit, which that
  tree cannot resolve.
- **The commit commands are guarded by one check line**, not chained with `&&`. Chained,
  the first kit would still be committed before the second refused.
- **The tool puts a new patch in place before its suites run on it**, and says in its
  last line and its exit status whether the suites clear it. Rejected: holding the patch
  back until the suites pass, which leaves no patch at all when a run is stopped. This is
  a ruling owed to you.
- **Three suites' display arms are kept out of the tool's routine list**, because they
  stall there with the port and without it, and every run would spend about 40 minutes
  waiting for them.
- **Scratch.** Leftover emergency-save directories in `/tmp` were removed only where
  their names and times matched the crews' own stalled runs; the others were left.

## 4. How it was checked

All of it in copies of the private tree, on a hidden display, with a throwaway home.
Nothing ran on your screen, and nothing was written in the private tree.

**The commands.** The README was typed line by line in a fresh copy by a second crew that
had not written it: the commit check answered `ready`, all ten commit lines ended with
status 0, the five commits held 18, 17, 10, 5 and 22 files, the diff of the five commits
is the patch byte for byte, and afterwards only your own untracked files were listed. The
build compiled 39 files with no error.

**The checks written for the private tree, and what each break did to them.** With the
new test files on the unpatched program, RS13, UI25b, UI25c and the item's own rows all
fail. Then five breaks were built into the patched window code, one at a time:

| break | what turned red |
|---|---|
| the order question is given the reduced netlist | RS13; UI26 to UI30 |
| every sentence-shaped line is wrapped (the main tree's behaviour) | UI25c alone |
| nothing is wrapped | UI25b, UI25c |
| the netlist is read once and never again | RS13; UI17c, UI26 to UI30 |
| the seed note is listed under "not delivered" | RS4b, PV8b; UI17b, UI25c |

The first three reddened exactly the rows expected; the last two reddened those and some
neighbours. The logs of these runs are only in the session's scratch directory (`p05/`),
which a reboot clears.

**The suites.** 46 suites, 95 runs in all (without a display, on a display, and for six
of them a third time with an action log): 85 pass, 3 skip, 7 are red. The second crew ran
all 95 again and got the same verdict and check count on every one.

- All 7 reds are red without the port too, with the same rows, and none is registered on
  the arm where it is red: `test_wave_sigbrowser_keys` (BK22 on both arms, BK29 and BK31
  on a display), `test_results_select` (SEL462, SEL468, SEL469 on both arms),
  `test_ase_dialogs` (G2sens on a display), and `test_key_graph_context` and
  `test_wire_stub_bindings` without a display, which report nothing.
- The 3 skips: `test_select_same_net_by_label` without a display (it needs a window) and
  `test_paste_at_log` on the two arms without an action log. With the log it passes.

**Two full regressions.**

- A copy of your working tree with the patch, uncommitted and ignored files included:

      T1-RUN-END pid=1406882 cases=328 blocks=327 counted_failures=29 skips=46 elapsed=3553s end=2026-11-22 09:56:33

  The 29 lines are 13 cases. None is a suite the port touches, and each is red in an
  unpatched copy with the same counts. They come from files that are in your working tree
  and not in the repository (section 5).
- A clean clone with the five commits made:

      T1-RUN-END pid=2716035 cases=328 blocks=327 counted_failures=0 skips=46 elapsed=3388s end=2026-11-22 11:05:36

Both verdict files are in `/home/analog/port_ob21/regression/`
(`results.1406882.patched_copy_of_the_working_tree.log` and
`results.2716035.clean_clone_with_the_five_commits.log`). The patch and the kit patches
are byte for byte the ones those two runs used; only two message files changed after
them.

**The stale states.** Each state the README has a command for was built in a copy and
typed through: a tree moved by one commit, the patch left applied, somebody else's commit
on a port file, foreign work staged, a commit block stopped half way, kits typed out of
order, a merge from the other session.

**Where the facts I was given differ from the tree.** The build stage's account says
"46 suites on both arms: 79 pass, 3 skip, 7 red" and gives 11:07 as the time of the last
apply check. The hand-over as it stands says 95 runs with 85, 3 and 7, and 15:43; the
first review found the earlier sentence false and it was corrected. The tree wins. The
private tree also lists ten untracked entries now, not nine: the tenth is `.claude/`,
where another session keeps a worktree.

**What was NOT checked:**

- Your screen, in any tree.
- A real Netlist and Run with the Options sheet open. The checks feed the preview the way
  the product does, but no simulator run drove it. This matters more in the private tree,
  whose reader is its own.
- The apply, the build and the commits in `~/private/xschem-private` itself. They were
  typed only in copies.
- The display arms of `test_paste_modify_flag_0244`, `test_ase_optier_0963` and
  `test_raw_read_dispatch`: they stall at 200 seconds with the port and without it. All
  three pass without a display.
- `test_wave_markers`, the suite with the most checks on viewer keys: it stalls on any
  display (issue 1488) and was not run.
- Row B7 of `tests/wire_stub_netlabel.tcl`, which the grow item edited: the file is in no
  list and reports nothing, so no run reaches that row, in either tree.
- A private tree that has moved in a way git does not refuse (other files changed, or the
  same files elsewhere). The commands go through there; no suite ran on the result. Only
  `git rev-parse` tells you.
- A full regression of any patch the tool makes for a moved tree. The tool runs the 46
  suites, never the whole regression.
- Whether closing a real error box brings the next one (first entry of section 5): the
  probe counted calls with the box replaced by a counter.

## 5. Left open

**The one thing in the port that behaves worse than before, by choice.** In the private
tree the Options preview keeps that tree's netlist reader, and that reader creates the
run directory when it is missing. Before the port it ran when the sheet was filled. With
the port it also runs on every repaint of an open sheet: each time the sheet gets the
keyboard focus, on every change of the session, on a new netlist. Measured in a patched
and an unpatched copy: a missing run directory is created again on focus, and for a bench
with no run directory of its own whose default cannot be made, every focus of the sheet
calls for two error boxes (unpatched: none). In your design work area the rc file makes
the default directory at startup, so there the reader finds it and makes nothing. No
check holds this in the private tree. It was documented and not changed, because changing
the reader would have changed the patch and voided both full regressions.

**Limits of the items, unchanged by the port, that you can meet:**

- "View is Read Only" can still come up from a schematic key in two states: the pointer
  was last in a viewer and now rests outside every drawing area, or a viewer has just
  opened while the pointer rests over the schematic. Moving the pointer into the
  schematic's drawing area ends it.
- When a finished run raises the viewer while you are typing in an ASE-L field or the
  Signal Browser's search box, and the pointer rests over the plot, the next characters
  run viewer shortcuts (measured in the main tree: `e` removed an empty strip).
- After a double-click grow, `q` opens a label's form, and ALT-R or ALT-F turn each
  selected label about its own pin. A label directly on a pin with no wire under it is
  not taken.
- Noise totals stored as `op` are still shown by `xschem raw switch`, by a select that
  names no analysis, and by a graph that loads its own file.

**After you commit**, a branch of the other session that registers a suite at the end of
the display list will conflict in `tests/run_regression.tcl`. Their two list lines first,
the port's comment block under them: that resolution was done in a copy and gives a
complete script.

**Defects seen outside the work order, not touched.** All are the private tree's own, the
same with the port and without:

- The 13 regression cases that are red in a copy of your working tree and green in a
  clone. `test_asemc_e0` (row U0b8) fails on a stale `__pycache__` of 2026-10-30 under
  `tests/headless/asemc/`. `test_layout_xl` (P6, P7, L4, L6) fails on the untracked layout
  view under `sky130A/xschem_libs/layout_xl_demo/`. `test_rdw_keys_1245` (S1, display
  arm) fails on the ignored `tests/headless/untitled~.sch`. Five `test_asemc_u*` suites
  (rows XR0, UF0, HF1) fail on both arms; the README attributes them to your ignored
  Monte Carlo run folders, but the crew that ran them says the cause was not established.
- `test_ase_optier_0963` row Z6 is red when the checkout's path holds a capital letter and
  green for the same files at a path without one. Not measured in the main tree.
- The three display stalls and the reds in unregistered suites listed in section 4.
- The private tree's `NUMBERING.md` line for issue 1657 still says the issue is filed and
  not fixed. Its issue file is stamped fixed by the port.
- `/tmp` holds about 816 emergency-save directories from other sessions.
- Other sessions' runs were live elsewhere on the machine during some suite runs. Every
  red was run a second time and did not move.

**Limits of the hand-over itself:**

- A commit block stopped half way with another commit on top of or between the port
  commits has no command; it needs a hand.
- The tool's comparison calls two reds "the same" when the first failing row and the
  counts agree. A port that turned one later row green and another red in a suite that is
  already red would pass unnoticed. Not met in any run.
- Git does not enforce the order between kits 01 and 02. Typed in the wrong order the
  result is the same tree with two commits swapped.
- After a tool run without suites, or a stopped run, the tables beside the README are
  still the earlier patch's while the patch and kits are new. Two tables
  (`verdict_table_display_arms.md`, `verdict_table_t1_reds.md`) are never rewritten by
  the tool.

**Debts to file.**

Looks (your eyes):

- The Options sheet's deck preview in the private tree on a real bench: the seed line
  with its unwrapped note above the analysis groups, and the wrapped order sentence.
- The looks the items already owe, now for the build you work in: the viewer keys with
  the pointer over the plot, the labels of a double-click grow, the Options preview.

Rulings (your decision):

- **The preview's reader in the private tree.** Keep that tree's reader, with the cost
  above, or give the preview a reader that only asks and carry the main tree's check for
  it. Evidence: `/home/analog/port_ob21/tool/out_repair1/probe_rundir.patched.out` and
  `probe_rundir.unpatched.out`.
- **The seed note in the private tree.** It stays on one line, cut at the pane's edge
  when the pane is narrow (60 characters, no horizontal scrollbar). Wrap it too?
- **The private `NUMBERING.md` line for 1657.** Update it by hand?
- **The port tool.** Should a new patch be held back until its suites have passed?

Not a debt, but yours to decide: the `port:` subject lines (section 3).

**Scratch left in place.** `/home/analog/pp21` is the patched and built copy of the
private tree; it holds copies of your uncommitted files, so delete it when you no longer
need it. `/home/analog/rt05.logs` (1.3 MB) holds the second crew's typed commands and
logs. Every other scratch copy is removed.

## 6. Files changed

Nothing in the main tree, nothing in the private tree, and nothing in the clone
`/home/analog/ob21` except this receipt (HEAD `a3d442d7a`, otherwise clean). Everything
is under `/home/analog/port_ob21`:

- `README.md`: the commands, what differs in the private tree, what was and was not
  tested.
- `port.patch`: 53 files, 1 new (`tests/headless/wvkey_engine.tcl`) and 52 modified.
- `commit/01` to `commit/05`, each with `commit.patch`, `message.txt` and `files.txt`.
- `run_summary.md`: every file of the port and how it was carried.
- `verdict_table.md`, `verdict_table_display_arms.md`, `verdict_table_t1_reds.md`: the
  suite results, each red with the unpatched copy's answer beside it.
- `regression/`: the two verdict files.
- `tool/`: `make_port.sh` and what it needs (`lib/`, `adapt/` with the hand-merge rules,
  the suite lists), the logs of the last run in `out/`, and the trials of the two repair
  rounds in `out_repair1/` and `out_repair2/`, each with a `00_INDEX.txt`.

What the patch changes in the private tree, once you apply it: the seven C files
`src/select.c`, `src/actions.c`, `src/paste.c`, `src/callback.c`, `src/save.c`,
`src/scheduler.c` and `src/xschem.h`; Tcl in `src/` (among them `src/ase.tcl`,
`src/ase_window.tcl` and `src/wave_viewer.tcl`); test suites under `tests/` with three
new registrations in `tests/run_regression.tcl`; and documents under `doc/` (specs, the
guide, FAQ entries Q96 to Q99, the issue file of 1657). Six files differ from the main
tree's change because they were adapted: `src/ase.tcl`, `src/ase_window.tcl`, the issue
file of 1657, `doc/claude/specs/ase_l.md`, `tests/headless/test_ase_optsheet_1441.tcl`
and `tests/headless/test_ase_run_seed.tcl`. The full list per commit is in each kit's
`files.txt`.
