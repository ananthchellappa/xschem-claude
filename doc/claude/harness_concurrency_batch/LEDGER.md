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
| **D3** | file the residuals | **DONE** | `9dffeed4` | **1477, 1478, 1479** minted, pointer → 1480; **one residual refuted** | 1477–1479 |

## Companions

| id | task | status | commit | result | issues |
|---|---|---|---|---|---|
| **E1** | 0805 + 0802 bundle | **DONE** | — | classifier **69 → 75 checks**, `ALL PASS (75)` ×2; CI gate 15/0 rc 0; **0805's own prescribed fix was WRONG** | 0805, 0802 |
| **E2** | 0408(a) | queued | — | — | 0408 |
| **E3** | 1332-residual | queued | — | — | — |

## ⚠ E1: THE THIRD ISSUE FILE THIS BATCH WHOSE PRESCRIBED FIX WAS WRONG

0805 prescribes anchoring the arm "with the same optional-trailer tolerance the other
two readers use". That is right for `OVERALL: ok` and **wrong for `RESULT: ALL PASS`**:
`test_ase_bus_bits_0159.tcl:294` emits

    RESULT: ALL PASS (12 checks, 2 group(s) skipped)

— an **inner parenthesis inside the trailer**. `\([^)]*\)` stops at that inner `)` and
scores a **green shipped suite FAIL**. That is a *live regression*, not the latent
divergence 0805 is actually about.

So the two arms deliberately differ: `OVERALL: ok` keeps `\([^)]*\)`, byte-identical to
`run_suites.sh` and asserted by K20; `RESULT: ALL PASS` takes `\(.*\)`, which the other
two readers cannot constrain because **neither implements that spelling**.

**Tally: 0867, 0990 and now 0805 — three of this batch's issue files confidently
prescribed a fix that was a no-op or a regression.** The lesson is no longer an
anecdote: **a fix shape in an issue file is a hypothesis, not an instruction.**

**E1 proved it the right way round** — it reddened row `C47` by *first applying 0805's
prescribed fix* (`-> {NO} (exp {YES})`) and only then correcting it. The wrong fix was
used as the sabotage.

## The unresolved "0354 H4" warning — resolved, and the repair was SMALLER than sized

Section H's rows are labelled **C30–C34**; `H1`–`H4` are *issue sub-item* labels, not
check names. The row meant is **C33**, and it needed **no repair at all**: its literal
is mid-line, so the column-0 anchor already rejects it. The `&& ! is_pass` clause was
**dead weight, not a gate**, so no red phase over section H was needed.

## E1 verification

Classifier suite `RESULT: ALL PASS (75 checks)` **twice identically** (baseline 69,
also ×2). Six new rows, each observed red first with a detail string reporting what was
*observed* — e.g. K20 names the diverging fixtures (`{R_OKAY tcl=NO sh=NO
full_audit=YES} {R_TAB …}`) rather than printing a bare 0/1. C46 and K22 are
anti-overshoot rows, never red, **declared as such with the reason they are kept**.

End-to-end `full_audit` over every banner shape the changed arm sees: **6 pass, 0 fail,
rc 0**. **CI headless gate exactly as `ci.yaml` runs it: 15 pass, 0 fail, floor met,
rc 0** — that is 0802's acceptance item 3. `test_grid_toggle_sel_gc` scored **SKIP**
under no display, so the skip path is intact rather than a hollow pass.
`test_regression_concurrency_1476` — which `file copy`s `banner_rule.tcl` — still
**PASS, 20 checks**.

Two facts the driver checked independently: **`banner_rule.tcl`'s procs are
byte-identical** (comments only), which matters because `run_regression.tcl` sources it
live and T1's baseline is zero; and **`full_audit.sh`'s entire code delta is 2 lines.**

## ⚠ OWED — carry into the final documentation pass

1. **`0905`'s closure text (committed in `1a46c800`) carries a claim D3 refuted** — that
   a standalone suite on `:99` can race `headless/*.disp.log`. It cannot; the only
   writer of those names is `run_regression.tcl` itself. A closed issue with a wrong
   sentence is how the next reader inherits the error.
2. **CLAUDE.md's "confirm the log's MTIME moved" bullet now has a known hole** (1477): a
   run killed mid-write moves the mtime *and* leaves a truncated file that reads green.
   The bullet should point at 1477.

## Candidate, not scheduled

1478 argues the cheapest useful next change is making the lock's **fail-open warning
write into the verdict** rather than only to stdout — a run that proceeded UNLOCKED
currently leaves no trace in "the only place the answer is".

## Resume point

Next: **E2** (0408a — part (a) only), then **E3** (1332-residual), then the final
documentation pass carrying both OWED items, then a final solo T1.
