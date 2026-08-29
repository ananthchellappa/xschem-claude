# 0922 — an expression trace added to the results paints a fabricated `0` on the schematic

**Status:** 🔴 **OPEN — measured, filed, deliberately not fixed.** Filed
2026-08-29 by the write-up pass of item **B3** (issue
[0861](0861-spice-get-node-renders-a-fabricated-0-when-nothing-is-published.md)),
from a finding of B3's second verification pass and re-measured by hand before
filing. Number claimed as a stub before the work started, per house rules.

**Not a regression from 0861.** The pre-fix unguarded read produced the identical
`0`, and this case sits outside 0861's six acceptance rows. But it is the **same
fabricated zero, the same array, the same accessor and the same shipped drawing
path**, so the RULING **D5-1** class 0861 belongs to is *not* closed by 0861.

## What the user sees

The user has an operating point on screen. They open the waveform viewer's trace
dialog and add an **expression trace** — the thing that turns `v(d) 2 *` into a
plotted signal. Every `@spice_get_node` text on the schematic that names that new
signal — a probe symbol, or the shipped
`xschem_library/devices/scope_ammeter.sym` — paints **`0`**.

Zero is not what the expression evaluates to. It is a freshly allocated array
slot. On the ammeter it reads, again, as a confident zero amps through the
branch.

## The measurement

Same fixture as 0861: `probe.sym` carrying `T {X=@spice_get_node …}`, one
instance on a sheet, a 3-point database whose `v(d)` is 1.8 / 1.9 / 2.0. Taken
2026-08-29 on the **fixed** tree (item B3 landed), so this is what ships:

```
  base v(d)        annot=0 0 -1  text=X=1.8   verb=1.8
  raw add v(derived) = v(d) 2 *
  point 0/1/2      -> 3.5999999  3.8000002  4      <-- the real column, correct
  annot after add  -> 0 0 -1                       <-- still "published"
  derived TEXT     -> X=0                          <-- FABRICATED
  derived VERB     -> |0|
  op_annot::raw_or_blank -> |0|
  TRUE value at the published point (point 0) is 3.5999999
```

The column itself is right. Only the **cursor-B slot** for it is a zero, and the
cursor-B slot is what every annotation surface reads.

## Root cause, one line

`raw_add_vector()`, `src/save.c:1205-1206`:

```c
    my_realloc(_ALLOC_ID_, &raw->cursor_b_val, raw->nvars * sizeof(double));
    raw->cursor_b_val[raw->nvars - 1] = 0.0;
```

The new column's cursor slot is initialised to `0.0` and **`annot_p` is left
where it was** — deliberately, and the comment eight lines above says so: *"a raw
MUTATED IN PLACE keeps the same Raw allocation, the same level and the same
`annot_p`"*. That is correct for the existing columns and wrong for the new one.

## Why 0861's guard cannot see it, and why that matters for the comment

0861's fix is the term `annot_p >= 0` on both readers — the rendered text
(`spice_get_node()`, `src/token.c`) and the verb (the cursor fall-through of
`xschem raw value`, `src/scheduler.c`). Here `annot_p` **is** 0. The term is
present, true, and insufficient: `annot_p` answers *"was an annotation
published"*, not *"is THIS column's slot a measurement"*.

So the reconciled inventory comment in `update_op()` (`src/save.c:2159-2190`)
**overstates its own closure**. It now says *"Both are guarded now"* and lays
down the rule *"Adding a reader of `cursor_b_val` obliges you to add the
`annot_p` term to it and to this list, in the same commit."* That rule is right
as far as it goes and it does not cover this: the defect here is a **writer**,
not a reader, and no reader-side term can catch it. Fixing this issue should
amend that paragraph rather than leave a second inventory going quietly false —
which is the exact failure mode 0861 was about. Note that
`tests/headless/test_spice_get_node_0861.tcl` row `SGN19` cannot see the drift
either; issue [0921](0921-the-comment-lock-catches-the-old-wrong-prose-coming-back-but-not-the-new-correct-prose-going-away.md)
records why.

## Scope — it is worse on an operating point than on a transient

Measured both ways on the fixed tree:

* **Transient with a waveform cursor.** It self-heals the moment the user moves
  the cursor, because `callback.c`'s cursor pass refills every slot:

  ```
    after add:    annot=0 1e-09 0   text=X=0     (true value at 1e-9 is 3.8000002)
    cursor moved: annot=1 2e-09 0   text=X=4
    cursor back:  annot=0 1e-09 0   text=X=3.8
  ```

* **Operating point.** There is no cursor to move, so the zero **stands** until
  the user re-annotates — which rebuilds the database from the file and deletes
  the added vector outright. That is the case a user actually hits: add an
  expression trace while an operating point is annotated, and the schematic
  carries a fabricated zero for as long as the vector exists.

## Acceptance if fixed

1. On a published operating point, adding `v(derived) = v(d) 2 *` makes the
   `@spice_get_node v(derived)` text paint the real value at the published point
   (`3.5999999` on the fixture), or blank — never `0`.
2. The verb `xschem raw value {v(derived)} -1` and `op_annot::raw_or_blank`
   agree with the rendered text (RULING **D5-4**), whichever answer row 1 takes.
3. **Positive twin.** Every existing column is unchanged: the base `v(d)` text
   still paints `1.8`, and the numbered-point reads of the new column still
   answer `3.5999999 / 3.8000002 / 4`.
4. **Positive twin.** The transient-with-a-cursor path is unchanged after the
   first cursor move, and the refused-transient blank of 0861 still blanks.
5. The `update_op()` inventory comment in `src/save.c` is amended so it no longer
   reads as if the reader-side `annot_p` term closed this class.
6. Sabotage: restore the `0.0` initialisation and confirm row 1 reds.

## Two shapes a fix could take, neither chosen here

* **Fill the slot.** Evaluate the expression at the published point and write the
  real number into `cursor_b_val[nvars-1]`, the way `update_op()`'s fill loop
  does for every other column. Correct, and it needs the annotation point, which
  `raw_add_vector()` does not currently look at.
* **Mark the slot unpublished.** Carry a per-column "this slot has no value"
  flag so the readers blank it. Wider, and it touches every reader again.

The first is smaller. Neither was attempted, because choosing between "the real
number" and "blank" is a user-visible decision and B3 was not scoped to make it.

## Related

* **0861** — the two readers this defect walks straight past. FIXED.
* **0921** — `SGN19` locks the old wrong prose out but does not lock the new
  correct prose in, so an amendment to the same comment is unguarded.
* **0920** — the other half of the same arm, also open.
* RULING **D5-1**, RULING **D5-4**, INVARIANT **I3**.
