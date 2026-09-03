# 1252 — the declutter's gate is fresh at one `symbol_bbox()` caller and stale at the other 38

Status: **FIXED** by item **A5-c**, 2026-09-02 (measured by item A3; the
`recompute_inst_bbox` door now syncs). **Residue filed as 1260** — two further
doors and the mask half of the gate. · Branch: `fluid-editing`
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


---

## FIXED by item A5-c, 2026-09-02 — and this issue's recommended repair was refuted

**What landed.** One line in the `recompute_inst_bbox` arm of `scheduler()`
(`src/scheduler.c`), after the `!xctx` guard and before either `symbol_bbox()`
branch:

```c
      annot_overlay_sync();
```

with a comment naming the measurement and both rejected repairs.

**THE SENTENCE THIS ISSUE RECOMMENDED IS REFUTED, and item A5 says which one:**

> *"i.e. call `annot_overlay_sync()` wherever `annot_show_sync_cache()` is already
> called (12 sites)"*

The measured stale door — the `recompute_inst_bbox` arm — calls **neither** cache
sync, so that repair as written leaves the defect exactly where it was found. (The
real `annot_show_sync_cache()` call sites are 8, not 12; four of the greps are
comments. The four not already paired are `xschem print`, `calc_drawing_bbox`,
startup and the CLI batch print, and none of them is a `symbol_bbox()` caller that
can observe a stale gate.) This issue's *rejection* of syncing inside
`symbol_bbox()` itself is **not** refuted and still stands.

**Measured before (item A5's measure pass, verbatim):**

```
A5c warm  bbox           = 277.5 -340 322.629 -280
A5c after re-register, op_annot::text MA1 = <<>>   (no draw, no export)
A5c STALE door  recompute_inst_bbox : bbox 277.5 -340 322.629 -280  flushes 21  instance_at(430,-245)={}
A5c FRESH door  update_all_sym_bboxes: bbox 277.5 -340 495.71 -232.78  flushes 22  instance_at(430,-245)={MA1}
```

**After:** row **A40** of `tests/headless/test_annot_declutter_1244.tcl` drives
both doors — **stale door read first**, because any sync repairs the cache and a
row that syncs before the stale read measures nothing — and asserts the two boxes
equal and both `instance_at` picks returning the instance.

**Sabotage:** `SB-A5c-RECOMPUTE` (an `annot_overlay_sync_noop()` shim at *only*
the new call, leaving the `update_all_sym_bboxes` site and the three draw/export
sites correct) reds **A40 and A41**, exactly as predicted, and nothing else.

## Still open — see **1260**

Item A5's acceptance sentence *"the gate agrees at both `symbol_bbox()` callers"*
is true of the two **Tcl-reachable bbox verbs** and of the **overlay-cache half**
of the gate. Measured after the fix and filed as **1260**: `xschem setprop
instance` and `xschem move_instance … nodraw` both write the click box from a
stale gate (and item A5-a *widened* the first of those, because a rename over a
dead raw now flips the gate where before it did not), and a bare
`set ::annot_show` makes the two doors answer opposite picks because the **mask**
half is deliberately not synced at `recompute_inst_bbox`.


---

## ⚠ THIS ISSUE'S REJECTED OPTION WAS DELIBERATELY REVERSED — item A6-c, 2026-09-02

This issue rejected "one `annot_overlay_sync()` inside `symbol_bbox()`" on two
grounds, re-entrancy and cost. **Item A6-c took it anyway**, and answered both
rather than ignoring them:

* **Re-entrancy** was already closed in code. `annot_overlay_sync()` is the
  function that *frees* the cache, and it early-returns on `annot_overlay_busy`,
  which `annot_overlay_cached_text()` sets around exactly the `tcleval` that can
  re-enter through `translate()` → `prepare_netlist_structs()` →
  `link_symbols_to_instances()` → `symbol_bbox()`. This issue argued from the
  hazard, not from the code that answers it. Separately verified: `draw.c`,
  `svgdraw.c` and `psprint.c` contain **zero** calls to `symbol_bbox()`, so no
  drawer can free the block it is holding.
* **Cost** is answered by a bit-3 prefilter. With the declutter unarmed — every
  load, every netlist pass, every other suite, all 378 audit cases —
  `symbol_bbox()` does two Tcl variable reads and **no sync**. Measured flush
  delta **0** for `update_all_sym_bboxes` and for 20 consecutive
  `recompute_inst_bbox` at every mask; ~1% on a 49-instance sheet.

The alternative — syncing at each named door — would have been six sites and
**still left ~33 callers stale**, which is precisely how this issue became issue
**1260**. **Do not "restore" the rejection.** Full record: issue 1260's closing
section. ⚠ A6 did not land; see PLAN.md's A6 entry.
