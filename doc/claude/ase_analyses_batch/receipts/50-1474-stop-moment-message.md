# Issue 1474 — the two messages of one run stop contradicting each other

**Issue** `doc/claude/issues/1474-the-post-stop-message-still-says-nothing-was-written-seconds-before-the-checkpoint-report-says-what-was-kept.md`,
the driver's own filing and specification. Files touched, and nothing else: `src/ase.tcl`
(**+120 / −8**), `src/ase_window.tcl` (**+17 / −1**), `tests/headless/test_ase_core.tcl`
(**+233 / −1**), `tests/headless/test_ase_trnoise_1466.tcl` (**+38**),
`doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` (**+23 / −1**) and this receipt.
**431 insertions, 11 deletions, five files.**

md5 at hand-over: `src/ase.tcl` `78adcd17…` (was `145eeac1…`), `src/ase_window.tcl`
`b38be6df…` (was `55b021fd…` — **1473 left this file untouched; 1474 is the half that
needed it**), `test_ase_core.tcl` `4ee42bc3…` (was `331ab486…`),
`test_ase_trnoise_1466.tcl` `b59d36bf…` (was `809c4c8a…`), `R9_COPY_REVIEW.md`
`91aee8ab…` (was `f17c73ab…`).

**No commit, no `git add`, no stash/restore/checkout/clean/push** by me. HEAD was `df5df4fe`
at hand-over and is **`0b0b61c0`** now — the driver committed twice during the verification
round (the 1474 `NUMBERING.md` row, and the stale-`results.log` note); this work still sits
uncommitted on top of it. `tests/run_regression.tcl` **NOT run** (issue 0990 — the driver's,
solo, and already done for this tree) **and not edited**: both suites carrying new rows are already in its case list. **No C**:
`make -q -C src` rc 0, `src/xschem` md5 `96fc4899…` unchanged. **No simulation on any
bench under `sky130A/`**; nothing read, written or backed up under `~/.xschem/`; no
`--logdir`, no bare `xschem`, no `pkill`. **No issue minted** — 1474 was filed by the
driver. **New user-facing copy**: one string, so `owed.sh add rule 1474` is filed and
`R9_COPY_REVIEW.md` carries **R9-726**.

---

## ⚠ THE HEADLINES

### 1. The two sentences of one run now make the same claim, and a row asserts them against EACH OTHER

`ase::run_stopped_msg` takes this run's own plan as a second argument, defaulting to `{}`
— the same shape, and the same one value, `ase::run_stop_warning` took in 1473:

| this run | what it is told at the Stop |
|---|---|
| **no checkpointed row** (default, and every caller that holds no state) | `ase: simulation stopped — nothing of this run was written` — **byte for byte what it said before** |
| **a checkpointed row** | `ase: simulation stopped — every point up to this run's last checkpoint was written, and what is kept is marked partial` |
| backend with **no `run_stop_cost` hook** | nothing at all, either way |
| backend with `after` and **no `after_ckpt`** | today's sentence un-checkpointed, **nothing at all** checkpointed |

⚠ **ROW CK31 IS THE ONE THE ISSUE IS ABOUT, AND IT IS NOT A SECOND COPY OF CK30.** The
defect was never that either sentence was wrong on its own — each matched its own literal,
and a suite of per-message goldens **would have passed on the tree 1473 left**. So CK31
reduces each sentence to *what it claims* — `KEEPS`, `NOTHING`, `SILENT`, or
`CONTRADICTORY` — and requires the launch warning and the stop message to make the **same**
claim about the **same** plan, over seven plans. `CONTRADICTORY` is a verdict of its own
rather than a failure to match, so a sentence that promised salvage and denied it in one
breath reds with a name instead of reading as some other claim. ⚠ And the expectation pins
the ANSWER as well as the agreement: two messages that both said `NOTHING` would agree
perfectly and be the defect 1473 repaired, so a checkpointed plan must read `KEEPS` on both
sides.

### 2. The plan is PASSED, not re-resolved — and the seam that made that possible is new

`ase::run_deck` already resolved `ase::ckpt_rows` once and put it in the run record as
`ckpt` (1473). Nothing could read that record back, which is why `ase::ui::do_stop` — which
holds an execute id and nothing else — had composed its sentence from the simulator name
alone. **`ase::run_record {id}`** is the reader: the meta dict out of
`::execute(callback,$id)`, `{}` for anything else.

