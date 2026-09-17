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
| **F2** | stale citations | **DONE** | `c9c50562` | **briefed as 2, found 9** | 1477–1479, NUMBERING |
| **F3** | last stale citations | **DONE** | — | **briefed as 4, found 43** across 30 comment lines | — |

## ⚠ A DRIVER ERROR: I COMPRESSED A RECEIPT AND THEN BRIEFED FROM MY COMPRESSION

F2's receipt said, in full, that `doc/claude/issues/0663-*.md` lines `:149/:201/:241`
were worth fixing. **I compressed that into the LEDGER as `0663:149/:201/:241`**, which
F3's brief then read as the *suite* `test_startup_guard_0663.tcl`. Those `.tcl` lines
carry **no citations at all** — they are `set sg_xtcl [...]`, a check-name
continuation, and a blank line.

**The lossy step was mine, not the crew's**, and it is the same failure mode as
everything else in this batch: a second-hand summary treated as a source. The ledger is
a *pointer* to receipts, and a brief must be written from the receipt.

## ⚠ F3: A CLASS OF ERROR F2's METHOD STRUCTURALLY COULD NOT SEE

**Two citations were never correct — authoring errors, not drift.** F2 diagnosed by
comparing against the authoring commit, so it would have scored both "sound":

* `banner_rule.tcl:68` → `test_ihp_sg13g2_libmgr:195`: that banner was at **`:218`** *at
  `banner_rule.tcl`'s own creation commit* `237fc966`.
* `test_startup_guard_0663.tcl:360` → `xinit.c:1535`: the `has_x` condition was at
  **`:1537`** at both `8d2bc871` and its parent. It is `:1543` today.

**A method that checks "has it moved since it was written?" cannot see a citation that
was wrong when written.** The only check that catches both is reading what is actually
at the line today.

Scale: **43 stale numbers across 30 comment lines**, including citations with **no file
extension** (`test_pdk_launcher:119`) that an extension-anchored regex misses. Largest
block: `src/xschem.tcl`'s bare sources moved **+2576** (`:14568` → `:17144`) across 41
commits and +3643 lines.

## ⚠ A LIVE FALSE RED ON THE USER'S BOX — `test_startup_guard_0663`

`2 FAILED (20 passed)` at HEAD **because of the user's `~/.xschem`, not the tree.**
Measured both ways: with a clean HOME it is **`RESULT: ALL PASS (22 checks)`**, rc 0.

The three `#! ` lines a "healthy" startup writes are **ASE-L registry warnings**: `stub`
→ `/tmp/stage11/e2e/bin/sim` and `slowstub` → `/tmp/stage11/kp/bin/slowsim`, both now
gone, plus `src/xschem` registered as simulator `ng-cm3`. `sharefarm.tcl:87` launches
children with the parent's environment and `scratch.tcl` deliberately does not redirect
`USER_CONF_DIR`.

**T1's zero baseline is unaffected** — this suite is not in `run_regression.tcl`'s case
list — **but it is a live false red for `full_audit.sh`**, which globs the file.

**Filed as a ruling debt for the user** (⚖ R2): prune the three dead
`~/.xschem/ase_simulators` entries, or isolate the suite from the registry. **F3
recommends isolating**, because pruning fixes this box and leaves the next developer to
inherit the same false red. **Not implemented**: redirecting `USER_CONF_DIR` in
`scratch.tcl` reaches 169 suites and is a design change deserving its own scoped work,
not a tail-end patch on a closing batch.

## F3's proofs

Line counts **136 → 136** and **435 → 435**; non-comment lines diff **0** against `HEAD`
in both; **0** non-comment additions; `+30 / −30`. Suites before vs after on `:99`:
`test_audit_classifier` `ALL PASS (75 checks)`, `test_startup_guard_0663`
**byte-identical output**, `1476` `ALL PASS (20 checks)`. F3 also caught two errors in
its **own draft receipt** and re-derived F2's `:328-330` rather than inheriting it.

## Owed — F4, genuinely the last content task

1. **`FIFTEEN` is now eighteen.** `src/xschem.tcl` has **18** bare sources;
   `op_param_lists`, `results` and `rdw` are named nowhere. F3 renumbered the fifteen
   cited lines but deliberately did not touch the count, because fixing it means adding
   helper names — content, not a citation. ⚠ **The block therefore now carries
   freshly-verified numbers under a false count — the exact shape F2 warned about.**
2. **Four citations sit inside `check "…"` name strings** (`:217`, `:279`, `:287`,
   `:310`), so editing them would have broken F3's comment-only proof. Replacements are
   measured and listed in its receipt; they currently **disagree with the comments above
   them.**

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", adopted repo-wide in one deliberate pass** — now
   supported by F2's evidence *and* by F3's, which showed 43 stale numbers in two files
   alone.

## Resume point

Next: **F4** (the two items above), then the **final solo T1**.
