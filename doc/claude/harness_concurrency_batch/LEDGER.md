# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

## ✅ T1 IS AT ZERO — closing gate passed on the second attempt

| | |
|---|---|
| cases | **84** (`Start=84 / Finish=84`, every name matched exactly once) |
| wall time | **375.1 s** (measured, **unattributed**) |
| counted failures | **0** |
| exit code | **0** |

`headless/test_ase_core`: `RESULT: ALL PASS (675 checks)`, `OVERALL: ok`, and the
offending row now reads `ok: C11 no untitled~.sch was dropped in the repo root`. All 83
`Total num fail:` lines read `0`. **Both 1477 gates pass** — mtime moved
`1789640995 → 1789642203` **and** 83 log lines against 84 cases, so the zero is a
finished verdict rather than a truncation. `results.log` returned to `cb8b3911…` / 4785 B,
**byte-identical to V1's and V2's green verdicts** — independent confirmation that
nothing else moved.

## The origin, pinned to a line

`test_descend_inert_class.tcl:173` places a `lab_pin.sym` named `zz1` at `100 100` on
the startup untitled buffer. That dirties it; `set_modify(1)` → `write_backup()` drops
`untitled~.sch` into `pwd_dir`; and **`full_audit.sh:64` pins that to `$REPO`.** It is
the **last of the 15** CI-gate suites (`ci.yaml:74`), which **F1 ran verbatim**.

Proved by byte-exact reproduction in an isolated cwd: md5
`2dbeb0ea88ae0a73d6d34e6efc5463e3`, `cmp` identical. The `zz1` signature is
**exclusive** — 0 hits across the other 14 suites — and **11 of the 15 are unguarded**.
Timeline fits to the second: F1's edits at 02:35:43/44, the file at 02:36:39, F1's
receipt at 02:38:49.

⚠ **V3's "pre-existing, not this batch" is refuted.** This batch wrote the file, via its
own CI-gate verification run, through a leak that predates it.

## ⚠ WHY V3 MISSED IT — TWO STRUCTURAL BLINDNESSES, STACKED

1. V3 inferred "no suite ran in that window" from finding **no `*.log` under `tests/`**.
   But `full_audit.sh:475` and `run_suites.sh:121` capture suite output into
   `out=$(...)` with `mktemp -d` logdirs, so they **write no `.log` under `tests/` at
   all.** The sweep was *structurally incapable* of seeing the responsible run.
2. **The audit's own leak detector is `git status --porcelain`**, and `.gitignore:75`
   hides `*~.sch` — so **the run that created the litter also could not report it.**

**A check that cannot observe the thing it concludes about is the same defect as the
phantom PASS this batch was built to remove.** Absence of evidence looked exactly like
evidence of absence, twice over, in one incident.

## Task table

| id | task | status | commit | result |
|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline; R1 filed |
| **A1** | the RED suite | **DONE** | `5114dd8b` | **13 RED / 7 green**, 4 runs identical |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 → 2 RED**, 10 of 10 |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 → 0**, `ALL PASS (20)`, 18 of 18 |
| **V1** | solo T1 | **GREEN** | `d4946b61` | 84 cases, ZERO failures |
| **D1** | the written record | **DONE** | `1a46c800` | 1476 minted; 5 closed; five CLAUDE.md fixes |
| **D2** | lying detail strings | **DONE** | `d35db718` | **12 of 20 rows lied**; 16 rewritten |
| **V2** | closing solo T1 | **GREEN** | `aa0e2213` | 84 cases, ZERO failures, committed tree |
| **D3** | file the residuals | **DONE** | `9dffeed4` | 1477–1479 minted |
| **E1** | 0805 + 0802 | **DONE** | `b3cc484c` | 69 → 75; **0805's own fix was a regression** |
| **E2** | 0408(a) | **DONE** | `b46892d6` | 157 → 161; 8 of 20 bad → 0 of 40 |
| **E3** | 1332-residual | **DONE** | `36226c0c` | 40 → 43; two sabotages |
| **F1** | documentation pass | **DONE** | `bb069d89` | three OWED items |
| **F2** | stale citations | **DONE** | `c9c50562` | briefed as 2, found 9 |
| **F3** | citations outside issues/ | **DONE** | `c7f3cdba` | briefed as 4, found 43 |
| **F4** | the false count | **DONE** | `26901af1` | briefed as 4 sites, found 7 |
| **V3** | closing solo T1 | **RED (2)** | `973ddb9f` | litter in repo root; cause misattributed |
| **G1** | origin + clear + re-run | ✅ **GREEN** | — | **84 cases, ZERO failures, rc 0** |

