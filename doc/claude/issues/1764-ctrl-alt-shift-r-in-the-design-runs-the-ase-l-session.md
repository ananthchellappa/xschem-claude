# 1764 — Ctrl-Alt-Shift-R in the design of an ASE-L session runs the session

**STAMP:** `v1 claim=fixed tree=e5eb71262 stamped=2026-11-25 fix=taken open=3 by=driver-1764`

Asked for by the user on 2026-11-25 and built the same day. Three things are open, listed
under "Open".

## What the user wrote

> Then, in a linked schematic (i.e., the schematic that would be opened from ASE-L : Session >
> Design Window) ensure that Ctrl-Alt-Shift-R runs the simulation - i.e., - same as pressing
> the Netlist and Run button in ASE-L. This should work even if user has descended in the
> schematic down from the test-bench (top) level

## What was built

- **The action.** `ase.netlist_and_run` in the action table of `src/callback.c`, run by
  `ase::ui::run_for_current` (`src/ase_window.tcl`). It is not one of the actions the table
  marks as changing the schematic, so it works in a design ASE-L opened read-only (issue
  1761).
- **The chord.** A row of the key table: keysym 82 (a capital R: for a letter the shift is
  in the key) with Control and Alt, on the canvas, skipped while the editor is busy. Seeded
  in C and mirrored in `src/keybindings.csv` and `src/actions.csv`, so `xschem bind` and a
  key file move it.
- **Which session.** The one whose design the window stands in, or the nearest level above
  that has one (`ase::sessions_for_current`, `src/ase.tcl`): the rule Direct Plot and Show
  in Signal Browser resolve by. Of several sessions on that one design, the one used last
  (`ase::ui::last_used`), and a sentence names it.
- **What it does.** `ase::ui::do_run`, the command of the session window's Netlist and Run
  entry and of its `N&>` button, with nothing in between.
- **A menu entry.** Tools > Netlist and Run (ASE-L) in the schematic window, showing the
  chord.

## What was measured on the way: a key press cannot move through the hierarchy

The first cut ran the command inside the key press. Pressed two levels down it made no deck;
pressed at the top level it made one with three "could not descend (busy)" errors from the
operating-point cards. While the editor is handling a key, `xschem go_back` and
`xschem descend` do nothing (`xctx->semaphore`, `src/scheduler.c`), and the netlist of a run
made from depth has to climb to the bench and come back (`ase::with_design_current`).

So `ase::ui::run_for_current` notes the window the key was pressed in and hands the work to
the event loop (`after idle`); `ase::ui::run_for_window` does it once the key press has
returned. If the editor is still busy then, it starts nothing and says so.

## Rows

`tests/headless/test_ase_run_key_1764.tcl`, registered in `hcases` and `dcases`. A run is seen
through a recorder in place of `ase::run` that makes the real netlist and starts no
simulator; row RKR runs for real.

| row | what it holds |
|---|---|
| RKT1 | the live key table binds the action once: key 82, Control and Alt, canvas, idle |
| RKT2 | `keybindings.csv`, `actions.csv`, the C action row and the C seeding of the chord agree |
| RKT3 | the action is not marked as changing the schematic; `edit.undo`, the control, is |
| RKS1 | a window answers for none, one, two sessions on its design; two levels down for the bench; none on another schematic |
| RKR | two levels down, a real run: the deck in the run folder, the simulator program started on it, its output in the session's log, the user still two levels down |
| RK0 | the fixture |
| RK1 | at the top level the key calls the entry's own command once; the entry itself, pressed there, gives the same run, deck and sentences |
| RK2 | two levels down the deck is made from the bench and the user stays; the same as the entry pressed from there |
| RK2b | asked while the editor is busy, it starts nothing and says so |
| RK3 | in a read-only design it runs, and no "View is Read Only" box comes up |
| RK4 | on a schematic no session is on: nothing runs, one sentence |
| RK4b | a session with no window is not run |
| RK5 | two sessions on the bench: opened last, given the keyboard, ran from its own menu, raised by a launch |
| RK6 | the session used last closed: the other runs, nothing is said of two, the closed one's mark is gone |
| RK7 | unbound, nothing runs; bound to F9, F9 runs it; bound back, the chord runs it |
| RK8 | the Tools entry shows the chord and runs the session |
| RK8b | pressed in the bench's window, it runs that window's session though another window became current first |
| RK9 | the chord typed on the canvas, through Tk's own key binding |
| RK10 | one line in the action log per press (needs `--logdir`) |

