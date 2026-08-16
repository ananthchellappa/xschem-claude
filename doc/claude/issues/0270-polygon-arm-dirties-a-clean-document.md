# 0270 — arming a polygon marks a clean document modified, with nothing stored

Status: **FIXED 2026-08-09** on `open_pdk` — the `set_modify(1)` moved from `new_polygon()`'s PLACE
arm to its commit branch, beside `store_poly()` (`src/actions.c`). Found by the issue **0269**
census.
Area: `src/actions.c` (`new_polygon()`)
Tests: section **F3** of `tests/headless/test_shape_draw_gate.tcl` (7 checks: the polygon row, the
ESC-still-dirties row, and four controls). Was: none.
Related: **0269** (the teardown that turned this from harmless into a lie), **0244** (the same
class: an aborted gesture must not leave the modify flag saying something false), **0267**.

## Measured, before

```
xschem clear force                       modified=0  polygons=0
xschem polygon gui                       modified=1  polygons=0   <-- nothing stored
```

`rect`, `arc`, `circle` and `zoom_box` do not do this — measured, and confirmed by reading:
`new_rect()` sets modify only when its PLACE commits a *previous* rectangle, `new_arc()` only at
the third click after `store_arc()`, and `zoom_rectangle()` contains no `set_modify` on any path.

## The claim

`new_polygon()`'s PLACE arm ended with an unconditional `set_modify(1)`, before any point beyond
the first existed and before anything was stored. It was also the polygon's **only** modify write —
the commit branch (`push_undo` + `store_poly` + `log_action` + the buffer frees) had none.

That combination is why the bug was invisible for so long and why the obvious fix is wrong. It was
*harmless* while ESC was the only exit from a polygon draw, because ESC **commits** the polygon
(`abort_operation()` calls `new_polygon(END, …)`), so the flag became true one call later. And
simply **deleting** the line would have stopped a finished polygon marking the file dirty at all.

It stopped being harmless the moment issue 0269 gave the gesture a second exit: with
`leave_shape_draw_for()` in place, a competing gesture abandons the polygon, and a teardown that
leaves `modified == 1` on a document where nothing was stored is the issue-0244 class — a buffer
that reports itself dirty and prompts to save changes the user never made.

## The fix

Move it, do not delete it: `set_modify(1)` now sits immediately after `store_poly()` in the commit
branch. Every path that finishes a polygon still dirties the file (SET, END, and close-by-clicking-
the-first-vertex all funnel through that block); no path that abandons one does.

Consequence for the teardown, and the reason this issue exists rather than a latch: with the modify
write moved, `abort_shape_draw()` needs **no** modify machinery at all — no
`pre_merge_modified`-style latch, no `modify_seq` comparison (issue 0267), nothing to restore. The
alternative — keeping the phantom write and having the teardown undo it — would have needed a
fourth latch field for a flag that should never have been set.

## Measured, after

```
xschem clear force                       modified=0  polygons=0
xschem polygon gui                       modified=0  polygons=0
  + xschem wire gui   (abandon)          modified=0  polygons=0
xschem polygon gui + ESC   (commit)      modified=1  polygons=1
```
