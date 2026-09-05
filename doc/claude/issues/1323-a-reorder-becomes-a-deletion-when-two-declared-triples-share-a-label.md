# 1323 — a reorder becomes a deletion when two declared triples share a label, so a Up press changes what the simulator saves

**Status:** FILED, NOT FIXED. Measured 2026-09-04 on `fluid-editing` at
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
