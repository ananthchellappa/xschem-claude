# BC1 — the issue-stamp convention, and a checker that enforces it forward

**Status:** DONE
**Files touched (all NEW; nothing in `doc/claude/issues/` was edited — D2/D4):**
* `doc/claude/specs/issue_stamp.md` — the convention, written as a spec
* `tests/headless/issue_stamp.tcl` — the checker (library + CLI)
* `tests/headless/test_issue_stamp.tcl` — its red-first suite, 39 checks
* `tests/headless/issue_stamp_baseline.txt` — the grandfather set, 1047 numbers
* this receipt

**Tree state:** started at **`d64686a1`**, finished at **`cf5f8dd7`**. ⚠ **HEAD moved
six times while this one task ran** (`d64686a1` → `07c8dee3` → `a489d98f` → `0e985165`
→ `01cef414` → `cf5f8dd7`). I did not correct my citations each time and did not need
to: everything below is stamped with the revision it was read at, which is the entire
thesis of the deliverable, demonstrated accidentally on itself.

**Suites run:** `test_issue_stamp` only — under `tclsh`, under
`./src/xschem --nogui --pipe -q --script`, and through `run_suites.sh` (dev display
`:99`, `GUI_GATE=0`). **T1 was NOT run**; the design does not require it (below).
Every command carried a `timeout`.

---

## 1. The convention, in five lines

One physical line, column 0, in the first 12 lines of an issue file:

```
**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`
```

* `claim=` `open|fixed|partial|latent|duplicate|wontfix` — **not one bit**
* `tree=` the revision the claims were checked against — **the load-bearing field**
* `fix=` `none|untried|taken|superseded|partial` — a stored fix is a hypothesis until marked
* `open=` how many items the file itself says are still outstanding
* optional `super=` (issue number, revision, or `self`), `scope=`, `by=`

Plus one rule that makes it survive this corpus's actual editing habit:
**the stamp is the file's single newest word; prose that disagrees, above or below,
is history.** Keep appending corrections — just update the one line.

### Why it is shaped like that, per requirement

| requirement | how it is met |
|---|---|
| 1. a one-bit status is insufficient | three values, on `T1-RUN-END`'s model: `claim=` / `tree=` / `open=`. 0905 needs four answers at once, 0891 needs "2 of 3 landed" (`claim=partial open=1`), 0890 and 1219 need "claims latent, is live" (`claim=latent`) — A3's missing cell |
| 2. it must say which option was TAKEN | `fix=superseded` **plus a mandatory `super=`**. This is 0442, and the parser refuses `fix=superseded` without it |
| 3. a stored fix is an unverified hypothesis | `fix=untried` is a first-class value, and `quote=` blocks are machine-verified against their revision |
| 4. **cheap to re-stamp** | **it never needs re-stamping.** See below — this dissolves rather than satisfies the requirement |
| 5. must express supersession | `super=`, plus the "stamp is the newest word" rule, which works *with* append-without-touching-the-top instead of against it |
| 6. the missing cell (claims latent, is live) | `claim=latent` |

### ⚠ Requirement 4 dissolved rather than met, and this is the design's core

`tree=` does **not** mean "current". It means *"the claims in this file were last
checked against this revision"* — **a statement about the past, which cannot rot.**
It only becomes older, and age is information. So there is no re-stamping treadmill:
you stamp when you re-verify, and re-verifying is work you were doing anyway.

A rule requiring `tree=HEAD` would redden the whole corpus on every commit — which is
exactly how `PLAN.md:3` rotted **within the hour**. The spec records that as a
**rejected design**, because it is the seductive one.

The warrant is A3's measurement: 5 of 5 files citing bare `file:line` had rotted;
**0818, the one file that named its revision, reproduced 4 of 4 dead coordinates** via
`git show fadb226d:`. One revision, recorded once, makes every coordinate in a file
recoverable forever.

### What I stole rather than invented

**Issue 0229 is the tracker's own write-up of this defect.** It prescribes *"cite
symbols, not offsets"*, ships a pre-commit grep, is still OPEN, and has since rotted
by exactly the defect it files. `src/op_annot.tcl` already models the cure in shipped
source — quoted at `cf5f8dd7`, line 2366:

> `# Cited by function name, not by line number, on purpose: the line numbers this`
> `# paragraph used to carry moved by about eleven hundred lines and silently sent`
> `# every later reader to the wrong place.`

