# Overnight batch 2026-11-21

**Status: LAUNCHED 2026-11-21.** While the work orders were being written the user said:
"OK, when ready, proceed with implementing the batch plan. Don't wait for another
go-ahead. This is it". The driver log at the foot of this file says where it stands.

**It did not run through the night.** The session that drives it ended at about 03:00
with item 01 in its repair stage, and nothing ran until the user resumed it at 09:26.

Four items the user asked for on 2026-11-21, and a fifth that carries the product changes
to the tree the user's design work runs on.

- Main tree: `/home/analog/dev/xschem-claude`, branch `fluid-editing`.
- Work clone: `/home/analog/ob21` (made for this batch; every crew works there and only there).
- Pipeline: `doc/claude/overnight_batch_2026_11_21/item_pipeline.js`, one run per item.
- Work orders: `doc/claude/overnight_batch_2026_11_21/prompts/NN_<slug>.md`.
- Receipts: `doc/claude/overnight_batch_2026_11_21/receipts/NN_<slug>.md`.
- Port hand-over (item 05): `/home/analog/port_ob21/`.

## Ledger

Run order is the order of this table. Item 02 is the largest and runs after the two
gesture items, so those land first.

| mark | item | slug | kind | what the user gets |
|------|------|------|------|--------------------|
| `[E]` | 01 | `quiz-howto` | doc | a how-to another session can follow to build a tip-of-the-day quiz in `~/private/xschem-private` |
| `[E]` | 03 | `viewer-ctrl-shift-m` | code | Ctrl-Shift-M in the waveform viewer toggles single/multi plot mode; no "View is Read Only" popup from a key in the viewer |
| `[E]` | 03b | `viewer-keys-with-focus-elsewhere` | code | a key typed with the pointer over the viewer's plot acts as a viewer key whichever window has the keyboard, and right after a viewer opens; added by the lead after item 03's first run (see its detail) |
| `[E]` | 04 | `dblclick-grow-takes-labels` | code | the double-click grow takes the net-name labels on the wires it selects |
| `[E]` | 02 | `issue-1657-open-items` | code | the Options preview shows the deck's order with labelled groups; a request for `op` reads again when an untyped read stored the noise totals |
| `[E]` | 05 | `port-to-private` | port | patch, proof and the commands to apply, build, restart and commit items 02 to 04 in `~/private/xschem-private` |

## Verdict alphabet

| mark | meaning |
|------|---------|
| `[ ]` | not started |
| `[x]` | done: built, attacked, gated at zero counted failures, committed, landed in the main tree, and every deliverable is reached by a row |
| `[E]` | done as `[x]`, but at least one deliverable is pixels, feel or layout that no row can see. The final report asks the user to look, and a `look` debt is filed. |
| `[D]` | deferred with the reason recorded (the request contradicts the source, or the scope grew past one run) |
| `[F]` | not landed: the build stopped, blockers were left after three repair rounds, or the gate stayed red because of the item. The work is kept as a patch beside the receipt. |

## Ruled by the user on 2026-11-21

These are decisions, not suggestions. A crew does not reopen them.

1. **Issue 1657, open item 1 (the Options preview): deck order and labels.** The preview asks
   the same question the deck asks, using the netlist the window already reads, and lists the
   per-analysis groups in the order the deck will run them. Each group is headed by its
   analysis. Before a netlist of this session exists it says plainly that the `op` group may
   run last. The user chose this from a sketch:

   ```
   inside the analysis block      (sketch, wording not final)

     tran
       option itl4=200
       option itl4=10          <- put back
     op                        <- runs last in this deck
       option gmin=1e-10

     note: gmin is left in force for every
           analysis after op (none in this deck)
   ```

2. **Issue 1657, open item 2 (an `op` table that holds the noise totals): read again when
   `op` is asked.** A request that names `op` and meets a table that an untyped read took
   from the noise totals reads the file again and gets the operating point. Every caller is
   cured (annotate, `xschem raw read <file> op`, scripts). A file without noise totals
   behaves exactly as today.

3. **The double-click grow takes net-name labels only.** `lab_pin` and `lab_wire` labels whose
   pin touches a wire the grow selects are selected with it. Power symbols of the `vdd`/`gnd`
   kind are not taken (they are told apart by their `global` attribute), and neither are
   ports, probes or devices. This overrules decision O2 ("wires only") of
   `doc/claude/specs/dblclick_connected_select.md`, ratified 2026-07-12. The user's reason:
   "Sometimes, one does this just to select all connect material to delete easily."

4. **Commits.** The issue 1724 and 1657 work was committed before the batch (`7c77f3594`).
   Each item that gates green lands as its own local commit on `fluid-editing`. Nothing is
   pushed. An item that does not gate green is left out and handed over as a patch with the
   reason.

The user's own words for the two gesture items are quoted at the head of their work orders.

## Run rules

The pipeline gives every crew these rules in full. The ones that shape the batch:

