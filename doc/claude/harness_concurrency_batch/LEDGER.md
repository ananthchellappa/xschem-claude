# Ledger — harness concurrency batch

## ⚠ REOPENED 2026-09-17 — THE PREMISE WAS WRONG. SEE "R1-RECON" BELOW.

The batch closed at `77820c03` with T1 at zero. It reopened the same day for two reasons:

1. **The user returned all three rulings**, which were never theirs to make — internal
   test-harness engineering filed as if it needed their sign-off. *"I don't get into the
   weeds of the test-suites. As my coding agent, I am expecting you to make the best
   decision … you can't let me gate progress."* All three taken by the driver, `890cb5e5`.
2. **The user rejected R1's shape before returning it** — *"Why not make it fault-tolerant
   and find a way for both runs to proceed?"* — and was right. The constraint the whole
   choice rested on was a filename convention, not a property of the system.
3. **Recon then refuted the driver's own stated premise.** `results.log` was not the last
   shared object. It is **1 of 88**.

## Closing state of the first pass — T1 AT ZERO, 2026-09-17

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

## Second pass — rulings taken, premise re-measured

| id | task | status | commit |
|---|---|---|---|
| **R1/R2/R3** | all three rulings taken by the driver | DONE | `890cb5e5` |
| **R1-recon** | can both runs proceed? what else is shared? | DONE | *(this commit)* |
| **R2-R3-design** | isolation + C11 delta, read-only design | DONE | *(this commit)* |
| **0060-comment** | the comment that misdirects leak-hunters | DONE | `a6038098` |
| **ram-figure** | CLAUDE.md's RAM constraint is wrong by 2× | IN FLIGHT | — |
| **R1-build** | per-pid logs + header/trailer sentinels | IN FLIGHT (holds the suite slot) | — |
| **R3-build** | the C11 delta — **land alone, not hostage** | QUEUED behind the suite slot | — |
| **R2-build** | private `HOME` for the guard suite's children | QUEUED behind the suite slot | — |
| **citations** | 9 stale in `test_no_untitled_litter.tcl`, +`test_ase_core.tcl:1516` | QUEUED (collides with R3-build) | — |
| **1480-update** | record that `write_backup()`'s header is fixed | QUEUED | — |

⚠ **Only one crew may run suites at a time** — that is this batch's own subject, and a number
produced during a collision is void. The queue above is that constraint, not a priority order.

## ⚠ R2/R3 DESIGN — THREE MORE DRIVER ERRORS, AND A FOURTH BAD ISSUE FILE

Full detail in `DECISIONS.md`. The headline for anyone reading only this file:

1. **"Neither ships alone" was HALF WRONG, and it changed the build order.** The dependency is
   **one-directional** — the C11 delta is strictly safe on its own (it only makes the row *less*
   sensitive); only the *containment* cannot ship alone. The delta was being held hostage for no
   reason. `R3-build` is now queued to land it by itself.
2. **"0609's containment pins T1's cwd to `$REPO`" — 0609 names no directory at all.** The
   driver's summary dropped a conditional that 1480 §5 still carries.
3. **"`scratch.tcl` reaches 169 suites" — it is 187 suites / 193 sourcers / 195 mentions.**
   Another count taken from a plausible sentence instead of from the artefact. The out-of-scope
   ruling stands and is *stronger*; the number must not be requoted.

⚠ **0609's supplied fix code is partial — do not paste it.** It compares **counts, not sets**
(a `.sym`→`.sch` swap scores clean, and **0609 §3 is itself the correction recording that both
occur**) and watches **only `$repo`**, fixing the false-red direction while leaving the blind
direction exactly as blind. **Fourth issue file this batch whose prescribed fix would have
shipped a no-op or a regression** — after 0867, 0990 and 0805.

**G1's decisive measurement VERIFIED on seven independent legs**, so R3's premise holds: under
T1 the suite's cwd is `tests/` while `C11` reads the repo root, and it cannot catch its own leak.

