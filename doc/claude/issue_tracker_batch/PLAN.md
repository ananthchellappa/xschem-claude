# Plan — issue tracker batch

**Opened** 2026-09-17, at `2cbce753`, branch `fluid-editing`.
**Subject** `doc/claude/issues/` — the tracker, not any bug in it.

⚠ **That opening line rotted within the hour, and A2 caught it.** By the time the first
crew read this file HEAD was `8608c7ef` — because **the driver had committed twice**. The
line is left standing rather than quietly corrected: it is the batch's own best evidence
that **a tree state written in prose decays the moment anyone commits**, so B1's
convention must be cheap to re-stamp or nobody will keep it. Re-read the stamp as *"the
state this sentence was true of"*, never as *"the state you are reading it in"*.

## Why

The user asked for the most open/broken thing more important than new features, and
took the answer: **the tracker is the project's memory and it is actively wrong in ways
that make it worse than having no memory at all. A blank page does not send you to break
working code; this one does.** The evidence is in `CREW_BRIEF.md` and is the
harness-concurrency batch's own measured tally.

## What "fixed" can and cannot mean

**It cannot mean "make 1047 prose files true."** Nobody can, and a batch that promised it
would end as the seventh prescribed fix that damaged something.

**It means what the harness batch did for T1.** That batch did not make every regression
run correct. It made every verdict **self-identifying** — `T1-RUN-BEGIN` names the pid and
the start time, `T1-RUN-END` states `cases=`, `blocks=`, `counted_failures=` — so a reader
can tell *what they are holding* without trusting the sentence that describes it. A
verdict with no trailer did not finish, whatever its contents.

The tracker needs the same property: **an issue file should state what it was measured
against, and whether its prescribed fix has been verified or is a guess** — so that a
reader can tell a measurement from a hypothesis without re-deriving the whole thing.

## ⭐ RE-SCOPED 2026-09-17 BY THE MEASUREMENT — THIS PLAN WAS AIMED AT THE WRONG TARGET

The stage-A sample came back and **the plan below is mis-scoped**. It is left standing and
annotated rather than rewritten, because the gap between what it predicted and what was
measured is the batch's single most valuable artefact. See `D10`.

| verdict | / 40 | the plan expected |
|---|---|---|
| **ROTTED-CITE** | **27** | not a listed sub-problem at all |
| **STALE-FIXED** | 7 | sub-problem 2 ✓ |
| **BAD-FIX** | **1** | **sub-problem 1 — the batch's headline** |
| **STALE-OPEN** | **0** | the dangerous direction |

**Sub-problem 1 below is built on the last batch's six prescribed bad fixes. In a random
sample that class is 1 in 40, and the dangerous direction is 0 in 40.** Those six were a
**selected** sample — we went looking at issues we already suspected — which is the exact
failure `D1` was written to catch, caught by the mechanism `D1` installed.

**The real disease: the tracker does not describe the wrong code, it points at the wrong
place.** Two files in three carry a citation that no longer resolves to what it claims,
while the *symbol* it names survives 98.4% of the time. Bare `file:line` rotted **5 of 5**;
line-plus-revision reproduced **4 of 4**; symbolic citations held **3 of 3**.

**And the fix has been sitting in the tracker, written down, unbuilt.** Issue **0229** is
the tracker's own write-up of line-number rot. It prescribes *"cite symbols, not offsets"*,
**ships a ready-made pre-commit grep**, is **still OPEN**, and has since rotted itself.
That is the five-filings-zero-fixes pattern in its purest form, and it is now this batch's
primary target.

## The three sub-problems, in the order they cost us

1. **A stored fix is an unverified hypothesis and nothing marks it as one.** Six would
   have changed working code. Exactly one file in the tracker carries a
   `SUPERSEDED — DO NOT PASTE` banner today (0609, added by the last batch); the other
   741 files with fenced code blocks carry nothing.
2. **Nothing closes an issue when the thing is fixed.** 0060's comment misdirected
   readers for 77 days. 1480 and 0609 recorded done work as outstanding. This is the
   direct cause of the five-filings-zero-fixes pattern.
3. **The user's queue has never been filtered.** 190 `rule` debts, 71 `look`, 11
   `suite`. The three cleared on 2026-09-17 were internal engineering that should never
   have been filed as the user's at all. The *does this reach a person?* filter exists
   now and has been applied to exactly three entries.

