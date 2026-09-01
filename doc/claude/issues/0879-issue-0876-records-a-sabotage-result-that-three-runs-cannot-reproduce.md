# 0879 — issue 0876 records an S15b result that two independent runs refute

Status: 🟡 **RULING SETTLED, 2026-08-29 — DECIDED, and still OPEN for two doc edits** — decided under the user instruction "decide the 23, leave 0861 and 0299 for me"; not bounced. The rule stands and gains the scope clause it was missing: a refuted measurement is corrected everywhere it is quoted, not only where it was first stated. Closes when the two files that still state the refuted S15b claim as fact carry the annotation 0876 already has — doc/claude/issues/0869-*.md:153 and doc/claude/specs/op_annotation.md:2831. See the RULING at the foot of this file. (was: CLOSED 2026-08-29 — premature, the correction had landed only in 0876. Before that: OPEN — filed by the A3h sabotage run, 2026-08-27.)

## The finding

`doc/claude/issues/0876-*.md` (lines ~89-95) records, as a "PREDICTION
CORRECTION", that sabotage variant **S15b** reddens **V11, V12, V13, V28 and
V31** in addition to V26b, and on that basis overrides the plan's written
prediction that S15b "must NOT red V26".

**It does not.** Measured on the restored binary, both readings of "invert the
comparison", each edit brace-balance-checked with `info complete` before running:

| reading | rows reddened |
|---|---|
| the plan's literal wording — `okclamped` minted unconditionally (`if {1}`) | **V26b, V28** |
| the comparison operator flipped (`>` -> `<=`)                              | **V26, V26b, V28** |

Neither reading touches V11, V12, V13 or V31. Under the plan's own literal
wording **V26 stays green — the plan was right and the recorded correction is
the error.** This reproduces the VERIFY-B agent's measurement exactly.

**A THIRD RUN, by the A3h repair agent, 2026-08-27, on the repaired tree** (413
checks, not 410 — V10b, V31c and V31d had landed by then), each edit made by exact
string replacement rather than `sed` and each checked with
`info complete` before running:

| reading | brace-balance | rows reddened | suite line |
|---|---|---|---|
| literal — `if {1}` | complete | **V26b, V28** | `RESULT: 2 FAILED (411 passed)` |
| flipped — `>` → `<=` | complete | **V26, V26b, V28** | `RESULT: 3 FAILED (410 passed)` |

Three independent runs against one. V11, V12, V13 and V31 stayed green in every
one of them.

The stated cause in 0876 cannot hold either: under an inversion `okclamped`
keeps its `$te $which $t` argument order unchanged, and V11/V12/V13 read
`annot_tran`'s **return value**, which is `ok` in both branches by design
(utils/annot_mode.tcl:800-803 says so explicitly).

## Probable provenance, reproduced

A brace-unaware single-line edit into a braced Tcl body. VERIFY-B reproduced a
twelve-row superset — V11 V12 V13 V14 V15 V16 V26 V26b V28 V29 V30 V31 — from a
`sed` that replaced one line of `cadence::_annot_ciw` and left an unmatched `}`
closing the proc early. That superset contains exactly the V11/V12/V13/V31 that
0876 reports.

## The rule this earns

CLAUDE.md already warns that braces inside Tcl **comments** count. The sibling
rule is not written down anywhere:

> A single-line `sed` into a braced Tcl body is a **structural** edit. A sabotage
> variant that does not re-check brace balance reports a superset and attributes
> it to the guard.

Cheap guard, used throughout this run:

    echo 'set fd [open <file> r]; set d [read $fd]; close $fd; puts [info complete $d]' | tclsh

Must print `1` before the variant's number is believed.

## Also worth recording

**V28 reds under every reading of S15b**, which no plan predicted. It is benign —
V28 pins the `ok` sentence byte-for-byte on both sinks, so any wording change
necessarily reds it — but it means S15b is a weaker isolation of the tolerance
direction than intended. **V26b is the clean discriminator.**

## Action

Correct the S15b block in 0876 to the measured table above, or delete the
"correction" and restore the plan's prediction. A tracker carrying a
known-false measurement is the "standing red as furniture" failure mode with the
sign flipped.

---

## RULING, 2026-08-29 — DECIDED under the user's "decide the 23" instruction

**Status: ✅ CLOSED. No code moves. Nothing the user sees or presses changes.**

