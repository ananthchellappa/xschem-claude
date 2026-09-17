# 61 — ⚖ R7 reversed: the PSS evidence is preserved and Stage 14 is closed unbuilt

**Task:** write-only, two files. The user ruled **2026-09-16** that Stage 14 is **not to be built**
(*"don't build it, write up the issue"*). Write the issue that preserves everything measured, and
mark the ruling in the plan. **No code, no tests, no simulator.**

**Delivered:**

| file | state | lines |
|---|---|---|
| `doc/claude/issues/1475-pss-declared-everywhere-working-nowhere.md` | **new** | **282** |
| `doc/claude/ase_analyses_batch/PLAN.md` | edited — **one hunk**, at the Stage 14 heading | +38 / −3 (file now 4636) |
| `doc/claude/ase_analyses_batch/receipts/61-r7-reversed-pss-not-built.md` | this file | — |

---

## VERDICT TABLE

| # | question | answer |
|---|---|---|
| 1 | all 12 required points written into 1475? | **yes**, §1–§12 in the brief's order |
| 2 | every factual claim traced to one of the two evidence files, named inline? | **yes for the measurements** — tagged **[2BIN]** / **[ARGC]** in the text. **Nine claim-groups are NOT from them** and every one says so in the file itself; §1 below lists them |
| 3 | did I invent a measurement? | **no** — nothing was run; the only arithmetic is two derivations, both declared (§1c) |
| 4 | did I round differently from the evidence? | **no** — `3857280067`, `3.758894068e9`, `4.590456891e6`, `0.81 s`, `0.41 s`, `0.46 %`, `4.5 %`, rc `0`/`1`/`124`/`139` all as written there |
| 5 | places `PLAN.md` §14 / `APPENDIX` §2.12 / `DECISIONS.md` contradict the evidence | **seven**, quoted in §2 — `PLAN.md` named as the stale one in the issue's own closing table |
| 6 | anything in the brief wrong against the evidence? | **no contradiction; two refinements** — §3 |
| 7 | did I touch anything outside the two files? | **no.** Three other files are modified in this tree and **none of them is mine** — §5 |

---

## 1 — Claims in 1475 I could NOT trace to the two evidence files

The brief required these listed explicitly. **The issue file marks each of them in place**, so a
reader of 1475 is never left guessing which sentence rests on what. Grouped by source:

### (a) From `src/ase.tcl` and `R9_COPY_REVIEW.md` — the whole of §9

§9 opens with ⚠ *"Not from the evidence files — read from `src/ase.tcl` at the tree this was filed
against."* Everything under it:

| claim | where I read it |
|---|---|
| the `pss` registry entry, quoted verbatim | `src/ase.tcl:27342-27344` |
| `registered 1` = "the GUI offers the type at all"; `baseline 0` = `#ifdef`-gated | the key contract comment, `src/ase.tcl` ~`:4727-4737`; the adapter's own *"`baseline 0` for `sp` and `pss`"* comment ~`:26538` |
| the grid cell is `blocked`/`unrenderable` | `ase::analysis_state` ~`:10450`, and the *"four `ok/baseline` and seven `blocked/unrenderable`"* comment above it |
| *"ASE-L cannot set up pss yet, so it is listed but cannot be enabled."* | `ase::analysis_state_msg`, `unrenderable` arm ~`:10512` |
| *"This pss analysis is not one this simulator can set up."* | `ase::analysis_refusal_frames` ~`:5509-5513` composing `ase::analysis_emit_msg unrenderable` ~`:5480` |
| the string is ratified copy, handles `R9-065` and `R9-160`, one literal behind both | `R9_COPY_REVIEW.md:1862-1873` and `:3208-3218` — `R9-065`'s note spells the framed sentence out with `pss` as its own example |

### (b) From the batch's ruling record and from the task brief — §11, and the ruling line in §Status

