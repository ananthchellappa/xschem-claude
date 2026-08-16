# 0271 — a merge/paste does NOT cancel a live wire or line draw: the direction plan phase 4 recorded as already working

Status: **FIXED 2026-08-09** on `open_pdk` — `merge_file()` (`src/paste.c`) now calls
`leave_wire_draw_for()` (and `leave_shape_draw_for()`) beside the placement and merge gates it
already had. Found by the issue **0269** census, then measured.
Area: `src/paste.c` (`merge_file()`), and three stale comments that asserted the opposite
(`src/callback.c` twice, `doc/claude/suggestions/plan_modal_gesture_exclusion.md`)
Tests: section **H1** of `tests/headless/test_shape_draw_gate.tcl` (8 checks: `wire gui`,
`line gui`, the RESTING command mode, and the clipboard `paste` door). Was: none — every suite that
could have caught it asserted the *other* direction.
Related: **0240** (the jam this recreates), **0243 F2**, **0265** (whose phase-4 write-up carried
the false claim forward), `WIRING.md` §8 class **D**.

## The claim

`plan_modal_gesture_exclusion.md` phase 4 states:

> The direction *merge cancels a live draw* already works (`merge_file()` calls
> `leave_placement_for()`, which is the wire/line teardown too).

**That is false.** `leave_placement_for()` (`callback.c`) calls `abort_placement_preview()`, which
tests and clears only `START_SYMPIN | PLACE_SYMBOL | PLACE_TEXT`. It has never looked at
`STARTWIRE` or `STARTLINE`, and it does not touch `last_command`. The wire/line teardown is
`abort_wire_line_command()`, reached through `leave_wire_draw_for()` — which `merge_file()` did not
call.

The same sentence had propagated into two source comments (`callback.c`, above `leave_merge_for()`
and at context-menu pick 2), so the claim was in three places and true in none.

## Measured, 2026-08-09, `--nogui`, on the post-0265 binary

```
                                  before                       after
xschem wire gui                   ui=1    last=1               ui=1    last=1
  + xschem merge <file>           ui=297  last=1     <--       ui=296  last=0
                                  STARTWIRE|STARTMOVE|
                                  SELECTION|STARTMERGE
RESTING mode (wire gui + ESC)     ui=0    last=1               ui=0    last=1
  + xschem merge <file>           ui=296  last=1     <--       ui=296  last=0
```

`ui_state 297` is two modal gestures at once. It is the issue-0240 dead end exactly: while
`STARTWIRE` is set, `end_place_move_copy_zoom()` feeds every click to the wire before the
`STARTMOVE` arm that would drop the paste — so the pasted objects ride the cursor with no way down
— and under `persistent_command` the press handler seizes the click one step earlier still. The
RESTING row is the worse half: `ui_state` shows nothing at all, only `last_command` is armed, and
that is the state the 0240 report was actually filed against.

## Why no suite caught it

Every gate suite tested the direction the bug reports named. `test_paste_modify_flag_0244.tcl`
section **E5** covers *a draw cancels a live merge* (phase 4's own work) and
`test_placement_wire_gate.tcl` covers *a placement cancels a draw*; nothing asserted *a merge
cancels a draw*, because the plan said it already held. A claim that is documented as true and
never asserted is a claim nobody re-checks — the class 0265's phase-4 note warned about in a
different dimension ("bounding a gesture against every ARM does not bound it against the COMMIT
forms") and then fell into here.

## The fix

`merge_file()` gates all four, in the order every other multi-gate arm uses — the two
band-erasing teardowns first (they tile from `save_pixmap`, and both of the others can reach a full
`draw()`), then placement before merge for the shared `preview_sel` slot:

```c
leave_shape_draw_for(selection_load == 2 ? "Paste" : "Merge");   /* issue 0269 */
leave_wire_draw_for(selection_load == 2 ? "Paste" : "Merge");    /* issue 0271 */
leave_placement_for(selection_load == 2 ? "Paste" : "Merge");
leave_merge_for(selection_load == 2 ? "Paste" : "Merge");
```

Sited at the same place as the other two and for the same three reasons: inside `if(fd)` so a
cancelled Merge dialog destroys nothing, at the ONE funnel every merge door shares (the `paste` and
`merge` verbs, Ctrl+V, context-menu pick 8, and the `xschem paste x y … -file {f}` replay form), and
before `push_undo()`. The wire/line teardown is delete-free, so it strands no undo baseline and
adds nothing to the ordering argument.

The three stale comments are corrected in place.
