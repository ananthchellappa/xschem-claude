# 1285 — `op_annot::text` draws from `params`, so DD-4's union un-declutters the sheet

**Status: MEASURED, FILED, NOT FIXED. HARD BLOCKER FOR ITEM B5.**
Filed by item **B2a**, 2026-09-03, while implementing ruling **DD-4** (issue
1280). Latent today: nothing calls `op_param_lists::apply` yet, and item **B5**
is the first thing that will.

## 1. The claim

Ruling **DD-4** has two clauses:

> `apply` writes the **union** of the annotation and summary lists into
> `params`, **and the display narrows to the annotation list.**

**Those two clauses cannot both be true of one field, and `params` is one
field.** MEASURED: `op_annot::text` (`src/op_annot.tcl:1726`, the `params` loop at
`:1741`) builds the
**on-sheet annotation rows** by iterating exactly the same
`dict get $d params` list that `op_annot::_cards_for`
(`src/op_annot.tcl:2808-2820`) turns into `.save` cards. One list, two
consumers, and DD-4 asks them to differ.

## 2. What B2a attempted, and why this issue outlives its revert

> **NOTE, 2026-09-03: item B2a was REVERTED in full** (its adversary pass
> refuted the batch's central claim). So the union described below is **not in
> the tree** — `apply` still writes the annotation list alone. **This issue is
> unaffected and still blocks B5**, because it is a property of
> `src/op_annot.tcl` at `825cd3bd` plus ruling **DD-4**, not of B2a's code: the
> moment *anyone* implements DD-4's first clause, its second clause needs a
> field that does not exist. Answering it before the re-do is strictly cheaper
> than after.

### What B2a attempted, and what it therefore left open

Item B2a's (reverted) attempt implemented the **save** half — the half whose failure is silent,
destructive and invisible on a schematic (invariant **I3**): `apply` now writes
`union(effective <c> annotation, effective <c> summary)` into `params`, so
trimming what is drawn can never stop the simulator computing what list 2 still
asks for. Rows `A3` and `A4` of `tests/headless/test_op_param_store_1245.tcl`
fence it.

B2a owns four files and `src/op_annot.tcl` is not one of them, so the **display**
half is this issue.

## 3. The consequence, stated plainly

Until this lands, a user who deletes a row from the annotation list will see

* the deck keep saving it — **correct**, per DD-4; and
* **the row still drawn on the sheet** — the opposite of the user's own word
  *declutter*, which is the word the whole feature is named after.

That is why this blocks **B5**, the item that ships the Delete button. Shipping
Delete against today's `op_annot::text` would ship a button whose visible effect
is nothing at all.

## 4. The two options, and the question for the user

**Option 1 — a new descriptor key the display prefers over `params`.**
`op_annot::text` reads e.g. `dict get $d shown` when present and falls back to
`params`. This is issue 1280's *rejected* Option 2, now unavoidable, and it is
the smaller blast radius: one dict key, one `if`, and `_cards_for` is untouched.
Cost: two lists in one descriptor, and a PDK author has to be told which is
which.

**Option 2 — `op_annot::text` calls `op_param_lists::effective` directly.**
No new dict key, and the narrowing has exactly one definition
(`effective <c> annotation`, which row `A4` already asserts by name for this
reason). Cost: `op_annot.tcl` gains a dependency on `op_param_lists.tcl`, which
today is one-way in the other direction — and `op_annot.tcl` is sourced first.

**Rejected already:** writing an inert display key into the descriptor dict
*from* `op_param_lists.tcl`, which invents a dict-shape contract no consumer
reads. **Rejected already:** leaving `apply` narrowing — DD-4 forbids it and
invariant I3 is why (issue 1280 §the measurement).

**On the owed ledger as a `rule` debt.** The choice is user-visible in the sense
that it decides where a PDK author declares "draw this" versus "save this", so
it is the user's to make; the cost is bounded either way and named above.

## 5. Acceptance rows this will need

* after `apply` with a trimmed annotation list, `op_annot::text` emits a row for
  every **annotation** entry and **no** row for a summary-only one, while
  `_cards_for` still emits a card for both (the A3/A4 pair, one layer out);
* a descriptor a PDK registered with no narrowing at all still draws every
  `params` row, unchanged — invariant **I7**'s shape for this field.
