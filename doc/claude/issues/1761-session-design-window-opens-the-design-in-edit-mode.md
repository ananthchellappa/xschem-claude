# 1761 — Session > Design Window opens the design in edit mode

**STAMP:** `v1 claim=fixed tree=e763db235 stamped=2026-11-25 fix=taken open=2 by=driver-1761`

Asked for by the user on 2026-11-25 and built the same day. Two things are open, listed under
"Open".

## What the user wrote

> When user does Session > Design Window in ASE-L, the schematic should NOT open in Edit mode.
> It should open Read Only

## What was measured

On a private Xvfb with openbox, in this tree at `e763db235`: a state view opened from a
library with its design not open anywhere, then `ase::ui::design_window`. The design loaded
into the window xschem starts with, `xschem get readonly` answered 0 and the title read
`xschem [3] - tb.sch`.

## The repair

`ase::ui::design_window` (`src/ase_window.tcl`) loads through `xschem load -gui -readonly`,
the door the reopen shortcuts (Open Most Recent, Last Closed, the Recent menu) already use.
The window title carries "(read-only)" and the Command window says "Opened Read-Only. Use
Edit > Make Editable (Ctrl-2) if needed" (`reopen_readonly_notice`, unchanged).

The action log gets `xschem set readonly 1` after the load line, as `libmgr::open_view_ro`
writes it, so a replay ends in the same mode. It is written only when the window now current
holds the design read-only (`ase::ui::design_is_current_ro`).

**Every door, not only the menu entry.** The proc is also what Run, Select On Design, Direct
Plot, the convergence highlight, the Calculator's pick and the viewer's browser call when the
design is not open. They all open it read-only now.

**A design that is already open is raised as it is.** `ase::ui::raise_design_editor` is
untouched: a window the user is editing in stays editable.

## Found on the way, and repaired: a read-only open that loads nothing

`xschem load -gui -readonly <file>` from a window that already holds a schematic opens the
file in a window of its own. When the file could not be opened (it was deleted since, or the
"already open" question was answered Cancel), **the window the user was in was made read-only
and "Opened Read-Only" was announced for it.** Measured before the repair: an editable
window holding `a.sch`, the call on a file that does not exist, and afterwards
`xschem get readonly` answered 1 with one notice said. The Recent menu and both reopen keys
go through this.

The cause, in the `load` branch of `src/scheduler.c`: the mode was set when `first_loaded`
was true, and an open that is routed to a new window presets `first_loaded` before anything
is loaded. A flag of its own, `loaded_any`, is now set where a file is really loaded.

## Rows

`tests/headless/test_ase_design_window_ro_1761.tcl`, registered in `hcases` and `dcases`.

| row | what it holds |
|---|---|
| DWH | no display: a scripted load with the flag ends read-only, the next plain load is editable |
| DW0 | the fixture: the session window is up, the design is not open, the start window is editable |
| DW1 | the menu entry: the design is current, read-only, the title says so, the notice is said once |
| DW2 | Make Editable makes it editable; a second press raises it as it is, nothing announced |
| DW3 | the read-only design netlists and takes a highlight; a net that is not there is not found |
| DW4 | with another schematic in the window: the design opens read-only in its own window, the other stays editable |
| DW5 | a read-only open of a missing file leaves the user's window editable and announces nothing; the control opens read-only |
| DW6 | the action log holds the load and, after it, the read-only line once (needs `--logdir`) |

Two questions of the tip-of-the-day bank: `ase-design-window-readonly`, and for issue 1762
`ase-bar-names-own-simulator`.

## Breaks

Each is one edit, run in a copy of the tree against this suite on the display arm, with
`--logdir` and with `--nogui` (2026-11-25).

| | what was broken | rows that turn red |
|---|---|---|
| c1 | the load without the read-only flag | DW1 to DW5, DW6 with `--logdir`; the bank question `ase-design-window-readonly` (row A15 of `test_startup_quiz`) |
| c2 | the mode not written to the action log | DW6 (with `--logdir` only: the other arms have no log to read) |
| c3 | C: the mode set on `first_loaded` again | DW5 |
| c4 | C: a file opened in a new window does not count as loaded | DW4, DW5 |
| c5 | C: a file loaded in place does not count as loaded | DWH without a display; DW1 to DW5 with one, DW6 with `--logdir` |

## The builder's choices (not ruled by the user)

1. **Every door that opens the design for a session opens it read-only**, not only the menu
   entry the request names. The other way would leave the mode depending on which gesture
   happened to open the window first.
2. **A design already open is raised in the mode it has.** A design the user was editing is
   not switched to read-only by pressing Design Window.
3. **The notice is the existing one** ("Opened Read-Only. Use Edit > Make Editable (Ctrl-2)
   if needed"), said in the Command window and the status bar. No dialog.

## Open

1. The user's ruling on the three choices above.
2. The user's own look: the title, the notice, and Make Editable, on their screen.

## Not checked

- The user's own screen. Every run here was on a hidden display under openbox.
- A design opened read-only by Run on a bench with a deep hierarchy, on the user's cells.
  The regression's run flows bind the design with a plain load.
