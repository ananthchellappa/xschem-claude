# 1252 — the declutter's gate is fresh at one `symbol_bbox()` caller and stale at the other 38

Status: **open** (measured by item A3, 2026-09-02; **partially mitigated**, not
fixed) · Branch: `fluid-editing`
Related: **1244**, ruling **D-6**, issue **0453** (same staleness shape), item
**B4** (which clicks these devices)

## The defect

Item A3 put the declutter's per-instance gate — `annot_instance_annotated()`,
ruling D-6 — behind `symbol_bbox()` (`src/select.c:709`), so a decluttered
device's **with-text bounding box** shrinks to what is still drawn and the click
target follows the pixels. The gate reads the **overlay cache**, and that cache is
refreshed by `annot_overlay_sync()`, which has **four** call sites. `symbol_bbox()`
has **thirty-nine**.

Measured 2026-09-02 on this tree:

```
$ grep -rn "annot_overlay_sync()" src/*.c | grep -v ' \* '
src/draw.c:10545       src/svgdraw.c:1105      src/psprint.c:1381
src/scheduler.c:14453   <- added by item A3, in the update_all_sym_bboxes arm

$ grep -rn "symbol_bbox(" src/*.c | grep -v "void symbol_bbox" | wc -l
39            (actions.c 6, draw.c 1, editprop.c 4, move.c 6,
               save.c 6, scheduler.c 10, select.c 5, token.c 1)

$ grep -rn "annot_show_sync_cache()" src/*.c | grep -v "void annot_show" | wc -l
12            <- the SIBLING cache, for comparison
```

Three of the four overlay-sync sites are draw/export entry points. So every
`symbol_bbox()` caller that runs **outside** a draw, an export, or
`update_all_sym_bboxes` computes its box from whatever epoch the cache last
flushed at — which may be empty (never drawn) or one annotation behind.

## What item A3 already mitigated, and what it did not

**Mitigated:** `scheduler.c`'s `update_all_sym_bboxes` arm now syncs the overlay
epoch beside the annotation-class one. Without that line the shipped idiom
`annotate_op; update_all_sym_bboxes; redraw` computed every box — and therefore
the click target — from the **pre-annotate** cache, so the pick disagreed with
the screen for one pass. Row **A15** of `tests/headless/test_annot_declutter_1244.tcl`
drives exactly that sequence with no redraw and no export in between.

**Not mitigated:** the other 38 callers. Reproduced, item A3's adversary pass:

```
load; set annot_show 9; annotate_op; export      (no update_all_sym_bboxes)
  -> the RENDER is decluttered
  -> `xschem instance_at 430 -245` and `180 -380` still answer M1, over blank canvas
one explicit `xschem update_all_sym_bboxes` fixes both
```

**No shipped path is exposed today**: all three mask writers
(`src/xschem.tcl`'s two Op-Annotate menu bodies, `cadence::annot_declutter`,
`ase::ui::annot_apply`) call `update_all_sym_bboxes` before redrawing. The
exposure is a hand-written script — **and item B4, which picks these devices from
a path of its own**.

## Why it was not fixed here (ladder L2)

Syncing inside `symbol_bbox()` itself is the obvious repair and is the wrong size:
it would tcleval `::op_annot::text` from a function with 39 callers, six of them
in `save.c`, and the re-entrancy guard (`annot_overlay_busy`) exists precisely
because that path can re-enter `symbol_bbox()`. **Rejected** for blast radius. The
smallest correct thing was to sync at the one caller whose whole job is "make the
boxes current", which is what landed.

## Recommended repair

Give the overlay cache the same treatment issue **0453** gave its sibling: sync at
the *epoch* boundary rather than at the draw entry points — i.e. call
`annot_overlay_sync()` wherever `annot_show_sync_cache()` is already called (12
sites), which costs a struct compare when the epoch has not moved. Item **B4**
should either do that or call `update_all_sym_bboxes` itself before its first
pick, and its suite should carry a row that fails if it does not.
