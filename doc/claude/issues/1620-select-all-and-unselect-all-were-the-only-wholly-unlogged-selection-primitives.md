# 1620 — `select_all` and `unselect_all` were the only wholly unlogged selection primitives

**STAMP:** `v1 claim=fixed tree=8ead6bb8 stamped=2026-09-29 fix=taken open=4`

Status: **FIXED**, 2026-09-29, with a self-log at `select_all()`'s core and a verb-boundary log for
`unselect_all`. Measured on this tree at `8ead6bb8` · Branch: `fluid-editing`
Related: issue **1619** (the replay door, which made this matter); `doc/claude/specs/wish_list.txt`
old-list item **3**; batch `doc/claude/replay_door_batch/` decisions **D2**, **D5**, **D9**; receipt
`receipts/B-select.md`; `doc/claude/specs/action_logging.md` **§2b**; the fences are
`tests/headless/test_select_log_1620.tcl` and the `S3` band of
`tests/headless/test_selflog_grep_guard.tcl`.

## The defect

Issue 1619 made a recorded log playable, which turned this gap from a curiosity into a real limit:
**selection is the commonest macro prefix** — "select everything, then act" — and it was the one
thing a recorded log could not express. `select_all()` and `unselect_all()` were the only wholly
unlogged selection primitives. The Ctrl-A arm of the legacy `switch (key)` in `src/callback.c`
called `select_all();` raw, under a `/* select all ... */` comment, with no log line, and a scripted
`xschem select_all` produced nothing either.

Both now record on **both paths**: a scripted `xschem select_all` and a real Ctrl-A over the canvas
each produce exactly one `xschem select_all` line, and a record→replay round trip comes back
byte-identical.

## ⚠ THE TWO PRIMITIVES ARE NOT SYMMETRIC, AND THE PLAN SAID THEY WERE

The batch PLAN's scope sentence — *"make both primitives self-log … guarded by `actionlog_suppress`
exactly like every other self-logging core"* — is **right about one and wrong about the other**.

* **`select_all()` self-logs at its core** (`src/select.c`). It has exactly **two** call sites, and
  both are a user asking: the Ctrl-A legacy-switch arm (`src/callback.c`) and the scheduler branch
  (`src/scheduler.c`), which is what **Edit ▸ Select all** invokes. One site therefore covers key,
  menu and script — the `select_grow_connected_step()` precedent.
* **`unselect_all()` must NOT.** It is shared machinery: ~87 C call sites including
  `save_schematic()`, the netlister, paste, the font change, **both** undo backends and
  `abort_operation()`. None of those is a user asking to deselect. Its log lives in the **scheduler
  branch**, which is the only deliberate "deselect everything" spelling a user can reach.

**The cost of the naive symmetric version was measured rather than argued.** Built as sabotage `S3`:
a child that drew two wires and deselected once produced **94 phantom `xschem unselect_all` lines**.

That measurement now sits in `doc/claude/specs/action_logging.md` §2b behind the reusable rule it
implies, which is worth more than this issue:

> **A core may self-log only if every one of its callers is a user asking for that action.**
> Otherwise the log belongs at the verb boundary and the core stays silent.

`select_all` passes that test. `unselect_all` fails it.

Driver-verified independently: `select_all(` has exactly two call sites (`callback.c`,
`scheduler.c`), while `unselect_all` appears across **19 files** including every netlister,
`save.c`, `font.c`, `in_memory_undo.c` and `paste.c`. The asymmetry is not marginal.

## Issue 1617 is provably untouched

Ctrl-A is an overloaded chord whose other half became load-bearing four commits earlier: issue
**1617** made Ctrl-A over a waveform graph select all traces. The `CA*` band of
`tests/headless/test_wave_viewer.tcl` is **byte-identical** across this change — 30 rows, 0 FAIL,
`diff` clean — and the suite is `ALL PASS (437 checks)` before and after, **driver-re-verified on
the display arm**.

⚠ **The core self-log made an edit to the Ctrl-A dispatch unnecessary**, so the only change to
`src/callback.c` is a **comment** — one that now explicitly corrects the misleading `/* select all */`
above it, naming where the graph half goes. The crew confirmed by grep that the canvas chord is
**not** in the binding table (both `DEV_KEY,'a'` rows are `ACTX_OVER_GRAPH`) rather than reading it
off the shipped comment, which was precisely 1617's own scouting error.

## Red first

* Headless **`RESULT: 12 FAILED (18 passed)`**, display **`RESULT: 13 FAILED (20 passed)`**, and
  **no row threw**.
* ⚠ **The critical pairing: `K1` (the EFFECT row) PASSED in the red run while `K2` failed.** Ctrl-A
  really moved the selection 0 → 2 and really logged nothing, so *"not logged"* could not be
  confused with *"nothing happened"*. That is the recon's trap 1 — a silently-failed fixture load
  once made every probe read "not logged" when nothing was selected — discharged by construction
  rather than by care.
