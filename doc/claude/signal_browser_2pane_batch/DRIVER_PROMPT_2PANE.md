# Two-pane Signal Browser — overnight DRIVER prompt

Everything between the markers goes into a fresh Claude Code session. Launching
the batch **is** the authorization for one commit per green item (plus fixup
commits from the repair stage). **Nothing is ever pushed.**

---

## Before you launch — five minutes, and skipping them wastes the night

1. **The GUI gate cannot be pressed while you sleep.** The X arm runs dozens of
   times and every run asks the panel for permission. Two honest options:
   * `export GUI_GATE=0` — the gate fails open and every suite just runs. Windows
     will appear and disappear on `:0` all night. **This is the one to use for an
     unattended run.**
   * Install `xvfb` (`sudo apt install xvfb`) and the X arm can run on a private
     display instead. **Not currently installed** — `xvfb-run` and `Xvfb` are both
     absent. It would also sidestep item 3 below. Worth doing if you plan more
     overnight batches, but it is a change to the machine, so it is your call.
2. **⚠ WSLg's Xwayland dies about three times a session and takes every client
   with it.** This is the single biggest overnight risk: it cannot be revived from
   inside the VM (the cure is `wsl --shutdown` from Windows). The pipeline treats
   a dead X server as **DEFER, not FAIL**, so the batch degrades honestly instead
   of recording garbage — but if it dies early you may wake to four `[D]`s.
   Installing xvfb is the only real mitigation.
3. `cd src && make` must be green before you start. Never `make` while a suite runs.
4. `git status --porcelain -- src tests doc` — note the pre-existing dirty files.
   They must still be the only dirty tracked files (batch dir excepted) at the end.
5. Three commits from the current session are **unpushed** (`958ada03`,
   `a98ab6fe`, `e5347591`). The batch adds more. Push is never automatic.

---

------ start prompt ------

Run the two-pane Signal Browser batch. Repo `/home/qflow/dev/xschem/claude_1/xschem`,
branch `fluid-editing`. This is an unattended overnight run.

You are the **DRIVER**. **You do not implement items yourself.** You sequence
items, launch one workflow per item, and read receipts. You do not `Read` source
files, you do not `Edit` or `Write` anything outside
`doc/claude/signal_browser_2pane_batch/`, and you do not compose commit messages
— the pipeline stages do all of that. If you find yourself opening
`src/wave_viewer.tcl`, you have drifted; stop and re-read this paragraph.

**State lives on disk, not in your context.** After any interruption or
compaction, re-read `doc/claude/signal_browser_2pane_batch/LEDGER.md` and
continue from it. Never reconstruct batch state from memory.

**Always write `two-pane item N`.** A second Signal Browser plan shares the
numbering and a bare "item N" has caused real confusion three times.

READ FIRST (once, then stop reading):
1. `doc/claude/signal_browser_2pane_batch/LEDGER.md` — the ledger, the recorded
   baseline, the dependency table, and what item 12 carried forward. **Source of
   truth for what runs next.**
2. `doc/claude/signal_browser_2pane_batch/PLAN.md` — the spec for each item. You
   pass its item sections through to the pipeline verbatim; you do not act on
   them yourself, and **the batch never writes to this file.**
3. `doc/claude/signal_browser_2pane_batch/12_receipt.md` — the most recent item,
   and the shape every receipt must take.

PREFLIGHT (once, before item 13):
1. `timeout 15 xdpyinfo -display :0` must return 0. If the X server is dead, do
   **not** start: every X-arm item would defer. Report and stop.
2. `cd src && make` green. If not, STOP and report — never start on a broken build.
3. `git status --porcelain -- src tests doc` — record the pre-existing dirty set.
4. Confirm `GUI_GATE=0` is exported, or that a long allow window is open.
   Without one of those, every X run blocks on a panel nobody will press.

LOOP (fully autonomous — **never ask the user anything**; when in doubt the answer
is DEFER, recorded):
1. Read `LEDGER.md`. If every ledger line is `[x]`/`[E]`/`[D]`/`[F]`, go to FINAL
   REPORT.
2. The next item is the first ledger line still `- [ ]`, in ledger order
   (13 → 14 → 15 → 16 → 17b → 18 → 19). **Strictly sequential; never two in
   flight** — every item touches `src/wave_viewer.tcl` and the same test files.
3. Enforce the dependency table in `LEDGER.md` before launching:
   * A `[D]`/`[F]` on **13** blocks **14** and **18**.
   * A `[D]`/`[F]` on **16** blocks **17b**, and therefore **18**.
   * Mark a blocked item `[D] blocked by item N` **yourself** (this is the one
     ledger edit you make directly) and carry on to the next runnable item. A
     blocked dependant does not stop the batch.
   * **15 and 19 always run.** 15 depends on nothing outstanding; 19 documents
     whatever actually shipped, including the defers.
