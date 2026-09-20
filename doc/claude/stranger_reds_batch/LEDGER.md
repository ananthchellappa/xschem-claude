# Ledger — stranger reds batch

| stage | item | crew | receipt | verdict | commit |
|---|---|---|---|---|---|
| setup | — | driver | this file | batch opened 2026-09-20 | |
| A impl | 1485 | crew (workflow) | receipts/A-impl.md | nine suites green in a `git archive` export and a `.git`-removed clone; 1284 checks, none skipped; sabotages S1/S2 red by name | |
| A verify | 1485 | two adversarial crews | receipts/A-verify.md | 12 findings, 1 blocker + 3 must; the blocker was a user's own saved bench reddening four exact-count rows | |
| A fix | 1485 | crew (workflow) | receipts/A-impl.md (fix round) | 9 applied, 3 rejected (2 filed as D4); all nine green in four trees, 1284 checks each | |
| A gate | 1485 | driver | tests/results.3921145.log | T1 solo: cases=87 blocks=86 counted_failures=0, 87/87 Start/Finish, wc -l 177, home=throwaway | 1f3f5287 |
| A docs | 1485, 1484 | docs crew | the issue files | 1485 closed as fixed; 1484 widened and given item A's two measured facts; 1490 and 1491 filed; NUMBERING.md now points at 1492 | |

