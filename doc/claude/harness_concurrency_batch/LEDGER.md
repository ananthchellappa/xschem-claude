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
| **D3** | file the residuals | **DONE** | `9dffeed4` | **1477, 1478, 1479** minted, pointer → 1480 | 1477–1479 |

## Companions — ALL THREE DONE

| id | task | status | commit | result | issues |
|---|---|---|---|---|---|
| **E1** | 0805 + 0802 bundle | **DONE** | `b3cc484c` | classifier **69 → 75 checks**; CI gate 15/0; **0805's own fix was a regression** | 0805, 0802 |
| **E2** | 0408(a) | **DONE** | `b46892d6` | **157 → 161 checks**; **8 of 20 bad → 0 of 40**; CI gate 15/0 | 0408(a) |
| **E3** | 1332-residual | **DONE** | `36226c0c` | **40 → 43 checks**; 12/12 clean, **8/8 under load**; **two** sabotages | 1332 |
| **F1** | documentation pass | **DONE** | `bb069d89` | three OWED items; comment-only, **proven** (0 non-comment lines) | 0905, 1477, 1478 |
| **F2** | stale citations | **DONE** | — | **briefed as 2, found 9** | 1477, 1478, 1479, NUMBERING |

## ⚠ F2: "THE BRIEF SAID TWO STALE CITATIONS. THERE WERE NINE."

The two it was sent for (`1478:41`, `:192`) were right, and **re-derived rather than
trusted**: `out=$(` sits at `475,477,481,483,485` today against `438,440,444,446,448`
at `aa0e2213` — a **+37** shift. Today's `:438-440` is `fi` / blank /
`PASS=0 FAIL=0 CRASH=0 SKIP=0`.

**Six more had the same cause and the brief did not anticipate them.** `b3cc484c` also
grew `tests/banner_rule.tcl` from 124 to 136 lines: `1479:75,:180`
(`banner_rule.tcl:107` → **`:119`**), `1479:82,:181` (`:115-118` → **`:127-130`**), and
`1477:168,:201` (`:82-124` → **`:92-136`**). A **ninth** sat in
`NUMBERING.md:3517`, repeating 1478's sentence verbatim, stale pair included.

### ⚠ The 1477 citation is the one to remember

`banner_rule.tcl` grew **+10 above `banner_complete` and +2 more below it**, so
`banner_complete` moved +10 (82→92) while `banner_died` moved +12 (106→118).
**The natural repair — assume a single offset and write `:82-136` — is wrong at the
start**, and today's `:82` lands on a bare `#` inside a comment block, **so it reads as
plausible**. A one-offset assumption would have produced a still-broken citation that
now looked *freshly verified*. Same shape as D1's fossil-84: **a plausible value is not
a measurement.**

Roughly 30 other citations were checked by printing the cited range and found sound.
One judgement call, trivially revertible: `run_suites.sh:123` widened to `:121, 123,
125` to match what F1 wrote into 0905.

## ⚠ F2 REFUTED THE REASONING BEHIND F1's CONVENTION DECISION

F1 declined E3's "cite the emitter, not the line" partly to protect
`test_audit_classifier.tcl:295-296` and `banner_rule.tcl:107` from drift. **Both were
already stale when F1 named them.** The *conclusion* (adopt it deliberately, repo-wide,
in one pass) is **strengthened** — but its supporting fact must not be inherited. That
is the eighth wrong recorded belief this batch, and the second in which the correction
itself was the thing that rotted.

## Owed — F3, the last content task

Three stale citations **outside** `doc/claude/issues/`, numbers measured and ready:

* `tests/banner_rule.tcl:98` cites `full_audit.sh:315-316` for the crash arm → **`:352-353`**.
  ⚠ **F1 edited that very file and missed this.**
* `tests/headless/test_startup_guard_0663.tcl:230` cites `full_audit.sh:316` → **`:353`**
* `tests/headless/test_startup_guard_0663.tcl:232` cites `test_audit_classifier.tcl:295-296` → **`:321-322`**

Plus `0663:149/:201/:241`, which F2 reports live and worth fixing.

**Deliberately NOT to be renumbered: `0802:16`** (`full_audit.sh:311-325`). It precedes
a code block quoting the *pre-fix* source, so it is a historical transcript like
`receipts/E1.md:115`; renumbering without requoting would make it worse.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", adopted repo-wide in one deliberate pass** — now
   with F2's evidence that the counter-argument rested on already-stale citations.

## Resume point

Next: **F3** (the three measured citations above — the last content task), then the
**final solo T1**.