The citation rule in §3 of the spec is 0229's prescription with something mechanical
behind it. **A1's recommendation is adopted as ruled**: a count is prose, only a
*pointer* is a citation, and only pointers are checked — otherwise every file rots on
day two and the checker cries wolf over the whole corpus.

---

## 2. The checker

**Where it lives:** `tests/headless/issue_stamp.tcl`, with `test_issue_stamp.tcl`
beside it. It needs no display, no simulator, no built binary and no T1.

```sh
tclsh tests/headless/issue_stamp.tcl gate                  # verdict, exit 0/1
tclsh tests/headless/issue_stamp.tcl gate <dir> <baseline> # against a scratch corpus
tclsh tests/headless/issue_stamp.tcl report                # advisory census
tests/headless/run_suites.sh test_issue_stamp              # the suite, gated
```

**Does it join T1's `hcases`? No — deliberately, and here is what runs it instead.**
`full_audit.sh:430` discovers suites with `ls "$HERE"/test_*.tcl | sort`, so
`test_issue_stamp.tcl` **joins the audit by existing**, with no registration. It also
runs under `run_suites.sh` unchanged. Registering it in T1 would move the case count
off 84 and oblige an edit to CLAUDE.md's arithmetic block (84 cases / 83 `Total num
fail:` lines / `wc -l` 171) — a paragraph CLAUDE.md records as having been **wrong
three times**, and a crew is the wrong author for that edit. The driver can register
it in one line if it wants T1 coverage; the suite is already green on the arm T1 would
use. Verified on all three arms:

| arm | result |
|---|---|
| `tclsh tests/headless/test_issue_stamp.tcl` | `RESULT: ALL PASS (39 checks)` · `OVERALL: ok` · rc 0 |
| `./src/xschem --nogui --pipe -q --script …` | `RESULT: ALL PASS (39 checks)` · `OVERALL: ok` · rc 0 |
| `run_suites.sh test_issue_stamp` | `PASS \| test_issue_stamp run 1/1` · rc 0 |

### How it is green today and still able to go red (D9)

Enforcement is **forward only**. A file carrying a stamp is validated; a file without
one is grandfathered **by number** in `issue_stamp_baseline.txt` (1047 entries). A
numbered issue file not in that list and carrying no stamp fails. The unconverted set
can shrink, never grow.

⚠ **The baseline is a list of numbers, not a count** — a count-based gate passes when
one grandfathered file is deleted and one unstamped file is added. That is the harness
batch's `W12b` lesson, and this batch re-learned it twice (a `pgrep -af` matching
itself; a `grep -lieE` that answered 1050 for a 1047-file corpus).

⚠ **A vacuous green is a broken checker wearing a pass.** There are zero stamped files
today, so every forward check has an empty input set. `gate` therefore **self-tests
against known-answer fixtures first and reports nothing if it fails them** — the rule
the five driver errors bought. Both directions: 5 known-good stamps that must parse,
10 known-bad that must be refused, and 3 anti-overshoot rows.

### THE RED — four genuine defect classes, one of them live in this tree

Corpus in the scratchpad; **nothing was written into `doc/claude/issues/`.**

```
$ tclsh tests/headless/issue_stamp.tcl gate $S/issues $S/baseline.txt
self-test PASSED (16 parser cases)
ISSUE-STAMP: 9996:5: the file states this assertion is BROKEN, but it now HOLDS -- the defect appears FIXED and the issue was never closed. Re-read it and update the stamp.
ISSUE-STAMP: 9997:5: the file states this assertion HOLDS and it does not (8 hits for SABOTAGE under src)
ISSUE-STAMP: 9998: tree=deadbee does not resolve to a commit in this repo. The whole value of the stamp is that `git show deadbee:<file>` recovers every coordinate in the file; a revision that does not resolve recovers nothing.
ISSUE-STAMP: 9999 (9999-unstamped.md): a NEW issue file with no **STAMP:** line. Every issue filed after the convention landed must carry one -- see doc/claude/specs/issue_stamp.md. The unconverted set may shrink, never grow.
ISSUE-STAMP: 4 problem(s)
rc=1
```

**Row 9997 is the free red, and it is a real live defect.** Re-measured at `cf5f8dd7`:
`/usr/bin/grep -rn SABOTAGE src/ | wc -l` → **8**, where the sabotage protocol's own
closing assertion says *"must be empty"*. That is issue **1219**'s second face, and it
is open.

### THE GREEN — same corpus, the four files repaired, nothing else changed

```
$ tclsh tests/headless/issue_stamp.tcl gate $S/issues $S/baseline.txt
self-test PASSED (16 parser cases)
ISSUE-STAMP: ok (0 problems)
rc=0
```

### And the green that D9 actually demands — the real corpus

```
$ tclsh tests/headless/issue_stamp.tcl gate
self-test PASSED (16 parser cases)
ISSUE-STAMP: ok (0 problems)
rc=0
```

### The check that closes issues by itself

`assert=absent|present pat=<token> path=<path> state=holds|broken` — no shell, no
interpolation. `state=broken` + predicate now true ⇒ **"the defect appears FIXED and
the issue was never closed."** That is the mechanical `STALE-FIXED` detector (7 of 40
in the sample), and it is the direct answer to *one defect filed five times across
seven weeks and attempted zero times*.

### Scope, decided deliberately

The checker **scans** `doc/claude/issues/`, and its `report` mode counts coordinate
citations in `src/` and `tests/` too, because A2/A4 measured that the rot escaped the
tracker (`src/ciw.tcl` repeats 0654's dead coordinates as fact; 1436's correction
lives in `test_ase_dialogs.tcl`, 1395's in `src/ase_window.tcl`). It **gates** only
what carries a stamp. Reddening 937 `src/` and 1190 `tests/` citations on day one
would get the checker disabled, and a disabled checker is how the cleanup rots (D3).
**Report, do not gate.** The report is D1's work list.

---

## 3. What D1 should do first — sized

**First: stamp the nine files this batch has already measured. ~40 minutes.**
Nine one-line insertions, zero prose rewritten (D2). The evidence is already in
`A1`–`A4`; nobody re-derives anything. Proposed stamps are in the spec's §8, and
**0442** and **1219** are the two that earn their keep immediately:

| file | one-line insertion | why first |
|---|---|---|
| 0442 | `fix=superseded … super=self` | its item 1 re-introduces deleted code if pasted |
| 0905 | `fix=superseded … super=32dff39a` | records as *rejected* the shape the tree runs |
| 0891 | `claim=partial open=1` | 2 of 3 follow-ups landed |
| 1438 | `claim=fixed super=1439` | header says "not fixed"; 1439 fixed it |
| 1458 | `claim=duplicate super=1397` | duplicates 1397 while citing it |
| 1219 | `claim=latent` **+ an `assert=` block** | the tree then closes it automatically |
| 0216 | `claim=partial scope=ase-rerun-path` | closed on one route, live on another |
| 0650 | `claim=partial super=0655` | general channel landed; titular sink did not |
| 0249 | `claim=fixed` | its `# RESOLUTION — FIXED` sits 306 lines below an OPEN header |

