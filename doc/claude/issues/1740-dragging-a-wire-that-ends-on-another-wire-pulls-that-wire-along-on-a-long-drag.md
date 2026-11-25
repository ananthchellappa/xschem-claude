# 1740 — Dragging a wire that ends on another wire pulls that wire along on a long drag

**STAMP:** `v1 claim=fixed tree=88309cdcf stamped=2026-11-24 fix=taken open=4 by=driver-1740`

Reported by the user on 2026-11-24 and repaired the same day. Reproduced and tested on a
private Xvfb with openbox, with real pointer events, on a scratch copy of the user's
schematic. Four things are open, listed under "Open" below.

## What the user wrote

> When we have a T of wires, there is a solder dot where the pillar meets the bar. Note,
> the T may be in any orientation. If I have a schematic with just the T, I find that
> clicking and dragging the pillar gives the expected and desired result - the solder dot
> should move to accommodate the new position of the pillar. The bar should stay unchanged.
> However, that is not what I find when I try what I did in /tmp/Xschem.log.4 with
> hdo_sky130/fast_buf3/schematic. I click at 820,-190 and drag left to 750,-170 and the bar
> moves. I started with schematic window at same size that it launches, did not change zoom
> (which seems to influence things - if I zoom in and do it, result is closer to
> "desirable"). The "after" result is in /tmp/after.sch.

What that settles: the bar under a T stays where it is and the dot slides along it, in
any orientation. Everything else below is the builder's reading and is marked as such.

## What was measured

The shape in the user's schematic (net `a1`, named by a label):

```
              (880,-230)-----------(1040,-230)
  (550,-240)----(780,-240)   |
                    |        |  bar, x=880, two wires meeting at the dot
                    |        |
               (780,-190)----o (880,-190)      pillar: the wire the user dragged
                             |
                         (880,-130)  top pin of capacitor Cc
```

The drag `(-70,+20)` of the pillar, with a click and then a press, eight motions and a
release sent to the schematic window, gives the wires of the user's `after.sch` exactly:
the two bar halves moved to x=810 with a jog at each far end, and at the left a 70-long
piece of the pillar hanging in the air past the corner wire. Sent to this tree and to the
private one the result is the same; the wire code of the two trees is the same file for
file (`move.c`, `select.c`, `callback.c`, `actions.c`, `check.c`, `store.c`).

Zoom is not the cause. The same drag in schematic units gives the same wires at the zoom
the window launches with and zoomed in. What decides is the drag distance against the
length of each attached wire: on the bare T (bar halves 40 and 60 long) a drag along the
pillar of 40 or less left the bar alone, 50 moved the 40-long half, 70 moved both. Zoomed
in, the same pointer travel is a shorter drag in schematic units, which is why it looked
better there.

## Cause

`select_attached_nets()` grabs, at each end of a wire that is dragged whole, the
coincident endpoint of every other wire there. `place_moved_wire()` then lays each of
those wires as an L from its other end to the dragged wire's new end, and
`recompute_orthogonal_manhattanline()` picks which L: the longer of the two components
first. For an attached wire that is perpendicular to the dragged one this compares the
drag with the attached wire's own length, so one junction gets two answers:

- **A T** (the dragged wire is the pillar). Drag shorter than a bar half: that half keeps
  its line and the dot slides, which is what issue 0014 asked for. Longer: the half is
  carried sideways and a jog is left at its far end.