## ⚠ TWO DRIVER ERRORS, RECORDED

1. **G1 did not halt.** The driver resumed it believing it had stopped mid-measurement
   with nothing to wake it, as had genuinely happened to V1. **G1's bounded waiter had
   fired normally** (`DONE rc=0 after 379s`) and its end timestamp survived, so its wall
   time is **measured, not reconstructed** — 375.1 s; the waiter's 379 is its own poll
   granularity. The resume was harmless, but a driver that cries "hung" at a working
   waiter will eventually interrupt one that is fine.
2. **The driver wrote G1's CLAUDE.md claim into this ledger as fact before checking it**
   — the same error that corrupted F3's brief. Corrected below before committing.

## ⚠ G1's CLAUDE.md CLAIM IS REFUTED — and acting on it would have BROKEN a correct line

G1 reported, outside its remit, that CLAUDE.md "still says **83 cases — 68 headless, 11
display, 4 top-level**". **It does not.** Measured by the driver, wrap-tolerantly (the
file is hard-wrapped, so a phrase can straddle a line break): a joined-line search
returns **silence** for both `83 cases` and `68 headless`. Every surviving `83`/`68` is
correct in context:

* `:108` "tree ran 83" — the fossil, historical, correct
* `:118` "**The run is 84 cases and 83 log lines**" — correct
* `:127` "`= 84  Start/Finish pairs      83 Total num fail: lines`" — correct
* `:130` "It was **68 + 11 + 3 + 1 = 83** until the harness-concurrency batch
  registered…" — **D1's deliberate PAST-TENSE sentence**, correct precisely *because*
  it is labelled as history
* `:155`, `:160` — both correct historical references

**G1 read `:130`'s historical statement as a live claim.** It also wrote that "V3 read
the same paragraph and let it stand", implying an oversight — **V3 let it stand because
it was right.** This is the twelfth wrong recorded belief in this batch and the first
where acting on a crew's finding would have *introduced* an error into a correct
document. **H1 therefore does NOT touch CLAUDE.md.**

## G1's two recommendations — one filed, one to mint

1. **⚖ R3 filed** (against 0609): should `C11` become a delta — clean before, compare
   after — instead of a raw existence test that reds on any repo-root litter whoever
   wrote it? **G1's new measured argument: under T1 the suite's cwd is `tests/` while
   C11 reads the repo root, so under T1 C11 cannot catch its own leak at all.** Twin of
   R2. 0609 already names C11, records 13/13 red audits and supplies fix code, so no new
   number is needed.
2. **Sixth residue class → mint 1480** (task **H1**). Sweep `untitled*` at the repo root
   **and** `tests/`. It proved itself mid-task: T1 regenerated `tests/untitled~.sch`
   with tag `_badig_2108581`, **a different pid from V3's**, so a fresh write — turning
   V3's inference into a measurement.
   ⚠ **The two fixes must land together**: 0609's proposed containment would pin T1's
   cwd to `$REPO`, **which would make every T1 run red.**

## Resume point

**H1** — mint 1480 and record G1's new argument in 0609. **Documentation only, and
explicitly NOT CLAUDE.md.** T1 reads none of it, so G1's green stands and no further T1
is owed.

## Rulings standing with the user

* **⚖ R1** (0990) — **refuse** vs **preserve-and-proceed**.
* **⚖ R2** (0663) — prune the three dead `~/.xschem/ase_simulators` entries, or isolate
  the suite? Recommendation: isolate.
* **⚖ R3** (0609) — should `C11` become a delta? R2's twin.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", repo-wide in one deliberate pass.**
