# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

| id | task | crew status | commit | result | issues |
|---|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline recorded; R1 filed as a ruling debt against 0990 | — |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, identical across 4 runs | 1476 |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 RED → 2 RED**, `2 FAILED (18 passed)` in **10 of 10** runs | 0867, 0990, 0384(part) |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 RED → 0**, `ALL PASS (20 checks)` rc 0, **18 of 18** runs | 0955, 0905, 0384(rest) |
| **V1** | solo T1 verification | **DONE — GREEN** | — | **84 cases** (`Start=84 / Finish=84`), **374.6 s**, **ZERO counted failures**, **rc 0** | — |

## V1's verdict, in full

**Not a fossil, and the diff is exactly two lines.** `results.log` mtime moved
`1789624370` → `1789629728`; the md5 changed (`8456b56c…` → `cb8b3911…`) *because
content changed* — the diff against the pre-batch baseline is the new suite's log name
and its `Total num fail: 0`, nothing else. Zero by all four counted shapes, and all 83
`Total num fail:` lines are 0. **83 log lines against 84 cases confirms the "one fewer
by design" rule.**

**The new suite passed INSIDE T1**, not merely standalone — its own case log carries
`RESULT: ALL PASS (20 checks)` and `OVERALL: ok`. The lock was caught working live
during the run (owner record `1722617 1789629353 run_regression.tcl`) and released
after. rc 0 on the ordinary path is **structural**: `exit 2` at `:546` is the only
`exit` statement in the driver.

**Preconditions measured, not assumed.** The `pgrep` hits were another user's idle
xschem in `/opt/xschem-repo` (**uid 1001, not `analog`**, 25 h idle, 0.0% CPU) plus V1's
own shell matching its own pattern. Binary current (`make -C src` → `Nothing to be
done`). Bounded by `timeout 1800` plus a Monitor arming DONE/STALL/DEADLINE.

**Residue: none — and the check is evidence, not a blind command.** All five residue
classes are gitignored, so `git status` is *structurally blind* to them. V1 swept with
`find`/`ls`, then **planted a decoy, confirmed the sweep detected it, and removed it**.

## ⚠ The hcases disagreement — settled, and BOTH numbers were right

**C1's 69 is the `hcases` entry count.** The driver's **75** counted *lines* containing
`"headless/` across **both** `hcases` and `dcases` — 76 entries on 75 lines, because
line 309 carries two. Settled from the run itself: 69 + 11 + 3 + 1 = **84**, and
pre-batch 68 + 11 + 3 + 1 = **83**, reproducing CLAUDE.md exactly. **The driver's crude
greps have now been wrong twice** (16 vs 20 checks; 75 vs 69 entries). Both times a
crew settled it from the run's own output. Drivers should stop grepping for counts.

## ⚠ V1's two corrections to its own brief

1. **The briefed ~418 s did not reproduce: 374.6 s — 35 s FASTER than the 410 s
   baseline.** V1 did not measure that baseline, it is one run, and load is
   uncontrolled, so this is recorded as **UNATTRIBUTED**. **Do not write that this
   batch made T1 faster.**
2. **The brief's netlisting "~1464–1472" was wrong, and it is a category error rather
   than a regression.** The log reports `[llength $pathlist]` — *planned* files — and
   says **1488 before and 1488 after, unchanged**. The tree's **1468** is *landed*
   files; the 20-file gap is jobs exiting 10, the expected-netlist-error path, which
   append to `pathlist` without producing a file. `create_save` 10 and `open_close`
   1898 are likewise identical to baseline.

## ⚠ Scope discovered for the written record

**At least SEVEN rows in the suite carry detail strings that lie on the green path** —
C1 found one, V1 found the count is higher and calls its own number a lower bound, not
an audit. The worst is **`D2a`**: an `ok:` row whose detail reads `no MINI-RESULT
line`, asserting the very absence that would make it red. This is bigger than C1
scoped it and is dispatched as its own task (**D2**), not folded into the prose work.

## Owed to the written record (task D1)

* **CLAUDE.md, two corrections.** The run is now **84 cases / 83 log lines**, not 83/82
  — keeping the lesson (count `Start`/`Finish` pairs, never log lines) while fixing the
  number. And `run_regression.tcl` **no longer "exits 0 whatever happens"**: a refused
  run exits **2** and writes nothing. Also the "⚠ RUN `run_regression.tcl` SOLO"
  paragraph, which still says 0990 is unfixed.
* **Describe the built shape correctly.** Not "it now takes a lock" — that sentence is
  wrong in the direction that loses data. Refusal by default; waiting opt-in; the
  waiting path *preserves* the prior verdict as `results.<pid>.log`.

## Resume point

Next: **D1** (the written record), then **D2** (the lying detail strings), then a final
solo T1, then companions E1/E2/E3.