- **A corner** (one perpendicular wire at the dragged wire's end). Drag along the pillar
  longer than the corner wire: the corner wire follows. Shorter: it stays, and the pillar
  runs past it as a tail in the air. Issue 0092 repairs that tail in a pass at the end of
  the drag, on auto-named copper only; the user's net is named, so the tail stayed.

## The repair

`fluid_place_wire_junctions()` in `src/move.c`, called before the commit loop of
`move_objects()` on every live step and at the release. For each wire the user had
selected when the drag started it looks at the two ends and decides by the shape there:

- **Anchor.** Two perpendicular wires that form a straight run through the end (the bar):
  they keep their line. Their shared endpoint and the dragged wire's end move by the
  component of the drag along the bar only, so the dot slides and the dragged wire
  stretches or shrinks. A device pin on the junction and a wire that continues the
  dragged one on the far side of the bar (a crossing) stay where they are; the crossing
  becomes two T junctions.
- **Carry.** One perpendicular wire and nothing else at the end (a corner): the corner
  wire goes where the dragged wire's end goes, and the one or two wires it meets at its
  far end have that endpoint moved with it (the corner there slides, or its tap slides
  along a rail).
- A corner wire that cannot be carried (its far end is on a pin, a pin or another wire's
  end rests on it, its far end has a wire in line with it) is anchored instead.
- Any other end gets no plan and is placed as before.

The endpoints are written directly, so the result does not depend on the drag distance
and needs no clean-up pass, which is what makes it work on a named net. Before anything
is written the whole plan is checked (`fj_verify`):

1. every wire stays on its axis, and no endpoint is given two targets;
2. nothing stationary that rested on a reshaped wire is left off the copper: an instance
   pin, the unmoved end of a wire outside the plan, and the unmoved end of a wire inside it;
3. no reshaped wire lands on a stationary pin it did not touch;
4. no reshaped wire makes a new contact with stationary copper of another net. Contact is
   an end of one wire on the span of the other; a plain crossing is not one.

A contact the dragged wire would make by moving rigidly, as the user dragged it, is not
"new" in 3 and 4. A plan that fails is tried again without Carry, then with the straight
runs only (the corners left to the old placement), then dropped.

Three places outside the pass were changed with it:

- **The commit loop** of `move_objects()` skips the wires the pass wrote.
- **The safety ladder.** The pass runs on the first attempt only. When its result changes
  which pins are connected, the result is kept aside; if the old placement of the second
  attempt changes them in exactly the same way (the user dropped the wire's free end on a
  pin: every route shows that), the result that is kept in the end is the junction one,
  not the old one.
- **The overshoot pass of issue 0092** (`fluid_collapse_axis_overshoot_stub`) does not run
  on an attempt in which the junction pass wrote. Its target is the tail the old placement
  leaves; on a junction result it took what was left of the pillar for such a tail and
  moved the bar to its tip.

Scope: fluid editing on, orthogonal wiring on, no rotation or flip in the drag, and only
wires the user selected (a wire that follows a dragged device is not touched). The piece of
a bar between two dragged pillars is whole-selected by the grab without being the user's;
it is taken as a half of a run when both its ends get a target.

On the user's schematic the reported drag now gives: bar unchanged from -230 to -130 with
the dot at -170, pillar from x=710 to the bar, corner wire at x=710, its arm ending at
x=710. Fourteen other drags of the same wire were read by eye with the first build, and
five again with the final one, among them the two drags of the user's first log
(`-90,0` and `-80,0`) and one of 300 that crosses other nets: none moves the bar.

## Rows

`tests/headless/test_wire_drag_junction_1740.tcl`, in both lists of
`tests/run_regression.tcl`. Bands A to F use the scripted release; band G sends pointer
events and runs on a display only.

Rows seen red. The first version of the file was run against the tree before the repair
(`88309cdcf`): A1, A1b, A2, A3, B1, C1, C2, C3, C3b, C4, C6, C7 and D1b were red without a
display, and those plus G1 to G5 on one. The rows added after that were seen red with the
pass switched off (break 1 below), which leaves the rest of the change inert.

Two suites of `tests/headless/wireedit` (not in the regression; `run_wireedit.sh` runs
them) held the old answer for a push toward a corner and were changed, see choice 1:
case R of `test_wireedit_49_axis_overshoot_0092.tcl` and the second gesture of
`test_wireedit_50_regrab_partial_disconnect_0093.tcl`. The other 56 suites of that folder
give the same result as at the base commit.

## Breaks

Each break is one edit of `src/move.c`, built and run against the suite on both arms in a
third clone (2026-11-24, final code). "+G" means the display arm adds those rows.

| # | what was broken | rows that turn red |
|---|---|---|
| 1 | the pass is never called | A1 A1b A2 A3 B1 C1 C2 C3 C3b C4 C6 C7 C9 D1b D2 F1 F1b F2 F3 F4 F5, +G1 to G5 |
| 2 | a corner is never carried | A1 A2 A3 C2 C3 C3b C8 F1 F1b F4, +G1 to G4 |
| 3 | a pin resting on the corner wire is not looked at | C8 |
| 4 | the left-off-the-copper check always passes | C9 F6 |
| 3+4 | both | C1 C4 C8 C9 F6 |
| 5 | the new-contact check always passes | D1 |
| 6 | the commit loop places the written wires again | A1 A1b A2 A3 A5 B1 B2 C1 to C9 D1b D2 F1 F1b F2 F3 F4 F5, +G1 to G5 |
| 7 | any whole-selected wire is in scope, not only the user's | F3 |
| 8 | the pass runs on every attempt of the ladder | none |
| 9 | a fixed pin on the junction means no plan | C6 |
| 10 | the kissing stub at the junction is not given its place | C6 |
| 11 | the wire that continues the dragged one is not kept | C7 |
| 12 | an anchored end moves by the whole drag | A1 A1b A2 A3 B1 C1 C2 C3 C3b C4 C6 C7 C9 D1b D2 F1 F1b F2 F3 F4 F5, +G1 to G5 |
| 13 | the wires at a carried corner wire's far end are not moved | A1 A2 A3 C3 C3b F1b F4, +G1 to G4 |
| 14 | the pass runs with fluid editing off | none |
| 15 | a failed plan is not tried again at a lower level | C9 D1b D2 F5 |
| 16 | two wires on the same side of the end count as a run | none |
| 17 | the far end of a corner wire may hold a wire in line with it | none |
| 18 | the pin-landing check always passes | D2 |
| 19 | the overshoot pass of 0092 runs on what the junction pass placed | F1 F1b F5 |
| 20 | the ladder never keeps the junction result | F2 |
| 21 | a wire grabbed at both its ends is not taken as a half of a run | F3 |
| 22 | a plain crossing counts as a contact | F4 |
| 23 | no third level: a corner that fails takes the run with it | F5 |
| 24 | the ends of wires inside the plan are not checked for copper | F6 |
| 25 | a wire grabbed at both ends may be given one target only | none |

Five breaks turn no row red:

- **8.** No row makes the pass's own result change the pin partition in a way its checks
  let through, so the ladder's second attempt is never asked to be different.
- **14.** With fluid editing off `select_attached_nets()` records no user wire, so the
  scope test already answers no; row E2 holds through either.
- **16.** With `autotrim_wires` on, two wires cannot lie over each other at an end.
- **17.** A wire in line with the corner wire at its far end would be moved off its axis;
  check 1 refuses that plan and the retry anchors the corner, which is the same result.
- **25.** No fixture gives such a wire one target only.

## What the review found

The first build was read by two reviewers and run by a third (2929 scripted drags of
random T shapes), and a second agent had to reproduce each finding
(workflow `wf_0298fc55-832`). Five findings stood, one of them with two triggers, which
makes the six lines below; all are repaired and have a row:

| finding | new with the first build? | repair | row |
|---|---|---|---|
| The pillar laid onto its corner's arm, or shrunk to nothing on the bar: the 0092 pass moved the bar (or the arm) to the tip of what was left | yes | the 0092 pass is skipped where the junction pass wrote | F1 F1b |
| The pillar's free end dropped on a device pin: the ladder rolled the plan back and the bar was carried | no (the old result surviving) | the ladder keeps the junction result when the old route changes the pins the same way | F2 |
| Two pillars on one bar dragged together: the piece between them moved with the drag | no | that piece is taken as a half of a run | F3 |
| A wire of another net merely crossed by the stretched pillar dropped the whole plan | no | contact is an exact touch, not an overlap of boxes | F4 |
| Trouble at the corner end cost the bar its place | no | the third level (runs only) | F5 |
| With `autotrim_wires` off, a wire end resting on a wire inside the plan was cut off | yes | check 2 looks at the unmoved ends of planned wires too | F6 |

The same review ran `fluid_editing=0`, live steps against one release, abort,
out-and-back, two gestures in a row, undo and a rotated drag, and reported nothing there.

## The builder's choices (not ruled by the user)

1. **A corner follows the dragged wire's end in both directions.** Before, a corner wire
   stood still when the wire was pushed toward it and was moved only when the wire was
   pulled past it (issue 0092, case L, which the user asked for). Rows of two suites held
   the standing-still half (0092 case R, 0093 second gesture); they now hold that the
   corner follows. The other reading: a push toward a corner does nothing along the wire.
2. **A corner wire whose far end is on a pin does not move sideways,** so a wire between
   two such corner wires can only be moved across them; the part of the drag along the
   wire is not applied. The other reading: carry it and leave a jog at the pin.
3. **Pushed through the bar, the pillar shrinks to nothing and then grows on the other
   side.** Nothing sticks out past the bar on the way.
4. **Past the end of the bar, the bar grows to the dot** (as before this change).
5. **A crossing becomes two T junctions** when one of its four wires is dragged along the
   wire it crosses.
6. **A corner that can be neither carried nor anchored is placed the old way,** and only
   the bar end of the wire is anchored (the third level).

## Found on the way, not repaired

- **Dragging one half of the bar** (the pillar hangs on the junction) still uses the
  length rule: the other half is carried when the drag is longer than it. No plan was
  built for that shape; row E1 holds today's result so a change shows.
- **The action log line of a connected drag does not replay it.** The drag is logged as
  `xschem move_objects dx dy kissing`; replayed, that moves the wire without its
  followers (`stretch` is not in the line). The user's log could not reproduce the
  report for that reason; pointer events did.
- **Five suites that are not in the regression are red at the base commit and stay red,**
  by the same rows: `test_ase_dialogs` (G2sens), `test_cadence_drag` (two rows),
  `test_paste_modify_flag_0244` (timeout), `test_phase3_mints` (no result),
  `test_rotate_stretch_short_0104` (one row).

## Open

1. The user's look at the drag on their own screen and design.
2. A ruling on the six choices above.
3. Dragging one half of the bar: what should happen is not decided.
4. The action log line of a connected drag.

## Not checked

- The user's own screen (the X server under Windows).
- A drag with a rotation or a flip in it: the pass does not run there (the review ran one
  rotated drag and saw the old placement, as intended).
- `autotrim_wires` off beyond row F6. A dragged wire whose end rests on the middle of an
  unsplit wire gets no plan at that end; a wire of the plan can still meet unsplit copper
  elsewhere, which is where F6's finding came from.
- Two dragged groups of different nets touching each other: the pass's contact check looks
  at stationary copper only; the ladder's pin partition is what stands there.
