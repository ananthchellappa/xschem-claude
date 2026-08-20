# Results batch — LEDGER

**Driver-owned. No crew agent may edit this file.** The driver appends the row
after each item returns.

State lives here, not in the driver's context. **After any compaction, re-read
this file first**, then `PLAN.md` §1.

---

## Batch

| | |
|---|---|
| Feature | `Results ▸ Select…` — bind a saved simulation result to an ASE-L session |
| Spec | `doc/claude/specs/results_selection.md` (966 lines, ruled §17) |
| Plan | `PLAN.md` — **§1 is the authoritative item list** |
| Decisions | `DECISIONS.md` — 10 user rulings + 2 driver rulings, none re-openable |
| Crew brief | `CREW_BRIEF.md` — in every item's `load` list |
| Pipeline | `item_pipeline.js` — Implement → Verify → Review×3 → Fix → Commit |
| Branch | `fluid-editing`, base HEAD `226302f9` |
| Push | **never** |

## Baseline

| | |
|---|---|
| File | `baseline_2026-08-19_226302f9.txt` |
| HEAD | `226302f9` |
| Display | `:99` (dev display, 1920x1080x24, openbox), `GUI_GATE=1` |
| Summary | **331 pass / 15 fail / 0 crash-timeout / 0 skip (total 346)** · scratch 0 leaked · tree 0 appeared 0 vanished |
| Reds | `test_ase_window` `test_cadence_drag` `test_ciw` `test_gf180mcud_libmgr` `test_ihp_sg13g2_libmgr` `test_lib_manager_gui` `test_lib_manager_locate` `test_lib_sweep` `test_reopen_readonly` `test_rotate_stretch_short_0104` `test_selflog_output` `test_sky130a_libmgr` `test_wave_markers` `test_wave_sigbrowser_0312` `test_wave_sigbrowser_keys` |

**Every audit is judged as a DIFF against that file, by test NAME and STATUS,
both directions. Never by the red count.**
`doc/claude/batch_F/baseline_status.txt` is **VOID** — do not diff against it.

Rolled forward when an item adds a suite of its own; both `BASELINE` and
`BASELINE_SUMMARY` in `item_pipeline.js` move together, and the roll is recorded
in the row that caused it.

## Verdict key

`[x]` done, verified by sabotaged checks · `[E]` done, pixels — a human must look
· `[D]` deferred (issue required) · `[F]` failed (issue required)

---

## Items