**The ruling, as an instruction to the codebase:** a measurement recorded in a
tracker file that later runs refute is **corrected in place by the agent that
measured the refutation, without asking the user**. Append the measured table,
and mark the superseded claim as superseded rather than deleting it, so the
record shows what was believed and why it was wrong. This is not a user-facing
decision and never was — no window, menu, key chord or sentence on screen
depends on it.

**Why this is not the user's call.** Every ruling debt on this branch exists
because a user-visible decision was made without approval. This one is not user
visible: it is an engineering note about which suite rows a sabotage variant
reddens. Leaving a known-false measurement standing so that a human can approve
deleting it is CLAUDE.md's "a standing red is a defect, not furniture" with the
sign flipped — and this repo has already burned eight issue files (0420/0492/
0629/0689 and 0421/0455/0491/0690) on facts nobody was allowed to just fix.

**The correction is already in the tree and committed at HEAD** — this ruling
ratifies it rather than ordering it:

* `0876-*.md:7` — the header flags the S15b block as refuted by three runs.
* `0876-*.md:87` — the S15b table cell reads "⚠ THIS CELL IS REFUTED — see issue
  0879, do not quote it", and carries the measured rows.
* `0876-*.md:~95-110` — the block that made the false claim is retained as
  "THE BLOCK THAT WAS HERE IS REFUTED", stating what it claimed and why it
  cannot hold. Superseded, not erased.

**Re-verified in the tree, 2026-08-29** (source, not the earlier write-ups):

* `utils/annot_mode.tcl:2585-2592` — the clamped/plain branch chooses only which
  *sentence* is spoken; the proc's last statement is a bare `return ok`. The
  return value is identical in both branches, so no inversion of that comparison
  can move a row that reads it.
* `tests/headless/test_op_annot.tcl:11736,11752,11769` — V11/V12/V13 assert the
  returned state (`ok`), the graph flags, the annotated time and the painted
  pins. None of them compares sentence text. 0876's stated cause is therefore
  impossible, exactly as this issue says.
* `tests/headless/test_op_annot.tcl:12314` (V26b, in range at 3e-9) and `:12366`
  (V28, in range at 2e-9) both pin the success sentence byte for byte, V28 on
  both sinks. Minting `okclamped` in range necessarily reds both — which is the
  measured `V26b + V28` result, and the reason V28 is a weak discriminator and
  V26b the clean one.

**Still worth doing, and not part of this ruling:** the sibling rule this issue
earns — *a single-line `sed` into a braced Tcl body is a structural edit; check
`info complete` before believing a sabotage variant's row list* — is written
here but nowhere a future crew will trip over it. Promoting it to CLAUDE.md
beside the existing "braces inside Tcl comments count" warning is a separate,
schedulable doc edit.

---

## RULING, 2026-08-29 — decided on the user's instruction

*This section supersedes the earlier "RULING … DECIDED under the user's 'decide
the 23' instruction" block above, which is kept for the record. That block got
the rule right and the closure wrong.*

**The user's instruction, verbatim:** *"decide the 23, leave 0861 and 0299 for
me"* (2026-08-29). A read-only audit had classified 25 of the 57 queued ruling
debts as questions whose answer is cheap and obvious; the user excluded 0861 and
0299 and told the crew to decide the rest. **This debt was one of the 23.** It
was not decided over the user's head.

### The ruling, as an instruction to the codebase

A measurement recorded in a tracker file that later runs refute is **corrected in
place by the agent that measured the refutation, without asking the user** —
appending the measured table and marking the superseded claim as superseded
rather than deleting it, so the record shows what was believed and why it was
wrong.

**And the scope clause the first draft of this rule was missing:** the correction
must land **everywhere the claim is quoted, not only in the file that first
stated it.** Before declaring a correction complete, the agent greps the claim's
own identifier across the docs and the code — here
`grep -rl S15b doc/ utils/ src/`, which takes about a second — and fixes every
place that states the refuted claim as fact. A refuted measurement that is
corrected in one file and left standing in the file the user's own queue sends
them to has not been corrected; it has been forked.

### Why this is not the user's call

Nothing on screen turns on it. No window, menu, key chord or sentence depends on
which suite rows a sabotage variant reddens, so it fails the test every other
ruling debt on this branch meets — those exist because a *user-visible* decision
was made without approval.

CLAUDE.md settles the direction: **"a standing red is a defect, not furniture"**,
a rule written after this repo burned eight issue files (0420/0492/0629/0689 and
0421/0455/0491/0690) on facts nobody felt allowed to simply fix. A tracker
carrying a known-false measurement is that same failure with the sign flipped.
Spending a slot on a 57-entry queue the user has already called too heavy, to ask
permission to delete a number three runs disproved, is the cost this ruling
avoids.

