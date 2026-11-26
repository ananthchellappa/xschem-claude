# 1766 — Ctrl-R in the Waveform Viewer reads the result again

**STAMP:** `v1 claim=fixed tree=ce9da37b3 stamped=2026-11-25 fix=taken open=2 by=driver-1766`

Asked for by the user on 2026-11-25 and built the same day. The review of issue 1765 found
one defect here, repaired ("Found by the review"). Two things are open, listed under
"Open".

## What the user wrote

> Second, in Waveform Viewer, add support for Ctrl-R (that's not Ctrl-Shift-R, just plain
> Ctrl-R) that will reload (from latest sim, or currently selected result in ASE-L -
> meaning, user could have just selected a past saved sim result) the waveforms currently
> plotted.

## What was built

- **The key.** Plain Ctrl-R on the viewer's `WaveViewer` bind tag
  (`wviewer::install_default_binds`), and **File > Reload** showing it. Ctrl-Shift-R is
  another key sequence and is not bound.
- **What it reads** (`wviewer::reload_source`): the result the window's ASE-L session has in
  view (`ase::ui::reload_source`). That is the latest run, or the saved result chosen with
  Results > Select, because `ase::last_rawfile` follows the result in view. When the
  session answers nothing (it has no results file), the file the window attached last.
- **What it does** (`wviewer::reload`): the file is read again through the load a run and a
  Direct Plot use (`wviewer::attach_raw`), so a zoom is kept by the same rules, and every
  trace shows it. A trace that was kept on an earlier run by a finished run's plot (issue
  1765) is put back on the result first (`wviewer::hold_release`). No trace is added or
  removed; the strips, their order, the target and the undo history stay.
- **Not while the session's run is live** (`ase::ui::reload_busy`): the simulator is
  writing that file. The key says so and reads nothing.
- **When the read finds nothing** (the file holds no such analysis, or no data) the viewer
  is left as it was: its data stays loaded and current, a trace kept on an earlier run
  stays on it (`wviewer::hold_settle`), and nothing is logged.
- **What it says.** One sentence naming what was read (a saved result by its name), with
  the number of traces that were on an earlier run; or why nothing was read. One
  replayable log line for a read, `wviewer::reload <window>`.

## Found by the review, and repaired

- **The key said "reloaded" when nothing was read.** Pressed while a run was live it
  emptied the viewer, or put every trace on the older kept run. Two causes. The reload took
  the load's return for success; it now asks whether data was read. And the load itself
  (`ase::attach_dbs`, `src/ase.tcl`) dropped the copy of the file that was loaded BEFORE
  reading the file again, so a read that failed left nothing: the copy is now set aside
  under another name (`xschem raw rekey`) and gets its own name back when the read fails.
  That second cause is older than this issue and was reachable by `~` and a Direct Plot
  made while a run was writing its file; the key made it one press away. Rows RLP3, RL10,
  RL11.

## Rows

`tests/headless/test_wave_reload_1766.tcl`, registered in `hcases` and `dcases`.

| row | what it holds |
|---|---|
| RLP1 | what a session hands the viewer: its result file and analysis; nothing for an operating point, no file, an unknown session |
| RLP2 | the sentence's count of traces |
| RL1 | Ctrl-R is bound on the viewer's tag and stops there; Ctrl-Shift-R is not bound; File > Reload shows Ctrl+R |
| RL2 | after a run that plotted nothing (the option off), a real Ctrl-R on the canvas brings every trace to the new run; the strips, the target and the undo history are what they were; one sentence, one log line |
| RL3 | a trace kept on an earlier run shows the result again, the kept data is gone, the sentence counts it |
| RL4 | a zoom is kept across a reload of new data |
| RL5 | Ctrl-Shift-R on the canvas reloads nothing |
| RL6 | File > Reload does what the key does |
| RL7 | a saved result selected in ASE-L: Ctrl-R shows that result and names it; back on the latest run, Ctrl-R shows the run |
| RL8 | a session with no results file, a file attached by hand: Ctrl-R reads that file again |
| RL9 | nothing to read: one sentence, nothing changes, nothing logged |
| RLP3 | a load whose read fails leaves the copy that was loaded, under its own name and current; a read that works replaces it |
| RL10 | while the session's run is live the key reads nothing and says so |
| RL11 | a file that cannot be read as the analysis shown: the viewer is as it was, a kept trace stays kept, the sentence says so, nothing is logged |
| RL12 | a kept strip zoomed in X: Ctrl-R keeps the X window and fits Y to the result |

The bank question is `wave-reload-ctrl-r`.

Ctrl-R was the example key of an rc remap (bound to Clear All) in the viewer's comments,
the user guide, the spec, and rows CG6 of `test_wave_clear_all` and KM19 of
`test_wave_viewer`, which bound it as a key of their own and removed it afterwards. All
of them now use Ctrl-K. The guide's key table has the row for Reload, so its counts moved
(GH0 of `test_wave_grid`, BT09 of `test_wave_sigbrowser`, and in two suites the
regression does not run, BX13 of `test_wave_sigbrowser_i12` and BK10 of
`test_wave_sigbrowser_keys`: 22 keys, 17 accelerators).

## Breaks

Each is one change, run in a copy of the tree against this suite on the display arm and
with `--nogui` (2026-11-25).

| | what was broken | rows that turn red |
|---|---|---|
| b16 | the reload does not put kept traces back | RL3, RL4, RL5, RL6, RL7, RL12 |
| b17 | Ctrl-R is not bound | RL1 to RL5, RL7 to RL12 |
| b18 | the reload reads what the window attached last, not the session's result | RL7 |
| b19 | the reload is not logged | RL2, RL6 |
| b24 | the File menu has no Reload | RL1, RL6 |
| b26 | the session hands over a result that is an operating point only | RLP1 |
| c7 | a load that read nothing leaves the traces unpinned | RL11 |
| c11 | the reload reads while a run is live | RL10 |
| c12 | the reload says "reloaded" whatever was read | RL11 |
| c13 | a failed read drops the copy that was loaded | RLP3, RL11 |

Breaks of issue 1765's suite that also turn rows of this one red: a finished run that
keeps nothing, a load that drops the kept data, and a finished run plotted as the user's
(RL3, RL11, RL12 each).

## The builder's choices (not ruled by the user)

1. **A File menu entry was added**, which the request did not ask for, so the key can be
   found.
2. **The session's result wins over a file loaded by hand.** A file the user put in the
   viewer through its Location bar is not a saved result of the session, so Ctrl-R goes
   back to the session's result. Only a session with no result file reads the hand-loaded
   one again.
3. **Ctrl-R does not plot ASE-L's rows again.** It changes the data under the traces that
   are there; `~` is the gesture that plots.
4. **Not an undo step.** It changes no trace and no strip.
5. **Refused while a run of the session is live.** Reading a file the simulator is writing
   shows a header, an operating point alone or half a transient.

## Open

1. The user's ruling on the five choices above.
2. The user's own look, on their screen and keyboard: whether Ctrl-R reaches the viewer
   through their X server (the suite presses the key through Tk on a hidden display).

## Not checked

- The user's own screen and keyboard. Every run here was on a hidden display under openbox.
- A real simulator run between two reloads: the rows write the results file themselves.
