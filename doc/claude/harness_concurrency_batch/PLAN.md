# Harness concurrency batch — PLAN

> ## ⚠ THIS IS THE PLAN **AS WRITTEN** (2026-09-16). IT WAS SUBSTANTIALLY REFUTED.
>
> Read it as the record of what was believed at batch start — **not as a description of
> what was built.** Almost every substantive claim below has since been measured, and
> several were refuted outright: the shape it proposed, the minimum fix it called "pure
> win", and the premise the whole design rested on.
>
> * **What actually happened → `LEDGER.md`.** **Why the shape changed → `DECISIONS.md`.**
> * **The stage table stops at `E3`.** Everything from `R1-recon` onward — the second
>   pass, which is where this plan was overturned — exists only in `LEDGER.md`.
> * **Nothing here is deleted.** Corrections are added inline, marked ⚠ and dated,
>   quoting what the text used to claim. A plan quietly rewritten to match its own outcome
>   would destroy the most valuable thing this batch produced: the record of how often a
>   confident written plan was wrong. `LEDGER.md` counts **fourteen** wrong recorded
>   beliefs, and this file is the origin of several of them.
>
> **The one-line summary of what changed:** the plan proposed that **the second run
> waits**. The user rejected that framing — *"Why not make it fault-tolerant and find a way
> for both runs to proceed? Innovation and progress are about having one's cake and eating
> it."* — and was right. **Both runs now proceed; nobody waits and nobody is refused.**

**Subject.** Two concurrent `tclsh run_regression.tcl` runs in one tree corrupt each
other in four distinct ways. Filed five times across seven weeks (0384, 0867, 0990,
0955, 0905) and **never once attempted** — `git log --all --grep` over both clones
returns nothing. Two further faces were reproduced on 2026-09-16 and are unfiled.

⚠ **"Four distinct ways" is an UNDERCOUNT, measured 2026-09-17 by `R1-recon`.** The four
faces below are real and all four were closed, but the enumeration was never complete. A
full T1 writes **88 fixed-name files** under `tests/`, of which **83 are verdict inputs**.
Face 4 was then reproduced **one file upstream** in `<hc>.log`, scored with the tree's own
`banner_rule.tcl`, wrong in *both* directions — silently counting run A's **two real
failures as 0**, and inventing a failure the passing run did not earn. Also shared:
`<tc>.log` ×3, `<dc>.disp.log` ×11, `tests/results/.actionlogs`, `~/.xschem/` (**19 T1
suites do not source `scratch.tcl`**) and the display. The faces are a list of *sightings*,
not a partition of the defect.

## The measured evidence (do not re-derive it)

⚠ **THE HEADING IS THIS BATCH'S OWN CAUTIONARY TALE, 2026-09-17.** *"Do not re-derive it"*
is the exact instruction the batch spent a night disproving. The very first crew (`A1`)
re-derived the next claim in this file and found it a **no-op** (see "A1's corrections"
below); `R1-recon` re-derived the driver's stated premise and found it false; `ram-figure`
re-derived a hardware figure six documents rested on and found it wrong by **2×**. The
standing rule that came out of this batch is the opposite of this heading: **take every
measurable fact from the machine, never from a sentence** — including facts that feel like
background rather than measurements. The pre-fix pair table immediately below is the one
block that has *survived* re-measurement, and `DECISIONS.md` ⚖ R4 leans on it by name.

Measured 2026-09-16 at HEAD, 20-core box, in-tree `src/xschem`:

| run | result |
|---|---|
| `open_close.tcl` **solo** | 34 s, rc 0, 1898 result files, **0 FATAL** |
| two runs, **3 s** apart | A: **407** phantom `FATAL … exit -1` · B: **died**, rc 1 |
| two runs, **6 s** apart | A: **432** phantom · B: **died**, rc 1 |
| two runs, **9 s** apart | A: **757** phantom · B: **died**, rc 1 |

Solo T1 baseline, same night: `rc=0`, **410 s (6m50s)**, `Start=83 / Finish=83`,
82 `Total num fail:` lines, **ZERO counted failures**, `results.log` mtime moved
(1789603761 → 1789624370, so not a fossil). **T1 is at its zero baseline; any red
after this batch is ours.**

⚠ **FOUR OF THAT PARAGRAPH'S FIVE CLAIMS ARE NOW WRONG. Corrected 2026-09-17.**

