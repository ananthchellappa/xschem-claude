# Stranger reds batch — the outsider audit's remaining red tests

The outsider-fixes batch (closed 2026-09-18) fixed two of the audit's findings and filed
the rest. This batch lands them. Every item is a case where someone who is not this
developer takes the branch we publish and sees red tests, or a real crash, on first
contact.

## Items, in dispatch order

| # | issue | what a stranger sees | class |
|---|---|---|---|
| A | 1485 | a ZIP download or `git archive` export has no `.git`, and nine suites use git's error text as data | test-side |
| B | 1483 | with no `DISPLAY` (a headless box, CI), four suites segfault mid-run; T1's ZERO is a DISPLAY-set ZERO | product crash |
| C | 1484 | a checkout path with a capital letter reds five ASE suites; an unquoted path on an ngspice control line may also lose a user's S-parameter export | product defect (inferred) |
| D | 1489 | the issue-stamp checker false-alarms on honest fence info strings; a ready patch exists | agent-facing |
| E | 1487 | `summarize_all` drops `skip:` lines, so skipped coverage reads as a pass | verdict honesty |
| F | 1486 | suites write `untitled~.sch` into the working directory | tester-facing |

## Acceptance criteria, fixed before the first round (they do not move mid-batch)

1. **Red first, then green, both measured.** Every item shows the defect on the current
   code in the stranger's condition, and the same measurement green after the fix. An
   assertion is not a measurement.
2. **No regression in the developer's condition.** The suites an item touches stay green
   in a normal clone, and T1 stays at ZERO counted failures with `DISPLAY` set.
3. **Fix the cause where the cause is.** A product defect (B, and C if the inference
   holds) is fixed in the product, not papered over in the suite. Say plainly when a fix
   is a test-side workaround and why.
4. **Scope is the issue as filed.** A finding outside it is written down and filed, not
   fixed on the way past.
5. **Rounds are capped: one implement round, one adversarial verify, at most one fix
   round.** If the verifier still finds a real defect after the fix round, the driver
   keeps the verified part, commits it, and files the remainder. There is no round four.
   (The last batch spent about four hours on rounds that shipped nothing.)
6. **Scratch is deleted by the crew that made it**, and each receipt states its peak disk
   use. The last batch left 192 GB behind.

## Gate

The driver runs T1 solo before each commit and reads `T1-RUN-END`; the baseline is ZERO
counted failures. Item B additionally gates on a T1 with `DISPLAY` unset.