⚠ **IT CHECKS THE CALLBACK'S FIRST WORD, AND THAT ONE CHECK IS PINNED.**
`execute(callback,<id>)` is **xschem's** table, not ASE-L's — `src/xschem.tcl:5889`'s own
`simulate` writes one too — so a stranger's callback list is not a run record and is not read
as one. Row **CK32**; arm **N07** removes the check and reds it alone.

⚠ **AND THE SECOND GUARD IS GONE — VERIFICATION ASKED, AND THE ANSWER WAS "DELETE IT".** My
first cut also ran `dict size` over element 4. The driver's verifier removed that line and
**both suites stayed ALL PASS**, which by this batch's own standard makes it a line no row can
defend. I re-measured before acting, because "no row fails" is a reason to look rather than a
verdict — and all three measurements said delete (C7 below). The identity check is a
different line, is reachable, and is pinned.

⚠ **AND THE RECORD IS READ BEFORE THE KILL.** `execute` drops the callback entry when it
fires it (`src/xschem.tcl:315`), and what fires it is the EOF this kill causes. Nothing
between the two lines enters the event loop today, so the ordering is insurance rather than
a live race — but the failure it prevents is silent, because an empty record reads as *"this
run had no checkpoints"*, which is the un-checkpointed sentence said to a checkpointed run.
Row **CK33b** asserts the order the way row CK25 does; arm **N06** swaps the two lines and
reds it alone.

### 3. ⚠ NO PERCENTAGE HERE, AND THAT ASYMMETRY IS DELIBERATE

The launch warning quotes `100/(N+1)` % because that is a **bound on the plan**, computed
before anything has run. At the moment of the Stop the amount really kept is a measurable
fact, and `ase::ckpt_report` reports it **after** the run **in points** for exactly that
reason — receipt 49's own binding note 3: *a percentage of an estimate reads like a
measurement; do not "unify" the two.* So this sentence says **what kind of result the user
now has**, and the salvage note that follows says **how much of it there is**. A ⚖ R9
choice, and it is in the R9-726 entry.

### 4. `partial` comes from neither `rc` nor `ase::sim_status`, and the SIGNATURE is the proof

Both are 0 after a Stop (`evidence/salvage.md` §5.3), so either would say the run
succeeded. Two things establish partial-ness instead: this proc is reached **only** from the
arm of `ase::ui::do_stop` that has just killed a live process, and the authority for
complete-vs-aborted afterwards is the **deck's completion echo**, read by
`ase::run_completed` for `ase::ckpt_report`. Row **CK30c** pins it structurally rather than
by promise — `info args ase::run_stopped_msg` is `{sim ckpt}`, so the proc **cannot see** an
exit code or a simulator status; to consult one, somebody would have to add a parameter, and
that row is what notices. The body scans are the same claim from the other side, and
`rg_body` drops comments so the word in this proc's own header cannot satisfy them.

### 5. The coverage 1473 claimed and did not have is closed — and `pss` could not be closed the obvious way

The verifier of 1473 found **`pss` and `sp` pinned by no row**. `sp` is now the eighth row of
CK28c's bench. **`pss` cannot go there at all**, and that is a fact about the registry
rather than an omission:

```
rank-pss  {}          emitorder-with-pss  RAISED: analysis type 'pss' is not one this
                                          simulator backend can render
rows-res+pss      {}      <- the row would PASS, for the wrong reason
rows-res+pss+big   0      <- and the non-vacuity control collapses, saying nothing
```

Both halves measured. So row **CK28f** asks all **eight** residue kinds where the question
can actually be put to each — `ase::ckpt_plan`, one row at a time, with no emit-order walk in
the way — and carries the long transient's real plan as its non-vacuity control. An assertion
that eight things answer `{}` is otherwise satisfied by a planner that answers `{}` to
everything, by a renamed proc and by a typo in the type list.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15, `GUI_GATE=0`, every command under `timeout`, every waiting loop bounded.