* **`Start=83 / Finish=83`, 82 lines → the tree runs 84 cases / 83 lines.** Not a
  mistake: **this batch caused it**, by registering
  `headless/test_regression_concurrency_1476` in `hcases`
  (`run_regression.tcl:93`, working tree at `873cce32`). The danger is that the old
  number stayed *plausible* — which is the same trap CLAUDE.md records twice over.
* **The counting rule it uses is itself holed**, and both holes were found here.
  **Issue 1481:** the NODISPLAY path `continue`s before its `Finish` line, so a box
  with no dev display prints **84 `Start` / 73 `Finish`** — the rule that exists
  *because* two passes miscounted is wrong on that arm. And `wc -l` answers **171**
  (`2 + 83 + 83 + 3`), not 83, 84, or the "85" that was briefly written down.
* **"mtime moved … so not a fossil" is RETIRED.** mtime only ever proved a run
  *wrote*; issue **1477** is that every prefix of a green run reads as a green run.
  **Read the `T1-RUN-END` trailer** — it names the pid, the case count and the counted
  failures, so a fossil and a truncation are both self-identifying. A green verdict is
  also **no longer byte-deterministic** (the sentinels carry a pid and a timestamp), so
  the md5 comparison that accompanied this rule is retired too.
* **410 s was never re-measured, and nobody may write that this batch made T1
  faster.** V1 measured 374.6 s, V2 375.0 s, V4 375 s solo — but all three refused to
  attribute it, on an uncontrolled box, one run each. The honest statement is that
  adding the 1476 suite **did not make T1 measurably slower**; that is the only
  comparison these runs support.
* ⚠ **"Any red after this batch is ours" is FALSE, and believing it costs a night.**
  V4's **uncontended** back-to-back baseline returned **3 counted failures** in
  `test_ase_optier_0963` (ngspice `rc=1`, `raw=-1bytes`, `NORAW`); the standalone
  re-run was `ALL PASS (109 checks)`. A flake. V3's red was **machine state**, not
  code. **A T1 red must be diagnosed by case** — it is not by itself evidence of a
  collision, and after a batch that taught everyone to suspect collisions this needs
  saying out loud.

A reproduction cycle is ~70 s and needs ONE case, not a whole regression. Issue
0990's claim that a row "would have to run two regressions at once, which is
expensive" is **wrong** and must not be inherited.

## The four faces

1. **Phantom FATALs** in whichever run collates. `$workroot` is a fixed path
   (`open_close.tcl:38`, `create_save.tcl:32`, `netlisting.tcl:38`); run A deletes
   it at its `:108`/`:100`/`:131` while run B is still reading; `read_job_status`
   (`test_utility.tcl:118-125`) scores a missing status file `-1`; the caller turns
   every `-1` into a counted `FATAL … exit -1`. Described by 0384/0867/0990.
2. **The second run dies at startup, with no verdict at all.** `file delete -force
   $testname/results` (`open_close.tcl:32`) fails — `error deleting
   "open_close/results": file already exists` — because the other run is creating
   files inside it mid-walk. rc 1, no banner, no `Total num fail:` line. **Recorded
   in no issue file.** Worse than face 1: face 1 screams, face 2 vanishes, and the
   driver counts lines that are *there*.
3. **Silent result-file loss in the cleanup phase.** `cleanup_debug_files`
   (`test_utility.tcl:102-114`) `catch`es its `xargs … awk`, so files the other run
   deleted produce `awk: … cannot open file` on stderr and are **never counted**.
   Observed 1, 5 and 6 files lost in the three pairs. **Recorded in no issue file.**
