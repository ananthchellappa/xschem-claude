# 1254 — two coverage holes in the declutter suite: the sync line is measured by nothing, and row A17 cannot detect what it names

Status: **FIXED** by item **A5-d**, 2026-09-02 (measured by item A3's sabotage
pass; both rows repaired in place and **shown failing** under the sabotage that
used to leave them green). **A third hole, found afterwards, is filed as 1261.**
Branch: `fluid-editing` · Related: **1244**, **1248** (the same suite's earlier
holes), **1252**

Both holes are in `tests/headless/test_annot_declutter_1244.tcl` (82 checks, ALL
PASS). Neither is a defect in the shipped feature; both are places where the suite
would stay green while the feature broke.

## Hole 1 — the `scheduler.c` overlay-sync line is guarded by nothing

Item A3 added one line to `src/scheduler.c`'s `update_all_sym_bboxes` arm:

```c
annot_show_sync_cache();
annot_overlay_sync();     /* <- added by A3 */
```

It is what keeps the click target from being one epoch behind the screen (see
**1252**). Item A3's plan asserted *"the sync alone reds A15"*. **Measured, and
that is false.** Sabotage variant `SB7b` — neutralize only that call, leave
`select.c` correct:

```
test_annot_declutter_1244  ALL PASS (82)
test_op_annot              ALL PASS (492)
test_annot_show_menu       ALL PASS (36)
```

**Cause**: row **A15** does `xschem load $A_SAV` immediately before
`annotate_op`, which leaves the overlay cache **cold**, so the first gate call
after `update_all_sym_bboxes` populates it fresh and no staleness can exist.

**Repair**: A15 must **warm** the cache with a *different* annotation state first
— export or redraw at mask 9 against one raw, then annotate a second raw whose
`op_annot::text` block differs or is blank — and only then run
`update_all_sym_bboxes` with no redraw and no export before reading the bbox.
Until then, a future editor can delete that line and every suite stays green.

## Hole 2 — row A17 cannot detect that the gate stopped honouring `hide_symbols`

Row **A17** is labelled *"`hide_symbols=2` CLOSES the D-6 gate"*. It compares the
mask-1 and mask-9 renders at `hide_symbols=2` and asserts they are identical.
Under sabotage `SB-GATE-ALWAYS` (`annot_instance_annotated()` replaced by
`return 1`, so `hide_symbols` is ignored entirely) **A17 stayed green** — because
at `hide_symbols=2` the keep-name filter has already reduced both renders to names
only, so the rung has nothing left to remove and the two are identical either way.

Three other rows caught that sabotage (I2, N11, A6, A7), so the *gate* is covered;
what is not covered is the specific claim A17's name makes.

**Repair**: give A17 a text the keep-name filter keeps and the rung would hide, or
assert the gate directly rather than through a doubly-filtered render.

## Why neither was fixed in item A3

Ladder **L2**. Both repairs are new test *fixtures*, not row edits: hole 1 needs a
second raw with a different block, hole 2 needs a symbol whose keep-name-surviving
text is not a name. Writing and re-verifying two fixtures in the write-up pass —
after the tiers, the sabotage matrix and the adversary pass had all been run
against the suite as it stands — would have changed the artefact the verdict was
taken on. **Rejected:** leaving them unrecorded, which is the failure mode
CLAUDE.md names ("a standing red is a defect, not furniture" — a standing *green*
that cannot go red is the same defect with better manners).


---

## FIXED by item A5-d, 2026-09-02 — both rows shown failing

### Hole 1 — the sync line (row A15)

The cause was sharper than "a cold cache": `xschem annotate_op` itself runs
`update_op(); draw();`, and `draw()` calls `annot_overlay_sync()` **above** the
`if(has_x)` guard, so it runs headless too and the sync line under test is always
redundant on row A15's path. Measured on A15's exact sequence: flushes 24 after
load, 25 after `annotate_op`, **25** after `update_all_sym_bboxes` — the line
under test flushed **zero** times.

**Repaired in place, same row number:** A15 now inserts an **epoch move with no
draw** (`xschem raw clear`) between the warm and the read, so the sync has
something to flush; its assertion flips direction (with no raw the A5-a gate is
closed, so the box must have grown **back**) and it gains a flush-delta leg.

**Shown failing:** `SB7b` (an `annot_overlay_sync_noop()` shim applied to *only*
the `update_all_sym_bboxes` sync) reddened **nothing** against the pre-A5 suite.
Against the repaired row it reds **A15** (plus A41, an additional true positive:
the source census sees the renamed call). **A40 stayed green**, which is what
proves A15 and A40 guard two different lines.

### Hole 2 — row A17

**⚠ THIS ISSUE'S FIRST RECOMMENDED REPAIR IS REFUTED and must not be attempted:**

> *"give A17 a text the keep-name filter keeps and the rung would hide"*

That text **cannot exist** on this tree. The keep-name filter is
`annot_name_token(text.txt_ptr)` (`src/draw.c`, `src/svgdraw.c`, `src/psprint.c`)
and the rung's exemption is `flags & TEXT_ANNOT_NAME`, set by
`annot_name_token(t->txt_ptr)` in `src/actions.c` — survivor and exempt are **one
predicate**, so the intersection is empty.

**The issue's second option was taken:** assert the **bbox**, which is the one
window open at `hide_symbols=2`. Measured: at `hide_symbols=2` the box is
identical at masks 1 and 9 and equals the un-decluttered box (495.71), against
322.629 at `hide_symbols=0` mask 9 — so a gate that ignores `hide_symbols` shrinks
the mask-9 reading and reds the row, where the doubly-filtered render cannot see
it.

**Shown failing:** `SB-GATE-ALWAYS` (`annot_instance_annotated()` → `return 1`)
left A17 **green** before. Against the repaired row it reds A17 together with I2,
N11, A6, A7, A15, A30, A32, A35, A40 and E6.

### Still open

* **1261** — a third hole of the same shape, found by item A5's adversary pass:
  `draw.c`'s leg of issue 1253 is guarded by a source-text census although
  `xschem print png` gives a real behavioural window. Not closed, because the
  write-up agent may not rebuild and so could not show a new row failing.
