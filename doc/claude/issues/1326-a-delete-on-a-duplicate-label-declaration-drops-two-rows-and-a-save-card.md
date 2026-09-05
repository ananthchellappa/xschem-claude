# 1326 — a Delete on a duplicate-label declaration drops TWO display rows and a `.save` card

**Status:** FILED, NOT FIXED. Measured 2026-09-04 by item **B5-a** while fixing
issue **1323**, on the tree at HEAD `9945ad43` with the preserved B5-2 patch
applied on top of B5-a's own fix.

**Files:** `src/rdw.tcl` (`rdw::_edit`'s `delete` arm), `src/op_param_lists.tcl`
(`set_list`, `reduce_why`).

---

## What was measured

A private class with ONE type token, whose PDK declaration carries two triples
sharing the label `id` — the same shape issue 1323 is about, reachable through
invariant **I5** (a user's own `op_annot::register` in their rc):

```
BASE        = {id ids 0} {id vgs 2} {gm gm 1}          (3 rows)
CARDS0      = {.save @m.m1[ids]} {.save @m.m1[vgs]} {.save @m.m1[gm]}
```

The user presses **Delete** on `gm` — one row, the last one, no duplicate of
its own:

```
DELETE_SAY  = Delete: removed gm from the annotation list for class zcls.
              a second entry for label "id" in class zcls annotation;
              the later one replaces it in place
AFTER       = {id vgs 2}                                (1 row, not 2)
CARDS1      = {.save @m.m1[vgs]} {.save @m.m1[gm]}
PARAMS      = {id vgs 2} {gm gm 1}
SHOWN       = {id vgs 2}
```

`.save @m.m1[ids]` **is gone from the deck**, and the annotation list lost TWO
rows for one Delete press. The verdict is `ok`.

Reproduce: `/tmp/.../scratch_B5-a/probe_1326.tcl` (kept out of the repo; the
fixture is eleven lines of the same shape store row BE8 builds).

---

## Why this is a defect and not the ruled behaviour

Rulings **DD-4** and **DD-6**: *"Delete removes a parameter from what is DRAWN.
It never changes what the simulator is asked to save."* Here it does both — one
row the user did not name leaves the display, and one `.save` card leaves the
deck. `op_param_lists::apply` unions through `_save_set` and `_merge_declared`,
both of which dedupe by label, and the DECLARATION itself carries the duplicate,
so nothing downstream can restore the row (this is issue 1323's mechanism,
arriving through a different button).

The user is **not** unwarned — `set_list`'s issue-1288 report rides onto the
success sentence — but the verdict is `ok`, nothing is rolled back, and a card
is destroyed.

---

## Why item B5-a did not fix it, and what it did instead

B5-a published `op_param_lists::reduce_why` and wired it into `rdw::_edit`'s
**reorder** arm only. That is deliberate and it is a measurement, not a
preference:

* A reorder is **definitionally length-preserving**, so a shortening reorder is
  unambiguously a defect and refusing it cannot be controversial.
* An **Add** whose triple collides by label is **RULED ACCEPTED** — issue
  **1288**: the later triple replaces the earlier one in place and the user is
  told once. Window row **BT27** in `B5-2_working_tree_REFUTED.patch` golds that
  by name, and `rdw::_edit`'s own comment states it: *"the Add is not refused: a
  third door with a third rule is the disagreement issue 1288 is about."*
  B5-a's first implementation guarded all four verbs and **red BT27**; the guard
  was narrowed on that measurement.
* **Delete** sits between the two and is the one this issue is about: the ruled
  Delete semantics (DD-10's last-row refusal) say nothing about a duplicate
  label, so there is no ruling to lean on either way.

---

## Options, and what each costs

* **(a) Refuse the Delete, with `reduce_why`'s existing sentence.** One line in
  `rdw::_edit`'s `delete` arm, symmetric with the reorder arm, and no new
  wording. Cost: a user whose PDK declares a duplicate label **cannot delete
  anything at all** from that class's list until the declaration is fixed — a
  button that refuses every press, with a sentence about a row they did not
  touch. RECOMMENDED only if (c) is rejected.
* **(b) Accept, but restore the row the user did not name.** Cannot be done in
  this store: `set_list` of the repaired list dedupes identically, and issue
  1323's own recommendation was refuted for exactly this reason (see
  `op_param_lists::reduce_why`'s comment).
* **(c) Refuse at the DECLARATION, once, where the duplicate is introduced.**
  `op_annot::register`/`_declare` accept the duplicate today (measured rc=0).
  A duplicate label in a declaration is not a thing any of the three shipped
  PDKs does and is arguably always an author error. Cost: it punishes the PDK
  author at load time, `src/op_annot.tcl` is a forbidden file for the whole
  op_param batch, and issue 1323 rejected this route once already. It is
  nonetheless the only option that closes 1323, 1326 and every future door at
  the same seam.
* **(d) Leave it.** Latent for sky130, gf180 and IHP — all three checked, all
  three declare distinct labels. Reachable only through invariant I5.

**This is a user ruling, not a crew decision**: (a) and (c) trade a broken
button against a rejected PDK, and DECISIONS.md contains no ruling that settles
it. Recorded as a `rule` debt on the owed ledger.

---

## Acceptance rows, when it is fixed

1. With the duplicate-label declaration live, a Delete of a row that is NOT part
   of the duplicate leaves the other rows' `.save` cards standing —
   `op_annot::_cards_for` byte-identical, or shorter by exactly the deleted row.
2. The verdict and the sentence agree: an `ok` never accompanies a list that
   came back shorter than `base - 1`.
3. Issue 1288's Add behaviour is untouched — window row **BT27** stays green.
4. Store row **BE8** (the reorder half) stays green.
