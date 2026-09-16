# Issue 1473 — the Stop warning tells the truth about THIS run (debt M18's other half)

**Issue** `doc/claude/issues/1473-the-stop-warning-still-says-a-run-is-discarded-after-stage-6f-made-that-untrue.md`,
the driver's own filing and specification. Files touched, and nothing else: `src/ase.tcl`
(**+124 / −13**), `tests/headless/test_ase_core.tcl` (**+154**),
`tests/headless/test_ase_simreg_0931.tcl` (**+29 / −2**),
`tests/headless/test_ase_trnoise_1466.tcl` (**+21**),
`doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` (**+43 / −1**) and this receipt.
**369 insertions, 15 deletions, five files.**

md5 at hand-over: `src/ase.tcl` `145eeac1…` (was `001af1ca…`), **`src/ase_window.tcl`
`55b021fd…` UNCHANGED**, `test_ase_core.tcl` `331ab486…` (was `3d39dd79…`),
`test_ase_simreg_0931.tcl` `517c6b17…` (was `95391796…`), `test_ase_trnoise_1466.tcl`
`809c4c8a…` (was `8fa2e42c…`), `R9_COPY_REVIEW.md` `f17c73ab…`.

**No commit, no `git add`, no stash/restore/checkout/clean/push. `tests/run_regression.tcl` NOT
run** (issue 0990 — the driver's, solo) **and not edited**: all three suites it already runs carry
the new rows inside them. **No C**: `make -q -C src` rc 0, `src/xschem` md5 `96fc4899…` unchanged.
**No simulation on any bench under `sky130A/`**; nothing read, written or backed up under
`~/.xschem/`. **No issue minted** — 1473 was filed by the driver. **New user-facing copy**: two
strings, so `owed.sh add rule 1473` is filed and `R9_COPY_REVIEW.md` carries **R9-724** and
**R9-725**.

---

## ⚠ THE HEADLINES

### 1. The sentence is now about THIS run, and the split is by what the run actually is

`ase::run_stop_warning` takes this run's own plan — `ase::ckpt_rows`' answer — as a second
argument, defaulting to `{}`:

| this run | what it is told |
|---|---|
| **no checkpointed row** (default, and every caller that holds no state) | `Stopping this run discards it — ngspice in batch mode writes nothing on a stop.` — **byte for byte what it said before** |
| **a checkpointed row** | `Stopping this run loses at most its last 20 %, and what is kept is marked partial — ngspice keeps every point up to this run's last checkpoint.` |
| backend with **no `run_stop_cost` hook** | nothing at all, either way |
| backend with `before` and **no `before_ckpt`** | today's sentence un-checkpointed, **nothing at all** checkpointed |

Both callers are gated: the run door (`ase::run_deck`) and `ase::run_log_header`'s
`stop      :` field, from **one resolve** carried in the run record as `ckpt`, for the reason
issue 1370 gave `using` one — two resolves are two answers about two instants.

### 2. ⚠ THE NUMBER IS THE PLAN'S, AND THE WORST CASE IS THE SMALLEST N

`ase::ckpt_worst_n` reads the plans, never `ase::ckpt_n`: N checkpoints cut a run into N+1
intervals, so a Stop costs at worst `100/(N+1)` %. Measured through the shipped path and through
hand-spelled plans: **N=4 → `20`**, N=9 → `10`, N=2 → `33.3`, and a **two-row plan {4, 9} → `20`**,
because fewer checkpoints mean a bigger loss. `format %.3g`, so 20 reads `20` and not `20.0`.

⚠ **The hand-spelled plans are the point, not decoration.** `ase::ckpt_n` answers one number for
every row on the shipped registry, so asked only through the planner *"reads this run's plan"* and
*"asks `ase::ckpt_n`"* are the same answer — a hard-coded `20` (arm M02), a largest-N reading
(M03) and a planner re-ask (M04) would all have passed. Each of the three reds **CK28b** and
nothing else.

### 3. Nothing is promised for the residue, and that is permanent

`op`, `noise`, `disto`, `pss`, `sp`, `pz`, `sens`, `tf` declare no `salvage` (row CK6), so they
reach no plan and keep the old sentence for good — debt M18's residue, worded as a final answer
rather than a promise. ⚠ **CORRECTED BY THE DRIVER'S VERIFIER 2026-09-15 — this said "a bench of
seven residue rows", and CK28c's seven rows contain only SIX residue kinds**; the seventh is `ac`,
which issue 1473 does not name. **`pss` and `sp` are therefore pinned by no row in this suite.** Both
were confirmed independently to declare no `salvage`, so the shipped behaviour is right and only the
coverage claim was wrong — the two rows are owed, and issue **1474** carries them. **CK28c** is that
bench, with the same bench plus one
long transient as its non-vacuity control, because `ase::ckpt_rows` also answers `{}` when
`ase::analysis_emit_order` raises and the row would otherwise pass over a state nothing could walk.

### 4. ⚠ FOUND, NOT FIXED, FOR THE DRIVER: the moment-of-the-Stop sentence still contradicts the salvage report

`ase::run_stopped_msg` takes **no plan** — `ase::ui::do_stop` hands it only the simulator name —
so the adapter's `after` clause is still said unconditionally. Measured on the finished tree
(`ase::run_stopped_msg` → `ase: simulation stopped — nothing of this run was written`, probe P11)
against `ase::ckpt_report`'s own sentence for the same run (*"…was kept at 200000 points of an
estimated 500000"*, `test_ase_trnoise_1466` NP6). A user stopping a checkpointed run therefore
reads **"nothing of this run was written"** and, seconds later, **"kept at 200000 points"**, in one
channel. Fixing it needs `src/ase_window.tcl`, which this task does not name, and a third R9
string (`after_ckpt`). **Not minted, named here**; the stale prediction in the adapter's own
comment is corrected in place rather than deleted.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15, `HOME` → `…/s1473/home`, `XSCHEM_DEVDISPLAY_DIR` the real state dir, `GUI_GATE=0`,
every command under `timeout`.

| claim | evidence |
|---|---|
| both callers consulted no plan at `d761b630`, and the sentence was therefore said to every run | **TRANSCRIBED** from the issue file's own measurement (re-confirmed only as the pre-change bytes reddening rows, arm M00) |
| the un-checkpointed sentence, the checkpointed sentence, the four backend cases and the three percentages | **MEASURED HERE** (`…/s1473/probe1.tcl` P1–P11, then rows CK28–CK29) |
| the log header's field and the CIW sentence are the same string for the same plan, and the field does not move | **MEASURED HERE** (probe P8/P9 side by side; rows CK29 and L12) |
| a noisy transient under the floor by its card is checkpointed and now told so | **MEASURED HERE** (row NP7), on the plan debt M22 already built |
| `ase::run_stopped_msg` still says "nothing of this run was written" after a checkpointed run | **MEASURED HERE** (probe P11 on the finished tree) |
| that a stopped checkpointed run really keeps its last checkpoint through a `kill -9` | **TRANSCRIBED** (`evidence/salvage.md` §3, §4.3, §4.4; issue 1433's own end-to-end SIGTERM row) — no run was killed for this task |
| the residue kinds' reasons (`op` one point, `noise`/`disto` an incomplete plot SET, `sens` not honouring `bg_halt`) | **TRANSCRIBED** (`ase::analysis_salvage`'s own block, D41.4, `evidence/builds.md`) |

---

## What shipped

### `src/ase.tcl` — 31 non-comment lines added, 93 comment lines

| proc | change |
|---|---|
| `ase::ckpt_worst_n` | **new** — the smallest usable `n` over the plan rows, `{}` for none. A row with no `n`, a non-integer `n` or `n < 1` is not a checkpointed row |
| `ase::run_stop_warning` | gains `{ckpt {}}`. Empty → today's sentence, byte for byte. Non-empty → the frame with `100/(N+1)` %, the word **partial**, and the adapter's **`before_ckpt`** clause; **no `before_ckpt` → nothing at all**, never the discarded sentence |
| `ase::run_deck` | one resolve of `ase::ckpt_rows` beside the walk `render_deck` already made, caught (empty is the conservative answer); passed to the CIW note and carried in the run record as `ckpt` |
| `ase::run_log_header` | renders the field from `[ase::state_get $meta ckpt {}]`; a record without the key writes the line it always wrote |
| `ase::backend::ngspice::run_stop_cost` | third key `before_ckpt`. Its comment predicted *"`before` becomes conditional … same two keys"* — **wrong in both halves**, corrected in place with what happened and why |

**What is unchanged, and how it is known:** `ase::run_stopped_msg` (headline 4), `ase::ckpt_plan`,
`ase::ckpt_rows`, `ase::ckpt_report`, `render_deck` and every deck golden — no line of any of them
is in the diff. Rows **SW1–SW7** and **L10/L11** are green unmoved, and they are the byte-identity
contract: SW1 passes no plan, which *is* the un-checkpointed run.

### The three suites — floors raised with each file's own paragraph

| suite | rows | floor |
|---|---|---|
| `test_ase_core` | **CK28** (the split, and the old sentence byte for byte), **CK28b** (the plan's own N; the smallest wins), **CK28c** (the residue, with its control), **CK28d** (the red row: `discards` never reaches a checkpointed run, `marked partial` always does, with both controls), **CK28e** (`before` without `before_ckpt` → silence; no hook → silence), **CK29** (both callers, one resolve, asserted against `ase::run_deck`'s body) | **638 → 644** |
| `test_ase_simreg_0931` | **L12** — the `stop      :` field for a checkpointed record and for one without, same index, same line count, and the record really carries it (`\yckpt\s+\$\w+` in the comment-stripped source, exactly 1) | **117 → 118** |
| `test_ase_trnoise_1466` | **NP7** — the noisy transient is told what a Stop KEEPS; the identical card with its noise table removed is under the floor and told a Stop discards it | **78 → 79** |

All eight new rows are **pure Tcl and start no simulator**, so they are not run twice per binary;
what is per-binary in these files (`test_ase_trnoise_1466` EC/EE) ran unchanged — **20 rows across
`/usr/bin/ngspice` 45.2 and the fork `build-ver_50`, 0 SKIPPED**, on both arms.

---

## Suites — before → after → restored, every arm, with rc

**Before** = the untouched tree at `03c68f3f` (`…/s1473/base/`). **After** = the finished tree
(`…/s1473/after/`). **Final** = the restored tree after the campaign (`…/s1473/final/`). Headless
`./src/xschem --nogui --pipe -q --nolog --script`; display
`tests/headless/devdisplay.sh exec timeout --kill-after=20 200 ./src/xschem --pipe -q --nolog
--script` on `:99` (Xvfb + **openbox**, 1920x1080x24). Every run rc **0**.

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_core`** | 638 | **ALL PASS (644)** | 638 | **ALL PASS (644)** |
| **`test_ase_simreg_0931`** | 117 | **ALL PASS (118)** | 117 | **ALL PASS (118)** |
| **`test_ase_trnoise_1466`** | 78 | **ALL PASS (79)** | 78 | **ALL PASS (79)** |
| `test_ase_persist` | 49 | 49 | 153 | 153 |
| `test_ase_preflight` | 235 | 235 | 235 | 235 |
| `test_ase_events_1465` | 87 | 87 | 87 | 87 |
| `test_ase_variant_1470` | 76 | 76 | 76 | 76 |
| `test_ase_optier_0963` (extra — it reads the run record) | 109 | **109** | not run | not run |

**Not a count diff — a name diff.** The md5 of each log's `ok:`/`FAIL:` **row names**, base vs
after, on both arms:

* **four neighbours identical on both arms** — persist `08b6707e…` / `f3f4aafd…`, preflight
  `bf6b3be6…`, events `500ca756…`, variant `9f37b7f8…`, before = after. No row moved, not merely
  no count.
* **the three that gained rows lost none**: `comm` of base names against after names is **lost = 0,
  gained = 6 / 1 / 1** on both arms. Every base row is among the after rows.
* the one `SKIPPED` line in `test_ase_core`'s display arm is **NT14 headless-only sink safety**,
  identical in base and after, and pre-existing.

**Final (restored) tree, both arms:** `test_ase_core` **ALL PASS (644)**, `test_ase_simreg_0931`
**ALL PASS (118)**, `test_ase_trnoise_1466` **ALL PASS (79)**, rc 0 — the campaign's positive last
row.

### Background runs

**None.** Every suite, probe and campaign call ran in the foreground under `timeout`; the harness
stopped nothing, so no result here lacks a verdict.

---

## `.state` byte identity

Through **`tests/headless/state_roundtrip.tcl`** on the finished tree, and inside the suites
(`test_ase_trnoise_1466` NC1, `test_ase_persist`):

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

**No new state key.** `ckpt` is a field of the in-memory RUN RECORD (`meta`), which is never
serialised — `ase::omit_if_empty` is untouched and ⚖ R8's "no new top-level keys" is not engaged.

---

## THE SABOTAGE CAMPAIGN — 10 arms, 10 killed by name, 0 restore mismatches

Every arm: exact-anchor mutation of the **fixed** `src/ase.tcl` bytes (anchor count asserted **= 1**,
and an arm whose md5 equals the fixed file's is refused), the three suites carrying the new rows run
headless under `timeout 300`, reds read **by row name**, restore by plain `cp` + md5 compare before
the next arm. **The gate is a positive assertion and was fed the empty case first**:

```
GATE CONTROLS empty=NORESULT partial=NORESULT crash=NORESULT pass=SURVIVED fail=KILLED
```

| # | what I broke | rows that reddened |
|---|---|---|
| **M00** | **the whole pre-change `src/ase.tcl`** — no fix at all | core/**CK0** (section CK died on `wrong # args: should be "ase::run_stop_warning ?sim?"`, taking CK28–CK29 with it: `1 FAILED (638 passed)`), simreg/**L12**, trnoise/**NP7** |
| M01 | the warning ignores the plan it is handed (one line) | CK28 CK28b CK28d CK28e CK29 L12 NP7 |
| M02 | the percentage is a constant `20` | **CK28b** |
| M03 | `ckpt_worst_n` takes the LARGEST N | **CK28b** |
| M04 | `ckpt_worst_n` re-asks `ase::ckpt_n` whatever the plan says | **CK28b** |
| M05 | the adapter loses `before_ckpt` | CK28 CK28b CK28d CK29 L12 NP7 |
| M06 | a missing `before_ckpt` **falls back** to the discarded sentence | **CK28e** |
| M07 | the run door passes no plan | **CK29** |
| M08 | the log header ignores the record's `ckpt` | CK29 L12 |
| M09 | an EMPTY plan is treated as checkpointed (the residue gets promised salvage) | core/**SW1** core/**SW4** CK28 CK28b **CK28c** CK28d CK28e CK29 L12 NP7 |
| **final** | **the restored tree**, md5 `145eeac1…` | **headless ALL PASS 644 / 118 / 79, rc 0; display ALL PASS 644 / 118 / 79, rc 0** |

**Every new row reddened under at least one arm**: CK28 (M01 M05 M09), CK28b (M01–M05 M09), CK28c
(M09), CK28d (M01 M05 M09), CK28e (M01 M06 M09), CK29 (M01 M05 M07 M08 M09), L12 (M00 M01 M05 M08
M09), NP7 (M00 M01 M05 M09).

⚠ **M09 is the arm worth reading twice.** It reds **SW1 and SW4** — the un-checkpointed sentence's
own rows — which is the byte-identity contract proving itself load-bearing rather than assumed: the
moment an ordinary run is treated as checkpointed, two rows written before this issue say so.

Logs: `…/s1473/sab/results.txt`, `…/s1473/sab/logs/<arm>.<suite>.h.log`.

---

## Debts — queue before → after

`owed.sh count`: **185 rule, 70 look, 11 suite → 186 rule, 70 look, 11 suite.** The one addition is
**`rule 1473`**, stamped `repo:/home/analog/dev/xschem-claude` with its `ref:` resolving to the
issue file. **The ledger was backed up before the write** (`…/s1473/owed_backup_20260915_170449`),
per the brief's one-sided-refusal warning. No `look` debt: this task draws no pixel — what the
window shows after a Stop is `src/ase_window.tcl`'s and is untouched. No `suite` debt: no new row
maps a window.

### ⚖ DEBT M18 — CLOSED

By **CK28** (a checkpointed run is told what a Stop costs at worst and that what is kept is
partial, where an un-checkpointed one keeps the old sentence byte for byte), **CK28d** (the word
`discards` never reaches a checkpointed run), **L12** (the same in the run log's own field) and
**NP7** (the noisy transient that debt M22 made checkpointable is told so). All four red against the
pre-change behaviour — M00 or M01.

⚠ **AND THE LEDGER'S STAGE 6 PASSAGE WAS WRONG.** *"⚠ What 6f does and does not discharge. **It
closes debt M18** …"* is false and was false on the day it was written: **6f shipped the loop and
left the sentence**, so for three weeks the tree warned the user that stopping a checkpointed run
discarded it and then told them afterwards that it had not. The debts table and the *Still open and
named* line were the correct halves. The ledger is the driver's file and is not edited here; the
correction belongs in the same commit.

---

## Corrections

| | |
|---|---|
| **C1** | ⚠ **`ase::backend::ngspice::run_stop_cost`'s own comment predicted the wrong shape** — *"`before` becomes conditional on whether this run has checkpoints and `after` gains the salvaged-file case. Same proc, same two keys."* Neither half held: `before` is a CONSTANT and a THIRD key answers the checkpointed case (a caller holding a plan must be able to ask for the one it needs), and `after` has **not** gained its case (headline 4). Corrected in place, not deleted |
| **C2** | **`PLAN.md` §6f's draft of this sentence was *"Stopping loses at most the last 20 % of this run; checkpointing costs about 18 % more run time"*.** The second clause is **not shipped**: the 18 % is one bench's I/O measured at one sitting, `evidence/salvage.md` §3.7's own throughput moved ±30 % between sittings, and ASE-L records no per-bench run history — a number that precise about *this* run would be a fabrication. `evidence/salvage.md` §5.2 asks for "both numbers"; only the one this run can actually compute is said. **A ⚖ R9 choice, and it is in the R9 entry** |
| **C3** | **The residue list in `PLAN.md` Stage 2e is stated as prose and is asserted nowhere.** Row **CK28c** now holds it against the shipped registry, and row CK6 holds its cause; a type that later declares a measured `salvage` moves both, deliberately |
| **C4** | **My first cut gave `ase::ckpt_worst_n` the largest N.** Reversed before it shipped and pinned by arm M03: the *worst* case is the *fewest* checkpoints |

---

## What binds later stages

1. **The stop sentence's shape is now `(simulator, this run's plan)`.** A stage that adds a
   salvageable analysis type gets the checkpointed sentence for free, and gets it in both channels,
   by declaring `salvage` — nothing in the warning knows a type name.
2. **`after` is the unfinished symmetry** (headline 4). Whoever touches `ase::ui::do_stop` next
   should take `ase::run_stopped_msg {sim ckpt}` and an `after_ckpt` clause with it; the plan is
   already in the session's state at that call site.
3. **A percentage of an estimate reads like a measurement.** `ase::ckpt_report` deliberately reports
   POINTS after the fact for that reason; the warning may quote a percentage only because it is a
   bound on the plan, not a reading of the run. Do not "unify" the two.
4. **The run record is the place for a per-run fact the log must render.** `ckpt` follows `using`'s
   precedent, not `rawlock`'s: resolved once, at the instant of the launch, because the log is
   written twice and the state can move between.

## Hygiene

* **Snapshots disarmed**: the pristine (pre-change) and fixed copies of `src/ase.tcl` and `sab.py`
  are under `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/s1473_1473/`, so nothing of this crew's can
  restore over a moving tree. Logs kept at `…/s1473/` (`base/`, `after/`, `final/`, `sab/`,
  `probe1.tcl`, `rt.tcl`, `owed_backup_*`).
* **No background process of this crew is running** — checked by process NAME
  (`ps -eo comm=,args=`, never a `-f` pattern this shell's own argv could match): no `xschem`, no
  `ngspice`, no `python3 sab.py`. Only `Xvfb` and `openbox` for `:99`, left as they were found.
* **Nothing under `~/.xschem/`**, no `--logdir` anywhere, no bare `xschem`, no `pkill`, no
  `git checkout`/`restore`/`stash`/`clean`/`push`/`commit`, and `/home/analog/dev/xschem-op-wcard`
  untouched. The only write outside the repo is the `owed.sh` rule entry, backed up first.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

`…/scratchpad` is
`/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
