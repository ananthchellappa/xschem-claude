# 1619 — the action log had no replay door, so macros were at zero while the engine was done

**STAMP:** `v1 claim=fixed tree=951e628c stamped=2026-09-29 fix=taken open=5`

Status: **FIXED**, 2026-09-29, with **no C change** — one `src/actions.csv` row, a hand-written
Tools-menu line, and two new Tcl procs over the **existing** `replay_action_log`.
Measured on this tree at `951e628c` · Branch: `fluid-editing`
Related: `doc/claude/specs/wish_list.txt` **old-list item 3** (*"Logging of all user interactions to
enable macros and script creation from log files. WIP - but 25% DONE"*); batch
`doc/claude/replay_door_batch/` decisions **D2**–**D6**, **D8**; recon receipt
`receipts/R-recon-wishlist.md`; implementation receipt `receipts/A-door.md`; the fence is
`tests/headless/test_replay_door_1619.tcl`; the ruling is `rule/1619`.

## The defect is a MISSING DOOR, not a missing engine

The engine was finished and safe. Three chokepoints (`dispatch_input_action`,
`context_menu_action`, `perform_action`/`core_log_action`) plus ~254 opt-in sites feed the log, and
`replay_action_log` (`src/xschem.tcl`) wraps `source` in the `xschem log_action -suppress push/pop`
depth counter so nested composites stay suppressed. A log recorded headless and replayed in a fresh
process came back **byte-identical** — a log-idempotent round trip — and **29 suites** already drove
record→replay per verb.

And **none of it was reachable.** `replay_action_log` had no `actions.csv` row, no menu entry, no
keybinding and no file dialog. The only way to invoke it was to type the proc name into the CIW. The
single user-facing row this whole feature owned was `tools.raise_ciw`.

So the item's own annotation — *"25% DONE"* — was wrong in **both directions at once**, which is why
batch decision **D8** replaces it with a structure: the machinery was far past 25%, and macros, the
stated purpose, were at **0%**. A percentage averages those into a number that is wrong either way.

## ⚠ THE PLAN AND THE RECON WERE BOTH WRONG THAT THIS IS "ONE CSV ROW"

`actions.csv` generates **only the File menu**. A `tools` row reaches the command palette and the
cheat-sheet and **no menu at all**. That is why `tools.raise_ciw` — the row *both* the PLAN and the
recon receipt named as the model to copy — **has no Tools-menu entry**; its door is Alt+F5.

**Implementing the plan literally would have shipped a door with no menu entry**, discoverable only
by opening the palette and already knowing what to search for. The correct model is
`tools.net_hilight_style_editor`, which pairs its row with a hand-written menu line. Found by the
implementing crew, not by the driver; sabotage **S5** now fences the menu line's presence.

This is the same lesson as issue 1617's, arriving from a third direction: there, a shipped comment
named the meaning its own line diverted away from; here, two planning documents agreed with each
other and both were wrong about a mechanism neither had measured.

## What shipped

* **`src/actions.csv`** — one row `tools.replay_action_log`, 11 columns copied from `file.open`,
  `nolog=1`, `accel` empty, placed after `tools.raise_ciw`.
* **`src/xschem.tcl`** — `replay_action_log_run {path}`, the **testable** half: validates, calls the
  existing `replay_action_log` inside a `catch`, reports through `ciw_echo`, returns 1/0 and **never
  raises**. `replay_action_log_dialog {}` is the `tk_getOpenFile` chooser with a sticky
  `INITIALLOGDIR` (added to `tctx::global_list`). Plus the hand-written Tools-menu line.
* ⚠ **`replay_action_log` itself is byte-for-byte unchanged**, and neither new proc contains a
  `source` — the shipped seam stays the only replay path.
* **`doc/claude/specs/action_logging.md`** — new **§3b**. The spec had no section on playing a log
  back at all.

## Red first

* Before any product change: **`RESULT: 32 FAILED (8 passed)`**. Every probe of a missing proc
  reported a `RAISED(invalid command name "replay_action_log_run")` sentinel, so the suite **failed
  32 times and completed** rather than throwing and aborting — the issue-1616 failure mode,
  deliberately avoided.
* After: **`RESULT: ALL PASS (63 checks)`** headless, 65 on the display arm.
* Bands `C*`/`X*` did not exist in the first green version. They were added **because a sabotage
  survived**, and the no-door tree was then re-created to observe them red (**35 failed**).

Driver-verified independently at `951e628c`: `ALL PASS (63 checks)`, exit 0, and against the tree's
own `tests/banner_rule.tcl` — `banner_complete` = **1**, `banner_died` = **0**.

## Sabotage: 12 applied, none survived, 4 caught by exactly one row each

Most valuable: **S3** — the door hand-rolling `push; source; pop` and losing the `pop` on the error
path, which is the single most likely wrong implementation — is caught **only** by row `L2`, which
measures in a child with a real `--logdir` that the session **still logs after a failed replay**.
One apparent sabotage (**S12**, dropping the `return`) proved to be a Tcl no-op and is recorded as
such rather than as a gap.

## Registration

`hcases` **and** `dcases` (87 and 18), taking T1 to **109 cases / 108 blocks**. ⚠ `skips=` stays at
**8** — driver-verified: the suite prints **zero** lowercase `skip:` lines and one uppercase
`SKIPPED:`, which `summarize_all` does not count. That is the **fourteenth** consecutive 8, and it
remains a coincidence of what has been registered rather than a property: this suite is registered
in BOTH lists, the shape CLAUDE.md warns normally costs a skip, and it costs none only because its
self-skip is uppercase.

## Still open (open=5)

1. **A replay is N undo units, not one** (row `R2`: two wires replayed, one undo leaves one wire).
   **Not changeable from Tcl** — each verb pushes its own slot and `xschem push_undo` adds rather
   than merges. `add_pin_stubs()` is the precedent for N operations under a single `push_undo`, and
   it is a **C** function, which is exactly why an atomic replay needs a C-side undo barrier. Out of
   this issue's scope and worth its own number.
2. **A malformed log leaves the schematic HALF CHANGED.** `source` runs commands one at a time, so a
   syntax error on line 3 has already applied lines 1–2 (`R5b`: +2 of 4; `R6b`: +1 of 3 for a
   runtime error). Reported, never thrown: the CIW says so explicitly and row `C3` asserts that
   sentence. `R4c` is the control proving the raw seam **does** throw, so the `catch` is
   load-bearing rather than decorative.
3. **A log recorded against a different schematic aborts at the first absent referent**, leaving the
   same partial state (`R7b`: +1 of 2). A dialog-recorded log opens with `xschem load {…}` and so
   re-establishes its own schematic (**D6**).
4. **With the CIW pane closed, `ciw_echo` no-ops**, so an interactive user who closed the CIW sees
   only the effect of a failed replay, not the message. Deliberately **no `tk_messageBox`** (it
   would stall this suite's own `dcases` arm on a modal `vwait`) and **no `puts` fallback** (product
   text ending in the word `FAIL` in a suite's stdout scores as a counted failure). Unverified by
   any row; named here rather than papered over.
5. **`rule/1619` is unanswered**: the menu wording, and whether replay should run into the current
   session or a fresh one. The shipped default is the current session (**D3**), matching the seam
   that already existed, so nothing is gated on the answer. A re-wording is three edits — the csv
   row, the menu line, and `set LABEL` in the suite.

## On trust, and why no new issue was filed for it

A log file is executable Tcl, so a replay door is a second executable-file entry point. That is the
**same** trust question already filed as `rule/0823` (a `.sch` is executable). The implementing crew
neither extended 0823 nor filed a duplicate, which is right: one ruling, one place.

## Two pre-existing reds, verified not ours

`test_palette` and `test_action_log_dispatch` are `NORESULT` on both arms
(`invalid command name "bind"` / `"focus"`), confirmed against the pristine tree via `git show
HEAD:`. Neither is registered, so neither can redden a gate. `test_keybindings_help` — the other
`actions.csv` consumer — **passes** on the display arm with the new row, and `test_home_isolation`
(116), `test_home_isolation_sh` (90) and `test_scratch_home_note` (22) are all green, so row `G2`
does not trip on the new launcher-free code.

## A generalisable finding worth more than this issue

**`ciw_echo` and `tk_getOpenFile` are both shadowable.** Bands `C*`/`X*` replace them, assert
against the captured calls, restore the originals and then assert the restore. Three of the twelve
sabotages are caught *only* by those bands. The consequence is general: nearly every *"this needs a
human to press OK, so it cannot be tested"* comment in this tree is testable this way — for
everything except the blocking call itself.