**R2's decisive hop:** `init_action_log()` runs from `main.c:103` **before** `Tcl_AppInit`
(`xinit.c:3112`), so the child's log is open when `xschem.tcl` sources the registry. Had it been
the other way round the whole hypothesis collapses. The two affected rows are **`SG13`**
(`:332-334`) and **`SG14`** (`:343-352`); fix is a private `HOME` for the farm children, 22 → 23
checks. Options (b) and (c) are **impossible**, not merely worse — the registry reader is a
separate process, which makes this **a child-process face of issue 1377 that 1377 does not cover**.

⚠ **Everything in the R2/R3 design is INFERRED FROM SOURCE — nothing was executed.** The crew
supplied falsifiable predictions (`SG13` → `{3}`, `SG14` → `{0 1 1 0 4}`) precisely so the build
crews can prove the chain wrong. **Report the actual numbers; do not round them into "2 failed."**
The driver's own "clean HOME → ALL PASS (22)" is still taken **entirely on trust**.

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

## Rulings — ALL THREE TAKEN BY THE DRIVER, none standing with the user

Cleared from `owed.sh` on the user's instruction. Reasoning in `DECISIONS.md`.

* **⚖ R1** (0990) → **both runs proceed.** Per-pid verdict files; `results.log` keeps its
  canonical name tracking the most recent completed run; every verdict gains a header and
  a trailer so a reader can tell whose answer it is and whether the run finished.
* **⚖ R2** (0663) → **isolate** the suite from the simulator registry; do not prune.
* **⚖ R3** (0609) → **`C11` becomes a delta.** Must land with 1480's containment.

**The filter that should have been applied at filing time:** *does this reach a person?*
UI wording and product behaviour are the user's; harness internals are the driver's. The
~190 rule debts still on the ledger have never been through that filter — a triage pass is
proposed, not scheduled.

## ⚠ R1-RECON — THE FOURTEENTH WRONG RECORDED BELIEF, AND IT WAS THE DRIVER'S

`DECISIONS.md` asserted, on the day the decision was taken, that *"the only single-slot
object left was the name `tests/results.log`"*. **Measured false.** A full T1 writes **88
fixed-name files** under `tests/`; **83 are verdict inputs**. The lock C1 built protects
**1 of 88**. The driver inherited that sentence from B1's receipt instead of measuring it —
the exact failure this batch spent its tail documenting, committed into the decision record.

**B1's fix is real, and re-measured rather than inherited:** two `open_close.tcl` runs
staggered 5 s produced **0 phantoms, rc 0, 1898 result files each, neither dying** — against
a pre-fix record of **407/432/757 phantoms with run B dead**. The *cases* are parallel. The
**driver** is not.

**The collision reproduced one file upstream**, in `<hc>.log`, wrong in **both** directions:
silently scoring run A's **two real failures as 0** (face 4 again), and inventing a failure
the passing run did not earn. Also shared: `<tc>.log` ×3, `<dc>.disp.log` ×11,
`tests/results/.actionlogs`, `~/.xschem/` (**19 T1 suites do not source `scratch.tcl`**), the
display. Cure: `.<pid>`, B1's own pattern, ~6 lines.

**Two corrections that outlive the batch:**

1. **This box is not ~7.8 GB. `MemTotal` ≈ 15.35 GiB — wrong by 2×** in CLAUDE.md, and
   inherited into `DECISIONS.md`. CLAUDE.md *reasons* from it (1477's OOM attribution).
   Crew `ram-figure` is repairing it; the truncation defect itself is real and stays.
2. **Concurrency does not buy throughput** — 64.4 s concurrent vs **53.7 s back-to-back**,
   20% *worse*. The case for "both proceed" is that **no crew is ever refused**, never speed.

⚠ **The header sentinel does not survive a kill without a `fconfigure`**, and there is still
**zero** `fconfigure`/`flush` in `run_regression.tcl`. The trailer survives; the header is the
half buffering eats — and the header is what says whose answer a file is. It is load-bearing.

⚠ **Row `V1b` of `test_regression_concurrency_1476.tcl:100` encodes the OLD R1** and will red
on the correct new behaviour. Rekey it in the build, do not delete it.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", repo-wide in one deliberate pass** — supported by
   F2 (9 stale), F3 (43, two never correct), F4 (7 sites) and H1 (7 more).
3. **1480's sweep**, which requires deciding 0356 first.
4. **`save.c:6137-6138`'s contradicting comment** (issue 0060) — source, untouched.
