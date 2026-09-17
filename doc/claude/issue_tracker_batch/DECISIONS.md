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

## D7 — `UNKNOWN` is a first-class verdict

**Decision.** Stage A's schema carries `UNKNOWN`, and a crew that cannot determine a
file's status records it with what it tried.

**Why.** The failure being measured is **fabricated confidence** — six prescribed fixes
written by people who were sure. A measurement pass that pressured crews to fill every
cell would manufacture exactly that, and the batch would have produced a seventh instance
of its own subject while claiming to count the first six. The size of the `UNKNOWN` set
is itself a finding: it is the fraction of the tracker that cannot be triaged without
running something.
