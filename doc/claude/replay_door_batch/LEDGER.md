# LEDGER — replay_door_batch

One row per crew receipt collected by the driver. The driver verifies, collects, gates and commits;
crews do not commit, push or gate.

Opened 2026-09-29 at `e05a9769`. T1 baseline `107/106/0/8` (`tests/results.775219.log`).

| stage | crew | receipt | collected | commit | notes |
|---|---|---|---|---|---|
| R | 6× wish-list recon (parallel, read-only) | `receipts/R-recon-wishlist.md` | 2026-09-29 | pending | Changed the batch target. Six candidates measured; **four of six list annotations wrong**. Headline: item 3's engine is done and fenced, macro surface is zero. |
| A | replay door (issue 1619) | `receipts/A-door.md` | 2026-09-29 | pending gate | **No C change.** Red `32 FAILED (8 passed)` -> `ALL PASS (63 checks)`. 12 sabotages, **none survived**. ⚠ **Refuted the PLAN and the recon both**: a `tools` row gets NO menu (only File is generated), so the literal plan would have shipped an undiscoverable door. Driver re-verified the suite, the banner (`banner_complete`=1, `banner_died`=0), the zero lowercase `skip:` lines and that `replay_action_log` is byte-unchanged. |
| B | selection gap (issue 1620) | `receipts/B-select.md` | — | — | not yet dispatched |

## Running totals

* Receipts collected: **2** of 3 planned.
* Commits from this batch: **0**.
* Issue numbers consumed: **1619**, **1620**.
* Owed-ledger entries this batch will add: `rule/1619` (replay into current vs fresh session, plus
  the menu wording) — filed by the driver, clears **only when the user says so**.

## What Stage R cost and returned

Six agents, 334 tool uses, ~775k subagent tokens, 20 minutes wall clock, zero agent errors. It
overturned the driver's own stated pick (new-list item 2) before a line of code was written, and it
found that item 2 is blocked behind **four** semantic rulings — the worst shape available while the
user is remote. That is the second batch in a row where a read-only recon stage refuted the driver;
the pattern is now established enough to be the default opening move rather than an option.

⚠ The full recon receipt also carries measured verdicts for **four candidates this batch does not
act on** (new-list 2, 11, 12, 17, 26 and 7). It is the backlog intelligence for the next batch and
exists so nobody re-runs this measurement. Notable: **new-list item 17 is already SHIPPED** (cursor
snaps to the trace, real trace x/y on the status bar) with its suite `test_wave_snap.tcl` passing
but unregistered; and **item 12 ships as-is**, needing only an optional menu cascade.