4. **Phantom PASS via the verdict file.** `run_regression.tcl:295` is
   `set log_fn "results.log"` and `:381` opens it mode `w` — fixed name, truncate,
   no lock. A run can report ZERO having verified nothing. Filed as 0955 (which
   calls itself "Sibling of issue 0867 … the same collision in a different file and
   in the opposite direction") and 0905. **This is the dangerous direction** — faces
   1–3 are loud, face 4 is silent, and it lands in the one file CLAUDE.md calls
   "THE ONLY PLACE THE ANSWER IS".

⚠ **Face 4's citations rotted, and the replacement is not a lock (2026-09-17).** The
mechanism described was real and is closed, but `:295`/`:381` name nothing now. In the
working tree at `873cce32`, `run_regression.tcl:353-354` reads:

```tcl
set log_fn     "results.log"          ;# canonical: the most recent COMPLETED run
set run_log_fn "results.[pid].log"    ;# this run's own answer, never shared
```

and the `open … w` is at `:693`, on `$run_log_fn` — **a name no other run can hold.** The
fixed name is no longer truncated by anybody; it is *copied* to at the end
(`:951`). ⚠ **And `results.log` may therefore not be your answer**: during a concurrent
run it can hold a verdict that is complete, well-formed and **someone else's**. Your
answer is `tests/results.<pid>.log`, and the `T1-RUN-BEGIN` header names the pid that
wrote whatever you are reading.

## The shape being built (ruling R1, see DECISIONS.md)

* **Scratch is made parallel-safe.** `$workroot` gets the pid scope the runner
  already uses one file away (`test_utility.tcl:82`, `.parallel_jobs.[pid]`).
  Nobody reads scratch after a run, so this is pure win.
* **The verdict is serialised.** `results.log` keeps its canonical name — `crew.js`,
  CLAUDE.md and the user all read that exact filename — and `run_regression.tcl`
  takes a lock so the second run is told plainly to wait rather than silently
  truncating it.

## ⚠ THE SHAPE ABOVE IS GONE. BOTH HALVES. Corrected 2026-09-17.

**This section is the single most misleading thing in this file**, because it is the part
a reader would act on. Neither bullet survived.

**The scratch half was a measured NO-OP.** This plan called pid-scoping `$workroot` "pure
win". `A1` measured that exact expression — `"$testname/results/.work.[pid]"` — and got
**658** phantom FATALs against today's **660**. The shared object is `$testname/results`
*itself*, which every run wipes at startup, so pid-scoping a directory **inside** the
thing that gets wiped changes nothing. The table is in "A1's corrections" below; the
amendment is in `DECISIONS.md`. What shipped instead: the workroot moves **out** of
`results/`, each case works in a private `<case>/results.<pid>` with scratch in
`<case>/.work.<pid>`, and the result is published back to the canonical name at the end.

**The verdict half was overturned by the user, on the framing.** ⚖ R1 as filed offered a
lock (the second run waits or refuses) against per-run roots. The user rejected the
question:

> *"Why not make it fault-tolerant and find a way for both runs to proceed? Innovation
> and progress are about having one's cake and eating it."*

They were right, and the constraint the entire choice rested on turned out to be a
**filename convention, not a property of the system.** Three things followed, in order,
and the middle one lasted only hours:

1. **`C1` built the lock** (`43b40f04`) — and first measured that *"the second run
   **waits**"*, the option as literally worded, is the **data-losing** one: a run that
   queues politely and then truncates leaves `results.log` holding **0** of the first
   run's four blocks. So what shipped was refusal by default, waiting opt-in, and the
   waiting path *preserving* the prior verdict.
2. **The refusal era is exactly datable and lasted hours** — `43b40f04` introduced it,
   `32dff39a` removed it, **both 2026-09-17**. A transcript from that window is the only
   place `exit 2` was ever real. ⚠ Any doc still teaching "a second run is refused, rc 2"
   is quoting a state of the tree that existed for part of one day.
3. **`R1-build` shipped "both runs proceed"** (`32dff39a`). From the working tree at
   `873cce32`, `run_regression.tcl:677`:

   ```tcl
     puts "  BOTH RUNS PROCEED. Nobody waits and nobody is refused (ruling R1)."
   ```

   The lock survives, demoted to a safety net bracketing **one file copy** instead of a
   whole run. Refusal and `exit 2` are **deleted**.

⚠ **AND THE PREMISE THE NEW SHAPE WAS ARGUED FROM WAS ALSO FALSE — the driver's own.**
`DECISIONS.md` asserted, on the day the decision was taken, that *"the only single-slot
object left was the name `tests/results.log`"*. `R1-recon` measured **88 fixed-name
files**, **83 of them verdict inputs**. **The lock protected 1 of 88.** Inherited from a
receipt instead of measured — the batch's fourteenth wrong recorded belief, written into
the decision record by the person writing the rule against doing that.

**The sentinels turned out to be worth more than the concurrency fix.** `T1-RUN-BEGIN` /
`T1-RUN-END` close two recorded traps no amount of locking touches — the **fossil** (a
stale verdict reads as a perfect clean sweep) and **1477's truncation hole** (every prefix
of a green run is itself a green run; 4096-byte full buffering against a 4785-byte verdict
makes a **0-byte** file the typical kill outcome). The load-bearing line is
`fconfigure $fd -buffering line`, without which the header — the half that says *whose*
answer a file is — does not survive a kill.

