# 1763 — the Save State form of an ASE-L window has no Browse button

**STAMP:** `v1 claim=fixed tree=e5eb71262 stamped=2026-11-25 fix=taken open=2 by=driver-1763`

Asked for by the user on 2026-11-25 and built the same day, with a repair found in the same
form. Two things are open, listed under "Open".

## What the user wrote

> ASE-L. The Session > Save State gives a dialog. That dialog pop-up SHOULD have a Browse
> button so user doesn't have to type everything. Please do the honors.

## What was built

`ase::ui::save_state_dialog` (`src/ase_window.tcl`) has a **Browse…** button under its three
fields, where the Save As form of the schematic window has its own.

It opens a browser of three columns, Library, Cell and View (`ase::ui::saveas_browse`), in the
shape of Load State's:

- It opens where the form stands: the form's Library and Cell selected, and its View too when
  that names a saved state of the cell (`ase::ui::saveas_browse_seed`).
- The View column lists the cell's saved states only (`ase::ui::state_views`, the list Load
  State shows).
- **OK** copies the pick into the form and closes the browser (`ase::ui::saveas_browse_ok`).
  Library alone, or Library and Cell, is a whole pick: the View name already in the form is
  kept. With no Library picked the browser stays and says so.
- A double click on a state is the pick and the OK in one.
- **Cancel** and Escape change nothing in the form.
- The status line names what OK will copy (`ase::ui::saveas_browse_hint`).
- It is a child window of the form, so it goes when the form goes.

The form's own OK is still what saves, through the confirm chain a typed name goes through.

## Found on the way, and repaired: a state written over the schematic

Measured before the change, in a scratch library with a cell `tb` that has a schematic and a
saved state: Save State with the View name `schematic` asked "State dlib/tb/schematic exists.
Overwrite?", and on OK `ase::ui::do_save_state_as` answered 1 and `tb.sch` began with the
state's text. `xschem cellview_path` answers the view's own datafile, and the writer wrote
whatever it answered.

`ase::ui::save_as_not_a_state` answers the file such a view holds. The form
(`ase::ui::save_state_ok`) refuses the name before any confirm and stays up; the writer
(`ase::ui::do_save_state_as`) refuses it too, for a script or the Command window. One
sentence, naming the file. The test is the one `state_views` lists by, so the browser, the
form and the writer agree on what a state is.

## Rows

`tests/headless/test_ase_save_browse_1763.tcl`, registered in `hcases` and `dcases`.

| row | what it holds |
|---|---|
| SN1 | the guard names the file for a schematic view; nothing for a state, a free name, a missing cell |
| SN2 | no display: the writer refuses the schematic's name, says one sentence, the file is unchanged |
| SB0 | the fixture: the form opens on the session's own names, no browser yet |
| SB1 | the button is there and gridded; the browser opens on the form's library, cell and state; the schematic is not listed |
| SB2 | a typed name that is no state: Library and Cell selected, no View; OK takes two fields and keeps the name |
| SB3 | a pick changes nothing until OK; all three picked; the double click on a state; on a cell it does nothing; no background error |
| SB4 | Cancel leaves the form as it was; Escape is the same command; the form stays up |
| SB5 | cancelling the form takes the browser down with it |
| SB6 | a Library the lists do not hold: nothing picked, OK copies nothing and stays; with a library picked it takes it |
| SB7 | the whole trip: Browse, a new View name, OK; the state is saved there with no question |
| SB7b | a state picked in the browser still brings the Overwrite question before it is replaced |
| SB8 | the blocking Save State of a close: the browser works inside the wait and the wait ends on the save |
| SB9 | the form refuses the schematic's name before any question; the writer too; another state's name does ask |

The bank question is `ase-save-state-browse`.

## Breaks

Each is one change, run in a copy of the tree against this suite on the display arm, with
`--logdir` and with `--nogui` (2026-11-25).

| | what was broken | rows that turn red |
|---|---|---|
| s1 | no Browse button | SB1 to SB8 |
| s2 | the browser opens with nothing selected | SB1, SB2, SB3, SB7b |
| s3 | the View column lists every view | SB1, SB2, SB3 |
| s4 | OK blanks the View when none is picked | SB2, SB3, SB8 |
| s5 | OK leaves the browser up | SB2, SB3, SB6 |
| s6 | the double-click binding has no `break` | SB3, SB9 (the background error is recorded) |
| s7 | a double click on a cell is OK too | SB3 |
| s8 | the form does not refuse a schematic's name | SB9 |
| s9 | the writer does not refuse it | SN2 without a display, SB9 with one |
| s10 | the browser is not a child of the form | SB1 to SB8 |
| s11 | OK with no Library closes the browser | SB6 |
| s12 | a pick fills the form at once | SB3, SB4 |

## The builder's choices (not ruled by the user)

1. **OK and Cancel, not live filling.** The browser of the schematic window's Save As fills
   its form with every click and its Cancel takes nothing back. Here a pick changes nothing
   until OK, so Cancel means what it says.
2. **The View column lists saved states only.** A cell's schematic or symbol is not offered
   as a place for a state.
3. **OK with no View picked keeps the View name in the form.** The usual save is "this cell,
   a new state name".
4. **A double click closes the browser only on a state.** On a library or a cell it selects
   and nothing more.
5. **The button sits under the three fields at the right**, as in the schematic window's
   Save As.
6. **A View name that is a view of another kind is refused outright.** No "overwrite
   anyway".

## Open

1. The user's ruling on the six choices above.
2. The user's own look: the button, the browser and its status line, on their screen.

## Not checked

- The user's own screen. Every run here was on a hidden display under openbox.
- A library list as long as the user's. The fixture has two libraries and three cells.
