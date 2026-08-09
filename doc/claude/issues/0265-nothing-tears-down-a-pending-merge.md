# 0265 — nothing tears down a pending paste/merge: a second `Ctrl+V` (or any placement arm) silently COMMITS the first one

Status: **OPEN** — found by the code census run for issue **0244** part B, then **measured** on both
doors (below). **Major**: the residue is a committed, netlist-visible set of objects the user never
dropped — the issue-**0242** orphan class, in the dimension `leave_placement_for()` does not cover.
Area: `src/paste.c` (`merge_file()`'s own `unselect_all(1)`), `src/select.c` (`unselect_all()`'s
wholesale `ui_state = 0`), vs `leave_placement_for()` / `abort_placement_preview()` in
`src/callback.c`
Tests: none. `tests/headless/test_paste_modify_flag_0244.tcl` covers the ESC and commit doors of a
*single* pending merge; the second-arm door is untested.
Found: 2026-08-08, closing issue **0244**.
Related: **0242** (the same class for placements — nine doors gated by `leave_placement_for()`),
**0244** (part B's stamp lives on the gesture this issue can drop), **0241**, **0123**,
`WIRING.md` §8 class **D**.

## The claim

`STARTMERGE` has exactly one setter (`merge_file()`, `src/paste.c`) and three teardown-bearing
clears: the commit tail (`move.c`), and `abort_operation()`'s two arms (`src/callback.c`). Every
**other** way the bit goes away is `unselect_all()`'s wholesale `xctx->ui_state = 0`, which fires
whenever anything is selected — and a pending merge is *always* selected, because that selection is
what the drag is carrying.

So:

- **`Ctrl+V` twice.** `merge_file()` itself calls `unselect_all(1)` before loading. If a merge is
  already pending in that window, that call drops `STARTMERGE` with **no** `delete()`, leaving the
  first paste's objects committed and deselected, and then arms `STARTMERGE` again for the second.
  `leave_placement_for()` — which `merge_file()` does call — only covers
  `START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT`; it never inspects `STARTMERGE`.
- **`Ctrl+V` then any placement arm that unselects** (the three form `-place` arms, `add_graph`,
  `add_image`, the `place_text` verb, both `place_symbol` routes): same wholesale drop, same
  committed residue.

The ratified rule since 0243 F2 / 0240 is *"whatever you just pressed is what you meant"* — the new
gesture cancels the pending one. For merges the second half of that ("cancels") is missing: the
pending paste is not cancelled, it is silently **accepted**.

## Measured, 2026-08-08, on the post-0244 binary

Both doors reproduce. `doc` = one wire, dirty; `src.sch` = one wire.

```
A  merge twice, then ESC
   before        wires=1 ui=0
   merge #1      wires=2 ui=296  (STARTMERGE|STARTMOVE|SELECTION)
   merge #2      wires=3 ui=296  <-- paste #1 still in the drawing, no longer pending
   after ESC     wires=2         <-- only paste #2 removed; paste #1 is COMMITTED

B  merge, then a placement arm, then ESC
   merge armed   wires=2 inst=0 ui=296
   place_symbol  wires=2 inst=1 ui=8232  <-- STARTMERGE gone, merged wire committed
   after ESC     wires=2 inst=0          <-- only the placement torn down; the paste stays
```

Both runs also print, from the fluid layer:

```
fluid_editing: fluid_gesture_arm() re-armed while a prior gesture was still armed -- it leaked its
snapshot (WIRING risk #11.10 mid-STARTMOVE abandon); recovering
```

i.e. the fluid machinery already *detects* this abandon and merely recovers from it. That message is
the cheapest available tripwire for a fix to silence.

## Why it is not 0244 part B's problem

Part B stamps the merged objects at the arm and narrows the cancel's `delete()` to that stamp. When
this issue's path fires, `STARTMERGE` is gone, so no arm reads the stamp and the next arm overwrites
it — the stamp is inert, not stale. Part B neither worsens nor fixes this.

## Sketch

A `leave_merge_for(const char *what)` sibling of `leave_placement_for()` — or extend the existing
one to `STARTMERGE` — called from the same funnel (`merge_file()`, before its `unselect_all`) and
from the placement arms. Its teardown is the merge arms' body: `select_placement_preview()` +
`delete(1)` + the `pre_merge_modified` restore + `clear_placement_preview()`, which is now a
three-line block worth factoring out of `abort_operation()` before a third caller copies it (the
duplication between the two arms is exactly how 0244 was born — see its root-cause section).

**Measure first**: build the two-paste sequence headlessly (`xschem merge f` twice, then count
objects and read `ui_state`) and confirm the residue before writing any gate.