- **One runner per clone.** Inside an item only one stage at a time starts xschem, and it
  runs one thing at a time. The two readers of the Review stage run side by side because
  they run nothing. (Until 2026-11-21 22:55 the rule was one item at a time on the whole
  machine, and a crew waited for ANY live run. Item 03 then lost hours waiting for the
  full regressions another session runs in its own clones. Since then: two items may run
  side by side in two clones, `/home/analog/ob21` and `/home/analog/ob22`; a crew waits
  only for a run in its own clone; a run elsewhere is noted, and a red taken while one
  was live is run once more before it is believed. Several xschem processes that start
  in the same second can collide: issues 1706 and 1725, the same temporary names.)
- **An attack hunts once.** The first attack of an item builds breaks of its own, and one
  that no row catches is a blocker. Every later round CHECKS the repair: a wrong
  behaviour, a red, an unfixed problem and a mistake of the repair are blockers; a
  further break that no row catches is recorded as a known gap. (Until the same hour
  every round hunted again. Item 03's product measured right through three rounds, and
  each round still found new hypothetical breaks, so the item never reached its gate.)
- **Private display only.** `DISPLAY` in a tool shell is the user's Windows X server. Every
  xschem start goes through `run_suites.sh`, `gated_xschem.sh` or the regression driver with
  `AUDIT_DISPLAY=private` / `T1_DISPLAY=private` and `env -u DISPLAY`.
- **Every command has a bound**, and a stall is reported as `TIMEOUT`, not waited on.
- **Crews write only in the clone.** The main tree, `~/private/xschem-private`,
  `/home/analog/dev/ngspice-ver_53`, `/home/analog/gcp0`, `/home/analog/g1724`,
  `/home/analog/pp1724`, `/home/analog/port_1724` and `~/.xschem` are not written by any crew.
  Item 05 writes under `/home/analog/port_ob21/` and in scratch copies it makes and removes.
- **Spec holes.** The rulings above are fixed. For a hole they do not cover, the crew takes
  the option that changes least for a user who did not ask for it, records the question, the
  decision and what it rejected, and goes on. The receipt lists every such decision.
- **Debts.** Crews do not touch the owed ledger. They return `look` and `rule` debts; the
  driver files them from the main tree after backing the ledger up.
- **Commits authorised by the launch:** one commit of this batch directory before the first
  item (the plan and the work orders, so the clone can pull them); one commit per green item;
  one last commit of `PLAN.md` and the receipts. Explicit file lists only. Never a push.

## Baseline

Taken during preparation, in the clone, at `7c77f3594` (the commit the batch starts from):

- Build: `./configure` and `make`, both rc 0.
- Full regression on a private display (`T1_DISPLAY=private`), 2026-11-21 01:25 to 01:49:
  `cases=225 blocks=224 counted_failures=0 skips=13 elapsed=1424s`
  (`/home/analog/ob21/tests/results.2248040.log`; `wc -l` 679; no case off zero, no
  counted shape, no live peer announced). It is the trailer the 1724 gate gave on the
  same code in `~/g1724`.

A gate of an item compares its own trailer with this one after deriving, from the
registration lists, what the item must add.

**Moved on 2026-11-22 02:33, when item 04 landed (`44f2d591f`).** A tree that has item 04
has three registered cases more (`test_dblclick_connected_grow` in `hcases` and `dcases`,
`test_select_same_net_by_label` in `dcases`) and two `skip:` lines more (both printed by
`test_dblclick_connected_grow` on the arm without a canvas and without an action log).
Item 04's own gate on such a tree: `cases=228 blocks=227 counted_failures=0 skips=15`
(`/home/analog/ob22/tests/results.1547194.log`, 690 lines). An item whose base is
`44f2d591f` or later derives its delta from that; an item whose base is older (item 03b:
`c78d0f1d3`) still derives from the figure above. As always, derive from the registration
lists of your own base; these lines only say what to expect.

Known reds that are not an item's (each crew also takes its own baseline of the suites it
touches before it changes anything):

- `test_wave_markers` times out on a private display and on the dev display (issue 1488).
- `test_ase_optier_0963` fails now and then with a `NORAW rc={1}` line (the flake recorded in
  `CLAUDE.md`). One more full run is the handling; a red there is still a red.
- Neither is a T1 failure in the baseline above unless the baseline line says so.

## Driver procedure

The driver is the session that launched the batch. It acts between items; crews never do
these steps.

**At launch**

1. Main tree: `git status --short` shows no tracked change of the batch's files; the two
   modified `sky130_fd_sc_hvl` files are someone else's work and stay as they are.
2. Commit this directory in the main tree (plan, work orders, pipeline), explicit list.
   `git -C /home/analog/ob21 pull --ff-only`, so the clone has them.
3. Back up the owed ledger: `cp -r ~/.claude/xschem_owed ~/.claude/xschem_owed.bak.20261121`.
4. No regression or suite run is live (matched by command name, not by argument text).
5. Schedule a check-in every twenty minutes for the length of the batch (below).

