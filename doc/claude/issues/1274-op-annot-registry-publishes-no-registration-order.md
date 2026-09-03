# 1274 — `op_annot` publishes no registration order, so "first registered wins" is unimplementable as written

**Status: MEASURED, FILED, NOT FIXED.** Item B2 may not edit `src/op_annot.tcl`,
and shipped a deterministic substitute instead. Recorded here so the substitute
is not mistaken for the rule it stands in for.

## The measurement

The driver's stated default for item B2's class seed is *"if two types in one
class ever disagree, FIRST REGISTERED WINS and the divergence is reported
once."* That cannot be implemented against today's registry:

* `::op_annot::desc` is a **Tcl array** (`op_annot.tcl:231`). `array names`
  answers **hash order**, not insertion order.
* `op_annot` publishes **no enumerator at all** — there is no `op_annot::types`,
  and no other accessor exposes the order in which `op_annot::register` was
  called.

So no caller can know which type was registered first.

## What B2 shipped instead

**First in LEXICAL ORDER OF THE `type=` TOKEN wins.** It is deterministic, it
**coincides with registration order for every PDK in this tree** (each registers
via `foreach t {nmos pmos}` — sky130A:397, gf180mcuD:103, ihp-sg13g2:751), and
nothing is ever merged: a merged list is one no PDK ever declared, which is the
invented data ruling D-4 forbids. The divergence is reported once per class
(`::op_param_lists::seed`).

**No shipped PDK produces the disagreement at all** — all three register `nmos`
and `pmos` with byte-identical `params` — so the rule ships unexercised against
real data. `tests/headless/test_op_param_store_1245.tcl` row **S3** builds a
synthetic disagreeing pair rather than leaving it untested.

## The one-line repair, when someone owns op_annot.tcl

Keep an insertion-ordered list beside the array in `op_annot::register` and
publish it as `op_annot::types`. Then `::op_param_lists::seed` orders its
candidates by that list instead of `lsort`, and the driver's sentence becomes
literally true. Nothing else in the tree needs the order today.
