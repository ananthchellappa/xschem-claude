# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

## ⚠ STATUS: T1 IS RED — 2 counted failures. THE BATCH IS NOT CLOSED.

V3, the closing gate, did **not** come back green. Per this repo's own standing rule —
*a standing red is a defect, not furniture* — the batch stays open until T1 reads zero
or the red is proven to belong to something else and is filed.

| | |
|---|---|
| cases | **84** (`Start=84 / Finish=84`) |
| wall time | 377.7 s (**unattributed**) |
| counted failures | **2** |
| exit code | **0** ⚠ |

## The red, named per case

One case, `headless/test_ase_core`, contributing two counted lines but **one real
defect**: `RESULT: 1 FAILED (674 passed)`, the second line being the banner rule's
consequence (`exit=1, OVERALL_ok=0, died=0` — a check failed, nothing crashed).

```
FAIL: C11 no untitled~.sch was dropped in the repo root (issue 0609) -> {1} (exp {0}) : FAIL
```

**`C11` is a raw existence test, not a delta** — a bare
`[file exists [file join $repo untitled~.sch]]` expecting 0 — so any litter in the repo
root reds it regardless of who put it there. The file is hidden by `.gitignore:75`
(`*~.sch`), so `git status` was blind to it all session.

⚠ **V3 called this "pre-existing, not this batch", and the driver is NOT accepting that
framing unexamined.** The file's mtime is **02:36:39** — *after* V2's green run and
*before* V3 started, i.e. **inside this batch's own working window**. V3's evidence
proves its own run did not create it and that `test_ase_core.tcl` is byte-identical
(`905dd7ad576f`) at V1's tree, V2's tree and HEAD. It does **not** establish that no
crew created it. Establishing the origin is task **G1**.

## ⚠ A SIXTH RESIDUE CLASS, UNSWEPT — and T1 itself produces it

`untitled~.sch` is gitignored and outside all five residue classes every verification
pass has swept. **One is provably produced by a T1 case**: `tests/untitled~.sch` carries
scratch tag `_badig_2066619` — the pid of V3's own run — and matches
`test_backannotate_digital`'s log mtime exactly. **`C11` only looks at the repo root,
which is the sole reason this has never reddened anything.**

## ⚠ rc 0 WITH A RED — the trap, sprung on the last run of the batch

T1 exited **0** while carrying two counted failures. A caller grepping stdout and
trusting the exit code would have reported this as a clean sweep. **Both of CLAUDE.md's
newest gates earned their keep on this run**: the mtime moved *and* the log carries 83
`Total num fail:` lines against 84 cases, so per issue **1477** the `2` is a real
verdict rather than a truncation artefact.

## ⚠ V3 corrected FOUR statements in the driver's brief

1. **Nine commits landed since `d35db718`, not six** — the driver missed `aa0e2213`,
   `9dffeed4`, and F4's own `26901af1`.
2. **The LEDGER's F4 row showed commit `—` while F4 was committed** at `26901af1`.
   **This is the second time a crew has caught this exact slip** (V2 caught it for D2).
   Corrected below. A ledger that is wrong about what is committed is the same class of
   defect as an issue file that is wrong about what is fixed.
3. **The driver's risk model was inverted.** `banner_rule.tcl` — the brief's headline
   worry — is **net comment-only across the whole range**, E1's 52-line diff included,
   so T1's verdict logic is exactly what V2 certified. The genuinely new exposure was
   **`test_label_ride`, which *is* in `hcases:38`**, directly contradicting the brief's
   "none of the companion suites is in T1's case list". E2 reworked it to 575
   non-comment lines with four new rows. **It passed** — but the driver guarded the
   wrong file.
4. **"Three comment-only source edits" undercounts**: five distinct files over six
   pairs, and `26901af1` changed **four non-comment lines** in
   `test_startup_guard_0663.tcl` (the four check-name strings — output, not comment).
   Harmless: that suite has 0 hits in T1's list.

**Confirmed as briefed:** 10 / 1898 / **1488** log-against-log; the 1476 suite passed
*inside* T1 (`ALL PASS (20 checks)`, `OVERALL: ok`); `test_startup_guard_0663` absent
from the run entirely, as it should be.

## Task table

| id | task | status | commit | result |
|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline; R1 filed |
| **A1** | the RED suite | **DONE** | `5114dd8b` | **13 RED / 7 green**, 4 runs identical |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 → 2 RED**, 10 of 10 |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 → 0**, `ALL PASS (20)`, 18 of 18 |
| **V1** | solo T1 | **GREEN** | `d4946b61` | 84 cases, ZERO failures, rc 0 |
| **D1** | the written record | **DONE** | `1a46c800` | 1476 minted; 5 closed; five CLAUDE.md fixes |
| **D2** | lying detail strings | **DONE** | `d35db718` | **12 of 20 rows lied**; 16 rewritten |
| **V2** | closing solo T1 | **GREEN** | `aa0e2213` | 84 cases, ZERO failures, committed tree |
| **D3** | file the residuals | **DONE** | `9dffeed4` | 1477–1479 minted |
| **E1** | 0805 + 0802 | **DONE** | `b3cc484c` | 69 → 75 checks; 0805's own fix was a regression |
| **E2** | 0408(a) | **DONE** | `b46892d6` | 157 → 161; 8 of 20 bad → 0 of 40 |
| **E3** | 1332-residual | **DONE** | `36226c0c` | 40 → 43; two sabotages |
| **F1** | documentation pass | **DONE** | `bb069d89` | three OWED items |
| **F2** | stale citations | **DONE** | `c9c50562` | briefed as 2, found 9 |
| **F3** | citations outside issues/ | **DONE** | `c7f3cdba` | briefed as 4, found 43 |
| **F4** | the false count | **DONE** | **`26901af1`** | briefed as 4 sites, found 7 |
| **V3** | closing solo T1 | ⚠ **RED (2)** | — | 84 cases, **2 counted failures**, rc 0 |

## Resume point

**G1** — establish who wrote the repo-root `untitled~.sch` at 02:36:39, clear the
litter, and re-run solo T1 to zero. Then the batch closes.

## Rulings standing with the user

* **⚖ R1** (against 0990) — **refuse** vs **preserve-and-proceed**. The originally
  offered "second run waits" was measured to destroy the verdict the lock protects.
* **⚖ R2** (against 0663) — prune the three dead `~/.xschem/ase_simulators` entries, or
  isolate the suite from the registry? Recommendation: isolate.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", repo-wide in one deliberate pass** — supported by
   F2 (9 stale), F3 (43, two never correct) and F4 (7 sites, two of them arithmetic no
   grep can reach). Carries the remaining `src/xinit.c` and `test_ase_core.tcl` sites.
