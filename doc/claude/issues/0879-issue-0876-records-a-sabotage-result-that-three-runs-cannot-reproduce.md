# 0879 — issue 0876 records an S15b result that two independent runs refute

Status: **OPEN** — filed by the A3h sabotage run, 2026-08-27.

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