| claim | evidence |
|---|---|
| `ase::run_stopped_msg` took one argument at `df5df4fe` and said the `after` clause to every run | **MEASURED HERE** (`probe1.tcl`: `args-stopped` → `sim`, `stopmsg-now` → the old sentence), then again as arm N00 reddening rows |
| the four backend cases, the un-checkpointed sentence's byte identity, and the new sentence | **MEASURED HERE** (`probe2.tcl` P1–P12, then rows CK30/CK30b) |
| the plan really travels record → sentence through the REAL `ase::ui::do_stop` | **MEASURED HERE** (`probe2.tcl` `stop-ckpt`/`stop-plain`/`stop-nokey`/`stop-foreign`, then row CK33) |
| `pss` has no emit rank and `sp` does; what each does to a walked bench | **MEASURED HERE** (`probe1.tcl`, five probes) |
| that a stopped checkpointed run really keeps its last checkpoint through a `kill -9` | **TRANSCRIBED** (`evidence/salvage.md` §3, §4.3, §4.4; issue 1433's SIGTERM row) — **no run was killed for this task**, and `kill_running_cmds` is stubbed in row CK33 |
| that `rc` and `$sim_status` are both 0 after a Stop | **TRANSCRIBED** (`evidence/salvage.md` §5.3). What is measured here is that this proc cannot reach either (CK30c) |
| the residue kinds' reasons (`op` one point, `noise`/`disto` an incomplete plot SET, `sens` not honouring `bg_halt`) | **TRANSCRIBED** (`ase::analysis_salvage`'s own block, D41.4). Their `{}` answers are **MEASURED** (CK28f) |

---

## What shipped

### `src/ase.tcl` — +120 / −8

| proc | change |
|---|---|
| `ase::run_stopped_msg` | gains `{ckpt {}}`. Empty → today's sentence, byte for byte. Non-empty → the frame with the word **partial** and the adapter's **`after_ckpt`** clause; **no `after_ckpt` → nothing at all**, never the other column's sentence |
| `ase::run_record` | **new** — the run record of a live run by its execute id, `{}` for a non-integer, an absent id, a foreign callback or a short list |
| `ase::backend::ngspice::run_stop_cost` | fourth key `after_ckpt`, the past tense of `before_ckpt` in `after`'s voice — neither names ngspice, because at this instant the user is being told about their RESULT and not about the simulator's run model |

**What is unchanged, and how it is known:** `ase::run_stop_warning`, `ase::ckpt_worst_n`,
`ase::ckpt_plan`, `ase::ckpt_rows`, `ase::ckpt_report`, `ase::run_deck`,
`ase::run_log_header` and every deck golden — no line of any of them is in the diff. Rows
**SW1–SW7**, **CK28–CK29**, **L10–L12** and **NP7** are green unmoved, and **SW2 is the
byte-identity contract**: it passes no plan, which *is* the un-checkpointed run.

⚠ **The stale prediction in the adapter's own comment is corrected in place, not deleted** —
for the second time. It predicted two keys; 1473 made three and said so; there are now
**four**, and the comment records the axis it got wrong: `before`/`after` is **when** the
sentence is said, the `_ckpt` half is **which run** it is said about.

### The two suites — floors raised with each file's own paragraph

| suite | rows | floor |
|---|---|---|
| `test_ase_core` | **CK28f** (the eight residue kinds, one row at a time, with the control), **CK30** (the split, and the old sentence byte for byte), **CK30b** (`after` without `after_ckpt` → silence; no hook → silence), **CK30c** (the signature: no rc, no `sim_status`), **CK31** (**the two messages against each other**), **CK32** (`ase::run_record`, incl. the foreign callback), **CK33** (record → CIW through the real `do_stop`, and the run is still really killed), **CK33b** (read, not re-derived, and read before the kill) | **644 → 652** |
| `test_ase_trnoise_1466` | **NP7b** — the noisy transient is told at the STOP what was kept, its two sentences make the same claim, and the identical card without its noise table is told nothing was written. ⚠ It sits eleven lines below **NP6**, which measures that this exact bench's salvage note says *"kept at 200000 points of an estimated 500000"* — the two halves of the contradiction, in one file, on purpose | **79 → 80** |

All nine new rows are **pure Tcl and start no simulator**, so they are not run twice per
binary; what is per-binary in `test_ase_trnoise_1466` (EC/EE) ran unchanged, **0 SKIPPED**,
on both arms.

---

## Suites — before → after → restored, every arm, with rc

**Before** = the untouched tree at `df5df4fe`. Headless
`./src/xschem --nogui --pipe -q --nolog --script`; display
`tests/headless/devdisplay.sh exec timeout --kill-after=20 400 ./src/xschem --pipe -q
--nolog --script` on `:99` (**Xvfb + openbox**, 1920x1080x24, `devdisplay.sh status`
confirmed live before the first run). Every run rc **0** except where named.

