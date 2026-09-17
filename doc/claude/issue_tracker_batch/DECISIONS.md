# Decisions — issue tracker batch

Design decisions taken by the driver, with the reasoning, so a later reader can tell a
choice from an accident. Numbered `D<n>`. User rulings are `⚖ R<n>`.

---

## D1 — Measure before cleaning, on a sample registered in advance

**Decision.** The first stage is a measurement of the tracker's error rate on 40 files
drawn at random with a recorded seed, committed to `SAMPLE.txt` **before any crew reads
one**.

**Why.** The batch that produced this one ended by requoting an unmeasured number — "six
documents" — which turned out to be 18 sites in 14 files, and the error sat in the
opening sentence of ⚖ R4, *the ruling that exists because a number was requoted instead
of measured*. Tonight's six-prescribed-bad-fixes figure has the same weakness in a
different direction: those issues were **selected** because we already suspected them. A
selected sample cannot produce a rate.

**What this forbids.** Quoting a rate off a sample anyone chose, including this one, at
more than one significant figure. n=40 of 1047 is ±15 points at 95%. It separates "rare"
from "endemic" and nothing finer.

---

## D2 — The fix is self-identification, not a prose cleanup

**Decision.** The deliverable is that an issue file **states what it was measured
against**, on the model of T1's `T1-RUN-BEGIN`/`T1-RUN-END` sentinels — not a pass that
rewrites 1047 files into a house style.

**Why.** The harness batch did not make every regression run correct; it made every
verdict say who wrote it and whether it finished, so a reader can tell what they are
holding. That is achievable and it is what was actually missing. "Make the prose true" is
not achievable by anyone and a batch that promised it would become the seventh prescribed
fix that damaged something.

**The measured warrant.** 510 of 1047 files contain **both** fixed-words and open-words
in their first ten lines. A reader cannot triage half the corpus from its own opening.
That is what an issue looks like after someone appends a correction without touching the
header — the documented habit here, and the exact shape of 0609, whose closing ⚠ reported
finished work as outstanding while its body carried the correction.

---

## D3 — A checker, or the cleanup rots

**Decision.** Stage C builds something mechanical that enforces whatever B designs, and
it must be observed **red on a real defect** before it is trusted.

**Why.** Measured 2026-09-17: **nothing** in this repo validates the tracker. Every hit
on `doc/claude/issues` in `*.sh`/`*.tcl`/`*.js`/`Makefile*` is source code citing an
issue number in a comment. 1047 files, 12 MB, zero checks — and the observable result is
a defect filed five times and fixed zero times, and a comment that misdirected readers
for 77 days.

A one-time cleanup against a corpus with no checker regresses to the mean. This project
has the receipts: 0689 was filed four times (0420, 0492, 0629, 0689) and 0690 four times
(0421, 0455, 0491, 0690), eight files, nobody fixing, everybody re-deriving.

---

## D4 — Crews classify in Stage A; they do not edit

**Decision.** Stage A is read-only. Nothing in `doc/claude/issues/` is edited until B has
designed the convention and C can check it.

**Why.** Separating measurement from repair keeps the rate honest. A crew that fixes what
it finds cannot then report what the corpus looked like, and the rate is the one artefact
this batch cannot re-derive later — the tree will have moved.

---

## D5 — The driver does not clear the user's debts; E1 recommends

**Decision.** E1 triages all 190 `rule` debts and produces a recommendation table. It
clears nothing. The user rules.

**Why.** CLAUDE.md is explicit that `rule` and `look` clear **only when the user says
so**, and the reason is recorded: a ledger that discharged an eyeball because a suite went
green would be exactly the defect that rule was written about. A ledger that closed a
*ruling* because an agent judged it internal would be the same defect wearing a tie — and
this batch's whole thesis is that the tracker's confident sentences are unreliable, which
includes the ones this batch writes.

