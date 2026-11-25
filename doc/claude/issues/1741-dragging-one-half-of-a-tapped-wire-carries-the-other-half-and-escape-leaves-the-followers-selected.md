# 1741 — Dragging one half of a tapped wire carries the other half; and Escape leaves the followers selected

**STAMP:** `v1 claim=fixed tree=554e8d72c stamped=2026-11-24 fix=taken open=3 by=driver-1741`

Reported by the user on 2026-11-24, after issue 1740 was confirmed ("that which I complained
about before has been resolved ok"), and repaired the same day. Reproduced with real pointer
events on a copy of the user's `/tmp/before.sch`, on a private Xvfb with openbox. Three things
are open, listed under "Open".

## What the user wrote

> if I click and release at 810,-200, only that vertical segment is selected. However, if I
> click and drag, then, abort with ESC, the screenshot shows what is selected after abort - 4
> segments.
>
> Like the previous complaint, how far I drag that vertical segment influences what happens
> finally. If I drag right upto only x=850, only that vertical segment is moved, with the wire
> connecting horizontally to its top vertex following. However, if I go past 850 to the right,
> then even the vertical segment below the solder dot is moved - as in /tmp/after_2.sch

What that settles: dragging the upper vertical segment moves that segment only, with the wire
at its top corner following, however far the drag goes; the segment below the solder dot stays.
And after Escape the wires that merely followed the drag are not selected.

## The shape

```
   (810,-230)-----------------(1040,-230)      top wire: follows the dragged segment's corner
       |
       |  the dragged segment (the upper half of the bar)
       |
 (780,-170)---o (810,-170)      the solder dot: a wire from the left ends here
       |
       |  the lower half, 40 long
       |
   (810,-130)----(880,-130)     to the capacitor pin
```

This is the T of issue 1740 with the roles turned: the user drags a half of the bar, not the
pillar. Issue 1740 left it out ("Dragging one half of the bar: what should happen is not
decided").

## What was measured

- **The drag.** With the pointer, in this tree at `554e8d72c`: a drag of 40 to the right gives
  what the user wants; a drag of 50 gives the wires of `after_2.sch` exactly (the lower half
  carried to x=860, and a 50-long piece of its jog left hanging at (810,-130)). The lower half
  is 40 long: it is the length rule of issue 1740 again, at an end that issue's pass gave no
  plan.
- **Escape.** Click, press, two motions, Escape: four wires are selected afterwards (the
  dragged one and the three at its ends), with or without the click first. A plain click
  hides the same thing: the release of the Cadence profile collapses the selection to the
  clicked object.
- **A sibling found while probing: a wire that runs straight through a device pin.** The two
  sides are two wires meeting on the pin. Dragging one side by more than the other side's
  length carried the other side, and then the overshoot pass of issue 0092 **deleted the
  dragged wire** (the trace line reads `overshoot: TRIM stub=0 [-100 -60 0 -60]`, the dragged
  wire's new place). Not the pass of 1740's doing: it gave that end no plan either.

## The repair

In `src/move.c`.

`fj_classify_end()` knows two more shapes at an end of a dragged wire W, where one wire A
continues W in a straight line past the end:

- **Half** (mode 3): one perpendicular wire P hangs on the joint. A stays. W's end keeps to
  P's line and moves along it by the part of the drag across W; P is made to hold both the
  joint and W's new end: it grows at the joint when W leaves on the side away from it, is left
  as it is when W's end lands on it, and grows at its far end when W goes past that. A device
  pin on the joint stays on the run, and the point wire kissing minted for it is given no
  length.
- **Through** (mode 4): no perpendicular wire, a fixed pin on the joint. A stays on the pin; the
  point wire kissing minted for the pin becomes the link from the pin to W's new end.

At such an end the part of the drag along W is not applied (W stretches or shrinks instead),
as at the other anchored ends of 1740. Both shapes are kept at every level of the plan.
`fj_verify()`'s axis check lets a point wire grow along either axis.

Two rules came with the review (below):

- **The dragged wire is not shrunk to nothing, and at a Half or Through end not turned
  round.** A bare end opposite a held one gives way and stops one grid short of the held end.
  If something is attached at the end that would have to give way, the plan fails. (The
  pillar of 1740 pushed through its bar with a corner at its far end may still come out with
  no length: the corner then sits on the bar. With a bare far end it now keeps one grid.)
- **A last level: hold.** When no plan that moves a dragged half can be verified (its link,
  or the grown perpendicular wire, would run over a pin or onto another net), the wire is
  held where it is, with the grabbed end of every wire at its two ends. The old placement is
  not used for this shape: it carries the other half, shorts a device the link crosses, and
  its overshoot pass deletes the dragged wire. Not held when a moving pin or another dragged
  wire is at one of its ends. When the held wires are all the user dragged, the release is
  treated as a refused move: no undo step, the modified flag as it was, and the CIW says
  "wire not moved: it cannot be laid there without running over a pin or another net".

`move_objects(ABORT)` takes every wire that is not the user's out of the selection and
redraws when that changed anything; the user's own wires keep the state they had. Escape in
mid-drag and a click both go through it. A move that is refused at the release now does the
same after it has put the wires back.

On the user's `before.sch`, with the pointer: the drag of 50 moves the dragged segment and its
top corner only, and the wire from the left reaches it; drags of 120 and of -50 the same; after
Escape only the dragged segment is selected, with and without a click first.

## Rows

`tests/headless/test_wire_drag_junction_1740.tcl`: band H (H1 to H17) and rows G7 to G9. The
row E1 of issue 1740, which held the old placement of a dragged bar half, is gone.

Rows seen red: with the two shapes switched off (breaks a and b below) H1 to H5, H8 to H10 and
H13 to H17 are red, and G9 on a display; with the selection clean-up off (break h) H6, H7,
G7 and G8. H11 and H12 are red under breaks n and j.

## Breaks

Each is one edit of `src/move.c`, built and run against the suite on both arms in a third
clone (2026-11-24, final code). "+G" means the display arm adds those rows.

| | what was broken | rows that turn red |
|---|---|---|
| a | a dragged half of a run gets no plan | H1 H2 H3 H8 H9 H15 H16 H17, +G9 |
| b | a wire through a pin gets no plan | H4 H5 H10 H13 H14 |
| c | the other half is not held where it is | H1 H2 H3 H4 H5 H8 H9 H10, +G9 |
| d | the perpendicular wire never grows at the joint | H1 H2 H3 H9, +G9 |
| e | the perpendicular wire never grows at its far end | H2 H3 H16 H17 |
| f | the part of the drag along the wire is applied at a half end | H2 H3 H4 H5 H8 H9 H10 |
| g | a point wire must keep both axes | H4 H5 H10 H13 |
| h | an aborted drag does not clean the selection | H6 H7, +G7 G8 |
| i | an aborted drag deselects the user's own wire too | H6 H12, +G7 G8 |
| j | an aborted drag makes a wire the user held by one end whole-selected | H12 |
| k | through a pin: the point wire is not made the link | H4 H5 H10 H13 H14 |
| l | a pin on the joint of a dragged half: its point wire is not collapsed | H8 |
| m | no redraw after the abort clean-up | none |
| n | the dragged wire may be shrunk to nothing or turned round | H9 H10 H11 |
| o | no last level: a dragged half that cannot be laid is not held | H13 H14 H15 H16 H17 |
| q | a held drag is not refused: it leaves an undo step | H16 |
| r | a held wire: the wires at its ends are not held with it | H13 H14 H15 |
| s | a wire is held although another dragged wire is at its end | none |
| t | a wire is held although a moving pin is at its end | none |
| u | a refused move does not clean the selection | H17 |

Three breaks turn no row red. **m:** the redraw only changes pixels. **s** and **t:** no
fixture drags a second wire, or a device, together with a half that cannot be laid.

## What the review found

The first build of this issue was read by one reviewer and run by another (1800 scripted
drags of random bar halves and wires through pins, a fifth of them aborted), and a second
agent had to reproduce each finding (workflow `wf_94867d7c-2d2`).

| finding | new with the first build? | repair | row |
|---|---|---|---|
| A drag along the wire toward the joint, as long as the wire or longer, deleted the dragged wire (it was written with no length, or onto the other half) | yes | the one-grid rule | H9 H10 H11 |
| An aborted drag made a wire the user held by one end whole-selected | yes | the clean-up no longer changes the user's wires | H12 |
| A wire through a pin dragged across the device: the plan was declined and the old placement ran (other side carried, device shorted, or every wire deleted) | no (old result surviving) | the hold level | H13 |
| The piece between two pins dragged where its link crosses a device: three diagonal wires | no | the hold level | H14 |
| A half taken past a pillar that ends on a device in line with it: the other half carried | no | the hold level | H15 |
| After a refused move the wires at the dragged wire's ends stayed selected | no | the refuse block cleans the selection | H17 |

One finding was not a defect: a refused drag leaves no undo step, so the next undo takes back
the edit before it. That is what a refusal is; the hold level now does the same (H16).

## The builder's choices (not ruled by the user)

1. **After Escape the dragged wire stays selected,** also when nothing was selected before the
   press. That is what Escape already did for a dragged instance (row 7a of
   `test_drag_keeps_selection.tcl`), and what a click leaves. The other reading: Escape puts
   back the selection from before the press.
2. **A drag along the dragged half does nothing at its joint end.** The joint end stays on
   the perpendicular wire's line; only the other end takes that part of the drag.
3. **The perpendicular wire grows at its far end** when the dragged half is taken past it, so
   whatever rests on that far end ends up on the middle of the wire.
4. **A wire through a pin: the link leaves the pin straight across the wire.** When that
   would cross the device, the drag is held (choice 6).
5. **A dragged wire is never shorter than one grid.** Pushed along itself onto a joint or a
   pin it keeps one grid there. The other reading: its far end does not take the drag along
   the wire at all, and the wire keeps its length.
6. **A drag that cannot be laid holds the wire where it is,** on every live step and at the
   release, with a line in the CIW. The other reading: the old placement, with what it does.

## Found on the way, not repaired

- **A held drag of a wire that sits on a pin leaves one undo step that changes nothing,** and
  marks the sheet modified. Kissing pushes its undo step when the drag starts, and the END
  path does not own that step. (A held drag with no pin involved leaves none: H16.)
- **After Escape in a drag that had minted a point wire for a pin, nothing is selected,** not
  even the dragged wire: the undo that removes the point wire clears the selection. As before.
- **A crash the reviewer met, not from this change:** with `xschem undo_type memory` switched
  on at run time, `move_objects start ... kissing` then `abort` at a wire end on a device pin
  ends with signal 11, also with fluid editing off.
- **A label at the dragged wire's free end** stays where it is when `label_ride` is off; the
  drag is then refused as a whole. The Cadence profile has `label_ride` on.

## Open

1. The user's look on their own screen.
2. A ruling on the six choices above.
3. The crash with the memory undo type (above) has no issue of its own yet.

## Not checked

- The user's own screen.
- A drag with a rotation or a flip in it (the pass does not run there).
- `autotrim_wires` off.
