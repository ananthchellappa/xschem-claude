# 1267 — three coverage holes found by item A6's own sabotage pass

**Filed** 2026-09-02 by item **A6**. The same shape as issue **1254** (A3's two
holes) and **1248**: places the suite stays green while the feature breaks. None
is a defect in shipped behaviour; each is a place a future regression hides.
**Measured, not fixed.**

## Hole 1 — the `dims=0` **parse** is guarded by exactly one row

Sabotage **SB-A6b-NOPARSE** (rename `raw_line_dims_zero()` and shadow it with a
same-signature stub returning 0, so `read_dataset()` never fills `raw->dims0`):
predicted 2 red, **observed 1** — row **A45** only, 119 passed.

Row **A48**, which the plan named as the structural fence, stayed **green**. Its
five structural legs count `raw_vector_absent(` occurrences and check the shape
of the `raw value` arm — none of which move when the parser that *fills* `dims0`
is dead — and its behavioural leg (`xschem raw value <v> 0` == 0) is satisfied
identically whether the mechanism works or not.

**So row A45 is the single point of coverage for the whole of A6-b's parse. If
A45 is ever weakened, A6-b becomes silently untested.**

## Hole 2 — the defence of the numbered-point read is one list element, in the
suite A6 owns, and no unowned suite backs it

Sabotage **SB-A6b-NUMBERED** (hoist the `&& !raw_vector_absent(raw, idx)` term
off the annotation fall-through onto the enclosing `if(idx >= 0)`, so an
in-range **data-inspection** read is blanked too): predicted 5 red, **observed
1** — row **A48**, and only its last element (`{2 1 1 1 1 1 {}}` vs expected
`{2 1 1 1 1 1 0}`).

* `test_raw_read_dispatch` stayed **ALL PASS (137)**. The plan named it as the
  fence on the numbered-point read; **it is not one.** 137 checks, none of which
  notice that an in-range `xschem raw value <v> <n>` stopped answering.
* `test_spice_get_node_0861` **SGN13 / SGN14 / SGN22** stayed **green**. They
  fence the *source shape* of the arm — an `annot_p` term, exactly one
  `cursor_b_val` subscript — and this mutation preserves both.

The shipped source comment states that data inspection must stay live. The whole
defence of that sentence is one element of one list, in A6's own file.

## Hole 3 — the hazard the pull/backstop **split** exists to prevent has no
behavioural coverage anywhere

A6-c split `annot_show_sync_cache()` into a pull plus the 0688
`annot_show_check_root()` backstop, and calls only the pull from
`symbol_bbox()`, because the backstop can `annot_show_set(0)` and a read-only
geometry verb must not be able to **disarm the annotation**.

Sabotage **SB-A6c-BACKSTOP** (call the full `annot_show_sync_cache()` from
`symbol_bbox()` instead — behaviourally plausible, and it puts a mask clearer on
a geometry verb): predicted 3 red, **observed 2** — rows **A55** and **A56**,
both **structural**. The behavioural legs did not fire:

* Row **A54**'s final leg (`recompute_inst_bbox` must not change
  `xschem get annot_show`) stayed green, because the 0688 backstop only clears
  the mask when the window's **root sheet** changed underneath it, and A54's
  fixture never changes root. The suite's own comment beside that leg admits it:
  *"IT IS GREEN BEFORE AND AFTER"*.
* `test_op_annot` **Y11** stayed green. Y11 golds `annot_show_check_root()`'s
  tree-wide **call-site census** at 3, and this mutation adds no call site — it
  reaches the backstop **transitively** through `annot_show_sync_cache()`. **A
  census check cannot see a new transitive caller**, so Y11 is not the guard the
  plan took it for.

**Only structural rows stand between the tree and that regression.**

## The row that closes hole 3

Warm the mask, **swap the root sheet**, then call `xschem recompute_inst_bbox`
and assert the mask survives. That is the fixture A54 is missing.

## Two plan mis-attributions, recorded so nobody re-derives them

Not holes — the rows named were simply the wrong ones:

* `SB-A6a-ALWAYS` / **A17**: green because A17's fixture sets `hide_symbols=2`,
  which closes the D-6 gate one rung **above** the value gate.
* `SB-A6c-NOSYNC` / **A55**: green because the `select.c` `annot_overlay_sync()`
  census lives in **A41** (re-golded 0 → 1) and **A56**, and both fired.
* `SB-A6b-ALWAYS-ABSENT` listed `test_zero_point_raw_0836` and
  `test_annot_op_behind_tran_1242` as backstops. Both stayed ALL PASS: neither
  reads through the `raw value` annotation fall-through. The real unowned
  backstops are `test_op_annot` (64 red) and `test_spice_get_node_0861` (3 red).

## Still open

All three holes.
