# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

## ✅ MAIN TASK COMPLETE AND CERTIFIED — 2026-09-17

All four faces closed, five issues resolved, one minted, verified twice by solo T1 —
the second time on the **committed** tree.

| id | task | crew status | commit | result | issues |
|---|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline recorded; R1 filed as a ruling debt against 0990 | — |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, identical across 4 runs | 1476 |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 RED → 2 RED**, `2 FAILED (18 passed)`, **10 of 10** runs | 0867, 0990, 0384(part) |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 RED → 0**, `ALL PASS (20 checks)` rc 0, **18 of 18** runs | 0955, 0905, 0384(rest) |
| **V1** | solo T1 verification | **DONE — GREEN** | `d4946b61` | **84 cases**, 374.6 s, **ZERO counted failures**, **rc 0** | — |
| **D1** | the written record | **DONE** | `1a46c800` | 1476 minted; 5 issues closed; NUMBERING + **five** CLAUDE.md corrections | 1476, 0384, 0867, 0955, 0905, 0990 |
| **D2** | the lying detail strings | **DONE** | `d35db718` | **12 of 20 rows lied on the green path**; 16 rewritten; `ALL PASS (20)`, **4 of 4** runs | — |
| **V2** | closing solo T1 | **DONE — GREEN** | — | **84 cases**, 375.0 s, **ZERO counted failures**, **rc 0**, on the **committed** tree | — |

⚠ **The D2 row read `—` for its commit until V2 caught it.** D2 was committed at
`d35db718` the whole time. The driver's own bookkeeping was the error, found by a crew
reading the ledger rather than by the driver checking it.

## V2 — the closing verification

Run solo as `cd tests && tclsh run_regression.tcl` under `timeout 1800` on the
committed tree at `d35db718`, so it certifies **what is committed, not a dirty tree**.
All four counted shapes grepped separately: `FAIL$` 0, `GOLD?` 0, `RESULT?` 0, leading
`FATAL` 0. 83 `Total num fail:` lines, one distinct value (`0`).

**The gap V2 existed to close is closed.** The 1476 suite passed *inside* T1 —
`results.log:146-147`, case log `RESULT: ALL PASS (20 checks)` / `OVERALL: ok`,
fingerprint **`c1abe627a272`**, identical to D2's standalone fingerprint. V2 also
**proved the edited file is what ran** rather than assuming it: source md5
`8338957824ce` matches D2's post-restore value, the case log grew 4482 → 5481 B, and
the log contains D2-only strings (`per-run-target=1` ×3), including the rewritten
worst-case row `D2a … B said: MINI-RESULT fatals=0 pathlist=1500 present=1500`.

## ⚠ THE FOSSIL TEST PASSED THE INTERESTING WAY — keep this

`results.log`'s mtime moved `1789629728` → `1789632528`, **while its md5 came back
byte-identical to V1's** (`cb8b3911…`, 4785 B both runs). **Had V2 used the md5 as its
fossil test, it would have concluded the run never happened.** This is the sharpest
possible demonstration of CLAUDE.md's "CHECK MTIME, NOT THE MD5" rule — the rule was
written from argument, and is now backed by a measurement in which the two tests
disagree outright.

## Result-file counts, and why the gap cannot redden T1

`create_save` 10 / `open_close` 1898 / `netlisting` **1488**, log against log,
unchanged. V2 strengthened V1's explanation **structurally**: the number is printed at
`test_utility.tcl:313` as `[llength $pathlist]` — *planned* files — and the `RESULT?`
arm that would make a missing file a counted shape sits inside
`if {[file exists $testname/gold]}`. With no gold directory, the ~20-file gap is
**structurally incapable** of reddening T1.

## ⚠ Wall time — report it, attribute nothing

V1 374.6 s, V2 375.0 s. The same number for practical purposes. These two runs support
exactly **one** claim: **registering the 1476 suite did not make T1 measurably
slower.** Nobody may write that this batch made T1 faster — the 410 s pre-batch figure
was taken once, by a different measurer, on an uncontrolled box.

## ⚠ Crude checks: five for five, and the fifth exonerated a predecessor

V2's own `git check-ignore` on a **non-existent** path returned NOT IGNORED, which
looked like a V1 error worth reporting. It was not: `.gitignore:112-117` are
trailing-slash, **directory-only** patterns, so git evaluates an absent path as a
*file*. Settled in a throwaway repo — **V1's table was right.** It is also why the
residue decoy must be a *directory*: a file-shaped decoy cannot match the pattern under
test and would have proved nothing.

Two genuine small V1 slips, corrected: `.gitignore:112-114` is `results.*/`, while
`.work.*/` is `115-117`; and `/proc/<pid>/cwd` is unreadable for a foreign uid, so the
`/opt/xschem-repo` evidence is cmdline-plus-uid, not `/proc`.

**Running tally of the batch's most persistent error: a crude grep or check answering
the wrong question — driver 16-vs-20, driver 75-vs-69, V1's inherited brief numbers,
D2's escaped-vs-unescaped 1→1, V2's non-existent-path check-ignore. Five occurrences,
every one a case where both numbers were correct answers to *different* questions.
Standing rule: take a count from the artefact's own output, never from a grep.**

## CLAUDE.md needs no further edit

D1's `:118` ("84 cases and 83 log lines") and `:88` (rc-2 refusal) both match today's
measurement. The case count agrees across **three independent methods**: `Start`/`Finish`
pairs, a Tcl `llength` over the list literals, and CLAUDE.md's written arithmetic.

## ⚠ DRIVER DECISION — the residuals get filed (D3)

1. **0905 shape (3) not implemented** — the `REGRESSION START/END` sentinel. A run
   **killed mid-write** can still leave a short `results.log` that reads green. The
   *collision* route is closed; the *interrupted-state* route is not.
2. **`headless/*.disp.log` names still not pid-qualified** — a standalone suite on
   `:99` is enrolled in no lock and **can still race a live T1**.
3. **0384 fix candidate 2 landed only in part** — no `exit 126` / `127` / `signal 15`
   → `INFRA:` distinction, so "the binary never ran" still reports as an ordinary
   counted failure.

## Resume point

Main task closed. Next: **D3** (file the three residuals above), then companions
**E1** (0805+0802, one bundle), **E2** (0408a), **E3** (1332-residual), each followed
by its own verification, with one final solo T1 at the end.
