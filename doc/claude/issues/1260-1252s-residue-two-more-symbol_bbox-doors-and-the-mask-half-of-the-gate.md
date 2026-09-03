# 1260 — 1252's residue: two more `symbol_bbox()` doors, and the mask half of the gate

Status: **FIXED by item A6-c**, 2026-09-02 — every `symbol_bbox()` door. A
**fifth** door that calls `symbol_bbox()` not at all is filed as **1266**
· Branch: `fluid-editing`

> ⚠ **NOT LANDED. The fix below was implemented, built and verified, then its
> write-up agent destroyed `src/save.c`'s half with `git checkout -- src/save.c`.
> The code is preserved in
> `doc/claude/op_param_batch/A6_working_tree_UNVERIFIED.patch` and in the working
> tree; PLAN.md's A6 entry says what to do first. Everything recorded below was
> measured and is correct.**

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

---

## FIXED — item A6-c, 2026-09-02

**Before** (Measure agent, each door driven on a **fresh** fixture still named
`M1`, the stale box read **first**, no draw / export / `update_all_sym_bboxes`
in between):

```
PROBE 1260 DOOR1 setprop: STORED bbox after rename = 277.5 -340 322.829 -280
PROBE 1260 DOOR1 setprop: RENDER now shows = MZ1 P6W=1u P6GATE {zid =} {zgm =}
PROBE DOOR2 move_instance: STORED bbox = 277.5 -340 320 -280
PROBE MASK bbox from recompute_inst_bbox = 150 -380 495.301 -232.872
```

with `instance_at 430 -245` answering **empty** over a frame that rendered the
device in full. The drawn thing and the clickable thing were different objects.

### The repair — ONE sync point, in the function every door passes through

`src/select.c`, `symbol_bbox()`'s prologue:

```c
annot_show_pull_cache();
if(xctx->annot_show & ANNOT_SHOW_NOPARAM) annot_overlay_sync();
```

**⚠ THIS DELIBERATELY REVERSES THE OPTION ISSUE 1252 REJECTED**, and both of
1252's reasons are **answered** rather than ignored. Ladder rung **L1**,
invariant **I1**: 39 callers cannot each carry a correct copy of a freshness
decision, and the ACCEPT row said *"every `symbol_bbox()` door agrees — drive
each door, do not reason about them"*, which is only reachable from one point.

* **Re-entrancy.** Filling the overlay cache tclevals `::op_annot::text`, which
  can return through `translate()` → `prepare_netlist_structs()` →
  `link_symbols_to_instances()` → `symbol_bbox()`. `annot_overlay_sync()` is the
  function that *frees* that cache and it early-returns on `annot_overlay_busy`
  (`src/actions.c`), which is set around exactly that evaluation. **The cycle was
  already closed in code**; 1252 argued from the hazard, not from the code that
  answers it. Verified separately that none of `get_annot_overlay()`'s three
  consumers (`draw.c`, `svgdraw.c`, `psprint.c`) reaches `symbol_bbox()` while
  holding the cache pointer — those three files contain **zero** calls to it.
* **Cost.** The bit-3 prefilter is a strictly **weaker necessary condition** than
  the rung it feeds, so it can only ever sync *more* often than needed, never
  less — it is not a second copy of `text_hidden_core()`'s AND-gate, and that
  function is byte-unchanged. With the declutter unarmed — every load, every
  netlist pass, every existing suite, all 378 audit cases — `symbol_bbox()` does
  two Tcl variable reads and **no sync**, so `annot_overlay_flushes` cannot move
  and `test_op_annot`'s O32/O33/O34/O35/O38 cannot move. Measured on a
  20-instance sheet: flush delta **0** for `update_all_sym_bboxes` at masks
  0/1/8/9 and **0** for 20 consecutive `recompute_inst_bbox` at masks 0 and 9;
  20 placements cost 30688 µs / 20 flushes at mask 0 and 30601 µs / 20 flushes
  at mask 9 — identical, so those flushes come from `draw()`, not from the new
  site. On a 49-instance sheet: `symbol_bbox` 9.97 µs against ~0.11 µs for a
  no-op sync, about 1%.