The bank question is `ase-run-key-on-design`.

## Breaks

Each is one change, run in a copy of the tree against this suite on the display arm, with
`--logdir` and with `--nogui` (2026-11-25).

| | what was broken | rows that turn red |
|---|---|---|
| k1 | the run is made inside the key press | RKR, RK1, RK2, RK3, RK4, RK4b, RK5, RK6, RK7, RK8b, RK9, and RK10 with `--logdir` (the busy guard answers every press) |
| k1b | the same, and a busy editor is not asked about | RKR, RK1, RK2, RK2b, RK8b, and RK10 with `--logdir` |
| k2 | C: the action is marked as changing the schematic | RKT3, RK3 |
| k3 | C: the chord is not seeded | RKT2 |
| k4 | the row is missing from `keybindings.csv` | RKT2 |
| k5 | of several sessions the first opened runs | RK5 |
| k6 | the keyboard focus does not mark a session used | RK5 |
| k7 | a run does not mark it | RK5 |
| k8 | a launch that raises its window does not mark it | RK5 |
| k9 | opening its window does not mark it | RK5 |
| k10 | a closed session keeps its mark | RK6 |
| k11 | only the level on screen is asked | RKS1, RKR, RK2 |
| k12 | nothing is said when there are several | RK5 |
| k13 | no Tools entry | RK8 |
| k14 | a busy editor is not asked about | RK2b |
| k15 | the key starts the run by itself, not through the entry's command | RK1, RK2, RK3 |
| k16 | C: the chord is not skipped while the editor is busy | RKT2 |
| k17 | a session with no window is pressed too | RK4b |
| k18 | the key does not note its window | RK8b |
| k19 | the row is missing from `actions.csv` | RKT2 |

## The builder's choices (not ruled by the user)

1. **The nearest level that has a session, not always the top.** With one session on the
   bench both give the same. It is the rule the other two gestures of a design window use.
2. **Of several sessions on one design, the one used last, and a sentence says which.**
   "Used" is: its window was opened, raised by a launch, given the keyboard, or it started a
   run. The other way, the first opened, runs a state the user may not have looked at for an
   hour.
3. **The ASE-L window is not raised.** The user stays in the schematic. The session's log
   window opens, as it does for the button.
4. **A Tools menu entry was added**, which the request did not ask for, so the chord can be
   found.
5. **The chord is skipped while the editor is busy**, as the netlist key is.
6. **A session with no window is not run.** A script can open one; it has no button.
7. **No session on the schematic: one sentence and nothing else.** It does not offer to
   launch ASE-L.

## Open

1. The user's ruling on the seven choices above.
2. The user's own look, on their screen and keyboard: whether Ctrl+Alt+Shift+R reaches
   xschem through their X server (the suite presses the key inside xschem, and once through
   Tk on a hidden display).
3. `tests/headless/test_wave_sigbrowser_keys.tcl` is not registered in the regression and has
   three red rows in the unchanged tree (BK22, BK29, BK31: counts that later work moved). This
   change made a fourth of its rows untrue (BK21: "the file's only ctrl+alt row") and
   corrected that one. The three and the registration are not this issue's.

## Not checked

- The user's own screen and keyboard. Every run here was on a hidden display under openbox.
- A run with a real simulator through the key. Row RKR runs the real netlist and run
  machinery with a stand-in program.
- The user's own bench.