## Baseline measurements (driver, 2026-09-17, at `2cbce753`)

Every number here is a timestamp, not a standing fact. Re-measure before quoting.

| quantity | value | command |
|---|---|---|
| numbered issue files (`NNNN-*.md`) | **1047** | `ls doc/claude/issues \| /usr/bin/grep -cE '^[0-9]{4}-.*\.md$'` |
| non-`.md` numbered artefacts | 9 | `.tcl`, `.c`, 6 × `.patch` |
| total size | 12 MB | `du -sh doc/claude/issues/` |
| files with a `**Status` line | 497 | `/usr/bin/grep -lE '^\*\*Status'` |
| files with any status-ish line | 972 | case-insensitive |
| files with **no** status word in first 10 lines | **86** | loop over `head -10` |
| **first 10 lines contain BOTH fixed-words and open-words** | **510** | census loop |
| first 10 lines say fixed-ish only | 306 | " |
| first 10 lines say open-ish only | 182 | " |
| first 10 lines say neither | 49 | " |
| files containing a fenced code block | **742** | `/usr/bin/grep -lE '^\`\`\`'` |
| files carrying a `SUPERSEDED` marker | 15 hits / ~13 files | `/usr/bin/grep -n SUPERSEDED` |
| tools that **validate** the tracker | **0** | see below |
| `owed.sh count` | **190 rule, 71 look, 11 suite** | `tests/headless/owed.sh count` |

**The zero is the headline.** `/usr/bin/grep -rln 'doc/claude/issues'` across `*.sh`,
`*.tcl`, `*.js`, `*.py`, `Makefile*` returns only source files **citing** an issue number
in a comment, plus batch `.js` launchers. Nothing reads the tracker to check it.

**510 is the second headline.** Half the corpus cannot be triaged from its own opening,
because the top ten lines contain both "FIXED" and "OPEN" words. That is not sloppiness —
it is what an issue file looks like after someone appends a correction without touching
the header, which is the documented habit of this project.

## Stages

Each stage is one dispatch. Read-only stages run in parallel (`CREW_BRIEF.md` rule 6).

⚠ **This table is kept CURRENT, unlike everything else this batch is studying.** It drifted
once already — `B1`/`C1` merged into `BC1` (D8), and `D0`/`E2` were dispatched after it was
first written and were missing from it for several commits. **A stage table that does not
say what actually happened is the corpus's own disease**, so it is corrected in place as
the batch runs rather than at the end.

| id | stage | crews | runs a suite? | depends on | state |
|---|---|---|---|---|---|
| **A1–A4** | **Measure the rate** on a pre-registered random sample | 4 ∥ | no | — | **DONE** |
| **E1** | **Triage the user's queue** — 190 `rule` debts against *does this reach a person?* | 1 ∥ | no | — | **DONE** |
| **T1-base** | pre-change regression baseline; pre-D1 tree reference | driver | **yes** | — | **DONE — green, 84/83/0** |
| ~~**B1**~~ | ~~design the header convention~~ | — | — | — | **merged into BC1 (D8)** |
| ~~**C1**~~ | ~~build the checker~~ | — | — | — | **merged into BC1 (D8)** |
| **BC1** | **Design the convention AND build the checker** | 1 | yes | A | **in flight** |
| **D0** | **Verify the 7 stale-closure issues**, propose replacement text | 1 ∥ | no | — | **in flight** |
| **E2** | **Collapse the 48 repeated wording ratifications** into one document | 1 ∥ | no | E1 | **in flight** |
| **D1** | **Apply** — the convention, D0's 7, and A's findings | 1 | no | BC1, D0 | blocked |
| **E3** | **Collapse the 71 `look` debts** the same way | 1 | no | E2's format | **DONE — 71 → 27 looks, 5 sittings** |
| **BC2** | **Fix `scope=` round-trip** + spec `open=` counts + §4 | 1 | yes | D1 | **DONE** — root-caused it; caught driver error 21 |
| **BC3** | **Fix the unqualified `.scratch` sweep** (added mid-batch) | 1 | yes | BC2 | **DONE** — and found the *real* cause of the gate red |
| **F1** | **Closing gate** — register in T1, CLAUDE.md 84→85, post-change run | driver | yes | all | **DONE — GREEN**, `cases=85 blocks=84 counted_failures=0` |