| suite | headless before → after | display before → after |
|---|---|---|
| **`test_ase_core`** | 644 → **ALL PASS (652)** | 644 → **ALL PASS (652)** |
| **`test_ase_trnoise_1466`** | 79 → **ALL PASS (80)** | 79 → **ALL PASS (80)** |
| `test_ase_simreg_0931` | 118 → 118 | 118 → 118 |
| `test_ase_persist` | 49 → 49 | 153 → 153 |
| `test_ase_preflight` | 235 → 235 | 235 → 235 |
| `test_ase_events_1465` | 87 → 87 | 87 → 87 |
| `test_ase_variant_1470` | 76 → 76 | 76 → 76 |

**Not a count diff — a NAME diff.** Row names extracted from every `ok:`/`FAIL:` line, base
against after, on **both** arms:

* **lost = 0 in all fourteen comparisons.** Every base row is among the after rows.
* **gained**: `test_ase_core` `CK28f CK30 CK30b CK30c CK31 CK32 CK33 CK33b` (8, both arms),
  `test_ase_trnoise_1466` `NP7b` (1, both arms). The other five suites gained nothing and
  lost nothing on either arm.

**Final (restored) tree, both arms, rc 0:** headless **652 / 118 / 80 / 49 / 235 / 87 / 76**,
display **652 / 118 / 80 / 153 / 235 / 87 / 76** — the campaign's positive last row.

### ⚠ ONE RED I DID NOT CAUSE, NAMED RATHER THAN ABSORBED

The **after** display sweep returned `test_ase_trnoise_1466` **1 FAILED (79 passed)**, on row
**`EE5`** — *"under the bench's seed the random source and the RTS source repeat run to run
and the white noise does not"*, last term `0` where `1` was expected. It is a **real two-run
ngspice end-to-end row** about seeded-noise repeatability and touches nothing in this change:
the diff moves `ase::run_stopped_msg`, `ase::run_record`, one adapter dict key and
`ase::ui::do_stop`, none of which is reachable from a noise-seed measurement.

⚠ **AND IT IS NOT BINARY-SPECIFIC — MY FIRST WRITE-UP OF IT WAS WRONG.** I saw the red on the
`apt` leg (`EE5/apt`) and named the leg. **The driver's independent verifier then saw it once
in 38 runs, on `EE5/fork`**, with an identical symptom. Two legs, same row, same shape: it is
a **binary-independent intermittent in a pre-existing real-ngspice row**, and a receipt that
said "apt" would have sent the next crew looking at the wrong binary.

**Characterised rather than re-run until green**: five immediate repeats (3 display + 2
headless) all **ALL PASS (80)**, and it has been green in every run of mine since. **That is
not a pass and it is not a rate** — the honest figure is the verifier's, 1 in 38 across both
legs. It stays a **named intermittent**; it is not filed as an issue, but a later crew
meeting `EE5` on either binary should read this paragraph before assuming it is new.

### Background runs

**None.** Every suite, probe and campaign chunk ran in the foreground under `timeout`; the
harness stopped nothing, so no result here lacks a verdict. The sabotage campaign was split
into four foreground chunks only because the tool's own ceiling is 10 minutes — never
backgrounded, and never run beside anything else, because an arm mutates the shared working
tree and a concurrent suite would have been measuring it.

---

## `.state` byte identity

Through **`tests/headless/state_roundtrip.tcl`**, driven through the proc (`source` +
`ase_state_roundtrip $repo`) and **not** as a bare `--script`, which defines the proc and
compares nothing (receipt 49b C2):

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

**No new state key.** `ckpt` is a field of the in-memory RUN RECORD, which is never
serialised; `ase::run_record` only reads it back. `ase::omit_if_empty` is untouched and ⚖ R8
is not engaged.

---

## THE SABOTAGE CAMPAIGN — 11 arms, 11 killed by name, 0 survivors, 0 restore mismatches

⚠ **N07 AND N10 WERE RUN TWICE, THE SECOND TIME AGAINST THE CHANGED PROC.** Deleting the
`dict size` guard (C7) edited the very proc arm N07 attacks, so re-running the whole
campaign's conclusions off the pre-deletion bytes would have been a stale measurement of a
file that had moved. N07 was re-run and still reds **CK32** alone; **N10 is new** and exists
because a deletion leaves no new line to pin — it answers `{}` from `ase::run_record`
unconditionally, and reds **CK32 and CK33**, which is what shows the *surviving* body is
load-bearing rather than merely unbroken. Arms N00–N06, N08 and N09 touch code the deletion
did not move and stand as measured.