| # | item | verdict | commit | checks | sabotages | files | eyeball | note |
|---|------|---------|--------|--------|-----------|-------|---------|------|
| 1 | `read-restamp-0509` | `[x]` | `7aa76dca` | 74 | 21 | 7 | no | R110 + **R110a/b/c** ruled into spec §3.1; S1/S2 red sets disjoint ⇒ both twice-written arms proven; audit 332/15/0/0 of 347, **no status moved**. |
| 2 | `results-tcl-resolver` | `[x]` | `91c6eb9a` | 139 | 34 | 11 | no | `src/results.tcl` 379 lines, sourced + in `Makefile.in` install. Scope fence held (no mutator). R201a-e/R304a-b/R305a-b/R803a/R805a ruled into spec. Audit 332/15/0/0 of 347, **no status moved**. |
| 3 | `raw-select-subverb` | `[x]` | `8377532a` | 215 | 38 | 10 | no | `raw select` + `raw non_spice` shipped; **R110d** fixes `new_rawfile()`'s third copy. 10 rulings; **R301b overturns the brief — `<type>` is OPTIONAL**. 0513 filed w/ reproducer. Audit 332/15/0/0 of 347, **no status moved**. |
| 4 | `results-select-orchestrator` | `[x]` | `2b138685` | 296 | 41 | 7 | **see below** | `results::select` shipped; 13 confirmed findings all reproduced+fixed, none unconfirmed. 0216 shape fixed for this path. **An ad-hoc drive destroyed the user's `~/.xschem/raw_history`.** Audit 332/15/0/0 of 347, **no status moved**. |
| 5 | `rawbar-load-reexpress` | `[x]` | `f22cade2` | 532 | 27 | 8 | **see below** | R501a/b/c into spec §7.1; five refusal arms measured and pinned; T-J half ruled → **0515** filed OPEN (refused ctx switch says nothing). **Damaged `~/.xschem/recent_files`; repaired from a 5-week-stale `.bak`.** Audit 332/15/0/0 of 347, **no status moved**. |
| 6 | `persistence-write-side` | `[x]` | `e9e5389d` | 497 | 29 | 7 | **look owed** | Slot finally WRITTEN. R602a-f/R604a/R605a into spec §8.1; **R602a overturns item 4's own description of its seam** and §5.2 was corrected in place. T-E made non-skippable three ways. Audit **no status moved**. |
| 7 | `results-select-dialog` | **`[E]`** | `7315cb87` | 58 | 65 | 10 | **2 looks owed** | The door. `src/ase_window.tcl` +879, 25 `rsel_*` procs, new suite `test_results_dialog`. 10 rulings into spec §6.1, incl. **R407c** ruling item 4's open question. Audit 333/15/0/0 of 348, **0 status changes**, 2 declared new rows. |
| 8 | `waves-menu-cadence-gate` | **`[E]`** | `a010fa63` | 42 | 50 | 9 | **2 looks owed** | Gated, **not repaired** (U4/U12). New suite `test_waves_gate` (741 lines). Nine confirmed defects fixed. **0508 FIXED** — worded so nobody reads it as `raw_read` having stopped clearing. Audit 334/15/0/0 of 349, **0 status changes**. |
| 9 | `kill-second-rawinfo-parser` | `[x]` | `70801385` | 377 | 21 | 12 | no | **R304c** removed, not re-expressed; **R304d** tombstone keeps `xschem.tcl` line-neutral so no citation re-stales. T-K ships as group AP, SEL459-474. **0507 FIXED.** Audit 334/15/0/0 of 349, **0 status changes**, 3 declared new suites. |
| 10 | `calculator-consumes-selection` | **`[E]`** | `407dc86b` | 789 | 38 | 8 | **2 looks owed** | U3/U6/U7/U9 landed; `self` arm gone; T-J's other half ruled. **Issue 0516 filed: R407a's `here` arm collides with U6 — needs the USER's word.** Audit 334/15/0/0 of 349, **0 status changes**. |

## Issues this batch closes

| issue | item | status |
|---|---|---|
| 0509 | 1 | **FIXED** `7aa76dca` — candidate (1) |
| 0516 | filed by item 10 | **OPEN, BLOCKED ON THE USER** — a result selected through `Results ▸ Select…`'s `here` arm is invisible to the Calculator. Two items of this batch, each correct on its own terms. See the closeout below. |
| 0515 | filed by item 5 | **OPEN** — the Location bar's refused context switch says nothing at all. Ruled deliberately unfixed (T-C wins over T-J on this arm). |
| 0514 | filed by item 4 | **OPEN** — no Tcl accessor for `raw->schname`, so R804's sentence cannot name the schematic a result was read against. Message-quality only; pre-existing. |
| 0513 | filed by item 3 | **OPEN** — `raw switch`'s OP publish gate reads the PREVIOUS database. Pre-dates the batch, measured on a pristine binary. Not fixed: R111 binds. |
| 0508 | 8 | **FIXED** `a010fa63` — GATED, not repaired; `raw_read` still clears outside `cadence_compat` |
| 0507 | 9 | **FIXED** `70801385` — removed, tombstone keeps the file line-neutral |
| 0216 (shape only) | 4 | **shape fixed** `2b138685` — `results::select` pushes to the MRU |

## Eyeball debts

