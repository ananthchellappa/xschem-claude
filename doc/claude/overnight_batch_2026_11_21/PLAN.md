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
| `[ ]` | 03 | `viewer-ctrl-shift-m` | code | Ctrl-Shift-M in the waveform viewer toggles single/multi plot mode; no "View is Read Only" popup from a key in the viewer |
| `[ ]` | 04 | `dblclick-grow-takes-labels` | code | the double-click grow takes the net-name labels on the wires it selects |
| `[ ]` | 02 | `issue-1657-open-items` | code | the Options preview shows the deck's order with labelled groups; a request for `op` reads again when an untyped read stored the noise totals |
| `[ ]` | 05 | `port-to-private` | port | patch, proof and the commands to apply, build, restart and commit items 02 to 04 in `~/private/xschem-private` |

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

- **One item at a time, and one runner at a time.** Several xschem processes that start in
  the same second can collide (issues 1706 and 1725: the same temporary names). So items run
  in sequence, and inside an item only one stage at a time starts xschem. The two readers of
  the Review stage run side by side because they run nothing.
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
- 10:40 item 01 landed in the main tree by cherry-pick as `d198fce04` (the branch had moved, see 09:23). Receipt copied to `receipts/01_quiz-howto.md` with a driver's note. Rule debt filed from the main tree: `startup_quiz_shared_conf`. Marked `[E]`: the census and the gate in the other tree were written from reading and run by nobody, and the window there has to be looked at once it exists.