* Green: **31 headless / 34 display**; `test_selflog_grep_guard` **390 / 394**. Driver-verified at
  `8ead6bb8`: 31, 34 and 390 respectively, and `banner_complete` = 1 with the tree's own reader.

## Sabotage: seven applied, none survived

`S1` (suppress guard bypassed) → `Z1b` plus **`R2` `{2 0}`**, i.e. the seam replay re-logs and the
round trip is no longer idempotent. `S2` (log at the branch instead of the core) → `G1`, `G3`, **and
`K2` on the display arm only, with every `W*` row green** — so **a scripted-only fence would have
passed it**. `S3` → 10 rows. `S4`/`S5` (no-op gates) → `W3`/`W4` alone. `S6` (`dr` argument dropped)
→ `W5`×2. `S7` (key arm double-logs) → `G3`'s `callback.c` row and `K2` `{2}`; the crew added that
`callback.c` row **because** it could see `S7` would otherwise be display-only.

## ⚠ A regression the crew caused, found, attributed and repaired

`test_select_at` went `ALL PASS` → `3 FAILED`. The crew **bisected the binary** (HEAD `select.c` +
its `scheduler.c` → still 3 FAILED; both at HEAD → `ALL PASS`), establishing the cause as its own
`unselect_all` log.

The mechanism generalises and is the most useful thing in this issue: **a `select_at` line is not
written when the verb returns.** It sits in a single-slot absorb buffer and reaches the file only
when the *next* `log_action` flushes it. Rows `SA5`/`SA7b` read the log immediately after a click, so
they were reading the **previous** row's held line — flushed by the very stash under test. `SA8b` in
the same file already did it correctly; that pattern was lifted into a `log_flush` helper. Verified
`ALL PASS` on **both** trees, pristine and changed, because a test fix that only works on the fixed
tree is not a fix.

## Registration

Two suites, as the PLAN budgeted: **`test_select_log_1620`** in `hcases` **and** `dcases` (new), and
**`test_selflog_grep_guard`** in `hcases` (fence rows were added to it, so the bounded rule obliges
registration; it needed a pass counter and the `OVERALL: ok` sentinel first). T1 goes **109 → 112
cases, 108 → 111 blocks, `skips=` unchanged at 8**. `wc -l` moves by more than three, because three
new `RESULT:` lines are published — do not check it arithmetically.

## C89

`-std=c89 -pedantic -Wall -Wdeclaration-after-statement` over the three touched C files: 37
diagnostics, **zero on a touched line**, verified by filtering to the diff's own line ranges.

## Still open (open=4)

1. **There is no Edit ▸ Unselect all entry and no default chord**, so the newly logged verb has no
   interactive door — only the CIW, a script, or a user's own rc binding. Not a regression (the verb
   never had one), but it means half the pair is reachable from the menu and half is not.
2. ⚠ **The ~10 internal Tcl callers of `xschem unselect_all`** — the descend dialog, the property
   form, the tab machinery — now each add a line when they deselect a live selection. That is
   faithful and replayable, and it makes the CIW **noisier during hierarchy navigation**. It is the
   one user-visible consequence of this change and it is on the user's queue as **`rule/1620`**,
   because the tradeoff (replay fidelity against CIW noise) is theirs, not the implementation's.
3. **`test_selflog_grep_guard` in `hcases` gates its STATIC scans only.** T1 passes no `--logdir`, so
   its `S5` runtime canary takes a *"skipped: no --logdir"* arm written as a **passing check** rather
   than a `skip:` line. Pre-existing, named in the registration comment, deliberately not refactored
   here. Clean follow-on.
4. **The `pin_sel_active` term of the no-op gate is unverified** — removing it reddens nothing.

## Pre-existing reds, measured so nobody re-pays for them

* **`test_select_at` fails 5 rows under the ARMED spelling and passes unarmed**, at **pristine HEAD**
  as well as here — driver-verified with byte-identical failing row lists on both trees
  (`action log open`, then `SA5`, `SA6b`, `SA7b`, `SA8b`). The first row is the cause and the other
  four are downstream: the suite cannot open its action log under the throwaway HOME
  `run_suites.sh` arms, and passes only when invoked directly against the user's real HOME. It is
  unregistered, so it gates nothing. ⚠ **This is the class CLAUDE.md warns about** — a suite whose
  green depends on the real HOME — and it is filed separately as issue **1622**.
* `test_selflog_output` fails six flip/rotate rows, byte-identical list at HEAD. Unregistered.
* `test_context_menu_log` times out at 200 s with `FATAL: signal 15`. Unregistered.
