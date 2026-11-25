# 1762 — The ASE-L bar names the process's simulator, not the state's own, until the first run

**STAMP:** `v1 claim=fixed tree=e763db235 stamped=2026-11-25 fix=taken open=3 by=driver-1762`

Reported by the user on 2026-11-25 and repaired the same day. Three things are open, listed
under "Open".

## What the user wrote

> When ASE-L is launched, the simulator to be used is not matching what is shown on the
> status bar. [...] shows the v52, but is set to ver_53. And, after the first run, it
> displays correctly.

## What was measured

On a private Xvfb with openbox, in this tree at `e763db235`: two stub programs registered as
`v_52` and `ver_53`, the first in force, and a state view whose `sim_entry` is
`{name ver_53}`. The window opened with `Simulator: v_52` on its bar. After the run's own
step (`ase::sim_apply_choice`) and a repaint it read `Simulator: ver_53`.

The cause: the bar asked `ase::sim_label`, which reads the choice in force for the whole
process (`ase::sim_use`). A state's choice went in force only when the state was run or the
choice was picked in the Simulators window. Until then the bar, and everything else that asks
which program a run starts, answered about whatever the process started with or about the
last state that ran.

This is the bar's half of a limitation the earlier work carried on purpose: decision D5 of
`doc/claude/ase_simchoice_batch/DECISIONS.md`.

## The repair

- **The bar asks about its own state.** `ase::sim_session_label` (`src/ase.tcl`) puts the
  state's choice in force as a run does, without the run's sentence, reads `ase::sim_label`,
  and puts back what was in force. `ase::ui::refresh_status` calls it. Two windows each name
  their own, whichever opened, ran or picked last.
- **The state's choice is in force from the moment the window opens.** `ase::ui::sim_enter`
  (`src/ase_window.tcl`) is called by `ase::ui::open`, by the arm of `ase::open_state` that
  raises a window already open, by `ase::ui::do_load_state_from` and by
  `ase::ui::revert_state`. So the other readers agree before the first run: the case mode a
  pick on the design resolves names in, what Choose Analyses and the Options sheet know the
  program can do, the status line of the Simulators window.
- **A state that asks for a simulator nobody has registered says so when it opens**, and
  when it is loaded into a window: the sentence a run says (`ase::sim_why noentry`), once.
  Its bar names what is in force, because that is what its run starts.

## What changed for the Command window's door

`ase::sim_select <name>` typed into the Command window changes what is in force and writes
no state. Before, every open bar followed it. A run of a bench puts that bench's own choice
(or the installation default) in force before it starts anything, so the bar was naming a
program the run would not start. Now no bar follows it. Removing an entry from that door
still repaints every bar at once.

## Rows

`tests/headless/test_ase_bar_session_sim_1762.tcl`, registered in `hcases` and `dcases`.

| row | what it holds |
|---|---|
| BS0 | the fixture: three entries, the first in force, each stub prints its own marker |
| BS1 | the label names the state's own entry with another in force, and changes nothing |
| BS2 | no choice: the installation default; the PATH choice: no entry's name |
| BS3 | an entry nobody registered: what is in force, no sentence from the label |
| BS4 | a registered entry whose program is gone: its name with the mark |
| BS5 | the report: the window opens with its own simulator on the bar and in force |
| BS6 | the command a run composes, started for real, is that program |
| BS7 | a second window names its own; the first still names its own |
| BS8 | a launch that raises a window puts its simulator back in force |
| BS9 | Load State brings the loaded state's simulator, Revert brings the saved one back |
| BS10 | a state asking for an unregistered simulator says so once when it opens |
| BS11 | repainting every bar moves nothing |
| BS12 | structural: the bar asks about its own state |

Three rows of `tests/headless/test_ase_simdlg_0937.tcl` held the old behaviour and are
rewritten, each with its reason beside it: `S22` (a pick in one window was expected on the
other's bar), `S32` (a pick from the Command window was expected on every bar; the row now
also takes an entry off the list from that door and expects it gone from every bar), `S45`
(the bar was expected to name what is in force, not the bench's choice).

## Breaks

Each is one edit, run in a copy of the tree against the two new suites, the Simulators
window suite and the tip-of-the-day suite, on the display arm, with `--logdir` and with
`--nogui` (2026-11-25). Without a display only BS1 to BS4 and BS12 run.

With the bar's own question taken out (b1), the rows that read a bar straight after another
window opened (BS7, BS8) stay green: the label still holds the text of its last repaint.
BS11, which repaints every bar first, is the row that sees it.

| | what was broken | rows that turn red |
|---|---|---|
| b1 | the bar asks the process-wide question again | BS11, BS12; S22, S32, S45 of `test_ase_simdlg_0937`; the bank question (row A15 of `test_startup_quiz`) |
| b2 | the window does not put its choice in force when it opens | BS5, BS7, BS10; the bank question |
| b3 | the window opens without the sentence | BS10; the bank question |
| b4 | a launch that raises a window does not put its choice in force | BS8 |
| b5 | Load State does not put the loaded choice in force | BS9 |
| b6 | Revert does not put the saved choice back in force | BS9, BS10, BS11 |
| b7 | the label leaves the session's choice in force | BS1 to BS4, BS11; S8a, S8b, S17, S19, S32, S44, S45 of `test_ase_simdlg_0937` |
| b8 | the label says the stale-entry sentence | BS3, BS10; the bank question |
| b9 | the label ignores the state | BS1, BS2, BS4, BS11; S22, S32, S45; the bank question |

## The builder's choices (not ruled by the user)

1. **Opening a window puts its state's simulator in force**, as a run does. With two windows
   open, the one opened or raised last decides what the dialogs of both answer about
   (below). The bars do not depend on it.
2. **A state that asks for an unregistered simulator says so when it opens**, in the
   Command window, tagged as an error. Before, the first notice was at Run.
3. **A pick from the Command window (`ase::sim_select`) is on no bar**, because no run
   starts it. It was on every bar before.
4. **The dialogs are left as they were.** With two windows open, Choose Analyses, the
   Options sheet and the status line of the Simulators window of the window that did not
   open, run or pick last still answer about the other's program (decision D5). Putting a
   window's choice in force when one of its dialogs opens was tried and taken out: four
   rows of the Simulators window suite about removing the entry in use are written against
   the choice typed into the Command window staying in force while the dialog opens.

## Open

1. The user's ruling on the four choices above.
2. The dialogs of the window that did not open, run or pick last (choice 4).
3. The user's own look at the bar on their bench.

## Not checked

- The user's own screen, and their own registry file. Every run here used stub programs in
  a registry of the suite's own, on a hidden display.
- The private tree, where the report was made: see the hand-over folder.
