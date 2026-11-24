# 1737 — The dividers between the ASE-L window's three panes can be dragged

**STAMP:** `v1 claim=fixed tree=4fba0839e stamped=2026-11-24 fix=taken open=1 by=driver-1737`

Asked for by the user on 2026-11-24 and built the same day, on a private Xvfb with
openbox. The user tried it on their own screen the same day and found it well, and
ruled on the builder's choices: all six are kept. One thing is open, listed under "Open"
below: what was not built.

## What the user asked

> The dividers (or separators, whatever the technical name is) in ASE-L - between the
> various panes - variables, analyses, outputs, are not moveable as they are in Cadence
> ADE-L. We'd like to be able to adjust - sometimes, you'd like to trade size of the
> analyses pane (vertically) to see more outputs (measures), etc.

## What was there

`ase::ui::build` gridded the three labelframes in the body frame: Design Variables in
the left column over both rows, Analyses and Outputs in the right column, with fixed
column and row weights. The gaps between the panes were the grid's pads. Nothing took a
press there.

## What is built

The rules are R-PANE1 to R-PANE8 in `doc/claude/specs/ase_l.md`, section "Panes". In
short:

- The two gaps are dividers. The one between Analyses and Outputs drags up and down,
  the one between Design Variables and the two panes at its right drags left and
  right. The panes follow the pointer during the drag. The pointer over a divider is
  the double arrow of its direction.
- A drag stops before a pane would lose its title, its column headings or its first
  row, and before a pane would be narrower than its title or its first column's
  heading. The stops come from the widgets and their fonts (`ase::ui::pane_min`).
- Only a drag moves a divider. A window resize keeps the proportions.
- A font-size change under an open window lays the panes out again
  (`ase::ui::pane_reseed`): a window nobody sized follows the font as before, and a
  dragged divider keeps its fraction.
- The split is remembered for the session while this xschem runs, so a window closed
  and opened again comes back with it. It is not written to disk.

The mechanism is two classic Tk paned windows made by `ase::ui::pane_layout`. The
labelframes stay children of the body frame under their old paths, so every reader of
`<top>.body.<pane>.tv` is untouched. Before any drag the window has the size and the
panes the sizes they had under the grid; the suite's band PD0 holds that.

One thing changed that a user could notice without dragging: when the window is
resized, the grid gave Design Variables a third of the growth and split the rest evenly
between Analyses and Outputs, whatever the panes' sizes were. The paned windows share
the growth out in proportion to the panes' sizes. On the default window the two differ
by a few pixels.

## What was found on the way

The first cut kept the panes' pixel sizes when the font size was changed under an open
window, where the grid had let the window grow: rows were cut off and horizontal
scrollbars appeared. No existing row caught it; `test_ase_window` stayed green. It was
seen in a probe that compared the base and the change side by side, and is why
`ase::ui::pane_reseed` exists. Band PD10 holds it.

## The builder's choices, ruled on 2026-11-24: all six kept

The user's words settle that both dividers can be dragged. These were not the user's;
the user kept every one of them on 2026-11-24 ("The user's rulings" at the foot):

1. The panes follow the pointer during the drag (not a ghost line placed at release).
2. The gap is as thin as it was and draws no line or grip: the only sign of a divider
   is the pointer.
3. Where a drag stops (above). A pane cannot be collapsed to nothing.
4. The split is remembered per session for the life of this xschem, and not saved.
5. The session's key is the bench with its state view, so two states of one bench have
   a split each.
6. No gesture puts the default split back; the dividers are dragged back by hand.

## What was measured

`tests/headless/test_ase_pane_dividers_1737.tcl`, registered in both regression lists.
Its header lists the bands and, for each deliberate break of the product that was tried,
the rows that went red. Every drag in it is a generated button press, pointer motion and
release on the paned window; no row calls the product's handlers. The suite is red on
both arms against the product without the change.

## Open

1. **Not built:** a split that survives a restart of xschem; an action-log line for a
   drag.

Not open any more: the six choices (kept, 2026-11-24), and dividers in the other ASE-L
windows that hold two or more lists with a fixed split (the Results > Select window's
lists, the campaign result window's table and plots). The user ruled to leave those
windows as they are, and nothing is filed for them.

## The user's look (2026-11-24)

Everything above ran on a hidden display with generated events. The user then used the
dividers with a real mouse on their own screen and wrote: *"I checked out the new ASE-L
and all is well."* The look is paid on those words. They say nothing about the six
choices (ruled later the same day, below), nor about the tutorial's wording.

## The user's rulings (2026-11-24)

The user answered this issue's entry in the owed ledger on a sign-off sheet in the
private tree's session, which cleared it and relayed the answer here in its own words:
all six choices are kept as built, and the other ASE-L windows with a fixed split are
left as they are, with nothing filed.
