# 1738 — Ctrl-Alt-S brings the Library Manager forward also when there is nothing to locate

**STAMP:** `v1 claim=fixed tree=51fedcdaf stamped=2026-11-24 fix=taken open=2 by=driver-1738`

Asked for by the user on 2026-11-24 and built the same day, on a private Xvfb with
openbox. Two things are open, listed under "Open" below: the user's own look at it, and
a ruling on the builder's choices.

## What the user asked

> Ctrl-Alt-S (that's not capital S or Shift-S. Just S key with Ctrl+Alt) locates the
> current cell that is being viewed in the Schematic window in the Library Manager. But,
> it only works if this cell exists - meaning, it doesn't work to just raise the Library
> Manager (which is what the user sometimes wants, because of how things load and windows
> are behind other Windows windows) if the Schematic editor is editing untitled.sch or
> some variant of that.
>
> So, in the case that the user is looking at a non-existent cell (doesn't exist in the
> user's library file system), ensure that Ctrl-Alt-S WILL raise the Library Manager. No
> need for it to steal focus though. Just raise.

And later the same day, on hearing that leaving the keyboard on the schematic is the
harder of the two:

> I didn't want to make it harder. I assumed that not-stealing-focus would be easier. I
> guess I was wrong. So, go ahead and wrap it up WITH handing the Library Manager focus
> when user does Ctrl-Alt-S

## What was there

The key is the Cadence profile's (`src/cadence_style_rc` binds it on the drawing area to
`locate_selected_in_libmgr`, `utils/lib_mgr_helpers.tcl`). With nothing selected it asks
`schematic_cellview` which library cell the schematic is. An untitled schematic, or a
file outside every registered library, is none: the command wrote "current cell is not
in a registered library" in the CIW and returned. Nothing was raised. Three other cases
ended the same way: one instance whose symbol is in no library, one text note with no
`lib/cell` in it, and any other selection.

## What is built

The rules are R-LMR1 to R-LMR4 in `doc/claude/specs/library_manager_launch.md`,
section 4. In short:

- Every press of the key ends with the Library Manager in front and holding the
  keyboard. With nothing to locate the key runs `xschem library_manager` with no cell,
  the same raise the located path has always used. A closed Library Manager is opened, a
  minimised one comes back.
- The CIW line says why nothing is located and that the window was raised. On an
  untitled schematic it is no longer styled as an error.
- What is selected in the Library Manager stays selected. The already-open arm of
  `libmgr::open` refreshes the panes, which empties Cell and View; with no cell asked
  for it now takes the selection before the refresh and puts it back. The same arm
  serves Tools > Library Manager, so that entry keeps the selection too.

## Why the keyboard goes to the Library Manager

The first cut left the keyboard on the schematic, as first asked. It was built and its
rows passed, and it was taken out again at the user's word. What it took, for whoever
is asked for it again: on the user's X server a plain `raise` does nothing, so
`raise_toplevel` (`src/xschem.tcl`) maps the window again, and a window that is mapped
again is given the keyboard by the window manager. Measured on a private display under
openbox: the bare re-map moved the keyboard to the Library Manager's library list; the
same re-map followed at once by `focus -force` on the drawing area kept it. On the
user's server the grant lands later, which is why the Results Display window has an
event-driven hand-back (`src/rdw.tcl`, issues 1306, 1340, 1369). The cut had the same
three parts: the forced focus, a hand-back on the window's `<FocusIn>` spent by the
first grant, by a press in the window and by time. One trap met on the way: the time
was compared with `string is integer`, which refuses `clock milliseconds` (wider than
32 bits), so the hand-back never fired until a row with a late grant caught it.

## The builder's choices, for a ruling

1. The three other cases (an instance or a note that names no library cell, any other
   selection) raise the Library Manager too. The user asked for the untitled schematic.
2. On an untitled schematic the CIW line is styled as a result, not as an error. In the
   other three cases it stays an error.
3. The selection kept across a raise also applies to Tools > Library Manager on a
   window that is open, which used to empty the Cell and View panes.

## What was measured

`tests/headless/test_libmgr_raise_1738.tcl`, registered in both regression lists. The
key is a generated `<Control-Alt-Key-s>` on the drawing area, so the profile's own
binding runs. Which window is in front is the window manager's answer
(`wm stackorder`). The display arm is red against the product without the change; its
header names the two deliberate breaks tried and the rows each reddened.

## Open

1. **The user's own look.** Everything ran on a hidden display under openbox. Not done:
   the key on the user's screen, with the Library Manager behind windows of other
   programs.
2. **The three choices above** wait for a ruling.

## Not built

- The raise that leaves the keyboard on the schematic (above).
- A line in the action log that tells this press from Tools > Library Manager: both
  write `xschem library_manager`.