CADENCE OR NOTHING, PLAIN ENGLISH, D5-1 and I3 are all about the surface and are
silent here — which is precisely why this is decidable rather than the user's.
But silent on the question is not silent on whether the work is finished, which
is why this ruling does **not** close the issue on ratification alone.

### Verified in the tree, 2026-08-29 (source, not the earlier write-ups)

* `utils/annot_mode.tcl:2585-2592` — the clamped/plain branch chooses only which
  *sentence* is spoken; the proc's last statement is a bare `return ok`,
  identical in both branches. No inversion of that comparison can move a row that
  reads the return value.
* `tests/headless/test_op_annot.tcl:11736, 11752, 11769` — V11/V12/V13 assert the
  returned state, the graph flags, the annotated time and the painted pins. None
  compares sentence text. 0876's stated cause is therefore mechanically
  impossible, exactly as this issue says.
* `tests/headless/test_op_annot.tcl:12314` (V26b, in range at 3e-9) and `:12366`
  (V28, in range at 2e-9, both sinks) pin the success sentence byte for byte.
  Minting `okclamped` in range necessarily reds both — the measured
  **V26b + V28**.
* `doc/claude/issues/0876-*.md:7, :87` and the block at ~95-110 already carry the
  correction, with the false claim retained as superseded, and the table cell
  stamped *"⚠ THIS CELL IS REFUTED — see issue 0879, do not quote it."*
  Committed at HEAD, not a working-tree edit.
* `grep -rl S15b doc/ utils/ src/` returns seven files. Five are clean:
  `doc/claude/FAQ.md:482` already states the refutation, and
  `doc/claude/batch_F/receipts/05b-f1-f5-salvage.md:164` is a different suite's
  S15b (`browser_node_for`, row FV24), unrelated. **Two still state the refuted
  claim as fact** — the two named below.

### Does this move code? No — but two doc edits are still owed

**No code change. Nothing the user sees or presses moves.** This ratifies what
already ships.

**Follow-up work, NOT YET DONE.** 0879 is DECIDED but stays **OPEN** until both
of these carry the same annotation `0876-*.md` already has:

1. `doc/claude/issues/0869-...md:153` — the S15b row currently reads
   *"**V26b**, and also V26, V11, V12, V13, V28, V31 — see 0876's table"*, stated
   as fact, and forwards the reader to the very cell now stamped "do not quote
   it". It must read the measured result — **V26b, V28** for the plan's literal
   wording; **V26, V26b, V28** for the flipped operator — with the old superset
   retained as refuted and the pointer to 0876's table removed. **This is the
   load-bearing one:** `owed.sh show` currently routes **two** open user debts to
   this file (a ruling on the clamped transient sentence, and a look debt asking
   the user to judge that sentence on their own screen), so the next reader
   preparing a decision the user still has to make reads the refuted superset as
   fact.
2. `doc/claude/specs/op_annotation.md:2831` — the branch index row still reads
   *"🔴 **NEW** … correcting another agent's tracker entry **is the user's
   call**"*, which this ruling makes wrong twice over: 0879 is not new, and it is
   expressly not the user's call.

*(Scope note for a later reader: the sibling rule this issue earns — a one-line
`sed` into a braced Tcl body is a structural edit; check `info complete` before
believing a sabotage variant's row list — is already written in
`doc/claude/FAQ.md:470-495`, contrary to the earlier section's claim that it
lives nowhere a future crew will trip over. Promoting it to CLAUDE.md beside the
"braces inside Tcl comments count" warning remains an optional, separate doc
edit.)*

### The adversary ran

An adversary challenged this decision and **overturned half of it**: it agreed
the rule is right and that this is not the user's call, and it defeated the
claim that the correction was complete — the same refuted line was still
committed in `0869-*.md:153` and `op_annotation.md:2831`. Its better answer is
the ruling recorded above: keep the rule, add the scope clause, and do not close
on ratification alone.

### In one line, for the user

Nothing on your screen changes — an internal engineering note recorded a test
result that three later runs disproved, I corrected it and it was not yours to
rule on, but the same wrong line was also sitting in two other notes and I am
fixing those before I call it closed.

---

**The user may reverse this at any time; it was decided to spare their attention,
not to bind them.**
