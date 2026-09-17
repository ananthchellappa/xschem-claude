# Ledger — harness concurrency batch

Receipts collected by the driver. One row per dispatched task. A row is added only
when the receipt is in `receipts/` and the driver has read it.

| id | task | crew status | commit | result | issues |
|---|---|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` | baseline recorded; R1 filed as a ruling debt against 0990 | — |
| **A1** | the RED suite | **DONE** | `5114dd8b` | 20 checks, **13 RED / 7 green**, identical across 4 runs | 1476 |
| **B1** | faces 1–3 | **DONE** | `5f7164d4` | **13 RED → 2 RED**, `2 FAILED (18 passed)` in **10 of 10** runs | 0867, 0990, 0384(part) |
| **C1** | face 4, the verdict | **DONE** | `43b40f04` | **2 RED → 0**, `ALL PASS (20 checks)` rc 0, **18 of 18** runs | 0955, 0905, 0384(rest) |
| **V1** | solo T1 verification | **DONE — GREEN** | `d4946b61` | **84 cases**, **374.6 s**, **ZERO counted failures**, **rc 0** | — |
| **D1** | the written record | **DONE** | — | 1476 minted (249 lines); 5 issues closed; NUMBERING + CLAUDE.md corrected. 7 modified (+354/−31), 2 new | 1476, 0384, 0867, 0955, 0905, 0990 |

## D1's corrections — the brief was short by two, and it matters

1. **"Three CLAUDE.md corrections" was wrong; there were five.** Fixing 83→84 would
   have left two *other* sentences in the same bullet false: the fossil parenthetical
   *"(84, where the tree runs 83)"* would have contradicted the paragraph eleven lines
   below it, and the CHECK MTIME bullet said *"a clean **82-case** sweep"* — the exact
   case-count/log-line conflation the bullet above it exists to warn about, and wrong
   in its own era too. **A number appearing in more than one place is a number that
   must be changed in more than one place.**
   D1 also added the observation the driver had not seen: now that the tree really
   runs 84, **the fossil "84" is indistinguishable from today's correct value**, and
   only its mtime ever said otherwise. *A plausible value is not a measurement.*
2. **0867's proposed fix is the same no-op as 0990's.** It proposes
   `results/.work.[pid]` verbatim — the shape A1 measured at **658** phantoms against
   660. **Two of the five issues carried a confidently-worded fix that does nothing**,
   which is a large part of why seven weeks produced no attempt.
3. **`NUMBERING.md:3334` also contains "exits 0 whatever happens"** — left deliberately
   in place, because it sits inside issue 1456's record of what *it* measured then.
   Correcting a historical measurement would be falsifying it. 1476's Related section
   says so instead.
4. Re-measured rather than inherited: the case arithmetic independently
   (bracket-balanced extraction: 3/69/11 at HEAD, 3/68/11 at `5f7164d4`), confirming
   V1 and refuting the driver's 75; the 1476 mint re-checked today; 1477 checked before
   advancing the pointer.
5. **No performance claim appears anywhere.** 374.6 s is labelled UNATTRIBUTED, and
   netlisting is reported log-against-log as 1488 → 1488 unchanged, with the
   planned-vs-landed reason given so nobody re-compares 1468.

## ⚠ DRIVER DECISION — the residuals get filed (D3)

D1 found three things this batch does **not** close and explicitly declined to mint a
number, leaving it to the driver. **Decision: file them.** An unfiled measured defect
is precisely what this batch exists to be about — and the opposite error, a *fix
proposal nobody re-measured*, is what cost the last seven weeks. Filing costs minutes;
rediscovery cost this project three duplicate issue numbers.

To be filed by **D3**, as defects, not as fixes:

1. **0905 shape (3) was not implemented** — the `REGRESSION START/END` sentinel. A run
   **killed mid-write** can still leave a short `results.log` that reads green. The
   *collision* route is closed; the *interrupted-state* route is not.
2. **`headless/*.disp.log` names are still not pid-qualified** (0905's second
   sighting), so a standalone suite on `:99` is enrolled in no lock and **can still
   race a live T1**.
3. **0384's fix candidate 2 landed only in part** — the `exit 126` / `127` /
   `signal 15` → `INFRA:` distinction was not implemented, so "the binary never ran"
   still reports as an ordinary counted failure.

## Owed to the suite (D2)

**At least SEVEN rows carry detail strings that lie on the green path** — V1 calls its
own count a lower bound, not an audit. Worst is **`D2a`**: an `ok:` row whose detail
reads `no MINI-RESULT line`, asserting the very absence that would make it red. `V2a`
(found by C1) hard-codes "the second run announced nothing" on the green path. D2
audits all 20.

## Resume point

Next: **D2** (the lying detail strings), then **D3** (file the three residuals), then a
final solo T1, then companions E1/E2/E3.
