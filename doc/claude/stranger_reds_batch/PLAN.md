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

---

# Closing — 2026-09-20

All six items are dispatched, verified, gated and committed. Every number below is read off
the ledger, the receipts or the gate artefacts; nothing here is re-derived.

## What shipped, and what did not

| # | issue | commit | shipped | did NOT ship |
|---|---|---|---|---|
| A | 1485 | `1f3f5287` | nine suites enumerate the corpus from the filesystem when git cannot answer; 1284 checks kept in an export, in a `.git`-removed clone and in a normal clone | nothing of 1485's; two verifier findings filed instead (**1490**, **1491**) |
| B | 1483 | `2288d437` | the crash itself — one statement, `XMaxRequestSize` on a display the process does not have; four suites green headless at 67/85/109/485 | the rest of the no-display family: **1492**, **1493**, **1494**, **1495** |
| C | 1484, 1490 | `a1314271` | the traced mechanism fixed on both faces (a capital and a space), product export 6 of 6 where it was 3 of 6 and 1 of 6 | `.include`/`.lib` cards from the user's own PDK (**1496**); issue **1334**'s refusal, left as the user's ruling |
| D | 1489 | `9fcf9177` | items 1, 3, 4, 5 **and** 3′, with the repair that made 3′ landable; suite 93 → 102 checks | two documented limits, refused as code with a row pinning each; one kept red, with a reference parser behind it |
| E | 1487 | `c84aee78` | the verdict carries every `skip:` line and every check count; `T1-RUN-END` states `skips=` | the same blind spot in `full_audit.sh` (**1497**) |
| F | 1486 | `c84aee78` | the product no longer deletes a `~` it did not write; the three **shell** drivers redirect the autosave into a private `$PWD`; a 13-check T1 case | **`tests/run_regression.tcl` was never armed** — T1 still writes `tests/untitled~.sch`; 38 of 405 suites still overwrite one on a bare run; nine suites write a `cellName~.sch` into the checkout (all three recorded in **0609**/**1480**) |

Docs commits: `2fb377de` (A), `37b80387` (B), `04844d23` (C), plus the closing one that
carries this section and the 1486/1487/1489 resolutions. Brief amendment: `0eed8a1b`. Five solo T1 gates, every one at ZERO counted failures — `cases=87 blocks=86` for
A through D, `cases=88 blocks=87 counted_failures=0 skips=5 elapsed=532s` for the joint E+F
gate (`tests/results.2325750.log`).

## Retrospective

### The adversarial round earned its cost three times, and never the same way twice

**Item F is the clearest.** Its own first fix **regressed the product**: it tracked backup
ownership as a boolean where the thing being tracked is a path, so `load_schematic()` cleared
the flag and any load between the write and the discard made xschem forget its own `~` — and
the next open offered deliberately discarded edits back as crash recovery. The suite was
`ALL PASS (10 checks)` with the defect live, because `U3` has no load at all and `U4` has no
*intervening* load. Three builds of one tree settled it: pre-1486 **0**, the boolean **1**,
the path **0**. The same round found `go_back()`'s "No" arm one call site on, and measured it
deleting a seeded foreign `descend_child~.sch` in the condition nine suites here run in.
Without the round, this batch would have shipped a fix that destroys a user's crash recovery
in the name of protecting it.

**Item E's was a hole the review only half-saw.** The verifier said the two new carry arms
copy suite text verbatim and could forge a sentinel. True — but a `skip:` or `RESULT:` line
can only forge mid-line, because it starts with its own prefix. The **counted** arm, which
has carried lines verbatim since long before this issue, carries them at **column 0**, where
a forged `T1-RUN-END` is a perfect trailer that even an anchored reader accepts. Sanitising
the two named arms would have left the dangerous one open. Measured on a fixture verdict:
three lines containing `T1-RUN-END` became one, and two anchored ones became one.

**Item D's was a refusal.** The fix round was asked to remove three residual findings; it
removed two and **refused the third on measurement**. A true assertion written after a
Slack-style fence line is red on the landed checker and was green before — but a reference
CommonMark parser reads that line as a paragraph and the assertion as literal text, so a
green there would be a claim passing unevaluated. The verdict stands and the *message* was
fixed instead. Saying "this red is correct" is the harder half of an adversarial round, and
it needed a third-party parser to say it with.

Items A, B and C's rounds each found real defects too — A's blocker was four rows asserting
"exactly 104 files" that go red the moment a tester saves their own bench, i.e. on ordinary
first use; B's blocker and must were the same **new test row**, asserting no-display
unconditionally so that it reds on the documented display arm; C's verifier found the
restore-side `.include` still unquoted, which fails a run outright at rc 1, and refuted one
of the first round's attributions by reverting a single change. **Item D's verify is the only
one that returned no blocker and no must** — and its fix round still closed a fail-open (one
capital letter in a value silently disarmed the whole new check) and an unbudgeted scan
(9.6 s → 2.5 s on a 90 MB corpus). No round was free.

### Three rules of the batch's own making cost something

1. **The shared scratch root was the driver's mistake.** `CREW_BRIEF.md` handed every item's
   crew the same root and told each to *"delete it when you are done"*. One crew did exactly
   that and removed six live directories — about **2.5 GB of another crew's work**, mid-item.
   The rule is now `<root>/<your label>/`, and the root is never deleted (D10). Nobody
   misread the brief; the brief was wrong.
2. **The delete-your-scratch rule lost a finding, and the count it left behind was wrong.**
   Item A's verifier measured *"a space in the checkout path reds 71 rows across five
   suites"* and deleted its scratch before the row names were written down, so **1490** was
   filed as a count with no names (D4). When item C re-measured it, the answer was **147 rows
   across 17 suites** — the carried-forward number was low by more than a factor of two, and
   1490's headline had to be corrected. The rule itself stays: per-receipt peaks in this
   batch run from **3.7 MB** to **1.8 GB**, every crew deleted its own subtree, against the
   previous batch's **192 GB** left behind. What changed is the brief: **a count is not a
   finding, and a receipt must carry the row names.**
3. **The scratch paths were too long to run a gate in.** Item B's fix round could not run its
   own gate inside the root it was assigned: a checkout path over about **73 characters** reds
   `test_op_annot` and `test_annot_hier_0911`, because `statusmsg_text` is `char[256]` and
   five goldens embed an absolute path. That is a real defect (filed as **1495**) *and* an
   operating cost — it cost a crew its gate. Both this and item 2 landed in the brief as
   `0eed8a1b`, mid-batch, which is where a rule correction belongs.

### What the record says about the rounds cap

Acceptance criterion 5 — one implement round, one adversarial verify, at most one fix round —
**held for all six items**. No item took a fourth round, and the two things a fourth round
would have been spent on were filed instead (1490's row names, and the `full_audit.sh` half
of 1487). Criterion 4 produced **eight new numbers** (1490–1497) and annotations to seven
existing files (1484, 1334, 0227, 0467, 0609, 1480, 1488) rather than fixes made on the way
past.

### The fact this batch should not be allowed to forget

**The gate that proved item F wrote the very file item F is about.** `tests/untitled~.sch`,
mtime 2026-09-20 23:23:39, inside the window of the E+F gate run — a green run,
`counted_failures=0`, writing litter into `tests/` because `tests/run_regression.tcl` is the
one driver nobody armed, and because the new guard row checks the three shell drivers and is
structurally blind to the Tcl one. Five of the six items are closed; this one is recorded in
1486, 0609 and 1480 as open, with the measurement attached, rather than described as done.