**Per item, in ledger order**

1. `base=$(git -C /home/analog/ob21 rev-parse HEAD)`; the clone has no uncommitted tracked change.
2. Run the pipeline: `Workflow({scriptPath: ".../item_pipeline.js", args: {item, slug, kind, base}})`.
3. When it returns with `x` or `E`:
   - land it: `git -C /home/analog/dev/xschem-claude fetch -q /home/analog/ob21 fluid-editing`
     then `git merge --ff-only FETCH_HEAD`. If the main tree's branch moved meanwhile,
     `git cherry-pick` the item's commit instead and say so in the ledger; a conflict leaves
     the item as a patch and marks it `[F]` with that reason.
   - if the commit changed C sources or `src/Makefile.in`: `./configure` when needed and
     `make -C src` in the main tree, so its binary matches its source.
   - copy the receipt from the clone to this directory; tick the ledger; file the debts.
4. When it returns with `F`: first read WHY.
   - The gate was red for a reason that is not the item's (`RED_OTHER`), or could not be
     taken (`NOT_RUN` with no blocker left): the item's work is intact in the clone as
     work-in-progress commits. The driver takes one more full regression itself. At zero,
     it makes the item's one commit and lands it. If the same case is red on the item's
     base as well, the item is committed with that standing red named in its commit
     message, its receipt and the final report: by case and rows, never as a count.
   - Anything else (the build stopped, blockers were left, the item reddens the gate):
     keep the work (`git -C /home/analog/ob21 branch ovb-NN-failed`, and
     `git diff <base> ovb-NN-failed` written beside the receipt as
     `NN_<slug>.failed.patch`), put the clone back on `<base>` (`git reset --hard <base>`,
     in the clone only), rebuild the clone, copy the receipt (or write a short one when
     the pipeline stopped before its receipt stage), mark `[F]`.
5. Item 05 runs last and carries only the items that landed.
6. Every step the driver takes is one line in the driver log below, with the time: the
   item, the pipeline's task id, run id and transcript directory at launch; the verdict
   and commit at return; what was landed.

**Check-in.** A job fires every twenty minutes while the session is idle. It reads the
driver log for the running pipeline and looks at its transcript directory: if no agent
transcript there was written for forty minutes, the run is stalled; it is stopped and
resumed from its journal (finished agents are not run again). If a pipeline has returned
and the next item was not started, it continues this procedure. Otherwise it does
nothing.

**Scout notes.** `maps/NN_<slug>.map.json` is what a read-only scout found for each item on
2026-11-21, and `maps/NN_<slug>.check.json` what a second reader, told to refute it,
confirmed, corrected and added. The work orders were written from both. They are notes
of that day, not a description of the tree.

**At the end**

1. Commit `PLAN.md` and `receipts/` in the main tree (explicit list). Remove the check-in.
2. Report to the user: per item the verdict, what to try, what to look at, the decisions
   the crews took, the debts filed; and for the private tree the commands to apply, build,
   restart any open xschem and commit, from `/home/analog/port_ob21/README.md`.

## Item detail

Each work order is self-contained. The lines here say only what is not in it.

### 01 quiz-howto

A document; no product change in this repository and no regression gate. It runs first
because another session may be waiting for it. It lands like any item, so its path in
the main tree is fixed: `doc/claude/suggestions/howto_startup_quiz_in_another_tree.md`.
It is tested the way a how-to can be: after two readers, a cold reader with nothing but
the document follows it in a scratch copy of the private tree (`/home/analog/pq21`, made
and removed by that stage) and runs the quiz suite there on both arms.

### 03 viewer-ctrl-shift-m

The user's report names one key. The work order's family table is the scope: every key the
viewer lets through that can reach an editor verb or the read-only popup.

### 03b viewer-keys-with-focus-elsewhere

Not one of the user's four items: the lead added it. Item 03's first run found that the
popup the user reported is also reached when the keyboard focus is in a schematic window
and the pointer rests over the viewer's plot, and right after a viewer opens: the user's
own likely gesture. Work order 03 had told its crews the chord need only work with the
focus on the plot; that point is withdrawn. It runs right after item 03, in the same
clone, and changes `callback()`.

### 04 dblclick-grow-takes-labels

Ruling 3 above. `tests/headless/test_dblclick_connected_grow.tcl` is in no list of
`tests/run_regression.tcl` when the batch starts, so today it gates nothing; registering it
is part of the item.

### 02 issue-1657-open-items

Rulings 1 and 2 above: two changes, in two different places (`src/ase.tcl` and the window
for the first, `src/save.c` and the registry for the second), one commit. The second
reader found that the second change, built the plain way, breaks three things that work
today (a read during a draw, the Calculator's restore, the rule that a select never
frees). The work order gives the shape that keeps them working and says what to do if it
cannot be built within it: land the first change, leave the second open with the
measurements. When the item is done the issue's stamp line and its "Open items" section
say what is closed, what is a stated limit and what the user can still choose.

