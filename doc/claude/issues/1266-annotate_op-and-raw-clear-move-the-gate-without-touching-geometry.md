# 1266 — `annotate_op` and `raw clear` move the gate **without touching geometry**, so the click box and the render disagree again

**Filed** 2026-09-02 by item **A6**, from the adversary pass. **Measured, not
fixed. It is a FIFTH door, and it is not a `symbol_bbox()` door — which is why
A6-c could not reach it.**

## What A6-c fixed, and what it cannot fix

Item A6-c put the gate refresh inside `symbol_bbox()` itself
(`src/select.c`), so **every one of its 39 callers** now writes a click box from
a fresh gate. Four Tcl-reachable doors were driven and are green (rows A49..A53
of `tests/headless/test_annot_declutter_1244.tcl`): `setprop instance`,
`move_instance … nodraw`, `reset_inst_prop`, and `select_element()`'s deselect
write.

**That repair is reachable only from a `symbol_bbox()` call.** Two verbs change
the gate's *answer* while calling `symbol_bbox()` **not at all**, so the stored
box stays as it was and the render moves out from under it.

## Measured, 2026-09-02, row A40's protocol (stale door read FIRST, no draw,
no export, no `update_all_sym_bboxes` in between)

**Forward.** Mask 9 armed, boxes warm, **no raw**: bbox `150 -380 496.505
-232.837`, `instance_at 430 -245` answers `M1`. Then `xschem annotate_op <raw>`:
the render becomes `M1 {zid = 11.1u} {zgm = 333u}` — `VCW=1u` and `VCGATE` are
gone, the device shrank — while the stored bbox is **still the wide one** and
`instance_at 430 -245` still answers `M1` **over blank canvas**.

**Reverse.** `xschem raw clear` at mask 9: the render shows `VCW=1u VCGATE`
again while the bbox is the narrow `277.5 -340 320 -280`, and a click **on the
visible text** answers **nothing**.

## Reach

Mitigated in the shipped chord paths — `cadence::annot_declutter`
(`utils/annot_mode.tcl:2968`), the `6` path (`:1505`) and the tran path
(`:2740`) each call `xschem update_all_sym_bboxes`. **Not** mitigated in
`op_annot::db_attach`'s own return path, nor for any script or ASE flow that
annotates without a bbox pass, nor for a user typing the documented verb.

**Item B4 clicks these devices**, and `findnet.c:461`'s `find_closest_element()`
uses `POINTINSIDE` against exactly this box.

## Fix shape, and why A6 did not take it

The natural repair is a bbox pass on the two verbs that move the gate —
`annotate_op` and `raw clear` — rather than another sync site. Both live in
`src/scheduler.c`, and both are **outside item A6's Files cell**; A6 had already
widened that cell three files for A6-b and would not widen it again at feature
close to fix something the adversary found after the implementation was frozen.
Ladder **L2**, recorded here rather than done quietly.

**Do not "fix" it by adding a sixth `annot_overlay_sync()`.** The cache is
already fresh on those paths; what is stale is **geometry**. The repair is a
bbox recompute, i.e. `update_all_sym_bboxes()`, and it belongs where the gate's
answer changes.

## Consequence for A6's claim

A6's row **A53** proves the drawn thing and the clickable thing are one object
**after a `symbol_bbox()` door**. That is what its ACCEPT row asked for and it is
true. It is **not** the general statement "they are always one object" — this
issue is the counter-example, and A6's PLAN entry says so.

## Still open

All of it. **Item B4 must still call `xschem update_all_sym_bboxes` before its
first pick and carry a row that reds if it does not** — that instruction, first
written under issue 1252 and repeated under 1260, survives A6 intact.