4. `pixel` is `true` for any item whose deliverable is something the user SEES.
   Of the remaining set that is **13** (reveal/scroll behaviour), **15** (the
   per-DB tree shape) and **18** (the auto-tick and its message). A pixel item may
   never be marked `[x]` — `[E]` plus an eyeball-queue row. Pass `pixel: false`
   for 14, 16, 17b and 19.
5. Launch the per-item workflow, then **END YOUR TURN.** It notifies you on
   completion. Do not poll, do not write an `until [ -s ... ]` waiter, do not
   start a second item, do not summarise progress mid-flight.

   ```
   Workflow({
     scriptPath: "doc/claude/signal_browser_2pane_batch/item_pipeline.js",
     args: { item: "<13|14|15|16|17b|18|19>",
             title: "<the ledger line title>",
             notes: "<the FULL item section for this item, verbatim from PLAN.md>",
             carried: "<the FULL 'Carried in from item 12' section of LEDGER.md, verbatim>",
             baseline: "<the FULL 'Recorded baseline' section of LEDGER.md, verbatim>",
             pixel: <true|false> }
   })
   ```
6. When it returns, read the result object only. Then go back to step 1.
   * `verdict: "INFRA_FAILURE"` means an agent died and **nothing was written**.
     Re-launch the same item once. If it happens twice, mark it `[F]` yourself
     with that reason and move on.
   * Any other verdict has already been written to the ledger and a receipt by
     the pipeline. Do not re-verify it and do not edit what it wrote.

FINAL REPORT (one message, at the end, and the only long thing you write):
* The ledger table as it now stands, mark by mark.
* Every commit the batch produced, in order, with its item.
* **The two baselines as last measured**, against the recorded 1618 / 11-of-11.
* The full eyeball queue — every `[E]` item and what to look at.
* Every `[D]` and `[F]` with its one-line reason, separating *blocked by a
  dependency* from *deferred on its own merits*.
* Anything the receipts flagged as still owed, especially the `.ph` status-line
  question item 12 left open.
* A plain statement that nothing was pushed.

Do not push. Do not open a review gate — this run is unattended and a gate would
block until morning for nothing.

------ end prompt ------

---

## What this batch is, in one paragraph

Two-pane items 0-12, 17's selected-instance arm and 20 are done. Seven units
remain: **13** (reveal/tree-apply under collapsed-by-default), **14**
(persistence for sash + the two R11 boxes), **15** (R7 — All-DBs headers and a
design root per DB), **16** (R9 — Ctrl-L → Ctrl-B, including deleting a row from
the C key table), **17b** (R10 — `Ctrl-Alt-V` through the C action registry; the
half `882694cc` did not take, because it needed 16), **18** (R12 — auto-tick,
reveal, and say so) and **19** (docs, oracles, the four-file lockstep, close
0217).

## Why the machinery exists

Driver mode is not a phrasing. Without a ledger on disk, a pipeline script and
receipts, "orchestrate this" degenerates into the main session implementing
everything within a few turns — there is nowhere for state to live. `LEDGER.md`
and `item_pipeline.js` were written for exactly that reason; the tutorial is
`doc/claude/suggestions/orchestration_driver_vs_implementer.md`.

## Drift signals — if the driver session starts doing any of these, it has lapsed

`Read` on a source file · `Write`/`Edit` outside the batch directory · an
`until [ -s … ]` waiter · the main session composing a commit message · two items
in flight · a progress summary between items.

## What the pipeline enforces that a plain "delegate this" would not

Every one of these is a trap that has already cost a session in this batch:

* **Measure the check-id band** — the PLAN's bands are already spent (it gave
  item 12 `BW40`-`BW49`; item 10 had taken through `BW53`).
* **Re-measure every number the PLAN states** — item 12's node counts were wrong
  (44/128; measured 45/129) while its signal totals were right.
* **"Reds existing: none" is not evidence** — item 12 red `BW25`, and item 9 had
  predicted it in a source comment the PLAN never carried forward.
* **Read the RED run for checks that passed before the code existed** — item 12
  shipped two into its first draft, both of the form "nothing changed", which is
  exactly what an unwired widget produces.
* **A check must not read back its own helper's restore** — one of item 12's
  survived a sabotage for that reason.
* **A control can eat the fixture** — `browser_refresh $tok 1` runs
  `browser_reload`, which overwrites the seeded inventory with `{}`.
* **Never name an accessor in a comment** — `BD06`-style oracles count a bare
  name file-wide; item 12 red one by writing a proc name in prose.
* **The sabotage driver takes a lock, traps, asserts a pre-state count, and
  counts `NORESULT`/`TIMEOUT` as reds** — an anchored `^(PASS|FAIL|RESULT)` filter
  turns a crashed suite into a clean zero.
* **A check-count shortfall is the only witness to vacuity** — diff the count,
  not just the fail count.
* **Items 16 and 17b are allowed to touch C.** Every other item is Tcl-only; a
  scout that defers 16 for "needs C" has misread the batch.