**Backup taken** before any pass touching the ledger, as CLAUDE.md requires:
`~/.claude/xschem_owed_backup_20260917_tracker` — 190 rule, 71 look, 11 suite, 106-line
`cleared.log`. A ruling really was destroyed in place on 2026-09-10 and survived only
because a backup existed.

---

## D6 — Read-only crews run in parallel; the last batch's serial rule does not carry over

**Decision.** A1–A4 and E1 dispatch together.

**Why.** The harness-concurrency brief's rule 4 — *"never run a suite while another crew
is running one"* — was about **suite contention**, and it was correct there because every
crew ran T1. These crews read files. Reading does not contend.

**And the rule it came from was itself relaxed on measurement the same day.** ⚖ R4: two
T1 runs in one tree both proceed, each writing `tests/results.<pid>.log`; concurrency
added **no** measurable peak memory (10328 MiB concurrent against 10350 MiB solo, the
*solo* run peaking highest). The serialisation had been justified in writing for five
weeks by a "~7.8 GB box" and a "recorded OOM path", **neither of which was ever
measured** — the box is 15.35 GiB and `dmesg` carries zero OOM kills.

⚠ **This does not licence concurrent suite runs in Stage C.** C1 runs alone, and says so.

---

## D13 — The checker DOES join T1, but only after D1 lands

**Decision.** BC1 deliberately left `issue_stamp.tcl` unregistered in T1's `hcases` and
flagged it as *"one line for you if you want it."* **The driver wants it.** It is registered
by the driver, after D1 finishes, never before.

**Why register, against BC1's leaning.** BC1's reasoning for abstaining was sound on its own
terms — `full_audit.sh:430` discovers `test_*.tcl` by `ls`, so the checker joins the audit
merely by existing, and registering moves the case count **84 → 85** and forces an edit to
CLAUDE.md's arithmetic block. But `full_audit.sh` **is not the routine gate**; T1 is. A
checker that only a deliberate audit runs is a checker that can be skipped indefinitely —
and **D3's entire thesis is that a one-time cleanup against a corpus with no enforcement
regresses to the mean.** This project has the receipts: 0689 filed four times, 0690 filed
four times, eight files, nobody fixing. An unenforced convention becomes the eleventh.

**Why the driver and not a crew.** BC1 was right that *a crew is the wrong author for that
edit*. CLAUDE.md's `69 + 11 + 3 + 1 = 84` block is **the most error-prone paragraph in the
file** — it records having been wrong **three times**, and the third time was **the
correction itself**, which reached `85` by doing arithmetic on a sentence instead of
running `wc -l` once. Editing it to 85 for real, while that paragraph warns against exactly
this, needs whoever holds the commit.

**Why after D1, not now.** Registering mid-repair would put a checker into T1 while D1 is
part-way through stamping nine files. A malformed intermediate stamp would redden T1 — and
**T1's baseline is ZERO, where a standing red is a defect, not furniture.** The first T1 run
that includes this checker must be one where it is green on a finished corpus. F1 runs that.

⚠ **Note the shape of the case-count change, because it is a trap this file has already
sprung.** 84 → 85 alters `hcases` **entries** (69 → 70), the `Start`/`Finish` pair count,
and `T1-RUN-END`'s `cases=`. It does **not** alter the `Total num fail:` line count the same
way, and `wc -l` on a green verdict moves by its own arithmetic. **Take every number from
the artefact after the change — including `wc -l` — and never by adding one to a
remembered figure.**

---

## D12 — D0 is pipelined ahead of D1, and E3 is deliberately held behind E2

**Decision.** Two scheduling calls, opposite in direction, recorded because a driver that
serialises or parallelises its crews is making a choice of its own and ought to say so at
the moment of making it.

**D0 runs NOW, ahead of the stage it feeds.** The 7 stale-closure issues (`0071`, `0216`,
`0249`, `0264`, `0516`, `0650`, `0947`) are the one D1 work-item that is **exactly known**
— produced by a self-testing detector with no judgement calls — so verifying them does not
need BC1's convention, only the truth about the tree. Doing it in parallel means D1 can
act the moment BC1 lands instead of starting its longest lookup from cold. D0 is read-only
and **proposes** replacement text rather than applying it, precisely so it cannot pre-empt
the convention it will be written in.

