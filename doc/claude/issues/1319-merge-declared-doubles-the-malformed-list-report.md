# 1319 — a malformed declaration is now reported twice per type

**Filed by item B2e's Verify-C (adversary) pass, 2026-09-04; re-measured
independently by the write-up agent before filing. Measured, NOT fixed.**
Status: **open — cosmetic, unfenced by any row, and exactly the kind of drift
that later gets golded by accident.**

---

## 1. What was measured

`op_param_lists::_merge_declared` calls `_declared_rows`, which is `_params`,
which is the one door that validates a descriptor's list and reports it when it
does not parse. `_save_set` may *already* have reached `_params` for the same
type, through `effective` → `seed`, when one of the class's two lists is
unowned. Nothing memoises the report.

Two `type=` tokens in one class, each registered with a `params` holding an
unmatched open brace (built with `format %c`, never as a literal — landmine 4),
counting `op_param_lists::said` across one `apply`:

```
case1  annotation owned, summary UNOWNED   reports = 4      <- HEAD emitted 2
case2  neither list owned                  reports = 0      <- apply skips the class
case3  BOTH lists owned                    reports = 2      <- unchanged from HEAD
```

Driver: `/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_B2e_wu/wu2.tcl`.

The doubling is confined to **case 1** — the shape where the unowned list falls
through to the seed and reaches `_params` a first time, and `_merge_declared`
reaches it a second. Case 1 is the *common* shape: a user who edits only the
annotation list from item B5's button column is in it.

The message itself is correct and its wording is B2e's improvement (it now names
*which* list failed — `declaration` or `params` — because after an apply the two
fields can differ and blaming `params` for a `params` that parses fine is
invariant I3's family one layer up):

```
op_param_lists: the descriptor for `nmos` has a declaration list that does not
parse; ignoring it. Fix it in the rc that registered it.
```

It is simply printed twice, to stderr and into `said`.

## 2. Why it matters at all

`said` is a **list, one element per report, so a caller can count how many times
the user was told something** — that is its documented reason for existing. A
count that doubles for one ownership shape and not another is a count nobody can
use, and item B5's status line is the first thing that will want to.

## 3. Options

1. **Dedupe in `_say`** by message text, per report buffer. Smallest; fixes
   every present and future double, including ones nobody has met. Risk: a
   genuinely repeated report (the same complaint about two different runs) is
   swallowed. Mitigable by deduping only within one `apply`.
2. **Memoise `_params` per type for the duration of one `apply`.** Fixes the
   cause rather than the symptom, and cuts a redundant validation pass. Risk:
   DD-13 rejected its option (c) — *caching the first `_params` answer* —
   because a cache that outlives a user's own `op_annot::register` breaks
   invariant **I5**. A cache scoped to one `apply` call does not outlive
   anything, but the shape is close enough that it must be written so it cannot
   be widened by accident.
3. **Pass the already-read rows into `_merge_declared`** instead of re-reading.
   No cache, no dedupe, no new state — but `_save_set` is per **class** and the
   third input is per **type**, so the rows are not the same rows and the
   plumbing is not free.

Recommended: **(2), scoped to a single `apply` frame**, with the I5 constraint
written beside it.

## 4. Still open

Which option, and a row that counts `said` for each of the three ownership
shapes above — there is none today, which is why the doubling landed green.
Nobody is assigned.