### 05 port-to-private

The user's design workarea runs the xschem of `~/private/xschem-private`, so a change made
here is not in front of the user until it is carried over. The hand-over ends with the
commands to commit it there; a patch without them is not finished.

## Driver log

Times are local, 2026-11-21 unless a date is given.

- 01:18 the issue 1724/1657 work committed in the main tree as `7c77f3594` (82 files; the two modified `sky130_fd_sc_hvl` files are not this session's and stay uncommitted).
- 01:21 work clone `/home/analog/ob21` made from `7c77f3594` and built (`./configure`, `make`, both rc 0).
- 01:25 baseline full regression started in the clone (private display, pid 2248040; verdict `/home/analog/ob21/tests/results.2248040.log`).
- 01:48 plan committed as `23c551453`; clone pulled to it. Owed ledger backed up to `~/.claude/xschem_owed.bak.20261121`. Check-in job `2fa16655` (minutes 7, 27, 47).
- 01:48 item 01 launched: task `wklght3xr`, run `wf_b9029379-036`, base `23c551453`, transcripts `/home/analog/.claude-taiga/projects/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/subagents/workflows/wf_b9029379-036`.
- 01:49 baseline regression ended at zero counted failures (see "Baseline").
- 01:50 the three remaining second-reader answers arrived (items 03, 04, 02). Work orders 03, 04 and 02 rewritten with their corrections; to be committed and pulled into the clone when item 01 has landed, before item 03 starts.
- 02:18 item 01: the how-to written (work-in-progress commit `722c84627` in the clone). 02:38 both readers answered; the writer started on what they found.
- about 03:00 the driving session ended (last transcript write 02:59). The item's pipeline stopped with it; the check-in job, which lives in the session, went too. Nothing ran for six and a half hours.
- 09:23 another session committed `444126b6e` in the main tree: `CLAUDE.md` condensed, the lessons that left it in `doc/claude/TEST_LESSONS.md`. The main tree's branch has therefore moved past the plan commit; the clone does not have that commit yet.
- 09:26 the user said "resume". 09:28 item 01 resumed from its journal: task `wbo3506uj`, run `wf_b9029379-036` (same run, same transcript directory), base `23c551453`. The how-to and both readers' answers were reused; the repair runs again, told about the interrupted writer's uncommitted edits in the clone and about the condensed `CLAUDE.md`. The pipeline gained an optional driver note for its repair stages for this. New check-in job (minutes 7, 27, 47).
- Because the main tree moved, item 01 lands by cherry-pick, not fast-forward. Then: the clone is put on the main tree's head, the revised work orders and this file are committed and pulled, and item 03 starts from there.
- 10:08 item 01: the repair done; the dry run started in `/home/analog/pq21`. 10:37 the pipeline returned: verdict E, no blocker left, no repair round after the dry run, commit `462c192b4` in the clone.
- 10:38 item 01 landed in the main tree by cherry-pick as `d198fce04` (the branch had moved, see 09:23). Receipt copied to `receipts/01_quiz-howto.md` with a driver's note. Rule debt filed from the main tree: `startup_quiz_shared_conf`. Marked `[E]`: the census and the gate in the other tree were written from reading and run by nobody, and the window there has to be looked at once it exists.
- 10:38 revised work orders, baseline, pipeline note and item 01's receipt committed in the main tree as `f09888cda`. Clone put on it (`git fetch`, `git reset --hard origin/fluid-editing`, in the clone only); its build is current, no run is live.
- 10:39 item 03 launched: task `wzze7glcr`, run `wf_d0770c87-61d`, base `f09888cda`, transcripts `/home/analog/.claude-taiga/projects/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/subagents/workflows/wf_d0770c87-61d`.
- 17:29 check-in: item 03 is in its second attack (since 15:08). Its runner spent part of that time waiting for a full regression that ANOTHER session was running in another clone, because the batch's one-runner rule says to wait for any live run. To do between items, not now (changing the rules text while an item is in flight would make a resume of it start over): narrow the rule so a run in another session's checkout is noted and not waited for, and a red taken while one was live is run once more before it is believed.
- 22:50 item 03's pipeline returned F: "blockers left after repair; not gated, not committed". Read why: three repair rounds, and after each the attack measured the product right and built NEW breaks that no row caught (the last six: a second column of subwindows, a second tab, a resize, a second viewer, cursors showing, markers and the cursor readout in the Cadence profile). Not the item's failure: the pipeline's rule that every round hunts again. The work (four work-in-progress commits, last `e19d5293b`, Tcl only) stays in the clone.
- 22:55 decided, as driver: (1) the pipeline is changed (clone as an argument; wait only for runs in one's own clone; later rounds check instead of hunting; a close-out mode that starts at the repair of what an earlier run left). (2) Item 03 is closed out, not discarded: its six open problems are rows to write, then a check, the gate and the commit. Its first run's result is `receipts/03_viewer-ctrl-shift-m.run1.json`. (3) Item 03b is added (see the ledger and its detail). (4) Item 04 runs at the same time in a second clone, `/home/analog/ob22`.
- 22:57 pipeline changes, work order 03b and item 03's first-run result committed in the main tree as `747cc6f3f`. Lane A (clone `/home/analog/ob21`): item 03's close-out launched: task `wk46crt3f`, run `wf_c019b01a-7ab`, base `f09888cda`, transcripts `/home/analog/.claude-taiga/projects/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/subagents/workflows/wf_c019b01a-7ab`. The clone stays on `f09888cda` plus the work in progress, so the close-out lands by cherry-pick; lane A's next item is 03b, after the clone is put on the main tree's head.
- 22:57 lane B: clone `/home/analog/ob22` being made from `747cc6f3f` and built; item 04 starts in it when the build is done. Check-in job replaced (`7,27,47`), now for two lanes.
- 22:58 lane B: clone `/home/analog/ob22` built (`./configure`, `make`, both rc 0) at `747cc6f3f`. Item 04 launched in it: task `wbub3n3hd`, run `wf_52746670-d3c`, base `747cc6f3f`, transcripts `/home/analog/.claude-taiga/projects/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/subagents/workflows/wf_52746670-d3c`. No baseline regression was taken in this clone: its tree is the first clone's baseline tree plus documents only.
- 2026-11-22 00:43 lane A: item 03's close-out returned: verdict E, no problem left, one repair round (rows only, no product file), gate green in the clone (`T1-RUN-END pid=3819655 cases=225 blocks=224 counted_failures=0 skips=13`, verdict `/home/analog/ob21/tests/results.3819655.log`), commit `373eaf5aa` in the clone (parent `f09888cda`, 18 files, Tcl only).
- 2026-11-22 00:44 item 03 landed in the main tree by cherry-pick as `9eb647078` (the branch had moved to `747cc6f3f`; the item's 18 files are identical to the gated ones). No rebuild: no C file. Receipt copied to `receipts/03_viewer-ctrl-shift-m.md` with a driver's note. Owed ledger backed up to `~/.claude/xschem_owed.bak.20261122`; filed from the main tree: look `viewer_ctrl_shift_m_real_screen`; rules `viewer_keys_focus_elsewhere` (the first run's two focus debts in one entry; item 03b works on it), `viewer_cadence_s_swaps_cursors`, `viewer_user_binding_rows` (binding rows and the Escape row in one entry), `viewer_graph_use_ctrl_key`, `viewer_plot_mode_menu_accel`. Marked `[E]`: nothing was seen on the user's X server.
- 2026-11-22 00:46 work order 03b gained two riders that item 03's receipt left open in the same code (a row for the chord with exactly one cursor showing; the inset of `wviewer::btn2_filter` at a high Tk scaling), each to be dropped and returned as a debt if it does not fit the first build.
- For the final report, from item 03's receipt: standing reds in unregistered suites, all older than the item (`test_wave_sigbrowser_keys` BK22 on both arms, BK29 and BK31 on the display arm; `test_wave_axis_zoom` CV2c on the display arm; `test_wave_sigbrowser_0312` BF21a and BF24a on the display arm); `test_startup_quiz` and `test_wave_grid` leave gitignored `*~.sch` backups under `xschem_library/`; one process incident in the first run (a bare `./src/xschem --version` started with `DISPLAY` on the user's screen; it exited by itself and no file of the user's changed).
- 2026-11-22 00:48 lane A: clone `/home/analog/ob21` put on the main tree's head `c78d0f1d3` (no run live in it, build current). Item 03b launched: task `wjtdkmg09`, run `wf_cd32e78a-3bf`, base `c78d0f1d3`, args `{item:3, nn:"03b", slug:"viewer-keys-with-focus-elsewhere", kind:"code", base:"c78d0f1d3", clone:"/home/analog/ob21"}`, transcripts `/home/analog/.claude-taiga/projects/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/subagents/workflows/wf_cd32e78a-3bf`. Lane B: item 04 still running (task `wbub3n3hd`, run `wf_52746670-d3c`).
- 2026-11-22 02:32 lane B: item 04's pipeline returned: verdict E, two repair rounds, gate green on the first full run in the clone (`T1-RUN-END pid=1547194 cases=228 blocks=227 counted_failures=0 skips=15`, verdict `/home/analog/ob22/tests/results.1547194.log`; three registrations and two `skip:` lines more than the baseline, all the item's), commit `2583c3e1b` in the clone (parent `747cc6f3f`, 18 files). One problem left, severity "should": row B7 of the unregistered `tests/wire_stub_netlabel.tcl` was edited and no run reaches it.
- 2026-11-22 02:33 item 04 landed in the main tree by cherry-pick as `44f2d591f` (`src/cadence_style_rc` merged by itself with item 03's lines; the C files, the suite and `tests/run_regression.tcl` are identical to the gated ones). Main tree rebuilt (`make -C src`, rc 0); `run_suites.sh --nogui test_dblclick_connected_grow` there: 112 checks pass. Beyond the label pass the commit carries two repairs the crews made outside the work order's text, in wiring code: `add_pin_stubs()` (`src/actions.c`) and `merge_wire()` (`src/paste.c`) order a wire's end points before storing it; `doc/claude/WIRING.md` section 1.1 records it.
- 2026-11-22 02:35 receipt copied to `receipts/04_dblclick-grow-takes-labels.md` with a driver's note. Filed from the main tree: look `dblclick_grow_labels_real_design`; rules `dblgrow_q_opens_label_form`, `dblgrow_alt_r_f_strands_labels`, `dblgrow_label_on_bare_pin`, `dblgrow_gschem_power_symbols`; suite debts `test_dblclick_connected_grow` and `test_wave_viewer` (each owes its one run on `:0`; the batch ran on a private display only). Marked `[E]`.
- **The figure later items are gated against has moved**: a tree with item 04 has `cases=228 blocks=227` and `skips=15` (the baseline's 13 plus the grow suite's two on the arm without a canvas). Items 03b (base `c78d0f1d3`, without item 04) still expects 225/224/13 in its own clone.
- To do when every item has landed, before item 05: (1) one full regression on the main tree's head in a clone, because items 03, 03b, 04 and 02 were each gated on their own base and meet only in the main tree; (2) mint issue numbers, from the main tree and with both checks, for the defects the receipts list as open and unfiled: `xschem paste` crashes (signal 11) on a clipboard file whose `G` record is empty (item 04's receipt, section 5); others as the remaining receipts name them.
- For the final report, from item 04's receipt: `test_selflog_output` (unregistered) fails six key rows with the action log, with and without the item; `test_shape_draw_gate` and `test_placement_preview_doors` time out on the display arm (headless-only suites); `tests/wire_stub_netlabel.tcl` (unregistered) fails five rows and dies before its row B7; `xschem move_objects` right after `xschem merge` prints a "re-armed" note; a missing abort of the armed move at the double click is caught by no row (the end state measured identical).
- 2026-11-22 02:36 lane B: clone `/home/analog/ob22` put on the main tree's head `7b0b601b7` (no run live in it; build current, rc 0). Item 02 launched: task `wguyzufa2`, run `wf_1f4fca4f-2d0`, base `7b0b601b7`, args `{item:2, slug:"issue-1657-open-items", kind:"code", base:"7b0b601b7", clone:"/home/analog/ob22"}`, transcripts `/home/analog/.claude-taiga/projects/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/subagents/workflows/wf_1f4fca4f-2d0`. Lane A: item 03b still running (task `wjtdkmg09`, run `wf_cd32e78a-3bf`).
- 2026-11-22 06:49 lane A: item 03b's pipeline returned: verdict E, one repair round, gate green in the clone (`T1-RUN-END pid=598977 cases=225 blocks=224 counted_failures=0 skips=13`, verdict `/home/analog/ob21/tests/results.598977.log`; its base `c78d0f1d3` is without item 04, hence 225), commit `fcdb11585` in the clone (11 files; `src/callback.c`, `src/wave_viewer.tcl`, `src/xschem.tcl`). Two problems left, both "should": no row for a key on the viewer's own window while the pointer is over the Signal Browser; a spec sentence without its condition. The repair took back the first build's "focus the plot at an open".
- 2026-11-22 06:51 item 03b landed in the main tree by cherry-pick as `454030f5c`. Conflicts in two documents with item 04, resolved by hand keeping both sides: `doc/claude/FAQ.md` (this item's entry renumbered Q97 and put on top; a missing `---` added under Q96) and `doc/claude/TEST_LESSONS.md`. `src/callback.c` merged by itself. The other eight files are identical to the gated ones. Main tree rebuilt (rc 0); `run_suites.sh --nogui test_wave_subwindows test_dblclick_connected_grow`: 289 and 112 checks pass.
- 2026-11-22 06:52 receipt copied to `receipts/03b_viewer-keys-with-focus-elsewhere.md` with a driver's note. Filed from the main tree: look `viewer_keys_focus_elsewhere_real_screen`; rules `viewer_keys_focus_elsewhere` (updated in place: the item as a whole), `viewer_read_only_still_reachable`, `viewer_mirror_state_keys`, `viewer_keyboard_after_open_or_raise`, `viewer_handed_key_details`, `viewer_mmb_pan_inset_high_scaling`. Marked `[E]`.
- The baseline verdict `/home/analog/ob21/tests/results.2248040.log` named under "Baseline" is gone: item 03b's gate run swept it as a dead run's verdict older than a day (`T1_VERDICT_KEEP`). Its trailer is quoted above and in item 03's gate file `/home/analog/ob21/tests/results.3819655.log`, which carries the same 13 skip lines.
- For the final report, from item 03b's receipt: the tabbed interface has no row for this item, and one probe saw the pointer coming back from a viewer make the FIRST tab the working one; "Descend to here" focuses the design window's toplevel after raising it (the pattern this item met in the viewer); crews made scratch clones `/home/analog/ob21r` and `/home/analog/ob21h` against the batch rule and removed them; the new rows wait a fixed short time after each pointer warp (a possible flake on a loaded machine).
- 2026-11-22 06:53 lane A: clone `/home/analog/ob21` put on the main tree's head `a754efdc7` and rebuilt (rc 0; no run live in it). A follow-up to item 03b started there as ONE agent, not a pipeline (three small things from its receipt's section 5: the missing row in band KM23 for a key on the viewer's own window while the pointer is over the Signal Browser, shown red under its break; the spec sentence without its condition; the stale comment above `viewer_takes_foreign_key`). It makes one commit on `a754efdc7` and runs the viewer suites, not the full regression: the combined run before item 05 covers it. Lane B: item 02 still running (task `wguyzufa2`, run `wf_1f4fca4f-2d0`).
- 2026-11-22 07:13 lane A: the follow-up to item 03b returned and landed in the main tree by fast-forward as `2631c7d1a` (5 files: one new check in band KM23 of `test_wave_viewer`, red alone under its break and green on the product; the comment above `viewer_takes_foreign_key` in `src/callback.c`, comment only; the spec, the guide and FAQ Q97 state the search-box case with its condition, and the guide says Ctrl-Shift-4 typed in the schematic with the pointer in the viewer does nothing). Main tree rebuilt (rc 0). `test_wave_viewer` now gives 536 checks alone on the display arm and 539 with the action log. Not run through a full regression yet: the combined run covers it. Seen by its agent and carried to the final report: `test_key_graph_context` under `--nogui` stops at startup with `invalid command name "focus"`, exits 0 and scores NORESULT (unregistered; passes on the display arm). Lane A is free.
- 2026-11-22 07:13 lane A: a full regression of the tree so far (main's head `2631c7d1a`: items 03, 04, 03b and the follow-up; item 02 is not in it) started in `/home/analog/ob21`, detached, private display: pid 871961, verdict `/home/analog/ob21/tests/results.871961.log`, output `/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/combined/t1_run1.log`, `planned_cases=228`. Expected trailer, derived from item 04's gate: `cases=228 blocks=227 counted_failures=0 skips=15`. It is an early answer on how the separately gated items sit together; the run that counts is the one on the head that also has item 02. Item 02's gate is live in `/home/analog/ob22` at the same time.
- 2026-11-22 07:27 lane B: item 02's pipeline returned: verdict E, one repair round, gate green on the first full run in the clone (`T1-RUN-END pid=754992 cases=229 blocks=228 counted_failures=0 skips=15`, verdict `/home/analog/ob22/tests/results.754992.log`; one registration more than its base: `test_annot_op_behind_tran_1242` in `hcases`), commit `ea60e07a0` in the clone (parent `7b0b601b7`, 23 files; `src/save.c`, `src/scheduler.c`, `src/xschem.h`). Both parts of the work order were built. Three deliberate breaks are caught by no check (the product is right in each).
- 2026-11-22 07:29 item 02 landed in the main tree by cherry-pick as `dcd53b124`. One conflict, `doc/claude/FAQ.md`, resolved by hand keeping every entry: the item's two entries renumbered Q99 and Q98 and put on top of item 03b's Q97. The other 22 files are identical to the gated ones. Main tree rebuilt (rc 0).
- 2026-11-22 07:30 two small text errors the receipt names corrected in the main tree (the comment above `ase::ui::optsheet_preview` in `src/ase_window.tcl`; the issue file's list of checks now reads R14 to R18); `issue_stamp.tcl` ok. Receipt copied to `receipts/02_issue-1657-open-items.md` with a driver's note. Filed from the main tree: look `options_preview_deck_order_real_screen`; rules `opt_preview_wording`, `opt_preview_line_order`, `raw_totals_as_op_names`, `op_reread_makes_op_current`, `issue_1657_cure_not_taken`. Marked `[E]`.
- For the final report, from item 02's receipt: reds and stalls in unregistered suites or arms, all the same on a build of the item's base: `test_results_select` (SEL462, SEL468, SEL469, both arms), `test_raw_read_dispatch` (stalls on a display at SC06 and leaves a `/tmp/xschem_emergencysave_*` directory), `test_ase_optier_0963` (stalls on a display after N3; registered headless only), `test_ase_dialogs` G2sens (private display), `test_ase_window` W7 (red once with other runs live, green alone); `doc/claude/specs/calculator.md` still says the Calculator always restores the user's table (not so for `vdc()` on a totals table); the annotate chord's third step picks its slot by comparing a slot index with a hierarchy level.
- 2026-11-22 07:31 lane B: clone `/home/analog/ob22` put on the main tree's head `6bd7ecfbb` (every item landed) and rebuilt (rc 0). THE COMBINED RUN started there, detached, private display: pid 996718, verdict `/home/analog/ob22/tests/results.996718.log`, output `/tmp/claude-1000/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/scratchpad/combined/t1_final_run1.log`, `planned_cases=229`, no live peer announced in that clone. Expected trailer, derived from item 02's gate (the one tree that had every registration): `cases=229 blocks=228 counted_failures=0 skips=15`. The earlier run without item 02 (pid 871961 in `/home/analog/ob21`) is still live.
- 2026-11-22 07:37 the run without item 02 ended in `/home/analog/ob21` as derived: `T1-RUN-END pid=871961 cases=228 blocks=227 counted_failures=0 skips=15 elapsed=1446s end=2026-11-22 07:37:25` (`/home/analog/ob21/tests/results.871961.log`, 690 lines, `planned_cases=228`; no block off zero, no counted shape, no live peer announced). Items 03, 04, 03b and the follow-up sit together at zero.
- 2026-11-22 07:38 lane A: clone `/home/analog/ob21` put on the main tree's head `a3d442d7a` and rebuilt (rc 0; no run live in it). Item 05 (the port) launched: task `wqbc6hquc`, run `wf_c11905fe-cae`, base `a3d442d7a`, args `{item:5, slug:"port-to-private", kind:"port", base:"a3d442d7a", clone:"/home/analog/ob21"}`, transcripts `/home/analog/.claude-taiga/projects/-home-analog-dev-xschem-claude/478872cd-9a2b-4322-b146-d62b97914d06/subagents/workflows/wf_c11905fe-cae`. Launched before the combined run with item 02 ended (pid 996718 in `/home/analog/ob22`, due about 07:55); if that run ends red the port is stopped and started again after the repair.
- 2026-11-22 07:54 THE COMBINED RUN ended green, as derived: `T1-RUN-END pid=996718 cases=229 blocks=228 counted_failures=0 skips=15 elapsed=1391s end=2026-11-22 07:54:11` (`/home/analog/ob22/tests/results.996718.log`, 693 lines, `planned_cases=229`, private display, throwaway home, binary `/home/analog/ob22/src/xschem`; no block off zero, no counted shape, no live peer announced). The tree it ran on is `6bd7ecfbb`: every item of the batch, the 03b follow-up and the two corrected sentences. What the main tree gained after it is documents of this batch only. The port (item 05) goes on.
- 2026-11-22 16:45 item 05 (the port) returned: verdict E, no commit (a port commits nothing), gate GREEN, 2 repair rounds, no problem left, 8 agents. Hand-over `/home/analog/port_ob21` (`README.md`, `port.patch` of 53 files, five commit kits `commit/01` to `commit/05` with 18, 17, 10, 5 and 22 files, `tool/make_port.sh`, `regression/` with both verdicts). The lead asked the private tree again, reading only: HEAD `2e0315892`, nothing staged, `git apply --check` status 0, `git apply --cached --check` status 0. The clean clone with the five commits ended at `T1-RUN-END pid=2716035 cases=328 blocks=327 counted_failures=0 skips=46`; the patched copy of the working tree counted 29 failures in 13 cases, the same in an unpatched copy. Receipt copied to `receipts/05_port-to-private.md` with a driver's note. Filed from the main tree: looks `private_options_preview_seed_note_and_groups`, `batch_looks_in_the_private_build`; rules `private_preview_keeps_its_netlist_reader`, `private_seed_note_not_wrapped`, `private_numbering_1657_line`, `port_tool_publishes_before_suites`. Marked `[E]`. Nothing was written in `~/private/xschem-private`.
- For the final report, from item 05's receipt: in the private tree the Options preview keeps that tree's netlist reader, which creates a missing run directory; with the port it runs on every repaint of an open sheet (rule `private_preview_keeps_its_netlist_reader`). While the patch is applied and not committed, git refuses the other session's merges into that checkout that touch one of the 52 modified files. After the commits, a branch of the other session that registers a suite at the end of `dcases` conflicts in `tests/run_regression.tcl` (their two list lines first, the port's comment block under them). The private tree's own: 13 cases red in a copy of the working tree and green in a clone (`test_asemc_e0` U0b8 on a stale `__pycache__`; `test_layout_xl` on the untracked layout view; `test_rdw_keys_1245` S1 on an ignored file; five `test_asemc_u*` suites, cause not established); `test_ase_optier_0963` Z6 red when the checkout's path holds a capital letter; display arms of `test_paste_modify_flag_0244`, `test_ase_optier_0963`, `test_raw_read_dispatch` time out with and without the patch. Scratch left: `/home/analog/pp21` (patched copy, holds copies of the user's uncommitted files) and `/home/analog/rt05.logs`.
- 2026-11-22 16:45 the batch is closed: every row of the ledger is `[E]`. The hourly stall check is deleted.
