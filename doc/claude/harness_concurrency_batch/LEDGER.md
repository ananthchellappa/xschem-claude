# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

## ✅ MAIN TASK COMPLETE AND CERTIFIED — 2026-09-17

All four faces closed, five issues resolved, four minted, verified twice by solo T1 —
the second time on the **committed** tree.

| id | task | crew status | commit | result | issues |
|---|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline recorded; R1 filed as a ruling debt against 0990 | — |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, identical across 4 runs | 1476 |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 RED → 2 RED**, **10 of 10** runs | 0867, 0990, 0384(part) |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 RED → 0**, `ALL PASS (20)` rc 0, **18 of 18** runs | 0955, 0905, 0384(rest) |
| **V1** | solo T1 verification | **DONE — GREEN** | `d4946b61` | **84 cases**, 374.6 s, **ZERO failures**, **rc 0** | — |
| **D1** | the written record | **DONE** | `1a46c800` | 1476 minted; 5 closed; **five** CLAUDE.md corrections | 1476 + the five |
| **D2** | the lying detail strings | **DONE** | `d35db718` | **12 of 20 rows lied on the green path**; 16 rewritten | — |
| **V2** | closing solo T1 | **DONE — GREEN** | `aa0e2213` | **84 cases**, 375.0 s, **ZERO failures**, **rc 0**, committed tree | — |
| **D3** | file the residuals | **DONE** | — | **1477, 1478, 1479** minted, pointer → 1480; **one residual refuted** | 1477, 1478, 1479 |

## ⚠ D3 REFUTED A RESIDUAL THE DRIVER, D1 AND 0905's CLOSURE ALL ASSERTED

The brief, D1's correction 5, and 0905's closure text all say a standalone suite on
`:99` can race `headless/*.disp.log` against a live T1. **Measured repo-wide: it
cannot.** The only writer of those names anywhere is `run_regression.tcl` itself
(`:669, 671, 691, 696, 700, 704`). `devdisplay.sh cmd_exec:399-403` does no
redirection; `run_suites.sh:123` and `full_audit.sh:438-440` capture into a shell
variable; `scratch.tcl` is already pid-qualified.

The residual is real but **its subject is different**: four fixed names
(`<case>.log`, `headless/<case>.log`, `headless/<case>.disp.log`, and the display arm's
shared `--logdir` at `tests/results/.actionlogs`) whose only guard is a lock
**documented to fail open** — `:502-505` proceeds UNLOCKED after four attempts. 1478
opens with the correction.

**⚠ OWED: `0905`'s closure text (committed in `1a46c800`) still carries the refuted
claim.** A closed issue with a wrong sentence in it is how the next reader inherits the
error. To be corrected in the batch's final documentation pass.

## The three issues D3 minted

* **1477 (high) — 0905 shape (3), the mid-write death.** Measured on a copy of the real
  verdict: **every prefix scores 0 counted failures** (1, 10, 40, 80, 120, 170 lines),
  because all four counted shapes at `:327` need a line to *exist*.
  ⚠ **It defeats the one rule CLAUDE.md tells you to trust: the mtime MOVES**, because
  the run really did write. And it is worse than a plain prefix — the channel is never
  `fconfigure`d, so it is **full-buffered at 4096 B** while the whole verdict is
  **4785 B**. A killed run therefore leaves **0 or 4096 bytes**, which makes 0905's
  original 0-byte sighting the *typical* outcome rather than an extreme one.
* **1478 (low/latent)** — the four fixed log names above, guarded only by a fail-open
  lock.
* **1479 (medium) — 0384's candidate 2.** On verbatim-extracted shipped source,
  `job_status_reason` returns a bare `exit $rc` for **126 / 127 / 139 / 143 alike**, all
  scoring `counted=1` — so "the binary never executed" is indistinguishable from "the
  product SIGSEGVed".

## One number or three — D3 chose three, and the reasoning is worth keeping

One number per **mechanism**, not per theme: three files, three fixes, three
severities, no shared line of code, each independently closable. **The batch's
five-numbers-for-one-mechanism tale argues against duplicating a mechanism, not for
merging distinct ones** — and the merge error has its own track record right here:
0905 folded its second sighting in rather than minting it, and that is precisely the
residual nobody acted on for seven weeks **and** the one that turned out to be
described incorrectly.

## ⚠ Three corrections D3 leaves for whoever fixes these

1. **`signal 15` is the wrong string** to implement 0384 against: jobs record **143**
   via `echo $?`. `FATAL: signal N` is a different channel entirely
   (`src/main.c:58` → `banner_died`).
2. **An `INFRA:` line must stay COUNTED.** Making it non-counting means a run in which
   *every* job failed to start reports zero — which is exactly issue **0147**. This is
   the likeliest way to "fix" 1479 and ship a quieter harness instead of a truthful one.
3. **0905 shape (3) needs two amendments**: under full buffering the rule must be
   "**no END → HARNESS**", never "START without END"; and `banner_rule.tcl` has **no
   run-level predicate** today (all three procs are per-case), so this would be a new
   consumer of a file locked by `test_audit_classifier.tcl` **section K** — which D3
   did **not** verify tolerates an added proc, and said so rather than assuming.

Every proposed fix in all three files is labelled **PROPOSED AND UNMEASURED** in those
words, per the lesson that two of the original five issues confidently prescribed a fix
that does nothing.

## ⚠ OWED to CLAUDE.md, from 1477

CLAUDE.md's "confirm the log's MTIME moved" bullet — reinforced by D1 and demonstrated
by V2, whose mtime and md5 tests disagreed outright — now has a **known hole**: a run
killed mid-write moves the mtime *and* leaves a truncated file that reads green. The
bullet should point at 1477. Final documentation pass.

## Candidate, not scheduled

1478 argues the cheapest useful change may be making the lock's **fail-open warning
write into the verdict** rather than only to stdout: a run that proceeded UNLOCKED
currently leaves no trace in the file that is "the only place the answer is". Recorded
here rather than dispatched, because the agreed remaining scope is the three
companions.

## Resume point

Next: **E1** (0805 + 0802, one bundle), then **E2** (0408a), then **E3**
(1332-residual), then a final documentation pass carrying the two OWED items above,
then a final solo T1.
