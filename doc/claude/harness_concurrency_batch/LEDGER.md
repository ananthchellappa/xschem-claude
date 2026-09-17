# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

## ✅ MAIN TASK COMPLETE AND CERTIFIED — 2026-09-17

| id | task | status | commit | result | issues |
|---|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline; R1 filed as a ruling debt against 0990 | — |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, 4 runs identical | 1476 |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 → 2 RED**, **10 of 10** runs | 0867, 0990, 0384(part) |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 → 0**, `ALL PASS (20)` rc 0, **18 of 18** | 0955, 0905, 0384(rest) |
| **V1** | solo T1 | **GREEN** | `d4946b61` | **84 cases**, 374.6 s, **ZERO failures**, rc 0 | — |
| **D1** | the written record | **DONE** | `1a46c800` | 1476 minted; 5 closed; **five** CLAUDE.md corrections | 1476 + five |
| **D2** | the lying detail strings | **DONE** | `d35db718` | **12 of 20 rows lied on the green path**; 16 rewritten | — |
| **V2** | closing solo T1 | **GREEN** | `aa0e2213` | **84 cases**, 375.0 s, **ZERO failures**, rc 0, committed tree | — |
| **D3** | file the residuals | **DONE** | `9dffeed4` | **1477, 1478, 1479** minted, pointer → 1480; one residual refuted | 1477–1479 |

## Companions — ALL THREE DONE

| id | task | status | commit | result | issues |
|---|---|---|---|---|---|
| **E1** | 0805 + 0802 bundle | **DONE** | `b3cc484c` | classifier **69 → 75 checks**; CI gate 15/0 rc 0; **0805's own fix was a regression** | 0805, 0802 |
| **E2** | 0408(a) | **DONE** | `b46892d6` | **157 → 161 checks**; **8 of 20 bad → 0 of 40**; CI gate 15/0 rc 0 | 0408(a) |
| **E3** | 1332-residual | **DONE** | — | **40 → 43 checks**; 12/12 clean, **8/8 under load**; reddened under **two** sabotages | 1332 |

## ⚠ E3: IT REFUTED ITS OWN ROW'S PREMISE, MID-TASK

`BB37`'s first draft asserted that the fixed `after 100` produces a *vacuous pass*. It
does not — it fires **before the toplevel exists** and degenerates into `BB36`'s shape.
The comment and check name now state both measured results separately.

E3's own formulation is the one to keep: **"an unmeasured mechanism in a comment is
D2's defect one layer up: nothing can ever redden it."**

## E3's red phase — two sabotages, and the second is the important one

* **Reverted to today's `after 100`** → `3 FAILED (40 passed)`, 2/2 byte-identical.
  `BB36 -> {0 {} {} 0 {} 1 0 1 0 1}` — 1332's own recorded shape: nothing seen, no
  grab, no bits, deadman burned.
* **A `winfo exists`-only poll** → `2 FAILED (41 passed)`.
  `BB37 -> {1 {} 1 {{A[1]} {A[0]}} …}` — window seen, **grab empty, `tkwait` never
  entered, and the right bits returned anyway.** ⚠ **That vacuous pass is the shape a
  naive "just poll instead" fix would have shipped GREEN**, and **only the grab leg
  sees it.** The obvious fix was measured and rejected.

Related: **the focus leg is a guard, not the discriminator** — it reads 1 under *both*
sabotages, because the WM focuses the toplevel before the wrapper's own `focus`. Kept,
but the file now says plainly that only the grab proves modality.

## E3's other findings

* **The gate question, answered before any edit** (as the brief demanded):
  `test_ase_bus_bits_0159` is **NOT CI-gated** — checked in four places. It is in
  neither `hcases` nor `dcases`, nor `nogui_tests`/`nolog_tests`/`logdir_tests`, and is
  reached only by `full_audit.sh:430`'s `ls test_*.tcl` glob. **The "both companions
  were gated" pattern does not extend to E3** — which is why the brief asked rather
  than asserted.
* **Citation drift in BOTH directions.** 1332 cites `:258` three times and **nothing
  was ever at `:258`**. The PLAN's `:277`/`:285` were exact today. The block is now
  `:387-407`.
* **The same latent defect P3 found, one row over:** `BB34`'s `after 5000` deadman
  stayed armed through `BB35` — and `BB35` expects `{}`, so it could have passed on the
  *deadman's* answer instead of Cancel's. Both timers are now cancelled per row, and
  `BB38` asserts the handle no longer resolves.
* **On E2's self-catch question**, asked explicitly: E3's rows write no files and use no
  shared path — they assert on in-process Tk state, so they cannot re-create what they
  test. No source-text rows were used, which matters because the file now contains
  several comments quoting the old `after 100`.
* Green after: `ALL PASS (43 checks)`, **12/12 clean**, **8/8 under 1332's own
  acceptance clause** (6-way CPU spinner plus a concurrent `test_op_annot` on `:99`,
  load 0.67 → 1.72), 3/3 through `run_suites.sh`, headless and `DISPLAY`-unset
  unchanged at 23. **WM live: openbox 3.6.1 on `:99`, 1920x1080x24** — stated, as the
  house rule requires.

## ⚠ OWED — the final documentation pass (F1)

1. **`0905`'s closure text (in `1a46c800`) carries a claim D3 refuted** — that a
   standalone suite on `:99` can race `headless/*.disp.log`. It cannot; the only writer
   of those names is `run_regression.tcl` itself.
2. **CLAUDE.md's "confirm the log's MTIME moved" bullet has a known hole** (1477): a run
   killed mid-write moves the mtime *and* leaves a truncated file that reads green. The
   bullet should point at 1477.
3. **NEW — three stale `:294` citations.** E3's added rows moved
   `test_ase_bus_bits_0159.tcl`'s banner from `:294` to `:540`, and it is cited by
   `tests/banner_rule.tcl:50`, `tests/headless/test_audit_classifier.tcl:280` and
   `tests/headless/full_audit.sh:211` — **all three on E3's do-not-touch list**. All are
   comments, so nothing reddens; E3 updated the two it was permitted to (0805's, and
   `test_rdw_keys_1245.tcl`'s, re-running that suite green at `ALL PASS (92 checks)` to
   prove the comment edit inert). The `:129` citations in three other suites were
   **already stale before E3 arrived** — left alone deliberately.

## Candidate, not scheduled

1478: make the lock's **fail-open warning write into the verdict** rather than only to
stdout — a run that proceeded UNLOCKED leaves no trace in "the only place the answer
is".

## Resume point

Next: **F1** (final documentation pass, all three OWED items), then the **final solo
T1** covering everything the companions touched — E1 moved `banner_rule.tcl`, which
`run_regression.tcl` sources live, and two CI-gated classifiers; E2 moved a CI-gated
suite.
