# OP parameter lists — batch ledger, branch `fluid-editing`, base `9ef4a37e`

**State lives HERE, not in the driver's context.** After a compaction, re-read
this file and continue from the first row that is not `[x]`/`[E]`/`[D]`/`[F]`.

Verdicts: `[x]` done+verified · `[E]` done, eyeball pending (pixels) ·
`[D]` deferred (needs a filed issue) · `[F]` failed (needs a filed issue) ·
`[ ]` not started · `[~]` in flight.

## Read before touching anything

1. **`DECISIONS.md`** — D-1 … D-8, settled with the user 2026-09-02. It
   overrides the spec wherever they disagree.
2. **`PLAN.md`** — the authoritative item list and the dependency edges.
3. `doc/claude/specs/op_param_lists.md` — the spec.
4. `doc/claude/code_analysis/1244_op_param_list_measurements.md` — every number
   the design rests on, with the command that produced it.

Receipts: `receipts/<item>-<slug>.md`, 120 lines max.

## Baseline — audit debt is PAID

**364 pass / 11 fail / 0 crash-timeout / 2 skip of 377** at `9ef4a37e` on the
dev display `:99`. The eleven are named in `PLAN.md`. Every later audit is
judged by DIFFING that list by test **NAME and STATUS**, never by the red count.
`run_regression.tcl` (T1) baseline is **ZERO** counted failures, run **solo**.

## Items

| # | item | verdict | commit | checks | files | eyeball | note |
|---|------|---------|--------|--------|-------|---------|------|
| A1 | the mask bit and the chord | `[ ]` | | | | | ⚠ `Ctrl-Alt-6` currently fires `Alt-6` |
| A2 | the name classifier | `[ ]` | | | | | three spellings, not one |
| A3 | the draw rung and the per-instance gate | `[ ]` | | | | | needs A1+A2; the 11th call site |
| B1 | the backend seam | `[ ]` | | | | | D-4/D-5 are the whole item |
| B2 | the list store and the settings file | `[ ]` | | | | | `Makefile.in` ×2 + `./configure` |
| B3 | the window | `[ ]` | | | | | `rdw::`, not `results::` |
| B4 | the keys and the two grammars | `[ ]` | | | | | needs B3; displaces `logic_set` |
| B5 | the button column and the scope dialogs | `[ ]` | | | | | needs B2+B3; issue 0803 |

## Debts this batch owes the user

Recorded on `tests/headless/owed.sh` at the moment they are incurred, never at
the end.

| kind | what | state |
|---|---|---|
| `look` | Q6 — the dump header spelling, on screen | to record when B3 lands |
| `look` | the decluttered sheet on the real display, per PDK | to record when A3 lands |
| `rule` | Q10 — is the RDW reachable after an ordinary OP+TRAN run | **verify first**, ask only if the answer is "no" |

Pre-existing and unrelated, still open: `rule` **1240**, `rule` **1243**, and
three `look` debts from the merge.

## Carried risks

1. **`Ctrl-Alt-6` is not free** and the failure is silent — it turns node
   voltages on. A1's chord matrix is the only guard.
2. **`Makefile.in` without `./configure` is invisible in-tree and fatal
   installed** (issue 0424, exit 139 at startup). Two items add a `.tcl` file.
3. **Modal dialogs hang suites under X** (issue 0803). B5.
4. **Symbol texts are shared across instances**, so feature A cannot be
   per-instance in `xText.flags`. A3 carries the gate in the context argument.
5. **A crew "improving" key 3** by inferring parameters violates D-4. The
   DECISIONS file states this in the negative on purpose.