Item 7 is a pixel deliverable and **may not be verdicted `[x]`**. Its closer owes
`tests/headless/owed.sh add look`. Record the debt id here when it is raised.

| debt | raised by | what to look at | cleared |
|---|---|---|---|
| | | | |

## Notes and rolls

- **2026-08-19** — batch opened. Two driver rulings taken (`DECISIONS.md` §B):
  D-A = R110's re-stamp **and** the new `xschem raw select` sub-verb (the spec's
  standing assumption, rung 3's zero-C option rejected because it fixes one
  caller, not the verb); D-B = no run history, no per-run result directories, no
  read-side migration.
- **2026-08-19** — baseline shot at `226302f9`: **331/15/0/0 of 346**, byte-for-byte the same status set as the casemode batch closer audit, so the tree is stable going in. `BASELINE_SUMMARY` filled in `item_pipeline.js`.

## Suites this batch has added — expected +1 PASS rows against the baseline

The baseline file stays at `226302f9` (331/15/0/0 of 346). Rather than re-shoot
it per item, the rows this batch legitimately ADDS are listed here and in the
pipeline's `BASELINE_SUMMARY`. A row not in this list, moving in either
direction, belongs to the item that moved it.

| suite | added by | total after |
|---|---|---|
| `test_results_select` | item 1 | 347 |
| `test_results_dialog` | item 7 | 348 |
| `test_waves_gate` | item 8 | 349 |

## Carried forward — raised by an item, not that item's to fix

