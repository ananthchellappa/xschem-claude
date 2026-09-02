# 1260 — 1252's residue: two more `symbol_bbox()` doors, and the mask half of the gate

Status: **open** (measured first-hand by item A5's adversary pass and again by
its write-up pass, 2026-09-02; **not fixed**) · Branch: `fluid-editing`
Related: **1252** (fixed by item A5-c), **1244**, **0453**, ruling **D-6**,
item **B4** (which clicks these devices)

## The defect, in one sentence

Item A5-c made the declutter's per-instance gate fresh at the
`recompute_inst_bbox` `symbol_bbox()` door as well as `update_all_sym_bboxes`,
but **at least two other verbs run `symbol_bbox()` from a stale gate**, and at
`recompute_inst_bbox` only the *overlay-cache* half of the gate was synced — the
*mask* half was deliberately left alone and still disagrees between the two doors.

⚠ **`instance_at` is what item B4's verb-noun pick uses, and
`findnet.c`'s `find_closest_element` uses `POINTINSIDE` against exactly this
box as its candidate gate.** These are picks that disagree, not merely numbers.

## Part 1 — `xschem setprop instance` writes the click box from the pre-edit gate

`scheduler.c`'s `setprop instance` arm runs `symbol_bbox()` after `set_modify(1)`
and **before** the redraw that would sync the cache, so the stored box is built
from the epoch as it stood before the edit. Measured first-hand:

```
C3 warm  bbox                     = 277.5 -340 320 -280      (decluttered, valued raw)
C3 after `xschem raw clear`  (epoch moved, gate now CLOSED, no draw yet)
C3 after `xschem setprop instance M1 name MZ1`
C3   stored bbox                  = 277.5 -340 322.629 -280
C3   instance_at 430 -245         =                          (EMPTY)
C3   render now shows             = MZ1 VCW=1u PD {zid =} {zgm =}
C3 after `xschem update_all_sym_bboxes`
C3   bbox                         = 277.5 -340 496.389 -232.78
C3   instance_at 430 -245         = MZ1
```

The frame on screen shows the text; the click box says there is nothing there.

⚠ **Item A5-a widened this.** Before A5-a a label-only block still opened the
gate, so a rename over a dead raw flipped nothing and the two boxes agreed. Now
that the gate demands a value, an ordinary property edit is enough to move it —
so this is newly reachable on the commonest edit there is.

## Part 2 — `xschem move_instance … nodraw noundo`

Same shape, one verb over:

```
D3 warm bbox                      = 280 -340 320 -280
D3 after move_instance … nodraw   : bbox 280 -340 320 -280       instance_at 430 -245 = (EMPTY)
D3 after update_all_sym_bboxes    : bbox 280 -340 496.532 -232.92 instance_at 430 -245 = M1
```

## Part 3 — the **mask** half of the gate still disagrees between the two doors

Item A5-c added `annot_overlay_sync()` to `recompute_inst_bbox` and deliberately
**not** `annot_show_sync_cache()` (that one ends in the 0688 mask backstop, which
can *clear* the mask, in a verb documented as not redrawing). The consequence,
measured with a bare `set ::annot_show` — no `xschem set`, no draw:

```
M0 at mask 1 bbox                 = 280 -340 496.532 -232.92
M1 bare `set ::annot_show 9`      ; xschem get annot_show = 1
M2 recompute_inst_bbox            : bbox 280 -340 496.532 -232.92  instance_at 430 -245 = M1
M3 update_all_sym_bboxes          : bbox 280 -340 320 -280         instance_at 430 -245 = (EMPTY)
```

Opposite answers from the two doors on the same pick. **Scope:** the shipped code
always writes the mask through `xschem set annot_show` (`utils/annot_mode.tcl`'s
S7 decision D4 forbids the bare set), so this is latent today — but item A5's
acceptance sentence *"the gate agrees at BOTH `symbol_bbox()` callers"* is true
only of the overlay-cache half, and row **A40**'s epoch mover (a descriptor
re-registration) cannot exercise this half at all.

## Why item A5 did not fix it (ladder L2, and the rejected alternatives)

Measured by the adversary pass, after the tiers, the six-variant sabotage matrix
and the full audit had run against the shipped change. Adding two more sync sites
and a mask sync at that point would ship untested edits to a hot path — and the
mask sync in particular has a *known* hazard (the 0688 backstop can clear the
mask) that needs its own rows in `test_annot_show_menu` and the 0688 suite.

**Rejected (still rejected, and this issue does not refute 1252's reasoning):**
syncing inside `symbol_bbox()` itself. 39 callers, six in `save.c`, and
`annot_overlay_busy` exists precisely because filling the cache evaluates
`::op_annot::text` and re-enters that machinery.

## ⚠ What item B4 must do until this is fixed

B4's pick must call `xschem update_all_sym_bboxes` **before its first pick** on
any sheet it has edited with `setprop instance` or `move_instance … nodraw`, and
should carry a row that reds if it does not. Item A5's row **A40** covers the
`recompute_inst_bbox` door only.

## Still open

* Which of the remaining `symbol_bbox()` callers can observe a stale gate — a
  full census was not taken; two were found by driving verbs, not by reading.
* Whether the mask half should be synced at `recompute_inst_bbox` despite the
  0688 backstop, or whether the backstop should be split out of
  `annot_show_sync_cache()` so a read-only verb can sync without it.