Every arm: exact-anchor mutation of the **fixed** bytes (anchor count asserted **= 1**, and
an arm whose md5 equals the fixed file's is **REFUSED** — a mutation that changed nothing
would "survive" and read as a missing row), the two suites carrying the new rows run headless
under `timeout`, reds read **by row name**, restore by plain `cp` + md5 compare from a
`finally:` block **and** from SIGINT/SIGTERM/SIGHUP handlers. **The gate is a positive
assertion and was fed the empty case first**:

```
GATE CONTROLS empty=NORESULT partial=NORESULT crash=NORESULT pass=SURVIVED fail=KILLED
```

| # | what I broke | rows that reddened |
|---|---|---|
| **N00** | **the whole pre-change pair** — no fix at all | core/**CK0** (section CK died on `wrong # args: should be "ase::run_stopped_msg ?sim?"`, taking CK30–CK33b with it), trnoise/**NP7b** |
| N01 | the stop sentence ignores the plan it is handed | CK30 CK30b **CK30c** CK31 CK33 NP7b |
| N02 | a missing `after_ckpt` **falls back** to the discarded sentence | **CK30b** CK31 |
| N03 | an EMPTY plan is treated as checkpointed | **SW2** CK30 CK30b CK31 CK33 NP7b |
| N04 | the Stop door passes no plan | **CK33** |
| N05 | the Stop door **re-derives** the plan from the session's current bench | CK33 **CK33b** |
| N06 | the record is read **after** the kill | **CK33b** |
| N07 | `ase::run_record` reads element 4 of ANY callback | **CK32** |
| N08 | the adapter loses `after_ckpt` | CK30 CK31 CK33 NP7b |
| N09 | every analysis type answers `tran`'s salvage declaration | CK6 CK20 CK27 **CK28f** |
| **N10** | **`ase::run_record` always answers `{}`** — the arm the guard deletion owes, since a removed line leaves nothing new to pin | **CK32** **CK33** |
| **final** | **the restored tree**, md5 `78adcd17…` / `b38be6df…` | **both arms ALL PASS across all seven suites — 652 / 118 / 80 / 49 / 235 / 87 / 76 headless, 652 / 118 / 80 / 153 / 235 / 87 / 76 display, rc 0** |

**Every new row reddened under at least one arm**: CK28f (N09), CK30 (N01 N03 N08), CK30b
(N01 N02 N03), CK30c (N01), CK31 (N01 N02 N03 N08), CK32 (**N07 N10**), CK33 (N01 N03 N04
N05 N08 **N10**), CK33b (N05 N06), NP7b (N00 N01 N03 N08).

⚠ **N03 is the arm worth reading twice.** It reds **SW2** — the un-checkpointed stop
sentence's own row, written before this issue — which is the byte-identity contract proving
itself load-bearing rather than assumed: the moment an ordinary run is treated as
checkpointed, a row nobody touched says so. (This is 1473's M09 lesson recurring one message
later, where it reddened SW1 and SW4.)

⚠ **N05 is the arm the source-scan row exists for.** Re-deriving the plan from the session's
current bench is the defect that only shows when the bench has *moved*, and no runtime
fixture in a suite can make a user edit a form mid-run. **CK33b** is what catches it, and
N05 reddens it by name.

Logs: `…/s1474/sab/logs/<arm>.<suite>.h.log`.

---

## Debts — queue before → after

`owed.sh count`: **186 rule, 70 look, 11 suite → 187 rule, 70 look, 11 suite.** The one
addition is **`rule 1474`**, stamped `repo:/home/analog/dev/xschem-claude` with its `ref:`
resolving to the issue file. **The ledger was backed up before the write**
(`…/s1474/owed_backup_20260915_180217`), per the brief's one-sided-refusal warning, and
`cleared.log` is unchanged at 51 lines — **nothing was cleared, by me or by anything I ran.**

**No `look` debt**: this task draws no pixel. The sentence goes to the CIW through
`ase::echo`, which rows CK33 and NP7b read at its own sink; what the window *draws* after a
Stop is untouched. **No `suite` debt**: no new row maps a window, and both suites were run on
`:99` anyway.

### ⚠ DEBT M18's SECOND HALF — CLOSED

1473 closed the launch half. This closes the moment-of-the-Stop half by **CK30** (the split,
with the old sentence byte for byte), **CK31** (the two messages of one run make the same
claim), **CK33** (the plan reaches the user's screen through the real Stop door) and
**NP7b** (the noisy transient NP6 measures is told, at the Stop, what NP6 says it kept). All
four red against the pre-change behaviour — N00, N01 or N08.

---

## Corrections

| | |
|---|---|
| **C1** | **Receipt 49's "CK28c is a bench of seven residue rows" is now true of seven of the eight kinds, and the eighth is pinned elsewhere.** The bench held six (`op noise disto tf pz sens`) plus `ac`, which is not one of the eight; `sp` is added, and `pss` is pinned by CK28f instead. The verifier's correction is therefore discharged **by measurement**, not by re-wording |
| **C2** | ⚠ **`pss` CANNOT BE PUT IN A WALKED BENCH, and a crew that tries will get a green.** It declares no `emitorder`, so `ase::analysis_emit_rank` answers `{}`, `ase::analysis_emit_order` RAISES, and `ase::ckpt_rows` returns `{}` **for the raise rather than for the salvage declaration** — the row passes for the wrong reason and the non-vacuity control silently collapses to 0. Measured both ways and written into CK28c's comment, because this is the trap the 1473 verifier hit in their own fixture |
| **C3** | **The stop sentence quotes NO percentage**, where its launch sibling quotes `100/(N+1)` %. Not an oversight of symmetry — headline 3, and it is the ⚖ R9 choice recorded in R9-726 |
| **C4** | **My first cut of CK28f and CK31 spelled their expectations as braced multi-line literals with backslash-continuations.** Inside braces Tcl keeps the backslash-newline **literally**, so both expectations carried a double space and both rows reddened on their first run with `got` and `exp` looking identical. Re-spelled with `[list …]` before anything shipped. Worth one line because the failure is invisible in a diff |
| **C5** | **`doc/claude/issues/NUMBERING.md` carried no row for 1474 at hand-over** — verified then (the only `1474` match in the file was inside `2147483647`), and **RESOLVED SINCE: the driver added the row after hand-over and COMMITTED it** (`NUMBERING.md` lines 3437/3439, committed in `0b0b61c0`, and the pointer now reads 1475), so it is not a debt and not part of this diff. ⚠ **And one grep trap, because I fell in it:** the entry is a **bullet** (`- **1474** — …`), not a table row, so my first check — `grep -c '^| \*\*1474'` — answered **0** over a file that plainly contains it. A zero from an anchored pattern is a fact about the pattern until the unanchored grep agrees. Recorded rather than deleted because the reasoning stands — NUMBERING.md is the driver's to write, and a crew editing it is how two clones came to disagree (issue 1400) |
| **C6** | ⚠ **T1's case count is 82, not 84, and the 84 came from a stale log.** My brief and receipt 49b both carried 84. **The trap is the invocation**: `tclsh tests/run_regression.tcl` **from the repo root exits 1 and leaves a stale `results.log` that reads as a clean sweep** — so a reader gets a plausible count and a plausible zero from a file the failed run never rewrote. The documented invocation is `cd tests && tclsh run_regression.tcl`. Carried here because two receipts now quote the wrong number; **T1 was not run by me** (issue 0990 — the driver's, solo, and already done for this tree) |
| **C7** | ⚠ **THE `dict size` GUARD IN `ase::run_record` IS DELETED, AND VERIFICATION IS WHAT RAISED IT.** The driver's verifier removed the line and **both suites stayed ALL PASS** — a seam pinned by no row, in a proc the task did not ask for. I re-measured rather than deferring, because "no row fails" can equally mean the row is missing: **(a) reachability** — the only writer of an `ase::run_done`-headed callback is `ase::run_deck`, which builds element 4 with `dict create`, and `src/xschem.tcl:5889`'s `simulate` writes a script string whose first word is `set_simulate_button`, so the identity check rejects it first; there is no product path to a non-dict element 4. **(b) Effect if reached** — `dict exists` **returns 0 and does not raise** for an odd-length list, a bare word, the empty string and an unbalanced one, so `ase::state_get` answers its default either way: measured `{}` with the guard and `{}` without, and `ZZ` from a well-formed meta in both. **The threat my own comment named — "arbitrary text through `ase::state_get`" — does not reproduce.** **(c) The shape that really breaks** — a callback that is not a well-formed list raises `unmatched open brace in list` at `lindex`, **two lines above the guard**, identically with and without it; `ase::ui::do_stop`'s `catch` is what covers that, and always did. So it defended nothing reachable, changed no answer where it was reachable, and missed the only failing case. Deleted, with the measurement written into the proc's header — issue 1432's S32, which `ase::ckpt_plan`'s own header already states: a line whose whole effect another line has had is deleted rather than given a fixture. **The identity check is a different line, is reachable, and stays pinned by CK32/N07** |

---

## Found, not fixed

1. ~~**NUMBERING.md has no 1474 row**~~ — **CLOSED by the driver after hand-over** (C5).
2. ⚠ **A run that COMPLETES microseconds before the kill is told it is partial.**
   `ase::ui::do_stop` cannot know the simulator finished between its `run_in_flight` check
   and its `kill`, so the sentence says "partial" for a run `ase::ckpt_report` will then
   score `complete` (and say nothing about, having deleted the checkpoint). **The same race
   existed for the old sentence in the opposite direction** — "nothing of this run was
   written" for a run that wrote everything — so it is neither introduced nor widened here,
   and closing it needs the completion echo at an instant where the log is still buffered.
   Named, not filed.
3. **R9-726 carries a reviewer question of its own**: whether *"every point up to this run's
   last checkpoint was written"* is the right thing to say when the Stop landed **before the
   first checkpoint**, where the salvage note that follows says *"kept nothing"*. The two do
   not contradict — "every point up to the last checkpoint" is vacuously none — but it is a
   blunter answer than the sentence leads a reader to expect. In the R9 entry for the user.
4. **`full_audit.sh`'s pass arm (issue 0805) and every other standing item** were not
   touched and are not this task's.

---

## What binds later stages

1. **The stop sentence's shape is now `(simulator, this run's plan)`, the same as the launch
   warning's.** A stage that adds a salvageable analysis type gets both sentences for free,
   in all three channels, by declaring `salvage` — nothing in either message knows a type
   name.
2. **`ase::run_record` is the seam for any future "ask about the run being stopped".** It is
   the only reader of `execute(callback,<id>)` on ASE-L's side, it validates the callback's
   identity, and a caller wanting another per-run fact should add a field to the record in
   `ase::run_deck` rather than re-deriving anything at the Stop door.
3. **The `run_stop_cost` hook now has four keys on two axes** — `before`/`after` is *when*,
   the `_ckpt` half is *which run*. A new backend may declare any subset; ASE-L says nothing
   in the cases it was not told about and never substitutes the other column's sentence.
4. ⚠ **A suite of per-message goldens cannot see a contradiction between messages.** CK31 is
   the shape to copy the next time two sentences describe one event: reduce each to its
   claim, then assert the claims against each other, with the expectation pinning the answer
   so that unanimous-and-wrong is still a red.

## Hygiene

* **Snapshots disarmed**: the pristine (pre-change) and fixed copies of `src/ase.tcl` and
  `src/ase_window.tcl`, and `sab.py`, are under
  `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/s1474_1474/`, so nothing of this crew's can restore
  over a moving tree. Working logs kept at `…/s1474/` (`base/`, `after/`, `final/`, `sab/`,
  `probe1.tcl`, `probe2.tcl`, `rt.tcl`, `owed_backup_*`).
* **No background process of this crew is running** — checked by process NAME
  (`ps -eo comm=`, never a `-f` pattern this shell's own argv could match): no `xschem`, no
  `ngspice`, no `python3`. Only `Xvfb` and `openbox` for `:99`, left as they were found.
* `git status` at hand-over is the five modified files; **two untracked receipts — this one
  and the verifier's `50b-1474-verification.md`, which is theirs and which I have not
  touched**; and the four untracked entries that were there at the start (`.xschem/`, two
  `doc/claude/rdw_*_batch/`, one `sky130A/…/debug_st1/`) — none of those four touched.
  `NUMBERING.md` is **not** in that list: the driver committed its 1474 row (C5).
  `/home/analog/dev/xschem-op-wcard` untouched. The only write outside the repo is the
  `owed.sh` rule entry, backed up first.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching
  anything.**

`…/scratchpad` is
`/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
