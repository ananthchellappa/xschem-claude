# 1323 — a reorder becomes a deletion when two declared triples share a label, so a Up press changes what the simulator saves

**Status:** **FIXED** by item **B5-a**, 2026-09-04 (was: FILED, NOT FIXED). The Delete half is split out as issue **1326**. Measured 2026-09-04 on `fluid-editing` at
`c940a5df`. The store half reproduces with **no item-B5-2 code at all**; the
button that reaches it was reverted with B5-2.
**Component:** `src/op_param_lists.tcl` (`set_list`'s label dedupe, `seed`,
`_merge_declared`) · `src/op_annot.tcl` (`register` / `_declare`) ·
`src/rdw.tcl` (`rdw::_edit`, up/down arm — in the preserved patch).
**Related:** rulings **DD-4** and **DD-6** (*"Delete removes a parameter from
what is DRAWN. It never changes what the simulator is asked to save."*), ruling
**DD-8** (precedence is file order), ruling **DD-10** (Delete refuses the last
row), issue **1288** (the duplicate-label rule), issue **1312**/**DD-13**.

## Why this is a ruling violation, not a wart

DD-4 and DD-6 divide the world: display decisions never become save decisions.
A **reorder** is the most purely-display operation the feature has. This makes
one drop a `.save` card.

## The mechanism

Three doors disagree about duplicate labels:

* `op_annot::register` **accepts** a declaration whose `params` carries two
  triples sharing a label, and `_declare` stamps it verbatim.
* `op_param_lists::seed` returns that declaration verbatim — no dedupe.
* `op_param_lists::set_list` **dedupes by label** (issue 1288's ruled behaviour:
  it returns 1 *with a report* and the later entry replaces the earlier in place).

`rdw::_edit`'s up/down arm takes `effective`'s list, swaps two elements, and
hands the result to `set_list`. When the base came from the **seed**, it can
carry a duplicate label that `set_list` will not keep — so the list that comes
back is **shorter than the one that went in**, and a parameter is gone.

## The measurement

At `c940a5df`, no B5-2 code loaded, driving the store directly along the exact
path `_edit`'s up/down arm takes:

```
REGISTER_DUP_LABEL_RC=0  err=<dupdev>
DECLARED={id ids 0} {id vgs 2} {gm gm 1}
SEED={id ids 0} {id vgs 2} {gm gm 1}
EFF0={id ids 0} {id vgs 2} {gm gm 1}  len=3
REORDERED_REQUEST={id vgs 2} {id ids 0} {gm gm 1}  len=3
SET_LIST_RC=1  report=<{a second entry for label "id" in class dcls annotation; the later one replaces it in place}>
EFF1={id ids 0} {gm gm 1}  len=2
ROW_LOST=1
```

Through the wired button (measured on B5-2's working tree before the revert),
the same input made `shown` follow the shortened list and the emitted cards drop
from three to two — **`.save @m.m1[ids]` disappeared.** `_merge_declared` cannot
restore it, because the union dedupes by label again. **DD-10's last-row guard
never fires**: the base length was 3, so nothing looks like "the last row".

## Reachability

**Latent with every PDK in this tree.** sky130, gf180 and IHP were all checked:
each declares distinct labels, so none can trigger it today. It is reachable
through invariant **I5** — a user's own `op_annot::register` in their `xschemrc`
overrides the PDK's and takes effect on redraw. A user writing
`{{id ids 0} {id vgs 2} …}` (two views of the same current, deliberately labelled
alike) gets a silently smaller deck the first time they press Up.

## Recommended fix

**A length check on `_edit`'s up/down arm**: after the write, if
`llength` of what the store now holds is less than the base, restore the base and
refuse with a sentence. The `_store_tail` machinery already exists to carry the
store's own wording to the status line, so the user gets told *why*. That closes
the whole class — it does not depend on knowing that labels are the reason.

Rejected alternatives:

* **Make `register` refuse a duplicate-label declaration.** Changes a shipped
  proc's contract, reds `test_op_annot` row K17's neighbours, and punishes the
  PDK author for a defect in the button.
* **Make `seed` dedupe.** Then the declaration and the seed disagree, which is
  the very split ruling DD-13 was written to remove.
* **Make `set_list` keep duplicates.** Re-opens issue 1288 in the other
  direction, and `_key`/`_save_set` both assume label-uniqueness downstream.

## Still open

All of it. Filed because it is a **binding-ruling** violation reachable by a
supported customisation, and because the next crew to wire the buttons will
otherwise re-derive it from scratch — or, more likely, not at all: no suite row
in the tree constructs a duplicate-label declaration.


---

## FIXED (the reorder half) — item B5-a, 2026-09-04

### ⚠ THE RECOMMENDED FIX ABOVE IS REFUTED BY MEASUREMENT, AND THIS IS THE SENTENCE

> *"A length check on `_edit`'s up/down arm: **after the write**, if `llength` of
> what the store now holds is less than the base, **restore the base** and refuse
> with a sentence."*

**It cannot restore.** Measured on this tree, `op_param_lists` only, no button
code (`scratch_B5-a/probe_d6.tcl`):

```
BASE                          = {id ids 0} {id vgs 2} {gm gm 1}   len 3
OWNS_BEFORE                   = 0
set_list class mos annotation $BASE   -> rc 1
STORED                        = {id vgs 2} {gm gm 1}              len 2
STORED_IDENTICAL_TO_BASE      = 0
```

1. **A `set_list` of the base dedupes it identically**, so "restoring the base"
   stores `{id vgs 2} {gm gm 1}` — a **third** value neither the user nor the PDK
   ever chose, and not the value that was on screen a moment earlier.
2. **When the base came from the SEED the key was previously UNOWNED**, and this
   store has **no verb that un-owns a key**: the fifty-seven procs in
   `::op_param_lists::` include `reset` (which forgets *everything*) and nothing
   else. So the "restore" would leave the store owning a list nobody chose,
   dirty-stamped for the next Save.

**The guard therefore runs BEFORE the write.**

### What was built

`src/op_param_lists.tcl` gains ONE published verb beside `set_list`:

```
op_param_lists::reduce_why {scope key listname triples}
  -> {}         a set_list of these triples would store EVERY row
  -> a sentence it would REDUCE the list, naming the repeated label
```

It reuses `_dup_index`, so the duplicate-label **rule** keeps exactly one
definition (issue 1288) and gains a second **reader** — the `governs` precedent,
this store's own. **`set_list` is unchanged**: 1288's ruling stands, both doors
still reach the same verdict with the same sentence, and this verb adds a reader
rather than a rule. It mints a NEW wording because it states a different fact
from `_dup_why`: *"this change would drop a row"*, not *"a row was replaced in
place"*. All three alternatives this issue rejects are still rejected.

`rdw::_edit`'s **up/down arm** (in `B5-2_working_tree_REFUTED.patch`) consults it
and refuses, carrying the store's own sentence.

### ⚠ THE GUARD COVERS `up`/`down` ONLY, AND THAT TOO IS A MEASUREMENT

Item B5-a's plan said the guard should sit at `_edit`'s single `set_list` call
site, *"covering up, down, delete AND add"*. **Implemented that way it reds
window row BT27**, which golds issue **1288**'s ruled behaviour for the Add door:
an Add whose triple collides by label is **ACCEPTED**, replaces the earlier row
in place, and tells the user once. `rdw::_edit`'s own comment had already said
so — *"the Add is not refused: a third door with a third rule is the
disagreement issue 1288 is about"*.

A **reorder** is definitionally length-preserving, so a shortening reorder is
unambiguously a defect and refusing it cannot be controversial. **Delete** is
neither: DD-10 rules its last row and nothing rules its duplicate label. The
Delete residual — one press drops the named row AND one of the duplicate pair,
out of the display *and* out of the deck, with verdict `ok` — is measured and
filed as issue **1326**, with the option set, because it is the user's to rule
on.

### Fenced by

* store `RD1` — the base reaches `seed` and `effective` intact at length 3,
  `reduce_why` of the exact swap an Up press performs is non-empty and names the
  repeated label, and a real `set_list` of that same value really does come back
  at length 2. The refusal is of a **measured** loss, not a hypothetical one.
* store `RD2` — narrow: `{}` for both shipped seeds, an actual Up swap of one of
  them, a single row and the empty list.
* store `RD3` — one rule, two readers, **both directions driven**: non-empty
  implies strictly shorter, empty implies byte-identical.
* store `RD4` — issue 1288 untouched (green before and after).
* store `RD5` — DD-4/DD-6 in the simulator's own units: three `.save` cards
  become two and `m1[vgs]` is gone.
* store `BE8` (in the patch) — the Up press through the REAL button column is
  refused, `effective` is byte-identical, nothing is owned, all three cards
  stand.

### Sabotage receipts (on a COPY, restored by `cp`, md5-verified)

| variant | red |
|---|---|
| `SAB-REDUCE-BLIND` (`reduce_why` -> `{}`) | store `RD1 RD3 RD5` (+ `J4`, a source-purity artifact of the sabotage's own `rename`) |
| `SAB-REDUCE-ALWAYS` (always a sentence) | store `RD1 RD2 RD3` (+ `J4`) |

### The adversary's receipts, and three predictions that did NOT fire

Verify-C drove Up and Down through the **real button column** on a patched copy:
both are refused, `effective` is byte-identical, the key is **still UNOWNED** (no
half-write), and `op_annot::_cards_for` is byte-identical
`{.save @m.m1[ids]} {.save @m.m1[vgs]} {.save @m.m1[gm]}`. It then fuzzed **200
random triple lists** through `reduce_why` against what `set_list` really
stores: **0 disagreements, 118/118 predicted reductions actual.** The
one-rule-two-readers claim holds under fuzz, not just on the fixture.

⚠ **`SAB-REDUCE-ALWAYS` was predicted to red patch rows `BE2`, `BE3` and `BE3b`
and redded none of them — a STALE PREDICTION, not a hole.** All three are
**Delete** rows, and the implemented guard sits only in `_edit`'s reorder arm,
so no Delete can reach it and no over-refusal can red them. The prediction was
inherited from the plan's original *"guard the single `set_list` call site,
covering four verbs"*, which the implement pass measured as redding row **BT27**
and deliberately narrowed. Verify-C confirmed that independently by
re-implementing the plan's version: **`BT27` RED, store `ALL PASS`.** `BE2`,
`BE3` and `BE3b` are covered by `SAB-APPLY-STUB`, under which all three red.

### Still open — carried risks the adversary named

* ⚠ **`op_param_lists::reduce_why` HAS NO CALLER IN THE TREE.** Its only
  consumer, `rdw::_edit`'s reorder arm, lives inside
  `B5-2_working_tree_REFUTED.patch`. **Until item B5-3 lands, this guard
  protects nothing** — the store verb is published, fenced and green, and the
  defect is still reachable by anything that calls `set_list` directly. A B5-3
  rebase that drops or reshapes the `_edit` hunk would leave every store row
  green with the defect live; only patch row **BE8** would catch it. B5-3 must
  confirm `BE8` is present and red under `SAB-REDUCE-BLIND` after its rebase.
* **The refusal is all-or-nothing, and that cost is stated for Delete in issue
  1326 but was not stated here.** With a duplicate-label declaration live,
  **every** Up/Down is refused, including on rows that have nothing to do with
  the duplicate — measured: an Up on `gm` is refused with a sentence about label
  `id`. Conservative and defensible (a reorder is definitionally
  length-preserving, so the store cannot tell a safe swap from a lossy one
  without keeping duplicates, which reopens 1288), but a user whose PDK declares
  a duplicate label cannot reorder that class's list at all until the
  declaration is fixed. Recorded so it is not discovered as a surprise.
