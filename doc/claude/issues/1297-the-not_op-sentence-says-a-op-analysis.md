# 1297 — the `not_op` refusal says "a op analysis", and the article never agrees

✅ **FIXED 2026-09-04 by the DRIVER**, immediately after B2d landed. B2d filed
it rather than widening its own three-issue scope, which was correct.

`rdw::_article {word}` returns `an` before a vowel and `a` otherwise, and the
`not_op` sentence uses it. ⚠ **Vowel-initial is the test, not a list of known
analyses** — the kinds are whatever the raw's `Plotname` mapped to, so a list
would be wrong for the first kind nobody anticipated. It is right for `op`,
`ac`, `dc`, `tran`, `noise`, `sp` and `sens`, which is every kind this tree
produces. Rows **ND3** and **ND4**; sabotage (always returning `a`) reds both.

---

*Original filing follows.*

**Status:** FILED, NOT FIXED. Found by item **B2d** while reproducing issue 1284's
legal minimal refusals; it is outside B2d's three-issue scope and was deliberately
left alone rather than smuggled in.

**File:** `src/rdw.tcl`, `rdw::_state_sentence`, the `not_op` arm.

## What it says

```tcl
not_op {
    return "The loaded results are a $sty analysis, not an operating point. ..."
}
```

`$sty` is whatever `xschem raw sim_type` reported for the loaded slot. The
article is the literal `a`, so the sentence reads correctly for `dc`, `tran`,
`noise` and `sp`, and **wrongly for every vowel-initial analysis name**:

| `sim_type` | rendered |
|---|---|
| `dc`   | "The loaded results are a dc analysis"   ✓ |
| `tran` | "The loaded results are a tran analysis" ✓ |
| `op`   | "The loaded results are **a op** analysis" ✗ |
| `ac`   | "The loaded results are **a ac** analysis" ✗ |

MEASURED 2026-09-04 on HEAD `21fcece6` and on B2d's tree, driving the renderer
directly:

```
--- {state not_op}   ctx simtype op
The loaded results are a op analysis, not an operating point. Nothing was read
from them: load the operating-point results and ask again. ...
```

## Why the `op` row is not absurd

`not_op` with `simtype op` looks self-contradictory but is reachable: the ctx's
`simtype` is read from the raw the WINDOW sees, and the seam's `state` is decided
by `ase::op_param_set` against the slot it read. `ac` is the ordinary case —
an OP+AC run whose AC slot became current answers `not_op` with `sim_type = ac`.

## Why B2d did not fix it

1. It is user-visible **wording** in a state arm none of B2d's three issues
   (1282, 1283, 1284) covers. This batch has been reverted twice for exactly
   that class of unratified drift, and the crew rule is to file, not to fix.
2. B2d already carries one wording change of its own (`RW_ANALYSIS`, ruling
   DD-5's specimen refuted by `save.c:1073`/`:1120`) which is on the owed ledger
   as a rule debt. Stacking a second undecided string on the same commit is how
   the first two attempts died.
3. Precedent: item B2b filed **1291** against a defect it found outside its scope
   rather than fixing it, and the driver's own brief records that as the right call.

## Options

* **(a)** Pick the article from the name: `[expr {[string match {[aeiou]*} $sty] ? {an} : {a}}]`.
  One line, no new string, and correct for every analysis name ngspice can
  report. Cost: the suite's `RW_NOTOP` golden (`tests/headless/test_rdw_window_1245.tcl`)
  has to take the article too, so it is a two-file change.
* **(b)** Drop the article: "The loaded results are `$sty` results, not an
  operating point." Smallest diff, and it sidesteps the vowel question entirely,
  but it loses the word "analysis" that names what `sim_type` IS.
* **(c)** Leave it. It is a cosmetic blemish on a sentence the user only sees in
  a refusal, and the remedy it gives is correct either way.

RECOMMENDED: **(a)**. It is the only one that keeps the sentence's meaning and
the only one that stays right when a backend reports an analysis name nobody
here anticipated — which is precisely ruling D-5's case.

## Acceptance, when someone takes it

* A ctx with `simtype ac` and `simtype op` each render "an ac"/"an op"; `dc`,
  `tran`, `noise`, `sp` each still render "a".
* The fence lives in `test_rdw_window_1245.tcl` beside the existing `not_op`
  rows and asserts BOTH halves, so a fix that hard-codes `an` is caught too.
