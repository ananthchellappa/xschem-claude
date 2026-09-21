# Ledger — stranger reds batch

| stage | item | crew | receipt | verdict | commit |
|---|---|---|---|---|---|
| setup | — | driver | this file | batch opened 2026-09-20 | |
| A impl | 1485 | crew (workflow) | receipts/A-impl.md | nine suites green in a `git archive` export and a `.git`-removed clone; 1284 checks, none skipped; sabotages S1/S2 red by name | |
| A verify | 1485 | two adversarial crews | receipts/A-verify.md | 12 findings, 1 blocker + 3 must; the blocker was a user's own saved bench reddening four exact-count rows | |
| A fix | 1485 | crew (workflow) | receipts/A-impl.md (fix round) | 9 applied, 3 rejected (2 filed as D4); all nine green in four trees, 1284 checks each | |
| A gate | 1485 | driver | tests/results.3921145.log | T1 solo: cases=87 blocks=86 counted_failures=0, 87/87 Start/Finish, wc -l 177, home=throwaway | 1f3f5287 |
| A docs | 1485, 1484 | docs crew | the issue files | 1485 closed as fixed; 1484 widened and given item A's two measured facts; 1490 and 1491 filed; NUMBERING.md now points at 1492 | |
| B impl | 1483 | crew (workflow) | receipts/B-impl.md | cause located by backtrace (scheduler.c XMaxRequestSize, one statement, all four suites); four suites green headless at 67/85/109/485; T1 headless 87/86/0 and T1 with display 87/86/0, both in the crew's clone | |
| B verify | 1483 | two adversarial crews | receipts/B-verify.md | 14 findings; a blocker and a must, both the same new test row asserting no-display unconditionally (it reds on the display arm, which is the documented spelling) | |
| B fix | 1483 | crew (workflow) | receipts/B-verify.md | row branched on the has_x mirror; 8 checks on every arm; sabotages red on the unfixed binary both ways; 7 findings out of scope, recorded as D6 | |
| B gate | 1483 | driver | tests/results.557418.log | T1 solo: cases=87 blocks=86 counted_failures=0 elapsed=527s, 87/87, wc -l 177, home=throwaway | (this commit) |
| B docs | 1483 and its family | docs crew + driver | the issue files | 1483 closed as fixed; 0227 gains four measured witnesses; 0467's "at teardown" corrected and its closure proposed, not taken; 1492-1495 filed; NUMBERING.md now points at 1496 | |
| C trace+fix | 1484, 1490 | crew (workflow) | receipts/C-impl.md | mechanism traced on two ngspice builds and in ngspice's source; 12 rows named for the capital face, 147 for the space face (1490 said 71); product export 3/6 and 1/6 before, 6/6 after | |
| C verify | 1484, 1490 | two adversarial crews | receipts/C-verify.md | the restore-side `.include` still bare (rc 1 on a space path); control characters lose artifacts silently; one row's attribution refuted; 26 further path shapes round-trip | |
| C fix | 1484, 1490 | crew (workflow) | receipts/C-verify.md | 7 applied, 3 rejected with reasons, 2 verifier claims refuted by measurement; 57 rows greened, none newly red | |
| C gate | 1484, 1490 | driver | tests/results.1030214.log | T1 solo: cases=87 blocks=86 counted_failures=0 elapsed=524s, 87/87, zero peers | (this commit) |
| C docs | 1484, 1490, 1334 | docs crew | the issue files | 1484 and 1490 closed with the traced mechanism and the full row lists; 1490's headline corrected (147 rows across 17 suites, not 71 across five); 1496 filed for the `.include`/`.lib` class; 1334 annotated, status unchanged, ruling left to the user | |
| D land | 1489 | crew (workflow) | receipts/D-impl.md | the D21-approved fixes landed from the prepared candidate; suite 93 -> 101 checks; four false alarms measured red-first then green | |
| D verify | 1489 | two adversarial crews | receipts/D-verify.md | no blocker, no must; ~150 hostile gate invocations, 19 fail-closed fixtures still red, six stranger shapes green with skips named | |
| D fix | 1489 | crew | receipts/D-verify.md | two findings fixed (a capitalised value disarmed the new check; the corpus-driven pass was outside the time budget, 9.6s -> 2.5s on 90 MB), one refused on measurement (D9), two recorded as documented limits; suite 102 checks | |
| D gate | 1489 | driver | tests/results.1188390.log | T1 solo: cases=87 blocks=86 counted_failures=0 elapsed=524s, 87/87, zero peers | (this commit) |
| E impl | 1487 | crew (workflow) | receipts/E-impl.md | the verdict carries each case's skip: lines and check count; trailer states skips= | |
| E verify | 1487 | adversarial crew | receipts/E-verify.md | no blocker; three shoulds, the sharpest being unsanitised carried text able to plant a forged trailer | |
| E fix | 1487 | crew | receipts/E-verify.md | all four carry sites sanitised (the review had named two); banner-only check counts carried for the two suites that state them; F's guard registered, after measuring that it would otherwise have counted a false failure | |
| F impl | 1486 | crew (workflow) | receipts/F-impl.md | suites stop writing untitled~.sch into the working directory; new guard suite and a shared cwd arm | |
| F verify | 1486 | adversarial crew | receipts/F-verify.md | BLOCKER: F's own first fix regressed the product (backup ownership tracked as a boolean where it needs the path); 38 of 406 suites write into their working directory | |
| F fix | 1486 | crew | receipts/F-verify.md | ownership tracked by path, three new rows; overstated claims scoped to the nine suites and five files actually measured | |
| E+F gate | 1486, 1487 | driver | tests/results.2325750.log | T1 solo: cases=88 blocks=87 counted_failures=0 skips=5 elapsed=532s, 88/88 Start/Finish, wc -l 260, zero peers | (this commit) |
| E+F docs | 1486, 1487, 1489 | docs crew | the issue files | 1489 and 1487 closed with what the fix does NOT cover (two documented limits and one kept red; the four sanitised carry sites and `cases=88 blocks=87 skips=5`, `wc -l` 260); 1486 closed only PARTLY, `open=4`, with the boolean-vs-path product regression and the unarmed Tcl driver written into it; **1497** filed for `full_audit.sh`; 0609, 1480 and 1488 annotated rather than re-filed; NUMBERING.md now points at 1498 | |
| CLOSED | all six | driver | PLAN.md §Closing | **batch closed 2026-09-20.** Six items, eight commits: `1f3f5287` (A/1485), `2288d437` (B/1483), `a1314271` (C/1484+1490), `9fcf9177` (D/1489), `c84aee78` (E+F/1487+1486), and the docs commits `2fb377de`, `37b80387`, `04844d23` (plus the brief amendment `0eed8a1b`). Five solo T1 gates, all ZERO counted failures; the last is `cases=88 blocks=87 counted_failures=0 skips=5 elapsed=532s`. Five issues closed, 1486 partial by measurement, eight numbers filed (1490–1497), no item took a fourth round | |
