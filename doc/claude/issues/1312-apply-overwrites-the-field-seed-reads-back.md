# 1312 — `apply` writes the union into `params`, and `seed` reads that same field back as "the PDK's own list"

**⚠ ESCALATED 2026-09-04: this is not only an order defect. It DESTROYS PDK
rows, and it is the BLOCKER that refuted and reverted item B5 — see issue
1314.**

**Filed by item B5 (2026-09-04), which is the first caller of
`op_param_lists::apply` in the tree. Measured, NOT fixed.** Status: **FILED, NOT
FIXED.**

## The collision, in two lines of the store

* `op_param_lists::apply` writes `_save_set` — the **union** of the annotation
  and summary lists, in **annotation-then-summary order** — into the
  descriptor's `params` (ruling **DD-6**: `params` is what the run computes).
* `op_param_lists::seed` reads the PDK's list through `_params`
  (`src/op_param_lists.tcl:700`), which reads **`dict get $d params`** — the very
  field `apply` has just overwritten.

So after the first `apply`, "the PDK seed" is no longer the PDK's list. It is
whatever the last apply computed, in whatever order the user's annotation list
happened to be in.

## Measured, on this binary, 2026-09-04

Two `type=` tokens in one class, both registered with `{{id ids 0} {gm gm 1}
{gds gds 1}}`, nothing owned:

```
seed0        = {id ids 0} {gm gm 1} {gds gds 1}
eff summary0 = {id ids 0} {gm gm 1} {gds gds 1}
                     # now the user REORDERS the ANNOTATION list only
reordered annotation = {gm gm 1} {id ids 0} {gds gds 1}
apply        = zz1 zz2
descr params = {gm gm 1} {id ids 0} {gds gds 1}
seed1        = {gm gm 1} {id ids 0} {gds gds 1}
eff summary1 = {gm gm 1} {id ids 0} {gds gds 1}   <-- the SUMMARY list nobody owns
```

**Reordering list 1 silently reordered what list 2 answers**, with nothing said
anywhere. The user never touched the summary list and does not own it. That is
invariant I3's family — a plausible wrong answer, on a schematic, with no
report.

## ⚠ AND IT IS A DATA-LOSS DEFECT. The paragraph that used to stand here was wrong.

This file originally said *"the content is not lost (the union is a superset),
so this is an order and provenance defect, not a data-loss one"*, copying
`_save_set`'s own in-code comment. **Both are false, and they are false in
exactly the case this feature creates.** The superset argument holds only while
at least one of the two lists is UNOWNED — an unowned list answers the seed, so
the union re-includes it. Own both, which two Delete presses do, and the union
consults no seed at all.

Measured 2026-09-04 on `./src/xschem` at `79f163cb`, driving the reverted B5
button path, broad scope:

```
PARAMS0    = {id ids 0} {gm gm 1} {gds gds 1}
  delete gm from annotation ; apply
PARAMS1    = {id ids 0} {gds gds 1} {gm gm 1}     # reordered, still present
  delete gm from summary    ; apply
PARAMS2    = {id ids 0} {gds gds 1}               # gm is GONE from params
SEED2      = {id ids 0} {gds gds 1}               # and gone from the PDK seed
SIBPARAMS2 = {id ids 0} {gds gds 1}               # and from the sibling type
```

`op_annot::_cards_for` iterates `params`, so the `.save` card goes with it and
**the simulator stops being asked to compute the parameter** — a direct
violation of binding ruling **DD-4/DD-6**. Nothing can put the row back inside
the session: `reset` restores the user's lists, not the descriptor, and the
window's own Add refuses because no list and no seed declares it any more.

The provenance half is real too and was always real: a row the user ADDS to the
annotation list ends up in the PDK seed, so a later `reset` of the user's own
list answers a seed that carries the user's row.

## What item B5 tried, and why it was reverted

B5's containment was *"Delete and Add apply; a reorder does not"* — Delete and
Add paying the cost because their visible effect **is** the feature. That
containment is what the transcript above defeats: the two presses that destroy a
PDK row are both Deletes, so the one path B5 chose to keep applying is the one
path that loses data. The item's adversary landed the attack, the write-up agent
re-measured it, and **item B5 was reverted in full** (status F, patch preserved
at `doc/claude/op_param_batch/B5_working_tree_REFUTED.patch`).

**So there is no containment in the tree, and none is possible from
`src/rdw.tcl` alone.** Any caller of `apply` that can own both lists inherits
this. Fixing it is a change to `src/op_param_lists.tcl`, which B5's Files cell
forbids — which is itself the finding: **B5 was mis-scoped and cannot be
delivered until this issue is fixed.**

## Options

* **(a)** give the descriptor a separate key for the PDK's own declaration
  (written once, by `op_annot::register`, never by `apply`) and have `_params`
  read that. Smallest change that makes `seed` mean what its name says; costs one
  descriptor key and a line in the three PDK `_procs.tcl` header comments.
* **(b)** have `apply` refuse to overwrite `params` when the value it would write
  differs only in ORDER from what is there. Cheap, and wrong: it would also
  freeze the drawn order, which is what Up/Down exist to change.
* **(c)** have `seed` cache the first `_params` answer per type. Rejected: a
  cache that outlives an `op_annot::register` from a user's rc breaks invariant
  I5 (a user's own registration must take effect on redraw).

**Recommended: (a), and it is now a BLOCKER, not a nicety.** With it, the reorder can apply like every other edit and
row **BT8** of `tests/headless/test_rdw_window_1245.tcl` — which asserts that
reordering the annotation list leaves `effective ... summary` at the PDK seed —
still holds.

## Related

Sibling of **1292** (nothing ever removes `shown`, so Reset/Defaults cannot be
built on `reset` + `apply`). Both are the same shape: `apply` writes descriptor
state that no verb can put back.
