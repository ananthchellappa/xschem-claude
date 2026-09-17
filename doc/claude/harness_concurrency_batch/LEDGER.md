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
| **E3** | 1332-residual | **DONE** | `36226c0c` | **40 → 43 checks**; 12/12 clean, **8/8 under load**; reddened under **two** sabotages | 1332 |
| **F1** | final documentation pass | **DONE** | — | all three OWED items closed; comment-only, **proven not asserted** | 0905, 1477, 1478 |

## ⚠ F1: A CITATION WRITTEN DOWN *AS A CORRECTION* WENT STALE INSIDE THE SAME BATCH

D3's refutation cited `full_audit.sh:438-440` as the capture site. **Today those lines
are `:475-485`** — because **E1's `b3cc484c` added lines to that file after D3 measured
at `aa0e2213`.** Under a day, inside one batch, in a sentence whose entire purpose was
to correct an earlier error.

F1 wrote the re-measured numbers into 0905 but **left `1478`'s copies at `:41` and
`:192` stale**, judging the 1477/1478/1479 fence to be about their *defects* rather than
their citations. **Driver: that is two one-line fixes and they are dispatched as F2** —
a just-filed issue carrying a known-stale citation is exactly the rot this batch exists
to be about.

## F1's work, re-measured rather than inherited

* **0905's closure corrected.** D3's refutation re-verified from scratch and it holds:
  the only writer of `headless/*.disp.log` is `run_regression.tcl`
  (`:669, 671, 691, 696, 700, 704`). The paragraph now leads with the refutation, names
  the real residual (four fixed names, the `:502-505` fail-open lock, `:661-662`'s
  shared `--logdir`), and points at 1478.
* **CLAUDE.md's MTIME bullet (`:138-156`).** The rule is **re-affirmed first**, with
  V2's disagreeing mtime/md5 result quoted as its justification, *then* the 1477 hole:
  **mtime proves a run WROTE, not that it FINISHED.** F1 reproduced 1477's measurement
  independently — zero counted failures at 1/10/40/80/120/170 lines, `-buffering full`,
  `-buffersize 4096`, no `fconfigure` anywhere. **The actionable addition is a second
  gate: pair the mtime with the case count** (83 `Total num fail:` lines for today's 84
  cases).
* **The three `:294` citations → `:540`**, verified against the real emitter (line 540
  of 545).

**Comment-only, proven rather than claimed:** non-comment lines diffed against `HEAD`
are **identical** in all three files, line counts unchanged (136 / 572 / 811). Sharper
still for `full_audit.sh`: the classifier's only extractions from its source key on
`line_has '…'` **shell syntax**, which cannot occur in a comment.

**Verification with a pre-edit baseline**, so "nothing moved" is a comparison rather
than an assertion: `ALL PASS (75 checks)` and `ALL PASS (20 checks)` **both before and
after**; CI gate exactly as `ci.yaml:68-74` → `SUMMARY: 15 pass 0 fail 0 crash/timeout
0 skip`, rc 0; `results.log` byte-for-byte V2's throughout.

## ⚠ A convention decision F1 declined to take unilaterally — and measured why

E3 adopted "cite the emitter, not the line". F1 **deliberately did not** propagate it,
with arithmetic rather than taste: it costs a line each, and a line added above
`test_audit_classifier.tcl:280` drifts `:295-296`, which `test_startup_guard_0663.tcl:232`
**pins by number**; a line above `banner_rule.tcl:50` drifts `:107` (cited twice by
1479) and `:82-124` (cited by 1477). **Fixing drift by creating drift, in files four
issue files cite by line, is the wrong trade at crew level.** All three edits are
therefore line-count-neutral. Adopting the convention deliberately and everywhere at
once is worth doing and is recorded here as a candidate, not smuggled in.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout — a
   run that proceeded UNLOCKED leaves no trace in "the only place the answer is".
2. **"Cite the emitter, not the line", adopted repo-wide in one deliberate pass.**

## Resume point

Next: **F2** (1478's two stale citations), then the **final solo T1** covering
everything the companions touched.
