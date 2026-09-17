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

## Companions and the documentation tail

| id | task | status | commit | result | issues |
|---|---|---|---|---|---|
| **E1** | 0805 + 0802 bundle | **DONE** | `b3cc484c` | classifier **69 → 75**; **0805's own fix was a regression** | 0805, 0802 |
| **E2** | 0408(a) | **DONE** | `b46892d6` | **157 → 161**; **8 of 20 bad → 0 of 40** | 0408(a) |
| **E3** | 1332-residual | **DONE** | `36226c0c` | **40 → 43**; 8/8 under load; **two** sabotages | 1332 |
| **F1** | documentation pass | **DONE** | `bb069d89` | three OWED items; comment-only, proven | 0905, 1477, 1478 |
| **F2** | stale citations | **DONE** | `c9c50562` | **briefed as 2, found 9** | 1477–1479 |
| **F3** | citations outside issues/ | **DONE** | `c7f3cdba` | **briefed as 4, found 43**; two were *never* correct | — |
| **F4** | the false count | **DONE** | — | **briefed as 4 sites, found 7**; two were *arithmetic*, not the word | — |

## ⚠ F4: A CLASS OF STALENESS NO GREP CAN FIND

F3 located the false "FIFTEEN" at four sites. There were **seven**. F4 found a missed
`:9`, a `:275` that was really `:277`, and — the two that matter — **`:295` "Sixteen
`catch` wrappers"** (15 bare + 1) and **`:300` "the seventeenth helper nobody has added
yet"** (16 + 1).

**Those are arithmetic DERIVED from the count, not the word itself. A crew grepping for
`fifteen` cannot find either.** Corrected to Nineteen and twentieth.

And the sentence at `:300` had already been overtaken by events: it promised the
backstop would cover "the seventeenth helper nobody has added yet". **Three have since
arrived** — `op_param_lists`, `results`, `rdw` — it covered all three silently, and
nobody updated the prediction. Those are exactly the three the block had never named.

## F4 solved the drift-by-fixing-drift problem instead of accepting it

F3 judged the block had no room for three more names, and **on lines 3–9 alone F3 was
right**: +53 characters of payload against 47 of slack at 80 columns, six short. F4
reflowed the **whole paragraph** (`3-19`, which carries ~114 spare columns at its short
lines 13 and 19) and landed on exactly 17 lines; the `295-301` paragraph is net zero and
re-wraps to 7. **Line-count-neutral, 435 → 435, so nothing shifted.**

It enumerated the inbound citations **before** editing — four repo-wide (`:149`, `:230`,
`:232`, `:360`), all in `doc/claude/` receipts and this ledger, none in code — and
re-printed all four after. **"There is no list of shifted citations to hand you"**,
which is the right ending for this particular tail.

Item 1's proof is not an eyeball: F4 extracted the `:NNNNN name` pairs back out of the
finished comment (joining lines first, since three pairs straddle a line break) and
diffed them against the 18 measured from `src/xschem.tcl` — **identical, 18 each**.

Item 2 (four citations inside `check "…"` name strings) was digit-count-neutral, so it
could not shift a line, and **nothing pins those names** — established by five separate
checks. The entire observable effect is four `ok:` lines reading differently.

**Both arms, both sides:** inherited `$HOME` `2 FAILED (20 passed)` rc 1 before *and*
after; clean `HOME` `ALL PASS (22 checks)` rc 0 before *and* after; `test_audit_classifier`
byte-identical. The two reds are **the same two by name and by measured value** (SG13
`{3}`, SG14 `{0 1 1 0 4}`) — the known R2 config artefact. F4 ran the two arms **serially
inside one shell command**, noting that both guard arms share one scratch dir, so
overlapping them would have reproduced this batch's own subject.

## ⛔ THE CITATION TAIL STOPS HERE — a driver decision

F4 handed over yet another stale set, this time in **product code**: `src/xinit.c:2990-2993`
and `:3025` still say "fifteen helpers" and carry **five** of the exact numbers just
corrected, inside the C comment that explains the fix. Also `test_ase_core.tcl:3314/:3317`.
Replacements are measured and listed in F4's receipt.

**They are deliberately not being patched.** Every pass in this tail found more than its
brief — F2 two→nine, F3 four→forty-three, F4 four→seven — and each fix is one more
hand-maintained number in a repo that has just demonstrated, at length, that
hand-maintained numbers rot. **Patching file-by-file is exactly the trade F1 argued
against.** The structural answer is candidate 2 below, now supported by three
independent measurements.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", adopted repo-wide in one deliberate pass** —
   justified by F2 (9 stale), F3 (43 stale, two never correct) and F4 (7 sites, two of
   them arithmetic no grep can reach). Carries the remaining `src/xinit.c` and
   `test_ase_core.tcl` sites with it.

## Rulings standing with the user

* **⚖ R1** (against 0990) — narrowed by measurement from "wait or don't" to **refuse**
  versus **preserve-and-proceed**. The originally-offered "second run waits" was
  measured to destroy the verdict the lock protects, so it no longer exists in a safe
  form.
* **⚖ R2** (against 0663) — `test_startup_guard_0663` false-reds 2 of 22 on this box
  because `~/.xschem/ase_simulators` holds three dead ASE-L entries. Clean `HOME` is
  `ALL PASS (22)`. **Prune, or isolate the suite from the registry?** Recommendation:
  isolate — pruning fixes this box and the next developer inherits the same false red.

## Resume point

**Final solo T1** — the closing gate. After it, the batch is finished.
