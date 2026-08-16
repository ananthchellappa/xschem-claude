# 0418 — `raw_add_vector()` swallows the expression failure and registers an all-zero column

**Status:** OPEN. Measured on branch `fluid-editing` at `532b1768` (casemode batch item 2).
Documentation only — nothing fixed, no test written.
**Area:** `src/save.c`, `raw_add_vector()` and its call to `plot_raw_custom_data()`.
**Found:** 2026-08-16, by the casemode batch item 2 crew, while ruling on D2's collision
rule. Named in `doc/claude/casemode_batch/receipts/02-one-lookup-ladder.md` §5 as
"named, not fixed" and filed here by the driver so it is not lost.
**Related:** the defect item 2 *did* fix in `wviewer::validate_rpn` is the same
family — a name that cannot resolve producing a **silent all-zero trace** rather
than a refusal.

**This is a silent-wrong-data defect, not a cosmetic one.** The user asks for a
vector, gets a plotted trace, and the trace is flat zero because the expression
never evaluated. Nothing on any stream says so, and the return value says success.

---

## Mechanism

`plot_raw_custom_data()` returns `-1` when it cannot evaluate the expression.
`raw_add_vector()` does not propagate that: it registers the vector anyway and
returns `1`. The column exists, is the right length, and is entirely zeros.

Measured:

```
xschem raw add x {BADTOK 2 *}    ->  returns 1
xschem raw list                  ->  x is present
                                     its samples are all 0.0
```

`BADTOK` is not a signal in the database and `BADTOK 2 *` is therefore not an
evaluable RPN expression. The correct outcome is a refusal.

## Why item 2 did not fix it

Two committed suites lean on the current engine semantics — a `raw add` that
returns `1` for an expression the engine could not evaluate. Changing the return
contract is a behaviour change with its own blast radius, and item 2's audit
contract was an **empty** diff (`receipts/00a-suite-sweep.md`). Fixing this
inside item 2 would have moved rows for a reason unrelated to the case ladder,
which is exactly what that contract exists to detect.

That is a reason to file it separately, not a reason to accept it.

## What a fix has to decide

1. **Propagate or reject?** Either `raw_add_vector()` returns `0` and registers
   nothing, or it registers the column and reports the failure some other way.
   The first is almost certainly right — a column of zeros is indistinguishable
   from a real all-zero signal, so there is no way for a later reader to tell.
2. **The two leaning suites.** Identify them, and decide per suite whether the
   assertion is testing this semantics deliberately or merely encoding it.
   Item 2's receipt names the situation but not the two files; re-grep.
3. **The distinction that matters:** an expression naming a signal that is
   genuinely absent, versus one that is syntactically malformed. Both currently
   yield the same silent zeros. A refusal should say which.

## What is NOT claimed here

Nobody has measured how a user reaches this through the GUI, or whether the
viewer's own paths can produce a `BADTOK`-shaped expression without going
through `validate_rpn` — which item 2 made D2-aware and which now refuses the
case that used to leak through. The reachable surface may be narrower than the
engine surface. That does not change the engine contract being wrong.