**Rejected**: per-door syncs at `scheduler.c:1016` / `:675` / `:692` / `:13128`
/ `:13184` plus `select.c:1528` — six sites, a widened Files cell, and **still
~33 callers stale**, which is how issue 1252 became this issue.

### The mask half — a SPLIT, not a second pull

`annot_show_pull_cache()` is `annot_show_sync_cache()`'s body **minus** its
trailing `annot_show_check_root()`; `annot_show_sync_cache()` is now that pull
plus the backstop. The 0688 backstop can `annot_show_set(0)`, and **a function
that computes a bounding box must not be able to disarm the annotation as a side
effect** — the hazard A5-c named when it left the mask half out. The backstop
keeps its eight bulk entry points and its tree-wide call-site census stays **3**,
so `test_op_annot` **Y11** is green and untouched. There is no self-undo:
`annot_show_set()` also writes the Tcl mirror, so a later pull reads the cleared
value rather than restoring it.

### The three "still open" questions this issue closed

* *Which callers can observe a stale gate* — the census was taken: `symbol_bbox()`
  has **39** call sites in 8 files, of which the writing doors are
  `scheduler.c:1016` / `:675` / `:692` / `:13184`, `select.c:1528`,
  `actions.c:3820`, `editprop.c:1088/1158/1266/1721`,
  `move.c:222/1078/8618/8706/9711`, `token.c:894`, `save.c:6181/8288`. **All of
  them are now fresh**, because the repair is inside the callee.
* **A THIRD Tcl-reachable door this issue never named**: `xschem reset_inst_prop`
  (`scheduler.c:675` and `:692`, two `symbol_bbox()` writes). Its arm **ends in
  `draw()`** — so a full redraw does **not** repair a box already written from a
  stale gate. Row **A51**.
* A **FOURTH**: `select_element()`'s deselect write at `select.c:1528`. Row **A52**.
* *Whether to sync the mask despite the backstop, or split it* — **split**, as
  above.

### Rows

**A49** `setprop instance` · **A50** `move_instance … nodraw noundo` · **A51**
`reset_inst_prop` · **A52** the deselect write · **A53** the headline (one
fixture, no redraw between: the exported frame renders `MZ1` **and**
`instance_at` inside that extent answers `MZ1`) · **A54** the mask half, **both
directions**, doors compared to each other and never to literal coordinates
(they differ in the 3rd decimal), plus the guard that `recompute_inst_bbox` does
not move `annot_show` · **A55** the census, with **row A41's fifth golden
re-golded in place, `select.c` 0 → 1**, the argument written beside it and the
regexp **not** widened · **A56** the shape (prologue, once, not once per text).

Sabotage: `SB-A6c-NOSYNC` → A41 A49 A50 A51 A52 A53 A56 red; `SB-A6c-NOPULL` →
A54 A55 A56 red **with A49..A53 green**, which is what proves the two halves are
separately load-bearing.

### Still open

* **1266** — a **fifth** door. `xschem annotate_op` and `xschem raw clear` change
  the gate's answer while calling `symbol_bbox()` **not at all**, so the stored
  box and the render disagree until something else triggers a bbox pass. Driven
  both directions. **Item B4 must still call `xschem update_all_sym_bboxes`
  before its first pick and carry a row that reds if it does not.**
* **1267** hole 3 — the hazard the pull/backstop split prevents has only
  structural coverage.
* `annot_show_pull_cache()` now runs on **every** `symbol_bbox()` call including
  `link_symbols_to_instances()` on the load path, so `xctx->annot_show` is
  overwritten from the single global Tcl `::annot_show` at every geometry pass.
  Measured harmless here (load cost unchanged at every mask, no flush storm), but
  it makes any existing multi-window/tab leak of that mirror strictly more
  frequent. **Not measured across tabs.**
