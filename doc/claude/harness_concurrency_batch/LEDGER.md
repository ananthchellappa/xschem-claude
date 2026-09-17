# Ledger — harness concurrency batch

## ✅ BATCH COMPLETE — T1 AT ZERO, 2026-09-17

| | |
|---|---|
| cases | **84** (`Start=84 / Finish=84`) |
| wall time | 375.1 s (**unattributed**) |
| counted failures | **0** |
| exit code | **0** |

`results.log` byte-identical to V1's and V2's green verdicts. Both 1477 gates pass:
mtime moved **and** 83 log lines against 84 cases, so the zero is a finished verdict,
not a truncation.

**Defect fixed:** the regression harness's concurrency collision, filed **five times
across seven weeks with zero attempts** (0384, 0867, 0990 — phantom FATAL; 0955, 0905 —
phantom PASS). All four faces closed; two of the four had never been recorded anywhere.

## Task table — 18 tasks, 19 commits

| id | task | status | commit |
|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` |
| **A1** | the RED suite (13 RED / 7 green) | DONE | `5114dd8b` |
| **B1** | faces 1–3 (13 → 2 RED, 10 of 10) | DONE | `5f7164d4` |
| **C1** | face 4, the verdict (2 → 0, 18 of 18) | DONE | `43b40f04` |
| **V1** | solo T1 — GREEN | DONE | `d4946b61` |
| **D1** | the written record (1476 minted, 5 closed) | DONE | `1a46c800` |
| **D2** | lying detail strings (12 of 20 lied) | DONE | `d35db718` |
| **V2** | closing solo T1 — GREEN, committed tree | DONE | `aa0e2213` |
| **D3** | file the residuals (1477–1479) | DONE | `9dffeed4` |
| **E1** | 0805 + 0802 (69 → 75 checks) | DONE | `b3cc484c` |
| **E2** | 0408(a) (157 → 161; 8/20 bad → 0/40) | DONE | `b46892d6` |
| **E3** | 1332-residual (40 → 43; two sabotages) | DONE | `36226c0c` |
| **F1** | documentation pass | DONE | `bb069d89` |
| **F2** | stale citations (briefed 2, found 9) | DONE | `c9c50562` |
| **F3** | citations outside issues/ (briefed 4, found 43) | DONE | `c7f3cdba` |
| **F4** | the false count (briefed 4, found 7) | DONE | `26901af1` |
| **V3** | closing solo T1 — **RED (2)** | DONE | `973ddb9f` |
| **G1** | origin + clear + re-run — **GREEN** | DONE | `0e559104` |
| **H1** | mint 1480, argue 0609 | DONE | — |

## ⚠ H1 RE-SCOPED ITS OWN BRIEF, AND THE IRONY IS EXACT

The brief said "mint 1480 as the sixth residue class". **Taken literally that would have
been the sixth filing of an already-filed proposal.** H1 read the neighbouring issues
first and found the litter half already filed **five times**:

* **0353** — detector half landed, backup shape excluded
* **0356** — the *open decision* on widening, tradeoff written out
* **0609** — owns `C11`
* **0673** — fix item 2 is *verbatim* "widen the tree-hygiene check crews are told to run"
* **0687** — already owns the `tests/` producer and the guardian's blindness

`.gitignore:48-52` also records the cure. **This batch exists because one defect was
filed five times and fixed zero times; the driver's brief was about to do it a sixth.**
H1 confined 1480 to what no issue file contains, opening with a table of the five prior
numbers and the sentence *"The litter is not this issue"* — the shape 1476 used.

**1480's unfiled core (§2.1):** **neither audit driver writes a per-suite `.log` under
`tests/` at all** (`out=$(…)` with `mktemp -d`), so V3's "no suite ran in that window"
sweep was *structurally incapable* of being right. Plus T1 writing one every green run
from a **passing** case (two distinct pids), the 63-of-69 static exposure, the scope
limit (`$repo` derives from `[info script]`, so the `tests/` copy can **never** reach
C11), and the must-land-together warning.

Mint verified **three times** (entry, pre-mint, post-mint): band awk silent, cross-clone
`ls` rc 2 no match in either checkout, `grep -lw` one hit — this clone's own pointer
sentence. 1481 checked before becoming the new pointer.

## ⚠ H1's three findings the brief did not have

1. **`write_backup()`'s header comment contradicts its own body.** `save.c:6137-6138`
   says untitled buffers are *skipped*; `:6149-6152` and the code do the deliberate
   opposite (issue 0060). **Wrong in exactly the direction that makes a reader conclude
   this leak cannot exist.** Reported, not fixed — it is source.
2. **`.gitignore:55/:56` is stale in 5 files across 7 sites**, one of them a
   **check-name string** at `test_audit_classifier.tcl:490` — **D2's exact defect
   class.** Today the lines are `:75/:76`; `:55` is `# Executables`. Reported, not
   edited (test logic).
3. **`test_op_dump_altshow` is not in T1's case list at all**, so under T1 the only
   exposed row is `C11` — narrowing the 0609/1480 interaction by one row. Also 0687's
   cited producer line `:374` is stale; the only `clear force` is `:484`.

## Driver decisions on H1's two flags

* **Its one overreach is KEPT.** H1 also corrected 0609's stale citations in place
  (`save.c` off ~2000 lines; the C11/H1 rows `:772`→`:1531`, `:924`→`:939-941`) and
  flagged it rather than letting an audit find it. **The pre-image of every one is in
  the new section's correction table**, so it is reversible and auditable. Dropping them
  would leave known-stale citations in the file — the rot this batch spent its tail
  documenting.
* **The sweep is NOT implemented.** 1480's proposed sweep is deliberately written as a
  `find` so it does not pre-empt **0356's open question** between `--ignored=matching`
  and a `find`-based arm. Implementing it touches 0356 and is the user's call.

**H1 re-measured the driver's CLAUDE.md refutation rather than take it on trust — and
confirmed it.** Joined-line search returns 0 for all four phrases; `:118` reads "The run
is 84 cases and 83 log lines"; `:130` is past-tense by construction. **CLAUDE.md was
never opened for writing.**

## The batch's own count: thirteen wrong recorded beliefs

Three issue files prescribed fixes that were no-ops or regressions (0867, 0990, 0805);
0408 reasoned wrongly about its own part (b); a residual was described incorrectly; E3
refuted its own row's premise; F2's correction went stale *inside the batch*; two
citations were wrong the day they were written; F4 found a count wrong in seven places,
two of them arithmetic no grep can reach; V3 misattributed a cause its sweep could not
observe; G1 read a past-tense sentence as a live claim; and the driver corrupted one
brief by summarising a receipt, mis-scoped 1480 toward a sixth duplicate filing, called
a working waiter dead, and twice left a commit hash out of this ledger — **both times
caught by a crew reading it.**

**Every one was found by re-measuring rather than re-reading.**

## Rulings standing with the user

* **⚖ R1** (0990) — **refuse** vs **preserve-and-proceed**. The originally offered
  "second run waits" was measured to destroy the verdict the lock protects.
* **⚖ R2** (0663) — prune the three dead `~/.xschem/ase_simulators` entries, or isolate
  the suite? Recommendation: **isolate**.
* **⚖ R3** (0609) — should `C11` become a delta? R2's twin. Under T1 it cannot currently
  catch its own leak.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", repo-wide in one deliberate pass** — supported by
   F2 (9 stale), F3 (43, two never correct), F4 (7 sites) and H1 (7 more).
3. **1480's sweep**, which requires deciding 0356 first.
4. **`save.c:6137-6138`'s contradicting comment** (issue 0060) — source, untouched.