**E3 is HELD, though nothing technical blocks it.** The 71 `look` debts have the same shape
defect as the 48 wording ratifications — **54 of the 71 were filed on a single day** — and
the same remedy. Dispatching it now would produce a **second user-facing consolidation
document in a different format**, invented in parallel by a crew that could not see E2's.
Two rival formats for one user is worse than one format arriving later. **E3 inherits E2's
shape.**

⚠ **Note these two are not the same judgement applied twice.** D0 is parallelised because
its input is already certain; E3 is serialised because its *output* must match something
that does not exist yet. The test is not "can this run now" but **"does running it now
commit us to something we would have to undo"**.

---

## D10 — The plan is re-scoped by its own measurement, and the wrong version is kept

**Decision.** `PLAN.md`'s sub-problem 1 (*"a stored fix is an unverified hypothesis"*) is
demoted from headline to secondary. **Citation rot becomes the batch's primary target.**
The mis-scoped text stays in the file with the correction above it; nothing is deleted.

**Why demoted.** The plan was built on the last batch's **six prescribed fixes that would
have damaged working code**. Across 40 pre-registered random files: `BAD-FIX` **1**,
`STALE-OPEN` **0**, `ROTTED-CITE` **27**. The six were a **selected** sample — we went
looking at issues we already suspected — and generalising them into a rate is the precise
error `D1` exists to prevent. **The mechanism caught its own author.**

**Why not deleted.** Three reasons, and the third is the real one.

1. The last batch's rule: *"the plan as written, corrected in place and not one line
   deleted"* (`f669af14`).
2. A plan that is silently rewritten to match its results cannot be audited, and stops
   being evidence that the measurement mattered.
3. **This is the batch's proof that pre-registration works.** A reader who finds only the
   corrected plan learns nothing; a reader who finds both learns that a confident,
   evidence-backed, six-example scoping was **wrong by an order of magnitude**, and that
   40 random files were enough to show it. That is the argument for doing this again.

**Why `BAD-FIX 1` is nonetheless an undercount.** A1 declined to score 0296 and 0435
`BAD-FIX` although both quote C that no longer exists **and still looks like valid C** —
*"correct by reference, damaging by paste."* The class is real and rarer than assumed, not
absent. Requirement: a stored fix must still record **which option was taken**.

---

## D11 — The user's queue is triaged but not touched, and the 48 collapse first

⚠ **CORRECTED BY E2, 2026-09-17. The premise below is wrong in one word, and the
correction is worse news than the original.** This decision says the collection step *was
skipped*. **It was not.** `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md` has existed
since **2026-09-13**: 11,364 lines, **821 handle blocks / 825 handle ids, drawn from 38
issues, already grouped by surface**, opening with *"all of them in one place, so they can
be read once instead of nineteen times."* **36 of the 48 were already in it.**