| from | what | disposition |
|---|---|---|
| item 3 §2 | **Two spellings of one path are TWO RUNS** — `w/an.raw` and `w/../w/an.raw` both read, two slots; the engine dedupes by `strcmp`. `~` expansion is the only normalisation the C verb does. | **`file normalize` is item 4's Tcl-side call.** Named in item 4's brief. |
| item 3 §5 | Six reviewer not-proven items carried as known and unfixed: `xschem raw_query select` MUTATES (pre-existing `argv[1]` aliasing, as `raw_query read`/`clear`/`new` already do); `_is_result_type Table` answers 1 where old Tcl answered 0 (latent, no slot carries an uppercase token); `raw select {}` returns 0 rather than the no-file error and extra positional args are ignored; `save.c`'s `if(type && !type[0]) type = NULL;` is dead so citing it as the L6 guard is overstated; `developer_info.html`'s `raw what = …` list is stale (already was, for `is_digital`/`casemode`/`vcd_read`). | Left standing. Re-raise only with a reproducer. |
| item 3 §5 | **SEL195 pins today's buggy `raw switch` behaviour on purpose and WILL INVERT when 0513 is fixed**; its own comment says so. Group AB writes `~/.xschem_results_select_<pid>/` under `$HOME` and removes it — outside where `full_audit.sh`'s TREE check can see it, because `~` cannot be redirected into `test_scratch`. | Known. Any later item touching `raw switch` must expect SEL195 to move. |
| item 4 §5 | **T-J's F6 borrow half is NOT delivered by item 4** — `grep -n 'borrow\|enter_ctx\|leave_ctx'` over `src/results.tcl` and the suite returns nothing, by design. Reassigned in spec §12 under the invariant table. | **Split between item 5** (R501 leaves `switch_ctx` in `rawbar_load`) **and item 10** (R502/T-I). Neither may mark T-J done on item 4's four checks. |
| item 4 §5 | **A typeless select of a VCD or table REFUSES**, because the no-type arm reaches the C reader as `<unspecified>` — so a non-spice database that reaches the MRU can never be re-selected through R303's door. Not called a bug. | **Item 7 is the first caller that can hit it and must rule it.** |
| item 9 §5 | **No reviewer reproduced any sabotage row** — a concurrent lens was mutating the shared tree and lenses 2/3 could not mutate, so the audit and every drive are the closer's own. The read-only rule removed the corruption but also removed independent reproduction. | **Driver tightened the prompts before item 10**: the read-only clause now says *not even temporarily, not even restored afterwards*, and lens 3's mandate says the other two are told so. If a later batch wants independent reproduction back, give each lens its own worktree. |
| item 9 §5 | **T-K has two declared holes**, unmeasured beyond reading: a proc taking the `raw info` blob as a **parameter**, and a **file-scope** capture consumed after a `proc` line. Also `SEL468/469` pin `save.c` line numbers — when that file next gains lines near `extra_rawfile()` they red, and **the fix is re-grep and restate, never delete**. | Recorded. Not this batch's to close. |
| item 4 §5 | **Concurrency during review is real**: files were rewritten mid-measurement in the implementation round. Named by the crew as a batch-orchestration matter for the driver. | **FIXED BY THE DRIVER in `item_pipeline.js`**, from item 5 on: lenses 1 and 2 are now READ-ONLY and propose sabotage recipes; lens 3 is the sole reviewer permitted to mutate, and must md5 before/after and prove the restore with `cmp -s`. |
| item 1 §5 | **A THIRD verbatim copy of the "file found" branch exists in `new_rawfile()` (`src/save.c:1570-1577`) and does not re-stamp.** Different function, different contract (`0` = already loaded); no reproducer was built either way, and 0509 closed naming it. | **Handed to item 3.** Its crew is already inside `extra_rawfile()`'s neighbourhood: MEASURE it, then either fix it or file an issue with a real reproducer. Do not file a speculative one. |
| item 2 §2 R305b | **`raw_type_is_non_spice()` (`src/save.c:1622`) has no Tcl verb**, so `results::current`'s R102 gate hard-codes the one reader token `table` beside its C predicate. `xschem raw is_digital` answers the reader table's *other* column and returns 0 for `table` on purpose. | **Offered to item 3** as a bounded extra: add `xschem raw non_spice <type>` while in the same C file, then let `results.tcl` ask the engine. The crew may decline with evidence. |
| item 2 §5 | **`results::list` shadows Tcl's `list` inside the namespace** (documented in the header; every construction written `::list`). And `resolve` does not normalize `..` while `list` returns the engine's verbatim spelling — the engine dedupes by `strcmp`. | **Both are item 4's hazard**, since "is this path already loaded?" sits on top of the second one. Named in item 4's brief. |
| item 2 §5 | Seven reviewer observations raised, **none confirmed, none filed**: 0-byte raw and `.vcd` both resolve `ok`; `named` not absolute-ised without a `rundir`; a non-existent explicit `derived` blocks the `key` fallback; a throwing `raw_content_verdict` swallowed as `ok`; whitespace-padded `rawfile` resolves `invalid`; R201e suspected-uncovered. | Left standing. Re-raise only with a reproducer. |

## Damage — the user's `~/.xschem`, TWICE

### Item 4 — `raw_history`

**The user's waveform-result MRU list was destroyed and is not recoverable.**

An **ad-hoc** verification drive of `results::select` — not the suite; the
suite's group AJ shims the writer *before* setting the flag — set
`::update_recent_files` without renaming `wviewer::rawhist_write`, so the real
writer ran and truncated `~/.xschem/raw_history` to the one scratchpad path it
had just pushed. The file now holds an honest empty list
(`set ::wviewer::rawhist {}`).

**Recovery attempted and failed.** There is no `.bak` (unlike `recent_files`,
which has one). The workflow transcripts were searched for a pre-damage capture:
the only `rawhist` value recorded anywhere is the post-damage single scratchpad
path. Nothing in the repo, in `$HOME`, or in any worktree holds the old list.

**This is issue 0119's exact class.** Two durable guards now exist:
`CREW_BRIEF.md` §3's rule (crew, item 4) and a POLICY line in
`item_pipeline.js` that every stage of every later item reads (driver, before
item 5). Both say the same thing: a hand-written drive is not exempt from the
test file's shims, and *"no droppings in `$HOME`"* is a claim to be **checked**
with `ls -la ~/.xschem`, never assumed from a green suite.