## Stages — ONE TASK PER CREW, dispatched serially

⚠ **Crews are dispatched one at a time on purpose.** Until this batch lands, two
crews running suites at once reproduce the very defect under repair, and the loser's
numbers are void. Nobody runs a suite while another crew is running one.

⚠ **THIS RULE WAS RIGHT FOR A REASON THAT WAS NEVER MEASURED — ⚖ R4, 2026-09-17.**
`ram-figure` found that **six documents** justified serialisation by citing a "~7.8 GB
box" that **does not exist**: `MemTotal` is 16091816 kB ≈ **15.35 GiB**, roughly double,
with 4 GiB of untouched swap. The OOM chain behind it is assertions citing each other —
1477 cites 0905, 0905 calls it *"a documented event"*, the ledgers say *"the recorded OOM
path"* — and **nothing at the end of that chain is a measurement**; `dmesg` shows **zero**
OOM kills. "7.8 GB" first appears **2026-08-07, in a session prompt**, spread by copying
for five weeks, and reached CLAUDE.md on the same day the driver reasoned from it. **Nobody
ever ran `free`.**

The rule nonetheless held, on its **real** basis: the pre-fix pairs corrupted each other
**407/432/757** times and the loser died outright. That has nothing to do with RAM.

✅ **R4 was then RELAXED on measurement, 2026-09-17** — V4 produced the first measured
clean concurrent pair, and `W12b` closed the last gate. **Two caveats stand:** concurrent
`make`, and the `ngspice` and display arms, are **unmeasured by anyone**; and a T1 red must
still be diagnosed *by case*. Note also that the relaxation is a statement about the
harness, not about this batch's own dispatch queue — `LEDGER.md` still serialises the
remaining suite work, because that queue is a constraint, not a priority order.

⚠ **Memory pressure was never the issue.** V4: peak **10328 MiB concurrent against 10350
MiB solo** — concurrency added **nothing**. Swap 0 throughout, OOM kills 0 before and
after. There is still **no receipt anywhere** for the event six documents once cited.

| id | task | files | acceptance |
|---|---|---|---|
| **A1** | the RED suite | new `tests/headless/test_regression_concurrency_1476.tcl` | rows RED on today's tree, for all four faces; source-text rows in the idiom of `test_suite_watchdog_1403.tcl` W14–W19 (`has_text`), behavioural rows bounded by `timeout` |
| **B1** | faces 1–3: scratch | `open_close.tcl:32,38`, `create_save.tcl:28,32`, `netlisting.tcl:32,38`, `test_utility.tcl:118-125` + its 3 callers, **and `test_utility.tcl:102-114`** | A1's face-1/2/3 rows go GREEN; a missing status file is reported as missing, not as `exit -1`; see ⚠ A1 below — the workroot must move **out of** `results/`, and face 2 needs the startup wipe, not the workroot |
| **C1** | face 4: verdict lock | `run_regression.tcl` (~`:295`, `:381`) | A1's face-4 rows go GREEN; second run waits or refuses **loudly**; `results.log` keeps its name |
| **D1** | docs | new `doc/claude/issues/1476-*.md`; close 0384, 0867, 0990, 0955, 0905; `NUMBERING.md` | 1476 records faces 2+3; the five are closed with pointers; NUMBERING records 1476 and corrects the stale 1332 bullet |
| **V1** | verification | — | solo T1, reported per CLAUDE.md's reading rules (mtime moved, Start/Finish pairs, per-case zero) |
| **E1** | companion: 0805 + 0802 | `tests/headless/full_audit.sh:211-212`, `:311-325`; `test_audit_classifier.tcl` | one bundle — 0805's own text says land them together |
| **E2** | companion: 0408(a) | `tests/headless/test_label_ride.tcl:548,550-552,839` | part (a) ONLY; part (b) is unexplained and out of scope |
| **E3** | companion: 1332-residual | `tests/headless/test_ase_bus_bits_0159.tcl:277,285` | poll, don't widen the delay; recipe at `test_rdw_keys_1245.tcl:2243,2279` |