| claim | source | ⚠ |
|---|---|---|
| ⚖ R7 answered 2026-09-13, Option A, user's words *"follow your recommendation"* | `DECISIONS.md` ⚖ R7 | — |
| the ratified recommendation's four parts (last / *experimental* / transient+FFT / `oscnode`) | `DECISIONS.md` ⚖ R7 | — |
| **the user's 2026-09-16 words — *"don't build it, write up the issue"* and *"I have never run PSS"*** | **the task brief only** | ⚠ **I have no independent source for these.** They are the driver's report of a conversation I was not in. They are **corroborated** by the driver's own concurrent edits to `DECISIONS.md`, `LEDGER.md` and `NUMBERING.md` (§5), which quote the same two sentences — but that is the same witness twice, not a second one |
| *"the user answered by delegating instead"* (what the 2026-09-13 ruling left open) | `LEDGER.md` ~`:624` | — |

### (c) Derived by me from the evidence, not stated in it

Two, both arithmetic over **[2BIN]**'s own numbers, and both flagged in the text as what they are:

1. **The 15 / 2 / 3 / 0 breakdown of the twenty 45.2 runs** in §1. **[2BIN]** states *"twenty cases,
   zero convergences"* as prose (*the example plus nineteen perturbations*); the split into fifteen
   `Convergence not reached`, two rc-1 aborts and three timeouts is **my count of its table rows**.
   I put the table in precisely so the number is checkable rather than quotable — a reader can
   re-count it in ninety seconds. ⚠ **If it is wrong, the headline "zero convergences" is still
   right**; only the breakdown moves.
2. **"about 2.6 % high"** — `3857280067 / 3.758894068e9 − 1 = 0.02618`. The brief gave the same
   figure; I recomputed it rather than copying it.

### (d) Framing language, mine, carrying no measurement

* *"the silent-wrong-answer class"* — the batch's own term for this failure shape; the underlying
  sentence (*rc 0 with plausible-looking data*) is `DECISIONS.md` ⚖ R7's trade-off line.
* §8's *"The choice was between offering it to everyone and offering it to nobody"* — my inference
  from **[2BIN]**'s two stated facts (identical `help pss`; no behaviour-pruning), not a quotation.
* §10's reopening condition — **stated in the file as a recommendation**, with the fact it rests on
  (`668329ca3` in no release tag) tagged **[2BIN]**.
* §11's closing lesson (*ask whether the thing is used before refining the estimate of what it
  costs*) — editorial, and marked as a note for the next ruling rather than as a finding.

### (e) Read in the documents by me, to check the evidence's claim about them

