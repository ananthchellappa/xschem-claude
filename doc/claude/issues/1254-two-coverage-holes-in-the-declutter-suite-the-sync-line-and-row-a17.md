# 1254 — two coverage holes in the declutter suite: the sync line is measured by nothing, and row A17 cannot detect what it names

Status: **open** (measured by item A3's sabotage pass, 2026-09-02; **not fixed**)
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
