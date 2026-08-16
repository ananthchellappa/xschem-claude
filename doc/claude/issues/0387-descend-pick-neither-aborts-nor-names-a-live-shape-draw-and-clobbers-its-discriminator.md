# 0387 — arming a descend pick over a live shape draw silently destroys the shape's discriminator

Status: **OPEN** (measured, not fixed)
Found: 2026-08-10, crew item D6 adversary pass (`ATK-2`/`ATK-2b`), after the 0257 fix landed.
Area: `xschem descend_pick` (`src/scheduler.c`) — it gates `abort_wire_line_command()` and the new
`abort_click_mode()` but not `abort_shape_draw()`, and then assigns `xctx->ui_state2 =
MENUSTARTDESCEND` **wholesale**; `abort_shape_draw()` and the `MENUSTARTSHAPE` family in
`src/callback.c`.
Tests: none. `tests/headless/test_shape_draw_gate.tcl` (421) covers shape-vs-shape and
shape-vs-wire; no test arms a descend pick with a shape draw live.
Related: **0257** (decision D3 dismissed this door as "unmeasured" — it is now measured),
**0269-0272** (the shape-draw teardown family), **0241** (a teardown must name what it tears down),
**0268** (`ui_state2` discriminator residue).

## The defect

A live shape draw is a Button-1 owner. Measured under xvfb:

```
xschem rect ; one click        -> ui_state = 2 (STARTRECT), ui_state2 = 4 (MENUSTARTRECT)
hi_descend                     -> statusmsg = "Descend: click the instance to descend into (ESC to cancel)"
                                  i.e. the PLAIN prompt: it reports that nothing was torn down
                                  ui_state  = 65538   <-- STARTRECT still live under MENUSTART
                                  ui_state2 = 32768   <-- MENUSTARTRECT silently destroyed
```

Two separate faults in one statement:

1. **The in-progress rectangle disappears with no word** — the opposite of the 0241 rule the same
   commit implements for the wire and click-mode doors.
2. **The discriminator is clobbered.** `ui_state2 = MENUSTARTDESCEND` is an assignment, not an OR,
   so `MENUSTARTRECT` is gone while `STARTRECT` remains set in `ui_state` — exactly the residue
   class `abort_shape_draw()`'s own comment warns about, and the state a cancelled pick leaves
   behind (the subsequent real descend zeroes `ui_state`, which is the only reason the measured
   consequence is bounded).

Bounded today: `rects(4)` stays 0 in both parent and child, `modified` stays 0, nothing rides into
the child. The exposure is a cancelled pick, which leaves `STARTRECT` live with no discriminator.

## Why it was not fixed in D6

Decision D3 gave `descend_pick` exactly the two gates whose swallow had been *measured*, and
recorded the rest of the battery (`leave_placement_for` / `leave_shape_draw_for` /
`leave_merge_for`) as the next doors if ever measured. This one now is. The fix is one more line in
the same composed sentence: `shape_gone = abort_shape_draw();` before the `ui_state2` assignment,
with the name folded into the held message, plus MS-style rows in
`tests/headless/test_cmdmode_descend_0201.tcl` asserting `ui_state & STARTRECT == 0` and a message
that names the abandoned shape.

Note the ordering landmine that already bit the 0257 work: every one of these teardowns writes
`ui_state2`, so all of them must run **before** `ui_state2 = MENUSTARTDESCEND`.
