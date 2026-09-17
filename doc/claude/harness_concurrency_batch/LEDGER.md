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

## Companions

| id | task | status | commit | result | issues |
|---|---|---|---|---|---|
| **E1** | 0805 + 0802 bundle | **DONE** | `b3cc484c` | classifier **69 → 75 checks**; CI gate 15/0 rc 0; **0805's own fix was a regression** | 0805, 0802 |
| **E2** | 0408(a) | **DONE** | — | **157 → 161 checks**; **8 of 20 bad → 0 of 40**; CI gate 15/0 rc 0 | 0408(a) |
| **E3** | 1332-residual | queued | — | — | — |

## ⚠ E2: THE CREW CAUGHT ITSELF RE-CREATING THE DEFECT IT WAS TESTING

E2's **first** `W3` row planted a sentinel at the shared legacy path to prove a
collision. Green sequentially — **4 of 20 bad under concurrency**, every one
`W3 -> {DELETED}`. **The row written to detect a fixed-path collision was itself a
fixed path in a shared directory**, and would have shipped a 20% flake into a
**CI-gated** suite. Rewritten to *observe* (glob) rather than plant.

⚠ **It was diagnosable in one grep only because the detail string reported `DELETED`
rather than a canned sentence.** That is D2's work paying for itself two tasks later:
an honest detail string turned a mystery flake into a one-line diagnosis.

## ⚠ E2 refuted 0408's own reasoning about part (b)

0408 states that a collision "aborts the script, it does not return a wrong agreement
count". **It does.** Two collided runs returned `V22 -> {1}` — part (b)'s exact shape
and one of its two recorded values. `rotflip` returns `"?"` when it parses the peer's
file, `V22` scores a disagreement, and the tier drops 157 → 156 **silently**.

Part (b) stays OPEN per scope, but its recorded next step is now **"re-run the V22 loop
with (a) fixed"** rather than hunting a second, independent cause. The "unexplained
non-determinism" may simply *be* part (a).

## E2's other measurements

* **The defect was worse than filed:** 10 concurrent pairs → **8 of 20 runs bad**. Six
  aborted on `couldn't open … _label_ride_rf.sch` **and exited 0 with no `RESULT:`
  line** — a silent pass to any exit-code reader. Two returned *wrong answers*.
* **The "next sequential run stays red" half did NOT reproduce.** Five planted
  stale-fixture flavours (content, zero-byte, read-only, directory, non-empty read-only
  directory) all gave `ALL PASS (157)`: `rotflip`'s leading `file delete -force`
  defeats every one. Fixed anyway — **nobody should spend time reproducing it.**
* **All six cited line numbers were exact** — no drift, contrary to the driver's
  warning. The driver's caution was unnecessary this time and is recorded as such.
* **The fix is `test_scratch` from `scratch.tcl`, not a bare pid path**, for measured
  reasons: nothing outside `rotflip` reads the fixture, so **no publish-back** (unlike
  B1); `.gitignore:84` is directory-only, so all three candidate paths are NOT IGNORED;
  and `_label_ride_rf_[pid].sch` **matches `full_audit.sh:381`'s glob**, which `ls -1d`
  applies to files — a leak would have been a *fatal* audit failure. B1's
  wiped-parent trap was **checked, not assumed**: nothing wipes `tests/headless/` or
  `.scratch/` wholesale.
* Green sequentially, after the concurrent rounds, with `DISPLAY` unset, and after a
  `kill -9` that left no corpse in the tracked tree.

## ⚠ A PLAN omission the driver should not repeat

`test_label_ride` is one of the **15 CI-gated suites** (`ci.yaml:68`,
`AUDIT_MIN_PASS=15`) and the PLAN's E2 row never said so. E2 ran that gate exactly as
CI does anyway: **15 pass, 0 fail, floor met, rc 0**, `SCRATCH: 0 leaked`, `TREE: 0
appeared 0 vanished`. **Both companions so far have turned out to touch CI-gated
files** — E3's brief must state the gate status up front rather than leaving the crew
to discover it.

## ⚠ OWED — carry into the final documentation pass

1. **`0905`'s closure text (in `1a46c800`) carries a claim D3 refuted** — that a
   standalone suite on `:99` can race `headless/*.disp.log`. It cannot; the only writer
   is `run_regression.tcl` itself.
2. **CLAUDE.md's "confirm the log's MTIME moved" bullet has a known hole** (1477): a run
   killed mid-write moves the mtime *and* leaves a truncated file that reads green.

## Candidate, not scheduled

1478: make the lock's **fail-open warning write into the verdict** rather than only to
stdout — a run that proceeded UNLOCKED leaves no trace in "the only place the answer
is".

## Resume point

Next: **E3** (1332-residual — `test_ase_bus_bits_0159.tcl:277,285`, and **state its CI
gate status in the brief**), then the final documentation pass carrying both OWED
items, then a final solo T1.