Then delete those nine numbers from `issue_stamp_baseline.txt`. That converts the gate
from vacuous-but-self-tested to **live on real files**, and gives the next filer nine
worked examples to copy.

**Second: 0071's child table** — the one below-the-fold repair, and the highest
consequence, because umbrella issues are what people read to pick work.

**Do NOT touch 0071's, 0264's, 0516's or 0947's headers.** They are the four
false positives D0 verified; two of them read *"FILED, **not** closed"*. Acting on the
original detector output would have **closed two live defects, one carrying a live
user ruling.**

**Not recommended for D1:** any pass over `src/`/`tests/` citations. 2127 sites,
green-field, and nothing in the sample says they mislead as often as the tracker does.

---

## 4. Claims I re-measured — including four that were wrong

**Confirmed exact:** the brief's **937** `file:line` citations across **27** `src/`
files; **1047** numbered issue files; `grep -rn SABOTAGE src/` = **8**;
`full_audit.sh:430` discovers by `ls test_*.tcl`; `op_annot.tcl:2366` says what A2
quotes.

**Corrections, newest first:**

1. ⚠ **My own checker produced a plausible RED for the wrong reason, and I nearly
   published it.** `rev_exists` returned false for *every* revision, including HEAD:
   `init` derived the repo from `[info script]` **at call time**, so a driver script
   living in the scratchpad resolved the repo two levels above *itself*, `git -C`
   pointed at a non-repository, and a **valid** stamp was reported as *"tree= does not
   resolve"*. The suite was unaffected (it lives in `tests/headless/`), so its greens
   stand. **Caught only because I tested a SHA I already knew was good** — which is
   the ledger's own rule, catching the tool written to enforce it. Row `S20` locks it
   by running the checker from another directory.
