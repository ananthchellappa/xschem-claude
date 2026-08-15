# Two-pane Signal Browser — overnight DRIVER prompt

Everything between the markers goes into a fresh Claude Code session. Launching
the batch **is** the authorization for one commit per green item (plus fixup
commits from the repair stage). **Nothing is ever pushed.**

---

## Before you launch

Almost nothing is left to set up — `xvfb` is installed and the display handling is
now automatic.

1. **The display is handled.** Every X-arm run goes through `xarm.sh`, which uses a
   private **Xvfb** until the deadline and the real **`:0` under the gate panel**
   after it. No `GUI_GATE=0`, no flooding your screen, and nothing to press
   overnight. **Measured before writing this: the Xvfb arm reproduces the `:0` arm
   exactly** — 11/11, all eleven per-suite counts identical, 2136 checks either way.
2. **The handback is set for Sat 2026-08-08 06:21 MST** (epoch `1786195286`, in
   `DEADLINE` beside `xarm.sh`). At that moment `xarm.sh` stops using Xvfb, raises
   the gate widget if it is not already up, and every later suite is under your
   Pause/Stop. Move the deadline by editing that one file.
3. **WSLg's Xwayland death cannot reach the batch while it is on Xvfb** — the
   single biggest overnight risk, removed. It applies again after the handback, and
   the pipeline still treats a dead `:0` as **DEFER, not FAIL**.
4. `cd src && make` must be green before you start. Never `make` while a suite runs.
5. `git status --porcelain -- src tests doc` — note the pre-existing dirty files.
   They must still be the only dirty tracked files (batch dir excepted) at the end.
6. Four commits from the current session are **unpushed** (`958ada03`, `a98ab6fe`,
   `e5347591`, `d5374918`). The batch adds more. Push is never automatic.

**Xvfb has no window manager.** Decoration, iconify, stacking, raise and
geometry-echo claims are untestable there. Nothing in items 13-19 needs one — it
is all inside a single toplevel — but if an item turns out to, the pipeline is
told to call that an eyeball rather than measure it and believe the answer.

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
1. `doc/claude/signal_browser_2pane_batch/xarm.sh mode` — it must say **XVFB
   (unattended)** with time left. If it says GATED, the unattended window has
   already closed; that is not a reason to stop, but say so in your first message
   because every run from then on needs the user at the panel.
2. `cd src && make` green. If not, STOP and report — never start on a broken build.
3. `git status --porcelain -- src tests doc` — record the pre-existing dirty set.

The display needs no other preparation. Do **not** export `GUI_GATE=0`, do not
call `run_suites.sh` or `gated_xschem.sh` yourself, and do not check the clock —
`xarm.sh` owns all of that and the pipeline tells every agent to use it.

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

THE HANDBACK (Sat 2026-08-08 06:21 MST, epoch 1786195286):
You do not need to do anything for it — `xarm.sh` switches displays on its own and
raises the gate widget. Two consequences to be aware of:
* Items that start after it run on the real `:0` and are governed by the panel.
  **Pause and Stop are the user's authority.** If a run seems to stall, check
  `~/.claude/gui_test_gate/control` — it may simply say `PAUSE`. Wait for it.
  Never set `GUI_GATE=0` to get around a pause, and never kill the panel.
* Note in the final report which items ran before the handback and which after.

FINAL REPORT (one message, at the end, and the only long thing you write):
* The ledger table as it now stands, mark by mark.
* Every commit the batch produced, in order, with its item.
* **The two baselines as last measured**, against the recorded 1618 / 11-of-11.
* Which items ran under Xvfb and which after the handback on `:0`.
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
