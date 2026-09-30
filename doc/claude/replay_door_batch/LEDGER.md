# LEDGER — replay_door_batch

One row per crew receipt collected by the driver. The driver verifies, collects, gates and commits;
crews do not commit, push or gate.

Opened 2026-09-29 at `e05a9769`. T1 baseline `107/106/0/8` (`tests/results.775219.log`).

| stage | crew | receipt | collected | commit | notes |
|---|---|---|---|---|---|
| R | 6× wish-list recon (parallel, read-only) | `receipts/R-recon-wishlist.md` | 2026-09-29 | `951e628c` | Changed the batch target. Six candidates measured; **four of six list annotations wrong**. Headline: item 3's engine is done and fenced, macro surface is zero. |
| A | replay door (issue 1619) | `receipts/A-door.md` | 2026-09-29 | `1041a87f` | **No C change.** Red `32 FAILED (8 passed)` -> `ALL PASS (63 checks)`. 12 sabotages, **none survived**. ⚠ **Refuted the PLAN and the recon both**: a `tools` row gets NO menu (only File is generated), so the literal plan would have shipped an undiscoverable door. Driver re-verified the suite, the banner (`banner_complete`=1, `banner_died`=0), the zero lowercase `skip:` lines and that `replay_action_log` is byte-unchanged. |
| B | selection gap (issue 1620) | `receipts/B-select.md` | 2026-09-29 | `80dc3bbb` | ⚠ **Refuted the PLAN's scope sentence**: the two primitives are NOT symmetric -- `select_all` self-logs at its core (2 callers, both a user asking), `unselect_all` must not (~87 call sites across 19 files). Cost of the naive version MEASURED at **94 phantom lines**, now a reusable rule in `action_logging.md` §2b. Red `12 FAILED (18 passed)`; **`K1` the EFFECT row PASSED while `K2` failed**, so the recon's sharpest trap was discharged by construction. 7 sabotages, none survived. Caused, bisected, attributed and repaired a `test_select_at` regression. Driver re-verified 31/34/390 + `test_wave_viewer` 437 (1617 intact). |

## Running totals

* Receipts collected: **3** of 3 planned.
* Commits from this batch: **6** -- `951e628c` (open), `1041a87f` (1619), `f8c53fdb` (baseline
  109/108), `8ead6bb8` (1621), `80dc3bbb` (1620), plus the closing baseline commit for 112/111.
* Issue numbers consumed: **1619**, **1620**, **1621** (undo atomicity, OPEN), **1622** (`test_select_at` HOME dependence, OPEN).
* Owed-ledger entries this batch will add: `rule/1619` (replay into current vs fresh session, plus
  the menu wording) and `rule/1620` (CIW noise during hierarchy navigation) — filed by the driver,
  both clear **only when the user says so**.

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

## CLOSED 2026-09-29

Both stages delivered and gated green. **T1 went 107/106 -> 112/111, `counted_failures=0
skips=8` at every step**, each figure taken in a fresh `git clone --local --no-hardlinks` built
from scratch at a 9-character path with zero live-peer lines:

| commit | gate verdict | figure |
|---|---|---|
| `1041a87f` (1619) | `tests/results.902414.log` | 109/108/0/8, `wc -l` 326, 622s |
| `80dc3bbb` (1620) | `tests/results.1010173.log` | 112/111/0/8, `wc -l` 335, 627s |

**What the user can now do that they could not this morning:** record a session and replay it
from Tools ▸ `Replay action log...`, with selection included, so the wish list's oldest
unfinished item -- macros -- works end to end.

### The pattern worth keeping

**Every one of the three stages refuted the driver.** Stage R overturned the driver's stated pick
(wire labels) before a line was written. Stage A found that the PLAN *and* the recon were both
wrong that a `tools` row yields a menu entry, so the literal plan would have shipped an
undiscoverable door. Stage B found the PLAN's scope sentence wrong on the substance -- the two
selection primitives are not symmetric -- and **priced the driver's version at 94 phantom log
lines** rather than arguing about it.

That is three for three, and the reason is the same each time: the driver was reasoning from
documents (a wish list, a recon receipt, its own plan) and the crews were reasoning from the
binary. **The read-only recon stage is now the default opening move of a batch, not an option** --
and the corollary is that a crew must be told to refute, because a crew told to implement will
implement the wrong thing correctly.

### Two things that cost real time and are worth not repeating

1. **A read-only crew gutted a tracked library schematic** with a `saveas` probe (decision **D9**).
   `git add -A` would have shipped it. The brief now says a probe that saves, saves to scratch, and
   a read-only stage ends by proving `git status` is clean.
2. **The driver suspected Stage B of overclaiming a green** and was wrong: a pristine clone
   reproduced the same 5 failures with a byte-identical row list. The suite gives opposite verdicts
   by launch method (issue **1622**). Cost ~15 minutes of clone-and-build to attribute, and the
   attribution was worth it -- but it would have been free if the receipt had named its invocation.

### Left open deliberately

* **`rule/1619`** -- replay wording, and current session versus a fresh one.
* **`rule/1620`** -- logging deselects makes the CIW noisier during hierarchy navigation.
* **Issue 1621** (undo atomicity, needs a C-side undo barrier) and **issue 1622**
  (`test_select_at`'s HOME dependence), both filed OPEN with their mechanisms recorded.
* **Increment 3** -- registering the remaining ~27 replay round-trip suites, out of scope per
  **D2**. Two of the 29 are now registered; the bounded rule brought them in, not a sweep.