### ⚠ Corrections to the table above, 2026-09-17

* **`C1`'s acceptance — "second run waits or refuses **loudly**" — is doubly wrong.**
  `C1` itself corrected the first half before building: *"waiting and then truncating
  loses the first run's verdict just as surely as the race does"*. Then R1 was retaken and
  **the second half went too**: nothing waits, nothing refuses, and `results.log` keeps its
  name by being *copied* to, not by being locked. Acceptance as built: both runs proceed,
  each verdict self-identifying via its sentinels.
* **`V1`'s acceptance cites three reading rules and all three are now retired or holed** —
  "mtime moved" (superseded by the trailer; see the measured-evidence correction above),
  "`Start`/`Finish` pairs" (issue **1481**, under-counts by 11 on a no-display box), and
  "per-case zero" (still right, and still the standard — but a red is diagnosed by case,
  since an uncontended run produced a flake).
* **`B1`'s file list was right about the files and wrong about the fix.** The workroot had
  to move **out of** `results/`, not merely gain a pid — and face 2 turned out to be a
  property of the **startup wipe**, fixed there.
* **The stage table ends here; the batch did not.** A second pass — `R1-recon`,
  `R2-R3-design`, `0060-comment`, `ram-figure`, `R1-build`, `claude-md`, `R3-build`,
  `R2-build`, `save-citations`, `V4`, `W12b`, `claude-md-2` — is recorded only in
  `LEDGER.md`, and it is where this plan was overturned.
* ⚠ **Six prescribed fixes in this batch would have changed WORKING code if pasted** —
  0867, 0990, 0805, 0609, 1478, **and one written by the driver**. Four of the six are
  issue files whose "the fix, when it is taken" section ships a no-op or a regression.
  **A written prescription is a hypothesis.**

**Explicitly out of scope:** 1232 (edits `run_regression.tcl:27` — the file C1 owns;
schedule after, never beside), 1455/1290, 1346, 0396/0368.

**Verified already fixed, do not touch:** 1332 (`Status: FIXED` 2026-09-05), 0994
(`FIXED 2026-08-30`). The scan also reported 0642 and 0645 as stale; **unverified by
the driver** — check before believing.

⚠ **"Verified already fixed" was not verified, and 1332 proves it (2026-09-17).** The
sentence contradicts this very file: stage **E3** above is *"1332-residual"*. A
`Status: FIXED` banner is a claim about part of an issue, not about the issue. E3 found
the residual live, fixed it — and found that **1332's own citation `:258` was wrong,
repeated three times, pointing at nothing**; this PLAN's `:277,285` was the correct pair.
**Trust a re-survey over an issue file's own line numbers.**

**The last clause — *"check before believing"* — is the only instruction in this section
that aged well, and it was vindicated twice over.** `ram-figure` checked two machine facts
nobody had thought to doubt and found **`/usr/bin/xfwm4` does not exist** (introduced,
unmeasured, by a commit titled *"correct the AUDIT_WM claim"* — one WM fact corrected and
a second invented in the same breath) and **`/usr/local/bin/xschem` does not exist
either**. The never-a-bare-`xschem` rule was **strengthened** rather than relaxed on that
finding: one `make install` restores the hazard, and all that has changed is that the
failure is now loud instead of silent.

## ⚠ A1's corrections — measured, and they invalidate part of this plan

> ⚠ **"Part" was generous, and this section is the plan's own first refutation
> (appended 2026-09-17).** A1 was the **first** crew dispatched, and it came back having
> measured the plan's stated minimum into a no-op before any code was written. Everything
> below stands as A1 wrote it. What it could not yet see is that the *other* half of the
> shape — the verdict lock — would be overturned as well, by the user and then by
> measurement: see "THE SHAPE ABOVE IS GONE" above. **The pattern worth taking from this
> section is not its content but its timing:** the plan was wrong at crew #1, and the way
> that was discovered was by re-deriving a number the plan said not to re-derive.

**The shape this PLAN called the minimum is a no-op.** A1 measured three
configurations of one staggered pair:

| workroot | run A | run B |
|---|---|---|
| `"$testname/results/.work"` (today) | **660** phantoms | died at startup |
| `"$testname/results/.work.[pid]"` — *this PLAN's stated minimum* | **658** phantoms | died at startup |
| `"$testname/.work.[pid]"` (outside `results/`) | **0** phantoms | died at startup, 2 of 3 |

The shared object is **`$testname/results` itself**, which every run wipes at startup
(`open_close.tcl:32`, `create_save.tcl:28`, `netlisting.tcl:32`). Pid-scoping a
directory *inside* the thing that gets wiped changes nothing. Moving the workroot out
closes face 1 and leaves face 2 flaky — **face 2 is a property of the startup wipe and
must be fixed there.**

**Face 1 is mis-attributed above.** The end-of-run delete at `:108` is not the culprit
in practice: run B died at startup and never reached it, yet run A still lost 639–670
status files to B's partially-completed *startup* wipe.

**Face 4 is an erasure, not a corruption.** 13268 bytes, zero NUL bytes, run A's
verdict complete — run B's verdict simply never appears while B exits 0. Rows keyed on
corruption or interleaving ship GREEN and prove nothing; A1 had two such rows in its
first draft and rekeyed them.

**Face 3 needs no concurrency and is wider than stated.** gawk's "cannot open file" is
**fatal**, so one missing file aborts the entire `xargs -n 64` batch — the *present*
files in that batch are left un-normalised too. Reproducible in two awk spawns, no
collision required. `test_utility.tcl:102-114` joins B1's file list.

## Issue number

**1476** — mint-checked 2026-09-16: outside every reserved band, no file in either
clone (`~/dev/xschem-claude`, `~/dev/xschem-op-wcard`), no reservation anywhere but
this clone's own `next free number` line.

⚠ **One number became six (2026-09-17).** The plan budgeted a single issue; the batch filed
**1476–1481**, because looking properly at a defect kept finding defects that were in no
file at all: **1477** (a killed run's truncated verdict reads as a clean sweep), **1478**
(per-case log names unqualified, protected only by a fail-open lock), **1479**
(infrastructure exit codes counted as ordinary failures), **1480** (nothing sweeps the
untitled residue, and neither audit driver leaves a log that could attribute it), **1481**
(the NODISPLAY arm skips its `Finish` line — the hole in the counting rule this batch
relied on). Five prior filings were closed with pointers.

## ⚠ The defect class this batch actually found — and it is not in the plan

**A COUNT IS NOT AN IDENTITY.** It appeared **three times**, in three unrelated places,
and nobody was looking for it:

1. **`C11`** compared counts of repo-root litter, so it false-redded on **foreign**
   litter and — measured, not inferred — passed `ALL PASS`, rc 0, **while its own suite
   was writing the leak**, because under T1 its cwd is `tests/` and it read the repo root.
   Simultaneously too sensitive and completely blind.
2. **0609's own supplied fix code** for that row compared counts too (a `.sym`→`.sch` swap
   scores clean), and watched only `$repo`. Only the *idea* — snapshot at suite start —
   survived; both halves of the code were discarded.
3. **`W12b`** globbed `/tmp/xschem_emergencysave_*`, **a global namespace with no pid in
   the name**, and compared counts — so the other run's killed children reddened the one
   suite whose baseline is ZERO.

⚠ **And for `/tmp`, even a set difference was insufficient** — the lesson that outlives the
batch. `C11`'s set difference works because its producer set is **bounded and local**;
`/tmp` has no bounded producer, so a foreign corpse is "new" too. The fix took **identity**:
the child announces `EMERGENCY SAVE DIR: <path>` on its way out (`src/main.c:45-52`), and
the row asserts on what its *own* child said. It then survived a deliberate **48-corpse
foreign flood green** while still redding with a named path on a real leak.

**The same finding, in prose, about this very batch.** A line number is a position in a
shared namespace. Four independent passes described a sentence none of them had read, each
citing a coordinate that was **correct against the tree it had read** while a live crew's
`+15`-line edit shifted everything below it; the driver then committed a message accusing
everyone of citing without reading — **in a message lecturing a crew about exactly that** —
and ordered a revert (`git checkout HEAD --`) that **would have destroyed the fix**. The
crew refused, and was right. ⚠ **If an instruction from the driver would discard work you
have measured as correct, say so and do not comply.** That refusal is the behaviour this
batch most wants to keep. The rule: **a citation needs a tree state, not just a line.**