**[2BIN]** asserts *"`PLAN.md` §14 and APPENDIX §2.12 say scrape stdout"*. I verified both rather
than relaying it: `PLAN.md` §14 says it **twice** (*"The panel scrapes stdout for the verdict
string"*, and again in *Files and procs*: *"scrapes **ngspice's own stdout strings**"*), and
`APPENDIX_ngspice_analyses.md:1345` says *"A GUI must scrape stdout for these and must refuse to
present a PSS result without one."* **The evidence file was right.**

**How I checked that nothing else is unsourced:** I walked 1475 section by section against the two
evidence files with both open, and every sentence that survived is either tagged, or sits under a
heading that declares its source, or appears above. The declared-source headings are the mechanism —
§9 and §11 are *entirely* non-evidence and say so in their first line, which is why they are not
itemised sentence by sentence here.

---

## 2 — Where `PLAN.md` §14, `APPENDIX` §2.12 and `DECISIONS.md` contradict the evidence

Quoted, with the evidence beside each. **All seven are in `PLAN.md`/`APPENDIX`/`DECISIONS.md`; none
is in the two evidence files, and the issue names `PLAN.md` as the stale one.** Four of the seven
are in 1475's closing table; all seven are here.

**1. The stream.** `PLAN.md` §14:

> **rc is not a success signal.** `Convergence not reached` returns **rc 0** … **The panel scrapes
> stdout for the verdict string.**

**[2BIN]**: *"45.2 writes the verdict, and every progress line, to STDERR. … `PLAN.md` §14 and
APPENDIX §2.12 say 'scrape stdout', which finds nothing on 45.2."*

**2. The same sentence in the appendix.** `APPENDIX` §2.12:

> **A GUI must scrape stdout for these and must refuse to present a PSS result without one.**

Same refutation.

**3. The `steady_coeff` floor.** `PLAN.md` §14's refusal table:

> | `steady_coeff < 1e-6` | 1e-9 gave a **false** `Convergence reached` **4.5 % wrong** |

— so **1e-6 is allowed**. **[2BIN]**: `steady_coeff 1e-6` → *"⚠ **124 at 60 s**"* on the fork, and
its §3 says so in words: *"`steady_coeff = 1e-6` is allowed by the plan and did not finish in 60 s."*

**4. The `fguess` bias.** `PLAN.md` §14:

> | `fguess` biased **high** | 2.1× high aborts; 19× low converged. **Bias the default low.** |

**[2BIN]**: `fguess 200meg (19× low)` → *"⚠ **not reached**, rel 1 (scratch build: reached)"* — the
evidence file even names the disagreement's cause in the same cell.

**5. `oscnode`.** `PLAN.md` §14:

> **`oscnode` steers nothing.** A nonexistent `oscnode` runs normally with no NULL deref. The field
> stays … its hint says *"ngspice records this and never reads it."*

**[2BIN]** §4: true among **real** nodes; *"**but a name that is not a node moves the answer**
(3.7415e9 against 3.7589e9, 0.46 %)"*. ⚠ **The stale half is the half that was going on screen as a
hint**, which is why 1475 gives it a section rather than a row.

**6. The appendix's parameter table, same defect.** `APPENDIX` §2.12 row 3:

> | `oscnode` | … | **nothing** | **it steers nothing** — assigned at `dcpss.c:126` and never read.
> … label it *(not used by the solver)* |

— refuse column *nothing*, and a label telling the user the field is inert. Same refutation as 5.

**7. `DECISIONS.md` ⚖ R7, as it stood when this task started:**

> **So the ruling stands and its implementation gains a hard requirement:** the panel ships, and the
> emitter **never writes a `pss` card with fewer than five arguments** …

The ruling does not stand. ⚠ **The driver rewrote the head of that block while I was writing**
(§5), so this contradiction is **already closed in the tree** — recorded here because the receipt is
the record of what the state was, and because the *second* half of that sentence (the five-argument
requirement) remains a correct and now-unowned finding, preserved in 1475 §5.

**And one evidence-vs-evidence disagreement, where the newer measurement wins.** `builds.md` §1.7
records that the per-iteration `Shooting cycle iteration number: …` line *"is inside `#ifdef
PSSDEBUG`, which is commented out … and defined nowhere"*. **[2BIN]**: *"45.2's stderr also carries
the `Shooting cycle iteration number: … || rr: … || predsum: …` line that `builds.md` §1.7 said
never prints; on 45.2 it does."* Written into 1475 §3. `builds.md` is **not** one of my two sources
and I did **not** edit it.

**Also stale, and left alone deliberately:** `APPENDIX` §2.12's gate row still reads *"**Absent in
this build**; present in `/usr/bin/ngspice` 45.2"*, which predates the 2026-09-10 `--enable-pss`
rebuild of the fork (**[2BIN]** opens by naming that rebuild). 1475's last paragraph says why it is
left: it is the appendix's record of the build it was taken on, and §14's not-built block is where
a reader is now sent.

---

## 3 — Two refinements to the brief. No instruction was wrong.

Nothing in the brief contradicted the evidence. Two items were **narrower than the tree**, and 1475
carries the wider version:

1. **Brief item 9** — *"the analysis is **listed** in the grid and an enabled row answers *'This pss
   analysis is not one this simulator can set up.'*"* Correct, and there are **two** sentences, not
   one: the grid's own status line is `ase::analysis_state_msg`'s **different** string, *"ASE-L
   cannot set up pss yet, so it is listed but cannot be enabled."*, while the ratified R9 sentence
   the brief quotes is what a row that is **enabled anyway** (an older or hand-edited `.state`)
   gets. Both are in 1475 §9, with the distinction stated.
2. **Brief item 1** — *"twenty cases, zero convergences"*. Exactly right. Only **fifteen** of the
   twenty produced a verdict at all: two aborted rc 1 and three ran past the timeout (§1c). Written
   in as a breakdown table so the headline is checkable.

---

## 4 — The exact `git diff --stat` of my changes

**My tracked change, alone:**

```
$ git diff --stat -- doc/claude/ase_analyses_batch/PLAN.md
 doc/claude/ase_analyses_batch/PLAN.md | 41 ++++++++++++++++++++++++++++++++---
 1 file changed, 38 insertions(+), 3 deletions(-)

$ git diff -U0 -- doc/claude/ase_analyses_batch/PLAN.md | grep '^@@'
@@ -3749,3 +3749,38 @@
```

**One hunk, at the Stage 14 heading.** The three deleted lines are the heading and the
`**One commit. Ruling ⚖ R7. Last, deliberately.**` line, both retained struck-through rather than
removed, per the plan's own convention for superseded content (the withdrawn `-b` refusal in *What
this plan refuses*).

**My new file is untracked**, so no `diff --stat` covers it:

```
$ git status --porcelain | grep 1475
?? doc/claude/issues/1475-pss-declared-everywhere-working-nowhere.md      (282 lines)
```

⚠ **The repo-wide `git diff --stat` is NOT mine and must not be read as this task's diff.** It grew
twice while this receipt was being written (§5); as of the final check:

```
 doc/claude/ase_analyses_batch/CREW_BRIEF.md   |   8 +++---     <- the driver's
 doc/claude/ase_analyses_batch/DECISIONS.md    |  30 ++++++-    <- the driver's
 doc/claude/ase_analyses_batch/LEDGER.md       | 140 +++++++++- <- the driver's
 doc/claude/ase_analyses_batch/PLAN.md         |  41 ++++++++-  <- MINE, one hunk
 doc/claude/ase_analyses_batch/RELEASE_NOTE.md |   7 +++--      <- the driver's
 doc/claude/issues/NUMBERING.md                |  16 +++-       <- the driver's
```

**`PLAN.md` is the only tracked file this task touched**, and its diff is the single hunk above.

---

## 5 — ⚠ FIVE files moved under me, and none of them is mine

The same class receipt 59 reported, and **it was still happening as this receipt was written** —
this section said *three* until the final `git status`. `DECISIONS.md`, `LEDGER.md`,
`NUMBERING.md`, `RELEASE_NOTE.md` and `CREW_BRIEF.md` are modified in this tree; **I never invoked
a write on any of them.** Attribution, by mtime against my own pass:

| file | mtime | what it now contains |
|---|---|---|
| `doc/claude/issues/NUMBERING.md` | **21:01:11** | the **1475** block and pointer **1475 → 1476**. The slug matches my filename exactly |
| `DECISIONS.md` | **21:02:37** | ⚖ R7's heading rewritten to *"**REVERSED 2026-09-16. The PSS panel is NOT built.**"*, the 2026-09-13 answer kept in full beneath a divider |
| my issue file | 21:04:08 | — |
| `PLAN.md` | 21:04:30 | my hunk |
| `LEDGER.md` | **21:04:36** | Stage 14's heading now `## Stage 14 — PSS — 🚫 **NOT BUILT**`, plus R7 rows through the document |
| `RELEASE_NOTE.md` | **21:06:10** | +5/−2: PSS's omission from the note is *"**now PERMANENT, not pending**"*, citing the reversal and issue **1475** |
| `CREW_BRIEF.md` | **21:06:13** | +5/−3: the `--enable-pss` fixture sentence loses *"a crew testing Stage 14"* — ⚠ *"there will be no such crew"*, citing issue **1475** |

**Both late arrivals were read and neither contradicts 1475**: they cite the same ruling, the same
date and the same issue number, and both describe the omission of PSS as settled rather than
pending — which is what a not-built stage means for the release note (`LEDGER.md` records that
`WR2`'s red on a PSS mention is therefore *permanent and correct*, not a placeholder).

**Two consequences I acted on:**

* **I re-read `DECISIONS.md` after the driver's edit and corrected two of my own sentences.** Both
  had said the ⚖ R7 block *"stays where it is"*, which was true when I drafted it and reads as
  *untouched* now. 1475 §11 and the `PLAN.md` block both now say the block **carries the reversal at
  its head and keeps the 2026-09-13 answer in full beneath it** — which is what is actually there.
* **`NUMBERING.md` is already filed by the driver, so I did not write it** (the brief names two
  files, and the number was minted before I started). ⚠ **The driver should confirm it is happy with
  its own entry**: I verified only that the number, the slug and the headline figures agree with
  1475.

---

## 6 — Consistency inside `PLAN.md`, checked and deliberately NOT fixed

**Two rows elsewhere in `PLAN.md` still record ⚖ R7 as *ship it***, verified present after my edit:

* `:4228` — the ruling ledger: *"| **R7** | 14 | … | **Yes, last, explicitly experimental**, with
  the hard validator, the stdout verdict scrape …"*
* `:4518` — the sequencing table: *"| 15 | **14** | PSS, experimental, hard validator, stdout
  verdict | +300 | **R7** | new suite |"*

**I did not change either.** They are the record of the 2026-09-13 ruling, my brief scoped me to the
Stage 14 section, and a task that quietly widens its own scope is what this batch's receipts exist
to prevent (issue 1474's own note). **Instead my block names both of them and points a reader who
meets either first back to the reversal.** ⚖ **The driver's call** whether they get a ✅/🚫 marker
in the same commit; a reader arriving at the ruling table with no other context will read *"ship
it"*.

---

## 7 — What I did NOT do

1. **No `src/`, no `tests/`, no build.** Nothing outside `doc/claude/` was written. `src/ase.tcl`
   and `R9_COPY_REVIEW.md` were **read** only.
2. **No ngspice, of any kind, ever.** Not `/usr/bin/ngspice`, not the fork, not a `help pss`, not a
   deck. **Every measurement in 1475 is transcribed from the two evidence files**, which is the
   whole of the task.
3. **No simulation, no bench, no `~/.xschem/`.** Nothing under `sky130A/` was opened.
4. **No `git` write command** — no `add`, `commit`, `checkout`, `restore`, `stash`, `clean`, `push`.
   The driver commits.
5. **No `owed.sh`.** Nothing filed, nothing cleared, `~/.claude/xschem_owed/` not read and not
   written. Debts to report are §8.
6. **`tests/run_regression.tcl` not run** (issue 0990 — T1 is the driver's, solo). **No suite of any
   kind ran**, which is correct: this pass changes no code, so no row can move.
7. **Stage 14 was NOT deleted** from `PLAN.md`, per the brief. It is struck-through, blocked and
   retained in full.
8. **I did not edit** `DECISIONS.md`, `LEDGER.md`, `NUMBERING.md`, `APPENDIX_ngspice_analyses.md`,
   `evidence/pss-two-binaries.md`, `evidence/pss-stage14.md` or `evidence/builds.md`.
9. **No snapshots taken and no sabotage campaign** — there is no code change to sabotage, so there
   is nothing to disarm and no stale restore this crew could ever fire.

---

## 8 — Debts to report upward — nothing filed by me

* **No `rule` debt.** ⚠ **Deliberate, and worth stating**: this pass mints **no new user-facing
  sentence**. `pss` keeps the copy it has, and 1475 §9 records that `R9-065`/`R9-160` are **ratified
  and not reopened**. A not-built stage is the one shape that owes the user no wording.
* **No `look` debt.** Nothing reaches a pixel; the grid looks today exactly as it did yesterday.
* **No `suite` debt.** No suite changed and none is owed.
* ⚖ **For the driver, not for the user:** the two `PLAN.md` rows in §6, and whether `APPENDIX`
  §2.12's parameter table wants a ⚠ pointing at 1475 — its `oscnode` row would otherwise tell the
  next implementer the field is inert (§2 item 6).

## 9 — Hygiene

* **Read-only outside the two files I was told to write**, plus this receipt. Three files show as
  modified and are the **driver's**, with mtimes and content attributed in §5.
* **No processes started**, so none to match or reap; no `pgrep -f`, no `pkill`, no background job,
  no waiting loop — this pass had nothing to wait for.
* **Nothing written to `/tmp`**; no scratch artefacts exist, because nothing was measured.
* ⚠ **If this crew is woken after collection: `git status` and `git log` first.** The driver was
  actively editing three files in this tree during this pass and will have committed since.