⚠ **BC3 was not in the plan.** It was added after D1's receipt exposed a defect in the
batch's *own* machinery. Recorded here rather than quietly absorbed: **three of the eleven
crew tasks (BC2, BC3, and half of D1) existed to repair things this batch built**, which is
the honest cost of building a checker while measuring a corpus.

⚠ **F1 went RED twice before it went green**, and both are in `LEDGER.md`: once because the
driver hand-ran a suite while T1 was live, and once because `HEAD` abbreviated to
`83656487` — eight decimal digits, no hex letter, which the checker's grammar correctly
refused. **A 2%-per-commit coin flip under a baseline that treats any red as a defect.**

### A1–A4 — measure the rate

**The sample is pre-registered** in `SAMPLE.txt`: 40 files drawn from the 1047 with
`awk srand(20260917)`, committed *before* any crew read one, precisely so this batch does
not repeat the sin it is investigating. The last batch's own worst number — "six
documents" — was a **selected** sample requoted as a rate.

Each crew takes 10 files and classifies each against the tree:

| verdict | meaning |
|---|---|
| `TRUE-OPEN` | says open, and it really is open on today's tree |
| `TRUE-FIXED` | says fixed, and it really is fixed |
| `STALE-FIXED` | **says open, but the tree already fixed it** — the 1480/0609 failure |
| `STALE-OPEN` | says fixed, but the defect is live — the dangerous direction |
| `BAD-FIX` | carries a prescribed fix that would **not work or would break something** |
| `ROTTED-CITE` | cites a file/line/symbol that does not say what it claims |
| `DUPLICATE` | same defect as another number |
| `UNKNOWN` | could not determine — **a valid verdict, see brief rule 2** |

A file can carry more than one verdict (`STALE-FIXED` + `ROTTED-CITE` is common).

**On the statistics, honestly:** n=40 of 1047 gives roughly ±15 points at 95%
confidence. That distinguishes "rare" from "endemic" and nothing finer. **Do not let
anyone quote a two-significant-figure rate off this sample** — including the driver,
especially in a closing summary, which is exactly where the last batch's requoted number
went wrong.

### E1 — triage the user's queue

190 `rule` debts, each a pointer to `doc/claude/issues/NNNN-*.md`. For each, one
question: **does the decision reach a person?** User-visible wording, product behaviour
and priorities are the user's. Lock semantics, internal file naming, how a check is
structured are not — those are the agent's to decide and state.

**Read-only on the ledger. Clear nothing.** `rule` and `look` clear only when the user
says so. The crew produces a recommendation table; the user rules on it.

### B1 — the header convention

Design a single opening block that makes an issue file self-identifying, on the T1
trailer's model. Sized by what A found, not by what this plan guesses. Candidate fields:
what it claims, what tree state that was measured against, whether a prescribed fix was
verified or is a hypothesis. **B1 decides; it does not ask.**

### C1 — the checker

Whatever B designs, **something mechanical must enforce it, or the cleanup rots in a
week** — which is this tracker's entire disease. Must go **red on a real defect** and be
runnable by anyone. Red-first: observe it red before the fix, green after.

### D1 — apply

The known-bad set from the last batch — **0867, 0990, 0805, 0609, 1478 §3** — plus
everything A classified `BAD-FIX`, `STALE-FIXED` or `STALE-OPEN`.

## Standing constraints

Live for every crew; violating one is worse than not finishing.

* **Never a bare `xschem`** (issue 0924 — it emptied the user's `File > Open Recent`).
* **Do NOT modify `~/.xschem/ase_simulators`** — the user's own configuration, not test
  scratch. Pruning its dead entries was the explicitly rejected fix.
* **Do NOT delete any `/tmp/xschem_emergencysave_*`** belonging to another process.
* **`rule` and `look` debts clear ONLY when the user says so.**
* **`/usr/bin/grep`, never bare `grep`.**
* **Issue 0356 stays the user's** — it governs what their own `git status` shows them.
* Minting a number takes **two** checks: the reserved-band table in `NUMBERING.md`
  (bands are ranges; no per-number grep sees one) **and** a cross-clone grep of
  `~/dev/*/doc/claude/issues/`. Pointer reads **1482**; **1500–1599 is op-wcard's**.