## Driver routine, per item

1. `homeguard.sh snap pre-item<N>` before launching.
2. Launch `Workflow({scriptPath: 'doc/claude/results_batch/item_pipeline.js', args: {...}})`, then **END THE TURN**. Do not poll.
3. On the completion notification: `homeguard.sh check pre-item<N>` — restore `geometry` from the snap, investigate anything else.
4. Read the receipt. Append the row here, plus any hand-off, issue or `owed.sh look` debt.
   Re-grep any citation the crew reports stale — `xschem.tcl` line numbers have
   now moved in items 2, 5, 7 and 8, so `CREW_BRIEF.md`'s own pointers rot.
5. Snap, launch the next item.

---

# BATCH CLOSEOUT — 10 / 10 complete, 2026-08-20

| | |
|---|---|
| Items | **10 of 10.** 7 `[x]`, 3 `[E]` (7, 8, 10 — all pixel deliverables) |
| Commits | `7aa76dca` `91c6eb9a` `8377532a` `2b138685` `f22cade2` `e9e5389d` `7315cb87` `a010fa63` `70801385` `407dc86b` + driver rows. **NOTHING PUSHED.** |
| Audit | **334 pass / 15 fail / 0 crash-timeout / 0 skip of 349**, against the baseline's 331/15/0/0 of 346. **Zero status changes in either direction, every item, all ten.** The +3 are this batch's own suites. |
| New code | `src/results.tcl` (new), `xschem raw select` + `raw non_spice` (C), the ASE-L `Results ▸ Select…` dialog (+879 in `ase_window.tcl`) |
| New suites | `test_results_select`, `test_results_dialog`, `test_waves_gate` |
| Issues closed | **0507**, **0508**, **0509**; **0216**'s shape |
| Issues filed | **0513**, **0514**, **0515**, **0516** — all measured, none speculative |
| Eyeball debts | **5**, all unpaid. `owed.sh list` |
| User data lost | `~/.xschem/raw_history` (item 4, unrecoverable) and five weeks of `~/.xschem/recent_files` (item 5). See the Damage section. |

## The one thing that needs the user, not the driver

**Issue 0516.** Item 7's **R407a** gave the Select dialog a `here` arm — with no
viewer in the session it selects into the current context — and justified it
verbatim: *"'evaluate against last night's raw' happens BEFORE a run, which is
exactly when no viewer exists."* That sentence names Evaluate. Item 10's **U6**
then removed the Calculator's `self` arm *"entirely, not demoted"*. So a
selection made through **this batch's own door** can land where the Calculator
will not look: the row says no result, Evaluate refuses. Measured on an unedited
tree, A/B'd against `HEAD:src/calculator.tcl`.

Both crews were right and neither could fix it: **U6 is a user ruling and a crew
agent may not overturn one.** Nor may the driver.

**Driver's reading, for the user to accept or reject.** U6's stated purpose is
that the Calculator *"must never read a raw that a **legacy path** put into a
schematic window"* — that is about **provenance**, not location. A selection made
through `results::select` is the opposite of a legacy path; it is R303's one
door. So the narrow arm the reviewer proposed does not defeat U6's intent, it
serves it — provided the Calculator reads the current context **only** when the
selection got there through `results::select`, which means stamping provenance
rather than trusting the location. The alternative — deleting R407a's `here` arm
so Select refuses without a viewer — is cheaper but breaks the pre-run case item
7 built it for.

## What is NOT in this batch, deliberately

- **Run history / per-run result directories** (R704, D7, driver ruling D-B).
- **Typed accessors `VT(out)`/`IT(...)`** — the half that makes a plotted name say
  which analysis it came from. Own spec, own batch, **blocked on 0512**.
- **R605's clear-then-read order** on the restore path.
- **0511, 0513, 0514, 0515** — each filed with a reason for staying open.