⚠⚠ **AND E3 SHOWS THIS CORRECTION IS ITSELF TOO SHALLOW.** A look-debt collection also
existed — `doc/claude/lookdebt_batch/`, committed 2026-09-07, 46 debts with question /
right / wrong / recipe each — **and its own brief says it WAS published.** It changed
nothing anyway: 8 of its 10 retire recommendations sat in the queue ten days later, it was
never maintained (46 → 71, 36 of today's absent), and it cannot be rebuilt because its page
builder reads a `shots/` directory nobody committed.

**So the lesson is not "collect, then hand over" either. Nothing re-points a collection at
a queue that keeps growing.** A handover is an **event**; the queue is a **process**. One
collection was never delivered and one was delivered and decayed, and the outcome was the
same. **This batch built a convention and a checker for the tracker's contents; it has
built nothing for this, and that is the honest limit of what it achieved.**

**So the defect is not a missing collection. It is a missing HANDOVER** — the document was
built, was correct, and was never put in front of the user, so debts went on being filed
one per stage beside a finished artefact that already contained them. That is strictly
worse than never collecting: the work was done twice and delivered zero times, and it is
the same disease as issue **0229** (the fix for citation rot, written down and unbuilt) and
as the five-filings-zero-fixes pattern. **The tracker's characteristic failure is not
ignorance. It is non-delivery.**

**Decision.** E1's triage stands as a **recommendation**; the driver clears nothing (`D5`).
The first thing put to the user is not the 24 misfiled entries but the **48 that are one
repeated question**.

**Why.** E1 measured **153 of 190 (81%) THEIRS** — the filter does not dissolve the queue,
and the driver's claim that it would was wrong (ledger error 7). But **48 of those 153 are
a single request**: *ratify this batch's new on-screen wording*, already explicitly batched
under **⚖ R9** and then filed **one entry at a time over weeks**. The user is looking at 48
queue items where there is **one** decision.

That is a **shape** defect, and it is the one the user actually experiences. Collapsing it
is worth more than any of the other 141 entries individually, and it is the standing
label-ratification exception working as intended: **collect the sentences into one
reviewable document, then work through it one question at a time** — never ask in bulk.

---

## D8 — B and C merge into one crew, because A decided the design

**Decision.** `PLAN.md` separates **B1** (design the convention) from **C1** (build the
checker). They dispatch as **one** crew, `BC1`. Recorded here at the moment of departing,
not discovered later in an audit.

**Why.** B1's question was *what should the convention be*, and three independent
measurements answered it before B1 could be dispatched:

| evidence | source | result |
|---|---|---|
| bare `file:line` citations | A3, 5 files | **5 of 5 rotted** |
| `file:line` **plus a revision** | A3, 0818 | **4 of 4 reproduced** via `git show fadb226d:` |
| **symbolic** citations (name, not position) | A3, 0945/1344/0896 | **3 of 3 held** |
| coordinates vs symbols in one sample | A2, 10 files | **8 of 10 coordinates wrong; the symbol survived in every one** |
| backticked `foo()` across the whole corpus | driver, `symbolscan.py` | **2016 checked, 98.4% still present** |
| cited lines past end of file | driver, `citescan.py` | **0 of 3751** |

**Coordinates rot; identity holds.** That is the same finding as the harness batch's
`W12b` — where a shared `/tmp` namespace could not be scored by counting or even by set
difference, and needed the child to **announce its own identity** — arriving in the prose
layer. With the design settled by measurement, a separate design stage would only add a
handoff at which it could be mis-transcribed.

**What stays separate.** `D1` (apply) remains its own stage, and the driver still holds
the commit.

---

## D9 — The checker must be GREEN on today's tree, and still able to go red

**Decision.** `BC1`'s checker must pass at its default setting on the tree as it stands,
while remaining capable of a real red.

**Why.** T1's baseline is **ZERO counted failures** and CLAUDE.md is emphatic that *a
standing red is a defect, not furniture* — it is the one place a real regression hides in
plain sight, and this branch has already shipped two defects past twenty-eight passing
checks. A checker that fails 1047 files on the day it lands would either redden T1
permanently or, far likelier, be quietly disabled — and a disabled checker is how the
cleanup rots, which is the outcome `D3` exists to prevent.

So it enforces **forward**: files that carry the new header are checked against it, and a
**non-regression count** keeps the unconverted set from growing. Red-first still applies —
the crew must observe it red on a genuine defect and green after, per `CREW_BRIEF.md`.

---

## D7 — `UNKNOWN` is a first-class verdict

**Decision.** Stage A's schema carries `UNKNOWN`, and a crew that cannot determine a
file's status records it with what it tried.

**Why.** The failure being measured is **fabricated confidence** — six prescribed fixes
written by people who were sure. A measurement pass that pressured crews to fill every
cell would manufacture exactly that, and the batch would have produced a seventh instance
of its own subject while claiming to count the first six. The size of the `UNKNOWN` set
is itself a finding: it is the fraction of the tracker that cannot be triaged without
running something.
