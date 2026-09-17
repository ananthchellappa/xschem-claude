# Ledger — issue tracker batch

Receipts collected by the driver, newest stage at the bottom. A row lands here only
after the driver has read the receipt and checked at least one of its claims.

**Opened** 2026-09-17 at `2cbce753`, branch `fluid-editing`.

| stage | task | crew status | driver verdict | commit |
|---|---|---|---|---|
| A1 | sample files 1–10, classify against the tree | **DONE** | **accepted** — and it re-aims the batch | — |
| A2 | sample files 11–20, classify against the tree | **DONE** | **accepted** — and it corrects the plan twice (see below) | — |
| A3 | sample files 21–30, classify against the tree | **DONE** | **accepted** — it decided the design (see below); triggered D8 | — |
| A4 | sample files 31–40, classify against the tree | **DONE** | **accepted** — and it caught driver error 6, in its own dispatch brief | — |
| E1 | triage 190 `rule` debts — *does this reach a person?* | **DONE** | **accepted** — and it refutes the driver's claim to the user | — |
| **BC1** | design the convention **and** build the checker (B+C merged, D8) | **DONE** | **accepted** — dissolved requirement 4 rather than meeting it | — |
| **D1** | apply: stamp the 9 measured files, fix 0071's child table | **DONE** | **accepted** — caught a vacuous green on the critical path | — |
| **D0** | verify the 7 stale-closure issues; propose replacement text | **DONE** | **accepted — and it refuted the driver's own detector** | — |
| **E2** | collapse the 48 repeated wording ratifications into one document | **DONE** | **accepted** — corrected D11's premise; caught driver errors 11 and 12 | — |
| **E3** | collapse the 71 `look` debts the same way | **DONE** | **accepted** — deepens error 11 into the batch's real thesis | — |
| **BC2** | fix `scope=` round-trip, spec `open=` counts, spec §4 | **DONE** | **accepted** — root-caused it, and caught driver error 21 | — |
| **T1-base** | pre-change regression baseline (driver's own, never delegated) | **DONE** | **GREEN** — see below | — |
| **F1** | closing gate: register in T1, CLAUDE.md 84→85, post-change run | blocked on BC2 | — | — |

## Running findings

### A2 (files 11–20) — the dangerous direction was empty; the **citation layer** is what rots

`TRUE-OPEN 7 · TRUE-FIXED 2 · STALE-FIXED 1 · BAD-FIX 1 · ROTTED-CITE 8 · STALE-OPEN 0 ·
DUPLICATE 0 · UNKNOWN 0.` n=10 — **not a rate** (D1).

**The headline is the shape, not the count. In all eight rotted citations the symbol
still existed and still behaved as the issue described — only the coordinates died.**
0654 has 5 cites and 5 misses; 0674's two load-bearing cites drifted **~15 000 lines**;
0618's ~20 bad cites sit in a section titled *"so a later reader need not re-derive it"*.

**This converges with the driver's symbol scan from the opposite direction**, and the two
were measured independently: symbols are **98.4% stable** (2016 backticked `foo()`
citations, 33 absent — and see the correction below, of which only a handful are rot at
all), while A2 found line coordinates wrong **8 times in 10**. The tracker's problem is
not that it describes the wrong code. **It is that it points at the wrong place.**
`src/op_annot.tcl:2366-2368` already models the answer in shipped source: *"Cited by
function name, not by line number, on purpose."*

**The rot has escaped the tracker into shipped source.** `src/ciw.tcl:122-126` repeats
0654's three dead coordinates as fact; `src/ase.tcl:15795` cites `ase.tcl:802` from inside
`ase.tcl`. **A checker scoped to `doc/claude/issues/` would miss half the corpus** — C1
must be able to sweep `src/` comments even if D1 only repairs the tracker.

**0442 is a `BAD-FIX` the schema did not anticipate: a placement defect, not a truth
defect.** Its numbered item 1 was accurate when written; the tree then fixed the defect by
the *unnumbered alternative buried at the end of the same section*, and the file's own
header records why the prescribed shape was abandoned — *"a hand-maintained mirror of
another module's rules is wrong by construction and had already drifted twice."* Pasting
item 1 today re-introduces what was deliberately deleted. **No status field would have
caught this**, so B1 must make a prescribed fix say **which option was taken**, not merely
whether it was verified.

**3 of 10 carry their own refutation 100+ lines below the wrong text.** 0665 line 3 says
OPEN and line 59 says FIXED. Append-without-touching-the-top is not an occasional lapse —
it is the corpus's default editing motion, and it is what the **510 both-words** census
measures. The header block has to be able to express supersession.

**Sizing D7: 9 of 10 needed no suite run at all.** The `UNKNOWN`/`NEEDS-RUN` fraction may
be small. The exception is 0448's count-instability claim, which needs repeated T1s and
cannot be refuted by a single green run.

**Two corrections owed upward, both accepted:**
* `PLAN.md:3` said the batch opened at `2cbce753`; **HEAD was `8608c7ef`** by the time A2
  read it. ⚠ **The driver's own plan carried a rotted tree-state citation, inside the
  batch about rotted tree-state citations, within an hour of writing it** — and it rotted
  because *the driver itself committed twice*. This is the sharpest possible argument for
  B1: a tree state in prose decays the moment anyone commits, so the convention must be
  cheap to re-stamp or it will not be kept.
* **CLAUDE.md's `run_regression.tcl:376`** for the four counted shapes is now **`:387`** —
  the same citation CLAUDE.md already records as having moved once from `:327`. Third
  position for one sentence.
* A2 also **refused a hint in its own dispatch**: the driver suggested 0676 might concern
  `share_farm_child` launching children under the developer's real `HOME`; 0676 is about
  action-log **slot 0** and has nothing to do with `HOME`. Do not merge them in D1.

A2 explicitly records that it did **not** re-verify the plan's 1047/510/742/0 census, so
its receipt is **not** corroboration of those figures.

### Driver verification of A3 and A4 — the thesis confirmed in one command

The last two receipts the driver had only ever **relayed**. Both exact:

* **A4 on 0663** — the claim that retired driver **error 6**. `/usr/bin/grep -ci geometry`
  on it returns **0**, and its title is *"a Tcl error in any file sourced late by
  `xschem.tcl` SEGFAULTS startup."* **There is no geometry guard suite in 0663 and never
  was.** A4 was right and the driver's brief was wrong.
* **A4 on 1458 ≡ 1397** — both cite `store_geom` (1 hit and 5), and **1458 names 1397
  twice** while duplicating it. Cross-reference presence really is not duplicate detection.
* **A3 on 0818** — it cites **`fadb226d`**, and that revision **resolves**. The one file in
  the sample that anchored its citations to a tree state is the one whose citations still
  work.
* **A3's contrast** — 0945, 1344 and 0896 carry **zero** `file:line` citations each.

⚠ **Those last two lines are the batch's entire finding, reproducible in one command:**

> **The file that names a revision reproduces. The files that name no positions have
> nothing to lose. The 27-in-40 that name bare positions are the ones that rotted.**

Every receipt in this batch has now been checked against at least one claim, as the ledger
preamble requires — including E1, which was checked last and had corrected what the driver
told the user.

### ⭐ THE AGGREGATE — all 40 pre-registered files, and it re-aims the batch

| verdict | count / 40 | what it means |
|---|---|---|
| **ROTTED-CITE** | **27** | **the disease** |
| TRUE-OPEN | 21 | says open, is open |
| TRUE-FIXED | 14 | says fixed, is fixed |
| **STALE-FIXED** | **7** | says open, tree already fixed it |
| **BAD-FIX** | **1** | a stored fix that would damage the tree |
| **STALE-OPEN** | **0** | *the dangerous direction never appeared* |
| DUPLICATE | 2 | |
| UNKNOWN | 1 | |

*(Crews used slightly different secondary labels, so the four primary rows are the robust
ones. A file can carry several verdicts. **n=40 of 1047 — roughly ±15 points at 95%.
Do not quote this to two significant figures**, per D1.)*

**`PLAN.md` was aimed at the wrong target, and D1 is why we know.** The plan was scoped
around `BAD-FIX` and `STALE-OPEN` — the six prescribed bad fixes the last batch found. In a
**random** sample `STALE-OPEN` is **0 of 40** and `BAD-FIX` is **1 of 40**. Those six were a
**selected** sample, exactly as D1 warned, and a batch that had skipped the pre-registered
measurement would have spent itself hunting a defect class that is genuinely rare while
walking past one that affects **two files in three**.

**The tracker does not describe the wrong code. It points at the wrong place.**

⚠ **And the undercount is real: `BAD-FIX 1` is too low.** A1 declined to score 0296 and
0435 as `BAD-FIX` although both quote C that no longer exists **and still looks like valid
C**. Its verdict on 0435: *"correct by reference, damaging by paste."*

### A1 (files 1–10) — the rot is BELOW THE FOLD, where no header checker can see it

`TRUE-OPEN 7 · TRUE-FIXED 3 · ROTTED-CITE 9 · STALE-FIXED 1 · BAD-FIX 0 · STALE-OPEN 0 ·
UNKNOWN 0 · NEEDS-RUN 0.` Ten files, **ten status-line directions correct**.

⚠ **The finding that most constrains C1: a first-ten-lines checker scores the worst file
in the sample GREEN.** 0071's header is *correct* — it says OPEN and it is open. The rot is
**below the fold**, in the tables an **umbrella** issue uses to track its children: §3 lists
0063 as an unresolved HIGH while 0063 reads `✅ REPLAYABLE`; §4 calls 0003 *"pre-existing"*
while 0003 reads CLOSED; §4b's six *"next mutators"* are **five done**. **Umbrella issues
are what people read to pick work**, so this is the highest-consequence rot in the corpus
and a header-scoped validator is blind to all of it.

**The tracker already contains its own prescription, unimplemented.** Issue **0229** *is*
the write-up of line-number rot: it prescribes *"cite symbols, not offsets"*, **ships a
ready-made pre-commit grep**, is **still OPEN**, and has since rotted itself — its class-d
*"only survivor"* `select.c:790` now lives at `:1021`, and it is the driver's one confirmed
rotted quote (`src/callback.c:2990`). **The fix for this batch's central finding has been
sitting in the tracker, written down, for weeks, unbuilt.** That is the five-filings-zero-
fixes pattern in its purest form.

### E1 — the queue is real; its problem is shape, not validity

| verdict | count | share |
|---|---|---|
| **THEIRS** — reaches a person | **153** | **81%** |
| **MINE** — internal, never should have been filed | 24 | 13% |
| STALE — already decided or moot | 11 | 6% |
| UNKNOWN | 2 | 1% |

**Driver verification of E1 — belatedly, and the gap is worth recording.** The ledger's
own preamble says a row lands only after the driver has checked at least one claim. That
was done for BC1, D0, D1, E2 and E3 — and **not** for E1, **the one receipt that corrected
what the driver had told the user** (error 7). Checked now, read-only, and every claim
holds:

* the rule queue really holds **190**, and E1's four verdicts sum to exactly **190**;
* `1377_isolate_opt_in` — its clearest *never-theirs* example — **exists**;
* **issue 0356 has 0 hits across `rule`, `look` and `suite`**, exactly as E1 reported, so
  the standing constraint protecting it was genuinely **inert**;
* all six top-ranked `THEIRS` ids exist as rule debts (1358 and 1395 carry two entries each).

⚠ **And a spot-check the driver ran and then DISCARDED, correctly.** Three of E2's 48
(`1453`, `1446`, `1398`) were checked against the R9 collection: one present, two absent.
That looks like it contradicts E2's *"36 of the 48 are already in it"* — **and it does not**.
Twelve of the 48 are by E2's own account absent, and these three were drawn from **E1's
top-ranked list**, which is a **selected** sample: the newest and hardest questions are
precisely the ones most likely to be among the missing twelve. **Reporting that as a
refutation would have been D1's selected-sample error for the third time in one evening.**

**The headline is the 153, not the 24** (driver error 7 above). **48 of the 153 are one
repeated request** — *ratify this batch's new on-screen wording* — already explicitly
batched under ⚖ R9 and then filed **one entry at a time over weeks**. Collapsing those 48
into the single review they were always meant to be is the most valuable thing available to
put to the user.

**Ordered for the user** (E1's ranking): `1453` ASE-L's test decks filled their *File >
Open Recent* with ten dead entries · `1352` typing in an xschem dialog runs what you type
as code · `1358_digits…vs_D2` **a ruling they already made was reversed without being put
back to them** · `1395-default` the gesture they asked for in 0932 has no door left ·
`1446` a value typed into a collapsed section is echoed back and silently not saved ·
`1398` every glyph in ASE-L changed typeface, unseen on their screen.

**The clearest never-theirs:** `1377_isolate_opt_in` — *should a test fixture clear the
simulator registry by default or on request?* No surface, no wording, no consequence any
XSCHEM user could observe. Eleven of the 24 are harness or tracker mechanics; five more
state their own answer — **an entry whose text says "Forced by…" is not a question.**

**Two notes carried up.** **Issue 0356 has no ledger entry at all** (0 hits across
rule/look/suite) — the standing constraint protecting it was **inert**. And `1397`/`1458`
are MINE to fix but carry a fact that is theirs to know: **50 of the user's 101 saved
window geometries were permanently displaced by test runs.**

**E1 corrected itself, in the batch's own idiom.** Its first draft took tier sizes from its
table's **row** counts and silently dropped **10 THEIRS entries**; the verdict totals were
right and the presentation lost ten. Caught by grepping the artefact against the ledger,
not by re-reading. *That is the cases-vs-lines conflation CLAUDE.md records getting wrong
three times — reproduced by a crew that had just read the warning.*

**Read-only confirmed by evidence, not assertion:** `diff -rq` against the driver's backup
is **silent**; the ledger is byte-identical. Nothing cleared, edited or added.

### Pre-D1 tree reference, and `tests/untitled~.sch` is NOT ambient — T1 writes it

Taken at `01cef414`, 2026-09-17 12:54, **before** D1 edits anything. Issue **1480**'s
complaint is that *nothing sweeps the `untitled*` residue class and neither audit driver
leaves a log that could attribute it* — so the before-picture has to exist before the
change, not after.

**And it immediately overturned a recorded belief.** The previous session's closing state
recorded `tests/untitled~.sch` as *"ambient, pre-existing, not ours."* Measured:

| | |
|---|---|
| mtime | **2026-09-17 12:47:30** — **inside** the driver's T1 window (12:45:51 → 12:52:22) |
| tracked by git | **no** — `git ls-files --error-unmatch` errors |
| ignored | **yes** — `.gitignore:75` `*~.sch` matches it |
| in `git status --porcelain` | **never** — which is why it read as ambient |

**T1 wrote it, during this batch's own baseline run.** It is not ambient and it is not
pre-existing. This is the `untitled` backup leak of issues **0060**, **0609** and **1480**,
confirmed live — and note *why* it stayed invisible: **it is ignored by git and outside the
guard suite's watch list at the same time.** `test_no_untitled_litter.tcl:22-28` says its
scope is deliberately *"a LIST and not 'the repo root is clean'"*, watching `$repo` and
`$launch_cwd`; a file under `tests/` falls between the two checks. **Two guards, one gap,
and the gap is exactly where the file lives.**

⚠ **Two things NOT to do, both deliberate.**

1. **Do not touch `.gitignore`.** That `*~.sch` rule is what hides the litter from
   `git status` — and *what the user's own `git status` shows them* is **issue 0356**,
   which is **explicitly theirs** and deliberately not taken by this batch or the last one.
   Changing the rule to make the litter visible would be answering their question for them.
2. **Do not mint an issue for this.** It is already 0060, 0609 and 1480. CLAUDE.md's own
   words: *"A sixth document about a defect already documented five times is this project's
   signature failure, not a fix."* The finding is the **attribution** — recorded here.

**Rest of the reference, for F1 to compare against:**

* **9** per-pid verdict logs in `tests/`, **every pid dead** — left alone. `T1_VERDICT_KEEP`
  (86400 s) sweeps them, a pid with `/proc` present is never swept, and the failure
  direction is therefore always *"a leftover survives"*, never *"a live run's answer is
  deleted"*.
* **49** `/tmp/xschem_emergencysave_*` dirs — unchanged, and **never to be deleted**; they
  may belong to live processes.
* **`~/.xschem/ase_simulators` untouched**, verified by content and not by assertion:
  md5 `13c5cec624b130f598db5779f7b2b8bf`, 724 B, mtime 2026-09-14 00:22:03 — byte-identical
  to the value the previous batch recorded. It is the **user's own configuration**, and
  pruning its dead entries was an explicitly rejected fix.
* Untracked set otherwise unchanged from the batch's start, plus BC1's three new files
  (`issue_stamp.tcl`, `issue_stamp_baseline.txt`, `test_issue_stamp.tcl`) — a tool, a
  non-regression baseline **and a suite for the checker itself**, which is red-first done
  properly.

### ⚠⚠⚠ F1 GATE RUN — RED. 55 counted failures, and the driver caused them

```
T1-RUN-END pid=2613154 cases=85 blocks=84 counted_failures=55 elapsed=370s
```

**Against a baseline of ZERO.** Two cases nonzero: **`test_ase_simcaps_0948` — 42** and
**`test_issue_stamp` — 13**. The registration itself worked: `planned_cases=85`,
`Start` 85 / `Finish` 85, solo-ness positively established (0 occurrences of *"another
regression run is live"*), `exit -1` count 0.

**The red is the driver's doing, and the defect is real. Both are true.**

| test | result |
|---|---|
| suite solo, `tclsh` arm | **ALL PASS (43 checks)** |
| suite solo, `./src/xschem --nogui --pipe` arm — **the arm T1 uses** | **ALL PASS (43 checks)** |
| suite inside T1, while the driver hand-ran a second copy | **12 rows + harness line FAIL** |

**Both arms pass solo, so the arm is not the difference. Concurrency is the only variable
left**, which settles the diagnosis.

⚠ **The blast radius is 191 suites, not six.** `tests/headless/scratch.tcl` returns
`<repo>/tests/headless/.scratch` as the **shared** scratch root and **does not pid-qualify**;
**191 suites `source scratch.tcl`**. `test_ase_simcaps_0948:201-202` does exactly that
(`set scratch [test_scratch simcaps0948]`). So the unqualified sweep at
`test_issue_stamp.tcl:589` can delete the live working directory of any of 191 suites —
and today it deleted `simcaps0948`'s **mid-run**, which is the 42.

⚠ **The user's own configuration is INTACT**, verified at the moment of the red:
`~/.xschem/ase_simulators` md5 **`13c5cec624b130f598db5779f7b2b8bf`**, 724 bytes,
mtime 2026-09-14 00:22:03 — unchanged. The simulator-registry rows failed because their
**scratch** was deleted, not because anything of the user's was touched. (`~/.xschem/geometry`
did move at 13:44 — that is the already-recorded 1397/1458 defect firing during T1, not new
damage.)

**Sequenced deliberately: the gate is NOT re-run yet.** Re-running now would certify a file
already known to be defective. **BC3 fixes the sweep with a real-collision red-first proof;
the gate runs after.** The `hcases` registration stays uncommitted until it is green.

### ⚠⚠ F1 — the new suite has the OLD defect: pid-qualified create, unqualified delete

**Found by the driver at the gate, and it is the batch's own machinery carrying the exact
defect class the previous batch existed to fix.**

`tests/headless/test_issue_stamp.tcl` returned **`RESULT: 12 FAILED (31 passed)` ·
`OVERALL: notok`** when run by hand — **twenty minutes after** BC2 reported and the driver
independently verified **`ALL PASS (43 checks)` · `OVERALL: ok`**. Same 43 rows
(31 + 12 = 43); twelve flipped.

**Three hypotheses were tested and refuted before the real one was found** — recorded
because two of them were the driver's confident first guesses:

| hypothesis | verdict |
|---|---|
| a row asserts its own non-registration, as row `B1` did | **refuted** — the only `run_regression` mention is a *comment* about `pgrep -af` self-matching |
| the suite reads state a live T1 writes | **refuted** — it reads no verdict, no `results.log`, no per-case log; the checker reads only `doc/claude/issues/` and the baseline |
| its inputs changed between the runs | **refuted** — corpus untouched (0 files modified in 40 min), `git status` on `doc/claude/issues/` and `tests/headless/` empty, 1047 files / 10 stamped / baseline 1057 throughout |

**The cause, with live evidence.** `tests/headless/.scratch` is a **shared namespace**. At
the moment of measuring it held **`_conc1476_2642112`** — `test_regression_concurrency_1476`
running **inside the live T1** — and the tree records `_campgui1464_*` and `_badig_*` from
other suites.

```tcl
:66   set d [... .scratch istamp_[pid]_$tag]     ;# CREATE: pid-qualified, correct
:68   file delete -force $d                      ;# its own dir, correct
:589  catch {file delete -force [... ] .scratch} ;# SWEEP: THE WHOLE TREE
```

**Creation is qualified by identity; the sweep is qualified by position.** So the suite
destroys every other suite's live scratch state on its way out, and a concurrent
`.scratch` user destroys its fixtures mid-run. That is **`W12b` exactly** — *position is
not identity* — reproduced in the file this batch built to enforce its own convention, and
it is the fifth sighting of a self-inflicted defect in this batch's machinery after BC1's
`rev_exists`, BC1's row `B1`, BC2's scope round-trip, and this.

⚠ **The driver caused the collision it then diagnosed.** The hand-run at 13:41 was a
*diagnostic run undertaken to be careful*, launched while T1 was live — breaking the rule
it was checking. **The failures are real evidence of a real defect, produced by an
illegitimate method.**

⚠ **It came within one green run of shipping into T1.** `issue_stamp` is registered last in
`hcases`, so in this run its sweep fires after the others finish and the blast radius is
small. **Registered anywhere else in the list, it would delete the scratch of every suite
after it.**

**Not minted as an issue.** It is a defect in an uncommitted-behaviour file of this batch's
own making, and CLAUDE.md is explicit that a document about a defect already understood is
this project's signature failure rather than a fix. **It gets fixed, not filed.**

**Sequenced deliberately:** the fix is **not** applied while T1 is live, because T1 is about
to execute that very file. Trailer first, then a solo re-run to capture all twelve row
names, then the fix. **The `hcases` registration stays uncommitted until the gate is green.**

### F1 pre-work — the CLAUDE.md edit is a DOZEN sites, and half of them must NOT change

`issue_stamp` registered in `hcases` (D13). Verified sound before running anything:
`info complete: 1` (the whole driver's brackets balance — a malformed list breaks *every*
case, not just the new one), **`hcases` 69 → 70**, `tcases` 3, `dcases` 11 unchanged, and
the suite file exists. **The registration is deliberately UNCOMMITTED until T1 is green**;
if it reddens it gets reverted rather than shipped.

⚠ **The count is asserted in about a dozen places in CLAUDE.md, and a one-site fix would be
this batch's own disease under the driver's name.** Census taken **before** the edit:

**Must change** (they describe today's tree): the arithmetic block's `69 hcases` and its
`= 84 Start/Finish pairs`; *"The run is 84 cases and 83 log lines"*; the three-numbers
sentence *"84 cases · 83 … · `wc -l` = 171"*; *"one `Total num fail:` line per case minus
one (83 for today's 84)"*; the NODISPLAY derivation *"84 `Start` lines and 73 `Finish`"*
and its companion *"84 `Start` / 84 `Finish`"*; and the baseline line *"`cases=84
blocks=83 counted_failures=0`"*.

**Must NOT change** — these are **dated records of what was true then**, and rewriting them
falsifies the history the file exists to preserve:

* *"84, at a time when the tree ran 83"* — the fossil-`results.log` story;
* *"82 is the number of `Total num fail:` lines"* — the earlier conflation;
* *"It was **68 + 11 + 3 + 1 = 83** until the harness-concurrency batch registered …"*;
* *"that was the 83-case tree, whose log carried 82 lines"*.

⚠⚠ **AND A COLLISION THE NEXT READER WILL WALK INTO.** CLAUDE.md currently warns:
*"This passage said **85** for a few hours on 2026-09-17, and that is the sharpest lesson in
this batch. 85 is `83 + 2` … it **forgets the 83 block-header lines entirely**."* **The
correct case count is now 85** — for a completely unrelated reason (a 70th `hcases` entry).
So the file is about to contain *"85 was wrong"* and *"85 is right"* within a few
paragraphs of each other. **That must be called out explicitly in the edit, or the warning
reads as refuted and gets deleted by someone tidying** — which would retire the single
best-earned lesson in the previous batch.

⚠ **No number here is computed.** `cases=`, the `Total num fail:` count and `wc -l` all come
from the post-change run's own trailer and verdict. The paragraph being edited has been
wrong **three times**, and the third time was **the correction itself**, reached by doing
arithmetic on a sentence instead of running `wc -l` once.

### T1 pre-change baseline — GREEN, at `63a1b41f`

The driver's own run, never delegated (CLAUDE.md: the solo regression run stays with the
driver). `cd tests && tclsh run_regression.tcl`, 12:45:51 → 12:52:22, **rc 0**.

```
T1-RUN-BEGIN pid=2554005 script=run_regression.tcl start=2026-09-17 12:45:51
             planned_cases=84 verdict=results.2554005.log canonical=results.log
T1-RUN-END   pid=2554005 cases=84 blocks=83 counted_failures=0 elapsed=391s
             end=2026-09-17 12:52:22
```

**The baseline is ZERO counted failures and it is met.** Every one of the 83 blocks reports
`Total num fail: 0`; the four counted shapes appear **0** times.

Checked the way CLAUDE.md demands, rather than by reading a number off stdout:

| check | value | why it is here |
|---|---|---|
| trailer present | **yes** | a verdict with no `T1-RUN-END` **did not finish**, whatever it contains |
| `wc -l` | **171** | and it decomposes exactly — **2** sentinels + **83** block headers + **83** `Total num fail:` + **3** NOGOLD |
| ran **solo** | **positively established** | **0** occurrences of *"another regression run is live"* in its own output — better evidence than `pgrep`, which answers yes to itself |
| `exit -1` | **0** | the pre-2026-09-17 corruption tell; no xschem process writes that code |
| `Start` / `Finish` | **84 / 84** | issue **1481**'s NODISPLAY asymmetry did **not** fire — the dev display was alive, exactly as CLAUDE.md predicts for this box |

⚠ **This is the PRE-CHANGE reference, and it was already overtaken while being recorded.**
It was taken at `63a1b41f`; BC1 has since created `tests/headless/issue_stamp.tcl` and
`tests/headless/issue_stamp_baseline.txt` in the working tree. **If BC1 registers that
suite in `hcases`, the case count moves off 84** and CLAUDE.md's arithmetic block
(69 + 11 + 3 + 1 = 84) needs updating in the same commit — the block itself records that
this paragraph has already been wrong three times. F1 re-runs T1 after D1 and compares
against this row.

### ⭐ `status.md` — the tracker's own "what is still open" index, and it is the worst of it

Nobody had looked at this. It is the file a person opens **to pick what to work on**.

| measurement | value |
|---|---|
| last touched | **2026-08-20** (`ab33cee6`) — **28 days ago** |
| issue files committed **since** it was last touched | **616** |
| **issues it actually names** | **26** of 1047 — **2.5% coverage** |
| of those 26: header now reads **FIXED** | **11** — **42%** |
| still reads OPEN | 15 |
| naming a number with no issue file | **0** |

⚠ **These are the SOUND numbers; the driver's first pass published four wrong ones** — see
error 9. A naive `\b[0-9]{4}\b` found **77** "issue numbers", of which **51 were not issue
numbers at all**: `1855` is a **pixel width**, `2026` a **year**, `4096` a **byte count**,
`0521` a sentence saying *"the next one is 0521"*. Extraction now requires the number to be
**presented as an issue** (`| **NNNN** |` or `issue NNNN`), and self-tests against 0517,
0519 and 0520 before reporting.

**A developer who opens `status.md` to choose work is handed a list covering 2.5% of the
tracker, of which 42% is already done.** It is titled *"What is still open — branch `fluid-editing`"*,
and it has been wrong in both directions for a month.

**This is sub-problem 2 in its most consequential form, and it outranks the seven
stale-closure headers D0 is verifying.** A stale header on issue 0264 misleads whoever
opens 0264. A stale *index* misleads **everyone choosing what to open at all** — and it is
the mechanism by which a defect gets filed five times in seven weeks, because the index
that would have shown the previous filing does not list it. 616 of the numbers a re-filer
would need to see are simply absent.

**It also generalises the A1 finding.** A1 measured that 0071's rot is **below the fold**,
in the child tables an umbrella uses to track its children, where a header checker cannot
see it. `status.md` is that same defect at corpus scale: **the index is an umbrella over
everything.** So C1's checker must handle *tables that name issue numbers and assert a
state*, not just headers — and that single check would cover 0071, `status.md`,
`status_annotate.md` (712 lines, unexamined) and every future umbrella at once.

⚠ **Nothing here says delete it.** A stale index is a defect; an absent index is worse,
and this one's 15 genuinely-open entries are real. The finding is that it has no
maintainer and no checker — which is D3's thesis with a very sharp example.

**And it is not one file. It is BOTH indexes**, measured with the same self-tested
extraction:

| index | lines | last touched | issues named | coverage | already FIXED | still open |
|---|---|---|---|---|---|---|
| `status.md` | 223 | 2026-08-20 | **26** | **2.5%** | 11 — **42%** | 15 |
| `status_annotate.md` | 713 | 2026-08-26 | **21** | **2.0%** | 18 — **86%** | 3 |
| **both** | 936 | — | **47** | **4.5%** | **29 — 62%** | 18 |

**`status_annotate.md` is the worse of the two: 86% of what it lists is done.** It is 713
lines long and names 21 issues — the ratio of prose to index is itself the tell. Between
them, the tracker's two top-level indexes cover **4.5%** of the corpus and **62% of what
they do cover is finished work**.

⚠ **Note the inflation these two files would have caused an unwary reader**: naive
4-digit matching finds 77 and 111 "issue numbers" in them; the sound count is 26 and 21.
`status_annotate.md` is **90 false positives** out of 111 — the worst ratio measured
anywhere tonight, and the reason error 9 happened.

### Nine issue-numbered artefacts that no scanner and no convention covers

Not `.md`, so every scan in this batch — and any checker scoped to `NNNN-*.md` — skips
them silently: `0054-activate-probe.tcl`, `0054-raise-drift-probe.tcl`,
`0054-xactivate.c`, and six preserved patches (`0264`, `0436`, `0442`, `0443`, `0466`,
`0494` — five named `attempt-N-reverted`, one `attempt-3-interrupted`). **Six of the nine
are reverted or interrupted attempts**, which is exactly the content a reader must not
paste, and none is reachable from either index. Small, but C1 should say whether its glob
sees them.

### The OTHER half of the user's queue, which E1 did not triage

E1 took the **190 `rule`** debts. Nobody has looked at the **71 `look`** or the **11
`suite`**. Measured by the driver, 2026-09-17:

**The `look` queue has the SAME shape defect as the rule queue.** By mtime: **54 of the 71
were filed on a single day** — 2026-09-10 — then 1, 1, 10, 1, 3, 1 across the following
week. That is one batch discharging its pixel debts one entry at a time into a queue a
person reads serially, which is exactly the pattern D11 is collapsing for the 48 wording
ratifications. **The fix is the same fix**, and it should follow E2's document rather than
invent a second shape.

**These are genuinely the user's, and unlike the rule debts they are not arguable.** A
`look` debt asks for their eyes, and the sample entry reads exactly as it should —
*"Suites green (124 --nogui / 136 :99 window, 53 keys :99, 130 store, 485 op_annot control,
T1 zero); please look: does the row visibly move where you expect, does the shading land on
it and not on the line it left…"*. That is the rule working: **never report a pixel
deliverable done on a green suite.** The defect is the serialisation, not the filing.

**The 11 `suite` debts are NOT the user's** and need no ruling — a suite debt clears itself
on a pass and `owed.sh drain` runs them as one batch with the gate live:
`test_annot_declutter_1244`, `test_ase_campaign_gui_1464`, `test_ase_core`,
`test_ase_dialogs`, `test_ase_optsheet_1441`, `test_ase_simdlg_0937`, `test_ase_window`,
`test_hier_pdf_links_1333`, `test_ps_valid_1350`, `test_rdw_keys_1245`,
`test_rdw_window_1245`. **Deferred, not forgotten:** draining them runs GUI suites, and the
driver's T1 baseline is live — a concurrent suite run would muddy the one number F1 needs.

### A4's geometry finding, independently confirmed by the driver

A4 reported that issues 1397/1458 are live. Confirmed on the user's real configuration:

```
2026-09-17 09:08:56   7076 bytes   ~/.xschem/geometry      <- written TODAY
2026-09-13 18:53:01   2632 bytes   ~/.xschem/recent_files  <- frozen four days ago
101 entries in geometry
```

**`geometry` moved today and `recent_files` did not**, which is the signature: the
`no_recent_files` gate protects one file and not the other, so test runs still write the
user's saved window positions. **50 of those 101 entries were permanently displaced.** This
is `MINE` to fix (E1's verdict) but the *fact* is theirs to know — it is their windows
opening in the wrong place.

⚠ **A separate, unrelated thing that looks similar and is not:** the untracked
`.xschem/op_param_lists.conf` in the **repo root** is dated **2026-09-09**, long before
this batch. It is not tonight's litter and not the geometry defect. Noted so the next
reader does not spend an hour on it — but note also that a repo-root `.xschem/` shadows the
user's own for anything launched from there.

### The driver's corpus-wide run of A4's closure detector

`tools/closescan.py` (self-testing, per the rule the eight errors bought). **165** issue
numbers are claimed closed somewhere — in issue files, `src/`, `tests/` or git log. **154**
have a header that agrees. **7 do not**, and they are the mechanical face of sub-problem 2:

`0071` · `0216` · `0249` · `0264` · `0516` · `0650` · `0947`

**Two are closed by shipped source and git log rather than by another issue** — 0216 via
`src/wave_viewer.tcl`, 0516 via `src/calculator.tcl` — which is the concrete argument for
C1 sweeping beyond `doc/claude/issues/`. At **4.3%** this is a smaller class than citation
rot, and unlike citation rot it is **exactly detectable**, today, with no judgement calls.

### ⭐⭐ E3 — a look collection existed, WAS published, and still changed nothing

**This is the batch's real thesis, and it supersedes D11's correction.**

`doc/claude/lookdebt_batch/` — **tracked**, committed **2026-09-07** (`a7cfa479`,
`4ac6f182`): **46** debts in `debts.json`, each with question / right / wrong / recipe, a
page builder, and photograph poses. **Unlike the wording collection, its own brief says it
WAS published.**

It still changed nothing:

* **8 of its 10 retire recommendations are still in the queue ten days later.** The two
  that went, went in the user's own 2026-09-09 topic close-out — **not** on its
  recommendation.
* **Never maintained:** 46 → **71**, and **36 of today's 71 are absent from it**.
* **Cannot even be rebuilt:** `build_page.py` reads `shots/`, which does not exist. **No PNG
  was ever committed.**

⚠ **So "collect, then hand over" is NOT the lesson, and D11's correction did not go far
enough.** Both collections were built correctly. One was delivered. **Both decayed, because
nothing re-points a collection at a queue that keeps growing.** A handover is an **event**;
the queue is a **process**.

**That unifies every finding in this batch:**

| artefact | state | outcome |
|---|---|---|
| issue **0229** — the fix for citation rot | written down, correct | **never built** |
| `R9_COPY_REVIEW.md` — the wording collection | built, maintained 35 commits | **never handed over** |
| `lookdebt_batch/` — the look collection | built **and handed over** | **never re-pointed; decayed** |
| `status.md` / `status_annotate.md` — the indexes | built | **2.5% / 2.0% coverage, unmaintained** |
| the harness-concurrency defect | filed **five times** | **attempted zero times** |

**The tracker does not fail to know things, and it does not even reliably fail to deliver
them. It fails to KEEP delivering.** No status field, convention, or checker addresses
that — which is the honest limit of what this batch built.

**The collapse: 71 → 27 looks in 5 sittings, ~2h40, plus 10 needing nothing.** Results
window 7 · Schematic 3 · ASE-L 12 · *File > Open Recent* 1 · Hierarchical PDF 4 · retire 10.
Arithmetic re-derived from the deliverable's own reference table; **all 71 ledger ids proved
present, 0 unaccounted.**

**Two live findings worth acting on:**

* ⚠ **`File > Open Recent` is damaged right now** — ten dead ASE-L probe decks and nothing
  of the user's. **Two minutes of their time, and the only item in the entire queue where
  something of theirs is actually broken.** (This is E1's top-ranked `THEIRS` item, 1453,
  reaching the same conclusion independently.)
* `rdw_keys_B4` claims *"nothing to look at yet — it is not in the tree"*. **False** —
  `src/cadence_style_rc` binds keys 1–4 to that window today.

**UNKNOWN recorded, not invented:** the 10 PDF entries live only on branch `op-wcard` of
`~/dev/xschem-op-wcard`, which is **currently checked out on `fluid-editing`**. E3 can say
what to open and **cannot** say whether they are current. A checkout away, and it did not
guess.

**Ledger proved untouched by `diff -rq` four times bracketing the work.**

### BC2 — the writer's vocabulary had drifted from the reader's

**Root cause, and it is a clean one.** `format_stamp` wrote fields by iterating a
hard-coded list `{claim tree stamped fix open super by}` — **`scope` absent** — while
`parse_stamp` accepts `scope` and `ok_key` contains it. **The writer's vocabulary had
drifted from the reader's**, so every round-trip silently deleted the one field keeping
0216 from being closed wrongly. Fixed to `{claim tree stamped fix open super scope by}`,
ordered to the spec's own field table.

⚠ **Why nothing caught it — the vacuous-green family, FOURTH sighting in this batch.** The
round-trip fixture carried only the **required** keys and asked only whether the result
*parsed*. **A fixture whose input lacks a field cannot see a formatter that drops it.**
After BC1's `rev_exists`, BC1's row `B1`, and this, the pattern is established enough to
state as a rule: *a green that never exercised the thing is not evidence about the thing.*

**Red then green, both arms, against 0216's REAL on-disk stamp** rather than a synthetic
one (at the driver's request):

```
before   round-trip LOST OR CHANGED a field: scope ase-rerun-path
         S15b 0/1 · S15c "1 0"/"1 1" · B4 got 0216:scope · D9b 1/0
         RESULT: 4 FAILED (39 passed)        rc 1
after    RESULT: ALL PASS (43 checks) · OVERALL: ok   rc 0
         gate self-test PASSED (17 parser cases) · ISSUE-STAMP: ok (0 problems)
```

Re-run **a second time after the final comment edits**, on the grounds that *a green which
does not cover the final bytes is not evidence*. **All ten committed stamps round-trip
byte-identical** through the fixed formatter — placing `scope` between `super` and `by` is
what makes that true — so **no stamp needed rewriting**.

**The two counts re-derived, not inherited.** **0442 → `open=1`**: item 1 fixed
(`_netlisted` asks the deck index, not symbol attributes), item 3 fixed (`_element` uses
`xschem translate`), item 2 genuinely open (`_force_netlist_env` forces `netlist_type
spice` — a declared constraint, not a fix). **0650 → `open=5`**: 0654/0655/0659/0660/0661
all read OPEN in their own headers, only 0658 moved — **and BC2 checked 0658 against the
tree because it is the one child whose wrongness would make the count too SMALL.** That is
the right direction to be paranoid in.

**A rule worth keeping, endorsing D1's choice over the driver's query:** `super=` names a
**successor carrying the remainder**; `scope=` names a **route nothing else carries**.
0216 has no successor — verified.

**Driver verification** (checker and suite re-run by the driver before anything was
registered): `self-test PASSED (17 parser cases)`, `ISSUE-STAMP: ok (0 problems)`, rc 0;
suite `ALL PASS (43 checks)`, `OVERALL: ok`, including row `N3` covering `scope=`.
`issue_stamp` confirmed **still unregistered** in `run_regression.tcl` (0 hits).

### ⭐ D1 — the convention applied, and a VACUOUS GREEN caught on the critical path

`checker BEFORE ok (0 problems) rc 0` → `AFTER ok (0 problems) rc 0`. Suite **ALL PASS (40
checks)** on both the `tclsh` and `--nogui` arms. **Census exact: 1047 = 10 stamped + 1037
grandfathered.** Baseline 1067 → 1057. **Ten files stamped at line 3 with zero prose
rewritten**, and 0071's child table repaired with its header untouched (*"11 checks"* →
**79**, all fourteen child statuses re-read from their own headers, §4b's five-of-six
re-derived in C rather than inherited).

⚠ **BC1's own suite forbade the adoption BC1's receipt instructs — and it was on the
critical path.** Row `B1` asserted the baseline covers **every** file. But **adoption *is*
deleting a number from the baseline**, so the row reddened on the first ten stamps. It had
been green before **only because zero files were stamped**: a **vacuous green, inside the
file written to prevent vacuous greens.** And `e14a0796` (D13) registers this checker in
T1 next — where it would have become **a counted failure against a ZERO baseline**, the one
thing CLAUDE.md is most emphatic about. D1 corrected the invariant to the one actually
meant (covered by baseline **or** carrying a stamp), added known-negative row `B3`, and
**flagged that it had edited a tracked file rather than burying it.**

**1219's `assert=` block proved non-vacuous by negative control**: flipping `broken` →
`holds` reddens with *"8 hits for SABOTAGE under src"*.

**All three closure candidates were false positives, in three NEW shapes:**

| | verdict | how the detector was fooled |
|---|---|---|
| **0056** | CONFIRMED-CLOSED — **right by accident** | matched *"a folded `.save` **resolves** (upstream 0056)"* — the same `resolves` over-fire BC1 hit on 0818. The tree is closed for reasons the scanner never saw |
| **0885** | **NOT-CLOSED**, untouched | three mechanisms at once: the float literal **`3.950885e-01`**; **the driver's own LEDGER commit about 0885, read back as evidence**; and two commits that genuinely name it saying *"STILL OPEN"* |
| **0897** | **NOT-CLOSED**, untouched | a **negation** — 0894's *"is **not** fixed here and is filed as 0897"* |

⚠ **Across D0 and D1, SEVEN OF TEN verified closure candidates were false.** The detector
is not a work list and never was. **Sending them as candidates rather than as work is the
only reason no live defect was closed** — and 0885 was matched partly by **this ledger's own
commit about 0885**, a citation loop closing in under an hour.

**Driver verification of D1's claims** (the ledger's own rule: a row lands only after the
driver has checked at least one claim). All confirmed on the committed tree:

* **10 stamps, every one at line 3**, all `v1` — as D1 reported.
* All carry `tree=61af3692`, and it **resolves** (`git cat-file -e`).
* The six-valued `claim=` is **genuinely exercised**: `fixed` ×5, `partial` ×3, `latent`
  ×1, `duplicate` ×1 — so `partial`/`latent`, added for 0891 and A3's missing cell, are
  carrying real weight rather than sitting unused.
* `fix=`: `taken` ×5, `superseded` ×2, `partial` ×1, `untried` ×1, `none` ×1.
* **Every `fix=superseded` and the `duplicate` carries a `super=`** (`self`, `32dff39a`,
  `1439`, `0655`, `1397`). **The 0442 rule holds in practice, not just in the grammar.**
* ⚠ **`scope=` appears exactly ONCE in the entire corpus** — 0216. So the formatter bug's
  blast radius is **one file**, which is worth knowing before anyone panics about it.
* ⚠ **A spec ambiguity found by the driver, not yet resolved:** D0 named **both** 0216 and
  0650 as cases a binary field cannot state, but D1 stamped 0216 with `scope=` and 0650
  with `super=0655`. Both readings are defensible — 0650's titular sink was deferred *out
  of* it into 0655, which is arguably supersession of a part rather than a scope
  restriction. **The spec does not say which applies when**, and that is how a field gets
  used inconsistently and then discarded as noise. Sent to BC2 as a spec question; **no
  stamp is to be rewritten over it.**

**Two defects in the new machinery, deliberately left for a follow-up:**

1. ⚠ **`istamp::format_stamp` omits `scope=`.** A round-trip **silently drops the one field
   that stops 0216 and 0650 being closed wrongly** — and the round-trip fixture carries no
   scope, so nothing catches it. The field D0 identified as essential is the field the
   formatter forgets.
2. **Spec §8's `open=` counts are wrong twice**, measured: **0442 → 1** (two of three
   still-open items are fixed) and **0650 → 5** (0655 plus 0654/0659/0660/0661; only 0658
   moved).

### ⭐ BC1 — the convention, and requirement 4 DISSOLVED rather than met

Spec: `doc/claude/specs/issue_stamp.md`. One physical line, column 0, first 12 lines:

```
**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`
```

* `claim=` is **six-valued** — `partial` and `latent` carry 0891 and **the missing
  "claims latent, is live" cell** A3 identified.
* **`fix=superseded` requires `super=`** — that is the 0442 rule, mechanised.
* `open=` is the outstanding count; optional **`scope=`** expresses 0216 and 0650.
* **The stamp is the file's newest word; prose that disagrees, above or below, is
  history.** That single rule answers the below-the-fold problem — A1's 0071 §3/§4/§4b,
  D0's 0249 with its resolution 306 lines down, and the **510** both-words files — without
  rewriting a line of anyone's prose.

⚠ **Requirement 4 was DISSOLVED, not satisfied, and this is the batch's best piece of
design.** The driver demanded the convention be *cheap to re-stamp*, because `PLAN.md:3`'s
tree citation rotted within the hour. BC1's answer: **`tree=` means "last checked against
this revision" — a statement about the PAST, which cannot rot, only age.** There is no
re-stamping treadmill because nothing ever becomes false. `tree=HEAD` is recorded as an
explicitly **rejected** design, because it *is* the `PLAN.md:3` failure mechanised.
**Demonstrated accidentally: HEAD moved seven times during BC1's task and nothing stamped
broke.**

**The checker.** `tests/headless/issue_stamp.tcl`, with `test_issue_stamp.tcl` (**39
checks**) and `issue_stamp_baseline.txt`. Green on all three arms. **Deliberately NOT
registered in T1** — `full_audit.sh:430` discovers `test_*.tcl` by `ls`, so it joins the
audit merely by existing; registering moves the case count **84 → 85** and forces an edit
to CLAUDE.md's arithmetic block, and BC1 judged *a crew is the wrong author for that*.
Correct call, and left to the driver.

**Four red classes, `rc=1`, then `rc=0` on the same corpus repaired:**

```
9996:5: states this assertion is BROKEN, but it now HOLDS -- the defect appears FIXED
        and the issue was never closed
9997:5: states this assertion HOLDS and it does not (8 hits for SABOTAGE under src)
9998:   tree=deadbee does not resolve to a commit in this repo
9999:   a NEW issue file with no **STAMP:** line
```

**9997 is the free red and it is live** — issue 1219, at `cf5f8dd7`. And the
`state=broken` → now-holds arm is **a mechanical STALE-FIXED detector**, the class measured
at **7 of 40**. Non-vacuous because `gate` self-tests **16 fixtures in both directions**
first — **BC1 adopted the lesson D0 taught the driver**, unprompted.

**BC1 re-measured five things and found them wrong**, the first being its own:

1. ⚠ **Its own checker produced a plausible red for the wrong reason.** `init` called
   `[info script]` at call time, so **every** `rev_exists` returned false. Caught **only
   because it tested a SHA it knew was good.** Row S20 locks it. *Exactly* the
   known-answer discipline, catching a defect in the tool built to enforce it.
2. ⚠ **`closescan.py` flagged 0818 as closed by `tests/headless/issue_stamp.tcl` — a file
   twenty minutes old** — from the phrase *"3 of 3 still **resolved**; and exactly one —
   **issue 0818**"*. **An independent second instance of the over-firing recorded as error
   10**, found without knowledge of D0's. Two crews, two corpora, same defect.
3. The worked example **refuted BC1's own grammar**: 0442 has no other number to name,
   hence `super=self`.
4. `tests/` carries **1190** `file:line` citations, not the driver's 1189.
5. The baseline's first cut was **1048 for 1047 files** — number **0443** has an artefact
   and no issue file.

**The driver's `937` citations across `27` `src/` files is confirmed EXACT.**

### D0 (the 7 stale closures) — 3 header rewrites and 1 child table, not 7

Read-only against `63a1b41f`. The headline is error 10 above; these are the verdicts.

| issue | verdict | finding |
|---|---|---|
| **0249** | **CONFIRMED-CLOSED** | the only true member. **Its own `# RESOLUTION — FIXED` sits 306 lines below a header that still says OPEN** |
| **0216** | **PARTIALLY-CLOSED** | `wviewer::attach_raw`'s whole body has no `rawhist_push`; the push is in `results::select`, reached by the Location bar and `wviewer::restore` — **not** the ASE re-run path, which is what the issue is about. `src/results.tcl` says so itself: *"Converting that path is NOT this item."* |
| **0650** | **PARTIALLY-CLOSED** | the general channel landed (`5dd68128`, `xschem::notify` + 4 sinks); **the titular session-window sink did not** — 0655 reads `OPEN (deferred out of issue 0650 deliberately)` |
| **0071** | **NOT-CLOSED**, header correct | deliverable is the **child table**: 5 stale rows, §4b's six mutators are **five done**, and its *"11 checks"* is now **79** |
| **0264** | **NOT-CLOSED**, header correct | `hierarchy_modified()` still loops `[0, currsch)`, ancestors only; the `had_unsaved` guard never landed |
| **0516** | **NOT-CLOSED**, header correct | `calc::session_result` still walks viewer tokens only. **The ruling happened, the implementation did not** |
| **0947** | **NOT-CLOSED**, header correct | `ase::sim_entry_kind` still returns `badvar` on a frozen `varok 0`; `0947` appears nowhere in `src/` or `tests/headless/` |

**A binary open/closed schema cannot express 0216 or 0650**, and D0 rates their **scope**
lines — *"for this path"*, *"this issue's actual title"* — as the precise fact a reader
needs. That is two concrete cases for BC1's three-value requirement, and without a scope
field both get closed wrongly by whoever tidies next.

**Below-the-fold, third independent sighting.** 0249's resolution is 306 lines down; 0071's
truth is in its child tables; A1 found the same in 0071's §3/§4/§4b. **The truth is in the
file — just never where anyone looks.**

**D1 resized: 3 header rewrites + 1 child table.** The four correct headers are marked
**do not touch**, with an optional tree stamp only.

### A3 (files 21–30) — the citation split, and 0905's account of its own fix

`TRUE-OPEN 4 · TRUE-FIXED 4 · STALE-FIXED 2 · ROTTED-CITE 6 · UNKNOWN 0` — and A3 says it
**distrusts its own zero**, because this draw happened to name readable symbols. Counts,
not a rate.

**The measurement that decided the design (see D8):** 5 files citing bare `file:line` →
**5 of 5 rotted**. 1 file citing line **plus a revision** (0818) → **4 of 4 reproduced**
via `git show fadb226d:`. 3 files citing **symbolically** (0945, 1344, 0896) → **3 of 3
held**. *"The least ceremonious files survived intact."*

**0905 — the subject is genuinely fixed; the file's account of its own fix is
substantially stale.** `32dff39a`, the commit that *replaced* the design 0905 describes,
appears **zero times** in it. §1 still says the second run *"refuses loudly and exits 2
writing nothing"* — `exit 2` is gone. **§3 is the dangerous one**: it records the
per-pid-log shape as *"considered and deliberately NOT taken"* when that is exactly what
shipped, as a **copy**, which was 0905's own stated objection to it. **A reader in good
faith is told not to build the thing the tree already runs.** Its other half —
*"`banner_rule.tcl` is unchanged"* — is **still true** (136 lines, zero `T1-RUN`), so a
blanket `STALE-FIXED` would over-claim. One file, three sections, three different truth
values.

**The OOM loop has a measured origin and a live residue.** 0905 is where the phrase enters,
and it was never a measurement — it was *"a documented event"*, an appeal to a document
that does not exist. Both ends now carry in-place corrections that cross-reference
correctly. **The uncorrected residue is `0432:82`**, which asserts the **event**, not
merely the figure — *"(this box OOMs on concurrent builds, ~7.8 GB)"* — with no correction
attached. That one still reads as live.

**A free red for C1:** the sabotage protocol's own `grep -rn SABOTAGE src/ # must be
empty` returns **8** on a clean tree. That is issue **1219**'s subject, and it is live.
A3 also refuted 1219's own numbers — *"60 lines / 28 files"* is **118 / 44** — in the
direction that **strengthens** the issue.

### A4 (files 31–40) — corrections land outside the issue file

`TRUE-FIXED 5 · TRUE-OPEN 3 · STALE-FIXED 3 · ROTTED-CITE 4 · DUPLICATE 1 · UNKNOWN 1 ·
**BAD-FIX 0 · STALE-OPEN 0**`. Six of ten carry a defect verdict; **three have a status
line that alone sends the reader the wrong way.**

**The finding that most changes C1: corrections land *outside* the issue file, two times
in three.** 1436's refutation lives in the **suite**; 1395's in `ase_window.tcl:9435`;
1439's *"Fixes issue 1438"* never propagated back to 1438. **A checker confined to
`doc/claude/issues/` misses two of three** — and on this sample the source comments cite
*more* accurately than the tracker does.

**Both `STALE-FIXED` files share one mechanical pattern, and it is detectable:** filed as
A, fixed later under number B, B's header names A, **A is never updated**. Grep for *"Fixes
issue N"* / *"Supersedes N"* and check N's header. 1439→1438 is a worked example sitting
in the tree right now. **This is the concrete detector for sub-problem 2** (nothing closes
an issue when the thing is fixed).

**1458 is a `DUPLICATE` of 1397 — and names 1397 in its own `Related:` line while
duplicating it.** So **cross-reference presence is not duplicate detection**, and a
checker must not assume it is. The defect is **live and was reproduced today**:
`~/.xschem/geometry` mtime **2026-09-17 09:08** against `recent_files` frozen at
**2026-09-13 18:53**. A4 recommends merging 1458 and 1397 to one number — a D1 item.

**1436 answered without running T1, and it is a trap for C1.** The rows sit in `hcases`
(`run_regression.tcl:76`), **not** `dcases` — the driver's own comment at `:172` says *"⚠
THEY GO IN `hcases`, NOT HERE."* So a **green T1 and a red display-arm row are
consistent**. ⚠ **C1 must not assert "no open issue may claim a red row while T1 is
green"**: it would false-red the one file in this sample that is careful about exactly
that distinction. The *"two rows"* count is nonetheless stale — the suite itself at
`:407-411` records that only G2sens reds.

## Wrong recorded beliefs caught in this batch

The last batch's tally was twenty, *"every one caught by re-measuring rather than
re-reading."* Same table here, same discipline.

| # | belief | who held it | what measurement said |
|---|---|---|---|
| 1 | *"1050 issue files explicitly call themselves a duplicate"* | **the driver** | **7.** There are only 1047 numbered files, so 1050 was impossible on its face and the driver published it anyway. Cause: `/usr/bin/grep -lieE 'duplicate of…'` — in a bundled short-option string **`-e` consumes the rest as its pattern**, so the command searched for the literal letter `E` and matched every file. Proved by experiment: `grep -lieE 'zzz-no-such-pattern-zzz'` also returns **1050**. **A plausible number from a silently broken command** — the same shape as the fossil `results.log` that reads exactly like a clean sweep. |
| 2 | *"69 citations in the tracker are demonstrably wrong"* | **the driver** | **Near zero.** `citescan.py` resolved 3751 `file:line` citations across 620 files and labelled 69 "missing", but the samples are `outitf.c`, `rawfile.c`, `tfanal.c`, `inp2dot.c` (**ngspice**), `libio/iovsprintf.c`, `debug/fortify_fail.c` (**glibc**) and `tcltk/tk8.6/entry.tcl` (**system Tk**) — legitimate citations into **external source trees**, counted as rot because the scanner only knew this repo. Same false-positive class as `pgrep -af` self-matching: **a pattern matched against the wrong namespace.** |
| 3 | *"the tracker's citations rot at 85%"* | **the driver** | **Unmeasured, and not measurable this way.** `quotescan.py` checked 20 quoted numbered source lines and called 17 mismatches, but 16 are the heuristic (*"nearest filename mentioned above"*) grabbing **SPICE decks, netlist listings and `results.log` excerpts** that happen to carry line numbers inside fenced blocks. **Exactly one was genuine** — see the finding below. The lesson is not a rate; it is that **retrospective rot detection cannot be done by heuristic**, which is a Stage C input. |

| 4 | *"only 1 issue file in 1047 states the tree it was measured against"* | **the driver** | **Wrong, and by the same mechanism as 1–3.** 1477, 1478 and 1479 visibly open with *"measured in the tree at `aa0e2213`"* — the driver had **read them in this session** and still published a census that excluded them. **Two** causes, both in one command: the phrase **hard-wraps across a newline** (`measured in` ⏎ `the tree at`) so a **line**-oriented grep cannot match it, and inside **single** quotes the `` \` `` escapes became a literal backslash-backtick, so the SHA alternation matched nothing either. |
| 5 | *"193 of 508 git SHAs cited in issue files do not resolve"* | **the driver** | **Not SHAs.** The regex `[0-9a-f]{8,40}` matches any 8-digit **decimal** number, so the non-resolving list is led by `16091816` (the box's `MemTotal` **in kB**, from the RAM correction), `141592654` (**π**), `12405346`, `1286397804`, `0000001e`. A SHA-ish token must contain at least one `a`–`f`. |

| 6 | *"issue **0663** is the guard suite that was **writing** `~/.xschem/geometry`, and its ruling was isolate-not-prune"* | **the driver**, in **A4's own dispatch brief** | **0663 is not about geometry at all.** It is *"a Tcl error in any file sourced late by `xschem.tcl` SEGFAULTS startup"*, fixed in C on 2026-08-24. `/usr/bin/grep -c geometry` on it returns **0**. There is no geometry-writing guard suite in it and no isolate-not-prune ruling. **The real sibling of 1458 is 1397**, filed four days earlier, citing the same proc at the same line. |

| 7 | *"the user's 190 `rule` debts are largely internal engineering misfiled as theirs — the three cleared on 2026-09-17 were the tip of an iceberg"* | **the driver**, and it was said **to the user**, in the answer that opened this batch | **153 of 190 (81%) are genuinely THEIRS.** E1's triage: THEIRS **153** · MINE **24** · STALE **11** · UNKNOWN **2**. The filter does **not** dissolve the queue. Its problem is **shape, not validity** — 48 of the 153 are *one repeated request* (ratify a batch's new on-screen wording), already batched under ⚖ R9 and then filed one entry at a time over weeks. |
| 8 | *"`SUPERSEDED` appears in ~15 hits across ~13 files"* | the driver, `PLAN.md` baseline table | **26 hits across 19 files** (A1 re-measured). A1 confirmed 1047 and 742. |

| 9 | *"`status.md` names **77** issue numbers (7.4% coverage), **61%** of them already fixed, and **4** name no file"* | **the driver** | **26 issues (2.5%), 42% fixed, 0 orphans.** `\b[0-9]{4}\b` matched **years, pixel widths and byte counts**: `1855` is *"731–1855 px"*, `2026` is a date, `4096` is *"a 4096-byte action-log line"*, `0521` is *"the next one is 0521"*. **51 of the 77 were not issue references.** The finding got **sharper** — the index covers 2.5%, not 7.4% — but three published figures were wrong. |

| 10 | *"165 issue numbers are claimed closed; **7** still have an OPEN header; **4.3%**"* — sent to BC1 as a design input and queued as D1's work list | **the driver**, `tools/closescan.py` | **4 of the 7 are FALSE POSITIVES. The real class is 1 in 165 — 0.6%.** D0 verified all seven against the tree. **Acting on the driver's table would have marked two genuinely open defects closed, one of them carrying a live user ruling.** |

| 11 | *"the collection step was skipped — 48 debts were filed one at a time where there should have been one document"* (D11) | **the driver** | **The collection was made on 2026-09-13 and never handed over.** `ase_analyses_batch/R9_COPY_REVIEW.md`: 11,364 lines, 821 blocks from 38 issues, already grouped by surface, **36 of the 48 already in it**. The defect is a missing **handover**, not a missing collection — **worse**, because the work was done twice and delivered zero times. |
| 12 | *"resolve each entry to `doc/claude/issues/NNNN-*.md` for the real text"* — the **method** in E2's dispatch brief | **the driver** | **Following it literally produces a document of superseded drafts.** The review itself records: *"The issue files could not be the source… several quote a draft that was superseded before the commit landed."* E2 **inverted** the instruction — review for the 36, issue file for the 9, `src/ase.tcl` where the issue only *describes* (1439's sentences exist nowhere else). |

⚠ **Error 12 is the SEVENTH prescribed fix in this project's record that would have damaged
working code, and the THIRD written by the driver** — after the harness batch's dispatch
brief and error 10's closure table. **All three were written into a crew's instructions**,
which is the most dangerous place for one, because a crew that obeys has no reason to
doubt. **Both crews refused and said why.** That refusal is the single most valuable
behaviour in this operating model, and it has now paid out three times.

| 13 | `LEDGER.md` **cited `tools/stampscan.py` three minutes before that file existed** | **the driver** | Found by BC1. **A rotted citation, written into the batch about rotted citations, pointing at a tool built to detect them** — and it rotted *forward*, naming something not yet real rather than something since moved. |
| 14 | *"`tests/` holds 1189 `file:line` citations"* | the driver | **1190** (BC1). The companion `937` across `27` `src/` files is **confirmed exact**. |

**Driver verification of E2 — what was checked, and what was NOT.** Recorded with the gap
visible, because an unlabelled unverified number is how this corpus got into trouble.

**Verified:**
* the collection **exists** and was added by `07922d71`, **2026-09-13** (see N1);
* **35 commits** touch it, carrying it **291 → 821 strings** to 2026-09-16;
* its **structure is exactly as E2 described** — 130 headings, front matter *"What this
  is / How it was built, and why the strings can be trusted / How to answer / What is
  deliberately NOT here"*, then themed sections grouped by surface (`A1 — Shouted words in
  the middle of a sentence`, `A2 — Acronyms shipped lowercase in pickers`, `A3 — Internal
  slot names shown where the form shows a label`…).

⚠ **NOT verified: E2's "36 of the 48 are already in it."** The driver's extraction pulled
**17** candidate ids where ~48 were expected, so **the scanner's guard refused to report a
rate** rather than publish one off a bad parse — the both-directions discipline working on
the driver's own tooling for the second time. **The fault is in the driver's regex** (it
was band-restricted to 1200–1500), **not in E2's claim**, and the figure is neither
confirmed nor refuted here.

**Error 11 does not rest on it.** Its core — the collection existed, was actively
maintained, and was never handed over — stands on the three verified facts above.

⚠ **E2's date was verified and is CORRECT — the driver's check was the sloppy one.** E2 said
the collection *"has existed since 2026-09-13"*. The driver first ran `git log -1 -- <path>`,
which returns the **newest** commit touching a file rather than the first, and labelled the
answer *"first committed: 2026-09-16"*. Re-run with `--diff-filter=A`: the ADD commit is
**`07922d71`, 2026-09-13**, *"the R9 copy review — 291 strings, grouped by where they are
seen."* **E2 was right; the driver's label was wrong** — caught before it reached a commit
message, which is the first time tonight a driver error was stopped at the door rather than
published and withdrawn.

⚠ **And the correction makes error 11 WORSE, not better. `git log -- <path>` counts 35
commits touching that file**, carrying it from **291 strings to 821** between 2026-09-13
and 2026-09-16. It was not forgotten in a corner. **It was actively maintained for three
days, right up to the day before this batch opened, and still never put in front of the
user** — while `owed.sh` went on accruing one debt per stage for the very strings it
already held. Non-delivery here was not neglect; it was sustained, diligent work with no
handover step at the end of it.

⚠ **Error 11 names the tracker's real disease, and it is not ignorance.** 0229 is the fix
for citation rot — **written down, never built.** `R9_COPY_REVIEW.md` is the wording
collection — **built, never delivered.** A defect was filed five times in seven weeks and
attempted zero times. **The corpus does not fail to know things. It fails to deliver what
it knows**, and no status field, convention or checker addresses that.

⚠ **Error 10 is the most dangerous of the ten, and it is the batch's own subject in the
first person.** A *"stored fix that would damage working code"* is the exact class this
batch was convened to study. The driver produced one, handed it to BC1 as evidence, and
queued it as D1's work list. **It would have been the seventh.** It was caught only because
D0 was dispatched to verify the seven rather than repair them (D12) — the same
measure-before-acting discipline as D1 and D4, paying out a second time.

**How the regex was blind, all three found by printing the MATCHED TEXT rather than the
location** — the location says *where* a claim lives and is silent on *what it says*:

| shape | what the text actually reads | why v1 matched |
|---|---|---|
| **negation** (0264, 0516) | *"FILED, **not** closed: issue 0516"*, *"filed, **not fixed** … issue 0264"* | the pattern allows a 40-character gap between verb and number — **the negation sits inside the gap** |
| **attribution** (0071 ×6) | `**Status:** CLOSED 2026-07-14 (issue 0071 atom 6)` | this closes **0003**; 0071 is being **credited as the fixer** |
| **prescription** (0947, 0650) | *"…and fixes 0947 at the same time"* | 0946's **unimplemented option 3**. A proposal is not an event |

⚠ **And the method lesson, which outlives the number: `closescan.py`'s self-test asserted
only a TRUE POSITIVE.** It proved the check *fires*; it could never prove the check does
not **over-fire**. **A self-test needs a known negative as well as a known positive** — and
an over-firing checker on a 1047-file corpus is worse than none, because it gets disabled,
which is D9's whole argument. `tools/closescan2.py` adds the three filters and asserts
**both directions** using D0's verified verdicts as fixtures (`0249` must flag; `0071`,
`0264`, `0516`, `0947` must not). **On first run it FAILED and refused to print a rate** —
0516 and 0947 are now correctly suppressed, 0071 and 0264 still leak. That refusal is the
tool working. v1 would have published.

⚠ **The corpus-wide 165 / 154 / 7 is therefore WITHDRAWN**, not merely qualified.

**`closescan2.py` now PASSES both directions, and here is the honest number.** It needed a
**fifth** and **sixth** filter that neither the driver nor D0 anticipated — found the same
way, by printing the matched text:

> **BLEED — the verb belongs to a DIFFERENT issue number.**
> `issue 0055 (locate arg, FIXED); umbrella 0071` — the verb is **0055's**, and the
> 40-character gap merely scooped up the next number along.
> `docs(issues): 0244 FIXED write-up, and file 0264-0267` — the verb is **0244's**; 0264 is
> a *filing* announcement. Neither carries a negation, a parenthesis or a proposal word, so
> all three of D0's filters passed them through.

Rules added: a claim cannot survive a `;` or `)` between its verb and its number, and **a
4-digit number immediately before the verb owns that verb**.

| | v1 (`closescan.py`) | v2 (`closescan2.py`, both-direction self-test) |
|---|---|---|
| claims accepted | 165 | **173** |
| header agrees | 154 | 157 |
| **header still OPEN** | **7** | **6** |
| no issue file | 4 | 10 |
| **rate** | **4.3%** ⚠ withdrawn | **3.7%** (6/163) |
| claims **rejected** by filter | 0 | **542** — negation 176, attribution 166, bleed-sep 96, prescription 65, bleed-owner 39 |

**542 rejected claims.** The unfiltered scan was roughly three-quarters noise, and it read
as a clean, plausible result.

**The six that survive**, three of them already D0-verified:

| issue | claimed closed by | D0 verdict |
|---|---|---|
| `0249` | git log, issue 0366 | **CONFIRMED-CLOSED** — genuinely stale header |
| `0216` | git log, `src/wave_viewer.tcl` | **PARTIALLY-CLOSED** — needs a scope, not a close |
| `0650` | issue 0653 | **PARTIALLY-CLOSED** — same |
| `0056` | `tests/headless/test_ase_preflight.tcl` | **not yet verified** |
| `0885` | git log | **not yet verified** |
| `0897` | issue 0894 | **not yet verified** |

⚠ **Do not repair the last three on the scanner's word.** That is precisely error 10, and
the detector has now been wrong about four of seven once already. They go to D1 as
*candidates to verify*, never as a work list.

⚠ **And note the one number that got WORSE: "claimed closed but no issue file" rose 4 → 10.**
Unexamined. Likely renumbering casualties or another clone's numbers, but that is a guess
and is labelled as one.

⚠ **Error 9 is the ninth instance of one single mistake**, and it is worth naming plainly:
**every driver error tonight was a pattern matched against the wrong namespace.** `-e`
swallowing its pattern; ngspice and glibc paths scored as rot; SPICE decks scored as rotted
quotes; a line-oriented grep against a hard-wrapped phrase; decimal numbers scored as SHAs;
md5 digests scored as git SHAs; a premise requoted from a session summary; and now years
and pixel widths scored as issue numbers. **This is the same defect as `W12b` and
`pgrep -af` from the last batch** — *position, or shape, mistaken for identity* — which is
also the finding this batch just measured about the tracker itself. The corpus and its
auditor have the same disease.

⚠ **Error 7 is the most consequential of the nine, because it is the only one the USER
heard.** It was asserted in the answer that persuaded them to take this batch on. The three
debts cleared that day were real, and generalising from three to 190 is the same move as
generalising six *selected* bad fixes into a rate — **the error this batch was designed to
avoid, committed by the driver in the act of proposing it.**

⚠ **Error 6 is the batch's subject happening to the batch.** The driver took a belief from
**its own compacted summary of a previous session**, did not re-measure it, and wrote it
into a crew's instructions as fact — which is precisely how a defect gets filed five times
in seven weeks. It is the same shape as the last batch's *"0609's containment pins T1's
cwd to `$REPO`"*, where the driver also reasoned from its own summary rather than the
document. **A4 checked it and refused it**, which is the behaviour `CREW_BRIEF.md` rule 10
asks for, and it was contained to one brief only because A4 looked.

| 21 | *"`scope=` appears exactly ONCE in the entire corpus"* — sent to BC2 to size its work | **the driver** | **Three hits across two files.** 0216's stamp, plus **two ngspice PROBE log lines inside 0307** (`PROBE-5 entry: model='dcell' … scope=…`). **The conclusion was right — exactly one is a STAMP, blast radius one file — but the stated measurement grepped prose.** Same family as `pgrep -af` answering four for one run. Verified by the driver: 3 raw hits, 1 stamp. |
| 22 | spec §8: *"the table below has been corrected to match"* — **with the table not corrected** | **BC2** (self-reported) | Caught only by grepping the rows back out of the artefact. **A document asserting a correction it never made** — this batch's disease with a crew's name on it. Both rows fixed and read back. |

| 20 | *"**54** of the 71 `look` debts were filed on a single day, 2026-09-10"* — used to justify E3's whole framing, and written into its brief | **the driver** | **That is a file MTIME, not a filing date.** 53 of the 71 share the identical mtime `2026-09-10 12:18:38` — **the `repo:` stamping pass**, which CLAUDE.md independently measures complete at 12:40. Real filing dates spread over **14 days**, peaking at **25 on 2026-09-05**; 09-10 holds **6**. Eight days summed and attributed to the last. Two further claims fall with it: it was **three** batches on **two clones**, not one, and the ratio is not E2's (71→27 groups *screens*; 48→16 de-duplicates *one question*). |

⚠ **Error 20 is the twentieth instance of the same mistake and the most on-the-nose: the
driver read a PROXY for the thing.** An mtime is not a filing date, exactly as a line number
is not an identity, a decimal is not a SHA, and a year is not an issue number. **This is
the defect the batch measured in the corpus, committed by its auditor twenty times in one
evening** — and E2 independently recorded the same shape in its own work, calling it the
fifth instance in this project.

| 15 | **row `B1` of `test_issue_stamp.tcl` asserted the baseline covers every file** — which forbids the adoption its own receipt prescribes | **BC1** | Green **only because zero files were stamped**. **A vacuous green inside the file written to prevent vacuous greens**, sitting on the path D13 was about to register in T1. Found and fixed by D1, with a known-negative row added. |
| 16 | **`issue_stamp_baseline.txt` left untracked** while checker, suite and spec were committed | **the driver** | A fresh clone's gate refuses with `BASELINE MISSING`. The driver excluded it on purpose (D1 was mid-edit) and then **did not put it back**. A correct precaution with no follow-through — the same *non-delivery* shape as error 11. |
| 17 | *"0442 contains the phrase «a hand-maintained mirror of another module's rules is wrong by construction»"* — quoted to D1 in its brief | **the driver** | It is in **`src/op_annot.tcl`**, not 0442. Requoted from A2's receipt without opening the file. |
| 18 | spec §4: *"the tree deleted `op_annot::_netlisted`"* | **BC1** | It is **live**; its *shape* was deleted. |
| 19 | spec §8's `open=` worked examples | **BC1** | **0442 is 1**, not as written; **0650 is 5**. Both re-measured by D1. |

⚠ **Error 15 is the most valuable catch of the batch**, because it was **not** in the
corpus being studied — it was in **the machinery built to study it**, and it was on the
critical path. A checker that cannot be adopted without reddening is worse than no checker,
and it would have reddened T1 at the gate, against the one baseline this project treats as
sacred.

### Near-misses — driver errors caught BEFORE publication

Recorded separately from the numbered errors, because the difference is the whole
improvement. Errors 1–14 were **published and then withdrawn**. These were stopped at the
door by checking a suspicious number instead of repeating it.

| | claim | what checking found |
|---|---|---|
| N1 | *"`R9_COPY_REVIEW.md` was first committed 2026-09-16"*, contradicting E2's 09-13 | **E2 was right.** `git log -1 -- <path>` returns the **newest** commit touching a file, not the first. `--diff-filter=A` gives `07922d71`, **2026-09-13**. Re-checking also produced the sharper finding: **35 commits**, 291 → 821 strings, maintained to the day before this batch and still never handed over. |
| N2 | *"BC1's suite has 41 checks"*, contradicting BC1's 39 | **BC1 was right.** `/usr/bin/grep -c 'check '` counts any line **containing** the substring — it swept in a prose comment and **`proc check {name got want}`, the definition itself**. Line-anchored: **39**, and 39 again excluding comments. |
| N4 | *"`scratch.tcl` does not pid-qualify, so 191 suites share `.scratch/<tag>` — and ⚖ R4's two-concurrent-T1-runs relaxation is undermined"* | **Refuted by reading it.** `test_scratch` builds `_${tag}_[pid]` — **fully pid-qualified**. `__scratch_sweep` guards **four** ways: globs only `_*_[0-9]*`, skips its own pid, **skips any LIVE pid** (`__scratch_pid_alive`), and enforces a **300 s age floor** against pid reuse. `__scratch_cleanup_all` deletes only `$::__scratch_dirs` and is wired into a **wrapped `exit`** so it fires on `exit 1` and early skips too. **The harness is exemplary; R4 stands.** Nothing published — caught in the same response as the first fragment that suggested it. |
| N3 | *"2 entries in `~/.xschem/recent_files` look like ASE-L probe decks"* — about to be told to the user | **It is 10 of 10, and none is theirs.** The grep counted **lines**; the file is 5 lines and packs all ten entries into two `set` statements (`recentfile` and `tctx::recentfile` mirroring each other). **A proxy for the thing, one paragraph after recording error 20 for exactly that.** Caught before it reached the user. |

**Both are the same defect as errors 1–14 — a pattern matched against the wrong namespace —
and in both the driver's number contradicted a crew's.** The rule that changed the outcome:
**when a measurement disagrees with a crew's, the crew has usually read the artefact and
the driver has usually run a grep.** Check before publishing, and check by tightening the
pattern rather than by re-running the loose one.

## The rule those five errors bought

**Every mechanical check is run first against a case whose answer is already known, and
reports nothing if it fails that.** All five driver errors are one family — *a command
that returns a plausible number without doing what was meant* — and every one was caught
only by a number looking impossible (1050 > 1047) or by reading the samples instead of
the count. This is **red-first applied to measurement**: the last batch's brief demanded
that a test row be observed red before it is trusted, and a grep is a test row.
`tools/stampscan.py` implements it — it asserts 1473/1477/1478/1479 are detected and
`sys.exit(1)`s rather than print a census if they are not.

**This is also the tracker's own disease, reproduced five times in one evening by the
agent auditing it.** The corpus is 1047 confident sentences produced the same way.

## Findings the driver measured directly (2026-09-17, at `8608c7ef`)

**No citation in the tracker points past the end of a file.** `citescan.py`: 3751
distinct `file:line` citations, **PAST-EOF = 0**. So the cheap, mechanical rot check —
does the line exist? — finds **nothing**, and the only rot that matters is the kind where
the citation resolves and the text moved. That is the `+15` shift that produced the last
batch's worst error, and it is **not** computable retrospectively.

**The one genuine rotted quote is perfect.** Issue **0229**, whose title is *"comment
line number citations in `callback.c` are stale"*, cites `src/callback.c:2990` as
`int wire_label_try_commit(void)`; the tree at that line says `} else {`. **An issue
about stale line citations whose own line citation went stale.** (0229 is in A1's
sample — the crew's independent verdict is the check on this one.)

**Self-declared refiling: 11 files.** 9 say *"filed four times"*, 2 say *"filed five
times"*. Only **7** files say *"duplicate of NNNN"* at all, against **101** that use the
word "duplicate" somewhere — so the tracker records refiling in prose far more often than
in any form a reader or a tool could act on.

**The cross-clone number collision is not visible today, and that does NOT retire it.**
Both clones hold an identical set of **1048** numbers; **zero** unique to either side and
**zero** `15xx` in op-wcard, despite `1500–1599` being reserved for it. Reason measured:
`/home/analog/dev/xschem-op-wcard` is checked out on **`fluid-editing`** — *this* branch —
at `875ae443`, a commit from the last batch. It is currently a second checkout of our own
branch, not a second line of work. **The hazard is parked, not removed**: one `git
checkout` in that tree restores it. Read this the way CLAUDE.md reads the empty
`/usr/local/bin` — the absence of the collision today is a fact about where a clone
happens to be sitting, not about the numbering rule.
