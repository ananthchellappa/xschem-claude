# 1326 — a Delete on a duplicate-label declaration drops TWO display rows and a `.save` card

**Status:** ✅ **FIXED 2026-09-04 by item B5-3**, under ruling **DD-15**, which
took this issue's option **(c)**: the refusal moved to the DECLARATION.
Originally measured 2026-09-04 by item **B5-a** while fixing
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

---

## ✅ FIXED 2026-09-04 by item **B5-3** — option (c), at the declaration

Ruling **DD-15** took option **(c)**. `op_annot::register` now refuses a
declaration carrying two triples that share a display label, **once, where the
duplicate is introduced**: `op_annot::_dup_declared_label` scans the declaration
`_declare` will store under `declared`, and `register` raises before anything is
stored and before `::op_annot::gen` is bumped, so a refused registration leaves
the registry byte-identical.

**Three properties the implementation is built around, each measured:**

1. **It scans the DECLARATION, not `params`.** `op_param_lists::apply`
   re-registers every applied type handing back the descriptor it read with
   `params` replaced by the annotation+summary UNION, inside a catch that turns
   a raise into a `_say` — so a guard reading `params` would make an ordinary
   Delete report *"cannot register the parameter lists"* instead of doing its
   job. Store row **DL3** fences exactly that shape.
2. **Every read is catch-guarded and falls through to ACCEPT.** `_declare`'s own
   header forbids parsing the value and forbids raising for a malformed one, and
   a user's rc is a supported door (invariant I5). Store row **DL2** fences the
   narrowness: an unmatched open brace, an unparseable row, the empty descriptor
   and a descriptor with no `params` all still register `rc=0`.
3. **The rule is written twice, not called across.**
   `op_param_lists::_dup_index` is the same one-line rule for the store's own
   two doors, and the guard deliberately does not call it: `op_annot.tcl` is
   sourced FIRST and `op_param_lists.tcl` depends on it, and ruling **DD-6**
   already rejected that load-order inversion.

**`op_param_lists::reduce_why` STAYS, as the second door.** DD-15 shuts the
declaration; it cannot shut `::op_annot::desc`, which a fixture, an older
session's stored state, or any code assigning the array directly still reaches.
Store rows **RD1**, **RD3**, **RD5** and **BE8** were re-pointed to a direct
`::op_annot::desc` assignment (row **N9c**'s sanctioned technique) rather than
deleted, precisely so that guard stays fenced — sabotage `reduce_why_blind` still
reds all four.

**Acceptance rows, all green:** store **DL1** (the refusal and everything it
must not leave behind), **DL2**, **DL3**; window **BT27** unchanged and green
(its label collision is minted by `set_list`, issue 1288's ruled
accept-and-report, not by a declaration — DD-15 moves nothing about `set_list`,
which is the re-check item B5-3's brief asked for); store **BE8** green;
`test_op_annot` **UNMOVED** at 485 / 492 (row **K17** never sees the guard,
because it overwrites `params` alone on a descriptor whose `declared` is already
well-formed).

**One consequence filed, not fixed: issue 1328** — all four shipped PDK register
sites are uncaught, so a refusal aborts the rest of that `_procs.tcl`.

---

## STILL OPEN after item B5-3 — the DELETE side, through the door DD-15 cannot shut

Item B5-3's adversary measured this, and the write-up agent reproduced it.
**DD-15 shuts the declaration; it does not shut `::op_annot::desc`**, which a
fixture, an older session's stored state, or any code assigning the array
directly still reaches — and which is exactly the route rows **RD1**, **RD5**
and **BE8** were deliberately re-pointed to.

Reached that way, **one Delete press still drops TWO display rows**, measured on
this tree (`./src/xschem --nogui --pipe -q --nolog`):

```
BEFORE_EFF  = {id ids 0} {id vgs 2} {gm gm 1}
DELETE_VERD = ok
DELETE_SAY  = removed gm from the annotation list for class zcls. a second entry
              for label "id" in class zcls annotation; the later one replaces it
              in place
AFTER_EFF   = {id vgs 2}
```

Three rows in, one row out. `gm` was asked for; `{id ids 0}` went with it.

**`reduce_why` is consulted for REORDERS ONLY.** Item B5-a narrowed its guard to
the reorder on a measurement (guarding the Add arm reds **BT27**, which golds
issue 1288's ruled accept-and-report), and item B5-3 left that narrowing alone.
So the "one rule, two doors" claim now written into `src/rdw.tcl` and
`src/op_param_lists.tcl` holds for **Up and Down** and **not for Delete**:
Delete has one door, and DD-15 is it.

Two mitigations that are real, and one that is not:

* the user IS told once, by the store's own dedupe sentence read back on the
  success arm (`rdw::_store_tail`, issue 1288's ruling) — the tail above;
* the state is **unreachable in production**: `op_annot::register` now refuses
  it, and a tree-wide grep finds nothing outside
  `tests/headless/test_op_param_store_1245.tcl` assigning `::op_annot::desc`;
* what the user is NOT told is that a row left the DECK. The sentence names a
  display-list dedupe; the `.save` card went too.

Also relevant, and filed separately as **issue 1330**: `rdw::_apply_now`
swallows `apply`'s failure, so on this path `apply` can fail to re-register
(`shown` = `NOKEY`, `said` carrying *"cannot register the parameter lists"*
twice) while the status line still reports the edit landed.

**Status: STILL FILED, NOT FIXED**, now with a measured reachability bound —
test-only today, and the choice of whether Delete gets a second door remains the
USER's, as this issue said from the start.