2. ⚠ **`closescan.py` flagged issue 0818 as "claimed closed by
   `tests/headless/issue_stamp.tcl`"** — a file that had existed for twenty minutes.
   The trigger, measured: *"3 of 3 still **resolved**; and exactly one — **issue
   0818** —"*. A citation *resolving* is not an issue being *resolved*. It moved a
   corpus-wide census from 165/7 to **166/8** while the driver was quoting it. This is
   an **independent second instance** of the over-firing the driver retracted, and it
   is why closure in this convention is a **declared** `super=` field. Row `N1` locks
   it, including a negated sentence.
3. **`tests/` coordinate citations: 1190, not the brief's 1189.** My own new files may
   account for the difference; I did not isolate it and am not claiming the brief was
   wrong.
4. **`LEDGER.md` cited `tools/stampscan.py` before it existed.** At 12:41 `find` over
   the whole tree returned nothing; at 12:44 the file was there. Not a defect —
   a *forward*-dangling citation that self-healed in three minutes — but worth one
   line, since a checker run in that window would have flagged it correctly.
5. **The baseline's first cut had 1048 numbers for 1047 files.** `ls | grep -oE
   '^[0-9]{4}'` also catches the 9 non-`.md` numbered artefacts. The extra is
   **0443**, which has a numbered artefact and **no issue file**. Rebuilt from
   `NNNN-*.md` only, which is exactly the set the gate iterates.
6. **The worked example refuted my own grammar.** `super=` originally required a
   4-digit issue number — and **0442, the case `fix=superseded` was invented for, was
   superseded by an unnumbered alternative inside its own file.** There is no number
   to name. `super=` now takes an issue number, a revision, or `self`. Writing the
   worked example on a real file is what caught it; the abstract design did not.
7. **Live confirmation of why the banner rule exists.** When my suite hit a Tcl error,
   the xschem arm printed the error and **exited 0**. The exit code alone would have
   scored it a pass; the missing `OVERALL: ok` is what catches it.

**Taken on trust, not checked:** `PLAN.md`'s 497/972/86/510/306/182/49 status census
and the 742 fenced-block count (A1 re-measured 1047 and 742 and confirmed both); the
`owed.sh` counts (brief rule 9); A1–A4's per-file verdicts, which I used as design
inputs rather than re-deriving; D0's verification of the four false positives.

---

## 5. Corrections to PLAN.md / CREW_BRIEF.md for the next crew

1. **`PLAN.md`'s stage framing is aimed at `BAD-FIX` and `STALE-OPEN`** (1 and 0 of 40
   respectively). The random sample says the disease is `ROTTED-CITE` (27 of 40). The
   design was re-aimed accordingly; the plan text still reads the old way.
2. **`PLAN.md:60`'s `SUPERSEDED` baseline of "15 hits / ~13 files" is 26 / 19** (A1).
   Its narrower "exactly one file carries `DO NOT PASTE`" claim is correct and should
   be kept distinct.
3. **A checker confined to a header block scores 0071 green**, and a checker confined
   to `doc/claude/issues/` cannot see two corrections in three. Both are stated as
   named blind spots in the spec rather than quietly accepted.
4. **Do not add a rule of the form "no open issue may claim a red row while T1 is
   green."** 1436 legitimately does, because `test_ase_dialogs` is in `hcases` and not
   `dcases`. Recorded in the spec's rejected-designs table so a future improver meets
   it before writing it.

## 6. Left dirty

Five new files, none committed, nothing deleted or modified:

```
?? doc/claude/specs/issue_stamp.md
?? tests/headless/issue_stamp.tcl
?? tests/headless/issue_stamp_baseline.txt
?? tests/headless/test_issue_stamp.tcl
?? doc/claude/issue_tracker_batch/receipts/BC1.md
```

**No issue file was edited.** No number was minted — deliberately: the suite follows
the unnumbered convention of `test_audit_classifier.tcl`, the spec is cited by path,
and with crews still out, not taking 1482 removes a live collision risk. `NUMBERING.md`
is untouched, so the pointer still reads **1482**. `tests/headless/owed.sh` and
`~/.claude/xschem_owed/` were **not** read or written. Scratch corpora live in the
session scratchpad, outside the repo; the suite sweeps its own fixtures from
`tests/headless/.scratch/`.

## 7. Owed to the user

**Nothing.** Every decision here is internal engineering — a file format for an
internal tracker, where a checker lives, how a baseline is keyed. None of it reaches a
person using xschem, so per the standing rule none of it is a ruling and none was
filed as one. Two decisions are recorded in the spec as mine rather than left implicit:
**A1's "a count is prose, only a pointer is a citation"** (adopted), and **not
registering the suite in T1** (with the one-line path for the driver to overturn it).
